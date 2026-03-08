# HistoryImport Module

The HistoryImport module provides comprehensive CSV/TSV import functionality for Loothing's history system. It supports auto-format detection, validation, conflict resolution, and progress tracking.

## Features

- **Format Support**: CSV and TSV (tab-delimited) formats
- **Auto-Detection**: Automatically detects CSV vs TSV format
- **Quoted Fields**: Properly handles quoted fields containing delimiters
- **Validation**: Comprehensive validation of entries before import
- **Conflict Detection**: Identifies entries that would overwrite existing data
- **Progress Tracking**: Events for import progress monitoring
- **Error Reporting**: Detailed error messages with line numbers
- **Flexible Date Parsing**: Supports multiple date formats

## File Format

### Header Row (Required)

```
Date,Item,ItemID,Winner,Response,Votes,Notes,Encounter,EncounterID
```

Or for TSV:

```
Date	Item	ItemID	Winner	Response	Votes	Notes	Encounter	EncounterID
```

### Field Descriptions

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| Date | String | Yes | Date/time of loot award (see date formats below) |
| Item | String | No | Item name (parsed from itemLink if available) |
| ItemID | Number | No | WoW item ID |
| Winner | String | Yes | Player name (must include realm: "Name-Realm") |
| Response | String | No | Response name (e.g., "Main Spec", "Off Spec") |
| Votes | Number | No | Number of votes (default: 0) |
| Notes | String | No | Optional notes |
| Encounter | String | No | Encounter/boss name |
| EncounterID | Number | No | WoW encounter ID |

### Date Formats Supported

- `YYYY-MM-DD HH:MM:SS` - ISO format with seconds
- `YYYY-MM-DD HH:MM` - ISO format without seconds
- `YYYY-MM-DD` - ISO date only
- `MM/DD/YYYY HH:MM:SS` - US format with time
- `MM/DD/YYYY` - US date only
- `DD/MM/YYYY` - European date format

### Example CSV

```csv
Date,Item,ItemID,Winner,Response,Votes,Notes,Encounter,EncounterID
2025-12-06 03:30,Void-Touched Warglaive,212391,Darkwind-Stormrage,Main Spec,5,,Queen Ansurek,2602
2025-12-06 03:25,Sikran's Endless Arsenal,212389,Moonfire-Stormrage,Main Spec,4,,Sikran,2599
2025-12-06 03:20,"Item, with comma",12388,Sunfire-Stormrage,Off Spec,2,Tier piece,Sikran,2599
```

### Example TSV

```tsv
Date	Item	ItemID	Winner	Response	Votes	Notes	Encounter	EncounterID
2025-12-06 03:30	Void-Touched Warglaive	212391	Darkwind-Stormrage	Main Spec	5		Queen Ansurek	2602
2025-12-06 03:25	Sikran's Endless Arsenal	212389	Moonfire-Stormrage	Main Spec	4		Sikran	2599
```

## API Reference

### Module Access

```lua
local importer = Loothing.HistoryImport
```

### Methods

#### ParseCSV(text)

Parse CSV formatted text into an array of entries.

**Parameters:**
- `text` (string) - CSV formatted text

**Returns:**
- `entries` (table|nil) - Array of entry tables or nil on error
- `error` (string|nil) - Error message if parsing failed

**Example:**

```lua
local csvText = [[Date,Item,ItemID,Winner,Response,Votes,Notes,Encounter,EncounterID
2025-12-06 03:30,Test Item,12345,Player-Realm,Main Spec,5,,Test Boss,100]]

local entries, err = importer:ParseCSV(csvText)
if not entries then
    print("Parse error:", err)
else
    print("Parsed", #entries, "entries")
end
```

#### ParseTSV(text)

Parse TSV (tab-delimited) formatted text into an array of entries.

**Parameters:**
- `text` (string) - TSV formatted text

**Returns:**
- `entries` (table|nil) - Array of entry tables
- `error` (string|nil) - Error message if parsing failed

**Example:**

```lua
local tsvText = "Date\tItem\tItemID\tWinner\tResponse\tVotes\tNotes\tEncounter\tEncounterID\n" ..
                "2025-12-06 03:30\tTest Item\t12345\tPlayer-Realm\tMain Spec\t5\t\tTest Boss\t100"

local entries, err = importer:ParseTSV(tsvText)
```

#### DetectFormat(text)

Auto-detect format (CSV or TSV) and parse.

**Parameters:**
- `text` (string) - Import text in CSV or TSV format

**Returns:**
- `entries` (table|nil) - Array of entry tables
- `error` (string|nil) - Error message if parsing failed

**Example:**

```lua
-- Works with either CSV or TSV
local entries, err = importer:DetectFormat(importText)
```

#### ValidateEntries(entries)

Validate an array of entries before import.

**Parameters:**
- `entries` (table) - Array of entry tables to validate

**Returns:**
- `valid` (boolean) - True if all entries are valid
- `error` (string|nil) - Error message if validation failed

**Example:**

```lua
local valid, err = importer:ValidateEntries(entries)
if not valid then
    print("Validation failed:", err)
end
```

#### GetConflicts(entries)

Find entries that would overwrite existing history entries.

**Parameters:**
- `entries` (table) - Array of entries to check

**Returns:**
- `conflicts` (table) - Array of conflict objects

**Conflict Object Structure:**

```lua
{
    import = entry,      -- The entry being imported
    existing = entry,    -- The existing entry it conflicts with
}
```

**Example:**

```lua
local conflicts = importer:GetConflicts(entries)
if #conflicts > 0 then
    print("Found", #conflicts, "conflicts")
    for i, conflict in ipairs(conflicts) do
        print(string.format("  %s won %s",
            conflict.import.winner,
            conflict.import.itemName))
    end
end
```

#### ImportEntries(entries, overwrite)

Import entries into the history system.

**Parameters:**
- `entries` (table) - Array of entries to import
- `overwrite` (boolean) - Whether to overwrite conflicting entries

**Returns:**
- `success` (boolean) - True if import succeeded
- `error` (string|nil) - Error message if import failed

**Example:**

```lua
-- Import without overwriting conflicts
local success, err = importer:ImportEntries(entries, false)

if not success then
    print("Import failed:", err)
else
    local stats = importer:GetImportStats()
    print(string.format("Imported: %d, Errors: %d",
        stats.imported, stats.errors))
end
```

#### GetImportStats()

Get statistics from the last import operation.

**Returns:**

```lua
{
    imported = 0,  -- Number of successfully imported entries
    skipped = 0,   -- Number of skipped entries
    errors = 0,    -- Number of errors
}
```

**Example:**

```lua
local stats = importer:GetImportStats()
print(string.format("Imported: %d, Errors: %d",
    stats.imported, stats.errors))
```

#### IsImporting()

Check if an import operation is currently in progress.

**Returns:**
- `importing` (boolean) - True if import is in progress

**Example:**

```lua
if importer:IsImporting() then
    print("Import already in progress")
end
```

#### GetErrors()

Get all errors from the last parse/import attempt.

**Returns:**
- `errors` (table) - Array of error objects

**Error Object Structure:**

```lua
{
    line = 5,                           -- Line number
    value = "invalid date",             -- Value that caused error
    description = "Could not parse date" -- Error description
}
```

**Example:**

```lua
local errors = importer:GetErrors()
for i, error in ipairs(errors) do
    print(string.format("Line %d: %s - %s",
        error.line, error.description, error.value or "nil"))
end
```

#### ClearErrors()

Clear the error list from previous operations.

**Example:**

```lua
importer:ClearErrors()
```

## Events

The HistoryImport module uses LoolibCallbackRegistry to fire events during import operations.

### OnImportStarted

Fired when import begins.

**Parameters:**
- `totalEntries` (number) - Total number of entries to import

**Example:**

```lua
importer:RegisterCallback("OnImportStarted", function(totalEntries)
    print("Starting import of", totalEntries, "entries")
end)
```

### OnImportProgress

Fired periodically during import (every 10 entries).

**Parameters:**
- `current` (number) - Current entry number
- `total` (number) - Total number of entries

**Example:**

```lua
importer:RegisterCallback("OnImportProgress", function(current, total)
    local percent = (current / total) * 100
    print(string.format("Progress: %d/%d (%.1f%%)", current, total, percent))
end)
```

### OnImportComplete

Fired when import completes successfully.

**Parameters:**
- `stats` (table) - Import statistics object

**Example:**

```lua
importer:RegisterCallback("OnImportComplete", function(stats)
    print(string.format("Import complete: %d imported, %d errors",
        stats.imported, stats.errors))
end)
```

### OnImportError

Fired when import encounters an error.

**Parameters:**
- `error` (string) - Error message

**Example:**

```lua
importer:RegisterCallback("OnImportError", function(error)
    print("Import error:", error)
end)
```

## Complete Usage Example

```lua
local importer = Loothing.HistoryImport

-- Register callbacks
importer:RegisterCallback("OnImportStarted", function(total)
    print("Starting import of", total, "entries...")
end)

importer:RegisterCallback("OnImportProgress", function(current, total)
    print(string.format("Progress: %d/%d", current, total))
end)

importer:RegisterCallback("OnImportComplete", function(stats)
    print(string.format("Import complete: %d imported, %d errors",
        stats.imported, stats.errors))
end)

-- CSV data
local csvText = [[Date,Item,ItemID,Winner,Response,Votes,Notes,Encounter,EncounterID
2025-12-06 03:30,Void-Touched Warglaive,212391,Darkwind-Stormrage,Main Spec,5,,Queen Ansurek,2602
2025-12-06 03:25,Sikran's Endless Arsenal,212389,Moonfire-Stormrage,Main Spec,4,,Sikran,2599]]

-- Parse and validate
local entries, err = importer:ParseCSV(csvText)

if not entries then
    print("Parse error:", err)

    -- Show detailed errors
    local errors = importer:GetErrors()
    for i, error in ipairs(errors) do
        print(string.format("Line %d: %s", error.line, error.description))
    end
    return
end

-- Validate entries
local valid, validErr = importer:ValidateEntries(entries)
if not valid then
    print("Validation failed:", validErr)
    return
end

-- Check for conflicts
local conflicts = importer:GetConflicts(entries)
if #conflicts > 0 then
    print(string.format("Warning: %d entries will overwrite existing data", #conflicts))

    -- Show conflicts
    for i, conflict in ipairs(conflicts) do
        print(string.format("  %s won %s at %s",
            conflict.existing.winner,
            conflict.existing.itemName,
            date("%Y-%m-%d %H:%M", conflict.existing.timestamp)))
    end
end

-- Import (with or without overwriting)
local success, importErr = importer:ImportEntries(entries, true)  -- true = overwrite conflicts

if not success then
    print("Import failed:", importErr)
else
    local stats = importer:GetImportStats()
    print("Import successful!")
end
```

## Integration with History.lua

The HistoryImport module integrates seamlessly with Loothing.History:

```lua
-- Export from History
local csvExport = Loothing.History:ExportCSV()

-- Later, import it back
local entries, err = Loothing.HistoryImport:ParseCSV(csvExport)
if entries then
    Loothing.HistoryImport:ImportEntries(entries, false)
end
```

## Error Handling Best Practices

1. **Always check parse results:**

```lua
local entries, err = importer:ParseCSV(csvText)
if not entries then
    print("Parse error:", err)
    return
end
```

2. **Validate before importing:**

```lua
local valid, err = importer:ValidateEntries(entries)
if not valid then
    print("Validation failed:", err)
    return
end
```

3. **Handle conflicts gracefully:**

```lua
local conflicts = importer:GetConflicts(entries)
if #conflicts > 0 then
    -- Ask user before overwriting
    -- ...
end
```

4. **Check import success:**

```lua
local success, err = importer:ImportEntries(entries, false)
if not success then
    print("Import failed:", err)
end
```

## Performance Notes

- Import progress events fire every 10 entries to avoid spam
- Large imports (1000+ entries) may take several seconds
- Use callbacks to provide user feedback during long imports
- Consider batching very large imports (10,000+ entries)

## Compatibility

- Works with exports from History.lua
- Compatible with RCLootCouncil CSV/TSV exports (with minor format adjustments)
- Supports all WoW item IDs and encounter IDs from Midnight expansion (12.0+)

## Testing

Run the test suite with:

```lua
/lttest import
```

This will run comprehensive tests for:
- Date parsing
- CSV/TSV parsing
- Quoted field handling
- Format auto-detection
- Validation
- Error handling
- Multiple entries
- Empty field handling

## Files

- `HistoryImport.lua` - Main implementation
- `HistoryImport_Tests.lua` - Test suite (development only)
- `HistoryImport_Example.lua` - Usage examples (documentation only)
- `HistoryImport_README.md` - This documentation
