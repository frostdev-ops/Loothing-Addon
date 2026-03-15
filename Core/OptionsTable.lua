--[[--------------------------------------------------------------------
    Loothing - Options Table
    Aggregates all option groups into the main config table
----------------------------------------------------------------------]]

local ADDON_NAME, ns = ...
local Loothing = ns.Addon
local Options = ns.Options or {}
ns.Options = Options

local L = ns.Locale

-- Resolve an options getter by name, returning the group table or nil
local function resolveOptions(name)
    local getter = Options[name]
    if getter then
        return getter()
    end
    return nil
end

local function copyTableShallow(tbl)
    if not tbl then return nil end
    local copy = {}
    for k, v in pairs(tbl) do
        copy[k] = v
    end
    return copy
end

local function cloneGroup(group, overrides)
    if not group then return nil end
    local g = copyTableShallow(group)
    if overrides then
        for k, v in pairs(overrides) do
            g[k] = v
        end
    end
    return g
end

local function addClonedGroup(targetArgs, key, sourceGroup, order, overrides)
    local group = cloneGroup(sourceGroup, overrides)
    if not group then
        return
    end

    group.order = order
    targetArgs[key] = group
end

-- Build the args table on demand so Options/*.lua files are loaded first
local function BuildArgs()
    local localPrefs = resolveOptions("GetLocalPreferencesOptions")
    local sessionSettings = resolveOptions("GetSessionSettingsOptions")
    local localArgs = localPrefs and localPrefs.args or nil
    local sessionArgs = sessionSettings and sessionSettings.args or nil

    local rootArgs = {}

    addClonedGroup(rootArgs, "lootResponse", localArgs and localArgs.lootResponse, 10)
    addClonedGroup(rootArgs, "frame", localArgs and localArgs.frame, 20)
    addClonedGroup(rootArgs, "autopass", localArgs and localArgs.autopass, 30)
    addClonedGroup(rootArgs, "autoaward", localArgs and localArgs.autoaward, 40)
    addClonedGroup(rootArgs, "ignore", localArgs and localArgs.ignore, 50)
    addClonedGroup(rootArgs, "ml", localArgs and localArgs.ml, 60)
    addClonedGroup(rootArgs, "history", localArgs and localArgs.history, 70)
    addClonedGroup(rootArgs, "voting", sessionArgs and sessionArgs.voting, 80)
    addClonedGroup(rootArgs, "winnerDetermination", sessionArgs and sessionArgs.winnerDetermination, 90)
    addClonedGroup(rootArgs, "responseButtons", sessionArgs and sessionArgs.responseButtons, 100)
    addClonedGroup(rootArgs, "observerPermissions", sessionArgs and sessionArgs.observerPermissions, 110)
    addClonedGroup(rootArgs, "council", sessionArgs and sessionArgs.council, 120)
    addClonedGroup(rootArgs, "awardReasons", sessionArgs and sessionArgs.awardReasons, 130)
    addClonedGroup(rootArgs, "announcements", localArgs and localArgs.announcements, 140, {
        childGroups = "tree",
    })
    addClonedGroup(rootArgs, "profiles", resolveOptions("GetProfileOptions"), 150)

    return rootArgs
end

ns.OptionsTable = ns.OptionsTable or {
    type = "group",
    name = L["ADDON_NAME"],
    childGroups = "tree",
    get = function(info)
        local key = table.concat(info, ".")
        return Loothing.Settings:Get(key)
    end,
    set = function(info, value)
        local key = table.concat(info, ".")
        Loothing.Settings:Set(key, value)
    end,
    args = {},
}
local OptionsTable = ns.OptionsTable

-- Populate args after all Options files have loaded.
-- Called from Init.lua during initialization, or on first dialog open.
function Options.BuildOptionsTable()
    OptionsTable.args = BuildArgs()
end

local PATH_ALIASES = {
    general = { "lootResponse" },
    personal = { "lootResponse" },
    session = { "voting" },
    raidSession = { "voting" },
    councilAwards = { "council" },
    councilManagement = { "council" },
    council = { "council" },
    announcements = { "announcements" },
    history = { "history" },
    ml = { "ml" },
    responseButtons = { "responseButtons" },
    profiles = { "profiles" },
}

function Options.ResolveOptionsPath(section)
    if not section or section == "" then
        return nil
    end

    if (not OptionsTable.args or not next(OptionsTable.args)) and Options.BuildOptionsTable then
        Options.BuildOptionsTable()
    end

    if type(section) == "table" then
        return section
    end

    local normalized = tostring(section):gsub("^%s+", ""):gsub("%s+$", "")
    if normalized == "" then
        return nil
    end

    local explicit = OptionsTable.args and OptionsTable.args[normalized]
    if explicit then
        return { normalized }
    end

    local alias = PATH_ALIASES[normalized] or PATH_ALIASES[normalized:lower()]
    if alias then
        return alias
    end

    local dotted = {}
    for part in normalized:gmatch("[^%.%s/]+") do
        dotted[#dotted + 1] = part
    end
    if #dotted > 0 then
        return dotted
    end

    return nil
end
