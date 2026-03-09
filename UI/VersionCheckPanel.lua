--[[--------------------------------------------------------------------
    Loothing - Loot Council Addon for WoW 12.0+
    VersionCheckPanel - Displays addon version status for group/guild
----------------------------------------------------------------------]]

local Loolib = LibStub("Loolib")
local L = LOOTHING_LOCALE

--[[--------------------------------------------------------------------
    LoothingVersionCheckPanelMixin
----------------------------------------------------------------------]]

LoothingVersionCheckPanelMixin = LoolibCreateFromMixins(LoolibCallbackRegistryMixin)

local VC_EVENTS = {
    "OnQueryStarted",
    "OnQueryComplete",
}

local PANEL_WIDTH = 420
local PANEL_HEIGHT = 380
local ROW_HEIGHT = 22

--- Initialize the version check panel
function LoothingVersionCheckPanelMixin:Init()
    LoolibCallbackRegistryMixin.OnLoad(self)
    self:GenerateCallbackEvents(VC_EVENTS)

    self.entries = {}
    self.versionCallbackRegistered = false

    self:CreateFrame()
    self:CreateElements()
end

--- Create the main frame
function LoothingVersionCheckPanelMixin:CreateFrame()
    local frame = CreateFrame("Frame", "LoothingVersionCheckPanel", UIParent, "BackdropTemplate")
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
end

--- Create UI elements
function LoothingVersionCheckPanelMixin:CreateElements()
    -- Title
    self.title = self.frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    self.title:SetPoint("TOP", 0, -20)
    self.title:SetText(L["VERSION_CHECK"] or "Version Check")

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
    self.queryBtn:SetText(L["QUERY_GROUP"] or "Query Group")
    self.queryBtn:SetScript("OnClick", function()
        self:QueryVersions()
    end)

    -- Count summary
    self.countText = self.frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    self.countText:SetPoint("BOTTOMRIGHT", -20, 24)
    self.countText:SetTextColor(0.7, 0.7, 0.7)
end

--- Create column headers
function LoothingVersionCheckPanelMixin:CreateColumnHeaders()
    local headers = CreateFrame("Frame", nil, self.frame)
    headers:SetPoint("TOPLEFT", 20, -42)
    headers:SetPoint("TOPRIGHT", -20, -42)
    headers:SetHeight(20)

    local nameHeader = headers:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    nameHeader:SetPoint("LEFT", 4, 0)
    nameHeader:SetText(L["PLAYER"] or "Player")

    local versionHeader = headers:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    versionHeader:SetPoint("LEFT", 180, 0)
    versionHeader:SetText(L["VERSION"] or "Version")

    local statusHeader = headers:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    statusHeader:SetPoint("LEFT", 290, 0)
    statusHeader:SetText(L["STATUS"] or "Status")
end

--- Create scrollable list area
function LoothingVersionCheckPanelMixin:CreateScrollArea()
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
function LoothingVersionCheckPanelMixin:QueryVersions()
    wipe(self.entries)

    -- Gather current group members
    local roster = LoothingUtils.GetRaidRoster()
    if #roster > 0 then
        for _, member in ipairs(roster) do
            self.entries[member.name] = {
                name = member.name,
                class = member.classFile,
                version = nil,
                status = "querying",
            }
        end
    else
        -- Solo - show self
        local playerName = LoolibSecretUtil.SafeUnitName("player")
        if playerName then
            local _, playerClass = LoolibSecretUtil.SafeUnitClass("player")
            self.entries[playerName] = {
                name = playerName,
                class = playerClass,
                version = Loothing.version or LOOTHING_VERSION,
                status = "current",
            }
        end
    end

    -- Register for version responses (once)
    if not self.versionCallbackRegistered and LoothingVersionCheck then
        LoothingVersionCheck:RegisterCallback("OnVersionReceived", function(_, name, version)
            if self.entries[name] then
                self.entries[name].version = version
                self.entries[name].status = self:GetVersionStatus(version)
                self:RefreshList()
            end
        end, self)
        self.versionCallbackRegistered = true
    end

    -- Also pull any already-cached data from VersionCheck
    if LoothingVersionCheck then
        local cached = LoothingVersionCheck:GetSortedVersions()
        for _, entry in ipairs(cached) do
            if self.entries[entry.name] then
                self.entries[entry.name].version = entry.version
                self.entries[entry.name].status = self:GetVersionStatus(entry.version)
            end
        end

        -- Trigger the query
        LoothingVersionCheck:Query("raid")
    end

    self:RefreshList()
    self:TriggerEvent("OnQueryStarted")

    -- Timeout: mark remaining as "not installed" after 5 seconds
    C_Timer.After(5, function()
        for _, entry in pairs(self.entries) do
            if entry.status == "querying" then
                entry.version = L["NOT_INSTALLED"] or "N/A"
                entry.status = "not_installed"
            end
        end
        self:RefreshList()
        self:TriggerEvent("OnQueryComplete")
    end)
end

--- Determine version status relative to our version
-- @param version string
-- @return string - "current", "outdated", or "not_installed"
function LoothingVersionCheckPanelMixin:GetVersionStatus(version)
    if not version or version == "N/A" or version == "Not Installed" then
        return "not_installed"
    end

    local currentVersion = Loothing.version or LOOTHING_VERSION or "0.0.0"
    if version == currentVersion then
        return "current"
    end

    -- Use VersionCheck's comparator if available
    if LoothingVersionCheck and LoothingVersionCheck.IsOutdated then
        return LoothingVersionCheck:IsOutdated(version) and "outdated" or "current"
    end

    -- Fallback: simple string comparison
    return version < currentVersion and "outdated" or "current"
end

--[[--------------------------------------------------------------------
    List Display
----------------------------------------------------------------------]]

--- Refresh the version list display
function LoothingVersionCheckPanelMixin:RefreshList()
    self.rowPool:ReleaseAll()

    -- Sort entries by name
    local sorted = {}
    for _, entry in pairs(self.entries) do
        sorted[#sorted + 1] = entry
    end
    table.sort(sorted, function(a, b)
        return a.name < b.name
    end)

    local yOffset = 0
    local total, current, outdated, missing = #sorted, 0, 0, 0

    for _, entry in ipairs(sorted) do
        local row = self.rowPool:Acquire()
        row:SetSize(self.scrollContent:GetWidth(), ROW_HEIGHT)
        row:SetPoint("TOPLEFT", 0, -yOffset)

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
            current       = { text = L["CURRENT"] or "Current",       color = "|cff00ff00" },
            outdated      = { text = L["OUTDATED"] or "Outdated",     color = "|cffffff00" },
            not_installed = { text = L["NOT_INSTALLED"] or "Not Installed", color = "|cffff0000" },
            querying      = { text = "...",                           color = "|cff888888" },
        }
        local info = statusMap[entry.status] or statusMap.querying
        row.statusText:SetText(info.color .. info.text .. "|r")

        -- Tally counts
        if entry.status == "current" then
            current = current + 1
        elseif entry.status == "outdated" then
            outdated = outdated + 1
        elseif entry.status == "not_installed" then
            missing = missing + 1
        end

        row:Show()
        yOffset = yOffset + ROW_HEIGHT
    end

    self.scrollContent:SetHeight(math.max(1, yOffset + 4))

    self.countText:SetText(string.format(
        "%d total | %d current | %d outdated | %d missing",
        total, current, outdated, missing
    ))
end

--[[--------------------------------------------------------------------
    Visibility
----------------------------------------------------------------------]]

function LoothingVersionCheckPanelMixin:Show()
    self.frame:Show()
end

function LoothingVersionCheckPanelMixin:Hide()
    self.frame:Hide()
end

function LoothingVersionCheckPanelMixin:Toggle()
    if self.frame:IsShown() then
        self:Hide()
    else
        self:Show()
    end
end

function LoothingVersionCheckPanelMixin:IsShown()
    return self.frame:IsShown()
end

--[[--------------------------------------------------------------------
    Factory
----------------------------------------------------------------------]]

function CreateLoothingVersionCheckPanel()
    local panel = LoolibCreateFromMixins(LoothingVersionCheckPanelMixin)
    panel:Init()
    return panel
end
