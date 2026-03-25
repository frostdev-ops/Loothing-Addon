--[[--------------------------------------------------------------------
    Loothing - Loot Council Addon for WoW 12.0+
    MLDB - Master Looter Database (Settings Sync)

    The MLDB contains Master Looter settings that get synced to raid members.
    When the ML changes settings, they broadcast to the raid so everyone
    uses the same configuration for voting, responses, etc.
----------------------------------------------------------------------]]

local _, ns = ...
local Loolib = LibStub("Loolib")
local Loothing = ns.Addon
local Utils = ns.Utils

--[[--------------------------------------------------------------------
    MLDBMixin
----------------------------------------------------------------------]]

local MLDBMixin = Loolib.CreateFromMixins(Loolib.CallbackRegistryMixin)
ns.MLDBMixin = MLDBMixin

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
    ["sortOrder"] = "so",
    ["observe"] = "ob",
    ["mlSeesVotes"] = "msv",
    ["requireNotes"] = "rn",
    ["autoAddRolls"] = "aar",
    ["maxRanks"] = "mxr",
    ["minRanks"] = "mnr",
    ["maxRevotes"] = "mrv",

    -- responseSets fields
    ["responseSets"] = "rs2",
    ["activeSet"] = "as",
    ["typeCodeMap"] = "tcm",
    ["responseText"] = "rt",
    ["whisperKeys"] = "wk",
    ["buttons"] = "btns",

    -- Per-button / shared fields
    ["name"] = "n",
    ["color"] = "c",
    ["icon"] = "i",
    ["sort"] = "s",
    ["text"] = "t",
    ["id"] = "id",
    ["enabled"] = "en",
    ["channel"] = "ch",
    ["reason"] = "r",

    -- Observer settings
    ["mlIsObserver"] = "mio",
    ["openObservation"] = "oo",
    ["observerPermissions"] = "op",
    ["seeVoteCounts"] = "svc",
    ["seeVoterIdentities"] = "svi",
    ["seeResponses"] = "sr",
    ["seeNotes"] = "sn",

    -- Session settings
    ["votingMode"] = "vm",
    ["sessionTriggerAction"] = "sta",
    ["sessionTriggerTiming"] = "stt",
    ["sessionTriggerRaid"] = "str",
    ["sessionTriggerDungeon"] = "std",
    ["sessionTriggerOpenWorld"] = "stow",
    ["groupLootMode"] = "glm",
    ["masterLooter"] = "ml2",

    -- AutoPass settings
    ["autoPass"] = "ap",
    ["weapons"] = "wp",
    ["boe"] = "bo",
    ["transmog"] = "tm",
    ["trinkets"] = "trk",
    ["transmogSource"] = "tms",
    ["silent"] = "sl",

    -- AutoAward settings
    ["autoAward"] = "aa",
    ["lowerThreshold"] = "lt",
    ["upperThreshold"] = "ut",
    ["awardTo"] = "at",
    ["includeBoE"] = "ib",

    -- Award reasons
    ["awardReasons"] = "ar",
    ["requireReason"] = "rr",
    -- numReasons removed (source of truth is array length)
    ["reasonId"] = "rid",
    ["reasons"] = "rsn",
    ["log"] = "lg",
    ["disenchant"] = "de",

    -- Winner determination
    ["winnerDetermination"] = "wd",
    ["mode"] = "m",
    ["tieBreaker"] = "tb",
    ["autoAwardOnUnanimous"] = "aau",
    ["requireConfirmation"] = "rc",

    -- Announcements
    ["announcements"] = "an",
    ["announceAwards"] = "anaw",
    ["announceItems"] = "ani",
    ["announceBossKill"] = "anbk",
    ["announceConsiderations"] = "anc",
    ["awardLines"] = "awl",
    ["itemLines"] = "itl",
    ["considerationsChannel"] = "cc",
    ["considerationsText"] = "cxt",
    ["sessionStartChannel"] = "ssc",
    ["sessionStartText"] = "sst",
    ["sessionEndChannel"] = "sec",
    ["sessionEndText"] = "set2",
    ["awardChannel"] = "ach",
    ["awardChannelSecondary"] = "acs",
    ["awardText"] = "atx",
    ["itemChannel"] = "ich",
    ["itemText"] = "itx",

    -- Ignore items
    ["ignoreItems"] = "ii",
    ["items"] = "its",
    ["ignoreEnchantingMaterials"] = "iem",
    ["ignoreCraftingReagents"] = "icr",
    ["ignoreConsumables"] = "ico",
    ["ignorePermanentEnhancements"] = "ipe",
}

-- Reverse mapping (code -> key)
local DECOMPRESSION_KEYS = {}
for key, code in pairs(COMPRESSION_KEYS) do
    DECOMPRESSION_KEYS[code] = key
end

-- Keys whose child tables are leaf/value tables (not structural).
-- Recursing into these with the compression map corrupts their keys
-- (e.g. color {r,g,b} → {reason,g,b} because "r" maps to "reason").
local LEAF_KEYS = {
    -- Uncompressed key names
    color = true,
    whisperKeys = true,
    -- Compressed codes
    c  = true,   -- color
    wk = true,   -- whisperKeys
}

--[[--------------------------------------------------------------------
    Initialization
----------------------------------------------------------------------]]

--- Initialize MLDB handler
function MLDBMixin:Init()
    Loolib.CallbackRegistryMixin.OnLoad(self)
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
function MLDBMixin:IsML()
    if Loothing.Settings then
        return Loothing.Settings:IsMasterLooter()
    end
    return false
end

--- Get current Master Looter name
-- @return string|nil
function MLDBMixin:GetML()
    if Loothing.Settings then
        return Loothing.Settings:GetMasterLooter()
    end
    return nil
end

--[[--------------------------------------------------------------------
    Settings Gathering
----------------------------------------------------------------------]]

--- Gather current ML settings for transmission
-- Includes all session-relevant settings so every raid member operates
-- under the same rules as the Master Looter.
-- @return table - Settings to sync
function MLDBMixin:GatherSettings()
    if not Loothing.Settings then
        return {}
    end

    local settings = {}

    -- Voting settings
    local votingSettings = Loothing.Settings:Get("voting", {})
    settings.selfVote       = votingSettings.selfVote or false
    settings.multiVote      = votingSettings.multiVote or false
    settings.anonymousVoting = votingSettings.anonymousVoting or false
    settings.hideVotes      = votingSettings.hideVotes or false
    settings.observe        = votingSettings.observe or false
    settings.mlSeesVotes    = votingSettings.mlSeesVotes or false
    settings.requireNotes   = votingSettings.requireNotes or false
    settings.autoAddRolls   = votingSettings.autoAddRolls ~= false  -- default true
    settings.maxRanks    = votingSettings.maxRanks or 0
    settings.minRanks    = votingSettings.minRanks or 1
    settings.maxRevotes  = votingSettings.maxRevotes or 2

    -- Observer settings
    settings.mlIsObserver = Loothing.Settings:Get("observers.mlIsObserver", false)
    settings.openObservation = Loothing.Settings:Get("observers.openObservation", false)
    settings.observerPermissions = Loothing.Settings:GetObserverPermissions()

    -- Session settings
    settings.votingTimeout = Loothing.Settings:Get("settings.votingTimeout", 30)
    settings.votingMode = Loothing.Settings:Get("settings.votingMode", "SIMPLE")

    -- Session trigger policy
    settings.sessionTriggerAction   = Loothing.Settings:GetSessionTriggerAction()
    settings.sessionTriggerTiming   = Loothing.Settings:GetSessionTriggerTiming()
    settings.sessionTriggerRaid     = Loothing.Settings:GetSessionTriggerRaid()
    settings.sessionTriggerDungeon  = Loothing.Settings:GetSessionTriggerDungeon()
    settings.sessionTriggerOpenWorld = Loothing.Settings:GetSessionTriggerOpenWorld()
    settings.groupLootMode = Loothing.Settings:GetGroupLootMode()
    settings.masterLooter = Loothing.explicitMasterLooter

    -- Sort order
    settings.sortOrder = Loothing.Settings:Get("councilTable.sortColumn", "response")

    -- Unified responseSets (full structure)
    settings.responseSets = Loothing.Settings:GetResponseSets()

    -- AutoPass settings
    settings.autoPass = {
        enabled       = Loothing.Settings:Get("autoPass.enabled") ~= false,
        weapons       = Loothing.Settings:Get("autoPass.weapons") ~= false,
        boe           = Loothing.Settings:Get("autoPass.boe") == true,
        transmog      = Loothing.Settings:Get("autoPass.transmog") == true,
        trinkets      = Loothing.Settings:Get("autoPass.trinkets") == true,
        transmogSource = Loothing.Settings:Get("autoPass.transmogSource") == true,
        silent        = Loothing.Settings:Get("autoPass.silent") == true,
    }

    -- AutoAward settings
    settings.autoAward = {
        enabled        = Loothing.Settings:Get("autoAward.enabled") == true,
        lowerThreshold = Loothing.Settings:Get("autoAward.lowerThreshold", 2),
        upperThreshold = Loothing.Settings:Get("autoAward.upperThreshold", 4),
        awardTo        = Loothing.Settings:Get("autoAward.awardTo", ""),
        reason         = Loothing.Settings:Get("autoAward.reason", "Auto Award"),
        reasonId       = Loothing.Settings:GetAutoAwardReasonId(),
        includeBoE     = Loothing.Settings:Get("autoAward.includeBoE") == true,
    }

    -- Award reasons
    settings.awardReasons = {
        enabled       = Loothing.Settings:Get("awardReasons.enabled") ~= false,
        requireReason = Loothing.Settings:Get("awardReasons.requireReason") == true,
        reasons       = Loothing.Settings:GetAwardReasons(),
    }

    -- Winner determination
    settings.winnerDetermination = {
        mode                 = Loothing.Settings:Get("winnerDetermination.mode", "ML_CONFIRM"),
        tieBreaker           = Loothing.Settings:Get("winnerDetermination.tieBreaker", "ROLL"),
        autoAwardOnUnanimous = Loothing.Settings:Get("winnerDetermination.autoAwardOnUnanimous") == true,
        requireConfirmation  = Loothing.Settings:Get("winnerDetermination.requireConfirmation") ~= false,
    }

    -- Announcements (full structure)
    settings.announcements = Loothing.Settings:Get("announcements",
        Loothing.DefaultSettings and Loothing.DefaultSettings.announcements or {})

    -- Ignore items
    settings.ignoreItems = Loothing.Settings:Get("ignoreItems",
        Loothing.DefaultSettings and Loothing.DefaultSettings.ignoreItems or {})

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
function MLDBMixin:CompressForTransmit(settings)
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
function MLDBMixin:DecompressFromTransmit(data)
    if not data or type(data) ~= "table" then
        return nil
    end

    -- Replace codes with original keys
    return self:ReplaceKeys(data, DECOMPRESSION_KEYS)
end

--- Recursively replace keys in a table
-- @param tbl table - Table to process
-- @param replacements table - Key replacement map
-- @param isLeaf boolean? - If true, skip key replacement (value table)
-- @return table - New table with replaced keys
function MLDBMixin:ReplaceKeys(tbl, replacements, isLeaf)
    local result = {}

    for key, value in pairs(tbl) do
        -- Replace key if mapping exists (skip for leaf tables — their keys are data)
        local newKey = (not isLeaf and replacements[key]) or key

        if type(value) == "table" then
            -- Don't recurse into leaf/value tables (e.g. color, whisperKeys).
            -- Propagate isLeaf downward so nested tables inside a leaf stay protected.
            result[newKey] = self:ReplaceKeys(value, replacements, isLeaf or LEAF_KEYS[key] or LEAF_KEYS[newKey])
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
-- Only the ML should call this.
-- @param force boolean? - Skip IsML check (used during ML reassignment where
--   the caller has already verified authority but IsML() would re-evaluate)
function MLDBMixin:BroadcastToRaid(force)
    if not force and not self:IsML() then
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
function MLDBMixin:OnMLDBBroadcast(data)
    local sender = data.sender
    local compressed = data.data

    if not compressed then
        Loothing:Debug("Received empty MLDB from", sender)
        return
    end

    -- Verify sender is the ML (or accept to bootstrap ML identity)
    local currentML = self:GetML()
    if currentML then
        if not Utils.IsSamePlayer(sender, currentML) then
            Loothing:Debug("Ignoring MLDB from non-ML:", sender)
            return
        end
    end
    -- If ML is unknown, the Core handler already validated the sender as a
    -- group member. Accept the MLDB so it can bootstrap the ML identity.

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
function MLDBMixin:ApplyFromML(settings, sender)
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

    if Loothing.Settings then
        -- Apply voting settings
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
        if settings.mlSeesVotes ~= nil then
            votingSettings.mlSeesVotes = settings.mlSeesVotes
        end
        if settings.requireNotes ~= nil then
            votingSettings.requireNotes = settings.requireNotes
        end
        if settings.autoAddRolls ~= nil then
            votingSettings.autoAddRolls = settings.autoAddRolls
        end
        if settings.maxRanks ~= nil then
            votingSettings.maxRanks = settings.maxRanks
        end
        if settings.minRanks ~= nil then
            votingSettings.minRanks = settings.minRanks
        end
        if settings.maxRevotes ~= nil then
            votingSettings.maxRevotes = settings.maxRevotes
        end

        Loothing.Settings:Set("voting", votingSettings)

        -- Apply session settings
        if settings.votingTimeout then
            Loothing.Settings:Set("settings.votingTimeout", settings.votingTimeout)
        end
        if settings.votingMode then
            Loothing.Settings:Set("settings.votingMode", settings.votingMode)
        end

        -- Apply session trigger policy
        if settings.sessionTriggerAction then
            Loothing.Settings:SetSessionTriggerAction(settings.sessionTriggerAction)
        end
        if settings.sessionTriggerTiming then
            Loothing.Settings:SetSessionTriggerTiming(settings.sessionTriggerTiming)
        end
        if settings.sessionTriggerRaid ~= nil then
            Loothing.Settings:SetSessionTriggerRaid(settings.sessionTriggerRaid)
        end
        if settings.sessionTriggerDungeon ~= nil then
            Loothing.Settings:SetSessionTriggerDungeon(settings.sessionTriggerDungeon)
        end
        if settings.sessionTriggerOpenWorld ~= nil then
            Loothing.Settings:SetSessionTriggerOpenWorld(settings.sessionTriggerOpenWorld)
        end
        if settings.groupLootMode then
            Loothing.Settings:SetGroupLootMode(settings.groupLootMode)
        end

        -- Apply explicit ML override (runtime-only, not persisted)
        -- nil means "use raid leader"; a name means that player is ML
        Loothing.explicitMasterLooter = settings.masterLooter

        -- Apply sort order
        if settings.sortOrder then
            Loothing.Settings:Set("councilTable.sortColumn", settings.sortOrder)
        end

        -- Apply observer settings
        if settings.mlIsObserver ~= nil then
            Loothing.Settings:Set("observers.mlIsObserver", settings.mlIsObserver)
        end
        if settings.openObservation ~= nil then
            Loothing.Settings:Set("observers.openObservation", settings.openObservation)
            Loothing.Settings:Set("voting.observe", settings.openObservation)
        end
        if settings.observerPermissions then
            Loothing.Settings:Set("observers.permissions", settings.observerPermissions)
        end

        -- Apply autoPass settings (per-key merge to preserve newer client keys)
        if settings.autoPass then
            for k, v in pairs(settings.autoPass) do
                Loothing.Settings:Set("autoPass." .. k, v)
            end
        end

        -- Apply autoAward settings (per-key merge)
        if settings.autoAward then
            for k, v in pairs(settings.autoAward) do
                Loothing.Settings:Set("autoAward." .. k, v)
            end
        end

        -- Apply award reasons (per-key merge)
        if settings.awardReasons then
            for k, v in pairs(settings.awardReasons) do
                Loothing.Settings:Set("awardReasons." .. k, v)
            end
        end

        -- Apply winner determination (per-key merge)
        if settings.winnerDetermination then
            for k, v in pairs(settings.winnerDetermination) do
                Loothing.Settings:Set("winnerDetermination." .. k, v)
            end
        end

        -- Apply announcements (per-key merge)
        if settings.announcements then
            for k, v in pairs(settings.announcements) do
                Loothing.Settings:Set("announcements." .. k, v)
            end
        end

        -- Apply ignore items (per-key merge)
        if settings.ignoreItems then
            for k, v in pairs(settings.ignoreItems) do
                Loothing.Settings:Set("ignoreItems." .. k, v)
            end
        end
    end

    -- Apply unified responseSets
    if settings.responseSets and Loothing.ResponseManager then
        Loothing.ResponseManager:Deserialize(settings.responseSets)
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
function MLDBMixin:Get()
    return self.mldb
end

--- Clear MLDB (called on session end)
function MLDBMixin:Clear()
    self.mldb = nil
end

--[[--------------------------------------------------------------------
    Update Current Settings
----------------------------------------------------------------------]]

--- Update MLDB from current settings and broadcast if ML
-- Called when settings change during an active session
function MLDBMixin:Update()
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
-- @return MLDBMixin
local function CreateMLDB()
    local mldb = Loolib.CreateFromMixins(MLDBMixin)
    mldb:Init()
    return mldb
end

ns.CreateMLDB = CreateMLDB
