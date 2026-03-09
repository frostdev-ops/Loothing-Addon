--[[--------------------------------------------------------------------
    Loothing - Loot Council Addon for WoW 12.0+
    Compat - Compatibility shims for deprecated/changed WoW APIs
----------------------------------------------------------------------]]

local GetLootMethod = GetLootMethod
local GetGuildRosterInfo = GetGuildRosterInfo
local GetLootRollItemInfo = GetLootRollItemInfo
local GuildRoster = GuildRoster
local UnitIsInMyGuild = UnitIsInMyGuild

local C_GuildInfo = C_GuildInfo
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

Loothing.GuildRoster = (C_GuildInfo and C_GuildInfo.GuildRoster) or GuildRoster
Loothing.GetGuildRosterInfo = (C_GuildInfo and C_GuildInfo.GetGuildRosterInfo) or GetGuildRosterInfo
Loothing.UnitIsInMyGuild = UnitIsInMyGuild

function Loothing.GetLootMethod()
    if C_PartyInfo and C_PartyInfo.GetLootMethod then
        return C_PartyInfo.GetLootMethod()
    end

    if not GetLootMethod then
        return enumLootMethod.Personal
    end

    local method, partyID, raidID = GetLootMethod()
    if not method then
        method = enumLootMethod.Personal
    elseif method == "freeforall" then
        method = enumLootMethod.Freeforall
    elseif method == "roundrobin" then
        method = enumLootMethod.Roundrobin
    elseif method == "master" then
        method = enumLootMethod.Masterlooter
    elseif method == "group" then
        method = enumLootMethod.Group
    elseif method == "needbeforegreed" then
        method = enumLootMethod.Needbeforegreed
    elseif method == "personalloot" then
        method = enumLootMethod.Personal
    end

    return method, partyID, raidID
end

function Loothing.GetLootRollItemData(rollID)
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
