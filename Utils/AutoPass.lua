--[[--------------------------------------------------------------------
    Loothing - Loot Council Addon for WoW 12.0+
    AutoPass - Automatic pass logic for unusable items

    Based on RCLootCouncil's autopass system with:
    - Armor/weapon type tables
    - Weapon stat checks
    - Trinket spec filtering (via TrinketData)
    - Class restriction parsing from item tooltips
    - Transmog source checking (known appearances)
    - Bitwise class flag system
----------------------------------------------------------------------]]

local _, ns = ...
local Loolib = LibStub("Loolib")
local Loothing = ns.Addon
local Utils = ns.Utils
local TrinketData = ns.TrinketData

local AutoPass = {}
ns.AutoPass = AutoPass

--[[--------------------------------------------------------------------
    Class ID Lookup

    Used for bitwise class flag operations.
    Class flags use bit N for classID N (bit 1 = Warrior, bit 2 = Paladin, etc.)
----------------------------------------------------------------------]]

local CLASS_NAME_TO_ID = {
    WARRIOR = 1,
    PALADIN = 2,
    HUNTER = 3,
    ROGUE = 4,
    PRIEST = 5,
    DEATHKNIGHT = 6,
    SHAMAN = 7,
    MAGE = 8,
    WARLOCK = 9,
    MONK = 10,
    DRUID = 11,
    DEMONHUNTER = 12,
    EVOKER = 13,
}

local CLASS_ID_TO_NAME = {}
for name, id in pairs(CLASS_NAME_TO_ID) do
    CLASS_ID_TO_NAME[id] = name
end

-- All classes flag - computed from CLASS_ID_TO_NAME to auto-adjust when new classes are added
-- (CLASS_ID_TO_NAME has sequential integer keys 1..N, so # works correctly)
local ALL_CLASSES_FLAG = bit.lshift(1, #CLASS_ID_TO_NAME) - 1

--[[--------------------------------------------------------------------
    Armor Type Tables

    Lists classes that should auto-pass on each armor subtype
----------------------------------------------------------------------]]

AutoPass.armorAutoPass = {
    -- Cloth - Everyone except Cloth wearers (Priest, Mage, Warlock)
    [Enum.ItemArmorSubclass.Cloth] = {
        "WARRIOR", "DEATHKNIGHT", "PALADIN", "DRUID", "MONK", "ROGUE",
        "HUNTER", "SHAMAN", "DEMONHUNTER", "EVOKER"
    },

    -- Leather - Everyone except Leather wearers (Druid, Monk, Rogue, Demon Hunter)
    [Enum.ItemArmorSubclass.Leather] = {
        "WARRIOR", "DEATHKNIGHT", "PALADIN", "HUNTER", "SHAMAN",
        "PRIEST", "MAGE", "WARLOCK", "EVOKER"
    },

    -- Mail - Everyone except Mail wearers (Hunter, Shaman, Evoker)
    [Enum.ItemArmorSubclass.Mail] = {
        "WARRIOR", "DEATHKNIGHT", "PALADIN", "DRUID", "MONK", "ROGUE",
        "PRIEST", "MAGE", "WARLOCK", "DEMONHUNTER"
    },

    -- Plate - Everyone except Plate wearers (Warrior, Paladin, Death Knight)
    [Enum.ItemArmorSubclass.Plate] = {
        "DRUID", "MONK", "ROGUE", "HUNTER", "SHAMAN", "PRIEST",
        "MAGE", "WARLOCK", "DEMONHUNTER", "EVOKER"
    },

    -- Shield - Classes that cannot use shields
    [Enum.ItemArmorSubclass.Shield] = {
        "DEATHKNIGHT", "DRUID", "MONK", "ROGUE", "HUNTER", "PRIEST",
        "MAGE", "WARLOCK", "DEMONHUNTER", "EVOKER"
    },
}

--[[--------------------------------------------------------------------
    Weapon Type Tables

    Lists classes that should auto-pass on each weapon subtype
----------------------------------------------------------------------]]

AutoPass.weaponAutoPass = {
    -- One-Hand Axes
    [Enum.ItemWeaponSubclass.Axe1H] = {
        "DRUID", "PRIEST", "MAGE", "WARLOCK"
    },

    -- Two-Hand Axes
    [Enum.ItemWeaponSubclass.Axe2H] = {
        "DRUID", "ROGUE", "MONK", "PRIEST", "MAGE", "WARLOCK",
        "DEMONHUNTER", "EVOKER"
    },

    -- Bows
    [Enum.ItemWeaponSubclass.Bows] = {
        "DEATHKNIGHT", "PALADIN", "DRUID", "MONK", "SHAMAN", "PRIEST",
        "MAGE", "WARLOCK", "DEMONHUNTER", "WARRIOR", "EVOKER"
    },

    -- Crossbows
    [Enum.ItemWeaponSubclass.Crossbow] = {
        "DEATHKNIGHT", "PALADIN", "DRUID", "MONK", "SHAMAN", "PRIEST",
        "MAGE", "WARLOCK", "DEMONHUNTER", "WARRIOR", "EVOKER"
    },

    -- Daggers
    [Enum.ItemWeaponSubclass.Dagger] = {
        "DEATHKNIGHT", "PALADIN", "MONK", "DEMONHUNTER"
    },

    -- Guns
    [Enum.ItemWeaponSubclass.Guns] = {
        "DEATHKNIGHT", "PALADIN", "DRUID", "MONK", "SHAMAN", "PRIEST",
        "MAGE", "WARLOCK", "DEMONHUNTER", "WARRIOR", "EVOKER"
    },

    -- One-Hand Maces
    [Enum.ItemWeaponSubclass.Mace1H] = {
        "HUNTER", "MAGE", "WARLOCK", "DEMONHUNTER"
    },

    -- Two-Hand Maces
    [Enum.ItemWeaponSubclass.Mace2H] = {
        "MONK", "ROGUE", "HUNTER", "PRIEST", "MAGE", "WARLOCK", "DEMONHUNTER"
    },

    -- Polearms
    [Enum.ItemWeaponSubclass.Polearm] = {
        "ROGUE", "SHAMAN", "PRIEST", "MAGE", "WARLOCK", "DEMONHUNTER", "EVOKER"
    },

    -- One-Hand Swords
    [Enum.ItemWeaponSubclass.Sword1H] = {
        "DRUID", "SHAMAN", "PRIEST"
    },

    -- Two-Hand Swords
    [Enum.ItemWeaponSubclass.Sword2H] = {
        "DRUID", "MONK", "ROGUE", "SHAMAN", "PRIEST", "MAGE",
        "WARLOCK", "DEMONHUNTER", "EVOKER"
    },

    -- Staves
    [Enum.ItemWeaponSubclass.Staff] = {
        "DEATHKNIGHT", "PALADIN", "ROGUE", "DEMONHUNTER"
    },

    -- Wands
    [Enum.ItemWeaponSubclass.Wand] = {
        "WARRIOR", "DEATHKNIGHT", "PALADIN", "DRUID", "MONK", "ROGUE",
        "HUNTER", "SHAMAN", "DEMONHUNTER", "EVOKER"
    },

    -- Warglaives
    [Enum.ItemWeaponSubclass.Warglaive] = {
        "WARRIOR", "DEATHKNIGHT", "PALADIN", "DRUID", "MONK", "ROGUE",
        "PRIEST", "MAGE", "WARLOCK", "HUNTER", "SHAMAN", "EVOKER"
    },

    -- Fist Weapons
    [Enum.ItemWeaponSubclass.Unarmed] = {
        "DEATHKNIGHT", "PALADIN", "PRIEST", "MAGE", "WARLOCK"
    },
}

--[[--------------------------------------------------------------------
    Required Weapon Stats by Class

    Maps each class to the main stats they need on weapons
----------------------------------------------------------------------]]

AutoPass.requiredWeaponStats = {
    WARRIOR = { "ITEM_MOD_STRENGTH_SHORT" },
    PALADIN = { "ITEM_MOD_STRENGTH_SHORT", "ITEM_MOD_INTELLECT_SHORT" },
    HUNTER = { "ITEM_MOD_AGILITY_SHORT" },
    ROGUE = { "ITEM_MOD_AGILITY_SHORT" },
    PRIEST = { "ITEM_MOD_INTELLECT_SHORT" },
    DEATHKNIGHT = { "ITEM_MOD_STRENGTH_SHORT" },
    SHAMAN = { "ITEM_MOD_INTELLECT_SHORT", "ITEM_MOD_AGILITY_SHORT" },
    MAGE = { "ITEM_MOD_INTELLECT_SHORT" },
    WARLOCK = { "ITEM_MOD_INTELLECT_SHORT" },
    MONK = { "ITEM_MOD_INTELLECT_SHORT", "ITEM_MOD_AGILITY_SHORT" },
    DRUID = { "ITEM_MOD_INTELLECT_SHORT", "ITEM_MOD_AGILITY_SHORT" },
    DEMONHUNTER = { "ITEM_MOD_AGILITY_SHORT" },
    EVOKER = { "ITEM_MOD_INTELLECT_SHORT" },
}

--[[--------------------------------------------------------------------
    Autopass Override Slots (never auto-pass these equip locations)
----------------------------------------------------------------------]]

AutoPass.autopassOverride = {
    "INVTYPE_CLOAK",
    "INVTYPE_FINGER",
    "INVTYPE_TRINKET",
    "INVTYPE_NECK",
}

--[[--------------------------------------------------------------------
    Bitwise Class Flag System

    Used to encode which classes can use an item. Bit N = class ID N.
    Parse from tooltip "Classes: Warrior, Mage, ..." line.
----------------------------------------------------------------------]]

--- Parse class restriction from an item's tooltip
-- Scans tooltip for "Classes: ..." line and returns a bitwise flag
-- @param itemLink string - Item link
-- @return number - Bitwise class flag (ALL_CLASSES_FLAG if no restriction)
function AutoPass:GetItemClassesAllowedFlag(itemLink)
    if not itemLink then return ALL_CLASSES_FLAG end

    -- Create a scanning tooltip
    local tooltipName = "LoothingAutoPassTooltip"
    local tooltip = _G[tooltipName]
    if not tooltip then
        tooltip = CreateFrame("GameTooltip", tooltipName, nil, "GameTooltipTemplate")
        tooltip:SetOwner(WorldFrame, "ANCHOR_NONE")
    end

    tooltip:ClearLines()
    tooltip:SetHyperlink(itemLink)

    -- Scan tooltip lines for "Classes: ..." pattern
    local numLines = tooltip:NumLines()
    for i = 1, numLines do
        local textObj = _G[tooltipName .. "TextLeft" .. i]
        if textObj then
            local text = textObj:GetText()
            if text then
                -- Match "Classes: Warrior, Mage, Paladin"
                -- Use plain string find() to avoid pattern-special characters in ITEM_CLASSES_ALLOWED
                local classList
                if ITEM_CLASSES_ALLOWED then
                    local startPos, endPos = text:find(ITEM_CLASSES_ALLOWED, 1, true)
                    if startPos == 1 then
                        classList = text:sub(endPos + 1):match("^:%s*(.+)$")
                    end
                end
                if not classList then
                    -- Fallback: try English pattern
                    classList = text:match("^Classes:%s*(.+)$")
                end

                if classList then
                    local flag = 0
                    -- Parse each class name
                    for className in classList:gmatch("[^,]+") do
                        className = strtrim(className)
                        -- Look up class ID by localized name
                        for classFile, classID in pairs(CLASS_NAME_TO_ID) do
                            local localizedName = LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[classFile]
                            if localizedName and localizedName == className then
                                flag = bit.bor(flag, bit.lshift(1, classID - 1))
                                break
                            end
                            -- Also check English class file name
                            if classFile:lower() == className:lower() then
                                flag = bit.bor(flag, bit.lshift(1, classID - 1))
                                break
                            end
                        end
                    end

                    if flag > 0 then
                        return flag
                    end
                end
            end
        end
    end

    return ALL_CLASSES_FLAG
end

--- Check if a class is allowed by a class flag
-- @param classesFlag number - Bitwise class flag
-- @param playerClass string - Class file name (e.g., "WARRIOR")
-- @return boolean - True if class is allowed
function AutoPass:IsClassAllowed(classesFlag, playerClass)
    if not classesFlag or classesFlag == ALL_CLASSES_FLAG then
        return true
    end

    local classID = CLASS_NAME_TO_ID[playerClass]
    if not classID then return true end

    return bit.band(classesFlag, bit.lshift(1, classID - 1)) > 0
end

--[[--------------------------------------------------------------------
    Transmog Source Checking

    Checks if the player already knows an item's appearance, and
    whether the item is even learnable by the player's class/race.
----------------------------------------------------------------------]]

--- Check if item appearance is already known by the player
-- @param itemLink string - Item link
-- @param itemID number|nil - Item ID (optional, extracted from link if nil)
-- @return boolean - True if appearance is already collected
function AutoPass:IsTransmogKnown(itemLink, itemID)
    if not C_TransmogCollection then return false end

    itemID = itemID or Utils.GetItemID(itemLink)
    if not itemID then return false end

    -- Check via PlayerKnowsTransmogFromItem (most reliable)
    if C_TransmogCollection.PlayerKnowsTransmogFromItem then
        return C_TransmogCollection.PlayerKnowsTransmogFromItem(itemID)
    end

    -- Fallback: use appearance/source info
    if C_TransmogCollection.GetItemInfo then
        local _, appearanceID = C_TransmogCollection.GetItemInfo(itemLink)
        if appearanceID then
            local sourceInfo = C_TransmogCollection.GetSourceInfo(appearanceID)
            if sourceInfo and sourceInfo.isCollected then
                return true
            end
        end
    end

    return false
end

--- Check if item appearance is learnable by the player
-- @param itemLink string - Item link
-- @param itemID number|nil - Item ID
-- @return boolean - True if the player can learn this appearance
function AutoPass:IsTransmogLearnable(itemLink, itemID)
    if not C_TransmogCollection then return false end

    itemID = itemID or Utils.GetItemID(itemLink)
    if not itemID then return false end

    -- Check if item is dressable (can be transmogged)
    if C_Item.IsDressableItemByID then
        if not C_Item.IsDressableItemByID(itemID) then
            return false
        end
    end

    -- Check if player can collect this appearance
    if C_TransmogCollection.PlayerCanCollectSource then
        local _, appearanceID = C_TransmogCollection.GetItemInfo(itemLink)
        if appearanceID then
            return C_TransmogCollection.PlayerCanCollectSource(appearanceID)
        end
    end

    return true
end

--[[--------------------------------------------------------------------
    Core Auto-Pass Logic
----------------------------------------------------------------------]]

--- Check if a weapon should be auto-passed based on primary stats
-- @param itemLink string - Item link to check
-- @param playerClass string - Class file (e.g., "WARRIOR")
-- @return boolean - True if should auto-pass
function AutoPass:ShouldAutoPassWeapon(itemLink, playerClass)
    if not itemLink or not playerClass then
        return false
    end

    local requiredStats = self.requiredWeaponStats[playerClass]
    if not requiredStats then
        return false
    end

    local getItemStats = C_Item.GetItemStats
    if not getItemStats then return false end
    local stats = getItemStats(itemLink)
    if not stats then
        -- Item not loaded yet, don't auto-pass
        return false
    end

    -- Check if item has any main stat
    local hasMainStat = stats.ITEM_MOD_STRENGTH_SHORT or
                        stats.ITEM_MOD_AGILITY_SHORT or
                        stats.ITEM_MOD_INTELLECT_SHORT

    if not hasMainStat then
        -- No main stat means it's usable by all (e.g., stat-stick)
        return false
    end

    -- Check if item has any of the required stats for this class
    for _, stat in ipairs(requiredStats) do
        if stats[stat] then
            -- Item has a required stat, don't auto-pass
            return false
        end
    end

    -- Item has main stats but not the right ones for this class
    return true
end

--- Check if an item should be auto-passed
-- @param itemLink string - Item link to check
-- @param playerClass string - Optional class file (defaults to player's class)
-- @param classesFlag number|nil - Bitwise class flag (optional, parsed from tooltip if nil)
-- @return boolean, string|nil - shouldAutoPass, reason
function AutoPass:ShouldAutoPass(itemLink, playerClass, classesFlag)
    if not itemLink then
        return false, nil
    end

    -- Check master toggle
    if Loothing.Settings and not Loothing.Settings:GetAutoPassEnabled() then
        return false, nil
    end

    -- Default to player's class
    if not playerClass then
        -- FIX(Area4-4): Use SafeUnitClass to avoid secret value tainting
        local _, class = Loolib.SecretUtil.SafeUnitClass("player")
        playerClass = class
    end

    -- Get item info
    local itemID = Utils.GetItemID(itemLink)
    if not itemID then
        return false, nil
    end

    -- GetItemInfo returns: name, link, quality, ilvl, reqLevel, classStr, subclassStr,
    -- maxStack, equipSlot, texture, vendorPrice, typeID, subTypeID, bindType
    local name, _, _, _, _, _, _,
          _, equipSlot, _, _, classID, subclassID, _ = C_Item.GetItemInfo(itemLink)

    if not name then
        -- Item not cached yet, don't auto-pass
        return false, nil
    end

    -- Check if this is an override slot (never auto-pass)
    if equipSlot and tContains(self.autopassOverride, equipSlot) then
        -- Exception: trinkets still get checked for spec filtering
        if equipSlot == "INVTYPE_TRINKET" then
            return self:ShouldAutoPassTrinket(itemID, playerClass)
        end
        return false, nil
    end

    -- Check class restrictions from tooltip (bitwise class flag)
    if classesFlag and classesFlag ~= ALL_CLASSES_FLAG then
        if not self:IsClassAllowed(classesFlag, playerClass) then
            return true, "Class restricted item"
        end
    else
        -- Parse class flag from tooltip if not provided
        local parsedFlag = self:GetItemClassesAllowedFlag(itemLink)
        if parsedFlag ~= ALL_CLASSES_FLAG then
            if not self:IsClassAllowed(parsedFlag, playerClass) then
                return true, "Class restricted item"
            end
        end
    end

    -- Check armor types
    if classID == Enum.ItemClass.Armor then
        local autoPassList = self.armorAutoPass[subclassID]
        if autoPassList and tContains(autoPassList, playerClass) then
            -- Before auto-passing armor, check if transmog setting keeps it
            if self:ShouldKeepForTransmog(itemLink, itemID) then
                return false, nil
            end
            local armorTypeName = C_Item.GetItemSubClassInfo(classID, subclassID)
            return true, string.format("Cannot wear %s armor", armorTypeName or "this")
        end
    end

    -- Check weapon types
    if classID == Enum.ItemClass.Weapon then
        -- First check if weapon type is usable
        local autoPassList = self.weaponAutoPass[subclassID]
        if autoPassList and tContains(autoPassList, playerClass) then
            -- Before auto-passing weapon, check if transmog setting keeps it
            if self:ShouldKeepForTransmog(itemLink, itemID) then
                return false, nil
            end
            local weaponTypeName = C_Item.GetItemSubClassInfo(classID, subclassID)
            return true, string.format("Cannot equip %s", weaponTypeName or "this weapon")
        end

        -- Then check weapon stats (for classes that can equip but wrong stats)
        if Loothing.Settings and Loothing.Settings:GetAutoPassWeapons() then
            if self:ShouldAutoPassWeapon(itemLink, playerClass) then
                return true, "Wrong primary stats for class"
            end
        end
    end

    -- Check trinket spec filtering
    if equipSlot == "INVTYPE_TRINKET" then
        local pass, reason = self:ShouldAutoPassTrinket(itemID, playerClass)
        if pass then
            return true, reason
        end
    end

    -- Check BoE items
    if Loothing.Settings and Loothing.Settings:GetAutoPassBoE() then
        local itemBindType = select(14, C_Item.GetItemInfo(itemLink))
        -- itemBindType 2 = Bind on Equip
        if itemBindType == 2 then
            return true, "Bind-on-Equip item (can be sold/traded)"
        end
    end

    -- Check transmog (if appearance is already known)
    if Loothing.Settings and Loothing.Settings:GetAutoPassTransmog() then
        if self:IsTransmogKnown(itemLink, itemID) then
            return true, "Transmog appearance already known"
        end
    end

    return false, nil
end

--[[--------------------------------------------------------------------
    Trinket Auto-Pass (uses TrinketData)
----------------------------------------------------------------------]]

--- Check if a trinket should be auto-passed based on spec restrictions
-- @param itemID number - Item ID
-- @param playerClass string - Class file (e.g., "WARRIOR")
-- @return boolean, string|nil - shouldAutoPass, reason
function AutoPass:ShouldAutoPassTrinket(itemID, _playerClass)
    if not Loothing.Settings or not Loothing.Settings:Get("autoPass.trinkets", false) then
        return false, nil
    end

    if not TrinketData then
        return false, nil
    end

    local shouldPass, reason = TrinketData:ShouldAutoPass(itemID)
    return shouldPass, reason
end

--[[--------------------------------------------------------------------
    Transmog Keep Check

    If the player has transmog source checking enabled, items that
    have an unknown appearance are kept even if the player can't equip them.
----------------------------------------------------------------------]]

--- Check if an item should be kept for transmog (unknown appearance)
-- @param itemLink string
-- @param itemID number|nil
-- @return boolean - True if item should be kept for transmog collection
function AutoPass:ShouldKeepForTransmog(itemLink, itemID)
    if not Loothing.Settings then return false end

    -- Check if transmog source setting is enabled
    if not Loothing.Settings:Get("autoPass.transmogSource", false) then
        return false
    end

    itemID = itemID or Utils.GetItemID(itemLink)
    if not itemID then return false end

    -- If appearance is unknown and learnable, keep it
    if not self:IsTransmogKnown(itemLink, itemID) then
        if self:IsTransmogLearnable(itemLink, itemID) then
            return true
        end
    end

    return false
end

--[[--------------------------------------------------------------------
    Legacy API (backwards compatible)
----------------------------------------------------------------------]]

--- Get the reason why an item should be auto-passed
-- @param itemLink string - Item link to check
-- @param playerClass string - Optional class file (defaults to player's class)
-- @return string|nil - Reason text, or nil if shouldn't auto-pass
function AutoPass:GetAutoPassReason(itemLink, playerClass)
    local _, reason = self:ShouldAutoPass(itemLink, playerClass)
    return reason
end

--[[--------------------------------------------------------------------
    Integration Helpers
----------------------------------------------------------------------]]

--- Check if player should auto-pass on an item and optionally show reason
-- @param item table - LoothingItem instance
-- @return boolean - True if should auto-pass
function AutoPass:CheckItem(item)
    if not item or not item.itemLink then
        return false
    end

    local shouldPass, reason = self:ShouldAutoPass(item.itemLink, nil, item.classesFlag)

    if shouldPass then
        Loothing:Debug("Auto-pass:", item.name, "-", reason)
    end

    return shouldPass
end

--- Get the bitwise class flag for an item
-- @param itemLink string
-- @return number - Bitwise class flag
function AutoPass:GetClassesFlag(itemLink)
    return self:GetItemClassesAllowedFlag(itemLink)
end

-- Export constants
AutoPass.ALL_CLASSES_FLAG = ALL_CLASSES_FLAG
AutoPass.CLASS_NAME_TO_ID = CLASS_NAME_TO_ID
AutoPass.CLASS_ID_TO_NAME = CLASS_ID_TO_NAME
