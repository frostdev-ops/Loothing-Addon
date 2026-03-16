--[[--------------------------------------------------------------------
    Loothing - Loot Council Addon for WoW 12.0+
    Bootstrap - Early addon namespace setup
----------------------------------------------------------------------]]

local ADDON_NAME, ns = ...
local Loolib = LibStub("Loolib")

ns.Addon = ns.Addon or Loolib:NewAddon({}, ADDON_NAME)

local Addon = ns.Addon
Addon.ns = ns

-- BrainrotMode is detected and applied at ADDON_LOADED time (Init.lua)
-- because SavedVariables are not available at file-scope load time.
Addon.BrainrotMode = false
