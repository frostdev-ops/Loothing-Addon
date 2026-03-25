--[[--------------------------------------------------------------------
    Loothing - Loot Council Addon for WoW 12.0+
    Protocol - Message serialization via Loolib Serializer+Compressor

    Encoding pipeline:
        Serialize(version, command, data, msgID) → Compress → Adler32 → EncodeForAddonChannel

    Decoding pipeline:
        DecodeForAddonChannel → split checksum → Decompress → verify Adler32 → Deserialize

    Adler-32 checksum is computed on the serialized (pre-compression) payload
    and appended as 4 big-endian bytes to the compressed blob before channel
    encoding. Decode strips and verifies it; mismatches return nil.

    Protocol version 4 (breaking from v3 — adds msgID for replay protection).
    Backward compat: v3 senders omit msgID; v4 receivers treat nil msgID as no-dedup.
----------------------------------------------------------------------]]
local _, ns = ...

local Loolib = LibStub("Loolib")
local Compressor = Loolib.Compressor
local CreateFromMixins = Loolib.CreateFromMixins
local Serializer = Loolib.Serializer
local Loothing = ns.Addon

ns.ProtocolMixin = ns.ProtocolMixin or {}

-- Monotonically increasing sequence counter for replay-protection msgIDs.
-- Resets to 0 on each reload (intentional: dedup window is 120s, reloads take longer).
local msgSeq = 0

--[[--------------------------------------------------------------------
    Checksum Helpers
----------------------------------------------------------------------]]

-- Pack a 32-bit unsigned integer into a 4-byte big-endian string
local function Pack32(n)
    n = math.floor(n) % (2 ^ 32)   -- normalize to [0, 2^32)
    local b4 = n % 256;             n = math.floor(n / 256)
    local b3 = n % 256;             n = math.floor(n / 256)
    local b2 = n % 256;             n = math.floor(n / 256)
    local b1 = n % 256
    return string.char(b1, b2, b3, b4)
end

-- Unpack a 4-byte big-endian string (at offset) into a 32-bit unsigned integer
local function Unpack32(s, offset)
    local b1, b2, b3, b4 = s:byte(offset, offset + 3)
    return ((b1 * 256 + b2) * 256 + b3) * 256 + b4
end

--[[--------------------------------------------------------------------
    ProtocolMixin
----------------------------------------------------------------------]]

local ProtocolMixin = ns.ProtocolMixin

--- Initialize protocol handler
function ProtocolMixin:Init()
    self.version = Loothing.PROTOCOL_VERSION

    self.Serializer = Serializer
    self.Compressor = Compressor

    assert(self.Serializer, "Loolib Serializer not available")
    assert(self.Compressor, "Loolib Compressor not available")
end

--[[--------------------------------------------------------------------
    Encoding / Decoding
----------------------------------------------------------------------]]

--- Encode a command + data for transmission
-- Pipeline: Serialize → Compress → append Adler32 checksum → EncodeForAddonChannel
-- @param command string - Message type from Loothing.MsgType
-- @param data table|nil - Message payload (structured table)
-- @return string|nil, number|nil - Encoded message ready for Loolib.Comm, msgID
function ProtocolMixin:Encode(command, data)
    -- Assign a monotonic message ID for replay protection (Protocol v4+)
    msgSeq = msgSeq + 1
    local currentMsgID = msgSeq

    -- Step 1: Serialize (version + command + data + msgID → string)
    local ok, serialized = pcall(self.Serializer.Serialize, self.Serializer,
        self.version, command, data, currentMsgID)
    if not ok then
        Loothing:Error("Protocol:Encode — Serialize failed for", command, ":", serialized)
        return nil, nil
    end
    if not serialized then
        Loothing:Error("Protocol:Encode — Serialize returned nil for", command)
        return nil, nil
    end

    -- Step 2: Compress
    local cOk, compressed = pcall(self.Compressor.Compress, self.Compressor, serialized, 3)
    if not cOk then
        Loothing:Error("Protocol:Encode — Compress failed for", command, ":", compressed)
        return nil, nil
    end
    if not compressed then
        Loothing:Error("Protocol:Encode — Compress returned nil for", command)
        return nil, nil
    end

    -- Step 3: Compute Adler-32 checksum on the serialized payload and append
    local checksum      = self.Compressor:Adler32(serialized)
    local withChecksum  = compressed .. Pack32(checksum)

    -- Step 4: Encode for WoW addon channel (escapes null bytes, etc.)
    local eOk, encoded = pcall(self.Compressor.EncodeForAddonChannel, self.Compressor, withChecksum)
    if not eOk then
        Loothing:Error("Protocol:Encode — EncodeForAddonChannel failed for", command, ":", encoded)
        return nil, nil
    end
    if not encoded then
        Loothing:Error("Protocol:Encode — EncodeForAddonChannel returned nil for", command)
        return nil, nil
    end

    return encoded, currentMsgID
end

--- Decode a received message
-- Pipeline: DecodeForAddonChannel → split checksum → Decompress → verify → Deserialize
-- @param encoded string - Encoded message from Loolib.Comm callback
-- @return number|nil, string|nil, table|nil, number|nil - version, command, data, msgID
--   msgID is nil when sender uses protocol v3 (no replay protection for legacy peers)
function ProtocolMixin:Decode(encoded)
    if not encoded or encoded == "" then
        return nil, nil, nil, nil
    end

    -- Step 1: Decode from addon channel encoding
    local withChecksum = self.Compressor:DecodeForAddonChannel(encoded)
    if not withChecksum or #withChecksum < 5 then
        -- Need at least 4 bytes checksum + 1 byte compressed data
        return nil, nil, nil, nil
    end

    -- Step 2: Split off the 4-byte checksum appended at the end
    local storedChecksum = Unpack32(withChecksum, #withChecksum - 3)
    local compressedPart = withChecksum:sub(1, #withChecksum - 4)

    -- Step 3: Decompress
    local decompressed, success = self.Compressor:Decompress(compressedPart)
    if not success or not decompressed then
        return nil, nil, nil, nil
    end

    -- Step 4: Verify Adler-32 integrity (computed on decompressed = serialized)
    local actualChecksum = self.Compressor:Adler32(decompressed)
    if actualChecksum ~= storedChecksum then
        Loothing:Debug("Protocol: Adler-32 mismatch — message may be corrupt",
            string.format("(stored=0x%08X actual=0x%08X)", storedChecksum, actualChecksum))
        return nil, nil, nil, nil
    end

    -- Step 5: Deserialize back to Lua values
    -- 4th return (msgID) is nil for v3 senders that don't include it
    local ok, version, command, msgData, msgID = self.Serializer:Deserialize(decompressed)
    if not ok then
        return nil, nil, nil, nil
    end

    return version, command, msgData, msgID
end

--[[--------------------------------------------------------------------
    Singleton Instance
----------------------------------------------------------------------]]

ns.Protocol = ns.Protocol or CreateFromMixins(ProtocolMixin)
ns.Protocol:Init()

-- ns.ProtocolMixin and ns.Protocol exported above
