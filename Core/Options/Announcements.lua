--[[--------------------------------------------------------------------
    Loothing - Options: Announcements
    Chat channel and message format settings
----------------------------------------------------------------------]]

local L = Loothing.Locale

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
--- @param getLineFn fun(i: integer): table? Returns {enabled, channel, text} for line i
--- @param setLineFn fun(i: integer, enabled: boolean, channel: string, text: string)
--- @param prefix string Key prefix for option names (e.g. "award", "item")
--- @return table args Config option args table
local function MakeLineOptions(getLineFn, setLineFn, prefix)
    local args = {
        desc = {
            type = "description",
            name = L["CONFIG_ANNOUNCEMENT_TOKENS_DESC"]
                or "Configure up to 5 announcement lines. Available tokens: {item}, {winner}, {reason}, {notes}, {ilvl}, {type}, {oldItem}, {ml}, {session}, {votes}",
            order = 0,
        },
    }

    for i = 1, 5 do
        local baseOrder = i * 10

        args[prefix .. i .. "Header"] = {
            type = "header",
            name = (L["CONFIG_LINE"] or "Line") .. " " .. i,
            order = baseOrder,
        }

        args[prefix .. i .. "Enabled"] = {
            type = "toggle",
            name = L["CONFIG_ENABLED"] or "Enabled",
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
            name = L["CONFIG_CHANNEL"] or "Channel",
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
            name = L["CONFIG_MESSAGE"] or "Message",
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

local function GetAnnouncementsOptions()
    return {
        type = "group",
        name = L["ANNOUNCEMENT_SETTINGS"],
        order = 3,
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
                        name = L["CONFIG_ANNOUNCE_CONSIDERATIONS"] or "Announce Considerations",
                        desc = L["CONFIG_ANNOUNCE_CONSIDERATIONS_DESC"] or "Announce when an item is being considered for distribution",
                        order = 4,
                        get = function() return Loothing.Settings:GetAnnounceConsiderations() end,
                        set = function(_, v) Loothing.Settings:SetAnnounceConsiderations(v) end,
                    },
                },
            },
            considerations = {
                type = "group",
                name = L["CONFIG_CONSIDERATIONS"] or "Considerations",
                order = 2,
                inline = false,
                args = {
                    considerationsChannel = {
                        type = "select",
                        name = L["CONFIG_CONSIDERATIONS_CHANNEL"] or "Channel",
                        desc = L["CONFIG_CONSIDERATIONS_CHANNEL_DESC"] or "Channel to announce considerations",
                        order = 1,
                        values = GetChannelValues(),
                        get = function() return Loothing.Settings:GetConsiderationsChannel() end,
                        set = function(_, v) Loothing.Settings:SetConsiderationsChannel(v) end,
                    },
                    considerationsText = {
                        type = "input",
                        name = L["CONFIG_CONSIDERATIONS_TEXT"] or "Message Template",
                        desc = L["CONFIG_CONSIDERATIONS_TEXT_DESC"] or "Template for consideration announcements. Tokens: {ml}, {item}, {ilvl}",
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
                name = L["CONFIG_ITEM_ANNOUNCEMENTS"] or "Item Announcements",
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
                name = L["CONFIG_SESSION_ANNOUNCEMENTS"] or "Session Announcements",
                order = 5,
                inline = false,
                args = {
                    sessionStartHeader = {
                        type = "header",
                        name = L["CONFIG_SESSION_START"] or "Session Start",
                        order = 1,
                    },
                    sessionStartChannel = {
                        type = "select",
                        name = L["CONFIG_CHANNEL"] or "Channel",
                        order = 2,
                        values = GetChannelValues(),
                        get = function() return Loothing.Settings:GetSessionStartChannel() end,
                        set = function(_, v) Loothing.Settings:SetSessionStartChannel(v) end,
                    },
                    sessionStartText = {
                        type = "input",
                        name = L["CONFIG_MESSAGE"] or "Message",
                        order = 3,
                        width = "full",
                        get = function() return Loothing.Settings:GetSessionStartText() end,
                        set = function(_, v) Loothing.Settings:SetSessionStartText(v) end,
                    },
                    sessionEndHeader = {
                        type = "header",
                        name = L["CONFIG_SESSION_END"] or "Session End",
                        order = 10,
                    },
                    sessionEndChannel = {
                        type = "select",
                        name = L["CONFIG_CHANNEL"] or "Channel",
                        order = 11,
                        values = GetChannelValues(),
                        get = function() return Loothing.Settings:GetSessionEndChannel() end,
                        set = function(_, v) Loothing.Settings:SetSessionEndChannel(v) end,
                    },
                    sessionEndText = {
                        type = "input",
                        name = L["CONFIG_MESSAGE"] or "Message",
                        order = 12,
                        width = "full",
                        get = function() return Loothing.Settings:GetSessionEndText() end,
                        set = function(_, v) Loothing.Settings:SetSessionEndText(v) end,
                    },
                },
            },
        },
    }
end

Loothing.Options = Loothing.Options or {}
Loothing.Options.GetAnnouncementsOptions = GetAnnouncementsOptions
