--[[--------------------------------------------------------------------
    Loothing - Loot Council Addon for WoW 12.0+
    ResponseTracker - Session-scoped response state engine

    The single source of truth for the local player's per-item response
    and roll state. Survives frame close, combat transitions, and frame
    re-open. Only cleared on session end.

    Previously this state lived on RollFrame and was wiped on Close().
    Now RollFrame delegates all response/roll access here.
----------------------------------------------------------------------]]

local _, ns = ...
local Loolib = LibStub("Loolib")
local Loothing = ns.Addon
local Utils = ns.Utils
local Protocol = ns.Protocol
local CreateFromMixins = Loolib.CreateFromMixins
local GetTime = GetTime

ns.ResponseTrackerMixin = ns.ResponseTrackerMixin or {}

--[[--------------------------------------------------------------------
    ResponseTrackerMixin
----------------------------------------------------------------------]]

local ResponseTrackerMixin = CreateFromMixins(Loolib.CallbackRegistryMixin, ns.ResponseTrackerMixin)
ns.ResponseTrackerMixin = ResponseTrackerMixin

local TRACKER_EVENTS = {
    "OnResponseChanged",          -- (guid, responseData)
    "OnRollChanged",              -- (guid, rollData)
    "OnUnrespondedCountChanged",  -- (count)
}

--- Initialize the response tracker
function ResponseTrackerMixin:Init()
    Loolib.CallbackRegistryMixin.OnLoad(self)
    self:GenerateCallbackEvents(TRACKER_EVENTS)

    -- Per-item response state (keyed by item GUID)
    self.responses = {}     -- { [guid] = { response, note, submitted, pending, retryCount } }

    -- Per-item roll state (keyed by item GUID)
    self.rolls = {}         -- { [guid] = { roll, min, max } }

    -- Ack timers (keyed by item GUID)
    self.ackTimers = {}     -- { [guid] = timerHandle }

    -- Items currently in VOTING state (keyed by item GUID)
    self.votingItems = {}   -- { [guid] = itemRef }

    -- Session scoping
    self.sessionID = nil

    -- CLIENT_READY debounce
    self.lastReadyTime = 0

    -- Gentle re-show timer
    self.reshowTimer = nil

    -- Combat-end recheck timer
    self.combatRecheckTimer = nil

    self:RegisterSessionEvents()
    self:RegisterCommEvents()
end

--[[--------------------------------------------------------------------
    Session Lifecycle
----------------------------------------------------------------------]]

function ResponseTrackerMixin:RegisterSessionEvents()
    if not Loothing.Session then return end

    Loothing.Session:RegisterCallback("OnSessionStarted", function(_, sessionID)
        self:OnSessionStarted(sessionID)
    end, self)

    Loothing.Session:RegisterCallback("OnSessionEnded", function()
        self:Clear()
    end, self)

    Loothing.Session:RegisterCallback("OnVotingStarted", function(_, item)
        if item and item.guid then
            self:TrackVotingItem(item.guid, item)
        end
    end, self)

    Loothing.Session:RegisterCallback("OnItemAwarded", function(_, item)
        if item and item.guid then
            self:UntrackVotingItem(item.guid)
        end
    end, self)

    Loothing.Session:RegisterCallback("OnVotingEnded", function(_, item)
        if item and item.guid then
            self:UntrackVotingItem(item.guid)
        end
    end, self)
end

function ResponseTrackerMixin:RegisterCommEvents()
    if not Loothing.Comm then return end

    -- Handle RESPONSE_POLL resend directly (doesn't need RollFrame open)
    Loothing.Comm:RegisterCallback("OnResponsePoll", function(_, data)
        self:HandleResponsePoll(data)
    end, self)
end

function ResponseTrackerMixin:OnSessionStarted(sessionID)
    if sessionID ~= self.sessionID then
        self:Clear()
        self.sessionID = sessionID
    end
end

--[[--------------------------------------------------------------------
    Response State
----------------------------------------------------------------------]]

--- Get the response for an item
-- @param guid string
-- @return table|nil - { response, note, submitted, pending, retryCount }
function ResponseTrackerMixin:GetResponse(guid)
    return self.responses[guid]
end

--- Set the response for an item
-- @param guid string
-- @param response any - Response ID
-- @param note string
-- @param submitted boolean
-- @param pending boolean
-- @param retryCount number|nil
function ResponseTrackerMixin:SetResponse(guid, response, note, submitted, pending, retryCount)
    local existing = self.responses[guid]
    self.responses[guid] = {
        response = response,
        note = note or "",
        submitted = submitted == true,
        pending = pending == true,
        retryCount = retryCount or (existing and existing.retryCount) or 0,
    }

    if pending then
        self:StartAckTimeout(guid)
    else
        self:ClearAckTimeout(guid)
    end

    self:TriggerEvent("OnResponseChanged", guid, self.responses[guid])
    self:FireUnrespondedCount()
end

--- Check if the player has submitted a response for an item
-- @param guid string
-- @return boolean
function ResponseTrackerMixin:HasResponded(guid)
    local r = self.responses[guid]
    return r and r.submitted == true
end

--[[--------------------------------------------------------------------
    Roll State
----------------------------------------------------------------------]]

--- Get the roll for an item
-- @param guid string
-- @return number|nil, number|nil, number|nil - roll, min, max
function ResponseTrackerMixin:GetRoll(guid)
    local r = self.rolls[guid]
    if r then
        return r.roll, r.min, r.max
    end
    return nil, nil, nil
end

--- Set the roll for an item
-- @param guid string
-- @param roll number
-- @param minRoll number
-- @param maxRoll number
function ResponseTrackerMixin:SetRoll(guid, roll, minRoll, maxRoll)
    self.rolls[guid] = {
        roll = roll,
        min = minRoll or 1,
        max = maxRoll or 100,
    }
    self:TriggerEvent("OnRollChanged", guid, self.rolls[guid])
end

--[[--------------------------------------------------------------------
    Voting Item Tracking
----------------------------------------------------------------------]]

--- Track an item that entered VOTING state
-- @param guid string
-- @param itemRef table - LoothingItem reference
function ResponseTrackerMixin:TrackVotingItem(guid, itemRef)
    self.votingItems[guid] = itemRef
    self:FireUnrespondedCount()
end

--- Remove an item from voting tracking (awarded, skipped, cancelled)
-- @param guid string
function ResponseTrackerMixin:UntrackVotingItem(guid)
    if self.votingItems[guid] then
        self.votingItems[guid] = nil
        self:FireUnrespondedCount()
    end
end

--- Check if the player has a local response for an item (submitted, pending, or queued).
-- Used by frame-reshow logic: if the player already clicked a button, don't nag them.
-- @param guid string
-- @return boolean
function ResponseTrackerMixin:HasLocalResponse(guid)
    local r = self.responses[guid]
    return r and (r.submitted or r.pending or r.response ~= nil)
end

--- Get all VOTING items the player hasn't responded to
-- @return table - Array of { guid = string, item = itemRef }
function ResponseTrackerMixin:GetUnrespondedVotingItems()
    local result = {}
    for guid, itemRef in pairs(self.votingItems) do
        if not self:HasLocalResponse(guid) then
            -- Verify item is still actually voting
            if itemRef.IsVoting and itemRef:IsVoting() then
                result[#result + 1] = { guid = guid, item = itemRef }
            end
        end
    end
    return result
end

--- Count of unresponded VOTING items
-- @return number
function ResponseTrackerMixin:GetUnrespondedCount()
    local count = 0
    for guid, itemRef in pairs(self.votingItems) do
        if not self:HasLocalResponse(guid) then
            if itemRef.IsVoting and itemRef:IsVoting() then
                count = count + 1
            end
        end
    end
    return count
end

--- Get GUIDs of items the player has responded to (for CLIENT_READY payload).
-- Includes submitted, pending, and queued responses — if the player clicked
-- a button, the ML should not poll for this item even if the ACK hasn't
-- round-tripped yet.
-- @return table - Array of GUID strings
function ResponseTrackerMixin:GetRespondedGUIDs()
    local result = {}
    for guid, data in pairs(self.responses) do
        if data.submitted or data.pending or data.response ~= nil then
            result[#result + 1] = guid
        end
    end
    return result
end

--- Fire the unresponded count changed event
function ResponseTrackerMixin:FireUnrespondedCount()
    self:TriggerEvent("OnUnrespondedCountChanged", self:GetUnrespondedCount())
end

--[[--------------------------------------------------------------------
    ACK Timeout (moved from RollFrame)
----------------------------------------------------------------------]]

--- Start an ack timeout for a pending response.
-- First timeout: auto-retry the same response (5s timer).
-- Second timeout: mark as failed, allow manual resubmit.
-- During combat, the timeout is deferred — the response is combat-queued and
-- will be sent when combat ends, so timing out would be a false alarm.
-- @param guid string
function ResponseTrackerMixin:StartAckTimeout(guid)
    if not guid then return end
    self:ClearAckTimeout(guid)

    local data = self.responses[guid]
    local retries = data and data.retryCount or 0

    local timeout
    if retries == 0 then
        timeout = (Loothing.Timing and Loothing.Timing.DEFAULT_VOTE_TIMEOUT) or 30
        timeout = math.min(timeout, 10)
    else
        timeout = Loothing.Timing and Loothing.Timing.ACK_AUTO_RETRY_TIMEOUT or 5
    end

    self.ackTimers[guid] = C_Timer.NewTimer(timeout, function()
        self.ackTimers[guid] = nil

        local responseData = self.responses[guid]
        if not responseData or not responseData.pending then return end

        -- During combat, messages are queued in the combat defer queue and will
        -- be sent when combat ends. Don't timeout or show error — just restart
        -- the timer so it fires after combat instead.
        if InCombatLockdown() then
            Loothing:Debug("ResponseTracker: ACK timeout deferred (in combat) for", guid)
            self:StartAckTimeout(guid)
            return
        end

        if responseData.retryCount == 0 then
            -- First timeout: auto-retry
            Loothing:Debug("ResponseTracker: ACK timeout for", guid, "- auto-retrying")
            responseData.retryCount = 1
            self:AutoRetryResponse(guid, responseData)
        else
            -- Second timeout: unlock for manual resubmit
            Loothing:Error("Response may not have reached the Master Looter. Click Submit to resend.")
            self:SetResponse(guid, responseData.response, responseData.note, false, false, responseData.retryCount)
        end
    end)
end

--- Clear a pending ack timer
-- @param guid string
function ResponseTrackerMixin:ClearAckTimeout(guid)
    local timer = guid and self.ackTimers[guid]
    if timer then
        timer:Cancel()
        self.ackTimers[guid] = nil
    end
end

--- Auto-retry sending the same response data after first ACK timeout
-- @param guid string
-- @param data table - The existing response entry
function ResponseTrackerMixin:AutoRetryResponse(guid, data)
    local ml = Loothing.Session and Loothing.Session:GetMasterLooter()
    if not (Loothing.Comm and ml) then
        self:SetResponse(guid, data.response, data.note, false, false, data.retryCount)
        return
    end

    local roll, rollMin, rollMax = self:GetRoll(guid)

    local ok = pcall(function()
        Loothing.Comm:SendPlayerResponse(
            guid,
            data.response,
            data.note,
            roll or 0,
            rollMin or 1,
            rollMax or 100,
            ml,
            Loothing.Session and Loothing.Session:GetSessionID()
        )
    end)

    if ok then
        self:SetResponse(guid, data.response, data.note, false, true, data.retryCount)
    else
        self:SetResponse(guid, data.response, data.note, false, false, data.retryCount)
    end
end

--[[--------------------------------------------------------------------
    RESPONSE_POLL Handling (moved from RollFrame Events.lua)
----------------------------------------------------------------------]]

--- Handle RESPONSE_POLL from ML: resend our response if we're in the missing list
-- Works even when RollFrame is closed because we have the response data.
-- @param data table - { itemGUID, sessionID, missing = { "Player1", ... } }
function ResponseTrackerMixin:HandleResponsePoll(data)
    if not data or not data.itemGUID or not data.missing then return end

    if data.sessionID and Loothing.Session and not Loothing.Session:IsCurrentSession(data.sessionID) then
        return
    end

    local playerName = Utils.GetPlayerFullName()
    local isInMissing = false
    for _, name in ipairs(data.missing) do
        if Utils.IsSamePlayer(name, playerName) then
            isInMissing = true
            break
        end
    end
    if not isInMissing then return end

    -- Check if we have a local response to resend
    local responseData = self:GetResponse(data.itemGUID)
    if responseData and responseData.response then
        Loothing:Debug("ResponseTracker: ML poll — resending response for", data.itemGUID)
        local ml = Loothing.Session and Loothing.Session:GetMasterLooter()
        if Loothing.Comm and ml then
            local roll, rollMin, rollMax = self:GetRoll(data.itemGUID)
            pcall(function()
                Loothing.Comm:SendPlayerResponse(
                    data.itemGUID,
                    responseData.response,
                    responseData.note,
                    roll or 0, rollMin or 1, rollMax or 100,
                    ml,
                    Loothing.Session and Loothing.Session:GetSessionID()
                )
            end)
        end
    else
        -- We haven't responded — show the frame so the player can
        Loothing:Print("The Master Looter is waiting for your response!")
        self:CheckAndReshowFrame()
    end
end

--[[--------------------------------------------------------------------
    CLIENT_READY (combat-end notification to ML)
----------------------------------------------------------------------]]

--- Called when the local player leaves combat during an active session.
-- Sends CLIENT_READY to ML (debounced) and schedules frame re-check.
function ResponseTrackerMixin:OnCombatEnd()
    -- Schedule frame recheck after short delay (let sync arrive first)
    local recheckDelay = Loothing.Timing and Loothing.Timing.COMBAT_END_RECHECK_DELAY or 2
    if self.combatRecheckTimer then
        self.combatRecheckTimer:Cancel()
    end
    self.combatRecheckTimer = C_Timer.NewTimer(recheckDelay, function()
        self.combatRecheckTimer = nil
        self:CheckAndReshowFrame()
    end)

    -- Send CLIENT_READY to ML (debounced)
    self:SendClientReady()
end

--- Send CLIENT_READY to ML with our response state
function ResponseTrackerMixin:SendClientReady()
    if not Loothing.Session or not Loothing.Session:IsActive() then return end
    if Loothing.Session:IsMasterLooter() then return end
    if not Loothing.Comm then return end

    -- Debounce: rapid combat toggling
    local debounce = Loothing.Timing and Loothing.Timing.CLIENT_READY_DEBOUNCE or 5
    local now = GetTime()
    if now - self.lastReadyTime < debounce then return end
    self.lastReadyTime = now

    local ml = Loothing.Session:GetMasterLooter()
    if not ml then return end

    Loothing.Comm:Send(Loothing.MsgType.CLIENT_READY, {
        sessionID = self.sessionID,
        responded = self:GetRespondedGUIDs(),
    }, ml, "NORMAL")

    Loothing:Debug("ResponseTracker: sent CLIENT_READY to", ml)
end

--[[--------------------------------------------------------------------
    Frame Reappearance
----------------------------------------------------------------------]]

--- Check for unresponded voting items and re-show RollFrame if needed
function ResponseTrackerMixin:CheckAndReshowFrame()
    -- Don't show during combat
    if InCombatLockdown() then return end

    local unresponded = self:GetUnrespondedVotingItems()
    if #unresponded == 0 then return end

    local rollFrame = Loothing.UI and Loothing.UI.RollFrame
    if not rollFrame then return end

    -- Don't interrupt if frame is already showing
    if rollFrame.frame and rollFrame.frame:IsShown() then return end

    -- Populate frame with unresponded items
    local items = {}
    for _, entry in ipairs(unresponded) do
        items[#items + 1] = entry.item
    end

    if #items > 0 then
        rollFrame:SetItems(items)
        rollFrame:Show()
        Loothing:Debug("ResponseTracker: re-showed RollFrame with", #items, "unresponded items")
    end
end

--- Schedule a gentle re-show after the player closes the frame with pending items
function ResponseTrackerMixin:ScheduleReshow()
    if self.reshowTimer then
        self.reshowTimer:Cancel()
        self.reshowTimer = nil
    end

    -- Check user setting
    if Loothing.Settings and not Loothing.Settings:Get("rollFrame.autoReshow", true) then
        return
    end

    local delay = Loothing.Timing and Loothing.Timing.FRAME_REOPEN_DELAY or 30
    self.reshowTimer = C_Timer.NewTimer(delay, function()
        self.reshowTimer = nil
        self:GentleReshow()
    end)
end

--- Gently re-show frame if conditions are met
function ResponseTrackerMixin:GentleReshow()
    if InCombatLockdown() then return end
    if self:GetUnrespondedCount() == 0 then return end

    local rollFrame = Loothing.UI and Loothing.UI.RollFrame
    if rollFrame and rollFrame.frame and rollFrame.frame:IsShown() then return end

    self:CheckAndReshowFrame()
end

--[[--------------------------------------------------------------------
    Cleanup
----------------------------------------------------------------------]]

--- Clear all state (called on session end)
function ResponseTrackerMixin:Clear()
    self.sessionID = nil
    wipe(self.responses)
    wipe(self.rolls)
    wipe(self.votingItems)

    -- Cancel all ack timers
    for guid, timer in pairs(self.ackTimers) do
        timer:Cancel()
    end
    wipe(self.ackTimers)

    -- Cancel reshow/recheck timers
    if self.reshowTimer then
        self.reshowTimer:Cancel()
        self.reshowTimer = nil
    end
    if self.combatRecheckTimer then
        self.combatRecheckTimer:Cancel()
        self.combatRecheckTimer = nil
    end

    self:FireUnrespondedCount()
end

--[[--------------------------------------------------------------------
    Factory
----------------------------------------------------------------------]]

function ns.CreateResponseTracker()
    local tracker = CreateFromMixins(ResponseTrackerMixin)
    tracker:Init()
    return tracker
end
