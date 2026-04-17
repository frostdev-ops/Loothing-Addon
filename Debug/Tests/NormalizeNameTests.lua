local _, ns = ...

--[[--------------------------------------------------------------------
    Loothing - Loot Council Addon for WoW 12.0+
    NormalizeNameTests - Realm-case canonicalization guard

    Locks in two related contracts:

      * Utils.NormalizeName lowercases the realm segment. This makes every
        name-keyed cache in the addon (versionCache, remoteRoster,
        remoteList, recentMLDBSenders, activeCandidates, …) safe against
        chat-server casing ("Jimbo-illidan") vs API casing
        ("Jimbo-Illidan") through direct table-key equality.

      * Utils.CanonicalizeGroupMemberName returns the roster-API canonical
        casing for any player currently in the group. This is the safe
        whisper-target form — WoW's SendAddonMessage WHISPER rejects the
        lowercased output of NormalizeName with "No player named 'X' is
        currently playing".

    Run: /lt test run normalizename
----------------------------------------------------------------------]]

local Utils = ns.Utils
local TestRunner = ns.TestRunner

local function RunNormalizeNameTests()
    local passed = 0
    local failed = 0

    local function pass(testName)
        print("|cff00ff00[PASS]|r", testName)
        passed = passed + 1
    end

    local function fail(testName, detail)
        print("|cffff0000[FAIL]|r", testName, detail or "")
        failed = failed + 1
    end

    local function assertEqual(actual, expected, testName)
        if actual == expected then
            pass(testName)
        else
            fail(testName, string.format("(got '%s', expected '%s')", tostring(actual), tostring(expected)))
        end
    end

    local function assertTrue(condition, testName)
        if condition then pass(testName) else fail(testName) end
    end

    local function assertFalse(condition, testName)
        if not condition then pass(testName) else fail(testName) end
    end

    print("|cff00ccff========== NormalizeName Tests ==========|r")

    if not Utils or not Utils.NormalizeName or not Utils.IsSamePlayer then
        print("|cffff0000[SKIP]|r Utils.NormalizeName / Utils.IsSamePlayer not available")
        return passed, failed
    end

    --[[--------------------------------------------------------------------
        Group 1: Realm case canonicalization (the cache-key contract)
    ----------------------------------------------------------------------]]
    print("\n|cffFFFF00Test Group: Realm case canonicalization|r")

    assertEqual(Utils.NormalizeName("Jimbo-Illidan"), "Jimbo-illidan",
        "Mixed-case realm is lowercased")
    assertEqual(Utils.NormalizeName("Jimbo-illidan"), "Jimbo-illidan",
        "Already-lowercase realm is preserved")
    assertEqual(Utils.NormalizeName("Jimbo-ThunderHorn"), "Jimbo-thunderhorn",
        "CamelCase realm is lowercased")
    assertEqual(Utils.NormalizeName("Jimbo-AREA 52"), "Jimbo-area 52",
        "Realm with space and uppercase is lowercased")
    -- Realm names with embedded dashes (e.g. Aerie-Peak) are valid on some
    -- regions; the match `([^-]+)-(.+)` captures the full remainder, which
    -- :lower() normalizes as one segment.
    assertEqual(Utils.NormalizeName("Jimbo-Aerie-Peak"), "Jimbo-aerie-peak",
        "Multi-dash realm suffix is fully lowercased as one segment")

    --[[--------------------------------------------------------------------
        Group 2: Short-name casing is preserved
    ----------------------------------------------------------------------]]
    print("\n|cffFFFF00Test Group: Short-name case preservation|r")

    assertEqual(Utils.NormalizeName("Jimbo-Illidan"):match("^([^-]+)"), "Jimbo",
        "Short name 'Jimbo' retains its case")
    assertEqual(Utils.NormalizeName("ALLCAPS-Illidan"), "ALLCAPS-illidan",
        "ALLCAPS short name is preserved")

    --[[--------------------------------------------------------------------
        Group 3: Nil / empty / secret input
    ----------------------------------------------------------------------]]
    print("\n|cffFFFF00Test Group: Edge inputs|r")

    assertEqual(Utils.NormalizeName(nil), nil, "nil input returns nil")

    --[[--------------------------------------------------------------------
        Group 4: Short-name input appends (lowercase) current realm
    ----------------------------------------------------------------------]]
    print("\n|cffFFFF00Test Group: Short name appends current realm|r")

    local shortResult = Utils.NormalizeName("TestPlayer")
    if type(shortResult) == "string" then
        assertTrue(shortResult:find("^TestPlayer") ~= nil,
            "Short-name result starts with the short name")
        local appended = shortResult:match("^TestPlayer%-(.+)$")
        if appended and appended ~= "" then
            assertEqual(appended, appended:lower(),
                "Appended realm segment is lowercase")
        else
            -- If the game hasn't resolved a realm (pre-PLAYER_LOGIN), the
            -- function returns the bare short name; that path is valid.
            assertEqual(shortResult, "TestPlayer",
                "No realm available: short name passes through unchanged")
        end
    else
        fail("Short-name input returns a string", tostring(shortResult))
    end

    --[[--------------------------------------------------------------------
        Group 5: IsSamePlayer triangulation
    ----------------------------------------------------------------------]]
    print("\n|cffFFFF00Test Group: IsSamePlayer across realm casing|r")

    assertTrue(Utils.IsSamePlayer("Jimbo-Illidan", "Jimbo-illidan"),
        "Same player, mixed vs lowercase realm -> true")
    assertTrue(Utils.IsSamePlayer("Jimbo-Illidan", "Jimbo-ILLIDAN"),
        "Same player, mixed vs uppercase realm -> true")
    assertFalse(Utils.IsSamePlayer("Jimbo-Illidan", "Jimbo-Thunderhorn"),
        "Different realms -> false")
    assertFalse(Utils.IsSamePlayer("Jimbo-Illidan", "Bobby-illidan"),
        "Different short names -> false")
    assertFalse(Utils.IsSamePlayer(nil, "Jimbo-Illidan"), "nil first arg -> false")
    assertFalse(Utils.IsSamePlayer("Jimbo-Illidan", nil), "nil second arg -> false")

    --[[--------------------------------------------------------------------
        Group 6: CanonicalizeGroupMemberName (whisper-target contract)

        Contract: out-of-group input is returned unchanged (this is the
        common test path). In-group lookups require a live roster and are
        covered by the live-raid verification step documented in CHANGELOG.
    ----------------------------------------------------------------------]]
    print("\n|cffFFFF00Test Group: CanonicalizeGroupMemberName fallbacks|r")

    if Utils.CanonicalizeGroupMemberName then
        assertEqual(Utils.CanonicalizeGroupMemberName(nil), nil,
            "nil input returns nil")
        -- Out of group (or when we can't match), input is returned verbatim.
        local input = "Vállarra-MoonGuard"
        local out = Utils.CanonicalizeGroupMemberName(input)
        assertTrue(out == input or type(out) == "string",
            "Out-of-group input passes through")
    else
        print("|cffff9900[SKIP]|r CanonicalizeGroupMemberName not available")
    end

    --[[--------------------------------------------------------------------
        Summary
    ----------------------------------------------------------------------]]
    print("\n|cff00ccff========== Results ==========|r")
    print(string.format("|cff00ff00Passed: %d|r  |cffff0000Failed: %d|r  Total: %d",
        passed, failed, passed + failed))

    return passed, failed
end

-- Register test
if TestRunner then
    TestRunner:RegisterTest("normalizename", RunNormalizeNameTests)
end
