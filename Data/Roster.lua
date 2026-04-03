--[[--------------------------------------------------------------------
    Loothing - Loot Council Addon for WoW 12.0+
    Roster - Desktop exchange raid roster data reader
    Provides roster membership and alt linking from the web app.
----------------------------------------------------------------------]]

local _, ns = ...
local Loolib = LibStub("Loolib")
local Loothing = ns.Addon
local time = time

--[[--------------------------------------------------------------------
    RosterMixin
----------------------------------------------------------------------]]

local RosterMixin = Loolib.CreateFromMixins(Loolib.CallbackRegistryMixin)
ns.RosterMixin = RosterMixin

local ROSTER_EVENTS = {
    "OnRosterLoaded",
    "OnRosterUpdated",
}

--- Initialize roster data reader
function RosterMixin:Init()
    Loolib.CallbackRegistryMixin.OnLoad(self)
    self:GenerateCallbackEvents(ROSTER_EVENTS)

    self.members = {}
    self.rosterName = nil
    self.updatedAt = nil

    self:LoadFromSaved()
end

--[[--------------------------------------------------------------------
    Persistence
----------------------------------------------------------------------]]

--- Load roster data from SavedVariables (written by Tauri desktop app)
function RosterMixin:LoadFromSaved()
    if not Loothing.Settings then return end

    local exchange = Loothing.Settings:GetGlobalValue("desktopExchange")
    if not exchange or not exchange.roster then return end

    local r = exchange.roster
    self.members = r.members or {}
    self.rosterName = r.rosterName
    self.updatedAt = r.updatedAt

    self:TriggerEvent("OnRosterLoaded")
end

--[[--------------------------------------------------------------------
    Queries
----------------------------------------------------------------------]]

--- Get roster data for a specific member
-- @param playerName string - "Name-Realm" format
-- @return table|nil - { cls, spec, role, status, alts }
function RosterMixin:GetMember(playerName)
    if not playerName then return nil end
    return self.members[playerName]
end

--- Get alt names for a player
-- @param playerName string - "Name-Realm" format
-- @return table|nil - Array of "AltName-Realm" strings
function RosterMixin:GetAlts(playerName)
    local member = self:GetMember(playerName)
    if not member or not member.alts then return nil end
    return #member.alts > 0 and member.alts or nil
end

--- Check if a player is on the synced roster
-- @param playerName string - "Name-Realm" format
-- @return boolean
function RosterMixin:IsOnRoster(playerName)
    return self.members[playerName] ~= nil
end

--- Check if roster data has been loaded from the desktop app
-- @return boolean
function RosterMixin:HasData()
    return self.updatedAt ~= nil and next(self.members) ~= nil
end

--- Get seconds since the last desktop sync
-- @return number|nil - Seconds since sync, or nil if never synced
function RosterMixin:GetTimeSinceSync()
    if not self.updatedAt then return nil end
    return time() - self.updatedAt
end

--- Get the synced roster name
-- @return string|nil
function RosterMixin:GetRosterName()
    return self.rosterName
end

--- Get count of roster members
-- @return number
function RosterMixin:GetMemberCount()
    local count = 0
    for _ in pairs(self.members) do
        count = count + 1
    end
    return count
end
