--[[--------------------------------------------------------------------
    Loothing - Loot Council Addon for WoW 12.0+
    SettingsPanel - Configuration UI
----------------------------------------------------------------------]]

local Loolib = LibStub("Loolib")

--[[--------------------------------------------------------------------
    LoothingSettingsPanelMixin
----------------------------------------------------------------------]]

LoothingSettingsPanelMixin = {}

--- Initialize the settings panel
-- @param parent Frame - Parent frame
function LoothingSettingsPanelMixin:Init(parent)
    self.parent = parent
    self.councilRows = {}
    self.responseRows = {}

    self:CreateFrame()
    self:CreateElements()
end

--- Create the main frame
function LoothingSettingsPanelMixin:CreateFrame()
    local frame = CreateFrame("Frame", nil, self.parent)
    frame:SetAllPoints()

    self.frame = frame
end

--- Create UI elements
function LoothingSettingsPanelMixin:CreateElements()
    local L = LOOTHING_LOCALE

    -- Create scroll frame for settings
    local scrollFrame = CreateFrame("ScrollFrame", nil, self.frame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 4, -4)
    scrollFrame:SetPoint("BOTTOMRIGHT", -24, 4)

    local content = CreateFrame("Frame", nil, scrollFrame)
    content:SetSize(scrollFrame:GetWidth(), 800)
    scrollFrame:SetScrollChild(content)

    -- Store reference to mixin for nested callbacks
    content.mixin = self

    self.scrollFrame = scrollFrame
    self.content = content

    local yOffset = -8

    -- Voting Settings Section
    yOffset = self:CreateSection(L["VOTING_SETTINGS"], yOffset)
    yOffset = self:CreateVotingSettings(yOffset)

    -- Council Settings Section
    yOffset = yOffset - 16
    yOffset = self:CreateSection(L["COUNCIL_SETTINGS"], yOffset)
    yOffset = self:CreateCouncilSettings(yOffset)

    -- UI Settings Section
    yOffset = yOffset - 16
    yOffset = self:CreateSection(L["UI_SETTINGS"], yOffset)
    yOffset = self:CreateUISettings(yOffset)

    -- Auto-Pass Settings Section
    yOffset = yOffset - 16
    yOffset = self:CreateSection(L["AUTOPASS_SETTINGS"], yOffset)
    yOffset = self:CreateAutoPassSettings(yOffset)

    -- Response Settings Section
    yOffset = yOffset - 16
    yOffset = self:CreateSection(L["RESPONSE_SETTINGS"], yOffset)
    yOffset = self:CreateResponseSettings(yOffset)

    -- Update content height
    self.content:SetHeight(math.abs(yOffset) + 20)
end

--- Create a section header
-- @param title string
-- @param yOffset number
-- @return number - New yOffset
function LoothingSettingsPanelMixin:CreateSection(title, yOffset)
    local header = self.content:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    header:SetPoint("TOPLEFT", 8, yOffset)
    header:SetText(title)
    header:SetTextColor(1, 0.82, 0)

    local sep = self.content:CreateTexture(nil, "ARTWORK")
    sep:SetPoint("TOPLEFT", 8, yOffset - 18)
    sep:SetPoint("TOPRIGHT", -8, yOffset - 18)
    sep:SetHeight(1)
    sep:SetColorTexture(0.5, 0.5, 0.5, 0.5)

    return yOffset - 28
end

--[[--------------------------------------------------------------------
    Voting Settings
----------------------------------------------------------------------]]

--- Create voting settings controls
-- @param yOffset number
-- @return number - New yOffset
function LoothingSettingsPanelMixin:CreateVotingSettings(yOffset)
    local L = LOOTHING_LOCALE

    -- Voting Mode dropdown
    local modeLabel = self.content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    modeLabel:SetPoint("TOPLEFT", 16, yOffset)
    modeLabel:SetText(L["VOTING_MODE"])

    local modeButton = CreateFrame("Button", nil, self.content, "UIPanelButtonTemplate")
    modeButton:SetSize(150, 22)
    modeButton:SetPoint("TOPLEFT", 16, yOffset - 18)
    modeButton:SetScript("OnClick", function()
        self:ShowVotingModeDropdown()
    end)
    self.votingModeButton = modeButton

    yOffset = yOffset - 50

    -- Voting Timeout slider
    local timeoutLabel = self.content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    timeoutLabel:SetPoint("TOPLEFT", 16, yOffset)
    timeoutLabel:SetText(L["VOTING_TIMEOUT"])

    local timeoutSlider = CreateFrame("Slider", nil, self.content, "OptionsSliderTemplate")
    timeoutSlider:SetPoint("TOPLEFT", 16, yOffset - 24)
    timeoutSlider:SetSize(200, 16)
    timeoutSlider:SetMinMaxValues(10, 120)
    timeoutSlider:SetValueStep(5)
    if timeoutSlider.SetObeyStepOnDrag then
        timeoutSlider:SetObeyStepOnDrag(true)
    end

    if timeoutSlider.Low then
        timeoutSlider.Low:SetText("10s")
    end
    if timeoutSlider.High then
        timeoutSlider.High:SetText("120s")
    end

    local timeoutValue = self.content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    timeoutValue:SetPoint("TOP", timeoutSlider, "BOTTOM", 0, -2)

    timeoutSlider:SetScript("OnValueChanged", function(self, value)
        value = math.floor(value)
        timeoutValue:SetText(string.format("%ds", value))
        if Loothing.Settings then
            Loothing.Settings:SetVotingTimeout(value)
        end
    end)

    self.timeoutSlider = timeoutSlider
    self.timeoutValue = timeoutValue

    yOffset = yOffset - 60

    -- Auto-start session checkbox
    local autoStart = CreateFrame("CheckButton", nil, self.content, "UICheckButtonTemplate")
    autoStart:SetPoint("TOPLEFT", 12, yOffset)
    autoStart.text:SetText(L["AUTO_START_SESSION"])
    autoStart.text:SetFontObject(GameFontNormal)
    autoStart:SetScript("OnClick", function(self)
        if Loothing.Settings then
            Loothing.Settings:Set("settings.autoStartSession", self:GetChecked())
        end
    end)
    self.autoStartCheck = autoStart

    yOffset = yOffset - 30

    return yOffset
end

--- Show voting mode dropdown
function LoothingSettingsPanelMixin:ShowVotingModeDropdown()
    local L = LOOTHING_LOCALE

    local menu = {
        {
            text = L["MODE_SIMPLE"],
            notCheckable = true,
            func = function()
                self:SetVotingMode(LOOTHING_VOTING_MODE.SIMPLE)
            end
        },
        {
            text = L["MODE_RANKED"],
            notCheckable = true,
            func = function()
                self:SetVotingMode(LOOTHING_VOTING_MODE.RANKED_CHOICE)
            end
        },
    }

    if EasyMenu then
        EasyMenu(menu, CreateFrame("Frame", "LoothingModeMenu", UIParent, "UIDropDownMenuTemplate"), self.votingModeButton, 0, 0, "MENU")
    end
end

--- Set voting mode
-- @param mode string
function LoothingSettingsPanelMixin:SetVotingMode(mode)
    local L = LOOTHING_LOCALE

    if Loothing.Settings then
        Loothing.Settings:SetVotingMode(mode)
    end

    if mode == LOOTHING_VOTING_MODE.RANKED_CHOICE then
        self.votingModeButton:SetText(L["MODE_RANKED"])
    else
        self.votingModeButton:SetText(L["MODE_SIMPLE"])
    end
end

--[[--------------------------------------------------------------------
    Council Settings
----------------------------------------------------------------------]]

--- Create council settings controls
-- @param yOffset number
-- @return number - New yOffset
function LoothingSettingsPanelMixin:CreateCouncilSettings(yOffset)
    local L = LOOTHING_LOCALE

    -- Auto-include officers checkbox
    local autoOfficers = CreateFrame("CheckButton", nil, self.content, "UICheckButtonTemplate")
    autoOfficers:SetPoint("TOPLEFT", 12, yOffset)
    autoOfficers.text:SetText(L["AUTO_INCLUDE_OFFICERS"])
    autoOfficers.text:SetFontObject(GameFontNormal)
    autoOfficers:SetScript("OnClick", function(self)
        if Loothing.Council then
            Loothing.Council:SetAutoIncludeOfficers(self:GetChecked())
        end
    end)
    self.autoOfficersCheck = autoOfficers

    yOffset = yOffset - 26

    -- Auto-include raid leader checkbox
    local autoLeader = CreateFrame("CheckButton", nil, self.content, "UICheckButtonTemplate")
    autoLeader:SetPoint("TOPLEFT", 12, yOffset)
    autoLeader.text:SetText(L["AUTO_INCLUDE_LEADER"])
    autoLeader.text:SetFontObject(GameFontNormal)
    autoLeader:SetScript("OnClick", function(self)
        if Loothing.Council then
            Loothing.Council:SetAutoIncludeRaidLeader(self:GetChecked())
        end
    end)
    self.autoLeaderCheck = autoLeader

    yOffset = yOffset - 34

    -- Council members list
    local membersLabel = self.content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    membersLabel:SetPoint("TOPLEFT", 16, yOffset)
    membersLabel:SetText(L["COUNCIL_MEMBERS"])

    yOffset = yOffset - 20

    -- Members list container
    local membersList = CreateFrame("Frame", nil, self.content, "BackdropTemplate")
    membersList:SetPoint("TOPLEFT", 16, yOffset)
    membersList:SetSize(280, 120)
    membersList:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        tileSize = 8,
        edgeSize = 12,
        insets = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    membersList:SetBackdropColor(0.05, 0.05, 0.05, 0.9)

    self.membersList = membersList
    self.membersContent = CreateFrame("Frame", nil, membersList)
    self.membersContent:SetPoint("TOPLEFT", 4, -4)
    self.membersContent:SetPoint("BOTTOMRIGHT", -4, 4)

    yOffset = yOffset - 130

    -- Add member controls
    local addBox = CreateFrame("EditBox", nil, self.content, "InputBoxTemplate")
    addBox:SetSize(180, 20)
    addBox:SetPoint("TOPLEFT", 16, yOffset)
    addBox:SetAutoFocus(false)
    addBox:SetScript("OnEnterPressed", function(self)
        local name = self:GetText()
        if name and name ~= "" then
            self:GetParent().mixin:AddCouncilMember(name)
            self:SetText("")
        end
        self:ClearFocus()
    end)
    addBox:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
    end)
    self.addMemberBox = addBox
    addBox:GetParent().mixin = self

    local addButton = CreateFrame("Button", nil, self.content, "UIPanelButtonTemplate")
    addButton:SetSize(80, 22)
    addButton:SetPoint("LEFT", addBox, "RIGHT", 8, 0)
    addButton:SetText(L["ADD"])
    addButton:SetScript("OnClick", function()
        local name = addBox:GetText()
        if name and name ~= "" then
            self:AddCouncilMember(name)
            addBox:SetText("")
        end
    end)

    yOffset = yOffset - 34

    return yOffset
end

--- Refresh council members list
function LoothingSettingsPanelMixin:RefreshCouncilList()
    -- Clear existing rows
    for _, row in ipairs(self.councilRows) do
        row:Hide()
    end
    wipe(self.councilRows)

    if not Loothing.Council then return end

    local members = Loothing.Council:GetMembers()
    local yOffset = 0
    local rowHeight = 22

    for _, memberName in ipairs(members) do
        local row = self:CreateCouncilMemberRow(memberName, yOffset)
        self.councilRows[#self.councilRows + 1] = row
        yOffset = yOffset - rowHeight - 2
    end
end

--- Create a council member row
-- @param memberName string
-- @param yOffset number
-- @return Frame
function LoothingSettingsPanelMixin:CreateCouncilMemberRow(memberName, yOffset)
    local row = CreateFrame("Frame", nil, self.membersContent)
    row:SetPoint("TOPLEFT", 0, yOffset)
    row:SetPoint("TOPRIGHT", 0, yOffset)
    row:SetHeight(22)

    -- Name
    local nameText = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    nameText:SetPoint("LEFT", 4, 0)
    nameText:SetText(LoothingUtils.GetShortName(memberName))

    -- Remove button
    local removeButton = CreateFrame("Button", nil, row)
    removeButton:SetSize(16, 16)
    removeButton:SetPoint("RIGHT", -4, 0)
    removeButton:SetNormalTexture("Interface\\Buttons\\UI-StopButton")
    removeButton:SetHighlightTexture("Interface\\Buttons\\UI-StopButton")
    removeButton:GetHighlightTexture():SetVertexColor(1, 0, 0, 0.5)
    removeButton:SetScript("OnClick", function()
        self:RemoveCouncilMember(memberName)
    end)

    row:Show()
    return row
end

--- Add a council member
-- @param name string
function LoothingSettingsPanelMixin:AddCouncilMember(name)
    if not Loothing.Council then return end

    if Loothing.Council:AddMember(name) then
        self:RefreshCouncilList()
    end
end

--- Remove a council member
-- @param name string
function LoothingSettingsPanelMixin:RemoveCouncilMember(name)
    if not Loothing.Council then return end

    if Loothing.Council:RemoveMember(name) then
        self:RefreshCouncilList()
    end
end

--[[--------------------------------------------------------------------
    UI Settings
----------------------------------------------------------------------]]

--- Create UI settings controls
-- @param yOffset number
-- @return number - New yOffset
function LoothingSettingsPanelMixin:CreateUISettings(yOffset)
    local L = LOOTHING_LOCALE

    -- Show minimap button checkbox
    local showMinimap = CreateFrame("CheckButton", nil, self.content, "UICheckButtonTemplate")
    showMinimap:SetPoint("TOPLEFT", 12, yOffset)
    showMinimap.text:SetText(L["SHOW_MINIMAP_BUTTON"])
    showMinimap.text:SetFontObject(GameFontNormal)
    showMinimap:SetScript("OnClick", function(self)
        if Loothing.Settings then
            Loothing.Settings:Set("settings.showMinimapButton", self:GetChecked())
        end
        if Loothing.UI and Loothing.UI.MinimapButton then
            Loothing.UI.MinimapButton:UpdateVisibility()
        end
    end)
    self.showMinimapCheck = showMinimap

    yOffset = yOffset - 30

    -- UI Scale slider
    local scaleLabel = self.content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    scaleLabel:SetPoint("TOPLEFT", 16, yOffset)
    scaleLabel:SetText(L["UI_SCALE"])

    local scaleSlider = CreateFrame("Slider", nil, self.content, "OptionsSliderTemplate")
    scaleSlider:SetPoint("TOPLEFT", 16, yOffset - 24)
    scaleSlider:SetSize(200, 16)
    scaleSlider:SetMinMaxValues(0.5, 1.5)
    scaleSlider:SetValueStep(0.1)
    if scaleSlider.SetObeyStepOnDrag then
        scaleSlider:SetObeyStepOnDrag(true)
    end

    if scaleSlider.Low then
        scaleSlider.Low:SetText("50%")
    end
    if scaleSlider.High then
        scaleSlider.High:SetText("150%")
    end

    local scaleValue = self.content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    scaleValue:SetPoint("TOP", scaleSlider, "BOTTOM", 0, -2)

    scaleSlider:SetScript("OnValueChanged", function(self, value)
        value = math.floor(value * 10) / 10
        scaleValue:SetText(string.format("%.0f%%", value * 100))
        if Loothing.Settings then
            Loothing.Settings:Set("settings.uiScale", value)
        end
        if Loothing.UI and Loothing.UI.MainFrame then
            Loothing.UI.MainFrame:UpdateScale()
        end
    end)

    self.scaleSlider = scaleSlider
    self.scaleValue = scaleValue

    yOffset = yOffset - 60

    return yOffset
end

--[[--------------------------------------------------------------------
    Auto-Pass Settings
----------------------------------------------------------------------]]

--- Create auto-pass settings controls
-- @param yOffset number
-- @return number - New yOffset
function LoothingSettingsPanelMixin:CreateAutoPassSettings(yOffset)
    local L = LOOTHING_LOCALE

    -- Enable Auto-Pass (master toggle)
    local enableCheck = CreateFrame("CheckButton", nil, self.content, "UICheckButtonTemplate")
    enableCheck:SetPoint("TOPLEFT", 12, yOffset)
    enableCheck.text:SetText(L["ENABLE_AUTOPASS"])
    enableCheck.text:SetFontObject(GameFontNormal)
    enableCheck:SetScript("OnClick", function(checkBtn)
        local enabled = checkBtn:GetChecked()
        if Loothing.Settings then
            Loothing.Settings:SetAutoPassEnabled(enabled)
        end
        -- Enable/disable sub-options via mixin reference
        local panel = checkBtn:GetParent().mixin
        if panel and panel.autoPassWeaponsCheck then
            panel.autoPassWeaponsCheck:SetEnabled(enabled)
            panel.autoPassBoECheck:SetEnabled(enabled)
            panel.autoPassTransmogCheck:SetEnabled(enabled)
        end
    end)
    self.autoPassEnabledCheck = enableCheck

    yOffset = yOffset - 26

    -- Description text
    local descText = self.content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    descText:SetPoint("TOPLEFT", 32, yOffset)
    descText:SetText(L["AUTOPASS_DESC"])
    descText:SetTextColor(0.6, 0.6, 0.6)

    yOffset = yOffset - 18

    -- Auto-pass weapons with wrong stats
    local weaponsCheck = CreateFrame("CheckButton", nil, self.content, "UICheckButtonTemplate")
    weaponsCheck:SetPoint("TOPLEFT", 32, yOffset)
    weaponsCheck.text:SetText(L["AUTOPASS_WEAPONS"])
    weaponsCheck.text:SetFontObject(GameFontNormal)
    weaponsCheck:SetScript("OnClick", function(self)
        if Loothing.Settings then
            Loothing.Settings:SetAutoPassWeapons(self:GetChecked())
        end
    end)
    self.autoPassWeaponsCheck = weaponsCheck

    yOffset = yOffset - 26

    -- Auto-pass BoE items
    local boeCheck = CreateFrame("CheckButton", nil, self.content, "UICheckButtonTemplate")
    boeCheck:SetPoint("TOPLEFT", 32, yOffset)
    boeCheck.text:SetText(L["AUTOPASS_BOE"])
    boeCheck.text:SetFontObject(GameFontNormal)
    boeCheck:SetScript("OnClick", function(self)
        if Loothing.Settings then
            Loothing.Settings:SetAutoPassBoE(self:GetChecked())
        end
    end)
    self.autoPassBoECheck = boeCheck

    yOffset = yOffset - 26

    -- Auto-pass known transmog
    local transmogCheck = CreateFrame("CheckButton", nil, self.content, "UICheckButtonTemplate")
    transmogCheck:SetPoint("TOPLEFT", 32, yOffset)
    transmogCheck.text:SetText(L["AUTOPASS_TRANSMOG"])
    transmogCheck.text:SetFontObject(GameFontNormal)
    transmogCheck:SetScript("OnClick", function(self)
        if Loothing.Settings then
            Loothing.Settings:SetAutoPassTransmog(self:GetChecked())
        end
    end)
    self.autoPassTransmogCheck = transmogCheck

    yOffset = yOffset - 30

    return yOffset
end

--[[--------------------------------------------------------------------
    Response Settings
----------------------------------------------------------------------]]

--- Create response settings controls
-- @param yOffset number
-- @return number - New yOffset
function LoothingSettingsPanelMixin:CreateResponseSettings(yOffset)
    local L = LOOTHING_LOCALE

    -- Reset to defaults button
    local resetButton = CreateFrame("Button", nil, self.content, "UIPanelButtonTemplate")
    resetButton:SetSize(150, 22)
    resetButton:SetPoint("TOPLEFT", 16, yOffset)
    resetButton:SetText(L["RESET_RESPONSES"])
    resetButton:SetScript("OnClick", function()
        if Loothing.ResponseManager then
            Loothing.ResponseManager:ResetToDefaults()
            self:RefreshResponseList()
        end
    end)

    yOffset = yOffset - 34

    -- Create rows container
    self.responseListContainer = CreateFrame("Frame", nil, self.content)
    self.responseListContainer:SetPoint("TOPLEFT", 16, yOffset)
    self.responseListContainer:SetPoint("TOPRIGHT", -16, yOffset)
    self.responseListContainer:SetHeight(200)

    -- Populate response list
    self:RefreshResponseList()

    yOffset = yOffset - 210

    return yOffset
end

--- Refresh response list
function LoothingSettingsPanelMixin:RefreshResponseList()
    -- Clear existing rows
    for _, rowData in pairs(self.responseRows) do
        if rowData.row then
            rowData.row:Hide()
            rowData.row:SetParent(nil)
        end
    end
    wipe(self.responseRows)

    if not Loothing.ResponseManager or not self.responseListContainer then
        return
    end

    local responses = Loothing.ResponseManager:GetSortedResponses()
    local yOffset = 0

    for _, resp in ipairs(responses) do
        yOffset = self:CreateResponseRow(resp, yOffset)
    end
end

--- Create a response row
-- @param responseData table - { id, name, color, icon, sort }
-- @param yOffset number
-- @return number - New yOffset
function LoothingSettingsPanelMixin:CreateResponseRow(responseData, yOffset)
    local row = CreateFrame("Frame", nil, self.responseListContainer)
    row:SetPoint("TOPLEFT", 0, yOffset)
    row:SetPoint("TOPRIGHT", 0, yOffset)
    row:SetHeight(28)

    -- Color swatch button
    local colorButton = CreateFrame("Button", nil, row)
    colorButton:SetSize(20, 20)
    colorButton:SetPoint("LEFT", 0, 0)

    local colorTex = colorButton:CreateTexture(nil, "BACKGROUND")
    colorTex:SetAllPoints()
    local r, g, b, a = unpack(responseData.color)
    colorTex:SetColorTexture(r, g, b, a or 1)

    -- Border for color swatch
    local colorBorder = colorButton:CreateTexture(nil, "BORDER")
    colorBorder:SetAllPoints()
    colorBorder:SetColorTexture(0.3, 0.3, 0.3, 1)
    colorBorder:SetDrawLayer("BORDER", -1)

    colorButton:SetScript("OnClick", function()
        self:ShowColorPicker(responseData.id, responseData.color)
    end)

    -- Response name (editable)
    local nameEdit = CreateFrame("EditBox", nil, row, "InputBoxTemplate")
    nameEdit:SetSize(120, 20)
    nameEdit:SetPoint("LEFT", colorButton, "RIGHT", 8, 0)
    nameEdit:SetText(responseData.name)
    nameEdit:SetAutoFocus(false)
    nameEdit:SetScript("OnEnterPressed", function(self)
        if Loothing.ResponseManager then
            Loothing.ResponseManager:UpdateResponse(responseData.id, { name = self:GetText() })
        end
        self:ClearFocus()
    end)
    nameEdit:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
    end)

    -- Reorder buttons (up/down)
    local upButton = CreateFrame("Button", nil, row)
    upButton:SetSize(16, 16)
    upButton:SetPoint("LEFT", nameEdit, "RIGHT", 16, 0)
    upButton:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIcon-ScrollUp-Up")
    upButton:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIcon-ScrollUp-Up")
    upButton:GetHighlightTexture():SetAlpha(0.5)
    upButton:SetScript("OnClick", function()
        self:MoveResponse(responseData.id, -1)
    end)

    local downButton = CreateFrame("Button", nil, row)
    downButton:SetSize(16, 16)
    downButton:SetPoint("LEFT", upButton, "RIGHT", 2, 0)
    downButton:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Up")
    downButton:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Up")
    downButton:GetHighlightTexture():SetAlpha(0.5)
    downButton:SetScript("OnClick", function()
        self:MoveResponse(responseData.id, 1)
    end)

    -- Store row reference
    self.responseRows[responseData.id] = {
        row = row,
        colorTex = colorTex,
        nameEdit = nameEdit,
    }

    row:Show()
    return yOffset - 32
end

--- Show color picker for a response
-- @param responseID number
-- @param currentColor table - { r, g, b, a }
function LoothingSettingsPanelMixin:ShowColorPicker(responseID, currentColor)
    local r, g, b, a = unpack(currentColor)

    local function callback(restore)
        local newR, newG, newB
        if restore then
            newR, newG, newB = r, g, b
        else
            newR, newG, newB = ColorPickerFrame:GetColorRGB()
        end

        if Loothing.ResponseManager then
            Loothing.ResponseManager:SetResponseColor(responseID, newR, newG, newB, a)
        end

        -- Update UI
        local rowData = self.responseRows[responseID]
        if rowData and rowData.colorTex then
            rowData.colorTex:SetColorTexture(newR, newG, newB, a or 1)
        end
    end

    ColorPickerFrame:SetupColorPickerAndShow({
        r = r,
        g = g,
        b = b,
        swatchFunc = callback,
        cancelFunc = callback,
    })
end

--- Move response up or down in sort order
-- @param responseID number
-- @param direction number - -1 for up, 1 for down
function LoothingSettingsPanelMixin:MoveResponse(responseID, direction)
    if not Loothing.ResponseManager then return end

    local responses = Loothing.ResponseManager:GetSortedResponses()
    local currentIndex

    for i, resp in ipairs(responses) do
        if resp.id == responseID then
            currentIndex = i
            break
        end
    end

    if not currentIndex then return end

    local targetIndex = currentIndex + direction
    if targetIndex < 1 or targetIndex > #responses then return end

    -- Swap sort orders
    local current = responses[currentIndex]
    local target = responses[targetIndex]

    Loothing.ResponseManager:SetResponseSort(current.id, target.sort)
    Loothing.ResponseManager:SetResponseSort(target.id, current.sort)

    self:RefreshResponseList()
end

--[[--------------------------------------------------------------------
    Refresh
----------------------------------------------------------------------]]

--- Refresh all settings from storage
function LoothingSettingsPanelMixin:Refresh()
    local L = LOOTHING_LOCALE

    if not Loothing.Settings then return end

    -- Voting mode
    local mode = Loothing.Settings:GetVotingMode()
    if mode == LOOTHING_VOTING_MODE.RANKED_CHOICE then
        self.votingModeButton:SetText(L["MODE_RANKED"])
    else
        self.votingModeButton:SetText(L["MODE_SIMPLE"])
    end

    -- Timeout
    local timeout = Loothing.Settings:GetVotingTimeout() or LOOTHING_TIMING.VOTING_DEFAULT
    self.timeoutSlider:SetValue(timeout)

    -- Auto-start
    local autoStart = Loothing.Settings:Get("voting.autoStartSession")
    self.autoStartCheck:SetChecked(autoStart)

    -- Council settings
    if Loothing.Council then
        self.autoOfficersCheck:SetChecked(Loothing.Council:GetAutoIncludeOfficers())
        self.autoLeaderCheck:SetChecked(Loothing.Council:GetAutoIncludeRaidLeader())
    end

    -- UI settings
    local showMinimap = Loothing.Settings:Get("settings.showMinimapButton")
    if showMinimap == nil then showMinimap = true end
    self.showMinimapCheck:SetChecked(showMinimap)

    local scale = Loothing.Settings:Get("settings.uiScale") or 1.0
    self.scaleSlider:SetValue(scale)

    -- Auto-pass settings
    local autoPassEnabled = Loothing.Settings:GetAutoPassEnabled()
    self.autoPassEnabledCheck:SetChecked(autoPassEnabled)

    self.autoPassWeaponsCheck:SetChecked(Loothing.Settings:GetAutoPassWeapons())
    self.autoPassWeaponsCheck:SetEnabled(autoPassEnabled)

    self.autoPassBoECheck:SetChecked(Loothing.Settings:GetAutoPassBoE())
    self.autoPassBoECheck:SetEnabled(autoPassEnabled)

    self.autoPassTransmogCheck:SetChecked(Loothing.Settings:GetAutoPassTransmog())
    self.autoPassTransmogCheck:SetEnabled(autoPassEnabled)

    -- Council list
    self:RefreshCouncilList()

    -- Response list
    self:RefreshResponseList()
end

--[[--------------------------------------------------------------------
    Frame Access
----------------------------------------------------------------------]]

function LoothingSettingsPanelMixin:GetFrame()
    return self.frame
end

function LoothingSettingsPanelMixin:Show()
    self.frame:Show()
    self:Refresh()
end

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
