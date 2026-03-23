--[[--------------------------------------------------------------------
    Loothing - Loot Council Addon for WoW 12.0+
    ResponseManager - Unified response configuration from responseSets
----------------------------------------------------------------------]]

local _, ns = ...
local Loolib = LibStub("Loolib")
local Loothing = ns.Addon
local Utils = ns.Utils

--[[--------------------------------------------------------------------
    ResponseManagerMixin
----------------------------------------------------------------------]]

ns.ResponseManagerMixin = ns.ResponseManagerMixin or {}
local ResponseManagerMixin = ns.ResponseManagerMixin

--- Initialize response manager
function ResponseManagerMixin:Init()
    -- Populated on LoadResponses(); kept as a reference to the active set's buttons
    self.buttons = nil
end

--- Load responses from the active responseSets set
function ResponseManagerMixin:LoadResponses()
    if not Loothing.Settings then return end

    local rs = Loothing.Settings:GetResponseSets()
    local activeId = rs.activeSet or 1
    self.buttons = Loothing.Settings:GetResponseButtons(activeId)
    if #self.buttons == 0 then
        self.buttons = Utils.DeepCopy(Loothing.DefaultSettings.responseSets.sets[1].buttons)
    end

    self:UpdateGlobalResponseInfo()
end

--- Update Loothing.ResponseInfo from the active set's buttons
-- Numeric entries are cleared and rebuilt; string-keyed system entries are untouched.
function ResponseManagerMixin:UpdateGlobalResponseInfo()
    -- Clear numeric response IDs
    for k in pairs(Loothing.ResponseInfo) do
        if type(k) == "number" then
            Loothing.ResponseInfo[k] = nil
        end
    end

    for index, btn in ipairs(self.buttons or {}) do
        local responseId = btn.id or index
        local color = Utils.ColorToNamed(btn.color)
        Loothing.ResponseInfo[responseId] = {
            name  = btn.responseText or btn.text,
            color = color,
            icon  = btn.icon,
        }
    end
end

--- Get all buttons in the active set (array)
-- @return table - Array of button data
function ResponseManagerMixin:GetAllResponses()
    if not self.buttons then self:LoadResponses() end
    return self.buttons or {}
end

--- Get buttons sorted by sort order
-- @return table - Sorted array of { id, name, color, icon, sort }
function ResponseManagerMixin:GetSortedResponses()
    local buttons = self:GetAllResponses()
    local sorted = {}

    for _, btn in ipairs(buttons) do
        sorted[#sorted + 1] = {
            id   = btn.id,
            name = btn.responseText or btn.text,
            color = btn.color,
            icon  = btn.icon,
            sort  = btn.sort or 999,
        }
    end

    table.sort(sorted, function(a, b) return a.sort < b.sort end)
    return sorted
end

--- Get a button by numeric ID
-- @param responseID number
-- @return table|nil
function ResponseManagerMixin:GetResponse(responseID)
    for _, btn in ipairs(self:GetAllResponses()) do
        if btn.id == responseID then return btn end
    end
    return nil
end

--- Find a button by responseText or text (case-insensitive)
-- @param name string
-- @return table|nil
function ResponseManagerMixin:GetResponseByName(name)
    if type(name) ~= "string" then return nil end
    local lname = name:lower()
    for _, btn in ipairs(self:GetAllResponses()) do
        if btn.responseText and btn.responseText:lower() == lname then return btn end
        if btn.text and btn.text:lower() == lname then return btn end
    end
    return nil
end

--- Serialize full responseSets for sync
-- @return table
function ResponseManagerMixin:Serialize()
    if not Loothing.Settings then return {} end
    return Utils.DeepCopy(Loothing.Settings:GetResponseSets())
end

--- Deserialize responseSets received from sync
-- @param data table
function ResponseManagerMixin:Deserialize(data)
    if not data then return end
    if Loothing.Settings then
        Loothing.Settings:Set("responseSets", data)
    end
    self:LoadResponses()
end

--- Reset the active set to defaults
function ResponseManagerMixin:ResetToDefaults()
    if not Loothing.Settings then return end
    local defaults = Utils.DeepCopy(Loothing.DefaultSettings.responseSets)
    Loothing.Settings:Set("responseSets", defaults)
    self:LoadResponses()
end

--[[--------------------------------------------------------------------
    Singleton Instance
----------------------------------------------------------------------]]

--- Create the ResponseManager singleton
-- @return table
ns.CreateResponseManager = ns.CreateResponseManager or function()
    local manager = Loolib.CreateFromMixins(ResponseManagerMixin)
    manager:Init()
    return manager
end
