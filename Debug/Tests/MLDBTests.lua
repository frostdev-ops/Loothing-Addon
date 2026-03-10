--[[--------------------------------------------------------------------
    Loothing - Loot Council Addon for WoW 12.0+
    MLDBTests - Test suite for MLDB compression round-trip

    Tests MLDBMixin:
    - CompressForTransmit / DecompressFromTransmit round-trip
    - Key compression maps (COMPRESSION_KEYS ↔ DECOMPRESSION_KEYS)
    - Nested table compression (responses with sub-keys)
    - GatherSettings output structure
    - Edge cases (nil, empty table, unknown keys)

    Run: /lt test run mldb
----------------------------------------------------------------------]]

local _, ns = ...
local Loothing = ns.Addon
local TestRunner = ns.TestRunner

local Loolib = LibStub("Loolib")

local function RunMLDBTests()
    local passed = 0
    local failed = 0

    local function assert(condition, testName)
        if condition then
            print("|cff00ff00[PASS]|r", testName)
            passed = passed + 1
        else
            print("|cffff0000[FAIL]|r", testName)
            failed = failed + 1
        end
    end

    local function assertEqual(actual, expected, testName)
        if actual == expected then
            print("|cff00ff00[PASS]|r", testName)
            passed = passed + 1
        else
            print("|cffff0000[FAIL]|r", testName, string.format("(got '%s', expected '%s')", tostring(actual), tostring(expected)))
            failed = failed + 1
        end
    end

    local function assertNotNil(value, testName)
        if value ~= nil then
            print("|cff00ff00[PASS]|r", testName)
            passed = passed + 1
        else
            print("|cffff0000[FAIL]|r", testName, "(value is nil)")
            failed = failed + 1
        end
    end

    local function assertNil(value, testName)
        if value == nil then
            print("|cff00ff00[PASS]|r", testName)
            passed = passed + 1
        else
            print("|cffff0000[FAIL]|r", testName, "(expected nil, got " .. tostring(value) .. ")")
            failed = failed + 1
        end
    end

    local function printGroup(groupName)
        print("\n|cffFFFF00Test Group: " .. groupName .. "|r")
    end

    print("|cff00ccff========== MLDB Compression Tests ==========|r")

    if not MLDBMixin then
        print("|cffff0000[SKIP]|r MLDBMixin not available")
        return passed, failed
    end

    -- Create a test instance (no Init, just direct method calls)
    local mldb = {}
    for k, v in pairs(MLDBMixin) do
        mldb[k] = v
    end

    --[[--------------------------------------------------------------------
        Test Group 1: Basic Compression Round-Trip
    ----------------------------------------------------------------------]]
    printGroup("Basic Compression Round-Trip")

    local input = {
        selfVote = true,
        multiVote = false,
        anonymousVoting = false,
        hideVotes = true,
        votingTimeout = 45,
        observe = true,
        numButtons = 5,
        mlSeesVotes = false,
        requireNotes = true,
        autoAddRolls = true,
    }

    local compressed = mldb:CompressForTransmit(input)
    assertNotNil(compressed, "Compression produces output")

    -- Verify keys are compressed
    assertNotNil(compressed.sv, "selfVote -> sv")
    assertNil(compressed.selfVote, "selfVote key removed after compression")
    assertEqual(compressed.sv, true, "sv preserves value true")
    assertEqual(compressed.mv, false, "mv preserves value false")
    assertEqual(compressed.hv, true, "hv preserves value true")
    assertEqual(compressed.vt, 45, "vt preserves number 45")
    assertEqual(compressed.ob, true, "ob preserves value true")
    assertEqual(compressed.nb, 5, "nb preserves number 5")

    -- Decompress
    local decompressed = mldb:DecompressFromTransmit(compressed)
    assertNotNil(decompressed, "Decompression produces output")

    -- Verify round-trip
    assertEqual(decompressed.selfVote, true, "Round-trip: selfVote == true")
    assertEqual(decompressed.multiVote, false, "Round-trip: multiVote == false")
    assertEqual(decompressed.anonymousVoting, false, "Round-trip: anonymousVoting == false")
    assertEqual(decompressed.hideVotes, true, "Round-trip: hideVotes == true")
    assertEqual(decompressed.votingTimeout, 45, "Round-trip: votingTimeout == 45")
    assertEqual(decompressed.observe, true, "Round-trip: observe == true")
    assertEqual(decompressed.numButtons, 5, "Round-trip: numButtons == 5")
    assertEqual(decompressed.mlSeesVotes, false, "Round-trip: mlSeesVotes == false")
    assertEqual(decompressed.requireNotes, true, "Round-trip: requireNotes == true")
    assertEqual(decompressed.autoAddRolls, true, "Round-trip: autoAddRolls == true")

    --[[--------------------------------------------------------------------
        Test Group 2: Nested Table Compression
    ----------------------------------------------------------------------]]
    printGroup("Nested Table Compression")

    local nested = {
        selfVote = true,
        responses = {
            [1] = { name = "Need", color = { 0, 1, 0, 1 }, sort = 1, icon = "icon1" },
            [2] = { name = "Greed", color = { 1, 1, 0, 1 }, sort = 2, icon = "icon2" },
        },
    }

    local nestedCompressed = mldb:CompressForTransmit(nested)
    assertNotNil(nestedCompressed, "Nested compression produces output")
    assertNotNil(nestedCompressed.rs, "responses -> rs")
    assertNotNil(nestedCompressed.rs[1], "rs[1] exists")

    -- Nested keys should be compressed too
    assertNotNil(nestedCompressed.rs[1].n, "responses[1].name -> n")
    assertNotNil(nestedCompressed.rs[1].c, "responses[1].color -> c")
    assertNotNil(nestedCompressed.rs[1].s, "responses[1].sort -> s")
    assertNotNil(nestedCompressed.rs[1].i, "responses[1].icon -> i")

    -- Decompress nested
    local nestedDecompressed = mldb:DecompressFromTransmit(nestedCompressed)
    assertNotNil(nestedDecompressed, "Nested decompression produces output")
    assertEqual(nestedDecompressed.selfVote, true, "Nested round-trip: selfVote")
    assertNotNil(nestedDecompressed.responses, "Nested round-trip: responses exists")
    assertEqual(nestedDecompressed.responses[1].name, "Need", "Nested round-trip: responses[1].name")
    assertEqual(nestedDecompressed.responses[1].sort, 1, "Nested round-trip: responses[1].sort")
    assertEqual(nestedDecompressed.responses[2].name, "Greed", "Nested round-trip: responses[2].name")

    -- Verify color array preserved
    local color = nestedDecompressed.responses[1].color
    assertNotNil(color, "Color array exists")
    assertEqual(color[1], 0, "Color[1] == 0")
    assertEqual(color[2], 1, "Color[2] == 1")
    assertEqual(color[3], 0, "Color[3] == 0")
    assertEqual(color[4], 1, "Color[4] == 1")

    --[[--------------------------------------------------------------------
        Test Group 3: Edge Cases
    ----------------------------------------------------------------------]]
    printGroup("Edge Cases")

    -- Nil input
    local nilResult = mldb:CompressForTransmit(nil)
    assertNil(nilResult, "Compress nil returns nil")

    local nilDecomp = mldb:DecompressFromTransmit(nil)
    assertNil(nilDecomp, "Decompress nil returns nil")

    -- Non-table input
    local badDecomp = mldb:DecompressFromTransmit("not a table")
    assertNil(badDecomp, "Decompress non-table returns nil")

    -- Empty table
    local emptyCompressed = mldb:CompressForTransmit({})
    assertNotNil(emptyCompressed, "Compress empty table returns table")

    local emptyDecomp = mldb:DecompressFromTransmit({})
    assertNotNil(emptyDecomp, "Decompress empty table returns table")

    -- Unknown keys (should pass through unchanged)
    local unknownKeys = {
        selfVote = true,
        customKey = "customValue",
        anotherKey = 42,
    }
    local unknownCompressed = mldb:CompressForTransmit(unknownKeys)
    assertNotNil(unknownCompressed.sv, "Known key compressed")
    assertEqual(unknownCompressed.customKey, "customValue", "Unknown key passes through")
    assertEqual(unknownCompressed.anotherKey, 42, "Unknown numeric key passes through")

    --[[--------------------------------------------------------------------
        Test Group 4: Full Protocol Round-Trip (Encode → Decode → Decompress)
    ----------------------------------------------------------------------]]
    printGroup("Full Protocol Round-Trip")

    if Protocol then
        local settings = {
            selfVote = true,
            multiVote = false,
            votingTimeout = 60,
            numButtons = 5,
            responses = {
                [1] = { name = "Need", color = { 0, 1, 0, 1 }, sort = 1 },
                [2] = { name = "Greed", color = { 1, 1, 0, 1 }, sort = 2 },
                [3] = { name = "Pass", color = { 0.5, 0.5, 0.5, 1 }, sort = 3 },
            },
        }

        -- Compress for transmit
        local txData = mldb:CompressForTransmit(settings)
        assertNotNil(txData, "Protocol: compressed data")

        -- Encode via Protocol
        local encoded = Protocol:Encode(Loothing.MsgType.MLDB_BROADCAST, txData)
        assertNotNil(encoded, "Protocol: encoded message")
        assert(type(encoded) == "string", "Protocol: encoded is string")

        -- Decode
        local ver, cmd, rxData = Protocol:Decode(encoded)
        assertEqual(cmd, Loothing.MsgType.MLDB_BROADCAST, "Protocol: command is MLDB_BROADCAST")
        assertNotNil(rxData, "Protocol: decoded data")

        -- Decompress
        local restored = mldb:DecompressFromTransmit(rxData)
        assertNotNil(restored, "Protocol: decompressed data")

        -- Verify full round-trip
        assertEqual(restored.selfVote, true, "Full round-trip: selfVote")
        assertEqual(restored.multiVote, false, "Full round-trip: multiVote")
        assertEqual(restored.votingTimeout, 60, "Full round-trip: votingTimeout")
        assertEqual(restored.numButtons, 5, "Full round-trip: numButtons")
        assertNotNil(restored.responses, "Full round-trip: responses exist")
        assertEqual(restored.responses[1].name, "Need", "Full round-trip: responses[1].name")
        assertEqual(restored.responses[3].name, "Pass", "Full round-trip: responses[3].name")

        -- Compression ratio
        local Serializer = Loolib.Serializer
        if Serializer then
            local raw = Serializer:Serialize(settings)
            local compressedStr = Serializer:Serialize(txData)
            if raw and compressedStr then
                local ratio = #compressedStr / #raw
                print(string.format("  MLDB Key Compression: %d raw -> %d compressed (%.0f%% of original)", #raw, #compressedStr, ratio * 100))
            end
        end
    else
        print("|cffffcc00[SKIP]|r Protocol not available for full round-trip test")
    end

    --[[--------------------------------------------------------------------
        Test Group 5: ReplaceKeys Recursive Depth
    ----------------------------------------------------------------------]]
    printGroup("ReplaceKeys Recursive Depth")

    local deepNested = {
        selfVote = true,
        responses = {
            [1] = {
                name = "Need",
                color = { 0, 1, 0, 1 },
                icon = "Interface\\Icons\\Test",
            },
        },
    }

    local deepCompressed = mldb:CompressForTransmit(deepNested)
    -- Level 1: selfVote -> sv, responses -> rs
    assertNotNil(deepCompressed.sv, "Deep L1: selfVote -> sv")
    assertNotNil(deepCompressed.rs, "Deep L1: responses -> rs")
    -- Level 2: name -> n, color -> c, icon -> i
    assertEqual(deepCompressed.rs[1].n, "Need", "Deep L2: name -> n = Need")
    assertNotNil(deepCompressed.rs[1].c, "Deep L2: color -> c exists")
    assertEqual(deepCompressed.rs[1].i, "Interface\\Icons\\Test", "Deep L2: icon -> i preserved")

    -- Verify full decompression
    local deepDecomp = mldb:DecompressFromTransmit(deepCompressed)
    assertEqual(deepDecomp.selfVote, true, "Deep round-trip: selfVote")
    assertEqual(deepDecomp.responses[1].name, "Need", "Deep round-trip: name")
    assertEqual(deepDecomp.responses[1].icon, "Interface\\Icons\\Test", "Deep round-trip: icon")

    --[[--------------------------------------------------------------------
        Summary
    ----------------------------------------------------------------------]]
    print("\n|cff00ccff========== Results ==========|r")
    print(string.format("|cff00ff00Passed: %d|r  |cffff0000Failed: %d|r  Total: %d", passed, failed, passed + failed))

    return passed, failed
end

-- Register test
if TestRunner then
    TestRunner:RegisterTest("mldb", RunMLDBTests)
end
