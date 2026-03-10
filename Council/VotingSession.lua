--[[--------------------------------------------------------------------
    Loothing - Loot Council Addon for WoW 12.0+
    VotingSession - Active voting state machine for a single item
----------------------------------------------------------------------]]

local _, ns = ...
local Loothing = ns.Addon
local Loolib = LibStub("Loolib")
local CreateFromMixins = Loolib.CreateFromMixins
local GetTime = GetTime
ns.VotingSessionMixin = CreateFromMixins(Loolib.CallbackRegistryMixin, ns.VotingSessionMixin or {})

--[[--------------------------------------------------------------------
    Voting State Constants
----------------------------------------------------------------------]]

Loothing.VotingState = Loothing.VotingState or {
    PENDING = 1,     -- Item queued, not yet voting
    VOTING = 2,      -- Actively collecting votes
    TALLYING = 3,    -- Vote collection ended, computing results
    DECIDED = 4,     -- Winner determined
    REVOTING = 5,    -- Re-vote requested (tie or override)
}

--[[--------------------------------------------------------------------
    VotingSessionMixin
----------------------------------------------------------------------]]

local VotingSessionMixin = ns.VotingSessionMixin

local VOTING_SESSION_EVENTS = {
    "OnStateChanged",
    "OnVoteReceived",
    "OnTimerTick",
    "OnTimerExpired",
    "OnResultsReady",
    "OnWinnerDeclared",
    "OnRevoteStarted",
}

--- Initialize voting session
-- @param item table - LoothingItem
function VotingSessionMixin:Init(item)
    Loolib.CallbackRegistryMixin.OnLoad(self)
    self:GenerateCallbackEvents(VOTING_SESSION_EVENTS)

    self.item = item
    self.state = Loothing.VotingState.PENDING

    -- Voting configuration
    self.timeout = Loothing.Timing.DEFAULT_VOTE_TIMEOUT
    self.votingMode = Loothing.VotingMode.SIMPLE
    self.allowRevote = true
    self.maxRevotes = 2
    self.revoteCount = 0

    -- Timing
    self.startTime = nil
    self.endTime = nil
    self.timer = nil
    self.tickTimer = nil

    -- Results
    self.results = nil
    self.winner = nil
    self.winnerResponse = nil

    -- Council members who should vote
    self.expectedVoters = {}
end

--[[--------------------------------------------------------------------
    State Machine
----------------------------------------------------------------------]]

--- Get current state
-- @return number - Loothing.VotingState value
function VotingSessionMixin:GetState()
    return self.state
end

--- Get state name for display
-- @return string
function VotingSessionMixin:GetStateName()
    local L = Loothing.Locale

    if self.state == Loothing.VotingState.PENDING then
        return L["VOTING_STATE_PENDING"]
    elseif self.state == Loothing.VotingState.VOTING then
        return L["VOTING_STATE_VOTING"]
    elseif self.state == Loothing.VotingState.TALLYING then
        return L["VOTING_STATE_TALLYING"]
    elseif self.state == Loothing.VotingState.DECIDED then
        return L["VOTING_STATE_DECIDED"]
    elseif self.state == Loothing.VotingState.REVOTING then
        return L["VOTING_STATE_REVOTING"]
    end

    return ""
end

--- Set state (internal)
-- @param newState number
function VotingSessionMixin:SetState(newState)
    if self.state == newState then
        return
    end

    local oldState = self.state
    self.state = newState

    Loothing:Debug("Voting session state:", oldState, "->", newState)
    self:TriggerEvent("OnStateChanged", newState, oldState)
end

--[[--------------------------------------------------------------------
    Voting Control
----------------------------------------------------------------------]]

--- Start voting
-- @param timeout number - Seconds for voting (optional)
-- @return boolean - True if started successfully
function VotingSessionMixin:Start(timeout)
    if self.state ~= Loothing.VotingState.PENDING and
       self.state ~= Loothing.VotingState.REVOTING then
        Loothing:Debug("Cannot start voting from state:", self.state)
        return false
    end

    -- Get expected voters from council
    if Loothing.Council then
        self.expectedVoters = Loothing.Council:GetVotingEligibleMembers()
    end

    -- Set timeout
    self.timeout = timeout or Loothing.Settings:GetVotingTimeout() or Loothing.Timing.DEFAULT_VOTE_TIMEOUT
    self.startTime = GetTime()
    if self.timeout == Loothing.Timing.NO_TIMEOUT then
        self.endTime = math.huge
    else
        self.endTime = self.startTime + self.timeout
    end

    -- Start the item's voting state
    if self.item and self.item.StartVoting then
        self.item:StartVoting(self.timeout)
    end

    -- Start timer (skipped when no-timeout)
    if self.timeout ~= Loothing.Timing.NO_TIMEOUT then
        self:StartTimer()
    end

    self:SetState(Loothing.VotingState.VOTING)
    return true
end

--- Stop voting (early end)
-- @param skipTally boolean - If true, don't compute results
function VotingSessionMixin:Stop(skipTally)
    if self.state ~= Loothing.VotingState.VOTING then
        return
    end

    self:StopTimer()
    self.endTime = GetTime()

    -- End item's voting state
    if self.item and self.item.EndVoting then
        self.item:EndVoting()
    end

    if skipTally then
        self:SetState(Loothing.VotingState.PENDING)
    else
        self:Tally()
    end
end

--- Start a re-vote
-- @param timeout number - Optional different timeout
-- @return boolean - True if re-vote started
function VotingSessionMixin:StartRevote(timeout)
    if not self.allowRevote then
        return false
    end

    if self.revoteCount >= self.maxRevotes then
        Loothing:Debug("Maximum re-votes reached")
        return false
    end

    self.revoteCount = self.revoteCount + 1

    -- Clear previous votes from item
    if self.item and self.item.votes then
        self.item.votes:Flush()
    end

    -- Reset results
    self.results = nil
    self.winner = nil
    self.winnerResponse = nil

    self:SetState(Loothing.VotingState.REVOTING)
    self:TriggerEvent("OnRevoteStarted", self.revoteCount)

    -- Start the new vote
    return self:Start(timeout)
end

--[[--------------------------------------------------------------------
    Timer Management
----------------------------------------------------------------------]]

--- Start the voting timer
function VotingSessionMixin:StartTimer()
    self:StopTimer()

    -- Main timeout timer
    self.timer = C_Timer.NewTimer(self.timeout, function()
        self:OnTimerExpired()
    end)

    -- Tick timer for UI updates (every second)
    self.tickTimer = C_Timer.NewTicker(1, function()
        self:OnTimerTick()
    end)
end

--- Stop the voting timer
function VotingSessionMixin:StopTimer()
    if self.timer then
        self.timer:Cancel()
        self.timer = nil
    end

    if self.tickTimer then
        self.tickTimer:Cancel()
        self.tickTimer = nil
    end
end

--- Handle timer tick
function VotingSessionMixin:OnTimerTick()
    if self.state ~= Loothing.VotingState.VOTING then
        return
    end

    local remaining = self:GetTimeRemaining()
    self:TriggerEvent("OnTimerTick", remaining)

    -- Check if all expected votes are in
    if self:HasAllVotes() then
        Loothing:Debug("All expected votes received, ending early")
        self:Stop()
    end
end

--- Handle timer expiration
function VotingSessionMixin:OnTimerExpired()
    if self.state ~= Loothing.VotingState.VOTING then
        return
    end

    self:StopTimer()
    self.endTime = GetTime()

    self:TriggerEvent("OnTimerExpired")

    -- End item's voting
    if self.item and self.item.EndVoting then
        self.item:EndVoting()
    end

    self:Tally()
end

--- Get time remaining
-- @return number - Seconds remaining, or math.huge if no-timeout mode
function VotingSessionMixin:GetTimeRemaining()
    if self.state ~= Loothing.VotingState.VOTING or not self.endTime then
        return 0
    end

    if self.endTime == math.huge then
        return math.huge
    end

    return math.max(0, self.endTime - GetTime())
end

--- Get progress percentage
-- @return number - 0-100 (returns 0 in no-timeout mode)
function VotingSessionMixin:GetProgress()
    if self.state ~= Loothing.VotingState.VOTING or not self.startTime then
        return 0
    end

    if self.timeout == Loothing.Timing.NO_TIMEOUT then
        return 0
    end

    local elapsed = GetTime() - self.startTime
    return math.min(100, (elapsed / self.timeout) * 100)
end

--[[--------------------------------------------------------------------
    Vote Handling
----------------------------------------------------------------------]]

--- Record a vote
-- @param voter string - Voter name
-- @param voterClass string - Voter class file
-- @param responses table - Array of response values
-- @return boolean - True if vote recorded
function VotingSessionMixin:RecordVote(voter, voterClass, responses)
    if self.state ~= Loothing.VotingState.VOTING then
        Loothing:Debug("Cannot record vote in state:", self.state)
        return false
    end

    -- Add vote to item
    local success = false
    if self.item and self.item.AddVote then
        success = self.item:AddVote(voter, voterClass, responses)
    end

    if success then
        self:TriggerEvent("OnVoteReceived", voter, responses)
    end

    return success
end

--- Check if a voter has voted
-- @param voter string - Voter name
-- @return boolean
function VotingSessionMixin:HasVoted(voter)
    if self.item and self.item.HasVoted then
        return self.item:HasVoted(voter)
    end
    return false
end

--- Check if all expected voters have voted
-- @return boolean
function VotingSessionMixin:HasAllVotes()
    if #self.expectedVoters == 0 then
        return false
    end

    for _, voter in ipairs(self.expectedVoters) do
        if not self:HasVoted(voter) then
            return false
        end
    end

    return true
end

--- Get vote count
-- @return number
function VotingSessionMixin:GetVoteCount()
    if self.item and self.item.GetVoteCount then
        return self.item:GetVoteCount()
    end
    return 0
end

--- Get expected vote count
-- @return number
function VotingSessionMixin:GetExpectedVoteCount()
    return #self.expectedVoters
end

--- Get voters who haven't voted
-- @return table - Array of voter names
function VotingSessionMixin:GetMissingVoters()
    local missing = {}

    for _, voter in ipairs(self.expectedVoters) do
        if not self:HasVoted(voter) then
            missing[#missing + 1] = voter
        end
    end

    return missing
end

--[[--------------------------------------------------------------------
    Tallying
----------------------------------------------------------------------]]

--- Tally votes and determine results
function VotingSessionMixin:Tally()
    if self.state == Loothing.VotingState.TALLYING then
        return -- Already tallying
    end

    self:SetState(Loothing.VotingState.TALLYING)

    -- Get votes from item
    local votes = self.item and self.item:GetVotes()
    if not votes then
        self.results = {
            error = "No votes available",
            totalVotes = 0,
        }
        self:TriggerEvent("OnResultsReady", self.results)
        return
    end

    -- Tally based on voting mode
    if self.votingMode == Loothing.VotingMode.RANKED_CHOICE then
        -- Get candidates (all players who received votes)
        local candidates = self:GetCandidatesFromVotes(votes)
        local tieBreakerMode = Loothing.Settings and Loothing.Settings:GetTieBreakerMode() or "ROLL"
        self.results = ns.VotingEngine:TallyRankedChoice(votes, candidates, { tieBreakerMode = tieBreakerMode })

        -- If tiebreaker requests a revote, auto-trigger it
        if self.results and self.results.needsRevote then
            self:StartRevote()
            return
        end
    else
        self.results = ns.VotingEngine:TallySimple(votes)
    end

    self:TriggerEvent("OnResultsReady", self.results)
end

--- Get candidates from votes — Delegates to VotingEngine
-- @param votes table - DataProvider or array of votes
-- @return table - Array of unique candidate names across all ranked positions
function VotingSessionMixin:GetCandidatesFromVotes(votes)
    return ns.VotingEngine:GetCandidatesFromVotes(votes)
end

--- Get results
-- @return table|nil
function VotingSessionMixin:GetResults()
    return self.results
end

--[[--------------------------------------------------------------------
    Winner Declaration
----------------------------------------------------------------------]]

--- Declare a winner
-- @param winner string|number - Winner name or response type
-- @param response number - Response type (optional if winner is a response)
function VotingSessionMixin:DeclareWinner(winner, response)
    self.winner = winner
    self.winnerResponse = response or winner

    -- Update item
    if self.item and self.item.SetWinner then
        self.item:SetWinner(winner, response)
    end

    self:SetState(Loothing.VotingState.DECIDED)
    self:TriggerEvent("OnWinnerDeclared", winner, response)
end

--- Get the declared winner
-- @return any, number - Winner, response type
function VotingSessionMixin:GetWinner()
    return self.winner, self.winnerResponse
end

--- Check if there's a tie
-- @return boolean
function VotingSessionMixin:IsTied()
    if not self.results then
        return false
    end

    return self.results.isTie == true
end

--[[--------------------------------------------------------------------
    Configuration
----------------------------------------------------------------------]]

--- Set voting mode
-- @param mode string - Loothing.VotingMode value
function VotingSessionMixin:SetVotingMode(mode)
    self.votingMode = mode
end

--- Get voting mode
-- @return string
function VotingSessionMixin:GetVotingMode()
    return self.votingMode
end

--- Set timeout
-- @param timeout number - Seconds
function VotingSessionMixin:SetTimeout(timeout)
    self.timeout = timeout
end

--- Set whether re-votes are allowed
-- @param allowed boolean
function VotingSessionMixin:SetAllowRevote(allowed)
    self.allowRevote = allowed
end

--[[--------------------------------------------------------------------
    Display Helpers
----------------------------------------------------------------------]]

--- Get a summary for display
-- @return table
function VotingSessionMixin:GetSummary()
    local L = Loothing.Locale

    return {
        state = self.state,
        stateName = self:GetStateName(),
        item = self.item,
        voteCount = self:GetVoteCount(),
        expectedVoteCount = self:GetExpectedVoteCount(),
        timeRemaining = self:GetTimeRemaining(),
        progress = self:GetProgress(),
        results = self.results,
        winner = self.winner,
        winnerResponse = self.winnerResponse,
        revoteCount = self.revoteCount,
        canRevote = self.allowRevote and self.revoteCount < self.maxRevotes,
    }
end

--- Get vote response summary
-- @return table - Array of { response, responseInfo, count, percentage }
function VotingSessionMixin:GetResponseSummary()
    if not self.item then
        return {}
    end

    local votes = self.item:GetVotes()
    if not votes then
        return {}
    end

    return ns.VotingEngine:GetResponseSummary(votes)
end

--[[--------------------------------------------------------------------
    Cleanup
----------------------------------------------------------------------]]

--- Destroy the voting session
function VotingSessionMixin:Destroy()
    self:StopTimer()
    self.item = nil
    self.results = nil
    self.expectedVoters = {}
end

--[[--------------------------------------------------------------------
    Factory
----------------------------------------------------------------------]]

--- Create a new voting session
-- @param item table - LoothingItem
-- @return table - LoothingVotingSession
function ns.CreateVotingSession(item)
    local session = CreateFromMixins(VotingSessionMixin)
    session:Init(item)
    return session
end

-- ns.VotingSessionMixin and ns.CreateVotingSession exported above
