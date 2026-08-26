--[[--------------------------------------------------------------------
    Loothing - Loot Council Addon for WoW 12.0+
    Skinning - Frame skinning, combat minimize, scale, Escape-to-close
----------------------------------------------------------------------]]

local _, ns = ...
local Loolib = LibStub("Loolib")
local Loothing = ns.Addon
local StyleUtil = Loolib.StyleUtil
local AnimationUtil = Loolib.AnimationUtil

-- Animation tuning for button state transitions.
local BUTTON_HOVER_DURATION = 0.12
local BUTTON_PRESS_SCALE = 0.96
local BUTTON_PRESS_DOWN_DURATION = 0.06
local BUTTON_PRESS_UP_DURATION = 0.09

local function CopyTable(source)
    if type(source) ~= "table" then
        return source
    end

    local copy = {}
    for key, value in pairs(source) do
        copy[key] = type(value) == "table" and CopyTable(value) or value
    end
    return copy
end

local function MergeTable(target, source)
    if type(target) ~= "table" or type(source) ~= "table" then
        return target
    end

    for key, value in pairs(source) do
        if type(value) == "table" then
            if type(target[key]) ~= "table" then
                target[key] = {}
            end
            MergeTable(target[key], value)
        else
            target[key] = value
        end
    end

    return target
end

--[[--------------------------------------------------------------------
    Skin Presets
----------------------------------------------------------------------]]

ns.SkinPresets = ns.SkinPresets or {
    Default = {
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        tile = false,
        tileSize = 0,
        edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 },
        bgColor = { 0.050, 0.058, 0.074, 0.97 },
        borderColor = { 0.180, 0.216, 0.278, 1.0 },
        colors = {
            frame = { 0.050, 0.058, 0.074, 0.97 },
            header = { 0.072, 0.082, 0.108, 0.98 },
            panel = { 0.068, 0.078, 0.104, 0.94 },
            panelAlt = { 0.085, 0.096, 0.126, 0.92 },
            panelInset = { 0.035, 0.041, 0.055, 0.92 },
            border = { 0.180, 0.216, 0.278, 1.0 },
            borderStrong = { 0.286, 0.337, 0.435, 1.0 },
            accent = { 0.945, 0.775, 0.298, 1.0 },
            accentSoft = { 0.945, 0.775, 0.298, 0.18 },
            accentCool = { 0.404, 0.647, 0.929, 1.0 },
            accentWarm = { 0.400, 0.860, 0.440, 1.0 },
            success = { 0.353, 0.808, 0.561, 1.0 },
            warning = { 0.945, 0.775, 0.298, 1.0 },
            danger = { 0.882, 0.396, 0.396, 1.0 },
            text = { 0.965, 0.972, 0.992, 1.0 },
            textMuted = { 0.658, 0.705, 0.792, 1.0 },
            textSubtle = { 0.520, 0.568, 0.647, 1.0 },
            row = { 0.082, 0.093, 0.122, 0.70 },
            rowAlt = { 0.062, 0.071, 0.095, 0.55 },
            rowHover = { 0.126, 0.150, 0.204, 0.72 },
            rowSelected = { 0.150, 0.176, 0.239, 0.84 },
        },
        fontObjects = {
            title = "GameFontNormalLarge",
            titleHuge = "GameFontNormalHuge",
            header = "GameFontNormal",
            body = "GameFontNormal",
            bodySmall = "GameFontNormalSmall",
            highlight = "GameFontHighlight",
            highlightSmall = "GameFontHighlightSmall",
        },
        spacing = {
            xs = 4,
            sm = 8,
            md = 12,
            lg = 16,
            xl = 24,
        },
        layout = {
            outerPadding = 16,
            tabHeight = 32,
            headerHeight = 42,
            contentBottom = 16,
            panelInset = 8,
            footerInset = 8,
        },
    },
    Dark = {
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        tile = false,
        tileSize = 0,
        edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 },
        bgColor = { 0.035, 0.039, 0.050, 0.98 },
        borderColor = { 0.145, 0.173, 0.220, 1.0 },
        colors = {
            frame = { 0.035, 0.039, 0.050, 0.98 },
            header = { 0.048, 0.054, 0.070, 0.98 },
            panel = { 0.050, 0.056, 0.072, 0.95 },
            panelAlt = { 0.062, 0.070, 0.090, 0.92 },
            panelInset = { 0.022, 0.026, 0.034, 0.94 },
            border = { 0.145, 0.173, 0.220, 1.0 },
            borderStrong = { 0.235, 0.274, 0.345, 1.0 },
            accent = { 0.420, 0.640, 0.945, 1.0 },
            accentSoft = { 0.420, 0.640, 0.945, 0.18 },
            accentCool = { 0.420, 0.790, 0.945, 1.0 },
            accentWarm = { 0.360, 0.800, 0.400, 1.0 },
            success = { 0.318, 0.706, 0.510, 1.0 },
            warning = { 0.902, 0.700, 0.298, 1.0 },
            danger = { 0.835, 0.349, 0.349, 1.0 },
            text = { 0.930, 0.950, 0.985, 1.0 },
            textMuted = { 0.612, 0.668, 0.760, 1.0 },
            textSubtle = { 0.474, 0.529, 0.615, 1.0 },
            row = { 0.060, 0.068, 0.088, 0.72 },
            rowAlt = { 0.046, 0.052, 0.068, 0.58 },
            rowHover = { 0.108, 0.126, 0.170, 0.76 },
            rowSelected = { 0.128, 0.152, 0.208, 0.86 },
        },
        fontObjects = {
            title = "GameFontNormalLarge",
            titleHuge = "GameFontNormalHuge",
            header = "GameFontNormal",
            body = "GameFontNormal",
            bodySmall = "GameFontNormalSmall",
            highlight = "GameFontHighlight",
            highlightSmall = "GameFontHighlightSmall",
        },
        spacing = {
            xs = 4,
            sm = 8,
            md = 12,
            lg = 16,
            xl = 24,
        },
        layout = {
            outerPadding = 16,
            tabHeight = 32,
            headerHeight = 42,
            contentBottom = 16,
            panelInset = 8,
            footerInset = 8,
        },
    },
    Minimal = {
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        tile = false,
        tileSize = 0,
        edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 },
        bgColor = { 0.046, 0.052, 0.066, 0.88 },
        borderColor = { 0.122, 0.145, 0.188, 0.88 },
        colors = {
            frame = { 0.046, 0.052, 0.066, 0.90 },
            header = { 0.052, 0.060, 0.078, 0.92 },
            panel = { 0.056, 0.064, 0.082, 0.90 },
            panelAlt = { 0.066, 0.075, 0.096, 0.88 },
            panelInset = { 0.030, 0.035, 0.045, 0.92 },
            border = { 0.122, 0.145, 0.188, 0.88 },
            borderStrong = { 0.215, 0.250, 0.322, 0.96 },
            accent = { 0.352, 0.705, 0.965, 1.0 },
            accentSoft = { 0.352, 0.705, 0.965, 0.16 },
            accentCool = { 0.490, 0.835, 0.965, 1.0 },
            accentWarm = { 0.420, 0.870, 0.460, 1.0 },
            success = { 0.345, 0.790, 0.522, 1.0 },
            warning = { 0.948, 0.760, 0.340, 1.0 },
            danger = { 0.882, 0.402, 0.402, 1.0 },
            text = { 0.970, 0.975, 0.985, 1.0 },
            textMuted = { 0.700, 0.742, 0.812, 1.0 },
            textSubtle = { 0.560, 0.602, 0.678, 1.0 },
            row = { 0.076, 0.086, 0.110, 0.62 },
            rowAlt = { 0.058, 0.066, 0.085, 0.50 },
            rowHover = { 0.118, 0.142, 0.188, 0.66 },
            rowSelected = { 0.142, 0.172, 0.224, 0.78 },
        },
        fontObjects = {
            title = "GameFontNormalLarge",
            titleHuge = "GameFontNormalHuge",
            header = "GameFontNormal",
            body = "GameFontNormal",
            bodySmall = "GameFontNormalSmall",
            highlight = "GameFontHighlight",
            highlightSmall = "GameFontHighlightSmall",
        },
        spacing = {
            xs = 3,
            sm = 6,
            md = 10,
            lg = 14,
            xl = 20,
        },
        layout = {
            outerPadding = 14,
            tabHeight = 30,
            headerHeight = 40,
            contentBottom = 14,
            panelInset = 6,
            footerInset = 6,
        },
    },
}
Loothing.SkinPresets = ns.SkinPresets

ns.SkinAccentPresets = ns.SkinAccentPresets or {
    Amber = {
        accent = { 0.945, 0.775, 0.298, 1.0 },
        accentSoft = { 0.945, 0.775, 0.298, 0.18 },
        accentCool = { 0.404, 0.647, 0.929, 1.0 },
        accentWarm = { 0.400, 0.860, 0.440, 1.0 },
        warning = { 0.945, 0.775, 0.298, 1.0 },
    },
    Azure = {
        accent = { 0.388, 0.682, 0.965, 1.0 },
        accentSoft = { 0.388, 0.682, 0.965, 0.18 },
        accentCool = { 0.518, 0.862, 0.988, 1.0 },
        accentWarm = { 0.380, 0.840, 0.420, 1.0 },
        warning = { 0.965, 0.760, 0.352, 1.0 },
    },
    Emerald = {
        accent = { 0.353, 0.808, 0.561, 1.0 },
        accentSoft = { 0.353, 0.808, 0.561, 0.18 },
        accentCool = { 0.404, 0.859, 0.769, 1.0 },
        accentWarm = { 0.440, 0.880, 0.480, 1.0 },
        warning = { 0.945, 0.775, 0.298, 1.0 },
    },
    Crimson = {
        accent = { 0.882, 0.396, 0.396, 1.0 },
        accentSoft = { 0.882, 0.396, 0.396, 0.18 },
        accentCool = { 0.918, 0.592, 0.592, 1.0 },
        accentWarm = { 0.420, 0.850, 0.450, 1.0 },
        warning = { 0.945, 0.775, 0.298, 1.0 },
    },
}

ns.SkinDensityPresets = ns.SkinDensityPresets or {
    Compact = {
        spacing = { xs = 2, sm = 6, md = 10, lg = 14, xl = 20 },
        layout = {
            outerPadding = 12,
            tabHeight = 28,
            headerHeight = 40,
            contentBottom = 12,
            panelInset = 6,
            footerInset = 6,
        },
    },
    Comfortable = {
        spacing = { xs = 4, sm = 8, md = 12, lg = 16, xl = 24 },
        layout = {
            outerPadding = 16,
            tabHeight = 32,
            headerHeight = 42,
            contentBottom = 16,
            panelInset = 8,
            footerInset = 8,
        },
    },
    Spacious = {
        spacing = { xs = 6, sm = 10, md = 14, lg = 20, xl = 28 },
        layout = {
            outerPadding = 20,
            tabHeight = 36,
            headerHeight = 46,
            contentBottom = 20,
            panelInset = 10,
            footerInset = 10,
        },
    },
}

--- Create a themed button using BackdropTemplate instead of UIPanelButtonTemplate.
-- Sets up font objects so SetText() renders immediately. Does not call
-- StylePlainButton — callers should do that during their styling pass.
-- @param parent Frame
-- @param name string|nil  Optional global name for the button.
-- @return Button
function ns.CreateThemedButton(parent, name)
    local btn = CreateFrame("Button", name, parent, "BackdropTemplate")
    btn:SetNormalFontObject(GameFontNormal)
    btn:SetHighlightFontObject(GameFontHighlight)
    btn:SetDisabledFontObject(GameFontDisable)
    return btn
end

--[[--------------------------------------------------------------------
    SkinningMixin

    Provides:
    - Frame skin application (backdrop, colors)
    - Per-frame position/scale/color persistence in db.UI[frameName]
    - Ctrl+Scroll to adjust frame scale
    - Combat minimize/maximize
    - Escape-to-close registration
----------------------------------------------------------------------]]

local SkinningMixin = ns.SkinningMixin or {}
ns.SkinningMixin = SkinningMixin

--- Managed frames (for combat minimize/maximize)
local managedFrames = {}
local combatFrame = nil

--- Registry of all buttons styled via StylePlainButton, keyed by button.
-- Allows RefreshTheme to re-style every button when texture set or accent changes.
local styledButtons = setmetatable({}, { __mode = "k" })

local function ApplyColorToFontString(fontString, color)
    if fontString and color and fontString.SetTextColor then
        fontString:SetTextColor(color[1], color[2], color[3], color[4] or 1)
    end
end

local function ApplyColorToTexture(texture, color)
    if texture and color and texture.SetColorTexture then
        texture:SetColorTexture(color[1], color[2], color[3], color[4] or 1)
    end
end

function SkinningMixin:GetSkinData(skinName)
    local resolvedSkin = skinName or self:GetCurrentSkin()
    local resolvedAccent = self:GetCurrentAccent()
    local resolvedDensity = self:GetCurrentDensity()
    local cacheKey = table.concat({ resolvedSkin or "Default", resolvedAccent or "Amber", resolvedDensity or "Comfortable" }, ":")

    if self._skinCacheKey == cacheKey and self._skinCache then
        return self._skinCache
    end

    local baseSkin = Loothing.SkinPresets[resolvedSkin] or Loothing.SkinPresets.Default
    local skin = CopyTable(baseSkin)
    local accentPreset = ns.SkinAccentPresets[resolvedAccent]
    local densityPreset = ns.SkinDensityPresets[resolvedDensity]

    if accentPreset then
        skin.colors = skin.colors or {}
        MergeTable(skin.colors, accentPreset)
    end

    if densityPreset then
        skin.spacing = skin.spacing or {}
        skin.layout = skin.layout or {}
        MergeTable(skin.spacing, densityPreset.spacing or {})
        MergeTable(skin.layout, densityPreset.layout or {})
    end

    self._skinCacheKey = cacheKey
    self._skinCache = skin
    return skin
end

function SkinningMixin:GetColor(colorKey, fallback, skinName)
    local skin = self:GetSkinData(skinName)
    local colors = skin and skin.colors
    if colors and colors[colorKey] then
        return colors[colorKey]
    end
    local defaultColors = Loothing.SkinPresets.Default and Loothing.SkinPresets.Default.colors
    if defaultColors and defaultColors[colorKey] then
        return defaultColors[colorKey]
    end
    return fallback or skin.borderColor or { 1, 1, 1, 1 }
end

function SkinningMixin:GetSpacing(spacingKey, fallback, skinName)
    local skin = self:GetSkinData(skinName)
    local spacing = skin and skin.spacing
    if spacing and spacing[spacingKey] then
        return spacing[spacingKey]
    end
    local defaultSpacing = Loothing.SkinPresets.Default and Loothing.SkinPresets.Default.spacing
    if defaultSpacing and defaultSpacing[spacingKey] then
        return defaultSpacing[spacingKey]
    end
    return fallback or 8
end

function SkinningMixin:GetLayoutValue(layoutKey, fallback, skinName)
    local skin = self:GetSkinData(skinName)
    local layout = skin and skin.layout
    if layout and layout[layoutKey] ~= nil then
        return layout[layoutKey]
    end

    local defaultLayout = Loothing.SkinPresets.Default and Loothing.SkinPresets.Default.layout
    if defaultLayout and defaultLayout[layoutKey] ~= nil then
        return defaultLayout[layoutKey]
    end

    return fallback
end

function SkinningMixin:GetCurrentAccent()
    if Loothing.Settings then
        return Loothing.Settings:Get("frame.accent") or "Amber"
    end
    return "Amber"
end

function SkinningMixin:GetCurrentDensity()
    if Loothing.Settings then
        return Loothing.Settings:Get("frame.density") or "Comfortable"
    end
    return "Comfortable"
end

function SkinningMixin:GetThemeNames()
    local names = {}
    for name in pairs(Loothing.SkinPresets) do
        names[#names + 1] = name
    end
    table.sort(names)
    return names
end

function SkinningMixin:GetAccentNames()
    local names = {}
    for name in pairs(ns.SkinAccentPresets) do
        names[#names + 1] = name
    end
    table.sort(names)
    return names
end

function SkinningMixin:GetDensityNames()
    local names = {}
    for name in pairs(ns.SkinDensityPresets) do
        names[#names + 1] = name
    end
    table.sort(names)
    return names
end

function SkinningMixin:InvalidateSkinCache()
    self._skinCacheKey = nil
    self._skinCache = nil
end

function SkinningMixin:SyncLoolibTheme(themeName)
    if not Loolib.ThemeManager or not Loolib.ThemeManager.SetActiveTheme then
        return
    end

    local targetTheme = themeName or self:GetCurrentSkin()
    local success = pcall(Loolib.ThemeManager.SetActiveTheme, Loolib.ThemeManager, targetTheme)
    if not success then
        pcall(Loolib.ThemeManager.SetActiveTheme, Loolib.ThemeManager, "Default")
    end
end

function SkinningMixin:StyleText(fontString, fontKey, colorKey)
    if not fontString then return end

    local skin = self:GetSkinData()
    local fontObjects = skin.fontObjects or {}
    local fontObject = fontObjects[fontKey or "body"]
    if not fontObject and Loothing.SkinPresets.Default and Loothing.SkinPresets.Default.fontObjects then
        fontObject = Loothing.SkinPresets.Default.fontObjects[fontKey or "body"]
    end

    if StyleUtil then
        StyleUtil.ApplyText(fontString, fontKey or "body", nil)
    elseif fontObject and fontString.SetFontObject then
        fontString:SetFontObject(fontObject)
    end

    ApplyColorToFontString(fontString, self:GetColor(colorKey or "text"))
end

function SkinningMixin:CreateDivider(parent, orientation, colorKey, thickness)
    if not parent or not parent.CreateTexture then
        return nil
    end

    if StyleUtil then
        return StyleUtil.CreateDivider(parent, {
            orientation = orientation,
            color = self:GetColor(colorKey or "border"),
            thickness = thickness or 1,
        })
    end

    local divider = parent:CreateTexture(nil, "ARTWORK")
    ApplyColorToTexture(divider, self:GetColor(colorKey or "border"))
    if orientation == "vertical" then
        divider:SetWidth(thickness or 1)
    else
        divider:SetHeight(thickness or 1)
    end
    return divider
end

function SkinningMixin:StyleSurface(frame, variant)
    if not frame or not frame.SetBackdrop then return end

    local bgColorKey = "panel"
    local borderColorKey = "border"

    if variant == "frame" then
        bgColorKey = "frame"
    elseif variant == "header" then
        bgColorKey = "header"
    elseif variant == "inset" then
        bgColorKey = "panelInset"
    elseif variant == "alt" then
        bgColorKey = "panelAlt"
        borderColorKey = "borderStrong"
    end

    frame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        tile = false,
        edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    frame:SetBackdropColor(unpack(self:GetColor(bgColorKey)))
    frame:SetBackdropBorderColor(unpack(self:GetColor(borderColorKey)))
end

local function GetButtonFontString(button)
    if button and button.GetFontString then
        return button:GetFontString()
    end
    if button then
        return button.Text or button.text or button.label
    end
    return nil
end

function SkinningMixin:GetButtonVariantPalette(variant)
    local palettes = {
        default = {
            bgColorKey = "accentSoft",
            hoverBgColorKey = "accent",
            pressedBgColorKey = "accentCool",
            borderColorKey = "accent",
            hoverBorderColorKey = "accent",
            pressedBorderColorKey = "accent",
            textColorKey = "text",
            -- Hover/press backgrounds switch to the full `accent` / `accentCool`
            -- colors, which are bright on every theme (amber, emerald, blue,
            -- etc.). Near-white `text` on those backgrounds becomes unreadable,
            -- so invert to `panel` (dark) — matching primary/success/warning/danger.
            hoverTextColorKey = "panel",
            pressedTextColorKey = "panel",
            disabledTextColorKey = "textSubtle",
        },
        primary = {
            bgColorKey = "accentSoft",
            hoverBgColorKey = "accent",
            pressedBgColorKey = "accentCool",
            borderColorKey = "accent",
            hoverBorderColorKey = "accent",
            pressedBorderColorKey = "accentCool",
            textColorKey = "text",
            hoverTextColorKey = "panel",
            pressedTextColorKey = "panel",
            disabledTextColorKey = "textSubtle",
        },
        success = {
            bgColorKey = "panelAlt",
            hoverBgColorKey = "success",
            pressedBgColorKey = "panelInset",
            borderColorKey = "success",
            hoverBorderColorKey = "success",
            pressedBorderColorKey = "success",
            textColorKey = "success",
            hoverTextColorKey = "panel",
            pressedTextColorKey = "panel",
            disabledTextColorKey = "textSubtle",
        },
        warning = {
            bgColorKey = "panelAlt",
            hoverBgColorKey = "warning",
            pressedBgColorKey = "panelInset",
            borderColorKey = "warning",
            hoverBorderColorKey = "warning",
            pressedBorderColorKey = "warning",
            textColorKey = "warning",
            hoverTextColorKey = "panel",
            pressedTextColorKey = "panel",
            disabledTextColorKey = "textSubtle",
        },
        danger = {
            bgColorKey = "panelAlt",
            hoverBgColorKey = "danger",
            pressedBgColorKey = "panelInset",
            borderColorKey = "danger",
            hoverBorderColorKey = "danger",
            pressedBorderColorKey = "danger",
            textColorKey = "danger",
            hoverTextColorKey = "panel",
            pressedTextColorKey = "panel",
            disabledTextColorKey = "textSubtle",
        },
        ghost = {
            bgColorKey = "panelInset",
            hoverBgColorKey = "panelAlt",
            pressedBgColorKey = "panelInset",
            borderColorKey = "border",
            hoverBorderColorKey = "borderStrong",
            pressedBorderColorKey = "border",
            textColorKey = "textMuted",
            hoverTextColorKey = "text",
            pressedTextColorKey = "textMuted",
            disabledTextColorKey = "textSubtle",
        },
    }

    return palettes[variant or "default"] or palettes.default
end

function SkinningMixin:RefreshButtonVisualState(button)
    if not button then
        return
    end

    -- Stop any in-flight hover/press tween so the snap actually wins.
    -- Without this, calling RefreshButtonVisualState during theme refresh
    -- or OnEnable/OnDisable/OnShow would write the target colors, then be
    -- immediately overwritten by the next animation tick.
    if button._ltColorGroup then button._ltColorGroup:Stop() end
    if button._ltPressGroup then
        button._ltPressGroup:Stop()
        -- Stopping mid press-tween freezes the button at a partial scale
        -- (Award/Submit-style buttons that disable themselves in OnClick
        -- hit this every time). Snap back to the recorded base scale.
        if button._ltBaseScale and button.SetScale then
            button:SetScale(button._ltBaseScale)
        end
    end

    local palette = self:GetButtonVariantPalette(button.ltButtonVariant)
    local disabled = button.IsEnabled and not button:IsEnabled()
    local hovered = not disabled and button.IsMouseOver and button:IsMouseOver()
    local pressed = not disabled and button.GetButtonState and button:GetButtonState() == "PUSHED"

    local bgColorKey = disabled and "panelInset" or palette.bgColorKey
    local borderColorKey = disabled and "border" or palette.borderColorKey
    local textColorKey = disabled and (palette.disabledTextColorKey or "textSubtle") or palette.textColorKey

    if hovered then
        bgColorKey = palette.hoverBgColorKey or bgColorKey
        borderColorKey = palette.hoverBorderColorKey or borderColorKey
        textColorKey = palette.hoverTextColorKey or textColorKey
    end
    if pressed then
        bgColorKey = palette.pressedBgColorKey or bgColorKey
        borderColorKey = palette.pressedBorderColorKey or borderColorKey
        textColorKey = palette.pressedTextColorKey or textColorKey
    end

    if button.SetBackdropColor then
        button:SetBackdropColor(unpack(self:GetColor(bgColorKey)))
    end
    if button.SetBackdropBorderColor then
        button:SetBackdropBorderColor(unpack(self:GetColor(borderColorKey)))
    end

    ApplyColorToFontString(GetButtonFontString(button), self:GetColor(textColorKey))
end

--- Resolve the target backdrop/border/text colors for a button in its
--- current interaction state (hover/press/disabled). Returns three color
--- tables: bg, border, text. Used by AnimateButtonState to compute tween
--- targets without duplicating the palette-resolve logic.
function SkinningMixin:ResolveButtonStateColors(button)
    local palette = self:GetButtonVariantPalette(button.ltButtonVariant)
    local disabled = button.IsEnabled and not button:IsEnabled()
    local hovered = not disabled and button.IsMouseOver and button:IsMouseOver()
    local pressed = not disabled and button.GetButtonState and button:GetButtonState() == "PUSHED"

    local bgColorKey = disabled and "panelInset" or palette.bgColorKey
    local borderColorKey = disabled and "border" or palette.borderColorKey
    local textColorKey = disabled and (palette.disabledTextColorKey or "textSubtle") or palette.textColorKey

    if hovered then
        bgColorKey = palette.hoverBgColorKey or bgColorKey
        borderColorKey = palette.hoverBorderColorKey or borderColorKey
        textColorKey = palette.hoverTextColorKey or textColorKey
    end
    if pressed then
        bgColorKey = palette.pressedBgColorKey or bgColorKey
        borderColorKey = palette.pressedBorderColorKey or borderColorKey
        textColorKey = palette.pressedTextColorKey or textColorKey
    end

    return self:GetColor(bgColorKey), self:GetColor(borderColorKey), self:GetColor(textColorKey)
end

--- Tween a button's colors toward its current-state target. Falls back to
--- RefreshButtonVisualState (snap) when AnimationUtil isn't loaded or the
--- button isn't visible.
function SkinningMixin:AnimateButtonState(button)
    if not button then return end
    if not AnimationUtil or not button:IsVisible() then
        return self:RefreshButtonVisualState(button)
    end

    local toBg, toBorder, toText = self:ResolveButtonStateColors(button)
    local fontString = GetButtonFontString(button)

    local function readColor(getter, holder, fallback)
        if type(getter) ~= "function" then
            return { fallback[1] or 0, fallback[2] or 0, fallback[3] or 0, fallback[4] or 1 }
        end
        local r, g, b, a = getter(holder)
        if r == nil then
            return { fallback[1] or 0, fallback[2] or 0, fallback[3] or 0, fallback[4] or 1 }
        end
        return { r, g, b, a or 1 }
    end

    local fromBg = readColor(button.GetBackdropColor, button, toBg)
    local fromBorder = readColor(button.GetBackdropBorderColor, button, toBorder)
    local fromText = fontString and readColor(fontString.GetTextColor, fontString, toText) or nil

    if button._ltColorGroup then button._ltColorGroup:Stop() end

    local group = AnimationUtil.CreateGroup(button)
    if button.SetBackdropColor then
        group:CreateAnimation("color", {
            target = button,
            sink = "backdropColor",
            from = fromBg,
            to = { toBg[1], toBg[2], toBg[3], toBg[4] or 1 },
            duration = BUTTON_HOVER_DURATION,
            easing = "outQuad",
        })
    end
    if button.SetBackdropBorderColor then
        group:CreateAnimation("color", {
            target = button,
            sink = "backdropBorderColor",
            from = fromBorder,
            to = { toBorder[1], toBorder[2], toBorder[3], toBorder[4] or 1 },
            duration = BUTTON_HOVER_DURATION,
            easing = "outQuad",
        })
    end
    if fontString and fromText then
        group:CreateAnimation("color", {
            target = fontString,
            sink = "textColor",
            from = fromText,
            to = { toText[1], toText[2], toText[3], toText[4] or 1 },
            duration = BUTTON_HOVER_DURATION,
            easing = "outQuad",
        })
    end
    button._ltColorGroup = group
    group:Play()
end

--- Play a press-down / press-up scale pulse on a button.
function SkinningMixin:AnimateButtonPress(button, pressed)
    if not button or not AnimationUtil or type(button.GetScale) ~= "function" then return end
    local current = button:GetScale() or 1
    -- If a persistent uiScale is set, we tween relative to it so we always return to the same size.
    if not button._ltBaseScale then
        button._ltBaseScale = current
    end
    local base = button._ltBaseScale
    local target = pressed and (base * BUTTON_PRESS_SCALE) or base

    if button._ltPressGroup then button._ltPressGroup:Stop() end
    local group = AnimationUtil.CreateGroup(button)
    group:CreateAnimation("scale", {
        target = button,
        from = current,
        to = target,
        duration = pressed and BUTTON_PRESS_DOWN_DURATION or BUTTON_PRESS_UP_DURATION,
        easing = pressed and "outQuad" or "outBack",
    })
    button._ltPressGroup = group
    group:Play()
end

function SkinningMixin:EnsureButtonStateHooks(button)
    if not button or button._ltButtonStateHooked or not button.HookScript then
        return
    end

    button._ltButtonStateHooked = true

    -- Tween on interaction events so hover/press feel fluid. Snap for
    -- non-interaction events (Enable/Disable/Show) because those are
    -- typically tied to theme refreshes or state changes the user doesn't
    -- "watch" transition.
    button:HookScript("OnEnter", function(btn)
        SkinningMixin:AnimateButtonState(btn)
    end)
    button:HookScript("OnLeave", function(btn)
        SkinningMixin:AnimateButtonState(btn)
    end)
    button:HookScript("OnMouseDown", function(btn)
        SkinningMixin:AnimateButtonState(btn)
        SkinningMixin:AnimateButtonPress(btn, true)
    end)
    button:HookScript("OnMouseUp", function(btn)
        SkinningMixin:AnimateButtonState(btn)
        SkinningMixin:AnimateButtonPress(btn, false)
    end)
    button:HookScript("OnEnable", function(btn)
        SkinningMixin:RefreshButtonVisualState(btn)
    end)
    button:HookScript("OnDisable", function(btn)
        SkinningMixin:RefreshButtonVisualState(btn)
    end)
    button:HookScript("OnShow", function(btn)
        SkinningMixin:RefreshButtonVisualState(btn)
    end)
end

function SkinningMixin:DecorateWindow(frame)
    if not frame then return end

    local headerHeight = self:GetLayoutValue("headerHeight", 42)

    if not frame.ltHeader then
        local header = frame:CreateTexture(nil, "BACKGROUND", nil, 1)
        header:SetPoint("TOPLEFT", 1, -1)
        header:SetPoint("TOPRIGHT", -1, -1)
        frame.ltHeader = header
    end
    frame.ltHeader:SetHeight(headerHeight)
    ApplyColorToTexture(frame.ltHeader, self:GetColor("header"))

    if not frame.ltAccent then
        local accent = frame:CreateTexture(nil, "OVERLAY", nil, 2)
        accent:SetPoint("TOPLEFT", 1, -1)
        accent:SetPoint("TOPRIGHT", -1, -1)
        accent:SetHeight(2)
        frame.ltAccent = accent
    end
    ApplyColorToTexture(frame.ltAccent, self:GetColor("accent"))

    if not frame.ltInsetShade then
        local shade = frame:CreateTexture(nil, "BACKGROUND", nil, -1)
        shade:SetPoint("BOTTOMLEFT", 1, 1)
        shade:SetPoint("BOTTOMRIGHT", -1, 1)
        frame.ltInsetShade = shade
    end
    frame.ltInsetShade:ClearAllPoints()
    frame.ltInsetShade:SetPoint("TOPLEFT", 1, -(headerHeight + 1))
    frame.ltInsetShade:SetPoint("TOPRIGHT", -1, -(headerHeight + 1))
    frame.ltInsetShade:SetPoint("BOTTOMLEFT", 1, 1)
    frame.ltInsetShade:SetPoint("BOTTOMRIGHT", -1, 1)
    ApplyColorToTexture(frame.ltInsetShade, self:GetColor("panelInset"))
end

function SkinningMixin:StylePlainButton(button, variant)
    if not button then return end

    styledButtons[button] = variant or "default"

    local palette = self:GetButtonVariantPalette(variant)

    -- Apply backdrop directly. Avoid StyleUtil.ApplyButton because the Loolib
    -- theme's componentConfig.textureSet would force Blizzard panel textures
    -- onto the button, overriding our flat appearance.
    if button.SetBackdrop then
        button:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Buttons\\WHITE8x8",
            tile = false,
            edgeSize = 1,
            insets = { left = 1, right = 1, top = 1, bottom = 1 },
        })
    end

    -- Strip any state textures that may have been inherited from a template.
    local function clearTexture(getter)
        local region = getter and getter(button)
        if type(region) == "table" then
            if region.SetTexture then region:SetTexture(nil) end
            if region.Hide then region:Hide() end
        end
    end
    if button.SetNormalTexture then button:SetNormalTexture("") end
    if button.SetPushedTexture then button:SetPushedTexture("") end
    if button.SetHighlightTexture then button:SetHighlightTexture("") end
    if button.SetDisabledTexture then button:SetDisabledTexture("") end
    clearTexture(button.GetNormalTexture)
    clearTexture(button.GetPushedTexture)
    clearTexture(button.GetHighlightTexture)
    clearTexture(button.GetDisabledTexture)

    -- Apply themed font to the button label.
    local fontString = (button.GetFontString and button:GetFontString()) or button.Text or button.text
    if fontString and StyleUtil then
        StyleUtil.ApplyText(fontString, "body", palette.textColorKey)
    end

    button.ltButtonVariant = variant or "default"

    self:EnsureButtonStateHooks(button)
    self:RefreshButtonVisualState(button)
end

function SkinningMixin:RefreshStyledButtons()
    for button, variant in pairs(styledButtons) do
        if type(button) == "table" and button.IsObjectType then
            self:StylePlainButton(button, variant)
        end
    end
end

--[[--------------------------------------------------------------------
    Skin Application
----------------------------------------------------------------------]]

--- Apply a skin preset to a frame
-- @param frame Frame - The frame to skin
-- @param skinName string|nil - Preset name (nil = use current setting)
function SkinningMixin:ApplySkin(frame, skinName)
    if not frame or not frame.SetBackdrop then return end

    local skin = self:GetSkinData(skinName)

    frame:SetBackdrop({
        bgFile = skin.bgFile,
        edgeFile = skin.edgeFile,
        tile = skin.tile,
        tileSize = skin.tileSize,
        edgeSize = skin.edgeSize,
        insets = skin.insets,
    })

    frame:SetBackdropColor(unpack(skin.bgColor))
    frame:SetBackdropBorderColor(unpack(skin.borderColor))
    self:DecorateWindow(frame)
end

--- Get the current skin name
-- @return string
function SkinningMixin:GetCurrentSkin()
    if Loothing.Settings then
        return Loothing.Settings:Get("frame.skin") or "Default"
    end
    return "Default"
end

--- Set the current skin and apply to all managed frames
-- @param skinName string
function SkinningMixin:SetCurrentSkin(skinName)
    if not Loothing.SkinPresets[skinName] then return end

    if Loothing.Settings then
        Loothing.Settings:Set("frame.skin", skinName)
    end

    self:RefreshTheme()
end

function SkinningMixin:SetCurrentAccent(accentName)
    if not ns.SkinAccentPresets[accentName] then return end

    if Loothing.Settings then
        Loothing.Settings:Set("frame.accent", accentName)
    end

    self:RefreshTheme()
end

function SkinningMixin:SetCurrentDensity(densityName)
    if not ns.SkinDensityPresets[densityName] then return end

    if Loothing.Settings then
        Loothing.Settings:Set("frame.density", densityName)
    end

    self:RefreshTheme()
end

function SkinningMixin:RefreshTheme()
    self:InvalidateSkinCache()
    self:SyncLoolibTheme()

    for _, entry in ipairs(managedFrames) do
        if entry.frame and entry.frame:IsObjectType("Frame") then
            self:ApplySkin(entry.frame)
        end
    end

    if Loothing.MainFrame and type(Loothing.MainFrame.ApplyTheme) == "function" then
        Loothing.MainFrame:ApplyTheme()
    end
    -- Dispatch ApplyTheme to every polished top-level panel so accent/skin
    -- changes take effect immediately, even if the panel is currently open.
    -- Each entry is (owner_table, key). The ApplyTheme method must live on
    -- the mixin instance at owner_table[key].
    local dispatchTargets = {
        -- Panels/tables stored on Loothing.UI
        { Loothing.UI, "CouncilTable" },
        { Loothing.UI, "RollFrame" },
        { Loothing.UI, "VotePanel" },
        { Loothing.UI, "ResultsPanel" },
        { Loothing.UI, "SyncPanel" },
        { Loothing.UI, "VersionCheckPanel" },
        -- Mixin instances stored directly on Loothing (not Loothing.UI)
        { Loothing,    "DiagPanel" },
        { Loothing,    "AddItemFrame" },
        { Loothing,    "ResponseButtonSettings" },
        { Loothing,    "AwardReasonsSettings" },
        -- Frames stored on ns with metatable proxy / direct Mixin() (ApplyTheme lives on the frame itself)
        { ns,          "LootPickerFrame" },
        { ns,          "IconPickerFrame" },
        -- SimulatorPanel is a mixin-as-singleton; ApplyTheme no-ops if the frame hasn't been built yet
        { ns,          "SimulatorPanelMixin" },
        -- HistoryDetailFrames is a dispatch table that fans ApplyTheme to all
        -- four lazy history-detail modals (item detail, session summary,
        -- candidate profile, voter profile). No-op if none have been opened yet.
        { ns,          "HistoryDetailFrames" },
        -- PlayerIntelFrames dispatches to the lazy PlayerIntelFrame singleton
        -- (UI/PlayerIntelFrame.lua). No-op until the user opens the modal once.
        { ns,          "PlayerIntelFrames" },
    }
    for _, entry in ipairs(dispatchTargets) do
        local owner, key = entry[1], entry[2]
        local target = owner and owner[key]
        if target and type(target.ApplyTheme) == "function" then
            target:ApplyTheme()
        end
    end

    self:RefreshStyledButtons()

    -- Re-tint every themed scrollbar (thumb + track) so accent/skin
    -- changes take effect on currently-visible scroll views.
    if type(ns.RefreshThemedScrollBars) == "function" then
        ns.RefreshThemedScrollBars()
    end
end

--- Apply per-frame overrides (bgColor, borderColor)
-- @param frame Frame
-- @param frameName string - Key for db.UI lookup
function SkinningMixin:ApplyFrameOverrides(frame, frameName)
    if not Loothing.Settings or not frame then return end

    local uiData = Loothing.Settings:Get("frame.UI." .. frameName)
    if not uiData then return end

    if uiData.bgColor then
        frame:SetBackdropColor(unpack(uiData.bgColor))
    end
    if uiData.borderColor then
        frame:SetBackdropBorderColor(unpack(uiData.borderColor))
    end
end

--[[--------------------------------------------------------------------
    Per-Frame Position/Scale Persistence
----------------------------------------------------------------------]]

--- Save frame position and scale to db.UI[frameName]
-- @param frame Frame
-- @param frameName string
function SkinningMixin:SaveFrameState(frame, frameName)
    if not Loothing.Settings or not frame then return end

    local point, _, relativePoint, x, y = frame:GetPoint()
    local width, height = frame:GetSize()
    local scale = frame:GetScale()

    Loothing.Settings:Set("frame.UI." .. frameName, {
        point = point,
        relativePoint = relativePoint,
        x = x,
        y = y,
        width = width,
        height = height,
        scale = scale,
    })
end

--- Load frame position and scale from db.UI[frameName]
-- @param frame Frame
-- @param frameName string
function SkinningMixin:LoadFrameState(frame, frameName)
    if not Loothing.Settings or not frame then return end

    local uiData = Loothing.Settings:Get("frame.UI." .. frameName)
    if not uiData then return end

    if uiData.point then
        frame:ClearAllPoints()
        frame:SetPoint(
            uiData.point,
            UIParent,
            uiData.relativePoint or uiData.point,
            uiData.x or 0,
            uiData.y or 0
        )
    end

    if uiData.width and uiData.height then
        frame:SetSize(uiData.width, uiData.height)
    end

    if uiData.scale then
        frame:SetScale(uiData.scale)
    end
end

--[[--------------------------------------------------------------------
    Ctrl+Scroll Scale
----------------------------------------------------------------------]]

--- Enable Ctrl+Scroll scaling on a frame
-- @param frame Frame
-- @param frameName string - Key for persistence
-- @param minScale number - Minimum scale (default 0.5)
-- @param maxScale number - Maximum scale (default 2.0)
function SkinningMixin:EnableCtrlScroll(frame, frameName, minScale, maxScale)
    if not frame then return end

    minScale = minScale or 0.5
    maxScale = maxScale or 2.0

    frame:EnableMouseWheel(true)
    frame:HookScript("OnMouseWheel", function(f, delta)
        if IsControlKeyDown() then
            local currentScale = f:GetScale()
            local step = 0.05

            if delta > 0 then
                currentScale = math.min(maxScale, currentScale + step)
            else
                currentScale = math.max(minScale, currentScale - step)
            end

            f:SetScale(currentScale)

            -- Persist
            if frameName then
                self:SaveFrameState(f, frameName)
            end
        end
    end)
end

--[[--------------------------------------------------------------------
    Combat Minimize/Maximize
----------------------------------------------------------------------]]

--- Register a frame for combat minimize/maximize
-- @param frame Frame - The frame to manage
-- @param frameName string - Name for tracking
-- @param minimizeFunc function|nil - Custom minimize (default: frame:Hide())
-- @param maximizeFunc function|nil - Custom maximize (default: frame:Show())
function SkinningMixin:RegisterForCombatMinimize(frame, frameName, minimizeFunc, maximizeFunc)
    if not frame then return end

    managedFrames[#managedFrames + 1] = {
        frame = frame,
        name = frameName,
        minimize = minimizeFunc or function(f) f:Hide() end,
        maximize = maximizeFunc or function(f) f:Show() end,
        wasShown = false,
    }

    -- Create combat event frame if needed
    if not combatFrame then
        combatFrame = CreateFrame("Frame")
        combatFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
        combatFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
        combatFrame:SetScript("OnEvent", function(_, event)
            if event == "PLAYER_REGEN_DISABLED" then
                SkinningMixin:OnCombatStart()
            elseif event == "PLAYER_REGEN_ENABLED" then
                SkinningMixin:OnCombatEnd()
            end
        end)
    end
end

--- Unregister a frame from combat minimize
-- @param frame Frame
function SkinningMixin:UnregisterForCombatMinimize(frame)
    for i = #managedFrames, 1, -1 do
        if managedFrames[i].frame == frame then
            table.remove(managedFrames, i)
            break
        end
    end
end

--- Handle combat start - minimize all registered frames
function SkinningMixin:OnCombatStart()
    if not Loothing.Settings then return end

    local minimizeInCombat = Loothing.Settings:Get("frame.minimizeInCombat", false)
    if not minimizeInCombat then return end

    for _, entry in ipairs(managedFrames) do
        if entry.frame:IsShown() then
            entry.wasShown = true
            entry.minimize(entry.frame)
        else
            entry.wasShown = false
        end
    end
end

--- Mark a combat-minimized frame as deliberately closed so OnCombatEnd
--- doesn't resurrect it. Frames hidden while minimized never fire the
--- usual OnHide path, so wasShown would stay true and the frame would
--- ghost back open (empty) after combat.
function SkinningMixin:NotifyFrameClosed(frame)
    for _, entry in ipairs(managedFrames) do
        if entry.frame == frame then
            entry.wasShown = false
            return
        end
    end
end

--- Handle combat end - restore minimized frames
function SkinningMixin:OnCombatEnd()
    for _, entry in ipairs(managedFrames) do
        if entry.wasShown then
            entry.maximize(entry.frame)
            -- A frame captured mid-hide-fade finishes its tween at alpha
            -- 0 even after minimize() hid it (the tween runs on Loolib's
            -- shared updater, which hiding the target does not stop) — a
            -- bare Show() then presents an invisible, click-swallowing
            -- frame. Kill any fade and restore full alpha.
            local fade = entry.frame._loothingFadeGroup
            if fade and fade.Stop then fade:Stop() end
            if entry.frame.SetAlpha then entry.frame:SetAlpha(1) end
            entry.wasShown = false
        end
    end
end

--[[--------------------------------------------------------------------
    Escape-to-Close
----------------------------------------------------------------------]]

local function addToUISpecialFrames(globalName)
    if not UISpecialFrames then return end
    for _, name in ipairs(UISpecialFrames) do
        if name == globalName then return end
    end
    tinsert(UISpecialFrames, globalName)
end

local function removeFromUISpecialFrames(globalName)
    if not UISpecialFrames then return end
    for i = #UISpecialFrames, 1, -1 do
        if UISpecialFrames[i] == globalName then
            tremove(UISpecialFrames, i)
        end
    end
end

--- Register a frame for Escape-to-close
-- @param frame Frame
-- @param globalName string - Global frame name
function SkinningMixin:RegisterForEscapeClose(frame, globalName)
    if not frame or not globalName then return end

    -- Blizzard's CloseSpecialWindows resolves the entry by global NAME;
    -- several of our frames (MainFrame, CouncilTable, RollFrame) are created
    -- unnamed, so their registration was a silent no-op — ESC did nothing on
    -- exactly the windows users most expect it to close. Publishing the
    -- global here is deliberate (it's how UISpecialFrames works).
    if _G[globalName] == nil then
        _G[globalName] = frame
    end

    -- Track every registration so the closeWithEscape toggle applies live
    -- (previously enabling required a /reload and disabling never took
    -- effect at all).
    self.escapeCloseNames = self.escapeCloseNames or {}
    local tracked = false
    for _, name in ipairs(self.escapeCloseNames) do
        if name == globalName then
            tracked = true
            break
        end
    end
    if not tracked then
        tinsert(self.escapeCloseNames, globalName)
    end

    if Loothing.Settings
        and not Loothing.Settings:Get("frame.closeWithEscape", false) then
        return
    end
    addToUISpecialFrames(globalName)
end

--- Apply the closeWithEscape setting to every tracked frame immediately.
-- Called from the options setter.
-- @param enabled boolean
function SkinningMixin:ApplyEscapeCloseSetting(enabled)
    for _, name in ipairs(self.escapeCloseNames or {}) do
        if enabled then
            addToUISpecialFrames(name)
        else
            removeFromUISpecialFrames(name)
        end
    end
end

--[[--------------------------------------------------------------------
    Full Frame Setup (convenience)
----------------------------------------------------------------------]]

--- Setup a frame with all skinning features
-- @param frame Frame
-- @param frameName string - Unique name for persistence
-- @param globalName string|nil - Global name for Escape-to-close
-- @param options table|nil - { combatMinimize, ctrlScroll, escapeClose }
function SkinningMixin:SetupFrame(frame, frameName, globalName, options)
    if not frame then return end
    options = options or {}

    -- Apply skin
    self:ApplySkin(frame)
    self:ApplyFrameOverrides(frame, frameName)

    -- Load saved position/scale
    self:LoadFrameState(frame, frameName)

    -- Ctrl+Scroll
    if options.ctrlScroll ~= false then
        self:EnableCtrlScroll(frame, frameName)
    end

    -- Combat minimize
    if options.combatMinimize ~= false then
        self:RegisterForCombatMinimize(frame, frameName)
    end

    -- Escape-to-close
    if globalName and options.escapeClose ~= false then
        self:RegisterForEscapeClose(frame, globalName)
    end

    -- Click-to-raise
    local WM = Loolib:GetModule("WindowManager")
    if WM then WM:Register(frame) end
end

--[[--------------------------------------------------------------------
    Init (called from Core/Init.lua)
----------------------------------------------------------------------]]

function SkinningMixin:Init()
    -- Ensure defaults exist
    if Loothing.Settings and not Loothing.Settings:Get("frame.skin") then
        Loothing.Settings:Set("frame.skin", "Default")
    end
    if Loothing.Settings and not Loothing.Settings:Get("frame.accent") then
        Loothing.Settings:Set("frame.accent", "Amber")
    end
    if Loothing.Settings and not Loothing.Settings:Get("frame.density") then
        Loothing.Settings:Set("frame.density", "Comfortable")
    end

    if Loolib.ThemeManager and Loolib.ThemeManager.RegisterMedia then
        Loolib.ThemeManager:RegisterMedia("image", "loothing-logo", "Interface\\AddOns\\Loothing\\Media\\logo.tga")
    end

    self:SyncLoolibTheme()
end
