--[[--------------------------------------------------------------------
    Loothing - Comm Handlers (Core/Voting/Sync)
    Message handlers for ns.CommMixin.

    All handlers receive structured table data (from Serializer),
    not string arrays. Security validation is applied per-handler.
----------------------------------------------------------------------]]

local _, ns = ...
local Loolib = LibStub("Loolib")
local GetNumGroupMembers = GetNumGroupMembers
local GetNumSubgroupMembers = GetNumSubgroupMembers
local IsInGroup = IsInGroup
local IsInRaid = IsInRaid
local UnitIsGroupAssistant = UnitIsGroupAssistant
local UnitIsGroupLeader = UnitIsGroupLeader
local Loothing = ns.Addon
local Utils = ns.Utils
local TestMode = ns.TestMode

ns.CommMixin = ns.CommMixin or {}

local CommMixin = ns.CommMixin

--[[--------------------------------------------------------------------
    Security Helpers
----------------------------------------------------------------------]]

--- Check if sender is the current master looter
-- @param sender string
-- @return boolean
local function isMasterLooter(sender)
    if not sender then return false end
    local ml
    if Loothing.Session then
        ml = Loothing.Session:GetMasterLooter()
    end
    if not ml and Loothing.Settings then
        ml = Loothing.Settings:GetMasterLooter()
    end
    if not ml then return false end
    return Utils.IsSamePlayer(ml, sender)
end

--- Check if sender is a council member
-- @param sender string
-- @return boolean
local function isCouncilMember(sender)
    if not Loothing.Council then return false end
    return Loothing.Council:IsMember(sender)
end

--- Check if sender is a raid/party leader or assistant
-- @param sender string
-- @return boolean
local function isGroupLeaderOrAssistant(sender)
    if TestMode and TestMode:IsEnabled() then
        return true
    end
    local normalizedSender = Utils.NormalizeName(sender)
    if IsInRaid() then
        local numMembers = GetNumGroupMembers()
        for i = 1, numMembers do
            local name, rank = Loolib.SecretUtil.SafeGetRaidRosterInfo(i)
            if name and Utils.IsSamePlayer(name, normalizedSender) then
                -- rank: 0 = member, 1 = assistant, 2 = leader
                return rank == 1 or rank == 2
            end
        end
    elseif IsInGroup() then
        local units = { "player" }
        for i = 1, GetNumSubgroupMembers() do
            units[#units + 1] = "party" .. i
        end
        for _, unit in ipairs(units) do
            local name = Loolib.SecretUtil.SafeUnitName(unit)
            if name and Utils.IsSamePlayer(name, normalizedSender) then
                return UnitIsGroupLeader(unit) or UnitIsGroupAssistant(unit)
            end
        end
    end
    return false
end

--- Check if sender is in the current raid/party
-- @param sender string
-- @return boolean
local function isGroupMember(sender)
    -- Allow in test mode
    if TestMode and TestMode:IsEnabled() then
        return true
    end
    -- If we can't check, fail closed (reject)
    if not Utils or not Utils.GetRaidRoster then return false end
    local roster = Utils.GetRaidRoster()
    for _, member in ipairs(roster) do
        if Utils.IsSamePlayer(member.name, sender) then
            return true
        end
    end
    return false
end

--[[--------------------------------------------------------------------
    Per-Handler Schema Definitions
    Derived from the broadcast helpers in MessageHandler.lua.
    Schema entries: { fieldName, expectedType, required }
----------------------------------------------------------------------]]

local SCHEMAS = {
    ITEM_ADD        = { { "itemLink",  "string", true }, { "guid",      "string", true } },
    VOTE_AWARD      = { { "itemGUID",  "string", true }, { "winner",    "string", true } },
    PLAYER_RESPONSE = { { "itemGUID",  "string", true }, { "response",  nil,      true } },
    VOTE_COMMIT     = { { "itemGUID",  "string", true }, { "responses", "table",  true } },
    BATCH           = { { "messages",  "table",  true } },
    MLDB_BROADCAST  = { { "data",      "table",  true } },
    COUNCIL_ROSTER  = { { "members",   "table",  true } },
    PROFILE_EXPORT_SHARE = {
        { "exportString", "string", true },
        { "shareID", "string", false },
        { "scope", "string", false },
        { "sessionID", "string", false },
    },
}

--- Validate data against a schema and log on failure.
-- Replaces bare `if not data then return end` guards with field-level checks.
-- @param name string - Handler name for debug logging
-- @param data table|nil - Message data
-- @param schema table|nil - Schema from SCHEMAS (nil = nil-check only)
-- @return boolean
local function validateHandler(name, data, schema)
    if not data then
        Loothing:Debug("Rejected", name, "— no data")
        return false
    end
    if schema then
        local ok, reason = Utils.ValidateSchema(data, schema)
        if not ok then
            Loothing:Debug("Rejected", name, "— schema:", reason)
            return false
        end
    end
    return true
end

--[[--------------------------------------------------------------------
    Session Handlers (ML → Group)
----------------------------------------------------------------------]]

function CommMixin:HandleSessionStart(data, sender)
    if not validateHandler("HandleSessionStart", data) then return end
    -- Accept from: known ML, group leader/assistant, or any group member if ML is unknown
    -- (the ML may not be the leader — e.g. designated via /lt ml)
    local senderIsML = isMasterLooter(sender)
    local senderIsLeader = isGroupLeaderOrAssistant(sender)
    local mlUnknown = not Loothing.masterLooter or Loothing.masterLooter == ""
    if not senderIsML and not senderIsLeader then
        if not mlUnknown or not isGroupMember(sender) then
            Loothing:Debug("Rejected SESSION_START from non-ML/non-leader:", sender)
            return
        end
        Loothing:Debug("Accepting SESSION_START from group member (ML unknown):", sender)
    end
    -- If we already have a known ML from local detection, validate sender matches
    if not mlUnknown and not senderIsML and not senderIsLeader then
        Loothing:Debug("Rejected SESSION_START from %s - local ML is %s", sender, Loothing.masterLooter)
        return
    end
    data.masterLooter = sender
    self:TriggerEvent("OnSessionStart", data)
end

function CommMixin:HandleStopHandleLoot(_data, sender)
    -- Only the current ML can broadcast stop
    if not isMasterLooter(sender) then
        Loothing:Debug("Rejected STOP_HANDLE_LOOT from non-ML:", sender)
        return
    end
    self:TriggerEvent("OnStopHandleLoot", { masterLooter = sender })
end

function CommMixin:HandleSessionEnd(_data, sender)
    -- Only the ML who started the session can end it
    if not isMasterLooter(sender) then
        Loothing:Debug("Rejected SESSION_END from non-ML:", sender)
        return
    end
    self:TriggerEvent("OnSessionEnd", {
        masterLooter = sender,
    })
end

--[[--------------------------------------------------------------------
    Item Handlers (ML → Group)
----------------------------------------------------------------------]]

function CommMixin:HandleItemAdd(data, sender)
    if not validateHandler("HandleItemAdd", data, SCHEMAS.ITEM_ADD) then return end
    if not isMasterLooter(sender) then
        Loothing:Debug("Rejected ITEM_ADD from non-ML:", sender)
        return
    end
    data.masterLooter = sender
    self:TriggerEvent("OnItemAdd", data)
end

function CommMixin:HandleItemRemove(data, sender)
    if not validateHandler("HandleItemRemove", data) then return end
    if not isMasterLooter(sender) then
        Loothing:Debug("Rejected ITEM_REMOVE from non-ML:", sender)
        return
    end
    data.masterLooter = sender
    self:TriggerEvent("OnItemRemove", data)
end

--[[--------------------------------------------------------------------
    Vote Handlers
----------------------------------------------------------------------]]

function CommMixin:HandleVoteRequest(data, sender)
    if not validateHandler("HandleVoteRequest", data) then return end
    -- Only ML can request votes
    if not isMasterLooter(sender) then
        Loothing:Debug("Rejected VOTE_REQUEST from non-ML:", sender)
        return
    end
    data.masterLooter = sender
    self:TriggerEvent("OnVoteRequest", data)
end

function CommMixin:HandleVoteCommit(data, sender)
    if not validateHandler("HandleVoteCommit", data, SCHEMAS.VOTE_COMMIT) then return end
    -- Only council members can vote
    if not isCouncilMember(sender) then
        Loothing:Debug("Rejected VOTE_COMMIT from non-council:", sender)
        return
    end
    data.voter = sender
    self:TriggerEvent("OnVoteCommit", data)
end

function CommMixin:HandleVoteCancel(data, sender)
    if not validateHandler("HandleVoteCancel", data) then return end
    if not isMasterLooter(sender) then
        Loothing:Debug("Rejected VOTE_CANCEL from non-ML:", sender)
        return
    end
    data.masterLooter = sender
    self:TriggerEvent("OnVoteCancel", data)
end

function CommMixin:HandleVoteResults(data, sender)
    if not validateHandler("HandleVoteResults", data) then return end
    if not isMasterLooter(sender) then
        Loothing:Debug("Rejected VOTE_RESULTS from non-ML:", sender)
        return
    end
    data.masterLooter = sender
    self:TriggerEvent("OnVoteResults", data)
end

function CommMixin:HandleVoteAward(data, sender)
    if not validateHandler("HandleVoteAward", data, SCHEMAS.VOTE_AWARD) then return end
    if not isMasterLooter(sender) then
        Loothing:Debug("Rejected VOTE_AWARD from non-ML:", sender)
        return
    end
    data.masterLooter = sender
    self:TriggerEvent("OnVoteAward", data)
end

function CommMixin:HandleVoteSkip(data, sender)
    if not validateHandler("HandleVoteSkip", data) then return end
    if not isMasterLooter(sender) then
        Loothing:Debug("Rejected VOTE_SKIP from non-ML:", sender)
        return
    end
    data.masterLooter = sender
    self:TriggerEvent("OnVoteSkip", data)
end

--[[--------------------------------------------------------------------
    History Entry Handler
----------------------------------------------------------------------]]

function CommMixin:HandleHistoryEntry(data, sender)
    if not validateHandler("HandleHistoryEntry", data) then return end
    if not isMasterLooter(sender) and not isGroupLeaderOrAssistant(sender) then
        Loothing:Debug("Rejected HISTORY_ENTRY from non-ML/leader:", sender)
        return
    end
    data.sender = sender
    self:TriggerEvent("OnHistoryEntry", data)
end

--[[--------------------------------------------------------------------
    Sync Handlers
----------------------------------------------------------------------]]

function CommMixin:HandleSyncRequest(data, sender)
    if not validateHandler("HandleSyncRequest", data) then return end
    if not isGroupMember(sender) then
        Loothing:Debug("Rejected SYNC_REQUEST from non-group member:", sender)
        return
    end
    data.requester = sender
    self:TriggerEvent("OnSyncRequest", data)
end

function CommMixin:HandleSyncData(data, sender)
    if not validateHandler("HandleSyncData", data) then return end
    -- Only accept sync data from the ML or a group leader/assistant
    if not isMasterLooter(sender) and not isGroupLeaderOrAssistant(sender) then
        Loothing:Debug("Rejected SYNC_DATA from non-ML/leader:", sender)
        return
    end
    -- If we already have a known ML from local detection, validate sender matches
    if Loothing.masterLooter and Loothing.masterLooter ~= "" and sender ~= Loothing.masterLooter then
        Loothing:Debug("Rejected SYNC_DATA from %s - local ML is %s", sender, Loothing.masterLooter)
        return
    end
    data.masterLooter = sender
    self:TriggerEvent("OnSyncData", data)
end

--[[--------------------------------------------------------------------
    Council Roster Handler
----------------------------------------------------------------------]]

function CommMixin:HandleCouncilRoster(data, sender)
    if not validateHandler("HandleCouncilRoster", data, SCHEMAS.COUNCIL_ROSTER) then return end
    if not isMasterLooter(sender) then
        Loothing:Debug("Rejected COUNCIL_ROSTER from non-ML:", sender)
        return
    end
    data.masterLooter = sender
    self:TriggerEvent("OnCouncilRoster", data)
end

--[[--------------------------------------------------------------------
    Observer Roster Handler
----------------------------------------------------------------------]]

function CommMixin:HandleObserverRoster(data, sender)
    if not validateHandler("HandleObserverRoster", data) then return end
    if not isMasterLooter(sender) then
        Loothing:Debug("Rejected OBSERVER_ROSTER from non-ML:", sender)
        return
    end
    data.masterLooter = sender
    self:TriggerEvent("OnObserverRoster", data)
end

--[[--------------------------------------------------------------------
    Player Info Handlers
----------------------------------------------------------------------]]

function CommMixin:HandlePlayerInfoRequest(data, sender)
    if not validateHandler("HandlePlayerInfoRequest", data) then return end
    if not isMasterLooter(sender) then
        Loothing:Debug("Rejected PLAYER_INFO_REQUEST from non-ML:", sender)
        return
    end
    data.requester = sender
    self:TriggerEvent("OnPlayerInfoRequest", data)
end

function CommMixin:HandlePlayerInfoResponse(data, sender)
    if not validateHandler("HandlePlayerInfoResponse", data) then return end
    if not isGroupMember(sender) then
        Loothing:Debug("Rejected PLAYER_INFO_RESPONSE from non-group member:", sender)
        return
    end
    -- Normalize nil-like values
    if data.slot1Link == "" then data.slot1Link = nil end
    if data.slot2Link == "" then data.slot2Link = nil end
    data.playerName = sender
    self:TriggerEvent("OnPlayerInfoResponse", data)
end

--[[--------------------------------------------------------------------
    Version Handlers
----------------------------------------------------------------------]]

function CommMixin:HandleVersionRequest(_data, sender)
    self:TriggerEvent("OnVersionRequest", {
        requester = sender,
    })
end

function CommMixin:HandleVersionResponse(data, sender)
    if not validateHandler("HandleVersionResponse", data) then return end
    data.sender = sender
    self:TriggerEvent("OnVersionResponse", data)
end

--[[--------------------------------------------------------------------
    Player Response Handlers
----------------------------------------------------------------------]]

function CommMixin:HandlePlayerResponse(data, sender)
    if not validateHandler("HandlePlayerResponse", data, SCHEMAS.PLAYER_RESPONSE) then return end

    -- Only ML processes player responses
    if not Loothing.Session or not Loothing.Session:IsMasterLooter() then
        return
    end

    -- Validate sender is in the group (bypass in test mode)
    local isTestMode = TestMode and TestMode:IsEnabled()
    local isMember = isGroupMember(sender)
    Loothing:Debug("PLAYER_RESPONSE from", sender, "isGroupMember:", isMember)
    if not isMember and not isTestMode then
        Loothing:Debug("Rejected PLAYER_RESPONSE from non-group member:", sender)
        if data.itemGUID then
            self:SendPlayerResponseAck(data.itemGUID, false, sender)
        end
        return
    end

    data.playerName = sender
    self:TriggerEvent("OnPlayerResponse", data)
end

function CommMixin:HandlePlayerResponseAck(data, sender)
    if not validateHandler("HandlePlayerResponseAck", data) then return end
    if not isMasterLooter(sender) then
        Loothing:Debug("Rejected PLAYER_RESPONSE_ACK from non-ML:", sender)
        return
    end
    data.masterLooter = sender
    self:TriggerEvent("OnPlayerResponseAck", data)
end

--[[--------------------------------------------------------------------
    MLDB Handler
----------------------------------------------------------------------]]

function CommMixin:HandleMLDBBroadcast(data, sender)
    if not validateHandler("HandleMLDBBroadcast", data, SCHEMAS.MLDB_BROADCAST) then return end
    -- Accept from: known ML, leader/assistant (bootstraps ML), or group member when ML unknown
    if not isMasterLooter(sender) then
        local mlUnknown = not Loothing.masterLooter or Loothing.masterLooter == ""
        if not mlUnknown or not isGroupMember(sender) then
            Loothing:Debug("Rejected MLDB_BROADCAST from non-ML:", sender)
            return
        end
        Loothing:Debug("Accepting MLDB from group member (ML unknown):", sender)
    end
    data.sender = sender
    self:TriggerEvent("OnMLDBBroadcast", data)
end

--[[--------------------------------------------------------------------
    Candidate & Vote Update Handlers
----------------------------------------------------------------------]]

function CommMixin:HandleCandidateUpdate(data, sender)
    if not validateHandler("HandleCandidateUpdate", data) then return end
    if not isMasterLooter(sender) then
        Loothing:Debug("Rejected CANDIDATE_UPDATE from non-ML:", sender)
        return
    end
    data.masterLooter = sender
    self:TriggerEvent("OnCandidateUpdate", data)
end

function CommMixin:HandleVoteUpdate(data, sender)
    if not validateHandler("HandleVoteUpdate", data) then return end
    if not isMasterLooter(sender) then
        Loothing:Debug("Rejected VOTE_UPDATE from non-ML:", sender)
        return
    end
    data.masterLooter = sender
    self:TriggerEvent("OnVoteUpdate", data)
end

--[[--------------------------------------------------------------------
    Trade Tracking Handlers
----------------------------------------------------------------------]]

function CommMixin:HandleTradable(data, sender)
    if not validateHandler("HandleTradable", data) then return end
    -- Any group member can send tradability status for their own looted items
    if not isGroupMember(sender) then
        Loothing:Debug("Rejected TRADABLE from non-group member:", sender)
        return
    end
    data.playerName = sender
    self:TriggerEvent("OnTradable", data)
end

function CommMixin:HandleNonTradable(data, sender)
    if not validateHandler("HandleNonTradable", data) then return end
    if not isGroupMember(sender) then
        Loothing:Debug("Rejected NON_TRADABLE from non-group member:", sender)
        return
    end
    data.playerName = sender
    self:TriggerEvent("OnNonTradable", data)
end

--[[--------------------------------------------------------------------
    Burst / Resilience Infrastructure Handlers
----------------------------------------------------------------------]]

--- Handle BATCH message — unwrap inner messages and route each individually.
-- Each inner message goes through the same security checks as a direct send.
-- @param data table - { messages = { {command, data}, ... } }
-- @param sender string
-- @param distribution string
function CommMixin:HandleBatch(data, sender, distribution)
    if not validateHandler("HandleBatch", data, SCHEMAS.BATCH) then return end
    -- Enforce the same per-batch cap on the receive side that the send side uses
    if #data.messages > (self.MAX_BATCH_SIZE or 20) then
        Loothing:Debug("Rejected BATCH from", sender, "— too many messages:", #data.messages)
        return
    end

    for _, inner in ipairs(data.messages) do
        if inner.command then
            -- Route each inner message through the normal handler chain.
            -- Security validation happens inside each handler, not here.
            self:RouteMessage(inner.command, inner.data, sender, distribution)
        end
    end
end

--- Handle HEARTBEAT message — delegate to AckTracker for state comparison
-- @param data table - Heartbeat digest { sessionID, state, itemCount, itemStates, councilHash, mldbHash }
-- @param sender string
function CommMixin:HandleHeartbeat(data, sender, _distribution)
    if not validateHandler("HandleHeartbeat", data) then return end
    -- AckTracker handles the comparison and potential auto-sync trigger
    if Loothing.AckTracker then
        Loothing.AckTracker:HandleHeartbeat(data, sender)
    end
    self:TriggerEvent("OnHeartbeat", data, sender)
end

--- Handle ACK message — reserved for point-to-point acknowledgment tracking
-- @param data table - { command, msgID, success }
-- @param sender string
function CommMixin:HandleAck(data, sender, _distribution)
    if not validateHandler("HandleAck", data) then return end
    -- Forward to AckTracker if available
    if Loothing.AckTracker and Loothing.AckTracker.HandleAck then
        Loothing.AckTracker:HandleAck(data, sender)
    end
    self:TriggerEvent("OnAck", data, sender)
end

--[[--------------------------------------------------------------------
    Settings/History Sync Handlers (delegated to Sync module)
----------------------------------------------------------------------]]

function CommMixin:HandleSettingsSyncRequest(_data, sender)
    if not isGroupMember(sender) then
        Loothing:Debug("Rejected SETTINGS_SYNC_REQUEST from non-group member:", sender)
        return
    end
    if Loothing.Sync then
        Loothing.Sync:HandleSettingsSyncRequest(sender)
    end
end

function CommMixin:HandleSettingsSyncAck(_data, sender)
    if not isGroupMember(sender) then
        Loothing:Debug("Rejected SETTINGS_SYNC_ACK from non-group member:", sender)
        return
    end
    if Loothing.Sync then
        Loothing.Sync:HandleSettingsSyncAck(sender)
    end
end

function CommMixin:HandleSettingsData(data, sender)
    if not isGroupMember(sender) then
        Loothing:Debug("Rejected SETTINGS_DATA from non-group member:", sender)
        return
    end
    if Loothing.Sync and data then
        Loothing.Sync:HandleSettingsData(data.data, sender)
    end
end

function CommMixin:HandleHistorySyncRequest(data, sender)
    if not isGroupMember(sender) then
        Loothing:Debug("Rejected HISTORY_SYNC_REQUEST from non-group member:", sender)
        return
    end
    if Loothing.Sync then
        local days = (data and data.days) or 7
        Loothing.Sync:HandleHistorySyncRequest(sender, days)
    end
end

function CommMixin:HandleHistorySyncAck(_data, sender)
    if not isGroupMember(sender) then
        Loothing:Debug("Rejected HISTORY_SYNC_ACK from non-group member:", sender)
        return
    end
    if Loothing.Sync then
        Loothing.Sync:HandleHistorySyncAck(sender)
    end
end

function CommMixin:HandleHistoryData(data, sender)
    if not isGroupMember(sender) then
        Loothing:Debug("Rejected HISTORY_DATA from non-group member:", sender)
        return
    end
    if Loothing.Sync and data then
        Loothing.Sync:HandleHistoryData(data.data, sender)
    end
end

function CommMixin:HandleProfileExportShare(data, sender, distribution)
    if not validateHandler("HandleProfileExportShare", data, SCHEMAS.PROFILE_EXPORT_SHARE) then return end

    local scope = data.scope
    if scope == "group" then
        if not data.shareID or data.shareID == "" then
            Loothing:Debug("Rejected PROFILE_EXPORT_SHARE group broadcast with missing shareID:", sender)
            return
        end
        if distribution ~= "RAID" and distribution ~= "PARTY" then
            Loothing:Debug("Rejected PROFILE_EXPORT_SHARE group broadcast on unexpected channel:", distribution)
            return
        end
        if not Loothing.Session or not Loothing.Session:IsActive() then
            Loothing:Debug("Rejected PROFILE_EXPORT_SHARE group broadcast with no active session:", sender)
            return
        end
        if not data.sessionID or not Loothing.Session:IsCurrentSession(data.sessionID) then
            Loothing:Debug("Rejected PROFILE_EXPORT_SHARE with mismatched session:", sender)
            return
        end
        if not isGroupMember(sender) then
            Loothing:Debug("Rejected PROFILE_EXPORT_SHARE group broadcast from non-group member:", sender)
            return
        end
        local sessionMasterLooter = Loothing.Session:GetMasterLooter()
        if not sessionMasterLooter or not Utils.IsSamePlayer(sessionMasterLooter, sender) then
            Loothing:Debug("Rejected PROFILE_EXPORT_SHARE group broadcast from non-ML:", sender)
            return
        end
    elseif not isGroupMember(sender) then
        Loothing:Debug("Rejected PROFILE_EXPORT_SHARE from non-group member:", sender)
        return
    end

    if Loothing.SettingsExport then
        Loothing.SettingsExport:HandleSharedExport(data.exportString, sender, {
            shareID = data.shareID,
            scope = scope,
            sessionID = data.sessionID,
        })
    end
end
