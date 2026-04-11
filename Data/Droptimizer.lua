--[[--------------------------------------------------------------------
    Loothing - Loot Council Addon for WoW 12.0+
    Droptimizer - Desktop exchange droptimizer upgrade data reader
    Provides per-character DPS upgrade values from Raidbots Droptimizer
    (via desktop sync) for loot council decisions.
----------------------------------------------------------------------]]

local _, ns = ...
local Loolib = LibStub("Loolib")
local Loothing = ns.Addon
local time = time
local tostring = tostring
local floor = math.floor
local format = string.format

--[[--------------------------------------------------------------------
    DroptimizerMixin
----------------------------------------------------------------------]]

local DroptimizerMixin = Loolib.CreateFromMixins(Loolib.CallbackRegistryMixin)
ns.DroptimizerMixin = DroptimizerMixin

local DROPTIMIZER_EVENTS = {
    "OnDroptimizerLoaded",
    "OnDroptimizerUpdated",
}

--- Staleness threshold (seconds) — matches server-side 7-day window
local STALE_THRESHOLD = 7 * 24 * 3600

--[[--------------------------------------------------------------------
    Initialization
----------------------------------------------------------------------]]

--- Initialize droptimizer data reader
function DroptimizerMixin:Init()
    Loolib.CallbackRegistryMixin.OnLoad(self)
    self:GenerateCallbackEvents(DROPTIMIZER_EVENTS)

    self.characters = {}
    self.generatedAt = nil
    self.source = nil
    self.version = nil

    self:LoadFromSaved()
end

--[[--------------------------------------------------------------------
    Persistence
----------------------------------------------------------------------]]

--- Load droptimizer data from SavedVariables (written by Tauri desktop app)
function DroptimizerMixin:LoadFromSaved()
    if not Loothing.Settings then return end

    local exchange = Loothing.Settings:GetGlobalValue("desktopExchange")
    if not exchange or not exchange.droptimizer then return end

    local dt = exchange.droptimizer
    self.characters = dt.characters or {}
    self.generatedAt = dt.generatedAt
    self.source = dt.source
    self.version = dt.version

    self:TriggerEvent("OnDroptimizerLoaded")
end

--[[--------------------------------------------------------------------
    Internal helpers
----------------------------------------------------------------------]]

--- Format a number with thousands separators (1234 -> "1,234")
-- @param n number
-- @return string
local function FormatNumber(n)
    if not n then return "0" end
    local formatted = format("%.0f", n)
    -- Insert commas from right to left
    local k
    while true do
        formatted, k = formatted:gsub("^(-?%d+)(%d%d%d)", "%1,%2")
        if k == 0 then break end
    end
    return formatted
end

--[[--------------------------------------------------------------------
    Queries
----------------------------------------------------------------------]]

--- Check if droptimizer data has been loaded from the desktop app
-- @return boolean
function DroptimizerMixin:HasData()
    return self.generatedAt ~= nil and next(self.characters) ~= nil
end

--- Get the raw upgrade entry for a specific item and player
-- @param playerName string - "Name-Realm" format
-- @param itemID number - WoW item ID
-- @return table|nil - { g=dpsGain, p=dpsGainPct, s=slot, r=rankInSlot, e=encounterId } or nil
function DroptimizerMixin:GetUpgrade(playerName, itemID)
    if not self:HasData() or not playerName or not itemID then return nil end

    local charData = self.characters[playerName]
    if not charData or not charData.upgrades then return nil end

    return charData.upgrades[tostring(itemID)]
end

--- Get a formatted upgrade string for display in the council table
-- Example: "+12,450 DPS (+5.3%)"
-- @param playerName string - "Name-Realm" format
-- @param itemID number - WoW item ID
-- @return string|nil - Formatted upgrade text or nil if no data
function DroptimizerMixin:GetUpgradeText(playerName, itemID)
    local upgrade = self:GetUpgrade(playerName, itemID)
    if not upgrade or not upgrade.g then return nil end

    local gainText = FormatNumber(upgrade.g)
    local sign = upgrade.g >= 0 and "+" or ""
    if upgrade.p then
        local pSign = upgrade.p >= 0 and "+" or ""
        return format("%s%s DPS (%s%.1f%%)", sign, gainText, pSign, upgrade.p)
    end
    return format("%s%s DPS", sign, gainText)
end

--- Check whether a character's droptimizer report is stale
-- @param playerName string - "Name-Realm" format
-- @return boolean - true if stale or no data
function DroptimizerMixin:IsCharStale(playerName)
    if not playerName then return true end
    local charData = self.characters[playerName]
    if not charData then return true end
    if charData.stale then return true end
    if charData.fetchedAt then
        return (time() - charData.fetchedAt) > STALE_THRESHOLD
    end
    return true
end

--- Get the simmed spec for a character
-- @param playerName string - "Name-Realm" format
-- @return string|nil - Spec name (e.g. "Shadow")
function DroptimizerMixin:GetCharSpec(playerName)
    if not playerName then return nil end
    local charData = self.characters[playerName]
    return charData and charData.spec or nil
end

--- Get the baseline DPS from the character's report
-- @param playerName string - "Name-Realm" format
-- @return number|nil
function DroptimizerMixin:GetCharBaseline(playerName)
    if not playerName then return nil end
    local charData = self.characters[playerName]
    return charData and charData.baseline or nil
end

--- Get seconds since the last desktop sync
-- @return number|nil - Seconds since sync, or nil if never synced
function DroptimizerMixin:GetDataAge()
    if not self.generatedAt then return nil end
    return time() - self.generatedAt
end

--- Get the data source identifier
-- @return string
function DroptimizerMixin:GetSource()
    return self.source or "raidbots.com"
end

--- Get the data format version
-- @return number|nil
function DroptimizerMixin:GetVersion()
    return self.version
end
