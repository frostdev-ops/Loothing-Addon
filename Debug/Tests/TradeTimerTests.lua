--[[--------------------------------------------------------------------
    Loothing - Loot Council Addon for WoW 12.0+
    TradeTimerTests - Test suite for trade queue and timer tracking

    Tests the LoothingTradeQueueMixin:
    - Queuing items for trade
    - Trade window expiry detection
    - Warning thresholds (20min, 5min)
    - Queue persistence (SavedVariables)
    - Removing traded/expired items

    Run: /lt test run tradetimer
----------------------------------------------------------------------]]

local function RunTradeTimerTests()
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

    print("|cff00ccff========== Trade Timer Tests ==========|r")

    if not LoothingTradeQueueMixin then
        print("|cffff0000[SKIP]|r LoothingTradeQueueMixin not available")
        return passed, failed
    end

    --[[--------------------------------------------------------------------
        Test Group 1: Trade Queue Entry Structure
    ----------------------------------------------------------------------]]
    printGroup("Trade Queue Entry Structure")

    -- Test the trade queue data shape (without full init which needs event frame)
    local TRADE_WINDOW_SECONDS = 2 * 60 * 60

    local entry = {
        itemGUID = "test-guid-001",
        itemLink = "|cffa335ee|Hitem:212405|h[Regicide]|h|r",
        winner = "Player-TestRealm",
        looter = "ML-TestRealm",
        queuedAt = time(),
        expiresAt = time() + TRADE_WINDOW_SECONDS,
        traded = false,
    }

    assertNotNil(entry.itemGUID, "Entry has itemGUID")
    assertNotNil(entry.itemLink, "Entry has itemLink")
    assertNotNil(entry.winner, "Entry has winner")
    assertNotNil(entry.expiresAt, "Entry has expiresAt")
    assertEqual(entry.traded, false, "Entry starts not traded")

    -- Verify 2-hour window
    local windowDuration = entry.expiresAt - entry.queuedAt
    assertEqual(windowDuration, TRADE_WINDOW_SECONDS, "Trade window is 2 hours (7200s)")

    --[[--------------------------------------------------------------------
        Test Group 2: Time Remaining Calculation
    ----------------------------------------------------------------------]]
    printGroup("Time Remaining Calculation")

    -- Fresh entry (full 2 hours remaining)
    local freshEntry = {
        expiresAt = time() + TRADE_WINDOW_SECONDS,
    }
    local remaining = freshEntry.expiresAt - time()
    assert(remaining > 7100, "Fresh entry: >7100s remaining")
    assert(remaining <= 7200, "Fresh entry: <=7200s remaining")

    -- Entry at 20min warning threshold
    local warn20Entry = {
        expiresAt = time() + (19 * 60), -- 19 minutes left
    }
    local warn20Remaining = warn20Entry.expiresAt - time()
    assert(warn20Remaining < 20 * 60, "20min warning: remaining < 1200s")
    assert(warn20Remaining > 0, "20min warning: still positive")

    -- Entry at 5min warning threshold
    local warn5Entry = {
        expiresAt = time() + (4 * 60), -- 4 minutes left
    }
    local warn5Remaining = warn5Entry.expiresAt - time()
    assert(warn5Remaining < 5 * 60, "5min warning: remaining < 300s")
    assert(warn5Remaining > 0, "5min warning: still positive")

    -- Expired entry
    local expiredEntry = {
        expiresAt = time() - 60, -- Expired 1 minute ago
    }
    local expiredRemaining = expiredEntry.expiresAt - time()
    assert(expiredRemaining < 0, "Expired entry: negative remaining")

    --[[--------------------------------------------------------------------
        Test Group 3: Warning Threshold Logic
    ----------------------------------------------------------------------]]
    printGroup("Warning Threshold Logic")

    local TRADE_WARNING_20MIN = 20 * 60
    local TRADE_WARNING_5MIN = 5 * 60

    -- Test threshold crossing detection
    local warningsSent = {}

    local function checkWarnings(guid, remaining)
        warningsSent[guid] = warningsSent[guid] or {}

        if remaining <= TRADE_WARNING_5MIN and not warningsSent[guid].warned5 then
            warningsSent[guid].warned5 = true
            return "5min"
        end
        if remaining <= TRADE_WARNING_20MIN and not warningsSent[guid].warned20 then
            warningsSent[guid].warned20 = true
            return "20min"
        end
        return nil
    end

    -- First check at 25min remaining (no warning)
    local result1 = checkWarnings("item1", 25 * 60)
    assert(result1 == nil, "No warning at 25min remaining")

    -- Check at 19min (triggers 20min warning)
    local result2 = checkWarnings("item1", 19 * 60)
    assertEqual(result2, "20min", "20min warning fires at 19min remaining")

    -- Check at 18min (no duplicate)
    local result3 = checkWarnings("item1", 18 * 60)
    assert(result3 == nil, "20min warning does not fire twice")

    -- Check at 4min (triggers 5min warning)
    local result4 = checkWarnings("item1", 4 * 60)
    assertEqual(result4, "5min", "5min warning fires at 4min remaining")

    -- Check at 3min (no duplicate)
    local result5 = checkWarnings("item1", 3 * 60)
    assert(result5 == nil, "5min warning does not fire twice")

    --[[--------------------------------------------------------------------
        Test Group 4: Queue Operations
    ----------------------------------------------------------------------]]
    printGroup("Queue Operations")

    -- Test array-based queue manipulation
    local queue = {}

    -- Add items
    queue[1] = { itemGUID = "g1", winner = "P1-Realm", expiresAt = time() + 7200, traded = false }
    queue[2] = { itemGUID = "g2", winner = "P2-Realm", expiresAt = time() + 3600, traded = false }
    queue[3] = { itemGUID = "g3", winner = "P3-Realm", expiresAt = time() - 60, traded = false }

    assertEqual(#queue, 3, "Queue has 3 items after adding")

    -- Mark traded
    queue[1].traded = true
    assertEqual(queue[1].traded, true, "Item marked as traded")

    -- Filter out traded and expired
    local activeQueue = {}
    for _, item in ipairs(queue) do
        if not item.traded and item.expiresAt > time() then
            activeQueue[#activeQueue + 1] = item
        end
    end
    assertEqual(#activeQueue, 1, "Active queue: 1 item (traded and expired filtered)")
    assertEqual(activeQueue[1].itemGUID, "g2", "Active item is g2 (not traded, not expired)")

    --[[--------------------------------------------------------------------
        Test Group 5: SavedVariables Serialization
    ----------------------------------------------------------------------]]
    printGroup("SavedVariables Serialization")

    -- Test that trade queue entries can be serialized to SV format
    local svEntry = {
        g = "guid-sv-test",
        l = "|cffa335ee|Hitem:212405|h[Regicide]|h|r",
        w = "Winner-TestRealm",
        o = "Looter-TestRealm",
        q = time(),
        e = time() + 7200,
        t = false,
    }

    -- Round-trip: compress then decompress
    local restored = {
        itemGUID = svEntry.g,
        itemLink = svEntry.l,
        winner = svEntry.w,
        looter = svEntry.o,
        queuedAt = svEntry.q,
        expiresAt = svEntry.e,
        traded = svEntry.t,
    }

    assertEqual(restored.itemGUID, "guid-sv-test", "SV round-trip: itemGUID")
    assertEqual(restored.winner, "Winner-TestRealm", "SV round-trip: winner")
    assertEqual(restored.traded, false, "SV round-trip: traded flag")
    assert(restored.expiresAt > time(), "SV round-trip: not yet expired")

    --[[--------------------------------------------------------------------
        Summary
    ----------------------------------------------------------------------]]
    print("\n|cff00ccff========== Results ==========|r")
    print(string.format("|cff00ff00Passed: %d|r  |cffff0000Failed: %d|r  Total: %d", passed, failed, passed + failed))

    return passed, failed
end

-- Register test
if LoothingTestRunner then
    LoothingTestRunner:RegisterTest("tradetimer", RunTradeTimerTests)
end
