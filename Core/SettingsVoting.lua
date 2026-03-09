--[[--------------------------------------------------------------------
    Loothing - Settings (Voting & Session Control)
----------------------------------------------------------------------]]

LoothingSettingsMixin = LoothingSettingsMixin or {}

-- Voting mode and timing
function LoothingSettingsMixin:GetVotingMode()
    return self:Get("settings.votingMode", LOOTHING_VOTING_MODE.SIMPLE)
end

function LoothingSettingsMixin:SetVotingMode(mode)
    self:Set("settings.votingMode", mode)
end

function LoothingSettingsMixin:GetVotingTimeout()
    return self:Get("settings.votingTimeout", LOOTHING_TIMING.DEFAULT_VOTE_TIMEOUT)
end

function LoothingSettingsMixin:SetVotingTimeout(seconds)
    if seconds == LOOTHING_TIMING.NO_TIMEOUT then
        self:Set("settings.votingTimeout", 0)
    else
        seconds = math.max(LOOTHING_TIMING.MIN_VOTE_TIMEOUT, math.min(LOOTHING_TIMING.MAX_VOTE_TIMEOUT, seconds))
        self:Set("settings.votingTimeout", seconds)
    end
end

-- Session triggers (legacy helper included)
function LoothingSettingsMixin:GetAutoStartSession()
    return self:GetSessionTriggerMode() == "auto"
end

function LoothingSettingsMixin:SetAutoStartSession(enabled)
    if enabled then
        self:SetSessionTriggerMode("auto")
    else
        self:SetSessionTriggerMode("manual")
    end
end

function LoothingSettingsMixin:GetSessionTriggerMode()
    return self:Get("settings.sessionTriggerMode", "prompt")
end

function LoothingSettingsMixin:SetSessionTriggerMode(mode)
    local valid = { manual = true, auto = true, prompt = true, afterRolls = true }
    if valid[mode] then
        self:Set("settings.sessionTriggerMode", mode)
    end
end

-- Master Looter controls
function LoothingSettingsMixin:GetMasterLooterName()
    return self:Get("settings.masterLooter", nil)
end

function LoothingSettingsMixin:SetMasterLooterName(name)
    if name and name ~= "" then
        self:Set("settings.masterLooter", LoothingUtils.NormalizeName(name))
    else
        self:Set("settings.masterLooter", nil)
    end
end

function LoothingSettingsMixin:ClearMasterLooter()
    self:Set("settings.masterLooter", nil)
end

function LoothingSettingsMixin:GetMasterLooter()
    local explicit = self:GetMasterLooterName()
    if explicit then
        return explicit
    end

    if IsInRaid() then
        for i = 1, GetNumGroupMembers() do
            local name, rank = GetRaidRosterInfo(i)
            if rank == 2 and not LoothingUtils.IsSecretValue(name) then
                return name
            end
        end
    elseif IsInGroup() then
        if UnitIsGroupLeader("player") then
            return LoothingUtils.GetPlayerFullName()
        end
        for i = 1, 4 do
            local unit = "party" .. i
            if UnitExists(unit) and UnitIsGroupLeader(unit) then
                local name, realm = UnitName(unit)
                if not LoothingUtils.IsSecretValue(name) then
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

function LoothingSettingsMixin:IsMasterLooter()
    local ml = self:GetMasterLooter()
    if not ml then
        return false
    end
    local playerName = LoothingUtils.GetPlayerFullName()
    return LoothingUtils.NormalizeName(ml) == LoothingUtils.NormalizeName(playerName)
end

