--[[--------------------------------------------------------------------
    Loothing - Loot Council Addon for WoW 12.0+
    CouncilManager - Council member management
----------------------------------------------------------------------]]

local Loolib = LibStub("Loolib")

--[[--------------------------------------------------------------------
    LoothingCouncilMixin
----------------------------------------------------------------------]]

LoothingCouncilMixin = LoolibCreateFromMixins(LoolibCallbackRegistryMixin)

local COUNCIL_EVENTS = {
    "OnMemberAdded",
    "OnMemberRemoved",
    "OnRosterChanged",
    "OnRemoteRosterReceived",
}

--- Initialize council manager
function LoothingCouncilMixin:Init()
    LoolibCallbackRegistryMixin.OnLoad(self)
    self:GenerateCallbackEvents(COUNCIL_EVENTS)

    -- Local roster (persisted)
    self.members = {}

    -- Remote roster (from ML, not persisted)
    self.remotePrimary = false
    self.remoteRoster = {}

    -- Settings
    self.autoIncludeOfficers = true
    self.autoIncludeRaidLeader = true

    -- Load from SavedVariables
    self:LoadFromSettings()
end

--[[--------------------------------------------------------------------
    Member Management
----------------------------------------------------------------------]]

--- Add a council member
-- @param name string - Player name (normalized)
-- @return boolean - True if added
function LoothingCouncilMixin:AddMember(name)
    name = LoothingUtils.NormalizeName(name)

    if self:IsMember(name) then
        return false
    end

    self.members[name] = {
        name = name,
        addedTime = time(),
        addedBy = UnitName("player"),
    }

    self:SaveToSettings()
    self:TriggerEvent("OnMemberAdded", name)
    self:TriggerEvent("OnRosterChanged")

    return true
end

--- Remove a council member
-- @param name string - Player name
-- @return boolean - True if removed
function LoothingCouncilMixin:RemoveMember(name)
    name = LoothingUtils.NormalizeName(name)

    if not self.members[name] then
        return false
    end

    self.members[name] = nil

    self:SaveToSettings()
    self:TriggerEvent("OnMemberRemoved", name)
    self:TriggerEvent("OnRosterChanged")

    return true
end

--- Check if player is a council member
-- @param name string - Player name
-- @return boolean
function LoothingCouncilMixin:IsMember(name)
    name = LoothingUtils.NormalizeName(name)

    -- Check explicit members
    if self.members[name] then
        return true
    end

    -- Check remote roster if we're not ML
    if self.remotePrimary and self.remoteRoster[name] then
        return true
    end

    -- Check auto-include settings
    if self:IsAutoIncluded(name) then
        return true
    end

    return false
end

--- Check if player is auto-included
-- @param name string - Player name
-- @return boolean
function LoothingCouncilMixin:IsAutoIncluded(name)
    name = LoothingUtils.NormalizeName(name)

    -- Check raid leader
    if self.autoIncludeRaidLeader then
        local leader = LoothingUtils.GetRaidLeader()
        if leader and LoothingUtils.IsSamePlayer(name, leader) then
            return true
        end
    end

    -- Check officers (raid assistants)
    if self.autoIncludeOfficers then
        local officers = LoothingUtils.GetRaidOfficers()
        for _, officer in ipairs(officers) do
            if LoothingUtils.IsSamePlayer(name, officer) then
                return true
            end
        end
    end

    return false
end

--- Get all explicit council members
-- @return table - Array of member names
function LoothingCouncilMixin:GetMembers()
    local result = {}
    for name in pairs(self.members) do
        result[#result + 1] = name
    end
    table.sort(result)
    return result
end

--- Get all effective council members (explicit + auto-included)
-- @return table - Array of member names
function LoothingCouncilMixin:GetAllMembers()
    local result = {}
    local seen = {}

    -- Add explicit members
    for name in pairs(self.members) do
        if not seen[name] then
            seen[name] = true
            result[#result + 1] = name
        end
    end

    -- Add remote roster if applicable
    if self.remotePrimary then
        for name in pairs(self.remoteRoster) do
            if not seen[name] then
                seen[name] = true
                result[#result + 1] = name
            end
        end
    end

    -- Add auto-included
    if self.autoIncludeRaidLeader then
        local leader = LoothingUtils.GetRaidLeader()
        if leader and not seen[leader] then
            seen[leader] = true
            result[#result + 1] = leader
        end
    end

    if self.autoIncludeOfficers then
        local officers = LoothingUtils.GetRaidOfficers()
        for _, officer in ipairs(officers) do
            if not seen[officer] then
                seen[officer] = true
                result[#result + 1] = officer
            end
        end
    end

    table.sort(result)
    return result
end

--- Get member count
-- @return number
function LoothingCouncilMixin:GetMemberCount()
    return #self:GetAllMembers()
end

--- Clear all explicit members
function LoothingCouncilMixin:ClearMembers()
    wipe(self.members)
    self:SaveToSettings()
    self:TriggerEvent("OnRosterChanged")
end

--[[--------------------------------------------------------------------
    Remote Roster (from ML)
----------------------------------------------------------------------]]

--- Set remote roster (received from ML)
-- @param members table - Array of member names
function LoothingCouncilMixin:SetRemoteRoster(members)
    wipe(self.remoteRoster)

    for _, name in ipairs(members) do
        self.remoteRoster[LoothingUtils.NormalizeName(name)] = true
    end

    self.remotePrimary = true
    self:TriggerEvent("OnRemoteRosterReceived", members)
    self:TriggerEvent("OnRosterChanged")
end

--- Clear remote roster (become primary)
function LoothingCouncilMixin:ClearRemoteRoster()
    wipe(self.remoteRoster)
    self.remotePrimary = false
    self:TriggerEvent("OnRosterChanged")
end

--- Check if using remote roster
-- @return boolean
function LoothingCouncilMixin:IsUsingRemoteRoster()
    return self.remotePrimary
end

--[[--------------------------------------------------------------------
    Settings
----------------------------------------------------------------------]]

--- Set auto-include officers setting
-- @param enabled boolean
function LoothingCouncilMixin:SetAutoIncludeOfficers(enabled)
    self.autoIncludeOfficers = enabled
    self:SaveToSettings()
    self:TriggerEvent("OnRosterChanged")
end

--- Get auto-include officers setting
-- @return boolean
function LoothingCouncilMixin:GetAutoIncludeOfficers()
    return self.autoIncludeOfficers
end

--- Set auto-include raid leader setting
-- @param enabled boolean
function LoothingCouncilMixin:SetAutoIncludeRaidLeader(enabled)
    self.autoIncludeRaidLeader = enabled
    self:SaveToSettings()
    self:TriggerEvent("OnRosterChanged")
end

--- Get auto-include raid leader setting
-- @return boolean
function LoothingCouncilMixin:GetAutoIncludeRaidLeader()
    return self.autoIncludeRaidLeader
end

--[[--------------------------------------------------------------------
    Persistence
----------------------------------------------------------------------]]

--- Load council from settings
function LoothingCouncilMixin:LoadFromSettings()
    if not Loothing.Settings then
        return
    end

    -- Load explicit members
    local savedMembers = Loothing.Settings:Get("council.members")
    if savedMembers then
        for _, memberData in ipairs(savedMembers) do
            if type(memberData) == "string" then
                -- Legacy format (just names)
                self.members[memberData] = {
                    name = memberData,
                    addedTime = 0,
                    addedBy = "unknown",
                }
            elseif type(memberData) == "table" then
                self.members[memberData.name] = memberData
            end
        end
    end

    -- Load settings
    self.autoIncludeOfficers = Loothing.Settings:Get("council.autoIncludeOfficers")
    if self.autoIncludeOfficers == nil then
        self.autoIncludeOfficers = LOOTHING_DEFAULT_SETTINGS.council.autoIncludeOfficers
    end

    self.autoIncludeRaidLeader = Loothing.Settings:Get("council.autoIncludeRaidLeader")
    if self.autoIncludeRaidLeader == nil then
        self.autoIncludeRaidLeader = LOOTHING_DEFAULT_SETTINGS.council.autoIncludeRaidLeader
    end
end

--- Save council to settings
function LoothingCouncilMixin:SaveToSettings()
    if not Loothing.Settings then
        return
    end

    -- Save members as array
    local memberArray = {}
    for _, memberData in pairs(self.members) do
        memberArray[#memberArray + 1] = memberData
    end

    Loothing.Settings:Set("council.members", memberArray)
    Loothing.Settings:Set("council.autoIncludeOfficers", self.autoIncludeOfficers)
    Loothing.Settings:Set("council.autoIncludeRaidLeader", self.autoIncludeRaidLeader)
end

--[[--------------------------------------------------------------------
    Raid Integration
----------------------------------------------------------------------]]

--- Get council members currently in raid
-- @return table - Array of member names in raid
function LoothingCouncilMixin:GetMembersInRaid()
    -- Test mode: return fake council members
    if LoothingTestMode and LoothingTestMode:IsEnabled() then
        local fakeMembers = LoothingTestMode:GetFakeCouncilMembers()
        local result = {}
        for _, member in ipairs(fakeMembers) do
            result[#result + 1] = member.name
        end
        return result
    end

    if not IsInRaid() then
        return {}
    end

    local result = {}
    local allMembers = self:GetAllMembers()
    local roster = LoothingUtils.GetRaidRoster()

    for _, memberName in ipairs(allMembers) do
        for _, rosterEntry in ipairs(roster) do
            if LoothingUtils.IsSamePlayer(memberName, rosterEntry.name) then
                result[#result + 1] = memberName
                break
            end
        end
    end

    return result
end

--- Check if current player is a council member
-- @return boolean
function LoothingCouncilMixin:IsPlayerCouncilMember()
    local playerName = LoothingUtils.GetPlayerFullName()
    return self:IsMember(playerName)
end

--[[--------------------------------------------------------------------
    Display Helpers
----------------------------------------------------------------------]]

--- Get member info with class color
-- @param name string - Member name
-- @return table|nil - { name, coloredName, class, isAutoIncluded }
function LoothingCouncilMixin:GetMemberInfo(name)
    name = LoothingUtils.NormalizeName(name)

    if not self:IsMember(name) then
        return nil
    end

    -- Try to get class from raid roster
    local className = nil
    if IsInRaid() then
        local roster = LoothingUtils.GetRaidRoster()
        for _, entry in ipairs(roster) do
            if LoothingUtils.IsSamePlayer(name, entry.name) then
                className = entry.classFile
                break
            end
        end
    end

    local shortName = LoothingUtils.GetShortName(name)
    local coloredName = className and LoothingUtils.ColorByClass(shortName, className) or shortName

    return {
        name = name,
        shortName = shortName,
        coloredName = coloredName,
        class = className,
        isAutoIncluded = self:IsAutoIncluded(name),
        isExplicit = self.members[name] ~= nil,
    }
end

--[[--------------------------------------------------------------------
    Factory
----------------------------------------------------------------------]]

function CreateLoothingCouncil()
    local council = LoolibCreateFromMixins(LoothingCouncilMixin)
    council:Init()
    return council
end
