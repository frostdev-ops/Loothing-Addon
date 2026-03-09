--[[--------------------------------------------------------------------
    Loothing - Loot Council Addon for WoW 12.0+
    ResultsPanel - Vote results display (candidate-centric)
----------------------------------------------------------------------]]

local Loolib = LibStub("Loolib")

--[[--------------------------------------------------------------------
    LoothingResultsPanelMixin
----------------------------------------------------------------------]]

LoothingResultsPanelMixin = Loolib.CreateFromMixins(Loolib.CallbackRegistryMixin)

local RESULTS_EVENTS = {
    "OnAwardClicked",
    "OnRevoteClicked",
    "OnSkipClicked",
}

local PANEL_WIDTH = 400
local PANEL_HEIGHT = 450

--- Initialize the results panel
function LoothingResultsPanelMixin:Init()
    Loolib.CallbackRegistryMixin.OnLoad(self)
    self:GenerateCallbackEvents(RESULTS_EVENTS)

    self.item = nil
    self.results = nil
    self.selectedCandidate = nil
    self.selectedRow = nil

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
    local L = Loothing.Locale

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

    -- Winner header text
    self.winnerText = content:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    self.winnerText:SetPoint("TOPLEFT", 0, 0)
    self.winnerText:SetPoint("TOPRIGHT", 0, 0)
    self.winnerText:SetJustifyH("LEFT")

    -- Response summary text (compact line below winner)
    self.responseSummaryText = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    self.responseSummaryText:SetPoint("TOPLEFT", self.winnerText, "BOTTOMLEFT", 0, -4)
    self.responseSummaryText:SetJustifyH("LEFT")
    self.responseSummaryText:SetTextColor(0.7, 0.7, 0.7)

    self.resultsContainer = container
    self.resultsContent = content
    self.responseRows = {}
end

--- Create action buttons
function LoothingResultsPanelMixin:CreateActionButtons()
    local L = Loothing.Locale

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
-- @param results table - Tally results (optional, kept for backward compat)
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

    -- Vote summary from candidateManager
    local isML = Loothing.Session and Loothing.Session:IsMasterLooter()
    local hideVotes = Loothing.Settings and Loothing.Settings:GetHideVotes() and not isML
    if hideVotes then
        self.voteSummary:SetText("")
    else
        local cm = item.candidateManager
        if cm then
            local totalVotes = cm:GetTotalVotes()
            self.voteSummary:SetText(string.format(Loothing.Locale["TOTAL_VOTES"], totalVotes))
        else
            local voteCount = item:GetVoteCount()
            self.voteSummary:SetText(string.format(Loothing.Locale["TOTAL_VOTES"], voteCount))
        end
    end

    -- Display candidate-centric results
    self:DisplayResults(results)

    -- Update button visibility
    self:UpdateActionButtons()

    self:Show()
end

--- Display vote results (candidate-centric)
-- @param results table - Legacy results (ignored; data comes from candidateManager)
function LoothingResultsPanelMixin:DisplayResults(results)
    -- Clear existing rows
    for _, row in ipairs(self.responseRows) do
        row:Hide()
    end
    wipe(self.responseRows)

    local cm = self.item and self.item.candidateManager
    if not cm or cm:GetCandidateCount() == 0 then
        self.winnerText:SetText("")
        self.responseSummaryText:SetText("")
        return
    end

    local totalVotes = cm:GetTotalVotes()
    local winner = cm:GetMostVoted()

    -- Sort candidates: by votes if any votes cast, else by response priority
    local candidates
    if totalVotes > 0 then
        candidates = cm:GetCandidatesSortedBy("votes", false)
    else
        candidates = cm:GetAllCandidates()
        table.sort(candidates, LoothingCandidateSorting.ByResponsePriority)
    end

    -- Update winner header
    self:UpdateWinnerSection(winner, totalVotes, candidates)

    -- Update response summary
    local summaryOffset = self:UpdateResponseSummary(cm)

    -- Create candidate rows (start below header + summary)
    local yOffset = summaryOffset - 8
    local rowHeight = 60
    local padding = 8

    -- Reset selection state
    self.selectedCandidate = nil
    self.selectedRow = nil

    local clickCallback = function(candidate, rowFrame)
        self:SelectCandidate(candidate, rowFrame)
    end

    local autoSelectCandidate = winner or candidates[1]
    local autoSelectRow = nil

    for _, candidate in ipairs(candidates) do
        local isWinner = (winner and candidate == winner and totalVotes > 0)
        local row = LoothingUI_CreateCandidateResultRow(
            self.resultsContent, candidate, yOffset, totalVotes, isWinner, clickCallback
        )
        row.candidate = candidate
        self.responseRows[#self.responseRows + 1] = row
        yOffset = yOffset - rowHeight - padding

        if candidate == autoSelectCandidate then
            autoSelectRow = row
        end
    end

    -- Auto-select the winner (or first candidate)
    if autoSelectCandidate and autoSelectRow then
        self:SelectCandidate(autoSelectCandidate, autoSelectRow)
    end

    -- Update content height
    self.resultsContent:SetHeight(math.abs(yOffset) + padding)
end

--- Select a candidate as the award recipient
-- @param candidate table - LoothingCandidateMixin
-- @param rowFrame Frame - The row frame to highlight
function LoothingResultsPanelMixin:SelectCandidate(candidate, rowFrame)
    if self.selectedRow and self.selectedRow.SetSelected then
        self.selectedRow:SetSelected(false)
    end
    self.selectedCandidate = candidate
    self.selectedRow = rowFrame
    if rowFrame and rowFrame.SetSelected then
        rowFrame:SetSelected(true)
    end
    self:UpdateAwardButtonText()
end

--- Update award button text to reflect the selected candidate
function LoothingResultsPanelMixin:UpdateAwardButtonText()
    if self.selectedCandidate then
        local name
        if self.selectedCandidate.GetShortName then
            name = self.selectedCandidate:GetShortName()
        else
            name = self.selectedCandidate.playerName or "Unknown"
        end
        local text = "Award to " .. name
        self.awardButton:SetText(text)
        local fs = self.awardButton:GetFontString()
        self.awardButton:SetWidth(math.max(90, fs:GetStringWidth() + 24))
    else
        self.awardButton:SetText(Loothing.Locale["AWARD"])
        self.awardButton:SetWidth(90)
    end
end

--- Update the winner/recommendation section at top of results
-- @param winner table|nil - Winning candidate
-- @param totalVotes number - Total council votes
-- @param candidates table - All candidates sorted
function LoothingResultsPanelMixin:UpdateWinnerSection(winner, totalVotes, candidates)
    if totalVotes == 0 then
        self.winnerText:SetText("|cff888888No council votes cast|r")
        return
    end

    local isML = Loothing.Session and Loothing.Session:IsMasterLooter()
    local hideVotes = Loothing.Settings and Loothing.Settings:GetHideVotes() and not isML

    -- Detect ties
    local maxVotes = winner and winner.councilVotes or 0
    local tied = {}
    for _, c in ipairs(candidates) do
        if c.councilVotes == maxVotes and maxVotes > 0 then
            tied[#tied + 1] = c
        end
    end

    if #tied > 1 then
        -- Tie
        local names = {}
        for _, c in ipairs(tied) do
            names[#names + 1] = c:GetColoredName()
        end
        self.winnerText:SetText("|cffffcc00Tie:|r " .. table.concat(names, ", "))
    elseif winner then
        local coloredName = winner:GetColoredName()
        if hideVotes then
            self.winnerText:SetText("Recommended: " .. coloredName)
        else
            self.winnerText:SetText(string.format("Recommended: %s (%d votes)", coloredName, maxVotes))
        end
    end
end

--- Update compact response summary line
-- @param cm table - CandidateManager
-- @return number - yOffset after the summary
function LoothingResultsPanelMixin:UpdateResponseSummary(cm)
    local counts = cm:GetResponseCounts()
    local parts = {}

    for _, response in ipairs(Loothing.ResponsePriority) do
        local count = counts[response]
        if count and count > 0 then
            local info = Loothing.ResponseInfo[response]
            if info then
                local rawColor = info.color
                local cr, cg, cb
                if rawColor.r then
                    cr, cg, cb = rawColor.r, rawColor.g, rawColor.b
                else
                    cr, cg, cb = rawColor[1] or 0.5, rawColor[2] or 0.5, rawColor[3] or 0.5
                end
                local hex = string.format("%02x%02x%02x", cr * 255, cg * 255, cb * 255)
                parts[#parts + 1] = string.format("|cff%s%s: %d|r", hex, info.name, count)
            end
        end
    end

    if #parts > 0 then
        self.responseSummaryText:SetText(table.concat(parts, "  |  "))
    else
        self.responseSummaryText:SetText("")
    end

    -- Return yOffset for the first candidate row (after winnerText + summary)
    -- winnerText is at y=0, summary is below it; estimate total header height
    return -40
end

--[[--------------------------------------------------------------------
    Action Handling
----------------------------------------------------------------------]]

--- Update action buttons based on user permissions
-- Only ML can award, re-vote, or skip. Observers and non-council see no actions.
function LoothingResultsPanelMixin:UpdateActionButtons()
    local isML = Loothing.Session and Loothing.Session:IsMasterLooter() or false

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
    if not self.item or not self.selectedCandidate then return end

    if Loothing.Settings and Loothing.Settings:GetAwardReasonsEnabled() then
        self:ShowAwardReasonDropdown()
    else
        self:ShowAwardDialog(nil, nil, nil)
    end
end


--- Show award confirmation dialog
-- @param winnerResponse number|nil - Unused, kept for backward compat
-- @param awardReasonId number|nil - Award reason ID
-- @param awardReasonName string|nil - Award reason name
function LoothingResultsPanelMixin:ShowAwardDialog(winnerResponse, awardReasonId, awardReasonName)
    if not self.item or not self.selectedCandidate then return end

    local candidate = self.selectedCandidate
    local itemGUID = self.item.guid
    local itemLink = self.item.itemLink or self.item.name or "Unknown Item"
    local playerName = candidate.playerName or "Unknown"

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
-- Presents award reasons in a context menu, then shows the award confirm dialog
function LoothingResultsPanelMixin:ShowAwardReasonDropdown()
    if not Loothing.Settings then return end

    local reasons = Loothing.Settings:GetAwardReasons()

    MenuUtil.CreateContextMenu(self.awardButton, function(ownerRegion, rootDescription)
        rootDescription:CreateTitle("Select Award Reason")

        if not Loothing.Settings:GetRequireAwardReason() then
            rootDescription:CreateButton("Award (No Reason)", function()
                self:ShowAwardDialog(nil, nil, nil)
            end)
            rootDescription:CreateDivider()
        end

        for _, reason in ipairs(reasons) do
            local cr, cg, cb = 1, 1, 1
            if reason.color then
                cr, cg, cb = reason.color[1] or 1, reason.color[2] or 1, reason.color[3] or 1
            end
            local coloredName = string.format("|cff%02x%02x%02x%s|r", cr * 255, cg * 255, cb * 255, reason.name)
            rootDescription:CreateButton(coloredName, function()
                self:ShowAwardDialog(nil, reason.id, reason.name)
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
    local panel = Loolib.CreateFromMixins(LoothingResultsPanelMixin)
    panel:Init()
    return panel
end
