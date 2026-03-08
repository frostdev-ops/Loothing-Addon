--[[--------------------------------------------------------------------
    Loothing - Loot Council Addon for WoW 12.0+
    Sync - State synchronization for late joiners, settings, and history

    Uses Loothing.Comm convenience methods for all communication.
    The Protocol layer handles serialization/compression automatically.
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
    self.pendingSyncCheckTimer = nil

    -- Listen for sync messages
    self:RegisterCommEvents()
end

--- Register for communication events
function LoothingSyncMixin:RegisterCommEvents()
    if not Loothing.Comm then return end

    Loothing.Comm:RegisterCallback("OnSyncRequest", function(_, data)
        self:HandleSyncRequest(data)
    end, self)

    Loothing.Comm:RegisterCallback("OnSyncData", function(_, data)
        self:HandleSyncData(data)
    end, self)

    Loothing.Comm:RegisterCallback("OnObserverRoster", function(_, data)
        self:HandleObserverRoster(data)
    end, self)
end

--[[--------------------------------------------------------------------
    Sync Requesting (Client Side)
----------------------------------------------------------------------]]

--- Request sync from the master looter, with up to 3 automatic retries on timeout
-- @param masterLooter string - Name of the ML to sync from
-- @param retryCount number - Internal: current retry attempt (0-indexed)
function LoothingSyncMixin:RequestSync(masterLooter, retryCount)
    retryCount = retryCount or 0
    local MAX_RETRIES = 3

    if retryCount >= MAX_RETRIES then
        self.syncInProgress = false
        self.syncTarget     = nil
        Loothing:Debug("Sync failed: max retries exceeded for", masterLooter)
        self:TriggerEvent("OnSyncFailed", "Max retries exceeded")
        return
    end

    -- On initial call only: block if already syncing
    if retryCount == 0 and self.syncInProgress then
        Loothing:Debug("Sync already in progress")
        return
    end

    if not masterLooter then
        Loothing:Debug("No master looter specified for sync")
        self:TriggerEvent("OnSyncFailed", "No master looter")
        return
    end

    self.syncInProgress = true
    self.syncTarget     = masterLooter
    self.pendingItems   = {}

    -- Cancel any pending timeout from a previous attempt
    if self.syncTimeout then
        self.syncTimeout:Cancel()
        self.syncTimeout = nil
    end

    -- Send sync request
    Loothing.Comm:RequestSync(masterLooter)

    -- Set timeout with retry on expiry
    self.syncTimeout = C_Timer.NewTimer(LOOTHING_TIMING.SYNC_TIMEOUT, function()
        if self.syncInProgress then
            Loothing:Debug("Sync timeout, retry", retryCount + 1, "of", MAX_RETRIES,
                "from", masterLooter)
            self.syncInProgress = false
            self:RequestSync(masterLooter, retryCount + 1)
        end
    end)

    if retryCount == 0 then
        self:TriggerEvent("OnSyncProgress", "Requesting sync...")
    else
        self:TriggerEvent("OnSyncProgress", "Retrying sync (attempt " .. (retryCount + 1) .. ")...")
    end

    Loothing:Debug("Requesting sync from", masterLooter,
        "(attempt " .. (retryCount + 1) .. "/" .. MAX_RETRIES .. ")")
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
    -- Restore MLDB from sync packet (before session, so candidates see correct config)
    if data.mldb and Loothing.MLDB then
        Loothing.MLDB:ApplyFromML(data.mldb, data.masterLooter or "")
    end

    -- Restore council roster from sync packet
    if data.councilRoster and Loothing.Council then
        Loothing.Council:SetRemoteRoster(data.councilRoster)
    end

    -- Restore observer roster from sync packet
    if data.observerRoster and Loothing.Observer then
        Loothing.Observer:SetRemoteObserverList(data.observerRoster)
    end

    if not Loothing.Session then return end

    -- Check if there's an active session
    if data.state == LOOTHING_SESSION_STATE.INACTIVE then
        -- If the local client still has an active session, clean it up
        if Loothing.Session:IsActive() then
            Loothing:Debug("Sync reports INACTIVE but local session is active, ending stale session")
            Loothing.Session:EndSession()
        end
        return
    end

    -- Create/update session
    Loothing.Session:SyncFromData({
        sessionID = data.sessionID,
        encounterID = data.encounterID,
        encounterName = data.encounterName,
        state = data.state,
        masterLooter = data.masterLooter,
        items = data.items,
    })
end

--[[--------------------------------------------------------------------
    Sync Responding (ML Side)
----------------------------------------------------------------------]]

--- Handle sync request from another player
-- @param data table - Request data
function LoothingSyncMixin:HandleSyncRequest(data)
    -- Only ML should respond to sync requests
    if not Loothing.Session or not Loothing.Session:IsMasterLooter() then
        return
    end

    local requester = data.requester

    Loothing:Debug("Received sync request from", requester)

    -- Gather current state
    local syncData = self:GatherSyncData()

    -- Send response (items/candidates/votes are already embedded in syncData.items)
    Loothing.Comm:SendSyncData(syncData, requester)
end

--- Gather current session state for sync (full reconnect packet)
-- Includes session, items with candidates/votes, MLDB, and council roster
-- @return table
function LoothingSyncMixin:GatherSyncData()
    local session = Loothing.Session

    if not session or session:GetState() == LOOTHING_SESSION_STATE.INACTIVE then
        return {
            sessionID = "",
            encounterID = 0,
            encounterName = "",
            state = LOOTHING_SESSION_STATE.INACTIVE,
            items = {},
        }
    end

    -- Gather items with candidate and vote data
    local items = {}
    if session.items then
        for _, item in session.items:Enumerate() do
            local itemData = {
                guid = item.guid,
                itemLink = item.itemLink,
                looter = item.looter,
                state = item:GetState(),
            }

            -- Include candidate data for each item
            if item.candidateManager then
                local candidates = item.candidateManager:GetAllCandidates()
                if candidates and #candidates > 0 then
                    itemData.candidates = {}
                    for _, candidate in ipairs(candidates) do
                        local cData = {
                            name = candidate.playerName,
                            class = candidate.playerClass,
                            response = candidate.response,
                            roll = candidate.roll,
                            note = candidate.note,
                            gear1 = candidate.gear1Link,
                            gear2 = candidate.gear2Link,
                            ilvl1 = candidate.gear1ilvl,
                            ilvl2 = candidate.gear2ilvl,
                            itemsWon = candidate.itemsWonThisSession,
                        }

                        -- Include voter data
                        if candidate.voters and #candidate.voters > 0 then
                            cData.voters = candidate.voters
                        end

                        itemData.candidates[#itemData.candidates + 1] = cData
                    end
                end
            end

            items[#items + 1] = itemData
        end
    end

    local syncData = {
        sessionID = session:GetSessionID(),
        encounterID = session:GetEncounterID(),
        encounterName = session:GetEncounterName(),
        state = session:GetState(),
        masterLooter = session:GetMasterLooter(),
        items = items,
    }

    -- Include MLDB
    if Loothing.MLDB and Loothing.MLDB:Get() then
        syncData.mldb = Loothing.MLDB:Get()
    end

    -- Include council roster
    if Loothing.Council then
        local members = Loothing.Council:GetAllMembers()
        if members and #members > 0 then
            syncData.councilRoster = members
        end
    end

    -- Include observer roster
    if Loothing.Observer then
        syncData.observerRoster = {
            list = Loothing.Observer:GetObservers(),
            permissions = Loothing.Settings and Loothing.Settings:GetObserverPermissions() or {},
            openObservation = Loothing.Settings and Loothing.Settings:GetOpenObservation() or false,
            mlIsObserver = Loothing.Settings and Loothing.Settings:GetMLIsObserver() or false,
        }
    end

    return syncData
end

--- Send item data to sync target
-- @param target string - Player to send to
-- NOTE: SendItemSync is intentionally removed. GatherSyncData() already embeds
-- all item + candidate + vote data into the SYNC_DATA payload, and SyncFromData()
-- on the receiver restores all of it. Sending individual ITEM_ADD/CANDIDATE_UPDATE/
-- VOTE_UPDATE messages per item was redundant and caused O(N*M) message overhead.

--[[--------------------------------------------------------------------
    Auto-Sync on Join
----------------------------------------------------------------------]]

--- Check if we need to sync (called on roster update)
function LoothingSyncMixin:CheckNeedSync()
    if not IsInGroup() then return end

    -- Don't sync if we're the ML (we own the session)
    if Loothing.handleLoot then return end

    -- Don't sync if already have a session
    if Loothing.Session and Loothing.Session:GetState() ~= LOOTHING_SESSION_STATE.INACTIVE then
        return
    end

    -- Prefer known ML, fall back to raid leader
    local syncTarget = Loothing.masterLooter or LoothingUtils.GetRaidLeader()
    if syncTarget then
        -- Cancel any pending sync-check timer to avoid unbounded timer spawns
        if self.pendingSyncCheckTimer then
            self.pendingSyncCheckTimer:Cancel()
        end
        -- Delay sync slightly to allow other addons to initialize
        self.pendingSyncCheckTimer = C_Timer.NewTimer(2, function()
            self.pendingSyncCheckTimer = nil
            self:RequestSync(syncTarget)
        end)
    end
end

--[[--------------------------------------------------------------------
    Observer Roster Sync
----------------------------------------------------------------------]]

--- Broadcast observer roster to raid (ML-only)
function LoothingSyncMixin:BroadcastObserverRoster()
    if not Loothing.Session or not Loothing.Session:IsMasterLooter() then return end
    if not Loothing.Observer then return end

    local data = {
        list = Loothing.Observer:GetObservers(),
        permissions = Loothing.Settings and Loothing.Settings:GetObserverPermissions() or {},
        openObservation = Loothing.Settings and Loothing.Settings:GetOpenObservation() or false,
        mlIsObserver = Loothing.Settings and Loothing.Settings:GetMLIsObserver() or false,
    }
    Loothing.Comm:Send(LOOTHING_MSG_TYPE.OBSERVER_ROSTER, data)
end

--- Handle received observer roster (non-ML players)
-- @param data table - { list, permissions, openObservation, mlIsObserver }
function LoothingSyncMixin:HandleObserverRoster(data)
    if not Loothing.Observer then return end
    if not data.masterLooter then return end

    -- Non-ML players mirror the ML's observer roster
    if not LoothingUtils.IsRaidLeaderOrAssistant() then
        Loothing.Observer:SetRemoteObserverList(data)
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

    Loothing.Comm:SendSettingsSyncRequest(target)

    if target == "guild" then
        Loothing:Print("Requesting settings sync to guild...")
    else
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

    if Loothing.ResponseManager then
        settings.responseSets = Loothing.ResponseManager:Serialize()
    end

    if Loothing.Settings then
        settings.voting = {
            mode    = Loothing.Settings:GetVotingMode(),
            timeout = Loothing.Settings:GetVotingTimeout(),
        }
    end

    return settings
end

--- Handle incoming settings sync request
-- @param sender string
function LoothingSyncMixin:HandleSettingsSyncRequest(sender)
    LoothingPopups:Show("LOOTHING_SYNC_REQUEST", {
        player = sender,
        type = "settings",
        onAccept = function()
            self:AcceptSettingsSync(sender)
        end
    })
end

--- Accept settings sync from sender
-- @param sender string
function LoothingSyncMixin:AcceptSettingsSync(sender)
    Loothing.Comm:SendSettingsSyncAck(sender)

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

    -- Send settings data (Protocol handles serialization+compression)
    Loothing.Comm:SendSettingsData(self.pendingSettingsSync, sender)

    Loothing:Print("Sent settings to " .. sender)
end

--- Handle received settings data
-- Settings data is already deserialized by the Protocol layer.
-- @param data table - Settings table
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

    -- Apply settings directly (no need to deserialize, Protocol already did)
    self:ApplySettings(data)

    Loothing:Print("Applied settings from " .. sender)
end

--- Apply received settings
-- @param settings table
function LoothingSyncMixin:ApplySettings(settings)
    if settings.responseSets and Loothing.ResponseManager then
        Loothing.ResponseManager:Deserialize(settings.responseSets)
    end

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

    Loothing.Comm:SendHistorySyncRequest(target, days)

    if target == "guild" then
        Loothing:Print(string.format("Requesting history sync (%d days) to guild...", days))
    else
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
            local syncEntry = {}
            for k, v in pairs(entry) do
                if k ~= "candidates" and k ~= "councilVotes" then
                    syncEntry[k] = v
                end
            end
            entries[#entries + 1] = syncEntry
        end
    end

    return entries
end

--- Handle history sync request
-- @param sender string
-- @param days number
function LoothingSyncMixin:HandleHistorySyncRequest(sender, days)
    LoothingPopups:Show("LOOTHING_SYNC_REQUEST", {
        player = sender,
        type = "history",
        days = days,
        onAccept = function()
            self:AcceptHistorySync(sender)
        end
    })
end

--- Accept history sync
-- @param sender string
function LoothingSyncMixin:AcceptHistorySync(sender)
    Loothing.Comm:SendHistorySyncAck(sender)

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

    -- Send history data (Protocol handles serialization+compression)
    Loothing.Comm:SendHistoryData(self.pendingHistorySync, sender)

    Loothing:Print(string.format("Sent %d history entries to %s", #self.pendingHistorySync, sender))
end

--- Handle history data
-- History data is already deserialized by the Protocol layer.
-- @param data table - History entries
-- @param sender string
function LoothingSyncMixin:HandleHistoryData(data, sender)
    if self.awaitingHistoryFrom ~= sender then return end

    if not data or type(data) ~= "table" then
        Loothing:Debug("Empty history data from " .. sender)
        self.awaitingHistoryFrom = nil
        return
    end

    self.awaitingHistoryFrom = nil

    -- Import history entries (avoid duplicates, validate required fields)
    local imported = 0
    local skipped = 0
    for _, entry in ipairs(data) do
        -- Validate required fields before importing
        if not entry.itemLink or not entry.winner then
            skipped = skipped + 1
            Loothing:Debug("HandleHistoryData: skipped entry missing required fields",
                "itemLink:", entry.itemLink ~= nil, "winner:", entry.winner ~= nil)
        else
            local existing = Loothing.History:GetEntryByGUID(entry.guid)
            if not existing then
                Loothing.History:AddEntry(entry)
                imported = imported + 1
            end
        end
    end

    if skipped > 0 then
        Loothing:Debug("HandleHistoryData: skipped", skipped, "entries with missing fields from", sender)
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
