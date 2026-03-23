--[[--------------------------------------------------------------------
    Loothing - Loot Council Addon for WoW 12.0+
    TestMode - Development testing utilities
----------------------------------------------------------------------]]


local _, ns = ...
local Loolib = LibStub("Loolib")
local Loothing = ns.Addon
local Protocol = ns.Protocol
local Utils = ns.Utils
local VotingEngine = ns.VotingEngine

local function GetTestRunner()
    return ns.TestRunner
end

--[[--------------------------------------------------------------------
    Test Mode State
----------------------------------------------------------------------]]

local TestMode = ns.TestMode or {
    enabled = false,
    fakeCouncilMembers = {},
    fakeItems = {},
}
ns.TestMode = TestMode

-- Class data for fake players
local CLASS_DATA = {
    { class = "WARRIOR", color = "C69B6D" },
    { class = "PALADIN", color = "F48CBA" },
    { class = "HUNTER", color = "AAD372" },
    { class = "ROGUE", color = "FFF468" },
    { class = "PRIEST", color = "FFFFFF" },
    { class = "DEATHKNIGHT", color = "C41E3A" },
    { class = "SHAMAN", color = "0070DD" },
    { class = "MAGE", color = "3FC7EB" },
    { class = "WARLOCK", color = "8788EE" },
    { class = "MONK", color = "00FF98" },
    { class = "DRUID", color = "FF7C0A" },
    { class = "DEMONHUNTER", color = "A330C9" },
    { class = "EVOKER", color = "33937F" },
}

-- Fake player name parts
local NAME_PREFIXES = { "Shadow", "Fire", "Ice", "Storm", "Dark", "Light", "Blood", "Soul", "Iron", "Steel", "Thunder", "Frost" }
local NAME_SUFFIXES = { "blade", "strike", "heart", "fang", "claw", "guard", "bane", "fury", "rage", "storm", "walker", "hunter" }

-- Test item IDs (modern WoW 12.0+ items for valid item links)
local TEST_ITEM_IDS = {
    212405, 212450, 212460, 212470, 212480,
    212502, 212504, 212506,
    225622, 225623, 225624, 225625,
}

--[[--------------------------------------------------------------------
    Test Mode Toggle
----------------------------------------------------------------------]]

--- Enable or disable test mode
-- @param enabled boolean
function TestMode:SetEnabled(enabled)
    self.enabled = enabled

    if Loothing and Loothing.TestMode and Loothing.TestMode.OnSimulatorToggled then
        Loothing.TestMode:OnSimulatorToggled(enabled)
    end

    if enabled then
        self:GenerateFakeCouncil()
        self:RegisterEventHandlers()
        local persistenceText = (Loothing and Loothing.TestMode and Loothing.TestMode:IsPersistenceAllowed()) and "persistence ALLOWED" or "persistence BLOCKED"
        print("|cff00ff00[Loothing]|r Test mode |cff00ff00ENABLED|r (" .. persistenceText .. ")")
        print("  - Raid requirements bypassed")
        print("  - Fake council members created: " .. #self.fakeCouncilMembers)
        print("  - Use '/lt test add [count]' to add fake items")
        print("  - Use '/lt test vote' to simulate votes")
        print("  - Use '/lt test session' to start a test session")
        print("  - Use '/lt test full' for complete workflow test")
        print("  - Use '/lt test help' for all commands")
    else
        self:UnregisterEventHandlers()
        self:ClearFakeData()
        print("|cff00ff00[Loothing]|r Test mode |cffff0000DISABLED|r")
    end

    -- Notify UI to update
    if Loothing and Loothing.UI and Loothing.UI.MainFrame then
        -- Call Refresh if it exists, otherwise try RefreshContent
        local mainFrame = Loothing.UI.MainFrame
        if type(mainFrame.Refresh) == "function" then
            mainFrame:Refresh()
        elseif type(mainFrame.RefreshContent) == "function" then
            mainFrame:RefreshContent()
        end
        -- Update test mode indicator
        self:UpdateTestModeIndicator()
    end
end

--- Register event handlers for test mode
function TestMode:RegisterEventHandlers()
    -- Listen for response submissions from RollFrame
    -- Use "TestMode_Events" owner key to avoid overwriting the full-workflow callback
    if Loothing.UI and Loothing.UI.RollFrame and Loothing.UI.RollFrame.RegisterCallback then
        Loothing.UI.RollFrame:RegisterCallback("OnResponseSubmitted", function(_, item, response, _note)
            TestMode:OnResponseSubmitted(item, response)
        end, "TestMode_Events")
    end

    -- Listen for revote clicks
    if Loothing.UI and Loothing.UI.ResultsPanel and Loothing.UI.ResultsPanel.RegisterCallback then
        Loothing.UI.ResultsPanel:RegisterCallback("OnRevoteClicked", function(_, item)
            TestMode:OnRevoteClicked(item)
        end, "TestMode_Events")
    end
end

--- Unregister event handlers
function TestMode:UnregisterEventHandlers()
    if Loothing.UI and Loothing.UI.RollFrame and Loothing.UI.RollFrame.UnregisterCallback then
        Loothing.UI.RollFrame:UnregisterCallback("OnResponseSubmitted", "TestMode_Events")
    end
    if Loothing.UI and Loothing.UI.ResultsPanel and Loothing.UI.ResultsPanel.UnregisterCallback then
        Loothing.UI.ResultsPanel:UnregisterCallback("OnRevoteClicked", "TestMode_Events")
    end
end

--- Handle response submission in test mode (from RollFrame)
function TestMode:OnResponseSubmitted(item, response)
    if not self.enabled or not item then return end

    local responseInfo = Loothing.ResponseInfo and Loothing.ResponseInfo[response]
    local responseName = responseInfo and responseInfo.name or tostring(response)
    print("|cff00ff00[Loothing Test]|r Response submitted: " .. responseName .. " for " .. (item.name or "item"))

    -- Skip auto-tally during full workflow mode - let the full workflow callback handle it
    if self.inFullWorkflowMode then
        return
    end

    -- In test mode (not full workflow), auto-tally and show results after response
    C_Timer.After(0.5, function()
        local results = self:TallyActualVotes(item)
        if results and Loothing.UI and Loothing.UI.ResultsPanel then
            -- Ensure candidateManager is populated from vote data so ResultsPanel can display candidates
            self:PopulateCandidateManagerFromVotes(item)
            Loothing.UI.ResultsPanel:SetItem(item, results)
            Loothing.UI.ResultsPanel:Show()
        end
    end)
end

--- Handle vote submission in test mode (deprecated, use OnResponseSubmitted)
function TestMode:OnVoteSubmitted(item, responses)
    -- Redirect to new handler
    self:OnResponseSubmitted(item, responses and responses[1])
end

--- Handle revote click in test mode
function TestMode:OnRevoteClicked(item)
    if not self.enabled or not item then return end

    print("|cff00ff00[Loothing Test]|r Re-vote requested for " .. (item.name or "item"))

    -- Clear existing votes on the item
    if item.ClearVotes then
        item:ClearVotes()
    elseif item.votes then
        wipe(item.votes)
    end

    -- Reset item state to voting
    if item.SetState then
        item:SetState(Loothing.ItemState.VOTING)
    elseif item.state then
        item.state = Loothing.ItemState.VOTING
    end

    -- Hide results panel and show RollFrame for new response
    if Loothing.UI.ResultsPanel then
        Loothing.UI.ResultsPanel:Hide()
    end

    if Loothing.UI.RollFrame then
        Loothing.UI.RollFrame:AddItem(item)
    end
end

--- Tally actual votes from an item
function TestMode:TallyActualVotes(item)
    local results = {
        counts = {},
        winner = nil,
        winnerResponse = nil,
        totalVotes = 0,
        isTie = false,
    }

    -- Get votes from item
    local votes = item.votes or (item.GetVotes and item:GetVotes()) or {}

    -- Group by response
    for voterName, voteData in pairs(votes) do
        local responses = voteData.responses or voteData
        local firstResponse = responses[1] or responses

        if not results.counts[firstResponse] then
            results.counts[firstResponse] = {
                count = 0,
                voters = {},
                response = firstResponse,
                info = Loothing.ResponseManager and Loothing.ResponseManager:GetResponse(firstResponse) or { name = "Response " .. tostring(firstResponse), color = {0.5, 0.5, 0.5, 1} },
            }
        end

        results.counts[firstResponse].count = results.counts[firstResponse].count + 1
        -- Store voter names as plain strings (GetShortName expects strings)
        table.insert(results.counts[firstResponse].voters, voterName)
        results.totalVotes = results.totalVotes + 1
    end

    -- Find winner
    local maxCount = 0
    local tieCount = 0
    for response, tally in pairs(results.counts) do
        if tally.count > maxCount then
            maxCount = tally.count
            results.winnerResponse = response
            results.winner = tally.voters[1]
            tieCount = 1
        elseif tally.count == maxCount and maxCount > 0 then
            tieCount = tieCount + 1
        end
    end

    results.isTie = tieCount > 1

    return results
end

--- Populate an item's candidateManager from its legacy vote data
-- Used in the quick-test flow so the new candidate-centric ResultsPanel has data to display
function TestMode:PopulateCandidateManagerFromVotes(item)
    if not item then return end

    local cm = item:GetCandidateManager()
    local votes = item.votes or (item.GetVotes and item:GetVotes()) or {}

    for voterName, voteData in pairs(votes) do
        local voterClass = voteData.class or "WARRIOR"
        local candidate = cm:GetOrCreateCandidate(voterName, voterClass)
        local responses = voteData.responses or voteData
        local firstResponse = responses[1] or responses
        candidate:SetResponse(firstResponse, nil)
    end
end

--- Enable test mode
function TestMode:Enable()
    self:SetEnabled(true)
end

--- Disable test mode
function TestMode:Disable()
    self:SetEnabled(false)
end

--- Check if test mode is enabled
-- @return boolean
function TestMode:IsEnabled()
    return self.enabled
end

--- Toggle test mode
function TestMode:Toggle()
    self:SetEnabled(not self.enabled)
end

--[[--------------------------------------------------------------------
    Fake Council Generation
----------------------------------------------------------------------]]

--- Generate fake council members
-- @param count number - Number of members to generate (default 5)
function TestMode:GenerateFakeCouncil(count)
    count = count or 5
    self.fakeCouncilMembers = {}

    local realm = GetNormalizedRealmName()
    local usedNames = {}

    for i = 1, count do
        local name
        repeat
            local prefix = NAME_PREFIXES[math.random(#NAME_PREFIXES)]
            local suffix = NAME_SUFFIXES[math.random(#NAME_SUFFIXES)]
            name = prefix .. suffix
        until not usedNames[name]

        usedNames[name] = true

        local classData = CLASS_DATA[math.random(#CLASS_DATA)]

        self.fakeCouncilMembers[i] = {
            name = name .. "-" .. realm,
            shortName = name,
            class = classData.class,
            classColor = classData.color,
            rank = i == 1 and 2 or 1,  -- First is "leader", rest are "assistants"
            online = true,
        }
    end

    -- Add the real player as first member
    local playerName = Utils.GetPlayerFullName()
    local _, playerClass = Loolib.SecretUtil.SafeUnitClass("player")
    table.insert(self.fakeCouncilMembers, 1, {
        name = playerName,
        shortName = Loolib.SecretUtil.SafeUnitName("player"),
        class = playerClass,
        rank = 2,  -- Player is the leader
        online = true,
    })

    -- Register fake members with the council in-memory only (skip SaveToSettings
    -- so fake names never persist to SavedVariables across sessions/crashes)
    if Loothing and Loothing.Council then
        for _, member in ipairs(self.fakeCouncilMembers) do
            local normalized = Utils.NormalizeName(member.name)
            if normalized and not Loothing.Council.members[normalized] then
                Loothing.Council.members[normalized] = {
                    name = normalized,
                    addedTime = time(),
                    addedBy = "TestMode",
                    isTestMode = true,
                }
            end
        end
        Loothing.Council:TriggerEvent("OnRosterChanged")
    end
end

--- Get fake council members
-- @return table - Array of fake council member data
function TestMode:GetFakeCouncilMembers()
    return self.fakeCouncilMembers
end

--- Get fake raid roster (for testing)
-- @return table - Array formatted like GetRaidRoster()
function TestMode:GetFakeRaidRoster()
    local roster = {}

    for i, member in ipairs(self.fakeCouncilMembers) do
        roster[i] = {
            name = member.name,
            shortName = member.shortName,
            rank = member.rank,
            subgroup = 1,
            level = 80,
            class = member.class:gsub("^%l", string.upper),  -- Capitalize
            classFile = member.class,
            online = true,
            isDead = false,
            role = "DAMAGER",
            isMasterLooter = (i == 1),
        }
    end

    return roster
end

--[[--------------------------------------------------------------------
    Fake Item Generation
----------------------------------------------------------------------]]

--- Generate a fake item link
-- @param itemID number - Optional specific item ID
-- @return string - Item link
function TestMode:GenerateFakeItemLink(itemID)
    itemID = itemID or TEST_ITEM_IDS[math.random(#TEST_ITEM_IDS)]

    -- Create a basic item link format
    -- |cff<color>|Hitem:<itemID>::::::::80:::::|h[<name>]|h|r
    local _, link = C_Item.GetItemInfo(itemID)

    if link then
        return link
    end

    -- Fallback: create a synthetic link (may not work perfectly)
    return string.format("|cffa335ee|Hitem:%d::::::::80:::::|h[Test Item %d]|h|r", itemID, itemID)
end

--- Create a fake item for testing UI components
-- @return ItemMixin - Fake item object
function TestMode:CreateFakeItem()
    if not Loothing or not Loothing.Session then
        print("|cffff0000[Loothing Test]|r Session module not loaded.")
        return nil
    end

    -- Auto-enable test mode if not enabled
    if not self.enabled then
        self:Enable()
    end

    -- Ensure we have council members
    if #self.fakeCouncilMembers < 2 then
        self:GenerateFakeCouncil()
    end

    local itemLink = self:GenerateFakeItemLink()
    local looterName
    if #self.fakeCouncilMembers >= 2 then
        local looter = self.fakeCouncilMembers[math.random(2, #self.fakeCouncilMembers)]
        looterName = looter and looter.name or Utils.GetPlayerFullName()
    else
        looterName = Utils.GetPlayerFullName()
    end

    -- Create item using the ItemMixin
    local item = Loolib.CreateFromMixins(ItemMixin)
    item:Init(itemLink, looterName, 0)

    return item
end

--- Create fake vote results for testing
-- @param item ItemMixin - The item to create results for
-- @return table - Fake results data
function TestMode:CreateFakeResults(_item)
    local results = {
        counts = {},
        winner = nil,
        winnerResponse = nil,
        totalVotes = 0,
    }

    -- Simulate vote tallies
    local allResponses = {
        Loothing.Response.NEED,
        Loothing.Response.GREED,
        Loothing.Response.OFFSPEC,
        Loothing.Response.TRANSMOG,
        Loothing.Response.PASS,
    }

    for _, response in ipairs(allResponses) do
        local voters = {}
        local count = math.random(0, 4) -- 0-4 voters per response

        for _ = 1, count do
            local member = self.fakeCouncilMembers[math.random(2, #self.fakeCouncilMembers)]
            if member then
                -- Store voter names as plain strings (GetShortName expects strings)
                voters[#voters + 1] = member.name
            end
        end

        results.counts[response] = {
            count = #voters,
            voters = voters,
        }
        results.totalVotes = results.totalVotes + #voters
    end

    -- Pick a winner (highest count)
    local maxCount = 0
    local winnerResponse = nil
    for response, tally in pairs(results.counts) do
        if tally.count > maxCount then
            maxCount = tally.count
            winnerResponse = response
        end
    end

    if winnerResponse and results.counts[winnerResponse].voters[1] then
        results.winner = results.counts[winnerResponse].voters[1]
        results.winnerResponse = winnerResponse
    end

    return results
end

--- Add fake items to the current session
-- @param count number - Number of items to add (default 3)
function TestMode:AddFakeItems(count)
    count = count or 3

    if not self.enabled then
        print("|cffff0000[Loothing]|r Test mode is not enabled. Use '/lt test' to enable.")
        return
    end

    if not Loothing or not Loothing.Session then
        print("|cffff0000[Loothing]|r Session module not loaded.")
        return
    end

    -- Start session if not active
    if not Loothing.Session:IsActive() then
        Loothing.Session:StartSession(0, "Test Encounter")
    end

    local addedCount = 0
    local usedIDs = {}

    for _ = 1, count do
        -- Pick a random item ID not already used
        local itemID
        local attempts = 0
        repeat
            itemID = TEST_ITEM_IDS[math.random(#TEST_ITEM_IDS)]
            attempts = attempts + 1
        until not usedIDs[itemID] or attempts > 20

        usedIDs[itemID] = true

        local itemLink = self:GenerateFakeItemLink(itemID)

        -- Pick a random fake council member as looter
        local looter = self.fakeCouncilMembers[math.random(2, #self.fakeCouncilMembers)]
        local looterName = looter and looter.name or Utils.GetPlayerFullName()

        local item = Loothing.Session:AddItem(itemLink, looterName)
        if item then
            addedCount = addedCount + 1
            self.fakeItems[#self.fakeItems + 1] = item
        end
    end

    print(string.format("|cff00ff00[Loothing]|r Added %d test items to session.", addedCount))

    -- Refresh UI
    if Loothing.UI and Loothing.UI.MainFrame then
        local mainFrame = Loothing.UI.MainFrame
        if type(mainFrame.Refresh) == "function" then
            mainFrame:Refresh()
        end
    end
end

--[[--------------------------------------------------------------------
    Vote Simulation
----------------------------------------------------------------------]]

--- Simulate votes on the current voting item
function TestMode:SimulateVotes()
    if not self.enabled then
        print("|cffff0000[Loothing]|r Test mode is not enabled. Use '/lt test' to enable.")
        return
    end

    if not Loothing or not Loothing.Session then
        print("|cffff0000[Loothing]|r Session module not loaded.")
        return
    end

    local currentItem = Loothing.Session:GetCurrentVotingItem()
    if not currentItem then
        print("|cffff0000[Loothing]|r No item is currently being voted on.")
        print("  Start voting on an item first, then run '/lt test vote'")
        return
    end

    local voteCount = 0

    -- Simulate votes from all fake council members (skip player at index 1)
    for i = 2, #self.fakeCouncilMembers do
        local member = self.fakeCouncilMembers[i]

        -- Skip if already voted
        if not currentItem:HasVoted(member.name) then
            -- Generate random responses
            local responses = self:GenerateRandomResponses()

            -- Add the vote directly
            currentItem:AddVote(member.name, member.class, responses)
            voteCount = voteCount + 1
        end
    end

    print(string.format("|cff00ff00[Loothing]|r Simulated %d votes.", voteCount))

    -- Trigger UI update (check if event exists first)
    if Loothing.Session.TriggerEvent and Loothing.Session.Event and Loothing.Session.Event.OnVoteReceived then
        Loothing.Session:TriggerEvent("OnVoteReceived", currentItem)
    end

    -- Refresh UI
    if Loothing.UI and Loothing.UI.MainFrame then
        local mainFrame = Loothing.UI.MainFrame
        if type(mainFrame.Refresh) == "function" then
            mainFrame:Refresh()
        end
    end
end

--- Generate random vote responses
-- @return table - Array of Loothing.Response values
function TestMode:GenerateRandomResponses()
    local responses = {}
    local allResponses = {
        Loothing.Response.NEED,
        Loothing.Response.GREED,
        Loothing.Response.OFFSPEC,
        Loothing.Response.TRANSMOG,
        Loothing.Response.PASS,
    }

    -- Weight towards NEED and GREED for more interesting results
    local weights = { 40, 25, 15, 10, 10 }

    -- Pick first choice with weighting
    local roll = math.random(100)
    local cumulative = 0
    for i, weight in ipairs(weights) do
        cumulative = cumulative + weight
        if roll <= cumulative then
            responses[1] = allResponses[i]
            break
        end
    end

    -- Add 1-2 more choices for ranked voting
    local usedResponses = { [responses[1]] = true }
    for j = 2, math.random(2, 3) do
        local available = {}
        for _, r in ipairs(allResponses) do
            if not usedResponses[r] then
                available[#available + 1] = r
            end
        end
        if #available > 0 then
            local choice = available[math.random(#available)]
            responses[j] = choice
            usedResponses[choice] = true
        end
    end

    return responses
end

--[[--------------------------------------------------------------------
    Test Session Management
----------------------------------------------------------------------]]

--- Start a test session
function TestMode:StartTestSession()
    if not self.enabled then
        print("|cffff0000[Loothing]|r Test mode is not enabled. Use '/lt test' to enable.")
        return
    end

    if not Loothing or not Loothing.Session then
        print("|cffff0000[Loothing]|r Session module not loaded.")
        return
    end

    if Loothing.Session:IsActive() then
        print("|cffff0000[Loothing]|r A session is already active. End it first.")
        return
    end

    Loothing.Session:StartSession(0, "Test Encounter")
    print("|cff00ff00[Loothing]|r Test session started.")

    -- Refresh UI
    if Loothing.UI and Loothing.UI.MainFrame then
        local mainFrame = Loothing.UI.MainFrame
        if type(mainFrame.Refresh) == "function" then
            mainFrame:Refresh()
        end
    end
end

--- End the current test session
function TestMode:EndTestSession()
    if not Loothing or not Loothing.Session then
        return
    end

    if Loothing.Session:IsActive() then
        Loothing.Session:EndSession()
        self.fakeItems = {}
        self.inFullWorkflowMode = false
        self.fullWorkflowCallbackRegistered = false
        print("|cff00ff00[Loothing]|r Test session ended.")
    end
end

--[[--------------------------------------------------------------------
    UI Component Testing
----------------------------------------------------------------------]]

--- Show VotePanel with a fake item for testing
function TestMode:ShowVotePanel()
    if not Loothing.VotePanel then
        print("|cffff9900[Loothing Test]|r VotePanel not initialized, using RollFrame instead")
        self:ShowRollFrame()
        return
    end

    -- Create a fake item with candidates for VotePanel
    local fakeItem = self:CreateFakeItem()
    if not fakeItem then return end

    local votingMode = Loothing.Settings and Loothing.Settings:GetVotingMode()
        or Loothing.VotingMode.RANKED_CHOICE
    Loothing.VotePanel:SetVotingMode(votingMode)
    Loothing.VotePanel:SetItem(fakeItem)
    Loothing.VotePanel:Show()
end

--- Show RollFrame (what raid members see to respond to loot)
function TestMode:ShowRollFrame()
    if not Loothing.UI or not Loothing.UI.RollFrame then
        print("|cffff0000[Loothing Test]|r RollFrame not initialized")
        return
    end

    -- Create a fake item for testing
    local fakeItem = self:CreateFakeItem()
    if not fakeItem then
        return
    end

    fakeItem:SetState(Loothing.ItemState.VOTING)
    fakeItem.voteStartTime = GetTime()
    local timeout = Loothing.Settings and Loothing.Settings:GetVotingTimeout()
                    or Loothing.Timing.DEFAULT_VOTE_TIMEOUT
    fakeItem.voteTimeout = timeout
    fakeItem.voteEndTime = GetTime() + timeout

    Loothing.UI.RollFrame:SetItem(fakeItem)
    Loothing.UI.RollFrame:Show()
    print("|cff00ff00[Loothing Test]|r RollFrame opened with fake item (raid member view)")
end

--- Show ResultsPanel with fake results for testing
function TestMode:ShowResultsPanel()
    if not Loothing.UI or not Loothing.UI.ResultsPanel then
        print("|cffff0000[Loothing Test]|r ResultsPanel not initialized")
        return
    end

    -- Create fake item and populate candidateManager
    local fakeItem = self:CreateFakeItem()
    if not fakeItem then
        return
    end

    fakeItem:SetState(Loothing.ItemState.TALLIED)

    -- Populate candidateManager with fake candidates and council votes
    self:AddFakeCandidatesToItem(fakeItem)
    local cm = fakeItem:GetCandidateManager()
    for _, c in ipairs(cm:GetAllCandidates()) do
        for _ = 1, math.random(0, 5) do
            c:AddCouncilVote()
        end
    end

    -- Also create legacy results for backward compat
    local fakeResults = self:CreateFakeResults(fakeItem)

    Loothing.UI.ResultsPanel:SetItem(fakeItem, fakeResults)
    Loothing.UI.ResultsPanel:Show()
    print("|cff00ff00[Loothing Test]|r ResultsPanel opened with fake results")
end

--- Show CouncilTable (where council sees all candidates and awards items)
function TestMode:ShowCouncilTable()
    if not Loothing.UI or not Loothing.UI.CouncilTable then
        print("|cffff0000[Loothing Test]|r CouncilTable not initialized")
        return
    end

    -- Make sure test mode is enabled
    if not self.enabled then
        self:Enable()
    end

    -- Start a test session if needed
    if not Loothing.Session or not Loothing.Session:IsActive() then
        self:StartTestSession()
    end

    -- Add some fake items and candidates
    if Loothing.Session then
        local session = Loothing.Session
        local items = session:GetItems()
        if not items or #items == 0 then
            self:AddFakeItems(3)
        end

        -- Add fake candidates to items
        for _, item in ipairs(session:GetItems() or {}) do
            local manager = item.GetCandidateManager and item:GetCandidateManager()
            if manager and manager:GetCandidateCount() == 0 then
                self:AddFakeCandidatesToItem(item)
            end
        end

        -- Set session on council table
        Loothing.UI.CouncilTable:SetSession(session)
    end

    Loothing.UI.CouncilTable:Show()
    print("|cff00ff00[Loothing Test]|r CouncilTable opened (ML/council voting view)")
end

--- Add fake candidates to an item for testing
function TestMode:AddFakeCandidatesToItem(item)
    if not item or not item.GetCandidateManager then return end

    local candidateManager = item:GetCandidateManager()
    if not candidateManager then return end

    local fakeNames = {"Faketank", "Fakehealer", "Fakedps1", "Fakedps2", "Fakedps3"}
    local classes = {"WARRIOR", "PRIEST", "MAGE", "ROGUE", "HUNTER"}
    local roles = {"TANK", "HEALER", "DAMAGER", "DAMAGER", "DAMAGER"}
    local ranks = {"Officer", "Officer", "Member", "Member", "Member"}

    -- Use actual Loothing.Response enum values
    local responseTypes = {
        Loothing.Response.NEED,
        Loothing.Response.GREED,
        Loothing.Response.OFFSPEC,
        Loothing.Response.TRANSMOG,
        Loothing.Response.PASS,
    }

    for i, name in ipairs(fakeNames) do
        local candidate = candidateManager:GetOrCreateCandidate(name, classes[i] or "WARRIOR")
        if candidate then
            -- Set response as enum value (renderer will look up Loothing.ResponseInfo)
            candidate.response = responseTypes[math.random(#responseTypes)]

            -- Roll
            candidate.roll = math.random(1, 100)

            -- Note (first candidate gets a note)
            candidate.note = (i == 1) and "This is a test note" or nil

            -- Gear data - renderer looks for gear1ilvl, gear2ilvl, ilvlDiff
            local playerIlvl = math.random(580, 620)
            local itemIlvl = item.itemLevel or math.random(600, 640)
            candidate.gear1ilvl = playerIlvl
            candidate.gear2ilvl = playerIlvl - math.random(0, 15)
            candidate.ilvlDiff = itemIlvl - playerIlvl

            -- Fake gear links (using test item IDs for visual)
            local fakeGearIDs = {19019, 17182, 22691, 32837, 34334, 16922, 16925, 19375}
            local gearID1 = fakeGearIDs[math.random(#fakeGearIDs)]
            local gearID2 = fakeGearIDs[math.random(#fakeGearIDs)]
            candidate.gear1Link = select(2, C_Item.GetItemInfo(gearID1))
            candidate.gear2Link = select(2, C_Item.GetItemInfo(gearID2))

            -- Response time
            candidate.responseTime = GetTime() - math.random(5, 30)

            -- Items won counters (renderer looks for these)
            candidate.itemsWonThisSession = math.random(0, 2)
            candidate.itemsWonInstance = math.random(0, 5)
            candidate.itemsWonWeekly = math.random(0, 8)

            -- Enrichment fields expected by CouncilTable renderer
            candidate.role = roles[i]
            candidate.rank = ranks[i]
            candidate.ilvl = candidate.gear1ilvl
        end
    end
end

--- Start voting on the first pending item
function TestMode:StartVoteOnPending()
    if not self.enabled then
        print("|cffff0000[Loothing Test]|r Test mode is not enabled. Use '/lt test' to enable.")
        return
    end

    if not Loothing or not Loothing.Session then
        print("|cffff0000[Loothing]|r Session module not loaded.")
        return
    end

    if not Loothing.Session:IsActive() then
        print("|cffff0000[Loothing Test]|r No active session. Starting one...")
        self:StartTestSession()
        self:AddFakeItems(3)
    end

    -- Find first pending item by enumerating the DataProvider
    local items = Loothing.Session:GetItems()
    local pendingItem = nil

    if items and items.Enumerate then
        for _, item in items:Enumerate() do
            if item:IsPending() then
                pendingItem = item
                break
            end
        end
    end

    if not pendingItem then
        print("|cffff0000[Loothing Test]|r No pending items. Adding some...")
        self:AddFakeItems(3)

        items = Loothing.Session:GetItems()
        if items and items.Enumerate then
            for _, item in items:Enumerate() do
                if item:IsPending() then
                    pendingItem = item
                    break
                end
            end
        end
    end

    if pendingItem then
        -- Use the correct API: StartVoting takes a guid, not an item object
        Loothing.Session:StartVoting(pendingItem.guid)
        print("|cff00ff00[Loothing Test]|r Started voting on: " .. (pendingItem.name or "Unknown Item"))

        -- RollFrame auto-shows via OnVotingStarted event
        -- Manual show not needed since StartVoting triggers the event
    else
        print("|cffff0000[Loothing Test]|r Failed to find pending item")
    end
end

--- Run full workflow test
function TestMode:RunFullWorkflow()
    print("|cff00ff00[Loothing Test]|r Starting full workflow test...")

    -- Step 1: Enable test mode if not already enabled
    if not self.enabled then
        self:SetEnabled(true)
    end

    -- Step 2: Start session if not active
    if not Loothing.Session or not Loothing.Session:IsActive() then
        self:StartTestSession()
    end

    -- Step 3: Add 3 fake items
    self:AddFakeItems(3)

    -- Step 4: Start voting on ALL items at once (multi-item flow)
    local votingCount = Loothing.Session:StartVotingOnAllItems()
    print(string.format("|cff00ff00[Loothing Test]|r Started voting on %d items", votingCount))

    -- Add fake candidates to all items
    if self.fakeItems then
        for _, item in ipairs(self.fakeItems) do
            self:AddFakeCandidatesToItem(item)
        end
    end

    -- The RollFrame should auto-show via OnVotingStarted event
    -- which will display all voting items at once
    if votingCount > 0 then
        print("|cff00ff00[Loothing Test]|r RollFrame should display - submit responses for each item")

        -- Register callback to show CouncilTable after response
        self:RegisterFullWorkflowCallbacks()
    else
        print("|cffff0000[Loothing Test]|r No items started voting")
    end

    -- Show MainFrame on session tab
    if Loothing.UI and Loothing.UI.MainFrame then
        Loothing.UI.MainFrame:Show()
        Loothing.UI.MainFrame:SelectTab("session")
    end

    print("|cff00ff00[Loothing Test]|r Full workflow active:")
    print("  1. RollFrame shown with " .. votingCount .. " items - respond to EACH item")
    print("  2. Use session buttons (left side) or submit to auto-advance")
    print("  3. After ALL items responded, CouncilTable opens for council voting")
    print("  4. In CouncilTable, use tabs to switch items and award each one")
    print("  Use '/lt test counciltable' to view CouncilTable directly")
end

--- Register callbacks for full workflow test
function TestMode:RegisterFullWorkflowCallbacks()
    -- Unregister previous callbacks if any
    if self.fullWorkflowCallbackRegistered then
        return
    end

    local rollFrame = Loothing.UI and Loothing.UI.RollFrame
    if not rollFrame or not rollFrame.RegisterCallback then
        return
    end

    -- Track that we're in full workflow mode (prevents ResultsPanel from showing)
    self.inFullWorkflowMode = true

    -- When RollFrame response is submitted, add candidate and check if all items done
    -- Use "TestMode_Workflow" owner key to avoid overwriting the event handler callback
    -- RollFrame fires: TriggerEvent("OnResponseSubmitted", self.item, response, note, roll)
    rollFrame:RegisterCallback("OnResponseSubmitted", function(_, item, response, note, roll)
        -- Add player as a candidate with their response
        if item and item.GetCandidateManager then
            local playerName = Loolib.SecretUtil.SafeUnitName("player")
            local _, playerClass = Loolib.SecretUtil.SafeUnitClass("player")
            local manager = item:GetCandidateManager()
            if manager then
                local candidate = manager:GetOrCreateCandidate(playerName, playerClass)
                if candidate then
                    -- Store the response enum value (not the info table)
                    candidate.response = response
                    candidate.note = note
                    candidate.roll = roll or math.random(1, 100)
                    candidate.responseTime = GetTime()
                end
            end
        end

        -- Check if ALL items have been responded to
        local unrespondedCount = rollFrame:GetUnrespondedCount()
        if unrespondedCount == 0 then
            -- All items responded - now show CouncilTable
            print("|cff00ff00[Loothing Test]|r All items responded! Opening CouncilTable...")
            C_Timer.After(0.3, function()
                TestMode.inFullWorkflowMode = false  -- Exit full workflow mode
                TestMode:ShowCouncilTableForSession()
            end)
        else
            -- Still have items to respond to - RollFrame handles switching automatically
            print(string.format("|cff00ff00[Loothing Test]|r Response submitted. %d item(s) remaining.", unrespondedCount))
        end
    end, "TestMode_Workflow")

    self.fullWorkflowCallbackRegistered = true
end

--- Run auto-award scenario (stub)
function TestMode:RunAutoAwardScenario()
    print("|cffff9900[Loothing Test]|r RunAutoAwardScenario not yet implemented")
end

--- Show CouncilTable with current session
function TestMode:ShowCouncilTableForSession()
    if not Loothing.UI or not Loothing.UI.CouncilTable then
        print("|cffff0000[Loothing Test]|r CouncilTable not initialized")
        return
    end

    -- Set session on CouncilTable
    if Loothing.Session then
        Loothing.UI.CouncilTable:SetSession(Loothing.Session)
    end

    Loothing.UI.CouncilTable:Show()
    print("|cff00ff00[Loothing Test]|r CouncilTable opened - select a candidate to award")
end

--[[--------------------------------------------------------------------
    Test Mode Indicator
----------------------------------------------------------------------]]

--- Update test mode indicator on MainFrame
function TestMode:UpdateTestModeIndicator()
    if not Loothing or not Loothing.UI or not Loothing.UI.MainFrame then
        return
    end

    local mainFrame = Loothing.UI.MainFrame.frame
    if not mainFrame then
        return
    end

    -- Remove existing indicator if present
    if self.testModeIndicator then
        self.testModeIndicator:Hide()
        self.testModeIndicator = nil
    end

    if self.enabled then
        -- Create test mode indicator
        local indicator = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        indicator:SetPoint("TOP", mainFrame, "TOP", 0, -8)
        indicator:SetText("|cffff0000TEST MODE|r")
        indicator:SetTextColor(1, 0, 0)
        indicator:SetShadowColor(0, 0, 0, 1)
        indicator:SetShadowOffset(1, -1)
        indicator:Show()

        self.testModeIndicator = indicator

        -- Pulse animation (optional)
        local ag = indicator:CreateAnimationGroup()
        local fadeOut = ag:CreateAnimation("Alpha")
        fadeOut:SetFromAlpha(1)
        fadeOut:SetToAlpha(0.3)
        fadeOut:SetDuration(0.8)
        fadeOut:SetSmoothing("IN_OUT")

        local fadeIn = ag:CreateAnimation("Alpha")
        fadeIn:SetFromAlpha(0.3)
        fadeIn:SetToAlpha(1)
        fadeIn:SetDuration(0.8)
        fadeIn:SetSmoothing("IN_OUT")
        fadeIn:SetStartDelay(0.8)

        ag:SetLooping("REPEAT")
        ag:Play()
    end
end

--[[--------------------------------------------------------------------
    Cleanup
----------------------------------------------------------------------]]

--- Clear all fake data
function TestMode:ClearFakeData()
    -- Remove fake council members from in-memory council (no SaveToSettings)
    if Loothing and Loothing.Council then
        for _, member in ipairs(self.fakeCouncilMembers) do
            local normalized = Utils.NormalizeName(member.name)
            if normalized then
                Loothing.Council.members[normalized] = nil
            end
        end
        Loothing.Council:TriggerEvent("OnRosterChanged")
    end

    self.fakeCouncilMembers = {}
    self.fakeItems = {}
    self.inFullWorkflowMode = false
    self.fullWorkflowCallbackRegistered = false

    -- End any active test session
    if Loothing and Loothing.Session and Loothing.Session:IsActive() then
        Loothing.Session:EndSession()
    end
end

--[[--------------------------------------------------------------------
    Slash Command Handler
----------------------------------------------------------------------]]

--- Handle test mode slash commands
-- @param args string - Command arguments
function TestMode:HandleCommand(args)
    local state = ns.TestModeState
    local cmd, param = args:match("^(%S*)%s*(.*)$")
    cmd = cmd and cmd:lower() or ""
    param = param or ""
    local force = param:lower() == "force"

    if cmd == "" or cmd == "toggle" then
        if not self.enabled and state and not state:CheckPrerequisites({ force = force }) then
            return
        end
        self:Toggle()
        return
    elseif cmd == "on" or cmd == "enable" then
        if state and not state:CheckPrerequisites({ force = force }) then
            return
        end
        self:Enable()
        return
    elseif cmd == "off" or cmd == "disable" then
        self:Disable()
        return
    elseif cmd == "status" then
        if state and state.Status then
            state:Status()
        else
            print("|cff00ff00[Loothing Test]|r Enabled:", self.enabled and "ON" or "OFF")
        end
        return
    elseif cmd == "persist" or cmd == "allowsave" then
        if state and state.SetPersistenceAllowed then
            local toggle = param:lower()
            local allow = toggle == "on" or toggle == "true" or toggle == "yes"
            state:SetPersistenceAllowed(allow)
        end
        return
    elseif cmd == "votepanel" then
        self:ShowVotePanel()
    elseif cmd == "rollframe" then
        self:ShowRollFrame()
    elseif cmd == "counciltable" or cmd == "council-table" or cmd == "ct" then
        self:ShowCouncilTable()
    elseif cmd == "results" then
        self:ShowResultsPanel()
    elseif cmd == "startvote" then
        self:StartVoteOnPending()
    elseif cmd == "full" then
        self:RunFullWorkflow()
    elseif cmd == "council" then
        local n = tonumber(param) or 5
        self:GenerateFakeCouncil(n)
        print(string.format("|cff00ff00[Loothing Test]|r Created %d fake council members", n))
    elseif cmd == "add" or cmd == "item" or cmd == "items" then
        local count = tonumber(param) or 3
        self:AddFakeItems(count)
    elseif cmd == "vote" or cmd == "votes" then
        self:SimulateVotes()
    elseif cmd == "session" or cmd == "start" then
        self:StartTestSession()
    elseif cmd == "end" or cmd == "stop" then
        self:EndTestSession()
    -- Test Suite Commands (requires test infrastructure from Dev TOC)
    elseif cmd == "run" or cmd == "suite" or cmd == "runall"
        or cmd == "unit" or cmd == "integration" or cmd == "stress"
        or cmd == "list" or cmd == "scenario" or cmd == "scenarios"
        or cmd == "report" or cmd == "benchmark" then
        if not GetTestRunner() then
            print("|cffff6600[Loothing Test]|r Test suite commands require the Dev build. These commands are not available in release.")
            return
        end
        if cmd == "run" or cmd == "suite" then
            self:RunTestSuite(param)
        elseif cmd == "runall" then
            self:RunAllTests()
        elseif cmd == "unit" then
            self:RunTestCategory("unit")
        elseif cmd == "integration" then
            self:RunTestCategory("integration")
        elseif cmd == "stress" then
            self:RunTestCategory("stress")
        elseif cmd == "list" then
            self:ListTestSuites()
        elseif cmd == "scenario" then
            self:RunScenario(param)
        elseif cmd == "scenarios" then
            self:ListScenarios()
        elseif cmd == "report" then
            self:ShowLastReport()
        elseif cmd == "benchmark" then
            self:RunBenchmarks()
        end
    elseif cmd == "help" then
        self:PrintHelp()
    else
        print("|cffff0000[Loothing Test]|r Unknown command: " .. cmd)
        print("  Use |cffffffff/lt test help|r for available commands.")
    end
end

--[[--------------------------------------------------------------------
    Test Suite Integration
----------------------------------------------------------------------]]

--- Run a specific test suite (Describe/It or standalone)
-- @param suiteName string - Name of the suite to run
function TestMode:RunTestSuite(suiteName)
    local TestRunner = GetTestRunner()
    if not suiteName or suiteName == "" then
        print("|cffff0000[Loothing Test]|r Please specify a suite name.")
        print("  Use |cffffffff/lt test list|r to see available suites.")
        return
    end

    if not TestRunner then
        print("|cffff0000[Loothing Test]|r TestRunner not loaded.")
        return
    end

    -- Check Describe/It suites first
    local suites = TestRunner:GetSuites()
    for _, suite in ipairs(suites) do
        if suite.name == suiteName then
            print("|cff00ccff[Loothing Test]|r Running suite: " .. suiteName)
            TestRunner:RunSuite(suiteName)
            return
        end
    end

    -- Fall back to standalone registered tests
    TestRunner:RunRegisteredTest(suiteName)
end

--- Run all registered test suites (Describe/It + standalone)
function TestMode:RunAllTests()
    local TestRunner = GetTestRunner()
    if not TestRunner then
        print("|cffff0000[Loothing Test]|r TestRunner not loaded.")
        return
    end

    print("|cff00ccff[Loothing Test]|r Running all test suites...")
    local startTime = debugprofilestop()

    -- Run Describe/It suites
    local results = TestRunner:RunAll()
    self:DisplayTestResults(results)

    -- Run standalone registered tests
    TestRunner:RunAllRegistered()

    local elapsed = debugprofilestop() - startTime
    print(string.format("|cff888888Total time: %.2f ms|r", elapsed))
end

--- Run tests in a specific category
-- @param category string - "unit", "integration", or "stress"
function TestMode:RunTestCategory(category)
    local TestRunner = GetTestRunner()
    if not TestRunner then
        print("|cffff0000[Loothing Test]|r TestRunner not loaded.")
        return
    end

    print("|cff00ccff[Loothing Test]|r Running " .. category .. " tests...")
    local results = TestRunner:RunCategory(category)
    self:DisplayTestResults(results)
end

--- List all available test suites (Describe/It + standalone)
function TestMode:ListTestSuites()
    local TestRunner = GetTestRunner()
    if not TestRunner then
        print("|cffff0000[Loothing Test]|r TestRunner not loaded.")
        return
    end

    local suites = TestRunner:GetSuites()
    print("|cff00ccff[Loothing Test]|r Available test suites:")

    if #suites > 0 then
        print("  |cffFFFF00Describe/It Suites:|r")
        for _, suite in ipairs(suites) do
            local testCount = #suite.tests or 0
            print(string.format("    |cffffffff%s|r (%d tests)", suite.name, testCount))
        end
    end

    -- Also list standalone registered tests
    TestRunner:ListRegisteredTests()
end

--- Display test results
-- @param results table - Test results from TestRunner
function TestMode:DisplayTestResults(results)
    if not results then
        print("|cffff0000[Loothing Test]|r No results to display.")
        return
    end

    -- Store for later viewing
    self.lastTestResults = results

    local passed = results.passed or 0
    local failed = results.failed or 0
    local skipped = results.skipped or 0
    -- Summary line
    local passColor = passed > 0 and "00ff00" or "888888"
    local failColor = failed > 0 and "ff0000" or "888888"
    local skipColor = skipped > 0 and "ffff00" or "888888"

    print(" ")
    print("|cff00ccff========== TEST RESULTS ==========|r")
    print(string.format("  |cff%s✓ Passed: %d|r  |cff%s✗ Failed: %d|r  |cff%s○ Skipped: %d|r",
        passColor, passed, failColor, failed, skipColor, skipped))

    -- Show failed test details
    if results.failures and #results.failures > 0 then
        print(" ")
        print("|cffff0000Failed Tests:|r")
        for i, failure in ipairs(results.failures) do
            if i <= 10 then -- Limit to 10 failures shown
                print(string.format("  |cffff6666%s|r", failure.name or "Unknown"))
                if failure.message then
                    print(string.format("    |cff888888%s|r", failure.message:sub(1, 100)))
                end
            end
        end
        if #results.failures > 10 then
            print(string.format("  |cff888888...and %d more failures|r", #results.failures - 10))
        end
    end

    -- Show slow tests
    if results.slowTests and #results.slowTests > 0 then
        print(" ")
        print("|cffffcc00Slow Tests (>100ms):|r")
        for i, slow in ipairs(results.slowTests) do
            if i <= 5 then
                print(string.format("  |cffffcc00%s|r: %.2fms", slow.name, slow.time))
            end
        end
    end

    print("|cff00ccff==================================|r")
    print(" ")

    -- Final verdict
    if failed == 0 then
        print("|cff00ff00✓ All tests passed!|r")
    else
        print(string.format("|cffff0000✗ %d test(s) failed.|r", failed))
    end
end

--- Show the last test report
function TestMode:ShowLastReport()
    if not self.lastTestResults then
        print("|cff888888[Loothing Test]|r No test results available. Run tests first.")
        return
    end

    self:DisplayTestResults(self.lastTestResults)
end

--[[--------------------------------------------------------------------
    Pre-Built Test Scenarios
----------------------------------------------------------------------]]

-- Scenario definitions
local TEST_SCENARIOS = {
    simple_vote = {
        name = "Simple Vote Workflow",
        description = "Basic voting with 5 council members, 3 items",
        func = "RunSimpleVoteScenario",
    },
    ranked_choice = {
        name = "Ranked Choice Voting",
        description = "Test ranked choice elimination and redistribution",
        func = "RunRankedChoiceScenario",
    },
    tie_breaker = {
        name = "Tie Breaker",
        description = "Test tie detection and resolution",
        func = "RunTieBreakerScenario",
    },
    auto_pass = {
        name = "Auto-Pass Rules",
        description = "Test armor/trinket/token auto-pass logic",
        func = "RunAutoPassScenario",
    },
    auto_award = {
        name = "Auto-Award",
        description = "Test automatic item awarding",
        func = "RunAutoAwardScenario",
    },
    large_raid = {
        name = "Large Raid (40 players)",
        description = "Stress test with 40-player raid simulation",
        func = "RunLargeRaidScenario",
    },
    many_items = {
        name = "Many Items (25 items)",
        description = "Session with 25 items to process",
        func = "RunManyItemsScenario",
    },
    timeout = {
        name = "Vote Timeout",
        description = "Test vote timeout handling",
        func = "RunTimeoutScenario",
    },
    sync = {
        name = "Settings Sync",
        description = "Test MLDB broadcast and apply",
        func = "RunSyncScenario",
    },
    history = {
        name = "History Recording",
        description = "Test history creation and export",
        func = "RunHistoryScenario",
    },
}

--- List available test scenarios
function TestMode:ListScenarios()
    print("|cff00ccff[Loothing Test]|r Available scenarios:")
    print(" ")
    for id, scenario in pairs(TEST_SCENARIOS) do
        print(string.format("  |cffffffff%s|r - %s", id, scenario.name))
        print(string.format("    |cff888888%s|r", scenario.description))
    end
    print(" ")
    print("  Use |cffffffff/lt test scenario <name>|r to run a scenario")
end

--- Run a specific scenario
-- @param scenarioName string - Scenario ID
function TestMode:RunScenario(scenarioName)
    if not scenarioName or scenarioName == "" then
        self:ListScenarios()
        return
    end

    local scenario = TEST_SCENARIOS[scenarioName:lower()]
    if not scenario then
        print("|cffff0000[Loothing Test]|r Unknown scenario: " .. scenarioName)
        self:ListScenarios()
        return
    end

    print("|cff00ccff[Loothing Test]|r Running scenario: " .. scenario.name)
    print("|cff888888" .. scenario.description .. "|r")
    print(" ")

    -- Enable test mode if not already
    if not self.enabled then
        self:SetEnabled(true)
    end

    -- Call the scenario function
    local func = self[scenario.func]
    if func then
        func(self)
    else
        print("|cffff0000[Loothing Test]|r Scenario function not implemented: " .. scenario.func)
    end
end

--- Simple vote workflow scenario
function TestMode:RunSimpleVoteScenario()
    print("|cff00ccff[Step 1]|r Creating 5 council members...")
    self:GenerateFakeCouncil(5)

    print("|cff00ccff[Step 2]|r Starting test session...")
    self:StartTestSession()

    print("|cff00ccff[Step 3]|r Adding 3 test items...")
    self:AddFakeItems(3)

    print("|cff00ccff[Step 4]|r Starting vote on first item...")
    self:StartVoteOnPending()

    print(" ")
    print("|cff00ff00Scenario ready!|r")
    print("  Use |cffffffff/lt test vote|r to simulate council votes")
    print("  The Loot Response frame should now be visible")
end

--- Ranked choice voting scenario
function TestMode:RunRankedChoiceScenario()
    -- Set voting mode to ranked choice
    if Loothing.Settings then
        Loothing.Settings:SetVotingMode(Loothing.VotingMode.RANKED_CHOICE)
    end

    print("|cff00ccff[Step 1]|r Set voting mode to RANKED_CHOICE")

    self:GenerateFakeCouncil(7)
    print("|cff00ccff[Step 2]|r Created 7 council members")

    self:StartTestSession()
    self:AddFakeItems(1)
    print("|cff00ccff[Step 3]|r Session started with 1 item")

    self:StartVoteOnPending()
    print("|cff00ccff[Step 4]|r Voting started")

    print(" ")
    print("|cff00ff00Ranked Choice scenario ready!|r")
    print("  Use |cffffffff/lt test vote|r to simulate ranked votes")
end

--- Tie breaker scenario
function TestMode:RunTieBreakerScenario()
    self:GenerateFakeCouncil(4)
    self:StartTestSession()
    self:AddFakeItems(1)
    self:StartVoteOnPending()

    -- Add exactly tied votes
    local item = Loothing.Session:GetCurrentVotingItem()
    if item then
        local members = self.fakeCouncilMembers
        -- 2 votes for NEED, 2 for GREED = tie
        if members[2] then
            item:AddVote(members[2].name, members[2].class, { Loothing.Response.NEED })
        end
        if members[3] then
            item:AddVote(members[3].name, members[3].class, { Loothing.Response.NEED })
        end
        if members[4] then
            item:AddVote(members[4].name, members[4].class, { Loothing.Response.GREED })
        end
        if members[5] then
            item:AddVote(members[5].name, members[5].class, { Loothing.Response.GREED })
        end

        print("|cff00ff00Tie created!|r NEED: 2, GREED: 2")
        print("  Check how the system handles the tie")
    end
end

--- Auto-pass scenario
function TestMode:RunAutoPassScenario()
    print("|cff00ccff[Auto-Pass Test]|r")
    print(" ")

    -- Test various auto-pass scenarios
    local scenarios = {
        { desc = "Plate on Mage", classID = 8, itemType = "Plate", shouldPass = true },
        { desc = "Cloth on Mage", classID = 8, itemType = "Cloth", shouldPass = false },
        { desc = "Strength Trinket on Mage", classID = 8, itemType = "StrTrinket", shouldPass = true },
    }

    for _, scenario in ipairs(scenarios) do
        local passText = scenario.shouldPass and "|cff00ff00SHOULD AUTO-PASS|r" or "|cffff0000SHOULD NOT PASS|r"
        print(string.format("  %s: %s", scenario.desc, passText))
    end

    print(" ")
    print("|cff888888Note: Full auto-pass testing requires actual item data|r")
end

--- Large raid scenario
function TestMode:RunLargeRaidScenario()
    print("|cff00ccff[Large Raid Stress Test]|r")
    print(" ")

    local startTime = debugprofilestop()

    self:GenerateFakeCouncil(40)
    print(string.format("  Created 40 raid members in %.2fms", debugprofilestop() - startTime))

    startTime = debugprofilestop()
    self:StartTestSession()
    self:AddFakeItems(10)
    print(string.format("  Added 10 items in %.2fms", debugprofilestop() - startTime))

    startTime = debugprofilestop()
    self:StartVoteOnPending()
    self:SimulateVotes()
    print(string.format("  Simulated 39 votes in %.2fms", debugprofilestop() - startTime))

    print(" ")
    print("|cff00ff00Large raid scenario complete!|r")
end

--- Many items scenario
function TestMode:RunManyItemsScenario()
    print("|cff00ccff[Many Items Stress Test]|r")
    print(" ")

    local startTime = debugprofilestop()

    self:GenerateFakeCouncil(10)
    self:StartTestSession()

    -- Add 25 items
    for i = 1, 25 do
        local itemID = TEST_ITEM_IDS[(i % #TEST_ITEM_IDS) + 1]
        local itemLink = self:GenerateFakeItemLink(itemID)
        local looter = self.fakeCouncilMembers[math.random(2, #self.fakeCouncilMembers)]
        Loothing.Session:AddItem(itemLink, looter.name)
    end

    local elapsed = debugprofilestop() - startTime
    print(string.format("  Added 25 items in %.2fms", elapsed))

    if Loothing.UI and Loothing.UI.MainFrame then
        Loothing.UI.MainFrame:Show()
        Loothing.UI.MainFrame:SelectTab("session")
    end

    print("|cff00ff00Many items scenario ready!|r")
end

--- Timeout scenario
function TestMode:RunTimeoutScenario()
    self:GenerateFakeCouncil(5)
    self:StartTestSession()
    self:AddFakeItems(1)

    -- Start voting with very short timeout
    local item = nil
    local items = Loothing.Session:GetItems()
    if items then
        for _, i in items:Enumerate() do
            if i:IsPending() then
                item = i
                break
            end
        end
    end

    if item then
        item.voteTimeout = 5 -- 5 second timeout
        Loothing.Session:StartVoting(item.guid)

        print("|cff00ccff[Timeout Test]|r Vote started with 5 second timeout")
        print("  Watch for timeout handling...")
    end
end

--- Sync scenario
function TestMode:RunSyncScenario()
    print("|cff00ccff[Sync Test]|r Testing MLDB broadcast...")

    if Loothing.MLDB then
        local settings = Loothing.MLDB:GatherSettings()
        print("  Gathered settings:")
        print(string.format("    selfVote: %s", tostring(settings.selfVote)))
        print(string.format("    multiVote: %s", tostring(settings.multiVote)))
        print(string.format("    votingTimeout: %d", settings.votingTimeout or 0))

        local compressed = Loothing.MLDB:CompressForTransmit(settings)
        print(string.format("  Compressed size: %d bytes", #compressed))

        local decompressed = Loothing.MLDB:DecompressFromTransmit(compressed)
        print(string.format("  Decompressed successfully: %s", decompressed and "yes" or "no"))
    else
        print("|cffff0000MLDB module not loaded|r")
    end
end

--- History scenario
function TestMode:RunHistoryScenario()
    print("|cff00ccff[History Test]|r")

    -- Create a quick session and award
    self:GenerateFakeCouncil(5)
    self:StartTestSession()
    self:AddFakeItems(1)

    local items = Loothing.Session:GetItems()
    if items then
        for _, item in items:Enumerate() do
            -- Simulate awarding
            if Loothing.History then
                local winner = self.fakeCouncilMembers[2]
                Loothing.History:AddEntry({
                    timestamp = time(),
                    winner = winner.name,
                    itemName = item.name or "Test Item",
                    itemID = item.itemID or 0,
                    itemLink = item.link,
                    winnerResponse = Loothing.Response.NEED,
                    votes = 5,
                    winnerClass = winner.class,
                    encounterID = 0,
                    encounterName = "Test Encounter",
                    instance = "Test Instance",
                    difficultyID = 16,
                    difficultyName = "Mythic",
                    groupSize = 20,
                    owner = winner.name,
                    equipSlot = "INVTYPE_CHEST",
                    typeCode = "default",
                    subType = "Plate",
                    candidates = {
                        { playerName = winner.name, playerClass = winner.class, response = Loothing.Response.NEED, note = "", roll = 0, gear1Link = nil, gear2Link = nil, gear1ilvl = 0, gear2ilvl = 0, ilvlDiff = 0, councilVotes = 3 },
                    },
                    councilVotes = {
                        { voter = "Council1-Realm", voterClass = "PALADIN", responses = { Loothing.Response.NEED }, note = "" },
                    },
                })
                print("  Added history entry for: " .. (item.name or "Unknown"))
            end
            break
        end
    end

    -- Test export
    if Loothing.History then
        local csv = Loothing.History:ExportCSV()
        print(string.format("  CSV export length: %d chars", #(csv or "")))
    end

    print("|cff00ff00History scenario complete!|r")
end

--[[--------------------------------------------------------------------
    Benchmarks
----------------------------------------------------------------------]]

--- Run performance benchmarks
function TestMode:RunBenchmarks()
    print("|cff00ccff[Loothing Test]|r Running benchmarks...")
    print(" ")

    local results = {}

    -- Benchmark: Item creation
    local startTime = debugprofilestop()
    for _ = 1, 100 do
        self:CreateFakeItem()
    end
    results.itemCreation = (debugprofilestop() - startTime) / 100
    print(string.format("  Item creation: %.3fms avg", results.itemCreation))

    -- Benchmark: Vote tallying
    if VotingEngine then
        local fakeVotes = {}
        for i = 1, 40 do
            fakeVotes[i] = {
                voter = "Player" .. i,
                responses = { math.random(1, 5) },
            }
        end

        startTime = debugprofilestop()
        for _ = 1, 100 do
            VotingEngine:TallySimple(fakeVotes)
        end
        results.voteTally = (debugprofilestop() - startTime) / 100
        print(string.format("  Vote tallying (40 votes): %.3fms avg", results.voteTally))
    end

    -- Benchmark: Protocol encoding (Serialize → Compress → EncodeForAddonChannel)
    if Protocol then
        startTime = debugprofilestop()
        for _ = 1, 100 do
            Protocol:Encode(Loothing.MsgType.VOTE_COMMIT, { itemGUID = "guid123", responses = { 1, 2, 3 } })
        end
        results.protocolEncode = (debugprofilestop() - startTime) / 100
        print(string.format("  Protocol encoding: %.3fms avg", results.protocolEncode))
    end

    -- Benchmark: Council lookup
    self:GenerateFakeCouncil(40)
    startTime = debugprofilestop()
    for _ = 1, 1000 do
        local _ = self.fakeCouncilMembers[math.random(1, 40)]
    end
    results.councilLookup = (debugprofilestop() - startTime) / 1000
    print(string.format("  Council lookup: %.4fms avg", results.councilLookup))

    print(" ")
    print("|cff00ff00Benchmarks complete!|r")

    self.lastBenchmarks = results
end

--[[--------------------------------------------------------------------
    Enhanced Help
----------------------------------------------------------------------]]

--- Print comprehensive help
function TestMode:PrintHelp()
    print("|cffff9900========== LOOTHING TEST MODE ==========|r")
    print(" ")
    print("|cff00ccffBasic Commands:|r")
    print("  |cffffffff/lt test|r - Toggle test mode on/off")
    print("  |cffffffff/lt test on|r / |cffffffff/lt test off|r - Enable/disable explicitly")
    print(" ")
    print("|cff00ccffUI Component Tests:|r")
    print("  |cffffffff/lt test rollframe|r - Loot Response frame (Need/Greed/Pass)")
    print("  |cffffffff/lt test votepanel|r - (deprecated, redirects to rollframe)")
    print("  |cffffffff/lt test counciltable|r - CouncilTable: where ML/council sees all candidates and awards")
    print("  |cffffffff/lt test results|r - ResultsPanel: view vote tallies after voting ends")
    print(" ")
    print("|cff00ccffWorkflow Tests:|r")
    print("  |cffffffff/lt test full|r - Complete workflow (session→items→vote)")
    print("  |cffffffff/lt test startvote|r - Start voting on first pending item")
    print("  |cffffffff/lt test vote|r - Simulate council votes")
    print(" ")
    print("|cff00ccffData Generation:|r")
    print("  |cffffffff/lt test council [N]|r - Create N fake council members")
    print("  |cffffffff/lt test items [N]|r - Add N fake items to session")
    print("  |cffffffff/lt test session|r - Start a test session")
    print("  |cffffffff/lt test end|r - End current test session")
    print(" ")
    print("|cff00ccffTest Suites:|r")
    print("  |cffffffff/lt test runall|r - Run all test suites")
    print("  |cffffffff/lt test run <suite>|r - Run specific test suite")
    print("  |cffffffff/lt test unit|r - Run unit tests only")
    print("  |cffffffff/lt test integration|r - Run integration tests only")
    print("  |cffffffff/lt test stress|r - Run stress tests only")
    print("  |cffffffff/lt test list|r - List available test suites")
    print("  |cffffffff/lt test report|r - Show last test report")
    print(" ")
    print("|cff00ccffScenarios:|r")
    print("  |cffffffff/lt test scenarios|r - List available scenarios")
    print("  |cffffffff/lt test scenario <name>|r - Run a specific scenario")
    print(" ")
    print("|cff00ccffPerformance:|r")
    print("  |cffffffff/lt test benchmark|r - Run performance benchmarks")
    print("|cffff9900==========================================|r")
end
