--[[--------------------------------------------------------------------
    Loothing - Loot Council Addon for WoW 12.0+
    SyncPanel - Data synchronization dialog for settings and history
----------------------------------------------------------------------]]

local Loolib = LibStub("Loolib")
local L = LOOTHING_LOCALE

--[[--------------------------------------------------------------------
    LoothingSyncPanelMixin
----------------------------------------------------------------------]]

LoothingSyncPanelMixin = LoolibCreateFromMixins(LoolibCallbackRegistryMixin)

local SYNC_EVENTS = {
    "OnSyncStarted",
    "OnSyncComplete",
    "OnSyncFailed",
}

local PANEL_WIDTH = 350
local PANEL_HEIGHT = 280

--- Initialize the sync panel
function LoothingSyncPanelMixin:Init()
    LoolibCallbackRegistryMixin.OnLoad(self)
    self:GenerateCallbackEvents(SYNC_EVENTS)

    self.syncType = "settings"  -- "settings" or "history"
    self.targetPlayer = nil
    self.dateRange = "all"  -- "7", "30", "all"

    self:CreateFrame()
    self:CreateElements()
end

--- Create the main frame
function LoothingSyncPanelMixin:CreateFrame()
    local frame = CreateFrame("Frame", "LoothingSyncPanel", UIParent, "BackdropTemplate")
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
function LoothingSyncPanelMixin:CreateElements()
    -- Title
    self.title = self.frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    self.title:SetPoint("TOP", 0, -20)
    self.title:SetText(L["SYNC_DATA"] or "Sync Data")

    -- Close button
    self.closeButton = CreateFrame("Button", nil, self.frame, "UIPanelCloseButton")
    self.closeButton:SetPoint("TOPRIGHT", -5, -5)
    self.closeButton:SetScript("OnClick", function()
        self:Hide()
    end)

    -- Sync type buttons
    self:CreateSyncTypeButtons()

    -- Target player dropdown
    self:CreateTargetDropdown()

    -- Date range dropdown (history only)
    self:CreateDateRangeDropdown()

    -- Progress bar
    self:CreateProgressBar()

    -- Status text
    self.statusText = self.frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    self.statusText:SetPoint("BOTTOM", 0, 86)
    self.statusText:SetText("")

    -- Send button
    self.sendBtn = CreateFrame("Button", nil, self.frame, "UIPanelButtonTemplate")
    self.sendBtn:SetSize(120, 28)
    self.sendBtn:SetPoint("BOTTOM", 0, 24)
    self.sendBtn:SetText(L["SEND"] or "Send")
    self.sendBtn:SetScript("OnClick", function()
        self:StartSync()
    end)

    self:UpdateUI()
end

--- Create sync type toggle buttons
function LoothingSyncPanelMixin:CreateSyncTypeButtons()
    self.settingsBtn = CreateFrame("Button", nil, self.frame, "UIPanelButtonTemplate")
    self.settingsBtn:SetSize(120, 24)
    self.settingsBtn:SetPoint("TOPLEFT", 30, -50)
    self.settingsBtn:SetText(L["SETTINGS"] or "Settings")
    self.settingsBtn:SetScript("OnClick", function()
        self.syncType = "settings"
        self:UpdateUI()
    end)

    self.historyBtn = CreateFrame("Button", nil, self.frame, "UIPanelButtonTemplate")
    self.historyBtn:SetSize(120, 24)
    self.historyBtn:SetPoint("LEFT", self.settingsBtn, "RIGHT", 10, 0)
    self.historyBtn:SetText(L["HISTORY"] or "History")
    self.historyBtn:SetScript("OnClick", function()
        self.syncType = "history"
        self:UpdateUI()
    end)
end

--- Create target player dropdown using MenuUtil
function LoothingSyncPanelMixin:CreateTargetDropdown()
    local targetLabel = self.frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    targetLabel:SetPoint("TOPLEFT", 30, -86)
    targetLabel:SetText(L["SEND_TO"] or "Send To:")

    self.targetBtn = CreateFrame("Button", nil, self.frame, "UIPanelButtonTemplate")
    self.targetBtn:SetSize(200, 24)
    self.targetBtn:SetPoint("TOPLEFT", 100, -84)
    self.targetBtn:SetText(L["SELECT_TARGET"] or "Select Target...")
    self.targetBtn:SetScript("OnClick", function()
        self:ShowTargetMenu()
    end)
end

--- Show target selection context menu
function LoothingSyncPanelMixin:ShowTargetMenu()
    local members = self:GetOnlineMembers()

    MenuUtil.CreateContextMenu(self.targetBtn, function(ownerRegion, rootDescription)
        rootDescription:CreateTitle(L["SELECT_TARGET"] or "Select Target")

        -- Guild option
        rootDescription:CreateButton(L["GUILD"] or "Guild (All Online)", function()
            self.targetPlayer = "guild"
            self.targetBtn:SetText(L["GUILD"] or "Guild")
        end)

        rootDescription:CreateDivider()

        -- Individual members
        if #members > 0 then
            for _, member in ipairs(members) do
                rootDescription:CreateButton(member, function()
                    self.targetPlayer = member
                    self.targetBtn:SetText(member)
                end)
            end
        else
            rootDescription:CreateTitle(L["NO_TARGETS"] or "No online members found")
        end
    end)
end

--- Create date range dropdown (history sync only)
function LoothingSyncPanelMixin:CreateDateRangeDropdown()
    self.dateLabel = self.frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    self.dateLabel:SetPoint("TOPLEFT", 30, -118)
    self.dateLabel:SetText(L["DATE_RANGE"] or "Date Range:")

    self.dateBtn = CreateFrame("Button", nil, self.frame, "UIPanelButtonTemplate")
    self.dateBtn:SetSize(160, 24)
    self.dateBtn:SetPoint("TOPLEFT", 120, -116)
    self.dateBtn:SetText(L["ALL_TIME"] or "All Time")
    self.dateBtn:SetScript("OnClick", function()
        self:ShowDateRangeMenu()
    end)
end

--- Show date range context menu
function LoothingSyncPanelMixin:ShowDateRangeMenu()
    local ranges = {
        { value = "7", label = L["LAST_7_DAYS"] or "Last 7 Days" },
        { value = "30", label = L["LAST_30_DAYS"] or "Last 30 Days" },
        { value = "all", label = L["ALL_TIME"] or "All Time" },
    }

    MenuUtil.CreateContextMenu(self.dateBtn, function(ownerRegion, rootDescription)
        for _, range in ipairs(ranges) do
            rootDescription:CreateButton(range.label, function()
                self.dateRange = range.value
                self.dateBtn:SetText(range.label)
            end)
        end
    end)
end

--- Create progress bar
function LoothingSyncPanelMixin:CreateProgressBar()
    local progressBg = CreateFrame("Frame", nil, self.frame, "BackdropTemplate")
    progressBg:SetSize(310, 20)
    progressBg:SetPoint("BOTTOM", 0, 60)
    progressBg:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        tile = false,
        edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    progressBg:SetBackdropColor(0.05, 0.05, 0.05, 0.9)
    progressBg:SetBackdropBorderColor(0.2, 0.2, 0.2, 1)
    progressBg:Hide()
    self.progressBg = progressBg

    local progressBar = progressBg:CreateTexture(nil, "ARTWORK")
    progressBar:SetPoint("LEFT", 1, 0)
    progressBar:SetSize(0, 18)
    progressBar:SetColorTexture(0.2, 0.6, 0.2, 1)
    self.progressBar = progressBar

    local progressText = progressBg:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    progressText:SetPoint("CENTER")
    progressText:SetText("0%")
    self.progressText = progressText
end

--[[--------------------------------------------------------------------
    UI State
----------------------------------------------------------------------]]

--- Update UI based on current sync type selection
function LoothingSyncPanelMixin:UpdateUI()
    local isHistory = self.syncType == "history"
    self.dateLabel:SetShown(isHistory)
    self.dateBtn:SetShown(isHistory)

    -- Highlight active button via text color
    if isHistory then
        self.settingsBtn:GetFontString():SetTextColor(0.6, 0.6, 0.6)
        self.historyBtn:GetFontString():SetTextColor(1, 1, 1)
    else
        self.settingsBtn:GetFontString():SetTextColor(1, 1, 1)
        self.historyBtn:GetFontString():SetTextColor(0.6, 0.6, 0.6)
    end
end

--- Get online group/guild members
-- @return table - Sorted array of player names
function LoothingSyncPanelMixin:GetOnlineMembers()
    local members = {}
    local seen = {}
    local playerName = UnitName("player")

    -- Check raid/party
    local roster = LoothingUtils.GetRaidRoster()
    for _, member in ipairs(roster) do
        if member.name and member.name ~= playerName and not seen[member.name] then
            seen[member.name] = true
            members[#members + 1] = member.name
        end
    end

    -- Check guild
    if IsInGuild() then
        local numGuild = GetNumGuildMembers()
        for i = 1, numGuild do
            local name, _, _, _, _, _, _, _, online = GetGuildRosterInfo(i)
            if online and name and not seen[name] then
                -- Strip realm from guild roster names
                local shortName = Ambiguate(name, "short")
                if shortName ~= playerName then
                    seen[name] = true
                    members[#members + 1] = shortName
                end
            end
        end
    end

    table.sort(members)
    return members
end

--[[--------------------------------------------------------------------
    Sync Execution
----------------------------------------------------------------------]]

--- Start the sync operation
function LoothingSyncPanelMixin:StartSync()
    if not self.targetPlayer then
        self.statusText:SetText("|cffff0000" .. (L["SELECT_TARGET_FIRST"] or "Select a target player") .. "|r")
        return
    end

    self.progressBg:Show()
    self.progressBar:SetWidth(0)
    self.progressText:SetText("0%")
    self.statusText:SetText(string.format(
        L["SYNCING_TO"] or "Syncing %s to %s...",
        self.syncType, self.targetPlayer
    ))
    self.sendBtn:Disable()

    self:TriggerEvent("OnSyncStarted", self.syncType, self.targetPlayer)

    if self.syncType == "settings" then
        if Loothing.Sync then
            Loothing.Sync:RequestSettingsSync(self.targetPlayer)
        end
    elseif self.syncType == "history" then
        local days = self.dateRange == "all" and 365 or tonumber(self.dateRange) or 7
        if Loothing.Sync then
            Loothing.Sync:RequestHistorySync(self.targetPlayer, days)
        end
    end

    -- Set progress to full after initiating (actual callbacks from Sync module drive real progress)
    -- Use a short timer to allow the comm to fire
    C_Timer.After(1, function()
        self:SetProgress(1.0)
        self:TriggerEvent("OnSyncComplete", self.syncType, self.targetPlayer)
    end)
end

--- Set progress bar percentage
-- @param pct number - 0.0 to 1.0
function LoothingSyncPanelMixin:SetProgress(pct)
    pct = math.max(0, math.min(1, pct))
    local maxWidth = self.progressBg:GetWidth() - 2
    self.progressBar:SetWidth(math.max(1, maxWidth * pct))
    self.progressText:SetText(math.floor(pct * 100) .. "%")

    if pct >= 1.0 then
        self.statusText:SetText("|cff00ff00" .. (L["SYNC_COMPLETE"] or "Sync complete!") .. "|r")
        self.sendBtn:Enable()
    end
end

--[[--------------------------------------------------------------------
    Visibility
----------------------------------------------------------------------]]

function LoothingSyncPanelMixin:Show()
    self.frame:Show()
end

function LoothingSyncPanelMixin:Hide()
    self.frame:Hide()
end

function LoothingSyncPanelMixin:Toggle()
    if self.frame:IsShown() then
        self:Hide()
    else
        self:Show()
    end
end

function LoothingSyncPanelMixin:IsShown()
    return self.frame:IsShown()
end

--[[--------------------------------------------------------------------
    Factory
----------------------------------------------------------------------]]

function CreateLoothingSyncPanel()
    local panel = LoolibCreateFromMixins(LoothingSyncPanelMixin)
    panel:Init()
    return panel
end
