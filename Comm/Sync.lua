--[[--------------------------------------------------------------------
    Loothing - Loot Council Addon for WoW 12.0+
    Sync - State synchronization for late joiners, settings, and history

    Uses Loothing.Comm convenience methods for all communication.
    The Protocol layer handles serialization/compression automatically.
----------------------------------------------------------------------]]

local _, ns = ...
local Loolib = LibStub("Loolib")
local Loothing = ns.Addon
local L = ns.Locale
local CreateFromMixins = Loolib.CreateFromMixins
local Utils = ns.Utils

ns.SyncMixin = CreateFromMixins(Loolib.CallbackRegistryMixin, ns.SyncMixin or {})

local function GetPopups()
    return ns.Popups
end

--[[--------------------------------------------------------------------
    SyncMixin
----------------------------------------------------------------------]]

local SyncMixin = ns.SyncMixin

local SYNC_EVENTS = {
    "OnSyncComplete",
    "OnSyncFailed",
    "OnSyncProgress",
}

--- Initialize sync handler
function SyncMixin:Init()
    Loolib.CallbackRegistryMixin.OnLoad(self)
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
function SyncMixin:RegisterCommEvents()
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

    Loothing.Comm:RegisterCallback("OnIncrementalSyncRequest", function(_, data)
        self:HandleIncrementalSyncRequest(data)
    end, self)

    Loothing.Comm:RegisterCallback("OnIncrementalSyncData", function(_, data)
        self:HandleIncrementalSyncData(data)
    end, self)
end

--[[--------------------------------------------------------------------
    Sync Requesting (Client Side)
----------------------------------------------------------------------]]

--- Request sync from the master looter, with up to 3 automatic retries on timeout
-- @param masterLooter string - Name of the ML to sync from
-- @param retryCount number - Internal: current retry attempt (0-indexed)
function SyncMixin:RequestSync(masterLooter, retryCount)
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
    self.syncTimeout = C_Timer.NewTimer(Loothing.Timing.SYNC_TIMEOUT, function()
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
function SyncMixin:CancelSync(reason)
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
function SyncMixin:HandleSyncData(data)
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
function SyncMixin:ApplySyncData(data)
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
    if data.state == Loothing.SessionState.INACTIVE then
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

--- Handle sync request from another player.
-- Requests arriving within SYNC_COALESCE_WINDOW seconds are batched: the ML
-- gathers state once and sends the same payload to all requesters. This
-- converts 25 simultaneous GatherSyncData() calls into 1 gather + 25 sends.
-- @param data table - Request data
function SyncMixin:HandleSyncRequest(data)
    -- Only ML should respond to sync requests
    if not Loothing.Session or not Loothing.Session:IsMasterLooter() then
        return
    end

    local requester = data.requester

    -- Requester may have left between sending the request and us processing it
    if not Utils.IsGroupMember(requester) then
        Loothing:Debug("Sync request from departed player, ignoring:", requester)
        return
    end

    Loothing:Debug("Received sync request from", requester)

    -- Add to coalesce batch
    if not self.pendingSyncRequesters then
        self.pendingSyncRequesters = {}
    end
    self.pendingSyncRequesters[requester] = true

    -- Schedule a flush if not already pending
    if not self.syncCoalesceTimer then
        local window = Loothing.Timing.SYNC_COALESCE_WINDOW or 2
        self.syncCoalesceTimer = C_Timer.NewTimer(window, function()
            self:FlushSyncRequests()
        end)
    end
end

--- Flush all coalesced sync requests: gather state once, send to each requester
function SyncMixin:FlushSyncRequests()
    self.syncCoalesceTimer = nil

    if not self.pendingSyncRequesters then return end

    local requesters = self.pendingSyncRequesters
    self.pendingSyncRequesters = nil

    -- Gather state once for all requesters
    local syncData = self:GatherSyncData()

    local count = 0
    for requester in pairs(requesters) do
        -- Re-validate: requester may have left during the coalesce window
        if Utils.IsGroupMember(requester) then
            Loothing.Comm:SendSyncData(syncData, requester)
            count = count + 1
        end
    end
    Loothing:Debug("Sync: flushed coalesced sync to", count, "requesters")
end

--- Gather current session state for sync (full reconnect packet)
-- Includes session, items with candidates/votes, MLDB, and council roster
-- @return table
function SyncMixin:GatherSyncData()
    local session = Loothing.Session

    if not session or session:GetState() == Loothing.SessionState.INACTIVE then
        return {
            sessionID = "",
            encounterID = 0,
            encounterName = "",
            state = Loothing.SessionState.INACTIVE,
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
-- Jittered delay to prevent thundering herd when multiple clients
-- detect roster changes simultaneously. Suppressed during grace period.
function SyncMixin:CheckNeedSync()
    if not IsInGroup() then return end

    -- Don't sync if we're the ML (we own the session)
    if Loothing.handleLoot then return end

    -- Don't sync during reconnect grace period (CommState will coordinate)
    local CommState = Loothing.CommState
    if CommState and CommState:IsInGracePeriod() then
        Loothing:Debug("Sync: suppressed CheckNeedSync (grace period)")
        return
    end

    -- Don't sync if we have a live session (confirmed by recent heartbeat).
    -- Allow sync if session appears stale (no heartbeat for 90s = 3 missed intervals).
    if Loothing.Session and Loothing.Session:GetState() ~= Loothing.SessionState.INACTIVE then
        local lastHB = Loothing.AckTracker and Loothing.AckTracker.lastHeartbeatTime or 0
        if (GetTime() - lastHB) < 90 then
            return
        end
        Loothing:Debug("Sync: session appears stale (no heartbeat for 90s), allowing sync")
    end

    -- Prefer known ML, fall back to raid leader
    local syncTarget = Loothing.masterLooter or Utils.GetRaidLeader()
    if syncTarget then
        -- Cancel any pending sync-check timer to avoid unbounded timer spawns
        if self.pendingSyncCheckTimer then
            self.pendingSyncCheckTimer:Cancel()
        end
        -- Jittered delay: 1.5-4.5s (prevents all clients syncing at the same instant)
        local delay = CommState and CommState:Jitter(3, 1.5) or 2
        self.pendingSyncCheckTimer = C_Timer.NewTimer(delay, function()
            self.pendingSyncCheckTimer = nil
            -- Route through CommState dedup if available
            if CommState then
                CommState:RequestSyncIfNeeded("roster", syncTarget)
            else
                self:RequestSync(syncTarget)
            end
        end)
    end
end

--[[--------------------------------------------------------------------
    Observer Roster Sync
----------------------------------------------------------------------]]

--- Broadcast observer roster to raid (ML-only)
function SyncMixin:BroadcastObserverRoster()
    if not Loothing.Session or not Loothing.Session:IsMasterLooter() then return end
    if not Loothing.Observer then return end

    local data = {
        list = Loothing.Observer:GetObservers(),
        permissions = Loothing.Settings and Loothing.Settings:GetObserverPermissions() or {},
        openObservation = Loothing.Settings and Loothing.Settings:GetOpenObservation() or false,
        mlIsObserver = Loothing.Settings and Loothing.Settings:GetMLIsObserver() or false,
    }
    Loothing.Comm:Send(Loothing.MsgType.OBSERVER_ROSTER, data)
end

--- Handle received observer roster (non-ML players)
-- @param data table - { list, permissions, openObservation, mlIsObserver }
function SyncMixin:HandleObserverRoster(data)
    if not Loothing.Observer then return end
    if not data.masterLooter then return end

    -- Non-ML players mirror the ML's observer roster
    if not (Loothing.Session and Loothing.Session:IsMasterLooter()) then
        Loothing.Observer:SetRemoteObserverList(data)
    end
end

--[[--------------------------------------------------------------------
    Council Roster Sync
----------------------------------------------------------------------]]

--- Sync council roster to raid
function SyncMixin:BroadcastCouncilRoster()
    if not (Loothing.Session and Loothing.Session:IsMasterLooter()) then return end
    if not Loothing.Council then return end

    local members = Loothing.Council:GetAllMembers()
    Loothing.Comm:BroadcastCouncilRoster(members)
end

--- Handle received council roster
-- @param data table
function SyncMixin:HandleCouncilRoster(data)
    if not Loothing.Council then return end

    -- Only accept roster from ML
    if not data.masterLooter then return end

    -- Update local council roster (non-ML players mirror the ML's roster)
    if not (Loothing.Session and Loothing.Session:IsMasterLooter()) then
        Loothing.Council:SetRemoteRoster(data.members)
    end
end

--[[--------------------------------------------------------------------
    Settings Sync
----------------------------------------------------------------------]]

--- Request to sync settings to target (guild or player)
-- @param target string - "guild" or player name
function SyncMixin:RequestSettingsSync(target)
    if self.settingsSyncInProgress then
        Loothing:Print(L["SYNC_IN_PROGRESS"])
        return
    end

    local settings = self:GatherSettings()
    self.pendingSettingsSync = settings
    self.settingsSyncInProgress = true
    self.settingsSyncResponses = {}

    Loothing.Comm:SendSettingsSyncRequest(target)

    if target == "guild" then
        Loothing:Print(L["SYNC_SETTINGS_TO_GUILD"])
    else
        Loothing:Print(string.format(L["SYNC_SETTINGS_TO_PLAYER"], target))
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
                Loothing:Print(string.format(L["SYNC_SETTINGS_COMPLETED"], count))
            else
                Loothing:Print(L["SYNC_TIMEOUT"])
            end
        end
    end)
end

--- Gather current settings for sync
-- @return table
function SyncMixin:GatherSettings()
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
function SyncMixin:HandleSettingsSyncRequest(sender)
    local Popups = GetPopups()
    if not Popups then return end

    Popups:Show("LOOTHING_SYNC_REQUEST", {
        player = sender,
        type = "settings",
        onAccept = function()
            self:AcceptSettingsSync(sender)
        end
    })
end

--- Accept settings sync from sender
-- @param sender string
function SyncMixin:AcceptSettingsSync(sender)
    Loothing.Comm:SendSettingsSyncAck(sender)

    self.awaitingSettingsFrom = sender
    Loothing:Print(string.format(L["SYNC_ACCEPTED_FROM"], sender))
end

--- Handle settings sync acknowledgment
-- @param sender string
function SyncMixin:HandleSettingsSyncAck(sender)
    if not self.settingsSyncInProgress or not self.pendingSettingsSync then
        return
    end

    -- Track response
    self.settingsSyncResponses = self.settingsSyncResponses or {}
    self.settingsSyncResponses[sender] = true

    -- Send settings data (Protocol handles serialization+compression)
    Loothing.Comm:SendSettingsData(self.pendingSettingsSync, sender)

    Loothing:Print(string.format(L["SYNC_SETTINGS_SENT"], sender))
end

--- Handle received settings data
-- Settings data is already deserialized by the Protocol layer.
-- @param data table - Settings table
-- @param sender string
function SyncMixin:HandleSettingsData(data, sender)
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

    Loothing:Print(string.format(L["SYNC_SETTINGS_APPLIED"], sender))
end

--- Apply received settings
-- @param settings table
function SyncMixin:ApplySettings(settings)
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
function SyncMixin:RequestHistorySync(target, days)
    days = days or 7

    if self.historySyncInProgress then
        Loothing:Print(L["SYNC_IN_PROGRESS"])
        return
    end

    local history = self:GatherHistory(days)
    self.pendingHistorySync = history
    self.historySyncInProgress = true
    self.historySyncResponses = {}

    Loothing.Comm:SendHistorySyncRequest(target, days)

    if target == "guild" then
        Loothing:Print(string.format(L["SYNC_HISTORY_GUILD_DAYS"], days))
    else
        Loothing:Print(string.format(L["SYNC_HISTORY_TO_PLAYER"], days, target))
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
                Loothing:Print(string.format(L["SYNC_HISTORY_COMPLETED"], count))
            else
                Loothing:Print(L["SYNC_TIMEOUT"])
            end
        end
    end)
end

--- Gather recent history entries
-- @param days number
-- @return table
function SyncMixin:GatherHistory(days)
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
function SyncMixin:HandleHistorySyncRequest(sender, days)
    local Popups = GetPopups()
    if not Popups then return end

    Popups:Show("LOOTHING_SYNC_REQUEST", {
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
function SyncMixin:AcceptHistorySync(sender)
    Loothing.Comm:SendHistorySyncAck(sender)

    self.awaitingHistoryFrom = sender
    Loothing:Print(string.format(L["SYNC_ACCEPTED_FROM"], sender))
end

--- Handle history sync acknowledgment
-- @param sender string
function SyncMixin:HandleHistorySyncAck(sender)
    if not self.historySyncInProgress or not self.pendingHistorySync then
        return
    end

    -- Track response
    self.historySyncResponses = self.historySyncResponses or {}
    self.historySyncResponses[sender] = true

    -- Send history data (Protocol handles serialization+compression)
    Loothing.Comm:SendHistoryData(self.pendingHistorySync, sender)

    Loothing:Print(string.format(L["SYNC_HISTORY_SENT"], #self.pendingHistorySync, sender))
end

--- Handle history data
-- History data is already deserialized by the Protocol layer.
-- @param data table - History entries
-- @param sender string
function SyncMixin:HandleHistoryData(data, sender)
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

    Loothing:Print(string.format(L["HISTORY_SYNCED"], imported, sender))
end

--[[--------------------------------------------------------------------
    Incremental Sync
    Lighter than full SYNC_DATA — only transfers the specific subset that
    diverged according to the heartbeat digest (council, MLDB, items, etc.)
----------------------------------------------------------------------]]

--- Request an incremental sync from the ML for a specific mismatch type.
-- Called by AckTracker when it can identify exactly what diverged.
-- @param mlName string
-- @param mismatchType string - "council", "mldb", "items", "itemStates"
function SyncMixin:RequestIncrementalSync(mlName, mismatchType)
    if not Loothing.Comm then return end
    Loothing:Debug("Sync: requesting incremental sync for", mismatchType, "from", mlName)
    Loothing.Comm:Send(Loothing.MsgType.SYNC_INCREMENTAL, {
        type = mismatchType,
        sessionID = Loothing.Session and Loothing.Session:GetSessionID() or "",
    }, mlName, "NORMAL")
end

--- ML-side: handle incremental sync request and return only the requested subset
-- @param data table - { requester, type, sessionID }
function SyncMixin:HandleIncrementalSyncRequest(data)
    if not Loothing.Session or not Loothing.Session:IsMasterLooter() then return end

    local requester = data.requester
    if not requester or not Utils.IsGroupMember(requester) then return end

    local mismatchType = data.type
    local responseData = { type = mismatchType }

    if mismatchType == "council" then
        if Loothing.Council then
            responseData.councilRoster = Loothing.Council:GetAllMembers()
        end
    elseif mismatchType == "mldb" then
        if Loothing.MLDB and Loothing.MLDB:Get() then
            responseData.mldb = Loothing.MLDB:Get()
        end
    elseif mismatchType == "items" or mismatchType == "itemStates" then
        -- Send compact item list (guid + state + link, no candidate data)
        local session = Loothing.Session
        responseData.items = {}
        if session.items then
            for _, item in session.items:Enumerate() do
                responseData.items[#responseData.items + 1] = {
                    guid = item.guid,
                    itemLink = item.itemLink,
                    looter = item.looter,
                    state = item:GetState(),
                }
            end
        end
        responseData.sessionID = session:GetSessionID()
        responseData.sessionState = session:GetState()
    else
        -- Unknown type — fall back to full sync
        Loothing:Debug("Sync: unknown incremental type", mismatchType, "— falling back to full")
        self:HandleSyncRequest(data)
        return
    end

    Loothing:Debug("Sync: sending incremental data (type:", mismatchType, ") to", requester)
    Loothing.Comm:Send(Loothing.MsgType.SYNC_INCREMENTAL_DATA, responseData, requester, "NORMAL")
end

--- Client-side: apply incremental sync data from ML
-- @param data table - { type, councilRoster?, mldb?, items?, sessionID? }
function SyncMixin:HandleIncrementalSyncData(data)
    if not data or not data.type then return end

    local mismatchType = data.type
    Loothing:Debug("Sync: applying incremental data (type:", mismatchType, ")")

    if mismatchType == "council" and data.councilRoster then
        if Loothing.Council then
            Loothing.Council:SetRemoteRoster(data.councilRoster)
        end
    elseif mismatchType == "mldb" and data.mldb then
        if Loothing.MLDB then
            Loothing.MLDB:ApplyFromML(data.mldb, data.masterLooter)
        end
    elseif (mismatchType == "items" or mismatchType == "itemStates") and data.items then
        local session = Loothing.Session
        if not session then return end

        -- Check if we have item count/state mismatches and add missing items
        local localItems = {}
        if session.items then
            for _, item in session.items:Enumerate() do
                localItems[item.guid] = item
            end
        end

        for _, remoteItem in ipairs(data.items) do
            local localItem = localItems[remoteItem.guid]
            if not localItem then
                -- Missing item — add it
                session:AddItem(remoteItem.itemLink, remoteItem.looter, remoteItem.guid, true)
                localItem = session:GetItemByGUID(remoteItem.guid)
            end
            if localItem and remoteItem.state then
                localItem:SetState(remoteItem.state)
            end
        end
    end

    self:TriggerEvent("OnSyncComplete", data)
end

--[[--------------------------------------------------------------------
    Factory
----------------------------------------------------------------------]]

function ns.CreateSync()
    local sync = CreateFromMixins(SyncMixin)
    sync:Init()
    return sync
end

-- ns.SyncMixin and ns.CreateSync exported above
