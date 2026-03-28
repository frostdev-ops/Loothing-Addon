--[[--------------------------------------------------------------------
    Loothing - Loot Council Addon for WoW 12.0+
    Restrictions - Encounter addon restriction handling

    WoW fires ADDON_RESTRICTION_STATE_CHANGED during encounters and
    challenge modes. When restrictions are active, addon comms are
    silently dropped. This module:
    - Tracks restriction state via bitmask
    - Queues critical ("guaranteed") comms during restrictions
    - Replays queued comms via paced ticker when restrictions lift
    - Notifies CommState of restriction transitions
    - Fires callbacks so UI can show restriction/replay indicators
----------------------------------------------------------------------]]

local _, ns = ...
local Loothing = ns.Addon
local Loolib = LibStub("Loolib")
local Comm = Loolib.Comm
local CreateFromMixins = Loolib.CreateFromMixins
local GetTime = GetTime

ns.RestrictionsMixin = CreateFromMixins(Loolib.CallbackRegistryMixin, ns.RestrictionsMixin or {})

--[[--------------------------------------------------------------------
    RestrictionsMixin
----------------------------------------------------------------------]]

local RestrictionsMixin = ns.RestrictionsMixin

-- Bitmask positions
local RESTRICTION_ENCOUNTER = 0x2       -- bit 1: encounter active
local RESTRICTION_CHALLENGE  = 0x4      -- bit 2: challenge mode active
local RESTRICTION_MASK = bit.bor(RESTRICTION_ENCOUNTER, RESTRICTION_CHALLENGE)

-- Paced replay constants
local REPLAY_INTERVAL    = Loothing.Timing.REPLAY_INTERVAL    or 0.1
local PRESSURE_SOFT      = Loothing.Timing.REPLAY_PAUSE_PRESSURE or 0.6
local PRESSURE_HARD      = Loothing.Timing.REPLAY_HARD_PRESSURE  or 0.8
local GUARANTEED_TTL     = 300  -- 5 minutes: discard stale guaranteed messages

-- Priority weights for replay ordering (lower = higher priority)
local PRIORITY_WEIGHT = { ALERT = 1, NORMAL = 2, BULK = 3 }

local RESTRICTION_EVENTS = {
    "OnRestrictionChanged",     -- (active: boolean)
    "OnQueuedMessageSent",      -- (command: string)
    "OnReplayStarted",          -- (count: number)
    "OnReplayProgress",         -- (remaining: number, total: number)
    "OnReplayComplete",         -- (sent: number, discarded: number)
    "OnReplayPaused",           -- (remaining: number)
}

--- Initialize restriction handler
function RestrictionsMixin:Init()
    Loolib.CallbackRegistryMixin.OnLoad(self)
    self:GenerateCallbackEvents(RESTRICTION_EVENTS)

    self.restrictions = 0               -- Current restriction bitmask
    self.restrictionsEnabled = false     -- Convenience flag
    self.guaranteedQueue = {}            -- Queued messages awaiting replay

    -- Paced replay state
    self.replayTicker = nil
    self.replayBuffer = nil
    self.replayIndex = 0
    self.replayStats = { sent = 0, discarded = 0, total = 0 }

    -- Register for restriction events
    self:RegisterEvents()
end

--[[--------------------------------------------------------------------
    Event Registration
----------------------------------------------------------------------]]

function RestrictionsMixin:RegisterEvents()
    local Events = Loolib.Events
    if not Events or not Events.Registry then return end

    -- WoW fires this when addon restrictions change during encounters
    Events.Registry:RegisterEventCallback("ADDON_RESTRICTION_STATE_CHANGED", function(_, state)
        self:OnRestrictionStateChanged(state)
    end, self)

    -- Track encounter start/end as backup detection
    Events.Registry:RegisterEventCallback("ENCOUNTER_START", function()
        self:OnEncounterStart()
    end, self)

    Events.Registry:RegisterEventCallback("ENCOUNTER_END", function()
        self:OnEncounterEnd()
    end, self)

    -- Challenge mode tracking
    Events.Registry:RegisterEventCallback("CHALLENGE_MODE_START", function()
        self:SetRestrictionBit(RESTRICTION_CHALLENGE, true)
    end, self)

    Events.Registry:RegisterEventCallback("CHALLENGE_MODE_COMPLETED", function()
        self:SetRestrictionBit(RESTRICTION_CHALLENGE, false)
    end, self)
end

--[[--------------------------------------------------------------------
    State Management
----------------------------------------------------------------------]]

--- Handle ADDON_RESTRICTION_STATE_CHANGED
-- @param state number - Enum.AddOnRestrictionState value
function RestrictionsMixin:OnRestrictionStateChanged(state)
    -- Active or Activating = restricted
    local isActive = (state == Enum.AddOnRestrictionState.Active
                   or state == Enum.AddOnRestrictionState.Activating)

    self:SetRestrictionBit(RESTRICTION_ENCOUNTER, isActive)
end

function RestrictionsMixin:OnEncounterStart()
    -- Encounter bit is set primarily by ADDON_RESTRICTION_STATE_CHANGED,
    -- but we set it here as a safety net
    self:SetRestrictionBit(RESTRICTION_ENCOUNTER, true)
end

function RestrictionsMixin:OnEncounterEnd()
    -- Don't clear immediately - wait for ADDON_RESTRICTION_STATE_CHANGED to fire Inactive.
    -- ENCOUNTER_END can fire before restrictions actually lift (e.g., during wipe recovery).
    -- Use a short delay to avoid premature queue replay.
    C_Timer.After(1, function()
        -- Only clear if ADDON_RESTRICTION_STATE_CHANGED hasn't already handled it
        if bit.band(self.restrictions, RESTRICTION_ENCOUNTER) ~= 0 then
            self:SetRestrictionBit(RESTRICTION_ENCOUNTER, false)
        end
    end)
end

--- Set or clear a restriction bit and update state
-- @param bitFlag number - The bit to set/clear
-- @param active boolean - Whether the restriction is active
function RestrictionsMixin:SetRestrictionBit(bitFlag, active)
    local oldEnabled = self.restrictionsEnabled

    if active then
        self.restrictions = bit.bor(self.restrictions, bitFlag)
    else
        self.restrictions = bit.band(self.restrictions, bit.bnot(bitFlag))
    end

    self.restrictionsEnabled = bit.band(self.restrictions, RESTRICTION_MASK) ~= 0

    -- Fire callback on state change
    if self.restrictionsEnabled ~= oldEnabled then
        self:TriggerEvent("OnRestrictionChanged", self.restrictionsEnabled)

        Loothing:Debug("Comm restrictions:", self.restrictionsEnabled and "ACTIVE" or "LIFTED")

        -- Notify CommState of restriction transitions.
        -- CommState decides when to trigger ReplayQueue() based on combat state:
        -- if still in combat when restrictions lift, replay is deferred to combat end.
        local CommState = Loothing.CommState
        if CommState then
            if self.restrictionsEnabled then
                CommState:OnRestrictionActivated()
            else
                CommState:OnRestrictionLifted()
            end
        else
            -- Fallback: no CommState available, replay immediately (pre-CommState compat)
            if not self.restrictionsEnabled then
                self:ReplayQueue()
            end
        end
    end
end

--[[--------------------------------------------------------------------
    Public API
----------------------------------------------------------------------]]

--- Check if comm restrictions are currently active
-- @return boolean
function RestrictionsMixin:IsRestricted()
    return self.restrictionsEnabled
end

--- Get the raw restriction bitmask
-- @return number
function RestrictionsMixin:GetRestrictionState()
    return self.restrictions
end

--- Get count of queued guaranteed messages (includes active replay buffer)
-- @return number
function RestrictionsMixin:GetQueuedCount()
    local count = #self.guaranteedQueue
    if self.replayBuffer then
        count = count + (#self.replayBuffer - self.replayIndex + 1)
    end
    return count
end

--- Check if a paced replay is in progress
-- @return boolean
function RestrictionsMixin:IsReplaying()
    return self.replayTicker ~= nil
end

--- Get replay progress
-- @return number, number, number - sent, remaining, total
function RestrictionsMixin:GetReplayProgress()
    if not self.replayBuffer then
        return 0, 0, 0
    end
    local remaining = math.max(0, #self.replayBuffer - self.replayIndex + 1)
    return self.replayStats.sent, remaining, self.replayStats.total
end

--[[--------------------------------------------------------------------
    Guaranteed Delivery Queue
----------------------------------------------------------------------]]

--- Queue a critical message for guaranteed delivery
-- Called by SendGuaranteed() during restrictions and by Send() for critical
-- commands during combat (WoW 12.0 blocks all addon messages in combat).
-- @param command string - Loothing.MsgType
-- @param data table - Message payload
-- @param target string|nil - Whisper target or nil for group
-- @param priority string|nil - "ALERT", "NORMAL", or "BULK"
function RestrictionsMixin:QueueGuaranteed(command, data, target, priority)
    self.guaranteedQueue[#self.guaranteedQueue + 1] = {
        command = command,
        data = data,
        target = target,
        priority = priority,
        queueTime = GetTime(),
    }

    Loothing:Debug("Queued guaranteed comm:", command, "(total:", #self.guaranteedQueue, ")")
end

--[[--------------------------------------------------------------------
    Paced Replay

    When restrictions lift, queued messages are replayed via a ticker
    that drains 1-3 messages per tick (100ms interval), adaptive to
    transport queue pressure. Priority-sorted: ALERT → NORMAL → BULK.

    If restrictions re-engage during replay, remaining messages are
    moved back to the guaranteed queue for later replay.
----------------------------------------------------------------------]]

--- Sort comparator: lower priority weight first, then FIFO by queue time
local function compareMsgs(a, b)
    local wa = PRIORITY_WEIGHT[a.priority or "NORMAL"] or 2
    local wb = PRIORITY_WEIGHT[b.priority or "NORMAL"] or 2
    if wa ~= wb then return wa < wb end
    return a.queueTime < b.queueTime
end

--- Start paced replay of guaranteed queue
-- Called by CommState when combat ends or restrictions lift (and not in combat).
-- In WoW 12.0, addon messages are blocked during combat, so replay must wait.
function RestrictionsMixin:ReplayQueue()
    if #self.guaranteedQueue == 0 then return end

    -- Safety: don't start replay during combat (WoW will drop messages)
    if InCombatLockdown() then
        Loothing:Debug("ReplayQueue deferred — still in combat lockdown")
        return
    end

    -- Cancel any existing replay
    if self.replayTicker then
        self.replayTicker:Cancel()
        self.replayTicker = nil
    end
    if self.replayBuffer then
        Loolib.TempTable:Release(self.replayBuffer)
        self.replayBuffer = nil
    end

    -- Sort by priority weight, then FIFO within same priority
    table.sort(self.guaranteedQueue, compareMsgs)

    -- Move to replay buffer (TempTable for GC efficiency)
    local buffer = Loolib.TempTable:Acquire()
    for i, msg in ipairs(self.guaranteedQueue) do
        buffer[i] = msg
    end
    wipe(self.guaranteedQueue)

    self.replayBuffer = buffer
    self.replayIndex = 1
    self.replayStats = { sent = 0, discarded = 0, total = #buffer }

    Loothing:Debug("Replaying", #buffer, "queued comms (paced)")
    self:TriggerEvent("OnReplayStarted", #buffer)

    -- Start ticker
    self.replayTicker = C_Timer.NewTicker(REPLAY_INTERVAL, function()
        self:ReplayTick()
    end)
end

--- Process one tick of the paced replay
function RestrictionsMixin:ReplayTick()
    -- Interrupt: restrictions re-engaged during replay
    if self.restrictionsEnabled then
        self:PauseReplay()
        return
    end

    -- Safety: WoW 12.0 blocks all addon messages during combat.
    -- If somehow replay started while in combat, pause immediately.
    if InCombatLockdown() then
        self:PauseReplay()
        return
    end

    -- Safety: Comm unavailable
    if not Loothing.Comm then
        self:FinishReplay()
        return
    end

    -- Adaptive per-tick limit based on transport queue pressure
    local pressure = Comm:GetQueuePressure()
    local maxThisTick
    if pressure > PRESSURE_HARD then
        maxThisTick = 1  -- Only ALERT under extreme pressure
    elseif pressure > PRESSURE_SOFT then
        maxThisTick = 2  -- Slow down under moderate pressure
    else
        maxThisTick = 3  -- Full speed when queue is clear
    end

    local buffer = self.replayBuffer
    local sent = 0
    local now = GetTime()

    while self.replayIndex <= #buffer and sent < maxThisTick do
        local msg = buffer[self.replayIndex]

        -- Discard stale messages (older than 5 minutes)
        if now - msg.queueTime >= GUARANTEED_TTL then
            Loothing:Debug("Discarded stale queued comm:", msg.command)
            self.replayStats.discarded = self.replayStats.discarded + 1
            self.replayIndex = self.replayIndex + 1
        else
            -- Under soft pressure, hold non-ALERT for next tick (don't skip, just wait)
            if pressure > PRESSURE_SOFT and (msg.priority or "NORMAL") ~= "ALERT" then
                break
            end

            Loothing.Comm:Send(msg.command, msg.data, msg.target, msg.priority)
            self:TriggerEvent("OnQueuedMessageSent", msg.command)
            self.replayStats.sent = self.replayStats.sent + 1
            self.replayIndex = self.replayIndex + 1
            sent = sent + 1
        end
    end

    -- Progress callback
    local remaining = #buffer - self.replayIndex + 1
    if remaining > 0 then
        self:TriggerEvent("OnReplayProgress", remaining, self.replayStats.total)
    end

    -- Completion check
    if self.replayIndex > #buffer then
        self:FinishReplay()
    end
end

--- Pause replay: cancel ticker, re-queue remaining messages
-- Called when restrictions re-engage during an active replay.
-- Appends unprocessed messages to the front of guaranteedQueue to preserve
-- ordering. Messages added to guaranteedQueue during the replay are kept.
function RestrictionsMixin:PauseReplay()
    if self.replayTicker then
        self.replayTicker:Cancel()
        self.replayTicker = nil
    end

    if not self.replayBuffer then return end

    -- Collect unprocessed replay messages
    local unprocessed = {}
    for i = self.replayIndex, #self.replayBuffer do
        unprocessed[#unprocessed + 1] = self.replayBuffer[i]
    end

    Loolib.TempTable:Release(self.replayBuffer)
    self.replayBuffer = nil
    self.replayIndex = 0

    -- Prepend unprocessed messages before any new messages added during replay
    local existingNew = self.guaranteedQueue
    self.guaranteedQueue = {}
    for _, msg in ipairs(unprocessed) do
        self.guaranteedQueue[#self.guaranteedQueue + 1] = msg
    end
    for _, msg in ipairs(existingNew) do
        self.guaranteedQueue[#self.guaranteedQueue + 1] = msg
    end

    Loothing:Debug("Replay paused,", #unprocessed, "messages re-queued")
    self:TriggerEvent("OnReplayPaused", #unprocessed)
end

--- Finish replay: cleanup and fire completion callback
function RestrictionsMixin:FinishReplay()
    if self.replayTicker then
        self.replayTicker:Cancel()
        self.replayTicker = nil
    end

    if self.replayBuffer then
        Loolib.TempTable:Release(self.replayBuffer)
        self.replayBuffer = nil
    end

    local stats = self.replayStats
    self.replayIndex = 0

    Loothing:Debug("Replay complete: sent=", stats.sent, "discarded=", stats.discarded)
    self:TriggerEvent("OnReplayComplete", stats.sent, stats.discarded)
end

--- Clear the guaranteed queue without sending (also cancels active replay)
function RestrictionsMixin:ClearQueue()
    wipe(self.guaranteedQueue)

    -- Cancel any active replay
    if self.replayTicker then
        self.replayTicker:Cancel()
        self.replayTicker = nil
    end
    if self.replayBuffer then
        Loolib.TempTable:Release(self.replayBuffer)
        self.replayBuffer = nil
    end
    self.replayIndex = 0
end

--[[--------------------------------------------------------------------
    Factory
----------------------------------------------------------------------]]

function ns.CreateRestrictions()
    local restrictions = CreateFromMixins(RestrictionsMixin)
    restrictions:Init()
    return restrictions
end

-- ns.RestrictionsMixin and ns.CreateRestrictions exported above
