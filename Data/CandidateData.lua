--[[--------------------------------------------------------------------
    Loothing - Loot Council Addon for WoW 12.0+
    CandidateData - Candidate information storage and utilities
----------------------------------------------------------------------]]

local _, ns = ...
local Loolib = LibStub("Loolib")
local Loothing = ns.Addon
local Utils = ns.Utils

--[[--------------------------------------------------------------------
    CandidateMixin - Individual candidate representation
----------------------------------------------------------------------]]

local CandidateMixin = {}
ns.CandidateMixin = CandidateMixin

--- Initialize a new candidate
-- @param playerName string - Full player name "Player-Realm"
-- @param playerClass string - Class file name (e.g., "WARRIOR")
function CandidateMixin:Init(playerName, playerClass)
    self.playerName = Utils.NormalizeName(playerName)
    self.playerClass = playerClass
    -- Aliases used by the CouncilTable renderer
    self.name = self.playerName
    self.shortName = Utils.GetShortName(self.playerName)
    self.class = playerClass
    self.response = nil
    self.responseTime = nil
    self.roll = nil
    self.rollRange = nil
    self.note = nil
    self.gear1Link = nil
    self.gear1ilvl = 0
    self.gear2Link = nil
    self.gear2ilvl = 0
    self.ilvlDiff = 0
    self.itemsWonThisSession = 0
    self.itemsWonInstance = 0
    self.itemsWonWeekly = 0
    self.councilVotes = 0
end

--- Set candidate's response
-- @param response number - Loothing.Response value
-- @param note string|nil - Optional note from player
function CandidateMixin:SetResponse(response, note)
    self.response = response
    self.responseTime = GetTime()
    self.note = note
end

--- Set candidate's roll data
-- @param roll number - Roll value
-- @param minRoll number|nil - Minimum roll range (default 1)
-- @param maxRoll number|nil - Maximum roll range (default 100)
function CandidateMixin:SetRoll(roll, minRoll, maxRoll)
    self.roll = roll
    self.rollRange = { min = minRoll or 1, max = maxRoll or 100 }
end

--- Set gear comparison data
-- @param gear1Link string|nil - First equipped item link
-- @param gear2Link string|nil - Second equipped item link (for dual-wield)
-- @param gear1ilvl number - Item level of first item
-- @param gear2ilvl number - Item level of second item
-- @param ilvlDiff number - Difference from candidate item
function CandidateMixin:SetGearData(gear1Link, gear2Link, gear1ilvl, gear2ilvl, ilvlDiff)
    self.gear1Link = gear1Link
    self.gear2Link = gear2Link
    self.gear1ilvl = gear1ilvl or 0
    self.gear2ilvl = gear2ilvl or 0
    self.ilvlDiff = ilvlDiff or 0
end

--- Calculate item level difference from candidate item
-- @param candidateIlvl number - Item level of the candidate item
function CandidateMixin:CalculateIlvlDiff(candidateIlvl)
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

--- Set items won counter
-- @param count number - Number of items won this session
function CandidateMixin:SetItemsWon(count)
    self.itemsWonThisSession = count or 0
end

--- Add a council vote for this candidate
function CandidateMixin:AddCouncilVote()
    self.councilVotes = self.councilVotes + 1
end

--- Remove a council vote from this candidate
function CandidateMixin:RemoveCouncilVote()
    self.councilVotes = math.max(0, self.councilVotes - 1)
end

--- Get short player name (without realm)
-- @return string
function CandidateMixin:GetShortName()
    return Utils.GetShortName(self.playerName)
end

--- Get class color for this candidate
-- @return table - { r, g, b }
function CandidateMixin:GetClassColor()
    return Utils.GetClassColor(self.playerClass)
end

--- Get colored player name
-- @return string
function CandidateMixin:GetColoredName()
    local shortName = self:GetShortName()
    return Utils.ColorByClass(shortName, self.playerClass)
end

--- Check if candidate has responded
-- @return boolean
function CandidateMixin:HasResponded()
    return self.response ~= nil
end

--- Check if candidate has rolled
-- @return boolean
function CandidateMixin:HasRolled()
    return self.roll ~= nil
end

--- Get response info for display
-- @return table|nil - { name, color, icon }
function CandidateMixin:GetResponseInfo()
    if not self.response then
        return nil
    end

    return Loothing.ResponseInfo[self.response] or Loothing.SystemResponseInfo[self.response]
end

--- Get response name
-- @return string|nil
function CandidateMixin:GetResponseName()
    local info = self:GetResponseInfo()
    return info and info.name
end

--- Get response time
-- @return number|nil - Time in seconds since response
function CandidateMixin:GetResponseTime()
    return self.responseTime
end

--- Get roll value
-- @return number|nil
function CandidateMixin:GetRoll()
    return self.roll
end

--- Get roll range
-- @return table|nil - { min, max }
function CandidateMixin:GetRollRange()
    return self.rollRange
end

--- Get note
-- @return string|nil
function CandidateMixin:GetNote()
    return self.note
end

--- Get item level difference
-- @return number - Positive means upgrade, negative means downgrade
function CandidateMixin:GetIlvlDiff()
    return self.ilvlDiff
end

--- Check if item is an upgrade for this candidate
-- @return boolean
function CandidateMixin:IsUpgrade()
    return self.ilvlDiff > 0
end

--- Get items won this session
-- @return number
function CandidateMixin:GetItemsWon()
    return self.itemsWonThisSession
end

--- Get council votes count
-- @return number
function CandidateMixin:GetCouncilVotes()
    return self.councilVotes
end

--- Get gear info for display
-- @return string - Formatted gear info text
function CandidateMixin:GetGearInfo()
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

--- Serialize candidate data
-- @return table
function CandidateMixin:Serialize()
    return {
        playerName = self.playerName,
        playerClass = self.playerClass,
        response = self.response,
        responseTime = self.responseTime,
        roll = self.roll,
        rollRange = self.rollRange,
        note = self.note,
        gear1Link = self.gear1Link,
        gear1ilvl = self.gear1ilvl,
        gear2Link = self.gear2Link,
        gear2ilvl = self.gear2ilvl,
        ilvlDiff = self.ilvlDiff,
        itemsWonThisSession = self.itemsWonThisSession,
        councilVotes = self.councilVotes,
    }
end

--- Deserialize candidate data
-- @param data table
function CandidateMixin:Deserialize(data)
    self.playerName = data.playerName
    self.playerClass = data.playerClass
    self.response = data.response
    self.responseTime = data.responseTime
    self.roll = data.roll
    self.rollRange = data.rollRange
    self.note = data.note
    self.gear1Link = data.gear1Link
    self.gear1ilvl = data.gear1ilvl or 0
    self.gear2Link = data.gear2Link
    self.gear2ilvl = data.gear2ilvl or 0
    self.ilvlDiff = data.ilvlDiff or 0
    self.itemsWonThisSession = data.itemsWonThisSession or 0
    self.councilVotes = data.councilVotes or 0
end

--[[--------------------------------------------------------------------
    Factory
----------------------------------------------------------------------]]

--- Create a new candidate
-- @param playerName string - Full player name
-- @param playerClass string - Class file name
-- @return table
local function CreateCandidate(playerName, playerClass)
    local candidate = Loolib.CreateFromMixins(CandidateMixin)
    candidate:Init(playerName, playerClass)
    return candidate
end

ns.CreateCandidate = CreateCandidate

--[[--------------------------------------------------------------------
    CandidateCollectionMixin - Collection of candidates for an item
----------------------------------------------------------------------]]

local CandidateCollectionMixin = Loolib.CreateFromMixins(Loolib.CallbackRegistryMixin)
ns.CandidateCollectionMixin = CandidateCollectionMixin

local CANDIDATE_COLLECTION_EVENTS = {
    "OnCandidateAdded",
    "OnCandidateRemoved",
    "OnCandidatesCleared",
    "OnCandidateUpdated",
}

--- Initialize the candidate collection
function CandidateCollectionMixin:Init()
    Loolib.CallbackRegistryMixin.OnLoad(self)
    self:GenerateCallbackEvents(CANDIDATE_COLLECTION_EVENTS)

    local Data = Loolib.Data
    self.candidates = Data.CreateDataProvider()
    self.candidatesByName = {}  -- Quick lookup by player name
end

--- Add a candidate
-- @param candidate table - Candidate data or CandidateMixin
-- @return boolean, boolean - success, isUpdate
function CandidateCollectionMixin:AddCandidate(candidate)
    local playerName = candidate.playerName

    -- Check for existing candidate
    local existing = self.candidatesByName[playerName]
    if existing then
        -- Update existing candidate
        existing.response = candidate.response
        existing.responseTime = candidate.responseTime
        existing.roll = candidate.roll
        existing.rollRange = candidate.rollRange
        existing.note = candidate.note
        existing.gear1Link = candidate.gear1Link
        existing.gear1ilvl = candidate.gear1ilvl
        existing.gear2Link = candidate.gear2Link
        existing.gear2ilvl = candidate.gear2ilvl
        existing.ilvlDiff = candidate.ilvlDiff
        self:TriggerEvent("OnCandidateUpdated", existing)
        return true, true
    end

    -- Add new candidate
    self.candidates:Insert(candidate)
    self.candidatesByName[playerName] = candidate
    self:TriggerEvent("OnCandidateAdded", candidate, false)
    return true, false
end

--- Remove a candidate by player name
-- @param playerName string
-- @return boolean
function CandidateCollectionMixin:RemoveCandidate(playerName)
    playerName = Utils.NormalizeName(playerName)

    local candidate = self.candidatesByName[playerName]
    if candidate then
        self.candidates:Remove(candidate)
        self.candidatesByName[playerName] = nil
        self:TriggerEvent("OnCandidateRemoved", candidate)
        return true
    end

    return false
end

--- Get candidate by player name
-- @param playerName string
-- @return table|nil
function CandidateCollectionMixin:GetCandidate(playerName)
    playerName = Utils.NormalizeName(playerName)
    return self.candidatesByName[playerName]
end

--- Check if player is a candidate
-- @param playerName string
-- @return boolean
function CandidateCollectionMixin:HasCandidate(playerName)
    playerName = Utils.NormalizeName(playerName)
    return self.candidatesByName[playerName] ~= nil
end

--- Get all candidates
-- @return DataProvider
function CandidateCollectionMixin:GetCandidates()
    return self.candidates
end

--- Get candidate count
-- @return number
function CandidateCollectionMixin:GetCount()
    return self.candidates:GetSize()
end

--- Clear all candidates
function CandidateCollectionMixin:Clear()
    self.candidates:Flush()
    wipe(self.candidatesByName)
    self:TriggerEvent("OnCandidatesCleared")
end

--- Enumerate candidates
-- @return iterator
function CandidateCollectionMixin:Enumerate()
    return self.candidates:Enumerate()
end

--- Get candidates grouped by response type
-- @return table - { [responseType] = { candidates } }
function CandidateCollectionMixin:GetCandidatesByResponse()
    local grouped = {}

    for _, response in pairs(Loothing.Response) do
        grouped[response] = {}
    end

    for _, candidate in self.candidates:Enumerate() do
        if candidate.response and grouped[candidate.response] then
            grouped[candidate.response][#grouped[candidate.response] + 1] = candidate
        end
    end

    return grouped
end

--- Get response counts
-- @return table - { [responseType] = count }
function CandidateCollectionMixin:GetResponseCounts()
    local counts = {}

    for _, response in pairs(Loothing.Response) do
        counts[response] = 0
    end

    for _, candidate in self.candidates:Enumerate() do
        if candidate.response and counts[candidate.response] then
            counts[candidate.response] = counts[candidate.response] + 1
        end
    end

    return counts
end

--- Get candidates who have responded
-- @return table - Array of candidates
function CandidateCollectionMixin:GetRespondedCandidates()
    local responded = {}
    for _, candidate in self.candidates:Enumerate() do
        if candidate:HasResponded() then
            responded[#responded + 1] = candidate
        end
    end
    return responded
end

--- Get candidates who have rolled
-- @return table - Array of candidates
function CandidateCollectionMixin:GetRolledCandidates()
    local rolled = {}
    for _, candidate in self.candidates:Enumerate() do
        if candidate:HasRolled() then
            rolled[#rolled + 1] = candidate
        end
    end
    return rolled
end

--- Get player names list
-- @return table - Array of player names
function CandidateCollectionMixin:GetPlayerNames()
    local names = {}
    for name in pairs(self.candidatesByName) do
        names[#names + 1] = name
    end
    return names
end

--- Serialize candidates
-- @return table
function CandidateCollectionMixin:Serialize()
    local serialized = {}
    for _, candidate in self.candidates:Enumerate() do
        if candidate.Serialize then
            serialized[#serialized + 1] = candidate:Serialize()
        else
            serialized[#serialized + 1] = {
                playerName = candidate.playerName,
                playerClass = candidate.playerClass,
                response = candidate.response,
                responseTime = candidate.responseTime,
                roll = candidate.roll,
                rollRange = candidate.rollRange,
                note = candidate.note,
                gear1Link = candidate.gear1Link,
                gear1ilvl = candidate.gear1ilvl,
                gear2Link = candidate.gear2Link,
                gear2ilvl = candidate.gear2ilvl,
                ilvlDiff = candidate.ilvlDiff,
                itemsWonThisSession = candidate.itemsWonThisSession,
                councilVotes = candidate.councilVotes,
            }
        end
    end
    return serialized
end

--- Deserialize candidates
-- @param data table
function CandidateCollectionMixin:Deserialize(data)
    self:Clear()

    for _, candidateData in ipairs(data) do
        local candidate = ns.CreateCandidate(
            candidateData.playerName,
            candidateData.playerClass
        )
        candidate:Deserialize(candidateData)

        self:AddCandidate(candidate)
    end
end

--[[--------------------------------------------------------------------
    Factory
----------------------------------------------------------------------]]

--- Create a new candidate collection
-- @return table
local function CreateCandidateCollection()
    local collection = Loolib.CreateFromMixins(CandidateCollectionMixin)
    collection:Init()
    return collection
end

ns.CreateCandidateCollection = CreateCandidateCollection

--[[--------------------------------------------------------------------
    Candidate Sorting Utilities
----------------------------------------------------------------------]]

local CandidateSorting = {}
ns.CandidateSorting = CandidateSorting

--- Sort candidates by response priority (Need > Greed > Offspec > Transmog > Pass)
-- @param a table - First candidate
-- @param b table - Second candidate
-- @return boolean
function CandidateSorting.ByResponsePriority(a, b)
    local aPriority = a.response or 999
    local bPriority = b.response or 999

    if aPriority ~= bPriority then
        return aPriority < bPriority
    end

    -- Tie-breaker: council votes
    return a.councilVotes > b.councilVotes
end

--- Sort candidates by council votes (descending)
-- @param a table - First candidate
-- @param b table - Second candidate
-- @return boolean
function CandidateSorting.ByCouncilVotes(a, b)
    if a.councilVotes ~= b.councilVotes then
        return a.councilVotes > b.councilVotes
    end

    -- Tie-breaker: response priority
    return (a.response or 999) < (b.response or 999)
end

--- Sort candidates by roll value (descending)
-- @param a table - First candidate
-- @param b table - Second candidate
-- @return boolean
function CandidateSorting.ByRoll(a, b)
    local aRoll = a.roll or 0
    local bRoll = b.roll or 0

    if aRoll ~= bRoll then
        return aRoll > bRoll
    end

    -- Tie-breaker: response priority
    return (a.response or 999) < (b.response or 999)
end

--- Sort candidates by item level difference (descending - biggest upgrade first)
-- @param a table - First candidate
-- @param b table - Second candidate
-- @return boolean
function CandidateSorting.ByIlvlDiff(a, b)
    if a.ilvlDiff ~= b.ilvlDiff then
        return a.ilvlDiff > b.ilvlDiff
    end

    -- Tie-breaker: council votes
    return a.councilVotes > b.councilVotes
end

--- Sort candidates by items won this session (ascending - fewer items first)
-- @param a table - First candidate
-- @param b table - Second candidate
-- @return boolean
function CandidateSorting.ByItemsWon(a, b)
    if a.itemsWonThisSession ~= b.itemsWonThisSession then
        return a.itemsWonThisSession < b.itemsWonThisSession
    end

    -- Tie-breaker: council votes
    return a.councilVotes > b.councilVotes
end

--- Sort candidates by player name (alphabetical)
-- @param a table - First candidate
-- @param b table - Second candidate
-- @return boolean
function CandidateSorting.ByName(a, b)
    return a.playerName < b.playerName
end
