--[[--------------------------------------------------------------------
    Loothing - Loot Council Addon for WoW 12.0+
    Settings - SavedVariables wrapper and settings management

    Uses Loolib's SavedVariables system for multi-profile support.
    Data is split into two scopes:
      - profile: User preferences (switches per character/profile)
      - global: Shared data (history, trade queue, item storage, migrations, player cache)

    All existing getter/setter methods remain unchanged. Callers do not
    need to know about profiles - self.db routes to the active profile.

    Table of Contents:
      Default Values ............... ~21
      SettingsMixin ................ ~80
      Profile Management ........... ~149
      General Settings ............. ~201
      UI Settings .................. ~349
      Council Settings ............. ~392
      Announcement Settings ........ ~455
      Multi-Line Announcements ..... ~579
      History Access ............... ~726
      Auto-Pass Settings ........... ~840
      Auto-Trade Settings .......... ~892
      Group Loot Settings .......... ~908
      Auto-Award Settings .......... ~949
      Ignore Items Settings ........ ~1017
      Voting Options Settings ...... ~1125
      Award Reasons Settings ....... ~1265
      Button Sets Settings ......... ~1585
      Response Sets Settings ....... ~1815
      Filter Settings .............. ~2225
      Council Table Settings ....... ~2372
      Roll Frame Settings .......... ~2455
      Winner Determination ......... ~2572
----------------------------------------------------------------------]]

local _, ns = ...
local Loolib = LibStub("Loolib")
local SavedVariables = Loolib.Data.SavedVariables
local Loothing = ns.Addon
local Utils = ns.Utils
local ipairs, pairs, tonumber = ipairs, pairs, tonumber

--[[--------------------------------------------------------------------
    Default Values (split by scope for Loolib SavedVariables)

    Profile scope: All user preferences from Loothing.DefaultSettings
    Global scope: Shared data that persists across profiles
----------------------------------------------------------------------]]

-- Deep copy defaults to prevent mutations from corrupting the source tables
local function CopyDefaults(src)
    if type(src) ~= "table" then return src end
    local copy = {}
    for k, v in pairs(src) do
        copy[k] = type(v) == "table" and CopyDefaults(v) or v
    end
    return copy
end

local PROFILE_DEFAULTS = {
    -- schemaVersion is mirrored from DefaultSettings so the
    -- SchemaMigration system can detect fresh installs (which are
    -- already at the current version) vs. legacy profiles.
    schemaVersion = Loothing.DefaultSettings.schemaVersion,
    version = 1,  -- legacy version field (used by Migration.lua, not SchemaMigration)

    council             = CopyDefaults(Loothing.DefaultSettings.council),
    observers           = CopyDefaults(Loothing.DefaultSettings.observers),
    -- v2.0.7: `settings.*`, `historySettings.*`, and `buttonSets.*`
    -- namespaces removed. Their contents now live under category
    -- namespaces (frame.*, voting.*, session.*, ml.*, history.*).
    session             = CopyDefaults(Loothing.DefaultSettings.session),
    announcements       = CopyDefaults(Loothing.DefaultSettings.announcements),
    autoPass            = CopyDefaults(Loothing.DefaultSettings.autoPass),
    autoAward           = CopyDefaults(Loothing.DefaultSettings.autoAward),
    ignoreItems         = CopyDefaults(Loothing.DefaultSettings.ignoreItems),
    voting              = CopyDefaults(Loothing.DefaultSettings.voting),
    -- v2.0.8: legacy `responses` definitions table removed (was
    -- superseded by `responseSets` in earlier versions; no consumers).
    awardReasons        = CopyDefaults(Loothing.DefaultSettings.awardReasons),
    frame               = CopyDefaults(Loothing.DefaultSettings.frame),
    ml                  = CopyDefaults(Loothing.DefaultSettings.ml),
    history             = CopyDefaults(Loothing.DefaultSettings.history),
    responseSets        = CopyDefaults(Loothing.DefaultSettings.responseSets),
    filters             = CopyDefaults(Loothing.DefaultSettings.filters),
    groupLoot           = CopyDefaults(Loothing.DefaultSettings.groupLoot),
    rollFrame           = CopyDefaults(Loothing.DefaultSettings.rollFrame),
    councilTable        = CopyDefaults(Loothing.DefaultSettings.councilTable),
    winnerDetermination = CopyDefaults(Loothing.DefaultSettings.winnerDetermination),
}

local GLOBAL_DEFAULTS = {
    history = {},           -- Loot history entries (persist across profiles)
    tradeQueue = {},        -- Trade queue data
    itemStorage = {},       -- Item storage data
    playerCache = {},       -- GUID-based player cache
    migrations = {          -- Migration tracking
        version = "0.0.0",
        history = {},
        lastRun = nil,
    },
}

local SV_DEFAULTS = {
    profile = PROFILE_DEFAULTS,
    global = GLOBAL_DEFAULTS,
}

--[[--------------------------------------------------------------------
    SettingsMixin
----------------------------------------------------------------------]]

local SettingsMixin = ns.SettingsMixin or {}
ns.SettingsMixin = SettingsMixin

local function allowTestPersistence(context)
    local TestMode = ns.TestModeState
    if TestMode and TestMode.GuardPersistence then
        return TestMode:GuardPersistence(context)
    end
    return true
end

--- Initialize settings with Loolib SavedVariables multi-profile support
function SettingsMixin:Init()
    -- Create Loolib SavedVariables database with profile + global scopes
    self.sv = SavedVariables.CreateAddonStore("Loothing", SV_DEFAULTS, "Default")

    -- Run forward-only schema migrations BEFORE any code reads from
    -- self.sv.profile. Each migration is keyed by the schemaVersion it
    -- produces; see Loothing/Core/SchemaMigration.lua for the full chain.
    -- Distinct from Core/Migration.lua, which runs AFTER Settings init
    -- for version-string-keyed data fixups.
    if ns.SchemaMigration and ns.SchemaMigration.Run then
        ns.SchemaMigration:Run(self.sv)
    end

    -- self.db is a metatable proxy that always reads from self.sv.profile.
    -- This prevents stale references: even if other code captures self.db,
    -- all reads/writes go through to the current active profile table.
    local settingsRef = self
    self.db = setmetatable({}, {
        __index = function(_, key)
            return settingsRef.sv.profile[key]
        end,
        __newindex = function(_, key, value)
            settingsRef.sv.profile[key] = value
        end,
        __pairs = function(_)
            return pairs(settingsRef.sv.profile)
        end,
        __len = function(_)
            return #settingsRef.sv.profile
        end,
    })

    -- Global data accessor (history, trade queue, etc.)
    self.global = self.sv.global

    -- Listen for profile changes (for debug logging and any additional side effects)
    self.sv:RegisterCallback("OnProfileChanged", function(_, newProfile, oldProfile)
        -- self.db proxy auto-routes to sv.profile, no reference update needed
        if Loothing and Loothing.Debug then
            Loothing:Debug("Profile changed from", oldProfile, "to", newProfile)
        end
    end, self)

    self.sv:RegisterCallback("OnProfileReset", function()
        if Loothing and Loothing.Debug then
            Loothing:Debug("Profile reset to defaults")
        end
    end, self)

    self.sv:RegisterCallback("OnProfileCopied", function(_, sourceName)
        if Loothing and Loothing.Debug then
            Loothing:Debug("Profile copied from", sourceName)
        end
    end, self)
end

--- Save settings (called on logout)
-- Loolib SavedVariables handles PLAYER_LOGOUT automatically (strips defaults)
function SettingsMixin:Save()
    -- No-op: Loolib SavedVariables handles persistence on PLAYER_LOGOUT
end

--[[--------------------------------------------------------------------
    Profile Management
----------------------------------------------------------------------]]

--- Get the Loolib SavedVariables database object
-- @return table - The saved variables instance
function SettingsMixin:GetDB()
    return self.sv
end

--- Get the global data table (history, trade queue, etc.)
-- @return table
function SettingsMixin:GetGlobal()
    return self.global
end

--- Get the current profile name
-- @return string
function SettingsMixin:GetCurrentProfile()
    return self.sv:GetCurrentProfile()
end

--- Get all available profile names
-- @return table - Array of profile name strings
function SettingsMixin:GetProfiles()
    return self.sv:GetProfiles()
end

--- Switch to a different profile
-- @param name string - Profile name (creates if doesn't exist)
function SettingsMixin:SetProfile(name)
    self.sv:SetProfile(name)
end

--- Copy data from another profile to the current profile
-- @param sourceName string - Source profile name
function SettingsMixin:CopyProfile(sourceName)
    self.sv:CopyProfile(sourceName)
end

--- Delete a profile
-- @param name string - Profile name to delete
-- @return boolean - Success
function SettingsMixin:DeleteProfile(name)
    return self.sv:DeleteProfile(name, true)
end

--- Reset current profile to defaults
function SettingsMixin:ResetProfile()
    self.sv:ResetProfile()
end

--[[--------------------------------------------------------------------
    General Settings Accessors
----------------------------------------------------------------------]]

--- Get a setting value from the active profile
-- @param key string - Setting key (supports dot notation: "settings.votingMode")
-- @param default any - Default value if not found
-- @return any
function SettingsMixin:Get(key, default)
    local parts = Utils.Split(key, ".")
    local value = self.db

    for _, part in ipairs(parts) do
        if type(value) ~= "table" then
            return default
        end
        value = value[part]
    end

    if value == nil then
        return default
    end

    return value
end

--- Set a setting value in the active profile
-- @param key string - Setting key (supports dot notation)
-- @param value any - Value to set
function SettingsMixin:Set(key, value)
    if not allowTestPersistence(key) then
        return
    end

    local parts = Utils.Split(key, ".")
    local target = self.db

    -- Navigate to parent
    for i = 1, #parts - 1 do
        local part = parts[i]
        if type(target[part]) ~= "table" then
            target[part] = {}
        end
        target = target[part]
    end

    -- Set value
    target[parts[#parts]] = value
end

--- Get a value from the global scope
-- @param key string - Setting key (supports dot notation)
-- @param default any - Default value if not found
-- @return any
function SettingsMixin:GetGlobalValue(key, default)
    local parts = Utils.Split(key, ".")
    local value = self.global

    for _, part in ipairs(parts) do
        if type(value) ~= "table" then
            return default
        end
        value = value[part]
    end

    if value == nil then
        return default
    end

    return value
end

--- Set a value in the global scope
-- @param key string - Setting key (supports dot notation)
-- @param value any - Value to set
function SettingsMixin:SetGlobalValue(key, value)
    if not allowTestPersistence("global." .. key) then
        return
    end

    local parts = Utils.Split(key, ".")
    local target = self.global

    -- Navigate to parent
    for i = 1, #parts - 1 do
        local part = parts[i]
        if type(target[part]) ~= "table" then
            target[part] = {}
        end
        target = target[part]
    end

    -- Set value
    target[parts[#parts]] = value
end

--- Reset a setting to default
-- @param key string - Setting key
function SettingsMixin:Reset(key)
    local default = self:GetDefault(key)
    self:Set(key, Utils.DeepCopy(default))
end

--- Get default value for a setting
-- @param key string - Setting key
-- @return any
function SettingsMixin:GetDefault(key)
    local parts = Utils.Split(key, ".")
    local value = PROFILE_DEFAULTS

    for _, part in ipairs(parts) do
        if type(value) ~= "table" then
            return nil
        end
        value = value[part]
    end

    return value
end

--- Reset all settings to defaults (resets current profile)
-- The proxy self.db already follows self.sv.profile via its metatable,
-- so we must NOT replace it with a direct table reference.
function SettingsMixin:ResetAll()
    self.sv:ResetProfile()
end

--- Get a deep copy of the current profile data (for export)
-- @return table
function SettingsMixin:GetProfileData()
    return Utils.DeepCopy(self.sv.profile)
end

--- Write key-value pairs into the current profile (for import)
-- @param data table - Key-value pairs to apply
function SettingsMixin:SetProfileData(data)
    if type(data) ~= "table" then return end
    for k, v in pairs(data) do
        self.sv.profile[k] = v
    end
end

--- Get the profile defaults table
-- @return table
function SettingsMixin:GetProfileDefaults()
    return PROFILE_DEFAULTS
end

--[[--------------------------------------------------------------------
    UI Settings
----------------------------------------------------------------------]]

--- Get UI scale
-- @return number
function SettingsMixin:GetUIScale()
    return self:Get("frame.uiScale", 1.0)
end

--- Set UI scale
-- @param scale number
function SettingsMixin:SetUIScale(scale)
    scale = math.max(0.5, math.min(2.0, scale))
    self:Set("frame.uiScale", scale)
end

--- Get main frame position
-- @return table|nil - { point, x, y }
function SettingsMixin:GetMainFramePosition()
    return self:Get("frame.position", nil)
end

--- Save main frame position
-- @param point string - Anchor point
-- @param x number - X offset
-- @param y number - Y offset
function SettingsMixin:SetMainFramePosition(point, x, y)
    self:Set("frame.position", { point = point, x = x, y = y })
end

--- Get minimap button visibility
-- @return boolean
function SettingsMixin:GetShowMinimapButton()
    return self:Get("frame.showMinimapButton", true)
end

--- Set minimap button visibility
-- @param show boolean
function SettingsMixin:SetShowMinimapButton(show)
    self:Set("frame.showMinimapButton", show)
end

--[[--------------------------------------------------------------------
    Council Settings
----------------------------------------------------------------------]]

--- Get council members
-- @return table - Array of member names (copy)
function SettingsMixin:GetCouncilMembers()
    local members = self:Get("council.members", {})
    return Utils.DeepCopy(members)
end

--- Set council members
-- @param members table - Array of member names
function SettingsMixin:SetCouncilMembers(members)
    self:Set("council.members", members)
end

--- Add council member
-- @param name string - Member name
function SettingsMixin:AddCouncilMember(name)
    local members = self:GetCouncilMembers()
    local normalized = Utils.NormalizeName(name)

    if not Utils.Contains(members, normalized) then
        members[#members + 1] = normalized
        self:SetCouncilMembers(members)
    end
end

--- Remove council member
-- @param name string - Member name
function SettingsMixin:RemoveCouncilMember(name)
    local members = self:GetCouncilMembers()
    local normalized = Utils.NormalizeName(name)

    Utils.RemoveValue(members, normalized)
    self:SetCouncilMembers(members)
end

--- Get auto-include officers setting
-- @return boolean
function SettingsMixin:GetAutoIncludeOfficers()
    return self:Get("council.autoIncludeOfficers", true)
end

--- Set auto-include officers
-- @param include boolean
function SettingsMixin:SetAutoIncludeOfficers(include)
    self:Set("council.autoIncludeOfficers", include)
end

--- Get auto-include raid leader setting
-- @return boolean
function SettingsMixin:GetAutoIncludeRaidLeader()
    return self:Get("council.autoIncludeRaidLeader", true)
end

--- Set auto-include raid leader
-- @param include boolean
function SettingsMixin:SetAutoIncludeRaidLeader(include)
    self:Set("council.autoIncludeRaidLeader", include)
end

--[[--------------------------------------------------------------------
    Announcement Settings
----------------------------------------------------------------------]]

--- Get announce awards setting
-- @return boolean
function SettingsMixin:GetAnnounceAwards()
    return self:Get("announcements.announceAwards", true)
end

--- Set announce awards
-- @param announce boolean
function SettingsMixin:SetAnnounceAwards(announce)
    self:Set("announcements.announceAwards", announce)
end

--- Get announce items setting
-- @return boolean
function SettingsMixin:GetAnnounceItems()
    return self:Get("announcements.announceItems", true)
end

--- Set announce items
-- @param announce boolean
function SettingsMixin:SetAnnounceItems(announce)
    self:Set("announcements.announceItems", announce)
end

--- Get announce boss kill setting
-- @return boolean
function SettingsMixin:GetAnnounceBossKill()
    return self:Get("announcements.announceBossKill", false)
end

--- Set announce boss kill
-- @param announce boolean
function SettingsMixin:SetAnnounceBossKill(announce)
    self:Set("announcements.announceBossKill", announce)
end

-- Single-line legacy fields removed in v2.0.7:
--   GetAwardChannel / SetAwardChannel
--   GetAwardChannelSecondary / SetAwardChannelSecondary
--   GetAwardText / SetAwardText
--   GetItemChannel / SetItemChannel
--   GetItemText / SetItemText
-- All superseded by the awardLines / itemLines arrays accessed via
-- GetAwardLine / GetItemLine.

--- Get session start text
-- @return string
function SettingsMixin:GetSessionStartText()
    return self:Get("announcements.sessionStartText", "Loot council session started")
end

--- Set session start text
-- @param text string
function SettingsMixin:SetSessionStartText(text)
    self:Set("announcements.sessionStartText", text)
end

--- Get session end text
-- @return string
function SettingsMixin:GetSessionEndText()
    return self:Get("announcements.sessionEndText", "Loot council session ended")
end

--- Set session end text
-- @param text string
function SettingsMixin:SetSessionEndText(text)
    self:Set("announcements.sessionEndText", text)
end

--[[--------------------------------------------------------------------
    Multi-Line Announcements
----------------------------------------------------------------------]]

--- Get all award announcement lines
-- @return table - Array of { enabled, channel, text } (copy)
function SettingsMixin:GetAwardLines()
    local defaults = Loothing.DefaultSettings.announcements.awardLines
    local lines = self:Get("announcements.awardLines", defaults)
    return Utils.DeepCopy(lines)
end

--- Set award announcement lines
-- @param lines table - Array of { enabled, channel, text }
function SettingsMixin:SetAwardLines(lines)
    self:Set("announcements.awardLines", lines)
end

--- Get a specific award announcement line
-- @param index number - Line index (1-5)
-- @return table|nil - { enabled, channel, text }
function SettingsMixin:GetAwardLine(index)
    local lines = self:GetAwardLines()
    return lines and lines[index]
end

--- Set a specific award announcement line
-- @param index number - Line index (1-5)
-- @param enabled boolean
-- @param channel string
-- @param text string
function SettingsMixin:SetAwardLine(index, enabled, channel, text)
    local lines = self:GetAwardLines()
    if lines and index >= 1 and index <= 5 then
        lines[index] = { enabled = enabled, channel = channel, text = text }
        self:Set("announcements.awardLines", lines)
    end
end

--- Get all item announcement lines
-- @return table - Array of { enabled, channel, text } (copy)
function SettingsMixin:GetItemLines()
    local defaults = Loothing.DefaultSettings.announcements.itemLines
    local lines = self:Get("announcements.itemLines", defaults)
    return Utils.DeepCopy(lines)
end

--- Set item announcement lines
-- @param lines table - Array of { enabled, channel, text }
function SettingsMixin:SetItemLines(lines)
    self:Set("announcements.itemLines", lines)
end

--- Get a specific item announcement line
-- @param index number - Line index (1-5)
-- @return table|nil - { enabled, channel, text }
function SettingsMixin:GetItemLine(index)
    local lines = self:GetItemLines()
    return lines and lines[index]
end

--- Set a specific item announcement line
-- @param index number - Line index (1-5)
-- @param enabled boolean
-- @param channel string
-- @param text string
function SettingsMixin:SetItemLine(index, enabled, channel, text)
    local lines = self:GetItemLines()
    if lines and index >= 1 and index <= 5 then
        lines[index] = { enabled = enabled, channel = channel, text = text }
        self:Set("announcements.itemLines", lines)
    end
end

--- Get announce considerations setting
-- @return boolean
function SettingsMixin:GetAnnounceConsiderations()
    return self:Get("announcements.announceConsiderations") == true
end

--- Set announce considerations setting
-- @param enabled boolean
function SettingsMixin:SetAnnounceConsiderations(enabled)
    self:Set("announcements.announceConsiderations", enabled)
end

--- Get considerations channel
-- @return string
function SettingsMixin:GetConsiderationsChannel()
    return self:Get("announcements.considerationsChannel", "RAID")
end

--- Set considerations channel
-- @param channel string
function SettingsMixin:SetConsiderationsChannel(channel)
    self:Set("announcements.considerationsChannel", channel)
end

--- Get considerations text
-- @return string
function SettingsMixin:GetConsiderationsText()
    return self:Get("announcements.considerationsText", "{ml} is considering {item} for distribution")
end

--- Set considerations text
-- @param text string
function SettingsMixin:SetConsiderationsText(text)
    self:Set("announcements.considerationsText", text)
end

--- Get session start channel
-- @return string
function SettingsMixin:GetSessionStartChannel()
    return self:Get("announcements.sessionStartChannel", "RAID")
end

--- Set session start channel
-- @param channel string
function SettingsMixin:SetSessionStartChannel(channel)
    self:Set("announcements.sessionStartChannel", channel)
end

--- Get session end channel
-- @return string
function SettingsMixin:GetSessionEndChannel()
    return self:Get("announcements.sessionEndChannel", "RAID")
end

--- Set session end channel
-- @param channel string
function SettingsMixin:SetSessionEndChannel(channel)
    self:Set("announcements.sessionEndChannel", channel)
end

-- GetAnnounceChannel / SetAnnounceChannel removed in v2.0.7. They were
-- already deprecated wrappers around GetAwardChannel/SetAwardChannel,
-- which were themselves removed in favor of the awardLines array model.

--[[--------------------------------------------------------------------
    History Access
----------------------------------------------------------------------]]

--- Get loot history (from global scope - persists across profiles)
-- @return table - Array of history entries (copy)
function SettingsMixin:GetHistory()
    local history = self:GetGlobalValue("history", {})
    return Utils.DeepCopy(history)
end

--- Get the live shared history table.
-- @return table
function SettingsMixin:GetHistoryRef()
    local history = self.global.history
    if not history then
        history = {}
        self.global.history = history
    end
    return history
end

--- Add history entry (to global scope)
-- @param entry table - History entry
function SettingsMixin:AddHistoryEntry(entry)
    local history = self:GetHistoryRef()
    history[#history + 1] = entry
end

--- Add multiple history entries to global scope.
-- @param entries table
function SettingsMixin:AddHistoryEntries(entries)
    if not entries or #entries == 0 then
        return
    end

    local history = self:GetHistoryRef()
    for _, entry in ipairs(entries) do
        history[#history + 1] = entry
    end
end

--- Remove a history entry by GUID from the live shared history table.
-- @param guid string
-- @return boolean
function SettingsMixin:RemoveHistoryEntry(guid)
    if not guid then
        return false
    end

    local history = self:GetHistoryRef()
    for index, entry in ipairs(history) do
        if entry.guid == guid then
            table.remove(history, index)
            return true
        end
    end

    return false
end

--- Remove multiple history entries by GUID.
-- @param guidSet table
-- @return number
function SettingsMixin:RemoveHistoryEntries(guidSet)
    if not guidSet then
        return 0
    end

    local history = self:GetHistoryRef()
    local removed = 0

    for index = #history, 1, -1 do
        local entry = history[index]
        if entry and entry.guid and guidSet[entry.guid] then
            table.remove(history, index)
            removed = removed + 1
        end
    end

    return removed
end

--- Get the configured shared history cap.
-- @return number
function SettingsMixin:GetHistoryMaxEntries()
    return tonumber(self:Get("history.maxEntries", Loothing.DefaultSettings.history.maxEntries)) or 500
end

--- Prune oldest history entries to fit the configured cap.
-- @param maxEntries number|nil
-- @return table
function SettingsMixin:PruneHistory(maxEntries)
    local history = self:GetHistoryRef()
    maxEntries = tonumber(maxEntries) or self:GetHistoryMaxEntries()

    if maxEntries <= 0 or #history <= maxEntries then
        return {}
    end

    local removed = {}
    local excess = #history - maxEntries
    for index = 1, excess do
        removed[index] = table.remove(history, 1)
    end

    return removed
end

--- Clear history (global scope)
function SettingsMixin:ClearHistory()
    self:SetGlobalValue("history", {})
end

--[[--------------------------------------------------------------------
    Auto-Pass Settings
----------------------------------------------------------------------]]

--- Get auto-pass enabled setting
-- @return boolean
function SettingsMixin:GetAutoPassEnabled()
    local value = self:Get("autoPass.enabled")
    if value == nil then return false end
    return value
end

--- Set auto-pass enabled
-- @param enabled boolean
function SettingsMixin:SetAutoPassEnabled(enabled)
    self:Set("autoPass.enabled", enabled)
end

--- Get auto-pass weapons setting
-- @return boolean
function SettingsMixin:GetAutoPassWeapons()
    local value = self:Get("autoPass.weapons")
    if value == nil then return false end
    return value
end

--- Set auto-pass weapons
-- @param enabled boolean
function SettingsMixin:SetAutoPassWeapons(enabled)
    self:Set("autoPass.weapons", enabled)
end

--- Get auto-pass BoE setting
-- @return boolean
function SettingsMixin:GetAutoPassBoE()
    return self:Get("autoPass.boe") == true
end

--- Set auto-pass BoE
-- @param enabled boolean
function SettingsMixin:SetAutoPassBoE(enabled)
    self:Set("autoPass.boe", enabled)
end

--- Get auto-pass transmog setting
-- @return boolean
function SettingsMixin:GetAutoPassTransmog()
    return self:Get("autoPass.transmog") == true
end

--- Set auto-pass transmog
-- @param enabled boolean
function SettingsMixin:SetAutoPassTransmog(enabled)
    self:Set("autoPass.transmog", enabled)
end

--[[--------------------------------------------------------------------
    Auto-Trade Settings
----------------------------------------------------------------------]]

--- Get auto-trade enabled setting
-- @return boolean
function SettingsMixin:GetAutoTrade()
    return self:Get("ml.autoTrade") ~= false
end

--- Set auto-trade enabled
-- @param enabled boolean
function SettingsMixin:SetAutoTrade(enabled)
    self:Set("ml.autoTrade", enabled)
end

--[[--------------------------------------------------------------------
    Group Loot Settings
----------------------------------------------------------------------]]

--- Get group loot auto-roll enabled setting
-- @return boolean
function SettingsMixin:GetGroupLootEnabled()
    return self:Get("groupLoot.enabled") ~= false
end

--- Set group loot auto-roll enabled
-- @param enabled boolean
function SettingsMixin:SetGroupLootEnabled(enabled)
    self:Set("groupLoot.enabled", enabled)
end

--- Get group loot hide frames setting
-- @return boolean
function SettingsMixin:GetGroupLootHideFrames()
    return self:Get("groupLoot.hideFrames") ~= false
end

--- Set group loot hide frames
-- @param hide boolean
function SettingsMixin:SetGroupLootHideFrames(hide)
    self:Set("groupLoot.hideFrames", hide)
end

--- Get group loot quality threshold
-- @return number - Minimum item quality for auto-roll (default: Epic = 4)
function SettingsMixin:GetGroupLootQualityThreshold()
    return self:Get("groupLoot.qualityThreshold", Enum.ItemQuality.Epic)
end

--- Set group loot quality threshold
-- @param quality number - Minimum item quality (0-7)
function SettingsMixin:SetGroupLootQualityThreshold(quality)
    quality = math.max(0, math.min(7, quality))
    self:Set("groupLoot.qualityThreshold", quality)
end

--[[--------------------------------------------------------------------
    Auto-Award Settings
----------------------------------------------------------------------]]

--- Get auto-award enabled setting
-- @return boolean
function SettingsMixin:GetAutoAwardEnabled()
    return self:Get("autoAward.enabled") == true
end

--- Set auto-award enabled
-- @param enabled boolean
function SettingsMixin:SetAutoAwardEnabled(enabled)
    self:Set("autoAward.enabled", enabled)
end

--- Get auto-award quality thresholds
-- @return number, number - Lower threshold, upper threshold
function SettingsMixin:GetAutoAwardThresholds()
    local lower = self:Get("autoAward.lowerThreshold", 2)
    local upper = self:Get("autoAward.upperThreshold", 4)
    return lower, upper
end

--- Set auto-award quality thresholds
-- @param lower number - Lower threshold (0-7)
-- @param upper number - Upper threshold (0-7)
function SettingsMixin:SetAutoAwardThresholds(lower, upper)
    self:Set("autoAward.lowerThreshold", lower)
    self:Set("autoAward.upperThreshold", upper)
end

--- Get auto-award target player name
-- @return string
function SettingsMixin:GetAutoAwardTo()
    return self:Get("autoAward.awardTo", "")
end

--- Set auto-award target player name
-- @param name string
function SettingsMixin:SetAutoAwardTo(name)
    self:Set("autoAward.awardTo", name)
end

-- Removed in v2.0.7:
--   GetAutoAwardReason / SetAutoAwardReason
-- Legacy free-text reason superseded by autoAward.reasonId which
-- references the structured awardReasons.reasons table.

--- Get auto-award include BoE setting
-- @return boolean
function SettingsMixin:GetAutoAwardIncludeBoE()
    return self:Get("autoAward.includeBoE") == true
end

--- Set auto-award include BoE
-- @param include boolean
function SettingsMixin:SetAutoAwardIncludeBoE(include)
    self:Set("autoAward.includeBoE", include)
end

--[[--------------------------------------------------------------------
    Ignore Items Settings
----------------------------------------------------------------------]]

--- Get ignore items enabled setting
-- @return boolean
function SettingsMixin:GetIgnoreItemsEnabled()
    return self:Get("ignoreItems.enabled") ~= false
end

--- Set ignore items enabled
-- @param enabled boolean
function SettingsMixin:SetIgnoreItemsEnabled(enabled)
    self:Set("ignoreItems.enabled", enabled)
end

--- Check if an item is ignored
-- @param itemID number - Item ID to check
-- @return boolean - True if item should be ignored
function SettingsMixin:IsItemIgnored(itemID)
    if not self:GetIgnoreItemsEnabled() then
        return false
    end

    local items = self:Get("ignoreItems.items", {})
    return items[itemID] == true
end

--- Add item to ignore list
-- @param itemID number - Item ID to ignore
function SettingsMixin:AddIgnoredItem(itemID)
    if not itemID then return end

    local items = self:Get("ignoreItems.items", {})
    items[itemID] = true
    self:Set("ignoreItems.items", items)
end

--- Remove item from ignore list
-- @param itemID number - Item ID to unignore
function SettingsMixin:RemoveIgnoredItem(itemID)
    if not itemID then return end

    local items = self:Get("ignoreItems.items", {})
    items[itemID] = nil
    self:Set("ignoreItems.items", items)
end

--- Get all ignored items
-- @return table - Table of itemID => true (copy)
function SettingsMixin:GetIgnoredItems()
    local items = self:Get("ignoreItems.items", {})
    return Utils.DeepCopy(items)
end

--- Clear all ignored items
function SettingsMixin:ClearIgnoredItems()
    self:Set("ignoreItems.items", {})
end

--- Get ignore enchanting materials setting
-- @return boolean
function SettingsMixin:GetIgnoreEnchantingMaterials()
    return self:Get("ignoreItems.ignoreEnchantingMaterials") ~= false
end

--- Set ignore enchanting materials
-- @param enabled boolean
function SettingsMixin:SetIgnoreEnchantingMaterials(enabled)
    self:Set("ignoreItems.ignoreEnchantingMaterials", enabled)
end

--- Get ignore crafting reagents setting
-- @return boolean
function SettingsMixin:GetIgnoreCraftingReagents()
    return self:Get("ignoreItems.ignoreCraftingReagents") ~= false
end

--- Set ignore crafting reagents
-- @param enabled boolean
function SettingsMixin:SetIgnoreCraftingReagents(enabled)
    self:Set("ignoreItems.ignoreCraftingReagents", enabled)
end

--- Get ignore consumables setting
-- @return boolean
function SettingsMixin:GetIgnoreConsumables()
    return self:Get("ignoreItems.ignoreConsumables") ~= false
end

--- Set ignore consumables
-- @param enabled boolean
function SettingsMixin:SetIgnoreConsumables(enabled)
    self:Set("ignoreItems.ignoreConsumables", enabled)
end

--- Get ignore permanent enhancements setting
-- @return boolean
function SettingsMixin:GetIgnorePermanentEnhancements()
    return self:Get("ignoreItems.ignorePermanentEnhancements") == true
end

--- Set ignore permanent enhancements
-- @param enabled boolean
function SettingsMixin:SetIgnorePermanentEnhancements(enabled)
    self:Set("ignoreItems.ignorePermanentEnhancements", enabled)
end

--[[--------------------------------------------------------------------
    Voting Options Settings
----------------------------------------------------------------------]]

--- Get self-vote setting
-- @return boolean
function SettingsMixin:GetSelfVote()
    return self:Get("voting.selfVote", false)
end

--- Set self-vote setting
-- @param enabled boolean
function SettingsMixin:SetSelfVote(enabled)
    self:Set("voting.selfVote", enabled)
end

--- Get multi-vote setting
-- @return boolean
function SettingsMixin:GetMultiVote()
    return self:Get("voting.multiVote", false)
end

--- Set multi-vote setting
-- @param enabled boolean
function SettingsMixin:SetMultiVote(enabled)
    self:Set("voting.multiVote", enabled)
end

-- AnonymousVoting / HideVotes accessors moved to SettingsVoting.lua
-- in v2.0.7. Both are now derived projections of the merged
-- voting.privacy field; see GetVotingPrivacy / SetVotingPrivacy there.

--- Get allow response change setting
-- @return boolean
function SettingsMixin:GetAllowResponseChange()
    return self:Get("voting.allowResponseChange", false)
end

--- Set allow response change setting
-- @param enabled boolean
function SettingsMixin:SetAllowResponseChange(enabled)
    self:Set("voting.allowResponseChange", enabled)
end

-- Removed in v2.0.7: GetObserveMode / SetObserveMode
-- The voting.observe key was redundant with observers.openObservation;
-- the migration drops voting.observe and the observers.openObservation
-- accessors are the canonical surface.

-- Observer settings
function SettingsMixin:GetObserverList()
    return self:Get("observers.list", {})
end
function SettingsMixin:SetObserverList(list)
    self:Set("observers.list", list)
end

function SettingsMixin:GetOpenObservation()
    return self:Get("observers.openObservation", false)
end
function SettingsMixin:SetOpenObservation(enabled)
    self:Set("observers.openObservation", enabled == true)
end

function SettingsMixin:GetMLIsObserver()
    return self:Get("observers.mlIsObserver", false)
end
function SettingsMixin:SetMLIsObserver(enabled)
    self:Set("observers.mlIsObserver", enabled == true)
end

function SettingsMixin:GetObserverPermissions()
    return self:Get("observers.permissions", {
        seeVoteCounts = true,
        seeVoterIdentities = false,
        seeResponses = true,
        seeNotes = false,
    })
end
function SettingsMixin:SetObserverPermission(key, enabled)
    local perms = self:GetObserverPermissions()
    perms[key] = enabled == true
    self:Set("observers.permissions", perms)
end

--- Get auto-add rolls setting
-- @return boolean
function SettingsMixin:GetAutoAddRolls()
    return self:Get("voting.autoAddRolls", true)
end

--- Set auto-add rolls setting
-- @param enabled boolean
function SettingsMixin:SetAutoAddRolls(enabled)
    self:Set("voting.autoAddRolls", enabled)
end

--- Get require notes setting
-- @return boolean
function SettingsMixin:GetRequireNotes()
    return self:Get("voting.requireNotes", false)
end

--- Set require notes setting
-- @param enabled boolean
function SettingsMixin:SetRequireNotes(enabled)
    self:Set("voting.requireNotes", enabled)
end

-- Removed in v2.0.8: GetNumButtons / SetNumButtons.
-- The `voting.numButtons` setting had no UI surface and no setter
-- caller — it was a fallback constant read in exactly one branch in
-- RollFrame/UI.lua, where it has been inlined as the literal 5.

--[[--------------------------------------------------------------------
    Award Reasons Settings
----------------------------------------------------------------------]]

--- Get award reasons enabled setting
-- @return boolean
function SettingsMixin:GetAwardReasonsEnabled()
    return self:Get("awardReasons.enabled") ~= false
end

--- Set award reasons enabled
-- @param enabled boolean
function SettingsMixin:SetAwardReasonsEnabled(enabled)
    self:Set("awardReasons.enabled", enabled)
end

--- Get require award reason setting
-- @return boolean
function SettingsMixin:GetRequireAwardReason()
    return self:Get("awardReasons.requireReason") == true
end

--- Set require award reason
-- @param require boolean
function SettingsMixin:SetRequireAwardReason(require)
    self:Set("awardReasons.requireReason", require)
end

--- Get all award reasons (normalized)
-- Ensures every entry has required fields, deduplicates IDs, re-sorts.
-- If array is empty and feature is enabled, restores defaults.
-- @return table - Array of award reason entries (copy)
function SettingsMixin:GetAwardReasons()
    local defaults = Loothing.DefaultSettings.awardReasons.reasons
    local reasons = self:Get("awardReasons.reasons", defaults)
    local copy = Utils.DeepCopy(reasons)

    -- Normalize: fill missing fields with deterministic defaults
    local seenIds = {}
    local dedupedCopy = {}
    for _, entry in ipairs(copy) do
        entry.id = tonumber(entry.id) or 0
        entry.name = type(entry.name) == "string" and entry.name or "Reason"
        if type(entry.color) ~= "table" or #entry.color < 3 then
            entry.color = { 1, 1, 1, 1 }
        end
        entry.sort = tonumber(entry.sort) or 0
        if entry.log == nil then entry.log = true end
        if entry.disenchant == nil then entry.disenchant = false end

        -- Deduplicate IDs (keep first occurrence)
        if not seenIds[entry.id] then
            seenIds[entry.id] = true
            dedupedCopy[#dedupedCopy + 1] = entry
        end
    end
    copy = dedupedCopy

    -- If array is empty and feature is enabled, restore defaults
    if #copy == 0 and self:GetAwardReasonsEnabled() then
        copy = Utils.DeepCopy(defaults)
    end

    -- Sort and renumber sort fields to be contiguous
    table.sort(copy, function(a, b)
        local aSort = tonumber(a and a.sort) or math.huge
        local bSort = tonumber(b and b.sort) or math.huge
        if aSort == bSort then
            return (tonumber(a and a.id) or math.huge) < (tonumber(b and b.id) or math.huge)
        end
        return aSort < bSort
    end)
    for i, entry in ipairs(copy) do
        entry.sort = i
    end

    return copy
end

--- Get award reason by ID
-- @param id number - Reason ID
-- @return table|nil - Award reason entry { id, name, color }
function SettingsMixin:GetAwardReasonById(id)
    local reasons = self:GetAwardReasons()
    for _, reason in ipairs(reasons) do
        if reason.id == id then
            return reason
        end
    end
    return nil
end

--- Add a new award reason
-- @param name string - Reason name
-- @param color table - Color as { r, g, b, a }
-- @return number - New reason ID
function SettingsMixin:AddAwardReason(name, color)
    local reasons = self:GetAwardReasons()

    -- Check if we've reached the limit
    if #reasons >= 20 then
        return nil
    end

    -- Find next available ID
    local maxId = 0
    for _, reason in ipairs(reasons) do
        if reason.id > maxId then
            maxId = reason.id
        end
    end

    local newReason = {
        id = maxId + 1,
        name = name,
        color = color or { 1.0, 1.0, 1.0, 1.0 },
        sort = #reasons + 1,
        log = true,
        disenchant = false
    }

    reasons[#reasons + 1] = newReason
    self:Set("awardReasons.reasons", reasons)

    return newReason.id
end

--- Remove an award reason
-- @param id number - Reason ID to remove
-- @return boolean - True if removed
function SettingsMixin:RemoveAwardReason(id)
    local reasons = self:GetAwardReasons()

    for i, reason in ipairs(reasons) do
        if reason.id == id then
            table.remove(reasons, i)
            for sortIndex, entry in ipairs(reasons) do
                entry.sort = sortIndex
            end
            self:Set("awardReasons.reasons", reasons)
            return true
        end
    end

    return false
end

--- Update an award reason
-- @param id number - Reason ID
-- @param name string|table - New name or patch table (optional)
-- @param color table - New color (optional when name is a string)
-- @return boolean - True if updated
function SettingsMixin:UpdateAwardReason(id, name, color)
    local reasons = self:GetAwardReasons()
    local patch
    if type(name) == "table" then
        patch = name
    else
        patch = {
            name = name,
            color = color,
        }
    end

    for i, reason in ipairs(reasons) do
        if reason.id == id then
            if patch.name ~= nil then
                reason.name = patch.name
            end
            if patch.color ~= nil then
                reason.color = patch.color
            end
            if patch.sort ~= nil then
                reason.sort = math.max(1, math.floor(tonumber(patch.sort) or reason.sort or i))
            end
            if patch.log ~= nil then
                reason.log = patch.log == true
            end
            if patch.disenchant ~= nil then
                reason.disenchant = patch.disenchant == true
            end
            table.sort(reasons, function(a, b)
                local aSort = tonumber(a and a.sort) or math.huge
                local bSort = tonumber(b and b.sort) or math.huge
                if aSort == bSort then
                    return (tonumber(a and a.id) or math.huge) < (tonumber(b and b.id) or math.huge)
                end
                return aSort < bSort
            end)
            for sortIndex, entry in ipairs(reasons) do
                entry.sort = sortIndex
            end
            self:Set("awardReasons.reasons", reasons)
            return true
        end
    end

    return false
end

--- Reset award reasons to defaults
function SettingsMixin:ResetAwardReasons()
    local defaults = Utils.DeepCopy(Loothing.DefaultSettings.awardReasons.reasons)
    self:Set("awardReasons.reasons", defaults)
end

--- Get auto-award structured reason ID
-- @return number|nil - Award reason ID or nil if unassigned
function SettingsMixin:GetAutoAwardReasonId()
    return self:Get("autoAward.reasonId")
end

--- Set auto-award structured reason ID
-- @param id number|nil - Award reason ID or nil to unassign
function SettingsMixin:SetAutoAwardReasonId(id)
    self:Set("autoAward.reasonId", id)
end

--- Get award reason log setting
-- @param id number - Reason ID
-- @return boolean - Whether this reason should be logged
function SettingsMixin:GetAwardReasonLog(id)
    local reason = self:GetAwardReasonById(id)
    if reason then
        return reason.log ~= false  -- Default to true if not set
    end
    return true
end

--- Set award reason log setting
-- @param id number - Reason ID
-- @param enabled boolean - Whether to log awards with this reason
function SettingsMixin:SetAwardReasonLog(id, enabled)
    local reasons = self:GetAwardReasons()
    for _, reason in ipairs(reasons) do
        if reason.id == id then
            reason.log = enabled
            self:Set("awardReasons.reasons", reasons)
            return
        end
    end
end

--- Get award reason disenchant setting
-- @param id number - Reason ID
-- @return boolean - Whether this reason should be treated as disenchant
function SettingsMixin:GetAwardReasonDisenchant(id)
    local reason = self:GetAwardReasonById(id)
    if reason then
        return reason.disenchant == true
    end
    return false
end

--- Set award reason disenchant setting
-- @param id number - Reason ID
-- @param enabled boolean - Whether to treat awards with this reason as disenchant
function SettingsMixin:SetAwardReasonDisenchant(id, enabled)
    local reasons = self:GetAwardReasons()
    for _, reason in ipairs(reasons) do
        if reason.id == id then
            reason.disenchant = enabled
            self:Set("awardReasons.reasons", reasons)
            return
        end
    end
end

--- Reorder award reason (move up or down in sort order)
-- @param id number - Reason ID
-- @param direction string - "up" or "down"
-- @return boolean - True if reordered successfully
function SettingsMixin:ReorderAwardReason(id, direction)
    local reasons = self:GetAwardReasons()

    -- Find the reason
    local reasonIndex = nil
    for i, reason in ipairs(reasons) do
        if reason.id == id then
            reasonIndex = i
            break
        end
    end

    if not reasonIndex then
        return false
    end

    -- Determine swap index
    local swapIndex = nil
    if direction == "up" and reasonIndex > 1 then
        swapIndex = reasonIndex - 1
    elseif direction == "down" and reasonIndex < #reasons then
        swapIndex = reasonIndex + 1
    end

    if not swapIndex then
        return false
    end

    -- Swap the reasons
    local temp = reasons[reasonIndex]
    reasons[reasonIndex] = reasons[swapIndex]
    reasons[swapIndex] = temp

    -- Update sort order to match new positions
    for i, reason in ipairs(reasons) do
        reason.sort = i
    end

    self:Set("awardReasons.reasons", reasons)
    return true
end

--- Reset award reasons to defaults (alias for ResetAwardReasons)
function SettingsMixin:ResetAwardReasonsToDefaults()
    local defaults = Utils.DeepCopy(Loothing.DefaultSettings.awardReasons)
    self:Set("awardReasons", defaults)
end

--[[--------------------------------------------------------------------
    Button Sets Settings (REMOVED in v2.0.7)

    The legacy buttonSets.* table was superseded by responseSets.* in
    earlier versions. The migration in Migrations.lua deletes the dead
    profile data; the entire accessor surface is removed here. Use
    GetResponseSet / SetResponseSet / etc. below instead.
----------------------------------------------------------------------]]

--[[--------------------------------------------------------------------
    Response Sets Settings (unified model)
----------------------------------------------------------------------]]

local function GetDefaultResponseSetTemplate(setId)
    local defaults = Loothing.DefaultSettings.responseSets and Loothing.DefaultSettings.responseSets.sets or {}
    return defaults[setId] or defaults[1] or { name = "Default", buttons = {} }
end

local function NormalizeResponseColor(color, fallback)
    return Utils.ColorToArray(color or fallback or { 1, 1, 1, 1 })
end

local function NormalizeResponseWhisperKeys(keys, fallback)
    if type(keys) == "table" then
        return Utils.DeepCopy(keys)
    end
    if type(fallback) == "table" then
        return Utils.DeepCopy(fallback)
    end
    return {}
end

local function NormalizeResponseSetData(setId, setData)
    local defaultSet = GetDefaultResponseSetTemplate(setId)
    local sourceButtons = type(setData) == "table" and type(setData.buttons) == "table" and setData.buttons or nil
    if not sourceButtons or #sourceButtons == 0 then
        sourceButtons = defaultSet.buttons or {}
    end

    local orderedButtons = {}
    for i, btn in ipairs(sourceButtons) do
        orderedButtons[i] = btn
    end
    table.sort(orderedButtons, function(a, b)
        local aSort = type(a) == "table" and (a.sort or a.id) or nil
        local bSort = type(b) == "table" and (b.sort or b.id) or nil
        return (aSort or math.huge) < (bSort or math.huge)
    end)

    local usedIds = {}
    local buttons = {}
    for i, btn in ipairs(orderedButtons) do
        local defaultBtn = defaultSet.buttons and defaultSet.buttons[i] or nil
        local normalized = {}

        local rawId = type(btn) == "table" and tonumber(btn.id) or nil
        local id = rawId and rawId > 0 and math.floor(rawId) or nil
        if not id or usedIds[id] then
            id = 1
            while usedIds[id] do
                id = id + 1
            end
        end
        usedIds[id] = true

        local text = type(btn) == "table" and btn.text or nil
        text = text or (defaultBtn and defaultBtn.text) or ("Button " .. id)

        normalized.id = id
        normalized.text = text
        normalized.responseText = (type(btn) == "table" and btn.responseText) or text
        normalized.color = NormalizeResponseColor(type(btn) == "table" and btn.color or nil, defaultBtn and defaultBtn.color)
        normalized.icon = (type(btn) == "table" and btn.icon ~= nil) and btn.icon or (defaultBtn and defaultBtn.icon) or nil
        normalized.sort = i
        normalized.whisperKeys = NormalizeResponseWhisperKeys(type(btn) == "table" and btn.whisperKeys or nil, defaultBtn and defaultBtn.whisperKeys)
        buttons[i] = normalized
    end

    return {
        name = (type(setData) == "table" and setData.name) or defaultSet.name or ("Set " .. tostring(setId)),
        buttons = buttons,
    }
end

function SettingsMixin:NormalizeResponseSets(data)
    local defaults = Loothing.DefaultSettings.responseSets or {}
    local source = type(data) == "table" and data or defaults
    local normalized = {
        activeSet = tonumber(source.activeSet) or defaults.activeSet or 1,
        sets = {},
        typeCodeMap = {},
    }

    local sourceSets = type(source.sets) == "table" and source.sets or {}
    for setId, setData in pairs(sourceSets) do
        if type(setId) == "number" then
            normalized.sets[setId] = NormalizeResponseSetData(setId, setData)
        end
    end

    if not normalized.sets[1] then
        normalized.sets[1] = NormalizeResponseSetData(1, defaults.sets and defaults.sets[1] or nil)
    end

    if not normalized.sets[normalized.activeSet] then
        normalized.activeSet = 1
    end

    local sourceTypeCodeMap = type(source.typeCodeMap) == "table" and source.typeCodeMap or {}
    for typeCode, setId in pairs(sourceTypeCodeMap) do
        if normalized.sets[setId] then
            normalized.typeCodeMap[typeCode] = setId
        end
    end

    return normalized
end

local function ResponseSetsNeedRepair(source, normalized)
    if type(source) ~= "table" then
        return true
    end
    if source.activeSet ~= normalized.activeSet then
        return true
    end
    if type(source.sets) ~= "table" or not source.sets[1] then
        return true
    end
    if type(source.typeCodeMap) ~= "table" then
        return true
    end

    for setId, normalizedSet in pairs(normalized.sets or {}) do
        local rawSet = source.sets[setId]
        if type(rawSet) ~= "table" or type(rawSet.buttons) ~= "table" then
            return true
        end
        if rawSet.name ~= normalizedSet.name or #rawSet.buttons ~= #normalizedSet.buttons then
            return true
        end

        for i, normalizedBtn in ipairs(normalizedSet.buttons) do
            local rawBtn = rawSet.buttons[i]
            if type(rawBtn) ~= "table"
                or rawBtn.id ~= normalizedBtn.id
                or rawBtn.sort ~= normalizedBtn.sort
                or rawBtn.text == nil
                or rawBtn.responseText == nil
                or rawBtn.color == nil
                or type(rawBtn.whisperKeys) ~= "table"
            then
                return true
            end
        end
    end

    for typeCode, setId in pairs(source.typeCodeMap) do
        if normalized.typeCodeMap[typeCode] ~= setId then
            return true
        end
    end
    for typeCode, setId in pairs(normalized.typeCodeMap) do
        if source.typeCodeMap[typeCode] ~= setId then
            return true
        end
    end

    return false
end

--- Get full responseSets data
-- @return table - { activeSet, sets, typeCodeMap }
function SettingsMixin:GetResponseSets()
    local stored = self:Get("responseSets", nil)
    local normalized = self:NormalizeResponseSets(stored)

    if ResponseSetsNeedRepair(stored, normalized) then
        self:Set("responseSets", Utils.DeepCopy(normalized))
    end

    return Utils.DeepCopy(normalized)
end

--- Get active response set ID
-- @return number
function SettingsMixin:GetActiveResponseSet()
    return self:Get("responseSets.activeSet", 1)
end

--- Set active response set
-- @param id number
function SettingsMixin:SetActiveResponseSet(id)
    local rs = self:GetResponseSets()
    if rs.sets and rs.sets[id] then
        self:Set("responseSets.activeSet", id)
    end
end

--- Get a response set by ID
-- @param id number
-- @return table|nil
function SettingsMixin:GetResponseSetById(id)
    local rs = self:GetResponseSets()
    return rs.sets and rs.sets[id]
end

--- Get buttons for the active set, or a specific set
-- @param setId number|nil - If nil, uses active set
-- @return table - Array of button data
function SettingsMixin:GetResponseButtons(setId)
    local id = setId or self:GetActiveResponseSet()
    local set = self:GetResponseSetById(id)
    if set and set.buttons then
        return Utils.DeepCopy(set.buttons)
    end
    return {}
end

--- Add a new response set
-- @param name string
-- @param buttons table|nil - Initial buttons (uses default response template if nil)
-- @return number - New set ID
function SettingsMixin:AddResponseSet(name, buttons)
    local rs = self:GetResponseSets()
    if not rs.sets then rs.sets = {} end

    local maxId = 0
    for id in pairs(rs.sets) do
        if id > maxId then maxId = id end
    end

    local newId = maxId + 1
    rs.sets[newId] = {
        name = name,
        buttons = buttons or Utils.DeepCopy(GetDefaultResponseSetTemplate(1).buttons),
    }
    self:Set("responseSets", self:NormalizeResponseSets(rs))
    return newId
end

--- Remove a response set (cannot remove set 1)
-- @param id number
-- @return boolean
function SettingsMixin:RemoveResponseSet(id)
    if id == 1 then return false end

    local rs = self:GetResponseSets()
    if not rs.sets or not rs.sets[id] then return false end

    rs.sets[id] = nil
    if (rs.activeSet or 1) == id then
        rs.activeSet = 1
    end
    self:Set("responseSets", rs)
    return true
end

--- Update response set data (merges fields)
-- @param id number
-- @param data table
-- @return boolean
function SettingsMixin:UpdateResponseSet(id, data)
    local rs = self:GetResponseSets()
    if not rs.sets or not rs.sets[id] then return false end

    for k, v in pairs(data) do
        rs.sets[id][k] = v
    end
    self:Set("responseSets", rs)
    return true
end

--- Add a button to a response set
-- @param setId number
-- @param data table - Button fields (text, responseText, color, icon, whisperKeys)
-- @return number|nil - New button ID
function SettingsMixin:AddResponseButton(setId, data)
    local rs = self:GetResponseSets()
    if not rs.sets or not rs.sets[setId] then return nil end

    local buttons = rs.sets[setId].buttons or {}
    if #buttons >= 10 then return nil end

    local maxId = 0
    for _, btn in ipairs(buttons) do
        if btn.id > maxId then maxId = btn.id end
    end

    local newBtn = {
        id           = maxId + 1,
        text         = data.text or "New Button",
        responseText = data.responseText or data.text or "NEW",
        color        = data.color or { 1.0, 1.0, 1.0, 1.0 },
        icon         = data.icon,
        sort         = #buttons + 1,
        whisperKeys  = data.whisperKeys or {},
    }

    buttons[#buttons + 1] = newBtn
    rs.sets[setId].buttons = buttons
    self:Set("responseSets", rs)
    return newBtn.id
end

--- Remove a button from a response set (minimum 1 button enforced)
-- @param setId number
-- @param btnId number
-- @return boolean
function SettingsMixin:RemoveResponseButton(setId, btnId)
    local rs = self:GetResponseSets()
    if not rs.sets or not rs.sets[setId] then return false end

    local buttons = rs.sets[setId].buttons or {}
    if #buttons <= 1 then return false end

    for i, btn in ipairs(buttons) do
        if btn.id == btnId then
            table.remove(buttons, i)
            for j, b in ipairs(buttons) do b.sort = j end
            rs.sets[setId].buttons = buttons
            self:Set("responseSets", rs)
            return true
        end
    end
    return false
end

--- Update a button's fields
-- @param setId number
-- @param btnId number
-- @param data table
-- @return boolean
function SettingsMixin:UpdateResponseButton(setId, btnId, data)
    local rs = self:GetResponseSets()
    if not rs.sets or not rs.sets[setId] then return false end

    local buttons = rs.sets[setId].buttons or {}
    for _, btn in ipairs(buttons) do
        if btn.id == btnId then
            for k, v in pairs(data) do btn[k] = v end
            rs.sets[setId].buttons = buttons
            self:Set("responseSets", rs)
            return true
        end
    end
    return false
end

--- Reorder a button to a new sort position
-- @param setId number
-- @param btnId number
-- @param newSort number
function SettingsMixin:ReorderResponseButton(setId, btnId, newSort)
    local rs = self:GetResponseSets()
    if not rs.sets or not rs.sets[setId] then return end

    local buttons = rs.sets[setId].buttons or {}
    local oldSort, targetIdx
    for i, btn in ipairs(buttons) do
        if btn.id == btnId then
            oldSort = btn.sort
            targetIdx = i
            break
        end
    end
    if not targetIdx then return end

    newSort = math.max(1, math.min(#buttons, newSort))

    for _, btn in ipairs(buttons) do
        if btn.id ~= btnId then
            if oldSort < newSort then
                if btn.sort > oldSort and btn.sort <= newSort then
                    btn.sort = btn.sort - 1
                end
            else
                if btn.sort >= newSort and btn.sort < oldSort then
                    btn.sort = btn.sort + 1
                end
            end
        end
    end
    buttons[targetIdx].sort = newSort
    table.sort(buttons, function(a, b) return a.sort < b.sort end)
    for i, btn in ipairs(buttons) do btn.sort = i end

    rs.sets[setId].buttons = buttons
    self:Set("responseSets", rs)
end

--- Get the typeCode -> setId mapping
-- @return table
function SettingsMixin:GetTypeCodeMap()
    local rs = self:GetResponseSets()
    return rs.typeCodeMap or {}
end

--- Assign a button set to a type code
-- @param typeCode string
-- @param setId number
function SettingsMixin:SetTypeCodeForSet(typeCode, setId)
    local rs = self:GetResponseSets()
    if not rs.typeCodeMap then rs.typeCodeMap = {} end
    rs.typeCodeMap[typeCode] = setId
    self:Set("responseSets", rs)
end

--- Clear a type-code override so it falls back to the default mapping or active set
-- @param typeCode string
function SettingsMixin:ClearTypeCodeForSet(typeCode)
    local rs = self:GetResponseSets()
    if not rs.typeCodeMap then
        return
    end

    rs.typeCodeMap[typeCode] = nil
    self:Set("responseSets", rs)
end

--[[--------------------------------------------------------------------
    Filter Settings
----------------------------------------------------------------------]]

--- Get filters enabled setting
-- @return boolean
function SettingsMixin:GetFiltersEnabled()
    return self:Get("filters.enabled") ~= false
end

--- Set filters enabled
-- @param enabled boolean
function SettingsMixin:SetFiltersEnabled(enabled)
    self:Set("filters.enabled", enabled)
end

--- Get class filters
-- @return table - Table of class names to show (empty = all) (copy)
function SettingsMixin:GetClassFilters()
    local filters = self:Get("filters.byClass", {})
    return Utils.DeepCopy(filters)
end

--- Set class filters
-- @param classes table - Table of class names to show
function SettingsMixin:SetClassFilters(classes)
    self:Set("filters.byClass", classes)
end

--- Add a class to the filter
-- @param class string - Class file name (e.g., "WARRIOR")
function SettingsMixin:AddClassFilter(class)
    if not class then return end

    local filters = self:GetClassFilters()
    filters[class] = true
    self:SetClassFilters(filters)
end

--- Remove a class from the filter
-- @param class string - Class file name
function SettingsMixin:RemoveClassFilter(class)
    if not class then return end

    local filters = self:GetClassFilters()
    filters[class] = nil
    self:SetClassFilters(filters)
end

--- Get response filters
-- @return table - Table of response IDs to show (empty = all) (copy)
function SettingsMixin:GetResponseFilters()
    local filters = self:Get("filters.byResponse", {})
    return Utils.DeepCopy(filters)
end

--- Set response filters
-- @param responses table - Table of response IDs to show
function SettingsMixin:SetResponseFilters(responses)
    self:Set("filters.byResponse", responses)
end

--- Add a response to the filter
-- @param responseId number - Response ID
function SettingsMixin:AddResponseFilter(responseId)
    if not responseId then return end

    local filters = self:GetResponseFilters()
    filters[responseId] = true
    self:SetResponseFilters(filters)
end

--- Remove a response from the filter
-- @param responseId number - Response ID
function SettingsMixin:RemoveResponseFilter(responseId)
    if not responseId then return end

    local filters = self:GetResponseFilters()
    filters[responseId] = nil
    self:SetResponseFilters(filters)
end

--- Get guild rank filters
-- @return table - Table of guild rank indices to show (empty = all) (copy)
function SettingsMixin:GetGuildRankFilters()
    local filters = self:Get("filters.byGuildRank", {})
    return Utils.DeepCopy(filters)
end

--- Set guild rank filters
-- @param ranks table - Table of guild rank indices to show
function SettingsMixin:SetGuildRankFilters(ranks)
    self:Set("filters.byGuildRank", ranks)
end

--- Add a guild rank to the filter
-- @param rank number - Guild rank index
function SettingsMixin:AddGuildRankFilter(rank)
    if not rank then return end

    local filters = self:GetGuildRankFilters()
    filters[rank] = true
    self:SetGuildRankFilters(filters)
end

--- Remove a guild rank from the filter
-- @param rank number - Guild rank index
function SettingsMixin:RemoveGuildRankFilter(rank)
    if not rank then return end

    local filters = self:GetGuildRankFilters()
    filters[rank] = nil
    self:SetGuildRankFilters(filters)
end

--- Get show only equippable setting
-- @return boolean
function SettingsMixin:GetShowOnlyEquippable()
    return self:Get("filters.showOnlyEquippable") == true
end

--- Set show only equippable
-- @param enabled boolean
function SettingsMixin:SetShowOnlyEquippable(enabled)
    self:Set("filters.showOnlyEquippable", enabled)
end

--- Get hide passed items setting
-- @return boolean
function SettingsMixin:GetHidePassedItems()
    return self:Get("filters.hidePassedItems") ~= false
end

--- Set hide passed items
-- @param enabled boolean
function SettingsMixin:SetHidePassedItems(enabled)
    self:Set("filters.hidePassedItems", enabled)
end

--- Clear all filters
function SettingsMixin:ClearAllFilters()
    self:Set("filters.byClass", {})
    self:Set("filters.byResponse", {})
    self:Set("filters.byGuildRank", {})
    self:Set("filters.showOnlyEquippable", false)
end

--[[--------------------------------------------------------------------
    Council Table Settings
----------------------------------------------------------------------]]

--- Get council table column visibility
-- @param columnId string - Column ID
-- @return boolean - True if column is visible
function SettingsMixin:GetColumnVisibility(columnId)
    local columns = self:Get("councilTable.columns", {})
    if columns[columnId] == nil then
        return true  -- Default to visible
    end
    return columns[columnId]
end

--- Set council table column visibility
-- @param columnId string - Column ID
-- @param visible boolean - True to show, false to hide
function SettingsMixin:SetColumnVisibility(columnId, visible)
    local columns = self:Get("councilTable.columns", {})
    columns[columnId] = visible
    self:Set("councilTable.columns", columns)
end

--- Get all council table column visibility settings
-- @return table - Table of columnId -> boolean (copy)
function SettingsMixin:GetAllColumnVisibility()
    local columns = self:Get("councilTable.columns", {})
    return Utils.DeepCopy(columns)
end

--- Reset council table columns to defaults
function SettingsMixin:ResetColumnVisibility()
    self:Set("councilTable.columns", {})
end

--- Get council table default sort column
-- @return string - Column ID
function SettingsMixin:GetCouncilTableSortColumn()
    return self:Get("councilTable.sortColumn", "response")
end

--- Set council table default sort column
-- @param columnId string - Column ID
function SettingsMixin:SetCouncilTableSortColumn(columnId)
    self:Set("councilTable.sortColumn", columnId)
end

--- Get council table sort ascending setting
-- @return boolean
function SettingsMixin:GetCouncilTableSortAscending()
    return self:Get("councilTable.sortAscending") == true
end

--- Set council table sort ascending
-- @param ascending boolean
function SettingsMixin:SetCouncilTableSortAscending(ascending)
    self:Set("councilTable.sortAscending", ascending)
end

--- Get council table sort settings
-- @return string, boolean - columnId, ascending
function SettingsMixin:GetCouncilTableSort()
    local column = self:Get("councilTable.sortColumn") or "response"
    local asc = self:Get("councilTable.sortAscending")
    if asc == nil then asc = true end
    return column, asc
end

--- Set council table sort settings
-- @param columnId string
-- @param ascending boolean
function SettingsMixin:SetCouncilTableSort(columnId, ascending)
    self:Set("councilTable.sortColumn", columnId)
    self:Set("councilTable.sortAscending", ascending)
end

-- Removed in v2.0.8: GetCouncilTableRowHeight
-- The accessor had zero callers — every council table renderer used
-- a hardcoded row height. The `councilTable.rowHeight` setting itself
-- has been deleted from DefaultSettings.

--[[--------------------------------------------------------------------
    Roll Frame Settings (rollFrame.*)
----------------------------------------------------------------------]]

-- Removed in v2.0.8: GetRollFrameAutoShow / SetRollFrameAutoShow
-- Consumers (LocalPreferences.lua) use direct
-- Loothing.Settings:Get("rollFrame.autoShow") instead.

-- Removed in v2.0.8: GetAutoRollOnSubmit / SetAutoRollOnSubmit
-- The setting was wired to the wrong call site (DisplayItem, not
-- response submit) and harmful in practice — it pre-rolled on every
-- item display before the user had decided on a response, leaking
-- the roll value to the council before their response and spamming
-- the roll channel. The genuine "tiebreaker roll" use case is already
-- covered by voting.autoAddRolls.

--- Get the roll range
-- @return table { min, max } (copy)
function SettingsMixin:GetRollRange()
    local range = self:Get("rollFrame.rollRange") or { min = 1, max = 100 }
    return { min = range.min, max = range.max }
end

-- Removed in v2.0.8: SetRollRange (Get is still alive — read in
-- RollFrame.lua's DoRoll). The roll range is hardcoded {1,100} in
-- DefaultSettings and there is no UI surface to change it.

-- Removed in v2.0.8: GetShowGearComparison / SetShowGearComparison
-- Consumers use direct Loothing.Settings:Get("rollFrame.showGearComparison")
-- instead — see RollFrame.lua and RollFrame/UI.lua.

-- Removed in v2.0.8: GetRollFramePosition / SetRollFramePosition
-- Position save/restore is done elsewhere via direct Get/Set.

--[[--------------------------------------------------------------------
    RollFrame Timeout Settings
----------------------------------------------------------------------]]

--- Get whether timeout is enabled for RollFrame
-- @return boolean
function SettingsMixin:GetRollFrameTimeoutEnabled()
    local value = self:Get("rollFrame.timeoutEnabled")
    if value == nil then return false end
    return value
end

--- Set whether timeout is enabled for RollFrame
-- @param value boolean
function SettingsMixin:SetRollFrameTimeoutEnabled(value)
    self:Set("rollFrame.timeoutEnabled", value)
end

--- Get RollFrame timeout duration
-- @return number - Seconds (MIN_ROLL_TIMEOUT to MAX_ROLL_TIMEOUT)
function SettingsMixin:GetRollFrameTimeoutDuration()
    local value = self:Get("rollFrame.timeoutDuration")
    local defaultTimeout = Loothing.Timing and Loothing.Timing.DEFAULT_ROLL_TIMEOUT or 30
    local minTimeout = Loothing.Timing and Loothing.Timing.MIN_ROLL_TIMEOUT or 5
    local maxTimeout = Loothing.Timing and Loothing.Timing.MAX_ROLL_TIMEOUT or 200

    if value == nil then return defaultTimeout end
    return math.max(minTimeout, math.min(maxTimeout, value))
end

--- Set RollFrame timeout duration
-- @param seconds number (MIN_ROLL_TIMEOUT to MAX_ROLL_TIMEOUT)
function SettingsMixin:SetRollFrameTimeoutDuration(seconds)
    if seconds == (Loothing.Timing and Loothing.Timing.NO_TIMEOUT or 0) then
        self:Set("rollFrame.timeoutDuration", 0)
    else
        local minTimeout = Loothing.Timing and Loothing.Timing.MIN_ROLL_TIMEOUT or 5
        local maxTimeout = Loothing.Timing and Loothing.Timing.MAX_ROLL_TIMEOUT or 200
        seconds = math.max(minTimeout, math.min(maxTimeout, seconds))
        self:Set("rollFrame.timeoutDuration", seconds)
    end
end

--[[--------------------------------------------------------------------
    Winner Determination Settings (winnerDetermination.*)
----------------------------------------------------------------------]]

-- Removed in v2.0.8: GetWinnerMode / SetWinnerMode
-- Consumers use direct Loothing.Settings:Get/Set("winnerDetermination.mode")
-- instead.

--- Get tie breaker mode
-- @return string "ROLL", "ML_CHOICE", or "REVOTE"
function SettingsMixin:GetTieBreakerMode()
    local value = self:Get("winnerDetermination.tieBreaker")
    if value == nil then return "ROLL" end
    return value
end

-- Removed in v2.0.8: SetTieBreakerMode (Get is still alive — read in
-- VotingSession.lua and the options table). The setter had no callers;
-- writes go through direct Loothing.Settings:Set("winnerDetermination.tieBreaker").

--- Get whether to auto-award on unanimous vote
-- @return boolean
function SettingsMixin:GetAutoAwardOnUnanimous()
    local value = self:Get("winnerDetermination.autoAwardOnUnanimous")
    if value == nil then return false end
    return value
end

--- Set whether to auto-award on unanimous vote
-- @param value boolean
function SettingsMixin:SetAutoAwardOnUnanimous(value)
    self:Set("winnerDetermination.autoAwardOnUnanimous", value)
end

-- Removed in v2.0.7: GetRequireConfirmation / SetRequireConfirmation
-- The toggle was redundant with `winnerDetermination.mode`. ML_CONFIRM
-- and AUTO_HIGHEST_CONFIRM imply confirmation; HIGHEST_VOTES does not.
-- The derived projection that lived here through v2.0.7 was itself
-- removed in v2.0.8 — it had zero callers, so any code that needs to
-- know whether confirmation is required should check `mode` directly.
