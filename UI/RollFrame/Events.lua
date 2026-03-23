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

        -- AutoPass: check if item should be auto-passed before showing to player
        -- Skip if already responded (double-fire guard for re-broadcasts)
        local existingResp = self:GetItemResponse(item.guid)
        if not (existingResp and (existingResp.pending or existingResp.submitted)) then
            local AutoPass = ns.AutoPass
            if AutoPass and AutoPass:CheckItem(item) then
                self:AutoPassItem(item)
                return
            end
        end

        local foundIndex = nil
        for i, existingItem in ipairs(self.items) do
            if existingItem.guid == item.guid then
                foundIndex = i
                break
            end
        end

        if foundIndex then
            self.items[foundIndex] = item
            if foundIndex == self.currentItemIndex then
                self:DisplayItem(item)
            end
        else
            self:AddItem(item)
        end

        for i, existingItem in ipairs(self.items) do
            if existingItem.guid == item.guid then
                self:SwitchToItem(i)
                break
            end
        end

        -- Deferred AutoPass: if item info wasn't cached, retry when it loads
        if item.IsItemInfoLoaded and not item:IsItemInfoLoaded() then
            local AutoPass = ns.AutoPass
            if AutoPass then
                item:RegisterCallback("OnItemInfoLoaded", function()
                    item:UnregisterCallback("OnItemInfoLoaded", self)
                    -- Bail if session ended while item info was loading
                    if not Loothing.Session or not Loothing.Session:IsActive() then return end
                    -- Only retry if player hasn't already responded
                    local resp = self:GetItemResponse(item.guid)
                    if resp and (resp.pending or resp.submitted) then return end
                    if AutoPass:CheckItem(item) then
                        self:AutoPassItem(item)
                    end
                end, self)
            end
        end
    end, self)

    Loothing.Session:RegisterCallback("OnItemAwarded", function(_, item, _winner)
        self:UpdateSessionButtons()
        if self.item and self.item.guid == item.guid then
            self:SwitchToNextPendingItem()
        end
    end, self)

    Loothing.Session:RegisterCallback("OnVotingEnded", function(_, _item, _results)
        self:UpdateSessionButtons()
    end, self)

    Loothing.Session:RegisterCallback("OnSessionEnded", function()
        self.items = {}
        self.itemRolls = {}
        self.itemResponses = {}
        self:Close(false)
    end, self)

    Loothing.Session:RegisterCallback("OnPlayerResponseAck", function(_, itemGUID, success, _, sessionID)
        self:OnPlayerResponseAck(itemGUID, success, sessionID)
    end, self)
end

function RollFrameMixin:RegisterRollCapture()
    if not self.eventFrame then
        self.eventFrame = CreateFrame("Frame")
        self.eventFrame:RegisterEvent("CHAT_MSG_SYSTEM")
        self.eventFrame:SetScript("OnEvent", function(_, event, text)
            if event == "CHAT_MSG_SYSTEM" then
                self:OnChatMessage(text)
            end
        end)
    end
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
    Loothing.Session:UnregisterCallback("OnPlayerResponseAck", self)
end

--- Send an AUTOPASS response for an item and remove it from display
-- Used by both the immediate and deferred (OnItemInfoLoaded) autopass paths
-- @param item table - LoothingItem instance
function RollFrameMixin:AutoPassItem(item)
    local ml = Loothing.Session and Loothing.Session:GetMasterLooter()
    local sessionID = Loothing.Session and Loothing.Session:GetSessionID()
    if Loothing.Comm and ml then
        local ok = pcall(function()
            Loothing.Comm:SendPlayerResponse(
                item.guid,
                Loothing.SystemResponse.AUTOPASS,
                "",
                0, 1, 100,
                ml,
                sessionID
            )
        end)
        if ok then
            self:SetItemResponse(item.guid, Loothing.SystemResponse.AUTOPASS, "", false, true)
        else
            Loothing:Debug("AutoPass: failed to send response for", item.name or "?")
        end
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
            break
        end
    end
    self:UpdateSessionButtons()
    if self.item and self.item.guid == item.guid then
        if not self:SwitchToNextUnrespondedItem() then
            self:Close(true)
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

    -- FIX(Area4-4): Use SafeUnitName to avoid secret value tainting
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
