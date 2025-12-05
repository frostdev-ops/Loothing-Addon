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

    -- Backdrop
    frame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true,
        tileSize = 32,
        edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 },
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

    -- Register for ESC to close
    if UISpecialFrames then
        tinsert(UISpecialFrames, "LoothingMainFrame")
    end

    self.frame = frame
end

--- Create tab buttons
function LoothingMainFrameMixin:CreateTabs()
    local L = LOOTHING_LOCALE

    local tabDefs = {
        { id = "session", name = L["TAB_SESSION"] },
        { id = "history", name = L["TAB_HISTORY"] },
        { id = "settings", name = L["TAB_SETTINGS"] },
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
    local tab = CreateFrame("Button", nil, self.tabContainer)
    tab:SetSize(100, TAB_HEIGHT - 4)
    tab:SetPoint("BOTTOMLEFT", xOffset, 0)

    -- Background
    local bg = tab:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0.2, 0.2, 0.2, 0.8)
    tab.bg = bg

    -- Highlight
    local highlight = tab:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetAllPoints()
    highlight:SetColorTexture(0.4, 0.4, 0.4, 0.5)

    -- Selected indicator
    local selected = tab:CreateTexture(nil, "BORDER")
    selected:SetPoint("BOTTOMLEFT")
    selected:SetPoint("BOTTOMRIGHT")
    selected:SetHeight(3)
    selected:SetColorTexture(1, 0.82, 0, 1)
    selected:Hide()
    tab.selected = selected

    -- Text
    local text = tab:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    text:SetPoint("CENTER")
    text:SetText(name)
    tab.text = text

    tab.id = id

    tab:SetScript("OnClick", function()
        self:SelectTab(id)
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

    -- History panel
    local historyFrame = CreateFrame("Frame", nil, self.contentContainer)
    historyFrame:SetAllPoints()
    historyFrame:Hide()
    self.panels.history = {
        frame = historyFrame,
        panel = CreateLoothingHistoryPanel(historyFrame),
    }

    -- Settings panel
    local settingsFrame = CreateFrame("Frame", nil, self.contentContainer)
    settingsFrame:SetAllPoints()
    settingsFrame:Hide()
    self.panels.settings = {
        frame = settingsFrame,
        panel = CreateLoothingSettingsPanel(settingsFrame),
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
            prevTab.selected:Hide()
            prevTab.bg:SetColorTexture(0.2, 0.2, 0.2, 0.8)
            prevTab.text:SetTextColor(1, 1, 1)
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
        tab.selected:Show()
        tab.bg:SetColorTexture(0.3, 0.3, 0.3, 0.9)
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

--[[--------------------------------------------------------------------
    Position & Size
----------------------------------------------------------------------]]

--- Load position from settings
function LoothingMainFrameMixin:LoadPosition()
    if not Loothing.Settings then return end

    local pos = Loothing.Settings:Get("ui.mainFramePosition")
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

    Loothing.Settings:Set("ui.mainFramePosition", {
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

    local scale = Loothing.Settings:Get("ui.scale") or 1.0
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

--- Get history panel
-- @return table
function LoothingMainFrameMixin:GetHistoryPanel()
    return self.panels.history and self.panels.history.panel
end

--- Get settings panel
-- @return table
function LoothingMainFrameMixin:GetSettingsPanel()
    return self.panels.settings and self.panels.settings.panel
end

--[[--------------------------------------------------------------------
    Factory
----------------------------------------------------------------------]]

function CreateLoothingMainFrame()
    local mainFrame = LoolibCreateFromMixins(LoothingMainFrameMixin)
    mainFrame:Init()
    return mainFrame
end
