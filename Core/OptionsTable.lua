--[[--------------------------------------------------------------------
    Loothing - Options Table
    Aggregates all option groups into the main config table
----------------------------------------------------------------------]]

-- Ensure namespace exists even before Core/Init loads
Loothing = Loothing or {}
Loothing.Options = Loothing.Options or {}

local L = Loothing.Locale

-- Resolve an options getter by name, returning the group table or nil
local function resolveOptions(name)
    local getter = Loothing.Options and Loothing.Options[name]
    if getter then
        return getter()
    end
    return nil
end

-- Shallow-copy a group table and force inline = true so it renders in the tab page
local function inlineGroup(group)
    if not group then return nil end
    local g = {}
    for k, v in pairs(group) do g[k] = v end
    g.inline = true
    return g
end

-- Build the args table on demand so Options/*.lua files are loaded first
local function BuildArgs()
    local localPrefs = resolveOptions("GetLocalPreferencesOptions")
    local sessionSettings = resolveOptions("GetSessionSettingsOptions")

    -- ----------------------------------------------------------------
    -- General tab: frame behavior, loot response, autopass, auto-award,
    --              ignore list, history, ML settings
    -- ----------------------------------------------------------------
    local generalArgs = {}
    if localPrefs and localPrefs.args then
        local order = 1
        for destKey, srcKey in pairs({
            frameBehavior = "frame",
            lootResponse  = "lootResponse",
            autopass      = "autopass",
            autoaward     = "autoaward",
            ignore        = "ignore",
            history       = "history",
            ml            = "ml",
        }) do
            local group = inlineGroup(localPrefs.args[srcKey])
            if group then
                group.order = order
                order = order + 1
                generalArgs[destKey] = group
            end
        end
    end

    -- ----------------------------------------------------------------
    -- Session tab: voting + session trigger (inline), then button sets
    --              and type code assignment (also inline, scrollable)
    -- ----------------------------------------------------------------
    local sessionArgs = {}
    if sessionSettings and sessionSettings.args then
        local srcArgs = sessionSettings.args
        local order = 1
        for _, key in ipairs({ "voting", "responseButtons" }) do
            local group = inlineGroup(srcArgs[key])
            if group then
                group.order = order
                order = order + 1
                sessionArgs[key] = group
            end
        end
    end

    -- ----------------------------------------------------------------
    -- Council & Awards tab: council roster + award reasons (both inline)
    -- ----------------------------------------------------------------
    local councilArgs = {}
    if sessionSettings and sessionSettings.args then
        local srcArgs = sessionSettings.args
        local order = 1
        for _, key in ipairs({ "council", "awardReasons" }) do
            local group = inlineGroup(srcArgs[key])
            if group then
                group.order = order
                order = order + 1
                councilArgs[key] = group
            end
        end
    end

    -- ----------------------------------------------------------------
    -- Announcements tab: all announcement sub-groups (inlined)
    -- ----------------------------------------------------------------
    local announcementsArgs = {}
    if localPrefs and localPrefs.args and localPrefs.args.announcements then
        local ann = localPrefs.args.announcements
        for k, v in pairs(ann.args or {}) do
            if type(v) == "table" and v.type == "group" then
                announcementsArgs[k] = inlineGroup(v)
            else
                announcementsArgs[k] = v
            end
        end
    end

    return {
        general = {
            type = "group",
            name = L["GENERAL"] or "General",
            order = 1,
            args = generalArgs,
        },
        session = {
            type = "group",
            name = L["SESSION_SETTINGS_ML"] or "Session",
            order = 2,
            args = sessionArgs,
        },
        councilAwards = {
            type = "group",
            name = L["COUNCIL"] or "Council & Awards",
            order = 3,
            args = councilArgs,
        },
        announcements = {
            type = "group",
            name = L["ANNOUNCEMENT_SETTINGS"] or "Announcements",
            order = 4,
            args = announcementsArgs,
        },
    }
end

LoothingOptionsTable = {
    type = "group",
    name = L["ADDON_NAME"],
    childGroups = "tab",
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

-- Populate args after all Options files have loaded.
-- Called from Init.lua during initialization, or on first dialog open.
function Loothing.Options.BuildOptionsTable()
    LoothingOptionsTable.args = BuildArgs()
end
