--[[--------------------------------------------------------------------
    Loothing - Group Loot Events
    Event registration and roll handling entry point.
----------------------------------------------------------------------]]

LoothingGroupLootMixin = LoothingGroupLootMixin or {}

--- Enable the group loot handler.
-- Registers for START_LOOT_ROLL event (setting controls actual behavior)
function LoothingGroupLootMixin:Enable()
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
function LoothingGroupLootMixin:Disable()
    if self.eventFrame then
        self.eventFrame:UnregisterEvent("START_LOOT_ROLL")
    end
end

--- Handle START_LOOT_ROLL event.
-- @param event string - Event name
-- @param rollID number - The roll ID for this loot item
function LoothingGroupLootMixin:OnStartLootRoll(event, rollID)
    local rolls = LoothingGroupLootRoll

    if not Loothing.Settings:Get("groupLoot.enabled") then
        return
    end

    if not IsInGroup() then
        return
    end

    local link = GetLootRollItemLink(rollID)
    if not link then
        return
    end

    local _, _, _, quality, _, canNeed, _, _, _, _, _, _, canTransmog = GetLootRollItemInfo(rollID)

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

