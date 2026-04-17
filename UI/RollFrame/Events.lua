--[[--------------------------------------------------------------------
    Loothing - RollFrame Event & Roll Handling
    Extracted to reduce monolith size in RollFrame.lua
----------------------------------------------------------------------]]

local _, ns = ...
local Loolib = LibStub("Loolib")
local Loothing = ns.Addon
local Utils = ns.Utils
local RollFrameMixin = ns.RollFrameMixin or {}
ns.RollFrameMixin = RollFrameMixin
local SecretUtil = Loolib.SecretUtil

--- Register for session events to auto-show
function RollFrameMixin:RegisterSessionEvents()
    if not Loothing.Session then return end

    Loothing.Session:RegisterCallback("OnVotingStarted", function(_, item, timeout)
        self.responseTimeout = timeout or Loothing.Timing.DEFAULT_VOTE_TIMEOUT or 30

        -- Ensure roll capture is active (re-registers if unregistered by prior session end)
        self:RegisterRollCapture()

        -- AutoPass: check if item should be auto-passed before showing to player.
        -- Skip if already responded (double-fire guard for re-broadcasts).
        local existingResp = self:GetItemResponse(item.guid)
        if not (existingResp and existingResp.submitted) then
            local AutoPass = ns.AutoPass
            if AutoPass and AutoPass:CheckItem(item) then
                self:AutoPassItem(item)
                return
            end
        end

        -- Find existing item by GUID, update or add, then switch to it
        self.items = self.items or {}
        local foundIndex = nil
        for i, existingItem in ipairs(self.items) do
            if existingItem.guid == item.guid then
                foundIndex = i
                break
            end
        end

        if foundIndex then
            self.items[foundIndex] = item
            -- SwitchToItem calls DisplayItem + UpdateSessionButtons
            self:SwitchToItem(foundIndex)
        else
            self:AddItem(item)
            -- AddItem appends to self.items, so the new item is at the end
            self:SwitchToItem(#self.items)
        end

        -- Cancel any deferred retries queued by a PRIOR voting item. This runs
        -- unconditionally — even when the new item is hot-cache and does not
        -- queue its own timers — because a hot item's arrival otherwise leaves
        -- stale timers + OnItemInfoLoaded callbacks running for the previous
        -- item and they can fire an autopass against an item the user has
        -- moved on from (or that was removed from the session). Cancellation
        -- bumps a token so any retry closure that wins a race against cancel
        -- becomes a no-op.
        self:CancelDeferredAutoPass()

        -- Deferred AutoPass: C_Item.GetItemInfo has its own cache separate from
        -- LoothingItem's loaded flag. For session-2+ items (batched arrival via
        -- SESSION_INIT, immediate VOTE_REQUEST) the server cache may be cold even
        -- when LoothingItem reports loaded — AutoPass.ShouldAutoPass silently
        -- returns false in that case, breaking the autopass funnel. Retry via
        -- OnItemInfoLoaded AND a short unconditional timer so neither path alone
        -- can strand us.
        if item.itemLink and not C_Item.GetItemInfo(item.itemLink) then
            local AutoPass = ns.AutoPass
            if AutoPass then
                -- Token captured by every retry closure below. CancelDeferredAutoPass
                -- bumps self.deferredAutoPassToken; any closure whose captured
                -- token no longer matches returns early.
                self.deferredAutoPassToken = {}
                local token = self.deferredAutoPassToken

                local retry = function(reason)
                    if self.deferredAutoPassToken ~= token then return end
                    if not Loothing.Session or not Loothing.Session:IsActive() then return end
                    -- Skip if the item has been removed from the session or
                    -- the frame has torn down its items table. AutoPassItem
                    -- would otherwise append a stale response.
                    if not self.items then return end
                    local found = false
                    for _, existingItem in ipairs(self.items) do
                        if existingItem.guid == item.guid then
                            found = true
                            break
                        end
                    end
                    if not found then return end
                    local resp = self:GetItemResponse(item.guid)
                    if resp and resp.submitted then return end
                    if AutoPass:CheckItem(item) then
                        Loothing:Debug("AutoPass: deferred fire (", reason, ") guid=", tostring(item.guid))
                        self:AutoPassItem(item)
                    end
                end

                if item.RegisterCallback then
                    self.deferredAutoPassItem = item
                    item:RegisterCallback("OnItemInfoLoaded", function()
                        -- Always unregister our listener whether or not we
                        -- still want to act — leaving it registered strongly
                        -- retains the item via the closure's upvalue.
                        if item.UnregisterCallback then
                            item:UnregisterCallback("OnItemInfoLoaded", self)
                        end
                        if self.deferredAutoPassToken ~= token then return end
                        retry("OnItemInfoLoaded")
                    end, self)
                end

                -- Timer fallbacks: even if OnItemInfoLoaded already fired before we
                -- registered, the C_Item cache warms within ~300ms of first access.
                -- The 800ms second pass covers slow tooltip scanners (classesFlag
                -- comes from a separate async tooltip scan, not from C_Item) on
                -- cold-cache items batched into SESSION_INIT. Use NewTimer so the
                -- session-end teardown below can cancel pending retries against
                -- items from the prior session.
                self.deferredAutoPassTimers = self.deferredAutoPassTimers or {}
                table.insert(self.deferredAutoPassTimers,
                    C_Timer.NewTimer(0.3, function() retry("timer-fast") end))
                table.insert(self.deferredAutoPassTimers,
                    C_Timer.NewTimer(0.8, function() retry("timer-slow") end))
            end
        end
    end, self)

    Loothing.Session:RegisterCallback("OnItemAwarded", function(_, item, _winner)
        self:UpdateSessionButtons()
        if self.item and self.item.guid == item.guid then
            self:SwitchToNextPendingItem()
        end
    end, self)

    Loothing.Session:RegisterCallback("OnVotingEnded", function(_, item, _results)
        self:UpdateSessionButtons()
        if item and item.guid then
            self:OnVotingEnded(item.guid)
        end
    end, self)

    Loothing.Session:RegisterCallback("OnSessionEnded", function()
        -- ResponseTracker clears its own state via its own OnSessionEnded listener.
        -- Unregister the roll-capture event frame so it does not keep
        -- listening to /roll chat messages after the session ends.
        self:UnregisterRollCapture()
        -- Cancel any deferred autopass retries queued by the active session.
        -- Closures capture the old session's `item`; letting them fire after
        -- the session flushes would enqueue an AUTOPASS for a guid that no
        -- longer exists in the new session.
        self:CancelDeferredAutoPass()
        self:Close(false, "session_ended")
    end, self)

    -- Response recovery: ResponseTracker handles resend logic directly.
    -- RollFrame only handles the "show frame" case when we haven't responded.
    if Loothing.Comm then
        Loothing.Comm:RegisterCallback("OnResponsePoll", function(_, data)
            self:OnResponsePoll(data)
        end, self)
    end

    -- Restriction state: lock submit button during encounter restrictions
    if Loothing.CommState then
        Loothing.CommState:RegisterCallback("OnStateChanged", function(_, newState)
            local restricted = (newState == Loothing.CommState.STATE_RESTRICTED)
            self:SetCombatLocked(restricted)
        end, self)
    end
end

--- Cancel any pending deferred autopass retry for a prior voting item.
-- Bumps the token so timer/OnItemInfoLoaded closures become no-ops, cancels
-- in-flight timers, and unregisters the item's OnItemInfoLoaded callback if
-- still pending. Safe to call when nothing is pending.
function RollFrameMixin:CancelDeferredAutoPass()
    -- Bump the token first so any closure that races with this block sees
    -- a mismatched token and returns early.
    self.deferredAutoPassToken = nil

    if self.deferredAutoPassTimers then
        for _, t in ipairs(self.deferredAutoPassTimers) do
            if t and t.Cancel then t:Cancel() end
        end
        self.deferredAutoPassTimers = nil
    end

    -- Unregister the prior item's OnItemInfoLoaded callback so a late cache
    -- warm does not fire a retry for the wrong item.
    if self.deferredAutoPassItem then
        local priorItem = self.deferredAutoPassItem
        self.deferredAutoPassItem = nil
        if priorItem.UnregisterCallback then
            priorItem:UnregisterCallback("OnItemInfoLoaded", self)
        end
    end
end

function RollFrameMixin:RegisterRollCapture()
    if not self.eventFrame then
        self.eventFrame = CreateFrame("Frame")
        self.eventFrame:SetScript("OnEvent", function(_, event, text)
            if event == "CHAT_MSG_SYSTEM" then
                self:OnChatMessage(text)
            end
        end)
    end
    -- Always (re-)register — UnregisterRollCapture unregisters the event but keeps the frame
    self.eventFrame:RegisterEvent("CHAT_MSG_SYSTEM")
end

function RollFrameMixin:UnregisterRollCapture()
    if self.eventFrame then
        self.eventFrame:UnregisterEvent("CHAT_MSG_SYSTEM")
    end
end

function RollFrameMixin:UnregisterSessionEvents()
    if not Loothing.Session then return end
    Loothing.Session:UnregisterCallback("OnVotingStarted", self)
    Loothing.Session:UnregisterCallback("OnItemAwarded", self)
    Loothing.Session:UnregisterCallback("OnVotingEnded", self)
    Loothing.Session:UnregisterCallback("OnSessionEnded", self)
    if Loothing.Comm then
        Loothing.Comm:UnregisterCallback("OnResponsePoll", self)
    end
    if Loothing.CommState then
        Loothing.CommState:UnregisterCallback("OnStateChanged", self)
    end
end

--- Handle RESPONSE_POLL from ML: resend our response if we're in the missing list
-- @param data table - { itemGUID, sessionID, missing = { "Player1", ... } }
--- Handle RESPONSE_POLL from ML (RollFrame side).
-- ResponseTracker handles the actual resend logic. RollFrame only ensures
-- the frame is visible if the player hasn't responded yet.
-- @param data table - { itemGUID, sessionID, missing = { "Player1", ... } }
function RollFrameMixin:OnResponsePoll(data)
    if not data or not data.itemGUID or not data.missing then return end

    local playerName = Utils.GetPlayerFullName()
    local isInMissing = false
    for _, name in ipairs(data.missing) do
        if Utils.IsSamePlayer(name, playerName) then
            isInMissing = true
            break
        end
    end
    if not isInMissing then return end

    -- If we haven't interacted with this item at all, make sure the frame is visible.
    -- HasLocalResponse covers submitted and queued (player clicked a button).
    local tracker = Loothing.ResponseTracker
    if tracker and not tracker:HasLocalResponse(data.itemGUID) then
        if self.frame and not self.frame:IsShown() then
            tracker:CheckAndReshowFrame()
        end
    end
end

--- Send an AUTOPASS response for an item and remove it from display
-- Used by both the immediate and deferred (OnItemInfoLoaded) autopass paths.
-- Auto-pass responses are batched: multiple items accumulate over a 200ms
-- window and flush as a single RESPONSE_BATCH (same path as manual responses).
-- @param item table - LoothingItem instance
function RollFrameMixin:AutoPassItem(item)
    if Loothing.Comm and Loothing.Session then
        -- Include gear inline so the ML/processor never falls back to PIQ/PIS.
        local gear1Link, gear2Link, gear1ilvl, gear2ilvl
        if item.equipSlot and Loothing.Session.GetEquippedGearForSlot then
            gear1Link, gear2Link, gear1ilvl, gear2ilvl =
                Loothing.Session:GetEquippedGearForSlot(item.equipSlot)
        end
        -- Buffer for batch delivery (same path as manual SendResponse)
        self.pendingBatch = self.pendingBatch or {}
        self.pendingBatch[#self.pendingBatch + 1] = {
            itemGUID = item.guid,
            response = Loothing.SystemResponse.AUTOPASS,
            note = nil,
            roll = 0,
            rollMin = 1,
            rollMax = 100,
            gear1Link = gear1Link,
            gear2Link = gear2Link,
            gear1ilvl = gear1ilvl or 0,
            gear2ilvl = gear2ilvl or 0,
        }
        -- Debounce: flush after 200ms (same window as SendResponse)
        if self.batchTimer then self.batchTimer:Cancel() end
        self.batchTimer = C_Timer.NewTimer(0.2, function()
            self:FlushResponseBatch()
        end)
        self:SetItemResponse(item.guid, Loothing.SystemResponse.AUTOPASS, "", true)
    end
    -- Notify player unless silent
    if not (Loothing.Settings and Loothing.Settings:Get("autoPass.silent", false)) then
        local AutoPass = ns.AutoPass
        local autoPassReason
        if AutoPass then
            _, autoPassReason = AutoPass:ShouldAutoPass(item.itemLink)
        end
        Loothing:Print(string.format("Auto-passed: %s (%s)",
            item.itemLink or item.name or "?", autoPassReason or "unusable"))
    end
    -- Remove from display and advance to next item
    for i, existingItem in ipairs(self.items) do
        if existingItem.guid == item.guid then
            table.remove(self.items, i)
            -- Adjust currentItemIndex after removal to keep it pointing at the correct item
            if i < self.currentItemIndex then
                self.currentItemIndex = self.currentItemIndex - 1
            elseif i == self.currentItemIndex then
                self.currentItemIndex = math.min(self.currentItemIndex, math.max(1, #self.items))
            end
            break
        end
    end
    self:UpdateSessionButtons()
    if self.item and self.item.guid == item.guid then
        if not self:SwitchToNextUnrespondedItem() then
            self:Close(true, "autopass")
        end
    end
end

--- Parse roll message from chat
function RollFrameMixin:OnChatMessage(text)
    if not text then return end
    -- Skip hardware-tainted secret values (death messages etc.)
    if SecretUtil.IsSecretValue(text) then return end
    local safeText = tostring(text)

    local hasPendingItem = self.pendingRollGUID ~= nil
    if not hasPendingItem and (not self.frame or not self.frame:IsShown()) then
        return
    end

    if self.pendingRollGUID and self.pendingRollStarted[self.pendingRollGUID] then
        if GetTime() - self.pendingRollStarted[self.pendingRollGUID] > 15 then
            self.pendingRollStarted[self.pendingRollGUID] = nil
            self.pendingRollGUID = nil
            return
        end
    end

    local playerName, roll, minRoll, maxRoll = string.match(safeText, "(.+) rolls (%d+) %((%d+)%-(%d+)%)")
    if not playerName then return end

    -- Use SafeUnitName to avoid secret value tainting
    local myFullName = Utils and Utils.GetPlayerFullName and Utils.GetPlayerFullName() or Loolib.SecretUtil.SafeUnitName("player")
    if Utils and Utils.IsSamePlayer then
        if not Utils.IsSamePlayer(playerName, myFullName) then
            return
        end
    else
        if playerName ~= myFullName and playerName ~= Loolib.SecretUtil.SafeUnitName("player") then
            return
        end
    end

    roll = tonumber(roll)
    minRoll = tonumber(minRoll) or 1
    maxRoll = tonumber(maxRoll) or 100

    local itemGUID = self.pendingRollGUID or (self.item and self.item.guid)
    if itemGUID then
        self:SetItemRoll(itemGUID, roll, minRoll, maxRoll)
    end
    if itemGUID and self.pendingRollStarted then
        self.pendingRollStarted[itemGUID] = nil
    end
    self.pendingRollGUID = nil

    if self.item and self.item.guid == itemGUID then
        self:UpdateRollDisplay()
    end

    self:TriggerEvent("OnRollCompleted", playerName, roll, minRoll, maxRoll)
end
