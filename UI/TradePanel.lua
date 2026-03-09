--[[--------------------------------------------------------------------
    Loothing - Loot Council Addon for WoW 12.0+
    TradePanel - Panel showing items pending trade
----------------------------------------------------------------------]]

local Loolib = LibStub("Loolib")

--[[--------------------------------------------------------------------
    LoothingTradePanelMixin

    Displays a list of items that need to be traded to winners.
    Shows item, winner, and time remaining. Click to initiate trade.
----------------------------------------------------------------------]]

LoothingTradePanelMixin = LoolibCreateFromMixins(LoolibCallbackRegistryMixin)

local TRADE_PANEL_EVENTS = {
    "OnInitiateTrade",
    "OnRemoveItem",
}

--- Initialize the trade panel
-- @param parent Frame - Parent frame (usually a tab content area)
function LoothingTradePanelMixin:Init(parent)
    LoolibCallbackRegistryMixin.OnLoad(self)
    self:GenerateCallbackEvents(TRADE_PANEL_EVENTS)

    self.parent = parent
    self.rows = {}
    self.rowPool = {} -- hidden rows available for reuse
    self.updateTimer = nil

    self:CreateFrame()
    self:CreateElements()
    self:RegisterEvents()
end

--[[--------------------------------------------------------------------
    Frame Creation
----------------------------------------------------------------------]]

--- Create the main frame
function LoothingTradePanelMixin:CreateFrame()
    local frame = CreateFrame("Frame", nil, self.parent)
    frame:SetAllPoints()

    self.frame = frame
end

--- Create UI elements
function LoothingTradePanelMixin:CreateElements()
    local L = LOOTHING_LOCALE

    -- Header
    self:CreateHeader()

    -- List container
    self:CreateList()

    -- Footer with controls
    self:CreateFooter()
end

--- Create header
function LoothingTradePanelMixin:CreateHeader()
    local L = LOOTHING_LOCALE

    local header = CreateFrame("Frame", nil, self.frame)
    header:SetPoint("TOPLEFT", 8, -8)
    header:SetPoint("TOPRIGHT", -8, -8)
    header:SetHeight(50)

    -- Title
    self.titleText = header:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    self.titleText:SetPoint("TOPLEFT")
    self.titleText:SetText(L["TRADE_QUEUE"] or "Trade Queue")

    -- Item count
    self.countText = header:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    self.countText:SetPoint("TOPLEFT", self.titleText, "BOTTOMLEFT", 0, -4)
    self.countText:SetTextColor(0.7, 0.7, 0.7)

    -- Help text
    self.helpText = header:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    self.helpText:SetPoint("TOPRIGHT")
    self.helpText:SetText(L["TRADE_PANEL_HELP"] or "Click a player name to initiate trade")
    self.helpText:SetTextColor(0.7, 0.7, 0.7)

    self.header = header
end

--- Create list
function LoothingTradePanelMixin:CreateList()
    local L = LOOTHING_LOCALE

    -- List container
    local container = CreateFrame("Frame", nil, self.frame, "BackdropTemplate")
    container:SetPoint("TOPLEFT", 8, -66)
    container:SetPoint("BOTTOMRIGHT", -8, 50)
    container:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        tile = false,
        edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    container:SetBackdropColor(0.05, 0.05, 0.05, 0.9)
    container:SetBackdropBorderColor(0.2, 0.2, 0.2, 1)

    -- Column headers
    local headerFrame = CreateFrame("Frame", nil, container)
    headerFrame:SetPoint("TOPLEFT", 8, -4)
    headerFrame:SetPoint("TOPRIGHT", -24, -4)
    headerFrame:SetHeight(20)

    local itemHeader = headerFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    itemHeader:SetPoint("LEFT", 40, 0)
    itemHeader:SetText(L["ITEM"] or "Item")
    itemHeader:SetTextColor(0.7, 0.7, 0.7)

    local winnerHeader = headerFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    winnerHeader:SetPoint("LEFT", 280, 0)
    winnerHeader:SetText(L["WINNER"] or "Winner")
    winnerHeader:SetTextColor(0.7, 0.7, 0.7)

    local timeHeader = headerFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    timeHeader:SetPoint("RIGHT", -60, 0)
    timeHeader:SetText(L["TIME_REMAINING"] or "Time Left")
    timeHeader:SetTextColor(0.7, 0.7, 0.7)

    -- Separator
    local sep = container:CreateTexture(nil, "ARTWORK")
    sep:SetPoint("TOPLEFT", 8, -24)
    sep:SetPoint("TOPRIGHT", -8, -24)
    sep:SetHeight(1)
    sep:SetColorTexture(0.3, 0.3, 0.3, 1)

    -- Scroll frame
    local scrollFrame = CreateFrame("ScrollFrame", nil, container, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 4, -28)
    scrollFrame:SetPoint("BOTTOMRIGHT", -24, 4)

    local content = CreateFrame("Frame", nil, scrollFrame)
    content:SetSize(1, 800)
    scrollFrame:SetScrollChild(content)

    scrollFrame:SetScript("OnSizeChanged", function(sf, w, h)
        content:SetWidth(w)
    end)

    self.listContainer = container
    self.listContent = content
    self.scrollFrame = scrollFrame

    -- Empty state text
    self.emptyText = container:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    self.emptyText:SetPoint("CENTER")
    self.emptyText:SetText(L["NO_PENDING_TRADES"] or "No items pending trade")
    self.emptyText:SetTextColor(0.5, 0.5, 0.5)
end

--- Create footer
function LoothingTradePanelMixin:CreateFooter()
    local L = LOOTHING_LOCALE

    local footer = CreateFrame("Frame", nil, self.frame)
    footer:SetPoint("BOTTOMLEFT", 8, 8)
    footer:SetPoint("BOTTOMRIGHT", -8, 8)
    footer:SetHeight(36)

    -- Refresh button
    self.refreshButton = CreateFrame("Button", nil, footer, "UIPanelButtonTemplate")
    self.refreshButton:SetSize(80, 26)
    self.refreshButton:SetPoint("LEFT")
    self.refreshButton:SetText(L["REFRESH"] or "Refresh")
    self.refreshButton:SetScript("OnClick", function()
        self:Refresh()
    end)

    -- Clear completed button
    self.clearButton = CreateFrame("Button", nil, footer, "UIPanelButtonTemplate")
    self.clearButton:SetSize(120, 26)
    self.clearButton:SetPoint("LEFT", self.refreshButton, "RIGHT", 8, 0)
    self.clearButton:SetText(L["CLEAR_COMPLETED"] or "Clear Completed")
    self.clearButton:SetScript("OnClick", function()
        self:ClearCompleted()
    end)

    -- Auto-trade checkbox
    self.autoTradeCheckbox = CreateFrame("CheckButton", nil, footer, "UICheckButtonTemplate")
    self.autoTradeCheckbox:SetPoint("RIGHT", -10, 0)
    self.autoTradeCheckbox:SetSize(24, 24)
    self.autoTradeCheckbox:SetScript("OnClick", function(checkbox)
        local checked = checkbox:GetChecked()
        if Loothing.Settings then
            Loothing.Settings:SetAutoTrade(checked)
        end
    end)

    local checkboxLabel = footer:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    checkboxLabel:SetPoint("RIGHT", self.autoTradeCheckbox, "LEFT", -4, 0)
    checkboxLabel:SetText(L["AUTO_TRADE"] or "Auto-trade")

    self.footer = footer
end

--[[--------------------------------------------------------------------
    Event Registration
----------------------------------------------------------------------]]

--- Register for trade queue events
function LoothingTradePanelMixin:RegisterEvents()
    if not Loothing.TradeQueue then return end

    Loothing.TradeQueue:RegisterCallback("OnItemQueued", function()
        self:Refresh()
    end, self)

    Loothing.TradeQueue:RegisterCallback("OnItemRemoved", function()
        self:Refresh()
    end, self)

    Loothing.TradeQueue:RegisterCallback("OnItemTraded", function()
        self:Refresh()
    end, self)
end

--[[--------------------------------------------------------------------
    Display
----------------------------------------------------------------------]]

--- Refresh the display
function LoothingTradePanelMixin:Refresh()
    self:UpdateHeader()
    self:UpdateFooter()
    self:RefreshList()
end

--- Update header display
function LoothingTradePanelMixin:UpdateHeader()
    local L = LOOTHING_LOCALE

    if not Loothing.TradeQueue then
        self.countText:SetText("")
        return
    end

    local pending = Loothing.TradeQueue:GetAllPending()
    local count = #pending

    if count == 0 then
        self.countText:SetText(L["NO_ITEMS_TO_TRADE"] or "No items to trade")
    elseif count == 1 then
        self.countText:SetText(L["ONE_ITEM_TO_TRADE"] or "1 item awaiting trade")
    else
        self.countText:SetText(string.format(L["N_ITEMS_TO_TRADE"] or "%d items awaiting trade", count))
    end
end

--- Update footer
function LoothingTradePanelMixin:UpdateFooter()
    -- Update auto-trade checkbox
    if Loothing.Settings then
        local autoTrade = Loothing.Settings:GetAutoTrade()
        self.autoTradeCheckbox:SetChecked(autoTrade)
    end
end

--- Refresh the list
function LoothingTradePanelMixin:RefreshList()
    -- Return active rows to the pool
    for _, row in ipairs(self.rows) do
        if row.flashTicker then
            row.flashTicker:Cancel()
            row.flashTicker = nil
        end
        row:Hide()
        self.rowPool[#self.rowPool + 1] = row
    end
    wipe(self.rows)

    if not Loothing.TradeQueue then
        self.emptyText:Show()
        return
    end

    local queue = Loothing.TradeQueue:GetQueue()
    if not queue or queue:GetSize() == 0 then
        self.emptyText:Show()
        return
    end

    self.emptyText:Hide()

    local yOffset = 0
    local rowHeight = 40
    local spacing = 2

    for _, entry in queue:Enumerate() do
        -- Skip traded items
        if not entry.traded then
            local row = self:GetOrCreateRow()
            row:SetEntry(entry)

            row:SetPoint("TOPLEFT", 0, yOffset)
            row:SetPoint("TOPRIGHT", 0, yOffset)
            row:Show()

            self.rows[#self.rows + 1] = row
            yOffset = yOffset - rowHeight - spacing
        end
    end

    -- Update content height
    self.listContent:SetHeight(math.abs(yOffset) + 20)

    -- Cancel existing timer before potentially recreating
    if self.updateTimer then
        self.updateTimer:Cancel()
        self.updateTimer = nil
    end

    -- Only start ticker if there are visible rows to update
    if #self.rows > 0 then
        self.updateTimer = C_Timer.NewTicker(1, function()
            self:UpdateTimers()
        end)
    end
end

--- Update time remaining on rows (with flash warnings at 20min and 5min)
function LoothingTradePanelMixin:UpdateTimers()
    for _, row in ipairs(self.rows) do
        if row:IsShown() then
            row:UpdateTimeRemaining()

            -- Flash warnings at critical thresholds
            if row.entry and Loothing.TradeQueue then
                local remaining = Loothing.TradeQueue:GetTimeRemaining(row.entry)
                local entryKey = row.entry.itemGUID or ""

                if not self.warningsSent then self.warningsSent = {} end

                -- 20-minute warning
                if remaining <= 1200 and remaining > 1195 and not self.warningsSent[entryKey .. "_20m"] then
                    self.warningsSent[entryKey .. "_20m"] = true
                    local name = LoothingUtils.GetItemName(row.entry.itemLink) or "Item"
                    local winner = LoothingUtils.GetShortName(row.entry.winner)
                    Loothing:Warn(string.format("Trade window for %s -> %s expires in 20 minutes!", name, winner))
                    self:FlashRow(row)
                end

                -- 5-minute warning
                if remaining <= 300 and remaining > 295 and not self.warningsSent[entryKey .. "_5m"] then
                    self.warningsSent[entryKey .. "_5m"] = true
                    local name = LoothingUtils.GetItemName(row.entry.itemLink) or "Item"
                    local winner = LoothingUtils.GetShortName(row.entry.winner)
                    Loothing:Warn(string.format("URGENT: Trade window for %s -> %s expires in 5 minutes!", name, winner))
                    self:FlashRow(row)
                end
            end
        end
    end
end

--- Flash a row to draw attention
-- @param row Frame
function LoothingTradePanelMixin:FlashRow(row)
    if not row or not row.bg then return end

    -- Cancel any in-progress flash for this row
    if row.flashTicker then
        row.flashTicker:Cancel()
        row.flashTicker = nil
    end

    -- Flash the background red briefly
    local flashCount = 0
    row.flashTicker = C_Timer.NewTicker(0.3, function()
        flashCount = flashCount + 1
        if flashCount % 2 == 1 then
            row.bg:SetColorTexture(0.6, 0.1, 0.1, 0.7)
            row.bg:Show()
        else
            row.bg:SetColorTexture(0.1, 0.1, 0.1, 0.5)
            row.bg:Hide()
        end
        if flashCount >= 6 then
            row.bg:SetColorTexture(0.1, 0.1, 0.1, 0.5)
            row.bg:Hide()
            row.flashTicker = nil
        end
    end, 6)
end

--[[--------------------------------------------------------------------
    Row Management
----------------------------------------------------------------------]]

--- Get or create a row frame
-- @return Frame - Trade row
function LoothingTradePanelMixin:GetOrCreateRow()
    -- Reuse a pooled row
    if #self.rowPool > 0 then
        return table.remove(self.rowPool)
    end

    -- Create new row
    return self:CreateRow()
end

--- Create a trade row
-- @return Frame - Trade row
function LoothingTradePanelMixin:CreateRow()
    local row = CreateFrame("Frame", nil, self.listContent)
    row:SetHeight(40)

    -- Background (hover highlight)
    row.bg = row:CreateTexture(nil, "BACKGROUND")
    row.bg:SetAllPoints()
    row.bg:SetColorTexture(0.1, 0.1, 0.1, 0.5)
    row.bg:Hide()

    -- Item icon
    row.icon = CreateFrame("Button", nil, row)
    row.icon:SetPoint("LEFT", 4, 0)
    row.icon:SetSize(32, 32)
    row.icon:SetNormalTexture("Interface\\Icons\\INV_Misc_QuestionMark")

    -- Item link text
    row.itemText = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    row.itemText:SetPoint("LEFT", row.icon, "RIGHT", 8, 0)
    row.itemText:SetWidth(200)
    row.itemText:SetJustifyH("LEFT")

    -- Winner button (clickable to trade)
    row.winnerButton = CreateFrame("Button", nil, row)
    row.winnerButton:SetPoint("LEFT", 280, 0)
    row.winnerButton:SetSize(150, 24)
    row.winnerButton:SetNormalFontObject("GameFontNormal")
    row.winnerButton:SetHighlightFontObject("GameFontHighlight")

    -- Time remaining text
    row.timeText = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    row.timeText:SetPoint("RIGHT", -70, 0)

    -- Trade button
    row.tradeButton = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
    row.tradeButton:SetSize(50, 20)
    row.tradeButton:SetPoint("RIGHT", -32, 0)
    row.tradeButton:SetText("Trade")

    -- Arrow indicator (shows direction: you -> winner)
    row.arrowText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.arrowText:SetPoint("RIGHT", row.winnerButton, "LEFT", -4, 0)
    row.arrowText:SetText("->")
    row.arrowText:SetTextColor(0.5, 0.8, 0.5)

    -- Remove button
    row.removeButton = CreateFrame("Button", nil, row)
    row.removeButton:SetPoint("RIGHT", -4, 0)
    row.removeButton:SetSize(24, 24)
    row.removeButton:SetNormalTexture("Interface\\Buttons\\UI-GroupLoot-Pass-Up")
    row.removeButton:SetHighlightTexture("Interface\\Buttons\\UI-GROUPLOOT-PASS-HIGHLIGHT")
    row.removeButton:SetPushedTexture("Interface\\Buttons\\UI-GROUPLOOT-PASS-DOWN")

    -- Hover effect
    row:SetScript("OnEnter", function(self)
        self.bg:Show()
    end)

    row:SetScript("OnLeave", function(self)
        self.bg:Hide()
    end)

    -- Store entry
    row.entry = nil

    -- Set entry method
    row.SetEntry = function(self, entry)
        self.entry = entry

        -- Icon
        local texture = select(10, C_Item.GetItemInfo(entry.itemLink)) or "Interface\\Icons\\INV_Misc_QuestionMark"
        self.icon:SetNormalTexture(texture)

        -- Item text
        local quality = LoothingUtils.GetItemQuality(entry.itemLink)
        local r, g, b = C_Item.GetItemQualityColor(quality or 0)
        local name = LoothingUtils.GetItemName(entry.itemLink) or "Unknown"
        self.itemText:SetText(name)
        self.itemText:SetTextColor(r, g, b)

        -- Winner
        local shortName = LoothingUtils.GetShortName(entry.winner)
        self.winnerButton:SetText(shortName)

        -- Icon tooltip
        self.icon:SetScript("OnEnter", function()
            GameTooltip:SetOwner(self.icon, "ANCHOR_RIGHT")
            GameTooltip:SetHyperlink(entry.itemLink)
            GameTooltip:Show()
        end)

        self.icon:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)

        self.icon:SetScript("OnClick", function(_, button)
            if IsModifiedClick() then
                HandleModifiedItemClick(entry.itemLink)
            end
        end)

        -- Helper: find UnitId for a player name
        local function FindUnitIdForPlayer(playerName)
            local shortName = Ambiguate(playerName, "short")
            for i = 1, GetNumGroupMembers() do
                local unit = IsInRaid() and ("raid" .. i) or ("party" .. i)
                local uName = UnitName(unit)
                if UnitExists(unit) and not LoothingUtils.IsSecretValue(uName) and uName == shortName then
                    return unit
                end
            end
            local tName = UnitName("target")
            if UnitExists("target") and not LoothingUtils.IsSecretValue(tName) and tName == shortName then
                return "target"
            end
            return nil
        end

        -- Winner button click
        self.winnerButton:SetScript("OnClick", function()
            if Loothing.TradeQueue then
                local unitId = FindUnitIdForPlayer(entry.winner)
                if unitId and CheckInteractDistance(unitId, 2) then
                    InitiateTrade(unitId)
                else
                    local shortName = LoothingUtils.GetShortName(entry.winner)
                    Loothing:Print(string.format("%s is not in range to trade", shortName))
                end
            end
        end)

        -- Trade button click
        self.tradeButton:SetScript("OnClick", function()
            local unitId = FindUnitIdForPlayer(entry.winner)
            if unitId and CheckInteractDistance(unitId, 2) then
                InitiateTrade(unitId)
            else
                local shortName = LoothingUtils.GetShortName(entry.winner)
                Loothing:Print(string.format("%s is not in range to trade", shortName))
            end
        end)

        -- Remove button
        self.removeButton:SetScript("OnEnter", function()
            GameTooltip:SetOwner(self.removeButton, "ANCHOR_RIGHT")
            GameTooltip:SetText("Remove from queue", nil, nil, nil, nil, true)
            GameTooltip:Show()
        end)

        self.removeButton:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)

        self.removeButton:SetScript("OnClick", function()
            if Loothing.TradeQueue then
                Loothing.TradeQueue:RemoveFromQueue(entry.itemGUID)
            end
        end)

        -- Update time
        self:UpdateTimeRemaining()
    end

    -- Update time remaining method
    row.UpdateTimeRemaining = function(self)
        if not self.entry then return end

        if Loothing.TradeQueue then
            local remaining = Loothing.TradeQueue:GetTimeRemaining(self.entry)
            local hours = math.floor(remaining / 3600)
            local minutes = math.floor((remaining % 3600) / 60)
            local seconds = remaining % 60

            local color
            if remaining < 600 then -- < 10 minutes
                color = "|cffff0000" -- Red
            elseif remaining < 1800 then -- < 30 minutes
                color = "|cffffa500" -- Orange
            else
                color = "|cffffffff" -- White
            end

            if hours > 0 then
                self.timeText:SetText(string.format("%s%dh %dm|r", color, hours, minutes))
            else
                self.timeText:SetText(string.format("%s%dm %ds|r", color, minutes, seconds))
            end
        end
    end

    return row
end

--[[--------------------------------------------------------------------
    Actions
----------------------------------------------------------------------]]

--- Clear completed (traded) items from the queue
function LoothingTradePanelMixin:ClearCompleted()
    if not Loothing.TradeQueue then return end

    local queue = Loothing.TradeQueue:GetQueue()
    local removed = 0

    -- Collect items to remove (can't modify during iteration)
    local toRemove = {}
    for _, entry in queue:Enumerate() do
        if entry.traded then
            toRemove[#toRemove + 1] = entry.itemGUID
        end
    end

    -- Remove them
    for _, guid in ipairs(toRemove) do
        if Loothing.TradeQueue:RemoveFromQueue(guid) then
            removed = removed + 1
        end
    end

    if removed > 0 then
        Loothing:Print(string.format("Cleared %d completed trade(s)", removed))
    else
        Loothing:Print("No completed trades to clear")
    end

    self:Refresh()
end

--[[--------------------------------------------------------------------
    Frame Access
----------------------------------------------------------------------]]

function LoothingTradePanelMixin:GetFrame()
    return self.frame
end

function LoothingTradePanelMixin:Show()
    self.frame:Show()
    self:Refresh()
end

function LoothingTradePanelMixin:Hide()
    self.frame:Hide()

    -- Stop update timer
    if self.updateTimer then
        self.updateTimer:Cancel()
        self.updateTimer = nil
    end
end

--[[--------------------------------------------------------------------
    Factory
----------------------------------------------------------------------]]

function CreateLoothingTradePanel(parent)
    local panel = LoolibCreateFromMixins(LoothingTradePanelMixin)
    panel:Init(parent)
    return panel
end
