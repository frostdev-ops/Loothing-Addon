--[[--------------------------------------------------------------------
    Loothing - Options: Personal Preferences (local only)
    These settings only affect you. They are not broadcast to the raid.
----------------------------------------------------------------------]]

local ADDON_NAME, ns = ...
local Loolib = LibStub("Loolib")
local Loothing = ns.Addon
local Options = ns.Options or {}
ns.Options = Options

local L = ns.Locale

local function GetQualityValues()
    return { [0]=L["QUALITY_POOR"], [1]=L["QUALITY_COMMON"], [2]=L["QUALITY_UNCOMMON"], [3]=L["QUALITY_RARE"], [4]=L["QUALITY_EPIC"], [5]=L["QUALITY_LEGENDARY"] }
end

local function GetChatFrameValues()
    local values = {}
    for i = 1, 10 do
        local name = _G["ChatFrame" .. i] and _G["ChatFrame" .. i].name or ("ChatFrame" .. i)
        values["ChatFrame" .. i] = name
    end
    return values
end

local function GetChannelValues()
    return {
        RAID = L["CHANNEL_RAID"],
        RAID_WARNING = L["CHANNEL_RAID_WARNING"],
        OFFICER = L["CHANNEL_OFFICER"],
        GUILD = L["CHANNEL_GUILD"],
        PARTY = L["CHANNEL_PARTY"],
        NONE = L["CHANNEL_NONE"],
    }
end

--- Generates option args for 5 configurable announcement lines.
local function MakeLineOptions(getLineFn, setLineFn, prefix)
    local args = {
        desc = {
            type = "description",
            name = L["CONFIG_ANNOUNCEMENT_TOKENS_DESC"],
            order = 0,
        },
    }
    for i = 1, 5 do
        local baseOrder = i * 10
        args[prefix .. i .. "Header"] = {
            type = "header",
            name = (L["CONFIG_LINE"]) .. " " .. i,
            order = baseOrder,
        }
        args[prefix .. i .. "Enabled"] = {
            type = "toggle",
            name = L["CONFIG_ENABLED"],
            order = baseOrder + 1,
            width = "half",
            get = function()
                local line = getLineFn(i)
                return line and line.enabled
            end,
            set = function(_, v)
                local line = getLineFn(i) or {}
                setLineFn(i, v, line.channel or "RAID", line.text or "")
            end,
        }
        args[prefix .. i .. "Channel"] = {
            type = "select",
            name = L["CONFIG_CHANNEL"],
            order = baseOrder + 2,
            values = GetChannelValues(),
            get = function()
                local line = getLineFn(i)
                return line and line.channel or "RAID"
            end,
            set = function(_, v)
                local line = getLineFn(i) or {}
                setLineFn(i, line.enabled, v, line.text or "")
            end,
        }
        args[prefix .. i .. "Text"] = {
            type = "input",
            name = L["CONFIG_MESSAGE"],
            order = baseOrder + 3,
            width = "full",
            get = function()
                local line = getLineFn(i)
                return line and line.text or ""
            end,
            set = function(_, v)
                local line = getLineFn(i) or {}
                setLineFn(i, line.enabled, line.channel or "RAID", v)
            end,
        }
    end
    return args
end

local function GetLocalPreferencesOptions()
    return {
        type = "group",
        name = L["PERSONAL_PREFERENCES"],
        desc = L["CONFIG_LOCAL_PREFS_DESC"],
        order = 2,
        childGroups = "tree",
        args = {
            localPrefsDesc = {
                type = "description",
                name = "|cff88ccff" .. L["CONFIG_LOCAL_PREFS_NOTE"] .. "|r",
                order = 0,
                fontSize = "medium",
                width = "full",
            },
            -- ============================================================
            -- Loot Response (RollFrame)
            -- ============================================================
            lootResponse = {
                type = "group",
                name = L["CONFIG_LOOT_RESPONSE"],
                order = 1,
                columns = 3,
                args = {
                    brainrotMode = {
                        type = "toggle",
                        name = L["CONFIG_BRAINROT_MODE"],
                        desc = L["CONFIG_BRAINROT_MODE_DESC"],
                        order = 0,
                        width = "double",
                        get = function()
                            local db = _G.LoolibDB
                            if type(db) == "table" and type(db._brainrotMode) == "table" then
                                return db._brainrotMode[ADDON_NAME] == true
                            end
                            return false
                        end,
                        set = function(_, value)
                            local db = _G.LoolibDB
                            if type(db) ~= "table" then
                                _G.LoolibDB = {}
                                db = _G.LoolibDB
                            end
                            if not db._brainrotMode then
                                db._brainrotMode = {}
                            end
                            db._brainrotMode[ADDON_NAME] = value or nil
                            print("|cFF33FF99Loothing|r: " .. L["CONFIG_BRAINROT_MODE_DESC"])
                        end,
                    },
                    autoShow = {
                        type = "toggle",
                        name = L["CONFIG_ROLLFRAME_AUTO_SHOW"],
                        desc = L["CONFIG_ROLLFRAME_AUTO_SHOW_DESC"],
                        order = 1,
                        width = "half",
                        get = function() return Loothing.Settings:Get("rollFrame.autoShow", true) ~= false end,
                        set = function(_, v) Loothing.Settings:Set("rollFrame.autoShow", v) end,
                    },
                    autoRollOnSubmit = {
                        type = "toggle",
                        name = L["CONFIG_ROLLFRAME_AUTO_ROLL"],
                        desc = L["CONFIG_ROLLFRAME_AUTO_ROLL_DESC"],
                        order = 2,
                        width = "half",
                        get = function() return Loothing.Settings:Get("rollFrame.autoRollOnSubmit", false) end,
                        set = function(_, v) Loothing.Settings:Set("rollFrame.autoRollOnSubmit", v) end,
                    },
                    showGearComparison = {
                        type = "toggle",
                        name = L["CONFIG_ROLLFRAME_GEAR_COMPARE"],
                        desc = L["CONFIG_ROLLFRAME_GEAR_COMPARE_DESC"],
                        order = 3,
                        width = "half",
                        get = function() return Loothing.Settings:Get("rollFrame.showGearComparison", true) ~= false end,
                        set = function(_, v) Loothing.Settings:Set("rollFrame.showGearComparison", v) end,
                    },
                    requireNote = {
                        type = "toggle",
                        name = L["CONFIG_ROLLFRAME_REQUIRE_NOTE"],
                        desc = L["CONFIG_ROLLFRAME_REQUIRE_NOTE_DESC"],
                        order = 4,
                        width = "half",
                        get = function() return Loothing.Settings:Get("rollFrame.requireNote", false) end,
                        set = function(_, v) Loothing.Settings:Set("rollFrame.requireNote", v) end,
                    },
                    printResponseToChat = {
                        type = "toggle",
                        name = L["CONFIG_ROLLFRAME_PRINT_RESPONSE"],
                        desc = L["CONFIG_ROLLFRAME_PRINT_RESPONSE_DESC"],
                        order = 5,
                        width = "half",
                        get = function() return Loothing.Settings:Get("rollFrame.printResponseToChat", false) end,
                        set = function(_, v) Loothing.Settings:Set("rollFrame.printResponseToChat", v) end,
                    },
                    responseTimerHeader = {
                        type = "header",
                        name = L["CONFIG_ROLLFRAME_TIMER"],
                        order = 10,
                    },
                    rollFrameTimeoutEnabled = {
                        type = "toggle",
                        name = L["CONFIG_ROLLFRAME_TIMER_ENABLED"],
                        desc = L["CONFIG_ROLLFRAME_TIMER_ENABLED_DESC"],
                        order = 11,
                        get = function()
                            local enabled = Loothing.Settings:GetRollFrameTimeoutEnabled()
                            local duration = Loothing.Settings:GetRollFrameTimeoutDuration()
                            return enabled and duration ~= Loothing.Timing.NO_TIMEOUT
                        end,
                        set = function(_, v)
                            Loothing.Settings:SetRollFrameTimeoutEnabled(v)
                            if not v then
                                Loothing.Settings:SetRollFrameTimeoutDuration(Loothing.Timing.NO_TIMEOUT)
                            elseif Loothing.Settings:GetRollFrameTimeoutDuration() == Loothing.Timing.NO_TIMEOUT then
                                Loothing.Settings:SetRollFrameTimeoutDuration(Loothing.Timing.DEFAULT_ROLL_TIMEOUT)
                            end
                        end,
                    },
                    rollFrameTimeoutDuration = {
                        type = "range",
                        name = L["CONFIG_ROLLFRAME_TIMER_DURATION"],
                        desc = L["SECONDS"],
                        order = 12,
                        min = Loothing.Timing.MIN_ROLL_TIMEOUT,
                        max = Loothing.Timing.MAX_ROLL_TIMEOUT,
                        step = 5,
                        hidden = function()
                            local enabled = Loothing.Settings:GetRollFrameTimeoutEnabled()
                            local duration = Loothing.Settings:GetRollFrameTimeoutDuration()
                            return not enabled or duration == Loothing.Timing.NO_TIMEOUT
                        end,
                        get = function() return Loothing.Settings:GetRollFrameTimeoutDuration() end,
                        set = function(_, v) Loothing.Settings:SetRollFrameTimeoutDuration(v) end,
                    },
                },
            },
            -- ============================================================
            -- AutoPass
            -- ============================================================
            autopass = {
                type = "group",
                name = L["AUTOPASS_SETTINGS"],
                order = 2,
                columns = 3,
                args = {
                    enabled = {
                        type = "toggle",
                        name = L["ENABLE_AUTOPASS"],
                        desc = L["AUTOPASS_DESC"],
                        order = 1,
                        width = "half",
                        get = function() return Loothing.Settings:GetAutoPassEnabled() end,
                        set = function(_, v) Loothing.Settings:SetAutoPassEnabled(v) end,
                    },
                    weapons = {
                        type = "toggle",
                        name = L["AUTOPASS_WEAPONS"],
                        order = 2,
                        width = "half",
                        get = function() return Loothing.Settings:GetAutoPassWeapons() end,
                        set = function(_, v) Loothing.Settings:SetAutoPassWeapons(v) end,
                    },
                    boe = {
                        type = "toggle",
                        name = L["CONFIG_AUTOPASS_BOE"],
                        desc = L["CONFIG_AUTOPASS_BOE_DESC"],
                        order = 3,
                        width = "half",
                        get = function() return Loothing.Settings:Get("autoPass.boe") end,
                        set = function(_, v) Loothing.Settings:Set("autoPass.boe", v) end,
                    },
                    trinkets = {
                        type = "toggle",
                        name = L["CONFIG_AUTOPASS_TRINKETS"],
                        order = 4,
                        width = "half",
                        get = function() return Loothing.Settings:Get("autoPass.trinkets") end,
                        set = function(_, v) Loothing.Settings:Set("autoPass.trinkets", v) end,
                    },
                    transmog = {
                        type = "toggle",
                        name = L["CONFIG_AUTOPASS_TRANSMOG"],
                        order = 5,
                        width = "half",
                        get = function() return Loothing.Settings:Get("autoPass.transmog") end,
                        set = function(_, v) Loothing.Settings:Set("autoPass.transmog", v) end,
                    },
                    transmogSource = {
                        type = "toggle",
                        name = L["CONFIG_AUTOPASS_TRANSMOG_SOURCE"],
                        order = 6,
                        width = "half",
                        get = function() return Loothing.Settings:Get("autoPass.transmogSource") end,
                        set = function(_, v) Loothing.Settings:Set("autoPass.transmogSource", v) end,
                    },
                    silent = {
                        type = "toggle",
                        name = L["CONFIG_AUTOPASS_SILENT"],
                        order = 7,
                        width = "half",
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
                order = 3,
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
                        name = L["CONFIG_AUTO_AWARD_LOWER_THRESHOLD"],
                        order = 3,
                        values = GetQualityValues(),
                        get = function() return Loothing.Settings:Get("autoAward.lowerThreshold") end,
                        set = function(_, v) Loothing.Settings:Set("autoAward.lowerThreshold", v) end,
                    },
                    upperThreshold = {
                        type = "select",
                        name = L["CONFIG_AUTO_AWARD_UPPER_THRESHOLD"],
                        order = 4,
                        values = GetQualityValues(),
                        get = function() return Loothing.Settings:Get("autoAward.upperThreshold") end,
                        set = function(_, v) Loothing.Settings:Set("autoAward.upperThreshold", v) end,
                    },
                    reason = {
                        type = "input",
                        name = L["CONFIG_AUTO_AWARD_REASON"],
                        order = 5,
                        get = function() return Loothing.Settings:GetAutoAwardReason() end,
                        set = function(_, v) Loothing.Settings:SetAutoAwardReason(v) end,
                    },
                    includeBoE = {
                        type = "toggle",
                        name = L["CONFIG_AUTO_AWARD_INCLUDE_BOE"],
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
                order = 4,
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
                    catHeader = {
                        type = "header",
                        name = L["IGNORE_CATEGORIES"],
                        order = 2,
                    },
                    ignoreEnchantingMaterials = {
                        type = "toggle",
                        name = L["CONFIG_IGNORE_ENCHANTING_MATS"],
                        order = 3,
                        get = function() return Loothing.Settings:GetIgnoreEnchantingMaterials() end,
                        set = function(_, v) Loothing.Settings:SetIgnoreEnchantingMaterials(v) end,
                    },
                    ignoreCraftingReagents = {
                        type = "toggle",
                        name = L["CONFIG_IGNORE_CRAFTING_REAGENTS"],
                        order = 4,
                        get = function() return Loothing.Settings:GetIgnoreCraftingReagents() end,
                        set = function(_, v) Loothing.Settings:SetIgnoreCraftingReagents(v) end,
                    },
                    ignoreConsumables = {
                        type = "toggle",
                        name = L["CONFIG_IGNORE_CONSUMABLES"],
                        order = 5,
                        get = function() return Loothing.Settings:GetIgnoreConsumables() end,
                        set = function(_, v) Loothing.Settings:SetIgnoreConsumables(v) end,
                    },
                    ignorePermanentEnhancements = {
                        type = "toggle",
                        name = L["CONFIG_IGNORE_PERMANENT_ENHANCEMENTS"],
                        order = 6,
                        get = function() return Loothing.Settings:GetIgnorePermanentEnhancements() end,
                        set = function(_, v) Loothing.Settings:SetIgnorePermanentEnhancements(v) end,
                    },
                    itemsHeader = {
                        type = "header",
                        name = L["IGNORED_ITEMS"],
                        order = 10,
                    },
                    itemListDesc = {
                        type = "description",
                        name = function()
                            local items = Loothing.Settings:GetIgnoredItems()
                            if not next(items) then
                                return L["NO_IGNORED_ITEMS"]
                            end
                            local lines = {}
                            for itemID in pairs(items) do
                                local itemName = C_Item.GetItemNameByID(itemID)
                                if itemName then
                                    lines[#lines + 1] = string.format("  [%d] %s", itemID, itemName)
                                else
                                    lines[#lines + 1] = string.format("  [%d]", itemID)
                                end
                            end
                            table.sort(lines)
                            return table.concat(lines, "\n")
                        end,
                        order = 11,
                        fontSize = "medium",
                    },
                    addItemInput = {
                        type = "input",
                        name = L["ADD_IGNORED_ITEM"],
                        desc = L["IGNORE_ADD_DESC"],
                        order = 12,
                        width = "double",
                        get = function() return "" end,
                        set = function(_, value)
                            value = strtrim(value)
                            if value == "" then return end
                            local itemID = tonumber(value)
                                or tonumber(value:match("item:(%d+)"))
                            if not itemID then
                                print("|cFF33FF99Loothing|r: " .. (L["SLASH_INVALID_ITEM"]))
                                return
                            end
                            Loothing.Settings:AddIgnoredItem(itemID)
                            local itemName = C_Item.GetItemNameByID(itemID) or tostring(itemID)
                            print("|cFF33FF99Loothing|r: " .. string.format(
                                L["ITEM_IGNORED"], itemName))
                            if Loolib.Config then Loolib.Config:NotifyChange("Loothing") end
                        end,
                    },
                    removeItemSelect = {
                        type = "select",
                        name = L["REMOVE_IGNORED_ITEM"],
                        order = 13,
                        width = "double",
                        values = function()
                            local items = Loothing.Settings:GetIgnoredItems()
                            local list = {}
                            for itemID in pairs(items) do
                                local itemName = C_Item.GetItemNameByID(itemID)
                                if itemName then
                                    list[itemID] = string.format("%s (%d)", itemName, itemID)
                                else
                                    list[itemID] = tostring(itemID)
                                end
                            end
                            return list
                        end,
                        get = function() return nil end,
                        set = function(_, value)
                            Loothing.Settings:RemoveIgnoredItem(value)
                            local itemName = C_Item.GetItemNameByID(value) or tostring(value)
                            print("|cFF33FF99Loothing|r: " .. string.format(
                                L["ITEM_UNIGNORED"], itemName))
                            if Loolib.Config then Loolib.Config:NotifyChange("Loothing") end
                        end,
                        hidden = function()
                            return not next(Loothing.Settings:GetIgnoredItems())
                        end,
                    },
                    clearBtn = {
                        type = "execute",
                        name = L["CLEAR_IGNORED_ITEMS"],
                        order = 14,
                        confirm = true,
                        confirmText = L["CONFIRM_CLEAR_IGNORED"],
                        func = function()
                            Loothing.Settings:ClearIgnoredItems()
                            print("|cFF33FF99Loothing|r: " .. (L["IGNORED_ITEMS_CLEARED"]))
                            if Loolib.Config then Loolib.Config:NotifyChange("Loothing") end
                        end,
                        hidden = function()
                            return not next(Loothing.Settings:GetIgnoredItems())
                        end,
                    },
                },
            },
            -- ============================================================
            -- Frame Behavior
            -- ============================================================
            frame = {
                type = "group",
                name = L["CONFIG_FRAME_BEHAVIOR"],
                order = 5,
                columns = 3,
                args = {
                    autoOpen = {
                        type = "toggle",
                        name = L["CONFIG_FRAME_AUTO_OPEN"],
                        order = 1,
                        width = "half",
                        get = function() return Loothing.Settings:Get("frame.autoOpen") end,
                        set = function(_, v) Loothing.Settings:Set("frame.autoOpen", v) end,
                    },
                    autoClose = {
                        type = "toggle",
                        name = L["CONFIG_FRAME_AUTO_CLOSE"],
                        order = 2,
                        width = "half",
                        get = function() return Loothing.Settings:Get("frame.autoClose") end,
                        set = function(_, v) Loothing.Settings:Set("frame.autoClose", v) end,
                    },
                    minimizeInCombat = {
                        type = "toggle",
                        name = L["CONFIG_FRAME_MINIMIZE_COMBAT"],
                        order = 3,
                        width = "half",
                        get = function() return Loothing.Settings:Get("frame.minimizeInCombat") end,
                        set = function(_, v) Loothing.Settings:Set("frame.minimizeInCombat", v) end,
                    },
                    showSpecIcon = {
                        type = "toggle",
                        name = L["CONFIG_FRAME_SHOW_SPEC_ICON"],
                        order = 4,
                        width = "half",
                        get = function() return Loothing.Settings:Get("frame.showSpecIcon") end,
                        set = function(_, v) Loothing.Settings:Set("frame.showSpecIcon", v) end,
                    },
                    closeWithEscape = {
                        type = "toggle",
                        name = L["CONFIG_FRAME_CLOSE_ESCAPE"],
                        order = 5,
                        width = "half",
                        get = function() return Loothing.Settings:Get("frame.closeWithEscape") end,
                        set = function(_, v) Loothing.Settings:Set("frame.closeWithEscape", v) end,
                    },
                    timeoutFlash = {
                        type = "toggle",
                        name = L["CONFIG_FRAME_TIMEOUT_FLASH"],
                        order = 6,
                        width = "half",
                        get = function() return Loothing.Settings:Get("frame.timeoutFlash") end,
                        set = function(_, v) Loothing.Settings:Set("frame.timeoutFlash", v) end,
                    },
                    blockTradesDuringVoting = {
                        type = "toggle",
                        name = L["CONFIG_FRAME_BLOCK_TRADES"],
                        order = 7,
                        width = "half",
                        get = function() return Loothing.Settings:Get("frame.blockTradesDuringVoting") end,
                        set = function(_, v) Loothing.Settings:Set("frame.blockTradesDuringVoting", v) end,
                    },
                    chatFrameName = {
                        type = "select",
                        name = L["CONFIG_FRAME_CHAT_OUTPUT"],
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
                name = L["CONFIG_ML_SETTINGS"],
                order = 6,
                columns = 3,
                args = {
                    usageMode = {
                        type = "select",
                        name = L["CONFIG_ML_USAGE_MODE"],
                        order = 1,
                        values = {
                            never = L["CONFIG_ML_USAGE_NEVER"],
                            gl = L["CONFIG_ML_USAGE_GL"],
                            ask_gl = L["CONFIG_ML_USAGE_ASK_GL"],
                        },
                        sorting = { "never", "gl", "ask_gl" },
                        get = function() return Loothing.Settings:Get("ml.usageMode") end,
                        set = function(_, v) Loothing.Settings:Set("ml.usageMode", v) end,
                    },
                    onlyUseInRaids = {
                        type = "toggle",
                        name = L["CONFIG_ML_RAIDS_ONLY"],
                        order = 2,
                        width = "half",
                        get = function() return Loothing.Settings:Get("ml.onlyUseInRaids") end,
                        set = function(_, v) Loothing.Settings:Set("ml.onlyUseInRaids", v) end,
                    },
                    allowOutOfRaid = {
                        type = "toggle",
                        name = L["CONFIG_ML_ALLOW_OUTSIDE"],
                        order = 3,
                        width = "half",
                        get = function() return Loothing.Settings:Get("ml.allowOutOfRaid") end,
                        set = function(_, v) Loothing.Settings:Set("ml.allowOutOfRaid", v) end,
                    },
                    skipSessionFrame = {
                        type = "toggle",
                        name = L["CONFIG_ML_SKIP_SESSION"],
                        order = 4,
                        width = "half",
                        get = function() return Loothing.Settings:Get("ml.skipSessionFrame") end,
                        set = function(_, v) Loothing.Settings:Set("ml.skipSessionFrame", v) end,
                    },
                    sortItems = {
                        type = "toggle",
                        name = L["CONFIG_ML_SORT_ITEMS"],
                        order = 5,
                        width = "half",
                        get = function() return Loothing.Settings:Get("ml.sortItems") end,
                        set = function(_, v) Loothing.Settings:Set("ml.sortItems", v) end,
                    },
                    autoAddBoEs = {
                        type = "toggle",
                        name = L["CONFIG_ML_AUTO_ADD_BOES"],
                        order = 6,
                        width = "half",
                        get = function() return Loothing.Settings:Get("ml.autoAddBoEs") end,
                        set = function(_, v) Loothing.Settings:Set("ml.autoAddBoEs", v) end,
                    },
                    printCompletedTrades = {
                        type = "toggle",
                        name = L["CONFIG_ML_PRINT_TRADES"],
                        order = 7,
                        width = "half",
                        get = function() return Loothing.Settings:Get("ml.printCompletedTrades") end,
                        set = function(_, v) Loothing.Settings:Set("ml.printCompletedTrades", v) end,
                    },
                    rejectTrade = {
                        type = "toggle",
                        name = L["CONFIG_ML_REJECT_TRADE"],
                        order = 8,
                        width = "half",
                        get = function() return Loothing.Settings:Get("ml.rejectTrade") end,
                        set = function(_, v) Loothing.Settings:Set("ml.rejectTrade", v) end,
                    },
                    awardLater = {
                        type = "toggle",
                        name = L["CONFIG_ML_AWARD_LATER"],
                        order = 9,
                        width = "half",
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
                name = L["CONFIG_HISTORY_SETTINGS"],
                order = 7,
                columns = 3,
                args = {
                    enabled = {
                        type = "toggle",
                        name = L["CONFIG_HISTORY_ENABLED"],
                        order = 1,
                        width = "half",
                        get = function() return Loothing.Settings:Get("historySettings.enabled", true) end,
                        set = function(_, v) Loothing.Settings:Set("historySettings.enabled", v) end,
                    },
                    clearAll = {
                        type = "execute",
                        name = L["CONFIG_HISTORY_CLEAR_ALL"],
                        order = 2,
                        func = function()
                            if Loothing.History then
                                Loothing.History:ClearHistory()
                                Loothing:Print(L["CONFIG_HISTORY_ALL_CLEARED"])
                                if Loolib.Config and Loolib.Config.Dialog then
                                    Loolib.Config.Dialog:RefreshContent("Loothing")
                                end
                            end
                        end,
                        confirm = function()
                            return L["CONFIG_HISTORY_CLEARALL_CONFIRM"]
                        end,
                    },
                    sendHistory = {
                        type = "toggle",
                        name = L["CONFIG_HISTORY_SEND"],
                        order = 3,
                        width = "half",
                        get = function() return Loothing.Settings:Get("historySettings.sendHistory") end,
                        set = function(_, v) Loothing.Settings:Set("historySettings.sendHistory", v) end,
                    },
                    sendToGuild = {
                        type = "toggle",
                        name = L["CONFIG_HISTORY_SEND_GUILD"],
                        order = 4,
                        width = "half",
                        get = function() return Loothing.Settings:Get("historySettings.sendToGuild") end,
                        set = function(_, v) Loothing.Settings:Set("historySettings.sendToGuild", v) end,
                    },
                    savePersonalLoot = {
                        type = "toggle",
                        name = L["CONFIG_HISTORY_SAVE_PL"],
                        order = 5,
                        width = "half",
                        get = function() return Loothing.Settings:Get("historySettings.savePersonalLoot") end,
                        set = function(_, v) Loothing.Settings:Set("historySettings.savePersonalLoot", v) end,
                    },
                    autoExportWeb = {
                        type = "toggle",
                        name = L["CONFIG_HISTORY_AUTO_EXPORT_WEB"],
                        desc = L["CONFIG_HISTORY_AUTO_EXPORT_WEB_DESC"],
                        order = 6,
                        width = "full",
                        get = function() return Loothing.Settings:Get("historySettings.autoExportWeb") end,
                        set = function(_, v) Loothing.Settings:Set("historySettings.autoExportWeb", v) end,
                    },
                },
            },
            -- ============================================================
            -- Announcements
            -- ============================================================
            announcements = {
                type = "group",
                name = L["ANNOUNCEMENT_SETTINGS"],
                order = 8,
                childGroups = "tree",
                args = {
                    general = {
                        type = "group",
                        name = L["GENERAL"],
                        order = 1,
                        inline = false,
                        args = {
                            announceAwards = {
                                type = "toggle",
                                name = L["ANNOUNCE_AWARDS"],
                                order = 1,
                                get = function() return Loothing.Settings:GetAnnounceAwards() end,
                                set = function(_, v) Loothing.Settings:SetAnnounceAwards(v) end,
                            },
                            announceItems = {
                                type = "toggle",
                                name = L["ANNOUNCE_ITEMS"],
                                order = 2,
                                get = function() return Loothing.Settings:GetAnnounceItems() end,
                                set = function(_, v) Loothing.Settings:SetAnnounceItems(v) end,
                            },
                            announceBossKill = {
                                type = "toggle",
                                name = L["ANNOUNCE_BOSS_KILL"],
                                order = 3,
                                get = function() return Loothing.Settings:GetAnnounceBossKill() end,
                                set = function(_, v) Loothing.Settings:SetAnnounceBossKill(v) end,
                            },
                            announceConsiderations = {
                                type = "toggle",
                                name = L["CONFIG_ANNOUNCE_CONSIDERATIONS"],
                                order = 4,
                                get = function() return Loothing.Settings:GetAnnounceConsiderations() end,
                                set = function(_, v) Loothing.Settings:SetAnnounceConsiderations(v) end,
                            },
                        },
                    },
                    considerations = {
                        type = "group",
                        name = L["CONFIG_CONSIDERATIONS"],
                        order = 2,
                        inline = false,
                        args = {
                            considerationsChannel = {
                                type = "select",
                                name = L["CONFIG_CONSIDERATIONS_CHANNEL"],
                                order = 1,
                                values = GetChannelValues(),
                                get = function() return Loothing.Settings:GetConsiderationsChannel() end,
                                set = function(_, v) Loothing.Settings:SetConsiderationsChannel(v) end,
                            },
                            considerationsText = {
                                type = "input",
                                name = L["CONFIG_CONSIDERATIONS_TEXT"],
                                order = 2,
                                width = "full",
                                get = function() return Loothing.Settings:GetConsiderationsText() end,
                                set = function(_, v) Loothing.Settings:SetConsiderationsText(v) end,
                            },
                        },
                    },
                    awards = {
                        type = "group",
                        name = L["AWARD"],
                        order = 3,
                        inline = false,
                        args = MakeLineOptions(
                            function(i) return Loothing.Settings:GetAwardLine(i) end,
                            function(i, en, ch, tx) Loothing.Settings:SetAwardLine(i, en, ch, tx) end,
                            "award"
                        ),
                    },
                    items = {
                        type = "group",
                        name = L["CONFIG_ITEM_ANNOUNCEMENTS"],
                        order = 4,
                        inline = false,
                        args = MakeLineOptions(
                            function(i) return Loothing.Settings:GetItemLine(i) end,
                            function(i, en, ch, tx) Loothing.Settings:SetItemLine(i, en, ch, tx) end,
                            "item"
                        ),
                    },
                    sessions = {
                        type = "group",
                        name = L["CONFIG_SESSION_ANNOUNCEMENTS"],
                        order = 5,
                        inline = false,
                        args = {
                            sessionStartHeader = {
                                type = "header",
                                name = L["CONFIG_SESSION_START"],
                                order = 1,
                            },
                            sessionStartChannel = {
                                type = "select",
                                name = L["CONFIG_CHANNEL"],
                                order = 2,
                                values = GetChannelValues(),
                                get = function() return Loothing.Settings:GetSessionStartChannel() end,
                                set = function(_, v) Loothing.Settings:SetSessionStartChannel(v) end,
                            },
                            sessionStartText = {
                                type = "input",
                                name = L["CONFIG_MESSAGE"],
                                order = 3,
                                width = "full",
                                get = function() return Loothing.Settings:GetSessionStartText() end,
                                set = function(_, v) Loothing.Settings:SetSessionStartText(v) end,
                            },
                            sessionEndHeader = {
                                type = "header",
                                name = L["CONFIG_SESSION_END"],
                                order = 10,
                            },
                            sessionEndChannel = {
                                type = "select",
                                name = L["CONFIG_CHANNEL"],
                                order = 11,
                                values = GetChannelValues(),
                                get = function() return Loothing.Settings:GetSessionEndChannel() end,
                                set = function(_, v) Loothing.Settings:SetSessionEndChannel(v) end,
                            },
                            sessionEndText = {
                                type = "input",
                                name = L["CONFIG_MESSAGE"],
                                order = 12,
                                width = "full",
                                get = function() return Loothing.Settings:GetSessionEndText() end,
                                set = function(_, v) Loothing.Settings:SetSessionEndText(v) end,
                            },
                        },
                    },
                },
            },
        },
    }
end

Options.GetLocalPreferencesOptions = GetLocalPreferencesOptions
