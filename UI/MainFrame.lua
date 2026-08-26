--[[--------------------------------------------------------------------
    Loothing - Loot Council Addon for WoW 12.0+
    MainFrame - Primary addon window with tabbed interface
----------------------------------------------------------------------]]

local _, ns = ...
local Loolib = LibStub("Loolib")
local Loothing = ns.Addon
local SkinningMixin = ns.SkinningMixin

local AnimationUtil = Loolib.AnimationUtil
local AnimationPresets = Loolib.AnimationPresets
local PixelUtil = Loolib.PixelUtil

--[[--------------------------------------------------------------------
    MainFrameMixin
----------------------------------------------------------------------]]

local MainFrameMixin = ns.MainFrameMixin or Loolib.CreateFromMixins(Loolib.CallbackRegistryMixin)
ns.MainFrameMixin = MainFrameMixin

local MAIN_FRAME_EVENTS = {
    "OnShow",
    "OnHide",
    "OnTabSelected",
}

local FRAME_WIDTH = 600
local FRAME_HEIGHT = 500
local TAB_HEIGHT = 32

-- Animation durations
local SHOW_DURATION = 0.22
local HIDE_DURATION = 0.13
local TAB_FADE_OUT = 0.13
local TAB_FADE_IN = 0.22
local TAB_FADE_STAGGER = 0.05
local TAB_HOVER_DURATION = 0.15
local INDICATOR_SLIDE_DURATION = 0.22

local function unpackColor(color)
    if type(color) ~= "table" then return 1, 1, 1, 1 end
    return color[1] or 1, color[2] or 1, color[3] or 1, color[4] or 1
end

local function cloneColor(color)
    if type(color) ~= "table" then return { 1, 1, 1, 1 } end
    return { color[1] or 1, color[2] or 1, color[3] or 1, color[4] or 1 }
end

local ApplyAccentGlow = ns.FramePolish.ApplyAccentGlow
local AttachIconButtonPolish = ns.FramePolish.AttachIconButtonPolish
function MainFrameMixin:Init()
    Loolib.CallbackRegistryMixin.OnLoad(self)
    self:GenerateCallbackEvents(MAIN_FRAME_EVENTS)

    self.tabs = {}
    self.panels = {}
    self.currentTab = nil

    self:CreateFrame()
    self:CreateTabs()
    self:CreatePanels()
    self:LoadPosition()
    self:ApplyTheme()
end

--- Create the main frame
function MainFrameMixin:CreateFrame()
    local frame = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    frame:SetSize(FRAME_WIDTH, FRAME_HEIGHT)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("HIGH")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:SetClampedToScreen(true)
    frame:SetResizable(true)
    frame:SetResizeBounds(500, 400, 900, 700)
    frame:Hide()

    -- Apply skin via SkinningMixin
    SkinningMixin:SetupFrame(frame, "MainFrame", "LoothingMainFrame", {
        combatMinimize = true,
        ctrlScroll = true,
        escapeClose = true,
    })
    ns.MainFrameFrame = frame

    -- Start hidden-alpha so the first Show() can fade in
    frame:SetAlpha(0)

    -- Accent glow strip: a subtle fade-from-accent-to-transparent behind the title.
    -- Color is sourced from SkinningMixin's current accent, so it tracks Frame Behavior settings.
    local headerStrip = frame:CreateTexture(nil, "BACKGROUND", nil, 2)
    headerStrip:SetPoint("TOPLEFT", 2, -2)
    headerStrip:SetPoint("TOPRIGHT", -2, -2)
    headerStrip:SetHeight(40)
    headerStrip:SetColorTexture(1, 1, 1, 1)
    self.headerStrip = headerStrip
    ApplyAccentGlow(headerStrip, 0.18)

    -- Pixel-perfect outer border: color is refreshed from SkinningMixin in ApplyTheme.
    if PixelUtil and type(PixelUtil.SetThinBorder) == "function" then
        self.pixelBorder = PixelUtil.SetThinBorder(frame, SkinningMixin:GetColor("borderStrong"))
    end

    -- Title
    self.titleText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    self.titleText:SetPoint("TOPLEFT", 20, -14)
    self.titleText:SetText("Loothing")
    SkinningMixin:StyleText(self.titleText, "title", "text")

    -- Version
    self.versionText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    self.versionText:SetPoint("LEFT", self.titleText, "RIGHT", 8, -1)
    self.versionText:SetText("v" .. (Loothing.VERSION or "1.0.0"))
    SkinningMixin:StyleText(self.versionText, "bodySmall", "textMuted")

    -- Close button
    self.closeButton = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    self.closeButton:SetPoint("TOPRIGHT", -5, -5)
    self.closeButton:SetScript("OnClick", function()
        self:Hide()
    end)
    AttachIconButtonPolish(self.closeButton, { hoverScale = 1.15, pressScale = 0.90 })

    -- Settings button (gear icon)
    self.settingsButton = CreateFrame("Button", nil, frame)
    self.settingsButton:SetSize(24, 24)
    self.settingsButton:SetPoint("RIGHT", self.closeButton, "LEFT", -4, 0)
    self.settingsButton:SetNormalTexture("Interface\\Buttons\\UI-OptionsButton")
    self.settingsButton:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
    self.settingsButton:SetScript("OnClick", function()
        self:OpenSettings()
    end)
    self.settingsButton:SetScript("OnEnter", function(btn)
        GameTooltip:SetOwner(btn, "ANCHOR_TOP")
        GameTooltip:SetText(Loothing.Locale["TAB_SETTINGS"], 1, 1, 1)
        GameTooltip:Show()
    end)
    self.settingsButton:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    AttachIconButtonPolish(self.settingsButton, { hoverScale = 1.12, pressScale = 0.92, rotateOnHover = true })

    -- Title bar for dragging
    local titleBar = CreateFrame("Frame", nil, frame)
    titleBar:SetPoint("TOPLEFT", 40, -8)
    titleBar:SetPoint("TOPRIGHT", -40, -8)
    titleBar:SetHeight(32)
    titleBar:EnableMouse(true)
    titleBar:RegisterForDrag("LeftButton")
    titleBar:SetScript("OnDragStart", function()
        frame:StartMoving()
    end)
    titleBar:SetScript("OnDragStop", function()
        frame:StopMovingOrSizing()
        self:SavePosition()
    end)

    -- Desktop sync status (near title bar, right side)
    local syncText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    syncText:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -80, -18)
    syncText:SetTextColor(0.5, 0.5, 0.5)
    self.desktopSyncText = syncText
    SkinningMixin:StyleText(syncText, "bodySmall", "textSubtle")
    self:UpdateDesktopSyncStatus()

    -- Resize grip
    local resizeGrip = CreateFrame("Button", nil, frame)
    resizeGrip:SetSize(16, 16)
    resizeGrip:SetPoint("BOTTOMRIGHT", -8, 8)
    resizeGrip:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    resizeGrip:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
    resizeGrip:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
    resizeGrip:SetScript("OnMouseDown", function()
        frame:StartSizing("BOTTOMRIGHT")
    end)
    resizeGrip:SetScript("OnMouseUp", function()
        frame:StopMovingOrSizing()
        self:SavePosition()
        self:OnResize()
    end)

    -- Tab container
    self.tabContainer = CreateFrame("Frame", nil, frame)
    self.tabContainer:SetPoint("TOPLEFT", 16, -48)
    self.tabContainer:SetPoint("TOPRIGHT", -16, -48)
    self.tabContainer:SetHeight(TAB_HEIGHT + 6)

    -- Shared selection indicator that slides between tabs
    local indicator = self.tabContainer:CreateTexture(nil, "OVERLAY", nil, 7)
    indicator:SetHeight(3)
    indicator:SetPoint("BOTTOMLEFT", self.tabContainer, "BOTTOMLEFT", 2, 2)
    indicator:SetWidth(0)
    indicator:SetColorTexture(1, 1, 1, 1)
    indicator:Hide()
    self.tabIndicator = indicator

    local tabDivider = SkinningMixin:CreateDivider(frame, "horizontal", "border", 1)
    tabDivider:SetPoint("TOPLEFT", 16, -42)
    tabDivider:SetPoint("TOPRIGHT", -16, -42)
    self.tabDivider = tabDivider

    -- Content container
    self.contentContainer = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    self.contentContainer:SetPoint("TOPLEFT", 16, -54 - TAB_HEIGHT)
    self.contentContainer:SetPoint("BOTTOMRIGHT", -16, 16)
    SkinningMixin:StyleSurface(self.contentContainer, "inset")

    self.frame = frame
end

--- Create tab buttons
function MainFrameMixin:CreateTabs()
    local L = Loothing.Locale

    local tabDefs = {
        { id = "session", name = L["TAB_SESSION"], icon = "dice-six" },
        { id = "roster",  name = L["TAB_ROSTER"],  icon = "users" },
        { id = "trade",   name = L["TAB_TRADE"],   icon = "handshake" },
        { id = "history", name = L["TAB_HISTORY"], icon = "clock-rotate-left" },
    }

    local tabWidth = 100
    local spacing = 4
    local xOffset = 0

    for _, def in ipairs(tabDefs) do
        local tab = self:CreateTab(def.id, def.name, xOffset, def.icon)
        self.tabs[def.id] = tab
        xOffset = xOffset + tabWidth + spacing
    end
end

--- Create a single tab button
-- @param id string - Tab identifier
-- @param name string - Display name
-- @param xOffset number
-- @param iconName string|nil - Loolib icon name for the tab's leading glyph
-- @return Frame
function MainFrameMixin:CreateTab(id, name, xOffset, iconName)
    local tab = CreateFrame("Button", nil, self.tabContainer, "BackdropTemplate")
    tab:SetSize(100, TAB_HEIGHT - 4)
    tab:SetPoint("BOTTOMLEFT", xOffset, 0)
    SkinningMixin:StyleSurface(tab, "alt")

    -- Background (managed by backdrop now)
    tab.bg = tab

    -- Highlight
    local highlight = tab:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetAllPoints()
    highlight:SetColorTexture(1, 1, 1, 0.1)

    -- Selection indicator (bottom highlight bar)
    local selectBar = tab:CreateTexture(nil, "OVERLAY", nil, 7)
    selectBar:SetHeight(3)
    selectBar:SetPoint("BOTTOMLEFT", 2, 2)
    selectBar:SetPoint("BOTTOMRIGHT", -2, 2)
    selectBar:SetColorTexture(unpack(SkinningMixin:GetColor("accent")))
    selectBar:Hide()
    tab.selectBar = selectBar

    -- Selection glow background - hidden by default
    local selectGlow = tab:CreateTexture(nil, "BACKGROUND", nil, -1)
    selectGlow:SetAllPoints()
    selectGlow:SetColorTexture(unpack(SkinningMixin:GetColor("accentSoft")))
    selectGlow:Hide()
    tab.selectGlow = selectGlow

    -- Leading icon (rendered in the Loolib icon font). Anchored to the
    -- left; the text anchor shifts right to accommodate it.
    local icon
    if iconName then
        icon = tab:CreateFontString(nil, "OVERLAY")
        Loolib.Fonts:SetIconFont(icon, 12, "")
        icon:SetText(Loolib.Fonts:Icon(iconName))
        icon:SetPoint("LEFT", 10, 0)
        tab.icon = icon
    end

    -- Text (bound LEFT→icon, RIGHT→tab edge so long translated labels
    -- truncate cleanly instead of overflowing the tab backdrop).
    local text = tab:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    if icon then
        text:SetPoint("LEFT", icon, "RIGHT", 5, 0)
    else
        text:SetPoint("LEFT", 6, 0)
    end
    text:SetPoint("RIGHT", -6, 0)
    text:SetWordWrap(false)
    text:SetJustifyH(icon and "LEFT" or "CENTER")
    text:SetText(name)
    SkinningMixin:StyleText(text, "header", "textMuted")
    tab.text = text

    tab.id = id

    tab:SetScript("OnClick", function()
        self:SelectTab(id)
    end)

    -- Smooth hover color tween. Skips animating when the tab is the active one.
    tab:SetScript("OnEnter", function(btn)
        if self.currentTab ~= id then
            self:AnimateTabColors(btn, "hover")
        end
    end)
    tab:SetScript("OnLeave", function(btn)
        if self.currentTab ~= id then
            self:AnimateTabColors(btn, "idle")
        end
    end)

    return tab
end

--- Tween a tab's backdrop + border + text colors toward a named state.
--- Cancels any in-flight tween on the same tab before starting the new one.
--- @param tab Button
--- @param state string - "idle" | "hover" | "active"
function MainFrameMixin:AnimateTabColors(tab, state)
    if not tab or not AnimationUtil then return end
    -- If the frame isn't visible yet, snap colors rather than animating.
    if not self.frame or not self.frame:IsVisible() then
        -- Apply target colors directly.
        local textColorKey
        if state == "active" then
            tab:SetBackdropColor(unpack(SkinningMixin:GetColor("panel")))
            tab:SetBackdropBorderColor(unpack(SkinningMixin:GetColor("accent")))
            textColorKey = "accent"
        elseif state == "hover" then
            tab:SetBackdropColor(unpack(SkinningMixin:GetColor("rowHover")))
            tab:SetBackdropBorderColor(unpack(SkinningMixin:GetColor("borderStrong")))
            textColorKey = "text"
        else
            tab:SetBackdropColor(unpack(SkinningMixin:GetColor("panelAlt")))
            tab:SetBackdropBorderColor(unpack(SkinningMixin:GetColor("borderStrong")))
            textColorKey = "textMuted"
        end
        tab.text:SetTextColor(unpack(SkinningMixin:GetColor(textColorKey)))
        if tab.icon then tab.icon:SetTextColor(unpack(SkinningMixin:GetColor(textColorKey))) end
        return
    end

    local bgKey, borderKey, textKey
    if state == "active" then
        bgKey, borderKey, textKey = "panel", "accent", "accent"
    elseif state == "hover" then
        bgKey, borderKey, textKey = "rowHover", "borderStrong", "text"
    else
        bgKey, borderKey, textKey = "panelAlt", "borderStrong", "textMuted"
    end

    local toBg = cloneColor(SkinningMixin:GetColor(bgKey))
    local toBorder = cloneColor(SkinningMixin:GetColor(borderKey))
    local toText = cloneColor(SkinningMixin:GetColor(textKey))

    -- Read current values so we tween from the real starting point.
    -- Guards: Get* may return nothing if a color was never set; fall back to target.
    local function readColor(getter, holder, fallback)
        if type(getter) ~= "function" then return cloneColor(fallback) end
        local r, g, b, a = getter(holder)
        if r == nil or g == nil or b == nil then return cloneColor(fallback) end
        return { r, g, b, a or 1 }
    end

    local fromBg = readColor(tab.GetBackdropColor, tab, toBg)
    local fromBorder = readColor(tab.GetBackdropBorderColor, tab, toBorder)
    local fromText = readColor(tab.text.GetTextColor, tab.text, toText)

    if tab._loothingColorGroup then tab._loothingColorGroup:Stop() end

    local group = AnimationUtil.CreateGroup(tab)
    group:CreateAnimation("color", {
        target = tab,
        sink = "backdropColor",
        from = fromBg,
        to = toBg,
        duration = TAB_HOVER_DURATION,
        easing = "outQuad",
    })
    group:CreateAnimation("color", {
        target = tab,
        sink = "backdropBorderColor",
        from = fromBorder,
        to = toBorder,
        duration = TAB_HOVER_DURATION,
        easing = "outQuad",
    })
    group:CreateAnimation("color", {
        target = tab.text,
        sink = "textColor",
        from = fromText,
        to = toText,
        duration = TAB_HOVER_DURATION,
        easing = "outQuad",
    })
    if tab.icon then
        local fromIcon = readColor(tab.icon.GetTextColor, tab.icon, toText)
        group:CreateAnimation("color", {
            target = tab.icon,
            sink = "textColor",
            from = fromIcon,
            to = toText,
            duration = TAB_HOVER_DURATION,
            easing = "outQuad",
        })
    end
    tab._loothingColorGroup = group
    group:Play()
end

function MainFrameMixin:UpdateTabVisual(tab, isActive, animate)
    if not tab then
        return
    end

    -- The per-tab selectBar/selectGlow are superseded by self.tabIndicator;
    -- keep them hidden to avoid visual duplication.
    if tab.selectBar then tab.selectBar:Hide() end
    if tab.selectGlow and isActive then tab.selectGlow:Show() elseif tab.selectGlow then tab.selectGlow:Hide() end

    if animate ~= false and AnimationUtil then
        self:AnimateTabColors(tab, isActive and "active" or "idle")
        return
    end

    -- Snap form (used on ApplyTheme and initial layout)
    local textColorKey
    if isActive then
        tab:SetBackdropColor(unpack(SkinningMixin:GetColor("panel")))
        tab:SetBackdropBorderColor(unpack(SkinningMixin:GetColor("accent")))
        textColorKey = "accent"
    else
        tab:SetBackdropColor(unpack(SkinningMixin:GetColor("panelAlt")))
        tab:SetBackdropBorderColor(unpack(SkinningMixin:GetColor("borderStrong")))
        textColorKey = "textMuted"
    end
    tab.text:SetTextColor(unpack(SkinningMixin:GetColor(textColorKey)))
    if tab.icon then tab.icon:SetTextColor(unpack(SkinningMixin:GetColor(textColorKey))) end
end

--- Slide the shared tab indicator to a tab. Called from SelectTab.
--- @param tab Button
function MainFrameMixin:MoveIndicatorTo(tab)
    if not self.tabIndicator or not tab then return end
    local indicator = self.tabIndicator
    local containerLeft = self.tabContainer:GetLeft() or 0
    local tabLeft = tab:GetLeft() or 0
    local targetX = (tabLeft - containerLeft) + 2
    local targetWidth = math.max(0, tab:GetWidth() - 4)
    local accent = cloneColor(SkinningMixin:GetColor("accent"))

    indicator:SetVertexColor(unpackColor(accent))
    indicator:Show()

    -- Skip animation when frame isn't visible, or on the first positioning (no prior anchor).
    local skipAnim = not self.frame or not self.frame:IsVisible() or not self._indicatorPositioned

    if not AnimationUtil or skipAnim then
        indicator:ClearAllPoints()
        indicator:SetPoint("BOTTOMLEFT", self.tabContainer, "BOTTOMLEFT", targetX, 2)
        indicator:SetWidth(targetWidth)
        self._indicatorPositioned = true
        return
    end

    local currentX
    local p, _, _, x = indicator:GetPoint(1)
    if p and x then currentX = x else currentX = targetX end
    local currentWidth = indicator:GetWidth() or 0

    -- Base-anchor the indicator so `move` animation can delta-offset cleanly.
    indicator:ClearAllPoints()
    indicator:SetPoint("BOTTOMLEFT", self.tabContainer, "BOTTOMLEFT", currentX, 2)

    if self._tabIndicatorGroup then self._tabIndicatorGroup:Stop() end

    local group = AnimationUtil.CreateGroup(indicator)
    -- Slide via move: capture base anchor = {currentX, 2}, tween from {0,0} to {dx,0}
    group:CreateAnimation("move", {
        target = indicator,
        baseAnchor = { point = "BOTTOMLEFT", relativeTo = self.tabContainer, relativePoint = "BOTTOMLEFT", x = currentX, y = 2 },
        from = { 0, 0 },
        to = { targetX - currentX, 0 },
        duration = INDICATOR_SLIDE_DURATION,
        easing = "outCubic",
    })
    group:CreateAnimation("width", {
        target = indicator,
        from = currentWidth,
        to = targetWidth,
        duration = INDICATOR_SLIDE_DURATION,
        easing = "outCubic",
    })
    group:SetOnFinished(function()
        -- Re-anchor cleanly at the end so later layout reads see the final position.
        indicator:ClearAllPoints()
        indicator:SetPoint("BOTTOMLEFT", self.tabContainer, "BOTTOMLEFT", targetX, 2)
        indicator:SetWidth(targetWidth)
    end)
    self._tabIndicatorGroup = group
    self._indicatorPositioned = true
    group:Play()
end

function MainFrameMixin:ApplyTheme()
    local outerPadding = SkinningMixin:GetLayoutValue("outerPadding", 16)
    local tabHeight = SkinningMixin:GetLayoutValue("tabHeight", TAB_HEIGHT)
    local headerHeight = SkinningMixin:GetLayoutValue("headerHeight", 42)
    local contentBottom = SkinningMixin:GetLayoutValue("contentBottom", 16)

    if self.titleText then
        self.titleText:ClearAllPoints()
        self.titleText:SetPoint("TOPLEFT", outerPadding + 4, -(outerPadding - 2))
        SkinningMixin:StyleText(self.titleText, "title", "text")
    end

    if self.versionText and self.titleText then
        self.versionText:ClearAllPoints()
        self.versionText:SetPoint("LEFT", self.titleText, "RIGHT", 8, -1)
        SkinningMixin:StyleText(self.versionText, "bodySmall", "textMuted")
    end

    if self.desktopSyncText then
        SkinningMixin:StyleText(self.desktopSyncText, "bodySmall", "textSubtle")
    end

    if self.tabContainer then
        self.tabContainer:ClearAllPoints()
        self.tabContainer:SetPoint("TOPLEFT", outerPadding, -(headerHeight + 6))
        self.tabContainer:SetPoint("TOPRIGHT", -outerPadding, -(headerHeight + 6))
        self.tabContainer:SetHeight(tabHeight + 6)
    end

    if self.tabDivider then
        self.tabDivider:ClearAllPoints()
        self.tabDivider:SetPoint("TOPLEFT", outerPadding, -headerHeight)
        self.tabDivider:SetPoint("TOPRIGHT", -outerPadding, -headerHeight)
        self.tabDivider:SetColorTexture(unpack(SkinningMixin:GetColor("border")))
    end

    if self.contentContainer then
        self.contentContainer:ClearAllPoints()
        self.contentContainer:SetPoint("TOPLEFT", outerPadding, -(headerHeight + tabHeight + 12))
        self.contentContainer:SetPoint("BOTTOMRIGHT", -outerPadding, contentBottom)
        SkinningMixin:StyleSurface(self.contentContainer, "inset")
    end

    for _, tab in pairs(self.tabs or {}) do
        tab:SetHeight(tabHeight - 4)
        SkinningMixin:StyleSurface(tab, "alt")
        SkinningMixin:StyleText(tab.text, "header", "textMuted")
        self:UpdateTabVisual(tab, self.currentTab == tab.id, false)
    end

    -- Re-apply the accent glow so accent/theme switches take effect.
    if self.headerStrip then
        ApplyAccentGlow(self.headerStrip, 0.18)
        self.headerStrip:SetAlpha(1)
    end
    if self.pixelBorder and PixelUtil and type(PixelUtil.SetThinBorder) == "function" then
        -- Recolor pixel border from theme "borderStrong".
        local c = SkinningMixin:GetColor("borderStrong") or { 0, 0, 0, 1 }
        for _, tex in pairs(self.pixelBorder) do
            if type(tex) == "table" and type(tex.SetColorTexture) == "function" then
                tex:SetColorTexture(c[1] or 0, c[2] or 0, c[3] or 0, c[4] or 1)
            end
        end
    end
    if self.tabIndicator then
        self.tabIndicator:SetVertexColor(unpack(SkinningMixin:GetColor("accent")))
        local activeTab = self.currentTab and self.tabs[self.currentTab] or nil
        if activeTab and self.frame:IsVisible() then self:MoveIndicatorTo(activeTab) end
    end

    for _, panelWrapper in pairs(self.panels or {}) do
        if panelWrapper and panelWrapper.panel and type(panelWrapper.panel.ApplyTheme) == "function" then
            panelWrapper.panel:ApplyTheme()
        end
    end
end

--- Create panel contents
function MainFrameMixin:CreatePanels()
    -- Session panel
    local sessionFrame = CreateFrame("Frame", nil, self.contentContainer)
    sessionFrame:SetAllPoints()
    sessionFrame:Hide()
    self.panels.session = {
        frame = sessionFrame,
        panel = ns.CreateSessionPanel(sessionFrame),
    }

    -- Roster panel
    local rosterFrame = CreateFrame("Frame", nil, self.contentContainer)
    rosterFrame:SetAllPoints()
    rosterFrame:Hide()
    self.panels.roster = {
        frame = rosterFrame,
        panel = ns.CreateRosterPanel(rosterFrame),
    }

    -- Trade panel
    local tradeFrame = CreateFrame("Frame", nil, self.contentContainer)
    tradeFrame:SetAllPoints()
    tradeFrame:Hide()
    self.panels.trade = {
        frame = tradeFrame,
        panel = ns.CreateTradePanel(tradeFrame),
    }

    -- History panel
    local historyFrame = CreateFrame("Frame", nil, self.contentContainer)
    historyFrame:SetAllPoints()
    historyFrame:Hide()
    self.panels.history = {
        frame = historyFrame,
        panel = ns.CreateHistoryPanel(historyFrame),
    }

    -- Select default tab
    self:SelectTab("session")
end

--[[--------------------------------------------------------------------
    Tab Selection
----------------------------------------------------------------------]]

--- Select a tab
-- @param tabId string
function MainFrameMixin:SelectTab(tabId)
    if self.currentTab == tabId then
        return
    end

    local prevTab = self.currentTab and self.tabs[self.currentTab] or nil
    local prevPanel = self.currentTab and self.panels[self.currentTab] or nil
    self.currentTab = tabId

    if prevTab then
        self:UpdateTabVisual(prevTab, false)
    end

    local tab = self.tabs[tabId]
    if tab then
        self:UpdateTabVisual(tab, true)
        self:MoveIndicatorTo(tab)
    end

    local panel = self.panels[tabId]

    -- Snapshot the tab this SelectTab call is targeting. Rapid switches
    -- (A→B→C within the cross-fade window) must not let the deferred
    -- showNewPanel for B fire after C has already started — otherwise B's
    -- panel is momentarily shown on top of C.
    local pendingTab = tabId

    local function showNewPanel()
        if self.currentTab ~= pendingTab then
            -- A later SelectTab superseded this one. Bail out so we don't
            -- fade in a now-stale panel on top of the real one.
            return
        end
        if not panel then return end
        if panel.panel and panel.panel.Refresh then
            panel.panel:Refresh()
        end
        if AnimationPresets then
            -- Capture the fade-in group so a future tab-switch can Stop() it
            -- before starting its own fade-out; without this the new in-flight
            -- tween on the same frame is uncancellable.
            if panel.frame._loothingFadeGroup then panel.frame._loothingFadeGroup:Stop() end
            panel.frame._loothingFadeGroup = AnimationPresets.FadeIn(panel.frame, TAB_FADE_IN, "outCubic")
        else
            panel.frame:Show()
        end
    end

    local canAnimatePanels = prevPanel and prevPanel.frame and prevPanel.frame:IsShown()
        and AnimationPresets and self.frame:IsVisible()
    if canAnimatePanels then
        -- Stop any existing fade so rapid tab-switching doesn't leave panels mid-fade.
        if prevPanel.frame._loothingFadeGroup then prevPanel.frame._loothingFadeGroup:Stop() end
        local fadeOut = AnimationPresets.FadeOut(prevPanel.frame, TAB_FADE_OUT, "inQuad", true, function()
            prevPanel.frame:SetAlpha(1)
        end)
        prevPanel.frame._loothingFadeGroup = fadeOut
        -- Stagger the new-panel fade slightly so the visual handoff reads as a cross-fade.
        if C_Timer and C_Timer.After then
            C_Timer.After(TAB_FADE_OUT + TAB_FADE_STAGGER, showNewPanel)
        else
            showNewPanel()
        end
    else
        if prevPanel then prevPanel.frame:Hide() end
        showNewPanel()
    end

    self:TriggerEvent("OnTabSelected", tabId)
end

--- Get current tab
-- @return string
function MainFrameMixin:GetCurrentTab()
    return self.currentTab
end

--[[--------------------------------------------------------------------
    Visibility
----------------------------------------------------------------------]]

--- Show the main frame
function MainFrameMixin:Show()
    -- Stop any in-flight open/close fade before starting a new one.
    if self.frame._loothingFadeGroup then self.frame._loothingFadeGroup:Stop() end
    self._hiding = nil

    self.frame:Show()

    -- Refresh current panel
    local panel = self.panels[self.currentTab]
    if panel and panel.panel and panel.panel.Refresh then
        panel.panel:Refresh()
    end

    -- Header desktop-sync label: refresh on every open — its only other
    -- call site is frame construction, which froze it at the load-time
    -- (usually empty) value for the whole session.
    if self.UpdateDesktopSyncStatus then
        self:UpdateDesktopSyncStatus()
    end

    -- Snap indicator to the active tab (safe now that layout is final).
    local activeTab = self.currentTab and self.tabs[self.currentTab] or nil
    if activeTab then self:MoveIndicatorTo(activeTab) end

    if AnimationPresets then
        self.frame._loothingFadeGroup = AnimationPresets.FadeIn(self.frame, SHOW_DURATION, "outCubic")
    else
        self.frame:SetAlpha(1)
    end

    self:TriggerEvent("OnShow")
end

--- Hide the main frame
function MainFrameMixin:Hide()
    if self.frame._loothingFadeGroup then self.frame._loothingFadeGroup:Stop() end
    self._hiding = true

    if AnimationPresets then
        self.frame._loothingFadeGroup = AnimationPresets.FadeOut(self.frame, HIDE_DURATION, "inCubic", true, function()
            -- Reset alpha for next Show so we don't get a visible starting-alpha pop.
            self.frame:SetAlpha(0)
            self._hiding = nil
        end)
    else
        self.frame:Hide()
        self._hiding = nil
    end

    self:TriggerEvent("OnHide")
end

--- Toggle visibility
function MainFrameMixin:Toggle()
    -- IsShown() stays true for the whole 0.13s hide fade, so a quick
    -- re-toggle used to re-Hide instead of reopening — the window felt
    -- unresponsive. Treat "currently fading out" as hidden.
    if self.frame:IsShown() and not self._hiding then
        self:Hide()
    else
        self:Show()
    end
end

--- Check if shown
-- @return boolean
function MainFrameMixin:IsShown()
    return self.frame:IsShown()
end

--- Refresh the currently active panel
-- Delegates to the current panel's Refresh method if available
function MainFrameMixin:Refresh()
    local currentTab = self.currentTab
    if not currentTab then return end

    local panelWrapper = self.panels[currentTab]
    if panelWrapper and panelWrapper.panel and type(panelWrapper.panel.Refresh) == "function" then
        panelWrapper.panel:Refresh()
    end
end

--- Refresh all panels
function MainFrameMixin:RefreshAll()
    for _, panelWrapper in pairs(self.panels) do
        if panelWrapper and panelWrapper.panel and type(panelWrapper.panel.Refresh) == "function" then
            panelWrapper.panel:Refresh()
        end
    end
end

--[[--------------------------------------------------------------------
    Position & Size
----------------------------------------------------------------------]]

--- Load position from settings
function MainFrameMixin:LoadPosition()
    if not Loothing.Settings then return end

    local pos = Loothing.Settings:Get("frame.position")
    if pos then
        self.frame:ClearAllPoints()
        self.frame:SetPoint(pos.point or "CENTER", UIParent, pos.relativePoint or "CENTER", pos.x or 0, pos.y or 0)

        if pos.width and pos.height then
            self.frame:SetSize(pos.width, pos.height)
        end
    end

    self:UpdateScale()
end

--- Save position to settings
function MainFrameMixin:SavePosition()
    if not Loothing.Settings then return end

    local point, _, relativePoint, x, y = self.frame:GetPoint()
    local width, height = self.frame:GetSize()

    Loothing.Settings:Set("frame.position", {
        point = point,
        relativePoint = relativePoint,
        x = x,
        y = y,
        width = width,
        height = height,
    })

    -- Persist scale too (frame.UI.MainFrame.scale) — nothing else writes
    -- it, and UpdateScale reads it on login to restore Ctrl+Scroll sizing.
    if ns.SkinningMixin and ns.SkinningMixin.SaveFrameState then
        ns.SkinningMixin:SaveFrameState(self.frame, "MainFrame")
    end
end

--- Update frame scale
function MainFrameMixin:UpdateScale()
    if not Loothing.Settings then return end

    -- Prefer the scale persisted by the Ctrl+Scroll skin handler
    -- (frame.UI.MainFrame.scale). frame.uiScale has no writer, so reading
    -- only it reset the user's saved scale to 1.0 every login.
    local scale = Loothing.Settings:Get("frame.UI.MainFrame.scale")
        or Loothing.Settings:Get("frame.uiScale")
        or 1.0
    self.frame:SetScale(scale)
end

--- Handle resize
function MainFrameMixin:OnResize()
    -- Notify panels of size change if needed
    for _, panelData in pairs(self.panels) do
        if panelData.panel and panelData.panel.OnResize then
            panelData.panel:OnResize()
        end
    end
end

--[[--------------------------------------------------------------------
    Panel Access
----------------------------------------------------------------------]]

--- Get session panel
-- @return table
function MainFrameMixin:GetSessionPanel()
    return self.panels.session and self.panels.session.panel
end

--- Get trade panel
-- @return table
function MainFrameMixin:GetTradePanel()
    return self.panels.trade and self.panels.trade.panel
end

--- Get roster panel
-- @return table
function MainFrameMixin:GetRosterPanel()
    return self.panels.roster and self.panels.roster.panel
end

--- Get history panel
-- @return table
function MainFrameMixin:GetHistoryPanel()
    return self.panels.history and self.panels.history.panel
end

--- Open the standalone settings dialog
function MainFrameMixin:OpenSettings()
    if Loolib.Config then
        Loolib.Config:Open("Loothing")
    end
end

--- Update the desktop sync status text in the title bar area.
--- Shows: "Desktop: Synced" (green, <1h), "Desktop: Xh ago" (yellow, 1-24h), "Desktop: Stale" (red, >24h), or empty if no data.
function MainFrameMixin:UpdateDesktopSyncStatus()
    if not self.desktopSyncText then return end
    if not Loothing.Wishlist or not Loothing.Wishlist:HasData() then
        self.desktopSyncText:SetText("")
        return
    end
    local age = Loothing.Wishlist:GetTimeSinceSync()
    if not age then
        self.desktopSyncText:SetText("|cff666666Desktop: Not synced|r")
    elseif age < 3600 then
        self.desktopSyncText:SetText("|cff00ff00Desktop: Synced|r")
    elseif age < 86400 then
        self.desktopSyncText:SetText("|cffffff00Desktop: " .. math.floor(age / 3600) .. "h ago|r")
    else
        self.desktopSyncText:SetText("|cffff0000Desktop: Stale|r")
    end
end

--[[--------------------------------------------------------------------
    Factory
----------------------------------------------------------------------]]

local function CreateMainFrame()
    local mainFrame = Loolib.CreateFromMixins(MainFrameMixin)
    mainFrame:Init()
    return mainFrame
end

ns.CreateMainFrame = CreateMainFrame
