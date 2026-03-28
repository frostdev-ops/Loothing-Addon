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
    return self:Get("settings.votingMode", Loothing.VotingMode.SIMPLE)
end

function SettingsMixin:SetVotingMode(mode)
    self:Set("settings.votingMode", mode)
end

function SettingsMixin:GetVotingTimeout()
    return self:Get("settings.votingTimeout", Loothing.Timing.DEFAULT_VOTE_TIMEOUT)
end

function SettingsMixin:SetVotingTimeout(seconds)
    if seconds == Loothing.Timing.NO_TIMEOUT then
        self:Set("settings.votingTimeout", 0)
    else
        seconds = math.max(Loothing.Timing.MIN_VOTE_TIMEOUT, math.min(Loothing.Timing.MAX_VOTE_TIMEOUT, seconds))
        self:Set("settings.votingTimeout", seconds)
    end
end

--[[--------------------------------------------------------------------
    Session Trigger Policy (split model — source of truth)
----------------------------------------------------------------------]]

--- Lazy migration: if the new split keys are absent, derive them from
--- the legacy sessionTriggerMode field.  Called once per accessor family.
function SettingsMixin:MigrateSessionTriggerIfNeeded()
    -- If new keys already exist, nothing to do (handles fresh installs and
    -- already-migrated profiles; re-checked every call so profile switches
    -- are safe without an instance flag).
    if self:Get("settings.sessionTriggerAction") then return end

    local legacy = self:Get("settings.sessionTriggerMode")
    if not legacy then return end

    local actionMap = {
        manual     = "manual",
        auto       = "auto",
        prompt     = "prompt",
        afterRolls = "prompt",
    }
    local timingMap = {
        manual     = "encounterEnd",
        auto       = "encounterEnd",
        prompt     = "encounterEnd",
        afterRolls = "afterLoot",
    }
    self:Set("settings.sessionTriggerAction",    actionMap[legacy] or "prompt")
    self:Set("settings.sessionTriggerTiming",    timingMap[legacy] or "encounterEnd")
    self:Set("settings.sessionTriggerRaid",      true)
    self:Set("settings.sessionTriggerDungeon",   false)
    self:Set("settings.sessionTriggerOpenWorld",  false)
end

-- Action: manual | prompt | auto
function SettingsMixin:GetSessionTriggerAction()
    self:MigrateSessionTriggerIfNeeded()
    return self:Get("settings.sessionTriggerAction", "prompt")
end

function SettingsMixin:SetSessionTriggerAction(action)
    local valid = { manual = true, prompt = true, auto = true }
    if valid[action] then
        self:Set("settings.sessionTriggerAction", action)
    end
end

-- Timing: encounterEnd | afterLoot
function SettingsMixin:GetSessionTriggerTiming()
    self:MigrateSessionTriggerIfNeeded()
    return self:Get("settings.sessionTriggerTiming", "encounterEnd")
end

function SettingsMixin:SetSessionTriggerTiming(timing)
    local valid = { encounterEnd = true, afterLoot = true }
    if valid[timing] then
        self:Set("settings.sessionTriggerTiming", timing)
    end
end

-- Scope toggles
function SettingsMixin:GetSessionTriggerRaid()
    self:MigrateSessionTriggerIfNeeded()
    return self:Get("settings.sessionTriggerRaid", true)
end

function SettingsMixin:SetSessionTriggerRaid(v)
    self:Set("settings.sessionTriggerRaid", v == true)
end

function SettingsMixin:GetSessionTriggerDungeon()
    self:MigrateSessionTriggerIfNeeded()
    return self:Get("settings.sessionTriggerDungeon", false)
end

function SettingsMixin:SetSessionTriggerDungeon(v)
    self:Set("settings.sessionTriggerDungeon", v == true)
end

function SettingsMixin:GetSessionTriggerOpenWorld()
    self:MigrateSessionTriggerIfNeeded()
    return self:Get("settings.sessionTriggerOpenWorld", false)
end

function SettingsMixin:SetSessionTriggerOpenWorld(v)
    self:Set("settings.sessionTriggerOpenWorld", v == true)
end

-- Group loot handling during active Loothing sessions
function SettingsMixin:GetGroupLootMode()
    local mode = self:Get("settings.groupLootMode", "active")
    if mode ~= "active" and mode ~= "passive" then
        return "active"
    end
    return mode
end

function SettingsMixin:SetGroupLootMode(mode)
    if mode == "active" or mode == "passive" then
        self:Set("settings.groupLootMode", mode)
    end
end

function SettingsMixin:IsPassiveGroupLootMode()
    return self:GetGroupLootMode() == "passive"
end

--[[--------------------------------------------------------------------
    Legacy Compatibility Shims
----------------------------------------------------------------------]]

--- Legacy getter — maps split fields back to old enum.
function SettingsMixin:GetSessionTriggerMode()
    local action = self:GetSessionTriggerAction()
    local timing = self:GetSessionTriggerTiming()
    if action == "manual" then return "manual" end
    if action == "auto"   then return "auto"   end
    -- action == "prompt"
    if timing == "afterLoot" then return "afterRolls" end
    return "prompt"
end

--- Legacy setter — maps old enum to split fields.
function SettingsMixin:SetSessionTriggerMode(mode)
    local map = {
        manual     = { action = "manual", timing = "encounterEnd" },
        auto       = { action = "auto",   timing = "encounterEnd" },
        prompt     = { action = "prompt",  timing = "encounterEnd" },
        afterRolls = { action = "prompt",  timing = "afterLoot" },
    }
    local entry = map[mode]
    if entry then
        self:Set("settings.sessionTriggerAction", entry.action)
        self:Set("settings.sessionTriggerTiming", entry.timing)
        self:Set("settings.sessionTriggerMode", mode) -- keep legacy field in sync
    end
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
