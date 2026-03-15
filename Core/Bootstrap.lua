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

-- Apply locale override stored in LoolibDB._localeOverrides (raw global, available at load time)
local db = _G.LoolibDB
local override = db and type(db._localeOverrides) == "table" and db._localeOverrides[ADDON_NAME]
if type(override) == "string" and override ~= "" then
    Addon.ForceLocale = override
    local LoolibLocale = Loolib.Locale or Loolib:GetModule("Locale")
    if LoolibLocale and LoolibLocale.SetLocaleOverride then
        LoolibLocale:SetLocaleOverride(ADDON_NAME, override)
    end
end
