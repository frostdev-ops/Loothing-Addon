--[[--------------------------------------------------------------------
    Loothing - Loot Council Addon for WoW 12.0+
    MLDB - Master Looter Database (Settings Sync)

    The MLDB contains Master Looter settings that get synced to raid members.
    When the ML changes settings, they broadcast to the raid so everyone
    uses the same configuration for voting, responses, etc.
----------------------------------------------------------------------]]

local Loolib = LibStub("Loolib")

--[[--------------------------------------------------------------------
    LoothingMLDBMixin
----------------------------------------------------------------------]]

LoothingMLDBMixin = LoolibCreateFromMixins(LoolibCallbackRegistryMixin)

local MLDB_EVENTS = {
    "OnMLDBReceived",      -- Fired when ML settings are received
    "OnMLDBApplied",       -- Fired after ML settings are applied locally
    "OnMLDBBroadcast",     -- Fired when ML broadcasts settings
}

-- Key compression table (reduces message size)
-- Maps long key names to short codes for transmission
local COMPRESSION_KEYS = {
    -- Forward mapping (key -> code)
    ["selfVote"] = "sv",
    ["multiVote"] = "mv",
    ["anonymousVoting"] = "av",
    ["hideVotes"] = "hv",
    ["votingTimeout"] = "vt",
    ["responses"] = "rs",
    ["sortOrder"] = "so",
    ["observe"] = "ob",
    ["numButtons"] = "nb",
    ["mlSeesVotes"] = "msv",
    ["requireNotes"] = "rn",
    ["autoAddRolls"] = "aar",

    -- Response fields
    ["name"] = "n",
    ["color"] = "c",
    ["icon"] = "i",
    ["sort"] = "s",

    -- Button set mapping
    ["typeCodeMap"] = "tcm",
    ["activeButtonSet"] = "abs",
    ["buttonSets"] = "bs",
}

-- Reverse mapping (code -> key)
local DECOMPRESSION_KEYS = {}
for key, code in pairs(COMPRESSION_KEYS) do
    DECOMPRESSION_KEYS[code] = key
end

--[[--------------------------------------------------------------------
    Initialization
----------------------------------------------------------------------]]

--- Initialize MLDB handler
function LoothingMLDBMixin:Init()
    LoolibCallbackRegistryMixin.OnLoad(self)
    self:GenerateCallbackEvents(MLDB_EVENTS)

    self.mldb = nil  -- Current MLDB (nil until received or built)
    self.isML = false

    -- Register for communication events
    if Loothing.Comm then
        Loothing.Comm:RegisterCallback("OnMLDBBroadcast", function(_, data)
            self:OnMLDBBroadcast(data)
        end, self)
    end
end

--[[--------------------------------------------------------------------
    Master Looter Functions
----------------------------------------------------------------------]]

--- Check if current player is Master Looter
-- @return boolean
function LoothingMLDBMixin:IsML()
    if Loothing.Settings then
        return Loothing.Settings:IsMasterLooter()
    end
    return false
end

--- Get current Master Looter name
-- @return string|nil
function LoothingMLDBMixin:GetML()
    if Loothing.Settings then
        return Loothing.Settings:GetMasterLooter()
    end
    return nil
end

--[[--------------------------------------------------------------------
    Settings Gathering
----------------------------------------------------------------------]]

--- Gather current ML settings for transmission
-- @return table - Settings to sync
function LoothingMLDBMixin:GatherSettings()
    if not Loothing.Settings then
        return {}
    end

    local settings = {}

    -- Voting settings
    local votingSettings = Loothing.Settings:Get("voting", {})
    settings.selfVote = votingSettings.selfVote or false
    settings.multiVote = votingSettings.multiVote or false
    settings.anonymousVoting = votingSettings.anonymousVoting or false
    settings.hideVotes = votingSettings.hideVotes or false
    settings.observe = votingSettings.observe or false
    settings.numButtons = votingSettings.numButtons or 5
    settings.mlSeesVotes = votingSettings.mlSeesVotes or false
    settings.requireNotes = votingSettings.requireNotes or false
    settings.autoAddRolls = votingSettings.autoAddRolls or true

    -- Voting timeout
    settings.votingTimeout = Loothing.Settings:Get("settings.votingTimeout", 30)

    -- Sort order
    settings.sortOrder = Loothing.Settings:Get("councilTable.sortColumn", "response")

    -- Response button configurations
    -- Only send non-default responses to reduce size
    if Loothing.ResponseManager then
        local responses = Loothing.ResponseManager:GetAllResponses()
        local changedResponses = {}

        for id, response in pairs(responses) do
            -- Compare to default to see if it was customized
            local defaultResponse = LOOTHING_RESPONSE_INFO[id]
            local hasChanged = false

            if not defaultResponse then
                hasChanged = true
            else
                -- Check if name or color changed
                if response.name ~= defaultResponse.name then
                    hasChanged = true
                end

                if response.color then
                    local defaultColor = defaultResponse.color
                    if not defaultColor or
                       response.color.r ~= defaultColor.r or
                       response.color.g ~= defaultColor.g or
                       response.color.b ~= defaultColor.b then
                        hasChanged = true
                    end
                end
            end

            if hasChanged then
                changedResponses[id] = {
                    name = response.name,
                    color = response.color,
                    icon = response.icon,
                    sort = response.sort or id,
                }
            end
        end

        -- Only include if there are changes
        if next(changedResponses) then
            settings.responses = changedResponses
        end
    end

    -- Per-typeCode button set mapping
    local typeCodeMap = Loothing.Settings:Get("buttonSets.typeCodeMap")
    if typeCodeMap and next(typeCodeMap) then
        settings.typeCodeMap = typeCodeMap
    end

    -- Active button set ID
    settings.activeButtonSet = Loothing.Settings:GetActiveButtonSet()

    -- Button sets (send full set definitions so candidates know button labels/colors)
    local buttonSets = Loothing.Settings:GetButtonSets()
    if buttonSets and buttonSets.sets then
        local setsData = {}
        for id, set in pairs(buttonSets.sets) do
            setsData[id] = {
                name = set.name,
                buttons = set.buttons,
            }
        end
        settings.buttonSets = setsData
    end

    return settings
end

--[[--------------------------------------------------------------------
    Compression / Decompression
----------------------------------------------------------------------]]

--- Compress settings for transmission
-- Replaces long key names with short codes for bandwidth savings.
-- The Protocol layer handles serialization+compression automatically.
-- @param settings table - Settings to compress
-- @return table|nil - Key-compressed settings table
function LoothingMLDBMixin:CompressForTransmit(settings)
    if not settings then
        return nil
    end

    -- Replace keys with compressed codes (Protocol handles serialization)
    return self:ReplaceKeys(settings, COMPRESSION_KEYS)
end

--- Decompress settings received from transmission
-- Restores short codes back to full key names.
-- The Protocol layer has already handled deserialization.
-- @param data table - Key-compressed settings table (already deserialized by Protocol)
-- @return table|nil - Decompressed settings or nil on failure
function LoothingMLDBMixin:DecompressFromTransmit(data)
    if not data or type(data) ~= "table" then
        return nil
    end

    -- Replace codes with original keys
    return self:ReplaceKeys(data, DECOMPRESSION_KEYS)
end

--- Recursively replace keys in a table
-- @param tbl table - Table to process
-- @param replacements table - Key replacement map
-- @return table - New table with replaced keys
function LoothingMLDBMixin:ReplaceKeys(tbl, replacements)
    local result = {}

    for key, value in pairs(tbl) do
        -- Replace key if mapping exists
        local newKey = replacements[key] or key

        -- Recursively handle nested tables
        if type(value) == "table" then
            result[newKey] = self:ReplaceKeys(value, replacements)
        else
            result[newKey] = value
        end
    end

    return result
end

--[[--------------------------------------------------------------------
    Broadcasting
----------------------------------------------------------------------]]

--- Broadcast settings to raid
-- Only the ML should call this
function LoothingMLDBMixin:BroadcastToRaid()
    if not self:IsML() then
        Loothing:Debug("Only ML can broadcast MLDB")
        return
    end

    if not Loothing.Comm then
        Loothing:Error("Comm module not available")
        return
    end

    -- Gather current settings
    local settings = self:GatherSettings()

    -- Store locally
    self.mldb = settings

    -- Key-compress for transmission (Protocol handles serialization+compression)
    local compressed = self:CompressForTransmit(settings)

    if not compressed then
        Loothing:Error("Failed to compress MLDB for broadcast")
        return
    end

    -- Send to raid
    Loothing.Comm:BroadcastMLDB(compressed)

    -- Trigger event
    self:TriggerEvent("OnMLDBBroadcast", settings)

    Loothing:Debug("Broadcast MLDB to raid")
end

--[[--------------------------------------------------------------------
    Receiving
----------------------------------------------------------------------]]

--- Handle received MLDB broadcast
-- @param data table - Message data
function LoothingMLDBMixin:OnMLDBBroadcast(data)
    local sender = data.sender
    local compressed = data.data

    if not compressed then
        Loothing:Debug("Received empty MLDB from", sender)
        return
    end

    -- Only accept from the current ML
    local currentML = self:GetML()
    if not currentML or not LoothingUtils.IsSamePlayer(sender, currentML) then
        Loothing:Debug("Ignoring MLDB from non-ML:", sender)
        return
    end

    -- Decompress
    local settings = self:DecompressFromTransmit(compressed)
    if not settings then
        Loothing:Error("Failed to decompress MLDB from", sender)
        return
    end

    -- Trigger received event
    self:TriggerEvent("OnMLDBReceived", {
        sender = sender,
        settings = settings,
    })

    -- Apply settings (only if not ML)
    if not self:IsML() then
        self:ApplyFromML(settings, sender)
    end
end

--[[--------------------------------------------------------------------
    Applying Settings
----------------------------------------------------------------------]]

--- Apply received ML settings locally
-- @param settings table - Settings from ML
-- @param sender string - ML name
function LoothingMLDBMixin:ApplyFromML(settings, sender)
    if not settings then
        return
    end

    -- Store MLDB
    self.mldb = settings

    -- Don't apply if we're the ML (we set our own settings)
    if self:IsML() then
        Loothing:Debug("Skipping MLDB apply - we are ML")
        return
    end

    Loothing:Debug("Applying MLDB from", sender)

    -- Apply voting settings
    if Loothing.Settings then
        local votingSettings = Loothing.Settings:Get("voting", {})

        if settings.selfVote ~= nil then
            votingSettings.selfVote = settings.selfVote
        end
        if settings.multiVote ~= nil then
            votingSettings.multiVote = settings.multiVote
        end
        if settings.anonymousVoting ~= nil then
            votingSettings.anonymousVoting = settings.anonymousVoting
        end
        if settings.hideVotes ~= nil then
            votingSettings.hideVotes = settings.hideVotes
        end
        if settings.observe ~= nil then
            votingSettings.observe = settings.observe
        end
        if settings.numButtons ~= nil then
            votingSettings.numButtons = settings.numButtons
        end
        if settings.mlSeesVotes ~= nil then
            votingSettings.mlSeesVotes = settings.mlSeesVotes
        end
        if settings.requireNotes ~= nil then
            votingSettings.requireNotes = settings.requireNotes
        end
        if settings.autoAddRolls ~= nil then
            votingSettings.autoAddRolls = settings.autoAddRolls
        end

        Loothing.Settings:Set("voting", votingSettings)

        -- Apply voting timeout
        if settings.votingTimeout then
            Loothing.Settings:Set("settings.votingTimeout", settings.votingTimeout)
        end

        -- Apply sort order
        if settings.sortOrder then
            Loothing.Settings:Set("councilTable.sortColumn", settings.sortOrder)
        end
    end

    -- Apply response configurations
    if settings.responses and Loothing.ResponseManager then
        for id, response in pairs(settings.responses) do
            local responseID = tonumber(id) or id

            -- Convert color array to table format
            local color = response.color
            if color and type(color) == "table" then
                -- Check if it's an array [r, g, b, a]
                if color[1] then
                    color = {
                        r = color[1] or 1,
                        g = color[2] or 1,
                        b = color[3] or 1,
                        a = color[4] or 1,
                    }
                end
            end

            Loothing.ResponseManager:UpdateResponse(responseID, {
                name = response.name,
                color = color,
                icon = response.icon,
                sort = response.sort,
            })
        end
    end

    -- Trigger applied event
    self:TriggerEvent("OnMLDBApplied", {
        sender = sender,
        settings = settings,
    })

    Loothing:Debug("Applied MLDB from", sender)
end

--- Get current MLDB
-- @return table|nil
function LoothingMLDBMixin:Get()
    return self.mldb
end

--- Clear MLDB (called on session end)
function LoothingMLDBMixin:Clear()
    self.mldb = nil
end

--[[--------------------------------------------------------------------
    Update Current Settings
----------------------------------------------------------------------]]

--- Update MLDB from current settings and broadcast if ML
-- Called when settings change during an active session
function LoothingMLDBMixin:Update()
    if not self:IsML() then
        return
    end

    -- Gather and broadcast
    self:BroadcastToRaid()
end

--[[--------------------------------------------------------------------
    Factory
----------------------------------------------------------------------]]

--- Create MLDB instance
-- @return LoothingMLDBMixin
function CreateLoothingMLDB()
    local mldb = LoolibCreateFromMixins(LoothingMLDBMixin)
    mldb:Init()
    return mldb
end
