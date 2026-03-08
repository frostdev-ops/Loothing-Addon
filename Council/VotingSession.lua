--[[--------------------------------------------------------------------
    Loothing - Loot Council Addon for WoW 12.0+
    VotingSession - Active voting state machine for a single item
----------------------------------------------------------------------]]

local Loolib = LibStub("Loolib")

--[[--------------------------------------------------------------------
    Voting State Constants
----------------------------------------------------------------------]]

LOOTHING_VOTING_STATE = {
    PENDING = 1,     -- Item queued, not yet voting
    VOTING = 2,      -- Actively collecting votes
    TALLYING = 3,    -- Vote collection ended, computing results
    DECIDED = 4,     -- Winner determined
    REVOTING = 5,    -- Re-vote requested (tie or override)
}

--[[--------------------------------------------------------------------
    LoothingVotingSessionMixin
----------------------------------------------------------------------]]

LoothingVotingSessionMixin = LoolibCreateFromMixins(LoolibCallbackRegistryMixin)

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
function LoothingVotingSessionMixin:Init(item)
    LoolibCallbackRegistryMixin.OnLoad(self)
    self:GenerateCallbackEvents(VOTING_SESSION_EVENTS)

    self.item = item
    self.state = LOOTHING_VOTING_STATE.PENDING

    -- Voting configuration
    self.timeout = LOOTHING_TIMING.DEFAULT_VOTE_TIMEOUT
    self.votingMode = LOOTHING_VOTING_MODE.SIMPLE
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
-- @return number - LOOTHING_VOTING_STATE value
function LoothingVotingSessionMixin:GetState()
    return self.state
end

--- Get state name for display
-- @return string
function LoothingVotingSessionMixin:GetStateName()
    local L = LOOTHING_LOCALE

    if self.state == LOOTHING_VOTING_STATE.PENDING then
        return L["VOTING_STATE_PENDING"]
    elseif self.state == LOOTHING_VOTING_STATE.VOTING then
        return L["VOTING_STATE_VOTING"]
    elseif self.state == LOOTHING_VOTING_STATE.TALLYING then
        return L["VOTING_STATE_TALLYING"]
    elseif self.state == LOOTHING_VOTING_STATE.DECIDED then
        return L["VOTING_STATE_DECIDED"]
    elseif self.state == LOOTHING_VOTING_STATE.REVOTING then
        return L["VOTING_STATE_REVOTING"]
    end

    return ""
end

--- Set state (internal)
-- @param newState number
function LoothingVotingSessionMixin:SetState(newState)
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
function LoothingVotingSessionMixin:Start(timeout)
    if self.state ~= LOOTHING_VOTING_STATE.PENDING and
       self.state ~= LOOTHING_VOTING_STATE.REVOTING then
        Loothing:Debug("Cannot start voting from state:", self.state)
        return false
    end

    -- Get expected voters from council
    if Loothing.Council then
        self.expectedVoters = Loothing.Council:GetVotingEligibleMembers()
    end

    -- Set timeout
    self.timeout = timeout or Loothing.Settings:GetVotingTimeout() or LOOTHING_TIMING.DEFAULT_VOTE_TIMEOUT
    self.startTime = GetTime()
    if self.timeout == LOOTHING_TIMING.NO_TIMEOUT then
        self.endTime = math.huge
    else
        self.endTime = self.startTime + self.timeout
    end

    -- Start the item's voting state
    if self.item and self.item.StartVoting then
        self.item:StartVoting(self.timeout)
    end

    -- Start timer (skipped when no-timeout)
    if self.timeout ~= LOOTHING_TIMING.NO_TIMEOUT then
        self:StartTimer()
    end

    self:SetState(LOOTHING_VOTING_STATE.VOTING)
    return true
end

--- Stop voting (early end)
-- @param skipTally boolean - If true, don't compute results
function LoothingVotingSessionMixin:Stop(skipTally)
    if self.state ~= LOOTHING_VOTING_STATE.VOTING then
        return
    end

    self:StopTimer()
    self.endTime = GetTime()

    -- End item's voting state
    if self.item and self.item.EndVoting then
        self.item:EndVoting()
    end

    if skipTally then
        self:SetState(LOOTHING_VOTING_STATE.PENDING)
    else
        self:Tally()
    end
end

--- Start a re-vote
-- @param timeout number - Optional different timeout
-- @return boolean - True if re-vote started
function LoothingVotingSessionMixin:StartRevote(timeout)
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

    self:SetState(LOOTHING_VOTING_STATE.REVOTING)
    self:TriggerEvent("OnRevoteStarted", self.revoteCount)

    -- Start the new vote
    return self:Start(timeout)
end

--[[--------------------------------------------------------------------
    Timer Management
----------------------------------------------------------------------]]

--- Start the voting timer
function LoothingVotingSessionMixin:StartTimer()
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
function LoothingVotingSessionMixin:StopTimer()
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
function LoothingVotingSessionMixin:OnTimerTick()
    if self.state ~= LOOTHING_VOTING_STATE.VOTING then
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
function LoothingVotingSessionMixin:OnTimerExpired()
    if self.state ~= LOOTHING_VOTING_STATE.VOTING then
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
function LoothingVotingSessionMixin:GetTimeRemaining()
    if self.state ~= LOOTHING_VOTING_STATE.VOTING or not self.endTime then
        return 0
    end

    if self.endTime == math.huge then
        return math.huge
    end

    return math.max(0, self.endTime - GetTime())
end

--- Get progress percentage
-- @return number - 0-100 (returns 0 in no-timeout mode)
function LoothingVotingSessionMixin:GetProgress()
    if self.state ~= LOOTHING_VOTING_STATE.VOTING or not self.startTime then
        return 0
    end

    if self.timeout == LOOTHING_TIMING.NO_TIMEOUT then
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
function LoothingVotingSessionMixin:RecordVote(voter, voterClass, responses)
    if self.state ~= LOOTHING_VOTING_STATE.VOTING then
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
function LoothingVotingSessionMixin:HasVoted(voter)
    if self.item and self.item.HasVoted then
        return self.item:HasVoted(voter)
    end
    return false
end

--- Check if all expected voters have voted
-- @return boolean
function LoothingVotingSessionMixin:HasAllVotes()
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
function LoothingVotingSessionMixin:GetVoteCount()
    if self.item and self.item.GetVoteCount then
        return self.item:GetVoteCount()
    end
    return 0
end

--- Get expected vote count
-- @return number
function LoothingVotingSessionMixin:GetExpectedVoteCount()
    return #self.expectedVoters
end

--- Get voters who haven't voted
-- @return table - Array of voter names
function LoothingVotingSessionMixin:GetMissingVoters()
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
function LoothingVotingSessionMixin:Tally()
    if self.state == LOOTHING_VOTING_STATE.TALLYING then
        return -- Already tallying
    end

    self:SetState(LOOTHING_VOTING_STATE.TALLYING)

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
    if self.votingMode == LOOTHING_VOTING_MODE.RANKED_CHOICE then
        -- Get candidates (all players who received votes)
        local candidates = self:GetCandidatesFromVotes(votes)
        self.results = LoothingVotingEngine:TallyRankedChoice(votes, candidates)
    else
        self.results = LoothingVotingEngine:TallySimple(votes)
    end

    self:TriggerEvent("OnResultsReady", self.results)
end

--- Get candidates from votes (for ranked choice)
-- @param votes table - DataProvider
-- @return table - Array of unique first-choice responses
function LoothingVotingSessionMixin:GetCandidatesFromVotes(votes)
    local seen = {}
    local candidates = {}

    for _, vote in votes:Enumerate() do
        local firstChoice = vote.responses and vote.responses[1]
        if firstChoice and not seen[firstChoice] then
            seen[firstChoice] = true
            candidates[#candidates + 1] = tostring(firstChoice)
        end
    end

    return candidates
end

--- Get results
-- @return table|nil
function LoothingVotingSessionMixin:GetResults()
    return self.results
end

--[[--------------------------------------------------------------------
    Winner Declaration
----------------------------------------------------------------------]]

--- Declare a winner
-- @param winner string|number - Winner name or response type
-- @param response number - Response type (optional if winner is a response)
function LoothingVotingSessionMixin:DeclareWinner(winner, response)
    self.winner = winner
    self.winnerResponse = response or winner

    -- Update item
    if self.item and self.item.SetWinner then
        self.item:SetWinner(winner, response)
    end

    self:SetState(LOOTHING_VOTING_STATE.DECIDED)
    self:TriggerEvent("OnWinnerDeclared", winner, response)
end

--- Get the declared winner
-- @return any, number - Winner, response type
function LoothingVotingSessionMixin:GetWinner()
    return self.winner, self.winnerResponse
end

--- Check if there's a tie
-- @return boolean
function LoothingVotingSessionMixin:IsTied()
    if not self.results then
        return false
    end

    return self.results.isTie == true
end

--[[--------------------------------------------------------------------
    Configuration
----------------------------------------------------------------------]]

--- Set voting mode
-- @param mode string - LOOTHING_VOTING_MODE value
function LoothingVotingSessionMixin:SetVotingMode(mode)
    self.votingMode = mode
end

--- Get voting mode
-- @return string
function LoothingVotingSessionMixin:GetVotingMode()
    return self.votingMode
end

--- Set timeout
-- @param timeout number - Seconds
function LoothingVotingSessionMixin:SetTimeout(timeout)
    self.timeout = timeout
end

--- Set whether re-votes are allowed
-- @param allowed boolean
function LoothingVotingSessionMixin:SetAllowRevote(allowed)
    self.allowRevote = allowed
end

--[[--------------------------------------------------------------------
    Display Helpers
----------------------------------------------------------------------]]

--- Get a summary for display
-- @return table
function LoothingVotingSessionMixin:GetSummary()
    local L = LOOTHING_LOCALE

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
function LoothingVotingSessionMixin:GetResponseSummary()
    if not self.item then
        return {}
    end

    local votes = self.item:GetVotes()
    if not votes then
        return {}
    end

    return LoothingVotingEngine:GetResponseSummary(votes)
end

--[[--------------------------------------------------------------------
    Cleanup
----------------------------------------------------------------------]]

--- Destroy the voting session
function LoothingVotingSessionMixin:Destroy()
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
function CreateLoothingVotingSession(item)
    local session = LoolibCreateFromMixins(LoothingVotingSessionMixin)
    session:Init(item)
    return session
end
