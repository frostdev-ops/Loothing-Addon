--[[--------------------------------------------------------------------
    Loothing - Loot Council Addon for WoW 12.0+
    MessageHandler - Message routing, sending, and receiving

    Uses LoolibComm for transport (handles chunking, throttling, queuing).
    Uses LoothingProtocol for encoding (Serializer + Compressor pipeline).
    Integrates with LoothingRestrictions for encounter restriction handling.
----------------------------------------------------------------------]]

local Loolib = LibStub("Loolib")

--[[--------------------------------------------------------------------
    LoothingCommMixin
----------------------------------------------------------------------]]

LoothingCommMixin = LoolibCreateFromMixins(LoolibCallbackRegistryMixin)

local COMM_EVENTS = {
    "OnSessionStart",
    "OnSessionEnd",
    "OnItemAdd",
    "OnItemRemove",
    "OnVoteRequest",
    "OnVoteCommit",
    "OnVoteCancel",
    "OnVoteResults",
    "OnVoteAward",
    "OnVoteSkip",
    "OnSyncRequest",
    "OnSyncData",
    "OnCouncilRoster",
    "OnObserverRoster",
    "OnPlayerInfoRequest",
    "OnPlayerInfoResponse",
    "OnPlayerResponse",
    "OnPlayerResponseAck",
    "OnVersionRequest",
    "OnVersionResponse",
    "OnMLDBBroadcast",
    "OnCandidateUpdate",
    "OnVoteUpdate",
    "OnStopHandleLoot",
    "OnTradable",
    "OnNonTradable",
    "OnHeartbeat",
    "OnAck",
}

--[[--------------------------------------------------------------------
    Batch Accumulator
----------------------------------------------------------------------]]

-- 100 ms collection window; messages keyed by "target:priority"
local BATCH_WINDOW   = 0.1
local MAX_BATCH_SIZE = 20

-- batchAccumulator[key] = { messages={}, target=, priority= }
local batchAccumulator = {}

local function GetBatchKey(target, priority)
    return (target or "_broadcast") .. ":" .. (priority or "NORMAL")
end

--[[--------------------------------------------------------------------
    Critical Commands (never downgraded by backpressure)
----------------------------------------------------------------------]]

local CRITICAL_COMMANDS = {
    [LOOTHING_MSG_TYPE.SESSION_START]       = true,
    [LOOTHING_MSG_TYPE.SESSION_END]         = true,
    [LOOTHING_MSG_TYPE.VOTE_AWARD]          = true,
    [LOOTHING_MSG_TYPE.VOTE_RESULTS]        = true,
    [LOOTHING_MSG_TYPE.PLAYER_RESPONSE]     = true,
    [LOOTHING_MSG_TYPE.PLAYER_RESPONSE_ACK] = true,
}

--- Command → handler method name dispatch table
local HANDLERS = {
    [LOOTHING_MSG_TYPE.SESSION_START]           = "HandleSessionStart",
    [LOOTHING_MSG_TYPE.SESSION_END]             = "HandleSessionEnd",
    [LOOTHING_MSG_TYPE.ITEM_ADD]                = "HandleItemAdd",
    [LOOTHING_MSG_TYPE.ITEM_REMOVE]             = "HandleItemRemove",
    [LOOTHING_MSG_TYPE.VOTE_REQUEST]            = "HandleVoteRequest",
    [LOOTHING_MSG_TYPE.VOTE_COMMIT]             = "HandleVoteCommit",
    [LOOTHING_MSG_TYPE.VOTE_CANCEL]             = "HandleVoteCancel",
    [LOOTHING_MSG_TYPE.VOTE_RESULTS]            = "HandleVoteResults",
    [LOOTHING_MSG_TYPE.VOTE_AWARD]              = "HandleVoteAward",
    [LOOTHING_MSG_TYPE.VOTE_SKIP]               = "HandleVoteSkip",
    [LOOTHING_MSG_TYPE.SYNC_REQUEST]            = "HandleSyncRequest",
    [LOOTHING_MSG_TYPE.SYNC_DATA]               = "HandleSyncData",
    [LOOTHING_MSG_TYPE.COUNCIL_ROSTER]          = "HandleCouncilRoster",
    [LOOTHING_MSG_TYPE.OBSERVER_ROSTER]         = "HandleObserverRoster",
    [LOOTHING_MSG_TYPE.PLAYER_INFO_REQUEST]     = "HandlePlayerInfoRequest",
    [LOOTHING_MSG_TYPE.PLAYER_INFO_RESPONSE]    = "HandlePlayerInfoResponse",
    [LOOTHING_MSG_TYPE.PLAYER_RESPONSE]         = "HandlePlayerResponse",
    [LOOTHING_MSG_TYPE.PLAYER_RESPONSE_ACK]     = "HandlePlayerResponseAck",
    [LOOTHING_MSG_TYPE.VERSION_REQUEST]         = "HandleVersionRequest",
    [LOOTHING_MSG_TYPE.VERSION_RESPONSE]        = "HandleVersionResponse",
    [LOOTHING_MSG_TYPE.MLDB_BROADCAST]          = "HandleMLDBBroadcast",
    [LOOTHING_MSG_TYPE.CANDIDATE_UPDATE]        = "HandleCandidateUpdate",
    [LOOTHING_MSG_TYPE.VOTE_UPDATE]             = "HandleVoteUpdate",
    [LOOTHING_MSG_TYPE.SYNC_SETTINGS_REQUEST]   = "HandleSettingsSyncRequest",
    [LOOTHING_MSG_TYPE.SYNC_SETTINGS_ACK]       = "HandleSettingsSyncAck",
    [LOOTHING_MSG_TYPE.SYNC_SETTINGS_DATA]      = "HandleSettingsData",
    [LOOTHING_MSG_TYPE.SYNC_HISTORY_REQUEST]    = "HandleHistorySyncRequest",
    [LOOTHING_MSG_TYPE.SYNC_HISTORY_ACK]        = "HandleHistorySyncAck",
    [LOOTHING_MSG_TYPE.SYNC_HISTORY_DATA]       = "HandleHistoryData",
    [LOOTHING_MSG_TYPE.XREALM]                  = "HandleXRealm",
    [LOOTHING_MSG_TYPE.STOP_HANDLE_LOOT]        = "HandleStopHandleLoot",
    [LOOTHING_MSG_TYPE.TRADABLE]                = "HandleTradable",
    [LOOTHING_MSG_TYPE.NON_TRADABLE]            = "HandleNonTradable",
    -- Burst / resilience infrastructure
    [LOOTHING_MSG_TYPE.BATCH]                   = "HandleBatch",
    [LOOTHING_MSG_TYPE.HEARTBEAT]               = "HandleHeartbeat",
    [LOOTHING_MSG_TYPE.ACK]                     = "HandleAck",
}

--- Initialize communication handler
function LoothingCommMixin:Init()
    LoolibCallbackRegistryMixin.OnLoad(self)
    self:GenerateCallbackEvents(COMM_EVENTS)

    -- Register with LoolibComm for incoming addon messages
    -- LoolibComm handles: prefix registration, message reassembly, throttling
    LoolibComm:RegisterComm(LOOTHING_ADDON_PREFIX, function(prefix, message, distribution, sender)
        self:OnMessage(message, distribution, sender)
    end, self)
end

--[[--------------------------------------------------------------------
    Core Send / Receive
----------------------------------------------------------------------]]

--- Send a command + data to group or a specific player
-- @param command string - LOOTHING_MSG_TYPE value
-- @param data table|nil - Structured message payload
-- @param target string|nil - Player name for WHISPER, nil for group broadcast
-- @param priority string|nil - "ALERT", "NORMAL" (default), or "BULK"
function LoothingCommMixin:Send(command, data, target, priority)
    local encoded = LoothingProtocol:Encode(command, data)
    if not encoded then return end

    -- Test mode intercept
    if LoothingTestMode and LoothingTestMode.OnOutgoingComm then
        local channel = target and "WHISPER" or (IsInRaid() and "RAID" or "PARTY")
        LoothingTestMode:OnOutgoingComm(channel, target)
    end

    -- Backpressure: downgrade non-critical NORMAL to BULK when queue is under pressure
    local prio = priority or "NORMAL"
    if prio == "NORMAL"
        and not CRITICAL_COMMANDS[command]
        and LoolibComm:GetQueuePressure() > 0.5
    then
        prio = "BULK"
    end

    if target then
        LoolibComm:SendCommMessage(LOOTHING_ADDON_PREFIX, encoded, "WHISPER", target, prio)
    else
        local channel = IsInRaid() and "RAID" or "PARTY"
        LoolibComm:SendCommMessage(LOOTHING_ADDON_PREFIX, encoded, channel, nil, prio)
    end
end

--[[--------------------------------------------------------------------
    Send Batcher (Phase 3B)
    Accumulates messages over a 100 ms window then flushes as a single
    BATCH message. Single-message bursts bypass the BATCH wrapper.
----------------------------------------------------------------------]]

--- Queue a message for batched delivery
-- Callers should call FlushAll() when the burst is complete to drain
-- immediately; otherwise the 100 ms window timer fires automatically.
-- @param command string - LOOTHING_MSG_TYPE value
-- @param data table|nil - Message payload
-- @param target string|nil - Player name or nil for broadcast
-- @param priority string|nil - "ALERT", "NORMAL", or "BULK"
function LoothingCommMixin:QueueForBatch(command, data, target, priority)
    local key   = GetBatchKey(target, priority)
    local batch = batchAccumulator[key]

    if not batch then
        batch = { messages = {}, target = target, priority = priority }
        batchAccumulator[key] = batch

        -- Schedule automatic flush at end of collection window
        C_Timer.After(BATCH_WINDOW, function()
            if batchAccumulator[key] then
                self:FlushBatch(key)
            end
        end)
    end

    batch.messages[#batch.messages + 1] = { command = command, data = data }

    -- Eagerly flush when the batch is full
    if #batch.messages >= MAX_BATCH_SIZE then
        self:FlushBatch(key)
    end
end

--- Flush a pending batch immediately
-- @param key string - Batch key from GetBatchKey
function LoothingCommMixin:FlushBatch(key)
    local batch = batchAccumulator[key]
    if not batch then return end
    batchAccumulator[key] = nil

    if #batch.messages == 0 then return end

    -- Single message: bypass BATCH wrapper (no overhead)
    if #batch.messages == 1 then
        local inner = batch.messages[1]
        self:Send(inner.command, inner.data, batch.target, batch.priority)
        return
    end

    -- Multiple messages: wrap in BATCH container
    self:Send(LOOTHING_MSG_TYPE.BATCH, {
        messages = batch.messages,
    }, batch.target, batch.priority)
end

--- Flush all pending batches immediately
function LoothingCommMixin:FlushAll()
    -- Collect keys first to avoid modifying table during iteration
    local keys = {}
    for k in pairs(batchAccumulator) do
        keys[#keys + 1] = k
    end
    for _, k in ipairs(keys) do
        self:FlushBatch(k)
    end
end

--- Send a command to the guild channel
-- @param command string - LOOTHING_MSG_TYPE value
-- @param data table|nil - Message payload
-- @param priority string|nil
function LoothingCommMixin:SendGuild(command, data, priority)
    if not IsInGuild() then
        Loothing:Debug("Cannot send to GUILD: not in a guild")
        return
    end

    local encoded = LoothingProtocol:Encode(command, data)
    if not encoded then return end

    if LoothingTestMode and LoothingTestMode.OnOutgoingComm then
        LoothingTestMode:OnOutgoingComm("GUILD", nil)
    end

    LoolibComm:SendCommMessage(LOOTHING_ADDON_PREFIX, encoded, "GUILD", nil, priority or "NORMAL")
end

--- Send with guaranteed delivery (queued during encounter restrictions)
-- Critical messages (votes, awards, session_end) should use this.
-- @param command string - LOOTHING_MSG_TYPE value
-- @param data table|nil - Message payload
-- @param target string|nil - Player name or nil for group
-- @param priority string|nil
function LoothingCommMixin:SendGuaranteed(command, data, target, priority)
    -- Check encounter restrictions
    if Loothing.Restrictions and Loothing.Restrictions:IsRestricted() then
        Loothing.Restrictions:QueueGuaranteed(command, data, target, priority)
        Loothing:Debug("Comm restricted, queued:", command)
        return
    end

    -- Not restricted, send immediately
    self:Send(command, data, target, priority)
end

--- Send via cross-realm relay (group channel with target envelope)
-- Use when direct whisper to a cross-realm player fails or is unreliable.
-- @param command string - LOOTHING_MSG_TYPE value
-- @param data table|nil - Message payload
-- @param target string - Target player name (with realm suffix)
-- @param priority string|nil
function LoothingCommMixin:SendViaRelay(command, data, target, priority)
    self:Send(LOOTHING_MSG_TYPE.XREALM, {
        target = target,
        command = command,
        data = data,
    }, nil, priority)
end

--[[--------------------------------------------------------------------
    Message Receiving
----------------------------------------------------------------------]]

--- Handle incoming addon message (LoolibComm callback)
-- @param message string - Encoded message (already reassembled if multi-part)
-- @param distribution string - Channel received on
-- @param sender string - Sender name
function LoothingCommMixin:OnMessage(message, distribution, sender)
    -- Decode message
    local version, command, data = LoothingProtocol:Decode(message)

    if not version or not command then
        Loothing:Debug("Failed to decode message from", sender)
        return
    end

    -- Version check
    if version > LOOTHING_PROTOCOL_VERSION then
        Loothing:Debug("Received message from newer protocol version:", version, "from", sender)
        -- Still try to process - might be backwards compatible
    end

    -- Normalize sender name
    sender = LoothingUtils.NormalizeName(sender)

    -- Route to handler
    self:RouteMessage(command, data, sender, distribution)
end

--- Route a decoded message to appropriate handler
-- @param command string - LOOTHING_MSG_TYPE value
-- @param data table - Deserialized message data
-- @param sender string - Normalized sender name
-- @param distribution string - Channel
function LoothingCommMixin:RouteMessage(command, data, sender, distribution)
    Loothing:Debug("Received:", command, "from", sender)

    local handlerName = HANDLERS[command]
    if handlerName and self[handlerName] then
        self[handlerName](self, data, sender, distribution)
    else
        Loothing:Debug("Unknown message type:", command)
    end
end

--[[--------------------------------------------------------------------
    Cross-Realm Handler
----------------------------------------------------------------------]]

--- Handle cross-realm relay messages
-- Unwrap the envelope and route to the inner command if we're the target.
-- @param data table - { target, command, data }
-- @param sender string
-- @param distribution string
function LoothingCommMixin:HandleXRealm(data, sender, distribution)
    if not data or not data.target then return end

    -- Prevent recursive processing: inner message must not be XREALM or BATCH
    if data.command == LOOTHING_MSG_TYPE.XREALM or data.command == LOOTHING_MSG_TYPE.BATCH then
        Loothing:Debug("HandleXRealm: blocked recursive", data.command, "from", sender)
        return
    end

    local localName = LoothingUtils.GetPlayerFullName()
    if not LoothingUtils.IsSamePlayer(data.target, localName) then
        return -- Not for us
    end

    -- Unwrap and route the inner message
    if data.command then
        self:RouteMessage(data.command, data.data, sender, "XREALM")
    end
end

--[[--------------------------------------------------------------------
    Broadcast Helpers - Session Management
----------------------------------------------------------------------]]

--- Broadcast session start
-- @param encounterID number
-- @param encounterName string
-- @param sessionID string|nil
function LoothingCommMixin:BroadcastSessionStart(encounterID, encounterName, sessionID)
    self:Send(LOOTHING_MSG_TYPE.SESSION_START, {
        encounterID = encounterID,
        encounterName = encounterName,
        sessionID = sessionID,
    })
end

--- Broadcast session end
function LoothingCommMixin:BroadcastSessionEnd()
    self:SendGuaranteed(LOOTHING_MSG_TYPE.SESSION_END, {})
end

--- Broadcast that ML has stopped handling loot entirely
function LoothingCommMixin:BroadcastStopHandleLoot()
    self:Send(LOOTHING_MSG_TYPE.STOP_HANDLE_LOOT, {})
end

--- Broadcast item added
-- @param itemLink string
-- @param guid string
-- @param looter string
function LoothingCommMixin:BroadcastItemAdd(itemLink, guid, looter)
    self:Send(LOOTHING_MSG_TYPE.ITEM_ADD, {
        itemLink = itemLink,
        guid = guid,
        looter = looter,
    })
end

--- Broadcast item removed
-- @param guid string
function LoothingCommMixin:BroadcastItemRemove(guid)
    self:Send(LOOTHING_MSG_TYPE.ITEM_REMOVE, {
        guid = guid,
    })
end

--[[--------------------------------------------------------------------
    Broadcast Helpers - Voting
----------------------------------------------------------------------]]

--- Broadcast vote request
-- @param itemGUID string
-- @param timeout number
-- @param sessionID string|nil
function LoothingCommMixin:BroadcastVoteRequest(itemGUID, timeout, sessionID)
    self:Send(LOOTHING_MSG_TYPE.VOTE_REQUEST, {
        itemGUID = itemGUID,
        timeout = timeout,
        sessionID = sessionID,
    })
end

--- Send vote commit to ML
-- @param itemGUID string
-- @param responses table
-- @param masterLooter string
-- @param sessionID string|nil
function LoothingCommMixin:SendVoteCommit(itemGUID, responses, masterLooter, sessionID)
    self:SendGuaranteed(LOOTHING_MSG_TYPE.VOTE_COMMIT, {
        itemGUID = itemGUID,
        responses = responses,
        sessionID = sessionID,
    }, masterLooter)
end

--- Broadcast vote award
-- @param itemGUID string
-- @param winnerName string
-- @param sessionID string|nil
function LoothingCommMixin:BroadcastVoteAward(itemGUID, winnerName, sessionID)
    self:SendGuaranteed(LOOTHING_MSG_TYPE.VOTE_AWARD, {
        itemGUID = itemGUID,
        winner = winnerName,
        sessionID = sessionID,
    })
end

--- Broadcast vote skip
-- @param itemGUID string
-- @param sessionID string|nil
function LoothingCommMixin:BroadcastVoteSkip(itemGUID, sessionID)
    self:SendGuaranteed(LOOTHING_MSG_TYPE.VOTE_SKIP, {
        itemGUID = itemGUID,
        sessionID = sessionID,
    })
end

--- Broadcast vote cancellation
-- @param itemGUID string
-- @param sessionID string|nil
function LoothingCommMixin:BroadcastVoteCancel(itemGUID, sessionID)
    self:Send(LOOTHING_MSG_TYPE.VOTE_CANCEL, {
        itemGUID = itemGUID,
        sessionID = sessionID,
    })
end

--- Broadcast vote results/closure
-- @param itemGUID string
-- @param results table
-- @param sessionID string|nil
function LoothingCommMixin:BroadcastVoteResults(itemGUID, results, sessionID)
    self:SendGuaranteed(LOOTHING_MSG_TYPE.VOTE_RESULTS, {
        itemGUID = itemGUID,
        results = results,
        sessionID = sessionID,
    })
end

--[[--------------------------------------------------------------------
    Broadcast Helpers - Council & Sync
----------------------------------------------------------------------]]

--- Broadcast council roster
-- @param members table
function LoothingCommMixin:BroadcastCouncilRoster(members)
    self:Send(LOOTHING_MSG_TYPE.COUNCIL_ROSTER, {
        members = members,
    })
end

--- Request sync from ML
-- @param masterLooter string
function LoothingCommMixin:RequestSync(masterLooter)
    self:Send(LOOTHING_MSG_TYPE.SYNC_REQUEST, {
        timestamp = time(),
    }, masterLooter)
end

--- Send sync data to requester
-- @param sessionData table
-- @param target string
function LoothingCommMixin:SendSyncData(sessionData, target)
    self:Send(LOOTHING_MSG_TYPE.SYNC_DATA, sessionData, target)
end

--[[--------------------------------------------------------------------
    Broadcast Helpers - Player Info & Responses
----------------------------------------------------------------------]]

--- Request player info (gear comparison)
-- @param itemGUID string
-- @param playerName string
function LoothingCommMixin:RequestPlayerInfo(itemGUID, playerName)
    self:Send(LOOTHING_MSG_TYPE.PLAYER_INFO_REQUEST, {
        itemGUID = itemGUID,
        playerName = playerName,
    }, playerName)
end

--- Send player info response
-- @param itemGUID string
-- @param slot1Link string|nil
-- @param slot2Link string|nil
-- @param slot1ilvl number
-- @param slot2ilvl number
-- @param target string
-- @param sessionID string|nil
function LoothingCommMixin:SendPlayerInfo(itemGUID, slot1Link, slot2Link, slot1ilvl, slot2ilvl, target, sessionID)
    self:Send(LOOTHING_MSG_TYPE.PLAYER_INFO_RESPONSE, {
        itemGUID = itemGUID,
        slot1Link = slot1Link,
        slot2Link = slot2Link,
        slot1ilvl = slot1ilvl or 0,
        slot2ilvl = slot2ilvl or 0,
        sessionID = sessionID,
    }, target)
end

--- Send player response (raid member -> ML)
-- @param itemGUID string
-- @param response number - LOOTHING_RESPONSE value
-- @param note string|nil
-- @param roll number|nil
-- @param rollMin number|nil
-- @param rollMax number|nil
-- @param masterLooter string
-- @param sessionID string|nil
function LoothingCommMixin:SendPlayerResponse(itemGUID, response, note, roll, rollMin, rollMax, masterLooter, sessionID)
    -- In test mode, short-circuit network and invoke locally.
    -- Deferred one frame so RollFrame:StartAckTimeout() runs before the ACK arrives.
    if LoothingTestMode and LoothingTestMode:IsEnabled() then
        local payload = {
            itemGUID = itemGUID,
            response = response,
            note = note ~= "" and note or nil,
            roll = roll,
            rollMin = rollMin or 1,
            rollMax = rollMax or 100,
            playerName = LoothingUtils.GetPlayerFullName(),
            sessionID = sessionID,
        }
        C_Timer.After(0, function()
            if Loothing.Session then
                Loothing.Session:HandlePlayerResponse(payload)
            end
        end)
        return
    end

    self:SendGuaranteed(LOOTHING_MSG_TYPE.PLAYER_RESPONSE, {
        itemGUID = itemGUID,
        response = response,
        note = note ~= "" and note or nil,
        roll = roll,
        rollMin = rollMin or 1,
        rollMax = rollMax or 100,
        sessionID = sessionID,
    }, masterLooter)
end

--- Send player response acknowledgment (ML -> raid member)
-- @param itemGUID string
-- @param success boolean
-- @param target string
-- @param sessionID string|nil
function LoothingCommMixin:SendPlayerResponseAck(itemGUID, success, target, sessionID)
    -- In test mode, short-circuit network and invoke locally
    if LoothingTestMode and LoothingTestMode:IsEnabled() then
        local payload = {
            itemGUID = itemGUID,
            success = success,
            sessionID = sessionID,
            masterLooter = LoothingUtils.GetPlayerFullName(),
        }
        if Loothing.Session then
            Loothing.Session:HandlePlayerResponseAck(payload)
        end
        return
    end

    self:Send(LOOTHING_MSG_TYPE.PLAYER_RESPONSE_ACK, {
        itemGUID = itemGUID,
        success = success,
        sessionID = sessionID,
    }, target)
end

--[[--------------------------------------------------------------------
    Broadcast Helpers - Candidate & Vote Updates
----------------------------------------------------------------------]]

--- Broadcast candidate update (ML -> Council)
-- @param itemGUID string
-- @param candidateData table
-- @param sessionID string|nil
function LoothingCommMixin:BroadcastCandidateUpdate(itemGUID, candidateData, sessionID)
    self:Send(LOOTHING_MSG_TYPE.CANDIDATE_UPDATE, {
        itemGUID = itemGUID,
        candidateData = candidateData,
        sessionID = sessionID,
    })
end

--- Broadcast vote update (ML -> Council)
-- @param itemGUID string
-- @param candidateName string
-- @param voters table
-- @param sessionID string|nil
function LoothingCommMixin:BroadcastVoteUpdate(itemGUID, candidateName, voters, sessionID)
    self:Send(LOOTHING_MSG_TYPE.VOTE_UPDATE, {
        itemGUID = itemGUID,
        candidateName = candidateName,
        voters = voters,
        sessionID = sessionID,
    })
end

--[[--------------------------------------------------------------------
    Broadcast Helpers - MLDB & Version
----------------------------------------------------------------------]]

--- Broadcast MLDB (Master Looter Database)
-- @param mldbData table - Compressed MLDB data
function LoothingCommMixin:BroadcastMLDB(mldbData)
    self:Send(LOOTHING_MSG_TYPE.MLDB_BROADCAST, {
        data = mldbData,
    })
end

--- Send version request
-- @param target string|nil - "guild" for guild, nil for group, or player name
function LoothingCommMixin:SendVersionRequest(target)
    if target == "guild" then
        self:SendGuild(LOOTHING_MSG_TYPE.VERSION_REQUEST, {})
    elseif target then
        self:Send(LOOTHING_MSG_TYPE.VERSION_REQUEST, {}, target)
    else
        self:Send(LOOTHING_MSG_TYPE.VERSION_REQUEST, {})
    end
end

--- Send version response
-- @param target string - Player to respond to
function LoothingCommMixin:SendVersionResponse(target)
    self:Send(LOOTHING_MSG_TYPE.VERSION_RESPONSE, {
        version = LOOTHING_VERSION,
    }, target)
end

--[[--------------------------------------------------------------------
    Broadcast Helpers - Sync (Settings & History)
----------------------------------------------------------------------]]

--- Send settings sync request
-- @param target string - "guild" or player name
function LoothingCommMixin:SendSettingsSyncRequest(target)
    if target == "guild" then
        self:SendGuild(LOOTHING_MSG_TYPE.SYNC_SETTINGS_REQUEST, {})
    else
        self:Send(LOOTHING_MSG_TYPE.SYNC_SETTINGS_REQUEST, {}, target)
    end
end

--- Send settings sync acknowledgment
-- @param target string
function LoothingCommMixin:SendSettingsSyncAck(target)
    self:Send(LOOTHING_MSG_TYPE.SYNC_SETTINGS_ACK, {}, target)
end

--- Send settings data
-- @param settingsData table - Serialized settings
-- @param target string
function LoothingCommMixin:SendSettingsData(settingsData, target)
    self:Send(LOOTHING_MSG_TYPE.SYNC_SETTINGS_DATA, {
        data = settingsData,
    }, target, "BULK")
end

--- Send history sync request
-- @param target string - "guild" or player name
-- @param days number
function LoothingCommMixin:SendHistorySyncRequest(target, days)
    if target == "guild" then
        self:SendGuild(LOOTHING_MSG_TYPE.SYNC_HISTORY_REQUEST, { days = days })
    else
        self:Send(LOOTHING_MSG_TYPE.SYNC_HISTORY_REQUEST, { days = days }, target)
    end
end

--- Send history sync acknowledgment
-- @param target string
function LoothingCommMixin:SendHistorySyncAck(target)
    self:Send(LOOTHING_MSG_TYPE.SYNC_HISTORY_ACK, {}, target)
end

--- Send history data
-- @param historyData table - History entries
-- @param target string
function LoothingCommMixin:SendHistoryData(historyData, target)
    self:Send(LOOTHING_MSG_TYPE.SYNC_HISTORY_DATA, {
        data = historyData,
    }, target, "BULK")
end
