local _, ns = ...
local Loothing = ns.Addon

ns.GroupLootMixin = ns.GroupLootMixin or {}

local GroupLootMixin = ns.GroupLootMixin
local GroupLootRollNames = ns.GroupLootRollNames or {}

--[[--------------------------------------------------------------------
    Loothing - Group Loot Display & Logging
    UI cleanup and debug logging for auto-rolls.
----------------------------------------------------------------------]]

--- Hide the GroupLootFrame for a specific rollID.
-- @param rollID number - The roll ID
function GroupLootMixin:HideGroupLootFrame(rollID)
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
function GroupLootMixin:LogRoll(rollID, link, rollType, isMasterLooter)
    local rollName = GroupLootRollNames[rollType] or "Unknown"
    local role = isMasterLooter and "ML" or "Raider"

    Loothing:Debug(string.format("[GroupLoot] [%s] Auto-rolled %s on %s", role, rollName, link))

    self.pendingRolls[rollID] = nil
end
