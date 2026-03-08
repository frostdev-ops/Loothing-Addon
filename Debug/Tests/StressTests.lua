--[[--------------------------------------------------------------------
    Loothing - Loot Council Addon for WoW 12.0+
    StressTests - Performance and stress tests
----------------------------------------------------------------------]]

--[[--------------------------------------------------------------------
    Test Infrastructure
----------------------------------------------------------------------]]

local StressTests = {
    name = "Stress Tests",
    tests = {},
    results = {},
    currentTest = nil,
    performanceThresholds = {
        critical = 16,      -- 16ms = 60fps target
        acceptable = 100,   -- 100ms general operations
        slow = 500,         -- 500ms bulk operations
    },
}

-- Performance metrics
local PerfMetrics = {
    name = nil,
    operations = 0,
    totalTime = 0,
    minTime = math.huge,
    maxTime = 0,
    avgTime = 0,
    threshold = 100,
    exceeded = false,
}

--- Create new performance metrics
local function NewPerfMetrics(name, threshold)
    return {
        name = name,
        operations = 0,
        totalTime = 0,
        minTime = math.huge,
        maxTime = 0,
        avgTime = 0,
        threshold = threshold or 100,
        exceeded = false,
        samples = {},
    }
end

--- Record operation time
local function RecordOp(metrics, duration)
    metrics.operations = metrics.operations + 1
    metrics.totalTime = metrics.totalTime + duration
    metrics.minTime = math.min(metrics.minTime, duration)
    metrics.maxTime = math.max(metrics.maxTime, duration)
    metrics.avgTime = metrics.totalTime / metrics.operations
    table.insert(metrics.samples, duration)

    if duration > metrics.threshold then
        metrics.exceeded = true
    end
end

--- Finalize and print metrics
local function PrintMetrics(metrics)
    local status = metrics.exceeded and "|cffff0000SLOW|r" or "|cff00ff00FAST|r"
    print(string.format("  %s: %s", metrics.name, status))
    print(string.format("    Operations: %d", metrics.operations))
    print(string.format("    Total: %.2fms", metrics.totalTime))
    print(string.format("    Min: %.2fms", metrics.minTime))
    print(string.format("    Max: %.2fms", metrics.maxTime))
    print(string.format("    Avg: %.2fms", metrics.avgTime))
    print(string.format("    Threshold: %.2fms", metrics.threshold))

    -- Calculate percentiles
    if #metrics.samples > 0 then
        table.sort(metrics.samples)
        local p50 = metrics.samples[math.ceil(#metrics.samples * 0.50)]
        local p95 = metrics.samples[math.ceil(#metrics.samples * 0.95)]
        local p99 = metrics.samples[math.ceil(#metrics.samples * 0.99)]
        print(string.format("    P50: %.2fms, P95: %.2fms, P99: %.2fms", p50, p95, p99))
    end
end

--- Assert helper
local function Assert(condition, message)
    if not condition then
        local errorMsg = message or "Assertion failed"
        error(errorMsg, 2)
    end
end

--- Assert performance within threshold
local function AssertPerf(metrics, message)
    if metrics.exceeded then
        local errorMsg = string.format("%s: max %.2fms exceeded threshold %.2fms",
            message or "Performance threshold exceeded",
            metrics.maxTime, metrics.threshold)
        error(errorMsg, 2)
    end
end

--[[--------------------------------------------------------------------
    Test Helper Functions
----------------------------------------------------------------------]]

--- Setup test environment
local function SetupTest()
    -- Enable test mode
    if LoothingTestMode and not LoothingTestMode:IsEnabled() then
        LoothingTestMode:SetEnabled(true)
    end

    -- Clear any existing session
    if Loothing.Session and Loothing.Session:IsActive() then
        Loothing.Session:EndSession()
    end

    -- Clear history
    if Loothing.History then
        Loothing.History:Clear()
    end

    -- Force garbage collection
    collectgarbage("collect")
end

--- Teardown test environment
local function TeardownTest()
    if Loothing.Session and Loothing.Session:IsActive() then
        Loothing.Session:EndSession()
    end
    collectgarbage("collect")
end

--- Measure execution time
local function Measure(func)
    local startTime = debugprofilestop()
    func()
    return debugprofilestop() - startTime
end

--- Generate large test data
local function GenerateLargeItemSet(count)
    local items = {}
    local testItemIDs = {
        19019, 17182, 22691, 32837, 34334,
        16922, 16925, 19375, 21126, 30905,
    }

    for i = 1, count do
        local itemID = testItemIDs[((i - 1) % #testItemIDs) + 1]
        local itemLink = LoothingTestMode:GenerateFakeItemLink(itemID)
        table.insert(items, itemLink)
    end

    return items
end

--[[--------------------------------------------------------------------
    1. Large Item Count Tests
----------------------------------------------------------------------]]

--- Test: 50 items in session
local function Test_FiftyItemSession()
    SetupTest()

    local metrics = NewPerfMetrics("50 Item Session", StressTests.performanceThresholds.acceptable)

    Loothing.Session:StartSession(0, "Stress Test")

    local itemLinks = GenerateLargeItemSet(50)
    local looter = LoothingUtils.GetPlayerFullName()

    -- Measure adding each item
    for _, itemLink in ipairs(itemLinks) do
        local duration = Measure(function()
            Loothing.Session:AddItem(itemLink, looter)
        end)
        RecordOp(metrics, duration)
    end

    PrintMetrics(metrics)
    AssertPerf(metrics, "Adding 50 items should be fast")

    -- Verify all items added
    local count = 0
    for _ in Loothing.Session.items:Enumerate() do
        count = count + 1
    end
    Assert(count == 50, "All 50 items should be added")

    Loothing.Session:EndSession()
    TeardownTest()
end

--- Test: 100 items in session
local function Test_HundredItemSession()
    SetupTest()

    local metrics = NewPerfMetrics("100 Item Session", StressTests.performanceThresholds.slow)

    Loothing.Session:StartSession(0, "Stress Test")

    local itemLinks = GenerateLargeItemSet(100)
    local looter = LoothingUtils.GetPlayerFullName()

    for _, itemLink in ipairs(itemLinks) do
        local duration = Measure(function()
            Loothing.Session:AddItem(itemLink, looter)
        end)
        RecordOp(metrics, duration)
    end

    PrintMetrics(metrics)

    -- Don't assert on performance for 100 items (may be slow)
    -- Just report metrics

    local count = 0
    for _ in Loothing.Session.items:Enumerate() do
        count = count + 1
    end
    Assert(count == 100, "All 100 items should be added")

    Loothing.Session:EndSession()
    TeardownTest()
end

--- Test: DataProvider performance with large sets
local function Test_DataProviderLargeSets()
    SetupTest()

    local Loolib = LibStub("Loolib")
    local Data = Loolib:GetModule("Data")
    local provider = Data.CreateDataProvider()

    local addMetrics = NewPerfMetrics("DataProvider Insert", StressTests.performanceThresholds.critical)
    local enumMetrics = NewPerfMetrics("DataProvider Enumerate", StressTests.performanceThresholds.acceptable)

    -- Add 1000 items
    for i = 1, 1000 do
        local duration = Measure(function()
            provider:Insert({ id = i, value = "Item " .. i })
        end)
        RecordOp(addMetrics, duration)
    end

    PrintMetrics(addMetrics)

    -- Enumerate all items
    local duration = Measure(function()
        local count = 0
        for item in provider:Enumerate() do
            count = count + 1
        end
    end)
    RecordOp(enumMetrics, duration)

    PrintMetrics(enumMetrics)

    TeardownTest()
end

--[[--------------------------------------------------------------------
    2. Large Raid Size Tests
----------------------------------------------------------------------]]

--- Test: 40-player raid simulation
local function Test_FortyPlayerRaid()
    SetupTest()

    -- Generate 40 fake council members
    LoothingTestMode:GenerateFakeCouncil(40)

    local councilMembers = LoothingTestMode:GetFakeCouncilMembers()
    Assert(#councilMembers >= 40, "Should have 40 council members")

    Loothing.Session:StartSession(0, "40-Player Raid")

    local item = LoothingTestMode:CreateFakeItem()
    item:SetState(LOOTHING_ITEM_STATE.VOTING)

    local voteMetrics = NewPerfMetrics("Vote Processing (40 voters)", StressTests.performanceThresholds.acceptable)

    -- All 40 players vote
    for i = 2, #councilMembers do
        local member = councilMembers[i]
        local responses = { LOOTHING_RESPONSE.NEED }

        local duration = Measure(function()
            item:AddVote(member.name, member.class, responses)
        end)
        RecordOp(voteMetrics, duration)
    end

    PrintMetrics(voteMetrics)
    AssertPerf(voteMetrics, "Vote processing should be fast")

    -- Tally votes
    local tallyMetrics = NewPerfMetrics("Vote Tally (40 voters)", StressTests.performanceThresholds.acceptable)
    local duration = Measure(function()
        item:TallyVotes()
    end)
    RecordOp(tallyMetrics, duration)

    PrintMetrics(tallyMetrics)
    AssertPerf(tallyMetrics, "Vote tallying should be fast")

    Loothing.Session:EndSession()
    TeardownTest()
end

--[[--------------------------------------------------------------------
    3. Rapid Operations Tests
----------------------------------------------------------------------]]

--- Test: 100 votes in quick succession
local function Test_RapidVotes()
    SetupTest()

    Loothing.Session:StartSession(0, "Rapid Test")
    local item = LoothingTestMode:CreateFakeItem()
    item:SetState(LOOTHING_ITEM_STATE.VOTING)

    local metrics = NewPerfMetrics("Rapid Vote Processing", StressTests.performanceThresholds.critical)

    -- Generate 100 unique voters
    for i = 1, 100 do
        local voterName = string.format("Player%d-Realm", i)
        local voterClass = "WARRIOR"

        local duration = Measure(function()
            item:AddVote(voterName, voterClass, { LOOTHING_RESPONSE.NEED })
        end)
        RecordOp(metrics, duration)
    end

    PrintMetrics(metrics)
    AssertPerf(metrics, "Rapid vote processing should be under 16ms per vote")

    Loothing.Session:EndSession()
    TeardownTest()
end

--- Test: 50 items added rapidly
local function Test_RapidItemAdds()
    SetupTest()

    Loothing.Session:StartSession(0, "Rapid Test")

    local itemLinks = GenerateLargeItemSet(50)
    local looter = LoothingUtils.GetPlayerFullName()

    local metrics = NewPerfMetrics("Rapid Item Addition", StressTests.performanceThresholds.critical)

    for _, itemLink in ipairs(itemLinks) do
        local duration = Measure(function()
            Loothing.Session:AddItem(itemLink, looter)
        end)
        RecordOp(metrics, duration)
    end

    PrintMetrics(metrics)
    AssertPerf(metrics, "Rapid item addition should be under 16ms per item")

    Loothing.Session:EndSession()
    TeardownTest()
end

--- Test: State changes in tight loop
local function Test_RapidStateChanges()
    SetupTest()

    Loothing.Session:StartSession(0, "State Test")

    local metrics = NewPerfMetrics("State Changes", StressTests.performanceThresholds.critical)

    for i = 1, 20 do
        local item = LoothingTestMode:CreateFakeItem()

        local duration = Measure(function()
            item:SetState(LOOTHING_ITEM_STATE.PENDING)
            item:SetState(LOOTHING_ITEM_STATE.VOTING)
            item:SetState(LOOTHING_ITEM_STATE.TALLIED)
            item:SetState(LOOTHING_ITEM_STATE.AWARDED)
        end)
        RecordOp(metrics, duration)
    end

    PrintMetrics(metrics)
    AssertPerf(metrics, "State changes should be fast")

    Loothing.Session:EndSession()
    TeardownTest()
end

--[[--------------------------------------------------------------------
    4. Memory Tests
----------------------------------------------------------------------]]

--- Test: Session start/end cycles (no leaks)
local function Test_SessionCycles()
    SetupTest()

    local startMemory = collectgarbage("count")

    -- Run 50 session cycles
    for i = 1, 50 do
        Loothing.Session:StartSession(0, "Memory Test " .. i)

        -- Add a few items
        for j = 1, 5 do
            LoothingTestMode:CreateFakeItem()
        end

        Loothing.Session:EndSession()

        -- Force GC every 10 cycles
        if i % 10 == 0 then
            collectgarbage("collect")
        end
    end

    collectgarbage("collect")
    local endMemory = collectgarbage("count")

    local memoryDelta = endMemory - startMemory

    print(string.format("  Memory: Start %.2f KB, End %.2f KB, Delta %.2f KB",
        startMemory, endMemory, memoryDelta))

    -- Allow up to 500KB growth (should be minimal after GC)
    Assert(memoryDelta < 500, "Memory growth should be minimal after 50 session cycles")

    TeardownTest()
end

--- Test: Item creation/destruction cycles
local function Test_ItemCreationCycles()
    SetupTest()

    Loothing.Session:StartSession(0, "Item Memory Test")

    local startMemory = collectgarbage("count")

    -- Create and destroy 100 items
    for i = 1, 100 do
        local item = LoothingTestMode:CreateFakeItem()
        Loothing.Session:RemoveItem(item.guid)

        if i % 20 == 0 then
            collectgarbage("collect")
        end
    end

    collectgarbage("collect")
    local endMemory = collectgarbage("count")

    local memoryDelta = endMemory - startMemory

    print(string.format("  Memory: Start %.2f KB, End %.2f KB, Delta %.2f KB",
        startMemory, endMemory, memoryDelta))

    Assert(memoryDelta < 200, "Memory should not grow significantly")

    Loothing.Session:EndSession()
    TeardownTest()
end

--- Test: Vote accumulation (no unbounded growth)
local function Test_VoteAccumulation()
    SetupTest()

    Loothing.Session:StartSession(0, "Vote Memory Test")

    local item = LoothingTestMode:CreateFakeItem()
    item:SetState(LOOTHING_ITEM_STATE.VOTING)

    local startMemory = collectgarbage("count")

    -- Add 500 votes
    for i = 1, 500 do
        local voterName = string.format("Voter%d-Realm", i)
        item:AddVote(voterName, "WARRIOR", { LOOTHING_RESPONSE.NEED })
    end

    local endMemory = collectgarbage("count")
    local memoryDelta = endMemory - startMemory

    print(string.format("  Memory for 500 votes: %.2f KB", memoryDelta))

    -- 500 votes should use reasonable memory (< 100KB)
    Assert(memoryDelta < 100, "Vote storage should be memory efficient")

    Loothing.Session:EndSession()
    TeardownTest()
end

--[[--------------------------------------------------------------------
    5. Message Volume Tests
----------------------------------------------------------------------]]

--- Test: 100 messages encoded/decoded
local function Test_MessageEncodeDecode()
    if not Loothing.Comm then
        print("|cffffcc00[Stress Test]|r Comm module not available, skipping test")
        return
    end

    SetupTest()

    local encodeMetrics = NewPerfMetrics("Message Encoding", StressTests.performanceThresholds.critical)
    local decodeMetrics = NewPerfMetrics("Message Decoding", StressTests.performanceThresholds.critical)

    for i = 1, 100 do
        local data = {
            sessionID = i,
            itemGUID = "Item-" .. i,
            response = LOOTHING_RESPONSE.NEED,
            timestamp = GetTime(),
        }

        -- Encode (Serialize → Compress → EncodeForAddonChannel)
        local encoded
        local encodeDuration = Measure(function()
            encoded = LoothingProtocol:Encode(LOOTHING_MSG_TYPE.VOTE_COMMIT, data)
        end)
        RecordOp(encodeMetrics, encodeDuration)

        -- Decode (DecodeForAddonChannel → Decompress → Deserialize)
        local decodeDuration = Measure(function()
            local version, command, decodedData = LoothingProtocol:Decode(encoded)
        end)
        RecordOp(decodeMetrics, decodeDuration)
    end

    PrintMetrics(encodeMetrics)
    PrintMetrics(decodeMetrics)

    AssertPerf(encodeMetrics, "Message encoding should be fast")
    AssertPerf(decodeMetrics, "Message decoding should be fast")

    TeardownTest()
end

--- Test: Large payload handling
local function Test_LargePayload()
    if not Loothing.Comm then
        print("|cffffcc00[Stress Test]|r Comm module not available, skipping test")
        return
    end

    SetupTest()

    -- Create a large payload (simulating full session sync)
    local largeData = {
        sessionID = 12345,
        encounterID = 999,
        items = {},
        history = {},
    }

    -- Add 50 items to payload
    for i = 1, 50 do
        largeData.items[i] = {
            guid = "Item-" .. i,
            link = string.format("|cffa335ee|Hitem:%d|h[Item %d]|h|r", 19019 + i, i),
            state = LOOTHING_ITEM_STATE.AWARDED,
            votes = {},
        }
    end

    local metrics = NewPerfMetrics("Large Payload Encoding", StressTests.performanceThresholds.acceptable)

    local duration = Measure(function()
        local encoded = LoothingProtocol:Encode(LOOTHING_MSG_TYPE.SYNC_DATA, largeData)
    end)
    RecordOp(metrics, duration)

    PrintMetrics(metrics)

    TeardownTest()
end

--[[--------------------------------------------------------------------
    6. History Tests
----------------------------------------------------------------------]]

--- Test: 1000 history entries
local function Test_ThousandHistoryEntries()
    if not Loothing.History then
        print("|cffffcc00[Stress Test]|r History module not available, skipping test")
        return
    end

    SetupTest()

    Loothing.History:Clear()

    local addMetrics = NewPerfMetrics("History Entry Addition", StressTests.performanceThresholds.critical)

    -- Add 1000 entries
    for i = 1, 1000 do
        local entry = {
            timestamp = time(),
            sessionID = math.floor(i / 10),
            encounterName = "Test Boss",
            itemLink = string.format("|cffa335ee|Hitem:%d|h[Item %d]|h|r", 19019, i),
            winner = string.format("Player%d-Realm", i),
            response = LOOTHING_RESPONSE.NEED,
        }

        local duration = Measure(function()
            Loothing.History:AddEntry(entry)
        end)
        RecordOp(addMetrics, duration)
    end

    PrintMetrics(addMetrics)
    AssertPerf(addMetrics, "History addition should be fast")

    local entries = Loothing.History:GetAllEntries()
    Assert(#entries >= 1000, "Should have 1000 history entries")

    TeardownTest()
end

--- Test: History search performance
local function Test_HistorySearch()
    if not Loothing.History then
        print("|cffffcc00[Stress Test]|r History module not available, skipping test")
        return
    end

    SetupTest()

    -- Add 500 entries
    for i = 1, 500 do
        Loothing.History:AddEntry({
            timestamp = time(),
            sessionID = i,
            winner = string.format("Player%d-Realm", i % 50),
            itemLink = string.format("|cffa335ee|Hitem:%d|h[Item]|h|r", 19019),
        })
    end

    local searchMetrics = NewPerfMetrics("History Search", StressTests.performanceThresholds.acceptable)

    -- Search for entries
    local duration = Measure(function()
        local results = Loothing.History:Search({ winner = "Player5-Realm" })
    end)
    RecordOp(searchMetrics, duration)

    PrintMetrics(searchMetrics)
    AssertPerf(searchMetrics, "History search should be fast")

    TeardownTest()
end

--[[--------------------------------------------------------------------
    7. UI Performance Tests
----------------------------------------------------------------------]]

--- Test: MainFrame with 50 items
local function Test_MainFrameWithFiftyItems()
    if not Loothing.UI or not Loothing.UI.MainFrame then
        print("|cffffcc00[Stress Test]|r MainFrame not available, skipping test")
        return
    end

    SetupTest()

    Loothing.Session:StartSession(0, "UI Stress Test")

    -- Add 50 items
    local itemLinks = GenerateLargeItemSet(50)
    local looter = LoothingUtils.GetPlayerFullName()
    for _, itemLink in ipairs(itemLinks) do
        Loothing.Session:AddItem(itemLink, looter)
    end

    local refreshMetrics = NewPerfMetrics("MainFrame Refresh", StressTests.performanceThresholds.critical)

    -- Measure refresh time
    local mainFrame = Loothing.UI.MainFrame
    local duration = Measure(function()
        if type(mainFrame.Refresh) == "function" then
            mainFrame:Refresh()
        elseif type(mainFrame.RefreshContent) == "function" then
            mainFrame:RefreshContent()
        end
    end)
    RecordOp(refreshMetrics, duration)

    PrintMetrics(refreshMetrics)

    Loothing.Session:EndSession()
    TeardownTest()
end

--- Test: ResultsPanel refresh with 40 voters
local function Test_ResultsPanelFortyVoters()
    if not Loothing.UI or not Loothing.UI.ResultsPanel then
        print("|cffffcc00[Stress Test]|r ResultsPanel not available, skipping test")
        return
    end

    SetupTest()

    LoothingTestMode:GenerateFakeCouncil(40)

    Loothing.Session:StartSession(0, "Results Stress Test")
    local item = LoothingTestMode:CreateFakeItem()
    item:SetState(LOOTHING_ITEM_STATE.VOTING)

    -- Add 40 votes
    local councilMembers = LoothingTestMode:GetFakeCouncilMembers()
    for i = 2, #councilMembers do
        local member = councilMembers[i]
        item:AddVote(member.name, member.class, { LOOTHING_RESPONSE.NEED })
    end

    local results = item:TallyVotes()

    local refreshMetrics = NewPerfMetrics("ResultsPanel Refresh", StressTests.performanceThresholds.critical)

    -- Measure refresh time
    local resultsPanel = Loothing.UI.ResultsPanel
    local duration = Measure(function()
        resultsPanel:SetItem(item)
        resultsPanel:SetResults(results)
    end)
    RecordOp(refreshMetrics, duration)

    PrintMetrics(refreshMetrics)

    Loothing.Session:EndSession()
    TeardownTest()
end

--[[--------------------------------------------------------------------
    Test Registry
----------------------------------------------------------------------]]

StressTests.tests = {
    -- Large Item Count
    { name = "50 Item Session", func = Test_FiftyItemSession },
    { name = "100 Item Session", func = Test_HundredItemSession },
    { name = "DataProvider Large Sets", func = Test_DataProviderLargeSets },

    -- Large Raid Size
    { name = "40-Player Raid", func = Test_FortyPlayerRaid },

    -- Rapid Operations
    { name = "Rapid Votes", func = Test_RapidVotes },
    { name = "Rapid Item Adds", func = Test_RapidItemAdds },
    { name = "Rapid State Changes", func = Test_RapidStateChanges },

    -- Memory Tests
    { name = "Session Cycles", func = Test_SessionCycles },
    { name = "Item Creation Cycles", func = Test_ItemCreationCycles },
    { name = "Vote Accumulation", func = Test_VoteAccumulation },

    -- Message Volume
    { name = "Message Encode/Decode", func = Test_MessageEncodeDecode },
    { name = "Large Payload", func = Test_LargePayload },

    -- History Tests
    { name = "1000 History Entries", func = Test_ThousandHistoryEntries },
    { name = "History Search", func = Test_HistorySearch },

    -- UI Performance
    { name = "MainFrame with 50 Items", func = Test_MainFrameWithFiftyItems },
    { name = "ResultsPanel with 40 Voters", func = Test_ResultsPanelFortyVoters },
}

--[[--------------------------------------------------------------------
    Test Runner
----------------------------------------------------------------------]]

--- Run all stress tests
function StressTests:RunAll()
    print("|cff00ff00==============================================|r")
    print("|cff00ff00  Loothing Stress Tests|r")
    print("|cff00ff00==============================================|r")
    print("")
    print(string.format("Performance Thresholds:"))
    print(string.format("  Critical (60fps):  %.2fms", self.performanceThresholds.critical))
    print(string.format("  Acceptable:        %.2fms", self.performanceThresholds.acceptable))
    print(string.format("  Slow (bulk ops):   %.2fms", self.performanceThresholds.slow))
    print("")

    self.results = {}
    local passed = 0
    local failed = 0
    local skipped = 0
    local slow = 0

    for i, test in ipairs(self.tests) do
        print(string.format("[%d/%d] Running: %s", i, #self.tests, test.name))

        local result = { name = test.name, passed = false, error = nil, duration = 0 }
        self.currentTest = result

        local startTime = debugprofilestop()
        local success, err = pcall(test.func)
        result.duration = debugprofilestop() - startTime

        if success then
            result.passed = true
            passed = passed + 1
            print(string.format("  |cff00ff00✓ PASSED|r (%.2fms)", result.duration))
        else
            result.passed = false
            result.error = err
            if err and err:match("skipping test") then
                skipped = skipped + 1
                print(string.format("  |cffffcc00⊗ SKIPPED|r - %s", err))
            elseif err and err:match("threshold exceeded") then
                slow = slow + 1
                print(string.format("  |cffffcc00⚠ SLOW|r - %s", err))
            else
                failed = failed + 1
                print(string.format("  |cffff0000✗ FAILED|r - %s", err or "Unknown error"))
            end
        end

        table.insert(self.results, result)
        print("")
    end

    print("|cff00ff00==============================================|r")
    print(string.format("Results: %d passed, %d failed, %d slow, %d skipped",
        passed, failed, slow, skipped))
    print("|cff00ff00==============================================|r")

    return passed, failed, slow, skipped
end

--- Run a specific test by name
function StressTests:Run(testName)
    for _, test in ipairs(self.tests) do
        if test.name == testName then
            print(string.format("|cff00ff00Running:|r %s", test.name))

            local result = { name = test.name, passed = false, error = nil, duration = 0 }
            self.currentTest = result

            local startTime = debugprofilestop()
            local success, err = pcall(test.func)
            result.duration = debugprofilestop() - startTime

            if success then
                result.passed = true
                print(string.format("|cff00ff00✓ PASSED|r (%.2fms)", result.duration))
            else
                result.passed = false
                result.error = err
                print(string.format("|cffff0000✗ FAILED|r - %s", err or "Unknown error"))
            end

            return result
        end
    end

    print(string.format("|cffff0000Error:|r Test '%s' not found", testName))
    return nil
end

--- List all available tests
function StressTests:List()
    print("|cff00ff00Available Stress Tests:|r")
    for i, test in ipairs(self.tests) do
        print(string.format("  %d. %s", i, test.name))
    end
end

--[[--------------------------------------------------------------------
    Global Access
----------------------------------------------------------------------]]

_G.LoothingStressTests = StressTests

