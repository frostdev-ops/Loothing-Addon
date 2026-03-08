--[[--------------------------------------------------------------------
    Loothing - Voting Tests
    Comprehensive test suite for voting mechanics and tallying
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

local function AssertGreaterOrEqual(actual, threshold, message)
    return Assert(actual >= threshold,
        string.format("%s (expected >= %s, got: %s)", message, tostring(threshold), tostring(actual)))
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
    print("\n=== Voting Test Results ===")
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

local function CreateVoteArray(votes)
    -- votes = { { voter, class, responses }, ... }
    local result = {}
    for _, v in ipairs(votes) do
        table.insert(result, {
            voter = v[1],
            voterClass = v[2],
            responses = v[3],
            timestamp = time()
        })
    end
    return result
end

local function CreateVoteDataProvider(votes)
    local Loolib = LibStub("Loolib")
    local Data = Loolib:GetModule("Data")
    local provider = Data.CreateDataProvider()

    for _, vote in ipairs(votes) do
        provider:Insert(vote)
    end

    return provider
end

--[[--------------------------------------------------------------------
    1. Simple Voting Tests
----------------------------------------------------------------------]]

Describe("Simple Voting - Basic Operations", function()
    It("Single vote counted correctly", function()
        local votes = CreateVoteArray({
            { "Player1", "WARRIOR", { LOOTHING_RESPONSE.NEED } }
        })

        local results = LoothingVotingEngine:TallySimple(votes)

        AssertNotNil(results, "Results should not be nil")
        AssertEquals(results.winningResponse, LOOTHING_RESPONSE.NEED, "NEED should win")
        AssertEquals(results.counts[LOOTHING_RESPONSE.NEED].count, 1, "NEED should have 1 vote")
        AssertEquals(results.totalVotes, 1, "Total votes should be 1")
    end)

    It("Multiple votes accumulated", function()
        local votes = CreateVoteArray({
            { "Player1", "WARRIOR", { LOOTHING_RESPONSE.NEED } },
            { "Player2", "MAGE", { LOOTHING_RESPONSE.NEED } },
            { "Player3", "PRIEST", { LOOTHING_RESPONSE.GREED } }
        })

        local results = LoothingVotingEngine:TallySimple(votes)

        AssertEquals(results.counts[LOOTHING_RESPONSE.NEED].count, 2, "NEED should have 2 votes")
        AssertEquals(results.counts[LOOTHING_RESPONSE.GREED].count, 1, "GREED should have 1 vote")
        AssertEquals(results.totalVotes, 3, "Total votes should be 3")
    end)

    It("Vote counts match response distribution", function()
        local votes = CreateVoteArray({
            { "P1", "WARRIOR", { LOOTHING_RESPONSE.NEED } },
            { "P2", "WARRIOR", { LOOTHING_RESPONSE.NEED } },
            { "P3", "MAGE", { LOOTHING_RESPONSE.GREED } },
            { "P4", "PRIEST", { LOOTHING_RESPONSE.OFFSPEC } },
            { "P5", "ROGUE", { LOOTHING_RESPONSE.PASS } }
        })

        local results = LoothingVotingEngine:TallySimple(votes)

        AssertEquals(results.counts[LOOTHING_RESPONSE.NEED].count, 2, "NEED count")
        AssertEquals(results.counts[LOOTHING_RESPONSE.GREED].count, 1, "GREED count")
        AssertEquals(results.counts[LOOTHING_RESPONSE.OFFSPEC].count, 1, "OFFSPEC count")
        AssertEquals(results.counts[LOOTHING_RESPONSE.PASS].count, 1, "PASS count")
        AssertEquals(results.totalVotes, 5, "Total votes")
    end)

    It("Highest vote wins", function()
        local votes = CreateVoteArray({
            { "P1", "WARRIOR", { LOOTHING_RESPONSE.GREED } },
            { "P2", "MAGE", { LOOTHING_RESPONSE.NEED } },
            { "P3", "PRIEST", { LOOTHING_RESPONSE.NEED } },
            { "P4", "ROGUE", { LOOTHING_RESPONSE.NEED } }
        })

        local results = LoothingVotingEngine:TallySimple(votes)

        AssertEquals(results.winningResponse, LOOTHING_RESPONSE.NEED, "NEED should win with 3 votes")
        AssertEquals(results.counts[LOOTHING_RESPONSE.NEED].count, 3, "NEED vote count")
    end)

    It("Voters list is tracked", function()
        local votes = CreateVoteArray({
            { "Alice", "WARRIOR", { LOOTHING_RESPONSE.NEED } },
            { "Bob", "MAGE", { LOOTHING_RESPONSE.NEED } }
        })

        local results = LoothingVotingEngine:TallySimple(votes)

        AssertEquals(#results.counts[LOOTHING_RESPONSE.NEED].voters, 2, "NEED should have 2 voters")

        local hasAlice = false
        local hasBob = false
        for _, voter in ipairs(results.counts[LOOTHING_RESPONSE.NEED].voters) do
            if voter == "Alice" then hasAlice = true end
            if voter == "Bob" then hasBob = true end
        end

        AssertTrue(hasAlice, "Alice should be in voters list")
        AssertTrue(hasBob, "Bob should be in voters list")
    end)
end)

--[[--------------------------------------------------------------------
    2. Ranked Choice Voting Tests
----------------------------------------------------------------------]]

Describe("Ranked Choice Voting - Basic Mechanics", function()
    It("First choices counted initially", function()
        local votes = CreateVoteArray({
            { "P1", "WARRIOR", { "Alice", "Bob", "Charlie" } },
            { "P2", "MAGE", { "Alice", "Charlie", "Bob" } },
            { "P3", "PRIEST", { "Bob", "Alice", "Charlie" } }
        })

        local candidates = { "Alice", "Bob", "Charlie" }
        local results = LoothingVotingEngine:TallyRankedChoice(votes, candidates)

        AssertNotNil(results, "Results should not be nil")
        AssertNotNil(results.rounds, "Should have rounds")
        AssertGreaterThan(#results.rounds, 0, "Should have at least one round")

        local round1 = results.rounds[1]
        AssertEquals(round1.counts[LoothingUtils.NormalizeName("Alice")], 2, "Alice should have 2 first-choice votes")
        AssertEquals(round1.counts[LoothingUtils.NormalizeName("Bob")], 1, "Bob should have 1 first-choice vote")
    end)

    It("Elimination of lowest candidate", function()
        local votes = CreateVoteArray({
            { "P1", "WARRIOR", { "Alice", "Bob", "Charlie" } },
            { "P2", "MAGE", { "Alice", "Charlie", "Bob" } },
            { "P3", "PRIEST", { "Bob", "Alice", "Charlie" } },
            { "P4", "ROGUE", { "Charlie", "Bob", "Alice" } }
        })

        local candidates = { "Alice", "Bob", "Charlie" }
        local results = LoothingVotingEngine:TallyRankedChoice(votes, candidates)

        AssertNotNil(results.eliminated, "Should have elimination list")
        AssertGreaterThan(#results.eliminated, 0, "Should have eliminated candidates")

        -- Check that someone was eliminated
        local eliminated = results.eliminated[1]
        AssertNotNil(eliminated.candidate, "Eliminated entry should have candidate")
        AssertNotNil(eliminated.round, "Eliminated entry should have round")
        AssertNotNil(eliminated.count, "Eliminated entry should have vote count")
    end)

    It("Vote redistribution works", function()
        -- Setup: Alice has 2, Bob has 1, Charlie has 1
        -- Charlie eliminated, vote goes to second choice
        local votes = CreateVoteArray({
            { "P1", "WARRIOR", { "Alice", "Bob" } },
            { "P2", "MAGE", { "Alice", "Bob" } },
            { "P3", "PRIEST", { "Bob", "Alice" } },
            { "P4", "ROGUE", { "Charlie", "Alice" } } -- Will redistribute to Alice
        })

        local candidates = { "Alice", "Bob", "Charlie" }
        local results = LoothingVotingEngine:TallyRankedChoice(votes, candidates)

        -- With redistribution, Alice should win
        AssertNotNil(results.winner, "Should have a winner")
    end)

    It("Majority winner detected", function()
        local votes = CreateVoteArray({
            { "P1", "WARRIOR", { "Alice", "Bob" } },
            { "P2", "MAGE", { "Alice", "Charlie" } },
            { "P3", "PRIEST", { "Alice", "Bob" } }
        })

        local candidates = { "Alice", "Bob", "Charlie" }
        local results = LoothingVotingEngine:TallyRankedChoice(votes, candidates)

        AssertEquals(results.winner, LoothingUtils.NormalizeName("Alice"), "Alice should win with majority")
        AssertEquals(#results.rounds, 1, "Should only need one round for majority")
    end)

    It("Multi-round elimination", function()
        local votes = CreateVoteArray({
            { "P1", "WARRIOR", { "Alice", "Bob", "Charlie", "Dave" } },
            { "P2", "MAGE", { "Bob", "Alice", "Charlie", "Dave" } },
            { "P3", "PRIEST", { "Charlie", "Alice", "Bob", "Dave" } },
            { "P4", "ROGUE", { "Dave", "Charlie", "Bob", "Alice" } }
        })

        local candidates = { "Alice", "Bob", "Charlie", "Dave" }
        local results = LoothingVotingEngine:TallyRankedChoice(votes, candidates)

        AssertGreaterThan(#results.rounds, 1, "Should have multiple rounds")
        AssertGreaterThan(#results.eliminated, 1, "Should eliminate multiple candidates")
    end)
end)

--[[--------------------------------------------------------------------
    3. Tie Breaking Tests
----------------------------------------------------------------------]]

Describe("Tie Breaking", function()
    It("Tie detected correctly in simple voting", function()
        local votes = CreateVoteArray({
            { "P1", "WARRIOR", { LOOTHING_RESPONSE.NEED } },
            { "P2", "MAGE", { LOOTHING_RESPONSE.GREED } }
        })

        local results = LoothingVotingEngine:TallySimple(votes)

        AssertTrue(results.isTie, "Should detect tie")
        AssertNotNil(results.tiedResponses, "Should have tied responses list")
        AssertEquals(#results.tiedResponses, 2, "Should have 2 tied responses")
    end)

    It("Random tiebreaker returns one of tied candidates", function()
        local tiedCandidates = { "Alice", "Bob", "Charlie" }

        local winner = LoothingVotingEngine:BreakTie(tiedCandidates, {}, "random")

        AssertNotNil(winner, "Should return a winner")

        local found = false
        for _, candidate in ipairs(tiedCandidates) do
            if candidate == winner then
                found = true
                break
            end
        end

        AssertTrue(found, "Winner should be one of the tied candidates")
    end)

    It("Alphabetical tiebreaker returns first alphabetically", function()
        local tiedCandidates = { "Charlie", "Alice", "Bob" }

        local winner = LoothingVotingEngine:BreakTie(tiedCandidates, {}, "alphabetical")

        AssertEquals(winner, "Alice", "Alice should win alphabetically")
    end)

    It("Manual tiebreaker returns nil", function()
        local tiedCandidates = { "Alice", "Bob" }

        local winner = LoothingVotingEngine:BreakTie(tiedCandidates, {}, "manual")

        AssertNil(winner, "Manual mode should return nil for ML decision")
    end)

    It("Single candidate tie returns that candidate", function()
        local tiedCandidates = { "OnlyOne" }

        local winner = LoothingVotingEngine:BreakTie(tiedCandidates, {}, "random")

        AssertEquals(winner, "OnlyOne", "Should return the only candidate")
    end)

    It("Empty tie list returns nil", function()
        local tiedCandidates = {}

        local winner = LoothingVotingEngine:BreakTie(tiedCandidates, {}, "random")

        AssertNil(winner, "Should return nil for empty list")
    end)

    It("No tie when clear winner", function()
        local votes = CreateVoteArray({
            { "P1", "WARRIOR", { LOOTHING_RESPONSE.NEED } },
            { "P2", "MAGE", { LOOTHING_RESPONSE.NEED } },
            { "P3", "PRIEST", { LOOTHING_RESPONSE.GREED } }
        })

        local results = LoothingVotingEngine:TallySimple(votes)

        AssertFalse(results.isTie, "Should not be a tie")
        AssertNil(results.tiedResponses, "Should not have tied responses")
    end)
end)

--[[--------------------------------------------------------------------
    4. Vote Tallying Tests
----------------------------------------------------------------------]]

Describe("Vote Tallying - Results Structure", function()
    It("TallySimple returns correct structure", function()
        local votes = CreateVoteArray({
            { "P1", "WARRIOR", { LOOTHING_RESPONSE.NEED } }
        })

        local results = LoothingVotingEngine:TallySimple(votes)

        AssertNotNil(results.winningResponse, "Should have winningResponse")
        AssertNotNil(results.counts, "Should have counts")
        AssertNotNil(results.totalVotes, "Should have totalVotes")
        AssertNotNil(results.isTie, "Should have isTie")
    end)

    It("TallyRankedChoice returns rounds", function()
        local votes = CreateVoteArray({
            { "P1", "WARRIOR", { "Alice", "Bob" } },
            { "P2", "MAGE", { "Bob", "Alice" } }
        })

        local candidates = { "Alice", "Bob" }
        local results = LoothingVotingEngine:TallyRankedChoice(votes, candidates)

        AssertNotNil(results.rounds, "Should have rounds")
        AssertNotNil(results.eliminated, "Should have eliminated list")
        AssertNotNil(results.totalVotes, "Should have totalVotes")

        if #results.rounds > 0 then
            local round = results.rounds[1]
            AssertNotNil(round.round, "Round should have round number")
            AssertNotNil(round.counts, "Round should have counts")
        end
    end)

    It("GetVotePercentages calculates correctly", function()
        local votes = CreateVoteArray({
            { "P1", "WARRIOR", { LOOTHING_RESPONSE.NEED } },
            { "P2", "MAGE", { LOOTHING_RESPONSE.NEED } },
            { "P3", "PRIEST", { LOOTHING_RESPONSE.GREED } },
            { "P4", "ROGUE", { LOOTHING_RESPONSE.PASS } }
        })

        local percentages = LoothingVotingEngine:GetVotePercentages(votes)

        AssertEquals(percentages[LOOTHING_RESPONSE.NEED], 50, "NEED should be 50%")
        AssertEquals(percentages[LOOTHING_RESPONSE.GREED], 25, "GREED should be 25%")
        AssertEquals(percentages[LOOTHING_RESPONSE.PASS], 25, "PASS should be 25%")
    end)

    It("GetResponseSummary formats correctly", function()
        local votes = CreateVoteArray({
            { "P1", "WARRIOR", { LOOTHING_RESPONSE.NEED } },
            { "P2", "MAGE", { LOOTHING_RESPONSE.GREED } }
        })

        local summary = LoothingVotingEngine:GetResponseSummary(votes)

        AssertNotNil(summary, "Summary should not be nil")
        AssertGreaterThan(#summary, 0, "Summary should have entries")

        local firstEntry = summary[1]
        AssertNotNil(firstEntry.response, "Entry should have response")
        AssertNotNil(firstEntry.responseInfo, "Entry should have responseInfo")
        AssertNotNil(firstEntry.count, "Entry should have count")
        AssertNotNil(firstEntry.voters, "Entry should have voters")
        AssertNotNil(firstEntry.percentage, "Entry should have percentage")
    end)

    It("GroupVotersByResponse groups correctly", function()
        local votes = CreateVoteArray({
            { "Alice", "WARRIOR", { LOOTHING_RESPONSE.NEED } },
            { "Bob", "MAGE", { LOOTHING_RESPONSE.NEED } },
            { "Charlie", "PRIEST", { LOOTHING_RESPONSE.GREED } }
        })

        local groups = LoothingVotingEngine:GroupVotersByResponse(votes)

        AssertEquals(#groups[LOOTHING_RESPONSE.NEED], 2, "NEED should have 2 voters")
        AssertEquals(#groups[LOOTHING_RESPONSE.GREED], 1, "GREED should have 1 voter")
    end)

    It("HasClearWinner detects clear winner", function()
        local votes = CreateVoteArray({
            { "P1", "WARRIOR", { LOOTHING_RESPONSE.NEED } },
            { "P2", "MAGE", { LOOTHING_RESPONSE.NEED } },
            { "P3", "PRIEST", { LOOTHING_RESPONSE.NEED } },
            { "P4", "ROGUE", { LOOTHING_RESPONSE.GREED } }
        })

        local hasClear, winner = LoothingVotingEngine:HasClearWinner(votes, 50)

        AssertTrue(hasClear, "Should have clear winner at 50% threshold")
        AssertEquals(winner, LOOTHING_RESPONSE.NEED, "NEED should be the winner")
    end)

    It("HasClearWinner fails without majority", function()
        local votes = CreateVoteArray({
            { "P1", "WARRIOR", { LOOTHING_RESPONSE.NEED } },
            { "P2", "MAGE", { LOOTHING_RESPONSE.GREED } },
            { "P3", "PRIEST", { LOOTHING_RESPONSE.OFFSPEC } }
        })

        local hasClear, winner = LoothingVotingEngine:HasClearWinner(votes, 50)

        AssertFalse(hasClear, "Should not have clear winner")
    end)
end)

--[[--------------------------------------------------------------------
    5. Edge Cases Tests
----------------------------------------------------------------------]]

Describe("Edge Cases", function()
    It("Zero votes handling in simple mode", function()
        local votes = CreateVoteArray({})

        local results = LoothingVotingEngine:TallySimple(votes)

        AssertEquals(results.totalVotes, 0, "Total votes should be 0")
        AssertNil(results.winningResponse, "Should have no winning response")
    end)

    It("Zero votes handling in ranked choice", function()
        local votes = CreateVoteArray({})
        local candidates = { "Alice", "Bob" }

        local results = LoothingVotingEngine:TallyRankedChoice(votes, candidates)

        AssertNil(results.winner, "Should have no winner")
        AssertEquals(#results.rounds, 0, "Should have no rounds")
    end)

    It("Single voter", function()
        local votes = CreateVoteArray({
            { "OnlyVoter", "WARRIOR", { LOOTHING_RESPONSE.NEED } }
        })

        local results = LoothingVotingEngine:TallySimple(votes)

        AssertEquals(results.totalVotes, 1, "Should have 1 vote")
        AssertEquals(results.winningResponse, LOOTHING_RESPONSE.NEED, "Single vote should win")
        AssertFalse(results.isTie, "Single vote is not a tie")
    end)

    It("All same response", function()
        local votes = CreateVoteArray({
            { "P1", "WARRIOR", { LOOTHING_RESPONSE.NEED } },
            { "P2", "MAGE", { LOOTHING_RESPONSE.NEED } },
            { "P3", "PRIEST", { LOOTHING_RESPONSE.NEED } }
        })

        local results = LoothingVotingEngine:TallySimple(votes)

        AssertEquals(results.winningResponse, LOOTHING_RESPONSE.NEED, "NEED should win")
        AssertEquals(results.counts[LOOTHING_RESPONSE.NEED].count, 3, "NEED should have all votes")
        AssertFalse(results.isTie, "Unanimous vote is not a tie")
    end)

    It("All pass votes", function()
        local votes = CreateVoteArray({
            { "P1", "WARRIOR", { LOOTHING_RESPONSE.PASS } },
            { "P2", "MAGE", { LOOTHING_RESPONSE.PASS } },
            { "P3", "PRIEST", { LOOTHING_RESPONSE.PASS } }
        })

        local results = LoothingVotingEngine:TallySimple(votes)

        AssertEquals(results.winningResponse, LOOTHING_RESPONSE.PASS, "PASS should win")
        AssertEquals(results.counts[LOOTHING_RESPONSE.PASS].count, 3, "All should be PASS")
    end)

    It("Empty responses array", function()
        local votes = CreateVoteArray({
            { "P1", "WARRIOR", {} }
        })

        local results = LoothingVotingEngine:TallySimple(votes)

        -- Should handle gracefully without crashing
        AssertNotNil(results, "Results should exist")
    end)

    It("DataProvider input works same as array", function()
        local votesArray = CreateVoteArray({
            { "P1", "WARRIOR", { LOOTHING_RESPONSE.NEED } },
            { "P2", "MAGE", { LOOTHING_RESPONSE.GREED } }
        })

        local votesProvider = CreateVoteDataProvider(votesArray)

        local resultsArray = LoothingVotingEngine:TallySimple(votesArray)
        local resultsProvider = LoothingVotingEngine:TallySimple(votesProvider)

        AssertEquals(resultsArray.totalVotes, resultsProvider.totalVotes, "Total votes should match")
        AssertEquals(resultsArray.winningResponse, resultsProvider.winningResponse, "Winning response should match")
    end)

    It("CountVotes handles both DataProvider and array", function()
        local votesArray = CreateVoteArray({
            { "P1", "WARRIOR", { LOOTHING_RESPONSE.NEED } },
            { "P2", "MAGE", { LOOTHING_RESPONSE.GREED } }
        })

        local votesProvider = CreateVoteDataProvider(votesArray)

        local countArray = LoothingVotingEngine:CountVotes(votesArray)
        local countProvider = LoothingVotingEngine:CountVotes(votesProvider)

        AssertEquals(countArray, 2, "Array should have 2 votes")
        AssertEquals(countProvider, 2, "DataProvider should have 2 votes")
    end)

    It("Ranked choice with empty candidates list", function()
        local votes = CreateVoteArray({
            { "P1", "WARRIOR", { "Alice" } }
        })

        local candidates = {}
        local results = LoothingVotingEngine:TallyRankedChoice(votes, candidates)

        AssertNil(results.winner, "Should have no winner with empty candidates")
        AssertEquals(#results.rounds, 0, "Should have no rounds")
    end)

    It("Ranked choice with more votes than candidates", function()
        local votes = CreateVoteArray({
            { "P1", "WARRIOR", { "Alice", "Bob" } },
            { "P2", "MAGE", { "Alice", "Bob" } },
            { "P3", "PRIEST", { "Bob", "Alice" } },
            { "P4", "ROGUE", { "Alice", "Bob" } },
            { "P5", "HUNTER", { "Alice", "Bob" } }
        })

        local candidates = { "Alice", "Bob" }
        local results = LoothingVotingEngine:TallyRankedChoice(votes, candidates)

        AssertNotNil(results.winner, "Should have a winner")
        AssertEquals(results.winner, LoothingUtils.NormalizeName("Alice"), "Alice should win")
    end)

    It("Percentage calculation with zero votes", function()
        local votes = CreateVoteArray({})

        local percentages = LoothingVotingEngine:GetVotePercentages(votes)

        for response, percentage in pairs(percentages) do
            AssertEquals(percentage, 0, string.format("Response %d should have 0%%", response))
        end
    end)
end)

--[[--------------------------------------------------------------------
    6. Integration Tests (Voting with Item)
----------------------------------------------------------------------]]

Describe("Integration with Item System", function()
    It("Item accepts and stores votes", function()
        local item = CreateLoothingItem("|cffa335ee|Hitem:212398::::::::80::::::::::|h[Epic Sword]|h|r", "Looter", 123)

        item:StartVoting(30)

        AssertTrue(item:AddVote("Voter1", "WARRIOR", { LOOTHING_RESPONSE.NEED }), "Should add vote")
        AssertEquals(item:GetVoteCount(), 1, "Should have 1 vote")

        local vote = item:GetVoteByVoter("Voter1")
        AssertNotNil(vote, "Should retrieve vote by voter")
        AssertEquals(vote.responses[1], LOOTHING_RESPONSE.NEED, "Vote response should match")
    end)

    It("Cannot add vote when not in VOTING state", function()
        local item = CreateLoothingItem("|cffa335ee|Hitem:212398::::::::80::::::::::|h[Epic Sword]|h|r", "Looter", 123)

        local added = item:AddVote("Voter1", "WARRIOR", { LOOTHING_RESPONSE.NEED })

        AssertFalse(added, "Should not add vote when not voting")
        AssertEquals(item:GetVoteCount(), 0, "Should have 0 votes")
    end)

    It("Vote update replaces existing vote", function()
        local item = CreateLoothingItem("|cffa335ee|Hitem:212398::::::::80::::::::::|h[Epic Sword]|h|r", "Looter", 123)

        item:StartVoting(30)
        item:AddVote("Voter1", "WARRIOR", { LOOTHING_RESPONSE.NEED })
        item:AddVote("Voter1", "WARRIOR", { LOOTHING_RESPONSE.GREED })

        AssertEquals(item:GetVoteCount(), 1, "Should still have 1 vote")

        local vote = item:GetVoteByVoter("Voter1")
        AssertEquals(vote.responses[1], LOOTHING_RESPONSE.GREED, "Vote should be updated to GREED")
    end)

    It("GetVotesByResponse filters correctly", function()
        local item = CreateLoothingItem("|cffa335ee|Hitem:212398::::::::80::::::::::|h[Epic Sword]|h|r", "Looter", 123)

        item:StartVoting(30)
        item:AddVote("V1", "WARRIOR", { LOOTHING_RESPONSE.NEED })
        item:AddVote("V2", "MAGE", { LOOTHING_RESPONSE.NEED })
        item:AddVote("V3", "PRIEST", { LOOTHING_RESPONSE.GREED })

        local needVotes = item:GetVotesByResponse(LOOTHING_RESPONSE.NEED)
        local greedVotes = item:GetVotesByResponse(LOOTHING_RESPONSE.GREED)

        AssertEquals(#needVotes, 2, "Should have 2 NEED votes")
        AssertEquals(#greedVotes, 1, "Should have 1 GREED vote")
    end)

    It("Item vote tallying integrates with VotingEngine", function()
        local item = CreateLoothingItem("|cffa335ee|Hitem:212398::::::::80::::::::::|h[Epic Sword]|h|r", "Looter", 123)

        item:StartVoting(30)
        item:AddVote("V1", "WARRIOR", { LOOTHING_RESPONSE.NEED })
        item:AddVote("V2", "MAGE", { LOOTHING_RESPONSE.NEED })
        item:AddVote("V3", "PRIEST", { LOOTHING_RESPONSE.GREED })

        local results = LoothingVotingEngine:Tally(item:GetVotes())

        AssertNotNil(results, "Should have tally results")
        AssertEquals(results.winningResponse, LOOTHING_RESPONSE.NEED, "NEED should win")
    end)

    It("RemoveVote removes from item", function()
        local item = CreateLoothingItem("|cffa335ee|Hitem:212398::::::::80::::::::::|h[Epic Sword]|h|r", "Looter", 123)

        item:StartVoting(30)
        item:AddVote("Voter1", "WARRIOR", { LOOTHING_RESPONSE.NEED })

        AssertEquals(item:GetVoteCount(), 1, "Should have 1 vote")

        local removed = item:RemoveVote("Voter1")

        AssertTrue(removed, "Should remove vote")
        AssertEquals(item:GetVoteCount(), 0, "Should have 0 votes after removal")
    end)
end)

--[[--------------------------------------------------------------------
    Run All Tests
----------------------------------------------------------------------]]

local function RunAllVotingTests()
    print("=== Running Voting Tests ===")

    -- Reset counters
    Tests.passed = 0
    Tests.failed = 0
    Tests.results = {}
    Tests.categories = {}

    -- Run tests (they call Describe internally)

    PrintResults()
end

