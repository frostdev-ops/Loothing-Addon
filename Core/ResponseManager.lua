--[[--------------------------------------------------------------------
    Loothing - Loot Council Addon for WoW 12.0+
    ResponseManager - Manage custom response configuration
----------------------------------------------------------------------]]

local Loolib = LibStub("Loolib")

--[[--------------------------------------------------------------------
    LoothingResponseManagerMixin
----------------------------------------------------------------------]]

LoothingResponseManagerMixin = {}

--- Initialize response manager
function LoothingResponseManagerMixin:Init()
    -- Will use Loothing.Settings.db.responses
    self.responses = nil
end

--- Load responses from settings
function LoothingResponseManagerMixin:LoadResponses()
    if not Loothing.Settings then
        return
    end

    self.responses = Loothing.Settings:Get("responses")

    -- Ensure all default responses exist
    if not self.responses then
        self.responses = LoothingUtils.DeepCopy(LOOTHING_DEFAULT_SETTINGS.responses)
        Loothing.Settings:Set("responses", self.responses)
    end

    -- Update global LOOTHING_RESPONSE_INFO to match configured responses
    self:UpdateGlobalResponseInfo()
end

--- Update global LOOTHING_RESPONSE_INFO from settings
function LoothingResponseManagerMixin:UpdateGlobalResponseInfo()
    if not self.responses then return end

    for responseID, responseData in pairs(self.responses) do
        LOOTHING_RESPONSE_INFO[responseID] = {
            name = responseData.name,
            color = responseData.color,
            icon = responseData.icon,
        }
    end
end

--- Get response configuration
-- @param responseID number - LOOTHING_RESPONSE value
-- @return table|nil - { name, color, icon, sort }
function LoothingResponseManagerMixin:GetResponse(responseID)
    if not self.responses then
        self:LoadResponses()
    end

    return self.responses and self.responses[responseID]
end

--- Get all responses
-- @return table - { [responseID] = responseData }
function LoothingResponseManagerMixin:GetAllResponses()
    if not self.responses then
        self:LoadResponses()
    end

    return self.responses or {}
end

--- Get responses sorted by sort order
-- @return table - Array of { id, name, color, icon, sort }
function LoothingResponseManagerMixin:GetSortedResponses()
    local responses = self:GetAllResponses()
    local sorted = {}

    for id, data in pairs(responses) do
        sorted[#sorted + 1] = {
            id = id,
            name = data.name,
            color = data.color,
            icon = data.icon,
            sort = data.sort or 999,
        }
    end

    table.sort(sorted, function(a, b)
        return a.sort < b.sort
    end)

    return sorted
end

--- Update a response
-- @param responseID number
-- @param data table - { name, color, icon, sort }
function LoothingResponseManagerMixin:UpdateResponse(responseID, data)
    if not self.responses then
        self:LoadResponses()
    end

    if not self.responses[responseID] then
        self.responses[responseID] = {}
    end

    -- Update fields
    if data.name then
        self.responses[responseID].name = data.name
    end
    if data.color then
        self.responses[responseID].color = data.color
    end
    if data.icon then
        self.responses[responseID].icon = data.icon
    end
    if data.sort then
        self.responses[responseID].sort = data.sort
    end

    -- Save to settings
    Loothing.Settings:Set("responses", self.responses)

    -- Update global info
    self:UpdateGlobalResponseInfo()
end

--- Set response color
-- @param responseID number
-- @param r number - 0-1
-- @param g number - 0-1
-- @param b number - 0-1
-- @param a number - 0-1 (optional, default 1.0)
function LoothingResponseManagerMixin:SetResponseColor(responseID, r, g, b, a)
    local response = self:GetResponse(responseID)
    if not response then return end

    response.color = { r, g, b, a or 1.0 }
    Loothing.Settings:Set("responses", self.responses)
    self:UpdateGlobalResponseInfo()
end

--- Set response sort order
-- @param responseID number
-- @param sortOrder number
function LoothingResponseManagerMixin:SetResponseSort(responseID, sortOrder)
    local response = self:GetResponse(responseID)
    if not response then return end

    response.sort = sortOrder
    Loothing.Settings:Set("responses", self.responses)
end

--- Reorder responses
-- @param orderedIDs table - Array of response IDs in desired order
function LoothingResponseManagerMixin:ReorderResponses(orderedIDs)
    for i, responseID in ipairs(orderedIDs) do
        self:SetResponseSort(responseID, i)
    end
end

--- Reset responses to defaults
function LoothingResponseManagerMixin:ResetToDefaults()
    self.responses = LoothingUtils.DeepCopy(LOOTHING_DEFAULT_SETTINGS.responses)
    Loothing.Settings:Set("responses", self.responses)
    self:UpdateGlobalResponseInfo()
end

--- Serialize responses for sync
-- @return table - Serialized response data
function LoothingResponseManagerMixin:Serialize()
    local serialized = {}

    for id, data in pairs(self.responses or {}) do
        serialized[id] = {
            name = data.name,
            color = data.color,
            icon = data.icon,
            sort = data.sort,
        }
    end

    return serialized
end

--- Deserialize responses from sync
-- @param data table - Serialized response data
function LoothingResponseManagerMixin:Deserialize(data)
    if not data then return end

    self.responses = {}

    for id, responseData in pairs(data) do
        self.responses[tonumber(id)] = {
            name = responseData.name,
            color = responseData.color,
            icon = responseData.icon,
            sort = responseData.sort,
        }
    end

    Loothing.Settings:Set("responses", self.responses)
    self:UpdateGlobalResponseInfo()
end

--[[--------------------------------------------------------------------
    Singleton Instance
----------------------------------------------------------------------]]

--- Create the ResponseManager singleton
-- @return table
function CreateLoothingResponseManager()
    local manager = LoolibCreateFromMixins(LoothingResponseManagerMixin)
    manager:Init()
    return manager
end
