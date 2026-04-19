--[[--------------------------------------------------------------------
    Loothing - Loot Council Addon for WoW 12.0+
    ThemedDropdown - Custom themed dropdown matching the rest of the polish

    Replaces Blizzard's UIDropDownMenuTemplate for Loothing-side controls
    that need to match SkinningMixin colors, animate on open/close, and
    handle both flat option lists and grouped option lists (e.g. the
    simulator raid picker that groups raids by tier).

    Usage:
        local dd = ns.CreateThemedDropdown(parent, {
            width = 260,
            getOptions = function() return optionsList end,
            getSelected = function() return selectedValue end,
            onSelect = function(value, option) ... end,
            getLabel = function(option) return option.label end, -- optional
        })
        dd:SetPoint("LEFT", label, "RIGHT", 8, 0)
        dd:Refresh()

    Option list format (flat):
        { { value = "a", label = "Aaa" }, { value = "b", label = "Bbb" } }

    Option list format (grouped):
        { { header = "Tier 1" },
          { value = "a", label = "Raid A" },
          { value = "b", label = "Raid B" },
          { header = "Tier 2" },
          { value = "c", label = "Raid C" } }
----------------------------------------------------------------------]]

local _, ns = ...
local Loolib = LibStub("Loolib")

local AnimationPresets = Loolib.AnimationPresets

local function GetSkinning() return ns.SkinningMixin end
local function GetColor(key, fallback)
    local sk = GetSkinning()
    if sk and sk.GetColor then return sk:GetColor(key, fallback) end
    return fallback or { 1, 1, 1, 1 }
end

local ROW_HEIGHT = 22
local MAX_POPUP_HEIGHT = 260
local POPUP_PADDING = 4
local CHEVRON_SIZE = 10
local HEADER_HEIGHT = 18

--[[--------------------------------------------------------------------
    One shared popup instance
    Only one themed dropdown can be open at a time. The popup is
    parented to UIParent so it can overlay any frame regardless of
    strata, and it's recycled across every themed dropdown.
----------------------------------------------------------------------]]

local popup

local function ensurePopup()
    if popup then return popup end

    local f = CreateFrame("Frame", "LoothingThemedDropdownPopup", UIParent, "BackdropTemplate")
    f:SetFrameStrata("FULLSCREEN_DIALOG")
    f:SetFrameLevel(200)
    f:SetClampedToScreen(true)
    f:EnableMouse(true)
    f:Hide()
    f:SetAlpha(0)
    f:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        tile = false, edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    local bg = GetColor("panelAlt", { 0.08, 0.09, 0.11, 0.98 })
    local border = GetColor("borderStrong", { 0.3, 0.3, 0.35, 1 })
    f:SetBackdropColor(bg[1], bg[2], bg[3], 0.98)
    f:SetBackdropBorderColor(border[1], border[2], border[3], border[4] or 1)

    -- Scroll frame for long option lists.
    local scroll = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", POPUP_PADDING, -POPUP_PADDING)
    scroll:SetPoint("BOTTOMRIGHT", -22, POPUP_PADDING)
    f.scroll = scroll

    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(1, 1)
    scroll:SetScrollChild(content)
    f.content = content

    -- Pool of row buttons we reuse across dropdowns.
    f.rows = {}
    f.headers = {}
    f.activeRows = 0
    f.activeHeaders = 0

    -- Close on click outside.
    f:SetScript("OnShow", function(self)
        self._closeHandler = self._closeHandler or function(_, btn)
            if not self:IsShown() then return end
            if self:IsMouseOver() then return end
            if self._owner and self._owner:IsMouseOver() then return end
            self:Close()
        end
        if not self._globalClickCatcher then
            local catcher = CreateFrame("Button", nil, UIParent)
            catcher:SetFrameStrata("FULLSCREEN_DIALOG")
            catcher:SetFrameLevel(199)  -- just below popup
            catcher:SetAllPoints(UIParent)
            catcher:RegisterForClicks("LeftButtonUp", "RightButtonUp", "MiddleButtonUp")
            catcher:SetScript("OnClick", function() self:Close() end)
            catcher:Hide()
            self._globalClickCatcher = catcher
        end
        self._globalClickCatcher:Show()
    end)

    f:SetScript("OnHide", function(self)
        if self._globalClickCatcher then self._globalClickCatcher:Hide() end
        if self._owner then
            -- Reset owner's visual open state.
            if self._owner._setOpenState then self._owner:_setOpenState(false) end
            self._owner = nil
        end
    end)

    -- Close helper with fade animation.
    function f:Close()
        if self._fadeGroup then self._fadeGroup:Stop() end
        if AnimationPresets and self:IsVisible() then
            self._fadeGroup = AnimationPresets.FadeOut(self, 0.10, "inCubic", true, function()
                if self then self:SetAlpha(0) end
            end)
        else
            self:Hide()
        end
    end

    popup = f
    return f
end

--[[--------------------------------------------------------------------
    Row + header pool
----------------------------------------------------------------------]]

local function acquireRow(popupFrame)
    popupFrame.activeRows = popupFrame.activeRows + 1
    local row = popupFrame.rows[popupFrame.activeRows]
    if row then
        row:Show()
        return row
    end

    row = CreateFrame("Button", nil, popupFrame.content, "BackdropTemplate")
    row:SetHeight(ROW_HEIGHT)
    row:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        tile = false,
        insets = { left = 0, right = 0, top = 0, bottom = 0 },
    })
    row:SetBackdropColor(0, 0, 0, 0)

    local text = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    text:SetPoint("LEFT", 10, 0)
    text:SetPoint("RIGHT", -10, 0)
    text:SetJustifyH("LEFT")
    text:SetWordWrap(false)
    row.text = text

    local check = row:CreateTexture(nil, "OVERLAY")
    check:SetSize(10, 10)
    check:SetPoint("RIGHT", -6, 0)
    check:SetColorTexture(1, 1, 1, 1)
    check:Hide()
    row.check = check

    row:SetScript("OnEnter", function(self)
        local hoverC = GetColor("rowHover", { 0.15, 0.18, 0.24, 0.7 })
        self:SetBackdropColor(hoverC[1], hoverC[2], hoverC[3], hoverC[4] or 0.7)
        local textC = GetColor("text", { 1, 1, 1, 1 })
        self.text:SetTextColor(textC[1], textC[2], textC[3], 1)
    end)
    row:SetScript("OnLeave", function(self)
        if self._selected then
            local selC = GetColor("rowSelected", { 0.15, 0.18, 0.24, 0.85 })
            self:SetBackdropColor(selC[1], selC[2], selC[3], selC[4] or 0.85)
        else
            self:SetBackdropColor(0, 0, 0, 0)
        end
        local textC = self._selected
            and GetColor("accent", { 0.95, 0.78, 0.30, 1 })
            or GetColor("text", { 1, 1, 1, 1 })
        self.text:SetTextColor(textC[1], textC[2], textC[3], 1)
    end)
    row:SetScript("OnClick", function(self)
        if self._onClick then self:_onClick() end
    end)

    popupFrame.rows[popupFrame.activeRows] = row
    return row
end

local function acquireHeader(popupFrame)
    popupFrame.activeHeaders = popupFrame.activeHeaders + 1
    local h = popupFrame.headers[popupFrame.activeHeaders]
    if h then
        h:Show()
        return h
    end
    h = CreateFrame("Frame", nil, popupFrame.content)
    h:SetHeight(HEADER_HEIGHT)
    local text = h:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    text:SetPoint("LEFT", 8, -1)
    text:SetPoint("RIGHT", -8, -1)
    text:SetJustifyH("LEFT")
    local c = GetColor("accent", { 0.95, 0.78, 0.30, 1 })
    text:SetTextColor(c[1], c[2], c[3], 1)
    local line = h:CreateTexture(nil, "ARTWORK")
    line:SetHeight(1)
    line:SetPoint("BOTTOMLEFT", 8, 0)
    line:SetPoint("BOTTOMRIGHT", -8, 0)
    local bc = GetColor("border", { 0.2, 0.22, 0.28, 0.8 })
    line:SetColorTexture(bc[1], bc[2], bc[3], bc[4] or 0.8)
    h.text = text
    popupFrame.headers[popupFrame.activeHeaders] = h
    return h
end

local function resetPopup(popupFrame)
    for i = 1, popupFrame.activeRows do
        local row = popupFrame.rows[i]
        if row then row:Hide() row._onClick = nil row._selected = false end
    end
    for i = 1, popupFrame.activeHeaders do
        local h = popupFrame.headers[i]
        if h then h:Hide() end
    end
    popupFrame.activeRows = 0
    popupFrame.activeHeaders = 0
end

--[[--------------------------------------------------------------------
    Dropdown API
----------------------------------------------------------------------]]

local function openDropdown(dd)
    local f = ensurePopup()

    -- Re-theme each open (handles skin/accent changes).
    local bg = GetColor("panelAlt", { 0.08, 0.09, 0.11, 0.98 })
    local border = GetColor("borderStrong", { 0.3, 0.3, 0.35, 1 })
    f:SetBackdropColor(bg[1], bg[2], bg[3], 0.98)
    f:SetBackdropBorderColor(border[1], border[2], border[3], border[4] or 1)

    resetPopup(f)
    f._owner = dd
    local options = dd.getOptions and dd:getOptions() or {}
    local selected = dd.getSelected and dd:getSelected() or nil

    -- Layout rows + headers top-to-bottom into content child
    local y = 0
    local totalHeight = 0
    for i, opt in ipairs(options) do
        if opt.header then
            local h = acquireHeader(f)
            h.text:SetText(opt.header)
            h:ClearAllPoints()
            h:SetPoint("TOPLEFT", 0, -y)
            h:SetPoint("TOPRIGHT", 0, -y)
            y = y + HEADER_HEIGHT
            totalHeight = y
        else
            local row = acquireRow(f)
            local label = opt.label or (dd.getLabel and dd:getLabel(opt)) or tostring(opt.value or "")
            row.text:SetText(label)
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", 0, -y)
            row:SetPoint("TOPRIGHT", 0, -y)
            local isSelected = (opt.value == selected)
            row._selected = isSelected
            if isSelected then
                local selC = GetColor("rowSelected", { 0.15, 0.18, 0.24, 0.85 })
                row:SetBackdropColor(selC[1], selC[2], selC[3], selC[4] or 0.85)
                local accentC = GetColor("accent", { 0.95, 0.78, 0.30, 1 })
                row.text:SetTextColor(accentC[1], accentC[2], accentC[3], 1)
                row.check:Show()
                row.check:SetColorTexture(accentC[1], accentC[2], accentC[3], 1)
            else
                row:SetBackdropColor(0, 0, 0, 0)
                local textC = GetColor("text", { 1, 1, 1, 1 })
                row.text:SetTextColor(textC[1], textC[2], textC[3], 1)
                row.check:Hide()
            end
            row._onClick = function(self)
                if dd.onSelect then dd:onSelect(opt.value, opt) end
                f:Close()
            end
            y = y + ROW_HEIGHT
            totalHeight = y
        end
    end

    -- Sizing: content child = total listed height; popup = min(height, cap) + padding
    f.content:SetHeight(math.max(1, totalHeight))
    local popupHeight = math.min(totalHeight, MAX_POPUP_HEIGHT) + POPUP_PADDING * 2
    f:SetSize(dd:GetWidth(), popupHeight)
    f.content:SetWidth(math.max(1, dd:GetWidth() - POPUP_PADDING * 2 - 18))  -- minus scrollbar

    -- Anchor the popup to just below the dropdown button.
    f:ClearAllPoints()
    f:SetPoint("TOPLEFT", dd, "BOTTOMLEFT", 0, -2)

    -- Scroll reset.
    if f.scroll and f.scroll.ScrollBar then
        f.scroll:SetVerticalScroll(0)
    end

    -- Animate open.
    if f._fadeGroup then f._fadeGroup:Stop() end
    f:Show()
    if AnimationPresets then
        f._fadeGroup = AnimationPresets.FadeIn(f, 0.13, "outCubic")
    else
        f:SetAlpha(1)
    end

    dd:_setOpenState(true)
end

local function closeDropdown()
    if popup and popup:IsShown() then popup:Close() end
end

local DropdownMethods = {}

function DropdownMethods:SetValue(value)
    self._currentValue = value
    self:Refresh()
end

function DropdownMethods:GetValue()
    return self._currentValue
end

function DropdownMethods:SetEnabled(enabled)
    self:EnableMouse(enabled ~= false)
    self._enabled = enabled ~= false
    self:Refresh()
end

function DropdownMethods:Refresh()
    local label = self._currentLabel
    if self.getSelected then
        local sel = self:getSelected()
        if self.getOptions then
            local opts = self:getOptions() or {}
            for _, o in ipairs(opts) do
                if o.value ~= nil and o.value == sel then
                    label = o.label or (self.getLabel and self:getLabel(o)) or tostring(o.value)
                    break
                end
            end
        end
    end
    self.text:SetText(label or "--")
    local textC = self._enabled ~= false
        and GetColor("text", { 1, 1, 1, 1 })
        or GetColor("textSubtle", { 0.5, 0.55, 0.6, 1 })
    self.text:SetTextColor(textC[1], textC[2], textC[3], 1)
    self:_applyStateColors()
end

function DropdownMethods:SetPlaceholder(text)
    self._currentLabel = text
    self.text:SetText(text or "--")
end

function DropdownMethods:_setOpenState(open)
    self._isOpen = open
    -- Flip the chevron orientation when open.
    if self.chevron then
        self.chevron:SetTexCoord(0, 1, open and 1 or 0, open and 0 or 1)
    end
    self:_applyStateColors()
end

function DropdownMethods:_applyStateColors()
    local state = self._isOpen and "open" or (self._hover and "hover" or "idle")
    local borderKey = state == "idle" and "border" or "accent"
    local bgKey = state == "idle" and "panel" or "panelAlt"
    local bg = GetColor(bgKey, { 0.07, 0.08, 0.1, 1 })
    local bc = GetColor(borderKey, { 0.2, 0.22, 0.28, 1 })
    self:SetBackdropColor(bg[1], bg[2], bg[3], bg[4] or 1)
    self:SetBackdropBorderColor(bc[1], bc[2], bc[3], bc[4] or 1)
end

--- Create a themed dropdown.
--- @param parent Frame
--- @param opts table { width, getOptions, getSelected, onSelect, getLabel, placeholder }
--- @return Button (themed dropdown)
function ns.CreateThemedDropdown(parent, opts)
    opts = opts or {}
    local dd = CreateFrame("Button", nil, parent, "BackdropTemplate")
    dd:SetSize(opts.width or 160, 22)
    dd:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        tile = false, edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })

    dd.getOptions = opts.getOptions
    dd.getSelected = opts.getSelected
    dd.onSelect = opts.onSelect
    dd.getLabel = opts.getLabel
    dd._enabled = true
    dd._currentLabel = opts.placeholder or "--"

    -- Label text
    local text = dd:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    text:SetPoint("LEFT", 8, 0)
    text:SetPoint("RIGHT", -22, 0)
    text:SetJustifyH("LEFT")
    text:SetWordWrap(false)
    dd.text = text

    -- Chevron (down-pointing arrow) on the right
    local chev = dd:CreateTexture(nil, "OVERLAY")
    chev:SetTexture("Interface\\Buttons\\UI-MicroStream-Yellow")  -- generic chevron-like
    chev:SetSize(CHEVRON_SIZE, CHEVRON_SIZE)
    chev:SetPoint("RIGHT", -6, 0)
    -- Use texCoord tricks so we can flip on open with SetTexCoord
    chev:SetTexCoord(0, 1, 0, 1)
    local accentC = GetColor("accent", { 0.95, 0.78, 0.30, 1 })
    chev:SetVertexColor(accentC[1], accentC[2], accentC[3], 1)
    dd.chevron = chev

    -- Mixin methods
    for k, v in pairs(DropdownMethods) do dd[k] = v end

    dd:_applyStateColors()
    dd:Refresh()

    dd:SetScript("OnEnter", function(self)
        self._hover = true
        self:_applyStateColors()
    end)
    dd:SetScript("OnLeave", function(self)
        self._hover = false
        self:_applyStateColors()
    end)
    dd:SetScript("OnClick", function(self)
        if not self._enabled then return end
        if self._isOpen then
            closeDropdown()
        else
            openDropdown(self)
        end
    end)

    return dd
end

--- Close any open themed dropdown. Useful for global ESC handlers.
function ns.CloseThemedDropdown()
    closeDropdown()
end
