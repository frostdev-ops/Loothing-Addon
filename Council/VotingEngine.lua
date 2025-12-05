--[[--------------------------------------------------------------------
    Loothing - Loot Council Addon for WoW 12.0+
    VotingEngine - Vote tallying algorithms
----------------------------------------------------------------------]]

--[[--------------------------------------------------------------------
    LoothingVotingEngine (Singleton)
----------------------------------------------------------------------]]

LoothingVotingEngine = {}

--[[--------------------------------------------------------------------
    Generic Tally - Dispatches to appropriate method based on voting mode
----------------------------------------------------------------------]]

--- Tally votes using the configured voting mode
-- @param votes table - DataProvider or array of votes
-- @param mode string|nil - Optional voting mode override (defaults to settings)
-- @return table - Results from the appropriate tally method
function LoothingVotingEngine:Tally(votes, mode)
    -- Get mode from settings if not provided
    mode = mode or (Loothing.Settings and Loothing.Settings:GetVotingMode()) or LOOTHING_VOTING_MODE.SIMPLE

    if mode == LOOTHING_VOTING_MODE.RANKED_CHOICE then
        -- For ranked choice, we need to extract candidates from the votes
        local candidates = self:GetCandidatesFromVotes(votes)
        return self:TallyRankedChoice(votes, candidates)
    else
        return self:TallySimple(votes)
    end
end

--- Extract unique candidates from votes (for ranked choice)
-- @param votes table - DataProvider or array of votes
-- @return table - Array of unique voter names who cast first-choice votes
function LoothingVotingEngine:GetCandidatesFromVotes(votes)
    local candidateSet = {}
    local candidates = {}

    local enumerate = votes.Enumerate and function() return votes:Enumerate() end or function() return ipairs(votes) end
    for _, vote in enumerate() do
        local firstChoice = vote.responses and vote.responses[1]
        if firstChoice and not candidateSet[firstChoice] then
            candidateSet[firstChoice] = true
            candidates[#candidates + 1] = firstChoice
        end
    end

    return candidates
end

--[[--------------------------------------------------------------------
    Simple Voting - Most votes wins
----------------------------------------------------------------------]]

--- Tally votes using simple majority
-- @param votes table - DataProvider or array of votes
-- @param candidates table - Array of candidate names (optional, for filtering)
-- @return table - { winner, response, counts, isTie, tiedCandidates }
function LoothingVotingEngine:TallySimple(votes, candidates)
    local counts = {}
    local candidateSet = nil

    -- Build candidate set if provided
    if candidates then
        candidateSet = {}
        for _, name in ipairs(candidates) do
            candidateSet[LoothingUtils.NormalizeName(name)] = true
        end
    end

    -- Initialize response counts
    for _, response in pairs(LOOTHING_RESPONSE) do
        counts[response] = {
            count = 0,
            voters = {},
        }
    end

    -- Count votes
    local enumerate = votes.Enumerate and function() return votes:Enumerate() end or function() return ipairs(votes) end
    for _, vote in enumerate() do
        local firstChoice = vote.responses and vote.responses[1]
        if firstChoice and counts[firstChoice] then
            -- If we have candidates, only count if voter voted for a candidate
            -- (In simple mode, we're counting response types, not individual candidates)
            counts[firstChoice].count = counts[firstChoice].count + 1
            counts[firstChoice].voters[#counts[firstChoice].voters + 1] = vote.voter
        end
    end

    -- Find the winning response
    local maxCount = 0
    local winningResponse = nil
    local tied = {}

    for response, data in pairs(counts) do
        if data.count > maxCount then
            maxCount = data.count
            winningResponse = response
            tied = { response }
        elseif data.count == maxCount and data.count > 0 then
            tied[#tied + 1] = response
        end
    end

    local isTie = #tied > 1

    return {
        winningResponse = winningResponse,
        counts = counts,
        isTie = isTie,
        tiedResponses = isTie and tied or nil,
        totalVotes = self:CountVotes(votes),
    }
end

--[[--------------------------------------------------------------------
    Ranked Choice Voting - Instant Runoff
----------------------------------------------------------------------]]

--- Tally votes using ranked choice (instant runoff)
-- @param votes table - DataProvider or array of votes
-- @param candidates table - Array of candidate names
-- @return table - { winner, rounds, eliminated }
function LoothingVotingEngine:TallyRankedChoice(votes, candidates)
    if not candidates or #candidates == 0 then
        return { winner = nil, rounds = {}, eliminated = {} }
    end

    -- Normalize candidate names
    local activeCandidates = {}
    for _, name in ipairs(candidates) do
        activeCandidates[LoothingUtils.NormalizeName(name)] = true
    end

    -- Convert votes to working format
    local workingVotes = {}
    local enumerate = votes.Enumerate and function() return votes:Enumerate() end or function() return ipairs(votes) end
    for _, vote in enumerate() do
        if vote.responses and #vote.responses > 0 then
            workingVotes[#workingVotes + 1] = {
                voter = vote.voter,
                responses = { unpack(vote.responses) }, -- Copy
            }
        end
    end

    local rounds = {}
    local eliminated = {}
    local totalVoters = #workingVotes
    local majorityThreshold = math.floor(totalVoters / 2) + 1

    -- Run rounds until we have a winner
    local maxRounds = #candidates -- Safety limit
    for round = 1, maxRounds do
        local roundCounts = self:CountFirstChoices(workingVotes, activeCandidates)
        rounds[#rounds + 1] = {
            round = round,
            counts = roundCounts,
            eliminated = nil,
        }

        -- Check for majority winner
        for candidate, count in pairs(roundCounts) do
            if count >= majorityThreshold then
                return {
                    winner = candidate,
                    rounds = rounds,
                    eliminated = eliminated,
                    totalVotes = totalVoters,
                }
            end
        end

        -- No majority - eliminate candidate with fewest votes
        local minCount = math.huge
        local toEliminate = nil
        local tiedForLast = {}

        for candidate, count in pairs(roundCounts) do
            if count < minCount then
                minCount = count
                toEliminate = candidate
                tiedForLast = { candidate }
            elseif count == minCount then
                tiedForLast[#tiedForLast + 1] = candidate
            end
        end

        -- Handle tie for last place - eliminate all tied
        if #tiedForLast > 1 then
            for _, candidate in ipairs(tiedForLast) do
                activeCandidates[candidate] = nil
                eliminated[#eliminated + 1] = {
                    candidate = candidate,
                    round = round,
                    count = minCount,
                    reason = "tied_for_last",
                }
            end
            rounds[#rounds].eliminated = tiedForLast
        else
            activeCandidates[toEliminate] = nil
            eliminated[#eliminated + 1] = {
                candidate = toEliminate,
                round = round,
                count = minCount,
                reason = "fewest_votes",
            }
            rounds[#rounds].eliminated = { toEliminate }
        end

        -- Redistribute votes from eliminated candidates
        self:RedistributeVotes(workingVotes, activeCandidates)

        -- Check if only one candidate remains
        local remaining = 0
        local lastCandidate = nil
        for candidate in pairs(activeCandidates) do
            remaining = remaining + 1
            lastCandidate = candidate
        end

        if remaining == 1 then
            return {
                winner = lastCandidate,
                rounds = rounds,
                eliminated = eliminated,
                totalVotes = totalVoters,
            }
        elseif remaining == 0 then
            -- All candidates eliminated (shouldn't happen with proper data)
            return {
                winner = nil,
                rounds = rounds,
                eliminated = eliminated,
                totalVotes = totalVoters,
            }
        end
    end

    -- Shouldn't reach here
    return {
        winner = nil,
        rounds = rounds,
        eliminated = eliminated,
        totalVotes = totalVoters,
    }
end

--- Count first-choice votes for active candidates
-- @param votes table - Working votes array
-- @param activeCandidates table - Set of active candidate names
-- @return table - { [candidate] = count }
function LoothingVotingEngine:CountFirstChoices(votes, activeCandidates)
    local counts = {}

    -- Initialize counts for all active candidates
    for candidate in pairs(activeCandidates) do
        counts[candidate] = 0
    end

    for _, vote in ipairs(votes) do
        -- Find the first choice that's still active
        for _, choice in ipairs(vote.responses) do
            local normalized = LoothingUtils.NormalizeName(tostring(choice))
            if activeCandidates[normalized] then
                counts[normalized] = counts[normalized] + 1
                break
            end
        end
    end

    return counts
end

--- Redistribute votes after elimination
-- @param votes table - Working votes array
-- @param activeCandidates table - Set of remaining active candidates
function LoothingVotingEngine:RedistributeVotes(votes, activeCandidates)
    -- Remove eliminated candidates from vote responses
    for _, vote in ipairs(votes) do
        local newResponses = {}
        for _, choice in ipairs(vote.responses) do
            local normalized = LoothingUtils.NormalizeName(tostring(choice))
            if activeCandidates[normalized] then
                newResponses[#newResponses + 1] = choice
            end
        end
        vote.responses = newResponses
    end
end

--[[--------------------------------------------------------------------
    Utility Functions
----------------------------------------------------------------------]]

--- Count total votes
-- @param votes table - DataProvider or array
-- @return number
function LoothingVotingEngine:CountVotes(votes)
    if votes.GetSize then
        return votes:GetSize()
    end

    local count = 0
    for _ in ipairs(votes) do
        count = count + 1
    end
    return count
end

--- Get voters by their first-choice response
-- @param votes table - DataProvider or array
-- @return table - { [response] = { voter1, voter2, ... } }
function LoothingVotingEngine:GroupVotersByResponse(votes)
    local groups = {}

    for _, response in pairs(LOOTHING_RESPONSE) do
        groups[response] = {}
    end

    local enumerate = votes.Enumerate and function() return votes:Enumerate() end or function() return ipairs(votes) end
    for _, vote in enumerate() do
        local firstChoice = vote.responses and vote.responses[1]
        if firstChoice and groups[firstChoice] then
            groups[firstChoice][#groups[firstChoice] + 1] = vote.voter
        end
    end

    return groups
end

--- Calculate vote percentage for each response
-- @param votes table - DataProvider or array
-- @return table - { [response] = percentage }
function LoothingVotingEngine:GetVotePercentages(votes)
    local result = self:TallySimple(votes)
    local total = result.totalVotes

    local percentages = {}
    for response, data in pairs(result.counts) do
        if total > 0 then
            percentages[response] = (data.count / total) * 100
        else
            percentages[response] = 0
        end
    end

    return percentages
end

--- Determine if there's a clear winner
-- @param votes table - DataProvider or array
-- @param threshold number - Percentage threshold for "clear" winner (default 50)
-- @return boolean, string|nil - hasClearWinner, winningResponse
function LoothingVotingEngine:HasClearWinner(votes, threshold)
    threshold = threshold or 50

    local percentages = self:GetVotePercentages(votes)
    local result = self:TallySimple(votes)

    if result.winningResponse and percentages[result.winningResponse] >= threshold then
        return true, result.winningResponse
    end

    return false, nil
end

--[[--------------------------------------------------------------------
    Response-Based Tallying (for UI display)
----------------------------------------------------------------------]]

--- Get a summary of votes by response type
-- @param votes table - DataProvider or array
-- @return table - Array of { response, responseInfo, count, voters, percentage }
function LoothingVotingEngine:GetResponseSummary(votes)
    local result = self:TallySimple(votes)
    local summary = {}

    for response, data in pairs(result.counts) do
        local responseInfo = LOOTHING_RESPONSE_INFO[response]
        if responseInfo then
            summary[#summary + 1] = {
                response = response,
                responseInfo = responseInfo,
                count = data.count,
                voters = data.voters,
                percentage = result.totalVotes > 0 and (data.count / result.totalVotes * 100) or 0,
            }
        end
    end

    -- Sort by response order (NEED first, PASS last)
    table.sort(summary, function(a, b)
        return a.response < b.response
    end)

    return summary
end

--[[--------------------------------------------------------------------
    Tiebreaker Logic
----------------------------------------------------------------------]]

--- Break a tie using configured rules
-- @param tiedCandidates table - Array of tied candidate names
-- @param votes table - DataProvider or array
-- @param mode string - Tiebreaker mode ("random", "alphabetical", "manual")
-- @return string|nil - Winner, or nil if manual resolution needed
function LoothingVotingEngine:BreakTie(tiedCandidates, votes, mode)
    mode = mode or "manual"

    if #tiedCandidates == 0 then
        return nil
    end

    if #tiedCandidates == 1 then
        return tiedCandidates[1]
    end

    if mode == "random" then
        local index = math.random(1, #tiedCandidates)
        return tiedCandidates[index]
    elseif mode == "alphabetical" then
        table.sort(tiedCandidates)
        return tiedCandidates[1]
    else
        -- Manual - return nil to indicate ML must decide
        return nil
    end
end
