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
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        tile = false,
        edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    container:SetBackdropColor(0.05, 0.05, 0.05, 0.9)
    container:SetBackdropBorderColor(0.2, 0.2, 0.2, 1)

    -- Scroll frame for results
    local scrollFrame = CreateFrame("ScrollFrame", nil, container, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 8, -8)
    scrollFrame:SetPoint("BOTTOMRIGHT", -28, 8)

    local content = CreateFrame("Frame", nil, scrollFrame)
    content:SetSize(1, 400)
    scrollFrame:SetScrollChild(content)

    scrollFrame:SetScript("OnSizeChanged", function(sf, w, h)
        content:SetWidth(w)
    end)

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
    for _, data in ipairs(sortedResponses) do
        local isWinner = self.results and self.results.winningResponse == data.response and not self.results.isTie
        local row = LoothingUI_CreateResponseRow(self.resultsContent, data, yOffset, self.results and self.results.totalVotes, isWinner)
        self.responseRows[#self.responseRows + 1] = row
        yOffset = yOffset - rowHeight - padding
    end

    -- Update content height
    self.resultsContent:SetHeight(math.abs(yOffset) + padding)
end

--[[--------------------------------------------------------------------
    Action Handling
----------------------------------------------------------------------]]

--- Update action buttons based on user permissions
-- Only ML can award, re-vote, or skip. Observers and non-council see no actions.
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

    -- If award reasons are enabled, show the award reason dropdown
    if Loothing.Settings and Loothing.Settings:GetAwardReasonsEnabled() then
        self:ShowAwardReasonDropdown()
    else
        -- Original behavior - no award reasons
        local winnerResponse = self.results.winningResponse
        local isTie = self.results.isTie

        if isTie then
            -- Show tie resolution dialog
            self:ShowTieDialog()
        else
            -- Show award confirmation
            self:ShowAwardDialog(winnerResponse, nil, nil)
        end
    end
end

--- Show tie resolution dialog
-- Presents tied candidates in a context menu for the ML to break the tie
function LoothingResultsPanelMixin:ShowTieDialog()
    if not self.results or not self.results.tiedCandidates then
        self:TriggerEvent("OnAwardClicked", self.item, nil, true)
        return
    end

    local tiedCandidates = self.results.tiedCandidates
    if #tiedCandidates < 2 then
        self:TriggerEvent("OnAwardClicked", self.item, nil, true)
        return
    end

    local itemGUID = self.item and self.item.guid
    local reasonId = self.selectedAwardReasonId
    local reasonName = self.selectedAwardReasonName

    MenuUtil.CreateContextMenu(self.awardButton, function(ownerRegion, rootDescription)
        rootDescription:CreateTitle("Tie Breaker - Select Winner")
        for _, candidate in ipairs(tiedCandidates) do
            local name = candidate.name or "Unknown"
            local votes = candidate.councilVotes or 0
            rootDescription:CreateButton(string.format("%s (%d votes)", name, votes), function()
                if Loothing.Session and itemGUID then
                    Loothing.Session:AwardItem(itemGUID, candidate.name, nil, reasonId)
                end
                self.selectedAwardReasonId = nil
                self.selectedAwardReasonName = nil
                self:Hide()
            end)
        end
        rootDescription:CreateDivider()
        rootDescription:CreateButton("Roll Off", function()
            self:TriggerEvent("OnRevoteClicked", self.item)
            self.selectedAwardReasonId = nil
            self.selectedAwardReasonName = nil
        end)
    end)
end

--- Show award confirmation dialog
-- @param winnerResponse number - The winning response type
-- @param awardReasonId number|nil - Award reason ID
-- @param awardReasonName string|nil - Award reason name
function LoothingResultsPanelMixin:ShowAwardDialog(winnerResponse, awardReasonId, awardReasonName)
    if not self.item or not self.results then return end

    -- Find the top candidate for the winning response
    local winner = nil
    if self.results.counts and self.results.counts[winnerResponse] then
        local voters = self.results.counts[winnerResponse].voters
        if voters and #voters > 0 then
            winner = voters[1]
        end
    end

    -- Fallback: use most voted candidate from the candidate manager
    if not winner and self.item.candidateManager then
        local mostVoted = self.item.candidateManager:GetMostVoted()
        if mostVoted then
            winner = mostVoted
        end
    end

    if not winner then
        self:TriggerEvent("OnAwardClicked", self.item, winnerResponse, false, awardReasonId, awardReasonName)
        self:Hide()
        return
    end

    local itemGUID = self.item.guid
    local itemLink = self.item.itemLink or self.item.name or "Unknown Item"
    local playerName = winner.name or "Unknown"

    LoothingPopups:Show("LOOTHING_CONFIRM_AWARD", {
        item = itemLink,
        player = playerName,
        reason = awardReasonName,
    }, function()
        if Loothing.Session and itemGUID then
            Loothing.Session:AwardItem(itemGUID, playerName, nil, awardReasonId)
        end
        self:Hide()
    end)
end

--- Show award reason dropdown
-- Presents award reasons in a context menu, then routes to tie or award dialog
function LoothingResultsPanelMixin:ShowAwardReasonDropdown()
    local L = LOOTHING_LOCALE

    if not Loothing.Settings then
        return
    end

    local reasons = Loothing.Settings:GetAwardReasons()
    local winnerResponse = self.results and self.results.winningResponse
    local isTie = self.results and self.results.isTie

    MenuUtil.CreateContextMenu(self.awardButton, function(ownerRegion, rootDescription)
        rootDescription:CreateTitle("Select Award Reason")

        -- Add "No Reason" option if not required
        if not Loothing.Settings:GetRequireAwardReason() then
            rootDescription:CreateButton("Award (No Reason)", function()
                if isTie then
                    self.selectedAwardReasonId = nil
                    self.selectedAwardReasonName = nil
                    self:ShowTieDialog()
                else
                    self:ShowAwardDialog(winnerResponse, nil, nil)
                end
            end)
            rootDescription:CreateDivider()
        end

        -- Add each award reason
        for _, reason in ipairs(reasons) do
            local r, g, b = 1, 1, 1
            if reason.color then
                r, g, b = reason.color[1] or 1, reason.color[2] or 1, reason.color[3] or 1
            end
            local coloredName = string.format("|cff%02x%02x%02x%s|r", r * 255, g * 255, b * 255, reason.name)
            rootDescription:CreateButton(coloredName, function()
                if isTie then
                    self.selectedAwardReasonId = reason.id
                    self.selectedAwardReasonName = reason.name
                    self:ShowTieDialog()
                else
                    self:ShowAwardDialog(winnerResponse, reason.id, reason.name)
                end
            end)
        end
    end)
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
