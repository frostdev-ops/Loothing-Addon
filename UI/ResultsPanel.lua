--[[--------------------------------------------------------------------
    Loothing - Loot Council Addon for WoW 12.0+
    ResultsPanel - Vote results display
----------------------------------------------------------------------]]

local Loolib = LibStub("Loolib")

--[[--------------------------------------------------------------------
    LoothingResultsPanelMixin
----------------------------------------------------------------------]]

LoothingResultsPanelMixin = LoolibCreateFromMixins(LoolibCallbackRegistryMixin)

local RESULTS_EVENTS = {
    "OnAwardClicked",
    "OnRevoteClicked",
    "OnSkipClicked",
}

local PANEL_WIDTH = 400
local PANEL_HEIGHT = 450

--- Initialize the results panel
function LoothingResultsPanelMixin:Init()
    LoolibCallbackRegistryMixin.OnLoad(self)
    self:GenerateCallbackEvents(RESULTS_EVENTS)

    self.item = nil
    self.results = nil

    self:CreateFrame()
    self:CreateElements()
end

--- Create the main frame
function LoothingResultsPanelMixin:CreateFrame()
    local frame = CreateFrame("Frame", "LoothingResultsPanel", UIParent, "BackdropTemplate")
    frame:SetSize(PANEL_WIDTH, PANEL_HEIGHT)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("DIALOG")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:SetClampedToScreen(true)
    frame:Hide()

    frame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true,
        tileSize = 32,
        edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 },
    })

    -- Title bar
    local titleBar = CreateFrame("Frame", nil, frame)
    titleBar:SetPoint("TOPLEFT", 12, -12)
    titleBar:SetPoint("TOPRIGHT", -12, -12)
    titleBar:SetHeight(24)
    titleBar:EnableMouse(true)
    titleBar:RegisterForDrag("LeftButton")
    titleBar:SetScript("OnDragStart", function()
        frame:StartMoving()
    end)
    titleBar:SetScript("OnDragStop", function()
        frame:StopMovingOrSizing()
    end)

    self.frame = frame
end

--- Create UI elements
function LoothingResultsPanelMixin:CreateElements()
    local L = LOOTHING_LOCALE

    -- Title
    self.title = self.frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    self.title:SetPoint("TOP", 0, -20)
    self.title:SetText(L["RESULTS_TITLE"])

    -- Close button
    self.closeButton = CreateFrame("Button", nil, self.frame, "UIPanelCloseButton")
    self.closeButton:SetPoint("TOPRIGHT", -5, -5)
    self.closeButton:SetScript("OnClick", function()
        self:Hide()
    end)

    -- Item display
    self:CreateItemDisplay()

    -- Results area
    self:CreateResultsArea()

    -- Action buttons (ML only)
    self:CreateActionButtons()
end

--- Create item display
function LoothingResultsPanelMixin:CreateItemDisplay()
    local container = CreateFrame("Frame", nil, self.frame)
    container:SetPoint("TOPLEFT", 20, -50)
    container:SetPoint("TOPRIGHT", -20, -50)
    container:SetHeight(50)

    -- Item icon
    self.itemIcon = container:CreateTexture(nil, "ARTWORK")
    self.itemIcon:SetSize(44, 44)
    self.itemIcon:SetPoint("LEFT")

    -- Icon border
    self.itemIconBorder = container:CreateTexture(nil, "OVERLAY")
    self.itemIconBorder:SetSize(46, 46)
    self.itemIconBorder:SetPoint("CENTER", self.itemIcon, "CENTER")
    self.itemIconBorder:SetTexture("Interface\\Common\\WhiteIconFrame")

    -- Item name
    self.itemName = container:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    self.itemName:SetPoint("TOPLEFT", self.itemIcon, "TOPRIGHT", 8, -2)
    self.itemName:SetPoint("RIGHT", -8, 0)
    self.itemName:SetJustifyH("LEFT")

    -- Item level
    self.itemLevel = container:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    self.itemLevel:SetPoint("BOTTOMLEFT", self.itemIcon, "BOTTOMRIGHT", 8, 2)
    self.itemLevel:SetTextColor(1, 0.82, 0)

    -- Vote count summary
    self.voteSummary = container:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    self.voteSummary:SetPoint("LEFT", self.itemLevel, "RIGHT", 16, 0)
    self.voteSummary:SetTextColor(0.7, 0.7, 0.7)
end

--- Create results display area
function LoothingResultsPanelMixin:CreateResultsArea()
    local L = LOOTHING_LOCALE

    local container = CreateFrame("Frame", nil, self.frame, "BackdropTemplate")
    container:SetPoint("TOPLEFT", 20, -110)
    container:SetPoint("BOTTOMRIGHT", -20, 60)
    container:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        tileSize = 8,
        edgeSize = 12,
        insets = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    container:SetBackdropColor(0.05, 0.05, 0.05, 0.9)

    -- Scroll frame for results
    local scrollFrame = CreateFrame("ScrollFrame", nil, container, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 8, -8)
    scrollFrame:SetPoint("BOTTOMRIGHT", -28, 8)

    local content = CreateFrame("Frame", nil, scrollFrame)
    content:SetSize(scrollFrame:GetWidth(), 400)
    scrollFrame:SetScrollChild(content)

    self.resultsContainer = container
    self.resultsContent = content
    self.responseRows = {}
end

--- Create action buttons
function LoothingResultsPanelMixin:CreateActionButtons()
    local L = LOOTHING_LOCALE

    -- Award button
    self.awardButton = CreateFrame("Button", nil, self.frame, "UIPanelButtonTemplate")
    self.awardButton:SetSize(90, 26)
    self.awardButton:SetPoint("BOTTOMRIGHT", -20, 20)
    self.awardButton:SetText(L["AWARD"])
    self.awardButton:SetScript("OnClick", function()
        self:OnAwardClick()
    end)

    -- Re-vote button
    self.revoteButton = CreateFrame("Button", nil, self.frame, "UIPanelButtonTemplate")
    self.revoteButton:SetSize(90, 26)
    self.revoteButton:SetPoint("RIGHT", self.awardButton, "LEFT", -8, 0)
    self.revoteButton:SetText(L["RE_VOTE"])
    self.revoteButton:SetScript("OnClick", function()
        self:TriggerEvent("OnRevoteClicked", self.item)
    end)

    -- Skip button
    self.skipButton = CreateFrame("Button", nil, self.frame, "UIPanelButtonTemplate")
    self.skipButton:SetSize(90, 26)
    self.skipButton:SetPoint("RIGHT", self.revoteButton, "LEFT", -8, 0)
    self.skipButton:SetText(L["SKIP_ITEM"])
    self.skipButton:SetScript("OnClick", function()
        self:TriggerEvent("OnSkipClicked", self.item)
        self:Hide()
    end)
end

--[[--------------------------------------------------------------------
    Data Display
----------------------------------------------------------------------]]

--- Set item and results to display
-- @param item table - LoothingItem
-- @param results table - Tally results (optional)
function LoothingResultsPanelMixin:SetItem(item, results)
    self.item = item
    self.results = results

    if not item then
        self:Hide()
        return
    end

    -- Update item display
    local texture = item.texture or GetItemIcon(item.itemID or 0)
    self.itemIcon:SetTexture(texture or "Interface\\Icons\\INV_Misc_QuestionMark")

    local quality = item.quality or 1
    local r, g, b = C_Item.GetItemQualityColor(quality)
    self.itemIconBorder:SetVertexColor(r, g, b)
    self.itemName:SetTextColor(r, g, b)
    self.itemName:SetText(item.name or item.itemLink or "Unknown Item")

    if item.itemLevel and item.itemLevel > 0 then
        self.itemLevel:SetText(string.format("ilvl %d", item.itemLevel))
    else
        self.itemLevel:SetText("")
    end

    -- Vote summary
    local voteCount = item:GetVoteCount()
    self.voteSummary:SetText(string.format(LOOTHING_LOCALE["TOTAL_VOTES"], voteCount))

    -- Display results
    if not results then
        -- Generate results if not provided
        local votes = item:GetVotes()
        results = LoothingVotingEngine:TallySimple(votes)
        self.results = results
    end

    self:DisplayResults(results)

    -- Update button visibility
    self:UpdateActionButtons()

    self:Show()
end

--- Display vote results
-- @param results table
function LoothingResultsPanelMixin:DisplayResults(results)
    -- Clear existing rows
    for _, row in ipairs(self.responseRows) do
        row:Hide()
    end
    wipe(self.responseRows)

    if not results or not results.counts then
        return
    end

    local yOffset = 0
    local rowHeight = 60
    local padding = 8

    -- Sort responses by vote count
    local sortedResponses = {}
    for response, data in pairs(results.counts) do
        if LOOTHING_RESPONSE_INFO[response] then
            sortedResponses[#sortedResponses + 1] = {
                response = response,
                count = data.count,
                voters = data.voters,
                info = LOOTHING_RESPONSE_INFO[response],
            }
        end
    end

    table.sort(sortedResponses, function(a, b)
        if a.count ~= b.count then
            return a.count > b.count
        end
        return a.response < b.response
    end)

    -- Create rows
    for i, data in ipairs(sortedResponses) do
        local row = self:CreateResponseRow(data, yOffset)
        self.responseRows[#self.responseRows + 1] = row
        yOffset = yOffset - rowHeight - padding
    end

    -- Update content height
    self.resultsContent:SetHeight(math.abs(yOffset) + padding)
end

--- Create a response row
-- @param data table - { response, count, voters, info }
-- @param yOffset number
-- @return Frame
function LoothingResultsPanelMixin:CreateResponseRow(data, yOffset)
    local row = CreateFrame("Frame", nil, self.resultsContent, "BackdropTemplate")
    row:SetPoint("TOPLEFT", 0, yOffset)
    row:SetPoint("TOPRIGHT", 0, yOffset)
    row:SetHeight(60)

    row:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        tile = false,
        tileSize = 0,
        edgeSize = 1,
        insets = { left = 0, right = 0, top = 0, bottom = 0 },
    })
    row:SetBackdropColor(data.info.color.r * 0.2, data.info.color.g * 0.2, data.info.color.b * 0.2, 0.8)
    row:SetBackdropBorderColor(data.info.color.r * 0.5, data.info.color.g * 0.5, data.info.color.b * 0.5, 1)

    -- Color bar
    local colorBar = row:CreateTexture(nil, "ARTWORK")
    colorBar:SetSize(4, 58)
    colorBar:SetPoint("LEFT", 1, 0)
    colorBar:SetColorTexture(data.info.color.r, data.info.color.g, data.info.color.b, 1)

    -- Response name
    local nameText = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    nameText:SetPoint("TOPLEFT", colorBar, "TOPRIGHT", 8, -4)
    nameText:SetText(data.info.name)
    nameText:SetTextColor(data.info.color.r, data.info.color.g, data.info.color.b)

    -- Vote count
    local countText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    countText:SetPoint("TOPRIGHT", -8, -4)
    countText:SetText(tostring(data.count))
    countText:SetTextColor(1, 1, 1)

    -- Percentage bar
    local total = self.results.totalVotes or 1
    local percentage = total > 0 and (data.count / total) or 0

    local barBg = row:CreateTexture(nil, "BACKGROUND")
    barBg:SetPoint("TOPLEFT", nameText, "BOTTOMLEFT", 0, -4)
    barBg:SetSize(200, 12)
    barBg:SetColorTexture(0.1, 0.1, 0.1, 0.8)

    local bar = row:CreateTexture(nil, "ARTWORK")
    bar:SetPoint("TOPLEFT", barBg, "TOPLEFT", 1, -1)
    bar:SetSize(math.max(1, (200 - 2) * percentage), 10)
    bar:SetColorTexture(data.info.color.r, data.info.color.g, data.info.color.b, 0.8)

    local percentText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    percentText:SetPoint("LEFT", barBg, "RIGHT", 4, 0)
    percentText:SetText(string.format("%.0f%%", percentage * 100))
    percentText:SetTextColor(0.7, 0.7, 0.7)

    -- Voters list
    local votersText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    votersText:SetPoint("BOTTOMLEFT", colorBar, "BOTTOMRIGHT", 8, 4)
    votersText:SetPoint("BOTTOMRIGHT", -8, 4)
    votersText:SetJustifyH("LEFT")
    votersText:SetWordWrap(false)

    if data.voters and #data.voters > 0 then
        local voterNames = {}
        for _, voter in ipairs(data.voters) do
            local shortName = LoothingUtils.GetShortName(voter)
            -- Try to color by class
            if IsInRaid() then
                local roster = LoothingUtils.GetRaidRoster()
                for _, entry in ipairs(roster) do
                    if LoothingUtils.IsSamePlayer(voter, entry.name) then
                        shortName = LoothingUtils.ColorByClass(shortName, entry.classFile)
                        break
                    end
                end
            end
            voterNames[#voterNames + 1] = shortName
        end
        votersText:SetText(table.concat(voterNames, ", "))
    else
        votersText:SetText("")
    end

    -- Highlight for winner
    if self.results.winningResponse == data.response and not self.results.isTie then
        local glow = row:CreateTexture(nil, "OVERLAY")
        glow:SetAllPoints()
        glow:SetColorTexture(1, 0.82, 0, 0.1)

        local winnerText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        winnerText:SetPoint("RIGHT", countText, "LEFT", -8, 0)
        winnerText:SetText(LOOTHING_LOCALE["WINNER"])
        winnerText:SetTextColor(1, 0.82, 0)
    end

    return row
end

--[[--------------------------------------------------------------------
    Action Handling
----------------------------------------------------------------------]]

--- Update action buttons based on user permissions
function LoothingResultsPanelMixin:UpdateActionButtons()
    local isML = LoothingUtils.IsRaidLeaderOrAssistant()

    if isML then
        self.awardButton:Show()
        self.revoteButton:Show()
        self.skipButton:Show()
    else
        self.awardButton:Hide()
        self.revoteButton:Hide()
        self.skipButton:Hide()
    end
end

--- Handle award button click
function LoothingResultsPanelMixin:OnAwardClick()
    if not self.item or not self.results then
        return
    end

    -- If there's a clear winner, pre-select them
    local winnerResponse = self.results.winningResponse
    local isTie = self.results.isTie

    if isTie then
        -- Show tie resolution dialog
        self:ShowTieDialog()
    else
        -- Show award confirmation
        self:ShowAwardDialog(winnerResponse)
    end
end

--- Show tie resolution dialog
function LoothingResultsPanelMixin:ShowTieDialog()
    local L = LOOTHING_LOCALE

    -- For now, just trigger the event and let the caller handle it
    -- A full implementation would show a dropdown to pick a winner
    self:TriggerEvent("OnAwardClicked", self.item, nil, true)
end

--- Show award confirmation dialog
-- @param winnerResponse number
function LoothingResultsPanelMixin:ShowAwardDialog(winnerResponse)
    local L = LOOTHING_LOCALE

    local responseInfo = LOOTHING_RESPONSE_INFO[winnerResponse]
    local responseName = responseInfo and responseInfo.name or "Unknown"

    -- For now, trigger the event
    -- A full implementation would show a confirmation dialog
    self:TriggerEvent("OnAwardClicked", self.item, winnerResponse, false)
    self:Hide()
end

--[[--------------------------------------------------------------------
    Visibility
----------------------------------------------------------------------]]

function LoothingResultsPanelMixin:Show()
    self.frame:Show()
end

function LoothingResultsPanelMixin:Hide()
    self.frame:Hide()
end

function LoothingResultsPanelMixin:Toggle()
    if self.frame:IsShown() then
        self:Hide()
    else
        self:Show()
    end
end

function LoothingResultsPanelMixin:IsShown()
    return self.frame:IsShown()
end

--[[--------------------------------------------------------------------
    Factory
----------------------------------------------------------------------]]

function CreateLoothingResultsPanel()
    local panel = LoolibCreateFromMixins(LoothingResultsPanelMixin)
    panel:Init()
    return panel
end
