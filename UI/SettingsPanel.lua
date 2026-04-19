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
local SkinningMixin = ns.SkinningMixin
local ThemeManager = Loolib.ThemeManager

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
    self:ApplyTheme()
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
    header:SetBackdropColor(unpack(SkinningMixin:GetColor("header")))
    self.headerFrame = header

    local xCursor = 12

    -- Logo texture (gracefully skip if not found)
    local logoW, logoH = 40, 40
    local logo = header:CreateTexture(nil, "ARTWORK")
    logo:SetSize(logoW, logoH)
    logo:SetPoint("LEFT", header, "LEFT", xCursor, 0)
    if ThemeManager and ThemeManager.ApplyTexture then
        ThemeManager:ApplyTexture(logo, "loothing-logo", "Interface\\AddOns\\Loothing\\Media\\logo.tga")
    else
        logo:SetTexture("Interface\\AddOns\\Loothing\\Media\\logo.tga")
    end
    -- If texture doesn't exist WoW shows nothing (graceful degradation)
    xCursor = xCursor + logoW + 8

    -- Addon title
    local title = header:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
    title:SetPoint("LEFT", header, "LEFT", xCursor, 4)
    title:SetText(L["ADDON_NAME"])
    SkinningMixin:StyleText(title, "titleHuge", "text")
    self.titleText = title

    -- Version below title
    local versionValue = (Loothing and (Loothing.version or Loothing.VERSION)) or ""
    local versionStr = "v" .. versionValue
    local version = header:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    version:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -2)
    version:SetText(versionStr)
    SkinningMixin:StyleText(version, "bodySmall", "textMuted")
    self.versionText = version

    -- Separator line at bottom of header
    local sep = header:CreateTexture(nil, "OVERLAY")
    sep:SetPoint("BOTTOMLEFT", header, "BOTTOMLEFT", 0, 0)
    sep:SetPoint("BOTTOMRIGHT", header, "BOTTOMRIGHT", 0, 0)
    sep:SetHeight(1)
    sep:SetColorTexture(unpack(SkinningMixin:GetColor("accent")))  -- Subtle accent separator
    self.headerSeparator = sep
end

--- Create UI elements using ConfigDialog
function SettingsPanelMixin:CreateElements()
    local container = CreateFrame("Frame", nil, self.frame)
    container:SetPoint("TOPLEFT", 0, -HEADER_HEIGHT)
    container:SetPoint("BOTTOMRIGHT", 0, 0)
    self.container = container

    local message = container:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    message:SetPoint("CENTER", 0, 24)
    message:SetText(L["BLIZZARD_SETTINGS_DESC"])
    SkinningMixin:StyleText(message, "title", "text")
    self.messageText = message

    -- Info icon anchored to the left of the centered message.
    self.messageIcon = container:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    self.messageIcon:SetPoint("RIGHT", message, "LEFT", -6, 0)
    Loolib.Fonts:SetIconFont(self.messageIcon, 16, "")
    self.messageIcon:SetText(Loolib.Fonts:Icon("circle-info"))
    self.messageIcon:SetTextColor(0.6, 0.8, 1.0)

    local openBtn = ns.CreateThemedButton(container)
    openBtn:SetSize(220, 28)
    openBtn:SetPoint("TOP", message, "BOTTOM", 0, -16)
    openBtn:SetText(L["OPEN_SETTINGS"])
    openBtn:SetScript("OnClick", function()
        if Config then
            Config:Open("Loothing")
        end
    end)
    SkinningMixin:StylePlainButton(openBtn, "primary")
    self.openButton = openBtn

    if not Config or type(Config.Open) ~= "function" then
        message:SetText("Error: Loolib Config not available")
        message:SetTextColor(unpack(SkinningMixin:GetColor("danger")))
        openBtn:Disable()
    end
end

function SettingsPanelMixin:ApplyTheme()
    if self.headerFrame then
        self.headerFrame:SetBackdropColor(unpack(SkinningMixin:GetColor("header")))
    end
    if self.headerSeparator then
        self.headerSeparator:SetColorTexture(unpack(SkinningMixin:GetColor("accent")))
    end
    SkinningMixin:StyleText(self.titleText, "titleHuge", "text")
    SkinningMixin:StyleText(self.versionText, "bodySmall", "textMuted")
    if self.messageText then
        local colorKey = (Config and type(Config.Open) == "function") and "text" or "danger"
        SkinningMixin:StyleText(self.messageText, "title", colorKey)
    end
    SkinningMixin:StylePlainButton(self.openButton, "primary")
end

--[[--------------------------------------------------------------------
    Public Interface
----------------------------------------------------------------------]]

--- Refresh settings display
function SettingsPanelMixin:Refresh()
    if self.messageText then
        self.messageText:SetText(L["BLIZZARD_SETTINGS_DESC"])
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
