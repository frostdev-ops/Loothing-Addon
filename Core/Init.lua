--[[--------------------------------------------------------------------
    Loothing - Loot Council Addon for WoW 12.0+
    Init - Addon initialization and namespace
----------------------------------------------------------------------]]

local Loolib = LibStub("Loolib")
local Config = Loolib.Config
local CreateFromMixins = Loolib.CreateFromMixins
local Events = Loolib.Events
local SecretUtil = Loolib.SecretUtil
local CreateFrame, GetTime, GetInstanceInfo = CreateFrame, GetTime, GetInstanceInfo
local GetNumGroupMembers, IsInGroup, IsInRaid = GetNumGroupMembers, IsInGroup, IsInRaid
local print, select, UnitExists, UnitIsGroupLeader = print, select, UnitExists, UnitIsGroupLeader

--[[--------------------------------------------------------------------
    Addon Namespace
----------------------------------------------------------------------]]

Loothing = Loothing or {}
Loothing.version = Loothing.VERSION
Loothing.initialized = false

-- ML detection state
Loothing.isMasterLooter = false     -- Are we currently the ML?
Loothing.masterLooter = nil         -- Player name of current ML (or nil)
Loothing.handleLoot = false         -- Is Loothing actively handling loot?
Loothing.isInGuildGroup = false     -- Is group leader in our guild?
Loothing.lootMethod = nil           -- Current loot method from GetLootMethod()

-- ML check state (module-private via upvalues)
local mlCheckTimer = nil            -- Pending NewMLCheck timer handle
local mlRetryCount = 0              -- Number of ML retry attempts
local raidEnterTimer = nil          -- Pending OnRaidEnter timer handle
local raidEnterAt = nil             -- Absolute trigger time for pending OnRaidEnter timer
local OnRaidEnter

-- Module references (populated during init)
Loothing.Settings = nil
Loothing.ResponseManager = nil
Loothing.ItemFilter = nil
Loothing.RollTracker = nil
Loothing.GroupLoot = nil
Loothing.Session = nil
Loothing.Council = nil
Loothing.Observer = nil
Loothing.Comm = nil
Loothing.Sync = nil
Loothing.AckTracker = nil
Loothing.Restrictions = nil
Loothing.MLDB = nil
Loothing.History = nil
Loothing.HistoryImport = nil
Loothing.TradeQueue = nil
Loothing.PlayerCache = nil
Loothing.ItemStorage = nil
Loothing.WhisperHandler = nil
Loothing.ErrorHandler = nil
Loothing.Announcer = nil
Loothing.AutoAward = nil
Loothing.ResponseButtonSettings = nil
Loothing.UI = nil

-- Localization shortcut
local L = Loothing.Locale

-- All popup dialogs are registered in UI/Popups.lua via LoothingPopups:Register()

--[[--------------------------------------------------------------------
    Event Frame
----------------------------------------------------------------------]]

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("PLAYER_LOGOUT")

--[[--------------------------------------------------------------------
    Initialization

    Module initialization order is critical. Dependencies:

    PHASE 1 - Core (no dependencies)
    - Settings: First, provides configuration for all other modules
    - ResponseManager: Uses Settings for button configurations
    - ItemFilter: Uses Settings for filter preferences
    - RollTracker: Standalone roll tracking

    PHASE 2 - Data Layer (depends on Phase 1)
    - History: Uses Settings for storage preferences
    - TradeQueue: Standalone trade management

    PHASE 3 - Council Logic (depends on Phase 1)
    - Council: Uses Settings for council configuration

    PHASE 4 - Communication (depends on Phase 3)
    - Comm: Requires Council for permission checks
    - Sync: Requires Comm for message transport

    PHASE 5 - Session Management (depends on Phases 1-4)
    - Session: Requires Settings, Comm, Council, History
    - VotingEngine: Requires Session for vote processing

    PHASE 6 - UI (depends on all above)
    - MainFrame: Requires all modules for display
    - VotePanel: Requires Session, Council, VotingEngine
    - ResultsPanel: Requires Session, VotingEngine
----------------------------------------------------------------------]]

local function InitializeModules()
    -- Initialize settings (must be first - other modules depend on it)
    -- Uses Loolib SavedVariables with multi-profile support
    if LoothingSettingsMixin then
        Loothing.Settings = CreateFromMixins(LoothingSettingsMixin)
        Loothing.Settings:Init()
    end

    -- Initialize auto-award system (depends on Settings)
    if CreateLoothingAutoAward then
        Loothing.AutoAward = CreateLoothingAutoAward()
    end

    -- Run migrations after settings are loaded (uses global scope)
    if LoothingMigration then
        LoothingMigration:Init()
        LoothingMigration:RunOnLoad()
    end

    -- Build the options table args now that all Options/*.lua files have loaded
    if Loothing.Options.BuildOptionsTable then
        Loothing.Options.BuildOptionsTable()
    end

    -- Register options table with Loolib.Config for settings dialog
    if Config and LoothingOptionsTable then
        if not Config:IsRegistered("Loothing") then
            Config:RegisterOptionsTable("Loothing", LoothingOptionsTable)
        end
    end

    -- Initialize response manager
    if CreateLoothingResponseManager then
        Loothing.ResponseManager = CreateLoothingResponseManager()
        Loothing.ResponseManager:LoadResponses()
    end

    -- Initialize item filter
    if CreateLoothingItemFilter then
        Loothing.ItemFilter = CreateLoothingItemFilter()
        Loothing.ItemFilter:Init()
    end

    -- Initialize roll tracker
    if CreateLoothingRollTracker then
        Loothing.RollTracker = CreateLoothingRollTracker()
    end

    -- Initialize group loot handler (auto-roll on group loot)
    if CreateLoothingGroupLoot then
        Loothing.GroupLoot = CreateLoothingGroupLoot()
    end

    -- Initialize history
    if LoothingHistoryMixin then
        Loothing.History = CreateFromMixins(LoothingHistoryMixin)
        Loothing.History:Init()
    end

    -- Initialize history import
    if LoothingHistoryImportMixin then
        Loothing.HistoryImport = CreateFromMixins(LoothingHistoryImportMixin)
        Loothing.HistoryImport:Init()
    end

    -- Initialize player cache (GUID-based player data)
    if CreateLoothingPlayerCache then
        Loothing.PlayerCache = CreateLoothingPlayerCache()
    end

    -- Initialize item storage
    if CreateLoothingItemStorage then
        Loothing.ItemStorage = CreateLoothingItemStorage()
    end

    -- Initialize trade queue
    if CreateLoothingTradeQueue then
        Loothing.TradeQueue = CreateLoothingTradeQueue()
    end

    -- Initialize council manager
    if LoothingCouncilMixin then
        Loothing.Council = CreateFromMixins(LoothingCouncilMixin)
        Loothing.Council:Init()
    end

    -- Initialize observer manager
    if LoothingObserverMixin then
        Loothing.Observer = CreateFromMixins(LoothingObserverMixin)
        Loothing.Observer:Init()
    end

    -- Initialize communication (Loolib.Comm handles prefix registration + CHAT_MSG_ADDON)
    if LoothingCommMixin then
        Loothing.Comm = CreateFromMixins(LoothingCommMixin)
        Loothing.Comm:Init()
    end

    -- Initialize encounter restrictions handler (must be before Announcer so it can hook OnRestrictionChanged)
    if CreateLoothingRestrictions then
        Loothing.Restrictions = CreateLoothingRestrictions()
    end

    -- FIX(Area2-2): Initialize announcer AFTER Restrictions so it can register the callback
    if CreateLoothingAnnouncer then
        Loothing.Announcer = CreateLoothingAnnouncer()
    end

    -- Initialize sync handler
    if LoothingSyncMixin then
        Loothing.Sync = CreateFromMixins(LoothingSyncMixin)
        Loothing.Sync:Init()
    end

    -- Initialize AckTracker (ML heartbeat + client auto-recovery)
    if LoothingAckTrackerMixin then
        Loothing.AckTracker = CreateLoothingAckTracker()
    end

    -- Initialize whisper command handler
    if CreateLoothingWhisperHandler then
        Loothing.WhisperHandler = CreateLoothingWhisperHandler()
    end

    -- Initialize error handler and structured logging
    if CreateLoothingErrorHandler then
        Loothing.ErrorHandler = CreateLoothingErrorHandler()
        Loothing.ErrorHandler:LoadFromDatabase()
    end

    -- Initialize MLDB (Master Looter Database)
    if CreateLoothingMLDB then
        Loothing.MLDB = CreateLoothingMLDB()
    end

    -- Initialize session manager
    if LoothingSessionMixin then
        Loothing.Session = CreateFromMixins(LoothingSessionMixin)
        Loothing.Session:Init()
    end

    -- Initialize voting engine (singleton, not a mixin)
    if LoothingVotingEngine then
        Loothing.VotingEngine = LoothingVotingEngine
    end

    -- Initialize response button settings frame
    if CreateLoothingResponseButtonSettings then
        Loothing.ResponseButtonSettings = CreateLoothingResponseButtonSettings()
    end

    -- Initialize UI last (depends on all other modules)
    if LoothingMainFrameMixin then
        Loothing.MainFrame = CreateLoothingMainFrame()
    end

    -- Initialize UI namespace with all panels
    Loothing.UI = {
        MainFrame = Loothing.MainFrame,
    }

    -- Initialize Sync Panel (modal dialog for settings/history sync)
    if CreateLoothingSyncPanel then
        local success, result = pcall(CreateLoothingSyncPanel)
        if success and result then
            Loothing.UI.SyncPanel = result
        else
            Loothing:Error("Failed to create SyncPanel:", result or "unknown error")
        end
    end

    -- Initialize Version Check Panel (group/guild version status)
    if CreateLoothingVersionCheckPanel then
        local success, result = pcall(CreateLoothingVersionCheckPanel)
        if success and result then
            Loothing.UI.VersionCheckPanel = result
        else
            Loothing:Error("Failed to create VersionCheckPanel:", result or "unknown error")
        end
    end

    -- Initialize Council Table (tabular view for ML/council to see all candidates and award)
    if CreateLoothingCouncilTable then
        local success, result = pcall(CreateLoothingCouncilTable)
        if success and result then
            Loothing.UI.CouncilTable = result
        else
            Loothing:Error("Failed to create CouncilTable:", result or "unknown error")
        end
    end

    -- Initialize Results Panel (modal dialog for viewing vote results)
    if CreateLoothingResultsPanel then
        local success, result = pcall(CreateLoothingResultsPanel)
        if success and result then
            Loothing.UI.ResultsPanel = result
        else
            Loothing:Error("Failed to create ResultsPanel:", result or "unknown error")
        end
    end

    -- Initialize Roll Frame (popup for raid members to respond to loot)
    if CreateLoothingRollFrame then
        local success, result = pcall(CreateLoothingRollFrame)
        if success and result then
            Loothing.UI.RollFrame = result
        else
            Loothing:Error("Failed to create RollFrame:", result or "unknown error")
        end
    else
        Loothing:Error("CreateLoothingRollFrame not defined - check TOC load order")
    end

    -- Initialize AddItemFrame (dedicated frame for manually adding items)
    if CreateLoothingAddItemFrame then
        local success, result = pcall(CreateLoothingAddItemFrame)
        if success and result then
            Loothing.AddItemFrame = result
        else
            Loothing:Error("Failed to create AddItemFrame:", result or "unknown error")
        end
    end

end

--[[--------------------------------------------------------------------
    ML Detection (NewMLCheck pattern)

    When PARTY_LEADER_CHANGED or PARTY_LOOT_METHOD_CHANGED fires, we
    schedule an ML check after 2 seconds. If the ML is unknown (nil) at
    check time, retry at 0.5s intervals up to 10 times. Skips PvP,
    arena, and scenario instances. Respects ml.usageMode setting.
----------------------------------------------------------------------]]

--- Check if we're in an instance type that should skip ML handling
-- @return boolean - True if we should skip ML detection
local function ShouldSkipMLCheck()
    -- Skip in PvP battlegrounds, arenas, and scenarios
    if LoothingUtils.IsInPvPOrScenario() then
        return true
    end
    -- Skip if "onlyUseInRaids" is set and we're not in a raid
    if Loothing.Settings and Loothing.Settings:Get("ml.onlyUseInRaids", true) then
        if not LoothingUtils.IsInRaidInstance() then
            return true
        end
    end
    return false
end

--- Perform the actual ML determination
-- @return string|nil - ML name or nil if unknown
local function DetermineML()
    -- Check explicit ML assignment first
    if Loothing.Settings then
        local explicit = Loothing.Settings:GetMasterLooterName()
        if explicit then
            return explicit
        end
    end

    -- In retail WoW 12.0+, the group/raid leader is treated as ML
    if IsInRaid() then
        for i = 1, GetNumGroupMembers() do
            local name, rank = SecretUtil.SafeGetRaidRosterInfo(i)
            if rank == 2 and name then -- Raid leader
                return LoothingUtils.NormalizeName(name)
            end
        end
    elseif IsInGroup() then
        if UnitIsGroupLeader("player") then
            return LoothingUtils.GetPlayerFullName()
        end
        for i = 1, 4 do
            local unit = "party" .. i
            if UnitExists(unit) and UnitIsGroupLeader(unit) then
                local name, realm = SecretUtil.SafeUnitName(unit)
                if not name then return nil end
                if realm and realm ~= "" then
                    return name .. "-" .. realm
                end
                return LoothingUtils.NormalizeName(name)
            end
        end
    end

    return nil
end

--- Core ML check logic - determines if we should be the ML
-- Handles retry for unknown ML, auto-disable on ML loss, and usage mode prompts
local function PerformMLCheck()
    if ShouldSkipMLCheck() then
        Loothing:Debug("ML check skipped - instance type not supported")
        return
    end

    if not IsInGroup() then
        -- Left group, stop handling
        if Loothing.handleLoot then
            Loothing:StopHandleLoot()
        end
        Loothing.isMasterLooter = false
        Loothing.masterLooter = nil
        Loothing.isInGuildGroup = false
        return
    end

    local ml = DetermineML()

    -- If ML is still unknown, retry at 0.5s intervals (up to 10 attempts)
    if not ml then
        mlRetryCount = mlRetryCount + 1
        if mlRetryCount < 10 then
            Loothing:Debug("ML unknown, retry #" .. mlRetryCount)
            C_Timer.After(0.5, PerformMLCheck)
            return
        end
        Loothing:Debug("ML unknown after 10 retries, giving up")
        return
    end

    mlRetryCount = 0

    local playerName = LoothingUtils.GetPlayerFullName()
    local wasML = Loothing.isMasterLooter
    local oldML = Loothing.masterLooter
    local isNowML = LoothingUtils.NormalizeName(ml) == LoothingUtils.NormalizeName(playerName)

    -- Update guild group status
    Loothing.isInGuildGroup = LoothingUtils.IsGuildGroup()

    -- Update stored loot method
    Loothing.lootMethod = Loothing.GetLootMethod and Loothing.GetLootMethod() or nil

    -- Early exit if nothing changed (but re-evaluate if we're ML without handleLoot)
    if ml == oldML and isNowML == wasML and (not isNowML or Loothing.handleLoot) then
        Loothing:Debug("ML check - no change (ML:", ml, ")")
        return
    end

    Loothing.masterLooter = ml
    Loothing.isMasterLooter = isNowML

    Loothing:Debug("ML changed:", oldML or "nil", "->", ml, "| isML:", tostring(isNowML))

    -- If we lost ML status, auto-disable
    if wasML and not isNowML then
        Loothing:Debug("Lost ML status, stopping loot handling")
        if Loothing.handleLoot then
            Loothing:StopHandleLoot()
        end
        return
    end

    -- If ML changed (but we're not ML), wipe cached MLDB and wait for new broadcast
    if not isNowML and ml ~= oldML then
        if Loothing.MLDB then
            Loothing.MLDB:Clear()
        end
        Loothing:Debug("New ML detected:", ml, "- waiting for MLDB")
        return
    end

    -- If we're ML but not yet handling loot, check usage mode to decide whether to prompt/start
    if isNowML and not Loothing.handleLoot then
        local usageMode = Loothing.Settings and Loothing.Settings:Get("ml.usageMode", "ask_gl") or "ask_gl"

        if usageMode == "never" then
            Loothing:Debug("ML detected but usage mode is 'never'")
            return
        end

        -- Check guild-only restriction
        local guildOnly = Loothing.Settings and Loothing.Settings:Get("settings.autoGroupLootGuildOnly", false) or false
        if guildOnly and not Loothing.isInGuildGroup then
            Loothing:Debug("ML detected but not in guild group (guild-only mode)")
            return
        end

        if usageMode == "gl" then
            -- Always use when group loot - auto-start
            Loothing:Debug("ML detected, usage mode 'gl' - auto-starting loot handling")
            Loothing:StartHandleLoot()
            return
        end

        if usageMode == "ask_gl" then
            -- Prompt the user for confirmation
            Loothing:Debug("ML detected, usage mode 'ask_gl' - prompting")
            LoothingPopups:Show("LOOTHING_ML_USAGE_PROMPT", nil, function()
                Loothing:StartHandleLoot()
            end)
            return
        end
    end
end

--- Schedule an ML check with 2s delay (debounced)
local function ScheduleMLCheck()
    if mlCheckTimer then
        mlCheckTimer:Cancel()
    end
    mlRetryCount = 0
    mlCheckTimer = C_Timer.NewTimer(2, PerformMLCheck)
end

local function ScheduleRaidEnter(delay)
    local triggerAt = GetTime() + delay

    if raidEnterTimer and raidEnterAt and raidEnterAt <= triggerAt then
        return
    end

    if raidEnterTimer then
        raidEnterTimer:Cancel()
    end

    raidEnterAt = triggerAt
    raidEnterTimer = C_Timer.NewTimer(delay, function()
        raidEnterTimer = nil
        raidEnterAt = nil
        OnRaidEnter()
    end)
end

--- Handle instance entry - prompts leader to activate Loothing
-- Separate from PerformMLCheck which handles ML *transitions*
OnRaidEnter = function()
    if not Loothing.initialized then return end

    local usageMode = Loothing.Settings and Loothing.Settings:Get("ml.usageMode", "ask_gl") or "ask_gl"
    if usageMode == "never" then return end
    if LoothingUtils.IsInPvPOrScenario() then return end

    if Loothing.Settings and Loothing.Settings:Get("ml.onlyUseInRaids", true) then
        if not LoothingUtils.IsInRaidInstance() then return end
    end

    if Loothing.handleLoot then return end
    if not UnitIsGroupLeader("player") then
        ScheduleMLCheck()
        return
    end

    local guildOnly = Loothing.Settings and Loothing.Settings:Get("settings.autoGroupLootGuildOnly", false) or false
    if guildOnly and not LoothingUtils.IsGuildGroup() then return end

    LoothingPopups:Hide("LOOTHING_ML_USAGE_PROMPT")

    if usageMode == "gl" then
        Loothing.isMasterLooter = true
        Loothing.masterLooter = LoothingUtils.GetPlayerFullName()
        Loothing:StartHandleLoot()
    elseif usageMode == "ask_gl" then
        local instanceName = select(1, GetInstanceInfo())
        LoothingPopups:Show("LOOTHING_ML_USAGE_PROMPT",
            { instance = instanceName },
            function()
                Loothing.isMasterLooter = true
                Loothing.masterLooter = LoothingUtils.GetPlayerFullName()
                Loothing:StartHandleLoot()
            end,
            function()
                Loothing:Print(L["ML_NOT_ACTIVE_SESSION"] or "Loothing is not active for this session. Use '/loothing start' to enable manually.")
            end
        )
    end
end

--- Start handling loot (broadcast to group)
-- Called when we become ML and usage mode permits
function Loothing:StartHandleLoot()
    if self.handleLoot then return end

    self.handleLoot = true
    self:Debug("StartHandleLoot - now handling loot")
    self:Print(L["ML_HANDLING_LOOT"] or "Now handling loot distribution.")

    -- Broadcast MLDB settings first (so candidates know our config)
    if self.MLDB then
        self.MLDB:BroadcastToRaid()
    end

    -- Broadcast council roster
    if self.Council and self.Comm then
        local members = self.Council:GetAllMembers()
        self.Comm:BroadcastCouncilRoster(members)
    end

    -- Send version check to group
    if LoothingVersionCheck and LoothingVersionCheck.Query then
        LoothingVersionCheck:Query("raid")
    end

    -- Enable whisper command handler
    if self.WhisperHandler then
        self.WhisperHandler:Enable()
    end
end

--- Stop handling loot (broadcast to group)
-- Ends any active session and notifies the group
function Loothing:StopHandleLoot()
    if not self.handleLoot then return end

    self.handleLoot = false
    self:Debug("StopHandleLoot - no longer handling loot")
    self:Print(L["ML_STOPPED_HANDLING"] or "Stopped handling loot distribution.")

    -- Broadcast to group that ML stopped handling loot
    if self.Comm and self.Comm.BroadcastStopHandleLoot then
        self.Comm:BroadcastStopHandleLoot()
    elseif self.Comm and self.Comm.Send then
        self.Comm:Send(Loothing.MsgType.STOP_HANDLE_LOOT, {}, "group")
    end

    -- Disable whisper command handler
    if self.WhisperHandler then
        self.WhisperHandler:Disable()
    end

    -- End any active session
    if self.Session and self.Session:IsActive() then
        self.Session:EndSession()
    end

    -- Clear MLDB
    if self.MLDB then
        self.MLDB:Clear()
    end
end

local function RegisterEvents()
    if not Events or not Events.Registry then return end

    -- ML detection events
    Events.Registry:RegisterEventCallback("PARTY_LEADER_CHANGED", function()
        ScheduleMLCheck()
    end, Loothing)

    Events.Registry:RegisterEventCallback("PARTY_LOOT_METHOD_CHANGED", function()
        ScheduleMLCheck()
    end, Loothing)

    Events.Registry:RegisterEventCallback("GROUP_JOINED", function()
        ScheduleMLCheck()
    end, Loothing)

    Events.Registry:RegisterEventCallback("GROUP_LEFT", function()
        if raidEnterTimer then
            raidEnterTimer:Cancel()
            raidEnterTimer = nil
            raidEnterAt = nil
        end

        if Loothing.handleLoot then
            Loothing:StopHandleLoot()
        end
        Loothing.isMasterLooter = false
        Loothing.masterLooter = nil
        Loothing.isInGuildGroup = false
        Loothing.lootMethod = nil

        -- Clear MLDB when leaving group
        if Loothing.MLDB then
            Loothing.MLDB:Clear()
        end

        -- Dismiss any pending ML usage prompt
        LoothingPopups:Hide("LOOTHING_ML_USAGE_PROMPT")
    end, Loothing)

    Events.Registry:RegisterEventCallback("RAID_INSTANCE_WELCOME", function()
        ScheduleRaidEnter(2)
    end, Loothing)

    -- Raid events
    Events.Registry:RegisterEventCallback("GROUP_ROSTER_UPDATE", function()
        ScheduleMLCheck()
        if Loothing.Council then
            Loothing.Council:OnRosterUpdate()
        end
        if Loothing.Session then
            Loothing.Session:OnRosterUpdate()
        end
        if Loothing.Sync then
            Loothing.Sync:CheckNeedSync()
        end
        -- Periodic version check on roster changes
        if LoothingVersionCheck then
            LoothingVersionCheck:OnGroupRosterUpdate()
        end
    end, Loothing)

    -- Encounter events
    Events.Registry:RegisterEventCallback("ENCOUNTER_START", function(_, encounterID, encounterName, difficultyID, groupSize)
        if Loothing.Session then
            Loothing.Session:OnEncounterStart(encounterID, encounterName, difficultyID, groupSize)
        end
    end, Loothing)

    Events.Registry:RegisterEventCallback("ENCOUNTER_END", function(_, encounterID, encounterName, difficultyID, groupSize, success)
        if Loothing.Session then
            Loothing.Session:OnEncounterEnd(encounterID, encounterName, difficultyID, groupSize, success)
        end
    end, Loothing)

    Events.Registry:RegisterEventCallback("BOSS_KILL", function(_, encounterID, encounterName)
        if Loothing.Session then
            Loothing.Session:OnBossKill(encounterID, encounterName)
        end
    end, Loothing)

    -- Loot events
    Events.Registry:RegisterEventCallback("ENCOUNTER_LOOT_RECEIVED", function(_, encounterID, itemID, itemLink, quantity, playerName, className)
        if Loothing.Session then
            Loothing.Session:OnLootReceived(encounterID, itemID, itemLink, quantity, playerName, className)
        end
    end, Loothing)

    -- NOTE: CHAT_MSG_ADDON is handled by Loolib.Comm (registered in LoothingCommMixin:Init)

    -- Wire VersionCheck callbacks to Comm events
    if Loothing.Comm and LoothingVersionCheck then
        Loothing.Comm:RegisterCallback("OnVersionRequest", function(_, data)
            LoothingVersionCheck:HandleRequest(data.requester)
        end, Loothing)

        Loothing.Comm:RegisterCallback("OnVersionResponse", function(_, data)
            LoothingVersionCheck:HandleResponse(data.version, data.sender)
        end, Loothing)
    end

    -- Wire StopHandleLoot callback to clear stale ML state on clients
    if Loothing.Comm then
        Loothing.Comm:RegisterCallback("OnStopHandleLoot", function(_, data)
            if data and data.masterLooter then
                if LoothingUtils.IsSamePlayer(data.masterLooter, Loothing.masterLooter or "") then
                    Loothing.masterLooter = nil
                    Loothing.isMasterLooter = false
                end
            end
        end, Loothing)
    end

    -- Wire CouncilRoster callback to Sync module
    if Loothing.Comm and Loothing.Sync then
        Loothing.Comm:RegisterCallback("OnCouncilRoster", function(_, data)
            Loothing.Sync:HandleCouncilRoster(data)
        end, Loothing)
    end

    -- Wire Session award → TradeQueue (only for items the local player looted)
    if Loothing.Session and Loothing.TradeQueue then
        Loothing.Session:RegisterCallback("OnItemAwarded", function(_, item, winner)
            if item.looter and LoothingUtils.IsSamePlayer(item.looter, LoothingUtils.GetPlayerFullName()) then
                Loothing.TradeQueue:AddToQueue(item.guid, item.itemLink, winner, item.timestamp)
            end
        end, Loothing)
    end

    -- Roll tracking
    Events.Registry:RegisterEventCallback("CHAT_MSG_SYSTEM", function(_, text)
        if Loothing.RollTracker then
            Loothing.RollTracker:OnChatMessage(text)
        end
    end, Loothing)

    -- NOTE: Trade window events (TRADE_SHOW, TRADE_CLOSED, TRADE_ACCEPT_UPDATE, UI_INFO_MESSAGE)
    -- are registered internally by TradeQueue:RegisterEvents()
end

local function RegisterSlashCommands()
    local function isDebugEnabled()
        return Loothing.debug == true
    end

    local function printLine(msg)
        Loothing:Print(msg)
    end

    local function printError(msg)
        Loothing:Error(msg)
    end

    local function ensureMainFrame(tabKey)
        if not Loothing.MainFrame then
            printError(L["SLASH_NO_MAINFRAME"] or "Main window not available yet.")
            return false
        end

        Loothing.MainFrame:Show()
        if tabKey and Loothing.MainFrame.SelectTab then
            Loothing.MainFrame:SelectTab(tabKey)
        end
        return true
    end

    local function openConfig(section)
        if not Config then
            printError(L["SLASH_NO_CONFIG"] or "Config dialog not available.")
            return
        end
        Config:Open("Loothing", section)
    end

    local function handleIgnore(argText)
        if not argText or argText == "" then
            printError(L["SLASH_IGNORE"])
            return
        end

        local itemLink = argText:match("|c%x+|H(item:[^|]+)|h%[([^%]]+)%]|h|r") or argText
        if not itemLink then
            printError(L["SLASH_IGNORE"])
            return
        end

        local itemID = LoothingUtils.GetItemID(itemLink)
        if not itemID then
            printError(L["SLASH_INVALID_ITEM"] or "Invalid item link.")
            return
        end

        local itemName = LoothingUtils.GetItemName(itemLink) or "Item"
        if Loothing.Settings:IsItemIgnored(itemID) then
            Loothing.Settings:RemoveIgnoredItem(itemID)
            printLine(string.format(L["ITEM_UNIGNORED"], itemName))
        else
            Loothing.Settings:AddIgnoredItem(itemID)
            printLine(string.format(L["ITEM_IGNORED"], itemName))
        end
    end

    local function handleMasterLooter(argText)
        local arg = (argText or ""):lower()

        if arg == "" then
            local ml = Loothing.Settings:GetMasterLooter()
            local explicit = Loothing.Settings:GetMasterLooterName()
            if ml then
                if explicit then
                    printLine(string.format(L["ML_IS_EXPLICIT"], ml))
                else
                    printLine(string.format(L["ML_IS_RAID_LEADER"], ml))
                end
                if Loothing.Settings:IsMasterLooter() then
                    printLine(L["YOU_ARE_ML"])
                end
            else
                printLine(L["ML_NOT_SET"])
            end
            return
        end

        if arg == "clear" or arg == "reset" then
            local canModify = Loothing.Settings:IsMasterLooter() or LoothingUtils.IsRaidLeader()
            if not canModify then
                printError(L["ERROR_NOT_ML_OR_RL"])
                return
            end
            Loothing.Settings:ClearMasterLooter()
            printLine(L["ML_CLEARED"])
            return
        end

        local canModify = Loothing.Settings:IsMasterLooter() or LoothingUtils.IsRaidLeader()
        if not canModify then
            printError(L["ERROR_NOT_ML_OR_RL"])
            return
        end
        Loothing.Settings:SetMasterLooterName(argText)
        printLine(string.format(L["ML_ASSIGNED"], argText))
    end

    local function handleSync(argText)
        local subCmd, target, days = argText:match("^(%S*)%s*(%S*)%s*(%S*)$")
        subCmd = subCmd and subCmd:lower() or ""
        target = target or ""
        days = days or ""

        if subCmd == "settings" then
            if target == "" then
                target = "guild"
            end
            if Loothing.Sync then
                Loothing.Sync:RequestSettingsSync(target)
            else
                printError(L["SLASH_SYNC_UNAVAILABLE"] or "Sync module not available.")
            end
            return
        end

        if subCmd == "history" then
            if target == "" then
                target = "guild"
            end
            local numDays = tonumber(days) or 7
            if Loothing.Sync then
                Loothing.Sync:RequestHistorySync(target, numDays)
            else
                printError(L["SLASH_SYNC_UNAVAILABLE"] or "Sync module not available.")
            end
            return
        end

        printLine("Sync commands:")
        printLine("  /lt sync settings [guild|player] - Sync settings")
        printLine("  /lt sync history [guild|player] [days] - Sync history")
    end

    local function handleImport(argText)
        if not Loothing.HistoryImport then
            printError(L["SLASH_IMPORT_UNAVAILABLE"] or "Import module not available.")
            return
        end

        local text = argText or ""
        if text == "" then
            printLine(L["SLASH_IMPORT_PROMPT"] or "Provide CSV/TSV text: /lt import <data>")
            return
        end

        local entries, err = Loothing.HistoryImport:DetectFormat(text)
        if not entries then
            printError(string.format(L["SLASH_IMPORT_PARSE_ERROR"] or "Parse error: %s", err or "unknown"))
            return
        end

        local success, importErr = Loothing.HistoryImport:ImportEntries(entries, false)
        if success then
            local stats = Loothing.HistoryImport:GetImportStats() or {}
            local imported = stats.imported or #entries
            printLine(string.format(L["SLASH_IMPORT_SUCCESS"] or "Imported %d entries.", imported))
        else
            printError(string.format(L["SLASH_IMPORT_FAILED"] or "Import failed: %s", importErr or "unknown"))
        end
    end

    local function requireDebug(commandName)
        if isDebugEnabled() then
            return true
        end
        printError(string.format(L["SLASH_DEBUG_REQUIRED"] or "Enable debug mode with /lt debug to use %s", commandName or "this command"))
        return false
    end

    local commands = {
        {
            key = "show",
            aliases = { "open" },
            description = L["SLASH_DESC_SHOW"] or "Show main window",
            usage = { "/lt", "/lt show" },
            handler = function()
                ensureMainFrame()
            end,
        },
        {
            key = "hide",
            description = L["SLASH_DESC_HIDE"] or "Hide main window",
            usage = { "/lt hide" },
            handler = function()
                if Loothing.MainFrame then
                    Loothing.MainFrame:Hide()
                else
                    printError(L["SLASH_NO_MAINFRAME"] or "Main window not available yet.")
                end
            end,
        },
        {
            key = "toggle",
            description = L["SLASH_DESC_TOGGLE"] or "Toggle main window",
            usage = { "/lt toggle" },
            handler = function()
                if not Loothing.MainFrame then
                    printError(L["SLASH_NO_MAINFRAME"] or "Main window not available yet.")
                    return
                end
                if Loothing.MainFrame:IsShown() then
                    Loothing.MainFrame:Hide()
                else
                    Loothing.MainFrame:Show()
                end
            end,
        },
        {
            key = "config",
            aliases = { "settings" },
            description = L["SLASH_DESC_CONFIG"] or "Open settings dialog",
            usage = { "/lt config", "/lt config council" },
            handler = function(args)
                openConfig(args ~= "" and args or nil)
            end,
        },
        {
            key = "history",
            description = L["SLASH_DESC_HISTORY"] or "Open history tab",
            usage = { "/lt history" },
            handler = function()
                ensureMainFrame("history")
            end,
        },
        {
            key = "council",
            description = L["SLASH_DESC_COUNCIL"] or "Open council settings",
            usage = { "/lt council" },
            handler = function()
                openConfig("council")
            end,
        },
        {
            key = "ml",
            description = L["SLASH_DESC_ML"] or "View or assign Master Looter",
            usage = { "/lt ml", "/lt ml <name>", "/lt ml clear" },
            handler = function(args)
                handleMasterLooter(args or "")
            end,
        },
        {
            key = "start",
            aliases = { "activate", "enable" },
            description = L["SLASH_DESC_START"] or "Activate loot handling",
            usage = { "/lt start" },
            handler = function()
                if not IsInGroup() then
                    printError("Must be in a group.")
                    return
                end
                if Loothing.handleLoot then
                    printLine("Already handling loot.")
                    return
                end
                if not UnitIsGroupLeader("player") then
                    printError("Only the group/raid leader can activate loot handling.")
                    return
                end
                Loothing.isMasterLooter = true
                Loothing.masterLooter = LoothingUtils.GetPlayerFullName()
                Loothing:StartHandleLoot()
            end,
        },
        {
            key = "stop",
            aliases = { "deactivate", "disable" },
            description = L["SLASH_DESC_STOP"] or "Deactivate loot handling",
            usage = { "/lt stop" },
            handler = function()
                if Loothing.handleLoot then
                    Loothing:StopHandleLoot()
                    printLine("Stopped handling loot.")
                else
                    printLine("Not currently handling loot.")
                end
            end,
        },
        {
            key = "ignore",
            description = L["SLASH_DESC_IGNORE"] or "Add/remove item from ignore list",
            usage = { "/lt ignore <itemLink|itemID>" },
            handler = function(args)
                handleIgnore(args)
            end,
        },
        {
            key = "add",
            description = L["SLASH_DESC_ADD"] or "Add item to session",
            usage = { "/lt add", "/lt add <itemLink|itemID>" },
            handler = function(args)
                if not Loothing.Session then
                    printError(L["ERROR_NO_SESSION"] or "No active session")
                    return
                end
                local input = args and args ~= "" and args or nil
                if input then
                    -- Direct add: resolve and add without opening the frame
                    local function tryAdd(link, retries)
                        retries = retries or 0
                        local name, resolvedLink = C_Item.GetItemInfo(link or input)
                        if resolvedLink then
                            -- FIX(Area4-4): Use SafeUnitName to avoid secret value tainting
                            local item = Loothing.Session:AddItem(resolvedLink, Loolib.SecretUtil.SafeUnitName("player"), nil, true)
                            if item then
                                printLine(string.format("%s added to session.", resolvedLink))
                            else
                                printError("Failed to add item to session.")
                            end
                        elseif retries < 20 then
                            C_Timer.After(0.05, function() tryAdd(input, retries + 1) end)
                        else
                            printError(L["SLASH_INVALID_ITEM"] or "Invalid item link.")
                        end
                    end
                    tryAdd(input)
                else
                    -- No args: open the AddItemFrame
                    if Loothing.AddItemFrame then
                        Loothing.AddItemFrame:Show()
                    else
                        printError("AddItemFrame not available.")
                    end
                end
            end,
        },
        {
            key = "sync",
            description = L["SLASH_DESC_SYNC"] or "Sync settings or history",
            usage = { "/lt sync settings [guild|player]", "/lt sync history [guild|player] [days]" },
            handler = function(args)
                handleSync(args or "")
            end,
        },
        {
            key = "import",
            description = L["SLASH_DESC_IMPORT"] or "Import loot history text",
            usage = { "/lt import <csv|tsv data>" },
            handler = function(args)
                handleImport(args or "")
            end,
        },
        {
            key = "errors",
            description = L["SLASH_DESC_ERRORS"] or "Show captured errors",
            usage = { "/lt errors", "/lt errors clear", "/lt errors count" },
            handler = function(args)
                if Loothing.ErrorHandler then
                    Loothing.ErrorHandler:HandleErrorsCommand(args or "")
                else
                    printError("Error handler not available.")
                end
            end,
        },
        {
            key = "log",
            description = L["SLASH_DESC_LOG"] or "View recent logs",
            usage = { "/lt log", "/lt log clear", "/lt log debug|info|warn|error", "/lt log <count>" },
            handler = function(args)
                if Loothing.ErrorHandler then
                    Loothing.ErrorHandler:HandleLogCommand(args or "")
                else
                    printError("Error handler not available.")
                end
            end,
        },
        {
            key = "debug",
            description = L["SLASH_DESC_DEBUG"] or "Toggle debug mode (enables dev commands)",
            usage = { "/lt debug", "/lt debug on", "/lt debug off" },
            handler = function(args)
                local toggle = (args or ""):lower()
                if toggle == "on" or toggle == "enable" then
                    Loothing.debug = true
                elseif toggle == "off" or toggle == "disable" then
                    Loothing.debug = false
                else
                    Loothing.debug = not Loothing.debug
                end
                printLine(string.format(L["SLASH_DEBUG_STATE"] or "Loothing debug: %s", Loothing.debug and "ON" or "OFF"))
            end,
        },
        {
            key = "test",
            devOnly = true,
            description = L["SLASH_DESC_TEST"] or "Test mode utilities",
            usage = { "/lt test", "/lt test help" },
            handler = function(args)
                if not requireDebug("/lt test") then
                    return
                end
                if LoothingTestMode then
                    LoothingTestMode:HandleCommand(args or "")
                else
                    printError(L["SLASH_TEST_UNAVAILABLE"] or "Test mode not available.")
                end
            end,
        },
        {
            key = "testmode",
            devOnly = true,
            description = L["SLASH_DESC_TESTMODE"] or "Control simulator/test mode",
            usage = { "/lt testmode on|off|status", "/lt testmode persist on|off" },
            handler = function(args)
                if not requireDebug("/lt testmode") then
                    return
                end
                if Loothing.TestMode and Loothing.TestMode.HandleSlash then
                    Loothing.TestMode:HandleSlash(args or "")
                else
                    printError(L["SLASH_TEST_UNAVAILABLE"] or "Test mode not available.")
                end
            end,
        },
        {
            key = "help",
            description = L["SLASH_DESC_HELP"] or "Show command help",
            usage = { "/lt help", "/lt help <command>" },
            handler = function(args, resolved, allCommands)
                local topic = (args or ""):lower()
                local function listCommands()
                    printLine(L["SLASH_HELP_HEADER"] or "Loothing commands:")
                    for _, c in ipairs(allCommands) do
                        if not c.devOnly or isDebugEnabled() then
                            local aliasText = ""
                            if c.aliases and #c.aliases > 0 then
                                aliasText = string.format(" (aliases: %s)", table.concat(c.aliases, ", "))
                            end
                            printLine(string.format("  /lt %s%s - %s", c.key, aliasText, c.description or ""))
                        end
                    end
                    if not isDebugEnabled() then
                        printLine(L["SLASH_HELP_DEBUG_NOTE"] or "Enable /lt debug to see developer commands.")
                    end
                end

                if topic == "" then
                    listCommands()
                    return
                end

                local lookup = resolved[topic]
                if not lookup or (lookup.devOnly and not isDebugEnabled()) then
                    printError(string.format(L["SLASH_HELP_UNKNOWN"] or "Unknown command '%s'. Use /lt help.", topic))
                    return
                end

                printLine(string.format(L["SLASH_HELP_DETAIL"] or "Usage for /lt %s:", lookup.key))
                if lookup.usage then
                    for _, line in ipairs(lookup.usage) do
                        printLine("  " .. line)
                    end
                end
                if lookup.description then
                    printLine("  " .. lookup.description)
                end
            end,
        },
    }

    local commandByToken = {}
    for _, cmd in ipairs(commands) do
        commandByToken[cmd.key] = cmd
        if cmd.aliases then
            for _, alias in ipairs(cmd.aliases) do
                commandByToken[alias] = cmd
            end
        end
    end

    Loolib.Compat.RegisterSlashCommand("LOOTHING", "/loothing", "/lt", function(msg)
        local token, rest = msg:match("^(%S*)%s*(.*)$")
        token = (token or ""):lower()
        rest = rest or ""

        -- Default route to show if no token
        if token == "" then
            local defaultCmd = commandByToken["show"]
            if defaultCmd then
                defaultCmd.handler(rest, defaultCmd, commands)
            end
            return
        end

        local command = commandByToken[token]
        if not command then
            printError(string.format(L["SLASH_HELP_UNKNOWN"] or "Unknown command '%s'. Use /lt help.", token))
            local helpCmd = commandByToken["help"]
            if helpCmd then
                helpCmd.handler("", helpCmd, commands)
            end
            return
        end

        if command.devOnly and not isDebugEnabled() then
            printError(L["SLASH_DEBUG_REQUIRED"] or "Enable debug mode with /lt debug to use this command.")
            return
        end

        command.handler(rest, command, commands)
    end)
end

--[[--------------------------------------------------------------------
    Event Handlers
----------------------------------------------------------------------]]

eventFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" then
        local addonName = ...
        if addonName == "Loothing" then
            -- Initialize all modules (Loolib.Comm handles addon prefix registration)
            InitializeModules()

            -- Register slash commands
            RegisterSlashCommands()

            Loothing.initialized = true
        end
    elseif event == "PLAYER_LOGIN" then
        if Loothing.initialized then
            -- Register for game events after login
            RegisterEvents()

            -- Load trade queue from SavedVariables
            if Loothing.TradeQueue then
                Loothing.TradeQueue:LoadFromDatabase()
            end

            -- Load item storage from SavedVariables
            if Loothing.ItemStorage then
                Loothing.ItemStorage:InitFromSavedVariables()
            end

            -- Enable group loot handler (auto-roll system)
            if Loothing.GroupLoot then
                Loothing.GroupLoot:Enable()
            end

            -- Initialize minimap button (deferred to PLAYER_LOGIN so Minimap frame exists)
            if CreateLoothingMinimapButton then
                local success, result = pcall(CreateLoothingMinimapButton)
                if success and result then
                    Loothing.MinimapButton = result
                    Loothing.UI.MinimapButton = result
                else
                    Loothing:Error("Failed to create minimap button:", result or "unknown error")
                end
            end

            -- Load persisted version data (Settings is now available)
            if LoothingVersionCheck and LoothingVersionCheck.LoadPersistedVersions then
                LoothingVersionCheck:LoadPersistedVersions()
            end

            -- Register with Blizzard's built-in addon settings panel
            if Settings and Settings.RegisterCanvasLayoutCategory then
                local settingsFrame = CreateFrame("Frame")
                settingsFrame:SetSize(600, 400)

                local logoTex = settingsFrame:CreateTexture(nil, "ARTWORK")
                logoTex:SetSize(80, 80)
                logoTex:SetPoint("TOP", 0, -20)
                logoTex:SetTexture("Interface\\AddOns\\Loothing\\Media\\logo")

                local desc = settingsFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
                desc:SetPoint("TOP", logoTex, "BOTTOM", 0, -8)
                desc:SetText("Loothing - " .. (L["ADDON_TAGLINE"] or "Loot Council Addon"))

                local subdesc = settingsFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
                subdesc:SetPoint("TOP", desc, "BOTTOM", 0, -12)
                subdesc:SetText(L["BLIZZARD_SETTINGS_DESC"] or "Click below to open the full settings panel")

                local versionText = settingsFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                versionText:SetPoint("TOP", subdesc, "BOTTOM", 0, -8)
                versionText:SetTextColor(0.7, 0.7, 0.7)
                versionText:SetText("v" .. (Loothing.VERSION or "?"))

                local openBtn = CreateFrame("Button", nil, settingsFrame, "UIPanelButtonTemplate")
                openBtn:SetSize(200, 30)
                openBtn:SetPoint("TOP", versionText, "BOTTOM", 0, -20)
                openBtn:SetText(L["OPEN_SETTINGS"] or "Open Loothing Settings")
                openBtn:SetScript("OnClick", function()
                    if SettingsPanel then
                        SettingsPanel:Close()
                    end
                    if Config then
                        Config:Open("Loothing")
                    end
                end)

                local category = Settings.RegisterCanvasLayoutCategory(settingsFrame, "Loothing")
                Settings.RegisterAddOnCategory(category)
            end

            -- Initial ML check if already in a group at login
            if IsInGroup() then
                ScheduleMLCheck()
            end

            -- Print loaded message
            print(string.format(L["ADDON_LOADED"], Loothing.VERSION))
        end
    elseif event == "PLAYER_ENTERING_WORLD" then
        local isLogin, isReload = ...
        if isReload and Loothing.initialized then
            -- UI reload - attempt to restore cached state
            Loothing:RestoreFromCache()
            -- If cache didn't restore handleLoot, re-check like login path
            if IsInGroup() and not Loothing.handleLoot then
                ScheduleRaidEnter(3)
            end
        elseif isLogin and Loothing.initialized then
            -- Try to restore cached session (e.g., disconnect/reconnect within 15 min)
            Loothing:RestoreFromCache()
            -- If no session was restored, check for raid entry prompt
            if IsInGroup() and not Loothing.handleLoot then
                ScheduleRaidEnter(3)
            end
        end
    elseif event == "PLAYER_LOGOUT" then
        -- Cache state for reconnect
        Loothing:CacheStateForReconnect()

        -- Save error log to SavedVariables
        if Loothing.ErrorHandler then
            Loothing.ErrorHandler:SaveToDatabase()
        end

        -- Save any pending data
        if Loothing.Settings then
            Loothing.Settings:Save()
        end
    end
end)

--[[--------------------------------------------------------------------
    Debug Utilities
----------------------------------------------------------------------]]

Loothing.debug = false

function Loothing:Debug(...)
    if self.debug then
        print("|cff00ff00[Loothing Debug]|r", SecretUtil.SecretsForPrint(...))
    end
end

function Loothing:Error(...)
    print("|cffff0000[Loothing Error]|r", SecretUtil.SecretsForPrint(...))
end

function Loothing:Print(...)
    print("|cff00ccff[Loothing]|r", SecretUtil.SecretsForPrint(...))
end

--[[--------------------------------------------------------------------
    Public API
----------------------------------------------------------------------]]

--- Check if the addon is ready
-- @return boolean
function Loothing:IsReady()
    return self.initialized
end

--- Get current session
-- @return table|nil
function Loothing:GetSession()
    return self.Session
end

--- Get council manager
-- @return table|nil
function Loothing:GetCouncil()
    return self.Council
end

--- Get settings
-- @return table|nil
function Loothing:GetSettings()
    return self.Settings
end

--- Toggle main window
function Loothing:Toggle()
    if self.MainFrame then
        if self.MainFrame:IsShown() then
            self.MainFrame:Hide()
        else
            self.MainFrame:Show()
        end
    end
end

--[[--------------------------------------------------------------------
    Reconnect Cache/Restore

    On PLAYER_LOGOUT, we cache critical state to global SavedVariables
    so it survives UI reloads and reconnects. On PLAYER_ENTERING_WORLD
    (reload or login), we restore from cache if it's fresh enough (<15 min old).
----------------------------------------------------------------------]]

local RECONNECT_CACHE_MAX_AGE = 15 * 60  -- 15 minutes

--- Cache current state to global SavedVariables for reconnect
function Loothing:CacheStateForReconnect()
    if not self.Settings then return end

    local cache = {
        timestamp = time(),
        handleLoot = self.handleLoot,
        isMasterLooter = self.isMasterLooter,
        masterLooter = self.masterLooter,
        isInGuildGroup = self.isInGuildGroup,
    }

    -- Cache MLDB
    if self.MLDB and self.MLDB:Get() then
        cache.mldb = self.MLDB:Get()
    end

    -- Cache council roster
    if self.Council then
        local members = self.Council:GetAllMembers()
        if members and #members > 0 then
            cache.councilRoster = members
        end
    end

    -- Cache active session state
    if self.Session and self.Session:IsActive() then
        cache.session = {
            sessionID = self.Session:GetSessionID(),
            encounterID = self.Session:GetEncounterID(),
            encounterName = self.Session:GetEncounterName(),
            state = self.Session:GetState(),
            masterLooter = self.Session:GetMasterLooter(),
        }

        -- Cache items with their states and candidate data
        local items = {}
        if self.Session.items then
            for _, item in self.Session.items:Enumerate() do
                local itemEntry = {
                    guid = item.guid,
                    itemLink = item.itemLink,
                    looter = item.looter,
                    state = item:GetState(),
                }

                -- Include candidate/vote data so ML can restore full state
                if item.candidateManager then
                    local candidates = item.candidateManager:GetAllCandidates()
                    if candidates and #candidates > 0 then
                        itemEntry.candidates = {}
                        for _, c in ipairs(candidates) do
                            itemEntry.candidates[#itemEntry.candidates + 1] = {
                                name = c.playerName,
                                class = c.playerClass,
                                response = c.response,
                                roll = c.roll,
                                note = c.note,
                                gear1 = c.gear1Link,
                                gear2 = c.gear2Link,
                                ilvl1 = c.gear1ilvl,
                                ilvl2 = c.gear2ilvl,
                                itemsWon = c.itemsWonThisSession,
                                voters = c.voters,
                            }
                        end
                    end
                end

                items[#items + 1] = itemEntry
            end
        end
        cache.session.items = items
    end

    -- FIX(critical-02): Tag cache with owner to prevent alt character restore
    cache.owner = LoothingUtils.GetPlayerFullName()

    -- Store in global scope (persists across profiles)
    self.Settings:SetGlobalValue("reconnectCache", cache)
    self:Debug("Cached state for reconnect (handleLoot:", tostring(self.handleLoot), ")")
end

--- Restore state from cache after UI reload
function Loothing:RestoreFromCache()
    if not self.Settings then return end

    local cache = self.Settings:GetGlobalValue("reconnectCache")
    if not cache then
        self:Debug("No reconnect cache found")
        return
    end

    -- FIX(critical-02): Reject cache if it belongs to a different character
    local currentOwner = LoothingUtils.GetPlayerFullName()
    if cache.owner and currentOwner and cache.owner ~= currentOwner then
        self:Debug("Reconnect cache owner mismatch; clearing stale cache from", tostring(cache.owner))
        self.Settings:SetGlobalValue("reconnectCache", nil)
        return
    end

    -- Check freshness (15 min max age)
    local age = time() - (cache.timestamp or 0)
    if age > RECONNECT_CACHE_MAX_AGE then
        self:Debug("Reconnect cache expired (age:", age, "s)")
        self.Settings:SetGlobalValue("reconnectCache", nil)
        return
    end

    self:Debug("Restoring from reconnect cache (age:", age, "s)")

    -- Restore ML state
    self.handleLoot = cache.handleLoot or false
    self.isMasterLooter = cache.isMasterLooter or false
    self.masterLooter = cache.masterLooter
    self.isInGuildGroup = cache.isInGuildGroup or false

    -- Restore MLDB
    if cache.mldb and self.MLDB then
        self.MLDB:ApplyFromML(cache.mldb, cache.masterLooter or "")
    end

    -- Restore council roster
    if cache.councilRoster and self.Council then
        self.Council:SetRemoteRoster(cache.councilRoster)
    end

    -- Restore session state
    if cache.session and self.Session then
        self.Session:SyncFromData({
            sessionID = cache.session.sessionID,
            encounterID = cache.session.encounterID,
            encounterName = cache.session.encounterName,
            state = cache.session.state,
            masterLooter = cache.session.masterLooter,
            items = cache.session.items,
        })
    end

    -- Clear the cache after restore
    self.Settings:SetGlobalValue("reconnectCache", nil)

    -- If we were handling loot and have an ML, send reconnect request
    if cache.masterLooter and not cache.isMasterLooter then
        -- We're not ML - request full state from ML
        C_Timer.After(3, function()
            if self.Sync and self.masterLooter then
                self:Debug("Sending reconnect request to ML:", self.masterLooter)
                self.Sync:RequestSync(self.masterLooter)
            end
        end)
    elseif cache.isMasterLooter and cache.handleLoot then
        -- We ARE the ML - re-broadcast MLDB and council
        C_Timer.After(2, function()
            if self.MLDB then
                self.MLDB:BroadcastToRaid()
            end
            if self.Council and self.Comm then
                local members = self.Council:GetAllMembers()
                self.Comm:BroadcastCouncilRoster(members)
            end
        end)
    end

    self:Print(L["RECONNECT_RESTORED"] or "Restored session state from cache.")
end
