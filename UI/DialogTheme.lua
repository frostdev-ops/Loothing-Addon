--[[--------------------------------------------------------------------
    Loothing - Loolib ConfigDialog theme registration

    Registers a Loothing-specific theme with Loolib.Config.DialogTheme so
    the `/lt config` window pulls colors, fonts, and post-create button
    styling from the same SkinningMixin palette as the rest of the addon.

    Loolib's DialogTheme system was added in Loolib 2.1.0; this file
    fails gracefully on older Loolib by checking for the API surface
    before calling it.

    Re-registered whenever the user changes their accent or skin via
    SkinningMixin:RefreshTheme so the dialog repaints in the new accent
    on next open (and immediately if a dialog is already open).
----------------------------------------------------------------------]]

local _, ns = ...
local Loolib = LibStub("Loolib")
local Loothing = ns.Addon

local DialogTheme = {}
ns.LoothingDialogTheme = DialogTheme

local APP_NAME = "Loothing"

--- Pull a color from Loothing's SkinningMixin with a sane fallback.
local function GetSkinColor(key, fallback)
    local SkinningMixin = ns.SkinningMixin
    if not SkinningMixin or not SkinningMixin.GetColor then
        return fallback or { 1, 1, 1, 1 }
    end
    local color = SkinningMixin:GetColor(key)
    if type(color) == "table" then
        return color
    end
    return fallback or { 1, 1, 1, 1 }
end

--- Build the theme table from the current SkinningMixin state.
local function BuildTheme()
    return {
        colors = {
            -- Surfaces
            searchBoxBg          = GetSkinColor("panelInset"),
            treeContainerBg      = GetSkinColor("panelInset"),
            contentContainerBg   = GetSkinColor("panel"),
            inlineGroupBg        = GetSkinColor("panelAlt"),
            inputBg              = GetSkinColor("panelInset"),
            inputBgDisabled      = GetSkinColor("rowAlt"),
            dropdownBg           = GetSkinColor("panelInset"),
            dropdownBgDisabled   = GetSkinColor("rowAlt"),
            dropdownMenuBg       = GetSkinColor("panelInset"),
            filterButtonBg       = GetSkinColor("panelInset"),
            filterMenuBg         = GetSkinColor("panelInset"),
            keyButtonBg          = GetSkinColor("panelInset"),
            keyButtonBgDisabled  = GetSkinColor("rowAlt"),
            textureFrameBg       = GetSkinColor("panelInset"),

            -- Borders
            treeContainerBorder    = GetSkinColor("border"),
            contentContainerBorder = GetSkinColor("border"),
            inlineGroupBorder      = GetSkinColor("borderStrong", GetSkinColor("border")),

            -- Tree / tab states
            treeHoverBg          = GetSkinColor("rowHover"),
            treeSelectionBg      = GetSkinColor("rowSelected"),
            treeTextSelected     = GetSkinColor("accent"),
            tabBgActive          = GetSkinColor("rowSelected"),
            tabBgInactive        = GetSkinColor("rowAlt"),
            tabActiveAccent      = GetSkinColor("accent"),
            tabTextActive        = GetSkinColor("text"),
            tabTextInactive      = GetSkinColor("textMuted"),

            -- Filter / dropdown highlights
            filterButtonHover    = GetSkinColor("rowHover"),
            dropdownItemHover    = GetSkinColor("rowHover"),
            dropdownItemSelected = GetSkinColor("accent"),

            -- Text colors
            headerText           = GetSkinColor("accent"),
            descriptionText      = GetSkinColor("textMuted"),
            labelText            = GetSkinColor("text"),
            labelTextDisabled    = GetSkinColor("textSubtle"),
            noResultsText        = GetSkinColor("textMuted"),
            searchIcon           = GetSkinColor("textMuted"),

            -- Decorative
            separator            = GetSkinColor("border"),
        },

        afterCreateWidget = function(widgetType, widget)
            -- Apply Loothing's primary button skin to action buttons so
            -- they match SessionPanel / HistoryPanel buttons elsewhere
            -- in the addon.
            if widgetType == "execute" then
                local SkinningMixin = ns.SkinningMixin
                if SkinningMixin and SkinningMixin.StylePlainButton then
                    pcall(SkinningMixin.StylePlainButton, SkinningMixin, widget, "primary")
                end
            end
        end,
    }
end

--- Register (or re-register) the Loothing dialog theme. Safe to call
--- multiple times — Loolib's DialogTheme registry overwrites on each
--- call and notifies any open dialog to refresh in place.
function DialogTheme:Register()
    local Config = Loolib and Loolib.Config
    if not Config or type(Config.RegisterAppTheme) ~= "function" then
        -- Older Loolib without theming API; nothing to do.
        return false
    end
    Config:RegisterAppTheme(APP_NAME, BuildTheme())
    return true
end

--- Hook into SkinningMixin's RefreshTheme to keep the dialog theme in
--- sync with the user's accent / skin choice. This wraps the existing
--- RefreshTheme rather than replacing it so any other side effects
--- (frame restyling, callback fires) are preserved.
function DialogTheme:HookSkinningRefresh()
    local SkinningMixin = ns.SkinningMixin
    if not SkinningMixin or self._hookInstalled then
        return
    end
    self._hookInstalled = true

    local original = SkinningMixin.RefreshTheme
    if type(original) ~= "function" then
        return
    end
    SkinningMixin.RefreshTheme = function(skinSelf, ...)
        local result = original(skinSelf, ...)
        DialogTheme:Register()
        return result
    end
end

--- Attach Loothing's themed scrollbar to the ConfigDialog's scroll frames
--- when the dialog is opened. Loolib's ConfigDialog still creates scroll
--- frames with UIPanelScrollFrameTemplate so its non-Loothing consumers
--- keep Blizzard chrome; `ns.ApplyThemedScrollBar` hides that chrome and
--- attaches a themed bar outside the scroll area. Idempotent — a flag on
--- the ScrollFrame prevents double-application if the dialog re-opens.
function DialogTheme:HookDialogScrollbars()
    -- The callback registry (and the dialogs map) live on Config.Dialog,
    -- not on the plain Config module table — the old guard against
    -- Config.RegisterCallback always failed and this hook never attached.
    local Config = Loolib and Loolib.Config
    local Dialog = Config and Config.Dialog
    if not Dialog or type(Dialog.RegisterCallback) ~= "function" then
        return
    end
    if self._scrollHookInstalled then return end
    self._scrollHookInstalled = true

    local function apply(scroll)
        -- Tab / simple layouts leave `treeScroll` unset. Iterate via
        -- explicit nil-safe applies rather than ipairs — a nil hole in
        -- a sequence would halt ipairs and silently skip later entries.
        if not scroll then return end
        if scroll._loothingThemedBar then return end
        local ok, bar = pcall(ns.ApplyThemedScrollBar, scroll, {
            autoHide = true,
            showButtons = true,
            thickness = 10,
        })
        if ok then scroll._loothingThemedBar = bar end
    end

    Dialog:RegisterCallback("OnDialogOpened", function(_, appName)
        if appName ~= APP_NAME then return end
        if type(ns.ApplyThemedScrollBar) ~= "function" then return end
        local dialog = Dialog.dialogs and Dialog.dialogs[appName]
        if not dialog then return end
        apply(dialog.treeScroll)
        apply(dialog.optionsScroll)
    end)
end
