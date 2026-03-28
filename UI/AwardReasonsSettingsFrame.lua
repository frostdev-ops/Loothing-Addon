--[[--------------------------------------------------------------------
    Loothing - Loot Council Addon for WoW 12.0+
    AwardReasonsSettingsFrame - Visual editor for award reasons
----------------------------------------------------------------------]]

local _, ns = ...
local Loolib = LibStub("Loolib")
local GlobalBridge = Loolib.Compat.GlobalBridge
local Loothing = ns.Addon
local Utils = ns.Utils
local L = ns.Locale

local FRAME_W        = 600
local FRAME_H        = 550
local FRAME_MIN_W    = 520
local FRAME_MIN_H    = 500
local FRAME_MAX_W    = 900
local FRAME_MAX_H    = 700
local ROW_H          = 30
local ROW_PADDING    = 4
local EXPANDED_H     = 90
local SWATCH_SIZE    = 20
local SECTION_PAD    = 12
local MAX_REASONS    = 20

local AwardReasonsSettingsMixin = ns.AwardReasonsSettingsMixin or {}
ns.AwardReasonsSettingsMixin = AwardReasonsSettingsMixin

--[[--------------------------------------------------------------------
    Public API
----------------------------------------------------------------------]]

function AwardReasonsSettingsMixin:Show()
    -- Block non-ML players from editing during an active session
    if Loothing.Session and Loothing.Session:IsActive()
        and Loothing.MLDB and not Loothing.MLDB:IsML() then
        Loothing:Print(L["SESSION_SETTINGS_LOCKED_SHORT"] or "Settings are locked during an active session.")
        return
    end

    self:BringToFront()
    self.frame:Show()
    self:UpdateLayout()
    self:Refresh()
end

function AwardReasonsSettingsMixin:Hide()
    self.frame:Hide()
end

function AwardReasonsSettingsMixin:IsShown()
    return self.frame:IsShown()
end

function AwardReasonsSettingsMixin:Toggle()
    if self:IsShown() then self:Hide() else self:Show() end
end

--[[--------------------------------------------------------------------
    Initialization
----------------------------------------------------------------------]]

function AwardReasonsSettingsMixin:Init()
    self.expandedRow = nil
    self.rowFrames   = {}
    self:BuildFrame()

    -- Auto-hide for non-ML when a session starts (settings become locked)
    if Loothing.Session then
        Loothing.Session:RegisterCallback("OnSessionStarted", function()
            if self:IsShown() and Loothing.MLDB and not Loothing.MLDB:IsML() then
                self:Hide()
                Loothing:Print(L["SESSION_SETTINGS_LOCKED_SHORT"] or "Settings are locked during an active session.")
            end
        end, self)
    end
end

function AwardReasonsSettingsMixin:BringToFront()
    if not self.frame then
        return
    end
    self.frame:Raise()
end

function AwardReasonsSettingsMixin:UpdateLayout()
    if self.scrollFrame and self.scrollChild then
        local scrollWidth = math.max((self.scrollFrame:GetWidth() or 0) - 24, 1)
        self.scrollChild:SetWidth(scrollWidth)
    end
end

--[[--------------------------------------------------------------------
    Frame Construction
----------------------------------------------------------------------]]

function AwardReasonsSettingsMixin:BuildFrame()
    local f = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    f:SetSize(FRAME_W, FRAME_H)
    f:SetPoint("CENTER")
    f:SetFrameStrata("DIALOG")
    f:SetToplevel(true)
    f:SetMovable(true)
    f:SetResizable(true)
    f:SetResizeBounds(FRAME_MIN_W, FRAME_MIN_H, FRAME_MAX_W, FRAME_MAX_H)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnShow", function(frame)
        frame:Raise()
        self:UpdateLayout()
    end)
    f:SetScript("OnMouseDown", function(frame)
        frame:Raise()
    end)
    f:SetScript("OnDragStart", function(frame)
        frame:Raise()
        frame:StartMoving()
    end)
    f:SetScript("OnDragStop",  f.StopMovingOrSizing)
    f:SetScript("OnSizeChanged", function()
        self:UpdateLayout()
        self:RebuildRows()
    end)
    f:SetClampedToScreen(true)
    f:SetBackdrop({
        bgFile   = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile     = true,
        tileSize = 32,
        edgeSize = 32,
        insets   = { left = 11, right = 12, top = 12, bottom = 11 },
    })
    f:SetBackdropColor(0.08, 0.08, 0.08, 0.97)
    f:SetBackdropBorderColor(0.7, 0.7, 0.7, 1)
    f:Hide()
    self.frame = f
    ns.AwardReasonsSettingsFrame = f

    -- Title
    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", 0, -14)
    title:SetText(L["AWARD_REASON_EDITOR"])
    self.titleText = title

    -- Close button
    local closeBtn = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", -4, -4)
    closeBtn:SetScript("OnClick", function() self:Hide() end)

    -- Resize grip
    local resizeGrip = CreateFrame("Button", nil, f)
    resizeGrip:SetSize(16, 16)
    resizeGrip:SetPoint("BOTTOMRIGHT", -8, 8)
    resizeGrip:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    resizeGrip:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
    resizeGrip:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
    resizeGrip:SetScript("OnMouseDown", function()
        f:StartSizing("BOTTOMRIGHT")
    end)
    resizeGrip:SetScript("OnMouseUp", function()
        f:StopMovingOrSizing()
        self:UpdateLayout()
        self:RebuildRows()
    end)
    self.resizeGrip = resizeGrip

    -- Separator below title
    local sep1 = f:CreateTexture(nil, "ARTWORK")
    sep1:SetHeight(1)
    sep1:SetPoint("TOPLEFT", 12, -36)
    sep1:SetPoint("TOPRIGHT", -12, -36)
    sep1:SetColorTexture(0.5, 0.5, 0.5, 0.5)

    -- ----------------------------------------------------------------
    -- Toggle Bar (Enabled + Require Award Reason)
    -- ----------------------------------------------------------------
    local toggleBar = CreateFrame("Frame", nil, f)
    toggleBar:SetHeight(28)
    toggleBar:SetPoint("TOPLEFT", 12, -44)
    toggleBar:SetPoint("TOPRIGHT", -12, -44)
    self.toggleBar = toggleBar

    -- Enabled checkbox
    local enabledCB = CreateFrame("CheckButton", nil, toggleBar, "ChatConfigCheckButtonTemplate")
    enabledCB:SetSize(20, 20)
    enabledCB:SetPoint("LEFT", 0, 0)
    enabledCB:SetScript("OnClick", function(cb)
        local enabled = cb:GetChecked()
        Loothing.Settings:SetAwardReasonsEnabled(enabled)
        self:RefreshToggleState()
        Utils.NotifySettingsDialogRefresh()
        Utils.BroadcastMLDBIfML()
    end)
    self.enabledCB = enabledCB

    local enabledLabel = toggleBar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    enabledLabel:SetPoint("LEFT", enabledCB, "RIGHT", 4, 0)
    enabledLabel:SetText(L["ENABLED"])
    self.enabledLabel = enabledLabel

    -- Require Award Reason checkbox
    local requireCB = CreateFrame("CheckButton", nil, toggleBar, "ChatConfigCheckButtonTemplate")
    requireCB:SetSize(20, 20)
    requireCB:SetPoint("LEFT", enabledLabel, "RIGHT", 24, 0)
    requireCB:SetScript("OnClick", function(cb)
        Loothing.Settings:SetRequireAwardReason(cb:GetChecked())
        Utils.NotifySettingsDialogRefresh()
        Utils.BroadcastMLDBIfML()
    end)
    self.requireCB = requireCB

    local requireLabel = toggleBar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    requireLabel:SetPoint("LEFT", requireCB, "RIGHT", 4, 0)
    requireLabel:SetText(L["REQUIRE_AWARD_REASON"])
    self.requireLabel = requireLabel

    -- Separator below toggle bar
    local sep2 = f:CreateTexture(nil, "ARTWORK")
    sep2:SetHeight(1)
    sep2:SetPoint("TOPLEFT", 12, -78)
    sep2:SetPoint("TOPRIGHT", -12, -78)
    sep2:SetColorTexture(0.5, 0.5, 0.5, 0.5)

    -- ----------------------------------------------------------------
    -- Bottom bar
    -- ----------------------------------------------------------------
    local bottomSep = f:CreateTexture(nil, "ARTWORK")
    bottomSep:SetHeight(1)
    bottomSep:SetPoint("BOTTOMLEFT",  12, 42)
    bottomSep:SetPoint("BOTTOMRIGHT",-12, 42)
    bottomSep:SetColorTexture(0.5, 0.5, 0.5, 0.5)

    local resetBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    resetBtn:SetSize(160, 22)
    resetBtn:SetPoint("BOTTOMLEFT", 12, 10)
    resetBtn:SetText(L["CONFIG_RESET_REASONS"])
    resetBtn:SetScript("OnClick", function()
        GlobalBridge:RegisterStaticPopup("Loothing", "LOOTHING_RESET_AWARD_REASONS", {
            text         = L["POPUP_RESET_ALL_REASONS"],
            button1      = L["RESET"],
            button2      = L["CANCEL"],
            OnAccept     = function()
                Loothing.Settings:ResetAwardReasons()
                self.expandedRow = nil
                self:Refresh()
                Utils.NotifySettingsDialogRefresh()
                Utils.BroadcastMLDBIfML()
            end,
            timeout      = 0,
            whileDead    = true,
            hideOnEscape = true,
        })
        GlobalBridge:ShowStaticPopup("Loothing", "LOOTHING_RESET_AWARD_REASONS")
    end)

    -- ----------------------------------------------------------------
    -- Add Reason button
    -- ----------------------------------------------------------------
    local addBtnContainer = CreateFrame("Frame", nil, f)
    addBtnContainer:SetHeight(28)
    addBtnContainer:SetPoint("BOTTOMLEFT", bottomSep, "TOPLEFT", 0, 10)
    addBtnContainer:SetPoint("BOTTOMRIGHT", bottomSep, "TOPRIGHT", 0, 10)

    local addBtn = CreateFrame("Button", nil, addBtnContainer, "UIPanelButtonTemplate")
    addBtn:SetSize(140, 22)
    addBtn:SetPoint("LEFT")
    addBtn:SetText("+ " .. L["ADD_REASON"])
    addBtn:SetScript("OnClick", function()
        local reasons = Loothing.Settings:GetAwardReasons()
        if #reasons >= MAX_REASONS then
            Loothing:Print(L["MAX_REASONS"])
            return
        end
        local newId = Loothing.Settings:AddAwardReason(L["CONFIG_NEW_REASON_DEFAULT"], { 1, 1, 1, 1 })
        if newId then
            self.expandedRow = newId
            self:Refresh()
            Utils.NotifySettingsDialogRefresh()
            Utils.BroadcastMLDBIfML()
        end
    end)
    self.addBtn = addBtn

    -- ----------------------------------------------------------------
    -- Scroll frame (reason list)
    -- ----------------------------------------------------------------
    local scrollFrame = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 12, -86)
    scrollFrame:SetPoint("TOPRIGHT", -30, -86)
    scrollFrame:SetPoint("BOTTOMLEFT", addBtnContainer, "TOPLEFT", 0, SECTION_PAD)
    scrollFrame:SetPoint("BOTTOMRIGHT", addBtnContainer, "TOPRIGHT", -18, SECTION_PAD)
    self.scrollFrame = scrollFrame

    local scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetWidth(FRAME_W - 12 - 30)
    scrollChild:SetHeight(1)
    scrollFrame:SetScrollChild(scrollChild)
    self.scrollChild = scrollChild
end

--[[--------------------------------------------------------------------
    Toggle State
----------------------------------------------------------------------]]

function AwardReasonsSettingsMixin:RefreshToggleState()
    local enabled = Loothing.Settings:GetAwardReasonsEnabled()
    self.enabledCB:SetChecked(enabled)
    self.requireCB:SetChecked(Loothing.Settings:GetRequireAwardReason())
    self.requireCB:SetEnabled(enabled)

    -- Dim the require label when disabled
    if enabled then
        self.requireLabel:SetTextColor(1, 0.82, 0)
    else
        self.requireLabel:SetTextColor(0.5, 0.5, 0.5)
    end

    -- Enable/disable the add button and scroll area
    if self.addBtn then
        self.addBtn:SetEnabled(enabled)
    end
end

--[[--------------------------------------------------------------------
    Refresh / Rebuild Reason Rows
----------------------------------------------------------------------]]

function AwardReasonsSettingsMixin:Refresh()
    self:RefreshToggleState()
    self:RebuildRows()
end

function AwardReasonsSettingsMixin:RebuildRows()
    if not self.scrollChild then return end

    -- Hide all existing rows
    for _, row in ipairs(self.rowFrames) do
        row:Hide()
    end

    local reasons = Loothing.Settings:GetAwardReasons()
    table.sort(reasons, function(a, b) return (a.sort or 0) < (b.sort or 0) end)

    local yOffset = 0

    for i, reasonData in ipairs(reasons) do
        local expanded = (self.expandedRow == reasonData.id)
        local rowFrame = self.rowFrames[i]
        if not rowFrame then
            rowFrame = self:CreateRow()
            self.rowFrames[i] = rowFrame
        end

        rowFrame:ClearAllPoints()
        rowFrame:SetPoint("TOPLEFT",  self.scrollChild, "TOPLEFT", 0, -yOffset)
        rowFrame:SetPoint("TOPRIGHT", self.scrollChild, "TOPRIGHT", 0, -yOffset)
        rowFrame:SetParent(self.scrollChild)

        self:PopulateRow(rowFrame, reasonData, i, #reasons, expanded)
        rowFrame:Show()

        local totalRowH = ROW_H + (expanded and EXPANDED_H or 0) + ROW_PADDING
        yOffset = yOffset + totalRowH
    end

    self.scrollChild:SetHeight(math.max(yOffset, 1))
end

--[[--------------------------------------------------------------------
    Row Creation
----------------------------------------------------------------------]]

function AwardReasonsSettingsMixin:CreateRow()
    local row = CreateFrame("Frame", nil, self.scrollChild, "BackdropTemplate")
    row:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        tile     = false,
        edgeSize = 1,
        insets   = { left = 0, right = 0, top = 0, bottom = 0 },
    })
    row:SetBackdropColor(0.12, 0.12, 0.12, 0.8)
    row:SetBackdropBorderColor(0.25, 0.25, 0.25, 1)

    -- ---- Collapsed region ----
    local collapsed = CreateFrame("Frame", nil, row)
    collapsed:SetHeight(ROW_H)
    collapsed:SetPoint("TOPLEFT")
    collapsed:SetPoint("TOPRIGHT")
    row.collapsed = collapsed

    -- Move up button
    local upBtn = CreateFrame("Button", nil, collapsed)
    upBtn:SetSize(16, 14)
    upBtn:SetPoint("LEFT", 4, 3)
    upBtn:SetNormalFontObject("GameFontNormalSmall")
    upBtn:SetText("▲")
    row.upBtn = upBtn

    -- Move down button
    local downBtn = CreateFrame("Button", nil, collapsed)
    downBtn:SetSize(16, 14)
    downBtn:SetPoint("LEFT", 4, -5)
    downBtn:SetNormalFontObject("GameFontNormalSmall")
    downBtn:SetText("▼")
    row.downBtn = downBtn

    -- Color swatch
    local swatch = CreateFrame("Button", nil, collapsed, "BackdropTemplate")
    swatch:SetSize(SWATCH_SIZE, SWATCH_SIZE)
    swatch:SetPoint("LEFT", upBtn, "RIGHT", 6, 0)
    swatch:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        tile     = false,
        edgeSize = 1,
        insets   = { left = 0, right = 0, top = 0, bottom = 0 },
    })
    swatch:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)
    row.swatch = swatch

    -- Reason name label
    local nameLabel = collapsed:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    nameLabel:SetPoint("LEFT", swatch, "RIGHT", 8, 0)
    nameLabel:SetPoint("RIGHT", -80, 0)
    nameLabel:SetJustifyH("LEFT")
    row.nameLabel = nameLabel

    -- Expand/collapse toggle
    local expandBtn = CreateFrame("Button", nil, collapsed)
    expandBtn:SetSize(60, 20)
    expandBtn:SetPoint("RIGHT", -28, 0)
    expandBtn:SetNormalFontObject("GameFontNormalSmall")
    row.expandBtn = expandBtn

    -- Delete button
    local delBtn = CreateFrame("Button", nil, collapsed)
    delBtn:SetSize(20, 20)
    delBtn:SetPoint("RIGHT", -4, 0)
    delBtn:SetNormalFontObject("GameFontNormalSmall")
    delBtn:SetText("|cffff4444✕|r")
    row.delBtn = delBtn

    -- ---- Expanded region ----
    local expandedRegion = CreateFrame("Frame", nil, row)
    expandedRegion:SetPoint("TOPLEFT",  0, -ROW_H)
    expandedRegion:SetPoint("TOPRIGHT", 0, -ROW_H)
    expandedRegion:SetHeight(EXPANDED_H)
    expandedRegion:Hide()
    row.expandedRegion = expandedRegion

    -- Helper to add a labeled sub-field
    local function AddField(label, yOff, content)
        local lbl = expandedRegion:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        lbl:SetPoint("TOPLEFT", 28, yOff)
        lbl:SetText(label)
        lbl:SetTextColor(0.7, 0.7, 0.7)
        content:SetParent(expandedRegion)
        content:ClearAllPoints()
        content:SetPoint("LEFT", lbl, "RIGHT", 6, 0)
        content:SetPoint("RIGHT", -8, 0)
    end

    -- Name EditBox
    local nameEB = CreateFrame("EditBox", nil, expandedRegion, "InputBoxTemplate")
    nameEB:SetHeight(20)
    nameEB:SetMaxLetters(64)
    nameEB:SetAutoFocus(false)
    row.nameEB = nameEB
    AddField(L["REASON_NAME"], -8, nameEB)

    -- Log to History checkbox
    local logCB = CreateFrame("CheckButton", nil, expandedRegion, "ChatConfigCheckButtonTemplate")
    logCB:SetSize(20, 20)
    row.logCB = logCB

    local logLabel = expandedRegion:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    logLabel:SetPoint("TOPLEFT", 28, -38)
    logLabel:SetText(L["CONFIG_REASON_LOG"])
    logLabel:SetTextColor(0.7, 0.7, 0.7)
    logCB:SetParent(expandedRegion)
    logCB:ClearAllPoints()
    logCB:SetPoint("LEFT", logLabel, "RIGHT", 6, 0)

    -- Disenchant checkbox
    local deCB = CreateFrame("CheckButton", nil, expandedRegion, "ChatConfigCheckButtonTemplate")
    deCB:SetSize(20, 20)
    row.deCB = deCB

    local deLabel = expandedRegion:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    deLabel:SetPoint("TOPLEFT", 28, -64)
    deLabel:SetText(L["DISENCHANT"])
    deLabel:SetTextColor(0.7, 0.7, 0.7)
    deCB:SetParent(expandedRegion)
    deCB:ClearAllPoints()
    deCB:SetPoint("LEFT", deLabel, "RIGHT", 6, 0)

    return row
end

--[[--------------------------------------------------------------------
    Row Population
----------------------------------------------------------------------]]

function AwardReasonsSettingsMixin:PopulateRow(row, reasonData, idx, total, isExpanded)
    local rowH = ROW_H + (isExpanded and EXPANDED_H or 0)
    row:SetHeight(rowH)

    -- Color swatch
    local color = reasonData.color or { 1, 1, 1, 1 }
    local cr, cg, cb, ca
    if color.r then
        cr, cg, cb, ca = color.r, color.g, color.b, color.a or 1
    else
        cr, cg, cb, ca = color[1] or 1, color[2] or 1, color[3] or 1, color[4] or 1
    end
    row.swatch:SetBackdropColor(cr, cg, cb, ca)

    row.swatch:SetScript("OnClick", function()
        local origR, origG, origB, origA = cr, cg, cb, ca
        ColorPickerFrame:SetupColorPickerAndShow({
            r = cr, g = cg, b = cb, opacity = ca,
            hasOpacity = true,
            swatchFunc = function()
                local nr, ng, nb = ColorPickerFrame:GetColorRGB()
                local na = ColorPickerFrame:GetColorAlpha()
                Loothing.Settings:UpdateAwardReason(reasonData.id, { color = { nr, ng, nb, na } })
                self:RebuildRows()
                Utils.NotifySettingsDialogRefresh()
                Utils.BroadcastMLDBIfML()
            end,
            opacityFunc = function()
                local nr, ng, nb = ColorPickerFrame:GetColorRGB()
                local na = ColorPickerFrame:GetColorAlpha()
                Loothing.Settings:UpdateAwardReason(reasonData.id, { color = { nr, ng, nb, na } })
                self:RebuildRows()
                Utils.NotifySettingsDialogRefresh()
                Utils.BroadcastMLDBIfML()
            end,
            cancelFunc = function()
                Loothing.Settings:UpdateAwardReason(reasonData.id, { color = { origR, origG, origB, origA } })
                self:RebuildRows()
                Utils.NotifySettingsDialogRefresh()
                Utils.BroadcastMLDBIfML()
            end,
        })
    end)

    -- Name label (collapsed view)
    row.nameLabel:SetText(reasonData.name or "")
    row.nameLabel:SetTextColor(cr, cg, cb)

    -- Move up/down
    row.upBtn:SetEnabled(idx > 1)
    row.upBtn:SetScript("OnClick", function()
        Loothing.Settings:UpdateAwardReason(reasonData.id, { sort = reasonData.sort - 1 })
        self:Refresh()
        Utils.NotifySettingsDialogRefresh()
        Utils.BroadcastMLDBIfML()
    end)
    row.downBtn:SetEnabled(idx < total)
    row.downBtn:SetScript("OnClick", function()
        Loothing.Settings:UpdateAwardReason(reasonData.id, { sort = reasonData.sort + 1 })
        self:Refresh()
        Utils.NotifySettingsDialogRefresh()
        Utils.BroadcastMLDBIfML()
    end)

    -- Expand button
    row.expandBtn:SetText(isExpanded and ("▲ " .. L["LESS"]) or ("▼ " .. L["EDIT"]))
    row.expandBtn:SetScript("OnClick", function()
        if self.expandedRow == reasonData.id then
            self.expandedRow = nil
        else
            self.expandedRow = reasonData.id
        end
        self:RebuildRows()
    end)

    -- Delete button
    row.delBtn:SetScript("OnClick", function()
        local reasons = Loothing.Settings:GetAwardReasons()
        local enabled = Loothing.Settings:GetAwardReasonsEnabled()
        if enabled and #reasons <= 1 then
            Loothing:Print(L["MIN_REASONS"])
            return
        end
        GlobalBridge:RegisterStaticPopup("Loothing", "LOOTHING_DEL_AWARD_REASON", {
            text         = L["POPUP_DELETE_AWARD_REASON"],
            button1      = L["DELETE"],
            button2      = L["CANCEL"],
            OnAccept     = function()
                if self.expandedRow == reasonData.id then
                    self.expandedRow = nil
                end
                Loothing.Settings:RemoveAwardReason(reasonData.id)
                self:Refresh()
                Utils.NotifySettingsDialogRefresh()
                Utils.BroadcastMLDBIfML()
            end,
            timeout      = 0,
            whileDead    = true,
            hideOnEscape = true,
        })
        GlobalBridge:ShowStaticPopup("Loothing", "LOOTHING_DEL_AWARD_REASON")
    end)

    -- ---- Expanded region ----
    if isExpanded then
        row.expandedRegion:Show()

        -- Name EditBox
        row.nameEB:SetText(reasonData.name or "")
        row.nameEB:SetScript("OnEnterPressed", function(eb)
            eb:ClearFocus()
            Loothing.Settings:UpdateAwardReason(reasonData.id, { name = eb:GetText() })
            self:RebuildRows()
            Utils.NotifySettingsDialogRefresh()
            Utils.BroadcastMLDBIfML()
        end)
        row.nameEB:SetScript("OnEditFocusLost", function(eb)
            Loothing.Settings:UpdateAwardReason(reasonData.id, { name = eb:GetText() })
            self:RebuildRows()
            Utils.NotifySettingsDialogRefresh()
            Utils.BroadcastMLDBIfML()
        end)

        -- Log to History
        row.logCB:SetChecked(reasonData.log or false)
        row.logCB:SetScript("OnClick", function(checkbox)
            Loothing.Settings:UpdateAwardReason(reasonData.id, { log = checkbox:GetChecked() })
            Utils.NotifySettingsDialogRefresh()
            Utils.BroadcastMLDBIfML()
        end)

        -- Disenchant
        row.deCB:SetChecked(reasonData.disenchant or false)
        row.deCB:SetScript("OnClick", function(checkbox)
            Loothing.Settings:UpdateAwardReason(reasonData.id, { disenchant = checkbox:GetChecked() })
            Utils.NotifySettingsDialogRefresh()
            Utils.BroadcastMLDBIfML()
        end)
    else
        row.expandedRegion:Hide()
    end
end

--[[--------------------------------------------------------------------
    Singleton factory
----------------------------------------------------------------------]]

local function CreateAwardReasonsSettings()
    local obj = Loolib.CreateFromMixins(AwardReasonsSettingsMixin)
    obj:Init()
    return obj
end

ns.CreateAwardReasonsSettings = CreateAwardReasonsSettings
