--[[--------------------------------------------------------------------
    Loothing - Loot Council Addon for WoW 12.0+
    Sync - State synchronization for late joiners
----------------------------------------------------------------------]]

local Loolib = LibStub("Loolib")

--[[--------------------------------------------------------------------
    LoothingSyncMixin
----------------------------------------------------------------------]]

LoothingSyncMixin = LoolibCreateFromMixins(LoolibCallbackRegistryMixin)

local SYNC_EVENTS = {
    "OnSyncComplete",
    "OnSyncFailed",
    "OnSyncProgress",
}

--- Initialize sync handler
function LoothingSyncMixin:Init()
    LoolibCallbackRegistryMixin.OnLoad(self)
    self:GenerateCallbackEvents(SYNC_EVENTS)

    self.syncInProgress = false
    self.syncTarget = nil
    self.syncTimeout = nil
    self.pendingItems = {}

    -- Listen for sync messages
    self:RegisterCommEvents()
end

--- Register for communication events
function LoothingSyncMixin:RegisterCommEvents()
    if not Loothing.Comm then return end

    Loothing.Comm:RegisterCallback("OnSyncRequest", function(data)
        self:HandleSyncRequest(data)
    end, self)

    Loothing.Comm:RegisterCallback("OnSyncData", function(data)
        self:HandleSyncData(data)
    end, self)
end

--[[--------------------------------------------------------------------
    Sync Requesting (Client Side)
----------------------------------------------------------------------]]

--- Request sync from the master looter
-- @param masterLooter string - Name of the ML to sync from
function LoothingSyncMixin:RequestSync(masterLooter)
    if self.syncInProgress then
        Loothing:Debug("Sync already in progress")
        return
    end

    if not masterLooter then
        Loothing:Debug("No master looter specified for sync")
        self:TriggerEvent("OnSyncFailed", "No master looter")
        return
    end

    self.syncInProgress = true
    self.syncTarget = masterLooter
    self.pendingItems = {}

    -- Send sync request
    Loothing.Comm:RequestSync(masterLooter)

    -- Set timeout
    self.syncTimeout = C_Timer.NewTimer(LOOTHING_TIMING.SYNC_TIMEOUT, function()
        if self.syncInProgress then
            self:CancelSync("Timeout")
        end
    end)

    self:TriggerEvent("OnSyncProgress", "Requesting sync...")
    Loothing:Debug("Requesting sync from", masterLooter)
end

--- Cancel an in-progress sync
-- @param reason string
function LoothingSyncMixin:CancelSync(reason)
    if self.syncTimeout then
        self.syncTimeout:Cancel()
        self.syncTimeout = nil
    end

    self.syncInProgress = false
    self.syncTarget = nil
    self.pendingItems = {}

    self:TriggerEvent("OnSyncFailed", reason or "Cancelled")
    Loothing:Debug("Sync cancelled:", reason)
end

--- Handle received sync data
-- @param data table - Sync data from ML
function LoothingSyncMixin:HandleSyncData(data)
    if not self.syncInProgress then
        Loothing:Debug("Received sync data but no sync in progress")
        return
    end

    -- Verify sender
    if data.masterLooter ~= self.syncTarget then
        Loothing:Debug("Sync data from unexpected sender")
        return
    end

    -- Cancel timeout
    if self.syncTimeout then
        self.syncTimeout:Cancel()
        self.syncTimeout = nil
    end

    -- Apply sync data to session
    self:ApplySyncData(data)

    self.syncInProgress = false
    self.syncTarget = nil

    self:TriggerEvent("OnSyncComplete", data)
    Loothing:Debug("Sync complete")
end

--- Apply sync data to current session
-- @param data table
function LoothingSyncMixin:ApplySyncData(data)
    if not Loothing.Session then return end

    -- Check if there's an active session
    if data.state == LOOTHING_SESSION_STATE.INACTIVE then
        -- No active session, nothing to sync
        return
    end

    -- Create/update session
    Loothing.Session:SyncFromData({
        sessionID = data.sessionID,
        encounterID = data.encounterID,
        encounterName = data.encounterName,
        state = data.state,
        masterLooter = data.masterLooter,
    })
end

--[[--------------------------------------------------------------------
    Sync Responding (ML Side)
----------------------------------------------------------------------]]

--- Handle sync request from another player
-- @param data table - Request data
function LoothingSyncMixin:HandleSyncRequest(data)
    -- Only ML should respond to sync requests
    if not LoothingUtils.IsRaidLeaderOrAssistant() then
        return
    end

    local requester = data.requester

    Loothing:Debug("Received sync request from", requester)

    -- Gather current state
    local syncData = self:GatherSyncData()

    -- Send response
    Loothing.Comm:SendSyncData(syncData, requester)

    -- Also send items if session is active
    if syncData.state ~= LOOTHING_SESSION_STATE.INACTIVE then
        self:SendItemSync(requester)
    end
end

--- Gather current session state for sync
-- @return table
function LoothingSyncMixin:GatherSyncData()
    local session = Loothing.Session

    if not session or session:GetState() == LOOTHING_SESSION_STATE.INACTIVE then
        return {
            sessionID = "",
            encounterID = 0,
            encounterName = "",
            state = LOOTHING_SESSION_STATE.INACTIVE,
        }
    end

    return {
        sessionID = session:GetSessionID(),
        encounterID = session:GetEncounterID(),
        encounterName = session:GetEncounterName(),
        state = session:GetState(),
    }
end

--- Send item data to sync target
-- @param target string - Player to send to
function LoothingSyncMixin:SendItemSync(target)
    if not Loothing.Session then return end

    local items = Loothing.Session:GetItems()
    if not items then return end

    -- Send each item
    for _, item in items:Enumerate() do
        Loothing.Comm:Send(
            LoothingProtocol:ItemAdd(item.itemLink, item.guid, item.looter),
            target
        )
    end
end

--[[--------------------------------------------------------------------
    Auto-Sync on Join
----------------------------------------------------------------------]]

--- Check if we need to sync (called on roster update)
function LoothingSyncMixin:CheckNeedSync()
    if not IsInRaid() then return end

    -- Don't sync if we're the leader
    if LoothingUtils.IsRaidLeaderOrAssistant() then return end

    -- Don't sync if already have a session
    if Loothing.Session and Loothing.Session:GetState() ~= LOOTHING_SESSION_STATE.INACTIVE then
        return
    end

    -- Find the raid leader to sync from
    local leader = LoothingUtils.GetRaidLeader()
    if leader then
        -- Delay sync slightly to allow other addons to initialize
        C_Timer.After(2, function()
            self:RequestSync(leader)
        end)
    end
end

--[[--------------------------------------------------------------------
    Council Roster Sync
----------------------------------------------------------------------]]

--- Sync council roster to raid
function LoothingSyncMixin:BroadcastCouncilRoster()
    if not LoothingUtils.IsRaidLeaderOrAssistant() then return end
    if not Loothing.Council then return end

    local members = Loothing.Council:GetAllMembers()
    Loothing.Comm:BroadcastCouncilRoster(members)
end

--- Handle received council roster
-- @param data table
function LoothingSyncMixin:HandleCouncilRoster(data)
    if not Loothing.Council then return end

    -- Only accept roster from ML
    if not data.masterLooter then return end

    -- Update local council roster (non-ML players mirror the ML's roster)
    if not LoothingUtils.IsRaidLeaderOrAssistant() then
        Loothing.Council:SetRemoteRoster(data.members)
    end
end

--[[--------------------------------------------------------------------
    Factory
----------------------------------------------------------------------]]

function CreateLoothingSync()
    local sync = LoolibCreateFromMixins(LoothingSyncMixin)
    sync:Init()
    return sync
end
