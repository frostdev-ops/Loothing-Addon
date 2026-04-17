local _, ns = ...

--[[--------------------------------------------------------------------
    Loothing - Loot Council Addon for WoW 12.0+
    HistoryRevokeTests - HistoryMixin:RemoveByItemGUID contract tests

    Locks in the 2.0.18 RevoteItem cleanup contract: a history entry
    carries an awardedItemGuid back-reference to the session item, and
    RemoveByItemGUID deletes every entry for a given item GUID so a
    subsequent re-award doesn't leave an orphan row.

    Run: /lt test run historyrevoke
----------------------------------------------------------------------]]

local Loolib = LibStub("Loolib")
local TestRunner = ns.TestRunner

local function RunHistoryRevokeTests()
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

    print("|cff00ccff========== HistoryRevoke Tests ==========|r")

    if not ns.HistoryMixin then
        print("|cffff0000[SKIP]|r ns.HistoryMixin not available")
        return passed, failed
    end

    -- Build an isolated HistoryMixin instance so the live SavedVariables
    -- history is untouched. Stub every side-effect method AddEntry and
    -- RemoveEntry could reach — both the single-entry and bulk-mode paths —
    -- so no fake entry ever touches SavedVariables.
    local history = Loolib.CreateFromMixins(ns.HistoryMixin)
    history.SaveEntry          = function() end
    history.SaveEntries        = function() end   -- bulk-add path
    history.RemoveSavedEntry   = function() end
    history.RemoveSavedEntries = function() end   -- bulk-remove path
    history.PruneSavedHistory  = function() end
    history.ApplyFilter        = function() end
    history.LoadFromSaved      = function() end
    history:Init()

    -- Seed directly via the non-bulk AddEntry path (all writes stubbed above).
    -- Previous versions of this test used BeginBulkUpdate/EndBulkUpdate, but
    -- EndBulkUpdate reaches SaveEntries/RemoveSavedEntries which — if not
    -- stubbed — write into the user's real SavedVariables.
    history:AddEntry({ guid = "H1", awardedItemGuid = "item-1", winner = "Alice", itemLink = "itemA", timestamp = 1 })
    history:AddEntry({ guid = "H2", awardedItemGuid = "item-2", winner = "Bob",   itemLink = "itemB", timestamp = 2 })
    -- AddEntry now evicts prior rows with the same awardedItemGuid (receiver-
    -- side idempotency). Seed H3 with a DIFFERENT awardedItemGuid so we have
    -- a third unique row, then mutate its awardedItemGuid to "item-1" after
    -- insert to simulate a stale council-side row from before the idempotency
    -- fix existed.
    history:AddEntry({ guid = "H3", awardedItemGuid = "item-3-seed", winner = "Carol", itemLink = "itemA", timestamp = 3 })
    local h3 = history:GetEntryByGUID("H3")
    if h3 then h3.awardedItemGuid = "item-1" end
    history:AddEntry({ guid = "H4", awardedItemGuid = nil,      winner = "Dave",  itemLink = "itemZ", timestamp = 4 })

    assertEqual(history:GetCount(), 4, "Setup: 4 entries seeded")

    --[[--------------------------------------------------------------------
        Test 1: Remove by item GUID clears all matching entries
    ----------------------------------------------------------------------]]
    print("\n|cffFFFF00Test Group: RemoveByItemGUID|r")

    local removed = history:RemoveByItemGUID("item-1")
    assertEqual(removed, 2, "RemoveByItemGUID('item-1') returns 2 (H1 + H3)")
    assertEqual(history:GetCount(), 2, "History now has 2 entries (H2 + H4)")
    assertEqual(history:GetEntryByGUID("H1"), nil, "H1 is gone")
    assertEqual(history:GetEntryByGUID("H3"), nil, "H3 is gone")

    --[[--------------------------------------------------------------------
        Test 2: Survivors have the expected item GUIDs
    ----------------------------------------------------------------------]]
    local h2 = history:GetEntryByGUID("H2")
    if h2 then
        assertEqual(h2.awardedItemGuid, "item-2", "H2 survives with awardedItemGuid='item-2'")
    else
        fail("H2 survives", "(H2 was removed unexpectedly)")
    end

    local h4 = history:GetEntryByGUID("H4")
    if h4 then
        assertEqual(h4.awardedItemGuid, nil, "H4 survives; its awardedItemGuid is still nil (pre-2.0.18 shape)")
    else
        fail("H4 survives", "(H4 was removed unexpectedly)")
    end

    --[[--------------------------------------------------------------------
        Test 3: Nil / empty / unmatched inputs are safe no-ops
    ----------------------------------------------------------------------]]
    print("\n|cffFFFF00Test Group: Safety rails|r")

    assertEqual(history:RemoveByItemGUID(nil), 0, "Nil itemGuid returns 0 and removes nothing")
    assertEqual(history:GetCount(), 2, "Count unchanged after nil input")

    assertEqual(history:RemoveByItemGUID("no-such-item"), 0,
        "Unknown itemGuid returns 0")
    assertEqual(history:GetCount(), 2, "Count unchanged after unmatched GUID")

    --[[--------------------------------------------------------------------
        Test 4: Pre-2.0.18 entries (no awardedItemGuid) are never matched
    ----------------------------------------------------------------------]]
    assertEqual(history:RemoveByItemGUID("item-z-missing"), 0,
        "Orphan cleanup never deletes entries lacking awardedItemGuid")
    local h4again = history:GetEntryByGUID("H4")
    assertEqual(h4again and h4again.guid or nil, "H4",
        "H4 (no awardedItemGuid) is preserved across every RemoveByItemGUID call")

    --[[--------------------------------------------------------------------
        Test 5: AddEntry receiver-side idempotency
        Closes the council-consistency gap: when an ML revotes and re-awards
        an item, the receiver should evict any prior row carrying the same
        awardedItemGuid before inserting the new one.
    ----------------------------------------------------------------------]]
    print("\n|cffFFFF00Test Group: AddEntry receiver-side idempotency|r")

    -- Seed a "stale" row (as if the receiver had already recorded an award
    -- that has since been revoted on the ML side).
    history:AddEntry({ guid = "H5-stale", awardedItemGuid = "item-5-seed",
        winner = "Eve", itemLink = "itemE", timestamp = 5 })
    local h5 = history:GetEntryByGUID("H5-stale")
    if h5 then h5.awardedItemGuid = "item-5" end
    local pre = history:GetCount()

    -- Re-award arrives on the wire: new entry for the SAME awardedItemGuid.
    history:AddEntry({ guid = "H5-final", awardedItemGuid = "item-5",
        winner = "Frank", itemLink = "itemE", timestamp = 6 })

    assertEqual(history:GetCount(), pre,
        "AddEntry evicts prior row with matching awardedItemGuid (net delta = 0)")
    assertEqual(history:GetEntryByGUID("H5-stale"), nil,
        "Stale row H5-stale is gone")
    local h5final = history:GetEntryByGUID("H5-final")
    if h5final then
        assertEqual(h5final.winner, "Frank",
            "New row H5-final is inserted with the re-award winner")
    else
        fail("H5-final exists", "(new entry was not inserted)")
    end

    -- Sanity: entries with nil awardedItemGuid are not touched by the new path.
    local h4sanity = history:GetEntryByGUID("H4")
    assertEqual(h4sanity and h4sanity.guid or nil, "H4",
        "AddEntry idempotency path leaves nil-guid rows alone")

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
    TestRunner:RegisterTest("historyrevoke", RunHistoryRevokeTests)
end
