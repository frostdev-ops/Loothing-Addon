--[[--------------------------------------------------------------------
    Loothing - Council Member Management
    Extracted member lifecycle, auto-include logic, and raid helpers.
----------------------------------------------------------------------]]

local _, ns = ...
local Loothing = ns.Addon
local Loolib = LibStub("Loolib")
local Utils = ns.Utils
local time = time

ns.CouncilMixin = ns.CouncilMixin or {}

local CouncilMixin = ns.CouncilMixin

--[[--------------------------------------------------------------------
    Member Management
----------------------------------------------------------------------]]

function CouncilMixin:AddMember(name)
    name = Utils.NormalizeName(name)

    if self.members[name] then
        return false, "Player is already a council member"
    end

    self.members[name] = {
        name = name,
        addedTime = time(),
        -- FIX(Area4-4): Use SafeUnitName to avoid secret value tainting
        addedBy = Loolib.SecretUtil.SafeUnitName("player") or "Unknown",
    }

    self:SaveToSettings()
    self:TriggerEvent("OnMemberAdded", name)
    self:TriggerEvent("OnRosterChanged")

    return true, nil
end

function CouncilMixin:RemoveMember(name)
    name = Utils.NormalizeName(name)

    if not self.members[name] then
        return false
    end

    self.members[name] = nil

    self:SaveToSettings()
    self:TriggerEvent("OnMemberRemoved", name)
    self:TriggerEvent("OnRosterChanged")

    return true
end

function CouncilMixin:IsMember(name)
    name = Utils.NormalizeName(name)

    if self.members[name] then
        return true
    end

    if self.remotePrimary and self.remoteRoster[name] then
        return true
    end

    if self:IsAutoIncluded(name) then
        return true
    end

    return false
end

function CouncilMixin:IsAutoIncluded(name)
    name = Utils.NormalizeName(name)

    if self.autoIncludeRaidLeader then
        local leader = Utils.GetRaidLeader()
        if leader and Utils.IsSamePlayer(name, leader) then
            return true
        end
    end

    if self.autoIncludeOfficers then
        local officers = Utils.GetRaidOfficers()
        for _, officer in ipairs(officers) do
            if Utils.IsSamePlayer(name, officer) then
                return true
            end
        end
    end

    return false
end

function CouncilMixin:GetMembers()
    local result = {}
    for name in pairs(self.members) do
        result[#result + 1] = name
    end
    table.sort(result)
    return result
end

function CouncilMixin:GetAllMembers()
    local result = {}
    local seen = {}

    for name in pairs(self.members) do
        if not seen[name] then
            seen[name] = true
            result[#result + 1] = name
        end
    end

    if self.remotePrimary then
        for name in pairs(self.remoteRoster) do
            if not seen[name] then
                seen[name] = true
                result[#result + 1] = name
            end
        end
    end

    if self.autoIncludeRaidLeader then
        local leader = Utils.GetRaidLeader()
        if leader and not seen[leader] then
            seen[leader] = true
            result[#result + 1] = leader
        end
    end

    if self.autoIncludeOfficers then
        local officers = Utils.GetRaidOfficers()
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

function CouncilMixin:GetMemberCount()
    return #self:GetAllMembers()
end

function CouncilMixin:ClearMembers()
    wipe(self.members)
    self:SaveToSettings()
    self:TriggerEvent("OnRosterChanged")
end

--[[--------------------------------------------------------------------
    Guild Integration
----------------------------------------------------------------------]]

function CouncilMixin:GetGuildRanks()
    local ranks = {}

    if not IsInGuild() then
        return ranks
    end

    local numRanks = GuildControlGetNumRanks()
    for i = 1, numRanks do
        local rankName = GuildControlGetRankName(i)
        if rankName then
            ranks[#ranks + 1] = {
                index = i,
                name = rankName,
            }
        end
    end

    return ranks
end

function CouncilMixin:AddMembersByRank(rankIndex)
    if not IsInGuild() then
        return 0
    end

    local count = 0
    local totalMembers = GetNumGuildMembers()

    for i = 1, totalMembers do
        local name, _, rankIndexMember = Loothing.GetGuildRosterInfo(i)
        if (rankIndexMember + 1) == rankIndex and name then
            name = Utils.NormalizeName(name)
            if self:AddMember(name) then
                count = count + 1
            end
        end
    end

    return count
end

--[[--------------------------------------------------------------------
    Group/Raid Helpers
----------------------------------------------------------------------]]

function CouncilMixin:GetCurrentGroupMembers()
    local members = {}

    if IsInRaid() then
        local roster = Utils.GetRaidRoster()
        for _, entry in ipairs(roster) do
            members[#members + 1] = {
                name = entry.name,
                class = entry.classFile,
                role = entry.role,
            }
        end
    elseif IsInGroup() then
        for i = 1, 4 do
            local unit = "party" .. i
            if UnitExists(unit) then
                local name = Loolib.SecretUtil.SafeUnitName(unit)
                local _, class = Loolib.SecretUtil.SafeUnitClass(unit)
                local role = UnitGroupRolesAssigned(unit)

                if name then
                    name = Utils.NormalizeName(name)
                    members[#members + 1] = {
                        name = name,
                        class = class,
                        role = role,
                    }
                end
            end
        end

        local playerName = Utils.GetPlayerFullName()
        -- FIX(Area4-4): Use SafeUnitClass to avoid secret value tainting
        local _, playerClass = Loolib.SecretUtil.SafeUnitClass("player")
        local playerRole = UnitGroupRolesAssigned("player")

        members[#members + 1] = {
            name = playerName,
            class = playerClass,
            role = playerRole,
        }
    end

    return members
end

function CouncilMixin:AddMembersFromGroup(names)
    if not names or type(names) ~= "table" then
        return 0
    end

    local groupMembers = self:GetCurrentGroupMembers()
    local groupMemberSet = {}

    for _, member in ipairs(groupMembers) do
        local normalized = Utils.NormalizeName(member.name)
        groupMemberSet[normalized] = true
    end

    local count = 0
    for _, name in ipairs(names) do
        name = Utils.NormalizeName(name)
        if groupMemberSet[name] then
            if self:AddMember(name) then
                count = count + 1
            end
        end
    end

    return count
end

function CouncilMixin:RemoveAllMembers()
    local count = 0

    for _ in pairs(self.members) do
        count = count + 1
    end

    wipe(self.members)
    self:SaveToSettings()
    self:TriggerEvent("OnRosterChanged")

    return count
end

function CouncilMixin:GetCouncilMemberCount()
    return self:GetMemberCount()
end

--- Called when GROUP_ROSTER_UPDATE fires so subscribers can refresh
-- Auto-include logic (leader/officers) is dynamic, so notify listeners.
function CouncilMixin:OnRosterUpdate()
    self:TriggerEvent("OnRosterChanged")
end
