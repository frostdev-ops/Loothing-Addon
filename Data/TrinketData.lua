--[[--------------------------------------------------------------------
    Loothing - Loot Council Addon for WoW 12.0+
    TrinketData - Trinket spec restrictions for auto-pass

    This module provides trinket-to-spec mappings from the Encounter Journal.
    Each trinket has a "spec flag" indicating which specs can loot it.

    Spec Flag Format:
    A 13-character string (one per class, in reverse order by classID).
    Each character is a hex digit representing which specs can use the item.
    - Bit 0 = Spec 1, Bit 1 = Spec 2, Bit 2 = Spec 3, Bit 3 = Spec 4
    - 0 = no specs, F = all 4 specs, 7 = first 3 specs, etc.

    Example: "0365002707767"
    - Position 1 (from right): Warrior (classID 1) = 7 = specs 1,2,3
    - Position 2: Paladin (classID 2) = 6 = specs 2,3
    - Position 3: Hunter (classID 3) = 7 = specs 1,2,3
    - etc.

    Data sourced from RCLootCouncil2/Utils/EncounterJournalData.lua
----------------------------------------------------------------------]]
local _, ns = ...

local Loolib = LibStub("Loolib")
local Loothing = ns.Addon

--[[--------------------------------------------------------------------
    Trinket Categories - Descriptive names for spec flags
----------------------------------------------------------------------]]

Loothing.TrinketCategories = {
    ["73F7777777777"] = ALL_CLASSES,
    -- Midnight-corrected archetype flags (Devourer DH digit 4 / Aug Evoker
    -- bits included). Legacy pre-Midnight keys above/below are kept for any
    -- older data that still carries them.
    ["77F7777777777"] = ALL_CLASSES,
    ["7492775070010"] = ITEM_MOD_INTELLECT_SHORT,
    ["5410771040000"] = DAMAGER .. ", " .. ITEM_MOD_INTELLECT_SHORT,
    ["5534773647743"] = DAMAGER,
    ["0365002707767"] = ITEM_MOD_STRENGTH_SHORT .. "/" .. ITEM_MOD_AGILITY_SHORT,
    ["0000000700067"] = ITEM_MOD_STRENGTH_SHORT,
    ["0365002707467"] = MELEE,
    ["33F7777077710"] = ITEM_MOD_AGILITY_SHORT .. "/" .. ITEM_MOD_INTELLECT_SHORT,
    ["0365002007700"] = ITEM_MOD_AGILITY_SHORT,
    ["7092775070010"] = ITEM_MOD_INTELLECT_SHORT,
    ["0241000100024"] = TANK,
    ["2082004030010"] = HEALER,
    ["6082004030010"] = HEALER,
    ["0124002607743"] = DAMAGER .. ", " .. ITEM_MOD_STRENGTH_SHORT .. "/" .. ITEM_MOD_AGILITY_SHORT,
    ["0000000600043"] = DAMAGER .. ", " .. ITEM_MOD_STRENGTH_SHORT,
    ["0124002007700"] = DAMAGER .. ", " .. ITEM_MOD_AGILITY_SHORT,
    ["0124002607443"] = DAMAGER .. ", " .. MELEE,
    ["0010771050300"] = DAMAGER .. ", " .. RANGED,
    ["1010771050000"] = DAMAGER .. ", " .. ITEM_MOD_INTELLECT_SHORT,
    ["5134773647743"] = DAMAGER,
    ["22C3004130034"] = TANK .. ", " .. HEALER,
}

--[[--------------------------------------------------------------------
    Trinket Spec Data
    Format: [itemID] = specFlag

    This table should contain all raid trinkets. The data below is a
    sample. For complete data, copy from RCLootCouncil2/Utils/EncounterJournalData.lua
----------------------------------------------------------------------]]

Loothing.TrinketSpecs = {
    -- ================================================================
    -- Midnight Season 1 Trinkets
    -- Sourced from RCLootCouncil/Utils/EncounterJournalData.lua
    -- ================================================================

    -- Midnight world/zone trinket
    [250462] = "77F7777777777", -- Forgotten Farstrider's Insignia (All)

    -- The Dreamrift (id: 1314)
    [249343] = "77F7777777777", -- Gaze of the Alnseer (All)
    [249805] = "0124002607743", -- Undreamt God's Oozing Vestige (DPS Str/Agi)

    -- The Voidspire (id: 1307)
    [249339] = "0241000100024", -- Gloom-Spattered Dreadscale (Tank)
    [249342] = "0000000700067", -- Heart of Ancient Hunger (Str)
    [249344] = "0124002607743", -- Light Company Guidon (DPS Str/Agi)
    [249808] = "2082004030010", -- Litany of Lightblind Wrath (Healer)
    [249809] = "7492775070010", -- Locus-Walker's Ribbon (Int)
    [249345] = "0124002007700", -- Ranger-Captain's Iridescent Insignia (DPS Agi)
    [249346] = "7492775070010", -- Vaelgor's Final Stare (Int)
    [249341] = "2082004030010", -- Volatile Void Suffuser (Healer)
    [249340] = "5410771040000", -- Wraps of Cosmic Madness (DPS Int)

    -- March on Quel'Danas (id: 1308)
    [249811] = "2082004030010", -- Light of the Cosmic Crescendo (Healer)
    [249806] = "0365002707767", -- Radiant Plume (Str/Agi)
    [249810] = "5410771040000", -- Shadow of the Empyrean Requiem (DPS Int)
    [249807] = "0241000100024", -- The Eternal Egg (Tank)
    [260235] = "0365002707767", -- Umbral Plume (Str/Agi)

    -- ================================================================
    -- Midnight Season 2 Trinkets (patch 12.1 "Curse of Ula'tek")
    -- Sourced from ItemSparse 12.1.0.69382 (wago.tools) + Wowhead;
    -- role/stat archetypes cross-checked against the community S2 loot table.
    -- ================================================================

    -- The Venomous Abyss
    [270162] = "7492775070010", -- Soulcoiler Ritual Vessel (Int) — Nek'zali the Soulcoiler
    [270165] = "0365002707767", -- Keeper's Seething Core (Str/Agi) — Entombed Sentinels
    [270161] = "5410771040000", -- Fang of Umbral Malignance (DPS Int) — Vashnik the Malignant
    [270166] = "0365002007700", -- Vashnik's Sanguine Rancor (Agi) — Vashnik the Malignant
    [270160] = "0241000100024", -- First Mate's Shellward (Tank) — The Lost Explorers
    [270164] = "77F7777777777", -- Gebbo's Bottomless Bag (All) — The Lost Explorers
    [270163] = "0000000700067", -- Sszorak's Ferocity (Str) — Sszorak
    [270174] = "0241000100024", -- Idol of the Howling Nexus (Tank) — Sszorak
    [270170] = "5410771040000", -- Vexhul's Everflowing Gland (DPS Int) — The Twin Fangs
    [270171] = "2082004030010", -- Preternatural Antivenom (Healer) — The Twin Fangs
    [270169] = "7492775070010", -- Hex Lord's Dooming Idol (Int) — The Coiled Altar
    [270173] = "0124002607743", -- Zul'jin's Guillotine Technique (DPS Str/Agi) — The Coiled Altar
    [270168] = "5534773647743", -- Font of Venomous Rage (DPS) — Ula'tek
    [270175] = "0365002707767", -- Voracious Heart of Ula'tek (Str/Agi) — Ula'tek

    -- ================================================================
    -- The War Within Season 1 Trinkets
    -- ================================================================

    -- Nerub-ar Palace Normal/Heroic/Mythic (id: 1273)
    -- Add trinkets as they become known

    -- ================================================================
    -- Dragonflight Trinkets (Examples)
    -- ================================================================

    -- Vault of the Incarnates
    [193773] = "0241000100024", -- Manic Grieftorch (Tank)
    [193769] = "0365002707767", -- Spiteful Storm (Str/Agi)

    -- ================================================================
    -- Legacy Trinkets (Timewalking)
    -- ================================================================

    -- Magisters' Terrace
    [133464] = "0241000100024", -- Commendation of Kael'thas (Tank)
    [133463] = "0124002607743", -- Shard of Contempt (DPS Str/Agi)
    [133461] = "0010771050000", -- Timbal's Focusing Crystal (DPS Int)
    [133462] = "0082004030010", -- Vial of the Sunwell (Healer)

    -- Classic Dungeons
    [11832] = "0082004030010", -- Burst of Knowledge (Healer)
    [11810] = "0241000100024", -- Force of Will (Tank)
    [11815] = "0365002707767", -- Hand of Justice (Str/Agi)
    [11819] = "0082004030010", -- Second Wind (Healer)
}

--[[--------------------------------------------------------------------
    TrinketData API
----------------------------------------------------------------------]]

local TrinketData = {}
ns.TrinketData = TrinketData

-- Number of classes in WoW (used for spec flag parsing)
local NUM_CLASSES = 13

--- Check if an item is in the trinket database
-- @param itemID number - Item ID
-- @return boolean - True if item is a known trinket
function TrinketData:IsTrinket(itemID)
    return Loothing.TrinketSpecs[itemID] ~= nil
end

--- Get the spec flag for a trinket
-- @param itemID number - Item ID
-- @return string|nil - Spec flag or nil if not found
function TrinketData:GetSpecFlag(itemID)
    return Loothing.TrinketSpecs[itemID]
end

--- Get the category description for a spec flag
-- @param specFlag string - Spec flag
-- @return string - Category description or empty string
function TrinketData:GetCategory(specFlag)
    return Loothing.TrinketCategories[specFlag] or ""
end

--- Get the category description for a trinket
-- @param itemID number - Item ID
-- @return string - Category description or empty string
function TrinketData:GetTrinketCategory(itemID)
    local specFlag = self:GetSpecFlag(itemID)
    if specFlag then
        return self:GetCategory(specFlag)
    end
    return ""
end

--- Check if a class can use a trinket
-- @param itemID number - Item ID
-- @param classID number - Class ID (1-13)
-- @return boolean - True if class can use the trinket
function TrinketData:CanClassUse(itemID, classID)
    local specFlag = self:GetSpecFlag(itemID)
    if not specFlag then
        return true -- Unknown trinket, don't restrict
    end

    -- Get the hex digit for this class (spec flag is reversed)
    local position = NUM_CLASSES - classID + 1
    local hexDigit = specFlag:sub(position, position)

    -- If hex digit is not "0", at least one spec can use it
    return hexDigit ~= "0"
end

--- Check if a specific spec can use a trinket
-- @param itemID number - Item ID
-- @param classID number - Class ID (1-13)
-- @param specIndex number - Spec index (1-4)
-- @return boolean - True if spec can use the trinket
function TrinketData:CanSpecUse(itemID, classID, specIndex)
    local specFlag = self:GetSpecFlag(itemID)
    if not specFlag then
        return true -- Unknown trinket, don't restrict
    end

    -- Get the hex digit for this class
    local position = NUM_CLASSES - classID + 1
    local hexDigit = specFlag:sub(position, position)

    -- Convert hex to number
    local specBits = tonumber(hexDigit, 16)
    if not specBits then
        return true -- Invalid data, don't restrict
    end

    -- Check if spec bit is set
    local specBit = 2 ^ (specIndex - 1)
    return bit.band(specBits, specBit) > 0
end

--- Check if current player can use a trinket
-- @param itemID number - Item ID
-- @return boolean - True if player can use the trinket
function TrinketData:CanPlayerUse(itemID)
    -- Use SafeUnitClass to avoid secret value tainting
    local _, _, classID = Loolib.SecretUtil.SafeUnitClass("player")
    local specIndex = GetSpecialization and GetSpecialization()

    if not classID or not specIndex then
        return true -- Can't determine, don't restrict
    end

    return self:CanSpecUse(itemID, classID, specIndex)
end

--- Check if player should auto-pass a trinket
-- @param itemID number - Item ID
-- @return boolean, string - shouldAutoPass, reason
function TrinketData:ShouldAutoPass(itemID)
    if not self:IsTrinket(itemID) then
        return false, nil
    end

    if not self:CanPlayerUse(itemID) then
        local category = self:GetTrinketCategory(itemID)
        local reason = "Trinket restricted to: " .. (category ~= "" and category or "other specs")
        return true, reason
    end

    return false, nil
end

--- Get all specs that can use a trinket
-- @param itemID number - Item ID
-- @return table - Array of { classID, specIndex, className, specName }
function TrinketData:GetUsableSpecs(itemID)
    local specFlag = self:GetSpecFlag(itemID)
    local result = {}

    if not specFlag then
        return result
    end

    for classID = 1, NUM_CLASSES do
        local position = NUM_CLASSES - classID + 1
        local hexDigit = specFlag:sub(position, position)
        local specBits = tonumber(hexDigit, 16)

        if specBits and specBits > 0 then
            local classInfo = C_CreatureInfo.GetClassInfo(classID)
            local numSpecs = C_SpecializationInfo.GetNumSpecializationsForClassID(classID)

            for specIndex = 1, numSpecs do
                local specBit = 2 ^ (specIndex - 1)
                if bit.band(specBits, specBit) > 0 then
                    local specName
                    if GetSpecializationInfoForClassID then
                        _, specName = GetSpecializationInfoForClassID(classID, specIndex)
                    end
                    result[#result + 1] = {
                        classID = classID,
                        specIndex = specIndex,
                        className = classInfo and classInfo.className or "Unknown",
                        specName = specName or "Unknown",
                    }
                end
            end
        end
    end

    return result
end

--[[--------------------------------------------------------------------
    Initialize class-specific categories
----------------------------------------------------------------------]]

local function InitClassCategories()
    for classID = 1, NUM_CLASSES do
        local classInfo = C_CreatureInfo.GetClassInfo(classID)
        if classInfo then
            local numSpecs = C_SpecializationInfo.GetNumSpecializationsForClassID(classID)
            local digit = 0
            for specIndex = 1, numSpecs do
                digit = digit + 2 ^ (specIndex - 1)
            end

            local flag = string.rep("0", NUM_CLASSES - classID)
                .. string.format("%X", digit)
                .. string.rep("0", classID - 1)

            Loothing.TrinketCategories[flag] = classInfo.className
        end
    end
end

-- Initialize on load
C_Timer.After(0, InitClassCategories)
