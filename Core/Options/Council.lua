--[[--------------------------------------------------------------------
    Loothing - Options: Council
    Council member management and roster settings
----------------------------------------------------------------------]]

local Loolib = LibStub("Loolib")

local L = Loothing.Locale

local function GetCouncilOptions()
    return {
        type = "group",
        name = L["COUNCIL"],
        order = 2,
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
                desc = L["CONFIG_COUNCIL_REMOVE_ALL_DESC"] or "Remove all council members from the list",
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
                name = L["CONFIG_GUILD_RANK_DESC"] or "Automatically include guild members at or above a certain rank in the council. This works alongside manually added members.",
                order = 9,
                fontSize = "medium",
            },
            minRank = {
                type = "range",
                name = L["CONFIG_MIN_RANK"] or "Minimum Guild Rank",
                desc = L["CONFIG_MIN_RANK_DESC"] or "Guild members at this rank or higher will be auto-included as council members. 0 = disabled, 1 = Guild Master, 2 = Officers, etc.",
                order = 10,
                min = 0,
                max = 10,
                step = 1,
                get = function() return Loothing.Settings:Get("council.minRank", 0) end,
                set = function(_, v) Loothing.Settings:Set("council.minRank", v) end,
            },
        },
    }
end

Loothing.Options = Loothing.Options or {}
Loothing.Options.GetCouncilOptions = GetCouncilOptions

