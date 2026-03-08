--[[--------------------------------------------------------------------
    Loothing - Loot Council Addon for WoW 12.0+
    HistoryPanel - Past loot history browser
----------------------------------------------------------------------]]

local Loolib = LibStub("Loolib")

--[[--------------------------------------------------------------------
    LoothingHistoryPanelMixin
----------------------------------------------------------------------]]

LoothingHistoryPanelMixin = LoolibCreateFromMixins(LoolibCallbackRegistryMixin)

local HISTORY_PANEL_EVENTS = {}

--- Initialize the history panel
-- @param parent Frame - Parent frame
function LoothingHistoryPanelMixin:Init(parent)
    LoolibCallbackRegistryMixin.OnLoad(self)
    self:GenerateCallbackEvents(HISTORY_PANEL_EVENTS)
    self.parent = parent
    self.historyRows = {}
    self.selectedDate = nil
    self.selectedPlayer = nil
    self.displayedCount = 0

    self:CreateFrame()
    self:CreateElements()
end

--- Create the main frame
function LoothingHistoryPanelMixin:CreateFrame()
    local frame = CreateFrame("Frame", nil, self.parent)
    frame:SetAllPoints()

    self.frame = frame
end

--- Create UI elements
function LoothingHistoryPanelMixin:CreateElements()
    local L = LOOTHING_LOCALE

    -- Three-pane container (starts below filter bar)
    local container = CreateFrame("Frame", nil, self.frame)
    container:SetPoint("TOPLEFT", 8, -40)
    container:SetPoint("BOTTOMRIGHT", -8, 50)
    self.paneContainer = container

    -- Left pane: Date list
    local datePane = CreateFrame("Frame", nil, container, "BackdropTemplate")
    datePane:SetPoint("TOPLEFT")
    datePane:SetPoint("BOTTOMLEFT")
    datePane:SetWidth(100)
    datePane:SetBackdrop({ bgFile = "Interface\\Tooltips\\UI-Tooltip-Background" })
    datePane:SetBackdropColor(0, 0, 0, 0.3)
    self.datePane = datePane

    -- Center pane: Player list
    local playerPane = CreateFrame("Frame", nil, container, "BackdropTemplate")
    playerPane:SetPoint("TOPLEFT", datePane, "TOPRIGHT", 2, 0)
    playerPane:SetPoint("BOTTOMLEFT", datePane, "BOTTOMRIGHT", 2, 0)
    playerPane:SetWidth(120)
    playerPane:SetBackdrop({ bgFile = "Interface\\Tooltips\\UI-Tooltip-Background" })
    playerPane:SetBackdropColor(0, 0, 0, 0.3)
    self.playerPane = playerPane

    -- Right pane: History (filter bar + list)
    local historyPane = CreateFrame("Frame", nil, container)
    historyPane:SetPoint("TOPLEFT", playerPane, "TOPRIGHT", 2, 0)
    historyPane:SetPoint("BOTTOMRIGHT")
    self.historyPane = historyPane

    -- Create sub-elements
    self:CreateDateList()
    self:CreatePlayerList()
    self:CreateFilterBar()
    self:CreateHistoryList()
    self:CreateFooter()
end

--- Create filter bar with response, class, instance, and date range filters
function LoothingHistoryPanelMixin:CreateFilterBar()
    local L = LOOTHING_LOCALE

    local filterBar = CreateFrame("Frame", nil, self.frame)
    filterBar:SetPoint("TOPLEFT", 8, -8)
    filterBar:SetPoint("TOPRIGHT", -8, -8)
    filterBar:SetHeight(28)

    -- Search box (placeholder text via focus scripts)
    local searchBox = CreateFrame("EditBox", nil, filterBar, "InputBoxTemplate")
    searchBox:SetSize(120, 20)
    searchBox:SetPoint("LEFT")
    searchBox:SetAutoFocus(false)
    searchBox:SetText(L["SEARCH"])
    searchBox:SetTextColor(0.5, 0.5, 0.5)
    searchBox:SetScript("OnEditFocusGained", function(self)
        if self:GetText() == L["SEARCH"] then
            self:SetText("")
            self:SetTextColor(1, 1, 1)
        end
    end)
    searchBox:SetScript("OnEditFocusLost", function(self)
        if self:GetText() == "" then
            self:SetText(L["SEARCH"])
            self:SetTextColor(0.5, 0.5, 0.5)
        end
    end)
    searchBox:SetScript("OnTextChanged", function(self)
        local text = self:GetText()
        if text == L["SEARCH"] then return end
        self:GetParent().mixin:OnSearchChanged(text)
    end)
    searchBox:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
    end)

    self.searchBox = searchBox

    -- Winner filter dropdown
    local winnerButton = CreateFrame("Button", nil, filterBar, "UIPanelButtonTemplate")
    winnerButton:SetSize(80, 20)
    winnerButton:SetPoint("LEFT", searchBox, "RIGHT", 8, 0)
    winnerButton:SetText(L["ALL_WINNERS"])
    winnerButton:SetScript("OnClick", function()
        self:ShowWinnerDropdown()
    end)
    self.winnerButton = winnerButton

    -- Response filter
    local responseButton = CreateFrame("Button", nil, filterBar, "UIPanelButtonTemplate")
    responseButton:SetSize(80, 20)
    responseButton:SetPoint("LEFT", winnerButton, "RIGHT", 4, 0)
    responseButton:SetText("Response")
    responseButton:SetScript("OnClick", function()
        self:ShowResponseFilterDropdown()
    end)
    self.responseFilterButton = responseButton

    -- Class filter
    local classButton = CreateFrame("Button", nil, filterBar, "UIPanelButtonTemplate")
    classButton:SetSize(60, 20)
    classButton:SetPoint("LEFT", responseButton, "RIGHT", 4, 0)
    classButton:SetText("Class")
    classButton:SetScript("OnClick", function()
        self:ShowClassFilterDropdown()
    end)
    self.classFilterButton = classButton

    -- Clear filters button
    local clearButton = CreateFrame("Button", nil, filterBar, "UIPanelButtonTemplate")
    clearButton:SetSize(50, 20)
    clearButton:SetPoint("RIGHT")
    clearButton:SetText(L["CLEAR"])
    clearButton:SetScript("OnClick", function()
        self:ClearFilters()
    end)

    -- Entry count
    self.countText = filterBar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    self.countText:SetPoint("RIGHT", clearButton, "LEFT", -8, 0)
    self.countText:SetTextColor(0.7, 0.7, 0.7)

    filterBar.mixin = self
    self.filterBar = filterBar
end

--- Show response filter dropdown
function LoothingHistoryPanelMixin:ShowResponseFilterDropdown()
    MenuUtil.CreateContextMenu(self.responseFilterButton, function(ownerRegion, rootDescription)
        rootDescription:CreateButton("All Responses", function()
            self:SetResponseFilter(nil)
        end)
        rootDescription:CreateDivider()

        for id, info in pairs(LOOTHING_RESPONSE_INFO) do
            rootDescription:CreateButton(info.name, function()
                self:SetResponseFilter(id)
            end)
        end
    end)
end

--- Set response filter
function LoothingHistoryPanelMixin:SetResponseFilter(responseId)
    if not Loothing.History then return end
    local filter = Loothing.History.filter or {}
    filter.response = responseId

    if responseId then
        local info = LOOTHING_RESPONSE_INFO[responseId]
        self.responseFilterButton:SetText(info and info.name or "?")
    else
        self.responseFilterButton:SetText("Response")
    end

    Loothing.History:SetFilter(filter)
    self:Refresh()
end

--- Show class filter dropdown
function LoothingHistoryPanelMixin:ShowClassFilterDropdown()
    local classes = { "WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST", "DEATHKNIGHT",
                      "SHAMAN", "MAGE", "WARLOCK", "MONK", "DRUID", "DEMONHUNTER", "EVOKER" }

    MenuUtil.CreateContextMenu(self.classFilterButton, function(ownerRegion, rootDescription)
        rootDescription:CreateButton("All Classes", function()
            self:SetClassFilter(nil)
        end)
        rootDescription:CreateDivider()

        for _, class in ipairs(classes) do
            rootDescription:CreateButton(class, function()
                self:SetClassFilter(class)
            end)
        end
    end)
end

--- Set class filter
function LoothingHistoryPanelMixin:SetClassFilter(class)
    if not Loothing.History then return end
    local filter = Loothing.History.filter or {}
    filter.class = class

    self.classFilterButton:SetText(class or "Class")
    Loothing.History:SetFilter(filter)
    self:Refresh()
end

--- Create history list
function LoothingHistoryPanelMixin:CreateHistoryList()
    local container = CreateFrame("Frame", nil, self.historyPane, "BackdropTemplate")
    container:SetPoint("TOPLEFT", 0, 0)
    container:SetPoint("BOTTOMRIGHT", 0, 0)
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

    local L = LOOTHING_LOCALE

    local dateHeader = headerFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    dateHeader:SetPoint("LEFT")
    dateHeader:SetWidth(80)
    dateHeader:SetText(L["DATE"])
    dateHeader:SetTextColor(0.7, 0.7, 0.7)

    local itemHeader = headerFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    itemHeader:SetPoint("LEFT", dateHeader, "RIGHT", 8, 0)
    itemHeader:SetText(L["ITEM"])
    itemHeader:SetTextColor(0.7, 0.7, 0.7)

    local winnerHeader = headerFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    winnerHeader:SetPoint("RIGHT", -80, 0)
    winnerHeader:SetText(L["WINNER"])
    winnerHeader:SetTextColor(0.7, 0.7, 0.7)

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

    -- Frame pool for history rows
    self.rowPool = CreateFramePool("Button", self.listContent, nil, function(pool, row)
        row:Hide()
        row:ClearAllPoints()
        row:SetScript("OnEnter", nil)
        row:SetScript("OnLeave", nil)
        row:SetScript("OnClick", nil)
        if row.colorBar then
            row.colorBar:Hide()
        end
    end)

    -- Empty state
    self.emptyText = container:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    self.emptyText:SetPoint("CENTER")
    self.emptyText:SetText(L["NO_HISTORY"])
    self.emptyText:SetTextColor(0.5, 0.5, 0.5)
end

--- Create footer
function LoothingHistoryPanelMixin:CreateFooter()
    local L = LOOTHING_LOCALE

    local footer = CreateFrame("Frame", nil, self.frame)
    footer:SetPoint("BOTTOMLEFT", 8, 8)
    footer:SetPoint("BOTTOMRIGHT", -8, 8)
    footer:SetHeight(36)

    -- Export button
    self.exportButton = CreateFrame("Button", nil, footer, "UIPanelButtonTemplate")
    self.exportButton:SetSize(80, 26)
    self.exportButton:SetPoint("LEFT")
    self.exportButton:SetText(L["EXPORT"])
    self.exportButton:SetScript("OnClick", function()
        self:ShowExportDialog()
    end)

    -- Clear history button
    self.clearButton = CreateFrame("Button", nil, footer, "UIPanelButtonTemplate")
    self.clearButton:SetSize(100, 26)
    self.clearButton:SetPoint("RIGHT")
    self.clearButton:SetText(L["CLEAR_HISTORY"])
    self.clearButton:SetScript("OnClick", function()
        self:ConfirmClearHistory()
    end)

    self.footer = footer
end

--- Create date list in the left pane
function LoothingHistoryPanelMixin:CreateDateList()
    -- Header
    local header = self.datePane:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    header:SetPoint("TOP", 0, -4)
    header:SetText("Dates")

    -- Scroll frame
    local scroll = CreateFrame("ScrollFrame", nil, self.datePane, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 4, -20)
    scroll:SetPoint("BOTTOMRIGHT", -22, 4)

    local content = CreateFrame("Frame", nil, scroll)
    content:SetWidth(scroll:GetWidth())
    scroll:SetScrollChild(content)

    self.dateScroll = scroll
    self.dateContent = content
    self.dateButtonPool = CreateFramePool("Button", content)

    -- "All Dates" button at top
    local allBtn = CreateFrame("Button", nil, content)
    allBtn:SetSize(110, 20)
    allBtn:SetPoint("TOPLEFT", 2, -2)
    allBtn.text = allBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    allBtn.text:SetAllPoints()
    allBtn.text:SetText("|cffffd700All Dates|r")
    allBtn:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
    allBtn:SetScript("OnClick", function()
        self.selectedDate = nil
        self:Refresh()
    end)
    self.allDatesBtn = allBtn
end

--- Create player list in the center pane
function LoothingHistoryPanelMixin:CreatePlayerList()
    -- Header
    local header = self.playerPane:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    header:SetPoint("TOP", 0, -4)
    header:SetText("Players")

    -- Scroll frame
    local scroll = CreateFrame("ScrollFrame", nil, self.playerPane, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 4, -20)
    scroll:SetPoint("BOTTOMRIGHT", -22, 4)

    local content = CreateFrame("Frame", nil, scroll)
    content:SetWidth(scroll:GetWidth())
    scroll:SetScrollChild(content)

    self.playerScroll = scroll
    self.playerContent = content
    self.playerButtonPool = CreateFramePool("Button", content)

    -- "All Players" button at top
    local allBtn = CreateFrame("Button", nil, content)
    allBtn:SetSize(130, 20)
    allBtn:SetPoint("TOPLEFT", 2, -2)
    allBtn.text = allBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    allBtn.text:SetAllPoints()
    allBtn.text:SetText("|cffffd700All Players|r")
    allBtn:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
    allBtn:SetScript("OnClick", function()
        self.selectedPlayer = nil
        self:Refresh()
    end)
    self.allPlayersBtn = allBtn
end

--[[--------------------------------------------------------------------
    Display
----------------------------------------------------------------------]]

--- Refresh the history display
function LoothingHistoryPanelMixin:Refresh()
    self:RefreshDateList()
    self:RefreshPlayerList()
    self:RefreshList()
    self:UpdateCount()
end

--- Refresh the date list in the left pane
function LoothingHistoryPanelMixin:RefreshDateList()
    self.dateButtonPool:ReleaseAll()

    if not Loothing.History then return end

    local dates = {}
    local seen = {}

    for _, entry in Loothing.History:GetEntries():Enumerate() do
        if entry.timestamp then
            local d = date("%Y-%m-%d", entry.timestamp)
            if not seen[d] then
                seen[d] = true
                dates[#dates + 1] = d
            end
        end
    end

    -- Newest first
    table.sort(dates, function(a, b) return a > b end)

    -- Update "All Dates" highlight
    if not self.selectedDate then
        self.allDatesBtn.text:SetText("|cffffd700All Dates|r")
    else
        self.allDatesBtn.text:SetText("All Dates")
    end

    local yOffset = -24  -- Below "All Dates" button
    for _, d in ipairs(dates) do
        local btn = self.dateButtonPool:Acquire()
        btn:SetSize(110, 18)
        btn:SetPoint("TOPLEFT", self.dateContent, "TOPLEFT", 2, yOffset)

        if not btn.text then
            btn.text = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            btn.text:SetAllPoints()
            btn:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
        end

        local isSelected = self.selectedDate == d
        btn.text:SetText(isSelected and ("|cffffd700" .. d .. "|r") or d)

        local dateValue = d
        btn:SetScript("OnClick", function()
            self.selectedDate = dateValue
            self:Refresh()
        end)
        btn:Show()

        yOffset = yOffset - 18
    end

    self.dateContent:SetHeight(math.abs(yOffset) + 4)
end

--- Refresh the player list in the center pane
function LoothingHistoryPanelMixin:RefreshPlayerList()
    self.playerButtonPool:ReleaseAll()

    if not Loothing.History then return end

    local players = {}
    local seen = {}

    for _, entry in Loothing.History:GetEntries():Enumerate() do
        -- Apply date filter from left pane
        local passesDate = true
        if self.selectedDate then
            local entryDate = entry.timestamp and date("%Y-%m-%d", entry.timestamp)
            if entryDate ~= self.selectedDate then
                passesDate = false
            end
        end

        if passesDate and entry.winner and not seen[entry.winner] then
            seen[entry.winner] = true
            players[#players + 1] = { name = entry.winner, class = entry.class }
        end
    end

    table.sort(players, function(a, b) return a.name < b.name end)

    -- Auto-deselect player if no longer in list
    if self.selectedPlayer and not seen[self.selectedPlayer] then
        self.selectedPlayer = nil
    end

    -- Update "All Players" highlight
    if not self.selectedPlayer then
        self.allPlayersBtn.text:SetText("|cffffd700All Players|r")
    else
        self.allPlayersBtn.text:SetText("All Players")
    end

    local yOffset = -24  -- Below "All Players" button
    for _, player in ipairs(players) do
        local btn = self.playerButtonPool:Acquire()
        btn:SetSize(130, 18)
        btn:SetPoint("TOPLEFT", self.playerContent, "TOPLEFT", 2, yOffset)

        if not btn.text then
            btn.text = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            btn.text:SetAllPoints()
            btn:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
        end

        -- Class-color the name
        local displayName = player.name
        local classColor = RAID_CLASS_COLORS and player.class and RAID_CLASS_COLORS[player.class]
        if classColor then
            displayName = string.format("|cff%02x%02x%02x%s|r",
                classColor.r * 255, classColor.g * 255, classColor.b * 255, player.name)
        end

        if self.selectedPlayer == player.name then
            displayName = "|cffffd700>|r " .. displayName
        end
        btn.text:SetText(displayName)

        local playerName = player.name
        btn:SetScript("OnClick", function()
            self.selectedPlayer = playerName
            self:Refresh()
        end)
        btn:Show()

        yOffset = yOffset - 18
    end

    self.playerContent:SetHeight(math.abs(yOffset) + 4)
end

--- Refresh the history list
function LoothingHistoryPanelMixin:RefreshList()
    self.rowPool:ReleaseAll()
    wipe(self.historyRows)

    if not Loothing.History then
        self.emptyText:Show()
        self.displayedCount = 0
        return
    end

    local entries = Loothing.History:GetFilteredEntries()
    if not entries or entries:GetSize() == 0 then
        self.emptyText:Show()
        self.displayedCount = 0
        return
    end

    local yOffset = 0
    local rowHeight = 36
    local spacing = 2

    for _, entry in entries:Enumerate() do
        local passesFilter = true

        -- Date pane filter
        if self.selectedDate and passesFilter then
            local entryDate = entry.timestamp and date("%Y-%m-%d", entry.timestamp)
            if entryDate ~= self.selectedDate then
                passesFilter = false
            end
        end

        -- Player pane filter
        if self.selectedPlayer and passesFilter then
            if entry.winner ~= self.selectedPlayer then
                passesFilter = false
            end
        end

        if passesFilter then
            local row = self.rowPool:Acquire()
            self:SetupHistoryRow(row, entry, yOffset)
            self.historyRows[#self.historyRows + 1] = row
            yOffset = yOffset - rowHeight - spacing
        end
    end

    self.displayedCount = #self.historyRows

    if self.displayedCount > 0 then
        self.emptyText:Hide()
    else
        self.emptyText:Show()
    end

    self.listContent:SetHeight(math.abs(yOffset) + 20)
end

--- Initialize child elements on a pooled row (called once per frame)
-- @param row Button - Pooled row frame
local function InitHistoryRowElements(row)
    row:SetHeight(36)

    -- Background
    row.bg = row:CreateTexture(nil, "BACKGROUND")
    row.bg:SetAllPoints()
    row.bg:SetColorTexture(0.1, 0.1, 0.1, 0.5)

    -- Highlight
    row.hl = row:CreateTexture(nil, "HIGHLIGHT")
    row.hl:SetAllPoints()
    row.hl:SetColorTexture(1, 1, 1, 0.1)

    -- Date
    row.dateText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.dateText:SetPoint("LEFT", 4, 0)
    row.dateText:SetWidth(76)
    row.dateText:SetJustifyH("LEFT")

    -- Item icon
    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(28, 28)
    row.icon:SetPoint("LEFT", 84, 0)

    -- Quality border
    row.iconBorder = row:CreateTexture(nil, "OVERLAY")
    row.iconBorder:SetSize(30, 30)
    row.iconBorder:SetPoint("CENTER", row.icon, "CENTER")
    row.iconBorder:SetTexture("Interface\\Common\\WhiteIconFrame")

    -- Item name
    row.nameText = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    row.nameText:SetPoint("LEFT", row.icon, "RIGHT", 8, 0)
    row.nameText:SetPoint("RIGHT", -150, 0)
    row.nameText:SetJustifyH("LEFT")
    row.nameText:SetWordWrap(false)

    -- Winner
    row.winnerText = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    row.winnerText:SetPoint("RIGHT", -4, 0)
    row.winnerText:SetWidth(120)
    row.winnerText:SetJustifyH("RIGHT")

    -- Response color bar (created once, toggled per entry)
    row.colorBar = row:CreateTexture(nil, "ARTWORK")
    row.colorBar:SetSize(3, 32)
    row.colorBar:SetPoint("RIGHT", row.winnerText, "LEFT", -4, 0)
    row.colorBar:Hide()

    row._initialized = true
end

--- Setup a pooled history row with entry data
-- @param row Button - Acquired pooled frame
-- @param entry table - History entry
-- @param yOffset number
function LoothingHistoryPanelMixin:SetupHistoryRow(row, entry, yOffset)
    -- Initialize child elements on first use
    if not row._initialized then
        InitHistoryRowElements(row)
    end

    -- Position
    row:ClearAllPoints()
    row:SetPoint("TOPLEFT", 0, yOffset)
    row:SetPoint("TOPRIGHT", 0, yOffset)

    -- Date
    if entry.timestamp then
        row.dateText:SetText(LoothingUtils.FormatDate(entry.timestamp))
    else
        row.dateText:SetText("")
    end
    row.dateText:SetTextColor(0.7, 0.7, 0.7)

    -- Icon
    local texture = entry.itemID and GetItemIcon(entry.itemID) or "Interface\\Icons\\INV_Misc_QuestionMark"
    row.icon:SetTexture(texture)

    -- Quality color
    local quality = entry.quality or 1
    local r, g, b = C_Item.GetItemQualityColor(quality)
    row.iconBorder:SetVertexColor(r, g, b)

    -- Item name
    row.nameText:SetText(entry.itemName or "Unknown Item")
    row.nameText:SetTextColor(r, g, b)

    -- Winner
    if entry.winner then
        row.winnerText:SetText(LoothingUtils.GetShortName(entry.winner))
    else
        row.winnerText:SetText("")
    end

    -- Response color bar
    if entry.winnerResponse and LOOTHING_RESPONSE_INFO[entry.winnerResponse] then
        local info = LOOTHING_RESPONSE_INFO[entry.winnerResponse]
        row.colorBar:SetColorTexture(info.color.r, info.color.g, info.color.b, 1)
        row.colorBar:Show()
    else
        row.colorBar:Hide()
    end

    -- Tooltip
    row:SetScript("OnEnter", function()
        GameTooltip:SetOwner(row, "ANCHOR_RIGHT")

        if entry.itemLink then
            GameTooltip:SetHyperlink(entry.itemLink)
        else
            GameTooltip:AddLine(entry.itemName or "Unknown Item")
        end

        GameTooltip:AddLine(" ")

        if entry.winner then
            GameTooltip:AddLine(string.format(LOOTHING_LOCALE["AWARDED_TO"], entry.winner), 1, 0.82, 0)
        end

        if entry.encounterName then
            GameTooltip:AddLine(string.format(LOOTHING_LOCALE["FROM_ENCOUNTER"], entry.encounterName), 0.7, 0.7, 0.7)
        end

        if entry.votes then
            GameTooltip:AddLine(string.format(LOOTHING_LOCALE["WITH_VOTES"], entry.votes), 0.7, 0.7, 0.7)
        end

        GameTooltip:Show()
    end)

    row:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    -- Click handling (left = shift-link, right = context menu)
    row:SetScript("OnClick", function(_, button)
        if button == "LeftButton" and entry.itemLink then
            if IsShiftKeyDown() then
                ChatEdit_InsertLink(entry.itemLink)
            end
        elseif button == "RightButton" then
            self:ShowHistoryRowContextMenu(row, entry)
        end
    end)
    row:RegisterForClicks("LeftButtonUp", "RightButtonUp")

    row:Show()
end

--- Show context menu for a history row
-- @param row Frame
-- @param entry table
function LoothingHistoryPanelMixin:ShowHistoryRowContextMenu(row, entry)
    local L = LOOTHING_LOCALE or {}

    MenuUtil.CreateContextMenu(row, function(ownerRegion, rootDescription)
        rootDescription:CreateTitle(entry.itemName or "Unknown")

        -- Link in chat
        if entry.itemLink then
            rootDescription:CreateButton(L["LINK_IN_CHAT"] or "Link in Chat", function()
                ChatEdit_InsertLink(entry.itemLink)
            end)
        end

        -- Filter by winner
        if entry.winner then
            rootDescription:CreateButton(
                string.format(L["FILTER_BY_WINNER"] or "Filter by %s", LoothingUtils.GetShortName(entry.winner)),
                function()
                    self:SetWinnerFilter(entry.winner)
                end
            )
        end

        -- Filter by encounter
        if entry.encounterName then
            rootDescription:CreateButton(string.format("Filter by %s", entry.encounterName), function()
                if Loothing.History then
                    local filter = Loothing.History.filter or {}
                    filter.instance = entry.encounterName
                    Loothing.History:SetFilter(filter)
                    self:Refresh()
                end
            end)
        end

        rootDescription:CreateDivider()

        -- Delete entry
        rootDescription:CreateButton(L["DELETE_ENTRY"] or "Delete Entry", function()
            if Loothing.History and entry.id then
                Loothing.History:DeleteEntry(entry.id)
                self:Refresh()
            end
        end)
    end)
end

--- Update count display
function LoothingHistoryPanelMixin:UpdateCount()
    if not Loothing.History then
        self.countText:SetText("")
        return
    end

    local total = Loothing.History:GetCount()
    local displayed = self.displayedCount or 0

    if total == displayed then
        self.countText:SetText(string.format(LOOTHING_LOCALE["ENTRIES_COUNT"], total))
    else
        self.countText:SetText(string.format(LOOTHING_LOCALE["ENTRIES_FILTERED"], displayed, total))
    end
end

--[[--------------------------------------------------------------------
    Filtering
----------------------------------------------------------------------]]

--- Handle search text change
-- @param text string
function LoothingHistoryPanelMixin:OnSearchChanged(text)
    if not Loothing.History then return end

    local filter = Loothing.History.filter or {}
    filter.searchText = text ~= "" and text or nil

    Loothing.History:SetFilter(filter)
    self:Refresh()
end

--- Show winner dropdown
function LoothingHistoryPanelMixin:ShowWinnerDropdown()
    if not Loothing.History then return end

    local L = LOOTHING_LOCALE
    local winners = Loothing.History:GetUniqueWinners()

    MenuUtil.CreateContextMenu(self.winnerButton, function(ownerRegion, rootDescription)
        rootDescription:CreateButton(L["ALL_WINNERS"], function()
            self:SetWinnerFilter(nil)
        end)
        rootDescription:CreateDivider()

        for _, winner in ipairs(winners) do
            rootDescription:CreateButton(LoothingUtils.GetShortName(winner), function()
                self:SetWinnerFilter(winner)
            end)
        end
    end)
end

--- Set winner filter
-- @param winner string|nil
function LoothingHistoryPanelMixin:SetWinnerFilter(winner)
    if not Loothing.History then return end

    local L = LOOTHING_LOCALE
    local filter = Loothing.History.filter or {}
    filter.winner = winner

    Loothing.History:SetFilter(filter)

    if winner then
        self.winnerButton:SetText(LoothingUtils.GetShortName(winner))
    else
        self.winnerButton:SetText(L["ALL_WINNERS"])
    end

    self:Refresh()
end

--- Clear all filters
function LoothingHistoryPanelMixin:ClearFilters()
    if not Loothing.History then return end

    local L = LOOTHING_LOCALE

    self.searchBox:SetText(LOOTHING_LOCALE["SEARCH"])
    self.searchBox:SetTextColor(0.5, 0.5, 0.5)
    self.winnerButton:SetText(L["ALL_WINNERS"])
    if self.responseFilterButton then
        self.responseFilterButton:SetText("Response")
    end
    if self.classFilterButton then
        self.classFilterButton:SetText("Class")
    end

    self.selectedDate = nil
    self.selectedPlayer = nil

    Loothing.History:ClearFilter()
    self:Refresh()
end

--[[--------------------------------------------------------------------
    Export
----------------------------------------------------------------------]]

--- Show export dialog
function LoothingHistoryPanelMixin:ShowExportDialog()
    if not Loothing.History then return end

    local L = LOOTHING_LOCALE

    -- Create export frame if it doesn't exist
    if not self.exportFrame then
        local frame = CreateFrame("Frame", "LoothingExportFrame", UIParent, "BackdropTemplate")
        frame:SetSize(580, 400)
        frame:SetPoint("CENTER")
        frame:SetFrameStrata("DIALOG")
        frame:SetMovable(true)
        frame:EnableMouse(true)
        frame:SetBackdrop({
            bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
            tile = true,
            tileSize = 32,
            edgeSize = 32,
            insets = { left = 11, right = 12, top = 12, bottom = 11 },
        })

        local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        title:SetPoint("TOP", 0, -16)
        title:SetText(L["EXPORT_HISTORY"])

        local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
        close:SetPoint("TOPRIGHT", -5, -5)
        close:SetScript("OnClick", function()
            frame:Hide()
        end)

        local scrollFrame = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
        scrollFrame:SetPoint("TOPLEFT", 16, -40)
        scrollFrame:SetPoint("BOTTOMRIGHT", -32, 50)

        local editBox = CreateFrame("EditBox", nil, scrollFrame)
        editBox:SetMultiLine(true)
        editBox:SetAutoFocus(false)
        editBox:SetFontObject(GameFontHighlightSmall)
        editBox:SetSize(1, 300)
        scrollFrame:SetScrollChild(editBox)

        scrollFrame:SetScript("OnSizeChanged", function(sf, w, h)
            editBox:SetWidth(w)
        end)

        -- Format buttons
        local csvButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
        csvButton:SetSize(45, 22)
        csvButton:SetPoint("BOTTOMLEFT", 16, 16)
        csvButton:SetText("CSV")
        csvButton:SetScript("OnClick", function()
            editBox:SetText(Loothing.History:ExportCSV())
            editBox:HighlightText()
        end)

        local tsvButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
        tsvButton:SetSize(45, 22)
        tsvButton:SetPoint("LEFT", csvButton, "RIGHT", 4, 0)
        tsvButton:SetText("TSV")
        tsvButton:SetScript("OnClick", function()
            editBox:SetText(Loothing.History:ExportTSV())
            editBox:HighlightText()
        end)

        local luaButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
        luaButton:SetSize(45, 22)
        luaButton:SetPoint("LEFT", tsvButton, "RIGHT", 4, 0)
        luaButton:SetText("Lua")
        luaButton:SetScript("OnClick", function()
            editBox:SetText(Loothing.History:ExportLua())
            editBox:HighlightText()
        end)

        local bbcodeButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
        bbcodeButton:SetSize(70, 22)
        bbcodeButton:SetPoint("LEFT", luaButton, "RIGHT", 4, 0)
        bbcodeButton:SetText("BBCode")
        bbcodeButton:SetScript("OnClick", function()
            editBox:SetText(Loothing.History:ExportBBCode())
            editBox:HighlightText()
        end)

        local discordButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
        discordButton:SetSize(70, 22)
        discordButton:SetPoint("LEFT", bbcodeButton, "RIGHT", 4, 0)
        discordButton:SetText("Discord")
        discordButton:SetScript("OnClick", function()
            editBox:SetText(Loothing.History:ExportDiscord())
            editBox:HighlightText()
        end)

        local jsonButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
        jsonButton:SetSize(50, 22)
        jsonButton:SetPoint("LEFT", discordButton, "RIGHT", 4, 0)
        jsonButton:SetText("JSON")
        jsonButton:SetScript("OnClick", function()
            editBox:SetText(Loothing.History:ExportJSON())
            editBox:HighlightText()
        end)

        local eqdkpButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
        eqdkpButton:SetSize(60, 22)
        eqdkpButton:SetPoint("LEFT", jsonButton, "RIGHT", 4, 0)
        eqdkpButton:SetText(L["EXPORT_EQDKP"] or "EQdkp")
        eqdkpButton:SetScript("OnClick", function()
            editBox:SetText(Loothing.History:ExportEQdkp())
            editBox:HighlightText()
        end)

        local webButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
        webButton:SetSize(50, 22)
        webButton:SetPoint("LEFT", eqdkpButton, "RIGHT", 4, 0)
        webButton:SetText("Web")
        webButton:SetScript("OnClick", function()
            editBox:SetText(Loothing.History:ExportCompact())
            editBox:HighlightText()
        end)

        local selectAll = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
        selectAll:SetSize(80, 22)
        selectAll:SetPoint("BOTTOMRIGHT", -16, 16)
        selectAll:SetText(L["SELECT_ALL"])
        selectAll:SetScript("OnClick", function()
            editBox:HighlightText()
            editBox:SetFocus()
        end)

        self.exportFrame = frame
        self.exportEditBox = editBox
    end

    -- Show with CSV by default
    self.exportEditBox:SetText(Loothing.History:ExportCSV())
    self.exportEditBox:HighlightText()
    self.exportFrame:Show()
end

--- Confirm and clear history
function LoothingHistoryPanelMixin:ConfirmClearHistory()
    LoothingPopups:Show("LOOTHING_CONFIRM_DELETE_HISTORY", {
        count = "all",
        onAccept = function()
            if Loothing.History then
                Loothing.History:ClearHistory()
                self:Refresh()
            end
        end,
    })
end

--[[--------------------------------------------------------------------
    Frame Access
----------------------------------------------------------------------]]

function LoothingHistoryPanelMixin:GetFrame()
    return self.frame
end

function LoothingHistoryPanelMixin:Show()
    self.frame:Show()
    self:Refresh()
end

function LoothingHistoryPanelMixin:Hide()
    self.frame:Hide()
end

--[[--------------------------------------------------------------------
    Factory
----------------------------------------------------------------------]]

function CreateLoothingHistoryPanel(parent)
    local panel = LoolibCreateFromMixins(LoothingHistoryPanelMixin)
    panel:Init(parent)
    return panel
end
