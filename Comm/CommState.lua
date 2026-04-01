--[[--------------------------------------------------------------------
    Loothing - Loot Council Addon for WoW 12.0+
    CommState - Centralized communication state machine

    Coordinates pause/resume behavior across encounter restrictions,
    disconnect/reconnect, and queue replay. All comm subsystems consult
    CommState to decide whether to send, defer, or drop messages.

    WoW 12.0 (Midnight) blocks addon messages during encounter
    restrictions and challenge mode (not plain combat — RCLC analysis
    confirms combat does NOT block addon comms, only restriction types
    Encounter and ChallengeMode do).

    States:
        CONNECTED    — Normal operation, all priorities flow
        RESTRICTED   — Encounter/challenge restriction active; sends blocked
        DISCONNECTED — Not in group, all sends dropped

    Responsibilities:
    - Guaranteed queue routing (critical messages during restrictions)
    - Paced replay orchestration (triggers Restrictions:ReplayQueue when safe)
    - Reconnect grace period with jitter (suppress sync stampede)
    - Sync request deduplication across trigger sources
    - State transition callbacks for subsystem coordination
----------------------------------------------------------------------]]

local _, ns = ...
local Loothing = ns.Addon
local Loolib = LibStub("Loolib")
local CreateFromMixins = Loolib.CreateFromMixins
local GetTime = GetTime

ns.CommStateMixin = CreateFromMixins(Loolib.CallbackRegistryMixin, ns.CommStateMixin or {})

--[[--------------------------------------------------------------------
    CommStateMixin
----------------------------------------------------------------------]]

local CommStateMixin = ns.CommStateMixin

-- State constants (exported on the mixin for external reference)
CommStateMixin.STATE_CONNECTED    = 1
CommStateMixin.STATE_RESTRICTED   = 2
CommStateMixin.STATE_DISCONNECTED = 3

local STATE_CONNECTED    = CommStateMixin.STATE_CONNECTED
local STATE_RESTRICTED   = CommStateMixin.STATE_RESTRICTED
local STATE_DISCONNECTED = CommStateMixin.STATE_DISCONNECTED

local STATE_NAMES = {
    [STATE_CONNECTED]    = "CONNECTED",
    [STATE_RESTRICTED]   = "RESTRICTED",
    [STATE_DISCONNECTED] = "DISCONNECTED",
}

local COMMSTATE_EVENTS = {
    "OnStateChanged",          -- (oldState: number, newState: number)
    "OnGracePeriodEnded",      -- ()
}

--- CRITICAL_COMMANDS — session-essential messages that get guaranteed delivery
--- during encounter restrictions (routed to Restrictions.guaranteedQueue).
--- These are replayed first when restrictions lift.
local CRITICAL_COMMANDS = {
    [Loothing.MsgType.SESSION_START]       = true,
    [Loothing.MsgType.SESSION_END]         = true,
    [Loothing.MsgType.ITEM_ADD]            = true,
    [Loothing.MsgType.ITEM_REMOVE]         = true,
    [Loothing.MsgType.VOTE_REQUEST]        = true,
    [Loothing.MsgType.VOTE_CANCEL]         = true,
    [Loothing.MsgType.VOTE_AWARD]          = true,
    [Loothing.MsgType.VOTE_RESULTS]        = true,
    [Loothing.MsgType.VOTE_SKIP]           = true,
    [Loothing.MsgType.PLAYER_RESPONSE]     = true,
    [Loothing.MsgType.MLDB_BROADCAST]      = true,
    [Loothing.MsgType.COUNCIL_ROSTER]      = true,
    [Loothing.MsgType.OBSERVER_ROSTER]     = true,
    [Loothing.MsgType.VOTE_COMMIT]         = true,
    [Loothing.MsgType.VOTE_POLL]           = true,
    [Loothing.MsgType.RESPONSE_POLL]       = true,
    [Loothing.MsgType.BATCH]               = true,
    [Loothing.MsgType.SESSION_INIT]        = true,
    [Loothing.MsgType.RESPONSE_BATCH]      = true,
}

--[[--------------------------------------------------------------------
    Initialization
----------------------------------------------------------------------]]

function CommStateMixin:Init()
    Loolib.CallbackRegistryMixin.OnLoad(self)
    self:GenerateCallbackEvents(COMMSTATE_EVENTS)

    self.state = STATE_CONNECTED

    -- Reconnect grace period
    self.gracePeriodEnd = 0
    self.graceTimer = nil

    -- Sync deduplication
    self.lastSyncRequestTime = 0

    -- Sync circuit breaker: prevents retry storms when syncs keep failing
    self.syncFailureCount    = 0
    self.syncCircuitOpen     = false
    self.syncCircuitTimer    = nil

    self:RegisterEvents()
end

--[[--------------------------------------------------------------------
    Event Registration
----------------------------------------------------------------------]]

function CommStateMixin:RegisterEvents()
    local Events = Loolib.Events
    if not Events or not Events.Registry then return end

    -- Group tracking
    Events.Registry:RegisterEventCallback("GROUP_JOINED", function()
        self:OnGroupJoined()
    end, self)

    Events.Registry:RegisterEventCallback("GROUP_LEFT", function()
        self:OnGroupLeft()
    end, self)
end

--- Wire up sync circuit breaker callbacks (call after Loothing.Sync is initialized)
function CommStateMixin:RegisterSyncCallbacks()
    if not Loothing.Sync then return end
    Loothing.Sync:RegisterCallback("OnSyncComplete", function()
        self:OnSyncSuccess()
    end, self)
    Loothing.Sync:RegisterCallback("OnSyncFailed", function()
        self:OnSyncFailure()
    end, self)
end

--[[--------------------------------------------------------------------
    State Transitions
----------------------------------------------------------------------]]

--- Transition to a new state with callback notification
-- @param newState number - STATE_* constant
local function TransitionTo(self, newState)
    if self.state == newState then return end

    local oldState = self.state
    self.state = newState

    Loothing:Debug("CommState:", STATE_NAMES[oldState] or "?", "->", STATE_NAMES[newState] or "?")
    self:TriggerEvent("OnStateChanged", oldState, newState)
end

--- Called by Restrictions when encounter/challenge restrictions activate
function CommStateMixin:OnRestrictionActivated()
    if self.state == STATE_DISCONNECTED then return end
    TransitionTo(self, STATE_RESTRICTED)
end

--- Called by Restrictions when encounter/challenge restrictions lift
function CommStateMixin:OnRestrictionLifted()
    if self.state == STATE_DISCONNECTED then return end
    TransitionTo(self, STATE_CONNECTED)
    if Loothing.Restrictions then
        Loothing.Restrictions:ReplayQueue()
    end
end

function CommStateMixin:OnGroupLeft()
    TransitionTo(self, STATE_DISCONNECTED)
    if Loothing.Restrictions then
        Loothing.Restrictions:ClearQueue()
    end
end

function CommStateMixin:OnGroupJoined()
    if self.state == STATE_DISCONNECTED then
        TransitionTo(self, STATE_CONNECTED)
        self:StartGracePeriod()
    end
end

--- Called by Init.lua on PLAYER_ENTERING_WORLD (login/reload)
function CommStateMixin:OnPlayerEnteringWorld()
    if IsInGroup() then
        if self.state == STATE_DISCONNECTED then
            TransitionTo(self, STATE_CONNECTED)
        end
        self:StartGracePeriod()
    else
        TransitionTo(self, STATE_DISCONNECTED)
    end
end

--[[--------------------------------------------------------------------
    Public API: State Queries
----------------------------------------------------------------------]]

--- Get current comm state
-- @return number - STATE_* constant
function CommStateMixin:GetState()
    return self.state
end

--- Get human-readable state name
-- @return string
function CommStateMixin:GetStateName()
    return STATE_NAMES[self.state] or "UNKNOWN"
end

--- Check if a command should be deferred in the current state.
-- Only encounter/challenge restrictions block sends; combat does not.
-- @param command string - Loothing.MsgType value
-- @param priority string - "ALERT", "NORMAL", or "BULK"
-- @return boolean - true if deferred/dropped, false if caller should proceed
function CommStateMixin:ShouldDefer(command, priority)
    if self.state == STATE_CONNECTED then
        return false
    end

    if self.state == STATE_DISCONNECTED then
        Loothing:Debug("CommState: dropped", command, "(disconnected)")
        return true
    end

    -- RESTRICTED: encounter/challenge restrictions block addon messages
    if self.state == STATE_RESTRICTED then
        return true
    end

    return false
end

--- Check if a command is critical (session-essential, gets guaranteed delivery)
-- @param command string - Loothing.MsgType value
-- @return boolean
function CommStateMixin:IsCriticalCommand(command)
    return CRITICAL_COMMANDS[command] == true
end

--[[--------------------------------------------------------------------
    Reconnect Grace Period
----------------------------------------------------------------------]]

--- Start the grace period (suppresses sync triggers for RECONNECT_GRACE_PERIOD seconds)
function CommStateMixin:StartGracePeriod()
    local duration = Loothing.Timing.RECONNECT_GRACE_PERIOD

    if self.graceTimer then
        self.graceTimer:Cancel()
        self.graceTimer = nil
    end

    self.gracePeriodEnd = GetTime() + duration

    self.graceTimer = C_Timer.NewTimer(duration, function()
        self.graceTimer = nil
        self.gracePeriodEnd = 0
        Loothing:Debug("CommState: grace period ended")
        self:TriggerEvent("OnGracePeriodEnded")
    end)

    Loothing:Debug("CommState: grace period started (", duration, "s)")
end

--- Check if the reconnect grace period is active
-- @return boolean
function CommStateMixin:IsInGracePeriod()
    return GetTime() < self.gracePeriodEnd
end

--[[--------------------------------------------------------------------
    Sync Deduplication
----------------------------------------------------------------------]]

--- Request sync through the dedup gate
-- @param source string - "heartbeat", "roster", "reconnect" (for debug logging)
-- @param mlName string - Master Looter to sync from
-- @return boolean - true if sync was dispatched, false if suppressed
function CommStateMixin:RequestSyncIfNeeded(source, mlName)
    local now = GetTime()
    local window = Loothing.Timing.SYNC_DEDUP_WINDOW

    if now - self.lastSyncRequestTime < window then
        Loothing:Debug("CommState: suppressed sync from", source,
            "(dedup window, last:", string.format("%.1fs ago", now - self.lastSyncRequestTime), ")")
        return false
    end

    if self:IsInGracePeriod() and source ~= "reconnect" then
        Loothing:Debug("CommState: suppressed sync from", source, "(grace period)")
        return false
    end

    if self.syncCircuitOpen then
        Loothing:Debug("CommState: suppressed sync from", source, "(circuit breaker open)")
        return false
    end

    self.lastSyncRequestTime = now
    Loothing:Debug("CommState: dispatching sync from", source, "to", mlName)

    if Loothing.Sync then
        Loothing.Sync:RequestSync(mlName)
    end
    return true
end

--- Called when a sync completes successfully. Resets the circuit breaker.
function CommStateMixin:OnSyncSuccess()
    self.syncFailureCount = 0
    if self.syncCircuitOpen then
        self.syncCircuitOpen = false
        if self.syncCircuitTimer then
            self.syncCircuitTimer:Cancel()
            self.syncCircuitTimer = nil
        end
        Loothing:Debug("CommState: sync circuit breaker closed (success)")
    end
end

--- Called when a sync attempt fails. Opens circuit breaker after threshold.
function CommStateMixin:OnSyncFailure()
    self.syncFailureCount = self.syncFailureCount + 1
    local threshold = Loothing.Timing.SYNC_CIRCUIT_THRESHOLD or 3

    if self.syncFailureCount >= threshold and not self.syncCircuitOpen then
        self.syncCircuitOpen = true
        local resetTime = Loothing.Timing.SYNC_CIRCUIT_RESET or 120

        Loothing:Debug("CommState: sync circuit breaker OPEN after", self.syncFailureCount, "failures, reset in", resetTime, "s")

        if self.syncCircuitTimer then
            self.syncCircuitTimer:Cancel()
        end
        self.syncCircuitTimer = C_Timer.NewTimer(resetTime, function()
            self.syncCircuitTimer = nil
            self.syncCircuitOpen = false
            self.syncFailureCount = 0
            Loothing:Debug("CommState: sync circuit breaker reset (timeout)")
        end)
    end
end

--[[--------------------------------------------------------------------
    Jitter Utility
----------------------------------------------------------------------]]

--- Compute a jittered delay for timer scheduling
-- @param base number - Base delay in seconds
-- @param spread number - +/- jitter range in seconds
-- @return number - Jittered delay (never negative)
function CommStateMixin:Jitter(base, spread)
    return math.max(0, base + (math.random() * spread * 2 - spread))
end

--[[--------------------------------------------------------------------
    Factory
----------------------------------------------------------------------]]

function ns.CreateCommState()
    local commState = CreateFromMixins(CommStateMixin)
    commState:Init()
    return commState
end
