--[[--------------------------------------------------------------------
    Loothing - Loot Council Addon for WoW 12.0+
    MessageHandler - Message routing, sending, and receiving

    Uses Loolib.Comm for transport (handles chunking, throttling, queuing).
    Uses ns.Protocol for encoding (Serializer + Compressor pipeline).
    Integrates with ns.RestrictionsMixin for encounter restriction handling.
----------------------------------------------------------------------]]

local _, ns = ...
local Loolib = LibStub("Loolib")
local CallbackRegistryMixin = Loolib.CallbackRegistryMixin
local Comm = Loolib.Comm
local CreateFromMixins = Loolib.CreateFromMixins
local Loothing = ns.Addon

ns.CommMixin = CreateFromMixins(CallbackRegistryMixin, ns.CommMixin or {})

--[[--------------------------------------------------------------------
    CommMixin
----------------------------------------------------------------------]]

local Utils = ns.Utils
local TestMode = ns.TestMode

---@class CommMixin
---@field GenerateCallbackEvents fun(self: CommMixin, events: table)
---@field Send fun(self: CommMixin, command: string, data: table|nil, target: string|nil, priority: string|nil)
local CommMixin = ns.CommMixin

local COMM_EVENTS = {
    "OnSessionStart",
    "OnSessionEnd",
    "OnItemAdd",
    "OnItemRemove",
    "OnVoteRequest",
    "OnVoteCommit",
    "OnVoteCancel",
    "OnVoteResults",
    "OnVoteAward",
    "OnVoteSkip",
    "OnSyncRequest",
    "OnSyncData",
    "OnCouncilRoster",
    "OnObserverRoster",
    "OnPlayerInfoRequest",
    "OnPlayerInfoResponse",
    "OnPlayerResponse",
    "OnVersionRequest",
    "OnVersionResponse",
    "OnMLDBBroadcast",
    "OnCandidateUpdate",
    "OnVoteUpdate",
    "OnStopHandleLoot",
    "OnTradable",
    "OnNonTradable",
    "OnHeartbeat",
    "OnHistoryEntry",
    "OnResponsePoll",
    "OnVotePoll",
    "OnIncrementalSyncRequest",
    "OnIncrementalSyncData",
    "OnMessageDropped",
}

--[[--------------------------------------------------------------------
    Batch Accumulator
----------------------------------------------------------------------]]

-- 100 ms collection window; messages keyed by "target:priority"
local BATCH_WINDOW   = 0.1
local MAX_BATCH_SIZE = 20

-- Expose send-side cap so HandleBatch can enforce the same limit on receive
CommMixin.MAX_BATCH_SIZE = MAX_BATCH_SIZE

-- batchAccumulator[key] = { messages={}, target=, priority= }
local batchAccumulator = {}

-- Replay-protection: track (sender.."-"..msgID) → timestamp for recent messages.
-- Entries expire after SEEN_TTL seconds; sweep runs every 30 seconds.
-- Hard-capped at SEEN_MAX_ENTRIES to prevent unbounded growth under a
-- flood of distinct msgIDs from a single malicious peer (at 1000 msg/s
-- within the 120s TTL the table could otherwise reach ~120k entries).
-- On overflow we do an emergency sweep of expired entries first; if still
-- over the cap, evict the oldest SEEN_EVICT_BATCH entries by timestamp.
local seenIDs          = {}
local seenCount        = 0
local SEEN_TTL         = 120
local SEEN_MAX_ENTRIES = 10000
local SEEN_EVICT_BATCH = 1000
local lastCleanup      = 0

-- Per-type comm statistics for diagnostics (/lt diag)
local commStats = {
    sent = {},       -- [wireCode] = count
    received = {},   -- [wireCode] = count
    dropped = {},    -- [wireCode] = count
}

-- Decode error ring buffer — the last N failures from Protocol:Decode(), with
-- context (sender, reason, bytes, timestamp). Lets /lt diag expose the CAUSE
-- of decode errors instead of only a count. Bounded-size circular buffer.
local DECODE_RING_SIZE = 20
local decodeRing       = {}  -- array; [1..size] hold entries, wraps via decodeRingHead
local decodeRingHead   = 1   -- 1-based index of the next slot to write
local decodeRingCount  = 0   -- number of valid entries (<= DECODE_RING_SIZE)

local function RecordDecodeFailure(sender, reason, bytes, distribution)
    -- time() is wall-clock epoch seconds; GetTime() is session-relative and
    -- would print as 1970 under date(). The diag panel formats this with
    -- date("%H:%M:%S") so both values must agree on the "epoch" definition.
    decodeRing[decodeRingHead] = {
        ts           = time(),
        sender       = sender or "?",
        reason       = reason or "unknown",
        bytes        = bytes or 0,
        distribution = distribution or "?",
    }
    decodeRingHead = (decodeRingHead % DECODE_RING_SIZE) + 1
    if decodeRingCount < DECODE_RING_SIZE then
        decodeRingCount = decodeRingCount + 1
    end
end

local function GetBatchKey(target, priority)
    return (target or "_broadcast") .. ":" .. (priority or "NORMAL")
end

--[[--------------------------------------------------------------------
    Critical Commands (never downgraded by backpressure)
----------------------------------------------------------------------]]

local CRITICAL_COMMANDS = {
    [Loothing.MsgType.SESSION_START]       = true,
    [Loothing.MsgType.SESSION_END]         = true,
    [Loothing.MsgType.ITEM_ADD]            = true,
    [Loothing.MsgType.ITEM_REMOVE]         = true,
    [Loothing.MsgType.VOTE_REQUEST]        = true,
    [Loothing.MsgType.VOTE_CANCEL]         = true,
    [Loothing.MsgType.VOTE_AWARD]          = true,
    [Loothing.MsgType.VOTE_RESULTS]        = true,
    [Loothing.MsgType.VOTE_SKIP]           = true,
    [Loothing.MsgType.PLAYER_RESPONSE]     = true,
    [Loothing.MsgType.MLDB_BROADCAST]      = true,
    [Loothing.MsgType.COUNCIL_ROSTER]      = true,
    [Loothing.MsgType.OBSERVER_ROSTER]     = true,
    [Loothing.MsgType.VOTE_COMMIT]         = true,
    [Loothing.MsgType.VOTE_POLL]           = true,
    [Loothing.MsgType.RESPONSE_POLL]       = true,
    [Loothing.MsgType.BATCH]               = true,
    [Loothing.MsgType.SESSION_INIT]        = true,
    [Loothing.MsgType.RESPONSE_BATCH]      = true,
    [Loothing.MsgType.TRADABLE]            = true,
    [Loothing.MsgType.NON_TRADABLE]        = true,
}

--[[--------------------------------------------------------------------
    Coalescable Commands (replace-in-queue for idempotent whole-state)

    Commands listed here carry whole-state payloads where only the most
    recent send matters. When a new outbound message for the same
    (coalesceKey, target) is enqueued and an earlier send is still queued
    but has not yet begun transmitting, the earlier item is marked
    superseded and the drain will skip it. This keeps us inside WoW's
    per-message-count send budget under request floods (e.g., 20 raiders
    reload and each triggers an MLDB sync within the same second).

    NOT listed here (must append, never supersede):
    - ITEM_ADD / ITEM_REMOVE (session mutation, each adds distinct state)
    - PLAYER_RESPONSE (per-item per-player response, each is distinct)
    - VOTE_REQUEST / VOTE_CANCEL / VOTE_AWARD / VOTE_COMMIT / VOTE_RESULTS
    - BATCH / RESPONSE_BATCH (aggregate content, already batched upstream)
    - VOTE_POLL / RESPONSE_POLL (poll-at-time-T semantics)
    - SESSION_START / SESSION_END (lifecycle transitions)
    - TRADABLE / NON_TRADABLE (per-item notifications)
----------------------------------------------------------------------]]
local COALESCE_COMMANDS = {
    [Loothing.MsgType.MLDB_BROADCAST]    = true,
    [Loothing.MsgType.COUNCIL_ROSTER]    = true,
    [Loothing.MsgType.OBSERVER_ROSTER]   = true,
    [Loothing.MsgType.HEARTBEAT]         = true,
    [Loothing.MsgType.SESSION_INIT]      = true,
    [Loothing.MsgType.VERSION_RESPONSE]  = true,
}

--- Command → handler method name dispatch table
local HANDLERS = {
    [Loothing.MsgType.SESSION_START]           = "HandleSessionStart",
    [Loothing.MsgType.SESSION_END]             = "HandleSessionEnd",
    [Loothing.MsgType.ITEM_ADD]                = "HandleItemAdd",
    [Loothing.MsgType.ITEM_REMOVE]             = "HandleItemRemove",
    [Loothing.MsgType.VOTE_REQUEST]            = "HandleVoteRequest",
    [Loothing.MsgType.VOTE_COMMIT]             = "HandleVoteCommit",
    [Loothing.MsgType.VOTE_CANCEL]             = "HandleVoteCancel",
    [Loothing.MsgType.VOTE_RESULTS]            = "HandleVoteResults",
    [Loothing.MsgType.VOTE_AWARD]              = "HandleVoteAward",
    [Loothing.MsgType.VOTE_SKIP]               = "HandleVoteSkip",
    [Loothing.MsgType.SYNC_REQUEST]            = "HandleSyncRequest",
    [Loothing.MsgType.SYNC_DATA]               = "HandleSyncData",
    [Loothing.MsgType.COUNCIL_ROSTER]          = "HandleCouncilRoster",
    [Loothing.MsgType.OBSERVER_ROSTER]         = "HandleObserverRoster",
    [Loothing.MsgType.PLAYER_INFO_REQUEST]     = "HandlePlayerInfoRequest",
    [Loothing.MsgType.PLAYER_INFO_RESPONSE]    = "HandlePlayerInfoResponse",
    [Loothing.MsgType.PLAYER_RESPONSE]         = "HandlePlayerResponse",
    [Loothing.MsgType.RESPONSE_POLL]           = "HandleResponsePoll",
    [Loothing.MsgType.VOTE_POLL]               = "HandleVotePoll",
    [Loothing.MsgType.SYNC_INCREMENTAL]        = "HandleIncrementalSyncRequest",
    [Loothing.MsgType.SYNC_INCREMENTAL_DATA]   = "HandleIncrementalSyncData",
    [Loothing.MsgType.VERSION_REQUEST]         = "HandleVersionRequest",
    [Loothing.MsgType.VERSION_RESPONSE]        = "HandleVersionResponse",
    [Loothing.MsgType.MLDB_BROADCAST]          = "HandleMLDBBroadcast",
    [Loothing.MsgType.CANDIDATE_UPDATE]        = "HandleCandidateUpdate",
    [Loothing.MsgType.VOTE_UPDATE]             = "HandleVoteUpdate",
    [Loothing.MsgType.SYNC_SETTINGS_REQUEST]   = "HandleSettingsSyncRequest",
    [Loothing.MsgType.SYNC_SETTINGS_CONFIRM]   = "HandleSettingsSyncConfirm",
    [Loothing.MsgType.SYNC_SETTINGS_DATA]      = "HandleSettingsData",
    [Loothing.MsgType.SYNC_HISTORY_REQUEST]    = "HandleHistorySyncRequest",
    [Loothing.MsgType.SYNC_HISTORY_CONFIRM]    = "HandleHistorySyncConfirm",
    [Loothing.MsgType.SYNC_HISTORY_DATA]       = "HandleHistoryData",
    [Loothing.MsgType.PROFILE_EXPORT_SHARE]    = "HandleProfileExportShare",
    [Loothing.MsgType.XREALM]                  = "HandleXRealm",
    [Loothing.MsgType.STOP_HANDLE_LOOT]        = "HandleStopHandleLoot",
    [Loothing.MsgType.TRADABLE]                = "HandleTradable",
    [Loothing.MsgType.NON_TRADABLE]            = "HandleNonTradable",
    -- Burst / resilience infrastructure
    [Loothing.MsgType.BATCH]                   = "HandleBatch",
    [Loothing.MsgType.HEARTBEAT]               = "HandleHeartbeat",
    [Loothing.MsgType.HISTORY_ENTRY]           = "HandleHistoryEntry",
    -- Combined session setup
    [Loothing.MsgType.SESSION_INIT]            = "HandleSessionInit",
    -- Batched responses
    [Loothing.MsgType.RESPONSE_BATCH]          = "HandleResponseBatch",
    -- Desktop Intel Share
    [Loothing.MsgType.INTEL_SHARE_MANIFEST]    = "HandleIntelShareManifest",
    [Loothing.MsgType.INTEL_SHARE]             = "HandleIntelShareData",
}

--- Initialize communication handler
function CommMixin:Init()
    CallbackRegistryMixin.OnLoad(self)
    self:GenerateCallbackEvents(COMM_EVENTS)

    -- Register with Loolib.Comm for incoming addon messages
    -- Loolib.Comm handles: prefix registration, message reassembly, throttling
    Comm:RegisterComm(Loothing.ADDON_PREFIX, function(_prefix, message, distribution, sender)
        self:OnMessage(message, distribution, sender)
    end, self)
end

--- Get per-type comm statistics for diagnostics
-- @return table - { sent = {wireCode=count}, received = {wireCode=count}, dropped = {wireCode=count} }
function CommMixin:GetCommStats()
    return commStats
end

--- Get count of entries in the dedup table.
-- Returns the live counter maintained by OnMessage (O(1)) with a lazy
-- resync against the underlying table to correct any drift (e.g., after
-- a failed sweep or /reload mid-insert). Historically this was an O(N)
-- pairs iteration; the new counter keeps the hot path constant-time
-- while preserving observable behavior.
-- @return number
function CommMixin:GetSeenIDCount()
    -- Belt-and-braces: recompute if the counter is obviously wrong (negative
    -- or we're suspiciously at zero while the table has entries).
    if seenCount < 0 or (seenCount == 0 and next(seenIDs) ~= nil) then
        local count = 0
        for _ in pairs(seenIDs) do count = count + 1 end
        seenCount = count
    end
    return seenCount
end

--- Get count of active batch accumulator entries
-- @return number
function CommMixin:GetBatchAccumulatorCount()
    local count = 0
    for _ in pairs(batchAccumulator) do
        count = count + 1
    end
    return count
end

--- Return a chronologically-ordered list (oldest first) of recent decode
--- failures for /lt diag display. Bounded to DECODE_RING_SIZE entries.
--- @return table[] - { { ts, sender, reason, bytes, distribution }, ... }
function CommMixin:GetDecodeErrorRing()
    local out = {}
    if decodeRingCount == 0 then return out end

    -- Read in chronological order. decodeRingHead points at the next-write
    -- slot, so the oldest entry is at head when the ring is full, or at
    -- index 1 when still filling. Walk `count` entries from the oldest.
    local start
    if decodeRingCount < DECODE_RING_SIZE then
        start = 1
    else
        start = decodeRingHead  -- oldest: next overwrite target
    end

    for i = 0, decodeRingCount - 1 do
        local idx = ((start - 1 + i) % DECODE_RING_SIZE) + 1
        out[#out + 1] = decodeRing[idx]
    end
    return out
end

--[[--------------------------------------------------------------------
    Core Send / Receive
----------------------------------------------------------------------]]

--- Send a command + data to group or a specific player
---@param self table
---@param command string Loothing.MsgType value
---@param data table|nil Structured message payload
---@param target string|nil Player name for WHISPER, nil for group broadcast
---@param priority string|nil "ALERT", "NORMAL" (default), or "BULK"
function CommMixin.Send(self, command, data, target, priority)
    -- Self-send shortcut: if target is the local player, deliver locally instead of
    -- going through the WoW addon message network. Self-send always works — it
    -- bypasses WoW addon channels entirely, so combat/restriction blocking does not apply.
    if target then
        local localName = Utils.GetPlayerFullName()
        if localName and Utils.IsSamePlayer(target, localName) then
            local encoded = ns.Protocol:Encode(command, data)
            if not encoded then
                Loothing:Error("Comm:Send — Encode returned nil for", command, "(message dropped)")
                return
            end
            Loothing:Debug("Comm:Send — self-send shortcut for", command)
            C_Timer.After(0, function()
                self:OnMessage(encoded, "WHISPER", localName)
            end)
            commStats.sent[command] = (commStats.sent[command] or 0) + 1
            return
        end
    end

    -- CommState gate: encounter/challenge restrictions block addon messages.
    -- Combat does NOT block addon comms (confirmed by RCLC analysis of WoW 12.0).
    local prio = priority or "NORMAL"
    local CommState = Loothing.CommState
    if CommState and CommState:ShouldDefer(command, prio) then
        local state = CommState:GetState()
        if state == CommState.STATE_RESTRICTED then
            -- Critical commands → guaranteed queue (replayed when restrictions lift)
            if CommState:IsCriticalCommand(command) then
                if Loothing.Restrictions then
                    Loothing.Restrictions:QueueGuaranteed(command, data, target, prio)
                else
                    Loothing:Error("Comm:Send — Restrictions not loaded, critical message dropped:", command)
                    commStats.dropped[command] = (commStats.dropped[command] or 0) + 1
                end
            else
                -- Non-critical during restrictions: silently dropped
                commStats.dropped[command] = (commStats.dropped[command] or 0) + 1
            end
        else
            -- STATE_DISCONNECTED: silently dropped (ShouldDefer logged it)
            commStats.dropped[command] = (commStats.dropped[command] or 0) + 1
        end
        return
    end

    -- Encode (only for messages that will actually be sent now)
    local encoded = ns.Protocol:Encode(command, data)
    if not encoded then
        Loothing:Error("Comm:Send — Encode returned nil for", command, "(message dropped)")
        return
    end

    -- Progressive backpressure: graduated shedding based on transport queue pressure
    local pressure = Comm:GetQueuePressure()
    local isCritical = CRITICAL_COMMANDS[command]

    if not isCritical then
        if pressure > 0.7 then
            -- Heavy pressure: downgrade NORMAL→BULK, drop existing BULK
            if prio == "BULK" then
                Loothing:Debug("Comm:Send — dropping BULK under heavy pressure:", command)
                commStats.dropped[command] = (commStats.dropped[command] or 0) + 1
                self:TriggerEvent("OnMessageDropped", command, "heavy_pressure", target)
                return
            elseif prio == "NORMAL" then
                prio = "BULK"
            end
        elseif pressure > 0.5 then
            -- Moderate pressure: drop non-critical BULK
            if prio == "BULK" then
                Loothing:Debug("Comm:Send — dropping BULK under moderate pressure:", command)
                commStats.dropped[command] = (commStats.dropped[command] or 0) + 1
                self:TriggerEvent("OnMessageDropped", command, "moderate_pressure", target)
                return
            end
        elseif pressure > 0.3 then
            -- Light pressure: downgrade non-critical NORMAL→BULK
            if prio == "NORMAL" then
                prio = "BULK"
            end
        end
    end

    -- Group membership gate: don't WHISPER players who left the group.
    -- WoW returns GeneralError (9) / TargetOffline (12) for stale targets.
    if target and not Utils.IsGroupMember(target) then
        Loothing:Debug("Comm:Send — target left group, dropping WHISPER:",
            command, "->", target)
        commStats.dropped[command] = (commStats.dropped[command] or 0) + 1
        return
    end

    -- Compute a coalesceKey for idempotent whole-state messages so a fresh
    -- send supersedes any prior copy still in the Loolib queue. WHISPERs include
    -- the target so unicasts to different recipients don't collapse; broadcasts
    -- key on the command alone. See COALESCE_COMMANDS above for the allowlist.
    local coalesceKey = nil
    if COALESCE_COMMANDS[command] then
        coalesceKey = target and (command .. "|" .. target) or command
    end

    local queued
    if target then
        -- Resolve target to its roster-canonical casing. Utils.NormalizeName
        -- lowercases the realm for cache-key consistency across chat-server
        -- and API casing drift, but WoW's SendAddonMessage WHISPER rejects
        -- non-canonical realm casing with "No player named 'X' is currently
        -- playing". The canonical form comes from the raid/party roster API.
        local whisperTarget = Utils.CanonicalizeGroupMemberName(target) or target
        queued = Comm:SendCommMessage(Loothing.ADDON_PREFIX, encoded, "WHISPER",
            whisperTarget, prio, nil, nil, coalesceKey)
    else
        local channel = IsInRaid() and "RAID" or "PARTY"
        queued = Comm:SendCommMessage(Loothing.ADDON_PREFIX, encoded, channel,
            nil, prio, nil, nil, coalesceKey)
    end

    -- Loolib.Comm returns false when it drops under queue pressure (BULK only
    -- today). Count those as dropped so /lt diag stats reflect reality instead
    -- of reporting a send that never left the client.
    if queued == false then
        commStats.dropped[command] = (commStats.dropped[command] or 0) + 1
        self:TriggerEvent("OnMessageDropped", command, "loolib_queue_full", target)
    else
        commStats.sent[command] = (commStats.sent[command] or 0) + 1
        -- TestMode intercept fires only on successful queue so test-mode stats
        -- match production stats (a queue-full drop is not an "outgoing" event).
        if TestMode and TestMode.OnOutgoingComm then
            local channel = target and "WHISPER" or (IsInRaid() and "RAID" or "PARTY")
            TestMode:OnOutgoingComm(channel, target)
        end
    end
end

--[[--------------------------------------------------------------------
    Send Batcher (Phase 3B)
    Accumulates messages over a 100 ms window then flushes as a single
    BATCH message. Single-message bursts bypass the BATCH wrapper.
----------------------------------------------------------------------]]

--- Queue a message for batched delivery
-- Callers should call FlushAll() when the burst is complete to drain
-- immediately; otherwise the 100 ms window timer fires automatically.
-- @param command string - Loothing.MsgType value
-- @param data table|nil - Message payload
-- @param target string|nil - Player name or nil for broadcast
-- @param priority string|nil - "ALERT", "NORMAL", or "BULK"
function CommMixin:QueueForBatch(command, data, target, priority)
    local key   = GetBatchKey(target, priority)
    local batch = batchAccumulator[key]

    if not batch then
        -- Use TempTable pool for the messages array to avoid GC pressure.
        -- Released in FlushBatch after Send() returns (Send is synchronous).
        -- Leak check: /run Loolib.TempTable:PrintLeaks()
        local messages = Loolib.TempTable:Acquire()
        batch = { messages = messages, target = target, priority = priority }
        batchAccumulator[key] = batch

        -- Schedule automatic flush at end of collection window
        C_Timer.After(BATCH_WINDOW, function()
            if batchAccumulator[key] then
                self:FlushBatch(key)
            end
        end)
    end

    batch.messages[#batch.messages + 1] = { command = command, data = data }

    -- Eagerly flush when the batch is full
    if #batch.messages >= MAX_BATCH_SIZE then
        self:FlushBatch(key)
    end
end

--- Flush a pending batch immediately
-- @param key string - Batch key from GetBatchKey
function CommMixin:FlushBatch(key)
    local batch = batchAccumulator[key]
    if not batch then return end
    batchAccumulator[key] = nil

    local messages = batch.messages

    if #messages == 0 then
        Loolib.TempTable:Release(messages)
        return
    end

    -- Single message: bypass BATCH wrapper (no overhead).
    if #messages == 1 then
        local inner = messages[1]
        local cmd, dat = inner.command, inner.data
        Loolib.TempTable:Release(messages)
        self:Send(cmd, dat, batch.target, batch.priority)
        return
    end

    -- Multiple messages: wrap in BATCH container.
    local messagesCopy = {}
    for i, msg in ipairs(messages) do
        messagesCopy[i] = msg
    end
    Loolib.TempTable:Release(messages)

    self:Send(Loothing.MsgType.BATCH, { messages = messagesCopy }, batch.target, batch.priority)
end

--- Flush all pending batches immediately
function CommMixin:FlushAll()
    -- Collect keys first to avoid modifying table during iteration
    local keys = {}
    for k in pairs(batchAccumulator) do
        keys[#keys + 1] = k
    end
    for _, k in ipairs(keys) do
        self:FlushBatch(k)
    end
end

--- Reset module-scoped comm state that should not survive session end.
-- Drains pending batches so queued messages still get delivered with the
-- correct session context, and belt-and-braces releases any TempTable
-- allocations that a racing 100ms flush timer left behind.
-- `seenIDs` is intentionally NOT wiped: it is a cross-session replay
-- shield (bounded by the 30s sweep + 120s TTL), and wiping it would open
-- a replay-acceptance window for all inbound comms, not just session
-- messages. Safe to call multiple times.
function CommMixin:ResetSessionState()
    -- Drain batches into real sends before session identifiers are nilled.
    self:FlushAll()

    -- Paranoia: release any TempTable that somehow survived FlushAll.
    -- Under current single-threaded semantics this loop is dead code
    -- (FlushBatch nils its key before Send, timers cannot preempt), but
    -- keeping it guards against a future code path that could leak.
    for k, batch in pairs(batchAccumulator) do
        if batch and batch.messages then
            Loolib.TempTable:Release(batch.messages)
        end
        batchAccumulator[k] = nil
    end
end

--- Send a command to the guild channel
-- @param command string - Loothing.MsgType value
-- @param data table|nil - Message payload
-- @param priority string|nil
function CommMixin:SendGuild(command, data, priority)
    if not IsInGuild() then
        Loothing:Debug("Cannot send to GUILD: not in a guild")
        return
    end

    -- CommState gate: encounter restrictions block addon messages.
    -- Guild messages are non-critical and user-initiated, so we drop them
    -- during restrictions rather than queue.
    local prio = priority or "NORMAL"
    local CommState = Loothing.CommState
    if CommState and CommState:ShouldDefer(command, prio) then
        Loothing:Debug("SendGuild: dropped during restriction:", command)
        commStats.dropped[command] = (commStats.dropped[command] or 0) + 1
        return
    end

    local encoded = ns.Protocol:Encode(command, data)
    if not encoded then
        Loothing:Error("Comm:SendGuild — Encode returned nil for", command, "(message dropped)")
        return
    end

    -- Guild channel supports coalescing on the same allowlist. VERSION_RESPONSE
    -- broadcasts to guild often arrive as bursts (many clients requesting at once).
    local coalesceKey = nil
    if COALESCE_COMMANDS[command] then
        coalesceKey = "GUILD|" .. command
    end

    local queued = Comm:SendCommMessage(Loothing.ADDON_PREFIX, encoded, "GUILD",
        nil, prio, nil, nil, coalesceKey)
    if queued == false then
        commStats.dropped[command] = (commStats.dropped[command] or 0) + 1
        -- Parity with CommMixin.Send: emit OnMessageDropped so subscribers
        -- that wire retries / alerts see guild drops, not just /lt diag stats.
        self:TriggerEvent("OnMessageDropped", command, "loolib_queue_full", nil)
    else
        commStats.sent[command] = (commStats.sent[command] or 0) + 1
        -- Test-mode only records successful queueing (matches Send parity).
        if TestMode and TestMode.OnOutgoingComm then
            TestMode:OnOutgoingComm("GUILD", nil)
        end
    end
end

--- Send with guaranteed delivery (queued during encounter restrictions)
-- Critical messages (votes, awards, session_end) should use this.
-- @param command string - Loothing.MsgType value
-- @param data table|nil - Message payload
-- @param target string|nil - Player name or nil for group
-- @param priority string|nil
function CommMixin:SendGuaranteed(command, data, target, priority)
    -- Queue during encounter/challenge restrictions (RCLC pattern).
    -- Combat does NOT block addon comms — only encounter restrictions do.
    if Loothing.Restrictions and Loothing.Restrictions:IsRestricted() then
        Loothing.Restrictions:QueueGuaranteed(command, data, target, priority)
        Loothing:Debug("Comm restricted, queued guaranteed:", command)
        return
    end

    self:Send(command, data, target, priority)
end

--[[--------------------------------------------------------------------
    Message Receiving
----------------------------------------------------------------------]]

--- Handle incoming addon message (Loolib.Comm callback)
-- @param message string - Encoded message (already reassembled if multi-part)
-- @param distribution string - Channel received on
-- @param sender string - Sender name
function CommMixin:OnMessage(message, distribution, sender)
    -- Decode message (msgID is nil for v3 senders — dedup key falls back to
    -- a content hash so a forged v3-formatted replay still dedups)
    local version, command, data, msgID, failReason = ns.Protocol:Decode(message)

    if not version or not command then
        -- Record a structured entry for /lt diag. Just counting errors leaves
        -- us blind to whether 126 drops were from one spammer or a system-wide
        -- corruption problem; the ring answers that next time.
        RecordDecodeFailure(sender, failReason, message and #message or 0, distribution)
        Loothing:Debug("Failed to decode message from", sender, "reason=" .. tostring(failReason))
        return
    end

    -- Version check (lower bound): reject legacy-format payloads below
    -- MIN_PROTOCOL_VERSION. A forged v2-or-earlier message that happens to
    -- pass the Adler-32 check could otherwise reach handlers with a
    -- structurally-wrong payload shape. Upper-bound newer-version
    -- messages are still attempted — protocol additions are expected to
    -- be backwards-compatible at the schema level.
    if version < Loothing.MIN_PROTOCOL_VERSION then
        Loothing:Debug("Rejected message with obsolete protocol version:", version, "from", sender)
        return
    end
    if version > Loothing.PROTOCOL_VERSION then
        Loothing:Debug("Received message from newer protocol version:", version, "from", sender)
        -- Still try to process - might be backwards compatible
    end

    -- Normalize sender name
    sender = Utils.NormalizeName(sender)

    -- Replay protection: deduplicate by sender+msgID (Protocol v4+) or by a
    -- content hash of the encoded blob for legacy v3 senders. A v3 forgery
    -- that would previously slip past dedup entirely now collides with itself
    -- via the hash; dedup window is SEEN_TTL (120s) either way.
    local now = GetTime()
    local dedupKey
    if msgID then
        dedupKey = sender .. "-v4-" .. msgID
    else
        local hash = Loolib.Compressor and Loolib.Compressor.Adler32
            and Loolib.Compressor:Adler32(message or "") or 0
        dedupKey = sender .. "-v3-" .. tostring(hash) .. "-" .. tostring(#(message or ""))
    end

    if seenIDs[dedupKey] then
        Loothing:Debug("Dropped duplicate", command, "from", sender,
            "msgID=", tostring(msgID or "(v3-hash)"))
        commStats.dropped[command] = (commStats.dropped[command] or 0) + 1
        return
    end

    -- Periodic sweep: remove entries older than SEEN_TTL (runs every 30s).
    -- Decrement seenCount as entries are purged so overflow detection stays
    -- accurate; pre-cap check below relies on this count.
    if now - lastCleanup > 30 then
        lastCleanup = now
        for k, t in pairs(seenIDs) do
            if now - t > SEEN_TTL then
                seenIDs[k] = nil
                seenCount = seenCount - 1
            end
        end
    end

    -- Anti-DoS cap: if we're at capacity, force an immediate expired-sweep
    -- (in case the periodic sweep hasn't run yet). If we're still over cap
    -- after that, evict the oldest SEEN_EVICT_BATCH entries by timestamp.
    -- This preserves dedup correctness for recent messages while bounding
    -- memory under a forged-msgID flood.
    if seenCount >= SEEN_MAX_ENTRIES then
        for k, t in pairs(seenIDs) do
            if now - t > SEEN_TTL then
                seenIDs[k] = nil
                seenCount = seenCount - 1
            end
        end
        if seenCount >= SEEN_MAX_ENTRIES then
            -- Collect timestamps, sort ascending, evict the oldest batch.
            local entries = {}
            for k, t in pairs(seenIDs) do
                entries[#entries + 1] = { k = k, t = t }
            end
            table.sort(entries, function(a, b) return a.t < b.t end)
            local evict = math.min(SEEN_EVICT_BATCH, #entries)
            for i = 1, evict do
                seenIDs[entries[i].k] = nil
                seenCount = seenCount - 1
            end
            Loothing:Debug("seenIDs DoS guard: evicted", evict,
                "oldest entries (cap=" .. SEEN_MAX_ENTRIES .. ")")
        end
    end

    seenIDs[dedupKey] = now
    seenCount         = seenCount + 1

    -- Route to handler
    self:RouteMessage(command, data, sender, distribution)
end

--- Route a decoded message to appropriate handler
-- @param command string - Loothing.MsgType value
-- @param data table - Deserialized message data
-- @param sender string - Normalized sender name
-- @param distribution string - Channel
function CommMixin:RouteMessage(command, data, sender, distribution)
    Loothing:Debug("Received:", command, "from", sender)
    commStats.received[command] = (commStats.received[command] or 0) + 1

    local handlerName = HANDLERS[command]
    if handlerName and self[handlerName] then
        self[handlerName](self, data, sender, distribution)
    else
        Loothing:Debug("Unknown message type:", command)
    end
end

--[[--------------------------------------------------------------------
    Cross-Realm Handler
----------------------------------------------------------------------]]

--- Handle cross-realm relay messages
-- Unwrap the envelope and route to the inner command if we're the target.
-- @param data table - { target, command, data }
-- @param sender string
-- @param distribution string
function CommMixin:HandleXRealm(data, sender, _distribution)
    if not data or not data.target then return end

    -- Prevent recursive processing: inner message must not be XREALM or BATCH
    if data.command == Loothing.MsgType.XREALM or data.command == Loothing.MsgType.BATCH then
        Loothing:Debug("HandleXRealm: blocked recursive", data.command, "from", sender)
        return
    end

    local localName = Utils.GetPlayerFullName()
    if not Utils.IsSamePlayer(data.target, localName) then
        return -- Not for us
    end

    -- Unwrap and route the inner message
    if data.command then
        self:RouteMessage(data.command, data.data, sender, "XREALM")
    end
end

--[[--------------------------------------------------------------------
    Broadcast Helpers - Session Management
----------------------------------------------------------------------]]

--- Broadcast combined session initialization (SS + MLDB + CR + items)
-- @param sessionData table - { sessionStart, mldb, councilRoster, items }
function CommMixin:BroadcastSessionInit(sessionData)
    self:Send(Loothing.MsgType.SESSION_INIT, sessionData)
end

--- Broadcast SESSION_START. Dirty-checks by sessionID to prevent duplicate
--- steady-state broadcasts, but new raid members joining mid-session need
--- the announcement — roster-driven callers MUST pass force=true because
--- the cache is payload-only, not recipient-aware.
--- @param encounterID number
--- @param encounterName string
--- @param sessionID string
--- @param force boolean? - Bypass the dirty check (new-member audience)
function CommMixin:BroadcastSessionStart(encounterID, encounterName, sessionID, force)
    if not force and sessionID and self._lastSessionStartID == sessionID then
        Loothing:Debug("BroadcastSessionStart skipped: sessionID", sessionID, "already announced")
        return
    end
    self._lastSessionStartID = sessionID

    self:Send(Loothing.MsgType.SESSION_START, {
        encounterID = encounterID,
        encounterName = encounterName,
        sessionID = sessionID,
    })
end

--- Clear the SESSION_START dirty-check cache. Call when session ends so the
--- next SessionStart goes out regardless.
function CommMixin:InvalidateSessionStartCache()
    self._lastSessionStartID = nil
end

--- Broadcast session end
-- @param sessionID string|nil - Session ID for validation on receivers
function CommMixin:BroadcastSessionEnd(sessionID)
    self:Send(Loothing.MsgType.SESSION_END, {
        sessionID = sessionID,
    })
end

--- Broadcast that ML has stopped handling loot entirely
function CommMixin:BroadcastStopHandleLoot()
    self:Send(Loothing.MsgType.STOP_HANDLE_LOOT, {})
end

--- Broadcast item added
-- @param itemLink string
-- @param guid string
-- @param looter string
function CommMixin:BroadcastItemAdd(itemLink, guid, looter, sessionID)
    self:Send(Loothing.MsgType.ITEM_ADD, {
        itemLink = itemLink,
        guid = guid,
        looter = looter,
        sessionID = sessionID,
    })
end

--- Broadcast item removed
-- @param guid string
-- @param sessionID string
function CommMixin:BroadcastItemRemove(guid, sessionID)
    self:Send(Loothing.MsgType.ITEM_REMOVE, {
        guid = guid,
        sessionID = sessionID,
    })
end

--[[--------------------------------------------------------------------
    Broadcast Helpers - Voting
----------------------------------------------------------------------]]

--- Broadcast vote request
-- @param itemGUID string
-- @param timeout number
-- @param sessionID string|nil
function CommMixin:BroadcastVoteRequest(itemGUID, timeout, sessionID)
    self:Send(Loothing.MsgType.VOTE_REQUEST, {
        itemGUID = itemGUID,
        timeout = timeout,
        sessionID = sessionID,
    })
end

--- Send vote commit (broadcast to group — all council members tally locally)
-- @param itemGUID string
-- @param responses table
-- @param masterLooter string (unused, kept for API compat)
-- @param sessionID string|nil
function CommMixin:SendVoteCommit(itemGUID, responses, masterLooter, sessionID)
    self:Send(Loothing.MsgType.VOTE_COMMIT, {
        itemGUID = itemGUID,
        responses = responses,
        sessionID = sessionID,
    })
end

--- Broadcast vote award
-- @param itemGUID string
-- @param winnerName string
-- @param sessionID string|nil
function CommMixin:BroadcastVoteAward(itemGUID, winnerName, sessionID)
    self:Send(Loothing.MsgType.VOTE_AWARD, {
        itemGUID = itemGUID,
        winner = winnerName,
        sessionID = sessionID,
    })
end

--- Broadcast vote skip
-- @param itemGUID string
-- @param sessionID string|nil
function CommMixin:BroadcastVoteSkip(itemGUID, sessionID)
    self:Send(Loothing.MsgType.VOTE_SKIP, {
        itemGUID = itemGUID,
        sessionID = sessionID,
    })
end

--- Broadcast vote cancellation
-- @param itemGUID string
-- @param sessionID string|nil
function CommMixin:BroadcastVoteCancel(itemGUID, sessionID)
    self:Send(Loothing.MsgType.VOTE_CANCEL, {
        itemGUID = itemGUID,
        sessionID = sessionID,
    })
end

--- Broadcast vote results/closure
-- @param itemGUID string
-- @param results table
-- @param sessionID string|nil
function CommMixin:BroadcastVoteResults(itemGUID, results, sessionID)
    self:Send(Loothing.MsgType.VOTE_RESULTS, {
        itemGUID = itemGUID,
        results = results,
        sessionID = sessionID,
    })
end

--[[--------------------------------------------------------------------
    Broadcast Helpers - Council & Sync
----------------------------------------------------------------------]]

--- Broadcast council roster
-- @param members table
function CommMixin:BroadcastCouncilRoster(members)
    self:Send(Loothing.MsgType.COUNCIL_ROSTER, {
        members = members,
    })
end

--- Request sync from ML
-- @param masterLooter string
function CommMixin:RequestSync(masterLooter)
    self:Send(Loothing.MsgType.SYNC_REQUEST, {
        timestamp = time(),
    }, masterLooter)
end

--- Send sync data to requester
-- @param sessionData table
-- @param target string
function CommMixin:SendSyncData(sessionData, target)
    self:Send(Loothing.MsgType.SYNC_DATA, sessionData, target)
end

--[[--------------------------------------------------------------------
    Broadcast Helpers - Player Info & Responses
----------------------------------------------------------------------]]

--- Request player info (gear comparison)
-- @param itemGUID string
-- @param playerName string
function CommMixin:RequestPlayerInfo(itemGUID, playerName)
    self:Send(Loothing.MsgType.PLAYER_INFO_REQUEST, {
        itemGUID = itemGUID,
        playerName = playerName,
    }, playerName)
end

--- Send player info response
-- @param itemGUID string
-- @param slot1Link string|nil
-- @param slot2Link string|nil
-- @param slot1ilvl number
-- @param slot2ilvl number
-- @param target string
-- @param sessionID string|nil
function CommMixin:SendPlayerInfo(itemGUID, slot1Link, slot2Link, slot1ilvl, slot2ilvl, target, sessionID)
    self:Send(Loothing.MsgType.PLAYER_INFO_RESPONSE, {
        itemGUID = itemGUID,
        slot1Link = slot1Link,
        slot2Link = slot2Link,
        slot1ilvl = slot1ilvl or 0,
        slot2ilvl = slot2ilvl or 0,
        sessionID = sessionID,
    }, target)
end

--- Send player response (raid member -> ML or assigned processor)
-- @param itemGUID string
-- @param response number|string - Loothing.Response or SystemResponse value
-- @param note string|nil
-- @param roll number|nil
-- @param rollMin number|nil
-- @param rollMax number|nil
-- @param masterLooter string
-- @param sessionID string|nil
-- @param gear1Link string|nil - Equipped gear slot 1 link (self-report)
-- @param gear2Link string|nil - Equipped gear slot 2 link (self-report)
-- @param gear1ilvl number|nil - Equipped gear slot 1 item level
-- @param gear2ilvl number|nil - Equipped gear slot 2 item level
function CommMixin:SendPlayerResponse(itemGUID, response, note, roll, rollMin, rollMax,
                                       masterLooter, sessionID, gear1Link, gear2Link,
                                       gear1ilvl, gear2ilvl)
    local payload = {
        itemGUID = itemGUID,
        response = response,
        note = note ~= "" and note or nil,
        roll = roll,
        rollMin = rollMin or 1,
        rollMax = rollMax or 100,
        playerName = Utils.GetPlayerFullName(),
        sessionID = sessionID,
        -- Gear self-report (eliminates PLAYER_INFO round-trip)
        gear1Link = gear1Link,
        gear2Link = gear2Link,
        gear1ilvl = gear1ilvl or 0,
        gear2ilvl = gear2ilvl or 0,
    }

    -- Self-loopback: when the ML is responding to their own session,
    -- bypass the network entirely. WHISPER-to-self through the throttled
    -- comm queue is unreliable (backpressure, self-delivery quirks).
    local isTestMode = TestMode and TestMode:IsEnabled()
    local isSelfSend = masterLooter and Utils.IsSamePlayer(masterLooter, Utils.GetPlayerFullName())
    if isTestMode or isSelfSend then
        if Loothing.Session then
            Loothing.Session:HandlePlayerResponse(payload)
        end
        return
    end

    -- Broadcast to group so ML + council all receive immediately
    self:Send(Loothing.MsgType.PLAYER_RESPONSE, {
        itemGUID = itemGUID,
        response = response,
        note = note ~= "" and note or nil,
        roll = roll,
        rollMin = rollMin or 1,
        rollMax = rollMax or 100,
        sessionID = sessionID,
        gear1Link = gear1Link,
        gear2Link = gear2Link,
        gear1ilvl = gear1ilvl or 0,
        gear2ilvl = gear2ilvl or 0,
    }, nil, "ALERT")
end

--- Send batched player responses (all items in one message)
-- @param responses table - Array of {itemGUID, response, note, roll, rollMin, rollMax, gear1Link, gear2Link, gear1ilvl, gear2ilvl}
-- @param masterLooter string
-- @param sessionID string|nil
function CommMixin:SendResponseBatch(responses, masterLooter, sessionID)
    -- Broadcast to group so ML + council all receive immediately
    self:Send(Loothing.MsgType.RESPONSE_BATCH, {
        responses = responses,
        sessionID = sessionID,
        playerName = Utils.GetPlayerFullName(),
    }, nil, "ALERT")
end

--[[--------------------------------------------------------------------
    Broadcast Helpers - Candidate & Vote Updates
----------------------------------------------------------------------]]

--- Broadcast candidate update (ML -> Council)
-- @param itemGUID string
-- @param candidateData table
-- @param sessionID string|nil
function CommMixin:BroadcastCandidateUpdate(itemGUID, candidateData, sessionID)
    self:Send(Loothing.MsgType.CANDIDATE_UPDATE, {
        itemGUID = itemGUID,
        candidateData = candidateData,
        sessionID = sessionID,
    })
end


--[[--------------------------------------------------------------------
    Broadcast Helpers - MLDB & Version
----------------------------------------------------------------------]]

--- Broadcast MLDB (Master Looter Database)
-- @param mldbData table - Compressed MLDB data
function CommMixin:BroadcastMLDB(mldbData)
    self:Send(Loothing.MsgType.MLDB_BROADCAST, {
        data = mldbData,
    })
end

--- Send version request
-- @param target string|nil - "guild" for guild, nil for group, or player name
function CommMixin:SendVersionRequest(target)
    if target == "guild" then
        self:SendGuild(Loothing.MsgType.VERSION_REQUEST, {})
    elseif target then
        self:Send(Loothing.MsgType.VERSION_REQUEST, {}, target)
    else
        self:Send(Loothing.MsgType.VERSION_REQUEST, {})
    end
end

--- Send version response
-- @param target string - Player to respond to
function CommMixin:SendVersionResponse(target)
    local _, equippedIlvl = GetAverageItemLevel()
    local specID
    local specIndex = GetSpecialization and GetSpecialization()
    if specIndex then
        local getInfo = C_SpecializationInfo and C_SpecializationInfo.GetSpecializationInfo or GetSpecializationInfo
        if getInfo then
            specID = getInfo(specIndex)
        end
    end

    self:Send(Loothing.MsgType.VERSION_RESPONSE, {
        version = Loothing.VERSION,
        tVersion = ns.VersionCheck and ns.VersionCheck.tVersion or nil,
        ilvl = equippedIlvl and equippedIlvl > 0 and equippedIlvl or nil,
        specID = specID,
    }, target)
end

--[[--------------------------------------------------------------------
    Broadcast Helpers - Sync (Settings & History)
----------------------------------------------------------------------]]

--- Send settings sync request
-- @param target string - "guild" or player name
function CommMixin:SendSettingsSyncRequest(target)
    if target == "guild" then
        self:SendGuild(Loothing.MsgType.SYNC_SETTINGS_REQUEST, {})
    else
        self:Send(Loothing.MsgType.SYNC_SETTINGS_REQUEST, {}, target)
    end
end

--- Send settings sync confirmation
-- @param target string
function CommMixin:SendSettingsSyncConfirm(target)
    self:Send(Loothing.MsgType.SYNC_SETTINGS_CONFIRM, {}, target)
end

--- Send settings data
-- @param settingsData table - Serialized settings
-- @param target string
function CommMixin:SendSettingsData(settingsData, target)
    self:Send(Loothing.MsgType.SYNC_SETTINGS_DATA, {
        data = settingsData,
    }, target, "BULK")
end

--- Send history sync request
-- @param target string - "guild" or player name
-- @param days number
function CommMixin:SendHistorySyncRequest(target, days)
    if target == "guild" then
        self:SendGuild(Loothing.MsgType.SYNC_HISTORY_REQUEST, { days = days })
    else
        self:Send(Loothing.MsgType.SYNC_HISTORY_REQUEST, { days = days }, target)
    end
end

--- Send history sync confirmation
-- @param target string
function CommMixin:SendHistorySyncConfirm(target)
    self:Send(Loothing.MsgType.SYNC_HISTORY_CONFIRM, {}, target)
end

--- Send history data
-- @param historyData table - History entries
-- @param target string
function CommMixin:SendHistoryData(historyData, target)
    self:Send(Loothing.MsgType.SYNC_HISTORY_DATA, {
        data = historyData,
    }, target, "BULK")
end

--- Send a shareable settings export string directly to another player.
-- @param exportString string
-- @param target string
-- @param options table|nil
function CommMixin:SendProfileExport(exportString, target, options)
    options = options or {}
    self:Send(Loothing.MsgType.PROFILE_EXPORT_SHARE, {
        exportString = exportString,
        shareID = options.shareID,
        scope = options.scope,
        sessionID = options.sessionID,
    }, target, "BULK")
end

--- Broadcast a shareable settings export string to the active raid/party.
-- @param exportString string
-- @param shareID string
-- @param sessionID string|nil
function CommMixin:BroadcastProfileExport(exportString, shareID, sessionID)
    self:Send(Loothing.MsgType.PROFILE_EXPORT_SHARE, {
        exportString = exportString,
        shareID = shareID,
        scope = "group",
        sessionID = sessionID,
    }, nil, "BULK")
end

-- ns.CommMixin exported above
