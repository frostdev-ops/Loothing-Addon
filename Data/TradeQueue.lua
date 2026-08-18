--[[--------------------------------------------------------------------
    Loothing - Loot Council Addon for WoW 12.0+
    TradeQueue - Manages items awaiting trade to winners
----------------------------------------------------------------------]]

local _, ns = ...
local Loolib = LibStub("Loolib")
local Loothing = ns.Addon
local L = ns.Locale
local Utils = ns.Utils
local CallbackRegistryMixin = Loolib.CallbackRegistryMixin
local CreateFromMixins = Loolib.CreateFromMixins
local Data = Loolib.Data
local Events = Loolib.Events
local SavedVariables = Loolib.Data.SavedVariables
local SecretUtil = Loolib.SecretUtil
local TooltipScan = ns.TooltipScan
local C_Timer = C_Timer

--[[--------------------------------------------------------------------
    TradeQueueMixin

    Manages the queue of items that need to be traded to winners.
    Tracks 2-hour trade window and persists to SavedVariables.
----------------------------------------------------------------------]]

local TradeQueueMixin = CreateFromMixins(CallbackRegistryMixin)
ns.TradeQueueMixin = TradeQueueMixin

local TRADE_QUEUE_EVENTS = {
    "OnItemQueued",
    "OnItemRemoved",
    "OnItemTraded",
    "OnTradeWindowOpened",
}

-- Trade window is 2 hours
local TRADE_WINDOW_SECONDS = 2 * 60 * 60

-- Warning thresholds (seconds remaining)
local TRADE_WARNING_20MIN = 20 * 60
local TRADE_WARNING_5MIN = 5 * 60

-- How often to check trade timers (seconds)
local TRADE_TIMER_CHECK_INTERVAL = 60
local ITEM_WATCH_DELAY = 0.5

-- Resolve trade-complete constant once at load time.
-- WoW 12.0 deprecated LE_ globals; the Enum key varies across builds.
local TRADE_COMPLETE_MSG = LE_GAME_ERR_TRADE_COMPLETE
    or (Enum and Enum.GameError and (
        Enum.GameError.TradeComplete
        or Enum.GameError.ErrTradeComplete
    ))
local TRADE_COMPLETE_TEXT = ERR_TRADE_COMPLETE

local function GetStagedItemLink(staged)
    if type(staged) == "table" then
        return staged.itemLink
    end
    return staged
end

--- Initialize the trade queue
function TradeQueueMixin:Init()
    CallbackRegistryMixin.OnLoad(self)
    self:GenerateCallbackEvents(TRADE_QUEUE_EVENTS)

    -- Queue storage (DataProvider)
    self.queue = Data.CreateDataProvider()

    -- Track current trade state
    self.tradeTarget = nil
    self.isTrading = false
    self.itemsInTradeWindow = {}

    -- Tracks which warnings have already been shown (itemGUID -> { warned20 = bool, warned5 = bool })
    self.warningsSent = {}
    self.pendingBagWatches = {}
    self.pendingBagWatchOrder = {}
    self.nextBagWatchID = 0
    self.tradeTimerTicker = nil
    self.bagWatchTicker = nil

    -- Register for WoW trade events
    self:RegisterEvents()

    -- Start periodic trade timer check
    self:StartTimerCheck()
end

--[[--------------------------------------------------------------------
    Event Registration
----------------------------------------------------------------------]]

--- Register for trade-related events
function TradeQueueMixin:RegisterEvents()
    if not Events or not Events.Registry then return end

    -- Trade window events
    Events.Registry:RegisterEventCallback("TRADE_SHOW", function()
        self:OnTradeShow()
    end, self)

    Events.Registry:RegisterEventCallback("TRADE_CLOSED", function()
        self:OnTradeClosed()
    end, self)

    Events.Registry:RegisterEventCallback("TRADE_ACCEPT_UPDATE", function(_, playerAccepted, targetAccepted)
        self:OnTradeAcceptUpdate(playerAccepted, targetAccepted)
    end, self)

    Events.Registry:RegisterEventCallback("UI_INFO_MESSAGE", function(_, messageType, message)
        self:OnUIInfoMessage(messageType, message)
    end, self)

    Events.Registry:RegisterEventCallback("BAG_UPDATE_DELAYED", function()
        self:OnBagUpdateDelayed()
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
function TradeQueueMixin:AddToQueue(itemGUID, itemLink, winner, awardTime)
    winner = Utils.NormalizeName(winner)
    -- NormalizeName returns nil for secret-tagged or empty inputs. Refuse
    -- to insert an entry we can never look up again — surface to the caller
    -- so it can re-resolve the winner instead of silently losing the queue.
    if not winner then
        Loothing:Debug("AddToQueue: dropped entry with secret/invalid winner for", itemLink)
        return nil
    end
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
function TradeQueueMixin:RemoveFromQueue(itemGUID)
    local entry = self:GetQueuedItem(itemGUID)
    if not entry then
        return false
    end

    self.queue:Remove(entry)
    self.warningsSent[itemGUID] = nil
    self:TriggerEvent("OnItemRemoved", entry)
    self:SaveToDatabase()

    Loothing:Debug("Removed from trade queue:", entry.itemLink)
    return true
end

--- Get a queued item by GUID
-- @param itemGUID string - Item GUID
-- @return table|nil - Queue entry or nil
function TradeQueueMixin:GetQueuedItem(itemGUID)
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
function TradeQueueMixin:GetPendingForPlayer(playerName)
    playerName = Utils.NormalizeName(playerName)

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
function TradeQueueMixin:GetAllPending()
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
function TradeQueueMixin:GetQueue()
    return self.queue
end

--- Check if an item is within the 2-hour trade window
-- @param entry table - Queue entry
-- @return boolean - True if still tradable
function TradeQueueMixin:IsWithinTradeWindow(entry)
    return self:GetTimeRemaining(entry) > 0
end

--- Get time remaining for an item's trade window.
-- Prefers the authoritative tooltip-scanned timer from the item in bags:
-- awardTime is stamped at item CREATION, which overstates remaining time
-- for items queued mid-window (a manually added item looted 100 minutes
-- ago would otherwise claim a full 2h and fire its 20/5-minute warnings
-- after it went soulbound). When the same itemID exists in several slots
-- the highest known timer wins (the copy that can still be traded).
-- Falls back to awardTime math when the item isn't locatable or the
-- tooltip has no verdict yet (math.huge = unbound/cold tooltip).
-- @param entry table - Queue entry
-- @return number - Seconds remaining, or 0 if expired
function TradeQueueMixin:GetTimeRemaining(entry)
    local targetID = Utils.GetItemID(entry.itemLink)
    if targetID then
        local best = nil
        for bag = 0, NUM_BAG_SLOTS do
            local numSlots = C_Container.GetContainerNumSlots(bag)
            for slot = 1, numSlots do
                local info = C_Container.GetContainerItemInfo(bag, slot)
                if info and info.hyperlink and Utils.GetItemID(info.hyperlink) == targetID then
                    local remaining = self:GetContainerItemTradeTimeRemaining(bag, slot)
                    if remaining and remaining ~= math.huge
                        and (not best or remaining > best) then
                        best = remaining
                    end
                end
            end
        end
        if best then
            -- TooltipScan caches a STATIC parsed value until the next bag
            -- update, so anchor it and count down locally — otherwise
            -- per-second UI countdowns (TradePanel) freeze between bag
            -- events. Re-anchor only when the parsed value changes.
            -- Transient fields: SaveToDatabase copies fields selectively,
            -- so these never reach SavedVariables.
            if entry._scanRemaining ~= best then
                entry._scanRemaining = best
                entry._scanAnchor = time()
            end
            return math.max(0, entry._scanRemaining - (time() - entry._scanAnchor))
        end

        -- Item momentarily un-locatable (e.g. mid-trade): age the last
        -- good scan instead of snapping back to creation-time math.
        if entry._scanRemaining and entry._scanAnchor then
            return math.max(0, entry._scanRemaining - (time() - entry._scanAnchor))
        end
    end

    local elapsed = time() - entry.awardTime
    local remaining = TRADE_WINDOW_SECONDS - elapsed
    return math.max(0, remaining)
end

--[[--------------------------------------------------------------------
    Trade Window Handling
----------------------------------------------------------------------]]

--- Handle TRADE_SHOW event
function TradeQueueMixin:OnTradeShow()
    -- Block trades during active voting if setting is enabled
    if Loothing.Settings and Loothing.Settings:Get("frame.blockTradesDuringVoting")
        and Loothing.Session and Loothing.Session:IsActive() then
        CancelTrade()
        return
    end

    -- Get trade target from Blizzard UI. TradeFrameRecipientNameText:GetText()
    -- can return a WoW 12.0 secret string when the trade window opens under
    -- tainted execution; comparing it directly throws. Fall back to the "npc"
    -- unit (the standard trade-partner unit ID) via SafeUnitName, which also
    -- guards against secret returns. The recipient frame itself is normally
    -- present once Blizzard_TradeFrame loads, but guard the global access in
    -- case another addon defers/blocks the load-on-demand chain.
    local recipientFrame = _G.TradeFrameRecipientNameText
    local target = recipientFrame and recipientFrame:GetText() or nil
    local fallbackRealm
    if SecretUtil.IsSecretValue(target) or not target or target == "" then
        target, fallbackRealm = SecretUtil.SafeUnitName("npc")
    end
    local normalizedTarget = nil

    if target and target ~= "" then
        -- Remove "(*)" for cross-realm (use plain find to avoid pattern errors)
        if target:find("(*)", 1, true) then
            target = target:gsub(" ?%(%*%)", "")
        end
        -- When the fallback path fired and the partner is on a connected
        -- realm, SafeUnitName returns the realm separately; attach it so
        -- NormalizeName can match the queue's stored "Name-realm" winners.
        if fallbackRealm and fallbackRealm ~= "" and not target:find("-", 1, true) then
            target = target .. "-" .. fallbackRealm
        end
        normalizedTarget = Utils.NormalizeName(target)
    end

    self.tradeTarget = normalizedTarget
    self.isTrading = true
    wipe(self.itemsInTradeWindow)

    Loothing:Debug("Trade opened with:", self.tradeTarget or "<unknown>")

    if not self.tradeTarget then
        return
    end

    -- Reject trades with players who have no queued items (if setting is enabled)
    if Loothing.Settings and Loothing.Settings:Get("ml.rejectTrade") then
        local pendingForTarget = self:GetPendingForPlayer(self.tradeTarget)
        if #pendingForTarget == 0 then
            CancelTrade()
            return
        end
    end

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
            Loothing:Print(string.format(L["TRADE_ITEMS_PENDING"], count, Utils.GetShortName(self.tradeTarget)))
        end

        -- Trigger event for UI updates
        self:TriggerEvent("OnTradeWindowOpened", self.tradeTarget, pending)
    end
end

--- Handle TRADE_CLOSED event
function TradeQueueMixin:OnTradeClosed()
    Loothing:Debug("Trade closed")

    -- Fallback: if items were staged but TRADE_COMPLETE never fired (constant
    -- nil in this WoW build), check bags after a short delay. If the items are
    -- gone, the trade succeeded.
    if #self.itemsInTradeWindow > 0 and self.tradeTarget then
        local stagedItems = { unpack(self.itemsInTradeWindow) }
        local stagedTarget = self.tradeTarget

        C_Timer.After(ITEM_WATCH_DELAY, function()
            -- Bail if a fresh trade started inside the 0.5s gap: items
            -- staged into the new window aren't in bags either, so the
            -- bag-delta check would falsely mark the prior trade complete
            -- and attribute it to the wrong target.
            if self.isTrading then return end

            for _, staged in ipairs(stagedItems) do
                local link = GetStagedItemLink(staged)
                local traded = false

                if type(staged) == "table" and staged.itemID and staged.preBagCount then
                    traded = self:CountItemIDInBags(staged.itemID) < staged.preBagCount
                elseif link then
                    local bag, _slot = self:FindItemInBags(link)
                    traded = not bag
                end

                if traded then
                    Loothing:Debug("TRADE_CLOSED fallback: item gone from bags:", link)
                    self:MarkItemTraded(staged, stagedTarget)
                end
            end
        end)
    end

    self.isTrading = false
    self.tradeTarget = nil
    wipe(self.itemsInTradeWindow)
end

--- Handle TRADE_ACCEPT_UPDATE event (record items being traded)
-- @param playerAccepted boolean - Has player accepted
-- @param targetAccepted boolean - Has target accepted
function TradeQueueMixin:OnTradeAcceptUpdate(playerAccepted, targetAccepted)
    local playerAcceptedNow = playerAccepted == true or playerAccepted == 1
    local targetAcceptedNow = targetAccepted == true or targetAccepted == 1

    if playerAcceptedNow or targetAcceptedNow then
        self:CaptureTradeWindowItems()
    else
        wipe(self.itemsInTradeWindow)
    end
end

--- Capture items currently staged in our side of the trade window.
-- @return number - Number of staged items captured
function TradeQueueMixin:CaptureTradeWindowItems()
    local metadataBySlot = {}
    for _, staged in ipairs(self.itemsInTradeWindow) do
        if type(staged) == "table" and staged.tradeSlot then
            metadataBySlot[staged.tradeSlot] = staged
        end
    end

    wipe(self.itemsInTradeWindow)

    for i = 1, MAX_TRADE_ITEMS - 1 do -- Last slot is "will not be traded"
        local link = GetTradePlayerItemLink(i)
        if link then
            local prior = metadataBySlot[i]
            self.itemsInTradeWindow[#self.itemsInTradeWindow + 1] = {
                itemLink = link,
                itemID = Utils.GetItemID(link),
                entryGUID = prior and prior.entryGUID or nil,
                winner = prior and prior.winner or nil,
                preBagCount = prior and prior.preBagCount or nil,
                tradeSlot = i,
            }
            Loothing:Debug("Recording trade item:", link)
        end
    end

    return #self.itemsInTradeWindow
end

local function IsTradeCompleteMessage(messageType, message)
    if TRADE_COMPLETE_MSG and messageType == TRADE_COMPLETE_MSG then
        return true
    end
    return TRADE_COMPLETE_TEXT and message == TRADE_COMPLETE_TEXT
end

--- Handle UI_INFO_MESSAGE event (trade complete)
-- @param messageType number - Message type
-- @param message string - Localized message text
function TradeQueueMixin:OnUIInfoMessage(messageType, message)
    if IsTradeCompleteMessage(messageType, message) then
        Loothing:Debug("Trade completed with:", self.tradeTarget)

        local stagedItems = { unpack(self.itemsInTradeWindow) }
        if self:CaptureTradeWindowItems() == 0 and #stagedItems > 0 then
            for _, staged in ipairs(stagedItems) do
                self.itemsInTradeWindow[#self.itemsInTradeWindow + 1] = staged
            end
        end

        -- Mark traded items as complete
        for _, staged in ipairs(self.itemsInTradeWindow) do
            self:MarkItemTraded(staged, self.tradeTarget)
        end

        wipe(self.itemsInTradeWindow)
    end
end

--- Add items to the trade window automatically
-- @param items table - Array of queue entries
function TradeQueueMixin:AddItemsToTradeWindow(items)
    if not self.isTrading then
        Loothing:Debug("Cannot add items - trade window not open")
        return
    end

    -- Add items with a small delay between each
    local delay = 0.1
    for i, entry in ipairs(items) do
        if i > MAX_TRADE_ITEMS - 1 then
            Loothing:Print(L["TRADE_TOO_MANY_ITEMS"])
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
function TradeQueueMixin:AddSingleItemToTrade(entry)
    if not self.isTrading then return end

    -- Find the item in bags
    local bag, slot = self:FindItemInBags(entry.itemLink)
    if not bag or not slot then
        Loothing:Print(string.format(L["TRADE_ITEM_NOT_FOUND"], entry.itemLink))
        return
    end

    -- Check if item is locked
    local containerInfo = C_Container.GetContainerItemInfo(bag, slot)
    if containerInfo and containerInfo.isLocked then
        Loothing:Print(string.format(L["TRADE_ITEM_LOCKED"], entry.itemLink))
        return
    end

    -- Add to trade window
    Loothing:Debug("Adding to trade:", entry.itemLink, bag, slot)
    local itemID = Utils.GetItemID(entry.itemLink)
    local preBagCount = self:CountItemIDInBags(itemID)
    local placed = false

    ClearCursor()
    C_Container.PickupContainerItem(bag, slot)

    -- Find first empty trade slot
    for i = 1, MAX_TRADE_ITEMS - 1 do
        if not GetTradePlayerItemLink(i) then
            ClickTradeButton(i)
            local placedLink = GetTradePlayerItemLink(i)
            if placedLink then
                self.itemsInTradeWindow[#self.itemsInTradeWindow + 1] = {
                    itemLink = placedLink,
                    itemID = Utils.GetItemID(placedLink),
                    entryGUID = entry.itemGUID,
                    winner = entry.winner,
                    preBagCount = preBagCount,
                    tradeSlot = i,
                }
                placed = true
            end
            break
        end
    end

    if not placed then
        if CursorHasItem and CursorHasItem() then
            ClearCursor()
        end
        Loothing:Debug("Failed to place item in trade slot:", entry.itemLink)
    end
end

--- Find an item in the player's bags
-- @param itemLink string - Item link to find
-- @return number, number - Bag and slot, or nil if not found
function TradeQueueMixin:FindItemInBags(itemLink)
    local targetID = Utils.GetItemID(itemLink)
    for bag = 0, NUM_BAG_SLOTS do
        local numSlots = C_Container.GetContainerNumSlots(bag)
        for slot = 1, numSlots do
            local info = C_Container.GetContainerItemInfo(bag, slot)
            if info and info.hyperlink then
                -- Compare item IDs (links may have different bonus IDs)
                local foundID = Utils.GetItemID(info.hyperlink)

                if targetID == foundID then
                    return bag, slot
                end
            end
        end
    end
    return nil, nil
end

--- Count matching item IDs in the player's bags.
-- Used after TRADE_CLOSED as a duplicate-safe fallback when the same item ID
-- still exists in bags but one copy was traded.
-- @param itemID number - Item ID to count
-- @return number - Total stack count found in bags
function TradeQueueMixin:CountItemIDInBags(itemID)
    local count = 0
    if not itemID then
        return count
    end

    for bag = 0, NUM_BAG_SLOTS do
        local numSlots = C_Container.GetContainerNumSlots(bag)
        for slot = 1, numSlots do
            local info = C_Container.GetContainerItemInfo(bag, slot)
            if info and info.hyperlink and Utils.GetItemID(info.hyperlink) == itemID then
                count = count + (info.stackCount or 1)
            end
        end
    end

    return count
end

--[[--------------------------------------------------------------------
    Trade Completion
----------------------------------------------------------------------]]

--- Mark an item as traded
-- @param itemOrStaged string|table - Item link or staged trade item metadata
-- @param tradedTo string - Who it was traded to
function TradeQueueMixin:MarkItemTraded(itemOrStaged, tradedTo)
    local itemLink = GetStagedItemLink(itemOrStaged)
    if not itemLink or not tradedTo then
        return
    end
    tradedTo = Utils.NormalizeName(tradedTo)

    -- Find matching queue entry
    local itemID = Utils.GetItemID(itemLink)
    local entry = nil

    if type(itemOrStaged) == "table" and itemOrStaged.entryGUID then
        entry = self:GetQueuedItem(itemOrStaged.entryGUID)
    end

    if not entry then
        for _, queueEntry in self.queue:Enumerate() do
            if not queueEntry.traded then
                local queueItemID = Utils.GetItemID(queueEntry.itemLink)
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
    end

    if entry then
        entry.traded = true
        entry.tradeTime = time()
        self.queue:UpdateElement(entry)

        self:TriggerEvent("OnItemTraded", entry, tradedTo)

        -- Print trade completion if enabled. Default matches Constants
        -- (printCompletedTrades = false), so Settings-missing falls silent
        -- rather than spamming the chat frame.
        if Loothing.Settings and Loothing.Settings:Get("ml.printCompletedTrades", false) then
            if entry.winner == tradedTo then
                Loothing:Print(string.format(L["TRADE_COMPLETED"], entry.itemLink, Utils.GetShortName(tradedTo)))
            else
                Loothing:Print(string.format(L["TRADE_WRONG_RECIPIENT"], entry.itemLink, Utils.GetShortName(tradedTo), Utils.GetShortName(entry.winner)))
            end
        end

        self:RemoveFromQueue(entry.itemGUID)
    end
end

--[[--------------------------------------------------------------------
    Tooltip-Based Trade Timer Parsing
----------------------------------------------------------------------]]

--- Get trade time remaining for a bag slot by parsing the tooltip
-- Handles multiple locale time formats and returns precise seconds.
-- @param container number - Bag index
-- @param slot number - Slot index
-- @return number - Seconds remaining: math.huge for unbound, 0 for soulbound, >0 for tradeable
function TradeQueueMixin:GetContainerItemTradeTimeRemaining(container, slot)
    if not TooltipScan then
        return 0
    end
    return TooltipScan:GetContainerItemTradeTimeRemaining(container, slot)
end

--[[--------------------------------------------------------------------
    Item Bag Watching
----------------------------------------------------------------------]]

--- Watch for a specific item to appear in bags (e.g., after looting)
-- Polls bags periodically and calls onFound or onFail.
-- @param itemLink string - Item link to watch for
-- @param onFound function(bag, slot, timeRemaining) - Called when found
-- @param onFail function() - Called when max attempts exceeded
-- @param maxAttempts number|nil - Max attempts (default: 20, at 0.5s intervals)
function TradeQueueMixin:WatchForItemInBags(itemLink, onFound, onFail, maxAttempts)
    maxAttempts = maxAttempts or 20
    local targetItemID = Utils.GetItemID(itemLink)
    if not targetItemID then
        if onFail then
            onFail()
        end
        return
    end

    self.nextBagWatchID = self.nextBagWatchID + 1
    local watchID = self.nextBagWatchID
    self.pendingBagWatches[watchID] = {
        id = watchID,
        itemLink = itemLink,
        targetItemID = targetItemID,
        onFound = onFound,
        onFail = onFail,
        attempts = 0,
        maxAttempts = maxAttempts,
    }
    self.pendingBagWatchOrder[#self.pendingBagWatchOrder + 1] = watchID
    self:EnsureBagWatchTicker()
end

function TradeQueueMixin:OnBagUpdateDelayed()
    if TooltipScan then
        TooltipScan:InvalidateBagCache()
    end
    self:ProcessPendingBagWatches(false)
end

function TradeQueueMixin:EnsureBagWatchTicker()
    if self.bagWatchTicker or #self.pendingBagWatchOrder == 0 then
        return
    end

    self.bagWatchTicker = C_Timer.NewTicker(ITEM_WATCH_DELAY, function()
        self:ProcessPendingBagWatches(true)
    end)
end

function TradeQueueMixin:StopBagWatchTickerIfIdle()
    if self.bagWatchTicker and #self.pendingBagWatchOrder == 0 then
        self.bagWatchTicker:Cancel()
        self.bagWatchTicker = nil
    end
end

function TradeQueueMixin:ProcessPendingBagWatches(countAttempt)
    if #self.pendingBagWatchOrder == 0 then
        self:StopBagWatchTickerIfIdle()
        return
    end

    local remaining = {}
    local pendingItemIDs = {}
    local foundByItemID = {}

    for _, watchID in ipairs(self.pendingBagWatchOrder) do
        local watch = self.pendingBagWatches[watchID]
        if watch then
            pendingItemIDs[watch.targetItemID] = true
        end
    end

    for bag = 0, NUM_BAG_SLOTS do
        local numSlots = C_Container.GetContainerNumSlots(bag)
        for slot = 1, numSlots do
            local bagItemLink = C_Container.GetContainerItemLink(bag, slot)
            if bagItemLink then
                local foundID = Utils.GetItemID(bagItemLink)
                if foundID and pendingItemIDs[foundID] and not foundByItemID[foundID] then
                    foundByItemID[foundID] = {
                        bag = bag,
                        slot = slot,
                        timeRemaining = self:GetContainerItemTradeTimeRemaining(bag, slot),
                    }
                end
            end
        end
    end

    for _, watchID in ipairs(self.pendingBagWatchOrder) do
        local watch = self.pendingBagWatches[watchID]
        if watch then
            local found = foundByItemID[watch.targetItemID]
            if found then
                self.pendingBagWatches[watchID] = nil
                if watch.onFound then
                    watch.onFound(found.bag, found.slot, found.timeRemaining)
                end
            else
                if countAttempt then
                    watch.attempts = watch.attempts + 1
                end

                if countAttempt and watch.attempts >= watch.maxAttempts then
                    self.pendingBagWatches[watchID] = nil
                    Loothing:Debug("WatchForItemInBags: failed after", watch.maxAttempts, "attempts for", watch.itemLink)
                    if watch.onFail then
                        watch.onFail()
                    end
                else
                    remaining[#remaining + 1] = watchID
                end
            end
        end
    end

    self.pendingBagWatchOrder = remaining
    self:StopBagWatchTickerIfIdle()
end

--[[--------------------------------------------------------------------
    Tradable/Non-Tradable Comms
----------------------------------------------------------------------]]

--- Send tradable item notification to group
-- Called when the player loots an item that has a trade window
-- @param itemLink string - Item link
-- @param timeRemaining number - Seconds remaining in trade window
function TradeQueueMixin:SendTradableComm(itemLink, timeRemaining)
    if not Loothing.Comm or not Loothing.Comm.Send then return end

    Loothing.Comm:Send(Loothing.MsgType.TRADABLE, {
        itemLink = itemLink,
        timeRemaining = timeRemaining,
    })

    Loothing:Debug("Sent TRADABLE comm for", itemLink)
end

--- Send non-tradable item notification to group
-- Called when the player loots an item that is soulbound
-- @param itemLink string - Item link
function TradeQueueMixin:SendNonTradableComm(itemLink)
    if not Loothing.Comm or not Loothing.Comm.Send then return end

    Loothing.Comm:Send(Loothing.MsgType.NON_TRADABLE, {
        itemLink = itemLink,
    })

    Loothing:Debug("Sent NON_TRADABLE comm for", itemLink)
end

--- Decide whether broadcasting a TRADABLE / NON_TRADABLE notification is
--- actually useful, or whether it's pure channel noise under the current
--- MLDB configuration. Suppress in the "auto-roll raid" case:
---   * Caller is not the ML, AND
---   * MLDB signals the ML is handling loot with active group-loot auto-roll
--- In that mode non-ML raiders win essentially nothing, so TRADABLE from
--- them is noise; ML detects own wins via LOOT_ITEM_ROLL_WON + bag scan.
--- Also suppress the ML's own self-announcement — the ML already has the
--- item in a session; broadcasting to the raid about "I have this" adds
--- nothing useful.
--- @return boolean - true if the broadcast should be skipped.
local function shouldSuppressTradeBroadcast()
    local mldb = Loothing.MLDB and Loothing.MLDB:Get()
    if not mldb then return false end                  -- MLDB absent: broadcast as before
    if mldb.handleLoot ~= true then return false end   -- ML not handling: broadcast
    if mldb.groupLootMode ~= "active" then return false end

    -- ML's own broadcast is self-referential noise: the item is already
    -- in the ML's session pipeline via HandleTradable's active-session
    -- branch or the buffer path. Other raiders don't need to be told.
    local Session = Loothing.Session
    local isMLSelf = Session and Session.IsMasterLooter and Session:IsMasterLooter()
    if isMLSelf then return true end

    -- Non-ML raider: suppress — their bag should be empty of new wins in
    -- auto-roll mode, and any item that DID land (e.g. legendary hard-skip
    -- or quality below threshold) is player-personal, not council-relevant.
    return true
end

--- Handle a recently looted item - determine if tradable and broadcast
-- @param itemLink string - Item link that was just looted
function TradeQueueMixin:UpdateAndSendRecentTradableItem(itemLink)
    if shouldSuppressTradeBroadcast() then
        Loothing:Debug("TRADABLE suppressed (auto-roll raid):", itemLink)
        return
    end
    self:WatchForItemInBags(itemLink,
        function(_bag, _slot, timeRemaining)
            if timeRemaining and timeRemaining > 0 then
                self:SendTradableComm(itemLink, timeRemaining)
            else
                self:SendNonTradableComm(itemLink)
            end
        end,
        function()
            -- Item not found in bags - might have been auto-looted elsewhere
            Loothing:Debug("UpdateAndSendRecentTradableItem: could not find", itemLink)
        end
    )
end

--[[--------------------------------------------------------------------
    Periodic Trade Timer Check
----------------------------------------------------------------------]]

--- Start periodic trade timer checking
-- Checks all queued items for approaching trade window expiry
function TradeQueueMixin:StartTimerCheck()
    if self.tradeTimerTicker then
        self.tradeTimerTicker:Cancel()
    end

    self.tradeTimerTicker = C_Timer.NewTicker(TRADE_TIMER_CHECK_INTERVAL, function()
        self:CheckTradeTimers()
    end)
end

--- Check all pending items and warn if trade window is expiring
function TradeQueueMixin:CheckTradeTimers()
    for _, entry in self.queue:Enumerate() do
        if not entry.traded then
            local remaining = self:GetTimeRemaining(entry)

            if remaining > 0 then
                local warnings = self.warningsSent[entry.itemGUID]
                if not warnings then
                    warnings = {}
                    self.warningsSent[entry.itemGUID] = warnings
                end

                -- 20-minute warning
                if remaining <= TRADE_WARNING_20MIN and not warnings.warned20 then
                    warnings.warned20 = true
                    local minutesLeft = math.floor(remaining / 60)
                    Loothing:Print(string.format(
                        L["TRADE_WINDOW_WARNING"],
                        entry.itemLink,
                        Utils.GetShortName(entry.winner),
                        minutesLeft
                    ))
                end

                -- 5-minute warning
                if remaining <= TRADE_WARNING_5MIN and not warnings.warned5 then
                    warnings.warned5 = true
                    local minutesLeft = math.floor(remaining / 60)
                    Loothing:Print(string.format(
                        L["TRADE_WINDOW_URGENT"],
                        entry.itemLink,
                        Utils.GetShortName(entry.winner),
                        minutesLeft
                    ))
                end
            end
        end
    end

    -- Clean up warnings for removed/traded items
    for itemGUID in pairs(self.warningsSent) do
        if not self:GetQueuedItem(itemGUID) then
            self.warningsSent[itemGUID] = nil
        end
    end
end

--[[--------------------------------------------------------------------
    Persistence (SavedVariables - Global Scope)
----------------------------------------------------------------------]]

--- Load queue from SavedVariables (uses global scope for cross-profile persistence)
function TradeQueueMixin:LoadFromDatabase()
    local stored
    if Loothing.Settings and Loothing.Settings.GetGlobalValue then
        stored = Loothing.Settings:GetGlobalValue("tradeQueue", {})
    else
        local store = SavedVariables.GetAddonData("Loothing", false)
        stored = store and store.global and store.global.tradeQueue
    end

    if not stored or type(stored) ~= "table" then
        return
    end

    -- Discard entries owned by a different character
    local currentOwner = Utils and Utils.GetPlayerFullName and Utils.GetPlayerFullName()
    if stored._owner and currentOwner and stored._owner ~= currentOwner then
        Loothing:Debug("TradeQueue: discarding stale entries from", tostring(stored._owner))
        return
    end

    self.queue:Flush()
    local discarded = 0

    for _, entry in ipairs(stored) do
        -- Only load entries still within trade window
        if not entry.traded and self:IsWithinTradeWindow(entry) then
            self.queue:Insert(entry)
        else
            discarded = discarded + 1
        end
    end

    if discarded > 0 then
        self:SaveToDatabase()
    end

    Loothing:Debug("Loaded", self.queue:GetSize(), "items from trade queue")
end

--- Save queue to SavedVariables (uses global scope)
function TradeQueueMixin:SaveToDatabase()
    local entries = {}

    for _, entry in self.queue:Enumerate() do
        -- Only save entries still within trade window
        if not entry.traded and self:IsWithinTradeWindow(entry) then
            entries[#entries + 1] = {
                itemGUID = entry.itemGUID,
                itemLink = entry.itemLink,
                winner = entry.winner,
                awardTime = entry.awardTime,
                traded = entry.traded,
                tradeTime = entry.tradeTime,
            }
        end
    end

    -- Persist owner key so other characters discard stale entries
    local currentOwner = Utils and Utils.GetPlayerFullName and Utils.GetPlayerFullName()
    if currentOwner then
        entries._owner = currentOwner
    end

    if Loothing.Settings and Loothing.Settings.SetGlobalValue then
        Loothing.Settings:SetGlobalValue("tradeQueue", entries)
    else
        local store = SavedVariables.GetAddonData("Loothing", true)
        store.global = store.global or {}
        store.global.tradeQueue = entries
    end

    Loothing:Debug("Saved", #entries, "items to trade queue")
end

--[[--------------------------------------------------------------------
    Factory
----------------------------------------------------------------------]]

--- Create a new trade queue
-- @return table - TradeQueue instance
local function CreateTradeQueue()
    local queue = CreateFromMixins(TradeQueueMixin)
    queue:Init()
    return queue
end

ns.CreateTradeQueue = CreateTradeQueue
