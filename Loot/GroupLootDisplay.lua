--[[--------------------------------------------------------------------
    Loothing - Group Loot Display & Logging
    UI cleanup and debug logging for auto-rolls.
----------------------------------------------------------------------]]

LoothingGroupLootMixin = LoothingGroupLootMixin or {}

--- Hide the GroupLootFrame for a specific rollID.
-- @param rollID number - The roll ID
function LoothingGroupLootMixin:HideGroupLootFrame(rollID)
    if not Loothing.Settings:Get("groupLoot.hideFrames") then
        return
    end

    for i = 1, 4 do
        local frame = _G["GroupLootFrame" .. i]
        if frame and frame:IsShown() and frame.rollID == rollID then
            GroupLootContainer_RemoveFrame(GroupLootContainer, frame)
            break
        end
    end
end

--- Log the roll action for debugging.
-- @param rollID number
-- @param link string - Item link
-- @param rollType number - Roll type used
-- @param isMasterLooter boolean
function LoothingGroupLootMixin:LogRoll(rollID, link, rollType, isMasterLooter)
    local rollName = LoothingGroupLootRollNames[rollType] or "Unknown"
    local role = isMasterLooter and "ML" or "Raider"

    Loothing:Debug(string.format("[GroupLoot] [%s] Auto-rolled %s on %s", role, rollName, link))

    self.pendingRolls[rollID] = nil
end

