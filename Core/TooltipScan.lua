--[[--------------------------------------------------------------------
    Loothing - Loot Council Addon for WoW 12.0+
    TooltipScan - Shared unnamed tooltip scanning and caches
----------------------------------------------------------------------]]

local _, ns = ...
local Loolib = LibStub("Loolib")
local Utils = ns.Utils
local Events = Loolib.Events

local TooltipScan = ns.TooltipScan or {}
ns.TooltipScan = TooltipScan

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

local ALL_CLASSES_FLAG = bit.lshift(1, 13) - 1

local function EnsureTooltip(self)
    if self.tooltip then
        return self.tooltip
    end

    local tooltip = CreateFrame("GameTooltip", nil, UIParent, "GameTooltipTemplate")
    tooltip:SetOwner(UIParent, "ANCHOR_NONE")
    self.tooltip = tooltip
    return tooltip
end

local function EnsureCaches(self)
    if self.classRestrictionCache then
        return
    end

    self.classRestrictionCache = {}
    self.bagTradeTimeCache = {}
end

local function EnsureEvents(self)
    if self.eventsRegistered then
        return
    end

    if Events and Events.Registry then
        Events.Registry:RegisterEventCallback("BAG_UPDATE_DELAYED", function()
            self:InvalidateBagCache()
        end, self)
        self.eventsRegistered = true
    end
end

local function GetClassCacheKey(itemLink)
    local itemID = Utils.GetItemID(itemLink)
    if itemID then
        return "item:" .. itemID
    end
    return "link:" .. tostring(itemLink)
end

local function IterateTooltipText(tooltip)
    local regions = { tooltip:GetRegions() }
    local index = 0

    return function()
        while true do
            index = index + 1
            local region = regions[index]
            if not region then
                return nil
            end
            if region.GetObjectType and region:GetObjectType() == "FontString" then
                local text = region:GetText()
                if text and text ~= "" then
                    return text
                end
            end
        end
    end
end

local function ParseTradeTimeText(text)
    if not text then
        return nil
    end

    local tradePattern = BIND_TRADE_TIME_REMAINING
    if tradePattern then
        local anchor = tradePattern:match("^(.-)%%s")
        if anchor and anchor ~= "" then
            local anchorStart, anchorEnd = text:find(anchor, 1, true)
            if anchorStart then
                local timeText = text:sub(anchorEnd + 1)
                local first, second = timeText:match("(%d+).-(%d+)")
                local hours = tonumber(first) or tonumber(timeText:match("(%d+)")) or 0
                local minutes = tonumber(second) or 0
                local remaining = (hours * 3600) + (minutes * 60)
                return remaining > 0 and remaining or 60
            end
        end
    end

    local hours = tonumber(text:match("(%d+)%s*hour")) or tonumber(text:match("(%d+)%s*hr"))
    local minutes = tonumber(text:match("(%d+)%s*min"))
    if hours or minutes then
        return (hours or 0) * 3600 + (minutes or 0) * 60
    end

    return nil
end

local function GetBagIdentity(bag, slot)
    local info = C_Container.GetContainerItemInfo(bag, slot)
    if not info then
        return nil
    end

    local itemID = info.itemID
    if not itemID and info.hyperlink then
        itemID = Utils.GetItemID(info.hyperlink)
    end

    return table.concat({
        tostring(itemID or ""),
        tostring(info.stackCount or 0),
        tostring(info.isBound and 1 or 0),
        tostring(info.hyperlink or ""),
    }, ":")
end

function TooltipScan:InvalidateBagCache()
    EnsureCaches(self)
    wipe(self.bagTradeTimeCache)
end

function TooltipScan:GetItemClassRestrictions(itemLink)
    if not itemLink then
        return nil
    end

    EnsureCaches(self)
    EnsureEvents(self)

    local cacheKey = GetClassCacheKey(itemLink)
    local cached = self.classRestrictionCache[cacheKey]
    if cached ~= nil then
        return cached ~= false and cached or nil
    end

    local tooltip = EnsureTooltip(self)
    tooltip:ClearLines()
    tooltip:SetHyperlink(itemLink)

    local restrictions
    local classLabel = ITEM_CLASSES_ALLOWED

    for text in IterateTooltipText(tooltip) do
        local classList
        if classLabel then
            local startPos, endPos = text:find(classLabel, 1, true)
            if startPos == 1 then
                classList = text:sub(endPos + 1):match("^:%s*(.+)$")
            end
        end
        if not classList then
            classList = text:match("^Classes:%s*(.+)$")
        end
        if classList then
            restrictions = {}
            for className in classList:gmatch("([^,]+)") do
                local normalized = className:match("^%s*(.-)%s*$")
                if normalized then
                    for classID = 1, 13 do
                        local info = C_CreatureInfo.GetClassInfo(classID)
                        if info and info.className and info.className:upper() == normalized:upper() then
                            restrictions[#restrictions + 1] = classID
                            break
                        end
                    end
                    if CLASS_NAME_TO_ID[normalized:upper()] then
                        restrictions[#restrictions + 1] = CLASS_NAME_TO_ID[normalized:upper()]
                    end
                end
            end
            break
        end
    end

    tooltip:Hide()

    if restrictions and #restrictions > 0 then
        local deduped = {}
        local unique = {}
        for _, classID in ipairs(restrictions) do
            if not deduped[classID] then
                deduped[classID] = true
                unique[#unique + 1] = classID
            end
        end
        self.classRestrictionCache[cacheKey] = unique
        return unique
    end

    self.classRestrictionCache[cacheKey] = false
    return nil
end

function TooltipScan:GetItemClassRestrictionFlag(itemLink)
    local restrictions = self:GetItemClassRestrictions(itemLink)
    if not restrictions or #restrictions == 0 then
        return ALL_CLASSES_FLAG
    end

    local flags = 0
    for _, classID in ipairs(restrictions) do
        flags = bit.bor(flags, bit.lshift(1, classID - 1))
    end
    return flags
end

function TooltipScan:GetContainerItemTradeTimeRemaining(bag, slot)
    if not bag or not slot then
        return 0
    end

    EnsureCaches(self)
    EnsureEvents(self)

    local identity = GetBagIdentity(bag, slot)
    if not identity then
        return 0
    end

    local cacheKey = bag .. ":" .. slot
    local cached = self.bagTradeTimeCache[cacheKey]
    if cached and cached.identity == identity then
        return cached.remaining
    end

    local tooltip = EnsureTooltip(self)
    tooltip:ClearLines()
    tooltip:SetBagItem(bag, slot)

    -- Scan every line: trade-time takes priority over bound status.
    -- Tooltips show "Soulbound" BEFORE the "You may trade…" line, so we
    -- must not break early on a bound marker — otherwise freshly looted
    -- raid loot always reports 0 trade-time and the bag scanner silently
    -- drops every drop. We track `bounded` as a flag and keep scanning.
    local tradeTime = nil
    local bounded = false

    for text in IterateTooltipText(tooltip) do
        local parsed = ParseTradeTimeText(text)
        if parsed then
            tradeTime = parsed
            break
        end
        if text == ITEM_SOULBOUND
            or text == ITEM_ACCOUNTBOUND
            or text == ITEM_BNETACCOUNTBOUND
            or text == ITEM_ACCOUNTBOUND_UNTIL_EQUIP
        then
            bounded = true
            -- Do NOT break — the trade-time line may appear later.
        end
    end

    tooltip:Hide()

    local remaining
    if tradeTime then
        remaining = tradeTime
    elseif bounded then
        remaining = 0
    else
        remaining = math.huge
    end

    self.bagTradeTimeCache[cacheKey] = {
        identity = identity,
        remaining = remaining,
    }
    return remaining
end
