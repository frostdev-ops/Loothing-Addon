local _, ns = ...

--[[--------------------------------------------------------------------
    Loothing - Loot Council Addon for WoW 12.0+
    Protocol - Message serialization via Loolib Serializer+Compressor

    Encoding pipeline:
        Serialize(version, command, data) → Compress → Adler32 → EncodeForAddonChannel

    Decoding pipeline:
        DecodeForAddonChannel → split checksum → Decompress → verify Adler32 → Deserialize

    Adler-32 checksum is computed on the serialized (pre-compression) payload
    and appended as 4 big-endian bytes to the compressed blob before channel
    encoding. Decode strips and verifies it; mismatches return nil.

    Protocol version 3 (breaking from v2 — pre-release, acceptable).
----------------------------------------------------------------------]]
local Loolib = LibStub("Loolib")
local Compressor = Loolib.Compressor
local CreateFromMixins = Loolib.CreateFromMixins
local Serializer = Loolib.Serializer
local Loothing = ns.Addon

ns.ProtocolMixin = ns.ProtocolMixin or {}

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
-- @return string|nil - Encoded message ready for Loolib.Comm
function ProtocolMixin:Encode(command, data)
    -- Step 1: Serialize (version + command + data → string)
    local serialized = self.Serializer:Serialize(self.version, command, data)
    if not serialized then return nil end

    -- Step 2: Compress
    local compressed = self.Compressor:Compress(serialized, 3)
    if not compressed then return nil end

    -- Step 3: Compute Adler-32 checksum on the serialized payload and append
    local checksum      = self.Compressor:Adler32(serialized)
    local withChecksum  = compressed .. Pack32(checksum)

    -- Step 4: Encode for WoW addon channel (escapes null bytes, etc.)
    return self.Compressor:EncodeForAddonChannel(withChecksum)
end

--- Decode a received message
-- Pipeline: DecodeForAddonChannel → split checksum → Decompress → verify → Deserialize
-- @param encoded string - Encoded message from Loolib.Comm callback
-- @return number|nil, string|nil, table|nil - version, command, data (all nil on error)
function ProtocolMixin:Decode(encoded)
    if not encoded or encoded == "" then
        return nil, nil, nil
    end

    -- Step 1: Decode from addon channel encoding
    local withChecksum = self.Compressor:DecodeForAddonChannel(encoded)
    if not withChecksum or #withChecksum < 5 then
        -- Need at least 4 bytes checksum + 1 byte compressed data
        return nil, nil, nil
    end

    -- Step 2: Split off the 4-byte checksum appended at the end
    local storedChecksum = Unpack32(withChecksum, #withChecksum - 3)
    local compressedPart = withChecksum:sub(1, #withChecksum - 4)

    -- Step 3: Decompress
    local decompressed, success = self.Compressor:Decompress(compressedPart)
    if not success or not decompressed then
        return nil, nil, nil
    end

    -- Step 4: Verify Adler-32 integrity (computed on decompressed = serialized)
    local actualChecksum = self.Compressor:Adler32(decompressed)
    if actualChecksum ~= storedChecksum then
        Loothing:Debug("Protocol: Adler-32 mismatch — message may be corrupt",
            string.format("(stored=0x%08X actual=0x%08X)", storedChecksum, actualChecksum))
        return nil, nil, nil
    end

    -- Step 5: Deserialize back to Lua values
    local ok, version, command, msgData = self.Serializer:Deserialize(decompressed)
    if not ok then
        return nil, nil, nil
    end

    return version, command, msgData
end

--[[--------------------------------------------------------------------
    Singleton Instance
----------------------------------------------------------------------]]

ns.Protocol = ns.Protocol or CreateFromMixins(ProtocolMixin)
ns.Protocol:Init()

-- ns.ProtocolMixin and ns.Protocol exported above
