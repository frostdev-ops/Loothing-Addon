--[[--------------------------------------------------------------------
    Loothing - Loot Council Addon for WoW 12.0+
    Session - Loot session management

    Table of Contents:
      SessionMixin ................. ~27
      Session Lifecycle ............ ~311
      State Management ............. ~482
      Item Management .............. ~551
      Voting Management ............ ~692
      Vote Casting ................. ~1030
      Award/Skip ................... ~1210
      Event Handlers ............... ~1416
      Encounter Scope .............. ~1432
      OnEncounterEnd ............... ~1478
      Remote Message Handlers ...... ~1659
      Gear Info Management ......... ~1975
      Player Results & Updates ..... ~2280
      Sync Support ................. ~2440
----------------------------------------------------------------------]]

local _, ns = ...
local Loolib = LibStub("Loolib")
local Loothing = ns.Addon
local Utils = ns.Utils

--- Resolved minimum-quality threshold (Loothing.MinQuality is the
--- legacy hardcoded fallback; the user-configurable value lives in
--- Settings:GetLootFilterMinQuality()).
local function GetMinQuality()
    if Loothing.Settings and Loothing.Settings.GetLootFilterMinQuality then
        return Loothing.Settings:GetLootFilterMinQuality()
    end
    return Loothing.MinQuality or 4
end

--- Check if an item is blocked by the user-configurable class filter.
--- Delegates to Loothing.ItemFilter:IsClassBlocked, which reads the
--- loot.filter.classes.* settings (seeded from the old hardcoded
--- BLACKLISTED_ITEM_CLASSES table by SchemaMigration v4). When
--- ItemFilter is missing (broken load), fall back to the seed defaults
--- exposed by SettingsLootFilter so consumables / recipes / quest
--- items can't silently leak into sessions.
local function IsItemClassBlocked(itemLink)
    if Loothing.ItemFilter and Loothing.ItemFilter.IsClassBlocked then
        return Loothing.ItemFilter:IsClassBlocked(itemLink) and true or false
    end
    -- Fail-closed fallback — mirrors ItemFilter:IsClassBlocked's own
    -- fallback chain when Loothing.Settings is unavailable.
    if not itemLink then return false end
    local _, _, _, _, _, classID, subclassID = C_Item.GetItemInfoInstant(itemLink)
    if not classID then return false end
    local def = ns.LootFilterDefaults and ns.LootFilterDefaults.classes
    if not def then return false end
    local entry = def[classID]
    if not entry then return false end
    if entry.all == true then return true end
    if subclassID and entry[subclassID] == true then return true end
    return false
end

--- Check if an item is Bind on Equip (not soulbound raid loot).
-- BoE items are excluded from loot council unless explicitly enabled.
-- @param itemLink string
-- @return boolean - true if the item is BoE
local function IsItemBoE(itemLink)
    if not itemLink then return false end
    local bindType = select(14, C_Item.GetItemInfo(itemLink))
    return bindType == 2  -- Enum.ItemBind.OnEquip
end

-- Unified loot-detection trace. Gated on Loothing.debug; all sites use
-- the shared "LootDetect:" prefix so users can grep a single boss-kill
-- trace to pinpoint which filter dropped each item.
local function TraceLoot(reason, itemLink, extra)
    if not Loothing.debug then return end
    Loothing:Debug("LootDetect:", reason, itemLink or "", extra or "")
end

local function L(key, fallback)
    local locale = Loothing.Locale or {}
    return locale[key] or fallback or key
end

local function GetPopups()
    return ns.Popups
end

local function IsTestModeEnabled()
    local TestMode = ns.TestMode
    return (Loothing.TestMode and Loothing.TestMode:IsActive())
        or (TestMode and TestMode:IsEnabled())
end

local function NormalizeEncounterID(id)
    local n = tonumber(id)
    if n == nil or n == 0 then return 0 end
    return n
end

local function SameEncounterID(a, b)
    return NormalizeEncounterID(a) == NormalizeEncounterID(b)
end

local function IsCreationSignal(data)
    return data and (data.source == "roll_won" or data.forceCreate == true)
end

local function SameItemIdentity(entry, itemID, itemLink)
    if not entry then return false end
    local entryItemID = entry.itemID
    if not entryItemID and entry.itemLink and C_Item and C_Item.GetItemInfoInstant then
        entryItemID = C_Item.GetItemInfoInstant(entry.itemLink)
    end
    if itemID and entryItemID then
        return tonumber(entryItemID) == tonumber(itemID)
    end
    return entry.itemLink == itemLink
end

local function GetContainerItemStackCount(bag, slot)
    if not C_Container or not C_Container.GetContainerItemInfo then
        return 1
    end
    local info = C_Container.GetContainerItemInfo(bag, slot)
    if type(info) == "table" then
        local count = tonumber(info.stackCount) or 1
        if count > 0 then
            return count
        end
    end
    return 1
end

local function CountRepresentedTradeableCopies(session, itemID, playerName, encounterID)
    if not session or not itemID or not playerName then return 0 end

    local count = 0
    if type(session.lootBuffer) == "table" then
        for _, entry in ipairs(session.lootBuffer) do
            if SameItemIdentity(entry, itemID, nil)
                and entry.playerName
                and Utils.IsSamePlayer(entry.playerName, playerName)
                and (encounterID == nil
                    or SameEncounterID(entry.encounterID, encounterID)) then
                count = count + 1
            end
        end
    end

    if session.IsActive and session:IsActive() and session.items and session.items.Enumerate then
        for _, item in session.items:Enumerate() do
            if item.itemID and tonumber(item.itemID) == tonumber(itemID)
                and item.looter
                and Utils.IsSamePlayer(item.looter, playerName)
                and (encounterID == nil
                    or session.encounterID == nil
                    or SameEncounterID(session.encounterID, encounterID)) then
                count = count + 1
            end
        end
    end

    return count
end

local function IsVotingEligibleMember(name)
    if not name or not Loothing.Council then return false end
    if Loothing.Council.GetVotingEligibleMembers then
        local members = Loothing.Council:GetVotingEligibleMembers()
        for _, member in ipairs(members or {}) do
            if Utils.IsSamePlayer(member, name) then
                return true
            end
        end
        return false
    end
    return Loothing.Council:IsMember(name)
end

--[[--------------------------------------------------------------------
    SessionMixin
----------------------------------------------------------------------]]

local SessionMixin = Loolib.CreateFromMixins(Loolib.CallbackRegistryMixin)
ns.SessionMixin = SessionMixin

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
    "OnItemTradabilityChanged",
    "OnVoteReceived",
    "OnLootBufferChanged",  -- LootPickerFrame subscribes to re-render rows when bag-scan adds late items
}

--- Initialize the session manager
function SessionMixin:Init()
    Loolib.CallbackRegistryMixin.OnLoad(self)
    self:GenerateCallbackEvents(SESSION_EVENTS)

    -- Session state
    self.sessionID = nil
    self.encounterID = nil
    self.encounterName = nil
    self.startTime = nil
    self.state = Loothing.SessionState.INACTIVE
    self.masterLooter = nil

    -- Items (DataProvider)
    local Data = Loolib.Data
    self.items = Data.CreateDataProvider()

    -- Current voting item
    self.currentVotingItem = nil
    self.voteTimer = nil

    -- Session trigger state
    self.lastEligibleEncounter = nil   -- { id, name } — cached for afterLoot / manual
    self.pendingLootTimer = nil
    self.pendingBufferedPrompt = nil
    self.receivedLootCount = 0
    self.lootBuffer = {}  -- Pre-session loot buffer (items arrive before session starts)

    -- Post-encounter bag scanner (RCLC-style distributed item collection)
    self.bagScanTimer = nil
    self.bagScanEncounterID = nil
    self.bagScanEncounterName = nil
    self.bagScanSnapshot = {}
    self.reportedTradeableItems = {}  -- { [itemID] = reportedCount } dedup (was itemLink-keyed pre-2.0.27)
    self.preEncounterBagSnapshot = {} -- { [itemID] = count } taken at ENCOUNTER_START (was itemLink-keyed pre-2.0.27)

    -- Legacy aliases (kept for any external reads)
    self.lastEncounterID = nil
    self.lastEncounterName = nil

    -- Register for communication events
    self:RegisterCommEvents()
end

--- Safely show RollFrame for loot response
-- @param item table - The item to display
function SessionMixin:ShowRollFrameForItem(item)
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

--- Show the active voting UI for an item.
-- RollFrame handles raid-member responses; VotePanel handles council voting.
-- @param item table - The item to display
function SessionMixin:ShowVotingUIForItem(item)
    local votingMode = Loothing.Settings and Loothing.Settings:GetVotingMode()

    if votingMode == Loothing.VotingMode.RANKED_CHOICE and Loothing.VotePanel then
        Loothing.VotePanel:SetVotingMode(Loothing.VotingMode.RANKED_CHOICE)
        Loothing.VotePanel:SetItem(item)
        Loothing.VotePanel:Show()
        return
    end

    self:ShowRollFrameForItem(item)
end

--- Compatibility shim for older callers.
-- @param item table - The item to display
function SessionMixin:ShowVotePanelForItem(item)
    self:ShowVotingUIForItem(item)
end

--- Safely show ResultsPanel to council members
-- @param item table - The item that was voted on
-- @param results table - The voting results
function SessionMixin:ShowResultsPanelForItem(item, results)
    if not item then return end

    -- Check if player is a council member, ML, or observer
    local isCouncil = Loothing.Council and Loothing.Council:IsPlayerCouncilMember()
    local isML = Loothing.HasMasterLooterVisibility and Loothing:HasMasterLooterVisibility() or false
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
function SessionMixin:RegisterCommEvents()
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

    Loothing.Comm:RegisterCallback("OnItemRemove", function(_, data)
        self:HandleRemoteItemRemove(data)
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

--- Handle tradability status for a looted item.
-- RCLC-style: when a raid member loots a tradeable item, they report it here.
-- ML uses this to add items to the session (primary item collection path).
-- @param data table - { itemLink, timeRemaining, playerName, guid, itemID }
function SessionMixin:HandleTradable(data)
    if not data or not data.itemLink then return end

    local itemLink = data.itemLink
    local playerName = data.playerName
    local isML = self:IsMasterLooter() or (Loothing.handleLoot and Loothing.isMasterLooter)

    -- Try to match an existing item first (update tradability). Identity
    -- checks are in increasing-cost order: GUID (cheapest, most specific)
    -- → itemID+looter → raw link equality fallback. The raw-link fallback
    -- is unreliable for group-loot wins because bonusIDs drift between
    -- the ENCOUNTER_LOOT_RECEIVED / LOOT_ITEM_ROLL_WON payload and the
    -- bag-slot's canonicalized link, so we derive itemID from the link
    -- if the caller didn't pass one and prefer that over link equality.
    local itemID = data.itemID
    if not itemID and itemLink then
        itemID = C_Item and C_Item.GetItemInfoInstant
            and C_Item.GetItemInfoInstant(itemLink)
            or nil
    end
    local isCreation = IsCreationSignal(data)

    if data.source == "bag_scan" and data.forceCreate ~= true
        and type(self.lootBuffer) == "table" then
        local refreshed = false
        local scanEncounterID = data.encounterID
        for _, entry in ipairs(self.lootBuffer) do
            if entry.source == "roll_won"
                and playerName
                and Utils.IsSamePlayer(entry.playerName, playerName)
                and SameItemIdentity(entry, itemID, itemLink)
                and (scanEncounterID == nil
                    or SameEncounterID(entry.encounterID, scanEncounterID)) then
                entry.itemID = entry.itemID or itemID
                entry.tradeTimeRemaining = data.timeRemaining
                refreshed = true
            end
        end
        if refreshed then
            self:TriggerEvent("OnLootBufferChanged", self.lootBuffer)
            TraceLoot("handleT:refreshed-roll-won-buffer", itemLink)
            return
        end
    end

    if self:IsActive() and data.encounterID and self.encounterID
        and not SameEncounterID(data.encounterID, self.encounterID) then
        self:BufferDeferredLoot(data, data.encounterID, data.encounterName)
        return
    end

    if self:IsActive() and isCreation and data.source ~= "roll_won"
        and data.encounterID == nil and self.encounterID ~= nil then
        self:BufferDeferredLoot(data, 0, data.encounterName or "Loot")
        return
    end

    local matched = nil
    if self:IsActive() then
        if data.guid then
            matched = self:GetItemByGUID(data.guid)
        end
        if not matched and itemID and not isCreation then
            for _, item in self.items:Enumerate() do
                if item.itemID == itemID and playerName and Utils.IsSamePlayer(item.looter, playerName) then
                    matched = item
                    break
                end
            end
        end
        if not matched and not isCreation then
            -- Raw-link fallback for legacy callers that don't surface itemID
            -- and items added pre-2.0.27 that lack item.itemID. Kept as last
            -- resort; primary match is via itemID above.
            for _, item in self.items:Enumerate() do
                if item.itemLink == itemLink and (not playerName or Utils.IsSamePlayer(item.looter, playerName)) then
                    matched = item
                    break
                end
            end
        end
    end

    if matched then
        -- Existing item: update tradability status. itemID+looter is coarse
        -- when the same player wins two identical items, so refresh every
        -- matching row instead of only the first one.
        if itemID then
            for _, item in self.items:Enumerate() do
                if item.itemID == itemID and playerName and Utils.IsSamePlayer(item.looter, playerName) then
                    item.isTradable = true
                    item.tradeTimeRemaining = data.timeRemaining
                    self:TriggerEvent("OnItemTradabilityChanged", item)
                end
            end
            return
        end
        matched.isTradable = true
        matched.tradeTimeRemaining = data.timeRemaining
        self:TriggerEvent("OnItemTradabilityChanged", matched)
        return
    end

    -- No matching item — ML adds it to the session (distributed item collection)
    if not isML then
        TraceLoot("handleT:not-ml", itemLink,
            "masterLooter=" .. tostring(self.masterLooter))
        return
    end

    -- Filter gates (quality + class block) apply in EVERY mode EXCEPT
    -- `prompt`. In prompt mode the Loot Picker is the ML's chance to
    -- override filters per-kill, so the buffer captures everything and
    -- the picker's checkbox state decides what reaches the session.
    -- `auto` and `manual` both apply filters: auto needs them because
    -- there's no UI gate, and manual feeds the SessionPanel which has no
    -- "show filtered" toggle. Defaulting to `auto` (most restrictive)
    -- when Settings is missing keeps a broken Settings module from
    -- silently disabling filtering.
    local triggerAction = (Loothing.Settings and Loothing.Settings:GetSessionTriggerAction())
        or "auto"
    local enforceFilters = (triggerAction ~= "prompt")

    if enforceFilters then
        local minQ = GetMinQuality()
        local quality = Utils.GetItemQuality(itemLink)
        if minQ > 0 and (not quality or quality < minQ) then
            TraceLoot("handleT:quality-low", itemLink,
                "got=" .. tostring(quality) .. " min=" .. tostring(minQ))
            return
        end

        if IsItemClassBlocked(itemLink) then
            TraceLoot("handleT:class-blocked", itemLink)
            return
        end

        -- BoE check (skip unless setting enables BoE collection)
        local boe = IsItemBoE(itemLink)
        if boe and not (Loothing.Settings and Loothing.Settings:Get("ml.autoAddBoEs", false)) then
            TraceLoot("handleT:boe-excluded", itemLink)
            return
        end

        -- User ignore list
        if Loothing.ItemFilter and Loothing.ItemFilter:ShouldIgnoreItem(itemLink) then
            TraceLoot("handleT:in-ignore-list", itemLink)
            return
        end
    end

    if self:IsActive() then
        -- Active session: add item and broadcast
        local forceAdd = data.force == true or data.source == "roll_won" or data.forceCreate == true
        local item = self:AddItem(itemLink, playerName, nil, forceAdd or nil, true)
        if not item then
            TraceLoot("handleT:add-returned-nil", itemLink,
                "looter=" .. tostring(playerName))
            return
        end
        TraceLoot("handleT:add-ok", itemLink, "looter=" .. tostring(playerName))
        item.isTradable = true
        item.tradeTimeRemaining = data.timeRemaining
        if Loothing.Comm then
            Loothing.Comm:QueueForBatch(Loothing.MsgType.ITEM_ADD, {
                itemLink  = itemLink,
                guid      = item.guid,
                looter    = playerName,
                sessionID = self.sessionID,
            }, nil, "NORMAL")
            -- Debounced flush (coalesces rapid item arrivals)
            if self.lootBatchTimer then
                self.lootBatchTimer:Cancel()
            end
            self.lootBatchTimer = C_Timer.NewTimer(0.5, function()
                self.lootBatchTimer = nil
                if Loothing.Comm then
                    Loothing.Comm:FlushAll()
                end
            end)
        end
    elseif Loothing.handleLoot then
        -- No active session: buffer item and trigger session start
        local bufferEncounterID
        local bufferEncounterName
        if data.source == "roll_won" and data.encounterID == nil and self.lastEligibleEncounter then
            bufferEncounterID = self.lastEligibleEncounter.id
            bufferEncounterName = self.lastEligibleEncounter.name
        elseif isCreation and data.encounterID == nil then
            bufferEncounterID = 0
            bufferEncounterName = data.encounterName or "Loot"
        else
            bufferEncounterID = data.encounterID or self.lastEncounterID
            bufferEncounterName = data.encounterName or self.lastEncounterName
        end

        -- Dedup: OnLootReceived, bag scanner, and TradeQueue can all buffer the same item
        local alreadyBuffered = false
        if not isCreation then
            for _, entry in ipairs(self.lootBuffer) do
                if SameItemIdentity(entry, itemID, itemLink)
                    and playerName
                    and Utils.IsSamePlayer(entry.playerName, playerName)
                    and (SameEncounterID(entry.encounterID, bufferEncounterID)
                        or (data.source == "bag_scan" and entry.source == "roll_won")) then
                    entry.itemID = entry.itemID or itemID
                    entry.tradeTimeRemaining = data.timeRemaining
                    alreadyBuffered = true
                    break
                end
            end
        end
        if alreadyBuffered then
            TraceLoot("handleT:already-buffered", itemLink)
            return
        end

        TraceLoot("handleT:buffered", itemLink, "looter=" .. tostring(playerName))
        table.insert(self.lootBuffer, {
            itemLink = itemLink,
            itemID = itemID,
            playerName = playerName,
            encounterID = bufferEncounterID,
            encounterName = bufferEncounterName,
            source = data.source,
            tradeTimeRemaining = data.timeRemaining,
            timestamp = time(),
        })
        self:TriggerEvent("OnLootBufferChanged", self.lootBuffer)
        -- Trigger session start via debounce (same as afterLoot path)
        self.receivedLootCount = (self.receivedLootCount or 0) + 1
        if self.pendingLootTimer then
            self.pendingLootTimer:Cancel()
        end
        local debounceDelay = Loothing.Timing and Loothing.Timing.LOOT_DEBOUNCE_DELAY or 2.5
        self.pendingLootTimer = C_Timer.NewTimer(debounceDelay, function()
            if self.receivedLootCount > 0
               and self.state == Loothing.SessionState.INACTIVE
               and Loothing.handleLoot then
                local enc = self.lastEligibleEncounter
                if enc then
                    self:ApplyTriggerAction(enc.id, enc.name)
                else
                    -- No cached encounter — auto-start with generic name
                    self:ApplyTriggerAction(self.lastEncounterID or 0, self.lastEncounterName or "Loot")
                end
            end
            self.receivedLootCount = 0
            self.pendingLootTimer = nil
        end)
    end
end

--- Handle non-tradability status for a looted item
-- @param data table - { itemLink, playerName, guid, itemID }
function SessionMixin:HandleNonTradable(data)
    if not self:IsActive() then return end
    if not data or not data.itemLink then return end

    -- Find the matching item: prefer GUID > itemID+looter > itemLink fallback
    local matched = nil
    if data.guid then
        matched = self:GetItemByGUID(data.guid)
    end
    if not matched and data.itemID then
        for _, item in self.items:Enumerate() do
            if item.itemID == data.itemID and data.playerName and Utils.IsSamePlayer(item.looter, data.playerName) then
                matched = item
                break
            end
        end
    end
    if not matched then
        for _, item in self.items:Enumerate() do
            if item.itemLink == data.itemLink and (not data.playerName or Utils.IsSamePlayer(item.looter, data.playerName)) then
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

--- Find buffered loot for an encounter, preferring the newest row.
-- @param excludeEncounterID number|nil - encounter to ignore
-- @return table|nil - { id, name }
function SessionMixin:FindBufferedEncounter(excludeEncounterID)
    if type(self.lootBuffer) ~= "table" then return nil end

    for i = #self.lootBuffer, 1, -1 do
        local entry = self.lootBuffer[i]
        if entry and entry.itemLink
            and (excludeEncounterID == nil or not SameEncounterID(entry.encounterID, excludeEncounterID)) then
            return {
                id = NormalizeEncounterID(entry.encounterID),
                name = entry.encounterName or self.lastEncounterName or "Loot",
            }
        end
    end
    return nil
end

--- Buffer loot without adding it to the currently active session.
-- Used when loot from encounter N+1 arrives while encounter N's council
-- session is still active; mixing those rows into the active session is worse
-- than delaying the next picker until the current session ends.
-- @param data table
-- @param encounterID number|nil
-- @param encounterName string|nil
-- @return boolean - true if a new row was inserted
function SessionMixin:BufferDeferredLoot(data, encounterID, encounterName)
    if not data or not data.itemLink then return false end
    self.lootBuffer = self.lootBuffer or {}

    local itemLink = data.itemLink
    local playerName = data.playerName
    local itemID = data.itemID
    if not itemID and itemLink and C_Item and C_Item.GetItemInfoInstant then
        itemID = C_Item.GetItemInfoInstant(itemLink)
    end
    local bufferEncounterID = encounterID or data.encounterID or self.lastEncounterID or 0
    local bufferEncounterName = encounterName or data.encounterName or self.lastEncounterName or "Loot"

    if not IsCreationSignal(data) then
        for _, entry in ipairs(self.lootBuffer) do
            if SameItemIdentity(entry, itemID, itemLink)
                and playerName
                and Utils.IsSamePlayer(entry.playerName, playerName)
                and SameEncounterID(entry.encounterID, bufferEncounterID) then
                TraceLoot("defer:already-buffered", itemLink,
                    "encounter=" .. tostring(bufferEncounterID))
                return false
            end
        end
    end

    table.insert(self.lootBuffer, {
        itemLink      = itemLink,
        itemID        = itemID,
        playerName    = playerName,
        encounterID   = bufferEncounterID,
        encounterName = bufferEncounterName,
        source        = data.source,
        tradeTimeRemaining = data.timeRemaining,
        timestamp     = time(),
    })

    self.lastEligibleEncounter = { id = bufferEncounterID, name = bufferEncounterName }
    self.lastEncounterID = bufferEncounterID
    self.lastEncounterName = bufferEncounterName
    self.receivedLootCount = (self.receivedLootCount or 0) + 1
    self:TriggerEvent("OnLootBufferChanged", self.lootBuffer)
    TraceLoot("defer:buffered", itemLink, "encounter=" .. tostring(bufferEncounterID))
    return true
end

--- Remove buffered rows for one encounter, preserving other encounters.
-- Nil/0 are treated as the same "encounterless" bucket; clearAll is the only
-- path that wipes unrelated future-encounter rows.
-- @param encounterID number|nil
-- @param clearAll boolean|nil
-- @return number - removed row count
function SessionMixin:ClearLootBufferForEncounter(encounterID, clearAll)
    if type(self.lootBuffer) ~= "table" or #self.lootBuffer == 0 then return 0 end

    local removed = 0
    if clearAll then
        removed = #self.lootBuffer
        wipe(self.lootBuffer)
    else
        for i = #self.lootBuffer, 1, -1 do
            local entry = self.lootBuffer[i]
            if not entry or SameEncounterID(entry.encounterID, encounterID) then
                table.remove(self.lootBuffer, i)
                removed = removed + 1
            end
        end
    end

    if removed > 0 then
        self:TriggerEvent("OnLootBufferChanged", self.lootBuffer)
    end
    return removed
end

--- Apply the configured action for buffered loot once no session is active.
-- @param encounter table|nil - optional { id, name } override
function SessionMixin:PromptForBufferedLoot(encounter)
    if self.state ~= Loothing.SessionState.INACTIVE then return end
    if not Loothing.handleLoot and not IsTestModeEnabled() then return end
    if not self.lootBuffer or #self.lootBuffer == 0 then return end

    local enc = encounter or self.lastEligibleEncounter or self:FindBufferedEncounter()
    if not enc then return end

    local picker = ns.LootPickerFrame
    if picker and picker.IsShown and picker:IsShown() then
        self.pendingBufferedPrompt = enc
        return
    end

    self.lastEligibleEncounter = enc
    self.lastEncounterID = enc.id
    self.lastEncounterName = enc.name
    self.pendingBufferedPrompt = nil
    self.receivedLootCount = #self.lootBuffer
    self:ApplyTriggerAction(enc.id, enc.name)
end

--- Called by LootPickerFrame once the actual frame hide completes.
function SessionMixin:OnLootPickerHidden()
    if not self.pendingBufferedPrompt then return end
    local enc = self.pendingBufferedPrompt
    self.pendingBufferedPrompt = nil
    C_Timer.After(0, function()
        self:PromptForBufferedLoot(enc)
    end)
end

--- Called after the picker successfully starts a session.
-- Clears prompt/debounce state that belonged to the now-consumed picker so
-- delayed callbacks cannot re-open it after the session has already started.
function SessionMixin:OnLootPickerSessionStarted()
    if self.pendingLootTimer then
        self.pendingLootTimer:Cancel()
        self.pendingLootTimer = nil
    end
    self.pendingBufferedPrompt = nil
    self.receivedLootCount = 0
end

--[[--------------------------------------------------------------------
    Session Lifecycle
----------------------------------------------------------------------]]

--- Start a new loot session
-- @param encounterID number
-- @param encounterName string
-- @return boolean
function SessionMixin:StartSession(encounterID, encounterName)
    if self.state ~= Loothing.SessionState.INACTIVE then
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

    local sessionID = Utils.GenerateGUID()
    if Loothing and Loothing.TestMode and Loothing.TestMode.ApplySessionTag then
        sessionID = Loothing.TestMode:ApplySessionTag(sessionID)
    end

    self.sessionID = sessionID
    self.encounterID = encounterID
    self.encounterName = encounterName
    self.startTime = time()
    self.masterLooter = Utils.GetPlayerFullName()

    self:SetState(Loothing.SessionState.ACTIVE)

    -- Start ML heartbeat for session-state auto-recovery on clients
    if Loothing.Heartbeat then
        Loothing.Heartbeat:StartHeartbeat()
    end

    self:TriggerEvent("OnSessionStarted", self.sessionID, encounterID, encounterName)
    Loothing:Print(string.format(Loothing.Locale["SESSION_STARTED"], encounterName or "Manual Session"))

    if Loothing.Settings:Get("frame.autoOpen") and Loothing.MainFrame then
        Loothing.MainFrame:Show()
    end

    -- Replay buffered loot items from before session started.
    -- Entries marked `_picked = true` came from the Loot Picker (the ML
    -- explicitly opted in) and bypass filter gates via force=true.
    local bufferTTL = Loothing.Timing and Loothing.Timing.LOOT_BUFFER_TTL or 60
    local now = time()
    local bufferedItems = {}
    local remainingBuffer = {}
    for _, entry in ipairs(self.lootBuffer) do
        local matchesEncounter = SameEncounterID(entry.encounterID, encounterID)
        if matchesEncounter and (now - entry.timestamp) <= bufferTTL then
            local force = entry._picked == true
            local item = self:AddItem(entry.itemLink, entry.playerName, nil, force, true)
            if item then
                if force then
                    item.isTradable = true
                end
                if entry.tradeTimeRemaining then
                    item.isTradable = true
                    item.tradeTimeRemaining = entry.tradeTimeRemaining
                end
                bufferedItems[#bufferedItems + 1] = {
                    itemLink = entry.itemLink,
                    guid = item.guid,
                    looter = entry.playerName,
                    sessionID = self.sessionID,
                }
            end
        elseif not matchesEncounter then
            remainingBuffer[#remainingBuffer + 1] = entry
        end
    end
    if #self.lootBuffer > 0 then
        wipe(self.lootBuffer)
        for _, entry in ipairs(remainingBuffer) do
            table.insert(self.lootBuffer, entry)
        end
        self:TriggerEvent("OnLootBufferChanged", self.lootBuffer)
    end

    -- Build and send combined SESSION_INIT (single reliable broadcast replaces
    -- separate SESSION_START + MLDB + COUNCIL_ROSTER + N ITEM_ADD broadcasts).
    -- Peers must understand SESSION_INIT for full session setup; upgrade if not.
    local sessionInitData = {
        sessionStart = {
            encounterID = encounterID,
            encounterName = encounterName,
            sessionID = self.sessionID,
        },
    }

    -- Include MLDB if available
    if Loothing.MLDB then
        local mldbSettings = Loothing.MLDB:GatherSettings()
        if mldbSettings then
            local compressed = Loothing.MLDB:CompressForTransmit(mldbSettings)
            if compressed then
                sessionInitData.mldb = { data = compressed }
            end
        end
    end

    -- Include council roster
    if Loothing.Council then
        local members = Loothing.Council:GetAllMembers()
        sessionInitData.councilRoster = { members = members }
    end

    -- Include buffered items
    if #bufferedItems > 0 then
        sessionInitData.items = bufferedItems
    end

    if Loothing.Comm then
        Loothing.Comm:BroadcastSessionInit(sessionInitData)
    end

    return true
end

--- End the current session
-- @return boolean
function SessionMixin:EndSession()
    if self.state == Loothing.SessionState.INACTIVE then
        -- Still cleanup pending state even if inactive
        local Popups = GetPopups()
        if Popups then
            Popups:Hide("LOOTHING_CONFIRM_START_SESSION")
        end

        -- Invalidate broadcast dirty-check caches even on the no-active-session
        -- early-return. A caller reached EndSession in an already-INACTIVE
        -- state typically because the group or ML state changed; the audience
        -- for any future broadcast is probably different, so caches from a
        -- prior ML stint must not outlive this call.
        if Loothing.MLDB and Loothing.MLDB.InvalidateBroadcastCache then
            Loothing.MLDB:InvalidateBroadcastCache()
        end
        if Loothing.Sync and Loothing.Sync.InvalidateBroadcastCaches then
            Loothing.Sync:InvalidateBroadcastCaches()
        end
        if Loothing.Comm and Loothing.Comm.InvalidateSessionStartCache then
            Loothing.Comm:InvalidateSessionStartCache()
        end

        return false
    end

    local endingEncounterID = self.encounterID
    local bufferedAfterSession

    -- Cancel any active voting (handles multiple items)
    local votingItems = self:GetVotingItems()
    if votingItems and #votingItems > 0 then
        self:CancelVoting()  -- Cancels all voting items when called without guid
    end

    -- Cancel afterLoot debounce timer if running
    if self.pendingLootTimer then
        self.pendingLootTimer:Cancel()
        self.pendingLootTimer = nil
    end

    -- Cancel skipSessionFrame auto-start timer if running
    if self.autoStartTimer then
        self.autoStartTimer:Cancel()
        self.autoStartTimer = nil
    end

    -- Cancel consolidated response poll timer
    if self.consolidatedPollTimer then
        self.consolidatedPollTimer:Cancel()
        self.consolidatedPollTimer = nil
    end

    -- Flush any pending loot batch before ending. The comm batch
    -- accumulator itself is drained later via Comm:ResetSessionState so
    -- we do not duplicate that work here — nothing between this point
    -- and the reset enqueues new batched messages.
    if self.lootBatchTimer then
        self.lootBatchTimer:Cancel()
        self.lootBatchTimer = nil
    end

    -- Stop post-encounter bag scanner and wipe its per-encounter state
    -- so a manual/no-encounter session restart does not inherit stale
    -- dedup entries or the previous encounter's bag snapshot. Done here
    -- (not inside StopPostEncounterBagScan) because that function is
    -- also called from StartPostEncounterBagScan after SnapshotBags has
    -- already taken a fresh snapshot, and we must not destroy it.
    if not self.bagScanEncounterID or SameEncounterID(self.bagScanEncounterID, endingEncounterID) then
        self:StopPostEncounterBagScan()
        wipe(self.reportedTradeableItems)
        wipe(self.preEncounterBagSnapshot)
    end

    -- Clear trigger state
    self.receivedLootCount = 0
    self.lastEligibleEncounter = nil
    self.lastEncounterID = nil
    self.lastEncounterName = nil

    -- Hide any pending session prompt dialog or open Loot Picker FIRST,
    -- then wipe the buffer — otherwise the picker's own callback would
    -- render an empty state briefly before its fade-out completes.
    local Popups = GetPopups()
    if Popups then
        Popups:Hide("LOOTHING_CONFIRM_START_SESSION")
    end
    if ns.LootPickerFrame and ns.LootPickerFrame.IsShown
        and ns.LootPickerFrame:IsShown() then
        ns.LootPickerFrame._suppressOnHideCleanup = true
        ns.LootPickerFrame:Hide()
    end
    if self.lootBuffer and #self.lootBuffer > 0 then
        self:ClearLootBufferForEncounter(endingEncounterID)
    end
    bufferedAfterSession = self:FindBufferedEncounter()

    local sessionID = self.sessionID
    local wasML = self:IsMasterLooter()

    -- Clear timer references on all items before flushing (prevents memory leaks)
    for _, item in self.items:Enumerate() do
        if item.voteTimer then
            item.voteTimer:Cancel()
            item.voteTimer = nil
        end

    end

    -- Flush any pending response broadcasts before clearing session
    self:FlushResponseBroadcasts()

    -- Reset module-scoped comm state (batchAccumulator, seenIDs) so pending
    -- 100ms flush timers from this session cannot deliver stale payloads
    -- into the next one. Must run AFTER FlushResponseBroadcasts so the
    -- response batch it flushes is actually sent, and BEFORE sessionID is
    -- nilled out below.
    if Loothing.Comm and Loothing.Comm.ResetSessionState then
        Loothing.Comm:ResetSessionState()
    end

    -- Clear MLDB on non-ML clients ONLY when the ML has stopped handling loot
    -- entirely. As long as `mldb.handleLoot == true`, the ML is still funnelling
    -- group loot through Loothing between sessions (trash drops, encounters
    -- without an active session, etc.) — clearing MLDB here would silence the
    -- group-loot auto-pass funnel (Loot/GroupLootEvents.lua:67-77 reads
    -- mldb.handleLoot to decide whether to PASS for the ML) until the next
    -- SESSION_INIT applies a new MLDB. STOP_HANDLE_LOOT explicitly handles the
    -- "ML stopped handling loot" case and clears MLDB then.
    if Loothing.MLDB and not Loothing.handleLoot then
        local mldb = Loothing.MLDB:Get()
        if not (mldb and mldb.handleLoot == true) then
            Loothing.MLDB:Clear()
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

    -- Clear global ML identity so stale references don't poison new sessions.
    -- Guard with handleLoot: the ML itself keeps its identity when ending a
    -- session it intends to restart (e.g., between encounters).
    if Loothing.masterLooter and not Loothing.handleLoot then
        Loothing.masterLooter = nil
        Loothing.isMasterLooter = false
    end

    self:SetState(Loothing.SessionState.INACTIVE)

    -- Stop ML heartbeat
    if Loothing.Heartbeat then
        Loothing.Heartbeat:StopHeartbeat()
    end

    -- Clear remote council roster so local roster becomes primary again
    if Loothing.Council then
        Loothing.Council:ClearRemoteRoster()
    end

    -- Clear remote observer list. Without this, observer flags from the
    -- previous session bleed into the next and can cause clients to see
    -- (or miss) responses, notes, vote counts and voter identities based
    -- on stale observer permissions.
    if Loothing.Observer and Loothing.Observer.ClearRemoteObserverList then
        Loothing.Observer:ClearRemoteObserverList()
    end

    -- Reset in-flight sync state so a sync that was mid-flight when this
    -- session ended cannot block the next session's sync.
    if Loothing.Sync and Loothing.Sync.ResetSessionState then
        Loothing.Sync:ResetSessionState()
    end

    -- Invalidate broadcast dirty-check caches. The next BroadcastToRaid /
    -- BroadcastCouncilRoster / BroadcastObserverRoster / BroadcastSessionStart
    -- should fire unconditionally — a fresh session is a fresh audience
    -- (new join, ML handoff, encounter transition), even if the payload
    -- happens to be byte-identical to the prior session's last send.
    if Loothing.MLDB and Loothing.MLDB.InvalidateBroadcastCache then
        Loothing.MLDB:InvalidateBroadcastCache()
    end
    if Loothing.Sync and Loothing.Sync.InvalidateBroadcastCaches then
        Loothing.Sync:InvalidateBroadcastCaches()
    end
    if Loothing.Comm and Loothing.Comm.InvalidateSessionStartCache then
        Loothing.Comm:InvalidateSessionStartCache()
    end

    -- Drop any messages queued while restrictions were active. Once the
    -- session that generated them has ended, the queued VOTE_COMMIT /
    -- ITEM_ADD / etc. are no longer meaningful and would otherwise
    -- replay into the next session when restrictions lift.
    if Loothing.Restrictions and Loothing.Restrictions.ClearQueue then
        Loothing.Restrictions:ClearQueue()
    end

    -- Drop any queued announcements (e.g. "Awarded X to Y" queued during
    -- combat) so they do not fire into the next session with stale text.
    if Loothing.Announcer and Loothing.Announcer.announcementQueue then
        wipe(Loothing.Announcer.announcementQueue)
    end

    -- Clear tracked /roll results so session-1 rolls cannot be re-associated
    -- with auto-added items in session 2 (5-min TTL is too long for rapid
    -- back-to-back sessions).
    if Loothing.RollTracker and Loothing.RollTracker.ClearAllRolls then
        Loothing.RollTracker:ClearAllRolls()
    end

    -- Broadcast to raid (only ML should broadcast end)
    if wasML then
        Loothing.Comm:BroadcastSessionEnd(sessionID)
    end

    -- Pass wasML captured *before* self.masterLooter and the global ML state
     -- were cleared above. Listeners that check IsMasterLooter() post-clear will
     -- fall through to IsCanonicalML() → raid-leader fallback, which gives the
     -- wrong answer when the ML is not the raid leader.
    self:TriggerEvent("OnSessionEnded", sessionID, wasML)
    Loothing:Print(Loothing.Locale["SESSION_ENDED"])

    if bufferedAfterSession and self.lootBuffer and #self.lootBuffer > 0 then
        C_Timer.After(0, function()
            self:PromptForBufferedLoot(bufferedAfterSession)
        end)
    end

    if Loothing.Settings:Get("frame.autoClose") and Loothing.MainFrame then
        -- Show trade tab instead of hiding if ML has pending trades
        local hasPendingTrades = Loothing.TradeQueue
            and #Loothing.TradeQueue:GetAllPending() > 0
        if hasPendingTrades then
            Loothing.MainFrame:Show()
            Loothing.MainFrame:SelectTab("trade")
        else
            Loothing.MainFrame:Hide()
        end
    end

    return true
end

--- Close session (no more items, finish voting)
function SessionMixin:CloseSession()
    if self.state ~= Loothing.SessionState.ACTIVE then
        return false
    end

    self:SetState(Loothing.SessionState.CLOSED)
    return true
end

--[[--------------------------------------------------------------------
    State Management
----------------------------------------------------------------------]]

--- Get current state
-- @return number
function SessionMixin:GetState()
    return self.state
end

--- Set state
-- @param state number
function SessionMixin:SetState(state)
    if self.state ~= state then
        local oldState = self.state
        self.state = state
        self:TriggerEvent("OnStateChanged", state, oldState)
    end
end

--- Check if session is active
-- @return boolean
function SessionMixin:IsActive()
    return self.state ~= Loothing.SessionState.INACTIVE
end

--- Get session ID
-- @return string|nil
function SessionMixin:GetSessionID()
    return self.sessionID
end

--- Validate a sessionID against current session
-- @param sessionID string|nil
-- @return boolean
function SessionMixin:IsCurrentSession(sessionID)
    if not sessionID or sessionID == "" then
        return false
    end
    return self.sessionID == sessionID
end

--- Get encounter ID
-- @return number|nil
function SessionMixin:GetEncounterID()
    return self.encounterID
end

--- Get encounter name
-- @return string|nil
function SessionMixin:GetEncounterName()
    return self.encounterName
end

--- Get master looter
-- @return string|nil
function SessionMixin:GetMasterLooter()
    return self.masterLooter
end

--- Check if local player is the master looter.
-- Checks session ML first; falls back to canonical resolution for transient states
-- where session ML hasn't been set yet (e.g. between MLDB apply and SESSION_START).
-- @return boolean
function SessionMixin:IsMasterLooter()
    if self.masterLooter then
        return Utils.IsSamePlayer(self.masterLooter, Utils.GetPlayerFullName())
    end
    return Loothing:IsCanonicalML()
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
function SessionMixin:AddItem(itemLink, looter, guid, force, skipBroadcast)
    if self.state == Loothing.SessionState.INACTIVE then
        TraceLoot("add:state-inactive", itemLink)
        return nil
    end

    if self.state == Loothing.SessionState.CLOSED then
        TraceLoot("add:state-closed", itemLink)
        return nil
    end

    -- Check quality threshold (uses configurable loot.filter.minQuality).
    -- minQ == 0 disables the gate; matches HandleTradable semantics.
    if not force then
        local minQ = GetMinQuality()
        if minQ > 0 then
            local quality = Utils.GetItemQuality(itemLink)
            if not quality or quality < minQ then
                TraceLoot("add:quality-low", itemLink,
                    "got=" .. tostring(quality) .. " min=" .. tostring(minQ))
                return nil
            end
        end
    end

    -- Filter check
    if not force and Loothing.ItemFilter and Loothing.ItemFilter:ShouldIgnoreItem(itemLink) then
        TraceLoot("add:in-ignore-list", itemLink)
        return nil
    end

    -- Skip BoE items unless ml.autoAddBoEs is enabled
    if not force then
        local _, _, _, _, _, _, _, _, _, _, _, _, _, bindType = C_Item.GetItemInfo(itemLink)
        if bindType == 2 and not Loothing.Settings:Get("ml.autoAddBoEs", false) then
            TraceLoot("add:boe-excluded", itemLink, "bindType=" .. tostring(bindType))
            return nil
        end
    end

    -- Skip class-blocked items (consumables, reagents, tradeskill, quest
    -- items, housing decor — defaults are configurable in settings) unless
    -- force is set. Mirrors the HandleTradable pre-filter so bag-scan and
    -- manual-add paths are symmetric.
    if not force and IsItemClassBlocked(itemLink) then
        TraceLoot("add:class-blocked", itemLink)
        return nil
    end

    -- Dedup by GUID
    if guid and self:GetItemByGUID(guid) then
        return self:GetItemByGUID(guid)
    end

    -- Create item
    local item = ns.CreateItem(itemLink, looter, self.encounterID)
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

    -- Broadcast to raid if we're ML (skip if items are batched into SESSION_INIT)
    if self:IsMasterLooter() and not skipBroadcast then
        Loothing.Comm:BroadcastItemAdd(itemLink, item.guid, looter, self.sessionID)
    end

    self:TriggerEvent("OnItemAdded", item)

    -- skipSessionFrame: auto-start voting after items stop arriving
    if self:IsMasterLooter() and Loothing.Settings:Get("ml.skipSessionFrame", true) then
        if self.autoStartTimer then
            self.autoStartTimer:Cancel()
        end
        self.autoStartTimer = C_Timer.NewTimer(2, function()
            self.autoStartTimer = nil
            if self.state == Loothing.SessionState.ACTIVE then
                self:StartVotingOnAllItems()
            end
        end)
    end

    return item
end

--- Remove an item from the session
-- @param guid string
-- @return boolean
function SessionMixin:RemoveItem(guid, skipBroadcast)
    local item = self:GetItemByGUID(guid)
    if not item then
        return false
    end

    -- Cancel vote timer if item is currently being voted on
    if item.voteTimer then
        item.voteTimer:Cancel()
        item.voteTimer = nil
    end

    self.items:Remove(item)
    self:TriggerEvent("OnItemRemoved", item)

    -- Cancel consolidated poll timer if no voting items remain
    if self.consolidatedPollTimer then
        local hasVoting = false
        for _, remaining in self.items:Enumerate() do
            if remaining:IsVoting() then
                hasVoting = true
                break
            end
        end
        if not hasVoting then
            self.consolidatedPollTimer:Cancel()
            self.consolidatedPollTimer = nil
        end
    end

    -- Broadcast to raid if we're ML (unless this was triggered by a remote message)
    if not skipBroadcast and self:IsMasterLooter() and Loothing.Comm then
        Loothing.Comm:BroadcastItemRemove(guid, self.sessionID)
    end

    return true
end

--- Get item by GUID
-- @param guid string
-- @return table|nil
function SessionMixin:GetItemByGUID(guid)
    for _, item in self.items:Enumerate() do
        if item.guid == guid then
            return item
        end
    end
    return nil
end

--- Get all items
-- @return DataProvider
function SessionMixin:GetItems()
    return self.items
end

--- Get pending items
-- @return table
function SessionMixin:GetPendingItems()
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
function SessionMixin:GetItemCount()
    return self.items:GetSize()
end

--- Check if all items in the session are complete (awarded or skipped).
-- @return boolean
function SessionMixin:AreAllItemsComplete()
    if self.items:GetSize() == 0 then return false end
    for _, item in self.items:Enumerate() do
        if not item:IsComplete() then
            return false
        end
    end
    return true
end

--- Auto-end the session if all items have been awarded or skipped.
-- Called after AwardItem/SkipItem. Only the ML triggers this.
function SessionMixin:CheckAutoEndSession()
    if not self:IsMasterLooter() then return end
    if self.state ~= Loothing.SessionState.ACTIVE
        and self.state ~= Loothing.SessionState.CLOSED then
        return
    end
    if not self:AreAllItemsComplete() then return end

    Loothing:Debug("All items complete — auto-ending session")
    self:EndSession()
end

--[[--------------------------------------------------------------------
    Voting Management
----------------------------------------------------------------------]]

--- Start voting on an item
-- @param guid string - Item GUID
-- @param timeout number - Optional timeout
-- @param skipBroadcast boolean - If true, caller is responsible for broadcasting vote request
-- @return boolean
function SessionMixin:StartVoting(guid, timeout, skipBroadcast)
    if not self:IsMasterLooter() then
        Loothing:Debug("Not master looter, cannot start voting")
        return false
    end

    if self.state == Loothing.SessionState.CLOSED then
        Loothing:Debug("Cannot start voting on a closed session")
        return false
    end

    if self.state ~= Loothing.SessionState.ACTIVE then
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

    -- Enrich candidates with wishlist data from desktop exchange
    if item.candidateManager and item.itemID then
        item.candidateManager:EnrichWithWishlistData(item.itemID)
    end

    -- Broadcast vote request for this item
    if not skipBroadcast then
        Loothing.Comm:BroadcastVoteRequest(guid, timeout, self.sessionID)
    end

    -- Gear info: modern clients self-report gear in PLAYER_RESPONSE (eliminates
    -- this round-trip). Legacy clients without gear fields trigger the PIQ fallback
    -- in HandlePlayerResponse when their response arrives without gear data.

    -- Track expected responders for response progress display
    item.expectedResponders = {}
    local roster = Utils.GetRaidRoster()
    for _, member in ipairs(roster) do
        item.expectedResponders[member.name] = true
    end
    item.expectedResponderCount = #roster
    item.responseCount = 0

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

    -- Consolidated response poll: schedule/reset a single session-level poll
    -- timer instead of one per item. Fires once and covers ALL voting items.
    self:ScheduleConsolidatedResponsePoll()

    return true
end

--- Schedule a single consolidated poll for ALL voting items with missing responses.
-- Resets the timer on each new voting item (sliding window from last vote start).
function SessionMixin:ScheduleConsolidatedResponsePoll()
    if not self:IsMasterLooter() then return end

    if self.consolidatedPollTimer then
        self.consolidatedPollTimer:Cancel()
    end

    local pollDelay = Loothing.Timing.RESPONSE_POLL_DELAY or 15
    self.consolidatedPollTimer = C_Timer.NewTimer(pollDelay, function()
        self.consolidatedPollTimer = nil
        self:PollAllMissingResponses()
    end)
end

--- Poll raid for missing responses across ALL voting items (ML-only).
-- Sends a single RESPONSE_POLL message covering all items instead of one per item.
function SessionMixin:PollAllMissingResponses()
    if not self:IsMasterLooter() then return end

    -- Build combined responded set across all voting items
    local missingByPlayer = {} -- { [playerName] = true }
    local votingGUIDs = {}

    for _, item in self.items:Enumerate() do
        if item:IsVoting() then
            votingGUIDs[#votingGUIDs + 1] = item.guid

            local responded = {}
            local cm = item:GetCandidateManager()
            if cm then
                for _, candidate in ipairs(cm:GetAllCandidates()) do
                    if candidate.response then
                        responded[candidate.playerName] = true
                    end
                end
            end

            -- Any roster member missing from this item's responses is "missing"
            local roster = ns.Utils.GetRaidRoster()
            for _, member in ipairs(roster) do
                if not responded[member.name] then
                    missingByPlayer[member.name] = true
                end
            end
        end
    end

    if #votingGUIDs == 0 then return end

    -- Flatten missing set to array
    local missing = {}
    for name in pairs(missingByPlayer) do
        missing[#missing + 1] = name
    end

    if #missing == 0 then return end

    Loothing:Debug("Session: consolidated poll -", #missing, "missing across", #votingGUIDs, "items")
    if Loothing.Comm then
        Loothing.Comm:Send(Loothing.MsgType.RESPONSE_POLL, {
            itemGUID = votingGUIDs[1],  -- Primary item (backwards compat)
            items = votingGUIDs,         -- All voting items
            sessionID = self.sessionID,
            missing = missing,
        }, nil, "NORMAL")
    end
end

--- Start voting on all pending items at once
-- @param timeout number - Optional timeout
-- @return number - Count of items now in voting state
function SessionMixin:StartVotingOnAllItems(timeout)
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

    -- Ensure queued item-add traffic is delivered before direct vote prompts.
    -- Receivers drop vote requests for items they have not seen yet.
    if Loothing.Comm and #pendingItems > 0 then
        Loothing.Comm:FlushAll()
    end

    for _, item in ipairs(pendingItems) do
        -- Vote requests are lifecycle prompts that open response frames. Send
        -- them directly so mixed clients and diagnostics see explicit VR traffic.
        if self:StartVoting(item.guid, timeout, false) then
            count = count + 1
        end
    end

    Loothing:Debug("Started voting on", count, "items")
    return count
end

--- Handle per-item vote timeout
-- @param item table - The item that timed out
function SessionMixin:OnItemVoteTimeout(item)
    if self.state == Loothing.SessionState.INACTIVE then
        return
    end
    if not item or not item:IsVoting() then
        return
    end

    Loothing:Debug("Vote timeout for item:", item.name)

    -- End voting on this item (will broadcast results if ML)
    self:EndVotingForItem(item.guid)

    -- Schedule a VOTE_POLL check so council members whose VOTE_COMMIT was
    -- queued during combat (and replayed after the timer fired) get a second
    -- chance to deliver their vote within the late-accept window.
    if self:IsMasterLooter() and Loothing.Comm and Loothing.Council then
        local pollDelay = Loothing.Timing.VOTE_POLL_DELAY or 5
        C_Timer.After(pollDelay, function()
            if not self:IsMasterLooter() then return end
            local members = Loothing.Council.GetVotingEligibleMembers
                and Loothing.Council:GetVotingEligibleMembers()
                or Loothing.Council:GetAllMembers()
            if not members or #members == 0 then return end

            local missing = {}
            for _, memberName in ipairs(members) do
                if not item:HasVoted(memberName) then
                    missing[#missing + 1] = memberName
                end
            end

            if #missing > 0 then
                local pollData = {
                    itemGUID      = item.guid,
                    missingVoters = missing,
                    sessionID     = self.sessionID,
                }
                Loothing.Comm:Send(Loothing.MsgType.VOTE_POLL, pollData)
                Loothing:Debug("Session: VOTE_POLL broadcast for", #missing, "missing council voter(s)")
            end
        end)
    end
end

--- Cancel voting on a specific item
-- @param guid string - Item GUID (optional, cancels all if nil)
-- @return boolean
function SessionMixin:CancelVoting(guid)
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


        item:SetState(Loothing.ItemState.PENDING)
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

            item:SetState(Loothing.ItemState.PENDING)

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
function SessionMixin:EndVotingForItem(guid)
    local item = self:GetItemByGUID(guid)
    if not item or not item:IsVoting() then
        return nil
    end

    -- Clear item timers
    if item.voteTimer then
        item.voteTimer:Cancel()
        item.voteTimer = nil
    end


    item:EndVoting()

    return self:RetallyVoteResultsForItem(item)
end

--- Recompute and broadcast vote results for an item.
-- Used when voting closes and when late grace-window VOTE_COMMITs alter a
-- tallied item, so result panels never drift from the authoritative vote set.
-- @param item table - LoothingItem
-- @return table|nil - Tally results
function SessionMixin:RetallyVoteResultsForItem(item)
    if not item then
        return nil
    end

    -- Tally votes
    local results = nil
    if Loothing.VotingEngine then
        results = Loothing.VotingEngine:Tally(item:GetVotes())
    end
    item.voteResults = results

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
function SessionMixin:EndVoting(guid)
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

--- Get all items currently in voting state
-- @return table - Array of voting items
function SessionMixin:GetVotingItems()
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
function SessionMixin:GetCurrentVotingItem()
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
function SessionMixin:UpdateCandidateVoters(item, candidateName)
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
        local roster = Utils.GetRaidRoster()
        for _, member in ipairs(roster) do
            if Utils.IsSamePlayer(member.name, candidateName) then
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
    local myName = Utils.GetPlayerFullName()
    candidate.hasMyVote = false
    for _, voter in ipairs(voters) do
        if Utils.IsSamePlayer(voter, myName) then
            candidate.hasMyVote = true
            break
        end
    end

    -- Trigger update locally
    self:TriggerEvent("OnCandidateUpdated", item, candidate)

    return candidate
end

--[[--------------------------------------------------------------------
    Vote Casting
----------------------------------------------------------------------]]

--- Cast a vote for a specific candidate on an item (per-candidate toggle)
-- @param itemGUID string - Item GUID
-- @param candidateName string - Candidate to add to voter's responses
-- @return boolean
function SessionMixin:CastVote(itemGUID, candidateName)
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

    local voter = Utils.GetPlayerFullName()
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
function SessionMixin:RetractVote(itemGUID, candidateName)
    if not itemGUID or not candidateName then return false end

    local item = self:GetItemByGUID(itemGUID)
    if not item or not item:IsVoting() then return false end

    local voter = Utils.GetPlayerFullName()
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
function SessionMixin:RetractAllVotes(itemGUID)
    if not itemGUID then return false end

    local item = self:GetItemByGUID(itemGUID)
    if not item or not item:IsVoting() then return false end

    local voter = Utils.GetPlayerFullName()

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
    if Loothing.VoteTracker then
        Loothing.VoteTracker:ClearVote(item.guid)
    end

    if not self:IsMasterLooter() and IsInGroup() then
        -- Signal ML to clear this voter's vote by sending empty responses
        Loothing.Comm:SendVoteCommit(
            item.guid,
            {},
            self.masterLooter,
            self.sessionID
        )
    elseif Loothing.HasMasterLooterVisibility and Loothing:HasMasterLooterVisibility() then
        -- ML: rebuild and broadcast voter lists — batch all affected candidates
        if Loothing.Comm and item.candidateManager and IsInGroup() then
            for _, candidateName in ipairs(affectedCandidates) do
                self:UpdateCandidateVoters(item, candidateName)
                local candidate = item.candidateManager:GetCandidate(candidateName)
                if candidate then
                    Loothing.Comm:QueueForBatch(Loothing.MsgType.VOTE_UPDATE, {
                        itemGUID      = item.guid,
                        candidateName = candidateName,
                        voters        = candidate.voters,
                        sessionID     = self.sessionID,
                    }, nil, "NORMAL")
                end
            end
            -- Let 100ms batch window coalesce with other vote updates
        end
    end

    return true
end

--- Submit a vote for a specific item
-- @param itemGUID string - Item GUID
-- @param responses table - Ranked responses
-- @return boolean
function SessionMixin:SubmitVote(itemGUID, responses)
    if not itemGUID then
        Loothing:Error("SubmitVote called with nil itemGUID")
        return false
    end

    local item = self:GetItemByGUID(itemGUID)
    if not item or not item:CanAcceptVotes() then
        return false
    end

    local voter = Utils.GetPlayerFullName()
    -- Use SafeUnitClass to avoid secret value tainting
    local _, class = Loolib.SecretUtil.SafeUnitClass("player")

    -- Only voting-eligible council members should vote (bypass in test mode)
    local isTestMode = ns.TestMode and ns.TestMode:IsEnabled()
    if Loothing.Council and not IsVotingEligibleMember(voter) and not isTestMode then
        Loothing:Debug("SubmitVote: rejected - not voting eligible:", voter)
        Loothing:Error("You are not on the council for this session.")
        return false
    end

    -- Snapshot voter arrays for affected candidates BEFORE AddVote (delta broadcast)
    local voterSnapshots = {}
    if item.candidateManager then
        for _, candidateName in ipairs(responses) do
            local c = item.candidateManager:GetCandidate(candidateName)
            voterSnapshots[candidateName] = c and c.voters and { unpack(c.voters) } or {}
        end
        -- Snapshot previous vote targets (voter list shrinks when vote moves)
        local existing = item:GetVoteByVoter(voter)
        if existing and existing.responses then
            for _, name in ipairs(existing.responses) do
                if not voterSnapshots[name] then
                    local c = item.candidateManager:GetCandidate(name)
                    voterSnapshots[name] = c and c.voters and { unpack(c.voters) } or {}
                end
            end
        end
    end

    -- Add vote locally (AddVote checks CanAcceptVotes internally too)
    item:AddVote(voter, class, responses)

    -- Notify UI that a vote was received (drives vote progress indicators)
    self:TriggerEvent("OnVoteReceived", item)

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
        -- Track the submitted vote so VoteTracker can re-send on VOTE_POLL
        if Loothing.VoteTracker then
            Loothing.VoteTracker:MarkSubmitted(item.guid, responses)
        end
    elseif self:IsMasterLooter() and Loothing.Comm and IsInGroup() then
        -- Broadcast VOTE_UPDATE only for candidates whose voter list changed
        if item.candidateManager then
            for candidateName, oldVoters in pairs(voterSnapshots) do
                local c = item.candidateManager:GetCandidate(candidateName)
                if c then
                    local newVoters = c.voters or {}
                    local changed = #oldVoters ~= #newVoters
                    if not changed then
                        for i, v in ipairs(oldVoters) do
                            if v ~= newVoters[i] then changed = true; break end
                        end
                    end
                    if changed then
                        Loothing.Comm:QueueForBatch(Loothing.MsgType.VOTE_UPDATE, {
                            itemGUID      = item.guid,
                            candidateName = candidateName,
                            voters        = newVoters,
                            sessionID     = self.sessionID,
                        }, nil, "NORMAL")
                    end
                end
            end
            -- Let 100ms batch window coalesce with other vote updates
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
function SessionMixin:AwardItem(guid, winner, response, awardReasonId, awardReasonText)
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

    local awardReason = nil
    if awardReasonId and Loothing.Settings then
        local reason = Loothing.Settings:GetAwardReasonById(awardReasonId)
        if reason then
            awardReason = reason.name
        end
    end
    if not awardReason and awardReasonText then
        awardReason = awardReasonText
    end

    -- Skip history, broadcast, and announcements in test mode
    local isTestMode = ns.TestMode and ns.TestMode:IsEnabled()

    -- Add to history (never during test mode)
    if Loothing.History and not isTestMode then
        -- Winner candidate snapshot
        local winnerCandidate = item.candidateManager and item.candidateManager:GetCandidate(winner)

        -- Snapshot all candidate responses
        local candidatesSnapshot = {}
        if item.candidateManager then
            for _, c in ipairs(item.candidateManager:GetAllCandidates()) do
                local cResponseInfo = Loothing.ResponseInfo[c.response]
                    or Loothing.SystemResponseInfo[c.response]
                candidatesSnapshot[#candidatesSnapshot + 1] = {
                    playerName   = c.playerName,
                    playerClass  = c.playerClass,
                    response     = c.response,
                    responseText = cResponseInfo and (cResponseInfo.text or cResponseInfo.name) or nil,
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

        local instanceData = item.instanceData or {}

        -- Resolve the winner's response text for top-level fields
        local responseInfo = Loothing.ResponseInfo[response]
        local responseText = responseInfo
            and (responseInfo.text or responseInfo.name) or nil

        local now = time()

        local historyEntry = {
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
            -- Back-reference to the session item, used by RevoteItem(force=true)
            -- to remove superseded history rows when an award is revoked.
            awardedItemGuid = item.guid,
            -- Winner info (original field names kept for backward compat)
            winner          = winner,
            winnerResponse  = response,
            winnerResponseText = responseText,
            winnerClass     = winnerCandidate and winnerCandidate.playerClass or nil,
            winnerNote      = winnerCandidate and winnerCandidate.note or nil,
            winnerRoll      = winnerCandidate and winnerCandidate.roll or nil,
            winnerGear1     = winnerCandidate and winnerCandidate.gear1Link or nil,
            winnerGear2     = winnerCandidate and winnerCandidate.gear2Link or nil,
            winnerGear1ilvl = winnerCandidate and winnerCandidate.gear1ilvl or nil,
            winnerGear2ilvl = winnerCandidate and winnerCandidate.gear2ilvl or nil,
            winnerIlvlDiff  = winnerCandidate and winnerCandidate.ilvlDiff or nil,
            -- Top-level response fields for direct import (avoids candidate lookup)
            response        = responseText,
            responseID      = response,
            -- Timestamps: unix epoch + pre-formatted UTC strings
            timestamp     = now,
            date          = date("!%Y-%m-%d", now),
            time          = date("!%H:%M:%S", now),
            -- Session / encounter
            encounterID    = self.encounterID,
            encounterName  = self.encounterName,
            boss           = self.encounterName,
            instance       = instanceData.name,
            difficultyID   = instanceData.difficultyID,
            difficultyName = instanceData.difficultyName,
            groupSize      = instanceData.groupSize,
            mapID          = instanceData.mapID,
            -- Award metadata
            votes         = item:GetVotes():GetSize(),
            awardReasonId = awardReasonId,
            awardReason   = awardReason,
            owner         = item.looter,
            -- Full snapshots
            candidates   = candidatesSnapshot,
            councilVotes = councilVotesSnapshot,
        }
        Loothing.History:AddEntry(historyEntry)

        -- Broadcast history entry based on the merged history.share setting.
        local share = Loothing.Settings:Get("history.share", "off")
        if share == "guild" and Loothing.Comm then
            Loothing.Comm:SendGuild(Loothing.MsgType.HISTORY_ENTRY, historyEntry)
        elseif share == "group" and Loothing.Comm then
            Loothing.Comm:Send(Loothing.MsgType.HISTORY_ENTRY, historyEntry)
        end
    end

    self:TriggerEvent("OnItemAwarded", item, winner, response)

    -- Announce via Announcer (handles token replacement, multi-line, combat queueing)
    if Loothing.Announcer then
        Loothing.Announcer:AnnounceAward(item.itemLink, winner, response, {
            awardReason = awardReason,
            itemLevel = item.itemLevel,
            itemType = item.subType,
            votes = item:GetVotes():GetSize(),
            session = self.encounterName,
        })
    end

    -- Auto-end session when all items are awarded/skipped
    self:CheckAutoEndSession()

    return true
end

--- Skip an item
-- @param guid string - Item GUID
-- @return boolean
function SessionMixin:SkipItem(guid)
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

    -- Auto-end session when all items are awarded/skipped
    self:CheckAutoEndSession()

    return true
end

--- Revote on a previously voted item (resets votes and restarts voting)
-- @param guid string - Item GUID
-- @param force boolean? - If true, allow revoting completed (awarded/skipped) items
-- @return boolean
function SessionMixin:RevoteItem(guid, force)
    if not self:IsMasterLooter() then
        Loothing:Debug("Not master looter, cannot revote")
        return false
    end

    local item = self:GetItemByGUID(guid)
    if not item then
        Loothing:Debug("Item not found for revote")
        return false
    end

    -- Completed items require explicit force (UI shows confirmation popup)
    if item:IsComplete() and not force then
        Loothing:Debug("Revote on completed item requires force:", guid)
        return false
    end

    -- Clear winner/skip state when forcing revote on a completed item
    if item:IsComplete() then
        item.winner = nil
        item.winnerResponse = nil
        item.awardedTime = nil
        item.awarded = false

        -- Drop the superseded award's history row so a subsequent re-award
        -- doesn't leave an orphan entry pointing at the previous winner.
        if Loothing.History then
            Loothing.History:RemoveByItemGUID(guid)
        end
    end

    -- Flush votes and reset to pending
    if item.votes then
        item.votes:Flush()
    end
    item:SetState(Loothing.ItemState.PENDING)

    -- Start voting again (handles broadcast internally)
    return self:StartVoting(guid)
end

--[[--------------------------------------------------------------------
    Event Handlers (WoW Events)
----------------------------------------------------------------------]]

--- Handle encounter start
function SessionMixin:OnEncounterStart(encounterID, encounterName)
    local preserveOpenPicker = false
    local pickerHandledBuffer = false
    local picker = ns.LootPickerFrame

    if picker and picker.IsShown and picker:IsShown() then
        if picker.HasCheckedSelections and picker:HasCheckedSelections() then
            local ok = picker.AutoCommitForEncounterStart
                and picker:AutoCommitForEncounterStart(encounterID, encounterName)
            pickerHandledBuffer = true
            if ok ~= true then
                preserveOpenPicker = true
                Loothing:Warn(string.format(
                    L("LOOT_PICKER_AUTOCOMMIT_FAILED_FMT",
                      "Loot Picker preserved prior selections; could not auto-start before new encounter: %s"),
                    tostring(encounterName or encounterID or "unknown")))
            end
        else
            -- No selected rows to preserve. Close the stale picker before
            -- wiping so OnLootBufferChanged does not repaint an empty state
            -- during its fade-out animation.
            picker._suppressOnHideCleanup = true
            picker:Hide()
        end
    end

    -- Wipe stale buffer from a previous encounter only when the picker is not
    -- still protecting user choices. Successful auto-commit already consumes
    -- the buffer through StartSessionWithPickedItems.
    if not preserveOpenPicker and not pickerHandledBuffer and self.lootBuffer and #self.lootBuffer > 0 then
        wipe(self.lootBuffer)
        self:TriggerEvent("OnLootBufferChanged", self.lootBuffer)
    end

    if not preserveOpenPicker then
        -- Cancel any stale afterLoot debounce from a previous encounter
        if self.pendingLootTimer then
            self.pendingLootTimer:Cancel()
            self.pendingLootTimer = nil
        end
        self.receivedLootCount = 0

        -- Stop any in-progress bag scan from previous encounter
        self:StopPostEncounterBagScan()

        -- Reset the per-encounter "already reported" dedup. Normally
        -- StartPostEncounterBagScan wipes this at the NEXT ENCOUNTER_END, but
        -- if the prior encounter was a wipe (success ~= 1), OnEncounterEnd
        -- bailed before scheduling the scan — and any entries from an even
        -- earlier kill would persist into this next kill, silently skipping
        -- legitimate re-drops. Wipe here as well to guarantee a clean slate
        -- per fresh encounter.
        wipe(self.reportedTradeableItems)
    end

    -- Snapshot current bag contents so post-encounter scan can distinguish
    -- newly looted items from old inventory still in the trade window. Active
    -- scans use a scan-local copy, so this is safe even when a preserved prior
    -- picker keeps that older scan alive briefly.
    self:SnapshotBags()
end

--- Take a snapshot of items currently in bags, keyed by itemID (not raw
--- link). Post-encounter group-loot wins arrive with bonusID-augmented
--- links that do NOT string-match the pre-encounter version of the same
--- base item, so a link-keyed snapshot would classify every post-roll
--- delivery as "new" (or fail to dedup correctly across scan ticks). The
--- canonical identity is itemID, resolved once via GetItemInfoInstant.
--- Map value is the count, so a stacked consumable going from 5→6
--- still registers as +1 new drop.
function SessionMixin:SnapshotBags()
    wipe(self.preEncounterBagSnapshot)
    for bag = 0, NUM_BAG_SLOTS do
        local numSlots = C_Container.GetContainerNumSlots(bag)
        for slot = 1, numSlots or 0 do
            local itemID = C_Container.GetContainerItemID(bag, slot)
            if itemID then
                self.preEncounterBagSnapshot[itemID] = (self.preEncounterBagSnapshot[itemID] or 0)
                    + GetContainerItemStackCount(bag, slot)
            end
        end
    end
    local keyCount = 0
    for _ in pairs(self.preEncounterBagSnapshot) do keyCount = keyCount + 1 end
    Loothing:Debug("BagSnapshot: captured", keyCount, "unique itemIDs")
end

--[[--------------------------------------------------------------------
    Encounter Scope Classifier
----------------------------------------------------------------------]]

--- Classify the current instance into a trigger scope.
-- @return string|nil - "raid", "dungeon", "openWorld", or nil (ineligible)
function SessionMixin:ClassifyEncounterScope()
    local instanceType, _, difficultyID = Utils.GetInstanceInfo()
    if instanceType == "raid" then
        -- LFR (difficultyID 17) uses personal loot — never eligible
        if difficultyID == 17 then return nil end
        return "raid"
    elseif instanceType == "party" then
        return "dungeon"
    elseif instanceType == "none" then
        return "openWorld"
    end
    -- pvp, arena, scenario → always ineligible
    return nil
end

--- Check if the given encounter scope is enabled in settings.
-- @param scope string - "raid", "dungeon", or "openWorld"
-- @return boolean
function SessionMixin:IsScopeEnabled(scope)
    if scope == "raid" then
        return Loothing.Settings:GetSessionTriggerRaid()
    elseif scope == "dungeon" then
        return Loothing.Settings:GetSessionTriggerDungeon()
    elseif scope == "openWorld" then
        return Loothing.Settings:GetSessionTriggerOpenWorld()
    end
    return false
end

--- Apply the configured action (manual/prompt/auto) for an eligible encounter.
--
-- This is the single convergence point for every *auto* session-trigger
-- path: OnEncounterEnd (sync), HandleTradable's pendingLootTimer debounce,
-- and OnLootReceived's afterLoot debounce all funnel through here.  The
-- scope gate lives here (not in StartSession) so that:
--
--   (a) the async debounces cannot bypass it by calling StartSession
--       directly with a cached lastEligibleEncounter from an earlier
--       eligible encounter, and
--   (b) explicit manual-start paths (UI Add Item, UI Session button,
--       /lt add slash command) can still call StartSession directly to
--       override the scope toggle with a deliberate user action.
--
-- @param encounterID number
-- @param encounterName string
function SessionMixin:ApplyTriggerAction(encounterID, encounterName)
    -- Scope gate: refuse to auto-trigger (or prompt-to-trigger) a session
    -- in an instance type the user has disabled.  Without this, a raid-ML
    -- who carries handleLoot=true into a M+ dungeon will start a session
    -- labeled with the dungeon boss as soon as a tradeable item drops.
    if not IsTestModeEnabled() then
        local scope = self:ClassifyEncounterScope()
        if not scope or not self:IsScopeEnabled(scope) then
            Loothing:Debug("ApplyTriggerAction: refusing — scope not enabled:",
                tostring(scope), "encounter:", tostring(encounterName))
            -- Fully clear the encounter cache and in-flight trigger state
            -- so the next HandleTradable / OnLootReceived call cannot retry
            -- the same refusal using stale fallback data (lastEncounterID
            -- is read at Session.lua line ~410 when lastEligibleEncounter
            -- is nil).
            self.lastEligibleEncounter = nil
            self.lastEncounterID = nil
            self.lastEncounterName = nil
            self.receivedLootCount = 0
            if self.pendingLootTimer then
                self.pendingLootTimer:Cancel()
                self.pendingLootTimer = nil
            end
            -- Hide any prompt that was mid-queue from a stale encounter.
            local Popups = GetPopups()
            if Popups then
                Popups:Hide("LOOTHING_CONFIRM_START_SESSION")
            end
            return
        end
    end

    local action = Loothing.Settings:GetSessionTriggerAction()
    if action == "auto" then
        self:StartSession(encounterID, encounterName)
    elseif action == "prompt" then
        local picker = ns.LootPickerFrame
        if picker and picker.IsShown and picker:IsShown() then
            if picker.IsShowingEncounter and not picker:IsShowingEncounter(encounterID) then
                Loothing:Warn(L("LOOT_PICKER_PREVIOUS_OPEN_WARNING",
                    "Loot Picker is still open for a previous encounter; resolve it before starting another picker."))
            else
                Loothing:Debug("ApplyTriggerAction: picker already open; relying on buffer refresh")
            end
            return
        end
        self:ShowSessionPrompt(encounterID, encounterName)
    end
    -- "manual": do nothing (encounter is cached in lastEligibleEncounter)
end

--[[--------------------------------------------------------------------
    OnEncounterEnd — Eligibility Gate
----------------------------------------------------------------------]]

--- Handle encounter end
-- @param encounterID number
-- @param encounterName string
-- @param difficultyID number
-- @param groupSize number
-- @param success number - 1 if boss killed, 0 if wipe
function SessionMixin:OnEncounterEnd(encounterID, encounterName, _difficultyID, _groupSize, success)
    Loothing:Debug("OnEncounterEnd:", encounterName, "id:", encounterID,
        "success:", success, "handleLoot:", tostring(Loothing.handleLoot),
        "state:", tostring(self.state), "isML:", tostring(Loothing.isMasterLooter))

    -- Must be a kill and in a group
    if success ~= 1 then return end
    if not IsInGroup() and not IsTestModeEnabled() then return end

    -- Distributed item collection: ALL clients scan bags for tradeable items
    -- after a boss kill and report them to the ML via TRADABLE comm.  This is
    -- the primary item detection path and does not depend on
    -- ENCOUNTER_LOOT_RECEIVED (which is unreliable with group loot in 12.0).
    -- Runs unconditionally (before the ML/scope gates) because non-ML clients
    -- don't yet know the ML's session-trigger preferences and need to report
    -- their bag contents either way; the ML's ApplyTriggerAction gate decides
    -- whether to act on the resulting TRADABLE messages.
    self:StartPostEncounterBagScan(encounterID, encounterName)

    -- Session auto-start gates (ML-only)
    if not Loothing.handleLoot and not IsTestModeEnabled() then
        Loothing:Debug("OnEncounterEnd: skipping session trigger — handleLoot is false")
        return
    end

    -- Scope gate.  Runs BEFORE the lastEligibleEncounter cache so a
    -- dungeon-boss kill in a raid-only-configured ML never pollutes the
    -- cache with stale data that an async debounce in HandleTradable or
    -- OnLootReceived could later read and feed into ApplyTriggerAction.
    -- (ApplyTriggerAction has its own scope gate as defense in depth, but
    -- preventing the pollution at source is cleaner.)
    if not IsTestModeEnabled() then
        local scope = self:ClassifyEncounterScope()
        if not scope or not self:IsScopeEnabled(scope) then
            Loothing:Debug("OnEncounterEnd: skipping session trigger — scope not enabled:", scope or "nil")
            return
        end
    end

    -- Cache encounter info (only for eligible-scope encounters now).
    -- HandleTradable's lootBuffer entries reference lastEncounterID as a
    -- replay-tag, and HandleTradable's pendingLootTimer fallback at line
    -- ~410 reads lastEncounterID/Name when lastEligibleEncounter is nil.
    self.lastEligibleEncounter = { id = encounterID, name = encounterName }
    self.lastEncounterID = encounterID
    self.lastEncounterName = encounterName

    if self.state ~= Loothing.SessionState.INACTIVE then
        Loothing:Debug("OnEncounterEnd: skipping session trigger — session already active")
        return
    end

    local timing = Loothing.Settings:GetSessionTriggerTiming()
    local action = Loothing.Settings:GetSessionTriggerAction()
    Loothing:Debug("OnEncounterEnd: all gates passed, timing=", timing, "action=", action)

    if timing == "encounterEnd" then
        self:ApplyTriggerAction(encounterID, encounterName)
    end
    -- "afterLoot": HandleTradable on ML will trigger session start when items arrive
end

--[[--------------------------------------------------------------------
    Post-Encounter Bag Scanner (RCLC-style distributed item collection)

    After ENCOUNTER_END with success, every player scans their bags for
    items with trade time remaining > 0 (indicating recently looted items).
    Found items are reported to the ML via TRADABLE comm.  The ML adds
    them to the session (or buffers them for session start).

    This replaces the unreliable ENCOUNTER_LOOT_RECEIVED dependency.
----------------------------------------------------------------------]]

--- Start periodic bag scanning after an encounter kill.
-- Scans every 2s for up to 60s to catch items arriving in bags.
function SessionMixin:StartPostEncounterBagScan(encounterID, encounterName)
    self:StopPostEncounterBagScan()
    self.bagScanEncounterID = encounterID
    self.bagScanEncounterName = encounterName
    self.bagScanSnapshot = self.bagScanSnapshot or {}
    wipe(self.reportedTradeableItems)
    wipe(self.bagScanSnapshot)
    for itemID, count in pairs(self.preEncounterBagSnapshot or {}) do
        self.bagScanSnapshot[itemID] = count
    end

    local scanCount = 0
    -- 30 scans × 2s = 60s window. The previous 30s window exactly matched
    -- WoW's default group-loot roll timer, so items delivered immediately
    -- after the roll closed (T+30-33s) arrived AFTER the final scan tick
    -- at T+29s. 60s covers the full roll-resolution + bag-delivery latency
    -- with margin. The LOOT_ITEM_ROLL_WON hook in GroupLootEvents.lua
    -- catches items the moment the roll resolves; this scan is the
    -- backstop for items won by raiders without Loothing or items that
    -- somehow bypass the event (e.g., trade-award transfers).
    local maxScans = 30

    Loothing:Debug("BagScan: starting post-encounter scan (60s window)")

    -- Expose start time so the picker's empty-state can render a countdown.
    -- Cleared in StopPostEncounterBagScan.
    self.bagScanStartedAt = GetTime()

    self.bagScanTimer = C_Timer.NewTicker(2, function()
        scanCount = scanCount + 1
        self:ScanBagsForTradeableItems()

        if scanCount >= maxScans then
            Loothing:Debug("BagScan: scan window expired")
            self:StopPostEncounterBagScan()
        end
    end)

    -- Also do an immediate scan
    C_Timer.After(1, function()
        if self.bagScanTimer
            and SameEncounterID(self.bagScanEncounterID, encounterID) then
            self:ScanBagsForTradeableItems()
        end
    end)
end

--- Stop the post-encounter bag scanner.
-- Only cancels the scan timer and clears scan-local metadata. The
-- pre-encounter snapshot table is wiped explicitly in EndSession after the
-- active session is done with it; scan-local snapshots are safe to clear here.
function SessionMixin:StopPostEncounterBagScan()
    if self.bagScanTimer then
        self.bagScanTimer:Cancel()
        self.bagScanTimer = nil
    end
    self.bagScanStartedAt = nil
    self.bagScanEncounterID = nil
    self.bagScanEncounterName = nil
    if self.bagScanSnapshot then
        wipe(self.bagScanSnapshot)
    end
end

--- Scan all bags for NEW tradeable items and either (ML) add them to the
--- session buffer or (non-ML) broadcast TRADABLE to the ML.
---
--- Identity by itemID, not raw itemLink: group-loot wins arrive with
--- bonusID-augmented links that do not string-match the pre-encounter
--- snapshot's link for the same base item. Keying on itemID makes the
--- diff, dedup, and trade-time lookup robust against that drift.
---
--- Non-ML TRADABLE gating: when the MLDB signals the raid is using
--- Loothing's group-loot auto-roll (ML auto-NEEDs, non-ML auto-PASS),
--- non-ML raiders win essentially nothing, so sending TRADABLE from their
--- bags is pure channel noise — the ML's LOOT_ITEM_ROLL_WON hook + their
--- own bag scan catch all wins directly. We suppress TRADABLE sends from
--- non-ML clients in that mode.
function SessionMixin:ScanBagsForTradeableItems()
    if not IsInGroup() then return end
    if not Loothing.Comm then return end

    local TradeQueue = Loothing.TradeQueue
    if not TradeQueue then return end

    -- First pass: count only. Avoid per-slot table allocation and tooltip
    -- work unless the itemID actually increased against the encounter snapshot.
    local currentCounts = {}
    for bag = 0, NUM_BAG_SLOTS do
        local numSlots = C_Container.GetContainerNumSlots(bag)
        for slot = 1, numSlots or 0 do
            local itemID = C_Container.GetContainerItemID(bag, slot)
            if itemID then
                currentCounts[itemID] = (currentCounts[itemID] or 0)
                    + GetContainerItemStackCount(bag, slot)
            end
        end
    end

    local snapshot = self.bagScanSnapshot or self.preEncounterBagSnapshot or {}
    local candidatesByItemID = {}
    local hasCandidates = false
    for itemID, currentCount in pairs(currentCounts) do
        local preCount = snapshot[itemID] or 0
        local newCopies = currentCount - preCount
        local storedReported = self.reportedTradeableItems[itemID]
        local reportedCount = tonumber(storedReported) or (storedReported == true and 1 or 0)
        if newCopies > reportedCount then
            candidatesByItemID[itemID] = {
                currentCount = currentCount,
                preCount = preCount,
                newCopies = newCopies,
                reportedCount = reportedCount,
            }
            hasCandidates = true
        end
    end

    if not hasCandidates then return end

    -- In `prompt` mode the ML's Loot Picker is the canonical override
    -- gate — the bag scan surfaces EVERY new tradeable so the picker has
    -- a complete list (BoE, low-quality, ignored, class-blocked all get
    -- a "BLOCKED" chip for per-kill opt-in). `auto` and `manual` retain
    -- pre-2.0.20 silent filter-rejection behavior.
    local triggerAction = (Loothing.Settings and Loothing.Settings:GetSessionTriggerAction())
        or "auto"
    local enforceFilters = (triggerAction ~= "prompt")

    -- Pre-compute ML authority + non-ML TRADABLE gating flags once.
    local isML = self:IsMasterLooter()
        or (Loothing.handleLoot and Loothing.isMasterLooter)
        or (Loothing.IsCanonicalML and Loothing:IsCanonicalML())

    -- TRADABLE-suppression gate for non-ML clients. Suppress when:
    --   1. We are NOT the ML (we have no self-loopback path to use), AND
    --   2. The ML's MLDB says it's actively handling loot, AND
    --   3. Group loot mode is "active" (auto-roll) — meaning non-ML
    --      clients auto-pass and don't win items, so TRADABLE from
    --      them is pure channel noise.
    --
    -- When this gate closes we skip the TRADABLE send entirely. The ML
    -- detects their own wins via LOOT_ITEM_ROLL_WON + their own bag scan.
    -- Drops that somehow land in a non-ML bag (e.g., legendary hard-skip,
    -- quality below threshold) remain the player's personal item and are
    -- not council-relevant under this mode.
    local suppressNonMLTradable = false
    if not isML then
        local mldb = Loothing.MLDB and Loothing.MLDB:Get()
        if mldb and mldb.handleLoot and mldb.groupLootMode == "active" then
            suppressNonMLTradable = true
        end
    end

    -- Second pass: collect links/trade-time only for itemIDs that had new,
    -- unreported copies. For duplicates, choose the newest trade-window slots
    -- by sorting finite trade times ascending and skipping the older copies
    -- already represented by the snapshot.
    local slotsByItemID = {}
    for bag = 0, NUM_BAG_SLOTS do
        local numSlots = C_Container.GetContainerNumSlots(bag)
        for slot = 1, numSlots or 0 do
            local itemID = C_Container.GetContainerItemID(bag, slot)
            if itemID and candidatesByItemID[itemID] then
                local itemLink = C_Container.GetContainerItemLink(bag, slot)
                if itemLink then
                    local tradeTime = TradeQueue.GetContainerItemTradeTimeRemaining
                        and TradeQueue:GetContainerItemTradeTimeRemaining(bag, slot)
                        or nil
                    if tradeTime and tradeTime > 0 and tradeTime ~= math.huge then
                        slotsByItemID[itemID] = slotsByItemID[itemID] or {}
                        slotsByItemID[itemID][#slotsByItemID[itemID] + 1] = {
                            bag = bag,
                            slot = slot,
                            link = itemLink,
                            tradeTime = tradeTime,
                            stackCount = GetContainerItemStackCount(bag, slot),
                        }
                    else
                        TraceLoot("no-trade-time", itemLink,
                            "bag=" .. bag .. " slot=" .. slot
                            .. " returned=" .. tostring(tradeTime))
                    end
                end
            end
        end
    end

    for itemID, info in pairs(candidatesByItemID) do
        local newCopies = info.newCopies
        local reportedCount = info.reportedCount
        local reportableSlots = slotsByItemID[itemID] or {}

        if #reportableSlots > 1 then
            table.sort(reportableSlots, function(a, b)
                return (a.tradeTime or 0) < (b.tradeTime or 0)
            end)
        end

        local reportableQuantity = 0
        for _, slotData in ipairs(reportableSlots) do
            reportableQuantity = reportableQuantity + (slotData.stackCount or 1)
        end

        local oldTradeableCopies = reportableQuantity - newCopies
        if oldTradeableCopies < 0 then oldTradeableCopies = 0 end

        local reportsThisScan = 0
        local skipCopies = oldTradeableCopies + reportedCount
        local representedCopies = isML
            and CountRepresentedTradeableCopies(
                self,
                itemID,
                Utils.GetPlayerFullName(),
                self.bagScanEncounterID or self.lastEncounterID
            )
            or 0

        for _, ex in ipairs(reportableSlots) do
            if reportedCount + reportsThisScan >= newCopies then break end

            local slotCopies = ex.stackCount or 1
            if skipCopies >= slotCopies then
                skipCopies = skipCopies - slotCopies
            else
                local skippedInSlot = skipCopies
                skipCopies = 0
                local availableCopies = slotCopies - skippedInSlot
                local remainingCopies = newCopies - reportedCount - reportsThisScan
                local copiesInSlot = math.min(availableCopies, remainingCopies)
                if copiesInSlot <= 0 then break end

                local itemLink = ex.link
                local rejected = false

                if enforceFilters then
                    local minQ = GetMinQuality()
                    local quality = Utils.GetItemQuality(itemLink)
                    if not quality or quality < minQ then
                        TraceLoot("quality-low", itemLink,
                            "got=" .. tostring(quality) .. " min=" .. tostring(minQ))
                        rejected = true
                    elseif IsItemClassBlocked(itemLink) then
                        local _, _, _, _, _, classID, subClassID = C_Item.GetItemInfoInstant(itemLink)
                        TraceLoot("class-blocked", itemLink,
                            "class=" .. tostring(classID) .. " sub=" .. tostring(subClassID))
                        rejected = true
                    else
                        local boe = IsItemBoE(itemLink)
                        local autoAddBoEs = Loothing.Settings and Loothing.Settings:Get("ml.autoAddBoEs", false)
                        if boe and not autoAddBoEs then
                            TraceLoot("boe-excluded", itemLink, "autoAddBoEs=false")
                            rejected = true
                        elseif Loothing.ItemFilter and Loothing.ItemFilter:ShouldIgnoreItem(itemLink) then
                            TraceLoot("in-ignore-list", itemLink)
                            rejected = true
                        end
                    end
                end

                if rejected then
                    reportsThisScan = reportsThisScan + copiesInSlot
                    self.reportedTradeableItems[itemID] = reportedCount + reportsThisScan
                else
                    local tradeTime = ex.tradeTime
                    for _ = 1, copiesInSlot do
                        local representedBefore = reportedCount + reportsThisScan
                        local forceCreate = isML
                            and (representedBefore >= representedCopies)
                            or (representedBefore > 0)
                        TraceLoot("candidate", itemLink,
                            "isML=" .. tostring(isML)
                            .. " tt=" .. tradeTime
                            .. " represented=" .. tostring(representedCopies)
                            .. " index=" .. tostring(representedBefore + 1))

                        if isML then
                            self:HandleTradable({
                                itemLink      = itemLink,
                                itemID        = itemID,
                                timeRemaining = tradeTime,
                                playerName    = Utils.GetPlayerFullName(),
                                quantity      = 1,
                                encounterID   = self.bagScanEncounterID or self.lastEncounterID,
                                encounterName = self.bagScanEncounterName or self.lastEncounterName,
                                source        = "bag_scan",
                                forceCreate   = forceCreate,
                            })
                        elseif suppressNonMLTradable then
                            TraceLoot("suppressed-nonml-tradable", itemLink,
                                "groupLoot=active handleLoot=true")
                        else
                            Loothing.Comm:Send(Loothing.MsgType.TRADABLE, {
                                itemLink      = itemLink,
                                itemID        = itemID,
                                timeRemaining = tradeTime,
                                quantity      = 1,
                                encounterID   = self.bagScanEncounterID or self.lastEncounterID,
                                encounterName = self.bagScanEncounterName or self.lastEncounterName,
                                source        = "bag_scan",
                                forceCreate   = forceCreate,
                            })
                        end

                        reportsThisScan = reportsThisScan + 1
                        self.reportedTradeableItems[itemID] = reportedCount + reportsThisScan
                    end
                end
            end
        end
    end
end

--- Show the loot-picker dialog to the ML so they can choose which items
--- from the encounter go into the new session. Falls back to the
--- legacy yes/no popup if the picker isn't available (test mode, etc.).
-- @param encounterID number
-- @param encounterName string
function SessionMixin:ShowSessionPrompt(encounterID, encounterName)
    -- Guard: Don't show if session already active
    if self.state ~= Loothing.SessionState.INACTIVE then
        return
    end

    -- Guard: Don't show if encounterID is nil (can happen with afterLoot timing edge cases)
    if not encounterID then
        encounterID = 0
        encounterName = encounterName or "Unknown Boss"
    end

    -- Preferred path: themed Loot Picker (replaces the yes/no popup)
    local picker = ns.LootPickerFrame
    if picker and picker.Show then
        picker:Show(encounterID, encounterName, self.lootBuffer)
        return
    end

    -- Fallback: legacy confirmation popup (still used when the picker
    -- frame failed to load — e.g., during certain test harness paths).
    local Popups = GetPopups()
    if not Popups then return end

    Popups:Show("LOOTHING_CONFIRM_START_SESSION", {
        boss = encounterName or "Unknown Boss",
        onAccept = function()
            self:StartSession(encounterID, encounterName)
        end,
    })
end

--- Cancel any pending prompt-mode debounce so a stale follow-up bag
--- scan doesn't immediately re-show the picker after the user cancels.
--- Called from LootPickerFrame:OnCancel.
-- @param encounterID number|nil - picker encounter to cancel; nil means the encounterless bucket
function SessionMixin:CancelPendingPrompt(encounterID)
    if self.pendingLootTimer then
        self.pendingLootTimer:Cancel()
        self.pendingLootTimer = nil
    end
    -- Stop the matching post-encounter bag scan and clear its dedup table.
    -- If the user is closing an older preserved picker while a newer
    -- encounter scan is running, keep that scan alive so current loot is not
    -- lost behind the old dialog.
    if not self.bagScanEncounterID or SameEncounterID(self.bagScanEncounterID, encounterID) then
        self:StopPostEncounterBagScan()
        if self.reportedTradeableItems then
            wipe(self.reportedTradeableItems)
        end
    end
    self.receivedLootCount = 0
    if self.lootBuffer and #self.lootBuffer > 0 then
        self:ClearLootBufferForEncounter(encounterID)
    end

    local nextEncounter = self:FindBufferedEncounter()
    if nextEncounter then
        self.lastEligibleEncounter = nextEncounter
        self.lastEncounterID = nextEncounter.id
        self.lastEncounterName = nextEncounter.name
        C_Timer.After(0, function()
            self:PromptForBufferedLoot(nextEncounter)
        end)
    else
        self.lastEligibleEncounter = nil
        self.lastEncounterID = nil
        self.lastEncounterName = nil
    end
end

--- Start a session with a pre-selected list of items from the picker.
--- The ML has already opted in to each item (including filter overrides);
--- the items are pre-loaded into the buffer so StartSession's regular
--- buffer-replay path picks them up and includes them in the single
--- SESSION_INIT broadcast (instead of one ITEM_ADD per item).
--- AddItem is called with force=true via the buffer-replay path's
--- explicit picked-item flag below.
-- @param encounterID number
-- @param encounterName string
-- @param pickedItems table - array of { itemLink, playerName, encounterID? }
-- @return boolean - true on success; false (with buffer preserved) on failure
function SessionMixin:StartSessionWithPickedItems(encounterID, encounterName, pickedItems)
    if type(pickedItems) ~= "table" then
        pickedItems = {}
    end

    self.lootBuffer = self.lootBuffer or {}

    -- Snapshot buffer CONTENTS (by copy) so we can restore them if
    -- StartSession bails. Using a deep list-copy instead of a reference
    -- capture lets us preserve the identity of `self.lootBuffer` via
    -- `wipe` + `table.insert` — safer for any module that caches the
    -- reference (the picker doesn't, but future consumers might).
    local priorBuffer = {}
    for i, entry in ipairs(self.lootBuffer) do priorBuffer[i] = entry end

    -- Replace buffer contents with EXACTLY the picked items so
    -- StartSession's buffer-replay loop (which builds SESSION_INIT)
    -- consumes the picker's decisions atomically. Stamp each entry with
    -- the target encounterID so the replay loop's encounter-match guard
    -- accepts them, and mark with `_picked = true` so AddItem can be
    -- told to bypass filters.
    local now = time()
    wipe(self.lootBuffer)
    for _, entry in ipairs(pickedItems) do
        if entry.itemLink then
            table.insert(self.lootBuffer, {
                itemLink           = entry.itemLink,
                itemID             = entry.itemID,
                playerName         = entry.playerName,
                encounterID        = encounterID,  -- normalise so replay-guard passes
                source             = entry.source,
                tradeTimeRemaining = entry.tradeTimeRemaining,
                timestamp          = now,
                _picked            = true,         -- StartSession reads this to force-add
            })
        end
    end
    for _, entry in ipairs(priorBuffer) do
        if entry and not SameEncounterID(entry.encounterID, encounterID) then
            table.insert(self.lootBuffer, entry)
        end
    end
    self:TriggerEvent("OnLootBufferChanged", self.lootBuffer)

    if not self:StartSession(encounterID, encounterName) then
        -- Restore prior buffer contents (preserving table identity) so
        -- the picker's re-show sees the same rows.
        wipe(self.lootBuffer)
        for _, entry in ipairs(priorBuffer) do
            table.insert(self.lootBuffer, entry)
        end
        self:TriggerEvent("OnLootBufferChanged", self.lootBuffer)
        if Loothing and Loothing.Print then
            local L = Loothing.Locale or {}
            Loothing:Print(L["LOOT_PICKER_START_FAILED"]
                or "Could not start the loot session — your picks were preserved.")
        end
        return false
    end

    if self.OnLootPickerSessionStarted then
        self:OnLootPickerSessionStarted()
    end

    return true
end

--- Handle loot received
function SessionMixin:OnLootReceived(encounterID, _itemID, itemLink, _quantity, playerName)
    Loothing:Debug("OnLootReceived:", itemLink, "from", playerName,
        "encounter:", encounterID, "active:", tostring(self:IsActive()),
        "isML:", tostring(self:IsMasterLooter()), "handleLoot:", tostring(Loothing.handleLoot))

    local timing = Loothing.Settings:GetSessionTriggerTiming()
    local action = Loothing.Settings:GetSessionTriggerAction()

    -- afterLoot timing: track encounter loot, then apply the configured
    -- action. Runs only on the ML's client (the `Loothing.handleLoot` gate
    -- is ML-local), but the underlying ENCOUNTER_LOOT_RECEIVED event on the
    -- ML's client fires for items distributed to ANY raid member — so the
    -- debounce counts all per-raider deliveries, not just the ML's own. In
    -- 12.0 group-loot, ENCOUNTER_LOOT_RECEIVED typically only fires for
    -- personal-loot drops; group-loot wins arrive via LOOT_ITEM_ROLL_WON
    -- (see Loot/GroupLootEvents.lua).
    if timing == "afterLoot" and action ~= "manual" and Loothing.handleLoot then
        self.receivedLootCount = (self.receivedLootCount or 0) + 1

        -- Reset/start debounce timer
        if self.pendingLootTimer then
            self.pendingLootTimer:Cancel()
        end

        -- After debounce delay with no new loot, apply the trigger action
        local debounceDelay = Loothing.Timing and Loothing.Timing.LOOT_DEBOUNCE_DELAY or 2.5
        self.pendingLootTimer = C_Timer.NewTimer(debounceDelay, function()
            if self.receivedLootCount > 0
               and self.state == Loothing.SessionState.INACTIVE
               and self.lastEligibleEncounter then
                self:ApplyTriggerAction(
                    self.lastEligibleEncounter.id,
                    self.lastEligibleEncounter.name
                )
            end
            self.receivedLootCount = 0
            self.pendingLootTimer = nil
        end)
    end

    -- Active session + ML: add item and batch-broadcast (not one IA per item)
    if self:IsActive() and self:IsMasterLooter() then
        if encounterID and self.encounterID and not SameEncounterID(encounterID, self.encounterID) then
            self:BufferDeferredLoot({
                itemLink = itemLink,
                playerName = playerName,
                encounterID = encounterID,
                encounterName = self.lastEncounterName,
            }, encounterID, self.lastEncounterName)
            return
        end
        local item = self:AddItem(itemLink, playerName, nil, nil, true)  -- skipBroadcast=true
        if item and Loothing.Comm then
            -- Queue ITEM_ADD for batch delivery instead of individual broadcast
            Loothing.Comm:QueueForBatch(Loothing.MsgType.ITEM_ADD, {
                itemLink  = itemLink,
                guid      = item.guid,
                looter    = playerName,
                sessionID = self.sessionID,
            }, nil, "NORMAL")

            -- Flush after a short debounce (coalesces rapid loot events)
            if self.lootBatchTimer then
                self.lootBatchTimer:Cancel()
            end
            self.lootBatchTimer = C_Timer.NewTimer(0.5, function()
                self.lootBatchTimer = nil
                if Loothing.Comm then
                    Loothing.Comm:FlushAll()
                end
            end)
        end
        if Utils.IsSamePlayer(playerName, Utils.GetPlayerFullName()) and Loothing.TradeQueue then
            Loothing.TradeQueue:UpdateAndSendRecentTradableItem(itemLink)
        end
        return
    end

    -- Inactive but we're designated to handle loot: buffer the item for replay on session start.
    -- Mirrors HandleTradable: prompt mode bypasses filters so the picker
    -- can show every item; auto/manual still apply quality + ignore.
    if not self:IsActive() and Loothing.handleLoot then
        local triggerAction = (Loothing.Settings and Loothing.Settings:GetSessionTriggerAction()) or "auto"
        local enforceFilters = (triggerAction ~= "prompt")
        local quality = Utils.GetItemQuality(itemLink)
        local minQ = GetMinQuality()
        local qualityOK = (not enforceFilters) or (minQ <= 0) or (quality and quality >= minQ)
        if qualityOK then
            if enforceFilters and Loothing.ItemFilter and Loothing.ItemFilter:ShouldIgnoreItem(itemLink) then
                Loothing:Debug("Item filtered (buffer):", itemLink)
            else
                -- Tradability gate. ENCOUNTER_LOOT_RECEIVED fires for
                -- soulbound-at-pickup crafting reagents (Spark of Radiance,
                -- Sparks of Omens, etc.) as well as actual distributable
                -- loot. Buffering non-tradeables leaks them into the picker
                -- even though the ML can't actually award them to other
                -- raiders — the pre-2.0.28 picker would show Spark rows
                -- but nothing else because the real gear arrived via
                -- LOOT_ITEM_ROLL_WON instead.
                --
                -- Probe bindType + classID synchronously. If the item is
                -- BoP AND a non-equippable reagent/consumable (classes 0
                -- Consumable, 7 Tradegoods, 15 Misc, 17 Profession) AND
                -- carries no trade window, it's personal — skip.
                local skipNonTradeable = false
                local _, _, _, _, _, _, _, _, _, _, _, classID, _, bindType = C_Item.GetItemInfo(itemLink)
                if bindType == 1 and classID and
                    (classID == 0 or classID == 7 or classID == 15 or classID == 17) then
                    -- Reagent / consumable / misc bound-on-pickup. These
                    -- never leave the owner's bag and shouldn't populate
                    -- a loot-council picker. (Raid gear is classID 2 / 4
                    -- and passes through.)
                    skipNonTradeable = true
                    Loothing:Debug("Skipping non-distributable loot:",
                        itemLink, "bindType=1 classID=" .. tostring(classID))
                end

                if not skipNonTradeable then
                    -- Dedup: bag scanner and HandleTradable can also buffer the same item
                    local alreadyBuffered = false
                    for _, entry in ipairs(self.lootBuffer) do
                        if entry.itemLink == itemLink
                            and entry.playerName == playerName
                            and SameEncounterID(entry.encounterID, encounterID) then
                            alreadyBuffered = true
                            break
                        end
                    end
                    if not alreadyBuffered then
                        table.insert(self.lootBuffer, {
                            itemLink = itemLink,
                            playerName = playerName,
                            encounterID = encounterID,
                            encounterName = self.lastEncounterName,
                            timestamp = time(),
                        })
                        Loothing:Debug("Buffered loot item:", itemLink, "from", playerName, "encounter", encounterID)
                        self:TriggerEvent("OnLootBufferChanged", self.lootBuffer)
                    end
                    if Utils.IsSamePlayer(playerName, Utils.GetPlayerFullName()) and Loothing.TradeQueue then
                        Loothing.TradeQueue:UpdateAndSendRecentTradableItem(itemLink)
                    end
                end
            end
        end
    end
end

--- Handle roster update — detect if ML left the group
function SessionMixin:OnRosterUpdate()
    if not self:IsActive() then return end
    if not self.masterLooter then return end

    -- Check if ML is still in the group
    local roster = Utils.GetRaidRoster()
    local mlFound = false
    for _, member in ipairs(roster) do
        if Utils.IsSamePlayer(member.name, self.masterLooter) then
            mlFound = true
            break
        end
    end

    if not mlFound then
        local departedML = self.masterLooter
        Loothing:Debug("ML left the group:", departedML)
        -- Clear explicit ML if it pointed to the departed ML
        if Loothing.explicitMasterLooter
                and Utils.IsSamePlayer(departedML, Loothing.explicitMasterLooter) then
            Loothing.explicitMasterLooter = nil
        end
        -- Clear global ML reference
        if Utils.IsSamePlayer(departedML, Loothing.masterLooter or "") then
            Loothing.masterLooter = nil
        end
        -- End the orphaned session on this client
        self:EndSession()
        -- Notify the user that ML left
        local L = Loothing.Locale
        if L and L["ML_LEFT_GROUP"] then
            Loothing:Print(string.format(L["ML_LEFT_GROUP"], departedML))
        end

        -- Trigger ML re-detection so a new leader can take over.
        -- This re-runs the normal ML detection flow, which will identify the
        -- new raid leader and prompt them based on their usageMode setting.
        if Loothing.ScheduleMLCheck then
            C_Timer.After(2, function()
                if IsInGroup() then
                    Loothing.ScheduleMLCheck()
                end
            end)
        end
    end
end

--[[--------------------------------------------------------------------
    Remote Message Handlers
----------------------------------------------------------------------]]

function SessionMixin:HandleRemoteSessionStart(data)
    -- Don't process our own messages
    if data.masterLooter == Utils.GetPlayerFullName() then
        return
    end

    -- If we already have an active session, decide whether to accept or reject.
    -- Same session duplicate → ignore.  Different session → force-end the old
    -- one (covers missed SESSION_END, ML change, rapid session restart).
    if self.state ~= Loothing.SessionState.INACTIVE then
        if data.sessionID and data.sessionID == self.sessionID then
            Loothing:Debug("Received duplicate SESSION_START for current session, ignoring")
            return
        end
        Loothing:Debug("Force-ending stale session for new SESSION_START from", data.masterLooter,
            "(old:", tostring(self.sessionID), "new:", tostring(data.sessionID), ")")
        self:EndSession()
        -- Fall through to process the new session start
    end

    -- Clean up any local pending session state (another ML started first)
    if self.pendingLootTimer then
        self.pendingLootTimer:Cancel()
        self.pendingLootTimer = nil
    end
    self.receivedLootCount = 0
    self.lastEligibleEncounter = nil
    self.lastEncounterID = nil
    self.lastEncounterName = nil
    local Popups = GetPopups()
    if Popups then
        Popups:Hide("LOOTHING_CONFIRM_START_SESSION")
    end

    -- Prefer authoritative sessionID from ML, fall back to generating locally
    self.sessionID = data.sessionID or Utils.GenerateGUID()
    self.encounterID = data.encounterID
    self.encounterName = data.encounterName
    self.startTime = time()
    self.masterLooter = data.masterLooter

    -- Propagate ML identity globally so handler security checks pass for this ML
    Loothing.masterLooter = data.masterLooter
    Loothing.isMasterLooter = false  -- we're not the ML; the sender is

    self:SetState(Loothing.SessionState.ACTIVE)

    self:TriggerEvent("OnSessionStarted", self.sessionID, data.encounterID, data.encounterName)
    Loothing:Print(string.format(Loothing.Locale["SESSION_STARTED"], data.encounterName or Loothing.Locale["MANUAL_SESSION"]))

    if Loothing.Settings:Get("frame.autoOpen") and Loothing.MainFrame then
        Loothing.MainFrame:Show()
    end
end

function SessionMixin:HandleRemoteSessionEnd(data)
    if data.masterLooter == Utils.GetPlayerFullName() then
        return
    end

    -- Validate sessionID when present (older protocol may omit it)
    if data.sessionID and not self:IsCurrentSession(data.sessionID) then
        Loothing:Debug("Ignoring session end for mismatched session", data.sessionID)
        return
    end

    self:EndSession()
end

function SessionMixin:HandleRemoteItemAdd(data)
    if data.masterLooter == Utils.GetPlayerFullName() then
        return
    end

    if not self:IsCurrentSession(data.sessionID) then
        Loothing:Debug("Ignoring item add for mismatched session", data.sessionID)
        return
    end

    -- Use AddItem with forced flag to bypass checks and register callbacks properly
    self:AddItem(data.itemLink, data.looter, data.guid, true, true)
end

function SessionMixin:HandleRemoteItemRemove(data)
    if data.masterLooter == Utils.GetPlayerFullName() then
        return
    end

    if not self:IsCurrentSession(data.sessionID) then
        Loothing:Debug("Ignoring item remove for mismatched session", data.sessionID)
        return
    end

    -- skipBroadcast=true to prevent re-broadcasting
    self:RemoveItem(data.guid, true)
end

function SessionMixin:HandleRemoteVoteRequest(data)
    if data.masterLooter == Utils.GetPlayerFullName() then
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
        timeout = Loothing.Timing.DEFAULT_VOTE_TIMEOUT
    elseif timeout ~= Loothing.Timing.NO_TIMEOUT then
        timeout = math.max(Loothing.Timing.MIN_VOTE_TIMEOUT,
                          math.min(Loothing.Timing.MAX_VOTE_TIMEOUT, timeout))
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
    elseif Loothing.HasMasterLooterVisibility and Loothing:HasMasterLooterVisibility() then
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

function SessionMixin:HandleRemoteVoteCommit(data)
    if not self:IsCurrentSession(data.sessionID) then
        return
    end

    local item = self:GetItemByGUID(data.itemGUID)
    if not item then
        return
    end

    -- Validate responses payload
    if type(data.responses) ~= "table" then
        Loothing:Debug("Rejected vote commit with invalid responses from:", tostring(data.voter))
        return
    end

    -- Guard against missing voter identity
    if not data.voter then
        Loothing:Debug("Rejected vote commit with missing voter")
        return
    end

    local isML = self:IsMasterLooter()

    -- Get voter's class from raid roster
    local roster = Utils.GetRaidRoster()
    local voterClass = "UNKNOWN"
    for _, member in ipairs(roster) do
        if Utils.IsSamePlayer(member.name, data.voter) then
            voterClass = member.classFile
            break
        end
    end

    -- Empty responses = vote retraction
    if #data.responses == 0 then
        -- ML: snapshot affected candidates BEFORE removal for delta broadcast
        local affectedSnapshots
        if isML and item.candidateManager then
            affectedSnapshots = {}
            local existing = item:GetVoteByVoter(data.voter)
            if existing and existing.responses then
                for _, name in ipairs(existing.responses) do
                    local c = item.candidateManager:GetCandidate(name)
                    affectedSnapshots[name] = c and c.voters and { unpack(c.voters) } or {}
                end
            end
        end

        item:RemoveVote(data.voter)

        -- ML: broadcast VOTE_UPDATE delta for affected candidates
        if isML then
            if Loothing.Comm and item.candidateManager then
                for candidateName, oldVoters in pairs(affectedSnapshots) do
                    self:UpdateCandidateVoters(item, candidateName)
                    local c = item.candidateManager:GetCandidate(candidateName)
                    if c then
                        local newVoters = c.voters or {}
                        local changed = #oldVoters ~= #newVoters
                        if not changed then
                            for i, v in ipairs(oldVoters) do
                                if v ~= newVoters[i] then changed = true; break end
                            end
                        end
                        if changed then
                            Loothing.Comm:QueueForBatch(Loothing.MsgType.VOTE_UPDATE, {
                                itemGUID      = item.guid,
                                candidateName = candidateName,
                                voters        = newVoters,
                                sessionID     = self.sessionID,
                            }, nil, "NORMAL")
                        end
                    end
                end
                -- Let 100ms batch window coalesce with other vote updates
            end
        end

        -- Non-ML: update all candidate voter arrays locally
        if not isML and item.candidateManager then
            for _, c in ipairs(item.candidateManager:GetAllCandidates()) do
                self:UpdateCandidateVoters(item, c.playerName)
            end
        end

        self:TriggerEvent("OnCandidateUpdated", item, { playerName = data.voter })
        if isML and item:IsTallied() then
            self:RetallyVoteResultsForItem(item)
        end
        return
    end

    -- ML: enforce vote policy (multiVote, selfVote)
    if isML then
        local multiVote = Loothing.Settings and Loothing.Settings:GetMultiVote()
        if not multiVote and #data.responses > 1 then
            Loothing:Debug("Rejected multi-vote from", tostring(data.voter), "- multiVote is disabled")
            data.responses = { data.responses[#data.responses] }
        end

        local selfVote = Loothing.Settings and Loothing.Settings:GetSelfVote()
        if not selfVote and data.voter then
            local filtered = {}
            for _, candidateName in ipairs(data.responses) do
                if not Utils.IsSamePlayer(candidateName, data.voter) then
                    filtered[#filtered + 1] = candidateName
                end
            end
            if #filtered == 0 then
                Loothing:Debug("Rejected self-vote from", tostring(data.voter))
                return
            end
            data.responses = filtered
        end
    end

    -- ML: snapshot voter arrays BEFORE AddVote for delta VOTE_UPDATE
    local voterSnapshots
    if isML and item.candidateManager then
        voterSnapshots = {}
        for _, candidateName in ipairs(data.responses) do
            local c = item.candidateManager:GetCandidate(candidateName)
            voterSnapshots[candidateName] = c and c.voters and { unpack(c.voters) } or {}
        end
        local existing = item:GetVoteByVoter(data.voter)
        if existing and existing.responses then
            for _, name in ipairs(existing.responses) do
                if not voterSnapshots[name] then
                    local c = item.candidateManager:GetCandidate(name)
                    voterSnapshots[name] = c and c.voters and { unpack(c.voters) } or {}
                end
            end
        end
    end

    -- AddVote returns false if item is past VOTING and the late-accept window
    if not item:AddVote(data.voter, voterClass, data.responses) then
        Loothing:Debug("Vote not added (item no longer accepting votes):", item.guid)
        return
    end

    -- Notify UI that a vote was received (drives vote progress indicators)
    self:TriggerEvent("OnVoteReceived", item)

    if isML then
        -- ML: broadcast VOTE_UPDATE only for candidates whose voter list changed
        if Loothing.Comm and item.candidateManager and voterSnapshots then
            for candidateName, oldVoters in pairs(voterSnapshots) do
                self:UpdateCandidateVoters(item, candidateName)
                local c = item.candidateManager:GetCandidate(candidateName)
                if c then
                    local newVoters = c.voters or {}
                    local changed = #oldVoters ~= #newVoters
                    if not changed then
                        for i, v in ipairs(oldVoters) do
                            if v ~= newVoters[i] then changed = true; break end
                        end
                    end
                    if changed then
                        Loothing.Comm:QueueForBatch(Loothing.MsgType.VOTE_UPDATE, {
                            itemGUID      = item.guid,
                            candidateName = candidateName,
                            voters        = newVoters,
                            sessionID     = self.sessionID,
                        }, nil, "NORMAL")
                    end
                end
            end
            -- Let 100ms batch window coalesce with other vote updates
        end
        if item:IsTallied() then
            self:RetallyVoteResultsForItem(item)
        end
    else
        -- Non-ML council: local vote applied, update all candidate voter arrays
        -- (covers both new targets and old targets when a vote changes).
        -- ML's authoritative VOTE_UPDATE will overwrite when it arrives.
        if item.candidateManager then
            for _, c in ipairs(item.candidateManager:GetAllCandidates()) do
                self:UpdateCandidateVoters(item, c.playerName)
            end
        end
        self:TriggerEvent("OnCandidateUpdated", item, { playerName = data.voter })
    end
end

function SessionMixin:HandleRemoteVoteAward(data)
    if data.masterLooter == Utils.GetPlayerFullName() then
        return
    end

    if not self:IsCurrentSession(data.sessionID) then
        return
    end

    local item = self:GetItemByGUID(data.itemGUID)
    if not item then
        return
    end

    -- Guard against duplicate/late awards on already-completed items
    if item:IsComplete() then
        Loothing:Debug("Ignoring duplicate award for completed item:", data.itemGUID)
        return
    end

    if item.voteTimer then
        item.voteTimer:Cancel()
        item.voteTimer = nil
    end


    item:SetWinner(data.winner)
    self:TriggerEvent("OnItemAwarded", item, data.winner)
end

function SessionMixin:HandleRemoteVoteSkip(data)
    if data.masterLooter == Utils.GetPlayerFullName() then
        return
    end

    if not self:IsCurrentSession(data.sessionID) then
        return
    end

    local item = self:GetItemByGUID(data.itemGUID)
    if not item then
        return
    end

    if item.voteTimer then
        item.voteTimer:Cancel()
        item.voteTimer = nil
    end


    item:Skip()
    self:TriggerEvent("OnItemSkipped", item)
end

function SessionMixin:HandleRemoteVoteCancel(data)
    if data.masterLooter == Utils.GetPlayerFullName() then
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

                item:SetState(Loothing.ItemState.PENDING)
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


    item:SetState(Loothing.ItemState.PENDING)
    self:TriggerEvent("OnVotingEnded", item)
end

function SessionMixin:HandleRemoteVoteResults(data)
    if data.masterLooter == Utils.GetPlayerFullName() then
        return
    end

    if not self:IsCurrentSession(data.sessionID) then
        return
    end

    local item = self:GetItemByGUID(data.itemGUID)
    if not item then
        return
    end

    -- Clear timers and set state to tallied
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
function SessionMixin:RequestPlayerGearInfo(itemGUID, playerName)
    if not self:IsMasterLooter() then
        return
    end

    Loothing.Comm:RequestPlayerInfo(itemGUID, playerName)
end

--- Get equipped item info for a given equip slot
-- @param equipSlot string - Equipment slot (e.g., "INVTYPE_HEAD")
-- @return string|nil, string|nil, number, number - slot1Link, slot2Link, slot1ilvl, slot2ilvl
function SessionMixin:GetEquippedGearForSlot(equipSlot)
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
function SessionMixin:HandlePlayerInfoRequest(data)
    local itemGUID = data.itemGUID
    local playerName = data.playerName

    -- Only respond if it's for us
    if not Utils.IsSamePlayer(playerName, Utils.GetPlayerFullName()) then
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
function SessionMixin:HandlePlayerInfoResponse(data)
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
        local roster = Utils.GetRaidRoster()
        for _, member in ipairs(roster) do
            if Utils.IsSamePlayer(member.name, data.playerName) then
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
            self:QueueResponseBroadcast(itemGUID, candidate)
        end
    end
end

--- Handle incoming player response from raid member.
-- Responses are broadcast to group, so all receivers (ML + council) process them.
-- ML: authoritative processing (CANDIDATE_UPDATE broadcast, gear request).
-- Non-ML: local candidate display (immediate UI update).
-- @param data table - { playerName, itemGUID, response, note, roll, rollMin, rollMax }
function SessionMixin:HandlePlayerResponse(data)
    local isML = self:IsMasterLooter()

    if not self:IsCurrentSession(data.sessionID) then
        return
    end

    local itemGUID = data.itemGUID
    local sender = data.playerName
    local response = data.response
    local note = data.note
    local roll = data.roll
    local rollMin = data.rollMin
    local rollMax = data.rollMax

    local item = self:GetItemByGUID(itemGUID)

    -- Validate session/item state
    if self.state ~= Loothing.SessionState.ACTIVE then
        return
    end

    if not item or not item:IsVoting() then
        return
    end

    -- Validate response value
    if not Loothing.ResponseInfo[response] and not Loothing.SystemResponseInfo[response] then
        return
    end

    -- Get sender's class from roster
    local senderClass = "UNKNOWN"
    local roster = Utils.GetRaidRoster()
    for _, member in ipairs(roster) do
        if Utils.IsSamePlayer(member.name, sender) then
            senderClass = member.classFile or "UNKNOWN"
            break
        end
    end

    -- Create or update candidate
    local candidateManager = item:GetCandidateManager()
    if not candidateManager then
        item.candidateManager = ns.CreateCandidateManager()
        candidateManager = item.candidateManager
    end

    local candidate = candidateManager:GetOrCreateCandidate(sender, senderClass)
    candidate:SetResponse(response, note)

    if roll and roll > 0 then
        candidate:SetRoll(roll, rollMin or 1, rollMax or 100)
    elseif isML then
        -- ML generates fallback roll for candidates that didn't include one
        local rollSettings = Loothing.Settings and Loothing.Settings:Get("rollFrame.rollRange")
        local fallbackMin = rollSettings and rollSettings.min or 1
        local fallbackMax = rollSettings and rollSettings.max or 100
        candidate:SetRoll(math.random(fallbackMin, fallbackMax), fallbackMin, fallbackMax)
    end

    -- Update items won count
    local itemsWon = self:GetItemsWonByPlayer(sender)
    candidate:SetItemsWon(itemsWon)

    -- Gear self-report
    if data.gear1Link or data.gear2Link then
        candidate:SetGearData(data.gear1Link, data.gear2Link, data.gear1ilvl or 0, data.gear2ilvl or 0)
        candidate:CalculateIlvlDiff(item.itemLevel)
        if candidateManager and candidateManager.UpdateCandidateGear then
            candidateManager:UpdateCandidateGear(
                candidate.playerName,
                candidate.gear1Link, candidate.gear2Link,
                candidate.gear1ilvl, candidate.gear2ilvl,
                candidate.ilvlDiff
            )
        end
    elseif isML then
        -- ML: request gear from legacy clients that don't self-report
        local hasGear = candidate.gear1Link or (candidate.gear1ilvl and candidate.gear1ilvl > 0)
        if not hasGear then
            self:RequestPlayerGearInfo(itemGUID, sender)
        end
    end

    -- ML-only: authoritative processing
    if isML then
        item.responseCount = (item.responseCount or 0) + 1

        -- Queue CANDIDATE_UPDATE broadcast (500ms sliding window)
        if Loothing.Comm then
            self:QueueResponseBroadcast(itemGUID, candidate)
        end
    end

    -- All receivers: fire UI event
    self:TriggerEvent("OnCandidateAdded", item, candidate)
end

--[[--------------------------------------------------------------------
    Response Broadcast Accumulator

    When multiple player responses arrive in a short burst (e.g., 7 players
    all sending RESPONSE_BATCH within seconds), each produces a CANDIDATE_UPDATE.
    Instead of broadcasting each individually (7+ messages), we accumulate them
    over a 500ms window and flush as a single BATCH message to council.
----------------------------------------------------------------------]]

local RESPONSE_BROADCAST_WINDOW = 0.5  -- 500ms collection window

--- Queue a candidate update for batched broadcast to council
-- @param itemGUID string
-- @param candidate table
function SessionMixin:QueueResponseBroadcast(itemGUID, candidate)
    if not self.responseBroadcastBuffer then
        self.responseBroadcastBuffer = {}
    end
    if not self.responseBroadcastIndex then
        self.responseBroadcastIndex = {}
    end

    local candidateName = candidate.playerName or candidate.name
    if not itemGUID or not candidateName then
        return
    end
    local key = tostring(itemGUID or "") .. "\001" .. tostring(candidateName or "")
    local entry = {
        command = Loothing.MsgType.CANDIDATE_UPDATE,
        data = {
            itemGUID      = itemGUID,
            candidateData = {
                name     = candidateName,
                class    = candidate.playerClass or candidate.class or "UNKNOWN",
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
        },
    }
    local existingIndex = self.responseBroadcastIndex[key]
    if existingIndex and self.responseBroadcastBuffer[existingIndex] then
        self.responseBroadcastBuffer[existingIndex] = entry
    else
        self.responseBroadcastBuffer[#self.responseBroadcastBuffer + 1] = entry
        self.responseBroadcastIndex[key] = #self.responseBroadcastBuffer
    end

    -- Start the flush timer on the first entry only. Resetting it on every
    -- response can defer council updates indefinitely during a steady stream.
    if not self.responseBroadcastTimer then
        self.responseBroadcastTimer = C_Timer.NewTimer(RESPONSE_BROADCAST_WINDOW, function()
            self:FlushResponseBroadcasts()
        end)
    end

    local maxBatch = Loothing.Comm and Loothing.Comm.MAX_BATCH_SIZE or 20
    if maxBatch < 2 then maxBatch = 20 end
    if #self.responseBroadcastBuffer >= maxBatch then
        self:FlushResponseBroadcasts()
    end
end

--- Flush accumulated response broadcasts as a single BATCH message
function SessionMixin:FlushResponseBroadcasts()
    if self.responseBroadcastTimer then
        self.responseBroadcastTimer:Cancel()
        self.responseBroadcastTimer = nil
    end

    local buffer = self.responseBroadcastBuffer
    if not buffer or #buffer == 0 then return end
    self.responseBroadcastBuffer = nil
    self.responseBroadcastIndex = nil

    if not Loothing.Comm then return end

    local maxBatch = Loothing.Comm.MAX_BATCH_SIZE or 20
    if maxBatch < 2 then maxBatch = 20 end

    local index = 1
    while index <= #buffer do
        local remaining = #buffer - index + 1
        if remaining == 1 then
            local entry = buffer[index]
            Loothing.Comm:Send(entry.command, entry.data, nil, "NORMAL")
            index = index + 1
        else
            local chunk = {}
            local chunkSize = math.min(maxBatch, remaining)
            for i = 0, chunkSize - 1 do
                chunk[#chunk + 1] = buffer[index + i]
            end
            Loothing.Comm:Send(Loothing.MsgType.BATCH, { messages = chunk }, nil, "NORMAL")
            index = index + chunkSize
        end
    end
end

--[[--------------------------------------------------------------------
    Player Results & Remote Updates
----------------------------------------------------------------------]]

--- Get the number of items a player has won in this session
-- @param playerName string
-- @return number
function SessionMixin:GetItemsWonByPlayer(playerName)
    local count = 0

    if not playerName or not self.items then
        return count
    end

    local normalizedName = Utils.NormalizeName(playerName)

    for _, item in self.items:Enumerate() do
        if item.state == Loothing.ItemState.AWARDED then
            local winner = item.winner or item.awardedTo
            if winner then
                local normalizedWinner = Utils.NormalizeName(winner)
                if normalizedWinner == normalizedName then
                    count = count + 1
                end
            end
        end
    end

    return count
end

--- Handle remote candidate update (Council view)
function SessionMixin:HandleRemoteCandidateUpdate(data)
    -- Don't process if we are ML (we generated it)
    if self:IsMasterLooter() then return end

    if type(data) ~= "table" or type(data.candidateData) ~= "table" then return end
    if type(data.candidateData.name) ~= "string" then return end

    if not self:IsCurrentSession(data.sessionID) then
        return
    end

    local item = self:GetItemByGUID(data.itemGUID)
    if not item then return end

    local cData = data.candidateData
    local candidateName = cData.name
    local candidateClass = type(cData.class) == "string" and cData.class or "UNKNOWN"
    local response = cData.response
    if response ~= nil and not Loothing.ResponseInfo[response] and not Loothing.SystemResponseInfo[response] then
        response = nil
    end
    local note = type(cData.note) == "string" and cData.note or nil
    local gear1 = type(cData.gear1) == "string" and cData.gear1 or nil
    local gear2 = type(cData.gear2) == "string" and cData.gear2 or nil
    local candidateManager = item:GetCandidateManager()
    if not candidateManager then
        item.candidateManager = ns.CreateCandidateManager()
        candidateManager = item.candidateManager
    end

    local candidate = candidateManager:GetOrCreateCandidate(candidateName, candidateClass)
    candidate:SetResponse(response, note)
    if type(cData.roll) == "number" and cData.roll > 0 then
        candidate:SetRoll(cData.roll, 1, 100) -- Range assumed 1-100 for now
    end

    -- Update gear
    if gear1 or gear2 then
        candidate.gear1Link = gear1
        candidate.gear2Link = gear2
        candidate.gear1ilvl = type(cData.ilvl1) == "number" and cData.ilvl1 or nil
        candidate.gear2ilvl = type(cData.ilvl2) == "number" and cData.ilvl2 or nil

        -- Recalculate ilvl diff if item has ilvl
        if item.itemLevel and item.itemLevel > 0 then
            local avgEquip = 0
            if candidate.gear1ilvl and candidate.gear1ilvl > 0 then
                avgEquip = candidate.gear1ilvl
                if candidate.gear2ilvl and candidate.gear2ilvl > 0 then
                    avgEquip = (candidate.gear1ilvl + candidate.gear2ilvl) / 2
                end
            end
            candidate.ilvlDiff = item.itemLevel - avgEquip
        end
    end

    candidate:SetItemsWon(type(cData.itemsWon) == "number" and cData.itemsWon or 0)

    self:TriggerEvent("OnCandidateUpdated", item, candidate)
end

--- Handle a tracked /roll from RollTracker
-- Applies roll to all voting items where the player is a candidate.
-- Runs on every client (CHAT_MSG_SYSTEM is local). ML also broadcasts for sync.
-- @param playerName string - Normalized player name
-- @param roll number - Roll result
-- @param minRoll number - Min roll range
-- @param maxRoll number - Max roll range
function SessionMixin:HandleRollTracked(playerName, roll, minRoll, maxRoll)
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
                    self:QueueResponseBroadcast(item.guid, candidate)
                end
            end
        end
    end
end

--- Handle remote vote update (Council view)
function SessionMixin:HandleRemoteVoteUpdate(data)
    -- Don't process if we are ML
    if self:IsMasterLooter() then return end

    if type(data) ~= "table" or type(data.candidateName) ~= "string" or type(data.voters) ~= "table" then
        return
    end

    if not self:IsCurrentSession(data.sessionID) then
        return
    end

    local item = self:GetItemByGUID(data.itemGUID)
    if not item then return end

    local candidateName = data.candidateName
    local voters = {}
    for _, voter in ipairs(data.voters) do
        if type(voter) == "string" then
            voters[#voters + 1] = voter
        end
    end

    -- Ensure CandidateManager exists
    local candidateManager = item:GetCandidateManager()
    if not candidateManager then
        item.candidateManager = ns.CreateCandidateManager()
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
function SessionMixin:SyncFromData(data)
    -- If we have an active session with a different ID, the ML has moved on.
    -- Force-end the stale session so the sync can restore the current one.
    if self.state ~= Loothing.SessionState.INACTIVE and self.sessionID ~= data.sessionID then
        Loothing:Debug("Force-ending stale session for sync data (old:", tostring(self.sessionID),
            "new:", tostring(data.sessionID), ")")
        self:EndSession()
    end

    self.sessionID = data.sessionID
    self.encounterID = data.encounterID
    self.encounterName = data.encounterName
    self.startTime = time()
    self.masterLooter = data.masterLooter
    self:SetState(data.state)

    -- Propagate ML identity globally so handler security checks, combat-end
    -- sync, and CheckNeedSync all resolve the correct ML for late joiners.
    Loothing.masterLooter = data.masterLooter
    Loothing.isMasterLooter = false

    -- Sync items if provided
    if data.items then
        -- Clear existing items to avoid duplicates/stale state
        self.items:Flush()

        for _, itemData in ipairs(data.items) do
            -- Use AddItem with force=true, skipBroadcast=true to bypass checks
            local item = self:AddItem(itemData.itemLink, itemData.looter, itemData.guid, true, true)
            if item then
                if itemData.state then
                    item:SetState(itemData.state)
                end

                -- Restore candidates if included in sync data
                if itemData.candidates and #itemData.candidates > 0 then
                    if not item.candidateManager then
                        item.candidateManager = ns.CreateCandidateManager()
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

    -- Fire OnVotingStarted for items already in VOTING state so the RollFrame
    -- displays them. Without this, players who missed the original VOTE_REQUEST
    -- (e.g., were in combat) would see an active session but no items to vote on.
    if self.items then
        local votingTimeout = Loothing.Timing and Loothing.Timing.DEFAULT_VOTE_TIMEOUT or 30
        for _, item in self.items:Enumerate() do
            if item:IsVoting() then
                self:TriggerEvent("OnVotingStarted", item, votingTimeout)
            end
        end
    end

    if Loothing.Settings:Get("frame.autoOpen") and Loothing.MainFrame then
        Loothing.MainFrame:Show()
    end
end
