--[[--------------------------------------------------------------------
    Loothing - Loot Council Addon for WoW 12.0+
    AutoPass - Automatic pass logic for unusable items

    Based on RCLootCouncil's autopass system with armor/weapon tables
----------------------------------------------------------------------]]

local Loolib = LibStub("Loolib")

LoothingAutoPass = {}

--[[--------------------------------------------------------------------
    Armor Type Tables

    Lists classes that should auto-pass on each armor subtype
----------------------------------------------------------------------]]

LoothingAutoPass.armorAutoPass = {
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

LoothingAutoPass.weaponAutoPass = {
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

LoothingAutoPass.requiredWeaponStats = {
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
    Armor types that should never be auto-passed
    (e.g., cloaks, rings, trinkets are usable by all classes)
----------------------------------------------------------------------]]

LoothingAutoPass.autopassOverride = {
    "INVTYPE_CLOAK",
    "INVTYPE_FINGER",
    "INVTYPE_TRINKET",
    "INVTYPE_NECK",
}

--[[--------------------------------------------------------------------
    Core Auto-Pass Logic
----------------------------------------------------------------------]]

--- Check if a weapon should be auto-passed based on primary stats
-- @param itemLink string - Item link to check
-- @param playerClass string - Class file (e.g., "WARRIOR")
-- @return boolean - True if should auto-pass
function LoothingAutoPass:ShouldAutoPassWeapon(itemLink, playerClass)
    if not itemLink or not playerClass then
        return false
    end

    local requiredStats = self.requiredWeaponStats[playerClass]
    if not requiredStats then
        return false
    end

    -- Get item stats
    local stats = C_Item.GetItemStats(itemLink)
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
-- @return boolean - True if should auto-pass
function LoothingAutoPass:ShouldAutoPass(itemLink, playerClass)
    if not itemLink then
        return false
    end

    -- Check master toggle
    if Loothing.Settings and not Loothing.Settings:GetAutoPassEnabled() then
        return false
    end

    -- Default to player's class
    if not playerClass then
        local _, class = UnitClass("player")
        playerClass = class
    end

    -- Get item info
    local itemID = LoothingUtils.GetItemID(itemLink)
    if not itemID then
        return false
    end

    local name, _, quality, itemLevel, reqLevel, classID, subclassID,
          maxStack, equipSlot, texture = C_Item.GetItemInfo(itemLink)

    if not name then
        -- Item not cached yet, don't auto-pass
        return false
    end

    -- Check if this is an override slot (never auto-pass)
    if equipSlot and tContains(self.autopassOverride, equipSlot) then
        return false
    end

    -- Check armor types
    if classID == Enum.ItemClass.Armor then
        local autoPassList = self.armorAutoPass[subclassID]
        if autoPassList and tContains(autoPassList, playerClass) then
            return true
        end
    end

    -- Check weapon types
    if classID == Enum.ItemClass.Weapon then
        -- First check if weapon type is usable
        local autoPassList = self.weaponAutoPass[subclassID]
        if autoPassList and tContains(autoPassList, playerClass) then
            return true
        end

        -- Then check weapon stats (for classes that can equip but wrong stats)
        -- Only check stats if weapon setting is enabled
        if Loothing.Settings and Loothing.Settings:GetAutoPassWeapons() then
            if self:ShouldAutoPassWeapon(itemLink, playerClass) then
                return true
            end
        end
    end

    -- Check BoE items
    if Loothing.Settings and Loothing.Settings:GetAutoPassBoE() then
        local isBound = C_Item.IsBound(itemLink)
        local bindType = select(14, C_Item.GetItemInfo(itemLink))
        -- bindType 2 = Bind on Equip, 3 = Bind on Use
        if not isBound and bindType == 2 then
            return true
        end
    end

    -- Check transmog (if appearance is already known)
    if Loothing.Settings and Loothing.Settings:GetAutoPassTransmog() then
        -- Check if item is transmoggable
        if C_TransmogCollection and C_Item.IsDressableItemByID then
            local canBeTransmogged = C_Item.IsDressableItemByID(itemID)
            if canBeTransmogged then
                local _, appearanceID = C_TransmogCollection.GetItemInfo(itemLink)
                if appearanceID then
                    local sourceInfo = C_TransmogCollection.GetSourceInfo(appearanceID)
                    if sourceInfo and sourceInfo.isCollected then
                        return true
                    end
                end
            end
        end
    end

    return false
end

--- Get the reason why an item should be auto-passed
-- @param itemLink string - Item link to check
-- @param playerClass string - Optional class file (defaults to player's class)
-- @return string|nil - Reason text, or nil if shouldn't auto-pass
function LoothingAutoPass:GetAutoPassReason(itemLink, playerClass)
    if not self:ShouldAutoPass(itemLink, playerClass) then
        return nil
    end

    -- Default to player's class
    if not playerClass then
        local _, class = UnitClass("player")
        playerClass = class
    end

    local name, _, quality, itemLevel, reqLevel, classID, subclassID,
          maxStack, equipSlot, texture = C_Item.GetItemInfo(itemLink)

    if not name then
        return "Unknown item"
    end

    -- Check armor
    if classID == Enum.ItemClass.Armor then
        local armorTypeName = GetItemSubClassInfo(classID, subclassID)
        return string.format("Cannot wear %s armor", armorTypeName or "this")
    end

    -- Check weapon type
    if classID == Enum.ItemClass.Weapon then
        local autoPassList = self.weaponAutoPass[subclassID]
        if autoPassList and tContains(autoPassList, playerClass) then
            local weaponTypeName = GetItemSubClassInfo(classID, subclassID)
            return string.format("Cannot equip %s", weaponTypeName or "this weapon")
        end

        -- Check weapon stats
        if Loothing.Settings and Loothing.Settings:GetAutoPassWeapons() then
            if self:ShouldAutoPassWeapon(itemLink, playerClass) then
                return "Wrong primary stats for class"
            end
        end
    end

    -- Check BoE
    if Loothing.Settings and Loothing.Settings:GetAutoPassBoE() then
        local isBound = C_Item.IsBound(itemLink)
        local bindType = select(14, C_Item.GetItemInfo(itemLink))
        if not isBound and bindType == 2 then
            return "Bind-on-Equip item (can be sold/traded)"
        end
    end

    -- Check transmog
    if Loothing.Settings and Loothing.Settings:GetAutoPassTransmog() then
        local itemID = LoothingUtils.GetItemID(itemLink)
        if itemID and C_TransmogCollection and C_Item.IsDressableItemByID then
            local canBeTransmogged = C_Item.IsDressableItemByID(itemID)
            if canBeTransmogged then
                local _, appearanceID = C_TransmogCollection.GetItemInfo(itemLink)
                if appearanceID then
                    local sourceInfo = C_TransmogCollection.GetSourceInfo(appearanceID)
                    if sourceInfo and sourceInfo.isCollected then
                        return "Transmog appearance already known"
                    end
                end
            end
        end
    end

    return "Cannot use this item"
end

--[[--------------------------------------------------------------------
    Integration Helpers
----------------------------------------------------------------------]]

--- Check if player should auto-pass on an item and optionally show reason
-- @param item table - LoothingItem instance
-- @return boolean - True if should auto-pass
function LoothingAutoPass:CheckItem(item)
    if not item or not item.itemLink then
        return false
    end

    local shouldPass = self:ShouldAutoPass(item.itemLink)

    if shouldPass then
        local reason = self:GetAutoPassReason(item.itemLink)
        Loothing:Debug("Auto-pass:", item.name, "-", reason)
    end

    return shouldPass
end
