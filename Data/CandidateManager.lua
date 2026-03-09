--[[--------------------------------------------------------------------
    Loothing - Loot Council Addon for WoW 12.0+
    CandidateManager - Manages candidates for a single loot item
----------------------------------------------------------------------]]

local Loolib = LibStub("Loolib")

--[[--------------------------------------------------------------------
    LoothingCandidateManagerMixin
----------------------------------------------------------------------]]

LoothingCandidateManagerMixin = Loolib.CreateFromMixins(Loolib.CallbackRegistryMixin)

local MANAGER_EVENTS = {
    "OnCandidateAdded",
    "OnCandidateUpdated",
    "OnCandidateRemoved",
    "OnCandidatesCleared",
}

--- Initialize the candidate manager
function LoothingCandidateManagerMixin:Init()
    Loolib.CallbackRegistryMixin.OnLoad(self)
    self:GenerateCallbackEvents(MANAGER_EVENTS)

    -- Candidates storage - keyed by normalized player name
    self.candidates = {}
    self.candidateCount = 0
end

--[[--------------------------------------------------------------------
    Candidate Access
----------------------------------------------------------------------]]

--- Get or create a candidate
-- @param playerName string - Player name (will be normalized)
-- @param playerClass string - Player class file (e.g., "WARRIOR")
-- @return table - Candidate object
function LoothingCandidateManagerMixin:GetOrCreateCandidate(playerName, playerClass)
    if not playerName then
        return nil
    end

    local normalizedName = LoothingUtils.NormalizeName(playerName)

    local candidate = self.candidates[normalizedName]
    if candidate then
        return candidate
    end

    -- Create new candidate
    candidate = CreateLoothingCandidate(playerName, playerClass)
    self.candidates[normalizedName] = candidate
    self.candidateCount = self.candidateCount + 1

    self:TriggerEvent("OnCandidateAdded", candidate)
    return candidate
end

--- Get a candidate by player name
-- @param playerName string - Player name (will be normalized)
-- @return table|nil - Candidate object or nil
function LoothingCandidateManagerMixin:GetCandidate(playerName)
    if not playerName then
        return nil
    end

    local normalizedName = LoothingUtils.NormalizeName(playerName)
    return self.candidates[normalizedName]
end

--- Check if a candidate exists
-- @param playerName string - Player name (will be normalized)
-- @return boolean
function LoothingCandidateManagerMixin:HasCandidate(playerName)
    if not playerName then
        return false
    end

    local normalizedName = LoothingUtils.NormalizeName(playerName)
    return self.candidates[normalizedName] ~= nil
end

--- Get all candidates as a table
-- @return table - Array of candidate objects
function LoothingCandidateManagerMixin:GetAllCandidates()
    local result = {}
    for _, candidate in pairs(self.candidates) do
        result[#result + 1] = candidate
    end
    return result
end

--- Get candidate count
-- @return number
function LoothingCandidateManagerMixin:GetCandidateCount()
    return self.candidateCount
end

--[[--------------------------------------------------------------------
    Candidate Modification
----------------------------------------------------------------------]]

--- Remove a candidate
-- @param playerName string - Player name (will be normalized)
-- @return boolean - True if candidate was removed
function LoothingCandidateManagerMixin:RemoveCandidate(playerName)
    if not playerName then
        return false
    end

    local normalizedName = LoothingUtils.NormalizeName(playerName)

    local candidate = self.candidates[normalizedName]
    if not candidate then
        return false
    end

    self.candidates[normalizedName] = nil
    self.candidateCount = self.candidateCount - 1

    self:TriggerEvent("OnCandidateRemoved", candidate)
    return true
end

--- Clear all candidates
function LoothingCandidateManagerMixin:Clear()
    if self.candidateCount == 0 then
        return
    end

    wipe(self.candidates)
    self.candidateCount = 0

    self:TriggerEvent("OnCandidatesCleared")
end

--[[--------------------------------------------------------------------
    Candidate Updates
----------------------------------------------------------------------]]

--- Forcibly set the response on a candidate (ML override)
-- @param playerName string - Player name
-- @param response number - Loothing.Response value
-- @param note string|nil - Optional note
-- @return boolean - True if updated
function LoothingCandidateManagerMixin:SetCandidateResponse(playerName, response, note)
    local candidate = self:GetCandidate(playerName)
    if not candidate then
        return false
    end

    candidate:SetResponse(response, note)
    self:TriggerEvent("OnCandidateUpdated", candidate)
    return true
end

--- Update roll data for a candidate
-- @param playerName string - Player name
-- @param roll number - Roll value
-- @param minRoll number - Optional minimum roll (default 1)
-- @param maxRoll number - Optional maximum roll (default 100)
-- @return boolean - True if updated
function LoothingCandidateManagerMixin:UpdateCandidateRoll(playerName, roll, minRoll, maxRoll)
    local candidate = self:GetCandidate(playerName)
    if not candidate then
        return false
    end

    candidate:SetRoll(roll, minRoll or 1, maxRoll or 100)
    self:TriggerEvent("OnCandidateUpdated", candidate)
    return true
end

--- Update gear data for a candidate
-- @param playerName string - Player name
-- @param gear1Link string|nil - First equipped item link
-- @param gear2Link string|nil - Second equipped item link
-- @param gear1ilvl number - Item level of first item
-- @param gear2ilvl number - Item level of second item
-- @param ilvlDiff number - Optional item level difference (will be calculated if not provided)
-- @return boolean - True if updated
function LoothingCandidateManagerMixin:UpdateCandidateGear(playerName, gear1Link, gear2Link, gear1ilvl, gear2ilvl, ilvlDiff)
    local candidate = self:GetCandidate(playerName)
    if not candidate then
        return false
    end

    candidate:SetGearData(gear1Link, gear2Link, gear1ilvl, gear2ilvl)

    if ilvlDiff then
        candidate.ilvlDiff = ilvlDiff
    end

    self:TriggerEvent("OnCandidateUpdated", candidate)
    return true
end

--- Add a vote to a candidate
-- @param playerName string - Player name
-- @return boolean - True if vote was added
function LoothingCandidateManagerMixin:AddVoteToCandidate(playerName)
    local candidate = self:GetCandidate(playerName)
    if not candidate then
        return false
    end

    candidate:AddCouncilVote()
    self:TriggerEvent("OnCandidateUpdated", candidate)
    return true
end

--- Remove a vote from a candidate
-- @param playerName string - Player name
-- @return boolean - True if vote was removed
function LoothingCandidateManagerMixin:RemoveVoteFromCandidate(playerName)
    local candidate = self:GetCandidate(playerName)
    if not candidate then
        return false
    end

    candidate:RemoveCouncilVote()
    self:TriggerEvent("OnCandidateUpdated", candidate)
    return true
end

--[[--------------------------------------------------------------------
    Filtering and Sorting
----------------------------------------------------------------------]]

--- Get candidates filtered by response type
-- @param response number - Loothing.Response value
-- @return table - Array of candidates
function LoothingCandidateManagerMixin:GetCandidatesByResponse(response)
    local result = {}

    for _, candidate in pairs(self.candidates) do
        if candidate.response == response then
            result[#result + 1] = candidate
        end
    end

    return result
end

--- Get candidates sorted by a specific column
-- @param column string - Column to sort by ("response", "roll", "ilvl", "votes", "name")
-- @param ascending boolean - Sort direction (default true)
-- @return table - Sorted array of candidates
function LoothingCandidateManagerMixin:GetCandidatesSortedBy(column, ascending)
    if ascending == nil then
        ascending = true
    end

    local candidates = self:GetAllCandidates()

    -- Define sort comparators
    local comparators = {
        response = function(a, b)
            if a.response == b.response then
                return a.playerName < b.playerName
            end
            return (a.response or 999) < (b.response or 999)
        end,

        roll = function(a, b)
            if a.roll == b.roll then
                return a.playerName < b.playerName
            end
            return (a.roll or 0) < (b.roll or 0)
        end,

        ilvl = function(a, b)
            if a.ilvlDiff == b.ilvlDiff then
                return a.playerName < b.playerName
            end
            return (a.ilvlDiff or 0) < (b.ilvlDiff or 0)
        end,

        votes = function(a, b)
            if a.councilVotes == b.councilVotes then
                return a.playerName < b.playerName
            end
            return (a.councilVotes or 0) < (b.councilVotes or 0)
        end,

        name = function(a, b)
            return a.playerName < b.playerName
        end,
    }

    local comparator = comparators[column] or comparators.name

    table.sort(candidates, function(a, b)
        if ascending then
            return comparator(a, b)
        else
            return comparator(b, a)
        end
    end)

    return candidates
end

--[[--------------------------------------------------------------------
    Response Management
----------------------------------------------------------------------]]

--- Get count of candidates by response type
-- @return table - { [responseType] = count }
function LoothingCandidateManagerMixin:GetResponseCounts()
    local counts = {}

    -- Initialize all response types to 0
    for _, response in pairs(Loothing.Response) do
        counts[response] = 0
    end

    for _, candidate in pairs(self.candidates) do
        if candidate.response and counts[candidate.response] then
            counts[candidate.response] = counts[candidate.response] + 1
        end
    end

    return counts
end

--- Get the most common response
-- @return number|nil, number - Response type and count
function LoothingCandidateManagerMixin:GetMostCommonResponse()
    local counts = self:GetResponseCounts()

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

--[[--------------------------------------------------------------------
    Statistics
----------------------------------------------------------------------]]

--- Get average item level difference
-- @return number
function LoothingCandidateManagerMixin:GetAverageIlvlDiff()
    if self.candidateCount == 0 then
        return 0
    end

    local total = 0
    local count = 0

    for _, candidate in pairs(self.candidates) do
        if candidate.ilvlDiff then
            total = total + candidate.ilvlDiff
            count = count + 1
        end
    end

    return count > 0 and (total / count) or 0
end

--- Get total votes across all candidates
-- @return number
function LoothingCandidateManagerMixin:GetTotalVotes()
    local total = 0

    for _, candidate in pairs(self.candidates) do
        total = total + (candidate.councilVotes or 0)
    end

    return total
end

--- Get candidate with highest roll
-- @return table|nil - Candidate or nil if none have rolled
function LoothingCandidateManagerMixin:GetHighestRoll()
    local highest = nil
    local maxRoll = -1

    for _, candidate in pairs(self.candidates) do
        if candidate.roll and candidate.roll > maxRoll then
            maxRoll = candidate.roll
            highest = candidate
        end
    end

    return highest
end

--- Get candidate with most votes
-- @return table|nil - Candidate or nil
function LoothingCandidateManagerMixin:GetMostVoted()
    local mostVoted = nil
    local maxVotes = -1

    for _, candidate in pairs(self.candidates) do
        local votes = candidate.councilVotes or 0
        if votes > maxVotes then
            maxVotes = votes
            mostVoted = candidate
        end
    end

    return mostVoted
end

--[[--------------------------------------------------------------------
    Serialization
----------------------------------------------------------------------]]

--- Serialize all candidates
-- @return table - Array of serialized candidate data
function LoothingCandidateManagerMixin:Serialize()
    local data = {}

    for _, candidate in pairs(self.candidates) do
        if candidate.Serialize then
            data[#data + 1] = candidate:Serialize()
        end
    end

    return data
end

--- Deserialize candidates
-- @param data table - Array of candidate data
function LoothingCandidateManagerMixin:Deserialize(data)
    self:Clear()

    for _, candidateData in ipairs(data) do
        local candidate = CreateLoothingCandidate(
            candidateData.playerName,
            candidateData.playerClass
        )

        if candidate.Deserialize then
            candidate:Deserialize(candidateData)
        end

        local normalizedName = LoothingUtils.NormalizeName(candidate.playerName)
        self.candidates[normalizedName] = candidate
        self.candidateCount = self.candidateCount + 1
    end
end

--[[--------------------------------------------------------------------
    Factory
----------------------------------------------------------------------]]

--- Create a new candidate manager
-- @return table - CandidateManager instance
function CreateLoothingCandidateManager()
    local manager = Loolib.CreateFromMixins(LoothingCandidateManagerMixin)
    manager:Init()
    return manager
end
