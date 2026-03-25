--[[--------------------------------------------------------------------
    Loothing - Loot Council Addon for WoW 12.0+
    Wishlist - Desktop exchange wishlist data reader
----------------------------------------------------------------------]]

local _, ns = ...
local Loolib = LibStub("Loolib")
local Loothing = ns.Addon
local Utils = ns.Utils
local time = time

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
    self.updatedAt = nil

    self:LoadFromSaved()
end

--[[--------------------------------------------------------------------
    Persistence
----------------------------------------------------------------------]]

--- Load wishlist data from SavedVariables (written by Tauri desktop app)
function WishlistMixin:LoadFromSaved()
    if not Loothing.Settings then return end

    local exchange = Loothing.Settings:GetGlobalValue("desktopExchange")
    if not exchange or not exchange.wishlists then return end

    local wl = exchange.wishlists
    self.byItemID = wl.byItemID or {}
    self.characters = wl.characters or {}
    self.updatedAt = wl.updatedAt

    self:TriggerEvent("OnWishlistLoaded")
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
    local entries = self.byItemID[itemID]
    if not entries then return nil end

    playerName = Utils.NormalizeName(playerName)
    for _, entry in ipairs(entries) do
        if Utils.NormalizeName(entry.playerName) == playerName then
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
    playerName = Utils.NormalizeName(playerName)
    return self.characters[playerName]
end

--- Get count of items with wishlist entries for a given player
-- @param playerName string - Player name (will be normalized)
-- @return number
function WishlistMixin:GetPlayerItemCount(playerName)
    playerName = Utils.NormalizeName(playerName)
    local count = 0
    for _, entries in pairs(self.byItemID) do
        for _, entry in ipairs(entries) do
            if Utils.NormalizeName(entry.playerName) == playerName then
                count = count + 1
                break
            end
        end
    end
    return count
end
