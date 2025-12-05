--[[--------------------------------------------------------------------
    Loothing - Loot Council Addon for WoW 12.0+
    Session - Loot session management
----------------------------------------------------------------------]]

local Loolib = LibStub("Loolib")

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

    -- Register for communication events
    self:RegisterCommEvents()
end

--- Register for communication events
function LoothingSessionMixin:RegisterCommEvents()
    if not Loothing.Comm then return end

    Loothing.Comm:RegisterCallback("OnSessionStart", function(data)
        self:HandleRemoteSessionStart(data)
    end, self)

    Loothing.Comm:RegisterCallback("OnSessionEnd", function(data)
        self:HandleRemoteSessionEnd(data)
    end, self)

    Loothing.Comm:RegisterCallback("OnItemAdd", function(data)
        self:HandleRemoteItemAdd(data)
    end, self)

    Loothing.Comm:RegisterCallback("OnVoteRequest", function(data)
        self:HandleRemoteVoteRequest(data)
    end, self)

    Loothing.Comm:RegisterCallback("OnVoteCommit", function(data)
        self:HandleRemoteVoteCommit(data)
    end, self)

    Loothing.Comm:RegisterCallback("OnVoteAward", function(data)
        self:HandleRemoteVoteAward(data)
    end, self)

    Loothing.Comm:RegisterCallback("OnVoteSkip", function(data)
        self:HandleRemoteVoteSkip(data)
    end, self)

    Loothing.Comm:RegisterCallback("OnPlayerInfoRequest", function(data)
        self:HandlePlayerInfoRequest(data)
    end, self)

    Loothing.Comm:RegisterCallback("OnPlayerInfoResponse", function(data)
        self:HandlePlayerInfoResponse(data)
    end, self)
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

    if not LoothingUtils.IsRaidLeaderOrAssistant() then
        Loothing:Debug("Not raid leader/assistant")
        return false
    end

    self.sessionID = LoothingUtils.GenerateGUID()
    self.encounterID = encounterID
    self.encounterName = encounterName
    self.startTime = time()
    self.masterLooter = LoothingUtils.GetPlayerFullName()

    self:SetState(LOOTHING_SESSION_STATE.ACTIVE)

    -- Broadcast to raid
    Loothing.Comm:BroadcastSessionStart(encounterID, encounterName)

    -- Also broadcast council roster
    if Loothing.Council then
        local members = Loothing.Council:GetAllMembers()
        Loothing.Comm:BroadcastCouncilRoster(members)
    end

    self:TriggerEvent("OnSessionStarted", self.sessionID, encounterID, encounterName)
    Loothing:Print(string.format(LOOTHING_LOCALE["SESSION_STARTED"], encounterName))

    return true
end

--- End the current session
-- @return boolean
function LoothingSessionMixin:EndSession()
    if self.state == LOOTHING_SESSION_STATE.INACTIVE then
        return false
    end

    -- Cancel any active voting
    if self.currentVotingItem then
        self:CancelVoting()
    end

    local sessionID = self.sessionID

    -- Clear session data
    self.sessionID = nil
    self.encounterID = nil
    self.encounterName = nil
    self.startTime = nil
    self.masterLooter = nil
    self.items:Flush()

    self:SetState(LOOTHING_SESSION_STATE.INACTIVE)

    -- Broadcast to raid
    if LoothingUtils.IsRaidLeaderOrAssistant() then
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
    return self.masterLooter == LoothingUtils.GetPlayerFullName()
end

--[[--------------------------------------------------------------------
    Item Management
----------------------------------------------------------------------]]

--- Add an item to the session
-- @param itemLink string
-- @param looter string
-- @return table|nil - The item, or nil if failed
function LoothingSessionMixin:AddItem(itemLink, looter)
    if self.state == LOOTHING_SESSION_STATE.INACTIVE then
        return nil
    end

    -- Check quality threshold
    local quality = LoothingUtils.GetItemQuality(itemLink)
    if quality < LOOTHING_MIN_QUALITY then
        Loothing:Debug("Item below quality threshold:", itemLink)
        return nil
    end

    -- Create item
    local item = CreateLoothingItem(itemLink, looter, self.encounterID)

    -- Listen for state changes
    item:RegisterCallback("OnStateChanged", function(newState, oldState)
        self:TriggerEvent("OnItemStateChanged", item, newState, oldState)
    end, self)

    -- Add to collection
    self.items:Insert(item)

    -- Broadcast to raid if we're ML
    if self:IsMasterLooter() then
        Loothing.Comm:BroadcastItemAdd(itemLink, item.guid, looter)
    end

    self:TriggerEvent("OnItemAdded", item)
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
-- @return boolean
function LoothingSessionMixin:StartVoting(guid, timeout)
    if not self:IsMasterLooter() then
        Loothing:Debug("Not master looter, cannot start voting")
        return false
    end

    if self.currentVotingItem then
        Loothing:Debug("Already voting on an item")
        return false
    end

    local item = self:GetItemByGUID(guid)
    if not item or not item:IsPending() then
        Loothing:Debug("Item not found or not pending")
        return false
    end

    timeout = timeout or Loothing.Settings:GetVotingTimeout()

    if not item:StartVoting(timeout) then
        return false
    end

    self.currentVotingItem = item

    -- Broadcast vote request
    Loothing.Comm:BroadcastVoteRequest(guid, timeout)

    -- Request gear info from all council members
    if Loothing.Council then
        local members = Loothing.Council:GetAllMembers()
        for _, member in ipairs(members) do
            self:RequestPlayerGearInfo(guid, member)
        end
    end

    -- Start timeout timer
    self.voteTimer = C_Timer.NewTimer(timeout, function()
        self:OnVoteTimeout()
    end)

    self:TriggerEvent("OnVotingStarted", item, timeout)
    return true
end

--- Cancel current voting
function LoothingSessionMixin:CancelVoting()
    if not self.currentVotingItem then
        return false
    end

    if self.voteTimer then
        self.voteTimer:Cancel()
        self.voteTimer = nil
    end

    self.currentVotingItem:SetState(LOOTHING_ITEM_STATE.PENDING)
    self.currentVotingItem = nil

    return true
end

--- End voting and tally results
-- @return table|nil - Tally results
function LoothingSessionMixin:EndVoting()
    if not self.currentVotingItem then
        return nil
    end

    if self.voteTimer then
        self.voteTimer:Cancel()
        self.voteTimer = nil
    end

    self.currentVotingItem:EndVoting()

    -- Tally votes
    local results = nil
    if Loothing.VotingEngine then
        results = Loothing.VotingEngine:Tally(self.currentVotingItem:GetVotes())
    end

    local item = self.currentVotingItem
    self.currentVotingItem = nil

    self:TriggerEvent("OnVotingEnded", item, results)
    return results
end

--- Handle vote timeout
function LoothingSessionMixin:OnVoteTimeout()
    Loothing:Debug("Vote timeout")
    self:EndVoting()
end

--- Get current voting item
-- @return table|nil
function LoothingSessionMixin:GetCurrentVotingItem()
    return self.currentVotingItem
end

--- Submit a vote for the current item
-- @param responses table - Ranked responses
-- @return boolean
function LoothingSessionMixin:SubmitVote(responses)
    if not self.currentVotingItem then
        return false
    end

    -- Get our class
    local _, class = UnitClass("player")

    -- Add vote locally
    local voter = LoothingUtils.GetPlayerFullName()
    self.currentVotingItem:AddVote(voter, class, responses)

    -- Send to ML
    if not self:IsMasterLooter() then
        Loothing.Comm:SendVoteCommit(
            self.currentVotingItem.guid,
            responses,
            self.masterLooter
        )
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
-- @return boolean
function LoothingSessionMixin:AwardItem(guid, winner, response)
    if not self:IsMasterLooter() then
        return false
    end

    local item = self:GetItemByGUID(guid)
    if not item then
        return false
    end

    item:SetWinner(winner, response)

    -- Broadcast
    Loothing.Comm:BroadcastVoteAward(guid, winner)

    -- Add to history
    if Loothing.History then
        Loothing.History:AddEntry({
            itemLink = item.itemLink,
            winner = winner,
            winnerResponse = response,
            encounterID = self.encounterID,
            encounterName = self.encounterName,
            votes = item:GetVotes():GetSize(),
            timestamp = time(),
        })
    end

    self:TriggerEvent("OnItemAwarded", item, winner, response)

    -- Announce if enabled
    if Loothing.Settings:GetAnnounceAwards() then
        local channel = Loothing.Settings:GetAnnounceChannel()
        local shortName = LoothingUtils.GetShortName(winner)
        local message = string.format(LOOTHING_LOCALE["ITEM_AWARDED"], item.itemLink, shortName)
        SendChatMessage(message, channel)
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

    item:Skip()

    -- Broadcast
    Loothing.Comm:BroadcastVoteSkip(guid)

    self:TriggerEvent("OnItemSkipped", item)
    return true
end

--[[--------------------------------------------------------------------
    Event Handlers (WoW Events)
----------------------------------------------------------------------]]

--- Handle encounter start
function LoothingSessionMixin:OnEncounterStart(encounterID, encounterName, difficultyID, groupSize)
    -- Nothing automatic on encounter start
end

--- Handle encounter end
function LoothingSessionMixin:OnEncounterEnd(encounterID, encounterName, difficultyID, groupSize, success)
    -- Auto-start session if enabled and we killed the boss
    if success == 1 and Loothing.Settings:GetAutoStartSession() then
        if LoothingUtils.IsRaidLeaderOrAssistant() then
            if self.state == LOOTHING_SESSION_STATE.INACTIVE then
                self:StartSession(encounterID, encounterName)
            end
        end
    end
end

--- Handle boss kill
function LoothingSessionMixin:OnBossKill(encounterID, encounterName)
    -- Same as encounter end with success
end

--- Handle loot received
function LoothingSessionMixin:OnLootReceived(encounterID, itemID, itemLink, quantity, playerName, className)
    -- Only add items if we're ML and session is active
    if not self:IsActive() then
        return
    end

    if not self:IsMasterLooter() then
        return
    end

    -- Check for auto-pass
    if LoothingAutoPass and LoothingAutoPass:ShouldAutoPass(itemLink) then
        local reason = LoothingAutoPass:GetAutoPassReason(itemLink)
        Loothing:Debug("Auto-passing:", itemLink, "-", reason)
        return
    end

    -- Add the item
    self:AddItem(itemLink, playerName)
end

--- Handle roster update
function LoothingSessionMixin:OnRosterUpdate()
    -- Could check if ML left, etc.
end

--[[--------------------------------------------------------------------
    Remote Message Handlers
----------------------------------------------------------------------]]

function LoothingSessionMixin:HandleRemoteSessionStart(data)
    -- Don't process our own messages
    if data.masterLooter == LoothingUtils.GetPlayerFullName() then
        return
    end

    self.sessionID = LoothingUtils.GenerateGUID()
    self.encounterID = data.encounterID
    self.encounterName = data.encounterName
    self.startTime = time()
    self.masterLooter = data.masterLooter

    self:SetState(LOOTHING_SESSION_STATE.ACTIVE)

    self:TriggerEvent("OnSessionStarted", self.sessionID, data.encounterID, data.encounterName)
    Loothing:Print(string.format(LOOTHING_LOCALE["SESSION_STARTED"], data.encounterName))
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

    -- Create item with the provided GUID
    local item = CreateLoothingItem(data.itemLink, data.looter, self.encounterID)
    item.guid = data.guid  -- Use the ML's GUID

    self.items:Insert(item)
    self:TriggerEvent("OnItemAdded", item)
end

function LoothingSessionMixin:HandleRemoteVoteRequest(data)
    if data.masterLooter == LoothingUtils.GetPlayerFullName() then
        return
    end

    local item = self:GetItemByGUID(data.itemGUID)
    if not item then
        return
    end

    item:StartVoting(data.timeout)
    self.currentVotingItem = item

    self:TriggerEvent("OnVotingStarted", item, data.timeout)
end

function LoothingSessionMixin:HandleRemoteVoteCommit(data)
    -- Only ML receives vote commits
    if not self:IsMasterLooter() then
        return
    end

    local item = self:GetItemByGUID(data.itemGUID)
    if not item then
        return
    end

    -- Get voter's class from raid roster
    local roster = LoothingUtils.GetRaidRoster()
    local voterClass = "UNKNOWN"
    for _, member in ipairs(roster) do
        if member.name == data.voter then
            voterClass = member.classFile
            break
        end
    end

    item:AddVote(data.voter, voterClass, data.responses)
end

function LoothingSessionMixin:HandleRemoteVoteAward(data)
    if data.masterLooter == LoothingUtils.GetPlayerFullName() then
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

    local item = self:GetItemByGUID(data.itemGUID)
    if not item then
        return
    end

    item:Skip()
    self:TriggerEvent("OnItemSkipped", item)
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
    Loothing.Comm:SendPlayerInfo(itemGUID, slot1Link, slot2Link, slot1ilvl, slot2ilvl, data.requester)
end

--- Handle player info response (store gear data on vote)
function LoothingSessionMixin:HandlePlayerInfoResponse(data)
    -- Only ML processes these
    if not self:IsMasterLooter() then
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
        -- Update vote with gear info
        vote:SetGearData(data.slot1Link, data.slot2Link, data.slot1ilvl, data.slot2ilvl)
        vote:CalculateIlvlDiff(item.itemLevel)

        Loothing:Debug("Updated gear info for", data.playerName, ":", vote:GetGearInfo())
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

    self:TriggerEvent("OnSessionStarted", self.sessionID, data.encounterID, data.encounterName)
end
