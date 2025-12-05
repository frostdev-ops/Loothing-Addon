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
    Settings Sync
----------------------------------------------------------------------]]

--- Request to sync settings to target (guild or player)
-- @param target string - "guild" or player name
function LoothingSyncMixin:RequestSettingsSync(target)
    if self.settingsSyncInProgress then
        Loothing:Print("Settings sync already in progress")
        return
    end

    local settings = self:GatherSettings()
    self.pendingSettingsSync = settings
    self.settingsSyncInProgress = true
    self.settingsSyncResponses = {}

    local msg = LoothingProtocol:Encode(LOOTHING_MSG_TYPE.SYNC_SETTINGS_REQUEST, {})

    if target == "guild" then
        Loothing.Comm:SendGuild(msg)
        Loothing:Print("Requesting settings sync to guild...")
    else
        Loothing.Comm:SendToPlayer(msg, target)
        Loothing:Print("Requesting settings sync to " .. target)
    end

    -- Timeout after 30 seconds
    C_Timer.After(30, function()
        if self.settingsSyncInProgress then
            self.settingsSyncInProgress = false
            local count = 0
            for _ in pairs(self.settingsSyncResponses or {}) do
                count = count + 1
            end
            if count > 0 then
                Loothing:Print(string.format("Settings sync completed to %d recipients", count))
            else
                Loothing:Print("Settings sync timed out - no responses")
            end
        end
    end)
end

--- Gather current settings for sync
-- @return table
function LoothingSyncMixin:GatherSettings()
    local settings = {}

    -- Responses
    if Loothing.ResponseManager then
        settings.responses = Loothing.ResponseManager:Serialize()
    end

    -- Voting settings
    if Loothing.Settings then
        settings.voting = {
            mode = Loothing.Settings:GetVotingMode(),
            timeout = Loothing.Settings:GetVotingTimeout(),
        }
    end

    return settings
end

--- Handle incoming settings sync request
-- @param sender string
function LoothingSyncMixin:HandleSettingsSyncRequest(sender)
    -- Show confirmation dialog
    StaticPopup_Show("LOOTHING_ACCEPT_SETTINGS_SYNC", sender, nil, {
        sender = sender,
        onAccept = function()
            self:AcceptSettingsSync(sender)
        end
    })
end

--- Accept settings sync from sender
-- @param sender string
function LoothingSyncMixin:AcceptSettingsSync(sender)
    local msg = LoothingProtocol:Encode(LOOTHING_MSG_TYPE.SYNC_SETTINGS_ACK, {})
    Loothing.Comm:SendToPlayer(msg, sender)

    self.awaitingSettingsFrom = sender
    Loothing:Print("Accepted settings sync from " .. sender)
end

--- Handle settings sync acknowledgment
-- @param sender string
function LoothingSyncMixin:HandleSettingsSyncAck(sender)
    if not self.settingsSyncInProgress or not self.pendingSettingsSync then
        return
    end

    -- Track response
    self.settingsSyncResponses = self.settingsSyncResponses or {}
    self.settingsSyncResponses[sender] = true

    -- Serialize and compress settings
    local Serializer = Loolib:GetModule("Serializer")
    local Compressor = Loolib:GetModule("Compressor")

    local serialized = Serializer:Serialize(self.pendingSettingsSync)
    local compressed = Compressor and Compressor:Compress(serialized) or serialized

    -- Send settings data
    local msg = LoothingProtocol:Encode(LOOTHING_MSG_TYPE.SYNC_SETTINGS_DATA, { compressed })
    Loothing.Comm:SendToPlayer(msg, sender)

    Loothing:Print("Sent settings to " .. sender)
end

--- Handle received settings data
-- @param data string - Compressed/serialized settings
-- @param sender string
function LoothingSyncMixin:HandleSettingsData(data, sender)
    if self.awaitingSettingsFrom ~= sender then
        return
    end

    if not data then
        Loothing:Debug("Empty settings data from " .. sender)
        self.awaitingSettingsFrom = nil
        return
    end

    self.awaitingSettingsFrom = nil

    -- Decompress and deserialize
    local Serializer = Loolib:GetModule("Serializer")
    local Compressor = Loolib:GetModule("Compressor")

    local decompressed = Compressor and Compressor:Decompress(data) or data
    local settings = Serializer:Deserialize(decompressed)

    if not settings then
        Loothing:Print("Failed to parse settings from " .. sender)
        return
    end

    -- Apply settings
    self:ApplySettings(settings)

    Loothing:Print("Applied settings from " .. sender)
end

--- Apply received settings
-- @param settings table
function LoothingSyncMixin:ApplySettings(settings)
    -- Apply responses
    if settings.responses and Loothing.ResponseManager then
        Loothing.ResponseManager:Deserialize(settings.responses)
    end

    -- Apply voting settings
    if settings.voting and Loothing.Settings then
        if settings.voting.mode then
            Loothing.Settings:SetVotingMode(settings.voting.mode)
        end
        if settings.voting.timeout then
            Loothing.Settings:SetVotingTimeout(settings.voting.timeout)
        end
    end
end

--[[--------------------------------------------------------------------
    History Sync
----------------------------------------------------------------------]]

--- Request to sync history to target
-- @param target string - "guild" or player name
-- @param days number - Number of days of history to sync (default: 7)
function LoothingSyncMixin:RequestHistorySync(target, days)
    days = days or 7

    if self.historySyncInProgress then
        Loothing:Print("History sync already in progress")
        return
    end

    local history = self:GatherHistory(days)
    self.pendingHistorySync = history
    self.historySyncInProgress = true
    self.historySyncResponses = {}

    local msg = LoothingProtocol:Encode(LOOTHING_MSG_TYPE.SYNC_HISTORY_REQUEST, { days })

    if target == "guild" then
        Loothing.Comm:SendGuild(msg)
        Loothing:Print(string.format("Requesting history sync (%d days) to guild...", days))
    else
        Loothing.Comm:SendToPlayer(msg, target)
        Loothing:Print(string.format("Requesting history sync (%d days) to %s", days, target))
    end

    -- Timeout
    C_Timer.After(60, function()
        if self.historySyncInProgress then
            self.historySyncInProgress = false
            local count = 0
            for _ in pairs(self.historySyncResponses or {}) do
                count = count + 1
            end
            if count > 0 then
                Loothing:Print(string.format("History sync completed to %d recipients", count))
            else
                Loothing:Print("History sync timed out - no responses")
            end
        end
    end)
end

--- Gather recent history entries
-- @param days number
-- @return table
function LoothingSyncMixin:GatherHistory(days)
    if not Loothing.History then return {} end

    local cutoff = time() - (days * 24 * 60 * 60)
    local entries = {}

    for _, entry in Loothing.History:GetEntries():Enumerate() do
        if entry.timestamp and entry.timestamp >= cutoff then
            entries[#entries + 1] = {
                guid = entry.guid,
                itemLink = entry.itemLink,
                itemID = entry.itemID,
                itemName = entry.itemName,
                winner = entry.winner,
                winnerResponse = entry.winnerResponse,
                encounterID = entry.encounterID,
                encounterName = entry.encounterName,
                timestamp = entry.timestamp,
            }
        end
    end

    return entries
end

--- Handle history sync request
-- @param sender string
-- @param days number
function LoothingSyncMixin:HandleHistorySyncRequest(sender, days)
    StaticPopup_Show("LOOTHING_ACCEPT_HISTORY_SYNC", sender, tostring(days), {
        sender = sender,
        days = days,
        onAccept = function()
            self:AcceptHistorySync(sender)
        end
    })
end

--- Accept history sync
-- @param sender string
function LoothingSyncMixin:AcceptHistorySync(sender)
    local msg = LoothingProtocol:Encode(LOOTHING_MSG_TYPE.SYNC_HISTORY_ACK, {})
    Loothing.Comm:SendToPlayer(msg, sender)

    self.awaitingHistoryFrom = sender
    Loothing:Print("Accepted history sync from " .. sender)
end

--- Handle history sync acknowledgment
-- @param sender string
function LoothingSyncMixin:HandleHistorySyncAck(sender)
    if not self.historySyncInProgress or not self.pendingHistorySync then
        return
    end

    -- Track response
    self.historySyncResponses = self.historySyncResponses or {}
    self.historySyncResponses[sender] = true

    -- Serialize and compress history
    local Serializer = Loolib:GetModule("Serializer")
    local Compressor = Loolib:GetModule("Compressor")

    local serialized = Serializer:Serialize(self.pendingHistorySync)
    local compressed = Compressor and Compressor:Compress(serialized) or serialized

    -- Send history data
    local msg = LoothingProtocol:Encode(LOOTHING_MSG_TYPE.SYNC_HISTORY_DATA, { compressed })
    Loothing.Comm:SendToPlayer(msg, sender)

    Loothing:Print(string.format("Sent %d history entries to %s", #self.pendingHistorySync, sender))
end

--- Handle history data
-- @param data string
-- @param sender string
function LoothingSyncMixin:HandleHistoryData(data, sender)
    if self.awaitingHistoryFrom ~= sender then return end

    if not data then
        Loothing:Debug("Empty history data from " .. sender)
        self.awaitingHistoryFrom = nil
        return
    end

    self.awaitingHistoryFrom = nil

    local Serializer = Loolib:GetModule("Serializer")
    local Compressor = Loolib:GetModule("Compressor")

    local decompressed = Compressor and Compressor:Decompress(data) or data
    local entries = Serializer:Deserialize(decompressed)

    if not entries or type(entries) ~= "table" then
        Loothing:Print("Failed to parse history from " .. sender)
        return
    end

    -- Import history entries (avoid duplicates)
    local imported = 0
    for _, entry in ipairs(entries) do
        local existing = Loothing.History:GetEntryByGUID(entry.guid)
        if not existing then
            Loothing.History:AddEntry(entry)
            imported = imported + 1
        end
    end

    Loothing:Print(string.format("Imported %d history entries from %s", imported, sender))
end

--[[--------------------------------------------------------------------
    Factory
----------------------------------------------------------------------]]

function CreateLoothingSync()
    local sync = LoolibCreateFromMixins(LoothingSyncMixin)
    sync:Init()
    return sync
end
