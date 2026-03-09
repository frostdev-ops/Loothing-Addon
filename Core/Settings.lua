--[[--------------------------------------------------------------------
    Loothing - Loot Council Addon for WoW 12.0+
    Settings - SavedVariables wrapper and settings management

    Uses Loolib's SavedVariables system for multi-profile support.
    Data is split into two scopes:
      - profile: User preferences (switches per character/profile)
      - global: Shared data (history, trade queue, item storage, migrations, player cache)

    All existing getter/setter methods remain unchanged. Callers do not
    need to know about profiles - self.db routes to the active profile.
----------------------------------------------------------------------]]

local Loolib = LibStub("Loolib")
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
    version = 1,

    council = CopyDefaults(Loothing.DefaultSettings.council),
    observers = CopyDefaults(Loothing.DefaultSettings.observers),
    settings = CopyDefaults(Loothing.DefaultSettings.settings),
    announcements = CopyDefaults(Loothing.DefaultSettings.announcements),
    autoPass = CopyDefaults(Loothing.DefaultSettings.autoPass),
    autoAward = CopyDefaults(Loothing.DefaultSettings.autoAward),
    ignoreItems = CopyDefaults(Loothing.DefaultSettings.ignoreItems),
    voting = CopyDefaults(Loothing.DefaultSettings.voting),
    responses = CopyDefaults(Loothing.DefaultSettings.responses),
    awardReasons = CopyDefaults(Loothing.DefaultSettings.awardReasons),
    frame = CopyDefaults(Loothing.DefaultSettings.frame),
    ml = CopyDefaults(Loothing.DefaultSettings.ml),
    historySettings = CopyDefaults(Loothing.DefaultSettings.historySettings),
    buttonSets = CopyDefaults(Loothing.DefaultSettings.buttonSets),
    responseSets = CopyDefaults(Loothing.DefaultSettings.responseSets),
    filters = CopyDefaults(Loothing.DefaultSettings.filters),
    groupLoot = CopyDefaults(Loothing.DefaultSettings.groupLoot),
    rollFrame = CopyDefaults(Loothing.DefaultSettings.rollFrame),
    councilTable = CopyDefaults(Loothing.DefaultSettings.councilTable),
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
    LoothingSettingsMixin
----------------------------------------------------------------------]]

LoothingSettingsMixin = {}

local function allowTestPersistence(context)
    if Loothing and Loothing.TestMode and Loothing.TestMode.GuardPersistence then
        return Loothing.TestMode:GuardPersistence(context)
    end
    return true
end

--- Initialize settings with Loolib SavedVariables multi-profile support
function LoothingSettingsMixin:Init()
    -- Create Loolib SavedVariables database with profile + global scopes
    self.sv = Loolib.Data.SavedVariables.Create("LoothingDB", SV_DEFAULTS, "Default")

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
function LoothingSettingsMixin:Save()
    -- No-op: Loolib SavedVariables handles persistence on PLAYER_LOGOUT
end

--[[--------------------------------------------------------------------
    Profile Management
----------------------------------------------------------------------]]

--- Get the Loolib SavedVariables database object
-- @return table - The saved variables instance
function LoothingSettingsMixin:GetDB()
    return self.sv
end

--- Get the global data table (history, trade queue, etc.)
-- @return table
function LoothingSettingsMixin:GetGlobal()
    return self.global
end

--- Get the current profile name
-- @return string
function LoothingSettingsMixin:GetCurrentProfile()
    return self.sv:GetCurrentProfile()
end

--- Get all available profile names
-- @return table - Array of profile name strings
function LoothingSettingsMixin:GetProfiles()
    return self.sv:GetProfiles()
end

--- Switch to a different profile
-- @param name string - Profile name (creates if doesn't exist)
function LoothingSettingsMixin:SetProfile(name)
    self.sv:SetProfile(name)
end

--- Copy data from another profile to the current profile
-- @param sourceName string - Source profile name
function LoothingSettingsMixin:CopyProfile(sourceName)
    self.sv:CopyProfile(sourceName)
end

--- Delete a profile
-- @param name string - Profile name to delete
-- @return boolean - Success
function LoothingSettingsMixin:DeleteProfile(name)
    return self.sv:DeleteProfile(name, true)
end

--- Reset current profile to defaults
function LoothingSettingsMixin:ResetProfile()
    self.sv:ResetProfile()
end

--[[--------------------------------------------------------------------
    General Settings Accessors
----------------------------------------------------------------------]]

--- Get a setting value from the active profile
-- @param key string - Setting key (supports dot notation: "settings.votingMode")
-- @param default any - Default value if not found
-- @return any
function LoothingSettingsMixin:Get(key, default)
    local parts = LoothingUtils.Split(key, ".")
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
function LoothingSettingsMixin:Set(key, value)
    if not allowTestPersistence(key) then
        return
    end

    local parts = LoothingUtils.Split(key, ".")
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
function LoothingSettingsMixin:GetGlobalValue(key, default)
    local parts = LoothingUtils.Split(key, ".")
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
function LoothingSettingsMixin:SetGlobalValue(key, value)
    if not allowTestPersistence("global." .. key) then
        return
    end

    local parts = LoothingUtils.Split(key, ".")
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
function LoothingSettingsMixin:Reset(key)
    local default = self:GetDefault(key)
    self:Set(key, LoothingUtils.DeepCopy(default))
end

--- Get default value for a setting
-- @param key string - Setting key
-- @return any
function LoothingSettingsMixin:GetDefault(key)
    local parts = LoothingUtils.Split(key, ".")
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
function LoothingSettingsMixin:ResetAll()
    self.sv:ResetProfile()
    self.db = self.sv.profile
end

--[[--------------------------------------------------------------------
    UI Settings
----------------------------------------------------------------------]]

--- Get UI scale
-- @return number
function LoothingSettingsMixin:GetUIScale()
    return self:Get("settings.uiScale", 1.0)
end

--- Set UI scale
-- @param scale number
function LoothingSettingsMixin:SetUIScale(scale)
    scale = math.max(0.5, math.min(2.0, scale))
    self:Set("settings.uiScale", scale)
end

--- Get main frame position
-- @return table|nil - { point, x, y }
function LoothingSettingsMixin:GetMainFramePosition()
    return self:Get("settings.mainFramePosition", nil)
end

--- Save main frame position
-- @param point string - Anchor point
-- @param x number - X offset
-- @param y number - Y offset
function LoothingSettingsMixin:SetMainFramePosition(point, x, y)
    self:Set("settings.mainFramePosition", { point = point, x = x, y = y })
end

--- Get minimap button visibility
-- @return boolean
function LoothingSettingsMixin:GetShowMinimapButton()
    return self:Get("settings.showMinimapButton", true)
end

--- Set minimap button visibility
-- @param show boolean
function LoothingSettingsMixin:SetShowMinimapButton(show)
    self:Set("settings.showMinimapButton", show)
end

--[[--------------------------------------------------------------------
    Council Settings
----------------------------------------------------------------------]]

--- Get council members
-- @return table - Array of member names (copy)
function LoothingSettingsMixin:GetCouncilMembers()
    local members = self:Get("council.members", {})
    return LoothingUtils.DeepCopy(members)
end

--- Set council members
-- @param members table - Array of member names
function LoothingSettingsMixin:SetCouncilMembers(members)
    self:Set("council.members", members)
end

--- Add council member
-- @param name string - Member name
function LoothingSettingsMixin:AddCouncilMember(name)
    local members = self:GetCouncilMembers()
    local normalized = LoothingUtils.NormalizeName(name)

    if not LoothingUtils.Contains(members, normalized) then
        members[#members + 1] = normalized
        self:SetCouncilMembers(members)
    end
end

--- Remove council member
-- @param name string - Member name
function LoothingSettingsMixin:RemoveCouncilMember(name)
    local members = self:GetCouncilMembers()
    local normalized = LoothingUtils.NormalizeName(name)

    LoothingUtils.RemoveValue(members, normalized)
    self:SetCouncilMembers(members)
end

--- Get auto-include officers setting
-- @return boolean
function LoothingSettingsMixin:GetAutoIncludeOfficers()
    return self:Get("council.autoIncludeOfficers", true)
end

--- Set auto-include officers
-- @param include boolean
function LoothingSettingsMixin:SetAutoIncludeOfficers(include)
    self:Set("council.autoIncludeOfficers", include)
end

--- Get auto-include raid leader setting
-- @return boolean
function LoothingSettingsMixin:GetAutoIncludeRaidLeader()
    return self:Get("council.autoIncludeRaidLeader", true)
end

--- Set auto-include raid leader
-- @param include boolean
function LoothingSettingsMixin:SetAutoIncludeRaidLeader(include)
    self:Set("council.autoIncludeRaidLeader", include)
end

--[[--------------------------------------------------------------------
    Announcement Settings
----------------------------------------------------------------------]]

--- Get announce awards setting
-- @return boolean
function LoothingSettingsMixin:GetAnnounceAwards()
    return self:Get("announcements.announceAwards", true)
end

--- Set announce awards
-- @param announce boolean
function LoothingSettingsMixin:SetAnnounceAwards(announce)
    self:Set("announcements.announceAwards", announce)
end

--- Get announce items setting
-- @return boolean
function LoothingSettingsMixin:GetAnnounceItems()
    return self:Get("announcements.announceItems", true)
end

--- Set announce items
-- @param announce boolean
function LoothingSettingsMixin:SetAnnounceItems(announce)
    self:Set("announcements.announceItems", announce)
end

--- Get announce boss kill setting
-- @return boolean
function LoothingSettingsMixin:GetAnnounceBossKill()
    return self:Get("announcements.announceBossKill", false)
end

--- Set announce boss kill
-- @param announce boolean
function LoothingSettingsMixin:SetAnnounceBossKill(announce)
    self:Set("announcements.announceBossKill", announce)
end

--- Get award channel
-- @return string - "RAID", "RAID_WARNING", "OFFICER", "GUILD", "PARTY", "NONE"
function LoothingSettingsMixin:GetAwardChannel()
    return self:Get("announcements.awardChannel", "RAID")
end

--- Set award channel
-- @param channel string
function LoothingSettingsMixin:SetAwardChannel(channel)
    self:Set("announcements.awardChannel", channel)
end

--- Get award channel secondary
-- @return string - "RAID", "RAID_WARNING", "OFFICER", "GUILD", "PARTY", "NONE"
function LoothingSettingsMixin:GetAwardChannelSecondary()
    return self:Get("announcements.awardChannelSecondary", "NONE")
end

--- Set award channel secondary
-- @param channel string
function LoothingSettingsMixin:SetAwardChannelSecondary(channel)
    self:Set("announcements.awardChannelSecondary", channel)
end

--- Get award text template
-- @return string
function LoothingSettingsMixin:GetAwardText()
    return self:Get("announcements.awardText", "{item} awarded to {winner} for {reason}")
end

--- Set award text template
-- @param text string
function LoothingSettingsMixin:SetAwardText(text)
    self:Set("announcements.awardText", text)
end

--- Get item channel
-- @return string
function LoothingSettingsMixin:GetItemChannel()
    return self:Get("announcements.itemChannel", "RAID")
end

--- Set item channel
-- @param channel string
function LoothingSettingsMixin:SetItemChannel(channel)
    self:Set("announcements.itemChannel", channel)
end

--- Get item text template
-- @return string
function LoothingSettingsMixin:GetItemText()
    return self:Get("announcements.itemText", "Now accepting rolls for {item}")
end

--- Set item text template
-- @param text string
function LoothingSettingsMixin:SetItemText(text)
    self:Set("announcements.itemText", text)
end

--- Get session start text
-- @return string
function LoothingSettingsMixin:GetSessionStartText()
    return self:Get("announcements.sessionStartText", "Loot council session started")
end

--- Set session start text
-- @param text string
function LoothingSettingsMixin:SetSessionStartText(text)
    self:Set("announcements.sessionStartText", text)
end

--- Get session end text
-- @return string
function LoothingSettingsMixin:GetSessionEndText()
    return self:Get("announcements.sessionEndText", "Loot council session ended")
end

--- Set session end text
-- @param text string
function LoothingSettingsMixin:SetSessionEndText(text)
    self:Set("announcements.sessionEndText", text)
end

--[[--------------------------------------------------------------------
    Multi-Line Announcements
----------------------------------------------------------------------]]

--- Get all award announcement lines
-- @return table - Array of { enabled, channel, text } (copy)
function LoothingSettingsMixin:GetAwardLines()
    local defaults = Loothing.DefaultSettings.announcements.awardLines
    local lines = self:Get("announcements.awardLines", defaults)
    return LoothingUtils.DeepCopy(lines)
end

--- Set award announcement lines
-- @param lines table - Array of { enabled, channel, text }
function LoothingSettingsMixin:SetAwardLines(lines)
    self:Set("announcements.awardLines", lines)
end

--- Get a specific award announcement line
-- @param index number - Line index (1-5)
-- @return table|nil - { enabled, channel, text }
function LoothingSettingsMixin:GetAwardLine(index)
    local lines = self:GetAwardLines()
    return lines and lines[index]
end

--- Set a specific award announcement line
-- @param index number - Line index (1-5)
-- @param enabled boolean
-- @param channel string
-- @param text string
function LoothingSettingsMixin:SetAwardLine(index, enabled, channel, text)
    local lines = self:GetAwardLines()
    if lines and index >= 1 and index <= 5 then
        lines[index] = { enabled = enabled, channel = channel, text = text }
        self:Set("announcements.awardLines", lines)
    end
end

--- Get all item announcement lines
-- @return table - Array of { enabled, channel, text } (copy)
function LoothingSettingsMixin:GetItemLines()
    local defaults = Loothing.DefaultSettings.announcements.itemLines
    local lines = self:Get("announcements.itemLines", defaults)
    return LoothingUtils.DeepCopy(lines)
end

--- Set item announcement lines
-- @param lines table - Array of { enabled, channel, text }
function LoothingSettingsMixin:SetItemLines(lines)
    self:Set("announcements.itemLines", lines)
end

--- Get a specific item announcement line
-- @param index number - Line index (1-5)
-- @return table|nil - { enabled, channel, text }
function LoothingSettingsMixin:GetItemLine(index)
    local lines = self:GetItemLines()
    return lines and lines[index]
end

--- Set a specific item announcement line
-- @param index number - Line index (1-5)
-- @param enabled boolean
-- @param channel string
-- @param text string
function LoothingSettingsMixin:SetItemLine(index, enabled, channel, text)
    local lines = self:GetItemLines()
    if lines and index >= 1 and index <= 5 then
        lines[index] = { enabled = enabled, channel = channel, text = text }
        self:Set("announcements.itemLines", lines)
    end
end

--- Get announce considerations setting
-- @return boolean
function LoothingSettingsMixin:GetAnnounceConsiderations()
    return self:Get("announcements.announceConsiderations") == true
end

--- Set announce considerations setting
-- @param enabled boolean
function LoothingSettingsMixin:SetAnnounceConsiderations(enabled)
    self:Set("announcements.announceConsiderations", enabled)
end

--- Get considerations channel
-- @return string
function LoothingSettingsMixin:GetConsiderationsChannel()
    return self:Get("announcements.considerationsChannel", "RAID")
end

--- Set considerations channel
-- @param channel string
function LoothingSettingsMixin:SetConsiderationsChannel(channel)
    self:Set("announcements.considerationsChannel", channel)
end

--- Get considerations text
-- @return string
function LoothingSettingsMixin:GetConsiderationsText()
    return self:Get("announcements.considerationsText", "{ml} is considering {item} for distribution")
end

--- Set considerations text
-- @param text string
function LoothingSettingsMixin:SetConsiderationsText(text)
    self:Set("announcements.considerationsText", text)
end

--- Get session start channel
-- @return string
function LoothingSettingsMixin:GetSessionStartChannel()
    return self:Get("announcements.sessionStartChannel", "RAID")
end

--- Set session start channel
-- @param channel string
function LoothingSettingsMixin:SetSessionStartChannel(channel)
    self:Set("announcements.sessionStartChannel", channel)
end

--- Get session end channel
-- @return string
function LoothingSettingsMixin:GetSessionEndChannel()
    return self:Get("announcements.sessionEndChannel", "RAID")
end

--- Set session end channel
-- @param channel string
function LoothingSettingsMixin:SetSessionEndChannel(channel)
    self:Set("announcements.sessionEndChannel", channel)
end

-- Legacy compatibility - kept for backward compatibility
--- Get announce channel (deprecated - use GetAwardChannel)
-- @return string
function LoothingSettingsMixin:GetAnnounceChannel()
    return self:GetAwardChannel()
end

--- Set announce channel (deprecated - use SetAwardChannel)
-- @param channel string
function LoothingSettingsMixin:SetAnnounceChannel(channel)
    self:SetAwardChannel(channel)
end

--[[--------------------------------------------------------------------
    History Access
----------------------------------------------------------------------]]

--- Get loot history (from global scope - persists across profiles)
-- @return table - Array of history entries (copy)
function LoothingSettingsMixin:GetHistory()
    local history = self:GetGlobalValue("history", {})
    return LoothingUtils.DeepCopy(history)
end

--- Get the live shared history table.
-- @return table
function LoothingSettingsMixin:GetHistoryRef()
    local history = self.global.history
    if not history then
        history = {}
        self.global.history = history
    end
    return history
end

--- Add history entry (to global scope)
-- @param entry table - History entry
function LoothingSettingsMixin:AddHistoryEntry(entry)
    local history = self:GetHistoryRef()
    history[#history + 1] = entry
end

--- Remove a history entry by GUID from the live shared history table.
-- @param guid string
-- @return boolean
function LoothingSettingsMixin:RemoveHistoryEntry(guid)
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
function LoothingSettingsMixin:RemoveHistoryEntries(guidSet)
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
function LoothingSettingsMixin:GetHistoryMaxEntries()
    return tonumber(self:Get("historySettings.maxEntries", Loothing.DefaultSettings.historySettings.maxEntries)) or 500
end

--- Prune oldest history entries to fit the configured cap.
-- @param maxEntries number|nil
-- @return table
function LoothingSettingsMixin:PruneHistory(maxEntries)
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
function LoothingSettingsMixin:ClearHistory()
    self:SetGlobalValue("history", {})
end

--[[--------------------------------------------------------------------
    Auto-Pass Settings
----------------------------------------------------------------------]]

--- Get auto-pass enabled setting
-- @return boolean
function LoothingSettingsMixin:GetAutoPassEnabled()
    return self:Get("autoPass.enabled") ~= false
end

--- Set auto-pass enabled
-- @param enabled boolean
function LoothingSettingsMixin:SetAutoPassEnabled(enabled)
    self:Set("autoPass.enabled", enabled)
end

--- Get auto-pass weapons setting
-- @return boolean
function LoothingSettingsMixin:GetAutoPassWeapons()
    return self:Get("autoPass.weapons") ~= false
end

--- Set auto-pass weapons
-- @param enabled boolean
function LoothingSettingsMixin:SetAutoPassWeapons(enabled)
    self:Set("autoPass.weapons", enabled)
end

--- Get auto-pass BoE setting
-- @return boolean
function LoothingSettingsMixin:GetAutoPassBoE()
    return self:Get("autoPass.boe") == true
end

--- Set auto-pass BoE
-- @param enabled boolean
function LoothingSettingsMixin:SetAutoPassBoE(enabled)
    self:Set("autoPass.boe", enabled)
end

--- Get auto-pass transmog setting
-- @return boolean
function LoothingSettingsMixin:GetAutoPassTransmog()
    return self:Get("autoPass.transmog") == true
end

--- Set auto-pass transmog
-- @param enabled boolean
function LoothingSettingsMixin:SetAutoPassTransmog(enabled)
    self:Set("autoPass.transmog", enabled)
end

--[[--------------------------------------------------------------------
    Auto-Trade Settings
----------------------------------------------------------------------]]

--- Get auto-trade enabled setting
-- @return boolean
function LoothingSettingsMixin:GetAutoTrade()
    return self:Get("settings.autoTrade") ~= false
end

--- Set auto-trade enabled
-- @param enabled boolean
function LoothingSettingsMixin:SetAutoTrade(enabled)
    self:Set("settings.autoTrade", enabled)
end

--[[--------------------------------------------------------------------
    Group Loot Settings
----------------------------------------------------------------------]]

--- Get group loot auto-roll enabled setting
-- @return boolean
function LoothingSettingsMixin:GetGroupLootEnabled()
    return self:Get("groupLoot.enabled") ~= false
end

--- Set group loot auto-roll enabled
-- @param enabled boolean
function LoothingSettingsMixin:SetGroupLootEnabled(enabled)
    self:Set("groupLoot.enabled", enabled)
end

--- Get group loot hide frames setting
-- @return boolean
function LoothingSettingsMixin:GetGroupLootHideFrames()
    return self:Get("groupLoot.hideFrames") ~= false
end

--- Set group loot hide frames
-- @param hide boolean
function LoothingSettingsMixin:SetGroupLootHideFrames(hide)
    self:Set("groupLoot.hideFrames", hide)
end

--- Get group loot quality threshold
-- @return number - Minimum item quality for auto-roll (default: Epic = 4)
function LoothingSettingsMixin:GetGroupLootQualityThreshold()
    return self:Get("groupLoot.qualityThreshold", Enum.ItemQuality.Epic)
end

--- Set group loot quality threshold
-- @param quality number - Minimum item quality (0-7)
function LoothingSettingsMixin:SetGroupLootQualityThreshold(quality)
    quality = math.max(0, math.min(7, quality))
    self:Set("groupLoot.qualityThreshold", quality)
end

--[[--------------------------------------------------------------------
    Auto-Award Settings
----------------------------------------------------------------------]]

--- Get auto-award enabled setting
-- @return boolean
function LoothingSettingsMixin:GetAutoAwardEnabled()
    return self:Get("autoAward.enabled") == true
end

--- Set auto-award enabled
-- @param enabled boolean
function LoothingSettingsMixin:SetAutoAwardEnabled(enabled)
    self:Set("autoAward.enabled", enabled)
end

--- Get auto-award quality thresholds
-- @return number, number - Lower threshold, upper threshold
function LoothingSettingsMixin:GetAutoAwardThresholds()
    local lower = self:Get("autoAward.lowerThreshold", 2)
    local upper = self:Get("autoAward.upperThreshold", 4)
    return lower, upper
end

--- Set auto-award quality thresholds
-- @param lower number - Lower threshold (0-7)
-- @param upper number - Upper threshold (0-7)
function LoothingSettingsMixin:SetAutoAwardThresholds(lower, upper)
    self:Set("autoAward.lowerThreshold", lower)
    self:Set("autoAward.upperThreshold", upper)
end

--- Get auto-award target player name
-- @return string
function LoothingSettingsMixin:GetAutoAwardTo()
    return self:Get("autoAward.awardTo", "")
end

--- Set auto-award target player name
-- @param name string
function LoothingSettingsMixin:SetAutoAwardTo(name)
    self:Set("autoAward.awardTo", name)
end

--- Get auto-award reason
-- @return string
function LoothingSettingsMixin:GetAutoAwardReason()
    return self:Get("autoAward.reason", "Auto Award")
end

--- Set auto-award reason
-- @param reason string
function LoothingSettingsMixin:SetAutoAwardReason(reason)
    self:Set("autoAward.reason", reason)
end

--- Get auto-award include BoE setting
-- @return boolean
function LoothingSettingsMixin:GetAutoAwardIncludeBoE()
    return self:Get("autoAward.includeBoE") == true
end

--- Set auto-award include BoE
-- @param include boolean
function LoothingSettingsMixin:SetAutoAwardIncludeBoE(include)
    self:Set("autoAward.includeBoE", include)
end

--[[--------------------------------------------------------------------
    Ignore Items Settings
----------------------------------------------------------------------]]

--- Get ignore items enabled setting
-- @return boolean
function LoothingSettingsMixin:GetIgnoreItemsEnabled()
    return self:Get("ignoreItems.enabled") ~= false
end

--- Set ignore items enabled
-- @param enabled boolean
function LoothingSettingsMixin:SetIgnoreItemsEnabled(enabled)
    self:Set("ignoreItems.enabled", enabled)
end

--- Check if an item is ignored
-- @param itemID number - Item ID to check
-- @return boolean - True if item should be ignored
function LoothingSettingsMixin:IsItemIgnored(itemID)
    if not self:GetIgnoreItemsEnabled() then
        return false
    end

    local items = self:Get("ignoreItems.items", {})
    return items[itemID] == true
end

--- Add item to ignore list
-- @param itemID number - Item ID to ignore
function LoothingSettingsMixin:AddIgnoredItem(itemID)
    if not itemID then return end

    local items = self:Get("ignoreItems.items", {})
    items[itemID] = true
    self:Set("ignoreItems.items", items)
end

--- Remove item from ignore list
-- @param itemID number - Item ID to unignore
function LoothingSettingsMixin:RemoveIgnoredItem(itemID)
    if not itemID then return end

    local items = self:Get("ignoreItems.items", {})
    items[itemID] = nil
    self:Set("ignoreItems.items", items)
end

--- Get all ignored items
-- @return table - Table of itemID => true (copy)
function LoothingSettingsMixin:GetIgnoredItems()
    local items = self:Get("ignoreItems.items", {})
    return LoothingUtils.DeepCopy(items)
end

--- Clear all ignored items
function LoothingSettingsMixin:ClearIgnoredItems()
    self:Set("ignoreItems.items", {})
end

--- Get ignore enchanting materials setting
-- @return boolean
function LoothingSettingsMixin:GetIgnoreEnchantingMaterials()
    return self:Get("ignoreItems.ignoreEnchantingMaterials") ~= false
end

--- Set ignore enchanting materials
-- @param enabled boolean
function LoothingSettingsMixin:SetIgnoreEnchantingMaterials(enabled)
    self:Set("ignoreItems.ignoreEnchantingMaterials", enabled)
end

--- Get ignore crafting reagents setting
-- @return boolean
function LoothingSettingsMixin:GetIgnoreCraftingReagents()
    return self:Get("ignoreItems.ignoreCraftingReagents") ~= false
end

--- Set ignore crafting reagents
-- @param enabled boolean
function LoothingSettingsMixin:SetIgnoreCraftingReagents(enabled)
    self:Set("ignoreItems.ignoreCraftingReagents", enabled)
end

--- Get ignore consumables setting
-- @return boolean
function LoothingSettingsMixin:GetIgnoreConsumables()
    return self:Get("ignoreItems.ignoreConsumables") ~= false
end

--- Set ignore consumables
-- @param enabled boolean
function LoothingSettingsMixin:SetIgnoreConsumables(enabled)
    self:Set("ignoreItems.ignoreConsumables", enabled)
end

--- Get ignore permanent enhancements setting
-- @return boolean
function LoothingSettingsMixin:GetIgnorePermanentEnhancements()
    return self:Get("ignoreItems.ignorePermanentEnhancements") == true
end

--- Set ignore permanent enhancements
-- @param enabled boolean
function LoothingSettingsMixin:SetIgnorePermanentEnhancements(enabled)
    self:Set("ignoreItems.ignorePermanentEnhancements", enabled)
end

--[[--------------------------------------------------------------------
    Voting Options Settings
----------------------------------------------------------------------]]

--- Get self-vote setting
-- @return boolean
function LoothingSettingsMixin:GetSelfVote()
    return self:Get("voting.selfVote", false)
end

--- Set self-vote setting
-- @param enabled boolean
function LoothingSettingsMixin:SetSelfVote(enabled)
    self:Set("voting.selfVote", enabled)
end

--- Get multi-vote setting
-- @return boolean
function LoothingSettingsMixin:GetMultiVote()
    return self:Get("voting.multiVote", false)
end

--- Set multi-vote setting
-- @param enabled boolean
function LoothingSettingsMixin:SetMultiVote(enabled)
    self:Set("voting.multiVote", enabled)
end

--- Get anonymous voting setting
-- @return boolean
function LoothingSettingsMixin:GetAnonymousVoting()
    return self:Get("voting.anonymousVoting", false)
end

--- Set anonymous voting setting
-- @param enabled boolean
function LoothingSettingsMixin:SetAnonymousVoting(enabled)
    self:Set("voting.anonymousVoting", enabled)
end

--- Get hide votes setting
-- @return boolean
function LoothingSettingsMixin:GetHideVotes()
    return self:Get("voting.hideVotes", false)
end

--- Set hide votes setting
-- @param enabled boolean
function LoothingSettingsMixin:SetHideVotes(enabled)
    self:Set("voting.hideVotes", enabled)
end

--- Get observe mode setting (DEPRECATED - redirects to GetOpenObservation)
-- @return boolean
function LoothingSettingsMixin:GetObserveMode()
    return self:GetOpenObservation()
end

--- Set observe mode setting (DEPRECATED - redirects to SetOpenObservation)
-- @param enabled boolean
function LoothingSettingsMixin:SetObserveMode(enabled)
    self:SetOpenObservation(enabled)
end

-- Observer settings
function LoothingSettingsMixin:GetObserverList()
    return self:Get("observers.list", {})
end
function LoothingSettingsMixin:SetObserverList(list)
    self:Set("observers.list", list)
end

function LoothingSettingsMixin:GetOpenObservation()
    return self:Get("observers.openObservation", false)
end
function LoothingSettingsMixin:SetOpenObservation(enabled)
    self:Set("observers.openObservation", enabled == true)
    -- Keep old voting.observe in sync for backward compat
    self:Set("voting.observe", enabled == true)
end

function LoothingSettingsMixin:GetMLIsObserver()
    return self:Get("observers.mlIsObserver", false)
end
function LoothingSettingsMixin:SetMLIsObserver(enabled)
    self:Set("observers.mlIsObserver", enabled == true)
end

function LoothingSettingsMixin:GetObserverPermissions()
    return self:Get("observers.permissions", {
        seeVoteCounts = true,
        seeVoterIdentities = false,
        seeResponses = true,
        seeNotes = false,
    })
end
function LoothingSettingsMixin:SetObserverPermission(key, enabled)
    local perms = self:GetObserverPermissions()
    perms[key] = enabled == true
    self:Set("observers.permissions", perms)
end

--- Get auto-add rolls setting
-- @return boolean
function LoothingSettingsMixin:GetAutoAddRolls()
    return self:Get("voting.autoAddRolls", true)
end

--- Set auto-add rolls setting
-- @param enabled boolean
function LoothingSettingsMixin:SetAutoAddRolls(enabled)
    self:Set("voting.autoAddRolls", enabled)
end

--- Get require notes setting
-- @return boolean
function LoothingSettingsMixin:GetRequireNotes()
    return self:Get("voting.requireNotes", false)
end

--- Set require notes setting
-- @param enabled boolean
function LoothingSettingsMixin:SetRequireNotes(enabled)
    self:Set("voting.requireNotes", enabled)
end

--- Get number of buttons setting
-- @return number
function LoothingSettingsMixin:GetNumButtons()
    local num = self:Get("voting.numButtons", 5)
    return math.max(1, math.min(10, num))
end

--- Set number of buttons setting
-- @param num number (1-10)
function LoothingSettingsMixin:SetNumButtons(num)
    num = math.max(1, math.min(10, num))
    self:Set("voting.numButtons", num)
end

--[[--------------------------------------------------------------------
    Award Reasons Settings
----------------------------------------------------------------------]]

--- Get award reasons enabled setting
-- @return boolean
function LoothingSettingsMixin:GetAwardReasonsEnabled()
    return self:Get("awardReasons.enabled") ~= false
end

--- Set award reasons enabled
-- @param enabled boolean
function LoothingSettingsMixin:SetAwardReasonsEnabled(enabled)
    self:Set("awardReasons.enabled", enabled)
end

--- Get require award reason setting
-- @return boolean
function LoothingSettingsMixin:GetRequireAwardReason()
    return self:Get("awardReasons.requireReason") == true
end

--- Set require award reason
-- @param require boolean
function LoothingSettingsMixin:SetRequireAwardReason(require)
    self:Set("awardReasons.requireReason", require)
end

--- Get all award reasons
-- @return table - Array of award reason entries (copy)
function LoothingSettingsMixin:GetAwardReasons()
    local defaults = Loothing.DefaultSettings.awardReasons.reasons
    local reasons = self:Get("awardReasons.reasons", defaults)
    return LoothingUtils.DeepCopy(reasons)
end

--- Get award reason by ID
-- @param id number - Reason ID
-- @return table|nil - Award reason entry { id, name, color }
function LoothingSettingsMixin:GetAwardReasonById(id)
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
function LoothingSettingsMixin:AddAwardReason(name, color)
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
function LoothingSettingsMixin:RemoveAwardReason(id)
    local reasons = self:GetAwardReasons()
    
    for i, reason in ipairs(reasons) do
        if reason.id == id then
            table.remove(reasons, i)
            self:Set("awardReasons.reasons", reasons)
            return true
        end
    end
    
    return false
end

--- Update an award reason
-- @param id number - Reason ID
-- @param name string - New name (optional)
-- @param color table - New color (optional)
-- @return boolean - True if updated
function LoothingSettingsMixin:UpdateAwardReason(id, name, color)
    local reasons = self:GetAwardReasons()
    
    for i, reason in ipairs(reasons) do
        if reason.id == id then
            if name then
                reason.name = name
            end
            if color then
                reason.color = color
            end
            self:Set("awardReasons.reasons", reasons)
            return true
        end
    end
    
    return false
end

--- Reset award reasons to defaults
function LoothingSettingsMixin:ResetAwardReasons()
    local defaults = LoothingUtils.DeepCopy(Loothing.DefaultSettings.awardReasons.reasons)
    self:Set("awardReasons.reasons", defaults)
end

--- Get number of active award reasons
-- @return number - Number of active reasons (1-20)
function LoothingSettingsMixin:GetNumAwardReasons()
    local num = self:Get("awardReasons.numReasons", 6)
    return math.max(1, math.min(20, num))
end

--- Set number of active award reasons
-- @param num number - Number of active reasons (clamped to 1-20)
function LoothingSettingsMixin:SetNumAwardReasons(num)
    num = math.max(1, math.min(20, num))
    self:Set("awardReasons.numReasons", num)
end

--- Get award reason log setting
-- @param id number - Reason ID
-- @return boolean - Whether this reason should be logged
function LoothingSettingsMixin:GetAwardReasonLog(id)
    local reason = self:GetAwardReasonById(id)
    if reason then
        return reason.log ~= false  -- Default to true if not set
    end
    return true
end

--- Set award reason log setting
-- @param id number - Reason ID
-- @param enabled boolean - Whether to log awards with this reason
function LoothingSettingsMixin:SetAwardReasonLog(id, enabled)
    local reasons = self:GetAwardReasons()
    for i, reason in ipairs(reasons) do
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
function LoothingSettingsMixin:GetAwardReasonDisenchant(id)
    local reason = self:GetAwardReasonById(id)
    if reason then
        return reason.disenchant == true
    end
    return false
end

--- Set award reason disenchant setting
-- @param id number - Reason ID
-- @param enabled boolean - Whether to treat awards with this reason as disenchant
function LoothingSettingsMixin:SetAwardReasonDisenchant(id, enabled)
    local reasons = self:GetAwardReasons()
    for i, reason in ipairs(reasons) do
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
function LoothingSettingsMixin:ReorderAwardReason(id, direction)
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
function LoothingSettingsMixin:ResetAwardReasonsToDefaults()
    local defaults = LoothingUtils.DeepCopy(Loothing.DefaultSettings.awardReasons)
    self:Set("awardReasons", defaults)
end

--[[--------------------------------------------------------------------
    Button Sets Settings
----------------------------------------------------------------------]]

--- Get active button set ID
-- @return number - Active set ID
function LoothingSettingsMixin:GetActiveButtonSet()
    return self:Get("buttonSets.activeSet", 1)
end

--- Set active button set
-- @param setId number - Button set ID
function LoothingSettingsMixin:SetActiveButtonSet(setId)
    local sets = self:GetButtonSets()
    if sets[setId] then
        self:Set("buttonSets.activeSet", setId)
    end
end

--- Get all button sets
-- @return table - Table of button sets indexed by ID (copy)
function LoothingSettingsMixin:GetButtonSets()
    local defaults = Loothing.DefaultSettings.buttonSets.sets
    local sets = self:Get("buttonSets.sets", defaults)
    return LoothingUtils.DeepCopy(sets)
end

--- Get specific button set by ID
-- @param setId number - Button set ID
-- @return table|nil - Button set data
function LoothingSettingsMixin:GetButtonSet(setId)
    local sets = self:GetButtonSets()
    return sets[setId]
end

--- Add a new button set
-- @param name string - Set name
-- @return number - New set ID
function LoothingSettingsMixin:AddButtonSet(name)
    local sets = self:GetButtonSets()

    -- Find next available ID
    local maxId = 0
    for id, _ in pairs(sets) do
        if id > maxId then
            maxId = id
        end
    end

    local newId = maxId + 1
    sets[newId] = {
        name = name,
        buttons = {
            { id = 1, text = "Need", color = { 0.0, 1.0, 0.0, 1.0 }, sort = 1 },
            { id = 2, text = "Pass", color = { 0.5, 0.5, 0.5, 1.0 }, sort = 2 },
        },
        whisperKey = "!vote",
    }

    self:Set("buttonSets.sets", sets)
    return newId
end

--- Remove a button set
-- @param setId number - Button set ID to remove
-- @return boolean - True if removed
function LoothingSettingsMixin:RemoveButtonSet(setId)
    if setId == 1 then
        return false  -- Cannot remove default set
    end

    local sets = self:GetButtonSets()
    if sets[setId] then
        sets[setId] = nil
        self:Set("buttonSets.sets", sets)

        -- If this was the active set, switch to default
        if self:GetActiveButtonSet() == setId then
            self:SetActiveButtonSet(1)
        end

        return true
    end

    return false
end

--- Update button set data
-- @param setId number - Button set ID
-- @param data table - Updated set data
-- @return boolean - True if updated
function LoothingSettingsMixin:UpdateButtonSet(setId, data)
    local sets = self:GetButtonSets()
    if sets[setId] then
        for key, value in pairs(data) do
            sets[setId][key] = value
        end
        self:Set("buttonSets.sets", sets)
        return true
    end
    return false
end

--- Get buttons from active set
-- @return table - Array of button data (copy)
function LoothingSettingsMixin:GetButtons()
    local activeSet = self:GetActiveButtonSet()
    local set = self:GetButtonSet(activeSet)
    if set and set.buttons then
        return LoothingUtils.DeepCopy(set.buttons)
    end
    return {}
end

--- Add a button to a set
-- @param setId number - Button set ID
-- @param text string - Button text
-- @param color table - Color as { r, g, b, a }
-- @return number|nil - New button ID
function LoothingSettingsMixin:AddButton(setId, text, color)
    local set = self:GetButtonSet(setId)
    if not set then return nil end

    local buttons = set.buttons or {}

    -- Check max buttons
    if #buttons >= 10 then
        return nil
    end

    -- Find next available ID
    local maxId = 0
    for _, button in ipairs(buttons) do
        if button.id > maxId then
            maxId = button.id
        end
    end

    local newButton = {
        id = maxId + 1,
        text = text,
        color = color or { 1.0, 1.0, 1.0, 1.0 },
        sort = #buttons + 1,
    }

    buttons[#buttons + 1] = newButton
    set.buttons = buttons

    self:UpdateButtonSet(setId, set)
    return newButton.id
end

--- Remove a button from a set
-- @param setId number - Button set ID
-- @param buttonId number - Button ID to remove
-- @return boolean - True if removed
function LoothingSettingsMixin:RemoveButton(setId, buttonId)
    local set = self:GetButtonSet(setId)
    if not set then return false end

    local buttons = set.buttons or {}

    -- Require at least 1 button
    if #buttons <= 1 then
        return false
    end

    for i, button in ipairs(buttons) do
        if button.id == buttonId then
            table.remove(buttons, i)
            -- Re-sort remaining buttons
            for j, btn in ipairs(buttons) do
                btn.sort = j
            end
            set.buttons = buttons
            self:UpdateButtonSet(setId, set)
            return true
        end
    end

    return false
end

--- Update button data
-- @param setId number - Button set ID
-- @param buttonId number - Button ID
-- @param data table - Updated button data
-- @return boolean - True if updated
function LoothingSettingsMixin:UpdateButton(setId, buttonId, data)
    local set = self:GetButtonSet(setId)
    if not set then return false end

    local buttons = set.buttons or {}

    for i, button in ipairs(buttons) do
        if button.id == buttonId then
            for key, value in pairs(data) do
                button[key] = value
            end
            set.buttons = buttons
            self:UpdateButtonSet(setId, set)
            return true
        end
    end

    return false
end

--- Get whisper key for a set
-- @param setId number - Button set ID
-- @return string - Whisper key
function LoothingSettingsMixin:GetWhisperKey(setId)
    local set = self:GetButtonSet(setId)
    if set then
        return set.whisperKey or "!vote"
    end
    return "!vote"
end

--- Set whisper key for a set
-- @param setId number - Button set ID
-- @param key string - Whisper key
function LoothingSettingsMixin:SetWhisperKey(setId, key)
    local set = self:GetButtonSet(setId)
    if set then
        set.whisperKey = key
        self:UpdateButtonSet(setId, set)
    end
end

--[[--------------------------------------------------------------------
    Response Sets Settings (unified model)
----------------------------------------------------------------------]]

local function GetDefaultResponseSetTemplate(setId)
    local defaults = Loothing.DefaultSettings.responseSets and Loothing.DefaultSettings.responseSets.sets or {}
    return defaults[setId] or defaults[1] or { name = "Default", buttons = {} }
end

local function NormalizeResponseColor(color, fallback)
    return LoothingUtils.ColorToArray(color or fallback or { 1, 1, 1, 1 })
end

local function NormalizeResponseWhisperKeys(keys, fallback)
    if type(keys) == "table" then
        return LoothingUtils.DeepCopy(keys)
    end
    if type(fallback) == "table" then
        return LoothingUtils.DeepCopy(fallback)
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
        if type(btn) == "table" and btn.requireNotes ~= nil then
            normalized.requireNotes = btn.requireNotes == true
        elseif defaultBtn then
            normalized.requireNotes = defaultBtn.requireNotes == true
        else
            normalized.requireNotes = false
        end

        buttons[i] = normalized
    end

    return {
        name = (type(setData) == "table" and setData.name) or defaultSet.name or ("Set " .. tostring(setId)),
        buttons = buttons,
    }
end

function LoothingSettingsMixin:NormalizeResponseSets(data)
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
function LoothingSettingsMixin:GetResponseSets()
    local stored = self:Get("responseSets", nil)
    local normalized = self:NormalizeResponseSets(stored)

    if ResponseSetsNeedRepair(stored, normalized) then
        self:Set("responseSets", LoothingUtils.DeepCopy(normalized))
    end

    return LoothingUtils.DeepCopy(normalized)
end

--- Get active response set ID
-- @return number
function LoothingSettingsMixin:GetActiveResponseSet()
    return self:Get("responseSets.activeSet", 1)
end

--- Set active response set
-- @param id number
function LoothingSettingsMixin:SetActiveResponseSet(id)
    local rs = self:GetResponseSets()
    if rs.sets and rs.sets[id] then
        self:Set("responseSets.activeSet", id)
    end
end

--- Get a response set by ID
-- @param id number
-- @return table|nil
function LoothingSettingsMixin:GetResponseSetById(id)
    local rs = self:GetResponseSets()
    return rs.sets and rs.sets[id]
end

--- Get buttons for the active set, or a specific set
-- @param setId number|nil - If nil, uses active set
-- @return table - Array of button data
function LoothingSettingsMixin:GetResponseButtons(setId)
    local id = setId or self:GetActiveResponseSet()
    local set = self:GetResponseSetById(id)
    if set and set.buttons then
        return LoothingUtils.DeepCopy(set.buttons)
    end
    return {}
end

--- Add a new response set
-- @param name string
-- @param buttons table|nil - Initial buttons (uses default response template if nil)
-- @return number - New set ID
function LoothingSettingsMixin:AddResponseSet(name, buttons)
    local rs = self:GetResponseSets()
    if not rs.sets then rs.sets = {} end

    local maxId = 0
    for id in pairs(rs.sets) do
        if id > maxId then maxId = id end
    end

    local newId = maxId + 1
    rs.sets[newId] = {
        name = name,
        buttons = buttons or LoothingUtils.DeepCopy(GetDefaultResponseSetTemplate(1).buttons),
    }
    self:Set("responseSets", self:NormalizeResponseSets(rs))
    return newId
end

--- Remove a response set (cannot remove set 1)
-- @param id number
-- @return boolean
function LoothingSettingsMixin:RemoveResponseSet(id)
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
function LoothingSettingsMixin:UpdateResponseSet(id, data)
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
-- @param data table - Button fields (text, responseText, color, icon, whisperKeys, requireNotes)
-- @return number|nil - New button ID
function LoothingSettingsMixin:AddResponseButton(setId, data)
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
        requireNotes = data.requireNotes or false,
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
function LoothingSettingsMixin:RemoveResponseButton(setId, btnId)
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
function LoothingSettingsMixin:UpdateResponseButton(setId, btnId, data)
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
function LoothingSettingsMixin:ReorderResponseButton(setId, btnId, newSort)
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
function LoothingSettingsMixin:GetTypeCodeMap()
    local rs = self:GetResponseSets()
    return rs.typeCodeMap or {}
end

--- Assign a button set to a type code
-- @param typeCode string
-- @param setId number
function LoothingSettingsMixin:SetTypeCodeForSet(typeCode, setId)
    local rs = self:GetResponseSets()
    if not rs.typeCodeMap then rs.typeCodeMap = {} end
    rs.typeCodeMap[typeCode] = setId
    self:Set("responseSets", rs)
end

--- Clear a type-code override so it falls back to the default mapping or active set
-- @param typeCode string
function LoothingSettingsMixin:ClearTypeCodeForSet(typeCode)
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
function LoothingSettingsMixin:GetFiltersEnabled()
    return self:Get("filters.enabled") ~= false
end

--- Set filters enabled
-- @param enabled boolean
function LoothingSettingsMixin:SetFiltersEnabled(enabled)
    self:Set("filters.enabled", enabled)
end

--- Get class filters
-- @return table - Table of class names to show (empty = all) (copy)
function LoothingSettingsMixin:GetClassFilters()
    local filters = self:Get("filters.byClass", {})
    return LoothingUtils.DeepCopy(filters)
end

--- Set class filters
-- @param classes table - Table of class names to show
function LoothingSettingsMixin:SetClassFilters(classes)
    self:Set("filters.byClass", classes)
end

--- Add a class to the filter
-- @param class string - Class file name (e.g., "WARRIOR")
function LoothingSettingsMixin:AddClassFilter(class)
    if not class then return end

    local filters = self:GetClassFilters()
    filters[class] = true
    self:SetClassFilters(filters)
end

--- Remove a class from the filter
-- @param class string - Class file name
function LoothingSettingsMixin:RemoveClassFilter(class)
    if not class then return end

    local filters = self:GetClassFilters()
    filters[class] = nil
    self:SetClassFilters(filters)
end

--- Get response filters
-- @return table - Table of response IDs to show (empty = all) (copy)
function LoothingSettingsMixin:GetResponseFilters()
    local filters = self:Get("filters.byResponse", {})
    return LoothingUtils.DeepCopy(filters)
end

--- Set response filters
-- @param responses table - Table of response IDs to show
function LoothingSettingsMixin:SetResponseFilters(responses)
    self:Set("filters.byResponse", responses)
end

--- Add a response to the filter
-- @param responseId number - Response ID
function LoothingSettingsMixin:AddResponseFilter(responseId)
    if not responseId then return end

    local filters = self:GetResponseFilters()
    filters[responseId] = true
    self:SetResponseFilters(filters)
end

--- Remove a response from the filter
-- @param responseId number - Response ID
function LoothingSettingsMixin:RemoveResponseFilter(responseId)
    if not responseId then return end

    local filters = self:GetResponseFilters()
    filters[responseId] = nil
    self:SetResponseFilters(filters)
end

--- Get guild rank filters
-- @return table - Table of guild rank indices to show (empty = all) (copy)
function LoothingSettingsMixin:GetGuildRankFilters()
    local filters = self:Get("filters.byGuildRank", {})
    return LoothingUtils.DeepCopy(filters)
end

--- Set guild rank filters
-- @param ranks table - Table of guild rank indices to show
function LoothingSettingsMixin:SetGuildRankFilters(ranks)
    self:Set("filters.byGuildRank", ranks)
end

--- Add a guild rank to the filter
-- @param rank number - Guild rank index
function LoothingSettingsMixin:AddGuildRankFilter(rank)
    if not rank then return end

    local filters = self:GetGuildRankFilters()
    filters[rank] = true
    self:SetGuildRankFilters(filters)
end

--- Remove a guild rank from the filter
-- @param rank number - Guild rank index
function LoothingSettingsMixin:RemoveGuildRankFilter(rank)
    if not rank then return end

    local filters = self:GetGuildRankFilters()
    filters[rank] = nil
    self:SetGuildRankFilters(filters)
end

--- Get show only equippable setting
-- @return boolean
function LoothingSettingsMixin:GetShowOnlyEquippable()
    return self:Get("filters.showOnlyEquippable") == true
end

--- Set show only equippable
-- @param enabled boolean
function LoothingSettingsMixin:SetShowOnlyEquippable(enabled)
    self:Set("filters.showOnlyEquippable", enabled)
end

--- Get hide passed items setting
-- @return boolean
function LoothingSettingsMixin:GetHidePassedItems()
    return self:Get("filters.hidePassedItems") ~= false
end

--- Set hide passed items
-- @param enabled boolean
function LoothingSettingsMixin:SetHidePassedItems(enabled)
    self:Set("filters.hidePassedItems", enabled)
end

--- Clear all filters
function LoothingSettingsMixin:ClearAllFilters()
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
function LoothingSettingsMixin:GetColumnVisibility(columnId)
    local columns = self:Get("councilTable.columns", {})
    if columns[columnId] == nil then
        return true  -- Default to visible
    end
    return columns[columnId]
end

--- Set council table column visibility
-- @param columnId string - Column ID
-- @param visible boolean - True to show, false to hide
function LoothingSettingsMixin:SetColumnVisibility(columnId, visible)
    local columns = self:Get("councilTable.columns", {})
    columns[columnId] = visible
    self:Set("councilTable.columns", columns)
end

--- Get all council table column visibility settings
-- @return table - Table of columnId -> boolean (copy)
function LoothingSettingsMixin:GetAllColumnVisibility()
    local columns = self:Get("councilTable.columns", {})
    return LoothingUtils.DeepCopy(columns)
end

--- Reset council table columns to defaults
function LoothingSettingsMixin:ResetColumnVisibility()
    self:Set("councilTable.columns", {})
end

--- Get council table default sort column
-- @return string - Column ID
function LoothingSettingsMixin:GetCouncilTableSortColumn()
    return self:Get("councilTable.sortColumn", "response")
end

--- Set council table default sort column
-- @param columnId string - Column ID
function LoothingSettingsMixin:SetCouncilTableSortColumn(columnId)
    self:Set("councilTable.sortColumn", columnId)
end

--- Get council table sort ascending setting
-- @return boolean
function LoothingSettingsMixin:GetCouncilTableSortAscending()
    return self:Get("councilTable.sortAscending") == true
end

--- Set council table sort ascending
-- @param ascending boolean
function LoothingSettingsMixin:SetCouncilTableSortAscending(ascending)
    self:Set("councilTable.sortAscending", ascending)
end

--- Get council table sort settings
-- @return string, boolean - columnId, ascending
function LoothingSettingsMixin:GetCouncilTableSort()
    local column = self:Get("councilTable.sortColumn") or "response"
    local asc = self:Get("councilTable.sortAscending")
    if asc == nil then asc = true end
    return column, asc
end

--- Set council table sort settings
-- @param columnId string
-- @param ascending boolean
function LoothingSettingsMixin:SetCouncilTableSort(columnId, ascending)
    self:Set("councilTable.sortColumn", columnId)
    self:Set("councilTable.sortAscending", ascending)
end

--- Get council table row height
-- @return number
function LoothingSettingsMixin:GetCouncilTableRowHeight()
    return self:Get("councilTable.rowHeight") or 24
end

--[[--------------------------------------------------------------------
    Roll Frame Settings (rollFrame.*)
----------------------------------------------------------------------]]

--- Get whether RollFrame should auto-show when voting starts
-- @return boolean
function LoothingSettingsMixin:GetRollFrameAutoShow()
    local value = self:Get("rollFrame.autoShow")
    if value == nil then return true end
    return value
end

--- Set whether RollFrame should auto-show when voting starts
-- @param value boolean
function LoothingSettingsMixin:SetRollFrameAutoShow(value)
    self:Set("rollFrame.autoShow", value)
end

--- Get whether to auto-roll when submitting response
-- @return boolean
function LoothingSettingsMixin:GetAutoRollOnSubmit()
    local value = self:Get("rollFrame.autoRollOnSubmit")
    if value == nil then return false end
    return value
end

--- Set whether to auto-roll when submitting response
-- @param value boolean
function LoothingSettingsMixin:SetAutoRollOnSubmit(value)
    self:Set("rollFrame.autoRollOnSubmit", value)
end

--- Get the roll range
-- @return table { min, max } (copy)
function LoothingSettingsMixin:GetRollRange()
    local range = self:Get("rollFrame.rollRange") or { min = 1, max = 100 }
    return { min = range.min, max = range.max }
end

--- Set the roll range
-- @param min number
-- @param max number
function LoothingSettingsMixin:SetRollRange(min, max)
    self:Set("rollFrame.rollRange", { min = min, max = max })
end

--- Get whether notes are required in RollFrame
-- @return boolean
function LoothingSettingsMixin:GetRollFrameRequireNote()
    local value = self:Get("rollFrame.requireNote")
    if value == nil then return false end
    return value
end

--- Set whether notes are required in RollFrame
-- @param value boolean
function LoothingSettingsMixin:SetRollFrameRequireNote(value)
    self:Set("rollFrame.requireNote", value)
end

--- Get whether to show gear comparison in RollFrame
-- @return boolean
function LoothingSettingsMixin:GetShowGearComparison()
    local value = self:Get("rollFrame.showGearComparison")
    if value == nil then return true end
    return value
end

--- Set whether to show gear comparison in RollFrame
-- @param value boolean
function LoothingSettingsMixin:SetShowGearComparison(value)
    self:Set("rollFrame.showGearComparison", value)
end

--- Get RollFrame saved position
-- @return table|nil { point, x, y }
function LoothingSettingsMixin:GetRollFramePosition()
    return self:Get("rollFrame.position")
end

--- Set RollFrame saved position
-- @param point string
-- @param x number
-- @param y number
function LoothingSettingsMixin:SetRollFramePosition(point, x, y)
    self:Set("rollFrame.position", { point = point, x = x, y = y })
end

--[[--------------------------------------------------------------------
    RollFrame Timeout Settings
----------------------------------------------------------------------]]

--- Get whether timeout is enabled for RollFrame
-- @return boolean
function LoothingSettingsMixin:GetRollFrameTimeoutEnabled()
    local value = self:Get("rollFrame.timeoutEnabled")
    if value == nil then return true end
    return value
end

--- Set whether timeout is enabled for RollFrame
-- @param value boolean
function LoothingSettingsMixin:SetRollFrameTimeoutEnabled(value)
    self:Set("rollFrame.timeoutEnabled", value)
end

--- Get RollFrame timeout duration
-- @return number - Seconds (MIN_ROLL_TIMEOUT to MAX_ROLL_TIMEOUT)
function LoothingSettingsMixin:GetRollFrameTimeoutDuration()
    local value = self:Get("rollFrame.timeoutDuration")
    local defaultTimeout = Loothing.Timing and Loothing.Timing.DEFAULT_ROLL_TIMEOUT or 30
    local minTimeout = Loothing.Timing and Loothing.Timing.MIN_ROLL_TIMEOUT or 5
    local maxTimeout = Loothing.Timing and Loothing.Timing.MAX_ROLL_TIMEOUT or 200

    if value == nil then return defaultTimeout end
    return math.max(minTimeout, math.min(maxTimeout, value))
end

--- Set RollFrame timeout duration
-- @param seconds number (MIN_ROLL_TIMEOUT to MAX_ROLL_TIMEOUT)
function LoothingSettingsMixin:SetRollFrameTimeoutDuration(seconds)
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

--- Get winner determination mode
-- @return string "HIGHEST_VOTES", "ML_CONFIRM", or "AUTO_HIGHEST_CONFIRM"
function LoothingSettingsMixin:GetWinnerMode()
    local value = self:Get("winnerDetermination.mode")
    if value == nil then return "ML_CONFIRM" end
    return value
end

--- Set winner determination mode
-- @param mode string
function LoothingSettingsMixin:SetWinnerMode(mode)
    local valid = { HIGHEST_VOTES = true, ML_CONFIRM = true, AUTO_HIGHEST_CONFIRM = true }
    if not valid[mode] then
        mode = "ML_CONFIRM"
    end
    self:Set("winnerDetermination.mode", mode)
end

--- Get tie breaker mode
-- @return string "ROLL", "ML_CHOICE", or "REVOTE"
function LoothingSettingsMixin:GetTieBreakerMode()
    local value = self:Get("winnerDetermination.tieBreaker")
    if value == nil then return "ROLL" end
    return value
end

--- Set tie breaker mode
-- @param mode string
function LoothingSettingsMixin:SetTieBreakerMode(mode)
    local valid = { ROLL = true, ML_CHOICE = true, REVOTE = true }
    if not valid[mode] then
        mode = "ROLL"
    end
    self:Set("winnerDetermination.tieBreaker", mode)
end

--- Get whether to auto-award on unanimous vote
-- @return boolean
function LoothingSettingsMixin:GetAutoAwardOnUnanimous()
    local value = self:Get("winnerDetermination.autoAwardOnUnanimous")
    if value == nil then return false end
    return value
end

--- Set whether to auto-award on unanimous vote
-- @param value boolean
function LoothingSettingsMixin:SetAutoAwardOnUnanimous(value)
    self:Set("winnerDetermination.autoAwardOnUnanimous", value)
end

--- Get whether to require confirmation before awarding
-- @return boolean
function LoothingSettingsMixin:GetRequireConfirmation()
    local value = self:Get("winnerDetermination.requireConfirmation")
    if value == nil then return true end
    return value
end

--- Set whether to require confirmation before awarding
-- @param value boolean
function LoothingSettingsMixin:SetRequireConfirmation(value)
    self:Set("winnerDetermination.requireConfirmation", value)
end
