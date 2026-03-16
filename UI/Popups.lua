--[[--------------------------------------------------------------------
    Loothing - Loot Council Addon for WoW 12.0+
    Popups - Dialog registration and management using Loolib Dialog system

    This module registers all Loothing-specific confirmation dialogs.
    Uses Loolib's Dialog system for modal/non-modal dialogs with callbacks.
----------------------------------------------------------------------]]

local ADDON_NAME, ns = ...
local Loolib = LibStub("Loolib")
local Loothing = ns.Addon
local Utils = ns.Utils
local L = ns.Locale
local C_Item = C_Item
local ipairs, tostring, type = ipairs, tostring, type
local tinsert = table.insert

--[[--------------------------------------------------------------------
    Popup Registry

    All popups are registered here and can be shown via:
    ns.Popups:Show(dialogName, data, onAccept, onCancel)
----------------------------------------------------------------------]]

local Popups = ns.Popups or {}
Popups.dialogs = Popups.dialogs or {}
Popups.activeDialogs = Popups.activeDialogs or {}
ns.Popups = Popups

--[[--------------------------------------------------------------------
    Helper Functions
----------------------------------------------------------------------]]

local function ReplaceTokens(text, data)
    if not data then return text end

    -- Replace common tokens
    local result = text
    if data.item then
        result = result:gsub("{item}", data.item)
    end
    if data.player then
        result = result:gsub("{player}", data.player)
    end
    if data.count then
        result = result:gsub("{count}", tostring(data.count))
    end
    if data.type then
        result = result:gsub("{type}", data.type)
    end
    if data.days then
        result = result:gsub("{days}", tostring(data.days))
    end
    if data.reason then
        result = result:gsub("{reason}", data.reason)
    end
    if data.boss then
        result = result:gsub("{boss}", data.boss)
    end
    if data.instance then
        result = result:gsub("{instance}", data.instance)
    end

    return result
end

local function GetItemIcon(itemLink)
    if not itemLink then return nil end

    local itemID = Utils.GetItemID(itemLink)
    if not itemID then return nil end

    local _, _, _, _, icon = C_Item.GetItemInfoInstant(itemID)
    return icon
end

--[[--------------------------------------------------------------------
    Dialog Registration
----------------------------------------------------------------------]]

--- Register a dialog template
-- @param name string - Dialog name
-- @param config table - Dialog configuration
function Popups:Register(name, config)
    self.dialogs[name] = config
end

--- Show a registered dialog
-- @param name string - Dialog name
-- @param data table - Data to pass to the dialog (optional)
-- @param onAccept function - Accept callback (optional)
-- @param onCancel function - Cancel callback (optional)
-- @return Frame - The dialog frame
function Popups:Show(name, data, onAccept, onCancel)
    local config = self.dialogs[name]
    if not config then
        Loothing:Error("Dialog not found:", name)
        return
    end

    -- Create dialog
    local dialog = Loolib.UI.Dialog.Create()

    -- Set title
    local title = config.title or "Loothing"
    dialog:SetTitle(ReplaceTokens(title, data))

    -- Set message
    local message = config.text or ""
    local processedMessage = ReplaceTokens(message, data)

    -- Call on_show hook if provided (can modify message)
    if config.on_show then
        local customMessage = config.on_show(dialog, data)
        if customMessage then
            processedMessage = customMessage
        end
    end

    dialog:SetMessage(processedMessage)

    -- Set icon if provided
    if config.icon then
        local icon = config.icon
        -- If icon is a function, call it with data
        if type(icon) == "function" then
            icon = icon(data)
        end
        if icon and icon ~= "" then
            dialog:SetIcon(icon)
        end
    end

    -- Set modal
    dialog:SetModal(config.modal ~= false)

    -- Set escape close
    dialog:SetEscapeClose(config.hide_on_escape ~= false)

    -- Build buttons
    local buttons = {}
    for i, buttonConfig in ipairs(config.buttons or {}) do
        local button = {
            text = buttonConfig.text or "Button",
            danger = buttonConfig.danger,
            onClick = function(dlg)
                -- Call button's on_click with dialog and data
                if buttonConfig.on_click then
                    buttonConfig.on_click(dlg, data)
                end

                -- Call accept/cancel callbacks
                if i == 1 and onAccept then
                    onAccept(data)
                elseif i == 2 and onCancel then
                    onCancel(data)
                end
            end,
            closes = buttonConfig.closes ~= false,
        }
        tinsert(buttons, button)
    end

    dialog:SetButtons(buttons)

    -- Register cancel callback
    if onCancel then
        dialog:RegisterCallback("OnCancel", function()
            onCancel(data)
        end)
    end

    -- Call on_cancel hook if provided
    if config.on_cancel then
        dialog:RegisterCallback("OnCancel", function()
            config.on_cancel(dialog, data)
        end)
    end

    -- Show dialog
    dialog:Show()

    -- Track active dialog
    self.activeDialogs[name] = dialog

    return dialog
end

--- Hide a dialog by name
-- @param name string - Dialog name
function Popups:Hide(name)
    local dialog = self.activeDialogs[name]
    if dialog then
        dialog:Hide()
        self.activeDialogs[name] = nil
    end
end

--- Check if a dialog is showing
-- @param name string - Dialog name
-- @return boolean
function Popups:IsShowing(name)
    local dialog = self.activeDialogs[name]
    return dialog and dialog:IsShown() or false
end

--[[--------------------------------------------------------------------
    Dialog Definitions
----------------------------------------------------------------------]]

-- 0. ML Usage Prompt - "You are ML, use Loothing?"
Popups:Register("LOOTHING_ML_USAGE_PROMPT", {
    title = L["ADDON_NAME"],
    text = L["ML_USAGE_PROMPT_TEXT"],
    modal = true,
    hide_on_escape = true,
    show_while_dead = true,
    on_show = function(dialog, data)
        if data and data.instance and data.instance ~= "" then
            return string.format(
                L["ML_USAGE_PROMPT_TEXT_INSTANCE"],
                data.instance
            )
        end
    end,
    buttons = {
        {
            text = L["YES"],
            on_click = function(dialog, data) end,
        },
        {
            text = L["NO"],
            on_click = function(dialog, data) end,
        },
    },
})

-- 1. Confirm Usage - "Use Loothing for this session?"
Popups:Register("LOOTHING_CONFIRM_USAGE", {
    title = L["ADDON_NAME"],
    text = L["POPUP_CONFIRM_USAGE"],
    modal = true,
    hide_on_escape = true,
    show_while_dead = true,
    buttons = {
        {
            text = L["YES"],
            on_click = function(dialog, data)
                if data and data.onAccept then
                    data.onAccept()
                end
            end,
        },
        {
            text = L["NO"],
            on_click = function(dialog, data)
                if data and data.onCancel then
                    data.onCancel()
                end
            end,
        },
    },
})

-- 2. Confirm Abort - "Abort current session?"
Popups:Register("LOOTHING_CONFIRM_ABORT", {
    title = L["END_SESSION"],
    text = L["POPUP_CONFIRM_END_SESSION"],
    modal = true,
    hide_on_escape = true,
    show_while_dead = true,
    buttons = {
        {
            text = L["YES"],
            danger = true,
            on_click = function(dialog, data)
                if data and data.onAccept then
                    data.onAccept()
                end
            end,
        },
        {
            text = L["NO"],
            on_click = function(dialog, data)
                if data and data.onCancel then
                    data.onCancel()
                end
            end,
        },
    },
})

-- 3. Confirm Award - "Award {item} to {player}?"
Popups:Register("LOOTHING_CONFIRM_AWARD", {
    title = L["AWARD_ITEM"],
    text = L["CONFIRM_AWARD"],
    modal = true,
    hide_on_escape = true,
    show_while_dead = true,
    icon = function(data)
        return GetItemIcon(data and data.item)
    end,
    on_show = function(dialog, data)
        if data and data.item and data.player then
            local message = string.format(L["CONFIRM_AWARD"], data.item, data.player)
            if data.reason then
                message = message .. "\n" .. L["AWARD_REASON"] .. ": " .. data.reason
            end
            return message
        end
        return nil
    end,
    buttons = {
        {
            text = L["YES"],
            on_click = function(dialog, data)
                if data and data.onAccept then
                    data.onAccept()
                end
            end,
        },
        {
            text = L["NO"],
            on_click = function(dialog, data)
                if data and data.onCancel then
                    data.onCancel()
                end
            end,
        },
    },
})

-- 4. Confirm Award Later - "Bag {item} for later?"
Popups:Register("LOOTHING_CONFIRM_AWARD_LATER", {
    title = L["AWARD_ITEM"],
    text = L["POPUP_AWARD_LATER"],
    modal = true,
    hide_on_escape = true,
    show_while_dead = true,
    icon = function(data)
        return GetItemIcon(data and data.item)
    end,
    buttons = {
        {
            text = L["YES"],
            on_click = function(dialog, data)
                if data and data.onAccept then
                    data.onAccept()
                end
            end,
        },
        {
            text = L["NO"],
            on_click = function(dialog, data)
                if data and data.onCancel then
                    data.onCancel()
                end
            end,
        },
    },
})

-- 5. Trade Add Item - "Add {count} items to trade with {player}?"
Popups:Register("LOOTHING_TRADE_ADD_ITEM", {
    title = L["TRADE_QUEUE"],
    text = L["POPUP_TRADE_ADD_ITEMS"],
    modal = true,
    hide_on_escape = true,
    show_while_dead = true,
    on_show = function(dialog, data)
        if data and data.count and data.player then
            if data.count == 1 then
                return string.format(L["POPUP_TRADE_ADD_SINGLE"], data.player)
            else
                return string.format(L["POPUP_TRADE_ADD_MULTI"], data.count, data.player)
            end
        end
        return nil
    end,
    buttons = {
        {
            text = L["YES"],
            on_click = function(dialog, data)
                if data and data.onAccept then
                    data.onAccept()
                end
            end,
        },
        {
            text = L["NO"],
            on_click = function(dialog, data)
                if data and data.onCancel then
                    data.onCancel()
                end
            end,
        },
    },
})

-- 6. Keep Item - "Keep {item} or trade?"
Popups:Register("LOOTHING_KEEP_ITEM", {
    title = L["AWARD_ITEM"],
    text = L["POPUP_KEEP_OR_TRADE"],
    modal = true,
    hide_on_escape = true,
    show_while_dead = true,
    no_close_button = true,
    icon = function(data)
        return GetItemIcon(data and data.item)
    end,
    on_show = function(dialog, data)
        if data and data.item then
            return string.format(L["POPUP_KEEP_OR_TRADE_FMT"], data.item)
        end
        return nil
    end,
    buttons = {
        {
            text = L["KEEP"],
            on_click = function(dialog, data)
                if data and data.onKeep then
                    data.onKeep()
                end
            end,
        },
        {
            text = L["TRADE_QUEUE"],
            on_click = function(dialog, data)
                if data and data.onTrade then
                    data.onTrade()
                end
            end,
        },
    },
})

-- 7. Sync Request - "{player} wants to sync {type}"
Popups:Register("LOOTHING_SYNC_REQUEST", {
    title = L["POPUP_SYNC_REQUEST_TITLE"],
    text = L["POPUP_SYNC_REQUEST"],
    modal = true,
    hide_on_escape = true,
    show_while_dead = true,
    on_show = function(dialog, data)
        if data then
            local syncType = data.type or "data"
            local player = data.player or L["UNKNOWN"]

            if syncType == "settings" then
                return string.format(L["POPUP_SYNC_SETTINGS_FMT"], player)
            elseif syncType == "history" then
                local days = data.days or 7
                return string.format(L["POPUP_SYNC_HISTORY_FMT"], player, days)
            else
                return string.format(L["POPUP_SYNC_GENERIC_FMT"], player, syncType)
            end
        end
        return nil
    end,
    buttons = {
        {
            text = L["ACCEPT"],
            on_click = function(dialog, data)
                if data and data.onAccept then
                    data.onAccept()
                end
            end,
        },
        {
            text = L["DECLINE"],
            on_click = function(dialog, data)
                if data and data.onCancel then
                    data.onCancel()
                end
            end,
        },
    },
})

-- 8. Import Overwrite - "Import will overwrite {count} entries"
Popups:Register("LOOTHING_IMPORT_OVERWRITE", {
    title = L["HISTORY"],
    text = L["POPUP_IMPORT_OVERWRITE"],
    modal = true,
    hide_on_escape = true,
    show_while_dead = true,
    on_show = function(dialog, data)
        if data and data.count then
            if data.count == 1 then
                return L["POPUP_IMPORT_OVERWRITE_SINGLE"]
            else
                return string.format(L["POPUP_IMPORT_OVERWRITE_MULTI"], data.count)
            end
        end
        return nil
    end,
    buttons = {
        {
            text = L["YES"],
            danger = true,
            on_click = function(dialog, data)
                if data and data.onAccept then
                    data.onAccept()
                end
            end,
        },
        {
            text = L["NO"],
            on_click = function(dialog, data)
                if data and data.onCancel then
                    data.onCancel()
                end
            end,
        },
    },
})

-- 9. Confirm Delete History - "Delete {count} history entries?"
Popups:Register("LOOTHING_CONFIRM_DELETE_HISTORY", {
    title = L["CLEAR_HISTORY"],
    text = L["CONFIRM_CLEAR_HISTORY"],
    modal = true,
    hide_on_escape = true,
    show_while_dead = true,
    on_show = function(dialog, data)
        if data and data.count then
            if data.count == 1 then
                return L["POPUP_DELETE_HISTORY_SINGLE"]
            elseif data.count == "all" then
                return L["POPUP_DELETE_HISTORY_ALL"]
            else
                return string.format(L["POPUP_DELETE_HISTORY_MULTI"], data.count)
            end
        end
        return L["POPUP_DELETE_HISTORY_SELECTED"]
    end,
    buttons = {
        {
            text = L["YES"],
            danger = true,
            on_click = function(dialog, data)
                if data and data.onAccept then
                    data.onAccept()
                end
            end,
        },
        {
            text = L["NO"],
            on_click = function(dialog, data)
                if data and data.onCancel then
                    data.onCancel()
                end
            end,
        },
    },
})

-- 10. Confirm Clear Council - "Clear all council members?"
Popups:Register("LOOTHING_CONFIRM_CLEAR_COUNCIL", {
    title = L["COUNCIL"],
    text = L["CONFIG_COUNCIL_REMOVEALL_CONFIRM"],
    modal = true,
    hide_on_escape = true,
    show_while_dead = true,
    on_show = function(dialog, data)
        if data and data.count then
            return string.format(L["POPUP_CLEAR_COUNCIL_COUNT"], data.count)
        end
        return L["POPUP_CLEAR_COUNCIL"]
    end,
    buttons = {
        {
            text = L["YES"],
            danger = true,
            on_click = function(dialog, data)
                if data and data.onAccept then
                    data.onAccept()
                end
            end,
        },
        {
            text = L["NO"],
            on_click = function(dialog, data)
                if data and data.onCancel then
                    data.onCancel()
                end
            end,
        },
    },
})

-- 11. Confirm Skip Item - "Skip this item?"
Popups:Register("LOOTHING_CONFIRM_SKIP", {
    title = L["SKIP_ITEM"],
    text = L["POPUP_SKIP_ITEM"],
    modal = true,
    hide_on_escape = true,
    show_while_dead = true,
    icon = function(data)
        return GetItemIcon(data and data.item)
    end,
    on_show = function(dialog, data)
        if data and data.item then
            return string.format(L["POPUP_SKIP_ITEM_FMT"], data.item)
        end
        return nil
    end,
    buttons = {
        {
            text = L["YES"],
            on_click = function(dialog, data)
                if data and data.onAccept then
                    data.onAccept()
                end
            end,
        },
        {
            text = L["NO"],
            on_click = function(dialog, data)
                if data and data.onCancel then
                    data.onCancel()
                end
            end,
        },
    },
})

-- 12. Confirm Re-vote - "Clear all votes and restart voting?"
Popups:Register("LOOTHING_CONFIRM_REVOTE", {
    title = L["RE_VOTE"],
    text = L["POPUP_CONFIRM_REVOTE"],
    modal = true,
    hide_on_escape = true,
    show_while_dead = true,
    icon = function(data)
        return GetItemIcon(data and data.item)
    end,
    on_show = function(dialog, data)
        if data and data.item then
            return string.format(L["POPUP_CONFIRM_REVOTE_FMT"], data.item)
        end
        return L["COUNCIL_CONFIRM_REVOTE"]
    end,
    buttons = {
        {
            text = L["YES"],
            on_click = function(dialog, data)
                if data and data.onAccept then
                    data.onAccept()
                end
            end,
        },
        {
            text = L["NO"],
            on_click = function(dialog, data)
                if data and data.onCancel then
                    data.onCancel()
                end
            end,
        },
    },
})

-- 13. Confirm Delete Ignored Items - "Clear all ignored items?"
Popups:Register("LOOTHING_CONFIRM_CLEAR_IGNORED", {
    title = L["IGNORED_ITEMS"],
    text = L["CONFIRM_CLEAR_IGNORED"],
    modal = true,
    hide_on_escape = true,
    show_while_dead = true,
    on_show = function(dialog, data)
        if data and data.count then
            return string.format(L["POPUP_CLEAR_IGNORED_COUNT"], data.count)
        end
        return L["POPUP_CLEAR_IGNORED"]
    end,
    buttons = {
        {
            text = L["YES"],
            danger = true,
            on_click = function(dialog, data)
                if data and data.onAccept then
                    data.onAccept()
                end
            end,
        },
        {
            text = L["NO"],
            on_click = function(dialog, data)
                if data and data.onCancel then
                    data.onCancel()
                end
            end,
        },
    },
})

-- 14. Confirm Reset Award Reasons - "Reset all award reasons to defaults?"
Popups:Register("LOOTHING_CONFIRM_RESET_REASONS", {
    title = L["AWARD_REASONS"],
    text = L["CONFIG_REASON_RESET_CONFIRM"],
    modal = true,
    hide_on_escape = true,
    show_while_dead = true,
    buttons = {
        {
            text = L["YES"],
            danger = true,
            on_click = function(dialog, data)
                if data and data.onAccept then
                    data.onAccept()
                end
            end,
        },
        {
            text = L["NO"],
            on_click = function(dialog, data)
                if data and data.onCancel then
                    data.onCancel()
                end
            end,
        },
    },
})

-- 15. Confirm Delete Button Set - "Delete button set {name}?"
Popups:Register("LOOTHING_CONFIRM_DELETE_SET", {
    title = L["BUTTON_SETS"],
    text = L["CONFIRM_DELETE_SET"],
    modal = true,
    hide_on_escape = true,
    show_while_dead = true,
    on_show = function(dialog, data)
        if data and data.name then
            return string.format(L["CONFIRM_DELETE_SET"], data.name)
        end
        return nil
    end,
    buttons = {
        {
            text = L["YES"],
            danger = true,
            on_click = function(dialog, data)
                if data and data.onAccept then
                    data.onAccept()
                end
            end,
        },
        {
            text = L["NO"],
            on_click = function(dialog, data)
                if data and data.onCancel then
                    data.onCancel()
                end
            end,
        },
    },
})

-- 16. Confirm Re-announce - "Re-announce all items?"
Popups:Register("LOOTHING_CONFIRM_REANNOUNCE", {
    title = L["POPUP_REANNOUNCE_TITLE"],
    text = L["POPUP_REANNOUNCE"],
    modal = true,
    hide_on_escape = true,
    show_while_dead = true,
    buttons = {
        {
            text = L["YES"],
            on_click = function(dialog, data)
                if data and data.onAccept then
                    data.onAccept()
                end
            end,
        },
        {
            text = L["NO"],
        },
    },
})

-- 17. Confirm Start Session - "Start loot session for {boss}?"
Popups:Register("LOOTHING_CONFIRM_START_SESSION", {
    title = L["START_SESSION"],
    text = L["POPUP_START_SESSION"],
    modal = true,
    hide_on_escape = true,
    show_while_dead = true,
    on_show = function(dialog, data)
        if data and data.boss then
            return string.format(L["POPUP_START_SESSION_FMT"], data.boss)
        end
        return L["POPUP_START_SESSION_GENERIC"]
    end,
    buttons = {
        {
            text = L["YES"],
            on_click = function(dialog, data)
                if data and data.onAccept then
                    data.onAccept()
                end
            end,
        },
        {
            text = L["NO"],
            on_click = function(dialog, data)
                if data and data.onCancel then
                    data.onCancel()
                end
            end,
        },
    },
})

-- 18. Confirm Profile Overwrite - "Overwrite current profile?"
Popups:Register("LOOTHING_CONFIRM_PROFILE_OVERWRITE", {
    title = L["POPUP_OVERWRITE_PROFILE_TITLE"],
    text = L["POPUP_OVERWRITE_PROFILE"],
    modal = true,
    hide_on_escape = true,
    show_while_dead = true,
    buttons = {
        {
            text = L["OVERWRITE"],
            danger = true,
            on_click = function(dialog, data)
                if data and data.onAccept then
                    data.onAccept()
                end
            end,
        },
        {
            text = L["NO"],
        },
    },
})

-- 19. Settings Import Confirmation — two action buttons for import mode
Popups:Register("LOOTHING_SETTINGS_IMPORT_CONFIRM", {
    title = L["POPUP_IMPORT_SETTINGS_TITLE"],
    text = L["POPUP_IMPORT_SETTINGS"],
    modal = true,
    hide_on_escape = true,
    show_while_dead = true,
    buttons = {
        {
            text = L["CREATE_NEW_PROFILE"],
            on_click = function(dialog, data)
                if data and data.onNewProfile then
                    data.onNewProfile()
                end
            end,
        },
        {
            text = L["APPLY_TO_CURRENT"],
            danger = true,
            on_click = function(dialog, data)
                if data and data.onApplyCurrent then
                    data.onApplyCurrent()
                end
            end,
        },
    },
})

--[[--------------------------------------------------------------------
    Convenience Functions
----------------------------------------------------------------------]]

--- Show a simple yes/no confirmation dialog
-- @param title string - Dialog title
-- @param message string - Dialog message
-- @param onYes function - Callback when yes is clicked
-- @param onNo function - Callback when no is clicked (optional)
function Popups:Confirm(title, message, onYes, onNo)
    local dialog = Loolib.UI.Dialog.Create()
    dialog:SetTitle(title)
    dialog:SetMessage(message)
    dialog:SetModal(true)
    dialog:SetEscapeClose(true)

    dialog:SetButtons({
        {
            text = L["YES"],
            onClick = function(dlg)
                if onYes then
                    onYes()
                end
            end,
        },
        {
            text = L["NO"],
            onClick = function(dlg)
                if onNo then
                    onNo()
                end
            end,
        },
    })

    dialog:Show()
    return dialog
end

--- Show a simple alert dialog with OK button
-- @param title string - Dialog title
-- @param message string - Dialog message
-- @param onOK function - Callback when OK is clicked (optional)
function Popups:Alert(title, message, onOK)
    local dialog = Loolib.UI.Dialog.Create()
    dialog:SetTitle(title)
    dialog:SetMessage(message)
    dialog:SetModal(true)
    dialog:SetEscapeClose(true)

    dialog:SetButtons({
        {
            text = L["OK"],
            onClick = function(dlg)
                if onOK then
                    onOK()
                end
            end,
        },
    })

    dialog:Show()
    return dialog
end

--- Show an input dialog
-- @param title string - Dialog title
-- @param prompt string - Dialog prompt
-- @param defaultValue string - Default input value (optional)
-- @param onAccept function - Callback with input value when accepted
-- @param onCancel function - Callback when cancelled (optional)
function Popups:Input(title, prompt, defaultValue, onAccept, onCancel)
    local dialog = Loolib.UI.Dialog.CreateInput()
    dialog:SetTitle(title)
    dialog:SetPrompt(prompt)
    dialog:SetInputValue(defaultValue or "")
    dialog:SetModal(true)
    dialog:SetEscapeClose(true)

    if onAccept then
        dialog:RegisterCallback("OnAccept", function()
            local value = dialog:GetInputValue()
            onAccept(value)
        end)
    end

    if onCancel then
        dialog:RegisterCallback("OnCancel", onCancel)
    end

    dialog:Show()
    return dialog
end

--[[--------------------------------------------------------------------
    Export
----------------------------------------------------------------------]]

return Popups
