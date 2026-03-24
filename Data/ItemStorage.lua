--[[--------------------------------------------------------------------
    Loothing - Loot Council Addon for WoW 12.0+
    ItemStorage - Enhanced item tracking with trade window monitoring
----------------------------------------------------------------------]]

local _, ns = ...
local Loolib = LibStub("Loolib")
local Loothing = ns.Addon
local Utils = ns.Utils
local SavedVariables = Loolib.Data.SavedVariables
local TooltipScan = ns.TooltipScan
local C_Timer = C_Timer

--[[--------------------------------------------------------------------
    ItemStorageMixin

    Provides enhanced item tracking beyond TradeQueue. Tracks items in
    player's bags with trade time remaining, supports "award later"
    functionality, and watches for items appearing in bags.

    Features:
    - Track items with trade window countdown
    - Support for TO_TRADE, AWARD_LATER, and TEMP item types
    - Watch for items appearing in bags (with retry logic)
    - Automatic cleanup of expired items
    - Persistence to SavedVariables

    Usage:
        local storage = CreateItemStorage()
        local item = storage:New(itemLink, "TO_TRADE", { winner = playerName })
        local bag, slot, timeRemaining = storage:FindInBags(itemLink)
        storage:WatchForItem(itemLink, onFound, onFail, 3)
----------------------------------------------------------------------]]

local ItemStorageMixin = Loolib.CreateFromMixins(Loolib.CallbackRegistryMixin)
ns.ItemStorageMixin = ItemStorageMixin

local ITEM_STORAGE_EVENTS = {
    "OnItemAdded",
    "OnItemRemoved",
    "OnItemFound",
    "OnItemExpired",
}

-- How long to wait between attempts when watching for items
local ITEM_WATCH_DELAY = 1.0

--[[--------------------------------------------------------------------
    Item Types

    TO_TRADE - Items that should be traded to another player (must be in bags)
    AWARD_LATER - Items saved for later session (can be out of bags)
    TEMP - Temporary tracking (must be in bags)
----------------------------------------------------------------------]]

ItemStorageMixin.AcceptedTypes = {
    ["TO_TRADE"] = {
        bagged = true,  -- Must be in player's bags
    },
    ["AWARD_LATER"] = {
        bagged = false, -- Can be out of bags
    },
    ["TEMP"] = {
        bagged = true,  -- Must be in player's bags
    },
}

--[[--------------------------------------------------------------------
    Item Class

    Represents a tracked item with trade time information.

    Fields:
    - type: Item type (TO_TRADE, AWARD_LATER, TEMP)
    - link: Item link string
    - inBags: Boolean, true if item is currently in bags
    - timeAdded: Timestamp when item was first tracked
    - timeUpdated: Timestamp when timeRemaining was last updated
    - timeRemaining: Seconds remaining for trade window (when last updated)
    - args: User-provided data (table)
----------------------------------------------------------------------]]

local ItemClass = {}
ItemClass.__index = ItemClass

--- Get actual time remaining (accounts for elapsed time since last update)
-- @return number - Seconds remaining
function ItemClass:GetTimeRemaining()
    if not self.inBags then
        return 0
    end

    -- Update from bags
    local storage = ItemStorageMixin._instance
    if storage then
        storage:UpdateItemTime(self)
    end

    -- Calculate actual remaining time
    local elapsed = time() - self.timeUpdated
    return math.max(0, self.timeRemaining - elapsed)
end

--- Update time from current bag position
-- @param timeRemaining number - New time remaining value
function ItemClass:SetUpdateTime(timeRemaining)
    self.timeUpdated = time()

    -- Handle special cases
    if not timeRemaining or timeRemaining == 0 then
        self.timeRemaining = 0
    elseif timeRemaining == math.huge then
        -- Store BoEs (math.huge) as 24 hours
        self.timeRemaining = 86400
    else
        self.timeRemaining = timeRemaining
    end
end

--- Store item to SavedVariables
function ItemClass:Store()
    local storage = ItemStorageMixin._instance
    if storage then
        storage:StoreItem(self)
    end
    return self
end

--- Remove item from SavedVariables
function ItemClass:Unstore()
    local storage = ItemStorageMixin._instance
    if storage then
        storage:UnstoreItem(self)
    end
    return self
end

--- Check if item is safe to remove (not being watched)
-- @return boolean
function ItemClass:IsSafeToRemove()
    return not self.args.itemWatch
end

--- String representation
function ItemClass:__tostring()
    return self.link or "Unknown Item"
end

--[[--------------------------------------------------------------------
    Storage Initialization
----------------------------------------------------------------------]]

--- Initialize the item storage
function ItemStorageMixin:Init()
    Loolib.CallbackRegistryMixin.OnLoad(self)
    self:GenerateCallbackEvents(ITEM_STORAGE_EVENTS)

    -- Storage arrays
    self.items = {}  -- Active tracked items
    self.pendingItemWatches = {}
    self.pendingItemWatchOrder = {}
    self.nextItemWatchID = 0
    self.itemWatchTicker = nil
    self.itemWatchEventFrame = self.itemWatchEventFrame or CreateFrame("Frame")
    self.itemWatchEventFrame:RegisterEvent("BAG_UPDATE_DELAYED")
    self.itemWatchEventFrame:SetScript("OnEvent", function()
        self:ProcessPendingItemWatches(false)
    end)

    -- Set singleton reference for ItemClass methods
    ItemStorageMixin._instance = self

    Loothing:Debug("ItemStorage initialized")
end

--[[--------------------------------------------------------------------
    Item Management
----------------------------------------------------------------------]]

--- Create a new tracked item
-- @param itemLink string - Item link
-- @param itemType string - Type: TO_TRADE, AWARD_LATER, TEMP
-- @param ... any - User data (stored in item.args as table)
-- @return table - Item object
function ItemStorageMixin:New(itemLink, itemType, ...)
    if not itemType then
        itemType = "TEMP"
    end

    if not self.AcceptedTypes[itemType] then
        error(string.format("Invalid item type: %s. Valid types: TO_TRADE, AWARD_LATER, TEMP", tostring(itemType)))
    end

    -- Find item in bags
    local bag, slot, timeRemaining = self:FindInBags(itemLink)

    -- Create item object
    local item = setmetatable({
        type = itemType,
        link = itemLink,
        inBags = bag and slot and true or false,
        timeAdded = time(),
        timeUpdated = time(),
        timeRemaining = 0,
        args = {},
    }, ItemClass)

    -- Store user args
    local userArgs = ...
    if type(userArgs) == "table" then
        item.args = userArgs
    elseif userArgs ~= nil then
        item.args = { ... }
    end

    -- Set time from bags (or default to 6 hours if not found)
    item:SetUpdateTime(timeRemaining or 21600)

    -- Add to active items
    table.insert(self.items, item)

    Loothing:Debug("ItemStorage:New", itemLink, itemType, string.format("%.1fh", item.timeRemaining / 3600))

    self:TriggerEvent("OnItemAdded", item)

    return item
end

--- Remove an item from storage
-- @param itemOrLink table|string - Item object or item link
-- @return boolean - True if removed
function ItemStorageMixin:RemoveItem(itemOrLink)
    local item = self:GetItem(itemOrLink)
    if not item then
        return false
    end

    -- Check if safe to remove
    if not item:IsSafeToRemove() then
        Loothing:Debug("ItemStorage:RemoveItem - item is being watched, skipping")
        return false
    end

    -- Remove from active items
    for i, storedItem in ipairs(self.items) do
        if storedItem == item then
            table.remove(self.items, i)
            self:TriggerEvent("OnItemRemoved", item)
            Loothing:Debug("ItemStorage:RemoveItem", item.link)
            return true
        end
    end

    return false
end

--- Get a specific item
-- @param itemOrLink table|string - Item object or item link
-- @param itemType string|nil - Optional type filter
-- @return table|nil - Item object or nil
function ItemStorageMixin:GetItem(itemOrLink, itemType)
    -- If already an item object, return it
    if type(itemOrLink) == "table" and itemOrLink.link then
        return itemOrLink
    end

    -- Search by link
    local itemLink = itemOrLink
    for _, item in ipairs(self.items) do
        if self:ItemLinksMatch(item.link, itemLink) then
            if not itemType or item.type == itemType then
                return item
            end
        end
    end

    return nil
end

--- Get all items of a specific type
-- @param itemType string - Type: TO_TRADE, AWARD_LATER, TEMP
-- @return table - Array of items
function ItemStorageMixin:GetAllOfType(itemType)
    local results = {}
    for _, item in ipairs(self.items) do
        if item.type == itemType then
            table.insert(results, item)
        end
    end
    return results
end

--- Get all tracked items
-- @return table - Array of items
function ItemStorageMixin:GetAllItems()
    return self.items
end

--- Remove expired items (trade window has passed)
-- @return number - Number of items removed
function ItemStorageMixin:RemoveExpired()
    local removed = 0

    for i = #self.items, 1, -1 do
        local item = self.items[i]
        local timeRemaining = item:GetTimeRemaining()

        if timeRemaining <= 0 and item:IsSafeToRemove() then
            table.remove(self.items, i)
            self:TriggerEvent("OnItemExpired", item)
            removed = removed + 1
            Loothing:Debug("ItemStorage:RemoveExpired", item.link)
        end
    end

    return removed
end

--- Remove all items of a specific type
-- @param itemType string - Type to remove
function ItemStorageMixin:RemoveAllOfType(itemType)
    for i = #self.items, 1, -1 do
        if self.items[i].type == itemType and self.items[i]:IsSafeToRemove() then
            table.remove(self.items, i)
        end
    end
end

--[[--------------------------------------------------------------------
    Bag Scanning
----------------------------------------------------------------------]]

--- Find an item in the player's bags
-- @param itemLink string - Item link to find
-- @param skip table|nil - Array of {container, slot} positions to skip
-- @return number|nil, number|nil, number|nil - bag, slot, tradeTimeRemaining
function ItemStorageMixin:FindInBags(itemLink, skip)
    if not itemLink or itemLink == "" then
        return nil, nil, nil
    end

    local foundBag, foundSlot, foundTime = nil, nil, nil

    for bag = 0, NUM_BAG_SLOTS do
        local numSlots = C_Container.GetContainerNumSlots(bag)
        for slot = 1, numSlots do
            -- Skip this position if requested
            if not self:ShouldSkipSlot(skip, bag, slot) then
                local bagItemLink = C_Container.GetContainerItemLink(bag, slot)

                if bagItemLink and self:ItemLinksMatch(itemLink, bagItemLink) then
                    foundBag = bag
                    foundSlot = slot

                    -- Get trade time remaining
                    foundTime = self:GetTradeTimeRemainingFromSlot(bag, slot)

                    -- If item is tradeable, we found the right one
                    if foundTime and foundTime > 0 then
                        return foundBag, foundSlot, foundTime
                    end
                end
            end
        end
    end

    -- Return last found position even if not tradeable
    return foundBag, foundSlot, foundTime
end

--- Get trade time remaining for an item
-- @param item table|string - Item object or link
-- @return number - Seconds remaining (0 if expired or not tradeable)
function ItemStorageMixin:GetTradeTimeRemaining(item)
    local itemLink = type(item) == "table" and item.link or item
    local bag, slot = self:FindInBags(itemLink)

    if not bag or not slot then
        return 0
    end

    return self:GetTradeTimeRemainingFromSlot(bag, slot) or 0
end

--- Get trade time remaining from a specific bag slot
-- @param bag number - Bag index
-- @param slot number - Slot index
-- @return number|nil - Seconds remaining, or nil if not tradeable
function ItemStorageMixin:GetTradeTimeRemainingFromSlot(bag, slot)
    if TooltipScan then
        return TooltipScan:GetContainerItemTradeTimeRemaining(bag, slot)
    end
    return nil
end

--- Parse trade time from tooltip
-- Handles multiple locale time formats. Uses TradeQueue's tooltip parser
-- if available, otherwise falls back to own parsing.
-- @param bag number - Bag index
-- @param slot number - Slot index
-- @return number|nil - Seconds remaining, or nil
function ItemStorageMixin:ParseTradeTimeFromTooltip(bag, slot)
    if TooltipScan then
        return TooltipScan:GetContainerItemTradeTimeRemaining(bag, slot)
    end
    return nil
end

--- Update an item's time from current bag position
-- @param item table - Item object
function ItemStorageMixin:UpdateItemTime(item)
    if not item.inBags then
        return
    end

    local bag, slot, timeRemaining = self:FindInBags(item.link)
    if bag and slot and timeRemaining then
        item:SetUpdateTime(timeRemaining)
    end
end

--[[--------------------------------------------------------------------
    Item Watching

    Poll for an item appearing in bags over multiple attempts.
----------------------------------------------------------------------]]

--- Watch for an item to appear in bags
-- @param itemLink string - Item link to watch for
-- @param onFound function|nil - Callback(item, bag, slot, time) when found
-- @param onFail function|nil - Callback(item) when max attempts reached
-- @param maxAttempts number|nil - Max polling attempts (default: 3)
function ItemStorageMixin:WatchForItem(itemLink, onFound, onFail, maxAttempts)
    maxAttempts = maxAttempts or 3
    local targetItemID = Utils.GetItemID(itemLink)
    if not targetItemID then
        if onFail then
            onFail()
        end
        return
    end

    -- Create temporary item for tracking
    local item = self:New(itemLink, "TEMP", {
        itemWatch = {
            maxAttempts = maxAttempts,
            currentAttempt = 1,
            onFound = onFound or function() end,
            onFail = onFail or function() end,
            targetItemID = targetItemID,
        }
    })

    Loothing:Debug("ItemStorage:WatchForItem", itemLink, "attempts:", maxAttempts)

    self.nextItemWatchID = self.nextItemWatchID + 1
    local watchID = self.nextItemWatchID
    self.pendingItemWatches[watchID] = item
    self.pendingItemWatchOrder[#self.pendingItemWatchOrder + 1] = watchID
    self:EnsureItemWatchTicker()
end

function ItemStorageMixin:EnsureItemWatchTicker()
    if self.itemWatchTicker or #self.pendingItemWatchOrder == 0 then
        return
    end

    self.itemWatchTicker = C_Timer.NewTicker(ITEM_WATCH_DELAY, function()
        self:ProcessPendingItemWatches(true)
    end)
end

function ItemStorageMixin:StopItemWatchTickerIfIdle()
    if self.itemWatchTicker and #self.pendingItemWatchOrder == 0 then
        self.itemWatchTicker:Cancel()
        self.itemWatchTicker = nil
    end
end

function ItemStorageMixin:ProcessPendingItemWatches(countAttempt)
    if #self.pendingItemWatchOrder == 0 then
        self:StopItemWatchTickerIfIdle()
        return
    end

    local remaining = {}
    local pendingItemIDs = {}
    local foundByItemID = {}

    for _, watchID in ipairs(self.pendingItemWatchOrder) do
        local item = self.pendingItemWatches[watchID]
        local watchData = item and item.args and item.args.itemWatch
        if watchData and watchData.targetItemID then
            pendingItemIDs[watchData.targetItemID] = true
        end
    end

    for bag = 0, NUM_BAG_SLOTS do
        local numSlots = C_Container.GetContainerNumSlots(bag)
        for slot = 1, numSlots do
            local bagItemLink = C_Container.GetContainerItemLink(bag, slot)
            local foundID = bagItemLink and Utils.GetItemID(bagItemLink)
            if foundID and pendingItemIDs[foundID] and not foundByItemID[foundID] then
                foundByItemID[foundID] = {
                    bag = bag,
                    slot = slot,
                    timeRemaining = self:GetTradeTimeRemainingFromSlot(bag, slot),
                }
            end
        end
    end

    for _, watchID in ipairs(self.pendingItemWatchOrder) do
        local item = self.pendingItemWatches[watchID]
        local watchData = item and item.args and item.args.itemWatch

        if item and watchData then
            local found = foundByItemID[watchData.targetItemID]
            local bag = found and found.bag or nil
            local slot = found and found.slot or nil
            local timeRemaining = found and found.timeRemaining or nil

            if bag and slot then
                item.inBags = true
                item:SetUpdateTime(timeRemaining or 0)
                item.timeAdded = time()

                Loothing:Debug("ItemStorage:WatchForItem - found", item.link, "at", bag, slot)

                if watchData.onFound then
                    watchData.onFound(item, bag, slot, timeRemaining)
                end

                self:TriggerEvent("OnItemFound", item, bag, slot, timeRemaining)
                item.args.itemWatch = nil
                self.pendingItemWatches[watchID] = nil
            else
                if countAttempt then
                    watchData.currentAttempt = watchData.currentAttempt + 1
                end

                if countAttempt and watchData.currentAttempt > watchData.maxAttempts then
                    Loothing:Debug("ItemStorage:WatchForItem - failed after", watchData.maxAttempts, "attempts")
                    if watchData.onFail then
                        watchData.onFail(item)
                    end
                    item.args.itemWatch = nil
                    self.pendingItemWatches[watchID] = nil
                    self:RemoveItem(item)
                else
                    remaining[#remaining + 1] = watchID
                end
            end
        end
    end

    self.pendingItemWatchOrder = remaining
    self:StopItemWatchTickerIfIdle()
end

--[[--------------------------------------------------------------------
    Persistence (SavedVariables)
----------------------------------------------------------------------]]

--- Get the item storage array from SavedVariables (global scope)
-- Owner key prevents cross-character bleed
-- @return table - The storage array
function ItemStorageMixin:GetStorageTable()
    local currentOwner = Utils and Utils.GetPlayerFullName and Utils.GetPlayerFullName()

    if Loothing and Loothing.Settings and Loothing.Settings.GetGlobalValue then
        local storage = Loothing.Settings:GetGlobalValue("itemStorage")
        if not storage then
            storage = { _owner = currentOwner }
            Loothing.Settings:SetGlobalValue("itemStorage", storage)
        end
        -- Discard storage from a different character
        if storage._owner and currentOwner and storage._owner ~= currentOwner then
            storage = { _owner = currentOwner }
            Loothing.Settings:SetGlobalValue("itemStorage", storage)
        end
        -- Stamp owner if not yet set
        if not storage._owner and currentOwner then
            storage._owner = currentOwner
        end
        return storage
    end

    local store = SavedVariables.GetAddonData("Loothing", true)
    store.global = store.global or {}
    if not store.global.itemStorage then
        store.global.itemStorage = { _owner = currentOwner }
    end
    if store.global.itemStorage._owner and currentOwner and store.global.itemStorage._owner ~= currentOwner then
        store.global.itemStorage = { _owner = currentOwner }
    end
    return store.global.itemStorage
end

--- Store an item to SavedVariables (global scope)
-- @param item table - Item object
function ItemStorageMixin:StoreItem(item)
    local storage = self:GetStorageTable()

    -- Check if already stored
    for i, stored in ipairs(storage) do
        if self:ItemLinksMatch(stored.link, item.link) and stored.type == item.type then
            -- Update existing entry
            storage[i] = self:SerializeItem(item)
            return
        end
    end

    -- Add new entry
    table.insert(storage, self:SerializeItem(item))
end

--- Remove an item from SavedVariables (global scope)
-- @param item table - Item object
function ItemStorageMixin:UnstoreItem(item)
    local storage = self:GetStorageTable()

    for i = #storage, 1, -1 do
        local stored = storage[i]
        if self:ItemLinksMatch(stored.link, item.link) and stored.type == item.type then
            table.remove(storage, i)
        end
    end
end

--- Initialize from SavedVariables (call on PLAYER_LOGIN)
function ItemStorageMixin:InitFromSavedVariables()
    local storage = self:GetStorageTable()

    if not storage or #storage == 0 then
        return
    end

    local loaded = 0
    local expired = 0
    local currentTime = time()

    for i = #storage, 1, -1 do
        local stored = storage[i]

        -- Validate item has required fields
        if not stored.link or not stored.type then
            table.remove(storage, i)
            expired = expired + 1
        else
            -- Check if type requires item to be in bags
            local typeInfo = self.AcceptedTypes[stored.type]
            local needsBagged = typeInfo and typeInfo.bagged

            -- Check if still in bags (if required)
            local bag, slot, timeRemaining = self:FindInBags(stored.link)
            local inBags = bag and slot and true or false

            if needsBagged and not inBags then
                -- Required to be in bags but not found
                table.remove(storage, i)
                expired = expired + 1
            else
                -- Restore item
                local item = setmetatable({
                    type = stored.type,
                    link = stored.link,
                    inBags = inBags,
                    timeAdded = stored.timeAdded or currentTime,
                    timeUpdated = stored.timeUpdated or currentTime,
                    timeRemaining = stored.timeRemaining or 0,
                    args = stored.args or {},
                }, ItemClass)

                -- Update time from bags if found
                if inBags and timeRemaining then
                    item:SetUpdateTime(timeRemaining)
                end

                table.insert(self.items, item)
                loaded = loaded + 1
            end
        end
    end

    Loothing:Debug("ItemStorage:InitFromSavedVariables - loaded:", loaded, "expired:", expired)
end

--- Serialize item for storage
-- @param item table - Item object
-- @return table - Serialized data
function ItemStorageMixin:SerializeItem(item)
    return {
        type = item.type,
        link = item.link,
        timeAdded = item.timeAdded,
        timeUpdated = item.timeUpdated,
        timeRemaining = item.timeRemaining,
        args = item.args,
    }
end

--[[--------------------------------------------------------------------
    Utilities
----------------------------------------------------------------------]]

--- Compare two item links (ignores bonus IDs, modifiers, etc.)
-- @param link1 string - First item link
-- @param link2 string - Second item link
-- @return boolean - True if same item
function ItemStorageMixin:ItemLinksMatch(link1, link2)
    if not link1 or not link2 then
        return false
    end

    local id1 = Utils.GetItemID(link1)
    local id2 = Utils.GetItemID(link2)

    return id1 and id2 and id1 == id2
end

--- Check if a bag slot should be skipped
-- @param skip table|nil - Array of {container, slot} positions
-- @param bag number - Bag index
-- @param slot number - Slot index
-- @return boolean
function ItemStorageMixin:ShouldSkipSlot(skip, bag, slot)
    if not skip then
        return false
    end

    for _, skipPos in ipairs(skip) do
        if skipPos.container == bag and skipPos.slot == slot then
            return true
        end
    end

    return false
end

--[[--------------------------------------------------------------------
    Factory
----------------------------------------------------------------------]]

--- Create a new item storage instance
-- @return table - ItemStorage instance
local function CreateItemStorage()
    local storage = Loolib.CreateFromMixins(ItemStorageMixin)
    storage:Init()
    return storage
end

ns.CreateItemStorage = CreateItemStorage
