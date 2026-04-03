--[[--------------------------------------------------------------------
    Loothing - Loot Council Addon for WoW 12.0+
    PlayerIntel - Desktop exchange player intel data reader
    Provides M+ activity, parse data, attendance, loot history,
    and alt loot for council voting decisions.
----------------------------------------------------------------------]]

local _, ns = ...
local Loolib = LibStub("Loolib")
local Loothing = ns.Addon
local time = time
local floor = math.floor
local format = string.format

--[[--------------------------------------------------------------------
    PlayerIntelMixin
----------------------------------------------------------------------]]

local PlayerIntelMixin = Loolib.CreateFromMixins(Loolib.CallbackRegistryMixin)
ns.PlayerIntelMixin = PlayerIntelMixin

local PLAYER_INTEL_EVENTS = {
    "OnPlayerIntelLoaded",
    "OnPlayerIntelUpdated",
}

--- Staleness thresholds (seconds)
local STALE_WARNING = 4 * 3600   -- 4 hours
local STALE_CRITICAL = 24 * 3600 -- 24 hours

--- Initialize player intel data reader
function PlayerIntelMixin:Init()
    Loolib.CallbackRegistryMixin.OnLoad(self)
    self:GenerateCallbackEvents(PLAYER_INTEL_EVENTS)

    self.players = {}
    self.generatedAt = nil
    self.raidTier = nil
    self.version = nil

    self:LoadFromSaved()
end

--[[--------------------------------------------------------------------
    Persistence
----------------------------------------------------------------------]]

--- Load player intel data from SavedVariables (written by Tauri desktop app)
function PlayerIntelMixin:LoadFromSaved()
    if not Loothing.Settings then return end

    local exchange = Loothing.Settings:GetGlobalValue("desktopExchange")
    if not exchange or not exchange.playerIntel then return end

    local pi = exchange.playerIntel
    self.players = pi.players or {}
    self.generatedAt = pi.generatedAt
    self.raidTier = pi.raidTier
    self.version = pi.version

    self:TriggerEvent("OnPlayerIntelLoaded")
end

--[[--------------------------------------------------------------------
    Queries
----------------------------------------------------------------------]]

--- Get player intel for a specific player
-- @param playerName string - "Name-Realm" format
-- @return table|nil - Player intel data or nil
function PlayerIntelMixin:Get(playerName)
    if not playerName then return nil end
    return self.players[playerName]
end

--- Check if player intel data has been loaded from the desktop app
-- @return boolean
function PlayerIntelMixin:HasData()
    return self.generatedAt ~= nil and next(self.players) ~= nil
end

--- Get seconds since the last desktop sync
-- @return number|nil - Seconds since sync, or nil if never synced
function PlayerIntelMixin:GetDataAge()
    if not self.generatedAt then return nil end
    return time() - self.generatedAt
end

--- Get a human-readable staleness string and color
-- @return string|nil - "2h ago", "3d ago", etc.
-- @return number, number, number - r, g, b color values
function PlayerIntelMixin:GetStalenessInfo()
    local age = self:GetDataAge()
    if not age then return nil, 0.5, 0.5, 0.5 end

    local text
    if age < 60 then
        text = "Just now"
    elseif age < 3600 then
        text = format("%dm ago", floor(age / 60))
    elseif age < 86400 then
        text = format("%dh ago", floor(age / 3600))
    else
        text = format("%dd ago", floor(age / 86400))
    end

    -- Color: green < 4h, yellow 4-24h, red > 24h
    if age < STALE_WARNING then
        return text, 0.5, 0.8, 0.5
    elseif age < STALE_CRITICAL then
        return text, 0.9, 0.8, 0.2
    else
        return text, 0.9, 0.3, 0.3
    end
end

--- Get the current raid tier name from the intel data
-- @return string|nil
function PlayerIntelMixin:GetRaidTier()
    return self.raidTier
end

--- Get the number of players with intel data
-- @return number
function PlayerIntelMixin:GetPlayerCount()
    local count = 0
    for _ in pairs(self.players) do
        count = count + 1
    end
    return count
end

--- Get formatted M+ summary for a player
-- @param playerName string - "Name-Realm" format
-- @return string|nil - Formatted M+ info line
function PlayerIntelMixin:GetMythicPlusSummary(playerName)
    local intel = self:Get(playerName)
    if not intel then return nil end

    local parts = {}
    if intel.mpWeek then
        if intel.mpWeek.count then
            parts[#parts + 1] = format("%d keys this week", intel.mpWeek.count)
        end
        if intel.mpWeek.highest then
            parts[#parts + 1] = format("Highest: +%d", intel.mpWeek.highest)
        end
    end
    if intel.mpScore then
        parts[#parts + 1] = format("Score: %.0f", intel.mpScore)
    end

    return #parts > 0 and table.concat(parts, "  |  ") or nil
end

--- Get formatted parse summary for a player
-- @param playerName string - "Name-Realm" format
-- @return string|nil - Formatted parse info line
-- @return number, number, number - Trend color (r, g, b)
function PlayerIntelMixin:GetParseSummary(playerName)
    local intel = self:Get(playerName)
    if not intel then return nil, 0.6, 0.6, 0.6 end

    local parts = {}
    if intel.parseAvg then
        parts[#parts + 1] = format("Avg: %.0f", intel.parseAvg)
    end
    if intel.parseBest then
        local bestText = format("Best: %.0f", intel.parseBest)
        if intel.parseBestBoss then
            bestText = bestText .. " (" .. intel.parseBestBoss .. ")"
        end
        parts[#parts + 1] = bestText
    end

    -- Trend indicator
    local trendR, trendG, trendB = 0.6, 0.6, 0.6
    if intel.parseTrend == "up" then
        parts[#parts + 1] = "Trend: \226\150\178"  -- ▲
        trendR, trendG, trendB = 0.3, 0.9, 0.3
    elseif intel.parseTrend == "down" then
        parts[#parts + 1] = "Trend: \226\150\188"  -- ▼
        trendR, trendG, trendB = 0.9, 0.3, 0.3
    elseif intel.parseTrend == "stable" then
        parts[#parts + 1] = "Trend: \226\151\134"  -- ◆
    end

    return #parts > 0 and table.concat(parts, "  |  ") or nil, trendR, trendG, trendB
end

--- Get formatted attendance summary for a player
-- @param playerName string - "Name-Realm" format
-- @return string|nil - Formatted attendance line
function PlayerIntelMixin:GetAttendanceSummary(playerName)
    local intel = self:Get(playerName)
    if not intel then return nil end

    local parts = {}
    if intel.attendance then
        parts[#parts + 1] = format("%.0f%%", intel.attendance * 100)
    end
    if intel.raidCount then
        parts[#parts + 1] = format("%d raids", intel.raidCount)
    end

    return #parts > 0 and ("Attendance: " .. table.concat(parts, "  |  ")) or nil
end

--- Get formatted loot history for a player (compact, last N items)
-- @param playerName string - "Name-Realm" format
-- @param maxItems number? - Maximum items to return (default 5)
-- @return table|nil - Array of formatted loot strings
function PlayerIntelMixin:GetRecentLoot(playerName, maxItems)
    local intel = self:Get(playerName)
    if not intel or not intel.loot then return nil end

    maxItems = maxItems or 5
    local lines = {}
    for i = 1, math.min(#intel.loot, maxItems) do
        local item = intel.loot[i]
        local text = format("[%s] %s (%s)", item.date or "?", item.name or "?", item.resp or "?")
        if item.boss then
            text = text .. " - " .. item.boss
        end
        if item.diff then
            text = text .. " " .. item.diff
        end
        lines[#lines + 1] = text
    end

    return #lines > 0 and lines or nil
end

--- Get formatted alt loot summary for a player
-- @param playerName string - "Name-Realm" format
-- @return table|nil - Array of { alt, cls, count, items } tables
function PlayerIntelMixin:GetAltLoot(playerName)
    local intel = self:Get(playerName)
    if not intel or not intel.altLoot then return nil end

    return #intel.altLoot > 0 and intel.altLoot or nil
end
