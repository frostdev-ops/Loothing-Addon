--[[--------------------------------------------------------------------
    Loothing - Loot Council Addon for WoW 12.0+
    Restrictions - Encounter addon restriction handling

    WoW fires ADDON_RESTRICTION_STATE_CHANGED during encounters and
    challenge modes. When restrictions are active, addon comms are
    silently dropped. This module:
    - Tracks restriction state via bitmask
    - Queues critical ("guaranteed") comms during restrictions
    - Replays queued comms when restrictions lift
    - Fires callbacks so UI can show restriction indicator
----------------------------------------------------------------------]]

local _, ns = ...
local Loothing = ns.Addon
local Loolib = LibStub("Loolib")
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

local RESTRICTION_EVENTS = {
    "OnRestrictionChanged",     -- (active: boolean)
    "OnQueuedMessageSent",      -- (command: string)
}

--- Initialize restriction handler
function RestrictionsMixin:Init()
    Loolib.CallbackRegistryMixin.OnLoad(self)
    self:GenerateCallbackEvents(RESTRICTION_EVENTS)

    self.restrictions = 0               -- Current restriction bitmask
    self.restrictionsEnabled = false     -- Convenience flag
    self.guaranteedQueue = {}            -- Queued messages awaiting replay

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

        -- Replay queue when restrictions lift
        if not self.restrictionsEnabled then
            self:ReplayQueue()
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

--- Get count of queued guaranteed messages
-- @return number
function RestrictionsMixin:GetQueuedCount()
    return #self.guaranteedQueue
end

--[[--------------------------------------------------------------------
    Guaranteed Delivery Queue
----------------------------------------------------------------------]]

--- Queue a critical message for guaranteed delivery
-- Called by CommMixin:SendGuaranteed() when restrictions are active
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

--- Replay all queued guaranteed messages
-- Called automatically when restrictions lift
function RestrictionsMixin:ReplayQueue()
    if #self.guaranteedQueue == 0 then return end

    Loothing:Debug("Replaying", #self.guaranteedQueue, "queued comms")

    for _, msg in ipairs(self.guaranteedQueue) do
        -- Discard messages older than 5 minutes (stale)
        if GetTime() - msg.queueTime < 300 then
            if Loothing.Comm then
                Loothing.Comm.Send(Loothing.Comm, msg.command, msg.data, msg.target, msg.priority)
            end
            self:TriggerEvent("OnQueuedMessageSent", msg.command)
        else
            Loothing:Debug("Discarded stale queued comm:", msg.command)
        end
    end

    wipe(self.guaranteedQueue)
end

--- Clear the guaranteed queue without sending
function RestrictionsMixin:ClearQueue()
    wipe(self.guaranteedQueue)
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
