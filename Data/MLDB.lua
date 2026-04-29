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
local GetTime = GetTime

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
    -- v2.0.7 voting privacy. `privacy` is the canonical wire field
    -- ("open" | "hide_counts" | "anonymous"). The legacy
    -- anonymousVoting/hideVotes/observe codes remain so v2.0.6 receivers
    -- can still parse the broadcast (we send all three on the wire).
    ["privacy"] = "pri",
    ["anonymousVoting"] = "av",
    ["hideVotes"] = "hv",
    ["observe"] = "ob",  -- legacy; receivers ignore but slot reserved
    ["votingTimeout"] = "vt",
    ["sortOrder"] = "so",
    ["mlSeesVotes"] = "msv",
    ["requireNotes"] = "rn",
    ["autoAddRolls"] = "aar",
    ["maxRanks"] = "mxr",
    ["minRanks"] = "mnr",
    ["maxRevotes"] = "mrv",
    ["allowResponseChange"] = "arc",

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
    ["handleLoot"] = "hl",
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
    -- requireConfirmation removed in v2.0.7 (derived from `mode`); the
    -- "rc" short code remains reserved to avoid collision with future fields.

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
    self.preSessionSnapshot = nil  -- Settings snapshot for non-ML restore
    self.recentMLDBSenders = {}   -- Recent MLDB broadcasters for farewell message auth

    -- Recover any preSessionSnapshot persisted across /reload or
    -- disconnect.  If the user reloaded mid-session, this restores the
    -- snapshot to memory so the eventual SESSION_END / MLDB:Clear can
    -- correctly roll back the MLDB-applied overrides.  If the session
    -- died across the reload, RecoverIfOrphaned() (called from PEW
    -- after RestoreFromCache) will detect the orphan and restore
    -- immediately.
    if Loothing.Settings then
        local persisted = Loothing.Settings:Get("__mldbPreSessionSnapshot", nil)
        if type(persisted) == "table" and next(persisted) ~= nil then
            self.preSessionSnapshot = persisted
            Loothing:Debug("MLDB: recovered persisted preSessionSnapshot from SavedVariables")
        end
    end

    -- Register for communication events
    if Loothing.Comm then
        Loothing.Comm:RegisterCallback("OnMLDBBroadcast", function(_, data)
            self:OnMLDBBroadcast(data)
        end, self)
    end
end

--- Detect and restore an orphaned preSessionSnapshot.
-- Called from PEW after RestoreFromCache.  If we have a persisted
-- snapshot but neither an active restored session nor any group at all,
-- the session that wrote the snapshot is dead — restore the user's
-- pre-session settings immediately so they aren't silently stuck on the
-- previous ML's configuration (e.g. sessionTriggerDungeon=true that
-- overrode their original false).
function MLDBMixin:RecoverIfOrphaned()
    if not self.preSessionSnapshot then return end
    if Loothing.Session and Loothing.Session.IsActive
        and Loothing.Session:IsActive() then
        return  -- session restored from cache; snapshot still needed
    end
    if IsInGroup() then
        return  -- still grouped; ML may yet broadcast SESSION_END
    end
    Loothing:Debug("MLDB: orphaned preSessionSnapshot detected — restoring settings")
    self:Clear()
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

--- Check if a sender was a recent MLDB broadcaster.
-- Used to authenticate farewell messages (STOP_HANDLE_LOOT, SESSION_END)
-- from an old ML whose MLDB transferred the role. Tracks multiple recent
-- senders so double handoffs (A→B→C) still allow A's cleanup messages.
-- @param sender string
-- @return boolean
function MLDBMixin:WasPreviousMLSender(sender)
    if not sender or not self.recentMLDBSenders then
        return false
    end
    local key = Utils.NormalizeName(sender)
    return self.recentMLDBSenders[key] ~= nil
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

    -- v2.0.7: voting.privacy is the canonical field. We also broadcast
    -- the legacy anonymousVoting/hideVotes flags derived from it so
    -- v2.0.6-and-earlier clients still receive the privacy intent.
    -- Receivers running v2.0.7+ prefer `privacy` and ignore the legacy
    -- flags; receivers on v2.0.6 read the legacy flags and miss the
    -- "open" vs "hide_counts" distinction (default to open).
    local privacy = votingSettings.privacy or "open"
    settings.privacy        = privacy
    settings.anonymousVoting = privacy == "anonymous"
    settings.hideVotes      = privacy == "hide_counts"

    settings.mlSeesVotes    = votingSettings.mlSeesVotes or false
    settings.requireNotes   = votingSettings.requireNotes or false
    settings.autoAddRolls   = votingSettings.autoAddRolls ~= false  -- default true
    settings.maxRanks    = votingSettings.maxRanks or 0
    settings.minRanks    = votingSettings.minRanks or 1
    settings.maxRevotes  = votingSettings.maxRevotes or 2
    settings.allowResponseChange = votingSettings.allowResponseChange or false

    -- Observer settings
    settings.mlIsObserver = Loothing.Settings:Get("observers.mlIsObserver", false)
    settings.openObservation = Loothing.Settings:Get("observers.openObservation", false)
    settings.observerPermissions = Loothing.Settings:GetObserverPermissions()

    -- Session settings
    settings.votingTimeout = Loothing.Settings:Get("voting.timeout", 30)
    settings.votingMode = Loothing.Settings:Get("voting.mode", "SIMPLE")

    -- Session trigger policy
    settings.sessionTriggerAction   = Loothing.Settings:GetSessionTriggerAction()
    settings.sessionTriggerTiming   = Loothing.Settings:GetSessionTriggerTiming()
    settings.sessionTriggerRaid     = Loothing.Settings:GetSessionTriggerRaid()
    settings.sessionTriggerDungeon  = Loothing.Settings:GetSessionTriggerDungeon()
    settings.sessionTriggerOpenWorld = Loothing.Settings:GetSessionTriggerOpenWorld()
    settings.groupLootMode = Loothing.Settings:GetGroupLootMode()
    settings.handleLoot = Loothing.handleLoot or false
    settings.masterLooter = Loothing.explicitMasterLooter

    -- Sort order
    settings.sortOrder = Loothing.Settings:Get("councilTable.sortColumn", "response")

    -- Unified responseSets (full structure)
    settings.responseSets = Loothing.Settings:GetResponseSets()

    -- AutoPass settings
    settings.autoPass = {
        enabled       = Loothing.Settings:GetAutoPassEnabled(),
        weapons       = Loothing.Settings:GetAutoPassWeapons(),
        boe           = Loothing.Settings:Get("autoPass.boe") == true,
        transmog      = Loothing.Settings:Get("autoPass.transmog") == true,
        trinkets      = Loothing.Settings:Get("autoPass.trinkets") == true,
        transmogSource = Loothing.Settings:Get("autoPass.transmogSource") == true,
        silent        = Loothing.Settings:Get("autoPass.silent") == true,
    }

    -- AutoAward settings (legacy `reason` free-text removed in v2.0.7)
    settings.autoAward = {
        enabled        = Loothing.Settings:Get("autoAward.enabled") == true,
        lowerThreshold = Loothing.Settings:Get("autoAward.lowerThreshold", 2),
        upperThreshold = Loothing.Settings:Get("autoAward.upperThreshold", 4),
        awardTo        = Loothing.Settings:Get("autoAward.awardTo", ""),
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
    -- requireConfirmation removed in v2.0.7; receivers derive it from `mode`.
    settings.winnerDetermination = {
        mode                 = Loothing.Settings:Get("winnerDetermination.mode", "ML_CONFIRM"),
        tieBreaker           = Loothing.Settings:Get("winnerDetermination.tieBreaker", "ROLL"),
        autoAwardOnUnanimous = Loothing.Settings:Get("winnerDetermination.autoAwardOnUnanimous") == true,
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
-- Only the ML should call this. Skips the actual send if the compressed
-- payload is identical to the last broadcast — settings UIs often call this
-- reflexively on any change, and sending the same state 10× in 30 seconds
-- wastes WoW's per-message channel budget. Queue-level coalesce (Loolib) is
-- a second-line defense; this is the primary dirty check.
-- @param force boolean? - Skip IsML check AND dirty check (used during ML
--   reassignment where the caller has already verified authority, and where
--   the same-payload case legitimately needs to go out to the new raid).
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

    -- Dirty-track: skip send when nothing has changed. `compressed` is a
    -- TABLE (key-replacement output), so `==` would be identity-only and
    -- always false. Serialize to a deterministic string for content equality.
    -- Equal serialized bytes mean no new information for recipients. Force
    -- bypasses (fresh raid audience or post-ML-reassignment resend).
    local serialized = Loolib.Serializer and Loolib.Serializer:Serialize(compressed)
    if not force and serialized and self._lastBroadcastSerialized == serialized then
        Loothing:Debug("MLDB broadcast skipped: payload unchanged")
        return
    end
    self._lastBroadcastSerialized = serialized

    -- Send to raid
    Loothing.Comm:BroadcastMLDB(compressed)

    -- Trigger event
    self:TriggerEvent("OnMLDBBroadcast", settings)

    Loothing:Debug("Broadcast MLDB to raid")
end

--- Clear the MLDB broadcast dirty-check cache. Call on session end / ML
--- handoff / roster change so the next BroadcastToRaid unconditionally sends.
function MLDBMixin:InvalidateBroadcastCache()
    self._lastBroadcastSerialized = nil
end

--- Restore this player's local ML settings and force-publish them to the group.
-- Used after ML handoff: the new ML may still have the previous ML's MLDB
-- applied locally, so restore the pre-session snapshot before gathering.
-- @return boolean ok
-- @return string|nil reason
-- @return table|nil details
function MLDBMixin:RefreshLocalSettingsAndBroadcast()
    local playerName = Utils.GetPlayerFullName()
    if not playerName then
        return false, "no_player"
    end

    local isCurrentML = self:IsML()
        or (Loothing.IsCanonicalML and Loothing:IsCanonicalML())
        or (Loothing.Session and Loothing.Session.IsMasterLooter and Loothing.Session:IsMasterLooter())

    if not isCurrentML then
        return false, "not_ml"
    end

    local restoredSnapshot = self.preSessionSnapshot ~= nil
    local wasHandlingLoot = Loothing.handleLoot
    local normalizedPlayer = Utils.NormalizeName(playerName)
    local hadExplicitML = Loothing.explicitMasterLooter
        and Utils.IsSamePlayer(Loothing.explicitMasterLooter, playerName)

    if restoredSnapshot then
        self:RestoreSettings()
    end

    -- RestoreSettings() intentionally restores the pre-session runtime ML
    -- override too. Preserve raid-leader fallback mode unless the current ML
    -- was already an explicit ML assignment before the refresh.
    Loothing.explicitMasterLooter = hadExplicitML and normalizedPlayer or nil
    Loothing.masterLooter = normalizedPlayer
    Loothing.isMasterLooter = true
    Loothing.mlStateVerified = true
    Loothing.handleLoot = wasHandlingLoot

    if Loothing.Session and Loothing.Session:IsActive() then
        Loothing.Session.masterLooter = normalizedPlayer
    end

    if Loothing.Council and Loothing.Council.ClearRemoteRoster then
        Loothing.Council:ClearRemoteRoster()
    end
    if Loothing.Observer and Loothing.Observer.ClearRemoteObserverList then
        Loothing.Observer:ClearRemoteObserverList()
    end

    self:InvalidateBroadcastCache()
    if Loothing.Sync and Loothing.Sync.InvalidateBroadcastCaches then
        Loothing.Sync:InvalidateBroadcastCaches()
    end

    self:BroadcastToRaid(true)

    if Loothing.Sync then
        if Loothing.Sync.BroadcastCouncilRoster then
            Loothing.Sync:BroadcastCouncilRoster(true)
        end
        if Loothing.Sync.BroadcastObserverRoster then
            Loothing.Sync:BroadcastObserverRoster(true)
        end
    elseif Loothing.Council and Loothing.Comm and Loothing.Comm.BroadcastCouncilRoster then
        Loothing.Comm:BroadcastCouncilRoster(Loothing.Council:GetAllMembers())
    end

    return true, nil, {
        restoredSnapshot = restoredSnapshot,
        masterLooter = normalizedPlayer,
    }
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
    -- group member. Accept the MLDB so it can bootstrap explicit ML identity.

    -- Decompress
    local settings = self:DecompressFromTransmit(compressed)
    if not settings then
        Loothing:Error("Failed to decompress MLDB from", sender)
        return
    end

    -- Track recent MLDB senders for farewell message authentication.
    -- When an old ML transfers ML via MLDB and then sends cleanup messages,
    -- the comm handler needs to accept them even though the ML identity changed.
    -- We track multiple senders so double handoffs (A→B→C) still allow A's cleanup.
    if not self.recentMLDBSenders then self.recentMLDBSenders = {} end
    self.recentMLDBSenders[Utils.NormalizeName(sender)] = GetTime()
    -- Prune entries older than 5 minutes
    local now = GetTime()
    for name, t in pairs(self.recentMLDBSenders) do
        if now - t > 300 then
            self.recentMLDBSenders[name] = nil
        end
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

    -- Don't apply if we're the ML (we set our own settings).
    -- The ML's own MLDB is stored in BroadcastToRaid(); don't overwrite it here.
    if self:IsML() then
        Loothing:Debug("Skipping MLDB apply - we are ML")
        return
    end

    -- Store MLDB (after ML guard so only non-ML clients hold the received copy)
    self.mldb = settings

    -- Snapshot local settings before first MLDB overwrite so we can restore on session end
    if not self.preSessionSnapshot then
        self:SnapshotSettings()
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

        -- v2.0.7 voting privacy. Prefer the new explicit `privacy` field
        -- if present (v2.0.7+ ML), otherwise reconstruct from legacy
        -- anonymousVoting/hideVotes flags broadcast by a v2.0.6 ML.
        if settings.privacy ~= nil then
            votingSettings.privacy = settings.privacy
        elseif settings.anonymousVoting ~= nil or settings.hideVotes ~= nil then
            if settings.anonymousVoting == true then
                votingSettings.privacy = "anonymous"
            elseif settings.hideVotes == true then
                votingSettings.privacy = "hide_counts"
            else
                votingSettings.privacy = "open"
            end
        end
        -- Never write the legacy anonymousVoting/hideVotes/observe keys
        -- back to local storage; the migration removed them and they
        -- would just accumulate as orphans.

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
        if settings.allowResponseChange ~= nil then
            votingSettings.allowResponseChange = settings.allowResponseChange
        end

        Loothing.Settings:Set("voting", votingSettings)

        -- Apply session settings
        if settings.votingTimeout then
            Loothing.Settings:Set("voting.timeout", settings.votingTimeout)
        end
        if settings.votingMode then
            Loothing.Settings:Set("voting.mode", settings.votingMode)
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

        -- NOTE: settings.handleLoot is stored in self.mldb (line 500) but NOT
        -- applied to Loothing.handleLoot. That flag is ML-only and controls
        -- session creation, loot processing, and ML detection. Non-ML clients
        -- read mldb.handleLoot via MLDB:Get() in the auto-roll gate instead.

        -- Apply explicit ML override (runtime-only, not persisted)
        -- nil means "use raid leader"; a name means that player is ML
        Loothing.explicitMasterLooter = settings.masterLooter

        -- Synchronize global ML identity so all three sources agree.
        -- Without this, isMasterLooter() in Handlers/Core.lua can give
        -- inconsistent answers depending on which source it checks first.
        -- When settings.masterLooter is nil (cleared → use raid leader),
        -- we must also clear the global so it doesn't hold a stale name.
        Loothing.masterLooter = settings.masterLooter
        if Loothing.Session and Loothing.Session:IsActive() then
            Loothing.Session.masterLooter = settings.masterLooter or sender
        end

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

--- Clear MLDB (called on session end or StopHandleLoot)
-- Restores non-ML client settings from the pre-session snapshot. Also clears
-- the broadcast dirty-check cache so the next BroadcastToRaid is authoritative
-- for whatever audience follows (new raid, ML re-acquisition, etc.) — the
-- cache must not outlive the ML-state transition it was built against.
function MLDBMixin:Clear()
    self.mldb = nil
    self.recentMLDBSenders = {}
    self._lastBroadcastSerialized = nil
    self:RestoreSettings()
end

--[[--------------------------------------------------------------------
    Settings Snapshot / Restore (non-ML clients)
----------------------------------------------------------------------]]

--- Snapshot current local settings before ML overwrite.
-- Only call once per session (guarded in ApplyFromML).
function MLDBMixin:SnapshotSettings()
    if not Loothing.Settings then
        return
    end

    local snap = {}

    -- Voting settings (full table copy)
    snap.voting = Utils.DeepCopy(Loothing.Settings:Get("voting", {}))

    -- Session settings
    snap.votingTimeout = Loothing.Settings:Get("voting.timeout")
    snap.votingMode    = Loothing.Settings:Get("voting.mode")

    -- Session trigger policy
    snap.sessionTriggerAction   = Loothing.Settings:GetSessionTriggerAction()
    snap.sessionTriggerTiming   = Loothing.Settings:GetSessionTriggerTiming()
    snap.sessionTriggerRaid     = Loothing.Settings:GetSessionTriggerRaid()
    snap.sessionTriggerDungeon  = Loothing.Settings:GetSessionTriggerDungeon()
    snap.sessionTriggerOpenWorld = Loothing.Settings:GetSessionTriggerOpenWorld()
    snap.groupLootMode          = Loothing.Settings:GetGroupLootMode()

    -- Sort order
    snap.sortOrder = Loothing.Settings:Get("councilTable.sortColumn")

    -- Observer settings
    snap.mlIsObserver        = Loothing.Settings:Get("observers.mlIsObserver")
    snap.openObservation     = Loothing.Settings:Get("observers.openObservation")
    snap.observerPermissions = Utils.DeepCopy(Loothing.Settings:GetObserverPermissions())

    -- AutoPass / AutoAward / AwardReasons / WinnerDetermination / Announcements / IgnoreItems
    snap.autoPass            = Utils.DeepCopy(Loothing.Settings:Get("autoPass", {}))
    snap.autoAward           = Utils.DeepCopy(Loothing.Settings:Get("autoAward", {}))
    snap.awardReasons        = Utils.DeepCopy(Loothing.Settings:Get("awardReasons", {}))
    snap.winnerDetermination = Utils.DeepCopy(Loothing.Settings:Get("winnerDetermination", {}))
    snap.announcements       = Utils.DeepCopy(Loothing.Settings:Get("announcements", {}))
    snap.ignoreItems         = Utils.DeepCopy(Loothing.Settings:Get("ignoreItems", {}))

    -- Response sets
    if Loothing.ResponseManager then
        snap.responseSets = Loothing.ResponseManager:Serialize()
    end

    -- Runtime ML override (may be nil — that's the pre-session state)
    snap.explicitMasterLooter = Loothing.explicitMasterLooter

    self.preSessionSnapshot = snap

    -- Persist the snapshot to the active profile in SavedVariables so a
    -- /reload or crash mid-session does not silently strand the user on
    -- the ML's session-trigger / autoPass / response settings.  Init
    -- recovers it on next load, and RecoverIfOrphaned restores when
    -- appropriate.  Profile-scoped (not char-scoped): if the user
    -- switches profiles between snapshot-write and recovery the snapshot
    -- stays with the original profile, which is the correct semantic
    -- since the snapshot describes that profile's pre-session state.
    Loothing.Settings:Set("__mldbPreSessionSnapshot", snap)

    Loothing:Debug("Snapshot local settings before MLDB apply")
end

--- Restore local settings from snapshot after session ends.
-- No-op if no snapshot exists (ML client, or no MLDB was received).
function MLDBMixin:RestoreSettings()
    local snap = self.preSessionSnapshot
    if not snap then
        return
    end

    -- Clear snapshot first so a re-entrant call is harmless
    self.preSessionSnapshot = nil

    if not Loothing.Settings then
        return
    end

    -- Drop the persisted copy too — the in-memory snapshot we're about
    -- to apply IS the canonical pre-session state.  Done before the
    -- restore writes so a re-entrant Settings:Set chain can't repopulate
    -- the persisted slot from a half-applied state.
    Loothing.Settings:Set("__mldbPreSessionSnapshot", nil)

    Loothing:Debug("Restoring local settings from pre-session snapshot")

    -- Voting settings
    if snap.voting then
        Loothing.Settings:Set("voting", snap.voting)
    end

    -- Session settings
    if snap.votingTimeout ~= nil then
        Loothing.Settings:Set("voting.timeout", snap.votingTimeout)
    end
    if snap.votingMode ~= nil then
        Loothing.Settings:Set("voting.mode", snap.votingMode)
    end

    -- Session trigger policy (use ~= nil consistently for all fields)
    if snap.sessionTriggerAction ~= nil then
        Loothing.Settings:SetSessionTriggerAction(snap.sessionTriggerAction)
    end
    if snap.sessionTriggerTiming ~= nil then
        Loothing.Settings:SetSessionTriggerTiming(snap.sessionTriggerTiming)
    end
    if snap.sessionTriggerRaid ~= nil then
        Loothing.Settings:SetSessionTriggerRaid(snap.sessionTriggerRaid)
    end
    if snap.sessionTriggerDungeon ~= nil then
        Loothing.Settings:SetSessionTriggerDungeon(snap.sessionTriggerDungeon)
    end
    if snap.sessionTriggerOpenWorld ~= nil then
        Loothing.Settings:SetSessionTriggerOpenWorld(snap.sessionTriggerOpenWorld)
    end
    if snap.groupLootMode ~= nil then
        Loothing.Settings:SetGroupLootMode(snap.groupLootMode)
    end

    -- Sort order
    if snap.sortOrder ~= nil then
        Loothing.Settings:Set("councilTable.sortColumn", snap.sortOrder)
    end

    -- Observer settings
    if snap.mlIsObserver ~= nil then
        Loothing.Settings:Set("observers.mlIsObserver", snap.mlIsObserver)
    end
    if snap.openObservation ~= nil then
        Loothing.Settings:Set("observers.openObservation", snap.openObservation)
    end
    if snap.observerPermissions then
        Loothing.Settings:Set("observers.permissions", snap.observerPermissions)
    end

    -- Full table replacement (not per-key merge) so that any keys
    -- the MLDB added but weren't in the original are removed.
    if snap.autoPass then
        Loothing.Settings:Set("autoPass", snap.autoPass)
    end
    if snap.autoAward then
        Loothing.Settings:Set("autoAward", snap.autoAward)
    end
    if snap.awardReasons then
        Loothing.Settings:Set("awardReasons", snap.awardReasons)
    end
    if snap.winnerDetermination then
        Loothing.Settings:Set("winnerDetermination", snap.winnerDetermination)
    end
    if snap.announcements then
        Loothing.Settings:Set("announcements", snap.announcements)
    end
    if snap.ignoreItems then
        Loothing.Settings:Set("ignoreItems", snap.ignoreItems)
    end

    -- Response sets
    if snap.responseSets and Loothing.ResponseManager then
        Loothing.ResponseManager:Deserialize(snap.responseSets)
    end

    -- Restore runtime ML override to pre-session value (often nil)
    Loothing.explicitMasterLooter = snap.explicitMasterLooter

    Loothing:Debug("Restored local settings from pre-session snapshot")
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
