local _, ns = ...
local pairs, time = pairs, time

ns.GroupLootMixin = ns.GroupLootMixin or {}

local GroupLootMixin = ns.GroupLootMixin

--[[--------------------------------------------------------------------
    Loothing - Group Loot State
    Maintains pending rolls and cleanup helpers.
----------------------------------------------------------------------]]

--- Initialize the group loot handler state.
function GroupLootMixin:Init()
    self.pendingRolls = {}
end

--- Clean up stale pending rolls (called periodically if needed).
function GroupLootMixin:CleanupPendingRolls()
    local now = time()
    local timeout = 60 -- 1 minute timeout

    for rollID, data in pairs(self.pendingRolls) do
        if now - data.timestamp > timeout then
            self.pendingRolls[rollID] = nil
        end
    end
end
