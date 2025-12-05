--[[--------------------------------------------------------------------
    Loothing - Loot Council Addon for WoW 12.0+
    History - Loot history storage and retrieval
----------------------------------------------------------------------]]

local Loolib = LibStub("Loolib")

--[[--------------------------------------------------------------------
    LoothingHistoryMixin
----------------------------------------------------------------------]]

LoothingHistoryMixin = LoolibCreateFromMixins(LoolibCallbackRegistryMixin)

local HISTORY_EVENTS = {
    "OnEntryAdded",
    "OnEntryRemoved",
    "OnHistoryCleared",
    "OnFilterChanged",
}

--- Initialize history manager
function LoothingHistoryMixin:Init()
    LoolibCallbackRegistryMixin.OnLoad(self)
    self:GenerateCallbackEvents(HISTORY_EVENTS)

    -- Data provider for history entries
    local Data = Loolib:GetModule("Data")
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

    -- Load from SavedVariables
    self:LoadFromSaved()
end

--[[--------------------------------------------------------------------
    Entry Management
----------------------------------------------------------------------]]

--- Add a history entry
-- @param entry table - { itemLink, winner, winnerResponse, encounterID, encounterName, votes, timestamp }
function LoothingHistoryMixin:AddEntry(entry)
    -- Ensure required fields
    entry.timestamp = entry.timestamp or time()
    entry.guid = entry.guid or LoothingUtils.GenerateGUID()

    -- Parse item info if not present
    if entry.itemLink and not entry.itemName then
        local itemInfo = LoothingUtils.GetItemInfo(entry.itemLink)
        if itemInfo then
            entry.itemName = itemInfo.name
            entry.itemID = itemInfo.itemID
            entry.itemLevel = itemInfo.itemLevel
            entry.quality = itemInfo.quality
        end
    end

    -- Add to data provider
    self.entries:Insert(entry)

    -- Save to SavedVariables
    self:SaveEntry(entry)

    -- Refresh filtered view
    self:ApplyFilter()

    self:TriggerEvent("OnEntryAdded", entry)
end

--- Remove a history entry
-- @param guid string
-- @return boolean
function LoothingHistoryMixin:RemoveEntry(guid)
    local entry = self:GetEntryByGUID(guid)
    if not entry then
        return false
    end

    self.entries:Remove(entry)

    -- Remove from SavedVariables
    self:RemoveSavedEntry(guid)

    -- Refresh filtered view
    self:ApplyFilter()

    self:TriggerEvent("OnEntryRemoved", entry)
    return true
end

--- Get entry by GUID
-- @param guid string
-- @return table|nil
function LoothingHistoryMixin:GetEntryByGUID(guid)
    for _, entry in self.entries:Enumerate() do
        if entry.guid == guid then
            return entry
        end
    end
    return nil
end

--- Get all entries
-- @return DataProvider
function LoothingHistoryMixin:GetEntries()
    return self.entries
end

--- Get filtered entries
-- @return DataProvider
function LoothingHistoryMixin:GetFilteredEntries()
    return self.filteredEntries
end

--- Get entry count
-- @return number
function LoothingHistoryMixin:GetCount()
    return self.entries:GetSize()
end

--- Get filtered count
-- @return number
function LoothingHistoryMixin:GetFilteredCount()
    return self.filteredEntries:GetSize()
end

--- Clear all history
function LoothingHistoryMixin:ClearHistory()
    self.entries:Flush()
    self.filteredEntries:Flush()

    -- Clear SavedVariables
    if Loothing.Settings then
        Loothing.Settings:ClearHistory()
    end

    self:TriggerEvent("OnHistoryCleared")
end

--[[--------------------------------------------------------------------
    Filtering
----------------------------------------------------------------------]]

--- Set filter criteria
-- @param filter table - { searchText, winner, encounterName, startDate, endDate }
function LoothingHistoryMixin:SetFilter(filter)
    self.filter = filter or {}
    self:ApplyFilter()
    self:TriggerEvent("OnFilterChanged", self.filter)
end

--- Clear all filters
function LoothingHistoryMixin:ClearFilter()
    self.filter = {}
    self:ApplyFilter()
    self:TriggerEvent("OnFilterChanged", self.filter)
end

--- Apply current filter to entries
function LoothingHistoryMixin:ApplyFilter()
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
function LoothingHistoryMixin:MatchesFilter(entry)
    -- Search text (matches item name or winner)
    if self.filter.searchText and self.filter.searchText ~= "" then
        local search = self.filter.searchText:lower()
        local matchesName = entry.itemName and entry.itemName:lower():find(search, 1, true)
        local matchesWinner = entry.winner and entry.winner:lower():find(search, 1, true)

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
    Statistics
----------------------------------------------------------------------]]

--- Get statistics for a player
-- @param playerName string
-- @return table - { total, byResponse, byQuality }
function LoothingHistoryMixin:GetPlayerStats(playerName)
    playerName = LoothingUtils.NormalizeName(playerName)

    local stats = {
        total = 0,
        byResponse = {},
        byQuality = {},
    }

    -- Initialize response counts
    for _, response in pairs(LOOTHING_RESPONSE) do
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
function LoothingHistoryMixin:GetUniqueWinners()
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
function LoothingHistoryMixin:GetUniqueEncounters()
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
function LoothingHistoryMixin:LoadFromSaved()
    if not Loothing.Settings then
        return
    end

    local saved = Loothing.Settings:GetHistory()
    if not saved then
        return
    end

    for _, entryData in ipairs(saved) do
        -- Create entry from saved data
        local entry = {
            guid = entryData.guid or LoothingUtils.GenerateGUID(),
            itemLink = entryData.itemLink,
            itemID = entryData.itemID,
            itemName = entryData.itemName,
            itemLevel = entryData.itemLevel,
            quality = entryData.quality,
            winner = entryData.winner,
            winnerResponse = entryData.winnerResponse,
            encounterID = entryData.encounterID,
            encounterName = entryData.encounterName,
            votes = entryData.votes,
            timestamp = entryData.timestamp,
        }

        self.entries:Insert(entry)
    end

    -- Apply initial filter (shows all)
    self:ApplyFilter()
end

--- Save a single entry to SavedVariables
-- @param entry table
function LoothingHistoryMixin:SaveEntry(entry)
    if not Loothing.Settings then
        return
    end

    Loothing.Settings:AddHistoryEntry({
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
    })
end

--- Remove a saved entry
-- @param guid string
function LoothingHistoryMixin:RemoveSavedEntry(guid)
    if not Loothing.Settings then
        return
    end

    local history = Loothing.Settings:GetHistory()
    for i, entry in ipairs(history) do
        if entry.guid == guid then
            table.remove(history, i)
            break
        end
    end
end

--[[--------------------------------------------------------------------
    Export
----------------------------------------------------------------------]]

--- Export history to CSV format
-- @return string
function LoothingHistoryMixin:ExportCSV()
    local lines = {}

    -- Header
    lines[1] = "Date,Item,Winner,Response,Encounter,Votes"

    -- Data rows
    for _, entry in self.filteredEntries:Enumerate() do
        local date = entry.timestamp and LoothingUtils.FormatDate(entry.timestamp) or ""
        local item = entry.itemName or "Unknown"
        local winner = LoothingUtils.GetShortName(entry.winner) or ""
        local response = ""
        if entry.winnerResponse and LOOTHING_RESPONSE_INFO[entry.winnerResponse] then
            response = LOOTHING_RESPONSE_INFO[entry.winnerResponse].name
        end
        local encounter = entry.encounterName or ""
        local votes = entry.votes or 0

        -- Escape commas in fields
        item = item:gsub(",", ";")
        encounter = encounter:gsub(",", ";")

        lines[#lines + 1] = string.format('"%s","%s","%s","%s","%s",%d',
            date, item, winner, response, encounter, votes)
    end

    return table.concat(lines, "\n")
end

--- Export history to Lua table format
-- @return string
function LoothingHistoryMixin:ExportLua()
    local entries = {}

    for _, entry in self.filteredEntries:Enumerate() do
        entries[#entries + 1] = {
            date = entry.timestamp and LoothingUtils.FormatDate(entry.timestamp),
            itemLink = entry.itemLink,
            itemName = entry.itemName,
            itemLevel = entry.itemLevel,
            winner = entry.winner,
            response = entry.winnerResponse and LOOTHING_RESPONSE_INFO[entry.winnerResponse] and
                       LOOTHING_RESPONSE_INFO[entry.winnerResponse].name,
            encounter = entry.encounterName,
            votes = entry.votes,
        }
    end

    -- Simple serialization
    local parts = { "return {" }

    for _, e in ipairs(entries) do
        parts[#parts + 1] = string.format(
            '    {date="%s", item="%s", winner="%s", response="%s", encounter="%s", votes=%d},',
            e.date or "", e.itemName or "", e.winner or "", e.response or "", e.encounter or "", e.votes or 0
        )
    end

    parts[#parts + 1] = "}"

    return table.concat(parts, "\n")
end

--- Export history to BBCode format for forums
-- @return string
function LoothingHistoryMixin:ExportBBCode()
    local lines = {}
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
        local shortName = LoothingUtils.GetShortName(winner)
        lines[#lines + 1] = string.format("[b]%s:[/b]", shortName)
        lines[#lines + 1] = "[list]"

        for _, entry in ipairs(winners[winner]) do
            local itemName = entry.itemName or "Unknown"
            local responseName = ""
            if entry.winnerResponse and LOOTHING_RESPONSE_INFO[entry.winnerResponse] then
                responseName = LOOTHING_RESPONSE_INFO[entry.winnerResponse].name
            end

            lines[#lines + 1] = string.format("[*]%s - Response: %s", itemName, responseName)
        end

        lines[#lines + 1] = "[/list]"
        lines[#lines + 1] = ""
    end

    return table.concat(lines, "\n")
end

--- Export history to Discord markdown format
-- @return string
function LoothingHistoryMixin:ExportDiscord()
    local lines = {}
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
        local shortName = LoothingUtils.GetShortName(winner)
        lines[#lines + 1] = string.format("**__%s:__**", shortName)

        for _, entry in ipairs(winners[winner]) do
            local itemName = entry.itemName or "Unknown"
            local responseName = ""
            if entry.winnerResponse and LOOTHING_RESPONSE_INFO[entry.winnerResponse] then
                responseName = LOOTHING_RESPONSE_INFO[entry.winnerResponse].name
            end

            lines[#lines + 1] = string.format("- **%s** - Response: *%s*", itemName, responseName)
        end

        lines[#lines + 1] = ""
    end

    return table.concat(lines, "\n")
end

--- Export history to JSON format
-- @return string
function LoothingHistoryMixin:ExportJSON()
    local entries = {}

    for _, entry in self.filteredEntries:Enumerate() do
        local responseName = ""
        if entry.winnerResponse and LOOTHING_RESPONSE_INFO[entry.winnerResponse] then
            responseName = LOOTHING_RESPONSE_INFO[entry.winnerResponse].name
        end

        entries[#entries + 1] = {
            date = entry.timestamp and LoothingUtils.FormatDate(entry.timestamp) or "",
            timestamp = entry.timestamp or 0,
            itemID = entry.itemID or 0,
            itemName = entry.itemName or "",
            itemLevel = entry.itemLevel or 0,
            quality = entry.quality or 1,
            winner = entry.winner or "",
            response = responseName,
            encounterID = entry.encounterID or 0,
            encounterName = entry.encounterName or "",
            votes = entry.votes or 0,
        }
    end

    -- Simple JSON serialization
    local parts = { "[" }

    for i, e in ipairs(entries) do
        local isLast = i == #entries
        local comma = isLast and "" or ","

        -- Escape strings for JSON
        local function escape(s)
            s = s:gsub("\\", "\\\\")
            s = s:gsub('"', '\\"')
            s = s:gsub("\n", "\\n")
            s = s:gsub("\r", "\\r")
            s = s:gsub("\t", "\\t")
            return s
        end

        parts[#parts + 1] = string.format(
            '  {"date":"%s","timestamp":%d,"itemID":%d,"itemName":"%s","itemLevel":%d,"quality":%d,"winner":"%s","response":"%s","encounterID":%d,"encounterName":"%s","votes":%d}%s',
            escape(e.date), e.timestamp, e.itemID, escape(e.itemName), e.itemLevel, e.quality,
            escape(e.winner), escape(e.response), e.encounterID, escape(e.encounterName), e.votes, comma
        )
    end

    parts[#parts + 1] = "]"

    return table.concat(parts, "\n")
end
