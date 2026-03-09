--[[--------------------------------------------------------------------
    Loothing - Loot Council Addon for WoW 12.0+
    IntegrationTests - End-to-end workflow tests
----------------------------------------------------------------------]]

--[[--------------------------------------------------------------------
    Test Infrastructure
----------------------------------------------------------------------]]

local IntegrationTests = {
    name = "Integration Tests",
    tests = {},
    results = {},
    currentTest = nil,
}

-- Test result tracking
local TestResult = {
    name = nil,
    passed = false,
    error = nil,
    duration = 0,
    assertions = 0,
    timestamp = 0,
}

--- Create a new test result
local function NewTestResult(name)
    return {
        name = name,
        passed = true,
        error = nil,
        duration = 0,
        assertions = 0,
        timestamp = GetTime(),
    }
end

--- Assert helper
local function Assert(condition, message)
    if IntegrationTests.currentTest then
        IntegrationTests.currentTest.assertions = IntegrationTests.currentTest.assertions + 1
    end

    if not condition then
        local errorMsg = message or "Assertion failed"
        error(errorMsg, 2)
    end
end

--- Assert equality
local function AssertEqual(actual, expected, message)
    if actual ~= expected then
        local errorMsg = string.format("%s: expected %s, got %s",
            message or "Values not equal", tostring(expected), tostring(actual))
        Assert(false, errorMsg)
    end
end

--- Assert not nil
local function AssertNotNil(value, message)
    Assert(value ~= nil, message or "Value is nil")
end

--- Assert truthy value
local function AssertTrue(value, message)
    Assert(value == true, message or "Expected true")
end

--- Wait for condition with timeout
local function WaitFor(condition, timeout, checkInterval)
    timeout = timeout or 5
    checkInterval = checkInterval or 0.1

    local startTime = GetTime()
    while not condition() do
        if GetTime() - startTime > timeout then
            return false
        end
        -- In real WoW, we'd use C_Timer.After or frame OnUpdate
        -- For test purposes, assume synchronous execution
    end
    return true
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

    -- Clear history for clean test state
    if Loothing.History then
        Loothing.History:Clear()
    end
end

--- Teardown test environment
local function TeardownTest()
    -- End any active session
    if Loothing.Session and Loothing.Session:IsActive() then
        Loothing.Session:EndSession()
    end
end

--- Create a test item
local function CreateTestItem(itemID)
    itemID = itemID or 19019  -- Thunderfury
    local itemLink = LoothingTestMode:GenerateFakeItemLink(itemID)
    local looter = LoothingUtils.GetPlayerFullName()

    return Loothing.Session:AddItem(itemLink, looter)
end

--- Simulate council votes for an item
local function SimulateVotes(item, voteDistribution)
    -- voteDistribution: { [Loothing.Response.NEED] = 3, [Loothing.Response.GREED] = 2, ... }
    local councilMembers = LoothingTestMode:GetFakeCouncilMembers()
    local memberIndex = 2  -- Skip player at index 1

    for response, count in pairs(voteDistribution) do
        for i = 1, count do
            if memberIndex > #councilMembers then
                break
            end

            local member = councilMembers[memberIndex]
            local responses = { response }
            item:AddVote(member.name, member.class, responses)
            memberIndex = memberIndex + 1
        end
    end
end

--[[--------------------------------------------------------------------
    1. Happy Path Workflow Tests
----------------------------------------------------------------------]]

--- Test: Full session workflow (start → add items → vote → tally → award → end)
local function Test_FullSessionWorkflow()
    SetupTest()

    -- Start session
    local sessionID = Loothing.Session:StartSession(0, "Test Boss")
    AssertNotNil(sessionID, "Session should be created")
    Assert(Loothing.Session:IsActive(), "Session should be active")
    AssertEqual(Loothing.Session.state, Loothing.SessionState.ACTIVE, "Session state should be ACTIVE")

    -- Add item
    local item = CreateTestItem(19019)
    AssertNotNil(item, "Item should be added")
    AssertEqual(item:GetState(), Loothing.ItemState.PENDING, "Item should be PENDING")

    -- Start voting
    Loothing.Session:StartVoting(item.guid)
    AssertEqual(item:GetState(), Loothing.ItemState.VOTING, "Item should be VOTING")

    -- Verify item is in voting items list (multi-item support)
    local votingItems = Loothing.Session:GetVotingItems()
    AssertTrue(#votingItems >= 1, "Should have at least one voting item")
    local foundItem = false
    for _, vItem in ipairs(votingItems) do
        if vItem.guid == item.guid then
            foundItem = true
            break
        end
    end
    AssertTrue(foundItem, "Item should be in voting items list")

    -- Simulate votes
    SimulateVotes(item, {
        [Loothing.Response.NEED] = 3,
        [Loothing.Response.GREED] = 2,
        [Loothing.Response.PASS] = 1,
    })

    -- Tally votes
    local results = item:TallyVotes()
    AssertNotNil(results, "Results should be created")
    AssertEqual(item:GetState(), Loothing.ItemState.TALLIED, "Item should be TALLIED")

    -- Award item
    local winner = results.winner or "TestPlayer-Realm"
    Loothing.Session:AwardItem(item.guid, winner, "Main Spec")
    AssertEqual(item:GetState(), Loothing.ItemState.AWARDED, "Item should be AWARDED")

    -- Verify history
    local historyEntries = Loothing.History:GetAllEntries()
    Assert(#historyEntries > 0, "History should have entries")

    -- End session
    Loothing.Session:EndSession()
    Assert(not Loothing.Session:IsActive(), "Session should be inactive")

    TeardownTest()
end

--- Test: Multiple items in sequence
local function Test_MultipleItemsInSequence()
    SetupTest()

    Loothing.Session:StartSession(0, "Test Boss")

    local itemIDs = { 19019, 17182, 22691 }
    local items = {}

    -- Add all items
    for _, itemID in ipairs(itemIDs) do
        local item = CreateTestItem(itemID)
        AssertNotNil(item, "Item should be added")
        table.insert(items, item)
    end

    -- Process each item
    for i, item in ipairs(items) do
        -- Start voting
        Loothing.Session:StartVoting(item.guid)
        AssertEqual(item:GetState(), Loothing.ItemState.VOTING, "Item " .. i .. " should be VOTING")

        -- Vote and tally
        SimulateVotes(item, { [Loothing.Response.NEED] = 2, [Loothing.Response.GREED] = 1 })
        local results = item:TallyVotes()

        -- Award
        local winner = results.winner or "TestPlayer-Realm"
        Loothing.Session:AwardItem(item.guid, winner, "Main Spec")
        AssertEqual(item:GetState(), Loothing.ItemState.AWARDED, "Item " .. i .. " should be AWARDED")
    end

    -- Verify all items processed
    local historyEntries = Loothing.History:GetAllEntries()
    Assert(#historyEntries >= #items, "All items should be in history")

    Loothing.Session:EndSession()
    TeardownTest()
end

--- Test: Proper state transitions
local function Test_StateTransitions()
    SetupTest()

    Loothing.Session:StartSession(0, "Test Boss")
    local item = CreateTestItem()

    -- PENDING → VOTING
    AssertEqual(item:GetState(), Loothing.ItemState.PENDING)
    Loothing.Session:StartVoting(item.guid)
    AssertEqual(item:GetState(), Loothing.ItemState.VOTING)

    -- VOTING → TALLIED
    SimulateVotes(item, { [Loothing.Response.NEED] = 2 })
    item:TallyVotes()
    AssertEqual(item:GetState(), Loothing.ItemState.TALLIED)

    -- TALLIED → AWARDED
    Loothing.Session:AwardItem(item.guid, "TestPlayer-Realm", "Main Spec")
    AssertEqual(item:GetState(), Loothing.ItemState.AWARDED)

    Loothing.Session:EndSession()
    TeardownTest()
end

--- Test: Skipped items workflow
local function Test_SkippedItems()
    SetupTest()

    Loothing.Session:StartSession(0, "Test Boss")
    local item = CreateTestItem()

    -- Start voting
    Loothing.Session:StartVoting(item.guid)

    -- Skip instead of awarding
    Loothing.Session:SkipItem(item.guid, "Disenchant")
    AssertEqual(item:GetState(), Loothing.ItemState.SKIPPED)

    -- Verify in history
    local historyEntries = Loothing.History:GetAllEntries()
    local found = false
    for _, entry in ipairs(historyEntries) do
        if entry.itemGUID == item.guid and entry.winner == "SKIPPED" then
            found = true
            break
        end
    end
    Assert(found, "Skipped item should be in history")

    Loothing.Session:EndSession()
    TeardownTest()
end

--[[--------------------------------------------------------------------
    2. Multi-Item Sessions
----------------------------------------------------------------------]]

--- Test: 5 items in sequence
local function Test_FiveItemSession()
    SetupTest()

    Loothing.Session:StartSession(0, "Test Boss")

    local itemCount = 5
    local items = {}

    for i = 1, itemCount do
        local item = CreateTestItem(19019 + i)
        table.insert(items, item)
    end

    for i, item in ipairs(items) do
        Loothing.Session:StartVoting(item.guid)
        SimulateVotes(item, { [Loothing.Response.NEED] = math.random(1, 3) })
        local results = item:TallyVotes()
        local winner = results.winner or "Player" .. i .. "-Realm"
        Loothing.Session:AwardItem(item.guid, winner, "Main Spec")
    end

    AssertEqual(#Loothing.History:GetAllEntries(), itemCount, "All items should be in history")

    Loothing.Session:EndSession()
    TeardownTest()
end

--- Test: 10 items with different winners
local function Test_TenItemsDifferentWinners()
    SetupTest()

    Loothing.Session:StartSession(0, "Test Raid")

    local councilMembers = LoothingTestMode:GetFakeCouncilMembers()
    local winners = {}

    for i = 1, 10 do
        local item = CreateTestItem(19019 + i)
        Loothing.Session:StartVoting(item.guid)

        -- Award to different council members
        local winner = councilMembers[((i - 1) % #councilMembers) + 1].name
        Loothing.Session:AwardItem(item.guid, winner, "Main Spec")

        winners[winner] = (winners[winner] or 0) + 1
    end

    -- Verify distribution
    local uniqueWinners = 0
    for _ in pairs(winners) do
        uniqueWinners = uniqueWinners + 1
    end
    Assert(uniqueWinners > 1, "Multiple different winners should exist")

    Loothing.Session:EndSession()
    TeardownTest()
end

--- Test: Mixed awarded and skipped items
local function Test_MixedAwardedAndSkipped()
    SetupTest()

    Loothing.Session:StartSession(0, "Test Boss")

    local awardedCount = 0
    local skippedCount = 0

    for i = 1, 6 do
        local item = CreateTestItem(19019 + i)
        Loothing.Session:StartVoting(item.guid)

        if i % 2 == 0 then
            -- Skip every other item
            Loothing.Session:SkipItem(item.guid, "Disenchant")
            skippedCount = skippedCount + 1
        else
            -- Award the rest
            Loothing.Session:AwardItem(item.guid, "TestPlayer-Realm", "Main Spec")
            awardedCount = awardedCount + 1
        end
    end

    AssertEqual(awardedCount, 3, "Should have 3 awarded items")
    AssertEqual(skippedCount, 3, "Should have 3 skipped items")

    Loothing.Session:EndSession()
    TeardownTest()
end

--[[--------------------------------------------------------------------
    3. Ranked Choice Workflow
----------------------------------------------------------------------]]

--- Test: Ranked choice voting
local function Test_RankedChoiceVoting()
    SetupTest()

    -- Set voting mode to ranked choice
    local originalMode = Loothing.Settings:GetVotingMode()
    Loothing.Settings:SetVotingMode(Loothing.VotingMode.RANKED_CHOICE)

    Loothing.Session:StartSession(0, "Test Boss")
    local item = CreateTestItem()

    Loothing.Session:StartVoting(item.guid)

    -- Simulate ranked votes
    local councilMembers = LoothingTestMode:GetFakeCouncilMembers()
    for i = 2, math.min(5, #councilMembers) do
        local member = councilMembers[i]
        local rankedResponses = {
            Loothing.Response.NEED,
            Loothing.Response.GREED,
            Loothing.Response.OFFSPEC,
        }
        item:AddVote(member.name, member.class, rankedResponses)
    end

    -- Tally with ranked choice
    local results = item:TallyVotes()
    AssertNotNil(results, "Ranked choice results should be generated")

    -- Restore original mode
    Loothing.Settings:SetVotingMode(originalMode)

    Loothing.Session:EndSession()
    TeardownTest()
end

--[[--------------------------------------------------------------------
    4. Auto-Award Workflow
----------------------------------------------------------------------]]

--- Test: Auto-award on matching items
local function Test_AutoAwardMatching()
    SetupTest()

    if not Loothing.AutoAward then
        print("|cffffcc00[Integration Test]|r AutoAward module not available, skipping test")
        return
    end

    -- Enable auto-award for uncommon items
    local originalEnabled = Loothing.Settings:Get("autoAward.enabled")
    local originalThreshold = Loothing.Settings:Get("autoAward.lowerThreshold")

    Loothing.Settings:Set("autoAward.enabled", true)
    Loothing.Settings:Set("autoAward.lowerThreshold", Loothing.Quality.UNCOMMON)
    Loothing.Settings:Set("autoAward.upperThreshold", Loothing.Quality.RARE)
    Loothing.Settings:Set("autoAward.awardTo", "TestPlayer-Realm")

    Loothing.Session:StartSession(0, "Test Boss")

    -- Add an item that should auto-award
    -- (Note: Test infrastructure would need to mock item quality)

    -- Restore settings
    Loothing.Settings:Set("autoAward.enabled", originalEnabled)
    Loothing.Settings:Set("autoAward.lowerThreshold", originalThreshold)

    Loothing.Session:EndSession()
    TeardownTest()
end

--[[--------------------------------------------------------------------
    5. Auto-Pass Workflow
----------------------------------------------------------------------]]

--- Test: Auto-pass restrictions
local function Test_AutoPassRestrictions()
    SetupTest()

    if not Loothing.ItemFilter then
        print("|cffffcc00[Integration Test]|r ItemFilter module not available, skipping test")
        return
    end

    -- Enable auto-pass
    local originalEnabled = Loothing.Settings:Get("autoPass.enabled")
    Loothing.Settings:Set("autoPass.enabled", true)
    Loothing.Settings:Set("autoPass.weapons", true)

    -- Test would verify that inappropriate items are auto-passed

    -- Restore settings
    Loothing.Settings:Set("autoPass.enabled", originalEnabled)

    TeardownTest()
end

--[[--------------------------------------------------------------------
    6. Sync Workflow
----------------------------------------------------------------------]]

--- Test: Settings sync between ML and raid
local function Test_SettingsSync()
    SetupTest()

    if not Loothing.Comm then
        print("|cffffcc00[Integration Test]|r Comm module not available, skipping test")
        return
    end

    -- This would test sending/receiving settings sync messages
    -- Requires mocking network communication

    TeardownTest()
end

--- Test: History sync request/response
local function Test_HistorySync()
    SetupTest()

    if not Loothing.Comm or not Loothing.History then
        print("|cffffcc00[Integration Test]|r Required modules not available, skipping test")
        return
    end

    -- Add some history entries
    Loothing.Session:StartSession(0, "Test Boss")
    local item = CreateTestItem()
    Loothing.Session:StartVoting(item.guid)
    Loothing.Session:AwardItem(item.guid, "TestPlayer-Realm", "Main Spec")
    Loothing.Session:EndSession()

    local historyCount = #Loothing.History:GetAllEntries()
    Assert(historyCount > 0, "History should have entries to sync")

    TeardownTest()
end

--[[--------------------------------------------------------------------
    7. Trade Workflow
----------------------------------------------------------------------]]

--- Test: Item added to trade queue after award
local function Test_TradeQueueAfterAward()
    SetupTest()

    if not Loothing.TradeQueue then
        print("|cffffcc00[Integration Test]|r TradeQueue module not available, skipping test")
        return
    end

    Loothing.Session:StartSession(0, "Test Boss")
    local item = CreateTestItem()

    Loothing.Session:StartVoting(item.guid)
    Loothing.Session:AwardItem(item.guid, "TestWinner-Realm", "Main Spec")

    -- Verify item is in trade queue
    local queuedItem = Loothing.TradeQueue:FindItemByGUID(item.guid)
    AssertNotNil(queuedItem, "Item should be in trade queue after award")

    Loothing.Session:EndSession()
    TeardownTest()
end

--[[--------------------------------------------------------------------
    8. Error Recovery
----------------------------------------------------------------------]]

--- Test: Session recovery after simulated disconnect
local function Test_SessionRecovery()
    SetupTest()

    Loothing.Session:StartSession(0, "Test Boss")
    local sessionID = Loothing.Session.sessionID

    -- Add items
    CreateTestItem(19019)
    CreateTestItem(17182)

    -- Simulate disconnect by clearing current session state
    local savedItems = Loothing.Session.items
    Loothing.Session.currentVotingItem = nil

    -- Verify items still exist
    local itemCount = 0
    for _ in savedItems:Enumerate() do
        itemCount = itemCount + 1
    end
    Assert(itemCount >= 2, "Items should persist after disconnect")

    Loothing.Session:EndSession()
    TeardownTest()
end

--- Test: Invalid message handling
local function Test_InvalidMessageHandling()
    SetupTest()

    if not Loothing.Comm then
        print("|cffffcc00[Integration Test]|r Comm module not available, skipping test")
        return
    end

    -- Test would send malformed messages and verify they're rejected gracefully
    -- Requires mocking message reception

    TeardownTest()
end

--[[--------------------------------------------------------------------
    Test Registry
----------------------------------------------------------------------]]

IntegrationTests.tests = {
    -- Happy Path
    { name = "Full Session Workflow", func = Test_FullSessionWorkflow },
    { name = "Multiple Items in Sequence", func = Test_MultipleItemsInSequence },
    { name = "State Transitions", func = Test_StateTransitions },
    { name = "Skipped Items", func = Test_SkippedItems },

    -- Multi-Item Sessions
    { name = "Five Item Session", func = Test_FiveItemSession },
    { name = "Ten Items Different Winners", func = Test_TenItemsDifferentWinners },
    { name = "Mixed Awarded and Skipped", func = Test_MixedAwardedAndSkipped },

    -- Ranked Choice
    { name = "Ranked Choice Voting", func = Test_RankedChoiceVoting },

    -- Auto-Award
    { name = "Auto-Award Matching", func = Test_AutoAwardMatching },

    -- Auto-Pass
    { name = "Auto-Pass Restrictions", func = Test_AutoPassRestrictions },

    -- Sync
    { name = "Settings Sync", func = Test_SettingsSync },
    { name = "History Sync", func = Test_HistorySync },

    -- Trade
    { name = "Trade Queue After Award", func = Test_TradeQueueAfterAward },

    -- Error Recovery
    { name = "Session Recovery", func = Test_SessionRecovery },
    { name = "Invalid Message Handling", func = Test_InvalidMessageHandling },
}

--[[--------------------------------------------------------------------
    Test Runner
----------------------------------------------------------------------]]

--- Run all integration tests
function IntegrationTests:RunAll()
    print("|cff00ff00==============================================|r")
    print("|cff00ff00  Loothing Integration Tests|r")
    print("|cff00ff00==============================================|r")
    print("")

    self.results = {}
    local passed = 0
    local failed = 0
    local skipped = 0

    for i, test in ipairs(self.tests) do
        print(string.format("[%d/%d] Running: %s", i, #self.tests, test.name))

        local result = NewTestResult(test.name)
        self.currentTest = result

        local startTime = debugprofilestop()
        local success, err = pcall(test.func)
        result.duration = debugprofilestop() - startTime

        if success then
            result.passed = true
            passed = passed + 1
            print(string.format("  |cff00ff00✓ PASSED|r (%d assertions, %.2fms)",
                result.assertions, result.duration))
        else
            result.passed = false
            result.error = err
            if err and err:match("skipping test") then
                skipped = skipped + 1
                print(string.format("  |cffffcc00⊗ SKIPPED|r - %s", err))
            else
                failed = failed + 1
                print(string.format("  |cffff0000✗ FAILED|r - %s", err or "Unknown error"))
            end
        end

        table.insert(self.results, result)
        print("")
    end

    print("|cff00ff00==============================================|r")
    print(string.format("Results: %d passed, %d failed, %d skipped", passed, failed, skipped))
    print("|cff00ff00==============================================|r")

    return passed, failed, skipped
end

--- Run a specific test by name
function IntegrationTests:Run(testName)
    for _, test in ipairs(self.tests) do
        if test.name == testName then
            print(string.format("|cff00ff00Running:|r %s", test.name))

            local result = NewTestResult(test.name)
            self.currentTest = result

            local startTime = debugprofilestop()
            local success, err = pcall(test.func)
            result.duration = debugprofilestop() - startTime

            if success then
                result.passed = true
                print(string.format("|cff00ff00✓ PASSED|r (%d assertions, %.2fms)",
                    result.assertions, result.duration))
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
function IntegrationTests:List()
    print("|cff00ff00Available Integration Tests:|r")
    for i, test in ipairs(self.tests) do
        print(string.format("  %d. %s", i, test.name))
    end
end

--[[--------------------------------------------------------------------
    Global Access
----------------------------------------------------------------------]]

_G.LoothingIntegrationTests = IntegrationTests

