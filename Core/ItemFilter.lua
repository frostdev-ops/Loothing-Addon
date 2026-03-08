--[[--------------------------------------------------------------------
    Loothing - Loot Council Addon for WoW 12.0+
    ItemFilter - Item filtering logic for ignore list
----------------------------------------------------------------------]]

local Loolib = LibStub("Loolib")

--[[--------------------------------------------------------------------
    Item Type Constants
----------------------------------------------------------------------]]

-- Item class IDs (from Enum.ItemClass)
local ITEM_CLASS_CONSUMABLE = 0
local ITEM_CLASS_TRADE_GOODS = 7
local ITEM_CLASS_GEM = 3

-- Trade Goods subclass IDs
local TRADE_GOODS_ENCHANTING = 12  -- Enchanting materials
local TRADE_GOODS_OPTIONAL_REAGENT = 1  -- Optional crafting reagents
local TRADE_GOODS_REAGENT = 8  -- Crafting reagents

-- Gem subclass IDs
local GEM_SIMPLE = 0  -- Simple gems
local GEM_COGWHEEL = 6  -- Cogwheel gems
local GEM_META = 7  -- Meta gems

--[[--------------------------------------------------------------------
    LoothingItemFilterMixin
----------------------------------------------------------------------]]

LoothingItemFilterMixin = {}

--- Initialize the item filter
function LoothingItemFilterMixin:Init()
    -- Nothing to initialize currently
end

--- Check if an item should be ignored
-- @param itemLink string - Full item link
-- @return boolean - True if item should be ignored
-- @return string|nil - Reason for ignoring (for debugging)
function LoothingItemFilterMixin:ShouldIgnoreItem(itemLink)
    if not itemLink then
        return false
    end

    -- Check if ignore system is enabled
    if not Loothing.Settings:GetIgnoreItemsEnabled() then
        return false
    end

    local itemID = LoothingUtils.GetItemID(itemLink)
    if not itemID then
        return false
    end

    -- Check explicit ignore list first
    if Loothing.Settings:IsItemIgnored(itemID) then
        return true, "Explicitly ignored"
    end

    -- Get item info (single call - C_Item.GetItemInfo returns nil for uncached items)
    local itemName, itemLinkFull, itemQuality, itemLevel, itemMinLevel,
          itemType, itemSubType, itemStackCount, itemEquipLoc, iconFileDataID,
          sellPrice, classID, subclassID = C_Item.GetItemInfo(itemLink)

    if not classID then
        -- Item not cached yet, can't filter by category
        return false
    end

    -- Check consumables
    if Loothing.Settings:GetIgnoreConsumables() then
        if classID == ITEM_CLASS_CONSUMABLE then
            return true, "Consumable"
        end
    end

    -- Check enchanting materials
    if Loothing.Settings:GetIgnoreEnchantingMaterials() then
        if classID == ITEM_CLASS_TRADE_GOODS and subclassID == TRADE_GOODS_ENCHANTING then
            return true, "Enchanting material"
        end
    end

    -- Check crafting reagents
    if Loothing.Settings:GetIgnoreCraftingReagents() then
        if classID == ITEM_CLASS_TRADE_GOODS then
            if subclassID == TRADE_GOODS_REAGENT or subclassID == TRADE_GOODS_OPTIONAL_REAGENT then
                return true, "Crafting reagent"
            end
        end
    end

    -- Check permanent enhancements (gems, enchants)
    if Loothing.Settings:GetIgnorePermanentEnhancements() then
        if classID == ITEM_CLASS_GEM then
            return true, "Gem"
        end
    end

    return false
end

--- Get item category type for display
-- @param itemLink string - Full item link
-- @return string|nil - Category name or nil
function LoothingItemFilterMixin:GetItemCategory(itemLink)
    if not itemLink then
        return nil
    end

    local _, _, _, _, _, _, _, _, _, _, _, classID, subclassID = C_Item.GetItemInfo(itemLink)
    if not classID then
        return nil
    end

    -- Consumables
    if classID == ITEM_CLASS_CONSUMABLE then
        return "Consumable"
    end

    -- Trade Goods
    if classID == ITEM_CLASS_TRADE_GOODS then
        if subclassID == TRADE_GOODS_ENCHANTING then
            return "Enchanting Material"
        elseif subclassID == TRADE_GOODS_REAGENT or subclassID == TRADE_GOODS_OPTIONAL_REAGENT then
            return "Crafting Reagent"
        else
            return "Trade Goods"
        end
    end

    -- Gems
    if classID == ITEM_CLASS_GEM then
        return "Gem"
    end

    return nil
end

--[[--------------------------------------------------------------------
    Module Export
----------------------------------------------------------------------]]

--- Create a new ItemFilter instance
-- @return table - ItemFilter instance
function CreateLoothingItemFilter()
    return LoolibCreateFromMixins(LoothingItemFilterMixin)
end
