--[[--------------------------------------------------------------------
    Loothing - Settings (Loot Filter)

    Configurable loot filtering. Master Looters can:
      * Set a minimum quality threshold (Common..Legendary)
      * Block whole item classes (consumables, recipes, quest items, etc.)
      * Block individual subclasses inside an item class

    These settings replace the hardcoded BLACKLISTED_ITEM_CLASSES that
    used to live in Data/Session.lua. Defaults preserve the old behavior
    so existing users see no change on upgrade — see SchemaMigration.lua
    for the seed migration.

    Storage layout:
      loot.filter.minQuality                                  -> number (0..5)
      loot.filter.classes.<classID>.blocked                   -> bool
      loot.filter.classes.<classID>.subclasses.<subID>        -> bool

    A class is fully blocked when classes[id].blocked == true. A
    specific subclass is blocked when subclasses[sub] == true (and the
    parent class is not fully blocked).
----------------------------------------------------------------------]]

local _, ns = ...
local Loothing = ns.Addon

local SettingsMixin = ns.SettingsMixin or {}
ns.SettingsMixin = SettingsMixin

--[[--------------------------------------------------------------------
    Default class blacklist seed

    Mirrors the pre-2.0.20 hardcoded BLACKLISTED_ITEM_CLASSES table.
    Both the SchemaMigration seed and the runtime fallback in
    GetClassEntry() consult this so a fresh install behaves identically
    to the old static list, while still letting users opt out per-class.
----------------------------------------------------------------------]]

local DEFAULT_BLOCKED_CLASSES = {
    [0]  = { all = true },               -- Consumables
    [5]  = { all = true },               -- Reagents
    [7]  = { all = true },               -- Tradeskill / recipes
    [12] = { all = true },               -- Quest items
    [15] = { [1] = true, [4] = true },   -- Misc: Reagent (1), Other/Anima (4)
    [20] = { all = true },               -- Decor / Housing
}

-- Read-only public view of the seed values. Note: `classes` is the
-- module-private table reference; do not mutate it. If you need to walk
-- and modify, deep-copy first.
ns.LootFilterDefaults = setmetatable({
    minQuality = 0,
    classes = DEFAULT_BLOCKED_CLASSES,
}, {
    __newindex = function() error("LootFilterDefaults is read-only", 2) end,
})

--[[--------------------------------------------------------------------
    Min quality
----------------------------------------------------------------------]]

function SettingsMixin:GetLootFilterMinQuality()
    local q = tonumber(self:Get("loot.filter.minQuality", 0))
    if not q then return 0 end
    if q < 0 then q = 0 end
    if q > 5 then q = 5 end
    return q
end

function SettingsMixin:SetLootFilterMinQuality(quality)
    quality = tonumber(quality)
    if not quality then return end
    if quality < 0 then quality = 0 end
    if quality > 5 then quality = 5 end
    self:Set("loot.filter.minQuality", math.floor(quality))
end

--[[--------------------------------------------------------------------
    Class / subclass blocking

    NOTE: We deliberately avoid Settings:Set("loot.filter.classes.<id>...")
    dot-notation here — Set splits on "." and uses string parts as keys,
    which collides with the numeric class IDs used by GetItemInfoInstant
    and by the seed table. Instead we take the classes-table reference
    once and mutate it directly so reads and writes share the same key
    type (numbers).
----------------------------------------------------------------------]]

--- Get the raw classes table, materialising the seed defaults the first
--- time a caller asks. Used by the options UI and by every accessor.
function SettingsMixin:GetLootFilterClasses()
    local classes = self:Get("loot.filter.classes", nil)
    if type(classes) == "table" then return classes end

    -- Materialise a copy of the defaults so subsequent writes persist.
    local seed = {}
    for cid, entry in pairs(DEFAULT_BLOCKED_CLASSES) do
        local copy = { blocked = entry.all == true }
        local subs = {}
        for k, v in pairs(entry) do
            if k ~= "all" then subs[k] = v end
        end
        if next(subs) then copy.subclasses = subs end
        seed[cid] = copy
    end
    self:Set("loot.filter.classes", seed)
    return seed
end

local function getOrCreateClassEntry(self, classID)
    local classes = self:GetLootFilterClasses()
    local entry = classes[classID]
    if not entry then
        -- Seed from the defaults so the new entry is authoritative from
        -- here on. A bare {blocked=false} entry made lookups fall back to
        -- DEFAULT_BLOCKED_CLASSES whenever subclasses was empty/nil —
        -- unblocking the last default-blocked subclass snapped both
        -- checkboxes back to blocked with no way to clear them.
        local def = DEFAULT_BLOCKED_CLASSES[classID]
        entry = { blocked = def ~= nil and def.all == true }
        if def then
            local subs = {}
            for k, v in pairs(def) do
                if k ~= "all" and v == true then subs[k] = true end
            end
            if next(subs) then entry.subclasses = subs end
        end
        classes[classID] = entry
    end
    return entry
end

--- True if the entire class is blocked (every subclass).
function SettingsMixin:IsLootFilterClassBlocked(classID)
    if classID == nil then return false end
    local classes = self:GetLootFilterClasses()
    local entry = classes[classID]
    if entry == nil then
        local def = DEFAULT_BLOCKED_CLASSES[classID]
        return def ~= nil and def.all == true
    end
    return entry.blocked == true
end

--- True if a specific subclass is blocked. A `true` from
--- IsLootFilterClassBlocked supersedes any subclass setting.
function SettingsMixin:IsLootFilterSubclassBlocked(classID, subclassID)
    if classID == nil or subclassID == nil then return false end
    if self:IsLootFilterClassBlocked(classID) then return true end
    local classes = self:GetLootFilterClasses()
    local entry = classes[classID]
    if entry then
        -- An existing entry is authoritative (seeded from defaults at
        -- creation): nil/empty subclasses means "no subclass blocks",
        -- not "fall back to defaults".
        if type(entry.subclasses) == "table" then
            return entry.subclasses[subclassID] == true
        end
        return false
    end
    local def = DEFAULT_BLOCKED_CLASSES[classID]
    if def and def[subclassID] == true then return true end
    return false
end

function SettingsMixin:SetLootFilterClassBlocked(classID, blocked)
    if classID == nil then return end
    local entry = getOrCreateClassEntry(self, classID)
    entry.blocked = blocked == true
end

function SettingsMixin:SetLootFilterSubclassBlocked(classID, subclassID, blocked)
    if classID == nil or subclassID == nil then return end
    local entry = getOrCreateClassEntry(self, classID)
    entry.subclasses = entry.subclasses or {}
    entry.subclasses[subclassID] = blocked == true and true or nil
    -- Drop the empty subclasses table to keep SVars tidy.
    if next(entry.subclasses) == nil then
        entry.subclasses = nil
    end
end

--- Reset all loot-filter class/subclass blocks to their seeded defaults.
--- Used by the "Reset Defaults" button in the Loot Filtering options group.
function SettingsMixin:ResetLootFilterClasses()
    local seed = {}
    for cid, entry in pairs(DEFAULT_BLOCKED_CLASSES) do
        local copy = { blocked = entry.all == true }
        local subs = {}
        for k, v in pairs(entry) do
            if k ~= "all" then subs[k] = v end
        end
        if next(subs) then copy.subclasses = subs end
        seed[cid] = copy
    end
    self:Set("loot.filter.classes", seed)
end
