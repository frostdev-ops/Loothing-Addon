--[[--------------------------------------------------------------------
    Loothing - Loot Council Addon for WoW 12.0+
    Init - Addon initialization and namespace

    Table of Contents:
      Addon Namespace .............. ~34
      Event Frame .................. ~99
      Initialization ............... ~109
      ML Detection ................. ~396
      Loot Handling ................ ~660
      Event Registration ........... ~730
      Slash Commands ............... ~960
      Event Handlers ............... ~1610
      Debug Utilities .............. ~1773
      Public API ................... ~1796
      Reconnect Cache/Restore ...... ~1835
----------------------------------------------------------------------]]

local ADDON_NAME, ns = ...
local Loolib = LibStub("Loolib")
local Config = Loolib.Config
local GlobalBridge = Loolib.Compat.GlobalBridge
local CreateFromMixins = Loolib.CreateFromMixins
local Events = Loolib.Events
local SecretUtil = Loolib.SecretUtil
local CreateFrame, GetTime, GetInstanceInfo = CreateFrame, GetTime, GetInstanceInfo
local GetNumGroupMembers, IsInGroup, IsInRaid = GetNumGroupMembers, IsInGroup, IsInRaid
local print, select, UnitExists, UnitIsGroupLeader = print, select, UnitExists, UnitIsGroupLeader
local Loothing = ns.Addon
-- Alias for public methods: architecture linter R12 flags `function Loothing:` (global method defs on addon table).
local Addon = ns.Addon
local Utils = ns.Utils

--[[--------------------------------------------------------------------
    Addon Namespace
----------------------------------------------------------------------]]

Loothing.version = Loothing.VERSION
Loothing.initialized = false

-- ML detection state
Loothing.isMasterLooter = false     -- Are we currently the ML?
Loothing.masterLooter = nil         -- Player name of current ML (or nil)
Loothing.explicitMasterLooter = nil -- Runtime-only explicit ML (per-session, synced via MLDB)
Loothing.handleLoot = false         -- Is Loothing actively handling loot?
-- User explicitly declined/disabled loot handling for this ML stint.
-- Without this latch the toggle was not respected at all: PerformMLCheck
-- re-evaluates on every roster/leader/loot-method event whenever we're ML
-- without handleLoot, and usage mode 'gl' re-enabled it seconds after the
-- user turned it off ('ask_gl' re-prompted forever instead). In-memory by
-- design: cleared on enable, on leaving the group, or on losing ML.
Loothing.handleLootDeclined = false
Loothing.isInGuildGroup = false     -- Is group leader in our guild?
Loothing.lootMethod = nil           -- Current loot method from GetLootMethod()
Loothing.mlStateVerified = true     -- False only during reconnect-cache restore until live ML check runs

-- Reusable GameTooltip for /lt tooltipscan. Frames cannot be garbage-collected
-- in WoW, so creating one per command invocation would leak a frame each time.
local scanTooltip = nil

-- ML check state (module-private via upvalues)
local mlCheckTimer = nil            -- Pending NewMLCheck timer handle
local mlRetryCount = 0              -- Number of ML retry attempts
local mlRetryTimer = nil            -- Handle for the 0.5s retry timer (prevents parallel chains)
local raidEnterTimer = nil          -- Pending OnRaidEnter timer handle
local raidEnterAt = nil             -- Absolute trigger time for pending OnRaidEnter timer
local mldbRosterTimer = nil         -- Debounce timer for MLDB re-broadcast on roster changes
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
---@type CommMixin?
Loothing.Comm = nil
Loothing.Sync = nil
Loothing.IntelShare = nil
Loothing.Heartbeat = nil
Loothing.Restrictions = nil
Loothing.MLDB = nil
Loothing.History = nil
Loothing.HistoryImport = nil
Loothing.TradeQueue = nil
Loothing.PlayerCache = nil
Loothing.ItemStorage = nil
Loothing.WhisperHandler = nil
Loothing.ErrorHandler = nil
Loothing.Diagnostics = nil
Loothing.Announcer = nil
Loothing.AutoAward = nil
Loothing.VotePanel = nil
Loothing.ResponseButtonSettings = nil
Loothing.AwardReasonsSettings = nil
Loothing.UI = nil

-- Localization shortcut
local L = ns.Locale

-- All popup dialogs are registered in UI/Popups.lua via ns.Popups:Register()
local function GetPopups()
    return ns.Popups
end

local function GetVersionCheck()
    return ns.VersionCheck
end

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
    if ns.SettingsMixin then
        Loothing.Settings = CreateFromMixins(ns.SettingsMixin)
        Loothing.Settings:Init()
    end

    -- Initialize settings export/import (depends on Settings)
    if ns.SettingsExportMixin then
        Loothing.SettingsExport = CreateFromMixins(ns.SettingsExportMixin)
        Loothing.SettingsExport:Init()
    end

    -- Initialize auto-award system (depends on Settings)
    if ns.CreateAutoAward then
        Loothing.AutoAward = ns.CreateAutoAward()
    end

    -- Run migrations after settings are loaded (uses global scope)
    if ns.Migration then
        ns.Migration:Init()
        ns.Migration:RunOnLoad()
    end

    -- Build the options table args now that all Options/*.lua files have loaded
    if ns.Options and ns.Options.BuildOptionsTable then
        ns.Options.BuildOptionsTable()
    end

    -- Register options table with Loolib.Config for settings dialog
    if Config and ns.OptionsTable then
        if not Config:IsRegistered("Loothing") then
            Config:RegisterOptionsTable("Loothing", ns.OptionsTable)
        end
        if Config.Dialog and type(Config.Dialog.SetDefaultSize) == "function" then
            Config.Dialog:SetDefaultSize("Loothing", 1040, 760)
        end
    end

    -- Initialize response manager
    if ns.CreateResponseManager then
        Loothing.ResponseManager = ns.CreateResponseManager()
        Loothing.ResponseManager:LoadResponses()
    end

    -- Initialize item filter
    if ns.CreateItemFilter then
        Loothing.ItemFilter = ns.CreateItemFilter()
        Loothing.ItemFilter:Init()
    end

    -- Initialize roll tracker
    if ns.CreateRollTracker then
        Loothing.RollTracker = ns.CreateRollTracker()
    end

    -- Initialize group loot handler (auto-roll on group loot)
    if ns.CreateGroupLoot then
        Loothing.GroupLoot = ns.CreateGroupLoot()
    end

    -- Initialize history
    if ns.HistoryMixin then
        Loothing.History = CreateFromMixins(ns.HistoryMixin)
        Loothing.History:Init()
    end

    -- Initialize history import
    if ns.HistoryImportMixin then
        Loothing.HistoryImport = CreateFromMixins(ns.HistoryImportMixin)
        Loothing.HistoryImport:Init()
    end

    -- Initialize wishlist data (desktop exchange)
    if ns.WishlistMixin then
        Loothing.Wishlist = CreateFromMixins(ns.WishlistMixin)
        Loothing.Wishlist:Init()
    end

    -- Initialize roster data (desktop exchange)
    if ns.RosterMixin then
        Loothing.Roster = CreateFromMixins(ns.RosterMixin)
        Loothing.Roster:Init()
    end

    -- Initialize player intel data (desktop exchange)
    if ns.PlayerIntelMixin then
        Loothing.PlayerIntel = CreateFromMixins(ns.PlayerIntelMixin)
        Loothing.PlayerIntel:Init()
    end

    -- Initialize trinket sim data (desktop exchange)
    if ns.TrinketSimsMixin then
        Loothing.TrinketSims = CreateFromMixins(ns.TrinketSimsMixin)
        Loothing.TrinketSims:Init()
    end

    -- Initialize droptimizer data (desktop exchange)
    if ns.DroptimizerMixin then
        Loothing.Droptimizer = CreateFromMixins(ns.DroptimizerMixin)
        Loothing.Droptimizer:Init()
    end

    -- Initialize crafting recipe scanner (desktop exchange)
    if ns.CraftingRecipesMixin then
        Loothing.CraftingRecipes = CreateFromMixins(ns.CraftingRecipesMixin)
        Loothing.CraftingRecipes:Init()
    end

    -- Initialize player cache (GUID-based player data)
    if ns.CreatePlayerCache then
        Loothing.PlayerCache = ns.CreatePlayerCache()
    end

    -- Initialize item storage
    if ns.CreateItemStorage then
        Loothing.ItemStorage = ns.CreateItemStorage()
    end

    -- Initialize trade queue
    if ns.CreateTradeQueue then
        Loothing.TradeQueue = ns.CreateTradeQueue()
    end

    -- Initialize council manager
    if ns.CouncilMixin then
        Loothing.Council = CreateFromMixins(ns.CouncilMixin)
        Loothing.Council:Init()
    end

    -- Initialize observer manager
    if ns.ObserverMixin then
        Loothing.Observer = CreateFromMixins(ns.ObserverMixin)
        Loothing.Observer:Init()
    end

    -- Initialize communication (Loolib.Comm handles prefix registration + CHAT_MSG_ADDON)
    if ns.CommMixin then
        Loothing.Comm = CreateFromMixins(ns.CommMixin)
        Loothing.Comm:Init()
    end

    -- Initialize encounter restrictions handler (must be before Announcer so it can hook OnRestrictionChanged)
    if ns.CreateRestrictions then
        Loothing.Restrictions = ns.CreateRestrictions()
    end

    -- Initialize CommState (centralized pause/resume state machine)
    -- After Restrictions (hooks into restriction transitions) and Comm (routes sends)
    if ns.CreateCommState then
        Loothing.CommState = ns.CreateCommState()
    end

    -- Initialize announcer AFTER Restrictions so it can register the callback
    if ns.CreateAnnouncer then
        Loothing.Announcer = ns.CreateAnnouncer()
    end

    -- Initialize sync handler
    if ns.SyncMixin then
        Loothing.Sync = CreateFromMixins(ns.SyncMixin)
        Loothing.Sync:Init()
    end

    -- Wire CommState circuit breaker to Sync events (must be after both are initialized)
    if Loothing.CommState and Loothing.Sync then
        Loothing.CommState:RegisterSyncCallbacks()
    end

    -- Initialize Heartbeat (ML heartbeat + client auto-recovery)
    if ns.CreateHeartbeat then
        Loothing.Heartbeat = ns.CreateHeartbeat()
    end

    -- Initialize whisper command handler
    if ns.CreateWhisperHandler then
        Loothing.WhisperHandler = ns.CreateWhisperHandler()
    end

    -- Initialize intel share (desktop data broadcast)
    if ns.IntelShareMixin then
        Loothing.IntelShare = CreateFromMixins(ns.IntelShareMixin)
        Loothing.IntelShare:Init()
    end

    -- Initialize error handler and structured logging
    if ns.CreateErrorHandler then
        Loothing.ErrorHandler = ns.CreateErrorHandler()
        Loothing.ErrorHandler:LoadFromDatabase()
    end

    -- Initialize runtime diagnostics after the error handler so it can reuse the log buffer
    if ns.CreateDiagnostics then
        Loothing.Diagnostics = ns.CreateDiagnostics()
    end

    -- Initialize MLDB (Master Looter Database)
    if ns.CreateMLDB then
        Loothing.MLDB = ns.CreateMLDB()
    end

    -- Initialize session manager
    if ns.SessionMixin then
        Loothing.Session = CreateFromMixins(ns.SessionMixin)
        Loothing.Session:Init()
    end

    -- Initialize ResponseTracker AFTER Session (needs Session callbacks)
    if ns.CreateResponseTracker then
        Loothing.ResponseTracker = ns.CreateResponseTracker()
    end

    -- Initialize VoteTracker AFTER Session + Council (needs both callbacks)
    if ns.CreateVoteTracker then
        Loothing.VoteTracker = ns.CreateVoteTracker()
    end

    -- Expose VersionCheck on Loothing for version check UI
    if ns.VersionCheck then
        Loothing.VersionCheck = ns.VersionCheck
    end

    -- Initialize voting engine (singleton, not a mixin)
    if ns.VotingEngine then
        Loothing.VotingEngine = ns.VotingEngine
    end

    -- Initialize response button settings frame
    if ns.CreateResponseButtonSettings then
        Loothing.ResponseButtonSettings = ns.CreateResponseButtonSettings()
    end

    -- Initialize award reasons settings frame
    if ns.CreateAwardReasonsSettings then
        Loothing.AwardReasonsSettings = ns.CreateAwardReasonsSettings()
    end

    -- Initialize UI last (depends on all other modules)
    if ns.CreateMainFrame then
        Loothing.MainFrame = ns.CreateMainFrame()
    end

    -- Initialize DiagPanel
    if ns.CreateDiagPanel then
        local success, result = pcall(ns.CreateDiagPanel)
        if success and result then
            Loothing.DiagPanel = result
        else
            Loothing:Error("Failed to create DiagPanel:", result or "unknown error")
        end
    end

    -- Initialize UI namespace with all panels
    Loothing.UI = {
        MainFrame = Loothing.MainFrame,
        DiagPanel = Loothing.DiagPanel,
    }

    -- Initialize Sync Panel (modal dialog for settings/history sync)
    if ns.CreateSyncPanel then
        local success, result = pcall(ns.CreateSyncPanel)
        if success and result then
            Loothing.UI.SyncPanel = result
        else
            Loothing:Error("Failed to create SyncPanel:", result or "unknown error")
        end
    end

    -- VersionCheckPanel is deliberately NOT created here: nothing ever opened
    -- it (RosterPanel's version column superseded it), so eager creation just
    -- built ~40 unreachable frames per session. The file still loads for its
    -- mixin; wire ns.CreateVersionCheckPanel lazily if a UI entry point ever
    -- wants it back.

    -- Initialize Council Table (tabular view for ML/council to see all candidates and award)
    if ns.CreateCouncilTable then
        local success, result = pcall(ns.CreateCouncilTable)
        if success and result then
            Loothing.UI.CouncilTable = result
        else
            Loothing:Error("Failed to create CouncilTable:", result or "unknown error")
        end
    end

    -- Initialize Results Panel (modal dialog for viewing vote results)
    if ns.CreateResultsPanel then
        local success, result = pcall(ns.CreateResultsPanel)
        if success and result then
            Loothing.UI.ResultsPanel = result
        else
            Loothing:Error("Failed to create ResultsPanel:", result or "unknown error")
        end
    end

    -- Initialize Vote Panel (council ranked-choice voting modal)
    if ns.CreateVotePanel then
        local success, result = pcall(ns.CreateVotePanel)
        if success and result then
            Loothing.VotePanel = result
            Loothing.UI.VotePanel = result
        else
            Loothing:Error("Failed to create VotePanel:", result or "unknown error")
        end
    end

    -- Initialize Roll Frame (popup for raid members to respond to loot)
    if ns.CreateRollFrame then
        local success, result = pcall(ns.CreateRollFrame)
        if success and result then
            Loothing.UI.RollFrame = result
        else
            Loothing:Error("Failed to create RollFrame:", result or "unknown error")
        end
    else
        Loothing:Error("ns.CreateRollFrame not defined - check TOC load order")
    end

    -- Initialize AddItemFrame (dedicated frame for manually adding items)
    if ns.CreateAddItemFrame then
        local success, result = pcall(ns.CreateAddItemFrame)
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
    if Utils.IsInPvPOrScenario() then
        return true
    end

    -- Force-cleanup when the player transitions into a *competing*
    -- instance type — a dungeon/keystone, LFR raid, PvP, arena, or
    -- scenario.  Competing means "a raid ML session should be torn
    -- down here".  Open world ("none") is NOT competing so that brief
    -- repair trips between raid pulls don't end an active session.
    --
    -- This MUST run before the active-ML bypass below.  Otherwise a
    -- raid ML who carries handleLoot=true into a M+ dungeon never
    -- gets torn down: the bypass lets PerformMLCheck run, but
    -- PerformMLCheck early-returns when ml/isNowML/handleLoot all
    -- look unchanged.  Returning true here lets the cleanup block in
    -- PerformMLCheck call StopHandleLoot, which ends the session and
    -- broadcasts SESSION_END to the group.
    -- Resolve ML scope once. The tri-state replaces the legacy
    -- onlyUseInRaids + allowOutOfRaid pair.
    --   "raids_only"          - raids only (default)
    --   "raids_and_dungeons"  - raids + 5-mans
    --   "anywhere"            - any group, including world groups
    local mlScope = (Loothing.Settings and Loothing.Settings:Get("ml.scope", "raids_only")) or "raids_only"

    -- Force-tear-down when the player transitions into an instance that
    -- competes with the configured scope. This MUST run before the
    -- active-ML bypass below — otherwise an active ML who walks into a
    -- M+ keystone (with raids_only) or a battleground (with any scope)
    -- never gets cleaned up.  openWorld is intentionally NOT competing
    -- under any scope: brief flight master / repair trips between pulls
    -- should not tear down a raid session.
    if Utils.IsInCompetingInstanceForScope(mlScope) then
        return true
    end

    -- Never skip when there is active ML state that needs re-evaluation.
    -- The scope restriction gates initial ML *activation*; it must not
    -- block handoffs or loss detection for an already-active ML who is
    -- still in an eligible or neutral (openWorld) instance.
    --   handleLoot / isMasterLooter: old ML must detect loss and stop
    --   explicitMasterLooter:        new ML must detect gain and start
    if Loothing.handleLoot or Loothing.isMasterLooter or Loothing.explicitMasterLooter then
        return false
    end

    -- Fresh activation: gate the ML usage prompt / detection on whether
    -- the current instance type is eligible for the configured scope.
    if not Utils.IsEligibleForMLScope(mlScope) then
        return true
    end

    return false
end

--- Perform the actual ML determination
-- @return string|nil - ML name or nil if unknown
local function DetermineML()
    -- Check runtime explicit ML assignment first, but only if they're in the group
    local explicit = Loothing.explicitMasterLooter
    if explicit then
        if Utils.IsPlayerInCurrentGroup(explicit) then
            return explicit
        else
            Loothing:Debug("Explicit ML", explicit, "not in group, falling through to leader detection")
        end
    end

    -- In retail WoW 12.0+, the group/raid leader is treated as ML
    if IsInRaid() then
        for i = 1, GetNumGroupMembers() do
            local name, rank = SecretUtil.SafeGetRaidRosterInfo(i)
            if rank == 2 and name then -- Raid leader
                return Utils.NormalizeName(name)
            end
        end
    elseif IsInGroup() then
        if UnitIsGroupLeader("player") then
            return Utils.GetPlayerFullName()
        end
        for i = 1, 4 do
            local unit = "party" .. i
            if UnitExists(unit) and UnitIsGroupLeader(unit) then
                local name, realm = SecretUtil.SafeUnitName(unit)
                if not name then return nil end
                if realm and realm ~= "" then
                    return name .. "-" .. realm
                end
                return Utils.NormalizeName(name)
            end
        end
    end

    return nil
end

--- Core ML check logic - determines if we should be the ML
-- Handles retry for unknown ML, auto-disable on ML loss, and usage mode prompts
local function PerformMLCheck()
    -- Defensive: while the handover modal is open, the local ML state has
    -- already been resolved (Loothing.masterLooter / isMasterLooter set).
    -- Re-running the check on roster churn could re-execute the explicit-ML
    -- pin clear or the remote-roster cleanup at a moment that races with
    -- AcceptMLHandover/RejectMLHandover. The guard supersedes the per-branch
    -- guards added later in this function (kept there for resilience).
    if ns.Popups and ns.Popups.IsShowing
        and ns.Popups:IsShowing("LOOTHING_ML_HANDOVER_PROMPT") then
        return
    end

    if ShouldSkipMLCheck() then
        -- Even when skipping, force-clear stale ML state to prevent
        -- loot handling persisting across instance type changes (e.g., raid → PvP).
        if Loothing.handleLoot or Loothing.isMasterLooter then
            Loothing:Debug("ML check skipped but clearing stale ML state")
            if Loothing.handleLoot then
                -- ML path: ends the local session AND broadcasts SESSION_END.
                Loothing:StopHandleLoot()
            end
            Loothing.isMasterLooter = false
            Loothing.masterLooter = nil
        end

        -- Non-ML defensive cleanup: a remote session from the previous
        -- instance can persist if the SESSION_END broadcast from the ML
        -- races with this client's zone transition, arrives during a
        -- comm-restricted window, or is lost entirely.  When the local
        -- instance is a *competing* type (dungeon, scenario, PvP, LFR),
        -- drop the stale view locally.  EndSession is idempotent so a
        -- later SESSION_END is a no-op.
        --
        -- Gated on Utils.IsInCompetingInstance() (NOT just any ineligible
        -- instance) for symmetry with the ML cleanup path above: a brief
        -- openWorld trip — flight master, repair NPC in the raid portal
        -- room — should not tear down the local view for non-ML clients
        -- either, because the ML's session is still legitimately running
        -- and the user will rejoin in seconds.
        if Loothing.Session and Loothing.Session.IsActive
            and Loothing.Session:IsActive()
            and not Loothing.handleLoot
            and Utils.IsInCompetingInstance() then
            Loothing:Debug("ML check skipped — clearing stale remote session state")
            Loothing.Session:EndSession()
        end

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
        Loothing.mlStateVerified = true
        -- Fresh group = fresh decision; drop any decline latch.
        Loothing.handleLootDeclined = false
        return
    end

    local ml = DetermineML()

    -- If ML is still unknown, retry at 0.5s intervals (up to 10 attempts)
    if not ml then
        mlRetryCount = mlRetryCount + 1
        if mlRetryCount < 10 then
            Loothing:Debug("ML unknown, retry #" .. mlRetryCount)
            mlRetryTimer = C_Timer.NewTimer(0.5, PerformMLCheck)
            return
        end
        Loothing:Debug("ML unknown after 10 retries, giving up")
        return
    end

    mlRetryCount = 0

    local playerName = Utils.GetPlayerFullName()
    local wasML = Loothing.isMasterLooter
    local oldML = Loothing.masterLooter
    local isNowML = Utils.NormalizeName(ml) == Utils.NormalizeName(playerName)

    -- Update guild group status
    Loothing.isInGuildGroup = Utils.IsGuildGroup()

    -- Update stored loot method
    Loothing.lootMethod = Loothing.GetLootMethod and Loothing.GetLootMethod() or nil
    Loothing.mlStateVerified = true

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
        -- The decline was about that ML stint; a later re-gain is a fresh
        -- decision.
        Loothing.handleLootDeclined = false
        if Loothing.handleLoot then
            Loothing:StopHandleLoot()
        end
        -- Drop any remote roster/observer state we may have inherited so the
        -- new ML's broadcast cleanly replaces it. (We were ML so these are
        -- usually empty, but clear defensively for re-handover edge cases.)
        if Loothing.Council and Loothing.Council.ClearRemoteRoster then
            Loothing.Council:ClearRemoteRoster()
        end
        if Loothing.Observer and Loothing.Observer.ClearRemoteObserverList then
            Loothing.Observer:ClearRemoteObserverList()
        end
        return
    end

    -- If ML changed (but we're not ML), stop handling if we were, then wait for new broadcast
    if not isNowML and ml ~= oldML then
        if Loothing.handleLoot then
            Loothing:Debug("New ML detected while handling loot, stopping")
            Loothing:StopHandleLoot()  -- internally calls MLDB:Clear()
        elseif Loothing.MLDB then
            Loothing.MLDB:Clear()
        end
        -- Drop the previous ML's remote roster/observer list so the council
        -- UI and eligibility checks immediately fall back to local data
        -- (auto-included leader/officers) until the new ML rebroadcasts.
        -- Without this, GetAllMembers() keeps returning the previous ML's
        -- council until SetRemoteRoster() runs again with new data.
        if Loothing.Council and Loothing.Council.ClearRemoteRoster then
            Loothing.Council:ClearRemoteRoster()
        end
        if Loothing.Observer and Loothing.Observer.ClearRemoteObserverList then
            Loothing.Observer:ClearRemoteObserverList()
        end
        Loothing:Debug("New ML detected:", ml, "- waiting for MLDB")
        return
    end

    -- If we're ML but not yet handling loot, decide whether to prompt for state
    -- handover from a previous ML, then run the usage-mode resolution.
    if isNowML and not Loothing.handleLoot then
        -- True handover: a different player previously held ML in this session.
        -- Show the inherit/discard prompt before any usage-mode decision so the
        -- new ML can choose whether to keep the old ML's MLDB/council/items
        -- or wipe them. This runs unconditionally on usageMode per requirements.
        local isHandover = oldML ~= nil
            and not Utils.IsSamePlayer(oldML, ml)
        if isHandover then
            -- If the modal is already up from a previous check, don't reset it.
            if GetPopups():IsShowing("LOOTHING_ML_HANDOVER_PROMPT") then
                Loothing:Debug("ML handover modal already open - skipping re-prompt")
                return
            end
            Loothing:Debug("ML handover detected:", oldML, "->", ml, "(self) - prompting")
            Loothing:PromptMLHandover(oldML, function()
                Loothing._ResolveMLUsageAfterHandover()
            end)
            return
        end

        Loothing._ResolveMLUsageAfterHandover()
    end
end

--- Resolve the post-ML-detection usage-mode flow (auto-start, prompt, or noop)
-- Extracted so the ML-handover prompt can defer to it after the user picks
-- Continue/Start Fresh. Behavior unchanged from the prior inline logic.
function Addon._ResolveMLUsageAfterHandover()
    if Loothing.handleLoot then return end
    if not Loothing.isMasterLooter then return end

    -- Respect an explicit decline for the rest of this ML stint.
    if Loothing.handleLootDeclined then
        Loothing:Debug("Skipping usage-mode resolve - user declined loot handling")
        return
    end

    -- Don't stack the usage-mode prompt under an open handover modal. The
    -- handover callback will call us back after the user resolves it.
    if GetPopups():IsShowing("LOOTHING_ML_HANDOVER_PROMPT") then
        Loothing:Debug("Skipping usage-mode resolve - handover modal is open")
        return
    end

    local usageMode = Loothing.Settings and Loothing.Settings:Get("ml.usageMode", "ask_gl") or "ask_gl"

    if usageMode == "never" then
        Loothing:Debug("ML detected but usage mode is 'never'")
        return
    end

    -- Instance type guard: skip ML handling in instances that the
    -- configured scope doesn't allow.
    local mlScope = Loothing.Settings and Loothing.Settings:Get("ml.scope", "raids_only") or "raids_only"
    if not Utils.IsEligibleForMLScope(mlScope) then
        Loothing:Debug("ML detected but instance not eligible for ml.scope =", mlScope)
        return
    end

    -- Guild-only restriction
    local guildOnly = Loothing.Settings and Loothing.Settings:Get("session.groupLootGuildOnly", false) or false
    if guildOnly and not Loothing.isInGuildGroup then
        Loothing:Debug("ML detected but not in guild group (guild-only mode)")
        return
    end

    if usageMode == "gl" then
        Loothing:Debug("ML detected, usage mode 'gl' - auto-starting loot handling")
        Loothing:StartHandleLoot()
        return
    end

    if usageMode == "ask_gl" then
        Loothing:Debug("ML detected, usage mode 'ask_gl' - prompting")
        GetPopups():Show("LOOTHING_ML_USAGE_PROMPT", nil, function()
            Loothing:StartHandleLoot()
        end, function()
            -- "No" must stick — otherwise the next roster event re-prompts.
            Loothing.handleLootDeclined = true
        end)
        return
    end
end

--[[--------------------------------------------------------------------
    ML Handover (Continue / Start Fresh prompt)

    When a new ML is detected and a different player previously held the
    role, the new ML is shown a Continue/Start Fresh prompt. Continue
    adopts the cached MLDB/council/session and rebroadcasts under the new
    identity (best-effort — if the new ML wasn't on the previous council
    they'll inherit only what was synced to them via MLDB broadcast).
    Start Fresh restores the new ML's pre-session settings, clears stale
    remote state, and broadcasts a clean slate.
----------------------------------------------------------------------]]

--- Build a short summary of what state will be inherited if Continue is chosen.
-- Used in the handover popup body. Returns nil if nothing notable is cached.
local function BuildHandoverInheritedSummary()
    local parts = {}
    if Loothing.Council and Loothing.Council.GetAllMembers then
        local members = Loothing.Council:GetAllMembers()
        if members and #members > 0 then
            parts[#parts + 1] = string.format(L["ML_HANDOVER_INHERITED_COUNCIL"], #members)
        end
    end
    if Loothing.MLDB and Loothing.MLDB.Get and Loothing.MLDB:Get() and next(Loothing.MLDB:Get()) ~= nil then
        parts[#parts + 1] = L["ML_HANDOVER_INHERITED_MLDB"]
    end
    if Loothing.Session and Loothing.Session.IsActive and Loothing.Session:IsActive()
        and Loothing.Session.GetItemCount and Loothing.Session:GetItemCount() > 0 then
        parts[#parts + 1] = string.format(L["ML_HANDOVER_INHERITED_ITEMS"], Loothing.Session:GetItemCount())
    end
    if #parts == 0 then return nil end
    return table.concat(parts, ", ")
end

--- Show the ML handover prompt (Continue / Start Fresh).
-- @param prevML string - Name of the previous ML
-- @param onResolved function - Called with no args after the user picks
function Addon:PromptMLHandover(prevML, onResolved)
    -- Hide any usage-mode prompt left over from a stale earlier check so it
    -- doesn't sit underneath the handover modal.
    GetPopups():Hide("LOOTHING_ML_USAGE_PROMPT")
    GetPopups():Hide("LOOTHING_ML_HANDOVER_PROMPT")

    local data = {
        previousML = Utils.GetShortName and Utils.GetShortName(prevML) or prevML,
        inheritedSummary = BuildHandoverInheritedSummary(),
    }

    GetPopups():Show("LOOTHING_ML_HANDOVER_PROMPT", data,
        function()
            -- Continue (button #1)
            local ok, err = pcall(function()
                Loothing:AcceptMLHandover(prevML)
            end)
            if not ok then
                Loothing:Error("AcceptMLHandover failed:", tostring(err))
            end
            if onResolved then onResolved() end
        end,
        function()
            -- Start Fresh (button #2)
            local ok, err = pcall(function()
                Loothing:RejectMLHandover(prevML)
            end)
            if not ok then
                Loothing:Error("RejectMLHandover failed:", tostring(err))
            end
            if onResolved then onResolved() end
        end
    )
end

--- Accept handover: keep cached MLDB/council/session state and rebroadcast
-- under our identity so observers re-anchor to us as the new ML.
-- @param prevML string|nil
function Addon:AcceptMLHandover(prevML)
    local me = Utils.NormalizeName(Utils.GetPlayerFullName())
    if not me then return end

    -- Seed prevML in MLDB's recent-senders table so any late STOP_HANDLE_LOOT
    -- or SESSION_END from them (queued under combat restrictions, network
    -- latency, etc.) authenticates locally via WasPreviousMLSender. Without
    -- this, a prevML who never broadcast a fresh MLDB to us before being
    -- demoted is unknown to the auth path.
    if prevML and self.MLDB then
        self.MLDB.recentMLDBSenders = self.MLDB.recentMLDBSenders or {}
        self.MLDB.recentMLDBSenders[Utils.NormalizeName(prevML)] = GetTime()
    end

    -- Mark ourselves authoritative without wiping cached state.
    self.masterLooter = me
    self.isMasterLooter = true
    self.mlStateVerified = true

    -- Clear an explicitMasterLooter that was inherited from the previous ML's
    -- MLDB push (MLDB.lua:747). Settings:GetMasterLooter() reads explicit first,
    -- so leaving it pointing at the previous ML breaks IsMasterLooter() and
    -- causes BroadcastStateRefresh() to short-circuit. We don't re-assert
    -- ourselves as explicit ML — fall through to raid-leader detection, which
    -- correctly identifies us since we are the leader.
    if self.explicitMasterLooter and prevML
        and Utils.IsSamePlayer(self.explicitMasterLooter, prevML) then
        self.explicitMasterLooter = nil
    end

    -- Promote the previous ML's remote council into our local persistent roster
    -- so subsequent edits go to SavedVariables. No-op if remote roster empty.
    if self.Council and self.Council.PromoteRemoteToLocal then
        self.Council:PromoteRemoteToLocal()
    end

    -- If a session is in flight (we previously received SESSION_INIT from prevML),
    -- re-stamp masterLooter and snapshot the reconnect cache so /reload won't lose it.
    if self.Session and self.Session.IsActive and self.Session:IsActive() then
        self.Session.masterLooter = me
        if self.CacheStateForReconnect then
            self:CacheStateForReconnect()
        end
    end

    -- Force-broadcast state forward (MLDB + council + observer + session bundle).
    -- BroadcastStateRefresh requires MLDB:IsML() = true — we just set
    -- isMasterLooter above, but its IsML() may have its own check; invalidate
    -- broadcast caches first so the next push is unconditional.
    if self.MLDB and self.MLDB.InvalidateBroadcastCache then
        self.MLDB:InvalidateBroadcastCache()
    end
    if self.Sync and self.Sync.InvalidateBroadcastCaches then
        self.Sync:InvalidateBroadcastCaches()
    end
    if self.Comm and self.Comm.InvalidateSessionStartCache then
        self.Comm:InvalidateSessionStartCache()
    end

    if self.Session and self.Session.BroadcastStateRefresh then
        local ok = self.Session:BroadcastStateRefresh()
        if not ok and self.MLDB and self.MLDB.BroadcastToRaid then
            -- Fallback: at minimum push our identity via MLDB
            self.MLDB:BroadcastToRaid(true)
        end
    elseif self.MLDB and self.MLDB.BroadcastToRaid then
        self.MLDB:BroadcastToRaid(true)
    end

    self:Print(string.format(L["ML_HANDOVER_CONTINUED"], prevML or "?"))
end

--- Reject handover: discard previous ML's cached state and broadcast our own
-- pre-session settings as a clean slate.
function Addon:RejectMLHandover(prevML)
    -- Seed prevML so their late farewell messages (STOP_HANDLE_LOOT,
    -- SESSION_END) still authenticate via WasPreviousMLSender. Reject means
    -- we don't honor their state going forward, but late comms in flight
    -- shouldn't be silently dropped — they may be needed for state coherence
    -- on intermediate observers who haven't received our broadcast yet.
    if prevML and self.MLDB then
        self.MLDB.recentMLDBSenders = self.MLDB.recentMLDBSenders or {}
        self.MLDB.recentMLDBSenders[Utils.NormalizeName(prevML)] = GetTime()
    end

    -- End any orphaned session locally (drops items/candidates).
    -- Session.masterLooter is still pointing at the previous ML at this point;
    -- re-stamp it to ourselves so EndSession() captures wasML=true at line 1148
    -- and broadcasts SESSION_END to observers — without this, observers keep
    -- seeing the old ML's session because no authoritative end signal arrived.
    if self.Session and self.Session.IsActive and self.Session:IsActive() then
        local me = Utils.NormalizeName(Utils.GetPlayerFullName())
        if me then
            self.Session.masterLooter = me
        end
        if self.Session.EndSession then
            self.Session:EndSession()
        end
    end

    -- EndSession() conditionally nils Loothing.masterLooter / isMasterLooter
    -- (Session.lua:1198-1201, gated on `not Loothing.handleLoot`). Re-assert
    -- them so the ML gate in RefreshLocalSettingsAndBroadcast / IsCanonicalML
    -- passes regardless of which branch ran.
    local me = Utils.NormalizeName(Utils.GetPlayerFullName())
    if me then
        self.masterLooter = me
        self.isMasterLooter = true
        self.mlStateVerified = true
    end

    -- Restore preSessionSnapshot + clear remote rosters in-process WITHOUT
    -- the per-channel broadcasts RefreshLocalSettingsAndBroadcast issues.
    -- Reasons we don't just call that helper:
    --   1. We want a single SESSION_INIT for ordering (MLDB-before-roster
    --      authorization on receivers).
    --   2. We want our own settings broadcast, not the previous ML's.
    if self.MLDB and self.MLDB.RestoreSettings then
        self.MLDB:RestoreSettings()  -- pre-session snapshot back to live Settings
    end

    -- Re-assert ML state after RestoreSettings (which may have rewritten
    -- explicitMasterLooter to the original pre-session value, which was nil
    -- on a typical "started as ML" snapshot — safe).
    if me then
        self.masterLooter = me
        self.isMasterLooter = true
        self.mlStateVerified = true
    end

    if self.Council and self.Council.ClearRemoteRoster then
        self.Council:ClearRemoteRoster()
    end
    if self.Observer and self.Observer.ClearRemoteObserverList then
        self.Observer:ClearRemoteObserverList()
    end

    -- Invalidate caches so the upcoming bundled broadcast is unconditional.
    if self.MLDB and self.MLDB.InvalidateBroadcastCache then
        self.MLDB:InvalidateBroadcastCache()
    end
    if self.Sync and self.Sync.InvalidateBroadcastCaches then
        self.Sync:InvalidateBroadcastCaches()
    end
    if self.Comm and self.Comm.InvalidateSessionStartCache then
        self.Comm:InvalidateSessionStartCache()
    end

    -- Bundled SESSION_INIT (MLDB → council → observer in one message)
    -- gives receivers the right ordering: MLDB's settings.masterLooter
    -- refines our identity before the council/observer authorization runs.
    -- BroadcastStateRefresh skips sessionStart when no session is active,
    -- which is correct here — we just ended any orphaned session above.
    if self.Session and self.Session.BroadcastStateRefresh then
        local ok = self.Session:BroadcastStateRefresh()
        if not ok and self.MLDB and self.MLDB.BroadcastToRaid then
            -- Fallback: at minimum push our identity via MLDB
            self.MLDB:BroadcastToRaid(true)
        end
    elseif self.MLDB and self.MLDB.BroadcastToRaid then
        self.MLDB:BroadcastToRaid(true)
    end

    self:Print(L["ML_HANDOVER_FRESH"])
end

--- Schedule an ML check with configurable delay (debounced with ceiling).
-- @param delay number|nil - Delay in seconds (default 2). Use 0.5 for explicit handoffs.
local mlCheckScheduledAt = nil
local function ScheduleMLCheck(delay)
    local now = GetTime()
    -- Debounce ceiling: if a timer has been pending >1.5s, let it fire rather than
    -- resetting. This caps roster-storm delays to ~3.5s (initial 2s + 1.5s of resets).
    if mlCheckTimer and mlCheckScheduledAt and (now - mlCheckScheduledAt) > 1.5 then
        -- Still cancel any in-flight retry chain so it doesn't race with the pending timer
        if mlRetryTimer then
            mlRetryTimer:Cancel()
            mlRetryTimer = nil
        end
        mlRetryCount = 0
        return
    end
    if mlCheckTimer then
        mlCheckTimer:Cancel()
    end
    -- Cancel any in-flight retry chain to prevent parallel retry races
    if mlRetryTimer then
        mlRetryTimer:Cancel()
        mlRetryTimer = nil
    end
    mlRetryCount = 0
    local d = delay or 2
    mlCheckScheduledAt = now
    mlCheckTimer = C_Timer.NewTimer(d, function()
        mlCheckScheduledAt = nil
        PerformMLCheck()
    end)
end

-- Expose for slash commands and RosterPanel after ML reassignment
Loothing.ScheduleMLCheck = ScheduleMLCheck

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
    if Utils.IsInPvPOrScenario() then return end

    local mlScope = Loothing.Settings and Loothing.Settings:Get("ml.scope", "raids_only") or "raids_only"
    if not Utils.IsEligibleForMLScope(mlScope) then
        return
    end

    if Loothing.handleLoot then return end
    -- Instance entry must not override an explicit decline either.
    if Loothing.handleLootDeclined then return end
    if not UnitIsGroupLeader("player") then
        ScheduleMLCheck()
        return
    end

    local guildOnly = Loothing.Settings and Loothing.Settings:Get("session.groupLootGuildOnly", false) or false
    if guildOnly and not Utils.IsGuildGroup() then return end

    GetPopups():Hide("LOOTHING_ML_USAGE_PROMPT")

    if usageMode == "gl" then
        Loothing.isMasterLooter = true
        Loothing.masterLooter = Utils.GetPlayerFullName()
        Loothing:StartHandleLoot()
    elseif usageMode == "ask_gl" then
        local instanceName = select(1, GetInstanceInfo())
        GetPopups():Show("LOOTHING_ML_USAGE_PROMPT",
            { instance = instanceName },
            function()
                Loothing.isMasterLooter = true
                Loothing.masterLooter = Utils.GetPlayerFullName()
                Loothing:StartHandleLoot()
            end,
            function()
                -- "No" must stick for this ML stint (see handleLootDeclined).
                Loothing.handleLootDeclined = true
                Loothing:Print(L["ML_NOT_ACTIVE_SESSION"])
            end
        )
    end
end

--[[--------------------------------------------------------------------
    Loot Handling
----------------------------------------------------------------------]]

--- Start handling loot (broadcast to group)
-- Called when we become ML and usage mode permits
function Addon:StartHandleLoot()
    if self.handleLoot then return end

    self.handleLoot = true
    self.handleLootDeclined = false
    self.mlStateVerified = true
    self:Debug("StartHandleLoot - now handling loot")
    self:Print(L["ML_HANDLING_LOOT"])

    -- Broadcast MLDB settings first (so candidates know our config).
    -- force=true because this is an ML-state transition — a stale cache from
    -- a previous ML stint with identical settings would silently suppress the
    -- initial push to the new audience.
    if self.MLDB then
        self.MLDB:BroadcastToRaid(true)
    end

    -- Broadcast council roster
    if self.Council and self.Comm then
        local members = self.Council:GetAllMembers()
        self.Comm:BroadcastCouncilRoster(members)
    end

    -- Send version check to group
    local versionCheck = GetVersionCheck()
    if versionCheck and versionCheck.Query then
        versionCheck:Query("raid")
    end

    -- Enable whisper command handler
    if self.WhisperHandler then
        self.WhisperHandler:Enable()
    end
end

--- Stop handling loot (broadcast to group)
-- Ends any active session and notifies the group
function Addon:StopHandleLoot()
    if not self.handleLoot then return end

    self.handleLoot = false
    self:Debug("StopHandleLoot - no longer handling loot")
    self:Print(L["ML_STOPPED_HANDLING"])

    -- Broadcast to group that ML stopped handling loot
    if self.Comm and self.Comm.BroadcastStopHandleLoot then
        self.Comm:BroadcastStopHandleLoot()
    elseif self.Comm and self.Comm.Send then
        self.Comm:Send(Loothing.MsgType.STOP_HANDLE_LOOT, {})
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

--- Toggle handle-loot state without ending the session.
-- Unlike StartHandleLoot/StopHandleLoot, this is a soft toggle:
-- turning OFF stops auto-rolling but does NOT end the session or
-- broadcast STOP_HANDLE_LOOT (which clears MLDB on clients).
-- @param enabled boolean
function Addon:SetHandleLoot(enabled)
    if enabled then
        self:StartHandleLoot()
    else
        self.handleLoot = false
        -- Explicit user opt-out: latch it so ML re-detection doesn't
        -- auto-re-enable ('gl') or re-prompt ('ask_gl') on the next
        -- roster event.
        self.handleLootDeclined = true
        self:Debug("SetHandleLoot(false) - soft disable, session preserved")
        self:Print(L["HANDLE_LOOT_DISABLED"])

        -- Re-broadcast MLDB with handleLoot=false so clients stop auto-passing
        if self.MLDB and self.MLDB:IsML() then
            self.MLDB:BroadcastToRaid()
        end
    end
end

--[[--------------------------------------------------------------------
    Event Registration
----------------------------------------------------------------------]]

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
            -- ML path: StopHandleLoot ends session, broadcasts, and clears MLDB
            Loothing:StopHandleLoot()
        elseif Loothing.Session and Loothing.Session:IsActive() then
            -- Non-ML path: end the remote session (no broadcast — we just left)
            Loothing.Session:EndSession()
        end

        Loothing.isMasterLooter = false
        Loothing.masterLooter = nil
        Loothing.isInGuildGroup = false
        Loothing.lootMethod = nil

        -- Clear MLDB when leaving group (also restores non-ML settings if needed).
        -- For the ML path, StopHandleLoot already called Clear(); this is a no-op.
        -- For non-ML, OnSessionEnded callback above already called Clear(); this is a no-op.
        -- This remains as a safety net in case neither path triggered (e.g. no active session).
        if Loothing.MLDB then
            Loothing.MLDB:Clear()
        end

        -- Clear explicitMasterLooter AFTER MLDB:Clear() so RestoreSettings() isn't overridden.
        -- When leaving a group, no explicit ML should persist regardless.
        Loothing.explicitMasterLooter = nil

        -- Dismiss any pending ML prompts (usage + handover)
        GetPopups():Hide("LOOTHING_ML_USAGE_PROMPT")
        GetPopups():Hide("LOOTHING_ML_HANDOVER_PROMPT")
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
        local versionCheck = GetVersionCheck()
        if versionCheck then
            versionCheck:OnGroupRosterUpdate()
        end
        -- Re-broadcast ML state when roster changes so new members get full
        -- context. Without this, members who join after StartHandleLoot never
        -- receive MLDB and won't auto-pass group loot items for the ML.
        -- Debounced: GROUP_ROSTER_UPDATE fires frequently in raids.
        --
        -- Pre-2.0.43 sent four separate broadcasts here (SESSION_START + MLDB
        -- + COUNCIL_ROSTER + OBSERVER_ROSTER). Each was payload-only-dirty-
        -- checked but routinely went out anyway because the audience had
        -- changed. In a 19-raid with people resurrecting / vehicling / etc.,
        -- 16+ roster shifts × 4 messages was a 64-message amplification on
        -- the queue. Now collapsed into a single SESSION_INIT carrying every
        -- field — the receiver fans out into the same handlers, so behavior
        -- is unchanged but the wire footprint is ~75% smaller.
        if Loothing.handleLoot and Loothing.MLDB and Loothing.MLDB:IsML() then
            if mldbRosterTimer then mldbRosterTimer:Cancel() end
            mldbRosterTimer = C_Timer.NewTimer(3, function()
                mldbRosterTimer = nil
                if not (Loothing.handleLoot and Loothing.MLDB and Loothing.MLDB:IsML()) then
                    return
                end

                local session = Loothing.Session
                if session and session.BroadcastStateRefresh then
                    session:BroadcastStateRefresh()
                else
                    -- Fallback path if the helper isn't available (loading
                    -- order safety net): preserve legacy behavior.
                    Loothing.MLDB:BroadcastToRaid(true)
                    if session and session:IsActive() and session.sessionID then
                        Loothing.Comm:BroadcastSessionStart(
                            session.encounterID,
                            session.encounterName,
                            session.sessionID,
                            true
                        )
                    end
                    if Loothing.Sync then
                        Loothing.Sync:BroadcastCouncilRoster(true)
                        Loothing.Sync:BroadcastObserverRoster(true)
                    end
                end
            end)
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

    -- BOSS_KILL was previously hooked to a no-op `Session:OnBossKill`
    -- alongside ENCOUNTER_END. Removed in 2.0.29 — ENCOUNTER_END is the
    -- canonical "boss died successfully" signal for every encounter in
    -- 12.0 and carries the success flag + encounter metadata we rely on.
    -- Re-add only if a specific encounter is found to fire BOSS_KILL
    -- without a matching ENCOUNTER_END.

    -- Loot events
    Events.Registry:RegisterEventCallback("ENCOUNTER_LOOT_RECEIVED", function(_, encounterID, itemID, itemLink, quantity, playerName, className)
        if Loothing.Session then
            Loothing.Session:OnLootReceived(encounterID, itemID, itemLink, quantity, playerName, className)
        end
    end, Loothing)

    -- Personal loot tracking (logs items received outside of council sessions)
    Events.Registry:RegisterEventCallback("CHAT_MSG_LOOT", function(_, msg, _, _, _, playerName2)
        -- Only proceed if setting is enabled
        if not (Loothing.Settings and Loothing.Settings:Get("history.savePersonalLoot", false)) then
            return
        end

        -- Skip if a council session is actively handling loot
        if Loothing.Session then
            local state = Loothing.Session:GetState()
            if state == Loothing.SessionState.ACTIVE or state == Loothing.SessionState.CLOSED then
                return
            end
        end

        -- CHAT_MSG_LOOT payloads (msg, looter name) are secret-tagged on
        -- tainted execution paths during raid combat. Any :match / ~= "" /
        -- string op on a secret throws — drop the event rather than abort.
        if SecretUtil.IsSecretValue(msg, playerName2) then return end

        -- Only track loot the player receives (not others)
        local myName = Utils.GetPlayerFullName()
        if not myName then return end

        -- Match "You receive loot: |cff...|Hitem:...|h[...]|h|r" pattern
        local itemLink = msg and msg:match("|c.-|Hitem:.-|h.-|h|r")
        if not itemLink then return end

        -- Only log items the player themselves received
        if playerName2 and playerName2 ~= "" and not Utils.IsSamePlayer(playerName2, myName) then
            return
        end

        -- Get instance info for context
        local instanceName, _, difficultyID, difficultyName, _, _, _, mapID = GetInstanceInfo()

        if Loothing.History then
            Loothing.History:AddEntry({
                itemLink       = itemLink,
                winner         = myName,
                source         = "personal",
                instance       = instanceName,
                difficultyID   = difficultyID,
                difficultyName = difficultyName,
                mapID          = mapID,
                timestamp      = time(),
            })
        end
    end, Loothing)

    -- NOTE: CHAT_MSG_ADDON is handled by Loolib.Comm (registered in CommMixin:Init)

    -- Wire VersionCheck callbacks to Comm events
    local versionCheck = GetVersionCheck()
    if Loothing.Comm and versionCheck then
        Loothing.Comm:RegisterCallback("OnVersionRequest", function(_, data)
            versionCheck:HandleRequest(data.requester, data.distribution)
        end, Loothing)

        Loothing.Comm:RegisterCallback("OnVersionResponse", function(_, data)
            versionCheck:HandleResponse(data.version, data.sender, data.tVersion, data.ilvl, data.specID)
        end, Loothing)
    end

    -- Wire StopHandleLoot callback to clear stale ML state on clients
    if Loothing.Comm then
        Loothing.Comm:RegisterCallback("OnStopHandleLoot", function(_, data)
            if data and data.masterLooter then
                if Utils.IsSamePlayer(data.masterLooter, Loothing.masterLooter or "") then
                    Loothing.handleLoot = false
                    Loothing.masterLooter = nil
                    Loothing.isMasterLooter = false
                    -- Restore non-ML settings from pre-session snapshot
                    if Loothing.MLDB then
                        Loothing.MLDB:Clear()
                    end
                end
            end
        end, Loothing)
    end

    -- Re-run ML detection when MLDB changes the designated Master Looter.
    -- This handles the case where the old ML transfers ML to us via /lt ml set:
    -- the MLDB arrives (setting explicitMasterLooter to our name) but no roster
    -- event fires, so we'd never notice we became ML without this.
    if Loothing.MLDB then
        Loothing.MLDB:RegisterCallback("OnMLDBApplied", function(_, data)
            if data and data.settings and data.settings.masterLooter then
                local newML = data.settings.masterLooter
                local currentML = Loothing.masterLooter
                local playerName = Utils.GetPlayerFullName()
                local becameLocalML = playerName and Utils.IsSamePlayer(newML, playerName)
                -- Note: Session.masterLooter is already propagated inside
                -- ApplyFromML() (MLDB.lua:587-589) before this callback fires.
                if becameLocalML and not Loothing.isMasterLooter then
                    Loothing:Debug("MLDB assigned us as ML - scheduling ML check")
                    ScheduleMLCheck(0.5)
                elseif not currentML or not Utils.IsSamePlayer(newML, currentML) then
                    Loothing:Debug("MLDB changed ML to", newML, "- scheduling ML check")
                    ScheduleMLCheck(0.5)
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

    -- Wire incoming history entries from group/guild broadcasts
    if Loothing.History and Loothing.Comm then
        Loothing.Comm:RegisterCallback("OnHistoryEntry", function(_, data)
            -- Don't re-add our own entries (ML already added locally)
            if data.sender and Utils.IsSamePlayer(data.sender, Utils.GetPlayerFullName()) then
                return
            end
            Loothing.History:AddEntry(data)
        end, Loothing)
    end

    -- Wire Session award → TradeQueue (only for items the local player looted)
    if Loothing.Session and Loothing.TradeQueue then
        Loothing.Session:RegisterCallback("OnItemAwarded", function(_, item, winner)
            if item.looter and Utils.IsSamePlayer(item.looter, Utils.GetPlayerFullName()) then
                -- Skip self-awards: no trade needed if the looter IS the winner
                if not Utils.IsSamePlayer(winner, Utils.GetPlayerFullName()) then
                    Loothing.TradeQueue:AddToQueue(item.guid, item.itemLink, winner, item.timestamp)
                end
            end
        end, Loothing)
    end

    -- Auto-show Web export when session ends (opt-in setting)
    -- Trade tab takes priority over web export when items are pending.
    if Loothing.Session then
        Loothing.Session:RegisterCallback("OnSessionEnded", function()
            if Loothing.Settings:Get("history.autoExportWeb")
                and Loothing.History
                and Loothing.History:GetFilteredCount() > 0
                and Loothing.MainFrame then
                local hasPendingTrades = Loothing.TradeQueue
                    and #Loothing.TradeQueue:GetAllPending() > 0
                if not hasPendingTrades then
                    Loothing.MainFrame:Show()
                    Loothing.MainFrame:SelectTab("history")
                    local historyPanel = Loothing.MainFrame:GetHistoryPanel()
                    if historyPanel then
                        historyPanel:ShowWebExport()
                    end
                end
            end
        end, Loothing)
    end

    -- NOTE: MLDB:Clear and Sync:CancelPendingBroadcasts used to be wired
    -- through OnSessionEnded callbacks here. Session:EndSession now calls
    -- them synchronously (Data/Session.lua) BEFORE firing OnSessionEnded,
    -- so other OnSessionEnded handlers see the restored settings and the
    -- drained sync timers. Re-adding them here would re-introduce the race
    -- where MLDB:Clear runs after a newly-applied session-2 MLDB and
    -- clobbers it back to the previous session's baseline.

    -- Wire Announcer to Session events (session start, end, item added, voting started).
    -- Broadcast-to-raid announcements must fire on the ML only — OnSessionStarted /
    -- OnSessionEnded fire on every candidate too via HandleRemoteSessionStart /
    -- HandleRemoteSessionEnd, which would otherwise produce N duplicate raid messages.
    if Loothing.Session and Loothing.Announcer then
        Loothing.Session:RegisterCallback("OnSessionStarted", function(_, _sessionID, _encounterID, encounterName)
            if not Loothing.Session:IsMasterLooter() then return end
            Loothing.Announcer:AnnounceSessionStart(encounterName)
        end, Loothing)

        Loothing.Session:RegisterCallback("OnSessionEnded", function(_, _sessionID, wasML)
            -- wasML is captured before the ML identity is cleared in EndSession;
            -- IsMasterLooter() at this point falls back to canonical-ML (raid
            -- leader) which misidentifies ML-not-leader setups.
            if not wasML then return end
            Loothing.Announcer:AnnounceSessionEnd()
        end, Loothing)

        -- ML-only, like OnSessionStarted above: both events also fire on every
        -- RECEIVING client (HandleRemoteItemAdd / HandleRemoteVoteRequest), and
        -- MLDB pushes the ML's announcement toggles into every raid member's
        -- local settings — without the gate the whole raid re-announced each
        -- item ("X is considering Y" ×N per item).
        Loothing.Session:RegisterCallback("OnItemAdded", function(_, item)
            if not Loothing.Session:IsMasterLooter() then return end
            if item and item.itemLink then
                Loothing.Announcer:AnnounceItem(item.itemLink, {
                    itemLevel = item.itemLevel,
                    itemType = item.itemType,
                    session = Loothing.Session.encounterName,
                })
            end
        end, Loothing)

        Loothing.Session:RegisterCallback("OnVotingStarted", function(_, item)
            if not Loothing.Session:IsMasterLooter() then return end
            if item and item.itemLink then
                Loothing.Announcer:AnnounceConsiderations(item.itemLink, {
                    itemLevel = item.itemLevel,
                    itemType = item.itemType,
                    session = Loothing.Session.encounterName,
                })
            end
        end, Loothing)
    end

    -- NOTE: CHAT_MSG_SYSTEM for roll tracking is registered by RollTracker:Init()
    -- NOTE: Trade window events (TRADE_SHOW, TRADE_CLOSED, TRADE_ACCEPT_UPDATE, UI_INFO_MESSAGE)
    -- are registered internally by TradeQueue:RegisterEvents()
end

--[[--------------------------------------------------------------------
    Slash Commands
----------------------------------------------------------------------]]

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
            printError(L["SLASH_NO_MAINFRAME"])
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
            printError(L["SLASH_NO_CONFIG"])
            return
        end

        local path = ns.Options and ns.Options.ResolveOptionsPath and ns.Options.ResolveOptionsPath(section) or nil
        if path and #path > 0 then
            Config:Open("Loothing", unpack(path))
        else
            Config:Open("Loothing")
        end
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

        local itemID = Utils.GetItemID(itemLink)
        if not itemID then
            printError(L["SLASH_INVALID_ITEM"])
            return
        end

        local itemName = Utils.GetItemName(itemLink) or "Item"
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
            local explicit = Loothing.explicitMasterLooter
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
            local canModify = Loothing.Settings:IsMasterLooter() or Utils.IsRaidLeader()
            if not canModify then
                printError(L["ERROR_NOT_ML_OR_RL"])
                return
            end
            -- Broadcast MLDB before clearing (we still have authority)
            Loothing.explicitMasterLooter = nil
            if Loothing.MLDB then
                Loothing.MLDB:BroadcastToRaid(true)
            end
            -- Revert global ML to raid leader (will be finalized by PerformMLCheck)
            Loothing.masterLooter = Utils.GetRaidLeader()
            ScheduleMLCheck(0.5)  -- Fast check for explicit clear
            printLine(L["ML_CLEARED"])
            return
        end

        local canModify = Loothing.Settings:IsMasterLooter() or Utils.IsRaidLeader()
        if not canModify then
            printError(L["ERROR_NOT_ML_OR_RL"])
            return
        end

        -- Check if target has Loothing installed (soft check, allow force override)
        local isForce = argText:match("%s+force%s*$")
        local cleanName = argText:gsub("%s+force%s*$", "")
        local versionCheck = GetVersionCheck()
        if versionCheck and not isForce then
            local targetNorm = Utils.NormalizeName(cleanName)
            local entry = versionCheck.versionCache and versionCheck.versionCache[targetNorm]
            if not entry or not entry.version then
                printError(targetNorm .. " doesn't appear to have Loothing installed.")
                printError("Use '/lt ml " .. cleanName .. " force' to override.")
                return
            end
        end
        if isForce then
            argText = cleanName
        end

        -- Set the new explicit ML and broadcast while we still have authority
        Loothing.explicitMasterLooter = Utils.NormalizeName(argText)
        if Loothing.MLDB then
            Loothing.MLDB:BroadcastToRaid(true)
        end

        -- Immediately update global ML identity (don't wait 2s for PerformMLCheck)
        Loothing.masterLooter = Loothing.explicitMasterLooter

        -- If WE were ML and just assigned someone else, stop handling immediately
        local playerName = Utils.GetPlayerFullName()
        if Loothing.handleLoot and not Utils.IsSamePlayer(Loothing.explicitMasterLooter, playerName) then
            Loothing:StopHandleLoot()
        end

        ScheduleMLCheck(0.5)  -- Fast check for explicit handoff
        printLine(string.format(L["ML_ASSIGNED"], argText))

        -- Warn if assigning ML outside a raid with raids-only scope active
        if Loothing.Settings:Get("ml.scope", "raids_only") == "raids_only" and not Utils.IsInRaidInstance() then
            printLine(L["ML_ASSIGNED_OUTSIDE_RAID_WARNING"])
        end
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
                printError(L["SLASH_SYNC_UNAVAILABLE"])
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
                printError(L["SLASH_SYNC_UNAVAILABLE"])
            end
            return
        end

        -- No sub-command: open the Sync Panel dialog
        if Loothing.UI and Loothing.UI.SyncPanel then
            Loothing.UI.SyncPanel:Show()
        else
            printLine("Sync commands:")
            printLine("  /lt sync settings [guild|player] - Sync settings")
            printLine("  /lt sync history [guild|player] [days] - Sync history")
        end
    end

    local function handleImport(argText)
        if not Loothing.HistoryImport then
            printError(L["SLASH_IMPORT_UNAVAILABLE"])
            return
        end

        local text = argText or ""
        if text == "" then
            printLine(L["SLASH_IMPORT_PROMPT"])
            return
        end

        local entries, err = Loothing.HistoryImport:DetectFormat(text)
        if not entries then
            printError(string.format(L["SLASH_IMPORT_PARSE_ERROR"], err or "unknown"))
            return
        end

        local success, importErr = Loothing.HistoryImport:ImportEntries(entries, false)
        if success then
            local stats = Loothing.HistoryImport:GetImportStats() or {}
            local imported = stats.imported or #entries
            printLine(string.format(L["SLASH_IMPORT_SUCCESS"], imported))
        else
            printError(string.format(L["SLASH_IMPORT_FAILED"], importErr or "unknown"))
        end
    end

    local function handleShare(argText)
        local subCmd, target = argText:match("^(%S*)%s*(%S*)$")
        subCmd = subCmd and subCmd:lower() or ""
        target = target and target:lower() or ""

        if subCmd == "intel" then
            if not Loothing.IntelShare then
                printError(L["INTEL_SHARE_NO_DATA"])
                return
            end
            if target == "" then
                target = "group"
            end
            local ok, err = Loothing.IntelShare:StartShare(target)
            if not ok then
                printError(err)
            end
            return
        end

        if subCmd == "purge" then
            if Loothing.IntelShare then
                Loothing.IntelShare:PurgeSharedData()
            else
                printError(L["INTEL_PURGE_NOTHING"])
            end
            return
        end

        if subCmd == "status" then
            if Loothing.IntelShare then
                Loothing.IntelShare:PrintStatus()
            else
                printError(L["INTEL_SHARE_NO_DATA"])
            end
            return
        end

        -- No sub-command: open the Sync Panel on the Intel tab
        if Loothing.UI and Loothing.UI.SyncPanel then
            Loothing.UI.SyncPanel.syncType = "intel"
            Loothing.UI.SyncPanel:UpdateUI()
            Loothing.UI.SyncPanel:Show()
        else
            printLine("Share commands:")
            printLine("  /lt share intel [group|guild] - Share desktop intel")
            printLine("  /lt share purge - Remove received shared intel")
            printLine("  /lt share status - Show desktop intel status")
        end
    end

    local function requireDebug(commandName)
        if isDebugEnabled() then
            return true
        end
        printError(string.format(L["SLASH_DEBUG_REQUIRED"], commandName or "this command"))
        return false
    end

    local function handleMLDBCommand(args)
        local action = strtrim(args or ""):lower()
        if action ~= "" and action ~= "refresh" and action ~= "reload" and action ~= "broadcast" then
            printLine("Usage: /lt mldb refresh")
            printLine("  Restores the current ML's local settings and broadcasts MLDB to the group.")
            return
        end

        if not IsInGroup() then
            printError(L["MLDB_REFRESH_NOT_GROUPED"] or "Must be in a group to broadcast MLDB settings.")
            return
        end

        if not (Loothing.MLDB and Loothing.MLDB.RefreshLocalSettingsAndBroadcast) then
            printError(L["MLDB_REFRESH_UNAVAILABLE"] or "MLDB module not available.")
            return
        end

        local ok, reason, details = Loothing.MLDB:RefreshLocalSettingsAndBroadcast()
        if not ok then
            if reason == "not_ml" then
                printError(L["MLDB_REFRESH_NOT_ML"] or "Only the current Master Looter can refresh and broadcast MLDB settings.")
            else
                printError(L["MLDB_REFRESH_FAILED"] or "Failed to refresh MLDB settings.")
            end
            return
        end

        if details and details.restoredSnapshot then
            printLine(L["MLDB_REFRESH_RESTORED"] or "Restored your local settings before broadcasting.")
        end
        printLine(L["MLDB_REFRESH_SENT"] or "Broadcast your MLDB settings to the group.")
    end

    local commands = {
        {
            key = "show",
            aliases = { "open" },
            description = L["SLASH_DESC_SHOW"],
            usage = { "/lt", "/lt show" },
            handler = function()
                ensureMainFrame()
            end,
        },
        {
            key = "hide",
            description = L["SLASH_DESC_HIDE"],
            usage = { "/lt hide" },
            handler = function()
                if Loothing.MainFrame then
                    Loothing.MainFrame:Hide()
                else
                    printError(L["SLASH_NO_MAINFRAME"])
                end
            end,
        },
        {
            key = "toggle",
            description = L["SLASH_DESC_TOGGLE"],
            usage = { "/lt toggle" },
            handler = function()
                if not Loothing.MainFrame then
                    printError(L["SLASH_NO_MAINFRAME"])
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
            description = L["SLASH_DESC_CONFIG"],
            usage = { "/lt config", "/lt config council" },
            handler = function(args)
                openConfig(args ~= "" and args or nil)
            end,
        },
        {
            key = "history",
            description = L["SLASH_DESC_HISTORY"],
            usage = { "/lt history" },
            handler = function()
                ensureMainFrame("history")
            end,
        },
        {
            key = "council",
            description = L["SLASH_DESC_COUNCIL"],
            usage = { "/lt council" },
            handler = function()
                openConfig("council")
            end,
        },
        {
            key = "ml",
            description = L["SLASH_DESC_ML"],
            usage = { "/lt ml", "/lt ml <name>", "/lt ml clear" },
            handler = function(args)
                handleMasterLooter(args or "")
            end,
        },
        {
            key = "mldb",
            aliases = { "mlsync" },
            description = L["SLASH_DESC_MLDB"] or "Refresh and broadcast Master Looter settings",
            usage = { "/lt mldb refresh", "/lt mlsync" },
            handler = function(args)
                handleMLDBCommand(args or "")
            end,
        },
        {
            key = "start",
            aliases = { "activate", "enable" },
            description = L["SLASH_DESC_START"],
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
                if not UnitIsGroupLeader("player") and not Loothing.isMasterLooter and not UnitIsGroupAssistant("player") then
                    printError("Only the group/raid leader, assistant, or Master Looter can activate loot handling.")
                    return
                end
                Loothing.isMasterLooter = true
                Loothing.masterLooter = Utils.GetPlayerFullName()
                Loothing:StartHandleLoot()
            end,
        },
        {
            key = "stop",
            aliases = { "deactivate", "disable" },
            description = L["SLASH_DESC_STOP"],
            usage = { "/lt stop" },
            handler = function()
                if Loothing.handleLoot then
                    Loothing:StopHandleLoot()
                    -- Explicit user stop — don't re-prompt/auto-re-enable
                    -- on the next roster event.
                    Loothing.handleLootDeclined = true
                    printLine("Stopped handling loot.")
                else
                    printLine("Not currently handling loot.")
                end
            end,
        },
        {
            key = "roll",
            aliases = { "respond" },
            description = "Reopen the loot response frame for unresponded items",
            usage = { "/lt roll", "/lt respond" },
            handler = function()
                local tracker = Loothing.ResponseTracker
                if not tracker or tracker:GetUnrespondedCount() == 0 then
                    printLine("No items awaiting response.")
                    return
                end
                if InCombatLockdown() then
                    printLine("Cannot reopen frame during combat. It will appear when combat ends.")
                    return
                end
                tracker:CheckAndReshowFrame()
            end,
        },
        {
            key = "vote",
            aliases = { "ct" },
            description = L["SLASH_DESC_VOTE"],
            usage = { "/lt vote", "/lt ct" },
            handler = function()
                local ct = Loothing.UI and Loothing.UI.CouncilTable
                if not ct then
                    printError("Council table not available.")
                    return
                end
                if not Loothing.Session or not Loothing.Session:IsActive() then
                    printLine("No active session.")
                    return
                end
                ct:Toggle()
            end,
        },
        {
            key = "reopen",
            description = L["SLASH_DESC_REOPEN"],
            usage = { "/lt reopen response", "/lt reopen council", "/lt reopen award" },
            handler = function(args)
                local sub = (args or ""):lower():match("^(%S+)") or ""

                if sub == "response" or sub == "respond" or sub == "roll" then
                    local tracker = Loothing.ResponseTracker
                    if not tracker or tracker:GetUnrespondedCount() == 0 then
                        printLine("No items awaiting response.")
                        return
                    end
                    if InCombatLockdown() then
                        printLine("Cannot reopen frame during combat. It will appear when combat ends.")
                        return
                    end
                    tracker:CheckAndReshowFrame()

                elseif sub == "council" or sub == "vote" then
                    local ct = Loothing.UI and Loothing.UI.CouncilTable
                    if not ct then
                        printError("Council table not available.")
                        return
                    end
                    if not Loothing.Session or not Loothing.Session:IsActive() then
                        printLine("No active session.")
                        return
                    end
                    ct:Show()

                elseif sub == "award" or sub == "session" or sub == "trade" then
                    if not Loothing.Session or not Loothing.Session:IsActive() then
                        printLine("No active session.")
                        return
                    end
                    ensureMainFrame("session")

                else
                    printLine("Usage: /lt reopen {response, council, award}")
                    printLine("  response — Reopen loot response frame")
                    printLine("  council  — Reopen council voting table")
                    printLine("  award    — Reopen session/award panel")
                end
            end,
        },
        {
            key = "resync",
            description = L["SLASH_DESC_RESYNC"],
            usage = { "/lt resync" },
            handler = function()
                if not Loothing.Session or not Loothing.Session:IsActive() then
                    printError(L["RESYNC_NO_SESSION"])
                    return
                end
                if Loothing.Session:IsMasterLooter() then
                    printError(L["RESYNC_IS_ML"])
                    return
                end
                local ml = Loothing.Session:GetMasterLooter()
                if not ml then
                    printError(L["RESYNC_NO_ML"])
                    return
                end
                if not Loothing.Sync then
                    printError(L["RESYNC_NO_SYNC"])
                    return
                end

                -- Trash local session state
                local sessionID = Loothing.Session:GetSessionID()
                Loothing.Session:EndSession()

                -- Clear ResponseTracker so we re-receive everything fresh
                if Loothing.ResponseTracker then
                    Loothing.ResponseTracker:Clear()
                end

                -- Request full sync from ML
                printLine(string.format(L["RESYNC_STARTED"], ml))
                Loothing.Sync:RequestSync(ml)
            end,
        },
        {
            key = "resend",
            description = "Resend your loot response(s) to the Master Looter",
            usage = { "/lt resend" },
            handler = function()
                if not Loothing.Session or Loothing.Session:GetState() == Loothing.SessionState.INACTIVE then
                    printError("No active session.")
                    return
                end
                local tracker = Loothing.ResponseTracker
                if not tracker then
                    printError("No responses to resend.")
                    return
                end
                local ml = Loothing.Session:GetMasterLooter()
                if not ml or not Loothing.Comm then
                    printError("Master Looter unavailable.")
                    return
                end
                -- Collect all resendable responses and batch them
                local batch = {}
                local resendNames = {}
                for guid, data in pairs(tracker.responses) do
                    if data.response then
                        local item = Loothing.Session:GetItemByGUID(guid)
                        if item and item:IsVoting() then
                            local roll, rMin, rMax = tracker:GetRoll(guid)
                            -- Include gear inline to prevent PIQ/PIS round-trip on resend.
                            local g1Link, g2Link, g1ilvl, g2ilvl
                            if item.equipSlot then
                                g1Link, g2Link, g1ilvl, g2ilvl =
                                    Loothing.Session:GetEquippedGearForSlot(item.equipSlot)
                            end
                            batch[#batch + 1] = {
                                itemGUID = guid,
                                response = data.response,
                                note = data.note ~= "" and data.note or nil,
                                roll = roll or 0,
                                rollMin = rMin or 1,
                                rollMax = rMax or 100,
                                gear1Link = g1Link,
                                gear2Link = g2Link,
                                gear1ilvl = g1ilvl or 0,
                                gear2ilvl = g2ilvl or 0,
                            }
                            tracker:SetResponse(guid, data.response, data.note, true)
                            resendNames[#resendNames + 1] = item.itemLink or item.name or guid
                        end
                    end
                end
                if #batch == 0 then
                    printLine("No pending responses to resend.")
                elseif #batch == 1 then
                    local r = batch[1]
                    pcall(function()
                        Loothing.Comm:SendPlayerResponse(
                            r.itemGUID, r.response, r.note,
                            r.roll, r.rollMin, r.rollMax,
                            ml, Loothing.Session:GetSessionID(),
                            r.gear1Link, r.gear2Link, r.gear1ilvl, r.gear2ilvl
                        )
                    end)
                    printLine("Resent response for " .. resendNames[1])
                else
                    pcall(function()
                        Loothing.Comm:SendResponseBatch(batch, ml, Loothing.Session:GetSessionID())
                    end)
                    printLine("Resent " .. #batch .. " responses as batch")
                end
            end,
        },
        {
            key = "ignore",
            description = L["SLASH_DESC_IGNORE"],
            usage = { "/lt ignore <itemLink|itemID>" },
            handler = function(args)
                handleIgnore(args)
            end,
        },
        {
            key = "add",
            description = L["SLASH_DESC_ADD"],
            usage = { "/lt add", "/lt add <itemLink|itemID>" },
            handler = function(args)
                if not Loothing.Session then
                    printError(L["ERROR_NO_SESSION"])
                    return
                end
                -- Auto-start a session if one isn't active
                if Loothing.Session:GetState() == Loothing.SessionState.INACTIVE then
                    if not Loothing.handleLoot then
                        Loothing:StartHandleLoot()
                    end
                    Loothing.Session:StartSession(nil, "Manual Session")
                end
                local input = args and args ~= "" and args or nil
                if input then
                    -- Direct add: resolve and add without opening the frame
                    local function tryAdd(link, retries)
                        retries = retries or 0
                        local resolvedLink = select(2, C_Item.GetItemInfo(link or input))
                        if resolvedLink then
                            -- Use SafeUnitName to avoid secret value tainting
                            local item = Loothing.Session:AddItem(resolvedLink, Loolib.SecretUtil.SafeUnitName("player"), nil, true)
                            if item then
                                printLine(string.format("%s added to session.", resolvedLink))
                            else
                                printError("Failed to add item to session.")
                            end
                        elseif retries < 20 then
                            C_Timer.After(0.05, function() tryAdd(input, retries + 1) end)
                        else
                            printError(L["SLASH_INVALID_ITEM"])
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
            key = "export",
            description = L["SLASH_DESC_EXPORT"],
            usage = { "/lt export", "/lt export crafting" },
            handler = function(args)
                local sub = strtrim(args or ""):lower()

                if sub == "crafting" then
                    if Loothing.CraftingRecipes then
                        Loothing.CraftingRecipes:ScanCurrentProfession()
                    else
                        printError("Crafting recipe scanner not available.")
                    end
                    return
                end

                if Loothing.SettingsExport then
                    Loothing.SettingsExport:ShowExportDialog()
                else
                    printError("Settings export not available.")
                end
            end,
        },
        {
            key = "profile",
            aliases = { "prof" },
            description = L["SLASH_DESC_PROFILE"],
            usage = { "/lt profile", "/lt profile list", "/lt profile <name>" },
            handler = function(args)
                args = strtrim(args or "")
                local profiles = Loothing.Settings:GetProfiles() or {}
                local current = Loothing.Settings:GetCurrentProfile() or "Default"

                -- No args or "list": print all profiles
                if args == "" or args:lower() == "list" then
                    printLine(L["PROFILE_LIST_HEADER"])
                    for _, name in ipairs(profiles) do
                        if name == current then
                            print("  |cFF33FF99> " .. name .. "|r")
                        else
                            print("    " .. name)
                        end
                    end
                    return
                end

                -- Try case-insensitive match against existing profiles
                local argsLower = args:lower()
                local matched = nil
                for _, name in ipairs(profiles) do
                    if name:lower() == argsLower then
                        matched = name
                        break
                    end
                end

                if matched then
                    Loothing.Settings:SetProfile(matched)
                    printLine(string.format(
                        L["PROFILE_SWITCHED"], matched))
                else
                    -- Validate and create new profile
                    local trimmed = strtrim(args)
                    if #trimmed > 48 then
                        printError("Profile name must be 48 characters or fewer.")
                        return
                    end
                    if trimmed:match('[<>:"/\\|?*]') then
                        printError("Profile name contains invalid characters.")
                        return
                    end
                    Loothing.Settings:SetProfile(trimmed)
                    printLine(string.format(
                        L["PROFILE_CREATED"], trimmed))
                end

                if Loolib.Config then
                    Loolib.Config:NotifyChange("Loothing")
                end
            end,
        },
        {
            key = "sync",
            description = L["SLASH_DESC_SYNC"],
            usage = { "/lt sync settings [guild|player]", "/lt sync history [guild|player] [days]" },
            handler = function(args)
                handleSync(args or "")
            end,
        },
        {
            key = "share",
            description = L["SLASH_DESC_SHARE"],
            usage = { "/lt share intel [group|guild]", "/lt share purge", "/lt share status" },
            handler = function(args)
                handleShare(args or "")
            end,
        },
        {
            key = "import",
            description = L["SLASH_DESC_IMPORT"],
            usage = { "/lt import <csv|tsv data>", "/lt import settings" },
            handler = function(args)
                local firstWord = (args or ""):match("^(%S+)")
                if firstWord and firstWord:lower() == "settings" then
                    if Loothing.SettingsExport then
                        Loothing.SettingsExport:ShowImportDialog()
                    else
                        printError("Settings import not available.")
                    end
                else
                    handleImport(args or "")
                end
            end,
        },
        {
            key = "errors",
            description = L["SLASH_DESC_ERRORS"],
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
            description = L["SLASH_DESC_LOG"],
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
            description = L["SLASH_DESC_DEBUG"],
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
                printLine(string.format(L["SLASH_DEBUG_STATE"], Loothing.debug and "ON" or "OFF"))
            end,
        },
        {
            key = "diag",
            aliases = { "diagnose" },
            description = "Communication pipeline diagnostics",
            usage = { "/lt diag" },
            handler = function()
                if Loothing.DiagPanel then
                    Loothing.DiagPanel:Toggle()
                else
                    printLine("Diagnostics panel not available.")
                end
            end,
        },
        {
            key = "lootdiag",
            description = "Print loot-detection state snapshot",
            usage = { "/lt lootdiag" },
            handler = function()
                local function yn(b) return b and "true" or "false" end
                local Session = Loothing.Session
                local Settings = Loothing.Settings
                local state = Session and Session:GetState() or nil
                local stateName = "nil"
                if state == Loothing.SessionState.INACTIVE then stateName = "INACTIVE"
                elseif state == Loothing.SessionState.ACTIVE then stateName = "ACTIVE"
                elseif state == Loothing.SessionState.CLOSED then stateName = "CLOSED"
                end
                local function countKeys(t)
                    if type(t) ~= "table" then return 0 end
                    local n = 0
                    for _ in pairs(t) do n = n + 1 end
                    return n
                end
                local instName, instType, difficultyID = GetInstanceInfo()

                printLine("=== Loothing Loot Detection Diagnostics ===")
                printLine("handleLoot:            " .. yn(Loothing.handleLoot))
                printLine("handleLootDeclined:    " .. yn(Loothing.handleLootDeclined))
                printLine("isMasterLooter:        " .. yn(Loothing.isMasterLooter))
                printLine("masterLooter:          " .. tostring(Loothing.masterLooter))
                printLine("canonicalML:           " .. tostring(Loothing:GetCanonicalML()))
                printLine("IsCanonicalML():       " .. yn(Loothing:IsCanonicalML()))
                printLine("IsInGroup:             " .. yn(IsInGroup()))
                printLine("IsInRaid:              " .. yn(IsInRaid()))
                printLine("UnitIsGroupLeader:     " .. yn(UnitIsGroupLeader("player")))
                printLine("Session state:         " .. stateName
                    .. " (id=" .. tostring(Session and Session.sessionID) .. ")")
                if Settings then
                    printLine("ml.usageMode:          " .. tostring(Settings:Get("ml.usageMode", "ask_gl")))
                    printLine("ml.scope:              " .. tostring(Settings:Get("ml.scope", "raids_only")))
                    printLine("ml.autoAddBoEs:        " .. yn(Settings:Get("ml.autoAddBoEs", false)))
                    printLine("session.triggerAction: " .. tostring(Settings:Get("session.triggerAction", "prompt")))
                    printLine("session.triggerTiming: " .. tostring(Settings:Get("session.triggerTiming", "encounterEnd")))
                    printLine("session.scope.raid:    " .. yn(Settings:Get("session.scope.raid", true)))
                    printLine("session.scope.dungeon: " .. yn(Settings:Get("session.scope.dungeon", false)))
                    printLine("session.scope.openW:   " .. yn(Settings:Get("session.scope.openWorld", false)))
                end
                local minQ = Loothing.Settings and Loothing.Settings.GetLootFilterMinQuality
                    and Loothing.Settings:GetLootFilterMinQuality()
                    or Loothing.MinQuality
                printLine("MinQuality:            " .. tostring(minQ)
                    .. " (loot.filter.minQuality)")
                if Session then
                    printLine("preEncounterBagSnapshot size: " .. countKeys(Session.preEncounterBagSnapshot))
                    printLine("reportedTradeableItems size:  " .. countKeys(Session.reportedTradeableItems))
                    printLine("Bag scan running:      " .. yn(Session.bagScanTimer ~= nil))
                    printLine("Last encounter:        " .. tostring(Session.lastEncounterID)
                        .. " \"" .. tostring(Session.lastEncounterName) .. "\"")
                    printLine("lootBuffer size:       " .. (Session.lootBuffer and #Session.lootBuffer or 0))
                end
                printLine("Instance:              " .. tostring(instName)
                    .. " (" .. tostring(instType) .. ", diff=" .. tostring(difficultyID) .. ")")
                printLine("BIND_TRADE_TIME_REMAINING:")
                printLine("  " .. tostring(BIND_TRADE_TIME_REMAINING))
            end,
        },
        {
            key = "tooltipscan",
            description = "Dump tooltip text + trade-time parse for a bag slot",
            usage = { "/lt tooltipscan <bag> <slot>" },
            handler = function(args)
                -- Accept leading/trailing whitespace; reject anything else.
                local bagStr, slotStr = (args or ""):match("^%s*(%S+)%s+(%S+)%s*$")
                local bag = tonumber(bagStr)
                local slot = tonumber(slotStr)
                if not bag or not slot then
                    printError("Usage: /lt tooltipscan <bag> <slot>   (bag 0 = backpack)")
                    return
                end
                local link = C_Container.GetContainerItemLink(bag, slot)
                if not link then
                    printError("No item at bag " .. bag .. " slot " .. slot)
                    return
                end
                printLine("=== Tooltip Scan: bag " .. bag .. " slot " .. slot .. " ===")
                printLine("Link: " .. link)

                -- Lazy-init reusable tooltip; see `local scanTooltip` declaration.
                if not scanTooltip then
                    scanTooltip = CreateFrame("GameTooltip", nil, UIParent, "GameTooltipTemplate")
                end
                scanTooltip:SetOwner(UIParent, "ANCHOR_NONE")
                scanTooltip:ClearLines()
                scanTooltip:SetBagItem(bag, slot)

                local lineIdx = 0
                local regions = { scanTooltip:GetRegions() }
                for _, region in ipairs(regions) do
                    if region.GetObjectType and region:GetObjectType() == "FontString" then
                        local text = region:GetText()
                        if text and text ~= "" then
                            lineIdx = lineIdx + 1
                            printLine(string.format("  [%2d] %s", lineIdx, text))
                        end
                    end
                end
                scanTooltip:Hide()

                local TradeQueue = Loothing.TradeQueue
                if TradeQueue and TradeQueue.GetContainerItemTradeTimeRemaining then
                    local t = TradeQueue:GetContainerItemTradeTimeRemaining(bag, slot)
                    local readable
                    if t == math.huge then
                        readable = "math.huge (no bound marker, no trade line)"
                    elseif not t then
                        readable = "nil"
                    elseif t == 0 then
                        readable = "0 (bound, no trade window)"
                    else
                        readable = tostring(t) .. "s (" .. math.floor(t / 60) .. "m " .. (t % 60) .. "s)"
                    end
                    printLine("GetContainerItemTradeTimeRemaining: " .. readable)
                end

                local _, _, quality, ilvl, _, _, _, _, _, _, _, _, _, bindType = C_Item.GetItemInfo(link)
                printLine("quality=" .. tostring(quality) .. " ilvl=" .. tostring(ilvl)
                    .. " bindType=" .. tostring(bindType) .. " (2=BoE,1=BoP)")
            end,
        },
        {
            key = "taint",
            devOnly = true,
            description = "Run Loothing taint/global audit",
            usage = { "/lt taint", "/lt taint scan", "/lt taint clear" },
            handler = function(args)
                if not requireDebug("/lt taint") then
                    return
                end

                if not Loothing.Diagnostics then
                    printError("Diagnostics not available.")
                    return
                end

                local action = (args or ""):lower()
                if action == "" then
                    local report = Loothing.Diagnostics:GetReport() or Loothing.Diagnostics:RunScan("slash")
                    Loothing.Diagnostics:PrintReport(report, printLine)
                    return
                end

                if action == "scan" then
                    local report = Loothing.Diagnostics:RunScan("slash")
                    Loothing.Diagnostics:PrintReport(report, printLine)
                    return
                end

                if action == "clear" then
                    Loothing.Diagnostics:Clear()
                    printLine("Taint diagnostics cleared and baseline reset.")
                    return
                end

                printError("Usage: /lt taint [scan|clear]")
            end,
        },
        {
            key = "test",
            devOnly = true,
            description = L["SLASH_DESC_TEST"],
            usage = { "/lt test", "/lt test help" },
            handler = function(args)
                if not requireDebug("/lt test") then
                    return
                end
                local TestMode = ns.TestMode
                if TestMode and TestMode.HandleCommand then
                    TestMode:HandleCommand(args or "")
                else
                    printError(L["SLASH_TEST_UNAVAILABLE"])
                end
            end,
        },
        {
            key = "testmode",
            devOnly = true,
            description = L["SLASH_DESC_TESTMODE"],
            usage = { "/lt testmode on|off|status", "/lt testmode persist on|off" },
            handler = function(args)
                if not requireDebug("/lt testmode") then
                    return
                end
                local TestMode = ns.TestModeState
                if TestMode and TestMode.HandleSlash then
                    TestMode:HandleSlash(args or "")
                else
                    printError(L["SLASH_TEST_UNAVAILABLE"])
                end
            end,
        },
        {
            key = "sim",
            devOnly = true,
            description = L["SLASH_DESC_SIM"] or "Boss-kill simulator (full pipeline)",
            usage = { "/lt sim help", "/lt sim panel", "/lt sim kill [boss] [N]" },
            handler = function(args)
                if not requireDebug("/lt sim") then
                    return
                end
                local Simulator = ns.Simulator
                if Simulator and Simulator.HandleCommand then
                    Simulator:HandleCommand(args or "")
                else
                    printError(L["SLASH_TEST_UNAVAILABLE"])
                end
            end,
        },
        {
            key = "help",
            description = L["SLASH_DESC_HELP"],
            usage = { "/lt help", "/lt help <command>" },
            handler = function(args, resolved, allCommands)
                local topic = (args or ""):lower()
                local function listCommands()
                    printLine(L["SLASH_HELP_HEADER"])
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
                        printLine(L["SLASH_HELP_DEBUG_NOTE"])
                    end
                end

                if topic == "" then
                    listCommands()
                    return
                end

                local lookup = resolved[topic]
                if not lookup or (lookup.devOnly and not isDebugEnabled()) then
                    printError(string.format(L["SLASH_HELP_UNKNOWN"], topic))
                    return
                end

                printLine(string.format(L["SLASH_HELP_DETAIL"], lookup.key))
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

    GlobalBridge:RegisterSlashCommands(ADDON_NAME, {
        {
            id = "LOOTHING",
            commands = { "/loothing", "/lt" },
            handler = function(msg)
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
            printError(string.format(L["SLASH_HELP_UNKNOWN"], token))
            local helpCmd = commandByToken["help"]
            if helpCmd then
                helpCmd.handler("", helpCmd, commands)
            end
            return
        end

        if command.devOnly and not isDebugEnabled() then
            printError(L["SLASH_DEBUG_REQUIRED"])
            return
        end

        command.handler(rest, command, commands)
            end,
        },
    })
end

--[[--------------------------------------------------------------------
    Event Handlers
----------------------------------------------------------------------]]

eventFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" then
        local addonName = ...
        if addonName == ADDON_NAME then
            -- Ensure SavedVariables table exists (first run or deleted WTF folder)
            if _G.LoolibDB == nil then
                _G.LoolibDB = {}
            end

            -- Detect and apply Brainrot Mode (SavedVariables are now available)
            local svDB = _G.LoolibDB
            if type(svDB) == "table" then
                -- Migrate old locale override to dedicated flag (one-time)
                if type(svDB._localeOverrides) == "table"
                   and svDB._localeOverrides[ADDON_NAME] == "brainrot" then
                    if not svDB._brainrotMode then svDB._brainrotMode = {} end
                    svDB._brainrotMode[ADDON_NAME] = true
                    svDB._localeOverrides[ADDON_NAME] = nil
                    if not next(svDB._localeOverrides) then svDB._localeOverrides = nil end
                end
                -- Apply brainrot strings in-place over the real locale table
                if type(svDB._brainrotMode) == "table"
                   and svDB._brainrotMode[ADDON_NAME] == true then
                    Addon.BrainrotMode = true
                    local baseLocale = ns.Locale
                    local brainrot = ns.BrainrotStrings
                    if baseLocale and brainrot then
                        for key, value in pairs(brainrot) do
                            rawset(baseLocale, key, value)
                        end
                    end
                end
            end

            -- Initialize all modules (Loolib.Comm handles addon prefix registration)
            InitializeModules()

            -- Register slash commands
            RegisterSlashCommands()

            -- Register Loothing's Loolib ConfigDialog theme so the
            -- /lt config window matches the rest of the addon's UI.
            -- Hooks SkinningMixin:RefreshTheme so it stays in sync when
            -- the user switches accent / skin.
            if ns.LoothingDialogTheme then
                ns.LoothingDialogTheme:Register()
                ns.LoothingDialogTheme:HookSkinningRefresh()
                ns.LoothingDialogTheme:HookDialogScrollbars()
            end

            if Loothing.Diagnostics then
                Loothing.Diagnostics:MarkRuntimeReady()
            end

            -- Dev build detection: the dev TOC loads the test harness
            -- (ns.TestRunner). When present, enable TempTable leak tracking
            -- so /lt diag and DiagPanel show meaningful leak counts. Release
            -- builds leave it off — debugstack(2) on every Acquire is
            -- noticeable on hot paths (comm batching, event dispatch).
            if ns.TestRunner and Loolib and Loolib.TempTable
                and Loolib.TempTable.SetLeakWarnings then
                Loolib.TempTable:SetLeakWarnings(true)
                Loothing.isDevBuild = true
            end

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
            if ns.CreateMinimapButton then
                local success, result = pcall(ns.CreateMinimapButton)
                if success and result then
                    Loothing.MinimapButton = result
                    Loothing.UI.MinimapButton = result
                else
                    Loothing:Error("Failed to create minimap button:", result or "unknown error")
                end
            end

            -- Load persisted version data (Settings is now available)
            local versionCheck = GetVersionCheck()
            if versionCheck and versionCheck.LoadPersistedVersions then
                versionCheck:LoadPersistedVersions()
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
                desc:SetText("Loothing - " .. (L["ADDON_TAGLINE"]))

                local subdesc = settingsFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
                subdesc:SetPoint("TOP", desc, "BOTTOM", 0, -12)
                subdesc:SetText(L["BLIZZARD_SETTINGS_DESC"])

                local versionText = settingsFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                versionText:SetPoint("TOP", subdesc, "BOTTOM", 0, -8)
                versionText:SetTextColor(0.7, 0.7, 0.7)
                versionText:SetText("v" .. (Loothing.VERSION or "?"))

                local openBtn = ns.CreateThemedButton(settingsFrame)
                openBtn:SetSize(200, 30)
                openBtn:SetPoint("TOP", versionText, "BOTTOM", 0, -20)
                openBtn:SetText(L["OPEN_SETTINGS"])
                ns.SkinningMixin:StylePlainButton(openBtn, "primary")
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

        -- Notify CommState of world entry (starts grace period if in group)
        if Loothing.CommState and Loothing.initialized then
            Loothing.CommState:OnPlayerEnteringWorld()
        end

        -- Seed the bag snapshot: it is otherwise only taken at
        -- ENCOUNTER_START, so a player who logs in / reloads / zones in
        -- mid-raid has an empty baseline and the next post-encounter scan
        -- re-reports every still-tradable item from earlier bosses as
        -- fresh loot.
        if Loothing.Session and Loothing.Session.SnapshotBags and Loothing.initialized then
            Loothing.Session:SnapshotBags()
        end

        if isReload and Loothing.initialized then
            -- UI reload - attempt to restore cached state
            Loothing:RestoreFromCache()
            -- Detect and restore an orphaned MLDB snapshot from a session
            -- that died across the reload (no SESSION_END ever arrived).
            if Loothing.MLDB and Loothing.MLDB.RecoverIfOrphaned then
                Loothing.MLDB:RecoverIfOrphaned()
            end
            -- Recover from a /reload-orphaned simulator state so the user's
            -- triggerTiming setting is restored if the sim was active when
            -- they reloaded. Cheap, idempotent — safe to call always.
            if ns.Simulator and ns.Simulator.RecoverOrphanedStash then
                ns.Simulator:RecoverOrphanedStash()
            end
            -- If cache didn't restore handleLoot, re-check like login path
            if IsInGroup() and not Loothing.handleLoot then
                ScheduleRaidEnter(3)
            end
        elseif isLogin and Loothing.initialized then
            -- Try to restore cached session (e.g., disconnect/reconnect within 15 min)
            Loothing:RestoreFromCache()
            -- Detect and restore an orphaned MLDB snapshot from a session
            -- that died across the disconnect (no SESSION_END ever arrived).
            if Loothing.MLDB and Loothing.MLDB.RecoverIfOrphaned then
                Loothing.MLDB:RecoverIfOrphaned()
            end
            -- Recover from a /reload-orphaned simulator state so the user's
            -- triggerTiming setting is restored if the sim was active when
            -- they reloaded. Cheap, idempotent — safe to call always.
            if ns.Simulator and ns.Simulator.RecoverOrphanedStash then
                ns.Simulator:RecoverOrphanedStash()
            end
            -- If no session was restored, check for raid entry prompt
            if IsInGroup() and not Loothing.handleLoot then
                ScheduleRaidEnter(3)
            end
        elseif Loothing.initialized then
            -- Normal zone transition (not login, not reload).  Re-run the
            -- ML check so that a raid ML who zoned into a M+ dungeon,
            -- scenario, or PvP instance correctly triggers the cleanup
            -- block in PerformMLCheck (via the reordered ShouldSkipMLCheck).
            ScheduleMLCheck()
        end
    elseif event == "PLAYER_LOGOUT" then
        -- Cache state for reconnect (captures MLDB for session resume)
        Loothing:CacheStateForReconnect()

        -- Restore pre-session settings if MLDB overwrote them.
        -- Without this, ML-broadcast values persist to SavedVariables and
        -- RemoveDefaults strips any that match defaults, permanently losing
        -- the user's original non-default settings.
        -- NOTE: RestoreSettings only touches settings + preSessionSnapshot,
        -- not self.mldb, so the reconnect cache (captured above) is unaffected.
        if Loothing.MLDB then
            Loothing.MLDB:RestoreSettings()
        end

        -- Save error log to SavedVariables
        if Loothing.ErrorHandler then
            Loothing.ErrorHandler:SaveToDatabase()
        end

        -- Write desktop exchange export metadata
        Loothing:WriteDesktopExport()

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

function Addon:Debug(...)
    if self.debug then
        print("|cff00ff00[Loothing Debug]|r", SecretUtil.SecretsForPrint(...))
    end
end

-- Inline texture escapes so the icon renders in the chat frame's font
-- (we can't swap chat's font to our TTF icon font, so use WoW textures).
local ICON_WARN  = "|TInterface\\DialogFrame\\DialogAlertIcon:14:14:0:0|t"
local ICON_ERROR = "|TInterface\\RAIDFRAME\\ReadyCheck-NotReady:14:14|t"

function Addon:Warn(...)
    print(ICON_WARN .. " |cffffcc00[Loothing Warn]|r", SecretUtil.SecretsForPrint(...))
end

function Addon:Error(...)
    print(ICON_ERROR .. " |cffff0000[Loothing Error]|r", SecretUtil.SecretsForPrint(...))
end

function Addon:Print(...)
    local frameName = self.Settings and self.Settings:Get("frame.chatFrameName", "ChatFrame1") or "ChatFrame1"
    local chatFrame = _G[frameName] or DEFAULT_CHAT_FRAME
    local msg = table.concat({SecretUtil.SecretsForPrint(...)}, " ")
    chatFrame:AddMessage("|cff00ccff[Loothing]|r " .. msg)
end

--[[--------------------------------------------------------------------
    Public API
----------------------------------------------------------------------]]

--- Check if the addon is ready
-- @return boolean
function Addon:IsReady()
    return self.initialized
end

--- Returns the current authoritative Master Looter name.
-- Cascade: Session.masterLooter → explicitMasterLooter → Loothing.masterLooter → raid leader.
-- All IsMasterLooter() checks should route through this to avoid disagreement.
-- @return string|nil
function Addon:GetCanonicalML()
    if self.Session then
        local sessionML = self.Session:GetMasterLooter()
        if sessionML then return sessionML end
    end
    if self.explicitMasterLooter then
        return self.explicitMasterLooter
    end
    if self.masterLooter then
        return self.masterLooter
    end
    -- Final fallback: live raid leader
    if self.Settings then
        return self.Settings:GetMasterLooter()
    end
    return nil
end

--- Check if local player is the canonical ML
-- @return boolean
function Addon:IsCanonicalML()
    local ml = self:GetCanonicalML()
    if not ml then return false end
    return Utils.IsSamePlayer(ml, Utils.GetPlayerFullName())
end

--- Check whether the local player should receive Master Looter UI privileges.
-- This is stricter than IsCanonicalML during reconnect restore: cached ML state
-- is not trusted for sensitive vote visibility until the live group ML check has
-- run at least once.
-- @return boolean
function Addon:HasMasterLooterVisibility()
    if self.mlStateVerified == false then return false end
    if self.Session and self.Session.IsMasterLooter and self.Session:IsMasterLooter() then return true end
    if self:IsCanonicalML() then return true end
    if not (self.handleLoot and self.isMasterLooter) then return false end

    local playerName = Utils.GetPlayerFullName()
    return playerName and self.masterLooter and Utils.IsSamePlayer(self.masterLooter, playerName) or false
end

--- Check whether restored/cached state says the local player is the ML.
--- Used only for fail-closed UI presentation during reconnect verification,
--- never for revealing responses/votes or enabling ML actions.
-- @return boolean
function Addon:IsCachedMasterLooterCandidate()
    local playerName = Utils.GetPlayerFullName()
    if not playerName then return false end
    if self.isMasterLooter == true then return true end

    local ml = self.masterLooter
        or (self.Session and self.Session.GetMasterLooter and self.Session:GetMasterLooter())
        or (self.GetCanonicalML and self:GetCanonicalML())
    return ml and Utils.IsSamePlayer(playerName, ml) or false
end

--- Get current session
-- @return table|nil
function Addon:GetSession()
    return self.Session
end

--- Get council manager
-- @return table|nil
function Addon:GetCouncil()
    return self.Council
end

--- Get settings
-- @return table|nil
function Addon:GetSettings()
    return self.Settings
end

--- Toggle main window
function Addon:Toggle()
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
function Addon:CacheStateForReconnect()
    if not self.Settings then return end

    -- Never persist test/simulator state: a /reload mid-sim would otherwise
    -- cache the fake ML identity + fake ACTIVE session, and the next load
    -- (test mode inactive) would restore the phantom session as real — the
    -- solo path even sets mlStateVerified. Clear any prior cache instead.
    if (ns.TestModeState and ns.TestModeState:IsActive())
        or (ns.Simulator and ns.Simulator.IsActive and ns.Simulator:IsActive()) then
        self.Settings:SetGlobalValue("reconnectCache", nil)
        return
    end

    local cache = {
        timestamp = time(),
        handleLoot = self.handleLoot,
        isMasterLooter = self.isMasterLooter,
        masterLooter = self.masterLooter,
        explicitMasterLooter = self.explicitMasterLooter,
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

    -- Cache observer roster
    if self.Observer then
        cache.observerRoster = self.Observer:GetReconnectSnapshot()
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
                    itemID = item.itemID,
                    itemLink = item.itemLink,
                    looter = item.looter,
                    state = item:GetState(),
                    isTradable = item.isTradable,
                    tradeTimeRemaining = item.tradeTimeRemaining,
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

    -- Tag cache with owner to prevent alt character restore
    cache.owner = Utils.GetPlayerFullName()

    -- Store in global scope (persists across profiles)
    self.Settings:SetGlobalValue("reconnectCache", cache)
    self:Debug("Cached state for reconnect (handleLoot:", tostring(self.handleLoot), ")")
end

--- Write desktop exchange export metadata to SavedVariables for the Tauri companion app.
--- Called at PLAYER_LOGOUT so the desktop app can identify which character last logged out.
function Addon:WriteDesktopExport()
    if not self.Settings then return end
    -- /reload mid-encounter triggers PLAYER_LOGOUT under taint; UnitName /
    -- UnitClass return secret-tagged values on those paths and the bare
    -- concat/index ops would throw. Use Safe* wrappers and gate accordingly.
    local name = SecretUtil.SafeUnitName("player")
    local realm = GetRealmName()
    local fullName = name and realm and (name .. "-" .. realm)
    local _, class = SecretUtil.SafeUnitClass("player")
    local guid = UnitGUID("player")
    if SecretUtil.IsSecretValue(guid) then guid = nil end

    local export = {
        version = 2,
        exportedAt = time(),
        characterName = fullName,
        characterGUID = guid,
        characterClass = class,
        addonVersion = self.VERSION,
    }
    self.Settings:SetGlobalValue("desktopExchange.export", export)
end

local function SanitizeReconnectSessionItems(items)
    if type(items) ~= "table" then return items end

    local sanitized = {}
    for i, item in ipairs(items) do
        if type(item) == "table" then
            sanitized[i] = {
                guid = item.guid,
                itemID = item.itemID,
                itemLink = item.itemLink,
                looter = item.looter,
                state = item.state,
                isTradable = item.isTradable,
                tradeTimeRemaining = item.tradeTimeRemaining,
            }
        end
    end
    return sanitized
end

--- Restore state from cache after UI reload
function Addon:RestoreFromCache()
    if not self.Settings then return end

    local cache = self.Settings:GetGlobalValue("reconnectCache")
    if not cache then
        self:Debug("No reconnect cache found")
        return
    end

    -- Reject cache if it belongs to a different character
    local currentOwner = Utils.GetPlayerFullName()
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
    self.mlStateVerified = false
    self.handleLoot = cache.handleLoot or false
    self.isMasterLooter = cache.isMasterLooter or false
    self.masterLooter = cache.masterLooter
    self.explicitMasterLooter = cache.explicitMasterLooter
    self.isInGuildGroup = cache.isInGuildGroup or false

    -- Restore MLDB
    if cache.mldb and self.MLDB then
        self.MLDB:ApplyFromML(cache.mldb, cache.masterLooter or "")
    end

    local restoringAsMasterLooter = cache.isMasterLooter == true

    -- Restore remote rosters only on non-ML clients. ML clients already have
    -- local saved rosters loaded; making the cached snapshot remote-primary
    -- would cause subsequent local roster edits/broadcasts to read stale data.
    if cache.councilRoster and self.Council and not restoringAsMasterLooter then
        self.Council:SetRemoteRoster(cache.councilRoster)
    end

    if cache.observerRoster and self.Observer and not restoringAsMasterLooter then
        self.Observer:SetRemoteObserverList(cache.observerRoster)
    end

    -- Restore session state
    if cache.session and self.Session then
        local restoredML = self.masterLooter or cache.masterLooter
        if self.MLDB and self.MLDB:Get() then
            local mldb = self.MLDB:Get()
            restoredML = mldb.masterLooter
                or (self.Settings and self.Settings:GetMasterLooter())
                or self.masterLooter
                or cache.masterLooter
        end
        if restoredML then
            cache.session.masterLooter = restoredML
        end
        local restorePrivateCandidateState = restoringAsMasterLooter
            or (self.Council and self.Council.IsPlayerCouncilMember
                and self.Council:IsPlayerCouncilMember())

        local restoredItems = restorePrivateCandidateState
            and cache.session.items
            or SanitizeReconnectSessionItems(cache.session.items)

        self.Session:SyncFromData({
            sessionID = cache.session.sessionID,
            encounterID = cache.session.encounterID,
            encounterName = cache.session.encounterName,
            state = cache.session.state,
            masterLooter = cache.session.masterLooter,
            items = restoredItems,
        })
    end

    -- Clear the cache after restore
    self.Settings:SetGlobalValue("reconnectCache", nil)

    -- If we were handling loot and have an ML, send reconnect request.
    -- Gated on CommState grace period + jitter to prevent thundering herd.
    local CommState = self.CommState
    if cache.masterLooter and not cache.isMasterLooter then
        -- We're not ML - request full state from ML after grace period
        local function doReconnectSync()
            if self.masterLooter then
                self:Debug("Sending reconnect request to ML:", self.masterLooter)
                if CommState then
                    CommState:RequestSyncIfNeeded("reconnect", self.masterLooter)
                elseif self.Sync then
                    self.Sync:RequestSync(self.masterLooter)
                end
            end
        end

        if CommState and CommState:IsInGracePeriod() then
            CommState:RegisterCallback("OnGracePeriodEnded", function()
                CommState:UnregisterCallback("OnGracePeriodEnded", self)
                local delay = CommState:Jitter(1, 1.5)
                C_Timer.After(delay, doReconnectSync)
            end, self)
        else
            C_Timer.After(3, doReconnectSync)
        end
    elseif cache.isMasterLooter and cache.handleLoot then
        -- We ARE the ML — re-broadcast MLDB and council after grace period.
        -- Post-reconnect the audience may have changed (members who joined
        -- while we were disconnected); force=true bypasses the payload-only
        -- dirty cache so these always push state.
        local function doMLBroadcast()
            if self.MLDB then
                self.MLDB:BroadcastToRaid(true)
            end
            if self.Council and self.Comm then
                local members = self.Council:GetAllMembers()
                self.Comm:BroadcastCouncilRoster(members)
            end
        end

        if CommState and CommState:IsInGracePeriod() then
            CommState:RegisterCallback("OnGracePeriodEnded", function()
                CommState:UnregisterCallback("OnGracePeriodEnded", self)
                local delay = CommState:Jitter(0.5, 1.0)
                C_Timer.After(delay, doMLBroadcast)
            end, self)
        else
            C_Timer.After(2, doMLBroadcast)
        end
    end

    -- Cached ML identity is optimistic. Re-run the live ML resolver immediately
    -- so restored globals/session state cannot remain authoritative after a
    -- reload or reconnect if the raid changed ML while the client was gone.
    if IsInGroup() then
        ScheduleMLCheck(0.1)
    else
        self.mlStateVerified = true
    end

    self:Print(L["RECONNECT_RESTORED"])
end
