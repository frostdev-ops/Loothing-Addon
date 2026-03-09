--[[--------------------------------------------------------------------
    Loothing - Loot Council Addon for WoW 12.0+
    VoteData - Vote storage, representation, and utilities
----------------------------------------------------------------------]]

local Loolib = LibStub("Loolib")

--[[--------------------------------------------------------------------
    LoothingVoteMixin - Individual vote representation
----------------------------------------------------------------------]]

LoothingVoteMixin = {}

--- Create a new vote
-- @param voter string - Voter name
-- @param voterClass string - Voter class file
-- @param responses table - Array of response values (ranked by preference)
function LoothingVoteMixin:Init(voter, voterClass, responses)
    self.voter = LoothingUtils.NormalizeName(voter)
    self.voterClass = voterClass
    self.responses = responses or {}
    self.timestamp = time()
    self.note = nil

    -- Gear comparison data
    self.gear1Link = nil        -- First equipped item link
    self.gear2Link = nil        -- Second equipped item link (for dual-wield slots)
    self.gear1ilvl = 0          -- Item level of first item
    self.gear2ilvl = 0          -- Item level of second item
    self.ilvlDiff = 0           -- Difference from candidate item

    -- Roll data
    self.roll = nil             -- Roll value (if player rolled)
    self.rollRange = nil        -- { min, max } range for roll
end

--- Get the first choice response
-- @return number - Loothing.Response value
function LoothingVoteMixin:GetFirstChoice()
    return self.responses[1]
end

--- Get all responses (for ranked choice)
-- @return table
function LoothingVoteMixin:GetResponses()
    return self.responses
end

--- Get response at a specific rank
-- @param rank number - 1-based rank
-- @return number|nil
function LoothingVoteMixin:GetResponseAtRank(rank)
    return self.responses[rank]
end

--- Set a note on this vote
-- @param note string
function LoothingVoteMixin:SetNote(note)
    self.note = note
end

--- Get the note
-- @return string|nil
function LoothingVoteMixin:GetNote()
    return self.note
end

--- Get voter's class color
-- @return table - { r, g, b }
function LoothingVoteMixin:GetClassColor()
    return LoothingUtils.GetClassColor(self.voterClass)
end

--- Get colored voter name
-- @return string
function LoothingVoteMixin:GetColoredVoterName()
    local shortName = LoothingUtils.GetShortName(self.voter)
    return LoothingUtils.ColorByClass(shortName, self.voterClass)
end

--- Get response info for display
-- @param rank number - Optional rank (default 1)
-- @return table - { name, color, icon }
function LoothingVoteMixin:GetResponseInfo(rank)
    rank = rank or 1
    local response = self.responses[rank]

    if not response then
        return nil
    end

    return Loothing.ResponseInfo[response]
end

--- Set gear comparison data
-- @param gear1Link string|nil - First equipped item
-- @param gear2Link string|nil - Second equipped item
-- @param gear1ilvl number - Item level of first item
-- @param gear2ilvl number - Item level of second item
function LoothingVoteMixin:SetGearData(gear1Link, gear2Link, gear1ilvl, gear2ilvl)
    self.gear1Link = gear1Link
    self.gear2Link = gear2Link
    self.gear1ilvl = gear1ilvl or 0
    self.gear2ilvl = gear2ilvl or 0
end

--- Calculate item level difference from candidate item
-- @param candidateIlvl number - Item level of the candidate item
function LoothingVoteMixin:CalculateIlvlDiff(candidateIlvl)
    if not candidateIlvl or candidateIlvl == 0 then
        self.ilvlDiff = 0
        return
    end

    -- For dual-wield slots, use average of both equipped items
    if self.gear2Link and self.gear2ilvl > 0 then
        local avgIlvl = (self.gear1ilvl + self.gear2ilvl) / 2
        self.ilvlDiff = candidateIlvl - avgIlvl
    elseif self.gear1Link and self.gear1ilvl > 0 then
        self.ilvlDiff = candidateIlvl - self.gear1ilvl
    else
        -- No gear equipped, candidate is pure upgrade
        self.ilvlDiff = candidateIlvl
    end
end

--- Get item level difference
-- @return number - Positive means upgrade, negative means downgrade
function LoothingVoteMixin:GetIlvlDiff()
    return self.ilvlDiff
end

--- Check if candidate is an upgrade
-- @return boolean
function LoothingVoteMixin:IsUpgrade()
    return self.ilvlDiff > 0
end

--- Set roll data
-- @param roll number - The roll value
-- @param minRoll number - Minimum roll range (default 1)
-- @param maxRoll number - Maximum roll range (default 100)
function LoothingVoteMixin:SetRoll(roll, minRoll, maxRoll)
    self.roll = roll
    self.rollRange = { min = minRoll or 1, max = maxRoll or 100 }
end

--- Get roll value
-- @return number|nil - Roll value or nil if not rolled
function LoothingVoteMixin:GetRoll()
    return self.roll
end

--- Check if voter has rolled
-- @return boolean
function LoothingVoteMixin:HasRolled()
    return self.roll ~= nil
end

--- Get roll range
-- @return table|nil - { min, max } or nil
function LoothingVoteMixin:GetRollRange()
    return self.rollRange
end

--- Get gear info for display
-- @return string - Formatted gear info text
function LoothingVoteMixin:GetGearInfo()
    if not self.gear1Link then
        return "No gear equipped"
    end

    local info = string.format("ilvl %d", self.gear1ilvl)

    if self.gear2Link and self.gear2ilvl > 0 then
        info = info .. string.format(" / %d", self.gear2ilvl)
    end

    if self.ilvlDiff ~= 0 then
        local sign = self.ilvlDiff > 0 and "+" or ""
        info = info .. string.format(" (%s%d)", sign, math.floor(self.ilvlDiff))
    end

    return info
end

--- Serialize vote
-- @return table
function LoothingVoteMixin:Serialize()
    return {
        voter = self.voter,
        voterClass = self.voterClass,
        responses = self.responses,
        timestamp = self.timestamp,
        note = self.note,
        gear1Link = self.gear1Link,
        gear2Link = self.gear2Link,
        gear1ilvl = self.gear1ilvl,
        gear2ilvl = self.gear2ilvl,
        ilvlDiff = self.ilvlDiff,
        roll = self.roll,
        rollRange = self.rollRange,
    }
end

--- Deserialize vote
-- @param data table
function LoothingVoteMixin:Deserialize(data)
    self.voter = data.voter
    self.voterClass = data.voterClass
    self.responses = data.responses or {}
    self.timestamp = data.timestamp
    self.note = data.note
    self.gear1Link = data.gear1Link
    self.gear2Link = data.gear2Link
    self.gear1ilvl = data.gear1ilvl or 0
    self.gear2ilvl = data.gear2ilvl or 0
    self.ilvlDiff = data.ilvlDiff or 0
    self.roll = data.roll
    self.rollRange = data.rollRange
end

--[[--------------------------------------------------------------------
    Factory
----------------------------------------------------------------------]]

--- Create a new vote
-- @param voter string
-- @param voterClass string
-- @param responses table
-- @return table
function CreateLoothingVote(voter, voterClass, responses)
    local vote = Loolib.CreateFromMixins(LoothingVoteMixin)
    vote:Init(voter, voterClass, responses)
    return vote
end

--[[--------------------------------------------------------------------
    LoothingVoteCollectionMixin - Collection of votes for an item
----------------------------------------------------------------------]]

LoothingVoteCollectionMixin = Loolib.CreateFromMixins(Loolib.CallbackRegistryMixin)

local VOTE_COLLECTION_EVENTS = {
    "OnVoteAdded",
    "OnVoteRemoved",
    "OnVotesCleared",
}

--- Initialize the vote collection
function LoothingVoteCollectionMixin:Init()
    Loolib.CallbackRegistryMixin.OnLoad(self)
    self:GenerateCallbackEvents(VOTE_COLLECTION_EVENTS)

    local Data = Loolib.Data
    self.votes = Data.CreateDataProvider()
    self.votesByVoter = {}  -- Quick lookup by voter name
end

--- Add a vote
-- @param vote table - Vote data or LoothingVoteMixin
-- @return boolean, boolean - success, isUpdate
function LoothingVoteCollectionMixin:AddVote(vote)
    local voter = vote.voter

    -- Check for existing vote from this voter
    local existing = self.votesByVoter[voter]
    if existing then
        -- Update existing vote
        existing.responses = vote.responses
        existing.timestamp = vote.timestamp
        existing.note = vote.note
        self:TriggerEvent("OnVoteAdded", existing, true)
        return true, true
    end

    -- Add new vote
    self.votes:Insert(vote)
    self.votesByVoter[voter] = vote
    self:TriggerEvent("OnVoteAdded", vote, false)
    return true, false
end

--- Remove a vote by voter
-- @param voter string
-- @return boolean
function LoothingVoteCollectionMixin:RemoveVote(voter)
    voter = LoothingUtils.NormalizeName(voter)

    local vote = self.votesByVoter[voter]
    if vote then
        self.votes:Remove(vote)
        self.votesByVoter[voter] = nil
        self:TriggerEvent("OnVoteRemoved", vote)
        return true
    end

    return false
end

--- Get vote by voter
-- @param voter string
-- @return table|nil
function LoothingVoteCollectionMixin:GetVote(voter)
    voter = LoothingUtils.NormalizeName(voter)
    return self.votesByVoter[voter]
end

--- Check if voter has voted
-- @param voter string
-- @return boolean
function LoothingVoteCollectionMixin:HasVoted(voter)
    voter = LoothingUtils.NormalizeName(voter)
    return self.votesByVoter[voter] ~= nil
end

--- Get all votes
-- @return DataProvider
function LoothingVoteCollectionMixin:GetVotes()
    return self.votes
end

--- Get vote count
-- @return number
function LoothingVoteCollectionMixin:GetCount()
    return self.votes:GetSize()
end

--- Clear all votes
function LoothingVoteCollectionMixin:Clear()
    self.votes:Flush()
    wipe(self.votesByVoter)
    self:TriggerEvent("OnVotesCleared")
end

--- Enumerate votes
-- @return iterator
function LoothingVoteCollectionMixin:Enumerate()
    return self.votes:Enumerate()
end

--- Get votes grouped by first-choice response
-- @return table - { [responseType] = { votes } }
function LoothingVoteCollectionMixin:GetVotesByResponse()
    local grouped = {}

    for _, response in pairs(Loothing.Response) do
        grouped[response] = {}
    end

    for _, vote in self.votes:Enumerate() do
        local firstChoice = vote.responses[1]
        if firstChoice then
            if not grouped[firstChoice] then
                -- Custom/dynamic response ID (e.g. from MLDB button sets)
                grouped[firstChoice] = {}
            end
            grouped[firstChoice][#grouped[firstChoice] + 1] = vote
        end
    end

    return grouped
end

--- Get response counts
-- @return table - { [responseType] = count }
function LoothingVoteCollectionMixin:GetResponseCounts()
    local counts = {}

    for _, response in pairs(Loothing.Response) do
        counts[response] = 0
    end

    for _, vote in self.votes:Enumerate() do
        local firstChoice = vote.responses[1]
        if firstChoice then
            if not counts[firstChoice] then
                -- Custom/dynamic response ID (e.g. from MLDB button sets)
                counts[firstChoice] = 0
            end
            counts[firstChoice] = counts[firstChoice] + 1
        end
    end

    return counts
end

--- Get voters list
-- @return table - Array of voter names
function LoothingVoteCollectionMixin:GetVoters()
    local voters = {}
    for voter in pairs(self.votesByVoter) do
        voters[#voters + 1] = voter
    end
    return voters
end

--- Serialize votes
-- @return table
function LoothingVoteCollectionMixin:Serialize()
    local serialized = {}
    for _, vote in self.votes:Enumerate() do
        if vote.Serialize then
            serialized[#serialized + 1] = vote:Serialize()
        else
            serialized[#serialized + 1] = {
                voter = vote.voter,
                voterClass = vote.voterClass,
                responses = vote.responses,
                timestamp = vote.timestamp,
                note = vote.note,
            }
        end
    end
    return serialized
end

--- Deserialize votes
-- @param data table
function LoothingVoteCollectionMixin:Deserialize(data)
    self:Clear()

    for _, voteData in ipairs(data) do
        local vote = CreateLoothingVote(
            voteData.voter,
            voteData.voterClass,
            voteData.responses
        )
        vote.timestamp = voteData.timestamp
        vote.note = voteData.note

        self:AddVote(vote)
    end
end

--[[--------------------------------------------------------------------
    Factory
----------------------------------------------------------------------]]

--- Create a new vote collection
-- @return table
function CreateLoothingVoteCollection()
    local collection = Loolib.CreateFromMixins(LoothingVoteCollectionMixin)
    collection:Init()
    return collection
end

--[[--------------------------------------------------------------------
    Vote Analysis Utilities
----------------------------------------------------------------------]]

LoothingVoteAnalysis = {}

--- Get the leading response type
-- @param votes table - Vote collection or array
-- @return number, number - Response type, count
function LoothingVoteAnalysis.GetLeadingResponse(votes)
    local counts = {}

    for _, response in pairs(Loothing.Response) do
        counts[response] = 0
    end

    local enumerate = votes.Enumerate and function() return votes:Enumerate() end or function() return ipairs(votes) end
    for _, vote in enumerate() do
        local firstChoice = type(vote.responses) == "table" and vote.responses[1]
        if firstChoice and counts[firstChoice] then
            counts[firstChoice] = counts[firstChoice] + 1
        end
    end

    local maxResponse = nil
    local maxCount = 0

    for response, count in pairs(counts) do
        if count > maxCount then
            maxCount = count
            maxResponse = response
        end
    end

    return maxResponse, maxCount
end

--- Check if there's a tie for first place
-- @param votes table - Vote collection or array
-- @return boolean, table - isTie, tiedResponses
function LoothingVoteAnalysis.IsTied(votes)
    local counts = {}

    for _, response in pairs(Loothing.Response) do
        counts[response] = 0
    end

    local enumerate = votes.Enumerate and function() return votes:Enumerate() end or function() return ipairs(votes) end
    for _, vote in enumerate() do
        local firstChoice = type(vote.responses) == "table" and vote.responses[1]
        if firstChoice and counts[firstChoice] then
            counts[firstChoice] = counts[firstChoice] + 1
        end
    end

    local maxCount = 0
    for _, count in pairs(counts) do
        if count > maxCount then
            maxCount = count
        end
    end

    local tied = {}
    for response, count in pairs(counts) do
        if count == maxCount and count > 0 then
            tied[#tied + 1] = response
        end
    end

    return #tied > 1, tied
end

--- Get voters who chose a specific response
-- @param votes table - Vote collection or array
-- @param responseType number
-- @return table - Array of voter names
function LoothingVoteAnalysis.GetVotersForResponse(votes, responseType)
    local voters = {}

    local enumerate = votes.Enumerate and function() return votes:Enumerate() end or function() return ipairs(votes) end
    for _, vote in enumerate() do
        local firstChoice = type(vote.responses) == "table" and vote.responses[1]
        if firstChoice == responseType then
            voters[#voters + 1] = vote.voter
        end
    end

    return voters
end
