--[[--------------------------------------------------------------------
    Loothing - Seasons

    Lightweight lookup table mapping raid instance names (as they appear
    in `history.entry.instance`) to a season id + display name + sort
    order. Used by the Browse-by-Season modal and the Season Summary
    modal to group history entries into seasonal buckets without needing
    a date range / API lookup.

    Extending: add a new row to `SEASONS_TABLE` keyed by the exact
    instance string Blizzard returns for that raid. Multiple raids can
    share a season (e.g., Season X has two raid tiers).

    Entries whose `instance` isn't in this table resolve to a sentinel
    "Unclassified" season so they're still browsable via the Seasons
    list; the Season modal can show them as a bucket for dungeon or
    world-drop loot.
----------------------------------------------------------------------]]

local _, ns = ...
local Loothing = ns.Addon

-- Ordered table of known seasons; lowest `order` is displayed first
-- (i.e. put the latest season at order = 1 so it sorts to the top).
--
-- Each instance name should appear in AT MOST ONE season. If Blizzard
-- releases a raid that spans multiple tiers, add it to whichever season
-- that raid was CURRENT for — the other season will bucket its entries
-- via UNCLASSIFIED until a future Loothing release adds proper
-- timestamp-range resolution.
local SEASONS_TABLE = {
    {
        id       = "TWW_S3",
        name     = "The War Within Season 3",
        order    = 1,
        -- Raid instance names that belong to this season. Match against
        -- entry.instance (what Blizzard returns from EJ / encounter data).
        instances = {
            "Manaforge Omega",
        },
    },
    {
        id       = "TWW_S2",
        name     = "The War Within Season 2",
        order    = 2,
        instances = {
            "Liberation of Undermine",
        },
    },
    {
        id       = "TWW_S1",
        name     = "The War Within Season 1",
        order    = 3,
        instances = {
            "Nerub-ar Palace",
        },
    },
    -- Midnight seasons will be added here once Blizzard announces the
    -- Season 1 raid and subsequent tiers.
}

-- Build a reverse lookup: instance name -> {season row, ...}. An
-- instance can appear in multiple season rows (Undermine spans TWW S2
-- and Midnight S1 in different games), in which case we pick the most
-- recent award to disambiguate via timestamp; for now, first match
-- wins on order (lowest first = most recent).
local _instanceIndex
local function buildInstanceIndex()
    _instanceIndex = {}
    for _, season in ipairs(SEASONS_TABLE) do
        for _, inst in ipairs(season.instances or {}) do
            _instanceIndex[inst] = _instanceIndex[inst] or {}
            table.insert(_instanceIndex[inst], season)
        end
    end
    for _, list in pairs(_instanceIndex) do
        table.sort(list, function(a, b) return (a.order or 99) < (b.order or 99) end)
    end
end

local Seasons = {}
ns.Seasons = Seasons
Loothing.Seasons = Seasons

--- Get the season descriptor for a history entry, or nil if unclassified.
--- @param entry table - history entry with .instance (string)
--- @return table|nil {id, name, order}
function Seasons:GetForEntry(entry)
    if not entry or not entry.instance then return nil end
    if not _instanceIndex then buildInstanceIndex() end

    local matches = _instanceIndex[entry.instance]
    if not matches or #matches == 0 then return nil end
    -- First match wins; extend with timestamp-based disambiguation if a
    -- single instance ever gets re-used across multiple seasons.
    return matches[1]
end

--- Enumerate every known season (ordered). Appends a virtual
--- "Unclassified" bucket at the end for entries whose instance isn't
--- mapped.
--- @return table Array of { id, name, order } rows
function Seasons:GetAll()
    local out = {}
    for _, season in ipairs(SEASONS_TABLE) do
        out[#out + 1] = season
    end
    out[#out + 1] = {
        id = "UNCLASSIFIED",
        name = "Unclassified / Other",
        order = 999,
        instances = nil,
    }
    table.sort(out, function(a, b) return (a.order or 99) < (b.order or 99) end)
    return out
end

--- Look up a season descriptor by id (including "UNCLASSIFIED").
--- @param id string
--- @return table|nil
function Seasons:GetById(id)
    if not id then return nil end
    if id == "UNCLASSIFIED" then
        return { id = "UNCLASSIFIED", name = "Unclassified / Other", order = 999 }
    end
    for _, season in ipairs(SEASONS_TABLE) do
        if season.id == id then return season end
    end
    return nil
end

--- Test whether a history entry belongs to a given season id.
--- @param entry table
--- @param seasonId string
--- @return boolean
function Seasons:EntryMatches(entry, seasonId)
    if not entry or not seasonId then return false end
    local s = self:GetForEntry(entry)
    if seasonId == "UNCLASSIFIED" then
        return s == nil
    end
    return s ~= nil and s.id == seasonId
end
