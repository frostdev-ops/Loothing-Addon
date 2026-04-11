--[[--------------------------------------------------------------------
    Loothing - Settings (Voting & Session Control)
----------------------------------------------------------------------]]

local _, ns = ...
local Loolib = LibStub("Loolib")
local Loothing = ns.Addon
local Utils = ns.Utils

local SettingsMixin = ns.SettingsMixin or {}
ns.SettingsMixin = SettingsMixin

-- Voting mode and timing
function SettingsMixin:GetVotingMode()
    return self:Get("voting.mode", Loothing.VotingMode.SIMPLE)
end

function SettingsMixin:SetVotingMode(mode)
    self:Set("voting.mode", mode)
end

function SettingsMixin:GetVotingTimeout()
    return self:Get("voting.timeout", Loothing.Timing.NO_TIMEOUT)
end

function SettingsMixin:SetVotingTimeout(seconds)
    if seconds == Loothing.Timing.NO_TIMEOUT then
        self:Set("voting.timeout", 0)
    else
        seconds = math.max(Loothing.Timing.MIN_VOTE_TIMEOUT, math.min(Loothing.Timing.MAX_VOTE_TIMEOUT, seconds))
        self:Set("voting.timeout", seconds)
    end
end

--[[--------------------------------------------------------------------
    Session Trigger Policy

    The split (action / timing / scope) is the canonical model. The
    pre-2.0.7 lazy migration of `settings.sessionTriggerMode` was moved
    into Loothing/Core/Migrations.lua, which runs once at Settings:Init.
----------------------------------------------------------------------]]

-- Action: manual | prompt | auto
function SettingsMixin:GetSessionTriggerAction()
    return self:Get("session.triggerAction", "prompt")
end

function SettingsMixin:SetSessionTriggerAction(action)
    local valid = { manual = true, prompt = true, auto = true }
    if valid[action] then
        self:Set("session.triggerAction", action)
    end
end

-- Timing: encounterEnd | afterLoot
function SettingsMixin:GetSessionTriggerTiming()
    return self:Get("session.triggerTiming", "encounterEnd")
end

function SettingsMixin:SetSessionTriggerTiming(timing)
    local valid = { encounterEnd = true, afterLoot = true }
    if valid[timing] then
        self:Set("session.triggerTiming", timing)
    end
end

-- Scope toggles
function SettingsMixin:GetSessionTriggerRaid()
    return self:Get("session.scope.raid", true)
end

function SettingsMixin:SetSessionTriggerRaid(v)
    self:Set("session.scope.raid", v == true)
end

function SettingsMixin:GetSessionTriggerDungeon()
    return self:Get("session.scope.dungeon", false)
end

function SettingsMixin:SetSessionTriggerDungeon(v)
    self:Set("session.scope.dungeon", v == true)
end

function SettingsMixin:GetSessionTriggerOpenWorld()
    return self:Get("session.scope.openWorld", false)
end

function SettingsMixin:SetSessionTriggerOpenWorld(v)
    self:Set("session.scope.openWorld", v == true)
end

-- Group loot handling during active Loothing sessions
function SettingsMixin:GetGroupLootMode()
    local mode = self:Get("session.groupLootMode", "active")
    if mode ~= "active" and mode ~= "passive" then
        return "active"
    end
    return mode
end

function SettingsMixin:SetGroupLootMode(mode)
    if mode == "active" or mode == "passive" then
        self:Set("session.groupLootMode", mode)
    end
end

function SettingsMixin:IsPassiveGroupLootMode()
    return self:GetGroupLootMode() == "passive"
end

function SettingsMixin:GetAutoStartSession()
    return self:GetSessionTriggerAction() == "auto"
end

function SettingsMixin:SetAutoStartSession(enabled)
    if enabled then
        self:SetSessionTriggerAction("auto")
    else
        self:SetSessionTriggerAction("manual")
    end
end

-- Master Looter controls
-- The explicit ML is runtime-only state (per-session, synced via MLDB).
-- It lives on Loothing.explicitMasterLooter, NOT in SavedVariables.

function SettingsMixin:GetMasterLooterName()
    return Loothing.explicitMasterLooter
end

function SettingsMixin:SetMasterLooterName(name)
    if name and name ~= "" then
        Loothing.explicitMasterLooter = Utils.NormalizeName(name)
    else
        Loothing.explicitMasterLooter = nil
    end
end

function SettingsMixin:ClearMasterLooter()
    Loothing.explicitMasterLooter = nil
end

function SettingsMixin:GetMasterLooter()
    local explicit = Loothing.explicitMasterLooter
    if explicit then
        return explicit
    end

    if IsInRaid() then
        for i = 1, GetNumGroupMembers() do
            local name, rank = Loolib.SecretUtil.SafeGetRaidRosterInfo(i)
            if rank == 2 and name then
                return name
            end
        end
    elseif IsInGroup() then
        if UnitIsGroupLeader("player") then
            return Utils.GetPlayerFullName()
        end
        for i = 1, 4 do
            local unit = "party" .. i
            if UnitExists(unit) and UnitIsGroupLeader(unit) then
                local name, realm = Loolib.SecretUtil.SafeUnitName(unit)
                if name then
                    if realm and realm ~= "" then
                        return name .. "-" .. realm
                    end
                    return name
                end
            end
        end
    end

    return nil
end

--- Check if local player is ML based on Settings-level resolution only
-- (explicitMasterLooter → raid leader). Does NOT check Session.masterLooter.
-- For full canonical ML resolution, use Loothing:IsCanonicalML() instead.
-- Kept for backward compat and for permission checks in /lt ml commands
-- where Settings-level authority is the correct scope.
function SettingsMixin:IsMasterLooter()
    local ml = self:GetMasterLooter()
    if not ml then
        return false
    end
    local playerName = Utils.GetPlayerFullName()
    return Utils.NormalizeName(ml) == Utils.NormalizeName(playerName)
end

-- Ranked choice rank limits
function SettingsMixin:GetMaxRanks()
    return self:Get("voting.maxRanks", 0)
end

function SettingsMixin:SetMaxRanks(n)
    self:Set("voting.maxRanks", math.max(0, math.floor(n)))
end

function SettingsMixin:GetMinRanks()
    return self:Get("voting.minRanks", 1)
end

function SettingsMixin:SetMinRanks(n)
    self:Set("voting.minRanks", math.max(1, math.floor(n)))
end

function SettingsMixin:GetMaxRevotes()
    return self:Get("voting.maxRevotes", 2)
end

function SettingsMixin:SetMaxRevotes(n)
    self:Set("voting.maxRevotes", math.max(0, math.floor(n)))
end

function SettingsMixin:GetMlSeesVotes()
    return self:Get("voting.mlSeesVotes", false)
end

function SettingsMixin:SetMlSeesVotes(v)
    self:Set("voting.mlSeesVotes", v == true)
end

--[[--------------------------------------------------------------------
    Voting privacy (collapsed merge of hideVotes + anonymousVoting)

    privacy = "open"        -- everyone sees votes + voters
            | "hide_counts" -- counts hidden until session end
            | "anonymous"   -- counts visible but voters anonymized

    The legacy GetAnonymousVoting / GetHideVotes accessors below remain
    as derived projections so older read-sites keep working without an
    audit.
----------------------------------------------------------------------]]

function SettingsMixin:GetVotingPrivacy()
    local p = self:Get("voting.privacy", "open")
    if p ~= "open" and p ~= "hide_counts" and p ~= "anonymous" then
        return "open"
    end
    return p
end

function SettingsMixin:SetVotingPrivacy(p)
    if p == "open" or p == "hide_counts" or p == "anonymous" then
        self:Set("voting.privacy", p)
    end
end

--- Derived: voters anonymized?
function SettingsMixin:GetAnonymousVoting()
    return self:GetVotingPrivacy() == "anonymous"
end

--- Derived: vote counts hidden until session end?
function SettingsMixin:GetHideVotes()
    return self:GetVotingPrivacy() == "hide_counts"
end

--- Convenience setter mapping the old boolean toggle onto the merged
--- privacy field. Setting either flag to true mirrors the pre-2.0.7
--- semantics; setting to false reverts to "open".
function SettingsMixin:SetAnonymousVoting(enabled)
    if enabled then
        self:SetVotingPrivacy("anonymous")
    else
        self:SetVotingPrivacy("open")
    end
end

function SettingsMixin:SetHideVotes(enabled)
    if enabled then
        self:SetVotingPrivacy("hide_counts")
    else
        self:SetVotingPrivacy("open")
    end
end
