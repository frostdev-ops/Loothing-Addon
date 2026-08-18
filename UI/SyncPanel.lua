--[[--------------------------------------------------------------------
    Loothing - Loot Council Addon for WoW 12.0+
    SyncPanel - Data synchronization dialog for settings and history
----------------------------------------------------------------------]]

local _, ns = ...
local Loolib = LibStub("Loolib")
local Loothing = ns.Addon
local Utils = ns.Utils
local L = Loothing.Locale
local SkinningMixin = ns.SkinningMixin

local AnimationUtil = Loolib.AnimationUtil
local AnimationPresets = Loolib.AnimationPresets
local PixelUtil = Loolib.PixelUtil

-- Animation durations
local SHOW_DURATION = 0.22
local HIDE_DURATION = 0.13
local INDICATOR_SLIDE_DURATION = 0.22

local ApplyAccentGlow = ns.FramePolish.ApplyAccentGlow
local AttachIconButtonPolish = ns.FramePolish.AttachIconButtonPolish

--[[--------------------------------------------------------------------
    SyncPanelMixin
----------------------------------------------------------------------]]

local SyncPanelMixin = ns.SyncPanelMixin or Loolib.CreateFromMixins(Loolib.CallbackRegistryMixin)
ns.SyncPanelMixin = SyncPanelMixin

local SYNC_EVENTS = {
    "OnSyncStarted",
    "OnSyncComplete",
    "OnSyncFailed",
}

local PANEL_WIDTH = 350
local PANEL_HEIGHT = 280

--- Initialize the sync panel
function SyncPanelMixin:Init()
    Loolib.CallbackRegistryMixin.OnLoad(self)
    self:GenerateCallbackEvents(SYNC_EVENTS)

    self.syncType = "settings"  -- "settings" or "history"
    self.targetPlayer = nil
    self.dateRange = "all"  -- "7", "30", "all"

    self:CreateFrame()
    self:CreateElements()
end

--- Create the main frame
function SyncPanelMixin:CreateFrame()
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

    -- Start hidden-alpha so the first Show() can fade in
    frame:SetAlpha(0)

    -- Accent glow strip: soft fade-from-accent-to-transparent behind the title.
    local headerStrip = frame:CreateTexture(nil, "BACKGROUND", nil, 2)
    headerStrip:SetPoint("TOPLEFT", 12, -12)
    headerStrip:SetPoint("TOPRIGHT", -12, -12)
    headerStrip:SetHeight(30)
    headerStrip:SetColorTexture(1, 1, 1, 1)
    self.headerStrip = headerStrip
    ApplyAccentGlow(headerStrip, 0.18)

    -- Pixel-perfect outer border
    if PixelUtil and type(PixelUtil.SetThinBorder) == "function" then
        self.pixelBorder = PixelUtil.SetThinBorder(frame, SkinningMixin and SkinningMixin:GetColor("borderStrong") or { 0.2, 0.2, 0.2, 1 })
    end

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
    ns.SyncPanelFrame = frame

    local WM = Loolib:GetModule("WindowManager")
    if WM then WM:Register(frame) end
end

--- Create UI elements
function SyncPanelMixin:CreateElements()
    -- Title
    self.title = self.frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    self.title:SetPoint("TOP", 0, -20)
    self.title:SetText(L["SYNC_DATA"])

    -- Close button
    self.closeButton = CreateFrame("Button", nil, self.frame, "UIPanelCloseButton")
    self.closeButton:SetPoint("TOPRIGHT", -5, -5)
    self.closeButton:SetScript("OnClick", function()
        self:Hide()
    end)
    AttachIconButtonPolish(self.closeButton, { hoverScale = 1.15, pressScale = 0.90 })

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
    self.sendBtn = ns.CreateThemedButton(self.frame)
    self.sendBtn:SetSize(120, 28)
    self.sendBtn:SetPoint("BOTTOM", 0, 24)
    self.sendBtn:SetText(L["SEND"])
    ns.SkinningMixin:StylePlainButton(self.sendBtn)
    self.sendBtn:SetScript("OnClick", function()
        self:StartSync()
    end)

    self:UpdateUI()
end

--- Create sync type toggle buttons
function SyncPanelMixin:CreateSyncTypeButtons()
    self.settingsBtn = ns.CreateThemedButton(self.frame)
    self.settingsBtn:SetSize(100, 24)
    self.settingsBtn:SetPoint("TOPLEFT", 20, -50)
    self.settingsBtn:SetText(L["SETTINGS"])
    ns.SkinningMixin:StylePlainButton(self.settingsBtn)
    self.settingsBtn:SetScript("OnClick", function()
        self.syncType = "settings"
        self:UpdateUI()
    end)

    self.historyBtn = ns.CreateThemedButton(self.frame)
    self.historyBtn:SetSize(100, 24)
    self.historyBtn:SetPoint("LEFT", self.settingsBtn, "RIGHT", 8, 0)
    self.historyBtn:SetText(L["HISTORY"])
    ns.SkinningMixin:StylePlainButton(self.historyBtn)
    self.historyBtn:SetScript("OnClick", function()
        self.syncType = "history"
        self:UpdateUI()
    end)

    self.intelBtn = ns.CreateThemedButton(self.frame)
    self.intelBtn:SetSize(100, 24)
    self.intelBtn:SetPoint("LEFT", self.historyBtn, "RIGHT", 8, 0)
    self.intelBtn:SetText(L["INTEL_SHARE"])
    ns.SkinningMixin:StylePlainButton(self.intelBtn)
    self.intelBtn:SetScript("OnClick", function()
        self.syncType = "intel"
        self.targetPlayer = nil
        self.targetBtn:SetText(L["SELECT_TARGET"])
        self:UpdateUI()
    end)

    -- Shared sliding indicator under the active sync-type button.
    local indicator = self.frame:CreateTexture(nil, "OVERLAY", nil, 7)
    indicator:SetHeight(3)
    indicator:SetWidth(0)
    indicator:SetColorTexture(1, 1, 1, 1)
    indicator:Hide()
    self.typeIndicator = indicator
end

--- Slide the shared sync-type indicator to the active button.
function SyncPanelMixin:MoveTypeIndicatorTo(button)
    if not self.typeIndicator or not button then return end
    local indicator = self.typeIndicator

    local accent = (SkinningMixin and SkinningMixin:GetColor("accent")) or { 0.4, 0.55, 0.9, 1 }
    indicator:SetVertexColor(accent[1] or 0.4, accent[2] or 0.55, accent[3] or 0.9, accent[4] or 1)
    indicator:Show()

    local targetWidth = math.max(0, (button:GetWidth() or 100) - 8)
    local skipAnim = not self.frame or not self.frame:IsVisible() or not self._typeIndicatorPositioned

    if not AnimationUtil or skipAnim then
        indicator:ClearAllPoints()
        indicator:SetPoint("BOTTOMLEFT", button, "BOTTOMLEFT", 4, -3)
        indicator:SetWidth(targetWidth)
        self._typeIndicatorPositioned = true
        self._typeIndicatorAnchor = button
        return
    end

    -- Re-anchor to new button with same width, then tween width.
    local currentWidth = indicator:GetWidth() or 0
    indicator:ClearAllPoints()
    indicator:SetPoint("BOTTOMLEFT", button, "BOTTOMLEFT", 4, -3)
    indicator:SetWidth(currentWidth)

    if self._typeIndicatorGroup then self._typeIndicatorGroup:Stop() end
    local group = AnimationUtil.CreateGroup(indicator)
    group:CreateAnimation("width", {
        target = indicator,
        from = currentWidth,
        to = targetWidth,
        duration = INDICATOR_SLIDE_DURATION,
        easing = "outCubic",
    })
    group:SetOnFinished(function()
        indicator:ClearAllPoints()
        indicator:SetPoint("BOTTOMLEFT", button, "BOTTOMLEFT", 4, -3)
        indicator:SetWidth(targetWidth)
    end)
    self._typeIndicatorGroup = group
    self._typeIndicatorAnchor = button
    self._typeIndicatorPositioned = true
    group:Play()
end

--- Resolve the button for the current sync type.
function SyncPanelMixin:GetActiveTypeButton()
    if self.syncType == "history" then return self.historyBtn end
    if self.syncType == "intel" then return self.intelBtn end
    return self.settingsBtn
end

--- Create target player dropdown using MenuUtil
function SyncPanelMixin:CreateTargetDropdown()
    local targetLabel = self.frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    targetLabel:SetPoint("TOPLEFT", 30, -86)
    targetLabel:SetText(L["SEND_TO"])

    self.targetBtn = ns.CreateThemedButton(self.frame)
    self.targetBtn:SetSize(200, 24)
    self.targetBtn:SetPoint("TOPLEFT", 100, -84)
    self.targetBtn:SetText(L["SELECT_TARGET"])
    ns.SkinningMixin:StylePlainButton(self.targetBtn)
    self.targetBtn:SetScript("OnClick", function()
        self:ShowTargetMenu()
    end)
end

--- Show target selection context menu
function SyncPanelMixin:ShowTargetMenu()
    local isIntel = self.syncType == "intel"
    local members = not isIntel and self:GetOnlineMembers() or {}

    MenuUtil.CreateContextMenu(self.targetBtn, function(_ownerRegion, rootDescription)
        rootDescription:CreateTitle(L["SELECT_TARGET"])

        -- Intel share: only Group and Guild options (no individual players)
        if isIntel then
            rootDescription:CreateButton(L["INTEL_SHARE_GROUP"], function()
                self.targetPlayer = "group"
                self.targetBtn:SetText(L["INTEL_SHARE_GROUP"])
            end)
            rootDescription:CreateButton(L["INTEL_SHARE_GUILD"], function()
                self.targetPlayer = "guild"
                self.targetBtn:SetText(L["INTEL_SHARE_GUILD"])
            end)
            return
        end

        -- Guild option
        rootDescription:CreateButton(L["GUILD"], function()
            self.targetPlayer = "guild"
            self.targetBtn:SetText(L["GUILD"])
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
            rootDescription:CreateTitle(L["NO_TARGETS"])
        end
    end)
end

--- Create date range dropdown (history sync only)
function SyncPanelMixin:CreateDateRangeDropdown()
    self.dateLabel = self.frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    self.dateLabel:SetPoint("TOPLEFT", 30, -118)
    self.dateLabel:SetText(L["DATE_RANGE"])

    self.dateBtn = ns.CreateThemedButton(self.frame)
    self.dateBtn:SetSize(160, 24)
    self.dateBtn:SetPoint("TOPLEFT", 120, -116)
    self.dateBtn:SetText(L["ALL_TIME"])
    ns.SkinningMixin:StylePlainButton(self.dateBtn)
    self.dateBtn:SetScript("OnClick", function()
        self:ShowDateRangeMenu()
    end)
end

--- Show date range context menu
function SyncPanelMixin:ShowDateRangeMenu()
    local ranges = {
        { value = "7", label = L["LAST_7_DAYS"] },
        { value = "30", label = L["LAST_30_DAYS"] },
        { value = "all", label = L["ALL_TIME"] },
    }

    MenuUtil.CreateContextMenu(self.dateBtn, function(_ownerRegion, rootDescription)
        for _, range in ipairs(ranges) do
            rootDescription:CreateButton(range.label, function()
                self.dateRange = range.value
                self.dateBtn:SetText(range.label)
            end)
        end
    end)
end

--- Create progress bar
function SyncPanelMixin:CreateProgressBar()
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
function SyncPanelMixin:UpdateUI()
    local isHistory = self.syncType == "history"
    local isIntel = self.syncType == "intel"
    self.dateLabel:SetShown(isHistory)
    self.dateBtn:SetShown(isHistory)

    -- Highlight active button via text color
    local activeColor = { 1, 1, 1 }
    local dimColor = { 0.6, 0.6, 0.6 }
    self.settingsBtn:GetFontString():SetTextColor(unpack(self.syncType == "settings" and activeColor or dimColor))
    self.historyBtn:GetFontString():SetTextColor(unpack(isHistory and activeColor or dimColor))
    self.intelBtn:GetFontString():SetTextColor(unpack(isIntel and activeColor or dimColor))

    -- Intel-specific: show dataset info, update send button label
    if self.intelStatusText then
        self.intelStatusText:SetShown(isIntel)
    end
    if isIntel then
        self:UpdateIntelStatus()
    end

    -- Slide the sync-type indicator to the active button.
    if self.MoveTypeIndicatorTo then
        self:MoveTypeIndicatorTo(self:GetActiveTypeButton())
    end
end

--- Get online group/guild members
-- @return table - Sorted array of player names
function SyncPanelMixin:GetOnlineMembers()
    local members = {}
    local seen = {}
    local playerName = Loolib.SecretUtil.SafeUnitName("player")

    -- Check raid/party
    local roster = Utils.GetRaidRoster()
    for _, member in ipairs(roster) do
        -- IsSamePlayer, not ~=: raid roster names carry realm suffixes while
        -- SafeUnitName("player") is short — the plain compare listed yourself
        -- as a sync target in raids.
        if member.name and not Utils.IsSamePlayer(member.name, playerName)
            and not seen[member.name] then
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
function SyncPanelMixin:StartSync()
    if not self.targetPlayer then
        self.statusText:SetText("|cffff0000" .. (L["SELECT_TARGET_FIRST"]) .. "|r")
        return
    end

    self.progressBg:Show()
    self.progressBar:SetWidth(0)
    self.progressText:SetText("0%")
    self.statusText:SetText(string.format(
        L["SYNCING_TO"],
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
    elseif self.syncType == "intel" then
        if Loothing.IntelShare then
            local target = self.targetPlayer == "guild" and "guild" or "group"
            local ok, err = Loothing.IntelShare:StartShare(target)
            if not ok then
                self.statusText:SetText("|cffff0000" .. (err or "") .. "|r")
                self.progressBg:Hide()
                self.sendBtn:Enable()
                return
            end
            -- Drive progress bar from IntelShare callbacks
            self:RegisterIntelShareCallbacks()
            return  -- Don't auto-complete; callbacks handle progress
        end
        -- IntelShare module not loaded
        self.statusText:SetText("|cffff0000" .. L["INTEL_SHARE_NO_DATA"] .. "|r")
        self.progressBg:Hide()
        self.sendBtn:Enable()
        return
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
function SyncPanelMixin:SetProgress(pct)
    pct = math.max(0, math.min(1, pct))
    local maxWidth = self.progressBg:GetWidth() - 2
    self.progressBar:SetWidth(math.max(1, maxWidth * pct))
    self.progressText:SetText(math.floor(pct * 100) .. "%")

    if pct >= 1.0 then
        self.statusText:SetText("|cff00ff00" .. (L["SYNC_COMPLETE"]) .. "|r")
        self.sendBtn:Enable()
    end
end

--[[--------------------------------------------------------------------
    Visibility
----------------------------------------------------------------------]]

function SyncPanelMixin:Show()
    if self.frame._loothingFadeGroup then self.frame._loothingFadeGroup:Stop() end

    self.frame:Show()
    self.frame:Raise()

    -- Re-apply custom accents in case skin/accent changed while hidden.
    if self.ApplyTheme then self:ApplyTheme() end

    -- Snap indicator once layout is final (skip-anim on first show).
    if self.MoveTypeIndicatorTo then
        self:MoveTypeIndicatorTo(self:GetActiveTypeButton())
    end

    if AnimationPresets then
        self.frame._loothingFadeGroup = AnimationPresets.FadeIn(self.frame, SHOW_DURATION, "outCubic")
    else
        self.frame:SetAlpha(1)
    end
end

function SyncPanelMixin:Hide()
    if self.frame._loothingFadeGroup then self.frame._loothingFadeGroup:Stop() end
    if AnimationPresets then
        self.frame._loothingFadeGroup = AnimationPresets.FadeOut(self.frame, HIDE_DURATION, "inCubic", true, function()
            self.frame:SetAlpha(0)
        end)
    else
        self.frame:Hide()
    end
end

function SyncPanelMixin:Toggle()
    if self.frame:IsShown() then
        self:Hide()
    else
        self:Show()
    end
end

function SyncPanelMixin:IsShown()
    return self.frame:IsShown()
end

--- Re-apply custom accents, pixel border, indicator color from the current theme.
--- Called from Show() because SyncPanel isn't in SkinningMixin:RefreshTheme's static
--- ApplyTheme chain; re-apply on each open keeps it in sync with Frame Behavior settings.
function SyncPanelMixin:ApplyTheme()
    if self.headerStrip then
        ApplyAccentGlow(self.headerStrip, 0.18)
        self.headerStrip:SetAlpha(1)
    end
    if self.pixelBorder and PixelUtil then
        local c = (SkinningMixin and SkinningMixin:GetColor("borderStrong")) or { 0, 0, 0, 1 }
        for _, tex in pairs(self.pixelBorder) do
            if type(tex) == "table" and type(tex.SetColorTexture) == "function" then
                tex:SetColorTexture(c[1] or 0, c[2] or 0, c[3] or 0, c[4] or 1)
            end
        end
    end
    if self.typeIndicator then
        local accent = (SkinningMixin and SkinningMixin:GetColor("accent")) or { 0.4, 0.55, 0.9, 1 }
        self.typeIndicator:SetVertexColor(accent[1] or 0.4, accent[2] or 0.55, accent[3] or 0.9, accent[4] or 1)
    end
end

--[[--------------------------------------------------------------------
    Intel Share Integration
----------------------------------------------------------------------]]

--- Update the intel status text showing available datasets
function SyncPanelMixin:UpdateIntelStatus()
    if not self.intelStatusText then
        -- Plug icon sits to the left; text flows after it.
        self.intelStatusIcon = self.frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        self.intelStatusIcon:SetPoint("TOPLEFT", 30, -118)
        Loolib.Fonts:SetIconFont(self.intelStatusIcon, 12, "")

        self.intelStatusText = self.frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        self.intelStatusText:SetPoint("LEFT", self.intelStatusIcon, "RIGHT", 6, 0)
        -- Preserve the original 290px width budget (the icon + 6px gap
        -- consume some of it, so the text column shrinks to ~270px which
        -- still fits the INTEL_SHARE_* strings).
        self.intelStatusText:SetWidth(290 - 18)
        self.intelStatusText:SetJustifyH("LEFT")
        self.intelStatusText:SetWordWrap(true)
    end

    local function setOffline(msg)
        self.intelStatusIcon:SetText(Loolib.Fonts:Icon("plug-circle-xmark"))
        self.intelStatusIcon:SetTextColor(1.0, 0.30, 0.30)
        self.intelStatusText:SetText("|cffff0000" .. msg .. "|r")
    end

    local function setOnline(msg)
        self.intelStatusIcon:SetText(Loolib.Fonts:Icon("plug-circle-check"))
        self.intelStatusIcon:SetTextColor(0.20, 1.0, 0.60)
        self.intelStatusText:SetText("|cff33ff99" .. msg .. "|r")
    end

    if not Loothing.IntelShare then
        setOffline(L["INTEL_SHARE_NO_DATA"])
        self.sendBtn:Disable()
        return
    end

    local _, count = Loothing.IntelShare:GetAvailableDatasets()
    if count == 0 then
        setOffline(L["INTEL_SHARE_NO_DATA"])
        self.sendBtn:Disable()
    else
        setOnline(string.format(L["INTEL_SHARE_DATASETS_READY"], count))
        self.sendBtn:Enable()
    end
end

--- Register callbacks for intel share progress tracking
function SyncPanelMixin:RegisterIntelShareCallbacks()
    if not Loothing.IntelShare or self.intelCallbacksRegistered then return end
    self.intelCallbacksRegistered = true

    Loothing.IntelShare:RegisterCallback("OnIntelShareProgress", function(_, transferID, index, name)
        if not self.frame:IsShown() then return end
        local _, total = Loothing.IntelShare:GetSendProgress()
        total = total or 5
        self:SetProgress(index / total)
    end, self)

    Loothing.IntelShare:RegisterCallback("OnIntelShareComplete", function()
        if not self.frame:IsShown() then return end
        self:SetProgress(1.0)
        self:TriggerEvent("OnSyncComplete", "intel", self.targetPlayer)
    end, self)

    Loothing.IntelShare:RegisterCallback("OnIntelShareFailed", function(_, transferID, reason)
        if not self.frame:IsShown() then return end
        self.statusText:SetText("|cffff0000" .. (reason or "Share failed") .. "|r")
        self.sendBtn:Enable()
    end, self)
end

--[[--------------------------------------------------------------------
    Factory
----------------------------------------------------------------------]]

local function CreateSyncPanel()
    local panel = Loolib.CreateFromMixins(SyncPanelMixin)
    panel:Init()
    return panel
end

ns.CreateSyncPanel = CreateSyncPanel
