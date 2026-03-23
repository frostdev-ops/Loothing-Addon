--[[--------------------------------------------------------------------
    Loothing - Options Table
    Aggregates all option groups into the main config table
----------------------------------------------------------------------]]

local _, ns = ...
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

    -- Tab 1: General (lootResponse + frame + autopass)
    local generalArgs = {}
    addClonedGroup(generalArgs, "lootResponse", localArgs and localArgs.lootResponse, 1)
    addClonedGroup(generalArgs, "frame", localArgs and localArgs.frame, 2)
    addClonedGroup(generalArgs, "autopass", localArgs and localArgs.autopass, 3)
    rootArgs.general = {
        type = "group",
        name = L["CONFIG_TAB_GENERAL"],
        desc = L["CONFIG_TAB_GENERAL_DESC"],
        order = 10,
        childGroups = "tree",
        args = generalArgs,
    }

    -- Tab 2: Master Looter (ml + autoaward + ignore + history)
    local mlArgs = {}
    addClonedGroup(mlArgs, "ml", localArgs and localArgs.ml, 1)
    addClonedGroup(mlArgs, "autoaward", localArgs and localArgs.autoaward, 2)
    addClonedGroup(mlArgs, "ignore", localArgs and localArgs.ignore, 3)
    addClonedGroup(mlArgs, "history", localArgs and localArgs.history, 4)
    rootArgs.masterLooter = {
        type = "group",
        name = L["CONFIG_TAB_MASTER_LOOTER"],
        desc = L["CONFIG_TAB_MASTER_LOOTER_DESC"],
        order = 20,
        childGroups = "tree",
        args = mlArgs,
    }

    -- Tab 3: Session & Voting (voting + winnerDetermination + awardReasons + responseButtons)
    -- All sub-groups are tree nodes (voting has 20+ settings, awardReasons has its own sub-tree)
    local sessionVotingArgs = {}
    addClonedGroup(sessionVotingArgs, "voting", sessionArgs and sessionArgs.voting, 1)
    addClonedGroup(sessionVotingArgs, "winnerDetermination", sessionArgs and sessionArgs.winnerDetermination, 2)
    addClonedGroup(sessionVotingArgs, "awardReasons", sessionArgs and sessionArgs.awardReasons, 3)
    addClonedGroup(sessionVotingArgs, "responseButtons", sessionArgs and sessionArgs.responseButtons, 4)
    rootArgs.sessionVoting = {
        type = "group",
        name = L["CONFIG_TAB_SESSION"],
        desc = L["CONFIG_TAB_SESSION_DESC"],
        order = 30,
        childGroups = "tree",
        args = sessionVotingArgs,
    }

    -- Tab 4: Council (council + observerPermissions)
    local councilArgs = {}
    addClonedGroup(councilArgs, "council", sessionArgs and sessionArgs.council, 1)
    addClonedGroup(councilArgs, "observerPermissions", sessionArgs and sessionArgs.observerPermissions, 2)
    rootArgs.councilTab = {
        type = "group",
        name = L["CONFIG_TAB_COUNCIL"],
        desc = L["CONFIG_TAB_COUNCIL_DESC"],
        order = 40,
        childGroups = "tree",
        args = councilArgs,
    }

    -- Tab 5: Announcements (keeps existing sub-tree structure)
    addClonedGroup(rootArgs, "announcements", localArgs and localArgs.announcements, 50, {
        childGroups = "tree",
    })

    -- Tab 6: Profiles
    addClonedGroup(rootArgs, "profiles", resolveOptions("GetProfileOptions"), 60)

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
    -- General tab children
    general        = { "general" },
    personal       = { "general" },
    lootResponse   = { "general", "lootResponse" },
    frame          = { "general", "frame" },
    autopass       = { "general", "autopass" },
    -- ML tab children
    ml             = { "masterLooter", "ml" },
    autoaward      = { "masterLooter", "autoaward" },
    ignore         = { "masterLooter", "ignore" },
    history        = { "masterLooter", "history" },
    -- Session & Voting (unchanged)
    session        = { "sessionVoting" },
    raidSession    = { "sessionVoting" },
    voting         = { "sessionVoting", "voting" },
    winnerDetermination = { "sessionVoting", "winnerDetermination" },
    responseButtons = { "sessionVoting", "responseButtons" },
    awardReasons   = { "sessionVoting", "awardReasons" },
    -- Council tab children
    council        = { "councilTab", "council" },
    councilAwards  = { "councilTab" },
    councilManagement = { "councilTab" },
    observerPermissions = { "councilTab", "observerPermissions" },
    -- Others (unchanged)
    announcements  = { "announcements" },
    profiles       = { "profiles" },
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
