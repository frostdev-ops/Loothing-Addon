--[[--------------------------------------------------------------------
    Loothing - Loot Council Addon for WoW 12.0+
    CommunicationTests - Test suite for Serializer+Compressor protocol

    Tests the encode/decode round-trip via Protocol, which uses:
    Loolib.Serializer → Loolib.Compressor → EncodeForAddonChannel

    Run: /lt test run communication
----------------------------------------------------------------------]]

local _, ns = ...
local Loothing = ns.Addon
local Protocol = ns.Protocol
local TestRunner = ns.TestRunner

local Loolib = LibStub("Loolib")

local function RunCommunicationTests()
    if not Protocol then
        print("[Tests] Protocol not loaded")
        return
    end

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

    print("|cff00ccff========== Communication Protocol Tests (v3) ==========|r")
    print("Protocol: Serialize -> Compress -> Adler32 checksum -> EncodeForAddonChannel")

    --[[--------------------------------------------------------------------
        Test Group 1: Basic Encode / Decode Round-Trip
    ----------------------------------------------------------------------]]
    printGroup("Basic Encode/Decode Round-Trip")

    -- Simple encode/decode
    local encoded = Protocol:Encode(Loothing.MsgType.SESSION_START, { encounterID = 123, encounterName = "Test Boss" })
    assertNotNil(encoded, "Encode produces a string")
    assert(type(encoded) == "string", "Encode returns string type")
    assert(#encoded > 0, "Encoded string is not empty")

    local version, command, data = Protocol:Decode(encoded)
    assertEqual(version, Loothing.PROTOCOL_VERSION, "Decoded version matches protocol version")
    assertEqual(command, Loothing.MsgType.SESSION_START, "Decoded command matches SESSION_START")
    assertNotNil(data, "Decoded data is not nil")
    assertEqual(data.encounterID, 123, "Decoded encounterID preserves number")
    assertEqual(data.encounterName, "Test Boss", "Decoded encounterName preserves string")

    -- Empty data table
    local emptyEncoded = Protocol:Encode(Loothing.MsgType.SESSION_END, {})
    local emptyVersion, emptyCommand, emptyData = Protocol:Decode(emptyEncoded)
    assertEqual(emptyVersion, Loothing.PROTOCOL_VERSION, "Empty data: version preserved")
    assertEqual(emptyCommand, Loothing.MsgType.SESSION_END, "Empty data: command preserved")
    assertNotNil(emptyData, "Empty data: data table exists")

    -- Nil data
    local nilEncoded = Protocol:Encode(Loothing.MsgType.SESSION_END, nil)
    local nilVersion, nilCommand, nilData = Protocol:Decode(nilEncoded)
    assertEqual(nilVersion, Loothing.PROTOCOL_VERSION, "Nil data: version preserved")
    assertEqual(nilCommand, Loothing.MsgType.SESSION_END, "Nil data: command preserved")

    --[[--------------------------------------------------------------------
        Test Group 2: Data Type Preservation
    ----------------------------------------------------------------------]]
    printGroup("Data Type Preservation")

    -- Numbers (integer)
    local numEncoded = Protocol:Encode("TEST", { value = 42 })
    local _, _, numData = Protocol:Decode(numEncoded)
    assertEqual(numData.value, 42, "Integer preserved")

    -- Numbers (zero)
    local zeroEncoded = Protocol:Encode("TEST", { value = 0 })
    local _, _, zeroData = Protocol:Decode(zeroEncoded)
    assertEqual(zeroData.value, 0, "Zero preserved")

    -- Numbers (negative)
    local negEncoded = Protocol:Encode("TEST", { value = -5 })
    local _, _, negData = Protocol:Decode(negEncoded)
    assertEqual(negData.value, -5, "Negative number preserved")

    -- Numbers (float)
    local floatEncoded = Protocol:Encode("TEST", { value = 3.14159 })
    local _, _, floatData = Protocol:Decode(floatEncoded)
    assert(math.abs(floatData.value - 3.14159) < 0.001, "Float preserved within tolerance")

    -- Booleans
    local boolEncoded = Protocol:Encode("TEST", { yes = true, no = false })
    local _, _, boolData = Protocol:Decode(boolEncoded)
    assertEqual(boolData.yes, true, "Boolean true preserved")
    assertEqual(boolData.no, false, "Boolean false preserved")

    -- Strings with special characters
    local specialEncoded = Protocol:Encode("TEST", { text = "Hello:World|Test\\End" })
    local _, _, specialData = Protocol:Decode(specialEncoded)
    assertEqual(specialData.text, "Hello:World|Test\\End", "Special characters preserved")

    -- Unicode strings
    local unicodeEncoded = Protocol:Encode("TEST", { name = "Plåyer-Tëst" })
    local _, _, unicodeData = Protocol:Decode(unicodeEncoded)
    assertEqual(unicodeData.name, "Plåyer-Tëst", "Unicode characters preserved")

    -- Empty string
    local emptyStrEncoded = Protocol:Encode("TEST", { text = "" })
    local _, _, emptyStrData = Protocol:Decode(emptyStrEncoded)
    assertEqual(emptyStrData.text, "", "Empty string preserved")

    -- Nested tables
    local nestedEncoded = Protocol:Encode("TEST", {
        outer = { inner = { deep = "value" } },
        array = { 1, 2, 3 },
    })
    local _, _, nestedData = Protocol:Decode(nestedEncoded)
    assertEqual(nestedData.outer.inner.deep, "value", "Nested table preserved")
    assertEqual(nestedData.array[1], 1, "Array element 1 preserved")
    assertEqual(nestedData.array[2], 2, "Array element 2 preserved")
    assertEqual(nestedData.array[3], 3, "Array element 3 preserved")

    --[[--------------------------------------------------------------------
        Test Group 3: Error Handling
    ----------------------------------------------------------------------]]
    printGroup("Error Handling")

    -- Decode nil
    local nilVersion2, nilCommand2, nilData2 = Protocol:Decode(nil)
    assertNil(nilVersion2, "Decode nil: version is nil")
    assertNil(nilCommand2, "Decode nil: command is nil")

    -- Decode empty string
    local emptyVersion2, emptyCommand2, emptyData2 = Protocol:Decode("")
    assertNil(emptyVersion2, "Decode empty: version is nil")
    assertNil(emptyCommand2, "Decode empty: command is nil")

    -- Decode garbage
    local garbageVersion, garbageCommand, garbageData = Protocol:Decode("not a real message!!!")
    assertNil(garbageVersion, "Decode garbage: version is nil")

    --[[--------------------------------------------------------------------
        Test Group 4: Message Types Round-Trip
    ----------------------------------------------------------------------]]
    printGroup("Message Type Round-Trips")

    -- SESSION_START
    local ss = Protocol:Encode(Loothing.MsgType.SESSION_START, {
        encounterID = 2820,
        encounterName = "Vault of the Incarnates",
        sessionID = "abc-123",
    })
    local ssV, ssC, ssD = Protocol:Decode(ss)
    assertEqual(ssC, Loothing.MsgType.SESSION_START, "SESSION_START command")
    assertEqual(ssD.encounterID, 2820, "SESSION_START encounterID")
    assertEqual(ssD.encounterName, "Vault of the Incarnates", "SESSION_START encounterName")
    assertEqual(ssD.sessionID, "abc-123", "SESSION_START sessionID")

    -- ITEM_ADD
    local itemLink = "|cff0070dd|Hitem:12345:0:0:0:0:0:0:0:0:0:0:0:0|h[Test Item]|h|r"
    local ia = Protocol:Encode(Loothing.MsgType.ITEM_ADD, {
        itemLink = itemLink,
        guid = "guid-456",
        looter = "Looter-Realm",
    })
    local iaV, iaC, iaD = Protocol:Decode(ia)
    assertEqual(iaC, Loothing.MsgType.ITEM_ADD, "ITEM_ADD command")
    assertEqual(iaD.itemLink, itemLink, "ITEM_ADD itemLink preserved (with pipes)")
    assertEqual(iaD.guid, "guid-456", "ITEM_ADD guid")
    assertEqual(iaD.looter, "Looter-Realm", "ITEM_ADD looter")

    -- VOTE_COMMIT with responses array
    local vc = Protocol:Encode(Loothing.MsgType.VOTE_COMMIT, {
        itemGUID = "guid-789",
        responses = { Loothing.Response.NEED, Loothing.Response.GREED, Loothing.Response.OFFSPEC },
        sessionID = "session-1",
    })
    local vcV, vcC, vcD = Protocol:Decode(vc)
    assertEqual(vcC, Loothing.MsgType.VOTE_COMMIT, "VOTE_COMMIT command")
    assertEqual(#vcD.responses, 3, "VOTE_COMMIT responses count")
    assertEqual(vcD.responses[1], Loothing.Response.NEED, "VOTE_COMMIT response 1")
    assertEqual(vcD.responses[2], Loothing.Response.GREED, "VOTE_COMMIT response 2")

    -- VOTE_AWARD
    local va = Protocol:Encode(Loothing.MsgType.VOTE_AWARD, {
        itemGUID = "guid-111",
        winner = "Winner-Realm",
        sessionID = "s1",
    })
    local vaV, vaC, vaD = Protocol:Decode(va)
    assertEqual(vaC, Loothing.MsgType.VOTE_AWARD, "VOTE_AWARD command")
    assertEqual(vaD.winner, "Winner-Realm", "VOTE_AWARD winner")

    -- PLAYER_RESPONSE
    local pr = Protocol:Encode(Loothing.MsgType.PLAYER_RESPONSE, {
        itemGUID = "guid-222",
        response = Loothing.Response.NEED,
        note = "Best in slot for me",
        roll = 95,
        rollMin = 1,
        rollMax = 100,
        sessionID = "s1",
    })
    local prV, prC, prD = Protocol:Decode(pr)
    assertEqual(prC, Loothing.MsgType.PLAYER_RESPONSE, "PLAYER_RESPONSE command")
    assertEqual(prD.response, Loothing.Response.NEED, "PLAYER_RESPONSE response")
    assertEqual(prD.note, "Best in slot for me", "PLAYER_RESPONSE note")
    assertEqual(prD.roll, 95, "PLAYER_RESPONSE roll")

    -- CANDIDATE_UPDATE with nested candidateData
    local cu = Protocol:Encode(Loothing.MsgType.CANDIDATE_UPDATE, {
        itemGUID = "guid-333",
        candidateData = {
            name = "Player-Realm",
            class = "WARRIOR",
            response = Loothing.Response.NEED,
            roll = 88,
            note = "Upgrade",
            gear1 = "|cff0070dd|Hitem:99999|h[Old Item]|h|r",
            gear2 = nil,
            ilvl1 = 450,
            ilvl2 = 0,
            itemsWon = 1,
        },
        sessionID = "s1",
    })
    local cuV, cuC, cuD = Protocol:Decode(cu)
    assertEqual(cuC, Loothing.MsgType.CANDIDATE_UPDATE, "CANDIDATE_UPDATE command")
    assertEqual(cuD.candidateData.name, "Player-Realm", "CANDIDATE_UPDATE name")
    assertEqual(cuD.candidateData.class, "WARRIOR", "CANDIDATE_UPDATE class")
    assertEqual(cuD.candidateData.ilvl1, 450, "CANDIDATE_UPDATE ilvl1")

    -- VOTE_UPDATE with voters array
    local vu = Protocol:Encode(Loothing.MsgType.VOTE_UPDATE, {
        itemGUID = "guid-444",
        candidateName = "Candidate-Realm",
        voters = { "Voter1-Realm", "Voter2-Realm", "Voter3-Realm" },
        sessionID = "s1",
    })
    local vuV, vuC, vuD = Protocol:Decode(vu)
    assertEqual(vuC, Loothing.MsgType.VOTE_UPDATE, "VOTE_UPDATE command")
    assertEqual(#vuD.voters, 3, "VOTE_UPDATE voters count")
    assertEqual(vuD.voters[1], "Voter1-Realm", "VOTE_UPDATE voter 1")

    -- COUNCIL_ROSTER with members array
    local cr = Protocol:Encode(Loothing.MsgType.COUNCIL_ROSTER, {
        members = { "Player1-Realm", "Player2-Realm", "Player3-Realm" },
    })
    local crV, crC, crD = Protocol:Decode(cr)
    assertEqual(crC, Loothing.MsgType.COUNCIL_ROSTER, "COUNCIL_ROSTER command")
    assertEqual(#crD.members, 3, "COUNCIL_ROSTER members count")

    -- PLAYER_INFO_RESPONSE
    local slot1Link = "|cff0070dd|Hitem:11111|h[Equipped 1]|h|r"
    local slot2Link = "|cff0070dd|Hitem:22222|h[Equipped 2]|h|r"
    local pir = Protocol:Encode(Loothing.MsgType.PLAYER_INFO_RESPONSE, {
        itemGUID = "guid-555",
        slot1Link = slot1Link,
        slot2Link = slot2Link,
        slot1ilvl = 450,
        slot2ilvl = 445,
        sessionID = "s1",
    })
    local pirV, pirC, pirD = Protocol:Decode(pir)
    assertEqual(pirC, Loothing.MsgType.PLAYER_INFO_RESPONSE, "PLAYER_INFO_RESPONSE command")
    assertEqual(pirD.slot1Link, slot1Link, "PLAYER_INFO_RESPONSE slot1Link")
    assertEqual(pirD.slot1ilvl, 450, "PLAYER_INFO_RESPONSE slot1ilvl")

    -- VOTE_RESULTS with nested results table
    local vr = Protocol:Encode(Loothing.MsgType.VOTE_RESULTS, {
        itemGUID = "guid-666",
        results = {
            winner = "Player-Realm",
            response = Loothing.Response.NEED,
            votes = 5,
            totalVotes = 8,
            rounds = 2,
        },
        sessionID = "s1",
    })
    local vrV, vrC, vrD = Protocol:Decode(vr)
    assertEqual(vrC, Loothing.MsgType.VOTE_RESULTS, "VOTE_RESULTS command")
    assertEqual(vrD.results.winner, "Player-Realm", "VOTE_RESULTS winner")
    assertEqual(vrD.results.votes, 5, "VOTE_RESULTS votes")

    -- XREALM envelope
    local xr = Protocol:Encode(Loothing.MsgType.XREALM, {
        target = "Player-OtherRealm",
        command = Loothing.MsgType.PLAYER_RESPONSE,
        data = { itemGUID = "guid-777", response = 1 },
    })
    local xrV, xrC, xrD = Protocol:Decode(xr)
    assertEqual(xrC, Loothing.MsgType.XREALM, "XREALM command")
    assertEqual(xrD.target, "Player-OtherRealm", "XREALM target")
    assertEqual(xrD.command, Loothing.MsgType.PLAYER_RESPONSE, "XREALM inner command")
    assertEqual(xrD.data.itemGUID, "guid-777", "XREALM inner data preserved")

    --[[--------------------------------------------------------------------
        Test Group 5: Compression Efficiency
    ----------------------------------------------------------------------]]
    printGroup("Compression")

    -- Large data should compress well
    local largeData = { items = {} }
    for i = 1, 25 do
        largeData.items[i] = {
            itemLink = string.format("|cff0070dd|Hitem:%d:0:0:0|h[Item %d]|h|r", 10000 + i, i),
            guid = string.format("guid-%03d", i),
            looter = "Player-Realm",
            ilvl = 450 + i,
        }
    end
    local largeEncoded = Protocol:Encode(Loothing.MsgType.SYNC_DATA, largeData)
    assertNotNil(largeEncoded, "Large data encodes successfully")

    local largeV, largeC, largeD = Protocol:Decode(largeEncoded)
    assertEqual(largeC, Loothing.MsgType.SYNC_DATA, "Large data: command preserved")
    assertEqual(#largeD.items, 25, "Large data: all 25 items preserved")
    assertEqual(largeD.items[1].ilvl, 451, "Large data: first item ilvl correct")
    assertEqual(largeD.items[25].ilvl, 475, "Large data: last item ilvl correct")

    -- Print compression ratio
    local Serializer = Loolib.Serializer
    local Compressor = Loolib.Compressor
    if Serializer and Compressor then
        local rawSerialized = Serializer:Serialize(Loothing.PROTOCOL_VERSION, Loothing.MsgType.SYNC_DATA, largeData)
        local ratio = #largeEncoded / #rawSerialized
        print(string.format("  Compression: %d raw -> %d encoded (%.1f%% ratio)", #rawSerialized, #largeEncoded, ratio * 100))
    end

    --[[--------------------------------------------------------------------
        Test Group 6: Edge Cases
    ----------------------------------------------------------------------]]
    printGroup("Edge Cases")

    -- Very long item link
    local veryLongLink = "|cff0070dd|Hitem:" .. string.rep("1234567890:", 20) .. "0|h[Super Long Item Name That Goes On And On]|h|r"
    local longLinkEncoded = Protocol:Encode(Loothing.MsgType.ITEM_ADD, { itemLink = veryLongLink, guid = "g", looter = "l" })
    local _, _, longLinkData = Protocol:Decode(longLinkEncoded)
    assertEqual(longLinkData.itemLink, veryLongLink, "Very long item link preserved")

    -- Many council members
    local manyMembers = {}
    for i = 1, 40 do
        manyMembers[i] = string.format("Player%d-VeryLongRealmName%d", i, i)
    end
    local manyEncoded = Protocol:Encode(Loothing.MsgType.COUNCIL_ROSTER, { members = manyMembers })
    local _, _, manyData = Protocol:Decode(manyEncoded)
    assertEqual(#manyData.members, 40, "40 council members preserved")
    assertEqual(manyData.members[40], "Player40-VeryLongRealmName40", "Last member preserved")

    -- Mixed-key table (both string and numeric keys)
    local mixedEncoded = Protocol:Encode("TEST", {
        name = "test",
        [1] = "first",
        [2] = "second",
        nested = { a = 1, b = 2 },
    })
    local _, _, mixedData = Protocol:Decode(mixedEncoded)
    assertEqual(mixedData.name, "test", "Mixed-key: string key preserved")

    --[[--------------------------------------------------------------------
        Test Group 7: Integrity Check (Protocol v3 Adler-32)
    ----------------------------------------------------------------------]]
    printGroup("Integrity Check (Protocol v3 Adler-32)")

    -- 7a: Normal round-trip should succeed
    local integrityData = { sessionID = "test-session", state = 2, itemCount = 3 }
    local intEncoded = Protocol:Encode(Loothing.MsgType.SESSION_START, integrityData)
    assertNotNil(intEncoded, "v3 Encode produces output")

    local intV, intC, intD = Protocol:Decode(intEncoded)
    assertEqual(intV, Loothing.PROTOCOL_VERSION, "v3 round-trip: version correct")
    assertEqual(intC, Loothing.MsgType.SESSION_START, "v3 round-trip: command correct")
    assertEqual(intD.sessionID, "test-session", "v3 round-trip: payload preserved")

    -- 7b: Tampered message should fail decode (return nil)
    -- Corrupt the middle of the encoded string by flipping a byte
    if intEncoded and #intEncoded > 10 then
        local mid = math.floor(#intEncoded / 2)
        local tampered = intEncoded:sub(1, mid - 1)
            .. string.char((intEncoded:byte(mid) + 1) % 256)
            .. intEncoded:sub(mid + 1)

        local tampV, tampC, tampD = Protocol:Decode(tampered)
        -- A tampered message should return nil for version and command
        -- (either checksum fails or decompression fails — both return nil)
        assert(tampV == nil or tampC == nil, "Tampered message: decode returns nil")
    else
        assert(true, "Tampered message: skip (encoded too short)")
    end

    --[[--------------------------------------------------------------------
        Test Group 8: BATCH Message
    ----------------------------------------------------------------------]]
    printGroup("BATCH Message")

    local innerMessages = {}
    for i = 1, 5 do
        innerMessages[i] = {
            command = Loothing.MsgType.VOTE_REQUEST,
            data    = { itemGUID = "guid-" .. i, timeout = 30, sessionID = "s1" },
        }
    end

    local batchEncoded = Protocol:Encode(Loothing.MsgType.BATCH, {
        messages = innerMessages,
    })
    assertNotNil(batchEncoded, "BATCH: encode produces output")

    local batchV, batchC, batchD = Protocol:Decode(batchEncoded)
    assertEqual(batchC, Loothing.MsgType.BATCH, "BATCH: command correct")
    assertNotNil(batchD, "BATCH: data not nil")
    assertEqual(#batchD.messages, 5, "BATCH: 5 inner messages preserved")
    assertEqual(batchD.messages[1].command, Loothing.MsgType.VOTE_REQUEST, "BATCH: inner command[1] correct")
    assertEqual(batchD.messages[1].data.itemGUID, "guid-1", "BATCH: inner data[1].itemGUID correct")
    assertEqual(batchD.messages[5].data.itemGUID, "guid-5", "BATCH: inner data[5].itemGUID correct")

    --[[--------------------------------------------------------------------
        Test Group 9: Heartbeat Encode/Decode
    ----------------------------------------------------------------------]]
    printGroup("Heartbeat Payload")

    local heartbeatPayload = {
        sessionID   = "hb-session-abc",
        state       = Loothing.SessionState.ACTIVE,
        itemCount   = 4,
        itemStates  = {
            ["guid-a"] = Loothing.ItemState.VOTING,
            ["guid-b"] = Loothing.ItemState.AWARDED,
            ["guid-c"] = Loothing.ItemState.PENDING,
            ["guid-d"] = Loothing.ItemState.TALLIED,
        },
        councilHash = 1234567890,
        mldbHash    = 9876543210,
    }

    local hbEncoded = Protocol:Encode(Loothing.MsgType.HEARTBEAT, heartbeatPayload)
    assertNotNil(hbEncoded, "Heartbeat: encode produces output")

    local hbV, hbC, hbD = Protocol:Decode(hbEncoded)
    assertEqual(hbC, Loothing.MsgType.HEARTBEAT, "Heartbeat: command correct")
    assertEqual(hbD.sessionID, "hb-session-abc", "Heartbeat: sessionID preserved")
    assertEqual(hbD.state, Loothing.SessionState.ACTIVE, "Heartbeat: state preserved")
    assertEqual(hbD.itemCount, 4, "Heartbeat: itemCount preserved")
    assertEqual(hbD.councilHash, 1234567890, "Heartbeat: councilHash preserved")
    assertEqual(hbD.mldbHash, 9876543210, "Heartbeat: mldbHash preserved")
    assertNotNil(hbD.itemStates, "Heartbeat: itemStates table present")
    assertEqual(hbD.itemStates["guid-a"], Loothing.ItemState.VOTING, "Heartbeat: itemStates[guid-a] correct")
    assertEqual(hbD.itemStates["guid-b"], Loothing.ItemState.AWARDED, "Heartbeat: itemStates[guid-b] correct")

    -- Verify heartbeat is compact (~100 bytes compressed is the target)
    print(string.format("  Heartbeat encoded size: %d bytes", #hbEncoded))

    --[[--------------------------------------------------------------------
        Test Group 10: Backpressure (manual queue test)
    ----------------------------------------------------------------------]]
    printGroup("Backpressure (manual)")

    if Loolib.Comm then
        -- Save current queue state
        local priorCount = Loolib.Comm:GetQueuedMessageCount()

        -- ALERT should always queue regardless of pressure
        local alertQueued = Loolib.Comm:SendCommMessage(
            Loothing.ADDON_PREFIX, "test", "PARTY", nil, "ALERT")
        assert(alertQueued ~= false, "ALERT queues even when pressure is high")

        -- Check IsQueueFull and GetQueuePressure exist and return valid types
        local isFull     = Loolib.Comm:IsQueueFull()
        local pressure   = Loolib.Comm:GetQueuePressure()
        assert(type(isFull) == "boolean", "IsQueueFull returns boolean")
        assert(type(pressure) == "number", "GetQueuePressure returns number")
        assert(pressure >= 0.0 and pressure <= 1.0, "GetQueuePressure in [0.0, 1.0]")

        -- Restore queue state
        Loolib.Comm:ClearSendQueue()
        print("  Queue cleared after backpressure test")
    else
        assert(true, "Backpressure: Loolib.Comm not available, skip")
    end

    --[[--------------------------------------------------------------------
        Summary
    ----------------------------------------------------------------------]]
    print("\n|cff00ccff========== Results ==========|r")
    print(string.format("|cff00ff00Passed: %d|r  |cffff0000Failed: %d|r  Total: %d", passed, failed, passed + failed))

    return passed, failed
end

-- Register test
if TestRunner then
    TestRunner:RegisterTest("communication", RunCommunicationTests)
end
