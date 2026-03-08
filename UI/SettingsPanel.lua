--[[--------------------------------------------------------------------
    Loothing - Loot Council Addon for WoW 12.0+
    SettingsPanel - Configuration UI (Using ConfigDialog)
----------------------------------------------------------------------]]

local Loolib = LibStub("Loolib")

local HEADER_HEIGHT = 56

--[[--------------------------------------------------------------------
    LoothingSettingsPanelMixin
----------------------------------------------------------------------]]

LoothingSettingsPanelMixin = {}

--- Initialize the settings panel
-- @param parent Frame - Parent frame
function LoothingSettingsPanelMixin:Init(parent)
    self.parent = parent

    self:CreateFrame()
    self:CreateHeader()
    self:CreateElements()
end

--- Create the main frame
function LoothingSettingsPanelMixin:CreateFrame()
    local frame = CreateFrame("Frame", nil, self.parent)
    frame:SetAllPoints()

    self.frame = frame
end

--- Create branding header: [logo] LOOTHING  v1.0.0
function LoothingSettingsPanelMixin:CreateHeader()
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
    title:SetText("LOOTHING")
    title:SetTextColor(1, 1, 1, 1)

    -- Version below title
    local versionStr = "v" .. (Loothing and Loothing.version or (LOOTHING_VERSION or ""))
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
function LoothingSettingsPanelMixin:CreateElements()
    -- Ensure LoolibConfig is initialized
    if not LoolibConfig or not LoolibConfig.Dialog or type(LoolibConfig.Dialog.Open) ~= "function" then
        -- Fallback: show error message
        local errText = self.frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        errText:SetPoint("CENTER")
        errText:SetText("Error: Loolib ConfigDialog not available")
        errText:SetTextColor(1, 0.3, 0.3)
        return
    end

    -- Create container for ConfigDialog, anchored below the header
    local container = CreateFrame("Frame", nil, self.frame)
    container:SetPoint("TOPLEFT", 0, -HEADER_HEIGHT)
    container:SetPoint("BOTTOMRIGHT", 0, 0)

    -- Open the dialog with our options table
    if LoothingOptionsTable then
        -- Register the options table if not already registered
        if not LoolibConfig:IsRegistered("Loothing") then
            LoolibConfig:RegisterOptionsTable("Loothing", LoothingOptionsTable)
        end

        -- Open dialog in our container
        LoolibConfig.Dialog:Open("Loothing", container)
    else
        -- Fallback: show error message
        local errText = container:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        errText:SetPoint("CENTER")
        errText:SetText("Error: LoothingOptionsTable not available")
        errText:SetTextColor(1, 0, 0)
    end

    self.container = container
end

--[[--------------------------------------------------------------------
    Public Interface
----------------------------------------------------------------------]]

--- Refresh settings display
function LoothingSettingsPanelMixin:Refresh()
    -- ConfigDialog handles this automatically when options change via get/set
    -- If we need to force a refresh, we can notify the system
    if LoolibConfig and LoolibConfig.Dialog then
        LoolibConfig.Dialog:RefreshContent("Loothing")
    end
end

--- Get the frame
-- @return Frame
function LoothingSettingsPanelMixin:GetFrame()
    return self.frame
end

--- Show the panel
function LoothingSettingsPanelMixin:Show()
    self.frame:Show()
    -- Refresh is handled by ConfigDialog automatically
end

--- Hide the panel
function LoothingSettingsPanelMixin:Hide()
    self.frame:Hide()
end

--[[--------------------------------------------------------------------
    Factory
----------------------------------------------------------------------]]

function CreateLoothingSettingsPanel(parent)
    local panel = LoolibCreateFromMixins(LoothingSettingsPanelMixin)
    panel:Init(parent)
    return panel
end
