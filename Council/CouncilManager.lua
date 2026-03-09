--[[--------------------------------------------------------------------
    Loothing - Loot Council Addon for WoW 12.0+
    CouncilManager - Council member management
----------------------------------------------------------------------]]

local _, ns = ...
local Loolib = LibStub("Loolib")
local CreateFromMixins = Loolib.CreateFromMixins
local Utils = ns.Utils
ns.CouncilMixin = CreateFromMixins(Loolib.CallbackRegistryMixin, ns.CouncilMixin or {})

local CouncilMixin = ns.CouncilMixin

--[[--------------------------------------------------------------------
    CouncilMixin
----------------------------------------------------------------------]]

local COUNCIL_EVENTS = {
    "OnMemberAdded",
    "OnMemberRemoved",
    "OnRosterChanged",
    "OnRemoteRosterReceived",
}

--- Initialize council manager
function CouncilMixin:Init()
    Loolib.CallbackRegistryMixin.OnLoad(self)
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

-- Member management extracted to CouncilMembers.lua

--[[--------------------------------------------------------------------
    Remote Roster (from ML)
----------------------------------------------------------------------]]

--- Set remote roster (received from ML)
-- @param members table - Array of member names
function CouncilMixin:SetRemoteRoster(members)
    wipe(self.remoteRoster)

    for _, name in ipairs(members) do
        self.remoteRoster[Utils.NormalizeName(name)] = true
    end

    self.remotePrimary = true
    self:TriggerEvent("OnRemoteRosterReceived", members)
    self:TriggerEvent("OnRosterChanged")
end

--- Clear remote roster (become primary)
function CouncilMixin:ClearRemoteRoster()
    wipe(self.remoteRoster)
    self.remotePrimary = false
    self:TriggerEvent("OnRosterChanged")
end

--- Check if using remote roster
-- @return boolean
function CouncilMixin:IsUsingRemoteRoster()
    return self.remotePrimary
end

-- Settings, persistence, and display helpers extracted to CouncilSettings.lua

--[[--------------------------------------------------------------------
    Factory
----------------------------------------------------------------------]]

function ns.CreateCouncil()
    local council = CreateFromMixins(CouncilMixin)
    council:Init()
    return council
end

-- ns.CouncilMixin and ns.CreateCouncil exported above
