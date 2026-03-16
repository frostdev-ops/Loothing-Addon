--[[--------------------------------------------------------------------
    Loothing - Loot Council Addon for WoW 12.0+
    ItemFilter - Item filtering logic for ignore list
----------------------------------------------------------------------]]

local ADDON_NAME, ns = ...
local Loolib = LibStub("Loolib")
local Loothing = ns.Addon
local L = ns.Locale
local Utils = ns.Utils

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
    ItemFilterMixin
----------------------------------------------------------------------]]

ns.ItemFilterMixin = ns.ItemFilterMixin or {}
local ItemFilterMixin = ns.ItemFilterMixin

--- Initialize the item filter
function ItemFilterMixin:Init()
    -- Nothing to initialize currently
end

--- Check if an item should be ignored
-- @param itemLink string - Full item link
-- @return boolean - True if item should be ignored
-- @return string|nil - Reason for ignoring (for debugging)
function ItemFilterMixin:ShouldIgnoreItem(itemLink)
    if not itemLink then
        return false
    end

    -- Check if ignore system is enabled
    if not Loothing.Settings:GetIgnoreItemsEnabled() then
        return false
    end

    local itemID = Utils.GetItemID(itemLink)
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
function ItemFilterMixin:GetItemCategory(itemLink)
    if not itemLink then
        return nil
    end

    local _, _, _, _, _, _, _, _, _, _, _, classID, subclassID = C_Item.GetItemInfo(itemLink)
    if not classID then
        return nil
    end

    -- Consumables
    if classID == ITEM_CLASS_CONSUMABLE then
        return L["ITEM_CATEGORY_CONSUMABLE"]
    end

    -- Trade Goods
    if classID == ITEM_CLASS_TRADE_GOODS then
        if subclassID == TRADE_GOODS_ENCHANTING then
            return L["ITEM_CATEGORY_ENCHANTING"]
        elseif subclassID == TRADE_GOODS_REAGENT or subclassID == TRADE_GOODS_OPTIONAL_REAGENT then
            return L["ITEM_CATEGORY_CRAFTING"]
        else
            return L["ITEM_CATEGORY_TRADE_GOODS"]
        end
    end

    -- Gems
    if classID == ITEM_CLASS_GEM then
        return L["ITEM_CATEGORY_GEM"]
    end

    return nil
end

--[[--------------------------------------------------------------------
    Module Export
----------------------------------------------------------------------]]

--- Create a new ItemFilter instance
-- @return table - ItemFilter instance
ns.CreateItemFilter = ns.CreateItemFilter or function()
    return Loolib.CreateFromMixins(ItemFilterMixin)
end
