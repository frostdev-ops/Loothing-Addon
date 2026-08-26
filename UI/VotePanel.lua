--[[--------------------------------------------------------------------
    Loothing - Loot Council Addon for WoW 12.0+
    VotePanel - Voting interface for council members
----------------------------------------------------------------------]]

local _, ns = ...
local Loolib = LibStub("Loolib")
local Loothing = ns.Addon
local L = ns.Locale
local Utils = ns.Utils
local SkinningMixin = ns.SkinningMixin

local AnimationUtil = Loolib.AnimationUtil
local AnimationPresets = Loolib.AnimationPresets
local PixelUtil = Loolib.PixelUtil

local ApplyAccentGlow = ns.FramePolish.ApplyAccentGlow
local AttachIconButtonPolish = ns.FramePolish.AttachIconButtonPolish

--[[--------------------------------------------------------------------
    VotePanelMixin
----------------------------------------------------------------------]]

local VotePanelMixin = ns.VotePanelMixin or Loolib.CreateFromMixins(Loolib.CallbackRegistryMixin)
ns.VotePanelMixin = VotePanelMixin

local VOTE_PANEL_EVENTS = {
    "OnVoteSubmitted",
    "OnVoteCancelled",
}

local PANEL_WIDTH = 380
local PANEL_HEIGHT = 500

-- Pool of recycled response button frames to avoid orphaning on each refresh
local responseButtonPool = {}

local function CanCurrentPlayerVote()
    return (Loothing.Council
        and Loothing.Council.CanPlayerVote
        and Loothing.Council:CanPlayerVote()) or false
end

local function IsCurrentPlayerObserverOnly()
    if CanCurrentPlayerVote() then
        return false
    end

    return (Loothing.Observer
        and (Loothing.Observer:IsPlayerObserver() or Loothing.Observer:IsMLObserver())) or false
end

local function IsSelfVoteBlocked(candidateName)
    if not candidateName then
        return false
    end
    local selfVoteAllowed = not Loothing.Settings or Loothing.Settings:GetSelfVote()
    if selfVoteAllowed then
        return false
    end
    local playerName = Utils.GetPlayerFullName()
    return playerName and Utils.IsSamePlayer(candidateName, playerName) or false
end

--- Initialize the vote panel
function VotePanelMixin:Init()
    Loolib.CallbackRegistryMixin.OnLoad(self)
    self:GenerateCallbackEvents(VOTE_PANEL_EVENTS)

    self.item = nil
    self.selectedResponses = {} -- For ranked choice
    self.votingMode = Loothing.VotingMode.SIMPLE

    self:CreateFrame()
    self:CreateElements()
    self:ApplyTheme()

    -- Close panel when session ends (prevent stale UI)
    if Loothing.Session then
        Loothing.Session:RegisterCallback("OnSessionEnded", function()
            -- Drop per-session refs so the next session cannot briefly
            -- flash stale item/candidate data if Show() is called before
            -- SetItem() repopulates the panel.
            self.item = nil
            if self.selectedResponses then wipe(self.selectedResponses) end
            self:Hide()
        end, self)
    end

    if Loothing.Council and Loothing.Council.RegisterCallback then
        Loothing.Council:RegisterCallback("OnRosterChanged", function()
            if self.frame and self.frame:IsShown() then
                self:ApplyObserveMode()
            end
        end, self)
    end

    if Loothing.Observer and Loothing.Observer.RegisterCallback then
        Loothing.Observer:RegisterCallback("OnObserverListChanged", function()
            if self.frame and self.frame:IsShown() then
                self:ApplyObserveMode()
            end
        end, self)
        Loothing.Observer:RegisterCallback("OnPermissionsChanged", function()
            if self.frame and self.frame:IsShown() then
                self:ApplyObserveMode()
            end
        end, self)
    end
end

--- Create the main frame
function VotePanelMixin:CreateFrame()
    local frame = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
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

    -- Start hidden-alpha so the first Show() can fade in.
    frame:SetAlpha(0)

    -- Gradient accent strip behind the title (dynamic from SkinningMixin).
    local headerStrip = frame:CreateTexture(nil, "BACKGROUND", nil, 2)
    headerStrip:SetPoint("TOPLEFT", 14, -14)
    headerStrip:SetPoint("TOPRIGHT", -14, -14)
    headerStrip:SetHeight(32)
    headerStrip:SetColorTexture(1, 1, 1, 1)
    self.headerStrip = headerStrip
    ApplyAccentGlow(headerStrip, 0.18)

    -- Pixel-perfect outer border: color refreshed from SkinningMixin in ApplyTheme.
    if PixelUtil and type(PixelUtil.SetThinBorder) == "function" and SkinningMixin then
        self.pixelBorder = PixelUtil.SetThinBorder(frame, SkinningMixin:GetColor("borderStrong"))
    end

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
    ns.VotePanelFrame = frame

    local WM = Loolib:GetModule("WindowManager")
    if WM then WM:Register(frame) end
end

--- Create UI elements
function VotePanelMixin:CreateElements()
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
    AttachIconButtonPolish(self.closeButton, { hoverScale = 1.15, pressScale = 0.90 })

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
    self.submitButton = ns.CreateThemedButton(self.frame)
    self.submitButton:SetSize(100, 26)
    self.submitButton:SetPoint("BOTTOM", 0, 20)
    self.submitButton:SetText(L["SUBMIT_VOTE"])
    self.submitButton:SetScript("OnClick", function()
        self:SubmitVote()
    end)
    ns.SkinningMixin:StylePlainButton(self.submitButton, "primary")
end

--- Create note input field
function VotePanelMixin:CreateNoteInput()
    -- Container for note input
    local container = CreateFrame("Frame", nil, self.frame)
    container:SetPoint("BOTTOMLEFT", 20, 80)
    container:SetPoint("BOTTOMRIGHT", -20, 80)
    container:SetHeight(30)

    -- Label
    local label = container:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    label:SetPoint("TOPLEFT", 0, 0)
    label:SetText(L["NOTE"])
    label:SetTextColor(0.8, 0.8, 0.8)

    -- Edit box
    local editBox = CreateFrame("EditBox", nil, container, "InputBoxTemplate")
    editBox:SetPoint("TOPLEFT", label, "TOPRIGHT", 5, 3)
    editBox:SetPoint("BOTTOMRIGHT", 0, 0)
    editBox:SetAutoFocus(false)
    editBox:SetMaxLetters(100)
    editBox:SetScript("OnEnterPressed", function(eb) eb:ClearFocus() end)
    editBox:SetScript("OnEscapePressed", function(eb) eb:ClearFocus() end)

    self.noteInput = editBox
    self.noteContainer = container

    -- Required indicator (shown when notes are required)
    local requiredText = container:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    requiredText:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 0, -2)
    requiredText:SetText("*" .. (L["REQUIRED"]))
    requiredText:SetTextColor(1, 0.3, 0.3)
    requiredText:Hide()
    self.noteRequiredText = requiredText
end

--- Get the current note text
-- @return string
function VotePanelMixin:GetNote()
    if self.noteInput then
        return self.noteInput:GetText() or ""
    end
    return ""
end

--- Clear the note input
function VotePanelMixin:ClearNote()
    if self.noteInput then
        self.noteInput:SetText("")
    end
end

--- Update note input visibility based on settings
function VotePanelMixin:UpdateNoteInputVisibility()
    if not self.noteContainer then return end

    local requireNotes = Loothing.Settings and Loothing.Settings:GetRequireNotes()
    if self.noteRequiredText then
        self.noteRequiredText:SetShown(requireNotes)
    end
end

--- Create item display area
function VotePanelMixin:CreateItemDisplay()
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
function VotePanelMixin:CreateResponseButtons()
    local container = CreateFrame("Frame", nil, self.frame)
    container:SetPoint("TOPLEFT", 20, -120)
    container:SetPoint("TOPRIGHT", -20, -120)
    container:SetHeight(400)  -- Accommodates up to ~12 candidates visible

    -- Label
    local label = container:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label:SetPoint("TOPLEFT")
    label:SetText(L["SELECT_CANDIDATE"] or L["SELECT_RESPONSE"] or "Select Candidate")

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

--- Refresh candidate rows for the current item
-- Populates from item.candidateManager instead of response button settings.
-- Each button represents a candidate (player) who has responded to the loot.
function VotePanelMixin:RefreshResponseButtons()
    -- Return existing buttons to the pool instead of orphaning them
    for _, button in ipairs(self.responseButtonsArray) do
        ReleaseResponseButton(button)
    end
    wipe(self.responseButtons)
    wipe(self.responseButtonsArray)

    if not self.item or not self.item.candidateManager then return end

    local candidates = self.item.candidateManager:GetAllCandidates()
    if not candidates or #candidates == 0 then return end

    -- Sort candidates: by response (NEED first), then by name
    local sorted = {}
    for _, c in ipairs(candidates) do
        sorted[#sorted + 1] = c
    end
    table.sort(sorted, function(a, b)
        local rA = a.response or 999
        local rB = b.response or 999
        if type(rA) ~= type(rB) then
            return type(rA) == "number"  -- numeric responses sort before string system responses
        end
        if rA ~= rB then return rA < rB end
        return (a.playerName or a.name or "") < (b.playerName or b.name or "")
    end)

    local buttonHeight = 28
    local spacing = 4
    local yOffset = -24

    for i, candidate in ipairs(sorted) do
        local button = AcquireResponseButton(self.responseContainer)
        button:SetSize(PANEL_WIDTH - 50, buttonHeight)
        button:SetPoint("TOPLEFT", 0, yOffset - (i - 1) * (buttonHeight + spacing))

        -- Class color for candidate
        local class = candidate.class
        local r, g, b = 0.5, 0.5, 0.5
        if class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class] then
            local cc = RAID_CLASS_COLORS[class]
            r, g, b = cc.r, cc.g, cc.b
        end

        -- Update sub-region colors
        button.bg:SetColorTexture(r * 0.3, g * 0.3, b * 0.3, 0.5)
        button.highlight:SetColorTexture(r, g, b, 0.3)
        button.selected:SetColorTexture(r, g, b, 0.5)
        button.colorBar:SetSize(4, buttonHeight - 4)
        button.colorBar:SetColorTexture(r, g, b, 1)

        -- Display: short name + response label
        local displayName = Utils.GetShortName(candidate.playerName or candidate.name or "Unknown")
        local responseInfo = candidate.response and (Loothing.ResponseInfo[candidate.response] or Loothing.SystemResponseInfo[candidate.response])
        local responseLabel = responseInfo and responseInfo.name or ""
        if responseLabel ~= "" then
            button.text:SetText(string.format("%s  |cFF888888(%s)|r", displayName, responseLabel))
        else
            button.text:SetText(displayName)
        end

        -- Key by normalized candidate name (matches CastVote / UpdateCandidateVoters)
        local candidateName = Utils.NormalizeName(candidate.playerName or candidate.name)
        button.buttonId = candidateName
        button.selfVoteBlocked = IsSelfVoteBlocked(candidateName)
        button.buttonData = {
            text = displayName,
            candidateName = candidateName,
            class = class,
            color = { r, g, b },
        }

        button:SetScript("OnClick", function()
            self:OnResponseClick(button)
        end)

        self.responseButtons[candidateName] = button
        self.responseButtonsArray[i] = button
    end
end

--- Update button visibility (all buttons in the active set are shown)
function VotePanelMixin:UpdateButtonVisibility()
    for _, button in ipairs(self.responseButtonsArray) do
        button:Show()
    end
end

function VotePanelMixin:UpdateCandidateButtonEligibility()
    local canVote = CanCurrentPlayerVote()
    for _, button in ipairs(self.responseButtonsArray) do
        local blocked = IsSelfVoteBlocked(button.buttonId)
        button.selfVoteBlocked = blocked
        button:SetEnabled(canVote and not blocked)
        button:SetAlpha(blocked and 0.45 or 1)
    end
end

function VotePanelMixin:RemoveBlockedSelections()
    local changed = false
    for i = #self.selectedResponses, 1, -1 do
        if IsSelfVoteBlocked(self.selectedResponses[i]) then
            table.remove(self.selectedResponses, i)
            changed = true
        end
    end
    return changed
end

--- Create ranked choice display with interactive rows
function VotePanelMixin:CreateRankedDisplay()
    local container = CreateFrame("Frame", nil, self.frame)
    container:SetPoint("TOPLEFT", 20, -280)
    container:SetPoint("TOPRIGHT", -20, -280)
    container:SetHeight(60)
    container:Hide()

    -- Label
    local label = container:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    label:SetPoint("TOPLEFT")
    label:SetText((Loothing.Locale and Loothing.Locale["YOUR_RANKING"]) or "Your Ranking")
    label:SetTextColor(0.7, 0.7, 0.7)

    -- Clear button
    local clearButton = ns.CreateThemedButton(container)
    clearButton:SetSize(60, 20)
    clearButton:SetPoint("TOPRIGHT")
    clearButton:SetText((Loothing.Locale and Loothing.Locale["CLEAR"]) or "Clear")
    clearButton:SetScript("OnClick", function()
        self:ClearRanking()
    end)
    ns.SkinningMixin:StylePlainButton(clearButton)

    -- Helper text for max/min rank messages
    self.rankHelperText = container:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    self.rankHelperText:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 0, -2)
    self.rankHelperText:SetTextColor(1, 0.5, 0.2)
    self.rankHelperText:Hide()

    self.rankedContainer = container
    self.rankRowFrames = {}
end

--- Create a single interactive rank row
-- @param parent Frame
-- @param index number - Rank position
-- @return Frame
function VotePanelMixin:CreateRankRow(parent, _index)
    local row = CreateFrame("Frame", nil, parent)
    row:SetSize(280, 22)

    -- Rank number
    local rankNum = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    rankNum:SetPoint("LEFT", 0, 0)
    rankNum:SetWidth(20)
    rankNum:SetJustifyH("CENTER")
    row.rankNum = rankNum

    -- Color bar
    local colorBar = row:CreateTexture(nil, "ARTWORK")
    colorBar:SetSize(4, 18)
    colorBar:SetPoint("LEFT", rankNum, "RIGHT", 4, 0)
    row.colorBar = colorBar

    -- Response name
    local nameText = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    nameText:SetPoint("LEFT", colorBar, "RIGHT", 6, 0)
    nameText:SetWidth(150)
    nameText:SetJustifyH("LEFT")
    nameText:SetWordWrap(false)
    row.nameText = nameText

    -- Up arrow button
    local upBtn = CreateFrame("Button", nil, row)
    upBtn:SetSize(16, 16)
    upBtn:SetPoint("LEFT", nameText, "RIGHT", 4, 0)
    upBtn:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIcon-ScrollUp-Up")
    upBtn:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIcon-ScrollUp-Highlight")
    upBtn:SetScript("OnClick", function()
        self:MoveRank(row.rankIndex, row.rankIndex - 1)
    end)
    AttachIconButtonPolish(upBtn, { hoverScale = 1.18, pressScale = 0.88 })
    row.upBtn = upBtn

    -- Down arrow button
    local downBtn = CreateFrame("Button", nil, row)
    downBtn:SetSize(16, 16)
    downBtn:SetPoint("LEFT", upBtn, "RIGHT", 2, 0)
    downBtn:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Up")
    downBtn:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Highlight")
    downBtn:SetScript("OnClick", function()
        self:MoveRank(row.rankIndex, row.rankIndex + 1)
    end)
    AttachIconButtonPolish(downBtn, { hoverScale = 1.18, pressScale = 0.88 })
    row.downBtn = downBtn

    -- Remove button
    local removeBtn = CreateFrame("Button", nil, row)
    removeBtn:SetSize(16, 16)
    removeBtn:SetPoint("LEFT", downBtn, "RIGHT", 2, 0)
    removeBtn:SetNormalTexture("Interface\\Buttons\\UI-StopButton")
    removeBtn:SetHighlightTexture("Interface\\Buttons\\UI-StopButton")
    removeBtn:SetScript("OnClick", function()
        table.remove(self.selectedResponses, row.rankIndex)
        self:RefreshRankDisplay()
        self:UpdateResponseButtons()
    end)
    AttachIconButtonPolish(removeBtn, { hoverScale = 1.18, pressScale = 0.88 })
    row.removeBtn = removeBtn

    return row
end

--- Swap two rank positions
-- @param fromIndex number
-- @param toIndex number
function VotePanelMixin:MoveRank(fromIndex, toIndex)
    if toIndex < 1 or toIndex > #self.selectedResponses then
        return
    end
    self.selectedResponses[fromIndex], self.selectedResponses[toIndex] =
        self.selectedResponses[toIndex], self.selectedResponses[fromIndex]
    self:RefreshRankDisplay()
    self:UpdateResponseButtons()
end

--- Rebuild rank row display from selectedResponses
function VotePanelMixin:RefreshRankDisplay()
    -- Hide all existing rows
    for _, row in ipairs(self.rankRowFrames) do
        row:Hide()
    end

    if not self.rankedContainer then return end

    local count = #self.selectedResponses
    local rowHeight = 24
    local yOffset = -20  -- Below the label

    for i, buttonId in ipairs(self.selectedResponses) do
        -- Reuse or create row
        local row = self.rankRowFrames[i]
        if not row then
            row = self:CreateRankRow(self.rankedContainer, i)
            self.rankRowFrames[i] = row
        end

        row.rankIndex = i
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", 0, yOffset - (i - 1) * rowHeight)
        row:SetPoint("RIGHT", -8, 0)

        -- Rank number with gradient color (gold -> gray)
        local t = count > 1 and (i - 1) / (count - 1) or 0
        local r = 1.0 - t * 0.4
        local g = 0.82 - t * 0.42
        local b = 0.0 + t * 0.4
        row.rankNum:SetText(tostring(i))
        row.rankNum:SetTextColor(r, g, b)

        -- Candidate info (buttonId is a candidate name string)
        local button = self.responseButtons[buttonId]
        if button and button.buttonData then
            local btnData = button.buttonData
            local cr, cg, cb = 0.5, 0.5, 0.5
            if btnData.color then
                cr, cg, cb = unpack(btnData.color)
            end
            row.colorBar:SetColorTexture(cr, cg, cb, 1)
            row.nameText:SetText(btnData.text)
            row.nameText:SetTextColor(cr, cg, cb)
        else
            -- No button for this candidate (left the group, restored vote
            -- from a stale roster): render the raw name instead of
            -- whatever the reused row last displayed — a positional reuse
            -- showed one candidate's name while submitting another.
            row.colorBar:SetColorTexture(0.5, 0.5, 0.5, 1)
            row.nameText:SetText(Utils.GetShortName(buttonId) or tostring(buttonId))
            row.nameText:SetTextColor(0.7, 0.7, 0.7)
        end

        -- Show/hide arrows based on position
        row.upBtn:SetShown(i > 1)
        row.downBtn:SetShown(i < count)

        row:Show()
    end

    -- Update container height
    local height = math.max(50, count * rowHeight + 28)
    self.rankedContainer:SetHeight(height)

    -- Update helper text
    self:UpdateRankHelperText()
end

--- Update helper text for rank limits
function VotePanelMixin:UpdateRankHelperText()
    if not self.rankHelperText then return end

    local count = #self.selectedResponses
    local maxRanks = Loothing.Settings and Loothing.Settings:GetMaxRanks() or 0
    local minRanks = Loothing.Settings and Loothing.Settings:GetMinRanks() or 1

    if maxRanks > 0 and count >= maxRanks then
        self.rankHelperText:SetText(string.format(L["RANK_LIMIT_REACHED"], maxRanks))
        self.rankHelperText:SetTextColor(1, 0.5, 0.2)
        self.rankHelperText:Show()
    elseif count < minRanks then
        self.rankHelperText:SetText(string.format(L["RANK_MINIMUM_REQUIRED"], minRanks))
        self.rankHelperText:SetTextColor(1, 0.3, 0.3)
        self.rankHelperText:Show()
    else
        self.rankHelperText:Hide()
    end
end

--- Create timer bar
function VotePanelMixin:CreateTimerBar()
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
function VotePanelMixin:SetItem(item)
    self.item = item
    wipe(self.selectedResponses)

    if not item then
        self:Hide()
        return
    end

    -- Update item display
    local texture = item.texture or C_Item.GetItemIconByID(item.itemID or 0)
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

    self.itemSlot:SetText(
        (ns.TokenData and ns.TokenData:FormatItemSlot(item)) or "")

    -- Re-render once item info loads (cold cache, async tier-token override).
    if not item.itemInfoLoaded and item.RegisterCallback then
        item:RegisterCallback("OnItemInfoLoaded", function()
            if item.UnregisterCallback then
                item:UnregisterCallback("OnItemInfoLoaded", self)
            end
            -- Only while still open on this item: a late info load must
            -- not reopen a panel the member already closed (SetItem ends
            -- with Show()).
            if self.item ~= item or not self.frame:IsShown() then return end
            -- Preserve an unsubmitted in-progress ranking: SetItem wipes
            -- selectedResponses and only restores SUBMITTED votes, so the
            -- async reload silently discarded the member's clicks.
            local pending = {}
            for i, v in ipairs(self.selectedResponses) do pending[i] = v end
            self:SetItem(item)
            if #pending > 0 then
                wipe(self.selectedResponses)
                for i, v in ipairs(pending) do self.selectedResponses[i] = v end
                self:RemoveBlockedSelections()
                self:UpdateResponseButtons()
            end
        end, self)
    end

    -- Rebuild candidate buttons for this item
    self:RefreshResponseButtons()
    self:ResetResponseButtons()

    -- Restore existing vote (responses contain candidate names)
    local existingVote = item.GetVoteByVoter and item:GetVoteByVoter(Utils.GetPlayerFullName())
    if existingVote and existingVote.responses then
        for i, candidateName in ipairs(existingVote.responses) do
            if self.votingMode == Loothing.VotingMode.RANKED_CHOICE then
                self.selectedResponses[i] = candidateName
            else
                self.selectedResponses[1] = candidateName
                break
            end
        end
    end

    self:RemoveBlockedSelections()
    self:UpdateResponseButtons()

    -- Apply observe mode
    self:ApplyObserveMode()

    -- Update button visibility based on settings
    self:UpdateButtonVisibility()

    -- Update timer
    self:StartTimer()

    self:Show()
end

--- Apply observe mode restrictions
function VotePanelMixin:ApplyObserveMode()
    local canVote = CanCurrentPlayerVote()
    local observerOnly = IsCurrentPlayerObserverOnly()

    -- Observers/non-council cannot submit. Eligible council members still run
    -- through UpdateSubmitButton so selection and min-rank requirements apply.
    if self.submitButton then
        if observerOnly then
            self.submitButton:SetText(L["OBSERVE_MODE"])
        else
            self.submitButton:SetText(L["SUBMIT_VOTE"])
        end
    end

    self:UpdateCandidateButtonEligibility()
    self:UpdateSubmitButton()
end

--[[--------------------------------------------------------------------
    Response Handling
----------------------------------------------------------------------]]

--- Handle response button click
-- @param button Frame
function VotePanelMixin:OnResponseClick(button)
    local buttonId = button.buttonId
    if IsSelfVoteBlocked(buttonId) then
        Loothing:Print(Loothing.Locale["SELF_VOTE_DISABLED"])
        return
    end

    if self.votingMode == Loothing.VotingMode.RANKED_CHOICE then
        -- Ranked choice - add to ranking
        self:AddToRanking(buttonId)
    else
        -- Simple mode - single selection
        self.selectedResponses = { buttonId }
        self:UpdateResponseButtons()
    end
end

--- Add candidate to ranking (ranked choice mode)
-- @param buttonId string - Normalized candidate name
function VotePanelMixin:AddToRanking(buttonId)
    -- Check if already ranked
    for i, id in ipairs(self.selectedResponses) do
        if id == buttonId then
            -- Remove from ranking
            table.remove(self.selectedResponses, i)
            self:UpdateResponseButtons()
            return
        end
    end

    -- Enforce maxRanks limit
    local maxRanks = Loothing.Settings and Loothing.Settings:GetMaxRanks() or 0
    if maxRanks > 0 and #self.selectedResponses >= maxRanks then
        return
    end

    -- Add to end of ranking
    self.selectedResponses[#self.selectedResponses + 1] = buttonId
    self:UpdateResponseButtons()
end

--- Clear ranking
function VotePanelMixin:ClearRanking()
    wipe(self.selectedResponses)
    self:UpdateResponseButtons()
end

--- Reset response buttons
function VotePanelMixin:ResetResponseButtons()
    for _, button in pairs(self.responseButtons) do
        button.selected:Hide()
        button.rank:Hide()
        button.rank:SetText("")
    end
end

--- Update response buttons based on selection
function VotePanelMixin:UpdateResponseButtons()
    self:RemoveBlockedSelections()
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

        -- Update interactive rank display
        self:RefreshRankDisplay()
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
    self:UpdateCandidateButtonEligibility()
    self:UpdateSubmitButton()
end

--- Update submit button state
function VotePanelMixin:UpdateSubmitButton()
    if not self.submitButton then
        return
    end

    local count = #self.selectedResponses
    local hasSelection = count > 0

    if not CanCurrentPlayerVote() then
        self.submitButton:SetEnabled(false)
        return
    end

    if self.votingMode == Loothing.VotingMode.RANKED_CHOICE then
        local minRanks = Loothing.Settings and Loothing.Settings:GetMinRanks() or 1
        self.submitButton:SetEnabled(count >= minRanks)
    else
        self.submitButton:SetEnabled(hasSelection)
    end
end

--[[--------------------------------------------------------------------
    Voting
----------------------------------------------------------------------]]

--- Submit the vote
function VotePanelMixin:SubmitVote()
    if #self.selectedResponses == 0 then
        return
    end

    if not self.item then
        return
    end

    -- Check for vote eligibility. Open observation alone is not a vote block:
    -- council members can vote while non-council observers watch.
    if not CanCurrentPlayerVote() then
        Loothing:Print(Loothing.Locale["OBSERVE_MODE_MSG"])
        return
    end

    -- Check for required notes
    local note = self:GetNote()
    if Loothing.Settings and Loothing.Settings:GetRequireNotes() then
        if note == "" then
            Loothing:Print(Loothing.Locale["VOTE_NOTE_REQUIRED"])
            if self.noteInput then
                self.noteInput:SetFocus()
            end
            return
        end
    end

    -- Copy responses after dropping any choices that became invalid while the
    -- panel was open, such as self-votes after a settings sync.
    self:RemoveBlockedSelections()
    local responses = { unpack(self.selectedResponses) }
    if #responses == 0 then
        self:UpdateResponseButtons()
        return
    end

    if not Loothing.Session then
        return
    end

    local submitted = Loothing.Session:SubmitVote(self.item.guid, responses)
    if not submitted then
        -- Tell the user — a silent no-op reads as a dead button when the
        -- vote raced the timeout/award.
        local L = Loothing.Locale or {}
        Loothing:Print(L["VOTE_CLOSED_FOR_ITEM"] or "Voting has closed for this item.")
        self:UpdateResponseButtons()
        return
    end

    self:TriggerEvent("OnVoteSubmitted", self.item, responses)
    self:Hide()
end

--[[--------------------------------------------------------------------
    Timer
----------------------------------------------------------------------]]

--- Start the timer display
function VotePanelMixin:StartTimer()
    if self.ticker then
        self.ticker:Cancel()
    end

    self.ticker = C_Timer.NewTicker(0.1, function()
        self:UpdateTimer()
    end)

    self:UpdateTimer()
end

--- Stop the timer
function VotePanelMixin:StopTimer()
    if self.ticker then
        self.ticker:Cancel()
        self.ticker = nil
    end
end

--- Update timer display
function VotePanelMixin:UpdateTimer()
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

        -- Auto-close after a delay. Deduplicated: only one pending timer
        -- at a time (mirrors RollFrame) — the 10 Hz ticker otherwise
        -- stacked ~10 of these, each restarting the close fade.
        if not self.autoCloseTimer then
            self.autoCloseTimer = true
            C_Timer.After(1, function()
                self.autoCloseTimer = nil
                local itemRemaining = self.frame:IsShown() and self.item and self.item:GetTimeRemaining() or 0
                if itemRemaining ~= math.huge and itemRemaining <= 0 then
                    self:Hide()
                end
            end)
        end
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
    Theme Refresh
----------------------------------------------------------------------]]

--- Re-apply custom accents (gradient strip, pixel border) from current theme.
--- Called from Init and from Show so that accent/theme changes propagate the
--- next time the panel appears.
function VotePanelMixin:ApplyTheme()
    if not self.frame then return end

    if self.headerStrip then
        ApplyAccentGlow(self.headerStrip, 0.18)
        self.headerStrip:SetAlpha(1)
    end

    if self.pixelBorder and PixelUtil and SkinningMixin then
        local c = SkinningMixin:GetColor("borderStrong") or { 0, 0, 0, 1 }
        for _, tex in pairs(self.pixelBorder) do
            if type(tex) == "table" and type(tex.SetColorTexture) == "function" then
                tex:SetColorTexture(c[1] or 0, c[2] or 0, c[3] or 0, c[4] or 1)
            end
        end
    end

    if self.submitButton and SkinningMixin and SkinningMixin.StylePlainButton then
        SkinningMixin:StylePlainButton(self.submitButton, "primary")
    end
end

--[[--------------------------------------------------------------------
    Visibility
----------------------------------------------------------------------]]

--- Show the panel
function VotePanelMixin:Show()
    if self.frame._loothingFadeGroup then self.frame._loothingFadeGroup:Stop() end

    -- Refresh theme-driven accents in case the user changed skin/accent while hidden.
    self:ApplyTheme()

    self.frame:Show()
    self.frame:Raise()

    if AnimationPresets then
        self.frame._loothingFadeGroup = AnimationPresets.FadeIn(self.frame, 0.22, "outCubic")
    else
        self.frame:SetAlpha(1)
    end
end

--- Hide the panel
function VotePanelMixin:Hide()
    self:StopTimer()

    if self.frame._loothingFadeGroup then self.frame._loothingFadeGroup:Stop() end

    if AnimationPresets and self.frame:IsVisible() then
        self.frame._loothingFadeGroup = AnimationPresets.FadeOut(self.frame, 0.13, "inCubic", true, function()
            self.frame:SetAlpha(0)
        end)
    else
        self.frame:Hide()
    end
end

--- Toggle visibility
function VotePanelMixin:Toggle()
    if self.frame:IsShown() then
        self:Hide()
    else
        self:Show()
    end
end

--- Check if shown
-- @return boolean
function VotePanelMixin:IsShown()
    return self.frame:IsShown()
end

--[[--------------------------------------------------------------------
    Configuration
----------------------------------------------------------------------]]

--- Set voting mode
-- @param mode string - Loothing.VotingMode value
function VotePanelMixin:SetVotingMode(mode)
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

local function CreateVotePanel()
    local panel = Loolib.CreateFromMixins(VotePanelMixin)
    panel:Init()
    return panel
end

ns.CreateVotePanel = CreateVotePanel
