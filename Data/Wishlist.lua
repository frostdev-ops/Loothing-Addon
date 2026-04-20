--[[--------------------------------------------------------------------
    Loothing - Loot Council Addon for WoW 12.0+
    Wishlist - Desktop exchange wishlist data reader
----------------------------------------------------------------------]]

local _, ns = ...
local Loolib = LibStub("Loolib")
local Loothing = ns.Addon
local Utils = ns.Utils
local time = time

--- Local shim mirroring the pattern used by PlayerIntel/Droptimizer/Roster.
-- Returns nil if Utils or NormalizeName is unavailable (early init) or the
-- input normalizes to nil (secret-value detection in NormalizeName).
local function normalizeKey(name)
    if Utils and Utils.NormalizeName then
        return Utils.NormalizeName(name)
    end
    return name
end

--[[--------------------------------------------------------------------
    WishlistMixin
----------------------------------------------------------------------]]

local WishlistMixin = Loolib.CreateFromMixins(Loolib.CallbackRegistryMixin)
ns.WishlistMixin = WishlistMixin

local WISHLIST_EVENTS = {
    "OnWishlistLoaded",
    "OnWishlistUpdated",
}

--- Initialize wishlist data reader
function WishlistMixin:Init()
    Loolib.CallbackRegistryMixin.OnLoad(self)
    self:GenerateCallbackEvents(WISHLIST_EVENTS)

    self.byItemID = {}
    self.characters = {}
    self.itemDetails = {}
    self.updatedAt = nil

    self:LoadFromSaved()
end

--[[--------------------------------------------------------------------
    Persistence
----------------------------------------------------------------------]]

--- Load wishlist data from SavedVariables (written by Tauri desktop app).
-- `self.characters` is keyed by player name; normalize on load so
-- GetCharacterInfo (which normalizes its input) always hits. See
-- PlayerIntel.lua for the same pattern.
function WishlistMixin:LoadFromSaved()
    if not Loothing.Settings then return end

    local exchange = Loothing.Settings:GetGlobalValue("desktopExchange")
    if not exchange or not exchange.wishlists then return end

    local wl = exchange.wishlists
    self.byItemID = wl.byItemID or {}
    local rawCharacters = wl.characters or {}
    self.characters = {}
    for key, value in pairs(rawCharacters) do
        local normalized = normalizeKey(key)
        if normalized then self.characters[normalized] = value end
    end
    self.itemDetails = wl.itemDetails or {}
    self.updatedAt = wl.updatedAt
    self.sharedBy = wl.sharedBy     -- nil if from own desktop app
    self.sharedAt = wl.sharedAt     -- nil if from own desktop app

    self:TriggerEvent("OnWishlistLoaded")
end

--- Check if data was received via intel share (not from own desktop app)
-- @return boolean
function WishlistMixin:IsSharedData()
    return self.sharedBy ~= nil
end

--- Get sharing metadata
-- @return string|nil sharedBy - Player name who shared
-- @return number|nil sharedAt - Epoch timestamp when shared
function WishlistMixin:GetSharedInfo()
    return self.sharedBy, self.sharedAt
end

--[[--------------------------------------------------------------------
    Queries
----------------------------------------------------------------------]]

--- Get all wishlist entries for an item
-- @param itemID number - Item ID to look up
-- @return table - Array of {playerName, priority, needLevel, isBiS, isOffspec, notes}
function WishlistMixin:GetEntriesForItem(itemID)
    return self.byItemID[itemID] or {}
end

--- Get a specific player's wishlist entry for an item
-- @param itemID number - Item ID to look up
-- @param playerName string - Player name (will be normalized)
-- @return table|nil - Entry or nil
function WishlistMixin:GetPlayerEntryForItem(itemID, playerName)
    if not playerName then return nil end
    local entries = self.byItemID[itemID]
    if not entries then return nil end

    local target = normalizeKey(playerName)
    if not target then return nil end
    for _, entry in ipairs(entries) do
        if normalizeKey(entry.playerName) == target then
            return entry
        end
    end
    return nil
end

--- Check if wishlist data has been loaded from the desktop app
-- @return boolean
function WishlistMixin:HasData()
    return self.updatedAt ~= nil and next(self.byItemID) ~= nil
end

--- Get seconds since the last desktop sync
-- @return number|nil - Seconds since sync, or nil if never synced
function WishlistMixin:GetTimeSinceSync()
    if not self.updatedAt then return nil end
    return time() - self.updatedAt
end

--- Get character metadata
-- @param playerName string - Player name (will be normalized)
-- @return table|nil - {characterId, listName, totalItems, fulfilledItems}
function WishlistMixin:GetCharacterInfo(playerName)
    if not playerName then return nil end
    local key = normalizeKey(playerName)
    if not key then return nil end
    return self.characters[key]
end

--- Get item details from the desktop app data (name, quality, source, etc.)
-- @param itemID number|string - Item ID to look up
-- @return table|nil - {name, quality, itemLevel, slot, source, sourceBoss, sourceType, difficulty}
function WishlistMixin:GetItemDetails(itemID)
    if not itemID then return nil end
    return self.itemDetails[tostring(itemID)] or self.itemDetails[itemID]
end

--- Get every item on a player's wishlist with its entry metadata.
-- Iterates `byItemID` once and collects entries matching the normalized
-- player name. Returns an array sorted by priority ascending (1 is highest).
-- @param playerName string - Player name (will be normalized)
-- @return table - Array of { itemID, priority, needLevel, isBiS, isOffspec, notes }
function WishlistMixin:GetItemsForPlayer(playerName)
    if not playerName then return {} end
    local target = normalizeKey(playerName)
    if not target then return {} end
    local items = {}
    for itemID, entries in pairs(self.byItemID) do
        for _, entry in ipairs(entries) do
            if normalizeKey(entry.playerName) == target then
                items[#items + 1] = {
                    itemID    = itemID,
                    priority  = entry.priority,
                    needLevel = entry.needLevel,
                    isBiS     = entry.isBiS,
                    isOffspec = entry.isOffspec,
                    notes     = entry.notes,
                }
                break
            end
        end
    end
    table.sort(items, function(a, b)
        local pa = a.priority or 999
        local pb = b.priority or 999
        if pa ~= pb then return pa < pb end
        return (a.itemID or 0) < (b.itemID or 0)
    end)
    return items
end

--- Get count of items with wishlist entries for a given player
-- @param playerName string - Player name (will be normalized)
-- @return number
function WishlistMixin:GetPlayerItemCount(playerName)
    if not playerName then return 0 end
    playerName = normalizeKey(playerName)
    if not playerName then return 0 end
    local count = 0
    for _, entries in pairs(self.byItemID) do
        for _, entry in ipairs(entries) do
            if normalizeKey(entry.playerName) == playerName then
                count = count + 1
                break
            end
        end
    end
    return count
end
