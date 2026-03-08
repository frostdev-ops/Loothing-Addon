--[[--------------------------------------------------------------------
    Loothing - Options: Advanced
    Autopass, auto-award, ignore lists, history, and frame config
----------------------------------------------------------------------]]

local L = LOOTHING_LOCALE

local function GetQualityValues()
    return { [0]="Poor", [1]="Common", [2]="Uncommon", [3]="Rare", [4]="Epic", [5]="Legendary" }
end

local function GetChatFrameValues()
    local values = {}
    for i = 1, 10 do
        local name = _G["ChatFrame" .. i] and _G["ChatFrame" .. i].name or ("ChatFrame" .. i)
        values["ChatFrame" .. i] = name
    end
    return values
end

local function GetAdvancedOptions()
    return {
        type = "group",
        name = L["SETTINGS"],
        order = 4,
        childGroups = "tree",
        args = {
            -- ============================================================
            -- AutoPass
            -- ============================================================
            autopass = {
                type = "group",
                name = L["AUTOPASS_SETTINGS"],
                order = 1,
                args = {
                    enabled = {
                        type = "toggle",
                        name = L["ENABLE_AUTOPASS"],
                        desc = L["AUTOPASS_DESC"],
                        order = 1,
                        width = "full",
                        get = function() return Loothing.Settings:GetAutoPassEnabled() end,
                        set = function(_, v) Loothing.Settings:SetAutoPassEnabled(v) end,
                    },
                    weapons = {
                        type = "toggle",
                        name = L["AUTOPASS_WEAPONS"],
                        order = 2,
                        get = function() return Loothing.Settings:GetAutoPassWeapons() end,
                        set = function(_, v) Loothing.Settings:SetAutoPassWeapons(v) end,
                    },
                    boe = {
                        type = "toggle",
                        name = L["CONFIG_AUTOPASS_BOE"] or "AutoPass BoE Items",
                        desc = L["CONFIG_AUTOPASS_BOE_DESC"] or "Automatically pass on Bind on Equip items",
                        order = 3,
                        get = function() return Loothing.Settings:Get("autoPass.boe") end,
                        set = function(_, v) Loothing.Settings:Set("autoPass.boe", v) end,
                    },
                    trinkets = {
                        type = "toggle",
                        name = L["CONFIG_AUTOPASS_TRINKETS"] or "AutoPass Trinkets",
                        desc = L["CONFIG_AUTOPASS_TRINKETS_DESC"] or "Automatically pass on class-restricted trinkets",
                        order = 4,
                        get = function() return Loothing.Settings:Get("autoPass.trinkets") end,
                        set = function(_, v) Loothing.Settings:Set("autoPass.trinkets", v) end,
                    },
                    transmog = {
                        type = "toggle",
                        name = L["CONFIG_AUTOPASS_TRANSMOG"] or "AutoPass Transmog",
                        desc = L["CONFIG_AUTOPASS_TRANSMOG_DESC"] or "Auto-pass items already collected for transmog",
                        order = 5,
                        get = function() return Loothing.Settings:Get("autoPass.transmog") end,
                        set = function(_, v) Loothing.Settings:Set("autoPass.transmog", v) end,
                    },
                    transmogSource = {
                        type = "toggle",
                        name = L["CONFIG_AUTOPASS_TRANSMOG_SOURCE"] or "Skip Known Appearances",
                        desc = L["CONFIG_AUTOPASS_TRANSMOG_SOURCE_DESC"] or "Auto-pass transmog sources already learned",
                        order = 6,
                        get = function() return Loothing.Settings:Get("autoPass.transmogSource") end,
                        set = function(_, v) Loothing.Settings:Set("autoPass.transmogSource", v) end,
                    },
                    silent = {
                        type = "toggle",
                        name = L["CONFIG_AUTOPASS_SILENT"] or "Silent AutoPass",
                        desc = L["CONFIG_AUTOPASS_SILENT_DESC"] or "Don't print auto-pass messages to chat",
                        order = 7,
                        get = function() return Loothing.Settings:Get("autoPass.silent") end,
                        set = function(_, v) Loothing.Settings:Set("autoPass.silent", v) end,
                    },
                },
            },
            -- ============================================================
            -- Auto Award
            -- ============================================================
            autoaward = {
                type = "group",
                name = L["AUTO_AWARD_SETTINGS"],
                order = 2,
                args = {
                    enabled = {
                        type = "toggle",
                        name = L["AUTO_AWARD_ENABLE"],
                        desc = L["AUTO_AWARD_DESC"],
                        order = 1,
                        width = "full",
                        get = function() return Loothing.Settings:GetAutoAwardEnabled() end,
                        set = function(_, v) Loothing.Settings:SetAutoAwardEnabled(v) end,
                    },
                    awardTo = {
                        type = "input",
                        name = L["AUTO_AWARD_TO"],
                        desc = L["AUTO_AWARD_TO_DESC"],
                        order = 2,
                        get = function() return Loothing.Settings:GetAutoAwardTo() end,
                        set = function(_, v) Loothing.Settings:SetAutoAwardTo(v) end,
                    },
                    lowerThreshold = {
                        type = "select",
                        name = L["CONFIG_AUTO_AWARD_LOWER_THRESHOLD"] or "Lower Quality Threshold",
                        desc = L["CONFIG_AUTO_AWARD_LOWER_THRESHOLD_DESC"] or "Minimum quality for auto-award",
                        order = 3,
                        values = GetQualityValues(),
                        get = function() return Loothing.Settings:Get("autoAward.lowerThreshold") end,
                        set = function(_, v) Loothing.Settings:Set("autoAward.lowerThreshold", v) end,
                    },
                    upperThreshold = {
                        type = "select",
                        name = L["CONFIG_AUTO_AWARD_UPPER_THRESHOLD"] or "Upper Quality Threshold",
                        desc = L["CONFIG_AUTO_AWARD_UPPER_THRESHOLD_DESC"] or "Maximum quality for auto-award",
                        order = 4,
                        values = GetQualityValues(),
                        get = function() return Loothing.Settings:Get("autoAward.upperThreshold") end,
                        set = function(_, v) Loothing.Settings:Set("autoAward.upperThreshold", v) end,
                    },
                    reason = {
                        type = "input",
                        name = L["CONFIG_AUTO_AWARD_REASON"] or "Award Reason",
                        desc = L["CONFIG_AUTO_AWARD_REASON_DESC"] or "Reason shown in history for auto-awards",
                        order = 5,
                        get = function() return Loothing.Settings:GetAutoAwardReason() end,
                        set = function(_, v) Loothing.Settings:SetAutoAwardReason(v) end,
                    },
                    includeBoE = {
                        type = "toggle",
                        name = L["CONFIG_AUTO_AWARD_INCLUDE_BOE"] or "Include BoE Items",
                        desc = L["CONFIG_AUTO_AWARD_INCLUDE_BOE_DESC"] or "Include Bind on Equip items in auto-awards",
                        order = 6,
                        get = function() return Loothing.Settings:GetAutoAwardIncludeBoE() end,
                        set = function(_, v) Loothing.Settings:SetAutoAwardIncludeBoE(v) end,
                    },
                },
            },
            -- ============================================================
            -- Ignore Items
            -- ============================================================
            ignore = {
                type = "group",
                name = L["IGNORE_ITEMS_SETTINGS"],
                order = 3,
                args = {
                    enabled = {
                        type = "toggle",
                        name = L["ENABLE_IGNORE_LIST"],
                        desc = L["IGNORE_LIST_DESC"],
                        order = 1,
                        width = "full",
                        get = function() return Loothing.Settings:GetIgnoreItemsEnabled() end,
                        set = function(_, v) Loothing.Settings:SetIgnoreItemsEnabled(v) end,
                    },
                    ignoreEnchantingMaterials = {
                        type = "toggle",
                        name = L["CONFIG_IGNORE_ENCHANTING_MATS"] or "Ignore Enchanting Materials",
                        order = 2,
                        get = function() return Loothing.Settings:GetIgnoreEnchantingMaterials() end,
                        set = function(_, v) Loothing.Settings:SetIgnoreEnchantingMaterials(v) end,
                    },
                    ignoreCraftingReagents = {
                        type = "toggle",
                        name = L["CONFIG_IGNORE_CRAFTING_REAGENTS"] or "Ignore Crafting Reagents",
                        order = 3,
                        get = function() return Loothing.Settings:GetIgnoreCraftingReagents() end,
                        set = function(_, v) Loothing.Settings:SetIgnoreCraftingReagents(v) end,
                    },
                    ignoreConsumables = {
                        type = "toggle",
                        name = L["CONFIG_IGNORE_CONSUMABLES"] or "Ignore Consumables",
                        order = 4,
                        get = function() return Loothing.Settings:GetIgnoreConsumables() end,
                        set = function(_, v) Loothing.Settings:SetIgnoreConsumables(v) end,
                    },
                    ignorePermanentEnhancements = {
                        type = "toggle",
                        name = L["CONFIG_IGNORE_PERMANENT_ENHANCEMENTS"] or "Ignore Permanent Enhancements",
                        desc = L["CONFIG_IGNORE_PERMANENT_ENHANCEMENTS_DESC"] or "Gems, enchants, and other permanent enhancements",
                        order = 5,
                        get = function() return Loothing.Settings:GetIgnorePermanentEnhancements() end,
                        set = function(_, v) Loothing.Settings:SetIgnorePermanentEnhancements(v) end,
                    },
                },
            },
            -- ============================================================
            -- Frame Behavior
            -- ============================================================
            frame = {
                type = "group",
                name = L["CONFIG_FRAME_BEHAVIOR"] or "Frame Behavior",
                order = 4,
                args = {
                    autoOpen = {
                        type = "toggle",
                        name = L["CONFIG_FRAME_AUTO_OPEN"] or "Auto-Open Frames",
                        desc = L["CONFIG_FRAME_AUTO_OPEN_DESC"] or "Automatically show frames when loot is available",
                        order = 1,
                        get = function() return Loothing.Settings:Get("frame.autoOpen") end,
                        set = function(_, v) Loothing.Settings:Set("frame.autoOpen", v) end,
                    },
                    autoClose = {
                        type = "toggle",
                        name = L["CONFIG_FRAME_AUTO_CLOSE"] or "Auto-Close Frames",
                        desc = L["CONFIG_FRAME_AUTO_CLOSE_DESC"] or "Automatically close frames when session ends",
                        order = 2,
                        get = function() return Loothing.Settings:Get("frame.autoClose") end,
                        set = function(_, v) Loothing.Settings:Set("frame.autoClose", v) end,
                    },
                    minimizeInCombat = {
                        type = "toggle",
                        name = L["CONFIG_FRAME_MINIMIZE_COMBAT"] or "Minimize in Combat",
                        desc = L["CONFIG_FRAME_MINIMIZE_COMBAT_DESC"] or "Minimize frames during combat",
                        order = 3,
                        get = function() return Loothing.Settings:Get("frame.minimizeInCombat") end,
                        set = function(_, v) Loothing.Settings:Set("frame.minimizeInCombat", v) end,
                    },
                    showSpecIcon = {
                        type = "toggle",
                        name = L["CONFIG_FRAME_SHOW_SPEC_ICON"] or "Show Spec Icons",
                        desc = L["CONFIG_FRAME_SHOW_SPEC_ICON_DESC"] or "Show specialization icons instead of class icons",
                        order = 4,
                        get = function() return Loothing.Settings:Get("frame.showSpecIcon") end,
                        set = function(_, v) Loothing.Settings:Set("frame.showSpecIcon", v) end,
                    },
                    closeWithEscape = {
                        type = "toggle",
                        name = L["CONFIG_FRAME_CLOSE_ESCAPE"] or "Close with Escape",
                        desc = L["CONFIG_FRAME_CLOSE_ESCAPE_DESC"] or "Allow Escape key to close Loothing frames",
                        order = 5,
                        get = function() return Loothing.Settings:Get("frame.closeWithEscape") end,
                        set = function(_, v) Loothing.Settings:Set("frame.closeWithEscape", v) end,
                    },
                    timeoutFlash = {
                        type = "toggle",
                        name = L["CONFIG_FRAME_TIMEOUT_FLASH"] or "Flash on Timeout",
                        desc = L["CONFIG_FRAME_TIMEOUT_FLASH_DESC"] or "Flash the taskbar icon when voting times out",
                        order = 6,
                        get = function() return Loothing.Settings:Get("frame.timeoutFlash") end,
                        set = function(_, v) Loothing.Settings:Set("frame.timeoutFlash", v) end,
                    },
                    blockTradesDuringVoting = {
                        type = "toggle",
                        name = L["CONFIG_FRAME_BLOCK_TRADES"] or "Block Trades During Voting",
                        desc = L["CONFIG_FRAME_BLOCK_TRADES_DESC"] or "Prevent trading items while voting is active",
                        order = 7,
                        get = function() return Loothing.Settings:Get("frame.blockTradesDuringVoting") end,
                        set = function(_, v) Loothing.Settings:Set("frame.blockTradesDuringVoting", v) end,
                    },
                    chatFrameName = {
                        type = "select",
                        name = L["CONFIG_FRAME_CHAT_OUTPUT"] or "Chat Output Frame",
                        desc = L["CONFIG_FRAME_CHAT_OUTPUT_DESC"] or "Which chat frame to use for Loothing messages",
                        order = 8,
                        values = GetChatFrameValues(),
                        get = function() return Loothing.Settings:Get("frame.chatFrameName") end,
                        set = function(_, v) Loothing.Settings:Set("frame.chatFrameName", v) end,
                    },
                },
            },
            -- ============================================================
            -- ML Settings
            -- ============================================================
            ml = {
                type = "group",
                name = L["CONFIG_ML_SETTINGS"] or "ML Settings",
                order = 5,
                args = {
                    usageMode = {
                        type = "select",
                        name = L["CONFIG_ML_USAGE_MODE"] or "Usage Mode",
                        desc = L["CONFIG_ML_USAGE_MODE_DESC"] or "When to activate Loothing as loot master",
                        order = 1,
                        values = {
                            never = L["CONFIG_ML_USAGE_NEVER"] or "Never",
                            gl = L["CONFIG_ML_USAGE_GL"] or "Group Loot",
                            ask_gl = L["CONFIG_ML_USAGE_ASK_GL"] or "Ask on Group Loot",
                        },
                        sorting = { "never", "gl", "ask_gl" },
                        get = function() return Loothing.Settings:Get("ml.usageMode") end,
                        set = function(_, v) Loothing.Settings:Set("ml.usageMode", v) end,
                    },
                    onlyUseInRaids = {
                        type = "toggle",
                        name = L["CONFIG_ML_RAIDS_ONLY"] or "Raids Only",
                        desc = L["CONFIG_ML_RAIDS_ONLY_DESC"] or "Only activate in raid instances",
                        order = 2,
                        get = function() return Loothing.Settings:Get("ml.onlyUseInRaids") end,
                        set = function(_, v) Loothing.Settings:Set("ml.onlyUseInRaids", v) end,
                    },
                    allowOutOfRaid = {
                        type = "toggle",
                        name = L["CONFIG_ML_ALLOW_OUTSIDE"] or "Allow Outside Raids",
                        desc = L["CONFIG_ML_ALLOW_OUTSIDE_DESC"] or "Allow loot handling outside raid instances",
                        order = 3,
                        get = function() return Loothing.Settings:Get("ml.allowOutOfRaid") end,
                        set = function(_, v) Loothing.Settings:Set("ml.allowOutOfRaid", v) end,
                    },
                    skipSessionFrame = {
                        type = "toggle",
                        name = L["CONFIG_ML_SKIP_SESSION"] or "Skip Session Frame",
                        desc = L["CONFIG_ML_SKIP_SESSION_DESC"] or "Start sessions immediately without the session setup frame",
                        order = 4,
                        get = function() return Loothing.Settings:Get("ml.skipSessionFrame") end,
                        set = function(_, v) Loothing.Settings:Set("ml.skipSessionFrame", v) end,
                    },
                    sortItems = {
                        type = "toggle",
                        name = L["CONFIG_ML_SORT_ITEMS"] or "Sort Items",
                        desc = L["CONFIG_ML_SORT_ITEMS_DESC"] or "Automatically sort items by type and item level",
                        order = 5,
                        get = function() return Loothing.Settings:Get("ml.sortItems") end,
                        set = function(_, v) Loothing.Settings:Set("ml.sortItems", v) end,
                    },
                    autoAddBoEs = {
                        type = "toggle",
                        name = L["CONFIG_ML_AUTO_ADD_BOES"] or "Auto-Add BoEs",
                        desc = L["CONFIG_ML_AUTO_ADD_BOES_DESC"] or "Automatically add Bind on Equip items to sessions",
                        order = 6,
                        get = function() return Loothing.Settings:Get("ml.autoAddBoEs") end,
                        set = function(_, v) Loothing.Settings:Set("ml.autoAddBoEs", v) end,
                    },
                    printCompletedTrades = {
                        type = "toggle",
                        name = L["CONFIG_ML_PRINT_TRADES"] or "Print Completed Trades",
                        desc = L["CONFIG_ML_PRINT_TRADES_DESC"] or "Print a message when a trade is completed",
                        order = 7,
                        get = function() return Loothing.Settings:Get("ml.printCompletedTrades") end,
                        set = function(_, v) Loothing.Settings:Set("ml.printCompletedTrades", v) end,
                    },
                    rejectTrade = {
                        type = "toggle",
                        name = L["CONFIG_ML_REJECT_TRADE"] or "Reject Invalid Trades",
                        desc = L["CONFIG_ML_REJECT_TRADE_DESC"] or "Automatically reject trades that aren't part of a session",
                        order = 8,
                        get = function() return Loothing.Settings:Get("ml.rejectTrade") end,
                        set = function(_, v) Loothing.Settings:Set("ml.rejectTrade", v) end,
                    },
                    awardLater = {
                        type = "toggle",
                        name = L["CONFIG_ML_AWARD_LATER"] or "Award Later",
                        desc = L["CONFIG_ML_AWARD_LATER_DESC"] or "Allow ML to bag items and award them later",
                        order = 9,
                        get = function() return Loothing.Settings:Get("ml.awardLater") end,
                        set = function(_, v) Loothing.Settings:Set("ml.awardLater", v) end,
                    },
                },
            },
            -- ============================================================
            -- History
            -- ============================================================
            history = {
                type = "group",
                name = L["CONFIG_HISTORY_SETTINGS"] or "History Settings",
                order = 6,
                args = {
                    enabled = {
                        type = "toggle",
                        name = L["CONFIG_HISTORY_ENABLED"] or "Enable History",
                        desc = L["CONFIG_HISTORY_ENABLED_DESC"] or "Record loot awards to history",
                        order = 1,
                        width = "full",
                        get = function() return Loothing.Settings:Get("historySettings.enabled", true) end,
                        set = function(_, v) Loothing.Settings:Set("historySettings.enabled", v) end,
                    },
                    clearAll = {
                        type = "execute",
                        name = L["CONFIG_HISTORY_CLEAR_ALL"] or "Clear All History",
                        desc = L["CONFIG_HISTORY_CLEAR_ALL_DESC"] or "Delete all history entries",
                        order = 2,
                        func = function()
                            if Loothing.History then
                                Loothing.History:ClearHistory()
                                Loothing:Print("All history cleared")
                                if LoolibConfig and LoolibConfig.Dialog then
                                    LoolibConfig.Dialog:RefreshContent("Loothing")
                                end
                            end
                        end,
                        confirm = function()
                            return "Are you sure you want to delete ALL history entries? This cannot be undone!"
                        end,
                    },
                    sendHistory = {
                        type = "toggle",
                        name = L["CONFIG_HISTORY_SEND"] or "Send History",
                        desc = L["CONFIG_HISTORY_SEND_DESC"] or "Broadcast history entries to group members",
                        order = 3,
                        get = function() return Loothing.Settings:Get("historySettings.sendHistory") end,
                        set = function(_, v) Loothing.Settings:Set("historySettings.sendHistory", v) end,
                    },
                    sendToGuild = {
                        type = "toggle",
                        name = L["CONFIG_HISTORY_SEND_GUILD"] or "Send to Guild",
                        desc = L["CONFIG_HISTORY_SEND_GUILD_DESC"] or "Broadcast history to guild channel",
                        order = 4,
                        get = function() return Loothing.Settings:Get("historySettings.sendToGuild") end,
                        set = function(_, v) Loothing.Settings:Set("historySettings.sendToGuild", v) end,
                    },
                    savePersonalLoot = {
                        type = "toggle",
                        name = L["CONFIG_HISTORY_SAVE_PL"] or "Save Personal Loot",
                        desc = L["CONFIG_HISTORY_SAVE_PL_DESC"] or "Record personal loot in history",
                        order = 5,
                        get = function() return Loothing.Settings:Get("historySettings.savePersonalLoot") end,
                        set = function(_, v) Loothing.Settings:Set("historySettings.savePersonalLoot", v) end,
                    },
                },
            },
        },
    }
end

Loothing.Options = Loothing.Options or {}
Loothing.Options.GetAdvancedOptions = GetAdvancedOptions
