--[[--------------------------------------------------------------------
    Loothing - Loot Council Addon for WoW 12.0+
    ItemTests - Comprehensive test suite for item management

    This file is for development/testing only and should not be loaded
    in production. To run tests, load this file manually in-game.
----------------------------------------------------------------------]]

local function RunItemTests()
    if not Loothing or not CreateLoothingItem then
        print("[Tests] LoothingItem not loaded")
        return
    end

    local passed = 0
    local failed = 0
    local testGroup = ""

    local function assert(condition, testName)
        if condition then
            print("|cff00ff00[PASS]|r", testName)
            passed = passed + 1
        else
            print("|cffff0000[FAIL]|r", testName)
            failed = failed + 1
        end
    end

    local function assertEqual(actual, expected, testName)
        if actual == expected then
            print("|cff00ff00[PASS]|r", testName)
            passed = passed + 1
        else
            print("|cffff0000[FAIL]|r", testName, string.format("(got %s, expected %s)", tostring(actual), tostring(expected)))
            failed = failed + 1
        end
    end

    local function assertNotNil(value, testName)
        if value ~= nil then
            print("|cff00ff00[PASS]|r", testName)
            passed = passed + 1
        else
            print("|cffff0000[FAIL]|r", testName, "(value is nil)")
            failed = failed + 1
        end
    end

    local function printGroup(groupName)
        print("\n|cffFFFF00Test Group: " .. groupName .. "|r")
        testGroup = groupName
    end

    print("|cff00ccff========== Item Management Tests ==========|r")

    -- Test data
    local testItemLink = "|cffa335ee|Hitem:207788::::::::70:581::16:4:6652:10341:1537:8767::::::|h[Amice of the Sinister Savant]|h|r"
    local testLooter = "TestPlayer-Realm"
    local testEncounterID = 2820

    --[[--------------------------------------------------------------------
        Test Group 1: Item Creation
    ----------------------------------------------------------------------]]
    printGroup("Item Creation")

    local item = CreateLoothingItem(testItemLink, testLooter, testEncounterID)
    assertNotNil(item, "CreateLoothingItem returns object")
    assertNotNil(item.guid, "Item has GUID")
    assertEqual(item.itemLink, testItemLink, "Item link stored correctly")
    assertEqual(item.looter, testLooter, "Looter stored correctly")
    assertEqual(item.encounterID, testEncounterID, "EncounterID stored correctly")
    assertNotNil(item.timestamp, "Timestamp generated")
    assertNotNil(item.itemID, "ItemID extracted from link")
    assertNotNil(item.name, "Item name extracted")

    -- Test GUID uniqueness
    local item2 = CreateLoothingItem(testItemLink, testLooter, testEncounterID)
    assert(item.guid ~= item2.guid, "GUID generation is unique")

    -- Test looter normalization
    local item3 = CreateLoothingItem(testItemLink, "PlayerNoRealm", testEncounterID)
    assert(item3.looter:find("-"), "Looter name normalized with realm")

    --[[--------------------------------------------------------------------
        Test Group 2: State Management
    ----------------------------------------------------------------------]]
    printGroup("State Management")

    local stateItem = CreateLoothingItem(testItemLink, testLooter, testEncounterID)

    -- Initial state
    assertEqual(stateItem:GetState(), LOOTHING_ITEM_STATE.PENDING, "Initial state is PENDING")
    assert(stateItem:IsPending(), "IsPending returns true for PENDING state")
    assert(not stateItem:IsVoting(), "IsVoting returns false for PENDING state")
    assert(not stateItem:IsTallied(), "IsTallied returns false for PENDING state")
    assert(not stateItem:IsAwarded(), "IsAwarded returns false for PENDING state")
    assert(not stateItem:IsSkipped(), "IsSkipped returns false for PENDING state")
    assert(not stateItem:IsComplete(), "IsComplete returns false for PENDING state")

    -- Change to VOTING
    stateItem:SetState(LOOTHING_ITEM_STATE.VOTING)
    assertEqual(stateItem:GetState(), LOOTHING_ITEM_STATE.VOTING, "SetState changes state to VOTING")
    assert(stateItem:IsVoting(), "IsVoting returns true for VOTING state")
    assert(not stateItem:IsPending(), "IsPending returns false after state change")

    -- Change to TALLIED
    stateItem:SetState(LOOTHING_ITEM_STATE.TALLIED)
    assertEqual(stateItem:GetState(), LOOTHING_ITEM_STATE.TALLIED, "SetState changes state to TALLIED")
    assert(stateItem:IsTallied(), "IsTallied returns true for TALLIED state")

    -- Change to AWARDED
    stateItem:SetState(LOOTHING_ITEM_STATE.AWARDED)
    assertEqual(stateItem:GetState(), LOOTHING_ITEM_STATE.AWARDED, "SetState changes state to AWARDED")
    assert(stateItem:IsAwarded(), "IsAwarded returns true for AWARDED state")
    assert(stateItem:IsComplete(), "IsComplete returns true for AWARDED state")

    -- Change to SKIPPED
    local skipItem = CreateLoothingItem(testItemLink, testLooter, testEncounterID)
    skipItem:SetState(LOOTHING_ITEM_STATE.SKIPPED)
    assert(skipItem:IsSkipped(), "IsSkipped returns true for SKIPPED state")
    assert(skipItem:IsComplete(), "IsComplete returns true for SKIPPED state")

    -- Test state change events
    local eventFired = false
    local oldStateCapture = nil
    local newStateCapture = nil
    local eventItem = CreateLoothingItem(testItemLink, testLooter, testEncounterID)
    eventItem:RegisterCallback("OnStateChanged", function(_, newState, oldState)
        eventFired = true
        newStateCapture = newState
        oldStateCapture = oldState
    end)
    eventItem:SetState(LOOTHING_ITEM_STATE.VOTING)
    assert(eventFired, "OnStateChanged event triggered")
    assertEqual(oldStateCapture, LOOTHING_ITEM_STATE.PENDING, "Event receives correct old state")
    assertEqual(newStateCapture, LOOTHING_ITEM_STATE.VOTING, "Event receives correct new state")

    --[[--------------------------------------------------------------------
        Test Group 3: Vote Management
    ----------------------------------------------------------------------]]
    printGroup("Vote Management")

    local voteItem = CreateLoothingItem(testItemLink, testLooter, testEncounterID)
    voteItem:SetState(LOOTHING_ITEM_STATE.VOTING)

    -- Add vote
    local voter1 = "Voter1-Realm"
    local voter1Class = "WARRIOR"
    local responses1 = { LOOTHING_RESPONSE.NEED, LOOTHING_RESPONSE.GREED }
    local addResult = voteItem:AddVote(voter1, voter1Class, responses1)
    assert(addResult, "AddVote returns true")
    assertEqual(voteItem:GetVoteCount(), 1, "Vote count incremented")
    assert(voteItem:HasVoted(voter1), "HasVoted returns true after adding vote")

    -- Get vote by voter
    local vote = voteItem:GetVoteByVoter(voter1)
    assertNotNil(vote, "GetVoteByVoter returns vote")
    assertEqual(vote.voter, voter1, "Vote has correct voter")
    assertEqual(vote.voterClass, voter1Class, "Vote has correct voter class")
    assertEqual(vote.responses[1], LOOTHING_RESPONSE.NEED, "Vote has correct first response")
    assertEqual(vote.responses[2], LOOTHING_RESPONSE.GREED, "Vote has correct second response")

    -- Add multiple votes
    voteItem:AddVote("Voter2-Realm", "MAGE", { LOOTHING_RESPONSE.GREED })
    voteItem:AddVote("Voter3-Realm", "PRIEST", { LOOTHING_RESPONSE.NEED })
    assertEqual(voteItem:GetVoteCount(), 3, "Multiple votes added correctly")

    -- Update existing vote
    local updateResult = voteItem:AddVote(voter1, voter1Class, { LOOTHING_RESPONSE.OFFSPEC })
    assert(updateResult, "AddVote can update existing vote")
    assertEqual(voteItem:GetVoteCount(), 3, "Vote count unchanged after update")
    local updatedVote = voteItem:GetVoteByVoter(voter1)
    assertEqual(updatedVote.responses[1], LOOTHING_RESPONSE.OFFSPEC, "Vote updated correctly")

    -- Remove vote
    local removeResult = voteItem:RemoveVote(voter1)
    assert(removeResult, "RemoveVote returns true")
    assertEqual(voteItem:GetVoteCount(), 2, "Vote count decremented")
    assert(not voteItem:HasVoted(voter1), "HasVoted returns false after removal")

    -- Get all votes
    local allVotes = voteItem:GetVotes()
    assertNotNil(allVotes, "GetVotes returns DataProvider")
    assertEqual(allVotes:GetSize(), 2, "DataProvider has correct size")

    -- Get votes by response
    local needVotes = voteItem:GetVotesByResponse(LOOTHING_RESPONSE.NEED)
    assertEqual(#needVotes, 1, "GetVotesByResponse returns correct count")

    -- Test vote events
    local voteEventFired = false
    local voteEventItem = CreateLoothingItem(testItemLink, testLooter, testEncounterID)
    voteEventItem:SetState(LOOTHING_ITEM_STATE.VOTING)
    voteEventItem:RegisterCallback("OnVoteAdded", function()
        voteEventFired = true
    end)
    voteEventItem:AddVote("TestVoter-Realm", "HUNTER", { LOOTHING_RESPONSE.NEED })
    assert(voteEventFired, "OnVoteAdded event triggered")

    -- Test voter normalization
    local normalizeItem = CreateLoothingItem(testItemLink, testLooter, testEncounterID)
    normalizeItem:SetState(LOOTHING_ITEM_STATE.VOTING)
    normalizeItem:AddVote("VoterNoRealm", "ROGUE", { LOOTHING_RESPONSE.NEED })
    assert(normalizeItem:HasVoted("VoterNoRealm-" .. GetNormalizedRealmName()), "Voter name normalized correctly")

    -- Test voting only allowed in VOTING state
    local pendingItem = CreateLoothingItem(testItemLink, testLooter, testEncounterID)
    local pendingResult = pendingItem:AddVote("Voter-Realm", "WARRIOR", { LOOTHING_RESPONSE.NEED })
    assert(not pendingResult, "AddVote fails when not in VOTING state")

    --[[--------------------------------------------------------------------
        Test Group 4: Timer Management
    ----------------------------------------------------------------------]]
    printGroup("Timer Management")

    local timerItem = CreateLoothingItem(testItemLink, testLooter, testEncounterID)

    -- Start voting with default timeout
    local startResult = timerItem:StartVoting()
    assert(startResult, "StartVoting returns true")
    assert(timerItem:IsVoting(), "StartVoting changes state to VOTING")
    assertNotNil(timerItem.voteStartTime, "voteStartTime set")
    assertNotNil(timerItem.voteEndTime, "voteEndTime set")
    assertNotNil(timerItem.voteTimeout, "voteTimeout set")

    -- Get time remaining
    local remaining = timerItem:GetTimeRemaining()
    assert(remaining > 0, "GetTimeRemaining returns positive value")
    assert(remaining <= timerItem.voteTimeout, "Time remaining within timeout")

    -- Start voting with custom timeout
    local customItem = CreateLoothingItem(testItemLink, testLooter, testEncounterID)
    customItem:StartVoting(60)
    assertEqual(customItem.voteTimeout, 60, "Custom timeout respected")

    -- Start voting fails if not pending
    local notPendingItem = CreateLoothingItem(testItemLink, testLooter, testEncounterID)
    notPendingItem:SetState(LOOTHING_ITEM_STATE.TALLIED)
    local failResult = notPendingItem:StartVoting()
    assert(not failResult, "StartVoting fails when not PENDING")

    -- End voting
    local endItem = CreateLoothingItem(testItemLink, testLooter, testEncounterID)
    endItem:StartVoting()
    local endResult = endItem:EndVoting()
    assert(endResult, "EndVoting returns true")
    assert(endItem:IsTallied(), "EndVoting changes state to TALLIED")

    -- GetTimeRemaining returns 0 when not voting
    assertEqual(endItem:GetTimeRemaining(), 0, "GetTimeRemaining returns 0 when not voting")

    --[[--------------------------------------------------------------------
        Test Group 5: Award and Skip
    ----------------------------------------------------------------------]]
    printGroup("Award and Skip")

    -- Set winner
    local awardItem = CreateLoothingItem(testItemLink, testLooter, testEncounterID)
    local winner = "Winner-Realm"
    local winnerResponse = LOOTHING_RESPONSE.NEED
    awardItem:SetWinner(winner, winnerResponse)
    assertEqual(awardItem:GetWinner(), winner, "GetWinner returns correct winner")
    assertEqual(awardItem.winnerResponse, winnerResponse, "Winner response stored")
    assert(awardItem:IsAwarded(), "SetWinner changes state to AWARDED")
    assertNotNil(awardItem.awardedTime, "awardedTime set")

    -- Test winner normalization
    local normWinnerItem = CreateLoothingItem(testItemLink, testLooter, testEncounterID)
    normWinnerItem:SetWinner("WinnerNoRealm", LOOTHING_RESPONSE.NEED)
    assert(normWinnerItem.winner:find("-"), "Winner name normalized")

    -- Test winner event
    local winnerEventFired = false
    local winnerEventItem = CreateLoothingItem(testItemLink, testLooter, testEncounterID)
    winnerEventItem:RegisterCallback("OnWinnerSet", function()
        winnerEventFired = true
    end)
    winnerEventItem:SetWinner("TestWinner-Realm", LOOTHING_RESPONSE.NEED)
    assert(winnerEventFired, "OnWinnerSet event triggered")

    -- Skip item
    local skipItem = CreateLoothingItem(testItemLink, testLooter, testEncounterID)
    skipItem:Skip()
    assert(skipItem:IsSkipped(), "Skip changes state to SKIPPED")
    assertNotNil(skipItem.awardedTime, "awardedTime set on skip")
    assertEqual(skipItem:GetWinner(), nil, "No winner for skipped item")

    --[[--------------------------------------------------------------------
        Test Group 6: Serialization
    ----------------------------------------------------------------------]]
    printGroup("Serialization")

    -- Create item with votes
    local serItem = CreateLoothingItem(testItemLink, testLooter, testEncounterID)
    serItem:SetState(LOOTHING_ITEM_STATE.VOTING)
    serItem:AddVote("SerVoter1-Realm", "WARRIOR", { LOOTHING_RESPONSE.NEED })
    serItem:AddVote("SerVoter2-Realm", "MAGE", { LOOTHING_RESPONSE.GREED })
    serItem:SetWinner("SerWinner-Realm", LOOTHING_RESPONSE.NEED)

    -- Serialize
    local serialized = serItem:Serialize()
    assertNotNil(serialized, "Serialize returns table")
    assertEqual(serialized.guid, serItem.guid, "Serialized GUID matches")
    assertEqual(serialized.itemLink, testItemLink, "Serialized itemLink matches")
    assertEqual(serialized.looter, testLooter, "Serialized looter matches")
    assertEqual(serialized.state, LOOTHING_ITEM_STATE.AWARDED, "Serialized state matches")
    assertEqual(serialized.winner, "SerWinner-Realm", "Serialized winner matches")
    assertNotNil(serialized.votes, "Serialized votes present")
    assertEqual(#serialized.votes, 2, "Serialized votes count correct")

    -- Deserialize
    local deserItem = CreateLoothingItem(testItemLink, testLooter, testEncounterID)
    deserItem:Deserialize(serialized)
    assertEqual(deserItem.guid, serialized.guid, "Deserialized GUID matches")
    assertEqual(deserItem.itemLink, serialized.itemLink, "Deserialized itemLink matches")
    assertEqual(deserItem.state, serialized.state, "Deserialized state matches")
    assertEqual(deserItem.winner, serialized.winner, "Deserialized winner matches")
    assertEqual(deserItem:GetVoteCount(), 2, "Deserialized votes restored")

    --[[--------------------------------------------------------------------
        Test Group 7: Edge Cases
    ----------------------------------------------------------------------]]
    printGroup("Edge Cases")

    -- Nil item link handling
    local nilLinkItem = CreateLoothingItem(nil, testLooter, testEncounterID)
    assertNotNil(nilLinkItem, "Item created with nil link")
    assertEqual(nilLinkItem.itemLink, nil, "Nil link stored as nil")

    -- Invalid item link
    local invalidLinkItem = CreateLoothingItem("not_a_link", testLooter, testEncounterID)
    assertNotNil(invalidLinkItem, "Item created with invalid link")
    assertEqual(invalidLinkItem.name, "Unknown", "Invalid link gets 'Unknown' name")

    -- Empty voter handling
    local emptyVoteItem = CreateLoothingItem(testItemLink, testLooter, testEncounterID)
    emptyVoteItem:SetState(LOOTHING_ITEM_STATE.VOTING)
    assertEqual(emptyVoteItem:GetVoteCount(), 0, "Empty votes returns 0 count")
    assertEqual(emptyVoteItem:GetVoteByVoter("NonExistent-Realm"), nil, "Non-existent voter returns nil")
    assert(not emptyVoteItem:HasVoted("NonExistent-Realm"), "HasVoted false for non-existent voter")

    -- Remove non-existent vote
    local removeNonExistent = emptyVoteItem:RemoveVote("NonExistent-Realm")
    assert(not removeNonExistent, "RemoveVote returns false for non-existent vote")

    -- Get votes by response with no votes
    local noNeedVotes = emptyVoteItem:GetVotesByResponse(LOOTHING_RESPONSE.NEED)
    assertEqual(#noNeedVotes, 0, "GetVotesByResponse returns empty table")

    -- Callback registry initialized
    local callbackItem = CreateLoothingItem(testItemLink, testLooter, testEncounterID)
    assertNotNil(callbackItem.RegisterCallback, "Item has callback registry")

    --[[--------------------------------------------------------------------
        Test Group 8: Display Helpers
    ----------------------------------------------------------------------]]
    printGroup("Display Helpers")

    local displayItem = CreateLoothingItem(testItemLink, testLooter, testEncounterID)

    -- Quality color
    local color = displayItem:GetQualityColor()
    assertNotNil(color, "GetQualityColor returns table")
    assertNotNil(color.r, "Color has red component")
    assertNotNil(color.g, "Color has green component")
    assertNotNil(color.b, "Color has blue component")

    -- Status text
    assertEqual(type(displayItem:GetStatusText()), "string", "GetStatusText returns string")
    displayItem:SetState(LOOTHING_ITEM_STATE.VOTING)
    assertNotNil(displayItem:GetStatusText(), "GetStatusText returns text for VOTING")

    --[[--------------------------------------------------------------------
        Test Group 9: Candidate Manager Integration
    ----------------------------------------------------------------------]]
    printGroup("Candidate Manager")

    local candItem = CreateLoothingItem(testItemLink, testLooter, testEncounterID)

    -- Get candidate manager (lazy initialization)
    local manager = candItem:GetCandidateManager()
    assertNotNil(manager, "GetCandidateManager returns manager")

    -- Same manager on subsequent calls
    local manager2 = candItem:GetCandidateManager()
    assert(manager == manager2, "GetCandidateManager returns same instance")

    -- Get or create candidate (if function exists)
    if candItem.GetOrCreateCandidate then
        local candidate = candItem:GetOrCreateCandidate("TestPlayer-Realm", "WARRIOR")
        assertNotNil(candidate, "GetOrCreateCandidate returns candidate")
    end

    -- Print summary
    print("\n|cff00ccff========== Test Summary ==========|r")
    print(string.format("|cff00ff00Passed: %d|r", passed))
    print(string.format("|cffff0000Failed: %d|r", failed))
    print(string.format("Total: %d", passed + failed))

    if failed == 0 then
        print("|cff00ff00All tests passed!|r")
    else
        print("|cffff0000Some tests failed!|r")
    end
end

