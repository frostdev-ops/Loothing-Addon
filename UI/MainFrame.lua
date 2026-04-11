--[[--------------------------------------------------------------------
    Loothing - Loot Council Addon for WoW 12.0+
    MainFrame - Primary addon window with tabbed interface
----------------------------------------------------------------------]]

local _, ns = ...
local Loolib = LibStub("Loolib")
local Loothing = ns.Addon
local SkinningMixin = ns.SkinningMixin

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

--- Initialize the main frame
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
        { id = "session", name = L["TAB_SESSION"] },
        { id = "roster", name = L["TAB_ROSTER"] },
        { id = "trade", name = L["TAB_TRADE"] },
        { id = "history", name = L["TAB_HISTORY"] },
    }

    local tabWidth = 100
    local spacing = 4
    local xOffset = 0

    for _, def in ipairs(tabDefs) do
        local tab = self:CreateTab(def.id, def.name, xOffset)
        self.tabs[def.id] = tab
        xOffset = xOffset + tabWidth + spacing
    end
end

--- Create a single tab button
-- @param id string - Tab identifier
-- @param name string - Display name
-- @param xOffset number
-- @return Frame
function MainFrameMixin:CreateTab(id, name, xOffset)
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

    -- Text
    local text = tab:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    text:SetPoint("CENTER")
    text:SetText(name)
    SkinningMixin:StyleText(text, "header", "textMuted")
    tab.text = text

    tab.id = id

    tab:SetScript("OnClick", function()
        self:SelectTab(id)
    end)

    -- Hover effects
    tab:SetScript("OnEnter", function(btn)
        if self.currentTab ~= id then
            btn:SetBackdropColor(unpack(SkinningMixin:GetColor("rowHover")))
            btn:SetBackdropBorderColor(unpack(SkinningMixin:GetColor("borderStrong")))
            btn.text:SetTextColor(unpack(SkinningMixin:GetColor("text")))
        end
    end)
    tab:SetScript("OnLeave", function(btn)
        if self.currentTab ~= id then
            btn:SetBackdropColor(unpack(SkinningMixin:GetColor("panelAlt")))
            btn:SetBackdropBorderColor(unpack(SkinningMixin:GetColor("borderStrong")))
            btn.text:SetTextColor(unpack(SkinningMixin:GetColor("textMuted")))
        end
    end)

    return tab
end

function MainFrameMixin:UpdateTabVisual(tab, isActive)
    if not tab then
        return
    end

    if isActive then
        tab:SetBackdropColor(unpack(SkinningMixin:GetColor("panel")))
        tab:SetBackdropBorderColor(unpack(SkinningMixin:GetColor("accent")))
        if tab.selectBar then tab.selectBar:Show() end
        if tab.selectGlow then tab.selectGlow:Show() end
        tab.text:SetTextColor(unpack(SkinningMixin:GetColor("accent")))
    else
        tab:SetBackdropColor(unpack(SkinningMixin:GetColor("panelAlt")))
        tab:SetBackdropBorderColor(unpack(SkinningMixin:GetColor("borderStrong")))
        if tab.selectBar then tab.selectBar:Hide() end
        if tab.selectGlow then tab.selectGlow:Hide() end
        tab.text:SetTextColor(unpack(SkinningMixin:GetColor("textMuted")))
    end
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
        self:UpdateTabVisual(tab, self.currentTab == tab.id)
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

    -- Deselect previous
    if self.currentTab then
        local prevTab = self.tabs[self.currentTab]
        if prevTab then
            self:UpdateTabVisual(prevTab, false)
        end

        local prevPanel = self.panels[self.currentTab]
        if prevPanel then
            prevPanel.frame:Hide()
        end
    end

    -- Select new
    self.currentTab = tabId

    local tab = self.tabs[tabId]
    if tab then
        self:UpdateTabVisual(tab, true)
    end

    local panel = self.panels[tabId]
    if panel then
        panel.frame:Show()
        if panel.panel and panel.panel.Refresh then
            panel.panel:Refresh()
        end
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
    self.frame:Show()

    -- Refresh current panel
    local panel = self.panels[self.currentTab]
    if panel and panel.panel and panel.panel.Refresh then
        panel.panel:Refresh()
    end

    self:TriggerEvent("OnShow")
end

--- Hide the main frame
function MainFrameMixin:Hide()
    self.frame:Hide()
    self:TriggerEvent("OnHide")
end

--- Toggle visibility
function MainFrameMixin:Toggle()
    if self.frame:IsShown() then
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
end

--- Update frame scale
function MainFrameMixin:UpdateScale()
    if not Loothing.Settings then return end

    local scale = Loothing.Settings:Get("frame.uiScale") or 1.0
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
