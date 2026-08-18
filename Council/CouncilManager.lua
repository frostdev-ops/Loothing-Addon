--[[--------------------------------------------------------------------
    Loothing - Loot Council Addon for WoW 12.0+
    CouncilManager - Council member management
----------------------------------------------------------------------]]

local _, ns = ...
local Loolib = LibStub("Loolib")
local CreateFromMixins = Loolib.CreateFromMixins
local Utils = ns.Utils
local time = time
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
        -- NormalizeName returns nil for nil/secret input; a malformed roster
        -- element must not become a nil table index inside comm dispatch
        local normalized = Utils.NormalizeName(name)
        if normalized then
            self.remoteRoster[normalized] = true
        end
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

--- Adopt the current remote roster as the local council, replacing any
--- existing local members. Used during ML handover when the new ML chooses
--- to "Continue" the previous ML's session: the remote roster is the
--- previous ML's council, which is what they want to inherit. Wipe semantics
--- (not union) match the user-facing "Continue with their council" framing —
--- merging would give a confusing mixed roster.
---
--- If the remote roster is empty (e.g., the new ML never received a
--- COUNCIL_ROSTER from the previous ML), the existing local roster is
--- preserved.
-- @return number count - number of members promoted from remote
function CouncilMixin:PromoteRemoteToLocal()
    local hadRemote = self.remotePrimary
    local remoteCount = 0
    for _ in pairs(self.remoteRoster) do
        remoteCount = remoteCount + 1
    end

    -- Empty remote roster: nothing to promote. Drop remote-primary flag and
    -- only fire OnRosterChanged if it actually flipped.
    if remoteCount == 0 then
        self.remotePrimary = false
        if hadRemote then
            self:TriggerEvent("OnRosterChanged")
        end
        return 0
    end

    -- Replacement: clear local members, then copy remote entries.
    wipe(self.members)

    local count = 0
    local now = time()
    local addedBy = (Loolib.SecretUtil and Loolib.SecretUtil.SafeUnitName
        and Loolib.SecretUtil.SafeUnitName("player")) or "Unknown"
    for name in pairs(self.remoteRoster) do
        local normalized = Utils.NormalizeName(name)
        self.members[normalized] = {
            name = normalized,
            addedTime = now,
            addedBy = addedBy,
        }
        count = count + 1
    end

    wipe(self.remoteRoster)
    self.remotePrimary = false

    self:SaveToSettings()
    self:TriggerEvent("OnRosterChanged")
    return count
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
