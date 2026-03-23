--[[--------------------------------------------------------------------
    Loothing - Loot Council Addon for WoW 12.0+
    HistoryPanel - Past loot history browser
----------------------------------------------------------------------]]

local _, ns = ...
local Loolib = LibStub("Loolib")
local Loothing = ns.Addon
local Utils = ns.Utils
local Popups = ns.Popups

--[[--------------------------------------------------------------------
    HistoryPanelMixin
----------------------------------------------------------------------]]

local HistoryPanelMixin = ns.HistoryPanelMixin or Loolib.CreateFromMixins(Loolib.CallbackRegistryMixin)
ns.HistoryPanelMixin = HistoryPanelMixin

local HISTORY_PANEL_EVENTS = {}

-- Exports larger than this byte threshold are routed to a single-line EditBox
-- to avoid the MultiLineEditBox layout freeze for >40KB of text
local HUGE_EXPORT_THRESHOLD = 40000

--- Initialize the history panel
-- @param parent Frame - Parent frame
function HistoryPanelMixin:Init(parent)
    Loolib.CallbackRegistryMixin.OnLoad(self)
    self:GenerateCallbackEvents(HISTORY_PANEL_EVENTS)
    self.parent = parent
    self.historyRows = {}
    self.dateButtons = {}
    self.playerButtons = {}
    self.selectedDate = nil
    self.selectedPlayer = nil
    self.displayedCount = 0
    self.viewState = nil

    self:CreateFrame()
    self:CreateElements()

    if Loothing.History then
        Loothing.History:RegisterCallback("OnHistoryChanged", function()
            if self.frame and self.frame:IsShown() then
                self:Refresh()
            end
        end, self)
    end
end

--- Create the main frame
function HistoryPanelMixin:CreateFrame()
    local frame = CreateFrame("Frame", nil, self.parent)
    frame:SetAllPoints()

    self.frame = frame
end

--- Create UI elements
function HistoryPanelMixin:CreateElements()
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
function HistoryPanelMixin:CreateFilterBar()
    local L = Loothing.Locale

    local filterBar = CreateFrame("Frame", nil, self.frame)
    filterBar:SetPoint("TOPLEFT", 8, -8)
    filterBar:SetPoint("TOPRIGHT", -8, -8)
    filterBar:SetHeight(28)

    -- Nil-safe placeholder string (guards against missing locale key)
    local placeholder = L["SEARCH"]
    filterBar._placeholder = placeholder
    filterBar._placeholderActive = true

    -- Search box (placeholder via boolean flag, not string equality)
    local searchBox = CreateFrame("EditBox", nil, filterBar, "InputBoxTemplate")
    searchBox:SetSize(120, 20)
    searchBox:SetPoint("LEFT")
    searchBox:SetAutoFocus(false)
    searchBox:SetText(placeholder)
    searchBox:SetTextColor(0.5, 0.5, 0.5)
    searchBox:SetScript("OnEditFocusGained", function(editBox)
        local fb = editBox:GetParent()
        if fb._placeholderActive then
            fb._placeholderActive = false
            editBox:SetText("")
            editBox:SetTextColor(1, 1, 1)
        end
    end)
    searchBox:SetScript("OnEditFocusLost", function(editBox)
        if editBox:GetText() == "" then
            local fb = editBox:GetParent()
            fb._placeholderActive = true
            editBox:SetText(fb._placeholder)
            editBox:SetTextColor(0.5, 0.5, 0.5)
        end
    end)
    searchBox:SetScript("OnTextChanged", function(editBox)
        local fb = editBox:GetParent()
        if fb._placeholderActive then return end
        fb.mixin:OnSearchChanged(editBox:GetText())
    end)
    searchBox:SetScript("OnEscapePressed", function(editBox)
        editBox:ClearFocus()
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
function HistoryPanelMixin:ShowResponseFilterDropdown()
    MenuUtil.CreateContextMenu(self.responseFilterButton, function(_ownerRegion, rootDescription)
        rootDescription:CreateButton("All Responses", function()
            self:SetResponseFilter(nil)
        end)
        rootDescription:CreateDivider()

        for id, info in pairs(Loothing.ResponseInfo) do
            rootDescription:CreateButton(info.name, function()
                self:SetResponseFilter(id)
            end)
        end
    end)
end

--- Set response filter
function HistoryPanelMixin:SetResponseFilter(responseId)
    if not Loothing.History then return end
    local filter = Loothing.History.filter or {}
    filter.response = responseId

    if responseId then
        local info = Loothing.ResponseInfo[responseId]
        self.responseFilterButton:SetText(info and info.name or "?")
    else
        self.responseFilterButton:SetText("Response")
    end

    Loothing.History:SetFilter(filter)
    self:Refresh()
end

--- Show class filter dropdown
function HistoryPanelMixin:ShowClassFilterDropdown()
    local classes = { "WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST", "DEATHKNIGHT",
                      "SHAMAN", "MAGE", "WARLOCK", "MONK", "DRUID", "DEMONHUNTER", "EVOKER" }

    MenuUtil.CreateContextMenu(self.classFilterButton, function(_ownerRegion, rootDescription)
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
function HistoryPanelMixin:SetClassFilter(class)
    if not Loothing.History then return end
    local filter = Loothing.History.filter or {}
    filter.class = class

    self.classFilterButton:SetText(class or "Class")
    Loothing.History:SetFilter(filter)
    self:Refresh()
end

--- Create history list
function HistoryPanelMixin:CreateHistoryList()
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

    local L = Loothing.Locale

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

    scrollFrame:SetScript("OnSizeChanged", function(_sf, w, _h)
        content:SetWidth(w)
    end)

    self.listContainer = container
    self.listContent = content
    self.scrollFrame = scrollFrame

    -- Frame pool for history rows
    self.rowPool = CreateFramePool("Button", self.listContent, nil, function(_pool, row)
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
function HistoryPanelMixin:CreateFooter()
    local L = Loothing.Locale

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
function HistoryPanelMixin:CreateDateList()
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

    scroll:SetScript("OnSizeChanged", function(_sf, w)
        content:SetWidth(w)
    end)

    self.dateScroll = scroll
    self.dateContent = content
    -- "All Dates" button at top
    local allBtn = CreateFrame("Button", nil, content)
    allBtn:SetSize(72, 20)
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
function HistoryPanelMixin:CreatePlayerList()
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

    scroll:SetScript("OnSizeChanged", function(_sf, w)
        content:SetWidth(w)
    end)

    self.playerScroll = scroll
    self.playerContent = content
    -- "All Players" button at top
    local allBtn = CreateFrame("Button", nil, content)
    allBtn:SetSize(92, 20)
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
function HistoryPanelMixin:Refresh()
    self.viewState = self:BuildViewState()
    self:RefreshDateList()
    self:RefreshPlayerList()
    self:RefreshList()
    self:UpdateCount()
end

local function AcquireIndexedButton(buttons, parent)
    local index = #buttons + 1
    local button = buttons[index]
    if button then
        return button
    end

    button = CreateFrame("Button", nil, parent)
    button.text = button:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    button.text:SetAllPoints()
    button:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
    buttons[index] = button
    return button
end

function HistoryPanelMixin:BuildViewState()
    local state = {
        dates = {},
        players = {},
        allDateEntries = {},
        entriesByPlayer = {},
        visibleEntries = {},
    }

    if not Loothing.History then
        return state
    end

    local seenDates = {}
    local seenPlayers = {}

    for _, entry in Loothing.History:GetFilteredEntries():Enumerate() do
        local entryDate = entry.timestamp and date("%Y-%m-%d", entry.timestamp)
        if entryDate and not seenDates[entryDate] then
            seenDates[entryDate] = true
            state.dates[#state.dates + 1] = entryDate
        end

        if not self.selectedDate or entryDate == self.selectedDate then
            state.allDateEntries[#state.allDateEntries + 1] = entry

            if entry.winner and not seenPlayers[entry.winner] then
                seenPlayers[entry.winner] = true
                state.players[#state.players + 1] = {
                    name = entry.winner,
                    class = entry.class or entry.winnerClass,
                }
            end

            if entry.winner then
                local bucket = state.entriesByPlayer[entry.winner]
                if not bucket then
                    bucket = {}
                    state.entriesByPlayer[entry.winner] = bucket
                end
                bucket[#bucket + 1] = entry
            end
        end
    end

    table.sort(state.dates, function(a, b) return a > b end)
    table.sort(state.players, function(a, b) return a.name < b.name end)

    if self.selectedPlayer and not state.entriesByPlayer[self.selectedPlayer] then
        self.selectedPlayer = nil
    end

    if self.selectedPlayer then
        state.visibleEntries = state.entriesByPlayer[self.selectedPlayer] or {}
    else
        state.visibleEntries = state.allDateEntries
    end

    return state
end

--- Refresh the date list in the left pane
function HistoryPanelMixin:RefreshDateList()
    local state = self.viewState or self:BuildViewState()

    -- Update "All Dates" highlight
    if not self.selectedDate then
        self.allDatesBtn.text:SetText("|cffffd700All Dates|r")
    else
        self.allDatesBtn.text:SetText("All Dates")
    end

    local yOffset = -24  -- Below "All Dates" button
    local used = 0
    for _, d in ipairs(state.dates) do
        used = used + 1
        local btn = self.dateButtons[used] or AcquireIndexedButton(self.dateButtons, self.dateContent)
        btn:SetSize(72, 18)
        btn:SetPoint("TOPLEFT", self.dateContent, "TOPLEFT", 2, yOffset)

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

    for index = used + 1, #self.dateButtons do
        self.dateButtons[index]:Hide()
    end

    self.dateContent:SetHeight(math.abs(yOffset) + 4)
end

--- Refresh the player list in the center pane
function HistoryPanelMixin:RefreshPlayerList()
    local state = self.viewState or self:BuildViewState()

    -- Update "All Players" highlight
    if not self.selectedPlayer then
        self.allPlayersBtn.text:SetText("|cffffd700All Players|r")
    else
        self.allPlayersBtn.text:SetText("All Players")
    end

    local yOffset = -24  -- Below "All Players" button
    local used = 0
    for _, player in ipairs(state.players) do
        used = used + 1
        local btn = self.playerButtons[used] or AcquireIndexedButton(self.playerButtons, self.playerContent)
        btn:SetSize(92, 18)
        btn:SetPoint("TOPLEFT", self.playerContent, "TOPLEFT", 2, yOffset)

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

    for index = used + 1, #self.playerButtons do
        self.playerButtons[index]:Hide()
    end

    self.playerContent:SetHeight(math.abs(yOffset) + 4)
end

--- Refresh the history list
function HistoryPanelMixin:RefreshList()
    local state = self.viewState or self:BuildViewState()
    if not Loothing.History then
        self.emptyText:Show()
        self.displayedCount = 0
        return
    end

    if not state.visibleEntries or #state.visibleEntries == 0 then
        self.emptyText:Show()
        self.displayedCount = 0
        for _, row in ipairs(self.historyRows) do
            row:Hide()
        end
        return
    end

    local yOffset = 0
    local rowHeight = 36
    local spacing = 2

    for index, entry in ipairs(state.visibleEntries) do
        local row = self.historyRows[index]
        if not row then
            row = CreateFrame("Button", nil, self.listContent)
            self.historyRows[index] = row
        end
        self:SetupHistoryRow(row, entry, yOffset)
        yOffset = yOffset - rowHeight - spacing
    end

    for index = #state.visibleEntries + 1, #self.historyRows do
        self.historyRows[index]:Hide()
    end

    self.displayedCount = #state.visibleEntries

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
function HistoryPanelMixin:SetupHistoryRow(row, entry, yOffset)
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
        row.dateText:SetText(Utils.FormatDate(entry.timestamp))
    else
        row.dateText:SetText("")
    end
    row.dateText:SetTextColor(0.7, 0.7, 0.7)

    -- Icon
    local texture = entry.itemID and C_Item.GetItemIconByID(entry.itemID) or "Interface\\Icons\\INV_Misc_QuestionMark"
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
        row.winnerText:SetText(Utils.GetShortName(entry.winner))
    else
        row.winnerText:SetText("")
    end

    -- Response color bar
    if entry.winnerResponse and Loothing.ResponseInfo[entry.winnerResponse] then
        local info = Loothing.ResponseInfo[entry.winnerResponse]
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
            GameTooltip:AddLine(string.format(Loothing.Locale["AWARDED_TO"], entry.winner), 1, 0.82, 0)
        end

        if entry.encounterName then
            GameTooltip:AddLine(string.format(Loothing.Locale["FROM_ENCOUNTER"], entry.encounterName), 0.7, 0.7, 0.7)
        end

        if entry.votes then
            GameTooltip:AddLine(string.format(Loothing.Locale["WITH_VOTES"], entry.votes), 0.7, 0.7, 0.7)
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
function HistoryPanelMixin:ShowHistoryRowContextMenu(row, entry)
    local L = Loothing.Locale or {}

    MenuUtil.CreateContextMenu(row, function(_ownerRegion, rootDescription)
        rootDescription:CreateTitle(entry.itemName or "Unknown")

        -- Link in chat
        if entry.itemLink then
            rootDescription:CreateButton(L["LINK_IN_CHAT"], function()
                ChatEdit_InsertLink(entry.itemLink)
            end)
        end

        -- Filter by winner
        if entry.winner then
            rootDescription:CreateButton(
                string.format(L["FILTER_BY_WINNER"], Utils.GetShortName(entry.winner)),
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
                    filter.encounterName = entry.encounterName
                    Loothing.History:SetFilter(filter)
                    self:Refresh()
                end
            end)
        end

        rootDescription:CreateDivider()

        -- Delete entry
        rootDescription:CreateButton(L["DELETE_ENTRY"], function()
            if Loothing.History and entry.guid then
                Loothing.History:DeleteEntry(entry.guid)
                self:Refresh()
            end
        end)
    end)
end

--- Update count display
function HistoryPanelMixin:UpdateCount()
    if not Loothing.History then
        self.countText:SetText("")
        return
    end

    local total = Loothing.History:GetCount()
    local displayed = self.displayedCount or 0

    if total == displayed then
        self.countText:SetText(string.format(Loothing.Locale["ENTRIES_COUNT"], total))
    else
        self.countText:SetText(string.format(Loothing.Locale["ENTRIES_FILTERED"], displayed, total))
    end
end

--[[--------------------------------------------------------------------
    Filtering
----------------------------------------------------------------------]]

--- Handle search text change
-- @param text string
function HistoryPanelMixin:OnSearchChanged(text)
    if not Loothing.History then return end

    local filter = Loothing.History.filter or {}
    filter.searchText = text ~= "" and text or nil

    Loothing.History:SetFilter(filter)
    self:Refresh()
end

--- Show winner dropdown
function HistoryPanelMixin:ShowWinnerDropdown()
    if not Loothing.History then return end

    local L = Loothing.Locale
    local winners = Loothing.History:GetUniqueWinners()

    MenuUtil.CreateContextMenu(self.winnerButton, function(_ownerRegion, rootDescription)
        rootDescription:CreateButton(L["ALL_WINNERS"], function()
            self:SetWinnerFilter(nil)
        end)
        rootDescription:CreateDivider()

        for _, winner in ipairs(winners) do
            rootDescription:CreateButton(Utils.GetShortName(winner), function()
                self:SetWinnerFilter(winner)
            end)
        end
    end)
end

--- Set winner filter
-- @param winner string|nil
function HistoryPanelMixin:SetWinnerFilter(winner)
    if not Loothing.History then return end

    local L = Loothing.Locale
    local filter = Loothing.History.filter or {}
    filter.winner = winner

    Loothing.History:SetFilter(filter)

    if winner then
        self.winnerButton:SetText(Utils.GetShortName(winner))
    else
        self.winnerButton:SetText(L["ALL_WINNERS"])
    end

    self:Refresh()
end

--- Clear all filters
function HistoryPanelMixin:ClearFilters()
    if not Loothing.History then return end

    local L = Loothing.Locale

    -- Restore placeholder state on the search box
    self.filterBar._placeholderActive = true
    self.searchBox:SetText(self.filterBar._placeholder)
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

-- Lazy singleton: a narrow single-line frame for large exports.
-- MultiLineEditBox freezes WoW when rendering >40KB; single-line avoids the layout pass.
local function GetOrCreateHugeExportFrame()
    if HistoryPanelMixin._hugeExportFrame then
        return HistoryPanelMixin._hugeExportFrame
    end

    local frame = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    frame:SetSize(700, 80)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("DIALOG")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 },
    })

    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    title:SetPoint("TOP", 0, -8)
    title:SetText("Export (large - Ctrl+A, Ctrl+C to copy)")
    title:SetTextColor(1, 0.82, 0)

    local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -5, -5)
    close:SetScript("OnClick", function() frame:Hide() end)

    local editBox = CreateFrame("EditBox", nil, frame)
    editBox:SetMultiLine(false)
    editBox:SetAutoFocus(false)
    editBox:SetFontObject(GameFontHighlightSmall)
    editBox:SetMaxLetters(0)
    editBox:SetPoint("TOPLEFT", 16, -28)
    editBox:SetPoint("BOTTOMRIGHT", -36, 12)
    editBox:SetScript("OnEscapePressed", function() frame:Hide() end)

    -- Guard against user edits overwriting the export text
    local _locked = false
    editBox:SetScript("OnTextChanged", function(self, userInput)
        if userInput and not _locked then
            _locked = true
            self:SetText(self._exportText or "")
            self:HighlightText()
            _locked = false
        end
    end)

    frame.editBox = editBox
    HistoryPanelMixin._hugeExportFrame = frame
    return frame
end

--- Route export text to the appropriate EditBox based on size
-- Large (>=40KB): single-line frame to avoid MultiLineEditBox layout freeze
-- Normal: existing multiline scrollable EditBox
-- @param text string
function HistoryPanelMixin:SetExportText(text)
    if #text >= HUGE_EXPORT_THRESHOLD then
        if self.exportFrame then self.exportFrame:Hide() end
        local hugeFrame = GetOrCreateHugeExportFrame()
        hugeFrame.editBox._exportText = text
        hugeFrame:Show()
        hugeFrame.editBox:SetText(text)
        hugeFrame.editBox:SetFocus()
        hugeFrame.editBox:HighlightText()
    else
        if HistoryPanelMixin._hugeExportFrame then
            HistoryPanelMixin._hugeExportFrame:Hide()
        end
        self.exportEditBox:SetText(text)
        self.exportEditBox:SetFocus()
        self.exportEditBox:HighlightText()
    end
end

--- Show export dialog
function HistoryPanelMixin:ShowExportDialog()
    if not Loothing.History then return end

    local L = Loothing.Locale

    -- Create export frame if it doesn't exist
    if not self.exportFrame then
        local frame = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
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

        scrollFrame:SetScript("OnSizeChanged", function(_sf, w, _h)
            editBox:SetWidth(w)
        end)

        -- Format buttons
        local csvButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
        csvButton:SetSize(45, 22)
        csvButton:SetPoint("BOTTOMLEFT", 16, 16)
        csvButton:SetText("CSV")
        csvButton:SetScript("OnClick", function()
            self:SetExportText(Loothing.History:ExportCSV())
        end)

        local tsvButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
        tsvButton:SetSize(45, 22)
        tsvButton:SetPoint("LEFT", csvButton, "RIGHT", 4, 0)
        tsvButton:SetText("TSV")
        tsvButton:SetScript("OnClick", function()
            self:SetExportText(Loothing.History:ExportTSV())
        end)

        local luaButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
        luaButton:SetSize(45, 22)
        luaButton:SetPoint("LEFT", tsvButton, "RIGHT", 4, 0)
        luaButton:SetText("Lua")
        luaButton:SetScript("OnClick", function()
            self:SetExportText(Loothing.History:ExportLua())
        end)

        local bbcodeButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
        bbcodeButton:SetSize(70, 22)
        bbcodeButton:SetPoint("LEFT", luaButton, "RIGHT", 4, 0)
        bbcodeButton:SetText("BBCode")
        bbcodeButton:SetScript("OnClick", function()
            self:SetExportText(Loothing.History:ExportBBCode())
        end)

        local discordButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
        discordButton:SetSize(70, 22)
        discordButton:SetPoint("LEFT", bbcodeButton, "RIGHT", 4, 0)
        discordButton:SetText("Discord")
        discordButton:SetScript("OnClick", function()
            self:SetExportText(Loothing.History:ExportDiscord())
        end)

        local jsonButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
        jsonButton:SetSize(50, 22)
        jsonButton:SetPoint("LEFT", discordButton, "RIGHT", 4, 0)
        jsonButton:SetText("JSON")
        jsonButton:SetScript("OnClick", function()
            self:SetExportText(Loothing.History:ExportJSON())
        end)

        local eqdkpButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
        eqdkpButton:SetSize(60, 22)
        eqdkpButton:SetPoint("LEFT", jsonButton, "RIGHT", 4, 0)
        eqdkpButton:SetText(L["EXPORT_EQDKP"])
        eqdkpButton:SetScript("OnClick", function()
            self:SetExportText(Loothing.History:ExportEQdkp())
        end)

        local webButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
        webButton:SetSize(50, 22)
        webButton:SetPoint("LEFT", eqdkpButton, "RIGHT", 4, 0)
        webButton:SetText("Web")
        webButton:SetScript("OnClick", function()
            self:SetExportText(Loothing.History:ExportCompact())
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
    self.exportFrame:Show()
    self:SetExportText(Loothing.History:ExportCSV())
end

--- Open the export dialog pre-loaded with the Web (compact) export string
function HistoryPanelMixin:ShowWebExport()
    self:ShowExportDialog()
    self:SetExportText(Loothing.History:ExportCompact())
end

--- Confirm and clear history
function HistoryPanelMixin:ConfirmClearHistory()
    Popups:Show("LOOTHING_CONFIRM_DELETE_HISTORY", {
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

function HistoryPanelMixin:GetFrame()
    return self.frame
end

function HistoryPanelMixin:Show()
    self.frame:Show()
    self:Refresh()
end

function HistoryPanelMixin:Hide()
    self.frame:Hide()
end

--[[--------------------------------------------------------------------
    Factory
----------------------------------------------------------------------]]

local function CreateHistoryPanel(parent)
    local panel = Loolib.CreateFromMixins(HistoryPanelMixin)
    panel:Init(parent)
    return panel
end

ns.CreateHistoryPanel = CreateHistoryPanel
