--[[--------------------------------------------------------------------
    Loothing - Loot Council Addon for WoW 12.0+
    ItemData - Loot item representation and management

    Includes:
    - GetItemInfo retry loop (up to 20 attempts at 0.05s intervals)
    - Item neutralization for comm transmission
    - TypeCode system for per-type button/response sets
    - Instance data snapshot per loot table entry
----------------------------------------------------------------------]]

local Loolib = LibStub("Loolib")

--[[--------------------------------------------------------------------
    Item Info Retry

    C_Item.GetItemInfo() returns nil for uncached items. We retry up to
    20 times at 0.05s intervals before giving up.
----------------------------------------------------------------------]]

local ITEM_INFO_MAX_RETRIES = 20
local ITEM_INFO_RETRY_INTERVAL = 0.05

--- Fetch item info with retry loop for uncached items
-- @param itemLink string - Item link or item ID
-- @param callback function - Called with (itemInfo) when data is available, or nil on failure
-- @param retryCount number|nil - Internal retry counter
local function GetItemInfoWithRetry(itemLink, callback, retryCount)
    retryCount = retryCount or 0

    local name, link, quality, itemLevel, reqLevel, classStr, subclass,
          maxStack, equipSlot, texture, vendorPrice, typeID, subTypeID,
          bindType = C_Item.GetItemInfo(itemLink)

    if name then
        -- Data available, build info table
        local itemID = LoothingUtils.GetItemID(itemLink)
        callback({
            itemID = itemID,
            itemLink = link or itemLink,
            name = name,
            quality = quality,
            itemLevel = itemLevel,
            reqLevel = reqLevel,
            equipSlot = equipSlot,
            texture = texture,
            vendorPrice = vendorPrice,
            typeID = typeID,
            subTypeID = subTypeID,
            bindType = bindType,
            subType = subclass,
        })
        return
    end

    -- Not cached yet, retry
    if retryCount < ITEM_INFO_MAX_RETRIES then
        C_Timer.After(ITEM_INFO_RETRY_INTERVAL, function()
            GetItemInfoWithRetry(itemLink, callback, retryCount + 1)
        end)
    else
        -- Gave up, return what we can parse from the link
        local itemID = LoothingUtils.GetItemID(itemLink)
        callback({
            itemID = itemID,
            itemLink = itemLink,
            name = LoothingUtils.GetItemName(itemLink) or "Unknown",
            quality = LoothingUtils.GetItemQuality(itemLink),
        })
    end
end

--[[--------------------------------------------------------------------
    TypeCode System

    Each item gets a "typeCode" that determines which set of response
    buttons to display. Type code generators run in priority order;
    first non-nil result wins. Falls back to equipLoc or "default".
----------------------------------------------------------------------]]

-- Type code generator functions (run in order, first non-nil wins)
local TYPE_CODE_GENERATORS = {
    -- Rare quality items
    function(info)
        if info.quality and info.quality == Enum.ItemQuality.Rare then
            return "RARE"
        end
    end,
    -- Pets
    function(info)
        if info.typeID == Enum.ItemClass.Battlepet or
           (info.typeID == Enum.ItemClass.Miscellaneous and info.subTypeID == Enum.ItemMiscellaneousSubclass.CompanionPet) then
            return "PETS"
        end
    end,
    -- Mounts
    function(info)
        if info.typeID == Enum.ItemClass.Miscellaneous and info.subTypeID == Enum.ItemMiscellaneousSubclass.Mount then
            return "MOUNTS"
        end
    end,
    -- Recipes / crafting patterns
    function(info)
        if info.typeID == Enum.ItemClass.Recipe then
            return "RECIPE"
        end
    end,
    -- Bag slots (containers)
    function(info)
        if info.typeID == Enum.ItemClass.Container then
            return "BAGSLOT"
        end
    end,
    -- Weapons
    function(info)
        if info.typeID == Enum.ItemClass.Weapon then
            return "WEAPON"
        end
    end,
    -- Armor tokens (detected by subType or known token itemIDs)
    -- WoW token items don't have "Token" in equipSlot; they use subType or specific itemIDs
    function(info)
        -- Check subType for tier token items (e.g., "Jeton", "Token" in subType string)
        if info.subType and (info.subType:find("Token") or info.subType:find("Jeton")) then
            return "TOKEN"
        end
        -- Check if equipSlot maps to a tier slot constant (e.g., INVTYPE_HEAD with Miscellaneous type)
        if info.typeID == Enum.ItemClass.Miscellaneous and info.equipSlot and info.equipSlot ~= "" then
            return "TOKEN"
        end
    end,
}

--- Determine the type code for an item
-- @param itemInfo table - Item info table from GetItemInfo
-- @return string - Type code (e.g., "WEAPON", "default")
local function DetermineTypeCode(itemInfo)
    if not itemInfo then return "default" end

    -- Run generators in order
    for _, generator in ipairs(TYPE_CODE_GENERATORS) do
        local code = generator(itemInfo)
        if code then
            return code
        end
    end

    -- Fall back to equipLoc if available (e.g., "INVTYPE_HEAD")
    if itemInfo.equipSlot and itemInfo.equipSlot ~= "" then
        return itemInfo.equipSlot
    end

    return "default"
end

--[[--------------------------------------------------------------------
    Item Neutralization (for comm transmission)

    Strips player-specific data from item strings to minimize payload
    and preserve privacy. Follows RC's NeutralizeItem pattern.
----------------------------------------------------------------------]]

--- Neutralize an item link for transmission
-- Strips player-specific fields: level, specID, uniqueID, linkLevel, etc.
-- @param itemLink string - Full item link
-- @return string - Neutralized item string (just "item:ID:enchant:gem1:gem2:gem3:gem4:suffix:uniqueID:...")
local function NeutralizeItemString(itemLink)
    if not itemLink then return "" end

    -- Extract the item string from the link
    local itemString = itemLink:match("item:[^|]+")
    if not itemString then return "" end

    -- Split into parts
    local parts = {}
    for part in itemString:gmatch("[^:]*") do
        parts[#parts + 1] = part
    end

    -- Standard item string: item:ID:enchant:gem1:gem2:gem3:gem4:suffixID:uniqueID:level:specID:upgradeID:difficultyID:...
    -- Indices (1-based): 1=item, 2=ID, 3=enchant, 4-7=gems, 8=suffixID, 9=uniqueID, 10=level, 11=specID, 12=upgradeID, 13=difficultyID
    -- We keep: item, ID, enchant, gems, suffixID (positions 1-8)
    -- We zero out: uniqueID (9), level (10), specID (11), difficultyID (13)
    if #parts >= 9 then parts[9] = "0" end    -- uniqueID
    if #parts >= 10 then parts[10] = "0" end  -- level
    if #parts >= 11 then parts[11] = "0" end  -- specID
    if #parts >= 13 then parts[13] = "0" end  -- difficultyID

    return table.concat(parts, ":")
end

--- Get a transmittable item string (neutralized + cleaned)
-- @param itemLink string
-- @return string - Compact item string for comms
local function GetTransmittableItemString(itemLink)
    local neutralized = NeutralizeItemString(itemLink)
    -- Remove "item:" prefix for compact transmission
    return neutralized:gsub("^item:", "")
end

--[[--------------------------------------------------------------------
    Instance Data Snapshot

    Captures current instance info for each loot table entry.
----------------------------------------------------------------------]]

--- Capture a snapshot of current instance data
-- @return table - Instance data snapshot
local function CaptureInstanceData()
    local name, instanceType, difficultyID, difficultyName, maxPlayers,
          dynamicDifficulty, isDynamic, instanceID, instanceGroupSize = GetInstanceInfo()

    return {
        name = name,
        instanceType = instanceType,
        difficultyID = difficultyID,
        difficultyName = difficultyName,
        maxPlayers = maxPlayers,
        instanceID = instanceID,
        groupSize = GetNumGroupMembers(),
        mapID = C_Map and C_Map.GetBestMapForUnit("player") or nil,
    }
end

--[[--------------------------------------------------------------------
    LoothingItemMixin
----------------------------------------------------------------------]]

LoothingItemMixin = LoolibCreateFromMixins(LoolibCallbackRegistryMixin)

local ITEM_EVENTS = {
    "OnStateChanged",
    "OnVoteAdded",
    "OnVoteRemoved",
    "OnWinnerSet",
    "OnItemInfoLoaded",
    "OnTypeCodeUpdated",
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

    -- Item info (may be populated asynchronously)
    self.itemID = LoothingUtils.GetItemID(itemLink)
    self.name = LoothingUtils.GetItemName(itemLink) or "Unknown"
    self.quality = LoothingUtils.GetItemQuality(itemLink)
    self.itemLevel = nil
    self.texture = nil
    self.equipSlot = nil
    self.typeID = nil
    self.subTypeID = nil
    self.subType = nil
    self.bindType = nil
    self.itemInfoLoaded = false

    -- TypeCode (determined after item info loads)
    self.typeCode = "default"

    -- Item strings for comm
    self.neutralizedString = NeutralizeItemString(itemLink)
    self.transmitString = GetTransmittableItemString(itemLink)

    -- Instance data snapshot (captured at item creation time)
    self.instanceData = CaptureInstanceData()

    -- Class restriction flag (bitwise, 0xFFFFFFFF = all classes)
    self.classesFlag = 0xFFFFFFFF

    -- BoE tracking
    self.isBoe = false

    -- State
    self.state = LOOTHING_ITEM_STATE.PENDING
    self.voteStartTime = nil
    self.voteEndTime = nil
    self.voteTimeout = nil

    -- Votes (DataProvider)
    local Data = Loolib:GetModule("Data")
    self.votes = Data.CreateDataProvider()

    -- Candidate manager
    self.candidateManager = nil

    -- Result
    self.winner = nil
    self.winnerResponse = nil
    self.awardedTime = nil
    self.awarded = false

    -- Kick off async item info loading
    self:LoadItemInfo()
end

--- Load item info asynchronously with retry
function LoothingItemMixin:LoadItemInfo()
    GetItemInfoWithRetry(self.itemLink, function(itemInfo)
        if not itemInfo then return end

        self.name = itemInfo.name or self.name
        self.quality = itemInfo.quality or self.quality
        self.itemLevel = itemInfo.itemLevel
        self.texture = itemInfo.texture
        self.equipSlot = itemInfo.equipSlot
        self.typeID = itemInfo.typeID
        self.subTypeID = itemInfo.subTypeID
        self.subType = itemInfo.subType
        self.bindType = itemInfo.bindType
        self.itemInfoLoaded = true

        -- Determine typeCode now that we have full item info
        local newTypeCode = DetermineTypeCode(itemInfo)
        local typeCodeChanged = newTypeCode ~= self.typeCode
        self.typeCode = newTypeCode

        -- Check BoE (bindType 2 = BoE)
        self.isBoe = (itemInfo.bindType == 2)

        self:TriggerEvent("OnItemInfoLoaded", self)

        -- Notify consumers if typeCode changed from default (e.g. voting started early)
        if typeCodeChanged then
            self:TriggerEvent("OnTypeCodeUpdated", self, self.typeCode)
        end
    end)
end

--- Check if full item info has been loaded
-- @return boolean
function LoothingItemMixin:IsItemInfoLoaded()
    return self.itemInfoLoaded
end

--- Get the type code for this item
-- @return string
function LoothingItemMixin:GetTypeCode()
    return self.typeCode
end

--- Get the button/response set for this item's type code
-- @return table - Buttons array for the resolved set
function LoothingItemMixin:GetResponseSet()
    if not Loothing.Settings then return nil end

    -- Check typeCodeMap for a type-specific set
    if self.typeCode then
        local typeCodeMap = Loothing.Settings:GetTypeCodeMap()
        local setId = typeCodeMap[self.typeCode] or typeCodeMap["default"]
        if setId then
            return Loothing.Settings:GetResponseButtons(setId)
        end
    end

    -- Fall back to active set
    return Loothing.Settings:GetResponseButtons()
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
-- @param timeout number - Seconds until voting closes (0 = no timeout)
function LoothingItemMixin:StartVoting(timeout)
    if self.state ~= LOOTHING_ITEM_STATE.PENDING then
        return false
    end

    self.voteStartTime = GetTime()
    self.voteTimeout = timeout or Loothing.Settings:GetVotingTimeout()
    if self.voteTimeout == LOOTHING_TIMING.NO_TIMEOUT then
        self.voteEndTime = math.huge
    else
        self.voteEndTime = self.voteStartTime + self.voteTimeout
    end

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
-- @return number - Seconds remaining, math.huge if no-timeout, or 0 if not voting
function LoothingItemMixin:GetTimeRemaining()
    if self.state ~= LOOTHING_ITEM_STATE.VOTING then
        return 0
    end

    if not self.voteEndTime then
        return 0
    end

    if self.voteEndTime == math.huge then
        return math.huge
    end

    local remaining = self.voteEndTime - GetTime()
    return math.max(0, remaining)
end

--- Check if voting has timed out
-- @return boolean
function LoothingItemMixin:IsVotingTimedOut()
    if not self.voteEndTime then
        return false
    end
    if self.voteEndTime == math.huge then
        return false
    end
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

    -- self.votes is normally a DataProvider, but may be a plain table
    -- (from deserialized data or test fixtures) — handle both
    local enumerate = self.votes.Enumerate
        and function() return self.votes:Enumerate() end
        or function() return ipairs(self.votes) end

    for _, vote in enumerate() do
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
    self.awarded = true

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
        typeCode = self.typeCode,
        transmitString = self.transmitString,
        neutralizedString = self.neutralizedString,
        classesFlag = self.classesFlag,
        isBoe = self.isBoe,
        instanceData = self.instanceData,
        looter = self.looter,
        encounterID = self.encounterID,
        timestamp = self.timestamp,
        state = self.state,
        votes = serializedVotes,
        winner = self.winner,
        winnerResponse = self.winnerResponse,
        awardedTime = self.awardedTime,
        awarded = self.awarded,
    }
end

--- Serialize item for comm transmission (minimal payload)
-- @return table
function LoothingItemMixin:SerializeForComm()
    return {
        g = self.guid,
        s = self.transmitString,
        q = self.quality,
        l = self.itemLevel,
        e = self.equipSlot,
        t = self.typeCode,
        c = self.classesFlag,
        b = self.isBoe,
        o = self.looter,
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
    self.typeCode = data.typeCode or "default"
    self.transmitString = data.transmitString
    self.neutralizedString = data.neutralizedString
    self.classesFlag = data.classesFlag or 0xFFFFFFFF
    self.isBoe = data.isBoe or false
    self.instanceData = data.instanceData
    self.looter = data.looter
    self.encounterID = data.encounterID
    self.timestamp = data.timestamp
    self.state = data.state
    self.winner = data.winner
    self.winnerResponse = data.winnerResponse
    self.awardedTime = data.awardedTime
    self.awarded = data.awarded or false

    -- Restore votes
    self.votes:Flush()
    if data.votes then
        for _, voteData in ipairs(data.votes) do
            self.votes:Insert(voteData)
        end
    end
end

--[[--------------------------------------------------------------------
    LootTable Helpers (PrepareLootTable)
----------------------------------------------------------------------]]

--- Enrich a received loot table entry with local item data
-- Called by candidates when they receive the loot table from ML.
-- Uses retry loop to ensure item data is fully loaded.
-- @param entry table - Comm-received entry { g=guid, s=transmitString, ... }
-- @param callback function - Called with enriched LoothingItem when ready
function LoothingItemMixin.PrepareLootTableEntry(entry, callback)
    if not entry or not entry.s then
        callback(nil)
        return
    end

    -- Reconstruct item link from transmit string
    local itemString = "item:" .. entry.s
    local _, itemLink = C_Item.GetItemInfo(itemString)

    -- If itemLink not available yet, use the item string directly
    if not itemLink then
        itemLink = itemString
    end

    -- Create item with data from comm
    local item = LoolibCreateFromMixins(LoothingItemMixin)
    LoolibCallbackRegistryMixin.OnLoad(item)
    item:GenerateCallbackEvents(ITEM_EVENTS)

    local Data = Loolib:GetModule("Data")
    item.votes = Data.CreateDataProvider()

    item.guid = entry.g
    item.transmitString = entry.s
    item.quality = entry.q
    item.itemLevel = entry.l
    item.equipSlot = entry.e
    item.typeCode = entry.t or "default"
    item.classesFlag = entry.c or 0xFFFFFFFF
    item.isBoe = entry.b or false
    item.looter = entry.o
    item.state = LOOTHING_ITEM_STATE.PENDING
    item.timestamp = time()
    item.candidateManager = nil
    item.winner = nil
    item.winnerResponse = nil
    item.awardedTime = nil
    item.awarded = false

    -- Load full item info with retry
    GetItemInfoWithRetry(itemString, function(itemInfo)
        if itemInfo then
            item.itemID = itemInfo.itemID
            item.itemLink = itemInfo.itemLink or itemLink
            item.name = itemInfo.name
            item.quality = itemInfo.quality or item.quality
            item.itemLevel = itemInfo.itemLevel or item.itemLevel
            item.texture = itemInfo.texture
            item.equipSlot = itemInfo.equipSlot or item.equipSlot
            item.typeID = itemInfo.typeID
            item.subTypeID = itemInfo.subTypeID
            item.subType = itemInfo.subType
            item.bindType = itemInfo.bindType
            item.itemInfoLoaded = true
            item.neutralizedString = NeutralizeItemString(item.itemLink)
        else
            item.itemID = LoothingUtils.GetItemID(itemLink)
            item.name = "Unknown"
            item.itemLink = itemLink
            item.itemInfoLoaded = false
        end

        callback(item)
    end)
end

--[[--------------------------------------------------------------------
    Candidate Management
----------------------------------------------------------------------]]

--- Get or create candidate manager for this item
-- @return LoothingCandidateManager
function LoothingItemMixin:GetCandidateManager()
    if not self.candidateManager then
        self.candidateManager = CreateLoothingCandidateManager()
    end
    return self.candidateManager
end

--- Get or create a candidate
-- @param playerName string
-- @param playerClass string
-- @return LoothingCandidate
function LoothingItemMixin:GetOrCreateCandidate(playerName, playerClass)
    return self:GetCandidateManager():GetOrCreateCandidate(playerName, playerClass)
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
    Module-Level Utilities (accessible via LoothingItemData namespace)
----------------------------------------------------------------------]]

LoothingItemData = {
    NeutralizeItemString = NeutralizeItemString,
    GetTransmittableItemString = GetTransmittableItemString,
    DetermineTypeCode = DetermineTypeCode,
    CaptureInstanceData = CaptureInstanceData,
    GetItemInfoWithRetry = GetItemInfoWithRetry,
}

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
