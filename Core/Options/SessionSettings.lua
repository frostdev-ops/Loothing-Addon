--[[--------------------------------------------------------------------
    Loothing - Options: Session Settings (ML-broadcast)
    These settings are broadcast to all raid members when you are the
    Master Looter. They control the session for everyone.
----------------------------------------------------------------------]]

local ADDON_NAME, ns = ...
local Loolib = LibStub("Loolib")
local Loothing = ns.Addon
local Options = ns.Options or {}
ns.Options = Options

local L = ns.Locale
local unpack = unpack


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
                            [Loothing.VotingMode.SIMPLE] = L["SIMPLE_VOTING"],
                            [Loothing.VotingMode.RANKED_CHOICE] = L["RANKED_VOTING"],
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
                            return Loothing.Settings:GetVotingTimeout() ~= Loothing.Timing.NO_TIMEOUT
                        end,
                        set = function(_, v)
                            if v then
                                Loothing.Settings:SetVotingTimeout(Loothing.Timing.DEFAULT_VOTE_TIMEOUT)
                            else
                                Loothing.Settings:SetVotingTimeout(Loothing.Timing.NO_TIMEOUT)
                            end
                        end,
                    },
                    votingTimeout = {
                        type = "range",
                        name = L["VOTING_TIMEOUT_DURATION"] or "Timeout Duration",
                        desc = L["SECONDS"] or "Seconds",
                        order = 3,
                        min = Loothing.Timing.MIN_VOTE_TIMEOUT,
                        max = Loothing.Timing.MAX_VOTE_TIMEOUT,
                        step = 5,
                        hidden = function()
                            return Loothing.Settings:GetVotingTimeout() == Loothing.Timing.NO_TIMEOUT
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
                    mlIsObserver = {
                        type = "toggle",
                        name = L["CONFIG_ML_OBSERVER"] or "ML Observer Mode",
                        desc = L["CONFIG_ML_OBSERVER_DESC"] or "Master Looter can see everything and manage sessions but cannot vote",
                        order = 14,
                        width = "half",
                        get = function() return Loothing.Settings:GetMLIsObserver() end,
                        set = function(_, v)
                            Loothing.Settings:SetMLIsObserver(v)
                            if Loothing.MLDB and Loothing.MLDB:IsML() then
                                Loothing.MLDB:BroadcastToRaid()
                            end
                        end,
                    },
                    openObservation = {
                        type = "toggle",
                        name = L["OPEN_OBSERVATION"] or "Open Observation",
                        desc = L["OPEN_OBSERVATION_DESC"] or "Allow all raid members to observe voting",
                        order = 15,
                        width = "half",
                        get = function() return Loothing.Settings:GetOpenObservation() end,
                        set = function(_, v)
                            Loothing.Settings:SetOpenObservation(v)
                            if Loothing.MLDB and Loothing.MLDB:IsML() then
                                Loothing.MLDB:BroadcastToRaid()
                            end
                        end,
                    },
                    autoAddRolls = {
                        type = "toggle",
                        name = L["AUTO_ADD_ROLLS"],
                        desc = L["AUTO_ADD_ROLLS_DESC"],
                        order = 16,
                        width = "half",
                        get = function() return Loothing.Settings:GetAutoAddRolls() end,
                        set = function(_, v) Loothing.Settings:SetAutoAddRolls(v) end,
                    },
                    requireNotes = {
                        type = "toggle",
                        name = L["REQUIRE_NOTES"],
                        desc = L["REQUIRE_NOTES_DESC"],
                        order = 17,
                        width = "half",
                        get = function() return Loothing.Settings:GetRequireNotes() end,
                        set = function(_, v) Loothing.Settings:SetRequireNotes(v) end,
                    },
                },
            },
            -- ============================================================
            -- Response Buttons (visual editor launcher)
            -- ============================================================
            responseButtons = {
                type = "group",
                name = L["CONFIG_BUTTON_SETS"] or "Response Buttons",
                order = 2,
                args = {
                    desc = {
                        type = "description",
                        name = "Configure response button sets, icons, whisper keys, and type-code assignments using the visual editor.",
                        order = 0,
                        width = "full",
                    },
                    openEditor = {
                        type = "execute",
                        name = "Open Response Button Editor",
                        order = 1,
                        func = function()
                            if Loothing.ResponseButtonSettings then
                                Loothing.ResponseButtonSettings:Show()
                            end
                        end,
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
                                        if Loolib.Config and Loolib.Config.Dialog then
                                            Loolib.Config.Dialog:RefreshContent("Loothing")
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
                                if Loolib.Config and Loolib.Config.Dialog then
                                    Loolib.Config.Dialog:RefreshContent("Loothing")
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
                                if Loolib.Config and Loolib.Config.Dialog then
                                    Loolib.Config.Dialog:RefreshContent("Loothing")
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

Options.GetSessionSettingsOptions = GetSessionSettingsOptions
