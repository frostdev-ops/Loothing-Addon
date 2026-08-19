--[[--------------------------------------------------------------------
    Loothing - LootPickerFrame

    Floating themed dialog the Master Looter sees when an encounter ends
    in "prompt" trigger mode. Replaces the legacy yes/no
    LOOTHING_CONFIRM_START_SESSION popup.

    Each row corresponds to one entry in Session.lootBuffer:
      * Allowed items default to checked.
      * Items the configured filter would have rejected are hidden by
        default; flipping "Show blocked" reveals them with a red hint
        chip so the ML can opt in on a per-kill basis.

    On Start: calls Session:StartSessionWithPickedItems(encID, encName,
    pickedItems). That method uses force=true on AddItem so manual
    overrides bypass the class/quality gates (the ML chose them).

    On Cancel: wipes the buffer, no session starts.
----------------------------------------------------------------------]]

local _, ns = ...
local Loolib = LibStub("Loolib")
local Loothing = ns.Addon

local AnimationUtil = Loolib.AnimationUtil
local AnimationPresets = Loolib.AnimationPresets
local PixelUtil = Loolib.PixelUtil

local ApplyAccentGlow = ns.FramePolish.ApplyAccentGlow
local AttachIconButtonPolish = ns.FramePolish.AttachIconButtonPolish

local PANEL_WIDTH = 560
local PANEL_HEIGHT = 560
local ROW_HEIGHT_DEFAULT = 50
local ROW_HEIGHT_BLOCKED = 64       -- taller for blocked rows so reason has its own line
local ROW_SPACING = 6
local ICON_SIZE = 36

local LootPickerFrameMixin = ns.LootPickerFrameMixin or {}
ns.LootPickerFrameMixin = LootPickerFrameMixin

local function GetSkinning()
    return ns.SkinningMixin
end

local function GetLocale()
    return ns.Locale or Loothing.Locale or {}
end

local function L(key, fallback)
    local locale = GetLocale()
    return (locale and locale[key]) or fallback or key
end

local function styleSurface(frame, variant)
    local sk = GetSkinning()
    if sk and sk.StyleSurface then
        sk:StyleSurface(frame, variant)
    else
        frame:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Buttons\\WHITE8x8",
            tile = false, edgeSize = 1,
            insets = { left = 1, right = 1, top = 1, bottom = 1 },
        })
        frame:SetBackdropColor(0.08, 0.08, 0.08, 0.95)
        frame:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)
    end
end

local function styleButton(button, variant)
    local sk = GetSkinning()
    if sk and sk.StylePlainButton then
        sk:StylePlainButton(button, variant)
    end
end

local function getColor(key, fallback)
    local sk = GetSkinning()
    if sk and sk.GetColor then
        return sk:GetColor(key, fallback)
    end
    return fallback or { 1, 1, 1, 1 }
end

local function applyTextColor(fontString, key, fallback)
    if not fontString then return end
    local c = getColor(key, fallback)
    if c then fontString:SetTextColor(c[1], c[2], c[3], c[4] or 1) end
end

local function qualityColor(quality)
    if ITEM_QUALITY_COLORS and quality and ITEM_QUALITY_COLORS[quality] then
        local c = ITEM_QUALITY_COLORS[quality]
        return c.r, c.g, c.b
    end
    return 0.5, 0.5, 0.5
end

--[[--------------------------------------------------------------------
    Lifecycle
----------------------------------------------------------------------]]

function LootPickerFrameMixin:Init()
    if self._built then return end
    self._built = true

    self.encounterID = 0
    self.encounterName = ""
    self.entries = {}            -- normalized buffer entries with eval results
    self.rows = {}
    self.showBlocked = false
    self._starting = false       -- guards OnStart against double-clicks
    self._suppressEvent = false  -- short-circuits self-fired callbacks

    self:BuildFrame()
    self:RegisterSessionCallback()
end

function LootPickerFrameMixin:RegisterSessionCallback()
    if self._callbackHooked then return end
    if not Loothing.Session or not Loothing.Session.RegisterCallback then return end
    -- Loolib CallbackRegistry's Function-type dispatch passes (owner, ...args)
    -- to subscribers registered without extra args — so the first param IS
    -- our `self`, NOT the buffer. Verified against Loolib/Events/CallbackRegistry.lua:325.
    Loothing.Session:RegisterCallback("OnLootBufferChanged", function(_owner, buffer)
        if self._suppressEvent then return end
        if not self.frame or not self.frame:IsShown() then return end
        self:RebuildEntries(buffer)
        self:Render()
    end, self)
    self._callbackHooked = true
end

--[[--------------------------------------------------------------------
    Frame construction
----------------------------------------------------------------------]]

function LootPickerFrameMixin:BuildFrame()
    local frame = CreateFrame("Frame", "LoothingLootPickerFrame", UIParent, "BackdropTemplate")
    frame:SetSize(PANEL_WIDTH, PANEL_HEIGHT)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("DIALOG")
    frame:SetFrameLevel(100)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:SetClampedToScreen(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function(f) f:StartMoving() end)
    frame:SetScript("OnDragStop", function(f)
        f:StopMovingOrSizing()
        local sk = GetSkinning()
        if sk and sk.SaveFrameState then
            sk:SaveFrameState(f, "LootPicker")
        end
    end)
    frame:Hide()
    frame:SetAlpha(0)
    self.frame = frame
    styleSurface(frame, "frame")

    -- Hook OnHide so ESC-key / UISpecialFrames / external Hide() all
    -- route through the same cancellation cleanup that OnCancel runs.
    -- Gated on `_suppressOnHideCleanup` so OnStart / OnCancel (which
    -- call Hide themselves as part of their own cleanup) don't re-enter.
    -- Hide may fade asynchronously, so the flag is cleared inside OnHide,
    -- not immediately after Hide() returns.
    frame:HookScript("OnHide", function()
        -- Parent-driven hides (UIParent hidden for a cinematic, Alt-Z) keep
        -- IsShown() true — the picker is still logically open and will
        -- reappear. Running cleanup here would cancel the prompt and latch a
        -- phantom decline the user never made.
        if frame:IsShown() then return end
        if self._suppressOnHideCleanup then
            self._suppressOnHideCleanup = false
            self._starting = false
            if self.frame then self.frame:EnableMouse(true) end
            if self.startBtn then self.startBtn:Enable() end
            if Loothing.Session and Loothing.Session.OnLootPickerHidden then
                Loothing.Session:OnLootPickerHidden()
            end
            return
        end
        self:_DoCleanupOnHide()
    end)

    -- OnShow: re-register item-info event + raise
    frame:HookScript("OnShow", function()
        if self._itemInfoEventRegistered then return end
        frame:RegisterEvent("GET_ITEM_INFO_RECEIVED")
        self._itemInfoEventRegistered = true
    end)
    -- Unregister the item-info event on hide so the handler doesn't
    -- churn through its linear `self.entries` scan on every item cache
    -- hit while the picker isn't even visible.
    frame:HookScript("OnHide", function()
        if self._itemInfoEventRegistered then
            frame:UnregisterEvent("GET_ITEM_INFO_RECEIVED")
            self._itemInfoEventRegistered = false
        end
    end)

    -- Decorative header strip + accent line
    local sk = GetSkinning()
    if sk and sk.DecorateWindow then
        sk:DecorateWindow(frame)
    end

    -- Gradient accent strip behind the title (effect #4)
    local headerStrip = frame:CreateTexture(nil, "BACKGROUND", nil, 2)
    headerStrip:SetPoint("TOPLEFT", 2, -2)
    headerStrip:SetPoint("TOPRIGHT", -2, -2)
    headerStrip:SetHeight(44)
    headerStrip:SetColorTexture(1, 1, 1, 1)
    self.headerStrip = headerStrip
    ApplyAccentGlow(headerStrip, 0.18)

    -- Pixel-perfect outer border (effect #5)
    if PixelUtil and type(PixelUtil.SetThinBorder) == "function" then
        self.pixelBorder = PixelUtil.SetThinBorder(frame, getColor("borderStrong", { 0, 0, 0, 1 }))
    end

    -- Title (sits inside the header strip)
    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 14, -12)
    title:SetText(L("LOOT_PICKER_TITLE", "Pick Loot for Session"))
    applyTextColor(title, "text", { 1, 0.82, 0 })
    self.titleText = title

    -- Subtitle: encounter name + count
    local subtitle = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    subtitle:SetPoint("TOPLEFT", 14, -32)
    applyTextColor(subtitle, "textMuted", { 0.7, 0.7, 0.7 })
    self.subtitleText = subtitle

    -- Close button (acts as Cancel)
    local closeBtn = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    closeBtn:SetSize(22, 22)
    closeBtn:SetPoint("TOPRIGHT", -2, -2)
    closeBtn:SetScript("OnClick", function() self:OnCancel() end)
    AttachIconButtonPolish(closeBtn, { hoverScale = 1.15, pressScale = 0.90 })
    self.closeBtn = closeBtn

    -- Toolbar: Show blocked + Select all / none
    local toolbar = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    toolbar:SetPoint("TOPLEFT", 10, -52)
    toolbar:SetPoint("TOPRIGHT", -10, -52)
    toolbar:SetHeight(28)
    styleSurface(toolbar, "alt")
    self.toolbar = toolbar

    self.showBlockedCheck = CreateFrame("CheckButton", "LoothingLootPickerShowBlocked", toolbar,
        "ChatConfigCheckButtonTemplate")
    self.showBlockedCheck:SetPoint("LEFT", 6, 0)
    -- Filter icon sits between checkbox and label to mark this as a filter toggle.
    self.filterIcon = self.showBlockedCheck:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    self.filterIcon:SetPoint("LEFT", self.showBlockedCheck, "RIGHT", 2, 1)
    Loolib.Fonts:SetIconFont(self.filterIcon, 10, "")
    self.filterIcon:SetText(Loolib.Fonts:Icon("filter"))
    self.filterIcon:SetTextColor(0.8, 0.8, 0.85)
    if self.showBlockedCheck.Text then
        self.showBlockedCheck.Text:ClearAllPoints()
        self.showBlockedCheck.Text:SetPoint("LEFT", self.filterIcon, "RIGHT", 4, 0)
        self.showBlockedCheck.Text:SetText(L("LOOT_PICKER_SHOW_BLOCKED", "Show blocked items"))
    else
        self.showBlockedLabel = self.showBlockedLabel or self.showBlockedCheck:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        self.showBlockedLabel:ClearAllPoints()
        self.showBlockedLabel:SetPoint("LEFT", self.filterIcon, "RIGHT", 4, 1)
        self.showBlockedLabel:SetText(L("LOOT_PICKER_SHOW_BLOCKED", "Show blocked items"))
    end
    self.showBlockedCheck:SetScript("OnClick", function(c)
        local newState = c:GetChecked() and true or false
        -- When hiding blocked rows, also uncheck them so they don't get
        -- silently included in the start payload (the count would lie).
        if not newState and self.showBlocked then
            for _, e in ipairs(self.entries) do
                if not e.eval.allowed then
                    e.checked = false
                    e.userOverride = true
                end
            end
        end
        self.showBlocked = newState
        self:Render()
    end)

    self.selectNoneBtn = ns.CreateThemedButton(toolbar)
    self.selectNoneBtn:SetSize(96, 20)
    self.selectNoneBtn:SetPoint("RIGHT", -6, 0)
    self.selectNoneBtn:SetText(L("LOOT_PICKER_SELECT_NONE", "Select None"))
    self.selectNoneBtn:SetScript("OnClick", function() self:SetAll(false) end)
    styleButton(self.selectNoneBtn, "ghost")

    self.selectAllBtn = ns.CreateThemedButton(toolbar)
    self.selectAllBtn:SetSize(96, 20)
    self.selectAllBtn:SetPoint("RIGHT", self.selectNoneBtn, "LEFT", -4, 0)
    self.selectAllBtn:SetText(L("LOOT_PICKER_SELECT_ALL", "Select All"))
    self.selectAllBtn:SetScript("OnClick", function() self:SetAll(true) end)
    styleButton(self.selectAllBtn, "ghost")

    -- Scrollable list
    local listFrame = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    listFrame:SetPoint("TOPLEFT", 10, -84)
    listFrame:SetPoint("BOTTOMRIGHT", -10, 50)
    styleSurface(listFrame, "inset")
    self.listFrame = listFrame

    local scroll = CreateFrame("ScrollFrame", "LoothingLootPickerScroll", listFrame)
    scroll:SetPoint("TOPLEFT", 4, -4)
    scroll:SetPoint("BOTTOMRIGHT", -14, 4)
    self.scrollFrame = scroll

    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(PANEL_WIDTH - 50, 1)
    scroll:SetScrollChild(content)
    self.scrollContent = content

    if ns.ApplyThemedScrollBar then
        ns.ApplyThemedScrollBar(scroll, {
            autoHide = true,
            showButtons = true,
            thickness = 10,
        })
    end

    self.emptyText = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    self.emptyText:SetPoint("CENTER", scroll, "CENTER", 0, 0)
    self.emptyText:SetText(L("LOOT_PICKER_EMPTY", "No tradable loot detected."))
    applyTextColor(self.emptyText, "textMuted", { 0.6, 0.6, 0.6 })
    self.emptyText:Hide()

    -- Footer buttons
    self.startBtn = ns.CreateThemedButton(frame)
    self.startBtn:SetSize(180, 26)
    self.startBtn:SetPoint("BOTTOMRIGHT", -10, 12)
    self.startBtn:SetScript("OnClick", function() self:OnStart() end)
    styleButton(self.startBtn, "primary")

    self.cancelBtn = ns.CreateThemedButton(frame)
    self.cancelBtn:SetSize(96, 26)
    self.cancelBtn:SetPoint("RIGHT", self.startBtn, "LEFT", -6, 0)
    self.cancelBtn:SetText(L("LOOT_PICKER_CANCEL", "Cancel"))
    self.cancelBtn:SetScript("OnClick", function() self:OnCancel() end)
    styleButton(self.cancelBtn, "ghost")

    -- Theming, position persistence, ESC-close, click-to-raise
    if sk and sk.SetupFrame then
        sk:SetupFrame(frame, "LootPicker", "LoothingLootPickerFrame", {
            escapeClose = true,
            combatMinimize = false,
        })
    else
        local WM = Loolib:GetModule("WindowManager")
        if WM and WM.Register then WM:Register(frame) end
    end

    -- Refresh row visuals when item info finishes loading from a cold
    -- cache (icon, ilvl, real link). The event is registered/unregistered
    -- in the OnShow/OnHide hooks above so the handler doesn't scan
    -- self.entries on every item-cache hit while the picker is hidden.
    frame:SetScript("OnEvent", function(_, event, itemID)
        if event ~= "GET_ITEM_INFO_RECEIVED" then return end
        if not frame:IsShown() then return end
        if not itemID then return end
        local filter = Loothing.ItemFilter
        local changed = false
        for _, entry in ipairs(self.entries) do
            local link = entry.itemLink
            if link and link:find("|Hitem:" .. itemID .. ":", 1, true) then
                if entry.eval and entry.eval.cacheIncomplete
                    and not entry.userOverride
                    and filter and filter.EvaluateItem then
                    entry.eval = filter:EvaluateItem(link)
                    entry.checked = entry.eval.allowed and true or false
                    changed = true
                end
                changed = true
            end
        end
        if changed then
            self:Render()
        end
    end)
end

--- Re-apply theme colors to picker children. Called from SkinningMixin
--- when the user changes theme/accent while the picker is open.
function LootPickerFrameMixin:ApplyTheme()
    if not self._built or not self.frame then return end
    styleSurface(self.frame, "frame")
    styleSurface(self.toolbar, "alt")
    styleSurface(self.listFrame, "inset")
    applyTextColor(self.titleText, "text", { 1, 0.82, 0 })
    applyTextColor(self.subtitleText, "textMuted", { 0.7, 0.7, 0.7 })
    for _, row in ipairs(self.rows) do
        if row:IsShown() then styleSurface(row, "alt") end
    end
    -- Re-apply custom accents
    if self.headerStrip then
        ApplyAccentGlow(self.headerStrip, 0.18)
        self.headerStrip:SetAlpha(1)
    end
    if self.pixelBorder then
        local c = getColor("borderStrong", { 0, 0, 0, 1 })
        for _, tex in pairs(self.pixelBorder) do
            if type(tex) == "table" and type(tex.SetColorTexture) == "function" then
                tex:SetColorTexture(c[1] or 0, c[2] or 0, c[3] or 0, c[4] or 1)
            end
        end
    end
    -- Re-bind active rows to refresh chip/text colors.
    self:Render()
end

--[[--------------------------------------------------------------------
    Public API
----------------------------------------------------------------------]]

function LootPickerFrameMixin:Show(encounterID, encounterName, lootBuffer)
    if not self._built then self:Init() end

    -- Defensive re-attach: Session may have loaded after our first Init.
    self:RegisterSessionCallback()

    -- A successful Start hides with an async fade-out. Do not let a delayed
    -- prompt/refresh re-enter Show() during that window and unlock the button.
    if self._starting and self.frame and self.frame:IsShown() then
        return
    end

    local newEncounter = (encounterID ~= self.encounterID)
                       or not self.frame:IsShown()

    self.encounterID = encounterID or 0
    self.encounterName = encounterName or L("LOOT_PICKER_DEFAULT_BOSS", "Encounter")
    self._starting = false
    if self.frame then self.frame:EnableMouse(true) end

    -- Only reset showBlocked + entries when this is a different encounter
    -- (or first show). A re-fire of Show for the SAME encounter — e.g.,
    -- a late bag-scan adding more items — should preserve the user's
    -- "Show blocked" state and any check overrides they've made.
    if newEncounter then
        self.showBlocked = false
        if self.showBlockedCheck then self.showBlockedCheck:SetChecked(false) end
        self.entries = {}
    end

    self:RebuildEntries(lootBuffer)
    self:Render()

    if self.frame._loothingFadeGroup then self.frame._loothingFadeGroup:Stop() end
    self.frame:Show()
    self.frame:Raise()
    -- Pick up any theme/accent change that happened while the modal was closed.
    if type(self.ApplyTheme) == "function" then self:ApplyTheme() end

    if AnimationPresets then
        self.frame._loothingFadeGroup = AnimationPresets.FadeIn(self.frame, 0.22, "outCubic")
    else
        self.frame:SetAlpha(1)
    end
end

function LootPickerFrameMixin:Hide()
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

function LootPickerFrameMixin:IsShown()
    return self.frame and self.frame:IsShown() or false
end

--[[--------------------------------------------------------------------
    Empty-state text: distinguish "still waiting" vs "all blocked"
----------------------------------------------------------------------]]

--- Update the empty-state message based on scan and filter state.
function LootPickerFrameMixin:UpdateEmptyStateText()
    if not self.emptyText then return end

    local session = Loothing.Session
    local scanActive = session and session.bagScanTimer ~= nil
    local startedAt = session and session.bagScanStartedAt
    local SCAN_WINDOW = 60

    if self.entries and #self.entries > 0 then
        self.emptyText:SetText(string.format(
            L("LOOT_PICKER_ALL_BLOCKED_FMT",
              "%d items hidden - toggle Show blocked to review."),
            #self.entries))
    elseif scanActive and startedAt then
        local elapsed = GetTime() - startedAt
        local remaining = math.max(0, math.ceil(SCAN_WINDOW - elapsed))
        self.emptyText:SetText(string.format(
            L("LOOT_PICKER_WAITING_FMT",
              "Waiting for roll results… (%ds remaining)"),
            remaining))
    else
        self.emptyText:SetText(
            L("LOOT_PICKER_EMPTY",
              "No tradable loot detected."))
    end
end

--[[--------------------------------------------------------------------
    Entry construction (one per buffer item)
----------------------------------------------------------------------]]

function LootPickerFrameMixin:RebuildEntries(buffer)
    -- Snapshot prior entries BEFORE wiping so we can preserve the user's
    -- per-item check overrides across rebuilds (live updates from late
    -- bag scans). Without this snapshot, FindPreviousCheckedState would
    -- always read from the just-cleared list and return nil.
    local prior = self.entries or {}
    local usedPrior = {}
    self.entries = {}
    if type(buffer) ~= "table" then return end

    local filter = Loothing.ItemFilter
    for i, raw in ipairs(buffer) do
        local pickerEncounterID = tonumber(self.encounterID) or 0
        local rawEncounterID = raw and tonumber(raw.encounterID) or 0
        local sameEncounter = not raw
            or rawEncounterID == 0
            or (pickerEncounterID ~= 0 and rawEncounterID == pickerEncounterID)
        if raw and raw.itemLink and sameEncounter then
            -- Preserve filter decision + user override across rebuilds for the
            -- SAME (link, looter). EvaluateItem depends on async item cache
            -- state; recalculating can flip default checkbox state mid-pick.
            local previousChecked
            local previousEval
            local previousUserOverride = false
            for priorIndex, e in ipairs(prior) do
                if not usedPrior[priorIndex]
                    and e.itemLink == raw.itemLink
                    and e.playerName == raw.playerName
                    and e.encounterID == raw.encounterID then
                    previousChecked = e.checked
                    previousEval = e.eval
                    previousUserOverride = e.userOverride == true
                    usedPrior[priorIndex] = true
                    break
                end
            end

            local eval = previousEval
            if not eval or (eval.cacheIncomplete and not previousUserOverride) then
                if filter and filter.EvaluateItem then
                    eval = filter:EvaluateItem(raw.itemLink)
                else
                    eval = { allowed = true }
                end
            end

            local checked
            if previousChecked ~= nil and (previousUserOverride or not (previousEval and previousEval.cacheIncomplete)) then
                checked = previousChecked
            else
                checked = eval.allowed and true or false
            end

            self.entries[#self.entries + 1] = {
                index              = i,
                itemLink           = raw.itemLink,
                itemID             = raw.itemID,
                playerName         = raw.playerName,
                encounterID        = raw.encounterID,
                source             = raw.source,
                tradeTimeRemaining = raw.tradeTimeRemaining,
                eval               = eval,
                checked            = checked,
                userOverride       = previousUserOverride,
            }
        end
    end
end

--[[--------------------------------------------------------------------
    Rendering
----------------------------------------------------------------------]]

function LootPickerFrameMixin:Render()
    -- Hide all rows first; reuse via pool
    for _, row in ipairs(self.rows) do row:Hide() end

    -- Subtitle
    local total = #self.entries
    if self.subtitleText then
        self.subtitleText:SetText(string.format(
            L("LOOT_PICKER_SUBTITLE_FMT", "%s    -    %d items"),
            self.encounterName, total))
    end

    local visible = {}
    for _, entry in ipairs(self.entries) do
        if entry.eval.allowed or self.showBlocked then
            visible[#visible + 1] = entry
        end
    end

    if #visible == 0 then
        -- Distinguish "buffer genuinely empty, scan still running" from
        -- "all items were filter-blocked". Without this the user has no
        -- cue that items are still arriving — they see empty and dismiss.
        self:UpdateEmptyStateText()
        self.emptyText:Show()
        -- Drive periodic text refresh while scan is active so the
        -- countdown ticks down. Cheap: runs only while picker is shown AND
        -- empty. Hidden when the first item arrives.
        if not self._emptyTicker then
            self._emptyTicker = C_Timer.NewTicker(1, function()
                if not self.frame or not self.frame:IsShown() then
                    if self._emptyTicker then
                        self._emptyTicker:Cancel()
                        self._emptyTicker = nil
                    end
                    return
                end
                local visibleCount = 0
                for _, entry in ipairs(self.entries) do
                    if entry.eval.allowed or self.showBlocked then
                        visibleCount = visibleCount + 1
                        break
                    end
                end
                local session = Loothing.Session
                local scanActive = session and session.bagScanTimer ~= nil
                if visibleCount > 0 then
                    self.emptyText:Hide()
                    if self._emptyTicker then
                        self._emptyTicker:Cancel()
                        self._emptyTicker = nil
                    end
                    return
                end
                self:UpdateEmptyStateText()
                if not scanActive and self._emptyTicker then
                    self._emptyTicker:Cancel()
                    self._emptyTicker = nil
                end
            end)
        end
    else
        self.emptyText:Hide()
        if self._emptyTicker then
            self._emptyTicker:Cancel()
            self._emptyTicker = nil
        end
    end

    -- Materialise rows for visible entries (variable row height: blocked
    -- items get extra room for the reason line).
    local yOffset = 0
    local maxIdx = 0
    for i, entry in ipairs(visible) do
        local row = self.rows[i]
        if not row then
            row = self:CreateRow()
            self.rows[i] = row
        end
        local rowH = entry.eval.allowed and ROW_HEIGHT_DEFAULT or ROW_HEIGHT_BLOCKED
        row:SetHeight(rowH)
        row.qBar:SetHeight(rowH - 4)
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", self.scrollContent, "TOPLEFT", 2, -yOffset)
        row:SetPoint("RIGHT", self.scrollContent, "RIGHT", -2, 0)
        self:BindRow(row, entry)
        row:Show()
        yOffset = yOffset + rowH + ROW_SPACING
        maxIdx = i
    end
    -- Hide and detach any leftover pooled rows so stale references don't
    -- pin item links from a previous (larger) encounter.
    for i = maxIdx + 1, #self.rows do
        local r = self.rows[i]
        if r then
            r:Hide()
            r._link = nil
            r._entry = nil
        end
    end

    -- Resize content to actual aggregate height
    self.scrollContent:SetHeight(math.max(1, yOffset))

    -- Defer to UpdateStartButton so the visible-only counting rule is
    -- consistent across the two call paths.
    self:UpdateStartButton()
end

function LootPickerFrameMixin:CreateRow()
    local row = CreateFrame("Frame", nil, self.scrollContent, "BackdropTemplate")
    row:SetHeight(ROW_HEIGHT_DEFAULT)
    styleSurface(row, "alt")

    -- Quality bar (left edge, full height — height is updated per-row in Render)
    local qBar = row:CreateTexture(nil, "ARTWORK")
    qBar:SetSize(3, ROW_HEIGHT_DEFAULT - 4)
    qBar:SetPoint("LEFT", 2, 0)
    row.qBar = qBar

    -- Checkbox
    local check = CreateFrame("CheckButton", nil, row, "ChatConfigCheckButtonTemplate")
    check:SetPoint("LEFT", 10, 0)
    check:SetSize(22, 22)
    if check.Text then check.Text:SetText("") end
    row.check = check

    -- Icon
    local icon = row:CreateTexture(nil, "ARTWORK")
    icon:SetSize(ICON_SIZE, ICON_SIZE)
    icon:SetPoint("LEFT", check, "RIGHT", 6, 0)
    row.icon = icon

    -- Status chip (top-right) — visible only when item is blocked
    local chip = CreateFrame("Frame", nil, row, "BackdropTemplate")
    chip:SetHeight(18)
    chip:SetPoint("TOPRIGHT", -8, -4)
    chip:Hide()
    chip:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        tile = false, edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    local chipText = chip:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    chipText:SetPoint("LEFT", 6, 0)
    chipText:SetPoint("RIGHT", -6, 0)
    chip.text = chipText
    row.chip = chip

    -- Item name (top line, leaves room for the chip on the right)
    local nameText = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    nameText:SetPoint("TOPLEFT", icon, "TOPRIGHT", 8, -2)
    nameText:SetPoint("RIGHT", chip, "LEFT", -8, 0)
    nameText:SetJustifyH("LEFT")
    nameText:SetWordWrap(false)
    row.nameText = nameText

    -- Looter / ilvl line
    local metaText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    metaText:SetPoint("TOPLEFT", nameText, "BOTTOMLEFT", 0, -2)
    metaText:SetPoint("RIGHT", row, "RIGHT", -8, 0)
    metaText:SetJustifyH("LEFT")
    metaText:SetWordWrap(false)
    row.metaText = metaText

    -- Reason line (third line, only populated for blocked items)
    -- Anchored UNDER metaText so it doesn't overlap on tall blocked rows.
    local reasonText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    reasonText:SetPoint("TOPLEFT", metaText, "BOTTOMLEFT", 0, -2)
    reasonText:SetPoint("RIGHT", row, "RIGHT", -8, 0)
    reasonText:SetJustifyH("LEFT")
    reasonText:SetWordWrap(false)
    row.reasonText = reasonText

    -- Hover/tooltip — shift-gated, strata-aware. r._link is rebound per row in BindRow.
    ns.AttachItemTooltip(row, function() return row._link end)

    return row
end

function LootPickerFrameMixin:BindRow(row, entry)
    row._link = entry.itemLink
    row._entry = entry

    -- Resolve item info for icon + name + ilvl + quality
    local _, _, quality, ilvl, _, _, _, _, _, iconTex = C_Item.GetItemInfo(entry.itemLink)
    quality = quality or entry.eval.quality

    -- Quality bar
    local qr, qg, qb = qualityColor(quality)
    row.qBar:SetColorTexture(qr, qg, qb, 1)

    -- Icon
    if iconTex then row.icon:SetTexture(iconTex) else row.icon:SetTexture(nil) end

    -- Name (raw item link so the chat-quality color comes through)
    row.nameText:SetText(entry.itemLink)

    -- Meta line: "Looter: X    ilvl Y"
    local metaParts = {}
    metaParts[#metaParts + 1] = string.format(L("LOOT_PICKER_LOOTER_FMT", "Looter: %s"),
        entry.playerName or L("LOOT_PICKER_UNKNOWN_LOOTER", "Unknown"))
    if ilvl and ilvl > 0 then
        metaParts[#metaParts + 1] = string.format(L("LOOT_PICKER_ILVL_FMT", "ilvl %d"), ilvl)
    end
    row.metaText:SetText(table.concat(metaParts, "    "))
    applyTextColor(row.metaText, "textMuted", { 0.7, 0.7, 0.7 })

    -- Status chip + reason line — populated only when blocked
    if entry.eval.allowed then
        row.chip:Hide()
        row.reasonText:SetText("")
    else
        row.chip:Show()
        row.chip.text:SetText(L("LOOT_PICKER_CHIP_BLOCKED", "BLOCKED"))
        local danger = getColor("danger", { 0.95, 0.4, 0.4 })
        row.chip:SetBackdropColor(danger[1] * 0.25, danger[2] * 0.15, danger[3] * 0.15, 0.9)
        row.chip:SetBackdropBorderColor(danger[1], danger[2], danger[3], 0.85)
        applyTextColor(row.chip.text, "danger", { 1, 0.55, 0.55 })

        local reason = self:DescribeReason(entry.eval, quality) or ""
        row.reasonText:SetText(reason)
        applyTextColor(row.reasonText, "danger", { 0.95, 0.55, 0.55 })

        local chipWidth = math.min(140, math.max(68, row.chip.text:GetStringWidth() + 16))
        row.chip:SetWidth(chipWidth)
    end

    -- Checkbox state + handler
    row.check:SetChecked(entry.checked)
    row.check:SetScript("OnClick", function(c)
        entry.checked = c:GetChecked() and true or false
        entry.userOverride = true
        self:UpdateStartButton()
    end)
end

-- Escape % so reasons containing literal % (e.g., "Hand of A'dal (5%)")
-- don't blow up string.format.
local function escapeFormatPct(s)
    if type(s) ~= "string" then return tostring(s) end
    return (s:gsub("%%", "%%%%"))
end

function LootPickerFrameMixin:DescribeReason(eval, resolvedQuality)
    if eval.allowed then return nil end
    local reason = eval.reason or ""
    local fmt = L("LOOT_PICKER_BLOCKED_REASON_FMT", "Blocked by filter: %s")

    if reason == "" then
        return string.format(fmt, L("LOOT_PICKER_REASON_UNKNOWN", "unknown"))
    end
    if reason == "ignored" then
        return string.format(fmt, escapeFormatPct(L("LOOT_PICKER_REASON_IGNORED", "ignored item")))
    end
    if reason == "boe" then
        return string.format(fmt, escapeFormatPct(L("LOOT_PICKER_REASON_BOE", "Bind on Equip")))
    end
    if reason:sub(1, 6) == "class:" then
        return string.format(fmt, escapeFormatPct(reason:sub(7)))
    end
    if reason == "quality" then
        local q = resolvedQuality or eval.quality or 0
        local minQ = eval.minQuality or 0
        return string.format(L("LOOT_PICKER_BLOCKED_QUALITY_FMT", "Below quality threshold (q%d < q%d)"),
            q, minQ)
    end
    return string.format(fmt, escapeFormatPct(reason))
end

function LootPickerFrameMixin:UpdateStartButton()
    -- Count only entries that are checked AND visible (allowed-by-filter
    -- OR Show-blocked-on). Hidden-but-checked entries can't exist after
    -- the showBlockedCheck OnClick auto-uncheck, but the Render path
    -- iterates everyone, so guard here too.
    local startCount = 0
    for _, e in ipairs(self.entries) do
        if e.checked and (e.eval.allowed or self.showBlocked) then
            startCount = startCount + 1
        end
    end
    if self.startBtn then
        self.startBtn:SetText(string.format(
            L("LOOT_PICKER_START_FMT", "Start Session  -  %d items"), startCount))
        self.startBtn:SetEnabled(startCount > 0)
    end
end

--[[--------------------------------------------------------------------
    Actions
----------------------------------------------------------------------]]

function LootPickerFrameMixin:HasCheckedSelections()
    for _, e in ipairs(self.entries or {}) do
        if e.checked then
            return true
        end
    end
    return false
end

function LootPickerFrameMixin:IsShowingEncounter(encounterID)
    if not self:IsShown() then return false end
    if encounterID == nil then return true end
    return self.encounterID == encounterID
end

function LootPickerFrameMixin:AutoCommitForEncounterStart(encounterID, encounterName)
    if not self:IsShown() then return true end
    if not self:HasCheckedSelections() then return false end
    if Loothing and Loothing.Debug then
        Loothing:Debug("LootPicker: auto-committing selections before encounter start:",
            tostring(encounterName or encounterID or "unknown"))
    end
    return self:OnStart()
end

function LootPickerFrameMixin:SetAll(checked)
    for _, e in ipairs(self.entries) do
        if checked then
            -- Only flip allowed entries when ticking; blocked stay off
            -- unless the user has Show Blocked on (then take everything)
            if self.showBlocked or e.eval.allowed then
                e.checked = true
                e.userOverride = true
            end
        else
            e.checked = false
            e.userOverride = true
        end
    end
    self:Render()
end

function LootPickerFrameMixin:OnStart()
    -- Double-click guard
    if self._starting then return false end
    self._starting = true

    if not Loothing.Session or not Loothing.Session.StartSessionWithPickedItems then
        self._starting = false
        self:Hide()
        return false
    end

    local picked = {}
    for _, e in ipairs(self.entries) do
        if e.checked then
            picked[#picked + 1] = {
                itemLink           = e.itemLink,
                itemID             = e.itemID,
                playerName         = e.playerName,
                encounterID        = e.encounterID,
                source             = e.source,
                tradeTimeRemaining = e.tradeTimeRemaining,
            }
        end
    end

    -- Hold the frame visible across the StartSession attempt — if we Hide
    -- before the call and the start fails, our Show() retry path uses
    -- `not self.frame:IsShown()` to compute newEncounter, which would
    -- evaluate true and wipe self.entries (losing the user's overrides).
    -- Hide only on confirmed success.
    self._suppressEvent = true
    local ok = Loothing.Session:StartSessionWithPickedItems(self.encounterID, self.encounterName, picked)
    self._suppressEvent = false
    if ok == false then
        -- StartSession failed (no group, lost ML rights, etc.). Frame
        -- stays shown with current entries; print a one-line error so
        -- the user understands why nothing happened.
        self._starting = false
        Loothing:Print(L("LOOT_PICKER_START_FAILED",
            "Could not start the loot session — check that you are in a group and still handling loot."))
        if self.frame then
            self.frame:Raise()  -- bring back to top in case another popup grabbed focus
        end
        return false
    end
    -- Successful start — suppress the OnHide cleanup path so we don't
    -- wipe the buffer Session already consumed via the replay loop.
    self._suppressOnHideCleanup = true
    if self.frame then self.frame:EnableMouse(false) end
    if self.startBtn then self.startBtn:Disable() end
    self:Hide()
    return true
end

--- Shared cleanup run when the picker hides WITHOUT a successful Start.
--- Called from both the manual Cancel button (via OnCancel) and any
--- indirect Hide (ESC key, UISpecialFrames, external Hide). Session
--- bookkeeping is centralised in Session:CancelPendingPrompt.
function LootPickerFrameMixin:_DoCleanupOnHide()
    self._starting = false
    self._suppressEvent = true
    if Loothing.Session and Loothing.Session.CancelPendingPrompt then
        Loothing.Session:CancelPendingPrompt(self.encounterID)
    elseif Loothing.Session and Loothing.Session.lootBuffer then
        -- Prefer wipe() to preserve table identity for any module that
        -- might have captured the reference; fall back to assignment if
        -- wipe is unavailable in the environment.
        if type(wipe) == "function" then
            wipe(Loothing.Session.lootBuffer)
        else
            Loothing.Session.lootBuffer = {}
        end
        if Loothing.Session.TriggerEvent then
            Loothing.Session:TriggerEvent("OnLootBufferChanged", Loothing.Session.lootBuffer)
        end
    end
    self._suppressEvent = false
end

function LootPickerFrameMixin:OnCancel()
    -- Run cancel cleanup BEFORE Hide, then set the flag so the async
    -- OnHide hook doesn't re-run cleanup; its suppress branch still hands
    -- off any pendingBufferedPrompt via Session:OnLootPickerHidden.
    -- (Previous order set the flag across the async fade, so the hook ran
    -- the successful-start branch before cleanup had executed.)
    self:_DoCleanupOnHide()
    self._suppressOnHideCleanup = true
    self:Hide()
end

--[[--------------------------------------------------------------------
    Module export — instance lives at ns.LootPickerFrame and is built on
    first method dispatch. Wrapped method closures are memoised on the
    wrapper table so repeated calls don't allocate.
----------------------------------------------------------------------]]

local instance = nil
local function getInstance()
    if not instance then
        instance = Loolib.CreateFromMixins(LootPickerFrameMixin)
    end
    return instance
end

ns.LootPickerFrame = setmetatable({}, {
    __index = function(t, key)
        local inst = getInstance()
        local v = inst[key]
        if type(v) == "function" then
            local wrapped = function(_, ...) return v(inst, ...) end
            t[key] = wrapped  -- memoise so subsequent dispatch is direct
            return wrapped
        end
        return v
    end,
})
