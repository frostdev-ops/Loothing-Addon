--[[--------------------------------------------------------------------
    Loothing - Loot Council Addon for WoW 12.0+
    History - Loot history storage and retrieval
----------------------------------------------------------------------]]

local _, ns = ...
local Loolib = LibStub("Loolib")
local Loothing = ns.Addon
local Utils = ns.Utils
local ipairs, pairs, time = ipairs, pairs, time

--[[--------------------------------------------------------------------
    HistoryMixin
----------------------------------------------------------------------]]

local HistoryMixin = Loolib.CreateFromMixins(Loolib.CallbackRegistryMixin)
ns.HistoryMixin = HistoryMixin

local HISTORY_EVENTS = {
    "OnEntryAdded",
    "OnEntryRemoved",
    "OnHistoryCleared",
    "OnBulkEntriesRemoved",
    "OnFilterChanged",
    "OnHistoryChanged",
}

--- Initialize history manager
function HistoryMixin:Init()
    Loolib.CallbackRegistryMixin.OnLoad(self)
    self:GenerateCallbackEvents(HISTORY_EVENTS)

    -- Data provider for history entries
    local Data = Loolib.Data
    self.entries = Data.CreateDataProvider()

    -- Filter state
    self.filter = {
        searchText = nil,
        winner = nil,
        encounterName = nil,
        startDate = nil,
        endDate = nil,
    }

    -- Filtered view
    self.filteredEntries = Data.CreateDataProvider()
    self.bulkDepth = 0
    self.bulkPendingAdditions = nil
    self.bulkPendingRemovals = nil

    -- Load from SavedVariables
    self:LoadFromSaved()
end

--[[--------------------------------------------------------------------
    Entry Management
----------------------------------------------------------------------]]

--- Add a history entry
-- @param entry table - History entry table (see complete schema in Loothing docs)
function HistoryMixin:AddEntry(entry)
    -- Guard: skip if history is disabled
    if Loothing.Settings and not Loothing.Settings:Get("historySettings.enabled", true) then
        return
    end

    -- Ensure required fields
    entry.timestamp = entry.timestamp or time()
    entry.guid = entry.guid or Utils.GenerateGUID()

    -- Parse item info if not present
    if entry.itemLink and not entry.itemName then
        local itemInfo = Utils.GetItemInfo(entry.itemLink)
        if itemInfo then
            entry.itemName = itemInfo.name
            entry.itemID = itemInfo.itemID
            entry.itemLevel = itemInfo.itemLevel
            entry.quality = itemInfo.quality
        end
    end

    -- Add to data provider
    self.entries:Insert(entry)

    if self:IsBulkUpdating() then
        local pending = self.bulkPendingAdditions or {}
        pending[#pending + 1] = entry
        self.bulkPendingAdditions = pending
    else
        self:SaveEntry(entry)
        self:PruneSavedHistory()
        self:ApplyFilter()
    end

    if not self:IsBulkUpdating() then
        self:TriggerEvent("OnEntryAdded", entry)
        self:TriggerEvent("OnHistoryChanged", "add", entry)
    end
end

--- Remove a history entry
-- @param guid string
-- @return boolean
function HistoryMixin:RemoveEntry(guid)
    local entry = self:GetEntryByGUID(guid)
    if not entry then
        return false
    end

    self.entries:Remove(entry)

    if self:IsBulkUpdating() then
        local pending = self.bulkPendingRemovals or {}
        pending[guid] = true
        self.bulkPendingRemovals = pending
    else
        self:RemoveSavedEntry(guid)
        self:ApplyFilter()
    end

    if not self:IsBulkUpdating() then
        self:TriggerEvent("OnEntryRemoved", entry)
        self:TriggerEvent("OnHistoryChanged", "remove", entry)
    end
    return true
end

function HistoryMixin:IsBulkUpdating()
    return (self.bulkDepth or 0) > 0
end

function HistoryMixin:BeginBulkUpdate()
    self.bulkDepth = (self.bulkDepth or 0) + 1
    if self.bulkDepth == 1 then
        self.bulkPendingAdditions = {}
        self.bulkPendingRemovals = {}
    end
end

function HistoryMixin:EndBulkUpdate()
    if not self:IsBulkUpdating() then
        return
    end

    self.bulkDepth = self.bulkDepth - 1
    if self.bulkDepth > 0 then
        return
    end

    local added = self.bulkPendingAdditions or {}
    local removed = self.bulkPendingRemovals or {}
    self.bulkPendingAdditions = nil
    self.bulkPendingRemovals = nil

    if next(removed) then
        self:RemoveSavedEntries(removed)
    end
    if #added > 0 then
        self:SaveEntries(added)
    end

    self:PruneSavedHistory()
    self:ApplyFilter()
    self:TriggerEvent("OnHistoryChanged", "bulk", {
        added = #added,
        removed = removed,
    })
end

--- Get entry by GUID
-- @param guid string
-- @return table|nil
function HistoryMixin:GetEntryByGUID(guid)
    for _, entry in self.entries:Enumerate() do
        if entry.guid == guid then
            return entry
        end
    end
    return nil
end

--- Get all entries
-- @return DataProvider
function HistoryMixin:GetEntries()
    return self.entries
end

--- Get filtered entries
-- @return DataProvider
function HistoryMixin:GetFilteredEntries()
    return self.filteredEntries
end

--- Get entry count
-- @return number
function HistoryMixin:GetCount()
    return self.entries:GetSize()
end

--- Get filtered count
-- @return number
function HistoryMixin:GetFilteredCount()
    return self.filteredEntries:GetSize()
end

--- Clear all history
function HistoryMixin:ClearHistory()
    self.entries:Flush()
    self.filteredEntries:Flush()

    -- Clear SavedVariables
    if Loothing.Settings then
        Loothing.Settings:ClearHistory()
    end

    self:TriggerEvent("OnHistoryCleared")
    self:TriggerEvent("OnHistoryChanged", "clear")
end

--[[--------------------------------------------------------------------
    Bulk Deletion Methods
----------------------------------------------------------------------]]

--- Delete all entries for a specific player
-- @param playerName string - Player name to delete entries for
-- @return number - Number of entries deleted
function HistoryMixin:DeleteByPlayer(playerName)
    if not playerName or playerName == "" then
        return 0
    end

    playerName = Utils.NormalizeName(playerName)
    if not playerName then
        return 0
    end

    local toRemove = {}

    -- Collect entries to remove
    for _, entry in self.entries:Enumerate() do
        if entry.winner == playerName then
            toRemove[#toRemove + 1] = entry
        end
    end

    -- Remove entries
    for _, entry in ipairs(toRemove) do
        self.entries:Remove(entry)
        self:RemoveSavedEntry(entry.guid)
    end

    -- Refresh filtered view
    if #toRemove > 0 then
        self:ApplyFilter()
        self:TriggerEvent("OnBulkEntriesRemoved", #toRemove, "player", playerName)
        self:TriggerEvent("OnHistoryChanged", "bulk-remove", { count = #toRemove, kind = "player", value = playerName })
    end

    return #toRemove
end

--- Delete entries older than a specified number of days
-- @param days number - Delete entries older than this many days
-- @return number - Number of entries deleted
function HistoryMixin:DeleteByAge(days)
    if not days or days <= 0 then
        return 0
    end

    local cutoffTime = time() - (days * 24 * 60 * 60)
    local toRemove = {}

    -- Collect entries to remove
    for _, entry in self.entries:Enumerate() do
        if (entry.timestamp or 0) < cutoffTime then
            toRemove[#toRemove + 1] = entry
        end
    end

    -- Remove entries
    for _, entry in ipairs(toRemove) do
        self.entries:Remove(entry)
        self:RemoveSavedEntry(entry.guid)
    end

    -- Refresh filtered view
    if #toRemove > 0 then
        self:ApplyFilter()
        self:TriggerEvent("OnBulkEntriesRemoved", #toRemove, "age", days)
        self:TriggerEvent("OnHistoryChanged", "bulk-remove", { count = #toRemove, kind = "age", value = days })
    end

    return #toRemove
end

--- Delete entries for a specific encounter/raid
-- @param encounterName string - Encounter name to delete entries for
-- @return number - Number of entries deleted
function HistoryMixin:DeleteByEncounter(encounterName)
    if not encounterName or encounterName == "" then
        return 0
    end

    local toRemove = {}

    -- Collect entries to remove
    for _, entry in self.entries:Enumerate() do
        if entry.encounterName == encounterName then
            toRemove[#toRemove + 1] = entry
        end
    end

    -- Remove entries
    for _, entry in ipairs(toRemove) do
        self.entries:Remove(entry)
        self:RemoveSavedEntry(entry.guid)
    end

    -- Refresh filtered view
    if #toRemove > 0 then
        self:ApplyFilter()
        self:TriggerEvent("OnBulkEntriesRemoved", #toRemove, "encounter", encounterName)
        self:TriggerEvent("OnHistoryChanged", "bulk-remove", { count = #toRemove, kind = "encounter", value = encounterName })
    end

    return #toRemove
end

--- Delete entries by item quality
-- @param minQuality number - Minimum quality to delete (inclusive)
-- @param maxQuality number - Maximum quality to delete (inclusive, optional)
-- @return number - Number of entries deleted
function HistoryMixin:DeleteByQuality(minQuality, maxQuality)
    if not minQuality then
        return 0
    end

    maxQuality = maxQuality or minQuality
    local toRemove = {}

    -- Collect entries to remove
    for _, entry in self.entries:Enumerate() do
        local quality = entry.quality or 0
        if quality >= minQuality and quality <= maxQuality then
            toRemove[#toRemove + 1] = entry
        end
    end

    -- Remove entries
    for _, entry in ipairs(toRemove) do
        self.entries:Remove(entry)
        self:RemoveSavedEntry(entry.guid)
    end

    -- Refresh filtered view
    if #toRemove > 0 then
        self:ApplyFilter()
        self:TriggerEvent("OnBulkEntriesRemoved", #toRemove, "quality", minQuality)
        self:TriggerEvent("OnHistoryChanged", "bulk-remove", { count = #toRemove, kind = "quality", value = minQuality })
    end

    return #toRemove
end

--- Delete entries within a date range
-- @param startTime number - Start timestamp (inclusive)
-- @param endTime number - End timestamp (inclusive)
-- @return number - Number of entries deleted
function HistoryMixin:DeleteByDateRange(startTime, endTime)
    if not startTime or not endTime then
        return 0
    end

    local toRemove = {}

    -- Collect entries to remove
    for _, entry in self.entries:Enumerate() do
        local timestamp = entry.timestamp or 0
        if timestamp >= startTime and timestamp <= endTime then
            toRemove[#toRemove + 1] = entry
        end
    end

    -- Remove entries
    for _, entry in ipairs(toRemove) do
        self.entries:Remove(entry)
        self:RemoveSavedEntry(entry.guid)
    end

    -- Refresh filtered view
    if #toRemove > 0 then
        self:ApplyFilter()
        self:TriggerEvent("OnBulkEntriesRemoved", #toRemove, "dateRange", startTime)
        self:TriggerEvent("OnHistoryChanged", "bulk-remove", { count = #toRemove, kind = "dateRange", value = startTime })
    end

    return #toRemove
end

--- Get age presets for UI dropdown
-- @return table - Array of { days, label } presets
function HistoryMixin:GetAgePresets()
    return {
        { days = 7, label = "7 days" },
        { days = 14, label = "14 days" },
        { days = 30, label = "30 days" },
        { days = 60, label = "60 days" },
        { days = 90, label = "90 days" },
        { days = 120, label = "120 days" },
        { days = 180, label = "180 days" },
        { days = 365, label = "1 year" },
    }
end

--[[--------------------------------------------------------------------
    Filtering
----------------------------------------------------------------------]]

--- Set filter criteria
-- @param filter table - { searchText, winner, encounterName, startDate, endDate }
function HistoryMixin:SetFilter(filter)
    self.filter = filter or {}
    self:ApplyFilter()
    self:TriggerEvent("OnFilterChanged", self.filter)
end

--- Clear all filters
function HistoryMixin:ClearFilter()
    self.filter = {}
    self:ApplyFilter()
    self:TriggerEvent("OnFilterChanged", self.filter)
end

--- Apply current filter to entries
function HistoryMixin:ApplyFilter()
    self.filteredEntries:Flush()

    for _, entry in self.entries:Enumerate() do
        if self:MatchesFilter(entry) then
            self.filteredEntries:Insert(entry)
        end
    end

    -- Sort by timestamp descending (newest first)
    self.filteredEntries:SetSortComparator(function(a, b)
        return (a.timestamp or 0) > (b.timestamp or 0)
    end)
end

--- Check if entry matches current filter
-- @param entry table
-- @return boolean
function HistoryMixin:MatchesFilter(entry)
    -- Search text (matches item name or winner)
    if self.filter.searchText and self.filter.searchText ~= "" then
        local search = string.lower(self.filter.searchText)
        local matchesName = entry.itemName and string.find(string.lower(entry.itemName), search, 1, true)
        local matchesWinner = entry.winner and string.find(string.lower(entry.winner), search, 1, true)

        if not matchesName and not matchesWinner then
            return false
        end
    end

    -- Winner filter
    if self.filter.winner and self.filter.winner ~= "" then
        if entry.winner ~= self.filter.winner then
            return false
        end
    end

    -- Encounter name filter
    if self.filter.encounterName and self.filter.encounterName ~= "" then
        if entry.encounterName ~= self.filter.encounterName then
            return false
        end
    end

    if self.filter.response and entry.winnerResponse ~= self.filter.response then
        return false
    end

    if self.filter.class and entry.class ~= self.filter.class and entry.winnerClass ~= self.filter.class then
        return false
    end

    -- Date range
    if self.filter.startDate then
        if (entry.timestamp or 0) < self.filter.startDate then
            return false
        end
    end

    if self.filter.endDate then
        if (entry.timestamp or 0) > self.filter.endDate then
            return false
        end
    end

    return true
end

--[[--------------------------------------------------------------------
    Loot Count Queries (for CouncilTable columns)
----------------------------------------------------------------------]]

--- Get the timestamp of the last weekly reset
-- @return number - Unix timestamp of the most recent weekly reset
function HistoryMixin:GetLastWeeklyResetTime()
    local secondsUntil = C_DateAndTime.GetSecondsUntilWeeklyReset()
    return time() + secondsUntil - (7 * 86400)
end

--- Build a per-player count cache for instance+difficulty and weekly scopes
-- Single O(H) pass over all history entries.
-- @param instanceName string|nil - Instance name to match
-- @param difficultyID number|nil - Difficulty ID to match
-- @param weeklyResetTime number - Timestamp of the last weekly reset
-- @return table - { [normalizedPlayerName] = { instance = N, weekly = N } }
function HistoryMixin:BuildPlayerCountCache(instanceName, difficultyID, weeklyResetTime)
    local cache = {}

    for _, entry in self.entries:Enumerate() do
        local winner = entry.winner
        if winner then
            local normalized = Utils.NormalizeName(winner)
            if normalized then
                if not cache[normalized] then
                    cache[normalized] = { instance = 0, weekly = 0 }
                end

                local ts = entry.timestamp or 0

                -- Instance + difficulty match
                if instanceName and difficultyID
                    and entry.instance == instanceName
                    and entry.difficultyID == difficultyID then
                    cache[normalized].instance = cache[normalized].instance + 1
                end

                -- Weekly match
                if ts >= weeklyResetTime then
                    cache[normalized].weekly = cache[normalized].weekly + 1
                end
            end
        end
    end

    return cache
end

--[[--------------------------------------------------------------------
    Statistics
----------------------------------------------------------------------]]

--- Get statistics for a player
-- @param playerName string
-- @return table - { total, byResponse, byQuality }
function HistoryMixin:GetPlayerStats(playerName)
    playerName = Utils.NormalizeName(playerName)

    local stats = {
        total = 0,
        byResponse = {},
        byQuality = {},
    }

    -- Initialize response counts
    for _, response in pairs(Loothing.Response) do
        stats.byResponse[response] = 0
    end

    -- Initialize quality counts
    for quality = 0, 7 do
        stats.byQuality[quality] = 0
    end

    for _, entry in self.entries:Enumerate() do
        if entry.winner == playerName then
            stats.total = stats.total + 1

            if entry.winnerResponse then
                stats.byResponse[entry.winnerResponse] =
                    (stats.byResponse[entry.winnerResponse] or 0) + 1
            end

            if entry.quality then
                stats.byQuality[entry.quality] =
                    (stats.byQuality[entry.quality] or 0) + 1
            end
        end
    end

    return stats
end

--- Get unique winners
-- @return table - Array of winner names
function HistoryMixin:GetUniqueWinners()
    local winners = {}
    local seen = {}

    for _, entry in self.entries:Enumerate() do
        if entry.winner and not seen[entry.winner] then
            seen[entry.winner] = true
            winners[#winners + 1] = entry.winner
        end
    end

    table.sort(winners)
    return winners
end

--- Get unique encounter names
-- @return table - Array of encounter names
function HistoryMixin:GetUniqueEncounters()
    local encounters = {}
    local seen = {}

    for _, entry in self.entries:Enumerate() do
        if entry.encounterName and not seen[entry.encounterName] then
            seen[entry.encounterName] = true
            encounters[#encounters + 1] = entry.encounterName
        end
    end

    table.sort(encounters)
    return encounters
end

--[[--------------------------------------------------------------------
    Persistence
----------------------------------------------------------------------]]

--- Load history from SavedVariables
function HistoryMixin:LoadFromSaved()
    if not Loothing.Settings then
        return
    end

    local saved = Loothing.Settings:GetHistory()
    if not saved then
        return
    end

    for _, entryData in ipairs(saved) do
        local entry = {}
        for k, v in pairs(entryData) do
            entry[k] = v
        end
        entry.guid = entry.guid or Utils.GenerateGUID()
        self.entries:Insert(entry)
    end

    -- Auto-prune entries older than 180 days on load
    self:DeleteByAge(180)
    self:PruneSavedHistory()

    -- Apply initial filter (shows all)
    self:ApplyFilter()
end

--- Save a single entry to SavedVariables
-- @param entry table
function HistoryMixin:SaveEntry(entry)
    if not Loothing.Settings then
        return
    end

    local persistable = {}
    for k, v in pairs(entry) do
        persistable[k] = v
    end
    Loothing.Settings:AddHistoryEntry(persistable)
end

function HistoryMixin:SaveEntries(entries)
    if not Loothing.Settings or not entries or #entries == 0 then
        return
    end

    local persistables = {}
    for _, entry in ipairs(entries) do
        local persistable = {}
        for k, v in pairs(entry) do
            persistable[k] = v
        end
        persistables[#persistables + 1] = persistable
    end

    Loothing.Settings:AddHistoryEntries(persistables)
end

--- Remove a saved entry
-- @param guid string
function HistoryMixin:RemoveSavedEntry(guid)
    if not Loothing.Settings then
        return
    end

    Loothing.Settings:RemoveHistoryEntry(guid)
end

--- Remove multiple saved entries efficiently (O(n) single pass)
-- @param guids table - Set of GUIDs to remove: { [guid] = true }
function HistoryMixin:RemoveSavedEntries(guids)
    if not Loothing.Settings or not guids then
        return
    end

    Loothing.Settings:RemoveHistoryEntries(guids)
end

function HistoryMixin:GetAllEntries()
    local entries = {}
    for _, entry in self.entries:Enumerate() do
        entries[#entries + 1] = entry
    end
    return entries
end

function HistoryMixin:Clear()
    self:ClearHistory()
end

function HistoryMixin:DeleteEntry(guid)
    return self:RemoveEntry(guid)
end

--- Enforce the configured shared history cap in memory and SavedVariables.
function HistoryMixin:PruneSavedHistory()
    if not Loothing.Settings then
        return
    end

    local removedEntries = Loothing.Settings:PruneHistory()
    if #removedEntries == 0 then
        return
    end

    local guidSet = {}
    for _, entry in ipairs(removedEntries) do
        if entry and entry.guid then
            guidSet[entry.guid] = true
        end
    end

    if next(guidSet) == nil then
        return
    end

    local entriesToRemove = {}
    for _, entry in self.entries:Enumerate() do
        if entry.guid and guidSet[entry.guid] then
            entriesToRemove[#entriesToRemove + 1] = entry
        end
    end

    for _, entry in ipairs(entriesToRemove) do
        self.entries:Remove(entry)
    end
end

--[[--------------------------------------------------------------------
    Export
----------------------------------------------------------------------]]

--- Get metadata for export headers
-- @return table - Metadata fields
function HistoryMixin:GetExportMetadata()
    local guildName, guildRank = GetGuildInfo("player")
    return {
        addonName = "Loothing",
        version = Loothing.VERSION,
        exportDate = date("%Y-%m-%d"),
        exportTime = date("%H:%M:%S"),
        -- FIX(Area4-4): Use SafeUnitName to avoid secret value tainting
        playerName = Loolib.SecretUtil.SafeUnitName("player") or "Unknown",
        realmName = GetNormalizedRealmName(),
        guildName = guildName or "",
        guildRank = guildRank or "",
        entryCount = self:GetFilteredCount(),
    }
end

--- Build response definitions from the active response button set.
-- Returns an array of { id, name } for all configured response buttons,
-- allowing the web importer to resolve candidate numeric response IDs
-- to the guild's custom response names without hardcoded mappings.
-- @return table - Array of { id = number, name = string }
function HistoryMixin:GetResponseDefs()
    local defs = {}
    if Loothing.ResponseInfo then
        for id, info in pairs(Loothing.ResponseInfo) do
            if type(id) == "number" and info.name then
                defs[#defs + 1] = { id = id, name = info.name }
            end
        end
        table.sort(defs, function(a, b) return a.id < b.id end)
    end
    return defs
end

--- Format metadata as comment-style header lines
-- @param meta table - From GetExportMetadata()
-- @param prefix string - Line prefix ("# " for CSV/TSV, "-- " for Lua)
-- @return string - Multi-line header (no trailing newline)
function HistoryMixin:FormatCommentHeader(meta, prefix)
    local guildDisplay = (meta.guildName ~= "") and meta.guildName or "N/A"
    local rankDisplay = (meta.guildRank ~= "") and meta.guildRank or "N/A"
    return table.concat({
        prefix .. "Loothing Data Export",
        prefix .. "Version: " .. meta.version,
        prefix .. "Date: " .. meta.exportDate,
        prefix .. "Time: " .. meta.exportTime,
        prefix .. "Character: " .. meta.playerName,
        prefix .. "Realm: " .. meta.realmName,
        prefix .. "Guild: " .. guildDisplay,
        prefix .. "Rank: " .. rankDisplay,
        prefix .. "Entries: " .. meta.entryCount,
    }, "\n")
end

--- Export history to CSV format (23 columns, RCLootCouncil-compatible)
-- @return string
function HistoryMixin:ExportCSV()
    local meta = self:GetExportMetadata()
    local lines = {}

    -- Header (23 columns)
    lines[1] = "player,date,time,id,item,itemID,itemString,response,votes,class,instance,boss,difficultyID,mapID,groupSize,gear1,gear2,responseID,isAwardReason,subType,equipLoc,note,owner"

    -- Escape a value for CSV (quoted, internal quotes doubled)
    local function csv(s)
        if not s then return '""' end
        s = tostring(s):gsub('"', '""')
        return '"' .. s .. '"'
    end

    -- Data rows
    for _, entry in self.filteredEntries:Enumerate() do
        local ts = entry.timestamp or 0
        local dateStr = ts > 0 and date("%Y-%m-%d", ts) or ""
        local timeStr = ts > 0 and date("%H:%M:%S", ts) or ""
        local responseName = ""
        if entry.winnerResponse and Loothing.ResponseInfo and Loothing.ResponseInfo[entry.winnerResponse] then
            responseName = Loothing.ResponseInfo[entry.winnerResponse].name
        end
        local isAwardReason = (entry.awardReasonId and entry.awardReasonId ~= 0) and 1 or 0

        lines[#lines + 1] = table.concat({
            csv(Utils.GetShortName(entry.winner) or ""),
            csv(dateStr),
            csv(timeStr),
            csv(entry.guid or ""),
            csv(entry.itemName or ""),
            tostring(entry.itemID or 0),
            csv(entry.itemLink or ""),
            csv(responseName),
            tostring(entry.votes or 0),
            csv(entry.winnerClass or ""),
            csv(entry.instance or ""),
            csv(entry.encounterName or ""),
            tostring(entry.difficultyID or 0),
            tostring(entry.mapID or 0),
            tostring(entry.groupSize or 0),
            csv(entry.winnerGear1 or ""),
            csv(entry.winnerGear2 or ""),
            tostring(entry.winnerResponse or 0),
            tostring(isAwardReason),
            csv(entry.subType or ""),
            csv(entry.equipSlot or ""),
            csv(entry.winnerNote or ""),
            csv(entry.owner or ""),
        }, ",")
    end

    return self:FormatCommentHeader(meta, "# ") .. "\n" .. table.concat(lines, "\n")
end

--- Export history to TSV format (tab-separated, same columns as CSV)
-- @return string
function HistoryMixin:ExportTSV()
    local meta = self:GetExportMetadata()
    local lines = {}

    -- Header (23 columns, tab-separated)
    lines[1] = "player\tdate\ttime\tid\titem\titemID\titemString\tresponse\tvotes\tclass\tinstance\tboss\tdifficultyID\tmapID\tgroupSize\tgear1\tgear2\tresponseID\tisAwardReason\tsubType\tequipLoc\tnote\towner"

    -- Escape a value for TSV (strip tabs/newlines)
    local function tsv(s)
        if not s then return "" end
        return tostring(s):gsub("\t", " "):gsub("\n", " ")
    end

    -- Data rows
    for _, entry in self.filteredEntries:Enumerate() do
        local ts = entry.timestamp or 0
        local dateStr = ts > 0 and date("%Y-%m-%d", ts) or ""
        local timeStr = ts > 0 and date("%H:%M:%S", ts) or ""
        local responseName = ""
        if entry.winnerResponse and Loothing.ResponseInfo and Loothing.ResponseInfo[entry.winnerResponse] then
            responseName = Loothing.ResponseInfo[entry.winnerResponse].name
        end
        local isAwardReason = (entry.awardReasonId and entry.awardReasonId ~= 0) and 1 or 0

        lines[#lines + 1] = table.concat({
            tsv(Utils.GetShortName(entry.winner) or ""),
            tsv(dateStr),
            tsv(timeStr),
            tsv(entry.guid or ""),
            tsv(entry.itemName or ""),
            tostring(entry.itemID or 0),
            tsv(entry.itemLink or ""),
            tsv(responseName),
            tostring(entry.votes or 0),
            tsv(entry.winnerClass or ""),
            tsv(entry.instance or ""),
            tsv(entry.encounterName or ""),
            tostring(entry.difficultyID or 0),
            tostring(entry.mapID or 0),
            tostring(entry.groupSize or 0),
            tsv(entry.winnerGear1 or ""),
            tsv(entry.winnerGear2 or ""),
            tostring(entry.winnerResponse or 0),
            tostring(isAwardReason),
            tsv(entry.subType or ""),
            tsv(entry.equipSlot or ""),
            tsv(entry.winnerNote or ""),
            tsv(entry.owner or ""),
        }, "\t")
    end

    return self:FormatCommentHeader(meta, "# ") .. "\n" .. table.concat(lines, "\n")
end

--- Export history to Lua table format
-- @return string
function HistoryMixin:ExportLua()
    local meta = self:GetExportMetadata()
    local parts = { "return {" }

    local function esc(s)
        if not s then return "" end
        return tostring(s):gsub('"', '\\"')
    end

    for _, entry in self.filteredEntries:Enumerate() do
        local responseName = ""
        if entry.winnerResponse and Loothing.ResponseInfo and Loothing.ResponseInfo[entry.winnerResponse] then
            responseName = Loothing.ResponseInfo[entry.winnerResponse].name
        end
        local ts = entry.timestamp or 0
        local dateStr = ts > 0 and date("%Y-%m-%d %H:%M:%S", ts) or ""

        parts[#parts + 1] = string.format(
            '    {date="%s", item="%s", itemID=%d, itemLevel=%d, quality=%d, winner="%s", winnerClass="%s",' ..
            ' response="%s", responseID="%s", votes=%d, encounter="%s", instance="%s", difficultyID=%d,' ..
            ' groupSize=%d, gear1="%s", gear2="%s", note="%s", typeCode="%s", subType="%s", owner="%s"},',
            dateStr,
            esc(entry.itemName), entry.itemID or 0, entry.itemLevel or 0, entry.quality or 0,
            esc(entry.winner), esc(entry.winnerClass),
            esc(responseName), tostring(entry.winnerResponse or 0), entry.votes or 0,
            esc(entry.encounterName), esc(entry.instance), entry.difficultyID or 0,
            entry.groupSize or 0,
            esc(entry.winnerGear1), esc(entry.winnerGear2),
            esc(entry.winnerNote), esc(entry.typeCode), esc(entry.subType), esc(entry.owner)
        )
    end

    parts[#parts + 1] = "}"
    return self:FormatCommentHeader(meta, "-- ") .. "\n" .. table.concat(parts, "\n")
end

--- Export history to BBCode format for forums
-- @return string
function HistoryMixin:ExportBBCode()
    local meta = self:GetExportMetadata()
    local guildDisplay = (meta.guildName ~= "") and meta.guildName or "N/A"
    local rankDisplay = (meta.guildRank ~= "") and meta.guildRank or "N/A"
    local lines = {
        "[b]Loothing Data Export[/b]",
        "Version: " .. meta.version,
        "Date: " .. meta.exportDate .. " " .. meta.exportTime,
        "Character: " .. meta.playerName .. " - " .. meta.realmName,
        "Guild: " .. guildDisplay .. " (" .. rankDisplay .. ")",
        "Entries: " .. meta.entryCount,
        "",
    }
    local winners = {}

    -- Group by winner
    for _, entry in self.filteredEntries:Enumerate() do
        local winner = entry.winner or "Unknown"
        if not winners[winner] then
            winners[winner] = {}
        end
        winners[winner][#winners[winner] + 1] = entry
    end

    -- Sort winner names
    local sortedWinners = {}
    for winner in pairs(winners) do
        sortedWinners[#sortedWinners + 1] = winner
    end
    table.sort(sortedWinners)

    -- Format output
    for _, winner in ipairs(sortedWinners) do
        local shortName = Utils.GetShortName(winner)
        local winnerEntries = winners[winner]
        local winnerClass = winnerEntries[1].winnerClass or ""
        local classTag = winnerClass ~= "" and string.format(" [%s]", winnerClass) or ""

        lines[#lines + 1] = string.format("[b]%s%s:[/b]", shortName, classTag)
        lines[#lines + 1] = "[list]"

        for _, entry in ipairs(winnerEntries) do
            local itemName = entry.itemName or "Unknown"
            local responseName = ""
            if entry.winnerResponse and Loothing.ResponseInfo and Loothing.ResponseInfo[entry.winnerResponse] then
                responseName = Loothing.ResponseInfo[entry.winnerResponse].name
            end
            local ilvl = entry.itemLevel and string.format(" (ilvl %d)", entry.itemLevel) or ""
            local instance = entry.instance or entry.encounterName or ""
            local diff = entry.difficultyName or ""
            local context = ""
            if instance ~= "" then
                context = diff ~= "" and string.format(" - %s %s", diff, instance) or string.format(" - %s", instance)
            end

            lines[#lines + 1] = string.format("[*]%s%s - %s%s", itemName, ilvl, responseName, context)
        end

        lines[#lines + 1] = "[/list]"
        lines[#lines + 1] = ""
    end

    return table.concat(lines, "\n")
end

--- Export history to Discord markdown format
-- @return string
function HistoryMixin:ExportDiscord()
    local meta = self:GetExportMetadata()
    local guildDisplay = (meta.guildName ~= "") and meta.guildName or "N/A"
    local rankDisplay = (meta.guildRank ~= "") and meta.guildRank or "N/A"
    local lines = {
        "# Loothing Data Export",
        "**Version:** " .. meta.version .. " | **Exported:** " .. meta.exportDate .. " " .. meta.exportTime,
        "**Character:** " .. meta.playerName .. " - " .. meta.realmName,
        "**Guild:** " .. guildDisplay .. " (" .. rankDisplay .. ")",
        "**Entries:** " .. meta.entryCount,
        "---",
        "",
    }
    local winners = {}

    -- Group by winner
    for _, entry in self.filteredEntries:Enumerate() do
        local winner = entry.winner or "Unknown"
        if not winners[winner] then
            winners[winner] = {}
        end
        winners[winner][#winners[winner] + 1] = entry
    end

    -- Sort winner names
    local sortedWinners = {}
    for winner in pairs(winners) do
        sortedWinners[#sortedWinners + 1] = winner
    end
    table.sort(sortedWinners)

    -- Format output
    for _, winner in ipairs(sortedWinners) do
        local shortName = Utils.GetShortName(winner)
        local winnerEntries = winners[winner]
        local winnerClass = winnerEntries[1].winnerClass or ""
        local classTag = winnerClass ~= "" and string.format(" (%s)", winnerClass) or ""

        lines[#lines + 1] = string.format("**__%s%s:__**", shortName, classTag)

        for _, entry in ipairs(winnerEntries) do
            local itemName = entry.itemName or "Unknown"
            local responseName = ""
            if entry.winnerResponse and Loothing.ResponseInfo and Loothing.ResponseInfo[entry.winnerResponse] then
                responseName = Loothing.ResponseInfo[entry.winnerResponse].name
            end
            local ilvl = entry.itemLevel and string.format(" `ilvl %d`", entry.itemLevel) or ""
            local instance = entry.instance or entry.encounterName or ""
            local diff = entry.difficultyName or ""
            local context = ""
            if instance ~= "" then
                context = diff ~= "" and string.format(" (%s %s)", diff, instance) or string.format(" (%s)", instance)
            end

            lines[#lines + 1] = string.format("- **%s**%s - *%s*%s", itemName, ilvl, responseName, context)
        end

        lines[#lines + 1] = ""
    end

    return table.concat(lines, "\n")
end

local function EscapeJSONStringForExport(value)
    local s = tostring(value)
    s = s:gsub("\\", "\\\\")
    s = s:gsub('"', '\\"')
    s = s:gsub("\b", "\\b")
    s = s:gsub("\f", "\\f")
    s = s:gsub("\n", "\\n")
    s = s:gsub("\r", "\\r")
    s = s:gsub("\t", "\\t")
    -- Raw item links contain pipe codes that WoW EditBoxes interpret as formatting.
    s = s:gsub("|", "\\u007C")
    return s
end

local SerializeCompactJSONValue
SerializeCompactJSONValue = function(value)
    local valueType = type(value)
    if valueType == "nil" then
        return "null"
    elseif valueType == "string" then
        return '"' .. EscapeJSONStringForExport(value) .. '"'
    elseif valueType == "number" or valueType == "boolean" then
        return tostring(value)
    elseif valueType == "table" then
        local parts = {}
        local isArray = (#value > 0) or (next(value) == nil)
        if isArray then
            for _, entry in ipairs(value) do
                parts[#parts + 1] = SerializeCompactJSONValue(entry)
            end
            return "[" .. table.concat(parts, ",") .. "]"
        end

        for key, nestedValue in pairs(value) do
            parts[#parts + 1] = '"' .. EscapeJSONStringForExport(key) .. '":' .. SerializeCompactJSONValue(nestedValue)
        end
        return "{" .. table.concat(parts, ",") .. "}"
    end

    return "null"
end

--- Export history to JSON format (all fields, including candidates and councilVotes arrays)
-- @return string
function HistoryMixin:ExportJSON()
    -- Recursive JSON serializer
    local function toJSON(value, indent)
        indent = indent or ""
        local t = type(value)
        if t == "nil" then
            return "null"
        elseif t == "boolean" then
            return tostring(value)
        elseif t == "number" then
            return tostring(value)
        elseif t == "string" then
            return '"' .. EscapeJSONStringForExport(value) .. '"'
        elseif t == "table" then
            local innerIndent = indent .. "  "
            -- Array if it has an integer key 1 or is empty
            local isArray = (#value > 0) or (next(value) == nil)
            local parts = {}
            if isArray then
                for _, v in ipairs(value) do
                    parts[#parts + 1] = innerIndent .. toJSON(v, innerIndent)
                end
                if #parts == 0 then return "[]" end
                return "[\n" .. table.concat(parts, ",\n") .. "\n" .. indent .. "]"
            else
                local keys = {}
                for k in pairs(value) do keys[#keys + 1] = k end
                table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
                for _, k in ipairs(keys) do
                    parts[#parts + 1] = innerIndent .. '"' .. tostring(k) .. '": ' .. toJSON(value[k], innerIndent)
                end
                if #parts == 0 then return "{}" end
                return "{\n" .. table.concat(parts, ",\n") .. "\n" .. indent .. "}"
            end
        end
        return "null"
    end

    local entries = {}

    for _, entry in self.filteredEntries:Enumerate() do
        local responseName = ""
        if entry.winnerResponse and Loothing.ResponseInfo and Loothing.ResponseInfo[entry.winnerResponse] then
            responseName = Loothing.ResponseInfo[entry.winnerResponse].name
        end
        local ts = entry.timestamp or 0

        entries[#entries + 1] = {
            guid            = entry.guid or "",
            date            = ts > 0 and date("%Y-%m-%d %H:%M:%S", ts) or "",
            timestamp       = ts,
            itemID          = entry.itemID or 0,
            itemLink        = entry.itemLink or "",
            itemName        = entry.itemName or "",
            itemLevel       = entry.itemLevel or 0,
            quality         = entry.quality or 0,
            equipSlot       = entry.equipSlot or "",
            typeCode        = entry.typeCode or "",
            subType         = entry.subType or "",
            bindType        = entry.bindType or 0,
            isBoe           = entry.isBoe or false,
            winner          = entry.winner or "",
            winnerClass     = entry.winnerClass or "",
            response        = responseName,
            responseID      = entry.winnerResponse or 0,
            winnerNote      = entry.winnerNote or "",
            winnerRoll      = entry.winnerRoll or 0,
            winnerGear1     = entry.winnerGear1 or "",
            winnerGear2     = entry.winnerGear2 or "",
            winnerGear1ilvl = entry.winnerGear1ilvl or 0,
            winnerGear2ilvl = entry.winnerGear2ilvl or 0,
            winnerIlvlDiff  = entry.winnerIlvlDiff or 0,
            encounterID     = entry.encounterID or 0,
            encounterName   = entry.encounterName or "",
            instance        = entry.instance or "",
            difficultyID    = entry.difficultyID or 0,
            difficultyName  = entry.difficultyName or "",
            groupSize       = entry.groupSize or 0,
            mapID           = entry.mapID or 0,
            votes           = entry.votes or 0,
            awardReasonId   = entry.awardReasonId or 0,
            awardReason     = entry.awardReason or "",
            owner           = entry.owner or "",
            candidates      = entry.candidates or {},
            councilVotes    = entry.councilVotes or {},
        }
    end

    local meta = self:GetExportMetadata()
    local guildDisplay = (meta.guildName ~= "") and meta.guildName or "N/A"
    local rankDisplay = (meta.guildRank ~= "") and meta.guildRank or "N/A"

    local parts = { "{" }
    parts[#parts + 1] = '  "metadata": ' .. toJSON({
        addon = meta.addonName,
        version = meta.version,
        exportDate = meta.exportDate,
        exportTime = meta.exportTime,
        character = meta.playerName,
        realm = meta.realmName,
        guild = guildDisplay,
        guildRank = rankDisplay,
        entryCount = meta.entryCount,
        responseDefs = self:GetResponseDefs(),
    }, "  ") .. ","
    parts[#parts + 1] = '  "entries": ['
    for i, e in ipairs(entries) do
        local comma = i < #entries and "," or ""
        parts[#parts + 1] = "    " .. toJSON(e, "    ") .. comma
    end
    parts[#parts + 1] = "  ]"
    parts[#parts + 1] = "}"

    return table.concat(parts, "\n")
end

--- Export history as compact (no-indent, no-sort) JSON for web import
-- Faster than ExportJSON: flat string.format template, no recursion, no intermediate tables
-- @return string
function HistoryMixin:ExportCompactJSON()
    local buf = {}

    local meta = self:GetExportMetadata()
    local guildDisplay = (meta.guildName ~= "") and meta.guildName or "N/A"
    local rankDisplay  = (meta.guildRank ~= "") and meta.guildRank or "N/A"

    -- Serialize responseDefs as compact JSON array: [{"id":1,"name":"NEED"},...]
    local responseDefs = self:GetResponseDefs()
    local rdefParts = {}
    for _, def in ipairs(responseDefs) do
        rdefParts[#rdefParts + 1] = string.format('{"id":%d,"name":"%s"}', def.id, EscapeJSONStringForExport(def.name))
    end
    local rdefJson = "[" .. table.concat(rdefParts, ",") .. "]"

    -- Write metadata header + open entries array
    buf[#buf + 1] = string.format(
        '{"metadata":{"addon":"%s","version":"%s","exportDate":"%s","exportTime":"%s","character":"%s","realm":"%s","guild":"%s","guildRank":"%s","entryCount":%d,"responseDefs":%s},"entries":[',
        EscapeJSONStringForExport(meta.addonName), EscapeJSONStringForExport(meta.version),
        EscapeJSONStringForExport(meta.exportDate), EscapeJSONStringForExport(meta.exportTime),
        EscapeJSONStringForExport(meta.playerName), EscapeJSONStringForExport(meta.realmName),
        EscapeJSONStringForExport(guildDisplay), EscapeJSONStringForExport(rankDisplay),
        meta.entryCount, rdefJson
    )

    local first = true
    for _, entry in self.filteredEntries:Enumerate() do
        local responseName = ""
        if entry.winnerResponse and Loothing.ResponseInfo and Loothing.ResponseInfo[entry.winnerResponse] then
            responseName = Loothing.ResponseInfo[entry.winnerResponse].name
        end
        local ts = entry.timestamp or 0
        local dateStr = ts > 0 and date("%Y-%m-%d %H:%M:%S", ts) or ""

        if not first then
            buf[#buf + 1] = ","
        end
        first = false

        -- Fixed template: 35 scalar fields + 2 array fields
        buf[#buf + 1] = string.format(
            '{"guid":"%s","date":"%s","timestamp":%d,"itemID":%d,"itemLink":"%s","itemName":"%s","itemLevel":%d,"quality":%d,"equipSlot":"%s","typeCode":"%s","subType":"%s","bindType":%d,"isBoe":%s,"winner":"%s","winnerClass":"%s","response":"%s","responseID":"%s","winnerNote":"%s","winnerRoll":%d,"winnerGear1":"%s","winnerGear2":"%s","winnerGear1ilvl":%d,"winnerGear2ilvl":%d,"winnerIlvlDiff":%d,"encounterID":%d,"encounterName":"%s","instance":"%s","difficultyID":%d,"difficultyName":"%s","groupSize":%d,"mapID":%d,"votes":%d,"awardReasonId":"%s","awardReason":"%s","owner":"%s","candidates":%s,"councilVotes":%s}',
            EscapeJSONStringForExport(entry.guid or ""),
            EscapeJSONStringForExport(dateStr),
            ts,
            entry.itemID or 0,
            EscapeJSONStringForExport(entry.itemLink or ""),
            EscapeJSONStringForExport(entry.itemName or ""),
            entry.itemLevel or 0,
            entry.quality or 0,
            EscapeJSONStringForExport(entry.equipSlot or ""),
            EscapeJSONStringForExport(entry.typeCode or ""),
            EscapeJSONStringForExport(entry.subType or ""),
            entry.bindType or 0,
            tostring(entry.isBoe or false),
            EscapeJSONStringForExport(entry.winner or ""),
            EscapeJSONStringForExport(entry.winnerClass or ""),
            EscapeJSONStringForExport(responseName),
            tostring(entry.winnerResponse or 0),
            EscapeJSONStringForExport(entry.winnerNote or ""),
            entry.winnerRoll or 0,
            EscapeJSONStringForExport(entry.winnerGear1 or ""),
            EscapeJSONStringForExport(entry.winnerGear2 or ""),
            entry.winnerGear1ilvl or 0,
            entry.winnerGear2ilvl or 0,
            entry.winnerIlvlDiff or 0,
            entry.encounterID or 0,
            EscapeJSONStringForExport(entry.encounterName or ""),
            EscapeJSONStringForExport(entry.instance or ""),
            entry.difficultyID or 0,
            EscapeJSONStringForExport(entry.difficultyName or ""),
            entry.groupSize or 0,
            entry.mapID or 0,
            entry.votes or 0,
            tostring(entry.awardReasonId or 0),
            EscapeJSONStringForExport(entry.awardReason or ""),
            EscapeJSONStringForExport(entry.owner or ""),
            SerializeCompactJSONValue(entry.candidates or {}),
            SerializeCompactJSONValue(entry.councilVotes or {})
        )
    end

    buf[#buf + 1] = "]}"
    return table.concat(buf)
end

--- Export history to EQdkp-Plus XML format
-- @return string
function HistoryMixin:ExportEQdkp()
    local lines = {}

    -- Collect unique zones, bosses, and members
    local zones = {}
    local zoneIndex = {}
    local bosses = {}
    local bossIndex = {}
    local members = {}
    local memberSet = {}

    for _, entry in self.filteredEntries:Enumerate() do
        local zone = entry.instance or entry.encounterName or "Unknown"
        if not zoneIndex[zone] then
            zones[#zones + 1] = zone
            zoneIndex[zone] = #zones
        end

        local boss = entry.encounterName or "Unknown"
        local bossKey = boss .. "_" .. (entry.timestamp or 0)
        if not bossIndex[bossKey] then
            bosses[#bosses + 1] = {
                name = boss,
                time = entry.timestamp or 0,
                zone = zoneIndex[zone]
            }
            bossIndex[bossKey] = #bosses
        end

        local winner = entry.winner
        if winner and not memberSet[winner] then
            memberSet[winner] = true
            members[#members + 1] = winner
        end
    end

    -- Get export metadata
    local meta = self:GetExportMetadata()
    local guildDisplay = (meta.guildName ~= "") and meta.guildName or "N/A"
    local rankDisplay = (meta.guildRank ~= "") and meta.guildRank or "N/A"

    -- XML Header
    lines[#lines + 1] = '<?xml version="1.0" encoding="UTF-8"?>'
    lines[#lines + 1] = '<RaidLog>'

    -- Head section
    lines[#lines + 1] = '    <head>'
    lines[#lines + 1] = '        <export>'
    lines[#lines + 1] = string.format('            <name>%s</name>', "Loothing")
    lines[#lines + 1] = string.format('            <version>%s</version>', Loothing.VERSION)
    lines[#lines + 1] = '        </export>'
    lines[#lines + 1] = '        <tracker>'
    lines[#lines + 1] = '            <name>Loothing Loot Council</name>'
    lines[#lines + 1] = string.format('            <version>%s</version>', Loothing.VERSION)
    lines[#lines + 1] = '        </tracker>'
    lines[#lines + 1] = '        <gameinfo>'
    lines[#lines + 1] = '            <game>World of Warcraft</game>'
    lines[#lines + 1] = '            <language>en</language>'
    lines[#lines + 1] = string.format('            <charactername>%s</charactername>', self:EscapeXML(meta.playerName))
    lines[#lines + 1] = string.format('            <servername>%s</servername>', self:EscapeXML(meta.realmName))
    lines[#lines + 1] = '        </gameinfo>'
    lines[#lines + 1] = '        <exportinfo>'
    lines[#lines + 1] = string.format('            <guild>%s</guild>', self:EscapeXML(guildDisplay))
    lines[#lines + 1] = string.format('            <guildrank>%s</guildrank>', self:EscapeXML(rankDisplay))
    lines[#lines + 1] = string.format('            <exportdate>%s</exportdate>', meta.exportDate)
    lines[#lines + 1] = string.format('            <exporttime>%s</exporttime>', meta.exportTime)
    lines[#lines + 1] = string.format('            <entrycount>%d</entrycount>', meta.entryCount)
    lines[#lines + 1] = '        </exportinfo>'
    lines[#lines + 1] = '    </head>'

    -- Raid data section
    lines[#lines + 1] = '    <raiddata>'

    -- Zones
    lines[#lines + 1] = '        <zones>'
    for i, zone in ipairs(zones) do
        lines[#lines + 1] = string.format('            <zone id="%d" name="%s"/>', i, self:EscapeXML(zone))
    end
    lines[#lines + 1] = '        </zones>'

    -- Boss kills
    lines[#lines + 1] = '        <bosskills>'
    for i, boss in ipairs(bosses) do
        lines[#lines + 1] = string.format('            <bosskill id="%d" name="%s" time="%d" zone="%d"/>',
            i, self:EscapeXML(boss.name), boss.time, boss.zone)
    end
    lines[#lines + 1] = '        </bosskills>'

    -- Members
    lines[#lines + 1] = '        <members>'
    for _, member in ipairs(members) do
        local shortName = Utils.GetShortName(member)
        lines[#lines + 1] = string.format('            <member name="%s"/>', self:EscapeXML(shortName))
    end
    lines[#lines + 1] = '        </members>'

    -- Items
    lines[#lines + 1] = '        <items>'
    for _, entry in self.filteredEntries:Enumerate() do
        local itemID = entry.itemID or 0
        local itemName = entry.itemName or "Unknown"
        local winner = Utils.GetShortName(entry.winner) or "Unknown"
        local timestamp = entry.timestamp or 0
        local votes = entry.votes or 0
        local boss = entry.encounterName or "Unknown"
        local zone = entry.instance or entry.encounterName or "Unknown"

        -- Get response name
        local responseName = ""
        if entry.winnerResponse and Loothing.ResponseInfo and Loothing.ResponseInfo[entry.winnerResponse] then
            responseName = Loothing.ResponseInfo[entry.winnerResponse].name
        end

        lines[#lines + 1] = '            <item>'
        lines[#lines + 1] = string.format('                <itemid>%d</itemid>', itemID)
        lines[#lines + 1] = string.format('                <name>%s</name>', self:EscapeXML(itemName))
        lines[#lines + 1] = string.format('                <member>%s</member>', self:EscapeXML(winner))
        lines[#lines + 1] = string.format('                <time>%d</time>', timestamp)
        lines[#lines + 1] = '                <count>1</count>'
        lines[#lines + 1] = string.format('                <cost>%d</cost>', votes)
        lines[#lines + 1] = string.format('                <note>Response: %s</note>', self:EscapeXML(responseName))
        lines[#lines + 1] = string.format('                <boss>%s</boss>', self:EscapeXML(boss))
        lines[#lines + 1] = string.format('                <zone>%s</zone>', self:EscapeXML(zone))
        lines[#lines + 1] = '            </item>'
    end
    lines[#lines + 1] = '        </items>'

    lines[#lines + 1] = '    </raiddata>'
    lines[#lines + 1] = '</RaidLog>'

    return table.concat(lines, "\n")
end

--- Export history as compact string for web import
-- Format: LOOTHING:1:<base64(zlib(json))>
-- @return string
function HistoryMixin:ExportCompact()
    local jsonStr = self:ExportCompactJSON()
    local compressed = Loolib.Compressor:CompressZlib(jsonStr, 6)
    local encoded = Loolib.Compressor:EncodeForPrint(compressed)
    return "LOOTHING:1:" .. encoded
end

--- Escape special characters for XML
-- @param str string
-- @return string
function HistoryMixin:EscapeXML(str)
    if not str then return "" end

    str = tostring(str)
    str = str:gsub("&", "&amp;")
    str = str:gsub("<", "&lt;")
    str = str:gsub(">", "&gt;")
    str = str:gsub('"', "&quot;")
    str = str:gsub("'", "&apos;")

    return str
end
