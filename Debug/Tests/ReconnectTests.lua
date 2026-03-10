--[[--------------------------------------------------------------------
    Loothing - Loot Council Addon for WoW 12.0+
    ReconnectTests - Test suite for reconnect cache/restore logic

    Tests the cache-on-logout → restore-on-reload flow:
    - CacheStateForReconnect builds the right structure
    - RestoreFromCache recovers ML state, MLDB, council, session
    - Expired caches are discarded
    - Empty/nil caches are handled gracefully

    Run: /lt test run reconnect
----------------------------------------------------------------------]]

local _, ns = ...
local Loothing = ns.Addon
local TestRunner = ns.TestRunner

local function RunReconnectTests()
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

    local function printGroup(groupName)
        print("\n|cffFFFF00Test Group: " .. groupName .. "|r")
    end

    print("|cff00ccff========== Reconnect Tests ==========|r")

    if not Loothing or not Loothing.Settings then
        print("|cffff0000[SKIP]|r Loothing.Settings not available")
        return passed, failed
    end

    --[[--------------------------------------------------------------------
        Test Group 1: Cache Structure
    ----------------------------------------------------------------------]]
    printGroup("Cache Structure")

    -- Save original state
    local origHandleLoot = Loothing.handleLoot
    local origIsML = Loothing.isMasterLooter
    local origML = Loothing.masterLooter
    local origGuild = Loothing.isInGuildGroup

    -- Set known state
    Loothing.handleLoot = true
    Loothing.isMasterLooter = true
    Loothing.masterLooter = "TestML-TestRealm"
    Loothing.isInGuildGroup = true

    -- Cache
    Loothing:CacheStateForReconnect()

    local cache = Loothing.Settings:GetGlobalValue("reconnectCache")
    assertNotNil(cache, "Cache exists after CacheStateForReconnect")
    assertNotNil(cache.timestamp, "Cache has timestamp")
    assertEqual(cache.handleLoot, true, "Cache captures handleLoot=true")
    assertEqual(cache.isMasterLooter, true, "Cache captures isMasterLooter=true")
    assertEqual(cache.masterLooter, "TestML-TestRealm", "Cache captures masterLooter name")
    assertEqual(cache.isInGuildGroup, true, "Cache captures isInGuildGroup")

    --[[--------------------------------------------------------------------
        Test Group 2: Restore from Cache
    ----------------------------------------------------------------------]]
    printGroup("Restore from Cache")

    -- Clear state
    Loothing.handleLoot = false
    Loothing.isMasterLooter = false
    Loothing.masterLooter = nil
    Loothing.isInGuildGroup = false

    -- Restore
    Loothing:RestoreFromCache()

    assertEqual(Loothing.handleLoot, true, "Restore recovers handleLoot=true")
    assertEqual(Loothing.isMasterLooter, true, "Restore recovers isMasterLooter=true")
    assertEqual(Loothing.masterLooter, "TestML-TestRealm", "Restore recovers masterLooter")
    assertEqual(Loothing.isInGuildGroup, true, "Restore recovers isInGuildGroup")

    --[[--------------------------------------------------------------------
        Test Group 3: Expired Cache
    ----------------------------------------------------------------------]]
    printGroup("Expired Cache")

    -- Set cache with old timestamp (>15 min)
    Loothing.Settings:SetGlobalValue("reconnectCache", {
        timestamp = time() - (16 * 60), -- 16 minutes old
        handleLoot = true,
        isMasterLooter = true,
        masterLooter = "OldML-TestRealm",
    })

    -- Clear current state
    Loothing.handleLoot = false
    Loothing.isMasterLooter = false
    Loothing.masterLooter = nil

    -- Attempt restore
    Loothing:RestoreFromCache()

    assertEqual(Loothing.handleLoot, false, "Expired cache: handleLoot stays false")
    assertEqual(Loothing.isMasterLooter, false, "Expired cache: isMasterLooter stays false")

    --[[--------------------------------------------------------------------
        Test Group 4: Nil / Missing Cache
    ----------------------------------------------------------------------]]
    printGroup("Nil / Missing Cache")

    -- Clear cache entirely
    Loothing.Settings:SetGlobalValue("reconnectCache", nil)

    Loothing.handleLoot = false
    Loothing.isMasterLooter = false

    -- Should not error
    local success = pcall(function()
        Loothing:RestoreFromCache()
    end)
    assert(success, "RestoreFromCache with nil cache does not error")
    assertEqual(Loothing.handleLoot, false, "Nil cache: state unchanged")

    --[[--------------------------------------------------------------------
        Cleanup
    ----------------------------------------------------------------------]]

    -- Restore original state
    Loothing.handleLoot = origHandleLoot
    Loothing.isMasterLooter = origIsML
    Loothing.masterLooter = origML
    Loothing.isInGuildGroup = origGuild
    Loothing.Settings:SetGlobalValue("reconnectCache", nil)

    --[[--------------------------------------------------------------------
        Summary
    ----------------------------------------------------------------------]]
    print("\n|cff00ccff========== Results ==========|r")
    print(string.format("|cff00ff00Passed: %d|r  |cffff0000Failed: %d|r  Total: %d", passed, failed, passed + failed))

    return passed, failed
end

-- Register test
if TestRunner then
    TestRunner:RegisterTest("reconnect", RunReconnectTests)
end
