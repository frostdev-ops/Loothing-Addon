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
            desc = L["CONFIG_ENABLED_DESC"],
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
            desc = L["CONFIG_CHANNEL_DESC"],
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
            desc = L["CONFIG_MESSAGE_DESC"],
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
                        desc = L["CONFIG_AUTOPASS_WEAPONS_DESC"],
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
                        desc = L["CONFIG_AUTOPASS_TRINKETS_DESC"],
                        order = 4,
                        width = "half",
                        get = function() return Loothing.Settings:Get("autoPass.trinkets") end,
                        set = function(_, v) Loothing.Settings:Set("autoPass.trinkets", v) end,
                    },
                    transmog = {
                        type = "toggle",
                        name = L["CONFIG_AUTOPASS_TRANSMOG"],
                        desc = L["CONFIG_AUTOPASS_TRANSMOG_DESC"],
                        order = 5,
                        width = "half",
                        get = function() return Loothing.Settings:Get("autoPass.transmog") end,
                        set = function(_, v) Loothing.Settings:Set("autoPass.transmog", v) end,
                    },
                    transmogSource = {
                        type = "toggle",
                        name = L["CONFIG_AUTOPASS_TRANSMOG_SOURCE"],
                        desc = L["CONFIG_AUTOPASS_TRANSMOG_SOURCE_DESC"],
                        order = 6,
                        width = "half",
                        get = function() return Loothing.Settings:Get("autoPass.transmogSource") end,
                        set = function(_, v) Loothing.Settings:Set("autoPass.transmogSource", v) end,
                    },
                    -- silent is ML-controlled via MLDB, not a local preference
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
                        desc = L["CONFIG_AUTO_AWARD_LOWER_THRESHOLD_DESC"],
                        order = 3,
                        values = GetQualityValues(),
                        get = function() return Loothing.Settings:Get("autoAward.lowerThreshold") end,
                        set = function(_, v) Loothing.Settings:Set("autoAward.lowerThreshold", v) end,
                    },
                    upperThreshold = {
                        type = "select",
                        name = L["CONFIG_AUTO_AWARD_UPPER_THRESHOLD"],
                        desc = L["CONFIG_AUTO_AWARD_UPPER_THRESHOLD_DESC"],
                        order = 4,
                        values = GetQualityValues(),
                        get = function() return Loothing.Settings:Get("autoAward.upperThreshold") end,
                        set = function(_, v) Loothing.Settings:Set("autoAward.upperThreshold", v) end,
                    },
                    reasonId = {
                        type = "select",
                        name = L["CONFIG_AUTO_AWARD_REASON"],
                        desc = L["CONFIG_AUTO_AWARD_REASON_DESC"],
                        order = 5,
                        values = function()
                            local vals = { [0] = L["NONE"] }
                            for _, r in ipairs(Loothing.Settings:GetAwardReasons()) do
                                vals[r.id] = r.name
                            end
                            return vals
                        end,
                        get = function() return Loothing.Settings:GetAutoAwardReasonId() or 0 end,
                        set = function(_, v)
                            Loothing.Settings:SetAutoAwardReasonId(v ~= 0 and v or nil)
                        end,
                    },
                    includeBoE = {
                        type = "toggle",
                        name = L["CONFIG_AUTO_AWARD_INCLUDE_BOE"],
                        desc = L["CONFIG_AUTO_AWARD_INCLUDE_BOE_DESC"],
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
                        desc = L["CONFIG_IGNORE_ENCHANTING_MATS_DESC"],
                        order = 3,
                        get = function() return Loothing.Settings:GetIgnoreEnchantingMaterials() end,
                        set = function(_, v) Loothing.Settings:SetIgnoreEnchantingMaterials(v) end,
                    },
                    ignoreCraftingReagents = {
                        type = "toggle",
                        name = L["CONFIG_IGNORE_CRAFTING_REAGENTS"],
                        desc = L["CONFIG_IGNORE_CRAFTING_REAGENTS_DESC"],
                        order = 4,
                        get = function() return Loothing.Settings:GetIgnoreCraftingReagents() end,
                        set = function(_, v) Loothing.Settings:SetIgnoreCraftingReagents(v) end,
                    },
                    ignoreConsumables = {
                        type = "toggle",
                        name = L["CONFIG_IGNORE_CONSUMABLES"],
                        desc = L["CONFIG_IGNORE_CONSUMABLES_DESC"],
                        order = 5,
                        get = function() return Loothing.Settings:GetIgnoreConsumables() end,
                        set = function(_, v) Loothing.Settings:SetIgnoreConsumables(v) end,
                    },
                    ignorePermanentEnhancements = {
                        type = "toggle",
                        name = L["CONFIG_IGNORE_PERMANENT_ENHANCEMENTS"],
                        desc = L["CONFIG_IGNORE_PERMANENT_ENHANCEMENTS_DESC"],
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
                        desc = L["CONFIG_FRAME_AUTO_OPEN_DESC"],
                        order = 1,
                        width = "half",
                        get = function() return Loothing.Settings:Get("frame.autoOpen") end,
                        set = function(_, v) Loothing.Settings:Set("frame.autoOpen", v) end,
                    },
                    autoClose = {
                        type = "toggle",
                        name = L["CONFIG_FRAME_AUTO_CLOSE"],
                        desc = L["CONFIG_FRAME_AUTO_CLOSE_DESC"],
                        order = 2,
                        width = "half",
                        get = function() return Loothing.Settings:Get("frame.autoClose") end,
                        set = function(_, v) Loothing.Settings:Set("frame.autoClose", v) end,
                    },
                    minimizeInCombat = {
                        type = "toggle",
                        name = L["CONFIG_FRAME_MINIMIZE_COMBAT"],
                        desc = L["CONFIG_FRAME_MINIMIZE_COMBAT_DESC"],
                        order = 3,
                        width = "half",
                        get = function() return Loothing.Settings:Get("frame.minimizeInCombat") end,
                        set = function(_, v) Loothing.Settings:Set("frame.minimizeInCombat", v) end,
                    },
                    showSpecIcon = {
                        type = "toggle",
                        name = L["CONFIG_FRAME_SHOW_SPEC_ICON"],
                        desc = L["CONFIG_FRAME_SHOW_SPEC_ICON_DESC"],
                        order = 4,
                        width = "half",
                        get = function() return Loothing.Settings:Get("frame.showSpecIcon") end,
                        set = function(_, v) Loothing.Settings:Set("frame.showSpecIcon", v) end,
                    },
                    closeWithEscape = {
                        type = "toggle",
                        name = L["CONFIG_FRAME_CLOSE_ESCAPE"],
                        desc = L["CONFIG_FRAME_CLOSE_ESCAPE_DESC"],
                        order = 5,
                        width = "half",
                        get = function() return Loothing.Settings:Get("frame.closeWithEscape") end,
                        set = function(_, v) Loothing.Settings:Set("frame.closeWithEscape", v) end,
                    },
                    timeoutFlash = {
                        type = "toggle",
                        name = L["CONFIG_FRAME_TIMEOUT_FLASH"],
                        desc = L["CONFIG_FRAME_TIMEOUT_FLASH_DESC"],
                        order = 6,
                        width = "half",
                        get = function() return Loothing.Settings:Get("frame.timeoutFlash") end,
                        set = function(_, v) Loothing.Settings:Set("frame.timeoutFlash", v) end,
                    },
                    blockTradesDuringVoting = {
                        type = "toggle",
                        name = L["CONFIG_FRAME_BLOCK_TRADES"],
                        desc = L["CONFIG_FRAME_BLOCK_TRADES_DESC"],
                        order = 7,
                        width = "half",
                        get = function() return Loothing.Settings:Get("frame.blockTradesDuringVoting") end,
                        set = function(_, v) Loothing.Settings:Set("frame.blockTradesDuringVoting", v) end,
                    },
                    chatFrameName = {
                        type = "select",
                        name = L["CONFIG_FRAME_CHAT_OUTPUT"],
                        desc = L["CONFIG_FRAME_CHAT_OUTPUT_DESC"],
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
                        desc = L["CONFIG_ML_USAGE_MODE_DESC"],
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
                        desc = L["CONFIG_ML_RAIDS_ONLY_DESC"],
                        order = 2,
                        width = "half",
                        get = function() return Loothing.Settings:Get("ml.onlyUseInRaids") end,
                        set = function(_, v) Loothing.Settings:Set("ml.onlyUseInRaids", v) end,
                    },
                    allowOutOfRaid = {
                        type = "toggle",
                        name = L["CONFIG_ML_ALLOW_OUTSIDE"],
                        desc = L["CONFIG_ML_ALLOW_OUTSIDE_DESC"],
                        order = 3,
                        width = "half",
                        get = function() return Loothing.Settings:Get("ml.allowOutOfRaid") end,
                        set = function(_, v) Loothing.Settings:Set("ml.allowOutOfRaid", v) end,
                    },
                    skipSessionFrame = {
                        type = "toggle",
                        name = L["CONFIG_ML_SKIP_SESSION"],
                        desc = L["CONFIG_ML_SKIP_SESSION_DESC"],
                        order = 4,
                        width = "half",
                        get = function() return Loothing.Settings:Get("ml.skipSessionFrame") end,
                        set = function(_, v) Loothing.Settings:Set("ml.skipSessionFrame", v) end,
                    },
                    sortItems = {
                        type = "toggle",
                        name = L["CONFIG_ML_SORT_ITEMS"],
                        desc = L["CONFIG_ML_SORT_ITEMS_DESC"],
                        order = 5,
                        width = "half",
                        get = function() return Loothing.Settings:Get("ml.sortItems") end,
                        set = function(_, v) Loothing.Settings:Set("ml.sortItems", v) end,
                    },
                    autoAddBoEs = {
                        type = "toggle",
                        name = L["CONFIG_ML_AUTO_ADD_BOES"],
                        desc = L["CONFIG_ML_AUTO_ADD_BOES_DESC"],
                        order = 6,
                        width = "half",
                        get = function() return Loothing.Settings:Get("ml.autoAddBoEs") end,
                        set = function(_, v) Loothing.Settings:Set("ml.autoAddBoEs", v) end,
                    },
                    printCompletedTrades = {
                        type = "toggle",
                        name = L["CONFIG_ML_PRINT_TRADES"],
                        desc = L["CONFIG_ML_PRINT_TRADES_DESC"],
                        order = 7,
                        width = "half",
                        get = function() return Loothing.Settings:Get("ml.printCompletedTrades") end,
                        set = function(_, v) Loothing.Settings:Set("ml.printCompletedTrades", v) end,
                    },
                    rejectTrade = {
                        type = "toggle",
                        name = L["CONFIG_ML_REJECT_TRADE"],
                        desc = L["CONFIG_ML_REJECT_TRADE_DESC"],
                        order = 8,
                        width = "half",
                        get = function() return Loothing.Settings:Get("ml.rejectTrade") end,
                        set = function(_, v) Loothing.Settings:Set("ml.rejectTrade", v) end,
                    },
                    awardLater = {
                        type = "toggle",
                        name = L["CONFIG_ML_AWARD_LATER"],
                        desc = L["CONFIG_ML_AWARD_LATER_DESC"],
                        order = 9,
                        width = "half",
                        get = function() return Loothing.Settings:Get("ml.awardLater") end,
                        set = function(_, v) Loothing.Settings:Set("ml.awardLater", v) end,
                    },
                    autoGroupLootGuildOnly = {
                        type = "toggle",
                        name = L["CONFIG_ML_GUILD_ONLY"],
                        desc = L["CONFIG_ML_GUILD_ONLY_DESC"],
                        order = 10,
                        width = "half",
                        get = function() return Loothing.Settings:Get("settings.autoGroupLootGuildOnly", false) end,
                        set = function(_, v) Loothing.Settings:Set("settings.autoGroupLootGuildOnly", v) end,
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
                        desc = L["CONFIG_HISTORY_ENABLED_DESC"],
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
                        desc = L["CONFIG_HISTORY_SEND_DESC"],
                        order = 3,
                        width = "half",
                        get = function() return Loothing.Settings:Get("historySettings.sendHistory") end,
                        set = function(_, v) Loothing.Settings:Set("historySettings.sendHistory", v) end,
                    },
                    sendToGuild = {
                        type = "toggle",
                        name = L["CONFIG_HISTORY_SEND_GUILD"],
                        desc = L["CONFIG_HISTORY_SEND_GUILD_DESC"],
                        order = 4,
                        width = "half",
                        get = function() return Loothing.Settings:Get("historySettings.sendToGuild") end,
                        set = function(_, v) Loothing.Settings:Set("historySettings.sendToGuild", v) end,
                    },
                    savePersonalLoot = {
                        type = "toggle",
                        name = L["CONFIG_HISTORY_SAVE_PL"],
                        desc = L["CONFIG_HISTORY_SAVE_PL_DESC"],
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
                    maxEntries = {
                        type = "range",
                        name = L["CONFIG_HISTORY_MAX_ENTRIES"],
                        desc = L["CONFIG_HISTORY_MAX_ENTRIES_DESC"],
                        order = 7,
                        min = 50, max = 2000, step = 50,
                        get = function() return Loothing.Settings:Get("historySettings.maxEntries", 500) end,
                        set = function(_, v) Loothing.Settings:Set("historySettings.maxEntries", v) end,
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
                                desc = L["CONFIG_ANNOUNCE_AWARDS_DESC"],
                                order = 1,
                                get = function() return Loothing.Settings:GetAnnounceAwards() end,
                                set = function(_, v) Loothing.Settings:SetAnnounceAwards(v) end,
                            },
                            announceItems = {
                                type = "toggle",
                                name = L["ANNOUNCE_ITEMS"],
                                desc = L["CONFIG_ANNOUNCE_ITEMS_DESC"],
                                order = 2,
                                get = function() return Loothing.Settings:GetAnnounceItems() end,
                                set = function(_, v) Loothing.Settings:SetAnnounceItems(v) end,
                            },
                            announceBossKill = {
                                type = "toggle",
                                name = L["ANNOUNCE_BOSS_KILL"],
                                desc = L["CONFIG_ANNOUNCE_BOSS_KILL_DESC"],
                                order = 3,
                                get = function() return Loothing.Settings:GetAnnounceBossKill() end,
                                set = function(_, v) Loothing.Settings:SetAnnounceBossKill(v) end,
                            },
                            announceConsiderations = {
                                type = "toggle",
                                name = L["CONFIG_ANNOUNCE_CONSIDERATIONS"],
                                desc = L["CONFIG_ANNOUNCE_CONSIDERATIONS_DESC"],
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
                                desc = L["CONFIG_CONSIDERATIONS_CHANNEL_DESC"],
                                order = 1,
                                values = GetChannelValues(),
                                get = function() return Loothing.Settings:GetConsiderationsChannel() end,
                                set = function(_, v) Loothing.Settings:SetConsiderationsChannel(v) end,
                            },
                            considerationsText = {
                                type = "input",
                                name = L["CONFIG_CONSIDERATIONS_TEXT"],
                                desc = L["CONFIG_CONSIDERATIONS_TEXT_DESC"],
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
