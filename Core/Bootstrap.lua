--[[--------------------------------------------------------------------
    Loothing - Loot Council Addon for WoW 12.0+
    Bootstrap - Early addon namespace setup
----------------------------------------------------------------------]]

local ADDON_NAME, ns = ...
local Loolib = LibStub("Loolib")

ns.Locale = ns.Locale or {}
ns.Addon = ns.Addon or Loolib:NewAddon({}, ADDON_NAME)

local Addon = ns.Addon
Addon.Locale = ns.Locale
Addon.ns = ns
