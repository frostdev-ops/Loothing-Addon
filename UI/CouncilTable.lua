--[[--------------------------------------------------------------------
    Loothing - UI: Council Table (Composite)
    Orchestrates Columns, Rows, Events, item tabs, voter progress,
    detail tooltip, and skinning integration.
----------------------------------------------------------------------]]

local _, ns = ...
local Loolib = LibStub("Loolib")
local Loothing = ns.Addon
local Utils = ns.Utils
local SkinningMixin = ns.SkinningMixin
local L = Loothing.Locale

local CouncilTableMixin = Loolib.CreateFromMixins(Loolib.CallbackRegistryMixin, ns.CouncilTableMixin or {})
ns.CouncilTableMixin = CouncilTableMixin

local COUNCIL_TABLE_EVENTS = {
    "OnCandidateSelected",
    "OnCandidateAwarded",
    "OnItemTabChanged",
    "OnSortChanged",
}

-- Window dimensions
local TABLE_WIDTH = 900
local TABLE_HEIGHT = 600
local MIN_WIDTH = 700
local MIN_HEIGHT = 450
local MAX_WIDTH = 1400
local MAX_HEIGHT = 900

local ITEM_TAB_WIDTH = 120
local ITEM_TAB_HEIGHT = 44
local ITEM_TAB_SPACING = 4
local ITEM_TAB_ICON_SIZE = 36
local ITEM_TAB_BAR_HEIGHT = 52
local SCROLL_ARROW_WIDTH = 16
local SCROLL_STEP = 124  -- ITEM_TAB_WIDTH + ITEM_TAB_SPACING
-- Throttle refresh to avoid spam during bulk candidate updates
local REFRESH_THROTTLE = 0.15

--- Check if the current player is an observer (not council, not ML)
-- Observers can see the table when voting.observe is enabled, but cannot
-- perform ML actions or cast votes.
local function IsObserverOnly()
    local isCouncil = Loothing.Council and Loothing.Council:IsPlayerCouncilMember()
    local isML = Loothing.Session and Loothing.Session:IsMasterLooter()
    if not isCouncil and not isML then
        return true  -- Regular observer
    end
    if isML and Loothing.Observer and Loothing.Observer:IsMLObserver() then
        return true  -- ML in observer mode
    end
    if isML and not isCouncil then
        return true  -- ML not on council = implicit observer
    end
    return false
end

function CouncilTableMixin:Init(parent)
    Loolib.CallbackRegistryMixin.OnLoad(self)
    self:GenerateCallbackEvents(COUNCIL_TABLE_EVENTS)

    self.parent = parent
    self.items = {}
    self.currentItem = nil
    self.selectedCandidate = nil
    self.candidateRows = {}
    self.itemTabs = {}
    -- ThrottledRefresh: leading+trailing throttle, allocated once per instance
    self.ThrottledRefresh = Loolib.FunctionUtil.ThrottleWithTrailing(
        function() self:RefreshCandidates() end, REFRESH_THROTTLE)

    -- Sorting defaults
    self.sortColumn = "response"
    self.sortAscending = false

    self:CreateFrame()
    self:CreateElements()
    self:CreateFramePools()
    self:RegisterEvents()
end

function CouncilTableMixin:CreateFrame()
    local frame = CreateFrame("Frame", nil, self.parent or UIParent, "BackdropTemplate")
    frame:SetSize(TABLE_WIDTH, TABLE_HEIGHT)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("DIALOG")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:SetClampedToScreen(true)
    frame:SetResizable(true)
    frame:SetResizeBounds(MIN_WIDTH, MIN_HEIGHT, MAX_WIDTH, MAX_HEIGHT)
    frame:Hide()

    -- Apply skin via SkinningMixin
    SkinningMixin:SetupFrame(frame, "CouncilTable", "LoothingCouncilTable", {
        combatMinimize = true,
        ctrlScroll = true,
        escapeClose = true,
    })
    ns.CouncilTableFrame = frame

    -- Title bar for dragging
    local titleBar = CreateFrame("Frame", nil, frame)
    titleBar:SetPoint("TOPLEFT", 12, -12)
    titleBar:SetPoint("TOPRIGHT", -12, -12)
    titleBar:SetHeight(24)
    titleBar:EnableMouse(true)
    titleBar:RegisterForDrag("LeftButton")
    titleBar:SetScript("OnDragStart", function() frame:StartMoving() end)
    titleBar:SetScript("OnDragStop", function()
        frame:StopMovingOrSizing()
        self:SavePosition()
    end)

    -- Title
    local title = titleBar:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("LEFT", 4, 0)
    title:SetText(L["LOOT_COUNCIL"])
    title:SetTextColor(1, 0.82, 0)
    self.titleText = title

    -- Resize grip
    local resizeGrip = CreateFrame("Button", nil, frame)
    resizeGrip:SetSize(16, 16)
    resizeGrip:SetPoint("BOTTOMRIGHT", -8, 8)
    resizeGrip:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    resizeGrip:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
    resizeGrip:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
    resizeGrip:SetScript("OnMouseDown", function() frame:StartSizing("BOTTOMRIGHT") end)
    resizeGrip:SetScript("OnMouseUp", function()
        frame:StopMovingOrSizing()
        self:SavePosition()
        self:OnResize()
    end)

    self.frame = frame
end

function CouncilTableMixin:CreateElements()
    -- Close button
    local closeButton = CreateFrame("Button", nil, self.frame, "UIPanelCloseButton")
    closeButton:SetPoint("TOPRIGHT", -5, -5)
    closeButton:SetScript("OnClick", function() self:Hide() end)

    -- Item tabs container (top of frame)
    self:CreateItemTabBar()

    -- Voter progress indicator (replaces filter button area)
    self:CreateVoterProgressUI()

    -- Column headers container
    self.headersContainer = CreateFrame("Frame", nil, self.frame)
    self.headersContainer:SetPoint("TOPLEFT", 16, -96)
    self.headersContainer:SetPoint("TOPRIGHT", -16, -96)
    self.headersContainer:SetHeight(22)

    -- Candidate list (scrollable)
    self:CreateCandidateList()

    -- Floating detail tooltip (anchored outside frame, right edge)
    self:CreateDetailTooltip()

    -- Action buttons (bottom right)
    self:CreateActionButtons()

    -- Empty text
    self.emptyText = self.frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    self.emptyText:SetPoint("CENTER", self.listContainer, "CENTER")
    self.emptyText:SetText(L["COUNCIL_NO_CANDIDATES"])
    self.emptyText:SetTextColor(0.5, 0.5, 0.5)

    -- Observer mode indicator (shown in title bar when observing)
    local observerText = self.frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    observerText:SetPoint("RIGHT", closeButton, "LEFT", -8, 0)
    observerText:SetText("(" .. L["OBSERVER"] .. ")")
    observerText:SetTextColor(0.7, 0.7, 0.3)
    observerText:Hide()
    self.observerText = observerText

    -- Enchanter button (next to action buttons)
    self:CreateEnchanterButton()

    -- Build column headers
    self:RebuildColumnHeaders()
end

--[[--------------------------------------------------------------------
    Item Tab Bar (session switching)
----------------------------------------------------------------------]]

function CouncilTableMixin:CreateItemTabBar()
    local bar = CreateFrame("Frame", nil, self.frame)
    bar:SetPoint("TOPLEFT", 16, -40)
    bar:SetPoint("TOPRIGHT", -16, -40)
    bar:SetHeight(ITEM_TAB_BAR_HEIGHT)
    self.itemTabBar = bar
    self.scrollOffset = 0

    -- Left scroll arrow
    local leftArrow = CreateFrame("Button", nil, bar)
    leftArrow:SetSize(SCROLL_ARROW_WIDTH, ITEM_TAB_HEIGHT)
    leftArrow:SetPoint("LEFT", 0, -4)
    leftArrow:SetNormalTexture("Interface\\Buttons\\UI-SpellbookIcon-PrevPage-Up")
    leftArrow:SetPushedTexture("Interface\\Buttons\\UI-SpellbookIcon-PrevPage-Down")
    leftArrow:SetDisabledTexture("Interface\\Buttons\\UI-SpellbookIcon-PrevPage-Disabled")
    leftArrow:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
    leftArrow:SetScript("OnClick", function()
        self:ScrollTo(self.scrollOffset - SCROLL_STEP)
    end)
    leftArrow:Hide()
    self.scrollLeftArrow = leftArrow

    -- Right scroll arrow
    local rightArrow = CreateFrame("Button", nil, bar)
    rightArrow:SetSize(SCROLL_ARROW_WIDTH, ITEM_TAB_HEIGHT)
    rightArrow:SetPoint("RIGHT", 0, -4)
    rightArrow:SetNormalTexture("Interface\\Buttons\\UI-SpellbookIcon-NextPage-Up")
    rightArrow:SetPushedTexture("Interface\\Buttons\\UI-SpellbookIcon-NextPage-Down")
    rightArrow:SetDisabledTexture("Interface\\Buttons\\UI-SpellbookIcon-NextPage-Disabled")
    rightArrow:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
    rightArrow:SetScript("OnClick", function()
        self:ScrollTo(self.scrollOffset + SCROLL_STEP)
    end)
    rightArrow:Hide()
    self.scrollRightArrow = rightArrow

    -- Clip frame between arrows
    local clip = CreateFrame("Frame", nil, bar)
    clip:SetPoint("LEFT", leftArrow, "RIGHT", 2, 0)
    clip:SetPoint("RIGHT", rightArrow, "LEFT", -2, 0)
    clip:SetHeight(ITEM_TAB_HEIGHT)
    clip:SetPoint("BOTTOM", 0, 0)
    clip:SetClipsChildren(true)
    self.itemTabClip = clip

    -- Content frame inside clip (holds the tabs, slides left/right)
    local content = CreateFrame("Frame", nil, clip)
    content:SetHeight(ITEM_TAB_HEIGHT)
    content:SetPoint("TOPLEFT", 0, 0)
    content:SetWidth(1) -- set dynamically in RefreshItemTabs
    self.itemTabContent = content

    -- Mouse wheel scrolling on the bar
    bar:EnableMouseWheel(true)
    bar:SetScript("OnMouseWheel", function(_, delta)
        self:ScrollTo(self.scrollOffset - delta * SCROLL_STEP)
    end)
end

function CouncilTableMixin:RefreshItemTabs()
    -- Clear existing tabs
    for _, tab in ipairs(self.itemTabs) do
        tab:Hide()
    end
    wipe(self.itemTabs)

    if not Loothing.Session then return end

    local items = Loothing.Session:GetItems()
    if not items then return end

    self.items = {}
    local index = 0
    for _, item in items:Enumerate() do
        index = index + 1
        self.items[index] = item
    end

    -- Set content frame width
    local contentWidth = #self.items * SCROLL_STEP - ITEM_TAB_SPACING
    if contentWidth < 1 then contentWidth = 1 end
    self.itemTabContent:SetWidth(contentWidth)

    for i, item in ipairs(self.items) do
        local tab = self:CreateItemTab(i, item)
        self.itemTabs[i] = tab
    end

    -- Reset scroll
    self.scrollOffset = 0
    self.itemTabContent:SetPoint("TOPLEFT", 0, 0)
    self:UpdateScrollArrows()

    -- Select first item if none selected
    if not self.currentItem and #self.items > 0 then
        self:SelectItemTab(self.items[1].guid)
    end

    -- Update voted indicators on item tabs
    self:UpdateItemTabVotedIndicators()
end

function CouncilTableMixin:CreateItemTab(index, item)
    local tab = CreateFrame("Button", nil, self.itemTabContent, "BackdropTemplate")
    tab:SetSize(ITEM_TAB_WIDTH, ITEM_TAB_HEIGHT)
    tab:SetPoint("LEFT", (index - 1) * SCROLL_STEP, 0)

    tab:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        tile = false, edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    tab:SetBackdropColor(0.08, 0.08, 0.12, 0.9)

    local quality = item.quality or 1
    local qr, qg, qb = C_Item.GetItemQualityColor(quality)

    -- 3px quality-colored left accent bar
    local accentBar = tab:CreateTexture(nil, "ARTWORK", nil, 1)
    accentBar:SetSize(3, ITEM_TAB_HEIGHT - 2)
    accentBar:SetPoint("LEFT", 1, 0)
    accentBar:SetTexture("Interface\\Buttons\\WHITE8x8")
    accentBar:SetVertexColor(qr, qg, qb, 1)
    tab.accentBar = accentBar

    -- Quality glow behind icon
    local glow = tab:CreateTexture(nil, "BACKGROUND")
    glow:SetSize(48, 48)
    glow:SetPoint("LEFT", 2, 0)
    glow:SetTexture("Interface\\SpellActivationOverlay\\IconAlert")
    glow:SetTexCoord(0.00781250, 0.50781250, 0.27734375, 0.52734375)
    glow:SetVertexColor(qr, qg, qb, 1)
    glow:SetAlpha(0.4)
    tab.glow = glow

    -- Item icon
    local icon = tab:CreateTexture(nil, "ARTWORK")
    icon:SetSize(ITEM_TAB_ICON_SIZE, ITEM_TAB_ICON_SIZE)
    icon:SetPoint("LEFT", 4, 0)
    local texture = item.texture or C_Item.GetItemIconByID(item.itemID or 0)
    icon:SetTexture(texture or "Interface\\Icons\\INV_Misc_QuestionMark")
    tab.icon = icon

    -- WhiteIconFrame quality border around icon
    local iconBorder = tab:CreateTexture(nil, "OVERLAY")
    iconBorder:SetSize(ITEM_TAB_ICON_SIZE + 2, ITEM_TAB_ICON_SIZE + 2)
    iconBorder:SetPoint("CENTER", icon, "CENTER")
    iconBorder:SetTexture("Interface\\Common\\WhiteIconFrame")
    iconBorder:SetVertexColor(qr, qg, qb, 1)
    tab.iconBorder = iconBorder

    -- ilvl badge overlay on icon (bottom-right)
    local ilvlBadge = CreateFrame("Frame", nil, tab)
    ilvlBadge:SetSize(24, 12)
    ilvlBadge:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", 2, -1)
    ilvlBadge:SetFrameLevel(tab:GetFrameLevel() + 5)

    local ilvlBg = ilvlBadge:CreateTexture(nil, "BACKGROUND")
    ilvlBg:SetAllPoints()
    ilvlBg:SetColorTexture(0, 0, 0, 0.8)

    local ilvlText = ilvlBadge:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    ilvlText:SetPoint("CENTER")
    ilvlText:SetTextColor(1, 0.82, 0)
    local ilvl = item.ilvl or 0
    if ilvl > 0 then
        ilvlText:SetText(tostring(ilvl))
    else
        ilvlBadge:Hide()
    end
    tab.ilvlBadge = ilvlBadge

    -- Item name (quality-colored, truncated)
    local nameText = tab:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    nameText:SetPoint("TOPLEFT", icon, "TOPRIGHT", 6, -2)
    nameText:SetPoint("RIGHT", tab, "RIGHT", -22, 0)
    nameText:SetJustifyH("LEFT")
    nameText:SetWordWrap(false)
    nameText:SetText(item.name or "Unknown")
    nameText:SetTextColor(qr, qg, qb, 1)
    tab.nameText = nameText

    -- Slot info text (gray)
    local slotText = tab:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    slotText:SetPoint("BOTTOMLEFT", icon, "BOTTOMRIGHT", 6, 2)
    slotText:SetPoint("RIGHT", tab, "RIGHT", -22, 0)
    slotText:SetJustifyH("LEFT")
    slotText:SetWordWrap(false)
    slotText:SetTextColor(0.7, 0.7, 0.7)
    if item.equipSlot and item.equipSlot ~= "" then
        slotText:SetText(_G[item.equipSlot] or item.equipSlot)
    else
        slotText:SetText("")
    end
    tab.slotText = slotText

    -- State indicator (14x14, bottom-right of card)
    local stateIndicator = tab:CreateTexture(nil, "OVERLAY", nil, 6)
    stateIndicator:SetSize(14, 14)
    stateIndicator:SetPoint("BOTTOMRIGHT", -2, 2)
    tab.stateIndicator = stateIndicator

    if item.state == Loothing.ItemState.AWARDED then
        stateIndicator:SetTexture("Interface\\RaidFrame\\ReadyCheck-Ready")
    elseif item.state == Loothing.ItemState.VOTING then
        stateIndicator:SetTexture("Interface\\COMMON\\Indicator-Green")
    elseif item.state == Loothing.ItemState.SKIPPED then
        stateIndicator:SetTexture("Interface\\RaidFrame\\ReadyCheck-NotReady")
    else
        stateIndicator:Hide()
    end

    -- Voted checkmark (14x14, top-right of card)
    local votedCheck = tab:CreateTexture(nil, "OVERLAY", nil, 7)
    votedCheck:SetSize(14, 14)
    votedCheck:SetPoint("TOPRIGHT", -2, -2)
    votedCheck:SetTexture("Interface\\RaidFrame\\ReadyCheck-Ready")
    votedCheck:Hide()
    tab.votedCheck = votedCheck

    -- Gold selection bar (full width bottom)
    local selectBar = tab:CreateTexture(nil, "OVERLAY", nil, 7)
    selectBar:SetHeight(2)
    selectBar:SetPoint("BOTTOMLEFT", 1, 1)
    selectBar:SetPoint("BOTTOMRIGHT", -1, 1)
    selectBar:SetColorTexture(1, 0.82, 0, 1)
    selectBar:Hide()
    tab.selectBar = selectBar

    -- Highlight texture
    local highlight = tab:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetAllPoints()
    highlight:SetTexture("Interface\\Buttons\\ButtonHilight-Square")
    highlight:SetAlpha(0.15)
    highlight:SetBlendMode("ADD")

    -- Quality border default
    tab:SetBackdropBorderColor(qr, qg, qb, 1)
    tab.quality = quality

    -- Tooltip
    tab:SetScript("OnEnter", function()
        GameTooltip:SetOwner(tab, "ANCHOR_BOTTOM")
        if item.itemLink then
            GameTooltip:SetHyperlink(item.itemLink)
        else
            GameTooltip:AddLine(item.name or "Unknown Item")
        end
        GameTooltip:Show()
    end)
    tab:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    -- Click to switch
    tab:SetScript("OnClick", function()
        self:SelectItemTab(item.guid)
    end)

    tab:Show()
    return tab
end

function CouncilTableMixin:SelectItemTab(itemGUID)
    -- Find item and its index
    local targetItem = nil
    local targetIndex = nil
    for i, item in ipairs(self.items) do
        if item.guid == itemGUID then
            targetItem = item
            targetIndex = i
            break
        end
    end

    if not targetItem then return end

    self.currentItem = targetItem
    self.selectedCandidate = nil
    self:HideDetailTooltip()

    -- Update tab visuals based on selection + item state
    for i, tab in ipairs(self.itemTabs) do
        local item = self.items[i]
        if not item then break end

        local q = item.quality or 1
        local qr, qg, qb = C_Item.GetItemQualityColor(q)

        if item.guid == itemGUID then
            -- Selected state: gold border, blue-shift bg, full alpha, glow up
            tab.selectBar:Show()
            tab:SetBackdropBorderColor(1, 0.82, 0, 1)
            tab:SetBackdropColor(0.15, 0.15, 0.25, 1)
            tab.icon:SetAlpha(1.0)
            tab.icon:SetDesaturated(false)
            tab.glow:SetAlpha(0.6)
            tab.accentBar:SetVertexColor(1, 0.82, 0, 1)
        elseif item.state == Loothing.ItemState.AWARDED then
            -- Awarded: green tint, desaturated
            tab.selectBar:Hide()
            tab:SetBackdropBorderColor(0.2, 0.8, 0.2, 1)
            tab:SetBackdropColor(0.05, 0.12, 0.05, 0.9)
            tab.icon:SetAlpha(0.5)
            tab.icon:SetDesaturated(true)
            tab.glow:SetAlpha(0.2)
            tab.accentBar:SetVertexColor(0.2, 0.8, 0.2, 1)
        elseif item.state == Loothing.ItemState.SKIPPED then
            -- Skipped: gray, dim, desaturated
            tab.selectBar:Hide()
            tab:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
            tab:SetBackdropColor(0.06, 0.06, 0.06, 0.7)
            tab.icon:SetAlpha(0.35)
            tab.icon:SetDesaturated(true)
            tab.glow:SetAlpha(0.1)
            tab.accentBar:SetVertexColor(0.4, 0.4, 0.4, 1)
        elseif item.state == Loothing.ItemState.VOTING then
            -- Voting: quality color, full alpha
            tab.selectBar:Hide()
            tab:SetBackdropBorderColor(qr, qg, qb, 1)
            tab:SetBackdropColor(0.08, 0.08, 0.12, 0.9)
            tab.icon:SetAlpha(1.0)
            tab.icon:SetDesaturated(false)
            tab.glow:SetAlpha(0.4)
            tab.accentBar:SetVertexColor(qr, qg, qb, 1)
        else
            -- Pending: quality at half alpha
            tab.selectBar:Hide()
            tab:SetBackdropBorderColor(qr, qg, qb, 0.5)
            tab:SetBackdropColor(0.08, 0.08, 0.12, 0.9)
            tab.icon:SetAlpha(0.7)
            tab.icon:SetDesaturated(false)
            tab.glow:SetAlpha(0.3)
            tab.accentBar:SetVertexColor(qr, qg, qb, 0.5)
        end
    end

    -- Auto-scroll selected tab into view
    if targetIndex and self.itemTabClip then
        local tabLeft = (targetIndex - 1) * SCROLL_STEP
        local tabRight = tabLeft + ITEM_TAB_WIDTH
        local clipWidth = self.itemTabClip:GetWidth()

        if tabLeft < self.scrollOffset then
            self:ScrollTo(tabLeft)
        elseif tabRight > self.scrollOffset + clipWidth then
            self:ScrollTo(tabRight - clipWidth)
        end
    end

    -- Update title
    if self.titleText then
        local name = targetItem.name or "Unknown"
        self.titleText:SetText(string.format(L["LOOT_COUNCIL"] .. " - %s", name))
    end

    -- Refresh candidates
    self:ThrottledRefresh()

    -- Update action buttons
    self:UpdateActionButtons()

    -- Update voter progress
    self:UpdateVoterProgress()

    self:TriggerEvent("OnItemTabChanged", targetItem)
end

function CouncilTableMixin:SelectFirstItem()
    if #self.items > 0 then
        self:SelectItemTab(self.items[1].guid)
    end
end

--[[--------------------------------------------------------------------
    Scroll Helpers
----------------------------------------------------------------------]]

function CouncilTableMixin:GetMaxScrollOffset()
    if not self.itemTabClip or not self.itemTabContent then return 0 end
    local contentWidth = self.itemTabContent:GetWidth()
    local clipWidth = self.itemTabClip:GetWidth()
    return math.max(0, contentWidth - clipWidth)
end

function CouncilTableMixin:ScrollTo(targetOffset)
    local maxOffset = self:GetMaxScrollOffset()
    targetOffset = math.max(0, math.min(targetOffset, maxOffset))
    self.scrollOffset = targetOffset
    self.itemTabContent:ClearAllPoints()
    self.itemTabContent:SetPoint("TOPLEFT", -targetOffset, 0)
    self:UpdateScrollArrows()
end

function CouncilTableMixin:UpdateScrollArrows()
    if not self.itemTabClip then return end

    local maxOffset = self:GetMaxScrollOffset()
    local needsScroll = maxOffset > 0

    if needsScroll then
        self.scrollLeftArrow:Show()
        self.scrollRightArrow:Show()

        if self.scrollOffset <= 0 then
            self.scrollLeftArrow:Disable()
        else
            self.scrollLeftArrow:Enable()
        end

        if self.scrollOffset >= maxOffset then
            self.scrollRightArrow:Disable()
        else
            self.scrollRightArrow:Enable()
        end
    else
        self.scrollLeftArrow:Hide()
        self.scrollRightArrow:Hide()
    end
end

--[[--------------------------------------------------------------------
    Candidate List (Scrollable)
----------------------------------------------------------------------]]

function CouncilTableMixin:CreateCandidateList()
    local container = CreateFrame("Frame", nil, self.frame, "BackdropTemplate")
    container:SetPoint("TOPLEFT", 16, -121)
    container:SetPoint("BOTTOMRIGHT", -16, 50)
    container:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        tile = false, edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    container:SetBackdropColor(0.04, 0.04, 0.06, 0.9)
    container:SetBackdropBorderColor(0.2, 0.2, 0.2, 1)

    local scrollFrame = CreateFrame("ScrollFrame", nil, container, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 2, -2)
    scrollFrame:SetPoint("BOTTOMRIGHT", -22, 2)

    local content = CreateFrame("Frame", nil, scrollFrame)
    content:SetSize(1, 800) -- width managed by OnSizeChanged below
    scrollFrame:SetScrollChild(content)

    -- Keep scroll child width in sync with scroll frame
    scrollFrame:SetScript("OnSizeChanged", function(_, w)
        content:SetWidth(w)
    end)

    self.listContainer = container
    self.listContent = content
    self.scrollFrame = scrollFrame
end

--[[--------------------------------------------------------------------
    Detail Tooltip (floating panel, anchored to right edge of frame)
----------------------------------------------------------------------]]

local DETAIL_TOOLTIP_WIDTH = 220

function CouncilTableMixin:CreateDetailTooltip()
    local tooltip = CreateFrame("Frame", nil, self.frame, "BackdropTemplate")
    tooltip:SetWidth(DETAIL_TOOLTIP_WIDTH)
    tooltip:SetPoint("TOPLEFT", self.frame, "TOPRIGHT", 6, 0)
    tooltip:SetPoint("BOTTOMLEFT", self.frame, "BOTTOMRIGHT", 6, 0)
    tooltip:SetFrameStrata("DIALOG")
    tooltip:SetFrameLevel(self.frame:GetFrameLevel() + 10)
    tooltip:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        tile = false, edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    tooltip:SetBackdropColor(0.06, 0.06, 0.08, 0.95)
    tooltip:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)
    tooltip:SetClampedToScreen(true)
    tooltip:Hide()

    -- Close/unpin button (top-right corner)
    local closeBtn = CreateFrame("Button", nil, tooltip)
    closeBtn:SetSize(14, 14)
    closeBtn:SetPoint("TOPRIGHT", -4, -4)
    closeBtn:SetNormalTexture("Interface\\Buttons\\UI-StopButton")
    closeBtn:SetHighlightTexture("Interface\\Buttons\\UI-StopButton", "ADD")
    closeBtn:SetScript("OnClick", function()
        self:HideDetailTooltip()
        self.selectedCandidate = nil
        self:RefreshCandidates()
    end)

    -- Scroll frame so content can exceed tooltip height
    local scrollFrame = CreateFrame("ScrollFrame", nil, tooltip, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 2, -2)
    scrollFrame:SetPoint("BOTTOMRIGHT", -18, 2)

    local content = CreateFrame("Frame", nil, scrollFrame)
    content:SetWidth(DETAIL_TOOLTIP_WIDTH - 40)
    content:SetHeight(1) -- dynamic
    scrollFrame:SetScrollChild(content)
    self.detailContent = content
    self.detailScrollFrame = scrollFrame

    -- Name
    local name = content:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    name:SetPoint("TOPLEFT", 6, -6)
    name:SetPoint("RIGHT", -6, 0)
    name:SetWordWrap(false)
    self.moreInfoName = name

    -- Response
    local response = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    response:SetPoint("TOPLEFT", name, "BOTTOMLEFT", 0, -2)
    response:SetPoint("RIGHT", -6, 0)
    self.moreInfoResponse = response

    -- Details (ilvl, role, rank)
    local details = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    details:SetPoint("TOPLEFT", response, "BOTTOMLEFT", 0, -2)
    details:SetPoint("RIGHT", -6, 0)
    details:SetTextColor(0.7, 0.7, 0.7)
    details:SetWordWrap(true)
    self.moreInfoDetails = details

    -- Note
    local note = content:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    note:SetPoint("TOPLEFT", details, "BOTTOMLEFT", 0, -4)
    note:SetPoint("RIGHT", -6, 0)
    note:SetJustifyH("LEFT")
    note:SetWordWrap(true)
    self.moreInfoNote = note

    -- Gear text
    local gear = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    gear:SetPoint("TOPLEFT", note, "BOTTOMLEFT", 0, -6)
    gear:SetPoint("RIGHT", -6, 0)
    gear:SetJustifyH("LEFT")
    gear:SetTextColor(0.8, 0.8, 0.8)
    gear:SetWordWrap(true)
    self.moreInfoGear = gear

    -- Vote breakdown
    local voteBreakdown = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    voteBreakdown:SetPoint("TOPLEFT", gear, "BOTTOMLEFT", 0, -6)
    voteBreakdown:SetPoint("RIGHT", -6, 0)
    voteBreakdown:SetJustifyH("LEFT")
    voteBreakdown:SetTextColor(0.6, 0.8, 0.6)
    voteBreakdown:SetWordWrap(true)
    self.moreInfoVoteBreakdown = voteBreakdown

    -- Wishlist info
    local wishlistInfo = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    wishlistInfo:SetPoint("TOPLEFT", voteBreakdown, "BOTTOMLEFT", 0, -4)
    wishlistInfo:SetPoint("RIGHT", -6, 0)
    wishlistInfo:SetJustifyH("LEFT")
    wishlistInfo:SetWordWrap(true)
    self.moreInfoWishlist = wishlistInfo

    -- Item source
    local sourceInfo = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    sourceInfo:SetPoint("TOPLEFT", wishlistInfo, "BOTTOMLEFT", 0, -2)
    sourceInfo:SetPoint("RIGHT", -6, 0)
    sourceInfo:SetJustifyH("LEFT")
    sourceInfo:SetTextColor(0.6, 0.6, 0.6)
    sourceInfo:SetWordWrap(true)
    self.moreInfoSource = sourceInfo

    -- ===== Player Intel Section (from desktop sync) =====

    -- Separator line
    local intelSep = content:CreateTexture(nil, "ARTWORK")
    intelSep:SetPoint("TOPLEFT", sourceInfo, "BOTTOMLEFT", 0, -6)
    intelSep:SetPoint("RIGHT", -6, 0)
    intelSep:SetHeight(1)
    intelSep:SetColorTexture(0.3, 0.3, 0.3, 0.6)
    self.moreInfoIntelSep = intelSep

    -- M+ Activity
    local mpInfo = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    mpInfo:SetPoint("TOPLEFT", intelSep, "BOTTOMLEFT", 0, -4)
    mpInfo:SetPoint("RIGHT", -6, 0)
    mpInfo:SetJustifyH("LEFT")
    mpInfo:SetTextColor(0.4, 0.8, 1.0)
    mpInfo:SetWordWrap(true)
    self.moreInfoMythicPlus = mpInfo

    -- Parse Performance
    local parseInfo = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    parseInfo:SetPoint("TOPLEFT", mpInfo, "BOTTOMLEFT", 0, -2)
    parseInfo:SetPoint("RIGHT", -6, 0)
    parseInfo:SetJustifyH("LEFT")
    parseInfo:SetTextColor(1.0, 0.8, 0.4)
    parseInfo:SetWordWrap(true)
    self.moreInfoParses = parseInfo

    -- Attendance
    local attendInfo = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    attendInfo:SetPoint("TOPLEFT", parseInfo, "BOTTOMLEFT", 0, -2)
    attendInfo:SetPoint("RIGHT", -6, 0)
    attendInfo:SetJustifyH("LEFT")
    attendInfo:SetTextColor(0.7, 0.7, 0.7)
    attendInfo:SetWordWrap(true)
    self.moreInfoAttendance = attendInfo

    -- Gear Readiness
    local gearReady = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    gearReady:SetPoint("TOPLEFT", attendInfo, "BOTTOMLEFT", 0, -2)
    gearReady:SetPoint("RIGHT", -6, 0)
    gearReady:SetJustifyH("LEFT")
    gearReady:SetTextColor(0.7, 0.8, 0.7)
    gearReady:SetWordWrap(true)
    self.moreInfoGearReady = gearReady

    -- Recent Loot History
    local lootHistory = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    lootHistory:SetPoint("TOPLEFT", gearReady, "BOTTOMLEFT", 0, -4)
    lootHistory:SetPoint("RIGHT", -6, 0)
    lootHistory:SetJustifyH("LEFT")
    lootHistory:SetWordWrap(true)
    lootHistory:SetTextColor(0.8, 0.8, 0.8)
    self.moreInfoLootHistory = lootHistory

    -- Alt Loot Summary
    local altLoot = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    altLoot:SetPoint("TOPLEFT", lootHistory, "BOTTOMLEFT", 0, -2)
    altLoot:SetPoint("RIGHT", -6, 0)
    altLoot:SetJustifyH("LEFT")
    altLoot:SetWordWrap(true)
    altLoot:SetTextColor(0.7, 0.7, 0.9)
    self.moreInfoAltLoot = altLoot

    -- Staleness indicator
    local staleness = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    staleness:SetPoint("TOPLEFT", altLoot, "BOTTOMLEFT", 0, -4)
    staleness:SetPoint("RIGHT", -6, 0)
    staleness:SetJustifyH("RIGHT")
    staleness:SetTextColor(0.5, 0.5, 0.5)
    self.moreInfoStaleness = staleness

    self.detailTooltip = tooltip
    self.tooltipPinned = false
end

--- Recalculate the scroll content height so the scroll frame
--- can accommodate all visible text. Deferred one frame so
--- font string layouts are finalized.
function CouncilTableMixin:ResizeDetailTooltip()
    if not self.detailTooltip or not self.detailContent then return end

    C_Timer.After(0, function()
        if not self.detailTooltip:IsShown() then return end

        local contentTop = self.detailContent:GetTop()
        local lastBottom = self.moreInfoStaleness and self.moreInfoStaleness:GetBottom()

        local contentHeight
        if contentTop and lastBottom then
            contentHeight = contentTop - lastBottom + 12
        else
            contentHeight = 600
        end
        self.detailContent:SetHeight(math.max(contentHeight, 100))
    end)
end

function CouncilTableMixin:HideDetailTooltip()
    if self.detailTooltip then
        self.detailTooltip:Hide()
    end
    if self.detailScrollFrame then
        self.detailScrollFrame:SetVerticalScroll(0)
    end
    self.tooltipPinned = false
end

--[[--------------------------------------------------------------------
    Action Buttons (ML controls)
----------------------------------------------------------------------]]

function CouncilTableMixin:CreateActionButtons()
    local footer = CreateFrame("Frame", nil, self.frame)
    footer:SetPoint("BOTTOMLEFT", 16, 12)
    footer:SetPoint("BOTTOMRIGHT", -16, 12)
    footer:SetHeight(28)

    -- Award button
    self.awardButton = CreateFrame("Button", nil, footer, "UIPanelButtonTemplate")
    self.awardButton:SetSize(100, 24)
    self.awardButton:SetPoint("LEFT")
    self.awardButton:SetText(L["COUNCIL_AWARD"])
    self.awardButton:SetScript("OnClick", function()
        if self.selectedCandidate and self.currentItem then
            self:ShowCandidateContextMenu(self.awardButton, self.selectedCandidate)
        end
    end)

    -- Revote button
    self.revoteButton = CreateFrame("Button", nil, footer, "UIPanelButtonTemplate")
    self.revoteButton:SetSize(80, 24)
    self.revoteButton:SetPoint("LEFT", self.awardButton, "RIGHT", 8, 0)
    self.revoteButton:SetText(L["COUNCIL_REVOTE"])
    self.revoteButton:SetScript("OnClick", function()
        if self.currentItem and Loothing.Session then
            Loothing.Session:StartVoting(self.currentItem.guid)
            self:RefreshCandidates()
        end
    end)

    -- Skip button
    self.skipButton = CreateFrame("Button", nil, footer, "UIPanelButtonTemplate")
    self.skipButton:SetSize(80, 24)
    self.skipButton:SetPoint("LEFT", self.revoteButton, "RIGHT", 8, 0)
    self.skipButton:SetText(L["COUNCIL_SKIP"])
    self.skipButton:SetScript("OnClick", function()
        if self.currentItem and Loothing.Session then
            Loothing.Session:SkipItem(self.currentItem.guid)
        end
    end)

    -- Results button (view results panel for current item)
    self.resultsButton = CreateFrame("Button", nil, footer, "UIPanelButtonTemplate")
    self.resultsButton:SetSize(80, 24)
    self.resultsButton:SetPoint("RIGHT", -4, 0)
    self.resultsButton:SetText(L["RESULTS"])
    self.resultsButton:SetScript("OnClick", function()
        if self.currentItem and Loothing.UI and Loothing.UI.ResultsPanel then
            Loothing.UI.ResultsPanel:SetItem(self.currentItem)
            Loothing.UI.ResultsPanel:Show()
        end
    end)

    self.actionFooter = footer
end

function CouncilTableMixin:UpdateActionButtons()
    local isML = Loothing.Session and Loothing.Session:IsMasterLooter()

    -- Observer indicator
    if self.observerText then
        if IsObserverOnly() then
            self.observerText:Show()
        else
            self.observerText:Hide()
        end
    end

    -- Enchanter button (ML only)
    if self.enchanterBtn then
        if isML then
            self.enchanterBtn:Show()
        else
            self.enchanterBtn:Hide()
        end
    end

    -- Results button (visible to anyone when an item is selected)
    if self.resultsButton then
        if self.currentItem and Loothing.UI and Loothing.UI.ResultsPanel then
            self.resultsButton:Show()
        else
            self.resultsButton:Hide()
        end
    end

    if not isML or not self.currentItem then
        self.awardButton:Hide()
        self.revoteButton:Hide()
        self.skipButton:Hide()
        return
    end

    self.awardButton:Show()
    self.revoteButton:Show()
    self.skipButton:Show()

    local state = self.currentItem.state

    if state == Loothing.ItemState.AWARDED or state == Loothing.ItemState.SKIPPED then
        self.awardButton:Disable()
        self.revoteButton:Enable()
        self.skipButton:Disable()
    elseif state == Loothing.ItemState.TALLIED then
        self.awardButton:Enable()
        self.revoteButton:Enable()
        self.skipButton:Enable()
    elseif state == Loothing.ItemState.VOTING then
        self.awardButton:Disable()
        self.revoteButton:Disable()
        self.skipButton:Enable()
    else
        self.awardButton:Disable()
        self.revoteButton:Disable()
        self.skipButton:Disable()
    end

    -- Award requires selection
    if not self.selectedCandidate then
        self.awardButton:Disable()
    end
end

--[[--------------------------------------------------------------------
    Enchanter Button & Dropdown
----------------------------------------------------------------------]]

function CouncilTableMixin:CreateEnchanterButton()
    local btn = CreateFrame("Button", nil, self.actionFooter)
    btn:SetSize(24, 24)
    btn:SetPoint("LEFT", self.skipButton, "RIGHT", 12, 0)
    btn:SetNormalTexture("Interface\\Icons\\Trade_Engraving")
    btn:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square")
    btn:SetScript("OnClick", function()
        self:ShowEnchanterDropdown(btn)
    end)
    btn:SetScript("OnEnter", function(b)
        GameTooltip:SetOwner(b, "ANCHOR_RIGHT")
        GameTooltip:SetText(L["DISENCHANT_TARGET"], 1, 1, 1)
        GameTooltip:AddLine(L["CLICK_SELECT_ENCHANTER"], 1, 1, 1)
        if self.disenchantTarget then
            GameTooltip:AddLine(L["CURRENT_COLON"] .. self.disenchantTarget, 0.5, 1, 0.5)
        end
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", GameTooltip_Hide)
    btn:Hide()
    self.enchanterBtn = btn
end

function CouncilTableMixin:ShowEnchanterDropdown(anchor)
    local enchanters = Loothing.PlayerCache and Loothing.PlayerCache:GetEnchanters() or {}
    if #enchanters == 0 then
        Loothing:Print(L["NO_ENCHANTERS"])
        return
    end

    MenuUtil.CreateContextMenu(anchor, function(_, rootDescription)
        rootDescription:CreateTitle(L["SELECT_ENCHANTER"])
        for _, enc in ipairs(enchanters) do
            local classColor = RAID_CLASS_COLORS and RAID_CLASS_COLORS[enc.class] or { r = 1, g = 1, b = 1 }
            local coloredName = string.format("|cff%02x%02x%02x%s|r",
                classColor.r * 255, classColor.g * 255, classColor.b * 255, enc.name)
            rootDescription:CreateButton(coloredName, function()
                self.disenchantTarget = enc.name
                Loothing:Print(string.format(L["DISENCHANT_TARGET_SET"], enc.name))
            end)
        end
        rootDescription:CreateDivider()
        rootDescription:CreateButton(L["CLEAR"], function()
            self.disenchantTarget = nil
            Loothing:Print(L["DISENCHANT_TARGET_CLEARED"])
        end)
    end)
end

--[[--------------------------------------------------------------------
    Voter Progress Indicator
----------------------------------------------------------------------]]

function CouncilTableMixin:CreateVoterProgressUI()
    local progressText = self.frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    progressText:SetPoint("TOPRIGHT", self.itemTabBar, "TOPRIGHT", -4, -2)
    progressText:SetJustifyH("RIGHT")
    self.voterProgressText = progressText

    -- Invisible button over text for hover tooltip
    local hoverBtn = CreateFrame("Button", nil, self.frame)
    hoverBtn:SetPoint("TOPLEFT", progressText, "TOPLEFT", -4, 4)
    hoverBtn:SetPoint("BOTTOMRIGHT", progressText, "BOTTOMRIGHT", 4, -4)
    hoverBtn:SetScript("OnEnter", function(btn)
        self:ShowVoterProgressTooltip(btn)
    end)
    hoverBtn:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    self.voterProgressBtn = hoverBtn
end

function CouncilTableMixin:UpdateVoterProgress()
    if not self.voterProgressText then return end
    if not self.currentItem then
        self.voterProgressText:SetText("")
        return
    end

    local expectedVoters = Loothing.Council and Loothing.Council:GetVotingEligibleMembers() or {}
    local totalExpected = #expectedVoters

    -- Count unique voters on this item
    local votedCount = 0
    if totalExpected > 0 then
        local voterSet = {}
        for _, vote in self.currentItem:GetVotes():Enumerate() do
            voterSet[vote.voter] = true
        end
        for _, member in ipairs(expectedVoters) do
            if voterSet[member] then
                votedCount = votedCount + 1
            end
        end
    end

    local text = string.format("%d of %d voted", votedCount, totalExpected)
    self.voterProgressText:SetText(text)

    if totalExpected > 0 and votedCount >= totalExpected then
        self.voterProgressText:SetTextColor(0.2, 1, 0.2)
    else
        self.voterProgressText:SetTextColor(1, 0.82, 0)
    end

    -- Resize hover button to match text
    if self.voterProgressBtn then
        self.voterProgressBtn:SetSize(
            self.voterProgressText:GetStringWidth() + 8,
            self.voterProgressText:GetStringHeight() + 8
        )
    end
end

function CouncilTableMixin:ShowVoterProgressTooltip(anchor)
    if not self.currentItem then return end

    local expectedVoters = Loothing.Council and Loothing.Council:GetVotingEligibleMembers() or {}
    if #expectedVoters == 0 then return end

    -- Build set of who has voted
    local voterSet = {}
    for _, vote in self.currentItem:GetVotes():Enumerate() do
        voterSet[vote.voter] = true
    end

    GameTooltip:SetOwner(anchor, "ANCHOR_BOTTOM")
    GameTooltip:AddLine(L["COUNCIL_VOTING_PROGRESS"], 1, 0.82, 0)
    GameTooltip:AddLine(" ")

    for _, member in ipairs(expectedVoters) do
        local hasVoted = voterSet[member] or false
        local shortName = member:match("^([^%-]+)") or member

        -- Class-color the name
        local nameText = shortName
        if Loothing.PlayerCache then
            local info = Loothing.PlayerCache:Get(member)
            if info and info.class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[info.class] then
                local cc = RAID_CLASS_COLORS[info.class]
                nameText = string.format("|cff%02x%02x%02x%s|r", cc.r * 255, cc.g * 255, cc.b * 255, shortName)
            end
        end

        local icon = hasVoted
            and "|TInterface\\RaidFrame\\ReadyCheck-Ready:0|t "
            or "|TInterface\\RaidFrame\\ReadyCheck-NotReady:0|t "
        GameTooltip:AddLine(icon .. nameText)
    end

    GameTooltip:Show()
end

--[[--------------------------------------------------------------------
    Item Tab Voted Indicators
----------------------------------------------------------------------]]

function CouncilTableMixin:UpdateItemTabVotedIndicators()
    if not self.items or not self.itemTabs then return end

    local myName = Utils.GetPlayerFullName()

    for i, tab in ipairs(self.itemTabs) do
        local item = self.items[i]
        if item and tab.votedCheck then
            local hasVoted = item:HasVoted(myName)
            if hasVoted then
                tab.votedCheck:Show()
            else
                tab.votedCheck:Hide()
            end
        end
    end
end

function CouncilTableMixin:CreateFramePools()
    self.rowPool = CreateFramePool("Button", self.listContent, "BackdropTemplate", function(_, frame)
        frame:Hide()
        frame:ClearAllPoints()
        frame.candidate = nil
        frame.rowIndex = nil
    end)
end

--[[--------------------------------------------------------------------
    Clear
----------------------------------------------------------------------]]

function CouncilTableMixin:Clear()
    self.items = {}
    self.currentItem = nil
    self.selectedCandidate = nil

    for _, tab in ipairs(self.itemTabs) do
        tab:Hide()
    end
    wipe(self.itemTabs)

    if self.rowPool then
        self.rowPool:ReleaseAll()
    end

    if self.emptyText then
        self.emptyText:Show()
    end
    self:HideDetailTooltip()

    self:UpdateActionButtons()
end

--[[--------------------------------------------------------------------
    Resize
----------------------------------------------------------------------]]

function CouncilTableMixin:OnResize()
    self:RebuildColumnHeaders()
    self:RefreshCandidates()
    self:UpdateScrollArrows()
end

--[[--------------------------------------------------------------------
    Position Persistence
----------------------------------------------------------------------]]

function CouncilTableMixin:SavePosition()
    SkinningMixin:SaveFrameState(self.frame, "CouncilTable")
end

function CouncilTableMixin:LoadPosition()
    SkinningMixin:LoadFrameState(self.frame, "CouncilTable")
end

-- Show/Hide/Toggle
function CouncilTableMixin:Show()
    self:HideDetailTooltip()
    self:LoadPosition()
    self.frame:Show()
    self.frame:Raise()
    self:RebuildColumnHeaders()
    self:RefreshItemTabs()
    self:RefreshCandidates()
    self:UpdateActionButtons()
end

function CouncilTableMixin:Hide()
    self.frame:Hide()
end

function CouncilTableMixin:Toggle()
    if self.frame:IsShown() then self:Hide() else self:Show() end
end

local function CreateCouncilTable(parent)
    local tbl = Loolib.CreateFromMixins(CouncilTableMixin)
    tbl:Init(parent)
    return tbl
end

ns.CreateCouncilTable = CreateCouncilTable
