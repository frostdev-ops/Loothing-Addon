local _, ns = ...
--[[--------------------------------------------------------------------
    Loothing - Loot Council Addon for WoW 12.0+
    ThemedScrollBar - Orientation-aware custom scrollbar widget

    Replaces Blizzard's UIPanelScrollFrameTemplate chrome with a
    ground-up widget that supports vertical + horizontal orientation,
    configurable thickness, optional end buttons rendered with Loolib
    Font Awesome glyphs, animated thumb hover, and auto-hide when the
    content fits within the visible range.

    All colors come from SkinningMixin so accent / skin changes
    propagate live via SkinningMixin:RefreshTheme.

    Public API
    ----------
      ns.CreateThemedScrollBar(parent, opts)
          opts = {
              orientation = "VERTICAL" | "HORIZONTAL"    -- default VERTICAL
              thickness   = 10                           -- track width (V) or height (H)
              showButtons = false                        -- render chevron end-buttons
              buttonSize  = 16                           -- end-button font size
              autoHide    = true                         -- hide when content fits
              minThumbSize = 30                          -- minimum thumb size along scroll axis
              step        = 20                           -- step size for button clicks
          }
          Returns a widget with:
              :AttachTo(scrollFrame)        -- wire to a Blizzard ScrollFrame
              :SetPoint / SetSize           -- passthrough (it's a Frame)
              :SetValue(v) / :GetValue()
              :SetMinMaxValues(min, max)
              :RegisterOnChanged(fn)        -- fires on value change
              :Refresh()                    -- re-apply theme colors
              :SetEnabled(bool)

      ns.CreateScrollableFrame(parent, opts)
          Convenience: creates a ScrollFrame + content + themed scrollbar
          Returns { scrollFrame, content, scrollBar }.
          Honors all ThemedScrollBar opts + { contentWidth, contentHeight }.

      ns.RefreshThemedScrollBars()
          Re-applies theme colors to every live themed scrollbar. Called
          automatically from SkinningMixin:RefreshTheme.
----------------------------------------------------------------------]]

local Loolib = LibStub("Loolib")

local AnimationUtil = Loolib.AnimationUtil
local Fonts = Loolib.Fonts

local function GetSkinning() return ns.SkinningMixin end
local function GetColor(key, fallback)
    local sk = GetSkinning()
    if sk and sk.GetColor then return sk:GetColor(key, fallback) end
    return fallback or { 1, 1, 1, 1 }
end

local DEFAULT_THICKNESS = 10
local DEFAULT_MIN_THUMB = 30
local DEFAULT_STEP = 20
local DEFAULT_BUTTON_SIZE = 14
local HOVER_DURATION = 0.15

-- Weak-keyed registry so live scrollbars can be re-themed and GC safely.
local registered = setmetatable({}, { __mode = "k" })

local function isVertical(self)
    return self._orientation == "VERTICAL"
end

local function setTextureColor(tex, color, alpha)
    if not tex or not color then return end
    tex:SetVertexColor(color[1], color[2], color[3], alpha or (color[4] or 1))
end

local function tweenColor(widget, tex, from, to, fromA, toA)
    if not tex then return end
    if not AnimationUtil then
        setTextureColor(tex, to, toA)
        return
    end
    if widget._thumbColorGroup then widget._thumbColorGroup:Stop() end
    local g = AnimationUtil.CreateGroup(tex)
    g:CreateAnimation("color", {
        target = tex,
        from = { from[1], from[2], from[3], fromA or from[4] or 1 },
        to   = { to[1],   to[2],   to[3],   toA   or to[4]   or 1 },
        duration = HOVER_DURATION,
        easing = "outQuad",
    })
    widget._thumbColorGroup = g
    g:Play()
end

local function applyColors(widget)
    local trackC = GetColor("panelInset", { 0.02, 0.03, 0.04, 0.6 })
    if widget.trackTex then
        widget.trackTex:SetColorTexture(trackC[1], trackC[2], trackC[3], 0.5)
    end
    local thumbC = widget._isHover
        and GetColor("accent", { 0.95, 0.78, 0.30, 1 })
         or GetColor("borderStrong", { 0.28, 0.33, 0.43, 1 })
    local thumbA = widget._isHover and 1 or 0.80
    if widget.thumbTex then
        setTextureColor(widget.thumbTex, thumbC, thumbA)
    end
    -- End buttons (if any) pick up accent on hover via their own hover scripts.
    local btnIdle = GetColor("textMuted", { 0.66, 0.71, 0.79, 1 })
    for _, btn in ipairs(widget._buttons or {}) do
        if btn.glyph and not btn._isHover then
            btn.glyph:SetTextColor(btnIdle[1], btnIdle[2], btnIdle[3], 1)
        end
    end
end

--[[--------------------------------------------------------------------
    Thumb geometry

    The slider's min/max values are in scroll-content units (e.g. 0..scrollRange
    pixels for a ScrollFrame). The thumb texture SIZE along the scroll
    axis is computed from the ratio of visible to total content.
----------------------------------------------------------------------]]

local function computeThumbExtent(widget)
    local trackExtent = widget:GetTrackExtent()
    if trackExtent <= 0 then return widget._minThumbSize end
    local visible = widget._visibleExtent or 0
    local total = widget._totalExtent or 0
    if total <= 0 then return trackExtent end
    local ratio = visible / total
    local extent = math.floor(trackExtent * ratio + 0.5)
    return math.max(widget._minThumbSize, extent)
end

local function positionThumb(widget)
    local min, max = widget._min, widget._max
    local range = max - min
    local v = widget._value
    local trackExtent = widget:GetTrackExtent()
    local thumbExtent = widget._thumbExtent
    local movable = math.max(0, trackExtent - thumbExtent)
    local frac = (range > 0) and ((v - min) / range) or 0
    frac = math.max(0, math.min(1, frac))
    local pos = math.floor(frac * movable + 0.5)

    widget.thumb:ClearAllPoints()
    if isVertical(widget) then
        widget.thumb:SetPoint("TOP", widget.track, "TOP", 0, -pos)
        widget.thumb:SetWidth(widget._thickness - 2)
        widget.thumb:SetHeight(thumbExtent)
    else
        widget.thumb:SetPoint("LEFT", widget.track, "LEFT", pos, 0)
        widget.thumb:SetHeight(widget._thickness - 2)
        widget.thumb:SetWidth(thumbExtent)
    end
end

local function updateAutoHide(widget)
    if not widget._autoHide then return end
    if widget._totalExtent <= widget._visibleExtent + 1 then
        widget:Hide()
    else
        widget:Show()
    end
end

local function sliderValueFromMouse(widget, x, y)
    -- Translate mouse into a slider value based on the click position.
    local trackExtent = widget:GetTrackExtent()
    local thumbExtent = widget._thumbExtent
    local movable = math.max(1, trackExtent - thumbExtent)

    local pos
    if isVertical(widget) then
        local trackTop = widget.track:GetTop() or 0
        pos = math.max(0, math.min(movable, (trackTop - y) - thumbExtent / 2))
    else
        local trackLeft = widget.track:GetLeft() or 0
        pos = math.max(0, math.min(movable, (x - trackLeft) - thumbExtent / 2))
    end

    local frac = pos / movable
    return widget._min + frac * (widget._max - widget._min)
end

--[[--------------------------------------------------------------------
    End-button factory (chevron glyphs)
----------------------------------------------------------------------]]

local function createEndButton(widget, iconName, onClick)
    local btn = CreateFrame("Button", nil, widget)
    btn:SetSize(widget._thickness, widget._thickness + 4)
    local glyph = btn:CreateFontString(nil, "OVERLAY")
    if Fonts and Fonts.SetIconFont then
        Fonts:SetIconFont(glyph, widget._buttonSize, "")
    else
        glyph:SetFontObject("GameFontNormalSmall")
    end
    glyph:SetPoint("CENTER")
    glyph:SetText(Fonts and Fonts:Icon(iconName) or "")
    btn.glyph = glyph

    btn:SetScript("OnEnter", function(self)
        self._isHover = true
        local accent = GetColor("accent", { 0.95, 0.78, 0.30, 1 })
        self.glyph:SetTextColor(accent[1], accent[2], accent[3], 1)
    end)
    btn:SetScript("OnLeave", function(self)
        self._isHover = false
        local muted = GetColor("textMuted", { 0.66, 0.71, 0.79, 1 })
        self.glyph:SetTextColor(muted[1], muted[2], muted[3], 1)
    end)
    btn:SetScript("OnMouseDown", function(self)
        self.glyph:ClearAllPoints()
        self.glyph:SetPoint("CENTER", 0, -1)
    end)
    btn:SetScript("OnMouseUp", function(self)
        self.glyph:ClearAllPoints()
        self.glyph:SetPoint("CENTER")
    end)
    btn:SetScript("OnClick", function(self)
        if onClick then onClick() end
    end)
    return btn
end

--[[--------------------------------------------------------------------
    Widget methods
----------------------------------------------------------------------]]

local Methods = {}

function Methods:GetTrackExtent()
    if isVertical(self) then
        return self.track:GetHeight() or 0
    else
        return self.track:GetWidth() or 0
    end
end

function Methods:SetMinMaxValues(min, max)
    self._min, self._max = min, max
    if self._value < min then self._value = min
    elseif self._value > max then self._value = max end
    self:Refresh()
end

function Methods:GetValue()
    return self._value
end

function Methods:SetValue(v)
    v = math.max(self._min, math.min(self._max, v))
    if v == self._value then return end
    self._value = v
    positionThumb(self)
    if self._onChanged then pcall(self._onChanged, self, v) end
end

function Methods:RegisterOnChanged(fn)
    self._onChanged = fn
end

function Methods:SetExtents(visible, total)
    -- visible: size of the viewport along scroll axis (e.g. scrollFrame:GetHeight())
    -- total:   size of the scrollable content along scroll axis (e.g. content:GetHeight())
    self._visibleExtent = visible or 0
    self._totalExtent = total or 0
    self._thumbExtent = computeThumbExtent(self)
    -- Scroll range in value units = total - visible (how far you can scroll before hitting the bottom).
    local maxScroll = math.max(0, (self._totalExtent) - (self._visibleExtent))
    self._min = 0
    self._max = maxScroll
    self._value = math.max(0, math.min(maxScroll, self._value or 0))
    positionThumb(self)
    updateAutoHide(self)
end

function Methods:Refresh()
    self._thumbExtent = computeThumbExtent(self)
    positionThumb(self)
    applyColors(self)
    updateAutoHide(self)
end

function Methods:SetEnabled(enabled)
    self._enabled = enabled ~= false
    self:EnableMouse(self._enabled)
    if self.thumb then
        self.thumb:EnableMouse(self._enabled)
    end
end

--- Wire to a Blizzard ScrollFrame (VERTICAL only for now; horizontal
--- ScrollFrame setups are rare in this codebase).
--- Hides the ScrollFrame's built-in scrollbar if any.
function Methods:AttachTo(scrollFrame)
    if not scrollFrame then return end
    self._scrollFrame = scrollFrame

    -- Hide Blizzard's scrollbar chrome if this ScrollFrame was made
    -- with UIPanelScrollFrameTemplate.
    if scrollFrame.ScrollBar then
        scrollFrame.ScrollBar:Hide()
        scrollFrame.ScrollBar:SetAlpha(0)
        scrollFrame.ScrollBar:SetScript("OnShow", function(s) s:Hide() end)
    end
    if scrollFrame.ScrollUpButton then scrollFrame.ScrollUpButton:Hide() end
    if scrollFrame.ScrollDownButton then scrollFrame.ScrollDownButton:Hide() end

    local sync = function()
        local content = scrollFrame:GetScrollChild()
        local visible = isVertical(self) and (scrollFrame:GetHeight() or 0)
            or (scrollFrame:GetWidth() or 0)
        local total
        if content then
            total = isVertical(self) and (content:GetHeight() or 0)
                or (content:GetWidth() or 0)
        else
            total = visible
        end
        self:SetExtents(visible, total)
    end

    self:RegisterOnChanged(function(_, v)
        if isVertical(self) then
            scrollFrame:SetVerticalScroll(v)
        else
            scrollFrame:SetHorizontalScroll(v)
        end
    end)

    scrollFrame:HookScript("OnScrollRangeChanged", sync)
    scrollFrame:HookScript("OnSizeChanged", sync)
    scrollFrame:HookScript("OnShow", sync)

    -- Forward hover state so dragging with the cursor temporarily off
    -- the thumb still reads as "hovered" (keeps the thumb bright).
    if self._onScrollEnter then
        scrollFrame:HookScript("OnEnter", self._onScrollEnter)
        scrollFrame:HookScript("OnLeave", self._onScrollLeave)
    end

    -- Mouse wheel scroll on the ScrollFrame.
    scrollFrame:EnableMouseWheel(true)
    scrollFrame:HookScript("OnMouseWheel", function(_, delta)
        self:SetValue(self._value - delta * self._step)
    end)

    sync()
end

--[[--------------------------------------------------------------------
    Factory
----------------------------------------------------------------------]]

--- Create a themed scrollbar widget.
--- @param parent Frame
--- @param opts table|nil
--- @return Frame  widget (implements Methods)
function ns.CreateThemedScrollBar(parent, opts)
    opts = opts or {}
    local orientation = opts.orientation or "VERTICAL"
    local thickness = opts.thickness or DEFAULT_THICKNESS
    local step = opts.step or DEFAULT_STEP
    local showButtons = opts.showButtons == true
    local buttonSize = opts.buttonSize or DEFAULT_BUTTON_SIZE

    local bar = CreateFrame("Frame", nil, parent)
    bar._orientation = orientation
    bar._thickness = thickness
    bar._step = step
    bar._buttonSize = buttonSize
    bar._autoHide = opts.autoHide ~= false
    bar._minThumbSize = opts.minThumbSize or DEFAULT_MIN_THUMB
    bar._buttons = {}
    bar._min, bar._max, bar._value = 0, 0, 0
    bar._visibleExtent, bar._totalExtent = 0, 0
    bar._thumbExtent = bar._minThumbSize
    bar._enabled = true

    -- The bar frame itself has the track as a child so end-buttons can
    -- sit on either side of the track and the track can still be the
    -- mouse-click target for page-up/down.
    bar:SetSize(thickness, thickness)

    -- Track frame (click-to-page region)
    local track = CreateFrame("Button", nil, bar)
    bar.track = track

    local trackTex = track:CreateTexture(nil, "BACKGROUND")
    trackTex:SetPoint("TOPLEFT", (thickness - 3) / 2, -(thickness - 3) / 2)
    trackTex:SetPoint("BOTTOMRIGHT", -(thickness - 3) / 2, (thickness - 3) / 2)
    if orientation == "VERTICAL" then
        trackTex:SetPoint("TOPLEFT", (thickness - 3) / 2, 0)
        trackTex:SetPoint("BOTTOMRIGHT", -(thickness - 3) / 2, 0)
    else
        trackTex:SetPoint("TOPLEFT", 0, -(thickness - 3) / 2)
        trackTex:SetPoint("BOTTOMRIGHT", 0, (thickness - 3) / 2)
    end
    bar.trackTex = trackTex

    -- Thumb (draggable grip)
    local thumb = CreateFrame("Frame", nil, track)
    thumb:EnableMouse(true)
    thumb:SetFrameLevel(track:GetFrameLevel() + 2)
    local thumbTex = thumb:CreateTexture(nil, "OVERLAY")
    thumbTex:SetAllPoints()
    thumbTex:SetTexture("Interface\\Buttons\\WHITE8x8")
    bar.thumb = thumb
    bar.thumbTex = thumbTex

    -- End buttons (optional)
    if showButtons then
        local upIcon = orientation == "VERTICAL" and "chevron-up" or "chevron-left"
        local downIcon = orientation == "VERTICAL" and "chevron-down" or "chevron-right"
        local upBtn = createEndButton(bar, upIcon, function()
            bar:SetValue(bar._value - step)
        end)
        local downBtn = createEndButton(bar, downIcon, function()
            bar:SetValue(bar._value + step)
        end)
        bar._buttons = { upBtn, downBtn }

        if orientation == "VERTICAL" then
            upBtn:SetPoint("TOP", bar, "TOP", 0, 0)
            downBtn:SetPoint("BOTTOM", bar, "BOTTOM", 0, 0)
            track:SetPoint("TOPLEFT", upBtn, "BOTTOMLEFT", 0, -2)
            track:SetPoint("BOTTOMRIGHT", downBtn, "TOPRIGHT", 0, 2)
        else
            upBtn:SetPoint("LEFT", bar, "LEFT", 0, 0)
            downBtn:SetPoint("RIGHT", bar, "RIGHT", 0, 0)
            track:SetPoint("TOPLEFT", upBtn, "TOPRIGHT", 2, 0)
            track:SetPoint("BOTTOMRIGHT", downBtn, "BOTTOMLEFT", -2, 0)
        end
    else
        track:SetAllPoints(bar)
    end

    -- Mixin methods
    for k, v in pairs(Methods) do bar[k] = v end

    --[[--------------------------------------------------------------------
        Thumb drag
    ----------------------------------------------------------------------]]
    thumb:SetScript("OnMouseDown", function(self, btn)
        if btn ~= "LeftButton" or not bar._enabled then return end
        bar._dragging = true
        bar._dragStartValue = bar._value
        local _, y = GetCursorPosition()
        local x
        x, y = GetCursorPosition()
        bar._dragStartCursor = isVertical(bar) and y or x
        self:SetScript("OnUpdate", function()
            if not bar._dragging then self:SetScript("OnUpdate", nil) return end
            local cx, cy = GetCursorPosition()
            local scale = UIParent:GetEffectiveScale()
            local delta = (isVertical(bar) and (bar._dragStartCursor - cy) or (cx - bar._dragStartCursor)) / scale
            local trackExtent = bar:GetTrackExtent()
            local movable = math.max(1, trackExtent - bar._thumbExtent)
            local range = bar._max - bar._min
            bar:SetValue(bar._dragStartValue + (delta / movable) * range)
        end)
    end)
    thumb:SetScript("OnMouseUp", function(self)
        bar._dragging = false
        self:SetScript("OnUpdate", nil)
    end)

    --[[--------------------------------------------------------------------
        Click-on-track: page up or down toward the click position
    ----------------------------------------------------------------------]]
    track:RegisterForClicks("LeftButtonUp")
    track:SetScript("OnClick", function(_, mouseButton)
        if mouseButton ~= "LeftButton" or not bar._enabled then return end
        local cx, cy = GetCursorPosition()
        local scale = UIParent:GetEffectiveScale()
        local target = sliderValueFromMouse(bar, cx / scale, cy / scale)
        bar:SetValue(target)
    end)

    --[[--------------------------------------------------------------------
        Hover detection: the hover color applies while the cursor is over
        the track, thumb, or parent scroll area (set via AttachTo).
    ----------------------------------------------------------------------]]
    local function enterHover()
        if bar._isHover then return end
        bar._isHover = true
        local from = GetColor("borderStrong", { 0.28, 0.33, 0.43, 1 })
        local to = GetColor("accent", { 0.95, 0.78, 0.30, 1 })
        tweenColor(bar, bar.thumbTex, from, to, 0.80, 1)
    end
    local function leaveHover()
        if not bar._isHover then return end
        if bar.thumb:IsMouseOver() or bar.track:IsMouseOver()
            or (bar._scrollFrame and bar._scrollFrame:IsMouseOver()) then
            return
        end
        bar._isHover = false
        local from = GetColor("accent", { 0.95, 0.78, 0.30, 1 })
        local to = GetColor("borderStrong", { 0.28, 0.33, 0.43, 1 })
        tweenColor(bar, bar.thumbTex, from, to, 1, 0.80)
    end
    bar.track:HookScript("OnEnter", enterHover)
    bar.track:HookScript("OnLeave", leaveHover)
    thumb:HookScript("OnEnter", enterHover)
    thumb:HookScript("OnLeave", leaveHover)

    -- Forward hover-enter from an attached scroll frame (wired in AttachTo
    -- so dragging with the cursor temporarily off the thumb still reads
    -- as hovered).
    bar._onScrollEnter = enterHover
    bar._onScrollLeave = leaveHover

    registered[bar] = true
    applyColors(bar)
    positionThumb(bar)

    return bar
end

--- Compatibility shim for the previous API: re-skin an existing
--- UIPanelScrollFrameTemplate ScrollFrame with a themed scrollbar.
--- @param scrollFrame ScrollFrame
--- @param opts table|nil
--- @return Frame themed bar
function ns.ApplyThemedScrollBar(scrollFrame, opts)
    if not scrollFrame then return end
    opts = opts or {}

    -- Create a new themed bar parented to the ScrollFrame's parent,
    -- anchored to the ScrollFrame's right side (or bottom for H).
    local parent = scrollFrame:GetParent() or UIParent
    local orientation = opts.orientation or "VERTICAL"
    local thickness = opts.thickness or DEFAULT_THICKNESS

    local bar = ns.CreateThemedScrollBar(parent, opts)
    bar:ClearAllPoints()
    if orientation == "VERTICAL" then
        bar:SetPoint("TOPRIGHT", scrollFrame, "TOPRIGHT", thickness + 2, 0)
        bar:SetPoint("BOTTOMRIGHT", scrollFrame, "BOTTOMRIGHT", thickness + 2, 0)
        bar:SetWidth(thickness)
    else
        bar:SetPoint("BOTTOMLEFT", scrollFrame, "BOTTOMLEFT", 0, -(thickness + 2))
        bar:SetPoint("BOTTOMRIGHT", scrollFrame, "BOTTOMRIGHT", 0, -(thickness + 2))
        bar:SetHeight(thickness)
    end
    bar:AttachTo(scrollFrame)
    return bar
end

--- Convenience factory: create a ScrollFrame + content child + themed
--- scrollbar that scrolls it. Returns the three frames so the caller
--- can anchor their own content into `content`.
--- @param parent Frame
--- @param opts table|nil
function ns.CreateScrollableFrame(parent, opts)
    opts = opts or {}
    local thickness = opts.thickness or DEFAULT_THICKNESS

    local scrollFrame = CreateFrame("ScrollFrame", nil, parent)
    local content = CreateFrame("Frame", nil, scrollFrame)
    content:SetSize(opts.contentWidth or 1, opts.contentHeight or 1)
    scrollFrame:SetScrollChild(content)
    scrollFrame:EnableMouseWheel(true)

    local bar = ns.CreateThemedScrollBar(parent, opts)
    bar:ClearAllPoints()
    bar:SetPoint("TOPRIGHT", scrollFrame, "TOPRIGHT", thickness + 2, 0)
    bar:SetPoint("BOTTOMRIGHT", scrollFrame, "BOTTOMRIGHT", thickness + 2, 0)
    bar:SetWidth(thickness)
    bar:AttachTo(scrollFrame)

    return { scrollFrame = scrollFrame, content = content, scrollBar = bar }
end

--- Re-apply theme colors to every live themed scrollbar.
function ns.RefreshThemedScrollBars()
    for bar in pairs(registered) do
        if bar and type(bar.Refresh) == "function" then
            bar:Refresh()
        end
    end
end
