--[[--------------------------------------------------------------------
    Loothing - Test Mode State & Guardrails
    Centralized test mode state, gating, and persistence safeguards.
----------------------------------------------------------------------]]

local _, ns = ...
local Loothing = ns.Addon
local GetTime, IsInGroup, IsInRaid = GetTime, IsInGroup, IsInRaid
local UnitIsGroupAssistant, UnitIsGroupLeader = UnitIsGroupAssistant, UnitIsGroupLeader
local print, time = print, time

local function safePrint(...)
    if Loothing.Print then
        Loothing:Print(...)
    else
        print(...)
    end
end

local function safeError(...)
    if Loothing.Error then
        Loothing:Error(...)
    else
        print(...)
    end
end

local TestModeState = ns.TestModeState or {
    active = false,
    persistenceAllowed = false,
    commTag = "[TEST]",
    lastPersistenceWarning = 0,
    lastCommNotice = 0,
}

local function isLeaderOrAssistant()
    if ns.Utils and ns.Utils.IsRaidLeaderOrAssistant then
        return ns.Utils.IsRaidLeaderOrAssistant()
    end
    return UnitIsGroupLeader("player") or UnitIsGroupAssistant("player")
end

function TestModeState:IsActive()
    return self.active
end

function TestModeState:IsPersistenceAllowed()
    return self.persistenceAllowed
end

function TestModeState:ShouldBlockPersistence()
    return self:IsActive() and not self.persistenceAllowed
end

function TestModeState:GuardPersistence(context)
    if not self:ShouldBlockPersistence() then
        return true
    end

    local now = GetTime and GetTime() or time()
    if now - self.lastPersistenceWarning > 2 then
        self.lastPersistenceWarning = now
        local reason = context or "persistence change"
        safeError(string.format("Test mode active: blocked %s. Use /lt testmode persist on to allow.", reason))
    end
    return false
end

function TestModeState:CheckPrerequisites(opts)
    local commsLive = IsInGroup() or IsInRaid()
    local isLeader = isLeaderOrAssistant()

    if commsLive and not isLeader then
        if opts and opts.force then
            safePrint("Test mode: forcing enable without lead/assist (use with care).")
            return true
        end
        safeError("Test mode requires party/raid lead or assist when grouped. Re-run with 'force' if intentional.")
        return false
    end

    return true
end

function TestModeState:Enter(opts)
    opts = opts or {}

    if self.active then
        self:Status()
        return true
    end

    if not self:CheckPrerequisites(opts) then
        return false
    end

    self.active = true
    self.persistenceAllowed = opts.allowPersistence or false

    -- Legacy global LoothingTestMode removed; TestModeState is the canonical source


    local persistenceText = self.persistenceAllowed and "persistence ALLOWED" or "persistence BLOCKED"
    safePrint(string.format("Test mode ENABLED (%s).", persistenceText))
    safePrint("Comms stay live; data writes are blocked unless explicitly allowed.")
    return true
end

function TestModeState:Exit()
    if not self.active then
        safePrint("Test mode already disabled.")
        return false
    end

    self.active = false
    self.persistenceAllowed = false
    self.lastPersistenceWarning = 0

    safePrint("Test mode disabled. Live persistence restored.")
    return true
end

function TestModeState:Toggle(opts)
    if self:IsActive() then
        return self:Exit()
    end
    return self:Enter(opts)
end

function TestModeState:SetPersistenceAllowed(allowed)
    self.persistenceAllowed = not not allowed
    if self.active then
        local text = self.persistenceAllowed and "Persistence now ALLOWED in test mode." or "Persistence now BLOCKED in test mode."
        safePrint(text)
    end
end

function TestModeState:Status()
    if self:IsActive() then
        local persistenceText = self.persistenceAllowed and "allowed" or "blocked"
        safePrint(string.format("Test mode is ENABLED (persistence %s).", persistenceText))
    else
        safePrint("Test mode is disabled.")
    end
end

function TestModeState:OnOutgoingComm(channel, target)
    if not self:IsActive() then
        return
    end

    local now = GetTime and GetTime() or time()
    if now - self.lastCommNotice < 2 then
        return
    end

    self.lastCommNotice = now
    local targetText = target and (" -> " .. target) or ""
    safePrint(string.format("Test mode: sending live comms (%s%s) with %s tag.", channel or "RAID", targetText, self.commTag))
end

function TestModeState:ApplySessionTag(sessionID)
    if not self:IsActive() then
        return sessionID
    end
    return string.format("TEST-%s", tostring(sessionID))
end

function TestModeState:OnSimulatorToggled(enabled)
    self.active = not not enabled
    if not enabled then
        self.persistenceAllowed = false
    end
end

--- Delegate to ns.TestMode:GetFakeRaidRoster() (loaded later via Debug/TestMode.lua).
--- Called by Utils.GetRaidRoster() when test mode is active.
function TestModeState:GetFakeRaidRoster()
    local tm = ns.TestMode
    if tm and tm.GetFakeRaidRoster then
        return tm:GetFakeRaidRoster()
    end
    return {}
end

function TestModeState:HandleSlash(args)
    local cmd, rest = args:match("^(%S*)%s*(.*)$")
    cmd = (cmd or ""):lower()
    rest = rest or ""

    if cmd == "" or cmd == "status" then
        self:Status()
        return
    elseif cmd == "on" or cmd == "enable" then
        local force = rest:lower() == "force"
        self:Enter({ force = force })
        return
    elseif cmd == "off" or cmd == "disable" then
        self:Exit()
        return
    elseif cmd == "persist" or cmd == "allowsave" or cmd == "allow" then
        local toggle = rest:lower()
        local allow = toggle == "on" or toggle == "true" or toggle == "yes"
        self:SetPersistenceAllowed(allow)
        return
    end

    safePrint("Test mode commands:")
    safePrint("  /lt testmode on [force]   - Enable test mode (blocks saves)")
    safePrint("  /lt testmode off          - Disable test mode")
    safePrint("  /lt testmode status       - Show current status")
    safePrint("  /lt testmode persist on|off - Allow or block SavedVariables writes")
end

ns.TestModeState = TestModeState
Loothing.TestMode = TestModeState

