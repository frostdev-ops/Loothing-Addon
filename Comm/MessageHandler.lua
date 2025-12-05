--[[--------------------------------------------------------------------
    Loothing - Loot Council Addon for WoW 12.0+
    MessageHandler - Incoming message routing and handling
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
    "OnVoteRequest",
    "OnVoteCommit",
    "OnVoteAward",
    "OnVoteSkip",
    "OnSyncRequest",
    "OnSyncData",
    "OnCouncilRoster",
    "OnPlayerInfoRequest",
    "OnPlayerInfoResponse",
    "OnVersionRequest",
    "OnVersionResponse",
}

--- Initialize communication handler
function LoothingCommMixin:Init()
    LoolibCallbackRegistryMixin.OnLoad(self)
    self:GenerateCallbackEvents(COMM_EVENTS)

    self.pendingChunks = {}  -- { messageID = { chunks } }
    self.messageQueue = {}   -- Outgoing message queue
    self.lastSendTime = 0
    self.throttleTime = LOOTHING_TIMING.MESSAGE_THROTTLE
end

--[[--------------------------------------------------------------------
    Message Sending
----------------------------------------------------------------------]]

--- Send a message to raid
-- @param message string - Encoded message
-- @param target string - Optional: whisper target
function LoothingCommMixin:Send(message, target)
    if not message then return end

    -- Test mode: skip actual message sending
    if LoothingTestMode and LoothingTestMode:IsEnabled() then
        Loothing:Debug("Test mode: Skipping message send")
        return
    end

    local channel = target and "WHISPER" or (IsInRaid() and "RAID" or "PARTY")

    -- Check if chunking needed
    if LoothingProtocol:NeedsChunking(message) then
        local chunks = LoothingProtocol:Chunk(message)
        for _, chunk in ipairs(chunks) do
            self:QueueMessage(chunk, channel, target)
        end
    else
        self:QueueMessage(message, channel, target)
    end

    -- Process queue
    self:ProcessQueue()
end

--- Send a message to guild
-- @param message string - Encoded message
function LoothingCommMixin:SendGuild(message)
    if not message then return end

    if not IsInGuild() then
        Loothing:Debug("Cannot send to GUILD: not in a guild")
        return
    end

    -- Test mode: skip actual message sending
    if LoothingTestMode and LoothingTestMode:IsEnabled() then
        Loothing:Debug("Test mode: Skipping guild message send")
        return
    end

    -- Check if chunking needed
    if LoothingProtocol:NeedsChunking(message) then
        local chunks = LoothingProtocol:Chunk(message)
        for _, chunk in ipairs(chunks) do
            self:QueueMessage(chunk, "GUILD", nil)
        end
    else
        self:QueueMessage(message, "GUILD", nil)
    end

    -- Process queue
    self:ProcessQueue()
end

--- Send a message to a specific player
-- @param message string - Encoded message
-- @param playerName string
function LoothingCommMixin:SendToPlayer(message, playerName)
    if not message or not playerName then return end

    -- Normalize player name
    playerName = LoothingUtils.NormalizeName(playerName)

    self:Send(message, playerName)
end

--- Queue a message for sending
-- @param message string
-- @param channel string
-- @param target string|nil
function LoothingCommMixin:QueueMessage(message, channel, target)
    self.messageQueue[#self.messageQueue + 1] = {
        message = message,
        channel = channel,
        target = target,
    }
end

--- Process the message queue with throttling
function LoothingCommMixin:ProcessQueue()
    local now = GetTime()

    while #self.messageQueue > 0 do
        if now - self.lastSendTime < self.throttleTime then
            -- Schedule next processing
            C_Timer.After(self.throttleTime, function()
                self:ProcessQueue()
            end)
            return
        end

        local msg = table.remove(self.messageQueue, 1)
        self:SendImmediate(msg.message, msg.channel, msg.target)
        self.lastSendTime = GetTime()
    end
end

--- Send a message immediately
-- @param message string
-- @param channel string
-- @param target string|nil
function LoothingCommMixin:SendImmediate(message, channel, target)
    local result

    if target then
        result = C_ChatInfo.SendAddonMessage(LOOTHING_ADDON_PREFIX, message, "WHISPER", target)
    else
        result = C_ChatInfo.SendAddonMessage(LOOTHING_ADDON_PREFIX, message, channel)
    end

    if result ~= Enum.SendAddonMessageResult.Success then
        Loothing:Debug("Failed to send message:", result)
    end

    return result == Enum.SendAddonMessageResult.Success
end

--[[--------------------------------------------------------------------
    Message Receiving
----------------------------------------------------------------------]]

--- Handle incoming addon message
-- @param message string - Raw message
-- @param channel string - Channel received on
-- @param sender string - Sender name
function LoothingCommMixin:OnMessage(message, channel, sender)
    -- Decode message
    local version, msgType, payload = LoothingProtocol:Decode(message)

    if not version or not msgType then
        Loothing:Debug("Failed to decode message from", sender)
        return
    end

    -- Version check
    if version > LOOTHING_PROTOCOL_VERSION then
        Loothing:Debug("Received message from newer protocol version:", version)
        -- Still try to process - might be backwards compatible
    end

    -- Normalize sender name
    sender = LoothingUtils.NormalizeName(sender)

    -- Handle chunked messages
    if msgType == LOOTHING_MSG_TYPE.CHUNK then
        self:HandleChunk(payload, sender)
        return
    end

    -- Route to handler
    self:RouteMessage(msgType, payload, sender, channel)
end

--- Handle a chunk message
-- @param payload table - { messageID, seq, total, data }
-- @param sender string
function LoothingCommMixin:HandleChunk(payload, sender)
    if #payload < 4 then return end

    local messageID = payload[1]
    local seq = tonumber(payload[2])
    local total = tonumber(payload[3])
    local data = payload[4]

    -- Create chunk storage for this message
    local key = sender .. "-" .. messageID
    if not self.pendingChunks[key] then
        self.pendingChunks[key] = {
            sender = sender,
            chunks = {},
            startTime = GetTime(),
        }
    end

    -- Store chunk
    self.pendingChunks[key].chunks[#self.pendingChunks[key].chunks + 1] = {
        seq = seq,
        total = total,
        data = data,
    }

    -- Check if complete
    if #self.pendingChunks[key].chunks >= total then
        local fullMessage = LoothingProtocol:Reassemble(self.pendingChunks[key].chunks)
        self.pendingChunks[key] = nil

        if fullMessage then
            -- Process the reassembled message
            local version, msgType, reassembledPayload = LoothingProtocol:Decode(fullMessage)
            if msgType and msgType ~= LOOTHING_MSG_TYPE.CHUNK then
                self:RouteMessage(msgType, reassembledPayload, sender, "REASSEMBLED")
            end
        end
    end

    -- Cleanup old pending chunks (older than 30 seconds)
    local now = GetTime()
    for k, v in pairs(self.pendingChunks) do
        if now - v.startTime > 30 then
            self.pendingChunks[k] = nil
        end
    end
end

--- Route a decoded message to appropriate handler
-- @param msgType string
-- @param payload table
-- @param sender string
-- @param channel string
function LoothingCommMixin:RouteMessage(msgType, payload, sender, channel)
    Loothing:Debug("Received message:", msgType, "from", sender)

    if msgType == LOOTHING_MSG_TYPE.SESSION_START then
        self:HandleSessionStart(payload, sender)

    elseif msgType == LOOTHING_MSG_TYPE.SESSION_END then
        self:HandleSessionEnd(payload, sender)

    elseif msgType == LOOTHING_MSG_TYPE.ITEM_ADD then
        self:HandleItemAdd(payload, sender)

    elseif msgType == LOOTHING_MSG_TYPE.ITEM_REMOVE then
        self:HandleItemRemove(payload, sender)

    elseif msgType == LOOTHING_MSG_TYPE.VOTE_REQUEST then
        self:HandleVoteRequest(payload, sender)

    elseif msgType == LOOTHING_MSG_TYPE.VOTE_COMMIT then
        self:HandleVoteCommit(payload, sender)

    elseif msgType == LOOTHING_MSG_TYPE.VOTE_CANCEL then
        self:HandleVoteCancel(payload, sender)

    elseif msgType == LOOTHING_MSG_TYPE.VOTE_AWARD then
        self:HandleVoteAward(payload, sender)

    elseif msgType == LOOTHING_MSG_TYPE.VOTE_SKIP then
        self:HandleVoteSkip(payload, sender)

    elseif msgType == LOOTHING_MSG_TYPE.SYNC_REQUEST then
        self:HandleSyncRequest(payload, sender)

    elseif msgType == LOOTHING_MSG_TYPE.SYNC_DATA then
        self:HandleSyncData(payload, sender)

    elseif msgType == LOOTHING_MSG_TYPE.COUNCIL_ROSTER then
        self:HandleCouncilRoster(payload, sender)

    elseif msgType == LOOTHING_MSG_TYPE.PLAYER_INFO_REQUEST then
        self:HandlePlayerInfoRequest(payload, sender)

    elseif msgType == LOOTHING_MSG_TYPE.PLAYER_INFO_RESPONSE then
        self:HandlePlayerInfoResponse(payload, sender)

    elseif msgType == LOOTHING_MSG_TYPE.VERSION_REQUEST then
        self:HandleVersionRequest(payload, sender)

    elseif msgType == LOOTHING_MSG_TYPE.VERSION_RESPONSE then
        self:HandleVersionResponse(payload, sender)

    else
        Loothing:Debug("Unknown message type:", msgType)
    end
end

--[[--------------------------------------------------------------------
    Message Handlers
----------------------------------------------------------------------]]

function LoothingCommMixin:HandleSessionStart(payload, sender)
    local encounterID = tonumber(payload[1])
    local encounterName = payload[2]

    self:TriggerEvent("OnSessionStart", {
        encounterID = encounterID,
        encounterName = encounterName,
        masterLooter = sender,
    })
end

function LoothingCommMixin:HandleSessionEnd(payload, sender)
    self:TriggerEvent("OnSessionEnd", {
        masterLooter = sender,
    })
end

function LoothingCommMixin:HandleItemAdd(payload, sender)
    local itemLink = payload[1]
    local guid = payload[2]
    local looter = payload[3]

    self:TriggerEvent("OnItemAdd", {
        itemLink = itemLink,
        guid = guid,
        looter = looter,
        masterLooter = sender,
    })
end

function LoothingCommMixin:HandleItemRemove(payload, sender)
    local guid = payload[1]

    self:TriggerEvent("OnItemRemove", {
        guid = guid,
        masterLooter = sender,
    })
end

function LoothingCommMixin:HandleVoteRequest(payload, sender)
    local itemGUID = payload[1]
    local timeout = tonumber(payload[2])

    self:TriggerEvent("OnVoteRequest", {
        itemGUID = itemGUID,
        timeout = timeout,
        masterLooter = sender,
    })
end

function LoothingCommMixin:HandleVoteCommit(payload, sender)
    local itemGUID = payload[1]
    local responses = {}

    for i = 2, #payload do
        responses[#responses + 1] = tonumber(payload[i])
    end

    self:TriggerEvent("OnVoteCommit", {
        itemGUID = itemGUID,
        responses = responses,
        voter = sender,
    })
end

function LoothingCommMixin:HandleVoteCancel(payload, sender)
    local itemGUID = payload[1]

    self:TriggerEvent("OnVoteCancel", {
        itemGUID = itemGUID,
        masterLooter = sender,
    })
end

function LoothingCommMixin:HandleVoteAward(payload, sender)
    local itemGUID = payload[1]
    local winnerName = payload[2]

    self:TriggerEvent("OnVoteAward", {
        itemGUID = itemGUID,
        winner = winnerName,
        masterLooter = sender,
    })
end

function LoothingCommMixin:HandleVoteSkip(payload, sender)
    local itemGUID = payload[1]

    self:TriggerEvent("OnVoteSkip", {
        itemGUID = itemGUID,
        masterLooter = sender,
    })
end

function LoothingCommMixin:HandleSyncRequest(payload, sender)
    self:TriggerEvent("OnSyncRequest", {
        requester = sender,
        timestamp = tonumber(payload[1]),
    })
end

function LoothingCommMixin:HandleSyncData(payload, sender)
    self:TriggerEvent("OnSyncData", {
        sessionID = payload[1],
        encounterID = tonumber(payload[2]),
        encounterName = payload[3],
        state = tonumber(payload[4]),
        masterLooter = sender,
    })
end

function LoothingCommMixin:HandleCouncilRoster(payload, sender)
    self:TriggerEvent("OnCouncilRoster", {
        members = payload,
        masterLooter = sender,
    })
end

function LoothingCommMixin:HandlePlayerInfoRequest(payload, sender)
    local itemGUID = payload[1]
    local playerName = payload[2]

    self:TriggerEvent("OnPlayerInfoRequest", {
        itemGUID = itemGUID,
        playerName = playerName,
        requester = sender,
    })
end

function LoothingCommMixin:HandlePlayerInfoResponse(payload, sender)
    local itemGUID = payload[1]
    local slot1Link = payload[2]
    local slot2Link = payload[3]
    local slot1ilvl = tonumber(payload[4]) or 0
    local slot2ilvl = tonumber(payload[5]) or 0

    self:TriggerEvent("OnPlayerInfoResponse", {
        itemGUID = itemGUID,
        slot1Link = slot1Link ~= "" and slot1Link or nil,
        slot2Link = slot2Link ~= "" and slot2Link or nil,
        slot1ilvl = slot1ilvl,
        slot2ilvl = slot2ilvl,
        playerName = sender,
    })
end

function LoothingCommMixin:HandleVersionRequest(payload, sender)
    self:TriggerEvent("OnVersionRequest", {
        requester = sender,
    })
end

function LoothingCommMixin:HandleVersionResponse(payload, sender)
    local version = payload[1]

    self:TriggerEvent("OnVersionResponse", {
        version = version,
        sender = sender,
    })
end

--[[--------------------------------------------------------------------
    Broadcast Helpers
----------------------------------------------------------------------]]

--- Broadcast session start
-- @param encounterID number
-- @param encounterName string
function LoothingCommMixin:BroadcastSessionStart(encounterID, encounterName)
    local msg = LoothingProtocol:SessionStart(encounterID, encounterName)
    self:Send(msg)
end

--- Broadcast session end
function LoothingCommMixin:BroadcastSessionEnd()
    local msg = LoothingProtocol:SessionEnd()
    self:Send(msg)
end

--- Broadcast item added
-- @param itemLink string
-- @param guid string
-- @param looter string
function LoothingCommMixin:BroadcastItemAdd(itemLink, guid, looter)
    local msg = LoothingProtocol:ItemAdd(itemLink, guid, looter)
    self:Send(msg)
end

--- Broadcast vote request
-- @param itemGUID string
-- @param timeout number
function LoothingCommMixin:BroadcastVoteRequest(itemGUID, timeout)
    local msg = LoothingProtocol:VoteRequest(itemGUID, timeout)
    self:Send(msg)
end

--- Send vote commit (to ML only)
-- @param itemGUID string
-- @param responses table
-- @param masterLooter string
function LoothingCommMixin:SendVoteCommit(itemGUID, responses, masterLooter)
    local msg = LoothingProtocol:VoteCommit(itemGUID, responses)
    self:Send(msg, masterLooter)
end

--- Broadcast vote award
-- @param itemGUID string
-- @param winnerName string
function LoothingCommMixin:BroadcastVoteAward(itemGUID, winnerName)
    local msg = LoothingProtocol:VoteAward(itemGUID, winnerName)
    self:Send(msg)
end

--- Broadcast vote skip
-- @param itemGUID string
function LoothingCommMixin:BroadcastVoteSkip(itemGUID)
    local msg = LoothingProtocol:VoteSkip(itemGUID)
    self:Send(msg)
end

--- Broadcast council roster
-- @param members table
function LoothingCommMixin:BroadcastCouncilRoster(members)
    local msg = LoothingProtocol:CouncilRoster(members)
    self:Send(msg)
end

--- Request sync from ML
-- @param masterLooter string
function LoothingCommMixin:RequestSync(masterLooter)
    local msg = LoothingProtocol:SyncRequest()
    self:Send(msg, masterLooter)
end

--- Send sync data to requester
-- @param sessionData table
-- @param target string
function LoothingCommMixin:SendSyncData(sessionData, target)
    local msg = LoothingProtocol:SyncData(sessionData)
    self:Send(msg, target)
end

--- Request player info (gear comparison)
-- @param itemGUID string - Item GUID
-- @param playerName string - Player to request from
function LoothingCommMixin:RequestPlayerInfo(itemGUID, playerName)
    local msg = LoothingProtocol:PlayerInfoRequest(itemGUID, playerName)
    self:Send(msg, playerName)
end

--- Send player info response
-- @param itemGUID string - Item GUID
-- @param slot1Link string|nil - First equipped item
-- @param slot2Link string|nil - Second equipped item
-- @param slot1ilvl number - Item level of slot 1
-- @param slot2ilvl number - Item level of slot 2
-- @param target string - ML to send to
function LoothingCommMixin:SendPlayerInfo(itemGUID, slot1Link, slot2Link, slot1ilvl, slot2ilvl, target)
    local msg = LoothingProtocol:PlayerInfoResponse(itemGUID, slot1Link, slot2Link, slot1ilvl, slot2ilvl)
    self:Send(msg, target)
end
