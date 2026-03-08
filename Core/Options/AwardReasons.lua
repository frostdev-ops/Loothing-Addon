--[[--------------------------------------------------------------------
    Loothing - Options: Award Reasons
    Award reason configuration for loot distribution
----------------------------------------------------------------------]]

local L = LOOTHING_LOCALE

local function GetAwardReasonsOptions()
    local reasonArgs = {
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

        reasonArgs["reason" .. i .. "Header"] = {
            type = "header",
            name = function()
                local reasons = Loothing.Settings:GetAwardReasons()
                return reasons and reasons[i] and reasons[i].name or ("Reason " .. i)
            end,
            order = i * 10,
            hidden = hiddenFunc,
        }
        reasonArgs["reason" .. i .. "Name"] = {
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
        reasonArgs["reason" .. i .. "Color"] = {
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
        reasonArgs["reason" .. i .. "Sort"] = {
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
        reasonArgs["reason" .. i .. "Log"] = {
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
        reasonArgs["reason" .. i .. "Disenchant"] = {
            type = "toggle",
            name = "Disenchant Reason",
            desc = "Mark this as a disenchant reason (used for auto-award to enchanter)",
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
        reasonArgs["reason" .. i .. "Remove"] = {
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

    return {
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
            reasons = {
                type = "group",
                name = "Reasons",
                order = 2,
                args = reasonArgs,
            },
            management = {
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
            },
        },
    }
end

Loothing.Options = Loothing.Options or {}
Loothing.Options.GetAwardReasonsOptions = GetAwardReasonsOptions
