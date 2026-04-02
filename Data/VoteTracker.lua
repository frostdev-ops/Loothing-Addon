--[[--------------------------------------------------------------------
    Loothing - Loot Council Addon for WoW 12.0+
    VoteTracker - Council member vote state engine

    Single source of truth for the local player's submitted votes across
    combat, frame close, and reconnects. Mirrors the pattern of
    ResponseTracker but for council VOTE_COMMIT messages:

    - Stores submitted vote data per item so VOTE_POLL can trigger a
      re-send without the VotePanel being open.
    - On combat end, re-shows VotePanel for any items the player has
      not yet voted on (VotePanel state is ephemeral/in-frame only).
    - On session end, clears all state.

    Note: VOTE_COMMIT already uses SendGuaranteed() so in-flight votes
    survive combat via the guaranteed queue. VoteTracker adds the layer
    above that: persistent state so we can re-send *after* the queue
    has been drained when the ML explicitly polls for missing votes.
----------------------------------------------------------------------]]

local _, ns = ...
local Loolib = LibStub("Loolib")
local Loothing = ns.Addon
local Utils = ns.Utils
local CreateFromMixins = Loolib.CreateFromMixins
local GetTime = GetTime

ns.VoteTrackerMixin = ns.VoteTrackerMixin or {}

--[[--------------------------------------------------------------------
    VoteTrackerMixin
----------------------------------------------------------------------]]

local VoteTrackerMixin = CreateFromMixins(Loolib.CallbackRegistryMixin, ns.VoteTrackerMixin)
ns.VoteTrackerMixin = VoteTrackerMixin

--- Initialize the vote tracker
function VoteTrackerMixin:Init()
    Loolib.CallbackRegistryMixin.OnLoad(self)

    -- Per-item submitted votes, keyed by item GUID.
    -- { [guid] = { responses, sentAt, sessionID } }
    self.submittedVotes = {}

    -- Session scoping
    self.sessionID = nil

    -- Combat-end reshow timer
    self.reshowTimer = nil

    self:RegisterSessionEvents()
    self:RegisterCommEvents()
    self:RegisterCombatEvents()
end

--[[--------------------------------------------------------------------
    Session Lifecycle
----------------------------------------------------------------------]]

function VoteTrackerMixin:RegisterSessionEvents()
    if not Loothing.Session then return end

    Loothing.Session:RegisterCallback("OnSessionStarted", function(_, sessionID)
        if sessionID ~= self.sessionID then
            self:Clear()
            self.sessionID = sessionID
        end
    end, self)

    Loothing.Session:RegisterCallback("OnSessionEnded", function()
        self:Clear()
    end, self)
end

function VoteTrackerMixin:RegisterCommEvents()
    if not Loothing.Comm then return end

    -- Clear per-item state when the item's voting round closes
    local function clearOnClose(_, data)
        if data and data.itemGUID then
            self:ClearVote(data.itemGUID)
        end
    end

    Loothing.Comm:RegisterCallback("OnVoteResults", clearOnClose, self)
    Loothing.Comm:RegisterCallback("OnVoteAward",   clearOnClose, self)
    Loothing.Comm:RegisterCallback("OnVoteCancel",  clearOnClose, self)
    Loothing.Comm:RegisterCallback("OnVoteSkip",    clearOnClose, self)

    -- ML polls for missing council votes after tally
    Loothing.Comm:RegisterCallback("OnVotePoll", function(_, data)
        self:HandleVotePoll(data)
    end, self)
end

--[[--------------------------------------------------------------------
    Vote State
----------------------------------------------------------------------]]

--- Record that the local player successfully submitted a vote.
-- Call this immediately after Comm:SendVoteCommit() fires.
-- @param guid string - Item GUID
-- @param responses table - Array of response IDs
function VoteTrackerMixin:MarkSubmitted(guid, responses)
    self.submittedVotes[guid] = {
        responses = responses,
        sentAt    = GetTime(),
        sessionID = self.sessionID,
    }
    Loothing:Debug("VoteTracker: recorded submitted vote for", guid)
end

--- Clear vote state for a single item (its voting round closed)
-- @param guid string
function VoteTrackerMixin:ClearVote(guid)
    if self.submittedVotes[guid] then
        self.submittedVotes[guid] = nil
        Loothing:Debug("VoteTracker: cleared vote for", guid)
    end
end

--- Return submitted vote data for an item, or nil
-- @param guid string
-- @return table|nil - { responses, sentAt, sessionID }
function VoteTrackerMixin:GetSubmittedVote(guid)
    return self.submittedVotes[guid]
end

--- Check whether the local player has submitted a vote for an item
-- @param guid string
-- @return boolean
function VoteTrackerMixin:HasSubmitted(guid)
    return self.submittedVotes[guid] ~= nil
end

--[[--------------------------------------------------------------------
    VOTE_POLL — Re-send if ML reports us missing
----------------------------------------------------------------------]]

--- Handle an incoming VOTE_POLL from the ML.
-- If the local player is in the missing list:
--   - If we have stored vote data: re-send VOTE_COMMIT silently.
--   - If we never voted: re-show VotePanel so the player can vote.
-- @param data table - { itemGUID, missingVoters, sessionID }
function VoteTrackerMixin:HandleVotePoll(data)
    if not data or not data.itemGUID or not data.missingVoters then return end

    -- Only council members respond to VOTE_POLL
    if not Loothing.Council then return end
    local playerName = Utils.GetPlayerFullName()
    if not Loothing.Council:IsMember(playerName) then return end

    -- Check we are in the missing list
    local inMissing = false
    for _, name in ipairs(data.missingVoters) do
        if Utils.IsSamePlayer(name, playerName) then
            inMissing = true
            break
        end
    end
    if not inMissing then return end

    local voteData = self.submittedVotes[data.itemGUID]
    if voteData and voteData.responses then
        -- Re-send the stored vote to ML
        local ml = Loothing.Session and Loothing.Session:GetMasterLooter()
        if Loothing.Comm and ml then
            Loothing:Debug("VoteTracker: VOTE_POLL — resending vote for", data.itemGUID)
            Loothing.Comm:SendVoteCommit(
                data.itemGUID,
                voteData.responses,
                ml,
                data.sessionID or self.sessionID
            )
        end
    else
        -- Player never voted; prompt them
        local L = Loothing.Locale
        Loothing:Print(L and L["VOTE_POLL_WAITING"] or
            "The Master Looter is waiting for your council vote!")
        self:ReshowVotePanelForItem(data.itemGUID)
    end
end

--[[--------------------------------------------------------------------
    Combat-End Recovery — Re-show VotePanel for unvoted items
----------------------------------------------------------------------]]

function VoteTrackerMixin:RegisterCombatEvents()
    local Events = Loolib.Events
    if not Events or not Events.Registry then return end
    Events.Registry:RegisterEventCallback("PLAYER_REGEN_ENABLED", function()
        self:OnCombatEnd()
    end, self)
end

--- Called when the local player leaves combat.
-- Schedules a jittered re-show of VotePanel for any item still in
-- VOTING state that the player has not yet voted on.
function VoteTrackerMixin:OnCombatEnd()
    -- Only act if there's an active session
    if not Loothing.Session or not Loothing.Session:IsActive() then return end

    if self.reshowTimer then
        self.reshowTimer:Cancel()
        self.reshowTimer = nil
    end

    -- Jittered delay: let the queue replay arrive first,
    -- then check state once things have settled.
    local delay = 2 + math.random() * 3  -- 2–5 seconds
    self.reshowTimer = C_Timer.NewTimer(delay, function()
        self.reshowTimer = nil
        self:CheckAndReshowVotePanel()
    end)
end

--- Re-show VotePanel for the first unvoted active voting item, if any.
function VoteTrackerMixin:CheckAndReshowVotePanel()
    if InCombatLockdown() then return end
    if not Loothing.Session or not Loothing.Session:IsActive() then return end
    if not Loothing.Council then return end

    local playerName = Utils.GetPlayerFullName()
    if not Loothing.Council:IsMember(playerName) then return end

    local session = Loothing.Session
    if not session.items then return end

    for _, item in session.items:Enumerate() do
        if item:CanAcceptVotes() and not self:HasSubmitted(item.guid) then
            self:ReshowVotePanelForItem(item.guid)
            return  -- show one at a time; player can navigate from there
        end
    end
end

--- Open VotePanel for a specific item if it is still in voting state.
-- @param guid string
function VoteTrackerMixin:ReshowVotePanelForItem(guid)
    if InCombatLockdown() then return end

    local votePanel = Loothing.VotePanel
    if not votePanel then return end
    if votePanel:IsShown() then return end  -- already open, don't interrupt

    local session = Loothing.Session
    if not session then return end

    local item = session:GetItemByGUID(guid)
    if not item or not item:CanAcceptVotes() then return end

    votePanel:SetItem(item)
    Loothing:Debug("VoteTracker: re-showed VotePanel for", guid)
end

--[[--------------------------------------------------------------------
    Cleanup
----------------------------------------------------------------------]]

--- Clear all state (session ended or new session started)
function VoteTrackerMixin:Clear()
    self.sessionID = nil
    wipe(self.submittedVotes)

    if self.reshowTimer then
        self.reshowTimer:Cancel()
        self.reshowTimer = nil
    end

    Loothing:Debug("VoteTracker: cleared all state")
end

--[[--------------------------------------------------------------------
    Factory
----------------------------------------------------------------------]]

function ns.CreateVoteTracker()
    local tracker = CreateFromMixins(VoteTrackerMixin)
    tracker:Init()
    return tracker
end

-- ns.VoteTrackerMixin and ns.CreateVoteTracker exported above
