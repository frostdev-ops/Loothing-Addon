--[[--------------------------------------------------------------------
    Loothing - Options: Session Settings (ML-broadcast)
    These settings are broadcast to all raid members when you are the
    Master Looter. They control the session for everyone.
----------------------------------------------------------------------]]

local _, ns = ...
local Loolib = LibStub("Loolib")
local Loothing = ns.Addon
local Options = ns.Options or {}
ns.Options = Options

local L = ns.Locale
local Utils = ns.Utils

local function CanManageCouncilRoster()
    return Utils and Utils.CanManageCouncilRoster and Utils.CanManageCouncilRoster() or false
end

local function BroadcastMLDBIfNeeded()
    if Loothing.MLDB and Loothing.MLDB:IsML() then
        Loothing.MLDB:BroadcastToRaid()
    end
end

--- Returns true when a non-ML player should be locked out of session settings.
-- Active session + not the ML = settings are controlled by the ML's MLDB broadcast.
local function IsSessionLocked()
    if not Loothing.Session or not Loothing.MLDB then
        return false
    end
    return Loothing.Session:IsActive() and not Loothing.MLDB:IsML()
end

local function GetSessionSettingsOptions()
    local opts = {
        type = "group",
        name = L["SESSION_SETTINGS_ML"],
        desc = L["CONFIG_SESSION_BROADCAST_DESC"],
        order = 1,
        childGroups = "tree",
        args = {
            sessionSettingsDesc = {
                type = "description",
                name = function()
                    local base = "|cffffcc00" .. L["CONFIG_SESSION_BROADCAST_NOTE"] .. "|r"
                    if IsSessionLocked() then
                        local ml = Loothing.MLDB:GetML() or "Master Looter"
                        return base .. "\n\n|cffff4444" .. string.format(L["SESSION_SETTINGS_LOCKED"] or "Settings are locked while a session is active. The Master Looter (%s) controls these settings.", ml) .. "|r"
                    end
                    return base
                end,
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
                disabled = IsSessionLocked,
                args = {
                    votingMode = {
                        type = "select",
                        name = L["VOTING_MODE"],
                        desc = L["VOTING_MODE_DESC"],
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
                        name = L["VOTING_TIMEOUT"],
                        desc = L["CONFIG_VOTING_TIMEOUT_DESC"],
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
                        name = L["VOTING_TIMEOUT_DURATION"],
                        desc = L["SECONDS"],
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
                    -- Session Trigger Policy (split model)
                    triggerHeader = {
                        type = "header",
                        name = L["SESSION_TRIGGER_HEADER"],
                        order = 4,
                    },
                    sessionTriggerAction = {
                        type = "select",
                        name = L["SESSION_TRIGGER_ACTION"],
                        desc = L["SESSION_TRIGGER_ACTION_DESC"],
                        order = 5,
                        values = {
                            manual = L["TRIGGER_MANUAL"],
                            prompt = L["TRIGGER_PROMPT"],
                            auto   = L["TRIGGER_AUTO"],
                        },
                        sorting = { "manual", "prompt", "auto" },
                        get = function() return Loothing.Settings:GetSessionTriggerAction() end,
                        set = function(_, v) Loothing.Settings:SetSessionTriggerAction(v) end,
                    },
                    sessionTriggerTiming = {
                        type = "select",
                        name = L["SESSION_TRIGGER_TIMING"],
                        desc = L["SESSION_TRIGGER_TIMING_DESC"],
                        order = 6,
                        values = {
                            encounterEnd = L["TRIGGER_TIMING_ENCOUNTER_END"],
                            afterLoot    = L["TRIGGER_TIMING_AFTER_LOOT"],
                        },
                        sorting = { "encounterEnd", "afterLoot" },
                        get = function() return Loothing.Settings:GetSessionTriggerTiming() end,
                        set = function(_, v) Loothing.Settings:SetSessionTriggerTiming(v) end,
                    },
                    sessionTriggerRaid = {
                        type = "toggle",
                        name = L["TRIGGER_SCOPE_RAID"],
                        desc = L["TRIGGER_SCOPE_RAID_DESC"],
                        order = 7,
                        width = "half",
                        get = function() return Loothing.Settings:GetSessionTriggerRaid() end,
                        set = function(_, v) Loothing.Settings:SetSessionTriggerRaid(v) end,
                    },
                    sessionTriggerDungeon = {
                        type = "toggle",
                        name = L["TRIGGER_SCOPE_DUNGEON"],
                        desc = L["TRIGGER_SCOPE_DUNGEON_DESC"],
                        order = 8,
                        width = "half",
                        get = function() return Loothing.Settings:GetSessionTriggerDungeon() end,
                        set = function(_, v) Loothing.Settings:SetSessionTriggerDungeon(v) end,
                    },
                    sessionTriggerOpenWorld = {
                        type = "toggle",
                        name = L["TRIGGER_SCOPE_OPEN_WORLD"],
                        desc = L["TRIGGER_SCOPE_OPEN_WORLD_DESC"],
                        order = 9,
                        width = "half",
                        get = function() return Loothing.Settings:GetSessionTriggerOpenWorld() end,
                        set = function(_, v) Loothing.Settings:SetSessionTriggerOpenWorld(v) end,
                    },
                    triggerScopeNote = {
                        type = "description",
                        name = "|cff888888" .. L["CONFIG_TRIGGER_SCOPE_NOTE"] .. "|r",
                        order = 9.5,
                        fontSize = "small",
                        width = "full",
                    },
                    handleLootToggle = {
                        type = "toggle",
                        name = L["HANDLE_LOOT_TOGGLE"],
                        desc = L["HANDLE_LOOT_TOGGLE_DESC"],
                        order = 9.8,
                        width = "full",
                        get = function() return Loothing.handleLoot end,
                        set = function(_, v) Loothing:SetHandleLoot(v) end,
                        disabled = function()
                            return not (Loothing.MLDB and Loothing.MLDB:IsML())
                        end,
                    },
                    groupLootMode = {
                        type = "select",
                        name = L["GROUP_LOOT_MODE"],
                        desc = L["GROUP_LOOT_MODE_DESC"],
                        order = 10,
                        width = "full",
                        values = {
                            active = L["GROUP_LOOT_MODE_ACTIVE"],
                            passive = L["GROUP_LOOT_MODE_PASSIVE"],
                        },
                        sorting = { "active", "passive" },
                        get = function() return Loothing.Settings:GetGroupLootMode() end,
                        set = function(_, v)
                            Loothing.Settings:SetGroupLootMode(v)
                            BroadcastMLDBIfNeeded()
                        end,
                    },
                    selfVote = {
                        type = "toggle",
                        name = L["SELF_VOTE"],
                        desc = L["SELF_VOTE_DESC"],
                        order = 11,
                        width = "half",
                        get = function() return Loothing.Settings:GetSelfVote() end,
                        set = function(_, v) Loothing.Settings:SetSelfVote(v) end,
                    },
                    multiVote = {
                        type = "toggle",
                        name = L["MULTI_VOTE"],
                        desc = L["MULTI_VOTE_DESC"],
                        order = 12,
                        width = "half",
                        get = function() return Loothing.Settings:GetMultiVote() end,
                        set = function(_, v) Loothing.Settings:SetMultiVote(v) end,
                    },
                    anonymousVoting = {
                        type = "toggle",
                        name = L["ANONYMOUS_VOTING"],
                        desc = L["ANONYMOUS_VOTING_DESC"],
                        order = 13,
                        width = "half",
                        get = function() return Loothing.Settings:GetAnonymousVoting() end,
                        set = function(_, v) Loothing.Settings:SetAnonymousVoting(v) end,
                    },
                    hideVotes = {
                        type = "toggle",
                        name = L["HIDE_VOTES"],
                        desc = L["HIDE_VOTES_DESC"],
                        order = 14,
                        width = "half",
                        get = function() return Loothing.Settings:GetHideVotes() end,
                        set = function(_, v) Loothing.Settings:SetHideVotes(v) end,
                    },
                    mlIsObserver = {
                        type = "toggle",
                        name = L["CONFIG_ML_OBSERVER"],
                        desc = L["CONFIG_ML_OBSERVER_DESC"],
                        order = 15,
                        width = "half",
                        get = function() return Loothing.Settings:GetMLIsObserver() end,
                        set = function(_, v)
                            Loothing.Settings:SetMLIsObserver(v)
                            BroadcastMLDBIfNeeded()
                        end,
                    },
                    openObservation = {
                        type = "toggle",
                        name = L["OPEN_OBSERVATION"],
                        desc = L["OPEN_OBSERVATION_DESC"],
                        order = 16,
                        width = "half",
                        get = function() return Loothing.Settings:GetOpenObservation() end,
                        set = function(_, v)
                            Loothing.Settings:SetOpenObservation(v)
                            BroadcastMLDBIfNeeded()
                        end,
                    },
                    autoAddRolls = {
                        type = "toggle",
                        name = L["AUTO_ADD_ROLLS"],
                        desc = L["AUTO_ADD_ROLLS_DESC"],
                        order = 17,
                        width = "half",
                        get = function() return Loothing.Settings:GetAutoAddRolls() end,
                        set = function(_, v) Loothing.Settings:SetAutoAddRolls(v) end,
                    },
                    requireNotes = {
                        type = "toggle",
                        name = L["REQUIRE_NOTES"],
                        desc = L["REQUIRE_NOTES_DESC"],
                        order = 18,
                        width = "half",
                        get = function() return Loothing.Settings:GetRequireNotes() end,
                        set = function(_, v) Loothing.Settings:SetRequireNotes(v) end,
                    },
                    mlSeesVotes = {
                        type = "toggle",
                        name = L["CONFIG_VOTING_MLSEESVOTES"],
                        desc = L["CONFIG_VOTING_MLSEESVOTES_DESC"],
                        order = 19,
                        width = "half",
                        get = function() return Loothing.Settings:GetMlSeesVotes() end,
                        set = function(_, v) Loothing.Settings:SetMlSeesVotes(v) end,
                    },
                    autoPassSilent = {
                        type = "toggle",
                        name = L["CONFIG_AUTOPASS_SILENT"],
                        desc = L["CONFIG_AUTOPASS_SILENT_DESC"],
                        order = 19.5,
                        width = "half",
                        get = function() return Loothing.Settings:Get("autoPass.silent") end,
                        set = function(_, v)
                            Loothing.Settings:Set("autoPass.silent", v)
                            BroadcastMLDBIfNeeded()
                        end,
                    },
                    rcvSettingsHeader = {
                        type = "header",
                        name = L["RCV_SETTINGS"],
                        order = 20,
                        hidden = function()
                            return Loothing.Settings:GetVotingMode() ~= Loothing.VotingMode.RANKED_CHOICE
                        end,
                    },
                    maxRanks = {
                        type = "range",
                        name = L["MAX_RANKS"],
                        desc = L["MAX_RANKS_DESC"],
                        order = 21,
                        min = 0,
                        max = 10,
                        step = 1,
                        hidden = function()
                            return Loothing.Settings:GetVotingMode() ~= Loothing.VotingMode.RANKED_CHOICE
                        end,
                        get = function() return Loothing.Settings:GetMaxRanks() end,
                        set = function(_, v) Loothing.Settings:SetMaxRanks(v) end,
                    },
                    minRanks = {
                        type = "range",
                        name = L["MIN_RANKS"],
                        desc = L["MIN_RANKS_DESC"],
                        order = 22,
                        min = 1,
                        max = 10,
                        step = 1,
                        hidden = function()
                            return Loothing.Settings:GetVotingMode() ~= Loothing.VotingMode.RANKED_CHOICE
                        end,
                        get = function() return Loothing.Settings:GetMinRanks() end,
                        set = function(_, v) Loothing.Settings:SetMinRanks(v) end,
                    },
                },
            },
            -- ============================================================
            -- Response Buttons (visual editor launcher)
            -- ============================================================
            responseButtons = {
                type = "group",
                name = L["CONFIG_BUTTON_SETS"],
                order = 2,
                disabled = IsSessionLocked,
                args = {
                    desc = {
                        type = "description",
                        name = L["CONFIG_BUTTON_SETS_DESC"],
                        order = 0,
                        width = "full",
                    },
                    openEditor = {
                        type = "execute",
                        name = L["CONFIG_OPEN_BUTTON_EDITOR"],
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
            -- Winner Determination
            -- ============================================================
            winnerDetermination = {
                type = "group",
                name = L["WINNER_DETERMINATION"],
                desc = L["WINNER_DETERMINATION_DESC"],
                order = 3,
                disabled = IsSessionLocked,
                args = {
                    mode = {
                        type = "select",
                        name = L["WINNER_MODE"],
                        desc = L["WINNER_MODE_DESC"],
                        order = 1,
                        values = {
                            HIGHEST_VOTES = L["WINNER_MODE_HIGHEST_VOTES"],
                            ML_CONFIRM = L["WINNER_MODE_ML_CONFIRM"],
                            AUTO_HIGHEST_CONFIRM = L["WINNER_MODE_AUTO_CONFIRM"],
                        },
                        get = function() return Loothing.Settings:Get("winnerDetermination.mode", "ML_CONFIRM") end,
                        set = function(_, v) Loothing.Settings:Set("winnerDetermination.mode", v) end,
                    },
                    tieBreaker = {
                        type = "select",
                        name = L["WINNER_TIE_BREAKER"],
                        desc = L["WINNER_TIE_BREAKER_DESC"],
                        order = 2,
                        values = {
                            ROLL = L["WINNER_TIE_USE_ROLL"],
                            ML_CHOICE = L["WINNER_TIE_ML_CHOICE"],
                            REVOTE = L["WINNER_TIE_REVOTE"],
                        },
                        get = function() return Loothing.Settings:GetTieBreakerMode() end,
                        set = function(_, v) Loothing.Settings:Set("winnerDetermination.tieBreaker", v) end,
                    },
                    autoAwardOnUnanimous = {
                        type = "toggle",
                        name = L["WINNER_AUTO_AWARD_UNANIMOUS"],
                        desc = L["WINNER_AUTO_AWARD_UNANIMOUS_DESC"],
                        order = 3,
                        get = function() return Loothing.Settings:GetAutoAwardOnUnanimous() end,
                        set = function(_, v) Loothing.Settings:Set("winnerDetermination.autoAwardOnUnanimous", v) end,
                    },
                    requireConfirmation = {
                        type = "toggle",
                        name = L["WINNER_REQUIRE_CONFIRMATION"],
                        desc = L["WINNER_REQUIRE_CONFIRMATION_DESC"],
                        order = 4,
                        get = function() return Loothing.Settings:GetRequireConfirmation() end,
                        set = function(_, v) Loothing.Settings:Set("winnerDetermination.requireConfirmation", v) end,
                    },
                    maxRevotes = {
                        type = "range",
                        name = L["MAX_REVOTES"],
                        desc = L["CONFIG_MAX_REVOTES_DESC"],
                        order = 5,
                        min = 0,
                        max = 10,
                        step = 1,
                        get = function() return Loothing.Settings:GetMaxRevotes() end,
                        set = function(_, v) Loothing.Settings:SetMaxRevotes(v) end,
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
                disabled = IsSessionLocked,
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
                                return "|cff888888" .. L["CONFIG_COUNCIL_NO_MEMBERS"] .. "|r\n\n" .. L["CONFIG_COUNCIL_ADD_HELP"]
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
                        desc = L["CONFIG_COUNCIL_ADD_NAME_DESC"],
                        order = 5,
                        width = "double",
                        hidden = function() return not CanManageCouncilRoster() end,
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
                        desc = L["CONFIG_COUNCIL_REMOVE_DESC"],
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
                                Loothing:Print(string.format(L["CONFIG_COUNCIL_MEMBER_REMOVED"], value))
                                if Loolib.Config and Loolib.Config.Dialog then
                                    Loolib.Config.Dialog:RefreshContent("Loothing")
                                end
                            end
                        end,
                        hidden = function()
                            if not CanManageCouncilRoster() then
                                return true
                            end
                            local members = Loothing.Council and Loothing.Council:GetMembers() or {}
                            return #members == 0
                        end,
                        confirm = function(_, value)
                            if not value or value == "" then return false end
                            return string.format(L["CONFIG_COUNCIL_CONFIRM_REMOVE"], value)
                        end,
                    },
                    removeAll = {
                        type = "execute",
                        name = L["CONFIG_COUNCIL_REMOVE_ALL"],
                        order = 7,
                        hidden = function()
                            if not CanManageCouncilRoster() then
                                return true
                            end
                            local members = Loothing.Council and Loothing.Council:GetMembers() or {}
                            return #members == 0
                        end,
                        func = function()
                            if Loothing.Council then
                                local members = Loothing.Council:GetMembers()
                                for i = #members, 1, -1 do
                                    Loothing.Council:RemoveMember(members[i])
                                end
                                Loothing:Print(L["CONFIG_COUNCIL_ALL_REMOVED"])
                                if Loolib.Config and Loolib.Config.Dialog then
                                    Loolib.Config.Dialog:RefreshContent("Loothing")
                                end
                            end
                        end,
                        confirm = function()
                            return L["CONFIG_COUNCIL_CONFIRM_REMOVE_ALL"]
                        end,
                    },
                    guildRankHeader = {
                        type = "header",
                        name = L["CONFIG_GUILD_RANK"],
                        order = 8,
                    },
                    guildRankDesc = {
                        type = "description",
                        name = L["CONFIG_GUILD_RANK_DESC"],
                        order = 9,
                        fontSize = "medium",
                    },
                    minRank = {
                        type = "range",
                        name = L["CONFIG_MIN_RANK"],
                        desc = L["CONFIG_MIN_RANK_DESC"],
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
                name = L["CONFIG_AWARD_REASONS"],
                order = 5,
                disabled = IsSessionLocked,
                args = {
                    desc = {
                        type = "description",
                        name = L["CONFIG_AWARD_REASONS_EDITOR_DESC"],
                        order = 1,
                        width = "full",
                    },
                    openEditor = {
                        type = "execute",
                        name = L["CONFIG_OPEN_AWARD_REASON_EDITOR"],
                        order = 2,
                        func = function()
                            if Loothing.AwardReasonsSettings then
                                Loothing.AwardReasonsSettings:Show()
                            end
                        end,
                    },
                },
            },
            -- ============================================================
            -- Observer Permissions
            -- ============================================================
            observerPermissions = {
                type = "group",
                name = L["OBSERVER_PERMISSIONS"],
                order = 6,
                disabled = IsSessionLocked,
                args = {
                    desc = {
                        type = "description",
                        name = L["CONFIG_OBSERVER_PERMISSIONS_DESC"],
                        order = 0,
                    },
                    seeVoteCounts = {
                        type = "toggle",
                        name = L["OBSERVER_SEE_VOTE_COUNTS"],
                        desc = L["OBSERVER_SEE_VOTE_COUNTS_DESC"],
                        order = 1,
                        get = function()
                            local perms = Loothing.Settings:GetObserverPermissions()
                            return perms.seeVoteCounts
                        end,
                        set = function(_, v)
                            Loothing.Settings:SetObserverPermission("seeVoteCounts", v)
                            if Loothing.MLDB and Loothing.MLDB:IsML() then
                                Loothing.MLDB:BroadcastToRaid()
                            end
                        end,
                    },
                    seeVoterIdentities = {
                        type = "toggle",
                        name = L["OBSERVER_SEE_VOTER_IDS"],
                        desc = L["OBSERVER_SEE_VOTER_IDS_DESC"],
                        order = 2,
                        get = function()
                            local perms = Loothing.Settings:GetObserverPermissions()
                            return perms.seeVoterIdentities
                        end,
                        set = function(_, v)
                            Loothing.Settings:SetObserverPermission("seeVoterIdentities", v)
                            if Loothing.MLDB and Loothing.MLDB:IsML() then
                                Loothing.MLDB:BroadcastToRaid()
                            end
                        end,
                    },
                    seeResponses = {
                        type = "toggle",
                        name = L["OBSERVER_SEE_RESPONSES"],
                        desc = L["OBSERVER_SEE_RESPONSES_DESC"],
                        order = 3,
                        get = function()
                            local perms = Loothing.Settings:GetObserverPermissions()
                            return perms.seeResponses
                        end,
                        set = function(_, v)
                            Loothing.Settings:SetObserverPermission("seeResponses", v)
                            if Loothing.MLDB and Loothing.MLDB:IsML() then
                                Loothing.MLDB:BroadcastToRaid()
                            end
                        end,
                    },
                    seeNotes = {
                        type = "toggle",
                        name = L["OBSERVER_SEE_NOTES"],
                        desc = L["OBSERVER_SEE_NOTES_DESC"],
                        order = 4,
                        get = function()
                            local perms = Loothing.Settings:GetObserverPermissions()
                            return perms.seeNotes
                        end,
                        set = function(_, v)
                            Loothing.Settings:SetObserverPermission("seeNotes", v)
                            if Loothing.MLDB and Loothing.MLDB:IsML() then
                                Loothing.MLDB:BroadcastToRaid()
                            end
                        end,
                    },
                },
            },
        },
    }

    return opts
end

Options.GetSessionSettingsOptions = GetSessionSettingsOptions
