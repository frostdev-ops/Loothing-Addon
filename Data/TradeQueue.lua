--[[--------------------------------------------------------------------
    Loothing - Loot Council Addon for WoW 12.0+
    TradeQueue - Manages items awaiting trade to winners
----------------------------------------------------------------------]]

local Loolib = LibStub("Loolib")
local CallbackRegistryMixin = Loolib.CallbackRegistryMixin
local CreateFromMixins = Loolib.CreateFromMixins
local Data = Loolib.Data
local Events = Loolib.Events

--[[--------------------------------------------------------------------
    LoothingTradeQueueMixin

    Manages the queue of items that need to be traded to winners.
    Tracks 2-hour trade window and persists to SavedVariables.
----------------------------------------------------------------------]]

LoothingTradeQueueMixin = CreateFromMixins(CallbackRegistryMixin)

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

--- Initialize the trade queue
function LoothingTradeQueueMixin:Init()
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

    -- Register for WoW trade events
    self:RegisterEvents()

    -- Start periodic trade timer check
    self:StartTimerCheck()
end

--[[--------------------------------------------------------------------
    Event Registration
----------------------------------------------------------------------]]

--- Register for trade-related events
function LoothingTradeQueueMixin:RegisterEvents()
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

    -- Remove "(*)" for cross-realm (use plain find to avoid pattern errors)
    if target:find("(*)", 1, true) then
        target = target:gsub(" ?%(%*%)", "")
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
    if playerAccepted or targetAccepted then
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
    -- Handle both legacy LE_ and modern Enum.GameError constants
    local TRADE_COMPLETE = LE_GAME_ERR_TRADE_COMPLETE
        or (Enum.GameError and Enum.GameError.TradeComplete)
    if TRADE_COMPLETE and messageType == TRADE_COMPLETE then
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
    Tooltip-Based Trade Timer Parsing
----------------------------------------------------------------------]]

--- Get trade time remaining for a bag slot by parsing the tooltip
-- Handles multiple locale time formats and returns precise seconds.
-- @param container number - Bag index
-- @param slot number - Slot index
-- @return number - Seconds remaining: math.huge for unbound, 0 for soulbound, >0 for tradeable
function LoothingTradeQueueMixin:GetContainerItemTradeTimeRemaining(container, slot)
    if not container or not slot then
        return 0
    end

    -- Check basic item info first
    local info = C_Container.GetContainerItemInfo(container, slot)
    if not info then
        return 0
    end

    -- Create a scanning tooltip
    local tooltipName = "LoothingTradeQueueScanTooltip"
    local tooltip = _G[tooltipName]
    if not tooltip then
        tooltip = CreateFrame("GameTooltip", tooltipName, nil, "GameTooltipTemplate")
    end

    tooltip:SetOwner(UIParent, "ANCHOR_NONE")
    tooltip:SetBagItem(container, slot)

    local result = 0

    -- Use Blizzard's BIND_TRADE_TIME_REMAINING global constant for locale-independent
    -- tooltip parsing. The constant contains a format string like "You may trade this
    -- item with players that were also eligible to loot this item for %s."
    -- We search for its presence and extract the time string from the tooltip text.
    local tradePattern = BIND_TRADE_TIME_REMAINING
    local boeText = ITEM_BIND_ON_EQUIP
    local soulboundText = ITEM_SOULBOUND

    for i = 1, tooltip:NumLines() do
        local line = _G[tooltipName .. "TextLeft" .. i]
        if line then
            local text = line:GetText()
            if text then
                -- Check for trade time remaining using Blizzard's localized constant
                if tradePattern then
                    -- Build a plain-text anchor from the constant (text before the %s placeholder)
                    local anchor = tradePattern:match("^(.-)%%s")
                    if anchor and anchor ~= "" then
                        local anchorStart, anchorEnd = text:find(anchor, 1, true)
                        if anchorStart then
                            -- Extract the time portion after the anchor
                            local timeStr = text:sub(anchorEnd + 1)
                            -- Parse hours and minutes from the time string
                            local hours = timeStr:match("(%d+)%s*%a") and tonumber(timeStr:match("(%d+)")) or 0
                            local minutes = 0
                            -- Try to extract a second number for minutes
                            local h, m = timeStr:match("(%d+).-(%d+)")
                            if h then
                                hours = tonumber(h) or 0
                                minutes = tonumber(m) or 0
                            end
                            result = hours * 3600 + minutes * 60
                            if result == 0 then result = 60 end -- At least 1 minute if pattern matched
                            break
                        end
                    end
                end

                -- Fallback: try direct time patterns for any edge cases
                local hours = text:match("(%d+)%s*hour") or text:match("(%d+)%s*hr")
                local minutes = text:match("(%d+)%s*min")
                if hours or minutes then
                    result = (tonumber(hours) or 0) * 3600 + (tonumber(minutes) or 0) * 60
                    break
                end

                -- Check for BoE items using localized constant
                if boeText and text:find(boeText, 1, true) then
                    result = math.huge
                    break
                end

                -- Check for soulbound using localized constant
                if soulboundText and text:find(soulboundText, 1, true) then
                    result = 0
                    break
                end
            end
        end
    end

    tooltip:Hide()
    return result
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
function LoothingTradeQueueMixin:WatchForItemInBags(itemLink, onFound, onFail, maxAttempts)
    maxAttempts = maxAttempts or 20
    local attempt = 0
    local delay = 0.5

    local function check()
        attempt = attempt + 1

        -- Scan bags for the item
        for bag = 0, NUM_BAG_SLOTS do
            local numSlots = C_Container.GetContainerNumSlots(bag)
            for slot = 1, numSlots do
                local bagItemLink = C_Container.GetContainerItemLink(bag, slot)
                if bagItemLink then
                    local targetID = LoothingUtils.GetItemID(itemLink)
                    local foundID = LoothingUtils.GetItemID(bagItemLink)

                    if targetID and foundID and targetID == foundID then
                        local timeRemaining = self:GetContainerItemTradeTimeRemaining(bag, slot)

                        Loothing:Debug("WatchForItemInBags: found", itemLink, "at", bag, slot)
                        if onFound then
                            onFound(bag, slot, timeRemaining)
                        end
                        return
                    end
                end
            end
        end

        -- Not found yet
        if attempt < maxAttempts then
            C_Timer.After(delay, check)
        else
            Loothing:Debug("WatchForItemInBags: failed after", maxAttempts, "attempts for", itemLink)
            if onFail then
                onFail()
            end
        end
    end

    C_Timer.After(delay, check)
end

--[[--------------------------------------------------------------------
    Tradable/Non-Tradable Comms
----------------------------------------------------------------------]]

--- Send tradable item notification to group
-- Called when the player loots an item that has a trade window
-- @param itemLink string - Item link
-- @param timeRemaining number - Seconds remaining in trade window
function LoothingTradeQueueMixin:SendTradableComm(itemLink, timeRemaining)
    if not Loothing.Comm or not Loothing.Comm.Send then return end

    Loothing.Comm:Send(Loothing.MsgType.TRADABLE, {
        itemLink = itemLink,
        timeRemaining = timeRemaining,
    }, "group")

    Loothing:Debug("Sent TRADABLE comm for", itemLink)
end

--- Send non-tradable item notification to group
-- Called when the player loots an item that is soulbound
-- @param itemLink string - Item link
function LoothingTradeQueueMixin:SendNonTradableComm(itemLink)
    if not Loothing.Comm or not Loothing.Comm.Send then return end

    Loothing.Comm:Send(Loothing.MsgType.NON_TRADABLE, {
        itemLink = itemLink,
    }, "group")

    Loothing:Debug("Sent NON_TRADABLE comm for", itemLink)
end

--- Handle a recently looted item - determine if tradable and broadcast
-- @param itemLink string - Item link that was just looted
function LoothingTradeQueueMixin:UpdateAndSendRecentTradableItem(itemLink)
    self:WatchForItemInBags(itemLink,
        function(bag, slot, timeRemaining)
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
function LoothingTradeQueueMixin:StartTimerCheck()
    C_Timer.NewTicker(TRADE_TIMER_CHECK_INTERVAL, function()
        self:CheckTradeTimers()
    end)
end

--- Check all pending items and warn if trade window is expiring
function LoothingTradeQueueMixin:CheckTradeTimers()
    for _, entry in self.queue:Enumerate() do
        if not entry.traded then
            local remaining = self:GetTimeRemaining(entry)

            if remaining <= 0 then
                -- Already expired, skip
            else
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
                        "|cffff9900Warning:|r Trade window for %s (awarded to %s) expires in %d minutes!",
                        entry.itemLink,
                        LoothingUtils.GetShortName(entry.winner),
                        minutesLeft
                    ))
                end

                -- 5-minute warning
                if remaining <= TRADE_WARNING_5MIN and not warnings.warned5 then
                    warnings.warned5 = true
                    local minutesLeft = math.floor(remaining / 60)
                    Loothing:Print(string.format(
                        "|cffff0000URGENT:|r Trade window for %s (awarded to %s) expires in %d minutes!",
                        entry.itemLink,
                        LoothingUtils.GetShortName(entry.winner),
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
function LoothingTradeQueueMixin:LoadFromDatabase()
    local stored
    if Loothing.Settings and Loothing.Settings.GetGlobalValue then
        stored = Loothing.Settings:GetGlobalValue("tradeQueue", {})
    elseif LoothingDB and LoothingDB.tradeQueue then
        stored = LoothingDB.tradeQueue
    end

    if not stored or type(stored) ~= "table" then
        return
    end

    -- FIX(Area4-2): Discard entries owned by a different character
    local currentOwner = LoothingUtils and LoothingUtils.GetPlayerFullName and LoothingUtils.GetPlayerFullName()
    if stored._owner and currentOwner and stored._owner ~= currentOwner then
        Loothing:Debug("TradeQueue: discarding stale entries from", tostring(stored._owner))
        return
    end

    self.queue:Flush()

    for _, entry in ipairs(stored) do
        -- Only load entries still within trade window
        if self:IsWithinTradeWindow(entry) then
            self.queue:Insert(entry)
        end
    end

    Loothing:Debug("Loaded", self.queue:GetSize(), "items from trade queue")
end

--- Save queue to SavedVariables (uses global scope)
function LoothingTradeQueueMixin:SaveToDatabase()
    local entries = {}

    for _, entry in self.queue:Enumerate() do
        -- Only save entries still within trade window
        if self:IsWithinTradeWindow(entry) then
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

    -- FIX(Area4-2): Persist owner key so other characters discard stale entries
    local currentOwner = LoothingUtils and LoothingUtils.GetPlayerFullName and LoothingUtils.GetPlayerFullName()
    if currentOwner then
        entries._owner = currentOwner
    end

    if Loothing.Settings and Loothing.Settings.SetGlobalValue then
        Loothing.Settings:SetGlobalValue("tradeQueue", entries)
    elseif LoothingDB then
        LoothingDB.tradeQueue = entries
    end

    Loothing:Debug("Saved", #entries, "items to trade queue")
end

--[[--------------------------------------------------------------------
    Factory
----------------------------------------------------------------------]]

--- Create a new trade queue
-- @return table - TradeQueue instance
function CreateLoothingTradeQueue()
    local queue = CreateFromMixins(LoothingTradeQueueMixin)
    queue:Init()
    return queue
end
