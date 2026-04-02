--[[--------------------------------------------------------------------
    Loothing - Loot Council Addon for WoW 12.0+
    DiagPanel - Live diagnostic GUI (updates every 1 second)
----------------------------------------------------------------------]]

local _, ns = ...
local Loolib = LibStub("Loolib")
local Loothing = ns.Addon
local SkinningMixin = ns.SkinningMixin
local Utils = ns.Utils

local CreateFrame = CreateFrame
local CreateFromMixins = Loolib.CreateFromMixins
local IsInGroup = IsInGroup
local IsInRaid = IsInRaid
local GetNumGroupMembers = GetNumGroupMembers
local tostring = tostring
local format = string.format
local unpack = unpack
local pairs = pairs
local ipairs = ipairs
local tconcat = table.concat
local tinsert = table.insert

--[[--------------------------------------------------------------------
    Constants
----------------------------------------------------------------------]]

local PANEL_WIDTH = 360
local PANEL_HEIGHT = 560
local PADDING = 12
local LINE_HEIGHT = 15
local SECTION_GAP = 6
local LABEL_WIDTH = 140
local MAX_ITEM_SLOTS = 10

local COLOR_GOLD   = { 1, 0.82, 0 }
local COLOR_LABEL  = { 0.55, 0.55, 0.55 }
local COLOR_VALUE  = { 0.9, 0.9, 0.9 }
local COLOR_OK     = { 0.3, 1, 0.3 }
local COLOR_WARN   = { 1, 0.6, 0.1 }
local COLOR_BAD    = { 1, 0.25, 0.25 }
local COLOR_DIM    = { 0.4, 0.4, 0.4 }
local COLOR_SEP    = { 0.25, 0.25, 0.25, 0.8 }
local COLOR_CYAN   = { 0.4, 0.8, 1 }

local SESSION_STATE_NAMES = {
    [1] = "INACTIVE",
    [2] = "ACTIVE",
    [3] = "CLOSED",
}

local ITEM_STATE_NAMES = {
    [1] = "PENDING",
    [2] = "VOTING",
    [3] = "TALLIED",
    [4] = "AWARDED",
    [5] = "SKIPPED",
}

local ITEM_STATE_COLORS = {
    [1] = COLOR_DIM,
    [2] = COLOR_OK,
    [3] = COLOR_WARN,
    [4] = COLOR_CYAN,
    [5] = COLOR_DIM,
}

local REFRESH_INTERVAL = 1.0

--[[--------------------------------------------------------------------
    DiagPanelMixin
----------------------------------------------------------------------]]

local DiagPanelMixin = {}
ns.DiagPanelMixin = DiagPanelMixin

function DiagPanelMixin:Init()
    self.values = {}
    self.itemSlots = {}
    self.ticker = nil
    self:BuildFrame()
    self:BuildCopyDialog()
    self:BuildContent()
end

--[[--------------------------------------------------------------------
    Frame Construction
----------------------------------------------------------------------]]

function DiagPanelMixin:BuildFrame()
    local frame = CreateFrame("Frame", "LoothingDiagPanel", UIParent, "BackdropTemplate")
    frame:SetSize(PANEL_WIDTH, PANEL_HEIGHT)
    frame:SetPoint("CENTER", UIParent, "CENTER", 300, 0)
    frame:SetFrameStrata("HIGH")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:SetClampedToScreen(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", function(f)
        f:StopMovingOrSizing()
        SkinningMixin:SaveFrameState(f, "DiagPanel")
    end)
    frame:Hide()

    SkinningMixin:SetupFrame(frame, "DiagPanel", "LoothingDiagPanel", {
        combatMinimize = false,
        ctrlScroll = true,
        escapeClose = true,
    })

    self.frame = frame

    -- Title
    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", 0, -PADDING)
    title:SetText("Loothing Diagnostics")
    title:SetTextColor(unpack(COLOR_GOLD))

    -- Close button
    local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -2, -2)
    close:SetScript("OnClick", function()
        self:Hide()
    end)

    -- Copy button
    local panel = self
    local copyBtn = CreateFrame("Button", nil, frame, "BackdropTemplate")
    copyBtn:SetSize(50, 20)
    copyBtn:SetPoint("TOPRIGHT", close, "TOPLEFT", -2, -4)
    copyBtn:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    copyBtn:SetBackdropColor(0.15, 0.15, 0.15, 0.9)
    copyBtn:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)

    local copyLabel = copyBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    copyLabel:SetPoint("CENTER")
    copyLabel:SetText("Copy")
    copyLabel:SetTextColor(0.8, 0.8, 0.8)

    copyBtn:SetScript("OnClick", function()
        panel:ShowCopyDialog()
    end)
    copyBtn:SetScript("OnEnter", function(btn)
        btn:SetBackdropColor(0.25, 0.25, 0.25, 1)
        copyLabel:SetTextColor(1, 1, 1)
    end)
    copyBtn:SetScript("OnLeave", function(btn)
        btn:SetBackdropColor(0.15, 0.15, 0.15, 0.9)
        copyLabel:SetTextColor(0.8, 0.8, 0.8)
    end)

    -- ScrollFrame for content
    local scrollFrame = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", PADDING, -36)
    scrollFrame:SetPoint("BOTTOMRIGHT", -PADDING - 22, PADDING)
    self.scrollFrame = scrollFrame

    local scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetWidth(PANEL_WIDTH - PADDING * 2 - 22)
    scrollFrame:SetScrollChild(scrollChild)
    self.scrollChild = scrollChild

    -- Show/Hide hooks
    frame:SetScript("OnShow", function()
        panel:Refresh()
        panel:StartTicker()
    end)
    frame:SetScript("OnHide", function()
        panel:StopTicker()
    end)
end

--[[--------------------------------------------------------------------
    Copy Dialog
----------------------------------------------------------------------]]

function DiagPanelMixin:BuildCopyDialog()
    local dialog = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    dialog:SetSize(520, 420)
    dialog:SetPoint("CENTER")
    dialog:SetFrameStrata("DIALOG")
    dialog:SetMovable(true)
    dialog:EnableMouse(true)
    dialog:SetClampedToScreen(true)
    dialog:RegisterForDrag("LeftButton")
    dialog:SetScript("OnDragStart", dialog.StartMoving)
    dialog:SetScript("OnDragStop", dialog.StopMovingOrSizing)
    dialog:Hide()

    SkinningMixin:ApplySkin(dialog)

    local title = dialog:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOP", 0, -10)
    title:SetText("Press Ctrl+C to copy")
    title:SetTextColor(unpack(COLOR_GOLD))

    local close = CreateFrame("Button", nil, dialog, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -2, -2)

    local scrollFrame = CreateFrame("ScrollFrame", nil, dialog, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 12, -30)
    scrollFrame:SetPoint("BOTTOMRIGHT", -32, 12)

    local editBox = CreateFrame("EditBox", nil, scrollFrame)
    editBox:SetMultiLine(true)
    editBox:SetFontObject(GameFontHighlightSmall)
    editBox:SetAutoFocus(true)
    editBox:SetScript("OnEscapePressed", function() dialog:Hide() end)

    -- Size the editbox to the scroll width after layout
    scrollFrame:SetScript("OnSizeChanged", function(sf, w)
        editBox:SetWidth(w)
    end)

    scrollFrame:SetScrollChild(editBox)

    self.copyDialog = dialog
    self.copyEditBox = editBox
end

function DiagPanelMixin:ShowCopyDialog()
    local text = self:BuildClipboardText()
    self.copyEditBox:SetText(text)
    self.copyDialog:Show()

    -- Select all text after a frame so the editbox has sized
    C_Timer.After(0, function()
        self.copyEditBox:SetFocus()
        self.copyEditBox:HighlightText()
    end)
end

--[[--------------------------------------------------------------------
    Content Layout
----------------------------------------------------------------------]]

function DiagPanelMixin:BuildContent()
    self.content = self.scrollChild
    self.yOffset = 0

    -- Addon
    self:AddHeader("Addon")
    self.values.version       = self:AddRow("Version:")
    self.values.protocol      = self:AddRow("Protocol:")

    -- Player
    self:AddHeader("Player")
    self.values.player        = self:AddRow("Player:")
    self.values.handleLoot    = self:AddRow("Handle Loot:")
    self.values.isML          = self:AddRow("Is Master Looter:")
    self.values.mlGlobal      = self:AddRow("ML (global):")
    self.values.mlSession     = self:AddRow("ML (session):")
    self.values.mlSettings    = self:AddRow("ML (settings):")

    -- Session
    self:AddHeader("Session")
    self.values.sessionState  = self:AddRow("State:")
    self.values.sessionID     = self:AddRow("Session ID:")
    self.values.encounter     = self:AddRow("Encounter:")
    self.values.itemCounts    = self:AddRow("Items:")

    -- Communication
    self:AddHeader("Communication")
    self.values.commState     = self:AddRow("Comm State:")
    self.values.queueDepth    = self:AddRow("Queue Depth:")
    self.values.queuePressure = self:AddRow("Queue Pressure:")
    self.values.prefixReg     = self:AddRow("Prefix Registered:")
    self.values.restricted    = self:AddRow("Enc. Restricted:")
    self.values.encodeTest    = self:AddRow("Encode/Decode:")

    -- Group
    self:AddHeader("Group")
    self.values.inGroup       = self:AddRow("In Group:")
    self.values.inRaid        = self:AddRow("In Raid:")
    self.values.groupSize     = self:AddRow("Group Size:")

    -- Health
    self:AddHeader("Health")
    self.values.tempPool      = self:AddRow("TempTable Pool:")
    self.values.tempActive    = self:AddRow("TempTable Active:")
    self.values.tempLeaks     = self:AddRow("TempTable Leaks:")
    self.values.errorCount    = self:AddRow("Captured Errors:")
    self.values.blockedCount  = self:AddRow("Blocked Actions:")

    -- Session Items (dynamic, at bottom)
    self.yOffset = self.yOffset - SECTION_GAP

    self.sessionItemsHeader = self.content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    self.sessionItemsHeader:SetPoint("TOPLEFT", 0, self.yOffset)
    self.sessionItemsHeader:SetPoint("RIGHT", self.content, "RIGHT")
    self.sessionItemsHeader:SetText("Session Items")
    self.sessionItemsHeader:SetTextColor(unpack(COLOR_GOLD))
    self.sessionItemsHeader:SetJustifyH("LEFT")
    self.sessionItemsHeader:Hide()
    self.yOffset = self.yOffset - LINE_HEIGHT - 1

    self.sessionItemsSep = self.content:CreateTexture(nil, "ARTWORK")
    self.sessionItemsSep:SetPoint("TOPLEFT", 0, self.yOffset + 1)
    self.sessionItemsSep:SetPoint("RIGHT", self.content, "RIGHT")
    self.sessionItemsSep:SetHeight(1)
    self.sessionItemsSep:SetColorTexture(unpack(COLOR_SEP))
    self.sessionItemsSep:Hide()
    self.yOffset = self.yOffset - 3

    -- Store the Y position where session items begin
    self.sessionItemsStartY = self.yOffset

    -- Pre-create item display slots (3 lines each: name, detail, responses)
    for i = 1, MAX_ITEM_SLOTS do
        local slot = {}

        slot.nameFS = self.content:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        slot.nameFS:SetPoint("TOPLEFT", 4, 0) -- positioned dynamically
        slot.nameFS:SetPoint("RIGHT", self.content, "RIGHT")
        slot.nameFS:SetJustifyH("LEFT")
        slot.nameFS:Hide()

        slot.detailFS = self.content:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        slot.detailFS:SetPoint("TOPLEFT", 12, 0) -- positioned dynamically
        slot.detailFS:SetPoint("RIGHT", self.content, "RIGHT")
        slot.detailFS:SetJustifyH("LEFT")
        slot.detailFS:Hide()

        slot.respFS = self.content:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        slot.respFS:SetPoint("TOPLEFT", 12, 0) -- positioned dynamically
        slot.respFS:SetPoint("RIGHT", self.content, "RIGHT")
        slot.respFS:SetJustifyH("LEFT")
        slot.respFS:Hide()

        self.itemSlots[i] = slot
    end

    -- Set initial scroll child height
    self.staticContentHeight = -self.yOffset
    self.scrollChild:SetHeight(self.staticContentHeight)
end

function DiagPanelMixin:AddHeader(text)
    if self.yOffset ~= 0 then
        self.yOffset = self.yOffset - SECTION_GAP
    end

    local fs = self.content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    fs:SetPoint("TOPLEFT", 0, self.yOffset)
    fs:SetPoint("RIGHT", self.content, "RIGHT")
    fs:SetText(text)
    fs:SetTextColor(unpack(COLOR_GOLD))
    fs:SetJustifyH("LEFT")
    self.yOffset = self.yOffset - LINE_HEIGHT - 1

    local sep = self.content:CreateTexture(nil, "ARTWORK")
    sep:SetPoint("TOPLEFT", 0, self.yOffset + 1)
    sep:SetPoint("RIGHT", self.content, "RIGHT")
    sep:SetHeight(1)
    sep:SetColorTexture(unpack(COLOR_SEP))
    self.yOffset = self.yOffset - 3
end

function DiagPanelMixin:AddRow(label)
    local labelFS = self.content:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    labelFS:SetPoint("TOPLEFT", 4, self.yOffset)
    labelFS:SetWidth(LABEL_WIDTH)
    labelFS:SetText(label)
    labelFS:SetTextColor(unpack(COLOR_LABEL))
    labelFS:SetJustifyH("LEFT")

    local valueFS = self.content:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    valueFS:SetPoint("LEFT", labelFS, "RIGHT", 4, 0)
    valueFS:SetPoint("RIGHT", self.content, "RIGHT")
    valueFS:SetText("--")
    valueFS:SetTextColor(unpack(COLOR_VALUE))
    valueFS:SetJustifyH("LEFT")

    self.yOffset = self.yOffset - LINE_HEIGHT
    return valueFS
end

--[[--------------------------------------------------------------------
    Value Helpers
----------------------------------------------------------------------]]

local function SetBool(fs, value)
    if value then
        fs:SetText("Yes")
        fs:SetTextColor(unpack(COLOR_OK))
    else
        fs:SetText("No")
        fs:SetTextColor(unpack(COLOR_DIM))
    end
end

local function SetText(fs, text, color)
    fs:SetText(text or "--")
    fs:SetTextColor(unpack(color or COLOR_VALUE))
end

local function GetResponseName(responseID)
    local info = Loothing.ResponseInfo and Loothing.ResponseInfo[responseID]
    if info then return info.name end
    local sysInfo = Loothing.SystemResponseInfo and Loothing.SystemResponseInfo[responseID]
    if sysInfo then return sysInfo.name end
    return tostring(responseID)
end

--[[--------------------------------------------------------------------
    Refresh (called every 1 second)
----------------------------------------------------------------------]]

function DiagPanelMixin:Refresh()
    local v = self.values

    -- Addon
    SetText(v.version, Loothing.VERSION)
    SetText(v.protocol, tostring(Loothing.PROTOCOL_VERSION))

    -- Player
    local playerName = Utils and Utils.GetPlayerFullName and Utils.GetPlayerFullName() or nil
    SetText(v.player, playerName or "<unknown>")
    SetBool(v.handleLoot, Loothing.handleLoot)
    SetBool(v.isML, Loothing.isMasterLooter)
    SetText(v.mlGlobal, tostring(Loothing.masterLooter or "none"), Loothing.masterLooter and COLOR_VALUE or COLOR_DIM)

    local sessionML = Loothing.Session and Loothing.Session:GetMasterLooter() or nil
    SetText(v.mlSession, tostring(sessionML or "none"), sessionML and COLOR_VALUE or COLOR_DIM)

    local settingsML = Loothing.Settings and Loothing.Settings.GetMasterLooter and Loothing.Settings:GetMasterLooter() or nil
    SetText(v.mlSettings, tostring(settingsML or "none"), settingsML and COLOR_VALUE or COLOR_DIM)

    -- Session
    local session = Loothing.Session
    local sessionState = session and session:GetState() or nil
    local stateName = sessionState and SESSION_STATE_NAMES[sessionState] or "N/A"
    local stateColor = COLOR_DIM
    if sessionState == 2 then
        stateColor = COLOR_OK
    elseif sessionState == 3 then
        stateColor = COLOR_WARN
    end
    SetText(v.sessionState, stateName, stateColor)

    local sessionID = session and session:GetSessionID() or nil
    SetText(v.sessionID, sessionID and tostring(sessionID) or "none", sessionID and COLOR_VALUE or COLOR_DIM)

    local encounterName = session and session.GetEncounterName and session:GetEncounterName() or nil
    SetText(v.encounter, encounterName or "none", encounterName and COLOR_VALUE or COLOR_DIM)

    -- Item count summary
    local hasSession = session and session.IsActive and session:IsActive()
    if hasSession or (sessionState and sessionState ~= 1) then
        local itemCount = session:GetItemCount()
        local counts = { 0, 0, 0, 0, 0 } -- pending, voting, tallied, awarded, skipped
        for _, item in session:GetItems():Enumerate() do
            local s = item.state
            if s and counts[s] then
                counts[s] = counts[s] + 1
            end
        end
        local parts = {}
        if counts[1] > 0 then tinsert(parts, counts[1] .. "P") end
        if counts[2] > 0 then tinsert(parts, counts[2] .. "V") end
        if counts[3] > 0 then tinsert(parts, counts[3] .. "T") end
        if counts[4] > 0 then tinsert(parts, counts[4] .. "A") end
        if counts[5] > 0 then tinsert(parts, counts[5] .. "S") end
        local detail = #parts > 0 and (" (" .. tconcat(parts, " ") .. ")") or ""
        SetText(v.itemCounts, tostring(itemCount) .. detail)
    else
        SetText(v.itemCounts, "0", COLOR_DIM)
    end

    -- Communication
    local Comm = Loolib.Comm
    local CommState = Loothing.CommState

    if CommState and CommState.GetStateName then
        local csName = CommState:GetStateName()
        local csColor = COLOR_OK
        if csName == "RESTRICTED" then
            csColor = COLOR_WARN
        elseif csName == "DISCONNECTED" then
            csColor = COLOR_BAD
        end
        SetText(v.commState, csName, csColor)
    else
        SetText(v.commState, "N/A", COLOR_DIM)
    end

    local queued = Comm and Comm.GetQueuedMessageCount and Comm:GetQueuedMessageCount() or nil
    SetText(v.queueDepth, queued and tostring(queued) or "?")

    local pressure = Comm and Comm.GetQueuePressure and Comm:GetQueuePressure() or nil
    if pressure then
        local pct = format("%.0f%%", pressure * 100)
        local pColor = COLOR_OK
        if pressure > 0.7 then
            pColor = COLOR_BAD
        elseif pressure > 0.4 then
            pColor = COLOR_WARN
        end
        SetText(v.queuePressure, pct, pColor)
    else
        SetText(v.queuePressure, "?", COLOR_DIM)
    end

    local isRegistered = Comm and Comm.IsCommRegistered and Comm:IsCommRegistered(Loothing.ADDON_PREFIX) or nil
    if isRegistered ~= nil then
        SetBool(v.prefixReg, isRegistered)
    else
        SetText(v.prefixReg, "?", COLOR_DIM)
    end

    local restricted = Loothing.Restrictions and Loothing.Restrictions.IsRestricted and Loothing.Restrictions:IsRestricted() or false
    if restricted then
        SetText(v.restricted, "Yes", COLOR_WARN)
    else
        SetText(v.restricted, "No", COLOR_OK)
    end

    -- Encode/decode test
    local testOK = false
    local testCmd = Loothing.MsgType and Loothing.MsgType.HEARTBEAT or "HEARTBEAT"
    if ns.Protocol then
        local encoded = ns.Protocol:Encode(testCmd, { test = true })
        if encoded then
            local pv, cmd = ns.Protocol:Decode(encoded)
            testOK = (pv == Loothing.PROTOCOL_VERSION and cmd == testCmd)
        end
    end
    if testOK then
        SetText(v.encodeTest, "OK", COLOR_OK)
    else
        SetText(v.encodeTest, "FAILED", COLOR_BAD)
    end

    -- Group
    SetBool(v.inGroup, IsInGroup())
    SetBool(v.inRaid, IsInRaid())
    local groupSize = GetNumGroupMembers()
    SetText(v.groupSize, tostring(groupSize), groupSize > 0 and COLOR_VALUE or COLOR_DIM)

    -- Health
    local TempTable = Loolib.TempTable
    if TempTable and TempTable.GetStats then
        local pooled, outstanding, maxPool = TempTable:GetStats()
        SetText(v.tempPool, format("%d / %d", pooled, maxPool))
        SetText(v.tempActive, tostring(outstanding), outstanding > 0 and COLOR_WARN or COLOR_OK)

        local leaks = TempTable:GetLeaks()
        local leakCount = 0
        for _ in pairs(leaks) do leakCount = leakCount + 1 end
        SetText(v.tempLeaks, tostring(leakCount), leakCount > 0 and COLOR_BAD or COLOR_OK)
    else
        SetText(v.tempPool, "N/A", COLOR_DIM)
        SetText(v.tempActive, "N/A", COLOR_DIM)
        SetText(v.tempLeaks, "N/A", COLOR_DIM)
    end

    local ErrorHandler = Loothing.ErrorHandler
    if ErrorHandler and ErrorHandler.GetErrorCount then
        local errCount = ErrorHandler:GetErrorCount()
        SetText(v.errorCount, tostring(errCount), errCount > 0 and COLOR_WARN or COLOR_OK)
    else
        SetText(v.errorCount, "N/A", COLOR_DIM)
    end

    local Diagnostics = Loothing.Diagnostics
    if Diagnostics then
        local blocked = Diagnostics.blockedActions and #Diagnostics.blockedActions or 0
        SetText(v.blockedCount, tostring(blocked), blocked > 0 and COLOR_BAD or COLOR_OK)
    else
        SetText(v.blockedCount, "N/A", COLOR_DIM)
    end

    -- Session items
    self:RefreshSessionItems()
end

--[[--------------------------------------------------------------------
    Session Items (dynamic section)
----------------------------------------------------------------------]]

function DiagPanelMixin:RefreshSessionItems()
    local session = Loothing.Session
    local sessionState = session and session:GetState() or nil
    local hasItems = sessionState and sessionState ~= 1 and session:GetItemCount() > 0

    if not hasItems then
        -- Hide entire section
        self.sessionItemsHeader:Hide()
        self.sessionItemsSep:Hide()
        for i = 1, MAX_ITEM_SLOTS do
            self.itemSlots[i].nameFS:Hide()
            self.itemSlots[i].detailFS:Hide()
            self.itemSlots[i].respFS:Hide()
        end
        self.scrollChild:SetHeight(self.staticContentHeight)
        return
    end

    self.sessionItemsHeader:Show()
    self.sessionItemsSep:Show()

    local y = self.sessionItemsStartY
    local slotIndex = 0

    for _, item in session:GetItems():Enumerate() do
        slotIndex = slotIndex + 1
        if slotIndex > MAX_ITEM_SLOTS then break end

        local slot = self.itemSlots[slotIndex]

        -- Gap between items
        if slotIndex > 1 then
            y = y - 4
        end

        -- Line 1: item name + state + ilvl
        local stateID = item.state or 0
        local stateName = ITEM_STATE_NAMES[stateID] or "?"
        local stateColor = ITEM_STATE_COLORS[stateID] or COLOR_DIM
        local ilvlStr = item.itemLevel and ("  ilvl " .. item.itemLevel) or ""
        local nameText = format("%s [%s]%s", item.name or "?", stateName, ilvlStr)

        slot.nameFS:ClearAllPoints()
        slot.nameFS:SetPoint("TOPLEFT", self.content, "TOPLEFT", 4, y)
        slot.nameFS:SetPoint("RIGHT", self.content, "RIGHT")
        slot.nameFS:SetText(nameText)
        slot.nameFS:SetTextColor(unpack(stateColor))
        slot.nameFS:Show()
        y = y - LINE_HEIGHT

        -- Line 2: candidates + winner or count
        local detailText
        local cm = item.candidateManager
        if item.winner then
            local winResp = item.winnerResponse and GetResponseName(item.winnerResponse) or "?"
            detailText = format("Winner: %s (%s)", item.winner, winResp)
        elseif cm then
            local candCount = cm:GetCandidateCount()
            local respCounts = cm:GetResponseCounts()
            local responded = 0
            for _, count in pairs(respCounts) do
                responded = responded + count
            end
            detailText = format("%d candidates, %d responded", candCount, responded)
        else
            detailText = "No candidate data"
        end

        slot.detailFS:ClearAllPoints()
        slot.detailFS:SetPoint("TOPLEFT", self.content, "TOPLEFT", 12, y)
        slot.detailFS:SetPoint("RIGHT", self.content, "RIGHT")
        slot.detailFS:SetText(detailText)
        slot.detailFS:SetTextColor(unpack(COLOR_LABEL))
        slot.detailFS:Show()
        y = y - LINE_HEIGHT

        -- Line 3: response breakdown (separate line)
        local respText = ""
        if cm and not item.winner then
            local respCounts = cm:GetResponseCounts()
            local respParts = {}
            for resp, count in pairs(respCounts) do
                tinsert(respParts, GetResponseName(resp) .. ":" .. count)
            end
            if #respParts > 0 then
                respText = tconcat(respParts, "  ")
            end
        end

        if respText ~= "" then
            slot.respFS:ClearAllPoints()
            slot.respFS:SetPoint("TOPLEFT", self.content, "TOPLEFT", 12, y)
            slot.respFS:SetPoint("RIGHT", self.content, "RIGHT")
            slot.respFS:SetText(respText)
            slot.respFS:SetTextColor(unpack(COLOR_DIM))
            slot.respFS:Show()
            y = y - LINE_HEIGHT
        else
            slot.respFS:Hide()
        end
    end

    -- Hide unused slots
    for i = slotIndex + 1, MAX_ITEM_SLOTS do
        self.itemSlots[i].nameFS:Hide()
        self.itemSlots[i].detailFS:Hide()
        self.itemSlots[i].respFS:Hide()
    end

    -- Update scroll child height
    local totalHeight = self.staticContentHeight + (-y - self.sessionItemsStartY)
    self.scrollChild:SetHeight(totalHeight)
end

--[[--------------------------------------------------------------------
    Clipboard Text Builder
----------------------------------------------------------------------]]

function DiagPanelMixin:BuildClipboardText()
    local lines = {}
    local function L(text) tinsert(lines, text) end
    local function Sep() L("---") end

    L("=== Loothing Diagnostics ===")
    L(format("Timestamp: %s", date("%Y-%m-%d %H:%M:%S")))
    L("")

    -- Addon
    L("[Addon]")
    L(format("  Version: %s", Loothing.VERSION or "?"))
    L(format("  Protocol: %s", tostring(Loothing.PROTOCOL_VERSION)))
    Sep()

    -- Player
    L("[Player]")
    local playerName = Utils and Utils.GetPlayerFullName and Utils.GetPlayerFullName() or "?"
    L(format("  Player: %s", playerName))
    L(format("  Handle Loot: %s", tostring(Loothing.handleLoot)))
    L(format("  Is Master Looter: %s", tostring(Loothing.isMasterLooter)))
    L(format("  ML (global): %s", tostring(Loothing.masterLooter or "none")))
    local sessionML = Loothing.Session and Loothing.Session:GetMasterLooter() or "none"
    L(format("  ML (session): %s", tostring(sessionML)))
    local settingsML = Loothing.Settings and Loothing.Settings.GetMasterLooter and Loothing.Settings:GetMasterLooter() or "none"
    L(format("  ML (settings): %s", tostring(settingsML)))
    Sep()

    -- Session
    L("[Session]")
    local session = Loothing.Session
    local sessionState = session and session:GetState() or nil
    L(format("  State: %s", sessionState and SESSION_STATE_NAMES[sessionState] or "N/A"))
    L(format("  Session ID: %s", session and session:GetSessionID() or "none"))
    local encName = session and session.GetEncounterName and session:GetEncounterName() or "none"
    local encID = session and session.GetEncounterID and session:GetEncounterID() or "none"
    L(format("  Encounter: %s (ID: %s)", tostring(encName), tostring(encID)))
    if session and sessionState and sessionState ~= 1 then
        L(format("  Item Count: %d", session:GetItemCount()))
    end
    Sep()

    -- Communication
    L("[Communication]")
    local CommState = Loothing.CommState
    L(format("  Comm State: %s", CommState and CommState.GetStateName and CommState:GetStateName() or "N/A"))
    local Comm = Loolib.Comm
    local queued = Comm and Comm.GetQueuedMessageCount and Comm:GetQueuedMessageCount() or "?"
    L(format("  Queue Depth: %s", tostring(queued)))
    local pressure = Comm and Comm.GetQueuePressure and Comm:GetQueuePressure() or "?"
    L(format("  Queue Pressure: %s", type(pressure) == "number" and format("%.1f%%", pressure * 100) or "?"))
    local isRegistered = Comm and Comm.IsCommRegistered and Comm:IsCommRegistered(Loothing.ADDON_PREFIX) or "?"
    L(format("  Prefix Registered: %s", tostring(isRegistered)))
    local restricted = Loothing.Restrictions and Loothing.Restrictions.IsRestricted and Loothing.Restrictions:IsRestricted() or false
    L(format("  Enc. Restricted: %s", tostring(restricted)))

    local testOK = false
    local testCmd = Loothing.MsgType and Loothing.MsgType.HEARTBEAT or "HEARTBEAT"
    if ns.Protocol then
        local encoded = ns.Protocol:Encode(testCmd, { test = true })
        if encoded then
            local pv, cmd = ns.Protocol:Decode(encoded)
            testOK = (pv == Loothing.PROTOCOL_VERSION and cmd == testCmd)
        end
    end
    L(format("  Encode/Decode: %s", testOK and "OK" or "FAILED"))
    Sep()

    -- Group
    L("[Group]")
    L(format("  In Group: %s", tostring(IsInGroup())))
    L(format("  In Raid: %s", tostring(IsInRaid())))
    L(format("  Group Size: %d", GetNumGroupMembers()))
    Sep()

    -- Health
    L("[Health]")
    local TempTable = Loolib.TempTable
    if TempTable and TempTable.GetStats then
        local pooled, outstanding, maxPool = TempTable:GetStats()
        L(format("  TempTable Pool: %d / %d", pooled, maxPool))
        L(format("  TempTable Active: %d", outstanding))
        local leaks = TempTable:GetLeaks()
        local leakCount = 0
        for _ in pairs(leaks) do leakCount = leakCount + 1 end
        L(format("  TempTable Leaks: %d", leakCount))
    else
        L("  TempTable: N/A")
    end

    local ErrorHandler = Loothing.ErrorHandler
    if ErrorHandler and ErrorHandler.GetErrorCount then
        L(format("  Captured Errors: %d", ErrorHandler:GetErrorCount()))
    end
    local Diagnostics = Loothing.Diagnostics
    if Diagnostics and Diagnostics.blockedActions then
        L(format("  Blocked Actions: %d", #Diagnostics.blockedActions))
    end
    Sep()

    -- Session Items (detailed)
    if session and sessionState and sessionState ~= 1 and session:GetItemCount() > 0 then
        L("[Session Items]")
        local itemIndex = 0
        for _, item in session:GetItems():Enumerate() do
            itemIndex = itemIndex + 1
            local stateID = item.state or 0
            local stateName = ITEM_STATE_NAMES[stateID] or "?"
            local ilvlStr = item.itemLevel and (" ilvl " .. item.itemLevel) or ""
            L(format("  #%d: %s [%s]%s", itemIndex, item.name or "?", stateName, ilvlStr))
            L(format("      GUID: %s", item.guid or "?"))
            L(format("      Looter: %s", item.looter or "?"))

            if item.winner then
                local winResp = item.winnerResponse and GetResponseName(item.winnerResponse) or "?"
                L(format("      Winner: %s (%s)", item.winner, winResp))
            end

            local cm = item.candidateManager
            if cm then
                local candCount = cm:GetCandidateCount()
                local respCounts = cm:GetResponseCounts()
                local respParts = {}
                local responded = 0
                for resp, count in pairs(respCounts) do
                    responded = responded + count
                    tinsert(respParts, GetResponseName(resp) .. ":" .. count)
                end
                L(format("      Candidates: %d | Responded: %d", candCount, responded))
                if #respParts > 0 then
                    L(format("      Responses: %s", tconcat(respParts, ", ")))
                end

                -- List each candidate
                local allCandidates = cm:GetAllCandidates()
                if allCandidates then
                    for _, cand in ipairs(allCandidates) do
                        local resp = cand.response
                        local respName = resp and GetResponseName(resp) or "waiting"
                        local roll = cand.roll and (" roll:" .. cand.roll) or ""
                        local ilvlDiff = cand.ilvlDiff and cand.ilvlDiff ~= 0
                            and format(" (%+d ilvl)", cand.ilvlDiff) or ""
                        L(format("        - %s: %s%s%s",
                            cand.playerName or "?", respName, roll, ilvlDiff))
                    end
                end
            end
        end
        Sep()
    end

    L("=== End Diagnostics ===")
    return tconcat(lines, "\n")
end

--[[--------------------------------------------------------------------
    Ticker Management
----------------------------------------------------------------------]]

function DiagPanelMixin:StartTicker()
    if self.ticker then return end
    self.ticker = C_Timer.NewTicker(REFRESH_INTERVAL, function()
        if self.frame:IsShown() then
            self:Refresh()
        end
    end)
end

function DiagPanelMixin:StopTicker()
    if self.ticker then
        self.ticker:Cancel()
        self.ticker = nil
    end
end

--[[--------------------------------------------------------------------
    Show / Hide / Toggle
----------------------------------------------------------------------]]

function DiagPanelMixin:Show()
    self.frame:Show()
end

function DiagPanelMixin:Hide()
    self.frame:Hide()
end

function DiagPanelMixin:Toggle()
    if self.frame:IsShown() then
        self:Hide()
    else
        self:Show()
    end
end

function DiagPanelMixin:IsShown()
    return self.frame:IsShown()
end

--[[--------------------------------------------------------------------
    Factory
----------------------------------------------------------------------]]

local function CreateDiagPanel()
    local panel = CreateFromMixins(DiagPanelMixin)
    panel:Init()
    return panel
end

ns.CreateDiagPanel = CreateDiagPanel
