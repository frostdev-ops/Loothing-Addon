--[[--------------------------------------------------------------------
    Loothing - Loot Council Addon for WoW 12.0+
    VotePanel - Voting interface for council members
----------------------------------------------------------------------]]

local Loolib = LibStub("Loolib")

--[[--------------------------------------------------------------------
    LoothingVotePanelMixin
----------------------------------------------------------------------]]

LoothingVotePanelMixin = LoolibCreateFromMixins(LoolibCallbackRegistryMixin)

local VOTE_PANEL_EVENTS = {
    "OnVoteSubmitted",
    "OnVoteCancelled",
}

local PANEL_WIDTH = 350
local PANEL_HEIGHT = 400

--- Initialize the vote panel
function LoothingVotePanelMixin:Init()
    LoolibCallbackRegistryMixin.OnLoad(self)
    self:GenerateCallbackEvents(VOTE_PANEL_EVENTS)

    self.item = nil
    self.selectedResponses = {} -- For ranked choice
    self.votingMode = LOOTHING_VOTING_MODE.SIMPLE

    self:CreateFrame()
    self:CreateElements()
end

--- Create the main frame
function LoothingVotePanelMixin:CreateFrame()
    local frame = CreateFrame("Frame", "LoothingVotePanel", UIParent, "BackdropTemplate")
    frame:SetSize(PANEL_WIDTH, PANEL_HEIGHT)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("DIALOG")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:SetClampedToScreen(true)
    frame:Hide()

    -- Backdrop
    frame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true,
        tileSize = 32,
        edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 },
    })

    -- Title bar for dragging
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
function LoothingVotePanelMixin:CreateElements()
    local L = LOOTHING_LOCALE

    -- Title
    self.title = self.frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    self.title:SetPoint("TOP", 0, -20)
    self.title:SetText(L["VOTE_TITLE"])

    -- Close button
    self.closeButton = CreateFrame("Button", nil, self.frame, "UIPanelCloseButton")
    self.closeButton:SetPoint("TOPRIGHT", -5, -5)
    self.closeButton:SetScript("OnClick", function()
        self:Hide()
        self:TriggerEvent("OnVoteCancelled")
    end)

    -- Item display area
    self:CreateItemDisplay()

    -- Response buttons
    self:CreateResponseButtons()

    -- Ranked choice display (for ranked mode)
    self:CreateRankedDisplay()

    -- Timer bar
    self:CreateTimerBar()

    -- Submit button
    self.submitButton = CreateFrame("Button", nil, self.frame, "UIPanelButtonTemplate")
    self.submitButton:SetSize(100, 26)
    self.submitButton:SetPoint("BOTTOM", 0, 20)
    self.submitButton:SetText(L["SUBMIT_VOTE"])
    self.submitButton:SetScript("OnClick", function()
        self:SubmitVote()
    end)
end

--- Create item display area
function LoothingVotePanelMixin:CreateItemDisplay()
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

    -- Slot text
    self.itemSlot = container:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    self.itemSlot:SetPoint("LEFT", self.itemLevel, "RIGHT", 8, 0)
    self.itemSlot:SetTextColor(0.7, 0.7, 0.7)

    self.itemContainer = container
end

--- Create response buttons
function LoothingVotePanelMixin:CreateResponseButtons()
    local L = LOOTHING_LOCALE

    local container = CreateFrame("Frame", nil, self.frame)
    container:SetPoint("TOPLEFT", 20, -120)
    container:SetPoint("TOPRIGHT", -20, -120)
    container:SetHeight(150)

    -- Label
    local label = container:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label:SetPoint("TOPLEFT")
    label:SetText(L["SELECT_RESPONSE"])

    self.responseButtons = {}
    local buttonHeight = 28
    local spacing = 4
    local yOffset = -24

    -- Create button for each response type
    local responseOrder = {
        LOOTHING_RESPONSE.NEED,
        LOOTHING_RESPONSE.GREED,
        LOOTHING_RESPONSE.OFFSPEC,
        LOOTHING_RESPONSE.TRANSMOG,
        LOOTHING_RESPONSE.PASS,
    }

    for i, response in ipairs(responseOrder) do
        local info = LOOTHING_RESPONSE_INFO[response]
        if info then
            local button = CreateFrame("Button", nil, container)
            button:SetSize(PANEL_WIDTH - 50, buttonHeight)
            button:SetPoint("TOPLEFT", 0, yOffset - (i - 1) * (buttonHeight + spacing))

            -- Background
            local bg = button:CreateTexture(nil, "BACKGROUND")
            bg:SetAllPoints()
            bg:SetColorTexture(info.color.r * 0.3, info.color.g * 0.3, info.color.b * 0.3, 0.5)
            button.bg = bg

            -- Highlight
            local highlight = button:CreateTexture(nil, "HIGHLIGHT")
            highlight:SetAllPoints()
            highlight:SetColorTexture(info.color.r, info.color.g, info.color.b, 0.3)

            -- Selected indicator
            local selected = button:CreateTexture(nil, "BORDER")
            selected:SetAllPoints()
            selected:SetColorTexture(info.color.r, info.color.g, info.color.b, 0.5)
            selected:Hide()
            button.selected = selected

            -- Color bar
            local colorBar = button:CreateTexture(nil, "ARTWORK")
            colorBar:SetSize(4, buttonHeight - 4)
            colorBar:SetPoint("LEFT", 2, 0)
            colorBar:SetColorTexture(info.color.r, info.color.g, info.color.b, 1)

            -- Text
            local text = button:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            text:SetPoint("LEFT", colorBar, "RIGHT", 8, 0)
            text:SetText(info.name)
            text:SetTextColor(1, 1, 1)
            button.text = text

            -- Rank number (for ranked choice)
            local rank = button:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
            rank:SetPoint("RIGHT", -8, 0)
            rank:SetTextColor(1, 0.82, 0)
            rank:Hide()
            button.rank = rank

            button.response = response
            button.info = info

            button:SetScript("OnClick", function()
                self:OnResponseClick(button)
            end)

            self.responseButtons[response] = button
        end
    end

    self.responseContainer = container
end

--- Create ranked choice display
function LoothingVotePanelMixin:CreateRankedDisplay()
    local L = LOOTHING_LOCALE

    local container = CreateFrame("Frame", nil, self.frame)
    container:SetPoint("TOPLEFT", 20, -280)
    container:SetPoint("TOPRIGHT", -20, -280)
    container:SetHeight(60)
    container:Hide()

    -- Label
    local label = container:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    label:SetPoint("TOPLEFT")
    label:SetText(L["YOUR_RANKING"])
    label:SetTextColor(0.7, 0.7, 0.7)

    -- Ranking text
    self.rankingText = container:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    self.rankingText:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 0, -4)
    self.rankingText:SetPoint("RIGHT", -8, 0)
    self.rankingText:SetJustifyH("LEFT")
    self.rankingText:SetWordWrap(true)

    -- Clear button
    local clearButton = CreateFrame("Button", nil, container, "UIPanelButtonTemplate")
    clearButton:SetSize(60, 20)
    clearButton:SetPoint("TOPRIGHT")
    clearButton:SetText(L["CLEAR"])
    clearButton:SetScript("OnClick", function()
        self:ClearRanking()
    end)

    self.rankedContainer = container
end

--- Create timer bar
function LoothingVotePanelMixin:CreateTimerBar()
    local container = CreateFrame("Frame", nil, self.frame)
    container:SetPoint("BOTTOMLEFT", 20, 55)
    container:SetPoint("BOTTOMRIGHT", -20, 55)
    container:SetHeight(20)

    -- Background
    local bg = container:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0.1, 0.1, 0.1, 0.8)

    -- Progress bar
    local bar = container:CreateTexture(nil, "ARTWORK")
    bar:SetPoint("TOPLEFT", 1, -1)
    bar:SetPoint("BOTTOMLEFT", 1, 1)
    bar:SetWidth(container:GetWidth() - 2)
    bar:SetColorTexture(0.2, 0.6, 0.2, 1)
    self.timerBar = bar

    -- Timer text
    local text = container:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    text:SetPoint("CENTER")
    text:SetTextColor(1, 1, 1)
    self.timerText = text

    self.timerContainer = container
end

--[[--------------------------------------------------------------------
    Item Display
----------------------------------------------------------------------]]

--- Set the item to vote on
-- @param item table - LoothingItem
function LoothingVotePanelMixin:SetItem(item)
    self.item = item
    wipe(self.selectedResponses)

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

    if item.equipSlot and item.equipSlot ~= "" then
        local slotName = _G[item.equipSlot] or item.equipSlot
        self.itemSlot:SetText(slotName)
    else
        self.itemSlot:SetText("")
    end

    -- Reset response buttons
    self:ResetResponseButtons()

    -- Check for existing vote
    local existingVote = item:GetVoteByVoter(LoothingUtils.GetPlayerName())
    if existingVote and existingVote.responses then
        for i, response in ipairs(existingVote.responses) do
            if self.votingMode == LOOTHING_VOTING_MODE.RANKED_CHOICE then
                self.selectedResponses[i] = response
            else
                self.selectedResponses[1] = response
                break
            end
        end
        self:UpdateResponseButtons()
    end

    -- Update timer
    self:StartTimer()

    self:Show()
end

--[[--------------------------------------------------------------------
    Response Handling
----------------------------------------------------------------------]]

--- Handle response button click
-- @param button Frame
function LoothingVotePanelMixin:OnResponseClick(button)
    local response = button.response

    if self.votingMode == LOOTHING_VOTING_MODE.RANKED_CHOICE then
        -- Ranked choice - add to ranking
        self:AddToRanking(response)
    else
        -- Simple mode - single selection
        self.selectedResponses = { response }
        self:UpdateResponseButtons()
    end
end

--- Add response to ranking (ranked choice mode)
-- @param response number
function LoothingVotePanelMixin:AddToRanking(response)
    -- Check if already ranked
    for i, r in ipairs(self.selectedResponses) do
        if r == response then
            -- Remove from ranking
            table.remove(self.selectedResponses, i)
            self:UpdateResponseButtons()
            return
        end
    end

    -- Add to end of ranking
    self.selectedResponses[#self.selectedResponses + 1] = response
    self:UpdateResponseButtons()
end

--- Clear ranking
function LoothingVotePanelMixin:ClearRanking()
    wipe(self.selectedResponses)
    self:UpdateResponseButtons()
end

--- Reset response buttons
function LoothingVotePanelMixin:ResetResponseButtons()
    for _, button in pairs(self.responseButtons) do
        button.selected:Hide()
        button.rank:Hide()
        button.rank:SetText("")
    end
end

--- Update response buttons based on selection
function LoothingVotePanelMixin:UpdateResponseButtons()
    self:ResetResponseButtons()

    if self.votingMode == LOOTHING_VOTING_MODE.RANKED_CHOICE then
        -- Show rank numbers
        for i, response in ipairs(self.selectedResponses) do
            local button = self.responseButtons[response]
            if button then
                button.selected:Show()
                button.rank:SetText(tostring(i))
                button.rank:Show()
            end
        end

        -- Update ranking text
        self:UpdateRankingText()
        self.rankedContainer:Show()
    else
        -- Simple mode - show selection
        local selected = self.selectedResponses[1]
        if selected and self.responseButtons[selected] then
            self.responseButtons[selected].selected:Show()
        end
        self.rankedContainer:Hide()
    end

    -- Update submit button state
    self:UpdateSubmitButton()
end

--- Update ranking text display
function LoothingVotePanelMixin:UpdateRankingText()
    if #self.selectedResponses == 0 then
        self.rankingText:SetText(LOOTHING_LOCALE["NO_SELECTION"])
        return
    end

    local parts = {}
    for i, response in ipairs(self.selectedResponses) do
        local info = LOOTHING_RESPONSE_INFO[response]
        if info then
            parts[#parts + 1] = string.format("%d. %s", i, info.name)
        end
    end

    self.rankingText:SetText(table.concat(parts, " > "))
end

--- Update submit button state
function LoothingVotePanelMixin:UpdateSubmitButton()
    local hasSelection = #self.selectedResponses > 0
    self.submitButton:SetEnabled(hasSelection)
end

--[[--------------------------------------------------------------------
    Voting
----------------------------------------------------------------------]]

--- Submit the vote
function LoothingVotePanelMixin:SubmitVote()
    if #self.selectedResponses == 0 then
        return
    end

    if not self.item then
        return
    end

    -- Get player info
    local playerName = LoothingUtils.GetPlayerName()
    local _, playerClass = UnitClass("player")

    -- Copy responses
    local responses = { unpack(self.selectedResponses) }

    -- Submit via session
    if Loothing.Session then
        Loothing.Session:SubmitVote(self.item.guid, playerName, playerClass, responses)
    end

    self:TriggerEvent("OnVoteSubmitted", self.item, responses)
    self:Hide()
end

--[[--------------------------------------------------------------------
    Timer
----------------------------------------------------------------------]]

--- Start the timer display
function LoothingVotePanelMixin:StartTimer()
    if self.ticker then
        self.ticker:Cancel()
    end

    self.ticker = C_Timer.NewTicker(0.1, function()
        self:UpdateTimer()
    end)

    self:UpdateTimer()
end

--- Stop the timer
function LoothingVotePanelMixin:StopTimer()
    if self.ticker then
        self.ticker:Cancel()
        self.ticker = nil
    end
end

--- Update timer display
function LoothingVotePanelMixin:UpdateTimer()
    if not self.item then
        self.timerText:SetText("")
        return
    end

    local remaining = self.item:GetTimeRemaining()

    if remaining <= 0 then
        self.timerText:SetText(LOOTHING_LOCALE["TIME_EXPIRED"])
        self.timerBar:SetWidth(0.001)
        self.timerBar:SetColorTexture(0.6, 0.2, 0.2, 1)

        -- Auto-close after a delay
        C_Timer.After(1, function()
            if self.frame:IsShown() and self.item and self.item:GetTimeRemaining() <= 0 then
                self:Hide()
            end
        end)
        return
    end

    -- Calculate progress
    local timeout = self.item.voteTimeout or LOOTHING_TIMING.VOTING_DEFAULT
    local progress = remaining / timeout

    -- Update bar
    local maxWidth = self.timerContainer:GetWidth() - 2
    self.timerBar:SetWidth(math.max(0.001, maxWidth * progress))

    -- Color based on time
    if remaining <= 5 then
        self.timerBar:SetColorTexture(0.8, 0.2, 0.2, 1)
    elseif remaining <= 10 then
        self.timerBar:SetColorTexture(0.8, 0.6, 0.2, 1)
    else
        self.timerBar:SetColorTexture(0.2, 0.6, 0.2, 1)
    end

    -- Update text
    self.timerText:SetText(string.format("%d", math.ceil(remaining)))
end

--[[--------------------------------------------------------------------
    Visibility
----------------------------------------------------------------------]]

--- Show the panel
function LoothingVotePanelMixin:Show()
    self.frame:Show()
end

--- Hide the panel
function LoothingVotePanelMixin:Hide()
    self:StopTimer()
    self.frame:Hide()
end

--- Toggle visibility
function LoothingVotePanelMixin:Toggle()
    if self.frame:IsShown() then
        self:Hide()
    else
        self:Show()
    end
end

--- Check if shown
-- @return boolean
function LoothingVotePanelMixin:IsShown()
    return self.frame:IsShown()
end

--[[--------------------------------------------------------------------
    Configuration
----------------------------------------------------------------------]]

--- Set voting mode
-- @param mode string - LOOTHING_VOTING_MODE value
function LoothingVotePanelMixin:SetVotingMode(mode)
    self.votingMode = mode

    if mode == LOOTHING_VOTING_MODE.RANKED_CHOICE then
        self.rankedContainer:Show()
    else
        self.rankedContainer:Hide()
    end

    self:UpdateResponseButtons()
end

--[[--------------------------------------------------------------------
    Factory
----------------------------------------------------------------------]]

function CreateLoothingVotePanel()
    local panel = LoolibCreateFromMixins(LoothingVotePanelMixin)
    panel:Init()
    return panel
end
