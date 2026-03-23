--[[--------------------------------------------------------------------
    Loothing - Group Loot Events
    Event registration and roll handling entry point.
----------------------------------------------------------------------]]

local _, ns = ...
local Loothing = ns.Addon
local Utils = ns.Utils
local CreateFrame = CreateFrame
local GetLootRollItemLink = GetLootRollItemLink
local IsInGroup = IsInGroup
local RollOnLoot = RollOnLoot
local time = time

ns.GroupLootMixin = ns.GroupLootMixin or {}
ns.GroupLootRoll = ns.GroupLootRoll or {}

local GroupLootMixin = ns.GroupLootMixin
local GroupLootRoll = ns.GroupLootRoll

--- Enable the group loot handler.
-- Registers for START_LOOT_ROLL event (setting controls actual behavior)
function GroupLootMixin:Enable()
    if not self.eventFrame then
        self.eventFrame = CreateFrame("Frame")
        self.eventFrame:SetScript("OnEvent", function(_, event, ...)
            if event == "START_LOOT_ROLL" then
                self:OnStartLootRoll(event, ...)
            end
        end)
    end

    self.eventFrame:RegisterEvent("START_LOOT_ROLL")
end

--- Disable the group loot handler.
function GroupLootMixin:Disable()
    if self.eventFrame then
        self.eventFrame:UnregisterEvent("START_LOOT_ROLL")
    end
end

--- Handle START_LOOT_ROLL event.
-- @param event string - Event name
-- @param rollID number - The roll ID for this loot item
function GroupLootMixin:OnStartLootRoll(_, rollID)
    local rolls = GroupLootRoll

    if not Loothing.Settings:Get("groupLoot.enabled") then
        return
    end

    if Utils.GetEffectiveGroupLootMode() == "passive" then
        Loothing:Debug("Group loot passive mode active — skipping auto-roll for rollID", rollID)
        return
    end

    if not IsInGroup() then
        return
    end

    -- Only auto-roll when a loot council session is active
    if not Loothing.Session or not Loothing.Session:IsActive() then
        return
    end

    local link = GetLootRollItemLink(rollID)
    if not link then
        return
    end

    local rollInfo = Loothing.GetLootRollItemData(rollID)
    if not rollInfo then
        return
    end

    local quality = rollInfo.quality
    local canNeed = rollInfo.canNeed
    local canTransmog = rollInfo.canTransmog

    -- Skip below threshold
    local qualityThreshold = Loothing.Settings:Get("groupLoot.qualityThreshold") or Enum.ItemQuality.Epic
    if quality and quality < qualityThreshold then
        return
    end

    -- Skip legendary items - let player decide manually
    if quality and quality >= Enum.ItemQuality.Legendary then
        return
    end

    local isMasterLooter = Loothing.Settings:IsMasterLooter()
    local rollType

    if isMasterLooter then
        if canNeed then
            rollType = rolls.NEED
        elseif canTransmog then
            rollType = rolls.TRANSMOG
        else
            rollType = rolls.GREED
        end
    else
        rollType = rolls.PASS
        Loothing:Debug("Auto-passing group loot roll for ML collection:", link)
    end

    self.pendingRolls[rollID] = {
        link = link,
        rollType = rollType,
        timestamp = time(),
    }

    C_Timer.After(0.05, function()
        RollOnLoot(rollID, rollType)
        self:HideGroupLootFrame(rollID)
        self:LogRoll(rollID, link, rollType, isMasterLooter)
    end)
end
