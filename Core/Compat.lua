--[[--------------------------------------------------------------------
    Loothing - Loot Council Addon for WoW 12.0+
    Compat - Compatibility shims for deprecated/changed WoW APIs
----------------------------------------------------------------------]]

local _, ns = ...
local Loolib = LibStub("Loolib")

local GetLootRollItemInfo = GetLootRollItemInfo
local UnitIsInMyGuild = UnitIsInMyGuild

local C_PartyInfo = C_PartyInfo
local Enum = Enum

local enumLootMethod = Enum and Enum.LootMethod or {
    Freeforall = 0,
    Roundrobin = 1,
    Masterlooter = 2,
    Group = 3,
    Needbeforegreed = 4,
    Personal = 5,
}

local Addon = ns.Addon

-- Delegate to Loolib.Compat instead of reimplementing
Addon.GuildRoster = Loolib.Compat.GuildRoster
Addon.GetGuildRosterInfo = Loolib.Compat.GetGuildRosterInfo
Addon.UnitIsInMyGuild = UnitIsInMyGuild

function Addon.GetLootMethod()
    if C_PartyInfo and C_PartyInfo.GetLootMethod then
        return C_PartyInfo.GetLootMethod()
    end

    return enumLootMethod.Personal
end

function Addon.GetLootRollItemData(rollID)
    if not GetLootRollItemInfo then
        return nil
    end

    local data = { GetLootRollItemInfo(rollID) }
    if #data == 0 then
        return nil
    end

    return {
        texture = data[1],
        name = data[2],
        count = data[3],
        quality = data[4],
        bindOnPickUp = data[5],
        canNeed = data[6],
        canGreed = data[7],
        canDisenchant = data[8],
        reasonNeed = data[9],
        reasonGreed = data[10],
        deTexture = data[11],
        reasonDE = data[12],
        canTransmog = data[13],
    }
end
