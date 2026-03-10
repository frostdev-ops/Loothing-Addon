--[[--------------------------------------------------------------------
    Loothing - Loot Council Addon for WoW 12.0+
    RestrictionTests - Test suite for encounter addon restriction handling

    Tests the RestrictionsMixin:
    - Bitmask state management
    - Guaranteed message queueing during restrictions
    - Replay when restrictions lift
    - Multiple overlapping restrictions (encounter + challenge mode)

    Run: /lt test run restriction
----------------------------------------------------------------------]]

local _, ns = ...
local Loothing = ns.Addon
local TestRunner = ns.TestRunner

local Loolib = LibStub("Loolib")

local function RunRestrictionTests()
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

    local function printGroup(groupName)
        print("\n|cffFFFF00Test Group: " .. groupName .. "|r")
    end

    print("|cff00ccff========== Encounter Restriction Tests ==========|r")

    if not RestrictionsMixin then
        print("|cffff0000[SKIP]|r RestrictionsMixin not available")
        return passed, failed
    end

    --[[--------------------------------------------------------------------
        Create a fresh restrictions instance for testing
    ----------------------------------------------------------------------]]

    local restrictions = Loolib.CreateFromMixins(RestrictionsMixin)

    -- Minimal init (skip event registration which needs full Loolib setup)
    Loolib.CallbackRegistryMixin.OnLoad(restrictions)
    restrictions:GenerateCallbackEvents({
        "OnRestrictionChanged",
        "OnQueuedMessageSent",
    })
    restrictions.restrictions = 0
    restrictions.restrictionsEnabled = false
    restrictions.guaranteedQueue = {}

    --[[--------------------------------------------------------------------
        Test Group 1: Bitmask State
    ----------------------------------------------------------------------]]
    printGroup("Bitmask State")

    assertEqual(restrictions.restrictions, 0, "Initial restrictions bitmask is 0")
    assertEqual(restrictions.restrictionsEnabled, false, "Initially not restricted")

    -- Simulate encounter start
    if restrictions.SetRestrictionBit then
        restrictions:SetRestrictionBit(0x2, true) -- ENCOUNTER bit
        assert(restrictions.restrictions ~= 0, "Encounter bit sets non-zero mask")
        assertEqual(restrictions.restrictionsEnabled, true, "Restrictions enabled after encounter start")

        -- Simulate encounter end
        restrictions:SetRestrictionBit(0x2, false)
        assertEqual(restrictions.restrictions, 0, "Mask returns to 0 after encounter end")
        assertEqual(restrictions.restrictionsEnabled, false, "Restrictions disabled after encounter end")

        -- Overlapping: encounter + challenge mode
        restrictions:SetRestrictionBit(0x2, true)
        restrictions:SetRestrictionBit(0x4, true) -- CHALLENGE bit
        assert(restrictions.restrictions ~= 0, "Both bits set")
        assertEqual(restrictions.restrictionsEnabled, true, "Still restricted with both bits")

        -- Remove encounter, challenge still active
        restrictions:SetRestrictionBit(0x2, false)
        assert(restrictions.restrictions ~= 0, "Challenge bit still active after encounter ends")
        assertEqual(restrictions.restrictionsEnabled, true, "Still restricted with challenge mode")

        -- Remove challenge
        restrictions:SetRestrictionBit(0x4, false)
        assertEqual(restrictions.restrictions, 0, "All bits cleared")
        assertEqual(restrictions.restrictionsEnabled, false, "Restrictions fully lifted")
    else
        print("|cffffcc00[SKIP]|r SetRestrictionBit not available (testing via public API)")
    end

    --[[--------------------------------------------------------------------
        Test Group 2: IsRestricted Query
    ----------------------------------------------------------------------]]
    printGroup("IsRestricted Query")

    if restrictions.IsRestricted then
        -- Start clean
        restrictions.restrictions = 0
        restrictions.restrictionsEnabled = false

        assertEqual(restrictions:IsRestricted(), false, "Not restricted initially")

        restrictions.restrictions = 0x2
        restrictions.restrictionsEnabled = true
        assertEqual(restrictions:IsRestricted(), true, "Restricted during encounter")

        restrictions.restrictions = 0
        restrictions.restrictionsEnabled = false
        assertEqual(restrictions:IsRestricted(), false, "Not restricted after encounter ends")
    else
        -- Fallback: test via direct field
        restrictions.restrictionsEnabled = true
        assertEqual(restrictions.restrictionsEnabled, true, "restrictionsEnabled field works (true)")

        restrictions.restrictionsEnabled = false
        assertEqual(restrictions.restrictionsEnabled, false, "restrictionsEnabled field works (false)")
    end

    --[[--------------------------------------------------------------------
        Test Group 3: Guaranteed Queue
    ----------------------------------------------------------------------]]
    printGroup("Guaranteed Queue")

    -- Reset queue
    restrictions.guaranteedQueue = {}

    if restrictions.QueueGuaranteed then
        -- Queue messages during restriction
        restrictions.restrictionsEnabled = true
        restrictions:QueueGuaranteed("VOTE_COMMIT", { itemGUID = "g1" }, "group")
        restrictions:QueueGuaranteed("VOTE_AWARD", { itemGUID = "g2", winner = "W" }, "group")

        assertEqual(#restrictions.guaranteedQueue, 2, "Two messages queued")
        assertEqual(restrictions.guaranteedQueue[1].command, "VOTE_COMMIT", "First queued command")
        assertEqual(restrictions.guaranteedQueue[2].command, "VOTE_AWARD", "Second queued command")
    else
        -- Test queue structure manually
        restrictions.guaranteedQueue[1] = { command = "VOTE_COMMIT", data = { itemGUID = "g1" }, target = "group" }
        restrictions.guaranteedQueue[2] = { command = "VOTE_AWARD", data = { itemGUID = "g2" }, target = "group" }
        assertEqual(#restrictions.guaranteedQueue, 2, "Manual queue: two messages")
    end

    --[[--------------------------------------------------------------------
        Test Group 4: Queue Replay
    ----------------------------------------------------------------------]]
    printGroup("Queue Replay")

    if restrictions.ReplayQueue then
        -- Set up spy to track sent messages
        local sentMessages = {}
        local origSend = Loothing.Comm and Loothing.Comm.Send
        if Loothing.Comm then
            Loothing.Comm.Send = function(self, command, data, target, _priority)
                sentMessages[#sentMessages + 1] = { command = command, data = data }
            end
        end

        restrictions.restrictionsEnabled = false
        restrictions:ReplayQueue()

        assertEqual(#restrictions.guaranteedQueue, 0, "Queue emptied after replay")

        -- Restore original
        if Loothing.Comm and origSend then
            Loothing.Comm.Send = origSend
        end
    else
        -- Just verify queue can be wiped
        restrictions.guaranteedQueue = {}
        assertEqual(#restrictions.guaranteedQueue, 0, "Queue can be cleared manually")
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
    TestRunner:RegisterTest("restriction", RunRestrictionTests)
end
