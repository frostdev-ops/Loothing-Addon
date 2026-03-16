--[[--------------------------------------------------------------------
    Loothing - Loot Council Addon for WoW 12.0+
    VersionCheckPanel - Displays addon version status for group/guild
----------------------------------------------------------------------]]

local _, ns = ...
local Loolib = LibStub("Loolib")
local Loothing = ns.Addon
local L = ns.Locale
local VersionCheck = ns.VersionCheck
local C_Timer = C_Timer

--[[--------------------------------------------------------------------
    VersionCheckPanelMixin
----------------------------------------------------------------------]]

local VersionCheckPanelMixin = ns.VersionCheckPanelMixin or Loolib.CreateFromMixins(Loolib.CallbackRegistryMixin)
ns.VersionCheckPanelMixin = VersionCheckPanelMixin

local VC_EVENTS = {
    "OnQueryStarted",
    "OnQueryComplete",
}

local PANEL_WIDTH = 420
local PANEL_HEIGHT = 380
local ROW_HEIGHT = 22

--- Initialize the version check panel
function VersionCheckPanelMixin:Init()
    Loolib.CallbackRegistryMixin.OnLoad(self)
    self:GenerateCallbackEvents(VC_EVENTS)

    self.entries = {}
    self.versionCallbackRegistered = false
    self.rowsByName = {}
    self.refreshToken = 0

    self:CreateFrame()
    self:CreateElements()
    self:RegisterVersionCallbacks()
end

function VersionCheckPanelMixin:RegisterVersionCallbacks()
    if self.versionCallbackRegistered or not VersionCheck then
        return
    end

    VersionCheck:RegisterCallback("OnVersionReceived", function()
        self:ScheduleRefresh(0.1)
    end, self)
    VersionCheck:RegisterCallback("OnQueryComplete", function()
        self:ScheduleRefresh(0)
        self:TriggerEvent("OnQueryComplete")
    end, self)
    self.versionCallbackRegistered = true
end

function VersionCheckPanelMixin:ScheduleRefresh(delay)
    self.refreshToken = (self.refreshToken or 0) + 1
    local token = self.refreshToken
    C_Timer.After(delay or 0, function()
        if self.refreshToken == token and self.frame and self.frame:IsShown() then
            self:RefreshList()
        end
    end)
end

--- Create the main frame
function VersionCheckPanelMixin:CreateFrame()
    local frame = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    frame:SetSize(PANEL_WIDTH, PANEL_HEIGHT)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("DIALOG")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:SetClampedToScreen(true)
    frame:Hide()

    frame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true,
        tileSize = 32,
        edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 },
    })

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
    ns.VersionCheckPanelFrame = frame

    local WM = Loolib:GetModule("WindowManager")
    if WM then WM:Register(frame) end
end

--- Create UI elements
function VersionCheckPanelMixin:CreateElements()
    -- Title
    self.title = self.frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    self.title:SetPoint("TOP", 0, -20)
    self.title:SetText(L["VERSION_CHECK"])

    -- Close button
    self.closeButton = CreateFrame("Button", nil, self.frame, "UIPanelCloseButton")
    self.closeButton:SetPoint("TOPRIGHT", -5, -5)
    self.closeButton:SetScript("OnClick", function()
        self:Hide()
    end)

    -- Column headers
    self:CreateColumnHeaders()

    -- Separator
    local sep = self.frame:CreateTexture(nil, "ARTWORK")
    sep:SetPoint("TOPLEFT", 20, -62)
    sep:SetPoint("TOPRIGHT", -20, -62)
    sep:SetHeight(1)
    sep:SetColorTexture(0.4, 0.4, 0.4, 0.6)

    -- Scroll area
    self:CreateScrollArea()

    -- Query button
    self.queryBtn = CreateFrame("Button", nil, self.frame, "UIPanelButtonTemplate")
    self.queryBtn:SetSize(140, 26)
    self.queryBtn:SetPoint("BOTTOMLEFT", 20, 18)
    self.queryBtn:SetText(L["QUERY_GROUP"])
    self.queryBtn:SetScript("OnClick", function()
        self:QueryVersions()
    end)

    -- Count summary
    self.countText = self.frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    self.countText:SetPoint("BOTTOMRIGHT", -20, 24)
    self.countText:SetTextColor(0.7, 0.7, 0.7)
end

--- Create column headers
function VersionCheckPanelMixin:CreateColumnHeaders()
    local headers = CreateFrame("Frame", nil, self.frame)
    headers:SetPoint("TOPLEFT", 20, -42)
    headers:SetPoint("TOPRIGHT", -20, -42)
    headers:SetHeight(20)

    local nameHeader = headers:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    nameHeader:SetPoint("LEFT", 4, 0)
    nameHeader:SetText(L["PLAYER"])

    local versionHeader = headers:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    versionHeader:SetPoint("LEFT", 180, 0)
    versionHeader:SetText(L["VERSION"])

    local statusHeader = headers:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    statusHeader:SetPoint("LEFT", 290, 0)
    statusHeader:SetText(L["STATUS"])
end

--- Create scrollable list area
function VersionCheckPanelMixin:CreateScrollArea()
    local container = CreateFrame("Frame", nil, self.frame, "BackdropTemplate")
    container:SetPoint("TOPLEFT", 16, -66)
    container:SetPoint("BOTTOMRIGHT", -16, 50)
    container:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        tile = false,
        edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    container:SetBackdropColor(0.05, 0.05, 0.05, 0.9)
    container:SetBackdropBorderColor(0.2, 0.2, 0.2, 1)

    local scrollFrame = CreateFrame("ScrollFrame", nil, container, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 4, -4)
    scrollFrame:SetPoint("BOTTOMRIGHT", -24, 4)

    local content = CreateFrame("Frame", nil, scrollFrame)
    content:SetWidth(scrollFrame:GetWidth())
    content:SetHeight(1)
    scrollFrame:SetScrollChild(content)

    self.scrollContainer = container
    self.scrollContent = content
    self.rowPool = CreateFramePool("Frame", content)
end

--[[--------------------------------------------------------------------
    Version Query
----------------------------------------------------------------------]]

--- Query versions from group/guild members
function VersionCheckPanelMixin:QueryVersions()
    if not VersionCheck then
        return
    end

    if IsInRaid() or IsInGroup() then
        VersionCheck:Query("raid")
    elseif IsInGuild() then
        VersionCheck:Query("guild")
    end

    self:RefreshList()
    self:TriggerEvent("OnQueryStarted")
end

--- Determine version status relative to our version
-- @param version string
-- @return string - "current", "outdated", or "not_installed"
function VersionCheckPanelMixin:GetVersionStatus(version)
    if not version or version == "N/A" or version == "Not Installed" then
        return "not_installed"
    end

    local currentVersion = Loothing.version or Loothing.VERSION or "0.0.0"
    if version == currentVersion then
        return "current"
    end

    -- Use VersionCheck's comparator if available
    if VersionCheck and VersionCheck.IsOutdated then
        return VersionCheck:IsOutdated(version) and "outdated" or "current"
    end

    -- Fallback: simple string comparison
    return version < currentVersion and "outdated" or "current"
end

--[[--------------------------------------------------------------------
    List Display
----------------------------------------------------------------------]]

--- Refresh the version list display
function VersionCheckPanelMixin:RefreshList()
    local snapshot = VersionCheck and VersionCheck.GetRosterSnapshot and VersionCheck:GetRosterSnapshot() or {
        entries = {},
        counts = { total = 0, current = 0, outdated = 0, notInstalled = 0 },
    }
    local sorted = snapshot.entries
    local activeRows = {}

    local yOffset = 0
    for _, entry in ipairs(sorted) do
        local row = self.rowsByName[entry.name]
        if not row then
            row = CreateFrame("Frame", nil, self.scrollContent)
            self.rowsByName[entry.name] = row
        end
        row:SetSize(self.scrollContent:GetWidth(), ROW_HEIGHT)
        row:SetPoint("TOPLEFT", 0, -yOffset)
        activeRows[entry.name] = true

        -- Lazily create font strings on first use
        if not row.nameText then
            row.nameText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            row.nameText:SetPoint("LEFT", 4, 0)
            row.nameText:SetWidth(170)
            row.nameText:SetJustifyH("LEFT")

            row.versionText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            row.versionText:SetPoint("LEFT", 176, 0)
            row.versionText:SetWidth(100)

            row.statusText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            row.statusText:SetPoint("LEFT", 286, 0)
            row.statusText:SetWidth(90)
        end

        -- Class-colored name
        local classColor = RAID_CLASS_COLORS and RAID_CLASS_COLORS[entry.class]
        if classColor then
            row.nameText:SetText(string.format(
                "|cff%02x%02x%02x%s|r",
                classColor.r * 255, classColor.g * 255, classColor.b * 255,
                entry.name
            ))
        else
            row.nameText:SetText(entry.name)
        end

        row.versionText:SetText(entry.version or "...")

        -- Status color coding
        local statusMap = {
            current       = { text = L["CURRENT"],       color = "|cff00ff00" },
            outdated      = { text = L["OUTDATED"],     color = "|cffffff00" },
            not_installed = { text = L["NOT_INSTALLED"], color = "|cffff0000" },
            querying      = { text = "...",                           color = "|cff888888" },
        }
        local status = entry.version and self:GetVersionStatus(entry.version) or (VersionCheck and VersionCheck.queryInProgress and "querying" or "not_installed")
        local info = statusMap[status] or statusMap.querying
        row.statusText:SetText(info.color .. info.text .. "|r")

        row:Show()
        yOffset = yOffset + ROW_HEIGHT
    end

    for name, row in pairs(self.rowsByName) do
        if not activeRows[name] then
            row:Hide()
        end
    end

    self.scrollContent:SetHeight(math.max(1, yOffset + 4))

    self.countText:SetText(string.format(
        "%d total | %d current | %d outdated | %d missing",
        snapshot.counts.total, snapshot.counts.current, snapshot.counts.outdated, snapshot.counts.notInstalled
    ))
end

--[[--------------------------------------------------------------------
    Visibility
----------------------------------------------------------------------]]

function VersionCheckPanelMixin:Show()
    self.frame:Show()
    self.frame:Raise()
    self:RefreshList()
end

function VersionCheckPanelMixin:Hide()
    self.frame:Hide()
end

function VersionCheckPanelMixin:Toggle()
    if self.frame:IsShown() then
        self:Hide()
    else
        self:Show()
    end
end

function VersionCheckPanelMixin:IsShown()
    return self.frame:IsShown()
end

--[[--------------------------------------------------------------------
    Factory
----------------------------------------------------------------------]]

local function CreateVersionCheckPanel()
    local panel = Loolib.CreateFromMixins(VersionCheckPanelMixin)
    panel:Init()
    return panel
end

ns.CreateVersionCheckPanel = CreateVersionCheckPanel
