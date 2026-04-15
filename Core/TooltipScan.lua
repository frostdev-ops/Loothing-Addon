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

-- Escape Lua pattern magic characters so a localized string with e.g. `(...)`
-- or `.` doesn't become an active pattern when we turn it into a capture.
-- `%` is escaped first because its replacement introduces new `%` chars.
local PATTERN_MAGIC = { "%%", "%*", "%+", "%-", "%?", "%(", "%)", "%[", "%]", "%$", "%^" }
local PATTERN_ESC   = { "%%%%", "%%%*", "%%%+", "%%%-", "%%%?", "%%%(", "%%%)", "%%%[", "%%%]", "%%%$", "%%%^" }

local function EscapePatternSymbols(text)
    for i = 1, #PATTERN_MAGIC do
        text = text:gsub(PATTERN_MAGIC[i], PATTERN_ESC[i])
    end
    return text
end

-- Cache the compiled pattern once per session. BIND_TRADE_TIME_REMAINING is
-- set by the client at load, never mutates.
local cachedTradePattern = nil
local function GetTradePattern()
    if cachedTradePattern then return cachedTradePattern end
    local raw = BIND_TRADE_TIME_REMAINING
    if not raw then return nil end
    cachedTradePattern = EscapePatternSymbols(raw)
        :gsub("1%%%$", "")      -- strip "%1$s" artifact from some locales (ruRU)
        :gsub("%%%%s", "(.+)")  -- %s → capture group
    return cachedTradePattern
end

-- RCLC-style locale-safe trade-time parser. Extracts the %s segment from the
-- BIND_TRADE_TIME_REMAINING line, then reconstructs candidate duration strings
-- via CompleteFormatSimpleStringWithPluralRule (Blizzard's own formatter) and
-- matches them exactly. Handles pluralization, locale-specific separators,
-- and sub-minute windows without relying on "%d+ h / %d+ m" keyword hints.
local function ParseTradeTimeText(text)
    if not text then return nil end
    local tradePattern = GetTradePattern()
    if not tradePattern then return nil end

    local timeText = text:match(tradePattern)
    if not timeText then return nil end

    local CompleteFormat = _G.CompleteFormatSimpleStringWithPluralRule
    local delimiter = _G.TIME_UNIT_DELIMITER or " "

    if CompleteFormat and _G.INT_SPELL_DURATION_HOURS and _G.INT_SPELL_DURATION_MIN then
        -- time >= 60s candidates: "1 hour", "1 hour 59 min", "59 min", "1 min"
        for hour = 4, 0, -1 do
            local hourText = ""
            if hour > 0 then
                hourText = CompleteFormat(_G.INT_SPELL_DURATION_HOURS, hour)
            end
            for minute = 59, 0, -1 do
                local candidate = hourText
                if minute > 0 then
                    if candidate ~= "" then candidate = candidate .. delimiter end
                    candidate = candidate .. CompleteFormat(_G.INT_SPELL_DURATION_MIN, minute)
                end
                if candidate == timeText then
                    return hour * 3600 + minute * 60
                end
            end
        end
        -- time < 60s candidates: "59 s", "1 s"
        if _G.INT_SPELL_DURATION_SEC then
            for second = 59, 1, -1 do
                if CompleteFormat(_G.INT_SPELL_DURATION_SEC, second) == timeText then
                    return second
                end
            end
        end
        -- Matched the tradePattern but not any candidate — stale or unrecognized
        -- locale format. Return a pessimistic 2h so the item is still seen as
        -- "tradable right now" and the bag scanner forwards it to the ML,
        -- rather than silently dropping it.
        return 7200
    end

    -- Fallback for clients lacking the formatter globals: best-effort digit parse.
    local first, second = timeText:match("(%d+).-(%d+)")
    if first and second then
        return (tonumber(first) or 0) * 3600 + (tonumber(second) or 0) * 60
    end
    local hours = tonumber(timeText:match("(%d+)%s*h"))
    local minutes = tonumber(timeText:match("(%d+)%s*m"))
    local seconds = tonumber(timeText:match("(%d+)%s*s"))
    if hours or minutes or seconds then
        return (hours or 0) * 3600 + (minutes or 0) * 60 + (seconds or 0)
    end
    return 7200
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
