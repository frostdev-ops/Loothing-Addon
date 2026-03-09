--[[--------------------------------------------------------------------
    Loothing - Group Loot Handler
    Handles automatic rolling on group loot items
----------------------------------------------------------------------]]

local _, ns = ...
local Loolib = LibStub("Loolib")
local CreateFromMixins = Loolib.CreateFromMixins

ns.GroupLootMixin = ns.GroupLootMixin or {}
ns.GroupLootRoll = ns.GroupLootRoll or {
    PASS = 0,
    NEED = 1,
    GREED = 2,
    DISENCHANT = 3,
    TRANSMOG = 4,
}
ns.GroupLootRollNames = ns.GroupLootRollNames or {
    [ns.GroupLootRoll.PASS] = "Pass",
    [ns.GroupLootRoll.NEED] = "Need",
    [ns.GroupLootRoll.GREED] = "Greed",
    [ns.GroupLootRoll.DISENCHANT] = "Disenchant",
    [ns.GroupLootRoll.TRANSMOG] = "Transmog",
}

local GroupLootMixin = ns.GroupLootMixin

--[[--------------------------------------------------------------------
    GroupLootMixin base + shared constants
----------------------------------------------------------------------]]

--[[--------------------------------------------------------------------
    Factory
----------------------------------------------------------------------]]

function ns.CreateGroupLoot()
    local groupLoot = CreateFromMixins(GroupLootMixin)
    if groupLoot.Init then
        groupLoot:Init()
    end
    return groupLoot
end

-- ns.GroupLootMixin, ns.GroupLootRoll, ns.GroupLootRollNames, ns.CreateGroupLoot exported above
