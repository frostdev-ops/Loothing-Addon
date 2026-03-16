--[[--------------------------------------------------------------------
    Loothing - Locale Resolver
    Loaded after all locale files. Resolves the active locale table
    and publishes it to ns.Locale / Addon.Locale for all consumers.
----------------------------------------------------------------------]]

local ADDON_NAME, ns = ...
local Loolib = LibStub("Loolib")
local LoolibLocale = Loolib.Locale or Loolib:GetModule("Locale")
local Addon = ns.Addon

-- Resolve the active locale table (falls back to enUS)
-- Brainrot overlay is applied in-place at ADDON_LOADED time (Init.lua)
-- so all file-scope captures of this table see the updated strings.
local L = LoolibLocale:GetLocale(ADDON_NAME, true)

ns.Locale = L
Addon.Locale = L
