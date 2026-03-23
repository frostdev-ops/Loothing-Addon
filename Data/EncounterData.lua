--[[--------------------------------------------------------------------
    Loothing - Loot Council Addon for WoW 12.0+
    EncounterData - Encounter Journal data access and caching

    This module provides boss and loot data from the Encounter Journal.
    Rather than hardcoding massive data tables, it queries the EJ API
    dynamically and caches results for performance.
----------------------------------------------------------------------]]

local _, ns = ...
local Loothing = ns.Addon

--[[--------------------------------------------------------------------
    EncounterData (Singleton)
----------------------------------------------------------------------]]

local EncounterData = {}
ns.EncounterData = EncounterData

-- Cache structures
local encounterCache = {}      -- [encounterID] = { name, items, instanceID, instanceName }
local itemToEncounter = {}     -- [itemID] = encounterID
local instanceCache = {}       -- [instanceID] = { name, encounters, isRaid }
local currentRaidCache = nil   -- Current raid tier encounter data
local initialized = false

-- Current expansion raid tier ID (The War Within)
local CURRENT_TIER = 11 -- TWW expansion

-- Difficulty mapping
local DIFFICULTY_IDS = {
    NORMAL = 14,
    HEROIC = 15,
    MYTHIC = 16,
    LFR = 17,
}

--[[--------------------------------------------------------------------
    Initialization
----------------------------------------------------------------------]]

--- Initialize the encounter data system
function EncounterData:Init()
    if initialized then return end

    -- Load Encounter Journal addon if needed
    if not C_AddOns.IsAddOnLoaded("Blizzard_EncounterJournal") then
        C_AddOns.LoadAddOn("Blizzard_EncounterJournal")
    end

    initialized = true
    Loothing:Debug("EncounterData initialized")
end

--[[--------------------------------------------------------------------
    Instance Data
----------------------------------------------------------------------]]

--- Get all instances for the current raid tier
-- @param isRaid boolean - True for raids, false for dungeons
-- @return table - Array of { instanceID, name, isRaid }
function EncounterData:GetCurrentTierInstances(isRaid)
    self:Init()

    local instances = {}

    EJ_SelectTier(CURRENT_TIER)

    local index = 1
    while EJ_GetInstanceByIndex(index, isRaid) do
        local instanceID, name = EJ_GetInstanceByIndex(index, isRaid)
        if instanceID then
            instances[#instances + 1] = {
                instanceID = instanceID,
                name = name,
                isRaid = isRaid,
            }

            -- Cache instance info
            if not instanceCache[instanceID] then
                instanceCache[instanceID] = {
                    name = name,
                    isRaid = isRaid,
                    encounters = {},
                }
            end
        end
        index = index + 1
    end

    return instances
end

--- Get all current tier raids
-- @return table - Array of raid instance data
function EncounterData:GetCurrentRaids()
    return self:GetCurrentTierInstances(true)
end

--- Get all current tier dungeons
-- @return table - Array of dungeon instance data
function EncounterData:GetCurrentDungeons()
    return self:GetCurrentTierInstances(false)
end

--[[--------------------------------------------------------------------
    Encounter (Boss) Data
----------------------------------------------------------------------]]

--- Get all encounters (bosses) for an instance
-- @param instanceID number - Instance ID
-- @return table - Array of { encounterID, name, description }
function EncounterData:GetEncountersForInstance(instanceID)
    self:Init()

    -- Check cache
    if instanceCache[instanceID] and #instanceCache[instanceID].encounters > 0 then
        return instanceCache[instanceID].encounters
    end

    local encounters = {}

    EJ_SelectInstance(instanceID)

    local index = 1
    while true do
        local name, description, journalEncounterID, _rootSectionID, link = EJ_GetEncounterInfoByIndex(index, instanceID)
        if not name then break end

        encounters[#encounters + 1] = {
            encounterID = journalEncounterID,
            name = name,
            description = description,
            link = link,
        }

        -- Cache encounter
        encounterCache[journalEncounterID] = encounterCache[journalEncounterID] or {}
        encounterCache[journalEncounterID].name = name
        encounterCache[journalEncounterID].instanceID = instanceID

        index = index + 1
    end

    -- Update instance cache
    if instanceCache[instanceID] then
        instanceCache[instanceID].encounters = encounters
    else
        local instanceName = EJ_GetInstanceInfo(instanceID)
        instanceCache[instanceID] = {
            name = instanceName,
            isRaid = true, -- Assume raid, will be overwritten if known
            encounters = encounters,
        }
    end

    return encounters
end

--- Get encounter info by ID
-- @param encounterID number - Encounter Journal encounter ID
-- @return table|nil - { name, instanceID, instanceName, items }
function EncounterData:GetEncounterInfo(encounterID)
    self:Init()

    -- Check cache
    if encounterCache[encounterID] and encounterCache[encounterID].name then
        return encounterCache[encounterID]
    end

    -- Try to get info directly
    local name, _description, _journalEncounterID, _rootSectionID, link = EJ_GetEncounterInfo(encounterID)
    if name then
        encounterCache[encounterID] = encounterCache[encounterID] or {}
        encounterCache[encounterID].name = name
        encounterCache[encounterID].link = link
        return encounterCache[encounterID]
    end

    return nil
end

--- Get boss name for an encounter ID
-- @param encounterID number - Encounter ID
-- @return string|nil - Boss name
function EncounterData:GetBossName(encounterID)
    local info = self:GetEncounterInfo(encounterID)
    return info and info.name or nil
end

--[[--------------------------------------------------------------------
    Loot Data
----------------------------------------------------------------------]]

--- Get all loot for an encounter
-- @param encounterID number - Encounter ID
-- @param difficultyID number|nil - Difficulty ID (default: current difficulty)
-- @return table - Array of item info { itemID, link, name, icon, slot, armorType, encounterID }
function EncounterData:GetEncounterLoot(encounterID, difficultyID)
    self:Init()

    local items = {}
    local cacheKey = encounterID .. "_" .. (difficultyID or "default")

    -- Check cache
    if encounterCache[encounterID] and encounterCache[encounterID].items and encounterCache[encounterID].items[cacheKey] then
        return encounterCache[encounterID].items[cacheKey]
    end

    -- Get encounter info to select the right instance
    local info = self:GetEncounterInfo(encounterID)
    if info and info.instanceID then
        EJ_SelectInstance(info.instanceID)
    end

    -- Set difficulty if specified
    if difficultyID then
        EJ_SetDifficulty(difficultyID)
    end

    -- Clear slot filter to get all items
    C_EncounterJournal.SetSlotFilter(Enum.ItemSlotFilterType.NoFilter)
    EJ_SetLootFilter(0, 0) -- No class/spec filter

    -- Select the encounter
    EJ_SelectEncounter(encounterID)

    -- Get loot count for this encounter
    local numLoot = EJ_GetNumLoot()
    for i = 1, numLoot do
        local lootInfo = C_EncounterJournal.GetLootInfoByIndex(i)
        if lootInfo and lootInfo.itemID then
            items[#items + 1] = {
                itemID = lootInfo.itemID,
                link = lootInfo.link,
                name = lootInfo.name,
                icon = lootInfo.icon,
                slot = lootInfo.slot,
                armorType = lootInfo.armorType,
                encounterID = encounterID,
            }

            -- Cache item -> encounter mapping
            itemToEncounter[lootInfo.itemID] = encounterID
        end
    end

    -- Cache results
    encounterCache[encounterID] = encounterCache[encounterID] or {}
    encounterCache[encounterID].items = encounterCache[encounterID].items or {}
    encounterCache[encounterID].items[cacheKey] = items

    return items
end

--- Get all items for a boss (alias for GetEncounterLoot)
-- @param encounterID number - Encounter ID
-- @return table - Array of item IDs
function EncounterData:GetBossItems(encounterID)
    local items = self:GetEncounterLoot(encounterID)
    local itemIDs = {}
    for _, item in ipairs(items) do
        itemIDs[#itemIDs + 1] = item.itemID
    end
    return itemIDs
end

--- Find the encounter that drops an item
-- @param itemID number - Item ID
-- @return number|nil - Encounter ID
function EncounterData:FindEncounterForItem(itemID)
    -- Check cache first
    if itemToEncounter[itemID] then
        return itemToEncounter[itemID]
    end

    -- Need to scan encounters to find the item
    -- This is expensive, so we cache aggressively
    local raids = self:GetCurrentRaids()
    for _, raid in ipairs(raids) do
        local encounters = self:GetEncountersForInstance(raid.instanceID)
        for _, encounter in ipairs(encounters) do
            local loot = self:GetEncounterLoot(encounter.encounterID)
            for _, item in ipairs(loot) do
                if item.itemID == itemID then
                    return encounter.encounterID
                end
            end
        end
    end

    -- Also check dungeons
    local dungeons = self:GetCurrentDungeons()
    for _, dungeon in ipairs(dungeons) do
        local encounters = self:GetEncountersForInstance(dungeon.instanceID)
        for _, encounter in ipairs(encounters) do
            local loot = self:GetEncounterLoot(encounter.encounterID)
            for _, item in ipairs(loot) do
                if item.itemID == itemID then
                    return encounter.encounterID
                end
            end
        end
    end

    return nil
end

--- Get the boss that drops an item
-- @param itemID number - Item ID
-- @return string|nil, number|nil - Boss name, encounter ID
function EncounterData:GetBossForItem(itemID)
    local encounterID = self:FindEncounterForItem(itemID)
    if encounterID then
        return self:GetBossName(encounterID), encounterID
    end
    return nil, nil
end

--[[--------------------------------------------------------------------
    Instance Loot
----------------------------------------------------------------------]]

--- Get all loot for an instance
-- @param instanceID number - Instance ID
-- @param difficultyID number|nil - Difficulty ID
-- @return table - Array of item info
function EncounterData:GetInstanceLoot(instanceID, difficultyID)
    self:Init()

    local allItems = {}

    local encounters = self:GetEncountersForInstance(instanceID)
    for _, encounter in ipairs(encounters) do
        local items = self:GetEncounterLoot(encounter.encounterID, difficultyID)
        for _, item in ipairs(items) do
            allItems[#allItems + 1] = item
        end
    end

    return allItems
end

--[[--------------------------------------------------------------------
    Current Raid Helpers
----------------------------------------------------------------------]]

--- Preload current raid data (call early for performance)
function EncounterData:PreloadCurrentRaid()
    self:Init()

    if currentRaidCache then
        return currentRaidCache
    end

    local raids = self:GetCurrentRaids()
    if #raids == 0 then
        Loothing:Debug("No current raids found")
        return nil
    end

    -- Get the first (latest) raid
    local raid = raids[1]

    currentRaidCache = {
        instanceID = raid.instanceID,
        name = raid.name,
        encounters = {},
        loot = {},
    }

    -- Preload all encounters and their loot
    local encounters = self:GetEncountersForInstance(raid.instanceID)
    for _, encounter in ipairs(encounters) do
        currentRaidCache.encounters[#currentRaidCache.encounters + 1] = encounter

        -- Preload loot for all difficulties
        for _diffName, diffID in pairs(DIFFICULTY_IDS) do
            self:GetEncounterLoot(encounter.encounterID, diffID)
        end
    end

    Loothing:Debug("Preloaded raid:", raid.name, "with", #encounters, "bosses")

    return currentRaidCache
end

--- Get current raid info
-- @return table|nil - { instanceID, name, encounters }
function EncounterData:GetCurrentRaid()
    if not currentRaidCache then
        self:PreloadCurrentRaid()
    end
    return currentRaidCache
end

--[[--------------------------------------------------------------------
    Utility Functions
----------------------------------------------------------------------]]

--- Check if an item is from the Encounter Journal
-- @param itemID number - Item ID
-- @return boolean
function EncounterData:IsEJItem(itemID)
    return itemToEncounter[itemID] ~= nil or self:FindEncounterForItem(itemID) ~= nil
end

--- Get difficulty name
-- @param difficultyID number - Difficulty ID
-- @return string
function EncounterData:GetDifficultyName(difficultyID)
    local name = GetDifficultyInfo(difficultyID)
    return name or "Unknown"
end

--- Clear all cached data
function EncounterData:ClearCache()
    wipe(encounterCache)
    wipe(itemToEncounter)
    wipe(instanceCache)
    currentRaidCache = nil
    Loothing:Debug("EncounterData cache cleared")
end

--- Get cache statistics
-- @return table - { encounters, items, instances }
function EncounterData:GetCacheStats()
    local encounterCount = 0
    local itemCount = 0
    local instanceCount = 0

    for _ in pairs(encounterCache) do encounterCount = encounterCount + 1 end
    for _ in pairs(itemToEncounter) do itemCount = itemCount + 1 end
    for _ in pairs(instanceCache) do instanceCount = instanceCount + 1 end

    return {
        encounters = encounterCount,
        items = itemCount,
        instances = instanceCount,
    }
end

--[[--------------------------------------------------------------------
    Static Encounter ID Mappings (Common bosses for quick reference)
----------------------------------------------------------------------]]

-- Current tier (TWW Season 1) encounter IDs
-- These are populated on first access from the Encounter Journal
Loothing.Encounters = Loothing.Encounters or {}

--- Populate common encounter IDs from the journal
function EncounterData:PopulateEncounterIDs()
    self:Init()

    local raids = self:GetCurrentRaids()
    for _, raid in ipairs(raids) do
        local encounters = self:GetEncountersForInstance(raid.instanceID)
        for _, encounter in ipairs(encounters) do
            local safeName = encounter.name:gsub("[^%w]", "_"):upper()
            Loothing.Encounters[safeName] = encounter.encounterID
        end
    end

    return Loothing.Encounters
end

--[[--------------------------------------------------------------------
    Rare Items (Very Rare / Extremely Rare drops)
----------------------------------------------------------------------]]

--- Get rare items for an encounter
-- @param encounterID number - Encounter ID
-- @param difficultyID number|nil - Difficulty ID
-- @return table - Array of rare item info
function EncounterData:GetRareItems(encounterID, difficultyID)
    local allItems = self:GetEncounterLoot(encounterID, difficultyID)
    local rareItems = {}

    -- Filter for rare items (these would need tooltip scanning or extra API)
    -- For now, we mark items with special names or known rare item IDs
    for _, item in ipairs(allItems) do
        -- Mount, pet, and toy drops are typically rare
        if item.slot == "Mount" or item.slot == "Pet" or item.slot == "Toy" then
            rareItems[#rareItems + 1] = item
        end
    end

    return rareItems
end
