--[[--------------------------------------------------------------------
    Loothing - Loot Council Addon for WoW 12.0+
    CommState - Centralized communication state machine

    Coordinates pause/resume behavior across combat, encounter restrictions,
    disconnect/reconnect, and queue replay. All comm subsystems consult
    CommState to decide whether to send, defer, or drop messages.

    WoW 12.0 (Midnight) blocks ALL addon messages during combat, not just
    during encounter restrictions. Both COMBAT and RESTRICTED states block
    sends; the distinction determines which queue receives the message:
    - Critical commands → guaranteed queue (replayed when combat ends)
    - Non-critical → combat defer queue (BULK priority, shorter TTL)

    States:
        CONNECTED    — Normal operation, all priorities flow
        COMBAT       — In combat, ALL sends blocked by WoW; messages queued
        RESTRICTED   — Encounter restriction active (subset of combat)
        DISCONNECTED — Not in group, all sends dropped

    Responsibilities:
    - Combat defer queue (non-critical messages held during combat)
    - Guaranteed queue routing (critical messages during combat/encounters)
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
CommStateMixin.STATE_COMBAT       = 2
CommStateMixin.STATE_RESTRICTED   = 3
CommStateMixin.STATE_DISCONNECTED = 4

local STATE_CONNECTED    = CommStateMixin.STATE_CONNECTED
local STATE_COMBAT       = CommStateMixin.STATE_COMBAT
local STATE_RESTRICTED   = CommStateMixin.STATE_RESTRICTED
local STATE_DISCONNECTED = CommStateMixin.STATE_DISCONNECTED

local STATE_NAMES = {
    [STATE_CONNECTED]    = "CONNECTED",
    [STATE_COMBAT]       = "COMBAT",
    [STATE_RESTRICTED]   = "RESTRICTED",
    [STATE_DISCONNECTED] = "DISCONNECTED",
}

local COMMSTATE_EVENTS = {
    "OnStateChanged",          -- (oldState: number, newState: number)
    "OnGracePeriodEnded",      -- ()
    "OnCombatQueueWarning",    -- (queueSize: number, maxSize: number)
}

--- CRITICAL_COMMANDS — session-essential messages that get guaranteed delivery
--- during combat (routed to Restrictions.guaranteedQueue instead of combat defer).
--- In Midnight, these cannot actually flow during combat (WoW blocks them),
--- but they are replayed first when combat ends due to higher replay priority.
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
    [Loothing.MsgType.PLAYER_RESPONSE_ACK] = true,
    [Loothing.MsgType.MLDB_BROADCAST]      = true,
    [Loothing.MsgType.COUNCIL_ROSTER]      = true,
    [Loothing.MsgType.BATCH]               = true,
}

--[[--------------------------------------------------------------------
    Initialization
----------------------------------------------------------------------]]

function CommStateMixin:Init()
    Loolib.CallbackRegistryMixin.OnLoad(self)
    self:GenerateCallbackEvents(COMMSTATE_EVENTS)

    self.state = STATE_CONNECTED

    -- Combat defer queue
    self.combatDeferQueue = {}

    -- Reconnect grace period
    self.gracePeriodEnd = 0
    self.graceTimer = nil

    -- Sync deduplication
    self.lastSyncRequestTime = 0

    -- Sync circuit breaker: prevents retry storms when syncs keep failing
    self.syncFailureCount    = 0
    self.syncCircuitOpen     = false
    self.syncCircuitTimer    = nil

    -- Combat-end receiver recovery
    self.combatEndSyncTimer = nil

    self:RegisterEvents()
end

--[[--------------------------------------------------------------------
    Event Registration
----------------------------------------------------------------------]]

function CommStateMixin:RegisterEvents()
    local Events = Loolib.Events
    if not Events or not Events.Registry then return end

    -- Combat tracking
    Events.Registry:RegisterEventCallback("PLAYER_REGEN_DISABLED", function()
        self:OnCombatStart()
    end, self)

    Events.Registry:RegisterEventCallback("PLAYER_REGEN_ENABLED", function()
        self:OnCombatEnd()
    end, self)

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

function CommStateMixin:OnCombatStart()
    -- Only transition CONNECTED → COMBAT (RESTRICTED takes priority)
    if self.state == STATE_CONNECTED then
        TransitionTo(self, STATE_COMBAT)
    end

    -- Cancel any pending combat-end sync check (re-entered combat before it fired)
    if self.combatEndSyncTimer then
        self.combatEndSyncTimer:Cancel()
        self.combatEndSyncTimer = nil
    end
end

function CommStateMixin:OnCombatEnd()
    if self.state == STATE_COMBAT then
        TransitionTo(self, STATE_CONNECTED)
        -- Replay guaranteed queue first (session-critical messages), then drain
        -- non-critical combat-deferred messages as BULK.
        if Loothing.Restrictions then
            Loothing.Restrictions:ReplayQueue()
        end
        self:DrainCombatDeferQueue()

        -- Receiver-side recovery: While we were in combat, WoW may have silently
        -- dropped messages FROM other players (e.g., ML sent VOTE_AWARD while we
        -- were fighting). Request a sync check so we catch up on anything missed.
        -- Jittered delay prevents all 25 raiders from syncing at the same instant.
        self:ScheduleCombatEndSyncCheck()

        -- Notify ResponseTracker so it can send CLIENT_READY and re-show frame
        if Loothing.ResponseTracker then
            Loothing.ResponseTracker:OnCombatEnd()
        end
    end
end

--- Called by Restrictions when encounter/challenge restrictions activate
function CommStateMixin:OnRestrictionActivated()
    -- Don't transition if disconnected — restriction events can arrive after GROUP_LEFT
    if self.state == STATE_DISCONNECTED then return end
    TransitionTo(self, STATE_RESTRICTED)
end

--- Called by Restrictions when encounter/challenge restrictions lift
function CommStateMixin:OnRestrictionLifted()
    -- Don't transition if disconnected — restriction events can arrive after GROUP_LEFT
    if self.state == STATE_DISCONNECTED then return end

    if InCombatLockdown() then
        -- Still in combat — WoW still blocks all addon messages.
        -- Do NOT replay. Wait for PLAYER_REGEN_ENABLED (OnCombatEnd).
        TransitionTo(self, STATE_COMBAT)
    else
        -- Combat over — safe to send. Trigger replay.
        TransitionTo(self, STATE_CONNECTED)
        if Loothing.Restrictions then
            Loothing.Restrictions:ReplayQueue()
        end
        self:DrainCombatDeferQueue()
    end
end

function CommStateMixin:OnGroupLeft()
    TransitionTo(self, STATE_DISCONNECTED)
    -- Clear combat defer queue — stale after leaving group
    wipe(self.combatDeferQueue)
    -- Cancel any active guaranteed queue replay (no group to send to)
    if Loothing.Restrictions then
        Loothing.Restrictions:ClearQueue()
    end
    -- Cancel any pending combat-end sync check
    if self.combatEndSyncTimer then
        self.combatEndSyncTimer:Cancel()
        self.combatEndSyncTimer = nil
    end
end

function CommStateMixin:OnGroupJoined()
    if self.state == STATE_DISCONNECTED then
        -- Determine correct target state
        if InCombatLockdown() then
            TransitionTo(self, STATE_COMBAT)
        else
            TransitionTo(self, STATE_CONNECTED)
        end
        self:StartGracePeriod()
    end
end

--- Called by Init.lua on PLAYER_ENTERING_WORLD (login/reload)
function CommStateMixin:OnPlayerEnteringWorld()
    if IsInGroup() then
        if self.state == STATE_DISCONNECTED then
            if InCombatLockdown() then
                TransitionTo(self, STATE_COMBAT)
            else
                TransitionTo(self, STATE_CONNECTED)
            end
        elseif InCombatLockdown() and self.state == STATE_CONNECTED then
            -- /reload during combat: we missed PLAYER_REGEN_DISABLED
            TransitionTo(self, STATE_COMBAT)
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

--- Check if a command+priority should be deferred in the current state.
-- In WoW 12.0 (Midnight), ALL addon messages are blocked during combat,
-- not just during encounter restrictions. Both COMBAT and RESTRICTED states
-- return true here. The caller is responsible for routing to the correct
-- queue (guaranteed vs. combat defer) based on command criticality.
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

    -- COMBAT and RESTRICTED: WoW blocks all addon messages.
    -- Caller must route to guaranteed queue (critical) or combat defer (non-critical).
    if self.state == STATE_COMBAT or self.state == STATE_RESTRICTED then
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
    Combat Defer Queue
----------------------------------------------------------------------]]

--- Queue a non-critical message during combat
-- @param command string
-- @param data table|nil
-- @param target string|nil
-- @param priority string
function CommStateMixin:DeferForCombat(command, data, target, priority)
    local max = Loothing.Timing.COMBAT_DEFER_MAX
    if #self.combatDeferQueue >= max then
        Loothing:Debug("CommState: combat defer queue full, dropping:", command)
        if Loothing.Comm then
            Loothing.Comm:TriggerEvent("OnMessageDropped", command, "combat_queue_full", target)
        end
        return
    end

    self.combatDeferQueue[#self.combatDeferQueue + 1] = {
        command = command,
        data = data,
        target = target,
        priority = "BULK",  -- always downgrade to BULK on release
        queueTime = GetTime(),
    }

    -- Warn when queue is nearing capacity (80%)
    if #self.combatDeferQueue >= math.floor(max * 0.8) then
        self:TriggerEvent("OnCombatQueueWarning", #self.combatDeferQueue, max)
    end

    Loothing:Debug("CommState: deferred for combat:", command,
        "(queue:", #self.combatDeferQueue, ")")
end

--- Drain combat-deferred messages after combat ends
-- All messages sent as BULK — transport throttle handles rate limiting (4x cost).
function CommStateMixin:DrainCombatDeferQueue()
    if #self.combatDeferQueue == 0 then return end
    if InCombatLockdown() then return end -- safety: still in combat

    local queue = self.combatDeferQueue
    self.combatDeferQueue = {}

    local now = GetTime()
    local staleTTL = Loothing.Timing.COMBAT_DEFER_STALE_TIME
    local sent, dropped = 0, 0

    for _, msg in ipairs(queue) do
        if now - msg.queueTime < staleTTL then
            if Loothing.Comm then
                Loothing.Comm:Send(msg.command, msg.data, msg.target, msg.priority)
            end
            sent = sent + 1
        else
            dropped = dropped + 1
        end
    end

    if sent > 0 or dropped > 0 then
        Loothing:Debug("CommState: combat defer drained:", sent, "sent,", dropped, "stale")
    end
end

--- Get count of combat-deferred messages
-- @return number
function CommStateMixin:GetCombatDeferCount()
    return #self.combatDeferQueue
end

--[[--------------------------------------------------------------------
    Reconnect Grace Period
----------------------------------------------------------------------]]

--- Start the grace period (suppresses sync triggers for RECONNECT_GRACE_PERIOD seconds)
function CommStateMixin:StartGracePeriod()
    local duration = Loothing.Timing.RECONNECT_GRACE_PERIOD

    -- Cancel any existing grace timer
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
-- All sync trigger sources (AckTracker, Sync.CheckNeedSync, Init.RestoreFromCache)
-- should call this instead of Sync:RequestSync() directly.
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

    -- Grace period check
    if self:IsInGracePeriod() and source ~= "reconnect" then
        Loothing:Debug("CommState: suppressed sync from", source, "(grace period)")
        return false
    end

    -- Circuit breaker: after repeated failures, back off to avoid retry storms
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
    Combat-End Receiver Recovery

    In WoW 12.0, messages FROM other players are also dropped while the
    local player is in combat. The sender has no way to know — there is
    no per-recipient ACK at the WoW addon channel level. To recover:

    When a non-ML client leaves combat during an active session, schedule
    a jittered sync check against the ML. If the ML's state has diverged
    (e.g., an award was made while we were in combat), the sync will
    restore it. The jitter spreads 25 raiders across a ~4s window.

    If we already synced recently (dedup window), the check is suppressed.
    If the ML is still in combat, the sync request is queued by the ML's
    CommState and answered when the ML's combat ends.
----------------------------------------------------------------------]]

--- Schedule a sync check after leaving combat to catch missed messages.
-- Also handles the case where SESSION_START itself was missed during combat
-- (player's session is INACTIVE but ML has an active session).
function CommStateMixin:ScheduleCombatEndSyncCheck()
    -- Only non-ML clients need recovery — ML owns the canonical state
    if Loothing.handleLoot then return end

    -- Must be in a group
    if not IsInGroup() then return end

    -- Prefer known ML, fall back to raid leader (covers the case where we
    -- missed SESSION_START and don't know who the ML is)
    local ml = Loothing.masterLooter
    if not ml then
        local Utils = ns and ns.Utils
        if Utils and Utils.GetRaidLeader then
            ml = Utils.GetRaidLeader()
        end
    end
    if not ml then return end

    -- Cancel any pending combat-end sync timer (e.g., rapid combat in/out)
    if self.combatEndSyncTimer then
        self.combatEndSyncTimer:Cancel()
        self.combatEndSyncTimer = nil
    end

    -- Jittered delay: 2-6s (spreads 25 raiders across a 4s window)
    local delay = self:Jitter(4, 2)
    self.combatEndSyncTimer = C_Timer.NewTimer(delay, function()
        self.combatEndSyncTimer = nil
        if InCombatLockdown() then return end
        self:RequestSyncIfNeeded("combat-end", ml)
    end)

    Loothing:Debug("CommState: combat-end sync check scheduled (",
        string.format("%.1f", delay), "s)")
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

-- ns.CommStateMixin and ns.CreateCommState exported above
