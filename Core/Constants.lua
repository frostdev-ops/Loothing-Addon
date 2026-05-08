--[[--------------------------------------------------------------------
    Loothing - Loot Council Addon for WoW 12.0+
    Constants - Enums, defaults, and static values
----------------------------------------------------------------------]]

local _, ns = ...

local Loothing = ns.Addon

-- Addon info
Loothing.VERSION = "2.0.44"
Loothing.PROTOCOL_VERSION = 4
-- Minimum accepted protocol version on receive. v2 and earlier predate the
-- current serializer/compressor pipeline and cannot be parsed safely; v3
-- remains supported for legacy peers (differs from v4 only in the absence
-- of per-message msgID). Anything below v3 is dropped.
Loothing.MIN_PROTOCOL_VERSION = 3
Loothing.ADDON_PREFIX = "LOOTHING"

--[[--------------------------------------------------------------------
    Response Types (for voting)
----------------------------------------------------------------------]]

Loothing.Response = {
    NEED = 1,
    GREED = 2,
    OFFSPEC = 3,
    TRANSMOG = 4,
    PASS = 5,
}

-- Response priority order (highest to lowest)
Loothing.ResponsePriority = {
    Loothing.Response.NEED,
    Loothing.Response.GREED,
    Loothing.Response.OFFSPEC,
    Loothing.Response.TRANSMOG,
    Loothing.Response.PASS,
}

-- Response display info
Loothing.ResponseInfo = {
    [Loothing.Response.NEED] = {
        name = "NEED",
        color = { r = 0.0, g = 1.0, b = 0.0, a = 1.0 },       -- Green
        icon = "Interface\\Buttons\\UI-GroupLoot-Dice-Up",
    },
    [Loothing.Response.GREED] = {
        name = "GREED",
        color = { r = 1.0, g = 1.0, b = 0.0, a = 1.0 },       -- Yellow
        icon = "Interface\\Buttons\\UI-GroupLoot-Coin-Up",
    },
    [Loothing.Response.OFFSPEC] = {
        name = "OFFSPEC",
        color = { r = 1.0, g = 0.5, b = 0.0, a = 1.0 },       -- Orange
        icon = "Interface\\Icons\\Ability_DualWield",
    },
    [Loothing.Response.TRANSMOG] = {
        name = "TRANSMOG",
        color = { r = 1.0, g = 0.0, b = 1.0, a = 1.0 },       -- Magenta
        icon = "Interface\\Icons\\INV_Arcane_Orb",
    },
    [Loothing.Response.PASS] = {
        name = "PASS",
        color = { r = 0.5, g = 0.5, b = 0.5, a = 1.0 },       -- Gray
        icon = "Interface\\Buttons\\UI-GroupLoot-Pass-Up",
    },
}

--[[--------------------------------------------------------------------
    System Responses (non-editable, string-keyed)
----------------------------------------------------------------------]]

Loothing.SystemResponse = {
    AUTOPASS    = "AUTOPASS",
    WAIT        = "WAIT",
    TIMEOUT     = "TIMEOUT",
    NOTANNOUNCED = "NOTANNOUNCED",
    AWARDED     = "AWARDED",
}

Loothing.SystemResponseInfo = {
    [Loothing.SystemResponse.AUTOPASS] = {
        name  = "Auto Pass",
        color = { r = 0.5, g = 0.5, b = 0.5, a = 0.7 },
        icon  = "Interface\\Buttons\\UI-GroupLoot-Pass-Up",
    },
    [Loothing.SystemResponse.WAIT] = {
        name  = "Waiting",
        color = { r = 1.0, g = 1.0, b = 0.5, a = 1.0 },
        icon  = nil,
    },
    [Loothing.SystemResponse.TIMEOUT] = {
        name  = "Timeout",
        color = { r = 0.7, g = 0.3, b = 0.3, a = 1.0 },
        icon  = nil,
    },
    [Loothing.SystemResponse.NOTANNOUNCED] = {
        name  = "Not Announced",
        color = { r = 0.5, g = 0.5, b = 0.5, a = 1.0 },
        icon  = nil,
    },
    [Loothing.SystemResponse.AWARDED] = {
        name  = "Awarded",
        color = { r = 1.0, g = 0.84, b = 0.0, a = 1.0 },
        icon  = "Interface\\Buttons\\UI-GroupLoot-Coin-Up",
    },
}

--[[--------------------------------------------------------------------
    Session State
----------------------------------------------------------------------]]

Loothing.SessionState = {
    INACTIVE = 1,   -- No active session
    ACTIVE = 2,     -- Session in progress, items can be added
    CLOSED = 3,     -- No more items, finishing remaining votes
}

--[[--------------------------------------------------------------------
    Item State
----------------------------------------------------------------------]]

Loothing.ItemState = {
    PENDING = 1,    -- Item received, not yet voting
    VOTING = 2,     -- Votes being collected
    TALLIED = 3,    -- Votes counted, awaiting ML decision
    AWARDED = 4,    -- Winner announced
    SKIPPED = 5,    -- ML chose to skip/disenchant
}

--[[--------------------------------------------------------------------
    Voting Mode
----------------------------------------------------------------------]]

Loothing.VotingMode = {
    SIMPLE = "SIMPLE",           -- Most votes for response type wins
    RANKED_CHOICE = "RANKED",    -- Instant runoff elimination
}

--[[--------------------------------------------------------------------
    Session Trigger Mode (legacy single-field enum — kept for migration)
----------------------------------------------------------------------]]

Loothing.SessionTrigger = {
    MANUAL = "manual",
    AUTO = "auto",
    PROMPT = "prompt",
    AFTER_ROLLS = "afterRolls",
}

--[[--------------------------------------------------------------------
    Session Trigger Policy (split model — source of truth)
----------------------------------------------------------------------]]

Loothing.SessionTriggerAction = {
    MANUAL = "manual",     -- Requires /loothing start; never prompts or auto-starts
    PROMPT = "prompt",     -- Shows dialog to confirm session start
    AUTO   = "auto",       -- Starts session directly without dialog
}

Loothing.SessionTriggerTiming = {
    ENCOUNTER_END = "encounterEnd",   -- React immediately on ENCOUNTER_END
    AFTER_LOOT    = "afterLoot",      -- Wait for encounter loot + debounce (any recipient)
}

-- Encounter scope toggles: which instance types are eligible for triggers.
-- PvP, arena, and scenario are always rejected regardless of these flags.
Loothing.SessionTriggerScope = {
    RAID       = "sessionTriggerRaid",
    DUNGEON    = "sessionTriggerDungeon",
    OPEN_WORLD = "sessionTriggerOpenWorld",
}

--[[--------------------------------------------------------------------
    Message Types (Communication Protocol)
----------------------------------------------------------------------]]

Loothing.MsgType = {
    -- Session management
    SESSION_START = "SS",       -- ML -> Raid: Start session
    SESSION_END = "SE",         -- ML -> Raid: End session
    STOP_HANDLE_LOOT = "SHL",   -- ML -> Raid: ML stopped handling loot entirely

    -- Item management
    ITEM_ADD = "IA",            -- ML -> Raid: Add item to session
    ITEM_REMOVE = "IR",         -- ML -> Raid: Remove item

    -- Voting
    VOTE_REQUEST = "VR",        -- ML -> Council: Request votes
    VOTE_COMMIT = "VC",         -- Council -> ML: Submit vote
    VOTE_CANCEL = "VX",         -- ML -> Council: Cancel voting
    VOTE_RESULTS = "VRR",       -- ML -> Council/Raid: Publish vote results/closure

    -- Awards
    VOTE_AWARD = "VA",          -- ML -> Raid: Announce winner
    VOTE_SKIP = "VS",           -- ML -> Raid: Skip item

    -- Sync
    SYNC_REQUEST = "SR",        -- Any -> ML: Request full state
    SYNC_DATA = "SD",           -- ML -> Requester: Full state

    -- Council
    COUNCIL_ROSTER = "CR",      -- ML -> Raid: Council member list

    -- Version Check
    VERSION_REQUEST = "VER_REQ", -- Any -> Guild/Raid: Request version info
    VERSION_RESPONSE = "VER_RES", -- Any -> Requester: Version info response

    -- Player info (gear comparison)
    PLAYER_INFO_REQUEST = "PIQ", -- ML -> Player: Request gear info
    PLAYER_INFO_RESPONSE = "PIS", -- Player -> ML: Send gear info

    -- Guild Sync (Settings and History)
    SYNC_SETTINGS_REQUEST = "SSR",   -- ML -> Target: Request to sync settings
    SYNC_SETTINGS_CONFIRM = "SSC",   -- Target -> ML: Confirm settings sync acceptance
    SYNC_SETTINGS_DATA = "SSD",      -- ML -> Target: Settings payload
    SYNC_HISTORY_REQUEST = "SHR",    -- ML -> Target: Request to sync history
    SYNC_HISTORY_CONFIRM = "SHC",    -- Target -> ML: Confirm history sync acceptance
    SYNC_HISTORY_DATA = "SHD",       -- ML -> Target: History payload
    PROFILE_EXPORT_SHARE = "PES",    -- Player -> Target: Share a settings export string

    -- Cross-realm relay
    XREALM = "XR",             -- Cross-realm whisper relay via group channel

    -- Roll/Vote System Message Types (added for candidate response flow)
    PLAYER_RESPONSE = "PR",      -- Raid member -> ML: Submit response/roll for item
    -- MLDB (Master Looter Database)
    MLDB_BROADCAST = "MLDB",     -- ML -> Raid: Broadcast ML settings

    -- Candidate/Vote Sync (Council visibility)
    CANDIDATE_UPDATE = "CU",     -- ML -> Council: Candidate response/data update
    VOTE_UPDATE = "VU",          -- ML -> Council: Vote update

    -- Trade tracking
    TRADABLE = "TR",             -- Candidate -> Group: Player looted tradeable item
    NON_TRADABLE = "NT",         -- Candidate -> Group: Player looted non-tradeable item

    -- Burst / resilience infrastructure
    BATCH     = "BT",            -- ML/Council: container wrapping multiple messages
    HEARTBEAT = "HB",            -- ML -> Raid: periodic state digest for auto-recovery

    -- Response recovery
    RESPONSE_POLL = "RP",           -- ML -> Raid: Poll for missing responses
    VOTE_POLL     = "VP",           -- ML -> Council: Poll for missing council votes

    -- Combined session setup (replaces separate SS + MLDB + CR + IA broadcasts)
    SESSION_INIT = "SI",           -- ML -> RAID: Combined session initialization

    -- Batched player responses (all items in one message)
    RESPONSE_BATCH = "RB",         -- Candidate -> ML: Batched responses for all items

    -- Incremental sync (lighter than full SYNC_DATA)
    SYNC_INCREMENTAL = "SIR",      -- Client -> ML: Request specific subset
    SYNC_INCREMENTAL_DATA = "SID", -- ML -> Client: Subset response

    -- Observer roster
    OBSERVER_ROSTER = "OR",         -- ML -> Raid: Observer list + permissions

    -- History sharing
    HISTORY_ENTRY = "HE",           -- ML -> Group/Guild: Broadcast history entry after award

    -- Desktop Intel Share (manual broadcast of desktop-app-synced data)
    INTEL_SHARE_MANIFEST = "ISM",   -- Sender -> Group/Guild: Transfer metadata
    INTEL_SHARE          = "IS",    -- Sender -> Group/Guild: Dataset payload
}

--[[--------------------------------------------------------------------
    Default Settings
----------------------------------------------------------------------]]

Loothing.DefaultSettings = {
    -- Schema version. Bumped when DefaultSettings shape changes; the
    -- Migrations module reads this to decide which migration steps to
    -- run on existing user profiles.
    --   v1 = pre-2.0.7 shape
    --   v2 = 2.0.7 settings cleanup (settings.* namespace removed,
    --        ml.scope/voting.privacy/history.share collapsed merges,
    --        legacy announcement / buttonSets keys deleted)
    --   v3 = 2.0.8 dead-weight cleanup (rollFrame.autoRollOnSubmit,
    --        councilTable.rowHeight, voting.numButtons,
    --        winnerDetermination.requireConfirmation, legacy
    --        `responses` definitions table)
    --   v4 = 2.0.20 configurable loot filter (loot.filter.* namespace
    --        seeded from the old hardcoded BLACKLISTED_ITEM_CLASSES
    --        and Loothing.MinQuality)
    schemaVersion = 5,

    council = {
        members = {},
        autoIncludeOfficers = true,
        autoIncludeRaidLeader = true,
        minRank = 0,                -- Minimum guild rank index allowed on council (0 = no restriction)
    },

    -- Session triggering & voting policy. These are broadcast by the
    -- Master Looter via MLDB and shared with all clients during a session.
    session = {
        triggerAction = "prompt",        -- "manual" | "prompt" | "auto"
        triggerTiming = "encounterEnd",  -- "encounterEnd" | "afterLoot"
        scope = {
            raid = true,                 -- Auto-trigger on raid encounters
            dungeon = false,             -- Auto-trigger on dungeon encounters
            openWorld = false,           -- Auto-trigger on world group encounters
        },
        groupLootMode = "active",        -- "active" = Loothing auto-rolls, "passive" = Blizzard rolls
        groupLootGuildOnly = false,      -- Only use group-loot integration in guild groups
    },

    voting = {
        mode = Loothing.VotingMode.SIMPLE,  -- "SIMPLE" | "RANKED_CHOICE"
        timeout = 0,                -- 0 = no auto-close, >0 = seconds
        selfVote = false,           -- Allow council members to vote for themselves
        multiVote = false,          -- Allow voting for multiple candidates per item
        privacy = "open",           -- "open" | "hide_counts" | "anonymous"
        mlSeesVotes = false,        -- ML can see votes even when privacy ~= "open"
        autoAddRolls = true,        -- Automatically add /roll results to candidates
        requireNotes = false,       -- Require voters to add a note with their vote
        maxRanks = 0,               -- RCV: 0 = unlimited (rank all buttons)
        minRanks = 1,               -- RCV: minimum rankings required to submit
        maxRevotes = 2,             -- Maximum re-votes per item
        allowResponseChange = false, -- Allow players to change their response after submission
    },

    announcements = {
        announceAwards = true,
        announceItems = true,
        announceBossKill = false,
        announceConsiderations = false,  -- Announce items being considered

        -- Multi-line award announcements (up to 5 lines, each with channel + message)
        -- Tokens: {item}, {winner}, {reason}, {notes}, {ilvl}, {type}, {oldItem}, {ml}, {session}, {votes}
        awardLines = {
            { enabled = true, channel = "RAID", text = "{item} awarded to {winner} for {reason}" },
            { enabled = false, channel = "NONE", text = "" },
            { enabled = false, channel = "NONE", text = "" },
            { enabled = false, channel = "NONE", text = "" },
            { enabled = false, channel = "NONE", text = "" },
        },

        -- Multi-line item announcements (up to 5 lines)
        itemLines = {
            { enabled = true, channel = "RAID", text = "Now accepting rolls for {item} (iLvl {ilvl})" },
            { enabled = false, channel = "NONE", text = "" },
            { enabled = false, channel = "NONE", text = "" },
            { enabled = false, channel = "NONE", text = "" },
            { enabled = false, channel = "NONE", text = "" },
        },

        -- Considerations announcements (when ML is reviewing item)
        considerationsChannel = "RAID",
        considerationsText = "{ml} is considering {item} for distribution",

        -- Session announcements
        sessionStartChannel = "RAID",
        sessionStartText = "Loot council session started for {session}",
        sessionEndChannel = "RAID",
        sessionEndText = "Loot council session ended",
    },

    autoPass = {
        enabled = false,
        weapons = false,
        boe = false,
        transmog = false,
        trinkets = false,           -- Auto pass trinkets
        transmogSource = false,     -- Auto pass transmog sources
        silent = false,             -- Don't print auto-pass messages
    },

    ignoreItems = {
        enabled = true,
        items = {
            -- Format: [itemID] = true
            -- Example: [12345] = true
        },
        ignoreEnchantingMaterials = true,
        ignoreCraftingReagents = true,
        ignoreConsumables = true,
        ignorePermanentEnhancements = false,  -- gems, enchants, etc
    },

    autoAward = {
        enabled = false,
        lowerThreshold = 2,      -- Uncommon
        upperThreshold = 4,      -- Epic (items between lower and upper will be auto-awarded)
        awardTo = "",            -- Player name or "disenchanter"
        reasonId = nil,          -- Structured reason ID (references awardReasons.reasons[].id)
        includeBoE = false,      -- Include Bind on Equip items
    },

    -- v2.0.8: legacy `responses` definitions table removed. The
    -- response IDs themselves (Loothing.Response.NEED/GREED/etc., the
    -- numeric constants at the top of this file) are still alive, but
    -- the per-response display metadata (color/icon/sort/name) lives
    -- in `responseSets` which is the canonical model.

    awardReasons = {
        enabled = true,
        requireReason = false,    -- Require selecting a reason before awarding
        -- numReasons removed (source of truth is #reasons array)
        reasons = {
            { id = 1, name = "Main Spec", color = { 0.0, 1.0, 0.0, 1.0 }, sort = 1, log = true, disenchant = false },
            { id = 2, name = "Off Spec", color = { 1.0, 0.5, 0.0, 1.0 }, sort = 2, log = true, disenchant = false },
            { id = 3, name = "PvP", color = { 1.0, 0.0, 0.0, 1.0 }, sort = 3, log = true, disenchant = false },
            { id = 4, name = "Disenchant", color = { 0.5, 0.0, 0.5, 1.0 }, sort = 4, log = true, disenchant = true },
            { id = 5, name = "Free Roll", color = { 0.5, 0.5, 0.5, 1.0 }, sort = 5, log = true, disenchant = false },
            { id = 6, name = "Bank", color = { 0.3, 0.3, 0.8, 1.0 }, sort = 6, log = true, disenchant = false },
        },
    },

    frame = {
        skin = "Default",                -- Base UI theme
        accent = "Amber",                -- Accent palette
        density = "Comfortable",         -- Layout density
        autoOpen = false,                -- Auto open frames when loot available
        autoClose = false,               -- Auto close after session ends
        minimizeInCombat = false,        -- Hide frames during combat
        showSpecIcon = false,            -- Show spec icons instead of class
        closeWithEscape = false,         -- Allow ESC to close frames
        timeoutFlash = false,            -- Flash on voting timeout
        blockTradesDuringVoting = false, -- Block trades while voting
        chatFrameName = "ChatFrame1",    -- Output chat frame
        autoReshow = true,               -- Gently re-show frame after 30s if unresponded items exist
        uiScale = 1.0,                   -- Global UI scale (was settings.uiScale)
        position = nil,                  -- Saved main frame position { point, x, y } (was settings.mainFramePosition)
        showMinimapButton = true,        -- Show the minimap button (was settings.showMinimapButton / ui.showMinimapButton)
        minimapButtonAngle = nil,        -- Saved minimap button angle (was ui.minimapButtonAngle)
    },

    ml = {
        usageMode = "ask_gl",            -- "never", "gl" (group loot), "ask_gl"
        scope = "raids_only",            -- "raids_only" | "raids_and_dungeons" | "anywhere"
                                         -- Replaces onlyUseInRaids + allowOutOfRaid.
        skipSessionFrame = true,         -- Auto-start without session frame
        sortItems = false,               -- Auto-sort items
        autoAddBoEs = false,             -- Include BoE in auto-add
        printCompletedTrades = false,    -- Print trade confirmations
        rejectTrade = false,             -- Reject invalid trades
        awardLater = false,              -- Allow awarding to ML for later
        autoTrade = true,                -- Auto-initiate trades after award (was settings.autoTrade)
    },

    -- History settings (profile-scoped). The actual history entries
    -- live in the global scope under the SavedVariables `history` key
    -- so they survive profile switches; that table is initialized
    -- lazily by Settings:GetHistoryRef().
    history = {
        enabled = true,             -- Enable loot history
        share = "off",              -- "off" | "group" | "guild"  (replaces sendHistory + sendToGuild)
        savePersonalLoot = false,   -- Log personal loot items
        maxEntries = 500,           -- Hard cap for the shared history table
        autoExportWeb = false,      -- Show Web export dialog when session ends
    },

    -- Unified response sets (replaces separate responses + buttonSets)
    -- Per-button schema: { id, text, responseText, color{array}, icon, sort, whisperKeys{array} }
    responseSets = {
        activeSet = 1,
        sets = {
            [1] = {
                name = "Default",
                buttons = {
                    { id = 1, text = "Need",     responseText = "NEED",     color = { 0.0, 1.0, 0.0, 1.0 }, icon = "Interface\\Buttons\\UI-GroupLoot-Dice-Up", sort = 1, whisperKeys = { "need" } },
                    { id = 2, text = "Greed",    responseText = "GREED",    color = { 1.0, 1.0, 0.0, 1.0 }, icon = "Interface\\Buttons\\UI-GroupLoot-Coin-Up", sort = 2, whisperKeys = { "greed" } },
                    { id = 3, text = "Offspec",  responseText = "OFFSPEC",  color = { 1.0, 0.5, 0.0, 1.0 }, icon = "Interface\\Icons\\Ability_DualWield",     sort = 3, whisperKeys = { "offspec", "os" } },
                    { id = 4, text = "Transmog", responseText = "TRANSMOG", color = { 1.0, 0.0, 1.0, 1.0 }, icon = "Interface\\Icons\\INV_Arcane_Orb",        sort = 4, whisperKeys = { "transmog", "tmog" } },
                    { id = 5, text = "Pass",     responseText = "PASS",     color = { 0.5, 0.5, 0.5, 1.0 }, icon = "Interface\\Buttons\\UI-GroupLoot-Pass-Up",sort = 5, whisperKeys = { "pass" } },
                },
            },
            [2] = {
                name = "Gear Priority",
                buttons = {
                    { id = 1, text = "BIS",           responseText = "BIS",      color = { 1.0, 0.0, 0.0, 1.0 }, icon = "Interface\\Buttons\\UI-GroupLoot-Dice-Up", sort = 1, whisperKeys = { "bis" } },
                    { id = 2, text = "Major Upgrade",  responseText = "MAJOR",    color = { 0.0, 1.0, 0.0, 1.0 }, icon = nil,                                       sort = 2, whisperKeys = { "major", "upgrade" } },
                    { id = 3, text = "Minor Upgrade",  responseText = "MINOR",    color = { 1.0, 1.0, 0.0, 1.0 }, icon = nil,                                       sort = 3, whisperKeys = { "minor" } },
                    { id = 4, text = "Sidegrade",      responseText = "SIDEGRADE",color = { 1.0, 0.5, 0.0, 1.0 }, icon = nil,                                       sort = 4, whisperKeys = { "sidegrade", "side" } },
                    { id = 5, text = "Pass",           responseText = "PASS",     color = { 0.5, 0.5, 0.5, 1.0 }, icon = "Interface\\Buttons\\UI-GroupLoot-Pass-Up",sort = 5, whisperKeys = { "pass" } },
                },
            },
        },
        typeCodeMap = {},  -- typeCode -> setId (e.g., "WEAPON" -> 2)
    },

    filters = {
        enabled = true,
        byClass = {},              -- Table of class names to show (empty = all)
        byResponse = {},           -- Table of response IDs to show (empty = all)
        byGuildRank = {},          -- Table of guild rank indices to show (empty = all)
        showOnlyEquippable = false, -- Only show candidates who can equip the item
        hidePassedItems = true,     -- Hide items that have been passed on
    },

    groupLoot = {
        enabled = true,            -- Enable auto-roll on group loot
        hideFrames = true,         -- Hide GroupLootFrame UI after auto-rolling
        qualityThreshold = 4,      -- Minimum quality for auto-roll (4 = Epic)
    },

    -- ============================================================================
    -- Roll/Vote System Settings
    -- ============================================================================

    -- RollFrame settings (popup for raid members to respond to loot)
    rollFrame = {
        autoShow = true,           -- Auto-popup when voting starts
        rollRange = { min = 1, max = 100 },  -- Roll range
        showGearComparison = true, -- Show equipped gear comparison
        position = nil,            -- Saved position { point, x, y }
        timeoutEnabled = false,    -- Enable/disable timeout timer (off by default)
        timeoutDuration = 30,      -- Timeout duration in seconds (0-200), only used when enabled
    },

    -- CouncilTable settings (table view of candidates for ML/council)
    councilTable = {
        columns = {
            player = true,
            class = false,
            response = true,
            roll = true,
            note = true,
            ilvl = true,
            ilvlDiff = true,
            gear1 = true,
            gear2 = true,
            itemsWon = true,
            councilVotes = true,
            wishlist = true,
        },
        sortColumn = "response",
        sortAscending = true,
        -- v2.0.8: rowHeight removed. Was only ever read by an orphaned
        -- accessor; renderers all use a hardcoded row height.
    },

    -- Winner determination settings
    winnerDetermination = {
        mode = "ML_CONFIRM",       -- "HIGHEST_VOTES", "ML_CONFIRM", "AUTO_HIGHEST_CONFIRM"
        tieBreaker = "ROLL",       -- "ROLL", "ML_CHOICE", "REVOTE"
        autoAwardOnUnanimous = false,
        -- requireConfirmation removed: redundant with `mode`. ML_CONFIRM
        -- and AUTO_HIGHEST_CONFIRM imply confirmation; HIGHEST_VOTES does not.
    },

    observers = {
        list = {},                          -- ML-managed observer player names
        openObservation = false,            -- When true, all raid members can observe
        mlIsObserver = false,               -- ML sees everything but cannot vote
        permissions = {
            seeVoteCounts = true,
            seeVoterIdentities = false,
            seeResponses = true,
            seeNotes = false,
        },
    },

    -- Loot filter (configurable replacement for the old hardcoded
    -- BLACKLISTED_ITEM_CLASSES + Loothing.MinQuality. Mirrors the
    -- structure used by SchemaMigration v4 for newly-created profiles.
    -- See Core/SettingsLootFilter.lua for accessors.
    --
    -- Defaults are deliberately permissive: quality filtering is OFF
    -- (minQuality = 0) and only the most obvious non-loot classes are
    -- blocked. The class blocks only kick in for `auto` trigger mode —
    -- in `prompt` mode every item reaches the picker so the ML can
    -- override on a per-kill basis.
    loot = {
        filter = {
            minQuality = 0,                 -- 0 = no quality filtering; raise for auto-mode strictness
            classes = {
                [0]  = { blocked = true },                                          -- Consumables
                [5]  = { blocked = true },                                          -- Reagents
                [7]  = { blocked = true },                                          -- Tradeskill / recipes
                [12] = { blocked = true },                                          -- Quest items
                [15] = { blocked = false, subclasses = { [1] = true, [4] = true } }, -- Misc: Reagent + Other (Anima)
                [20] = { blocked = true },                                          -- Decor / Housing
            },
        },
    },
}

--[[--------------------------------------------------------------------
    Item Quality Thresholds
----------------------------------------------------------------------]]

Loothing.Quality = {
    POOR = 0,
    COMMON = 1,
    UNCOMMON = 2,
    RARE = 3,
    EPIC = 4,
    LEGENDARY = 5,
    ARTIFACT = 6,
    HEIRLOOM = 7,
}

-- Minimum quality to track (Epic+)
Loothing.MinQuality = Loothing.Quality.EPIC

--[[--------------------------------------------------------------------
    UI Constants
----------------------------------------------------------------------]]

Loothing.UIConstants = {
    MAIN_FRAME_WIDTH = 600,
    MAIN_FRAME_HEIGHT = 450,
    ITEM_ROW_HEIGHT = 40,
    VOTE_BUTTON_SIZE = 32,
    VOTER_ROW_HEIGHT = 24,
    PADDING = 8,
    SPACING = 4,
}

--[[--------------------------------------------------------------------
    Timing Constants
----------------------------------------------------------------------]]

Loothing.Timing = {
    NO_TIMEOUT = 0,             -- Sentinel: voting runs until ML manually ends it
    DEFAULT_VOTE_TIMEOUT = 30,
    VOTING_DEFAULT = 30,        -- Alias used in VotingSession / VotePanel
    MIN_VOTE_TIMEOUT = 10,
    MAX_VOTE_TIMEOUT = 120,
    VOTE_LATE_ACCEPT_WINDOW = 30, -- Seconds after timer expiry to still accept queued VOTE_COMMITs
    VOTE_POLL_DELAY = 5,          -- Seconds after tally before ML checks for missing council votes
    SYNC_TIMEOUT = 10,
    MESSAGE_THROTTLE = 0.1,     -- Seconds between messages
    -- CHUNK_SIZE removed: Loolib.Comm handles message chunking internally

    -- RollFrame timeout
    DEFAULT_ROLL_TIMEOUT = 30,
    MIN_ROLL_TIMEOUT = 5,       -- Minimum 5 seconds (0 would be instant timeout)
    MAX_ROLL_TIMEOUT = 200,

    -- Session prompt
    LOOT_DEBOUNCE_DELAY = 2.5,  -- Wait for all boss loot to distribute before prompting
    SESSION_PROMPT_TIMEOUT = 30, -- How long ML has to respond to session prompt
    LOOT_BUFFER_TTL = 60,       -- Max seconds to keep buffered loot (no session started)

    -- CommState: reconnect grace period
    RECONNECT_GRACE_PERIOD = 5, -- Suppress sync triggers for N seconds after reconnect
    RECONNECT_JITTER_SPREAD = 1.5, -- +/- seconds for reconnect timer jitter

    -- CommState: paced queue replay
    REPLAY_INTERVAL = 0.1,         -- 100ms between replay ticks
    REPLAY_PAUSE_PRESSURE = 0.6,   -- Pause replay above this queue pressure
    REPLAY_HARD_PRESSURE = 0.8,    -- ALERT-only above this queue pressure

    -- CommState: sync deduplication
    SYNC_DEDUP_WINDOW = 10,        -- Suppress duplicate sync requests within N seconds

    -- Heartbeat: jitter
    HEARTBEAT_JITTER = 5,          -- +/- seconds on heartbeat interval (25-35s)

    -- Sync storm prevention
    SYNC_JITTER_WINDOW = 8,         -- Spread client sync requests across N seconds after heartbeat mismatch
    SYNC_COALESCE_WINDOW = 2,       -- ML waits N seconds to collect sync requests before responding
    SYNC_CIRCUIT_THRESHOLD = 3,     -- Consecutive sync failures before opening circuit breaker
    SYNC_CIRCUIT_RESET = 120,       -- Seconds before retrying sync after circuit opens

    -- Response recovery
    RESPONSE_POLL_DELAY = 15,       -- Seconds after VOTE_REQUEST before ML polls missing responses

    -- ResponseTracker: RollFrame reopen after combat
    COMBAT_END_RECHECK_DELAY = 0.5, -- Delay after combat before re-showing RollFrame
    FRAME_REOPEN_DELAY = 30,        -- Seconds before gentle re-show of pending items

}

--[[--------------------------------------------------------------------
    Class Colors (backup if RAID_CLASS_COLORS unavailable)
----------------------------------------------------------------------]]

Loothing.ClassColors = {
    WARRIOR = { r = 0.78, g = 0.61, b = 0.43 },
    PALADIN = { r = 0.96, g = 0.55, b = 0.73 },
    HUNTER = { r = 0.67, g = 0.83, b = 0.45 },
    ROGUE = { r = 1.00, g = 0.96, b = 0.41 },
    PRIEST = { r = 1.00, g = 1.00, b = 1.00 },
    DEATHKNIGHT = { r = 0.77, g = 0.12, b = 0.23 },
    SHAMAN = { r = 0.00, g = 0.44, b = 0.87 },
    MAGE = { r = 0.41, g = 0.80, b = 0.94 },
    WARLOCK = { r = 0.58, g = 0.51, b = 0.79 },
    MONK = { r = 0.00, g = 1.00, b = 0.59 },
    DRUID = { r = 1.00, g = 0.49, b = 0.04 },
    DEMONHUNTER = { r = 0.64, g = 0.19, b = 0.79 },
    EVOKER = { r = 0.20, g = 0.58, b = 0.50 },
}

--[[--------------------------------------------------------------------
    Wishlist Need-Level Definitions
----------------------------------------------------------------------]]

Loothing.NeedLevel = {
    bis      = { label = "BiS",   color = { r = 1.0, g = 0.5, b = 0.0 } },
    major    = { label = "Major", color = { r = 0.0, g = 1.0, b = 0.0 } },
    minor    = { label = "Minor", color = { r = 1.0, g = 1.0, b = 0.0 } },
    optional = { label = "Opt",   color = { r = 0.6, g = 0.6, b = 0.6 } },
    transmog = { label = "Tmog",  color = { r = 1.0, g = 0.0, b = 1.0 } },
}
