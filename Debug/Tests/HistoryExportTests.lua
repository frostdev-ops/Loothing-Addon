--[[--------------------------------------------------------------------
    Loothing - Loot Council Addon for WoW 12.0+
    HistoryExportTests - Regression coverage for JSON and compact export
----------------------------------------------------------------------]]

local _, ns = ...

local TestRunner = ns.TestRunner
local Assert = ns.Assert

local function CreateEnumerator(entries)
    local function iterator(_, index)
        local nextIndex = index + 1
        local entry = entries[nextIndex]
        if entry then
            return nextIndex, entry
        end
    end

    return iterator, nil, 0
end

local function CreateHistory(entries)
    local history = setmetatable({}, { __index = ns.HistoryMixin })
    history.filteredEntries = {
        Enumerate = function()
            return CreateEnumerator(entries)
        end,
    }
    history.GetExportMetadata = function()
        return {
            addonName = "Loothing",
            version = "1.2.3",
            exportDate = "2026-03-11",
            exportTime = "12:00:00",
            playerName = "Tester",
            realmName = "Realm",
            guildName = "Guild",
            guildRank = "Officer",
            entryCount = #entries,
        }
    end
    history.GetResponseDefs = function()
        return {
            { id = 1, name = "Need|Main" },
        }
    end
    return history
end

local RAW_LINK = "|cff0070dd|Hitem:12345::::::::80:::::|h[Test Item]|h|r"

TestRunner:Describe("History Export", function()
    TestRunner:It("escapes raw pipe codes in pretty JSON export", function()
        local history = CreateHistory({
            {
                guid = "guid-1",
                timestamp = 1709900000,
                itemID = 12345,
                itemLink = RAW_LINK,
                itemName = "Test Item",
                winner = "Winner-Realm",
                winnerGear1 = RAW_LINK,
                candidates = {
                    { name = "Winner-Realm", gear1Link = RAW_LINK },
                },
                councilVotes = {
                    { voter = "Council-Realm", responses = { 1, 2 }, note = RAW_LINK },
                },
            },
        })

        local json = history:ExportJSON()

        Assert.IsNil(json:find("|", 1, true), "Pretty JSON export should not contain raw pipe codes")
        Assert.Matches(json, '"itemLink": "\\u007Ccff0070dd')
        Assert.Matches(json, '"winnerGear1": "\\u007Ccff0070dd')
        Assert.Matches(json, '"responses": %[')
    end, { category = "unit" })

    TestRunner:It("preserves nested arrays and itemLink in compact JSON export", function()
        local history = CreateHistory({
            {
                guid = "guid-1",
                timestamp = 1709900000,
                itemID = 12345,
                itemLink = RAW_LINK,
                itemName = "Test Item",
                winner = "Winner-Realm",
                winnerGear1 = RAW_LINK,
                councilVotes = {
                    { voter = "Council-Realm", responses = { 1, 2 }, note = "ranked" },
                },
            },
        })

        local json = history:ExportCompactJSON()

        Assert.IsNil(json:find("|", 1, true), "Compact JSON export should not contain raw pipe codes")
        Assert.Matches(json, '"itemLink":"\\u007Ccff0070dd')
        Assert.Matches(json, '"responses":%[1,2%]')
    end, { category = "unit" })
end)
