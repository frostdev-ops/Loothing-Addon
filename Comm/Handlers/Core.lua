--[[--------------------------------------------------------------------
    Loothing - Comm Handlers (Core/Voting/Sync)
    Message handlers for LoothingCommMixin.

    All handlers receive structured table data (from Serializer),
    not string arrays. Security validation is applied per-handler.
----------------------------------------------------------------------]]

LoothingCommMixin = LoothingCommMixin or {}

--[[--------------------------------------------------------------------
    Security Helpers
----------------------------------------------------------------------]]

--- Check if sender is the current master looter
-- @param sender string
-- @return boolean
local function isMasterLooter(sender)
    if not Loothing.Session then return false end
    local ml = Loothing.Session:GetMasterLooter()
    if not ml then return false end
    return LoothingUtils.IsSamePlayer(ml, sender)
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
    if LoothingTestMode and LoothingTestMode:IsEnabled() then
        return true
    end
    local normalizedSender = LoothingUtils.NormalizeName(sender)
    if IsInRaid() then
        local numMembers = GetNumGroupMembers()
        for i = 1, numMembers do
            local name, rank = GetRaidRosterInfo(i)
            if name and LoothingUtils.IsSamePlayer(name, normalizedSender) then
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
            local name = UnitName(unit)
            if name and LoothingUtils.IsSamePlayer(name, normalizedSender) then
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
    if LoothingTestMode and LoothingTestMode:IsEnabled() then
        return true
    end
    -- If we can't check, fail closed (reject)
    if not LoothingUtils or not LoothingUtils.GetRaidRoster then return false end
    local roster = LoothingUtils.GetRaidRoster()
    for _, member in ipairs(roster) do
        if LoothingUtils.IsSamePlayer(member.name, sender) then
            return true
        end
    end
    return false
end

--[[--------------------------------------------------------------------
    Session Handlers (ML → Group)
----------------------------------------------------------------------]]

function LoothingCommMixin:HandleSessionStart(data, sender)
    if not data then return end
    -- Validate sender is at least a raid leader/assistant
    if not isGroupLeaderOrAssistant(sender) then
        Loothing:Debug("Rejected SESSION_START from non-leader/assistant:", sender)
        return
    end
    -- If we already have a known ML from local detection, validate sender matches
    if Loothing.masterLooter and Loothing.masterLooter ~= "" and sender ~= Loothing.masterLooter then
        Loothing:Debug("Rejected SESSION_START from %s - local ML is %s", sender, Loothing.masterLooter)
        return
    end
    data.masterLooter = sender
    self:TriggerEvent("OnSessionStart", data)
end

function LoothingCommMixin:HandleStopHandleLoot(data, sender)
    -- Only the current ML can broadcast stop
    if not isMasterLooter(sender) then
        Loothing:Debug("Rejected STOP_HANDLE_LOOT from non-ML:", sender)
        return
    end
    self:TriggerEvent("OnStopHandleLoot", { masterLooter = sender })
end

function LoothingCommMixin:HandleSessionEnd(data, sender)
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

function LoothingCommMixin:HandleItemAdd(data, sender)
    if not data then return end
    if not isMasterLooter(sender) then
        Loothing:Debug("Rejected ITEM_ADD from non-ML:", sender)
        return
    end
    data.masterLooter = sender
    self:TriggerEvent("OnItemAdd", data)
end

function LoothingCommMixin:HandleItemRemove(data, sender)
    if not data then return end
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

function LoothingCommMixin:HandleVoteRequest(data, sender)
    if not data then return end
    -- Only ML can request votes
    if not isMasterLooter(sender) then
        Loothing:Debug("Rejected VOTE_REQUEST from non-ML:", sender)
        return
    end
    data.masterLooter = sender
    self:TriggerEvent("OnVoteRequest", data)
end

function LoothingCommMixin:HandleVoteCommit(data, sender)
    if not data then return end
    -- Only council members can vote
    if not isCouncilMember(sender) then
        Loothing:Debug("Rejected VOTE_COMMIT from non-council:", sender)
        return
    end
    data.voter = sender
    self:TriggerEvent("OnVoteCommit", data)
end

function LoothingCommMixin:HandleVoteCancel(data, sender)
    if not data then return end
    if not isMasterLooter(sender) then
        Loothing:Debug("Rejected VOTE_CANCEL from non-ML:", sender)
        return
    end
    data.masterLooter = sender
    self:TriggerEvent("OnVoteCancel", data)
end

function LoothingCommMixin:HandleVoteResults(data, sender)
    if not data then return end
    if not isMasterLooter(sender) then
        Loothing:Debug("Rejected VOTE_RESULTS from non-ML:", sender)
        return
    end
    data.masterLooter = sender
    self:TriggerEvent("OnVoteResults", data)
end

function LoothingCommMixin:HandleVoteAward(data, sender)
    if not data then return end
    if not isMasterLooter(sender) then
        Loothing:Debug("Rejected VOTE_AWARD from non-ML:", sender)
        return
    end
    data.masterLooter = sender
    self:TriggerEvent("OnVoteAward", data)
end

function LoothingCommMixin:HandleVoteSkip(data, sender)
    if not data then return end
    if not isMasterLooter(sender) then
        Loothing:Debug("Rejected VOTE_SKIP from non-ML:", sender)
        return
    end
    data.masterLooter = sender
    self:TriggerEvent("OnVoteSkip", data)
end

--[[--------------------------------------------------------------------
    Sync Handlers
----------------------------------------------------------------------]]

function LoothingCommMixin:HandleSyncRequest(data, sender)
    if not data then return end
    if not isGroupMember(sender) then
        Loothing:Debug("Rejected SYNC_REQUEST from non-group member:", sender)
        return
    end
    data.requester = sender
    self:TriggerEvent("OnSyncRequest", data)
end

function LoothingCommMixin:HandleSyncData(data, sender)
    if not data then return end
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

function LoothingCommMixin:HandleCouncilRoster(data, sender)
    if not data then return end
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

function LoothingCommMixin:HandleObserverRoster(data, sender)
    if not data then return end
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

function LoothingCommMixin:HandlePlayerInfoRequest(data, sender)
    if not data then return end
    if not isMasterLooter(sender) then
        Loothing:Debug("Rejected PLAYER_INFO_REQUEST from non-ML:", sender)
        return
    end
    data.requester = sender
    self:TriggerEvent("OnPlayerInfoRequest", data)
end

function LoothingCommMixin:HandlePlayerInfoResponse(data, sender)
    if not data then return end
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

function LoothingCommMixin:HandleVersionRequest(data, sender)
    self:TriggerEvent("OnVersionRequest", {
        requester = sender,
    })
end

function LoothingCommMixin:HandleVersionResponse(data, sender)
    if not data then return end
    data.sender = sender
    self:TriggerEvent("OnVersionResponse", data)
end

--[[--------------------------------------------------------------------
    Player Response Handlers
----------------------------------------------------------------------]]

function LoothingCommMixin:HandlePlayerResponse(data, sender)
    if not data then return end

    -- Only ML processes player responses
    if not Loothing.Session or not Loothing.Session:IsMasterLooter() then
        return
    end

    -- Validate sender is in the group (bypass in test mode)
    local isTestMode = LoothingTestMode and LoothingTestMode:IsEnabled()
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

function LoothingCommMixin:HandlePlayerResponseAck(data, sender)
    if not data then return end
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

function LoothingCommMixin:HandleMLDBBroadcast(data, sender)
    if not data then return end
    if not isMasterLooter(sender) then
        Loothing:Debug("Rejected MLDB_BROADCAST from non-ML:", sender)
        return
    end
    data.sender = sender
    self:TriggerEvent("OnMLDBBroadcast", data)
end

--[[--------------------------------------------------------------------
    Candidate & Vote Update Handlers
----------------------------------------------------------------------]]

function LoothingCommMixin:HandleCandidateUpdate(data, sender)
    if not data then return end
    if not isMasterLooter(sender) then
        Loothing:Debug("Rejected CANDIDATE_UPDATE from non-ML:", sender)
        return
    end
    data.masterLooter = sender
    self:TriggerEvent("OnCandidateUpdate", data)
end

function LoothingCommMixin:HandleVoteUpdate(data, sender)
    if not data then return end
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

function LoothingCommMixin:HandleTradable(data, sender)
    if not data then return end
    -- Any group member can send tradability status for their own looted items
    if not isGroupMember(sender) then
        Loothing:Debug("Rejected TRADABLE from non-group member:", sender)
        return
    end
    data.playerName = sender
    self:TriggerEvent("OnTradable", data)
end

function LoothingCommMixin:HandleNonTradable(data, sender)
    if not data then return end
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
function LoothingCommMixin:HandleBatch(data, sender, distribution)
    if not data or type(data.messages) ~= "table" then return end

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
function LoothingCommMixin:HandleHeartbeat(data, sender, distribution)
    if not data then return end
    -- AckTracker handles the comparison and potential auto-sync trigger
    if Loothing.AckTracker then
        Loothing.AckTracker:HandleHeartbeat(data, sender)
    end
    self:TriggerEvent("OnHeartbeat", data, sender)
end

--- Handle ACK message — reserved for point-to-point acknowledgment tracking
-- @param data table - { command, msgID, success }
-- @param sender string
function LoothingCommMixin:HandleAck(data, sender, distribution)
    if not data then return end
    -- Forward to AckTracker if available
    if Loothing.AckTracker and Loothing.AckTracker.HandleAck then
        Loothing.AckTracker:HandleAck(data, sender)
    end
    self:TriggerEvent("OnAck", data, sender)
end

--[[--------------------------------------------------------------------
    Settings/History Sync Handlers (delegated to Sync module)
----------------------------------------------------------------------]]

function LoothingCommMixin:HandleSettingsSyncRequest(data, sender)
    if not isGroupMember(sender) then
        Loothing:Debug("Rejected SETTINGS_SYNC_REQUEST from non-group member:", sender)
        return
    end
    if Loothing.Sync then
        Loothing.Sync:HandleSettingsSyncRequest(sender)
    end
end

function LoothingCommMixin:HandleSettingsSyncAck(data, sender)
    if not isGroupMember(sender) then
        Loothing:Debug("Rejected SETTINGS_SYNC_ACK from non-group member:", sender)
        return
    end
    if Loothing.Sync then
        Loothing.Sync:HandleSettingsSyncAck(sender)
    end
end

function LoothingCommMixin:HandleSettingsData(data, sender)
    if not isGroupMember(sender) then
        Loothing:Debug("Rejected SETTINGS_DATA from non-group member:", sender)
        return
    end
    if Loothing.Sync and data then
        Loothing.Sync:HandleSettingsData(data.data, sender)
    end
end

function LoothingCommMixin:HandleHistorySyncRequest(data, sender)
    if not isGroupMember(sender) then
        Loothing:Debug("Rejected HISTORY_SYNC_REQUEST from non-group member:", sender)
        return
    end
    if Loothing.Sync then
        local days = (data and data.days) or 7
        Loothing.Sync:HandleHistorySyncRequest(sender, days)
    end
end

function LoothingCommMixin:HandleHistorySyncAck(data, sender)
    if not isGroupMember(sender) then
        Loothing:Debug("Rejected HISTORY_SYNC_ACK from non-group member:", sender)
        return
    end
    if Loothing.Sync then
        Loothing.Sync:HandleHistorySyncAck(sender)
    end
end

function LoothingCommMixin:HandleHistoryData(data, sender)
    if not isGroupMember(sender) then
        Loothing:Debug("Rejected HISTORY_DATA from non-group member:", sender)
        return
    end
    if Loothing.Sync and data then
        Loothing.Sync:HandleHistoryData(data.data, sender)
    end
end
