--[[--------------------------------------------------------------------
    Loothing - Session Tests
    Comprehensive test suite for Session lifecycle and item management
----------------------------------------------------------------------]]

--[[--------------------------------------------------------------------
    Test Framework Setup
----------------------------------------------------------------------]]

local Tests = {
    passed = 0,
    failed = 0,
    results = {},
    categories = {}
}

local function Assert(condition, message)
    if condition then
        Tests.passed = Tests.passed + 1
        table.insert(Tests.results, { pass = true, msg = message })
        return true
    else
        Tests.failed = Tests.failed + 1
        table.insert(Tests.results, { pass = false, msg = message })
        return false
    end
end

local function AssertEquals(actual, expected, message)
    return Assert(actual == expected,
        string.format("%s (expected: %s, got: %s)", message, tostring(expected), tostring(actual)))
end

local function AssertNotEquals(actual, notExpected, message)
    return Assert(actual ~= notExpected,
        string.format("%s (should not equal: %s)", message, tostring(notExpected)))
end

local function AssertNotNil(value, message)
    return Assert(value ~= nil, message or "Value should not be nil")
end

local function AssertNil(value, message)
    return Assert(value == nil, message or "Value should be nil")
end

local function AssertTrue(value, message)
    return Assert(value == true, message or "Value should be true")
end

local function AssertFalse(value, message)
    return Assert(value == false, message or "Value should be false")
end

local function AssertGreaterThan(actual, threshold, message)
    return Assert(actual > threshold,
        string.format("%s (expected > %s, got: %s)", message, tostring(threshold), tostring(actual)))
end

local function Describe(category, func)
    Tests.categories[#Tests.categories + 1] = category
    print("\n--- " .. category .. " ---")
    func()
end

local function It(description, func)
    local success, err = pcall(func)
    if not success then
        Assert(false, description .. " - ERROR: " .. tostring(err))
    end
end

local function PrintResults()
    print("\n=== Session Test Results ===")
    print(string.format("Passed: %d, Failed: %d", Tests.passed, Tests.failed))

    if Tests.failed > 0 then
        print("\nFailed Tests:")
        for _, result in ipairs(Tests.results) do
            if not result.pass then
                print("  ✗", result.msg)
            end
        end
    end

    if Tests.passed == #Tests.results then
        print("\n✓ All tests passed!")
    end
end

--[[--------------------------------------------------------------------
    Helper Functions
----------------------------------------------------------------------]]

local function CreateMockSession()
    local session = LoolibCreateFromMixins(LoothingSessionMixin)
    session:Init()
    return session
end

local function CreateMockItem(itemLink, looter)
    itemLink = itemLink or "|cffa335ee|Hitem:212398::::::::80::::::::::|h[Test Epic Item]|h|r"
    looter = looter or "TestPlayer"
    return CreateLoothingItem(itemLink, looter, 12345)
end

-- Mock only addon-owned Loothing.handleLoot (not Blizzard globals or TestMode).
-- StartSession also checks IsInGroup() — tests pass in-group, fail gracefully
-- solo via pcall without tainting any globals or leaking TestMode state.
local function MockSessionPermissions(canHandleLoot)
    local saved = {
        handleLoot = Loothing.handleLoot,
    }
    Loothing.handleLoot = (canHandleLoot == true)
    return saved
end

local function RestoreSessionPermissions(saved)
    Loothing.handleLoot = saved.handleLoot
end

--[[--------------------------------------------------------------------
    1. Session Creation Tests
----------------------------------------------------------------------]]

Describe("Session Creation", function()
    It("StartSession creates valid session", function()
        local session = CreateMockSession()

        local saved = MockSessionPermissions(true)

        local success = session:StartSession(12345, "Test Boss")

        AssertTrue(success, "StartSession should succeed")
        AssertNotNil(session:GetSessionID(), "Session should have ID")
        AssertEquals(session:GetEncounterID(), 12345, "Encounter ID should match")
        AssertEquals(session:GetEncounterName(), "Test Boss", "Encounter name should match")

        RestoreSessionPermissions(saved)
        session:EndSession()
    end)

    It("Session has correct initial state", function()
        local session = CreateMockSession()

        AssertEquals(session:GetState(), LOOTHING_SESSION_STATE.INACTIVE, "Initial state should be INACTIVE")
        AssertNil(session:GetSessionID(), "Session ID should be nil initially")
        AssertNil(session:GetEncounterID(), "Encounter ID should be nil initially")
        AssertFalse(session:IsActive(), "Session should not be active initially")
        AssertEquals(session:GetItemCount(), 0, "Should have no items initially")
    end)

    It("Session ID is unique", function()
        local session1 = CreateMockSession()
        local session2 = CreateMockSession()

        local saved = MockSessionPermissions(true)

        session1:StartSession(1, "Boss 1")
        session2:StartSession(2, "Boss 2")

        AssertNotEquals(session1:GetSessionID(), session2:GetSessionID(), "Session IDs should be unique")

        RestoreSessionPermissions(saved)
        session1:EndSession()
        session2:EndSession()
    end)

    It("Encounter info is stored correctly", function()
        local session = CreateMockSession()

        local saved = MockSessionPermissions(true)

        session:StartSession(999, "Mythic Test Boss")

        AssertEquals(session:GetEncounterID(), 999, "Encounter ID stored")
        AssertEquals(session:GetEncounterName(), "Mythic Test Boss", "Encounter name stored")

        RestoreSessionPermissions(saved)
        session:EndSession()
    end)

    It("Cannot start session twice", function()
        local session = CreateMockSession()

        local saved = MockSessionPermissions(true)

        local first = session:StartSession(1, "Boss")
        local second = session:StartSession(2, "Another Boss")

        AssertTrue(first, "First start should succeed")
        AssertFalse(second, "Second start should fail")
        AssertEquals(session:GetEncounterID(), 1, "Should keep first encounter")

        RestoreSessionPermissions(saved)
        session:EndSession()
    end)

    It("Cannot start session without permissions", function()
        local session = CreateMockSession()

        local saved = MockSessionPermissions(false)

        local success = session:StartSession(1, "Boss")

        AssertFalse(success, "Should not start without permissions")
        AssertEquals(session:GetState(), LOOTHING_SESSION_STATE.INACTIVE, "State should remain INACTIVE")

        RestoreSessionPermissions(saved)
    end)
end)

--[[--------------------------------------------------------------------
    2. Item Management Tests
----------------------------------------------------------------------]]

Describe("Item Management", function()
    It("AddItem creates LoothingItemMixin", function()
        local session = CreateMockSession()

        local saved = MockSessionPermissions(true)

        session:StartSession(1, "Boss")

        local item = session:AddItem("|cffa335ee|Hitem:212398::::::::80::::::::::|h[Epic Sword]|h|r", "Player1")

        AssertNotNil(item, "AddItem should return item")
        AssertNotNil(item.guid, "Item should have GUID")
        AssertEquals(item.state, LOOTHING_ITEM_STATE.PENDING, "Item should be PENDING")

        RestoreSessionPermissions(saved)
        session:EndSession()
    end)

    It("RemoveItem removes from DataProvider", function()
        local session = CreateMockSession()

        local saved = MockSessionPermissions(true)

        session:StartSession(1, "Boss")

        local item = session:AddItem("|cffa335ee|Hitem:212398::::::::80::::::::::|h[Epic Sword]|h|r", "Player1")
        local guid = item.guid

        AssertEquals(session:GetItemCount(), 1, "Should have 1 item")

        local removed = session:RemoveItem(guid)

        AssertTrue(removed, "RemoveItem should succeed")
        AssertEquals(session:GetItemCount(), 0, "Should have 0 items after removal")

        RestoreSessionPermissions(saved)
        session:EndSession()
    end)

    It("Items have unique GUIDs", function()
        local session = CreateMockSession()

        local saved = MockSessionPermissions(true)

        session:StartSession(1, "Boss")

        local item1 = session:AddItem("|cffa335ee|Hitem:212398::::::::80::::::::::|h[Item 1]|h|r", "Player1")
        local item2 = session:AddItem("|cffa335ee|Hitem:212399::::::::80::::::::::|h[Item 2]|h|r", "Player2")

        AssertNotEquals(item1.guid, item2.guid, "Items should have unique GUIDs")

        RestoreSessionPermissions(saved)
        session:EndSession()
    end)

    It("Cannot add items when session inactive", function()
        local session = CreateMockSession()

        local item = session:AddItem("|cffa335ee|Hitem:212398::::::::80::::::::::|h[Epic Sword]|h|r", "Player1")

        AssertNil(item, "Should not add item when session inactive")
        AssertEquals(session:GetItemCount(), 0, "Item count should be 0")
    end)

    It("GetItemByGUID returns correct item", function()
        local session = CreateMockSession()

        local saved = MockSessionPermissions(true)

        session:StartSession(1, "Boss")

        local item1 = session:AddItem("|cffa335ee|Hitem:212398::::::::80::::::::::|h[Item 1]|h|r", "Player1")
        local item2 = session:AddItem("|cffa335ee|Hitem:212399::::::::80::::::::::|h[Item 2]|h|r", "Player2")

        local found = session:GetItemByGUID(item2.guid)

        AssertEquals(found, item2, "Should find correct item by GUID")

        RestoreSessionPermissions(saved)
        session:EndSession()
    end)

    It("GetPendingItems returns only pending items", function()
        local session = CreateMockSession()

        local saved = MockSessionPermissions(true)

        session:StartSession(1, "Boss")

        local item1 = session:AddItem("|cffa335ee|Hitem:212398::::::::80::::::::::|h[Item 1]|h|r", "Player1")
        local item2 = session:AddItem("|cffa335ee|Hitem:212399::::::::80::::::::::|h[Item 2]|h|r", "Player2")

        item2:SetState(LOOTHING_ITEM_STATE.AWARDED)

        local pending = session:GetPendingItems()

        AssertEquals(#pending, 1, "Should have 1 pending item")
        AssertEquals(pending[1], item1, "Should return only pending item")

        RestoreSessionPermissions(saved)
        session:EndSession()
    end)
end)

--[[--------------------------------------------------------------------
    3. State Transitions Tests
----------------------------------------------------------------------]]

Describe("State Transitions", function()
    It("StartVoting changes item state to VOTING", function()
        local session = CreateMockSession()

        local saved = MockSessionPermissions(true)

        session:StartSession(1, "Boss")
        local item = session:AddItem("|cffa335ee|Hitem:212398::::::::80::::::::::|h[Epic Sword]|h|r", "Player1")

        local success = session:StartVoting(item.guid, 30)

        AssertTrue(success, "StartVoting should succeed")
        AssertEquals(item:GetState(), LOOTHING_ITEM_STATE.VOTING, "Item should be in VOTING state")
        AssertEquals(session:GetCurrentVotingItem(), item, "Session should track voting item")

        RestoreSessionPermissions(saved)
        session:EndSession()
    end)

    It("EndVoting changes state to TALLIED", function()
        local session = CreateMockSession()

        local saved = MockSessionPermissions(true)

        session:StartSession(1, "Boss")
        local item = session:AddItem("|cffa335ee|Hitem:212398::::::::80::::::::::|h[Epic Sword]|h|r", "Player1")

        session:StartVoting(item.guid, 30)
        session:EndVoting()

        AssertEquals(item:GetState(), LOOTHING_ITEM_STATE.TALLIED, "Item should be TALLIED")
        AssertNil(session:GetCurrentVotingItem(), "Current voting item should be cleared")

        RestoreSessionPermissions(saved)
        session:EndSession()
    end)

    It("AwardItem marks as AWARDED", function()
        local session = CreateMockSession()

        local saved = MockSessionPermissions(true)

        session:StartSession(1, "Boss")
        local item = session:AddItem("|cffa335ee|Hitem:212398::::::::80::::::::::|h[Epic Sword]|h|r", "Player1")

        session:AwardItem(item.guid, "Winner", LOOTHING_RESPONSE.NEED)

        AssertEquals(item:GetState(), LOOTHING_ITEM_STATE.AWARDED, "Item should be AWARDED")
        AssertEquals(item:GetWinner(), LoothingUtils.NormalizeName("Winner"), "Winner should be set")

        RestoreSessionPermissions(saved)
        session:EndSession()
    end)

    It("SkipItem marks as SKIPPED", function()
        local session = CreateMockSession()

        local saved = MockSessionPermissions(true)

        session:StartSession(1, "Boss")
        local item = session:AddItem("|cffa335ee|Hitem:212398::::::::80::::::::::|h[Epic Sword]|h|r", "Player1")

        session:SkipItem(item.guid)

        AssertEquals(item:GetState(), LOOTHING_ITEM_STATE.SKIPPED, "Item should be SKIPPED")

        RestoreSessionPermissions(saved)
        session:EndSession()
    end)

    It("Cannot start voting on already voting item", function()
        local session = CreateMockSession()

        local saved = MockSessionPermissions(true)

        session:StartSession(1, "Boss")
        local item1 = session:AddItem("|cffa335ee|Hitem:212398::::::::80::::::::::|h[Item 1]|h|r", "Player1")
        local item2 = session:AddItem("|cffa335ee|Hitem:212399::::::::80::::::::::|h[Item 2]|h|r", "Player2")

        session:StartVoting(item1.guid, 30)
        local second = session:StartVoting(item2.guid, 30)

        AssertFalse(second, "Should not start voting on second item")
        AssertEquals(session:GetCurrentVotingItem(), item1, "Should keep first item voting")

        RestoreSessionPermissions(saved)
        session:EndSession()
    end)

    It("Cannot start voting on non-pending item", function()
        local session = CreateMockSession()

        local saved = MockSessionPermissions(true)

        session:StartSession(1, "Boss")
        local item = session:AddItem("|cffa335ee|Hitem:212398::::::::80::::::::::|h[Epic Sword]|h|r", "Player1")

        item:SetState(LOOTHING_ITEM_STATE.AWARDED)

        local success = session:StartVoting(item.guid, 30)

        AssertFalse(success, "Should not start voting on awarded item")

        RestoreSessionPermissions(saved)
        session:EndSession()
    end)
end)

--[[--------------------------------------------------------------------
    4. Session End Tests
----------------------------------------------------------------------]]

Describe("Session End", function()
    It("EndSession clears items", function()
        local session = CreateMockSession()

        local saved = MockSessionPermissions(true)

        session:StartSession(1, "Boss")
        session:AddItem("|cffa335ee|Hitem:212398::::::::80::::::::::|h[Item 1]|h|r", "Player1")
        session:AddItem("|cffa335ee|Hitem:212399::::::::80::::::::::|h[Item 2]|h|r", "Player2")

        AssertEquals(session:GetItemCount(), 2, "Should have 2 items")

        session:EndSession()

        AssertEquals(session:GetItemCount(), 0, "Items should be cleared")

        RestoreSessionPermissions(saved)
    end)

    It("EndSession moves to INACTIVE state", function()
        local session = CreateMockSession()

        local saved = MockSessionPermissions(true)

        session:StartSession(1, "Boss")
        AssertEquals(session:GetState(), LOOTHING_SESSION_STATE.ACTIVE, "Should be ACTIVE")

        session:EndSession()

        AssertEquals(session:GetState(), LOOTHING_SESSION_STATE.INACTIVE, "Should be INACTIVE")
        AssertFalse(session:IsActive(), "IsActive should be false")

        RestoreSessionPermissions(saved)
    end)

    It("EndSession cancels active voting", function()
        local session = CreateMockSession()

        local saved = MockSessionPermissions(true)

        session:StartSession(1, "Boss")
        local item = session:AddItem("|cffa335ee|Hitem:212398::::::::80::::::::::|h[Epic Sword]|h|r", "Player1")

        session:StartVoting(item.guid, 30)
        AssertNotNil(session:GetCurrentVotingItem(), "Should have voting item")

        session:EndSession()

        AssertNil(session:GetCurrentVotingItem(), "Voting item should be cleared")

        RestoreSessionPermissions(saved)
    end)

    It("CloseSession changes state to CLOSED", function()
        local session = CreateMockSession()

        local saved = MockSessionPermissions(true)

        session:StartSession(1, "Boss")
        session:CloseSession()

        AssertEquals(session:GetState(), LOOTHING_SESSION_STATE.CLOSED, "Should be CLOSED")

        RestoreSessionPermissions(saved)
        session:EndSession()
    end)

    It("Cannot end inactive session", function()
        local session = CreateMockSession()

        local success = session:EndSession()

        AssertFalse(success, "Cannot end inactive session")
    end)
end)

--[[--------------------------------------------------------------------
    5. Edge Cases Tests
----------------------------------------------------------------------]]

Describe("Edge Cases", function()
    It("Empty session handling", function()
        local session = CreateMockSession()

        AssertEquals(session:GetItemCount(), 0, "Empty session has 0 items")
        AssertEquals(#session:GetPendingItems(), 0, "No pending items in empty session")

        local items = session:GetItems()
        local count = 0
        for _ in items:Enumerate() do
            count = count + 1
        end
        AssertEquals(count, 0, "Items DataProvider is empty")
    end)

    It("Invalid item GUID handling", function()
        local session = CreateMockSession()

        local saved = MockSessionPermissions(true)

        session:StartSession(1, "Boss")

        local found = session:GetItemByGUID("invalid-guid-12345")
        AssertNil(found, "Should return nil for invalid GUID")

        local removed = session:RemoveItem("invalid-guid-12345")
        AssertFalse(removed, "Should fail to remove invalid GUID")

        local voted = session:StartVoting("invalid-guid-12345", 30)
        AssertFalse(voted, "Should fail to start voting on invalid GUID")

        RestoreSessionPermissions(saved)
        session:EndSession()
    end)

    It("Multiple items same looter", function()
        local session = CreateMockSession()

        local saved = MockSessionPermissions(true)

        session:StartSession(1, "Boss")

        local item1 = session:AddItem("|cffa335ee|Hitem:212398::::::::80::::::::::|h[Item 1]|h|r", "SamePlayer")
        local item2 = session:AddItem("|cffa335ee|Hitem:212399::::::::80::::::::::|h[Item 2]|h|r", "SamePlayer")

        AssertEquals(session:GetItemCount(), 2, "Should add both items")
        AssertEquals(item1.looter, item2.looter, "Looter should be same")
        AssertNotEquals(item1.guid, item2.guid, "GUIDs should be different")

        RestoreSessionPermissions(saved)
        session:EndSession()
    end)

    It("GetItemsWonByPlayer counts correctly", function()
        local session = CreateMockSession()

        local saved = MockSessionPermissions(true)

        session:StartSession(1, "Boss")

        local item1 = session:AddItem("|cffa335ee|Hitem:212398::::::::80::::::::::|h[Item 1]|h|r", "Looter1")
        local item2 = session:AddItem("|cffa335ee|Hitem:212399::::::::80::::::::::|h[Item 2]|h|r", "Looter2")
        local item3 = session:AddItem("|cffa335ee|Hitem:212400::::::::80::::::::::|h[Item 3]|h|r", "Looter3")

        session:AwardItem(item1.guid, "Winner1", LOOTHING_RESPONSE.NEED)
        session:AwardItem(item2.guid, "Winner1", LOOTHING_RESPONSE.GREED)
        session:AwardItem(item3.guid, "Winner2", LOOTHING_RESPONSE.NEED)

        AssertEquals(session:GetItemsWonByPlayer("Winner1"), 2, "Winner1 should have 2 items")
        AssertEquals(session:GetItemsWonByPlayer("Winner2"), 1, "Winner2 should have 1 item")
        AssertEquals(session:GetItemsWonByPlayer("NoWins"), 0, "NoWins should have 0 items")

        RestoreSessionPermissions(saved)
        session:EndSession()
    end)

    It("Session state changes trigger events", function()
        local session = CreateMockSession()

        local stateChangeFired = false
        local newState, oldState

        session:RegisterCallback("OnStateChanged", function(state, old)
            stateChangeFired = true
            newState = state
            oldState = old
        end)

        local saved = MockSessionPermissions(true)

        session:StartSession(1, "Boss")

        AssertTrue(stateChangeFired, "State change event should fire")
        AssertEquals(newState, LOOTHING_SESSION_STATE.ACTIVE, "New state should be ACTIVE")
        AssertEquals(oldState, LOOTHING_SESSION_STATE.INACTIVE, "Old state should be INACTIVE")

        RestoreSessionPermissions(saved)
        session:EndSession()
    end)

    It("Item add triggers event", function()
        local session = CreateMockSession()

        local itemAddFired = false
        local addedItem

        session:RegisterCallback("OnItemAdded", function(_, item)
            itemAddFired = true
            addedItem = item
        end)

        local saved = MockSessionPermissions(true)

        session:StartSession(1, "Boss")
        local item = session:AddItem("|cffa335ee|Hitem:212398::::::::80::::::::::|h[Epic Sword]|h|r", "Player1")

        AssertTrue(itemAddFired, "Item add event should fire")
        AssertEquals(addedItem, item, "Event should pass correct item")

        RestoreSessionPermissions(saved)
        session:EndSession()
    end)

    It("Voting started event fires", function()
        local session = CreateMockSession()

        local votingStartFired = false
        local votingItem, timeout

        session:RegisterCallback("OnVotingStarted", function(item, time)
            votingStartFired = true
            votingItem = item
            timeout = time
        end)

        local saved = MockSessionPermissions(true)

        session:StartSession(1, "Boss")
        local item = session:AddItem("|cffa335ee|Hitem:212398::::::::80::::::::::|h[Epic Sword]|h|r", "Player1")
        session:StartVoting(item.guid, 45)

        AssertTrue(votingStartFired, "Voting started event should fire")
        AssertEquals(votingItem, item, "Event should pass correct item")
        AssertEquals(timeout, 45, "Event should pass correct timeout")

        RestoreSessionPermissions(saved)
        session:EndSession()
    end)
end)

--[[--------------------------------------------------------------------
    Run All Tests
----------------------------------------------------------------------]]

local function RunAllSessionTests()
    print("=== Running Session Tests ===")

    -- Reset counters
    Tests.passed = 0
    Tests.failed = 0
    Tests.results = {}
    Tests.categories = {}

    -- Run tests (they call Describe internally)

    PrintResults()
end

