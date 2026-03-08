--[[--------------------------------------------------------------------
    Loothing - Options: Session Settings (ML-broadcast)
    These settings are broadcast to all raid members when you are the
    Master Looter. They control the session for everyone.
----------------------------------------------------------------------]]

local L = LOOTHING_LOCALE
local unpack = unpack

-- Shared values function for button set dropdowns
local function GetButtonSetValues()
    local sets = Loothing.Settings:GetButtonSets()
    local t = {}
    if sets and sets.sets then
        for id, set in pairs(sets.sets) do
            t[id] = set.name
        end
    end
    return t
end

-- Type codes that can be assigned to specific button sets
local TYPE_CODES = { "default", "WEAPON", "RARE", "TOKEN", "PETS", "MOUNTS", "RECIPE", "SPECIAL", "CATALYST" }

local function GetSessionSettingsOptions()
    local opts = {
        type = "group",
        name = L["SESSION_SETTINGS_ML"] or "Session Settings (ML)",
        desc = "These settings are broadcast to all raid members when you are the Master Looter. They control the session for everyone.",
        order = 1,
        childGroups = "tree",
        args = {
            sessionSettingsDesc = {
                type = "description",
                name = "|cffffcc00These settings are broadcast to all raid members when you start a session as Master Looter.|r",
                order = 0,
                fontSize = "medium",
                width = "full",
            },
            -- ============================================================
            -- Voting
            -- ============================================================
            voting = {
                type = "group",
                name = L["VOTING"],
                order = 1,
                columns = 3,
                args = {
                    votingMode = {
                        type = "select",
                        name = L["VOTING_MODE"],
                        order = 1,
                        values = {
                            [LOOTHING_VOTING_MODE.SIMPLE] = L["SIMPLE_VOTING"],
                            [LOOTHING_VOTING_MODE.RANKED_CHOICE] = L["RANKED_VOTING"],
                        },
                        get = function() return Loothing.Settings:GetVotingMode() end,
                        set = function(_, v) Loothing.Settings:SetVotingMode(v) end,
                    },
                    votingTimeoutEnabled = {
                        type = "toggle",
                        name = L["VOTING_TIMEOUT"] or "Voting Timeout",
                        desc = "When disabled, voting runs until the ML manually ends it.",
                        order = 2,
                        get = function()
                            return Loothing.Settings:GetVotingTimeout() ~= LOOTHING_TIMING.NO_TIMEOUT
                        end,
                        set = function(_, v)
                            if v then
                                Loothing.Settings:SetVotingTimeout(LOOTHING_TIMING.DEFAULT_VOTE_TIMEOUT)
                            else
                                Loothing.Settings:SetVotingTimeout(LOOTHING_TIMING.NO_TIMEOUT)
                            end
                        end,
                    },
                    votingTimeout = {
                        type = "range",
                        name = L["VOTING_TIMEOUT_DURATION"] or "Timeout Duration",
                        desc = L["SECONDS"] or "Seconds",
                        order = 3,
                        min = LOOTHING_TIMING.MIN_VOTE_TIMEOUT,
                        max = LOOTHING_TIMING.MAX_VOTE_TIMEOUT,
                        step = 5,
                        hidden = function()
                            return Loothing.Settings:GetVotingTimeout() == LOOTHING_TIMING.NO_TIMEOUT
                        end,
                        get = function() return Loothing.Settings:GetVotingTimeout() end,
                        set = function(_, v) Loothing.Settings:SetVotingTimeout(v) end,
                    },
                    sessionTriggerMode = {
                        type = "select",
                        name = L["SESSION_TRIGGER_MODE"] or "Session Trigger Mode",
                        desc = L["SESSION_TRIGGER_MODE_DESC"] or "How loot sessions are started after a boss kill",
                        order = 4,
                        width = "double",
                        values = {
                            manual = L["TRIGGER_MANUAL"] or "Manual (use /loothing start)",
                            auto = L["TRIGGER_AUTO"] or "Automatic (start immediately)",
                            prompt = L["TRIGGER_PROMPT"] or "Prompt (ask before starting)",
                            afterRolls = L["TRIGGER_AFTER_ROLLS"] or "After Rolls (wait for ML to receive loot)",
                        },
                        sorting = { "manual", "auto", "prompt", "afterRolls" },
                        get = function() return Loothing.Settings:GetSessionTriggerMode() end,
                        set = function(_, v) Loothing.Settings:SetSessionTriggerMode(v) end,
                    },
                    selfVote = {
                        type = "toggle",
                        name = L["SELF_VOTE"],
                        desc = L["SELF_VOTE_DESC"],
                        order = 10,
                        width = "half",
                        get = function() return Loothing.Settings:GetSelfVote() end,
                        set = function(_, v) Loothing.Settings:SetSelfVote(v) end,
                    },
                    multiVote = {
                        type = "toggle",
                        name = L["MULTI_VOTE"],
                        desc = L["MULTI_VOTE_DESC"],
                        order = 11,
                        width = "half",
                        get = function() return Loothing.Settings:GetMultiVote() end,
                        set = function(_, v) Loothing.Settings:SetMultiVote(v) end,
                    },
                    anonymousVoting = {
                        type = "toggle",
                        name = L["ANONYMOUS_VOTING"],
                        desc = L["ANONYMOUS_VOTING_DESC"],
                        order = 12,
                        width = "half",
                        get = function() return Loothing.Settings:GetAnonymousVoting() end,
                        set = function(_, v) Loothing.Settings:SetAnonymousVoting(v) end,
                    },
                    hideVotes = {
                        type = "toggle",
                        name = L["HIDE_VOTES"],
                        desc = L["HIDE_VOTES_DESC"],
                        order = 13,
                        width = "half",
                        get = function() return Loothing.Settings:GetHideVotes() end,
                        set = function(_, v) Loothing.Settings:SetHideVotes(v) end,
                    },
                    observe = {
                        type = "toggle",
                        name = L["OBSERVE_MODE"],
                        desc = L["OBSERVE_MODE_DESC"],
                        order = 14,
                        width = "half",
                        get = function() return Loothing.Settings:GetObserveMode() end,
                        set = function(_, v) Loothing.Settings:SetObserveMode(v) end,
                    },
                    autoAddRolls = {
                        type = "toggle",
                        name = L["AUTO_ADD_ROLLS"],
                        desc = L["AUTO_ADD_ROLLS_DESC"],
                        order = 15,
                        width = "half",
                        get = function() return Loothing.Settings:GetAutoAddRolls() end,
                        set = function(_, v) Loothing.Settings:SetAutoAddRolls(v) end,
                    },
                    requireNotes = {
                        type = "toggle",
                        name = L["REQUIRE_NOTES"],
                        desc = L["REQUIRE_NOTES_DESC"],
                        order = 16,
                        width = "half",
                        get = function() return Loothing.Settings:GetRequireNotes() end,
                        set = function(_, v) Loothing.Settings:SetRequireNotes(v) end,
                    },
                    numButtons = {
                        type = "range",
                        name = L["NUM_BUTTONS"],
                        desc = L["NUM_BUTTONS_DESC"],
                        order = 17,
                        min = 1,
                        max = 10,
                        step = 1,
                        get = function() return Loothing.Settings:GetNumButtons() end,
                        set = function(_, v) Loothing.Settings:SetNumButtons(v) end,
                    },
                },
            },
            -- ============================================================
            -- Response Buttons
            -- ============================================================
            buttonSets = {
                type = "group",
                name = L["CONFIG_BUTTON_SETS"] or "Response Buttons",
                order = 2,
                args = {
                    desc = {
                        type = "description",
                        name = "Configure response button sets. Each set defines the buttons shown to candidates when rolling on items.",
                        order = 0,
                    },
                    activeSet = {
                        type = "select",
                        name = "Active Button Set",
                        order = 1,
                        values = GetButtonSetValues,
                        get = function() return Loothing.Settings:GetActiveButtonSet() end,
                        set = function(_, v) Loothing.Settings:SetActiveButtonSet(v) end,
                    },
                    setName = {
                        type = "input",
                        name = "Set Name",
                        order = 2,
                        get = function()
                            local id = Loothing.Settings:GetActiveButtonSet()
                            local set = Loothing.Settings:GetButtonSet(id)
                            return set and set.name or ""
                        end,
                        set = function(_, v)
                            local id = Loothing.Settings:GetActiveButtonSet()
                            Loothing.Settings:UpdateButtonSet(id, { name = v })
                        end,
                    },
                    whisperKey = {
                        type = "input",
                        name = "Whisper Key",
                        desc = "The whisper key players can use to respond (e.g., '!need')",
                        order = 3,
                        get = function()
                            local id = Loothing.Settings:GetActiveButtonSet()
                            local set = Loothing.Settings:GetButtonSet(id)
                            return set and set.whisperKey or ""
                        end,
                        set = function(_, v)
                            local id = Loothing.Settings:GetActiveButtonSet()
                            Loothing.Settings:UpdateButtonSet(id, { whisperKey = v })
                        end,
                    },
                    setMgmtHeader = {
                        type = "header",
                        name = "Manage Sets",
                        order = 5,
                    },
                    newSetName = {
                        type = "input",
                        name = "New Set Name",
                        order = 6,
                        get = function() return "" end,
                        set = function(_, v)
                            if v and v ~= "" then
                                local defaultButtons = {
                                    { id = 1, text = "Need", color = {0,1,0,1}, sort = 1 },
                                    { id = 2, text = "Pass", color = {0.5,0.5,0.5,1}, sort = 2 },
                                }
                                Loothing.Settings:AddButtonSet(v, defaultButtons)
                            end
                        end,
                    },
                    copySet = {
                        type = "execute",
                        name = "Copy Active Set",
                        order = 7,
                        func = function()
                            local id = Loothing.Settings:GetActiveButtonSet()
                            local set = Loothing.Settings:GetButtonSet(id)
                            if set then
                                local newId = Loothing.Settings:AddButtonSet(set.name .. " (Copy)", set.buttons)
                                Loothing.Settings:SetActiveButtonSet(newId)
                            end
                        end,
                    },
                    deleteSet = {
                        type = "execute",
                        name = "Delete Active Set",
                        order = 8,
                        confirm = function() return "Delete this button set? This cannot be undone." end,
                        func = function()
                            local id = Loothing.Settings:GetActiveButtonSet()
                            local sets = Loothing.Settings:GetButtonSets()
                            if sets and sets.sets then
                                local count = 0
                                for _ in pairs(sets.sets) do count = count + 1 end
                                if count <= 1 then
                                    Loothing:Print("Cannot delete the last button set")
                                    return
                                end
                            end
                            Loothing.Settings:RemoveButtonSet(id)
                            local remaining = Loothing.Settings:GetButtonSets()
                            if remaining and remaining.sets then
                                for newId in pairs(remaining.sets) do
                                    Loothing.Settings:SetActiveButtonSet(newId)
                                    break
                                end
                            end
                        end,
                    },
                    buttonsHeader = {
                        type = "header",
                        name = "Buttons",
                        order = 10,
                    },
                },
            },
            -- ============================================================
            -- Type Code Assignment
            -- ============================================================
            typeCodeAssignment = {
                type = "group",
                name = L["CONFIG_TYPECODE_ASSIGNMENT"] or "Type Code Assignment",
                order = 3,
                args = {
                    desc = {
                        type = "description",
                        name = "Assign which button set to use for each item type code. Items matching a specific type code will show the assigned button set instead of the default.",
                        order = 0,
                    },
                },
            },
            -- ============================================================
            -- Council
            -- ============================================================
            council = {
                type = "group",
                name = L["COUNCIL"],
                order = 4,
                args = {
                    autoIncludeOfficers = {
                        type = "toggle",
                        name = L["AUTO_INCLUDE_OFFICERS"],
                        desc = L["AUTO_OFFICERS"],
                        order = 1,
                        get = function() return Loothing.Settings:GetAutoIncludeOfficers() end,
                        set = function(_, v) Loothing.Settings:SetAutoIncludeOfficers(v) end,
                    },
                    autoIncludeRaidLeader = {
                        type = "toggle",
                        name = L["AUTO_INCLUDE_LEADER"],
                        desc = L["AUTO_RAID_LEADER"],
                        order = 2,
                        get = function() return Loothing.Settings:GetAutoIncludeRaidLeader() end,
                        set = function(_, v) Loothing.Settings:SetAutoIncludeRaidLeader(v) end,
                    },
                    membersHeader = {
                        type = "header",
                        name = L["COUNCIL_MEMBERS"],
                        order = 3,
                    },
                    membersList = {
                        type = "description",
                        name = function()
                            local members = Loothing.Council and Loothing.Council:GetMembers() or {}
                            if #members == 0 then
                                return "|cff888888No council members added yet.|r\n\nCouncil members can vote on loot distribution. Use the field below to add members by name."
                            end
                            local list = {}
                            for i, name in ipairs(members) do
                                list[i] = "|cffffd700" .. i .. ".|r " .. name
                            end
                            return table.concat(list, "\n")
                        end,
                        order = 4,
                        fontSize = "medium",
                        width = "full",
                    },
                    addMemberInput = {
                        type = "input",
                        name = L["ADD_MEMBER"],
                        desc = "Enter character name (e.g., 'Playername' or 'Playername-Realm')",
                        order = 5,
                        width = "double",
                        get = function() return "" end,
                        set = function(_, value)
                            if value and value ~= "" then
                                if Loothing.Council then
                                    local success, err = Loothing.Council:AddMember(value)
                                    if success then
                                        Loothing:Print(string.format(L["IS_COUNCIL"], value))
                                        if LoolibConfig and LoolibConfig.Dialog then
                                            LoolibConfig.Dialog:RefreshContent("Loothing")
                                        end
                                    else
                                        Loothing:Error(err or "Failed to add council member")
                                    end
                                end
                            end
                        end,
                    },
                    removeMember = {
                        type = "select",
                        name = L["REMOVE_MEMBER"],
                        desc = "Select a member to remove from the council",
                        order = 6,
                        width = "double",
                        values = function()
                            local members = Loothing.Council and Loothing.Council:GetMembers() or {}
                            local t = {}
                            for _, name in ipairs(members) do
                                t[name] = name
                            end
                            return t
                        end,
                        get = function() return nil end,
                        set = function(_, value)
                            if value and Loothing.Council then
                                Loothing.Council:RemoveMember(value)
                                Loothing:Print(value .. " removed from council")
                                if LoolibConfig and LoolibConfig.Dialog then
                                    LoolibConfig.Dialog:RefreshContent("Loothing")
                                end
                            end
                        end,
                        hidden = function()
                            local members = Loothing.Council and Loothing.Council:GetMembers() or {}
                            return #members == 0
                        end,
                        confirm = function(_, value)
                            if not value or value == "" then return false end
                            return "Remove " .. value .. " from the council?"
                        end,
                    },
                    removeAll = {
                        type = "execute",
                        name = L["CONFIG_COUNCIL_REMOVE_ALL"] or "Remove All Members",
                        order = 7,
                        func = function()
                            if Loothing.Council then
                                local members = Loothing.Council:GetMembers()
                                for i = #members, 1, -1 do
                                    Loothing.Council:RemoveMember(members[i])
                                end
                                Loothing:Print("All council members removed")
                                if LoolibConfig and LoolibConfig.Dialog then
                                    LoolibConfig.Dialog:RefreshContent("Loothing")
                                end
                            end
                        end,
                        hidden = function()
                            local members = Loothing.Council and Loothing.Council:GetMembers() or {}
                            return #members == 0
                        end,
                        confirm = function()
                            return "Remove ALL council members?"
                        end,
                    },
                    guildRankHeader = {
                        type = "header",
                        name = L["CONFIG_GUILD_RANK"] or "Guild Rank Auto-Include",
                        order = 8,
                    },
                    guildRankDesc = {
                        type = "description",
                        name = L["CONFIG_GUILD_RANK_DESC"] or "Automatically include guild members at or above a certain rank in the council.",
                        order = 9,
                        fontSize = "medium",
                    },
                    minRank = {
                        type = "range",
                        name = L["CONFIG_MIN_RANK"] or "Minimum Guild Rank",
                        desc = L["CONFIG_MIN_RANK_DESC"] or "Guild members at this rank or higher will be auto-included. 0 = disabled.",
                        order = 10,
                        min = 0,
                        max = 10,
                        step = 1,
                        get = function() return Loothing.Settings:Get("council.minRank", 0) end,
                        set = function(_, v) Loothing.Settings:Set("council.minRank", v) end,
                    },
                },
            },
            -- ============================================================
            -- Award Reasons
            -- ============================================================
            awardReasons = {
                type = "group",
                name = L["CONFIG_AWARD_REASONS"] or "Award Reasons",
                order = 5,
                childGroups = "tree",
                args = {
                    general = {
                        type = "group",
                        name = L["GENERAL"] or "General",
                        order = 1,
                        inline = false,
                        args = {
                            enabled = {
                                type = "toggle",
                                name = L["ENABLED"] or "Enabled",
                                desc = "Enable or disable the award reasons system",
                                order = 1,
                                get = function() return Loothing.Settings:GetAwardReasonsEnabled() end,
                                set = function(_, v) Loothing.Settings:SetAwardReasonsEnabled(v) end,
                            },
                            requireReason = {
                                type = "toggle",
                                name = L["REQUIRE_AWARD_REASON"] or "Require Reason",
                                desc = "Require an award reason to be selected before awarding an item",
                                order = 2,
                                get = function() return Loothing.Settings:GetRequireAwardReason() end,
                                set = function(_, v) Loothing.Settings:SetRequireAwardReason(v) end,
                            },
                            numReasons = {
                                type = "range",
                                name = L["NUM_AWARD_REASONS"] or "Number of Reasons",
                                desc = "Maximum number of active award reasons",
                                order = 3,
                                min = 1,
                                max = 20,
                                step = 1,
                                get = function() return Loothing.Settings:GetNumAwardReasons() end,
                                set = function(_, v) Loothing.Settings:SetNumAwardReasons(v) end,
                            },
                        },
                    },
                },
            },
        },
    }

    -- Generate per-button editor entries (buttons 1-10) in the buttonSets group
    local btnArgs = opts.args.buttonSets.args
    for i = 1, 10 do
        local hiddenFunc = function()
            local id = Loothing.Settings:GetActiveButtonSet()
            local buttons = Loothing.Settings:GetButtons(id)
            return not buttons or not buttons[i]
        end

        btnArgs["btn" .. i .. "Text"] = {
            type = "input",
            name = "Button " .. i .. " Text",
            order = 10 + i * 4,
            hidden = hiddenFunc,
            get = function()
                local id = Loothing.Settings:GetActiveButtonSet()
                local buttons = Loothing.Settings:GetButtons(id)
                return buttons and buttons[i] and buttons[i].text or ""
            end,
            set = function(_, v)
                local id = Loothing.Settings:GetActiveButtonSet()
                Loothing.Settings:UpdateButton(id, i, { text = v })
            end,
        }

        btnArgs["btn" .. i .. "Color"] = {
            type = "color",
            name = "Color",
            order = 10 + i * 4 + 1,
            hasAlpha = true,
            hidden = hiddenFunc,
            get = function()
                local id = Loothing.Settings:GetActiveButtonSet()
                local buttons = Loothing.Settings:GetButtons(id)
                if buttons and buttons[i] and buttons[i].color then
                    return unpack(buttons[i].color)
                end
                return 1, 1, 1, 1
            end,
            set = function(_, r, g, b, a)
                local id = Loothing.Settings:GetActiveButtonSet()
                Loothing.Settings:UpdateButton(id, i, { color = { r, g, b, a } })
            end,
        }

        btnArgs["btn" .. i .. "Sort"] = {
            type = "range",
            name = "Sort Order",
            order = 10 + i * 4 + 2,
            min = 1,
            max = 10,
            step = 1,
            hidden = hiddenFunc,
            get = function()
                local id = Loothing.Settings:GetActiveButtonSet()
                local buttons = Loothing.Settings:GetButtons(id)
                return buttons and buttons[i] and buttons[i].sort or i
            end,
            set = function(_, v)
                local id = Loothing.Settings:GetActiveButtonSet()
                Loothing.Settings:UpdateButton(id, i, { sort = v })
            end,
        }
    end

    -- Generate per-typeCode assignment selects
    local tcArgs = opts.args.typeCodeAssignment.args
    for idx, typeCode in ipairs(TYPE_CODES) do
        tcArgs[typeCode] = {
            type = "select",
            name = typeCode,
            order = idx,
            values = GetButtonSetValues,
            get = function()
                return Loothing.Settings:Get("buttonSets.typeCodeMap." .. typeCode, 1)
            end,
            set = function(_, v)
                Loothing.Settings:Set("buttonSets.typeCodeMap." .. typeCode, v)
            end,
        }
    end

    -- Generate award reason entries (reasons 1-20)
    local reasonArgs = opts.args.awardReasons.args
    local perReasonArgs = {
        desc = {
            type = "description",
            name = "Configure individual award reasons. Each reason has a name, color, sort order, and flags for history logging and disenchant classification.",
            order = 0,
        },
    }
    for i = 1, 20 do
        local hiddenFunc = function()
            local reasons = Loothing.Settings:GetAwardReasons()
            return not reasons or not reasons[i]
        end
        perReasonArgs["reason" .. i .. "Header"] = {
            type = "header",
            name = function()
                local reasons = Loothing.Settings:GetAwardReasons()
                return reasons and reasons[i] and reasons[i].name or ("Reason " .. i)
            end,
            order = i * 10,
            hidden = hiddenFunc,
        }
        perReasonArgs["reason" .. i .. "Name"] = {
            type = "input",
            name = "Name",
            order = i * 10 + 1,
            hidden = hiddenFunc,
            get = function()
                local reasons = Loothing.Settings:GetAwardReasons()
                return reasons and reasons[i] and reasons[i].name or ""
            end,
            set = function(_, v)
                Loothing.Settings:UpdateAwardReason(i, { name = v })
            end,
        }
        perReasonArgs["reason" .. i .. "Color"] = {
            type = "color",
            name = "Color",
            order = i * 10 + 2,
            hasAlpha = true,
            hidden = hiddenFunc,
            get = function()
                local reasons = Loothing.Settings:GetAwardReasons()
                if reasons and reasons[i] and reasons[i].color then
                    return unpack(reasons[i].color)
                end
                return 1, 1, 1, 1
            end,
            set = function(_, r, g, b, a)
                Loothing.Settings:UpdateAwardReason(i, { color = { r, g, b, a } })
            end,
        }
        perReasonArgs["reason" .. i .. "Sort"] = {
            type = "range",
            name = "Sort Order",
            order = i * 10 + 3,
            min = 1,
            max = 20,
            step = 1,
            hidden = hiddenFunc,
            get = function()
                local reasons = Loothing.Settings:GetAwardReasons()
                return reasons and reasons[i] and reasons[i].sort or i
            end,
            set = function(_, v)
                Loothing.Settings:UpdateAwardReason(i, { sort = v })
            end,
        }
        perReasonArgs["reason" .. i .. "Log"] = {
            type = "toggle",
            name = "Log to History",
            order = i * 10 + 4,
            hidden = hiddenFunc,
            get = function()
                local reasons = Loothing.Settings:GetAwardReasons()
                return reasons and reasons[i] and reasons[i].log
            end,
            set = function(_, v)
                Loothing.Settings:UpdateAwardReason(i, { log = v })
            end,
        }
        perReasonArgs["reason" .. i .. "Disenchant"] = {
            type = "toggle",
            name = "Disenchant Reason",
            order = i * 10 + 5,
            hidden = hiddenFunc,
            get = function()
                local reasons = Loothing.Settings:GetAwardReasons()
                return reasons and reasons[i] and reasons[i].disenchant
            end,
            set = function(_, v)
                Loothing.Settings:UpdateAwardReason(i, { disenchant = v })
            end,
        }
        perReasonArgs["reason" .. i .. "Remove"] = {
            type = "execute",
            name = "Remove",
            order = i * 10 + 6,
            hidden = hiddenFunc,
            confirm = "Remove this award reason?",
            func = function()
                Loothing.Settings:RemoveAwardReason(i)
            end,
        }
    end

    reasonArgs.reasons = {
        type = "group",
        name = "Reasons",
        order = 2,
        args = perReasonArgs,
    }
    reasonArgs.management = {
        type = "group",
        name = "Manage",
        order = 3,
        inline = true,
        args = {
            addReason = {
                type = "execute",
                name = "Add New Reason",
                order = 1,
                func = function()
                    local reasons = Loothing.Settings:GetAwardReasons() or {}
                    local nextId = #reasons + 1
                    Loothing.Settings:AddAwardReason({
                        id = nextId,
                        name = "New Reason",
                        color = { 1, 1, 1, 1 },
                        sort = nextId,
                        log = true,
                        disenchant = false,
                    })
                end,
            },
            resetDefaults = {
                type = "execute",
                name = "Reset to Defaults",
                order = 2,
                confirm = "Reset all award reasons to their default values? This cannot be undone.",
                func = function()
                    Loothing.Settings:ResetAwardReasonsToDefaults()
                end,
            },
        },
    }

    return opts
end

Loothing.Options = Loothing.Options or {}
Loothing.Options.GetSessionSettingsOptions = GetSessionSettingsOptions
