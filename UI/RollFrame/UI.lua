--[[--------------------------------------------------------------------
    Loothing - RollFrame UI & Layout
    Extracted from RollFrame.lua to reduce monolith size.
----------------------------------------------------------------------]]

local _, ns = ...
local Loothing = ns.Addon
local SkinningMixin = ns.SkinningMixin

local RollFrameMixin = ns.RollFrameMixin or {}
ns.RollFrameMixin = RollFrameMixin

-- Frame dimensions
local FRAME_WIDTH = 380
local MIN_FRAME_HEIGHT = 300
local MAX_FRAME_HEIGHT = 600
local BUTTON_HEIGHT = 28
local BUTTON_SPACING = 4
local SECTION_PADDING = 8

-- Section heights
local ITEM_DISPLAY_HEIGHT = 54
local GEAR_COMPARISON_HEIGHT = 60
local NOTE_INPUT_HEIGHT = 48
local ROLL_SECTION_HEIGHT = 24
local TIMER_BAR_HEIGHT = 20
local SUBMIT_BUTTON_HEIGHT = 32
local RESPONSE_LABEL_HEIGHT = 20

-- Session button constants
local SESSION_BUTTON_SIZE = 36
local SESSION_BUTTONS_PER_COLUMN = 10
local MAX_SESSION_BUTTONS = 50  -- 5 columns max to prevent UI overflow

--[[--------------------------------------------------------------------
    Frame Creation
----------------------------------------------------------------------]]

function RollFrameMixin:CreateFrame()
    local frame = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    frame:SetSize(FRAME_WIDTH, MIN_FRAME_HEIGHT)  -- Height will be updated dynamically
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("DIALOG")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:SetClampedToScreen(true)
    frame:Hide()

    -- Apply skin via SkinningMixin
    SkinningMixin:SetupFrame(frame, "RollFrame", "LoothingRollFrame", {
        combatMinimize = true,
        ctrlScroll = true,
        escapeClose = false, -- RollFrame should not close with Escape during voting
    })
    ns.RollFrameFrame = frame

    -- Gold accent bar at top
    local accentBar = frame:CreateTexture(nil, "OVERLAY", nil, 7)
    accentBar:SetPoint("TOPLEFT", 0, 0)
    accentBar:SetPoint("TOPRIGHT", 0, 0)
    accentBar:SetHeight(2)
    accentBar:SetColorTexture(1, 0.82, 0, 1)

    -- Dark header background
    local headerBg = frame:CreateTexture(nil, "BACKGROUND", nil, 1)
    headerBg:SetPoint("TOPLEFT", 0, 0)
    headerBg:SetPoint("TOPRIGHT", 0, 0)
    headerBg:SetHeight(36)
    headerBg:SetColorTexture(0.05, 0.05, 0.05, 0.95)

    local titleBar = CreateFrame("Frame", nil, frame)
    titleBar:SetPoint("TOPLEFT", 12, -8)
    titleBar:SetPoint("TOPRIGHT", -12, -8)
    titleBar:SetHeight(28)
    titleBar:EnableMouse(true)
    titleBar:RegisterForDrag("LeftButton")
    titleBar:SetScript("OnDragStart", function()
        frame:StartMoving()
    end)
    titleBar:SetScript("OnDragStop", function()
        frame:StopMovingOrSizing()
        self:SavePosition()
    end)

    local titleText = titleBar:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    titleText:SetPoint("LEFT", 5, 0)
    titleText:SetText("Loot Response")
    self.titleText = titleText

    local counterText = titleBar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    counterText:SetPoint("RIGHT", -25, 0)
    counterText:SetTextColor(0.7, 0.7, 0.7)
    self.counterText = counterText

    self.frame = frame
end

function RollFrameMixin:CreateElements()
    local L = Loothing.Locale

    self.closeButton = CreateFrame("Button", nil, self.frame, "UIPanelCloseButton")
    self.closeButton:SetPoint("TOPRIGHT", -5, -5)
    self.closeButton:SetScript("OnClick", function()
        self:Close(false)
    end)

    self:CreateSessionButtonFrame()
    self:CreateItemDisplay()
    self:CreateGearComparison()
    self:CreateNoteInput()
    self:CreateRollSection()
    self:CreateTimerBar()

    local submitBtn = CreateFrame("Button", nil, self.frame, "BackdropTemplate")
    submitBtn:SetSize(160, SUBMIT_BUTTON_HEIGHT)
    submitBtn:SetPoint("BOTTOM", 0, 16)
    submitBtn:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        tile = false,
        edgeSize = 1,
        insets = { left = 0, right = 0, top = 0, bottom = 0 },
    })
    submitBtn:SetBackdropColor(0.15, 0.35, 0.15, 0.95)
    submitBtn:SetBackdropBorderColor(0.3, 0.6, 0.3, 1)

    local submitLabel = submitBtn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    submitLabel:SetPoint("CENTER")
    submitLabel:SetText(L["SUBMIT_RESPONSE"] or "Submit Response")
    submitLabel:SetTextColor(0.9, 1, 0.9)
    submitBtn.label = submitLabel

    submitBtn:SetScript("OnEnter", function(btn)
        if btn:IsEnabled() then
            btn:SetBackdropColor(0.2, 0.45, 0.2, 1)
            btn:SetBackdropBorderColor(0.4, 0.75, 0.4, 1)
        end
    end)
    submitBtn:SetScript("OnLeave", function(btn)
        if btn:IsEnabled() then
            btn:SetBackdropColor(0.15, 0.35, 0.15, 0.95)
            btn:SetBackdropBorderColor(0.3, 0.6, 0.3, 1)
        end
    end)
    submitBtn:SetEnabled(false)
    submitBtn:SetBackdropColor(0.12, 0.12, 0.12, 0.8)
    submitBtn:SetBackdropBorderColor(0.2, 0.2, 0.2, 0.8)
    submitLabel:SetTextColor(0.45, 0.45, 0.45)
    submitBtn:SetScript("OnClick", function()
        self:Submit()
    end)
    self.submitButton = submitBtn

    self:CreateResponseSection()
end

--[[--------------------------------------------------------------------
    Session Button Frame (Multi-Item Support)
----------------------------------------------------------------------]]

function RollFrameMixin:CreateSessionButtonFrame()
    local container = CreateFrame("Frame", nil, self.frame)
    container:SetSize(SESSION_BUTTON_SIZE + 4, self.frame:GetHeight())
    container:SetPoint("TOPRIGHT", self.frame, "TOPLEFT", -2, 0)
    container:Hide()
    self.sessionButtonFrame = container
end

function RollFrameMixin:CreateSessionButton(index, item)
    if index > MAX_SESSION_BUTTONS then
        return nil
    end

    local btn = self.sessionButtons[index]

    if not btn then
        btn = CreateFrame("Button", nil, self.sessionButtonFrame, "BackdropTemplate")
        btn:SetSize(SESSION_BUTTON_SIZE, SESSION_BUTTON_SIZE)

        local col = math.floor((index - 1) / SESSION_BUTTONS_PER_COLUMN)
        local row = (index - 1) % SESSION_BUTTONS_PER_COLUMN

        btn:SetPoint("TOPRIGHT",
                     self.sessionButtonFrame,
                     "TOPRIGHT",
                     -col * (SESSION_BUTTON_SIZE + 2),
                     -row * (SESSION_BUTTON_SIZE + 2))

        btn:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Buttons\\WHITE8x8",
            tile = false,
            edgeSize = 1,
            insets = { left = 1, right = 1, top = 1, bottom = 1 },
        })
        btn:SetBackdropColor(0.12, 0.12, 0.12, 0.95)
        btn:SetBackdropBorderColor(0.25, 0.25, 0.25, 1)

        btn.selectBar = btn:CreateTexture(nil, "OVERLAY", nil, 7)
        btn.selectBar:SetHeight(2)
        btn.selectBar:SetPoint("BOTTOMLEFT", 1, 1)
        btn.selectBar:SetPoint("BOTTOMRIGHT", -1, 1)
        btn.selectBar:SetColorTexture(1, 0.82, 0, 1)
        btn.selectBar:Hide()

        btn.selectGlow = btn:CreateTexture(nil, "BACKGROUND", nil, -1)
        btn.selectGlow:SetAllPoints()
        btn.selectGlow:SetColorTexture(0.3, 0.3, 0.5, 0.4)
        btn.selectGlow:Hide()

        btn.iconBorder = btn:CreateTexture(nil, "ARTWORK", nil, 1)
        btn.iconBorder:SetPoint("TOPLEFT", 1, -1)
        btn.iconBorder:SetPoint("BOTTOMRIGHT", -1, 1)
        btn.iconBorder:SetColorTexture(0.5, 0.5, 0.5, 1)

        btn.icon = btn:CreateTexture(nil, "ARTWORK", nil, 2)
        btn.icon:SetPoint("TOPLEFT", 2, -2)
        btn.icon:SetPoint("BOTTOMRIGHT", -2, 2)

        btn.check = btn:CreateTexture(nil, "OVERLAY", nil, 3)
        btn.check:SetTexture("Interface\\RaidFrame\\ReadyCheck-Ready")
        btn.check:SetSize(16, 16)
        btn.check:SetPoint("CENTER")
        btn.check:Hide()

        -- Mini ilvl badge in bottom-right corner
        local ilvlBadge = CreateFrame("Frame", nil, btn)
        ilvlBadge:SetSize(22, 12)
        ilvlBadge:SetPoint("BOTTOMRIGHT", -1, 1)
        ilvlBadge:SetFrameLevel(btn:GetFrameLevel() + 5)

        local ilvlBadgeBg = ilvlBadge:CreateTexture(nil, "BACKGROUND")
        ilvlBadgeBg:SetAllPoints()
        ilvlBadgeBg:SetColorTexture(0, 0, 0, 0.75)

        local ilvlText = ilvlBadge:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        ilvlText:SetPoint("CENTER")
        ilvlText:SetTextColor(1, 0.82, 0)
        ilvlText:SetText("")
        btn.ilvlBadge = ilvlBadge
        btn.ilvlText = ilvlText

        btn:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square")

        btn:SetScript("OnClick", function()
            self:SwitchToItem(index)
        end)

        btn:SetScript("OnEnter", function()
            local itemData = self.items[index]
            if itemData and itemData.itemLink then
                GameTooltip:SetOwner(btn, "ANCHOR_RIGHT")
                GameTooltip:SetHyperlink(itemData.itemLink)
                GameTooltip:Show()
            end
        end)
        btn:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)

        self.sessionButtons[index] = btn
    end

    local texture = item.texture or C_Item.GetItemIconByID(item.itemID or 0)
    btn.icon:SetTexture(texture or "Interface\\Icons\\INV_Misc_QuestionMark")

    local quality = item.quality or 1
    local r, g, b = C_Item.GetItemQualityColor(quality)
    btn.iconBorder:SetColorTexture(r, g, b, 1)

    -- Update ilvl badge
    if btn.ilvlText then
        local ilvl = item.ilvl or 0
        if ilvl and ilvl > 0 then
            btn.ilvlText:SetText(tostring(ilvl))
            btn.ilvlBadge:Show()
        else
            btn.ilvlBadge:Hide()
        end
    end

    local hasResponded = self:HasRespondedToItem(item.guid)

    if index == self.currentItemIndex then
        btn:SetBackdropColor(0.2, 0.2, 0.3, 1)
        btn:SetBackdropBorderColor(1, 0.82, 0, 1)
        btn.selectBar:Show()
        btn.selectGlow:Show()
        btn.check:Hide()
        btn.icon:SetAlpha(1.0)
    else
        btn:SetBackdropColor(0.12, 0.12, 0.12, 0.95)
        btn:SetBackdropBorderColor(0.25, 0.25, 0.25, 1)
        btn.selectBar:Hide()
        btn.selectGlow:Hide()

        if item.state == Loothing.ItemState.AWARDED then
            btn.check:Show()
            btn.icon:SetAlpha(0.5)
        elseif hasResponded then
            btn.check:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
            btn.check:Show()
            btn.icon:SetAlpha(0.6)
        else
            btn.check:Hide()
            btn.icon:SetAlpha(1.0)
        end
    end

    if item.state == Loothing.ItemState.AWARDED then
        btn.check:SetTexture("Interface\\RaidFrame\\ReadyCheck-Ready")
        btn.check:Show()
    end

    btn:Show()
    return btn
end

function RollFrameMixin:UpdateSessionButtons()
    local displayedCount = math.min(#self.items, MAX_SESSION_BUTTONS)

    if #self.items > MAX_SESSION_BUTTONS and not self.sessionButtonWarningShown then
        Loothing:Warn(string.format(
            "Too many items (%d). Only showing buttons for first %d items. Use navigation to access all.",
            #self.items, MAX_SESSION_BUTTONS))
        self.sessionButtonWarningShown = true
    end

    local numColumns = math.ceil(displayedCount / SESSION_BUTTONS_PER_COLUMN)
    if numColumns < 1 then numColumns = 1 end
    local containerWidth = numColumns * (SESSION_BUTTON_SIZE + 2) + 2
    self.sessionButtonFrame:SetWidth(containerWidth)

    for i = 1, displayedCount do
        local item = self.items[i]
        self:CreateSessionButton(i, item)
    end

    for i = displayedCount + 1, #self.sessionButtons do
        if self.sessionButtons[i] then
            self.sessionButtons[i]:Hide()
        end
    end

    if #self.items > 1 then
        self.sessionButtonFrame:Show()
    else
        self.sessionButtonFrame:Hide()
    end

    self:UpdateCounterText()
end

function RollFrameMixin:UpdateCounterText()
    if not self.counterText then return end

    local total = #self.items
    if total <= 1 then
        self.counterText:SetText("")
        return
    end

    local remaining = self:GetUnrespondedCount()

    if remaining == 0 then
        self.counterText:SetText("|cff00ff00All done!|r")
    else
        self.counterText:SetText(string.format("Item %d/%d (%d left)",
            self.currentItemIndex, total, remaining))
    end
end

function RollFrameMixin:SwitchToItem(index)
    if index < 1 or index > #self.items then
        return
    end

    local item = self.items[index]
    if not item then
        Loothing:Debug("SwitchToItem: item at index", index, "is nil")
        return
    end

    self.currentItemIndex = index
    self:DisplayItem(item)
    self:UpdateSessionButtons()
end


--[[--------------------------------------------------------------------
    Dynamic Layout System
----------------------------------------------------------------------]]

function RollFrameMixin:UpdateLayout()
    local showGear = true
    local showTimer = true
    local showRolls = false
    local numButtons = 5

    if Loothing.Settings then
        showGear = Loothing.Settings:Get("rollFrame.showGearComparison", true) ~= false
        showTimer = Loothing.Settings:GetRollFrameTimeoutEnabled()
        showRolls = Loothing.Settings:GetAutoAddRolls()
        numButtons = #self.responseButtonsArray
        if numButtons == 0 then
            numButtons = Loothing.Settings:GetNumButtons() or 5
        end
    end

    local responseHeight = RESPONSE_LABEL_HEIGHT + numButtons * (BUTTON_HEIGHT + BUTTON_SPACING)

    local height = 42 + SECTION_PADDING  -- account for header bar (36px) + gap
    height = height + ITEM_DISPLAY_HEIGHT + SECTION_PADDING

    if showGear then
        height = height + GEAR_COMPARISON_HEIGHT + SECTION_PADDING
        self.gearContainer:Show()
    else
        self.gearContainer:Hide()
    end

    height = height + responseHeight + SECTION_PADDING
    height = height + NOTE_INPUT_HEIGHT + SECTION_PADDING

    if showRolls then
        height = height + ROLL_SECTION_HEIGHT + SECTION_PADDING
        self.rollContainer:Show()
    else
        self.rollContainer:Hide()
    end

    if showTimer then
        height = height + TIMER_BAR_HEIGHT + SECTION_PADDING
        self.timerContainer:Show()
    else
        self.timerContainer:Hide()
    end

    height = height + SUBMIT_BUTTON_HEIGHT + 20
    height = math.max(MIN_FRAME_HEIGHT, math.min(MAX_FRAME_HEIGHT, height))
    self.frame:SetHeight(height)

    if self.sessionButtonFrame then
        self.sessionButtonFrame:SetHeight(height)
    end

    self:ReanchorSections(showGear, showTimer, showRolls, numButtons)
end

function RollFrameMixin:ReanchorSections(showGear, showTimer, showRolls, numButtons)
    local responseHeight = RESPONSE_LABEL_HEIGHT + numButtons * (BUTTON_HEIGHT + BUTTON_SPACING)
    self.responseContainer:SetHeight(responseHeight)

    self.itemContainer:ClearAllPoints()
    self.itemContainer:SetPoint("TOPLEFT", self.frame, "TOPLEFT", 20, -42)
    self.itemContainer:SetPoint("TOPRIGHT", self.frame, "TOPRIGHT", -20, -42)
    self.itemContainer:SetHeight(ITEM_DISPLAY_HEIGHT)

    local lastSection = self.itemContainer

    if showGear then
        self.gearContainer:ClearAllPoints()
        self.gearContainer:SetPoint("TOPLEFT", lastSection, "BOTTOMLEFT", 0, -SECTION_PADDING)
        self.gearContainer:SetPoint("TOPRIGHT", lastSection, "BOTTOMRIGHT", 0, -SECTION_PADDING)
        self.gearContainer:SetHeight(GEAR_COMPARISON_HEIGHT)
        lastSection = self.gearContainer
    end

    self.responseContainer:ClearAllPoints()
    self.responseContainer:SetPoint("TOPLEFT", lastSection, "BOTTOMLEFT", 0, -SECTION_PADDING)
    self.responseContainer:SetPoint("TOPRIGHT", lastSection, "BOTTOMRIGHT", 0, -SECTION_PADDING)
    lastSection = self.responseContainer

    self.noteContainer:ClearAllPoints()
    self.noteContainer:SetPoint("TOPLEFT", lastSection, "BOTTOMLEFT", 0, -SECTION_PADDING)
    self.noteContainer:SetPoint("TOPRIGHT", lastSection, "BOTTOMRIGHT", 0, -SECTION_PADDING)
    self.noteContainer:SetHeight(NOTE_INPUT_HEIGHT)
    lastSection = self.noteContainer

    if showRolls then
        self.rollContainer:ClearAllPoints()
        self.rollContainer:SetPoint("TOPLEFT", lastSection, "BOTTOMLEFT", 0, -SECTION_PADDING)
        self.rollContainer:SetPoint("TOPRIGHT", lastSection, "BOTTOMRIGHT", 0, -SECTION_PADDING)
        self.rollContainer:SetHeight(ROLL_SECTION_HEIGHT)
        lastSection = self.rollContainer
    end

    if showTimer then
        self.timerContainer:ClearAllPoints()
        self.timerContainer:SetPoint("BOTTOMLEFT", self.submitButton, "TOPLEFT", 0, SECTION_PADDING)
        self.timerContainer:SetPoint("BOTTOMRIGHT", self.submitButton, "TOPRIGHT", 0, SECTION_PADDING)
        self.timerContainer:SetHeight(TIMER_BAR_HEIGHT)
    end
end

--[[--------------------------------------------------------------------
    Item Display Section
----------------------------------------------------------------------]]

function RollFrameMixin:CreateItemDisplay()
    local container = CreateFrame("Frame", nil, self.frame)
    container:SetPoint("TOPLEFT", 20, -40)
    container:SetPoint("TOPRIGHT", -20, -40)
    container:SetHeight(ITEM_DISPLAY_HEIGHT)

    -- Quality glow behind icon
    local itemGlow = container:CreateTexture(nil, "BACKGROUND")
    itemGlow:SetSize(64, 64)
    itemGlow:SetPoint("LEFT", -2, 0)
    itemGlow:SetTexture("Interface\\SpellActivationOverlay\\IconAlert")
    itemGlow:SetTexCoord(0.00781250, 0.50781250, 0.27734375, 0.52734375)
    itemGlow:SetAlpha(0.6)
    self.itemGlow = itemGlow

    -- Make icon a button so we can attach tooltip scripts
    local iconBtn = CreateFrame("Button", nil, container)
    iconBtn:SetSize(48, 48)
    iconBtn:SetPoint("LEFT")

    self.itemIcon = iconBtn:CreateTexture(nil, "ARTWORK")
    self.itemIcon:SetAllPoints()

    self.itemIconBorder = iconBtn:CreateTexture(nil, "OVERLAY")
    self.itemIconBorder:SetSize(50, 50)
    self.itemIconBorder:SetPoint("CENTER", self.itemIcon, "CENTER")
    self.itemIconBorder:SetTexture("Interface\\Common\\WhiteIconFrame")

    iconBtn:SetScript("OnEnter", function(btn)
        local itemLink = self.item and self.item.itemLink
        if itemLink then
            GameTooltip:SetOwner(btn, "ANCHOR_RIGHT")
            GameTooltip:SetHyperlink(itemLink)
            GameTooltip:Show()
        end
    end)
    iconBtn:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    self.itemIconBtn = iconBtn

    self.itemName = container:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    self.itemName:SetPoint("TOPLEFT", iconBtn, "TOPRIGHT", 8, -2)
    self.itemName:SetPoint("RIGHT", -8, 0)
    self.itemName:SetJustifyH("LEFT")
    self.itemName:SetWordWrap(false)

    self.itemInfo = container:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    self.itemInfo:SetPoint("BOTTOMLEFT", iconBtn, "BOTTOMRIGHT", 8, 2)
    self.itemInfo:SetTextColor(1, 0.82, 0)

    self.itemContainer = container
end

--[[--------------------------------------------------------------------
    Gear Comparison Section
----------------------------------------------------------------------]]

function RollFrameMixin:CreateGearComparison()
    local container = CreateFrame("Frame", nil, self.frame, "BackdropTemplate")
    container:SetPoint("TOPLEFT", 20, -75)
    container:SetPoint("TOPRIGHT", -20, -75)
    container:SetHeight(GEAR_COMPARISON_HEIGHT)

    container:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        tile = false,
        edgeSize = 1,
        insets = { left = 0, right = 0, top = 0, bottom = 0 },
    })
    container:SetBackdropColor(0.08, 0.08, 0.08, 0.7)
    container:SetBackdropBorderColor(0.2, 0.2, 0.2, 1)

    local label = container:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    label:SetPoint("TOPLEFT", 8, -6)
    label:SetText("Equipped Gear")
    label:SetTextColor(0.8, 0.8, 0.8)

    -- Horizontal divider under label
    local divider = container:CreateTexture(nil, "ARTWORK")
    divider:SetHeight(1)
    divider:SetPoint("TOPLEFT", 8, -18)
    divider:SetPoint("TOPRIGHT", -8, -18)
    divider:SetColorTexture(0.25, 0.25, 0.25, 1)

    -- Gear slot 1 as button for tooltip
    local gear1Btn = CreateFrame("Button", nil, container)
    gear1Btn:SetSize(30, 30)
    gear1Btn:SetPoint("TOPLEFT", 8, -22)

    self.gear1Icon = gear1Btn:CreateTexture(nil, "ARTWORK")
    self.gear1Icon:SetAllPoints()

    local gear1Border = gear1Btn:CreateTexture(nil, "OVERLAY")
    gear1Border:SetSize(32, 32)
    gear1Border:SetPoint("CENTER")
    gear1Border:SetTexture("Interface\\Common\\WhiteIconFrame")
    self.gear1Border = gear1Border

    self.gear1Level = container:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    self.gear1Level:SetPoint("LEFT", gear1Btn, "RIGHT", 4, 0)
    self.gear1Level:SetTextColor(1, 1, 1)

    -- Gear slot 2 as button for tooltip
    local gear2Btn = CreateFrame("Button", nil, container)
    gear2Btn:SetSize(30, 30)
    gear2Btn:SetPoint("LEFT", self.gear1Level, "RIGHT", 16, 0)

    self.gear2Icon = gear2Btn:CreateTexture(nil, "ARTWORK")
    self.gear2Icon:SetAllPoints()

    local gear2Border = gear2Btn:CreateTexture(nil, "OVERLAY")
    gear2Border:SetSize(32, 32)
    gear2Border:SetPoint("CENTER")
    gear2Border:SetTexture("Interface\\Common\\WhiteIconFrame")
    self.gear2Border = gear2Border

    self.gear2Level = container:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    self.gear2Level:SetPoint("LEFT", gear2Btn, "RIGHT", 4, 0)
    self.gear2Level:SetTextColor(1, 1, 1)

    -- Upgrade badge (colored pill)
    local upgradeBadge = CreateFrame("Frame", nil, container, "BackdropTemplate")
    upgradeBadge:SetSize(68, 18)
    upgradeBadge:SetPoint("TOPRIGHT", -6, -24)
    upgradeBadge:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = nil,
    })
    upgradeBadge:SetBackdropColor(0.1, 0.3, 0.1, 0.9)
    self.upgradeBadge = upgradeBadge

    self.upgradeText = upgradeBadge:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    self.upgradeText:SetPoint("CENTER")
    self.upgradeText:SetTextColor(0.4, 1, 0.4)

    -- Store gear buttons for tooltip hookup in UpdateGearComparison
    self.gear1Btn = gear1Btn
    self.gear2Btn = gear2Btn

    gear1Btn:SetScript("OnEnter", function(btn)
        local link = btn.itemLink
        if link then
            GameTooltip:SetOwner(btn, "ANCHOR_RIGHT")
            GameTooltip:SetHyperlink(link)
            GameTooltip:Show()
        end
    end)
    gear1Btn:SetScript("OnLeave", function() GameTooltip:Hide() end)

    gear2Btn:SetScript("OnEnter", function(btn)
        local link = btn.itemLink
        if link then
            GameTooltip:SetOwner(btn, "ANCHOR_RIGHT")
            GameTooltip:SetHyperlink(link)
            GameTooltip:Show()
        end
    end)
    gear2Btn:SetScript("OnLeave", function() GameTooltip:Hide() end)

    self.gearContainer = container
end

--[[--------------------------------------------------------------------
    Response Buttons Section
----------------------------------------------------------------------]]

function RollFrameMixin:CreateResponseSection()
    local L = Loothing.Locale

    local container = CreateFrame("Frame", nil, self.frame)
    container:SetPoint("TOPLEFT", 20, -140)
    container:SetPoint("TOPRIGHT", -20, -140)
    container:SetHeight(140)

    local label = container:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label:SetPoint("TOPLEFT")
    label:SetText(L["SELECT_RESPONSE"] or "SELECT YOUR RESPONSE:")

    self.responseButtons = {}
    self.responseButtonsArray = {}
    self.responseContainer = container
    self.responseLabel = label

    self:RefreshResponseButtons()
end

function RollFrameMixin:RefreshResponseButtons()
    for _, button in ipairs(self.responseButtonsArray) do
        button:Hide()
        button:SetParent(nil)
    end
    wipe(self.responseButtons)
    wipe(self.responseButtonsArray)

    local buttons = Loothing.Settings and Loothing.Settings:GetResponseButtons() or {}
    if #buttons == 0 and Loothing.DefaultSettings then
        local defaultSet = Loothing.DefaultSettings.responseSets
            and Loothing.DefaultSettings.responseSets.sets
            and Loothing.DefaultSettings.responseSets.sets[1]
        if defaultSet and defaultSet.buttons then
            buttons = defaultSet.buttons
        end
    end
    if #buttons == 0 then return end

    local sortedButtons = {}
    for _, btn in ipairs(buttons) do
        sortedButtons[#sortedButtons + 1] = btn
    end
    table.sort(sortedButtons, function(a, b)
        return (a.sort or 0) < (b.sort or 0)
    end)

    local buttonWidth = FRAME_WIDTH - 50

    for i, btnData in ipairs(sortedButtons) do
        local button = self.responseButtons[btnData.id]
        if not button then
            button = CreateFrame("Button", nil, self.responseContainer, "BackdropTemplate")
            button:SetSize(buttonWidth, BUTTON_HEIGHT)
            button:SetPoint("TOPLEFT", 0, -RESPONSE_LABEL_HEIGHT - (i - 1) * (BUTTON_HEIGHT + BUTTON_SPACING))

            button:SetBackdrop({
                bgFile = "Interface\\Buttons\\WHITE8x8",
                edgeFile = "Interface\\Buttons\\WHITE8x8",
                tile = false,
                edgeSize = 1,
                insets = { left = 0, right = 0, top = 0, bottom = 0 },
            })
            button:SetBackdropColor(0.10, 0.10, 0.10, 0.9)
            button:SetBackdropBorderColor(0.22, 0.22, 0.22, 1)

            -- Gradient background texture (subtle color fill from response color)
            local gradTex = button:CreateTexture(nil, "BACKGROUND", nil, 2)
            gradTex:SetPoint("TOPLEFT", 1, -1)
            gradTex:SetPoint("BOTTOMRIGHT", -1, 1)
            button.gradTex = gradTex

            -- Selected glow overlay
            local selectedGlow = button:CreateTexture(nil, "BACKGROUND", nil, 3)
            selectedGlow:SetAllPoints()
            selectedGlow:SetColorTexture(1, 0.82, 0, 0.12)
            selectedGlow:Hide()
            button.selectedGlow = selectedGlow

            -- Left accent bar (shown when selected)
            local accentBar = button:CreateTexture(nil, "ARTWORK", nil, 4)
            accentBar:SetPoint("TOPLEFT", 0, 0)
            accentBar:SetPoint("BOTTOMLEFT", 0, 0)
            accentBar:SetWidth(4)
            accentBar:Hide()
            button.accentBar = accentBar

            -- Gold border when selected
            local goldBorder = button:CreateTexture(nil, "OVERLAY", nil, 6)
            goldBorder:SetAllPoints()
            goldBorder:SetTexture("Interface\\Buttons\\WHITE8x8")
            goldBorder:SetAlpha(0)  -- Use as transparent overlay; border is handled via backdrop
            goldBorder:Hide()
            button.goldBorder = goldBorder

            -- Response icon (20x20)
            local icon = button:CreateTexture(nil, "ARTWORK", nil, 5)
            icon:SetSize(20, 20)
            icon:SetPoint("LEFT", 8, 0)
            button.icon = icon

            -- Left color bar
            local colorBar = button:CreateTexture(nil, "ARTWORK", nil, 5)
            colorBar:SetPoint("LEFT", icon, "RIGHT", 4, 0)
            colorBar:SetSize(4, BUTTON_HEIGHT - 6)
            colorBar:SetColorTexture(1, 1, 1)
            button.colorBar = colorBar

            -- Response text (bold, colored)
            local text = button:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            text:SetPoint("LEFT", colorBar, "RIGHT", 8, 0)
            text:SetText(btnData.text)
            text:SetTextColor(1, 1, 1)
            button.text = text

            button.buttonId = btnData.id
            button.buttonData = btnData

            -- Flash overlay texture with its own animation group
            local flashTex = button:CreateTexture(nil, "OVERLAY", nil, 7)
            flashTex:SetAllPoints()
            flashTex:SetColorTexture(1, 1, 1, 0)

            local ag = flashTex:CreateAnimationGroup()
            local fadeIn = ag:CreateAnimation("Alpha")
            fadeIn:SetFromAlpha(0)
            fadeIn:SetToAlpha(0.4)
            fadeIn:SetDuration(0.05)
            fadeIn:SetOrder(1)
            local fadeOut = ag:CreateAnimation("Alpha")
            fadeOut:SetFromAlpha(0.4)
            fadeOut:SetToAlpha(0)
            fadeOut:SetDuration(0.25)
            fadeOut:SetSmoothing("OUT")
            fadeOut:SetOrder(2)
            button.selectAnim = ag
            button.flashTex = flashTex

            button:SetScript("OnClick", function()
                self:OnResponseClick(button)
                if button.selectAnim then button.selectAnim:Play() end
            end)

            self.responseButtons[btnData.id] = button
            self.responseButtonsArray[i] = button
            button:Show()
        end

        -- Apply color from btnData
        local color = btnData.color or { r = 1, g = 1, b = 1 }
        local cr, cg, cb
        if color.r then
            cr, cg, cb = color.r, color.g, color.b
        elseif type(color) == "table" then
            cr, cg, cb = color[1], color[2], color[3]
        else
            cr, cg, cb = 1, 1, 1
        end

        button.colorBar:SetColorTexture(cr, cg, cb)
        button.accentBar:SetColorTexture(cr, cg, cb)
        button.text:SetTextColor(cr, cg, cb)

        -- Gradient fill with subtle response color
        if button.gradTex then
            button.gradTex:SetGradient("HORIZONTAL",
                CreateColor(cr * 0.25, cg * 0.25, cb * 0.25, 0.6),
                CreateColor(0.06, 0.06, 0.06, 0.0))
        end

        -- Icon from btnData.icon directly (set by ResponseManager from responseSets)
        local iconPath = btnData.icon
        if iconPath then
            button.icon:SetTexture(iconPath)
            button.icon:Show()
        else
            button.icon:Hide()
        end
    end

    self:UpdateLayout()
end

function RollFrameMixin:OnResponseClick(button)
    for _, btn in pairs(self.responseButtons) do
        if btn.selectedGlow then btn.selectedGlow:Hide() end
        if btn.accentBar then btn.accentBar:Hide() end
        btn:SetBackdropBorderColor(0.22, 0.22, 0.22, 1)
    end

    if button.selectedGlow then button.selectedGlow:Show() end
    if button.accentBar then button.accentBar:Show() end
    button:SetBackdropBorderColor(1, 0.82, 0, 0.9)
    self.selectedResponse = button.buttonId

    -- Check per-button requireNotes
    local btnData = button.buttonData
    if btnData and btnData.requireNotes then
        self.requireNotesForResponse = true
        -- Expand notes section and focus if notes are empty
        if self.noteEditBox then
            self.noteContainer:Show()
            local noteText = self.noteEditBox:GetText() or ""
            if noteText == "" then
                self.noteEditBox:SetFocus()
            end
        end
    else
        self.requireNotesForResponse = false
    end

    self:UpdateSubmitButton()
end

--[[--------------------------------------------------------------------
    Roll-Type Button Section (Roll + Pass only)
----------------------------------------------------------------------]]

function RollFrameMixin:CreateRollButtonSection()
    local container = CreateFrame("Frame", nil, self.frame)
    container:SetHeight(24 + 2 * (BUTTON_HEIGHT + BUTTON_SPACING))
    container:Hide()

    local label = container:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label:SetPoint("TOPLEFT")
    label:SetText("ROLL OR PASS:")

    local buttonWidth = FRAME_WIDTH - 50

    -- Roll button
    local rollBtn = CreateFrame("Button", nil, container, "BackdropTemplate")
    rollBtn:SetSize(buttonWidth, BUTTON_HEIGHT)
    rollBtn:SetPoint("TOPLEFT", 0, -(BUTTON_HEIGHT + BUTTON_SPACING))
    rollBtn:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        tile = false, edgeSize = 1,
        insets = { left = 0, right = 0, top = 0, bottom = 0 },
    })
    rollBtn:SetBackdropColor(0.12, 0.12, 0.12, 0.9)
    rollBtn:SetBackdropBorderColor(0.25, 0.25, 0.25, 1)
    rollBtn:SetHighlightTexture("Interface\\Buttons\\WHITE8x8")
    rollBtn:GetHighlightTexture():SetVertexColor(1, 1, 1, 0.08)

    local rollSelected = rollBtn:CreateTexture(nil, "BACKGROUND", nil, 1)
    rollSelected:SetAllPoints()
    rollSelected:SetColorTexture(1, 0.82, 0, 0.08)
    rollSelected:Hide()
    rollBtn.selected = rollSelected

    local rollBar = rollBtn:CreateTexture(nil, "ARTWORK")
    rollBar:SetPoint("LEFT", 0, 0)
    rollBar:SetSize(6, BUTTON_HEIGHT)
    rollBar:SetColorTexture(0.0, 1.0, 0.0)

    local rollText = rollBtn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    rollText:SetPoint("LEFT", rollBar, "RIGHT", 8, 0)
    rollText:SetText("Roll")
    rollText:SetTextColor(0.0, 1.0, 0.0)
    rollBtn.text = rollText

    rollBtn:SetScript("OnClick", function()
        rollSelected:Show()
        self.rollPassSelected:Hide()
        self.selectedResponse = "ROLL"
        self:UpdateSubmitButton()
    end)

    -- Pass button
    local passBtn = CreateFrame("Button", nil, container, "BackdropTemplate")
    passBtn:SetSize(buttonWidth, BUTTON_HEIGHT)
    passBtn:SetPoint("TOPLEFT", rollBtn, "BOTTOMLEFT", 0, -BUTTON_SPACING)
    passBtn:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        tile = false, edgeSize = 1,
        insets = { left = 0, right = 0, top = 0, bottom = 0 },
    })
    passBtn:SetBackdropColor(0.12, 0.12, 0.12, 0.9)
    passBtn:SetBackdropBorderColor(0.25, 0.25, 0.25, 1)
    passBtn:SetHighlightTexture("Interface\\Buttons\\WHITE8x8")
    passBtn:GetHighlightTexture():SetVertexColor(1, 1, 1, 0.08)

    local passSelected = passBtn:CreateTexture(nil, "BACKGROUND", nil, 1)
    passSelected:SetAllPoints()
    passSelected:SetColorTexture(1, 0.82, 0, 0.08)
    passSelected:Hide()
    passBtn.selected = passSelected

    local passBar = passBtn:CreateTexture(nil, "ARTWORK")
    passBar:SetPoint("LEFT", 0, 0)
    passBar:SetSize(6, BUTTON_HEIGHT)
    passBar:SetColorTexture(0.5, 0.5, 0.5)

    local passText = passBtn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    passText:SetPoint("LEFT", passBar, "RIGHT", 8, 0)
    passText:SetText("Pass")
    passText:SetTextColor(0.5, 0.5, 0.5)
    passBtn.text = passText

    passBtn:SetScript("OnClick", function()
        passSelected:Show()
        rollSelected:Hide()
        self.selectedResponse = "PASS"
        self:UpdateSubmitButton()
    end)

    self.rollPassSelected = passSelected
    self.rollButtonSection = container
    self.rollButtonRoll = rollBtn
    self.rollButtonPass = passBtn
end

--- Show roll-type buttons (Roll + Pass) instead of response buttons
function RollFrameMixin:ShowRollButtons()
    if self.responseContainer then
        self.responseContainer:Hide()
    end
    if not self.rollButtonSection then
        self:CreateRollButtonSection()
    end
    -- Anchor roll button section where response container normally sits
    self.rollButtonSection:ClearAllPoints()
    self.rollButtonSection:SetPoint("TOPLEFT", self.responseContainer, "TOPLEFT")
    self.rollButtonSection:SetPoint("TOPRIGHT", self.responseContainer, "TOPRIGHT")
    self.rollButtonSection:Show()

    -- Reset selection state
    self.rollButtonRoll.selected:Hide()
    self.rollPassSelected:Hide()
end

--- Show normal response buttons (hide roll buttons)
function RollFrameMixin:ShowResponseButtons()
    if self.rollButtonSection then
        self.rollButtonSection:Hide()
    end
    if self.responseContainer then
        self.responseContainer:Show()
    end
end

--[[--------------------------------------------------------------------
    Note Input Section
----------------------------------------------------------------------]]

function RollFrameMixin:CreateNoteInput()
    local container = CreateFrame("Frame", nil, self.frame)
    container:SetPoint("TOPLEFT", 20, -285)
    container:SetPoint("TOPRIGHT", -20, -285)
    container:SetHeight(NOTE_INPUT_HEIGHT)

    local label = container:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    label:SetPoint("TOPLEFT")
    label:SetText("Note (optional):")
    label:SetTextColor(0.7, 0.7, 0.7)

    local editBox = CreateFrame("EditBox", nil, container, "BackdropTemplate")
    editBox:SetPoint("TOPLEFT", 0, -18)
    editBox:SetPoint("TOPRIGHT", 0, -18)
    editBox:SetHeight(26)
    editBox:SetFontObject(GameFontHighlightSmall)
    editBox:SetAutoFocus(false)
    editBox:SetMaxLetters(100)

    editBox:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    editBox:SetBackdropColor(0.08, 0.08, 0.08, 0.9)
    editBox:SetBackdropBorderColor(0.28, 0.28, 0.28, 1)

    editBox:SetTextInsets(8, 6, 0, 0)

    -- Placeholder text
    local placeholder = editBox:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    placeholder:SetPoint("LEFT", editBox, "LEFT", 8, 0)
    placeholder:SetText("Add a note...")
    placeholder:SetTextColor(0.4, 0.4, 0.4, 1)
    editBox.placeholder = placeholder

    local function UpdatePlaceholder(eb)
        if eb:GetText() == "" and not eb:HasFocus() then
            placeholder:Show()
        else
            placeholder:Hide()
        end
    end

    editBox:SetScript("OnTextChanged", function(eb)
        self.note = eb:GetText() or ""
        UpdatePlaceholder(eb)
        self:UpdateSubmitButton()
    end)
    editBox:SetScript("OnEditFocusGained", function(eb)
        eb:SetBackdropBorderColor(1, 0.82, 0, 0.8)
        UpdatePlaceholder(eb)
    end)
    editBox:SetScript("OnEditFocusLost", function(eb)
        eb:SetBackdropBorderColor(0.28, 0.28, 0.28, 1)
        UpdatePlaceholder(eb)
    end)
    editBox:SetScript("OnEscapePressed", function(eb)
        eb:ClearFocus()
    end)
    editBox:SetScript("OnEnterPressed", function(eb)
        eb:ClearFocus()
    end)

    self.noteEditBox = editBox
    self.noteContainer = container
end

--[[--------------------------------------------------------------------
    Roll Section
----------------------------------------------------------------------]]

function RollFrameMixin:CreateRollSection()
    local container = CreateFrame("Frame", nil, self.frame)
    container:SetPoint("TOPLEFT", 20, -335)
    container:SetPoint("TOPRIGHT", -20, -335)
    container:SetHeight(ROLL_SECTION_HEIGHT)

    local rollLabel = container:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    rollLabel:SetPoint("LEFT")
    rollLabel:SetText("Your Roll:")
    rollLabel:SetTextColor(0.7, 0.7, 0.7)

    local rollText = container:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    rollText:SetPoint("LEFT", rollLabel, "RIGHT", 8, 0)
    rollText:SetText("...")
    rollText:SetTextColor(1, 0.82, 0)
    self.rollLabel = rollLabel
    self.rollText = rollText
    self.rollContainer = container
end

--[[--------------------------------------------------------------------
    Timer Bar
----------------------------------------------------------------------]]

function RollFrameMixin:CreateTimerBar()
    local container = CreateFrame("Frame", nil, self.frame, "BackdropTemplate")
    container:SetPoint("BOTTOMLEFT", 20, 55)
    container:SetPoint("BOTTOMRIGHT", -20, 55)
    container:SetHeight(TIMER_BAR_HEIGHT)
    container:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        tile = false,
        edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    container:SetBackdropColor(0.06, 0.06, 0.06, 0.9)
    container:SetBackdropBorderColor(0.18, 0.18, 0.18, 1)

    local bar = CreateFrame("StatusBar", nil, container)
    bar:SetPoint("TOPLEFT", 1, -1)
    bar:SetPoint("BOTTOMRIGHT", -1, 1)
    bar:SetStatusBarTexture("Interface\\Buttons\\WHITE8x8")
    bar:SetStatusBarColor(0.2, 0.6, 0.2, 1)
    bar:SetMinMaxValues(0, 1)
    bar:SetValue(1)
    self.timerBar = bar

    -- Spark at the leading edge
    local spark = bar:CreateTexture(nil, "OVERLAY")
    spark:SetSize(8, TIMER_BAR_HEIGHT + 4)
    spark:SetBlendMode("ADD")
    spark:SetTexture("Interface\\CastingBar\\UI-CastingBar-Spark")
    spark:SetPoint("CENTER", bar:GetStatusBarTexture(), "RIGHT", 0, 0)
    self.timerSpark = spark

    local text = container:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    text:SetPoint("CENTER")
    text:SetTextColor(1, 1, 1)
    self.timerText = text

    self.timerContainer = container
end
