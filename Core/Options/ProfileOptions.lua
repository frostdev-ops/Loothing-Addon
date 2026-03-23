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
    if type(name) ~= "string" then return false, L["PROFILE_ERR_NOT_STRING"] end
    name = strtrim(name)
    if name == "" then return false, L["PROFILE_ERR_EMPTY"] end
    if #name > 48 then return false, L["PROFILE_ERR_TOO_LONG"] end
    if name:match('[<>:"/\\|?*]') then return false, L["PROFILE_ERR_INVALID_CHARS"] end
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

    local first = next(targets)
    if first then
        shareTarget = first
        return shareTarget
    end

    shareTarget = nil
    return nil
end

local function GetBroadcastShareDescription()
    local base = L["PROFILE_SHARE_BROADCAST_DESC"]
    if not Loothing.SettingsExport or not Loothing.SettingsExport.CanBroadcastSharedExport then
        return base
    end

    local allowed, reason = Loothing.SettingsExport:CanBroadcastSharedExport()
    if allowed or not reason or reason == "" then
        return base
    end

    return base .. "\n|cffffaa00" .. reason .. "|r"
end

function Options.GetProfileOptions()
    return {
        type = "group",
        name = L["PROFILES"],
        args = {
            -- Current profile display
            currentHeader = {
                type = "header",
                name = L["PROFILE_CURRENT"],
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
                name = L["PROFILE_SWITCH"],
                order = 10,
            },
            switchDesc = {
                type = "description",
                name = L["PROFILE_SWITCH_DESC"],
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
                name = L["PROFILE_NEW"],
                order = 20,
            },
            newDesc = {
                type = "description",
                name = L["PROFILE_NEW_DESC"],
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
                        L["PROFILE_CREATED"], value))
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
                name = L["PROFILE_COPY_FROM"],
                order = 30,
            },
            copyDesc = {
                type = "description",
                name = L["PROFILE_COPY_DESC"],
                order = 31,
            },
            copySelect = {
                type = "select",
                name = "",
                order = 32,
                width = "double",
                confirm = true,
                confirmText = L["PROFILE_COPY_CONFIRM"],
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
                name = L["PROFILE_DELETE"],
                order = 40,
                hidden = function() return not HasDeletableProfiles() end,
            },
            deleteSelect = {
                type = "select",
                name = "",
                order = 42,
                width = "double",
                confirm = true,
                confirmText = L["PROFILE_DELETE_CONFIRM"],
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
                name = L["PROFILE_RESET"],
                order = 50,
            },
            resetBtn = {
                type = "execute",
                name = L["PROFILE_RESET"],
                order = 52,
                confirm = true,
                confirmText = function()
                    local name = Loothing.Settings:GetCurrentProfile() or "Default"
                    return string.format(
                        L["PROFILE_RESET_CONFIRM"],
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
                name = L["EXPORT_SETTINGS"],
                order = 60,
            },
            exportDesc = {
                type = "description",
                name = L["PROFILE_EXPORT_INLINE_DESC"],
                order = 61,
            },
            exportBtn = {
                type = "execute",
                name = L["EXPORT"],
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
                                L["EXPORT_FAILED"], err or "unknown"))
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
                name = L["PROFILE_SHARE_TARGET"],
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
                name = L["PROFILE_SHARE_BUTTON"],
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
                            L["PROFILE_SHARE_FAILED_GENERIC"], err or "unknown"))
                    end
                end,
            },
            shareDesc = {
                type = "description",
                name = L["PROFILE_SHARE_DESC"],
                order = 67,
            },
            shareBroadcastBtn = {
                type = "execute",
                name = L["PROFILE_SHARE_BROADCAST_BUTTON"],
                order = 68,
                confirm = true,
                confirmText = L["PROFILE_SHARE_BROADCAST_CONFIRM"],
                disabled = function()
                    if not Loothing.SettingsExport or not Loothing.SettingsExport.CanBroadcastSharedExport then
                        return true
                    end
                    local allowed = Loothing.SettingsExport:CanBroadcastSharedExport()
                    return not allowed
                end,
                func = function()
                    if not Loothing.SettingsExport then
                        return
                    end

                    local success, err = Loothing.SettingsExport:BroadcastSharedExport()
                    if not success then
                        print("|cFF33FF99Loothing|r: " .. string.format(
                            L["PROFILE_SHARE_FAILED_GENERIC"], err or "unknown"))
                    end
                end,
            },
            shareBroadcastDesc = {
                type = "description",
                name = GetBroadcastShareDescription,
                order = 69,
            },
            shareSpacer = {
                type = "description",
                name = " ",
                order = 70,
            },

            -- Import (inline)
            importHeader = {
                type = "header",
                name = L["IMPORT_SETTINGS"],
                order = 80,
            },
            importDesc = {
                type = "description",
                name = L["PROFILE_IMPORT_INLINE_DESC"],
                order = 81,
            },
            importField = {
                type = "input",
                name = "",
                order = 82,
                multiline = 8,
                width = "full",
                get = function() return importBuffer end,
                set = function(_, value)
                    importBuffer = value or ""
                end,
            },
            importBtn = {
                type = "execute",
                name = L["IMPORT_BUTTON"],
                order = 84,
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
                order = 89,
            },

            -- All Profiles list
            listHeader = {
                type = "header",
                name = L["PROFILE_LIST"],
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
                                .. (name == "Default" and (" " .. (L["PROFILE_DEFAULT_SUFFIX"])) or "")
                        else
                            lines[#lines + 1] = name
                                .. (name == "Default" and (" " .. (L["PROFILE_DEFAULT_SUFFIX"])) or "")
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
