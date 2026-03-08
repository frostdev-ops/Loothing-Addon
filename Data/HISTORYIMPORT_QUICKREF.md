# HistoryImport Quick Reference

## Access Module

```lua
local importer = Loothing.HistoryImport
```

## Basic Import (CSV)

```lua
local csvText = [[Date,Item,ItemID,Winner,Response,Votes,Notes,Encounter,EncounterID
2025-12-06 03:30,Test Item,12345,Player-Realm,Main Spec,5,,Test Boss,100]]

local entries, err = importer:ParseCSV(csvText)
if entries then
    importer:ImportEntries(entries, false)  -- false = don't overwrite
end
```

## Auto-Detect Format

```lua
local entries, err = importer:DetectFormat(importText)  -- Works with CSV or TSV
```

## Check for Conflicts

```lua
local conflicts = importer:GetConflicts(entries)
if #conflicts > 0 then
    print("Found", #conflicts, "conflicts")
end
```

## Get Import Results

```lua
local stats = importer:GetImportStats()
print(string.format("Imported: %d, Errors: %d", stats.imported, stats.errors))
```

## Handle Errors

```lua
local entries, err = importer:ParseCSV(csvText)
if not entries then
    print("Parse error:", err)

    local errors = importer:GetErrors()
    for _, error in ipairs(errors) do
        print(string.format("Line %d: %s", error.line, error.description))
    end
end
```

## Progress Tracking

```lua
importer:RegisterCallback("OnImportProgress", function(current, total)
    print(string.format("Progress: %d/%d", current, total))
end)

importer:RegisterCallback("OnImportComplete", function(stats)
    print("Import complete:", stats.imported, "entries")
end)
```

## Complete Workflow

```lua
-- 1. Parse
local entries, parseErr = importer:DetectFormat(csvText)
if not entries then return end

-- 2. Validate
local valid, validErr = importer:ValidateEntries(entries)
if not valid then return end

-- 3. Check conflicts
local conflicts = importer:GetConflicts(entries)

-- 4. Import
local success, importErr = importer:ImportEntries(entries, #conflicts > 0)

-- 5. Get stats
if success then
    local stats = importer:GetImportStats()
end
```

## Date Formats

Supports:
- `2025-12-06 03:30:00` (ISO with seconds)
- `2025-12-06 03:30` (ISO without seconds)
- `2025-12-06` (ISO date only)
- `12/06/2025` (US format)

## CSV Format

```csv
Date,Item,ItemID,Winner,Response,Votes,Notes,Encounter,EncounterID
2025-12-06 03:30,Item Name,12345,Player-Realm,Main Spec,5,Optional note,Boss Name,100
```

## Key Methods

| Method | Purpose |
|--------|---------|
| `ParseCSV(text)` | Parse CSV format |
| `ParseTSV(text)` | Parse TSV format |
| `DetectFormat(text)` | Auto-detect CSV/TSV |
| `ValidateEntries(entries)` | Validate before import |
| `GetConflicts(entries)` | Find duplicates |
| `ImportEntries(entries, overwrite)` | Execute import |
| `GetImportStats()` | Get results |
| `GetErrors()` | Get error details |

## Events

| Event | Parameters | When |
|-------|-----------|------|
| `OnImportStarted` | `totalEntries` | Import begins |
| `OnImportProgress` | `current, total` | Every 10 entries |
| `OnImportComplete` | `stats` | Import finishes |
| `OnImportError` | `error` | Import fails |

## Testing

Run tests in-game:
```lua
/lttest import
```

## Common Patterns

### Import with User Confirmation

```lua
local conflicts = importer:GetConflicts(entries)
if #conflicts > 0 then
    StaticPopupDialogs["CONFIRM_IMPORT"] = {
        text = string.format("Overwrite %d entries?", #conflicts),
        button1 = "Yes",
        button2 = "No",
        OnAccept = function()
            importer:ImportEntries(entries, true)
        end,
    }
    StaticPopup_Show("CONFIRM_IMPORT")
else
    importer:ImportEntries(entries, false)
end
```

### Show Progress Bar

```lua
local progress = 0
importer:RegisterCallback("OnImportProgress", function(current, total)
    progress = (current / total) * 100
    -- Update progress bar UI here
end)
```

### Batch Import Multiple Files

```lua
for _, fileContents in ipairs(files) do
    local entries = importer:DetectFormat(fileContents)
    if entries then
        importer:ImportEntries(entries, false)
    end
end
```

## Error Codes

Common errors:
- `"Empty import text"` - No data provided
- `"Invalid header format"` - Header doesn't match expected format
- `"Expected 9 fields, got X"` - Malformed CSV line
- `"Date is required"` - Missing required field
- `"Winner is required"` - Missing required field
- `"Could not parse date"` - Invalid date format
- `"Import already in progress"` - Concurrent import attempt
