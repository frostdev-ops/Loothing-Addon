--[[--------------------------------------------------------------------
    Loothing - Options: Profile Management
    Full profile CRUD, inline export/import, embedded in AceConfig panel.
----------------------------------------------------------------------]]

local _, ns = ...
local Loothing = ns.Addon
local Options = ns.Options or {}
ns.Options = Options

local L = ns.Locale
local Loolib = LibStub("Loolib")

local cachedExportString = ""
local importBuffer = ""
local shareTarget = nil

local function RefreshSettingsDialog()
    cachedExportString = ""
    if Loolib.Config then Loolib.Config:NotifyChange("Loothing") end
end

local function ValidateProfileName(name)
    if type(name) ~= "string" then return false, "Name must be a string" end
    name = strtrim(name)
    if name == "" then return false, "Name cannot be empty" end
    if #name > 48 then return false, "Name must be 48 characters or fewer" end
    if name:match('[<>:"/\\|?*]') then return false, "Name contains invalid characters" end
    return true
end

local function GetProfileList()
    local profiles = Loothing.Settings:GetProfiles() or {}
    local list = {}
    for _, name in ipairs(profiles) do
        list[name] = name
    end
    return list
end

local function GetProfileListExcluding(...)
    local exclude = {}
    for i = 1, select("#", ...) do
        local v = select(i, ...)
        if v then exclude[v] = true end
    end
    local profiles = Loothing.Settings:GetProfiles() or {}
    local list = {}
    for _, name in ipairs(profiles) do
        if not exclude[name] then
            list[name] = name
        end
    end
    return list
end

local function HasDeletableProfiles()
    local current = Loothing.Settings:GetCurrentProfile()
    local list = GetProfileListExcluding(current, "Default")
    return next(list) ~= nil
end

local function GetShareTargetList()
    local list = {}
    local roster = ns.Utils and ns.Utils.GetRaidRoster and ns.Utils.GetRaidRoster() or {}
    local playerName = ns.Utils and ns.Utils.GetPlayerFullName and ns.Utils.GetPlayerFullName()

    for _, member in ipairs(roster) do
        if member.online and member.name and not ns.Utils.IsSamePlayer(member.name, playerName) then
            list[member.name] = member.name
        end
    end

    return list
end

local function GetResolvedShareTarget()
    local targets = GetShareTargetList()
    if shareTarget and targets[shareTarget] then
        return shareTarget
    end

    for name in pairs(targets) do
        shareTarget = name
        return shareTarget
    end

    shareTarget = nil
    return nil
end

function Options.GetProfileOptions()
    return {
        type = "group",
        name = L["PROFILES"] or "Profiles",
        args = {
            -- Current profile display
            currentHeader = {
                type = "header",
                name = L["PROFILE_CURRENT"] or "Current Profile",
                order = 1,
            },
            currentName = {
                type = "description",
                name = function()
                    local name = Loothing.Settings:GetCurrentProfile() or "Default"
                    return "|cFF33FF99" .. name .. "|r"
                end,
                fontSize = "large",
                order = 2,
            },
            currentSpacer = {
                type = "description",
                name = " ",
                order = 4,
            },

            -- Switch Profile
            switchHeader = {
                type = "header",
                name = L["PROFILE_SWITCH"] or "Switch Profile",
                order = 10,
            },
            switchDesc = {
                type = "description",
                name = L["PROFILE_SWITCH_DESC"] or "Select a profile to switch to.",
                order = 11,
            },
            switchSelect = {
                type = "select",
                name = "",
                order = 12,
                width = "double",
                values = function() return GetProfileList() end,
                get = function()
                    return Loothing.Settings:GetCurrentProfile() or "Default"
                end,
                set = function(_, value)
                    Loothing.Settings:SetProfile(value)
                    RefreshSettingsDialog()
                end,
            },
            switchSpacer = {
                type = "description",
                name = " ",
                order = 14,
            },

            -- Create New Profile
            newHeader = {
                type = "header",
                name = L["PROFILE_NEW"] or "Create New Profile",
                order = 20,
            },
            newDesc = {
                type = "description",
                name = L["PROFILE_NEW_DESC"] or "Enter a name for the new profile.",
                order = 21,
            },
            newInput = {
                type = "input",
                name = "",
                order = 22,
                width = "double",
                get = function() return "" end,
                set = function(_, value)
                    value = strtrim(value)
                    Loothing.Settings:SetProfile(value)
                    RefreshSettingsDialog()
                    print("|cFF33FF99Loothing|r: " .. string.format(
                        L["PROFILE_CREATED"] or "Created and switched to profile: %s", value))
                end,
                validate = function(_, value)
                    local valid, err = ValidateProfileName(value)
                    if not valid then return err end
                    return true
                end,
            },
            newSpacer = {
                type = "description",
                name = " ",
                order = 24,
            },

            -- Copy From
            copyHeader = {
                type = "header",
                name = L["PROFILE_COPY_FROM"] or "Copy From",
                order = 30,
            },
            copyDesc = {
                type = "description",
                name = L["PROFILE_COPY_DESC"] or "Copy settings from another profile into the current one.",
                order = 31,
            },
            copySelect = {
                type = "select",
                name = "",
                order = 32,
                width = "double",
                confirm = true,
                confirmText = L["PROFILE_COPY_CONFIRM"]
                    or "This will overwrite all settings in your current profile. Continue?",
                values = function()
                    local current = Loothing.Settings:GetCurrentProfile()
                    return GetProfileListExcluding(current)
                end,
                get = function() return nil end,
                set = function(_, value)
                    Loothing.Settings:CopyProfile(value)
                    RefreshSettingsDialog()
                end,
            },
            copySpacer = {
                type = "description",
                name = " ",
                order = 34,
            },

            -- Delete Profile
            deleteHeader = {
                type = "header",
                name = L["PROFILE_DELETE"] or "Delete Profile",
                order = 40,
                hidden = function() return not HasDeletableProfiles() end,
            },
            deleteSelect = {
                type = "select",
                name = "",
                order = 42,
                width = "double",
                confirm = true,
                confirmText = L["PROFILE_DELETE_CONFIRM"]
                    or "Are you sure you want to delete this profile? This cannot be undone.",
                values = function()
                    local current = Loothing.Settings:GetCurrentProfile()
                    return GetProfileListExcluding(current, "Default")
                end,
                get = function() return nil end,
                set = function(_, value)
                    Loothing.Settings:DeleteProfile(value)
                    RefreshSettingsDialog()
                end,
                hidden = function() return not HasDeletableProfiles() end,
            },
            deleteSpacer = {
                type = "description",
                name = " ",
                order = 44,
                hidden = function() return not HasDeletableProfiles() end,
            },

            -- Reset to Defaults
            resetHeader = {
                type = "header",
                name = L["PROFILE_RESET"] or "Reset to Defaults",
                order = 50,
            },
            resetBtn = {
                type = "execute",
                name = L["PROFILE_RESET"] or "Reset to Defaults",
                order = 52,
                confirm = true,
                confirmText = function()
                    local name = Loothing.Settings:GetCurrentProfile() or "Default"
                    return string.format(
                        L["PROFILE_RESET_CONFIRM"]
                            or "Reset profile '%s' to default settings? This cannot be undone.",
                        name)
                end,
                func = function()
                    Loothing.Settings:ResetProfile()
                    RefreshSettingsDialog()
                end,
            },
            resetSpacer = {
                type = "description",
                name = " ",
                order = 54,
            },

            -- Export (inline)
            exportHeader = {
                type = "header",
                name = L["EXPORT_SETTINGS"] or "Export Settings",
                order = 60,
            },
            exportDesc = {
                type = "description",
                name = L["PROFILE_EXPORT_INLINE_DESC"]
                    or "Generate an export string, then copy it to share your settings.",
                order = 61,
            },
            exportBtn = {
                type = "execute",
                name = L["EXPORT"] or "Export",
                order = 62,
                func = function()
                    if Loothing.SettingsExport then
                        local encoded, err = Loothing.SettingsExport:Export()
                        if encoded then
                            -- Insert newlines every 36 chars to fit within the AceConfig panel
                            cachedExportString = encoded:gsub("(" .. ("."):rep(36) .. ")", "%1\n")
                        else
                            cachedExportString = ""
                            print("|cFF33FF99Loothing|r: " .. string.format(
                                L["EXPORT_FAILED"] or "Export failed: %s", err or "unknown"))
                        end
                        if Loolib.Config then Loolib.Config:NotifyChange("Loothing") end
                    end
                end,
            },
            exportField = {
                type = "input",
                name = "",
                order = 63,
                multiline = 12,
                width = "full",
                get = function() return cachedExportString end,
                set = function() end, -- read-only
            },
            exportSpacer = {
                type = "description",
                name = " ",
                order = 64,
            },
            shareTarget = {
                type = "select",
                name = L["PROFILE_SHARE_TARGET"] or "Share To",
                order = 65,
                width = "double",
                values = function() return GetShareTargetList() end,
                get = function()
                    return GetResolvedShareTarget()
                end,
                set = function(_, value)
                    shareTarget = value
                end,
            },
            shareBtn = {
                type = "execute",
                name = L["PROFILE_SHARE_BUTTON"] or "Share",
                order = 66,
                disabled = function()
                    return GetResolvedShareTarget() == nil
                end,
                func = function()
                    local target = GetResolvedShareTarget()
                    if not target or not Loothing.SettingsExport then
                        return
                    end

                    local success, err = Loothing.SettingsExport:SendSharedExport(target)
                    if not success then
                        print("|cFF33FF99Loothing|r: " .. string.format(
                            L["PROFILE_SHARE_FAILED_GENERIC"] or "Share failed: %s", err or "unknown"))
                    end
                end,
            },
            shareDesc = {
                type = "description",
                name = L["PROFILE_SHARE_DESC"]
                    or "Send the current export string directly to one online group member.",
                order = 67,
            },
            shareSpacer = {
                type = "description",
                name = " ",
                order = 68,
            },

            -- Import (inline)
            importHeader = {
                type = "header",
                name = L["IMPORT_SETTINGS"] or "Import Settings",
                order = 70,
            },
            importDesc = {
                type = "description",
                name = L["PROFILE_IMPORT_INLINE_DESC"]
                    or "Paste an exported settings string below, then click Import.",
                order = 71,
            },
            importField = {
                type = "input",
                name = "",
                order = 72,
                multiline = 8,
                width = "full",
                get = function() return importBuffer end,
                set = function(_, value)
                    importBuffer = value or ""
                end,
            },
            importBtn = {
                type = "execute",
                name = L["IMPORT_BUTTON"] or "Import",
                order = 74,
                func = function()
                    if importBuffer == "" then return end
                    if Loothing.SettingsExport then
                        Loothing.SettingsExport:ProcessImportInline(importBuffer)
                        cachedExportString = ""
                    end
                end,
            },
            importSpacer = {
                type = "description",
                name = " ",
                order = 79,
            },

            -- All Profiles list
            listHeader = {
                type = "header",
                name = L["PROFILE_LIST"] or "All Profiles",
                order = 90,
            },
            listDesc = {
                type = "description",
                name = function()
                    local profiles = Loothing.Settings:GetProfiles() or {}
                    local current = Loothing.Settings:GetCurrentProfile() or "Default"
                    local lines = {}
                    for _, name in ipairs(profiles) do
                        if name == current then
                            lines[#lines + 1] = "|cFF33FF99" .. name .. "|r"
                                .. (name == "Default" and (" " .. (L["PROFILE_DEFAULT_SUFFIX"] or "(default)")) or "")
                        else
                            lines[#lines + 1] = name
                                .. (name == "Default" and (" " .. (L["PROFILE_DEFAULT_SUFFIX"] or "(default)")) or "")
                        end
                    end
                    return table.concat(lines, "\n")
                end,
                fontSize = "medium",
                order = 92,
            },
        },
    }
end
