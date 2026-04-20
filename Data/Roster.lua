--[[--------------------------------------------------------------------
    Loothing - Loot Council Addon for WoW 12.0+
    Roster - Desktop exchange raid roster data reader
    Provides roster membership and alt linking from the web app.
----------------------------------------------------------------------]]

local _, ns = ...
local Loolib = LibStub("Loolib")
local Loothing = ns.Addon
local Utils = ns.Utils
local time = time

local function normalizeKey(name)
    if Utils and Utils.NormalizeName then
        return Utils.NormalizeName(name)
    end
    return name
end

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

--- Load roster data from SavedVariables (written by Tauri desktop app).
-- Keys are normalized on load for parity with the other desktopExchange
-- readers (see PlayerIntel.lua for rationale).
function RosterMixin:LoadFromSaved()
    if not Loothing.Settings then return end

    local exchange = Loothing.Settings:GetGlobalValue("desktopExchange")
    if not exchange or not exchange.roster then return end

    local r = exchange.roster
    local raw = r.members or {}
    self.members = {}
    for key, value in pairs(raw) do
        local normalized = normalizeKey(key)
        if normalized then self.members[normalized] = value end
    end
    self.rosterName = r.rosterName
    self.updatedAt = r.updatedAt
    self.sharedBy = r.sharedBy     -- nil if from own desktop app
    self.sharedAt = r.sharedAt     -- nil if from own desktop app

    self:TriggerEvent("OnRosterLoaded")
end

--- Check if data was received via intel share (not from own desktop app)
-- @return boolean
function RosterMixin:IsSharedData()
    return self.sharedBy ~= nil
end

--- Get sharing metadata
-- @return string|nil sharedBy - Player name who shared
-- @return number|nil sharedAt - Epoch timestamp when shared
function RosterMixin:GetSharedInfo()
    return self.sharedBy, self.sharedAt
end

--[[--------------------------------------------------------------------
    Queries
----------------------------------------------------------------------]]

--- Get roster data for a specific member
-- @param playerName string - "Name-Realm" format (any casing)
-- @return table|nil - { cls, spec, role, status, alts }
function RosterMixin:GetMember(playerName)
    if not playerName then return nil end
    return self.members[normalizeKey(playerName)]
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
-- @param playerName string - "Name-Realm" format (any casing)
-- @return boolean
function RosterMixin:IsOnRoster(playerName)
    if not playerName then return false end
    return self.members[normalizeKey(playerName)] ~= nil
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
