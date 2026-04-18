--[[--------------------------------------------------------------------
    Loothing - Loot Council Addon for WoW 12.0+
    SimulatorPanel - Floating UI for the boss-kill simulator

    Visual front-end over ns.Simulator. Each button maps 1:1 to a slash
    subcommand so behavior lives in the Simulator module, not here.
----------------------------------------------------------------------]]


local _, ns = ...
local Loolib = LibStub("Loolib")
local Loothing = ns.Addon
local SkinningMixin = ns.SkinningMixin

local PANEL_WIDTH = 380
local PANEL_HEIGHT = 460
local QUEUE_ROW_HEIGHT = 22

local SimulatorPanelMixin = ns.SimulatorPanelMixin or {}
ns.SimulatorPanelMixin = SimulatorPanelMixin

--[[--------------------------------------------------------------------
    Helpers
----------------------------------------------------------------------]]

local function makeBackdrop()
    return {
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        tile = false, edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 },
    }
end

local function styleSurface(frame, bgColor, borderColor)
    frame:SetBackdrop(makeBackdrop())
    frame:SetBackdropColor(unpack(bgColor or { 0.08, 0.08, 0.08, 0.95 }))
    frame:SetBackdropBorderColor(unpack(borderColor or { 0.3, 0.3, 0.3, 1 }))
end

local function getBosses()
    if ns.Simulator and ns.Simulator.ListBosses then
        return ns.Simulator:ListBosses()
    end
    return {}
end

local function getCouncil()
    if ns.Simulator and ns.Simulator.GetCouncil then
        return ns.Simulator:GetCouncil()
    end
    return {}
end

--[[--------------------------------------------------------------------
    Init
----------------------------------------------------------------------]]

function SimulatorPanelMixin:Init()
    if self._built then return end
    self._built = true

    self.selectedBoss = nil       -- table from ListBosses or nil for random
    self.selectedLooter = nil     -- name string or nil for random
    self.itemCount = 3
    self.queueRows = {}

    self:BuildFrame()
    self:RegisterCallbacks()
    self:RefreshAll()
end

--[[--------------------------------------------------------------------
    Frame construction
----------------------------------------------------------------------]]

function SimulatorPanelMixin:BuildFrame()
    local frame = CreateFrame("Frame", "LoothingSimulatorPanel", UIParent, "BackdropTemplate")
    frame:SetSize(PANEL_WIDTH, PANEL_HEIGHT)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("DIALOG")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function(f) f:StartMoving() end)
    frame:SetScript("OnDragStop", function(f) f:StopMovingOrSizing() end)
    styleSurface(frame)
    frame:Hide()
    self.frame = frame

    local WM = Loolib:GetModule("WindowManager")
    if WM and WM.Register then WM:Register(frame) end

    -- Title
    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOPLEFT", 10, -10)
    title:SetText("Loothing Simulator")
    title:SetTextColor(1, 0.82, 0)

    -- Close button
    local closeBtn = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    closeBtn:SetSize(22, 22)
    closeBtn:SetPoint("TOPRIGHT", -2, -2)
    closeBtn:SetScript("OnClick", function() self:Hide() end)

    -- Status row
    local statusRow = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    statusRow:SetPoint("TOPLEFT", 8, -32)
    statusRow:SetPoint("TOPRIGHT", -8, -32)
    statusRow:SetHeight(24)
    styleSurface(statusRow, { 0.06, 0.06, 0.08, 1 }, { 0.25, 0.25, 0.3, 1 })

    self.statusText = statusRow:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    self.statusText:SetPoint("LEFT", 8, 0)

    self.toggleBtn = ns.CreateThemedButton(statusRow)
    self.toggleBtn:SetSize(60, 18)
    self.toggleBtn:SetPoint("RIGHT", -6, 0)
    self.toggleBtn:SetText("Toggle")
    self.toggleBtn:SetScript("OnClick", function()
        if ns.Simulator:IsActive() then
            ns.Simulator:Disable()
        else
            ns.Simulator:Enable(true)
        end
    end)
    SkinningMixin:StylePlainButton(self.toggleBtn)

    -- Section: Fire / Queue kill controls
    self:BuildKillSection()
    -- Section: Add loot
    self:BuildLootSection()
    -- Section: Queue list
    self:BuildQueueSection()
    -- Section: Footer
    self:BuildFooter()
end

function SimulatorPanelMixin:BuildKillSection()
    local section = CreateFrame("Frame", nil, self.frame, "BackdropTemplate")
    section:SetPoint("TOPLEFT", 8, -62)
    section:SetPoint("TOPRIGHT", -8, -62)
    section:SetHeight(96)
    styleSurface(section, { 0.05, 0.05, 0.07, 1 }, { 0.2, 0.2, 0.25, 1 })

    local label = section:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    label:SetPoint("TOPLEFT", 8, -6)
    label:SetText("Fire / Queue Kill")
    label:SetTextColor(0.7, 0.7, 0.85)

    -- Boss dropdown
    local bossLabel = section:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    bossLabel:SetPoint("TOPLEFT", 8, -26)
    bossLabel:SetText("Boss:")
    bossLabel:SetTextColor(0.8, 0.8, 0.8)

    self.bossDropdown = CreateFrame("Frame", "LoothingSimBossDropdown", section, "UIDropDownMenuTemplate")
    self.bossDropdown:SetPoint("LEFT", bossLabel, "RIGHT", -8, -2)
    UIDropDownMenu_SetWidth(self.bossDropdown, 200)
    UIDropDownMenu_Initialize(self.bossDropdown, function(_, _, _) self:PopulateBossDropdown() end)
    UIDropDownMenu_SetText(self.bossDropdown, "Random")

    -- Item count
    local countLabel = section:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    countLabel:SetPoint("TOPLEFT", 8, -52)
    countLabel:SetText("Items:")
    countLabel:SetTextColor(0.8, 0.8, 0.8)

    local countBox = CreateFrame("EditBox", nil, section, "InputBoxTemplate")
    countBox:SetSize(40, 22)
    countBox:SetPoint("LEFT", countLabel, "RIGHT", 8, 0)
    countBox:SetAutoFocus(false)
    countBox:SetNumeric(true)
    countBox:SetMaxLetters(2)
    countBox:SetText(tostring(self.itemCount))
    countBox:SetScript("OnTextChanged", function(eb)
        self.itemCount = math.max(1, tonumber(eb:GetText()) or 1)
    end)
    self.countBox = countBox

    -- Looter dropdown
    local looterLabel = section:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    looterLabel:SetPoint("LEFT", countBox, "RIGHT", 12, 0)
    looterLabel:SetText("Looter:")
    looterLabel:SetTextColor(0.8, 0.8, 0.8)

    self.looterDropdown = CreateFrame("Frame", "LoothingSimLooterDropdown", section, "UIDropDownMenuTemplate")
    self.looterDropdown:SetPoint("LEFT", looterLabel, "RIGHT", -8, -2)
    UIDropDownMenu_SetWidth(self.looterDropdown, 130)
    UIDropDownMenu_Initialize(self.looterDropdown, function(_, _, _) self:PopulateLooterDropdown() end)
    UIDropDownMenu_SetText(self.looterDropdown, "Random")

    -- Buttons
    self.fireKillBtn = ns.CreateThemedButton(section)
    self.fireKillBtn:SetSize(90, 22)
    self.fireKillBtn:SetPoint("BOTTOMLEFT", 8, 6)
    self.fireKillBtn:SetText("Fire Kill")
    self.fireKillBtn:SetScript("OnClick", function() self:OnFireKill() end)
    SkinningMixin:StylePlainButton(self.fireKillBtn, "primary")

    self.queueKillBtn = ns.CreateThemedButton(section)
    self.queueKillBtn:SetSize(90, 22)
    self.queueKillBtn:SetPoint("LEFT", self.fireKillBtn, "RIGHT", 6, 0)
    self.queueKillBtn:SetText("Queue Kill")
    self.queueKillBtn:SetScript("OnClick", function() self:OnQueueKill() end)
    SkinningMixin:StylePlainButton(self.queueKillBtn)
end

function SimulatorPanelMixin:BuildLootSection()
    local section = CreateFrame("Frame", nil, self.frame, "BackdropTemplate")
    section:SetPoint("TOPLEFT", 8, -164)
    section:SetPoint("TOPRIGHT", -8, -164)
    section:SetHeight(58)
    styleSurface(section, { 0.05, 0.05, 0.07, 1 }, { 0.2, 0.2, 0.25, 1 })

    local label = section:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    label:SetPoint("TOPLEFT", 8, -6)
    label:SetText("Add Loot Drop")
    label:SetTextColor(0.7, 0.7, 0.85)

    -- Item input (link or id)
    local editFrame = CreateFrame("Frame", nil, section, "BackdropTemplate")
    editFrame:SetPoint("TOPLEFT", 8, -22)
    editFrame:SetPoint("TOPRIGHT", -88, -22)
    editFrame:SetHeight(22)
    styleSurface(editFrame, { 0.04, 0.04, 0.04, 1 }, { 0.4, 0.4, 0.4, 1 })

    local editBox = CreateFrame("EditBox", nil, editFrame)
    editBox:SetPoint("TOPLEFT", 4, -2)
    editBox:SetPoint("BOTTOMRIGHT", -4, 2)
    editBox:SetAutoFocus(false)
    editBox:SetFontObject("ChatFontNormal")
    editBox:SetScript("OnReceiveDrag", function(eb)
        local kind, _, link = GetCursorInfo()
        if kind == "item" and link then
            eb:SetText(link)
            ClearCursor()
        end
    end)
    editBox:SetScript("OnMouseDown", function(eb)
        local kind, _, link = GetCursorInfo()
        if kind == "item" and link then
            eb:SetText(link)
            ClearCursor()
        end
    end)
    self.lootInput = editBox

    self.addLootBtn = ns.CreateThemedButton(section)
    self.addLootBtn:SetSize(76, 22)
    self.addLootBtn:SetPoint("TOPRIGHT", -8, -22)
    self.addLootBtn:SetText("Add Loot")
    self.addLootBtn:SetScript("OnClick", function() self:OnAddLoot() end)
    SkinningMixin:StylePlainButton(self.addLootBtn)

    local hint = section:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    hint:SetPoint("BOTTOMLEFT", 8, 4)
    hint:SetText("Item link or ID  -  drag from bags supported")
    hint:SetTextColor(0.5, 0.5, 0.5)
end

function SimulatorPanelMixin:BuildQueueSection()
    local section = CreateFrame("Frame", nil, self.frame, "BackdropTemplate")
    section:SetPoint("TOPLEFT", 8, -228)
    section:SetPoint("BOTTOMRIGHT", -8, 60)
    styleSurface(section, { 0.05, 0.05, 0.07, 1 }, { 0.2, 0.2, 0.25, 1 })

    self.queueHeader = section:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    self.queueHeader:SetPoint("TOPLEFT", 8, -6)
    self.queueHeader:SetText("Queued Kills (0)")
    self.queueHeader:SetTextColor(0.7, 0.7, 0.85)

    local scroll = CreateFrame("ScrollFrame", nil, section, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 6, -22)
    scroll:SetPoint("BOTTOMRIGHT", -24, 6)
    self.queueScroll = scroll

    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(1, 1)
    scroll:SetScrollChild(content)
    self.queueContent = content

    scroll:SetScript("OnSizeChanged", function(_sf, w)
        content:SetWidth(w)
    end)

    self.queueEmpty = section:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    self.queueEmpty:SetPoint("CENTER")
    self.queueEmpty:SetText("Queue is empty.")
    self.queueEmpty:SetTextColor(0.4, 0.4, 0.4)
end

function SimulatorPanelMixin:BuildFooter()
    local footer = CreateFrame("Frame", nil, self.frame)
    footer:SetPoint("BOTTOMLEFT", 8, 6)
    footer:SetPoint("BOTTOMRIGHT", -8, 6)
    footer:SetHeight(48)

    -- Top row: Fire Next, Flush
    self.fireNextBtn = ns.CreateThemedButton(footer)
    self.fireNextBtn:SetSize(90, 22)
    self.fireNextBtn:SetPoint("TOPLEFT")
    self.fireNextBtn:SetText("Fire Next")
    self.fireNextBtn:SetScript("OnClick", function()
        ns.Simulator:FireNext()
    end)
    SkinningMixin:StylePlainButton(self.fireNextBtn)

    self.flushBtn = ns.CreateThemedButton(footer)
    self.flushBtn:SetSize(90, 22)
    self.flushBtn:SetPoint("LEFT", self.fireNextBtn, "RIGHT", 6, 0)
    self.flushBtn:SetText("Flush All")
    self.flushBtn:SetScript("OnClick", function()
        ns.Simulator:Flush()
    end)
    SkinningMixin:StylePlainButton(self.flushBtn)

    -- Autofire checkbox
    local autofireCheck = CreateFrame("CheckButton", nil, footer, "UICheckButtonTemplate")
    autofireCheck:SetSize(20, 20)
    autofireCheck:SetPoint("LEFT", self.flushBtn, "RIGHT", 12, 0)
    autofireCheck:SetScript("OnClick", function(cb)
        ns.Simulator:SetAutoFire(cb:GetChecked())
    end)
    local autofireLabel = footer:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    autofireLabel:SetPoint("LEFT", autofireCheck, "RIGHT", 2, 0)
    autofireLabel:SetText("Autofire next on session end")
    autofireLabel:SetTextColor(0.85, 0.85, 0.85)
    self.autofireCheck = autofireCheck

    -- Bottom row: End Session, Reset
    self.endBtn = ns.CreateThemedButton(footer)
    self.endBtn:SetSize(110, 22)
    self.endBtn:SetPoint("BOTTOMLEFT")
    self.endBtn:SetText("End Session")
    self.endBtn:SetScript("OnClick", function()
        ns.Simulator:EndSession()
    end)
    SkinningMixin:StylePlainButton(self.endBtn)

    self.resetBtn = ns.CreateThemedButton(footer)
    self.resetBtn:SetSize(80, 22)
    self.resetBtn:SetPoint("BOTTOMRIGHT")
    self.resetBtn:SetText("Reset")
    self.resetBtn:SetScript("OnClick", function()
        ns.Simulator:Reset()
    end)
    SkinningMixin:StylePlainButton(self.resetBtn)
end

--[[--------------------------------------------------------------------
    Dropdown population
----------------------------------------------------------------------]]

function SimulatorPanelMixin:PopulateBossDropdown()
    local info = UIDropDownMenu_CreateInfo()

    info.text = "Random"
    info.checked = (self.selectedBoss == nil)
    info.func = function()
        self.selectedBoss = nil
        UIDropDownMenu_SetText(self.bossDropdown, "Random")
        CloseDropDownMenus()
    end
    UIDropDownMenu_AddButton(info)

    for _, b in ipairs(getBosses()) do
        info = UIDropDownMenu_CreateInfo()
        info.text = string.format("%d. %s", b.order, b.name)
        info.checked = (self.selectedBoss and self.selectedBoss.id == b.id) or false
        info.func = function()
            self.selectedBoss = b
            UIDropDownMenu_SetText(self.bossDropdown, b.name)
            CloseDropDownMenus()
        end
        UIDropDownMenu_AddButton(info)
    end
end

function SimulatorPanelMixin:PopulateLooterDropdown()
    local info = UIDropDownMenu_CreateInfo()

    info.text = "Random"
    info.checked = (self.selectedLooter == nil)
    info.func = function()
        self.selectedLooter = nil
        UIDropDownMenu_SetText(self.looterDropdown, "Random")
        CloseDropDownMenus()
    end
    UIDropDownMenu_AddButton(info)

    info = UIDropDownMenu_CreateInfo()
    info.text = "Player (you)"
    info.checked = (self.selectedLooter == "self")
    info.func = function()
        self.selectedLooter = "self"
        UIDropDownMenu_SetText(self.looterDropdown, "You")
        CloseDropDownMenus()
    end
    UIDropDownMenu_AddButton(info)

    for _, m in ipairs(getCouncil()) do
        info = UIDropDownMenu_CreateInfo()
        info.text = m.shortName or m.name
        info.checked = (self.selectedLooter == m.name)
        info.func = function()
            self.selectedLooter = m.name
            UIDropDownMenu_SetText(self.looterDropdown, info.text)
            CloseDropDownMenus()
        end
        UIDropDownMenu_AddButton(info)
    end
end

--[[--------------------------------------------------------------------
    Action handlers
----------------------------------------------------------------------]]

function SimulatorPanelMixin:GetBossToken()
    if self.selectedBoss then return tostring(self.selectedBoss.id) end
    return "random"
end

function SimulatorPanelMixin:GetLooterToken()
    if not self.selectedLooter then return nil end
    return self.selectedLooter
end

function SimulatorPanelMixin:OnFireKill()
    if not ns.Simulator:IsActive() then
        ns.Simulator:Enable(true)
    end
    ns.Simulator:FireKillForBoss(self:GetBossToken(), self.itemCount, self:GetLooterToken())
end

function SimulatorPanelMixin:OnQueueKill()
    if not ns.Simulator:IsActive() then
        ns.Simulator:Enable(true)
    end
    ns.Simulator:QueueKill(self:GetBossToken(), self.itemCount, self:GetLooterToken())
end

function SimulatorPanelMixin:OnAddLoot()
    if not ns.Simulator:IsActive() then
        ns.Simulator:Enable(true)
    end
    local text = self.lootInput:GetText() or ""
    if text == "" then
        if Loothing.Print then Loothing:Print("Enter an item link or item ID first.") end
        return
    end
    ns.Simulator:AddLoot(text, self:GetLooterToken())
end

--[[--------------------------------------------------------------------
    Refresh + callbacks
----------------------------------------------------------------------]]

function SimulatorPanelMixin:RegisterCallbacks()
    if not ns.Simulator or not ns.Simulator.RegisterCallback then return end
    ns.Simulator:RegisterCallback("OnSimStateChanged", function() self:RefreshAll() end, "SimulatorPanel")
    ns.Simulator:RegisterCallback("OnQueueChanged", function() self:RefreshQueue() end, "SimulatorPanel")
    ns.Simulator:RegisterCallback("OnAutofireChanged", function(_, on) self:RefreshAutofire(on) end, "SimulatorPanel")

    if Loothing.Session and Loothing.Session.RegisterCallback then
        Loothing.Session:RegisterCallback("OnSessionStarted", function() self:RefreshStatus() end, "SimulatorPanel")
        Loothing.Session:RegisterCallback("OnSessionEnded", function() self:RefreshStatus() end, "SimulatorPanel")
    end
end

function SimulatorPanelMixin:RefreshAll()
    self:RefreshStatus()
    self:RefreshQueue()
    self:RefreshAutofire(ns.Simulator and ns.Simulator:IsAutoFire())
end

function SimulatorPanelMixin:RefreshStatus()
    if not self.statusText then return end
    local active = ns.Simulator and ns.Simulator:IsActive() or false
    local sessActive = Loothing.Session
        and Loothing.Session.state ~= Loothing.SessionState.INACTIVE
    local color = active and "|cff66ff66" or "|cffff6666"
    local sessText = sessActive and "|cff66ff66active|r" or "|cff999999inactive|r"
    self.statusText:SetText(string.format("Sim: %s%s|r   Session: %s",
        color, active and "ACTIVE" or "OFF", sessText))
end

function SimulatorPanelMixin:RefreshAutofire(on)
    if self.autofireCheck then
        self.autofireCheck:SetChecked(on and true or false)
    end
end

function SimulatorPanelMixin:RefreshQueue()
    if not self.queueContent then return end
    local queue = (ns.Simulator and ns.Simulator:GetQueue()) or {}

    self.queueHeader:SetText(string.format("Queued Kills (%d)", #queue))
    if #queue == 0 then
        self.queueEmpty:Show()
    else
        self.queueEmpty:Hide()
    end

    -- Hide all existing rows
    for _, row in ipairs(self.queueRows) do row:Hide() end

    for i, entry in ipairs(queue) do
        local row = self.queueRows[i]
        if not row then
            row = self:CreateQueueRow(self.queueContent)
            self.queueRows[i] = row
        end
        row:Show()
        row:SetPoint("TOPLEFT", 0, -((i - 1) * QUEUE_ROW_HEIGHT))
        row:SetPoint("TOPRIGHT", 0, -((i - 1) * QUEUE_ROW_HEIGHT))
        row.label:SetText(string.format("%d. %s  (%d items)",
            i, entry.encounter.name, entry.itemCount or #entry.items))
        row.removeBtn:SetScript("OnClick", function()
            ns.Simulator:RemoveQueueEntry(i)
        end)
    end

    self.queueContent:SetHeight(math.max(1, #queue * QUEUE_ROW_HEIGHT))
end

function SimulatorPanelMixin:CreateQueueRow(parent)
    local row = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    row:SetHeight(QUEUE_ROW_HEIGHT)
    styleSurface(row, { 0.07, 0.07, 0.09, 1 }, { 0.18, 0.18, 0.22, 1 })

    row.label = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.label:SetPoint("LEFT", 6, 0)
    row.label:SetTextColor(0.9, 0.9, 0.9)

    row.removeBtn = ns.CreateThemedButton(row)
    row.removeBtn:SetSize(20, 18)
    row.removeBtn:SetPoint("RIGHT", -4, 0)
    row.removeBtn:SetText("x")
    SkinningMixin:StylePlainButton(row.removeBtn)
    return row
end

--[[--------------------------------------------------------------------
    Show / Hide / Toggle
----------------------------------------------------------------------]]

function SimulatorPanelMixin:Show()
    self:Init()
    self.frame:Show()
    self:RefreshAll()
end

function SimulatorPanelMixin:Hide()
    if self.frame then self.frame:Hide() end
end

function SimulatorPanelMixin:Toggle()
    self:Init()
    if self.frame:IsShown() then
        self:Hide()
    else
        self:Show()
    end
end

function SimulatorPanelMixin:IsShown()
    return self.frame and self.frame:IsShown()
end

--[[--------------------------------------------------------------------
    Module registration

    Exposed via ns.SimulatorPanelMixin (set at the top of file). We do NOT
    write to Loothing.UI here — Core/Init.lua:401 reassigns Loothing.UI
    during PLAYER_LOGIN, which would clobber our entry. Lookups happen via
    ns.SimulatorPanelMixin (see Debug/Simulator.lua panel handler).
----------------------------------------------------------------------]]
