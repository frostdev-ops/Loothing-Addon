--[[--------------------------------------------------------------------
    Loothing - Loot Council Addon for WoW 12.0+
    AckTracker - ML heartbeat and client auto-recovery

    Responsibilities:
    - ML side: broadcast lightweight state digest every 30s during sessions
    - Client side: compare incoming digest against local state, trigger
      auto-sync on mismatch with a 60s cooldown to prevent sync storms

    The heartbeat replaces per-message ACKs for broadcasts. Instead of
    20 raiders each sending an ACK (O(N) messages), the ML sends 1
    heartbeat and only divergent clients respond (typically 0-1).

    Heartbeat payload (~100 bytes compressed):
        sessionID   = string
        state       = number (Loothing.SessionState)
        itemCount   = number
        itemStates  = { [guid] = stateCode, ... }
        councilHash = number (Adler-32 of sorted council member names)
        mldbHash    = number (Adler-32 of serialized MLDB)
----------------------------------------------------------------------]]
local _, ns = ...

local Loothing = ns.Addon
local Loolib = LibStub("Loolib")
local CreateFromMixins = Loolib.CreateFromMixins
local GetTime = GetTime

ns.AckTrackerMixin = ns.AckTrackerMixin or {}

--[[--------------------------------------------------------------------
    AckTrackerMixin
----------------------------------------------------------------------]]

local AckTrackerMixin = ns.AckTrackerMixin

local HEARTBEAT_INTERVAL    = 30    -- Seconds between ML heartbeat broadcasts
local AUTO_SYNC_COOLDOWN    = 60    -- Minimum seconds between auto-sync triggers

--- Initialize the AckTracker
function AckTrackerMixin:Init()
    self.heartbeatTimer     = nil
    self.lastAutoSyncTime   = 0
    self.lastHeartbeatTime  = 0
end

--[[--------------------------------------------------------------------
    ML Side — Heartbeat Broadcasting
----------------------------------------------------------------------]]

--- Start the periodic heartbeat timer (call when ML session becomes active)
-- Deferred during reconnect grace period; jittered interval to prevent sync storms.
function AckTrackerMixin:StartHeartbeat()
    self:StopHeartbeat()

    -- During grace period, defer start until grace ends
    local CommState = Loothing.CommState
    if CommState and CommState:IsInGracePeriod() then
        Loothing:Debug("AckTracker: deferring heartbeat start (grace period)")
        CommState:RegisterCallback("OnGracePeriodEnded", function()
            CommState:UnregisterCallback("OnGracePeriodEnded", self)
            self:StartHeartbeat()
        end, self)
        return
    end

    -- Jittered interval: HEARTBEAT_INTERVAL +/- HEARTBEAT_JITTER
    local jitter = Loothing.Timing.HEARTBEAT_JITTER or 5
    local interval = HEARTBEAT_INTERVAL
    if CommState then
        interval = CommState:Jitter(HEARTBEAT_INTERVAL, jitter)
    end

    self.heartbeatTimer = C_Timer.NewTicker(interval, function()
        self:BroadcastHeartbeat()
    end)
    Loothing:Debug("AckTracker: heartbeat started (interval=" .. string.format("%.1f", interval) .. "s)")
end

--- Stop the heartbeat timer (call when session ends or ML role lost)
function AckTrackerMixin:StopHeartbeat()
    if self.heartbeatTimer then
        self.heartbeatTimer:Cancel()
        self.heartbeatTimer = nil
        Loothing:Debug("AckTracker: heartbeat stopped")
    end

    -- Cancel any pending grace-period deferred start
    local CommState = Loothing.CommState
    if CommState then
        CommState:UnregisterCallback("OnGracePeriodEnded", self)
    end
end

--- Broadcast one heartbeat digest to the group
-- Skipped during encounter restrictions (WoW drops them anyway, wastes queue budget).
function AckTrackerMixin:BroadcastHeartbeat()
    if not Loothing.Session or not Loothing.Session:IsMasterLooter() then
        self:StopHeartbeat()
        return
    end
    if Loothing.Session:GetState() == Loothing.SessionState.INACTIVE then
        return
    end

    -- Skip during any combat — WoW 12.0 blocks all addon messages in combat.
    -- Heartbeats are BULK and would just be deferred by Send() anyway, but
    -- skipping here avoids the wasted CPU of BuildHeartbeatDigest() (item
    -- iteration, Adler-32 hash computation).
    local CommState = Loothing.CommState
    if CommState then
        local state = CommState:GetState()
        if state == CommState.STATE_COMBAT or state == CommState.STATE_RESTRICTED then
            return
        end
    end

    local digest = self:BuildHeartbeatDigest()
    if not digest then return end

    -- BULK priority — 30s interval means ~3.3 B/s against our 800 B/s budget
    Loothing.Comm:Send(Loothing.MsgType.HEARTBEAT, digest, nil, "BULK")
    Loothing:Debug("AckTracker: heartbeat broadcast")
end

--- Build the current session state digest for the heartbeat payload
-- @return table|nil
function AckTrackerMixin:BuildHeartbeatDigest()
    local session = Loothing.Session
    if not session then return nil end

    local digest = {
        sessionID  = session:GetSessionID() or "",
        state      = session:GetState(),
        itemCount  = 0,
        itemStates = {},
        councilHash = 0,
        mldbHash    = 0,
    }

    -- Item count and per-item state codes
    if session.items then
        for _, item in session.items:Enumerate() do
            digest.itemCount                  = digest.itemCount + 1
            digest.itemStates[item.guid] = item:GetState()
        end
    end

    -- Council hash: Adler-32 of sorted member names concatenated
    digest.councilHash = self:ComputeCouncilHash()

    -- MLDB hash: Adler-32 of serialized MLDB
    digest.mldbHash = self:ComputeMLDBHash()

    return digest
end

--[[--------------------------------------------------------------------
    Client Side — Heartbeat Handling and Auto-Sync
----------------------------------------------------------------------]]

--- Handle an incoming HEARTBEAT from the ML
-- @param digest table - Heartbeat payload
-- @param sender string - Sender (the ML)
function AckTrackerMixin:HandleHeartbeat(digest, sender)
    -- Record receipt time so stale-session detection can check heartbeat age
    self.lastHeartbeatTime = GetTime()

    -- Only non-ML clients should act on heartbeats
    if Loothing.Session and Loothing.Session:IsMasterLooter() then return end

    local session    = Loothing.Session
    local needsSync  = false
    local mismatchType = nil  -- nil = full sync, string = incremental

    if not session then return end

    local localState = session:GetState()

    if localState == Loothing.SessionState.INACTIVE then
        -- We have no session but ML reports one active → full sync
        if digest.state ~= Loothing.SessionState.INACTIVE then
            Loothing:Debug("AckTracker: no local session, ML has active session — full sync needed")
            needsSync = true
        end
    else
        -- Compare session identity and state
        local localID = session:GetSessionID() or ""
        if digest.sessionID ~= localID then
            Loothing:Debug("AckTracker: session ID mismatch — full sync needed")
            needsSync = true
        elseif digest.state ~= localState then
            Loothing:Debug("AckTracker: session state mismatch — full sync needed")
            needsSync = true
        elseif digest.itemCount ~= self:GetLocalItemCount() then
            Loothing:Debug("AckTracker: item count mismatch — incremental sync (items)")
            needsSync = true
            mismatchType = "items"
        else
            -- Deep-check council hash
            local localCouncilHash = self:ComputeCouncilHash()
            if localCouncilHash ~= digest.councilHash then
                Loothing:Debug("AckTracker: council hash mismatch — incremental sync (council)")
                needsSync = true
                mismatchType = "council"
            end

            -- Deep-check MLDB hash
            if not needsSync then
                local localMLDBHash = self:ComputeMLDBHash()
                if localMLDBHash ~= digest.mldbHash then
                    Loothing:Debug("AckTracker: MLDB hash mismatch — incremental sync (mldb)")
                    needsSync = true
                    mismatchType = "mldb"
                end
            end
        end
    end

    if needsSync then
        if mismatchType and Loothing.Sync then
            -- Use incremental sync for targeted mismatches (much lighter)
            self:TriggerIncrementalSync(sender, mismatchType)
        else
            -- Full sync for fundamental divergence (session ID, state, no session)
            self:TriggerAutoSync(sender)
        end
    else
        -- State matches — cancel any pending jittered sync from a prior heartbeat
        self:CancelPendingSync()
    end
end

--- Handle an incoming ACK message (reserved for future extensibility)
-- @param data table - { command, msgID, success }
-- @param sender string
function AckTrackerMixin:HandleAck(data, sender)
    -- Placeholder — ACK tracking for point-to-point messages can be
    -- built here when needed without a wire-format change.
    -- data.msgID is the Protocol v4 sequence number being acknowledged (may be nil for v3 peers).
    Loothing:Debug("AckTracker: received ACK from", sender,
        "command=" .. tostring(data and data.command),
        "msgID=" .. tostring(data and data.msgID))
end

--- Trigger an auto-sync with the ML, subject to cooldown.
-- Jittered: instead of all 25 clients firing at once on the same heartbeat,
-- each client delays by a random amount within SYNC_JITTER_WINDOW seconds.
-- If the next heartbeat arrives and state has converged, the pending timer
-- is cancelled (avoiding unnecessary syncs).
-- @param mlName string - The ML to sync from
function AckTrackerMixin:TriggerAutoSync(mlName)
    local now = GetTime()
    if now - self.lastAutoSyncTime < AUTO_SYNC_COOLDOWN then
        Loothing:Debug("AckTracker: auto-sync cooldown active, skipping")
        return
    end

    self.lastAutoSyncTime = now

    -- Cancel any previously scheduled jittered sync
    if self.pendingSyncTimer then
        self.pendingSyncTimer:Cancel()
        self.pendingSyncTimer = nil
    end

    -- Schedule sync with random jitter to spread 25 clients across the window
    local jitterWindow = Loothing.Timing.SYNC_JITTER_WINDOW or 8
    local delay = math.random() * jitterWindow
    Loothing:Debug("AckTracker: scheduling auto-sync in", string.format("%.1fs", delay))

    self.pendingSyncTimer = C_Timer.NewTimer(delay, function()
        self.pendingSyncTimer = nil
        if Loothing.CommState then
            Loothing.CommState:RequestSyncIfNeeded("heartbeat", mlName)
        elseif Loothing.Sync then
            Loothing:Debug("AckTracker: requesting auto-sync from", mlName)
            Loothing.Sync:RequestSync(mlName)
        end
    end)
end

--- Cancel any pending jittered sync (e.g., if heartbeat shows convergence)
function AckTrackerMixin:CancelPendingSync()
    if self.pendingSyncTimer then
        self.pendingSyncTimer:Cancel()
        self.pendingSyncTimer = nil
        Loothing:Debug("AckTracker: cancelled pending sync (state converged)")
    end
end

--- Trigger an incremental sync for a specific mismatch type, with jitter.
-- Much lighter than full sync — only requests the divergent subset.
-- @param mlName string
-- @param mismatchType string - "council", "mldb", "items", "itemStates"
function AckTrackerMixin:TriggerIncrementalSync(mlName, mismatchType)
    local now = GetTime()
    if now - self.lastAutoSyncTime < AUTO_SYNC_COOLDOWN then
        return
    end
    self.lastAutoSyncTime = now

    -- Cancel any pending full sync
    if self.pendingSyncTimer then
        self.pendingSyncTimer:Cancel()
        self.pendingSyncTimer = nil
    end

    local jitterWindow = Loothing.Timing.SYNC_JITTER_WINDOW or 8
    local delay = math.random() * jitterWindow

    Loothing:Debug("AckTracker: scheduling incremental sync (", mismatchType, ") in", string.format("%.1fs", delay))

    self.pendingSyncTimer = C_Timer.NewTimer(delay, function()
        self.pendingSyncTimer = nil
        if Loothing.Sync then
            Loothing.Sync:RequestIncrementalSync(mlName, mismatchType)
        end
    end)
end

--[[--------------------------------------------------------------------
    Hash Helpers (used by both ML and client sides)
----------------------------------------------------------------------]]

--- Compute Adler-32 hash of the council member list
-- @return number
function AckTrackerMixin:ComputeCouncilHash()
    if not Loothing.Council then return 0 end

    local members = Loothing.Council:GetAllMembers()
    if not members or #members == 0 then return 0 end

    -- Sort for determinism (order may differ between ML and clients)
    local sorted = {}
    for _, m in ipairs(members) do sorted[#sorted + 1] = m end
    table.sort(sorted)

    local str = table.concat(sorted, ",")
    return Loolib.Compressor:Adler32(str)
end

--- Serialize a table deterministically (sorted keys at every level)
-- Required because pairs() iteration order is undefined, so Serialize()
-- output can differ between ML and client even for identical tables.
-- @param tbl any
-- @return string
function AckTrackerMixin:DeterministicSerialize(tbl)
    if type(tbl) ~= "table" then
        return tostring(tbl)
    end

    local keys = {}
    for k in pairs(tbl) do
        keys[#keys + 1] = k
    end
    table.sort(keys, function(a, b)
        return tostring(a) < tostring(b)
    end)

    local parts = {}
    for _, k in ipairs(keys) do
        parts[#parts + 1] = tostring(k) .. "=" .. self:DeterministicSerialize(tbl[k])
    end

    return "{" .. table.concat(parts, ",") .. "}"
end

--- Compute Adler-32 hash of the current MLDB
-- Uses deterministic serialization to ensure ML and client produce
-- identical hashes for identical data.
-- @return number
function AckTrackerMixin:ComputeMLDBHash()
    if not Loothing.MLDB then return 0 end

    local mldb = Loothing.MLDB:Get()
    if not mldb then return 0 end

    local serialized = self:DeterministicSerialize(mldb)
    return Loolib.Compressor:Adler32(serialized)
end

--- Get the number of items in the local session
-- @return number
function AckTrackerMixin:GetLocalItemCount()
    local session = Loothing.Session
    if not session or not session.items then return 0 end

    local count = 0
    for _ in session.items:Enumerate() do
        count = count + 1
    end
    return count
end

--[[--------------------------------------------------------------------
    Factory
----------------------------------------------------------------------]]

function ns.CreateAckTracker()
    local tracker = CreateFromMixins(AckTrackerMixin)
    tracker:Init()
    return tracker
end

-- ns.AckTrackerMixin and ns.CreateAckTracker exported above
