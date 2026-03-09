--[[--------------------------------------------------------------------
    Loothing - Loot Council Addon for WoW 12.0+
    RollTracker - Track /roll results for loot distribution
----------------------------------------------------------------------]]

local Loolib = LibStub("Loolib")
local CreateFromMixins = Loolib.CreateFromMixins
local Events = Loolib.Events

--[[--------------------------------------------------------------------
    LoothingRollTrackerMixin
----------------------------------------------------------------------]]

LoothingRollTrackerMixin = {}

--- Initialize roll tracker
function LoothingRollTrackerMixin:Init()
    -- Store rolls by player name
    -- { [playerName] = { roll = number, minRoll = number, maxRoll = number, timestamp = number } }
    self.rolls = {}

    -- Register for CHAT_MSG_SYSTEM
    if Events and Events.Registry then
        Events.Registry:RegisterEventCallback("CHAT_MSG_SYSTEM", function(_, text)
            self:OnChatMessage(text)
        end, self)
    end
end

--- Parse roll message from CHAT_MSG_SYSTEM
-- Pattern: "PlayerName rolls 42 (1-100)"
-- @param text string - Chat message text
function LoothingRollTrackerMixin:OnChatMessage(text)
    if not text then return end

    -- Convert to untainted string - CHAT_MSG_SYSTEM text is hardware-tainted
    -- and calling methods on tainted strings errors during combat
    local safeText = tostring(text)

    -- Pattern for roll messages
    -- Handles both "Player rolls X (Y-Z)" and localized versions
    local playerName, roll, minRoll, maxRoll = string.match(safeText, "(.+) rolls (%d+) %((%d+)%-(%d+)%)")

    if not playerName then
        -- Try alternate pattern without "rolls" keyword (for localization)
        playerName, roll, minRoll, maxRoll = string.match(safeText, "(.+)%s+(%d+)%s+%((%d+)%-(%d+)%)")
    end

    if playerName and roll then
        roll = tonumber(roll)
        minRoll = tonumber(minRoll) or 1
        maxRoll = tonumber(maxRoll) or 100

        -- Normalize player name
        playerName = LoothingUtils.NormalizeName(playerName)

        -- Store the roll
        self:RecordRoll(playerName, roll, minRoll, maxRoll)

        Loothing:Debug("Roll tracked:", playerName, roll, string.format("(%d-%d)", minRoll, maxRoll))
    end
end

--- Record a roll for a player
-- @param playerName string
-- @param roll number
-- @param minRoll number
-- @param maxRoll number
function LoothingRollTrackerMixin:RecordRoll(playerName, roll, minRoll, maxRoll)
    playerName = LoothingUtils.NormalizeName(playerName)

    self.rolls[playerName] = {
        roll = roll,
        minRoll = minRoll,
        maxRoll = maxRoll,
        timestamp = time(),
    }

    -- Clean up old rolls (older than 5 minutes)
    self:CleanupOldRolls()

    -- Bridge to Session for auto-add rolls
    if Loothing.Session and Loothing.Session.HandleRollTracked then
        Loothing.Session:HandleRollTracked(playerName, roll, minRoll, maxRoll)
    end
end

--- Get roll for a player
-- @param playerName string
-- @return table|nil - { roll, minRoll, maxRoll, timestamp }
function LoothingRollTrackerMixin:GetRoll(playerName)
    playerName = LoothingUtils.NormalizeName(playerName)
    return self.rolls[playerName]
end

--- Check if player has rolled
-- @param playerName string
-- @return boolean
function LoothingRollTrackerMixin:HasRolled(playerName)
    playerName = LoothingUtils.NormalizeName(playerName)
    return self.rolls[playerName] ~= nil
end

--- Get all current rolls
-- @return table - { [playerName] = rollData }
function LoothingRollTrackerMixin:GetAllRolls()
    return self.rolls
end

--- Clear all rolls
function LoothingRollTrackerMixin:ClearAllRolls()
    wipe(self.rolls)
end

--- Clear roll for a specific player
-- @param playerName string
function LoothingRollTrackerMixin:ClearRoll(playerName)
    playerName = LoothingUtils.NormalizeName(playerName)
    self.rolls[playerName] = nil
end

--- Clean up rolls older than threshold
-- @param maxAge number - Max age in seconds (default 300 = 5 minutes)
function LoothingRollTrackerMixin:CleanupOldRolls(maxAge)
    maxAge = maxAge or 300 -- 5 minutes default

    local now = time()
    local toRemove = {}

    for playerName, rollData in pairs(self.rolls) do
        if now - rollData.timestamp > maxAge then
            toRemove[#toRemove + 1] = playerName
        end
    end

    for _, playerName in ipairs(toRemove) do
        self.rolls[playerName] = nil
    end

    if #toRemove > 0 then
        Loothing:Debug("Cleaned up", #toRemove, "old rolls")
    end
end

--- Request rolls from raid
-- Announces a message asking players to /roll
-- @param itemLink string - Optional item link to include in message
function LoothingRollTrackerMixin:RequestRolls(itemLink)
    local L = Loothing.Locale

    -- Clear previous rolls
    self:ClearAllRolls()

    -- Build message
    local message = L["ROLL_REQUEST"] or "Please /roll for loot"
    if itemLink then
        message = string.format("%s: %s", message, itemLink)
    end

    -- Announce to raid
    if IsInRaid() then
        SendChatMessage(message, "RAID_WARNING")
    elseif IsInGroup() then
        SendChatMessage(message, "PARTY")
    end

    Loothing:Print(L["ROLL_REQUEST_SENT"] or "Roll request sent to raid")
end

--[[--------------------------------------------------------------------
    Singleton Instance
----------------------------------------------------------------------]]

--- Create the RollTracker singleton
-- @return table
function CreateLoothingRollTracker()
    local tracker = CreateFromMixins(LoothingRollTrackerMixin)
    tracker:Init()
    return tracker
end
