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

--- Items that must never be auto-rolled, because they are NOT tradeable.
---
--- Our auto-roll makes every non-ML raider pass so the ML collects the drop
--- and the council distributes it afterwards. That only works for items the
--- ML can actually hand over. For these the ML ends up holding a soulbound
--- item nobody else can receive — and worse, an already-collected toy is
--- *unwinnable* for the ML, so once everyone else has passed the item is
--- destroyed outright. Leave them to the normal Blizzard roll UI.
---
--- Mirrors RCLootCouncil's `GroupLoot.IgnoreList` (3.20.4 / 3.22.0).
--- @type table<number, boolean>
ns.GroupLootIgnoreList = {
    [209035] = true, -- Hearthstone of the Flame (Amirdrassil)
    [236687] = true, -- Explosive Hearthstone (Liberation of Undermine)
    [246565] = true, -- Cosmic Hearthstone (Manaforge Omega)
    [250104] = true, -- Soulbinder's Nethermantle
    [264672] = true, -- Cosmic Ritual Stone (Voidspire toy; unwinnable for the ML once learned)
    [264313] = true, -- Madcap Redcap (Sporefall toy)
    [264367] = true, -- Mycomancer's Hearthspore (Sporefall hearthstone)
    [268280] = true, -- Sporelord's Shroom Cap (Sporefall cosmetic)
}

--- Whether an item is on the never-auto-roll list.
--- @param itemID number|nil
--- @return boolean
function ns.IsGroupLootIgnored(itemID)
    return itemID ~= nil and ns.GroupLootIgnoreList[itemID] == true
end

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

-- ns.GroupLootMixin, ns.GroupLootRoll, ns.GroupLootRollNames, ns.GroupLootIgnoreList,
-- ns.IsGroupLootIgnored, ns.CreateGroupLoot exported above
