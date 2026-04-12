--[[--------------------------------------------------------------------
    Loothing - Loot Council Addon for WoW 12.0+
    TrinketSims - Desktop exchange trinket sim rankings reader
    Provides trinket rank + DPS gain data from bloodmallet.com (SimulationCraft)
    for loot council decisions.

    v2 payload shape (all 3 fight styles in one payload):
      trinkets[itemId][class_spec] = {
        r  = rank1T, g  = gain1T,   -- 1 Target
        r3 = rank3T, g3 = gain3T,   -- 3 Targets
        r5 = rank5T, g5 = gain5T,   -- 5 Targets
      }

    v1 (legacy, backward compat):
      trinkets[itemId][class_spec] = rank  (number, 1T only)
----------------------------------------------------------------------]]

local _, ns = ...
local Loolib = LibStub("Loolib")
local Loothing = ns.Addon
local time = time
local tostring = tostring
local format = string.format
local floor = math.floor
local abs = math.abs

--[[--------------------------------------------------------------------
    TrinketSimsMixin
----------------------------------------------------------------------]]

local TrinketSimsMixin = Loolib.CreateFromMixins(Loolib.CallbackRegistryMixin)
ns.TrinketSimsMixin = TrinketSimsMixin

local TRINKET_SIMS_EVENTS = {
    "OnTrinketSimsLoaded",
}

--[[--------------------------------------------------------------------
    Class / Spec slug conversion tables
    WoW API gives us DEATHKNIGHT / "Beast Mastery" — bloodmallet uses
    death_knight_beast_mastery. These tables bridge the gap.
----------------------------------------------------------------------]]

local CLASS_SLUGS = {
    DEATHKNIGHT  = "death_knight",
    DEMONHUNTER  = "demon_hunter",
    DRUID        = "druid",
    EVOKER       = "evoker",
    HUNTER       = "hunter",
    MAGE         = "mage",
    MONK         = "monk",
    PALADIN      = "paladin",
    PRIEST       = "priest",
    ROGUE        = "rogue",
    SHAMAN       = "shaman",
    WARLOCK      = "warlock",
    WARRIOR      = "warrior",
}

local SPEC_SLUGS = {
    -- Death Knight
    ["Blood"]         = "blood",
    ["Frost"]         = "frost",
    ["Unholy"]        = "unholy",
    -- Demon Hunter
    ["Havoc"]         = "havoc",
    ["Vengeance"]     = "vengeance",
    ["Devourer"]      = "devourer",
    -- Druid
    ["Balance"]       = "balance",
    ["Feral"]         = "feral",
    ["Guardian"]      = "guardian",
    ["Restoration"]   = "restoration",
    -- Evoker
    ["Devastation"]   = "devastation",
    ["Preservation"]  = "preservation",
    ["Augmentation"]  = "augmentation",
    -- Hunter
    ["Beast Mastery"]  = "beast_mastery",
    ["Marksmanship"]   = "marksmanship",
    ["Survival"]       = "survival",
    -- Mage
    ["Arcane"]        = "arcane",
    ["Fire"]          = "fire",
    -- Frost already mapped above (shared with DK)
    -- Monk
    ["Brewmaster"]    = "brewmaster",
    ["Mistweaver"]    = "mistweaver",
    ["Windwalker"]    = "windwalker",
    -- Paladin
    ["Holy"]          = "holy",
    ["Protection"]    = "protection",
    ["Retribution"]   = "retribution",
    -- Priest
    ["Discipline"]    = "discipline",
    -- Holy already mapped above (shared with Paladin)
    ["Shadow"]        = "shadow",
    -- Rogue
    ["Assassination"] = "assassination",
    ["Outlaw"]        = "outlaw",
    ["Subtlety"]      = "subtlety",
    -- Shaman
    ["Elemental"]     = "elemental",
    ["Enhancement"]   = "enhancement",
    -- Restoration already mapped above (shared with Druid)
    -- Warlock
    ["Affliction"]    = "affliction",
    ["Demonology"]    = "demonology",
    ["Destruction"]   = "destruction",
    -- Warrior
    ["Arms"]          = "arms",
    ["Fury"]          = "fury",
    -- Protection already mapped above (shared with Paladin)
}

--- Display names for class tokens (DEATHKNIGHT -> "Death Knight", etc.)
local CLASS_DISPLAY_NAMES = {
    DEATHKNIGHT  = "Death Knight",
    DEMONHUNTER  = "Demon Hunter",
    DRUID        = "Druid",
    EVOKER       = "Evoker",
    HUNTER       = "Hunter",
    MAGE         = "Mage",
    MONK         = "Monk",
    PALADIN      = "Paladin",
    PRIEST       = "Priest",
    ROGUE        = "Rogue",
    SHAMAN       = "Shaman",
    WARLOCK      = "Warlock",
    WARRIOR      = "Warrior",
}

--[[--------------------------------------------------------------------
    Initialization
----------------------------------------------------------------------]]

--- Initialize trinket sims data reader
function TrinketSimsMixin:Init()
    Loolib.CallbackRegistryMixin.OnLoad(self)
    self:GenerateCallbackEvents(TRINKET_SIMS_EVENTS)

    self.trinkets = {}
    self.generatedAt = nil
    self.source = nil
    self.version = nil

    self:LoadFromSaved()
end

--[[--------------------------------------------------------------------
    Persistence
----------------------------------------------------------------------]]

--- Load trinket sim data from SavedVariables (written by Tauri desktop app)
function TrinketSimsMixin:LoadFromSaved()
    if not Loothing.Settings then return end

    local exchange = Loothing.Settings:GetGlobalValue("desktopExchange")
    if not exchange or not exchange.trinketSims then return end

    local ts = exchange.trinketSims
    self.trinkets = ts.trinkets or {}
    self.generatedAt = ts.generatedAt
    self.source = ts.source
    self.version = ts.version or 1
    self.sharedBy = ts.sharedBy     -- nil if from own desktop app
    self.sharedAt = ts.sharedAt     -- nil if from own desktop app

    self:TriggerEvent("OnTrinketSimsLoaded")
end

--- Check if data was received via intel share (not from own desktop app)
-- @return boolean
function TrinketSimsMixin:IsSharedData()
    return self.sharedBy ~= nil
end

--- Get sharing metadata
-- @return string|nil sharedBy - Player name who shared
-- @return number|nil sharedAt - Epoch timestamp when shared
function TrinketSimsMixin:GetSharedInfo()
    return self.sharedBy, self.sharedAt
end

--[[--------------------------------------------------------------------
    Internal helpers
----------------------------------------------------------------------]]

--- Build a bloodmallet-style slug from WoW class token and spec name
-- @param class string - WoW class token (e.g. "PRIEST", "DEATHKNIGHT")
-- @param spec string  - Display spec name (e.g. "Shadow", "Beast Mastery")
-- @return string|nil  - Slug like "priest_shadow" or nil if conversion fails
local function BuildSlug(class, spec)
    local classSlug = CLASS_SLUGS[class]
    local specSlug = SPEC_SLUGS[spec]
    if not classSlug or not specSlug then return nil end
    return classSlug .. "_" .. specSlug
end

--- Look up an item entry from a desktop-synced item map.
-- Desktop sync writes numeric Lua keys for item IDs, but older payloads may
-- still use string keys. Support both to stay backward-compatible.
-- @param itemMap table|nil
-- @param itemID number|string
-- @return table|nil
local function GetItemEntry(itemMap, itemID)
    if type(itemMap) ~= "table" or itemID == nil then return nil end
    return itemMap[itemID] or itemMap[tostring(itemID)]
end

--- Format a DPS number into a compact human-readable string
-- e.g. 12500 → "12.5k", 1234567 → "1.23M", 850 → "850"
local function FormatDps(dps)
    if not dps or dps == 0 then return nil end
    local absDps = abs(dps)
    local sign = dps >= 0 and "+" or ""
    if absDps >= 1000000 then
        return format("%s%.2fM", sign, dps / 1000000)
    elseif absDps >= 1000 then
        return format("%s%.1fk", sign, dps / 1000)
    else
        return format("%s%d", sign, floor(dps))
    end
end

--- Get the spec entry for an item, handling both v1 and v2 formats.
-- v1: entry[slug] = rank (number)
-- v2: entry[slug] = { r=rank, g=gain, r3=rank3, g3=gain3, r5=rank5, g5=gain5 }
-- @return table|nil - Always returns a v2-style table or nil
local function GetSpecData(entry, slug)
    if not entry or not slug then return nil end
    local val = entry[slug]
    if val == nil then return nil end
    -- v1 backward compat: bare number = 1T rank only
    if type(val) == "number" then
        return { r = val, g = nil }
    end
    if type(val) == "table" then
        return val
    end
    return nil
end

--[[--------------------------------------------------------------------
    Queries
----------------------------------------------------------------------]]

--- Check if trinket sim data has been loaded from the desktop app
-- @return boolean
function TrinketSimsMixin:HasData()
    return self.generatedAt ~= nil and next(self.trinkets) ~= nil
end

--- Get the sim rank for a trinket given a class and spec (1T by default)
-- @param itemID number - WoW item ID
-- @param class string  - WoW class token (e.g. "PRIEST", "DEATHKNIGHT")
-- @param spec string   - Display spec name (e.g. "Shadow", "Beast Mastery")
-- @return number|nil   - Rank (1 = best) or nil if no data
function TrinketSimsMixin:GetRank(itemID, class, spec)
    if not self:HasData() or not itemID then return nil end

    local slug = BuildSlug(class, spec)
    if not slug then return nil end

    local entry = GetItemEntry(self.trinkets, itemID)
    local specData = GetSpecData(entry, slug)
    if not specData then return nil end

    return specData.r
end

--- Get the DPS gain for a trinket given a class, spec, and fight style
-- @param itemID number - WoW item ID
-- @param class string  - WoW class token
-- @param spec string   - Display spec name
-- @param targets string|nil - "1T", "3T", or "5T" (default "1T")
-- @return number|nil   - DPS gain or nil if no data
function TrinketSimsMixin:GetDpsGain(itemID, class, spec, targets)
    if not self:HasData() or not itemID then return nil end

    local slug = BuildSlug(class, spec)
    if not slug then return nil end

    local entry = GetItemEntry(self.trinkets, itemID)
    local specData = GetSpecData(entry, slug)
    if not specData then return nil end

    if targets == "3T" then return specData.g3
    elseif targets == "5T" then return specData.g5
    else return specData.g
    end
end

--- Get a formatted rank string with class-colored text (legacy, 1T only)
-- Example: "#3 for |cffFF7D0AShadow Priest|r"
-- @param itemID number - WoW item ID
-- @param class string  - WoW class token (e.g. "PRIEST", "DEATHKNIGHT")
-- @param spec string   - Display spec name (e.g. "Shadow", "Beast Mastery")
-- @return string|nil   - Formatted rank text or nil if no data
function TrinketSimsMixin:GetRankText(itemID, class, spec)
    local rank = self:GetRank(itemID, class, spec)
    if not rank then return nil end

    local displayClassName = CLASS_DISPLAY_NAMES[class] or class
    local cc = RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]

    if cc then
        return format(
            "#%d for |cff%02x%02x%02x%s %s|r",
            rank,
            cc.r * 255,
            cc.g * 255,
            cc.b * 255,
            spec,
            displayClassName
        )
    end

    -- Fallback without color (RAID_CLASS_COLORS not available)
    return format("#%d for %s %s", rank, spec, displayClassName)
end

--- Get a multi-target sim summary line for the council table.
-- Shows DPS gain for each available fight style (1T / 3T / 5T).
-- Example: "1T +12.5k · 3T +8.2k · 5T +4.1k"
-- Falls back to rank display if gains aren't available (v1 data).
-- @param itemID number - WoW item ID
-- @param class string  - WoW class token
-- @param spec string   - Display spec name
-- @return string|nil   - Formatted sim text or nil if no data
function TrinketSimsMixin:GetSimText(itemID, class, spec)
    if not self:HasData() or not itemID then return nil end

    local slug = BuildSlug(class, spec)
    if not slug then return nil end

    local entry = GetItemEntry(self.trinkets, itemID)
    local specData = GetSpecData(entry, slug)
    if not specData then return nil end

    -- v2: build DPS gain display across all available fight styles
    local parts = {}
    local gainKeys = {
        { label = "1T", gKey = "g",  rKey = "r"  },
        { label = "3T", gKey = "g3", rKey = "r3" },
        { label = "5T", gKey = "g5", rKey = "r5" },
    }

    for _, k in ipairs(gainKeys) do
        local gain = specData[k.gKey]
        local rank = specData[k.rKey]
        if gain then
            local formatted = FormatDps(gain)
            if formatted then
                if rank then
                    parts[#parts + 1] = format("|cffAAAAAA%s|r #%d %s", k.label, rank, formatted)
                else
                    parts[#parts + 1] = format("|cffAAAAAA%s|r %s", k.label, formatted)
                end
            end
        elseif rank then
            parts[#parts + 1] = format("|cffAAAAAA%s|r #%d", k.label, rank)
        end
    end

    -- If we have DPS gain data, use it
    if #parts > 0 then
        return table.concat(parts, "  |cff555555|||r  ")
    end

    -- Fallback for v1 data: just show rank
    if specData.r then
        return format("#%d", specData.r)
    end

    return nil
end

--- Get a class-colored spec label for display
-- Example: "|cffFF7D0AShadow Priest|r"
-- @param class string - WoW class token
-- @param spec string  - Display spec name
-- @return string
function TrinketSimsMixin:GetColoredSpecLabel(class, spec)
    local displayClassName = CLASS_DISPLAY_NAMES[class] or class
    local cc = RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
    if cc then
        return format(
            "|cff%02x%02x%02x%s %s|r",
            cc.r * 255,
            cc.g * 255,
            cc.b * 255,
            spec,
            displayClassName
        )
    end
    return format("%s %s", spec, displayClassName)
end

--- Get seconds since the last desktop sync
-- @return number|nil - Seconds since sync, or nil if never synced
function TrinketSimsMixin:GetDataAge()
    if not self.generatedAt then return nil end
    return time() - self.generatedAt
end

--- Get the data source identifier
-- @return string - Source name (e.g. "bloodmallet.com")
function TrinketSimsMixin:GetSource()
    return self.source or "bloodmallet.com"
end

--- Get the data format version
-- @return number|nil
function TrinketSimsMixin:GetVersion()
    return self.version
end
