--[[--------------------------------------------------------------------
    Loothing - Loot Council Addon for WoW 12.0+
    HistoryImport - CSV/TSV history import functionality
----------------------------------------------------------------------]]

local _, ns = ...
local Loolib = LibStub("Loolib")
local Loothing = ns.Addon
local Utils = ns.Utils

--[[--------------------------------------------------------------------
    HistoryImportMixin
----------------------------------------------------------------------]]

local HistoryImportMixin = Loolib.CreateFromMixins(Loolib.CallbackRegistryMixin)
ns.HistoryImportMixin = HistoryImportMixin

local IMPORT_EVENTS = {
    "OnImportStarted",
    "OnImportProgress",
    "OnImportComplete",
    "OnImportError",
}

--[[--------------------------------------------------------------------
    Private State
----------------------------------------------------------------------]]

local private = {
    errorList = {},
    stats = {
        imported = 0,
        skipped = 0,
        errors = 0,
    },
    currentImport = nil,
    importing = false,
}

--[[--------------------------------------------------------------------
    Initialization
----------------------------------------------------------------------]]

--- Initialize the import module
function HistoryImportMixin:Init()
    Loolib.CallbackRegistryMixin.OnLoad(self)
    self:GenerateCallbackEvents(IMPORT_EVENTS)
end

--[[--------------------------------------------------------------------
    CSV/TSV Parsing
----------------------------------------------------------------------]]

--- Parse CSV text into entries array
-- @param text string - CSV formatted text
-- @return table|nil - Array of entry tables or nil on error
function HistoryImportMixin:ParseCSV(text)
    return self:ParseDelimited(text, ",")
end

--- Parse TSV text into entries array
-- @param text string - TSV formatted text
-- @return table|nil - Array of entry tables or nil on error
function HistoryImportMixin:ParseTSV(text)
    return self:ParseDelimited(text, "\t")
end

--- Auto-detect format and parse
-- @param text string - Import text
-- @return table|nil - Array of entry tables or nil on error
function HistoryImportMixin:DetectFormat(text)
    if not text or text == "" then
        return nil, "Empty import text"
    end

    -- Get first non-comment line to detect format
    local firstLine
    for line in text:gmatch("([^\n]+)") do
        if not line:match("^%s*#") then
            firstLine = line
            break
        end
    end
    if not firstLine then
        return nil, "Could not read first line"
    end

    -- Count delimiters in header
    local tabCount = select(2, firstLine:gsub("\t", ""))
    local commaCount = select(2, firstLine:gsub(",", ""))

    -- TSV typically has more tabs than commas in the header
    if tabCount > commaCount then
        return self:ParseTSV(text)
    else
        return self:ParseCSV(text)
    end
end

--- Parse delimited text (CSV or TSV)
-- @param text string - Delimited text
-- @param delimiter string - Delimiter character
-- @return table|nil, string|nil - Array of entries or nil, error message
function HistoryImportMixin:ParseDelimited(text, delimiter)
    if not text or text == "" then
        return nil, "Empty import text"
    end

    -- Reset error list
    wipe(private.errorList)

    -- Remove trailing whitespace from each line
    text = text:gsub("[%s\t]+\n", "\n")

    -- Split into lines
    local lines = {}
    for line in text:gmatch("([^\n]+)") do
        lines[#lines + 1] = line
    end

    -- Filter out comment lines (metadata headers from Loothing exports)
    local filtered = {}
    for _, line in ipairs(lines) do
        if not line:match("^%s*#") then
            filtered[#filtered + 1] = line
        end
    end
    lines = filtered

    if #lines == 0 then
        return nil, "No lines found in import text"
    end

    -- Validate header
    local header = lines[1]
    if not self:ValidateHeader(header, delimiter) then
        return nil, "Invalid header format. Expected a header with at least 'date' and 'winner' (or 'player') columns"
    end

    -- Build column map for dynamic field lookup
    local colMap = self:BuildColumnMap(header, delimiter)

    -- Parse data lines
    local entries = {}
    for i = 2, #lines do
        local line = lines[i]
        if line and line ~= "" then
            local fields, fieldCount = self:ExtractLine(line, delimiter)

            -- Need at least 2 fields (date + winner)
            if fieldCount and fieldCount < 2 then
                self:AddError(i, line, string.format("Expected at least 2 fields, got %d", fieldCount))
            else
                local entry = self:ParseEntry(fields, i, colMap)
                if entry then
                    entries[#entries + 1] = entry
                end
            end
        end
    end

    -- Check for errors
    if #private.errorList > 0 then
        local errorMsg = string.format("Import contained %d errors", #private.errorList)
        return entries, errorMsg
    end

    return entries, nil
end

--- Parse a single entry from field array
-- @param fields table - Array of field values
-- @param lineNum number - Line number for error reporting
-- @param colMap table - Column name to index map (nil = use positional fallback)
-- @return table|nil - Entry table or nil on error
function HistoryImportMixin:ParseEntry(fields, lineNum, colMap)
    -- Helper: get field by column name.
    -- When colMap is present (always in practice), ONLY the named column is used —
    -- positional fallback is ignored to prevent wrong fields on mismatched formats.
    -- fallbackPos is only used when called without a colMap (future-proofing).
    local function col(name, fallbackPos)
        if colMap then
            local idx = colMap[name:lower()]
            return idx and fields[idx] or nil
        end
        return fallbackPos and fields[fallbackPos] or nil
    end

    -- Support both old format (winner col) and new format (player col)
    local winnerField = col("winner", 4) or col("player")

    local entry = {
        date          = col("date", 1),
        itemName      = col("item", 2),
        itemID        = tonumber(col("itemid", 3)),
        winner        = winnerField,
        response      = col("response", 5),
        votes         = tonumber(col("votes", 6)) or 0,
        notes         = col("notes", 7),
        encounterName = col("encounter", 8) or col("boss"),
        encounterID   = tonumber(col("encounterid", 9)),
        -- New columns (nil for old-format imports)
        winnerClass   = col("class"),
        instance      = col("instance"),
        difficultyID  = tonumber(col("difficultyid")),
        mapID         = tonumber(col("mapid")),
        groupSize     = tonumber(col("groupsize")),
        winnerGear1   = col("gear1"),
        winnerGear2   = col("gear2"),
        winnerNote    = col("note"),
        subType       = col("subtype"),
        equipSlot     = col("equiploc"),
        owner         = col("owner"),
    }

    -- Validate required fields
    if not entry.date or entry.date == "" then
        self:AddError(lineNum, fields[1] or "nil", "Date is required")
        return nil
    end

    if not entry.winner or entry.winner == "" then
        self:AddError(lineNum, winnerField or "nil", "Winner is required")
        return nil
    end

    -- Parse timestamp from date
    entry.timestamp = self:ParseDate(entry.date)
    if not entry.timestamp then
        self:AddError(lineNum, entry.date, "Could not parse date")
        return nil
    end

    -- Normalize winner name
    entry.winner = Utils.NormalizeName(entry.winner)

    -- winnerResponse: prefer numeric responseID column, then map from text response name
    local responseID = tonumber(col("responseid"))
    if responseID and responseID ~= 0 then
        entry.winnerResponse = responseID
    elseif entry.response and entry.response ~= "" then
        entry.winnerResponse = self:FindResponseByName(entry.response)
    end

    -- Use imported guid or generate a new one
    entry.guid = col("id") or Utils.GenerateGUID()

    -- Get item quality if we have an itemID and it wasn't in the import
    if entry.itemID and entry.itemID > 0 then
        local itemInfo = Utils.GetItemInfo(string.format("item:%d", entry.itemID))
        if itemInfo then
            entry.quality = entry.quality or itemInfo.quality
            entry.itemLevel = entry.itemLevel or itemInfo.itemLevel
            entry.itemLink = entry.itemLink or itemInfo.itemLink
        end
    end

    return entry
end

--- Extract fields from a delimited line (handles quoted fields)
-- @param input string - Line to parse
-- @param delimiter string - Delimiter character
-- @param notFirst boolean - Internal flag for recursion
-- @return table, number|nil - Array of fields, field count
function HistoryImportMixin:ExtractLine(input, delimiter, notFirst)
    local ret = {}

    if not input or input == "" then
        return ret, 0
    end

    -- Handle quoted fields (contains commas/tabs inside quotes)
    if input:find('"') then
        local first, last = input:find('".-"')
        if first then
            -- Parse before the quoted section
            if first > 1 then
                ret = self:ExtractLine(input:sub(1, first - 2), delimiter, true)
            end

            -- Check if quote is adjacent to delimiter
            if first > 1 and input:sub(first - 1, first - 1) ~= delimiter and
               last < #input and input:sub(last + 1, last + 1) ~= delimiter then
                -- Quote is part of a field, find the full field
                local nextDelim = input:find(delimiter, last + 2)
                if nextDelim then
                    -- Merge with previous field
                    ret[#ret] = (ret[#ret] or "") .. input:sub(first - 1, nextDelim - 1)
                    last = nextDelim - 1
                else
                    -- Last field
                    ret[#ret] = (ret[#ret] or "") .. input:sub(first - 1)
                    last = #input
                end
            else
                -- Extract quoted content (without quotes)
                ret[#ret + 1] = input:sub(first + 1, last - 1)
            end

            -- Parse after the quoted section
            if last < #input then
                local remaining = self:ExtractLine(input:sub(last + 2), delimiter, true)
                for _, v in ipairs(remaining) do
                    ret[#ret + 1] = v
                end
            end
        else
            -- No matching quote found, treat as normal
            ret = { strsplit(delimiter, input) }
        end
    else
        -- No quotes, simple split
        ret = { strsplit(delimiter, input) }
    end

    local length
    if not notFirst then
        length = #ret
        -- Convert empty strings to nil
        for i = 1, #ret do
            if ret[i] == "" then
                ret[i] = nil
            end
        end
    end

    return ret, length
end

--[[--------------------------------------------------------------------
    Validation
----------------------------------------------------------------------]]

--- Validate header line (accepts both old 9-column and new 23-column formats)
-- @param header string - Header line
-- @param delimiter string - Delimiter character
-- @return boolean - True if valid
function HistoryImportMixin:ValidateHeader(header, delimiter)
    -- Accept any header that contains a date column and a winner or player column
    local lower = header:lower()
    return lower:find("date") ~= nil and (lower:find("winner") ~= nil or lower:find("player") ~= nil)
end

--- Build a column-name-to-index map from the header line
-- @param header string - Header line
-- @param delimiter string - Delimiter character
-- @return table - { [lowerColumnName] = columnIndex }
function HistoryImportMixin:BuildColumnMap(header, delimiter)
    local colMap = {}
    local fields = { strsplit(delimiter, header) }
    for i, name in ipairs(fields) do
        -- Strip surrounding quotes and whitespace, lowercase
        name = name:gsub('^%s*"?%s*', ""):gsub('%s*"?%s*$', ""):lower()
        colMap[name] = i
    end
    return colMap
end

--- Validate an array of entries
-- @param entries table - Array of entry tables
-- @return boolean, string|nil - Valid status, error message if invalid
function HistoryImportMixin:ValidateEntries(entries)
    if not entries or #entries == 0 then
        return false, "No entries to validate"
    end

    local errors = {}

    for i, entry in ipairs(entries) do
        -- Check required fields
        if not entry.timestamp then
            errors[#errors + 1] = string.format("Entry %d: Missing timestamp", i)
        end

        if not entry.winner or entry.winner == "" then
            errors[#errors + 1] = string.format("Entry %d: Missing winner", i)
        end

        -- Winner name format is not strictly enforced (short names are valid)
    end

    if #errors > 0 then
        return false, table.concat(errors, "\n")
    end

    return true, nil
end

--- Find entries that would conflict with existing history
-- @param entries table - Array of entries to check
-- @return table - Array of conflicting entries
function HistoryImportMixin:GetConflicts(entries)
    if not entries or not Loothing.History then
        return {}
    end

    local conflicts = {}
    local existing = {}

    -- Build lookup of existing entries by winner + timestamp
    for _, existingEntry in Loothing.History:GetEntries():Enumerate() do
        local key = string.format("%s_%d", existingEntry.winner, existingEntry.timestamp or 0)
        existing[key] = existingEntry
    end

    -- Check for conflicts
    for _, entry in ipairs(entries) do
        local key = string.format("%s_%d", entry.winner, entry.timestamp or 0)
        if existing[key] then
            conflicts[#conflicts + 1] = {
                import = entry,
                existing = existing[key],
            }
        end
    end

    return conflicts
end

--[[--------------------------------------------------------------------
    Import Execution
----------------------------------------------------------------------]]

--- Import entries into history
-- @param entries table - Array of entries to import
-- @param overwrite boolean - Whether to overwrite conflicts
-- @return boolean, string|nil - Success status, error message if failed
function HistoryImportMixin:ImportEntries(entries, overwrite)
    if private.importing then
        return false, "Import already in progress"
    end

    if not entries or #entries == 0 then
        return false, "No entries to import"
    end

    if not Loothing.History then
        return false, "History module not initialized"
    end

    -- Validate entries
    local valid, err = self:ValidateEntries(entries)
    if not valid then
        return false, err
    end

    -- Reset stats
    private.stats.imported = 0
    private.stats.skipped = 0
    private.stats.errors = 0
    private.importing = true

    -- Start import
    self:TriggerEvent("OnImportStarted", #entries)

    -- Check for conflicts
    local conflicts = self:GetConflicts(entries)
    if #conflicts > 0 and not overwrite then
        private.importing = false
        return false, string.format("Import contains %d conflicts. Use overwrite=true to replace existing entries.", #conflicts)
    end

    -- Import entries
    local conflictMap = {}
    for _, conflict in ipairs(conflicts) do
        local key = string.format("%s_%d", conflict.existing.winner, conflict.existing.timestamp or 0)
        conflictMap[key] = conflict.existing
    end

    for i, entry in ipairs(entries) do
        local key = string.format("%s_%d", entry.winner, entry.timestamp or 0)
        local existingEntry = conflictMap[key]

        if existingEntry and overwrite then
            -- Remove existing entry first
            Loothing.History:RemoveEntry(existingEntry.guid)
        end

        -- Import entry
        local success, importErr = pcall(function()
            Loothing.History:AddEntry({
                guid = entry.guid,
                itemLink = entry.itemLink,
                itemID = entry.itemID,
                itemName = entry.itemName,
                itemLevel = entry.itemLevel,
                quality = entry.quality,
                winner = entry.winner,
                winnerResponse = entry.winnerResponse,
                encounterID = entry.encounterID,
                encounterName = entry.encounterName,
                votes = entry.votes,
                timestamp = entry.timestamp,
                notes = entry.notes,
            })
        end)

        if success then
            private.stats.imported = private.stats.imported + 1
        else
            private.stats.errors = private.stats.errors + 1
            Loothing:Debug("Import error for entry", i, ":", importErr)
        end

        -- Report progress every 10 entries
        if i % 10 == 0 then
            self:TriggerEvent("OnImportProgress", i, #entries)
        end
    end

    private.importing = false

    -- Trigger complete event
    self:TriggerEvent("OnImportComplete", private.stats)

    return true, nil
end

--[[--------------------------------------------------------------------
    Statistics
----------------------------------------------------------------------]]

--- Get import statistics
-- @return table - { imported, skipped, errors }
function HistoryImportMixin:GetImportStats()
    return {
        imported = private.stats.imported,
        skipped = private.stats.skipped,
        errors = private.stats.errors,
    }
end

--- Check if import is in progress
-- @return boolean
function HistoryImportMixin:IsImporting()
    return private.importing
end

--[[--------------------------------------------------------------------
    Utility Functions
----------------------------------------------------------------------]]

--- Parse date string to timestamp
-- Supports formats: YYYY-MM-DD HH:MM, YYYY-MM-DD, MM/DD/YYYY, etc.
-- @param dateStr string - Date string
-- @return number|nil - Unix timestamp or nil if invalid
function HistoryImportMixin:ParseDate(dateStr)
    if not dateStr or dateStr == "" then
        return nil
    end

    -- Try YYYY-MM-DD HH:MM:SS
    local year, month, day, hour, min, sec = dateStr:match("^(%d%d%d%d)-(%d%d)-(%d%d) (%d%d):(%d%d):?(%d*)$")
    if year then
        return time({
            year = tonumber(year),
            month = tonumber(month),
            day = tonumber(day),
            hour = tonumber(hour),
            min = tonumber(min),
            sec = tonumber(sec) or 0,
        })
    end

    -- Try YYYY-MM-DD HH:MM
    year, month, day, hour, min = dateStr:match("^(%d%d%d%d)-(%d%d)-(%d%d) (%d%d):(%d%d)$")
    if year then
        return time({
            year = tonumber(year),
            month = tonumber(month),
            day = tonumber(day),
            hour = tonumber(hour),
            min = tonumber(min),
            sec = 0,
        })
    end

    -- Try YYYY-MM-DD
    year, month, day = dateStr:match("^(%d%d%d%d)-(%d%d)-(%d%d)$")
    if year then
        return time({
            year = tonumber(year),
            month = tonumber(month),
            day = tonumber(day),
            hour = 0,
            min = 0,
            sec = 0,
        })
    end

    -- Try MM/DD/YYYY HH:MM:SS
    month, day, year, hour, min, sec = dateStr:match("^(%d%d?)/(%d%d?)/(%d%d%d%d) (%d%d):(%d%d):?(%d*)$")
    if year then
        return time({
            year = tonumber(year),
            month = tonumber(month),
            day = tonumber(day),
            hour = tonumber(hour),
            min = tonumber(min),
            sec = tonumber(sec) or 0,
        })
    end

    -- Try MM/DD/YYYY
    month, day, year = dateStr:match("^(%d%d?)/(%d%d?)/(%d%d%d%d)$")
    if year then
        return time({
            year = tonumber(year),
            month = tonumber(month),
            day = tonumber(day),
            hour = 0,
            min = 0,
            sec = 0,
        })
    end

    -- Try DD/MM/YYYY (European format)
    day, month, year = dateStr:match("^(%d%d?)/(%d%d?)/(%d%d%d%d)$")
    if year and tonumber(month) <= 12 then
        return time({
            year = tonumber(year),
            month = tonumber(month),
            day = tonumber(day),
            hour = 0,
            min = 0,
            sec = 0,
        })
    end

    return nil
end

--- Find response ID by response name
-- @param responseName string - Response name to find
-- @return string|nil - Response ID or nil if not found
function HistoryImportMixin:FindResponseByName(responseName)
    if not responseName or not Loothing.ResponseInfo then
        return nil
    end

    -- Search all responses
    for responseID, info in pairs(Loothing.ResponseInfo) do
        if info.name and info.name:lower() == responseName:lower() then
            return responseID
        end
    end

    return nil
end

--- Add error to error list
-- @param lineNum number - Line number
-- @param value string - Field value that caused error
-- @param desc string - Error description
function HistoryImportMixin:AddError(lineNum, value, desc)
    private.errorList[#private.errorList + 1] = {
        line = lineNum,
        value = value,
        description = desc,
    }
end

--- Get all errors from last import attempt
-- @return table - Array of error tables
function HistoryImportMixin:GetErrors()
    return private.errorList
end

--- Clear error list
function HistoryImportMixin:ClearErrors()
    wipe(private.errorList)
end

--[[--------------------------------------------------------------------
    Example Usage
----------------------------------------------------------------------]]

--[==[

-- Initialize
local importer = Loolib.CreateFromMixins(HistoryImportMixin)
importer:Init()

-- Register callbacks
importer:RegisterCallback("OnImportStarted", function(_, totalEntries)
    print("Import started:", totalEntries, "entries")
end)

importer:RegisterCallback("OnImportProgress", function(_, current, total)
    print(string.format("Import progress: %d/%d", current, total))
end)

importer:RegisterCallback("OnImportComplete", function(_, stats)
    print(string.format("Import complete: %d imported, %d errors", stats.imported, stats.errors))
end)

importer:RegisterCallback("OnImportError", function(_, error)
    print("Import error:", error)
end)

-- Auto-detect and import
local csvText = [=[
player,date,time,id,item,itemID,itemString,response,votes,class,instance,boss,difficultyID,mapID,groupSize,gear1,gear2,responseID,isAwardReason,subType,equipLoc,note,owner
Darkwind,2025-12-06,03:30:00,,Void-Touched Warglaive,212391,,Main Spec,5,DEATHKNIGHT,Nerub-ar Palace,Queen Ansurek,16,2596,20,,,3,0,Warglaive,INVTYPE_WEAPONMAINHAND,,Darkwind-Stormrage
]=]

local entries, err = importer:DetectFormat(csvText)
if not entries then
    print("Parse error:", err)
else
    print("Parsed", #entries, "entries")

    -- Check for conflicts
    local conflicts = importer:GetConflicts(entries)
    if #conflicts > 0 then
        print("Found", #conflicts, "conflicts")
    end

    -- Import (overwrite conflicts)
    local success, importErr = importer:ImportEntries(entries, true)
    if not success then
        print("Import failed:", importErr)
    end
end

]==]
