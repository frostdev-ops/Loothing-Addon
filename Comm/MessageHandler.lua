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
    "OnPlayerResponseAck",
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
    "OnClientReady",
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
local seenIDs    = {}
local SEEN_TTL   = 120
local lastCleanup = 0

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
    [Loothing.MsgType.PLAYER_RESPONSE_ACK]     = "HandlePlayerResponseAck",
    [Loothing.MsgType.RESPONSE_POLL]           = "HandleResponsePoll",
    [Loothing.MsgType.VOTE_POLL]               = "HandleVotePoll",
    [Loothing.MsgType.SYNC_INCREMENTAL]        = "HandleIncrementalSyncRequest",
    [Loothing.MsgType.SYNC_INCREMENTAL_DATA]   = "HandleIncrementalSyncData",
    [Loothing.MsgType.CLIENT_READY]            = "HandleClientReady",
    [Loothing.MsgType.VERSION_REQUEST]         = "HandleVersionRequest",
    [Loothing.MsgType.VERSION_RESPONSE]        = "HandleVersionResponse",
    [Loothing.MsgType.MLDB_BROADCAST]          = "HandleMLDBBroadcast",
    [Loothing.MsgType.CANDIDATE_UPDATE]        = "HandleCandidateUpdate",
    [Loothing.MsgType.VOTE_UPDATE]             = "HandleVoteUpdate",
    [Loothing.MsgType.SYNC_SETTINGS_REQUEST]   = "HandleSettingsSyncRequest",
    [Loothing.MsgType.SYNC_SETTINGS_ACK]       = "HandleSettingsSyncAck",
    [Loothing.MsgType.SYNC_SETTINGS_DATA]      = "HandleSettingsData",
    [Loothing.MsgType.SYNC_HISTORY_REQUEST]    = "HandleHistorySyncRequest",
    [Loothing.MsgType.SYNC_HISTORY_ACK]        = "HandleHistorySyncAck",
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
                end
            end
            -- Non-critical during restrictions: silently dropped
        end
        -- STATE_DISCONNECTED: silently dropped (ShouldDefer logged it)
        return
    end

    -- Encode (only for messages that will actually be sent now)
    local encoded = ns.Protocol:Encode(command, data)
    if not encoded then
        Loothing:Error("Comm:Send — Encode returned nil for", command, "(message dropped)")
        return
    end

    -- Test mode intercept
    if TestMode and TestMode.OnOutgoingComm then
        local channel = target and "WHISPER" or (IsInRaid() and "RAID" or "PARTY")
        TestMode:OnOutgoingComm(channel, target)
    end

    -- Progressive backpressure: graduated shedding based on transport queue pressure
    local pressure = Comm:GetQueuePressure()
    local isCritical = CRITICAL_COMMANDS[command]

    if not isCritical then
        if pressure > 0.7 then
            -- Heavy pressure: downgrade NORMAL→BULK, drop existing BULK
            if prio == "BULK" then
                Loothing:Debug("Comm:Send — dropping BULK under heavy pressure:", command)
                self:TriggerEvent("OnMessageDropped", command, "heavy_pressure", target)
                return
            elseif prio == "NORMAL" then
                prio = "BULK"
            end
        elseif pressure > 0.5 then
            -- Moderate pressure: drop non-critical BULK
            if prio == "BULK" then
                Loothing:Debug("Comm:Send — dropping BULK under moderate pressure:", command)
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
        return
    end

    if target then
        Comm:SendCommMessage(Loothing.ADDON_PREFIX, encoded, "WHISPER", target, prio)
    else
        local channel = IsInRaid() and "RAID" or "PARTY"
        Comm:SendCommMessage(Loothing.ADDON_PREFIX, encoded, channel, nil, prio)
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
        return
    end

    local encoded = ns.Protocol:Encode(command, data)
    if not encoded then
        Loothing:Error("Comm:SendGuild — Encode returned nil for", command, "(message dropped)")
        return
    end

    if TestMode and TestMode.OnOutgoingComm then
        TestMode:OnOutgoingComm("GUILD", nil)
    end

    Comm:SendCommMessage(Loothing.ADDON_PREFIX, encoded, "GUILD", nil, prio)
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

--- Send via cross-realm relay (group channel with target envelope)
-- Use when direct whisper to a cross-realm player fails or is unreliable.
-- @param command string - Loothing.MsgType value
-- @param data table|nil - Message payload
-- @param target string - Target player name (with realm suffix)
-- @param priority string|nil
function CommMixin:SendViaRelay(command, data, target, priority)
    self:Send(Loothing.MsgType.XREALM, {
        target = target,
        command = command,
        data = data,
    }, nil, priority)
end

--[[--------------------------------------------------------------------
    Message Receiving
----------------------------------------------------------------------]]

--- Handle incoming addon message (Loolib.Comm callback)
-- @param message string - Encoded message (already reassembled if multi-part)
-- @param distribution string - Channel received on
-- @param sender string - Sender name
function CommMixin:OnMessage(message, distribution, sender)
    -- Decode message (msgID is nil for v3 senders — dedup skipped for legacy peers)
    local version, command, data, msgID = ns.Protocol:Decode(message)

    if not version or not command then
        Loothing:Debug("Failed to decode message from", sender)
        return
    end

    -- Version check
    if version > Loothing.PROTOCOL_VERSION then
        Loothing:Debug("Received message from newer protocol version:", version, "from", sender)
        -- Still try to process - might be backwards compatible
    end

    -- Normalize sender name
    sender = Utils.NormalizeName(sender)

    -- Replay protection: deduplicate by sender+msgID (Protocol v4+).
    -- v3 senders have msgID=nil; we skip dedup to stay backward compatible.
    if msgID then
        local now = GetTime()
        local dedupKey = sender .. "-" .. msgID
        if seenIDs[dedupKey] then
            Loothing:Debug("Dropped duplicate", command, "from", sender, "msgID=", msgID)
            return
        end
        seenIDs[dedupKey] = now

        -- Periodic sweep: remove entries older than SEEN_TTL (runs every 30s)
        if now - lastCleanup > 30 then
            lastCleanup = now
            for k, t in pairs(seenIDs) do
                if now - t > SEEN_TTL then
                    seenIDs[k] = nil
                end
            end
        end
    end

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

function CommMixin:BroadcastSessionStart(encounterID, encounterName, sessionID)
    self:Send(Loothing.MsgType.SESSION_START, {
        encounterID = encounterID,
        encounterName = encounterName,
        sessionID = sessionID,
    })
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
    -- Deferred one frame so RollFrame:StartAckTimeout() runs before the ACK arrives.
    local isTestMode = TestMode and TestMode:IsEnabled()
    local isSelfSend = masterLooter and Utils.IsSamePlayer(masterLooter, Utils.GetPlayerFullName())
    if isTestMode or isSelfSend then
        C_Timer.After(0, function()
            if Loothing.Session then
                Loothing.Session:HandlePlayerResponse(payload)
            end
        end)
        return
    end

    self:SendGuaranteed(Loothing.MsgType.PLAYER_RESPONSE, {
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
    }, masterLooter)
end

--- Send batched player responses (all items in one message)
-- @param responses table - Array of {itemGUID, response, note, roll, rollMin, rollMax, gear1Link, gear2Link, gear1ilvl, gear2ilvl}
-- @param masterLooter string
-- @param sessionID string|nil
function CommMixin:SendResponseBatch(responses, masterLooter, sessionID)
    self:SendGuaranteed(Loothing.MsgType.RESPONSE_BATCH, {
        responses = responses,
        sessionID = sessionID,
        playerName = Utils.GetPlayerFullName(),
    }, masterLooter)
end

--- Send player response acknowledgment (ML -> raid member)
-- @param itemGUID string
-- @param success boolean
-- @param target string
-- @param sessionID string|nil
function CommMixin:SendPlayerResponseAck(itemGUID, success, target, sessionID)
    -- Self-loopback: when ML sends ACK to themselves, bypass network.
    local isTestMode = TestMode and TestMode:IsEnabled()
    local isSelfSend = target and Utils.IsSamePlayer(target, Utils.GetPlayerFullName())
    if isTestMode or isSelfSend then
        local payload = {
            itemGUID = itemGUID,
            success = success,
            sessionID = sessionID,
            masterLooter = Utils.GetPlayerFullName(),
        }
        C_Timer.After(0, function()
            if Loothing.Session then
                Loothing.Session:HandlePlayerResponseAck(payload)
            end
        end)
        return
    end

    self:Send(Loothing.MsgType.PLAYER_RESPONSE_ACK, {
        itemGUID = itemGUID,
        success = success,
        sessionID = sessionID,
    }, target, "ALERT")
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

--- Broadcast vote update (ML -> Council)
-- @param itemGUID string
-- @param candidateName string
-- @param voters table
-- @param sessionID string|nil
function CommMixin:BroadcastVoteUpdate(itemGUID, candidateName, voters, sessionID)
    self:Send(Loothing.MsgType.VOTE_UPDATE, {
        itemGUID = itemGUID,
        candidateName = candidateName,
        voters = voters,
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
    if specIndex and GetSpecializationInfo then
        specID = GetSpecializationInfo(specIndex)
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

--- Send settings sync acknowledgment
-- @param target string
function CommMixin:SendSettingsSyncAck(target)
    self:Send(Loothing.MsgType.SYNC_SETTINGS_ACK, {}, target)
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

--- Send history sync acknowledgment
-- @param target string
function CommMixin:SendHistorySyncAck(target)
    self:Send(Loothing.MsgType.SYNC_HISTORY_ACK, {}, target)
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
