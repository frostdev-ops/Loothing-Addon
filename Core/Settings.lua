--[[--------------------------------------------------------------------
    Loothing - Loot Council Addon for WoW 12.0+
    Settings - SavedVariables wrapper and settings management
----------------------------------------------------------------------]]

local Loolib = LibStub("Loolib")

--[[--------------------------------------------------------------------
    LoothingSettingsMixin
----------------------------------------------------------------------]]

LoothingSettingsMixin = {}

--- Initialize settings
function LoothingSettingsMixin:Init()
    -- Load or create saved variables
    if not LoothingDB then
        LoothingDB = LoothingUtils.DeepCopy(LOOTHING_DEFAULT_SETTINGS)
    end

    self.db = LoothingDB

    -- Migrate if needed
    self:Migrate()

    -- Validate structure
    self:ValidateStructure()
end

--- Migrate settings from older versions
function LoothingSettingsMixin:Migrate()
    local currentVersion = 1
    local dbVersion = self.db.version or 0

    if dbVersion < currentVersion then
        -- Migration logic for future versions
        -- if dbVersion < 2 then ... end

        self.db.version = currentVersion
    end
end

--- Ensure all required fields exist
function LoothingSettingsMixin:ValidateStructure()
    local defaults = LOOTHING_DEFAULT_SETTINGS

    -- Council
    if not self.db.council then
        self.db.council = LoothingUtils.DeepCopy(defaults.council)
    else
        for key, value in pairs(defaults.council) do
            if self.db.council[key] == nil then
                self.db.council[key] = LoothingUtils.DeepCopy(value)
            end
        end
    end

    -- Settings
    if not self.db.settings then
        self.db.settings = LoothingUtils.DeepCopy(defaults.settings)
    else
        for key, value in pairs(defaults.settings) do
            if self.db.settings[key] == nil then
                self.db.settings[key] = LoothingUtils.DeepCopy(value)
            end
        end
    end

    -- History
    if not self.db.history then
        self.db.history = {}
    end
end

--- Save settings (called on logout)
function LoothingSettingsMixin:Save()
    -- LoothingDB is automatically saved by WoW
    -- This is just for any cleanup needed
end

--[[--------------------------------------------------------------------
    General Settings Accessors
----------------------------------------------------------------------]]

--- Get a setting value
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

--- Set a setting value
-- @param key string - Setting key (supports dot notation)
-- @param value any - Value to set
function LoothingSettingsMixin:Set(key, value)
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
    local value = LOOTHING_DEFAULT_SETTINGS

    for _, part in ipairs(parts) do
        if type(value) ~= "table" then
            return nil
        end
        value = value[part]
    end

    return value
end

--- Reset all settings to defaults
function LoothingSettingsMixin:ResetAll()
    self.db = LoothingUtils.DeepCopy(LOOTHING_DEFAULT_SETTINGS)
    LoothingDB = self.db
end

--[[--------------------------------------------------------------------
    Voting Settings
----------------------------------------------------------------------]]

--- Get voting mode
-- @return string - LOOTHING_VOTING_MODE value
function LoothingSettingsMixin:GetVotingMode()
    return self:Get("settings.votingMode", LOOTHING_VOTING_MODE.SIMPLE)
end

--- Set voting mode
-- @param mode string - LOOTHING_VOTING_MODE value
function LoothingSettingsMixin:SetVotingMode(mode)
    self:Set("settings.votingMode", mode)
end

--- Get voting timeout
-- @return number - Seconds
function LoothingSettingsMixin:GetVotingTimeout()
    return self:Get("settings.votingTimeout", LOOTHING_TIMING.DEFAULT_VOTE_TIMEOUT)
end

--- Set voting timeout
-- @param seconds number
function LoothingSettingsMixin:SetVotingTimeout(seconds)
    seconds = math.max(LOOTHING_TIMING.MIN_VOTE_TIMEOUT,
                       math.min(LOOTHING_TIMING.MAX_VOTE_TIMEOUT, seconds))
    self:Set("settings.votingTimeout", seconds)
end

--- Get auto-start session setting
-- @return boolean
function LoothingSettingsMixin:GetAutoStartSession()
    return self:Get("settings.autoStartSession", false)
end

--- Set auto-start session
-- @param enabled boolean
function LoothingSettingsMixin:SetAutoStartSession(enabled)
    self:Set("settings.autoStartSession", enabled)
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
-- @return table - Array of member names
function LoothingSettingsMixin:GetCouncilMembers()
    return self:Get("council.members", {})
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
    return self:Get("settings.announceAwards", true)
end

--- Set announce awards
-- @param announce boolean
function LoothingSettingsMixin:SetAnnounceAwards(announce)
    self:Set("settings.announceAwards", announce)
end

--- Get announce channel
-- @return string - "RAID", "RAID_WARNING", etc.
function LoothingSettingsMixin:GetAnnounceChannel()
    return self:Get("settings.announceChannel", "RAID")
end

--- Set announce channel
-- @param channel string
function LoothingSettingsMixin:SetAnnounceChannel(channel)
    self:Set("settings.announceChannel", channel)
end

--[[--------------------------------------------------------------------
    History Access
----------------------------------------------------------------------]]

--- Get loot history
-- @return table - Array of history entries
function LoothingSettingsMixin:GetHistory()
    return self:Get("history", {})
end

--- Add history entry
-- @param entry table - History entry
function LoothingSettingsMixin:AddHistoryEntry(entry)
    local history = self:GetHistory()
    history[#history + 1] = entry
    self:Set("history", history)
end

--- Clear history
function LoothingSettingsMixin:ClearHistory()
    self:Set("history", {})
end
