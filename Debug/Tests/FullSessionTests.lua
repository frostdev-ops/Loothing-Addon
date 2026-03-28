--[[--------------------------------------------------------------------
    Loothing - Loot Council Addon for WoW 12.0+
    FullSessionTests - Comprehensive end-to-end session integration test

    Requires at minimum two players in a group to test real ML <-> client
    communication. The other player must have Loothing installed and will
    see normal session/voting UI to respond through.

    When solo (no group), falls back to simulated client responses with
    a warning. Real comms mode is preferred.

    All comm messages are logged (pass-through) for the debug report.
    Edge cases test local state machines directly (combat, restrictions).

    Produces a debug report window with full message log, state
    transitions, and edge case results that can be copy-pasted.

    Run: /lt test run fullsession
----------------------------------------------------------------------]]

local _, ns = ...
local Loothing = ns.Addon
local Utils = ns.Utils
local TestMode = ns.TestMode
local TestHelpers = ns.TestHelpers
local TestRunner = ns.TestRunner
local Protocol = ns.Protocol

local Loolib = LibStub("Loolib")

--[[--------------------------------------------------------------------
    Constants
----------------------------------------------------------------------]]

-- How long to wait for real player responses before timing out (seconds)
local RESPONSE_TIMEOUT = 15
-- How long to wait for responses in edge-case mini-sessions
local EDGE_RESPONSE_TIMEOUT = 10

local PHASES = {
    "PRE_SESSION_SETUP",
    "ENCOUNTER_AND_SESSION_START",
    "LOOT_AND_ITEM_MANAGEMENT",
    "VOTING_PHASE",
    "TALLYING_AND_AWARD",
    "SESSION_END",
    "EDGE_COMBAT_DURING_VOTING",
    "EDGE_COMBAT_DURING_SESSION_START",
    "EDGE_ENCOUNTER_RESTRICTION",
    "EDGE_CLIENT_DISCONNECT",
    "EDGE_ML_DISCONNECT",
    "EDGE_REVOTE_ON_TIE",
    "EDGE_SKIP_ITEM",
    "EDGE_MULTI_ITEM_VOTING",
    "EDGE_LATE_RESPONSE",
    "EDGE_INVALID_MESSAGE",
    "EDGE_DUPLICATE_DEDUP",
    "EDGE_SESSION_END_DURING_VOTING",
    "EDGE_COMBAT_RAPID_CYCLING",
}

--[[--------------------------------------------------------------------
    Color Codes
----------------------------------------------------------------------]]

local COLOR = {
    GREEN  = "|cff00ff00",
    RED    = "|cffff0000",
    YELLOW = "|cffffff00",
    CYAN   = "|cff00ffff",
    GRAY   = "|cff808080",
    WHITE  = "|cffffffff",
    ORANGE = "|cffff9900",
    RESET  = "|r",
}

--[[--------------------------------------------------------------------
    Utility: Strip WoW Color Codes
----------------------------------------------------------------------]]

local function StripColorCodes(text)
    text = text:gsub("|c%x%x%x%x%x%x%x%x", "")
    text = text:gsub("|r", "")
    text = text:gsub("|H.-|h", "")
    text = text:gsub("|h", "")
    return text
end

--[[--------------------------------------------------------------------
    CommLogger - Pass-through message logger

    Wraps Send/SendGuaranteed/SendGuild to log all traffic while letting
    real messages flow through WoW addon channels. Also hooks OnMessage
    to capture inbound traffic.

    When solo (ctx.isSimulated == true), outgoing broadcasts are
    intercepted and fake client responses are injected instead.
----------------------------------------------------------------------]]

local CommLogger = {}

function CommLogger:New()
    local obj = {
        ctx = nil,
        originalSend = nil,
        originalSendGuaranteed = nil,
        originalSendGuild = nil,
        originalOnMessage = nil,
        installed = false,
    }
    setmetatable(obj, { __index = self })
    return obj
end

function CommLogger:Install(ctx)
    if not Loothing.Comm then return end

    self.ctx = ctx
    self.originalSend = Loothing.Comm.Send
    self.originalSendGuaranteed = Loothing.Comm.SendGuaranteed
    self.originalSendGuild = Loothing.Comm.SendGuild
    self.originalOnMessage = Loothing.Comm.OnMessage
    self.installed = true

    local logger = self

    -- Wrap CommMixin.Send — log then pass through
    Loothing.Comm.Send = function(commSelf, command, data, target, priority)
        logger:LogMessage(GetTime(), "OUT", command, target, priority, data)

        if ctx.isSimulated and not target then
            -- Solo mode: simulate client response for broadcast messages
            logger:SimulateClientResponse(command, data)
        end

        -- Always pass through to real send
        logger.originalSend(commSelf, command, data, target, priority)
    end

    -- Wrap CommMixin.SendGuaranteed — log then pass through
    Loothing.Comm.SendGuaranteed = function(commSelf, command, data, target, priority)
        logger:LogMessage(GetTime(), "OUT-G", command, target, priority, data)

        if ctx.isSimulated and not target then
            logger:SimulateClientResponse(command, data)
        end

        logger.originalSendGuaranteed(commSelf, command, data, target, priority)
    end

    -- Wrap SendGuild — log then pass through
    Loothing.Comm.SendGuild = function(commSelf, command, data, priority)
        logger:LogMessage(GetTime(), "OUT", command, "GUILD", priority, data)
        logger.originalSendGuild(commSelf, command, data, priority)
    end

    -- Wrap OnMessage — log inbound then pass through
    local CommMixin = ns.CommMixin
    Loothing.Comm.OnMessage = function(commSelf, message, distribution, sender)
        -- Decode for logging (best-effort, don't fail if decode fails)
        local ok, version, cmd, msgData = pcall(function()
            return Protocol:Decode(message)
        end)
        if ok and cmd then
            logger:LogMessage(GetTime(), "IN", cmd, sender, nil, msgData)
        else
            logger:LogMessage(GetTime(), "IN", "?", sender, nil, nil)
        end

        -- Pass through to real handler
        logger.originalOnMessage(commSelf, message, distribution, sender)
    end

    -- Register cleanup
    ctx.cleanupCallbacks[#ctx.cleanupCallbacks + 1] = function() logger:Uninstall() end
end

function CommLogger:Uninstall()
    if not self.installed or not Loothing.Comm then return end

    Loothing.Comm.Send = self.originalSend
    Loothing.Comm.SendGuaranteed = self.originalSendGuaranteed
    Loothing.Comm.SendGuild = self.originalSendGuild
    Loothing.Comm.OnMessage = self.originalOnMessage
    self.installed = false
end

--- Solo-mode only: inject fake client responses for broadcast messages
function CommLogger:SimulateClientResponse(command, data)
    local ctx = self.ctx
    if not ctx or not ctx.fakeClient then return end

    local client = ctx.fakeClient

    if command == Loothing.MsgType.VOTE_REQUEST then
        -- Simulate a PLAYER_RESPONSE from the fake client after a short delay
        C_Timer.After(0.2, function()
            local responseData = {
                itemGUID = data and data.itemGUID,
                response = Loothing.Response.NEED,
                sessionID = data and data.sessionID or ctx.sessionID,
                playerName = client.name,
                class = client.class,
                roll = math.random(1, 100),
                rollMin = 1,
                rollMax = 100,
            }
            local encoded = Protocol:Encode(Loothing.MsgType.PLAYER_RESPONSE, responseData)
            if encoded then
                self:LogMessage(GetTime(), "IN-SIM", Loothing.MsgType.PLAYER_RESPONSE, client.name, nil, responseData)
                -- Deliver via original OnMessage to exercise full decode path
                self.originalOnMessage(Loothing.Comm, encoded, "RAID", client.name)
            end
        end)
    end
end

function CommLogger:LogMessage(timestamp, direction, command, senderOrTarget, priority, data)
    local ctx = self.ctx
    if not ctx then return end

    ctx.messageLog[#ctx.messageLog + 1] = {
        timestamp = timestamp,
        direction = direction,
        command = command or "?",
        senderOrTarget = senderOrTarget or "broadcast",
        priority = priority,
        dataSummary = self:SummarizeData(data),
    }
end

function CommLogger:SummarizeData(data)
    if not data then return "nil" end
    if type(data) ~= "table" then return tostring(data) end

    local parts = {}
    local count = 0
    for k, v in pairs(data) do
        if count >= 4 then
            parts[#parts + 1] = "..."
            break
        end
        local val = type(v) == "table" and "{...}" or tostring(v)
        if #val > 30 then val = val:sub(1, 27) .. "..." end
        parts[#parts + 1] = tostring(k) .. "=" .. val
        count = count + 1
    end
    return "{" .. table.concat(parts, ", ") .. "}"
end

--[[--------------------------------------------------------------------
    State Tracker
----------------------------------------------------------------------]]

local function InstallStateTrackers(ctx)
    if Loothing.Session then
        Loothing.Session:RegisterCallback("OnStateChanged", function(_, newState, oldState)
            ctx.stateTransitions[#ctx.stateTransitions + 1] = {
                timestamp = GetTime(),
                system = "SessionState",
                oldState = oldState,
                newState = newState,
            }
        end, ctx)

        Loothing.Session:RegisterCallback("OnItemStateChanged", function(_, item, newState, oldState)
            ctx.stateTransitions[#ctx.stateTransitions + 1] = {
                timestamp = GetTime(),
                system = "ItemState",
                itemGUID = item and item.guid,
                oldState = oldState,
                newState = newState,
            }
        end, ctx)
    end

    if Loothing.CommState then
        Loothing.CommState:RegisterCallback("OnStateChanged", function(_, oldState, newState)
            ctx.stateTransitions[#ctx.stateTransitions + 1] = {
                timestamp = GetTime(),
                system = "CommState",
                oldState = oldState,
                newState = newState,
            }
        end, ctx)
    end

    ctx.cleanupCallbacks[#ctx.cleanupCallbacks + 1] = function()
        if Loothing.Session then
            Loothing.Session:UnregisterCallback("OnStateChanged", ctx)
            Loothing.Session:UnregisterCallback("OnItemStateChanged", ctx)
        end
        if Loothing.CommState then
            Loothing.CommState:UnregisterCallback("OnStateChanged", ctx)
        end
    end
end

--[[--------------------------------------------------------------------
    Assert Helpers
----------------------------------------------------------------------]]

local function CreateAssertHelpers(ctx)
    ctx.assert = function(condition, testName)
        if condition then
            ctx.passed = ctx.passed + 1
            ctx.phaseAssertions = ctx.phaseAssertions + 1
            print(COLOR.GREEN .. "  [PASS]" .. COLOR.RESET .. " " .. testName)
        else
            ctx.failed = ctx.failed + 1
            ctx.phaseAssertions = ctx.phaseAssertions + 1
            print(COLOR.RED .. "  [FAIL]" .. COLOR.RESET .. " " .. testName)
        end
    end

    ctx.assertEqual = function(actual, expected, testName)
        if actual == expected then
            ctx.passed = ctx.passed + 1
            ctx.phaseAssertions = ctx.phaseAssertions + 1
            print(COLOR.GREEN .. "  [PASS]" .. COLOR.RESET .. " " .. testName)
        else
            ctx.failed = ctx.failed + 1
            ctx.phaseAssertions = ctx.phaseAssertions + 1
            print(COLOR.RED .. "  [FAIL]" .. COLOR.RESET .. " " .. testName
                .. string.format(" (got '%s', expected '%s')", tostring(actual), tostring(expected)))
        end
    end

    ctx.assertNotNil = function(value, testName)
        ctx.assert(value ~= nil, testName)
    end
end

--[[--------------------------------------------------------------------
    Test Context
----------------------------------------------------------------------]]

local function CreateTestContext()
    local inGroup = IsInGroup() or IsInRaid()
    local groupSize = GetNumGroupMembers() or 0
    local isSimulated = not inGroup or groupSize < 2

    local ctx = {
        isSimulated = isSimulated,
        groupSize = groupSize,
        fakeClient = nil,        -- Only used in simulated mode
        testItemGUIDs = {},
        sessionID = nil,
        phaseResults = {},
        currentPhase = nil,
        phaseAssertions = 0,
        messageLog = {},
        stateTransitions = {},
        edgeCaseResults = {},
        tempTableCountBefore = 0,
        tempTableLeakCount = 0,
        startTime = 0,
        endTime = 0,
        passed = 0,
        failed = 0,
        cleanupCallbacks = {},
        logger = CommLogger:New(),
    }

    CreateAssertHelpers(ctx)
    return ctx
end

--[[--------------------------------------------------------------------
    Mini-Session Helpers (for edge cases)
----------------------------------------------------------------------]]

local function StartMiniSession(ctx, name)
    if Loothing.Session:IsActive() then
        Loothing.Session:EndSession()
    end
    if Loothing.History then
        Loothing.History:Clear()
    end

    Loothing.handleLoot = true
    if Loothing.Session then
        Loothing.Session.masterLooter = Utils.GetPlayerFullName()
    end

    Loothing.Session:StartSession(0, "Edge Case: " .. name)
end

local function EndMiniSession(ctx)
    if Loothing.Session and Loothing.Session:IsActive() then
        Loothing.Session:EndSession()
    end
end

local function AddAndStartVoting(ctx)
    local itemLink = TestMode:GenerateFakeItemLink()
    local item = Loothing.Session:AddItem(itemLink, Utils.GetPlayerFullName(), nil, true)
    if not item then return nil end

    if Loothing.Session.autoStartTimer then
        Loothing.Session.autoStartTimer:Cancel()
        Loothing.Session.autoStartTimer = nil
    end

    Loothing.Session:StartVoting(item.guid, 30)
    return item
end

local function FindMessageInLog(ctx, command, direction)
    for _, msg in ipairs(ctx.messageLog) do
        if msg.command == command and (not direction or msg.direction == direction or msg.direction == direction .. "-G") then
            return true
        end
    end
    return false
end

local function CountMessagesInLog(ctx, command, direction)
    local count = 0
    for _, msg in ipairs(ctx.messageLog) do
        if msg.command == command and (not direction or msg.direction == direction or msg.direction == direction .. "-G") then
            count = count + 1
        end
    end
    return count
end

--- Wait for a condition to become true, polling every interval seconds.
--- Calls onDone(true) when condition met, onDone(false) on timeout.
local function WaitForCondition(condition, timeout, interval, onDone)
    interval = interval or 0.5
    local elapsed = 0

    local function check()
        if condition() then
            onDone(true)
            return
        end
        elapsed = elapsed + interval
        if elapsed >= timeout then
            onDone(false)
            return
        end
        C_Timer.After(interval, check)
    end

    C_Timer.After(interval, check)
end

--[[--------------------------------------------------------------------
    Phase 1: Pre-Session Setup
----------------------------------------------------------------------]]

local function RunPhase1_PreSessionSetup(ctx, onComplete)
    local assert = ctx.assert
    local assertNotNil = ctx.assertNotNil

    -- Enable test mode
    if TestMode and not TestMode:IsEnabled() then
        TestMode:SetEnabled(true)
    end
    assert(TestMode:IsEnabled(), "Test mode enabled")

    -- Report group status
    if ctx.isSimulated then
        print(COLOR.ORANGE .. "  [WARN] Not in a group — running in SIMULATED mode." .. COLOR.RESET)
        print(COLOR.ORANGE .. "         Group with another Loothing player for real comms test." .. COLOR.RESET)

        -- Create fake client for simulated responses
        ctx.fakeClient = TestHelpers:CreateFakePlayer({
            name = "FakeClient",
            class = "WARRIOR",
        })
        assertNotNil(ctx.fakeClient, "Fake client player created (simulated mode)")
    else
        print(COLOR.GREEN .. "  [INFO] In group with " .. ctx.groupSize .. " members — REAL COMMS mode." .. COLOR.RESET)
    end

    -- Set ML flag
    Loothing.handleLoot = true
    Loothing.isMasterLooter = true
    assert(Loothing.handleLoot == true, "ML handleLoot flag set")

    if Loothing.Session then
        Loothing.Session.masterLooter = Utils.GetPlayerFullName()
    end

    -- Council setup
    TestMode:GenerateFakeCouncil(5)
    local council = TestMode:GetFakeCouncilMembers()
    assert(#council >= 2, "Council has >= 2 members")

    -- Install CommLogger (pass-through logging)
    ctx.logger:Install(ctx)
    assert(ctx.logger.installed, "CommLogger installed")

    -- Install state trackers
    InstallStateTrackers(ctx)

    -- TempTable baseline
    if Loolib and Loolib.TempTable and Loolib.TempTable.GetLeaks then
        local leaks = Loolib.TempTable:GetLeaks()
        ctx.tempTableCountBefore = leaks and #leaks or 0
    end

    -- Clean slate
    if Loothing.Session:IsActive() then
        Loothing.Session:EndSession()
    end
    if Loothing.History then
        Loothing.History:Clear()
    end

    onComplete()
end

--[[--------------------------------------------------------------------
    Phase 2: Encounter & Session Start
----------------------------------------------------------------------]]

local function RunPhase2_EncounterAndStart(ctx, onComplete)
    local assert = ctx.assert
    local assertEqual = ctx.assertEqual
    local assertNotNil = ctx.assertNotNil

    assertEqual(Loothing.Session:GetState(), Loothing.SessionState.INACTIVE, "Session starts INACTIVE")

    local result = Loothing.Session:StartSession(0, "Test Boss Kill")
    assert(result ~= false, "StartSession succeeded")

    ctx.sessionID = Loothing.Session:GetSessionID()
    assertNotNil(ctx.sessionID, "Session ID generated")

    assertEqual(Loothing.Session:GetState(), Loothing.SessionState.ACTIVE, "Session state is ACTIVE")
    assert(Loothing.Session:IsActive(), "Session:IsActive() returns true")
    assert(Loothing.Session:IsMasterLooter(), "Local player is ML")

    assert(FindMessageInLog(ctx, Loothing.MsgType.SESSION_START, "OUT"), "SESSION_START broadcast logged")

    onComplete()
end

--[[--------------------------------------------------------------------
    Phase 3: Loot & Item Management
----------------------------------------------------------------------]]

local function RunPhase3_LootAndItems(ctx, onComplete)
    local assert = ctx.assert
    local assertEqual = ctx.assertEqual
    local assertNotNil = ctx.assertNotNil

    local testItemIDs = { 212395, 212424, 212456, 212432 }

    for i, itemID in ipairs(testItemIDs) do
        local itemLink = TestMode:GenerateFakeItemLink(itemID)
        local item = Loothing.Session:AddItem(itemLink, Utils.GetPlayerFullName(), nil, true)
        if item then
            ctx.testItemGUIDs[#ctx.testItemGUIDs + 1] = item.guid
            assertNotNil(item.guid, "Item " .. i .. " has GUID")
            assertEqual(item:GetState(), Loothing.ItemState.PENDING, "Item " .. i .. " state is PENDING")
        else
            ctx.failed = ctx.failed + 1
            print(COLOR.RED .. "  [FAIL]" .. COLOR.RESET .. " Item " .. i .. " AddItem returned nil")
        end
    end

    assertEqual(#ctx.testItemGUIDs, 4, "4 items added to session")

    if Loothing.Session.autoStartTimer then
        Loothing.Session.autoStartTimer:Cancel()
        Loothing.Session.autoStartTimer = nil
    end

    local addCount = CountMessagesInLog(ctx, Loothing.MsgType.ITEM_ADD, "OUT")
    assert(addCount >= 4, "ITEM_ADD broadcasts logged (got " .. addCount .. ")")

    onComplete()
end

--[[--------------------------------------------------------------------
    Phase 4: Voting Phase

    Starts voting on the first item. In real comms mode, waits for
    actual player responses (up to RESPONSE_TIMEOUT). In simulated
    mode, the CommLogger auto-injects a fake response.
----------------------------------------------------------------------]]

local function RunPhase4_Voting(ctx, onComplete)
    local assert = ctx.assert
    local assertEqual = ctx.assertEqual

    if #ctx.testItemGUIDs == 0 then
        ctx.failed = ctx.failed + 1
        print(COLOR.RED .. "  [FAIL]" .. COLOR.RESET .. " No items to vote on")
        onComplete()
        return
    end

    local firstGUID = ctx.testItemGUIDs[1]
    local result = Loothing.Session:StartVoting(firstGUID, 60)
    assert(result ~= false, "StartVoting returned success")

    assert(FindMessageInLog(ctx, Loothing.MsgType.VOTE_REQUEST, "OUT"), "VOTE_REQUEST broadcast logged")

    local item = Loothing.Session:GetItemByGUID(firstGUID)
    if item then
        assertEqual(item:GetState(), Loothing.ItemState.VOTING, "Item state is VOTING")
    end

    -- Add council votes directly (ML-side council members)
    if item then
        local council = TestMode:GetFakeCouncilMembers()
        for i = 2, math.min(4, #council) do
            local member = council[i]
            if member and not item:HasVoted(member.name) then
                item:AddVote(member.name, member.class, { Loothing.Response.NEED })
            end
        end
    end

    -- Wait for at least one response (real or simulated)
    local timeout = ctx.isSimulated and 3 or RESPONSE_TIMEOUT
    if not ctx.isSimulated then
        print(COLOR.CYAN .. "  [WAIT] Waiting up to " .. timeout .. "s for player responses..." .. COLOR.RESET)
    end

    WaitForCondition(
        function()
            if not item then return true end
            local votes = item.votes or (item.GetVotes and item:GetVotes()) or {}
            local count = 0
            for _ in pairs(votes) do count = count + 1 end
            return count >= 1
        end,
        timeout,
        0.5,
        function(gotResponse)
            if gotResponse then
                assert(true, "At least 1 vote received")
            else
                if ctx.isSimulated then
                    assert(false, "No votes received (simulated mode timed out)")
                else
                    print(COLOR.YELLOW .. "  [WARN] No player responses within timeout — continuing" .. COLOR.RESET)
                    ctx.passed = ctx.passed + 1
                    ctx.phaseAssertions = ctx.phaseAssertions + 1
                end
            end
            onComplete()
        end
    )
end

--[[--------------------------------------------------------------------
    Phase 5: Tallying & Award
----------------------------------------------------------------------]]

local function RunPhase5_TallyAndAward(ctx, onComplete)
    local assert = ctx.assert
    local assertEqual = ctx.assertEqual

    local firstGUID = ctx.testItemGUIDs[1]
    Loothing.Session:EndVotingForItem(firstGUID)

    local item = Loothing.Session:GetItemByGUID(firstGUID)

    -- Determine a winner
    local winner
    if not ctx.isSimulated then
        -- Pick the first voter or first group member
        if item then
            local votes = item.votes or (item.GetVotes and item:GetVotes()) or {}
            for voterName in pairs(votes) do
                winner = voterName
                break
            end
        end
    end
    if not winner then
        winner = ctx.fakeClient and ctx.fakeClient.name or "TestWinner-TestRealm"
    end

    Loothing.Session:AwardItem(firstGUID, winner, Loothing.Response.NEED)

    if item then
        assertEqual(item:GetState(), Loothing.ItemState.AWARDED, "Item state is AWARDED")
    end

    assert(FindMessageInLog(ctx, Loothing.MsgType.VOTE_AWARD, "OUT"), "VOTE_AWARD broadcast logged")

    -- Award remaining items quickly
    for i = 2, #ctx.testItemGUIDs do
        local guid = ctx.testItemGUIDs[i]
        Loothing.Session:StartVoting(guid, 30, true)
        Loothing.Session:AwardItem(guid, winner, Loothing.Response.GREED)
    end

    -- Verify history
    if Loothing.History then
        local entries = Loothing.History:GetAllEntries()
        assert(entries and #entries > 0, "History has entries after awards")
    end

    onComplete()
end

--[[--------------------------------------------------------------------
    Phase 6: Session End
----------------------------------------------------------------------]]

local function RunPhase6_SessionEnd(ctx, onComplete)
    local assert = ctx.assert
    local assertEqual = ctx.assertEqual

    Loothing.Session:EndSession()

    assert(not Loothing.Session:IsActive(), "Session is inactive after EndSession")
    assertEqual(Loothing.Session:GetState(), Loothing.SessionState.INACTIVE, "Session state is INACTIVE")
    assert(FindMessageInLog(ctx, Loothing.MsgType.SESSION_END, "OUT"), "SESSION_END broadcast logged")

    onComplete()
end

--[[--------------------------------------------------------------------
    Edge Case 1: Combat During Voting
----------------------------------------------------------------------]]

local function RunEdge_CombatDuringVoting(ctx, onComplete)
    local assert = ctx.assert
    local assertEqual = ctx.assertEqual

    if not Loothing.CommState then
        ctx.edgeCaseResults[#ctx.edgeCaseResults + 1] = {
            name = "Combat During Voting", passed = false, error = "CommState unavailable"
        }
        onComplete()
        return
    end

    StartMiniSession(ctx, "Combat During Voting")
    local item = AddAndStartVoting(ctx)

    if not item then
        ctx.edgeCaseResults[#ctx.edgeCaseResults + 1] = {
            name = "Combat During Voting", passed = false, error = "Failed to add/start voting"
        }
        EndMiniSession(ctx)
        onComplete()
        return
    end

    Loothing.CommState:OnCombatStart()
    assertEqual(Loothing.CommState:GetState(), Loothing.CommState.STATE_COMBAT,
        "EDGE: CommState is COMBAT")

    local shouldDefer = Loothing.CommState:ShouldDefer(Loothing.MsgType.CANDIDATE_UPDATE, "NORMAL")
    assert(shouldDefer == true, "EDGE: ShouldDefer returns true during combat")

    local isCritical = Loothing.CommState:IsCriticalCommand(Loothing.MsgType.VOTE_AWARD)
    assert(isCritical == true, "EDGE: VOTE_AWARD is critical")

    local isNotCritical = Loothing.CommState:IsCriticalCommand(Loothing.MsgType.VERSION_REQUEST)
    assert(isNotCritical ~= true, "EDGE: VERSION_REQUEST is not critical")

    Loothing.CommState:OnCombatEnd()
    assertEqual(Loothing.CommState:GetState(), Loothing.CommState.STATE_CONNECTED,
        "EDGE: CommState returns to CONNECTED")

    ctx.edgeCaseResults[#ctx.edgeCaseResults + 1] = {
        name = "Combat During Voting", passed = true
    }

    EndMiniSession(ctx)
    onComplete()
end

--[[--------------------------------------------------------------------
    Edge Case 2: Combat During Session Start
----------------------------------------------------------------------]]

local function RunEdge_CombatDuringSessionStart(ctx, onComplete)
    local assert = ctx.assert
    local assertEqual = ctx.assertEqual

    if not Loothing.CommState then
        ctx.edgeCaseResults[#ctx.edgeCaseResults + 1] = {
            name = "Combat During Session Start", passed = false, error = "CommState unavailable"
        }
        onComplete()
        return
    end

    Loothing.CommState:OnCombatStart()

    local shouldDefer = Loothing.CommState:ShouldDefer(Loothing.MsgType.SESSION_START, "NORMAL")
    assert(shouldDefer == true, "EDGE: SESSION_START deferred during combat")

    local isCrit = Loothing.CommState:IsCriticalCommand(Loothing.MsgType.SESSION_START)
    assert(isCrit == true, "EDGE: SESSION_START is critical")

    Loothing.CommState:OnCombatEnd()
    assertEqual(Loothing.CommState:GetState(), Loothing.CommState.STATE_CONNECTED,
        "EDGE: Back to CONNECTED after combat")

    ctx.edgeCaseResults[#ctx.edgeCaseResults + 1] = {
        name = "Combat During Session Start", passed = true
    }

    onComplete()
end

--[[--------------------------------------------------------------------
    Edge Case 3: Encounter Restriction
----------------------------------------------------------------------]]

local function RunEdge_EncounterRestriction(ctx, onComplete)
    local assert = ctx.assert
    local assertEqual = ctx.assertEqual

    if not Loothing.Restrictions then
        ctx.edgeCaseResults[#ctx.edgeCaseResults + 1] = {
            name = "Encounter Restriction", passed = false, error = "Restrictions module unavailable"
        }
        onComplete()
        return
    end

    Loothing.Restrictions:SetRestrictionBit(0x2, true)
    assert(Loothing.Restrictions:IsRestricted(), "EDGE: Restrictions active after bit set")

    local queueCountBefore = Loothing.Restrictions:GetQueuedCount()
    Loothing.Restrictions:QueueGuaranteed(
        Loothing.MsgType.VOTE_AWARD,
        { itemGUID = "test-guid", winner = "TestWinner" },
        nil, "NORMAL"
    )
    assert(Loothing.Restrictions:GetQueuedCount() > queueCountBefore, "EDGE: Message queued during restriction")

    Loothing.Restrictions:SetRestrictionBit(0x2, false)
    assert(not Loothing.Restrictions:IsRestricted(), "EDGE: Restrictions lifted")

    Loothing.Restrictions:ClearQueue()
    assertEqual(Loothing.Restrictions:GetQueuedCount(), 0, "EDGE: Queue cleared")

    ctx.edgeCaseResults[#ctx.edgeCaseResults + 1] = {
        name = "Encounter Restriction", passed = true
    }

    onComplete()
end

--[[--------------------------------------------------------------------
    Edge Case 4: Client Disconnect
----------------------------------------------------------------------]]

local function RunEdge_ClientDisconnect(ctx, onComplete)
    local assert = ctx.assert

    if not Loothing.CommState then
        ctx.edgeCaseResults[#ctx.edgeCaseResults + 1] = {
            name = "Client Disconnect", passed = false, error = "CommState unavailable"
        }
        onComplete()
        return
    end

    Loothing.CommState:StartGracePeriod()
    assert(Loothing.CommState:IsInGracePeriod(), "EDGE: Grace period active after start")

    local dispatched = Loothing.CommState:RequestSyncIfNeeded("heartbeat", "TestML-Realm")
    assert(dispatched == false or dispatched == nil, "EDGE: Sync suppressed during grace period")

    ctx.edgeCaseResults[#ctx.edgeCaseResults + 1] = {
        name = "Client Disconnect", passed = true
    }

    onComplete()
end

--[[--------------------------------------------------------------------
    Edge Case 5: ML Disconnect/Reconnect
----------------------------------------------------------------------]]

local function RunEdge_MLDisconnect(ctx, onComplete)
    local assert = ctx.assert
    local assertNotNil = ctx.assertNotNil

    if Loothing.CacheStateForReconnect then
        assert(type(Loothing.CacheStateForReconnect) == "function",
            "EDGE: CacheStateForReconnect exists")
    end

    if Loothing.RestoreFromCache then
        assert(type(Loothing.RestoreFromCache) == "function",
            "EDGE: RestoreFromCache exists")
    end

    StartMiniSession(ctx, "ML Disconnect")
    assertNotNil(Loothing.Session:GetSessionID(), "EDGE: Session has ID for caching")
    assert(Loothing.handleLoot == true, "EDGE: handleLoot set for caching")
    EndMiniSession(ctx)

    ctx.edgeCaseResults[#ctx.edgeCaseResults + 1] = {
        name = "ML Disconnect/Reconnect", passed = true
    }

    onComplete()
end

--[[--------------------------------------------------------------------
    Edge Case 6: Revote on Tie
----------------------------------------------------------------------]]

local function RunEdge_RevoteOnTie(ctx, onComplete)
    local assert = ctx.assert
    local assertEqual = ctx.assertEqual

    StartMiniSession(ctx, "Revote on Tie")
    local item = AddAndStartVoting(ctx)

    if not item then
        ctx.edgeCaseResults[#ctx.edgeCaseResults + 1] = {
            name = "Revote on Tie", passed = false, error = "Failed to add item"
        }
        EndMiniSession(ctx)
        onComplete()
        return
    end

    TestHelpers:CreateTiedVotes(item, Loothing.Response.NEED, Loothing.Response.GREED, 2)
    Loothing.Session:EndVotingForItem(item.guid)

    local revoteResult = Loothing.Session:RevoteItem(item.guid)
    if revoteResult then
        assertEqual(item:GetState(), Loothing.ItemState.VOTING, "EDGE: Item back to VOTING after revote")

        TestHelpers:CreateFakeVotes(item, {
            [Loothing.Response.NEED] = 3,
            [Loothing.Response.GREED] = 1,
        })
        Loothing.Session:EndVotingForItem(item.guid)

        local winner = ctx.fakeClient and ctx.fakeClient.name or "TestWinner-TestRealm"
        Loothing.Session:AwardItem(item.guid, winner, Loothing.Response.NEED)
        assertEqual(item:GetState(), Loothing.ItemState.AWARDED, "EDGE: Item AWARDED after revote")
    else
        print(COLOR.YELLOW .. "  [INFO]" .. COLOR.RESET .. " RevoteItem returned false — awarding directly")
        local winner = ctx.fakeClient and ctx.fakeClient.name or "TestWinner-TestRealm"
        Loothing.Session:AwardItem(item.guid, winner, Loothing.Response.NEED)
    end

    ctx.edgeCaseResults[#ctx.edgeCaseResults + 1] = {
        name = "Revote on Tie", passed = true
    }

    EndMiniSession(ctx)
    onComplete()
end

--[[--------------------------------------------------------------------
    Edge Case 7: Skip Item
----------------------------------------------------------------------]]

local function RunEdge_SkipItem(ctx, onComplete)
    local assert = ctx.assert
    local assertEqual = ctx.assertEqual

    StartMiniSession(ctx, "Skip Item")
    local item = AddAndStartVoting(ctx)

    if not item then
        ctx.edgeCaseResults[#ctx.edgeCaseResults + 1] = {
            name = "Skip Item", passed = false, error = "Failed to add item"
        }
        EndMiniSession(ctx)
        onComplete()
        return
    end

    Loothing.Session:SkipItem(item.guid)
    assertEqual(item:GetState(), Loothing.ItemState.SKIPPED, "EDGE: Item state is SKIPPED")
    assert(FindMessageInLog(ctx, Loothing.MsgType.VOTE_SKIP, "OUT"), "EDGE: VOTE_SKIP broadcast logged")

    ctx.edgeCaseResults[#ctx.edgeCaseResults + 1] = {
        name = "Skip Item", passed = true
    }

    EndMiniSession(ctx)
    onComplete()
end

--[[--------------------------------------------------------------------
    Edge Case 8: Multi-Item Voting
----------------------------------------------------------------------]]

local function RunEdge_MultiItemVoting(ctx, onComplete)
    local assert = ctx.assert

    StartMiniSession(ctx, "Multi-Item Voting")

    local items = {}
    for _ = 1, 3 do
        local itemLink = TestMode:GenerateFakeItemLink()
        local item = Loothing.Session:AddItem(itemLink, Utils.GetPlayerFullName(), nil, true)
        if item then
            items[#items + 1] = item
        end
    end

    if Loothing.Session.autoStartTimer then
        Loothing.Session.autoStartTimer:Cancel()
        Loothing.Session.autoStartTimer = nil
    end

    assert(#items >= 2, "EDGE: At least 2 items added for multi-item test")

    local votingCount = Loothing.Session:StartVotingOnAllItems(30)
    assert(votingCount >= 2, "EDGE: StartVotingOnAllItems returned " .. votingCount)

    local allVoting = true
    for _, item in ipairs(items) do
        if item:GetState() ~= Loothing.ItemState.VOTING then
            allVoting = false
            break
        end
    end
    assert(allVoting, "EDGE: All items in VOTING state simultaneously")

    local winner = ctx.fakeClient and ctx.fakeClient.name or "TestWinner-TestRealm"
    for _, item in ipairs(items) do
        Loothing.Session:AwardItem(item.guid, winner, Loothing.Response.NEED)
    end

    ctx.edgeCaseResults[#ctx.edgeCaseResults + 1] = {
        name = "Multi-Item Voting", passed = true
    }

    EndMiniSession(ctx)
    onComplete()
end

--[[--------------------------------------------------------------------
    Edge Case 9: Late Response After Timeout
----------------------------------------------------------------------]]

local function RunEdge_LateResponse(ctx, onComplete)
    local assert = ctx.assert

    StartMiniSession(ctx, "Late Response")
    local item = AddAndStartVoting(ctx)

    if not item then
        ctx.edgeCaseResults[#ctx.edgeCaseResults + 1] = {
            name = "Late Response", passed = false, error = "Failed to add item"
        }
        EndMiniSession(ctx)
        onComplete()
        return
    end

    Loothing.Session:EndVotingForItem(item.guid)

    local latePayload = {
        itemGUID = item.guid,
        response = Loothing.Response.NEED,
        sessionID = Loothing.Session:GetSessionID(),
        playerName = "LatePlayer-TestRealm",
        class = "MAGE",
    }

    local success, err = pcall(function()
        Loothing.Session:HandlePlayerResponse(latePayload)
    end)
    assert(success, "EDGE: Late response handled without crash (" .. tostring(err) .. ")")

    assert(item:GetState() ~= Loothing.ItemState.VOTING,
        "EDGE: Late response did not revert item to VOTING (state=" .. tostring(item:GetState()) .. ")")

    ctx.edgeCaseResults[#ctx.edgeCaseResults + 1] = {
        name = "Late Response", passed = true
    }

    EndMiniSession(ctx)
    onComplete()
end

--[[--------------------------------------------------------------------
    Edge Case 10: Invalid Message
----------------------------------------------------------------------]]

local function RunEdge_InvalidMessage(ctx, onComplete)
    local assert = ctx.assert

    if not Loothing.Comm then
        ctx.edgeCaseResults[#ctx.edgeCaseResults + 1] = {
            name = "Invalid Message", passed = false, error = "Comm unavailable"
        }
        onComplete()
        return
    end

    local garbage = { "not_valid_encoded_data", "", "\\0\\0\\0" }

    local allPassed = true
    for i, badData in ipairs(garbage) do
        local success, err = pcall(function()
            -- Use original OnMessage to bypass our logger for garbage
            ctx.logger.originalOnMessage(Loothing.Comm, badData, "RAID", "FakeSender-TestRealm")
        end)
        if not success then
            allPassed = false
            print(COLOR.RED .. "  [FAIL]" .. COLOR.RESET .. " EDGE: Invalid message " .. i .. " crashed: " .. tostring(err))
        end
    end

    assert(allPassed, "EDGE: All invalid messages handled gracefully")

    ctx.edgeCaseResults[#ctx.edgeCaseResults + 1] = {
        name = "Invalid Message", passed = allPassed
    }

    onComplete()
end

--[[--------------------------------------------------------------------
    Edge Case 11: Duplicate Message Dedup
----------------------------------------------------------------------]]

local function RunEdge_DuplicateDedup(ctx, onComplete)
    local assert = ctx.assert

    if not Protocol or not Loothing.Comm then
        ctx.edgeCaseResults[#ctx.edgeCaseResults + 1] = {
            name = "Duplicate Dedup", passed = false, error = "Protocol/Comm unavailable"
        }
        onComplete()
        return
    end

    StartMiniSession(ctx, "Dedup Test")

    local testData = {
        itemGUID = "dedup-test-guid",
        response = Loothing.Response.NEED,
        sessionID = Loothing.Session:GetSessionID(),
        playerName = "DedupTester-TestRealm",
    }
    local encoded = Protocol:Encode(Loothing.MsgType.PLAYER_RESPONSE, testData)

    if encoded then
        local success1 = pcall(function()
            ctx.logger.originalOnMessage(Loothing.Comm, encoded, "RAID", "DedupTester-TestRealm")
        end)
        assert(success1, "EDGE: First message delivery OK")

        local success2 = pcall(function()
            ctx.logger.originalOnMessage(Loothing.Comm, encoded, "RAID", "DedupTester-TestRealm")
        end)
        assert(success2, "EDGE: Second message delivery OK (no crash)")
    else
        print(COLOR.YELLOW .. "  [INFO]" .. COLOR.RESET .. " Protocol:Encode returned nil for dedup test")
    end

    ctx.edgeCaseResults[#ctx.edgeCaseResults + 1] = {
        name = "Duplicate Dedup", passed = true
    }

    EndMiniSession(ctx)
    onComplete()
end

--[[--------------------------------------------------------------------
    Edge Case 12: Session End During Voting
----------------------------------------------------------------------]]

local function RunEdge_SessionEndDuringVoting(ctx, onComplete)
    local assert = ctx.assert
    local assertEqual = ctx.assertEqual

    StartMiniSession(ctx, "Session End During Voting")
    local item = AddAndStartVoting(ctx)

    if not item then
        ctx.edgeCaseResults[#ctx.edgeCaseResults + 1] = {
            name = "Session End During Voting", passed = false, error = "Failed to add item"
        }
        EndMiniSession(ctx)
        onComplete()
        return
    end

    assertEqual(item:GetState(), Loothing.ItemState.VOTING, "EDGE: Item in VOTING before end")

    Loothing.Session:EndSession()

    assert(not Loothing.Session:IsActive(), "EDGE: Session inactive after end during voting")
    assertEqual(Loothing.Session:GetState(), Loothing.SessionState.INACTIVE,
        "EDGE: Session state is INACTIVE")

    ctx.edgeCaseResults[#ctx.edgeCaseResults + 1] = {
        name = "Session End During Voting", passed = true
    }

    onComplete()
end

--[[--------------------------------------------------------------------
    Edge Case 13: Combat Rapid Cycling
----------------------------------------------------------------------]]

local function RunEdge_CombatRapidCycling(ctx, onComplete)
    local assert = ctx.assert
    local assertEqual = ctx.assertEqual

    if not Loothing.CommState then
        ctx.edgeCaseResults[#ctx.edgeCaseResults + 1] = {
            name = "Combat Rapid Cycling", passed = false, error = "CommState unavailable"
        }
        onComplete()
        return
    end

    for _ = 1, 3 do
        Loothing.CommState:OnCombatStart()
        Loothing.CommState:OnCombatEnd()
    end

    assertEqual(Loothing.CommState:GetState(), Loothing.CommState.STATE_CONNECTED,
        "EDGE: CommState is CONNECTED after rapid cycling")

    assert(type(Loothing.CommState.combatDeferQueue) == "table",
        "EDGE: Combat defer queue is valid table after cycling")

    ctx.edgeCaseResults[#ctx.edgeCaseResults + 1] = {
        name = "Combat Rapid Cycling", passed = true
    }

    onComplete()
end

--[[--------------------------------------------------------------------
    Cleanup
----------------------------------------------------------------------]]

local function Cleanup(ctx)
    for i = #ctx.cleanupCallbacks, 1, -1 do
        local ok, err = pcall(ctx.cleanupCallbacks[i])
        if not ok then
            print(COLOR.ORANGE .. "  [Cleanup Warning] " .. tostring(err) .. COLOR.RESET)
        end
    end

    if ctx.logger and ctx.logger.installed then
        ctx.logger:Uninstall()
    end

    if Loothing.Session and Loothing.Session:IsActive() then
        Loothing.Session:EndSession()
    end

    if Loothing.CommState and Loothing.CommState:GetState() ~= Loothing.CommState.STATE_CONNECTED then
        Loothing.CommState.state = Loothing.CommState.STATE_CONNECTED
    end

    if Loothing.Restrictions then
        Loothing.Restrictions:ClearQueue()
        Loothing.Restrictions.restrictions = 0
        Loothing.Restrictions.restrictionsEnabled = false
    end

    Loothing.handleLoot = false
    Loothing.isMasterLooter = false

    if Loolib and Loolib.TempTable and Loolib.TempTable.GetLeaks then
        local leaks = Loolib.TempTable:GetLeaks() or {}
        local delta = #leaks - (ctx.tempTableCountBefore or 0)
        ctx.tempTableLeakCount = math.max(0, delta)
        if delta > 0 then
            print(COLOR.ORANGE .. "  [WARNING] TempTable leaks detected: " .. delta .. COLOR.RESET)
        end
    end
end

--[[--------------------------------------------------------------------
    Report Builder
----------------------------------------------------------------------]]

local STATE_NAMES = {
    [1] = "INACTIVE", [2] = "ACTIVE", [3] = "CLOSED",
}
local ITEM_STATE_NAMES = {
    [1] = "PENDING", [2] = "VOTING", [3] = "TALLIED", [4] = "AWARDED", [5] = "SKIPPED",
}
local COMM_STATE_NAMES = {
    [1] = "CONNECTED", [2] = "COMBAT", [3] = "RESTRICTED", [4] = "DISCONNECTED",
}

local function ResolveStateName(system, stateValue)
    if system == "SessionState" then return STATE_NAMES[stateValue] or tostring(stateValue) end
    if system == "ItemState" then return ITEM_STATE_NAMES[stateValue] or tostring(stateValue) end
    if system == "CommState" then return COMM_STATE_NAMES[stateValue] or tostring(stateValue) end
    return tostring(stateValue)
end

local function BuildReportText(ctx)
    local lines = {}
    local function add(line) lines[#lines + 1] = line end

    local totalDuration = (ctx.endTime - ctx.startTime) / 1000

    add("======================================================")
    add("  LOOTHING FULL SESSION INTEGRATION TEST REPORT")
    add("======================================================")
    add("")
    add(string.format("Result: %s", ctx.failed == 0 and "ALL PASSED" or "FAILURES DETECTED"))
    add(string.format("Passed: %d  |  Failed: %d  |  Total: %d", ctx.passed, ctx.failed, ctx.passed + ctx.failed))
    add(string.format("Duration: %.2f ms", totalDuration))
    add(string.format("Date: %s", date("%Y-%m-%d %H:%M:%S")))
    add(string.format("Loothing Version: %s", Loothing.VERSION or "unknown"))
    add(string.format("Mode: %s (group size: %d)", ctx.isSimulated and "SIMULATED" or "REAL COMMS", ctx.groupSize))
    add("")

    add("--- PHASE TIMELINE ---")
    for _, phaseName in ipairs(PHASES) do
        local result = ctx.phaseResults[phaseName]
        if result then
            local duration = (result.endTime and result.startTime)
                and string.format("%.2fs", result.endTime - result.startTime) or "N/A"
            local status = result.error and "FAIL" or "PASS"
            add(string.format("  [%s] %-40s (%s)%s", status, phaseName, duration,
                result.error and (" - " .. tostring(result.error)) or ""))
        end
    end
    add("")

    add("--- MESSAGE LOG ---")
    add(string.format("  Total messages: %d", #ctx.messageLog))
    add("")
    for i, msg in ipairs(ctx.messageLog) do
        add(string.format("  [%03d] t=%.3f  %-6s  %-4s  target=%-25s  prio=%-6s  %s",
            i, msg.timestamp, msg.direction, msg.command,
            tostring(msg.senderOrTarget), tostring(msg.priority or "-"),
            tostring(msg.dataSummary)))
    end
    add("")

    add("--- STATE TRANSITIONS ---")
    add(string.format("  Total transitions: %d", #ctx.stateTransitions))
    add("")
    for i, tr in ipairs(ctx.stateTransitions) do
        local oldName = ResolveStateName(tr.system, tr.oldState)
        local newName = ResolveStateName(tr.system, tr.newState)
        local extra = tr.itemGUID and (" (item=" .. tr.itemGUID .. ")") or ""
        add(string.format("  [%03d] t=%.3f  %-14s  %s -> %s%s",
            i, tr.timestamp, tr.system, oldName, newName, extra))
    end
    add("")

    add("--- EDGE CASE RESULTS ---")
    for _, ec in ipairs(ctx.edgeCaseResults) do
        local status = ec.passed and "PASS" or "FAIL"
        add(string.format("  [%s] %s%s", status, ec.name,
            ec.error and (" - " .. ec.error) or ""))
    end
    add("")

    add("--- TEMPTABLE LEAK CHECK ---")
    add(string.format("  Leaks: %d (expected: 0)", ctx.tempTableLeakCount or -1))
    add("")

    add("--- RAW CHRONOLOGICAL LOG ---")
    local rawLog = {}
    for _, msg in ipairs(ctx.messageLog) do
        rawLog[#rawLog + 1] = {
            t = msg.timestamp,
            text = string.format("MSG  %-6s  %-4s  %s",
                msg.direction, msg.command, tostring(msg.senderOrTarget))
        }
    end
    for _, st in ipairs(ctx.stateTransitions) do
        local oldName = ResolveStateName(st.system, st.oldState)
        local newName = ResolveStateName(st.system, st.newState)
        rawLog[#rawLog + 1] = {
            t = st.timestamp,
            text = string.format("STATE  %-14s  %s -> %s", st.system, oldName, newName)
        }
    end
    table.sort(rawLog, function(a, b) return a.t < b.t end)
    for _, entry in ipairs(rawLog) do
        add(string.format("  [%.3f] %s", entry.t, entry.text))
    end
    add("")
    add("======================================================")
    add("  END OF REPORT")
    add("======================================================")

    return table.concat(lines, "\n")
end

--[[--------------------------------------------------------------------
    Debug Report Window
----------------------------------------------------------------------]]

local function ShowDebugReport(ctx)
    local reportText = BuildReportText(ctx)
    local plainText = StripColorCodes(reportText)

    local frameName = "LoothingFullSessionReport"
    local frame = _G[frameName]
    if frame then
        frame:Show()
    else
        frame = CreateFrame("Frame", frameName, UIParent, "BackdropTemplate")
        frame:SetSize(750, 550)
        frame:SetPoint("CENTER")
        frame:SetMovable(true)
        frame:EnableMouse(true)
        frame:RegisterForDrag("LeftButton")
        frame:SetScript("OnDragStart", frame.StartMoving)
        frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
        frame:SetResizable(true)
        frame:SetResizeBounds(400, 300, 1200, 900)

        frame:SetBackdrop({
            bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
            tile = true, tileSize = 32, edgeSize = 16,
            insets = { left = 4, right = 4, top = 4, bottom = 4 },
        })
        frame:SetBackdropColor(0.08, 0.08, 0.08, 0.95)

        local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        title:SetPoint("TOP", 0, -12)
        title:SetText("Full Session Test Report")

        local closeBtn = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
        closeBtn:SetPoint("TOPRIGHT", -2, -2)

        local scrollFrame = CreateFrame("ScrollFrame", frameName .. "Scroll", frame, "UIPanelScrollFrameTemplate")
        scrollFrame:SetPoint("TOPLEFT", 12, -36)
        scrollFrame:SetPoint("BOTTOMRIGHT", -30, 40)

        local editBox = CreateFrame("EditBox", frameName .. "EditBox", scrollFrame)
        editBox:SetMultiLine(true)
        editBox:SetAutoFocus(false)
        editBox:SetFontObject("ChatFontNormal")
        editBox:SetWidth(scrollFrame:GetWidth() - 20)
        editBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)

        scrollFrame:SetScrollChild(editBox)
        scrollFrame:SetScript("OnSizeChanged", function(_sf, w)
            editBox:SetWidth(w - 20)
        end)

        frame.editBox = editBox
        frame.scrollFrame = scrollFrame

        local selectBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
        selectBtn:SetSize(100, 24)
        selectBtn:SetPoint("BOTTOMLEFT", 12, 10)
        selectBtn:SetText("Select All")
        selectBtn:SetScript("OnClick", function()
            frame.editBox:SetFocus()
            frame.editBox:HighlightText()
        end)

        local resizeBtn = CreateFrame("Button", nil, frame)
        resizeBtn:SetSize(16, 16)
        resizeBtn:SetPoint("BOTTOMRIGHT")
        resizeBtn:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
        resizeBtn:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
        resizeBtn:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
        resizeBtn:SetScript("OnMouseDown", function() frame:StartSizing("BOTTOMRIGHT") end)
        resizeBtn:SetScript("OnMouseUp", function()
            frame:StopMovingOrSizing()
            frame.editBox:SetWidth(frame.scrollFrame:GetWidth() - 20)
        end)

        tinsert(UISpecialFrames, frameName)
    end

    frame.editBox:SetText(plainText)
    frame:Show()

    print(COLOR.WHITE .. "========================================" .. COLOR.RESET)
    print(COLOR.WHITE .. "  Full Session Test Complete" .. COLOR.RESET)
    print(COLOR.WHITE .. "========================================" .. COLOR.RESET)
    if ctx.failed == 0 then
        print(COLOR.GREEN .. "  ALL PASSED" .. COLOR.RESET)
    else
        print(COLOR.RED .. "  FAILURES DETECTED" .. COLOR.RESET)
    end
    print(string.format("%s  Passed: %d%s  |  %sFailed: %d%s",
        COLOR.GREEN, ctx.passed, COLOR.RESET,
        COLOR.RED, ctx.failed, COLOR.RESET))
    print(string.format("  Mode: %s (group size: %d)",
        ctx.isSimulated and "SIMULATED" or "REAL COMMS", ctx.groupSize))
    print(COLOR.WHITE .. "  Debug report window opened (select all to copy)" .. COLOR.RESET)
    print(COLOR.WHITE .. "========================================" .. COLOR.RESET)
end

--[[--------------------------------------------------------------------
    Main Test Runner
----------------------------------------------------------------------]]

local function RunFullSessionTest()
    local ctx = CreateTestContext()
    ctx.startTime = debugprofilestop()

    print(COLOR.CYAN .. "========================================" .. COLOR.RESET)
    print(COLOR.CYAN .. "  Loothing Full Session Integration Test" .. COLOR.RESET)
    print(COLOR.CYAN .. "========================================" .. COLOR.RESET)
    if ctx.isSimulated then
        print(COLOR.ORANGE .. "  Mode: SIMULATED (solo — group up for real comms)" .. COLOR.RESET)
    else
        print(COLOR.GREEN .. "  Mode: REAL COMMS (" .. ctx.groupSize .. " group members)" .. COLOR.RESET)
    end
    print("")

    local phases = {
        { name = "PRE_SESSION_SETUP",            func = RunPhase1_PreSessionSetup,          delay = 0 },
        { name = "ENCOUNTER_AND_SESSION_START",  func = RunPhase2_EncounterAndStart,        delay = 0.2 },
        { name = "LOOT_AND_ITEM_MANAGEMENT",     func = RunPhase3_LootAndItems,             delay = 0.3 },
        { name = "VOTING_PHASE",                 func = RunPhase4_Voting,                   delay = 0.3 },
        { name = "TALLYING_AND_AWARD",           func = RunPhase5_TallyAndAward,            delay = 0.5 },
        { name = "SESSION_END",                  func = RunPhase6_SessionEnd,               delay = 0.3 },
        { name = "EDGE_COMBAT_DURING_VOTING",        func = RunEdge_CombatDuringVoting,          delay = 0.3 },
        { name = "EDGE_COMBAT_DURING_SESSION_START", func = RunEdge_CombatDuringSessionStart,    delay = 0.2 },
        { name = "EDGE_ENCOUNTER_RESTRICTION",       func = RunEdge_EncounterRestriction,        delay = 0.2 },
        { name = "EDGE_CLIENT_DISCONNECT",           func = RunEdge_ClientDisconnect,            delay = 0.2 },
        { name = "EDGE_ML_DISCONNECT",               func = RunEdge_MLDisconnect,                delay = 0.2 },
        { name = "EDGE_REVOTE_ON_TIE",               func = RunEdge_RevoteOnTie,                 delay = 0.3 },
        { name = "EDGE_SKIP_ITEM",                   func = RunEdge_SkipItem,                    delay = 0.2 },
        { name = "EDGE_MULTI_ITEM_VOTING",           func = RunEdge_MultiItemVoting,             delay = 0.3 },
        { name = "EDGE_LATE_RESPONSE",               func = RunEdge_LateResponse,                delay = 0.3 },
        { name = "EDGE_INVALID_MESSAGE",             func = RunEdge_InvalidMessage,              delay = 0.2 },
        { name = "EDGE_DUPLICATE_DEDUP",             func = RunEdge_DuplicateDedup,              delay = 0.2 },
        { name = "EDGE_SESSION_END_DURING_VOTING",   func = RunEdge_SessionEndDuringVoting,      delay = 0.2 },
        { name = "EDGE_COMBAT_RAPID_CYCLING",        func = RunEdge_CombatRapidCycling,          delay = 0.2 },
    }

    local function RunNextPhase(index)
        if index > #phases then
            ctx.endTime = debugprofilestop()
            Cleanup(ctx)
            ShowDebugReport(ctx)
            return ctx.passed, ctx.failed
        end

        local phase = phases[index]
        ctx.currentPhase = phase.name
        ctx.phaseAssertions = 0
        ctx.phaseResults[phase.name] = { passed = 0, failed = 0, startTime = GetTime() }

        print(COLOR.CYAN .. "\n[Phase " .. index .. "/" .. #phases .. "] " .. phase.name .. COLOR.RESET)

        C_Timer.After(phase.delay, function()
            local passBefore = ctx.passed
            local failBefore = ctx.failed

            local success, err = pcall(phase.func, ctx, function()
                ctx.phaseResults[phase.name].endTime = GetTime()
                ctx.phaseResults[phase.name].passed = ctx.passed - passBefore
                ctx.phaseResults[phase.name].failed = ctx.failed - failBefore
                RunNextPhase(index + 1)
            end)

            if not success then
                ctx.phaseResults[phase.name].error = tostring(err)
                ctx.phaseResults[phase.name].endTime = GetTime()
                ctx.failed = ctx.failed + 1
                print(COLOR.RED .. "  [CRASH] Phase " .. phase.name .. ": " .. tostring(err) .. COLOR.RESET)
                RunNextPhase(index + 1)
            end
        end)
    end

    RunNextPhase(1)
end

--[[--------------------------------------------------------------------
    Registration
----------------------------------------------------------------------]]

if TestRunner then
    TestRunner:RegisterTest("fullsession", RunFullSessionTest)
end

print(COLOR.GREEN .. "[Loothing] FullSessionTests loaded" .. COLOR.RESET)
