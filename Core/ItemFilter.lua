--[[--------------------------------------------------------------------
    Loothing - Loot Council Addon for WoW 12.0+
    ItemFilter - Item filtering logic for ignore list
----------------------------------------------------------------------]]

local _, ns = ...
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

    -- Fail-closed when Settings is missing: without it, the per-player
    -- ignore-list system is effectively disabled (we have no per-player
    -- preferences to consult), so return false. The class/quality fail-
    -- closed fallbacks in IsClassBlocked / IsBelowMinQuality still cover
    -- the gross cases when Settings is unavailable.
    if not Loothing.Settings then
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
    local _itemName, _itemLinkFull, _itemQuality, _itemLevel, _itemMinLevel,
          _itemType, _itemSubType, _itemStackCount, _itemEquipLoc, _iconFileDataID,
          _sellPrice, classID, subclassID = C_Item.GetItemInfo(itemLink)

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

--[[--------------------------------------------------------------------
    Class / quality filter (master-looter loot policy)

    These methods read the loot.filter.* settings (see
    Core/SettingsLootFilter.lua). They are independent of
    :ShouldIgnoreItem above, which handles the per-player ignore list.
----------------------------------------------------------------------]]

-- Localised display names for the user-blockable classes/subclasses.
-- Keyed by classID, with optional .subclasses[subID] specialisation
-- when a subclass-only block needs a more specific label than the
-- whole-class label. Falls back to L["LOOT_FILTER_BLOCK_*"] strings.
local function getCategoryLabel(classID, subclassID)
    if classID == nil then return nil end
    -- Subclass-specific overrides first
    if classID == 15 then
        if subclassID == 1 then return L["LOOT_FILTER_BLOCK_MISC_REAGENT"] or "Misc: Reagent" end
        if subclassID == 4 then return L["LOOT_FILTER_BLOCK_MISC_OTHER"]   or "Misc: Other" end
    end
    local labels = {
        [0]  = L["LOOT_FILTER_BLOCK_CONSUMABLES"] or "Consumable",
        [5]  = L["LOOT_FILTER_BLOCK_REAGENTS"]    or "Reagent",
        [7]  = L["LOOT_FILTER_BLOCK_TRADESKILL"]  or "Recipe",
        [12] = L["LOOT_FILTER_BLOCK_QUEST"]       or "Quest item",
        [20] = L["LOOT_FILTER_BLOCK_HOUSING"]     or "Housing / Decor",
    }
    return labels[classID]
end

--- True if the item's class/subclass is blocked by user settings.
-- Fail-closed: if Loothing.Settings is missing (Settings module didn't
-- load), fall back to the seed defaults exposed by SettingsLootFilter
-- so a broken Settings module can't silently disable class blocking.
-- @param itemLink string
-- @return boolean
-- @return string|nil - Category label (for UI hint), nil if not blocked
function ItemFilterMixin:IsClassBlocked(itemLink)
    if not itemLink then return false end
    local _, _, _, _, _, classID, subclassID = C_Item.GetItemInfoInstant(itemLink)
    if not classID then return false end

    if Loothing.Settings then
        if Loothing.Settings:IsLootFilterClassBlocked(classID) then
            return true, getCategoryLabel(classID, subclassID)
                or self:GetItemCategory(itemLink)
                or string.format("Class %d", classID)
        end
        if Loothing.Settings:IsLootFilterSubclassBlocked(classID, subclassID) then
            return true, getCategoryLabel(classID, subclassID)
                or self:GetItemCategory(itemLink)
                or string.format("Class %d / %d", classID, subclassID)
        end
        return false
    end

    -- Settings module unavailable — apply the static seed defaults so a
    -- broken Settings load can't silently let consumables/recipes through.
    local def = ns.LootFilterDefaults and ns.LootFilterDefaults.classes
    if def then
        local entry = def[classID]
        if entry then
            if entry.all == true then
                return true, getCategoryLabel(classID, subclassID)
                    or string.format("Class %d", classID)
            end
            if subclassID and entry[subclassID] == true then
                return true, getCategoryLabel(classID, subclassID)
                    or string.format("Class %d / %d", classID, subclassID)
            end
        end
    end
    return false
end

--- True if the item's quality is below the configured minimum.
-- Fail-closed: when Loothing.Settings is missing, fall back to the
-- legacy `Loothing.MinQuality` constant (EPIC) instead of disabling
-- the gate. Matches the seed-defaults fallback in IsClassBlocked.
-- @param itemLink string
-- @return boolean
-- @return number|nil - actual quality
-- @return number    - configured minimum
function ItemFilterMixin:IsBelowMinQuality(itemLink)
    local minQ
    if Loothing.Settings then
        minQ = Loothing.Settings:GetLootFilterMinQuality() or 0
    else
        minQ = Loothing.MinQuality or 4  -- EPIC fallback when Settings absent
    end
    if not itemLink then return false, nil, minQ end
    if minQ <= 0 then
        -- Quality filter disabled — never block.
        return false, nil, minQ
    end
    local _, _, quality = C_Item.GetItemInfo(itemLink)
    if quality == nil then
        -- Item not yet cached — defer the decision rather than blocking.
        return false, nil, minQ
    end
    return quality < minQ, quality, minQ
end

--- Composite evaluation used by the Loot Picker to decide default
--- checkbox state and render per-row hints. Resolves item info ONCE
--- and shares classID/subclassID/quality across all sub-checks.
-- @param itemLink string
-- @return table - { allowed, reason, classID, subclassID, quality, minQuality }
function ItemFilterMixin:EvaluateItem(itemLink)
    -- Fail-closed minQ: same logic as IsBelowMinQuality — fall back to
    -- the EPIC constant when the Settings module is missing so the
    -- picker doesn't silently downgrade to "no quality filter".
    local minQ
    if Loothing.Settings then
        minQ = Loothing.Settings:GetLootFilterMinQuality() or 0
    else
        minQ = Loothing.MinQuality or 4
    end
    local result = {
        allowed     = true,
        reason      = nil,
        classID     = nil,
        subclassID  = nil,
        quality     = nil,
        minQuality  = minQ,
    }
    if not itemLink then
        -- No link — default to ALLOWED so an unknown link doesn't trip
        -- a "blocked" badge in the picker; the caller can still skip.
        result.reason = "no-item"
        return result
    end

    local _, _, _, _, _, classID, subclassID = C_Item.GetItemInfoInstant(itemLink)
    result.classID = classID
    result.subclassID = subclassID

    local _, _, quality = C_Item.GetItemInfo(itemLink)
    result.quality = quality

    -- Per-player ignore list
    if self:ShouldIgnoreItem(itemLink) then
        result.allowed = false
        result.reason = "ignored"
        return result
    end

    -- Class/subclass block (uses shared classID/subclassID, no extra fetch).
    -- Same fail-closed fallback as IsClassBlocked: when Settings is absent,
    -- defer to the seed defaults exposed by SettingsLootFilter.
    if classID then
        local blocked, label = self:IsClassBlocked(itemLink)
        if blocked then
            result.allowed = false
            result.reason = "class:" .. (label or string.format("Class %d", classID))
            return result
        end
    end

    -- Quality threshold — only enforce when filter is enabled (minQ > 0)
    -- AND the item is cached. Cold cache defers to allowed.
    if minQ > 0 and quality ~= nil and quality < minQ then
        result.allowed = false
        result.reason = "quality"
        return result
    end

    -- BoE check (separate gate from class block — controlled by ml.autoAddBoEs)
    if Loothing.Settings and not Loothing.Settings:Get("ml.autoAddBoEs", false) then
        local _, _, _, _, _, _, _, _, _, _, _, _, _, bindType = C_Item.GetItemInfo(itemLink)
        if bindType == 2 then  -- Enum.ItemBind.OnEquip
            result.allowed = false
            result.reason = "boe"
            return result
        end
    end

    return result
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
