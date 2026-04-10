--[[--------------------------------------------------------------------
    Loothing - Loot Council Addon for WoW 12.0+
    TrinketSims - Desktop exchange trinket sim rankings reader
    Provides trinket rank data from bloodmallet.com (SimulationCraft)
    for loot council decisions.
----------------------------------------------------------------------]]

local _, ns = ...
local Loolib = LibStub("Loolib")
local Loothing = ns.Addon
local time = time
local tostring = tostring
local format = string.format

--[[--------------------------------------------------------------------
    TrinketSimsMixin
----------------------------------------------------------------------]]

local TrinketSimsMixin = Loolib.CreateFromMixins(Loolib.CallbackRegistryMixin)
ns.TrinketSimsMixin = TrinketSimsMixin

local TRINKET_SIMS_EVENTS = {
    "OnTrinketSimsLoaded",
    "OnTrinketSimsUpdated",
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
    self.fightStyle = nil
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
    self.fightStyle = ts.fightStyle
    self.source = ts.source
    self.version = ts.version

    self:TriggerEvent("OnTrinketSimsLoaded")
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

--[[--------------------------------------------------------------------
    Queries
----------------------------------------------------------------------]]

--- Check if trinket sim data has been loaded from the desktop app
-- @return boolean
function TrinketSimsMixin:HasData()
    return self.generatedAt ~= nil and next(self.trinkets) ~= nil
end

--- Get the sim rank for a trinket given a class and spec
-- @param itemID number - WoW item ID
-- @param class string  - WoW class token (e.g. "PRIEST", "DEATHKNIGHT")
-- @param spec string   - Display spec name (e.g. "Shadow", "Beast Mastery")
-- @return number|nil   - Rank (1 = best) or nil if no data
function TrinketSimsMixin:GetRank(itemID, class, spec)
    if not self:HasData() or not itemID then return nil end

    local slug = BuildSlug(class, spec)
    if not slug then return nil end

    local entry = self.trinkets[tostring(itemID)]
    if not entry then return nil end

    return entry[slug]
end

--- Get a formatted rank string with class-colored text
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

--- Get the fight style used for the sims
-- @return string|nil - Fight style (e.g. "castingpatchwerk")
function TrinketSimsMixin:GetFightStyle()
    return self.fightStyle
end

--- Get the data format version
-- @return number|nil
function TrinketSimsMixin:GetVersion()
    return self.version
end
