--[[--------------------------------------------------------------------
    Loothing - Loot Council Addon for WoW 12.0+
    MainFrame - Primary addon window with tabbed interface
----------------------------------------------------------------------]]

local Loolib = LibStub("Loolib")

--[[--------------------------------------------------------------------
    LoothingMainFrameMixin
----------------------------------------------------------------------]]

LoothingMainFrameMixin = LoolibCreateFromMixins(LoolibCallbackRegistryMixin)

local MAIN_FRAME_EVENTS = {
    "OnShow",
    "OnHide",
    "OnTabSelected",
}

local FRAME_WIDTH = 600
local FRAME_HEIGHT = 500
local TAB_HEIGHT = 32

--- Initialize the main frame
function LoothingMainFrameMixin:Init()
    LoolibCallbackRegistryMixin.OnLoad(self)
    self:GenerateCallbackEvents(MAIN_FRAME_EVENTS)

    self.tabs = {}
    self.panels = {}
    self.currentTab = nil

    self:CreateFrame()
    self:CreateTabs()
    self:CreatePanels()
    self:LoadPosition()
end

--- Create the main frame
function LoothingMainFrameMixin:CreateFrame()
    local frame = CreateFrame("Frame", "LoothingMainFrame", UIParent, "BackdropTemplate")
    frame:SetSize(FRAME_WIDTH, FRAME_HEIGHT)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("HIGH")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:SetClampedToScreen(true)
    frame:SetResizable(true)
    frame:SetResizeBounds(500, 400, 900, 700)
    frame:Hide()

    -- Apply skin via LoothingSkinningMixin
    LoothingSkinningMixin:SetupFrame(frame, "MainFrame", "LoothingMainFrame", {
        combatMinimize = true,
        ctrlScroll = true,
        escapeClose = true,
    })

    -- Title
    self.titleText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    self.titleText:SetPoint("TOP", 0, -16)
    self.titleText:SetText("Loothing")
    self.titleText:SetTextColor(1, 0.82, 0)

    -- Version
    self.versionText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    self.versionText:SetPoint("LEFT", self.titleText, "RIGHT", 8, 0)
    self.versionText:SetText("v" .. (LOOTHING_VERSION or "1.0.0"))
    self.versionText:SetTextColor(0.5, 0.5, 0.5)

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
        GameTooltip:SetText(LOOTHING_LOCALE["TAB_SETTINGS"])
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
    self.tabContainer:SetPoint("TOPLEFT", 16, -40)
    self.tabContainer:SetPoint("TOPRIGHT", -16, -40)
    self.tabContainer:SetHeight(TAB_HEIGHT)

    -- Content container
    self.contentContainer = CreateFrame("Frame", nil, frame)
    self.contentContainer:SetPoint("TOPLEFT", 16, -40 - TAB_HEIGHT)
    self.contentContainer:SetPoint("BOTTOMRIGHT", -16, 16)

    self.frame = frame
end

--- Create tab buttons
function LoothingMainFrameMixin:CreateTabs()
    local L = LOOTHING_LOCALE

    local tabDefs = {
        { id = "session", name = L["TAB_SESSION"] },
        { id = "trade", name = L["TAB_TRADE"] },
        { id = "history", name = L["TAB_HISTORY"] },
    }

    local tabWidth = 100
    local spacing = 4
    local xOffset = 0

    for i, def in ipairs(tabDefs) do
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
function LoothingMainFrameMixin:CreateTab(id, name, xOffset)
    local tab = CreateFrame("Button", nil, self.tabContainer, "BackdropTemplate")
    tab:SetSize(100, TAB_HEIGHT - 4)
    tab:SetPoint("BOTTOMLEFT", xOffset, 0)

    -- Enhanced backdrop with thicker border
    tab:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        tile = false,
        edgeSize = 2,
        insets = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    tab:SetBackdropColor(0.12, 0.12, 0.12, 0.95)
    tab:SetBackdropBorderColor(0.25, 0.25, 0.25, 1)

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
    selectBar:SetColorTexture(1, 0.82, 0, 1)
    selectBar:Hide()
    tab.selectBar = selectBar

    -- Selection glow background - hidden by default
    local selectGlow = tab:CreateTexture(nil, "BACKGROUND", nil, -1)
    selectGlow:SetAllPoints()
    selectGlow:SetColorTexture(0.3, 0.3, 0.5, 0.4)
    selectGlow:Hide()
    tab.selectGlow = selectGlow

    -- Text
    local text = tab:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    text:SetPoint("CENTER")
    text:SetText(name)
    text:SetTextColor(0.6, 0.6, 0.6) -- Default dim color
    tab.text = text

    tab.id = id

    tab:SetScript("OnClick", function()
        self:SelectTab(id)
    end)

    -- Hover effects
    tab:SetScript("OnEnter", function(btn)
        if self.currentTab ~= id then
            btn:SetBackdropColor(0.2, 0.2, 0.25, 0.95)
            btn:SetBackdropBorderColor(0.4, 0.4, 0.5, 1)
            btn.text:SetTextColor(1, 1, 1)
        end
    end)
    tab:SetScript("OnLeave", function(btn)
        if self.currentTab ~= id then
            btn:SetBackdropColor(0.12, 0.12, 0.12, 0.95)
            btn:SetBackdropBorderColor(0.25, 0.25, 0.25, 1)
            btn.text:SetTextColor(0.6, 0.6, 0.6)
        end
    end)

    return tab
end

--- Create panel contents
function LoothingMainFrameMixin:CreatePanels()
    -- Session panel
    local sessionFrame = CreateFrame("Frame", nil, self.contentContainer)
    sessionFrame:SetAllPoints()
    sessionFrame:Hide()
    self.panels.session = {
        frame = sessionFrame,
        panel = CreateLoothingSessionPanel(sessionFrame),
    }

    -- Trade panel
    local tradeFrame = CreateFrame("Frame", nil, self.contentContainer)
    tradeFrame:SetAllPoints()
    tradeFrame:Hide()
    self.panels.trade = {
        frame = tradeFrame,
        panel = CreateLoothingTradePanel(tradeFrame),
    }

    -- History panel
    local historyFrame = CreateFrame("Frame", nil, self.contentContainer)
    historyFrame:SetAllPoints()
    historyFrame:Hide()
    self.panels.history = {
        frame = historyFrame,
        panel = CreateLoothingHistoryPanel(historyFrame),
    }

    -- Select default tab
    self:SelectTab("session")
end

--[[--------------------------------------------------------------------
    Tab Selection
----------------------------------------------------------------------]]

--- Select a tab
-- @param tabId string
function LoothingMainFrameMixin:SelectTab(tabId)
    if self.currentTab == tabId then
        return
    end

    -- Deselect previous
    if self.currentTab then
        local prevTab = self.tabs[self.currentTab]
        if prevTab then
            prevTab:SetBackdropColor(0.12, 0.12, 0.12, 0.95)
            prevTab:SetBackdropBorderColor(0.25, 0.25, 0.25, 1)
            if prevTab.selectBar then prevTab.selectBar:Hide() end
            if prevTab.selectGlow then prevTab.selectGlow:Hide() end
            prevTab.text:SetTextColor(0.6, 0.6, 0.6)
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
        tab:SetBackdropColor(0.2, 0.2, 0.3, 1)
        tab:SetBackdropBorderColor(1, 0.82, 0, 1)
        if tab.selectBar then tab.selectBar:Show() end
        if tab.selectGlow then tab.selectGlow:Show() end
        tab.text:SetTextColor(1, 0.82, 0)
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
function LoothingMainFrameMixin:GetCurrentTab()
    return self.currentTab
end

--[[--------------------------------------------------------------------
    Visibility
----------------------------------------------------------------------]]

--- Show the main frame
function LoothingMainFrameMixin:Show()
    self.frame:Show()

    -- Refresh current panel
    local panel = self.panels[self.currentTab]
    if panel and panel.panel and panel.panel.Refresh then
        panel.panel:Refresh()
    end

    self:TriggerEvent("OnShow")
end

--- Hide the main frame
function LoothingMainFrameMixin:Hide()
    self.frame:Hide()
    self:TriggerEvent("OnHide")
end

--- Toggle visibility
function LoothingMainFrameMixin:Toggle()
    if self.frame:IsShown() then
        self:Hide()
    else
        self:Show()
    end
end

--- Check if shown
-- @return boolean
function LoothingMainFrameMixin:IsShown()
    return self.frame:IsShown()
end

--- Refresh the currently active panel
-- Delegates to the current panel's Refresh method if available
function LoothingMainFrameMixin:Refresh()
    local currentTab = self.currentTab
    if not currentTab then return end

    local panelWrapper = self.panels[currentTab]
    if panelWrapper and panelWrapper.panel and type(panelWrapper.panel.Refresh) == "function" then
        panelWrapper.panel:Refresh()
    end
end

--- Refresh all panels
function LoothingMainFrameMixin:RefreshAll()
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
function LoothingMainFrameMixin:LoadPosition()
    if not Loothing.Settings then return end

    local pos = Loothing.Settings:Get("settings.mainFramePosition")
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
function LoothingMainFrameMixin:SavePosition()
    if not Loothing.Settings then return end

    local point, _, relativePoint, x, y = self.frame:GetPoint()
    local width, height = self.frame:GetSize()

    Loothing.Settings:Set("settings.mainFramePosition", {
        point = point,
        relativePoint = relativePoint,
        x = x,
        y = y,
        width = width,
        height = height,
    })
end

--- Update frame scale
function LoothingMainFrameMixin:UpdateScale()
    if not Loothing.Settings then return end

    local scale = Loothing.Settings:Get("settings.uiScale") or 1.0
    self.frame:SetScale(scale)
end

--- Handle resize
function LoothingMainFrameMixin:OnResize()
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
function LoothingMainFrameMixin:GetSessionPanel()
    return self.panels.session and self.panels.session.panel
end

--- Get trade panel
-- @return table
function LoothingMainFrameMixin:GetTradePanel()
    return self.panels.trade and self.panels.trade.panel
end

--- Get history panel
-- @return table
function LoothingMainFrameMixin:GetHistoryPanel()
    return self.panels.history and self.panels.history.panel
end

--- Open the standalone settings dialog
function LoothingMainFrameMixin:OpenSettings()
    if LoolibConfig then
        LoolibConfig:Open("Loothing")
    end
end

--[[--------------------------------------------------------------------
    Factory
----------------------------------------------------------------------]]

function CreateLoothingMainFrame()
    local mainFrame = LoolibCreateFromMixins(LoothingMainFrameMixin)
    mainFrame:Init()
    return mainFrame
end
