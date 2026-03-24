--[[--------------------------------------------------------------------
    Loothing - Loot Council Addon for WoW 12.0+
    HistoryImport_Example - Usage examples for HistoryImport module

    This file demonstrates how to use the HistoryImport module.
    It is not loaded by the addon - it's for documentation purposes.
----------------------------------------------------------------------]]
local _, ns = ...

local Loolib = LibStub("Loolib")
local Loothing = ns.Addon

--[[--------------------------------------------------------------------
    EXAMPLE 1: Basic CSV Import
----------------------------------------------------------------------]]

local function Example_BasicCSVImport()
    -- Get the importer instance
    local importer = Loothing.HistoryImport

    -- CSV data to import
    local csvText = [[Date,Item,ItemID,Winner,Response,Votes,Notes,Encounter,EncounterID
2025-12-06 03:30,Void-Touched Warglaive,212391,Darkwind-Stormrage,Main Spec,5,,Queen Ansurek,2602
2025-12-06 03:25,Sikran's Endless Arsenal,212389,Moonfire-Stormrage,Main Spec,4,,Sikran,2599
2025-12-06 03:20,Regalia of the Forgotten,212388,Sunfire-Stormrage,Off Spec,2,Tier piece,Sikran,2599]]

    -- Parse the CSV
    local entries, err = importer:ParseCSV(csvText)

    if not entries then
        print("Parse error:", err)
        return
    end

    print("Parsed", #entries, "entries")

    -- Import the entries (without overwriting conflicts)
    local success, importErr = importer:ImportEntries(entries, false)

    if not success then
        print("Import failed:", importErr)
    else
        local stats = importer:GetImportStats()
        print(string.format("Import complete: %d imported, %d errors",
            stats.imported, stats.errors))
    end
end

--[[--------------------------------------------------------------------
    EXAMPLE 2: TSV Import with Progress Tracking
----------------------------------------------------------------------]]

local function Example_TSVImportWithProgress()
    local importer = Loothing.HistoryImport

    -- Register progress callbacks
    importer:RegisterCallback("OnImportStarted", function(totalEntries)
        print(string.format("Starting import of %d entries...", totalEntries))
    end)

    importer:RegisterCallback("OnImportProgress", function(current, total)
        print(string.format("Progress: %d/%d (%.1f%%)",
            current, total, (current / total) * 100))
    end)

    importer:RegisterCallback("OnImportComplete", function(stats)
        print(string.format("Import complete!"))
        print(string.format("  Imported: %d", stats.imported))
        print(string.format("  Skipped: %d", stats.skipped))
        print(string.format("  Errors: %d", stats.errors))
    end)

    importer:RegisterCallback("OnImportError", function(error)
        print("Import error:", error)
    end)

    -- TSV data (tab-delimited)
    local tsvText = "Date\tItem\tItemID\tWinner\tResponse\tVotes\tNotes\tEncounter\tEncounterID\n" ..
                    "2025-12-06 03:30\tVoid-Touched Warglaive\t212391\tDarkwind-Stormrage\tMain Spec\t5\t\tQueen Ansurek\t2602\n" ..
                    "2025-12-06 03:25\tSikran's Endless Arsenal\t212389\tMoonfire-Stormrage\tMain Spec\t4\t\tSikran\t2599"

    -- Parse and import
    local entries, err = importer:ParseTSV(tsvText)
    if entries then
        importer:ImportEntries(entries, false)
    end
end

--[[--------------------------------------------------------------------
    EXAMPLE 3: Auto-Detect Format with Conflict Handling
----------------------------------------------------------------------]]

local function Example_AutoDetectWithConflicts()
    local importer = Loothing.HistoryImport

    -- Unknown format (could be CSV or TSV)
    local importText = [[Date,Item,ItemID,Winner,Response,Votes,Notes,Encounter,EncounterID
2025-12-06 03:30,Test Item,12345,Player-Realm,Main Spec,5,,Test Boss,100]]

    -- Auto-detect and parse
    local entries, err = importer:DetectFormat(importText)

    if not entries then
        print("Parse error:", err)

        -- Print detailed errors
        local errors = importer:GetErrors()
        for i, error in ipairs(errors) do
            print(string.format("Line %d: %s - %s",
                error.line, error.description, error.value or "nil"))
        end
        return
    end

    -- Check for conflicts
    local conflicts = importer:GetConflicts(entries)

    if #conflicts > 0 then
        print(string.format("Found %d conflicts:", #conflicts))
        for i, conflict in ipairs(conflicts) do
            print(string.format("  Entry %d: %s won %s at %s",
                i,
                conflict.import.winner,
                conflict.import.itemName,
                conflict.import.date))
        end

        -- Ask user if they want to overwrite
        Loolib.Compat.RegisterStaticPopup("LOOTHING_IMPORT_OVERWRITE", {
            text = string.format("Import contains %d conflicts. Overwrite existing entries?", #conflicts),
            button1 = "Overwrite",
            button2 = "Cancel",
            OnAccept = function()
                importer:ImportEntries(entries, true)  -- Overwrite
            end,
            timeout = 0,
            whileDead = true,
            hideOnEscape = true,
        })
        StaticPopup_Show("LOOTHING_IMPORT_OVERWRITE")
    else
        -- No conflicts, import directly
        importer:ImportEntries(entries, false)
    end
end

--[[--------------------------------------------------------------------
    EXAMPLE 4: Import from Clipboard with Validation
----------------------------------------------------------------------]]

local function Example_ImportFromClipboard()
    local importer = Loothing.HistoryImport

    -- In a real implementation, you'd get this from a multiline edit box
    local clipboardText = "..." -- CSV/TSV data from clipboard

    -- Clear previous errors
    importer:ClearErrors()

    -- Auto-detect and parse
    local entries, err = importer:DetectFormat(clipboardText)

    if not entries then
        print("Failed to parse clipboard data:", err)
        return
    end

    -- Validate entries
    local valid, validationErr = importer:ValidateEntries(entries)

    if not valid then
        print("Validation failed:", validationErr)
        return
    end

    -- Get import stats preview
    print(string.format("Ready to import %d entries", #entries))

    local conflicts = importer:GetConflicts(entries)
    if #conflicts > 0 then
        print(string.format("Warning: %d entries will overwrite existing data", #conflicts))
    end

    -- Proceed with import
    local success, importErr = importer:ImportEntries(entries, false)

    if success then
        local stats = importer:GetImportStats()
        print("Import successful!")
        print(string.format("Imported: %d, Errors: %d", stats.imported, stats.errors))
    else
        print("Import failed:", importErr)
    end
end

--[[--------------------------------------------------------------------
    EXAMPLE 5: Batch Import Multiple Files
----------------------------------------------------------------------]]

local function Example_BatchImport()
    local importer = Loothing.HistoryImport

    local files = {
        "export_week1.csv",
        "export_week2.csv",
        "export_week3.csv",
    }

    local totalImported = 0
    local totalErrors = 0

    for _, filename in ipairs(files) do
        print("Importing", filename)

        -- In real code, you'd read file contents here
        local fileContents = "..." -- Read from file

        local entries, err = importer:DetectFormat(fileContents)

        if entries then
            local success, importErr = importer:ImportEntries(entries, false)

            if success then
                local stats = importer:GetImportStats()
                totalImported = totalImported + stats.imported
                totalErrors = totalErrors + stats.errors
            else
                print("  Failed:", importErr)
                totalErrors = totalErrors + 1
            end
        else
            print("  Parse error:", err)
            totalErrors = totalErrors + 1
        end
    end

    print(string.format("Batch import complete: %d imported, %d errors",
        totalImported, totalErrors))
end

--[[--------------------------------------------------------------------
    EXAMPLE 6: Export and Re-Import (Round-Trip Test)
----------------------------------------------------------------------]]

local function Example_RoundTripTest()
    -- Export current history to CSV
    local csvExport = Loothing.History:ExportCSV()

    -- Save to a variable or file
    -- ...

    -- Later, import it back
    local importer = Loothing.HistoryImport
    local entries, err = importer:ParseCSV(csvExport)

    if entries then
        print("Round-trip test: Parsed", #entries, "entries from export")

        -- Validate that all entries are valid
        local valid, validationErr = importer:ValidateEntries(entries)

        if valid then
            print("Round-trip test: All entries valid!")
        else
            print("Round-trip test failed:", validationErr)
        end
    else
        print("Round-trip test failed to parse:", err)
    end
end

--[[--------------------------------------------------------------------
    EXAMPLE 7: Import with Custom Error Handling
----------------------------------------------------------------------]]

local function Example_CustomErrorHandling()
    local importer = Loothing.HistoryImport

    local csvText = [[Date,Item,ItemID,Winner,Response,Votes,Notes,Encounter,EncounterID
2025-12-06 03:30,Test Item,12345,Player-Realm,Main Spec,5,,Test Boss,100
invalid date,Test Item 2,12346,Player-Realm,Main Spec,5,,Test Boss,100
2025-12-06,Test Item 3,,Player-Realm,Main Spec,5,,Test Boss,100]]

    local entries, err = importer:ParseCSV(csvText)

    -- Check if there were any errors during parsing
    local errors = importer:GetErrors()

    if #errors > 0 then
        print(string.format("Import encountered %d errors:", #errors))

        for i, error in ipairs(errors) do
            print(string.format("  Line %d: %s", error.line, error.description))
            print(string.format("    Value: %s", error.value or "nil"))
        end

        -- You can choose to:
        -- 1. Abort the import
        -- 2. Import only valid entries
        -- 3. Fix errors and retry

        if entries and #entries > 0 then
            print(string.format("Import will proceed with %d valid entries (skipping %d errors)",
                #entries, #errors))
        end
    end

    -- Import valid entries only
    if entries and #entries > 0 then
        importer:ImportEntries(entries, false)
    end
end

--[[--------------------------------------------------------------------
    Slash Command Integration
----------------------------------------------------------------------]]

-- Add import command to main slash handler
-- /lt import - Show import dialog
-- /lt import csv <data> - Import CSV data directly

Loolib.Compat.RegisterSlashCommand("LOOTHING_IMPORT", "/ltimport", nil, function(msg)
    if msg == "" then
        -- Show import dialog (would need UI implementation)
        print("Opening import dialog...")
        -- ShowImportDialog()
    else
        -- Try to import from command line argument
        local importer = Loothing.HistoryImport
        local entries, err = importer:DetectFormat(msg)

        if entries then
            local success, importErr = importer:ImportEntries(entries, false)
            if success then
                local stats = importer:GetImportStats()
                print(string.format("Imported %d entries", stats.imported))
            else
                print("Import failed:", importErr)
            end
        else
            print("Parse error:", err)
        end
    end
end)
