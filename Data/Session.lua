--[[--------------------------------------------------------------------
    Loothing - Loot Council Addon for WoW 12.0+
    Session - Loot session management
----------------------------------------------------------------------]]

local Loolib = LibStub("Loolib")

local function IsTestModeEnabled()
    return (Loothing and Loothing.TestMode and Loothing.TestMode:IsActive())
        or (LoothingTestMode and LoothingTestMode:IsEnabled())
end

--[[--------------------------------------------------------------------
    LoothingSessionMixin
----------------------------------------------------------------------]]

LoothingSessionMixin = LoolibCreateFromMixins(LoolibCallbackRegistryMixin)

local SESSION_EVENTS = {
    "OnSessionStarted",
    "OnSessionEnded",
    "OnItemAdded",
    "OnItemRemoved",
    "OnItemStateChanged",
    "OnVotingStarted",
    "OnVotingEnded",
    "OnItemAwarded",
    "OnItemSkipped",
    "OnStateChanged",
    "OnCandidateAdded",
    "OnCandidateUpdated",
    "OnCandidateRollUpdated",
    "OnPlayerResponseAck",
    "OnItemTradabilityChanged",
}

--- Initialize the session manager
function LoothingSessionMixin:Init()
    LoolibCallbackRegistryMixin.OnLoad(self)
    self:GenerateCallbackEvents(SESSION_EVENTS)

    -- Session state
    self.sessionID = nil
    self.encounterID = nil
    self.encounterName = nil
    self.startTime = nil
    self.state = LOOTHING_SESSION_STATE.INACTIVE
    self.masterLooter = nil

    -- Items (DataProvider)
    local Data = Loolib:GetModule("Data")
    self.items = Data.CreateDataProvider()

    -- Current voting item
    self.currentVotingItem = nil
    self.voteTimer = nil

    -- Session trigger mode state
    self.pendingEncounterID = nil
    self.pendingEncounterName = nil
    self.lastEncounterID = nil
    self.lastEncounterName = nil
    self.pendingLootTimer = nil
    self.receivedLootCount = 0
    self.lootBuffer = {}  -- Pre-session loot buffer (items arrive before session starts)

    -- Register for communication events
    self:RegisterCommEvents()
end

--- Safely show RollFrame for loot response
-- @param item table - The item to display
function LoothingSessionMixin:ShowRollFrameForItem(item)
    if not item then return end

    -- RollFrame handles OnVotingStarted events automatically and adds items
    -- This function is for manual display if needed
    local rollFrame = Loothing.UI and Loothing.UI.RollFrame
    if rollFrame and type(rollFrame.AddItem) == "function" then
        local success, err = pcall(function()
            -- Check if item already added (RollFrame may have auto-added it)
            local found = false
            if rollFrame.items then
                for _, existingItem in ipairs(rollFrame.items) do
                    if existingItem.guid == item.guid then
                        found = true
                        break
                    end
                end
            end

            if not found then
                rollFrame:AddItem(item)
            end
        end)
        if not success then
            Loothing:Error("Failed to show RollFrame:", err)
        end
    end
end

-- DEPRECATED: Use ShowRollFrameForItem instead. Kept for external consumer compatibility.
-- @param item table - The item to display
function LoothingSessionMixin:ShowVotePanelForItem(item)
    -- Redirect to RollFrame
    self:ShowRollFrameForItem(item)
end

--- Safely show ResultsPanel to council members
-- @param item table - The item that was voted on
-- @param results table - The voting results
function LoothingSessionMixin:ShowResultsPanelForItem(item, results)
    if not item then return end

    -- Check if player is a council member, ML, or observer
    local isCouncil = Loothing.Council and Loothing.Council:IsPlayerCouncilMember()
    local isML = self:IsMasterLooter()
    local isObserver = Loothing.Observer and Loothing.Observer:IsPlayerObserver()
    local isMLObserver = Loothing.Observer and Loothing.Observer:IsMLObserver()
    if not isCouncil and not isML and not isObserver and not isMLObserver then
        return
    end

    -- Safely show ResultsPanel
    local panel = Loothing.UI and Loothing.UI.ResultsPanel
    if panel and type(panel.SetItem) == "function" and type(panel.Show) == "function" then
        local success, err = pcall(function()
            panel:SetItem(item, results)
            panel:Show()
        end)
        if not success then
            Loothing:Error("Failed to show ResultsPanel:", err)
        end
    end
end

--- Register for communication events
function LoothingSessionMixin:RegisterCommEvents()
    if not Loothing.Comm then return end

    Loothing.Comm:RegisterCallback("OnSessionStart", function(_, data)
        self:HandleRemoteSessionStart(data)
    end, self)

    Loothing.Comm:RegisterCallback("OnSessionEnd", function(_, data)
        self:HandleRemoteSessionEnd(data)
    end, self)

    Loothing.Comm:RegisterCallback("OnItemAdd", function(_, data)
        self:HandleRemoteItemAdd(data)
    end, self)

    Loothing.Comm:RegisterCallback("OnVoteRequest", function(_, data)
        self:HandleRemoteVoteRequest(data)
    end, self)

    Loothing.Comm:RegisterCallback("OnVoteCommit", function(_, data)
        self:HandleRemoteVoteCommit(data)
    end, self)

    Loothing.Comm:RegisterCallback("OnVoteCancel", function(_, data)
        self:HandleRemoteVoteCancel(data)
    end, self)

    Loothing.Comm:RegisterCallback("OnVoteAward", function(_, data)
        self:HandleRemoteVoteAward(data)
    end, self)

    Loothing.Comm:RegisterCallback("OnVoteSkip", function(_, data)
        self:HandleRemoteVoteSkip(data)
    end, self)

    Loothing.Comm:RegisterCallback("OnVoteResults", function(_, data)
        self:HandleRemoteVoteResults(data)
    end, self)

    Loothing.Comm:RegisterCallback("OnPlayerInfoRequest", function(_, data)
        self:HandlePlayerInfoRequest(data)
    end, self)

    Loothing.Comm:RegisterCallback("OnPlayerInfoResponse", function(_, data)
        self:HandlePlayerInfoResponse(data)
    end, self)

    Loothing.Comm:RegisterCallback("OnPlayerResponse", function(_, data)
        self:HandlePlayerResponse(data)
    end, self)

    Loothing.Comm:RegisterCallback("OnPlayerResponseAck", function(_, data)
        self:HandlePlayerResponseAck(data)
    end, self)

    Loothing.Comm:RegisterCallback("OnCandidateUpdate", function(_, data)
        self:HandleRemoteCandidateUpdate(data)
    end, self)

    Loothing.Comm:RegisterCallback("OnVoteUpdate", function(_, data)
        self:HandleRemoteVoteUpdate(data)
    end, self)

    Loothing.Comm:RegisterCallback("OnTradable", function(_, data)
        self:HandleTradable(data)
    end, self)

    Loothing.Comm:RegisterCallback("OnNonTradable", function(_, data)
        self:HandleNonTradable(data)
    end, self)
end

--- Handle tradability status for a looted item
-- @param data table - { itemLink, timeRemaining, playerName, guid, itemID }
function LoothingSessionMixin:HandleTradable(data)
    if not data or not data.itemLink then return end

    -- Find the matching item: prefer GUID > itemID+looter > itemLink fallback
    local matched = nil
    if data.guid then
        matched = self:GetItemByGUID(data.guid)
    end
    if not matched and data.itemID then
        for _, item in self.items:Enumerate() do
            if item.itemID == data.itemID and data.playerName and item.looter == data.playerName then
                matched = item
                break
            end
        end
    end
    if not matched then
        for _, item in self.items:Enumerate() do
            if item.itemLink == data.itemLink and (not data.playerName or item.looter == data.playerName) then
                matched = item
                break
            end
        end
    end

    if matched then
        matched.isTradable = true
        matched.tradeTimeRemaining = data.timeRemaining
        self:TriggerEvent("OnItemTradabilityChanged", matched)
    end
end

--- Handle non-tradability status for a looted item
-- @param data table - { itemLink, playerName, guid, itemID }
function LoothingSessionMixin:HandleNonTradable(data)
    if not data or not data.itemLink then return end

    -- Find the matching item: prefer GUID > itemID+looter > itemLink fallback
    local matched = nil
    if data.guid then
        matched = self:GetItemByGUID(data.guid)
    end
    if not matched and data.itemID then
        for _, item in self.items:Enumerate() do
            if item.itemID == data.itemID and data.playerName and item.looter == data.playerName then
                matched = item
                break
            end
        end
    end
    if not matched then
        for _, item in self.items:Enumerate() do
            if item.itemLink == data.itemLink and (not data.playerName or item.looter == data.playerName) then
                matched = item
                break
            end
        end
    end

    if matched then
        matched.isTradable = false
        matched.tradeTimeRemaining = nil
        self:TriggerEvent("OnItemTradabilityChanged", matched)
    end
end

--[[--------------------------------------------------------------------
    Session Lifecycle
----------------------------------------------------------------------]]

--- Start a new loot session
-- @param encounterID number
-- @param encounterName string
-- @return boolean
function LoothingSessionMixin:StartSession(encounterID, encounterName)
    if self.state ~= LOOTHING_SESSION_STATE.INACTIVE then
        Loothing:Debug("Session already active")
        return false
    end

    if not IsInGroup() and not IsTestModeEnabled() then
        Loothing:Debug("Cannot start session outside a group")
        return false
    end

    if not Loothing.handleLoot and not IsTestModeEnabled() then
        Loothing:Debug("Not designated to handle loot")
        return false
    end

    local sessionID = LoothingUtils.GenerateGUID()
    if Loothing and Loothing.TestMode and Loothing.TestMode.ApplySessionTag then
        sessionID = Loothing.TestMode:ApplySessionTag(sessionID)
    end

    self.sessionID = sessionID
    self.encounterID = encounterID
    self.encounterName = encounterName
    self.startTime = time()
    self.masterLooter = LoothingUtils.GetPlayerFullName()

    self:SetState(LOOTHING_SESSION_STATE.ACTIVE)

    -- Broadcast to raid (include authoritative sessionID)
    Loothing.Comm:BroadcastSessionStart(encounterID, encounterName, self.sessionID)

    -- Also broadcast council roster
    if Loothing.Council then
        local members = Loothing.Council:GetAllMembers()
        Loothing.Comm:BroadcastCouncilRoster(members)
    end

    -- Start ML heartbeat for session-state auto-recovery on clients
    if Loothing.AckTracker then
        Loothing.AckTracker:StartHeartbeat()
    end

    self:TriggerEvent("OnSessionStarted", self.sessionID, encounterID, encounterName)
    Loothing:Print(string.format(LOOTHING_LOCALE["SESSION_STARTED"], encounterName or "Manual Session"))

    -- Replay buffered loot items from before session started
    local bufferTTL = LOOTHING_TIMING and LOOTHING_TIMING.LOOT_BUFFER_TTL or 60
    local now = time()
    for _, entry in ipairs(self.lootBuffer) do
        if entry.encounterID == encounterID and (now - entry.timestamp) <= bufferTTL then
            self:AddItem(entry.itemLink, entry.playerName)
        end
    end
    wipe(self.lootBuffer)

    return true
end

--- End the current session
-- @return boolean
function LoothingSessionMixin:EndSession()
    if self.state == LOOTHING_SESSION_STATE.INACTIVE then
        -- Still cleanup pending state even if inactive
        LoothingPopups:Hide("LOOTHING_CONFIRM_START_SESSION")
        return false
    end

    -- Cancel any active voting (handles multiple items)
    local votingItems = self:GetVotingItems()
    if votingItems and #votingItems > 0 then
        self:CancelVoting()  -- Cancels all voting items when called without guid
    end

    -- Cancel afterRolls mode timer if running
    if self.pendingLootTimer then
        self.pendingLootTimer:Cancel()
        self.pendingLootTimer = nil
    end

    -- Cancel skipSessionFrame auto-start timer if running
    if self.autoStartTimer then
        self.autoStartTimer:Cancel()
        self.autoStartTimer = nil
    end

    -- Clear trigger mode state
    self.receivedLootCount = 0
    self.pendingEncounterID = nil
    self.pendingEncounterName = nil
    if self.lootBuffer then wipe(self.lootBuffer) end

    -- Hide any pending session prompt dialog
    LoothingPopups:Hide("LOOTHING_CONFIRM_START_SESSION")

    local sessionID = self.sessionID
    local wasML = self:IsMasterLooter()

    -- Clear timer references on all items before flushing (prevents memory leaks)
    for _, item in self.items:Enumerate() do
        if item.voteTimer then
            item.voteTimer:Cancel()
            item.voteTimer = nil
        end
    end

    -- Clear session data
    self.sessionID = nil
    self.encounterID = nil
    self.encounterName = nil
    self.startTime = nil
    self.masterLooter = nil
    self.currentVotingItem = nil
    self.items:Flush()

    self:SetState(LOOTHING_SESSION_STATE.INACTIVE)

    -- Stop ML heartbeat
    if Loothing.AckTracker then
        Loothing.AckTracker:StopHeartbeat()
    end

    -- Clear remote council roster so local roster becomes primary again
    if Loothing.Council then
        Loothing.Council:ClearRemoteRoster()
    end

    -- Broadcast to raid (only ML should broadcast end)
    if wasML then
        Loothing.Comm:BroadcastSessionEnd()
    end

    self:TriggerEvent("OnSessionEnded", sessionID)
    Loothing:Print(LOOTHING_LOCALE["SESSION_ENDED"])

    return true
end

--- Close session (no more items, finish voting)
function LoothingSessionMixin:CloseSession()
    if self.state ~= LOOTHING_SESSION_STATE.ACTIVE then
        return false
    end

    self:SetState(LOOTHING_SESSION_STATE.CLOSED)
    return true
end

--[[--------------------------------------------------------------------
    State Management
----------------------------------------------------------------------]]

--- Get current state
-- @return number
function LoothingSessionMixin:GetState()
    return self.state
end

--- Set state
-- @param state number
function LoothingSessionMixin:SetState(state)
    if self.state ~= state then
        local oldState = self.state
        self.state = state
        self:TriggerEvent("OnStateChanged", state, oldState)
    end
end

--- Check if session is active
-- @return boolean
function LoothingSessionMixin:IsActive()
    return self.state ~= LOOTHING_SESSION_STATE.INACTIVE
end

--- Get session ID
-- @return string|nil
function LoothingSessionMixin:GetSessionID()
    return self.sessionID
end

--- Validate a sessionID against current session
-- @param sessionID string|nil
-- @return boolean
function LoothingSessionMixin:IsCurrentSession(sessionID)
    if not sessionID or sessionID == "" then
        return false
    end
    return self.sessionID == sessionID
end

--- Get encounter ID
-- @return number|nil
function LoothingSessionMixin:GetEncounterID()
    return self.encounterID
end

--- Get encounter name
-- @return string|nil
function LoothingSessionMixin:GetEncounterName()
    return self.encounterName
end

--- Get master looter
-- @return string|nil
function LoothingSessionMixin:GetMasterLooter()
    return self.masterLooter
end

--- Check if local player is the master looter
-- @return boolean
function LoothingSessionMixin:IsMasterLooter()
    if self.masterLooter then
        return self.masterLooter == LoothingUtils.GetPlayerFullName()
    end
    return Loothing.handleLoot == true
end

--[[--------------------------------------------------------------------
    Item Management
----------------------------------------------------------------------]]

--- Add an item to the session
-- @param itemLink string
-- @param looter string
-- @param guid string|nil - Optional GUID (uses new one if nil)
-- @param force boolean - Force add (bypass quality check)
-- @return table|nil - The item, or nil if failed
function LoothingSessionMixin:AddItem(itemLink, looter, guid, force)
    if self.state == LOOTHING_SESSION_STATE.INACTIVE then
        return nil
    end

    if self.state == LOOTHING_SESSION_STATE.CLOSED then
        Loothing:Debug("Cannot add items to a closed session")
        return nil
    end

    -- Check quality threshold
    if not force then
        local quality = LoothingUtils.GetItemQuality(itemLink)
        if quality < LOOTHING_MIN_QUALITY then
            Loothing:Debug("Item below quality threshold:", itemLink)
            return nil
        end
    end

    -- Filter check
    if not force and Loothing.ItemFilter and Loothing.ItemFilter:ShouldIgnoreItem(itemLink) then
        Loothing:Debug("Item filtered:", itemLink)
        return nil
    end

    -- Dedup by GUID
    if guid and self:GetItemByGUID(guid) then
        return self:GetItemByGUID(guid)
    end

    -- Create item
    local item = CreateLoothingItem(itemLink, looter, self.encounterID)
    if guid then
        item.guid = guid
    end

    -- Listen for state changes
    item:RegisterCallback("OnStateChanged", function(_, newState, oldState)
        self:TriggerEvent("OnItemStateChanged", item, newState, oldState)
    end, self)

    -- Add to collection
    self.items:Insert(item)

    -- Check auto-award before broadcasting
    if Loothing.AutoAward and self:IsMasterLooter() then
        if Loothing.AutoAward:ProcessItem(itemLink, item.guid) then
            return item
        end
    end

    -- Broadcast to raid if we're ML
    if self:IsMasterLooter() then
        Loothing.Comm:BroadcastItemAdd(itemLink, item.guid, looter)
    end

    self:TriggerEvent("OnItemAdded", item)

    -- skipSessionFrame: auto-start voting after items stop arriving
    if self:IsMasterLooter() and Loothing.Settings:Get("ml.skipSessionFrame", true) then
        if self.autoStartTimer then
            self.autoStartTimer:Cancel()
        end
        self.autoStartTimer = C_Timer.NewTimer(2, function()
            self:StartVotingOnAllItems()
            self.autoStartTimer = nil
        end)
    end

    return item
end

--- Remove an item from the session
-- @param guid string
-- @return boolean
function LoothingSessionMixin:RemoveItem(guid)
    local item = self:GetItemByGUID(guid)
    if not item then
        return false
    end

    self.items:Remove(item)
    self:TriggerEvent("OnItemRemoved", item)
    return true
end

--- Get item by GUID
-- @param guid string
-- @return table|nil
function LoothingSessionMixin:GetItemByGUID(guid)
    for _, item in self.items:Enumerate() do
        if item.guid == guid then
            return item
        end
    end
    return nil
end

--- Get all items
-- @return DataProvider
function LoothingSessionMixin:GetItems()
    return self.items
end

--- Get pending items
-- @return table
function LoothingSessionMixin:GetPendingItems()
    local pending = {}
    for _, item in self.items:Enumerate() do
        if item:IsPending() then
            pending[#pending + 1] = item
        end
    end
    return pending
end

--- Get item count
-- @return number
function LoothingSessionMixin:GetItemCount()
    return self.items:GetSize()
end

--[[--------------------------------------------------------------------
    Voting Management
----------------------------------------------------------------------]]

--- Start voting on an item
-- @param guid string - Item GUID
-- @param timeout number - Optional timeout
-- @param skipBroadcast boolean - If true, caller is responsible for broadcasting vote request
-- @return boolean
function LoothingSessionMixin:StartVoting(guid, timeout, skipBroadcast)
    if not self:IsMasterLooter() then
        Loothing:Debug("Not master looter, cannot start voting")
        return false
    end

    if self.state == LOOTHING_SESSION_STATE.CLOSED then
        Loothing:Debug("Cannot start voting on a closed session")
        return false
    end

    if self.state ~= LOOTHING_SESSION_STATE.ACTIVE then
        Loothing:Debug("Cannot start voting when session is not active")
        return false
    end

    local item = self:GetItemByGUID(guid)
    if not item then
        Loothing:Debug("Item not found")
        return false
    end

    -- Allow starting voting on pending items (skip if already voting/completed)
    if not item:IsPending() then
        Loothing:Debug("Item not pending, state:", item:GetState())
        return false
    end

    timeout = timeout or Loothing.Settings:GetVotingTimeout()

    if not item:StartVoting(timeout) then
        return false
    end

    -- Broadcast vote request for this item (skipped when batching via StartVotingOnAllItems)
    if not skipBroadcast then
        Loothing.Comm:BroadcastVoteRequest(guid, timeout, self.sessionID)
    end

    -- Request gear info from council members in the raid (not all members)
    if Loothing.Council then
        local members = Loothing.Council:GetMembersInRaid()
        for _, member in ipairs(members) do
            self:RequestPlayerGearInfo(guid, member)
        end
    end

    -- Start timeout timer per-item (timeout == 0 means no timeout)
    if item.voteTimer then
        item.voteTimer:Cancel()
        item.voteTimer = nil
    end
    if timeout > 0 then
        item.voteTimer = C_Timer.NewTimer(timeout, function()
            self:OnItemVoteTimeout(item)
        end)
    end

    self:TriggerEvent("OnVotingStarted", item, timeout)

    return true
end

--- Start voting on all pending items at once
-- @param timeout number - Optional timeout
-- @return number - Count of items now in voting state
function LoothingSessionMixin:StartVotingOnAllItems(timeout)
    if not self:IsMasterLooter() then
        Loothing:Debug("Not master looter, cannot start voting")
        return 0
    end

    timeout = timeout or Loothing.Settings:GetVotingTimeout()
    local count = 0

    -- Collect pending items
    local pendingItems = {}
    for _, item in self.items:Enumerate() do
        if item:IsPending() then
            pendingItems[#pendingItems + 1] = item
        end
    end

    -- Sort by typeCode then ilvl descending if setting enabled
    if Loothing.Settings:Get("ml.sortItems", false) then
        table.sort(pendingItems, function(a, b)
            if a.typeCode ~= b.typeCode then
                return (a.typeCode or "default") < (b.typeCode or "default")
            end
            return (a.itemLevel or 0) > (b.itemLevel or 0)
        end)
    end

    -- Use batch sending: collect all vote requests, flush as 1-2 BATCH messages
    -- instead of N individual BroadcastVoteRequest calls.
    local useBatch = self:IsMasterLooter() and Loothing.Comm and IsInGroup()

    for _, item in ipairs(pendingItems) do
        if self:StartVoting(item.guid, timeout, useBatch) then
            count = count + 1
            if useBatch then
                Loothing.Comm:QueueForBatch(LOOTHING_MSG_TYPE.VOTE_REQUEST, {
                    itemGUID  = item.guid,
                    timeout   = timeout,
                    sessionID = self.sessionID,
                }, nil, "NORMAL")
            end
        end
    end

    -- Flush immediately so raiders see vote requests as a single burst
    if useBatch and count > 0 then
        Loothing.Comm:FlushAll()
    end

    Loothing:Debug("Started voting on", count, "items")
    return count
end

--- Handle per-item vote timeout
-- @param item table - The item that timed out
function LoothingSessionMixin:OnItemVoteTimeout(item)
    if not item or not item:IsVoting() then
        return
    end

    Loothing:Debug("Vote timeout for item:", item.name)

    -- End voting on this item (will broadcast results if ML)
    self:EndVotingForItem(item.guid)
end

--- Cancel voting on a specific item
-- @param guid string - Item GUID (optional, cancels all if nil)
-- @return boolean
function LoothingSessionMixin:CancelVoting(guid)
    if guid then
        -- Cancel specific item
        local item = self:GetItemByGUID(guid)
        if not item or not item:IsVoting() then
            return false
        end

        if item.voteTimer then
            item.voteTimer:Cancel()
            item.voteTimer = nil
        end

        item:SetState(LOOTHING_ITEM_STATE.PENDING)
        if self:IsMasterLooter() and Loothing.Comm then
            Loothing.Comm:BroadcastVoteCancel(guid, self.sessionID)
        end
        return true
    else
        -- Cancel all voting items
        -- Collect items first to avoid race conditions during iteration
        local itemsToCancel = {}
        for _, item in self.items:Enumerate() do
            if item:IsVoting() then
                itemsToCancel[#itemsToCancel + 1] = item
            end
        end

        -- Now cancel each collected item
        for _, item in ipairs(itemsToCancel) do
            if item.voteTimer then
                item.voteTimer:Cancel()
                item.voteTimer = nil
            end
            item:SetState(LOOTHING_ITEM_STATE.PENDING)

            if self:IsMasterLooter() and Loothing.Comm then
                Loothing.Comm:BroadcastVoteCancel(item.guid, self.sessionID)
            end
        end

        return #itemsToCancel > 0
    end
end

--- End voting on a specific item and tally results
-- @param guid string - Item GUID
-- @return table|nil - Tally results
function LoothingSessionMixin:EndVotingForItem(guid)
    local item = self:GetItemByGUID(guid)
    if not item or not item:IsVoting() then
        return nil
    end

    -- Clear item's timer
    if item.voteTimer then
        item.voteTimer:Cancel()
        item.voteTimer = nil
    end

    item:EndVoting()

    -- Tally votes
    local results = nil
    if Loothing.VotingEngine then
        results = Loothing.VotingEngine:Tally(item:GetVotes())
    end

    self:TriggerEvent("OnVotingEnded", item, results)

    -- Broadcast closure/results so council/raiders can close UI
    if self:IsMasterLooter() and Loothing.Comm then
        Loothing.Comm:BroadcastVoteResults(item.guid, results, self.sessionID)
    end

    return results
end

-- DEPRECATED: Use EndVotingForItem(guid) instead. Kept for external consumer compatibility.
-- @param guid string - Optional item GUID
-- @return table|nil - Tally results for last item
function LoothingSessionMixin:EndVoting(guid)
    if guid then
        return self:EndVotingForItem(guid)
    end

    -- End all voting items
    local lastResults = nil
    for _, item in self.items:Enumerate() do
        if item:IsVoting() then
            lastResults = self:EndVotingForItem(item.guid)
        end
    end
    return lastResults
end

--- Handle vote timeout (legacy - now handled per-item)
function LoothingSessionMixin:OnVoteTimeout()
    Loothing:Debug("Vote timeout (legacy)")
    self:EndVoting()
end

--- Get all items currently in voting state
-- @return table - Array of voting items
function LoothingSessionMixin:GetVotingItems()
    local votingItems = {}
    for _, item in self.items:Enumerate() do
        if item:IsVoting() then
            votingItems[#votingItems + 1] = item
        end
    end
    return votingItems
end

--- Get current voting item (legacy - returns first voting item)
-- @return table|nil
function LoothingSessionMixin:GetCurrentVotingItem()
    for _, item in self.items:Enumerate() do
        if item:IsVoting() then
            return item
        end
    end
    return nil
end

--- Update a candidate's voter list based on current votes
-- @param item table - The item
-- @param candidateName string - Name of the candidate
function LoothingSessionMixin:UpdateCandidateVoters(item, candidateName)
    if not item or not candidateName then return end

    local candidateManager = item.GetCandidateManager and item:GetCandidateManager()
    if not candidateManager then
        return
    end

    -- Prefer existing candidate; fall back to create so we don't explode on missing data
    local candidate = candidateManager:GetCandidate(candidateName)
    if not candidate then
        -- Try to pick up class from raid roster for accuracy
        local candidateClass = "UNKNOWN"
        local roster = LoothingUtils.GetRaidRoster()
        for _, member in ipairs(roster) do
            if LoothingUtils.IsSamePlayer(member.name, candidateName) then
                candidateClass = member.classFile or "UNKNOWN"
                break
            end
        end
        candidate = candidateManager:GetOrCreateCandidate(candidateName, candidateClass)
    end
    if not candidate then return end

    local voters = {}
    -- Iterate all votes to find who voted for this candidate
    for _, vote in item:GetVotes():Enumerate() do
        if vote.responses then
            for _, response in ipairs(vote.responses) do
                if response == candidateName then
                    table.insert(voters, vote.voter)
                    break
                end
            end
        end
    end

    candidate.voters = voters
    candidate.councilVotes = #voters

    -- Mark whether the local player has voted for this candidate
    local myName = LoothingUtils.GetPlayerFullName()
    candidate.hasMyVote = false
    for _, voter in ipairs(voters) do
        if LoothingUtils.IsSamePlayer(voter, myName) then
            candidate.hasMyVote = true
            break
        end
    end

    -- Trigger update locally
    self:TriggerEvent("OnCandidateUpdated", item, candidate)

    return candidate
end

--- Cast a vote for a specific candidate on an item (per-candidate toggle)
-- @param itemGUID string - Item GUID
-- @param candidateName string - Candidate to add to voter's responses
-- @return boolean
function LoothingSessionMixin:CastVote(itemGUID, candidateName)
    if not itemGUID or not candidateName then
        Loothing:Debug("CastVote: nil itemGUID or candidateName")
        return false
    end

    local item = self:GetItemByGUID(itemGUID)
    if not item then
        Loothing:Debug("CastVote: item not found for GUID", itemGUID)
        return false
    end
    if not item:IsVoting() then
        Loothing:Debug("CastVote: item not in VOTING state, state =", item:GetState())
        return false
    end

    local voter = LoothingUtils.GetPlayerFullName()
    local existing = item:GetVoteByVoter(voter)

    -- Copy existing responses, skipping any duplicate, then append
    local newResponses = {}
    if existing and existing.responses then
        for _, name in ipairs(existing.responses) do
            if name ~= candidateName then
                newResponses[#newResponses + 1] = name
            end
        end
    end
    newResponses[#newResponses + 1] = candidateName

    return self:SubmitVote(itemGUID, newResponses)
end

--- Retract a vote for a specific candidate on an item (per-candidate toggle)
-- @param itemGUID string - Item GUID
-- @param candidateName string - Candidate to remove from voter's responses
-- @return boolean
function LoothingSessionMixin:RetractVote(itemGUID, candidateName)
    if not itemGUID or not candidateName then return false end

    local item = self:GetItemByGUID(itemGUID)
    if not item or not item:IsVoting() then return false end

    local voter = LoothingUtils.GetPlayerFullName()
    local existing = item:GetVoteByVoter(voter)
    if not existing then return false end

    -- Build new responses excluding this candidate
    local newResponses = {}
    for _, name in ipairs(existing.responses or {}) do
        if name ~= candidateName then
            newResponses[#newResponses + 1] = name
        end
    end

    if #newResponses == 0 then
        return self:RetractAllVotes(itemGUID)
    end

    return self:SubmitVote(itemGUID, newResponses)
end

--- Retract all votes on an item (clears the voter's full response list)
-- @param itemGUID string - Item GUID
-- @return boolean
function LoothingSessionMixin:RetractAllVotes(itemGUID)
    if not itemGUID then return false end

    local item = self:GetItemByGUID(itemGUID)
    if not item or not item:IsVoting() then return false end

    local voter = LoothingUtils.GetPlayerFullName()

    -- Snapshot affected candidates before removing the vote locally
    local existing = item:GetVoteByVoter(voter)
    local affectedCandidates = {}
    if existing and existing.responses then
        for _, name in ipairs(existing.responses) do
            affectedCandidates[#affectedCandidates + 1] = name
        end
    end

    -- Remove vote locally
    item:RemoveVote(voter)

    if not self:IsMasterLooter() and IsInGroup() then
        -- Signal ML to clear this voter's vote by sending empty responses
        Loothing.Comm:SendVoteCommit(
            item.guid,
            {},
            self.masterLooter,
            self.sessionID
        )
    elseif self:IsMasterLooter() then
        -- ML: rebuild and broadcast voter lists — batch all affected candidates
        if Loothing.Comm and item.candidateManager and IsInGroup() then
            for _, candidateName in ipairs(affectedCandidates) do
                self:UpdateCandidateVoters(item, candidateName)
                local candidate = item.candidateManager:GetCandidate(candidateName)
                if candidate then
                    Loothing.Comm:QueueForBatch(LOOTHING_MSG_TYPE.VOTE_UPDATE, {
                        itemGUID      = item.guid,
                        candidateName = candidateName,
                        voters        = candidate.voters,
                        sessionID     = self.sessionID,
                    }, nil, "NORMAL")
                end
            end
            Loothing.Comm:FlushAll()
        end
    end

    return true
end

--- Submit a vote for a specific item
-- @param itemGUID string - Item GUID
-- @param responses table - Ranked responses
-- @return boolean
function LoothingSessionMixin:SubmitVote(itemGUID, responses)
    if not itemGUID then
        Loothing:Error("SubmitVote called with nil itemGUID")
        return false
    end

    local item = self:GetItemByGUID(itemGUID)
    if not item or not item:IsVoting() then
        return false
    end

    local voter = LoothingUtils.GetPlayerFullName()
    local _, class = UnitClass("player")

    -- Only council members should vote (bypass in test mode)
    local isTestMode = LoothingTestMode and LoothingTestMode:IsEnabled()
    if Loothing.Council and not Loothing.Council:IsMember(voter) and not isTestMode then
        Loothing:Debug("SubmitVote: rejected - not a council member:", voter)
        Loothing:Error("You are not on the council for this session.")
        return false
    end

    -- Add vote locally
    item:AddVote(voter, class, responses)

    -- Always update candidate voter lists locally (sets hasMyVote, councilVotes)
    if item.candidateManager then
        for _, candidate in ipairs(item.candidateManager:GetAllCandidates()) do
            self:UpdateCandidateVoters(item, candidate.playerName)
        end
    end

    -- Network: send or broadcast depending on role
    if not self:IsMasterLooter() and IsInGroup() then
        Loothing.Comm:SendVoteCommit(
            item.guid,
            responses,
            self.masterLooter,
            self.sessionID
        )
    elseif self:IsMasterLooter() and Loothing.Comm and IsInGroup() then
        -- Broadcast vote updates — batch all candidates into 1-2 messages
        if item.candidateManager then
            for _, candidate in ipairs(item.candidateManager:GetAllCandidates()) do
                Loothing.Comm:QueueForBatch(LOOTHING_MSG_TYPE.VOTE_UPDATE, {
                    itemGUID      = item.guid,
                    candidateName = candidate.playerName,
                    voters        = candidate.voters,
                    sessionID     = self.sessionID,
                }, nil, "NORMAL")
            end
            Loothing.Comm:FlushAll()
        end
    end

    return true
end

--[[--------------------------------------------------------------------
    Award/Skip
----------------------------------------------------------------------]]

--- Award an item to a player
-- @param guid string - Item GUID
-- @param winner string - Winner name
-- @param response number - Optional response type
-- @param awardReasonId number - Optional award reason ID
-- @return boolean
function LoothingSessionMixin:AwardItem(guid, winner, response, awardReasonId)
    if not self:IsMasterLooter() then
        return false
    end

    local item = self:GetItemByGUID(guid)
    if not item then
        return false
    end

    if item:IsComplete() or item:IsPending() then
        Loothing:Debug("Cannot award item in state", item:GetState())
        return false
    end

    item:SetWinner(winner, response)

    -- Broadcast
    Loothing.Comm:BroadcastVoteAward(guid, winner, self.sessionID)

    -- Add to history
    if Loothing.History then
        -- Winner candidate snapshot
        local winnerCandidate = item.candidateManager and item.candidateManager:GetCandidate(winner)

        -- Snapshot all candidate responses
        local candidatesSnapshot = {}
        if item.candidateManager then
            for _, c in ipairs(item.candidateManager:GetAllCandidates()) do
                candidatesSnapshot[#candidatesSnapshot + 1] = {
                    playerName   = c.playerName,
                    playerClass  = c.playerClass,
                    response     = c.response,
                    note         = c.note,
                    roll         = c.roll,
                    gear1Link    = c.gear1Link,
                    gear2Link    = c.gear2Link,
                    gear1ilvl    = c.gear1ilvl,
                    gear2ilvl    = c.gear2ilvl,
                    ilvlDiff     = c.ilvlDiff,
                    councilVotes = c.councilVotes,
                }
            end
        end

        -- Snapshot all council votes (copy responses array to avoid aliasing)
        local councilVotesSnapshot = {}
        for _, vote in item:GetVotes():Enumerate() do
            local responsesCopy = {}
            if vote.responses then
                for i, r in ipairs(vote.responses) do
                    responsesCopy[i] = r
                end
            end
            councilVotesSnapshot[#councilVotesSnapshot + 1] = {
                voter      = vote.voter,
                voterClass = vote.voterClass,
                responses  = responsesCopy,
                note       = vote.note,
            }
        end

        -- Resolve awardReason text
        local awardReason = nil
        if awardReasonId and LOOTHING_RESPONSE_INFO and LOOTHING_RESPONSE_INFO[awardReasonId] then
            awardReason = LOOTHING_RESPONSE_INFO[awardReasonId].name
        end

        local instanceData = item.instanceData or {}

        Loothing.History:AddEntry({
            -- Item identification
            itemLink      = item.itemLink,
            itemID        = item.itemID,
            equipSlot     = item.equipSlot,
            typeCode      = item.typeCode,
            subType       = item.subType,
            typeID        = item.typeID,
            subTypeID     = item.subTypeID,
            bindType      = item.bindType,
            isBoe         = item.isBoe,
            -- Winner info
            winner          = winner,
            winnerResponse  = response,
            winnerClass     = winnerCandidate and winnerCandidate.playerClass or nil,
            winnerNote      = winnerCandidate and winnerCandidate.note or nil,
            winnerRoll      = winnerCandidate and winnerCandidate.roll or nil,
            winnerGear1     = winnerCandidate and winnerCandidate.gear1Link or nil,
            winnerGear2     = winnerCandidate and winnerCandidate.gear2Link or nil,
            winnerGear1ilvl = winnerCandidate and winnerCandidate.gear1ilvl or nil,
            winnerGear2ilvl = winnerCandidate and winnerCandidate.gear2ilvl or nil,
            winnerIlvlDiff  = winnerCandidate and winnerCandidate.ilvlDiff or nil,
            -- Session / encounter
            encounterID    = self.encounterID,
            encounterName  = self.encounterName,
            instance       = instanceData.name,
            difficultyID   = instanceData.difficultyID,
            difficultyName = instanceData.difficultyName,
            groupSize      = instanceData.groupSize,
            mapID          = instanceData.mapID,
            -- Award metadata
            votes         = item:GetVotes():GetSize(),
            timestamp     = time(),
            awardReasonId = awardReasonId,
            awardReason   = awardReason,
            owner         = item.looter,
            -- Full snapshots
            candidates   = candidatesSnapshot,
            councilVotes = councilVotesSnapshot,
        })
    end

    self:TriggerEvent("OnItemAwarded", item, winner, response)

    -- Announce via Announcer (handles token replacement, multi-line, combat queueing)
    if Loothing.Announcer then
        Loothing.Announcer:AnnounceAward(item.itemLink, winner, response, {
            itemLevel = item.itemLevel,
            itemType = item.subType,
            votes = item:GetVotes():GetSize(),
            session = self.encounterName,
        })
    end

    return true
end

--- Skip an item
-- @param guid string - Item GUID
-- @return boolean
function LoothingSessionMixin:SkipItem(guid)
    if not self:IsMasterLooter() then
        return false
    end

    local item = self:GetItemByGUID(guid)
    if not item then
        return false
    end

    if item:IsComplete() then
        Loothing:Debug("Cannot skip already completed item")
        return false
    end

    item:Skip()

    -- Broadcast
    Loothing.Comm:BroadcastVoteSkip(guid, self.sessionID)

    self:TriggerEvent("OnItemSkipped", item)
    return true
end

--- Revote on a previously voted item (resets votes and restarts voting)
-- @param guid string - Item GUID
-- @return boolean
function LoothingSessionMixin:RevoteItem(guid)
    if not self:IsMasterLooter() then
        Loothing:Debug("Not master looter, cannot revote")
        return false
    end

    local item = self:GetItemByGUID(guid)
    if not item then
        Loothing:Debug("Item not found for revote")
        return false
    end

    -- Flush votes and reset to pending
    if item.votes then
        item.votes:Flush()
    end
    item:SetState(LOOTHING_ITEM_STATE.PENDING)

    -- Start voting again (handles broadcast internally)
    return self:StartVoting(guid)
end

--[[--------------------------------------------------------------------
    Event Handlers (WoW Events)
----------------------------------------------------------------------]]

--- Handle encounter start
function LoothingSessionMixin:OnEncounterStart(encounterID, encounterName, difficultyID, groupSize)
    -- Wipe stale buffer from previous encounter that never started a session
    if self.lootBuffer then wipe(self.lootBuffer) end
end

--- Handle encounter end
-- @param encounterID number
-- @param encounterName string
-- @param difficultyID number
-- @param groupSize number
-- @param success number - 1 if boss killed, 0 if wipe
function LoothingSessionMixin:OnEncounterEnd(encounterID, encounterName, difficultyID, groupSize, success)
    if success ~= 1 then return end
    if not IsInGroup() and not IsTestModeEnabled() then return end
    if not Loothing.handleLoot and not IsTestModeEnabled() then return end
    if self.state ~= LOOTHING_SESSION_STATE.INACTIVE then
        Loothing:Debug("Encounter ended but session already active, ignoring:", encounterName)
        return
    end

    local mode = Loothing.Settings:GetSessionTriggerMode()

    -- Only store encounter info for modes that need it (prompt and afterRolls)
    if mode == "prompt" or mode == "afterRolls" then
        self.lastEncounterID = encounterID
        self.lastEncounterName = encounterName
    end

    if mode == "auto" then
        self:StartSession(encounterID, encounterName)
    elseif mode == "prompt" then
        self:ShowSessionPrompt(encounterID, encounterName)
    end
    -- "manual" and "afterRolls" modes: do nothing here (afterRolls triggers on loot receipt)
end

--- Show session start confirmation dialog to ML
-- @param encounterID number
-- @param encounterName string
function LoothingSessionMixin:ShowSessionPrompt(encounterID, encounterName)
    -- Guard: Don't show if session already active
    if self.state ~= LOOTHING_SESSION_STATE.INACTIVE then
        return
    end

    -- Guard: Don't show if encounterID is nil (can happen with afterRolls mode edge cases)
    if not encounterID then
        encounterID = 0
        encounterName = encounterName or "Unknown Boss"
    end

    LoothingPopups:Show("LOOTHING_CONFIRM_START_SESSION", {
        boss = encounterName or "Unknown Boss",
        onAccept = function()
            self:StartSession(encounterID, encounterName)
        end,
    })
end

--- Handle boss kill
function LoothingSessionMixin:OnBossKill(encounterID, encounterName)
    -- Same as encounter end with success
end

--- Handle loot received
function LoothingSessionMixin:OnLootReceived(encounterID, itemID, itemLink, quantity, playerName, className)
    local mode = Loothing.Settings:GetSessionTriggerMode()

    -- For afterRolls mode: track when ML receives loot, then prompt
    if mode == "afterRolls" and Loothing.handleLoot then
        -- Use IsSamePlayer if available for robust cross-realm comparison
        local isMyLoot = false
        if LoothingUtils.IsSamePlayer then
            local myName = LoothingUtils.GetPlayerFullName()
            isMyLoot = LoothingUtils.IsSamePlayer(playerName, myName)
        else
            -- Fallback: simple comparison
            local myName = LoothingUtils.GetPlayerFullName()
            isMyLoot = playerName == myName or playerName == UnitName("player")
        end

        if isMyLoot then
            self.receivedLootCount = (self.receivedLootCount or 0) + 1

            -- Reset/start debounce timer
            if self.pendingLootTimer then
                self.pendingLootTimer:Cancel()
            end

            -- After debounce delay with no new loot, prompt for session
            -- (Debounce delay allows all boss loot to be distributed before prompting)
            local debounceDelay = LOOTHING_TIMING and LOOTHING_TIMING.LOOT_DEBOUNCE_DELAY or 2.5
            self.pendingLootTimer = C_Timer.NewTimer(debounceDelay, function()
                -- Guard: Only prompt if we have loot, session is inactive, and we have a valid encounter
                if self.receivedLootCount > 0
                   and self.state == LOOTHING_SESSION_STATE.INACTIVE
                   and self.lastEncounterID then
                    self:ShowSessionPrompt(self.lastEncounterID, self.lastEncounterName)
                end
                self.receivedLootCount = 0
                self.pendingLootTimer = nil
            end)
        end
    end

    -- Active session + ML: add item directly
    if self:IsActive() and self:IsMasterLooter() then
        self:AddItem(itemLink, playerName)
        if LoothingUtils.IsSamePlayer(playerName, LoothingUtils.GetPlayerFullName()) and Loothing.TradeQueue then
            Loothing.TradeQueue:UpdateAndSendRecentTradableItem(itemLink)
        end
        return
    end

    -- Inactive but we're designated to handle loot: buffer the item for replay on session start
    if not self:IsActive() and Loothing.handleLoot then
        local quality = LoothingUtils.GetItemQuality(itemLink)
        if quality and quality >= LOOTHING_MIN_QUALITY then
            if Loothing.ItemFilter and Loothing.ItemFilter:ShouldIgnoreItem(itemLink) then
                Loothing:Debug("Item filtered (buffer):", itemLink)
            else
                table.insert(self.lootBuffer, {
                    itemLink = itemLink,
                    playerName = playerName,
                    encounterID = encounterID,
                    timestamp = time(),
                })
                Loothing:Debug("Buffered loot item:", itemLink, "from", playerName, "encounter", encounterID)
                if LoothingUtils.IsSamePlayer(playerName, LoothingUtils.GetPlayerFullName()) and Loothing.TradeQueue then
                    Loothing.TradeQueue:UpdateAndSendRecentTradableItem(itemLink)
                end
            end
        end
    end
end

--- Handle roster update — detect if ML left the group
function LoothingSessionMixin:OnRosterUpdate()
    if not self:IsActive() then return end
    if not self.masterLooter then return end

    -- Check if ML is still in the group
    local roster = LoothingUtils.GetRaidRoster()
    local mlFound = false
    for _, member in ipairs(roster) do
        if LoothingUtils.IsSamePlayer(member.name, self.masterLooter) then
            mlFound = true
            break
        end
    end

    if not mlFound then
        Loothing:Debug("ML left the group:", self.masterLooter)
        -- Clear global ML reference
        if LoothingUtils.IsSamePlayer(self.masterLooter, Loothing.masterLooter or "") then
            Loothing.masterLooter = nil
        end
        -- End the orphaned session on this client
        self:EndSession()
    end
end

--[[--------------------------------------------------------------------
    Remote Message Handlers
----------------------------------------------------------------------]]

function LoothingSessionMixin:HandleRemoteSessionStart(data)
    -- Don't process our own messages
    if data.masterLooter == LoothingUtils.GetPlayerFullName() then
        return
    end

    -- Ignore if we already have an active session (prevents clobbering)
    if self.state ~= LOOTHING_SESSION_STATE.INACTIVE then
        Loothing:Debug("Received remote session start while active, ignoring")
        return
    end

    -- Clean up any local pending session state (another ML started first)
    if self.pendingLootTimer then
        self.pendingLootTimer:Cancel()
        self.pendingLootTimer = nil
    end
    self.receivedLootCount = 0
    self.pendingEncounterID = nil
    self.pendingEncounterName = nil
    LoothingPopups:Hide("LOOTHING_CONFIRM_START_SESSION")

    -- Prefer authoritative sessionID from ML, fall back to generating locally
    self.sessionID = data.sessionID or LoothingUtils.GenerateGUID()
    self.encounterID = data.encounterID
    self.encounterName = data.encounterName
    self.startTime = time()
    self.masterLooter = data.masterLooter

    self:SetState(LOOTHING_SESSION_STATE.ACTIVE)

    self:TriggerEvent("OnSessionStarted", self.sessionID, data.encounterID, data.encounterName)
    Loothing:Print(string.format(LOOTHING_LOCALE["SESSION_STARTED"], data.encounterName or LOOTHING_LOCALE["MANUAL_SESSION"]))
end

function LoothingSessionMixin:HandleRemoteSessionEnd(data)
    if data.masterLooter == LoothingUtils.GetPlayerFullName() then
        return
    end

    self:EndSession()
end

function LoothingSessionMixin:HandleRemoteItemAdd(data)
    if data.masterLooter == LoothingUtils.GetPlayerFullName() then
        return
    end

    -- Use AddItem with forced flag to bypass checks and register callbacks properly
    self:AddItem(data.itemLink, data.looter, data.guid, true)
end

function LoothingSessionMixin:HandleRemoteVoteRequest(data)
    if data.masterLooter == LoothingUtils.GetPlayerFullName() then
        return
    end

    if not self:IsCurrentSession(data.sessionID) then
        Loothing:Debug("Ignoring vote request for mismatched session", data.sessionID)
        return
    end

    local item = self:GetItemByGUID(data.itemGUID)
    if not item then
        return
    end

    -- Validate timeout is within acceptable bounds (prevents malicious/corrupt values)
    local timeout = data.timeout
    if type(timeout) ~= "number" then
        timeout = LOOTHING_TIMING.DEFAULT_VOTE_TIMEOUT
    elseif timeout == LOOTHING_TIMING.NO_TIMEOUT then
        -- 0 is the no-timeout sentinel — allow it through
    else
        timeout = math.max(LOOTHING_TIMING.MIN_VOTE_TIMEOUT,
                          math.min(LOOTHING_TIMING.MAX_VOTE_TIMEOUT, timeout))
    end

    item:StartVoting(timeout)
    -- Note: We don't set self.currentVotingItem here because multiple items
    -- can be in voting state simultaneously. Use GetVotingItems() instead.

    self:TriggerEvent("OnVotingStarted", item, timeout)

    -- Show RollFrame for everyone (including council)
    self:ShowRollFrameForItem(item)

    -- Show CouncilTable for council, ML, and observers
    local showTable = false
    if Loothing.Council and Loothing.Council:IsPlayerCouncilMember() then
        showTable = true
    elseif self:IsMasterLooter() then
        showTable = true
    elseif Loothing.Observer and (Loothing.Observer:IsPlayerObserver() or Loothing.Observer:IsMLObserver()) then
        showTable = true
    end
    if showTable and Loothing.UI and Loothing.UI.CouncilTable then
        Loothing.UI.CouncilTable:Show()
        if Loothing.UI.CouncilTable.SelectItemTab then
            Loothing.UI.CouncilTable:SelectItemTab(item.guid)
        end
    end
end

function LoothingSessionMixin:HandleRemoteVoteCommit(data)
    -- Only ML receives vote commits
    if not self:IsMasterLooter() then
        return
    end

    if not self:IsCurrentSession(data.sessionID) then
        return
    end

    local item = self:GetItemByGUID(data.itemGUID)
    if not item then
        return
    end

    -- Validate responses payload
    if type(data.responses) ~= "table" or #data.responses == 0 then
        Loothing:Debug("Rejected vote commit with invalid responses from:", tostring(data.voter))
        return
    end

    -- Get voter's class from raid roster
    local roster = LoothingUtils.GetRaidRoster()
    local voterClass = "UNKNOWN"
    for _, member in ipairs(roster) do
        if LoothingUtils.IsSamePlayer(member.name, data.voter) then
            voterClass = member.classFile
            break
        end
    end

    item:AddVote(data.voter, voterClass, data.responses)

    -- Broadcast vote update to Council — batch all candidates into 1-2 messages
    if Loothing.Comm and item.candidateManager then
        local candidates = item.candidateManager:GetAllCandidates()
        for _, candidate in ipairs(candidates) do
            self:UpdateCandidateVoters(item, candidate.playerName)
            Loothing.Comm:QueueForBatch(LOOTHING_MSG_TYPE.VOTE_UPDATE, {
                itemGUID      = item.guid,
                candidateName = candidate.playerName,
                voters        = candidate.voters,
                sessionID     = self.sessionID,
            }, nil, "NORMAL")
        end
        Loothing.Comm:FlushAll()
    end
end

function LoothingSessionMixin:HandleRemoteVoteAward(data)
    if data.masterLooter == LoothingUtils.GetPlayerFullName() then
        return
    end

    if not self:IsCurrentSession(data.sessionID) then
        return
    end

    local item = self:GetItemByGUID(data.itemGUID)
    if not item then
        return
    end

    item:SetWinner(data.winner)
    self:TriggerEvent("OnItemAwarded", item, data.winner)
end

function LoothingSessionMixin:HandleRemoteVoteSkip(data)
    if data.masterLooter == LoothingUtils.GetPlayerFullName() then
        return
    end

    if not self:IsCurrentSession(data.sessionID) then
        return
    end

    local item = self:GetItemByGUID(data.itemGUID)
    if not item then
        return
    end

    item:Skip()
    self:TriggerEvent("OnItemSkipped", item)
end

function LoothingSessionMixin:HandleRemoteVoteCancel(data)
    if data.masterLooter == LoothingUtils.GetPlayerFullName() then
        return
    end

    if not self:IsCurrentSession(data.sessionID) then
        return
    end

    -- If nil item GUID, cancel all voting items
    if not data.itemGUID then
        for _, item in self.items:Enumerate() do
            if item:IsVoting() then
                if item.voteTimer then
                    item.voteTimer:Cancel()
                    item.voteTimer = nil
                end
                item:SetState(LOOTHING_ITEM_STATE.PENDING)
                self:TriggerEvent("OnVotingEnded", item)
            end
        end
        return
    end

    local item = self:GetItemByGUID(data.itemGUID)
    if not item or not item:IsVoting() then
        return
    end

    if item.voteTimer then
        item.voteTimer:Cancel()
        item.voteTimer = nil
    end

    item:SetState(LOOTHING_ITEM_STATE.PENDING)
    self:TriggerEvent("OnVotingEnded", item)
end

function LoothingSessionMixin:HandleRemoteVoteResults(data)
    if data.masterLooter == LoothingUtils.GetPlayerFullName() then
        return
    end

    if not self:IsCurrentSession(data.sessionID) then
        return
    end

    local item = self:GetItemByGUID(data.itemGUID)
    if not item then
        return
    end

    -- Clear timer and set state to tallied
    if item.voteTimer then
        item.voteTimer:Cancel()
        item.voteTimer = nil
    end

    if item:IsVoting() then
        item:EndVoting()
    end

    item.voteResults = data.results
    self:TriggerEvent("OnVotingEnded", item, data.results)

    -- Show results panel to council
    self:ShowResultsPanelForItem(item, data.results)
end

--[[--------------------------------------------------------------------
    Gear Info Management
----------------------------------------------------------------------]]

--- Request gear info from a player
-- @param itemGUID string - Item GUID
-- @param playerName string - Player to request from
function LoothingSessionMixin:RequestPlayerGearInfo(itemGUID, playerName)
    if not self:IsMasterLooter() then
        return
    end

    Loothing.Comm:RequestPlayerInfo(itemGUID, playerName)
end

--- Get equipped item info for a given equip slot
-- @param equipSlot string - Equipment slot (e.g., "INVTYPE_HEAD")
-- @return string|nil, string|nil, number, number - slot1Link, slot2Link, slot1ilvl, slot2ilvl
function LoothingSessionMixin:GetEquippedGearForSlot(equipSlot)
    if not equipSlot then
        return nil, nil, 0, 0
    end

    -- Map equipment slots to inventory slot IDs
    local slotMap = {
        INVTYPE_HEAD = { 1 },
        INVTYPE_NECK = { 2 },
        INVTYPE_SHOULDER = { 3 },
        INVTYPE_BODY = { 4 },
        INVTYPE_CHEST = { 5 },
        INVTYPE_ROBE = { 5 },
        INVTYPE_WAIST = { 6 },
        INVTYPE_LEGS = { 7 },
        INVTYPE_FEET = { 8 },
        INVTYPE_WRIST = { 9 },
        INVTYPE_HAND = { 10 },
        INVTYPE_FINGER = { 11, 12 },
        INVTYPE_TRINKET = { 13, 14 },
        INVTYPE_CLOAK = { 15 },
        INVTYPE_WEAPON = { 16, 17 },
        INVTYPE_2HWEAPON = { 16 },
        INVTYPE_WEAPONMAINHAND = { 16 },
        INVTYPE_WEAPONOFFHAND = { 17 },
        INVTYPE_SHIELD = { 17 },
        INVTYPE_HOLDABLE = { 17 },
        INVTYPE_RANGED = { 16 },
        INVTYPE_RANGEDRIGHT = { 16 },
    }

    local slots = slotMap[equipSlot]
    if not slots then
        return nil, nil, 0, 0
    end

    local slot1Link = GetInventoryItemLink("player", slots[1])
    local slot1ilvl = 0
    if slot1Link then
        local itemLevel = C_Item.GetCurrentItemLevel(ItemLocation:CreateFromEquipmentSlot(slots[1]))
        slot1ilvl = itemLevel or 0
    end

    local slot2Link = nil
    local slot2ilvl = 0
    if slots[2] then
        slot2Link = GetInventoryItemLink("player", slots[2])
        if slot2Link then
            local itemLevel = C_Item.GetCurrentItemLevel(ItemLocation:CreateFromEquipmentSlot(slots[2]))
            slot2ilvl = itemLevel or 0
        end
    end

    return slot1Link, slot2Link, slot1ilvl, slot2ilvl
end

--- Handle player info request (respond with our gear)
function LoothingSessionMixin:HandlePlayerInfoRequest(data)
    local itemGUID = data.itemGUID
    local playerName = data.playerName

    -- Only respond if it's for us
    if not LoothingUtils.IsSamePlayer(playerName, LoothingUtils.GetPlayerFullName()) then
        return
    end

    -- Get the item to determine equip slot
    local item = self:GetItemByGUID(itemGUID)
    if not item or not item.equipSlot then
        return
    end

    -- Get our equipped gear for this slot
    local slot1Link, slot2Link, slot1ilvl, slot2ilvl = self:GetEquippedGearForSlot(item.equipSlot)

    -- Send response to ML
    Loothing.Comm:SendPlayerInfo(itemGUID, slot1Link, slot2Link, slot1ilvl, slot2ilvl, data.requester, self.sessionID)
end

--- Handle player info response (store gear data on vote)
function LoothingSessionMixin:HandlePlayerInfoResponse(data)
    -- Only ML processes these
    if not self:IsMasterLooter() then
        return
    end

    if not self:IsCurrentSession(data.sessionID) then
        return
    end

    local itemGUID = data.itemGUID
    local item = self:GetItemByGUID(itemGUID)
    if not item then
        return
    end

    -- Find the vote for this player
    local vote = item:GetVoteByVoter(data.playerName)
    if vote then
        -- Update vote with gear info (guard: deserialized votes are plain tables without mixin methods)
        if vote.SetGearData then
            vote:SetGearData(data.slot1Link, data.slot2Link, data.slot1ilvl, data.slot2ilvl)
            vote:CalculateIlvlDiff(item.itemLevel)
            Loothing:Debug("Updated gear info for", data.playerName, ":", vote:GetGearInfo())
        else
            vote.gear1Link = data.slot1Link
            vote.gear2Link = data.slot2Link
            vote.gear1ilvl = data.slot1ilvl or 0
            vote.gear2ilvl = data.slot2ilvl or 0
        end
    end

    -- Update candidate gear and broadcast to council
    local candidateManager = item:GetCandidateManager()
    if candidateManager then
        -- Resolve candidate class from raid roster (fallback to vote if roster missing)
        local candidateClass = "UNKNOWN"
        local roster = LoothingUtils.GetRaidRoster()
        for _, member in ipairs(roster) do
            if LoothingUtils.IsSamePlayer(member.name, data.playerName) then
                candidateClass = member.classFile or "UNKNOWN"
                break
            end
        end
        if candidateClass == "UNKNOWN" and vote and vote.voterClass then
            candidateClass = vote.voterClass
        end

        local candidate = candidateManager:GetOrCreateCandidate(data.playerName, candidateClass)
        candidate:SetGearData(data.slot1Link, data.slot2Link, data.slot1ilvl, data.slot2ilvl)
        candidate:CalculateIlvlDiff(item.itemLevel)
        candidateManager:UpdateCandidateGear(candidate.playerName, candidate.gear1Link, candidate.gear2Link, candidate.gear1ilvl, candidate.gear2ilvl, candidate.ilvlDiff)

        if Loothing.Comm then
            Loothing.Comm:BroadcastCandidateUpdate(itemGUID, {
                name = candidate.playerName,
                class = candidate.playerClass,
                response = candidate.response,
                roll = candidate.roll,
                note = candidate.note,
                gear1 = candidate.gear1Link,
                gear2 = candidate.gear2Link,
                ilvl1 = candidate.gear1ilvl,
                ilvl2 = candidate.gear2ilvl,
                itemsWon = candidate.itemsWonThisSession,
            }, self.sessionID)
        end
    end
end

--- Handle incoming player response from raid member
-- @param data table - { sender, itemGUID, response, note, roll, rollMin, rollMax }
function LoothingSessionMixin:HandlePlayerResponse(data)
    -- Only ML processes these
    if not self:IsMasterLooter() then
        return
    end

    if not self:IsCurrentSession(data.sessionID) then
        Loothing:Debug("HandlePlayerResponse: session_mismatch - expected", tostring(self.sessionID), "got", tostring(data.sessionID), "from", tostring(data.playerName))
        local itemGUID = data.itemGUID
        if Loothing.Comm then
            Loothing.Comm:SendPlayerResponseAck(itemGUID, false, data.playerName, self.sessionID)
        end
        return
    end

    local itemGUID = data.itemGUID
    local sender = data.playerName
    local response = data.response
    local note = data.note
    local roll = data.roll
    local rollMin = data.rollMin
    local rollMax = data.rollMax

    -- Get the item
    local item = self:GetItemByGUID(itemGUID)
    local function sendAck(success)
        if Loothing.Comm then
            Loothing.Comm:SendPlayerResponseAck(itemGUID, success, sender, self.sessionID)
        end
    end

    -- Validate session/item state
    if self.state ~= LOOTHING_SESSION_STATE.ACTIVE then
        Loothing:Debug("HandlePlayerResponse: session_not_active - state", tostring(self.state), "from", sender)
        sendAck(false)
        return
    end

    if not item or not item:IsVoting() then
        Loothing:Debug("HandlePlayerResponse: item_not_voting - guid", tostring(itemGUID), "state", item and tostring(item.state) or "nil", "from", sender)
        sendAck(false)
        return
    end

    -- Validate response is a known response value
    if not LOOTHING_RESPONSE_INFO[response] then
        Loothing:Debug("HandlePlayerResponse: invalid_response -", tostring(response), "from", sender)
        sendAck(false)
        return
    end

    -- Get sender's class from roster
    local senderClass = "UNKNOWN"
    local roster = LoothingUtils.GetRaidRoster()
    for _, member in ipairs(roster) do
        if LoothingUtils.IsSamePlayer(member.name, sender) then
            senderClass = member.classFile or "UNKNOWN"
            break
        end
    end

    -- Create or update candidate
    local candidateManager = item:GetCandidateManager()
    if not candidateManager then
        -- Initialize candidate manager if not present
        item.candidateManager = CreateLoothingCandidateManager()
        candidateManager = item.candidateManager
    end

    local candidate = candidateManager:GetOrCreateCandidate(sender, senderClass)
    candidate:SetResponse(response, note)

    if roll and roll > 0 then
        candidate:SetRoll(roll, rollMin or 1, rollMax or 100)
    else
        -- Fallback: generate a silent roll if response arrived without one
        local rollSettings = Loothing.Settings and Loothing.Settings:Get("rollFrame.rollRange")
        local fallbackMin = rollSettings and rollSettings.min or 1
        local fallbackMax = rollSettings and rollSettings.max or 100
        candidate:SetRoll(math.random(fallbackMin, fallbackMax), fallbackMin, fallbackMax)
    end

    -- Update items won count for this player
    local itemsWon = self:GetItemsWonByPlayer(sender)
    candidate:SetItemsWon(itemsWon)

    -- Request the responder's gear so council can see upgrade context
    self:RequestPlayerGearInfo(itemGUID, sender)

    -- Send acknowledgment
    sendAck(true)

    -- Route candidate update through the batcher so concurrent responses from
    -- multiple raiders within 100ms are coalesced into a single BATCH message.
    if Loothing.Comm then
        Loothing.Comm:QueueForBatch(LOOTHING_MSG_TYPE.CANDIDATE_UPDATE, {
            itemGUID      = itemGUID,
            candidateData = {
                name     = candidate.playerName,
                class    = candidate.playerClass,
                response = candidate.response,
                roll     = candidate.roll,
                note     = candidate.note,
                gear1    = candidate.gear1Link,
                gear2    = candidate.gear2Link,
                ilvl1    = candidate.gear1ilvl,
                ilvl2    = candidate.gear2ilvl,
                itemsWon = candidate.itemsWonThisSession,
            },
            sessionID = self.sessionID,
        }, nil, "NORMAL")
        -- NOTE: No FlushAll here — let the 100ms window accumulate concurrent responses.
    end

    -- Trigger event
    self:TriggerEvent("OnCandidateAdded", item, candidate)
end

--- Handle player response acknowledgment (ML -> player)
-- @param data table - { itemGUID, success, masterLooter }
function LoothingSessionMixin:HandlePlayerResponseAck(data)
    if not data or not data.itemGUID then
        return
    end

    self:TriggerEvent("OnPlayerResponseAck", data.itemGUID, data.success, data.masterLooter, data.sessionID)
end

--- Get the number of items a player has won in this session
-- @param playerName string
-- @return number
function LoothingSessionMixin:GetItemsWonByPlayer(playerName)
    local count = 0

    if not playerName or not self.items then
        return count
    end

    local normalizedName = LoothingUtils.NormalizeName(playerName)

    for _, item in self.items:Enumerate() do
        if item.state == LOOTHING_ITEM_STATE.AWARDED then
            local winner = item.winner or item.awardedTo
            if winner then
                local normalizedWinner = LoothingUtils.NormalizeName(winner)
                if normalizedWinner == normalizedName then
                    count = count + 1
                end
            end
        end
    end

    return count
end

--- Handle remote candidate update (Council view)
function LoothingSessionMixin:HandleRemoteCandidateUpdate(data)
    -- Don't process if we are ML (we generated it)
    if self:IsMasterLooter() then return end

    if not self:IsCurrentSession(data.sessionID) then
        return
    end

    local item = self:GetItemByGUID(data.itemGUID)
    if not item then return end

    local cData = data.candidateData
    local candidateManager = item:GetCandidateManager()
    if not candidateManager then
        item.candidateManager = CreateLoothingCandidateManager()
        candidateManager = item.candidateManager
    end

    local candidate = candidateManager:GetOrCreateCandidate(cData.name, cData.class)
    candidate:SetResponse(cData.response, cData.note)
    if cData.roll and cData.roll > 0 then
        candidate:SetRoll(cData.roll, 1, 100) -- Range assumed 1-100 for now
    end
    
    -- Update gear
    if cData.gear1 or cData.gear2 then
        candidate.gear1Link = cData.gear1
        candidate.gear2Link = cData.gear2
        candidate.gear1ilvl = cData.ilvl1
        candidate.gear2ilvl = cData.ilvl2
        
        -- Recalculate ilvl diff if item has ilvl
        if item.itemLevel and item.itemLevel > 0 then
            local avgEquip = 0
            if cData.ilvl1 and cData.ilvl1 > 0 then
                avgEquip = cData.ilvl1
                if cData.ilvl2 and cData.ilvl2 > 0 then
                    avgEquip = (cData.ilvl1 + cData.ilvl2) / 2
                end
            end
            candidate.ilvlDiff = item.itemLevel - avgEquip
        end
    end
    
    candidate:SetItemsWon(cData.itemsWon)

    self:TriggerEvent("OnCandidateUpdated", item, candidate)
end

--- Handle a tracked /roll from RollTracker
-- Applies roll to all voting items where the player is a candidate.
-- Runs on every client (CHAT_MSG_SYSTEM is local). ML also broadcasts for sync.
-- @param playerName string - Normalized player name
-- @param roll number - Roll result
-- @param minRoll number - Min roll range
-- @param maxRoll number - Max roll range
function LoothingSessionMixin:HandleRollTracked(playerName, roll, minRoll, maxRoll)
    -- Check autoAddRolls: MLDB first (authoritative from ML), Settings fallback
    local mldb = Loothing.MLDB and Loothing.MLDB:Get()
    local autoAddRolls
    if mldb then
        autoAddRolls = mldb.autoAddRolls
    end
    if autoAddRolls == nil then
        autoAddRolls = Loothing.Settings:GetAutoAddRolls()
    end
    if not autoAddRolls then return end

    -- Must have an active session
    if not self:IsActive() then return end

    local votingItems = self:GetVotingItems()
    if #votingItems == 0 then return end

    local isML = self:IsMasterLooter()

    for _, item in ipairs(votingItems) do
        local candidateManager = item:GetCandidateManager()
        if candidateManager then
            local updated = candidateManager:UpdateCandidateRoll(playerName, roll, minRoll, maxRoll)
            if updated then
                self:TriggerEvent("OnCandidateUpdated", item, candidateManager:GetCandidate(playerName))

                -- ML broadcasts so council members who missed the chat event stay in sync
                if isML and Loothing.Comm then
                    local candidate = candidateManager:GetCandidate(playerName)
                    Loothing.Comm:BroadcastCandidateUpdate(item.itemGUID, {
                        name = candidate.playerName,
                        class = candidate.playerClass,
                        response = candidate.response,
                        roll = candidate.roll,
                        note = candidate.note,
                        gear1 = candidate.gear1Link,
                        gear2 = candidate.gear2Link,
                        ilvl1 = candidate.gear1ilvl,
                        ilvl2 = candidate.gear2ilvl,
                        itemsWon = candidate.itemsWonThisSession,
                    }, self.sessionID)
                end
            end
        end
    end
end

--- Handle remote vote update (Council view)
function LoothingSessionMixin:HandleRemoteVoteUpdate(data)
    -- Don't process if we are ML
    if self:IsMasterLooter() then return end

    if not self:IsCurrentSession(data.sessionID) then
        return
    end

    local item = self:GetItemByGUID(data.itemGUID)
    if not item then return end

    local candidateName = data.candidateName
    local voters = data.voters
    
    -- Ensure CandidateManager exists
    local candidateManager = item:GetCandidateManager()
    if not candidateManager then
        item.candidateManager = CreateLoothingCandidateManager()
        candidateManager = item.candidateManager
    end
    
    -- Use GetOrCreateCandidate to handle concurrent updates
    -- Fallback to UNKNOWN class, will be updated when CandidateUpdate arrives
    local candidate = candidateManager:GetOrCreateCandidate(candidateName, "UNKNOWN")
    
    if candidate then
        candidate.voters = voters
        candidate.councilVotes = #voters
        self:TriggerEvent("OnCandidateUpdated", item, candidate)
    end
end

--[[--------------------------------------------------------------------
    Sync Support
----------------------------------------------------------------------]]

--- Sync session from remote data
-- @param data table
function LoothingSessionMixin:SyncFromData(data)
    self.sessionID = data.sessionID
    self.encounterID = data.encounterID
    self.encounterName = data.encounterName
    self.startTime = time()
    self.masterLooter = data.masterLooter
    self:SetState(data.state)

    -- Sync items if provided
    if data.items then
        -- Clear existing items to avoid duplicates/stale state
        self.items:Flush()

        for _, itemData in ipairs(data.items) do
            -- Use AddItem with force=true to bypass checks
            local item = self:AddItem(itemData.itemLink, itemData.looter, itemData.guid, true)
            if item then
                if itemData.state then
                    item:SetState(itemData.state)
                end

                -- Restore candidates if included in sync data
                if itemData.candidates and #itemData.candidates > 0 then
                    if not item.candidateManager then
                        item.candidateManager = CreateLoothingCandidateManager()
                    end
                    local cm = item.candidateManager
                    for _, cData in ipairs(itemData.candidates) do
                        local candidate = cm:GetOrCreateCandidate(cData.name, cData.class)
                        if candidate then
                            if cData.response then
                                candidate:SetResponse(cData.response, cData.note)
                            end
                            if cData.roll and cData.roll > 0 then
                                candidate:SetRoll(cData.roll, 1, 100)
                            end
                            if cData.gear1 or cData.gear2 then
                                candidate:SetGearData(cData.gear1, cData.gear2, cData.ilvl1, cData.ilvl2)
                            end
                            if cData.itemsWon then
                                candidate:SetItemsWon(cData.itemsWon)
                            end
                            if cData.voters then
                                candidate.voters = cData.voters
                                candidate.councilVotes = #cData.voters
                            end
                        end
                    end
                end
            end
        end
    end

    self:TriggerEvent("OnSessionStarted", self.sessionID, data.encounterID, data.encounterName)
end
