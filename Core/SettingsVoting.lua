--[[--------------------------------------------------------------------
    Loothing - Settings (Voting & Session Control)
----------------------------------------------------------------------]]

local ADDON_NAME, ns = ...
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

-- Session triggers (legacy helper included)
function SettingsMixin:GetAutoStartSession()
    return self:GetSessionTriggerMode() == "auto"
end

function SettingsMixin:SetAutoStartSession(enabled)
    if enabled then
        self:SetSessionTriggerMode("auto")
    else
        self:SetSessionTriggerMode("manual")
    end
end

function SettingsMixin:GetSessionTriggerMode()
    return self:Get("settings.sessionTriggerMode", "prompt")
end

function SettingsMixin:SetSessionTriggerMode(mode)
    local valid = { manual = true, auto = true, prompt = true, afterRolls = true }
    if valid[mode] then
        self:Set("settings.sessionTriggerMode", mode)
    end
end

-- Master Looter controls
function SettingsMixin:GetMasterLooterName()
    return self:Get("settings.masterLooter", nil)
end

function SettingsMixin:SetMasterLooterName(name)
    if name and name ~= "" then
        self:Set("settings.masterLooter", Utils.NormalizeName(name))
    else
        self:Set("settings.masterLooter", nil)
    end
end

function SettingsMixin:ClearMasterLooter()
    self:Set("settings.masterLooter", nil)
end

function SettingsMixin:GetMasterLooter()
    local explicit = self:GetMasterLooterName()
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
