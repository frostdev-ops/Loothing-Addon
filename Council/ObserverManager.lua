--[[--------------------------------------------------------------------
    Loothing - Loot Council Addon for WoW 12.0+
    ObserverManager - Observer list management and permission queries
----------------------------------------------------------------------]]

local _, ns = ...
local Loolib = LibStub("Loolib")
local CreateFromMixins = Loolib.CreateFromMixins
local IsInGroup = IsInGroup
local Loothing = ns.Addon
local Utils = ns.Utils
ns.ObserverMixin = CreateFromMixins(Loolib.CallbackRegistryMixin, ns.ObserverMixin or {})

local ObserverMixin = ns.ObserverMixin

--[[--------------------------------------------------------------------
    ObserverMixin
----------------------------------------------------------------------]]

local OBSERVER_EVENTS = {
    "OnObserverAdded",
    "OnObserverRemoved",
    "OnObserverListChanged",
    "OnPermissionsChanged",
}

--- Initialize observer manager
function ObserverMixin:Init()
    Loolib.CallbackRegistryMixin.OnLoad(self)
    self:GenerateCallbackEvents(OBSERVER_EVENTS)

    -- Local list (persisted)
    self.list = {}

    -- Remote list (from ML, not persisted)
    self.remoteList = {}
    self.remotePrimary = false

    -- Load from settings
    self:LoadFromSettings()
end

--[[--------------------------------------------------------------------
    List Management (ML only)
----------------------------------------------------------------------]]

--- Add a player to the observer list
-- @param name string - Player name
-- @return boolean, string - success, error
function ObserverMixin:AddObserver(name)
    if not name or name == "" then
        return false, "Invalid name"
    end
    name = Utils.NormalizeName(name)
    -- Already on list?
    for _, n in ipairs(self.list) do
        if Utils.IsSamePlayer(n, name) then
            return false, name .. " is already an observer"
        end
    end
    self.list[#self.list + 1] = name
    self:SaveToSettings()
    self:TriggerEvent("OnObserverAdded", name)
    self:TriggerEvent("OnObserverListChanged", self.list)
    if Loothing.Sync then Loothing.Sync:BroadcastObserverRoster() end
    return true
end

--- Remove a player from the observer list
-- @param name string
-- @return boolean
function ObserverMixin:RemoveObserver(name)
    if not name or name == "" then return false end
    name = Utils.NormalizeName(name)
    for i, n in ipairs(self.list) do
        if Utils.IsSamePlayer(n, name) then
            table.remove(self.list, i)
            self:SaveToSettings()
            self:TriggerEvent("OnObserverRemoved", name)
            self:TriggerEvent("OnObserverListChanged", self.list)
            if Loothing.Sync then Loothing.Sync:BroadcastObserverRoster() end
            return true
        end
    end
    return false
end

--- Clear all observers
function ObserverMixin:ClearObservers()
    wipe(self.list)
    self:SaveToSettings()
    self:TriggerEvent("OnObserverListChanged", self.list)
    if Loothing.Sync then Loothing.Sync:BroadcastObserverRoster() end
end

--- Get explicit observer list
-- @return table - Array of names
function ObserverMixin:GetObservers()
    return self.list
end

--- Get all effective observers (explicit list + auto-included when openObservation is on)
-- @return table - Array of names
function ObserverMixin:GetAllObservers()
    if not Loothing.Settings or not Loothing.Settings:GetOpenObservation() then
        return self.list
    end
    -- Open observation: return all group members
    if not IsInGroup() then
        return self.list
    end
    local roster = Utils.GetRaidRoster()
    local result = {}
    for _, entry in ipairs(roster) do
        result[#result + 1] = entry.name
    end
    return result
end

--[[--------------------------------------------------------------------
    Membership Queries
----------------------------------------------------------------------]]

--- Check if a player is on the observer list (or auto-included via openObservation)
-- @param name string
-- @return boolean
function ObserverMixin:IsObserver(name)
    if not name then return false end

    -- Check remote list if using remote primary
    if self.remotePrimary then
        local normalized = Utils.NormalizeName(name)
        if self.remoteList[normalized] then
            return true
        end
        -- Also check openObservation from remote
        if Loothing.Settings and Loothing.Settings:GetOpenObservation() then
            if IsInGroup() then
                local roster = Utils.GetRaidRoster()
                for _, entry in ipairs(roster) do
                    if Utils.IsSamePlayer(entry.name, name) then
                        return true
                    end
                end
            end
            return false
        end
        return false
    end

    -- Local list check
    for _, n in ipairs(self.list) do
        if Utils.IsSamePlayer(n, name) then
            return true
        end
    end

    -- Open observation: any group member qualifies
    if Loothing.Settings and Loothing.Settings:GetOpenObservation() then
        if IsInGroup() then
            local roster = Utils.GetRaidRoster()
            for _, entry in ipairs(roster) do
                if Utils.IsSamePlayer(entry.name, name) then
                    return true
                end
            end
        end
    end

    return false
end

--- Check if the current player is an observer
-- @return boolean
function ObserverMixin:IsPlayerObserver()
    -- ML observer is handled separately by IsMLObserver()
    local playerName = Utils.GetPlayerFullName()
    return self:IsObserver(playerName)
end

--- Check if the current player is the ML in observer mode
-- @return boolean
function ObserverMixin:IsMLObserver()
    if not Loothing.Session or not Loothing.Session:IsMasterLooter() then
        return false
    end
    if not Loothing.Settings then return false end
    return Loothing.Settings:GetMLIsObserver()
end

--[[--------------------------------------------------------------------
    Permission Queries
    ML always has full visibility. Regular observers are gated by permissions.
----------------------------------------------------------------------]]

--- Can the current player see vote counts?
-- @return boolean
function ObserverMixin:CanPlayerSeeVoteCounts()
    -- Council members and ML always see everything
    if Loothing.Council and Loothing.Council:IsPlayerCouncilMember() then return true end
    if Loothing.Session and Loothing.Session:IsMasterLooter() then return true end
    -- Regular observer: check permission
    if not Loothing.Settings then return false end
    local perms = Loothing.Settings:GetObserverPermissions()
    return perms and perms.seeVoteCounts or false
end

--- Can the current player see voter identities?
-- @return boolean
function ObserverMixin:CanPlayerSeeVoterIdentities()
    if Loothing.Council and Loothing.Council:IsPlayerCouncilMember() then return true end
    if Loothing.Session and Loothing.Session:IsMasterLooter() then return true end
    if not Loothing.Settings then return false end
    local perms = Loothing.Settings:GetObserverPermissions()
    return perms and perms.seeVoterIdentities or false
end

--- Can the current player see candidate responses?
-- @return boolean
function ObserverMixin:CanPlayerSeeResponses()
    if Loothing.Council and Loothing.Council:IsPlayerCouncilMember() then return true end
    if Loothing.Session and Loothing.Session:IsMasterLooter() then return true end
    if not Loothing.Settings then return false end
    local perms = Loothing.Settings:GetObserverPermissions()
    return perms and perms.seeResponses or false
end

--- Can the current player see candidate notes?
-- @return boolean
function ObserverMixin:CanPlayerSeeNotes()
    if Loothing.Council and Loothing.Council:IsPlayerCouncilMember() then return true end
    if Loothing.Session and Loothing.Session:IsMasterLooter() then return true end
    if not Loothing.Settings then return false end
    local perms = Loothing.Settings:GetObserverPermissions()
    return perms and perms.seeNotes or false
end

--[[--------------------------------------------------------------------
    Remote Roster (from ML)
----------------------------------------------------------------------]]

--- Set remote observer data (received from ML)
-- @param data table - { list, permissions, openObservation }
function ObserverMixin:SetRemoteObserverList(data)
    if not data then return end

    wipe(self.remoteList)
    if data.list then
        for _, name in ipairs(data.list) do
            self.remoteList[Utils.NormalizeName(name)] = true
        end
    end

    self.remotePrimary = true

    -- Apply permissions from ML
    if data.permissions and Loothing.Settings then
        Loothing.Settings:Set("observers.permissions", data.permissions)
    end
    if data.openObservation ~= nil and Loothing.Settings then
        Loothing.Settings:Set("observers.openObservation", data.openObservation)
        Loothing.Settings:Set("voting.observe", data.openObservation)
    end
    if data.mlIsObserver ~= nil and Loothing.Settings then
        Loothing.Settings:Set("observers.mlIsObserver", data.mlIsObserver)
    end

    self:TriggerEvent("OnObserverListChanged", data.list or {})
end

--- Clear remote roster (become primary)
function ObserverMixin:ClearRemoteObserverList()
    wipe(self.remoteList)
    self.remotePrimary = false
end

--[[--------------------------------------------------------------------
    Persistence
----------------------------------------------------------------------]]

function ObserverMixin:LoadFromSettings()
    if not Loothing.Settings then return end
    local saved = Loothing.Settings:GetObserverList()
    wipe(self.list)
    if saved then
        for _, name in ipairs(saved) do
            self.list[#self.list + 1] = name
        end
    end
end

function ObserverMixin:SaveToSettings()
    if not Loothing.Settings then return end
    Loothing.Settings:SetObserverList(self.list)
end

--[[--------------------------------------------------------------------
    Factory
----------------------------------------------------------------------]]

function ns.CreateObserver()
    local observer = CreateFromMixins(ObserverMixin)
    observer:Init()
    return observer
end

-- ns.ObserverMixin and ns.CreateObserver exported above
