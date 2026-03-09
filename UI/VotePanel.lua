--[[--------------------------------------------------------------------
    Loothing - Loot Council Addon for WoW 12.0+
    VotePanel - Voting interface for council members
----------------------------------------------------------------------]]

local Loolib = LibStub("Loolib")

--[[--------------------------------------------------------------------
    LoothingVotePanelMixin
----------------------------------------------------------------------]]

LoothingVotePanelMixin = Loolib.CreateFromMixins(Loolib.CallbackRegistryMixin)

local VOTE_PANEL_EVENTS = {
    "OnVoteSubmitted",
    "OnVoteCancelled",
}

local PANEL_WIDTH = 350
local PANEL_HEIGHT = 400

-- Pool of recycled response button frames to avoid orphaning on each refresh
local responseButtonPool = {}

--- Initialize the vote panel
function LoothingVotePanelMixin:Init()
    Loolib.CallbackRegistryMixin.OnLoad(self)
    self:GenerateCallbackEvents(VOTE_PANEL_EVENTS)

    self.item = nil
    self.selectedResponses = {} -- For ranked choice
    self.votingMode = Loothing.VotingMode.SIMPLE

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
    local L = Loothing.Locale

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

    -- Note input
    self:CreateNoteInput()

    -- Submit button
    self.submitButton = CreateFrame("Button", nil, self.frame, "UIPanelButtonTemplate")
    self.submitButton:SetSize(100, 26)
    self.submitButton:SetPoint("BOTTOM", 0, 20)
    self.submitButton:SetText(L["SUBMIT_VOTE"])
    self.submitButton:SetScript("OnClick", function()
        self:SubmitVote()
    end)
end

--- Create note input field
function LoothingVotePanelMixin:CreateNoteInput()
    local L = Loothing.Locale

    -- Container for note input
    local container = CreateFrame("Frame", nil, self.frame)
    container:SetPoint("BOTTOMLEFT", 20, 80)
    container:SetPoint("BOTTOMRIGHT", -20, 80)
    container:SetHeight(30)

    -- Label
    local label = container:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    label:SetPoint("TOPLEFT", 0, 0)
    label:SetText(L["NOTE"] or "Note:")
    label:SetTextColor(0.8, 0.8, 0.8)

    -- Edit box
    local editBox = CreateFrame("EditBox", "LoothingVotePanelNoteInput", container, "InputBoxTemplate")
    editBox:SetPoint("TOPLEFT", label, "TOPRIGHT", 5, 3)
    editBox:SetPoint("BOTTOMRIGHT", 0, 0)
    editBox:SetAutoFocus(false)
    editBox:SetMaxLetters(100)
    editBox:SetScript("OnEnterPressed", function(self)
        self:ClearFocus()
    end)
    editBox:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
    end)

    self.noteInput = editBox
    self.noteContainer = container

    -- Required indicator (shown when notes are required)
    local requiredText = container:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    requiredText:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 0, -2)
    requiredText:SetText("*" .. (L["REQUIRED"] or "Required"))
    requiredText:SetTextColor(1, 0.3, 0.3)
    requiredText:Hide()
    self.noteRequiredText = requiredText
end

--- Get the current note text
-- @return string
function LoothingVotePanelMixin:GetNote()
    if self.noteInput then
        return self.noteInput:GetText() or ""
    end
    return ""
end

--- Clear the note input
function LoothingVotePanelMixin:ClearNote()
    if self.noteInput then
        self.noteInput:SetText("")
    end
end

--- Update note input visibility based on settings
function LoothingVotePanelMixin:UpdateNoteInputVisibility()
    if not self.noteContainer then return end

    local requireNotes = Loothing.Settings and Loothing.Settings:GetRequireNotes()
    if self.noteRequiredText then
        self.noteRequiredText:SetShown(requireNotes)
    end
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
    local L = Loothing.Locale

    local container = CreateFrame("Frame", nil, self.frame)
    container:SetPoint("TOPLEFT", 20, -120)
    container:SetPoint("TOPRIGHT", -20, -120)
    container:SetHeight(320)  -- Increased to accommodate up to 10 buttons

    -- Label
    local label = container:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label:SetPoint("TOPLEFT")
    label:SetText(L["SELECT_RESPONSE"])

    self.responseButtons = {}
    self.responseButtonsArray = {}
    self.responseContainer = container
    self.responseContainerLabel = label

    -- Initial button creation will happen in RefreshResponseButtons
    self:RefreshResponseButtons()
end

--- Acquire a response button from the pool, or create a new one
-- @param parent Frame - Parent frame for newly created buttons
-- @return Button
local function AcquireResponseButton(parent)
    local button = table.remove(responseButtonPool)
    if button then
        button:SetParent(parent)
        button:ClearAllPoints()
        button:Show()
        return button
    end

    -- Create a new button with all sub-regions; colors/text are set by caller
    button = CreateFrame("Button", nil, parent)

    local bg = button:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    button.bg = bg

    local highlight = button:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetAllPoints()
    button.highlight = highlight

    local selected = button:CreateTexture(nil, "BORDER")
    selected:SetAllPoints()
    selected:Hide()
    button.selected = selected

    local colorBar = button:CreateTexture(nil, "ARTWORK")
    colorBar:SetPoint("LEFT", 2, 0)
    button.colorBar = colorBar

    local text = button:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    text:SetPoint("LEFT", colorBar, "RIGHT", 8, 0)
    text:SetTextColor(1, 1, 1)
    button.text = text

    local rank = button:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    rank:SetPoint("RIGHT", -8, 0)
    rank:SetTextColor(1, 0.82, 0)
    rank:Hide()
    button.rank = rank

    return button
end

--- Release a response button back to the pool
-- @param button Button
local function ReleaseResponseButton(button)
    button:SetScript("OnClick", nil)
    button:ClearAllPoints()
    button:Hide()
    button:SetParent(nil)
    button.buttonId = nil
    button.buttonData = nil
    button.selected:Hide()
    button.rank:Hide()
    button.rank:SetText("")
    responseButtonPool[#responseButtonPool + 1] = button
end

--- Refresh response buttons based on active button set
function LoothingVotePanelMixin:RefreshResponseButtons()
    -- Return existing buttons to the pool instead of orphaning them
    for _, button in ipairs(self.responseButtonsArray) do
        ReleaseResponseButton(button)
    end
    wipe(self.responseButtons)
    wipe(self.responseButtonsArray)

    if not Loothing.Settings then return end

    -- Get buttons from active response set
    local buttons = Loothing.Settings:GetResponseButtons()
    if not buttons or #buttons == 0 then return end

    -- Sort by sort order
    local sortedButtons = {}
    for _, btn in ipairs(buttons) do
        table.insert(sortedButtons, btn)
    end
    table.sort(sortedButtons, function(a, b) return a.sort < b.sort end)

    local buttonHeight = 28
    local spacing = 4
    local yOffset = -24

    for i, btnData in ipairs(sortedButtons) do
        local button = AcquireResponseButton(self.responseContainer)
        button:SetSize(PANEL_WIDTH - 50, buttonHeight)
        button:SetPoint("TOPLEFT", 0, yOffset - (i - 1) * (buttonHeight + spacing))

        -- Parse color (normalize to array format in case of named-field colors from sync)
        local r, g, b = unpack(LoothingUtils.ColorToArray(btnData.color))

        -- Update sub-region colors
        button.bg:SetColorTexture(r * 0.3, g * 0.3, b * 0.3, 0.5)
        button.highlight:SetColorTexture(r, g, b, 0.3)
        button.selected:SetColorTexture(r, g, b, 0.5)
        button.colorBar:SetSize(4, buttonHeight - 4)
        button.colorBar:SetColorTexture(r, g, b, 1)
        button.text:SetText(btnData.text)

        button.buttonId = btnData.id
        button.buttonData = btnData

        button:SetScript("OnClick", function()
            self:OnResponseClick(button)
        end)

        self.responseButtons[btnData.id] = button
        self.responseButtonsArray[i] = button
    end
end

--- Update button visibility (all buttons in the active set are shown)
function LoothingVotePanelMixin:UpdateButtonVisibility()
    for _, button in ipairs(self.responseButtonsArray) do
        button:Show()
    end
end

--- Create ranked choice display
function LoothingVotePanelMixin:CreateRankedDisplay()
    local L = Loothing.Locale

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
    container:SetPoint("BOTTOMLEFT", 20, 50)
    container:SetPoint("BOTTOMRIGHT", -20, 50)
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

    -- Check for existing vote (only if item has the method)
    local existingVote = item.GetVoteByVoter and item:GetVoteByVoter(LoothingUtils.GetPlayerFullName())
    if existingVote and existingVote.responses then
        for i, response in ipairs(existingVote.responses) do
            if self.votingMode == Loothing.VotingMode.RANKED_CHOICE then
                self.selectedResponses[i] = response
            else
                self.selectedResponses[1] = response
                break
            end
        end
        self:UpdateResponseButtons()
    end

    -- Apply observe mode
    self:ApplyObserveMode()

    -- Update button visibility based on settings
    self:UpdateButtonVisibility()

    -- Update timer
    self:StartTimer()

    self:Show()
end

--- Apply observe mode restrictions
function LoothingVotePanelMixin:ApplyObserveMode()
    if not Loothing.Settings then return end

    local observeMode = Loothing.Settings:GetObserveMode()

    -- Disable submit button in observe mode
    if self.submitButton then
        self.submitButton:SetEnabled(not observeMode)
        if observeMode then
            self.submitButton:SetText("Observe Mode")
        else
            local L = Loothing.Locale
            self.submitButton:SetText(L["SUBMIT_VOTE"] or "Submit Vote")
        end
    end

    -- Disable response buttons in observe mode
    for _, button in pairs(self.responseButtons) do
        button:SetEnabled(not observeMode)
    end
end

--[[--------------------------------------------------------------------
    Response Handling
----------------------------------------------------------------------]]

--- Handle response button click
-- @param button Frame
function LoothingVotePanelMixin:OnResponseClick(button)
    local buttonId = button.buttonId

    if self.votingMode == Loothing.VotingMode.RANKED_CHOICE then
        -- Ranked choice - add to ranking
        self:AddToRanking(buttonId)
    else
        -- Simple mode - single selection
        self.selectedResponses = { buttonId }
        self:UpdateResponseButtons()
    end
end

--- Add response to ranking (ranked choice mode)
-- @param buttonId number
function LoothingVotePanelMixin:AddToRanking(buttonId)
    -- Check if already ranked
    for i, id in ipairs(self.selectedResponses) do
        if id == buttonId then
            -- Remove from ranking
            table.remove(self.selectedResponses, i)
            self:UpdateResponseButtons()
            return
        end
    end

    -- Add to end of ranking
    self.selectedResponses[#self.selectedResponses + 1] = buttonId
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

    if self.votingMode == Loothing.VotingMode.RANKED_CHOICE then
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
        self.rankingText:SetText(Loothing.Locale["NO_SELECTION"])
        return
    end

    local parts = {}
    for i, buttonId in ipairs(self.selectedResponses) do
        local button = self.responseButtons[buttonId]
        if button and button.buttonData then
            parts[#parts + 1] = string.format("%d. %s", i, button.buttonData.text)
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

    -- Check for observe mode
    if Loothing.Settings and Loothing.Settings:GetObserveMode() then
        print("|cff00ccff[Loothing]|r You are in observe mode and cannot cast votes.")
        return
    end

    -- Check for required notes
    local note = self:GetNote()
    if Loothing.Settings and Loothing.Settings:GetRequireNotes() then
        if note == "" then
            print("|cff00ccff[Loothing]|r You must add a note with your vote.")
            if self.noteInput then
                self.noteInput:SetFocus()
            end
            return
        end
    end

    -- Copy responses
    local responses = { unpack(self.selectedResponses) }

    -- Submit via session
    if Loothing.Session then
        Loothing.Session:SubmitVote(self.item.guid, responses)
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

    -- No-timeout mode: show "No Limit", full bar, never auto-close
    if remaining == math.huge then
        self.timerText:SetText(Loothing.Locale["NO_LIMIT"] or "No Limit")
        local maxWidth = self.timerContainer:GetWidth() - 2
        self.timerBar:SetWidth(math.max(0.001, maxWidth))
        self.timerBar:SetColorTexture(0.2, 0.6, 0.2, 1)
        return
    end

    if remaining <= 0 then
        self.timerText:SetText(Loothing.Locale["TIME_EXPIRED"])
        self.timerBar:SetWidth(0.001)
        self.timerBar:SetColorTexture(0.6, 0.2, 0.2, 1)

        -- Auto-close after a delay
        C_Timer.After(1, function()
            local itemRemaining = self.frame:IsShown() and self.item and self.item:GetTimeRemaining() or 0
            if itemRemaining ~= math.huge and itemRemaining <= 0 then
                self:Hide()
            end
        end)
        return
    end

    -- Calculate progress
    local timeout = self.item.voteTimeout or Loothing.Timing.VOTING_DEFAULT
    local progress = (timeout > 0) and (remaining / timeout) or 1

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
-- @param mode string - Loothing.VotingMode value
function LoothingVotePanelMixin:SetVotingMode(mode)
    self.votingMode = mode

    if mode == Loothing.VotingMode.RANKED_CHOICE then
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
    local panel = Loolib.CreateFromMixins(LoothingVotePanelMixin)
    panel:Init()
    return panel
end
