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

local function RefreshSettingsDialog()
    if Loolib.Config and type(Loolib.Config.NotifyChange) == "function" then
        Loolib.Config:NotifyChange("Loothing")
    elseif Loolib.Config and Loolib.Config.Dialog then
        Loolib.Config.Dialog:RefreshContent("Loothing")
    end
end

local function GetAwardReasonAtIndex(index)
    local reasons = Loothing.Settings:GetAwardReasons()
    return reasons and reasons[index] or nil
end


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
                    -- Session Trigger Policy (split model)
                    triggerHeader = {
                        type = "header",
                        name = L["SESSION_TRIGGER_HEADER"] or "Session Trigger",
                        order = 4,
                    },
                    sessionTriggerAction = {
                        type = "select",
                        name = L["SESSION_TRIGGER_ACTION"] or "Trigger Action",
                        desc = L["SESSION_TRIGGER_ACTION_DESC"] or "What happens when a boss kill is eligible",
                        order = 5,
                        values = {
                            manual = L["TRIGGER_MANUAL"] or "Manual (use /loothing start)",
                            prompt = L["TRIGGER_PROMPT"] or "Prompt (ask before starting)",
                            auto   = L["TRIGGER_AUTO"] or "Automatic (start immediately)",
                        },
                        sorting = { "manual", "prompt", "auto" },
                        get = function() return Loothing.Settings:GetSessionTriggerAction() end,
                        set = function(_, v) Loothing.Settings:SetSessionTriggerAction(v) end,
                    },
                    sessionTriggerTiming = {
                        type = "select",
                        name = L["SESSION_TRIGGER_TIMING"] or "Trigger Timing",
                        desc = L["SESSION_TRIGGER_TIMING_DESC"] or "When the trigger action fires relative to the boss kill",
                        order = 6,
                        values = {
                            encounterEnd = L["TRIGGER_TIMING_ENCOUNTER_END"] or "On Boss Kill",
                            afterLoot    = L["TRIGGER_TIMING_AFTER_LOOT"] or "After ML Receives Loot",
                        },
                        sorting = { "encounterEnd", "afterLoot" },
                        get = function() return Loothing.Settings:GetSessionTriggerTiming() end,
                        set = function(_, v) Loothing.Settings:SetSessionTriggerTiming(v) end,
                    },
                    sessionTriggerRaid = {
                        type = "toggle",
                        name = L["TRIGGER_SCOPE_RAID"] or "Raid Bosses",
                        desc = L["TRIGGER_SCOPE_RAID_DESC"] or "Trigger on raid boss kills",
                        order = 7,
                        width = "half",
                        get = function() return Loothing.Settings:GetSessionTriggerRaid() end,
                        set = function(_, v) Loothing.Settings:SetSessionTriggerRaid(v) end,
                    },
                    sessionTriggerDungeon = {
                        type = "toggle",
                        name = L["TRIGGER_SCOPE_DUNGEON"] or "Dungeon Bosses",
                        desc = L["TRIGGER_SCOPE_DUNGEON_DESC"] or "Trigger on dungeon boss kills",
                        order = 8,
                        width = "half",
                        get = function() return Loothing.Settings:GetSessionTriggerDungeon() end,
                        set = function(_, v) Loothing.Settings:SetSessionTriggerDungeon(v) end,
                    },
                    sessionTriggerOpenWorld = {
                        type = "toggle",
                        name = L["TRIGGER_SCOPE_OPEN_WORLD"] or "Open World",
                        desc = L["TRIGGER_SCOPE_OPEN_WORLD_DESC"] or "Trigger on open-world encounters (e.g. world bosses)",
                        order = 9,
                        width = "half",
                        get = function() return Loothing.Settings:GetSessionTriggerOpenWorld() end,
                        set = function(_, v) Loothing.Settings:SetSessionTriggerOpenWorld(v) end,
                    },
                    triggerScopeNote = {
                        type = "description",
                        name = "|cff888888PvP, arena, and scenario encounters never trigger sessions. Raid-only is the default.|r",
                        order = 9.5,
                        fontSize = "small",
                        width = "full",
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
                    mlSeesVotes = {
                        type = "toggle",
                        name = L["CONFIG_VOTING_MLSEESVOTES"] or "ML Sees Votes",
                        desc = L["CONFIG_VOTING_MLSEESVOTES_DESC"] or "Master Looter can see votes even when anonymous",
                        order = 18,
                        width = "half",
                        get = function() return Loothing.Settings:GetMlSeesVotes() end,
                        set = function(_, v) Loothing.Settings:SetMlSeesVotes(v) end,
                    },
                    rcvSettingsHeader = {
                        type = "header",
                        name = L["RCV_SETTINGS"] or "Ranked Choice Settings",
                        order = 19,
                        hidden = function()
                            return Loothing.Settings:GetVotingMode() ~= Loothing.VotingMode.RANKED_CHOICE
                        end,
                    },
                    maxRanks = {
                        type = "range",
                        name = L["MAX_RANKS"] or "Maximum Rankings",
                        desc = L["MAX_RANKS_DESC"] or "Maximum number of choices a voter can rank (0 = unlimited)",
                        order = 20,
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
                        name = L["MIN_RANKS"] or "Minimum Rankings",
                        desc = L["MIN_RANKS_DESC"] or "Minimum number of choices required to submit a vote",
                        order = 21,
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
            -- Winner Determination
            -- ============================================================
            winnerDetermination = {
                type = "group",
                name = L["WINNER_DETERMINATION"] or "Winner Determination",
                desc = L["WINNER_DETERMINATION_DESC"] or "Configure how winners are selected when voting ends",
                order = 3,
                args = {
                    mode = {
                        type = "select",
                        name = L["WINNER_MODE"] or "Winner Mode",
                        desc = L["WINNER_MODE_DESC"] or "How the winner is determined after voting",
                        order = 1,
                        values = {
                            HIGHEST_VOTES = L["WINNER_MODE_HIGHEST_VOTES"] or "Highest Council Votes",
                            ML_CONFIRM = L["WINNER_MODE_ML_CONFIRM"] or "ML Confirms Winner",
                            AUTO_HIGHEST_CONFIRM = L["WINNER_MODE_AUTO_CONFIRM"] or "Auto-select Highest + Confirm",
                        },
                        get = function() return Loothing.Settings:Get("winnerDetermination.mode", "ML_CONFIRM") end,
                        set = function(_, v) Loothing.Settings:Set("winnerDetermination.mode", v) end,
                    },
                    tieBreaker = {
                        type = "select",
                        name = L["WINNER_TIE_BREAKER"] or "Tie Breaker",
                        desc = L["WINNER_TIE_BREAKER_DESC"] or "How ties are resolved when candidates have equal votes",
                        order = 2,
                        values = {
                            ROLL = L["WINNER_TIE_USE_ROLL"] or "Random (Simulated Roll)",
                            ML_CHOICE = L["WINNER_TIE_ML_CHOICE"] or "ML Decides",
                            REVOTE = L["WINNER_TIE_REVOTE"] or "Force Re-Vote",
                        },
                        get = function() return Loothing.Settings:GetTieBreakerMode() end,
                        set = function(_, v) Loothing.Settings:Set("winnerDetermination.tieBreaker", v) end,
                    },
                    autoAwardOnUnanimous = {
                        type = "toggle",
                        name = L["WINNER_AUTO_AWARD_UNANIMOUS"] or "Auto-award on Unanimous",
                        desc = L["WINNER_AUTO_AWARD_UNANIMOUS_DESC"] or "Automatically award when all council members vote for the same candidate",
                        order = 3,
                        get = function() return Loothing.Settings:GetAutoAwardOnUnanimous() end,
                        set = function(_, v) Loothing.Settings:Set("winnerDetermination.autoAwardOnUnanimous", v) end,
                    },
                    requireConfirmation = {
                        type = "toggle",
                        name = L["WINNER_REQUIRE_CONFIRMATION"] or "Require Confirmation",
                        desc = L["WINNER_REQUIRE_CONFIRMATION_DESC"] or "Show confirmation dialog before awarding items",
                        order = 4,
                        get = function() return Loothing.Settings:GetRequireConfirmation() end,
                        set = function(_, v) Loothing.Settings:Set("winnerDetermination.requireConfirmation", v) end,
                    },
                    maxRevotes = {
                        type = "range",
                        name = L["MAX_REVOTES"] or "Maximum Re-votes",
                        desc = "Maximum number of re-votes allowed per item (0 = no re-votes)",
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
            -- ============================================================
            -- Observer Permissions
            -- ============================================================
            observerPermissions = {
                type = "group",
                name = L["OBSERVER_PERMISSIONS"] or "Observer Permissions",
                order = 6,
                args = {
                    desc = {
                        type = "description",
                        name = "Control what observers can see during voting sessions.",
                        order = 0,
                    },
                    seeVoteCounts = {
                        type = "toggle",
                        name = L["OBSERVER_SEE_VOTE_COUNTS"] or "See Vote Counts",
                        desc = L["OBSERVER_SEE_VOTE_COUNTS_DESC"] or "Observers can see how many votes each candidate has",
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
                        name = L["OBSERVER_SEE_VOTER_IDS"] or "See Voter Identities",
                        desc = L["OBSERVER_SEE_VOTER_IDS_DESC"] or "Observers can see who voted for each candidate",
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
                        name = L["OBSERVER_SEE_RESPONSES"] or "See Responses",
                        desc = L["OBSERVER_SEE_RESPONSES_DESC"] or "Observers can see what response each candidate selected",
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
                        name = L["OBSERVER_SEE_NOTES"] or "See Notes",
                        desc = L["OBSERVER_SEE_NOTES_DESC"] or "Observers can see candidate notes",
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
            return GetAwardReasonAtIndex(i) == nil
        end
        perReasonArgs["reason" .. i .. "Header"] = {
            type = "header",
            name = function()
                local reason = GetAwardReasonAtIndex(i)
                return reason and reason.name or ("Reason " .. i)
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
                local reason = GetAwardReasonAtIndex(i)
                return reason and reason.name or ""
            end,
            set = function(_, v)
                local reason = GetAwardReasonAtIndex(i)
                if reason then
                    Loothing.Settings:UpdateAwardReason(reason.id, { name = v })
                end
            end,
        }
        perReasonArgs["reason" .. i .. "Color"] = {
            type = "color",
            name = "Color",
            order = i * 10 + 2,
            hasAlpha = true,
            hidden = hiddenFunc,
            get = function()
                local reason = GetAwardReasonAtIndex(i)
                if reason and reason.color then
                    return unpack(reason.color)
                end
                return 1, 1, 1, 1
            end,
            set = function(_, r, g, b, a)
                local reason = GetAwardReasonAtIndex(i)
                if reason then
                    Loothing.Settings:UpdateAwardReason(reason.id, { color = { r, g, b, a } })
                end
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
                local reason = GetAwardReasonAtIndex(i)
                return reason and reason.sort or i
            end,
            set = function(_, v)
                local reason = GetAwardReasonAtIndex(i)
                if reason then
                    Loothing.Settings:UpdateAwardReason(reason.id, { sort = v })
                end
            end,
        }
        perReasonArgs["reason" .. i .. "Log"] = {
            type = "toggle",
            name = "Log to History",
            order = i * 10 + 4,
            hidden = hiddenFunc,
            get = function()
                local reason = GetAwardReasonAtIndex(i)
                return reason and reason.log
            end,
            set = function(_, v)
                local reason = GetAwardReasonAtIndex(i)
                if reason then
                    Loothing.Settings:UpdateAwardReason(reason.id, { log = v })
                end
            end,
        }
        perReasonArgs["reason" .. i .. "Disenchant"] = {
            type = "toggle",
            name = "Disenchant Reason",
            order = i * 10 + 5,
            hidden = hiddenFunc,
            get = function()
                local reason = GetAwardReasonAtIndex(i)
                return reason and reason.disenchant
            end,
            set = function(_, v)
                local reason = GetAwardReasonAtIndex(i)
                if reason then
                    Loothing.Settings:UpdateAwardReason(reason.id, { disenchant = v })
                end
            end,
        }
        perReasonArgs["reason" .. i .. "Remove"] = {
            type = "execute",
            name = "Remove",
            order = i * 10 + 6,
            hidden = hiddenFunc,
            confirm = "Remove this award reason?",
            func = function()
                local reason = GetAwardReasonAtIndex(i)
                if reason then
                    Loothing.Settings:RemoveAwardReason(reason.id)
                    RefreshSettingsDialog()
                end
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
                    if Loothing.Settings:AddAwardReason("New Reason", { 1, 1, 1, 1 }) then
                        RefreshSettingsDialog()
                    end
                end,
            },
            resetDefaults = {
                type = "execute",
                name = "Reset to Defaults",
                order = 2,
                confirm = "Reset all award reasons to their default values? This cannot be undone.",
                func = function()
                    Loothing.Settings:ResetAwardReasonsToDefaults()
                    RefreshSettingsDialog()
                end,
            },
        },
    }

    return opts
end

Options.GetSessionSettingsOptions = GetSessionSettingsOptions
