--[[--------------------------------------------------------------------
    Loothing - Loot Council Addon for WoW 12.0+
    Protocol - Message serialization and deserialization
----------------------------------------------------------------------]]

local Loolib = LibStub("Loolib")

--[[--------------------------------------------------------------------
    LoothingProtocolMixin
----------------------------------------------------------------------]]

LoothingProtocolMixin = {}

--- Initialize protocol handler
function LoothingProtocolMixin:Init()
    self.version = LOOTHING_PROTOCOL_VERSION
    self.delimiter = ":"
    self.chunkDelimiter = "|"
end

--[[--------------------------------------------------------------------
    Message Encoding
----------------------------------------------------------------------]]

--- Encode a message for transmission
-- @param msgType string - Message type from LOOTHING_MSG_TYPE
-- @param payload table|string - Message payload
-- @return string - Encoded message
function LoothingProtocolMixin:Encode(msgType, payload)
    local payloadStr = ""

    if type(payload) == "table" then
        payloadStr = self:EncodePayload(payload)
    elseif payload then
        payloadStr = tostring(payload)
    end

    return string.format("%d%s%s%s%s",
        self.version,
        self.delimiter,
        msgType,
        self.delimiter,
        payloadStr)
end

--- Encode a table payload to string
-- @param payload table
-- @return string
function LoothingProtocolMixin:EncodePayload(payload)
    local parts = {}

    for _, value in ipairs(payload) do
        if type(value) == "table" then
            -- Nested table - encode recursively with different delimiter
            parts[#parts + 1] = self:EncodeNestedPayload(value)
        else
            parts[#parts + 1] = self:EscapeValue(tostring(value))
        end
    end

    return table.concat(parts, self.delimiter)
end

--- Encode nested payload
-- @param payload table
-- @return string
function LoothingProtocolMixin:EncodeNestedPayload(payload)
    local parts = {}

    for _, value in ipairs(payload) do
        parts[#parts + 1] = self:EscapeValue(tostring(value))
    end

    return "{" .. table.concat(parts, ",") .. "}"
end

--- Escape special characters in a value
-- @param value string
-- @return string
function LoothingProtocolMixin:EscapeValue(value)
    -- Escape delimiter and special chars
    value = value:gsub("\\", "\\\\")
    value = value:gsub(self.delimiter, "\\" .. self.delimiter)
    value = value:gsub(self.chunkDelimiter, "\\" .. self.chunkDelimiter)
    return value
end

--[[--------------------------------------------------------------------
    Message Decoding
----------------------------------------------------------------------]]

--- Decode a received message
-- @param message string - Raw message
-- @return number, string, table - version, msgType, payload parts
function LoothingProtocolMixin:Decode(message)
    if not message or message == "" then
        return nil, nil, nil
    end

    local parts = self:SplitMessage(message)
    if #parts < 2 then
        return nil, nil, nil
    end

    local version = tonumber(parts[1])
    local msgType = parts[2]
    local payload = {}

    for i = 3, #parts do
        payload[#payload + 1] = self:UnescapeValue(parts[i])
    end

    return version, msgType, payload
end

--- Split message respecting escape sequences
-- @param message string
-- @return table
function LoothingProtocolMixin:SplitMessage(message)
    local parts = {}
    local current = ""
    local escaped = false

    for i = 1, #message do
        local char = message:sub(i, i)

        if escaped then
            current = current .. char
            escaped = false
        elseif char == "\\" then
            escaped = true
        elseif char == self.delimiter then
            parts[#parts + 1] = current
            current = ""
        else
            current = current .. char
        end
    end

    parts[#parts + 1] = current
    return parts
end

--- Unescape special characters in a value
-- @param value string
-- @return string
function LoothingProtocolMixin:UnescapeValue(value)
    value = value:gsub("\\" .. self.chunkDelimiter, self.chunkDelimiter)
    value = value:gsub("\\" .. self.delimiter, self.delimiter)
    value = value:gsub("\\\\", "\\")
    return value
end

--[[--------------------------------------------------------------------
    Message Chunking (for >255 char messages)
----------------------------------------------------------------------]]

--- Check if message needs chunking
-- @param message string
-- @return boolean
function LoothingProtocolMixin:NeedsChunking(message)
    return #message > LOOTHING_TIMING.CHUNK_SIZE
end

--- Split a large message into chunks
-- @param message string
-- @return table - Array of chunk messages
function LoothingProtocolMixin:Chunk(message)
    local chunks = {}
    local chunkSize = LOOTHING_TIMING.CHUNK_SIZE
    local totalChunks = math.ceil(#message / chunkSize)
    local messageID = LoothingUtils.GenerateGUID()

    for i = 1, totalChunks do
        local startPos = (i - 1) * chunkSize + 1
        local endPos = math.min(i * chunkSize, #message)
        local chunk = message:sub(startPos, endPos)

        local chunkMsg = string.format("%d%s%s%s%s%s%d%s%d%s%s",
            self.version,
            self.delimiter,
            LOOTHING_MSG_TYPE.CHUNK,
            self.delimiter,
            messageID,
            self.delimiter,
            i,
            self.delimiter,
            totalChunks,
            self.delimiter,
            chunk)

        chunks[#chunks + 1] = chunkMsg
    end

    return chunks
end

--- Reassemble chunks into original message
-- @param chunks table - Array of { seq, total, data }
-- @return string|nil - Reassembled message or nil if incomplete
function LoothingProtocolMixin:Reassemble(chunks)
    if not chunks or #chunks == 0 then
        return nil
    end

    -- Sort by sequence number
    table.sort(chunks, function(a, b) return a.seq < b.seq end)

    -- Check if we have all chunks
    local total = chunks[1].total
    if #chunks < total then
        return nil
    end

    -- Reassemble
    local parts = {}
    for _, chunk in ipairs(chunks) do
        parts[#parts + 1] = chunk.data
    end

    return table.concat(parts, "")
end

--[[--------------------------------------------------------------------
    Message Type Helpers
----------------------------------------------------------------------]]

--- Create session start message
-- @param encounterID number
-- @param encounterName string
-- @return string
function LoothingProtocolMixin:SessionStart(encounterID, encounterName)
    return self:Encode(LOOTHING_MSG_TYPE.SESSION_START, { encounterID, encounterName })
end

--- Create session end message
-- @return string
function LoothingProtocolMixin:SessionEnd()
    return self:Encode(LOOTHING_MSG_TYPE.SESSION_END, {})
end

--- Create item add message
-- @param itemLink string
-- @param guid string
-- @param looter string
-- @return string
function LoothingProtocolMixin:ItemAdd(itemLink, guid, looter)
    return self:Encode(LOOTHING_MSG_TYPE.ITEM_ADD, { itemLink, guid, looter })
end

--- Create vote request message
-- @param itemGUID string
-- @param timeout number
-- @return string
function LoothingProtocolMixin:VoteRequest(itemGUID, timeout)
    return self:Encode(LOOTHING_MSG_TYPE.VOTE_REQUEST, { itemGUID, timeout })
end

--- Create vote commit message
-- @param itemGUID string
-- @param responses table - Array of response values (ranked)
-- @return string
function LoothingProtocolMixin:VoteCommit(itemGUID, responses)
    local payload = { itemGUID }
    for _, resp in ipairs(responses) do
        payload[#payload + 1] = resp
    end
    return self:Encode(LOOTHING_MSG_TYPE.VOTE_COMMIT, payload)
end

--- Create vote award message
-- @param itemGUID string
-- @param winnerName string
-- @return string
function LoothingProtocolMixin:VoteAward(itemGUID, winnerName)
    return self:Encode(LOOTHING_MSG_TYPE.VOTE_AWARD, { itemGUID, winnerName })
end

--- Create vote skip message
-- @param itemGUID string
-- @return string
function LoothingProtocolMixin:VoteSkip(itemGUID)
    return self:Encode(LOOTHING_MSG_TYPE.VOTE_SKIP, { itemGUID })
end

--- Create sync request message
-- @return string
function LoothingProtocolMixin:SyncRequest()
    return self:Encode(LOOTHING_MSG_TYPE.SYNC_REQUEST, { time() })
end

--- Create sync data message
-- @param sessionData table
-- @return string
function LoothingProtocolMixin:SyncData(sessionData)
    -- Serialize session data
    local payload = {
        sessionData.sessionID or "",
        sessionData.encounterID or 0,
        sessionData.encounterName or "",
        sessionData.state or LOOTHING_SESSION_STATE.INACTIVE,
    }
    return self:Encode(LOOTHING_MSG_TYPE.SYNC_DATA, payload)
end

--- Create council roster message
-- @param members table - Array of member names
-- @return string
function LoothingProtocolMixin:CouncilRoster(members)
    return self:Encode(LOOTHING_MSG_TYPE.COUNCIL_ROSTER, members)
end

--- Create player info request message
-- @param itemGUID string - Item GUID to request info for
-- @param playerName string - Player to request info from
-- @return string
function LoothingProtocolMixin:PlayerInfoRequest(itemGUID, playerName)
    return self:Encode(LOOTHING_MSG_TYPE.PLAYER_INFO_REQUEST, { itemGUID, playerName })
end

--- Create player info response message
-- @param itemGUID string - Item GUID this info is for
-- @param slot1Link string|nil - First equipped item link
-- @param slot2Link string|nil - Second equipped item link (for dual-wield slots)
-- @param slot1ilvl number - Item level of slot 1
-- @param slot2ilvl number - Item level of slot 2
-- @return string
function LoothingProtocolMixin:PlayerInfoResponse(itemGUID, slot1Link, slot2Link, slot1ilvl, slot2ilvl)
    return self:Encode(LOOTHING_MSG_TYPE.PLAYER_INFO_RESPONSE, {
        itemGUID,
        slot1Link or "",
        slot2Link or "",
        slot1ilvl or 0,
        slot2ilvl or 0,
    })
end

--[[--------------------------------------------------------------------
    Singleton Instance
----------------------------------------------------------------------]]

LoothingProtocol = LoolibCreateFromMixins(LoothingProtocolMixin)
LoothingProtocol:Init()
