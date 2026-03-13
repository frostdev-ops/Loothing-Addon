--[[--------------------------------------------------------------------
    Loothing - Loot Council Addon for WoW 12.0+
    SettingsPanel - Configuration UI (Using ConfigDialog)
----------------------------------------------------------------------]]

local _, ns = ...
local Loolib = LibStub("Loolib")
local Config = Loolib.Config
local CreateFromMixins = Loolib.CreateFromMixins
local Loothing = ns.Addon
local L = ns.Locale

local HEADER_HEIGHT = 56

--[[--------------------------------------------------------------------
    SettingsPanelMixin
----------------------------------------------------------------------]]

local SettingsPanelMixin = ns.SettingsPanelMixin or {}
ns.SettingsPanelMixin = SettingsPanelMixin

--- Initialize the settings panel
-- @param parent Frame - Parent frame
function SettingsPanelMixin:Init(parent)
    self.parent = parent

    self:CreateFrame()
    self:CreateHeader()
    self:CreateElements()
end

--- Create the main frame
function SettingsPanelMixin:CreateFrame()
    local frame = CreateFrame("Frame", nil, self.parent)
    frame:SetAllPoints()

    self.frame = frame
end

--- Create branding header: [logo] LOOTHING  v1.0.0
function SettingsPanelMixin:CreateHeader()
    local frame = self.frame

    -- Header container
    local header = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    header:SetPoint("TOPLEFT", 0, 0)
    header:SetPoint("TOPRIGHT", 0, 0)
    header:SetHeight(HEADER_HEIGHT)
    header:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = nil,
        tile = false,
    })
    header:SetBackdropColor(0.06, 0.06, 0.09, 0.95)
    self.headerFrame = header

    local xCursor = 12

    -- Logo texture (gracefully skip if not found)
    local logoPath = "Interface\\AddOns\\Loothing\\Media\\logo"
    local logoW, logoH = 40, 40
    local logo = header:CreateTexture(nil, "ARTWORK")
    logo:SetSize(logoW, logoH)
    logo:SetPoint("LEFT", header, "LEFT", xCursor, 0)
    logo:SetTexture(logoPath)
    -- If texture doesn't exist WoW shows nothing (graceful degradation)
    xCursor = xCursor + logoW + 8

    -- Addon title
    local title = header:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
    title:SetPoint("LEFT", header, "LEFT", xCursor, 4)
    title:SetText(L["ADDON_NAME"] or "Loothing")
    title:SetTextColor(1, 1, 1, 1)

    -- Version below title
    local versionValue = (Loothing and (Loothing.version or Loothing.VERSION)) or ""
    local versionStr = "v" .. versionValue
    local version = header:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    version:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -2)
    version:SetText(versionStr)
    version:SetTextColor(0.6, 0.6, 0.6, 1)

    -- Separator line at bottom of header
    local sep = header:CreateTexture(nil, "OVERLAY")
    sep:SetPoint("BOTTOMLEFT", header, "BOTTOMLEFT", 0, 0)
    sep:SetPoint("BOTTOMRIGHT", header, "BOTTOMRIGHT", 0, 0)
    sep:SetHeight(1)
    sep:SetColorTexture(1, 0.82, 0, 0.6)  -- Subtle gold separator
end

--- Create UI elements using ConfigDialog
function SettingsPanelMixin:CreateElements()
    local container = CreateFrame("Frame", nil, self.frame)
    container:SetPoint("TOPLEFT", 0, -HEADER_HEIGHT)
    container:SetPoint("BOTTOMRIGHT", 0, 0)
    self.container = container

    local message = container:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    message:SetPoint("CENTER", 0, 24)
    message:SetText(L["BLIZZARD_SETTINGS_DESC"] or "Click below to open the full settings panel")
    message:SetTextColor(0.9, 0.9, 0.9)
    self.messageText = message

    local openBtn = CreateFrame("Button", nil, container, "UIPanelButtonTemplate")
    openBtn:SetSize(220, 28)
    openBtn:SetPoint("TOP", message, "BOTTOM", 0, -16)
    openBtn:SetText(L["OPEN_SETTINGS"] or "Open Loothing Settings")
    openBtn:SetScript("OnClick", function()
        if Config then
            Config:Open("Loothing")
        end
    end)
    self.openButton = openBtn

    if not Config or type(Config.Open) ~= "function" then
        message:SetText("Error: Loolib Config not available")
        message:SetTextColor(1, 0.3, 0.3)
        openBtn:Disable()
    end
end

--[[--------------------------------------------------------------------
    Public Interface
----------------------------------------------------------------------]]

--- Refresh settings display
function SettingsPanelMixin:Refresh()
    if self.messageText then
        self.messageText:SetText(L["BLIZZARD_SETTINGS_DESC"] or "Click below to open the full settings panel")
    end
end

--- Get the frame
-- @return Frame
function SettingsPanelMixin:GetFrame()
    return self.frame
end

--- Show the panel
function SettingsPanelMixin:Show()
    self.frame:Show()
    -- Refresh is handled by ConfigDialog automatically
end

--- Hide the panel
function SettingsPanelMixin:Hide()
    self.frame:Hide()
end

--[[--------------------------------------------------------------------
    Factory
----------------------------------------------------------------------]]

local function CreateSettingsPanel(parent)
    local panel = CreateFromMixins(SettingsPanelMixin)
    panel:Init(parent)
    return panel
end

ns.CreateSettingsPanel = CreateSettingsPanel
