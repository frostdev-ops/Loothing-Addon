--[[--------------------------------------------------------------------
    Loothing - Loot Council Addon for WoW 12.0+
    TradeQueue - Manages items awaiting trade to winners
----------------------------------------------------------------------]]

local Loolib = LibStub("Loolib")

--[[--------------------------------------------------------------------
    LoothingTradeQueueMixin

    Manages the queue of items that need to be traded to winners.
    Tracks 2-hour trade window and persists to SavedVariables.
----------------------------------------------------------------------]]

LoothingTradeQueueMixin = LoolibCreateFromMixins(LoolibCallbackRegistryMixin)

local TRADE_QUEUE_EVENTS = {
    "OnItemQueued",
    "OnItemRemoved",
    "OnItemTraded",
    "OnTradeWindowOpened",
}

-- Trade window is 2 hours
local TRADE_WINDOW_SECONDS = 2 * 60 * 60

--- Initialize the trade queue
function LoothingTradeQueueMixin:Init()
    LoolibCallbackRegistryMixin.OnLoad(self)
    self:GenerateCallbackEvents(TRADE_QUEUE_EVENTS)

    -- Queue storage (DataProvider)
    local Data = Loolib:GetModule("Data")
    self.queue = Data.CreateDataProvider()

    -- Track current trade state
    self.tradeTarget = nil
    self.isTrading = false
    self.itemsInTradeWindow = {}

    -- Register for WoW trade events
    self:RegisterEvents()
end

--[[--------------------------------------------------------------------
    Event Registration
----------------------------------------------------------------------]]

--- Register for trade-related events
function LoothingTradeQueueMixin:RegisterEvents()
    local Events = Loothing.Loolib.Events
    if not Events or not Events.Registry then return end

    -- Trade window events
    Events.Registry:RegisterEventCallback("TRADE_SHOW", function()
        self:OnTradeShow()
    end, self)

    Events.Registry:RegisterEventCallback("TRADE_CLOSED", function()
        self:OnTradeClosed()
    end, self)

    Events.Registry:RegisterEventCallback("TRADE_ACCEPT_UPDATE", function(playerAccepted, targetAccepted)
        self:OnTradeAcceptUpdate(playerAccepted, targetAccepted)
    end, self)

    Events.Registry:RegisterEventCallback("UI_INFO_MESSAGE", function(messageType, message)
        self:OnUIInfoMessage(messageType, message)
    end, self)
end

--[[--------------------------------------------------------------------
    Queue Management
----------------------------------------------------------------------]]

--- Add an item to the trade queue
-- @param itemGUID string - Item GUID
-- @param itemLink string - Item link
-- @param winner string - Winner's name (full name with realm)
-- @param awardTime number - Timestamp when awarded
-- @return table - The queue entry
function LoothingTradeQueueMixin:AddToQueue(itemGUID, itemLink, winner, awardTime)
    winner = LoothingUtils.NormalizeName(winner)
    awardTime = awardTime or time()

    -- Check if already queued
    local existing = self:GetQueuedItem(itemGUID)
    if existing then
        -- Update winner if changed (reawarding)
        existing.winner = winner
        existing.awardTime = awardTime
        existing.traded = false
        self.queue:UpdateElement(existing)
        return existing
    end

    -- Create queue entry
    local entry = {
        itemGUID = itemGUID,
        itemLink = itemLink,
        winner = winner,
        awardTime = awardTime,
        traded = false,
        tradeTime = nil,
    }

    self.queue:Insert(entry)
    self:TriggerEvent("OnItemQueued", entry)

    -- Save to DB
    self:SaveToDatabase()

    Loothing:Debug("Added to trade queue:", itemLink, "->", winner)
    return entry
end

--- Remove an item from the queue
-- @param itemGUID string - Item GUID
-- @return boolean - True if removed
function LoothingTradeQueueMixin:RemoveFromQueue(itemGUID)
    local entry = self:GetQueuedItem(itemGUID)
    if not entry then
        return false
    end

    self.queue:Remove(entry)
    self:TriggerEvent("OnItemRemoved", entry)
    self:SaveToDatabase()

    Loothing:Debug("Removed from trade queue:", entry.itemLink)
    return true
end

--- Get a queued item by GUID
-- @param itemGUID string - Item GUID
-- @return table|nil - Queue entry or nil
function LoothingTradeQueueMixin:GetQueuedItem(itemGUID)
    for _, entry in self.queue:Enumerate() do
        if entry.itemGUID == itemGUID then
            return entry
        end
    end
    return nil
end

--- Get all items queued for a specific player
-- @param playerName string - Player name (will be normalized)
-- @return table - Array of queue entries
function LoothingTradeQueueMixin:GetPendingForPlayer(playerName)
    playerName = LoothingUtils.NormalizeName(playerName)

    local pending = {}
    for _, entry in self.queue:Enumerate() do
        if not entry.traded and entry.winner == playerName then
            -- Check if still within trade window
            if self:IsWithinTradeWindow(entry) then
                pending[#pending + 1] = entry
            else
                -- Mark as expired (will be cleaned up)
                Loothing:Debug("Trade window expired for:", entry.itemLink)
            end
        end
    end

    return pending
end

--- Get all pending items (not yet traded)
-- @return table - Array of queue entries
function LoothingTradeQueueMixin:GetAllPending()
    local pending = {}
    for _, entry in self.queue:Enumerate() do
        if not entry.traded and self:IsWithinTradeWindow(entry) then
            pending[#pending + 1] = entry
        end
    end
    return pending
end

--- Get all queue entries (for display)
-- @return DataProvider
function LoothingTradeQueueMixin:GetQueue()
    return self.queue
end

--- Check if an item is within the 2-hour trade window
-- @param entry table - Queue entry
-- @return boolean - True if still tradable
function LoothingTradeQueueMixin:IsWithinTradeWindow(entry)
    local elapsed = time() - entry.awardTime
    return elapsed < TRADE_WINDOW_SECONDS
end

--- Get time remaining for an item's trade window
-- @param entry table - Queue entry
-- @return number - Seconds remaining, or 0 if expired
function LoothingTradeQueueMixin:GetTimeRemaining(entry)
    local elapsed = time() - entry.awardTime
    local remaining = TRADE_WINDOW_SECONDS - elapsed
    return math.max(0, remaining)
end

--- Clear expired entries from the queue
-- @return number - Number of entries removed
function LoothingTradeQueueMixin:CleanupExpired()
    local removed = self.queue:RemoveByPredicate(function(entry)
        return not self:IsWithinTradeWindow(entry)
    end)

    if removed > 0 then
        self:SaveToDatabase()
        Loothing:Debug("Cleaned up", removed, "expired trade queue entries")
    end

    return removed
end

--[[--------------------------------------------------------------------
    Trade Window Handling
----------------------------------------------------------------------]]

--- Handle TRADE_SHOW event
function LoothingTradeQueueMixin:OnTradeShow()
    -- Get trade target from Blizzard UI
    local target = TradeFrameRecipientNameText:GetText()
    if not target or target == "" then
        target = UnitName("NPC") or "Unknown"
    end

    -- Remove "(*)" for cross-realm
    if target:find("(*)") then
        target = string.sub(target, 1, -4)
    end

    self.tradeTarget = LoothingUtils.NormalizeName(target)
    self.isTrading = true
    wipe(self.itemsInTradeWindow)

    Loothing:Debug("Trade opened with:", self.tradeTarget)

    -- Check if we have items for this player
    local pending = self:GetPendingForPlayer(self.tradeTarget)
    local count = #pending

    if count > 0 then
        -- Get auto-trade setting
        local autoTrade = Loothing.Settings and Loothing.Settings:GetAutoTrade()

        if autoTrade then
            Loothing:Debug("Auto-adding", count, "items to trade")
            self:AddItemsToTradeWindow(pending)
        else
            -- Show confirmation
            Loothing:Print(string.format("You have %d item(s) to trade to %s. Click items to add them to the trade window.", count, LoothingUtils.GetShortName(self.tradeTarget)))
        end

        -- Trigger event for UI updates
        self:TriggerEvent("OnTradeWindowOpened", self.tradeTarget, pending)
    end
end

--- Handle TRADE_CLOSED event
function LoothingTradeQueueMixin:OnTradeClosed()
    Loothing:Debug("Trade closed")
    self.isTrading = false
    self.tradeTarget = nil
    wipe(self.itemsInTradeWindow)
end

--- Handle TRADE_ACCEPT_UPDATE event (record items being traded)
-- @param playerAccepted boolean - Has player accepted
-- @param targetAccepted boolean - Has target accepted
function LoothingTradeQueueMixin:OnTradeAcceptUpdate(playerAccepted, targetAccepted)
    if playerAccepted == 1 or targetAccepted == 1 then
        -- Record what we're trading
        wipe(self.itemsInTradeWindow)

        for i = 1, MAX_TRADE_ITEMS - 1 do -- Last slot is "will not be traded"
            local link = GetTradePlayerItemLink(i)
            if link then
                self.itemsInTradeWindow[#self.itemsInTradeWindow + 1] = link
                Loothing:Debug("Recording trade item:", link)
            end
        end
    end
end

--- Handle UI_INFO_MESSAGE event (trade complete)
-- @param messageType number - Message type
-- @param message string - Message text
function LoothingTradeQueueMixin:OnUIInfoMessage(messageType, message)
    if messageType == LE_GAME_ERR_TRADE_COMPLETE then
        Loothing:Debug("Trade completed with:", self.tradeTarget)

        -- Mark traded items as complete
        for _, link in ipairs(self.itemsInTradeWindow) do
            self:MarkItemTraded(link, self.tradeTarget)
        end

        wipe(self.itemsInTradeWindow)
    end
end

--- Add items to the trade window automatically
-- @param items table - Array of queue entries
function LoothingTradeQueueMixin:AddItemsToTradeWindow(items)
    if not self.isTrading then
        Loothing:Debug("Cannot add items - trade window not open")
        return
    end

    -- Add items with a small delay between each
    local delay = 0.1
    for i, entry in ipairs(items) do
        if i > MAX_TRADE_ITEMS - 1 then
            Loothing:Print("Too many items to trade - only first 6 will be added.")
            break
        end

        C_Timer.After(delay * i, function()
            if self.isTrading then
                self:AddSingleItemToTrade(entry)
            end
        end)
    end
end

--- Add a single item to the trade window
-- @param entry table - Queue entry
function LoothingTradeQueueMixin:AddSingleItemToTrade(entry)
    if not self.isTrading then return end

    -- Find the item in bags
    local bag, slot = self:FindItemInBags(entry.itemLink)
    if not bag or not slot then
        Loothing:Print("Could not find item to trade:", entry.itemLink)
        return
    end

    -- Check if item is locked
    local containerInfo = C_Container.GetContainerItemInfo(bag, slot)
    if containerInfo and containerInfo.isLocked then
        Loothing:Print("Item is locked:", entry.itemLink)
        return
    end

    -- Add to trade window
    Loothing:Debug("Adding to trade:", entry.itemLink, bag, slot)
    ClearCursor()
    C_Container.PickupContainerItem(bag, slot)

    -- Find first empty trade slot
    for i = 1, MAX_TRADE_ITEMS - 1 do
        if not GetTradePlayerItemLink(i) then
            ClickTradeButton(i)
            break
        end
    end
end

--- Find an item in the player's bags
-- @param itemLink string - Item link to find
-- @return number, number - Bag and slot, or nil if not found
function LoothingTradeQueueMixin:FindItemInBags(itemLink)
    for bag = 0, NUM_BAG_SLOTS do
        local numSlots = C_Container.GetContainerNumSlots(bag)
        for slot = 1, numSlots do
            local info = C_Container.GetContainerItemInfo(bag, slot)
            if info and info.hyperlink then
                -- Compare item IDs (links may have different bonus IDs)
                local targetID = LoothingUtils.GetItemID(itemLink)
                local foundID = LoothingUtils.GetItemID(info.hyperlink)

                if targetID == foundID then
                    return bag, slot
                end
            end
        end
    end
    return nil, nil
end

--[[--------------------------------------------------------------------
    Trade Completion
----------------------------------------------------------------------]]

--- Mark an item as traded
-- @param itemLink string - Item that was traded
-- @param tradedTo string - Who it was traded to
function LoothingTradeQueueMixin:MarkItemTraded(itemLink, tradedTo)
    tradedTo = LoothingUtils.NormalizeName(tradedTo)

    -- Find matching queue entry
    local itemID = LoothingUtils.GetItemID(itemLink)
    local entry = nil

    for _, queueEntry in self.queue:Enumerate() do
        if not queueEntry.traded then
            local queueItemID = LoothingUtils.GetItemID(queueEntry.itemLink)
            if queueItemID == itemID then
                -- Prefer exact winner match
                if queueEntry.winner == tradedTo then
                    entry = queueEntry
                    break
                elseif not entry then
                    -- Fallback to first matching item
                    entry = queueEntry
                end
            end
        end
    end

    if entry then
        entry.traded = true
        entry.tradeTime = time()
        self.queue:UpdateElement(entry)

        self:TriggerEvent("OnItemTraded", entry, tradedTo)
        self:SaveToDatabase()

        -- Check if traded to correct winner
        if entry.winner == tradedTo then
            Loothing:Print(string.format("Traded %s to %s", entry.itemLink, LoothingUtils.GetShortName(tradedTo)))
        else
            Loothing:Print(string.format("Warning: Traded %s to %s (was awarded to %s)", entry.itemLink, LoothingUtils.GetShortName(tradedTo), LoothingUtils.GetShortName(entry.winner)))
        end
    end
end

--[[--------------------------------------------------------------------
    Persistence (SavedVariables)
----------------------------------------------------------------------]]

--- Load queue from SavedVariables
function LoothingTradeQueueMixin:LoadFromDatabase()
    if not LoothingDB or not LoothingDB.tradeQueue then
        return
    end

    self.queue:Flush()

    for _, entry in ipairs(LoothingDB.tradeQueue) do
        -- Only load entries still within trade window
        if self:IsWithinTradeWindow(entry) then
            self.queue:Insert(entry)
        end
    end

    Loothing:Debug("Loaded", self.queue:GetSize(), "items from trade queue")
end

--- Save queue to SavedVariables
function LoothingTradeQueueMixin:SaveToDatabase()
    if not LoothingDB then
        LoothingDB = {}
    end

    LoothingDB.tradeQueue = {}

    for _, entry in self.queue:Enumerate() do
        -- Only save entries still within trade window
        if self:IsWithinTradeWindow(entry) then
            LoothingDB.tradeQueue[#LoothingDB.tradeQueue + 1] = {
                itemGUID = entry.itemGUID,
                itemLink = entry.itemLink,
                winner = entry.winner,
                awardTime = entry.awardTime,
                traded = entry.traded,
                tradeTime = entry.tradeTime,
            }
        end
    end

    Loothing:Debug("Saved", #LoothingDB.tradeQueue, "items to trade queue")
end

--[[--------------------------------------------------------------------
    Factory
----------------------------------------------------------------------]]

--- Create a new trade queue
-- @return table - TradeQueue instance
function CreateLoothingTradeQueue()
    local queue = LoolibCreateFromMixins(LoothingTradeQueueMixin)
    queue:Init()
    return queue
end
