--[[--------------------------------------------------------------------
    Loothing - Loot Council Addon for WoW 12.0+
    ItemData - Loot item representation and management
----------------------------------------------------------------------]]

local Loolib = LibStub("Loolib")

--[[--------------------------------------------------------------------
    LoothingItemMixin
----------------------------------------------------------------------]]

LoothingItemMixin = LoolibCreateFromMixins(LoolibCallbackRegistryMixin)

local ITEM_EVENTS = {
    "OnStateChanged",
    "OnVoteAdded",
    "OnVoteRemoved",
    "OnWinnerSet",
}

--- Initialize the item
function LoothingItemMixin:Init(itemLink, looter, encounterID)
    LoolibCallbackRegistryMixin.OnLoad(self)
    self:GenerateCallbackEvents(ITEM_EVENTS)

    -- Core properties
    self.guid = LoothingUtils.GenerateGUID()
    self.itemLink = itemLink
    self.looter = LoothingUtils.NormalizeName(looter)
    self.encounterID = encounterID
    self.timestamp = time()

    -- Parse item info
    local itemInfo = LoothingUtils.GetItemInfo(itemLink)
    if itemInfo then
        self.itemID = itemInfo.itemID
        self.name = itemInfo.name
        self.quality = itemInfo.quality
        self.itemLevel = itemInfo.itemLevel
        self.texture = itemInfo.texture
        self.equipSlot = itemInfo.equipSlot
    else
        self.itemID = LoothingUtils.GetItemID(itemLink)
        self.name = LoothingUtils.GetItemName(itemLink) or "Unknown"
        self.quality = LoothingUtils.GetItemQuality(itemLink)
    end

    -- State
    self.state = LOOTHING_ITEM_STATE.PENDING
    self.voteStartTime = nil
    self.voteEndTime = nil
    self.voteTimeout = nil

    -- Votes (DataProvider)
    local Data = Loolib:GetModule("Data")
    self.votes = Data.CreateDataProvider()

    -- Result
    self.winner = nil
    self.winnerResponse = nil
    self.awardedTime = nil
end

--[[--------------------------------------------------------------------
    State Management
----------------------------------------------------------------------]]

--- Get the current state
-- @return number - LOOTHING_ITEM_STATE value
function LoothingItemMixin:GetState()
    return self.state
end

--- Set the state
-- @param state number - LOOTHING_ITEM_STATE value
function LoothingItemMixin:SetState(state)
    if self.state ~= state then
        local oldState = self.state
        self.state = state
        self:TriggerEvent("OnStateChanged", state, oldState)
    end
end

--- Check if item is pending
-- @return boolean
function LoothingItemMixin:IsPending()
    return self.state == LOOTHING_ITEM_STATE.PENDING
end

--- Check if item is being voted on
-- @return boolean
function LoothingItemMixin:IsVoting()
    return self.state == LOOTHING_ITEM_STATE.VOTING
end

--- Check if item has been tallied
-- @return boolean
function LoothingItemMixin:IsTallied()
    return self.state == LOOTHING_ITEM_STATE.TALLIED
end

--- Check if item has been awarded
-- @return boolean
function LoothingItemMixin:IsAwarded()
    return self.state == LOOTHING_ITEM_STATE.AWARDED
end

--- Check if item was skipped
-- @return boolean
function LoothingItemMixin:IsSkipped()
    return self.state == LOOTHING_ITEM_STATE.SKIPPED
end

--- Check if item is complete (awarded or skipped)
-- @return boolean
function LoothingItemMixin:IsComplete()
    return self.state == LOOTHING_ITEM_STATE.AWARDED or
           self.state == LOOTHING_ITEM_STATE.SKIPPED
end

--[[--------------------------------------------------------------------
    Voting
----------------------------------------------------------------------]]

--- Start voting for this item
-- @param timeout number - Seconds until voting closes
function LoothingItemMixin:StartVoting(timeout)
    if self.state ~= LOOTHING_ITEM_STATE.PENDING then
        return false
    end

    self.voteStartTime = GetTime()
    self.voteTimeout = timeout or Loothing.Settings:GetVotingTimeout()
    self.voteEndTime = self.voteStartTime + self.voteTimeout

    self:SetState(LOOTHING_ITEM_STATE.VOTING)
    return true
end

--- End voting for this item
function LoothingItemMixin:EndVoting()
    if self.state ~= LOOTHING_ITEM_STATE.VOTING then
        return false
    end

    self.voteEndTime = GetTime()
    self:SetState(LOOTHING_ITEM_STATE.TALLIED)
    return true
end

--- Get time remaining for voting
-- @return number - Seconds remaining, or 0 if not voting
function LoothingItemMixin:GetTimeRemaining()
    if self.state ~= LOOTHING_ITEM_STATE.VOTING then
        return 0
    end

    local remaining = self.voteEndTime - GetTime()
    return math.max(0, remaining)
end

--- Check if voting has timed out
-- @return boolean
function LoothingItemMixin:IsVotingTimedOut()
    return self.state == LOOTHING_ITEM_STATE.VOTING and
           GetTime() >= self.voteEndTime
end

--[[--------------------------------------------------------------------
    Vote Management
----------------------------------------------------------------------]]

--- Add a vote for this item
-- @param voter string - Voter name
-- @param voterClass string - Voter class
-- @param responses table - Array of response values (ranked)
-- @return boolean - True if vote was added
function LoothingItemMixin:AddVote(voter, voterClass, responses)
    if self.state ~= LOOTHING_ITEM_STATE.VOTING then
        return false
    end

    voter = LoothingUtils.NormalizeName(voter)

    -- Check for existing vote
    local existing = self:GetVoteByVoter(voter)
    if existing then
        -- Update existing vote
        existing.responses = responses
        existing.timestamp = time()
        self:TriggerEvent("OnVoteAdded", existing, true)
        return true
    end

    -- Create new vote
    local vote = {
        voter = voter,
        voterClass = voterClass,
        responses = responses,
        timestamp = time(),
    }

    self.votes:Insert(vote)
    self:TriggerEvent("OnVoteAdded", vote, false)
    return true
end

--- Remove a vote
-- @param voter string - Voter name
-- @return boolean - True if vote was removed
function LoothingItemMixin:RemoveVote(voter)
    voter = LoothingUtils.NormalizeName(voter)

    local vote = self:GetVoteByVoter(voter)
    if vote then
        self.votes:Remove(vote)
        self:TriggerEvent("OnVoteRemoved", vote)
        return true
    end

    return false
end

--- Get a vote by voter name
-- @param voter string
-- @return table|nil
function LoothingItemMixin:GetVoteByVoter(voter)
    voter = LoothingUtils.NormalizeName(voter)

    for _, vote in self.votes:Enumerate() do
        if vote.voter == voter then
            return vote
        end
    end

    return nil
end

--- Check if a voter has voted
-- @param voter string
-- @return boolean
function LoothingItemMixin:HasVoted(voter)
    return self:GetVoteByVoter(voter) ~= nil
end

--- Get all votes
-- @return DataProvider
function LoothingItemMixin:GetVotes()
    return self.votes
end

--- Get vote count
-- @return number
function LoothingItemMixin:GetVoteCount()
    return self.votes:GetSize()
end

--- Get votes by response type
-- @param responseType number - LOOTHING_RESPONSE value
-- @return table - Array of votes with that first-choice response
function LoothingItemMixin:GetVotesByResponse(responseType)
    local result = {}

    for _, vote in self.votes:Enumerate() do
        if vote.responses and vote.responses[1] == responseType then
            result[#result + 1] = vote
        end
    end

    return result
end

--[[--------------------------------------------------------------------
    Award/Skip
----------------------------------------------------------------------]]

--- Set the winner for this item
-- @param winner string - Winner name
-- @param response number - Winning response type (optional)
function LoothingItemMixin:SetWinner(winner, response)
    self.winner = LoothingUtils.NormalizeName(winner)
    self.winnerResponse = response
    self.awardedTime = time()

    self:SetState(LOOTHING_ITEM_STATE.AWARDED)
    self:TriggerEvent("OnWinnerSet", self.winner, response)
end

--- Skip this item (no award)
function LoothingItemMixin:Skip()
    self.awardedTime = time()
    self:SetState(LOOTHING_ITEM_STATE.SKIPPED)
end

--- Get the winner
-- @return string|nil
function LoothingItemMixin:GetWinner()
    return self.winner
end

--[[--------------------------------------------------------------------
    Serialization
----------------------------------------------------------------------]]

--- Serialize item for storage/transmission
-- @return table
function LoothingItemMixin:Serialize()
    local serializedVotes = {}
    for _, vote in self.votes:Enumerate() do
        serializedVotes[#serializedVotes + 1] = {
            voter = vote.voter,
            voterClass = vote.voterClass,
            responses = vote.responses,
            timestamp = vote.timestamp,
        }
    end

    return {
        guid = self.guid,
        itemLink = self.itemLink,
        itemID = self.itemID,
        name = self.name,
        quality = self.quality,
        itemLevel = self.itemLevel,
        looter = self.looter,
        encounterID = self.encounterID,
        timestamp = self.timestamp,
        state = self.state,
        votes = serializedVotes,
        winner = self.winner,
        winnerResponse = self.winnerResponse,
        awardedTime = self.awardedTime,
    }
end

--- Deserialize item from storage
-- @param data table
function LoothingItemMixin:Deserialize(data)
    self.guid = data.guid
    self.itemLink = data.itemLink
    self.itemID = data.itemID
    self.name = data.name
    self.quality = data.quality
    self.itemLevel = data.itemLevel
    self.looter = data.looter
    self.encounterID = data.encounterID
    self.timestamp = data.timestamp
    self.state = data.state
    self.winner = data.winner
    self.winnerResponse = data.winnerResponse
    self.awardedTime = data.awardedTime

    -- Restore votes
    self.votes:Flush()
    if data.votes then
        for _, voteData in ipairs(data.votes) do
            self.votes:Insert(voteData)
        end
    end
end

--[[--------------------------------------------------------------------
    Display Helpers
----------------------------------------------------------------------]]

--- Get quality color
-- @return table - { r, g, b }
function LoothingItemMixin:GetQualityColor()
    local quality = self.quality or 0
    local r, g, b = C_Item.GetItemQualityColor(quality)
    return { r = r, g = g, b = b }
end

--- Get status text
-- @return string
function LoothingItemMixin:GetStatusText()
    local L = LOOTHING_LOCALE

    if self.state == LOOTHING_ITEM_STATE.PENDING then
        return L["STATUS_PENDING"]
    elseif self.state == LOOTHING_ITEM_STATE.VOTING then
        return L["STATUS_VOTING"]
    elseif self.state == LOOTHING_ITEM_STATE.TALLIED then
        return L["STATUS_TALLIED"]
    elseif self.state == LOOTHING_ITEM_STATE.AWARDED then
        return L["STATUS_AWARDED"]
    elseif self.state == LOOTHING_ITEM_STATE.SKIPPED then
        return L["STATUS_SKIPPED"]
    end

    return ""
end

--[[--------------------------------------------------------------------
    Factory
----------------------------------------------------------------------]]

--- Create a new loot item
-- @param itemLink string
-- @param looter string
-- @param encounterID number
-- @return table - LoothingItem instance
function CreateLoothingItem(itemLink, looter, encounterID)
    local item = LoolibCreateFromMixins(LoothingItemMixin)
    item:Init(itemLink, looter, encounterID)
    return item
end
