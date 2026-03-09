--[[--------------------------------------------------------------------
    Loothing - Loot Council Addon for WoW 12.0+
    ResponseButtonSettingsFrame - Visual editor for response button sets
----------------------------------------------------------------------]]

local Loolib = LibStub("Loolib")

local FRAME_W        = 760
local FRAME_H        = 720
local FRAME_MIN_W    = 680
local FRAME_MIN_H    = 680
local ROW_H          = 30
local ROW_PADDING    = 4
local EXPANDED_H     = 130   -- Extra height when a row is expanded
local SWATCH_SIZE    = 20
local SECTION_PAD    = 12
local MAX_BUTTONS    = 10
local TYPE_CODE_MIN_COL_W = 220

LoothingResponseButtonSettingsMixin = {}

--[[--------------------------------------------------------------------
    Public API
----------------------------------------------------------------------]]

function LoothingResponseButtonSettingsMixin:Show()
    self:BringToFront()
    self.frame:Show()
    self:BringToFront()
    self:UpdateLayout()
    self:Refresh()
end

function LoothingResponseButtonSettingsMixin:Hide()
    self.frame:Hide()
end

function LoothingResponseButtonSettingsMixin:IsShown()
    return self.frame:IsShown()
end

function LoothingResponseButtonSettingsMixin:Toggle()
    if self:IsShown() then self:Hide() else self:Show() end
end

--[[--------------------------------------------------------------------
    Initialization
----------------------------------------------------------------------]]

function LoothingResponseButtonSettingsMixin:Init()
    self.expandedRow = nil   -- btnId of currently expanded row (or nil)
    self.rowFrames   = {}    -- pool of row frames
    self:BuildFrame()
end

function LoothingResponseButtonSettingsMixin:BringToFront()
    if not self.frame then
        return
    end

    self.frame:Raise()
end

function LoothingResponseButtonSettingsMixin:UpdateLayout()
    if self.scrollFrame and self.scrollChild then
        local scrollWidth = math.max((self.scrollFrame:GetWidth() or 0) - 24, 1)
        self.scrollChild:SetWidth(scrollWidth)
    end

    self:LayoutTypeCodeMap()
end

function LoothingResponseButtonSettingsMixin:BuildFrame()
    local f = CreateFrame("Frame", "LoothingResponseButtonSettingsFrame", UIParent, "BackdropTemplate")
    f:SetSize(FRAME_W, FRAME_H)
    f:SetPoint("CENTER")
    f:SetFrameStrata("DIALOG")
    f:SetToplevel(true)
    f:SetMovable(true)
    f:SetResizable(true)
    f:SetResizeBounds(FRAME_MIN_W, FRAME_MIN_H, 1100, 900)
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

    -- Title
    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", 0, -14)
    title:SetText("Response Button Editor")
    self.titleText = title

    -- Close button
    local closeBtn = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", -4, -4)
    closeBtn:SetScript("OnClick", function() self:Hide() end)

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

    -- Separator
    local sep1 = f:CreateTexture(nil, "ARTWORK")
    sep1:SetHeight(1)
    sep1:SetPoint("TOPLEFT", 12, -36)
    sep1:SetPoint("TOPRIGHT", -12, -36)
    sep1:SetColorTexture(0.5, 0.5, 0.5, 0.5)

    -- ----------------------------------------------------------------
    -- Set Selector Bar
    -- ----------------------------------------------------------------
    local setBar = CreateFrame("Frame", nil, f)
    setBar:SetHeight(28)
    setBar:SetPoint("TOPLEFT", 12, -44)
    setBar:SetPoint("TOPRIGHT", -12, -44)
    self.setBar = setBar

    -- Set dropdown (simple select button + popup)
    local setLabel = setBar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    setLabel:SetPoint("LEFT")
    setLabel:SetText("Set:")

    local setSelectBtn = CreateFrame("Button", nil, setBar, "UIPanelButtonTemplate")
    setSelectBtn:SetSize(170, 22)
    setSelectBtn:SetPoint("LEFT", setLabel, "RIGHT", 8, 0)
    self.setSelectBtn = setSelectBtn

    setSelectBtn:SetScript("OnClick", function(btn)
        MenuUtil.CreateContextMenu(btn, function(ownerRegion, rootDescription)
            local rs = Loothing.Settings:GetResponseSets()
            for id, set in pairs(rs.sets or {}) do
                rootDescription:CreateRadio(set.name,
                    function() return id == self:GetActiveSetId() end,
                    function()
                        Loothing.Settings:SetActiveResponseSet(id)
                        self:Refresh()
                    end
                )
            end
        end)
    end)

    -- New set button
    local newBtn = CreateFrame("Button", nil, setBar, "UIPanelButtonTemplate")
    newBtn:SetSize(60, 22)
    newBtn:SetPoint("LEFT", setSelectBtn, "RIGHT", 6, 0)
    newBtn:SetText("New")
    newBtn:SetScript("OnClick", function()
        local id = Loothing.Settings:AddResponseSet("New Set")
        Loothing.Settings:SetActiveResponseSet(id)
        self:Refresh()
    end)

    -- Copy button
    local copyBtn = CreateFrame("Button", nil, setBar, "UIPanelButtonTemplate")
    copyBtn:SetSize(60, 22)
    copyBtn:SetPoint("LEFT", newBtn, "RIGHT", 4, 0)
    copyBtn:SetText("Copy")
    copyBtn:SetScript("OnClick", function()
        local id  = self:GetActiveSetId()
        local set = Loothing.Settings:GetResponseSetById(id)
        if set then
            local newId = Loothing.Settings:AddResponseSet(set.name .. " (Copy)", LoothingUtils.DeepCopy(set.buttons))
            Loothing.Settings:SetActiveResponseSet(newId)
            self:Refresh()
        end
    end)

    -- Rename button
    local renameBtn = CreateFrame("Button", nil, setBar, "UIPanelButtonTemplate")
    renameBtn:SetSize(70, 22)
    renameBtn:SetPoint("LEFT", copyBtn, "RIGHT", 4, 0)
    renameBtn:SetText("Rename")
    renameBtn:SetScript("OnClick", function()
        local id  = self:GetActiveSetId()
        local set = Loothing.Settings:GetResponseSetById(id)
        Loolib.Compat.RegisterStaticPopup("LOOTHING_RENAME_SET", {
            text         = "Enter new name for set:",
            button1      = "OK",
            button2      = "Cancel",
            hasEditBox   = true,
            maxLetters   = 32,
            OnAccept     = function(popup)
                local v = popup.EditBox:GetText()
                if v and v ~= "" then
                    Loothing.Settings:UpdateResponseSet(id, { name = v })
                    self:Refresh()
                end
            end,
            timeout      = 0,
            whileDead    = true,
            hideOnEscape = true,
        })
        local dialog = StaticPopup_Show("LOOTHING_RENAME_SET")
        if dialog and set then
            dialog.EditBox:SetText(set.name)
            dialog.EditBox:HighlightText()
        end
    end)

    -- Delete button
    local deleteSetBtn = CreateFrame("Button", nil, setBar, "UIPanelButtonTemplate")
    deleteSetBtn:SetSize(65, 22)
    deleteSetBtn:SetPoint("LEFT", renameBtn, "RIGHT", 4, 0)
    deleteSetBtn:SetText("|cffff4444Del|r")
    deleteSetBtn:SetScript("OnClick", function()
        local id = self:GetActiveSetId()
        local rs = Loothing.Settings:GetResponseSets()
        local count = 0
        for _ in pairs(rs.sets or {}) do count = count + 1 end
        if count <= 1 then
            Loothing:Print("Cannot delete the last response set.")
            return
        end
        Loolib.Compat.RegisterStaticPopup("LOOTHING_DEL_SET", {
            text         = "Delete this response set? This cannot be undone.",
            button1      = "Delete",
            button2      = "Cancel",
            OnAccept     = function()
                Loothing.Settings:RemoveResponseSet(id)
                self:Refresh()
            end,
            timeout      = 0,
            whileDead    = true,
            hideOnEscape = true,
        })
        StaticPopup_Show("LOOTHING_DEL_SET")
    end)

    -- ----------------------------------------------------------------
    -- Bottom bar
    -- ----------------------------------------------------------------
    local bottomSep = f:CreateTexture(nil, "ARTWORK")
    bottomSep:SetHeight(1)
    bottomSep:SetPoint("BOTTOMLEFT",  12, 42)
    bottomSep:SetPoint("BOTTOMRIGHT",-12, 42)
    bottomSep:SetColorTexture(0.5, 0.5, 0.5, 0.5)

    local resetBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    resetBtn:SetSize(140, 22)
    resetBtn:SetPoint("BOTTOMLEFT", 12, 10)
    resetBtn:SetText("Reset to Defaults")
    resetBtn:SetScript("OnClick", function()
        Loolib.Compat.RegisterStaticPopup("LOOTHING_RESET_SETS", {
            text         = "Reset ALL response sets to defaults? This cannot be undone.",
            button1      = "Reset",
            button2      = "Cancel",
            OnAccept     = function()
                if Loothing.ResponseManager then
                    Loothing.ResponseManager:ResetToDefaults()
                end
                self:Refresh()
            end,
            timeout      = 0,
            whileDead    = true,
            hideOnEscape = true,
        })
        StaticPopup_Show("LOOTHING_RESET_SETS")
    end)

    -- ----------------------------------------------------------------
    -- Type Code Mapping section
    -- ----------------------------------------------------------------
    local tcContainer = CreateFrame("Frame", nil, f)
    tcContainer:SetPoint("BOTTOMLEFT", 12, 52)
    tcContainer:SetPoint("BOTTOMRIGHT", -12, 52)
    tcContainer:SetHeight(1)
    self.tcContainer = tcContainer
    self:BuildTypeCodeMap(tcContainer)

    local tcHeader = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    tcHeader:SetPoint("BOTTOMLEFT", tcContainer, "TOPLEFT", 0, 6)
    tcHeader:SetText("|cffffcc00Type Code Mapping|r")
    self.tcHeader = tcHeader

    -- ----------------------------------------------------------------
    -- Add Button
    -- ----------------------------------------------------------------
    local addBtnContainer = CreateFrame("Frame", nil, f)
    addBtnContainer:SetHeight(28)
    addBtnContainer:SetPoint("BOTTOMLEFT", tcHeader, "TOPLEFT", 0, 10)
    addBtnContainer:SetPoint("BOTTOMRIGHT", tcHeader, "TOPRIGHT", 0, 10)

    local addBtn = CreateFrame("Button", nil, addBtnContainer, "UIPanelButtonTemplate")
    addBtn:SetSize(120, 22)
    addBtn:SetPoint("LEFT")
    addBtn:SetText("+ Add Button")
    addBtn:SetScript("OnClick", function()
        local id = self:GetActiveSetId()
        local buttons = Loothing.Settings:GetResponseButtons(id)
        if #buttons >= MAX_BUTTONS then
            Loothing:Print("Maximum " .. MAX_BUTTONS .. " buttons per set.")
            return
        end
        local newId = Loothing.Settings:AddResponseButton(id, { text = "New Button", responseText = "NEW" })
        if newId then
            self.expandedRow = newId
            self:Refresh()
        end
    end)
    self.addBtn = addBtn

    -- ----------------------------------------------------------------
    -- Scroll frame (button list)
    -- ----------------------------------------------------------------
    local scrollFrame = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 12, -80)
    scrollFrame:SetPoint("TOPRIGHT", -30, -80)
    scrollFrame:SetPoint("BOTTOMLEFT", addBtnContainer, "TOPLEFT", 0, SECTION_PAD)
    scrollFrame:SetPoint("BOTTOMRIGHT", addBtnContainer, "TOPRIGHT", -18, SECTION_PAD)
    self.scrollFrame = scrollFrame

    local scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetWidth(FRAME_W - 12 - 30)
    scrollChild:SetHeight(1)  -- will be grown dynamically
    scrollFrame:SetScrollChild(scrollChild)
    self.scrollChild = scrollChild
end

--[[--------------------------------------------------------------------
    Type Code Mapping
----------------------------------------------------------------------]]

local TYPE_CODES = { "default", "WEAPON", "RARE", "TOKEN", "PETS", "MOUNTS", "RECIPE", "SPECIAL", "CATALYST" }

function LoothingResponseButtonSettingsMixin:BuildTypeCodeMap(container)
    self.tcDropdowns = {}
    self.tcFields = {}

    for i, tc in ipairs(TYPE_CODES) do
        local lbl = container:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        lbl:SetJustifyH("LEFT")
        lbl:SetText(tc .. ":")

        local capturedTc = tc
        local dd = CreateFrame("Button", nil, container, "UIPanelButtonTemplate")

        dd:SetScript("OnClick", function(btn)
            MenuUtil.CreateContextMenu(btn, function(ownerRegion, rootDescription)
                local tcMap = Loothing.Settings:GetTypeCodeMap()

                local defaultLabel = (capturedTc == "default") and "Active Set" or "Default"
                rootDescription:CreateRadio(defaultLabel,
                    function() return tcMap[capturedTc] == nil end,
                    function()
                        Loothing.Settings:ClearTypeCodeForSet(capturedTc)
                        self:RefreshTypeCodeMap()
                    end
                )

                local rs = Loothing.Settings:GetResponseSets()
                for sid, set in pairs(rs.sets or {}) do
                    rootDescription:CreateRadio(set.name,
                        function() return tcMap[capturedTc] == sid end,
                        function()
                            Loothing.Settings:SetTypeCodeForSet(capturedTc, sid)
                            self:RefreshTypeCodeMap()
                        end
                    )
                end
            end)
        end)

        self.tcDropdowns[tc] = dd
        self.tcFields[i] = {
            label = lbl,
            dropdown = dd,
        }
    end
end

function LoothingResponseButtonSettingsMixin:LayoutTypeCodeMap()
    if not self.tcContainer or not self.tcFields then
        return
    end

    local container = self.tcContainer
    local width = container:GetWidth()
    if width <= 0 and self.frame then
        width = self.frame:GetWidth() - 24
    end
    if width <= 0 then
        return
    end

    local columns = math.max(2, math.min(3, math.floor((width + SECTION_PAD) / TYPE_CODE_MIN_COL_W)))
    local colGap = SECTION_PAD
    local rowGap = 8
    local rowH = 22
    local colW = math.floor((width - ((columns - 1) * colGap)) / columns)
    local labelW = math.max(60, math.floor(colW * 0.33))
    local dropdownW = math.max(110, colW - labelW - 10)

    for i, field in ipairs(self.tcFields) do
        local col = (i - 1) % columns
        local row = math.floor((i - 1) / columns)
        local x = col * (colW + colGap)
        local y = -row * (rowH + rowGap)

        field.label:ClearAllPoints()
        field.label:SetPoint("TOPLEFT", container, "TOPLEFT", x, y)
        field.label:SetWidth(labelW)

        field.dropdown:ClearAllPoints()
        field.dropdown:SetPoint("LEFT", field.label, "RIGHT", 4, 0)
        field.dropdown:SetSize(dropdownW, 22)
    end

    local rows = math.ceil(#self.tcFields / columns)
    container:SetHeight(rows * rowH + math.max(0, rows - 1) * rowGap)
end

function LoothingResponseButtonSettingsMixin:RefreshTypeCodeMap()
    local tcMap = Loothing.Settings:GetTypeCodeMap()
    for tc, dd in pairs(self.tcDropdowns or {}) do
        local setId = tcMap[tc]
        if setId then
            local set = Loothing.Settings:GetResponseSetById(setId)
            dd:SetText(set and set.name or tostring(setId))
        elseif tc == "default" then
            dd:SetText("Active Set")
        else
            dd:SetText("Default")
        end
    end
end

--[[--------------------------------------------------------------------
    Refresh / Rebuild Button Rows
----------------------------------------------------------------------]]

function LoothingResponseButtonSettingsMixin:GetActiveSetId()
    return Loothing.Settings:GetActiveResponseSet()
end

function LoothingResponseButtonSettingsMixin:Refresh()
    -- Update set dropdown label
    local id  = self:GetActiveSetId()
    local set = Loothing.Settings:GetResponseSetById(id)
    self.setSelectBtn:SetText(set and set.name or "?")

    -- Rebuild button rows
    self:RebuildRows()

    -- Refresh typeCode map
    self:RefreshTypeCodeMap()
end

function LoothingResponseButtonSettingsMixin:RebuildRows()
    if not self.scrollChild then return end
    -- Hide all existing rows
    for _, row in ipairs(self.rowFrames) do
        row:Hide()
    end

    local setId   = self:GetActiveSetId()
    local buttons = Loothing.Settings:GetResponseButtons(setId)
    table.sort(buttons, function(a, b) return (a.sort or 0) < (b.sort or 0) end)

    local yOffset = 0

    for i, btnData in ipairs(buttons) do
        local expanded = (self.expandedRow == btnData.id)
        local rowFrame = self.rowFrames[i]
        if not rowFrame then
            rowFrame = self:CreateRow()
            self.rowFrames[i] = rowFrame
        end

        rowFrame:ClearAllPoints()
        rowFrame:SetPoint("TOPLEFT",  self.scrollChild, "TOPLEFT", 0, -yOffset)
        rowFrame:SetPoint("TOPRIGHT", self.scrollChild, "TOPRIGHT", 0, -yOffset)
        rowFrame:SetParent(self.scrollChild)

        self:PopulateRow(rowFrame, setId, btnData, i, #buttons, expanded)
        rowFrame:Show()

        local rowH = ROW_H + (expanded and EXPANDED_H or 0) + ROW_PADDING
        yOffset = yOffset + rowH
    end

    self.scrollChild:SetHeight(math.max(yOffset, 1))

    -- Keep Loothing.ResponseInfo in sync after any data change
    if Loothing.ResponseManager and self.frame and self.frame:IsShown() then
        Loothing.ResponseManager:LoadResponses()
    end
end

--[[--------------------------------------------------------------------
    Row Creation
----------------------------------------------------------------------]]

function LoothingResponseButtonSettingsMixin:CreateRow()
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

    -- Button text label
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
    local expanded = CreateFrame("Frame", nil, row)
    expanded:SetPoint("TOPLEFT",  0, -ROW_H)
    expanded:SetPoint("TOPRIGHT", 0, -ROW_H)
    expanded:SetHeight(EXPANDED_H)
    expanded:Hide()
    row.expandedRegion = expanded

    -- Helper to add a labeled sub-field
    local function AddField(label, yOff, content)
        local lbl = expanded:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        lbl:SetPoint("TOPLEFT", 28, yOff)
        lbl:SetText(label)
        lbl:SetTextColor(0.7, 0.7, 0.7)
        content:SetParent(expanded)
        content:ClearAllPoints()
        content:SetPoint("LEFT", lbl, "RIGHT", 6, 0)
        content:SetPoint("RIGHT", -8, 0)
    end

    -- Display Text EditBox
    local dispEB = CreateFrame("EditBox", nil, expanded, "InputBoxTemplate")
    dispEB:SetHeight(20)
    dispEB:SetMaxLetters(64)
    dispEB:SetAutoFocus(false)
    row.dispEB = dispEB
    AddField("Display Text:", -6, dispEB)

    -- Response Text EditBox
    local respEB = CreateFrame("EditBox", nil, expanded, "InputBoxTemplate")
    respEB:SetHeight(20)
    respEB:SetMaxLetters(64)
    respEB:SetAutoFocus(false)
    row.respEB = respEB
    AddField("Response Text:", -32, respEB)

    -- Icon picker button
    local iconPickBtn = CreateFrame("Button", nil, expanded, "UIPanelButtonTemplate")
    iconPickBtn:SetHeight(20)
    row.iconPickBtn = iconPickBtn
    AddField("Icon:", -58, iconPickBtn)

    -- Whisper Keys EditBox
    local whisperEB = CreateFrame("EditBox", nil, expanded, "InputBoxTemplate")
    whisperEB:SetHeight(20)
    whisperEB:SetMaxLetters(128)
    whisperEB:SetAutoFocus(false)
    row.whisperEB = whisperEB
    AddField("Whisper Keys:", -84, whisperEB)

    -- Require Notes CheckButton
    local requireCB = CreateFrame("CheckButton", nil, expanded, "ChatConfigCheckButtonTemplate")
    requireCB:SetSize(20, 20)
    row.requireCB = requireCB
    local cbLbl = expanded:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    cbLbl:SetPoint("TOPLEFT", 28, -108)
    cbLbl:SetText("Require Notes")
    cbLbl:SetTextColor(0.7, 0.7, 0.7)
    requireCB:SetParent(expanded)
    requireCB:ClearAllPoints()
    requireCB:SetPoint("LEFT", cbLbl, "RIGHT", 6, 0)

    return row
end

function LoothingResponseButtonSettingsMixin:PopulateRow(row, setId, btnData, idx, total, isExpanded)
    local rowH = ROW_H + (isExpanded and EXPANDED_H or 0)
    row:SetHeight(rowH)

    -- Color swatch
    local color = btnData.color or { 1, 1, 1, 1 }
    local cr, cg, cb, ca
    if color.r then
        cr, cg, cb, ca = color.r, color.g, color.b, color.a or 1
    else
        cr, cg, cb, ca = color[1] or 1, color[2] or 1, color[3] or 1, color[4] or 1
    end
    row.swatch:SetBackdropColor(cr, cg, cb, ca)

    row.swatch:SetScript("OnClick", function(btn)
        local origR, origG, origB, origA = cr, cg, cb, ca
        ColorPickerFrame:SetupColorPickerAndShow({
            r = cr, g = cg, b = cb, opacity = ca,
            hasOpacity = true,
            swatchFunc = function()
                local nr, ng, nb = ColorPickerFrame:GetColorRGB()
                local na = ColorPickerFrame:GetColorAlpha()
                Loothing.Settings:UpdateResponseButton(setId, btnData.id, { color = { nr, ng, nb, na } })
                self:RebuildRows()
            end,
            opacityFunc = function()
                local nr, ng, nb = ColorPickerFrame:GetColorRGB()
                local na = ColorPickerFrame:GetColorAlpha()
                Loothing.Settings:UpdateResponseButton(setId, btnData.id, { color = { nr, ng, nb, na } })
                self:RebuildRows()
            end,
            cancelFunc = function()
                Loothing.Settings:UpdateResponseButton(setId, btnData.id, { color = { origR, origG, origB, origA } })
                self:RebuildRows()
            end,
        })
    end)

    -- Name label
    row.nameLabel:SetText(btnData.text or "")
    row.nameLabel:SetTextColor(cr, cg, cb)

    -- Move up/down
    row.upBtn:SetEnabled(idx > 1)
    row.upBtn:SetScript("OnClick", function()
        Loothing.Settings:ReorderResponseButton(setId, btnData.id, btnData.sort - 1)
        self:Refresh()
    end)
    row.downBtn:SetEnabled(idx < total)
    row.downBtn:SetScript("OnClick", function()
        Loothing.Settings:ReorderResponseButton(setId, btnData.id, btnData.sort + 1)
        self:Refresh()
    end)

    -- Expand button
    row.expandBtn:SetText(isExpanded and "▲ Less" or "▼ Edit")
    row.expandBtn:SetScript("OnClick", function()
        if self.expandedRow == btnData.id then
            self.expandedRow = nil
        else
            self.expandedRow = btnData.id
        end
        self:RebuildRows()
    end)

    -- Delete button
    row.delBtn:SetScript("OnClick", function()
        local buttons = Loothing.Settings:GetResponseButtons(setId)
        if #buttons <= 1 then
            Loothing:Print("Cannot delete the last button in a set.")
            return
        end
        Loolib.Compat.RegisterStaticPopup("LOOTHING_DEL_BTN", {
            text         = "Delete this response button?",
            button1      = "Delete",
            button2      = "Cancel",
            OnAccept     = function()
                if self.expandedRow == btnData.id then self.expandedRow = nil end
                Loothing.Settings:RemoveResponseButton(setId, btnData.id)
                self:Refresh()
            end,
            timeout      = 0,
            whileDead    = true,
            hideOnEscape = true,
        })
        StaticPopup_Show("LOOTHING_DEL_BTN")
    end)

    -- ---- Expanded region ----
    if isExpanded then
        row.expandedRegion:Show()

        -- Display text
        row.dispEB:SetText(btnData.text or "")
        row.dispEB:SetScript("OnEnterPressed", function(eb)
            eb:ClearFocus()
            Loothing.Settings:UpdateResponseButton(setId, btnData.id, { text = eb:GetText() })
            self:RebuildRows()
        end)
        row.dispEB:SetScript("OnEditFocusLost", function(eb)
            Loothing.Settings:UpdateResponseButton(setId, btnData.id, { text = eb:GetText() })
            self:RebuildRows()
        end)

        -- Response text
        row.respEB:SetText(btnData.responseText or btnData.text or "")
        row.respEB:SetScript("OnEnterPressed", function(eb)
            eb:ClearFocus()
            Loothing.Settings:UpdateResponseButton(setId, btnData.id, { responseText = eb:GetText() })
            if Loothing.ResponseManager then Loothing.ResponseManager:LoadResponses() end
        end)
        row.respEB:SetScript("OnEditFocusLost", function(eb)
            Loothing.Settings:UpdateResponseButton(setId, btnData.id, { responseText = eb:GetText() })
            if Loothing.ResponseManager then Loothing.ResponseManager:LoadResponses() end
        end)

        -- Icon picker
        local iconLabel = btnData.icon and ("Icon: ✓") or "Pick Icon…"
        row.iconPickBtn:SetText(iconLabel)
        row.iconPickBtn:SetScript("OnClick", function(btn)
            LoothingIconPicker_Open(btn, function(path)
                Loothing.Settings:UpdateResponseButton(setId, btnData.id, { icon = path })
                self:RebuildRows()
            end, btnData.icon)
        end)

        -- Whisper keys (comma-separated)
        local keysStr = table.concat(btnData.whisperKeys or {}, ", ")
        row.whisperEB:SetText(keysStr)
        row.whisperEB:SetScript("OnEnterPressed", function(eb)
            eb:ClearFocus()
            local parts = LoothingUtils.Split(eb:GetText():gsub("%s+", ""), ",")
            Loothing.Settings:UpdateResponseButton(setId, btnData.id, { whisperKeys = parts })
            if Loothing.ResponseManager then Loothing.ResponseManager:LoadResponses() end
        end)
        row.whisperEB:SetScript("OnEditFocusLost", function(eb)
            local parts = LoothingUtils.Split(eb:GetText():gsub("%s+", ""), ",")
            Loothing.Settings:UpdateResponseButton(setId, btnData.id, { whisperKeys = parts })
            if Loothing.ResponseManager then Loothing.ResponseManager:LoadResponses() end
        end)

        -- Require notes
        row.requireCB:SetChecked(btnData.requireNotes or false)
        row.requireCB:SetScript("OnClick", function(cb)
            Loothing.Settings:UpdateResponseButton(setId, btnData.id, { requireNotes = cb:GetChecked() })
            if Loothing.ResponseManager then Loothing.ResponseManager:LoadResponses() end
        end)
    else
        row.expandedRegion:Hide()
    end
end

--[[--------------------------------------------------------------------
    Singleton factory
----------------------------------------------------------------------]]

function CreateLoothingResponseButtonSettings()
    local obj = Loolib.CreateFromMixins(LoothingResponseButtonSettingsMixin)
    obj:Init()
    return obj
end
