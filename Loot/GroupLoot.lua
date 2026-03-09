--[[--------------------------------------------------------------------
    Loothing - Group Loot Handler
    Handles automatic rolling on group loot items
----------------------------------------------------------------------]]

local Loolib = LibStub("Loolib")

--[[--------------------------------------------------------------------
    LoothingGroupLootMixin base + shared constants
----------------------------------------------------------------------]]

LoothingGroupLootMixin = LoothingGroupLootMixin or {}

-- Shared roll constants used by the partial modules under Loot/
LoothingGroupLootRoll = {
    PASS = 0,
    NEED = 1,
    GREED = 2,
    DISENCHANT = 3,
    TRANSMOG = 4,
}

LoothingGroupLootRollNames = {
    [LoothingGroupLootRoll.PASS] = "Pass",
    [LoothingGroupLootRoll.NEED] = "Need",
    [LoothingGroupLootRoll.GREED] = "Greed",
    [LoothingGroupLootRoll.DISENCHANT] = "Disenchant",
    [LoothingGroupLootRoll.TRANSMOG] = "Transmog",
}

--[[--------------------------------------------------------------------
    Factory
----------------------------------------------------------------------]]

function CreateLoothingGroupLoot()
    local groupLoot = Loolib.CreateFromMixins(LoothingGroupLootMixin)
    if groupLoot.Init then
        groupLoot:Init()
    end
    return groupLoot
end
