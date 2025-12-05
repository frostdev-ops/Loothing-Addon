--[[--------------------------------------------------------------------
    Loothing - Loot Council Addon for WoW 12.0+
    HistoryPanel - Past loot history browser
----------------------------------------------------------------------]]

local Loolib = LibStub("Loolib")

--[[--------------------------------------------------------------------
    LoothingHistoryPanelMixin
----------------------------------------------------------------------]]

LoothingHistoryPanelMixin = {}

--- Initialize the history panel
-- @param parent Frame - Parent frame
function LoothingHistoryPanelMixin:Init(parent)
    self.parent = parent
    self.historyRows = {}

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

    -- Filter bar
    self:CreateFilterBar()

    -- History list
    self:CreateHistoryList()

    -- Footer with stats/export
    self:CreateFooter()
end

--- Create filter bar
function LoothingHistoryPanelMixin:CreateFilterBar()
    local L = LOOTHING_LOCALE

    local filterBar = CreateFrame("Frame", nil, self.frame)
    filterBar:SetPoint("TOPLEFT", 8, -8)
    filterBar:SetPoint("TOPRIGHT", -8, -8)
    filterBar:SetHeight(30)

    -- Search box
    local searchBox = CreateFrame("EditBox", nil, filterBar, "InputBoxTemplate")
    searchBox:SetSize(150, 20)
    searchBox:SetPoint("LEFT")
    searchBox:SetAutoFocus(false)
    searchBox:SetScript("OnTextChanged", function(self)
        local text = self:GetText()
        self:GetParent().mixin:OnSearchChanged(text)
    end)
    searchBox:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
    end)

    local searchLabel = filterBar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    searchLabel:SetPoint("BOTTOMLEFT", searchBox, "TOPLEFT", 0, 2)
    searchLabel:SetText(L["SEARCH"])
    searchLabel:SetTextColor(0.7, 0.7, 0.7)

    self.searchBox = searchBox

    -- Winner filter dropdown
    local winnerButton = CreateFrame("Button", nil, filterBar, "UIPanelButtonTemplate")
    winnerButton:SetSize(100, 20)
    winnerButton:SetPoint("LEFT", searchBox, "RIGHT", 16, 0)
    winnerButton:SetText(L["ALL_WINNERS"])
    winnerButton:SetScript("OnClick", function()
        self:ShowWinnerDropdown()
    end)

    local winnerLabel = filterBar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    winnerLabel:SetPoint("BOTTOMLEFT", winnerButton, "TOPLEFT", 0, 2)
    winnerLabel:SetText(L["WINNER"])
    winnerLabel:SetTextColor(0.7, 0.7, 0.7)

    self.winnerButton = winnerButton

    -- Clear filters button
    local clearButton = CreateFrame("Button", nil, filterBar, "UIPanelButtonTemplate")
    clearButton:SetSize(60, 20)
    clearButton:SetPoint("RIGHT")
    clearButton:SetText(L["CLEAR"])
    clearButton:SetScript("OnClick", function()
        self:ClearFilters()
    end)

    -- Entry count
    self.countText = filterBar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    self.countText:SetPoint("RIGHT", clearButton, "LEFT", -16, 0)
    self.countText:SetTextColor(0.7, 0.7, 0.7)

    filterBar.mixin = self
    self.filterBar = filterBar
end

--- Create history list
function LoothingHistoryPanelMixin:CreateHistoryList()
    local container = CreateFrame("Frame", nil, self.frame, "BackdropTemplate")
    container:SetPoint("TOPLEFT", 8, -46)
    container:SetPoint("BOTTOMRIGHT", -8, 50)
    container:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        tileSize = 8,
        edgeSize = 12,
        insets = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    container:SetBackdropColor(0.05, 0.05, 0.05, 0.9)

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
    content:SetSize(scrollFrame:GetWidth(), 800)
    scrollFrame:SetScrollChild(content)

    self.listContainer = container
    self.listContent = content
    self.scrollFrame = scrollFrame

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

--[[--------------------------------------------------------------------
    Display
----------------------------------------------------------------------]]

--- Refresh the history display
function LoothingHistoryPanelMixin:Refresh()
    self:RefreshList()
    self:UpdateCount()
end

--- Refresh the history list
function LoothingHistoryPanelMixin:RefreshList()
    -- Clear existing rows
    for _, row in ipairs(self.historyRows) do
        row:Hide()
    end
    wipe(self.historyRows)

    if not Loothing.History then
        self.emptyText:Show()
        return
    end

    local entries = Loothing.History:GetFilteredEntries()
    if not entries or entries:GetSize() == 0 then
        self.emptyText:Show()
        return
    end

    self.emptyText:Hide()

    local yOffset = 0
    local rowHeight = 36
    local spacing = 2

    for _, entry in entries:Enumerate() do
        local row = self:CreateHistoryRow(entry, yOffset)
        self.historyRows[#self.historyRows + 1] = row
        yOffset = yOffset - rowHeight - spacing
    end

    self.listContent:SetHeight(math.abs(yOffset) + 20)
end

--- Create a history row
-- @param entry table - History entry
-- @param yOffset number
-- @return Frame
function LoothingHistoryPanelMixin:CreateHistoryRow(entry, yOffset)
    local row = CreateFrame("Button", nil, self.listContent)
    row:SetPoint("TOPLEFT", 0, yOffset)
    row:SetPoint("TOPRIGHT", 0, yOffset)
    row:SetHeight(36)

    -- Background
    local bg = row:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0.1, 0.1, 0.1, 0.5)

    -- Highlight
    local highlight = row:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetAllPoints()
    highlight:SetColorTexture(1, 1, 1, 0.1)

    -- Date
    local dateText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    dateText:SetPoint("LEFT", 4, 0)
    dateText:SetWidth(76)
    dateText:SetJustifyH("LEFT")

    if entry.timestamp then
        dateText:SetText(LoothingUtils.FormatDate(entry.timestamp))
    else
        dateText:SetText("")
    end
    dateText:SetTextColor(0.7, 0.7, 0.7)

    -- Item icon
    local icon = row:CreateTexture(nil, "ARTWORK")
    icon:SetSize(28, 28)
    icon:SetPoint("LEFT", 84, 0)

    local texture = entry.itemID and GetItemIcon(entry.itemID) or "Interface\\Icons\\INV_Misc_QuestionMark"
    icon:SetTexture(texture)

    -- Quality border
    local quality = entry.quality or 1
    local r, g, b = C_Item.GetItemQualityColor(quality)

    local border = row:CreateTexture(nil, "OVERLAY")
    border:SetSize(30, 30)
    border:SetPoint("CENTER", icon, "CENTER")
    border:SetTexture("Interface\\Common\\WhiteIconFrame")
    border:SetVertexColor(r, g, b)

    -- Item name
    local nameText = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    nameText:SetPoint("LEFT", icon, "RIGHT", 8, 0)
    nameText:SetPoint("RIGHT", -150, 0)
    nameText:SetJustifyH("LEFT")
    nameText:SetWordWrap(false)
    nameText:SetText(entry.itemName or "Unknown Item")
    nameText:SetTextColor(r, g, b)

    -- Winner
    local winnerText = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    winnerText:SetPoint("RIGHT", -4, 0)
    winnerText:SetWidth(120)
    winnerText:SetJustifyH("RIGHT")

    if entry.winner then
        local shortName = LoothingUtils.GetShortName(entry.winner)
        winnerText:SetText(shortName)
    else
        winnerText:SetText("")
    end

    -- Response color bar
    if entry.winnerResponse and LOOTHING_RESPONSE_INFO[entry.winnerResponse] then
        local info = LOOTHING_RESPONSE_INFO[entry.winnerResponse]
        local colorBar = row:CreateTexture(nil, "ARTWORK")
        colorBar:SetSize(3, 32)
        colorBar:SetPoint("RIGHT", winnerText, "LEFT", -4, 0)
        colorBar:SetColorTexture(info.color.r, info.color.g, info.color.b, 1)
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

    -- Click to link
    row:SetScript("OnClick", function(_, button)
        if button == "LeftButton" and entry.itemLink then
            if IsShiftKeyDown() then
                ChatEdit_InsertLink(entry.itemLink)
            end
        end
    end)

    row:Show()
    return row
end

--- Update count display
function LoothingHistoryPanelMixin:UpdateCount()
    if not Loothing.History then
        self.countText:SetText("")
        return
    end

    local total = Loothing.History:GetCount()
    local filtered = Loothing.History:GetFilteredCount()

    if total == filtered then
        self.countText:SetText(string.format(LOOTHING_LOCALE["ENTRIES_COUNT"], total))
    else
        self.countText:SetText(string.format(LOOTHING_LOCALE["ENTRIES_FILTERED"], filtered, total))
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

    local menu = {
        { text = L["ALL_WINNERS"], notCheckable = true, func = function()
            self:SetWinnerFilter(nil)
        end },
        { text = "", notCheckable = true, disabled = true },
    }

    for _, winner in ipairs(winners) do
        table.insert(menu, {
            text = LoothingUtils.GetShortName(winner),
            notCheckable = true,
            func = function()
                self:SetWinnerFilter(winner)
            end
        })
    end

    if EasyMenu then
        EasyMenu(menu, CreateFrame("Frame", "LoothingWinnerMenu", UIParent, "UIDropDownMenuTemplate"), self.winnerButton, 0, 0, "MENU")
    end
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

    self.searchBox:SetText("")
    self.winnerButton:SetText(L["ALL_WINNERS"])

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
        frame:SetSize(500, 400)
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
        editBox:SetSize(scrollFrame:GetWidth(), 300)
        scrollFrame:SetScrollChild(editBox)

        -- Format buttons
        local csvButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
        csvButton:SetSize(50, 22)
        csvButton:SetPoint("BOTTOMLEFT", 16, 16)
        csvButton:SetText("CSV")
        csvButton:SetScript("OnClick", function()
            editBox:SetText(Loothing.History:ExportCSV())
            editBox:HighlightText()
        end)

        local luaButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
        luaButton:SetSize(50, 22)
        luaButton:SetPoint("LEFT", csvButton, "RIGHT", 4, 0)
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
    local L = LOOTHING_LOCALE

    StaticPopupDialogs["LOOTHING_CLEAR_HISTORY"] = {
        text = L["CONFIRM_CLEAR_HISTORY"],
        button1 = L["YES"],
        button2 = L["NO"],
        OnAccept = function()
            if Loothing.History then
                Loothing.History:ClearHistory()
                self:Refresh()
            end
        end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
    }

    StaticPopup_Show("LOOTHING_CLEAR_HISTORY")
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
