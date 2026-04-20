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

local AnimationPresets = Loolib.AnimationPresets
local PixelUtil = Loolib.PixelUtil
local ApplyAccentGlow = ns.FramePolish and ns.FramePolish.ApplyAccentGlow
local AttachIconButtonPolish = ns.FramePolish and ns.FramePolish.AttachIconButtonPolish

local PANEL_WIDTH = 420    -- widened from 380; ListRaids raid names need the room
local PANEL_HEIGHT = 540   -- +52 over original to give each row proper breathing space
local HEADER_HEIGHT = 36
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

local function getRaids()
    if ns.Simulator and ns.Simulator.ListRaids then
        return ns.Simulator:ListRaids()
    end
    return {}
end

local function getSelectedRaidID()
    if ns.Simulator and ns.Simulator.GetSelectedRaidID then
        return ns.Simulator:GetSelectedRaidID()
    end
    return nil
end

local function getCurrentRaidName()
    if ns.Simulator and ns.Simulator.GetCurrentRaidName then
        return ns.Simulator:GetCurrentRaidName()
    end
    return "(unknown)"
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
    frame:SetAlpha(0)   -- fade in from 0 on first Show()
    self.frame = frame

    local WM = Loolib:GetModule("WindowManager")
    if WM and WM.Register then WM:Register(frame) end

    -- Accent glow strip behind the title (dynamic from SkinningMixin accent)
    local headerStrip = frame:CreateTexture(nil, "BACKGROUND", nil, 2)
    headerStrip:SetPoint("TOPLEFT", 2, -2)
    headerStrip:SetPoint("TOPRIGHT", -2, -2)
    headerStrip:SetHeight(HEADER_HEIGHT)
    headerStrip:SetColorTexture(1, 1, 1, 1)
    self.headerStrip = headerStrip
    if ApplyAccentGlow then ApplyAccentGlow(headerStrip, 0.18) end

    -- Pixel-perfect outer border
    if PixelUtil and type(PixelUtil.SetThinBorder) == "function" then
        local bc = (SkinningMixin and SkinningMixin:GetColor("borderStrong")) or { 0, 0, 0, 1 }
        self.pixelBorder = PixelUtil.SetThinBorder(frame, bc)
    end

    -- Title
    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOPLEFT", 12, -12)
    title:SetText("Loothing Simulator")
    title:SetTextColor(1, 0.82, 0)

    -- Close button
    local closeBtn = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    closeBtn:SetSize(22, 22)
    closeBtn:SetPoint("TOPRIGHT", -2, -2)
    closeBtn:SetScript("OnClick", function() self:Hide() end)
    if AttachIconButtonPolish then
        AttachIconButtonPolish(closeBtn, { hoverScale = 1.15, pressScale = 0.90 })
    end

    -- Status row (below the 36-px accent header band)
    local statusRow = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    statusRow:SetPoint("TOPLEFT", 8, -44)
    statusRow:SetPoint("TOPRIGHT", -8, -44)
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
            -- Try Enable without force first so the safety gates
            -- (real raid, active session, open picker, encounter in
            -- progress) can refuse and surface a chat warning. If the
            -- user wants to bypass, they can call `/lt sim on force`.
            ns.Simulator:Enable(false)
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
    section:SetPoint("TOPLEFT", 8, -74)
    section:SetPoint("TOPRIGHT", -8, -74)
    section:SetHeight(156)   -- room for 4 rows at 28px + label + bottom buttons
    styleSurface(section, { 0.05, 0.05, 0.07, 1 }, { 0.2, 0.2, 0.25, 1 })

    local label = section:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    label:SetPoint("TOPLEFT", 8, -6)
    label:SetText("Fire / Queue Kill")
    label:SetTextColor(0.7, 0.7, 0.85)

    local LABEL_COL = 56  -- pixel offset where dropdowns start (past the "Raid:/Boss:" labels)
    local ROW_Y = { -30, -60, -90 }   -- Raid, Boss, Items/Looter

    -- Raid row
    local raidLabel = section:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    raidLabel:SetPoint("TOPLEFT", 8, ROW_Y[1])
    raidLabel:SetText("Raid:")
    raidLabel:SetTextColor(0.8, 0.8, 0.8)

    self.raidDropdown = ns.CreateThemedDropdown(section, {
        width = 336,
        placeholder = getCurrentRaidName(),
        getOptions = function() return self:BuildRaidOptions() end,
        getSelected = function() return getSelectedRaidID() end,
        onSelect = function(_, value) self:OnRaidSelected(value) end,
    })
    self.raidDropdown:SetPoint("TOPLEFT", section, "TOPLEFT", LABEL_COL, ROW_Y[1] - 2)

    -- Boss row
    local bossLabel = section:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    bossLabel:SetPoint("TOPLEFT", 8, ROW_Y[2])
    bossLabel:SetText("Boss:")
    bossLabel:SetTextColor(0.8, 0.8, 0.8)

    self.bossDropdown = ns.CreateThemedDropdown(section, {
        width = 336,
        placeholder = "Random",
        getOptions = function() return self:BuildBossOptions() end,
        getSelected = function() return self:GetBossToken() end,
        onSelect = function(_, value) self:OnBossSelected(value) end,
    })
    self.bossDropdown:SetPoint("TOPLEFT", section, "TOPLEFT", LABEL_COL, ROW_Y[2] - 2)

    -- Items + Looter row
    local countLabel = section:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    countLabel:SetPoint("TOPLEFT", 8, ROW_Y[3])
    countLabel:SetText("Items:")
    countLabel:SetTextColor(0.8, 0.8, 0.8)

    local countBox = CreateFrame("EditBox", nil, section, "InputBoxTemplate")
    countBox:SetSize(36, 22)
    countBox:SetPoint("TOPLEFT", section, "TOPLEFT", LABEL_COL, ROW_Y[3] - 2)
    countBox:SetAutoFocus(false)
    countBox:SetNumeric(true)
    countBox:SetMaxLetters(2)
    countBox:SetText(tostring(self.itemCount))
    countBox:SetScript("OnTextChanged", function(eb)
        self.itemCount = math.max(1, tonumber(eb:GetText()) or 1)
    end)
    self.countBox = countBox

    local looterLabel = section:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    looterLabel:SetPoint("LEFT", countBox, "RIGHT", 14, 0)
    looterLabel:SetText("Looter:")
    looterLabel:SetTextColor(0.8, 0.8, 0.8)

    self.looterDropdown = ns.CreateThemedDropdown(section, {
        width = 220,
        placeholder = "Random",
        getOptions = function() return self:BuildLooterOptions() end,
        -- The Random row uses sentinel "_random" so the check-mark lines up
        -- when no looter is picked (GetLooterToken returns nil for random).
        getSelected = function() return self.selectedLooter or "_random" end,
        onSelect = function(_, value) self:OnLooterSelected(value) end,
    })
    self.looterDropdown:SetPoint("LEFT", looterLabel, "RIGHT", 6, 0)

    -- Buttons (dropdowns' popups render over them so put them at the bottom safely)
    self.fireKillBtn = ns.CreateThemedButton(section)
    self.fireKillBtn:SetSize(90, 22)
    self.fireKillBtn:SetPoint("BOTTOMLEFT", 8, 8)
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
    section:SetPoint("TOPLEFT", 8, -236)
    section:SetPoint("TOPRIGHT", -8, -236)
    section:SetHeight(78)   -- taller so the hint text has its own line below the editbox
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
    section:SetPoint("TOPLEFT", 8, -320)
    section:SetPoint("BOTTOMRIGHT", -8, 60)
    styleSurface(section, { 0.05, 0.05, 0.07, 1 }, { 0.2, 0.2, 0.25, 1 })

    self.queueHeader = section:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    self.queueHeader:SetPoint("TOPLEFT", 8, -6)
    self.queueHeader:SetText("Queued Kills (0)")
    self.queueHeader:SetTextColor(0.7, 0.7, 0.85)

    local scroll = CreateFrame("ScrollFrame", nil, section, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 6, -22)
    scroll:SetPoint("BOTTOMRIGHT", -14, 6)    -- tighter right inset since the themed bar is thinner
    self.queueScroll = scroll

    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(1, 1)
    scroll:SetScrollChild(content)
    self.queueContent = content

    -- Set the caller's resize handler FIRST, then ApplyThemedScrollBar.
    -- ApplyThemedScrollBar uses HookScript("OnSizeChanged", ...) so it
    -- chains on top of this SetScript. Running them in the opposite
    -- order would make SetScript wipe the themed bar's resize sync.
    scroll:SetScript("OnSizeChanged", function(_sf, w)
        content:SetWidth(w)
    end)

    if ns.ApplyThemedScrollBar then
        ns.ApplyThemedScrollBar(scroll, {
            autoHide = true,
            showButtons = true,   -- chevron-up/chevron-down glyphs from Loolib Font Awesome
            thickness = 12,
        })
    end

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
    Themed dropdown option builders

    The themed dropdowns (ns.CreateThemedDropdown) expect a flat list of
    options where each entry is either:
      { header = "Tier Name" }                        -- group header
      { value = <unique>, label = "Display Text" }    -- selectable row
----------------------------------------------------------------------]]

function SimulatorPanelMixin:BuildRaidOptions()
    local out = {}
    local raids = getRaids()
    if #raids == 0 then
        out[#out + 1] = { value = nil, label = "(no raids — EJ not loaded)" }
        return out
    end
    local lastTier
    for _, r in ipairs(raids) do
        if r.tierIndex ~= lastTier then
            out[#out + 1] = { header = r.tierName or ("Tier " .. tostring(r.tierIndex)) }
            lastTier = r.tierIndex
        end
        local label = r.instanceName
        if r.isLatest then label = label .. "  |cff888888(latest)|r" end
        out[#out + 1] = { value = r.instanceID, label = label, raid = r }
    end
    return out
end

function SimulatorPanelMixin:OnRaidSelected(instanceID)
    if ns.Simulator and ns.Simulator.SelectRaid then
        ns.Simulator:SelectRaid(instanceID)
    end
    self.selectedBoss = nil  -- raid changed; clear boss
    if self.raidDropdown then self.raidDropdown:Refresh() end
    if self.bossDropdown then self.bossDropdown:Refresh() end
end

function SimulatorPanelMixin:BuildBossOptions()
    local out = { { value = "random", label = "Random" } }
    for _, b in ipairs(getBosses()) do
        out[#out + 1] = {
            value = tostring(b.id),
            label = string.format("%d. %s", b.order, b.name),
            boss = b,
        }
    end
    return out
end

function SimulatorPanelMixin:OnBossSelected(value)
    if value == "random" or value == nil then
        self.selectedBoss = nil
    else
        for _, b in ipairs(getBosses()) do
            if tostring(b.id) == value then self.selectedBoss = b break end
        end
    end
    if self.bossDropdown then self.bossDropdown:Refresh() end
end

function SimulatorPanelMixin:BuildLooterOptions()
    local out = {
        { value = "_random", label = "Random" },
        { value = "self", label = "Player (you)" },
    }
    for _, m in ipairs(getCouncil()) do
        out[#out + 1] = { value = m.name, label = m.shortName or m.name }
    end
    return out
end

function SimulatorPanelMixin:OnLooterSelected(value)
    if value == "_random" or value == nil then
        self.selectedLooter = nil
    else
        self.selectedLooter = value
    end
    if self.looterDropdown then self.looterDropdown:Refresh() end
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

-- Respect the same safety gates (real raid / active session / open
-- picker / encounter in progress) as the slash-command path. Using
-- `Enable(false)` means the user has to manually enable via
-- `/lt sim on force` if they want to bypass — the UI should not
-- silently disarm broadcast-to-live-raid protection.
function SimulatorPanelMixin:OnFireKill()
    if not ns.Simulator:IsActive() then
        if not ns.Simulator:Enable(false) then return end
    end
    ns.Simulator:FireKillForBoss(self:GetBossToken(), self.itemCount, self:GetLooterToken())
end

function SimulatorPanelMixin:OnQueueKill()
    if not ns.Simulator:IsActive() then
        if not ns.Simulator:Enable(false) then return end
    end
    ns.Simulator:QueueKill(self:GetBossToken(), self.itemCount, self:GetLooterToken())
end

function SimulatorPanelMixin:OnAddLoot()
    if not ns.Simulator:IsActive() then
        if not ns.Simulator:Enable(false) then return end
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
    ns.Simulator:RegisterCallback("OnSelectedRaidChanged", function() self:RefreshRaidDropdown() end, "SimulatorPanel")

    if Loothing.Session and Loothing.Session.RegisterCallback then
        Loothing.Session:RegisterCallback("OnSessionStarted", function() self:RefreshStatus() end, "SimulatorPanel")
        Loothing.Session:RegisterCallback("OnSessionEnded", function() self:RefreshStatus() end, "SimulatorPanel")
    end
end

function SimulatorPanelMixin:RefreshRaidDropdown()
    if self.raidDropdown then self.raidDropdown:Refresh() end
    if self.bossDropdown then self.bossDropdown:Refresh() end
end

function SimulatorPanelMixin:RefreshAll()
    self:RefreshStatus()
    self:RefreshQueue()
    self:RefreshAutofire(ns.Simulator and ns.Simulator:IsAutoFire())
    self:RefreshRaidDropdown()
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
    if self.frame._loothingFadeGroup then self.frame._loothingFadeGroup:Stop() end
    self.frame:Show()
    -- Pick up any theme/accent change that happened while the panel was closed.
    if type(self.ApplyTheme) == "function" then self:ApplyTheme() end
    self:RefreshAll()
    if AnimationPresets then
        self.frame._loothingFadeGroup = AnimationPresets.FadeIn(self.frame, 0.22, "outCubic")
    else
        self.frame:SetAlpha(1)
    end
end

function SimulatorPanelMixin:Hide()
    if not self.frame then return end
    if self.frame._loothingFadeGroup then self.frame._loothingFadeGroup:Stop() end
    if AnimationPresets and self.frame:IsVisible() then
        self.frame._loothingFadeGroup = AnimationPresets.FadeOut(self.frame, 0.13, "inCubic", true, function()
            if self.frame then self.frame:SetAlpha(0) end
        end)
    else
        self.frame:Hide()
    end
end

--- Re-apply accent glow and pixel border color on theme/accent change.
function SimulatorPanelMixin:ApplyTheme()
    if not self.frame then return end
    if self.headerStrip and ApplyAccentGlow then
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
