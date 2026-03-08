--[[--------------------------------------------------------------------
    Loothing - Options: Voting
    Voting configuration (mode, timeout, triggers, options)
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

local function GetVotingOptions()
    local opts = {
        type = "group",
        name = L["VOTING"],
        order = 1,
        args = {
            general = {
                type = "group",
                name = L["GENERAL"],
                order = 1,
                inline = false,
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
                    votingTimeout = {
                        type = "range",
                        name = L["VOTING_TIMEOUT"],
                        desc = L["SECONDS"],
                        order = 2,
                        min = LOOTHING_TIMING.MIN_VOTE_TIMEOUT,
                        max = LOOTHING_TIMING.MAX_VOTE_TIMEOUT,
                        step = 5,
                        get = function() return Loothing.Settings:GetVotingTimeout() end,
                        set = function(_, v) Loothing.Settings:SetVotingTimeout(v) end,
                    },
                    sessionTriggerMode = {
                        type = "select",
                        name = L["SESSION_TRIGGER_MODE"] or "Session Trigger Mode",
                        desc = L["SESSION_TRIGGER_MODE_DESC"] or "How loot sessions are started after a boss kill",
                        order = 3,
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
                },
            },
            options = {
                type = "group",
                name = L["VOTING_OPTIONS"],
                order = 2,
                inline = false,
                args = {
                    selfVote = {
                        type = "toggle",
                        name = L["SELF_VOTE"],
                        desc = L["SELF_VOTE_DESC"],
                        order = 1,
                        get = function() return Loothing.Settings:GetSelfVote() end,
                        set = function(_, v) Loothing.Settings:SetSelfVote(v) end,
                    },
                    multiVote = {
                        type = "toggle",
                        name = L["MULTI_VOTE"],
                        desc = L["MULTI_VOTE_DESC"],
                        order = 2,
                        get = function() return Loothing.Settings:GetMultiVote() end,
                        set = function(_, v) Loothing.Settings:SetMultiVote(v) end,
                    },
                    anonymousVoting = {
                        type = "toggle",
                        name = L["ANONYMOUS_VOTING"],
                        desc = L["ANONYMOUS_VOTING_DESC"],
                        order = 3,
                        get = function() return Loothing.Settings:GetAnonymousVoting() end,
                        set = function(_, v) Loothing.Settings:SetAnonymousVoting(v) end,
                    },
                    hideVotes = {
                        type = "toggle",
                        name = L["HIDE_VOTES"],
                        desc = L["HIDE_VOTES_DESC"],
                        order = 4,
                        get = function() return Loothing.Settings:GetHideVotes() end,
                        set = function(_, v) Loothing.Settings:SetHideVotes(v) end,
                    },
                    observe = {
                        type = "toggle",
                        name = L["OBSERVE_MODE"],
                        desc = L["OBSERVE_MODE_DESC"],
                        order = 5,
                        get = function() return Loothing.Settings:GetObserveMode() end,
                        set = function(_, v) Loothing.Settings:SetObserveMode(v) end,
                    },
                    autoAddRolls = {
                        type = "toggle",
                        name = L["AUTO_ADD_ROLLS"],
                        desc = L["AUTO_ADD_ROLLS_DESC"],
                        order = 6,
                        get = function() return Loothing.Settings:GetAutoAddRolls() end,
                        set = function(_, v) Loothing.Settings:SetAutoAddRolls(v) end,
                    },
                    requireNotes = {
                        type = "toggle",
                        name = L["REQUIRE_NOTES"],
                        desc = L["REQUIRE_NOTES_DESC"],
                        order = 7,
                        get = function() return Loothing.Settings:GetRequireNotes() end,
                        set = function(_, v) Loothing.Settings:SetRequireNotes(v) end,
                    },
                    numButtons = {
                        type = "range",
                        name = L["NUM_BUTTONS"],
                        desc = L["NUM_BUTTONS_DESC"],
                        order = 8,
                        min = 1,
                        max = 10,
                        step = 1,
                        get = function() return Loothing.Settings:GetNumButtons() end,
                        set = function(_, v) Loothing.Settings:SetNumButtons(v) end,
                    },
                },
            },
            buttonSets = {
                type = "group",
                name = L["CONFIG_BUTTON_SETS"] or "Button Sets",
                order = 3,
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
                    buttonsHeader = {
                        type = "header",
                        name = "Buttons",
                        order = 10,
                    },
                },
            },
            setManagement = {
                type = "group",
                name = "Manage Sets",
                order = 4,
                inline = true,
                args = {
                    newSetName = {
                        type = "input",
                        name = "New Set Name",
                        order = 1,
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
                        order = 2,
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
                        order = 3,
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
                },
            },
            typeCodeAssignment = {
                type = "group",
                name = L["CONFIG_TYPECODE_ASSIGNMENT"] or "Type Code Assignment",
                order = 5,
                args = {
                    desc = {
                        type = "description",
                        name = "Assign which button set to use for each item type code. Items matching a specific type code will show the assigned button set instead of the default.",
                        order = 0,
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

    return opts
end

Loothing.Options = Loothing.Options or {}
Loothing.Options.GetVotingOptions = GetVotingOptions
