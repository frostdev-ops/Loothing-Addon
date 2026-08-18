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
local IsInGuild = IsInGuild
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
-- Checks Session ML first, then Settings ML, then the global Loothing.masterLooter.
-- @param sender string
-- @return boolean
local function isMasterLooter(sender)
    if not sender then return false end
    local ml = Loothing:GetCanonicalML()
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

local function isVotingEligible(sender)
    if not sender or not Loothing.Council then return false end
    if Loothing.Council.GetVotingEligibleMembers then
        local members = Loothing.Council:GetVotingEligibleMembers()
        for _, member in ipairs(members or {}) do
            if Utils.IsSamePlayer(member, sender) then
                return true
            end
        end
        return false
    end
    return isCouncilMember(sender)
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
    return Utils.IsGroupMember(sender)
end

--[[--------------------------------------------------------------------
    Per-Handler Schema Definitions
    Derived from the broadcast helpers in MessageHandler.lua.
    Schema entries: { fieldName, expectedType, required }
----------------------------------------------------------------------]]

local SCHEMAS = {
    ITEM_ADD = {
        { "itemLink",  "string", true },
        { "guid",      "string", true },
        { "sessionID", "string", true },
        { "looter",    "string", false },
    },
    VOTE_AWARD = {
        { "itemGUID",  "string", true },
        { "winner",    "string", true },
        { "sessionID", "string", false },
    },
    PLAYER_RESPONSE = {
        { "itemGUID",  "string", true },
        { "response",  nil,      true },
        { "sessionID", "string", false },
        { "roll",      nil,      false },
        { "rollMin",   nil,      false },
        { "rollMax",   nil,      false },
    },
    VOTE_COMMIT = {
        { "itemGUID",  "string", true },
        { "responses", "table",  true },
        { "sessionID", "string", false },
    },
    RESPONSE_BATCH  = { { "responses", "table",  true } },
    BATCH           = { { "messages",  "table",  true } },
    MLDB_BROADCAST  = { { "data",      "table",  true } },
    COUNCIL_ROSTER  = { { "members",   "table",  true } },
    OBSERVER_ROSTER = {
        { "list",            "table",   true },
        { "permissions",     "table",   false },
        { "openObservation", "boolean", false },
        { "mlIsObserver",    "boolean", false },
    },
    SYNC_SETTINGS_REQUEST = {},
    SYNC_SETTINGS_CONFIRM = {},
    SYNC_SETTINGS_DATA = {
        { "data", "table", true },
    },
    SYNC_HISTORY_REQUEST = {
        { "days", nil, false },
    },
    SYNC_HISTORY_CONFIRM = {},
    SYNC_HISTORY_DATA = {
        { "data", "table", true },
    },
    PROFILE_EXPORT_SHARE = {
        { "exportString", "string", true },
        { "shareID", "string", false },
        { "scope", "string", false },
        { "sessionID", "string", false },
    },
    INTEL_SHARE_MANIFEST = {
        { "transferID", "string", true },
        { "sender",     "string", true },
        { "version",    "string", false },
        { "datasets",   "table",  true },
    },
    INTEL_SHARE = {
        { "transferID", "string", true },
        { "type",       "string", true },
        { "data",       "table",  true },
    },
    CANDIDATE_UPDATE = {
        { "itemGUID",      "string", true },
        { "candidateData", "table",  true },
        { "sessionID",     "string", false },
    },
    VOTE_UPDATE = {
        { "itemGUID",      "string", true },
        { "candidateName", "string", true },
        { "voters",        "table",  true },
        { "sessionID",     "string", false },
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
    -- SESSION_START is the authoritative ML declaration. Same authorization
    -- ladder as SESSION_INIT (minus the MLDB-payload requirement — bare
    -- SESSION_START never carries one):
    --   1. Known ML (Session or Settings). Covers explicit ML (/lt ml) who may
    --      not be leader — every current send path broadcasts MLDB before or
    --      alongside SESSION_START, so receivers already resolved the ML.
    --   2. Strict group leader when our cached ML is stale (handover).
    --   3. Leader/assistant bootstrap when we don't know an ML yet.
    -- Anything else is rejected: HandleRemoteSessionStart force-ends the
    -- active session on sessionID mismatch and adopts the sender as global
    -- ML, so an unauthenticated SESSION_START would let any group member
    -- terminate another player's session and pass isMasterLooter() for
    -- subsequent ITEM_ADD / VOTE_AWARD / COUNCIL_ROSTER forgeries — the
    -- exact takeover HandleSessionInit guards against.
    if not isMasterLooter(sender) then
        local mlKnown = Loothing.masterLooter and Loothing.masterLooter ~= ""
        local senderIsStrictLeader = Utils.IsPlayerGroupLeader
            and Utils.IsPlayerGroupLeader(sender)
        local leaderHandover = mlKnown
            and senderIsStrictLeader
            and not Utils.IsSamePlayer(Loothing.masterLooter, sender)
        local bootstrap = not mlKnown and isGroupLeaderOrAssistant(sender)

        if not leaderHandover and not bootstrap then
            Loothing:Debug("Rejected SESSION_START from non-ML/non-leader:", sender)
            return
        end
    end

    -- Accept and propagate the sender as authoritative ML
    data.masterLooter = sender
    self:TriggerEvent("OnSessionStart", data)
end

function CommMixin:HandleStopHandleLoot(_data, sender)
    -- Accept from current ML or from the previous ML who just transferred the role.
    -- When ML is transferred via MLDB, the old ML's STOP_HANDLE_LOOT arrives after
    -- the MLDB that already changed the ML identity, so the old ML must be accepted.
    if not isMasterLooter(sender)
        and not (Loothing.MLDB and Loothing.MLDB:WasPreviousMLSender(sender)) then
        Loothing:Debug("Rejected STOP_HANDLE_LOOT from non-ML:", sender)
        return
    end
    self:TriggerEvent("OnStopHandleLoot", { masterLooter = sender })
end

function CommMixin:HandleSessionEnd(data, sender)
    if not validateHandler("HandleSessionEnd", data) then return end
    -- Accept from:
    --   1. Current ML (normal path)
    --   2. Previous ML who just transferred — MLDB transfer race
    --   3. Current group leader (defense-in-depth for handover where the
    --      receiver's cached ML is stale and the new leader is ending the
    --      orphaned session — Reject path of LOOTHING_ML_HANDOVER_PROMPT)
    local senderIsML = isMasterLooter(sender)
    local senderIsPrevML = Loothing.MLDB and Loothing.MLDB:WasPreviousMLSender(sender)
    local senderIsLeader = Utils.IsPlayerGroupLeader and Utils.IsPlayerGroupLeader(sender)

    if not senderIsML and not senderIsPrevML and not senderIsLeader then
        Loothing:Debug("Rejected SESSION_END from non-ML:", sender)
        return
    end
    self:TriggerEvent("OnSessionEnd", {
        masterLooter = sender,
        sessionID = data.sessionID,
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

function CommMixin:HandleVoteCommit(data, sender, distribution)
    if not validateHandler("HandleVoteCommit", data, SCHEMAS.VOTE_COMMIT) then return end
    -- Only voting-eligible council members can vote. This excludes the ML
    -- when ML Observer Mode is enabled, matching the displayed voter count.
    if not isVotingEligible(sender) then
        Loothing:Debug("Rejected VOTE_COMMIT from non-eligible council:", sender)
        return
    end
    data.voter = sender
    -- Tag legacy whisper sources so the ML can re-broadcast a VOTE_UPDATE
    -- delta for 2.0.41+ council members who never saw the original (the old
    -- v2.0.40 sender targeted only ML). Underscore-prefixed key is local-only.
    data._legacyWhisper = (distribution == "WHISPER")
    -- Broadcast votes: every receiver tallies locally — ML + council members
    -- maintain the same voter state without an ML re-broadcast step.
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
    -- If we already have a known ML from local detection, validate sender
    -- matches. Use IsSamePlayer: Loothing.masterLooter may be stored in a
    -- roster-API casing that differs from the post-NormalizeName sender.
    -- Loothing:Debug is a print wrapper, not a format function, so pass
    -- args positionally rather than via a "%s" format string.
    if Loothing.masterLooter and Loothing.masterLooter ~= ""
        and not Utils.IsSamePlayer(sender, Loothing.masterLooter) then
        Loothing:Debug("Rejected SYNC_DATA from", sender, "- local ML is", Loothing.masterLooter)
        return
    end
    data.masterLooter = sender
    self:TriggerEvent("OnSyncData", data)
end

function CommMixin:HandleIncrementalSyncRequest(data, sender)
    if not validateHandler("HandleIncrementalSyncRequest", data) then return end
    if not isGroupMember(sender) then
        Loothing:Debug("Rejected SYNC_INCREMENTAL from non-group:", sender)
        return
    end
    data.requester = sender
    self:TriggerEvent("OnIncrementalSyncRequest", data)
end

function CommMixin:HandleIncrementalSyncData(data, sender)
    if not validateHandler("HandleIncrementalSyncData", data) then return end
    if not isMasterLooter(sender) and not isGroupLeaderOrAssistant(sender) then
        Loothing:Debug("Rejected SYNC_INCREMENTAL_DATA from non-ML:", sender)
        return
    end
    data.masterLooter = sender
    self:TriggerEvent("OnIncrementalSyncData", data)
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
    if not validateHandler("HandleObserverRoster", data, SCHEMAS.OBSERVER_ROSTER) then return end
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

function CommMixin:HandlePlayerInfoResponse(data, sender, distribution)
    if not validateHandler("HandlePlayerInfoResponse", data) then return end
    if not isGroupMember(sender) then
        Loothing:Debug("Rejected PLAYER_INFO_RESPONSE from non-group member:", sender)
        return
    end
    -- Normalize nil-like values
    if data.slot1Link == "" then data.slot1Link = nil end
    if data.slot2Link == "" then data.slot2Link = nil end
    data.playerName = sender
    -- Tag legacy whisper sources so ML can re-broadcast a CANDIDATE_UPDATE
    -- with the gear info for 2.0.41+ council members who didn't see the
    -- original (v2.0.40 senders whisper directly to ML).
    data._legacyWhisper = (distribution == "WHISPER")
    self:TriggerEvent("OnPlayerInfoResponse", data)
end

--[[--------------------------------------------------------------------
    Version Handlers
----------------------------------------------------------------------]]

function CommMixin:HandleVersionRequest(_data, sender, distribution)
    if distribution == "GUILD" then
        if not IsInGuild() then
            return
        end
    elseif not isGroupMember(sender) then
        Loothing:Debug("Rejected VERSION_REQUEST from non-group member:", sender)
        return
    end

    self:TriggerEvent("OnVersionRequest", {
        requester = sender,
        distribution = distribution,
    })
end

function CommMixin:HandleVersionResponse(data, sender, distribution)
    if not validateHandler("HandleVersionResponse", data) then return end
    -- Restrict version responses to group/guild distribution. Without this
    -- gate any prefix-aware peer could whisper a forged response and
    -- pollute the version display + PlayerCache.
    if distribution ~= "GUILD" and not isGroupMember(sender) then
        Loothing:Debug("Rejected VERSION_RESPONSE from non-group/guild peer:", sender)
        return
    end
    data.sender = sender
    self:TriggerEvent("OnVersionResponse", data)
end

--[[--------------------------------------------------------------------
    Player Response Handlers
----------------------------------------------------------------------]]

function CommMixin:HandlePlayerResponse(data, sender, distribution)
    if not validateHandler("HandlePlayerResponse", data, SCHEMAS.PLAYER_RESPONSE) then return end
    if not Loothing.Session then return end

    -- Validate sender is in the group (bypass in test mode)
    local isTestMode = TestMode and TestMode:IsEnabled()
    if not isGroupMember(sender) and not isTestMode then
        Loothing:Debug("Rejected PLAYER_RESPONSE from non-group member:", sender)
        return
    end

    data.playerName = sender
    -- Tag legacy whisper sources so ML can re-broadcast a CANDIDATE_UPDATE
    -- on behalf of a v2.0.40 sender whose response only reached ML directly.
    data._legacyWhisper = (distribution == "WHISPER")
    -- Broadcast: every client computes candidate state locally.
    self:TriggerEvent("OnPlayerResponse", data)
end

function CommMixin:HandleResponsePoll(data, sender)
    if not validateHandler("HandleResponsePoll", data) then return end
    if not isMasterLooter(sender) then
        Loothing:Debug("Rejected RESPONSE_POLL from non-ML:", sender)
        return
    end
    self:TriggerEvent("OnResponsePoll", data)
end

function CommMixin:HandleVotePoll(data, sender)
    if not validateHandler("HandleVotePoll", data) then return end
    if not isMasterLooter(sender) then
        Loothing:Debug("Rejected VOTE_POLL from non-ML:", sender)
        return
    end
    data.masterLooter = sender
    self:TriggerEvent("OnVotePoll", data)
end

--[[--------------------------------------------------------------------
    MLDB Handler
----------------------------------------------------------------------]]

function CommMixin:HandleMLDBBroadcast(data, sender)
    if not validateHandler("HandleMLDBBroadcast", data, SCHEMAS.MLDB_BROADCAST) then return end
    -- Accept from: known ML, leader/assistant (bootstraps ML), or group member
    -- when ML is unknown. The last case covers explicit ML setups where the
    -- chosen ML is not raid lead/assistant and MLDB is the first identity signal.
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
    if not validateHandler("HandleCandidateUpdate", data, SCHEMAS.CANDIDATE_UPDATE) then return end
    -- Authorize first so forged messages from non-ML peers don't trip the
    -- inner-payload debug log path.
    if not isMasterLooter(sender) then
        Loothing:Debug("Rejected CANDIDATE_UPDATE from non-ML:", sender)
        return
    end
    if type(data.candidateData.name) ~= "string" then
        Loothing:Debug("Rejected CANDIDATE_UPDATE — candidateData.name missing")
        return
    end
    data.masterLooter = sender
    self:TriggerEvent("OnCandidateUpdate", data)
end

function CommMixin:HandleVoteUpdate(data, sender)
    if not validateHandler("HandleVoteUpdate", data, SCHEMAS.VOTE_UPDATE) then return end
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

--- Handle HEARTBEAT message — delegate to Heartbeat for state comparison
-- @param data table - Heartbeat digest { sessionID, state, itemCount, itemStates, councilHash, mldbHash }
-- @param sender string
function CommMixin:HandleHeartbeat(data, sender, _distribution)
    if not validateHandler("HandleHeartbeat", data) then return end
    -- Self-filter at the dispatch layer: RAID broadcasts loop back to the
    -- sender, and subscribers to OnHeartbeat should never see a heartbeat
    -- purportedly describing remote state when that state is actually the
    -- local player. Heartbeat.lua already guards its own handler, but this
    -- ensures any OnHeartbeat subscriber gets a filtered stream by default.
    local localName = Utils.GetPlayerFullName()
    if localName and Utils.IsSamePlayer(sender, localName) then
        return
    end
    -- Heartbeat handles the comparison and potential auto-sync trigger
    if Loothing.Heartbeat then
        Loothing.Heartbeat:HandleHeartbeat(data, sender)
    end
    self:TriggerEvent("OnHeartbeat", data, sender)
end

--[[--------------------------------------------------------------------
    Settings/History Sync Handlers (delegated to Sync module)
----------------------------------------------------------------------]]

function CommMixin:HandleSettingsSyncRequest(data, sender)
    if not validateHandler("HandleSettingsSyncRequest", data, SCHEMAS.SYNC_SETTINGS_REQUEST) then return end
    if not isGroupMember(sender) then
        Loothing:Debug("Rejected SETTINGS_SYNC_REQUEST from non-group member:", sender)
        return
    end
    if Loothing.Sync then
        Loothing.Sync:HandleSettingsSyncRequest(sender)
    end
end

function CommMixin:HandleSettingsSyncConfirm(data, sender)
    if not validateHandler("HandleSettingsSyncConfirm", data, SCHEMAS.SYNC_SETTINGS_CONFIRM) then return end
    if not isGroupMember(sender) then
        Loothing:Debug("Rejected SETTINGS_SYNC_CONFIRM from non-group member:", sender)
        return
    end
    if Loothing.Sync then
        Loothing.Sync:HandleSettingsSyncConfirm(sender)
    end
end

function CommMixin:HandleSettingsData(data, sender)
    if not validateHandler("HandleSettingsData", data, SCHEMAS.SYNC_SETTINGS_DATA) then return end
    if not isGroupMember(sender) then
        Loothing:Debug("Rejected SETTINGS_DATA from non-group member:", sender)
        return
    end
    if Loothing.Sync then
        Loothing.Sync:HandleSettingsData(data.data, sender)
    end
end

function CommMixin:HandleHistorySyncRequest(data, sender)
    if not validateHandler("HandleHistorySyncRequest", data, SCHEMAS.SYNC_HISTORY_REQUEST) then return end
    if not isGroupMember(sender) then
        Loothing:Debug("Rejected HISTORY_SYNC_REQUEST from non-group member:", sender)
        return
    end
    if Loothing.Sync then
        local days = (data and data.days) or 7
        Loothing.Sync:HandleHistorySyncRequest(sender, days)
    end
end

function CommMixin:HandleHistorySyncConfirm(data, sender)
    if not validateHandler("HandleHistorySyncConfirm", data, SCHEMAS.SYNC_HISTORY_CONFIRM) then return end
    if not isGroupMember(sender) then
        Loothing:Debug("Rejected HISTORY_SYNC_CONFIRM from non-group member:", sender)
        return
    end
    if Loothing.Sync then
        Loothing.Sync:HandleHistorySyncConfirm(sender)
    end
end

function CommMixin:HandleHistoryData(data, sender)
    if not validateHandler("HandleHistoryData", data, SCHEMAS.SYNC_HISTORY_DATA) then return end
    if not isGroupMember(sender) then
        Loothing:Debug("Rejected HISTORY_DATA from non-group member:", sender)
        return
    end
    if Loothing.Sync then
        Loothing.Sync:HandleHistoryData(data.data, sender)
    end
end

--[[--------------------------------------------------------------------
    Combined Session Setup Handler
----------------------------------------------------------------------]]

--- Handle SESSION_INIT — combined session initialization message.
-- Unpacks and routes sub-messages through the standalone handlers so each
-- sub-payload gets its own schema + sender-authorization check instead of
-- being re-emitted unvalidated. Idempotent: receiving both SESSION_INIT
-- and the individual messages is harmless.
function CommMixin:HandleSessionInit(data, sender, _distribution)
    if not validateHandler("HandleSessionInit", data) then return end

    -- Authorization:
    --   * Current ML: accept (normal path).
    --   * Raid leader/assistant WHEN the receiver does not yet know the ML:
    --     accept as bootstrap and provisionally adopt the sender as ML so the
    --     sub-payload handlers (strict ML-only) authorize. The MLDB sub-
    --     payload refines this to the MLDB's settings.masterLooter.
    --   * Strict GROUP LEADER (rank 2) WHEN our cached ML is stale (handover):
    --     accept and force-update our cached ML to the leader. The MLDB
    --     sub-payload (required) then refines settings.masterLooter. Without
    --     this branch, an observer with explicitMasterLooter still pinned at
    --     the previous ML would reject the new ML's first SESSION_INIT and
    --     stay stranded on stale state.
    --   * Otherwise reject. A non-ML group member must not be able to
    --     broadcast SESSION_INIT — the force-end-on-sessionID-mismatch branch
    --     below would let them terminate another player's active session.
    if not isMasterLooter(sender) then
        local mlKnown = Loothing.masterLooter and Loothing.masterLooter ~= ""
        local senderIsStrictLeader = Utils.IsPlayerGroupLeader
            and Utils.IsPlayerGroupLeader(sender)

        -- Strict-leader handover override. Only fires when the cached ML is
        -- stale (mlKnown but != sender) and the sender is unambiguously the
        -- group leader (NOT an assistant).
        local leaderHandover = mlKnown
            and senderIsStrictLeader
            and not Utils.IsSamePlayer(Loothing.masterLooter, sender)

        if leaderHandover then
            -- Both bootstrap and leader-handover require a valid MLDB payload
            -- so HandleMLDBBroadcast can refine settings.masterLooter — see
            -- the bootstrap-path security note below.
            if type(data.mldb) ~= "table" or type(data.mldb.data) ~= "table" then
                Loothing:Debug("Rejected SESSION_INIT leader-handover (MLDB missing):", sender)
                return
            end
            Loothing:Debug("SESSION_INIT handover: leader", sender,
                "outranks stale ML", Loothing.masterLooter, "- accepting")
            Loothing.masterLooter = sender
            -- Drop the stale explicit pin so subsequent ML resolution agrees
            -- with the leader; symmetric to OnMLDBBroadcast's stale-pin clear.
            if Loothing.explicitMasterLooter
                and not Utils.IsSamePlayer(Loothing.explicitMasterLooter, sender) then
                Loothing.explicitMasterLooter = nil
            end
        elseif mlKnown or not isGroupLeaderOrAssistant(sender) then
            Loothing:Debug("Rejected SESSION_INIT from non-ML/non-leader:", sender)
            return
        else
            -- Bootstrap REQUIRES an MLDB sub-payload with a populated data table.
            -- Without it, HandleMLDBBroadcast would never fire OnMLDBBroadcast, the
            -- subscriber would never resolve settings.masterLooter, and a
            -- provisionally-adopted leader/assistant would stay impersonating ML
            -- until the next legitimate MLDB arrived — long enough to forge
            -- COUNCIL_ROSTER / ITEM_ADD / VOTE_* as the supposed ML.
            if type(data.mldb) ~= "table" or type(data.mldb.data) ~= "table" then
                Loothing:Debug("Rejected SESSION_INIT bootstrap (MLDB payload missing or malformed):",
                    sender)
                return
            end
            -- Bootstrap path: ML unknown + sender is leader/assistant + valid MLDB
            -- present. Provisionally promote sender so HandleCouncilRoster /
            -- HandleItemAdd authorize. MLDB routing below will overwrite with the
            -- MLDB's authoritative settings.masterLooter.
            Loothing:Debug("SESSION_INIT bootstrap: provisionally adopting",
                sender, "as ML (pending MLDB resolution)")
            Loothing.masterLooter = sender
        end
    end

    -- If we are still ACTIVE on a different session (e.g. the previous
    -- SESSION_END was missed or arrived during restrictions), force-end the
    -- stale session BEFORE the new MLDB is applied. Otherwise the
    -- downstream HandleRemoteSessionStart below would call EndSession
    -- AFTER OnMLDBBroadcast has applied the new settings, and EndSession's
    -- MLDB:Clear → RestoreSettings would clobber the freshly applied MLDB
    -- back to the previous session's baseline — leaving session 2 running
    -- with stale votingMode, responseSets, autoPass, etc. That is the
    -- "autopass broken / character names as buttons" class of bug.
    if data.sessionStart and Loothing.Session and Loothing.Session.IsActive
        and Loothing.Session:IsActive() then
        local newSessionID = data.sessionStart.sessionID
        local currentID = Loothing.Session.sessionID
        if newSessionID and newSessionID ~= currentID then
            Loothing:Debug("SESSION_INIT: force-ending stale session",
                tostring(currentID), "for new session", tostring(newSessionID))
            Loothing.Session:EndSession()
        end
    end

    -- Route each sub-payload through the standalone handler so the per-handler
    -- schema and authorization checks run. Order matters: MLDB first so
    -- clients have authoritative settings (and ML identity, via the bootstrap
    -- path in HandleMLDBBroadcast) before SessionStart flips state to ACTIVE —
    -- otherwise GetEffectiveGroupLootMode() sees no MLDB yet and AutoPass /
    -- other MLDB-dependent checks fail on the first tick.
    if data.mldb then
        self:HandleMLDBBroadcast(data.mldb, sender)
    end

    if data.councilRoster then
        self:HandleCouncilRoster(data.councilRoster, sender)
    end

    -- Observer roster (optional; added to SESSION_INIT payload for the
    -- roster-onboard refresh path so a single SESSION_INIT replaces the
    -- legacy SESSION_START + MLDB + COUNCIL_ROSTER + OBSERVER_ROSTER fan-out).
    if data.observerRoster then
        self:HandleObserverRoster(data.observerRoster, sender)
    end

    if data.sessionStart then
        self:HandleSessionStart(data.sessionStart, sender)
    end

    if data.items and type(data.items) == "table" then
        for _, itemData in ipairs(data.items) do
            self:HandleItemAdd(itemData, sender)
        end
    end
end

--[[--------------------------------------------------------------------
    Batched Response Handler
----------------------------------------------------------------------]]

function CommMixin:HandleResponseBatch(data, sender, distribution)
    if not validateHandler("HandleResponseBatch", data, SCHEMAS.RESPONSE_BATCH) then return end
    if not Loothing.Session then return end

    -- Validate sender is in the group
    local isTestMode = TestMode and TestMode:IsEnabled()
    if not isGroupMember(sender) and not isTestMode then
        Loothing:Debug("Rejected RESPONSE_BATCH from non-group member:", sender)
        return
    end

    -- Tag legacy whisper sources so per-item OnPlayerResponse fan-out can
    -- propagate a CANDIDATE_UPDATE on ML behalf for v2.0.40 senders.
    local isLegacyWhisper = (distribution == "WHISPER")

    -- Anti-DoS: cap inner batch size. The outer BATCH envelope enforces
    -- MAX_BATCH_SIZE (20) but nothing stopped a peer from sending a single
    -- RESPONSE_BATCH containing thousands of items. 100 covers the
    -- legitimate worst case (one response per raider per session on a
    -- 40-person raid, with a safety margin).
    local MAX_RESPONSES_PER_BATCH = 100
    if #data.responses > MAX_RESPONSES_PER_BATCH then
        Loothing:Debug("Rejected RESPONSE_BATCH with", #data.responses,
            "items (cap " .. MAX_RESPONSES_PER_BATCH .. ") from", sender)
        self:TriggerEvent("OnMessageDropped",
            Loothing.MsgType.RESPONSE_BATCH,
            "oversized_batch", sender)
        return
    end

    -- Unpack batch: per-item schema validation mirrors the direct
    -- HandlePlayerResponse path. A malformed item is dropped individually
    -- so a single bad entry does not poison the rest of the batch. Drops
    -- fire OnMessageDropped so subscribers can rate-limit, alert, or ban a
    -- peer that sends repeated garbage.
    for _, item in ipairs(data.responses) do
        if type(item) == "table" then
            local ok, reason = Utils.ValidateSchema(item, SCHEMAS.PLAYER_RESPONSE)
            if ok then
                item.playerName = sender
                item.sessionID = item.sessionID or data.sessionID
                item._legacyWhisper = isLegacyWhisper
                self:TriggerEvent("OnPlayerResponse", item)
            else
                Loothing:Debug("Rejected RESPONSE_BATCH item — schema:", reason)
                self:TriggerEvent("OnMessageDropped",
                    Loothing.MsgType.RESPONSE_BATCH,
                    "schema_malformed_item", sender)
            end
        else
            Loothing:Debug("Rejected RESPONSE_BATCH item — not a table")
            self:TriggerEvent("OnMessageDropped",
                Loothing.MsgType.RESPONSE_BATCH,
                "schema_malformed_item", sender)
        end
    end
end

--[[--------------------------------------------------------------------
    Settings/History Sync Handlers (delegated to Sync module)
----------------------------------------------------------------------]]

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

--[[--------------------------------------------------------------------
    Desktop Intel Share Handlers
----------------------------------------------------------------------]]

-- Intel share has a consent popup downstream, but datasets buffer in memory
-- before acceptance and a declined sender can re-send to re-pop the dialog.
-- Require a relationship: group member, or guild channel (Blizzard only
-- delivers GUILD addon messages from guildmates). Blocks stranger WHISPERs.
local function isIntelShareSenderAllowed(sender, distribution)
    return distribution == "GUILD" or isGroupMember(sender)
end

function CommMixin:HandleIntelShareManifest(data, sender, distribution)
    if not validateHandler("HandleIntelShareManifest", data, SCHEMAS.INTEL_SHARE_MANIFEST) then return end
    if not isIntelShareSenderAllowed(sender, distribution) then
        Loothing:Debug("Rejected INTEL_SHARE_MANIFEST from non-group/non-guild sender:", sender)
        return
    end
    if Loothing.IntelShare then
        Loothing.IntelShare:HandleManifest(data, sender, distribution)
    end
end

function CommMixin:HandleIntelShareData(data, sender, distribution)
    if not validateHandler("HandleIntelShareData", data, SCHEMAS.INTEL_SHARE) then return end
    if not isIntelShareSenderAllowed(sender, distribution) then
        Loothing:Debug("Rejected INTEL_SHARE from non-group/non-guild sender:", sender)
        return
    end
    if Loothing.IntelShare then
        Loothing.IntelShare:HandleDataset(data, sender, distribution)
    end
end
