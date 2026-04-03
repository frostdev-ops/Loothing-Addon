--[[--------------------------------------------------------------------
    Loothing - Loot Council Addon for WoW 12.0+
    Heartbeat - ML heartbeat and client auto-recovery

    Responsibilities:
    - ML side: broadcast lightweight state digest every 10s during sessions
    - Client side: compare incoming digest against local state, trigger
      auto-sync on mismatch with a 60s cooldown to prevent sync storms

    The heartbeat provides eventual consistency without per-message ACKs.
    Instead of 20 raiders each sending an acknowledgment (O(N) messages),
    the ML sends 1 heartbeat and only divergent clients respond (typically 0-1).

    Dirty-tracking: the ML caches the last broadcast digest and skips
    sending when nothing has changed, avoiding redundant network + CPU cost.

    Heartbeat payload (~100 bytes compressed):
        sessionID    = string
        state        = number (Loothing.SessionState)
        itemCount    = number
        itemStates   = { [guid] = stateCode, ... }
        councilHash  = number (Adler-32 of sorted council member names)
        mldbHash     = number (Adler-32 of serialized MLDB)
        observerHash = number (Adler-32 of sorted observer names)
----------------------------------------------------------------------]]
local _, ns = ...

local Loothing = ns.Addon
local Loolib = LibStub("Loolib")
local CreateFromMixins = Loolib.CreateFromMixins
local GetTime = GetTime

ns.HeartbeatMixin = ns.HeartbeatMixin or {}

--[[--------------------------------------------------------------------
    HeartbeatMixin
----------------------------------------------------------------------]]

local HeartbeatMixin = ns.HeartbeatMixin

local HEARTBEAT_INTERVAL    = 10    -- Seconds between ML heartbeat broadcasts
local AUTO_SYNC_COOLDOWN    = 60    -- Minimum seconds between auto-sync triggers

--- Initialize the Heartbeat
function HeartbeatMixin:Init()
    self.heartbeatTimer     = nil
    self.pendingSyncTimer   = nil
    self.lastAutoSyncTime   = 0
    self.lastHeartbeatTime  = 0
    self.lastDigest         = nil
end

--[[--------------------------------------------------------------------
    ML Side — Heartbeat Broadcasting
----------------------------------------------------------------------]]

--- Start the periodic heartbeat timer (call when ML session becomes active)
-- Deferred during reconnect grace period; jittered interval to prevent sync storms.
function HeartbeatMixin:StartHeartbeat()
    self:StopHeartbeat()

    -- Reset dirty-tracking so first broadcast always fires
    self.lastDigest = nil

    -- During grace period, defer start until grace ends
    local CommState = Loothing.CommState
    if CommState and CommState:IsInGracePeriod() then
        Loothing:Debug("Heartbeat: deferring heartbeat start (grace period)")
        CommState:RegisterCallback("OnGracePeriodEnded", function()
            CommState:UnregisterCallback("OnGracePeriodEnded", self)
            self:StartHeartbeat()
        end, self)
        return
    end

    -- Jittered interval: HEARTBEAT_INTERVAL +/- HEARTBEAT_JITTER
    local jitter = Loothing.Timing.HEARTBEAT_JITTER or 2
    local interval = HEARTBEAT_INTERVAL
    if CommState then
        interval = CommState:Jitter(HEARTBEAT_INTERVAL, jitter)
    end

    self.heartbeatTimer = C_Timer.NewTicker(interval, function()
        self:BroadcastHeartbeat()
    end)
    Loothing:Debug("Heartbeat: started (interval=" .. string.format("%.1f", interval) .. "s)")
end

--- Stop the heartbeat timer (call when session ends or ML role lost)
function HeartbeatMixin:StopHeartbeat()
    if self.heartbeatTimer then
        self.heartbeatTimer:Cancel()
        self.heartbeatTimer = nil
        Loothing:Debug("Heartbeat: stopped")
    end

    -- Reset dirty-tracking
    self.lastDigest = nil

    -- Cancel any pending grace-period deferred start
    local CommState = Loothing.CommState
    if CommState then
        CommState:UnregisterCallback("OnGracePeriodEnded", self)
    end
end

--- Broadcast one heartbeat digest to the group
-- Skipped during encounter restrictions (WoW drops them anyway, wastes queue budget).
-- Skipped when digest is unchanged since last broadcast (dirty-tracking).
function HeartbeatMixin:BroadcastHeartbeat()
    if not Loothing.Session or not Loothing.Session:IsMasterLooter() then
        self:StopHeartbeat()
        return
    end
    if Loothing.Session:GetState() == Loothing.SessionState.INACTIVE then
        return
    end

    -- Skip during encounter restrictions — WoW drops addon messages anyway,
    -- and skipping here avoids the wasted CPU of BuildHeartbeatDigest() (item
    -- iteration, Adler-32 hash computation).
    local CommState = Loothing.CommState
    if CommState then
        local state = CommState:GetState()
        if state == CommState.STATE_RESTRICTED then
            return
        end
    end

    local digest = self:BuildHeartbeatDigest()
    if not digest then return end

    -- Dirty-tracking: skip if digest is unchanged since last broadcast
    if self:DigestMatches(digest, self.lastDigest) then
        Loothing:Debug("Heartbeat: skipped (no change)")
        return
    end

    self.lastDigest = digest

    -- BULK priority — 10s interval means ~10 B/s against our 800 B/s budget
    Loothing.Comm:Send(Loothing.MsgType.HEARTBEAT, digest, nil, "BULK")
    Loothing:Debug("Heartbeat: broadcast")
end

--- Compare two heartbeat digests for equality
-- @param a table|nil
-- @param b table|nil
-- @return boolean - true if both are non-nil and all fields match
function HeartbeatMixin:DigestMatches(a, b)
    if not a or not b then return false end

    if a.sessionID ~= b.sessionID then return false end
    if a.state ~= b.state then return false end
    if a.itemCount ~= b.itemCount then return false end
    if a.councilHash ~= b.councilHash then return false end
    if a.mldbHash ~= b.mldbHash then return false end
    if a.observerHash ~= b.observerHash then return false end

    -- Shallow compare itemStates (typically 1-10 items)
    if a.itemStates and b.itemStates then
        for guid, stateCode in pairs(a.itemStates) do
            if b.itemStates[guid] ~= stateCode then return false end
        end
        for guid in pairs(b.itemStates) do
            if a.itemStates[guid] == nil then return false end
        end
    elseif a.itemStates or b.itemStates then
        return false
    end

    return true
end

--- Build the current session state digest for the heartbeat payload
-- @return table|nil
function HeartbeatMixin:BuildHeartbeatDigest()
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

    -- Observer hash: Adler-32 of sorted observer names
    digest.observerHash = self:ComputeObserverHash()

    return digest
end

--[[--------------------------------------------------------------------
    Client Side — Heartbeat Handling and Auto-Sync
----------------------------------------------------------------------]]

--- Handle an incoming HEARTBEAT from the ML
-- @param digest table - Heartbeat payload
-- @param sender string - Sender (the ML)
function HeartbeatMixin:HandleHeartbeat(digest, sender)
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
        -- We have no session but ML reports one active -> full sync
        if digest.state ~= Loothing.SessionState.INACTIVE then
            Loothing:Debug("Heartbeat: no local session, ML has active session -- full sync needed")
            needsSync = true
        end
    else
        -- Compare session identity and state
        local localID = session:GetSessionID() or ""
        if digest.sessionID ~= localID then
            Loothing:Debug("Heartbeat: session ID mismatch -- full sync needed")
            needsSync = true
        elseif digest.state ~= localState then
            Loothing:Debug("Heartbeat: session state mismatch -- full sync needed")
            needsSync = true
        elseif digest.itemCount ~= self:GetLocalItemCount() then
            Loothing:Debug("Heartbeat: item count mismatch -- incremental sync (items)")
            needsSync = true
            mismatchType = "items"
        else
            -- Deep-check item states (detect VOTING→AWARDED etc. when count matches)
            if not needsSync and digest.itemStates and session.items then
                -- Forward check: local items whose state diverges from ML
                for _, item in session.items:Enumerate() do
                    local remoteState = digest.itemStates[item.guid]
                    if remoteState and remoteState ~= item:GetState() then
                        Loothing:Debug("Heartbeat: item state mismatch for", item.guid, "-- incremental sync (itemStates)")
                        needsSync = true
                        mismatchType = "itemStates"
                        break
                    end
                end
                -- Reverse check: items ML has that we don't (count-preserving swap)
                if not needsSync then
                    local localGUIDs = {}
                    for _, item in session.items:Enumerate() do
                        localGUIDs[item.guid] = true
                    end
                    for guid in pairs(digest.itemStates) do
                        if not localGUIDs[guid] then
                            Loothing:Debug("Heartbeat: ML has item", guid, "not present locally -- incremental sync (itemStates)")
                            needsSync = true
                            mismatchType = "itemStates"
                            break
                        end
                    end
                end
            end

            -- Deep-check council hash
            if not needsSync then
                local localCouncilHash = self:ComputeCouncilHash()
                if localCouncilHash ~= digest.councilHash then
                    Loothing:Debug("Heartbeat: council hash mismatch -- incremental sync (council)")
                    needsSync = true
                    mismatchType = "council"
                end
            end

            -- Deep-check MLDB hash
            if not needsSync then
                local localMLDBHash = self:ComputeMLDBHash()
                if localMLDBHash ~= digest.mldbHash then
                    Loothing:Debug("Heartbeat: MLDB hash mismatch -- incremental sync (mldb)")
                    needsSync = true
                    mismatchType = "mldb"
                end
            end

            -- Deep-check observer hash (may be absent from older peers)
            if not needsSync and digest.observerHash ~= nil then
                local localObserverHash = self:ComputeObserverHash()
                if localObserverHash ~= digest.observerHash then
                    Loothing:Debug("Heartbeat: observer hash mismatch -- incremental sync (observer)")
                    needsSync = true
                    mismatchType = "observer"
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

--- Trigger an auto-sync with the ML, subject to cooldown.
-- Jittered: instead of all 25 clients firing at once on the same heartbeat,
-- each client delays by a random amount within SYNC_JITTER_WINDOW seconds.
-- If the next heartbeat arrives and state has converged, the pending timer
-- is cancelled (avoiding unnecessary syncs).
-- @param mlName string - The ML to sync from
function HeartbeatMixin:TriggerAutoSync(mlName)
    local now = GetTime()
    if now - self.lastAutoSyncTime < AUTO_SYNC_COOLDOWN then
        Loothing:Debug("Heartbeat: auto-sync cooldown active, skipping")
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
    Loothing:Debug("Heartbeat: scheduling auto-sync in", string.format("%.1fs", delay))

    self.pendingSyncTimer = C_Timer.NewTimer(delay, function()
        self.pendingSyncTimer = nil
        if Loothing.CommState then
            Loothing.CommState:RequestSyncIfNeeded("heartbeat", mlName)
        elseif Loothing.Sync then
            Loothing:Debug("Heartbeat: requesting auto-sync from", mlName)
            Loothing.Sync:RequestSync(mlName)
        end
    end)
end

--- Cancel any pending jittered sync (e.g., if heartbeat shows convergence)
function HeartbeatMixin:CancelPendingSync()
    if self.pendingSyncTimer then
        self.pendingSyncTimer:Cancel()
        self.pendingSyncTimer = nil
        Loothing:Debug("Heartbeat: cancelled pending sync (state converged)")
    end
end

--- Trigger an incremental sync for a specific mismatch type, with jitter.
-- Much lighter than full sync — only requests the divergent subset.
-- @param mlName string
-- @param mismatchType string - "council", "mldb", "items", "itemStates"
function HeartbeatMixin:TriggerIncrementalSync(mlName, mismatchType)
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

    Loothing:Debug("Heartbeat: scheduling incremental sync (", mismatchType, ") in", string.format("%.1fs", delay))

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
function HeartbeatMixin:ComputeCouncilHash()
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

--- Compute Adler-32 hash of the current observer list
-- Uses the same pattern as ComputeCouncilHash for determinism.
-- Returns 0 when the Observer module is absent or the list is empty.
-- @return number
function HeartbeatMixin:ComputeObserverHash()
    if not Loothing.Observer then return 0 end

    local observers = Loothing.Observer:GetObservers()
    if not observers or #observers == 0 then return 0 end

    -- Sort for determinism
    local sorted = {}
    for _, name in ipairs(observers) do sorted[#sorted + 1] = name end
    table.sort(sorted)

    local str = table.concat(sorted, ",")
    return Loolib.Compressor:Adler32(str)
end

--- Serialize a table deterministically (sorted keys at every level)
-- Required because pairs() iteration order is undefined, so Serialize()
-- output can differ between ML and client even for identical tables.
-- @param tbl any
-- @return string
function HeartbeatMixin:DeterministicSerialize(tbl)
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
function HeartbeatMixin:ComputeMLDBHash()
    if not Loothing.MLDB then return 0 end

    local mldb = Loothing.MLDB:Get()
    if not mldb then return 0 end

    local serialized = self:DeterministicSerialize(mldb)
    return Loolib.Compressor:Adler32(serialized)
end

--- Get the number of items in the local session
-- @return number
function HeartbeatMixin:GetLocalItemCount()
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

function ns.CreateHeartbeat()
    local tracker = CreateFromMixins(HeartbeatMixin)
    tracker:Init()
    return tracker
end

-- ns.HeartbeatMixin and ns.CreateHeartbeat exported above
