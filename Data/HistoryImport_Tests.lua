--[[--------------------------------------------------------------------
    Loothing - Loot Council Addon for WoW 12.0+
    HistoryImport_Tests - Test suite for history import functionality

    This file is for development/testing only and should not be loaded
    in production. To run tests, load this file manually in-game.
----------------------------------------------------------------------]]
local _, ns = ...

local function RunHistoryImportTests()
    if not Loothing or not Loothing.HistoryImport then
        print("[Tests] HistoryImport module not loaded")
        return
    end

    local importer = Loothing.HistoryImport
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

    print("|cff00ccff========== HistoryImport Tests ==========|r")

    -- Test 1: Parse date formats
    print("\n|cffFFFF00Test Group: Date Parsing|r")

    local ts1 = importer:ParseDate("2025-12-06 03:30:00")
    assert(ts1 ~= nil, "Parse YYYY-MM-DD HH:MM:SS format")

    local ts2 = importer:ParseDate("2025-12-06 03:30")
    assert(ts2 ~= nil, "Parse YYYY-MM-DD HH:MM format")

    local ts3 = importer:ParseDate("2025-12-06")
    assert(ts3 ~= nil, "Parse YYYY-MM-DD format")

    local ts4 = importer:ParseDate("12/06/2025")
    assert(ts4 ~= nil, "Parse MM/DD/YYYY format")

    local ts5 = importer:ParseDate("invalid date")
    assert(ts5 == nil, "Reject invalid date format")

    -- Test 2: CSV parsing
    print("\n|cffFFFF00Test Group: CSV Parsing|r")

    local csvText = [[Date,Item,ItemID,Winner,Response,Votes,Notes,Encounter,EncounterID
2025-12-06 03:30,Test Item,12345,Player-Realm,Main Spec,5,,Test Boss,100]]

    local entries, err = importer:ParseCSV(csvText)
    assert(entries ~= nil, "Parse valid CSV")
    assert(#entries == 1, "CSV has correct entry count")
    if entries and #entries > 0 then
        assert(entries[1].itemName == "Test Item", "CSV entry has correct item name")
        assert(entries[1].winner == "Player-Realm", "CSV entry has correct winner")
        assert(entries[1].votes == 5, "CSV entry has correct votes")
    end

    -- Test 3: TSV parsing
    print("\n|cffFFFF00Test Group: TSV Parsing|r")

    local tsvText = "Date\tItem\tItemID\tWinner\tResponse\tVotes\tNotes\tEncounter\tEncounterID\n" ..
                    "2025-12-06 03:30\tTest Item\t12345\tPlayer-Realm\tMain Spec\t5\t\tTest Boss\t100"

    entries, err = importer:ParseTSV(tsvText)
    assert(entries ~= nil, "Parse valid TSV")
    assert(#entries == 1, "TSV has correct entry count")

    -- Test 4: Quoted fields with commas
    print("\n|cffFFFF00Test Group: Quoted Field Handling|r")

    local csvWithQuotes = [[Date,Item,ItemID,Winner,Response,Votes,Notes,Encounter,EncounterID
2025-12-06 03:30,"Item, with comma",12345,Player-Realm,Main Spec,5,"Note, with comma",Test Boss,100]]

    entries, err = importer:ParseCSV(csvWithQuotes)
    assert(entries ~= nil, "Parse CSV with quoted fields")
    if entries and #entries > 0 then
        assert(entries[1].itemName == "Item, with comma", "Correctly parse quoted item name with comma")
        assert(entries[1].notes == "Note, with comma", "Correctly parse quoted notes with comma")
    end

    -- Test 5: Format detection
    print("\n|cffFFFF00Test Group: Format Detection|r")

    entries, err = importer:DetectFormat(csvText)
    assert(entries ~= nil, "Auto-detect CSV format")

    entries, err = importer:DetectFormat(tsvText)
    assert(entries ~= nil, "Auto-detect TSV format")

    -- Test 6: Header validation
    print("\n|cffFFFF00Test Group: Header Validation|r")

    local validHeader = "Date,Item,ItemID,Winner,Response,Votes,Notes,Encounter,EncounterID"
    assert(importer:ValidateHeader(validHeader, ","), "Accept valid CSV header")

    local invalidHeader = "Date,Item,Winner"
    assert(not importer:ValidateHeader(invalidHeader, ","), "Reject invalid CSV header")

    -- Test 7: Entry validation
    print("\n|cffFFFF00Test Group: Entry Validation|r")

    local validEntries = {
        {
            timestamp = time(),
            winner = "Player-Realm",
            itemName = "Test Item",
        }
    }
    local valid, errMsg = importer:ValidateEntries(validEntries)
    assert(valid, "Validate correct entry")

    local invalidEntries = {
        {
            timestamp = time(),
            winner = "",  -- Missing winner
        }
    }
    valid, errMsg = importer:ValidateEntries(invalidEntries)
    assert(not valid, "Reject entry with missing winner")

    local noRealmEntries = {
        {
            timestamp = time(),
            winner = "Player",  -- No realm
        }
    }
    valid, errMsg = importer:ValidateEntries(noRealmEntries)
    assert(not valid, "Reject entry with winner name missing realm")

    -- Test 8: Error handling
    print("\n|cffFFFF00Test Group: Error Handling|r")

    local badCSV = [[Date,Item,ItemID,Winner,Response,Votes,Notes,Encounter,EncounterID
2025-12-06,Test,,Player-Realm,Main Spec]]  -- Missing fields

    entries, err = importer:ParseCSV(badCSV)
    assert(err ~= nil, "Report error for malformed CSV")

    local errors = importer:GetErrors()
    assert(#errors > 0, "Error list populated on parse failure")

    -- Test 9: Multiple entries
    print("\n|cffFFFF00Test Group: Multiple Entries|r")

    local multiCSV = [[Date,Item,ItemID,Winner,Response,Votes,Notes,Encounter,EncounterID
2025-12-06 03:30,Item 1,12345,Player1-Realm,Main Spec,5,,Boss 1,100
2025-12-06 03:25,Item 2,12346,Player2-Realm,Off Spec,3,,Boss 2,101
2025-12-06 03:20,Item 3,12347,Player1-Realm,Main Spec,7,,Boss 1,100]]

    entries, err = importer:ParseCSV(multiCSV)
    assert(entries ~= nil and #entries == 3, "Parse multiple entries correctly")
    if entries then
        assert(entries[1].itemName == "Item 1", "First entry correct")
        assert(entries[2].itemName == "Item 2", "Second entry correct")
        assert(entries[3].itemName == "Item 3", "Third entry correct")
    end

    -- Test 10: Empty notes handling
    print("\n|cffFFFF00Test Group: Empty Field Handling|r")

    local emptyNotesCSV = [[Date,Item,ItemID,Winner,Response,Votes,Notes,Encounter,EncounterID
2025-12-06 03:30,Test Item,12345,Player-Realm,Main Spec,5,,,100]]

    entries, err = importer:ParseCSV(emptyNotesCSV)
    assert(entries ~= nil and #entries == 1, "Parse entry with empty notes")
    if entries and #entries > 0 then
        assert(entries[1].notes == nil or entries[1].notes == "", "Empty notes handled correctly")
        assert(entries[1].encounterName == nil or entries[1].encounterName == "", "Empty encounter handled correctly")
    end

    -- Print summary
    print("\n|cff00ccff========== Test Summary ==========|r")
    print(string.format("|cff00ff00Passed: %d|r", passed))
    print(string.format("|cffff0000Failed: %d|r", failed))
    print(string.format("Total: %d", passed + failed))

    if failed == 0 then
        print("|cff00ff00All tests passed!|r")
    else
        print("|cffff0000Some tests failed!|r")
    end
end

