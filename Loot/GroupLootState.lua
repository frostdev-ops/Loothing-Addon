--[[--------------------------------------------------------------------
    Loothing - Group Loot State
    Maintains pending rolls and cleanup helpers.
----------------------------------------------------------------------]]
local _, ns = ...
local pairs, time = pairs, time

ns.GroupLootMixin = ns.GroupLootMixin or {}

local GroupLootMixin = ns.GroupLootMixin

--- Initialize the group loot handler state.
function GroupLootMixin:Init()
    self.pendingRolls = {}
end

