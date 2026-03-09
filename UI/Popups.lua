--[[--------------------------------------------------------------------
    Loothing - Loot Council Addon for WoW 12.0+
    Popups - Dialog registration and management using Loolib Dialog system

    This module registers all Loothing-specific confirmation dialogs.
    Uses Loolib's Dialog system for modal/non-modal dialogs with callbacks.
----------------------------------------------------------------------]]

local Loolib = LibStub("Loolib")
local L = Loothing.Locale

--[[--------------------------------------------------------------------
    Popup Registry

    All popups are registered here and can be shown via:
    LoothingPopups:Show(dialogName, data, onAccept, onCancel)
----------------------------------------------------------------------]]

LoothingPopups = {
    dialogs = {},
    activeDialogs = {},
}

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

    local itemID = LoothingUtils.GetItemID(itemLink)
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
function LoothingPopups:Register(name, config)
    self.dialogs[name] = config
end

--- Show a registered dialog
-- @param name string - Dialog name
-- @param data table - Data to pass to the dialog (optional)
-- @param onAccept function - Accept callback (optional)
-- @param onCancel function - Cancel callback (optional)
-- @return Frame - The dialog frame
function LoothingPopups:Show(name, data, onAccept, onCancel)
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
        table.insert(buttons, button)
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
function LoothingPopups:Hide(name)
    local dialog = self.activeDialogs[name]
    if dialog then
        dialog:Hide()
        self.activeDialogs[name] = nil
    end
end

--- Check if a dialog is showing
-- @param name string - Dialog name
-- @return boolean
function LoothingPopups:IsShowing(name)
    local dialog = self.activeDialogs[name]
    return dialog and dialog:IsShown() or false
end

--[[--------------------------------------------------------------------
    Dialog Definitions
----------------------------------------------------------------------]]

-- 0. ML Usage Prompt - "You are ML, use Loothing?"
LoothingPopups:Register("LOOTHING_ML_USAGE_PROMPT", {
    title = L["ADDON_NAME"],
    text = L["ML_USAGE_PROMPT_TEXT"] or "You are the raid leader. Use Loothing for loot distribution?",
    modal = true,
    hide_on_escape = true,
    show_while_dead = true,
    on_show = function(dialog, data)
        if data and data.instance and data.instance ~= "" then
            return string.format(
                L["ML_USAGE_PROMPT_TEXT_INSTANCE"] or "You are the raid leader.\nUse Loothing for %s?",
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
LoothingPopups:Register("LOOTHING_CONFIRM_USAGE", {
    title = L["ADDON_NAME"],
    text = "Do you want to use Loothing for loot distribution in this raid?",
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
LoothingPopups:Register("LOOTHING_CONFIRM_ABORT", {
    title = L["END_SESSION"],
    text = "Are you sure you want to end the current loot session? All pending items will be closed.",
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
LoothingPopups:Register("LOOTHING_CONFIRM_AWARD", {
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
LoothingPopups:Register("LOOTHING_CONFIRM_AWARD_LATER", {
    title = L["AWARD_ITEM"],
    text = "Award {item} to yourself to distribute later?",
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
LoothingPopups:Register("LOOTHING_TRADE_ADD_ITEM", {
    title = L["TRADE_QUEUE"],
    text = "Add {count} awarded items to trade with {player}?",
    modal = true,
    hide_on_escape = true,
    show_while_dead = true,
    on_show = function(dialog, data)
        if data and data.count and data.player then
            if data.count == 1 then
                return string.format("Add 1 awarded item to trade with %s?", data.player)
            else
                return string.format("Add %d awarded items to trade with %s?", data.count, data.player)
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
LoothingPopups:Register("LOOTHING_KEEP_ITEM", {
    title = L["AWARD_ITEM"],
    text = "What would you like to do with {item}?",
    modal = true,
    hide_on_escape = true,
    show_while_dead = true,
    no_close_button = true,
    icon = function(data)
        return GetItemIcon(data and data.item)
    end,
    on_show = function(dialog, data)
        if data and data.item then
            return string.format("What would you like to do with %s?", data.item)
        end
        return nil
    end,
    buttons = {
        {
            text = "Keep",
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
LoothingPopups:Register("LOOTHING_SYNC_REQUEST", {
    title = "Sync Request",
    text = "{player} wants to sync their {type} to you. Accept?",
    modal = true,
    hide_on_escape = true,
    show_while_dead = true,
    on_show = function(dialog, data)
        if data then
            local syncType = data.type or "data"
            local player = data.player or "Unknown"

            if syncType == "settings" then
                return string.format("%s wants to sync their Loothing settings to you. Accept?", player)
            elseif syncType == "history" then
                local days = data.days or 7
                return string.format("%s wants to sync their loot history (%d days) to you. Accept?", player, days)
            else
                return string.format("%s wants to sync their %s to you. Accept?", player, syncType)
            end
        end
        return nil
    end,
    buttons = {
        {
            text = "Accept",
            on_click = function(dialog, data)
                if data and data.onAccept then
                    data.onAccept()
                end
            end,
        },
        {
            text = "Decline",
            on_click = function(dialog, data)
                if data and data.onCancel then
                    data.onCancel()
                end
            end,
        },
    },
})

-- 8. Import Overwrite - "Import will overwrite {count} entries"
LoothingPopups:Register("LOOTHING_IMPORT_OVERWRITE", {
    title = L["HISTORY"],
    text = "This import will overwrite {count} existing history entries. Continue?",
    modal = true,
    hide_on_escape = true,
    show_while_dead = true,
    on_show = function(dialog, data)
        if data and data.count then
            if data.count == 1 then
                return "This import will overwrite 1 existing history entry. Continue?"
            else
                return string.format("This import will overwrite %d existing history entries. Continue?", data.count)
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
LoothingPopups:Register("LOOTHING_CONFIRM_DELETE_HISTORY", {
    title = L["CLEAR_HISTORY"],
    text = L["CONFIRM_CLEAR_HISTORY"],
    modal = true,
    hide_on_escape = true,
    show_while_dead = true,
    on_show = function(dialog, data)
        if data and data.count then
            if data.count == 1 then
                return "Delete 1 history entry? This cannot be undone."
            elseif data.count == "all" then
                return "Delete ALL history entries? This cannot be undone."
            else
                return string.format("Delete %d history entries? This cannot be undone.", data.count)
            end
        end
        return "Delete selected history entries? This cannot be undone."
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
LoothingPopups:Register("LOOTHING_CONFIRM_CLEAR_COUNCIL", {
    title = L["COUNCIL"],
    text = L["CONFIG_COUNCIL_REMOVEALL_CONFIRM"],
    modal = true,
    hide_on_escape = true,
    show_while_dead = true,
    on_show = function(dialog, data)
        if data and data.count then
            return string.format("Remove all %d council members?", data.count)
        end
        return "Remove all council members?"
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
LoothingPopups:Register("LOOTHING_CONFIRM_SKIP", {
    title = L["SKIP_ITEM"],
    text = "Skip {item} without awarding it?",
    modal = true,
    hide_on_escape = true,
    show_while_dead = true,
    icon = function(data)
        return GetItemIcon(data and data.item)
    end,
    on_show = function(dialog, data)
        if data and data.item then
            return string.format("Skip %s without awarding it?", data.item)
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
LoothingPopups:Register("LOOTHING_CONFIRM_REVOTE", {
    title = L["RE_VOTE"],
    text = "Clear all votes and restart voting for {item}?",
    modal = true,
    hide_on_escape = true,
    show_while_dead = true,
    icon = function(data)
        return GetItemIcon(data and data.item)
    end,
    on_show = function(dialog, data)
        if data and data.item then
            return string.format("Clear all votes and restart voting for %s?", data.item)
        end
        return "Clear all votes and restart voting?"
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
LoothingPopups:Register("LOOTHING_CONFIRM_CLEAR_IGNORED", {
    title = L["IGNORED_ITEMS"],
    text = L["CONFIRM_CLEAR_IGNORED"],
    modal = true,
    hide_on_escape = true,
    show_while_dead = true,
    on_show = function(dialog, data)
        if data and data.count then
            return string.format("Clear all %d ignored items?", data.count)
        end
        return "Clear all ignored items?"
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
LoothingPopups:Register("LOOTHING_CONFIRM_RESET_REASONS", {
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
LoothingPopups:Register("LOOTHING_CONFIRM_DELETE_SET", {
    title = L["BUTTON_SETS"],
    text = "Delete button set '{name}'?",
    modal = true,
    hide_on_escape = true,
    show_while_dead = true,
    on_show = function(dialog, data)
        if data and data.name then
            return string.format("Delete button set '%s'?", data.name)
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
LoothingPopups:Register("LOOTHING_CONFIRM_REANNOUNCE", {
    title = "Re-announce Items",
    text = "Re-announce all items to the group?",
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
LoothingPopups:Register("LOOTHING_CONFIRM_START_SESSION", {
    title = L["START_SESSION"],
    text = "Start loot session for {boss}?",
    modal = true,
    hide_on_escape = true,
    show_while_dead = true,
    on_show = function(dialog, data)
        if data and data.boss then
            return string.format("Start loot session for %s?", data.boss)
        end
        return "Start loot session?"
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
LoothingPopups:Register("LOOTHING_CONFIRM_PROFILE_OVERWRITE", {
    title = "Overwrite Profile",
    text = "This will overwrite your current profile settings. Continue?",
    modal = true,
    hide_on_escape = true,
    show_while_dead = true,
    buttons = {
        {
            text = "Overwrite",
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

--[[--------------------------------------------------------------------
    Convenience Functions
----------------------------------------------------------------------]]

--- Show a simple yes/no confirmation dialog
-- @param title string - Dialog title
-- @param message string - Dialog message
-- @param onYes function - Callback when yes is clicked
-- @param onNo function - Callback when no is clicked (optional)
function LoothingPopups:Confirm(title, message, onYes, onNo)
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
function LoothingPopups:Alert(title, message, onOK)
    local dialog = Loolib.UI.Dialog.Create()
    dialog:SetTitle(title)
    dialog:SetMessage(message)
    dialog:SetModal(true)
    dialog:SetEscapeClose(true)

    dialog:SetButtons({
        {
            text = "OK",
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
function LoothingPopups:Input(title, prompt, defaultValue, onAccept, onCancel)
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

-- Make globally available for easy access
_G.LoothingPopups = LoothingPopups

return LoothingPopups
