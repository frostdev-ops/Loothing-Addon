--[[--------------------------------------------------------------------
    Loothing - Council Settings & Roster Helpers
----------------------------------------------------------------------]]

LoothingCouncilMixin = LoothingCouncilMixin or {}

-- Settings toggles
function LoothingCouncilMixin:SetAutoIncludeOfficers(enabled)
    self.autoIncludeOfficers = enabled
    self:SaveToSettings()
    self:TriggerEvent("OnRosterChanged")
end

function LoothingCouncilMixin:GetAutoIncludeOfficers()
    return self.autoIncludeOfficers
end

function LoothingCouncilMixin:SetAutoIncludeRaidLeader(enabled)
    self.autoIncludeRaidLeader = enabled
    self:SaveToSettings()
    self:TriggerEvent("OnRosterChanged")
end

function LoothingCouncilMixin:GetAutoIncludeRaidLeader()
    return self.autoIncludeRaidLeader
end

-- Persistence
function LoothingCouncilMixin:LoadFromSettings()
    if not Loothing.Settings then
        return
    end

    local savedMembers = Loothing.Settings:Get("council.members")
    if savedMembers then
        for _, memberData in ipairs(savedMembers) do
            if type(memberData) == "string" then
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

    self.autoIncludeOfficers = Loothing.Settings:Get("council.autoIncludeOfficers")
    if self.autoIncludeOfficers == nil then
        self.autoIncludeOfficers = LOOTHING_DEFAULT_SETTINGS.council.autoIncludeOfficers
    end

    self.autoIncludeRaidLeader = Loothing.Settings:Get("council.autoIncludeRaidLeader")
    if self.autoIncludeRaidLeader == nil then
        self.autoIncludeRaidLeader = LOOTHING_DEFAULT_SETTINGS.council.autoIncludeRaidLeader
    end
end

function LoothingCouncilMixin:SaveToSettings()
    if not Loothing.Settings then
        return
    end

    local memberArray = {}
    for _, memberData in pairs(self.members) do
        memberArray[#memberArray + 1] = memberData
    end

    Loothing.Settings:Set("council.members", memberArray)
    Loothing.Settings:Set("council.autoIncludeOfficers", self.autoIncludeOfficers)
    Loothing.Settings:Set("council.autoIncludeRaidLeader", self.autoIncludeRaidLeader)
end

-- Raid integration
function LoothingCouncilMixin:GetMembersInRaid()
    if LoothingTestMode and LoothingTestMode:IsEnabled() then
        local fakeMembers = LoothingTestMode:GetFakeCouncilMembers()
        local result = {}
        for _, member in ipairs(fakeMembers) do
            result[#result + 1] = member.name
        end
        return result
    end

    if not IsInGroup() then
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

function LoothingCouncilMixin:IsPlayerCouncilMember()
    if LoothingTestMode and LoothingTestMode:IsEnabled() then
        return true
    end
    local playerName = LoothingUtils.GetPlayerFullName()
    return self:IsMember(playerName)
end

-- Display helper
function LoothingCouncilMixin:GetMemberInfo(name)
    name = LoothingUtils.NormalizeName(name)

    if not self:IsMember(name) then
        return nil
    end

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

