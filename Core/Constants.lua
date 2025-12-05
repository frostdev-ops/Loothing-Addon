--[[--------------------------------------------------------------------
    Loothing - Loot Council Addon for WoW 12.0+
    Constants - Enums, defaults, and static values
----------------------------------------------------------------------]]

-- Addon info
LOOTHING_VERSION = "1.0.0"
LOOTHING_PROTOCOL_VERSION = 1
LOOTHING_ADDON_PREFIX = "LOOTHING"

--[[--------------------------------------------------------------------
    Response Types (for voting)
----------------------------------------------------------------------]]

LOOTHING_RESPONSE = {
    NEED = 1,
    GREED = 2,
    OFFSPEC = 3,
    TRANSMOG = 4,
    PASS = 5,
}

-- Response priority order (highest to lowest)
LOOTHING_RESPONSE_PRIORITY = {
    LOOTHING_RESPONSE.NEED,
    LOOTHING_RESPONSE.GREED,
    LOOTHING_RESPONSE.OFFSPEC,
    LOOTHING_RESPONSE.TRANSMOG,
    LOOTHING_RESPONSE.PASS,
}

-- Response display info
LOOTHING_RESPONSE_INFO = {
    [LOOTHING_RESPONSE.NEED] = {
        name = "NEED",
        color = { 0.0, 1.0, 0.0, 1.0 },       -- Green
        icon = "Interface\\Buttons\\UI-GroupLoot-Dice-Up",
    },
    [LOOTHING_RESPONSE.GREED] = {
        name = "GREED",
        color = { 1.0, 1.0, 0.0, 1.0 },       -- Yellow
        icon = "Interface\\Buttons\\UI-GroupLoot-Coin-Up",
    },
    [LOOTHING_RESPONSE.OFFSPEC] = {
        name = "OFFSPEC",
        color = { 1.0, 0.5, 0.0, 1.0 },       -- Orange
        icon = "Interface\\Icons\\Ability_DualWield",
    },
    [LOOTHING_RESPONSE.TRANSMOG] = {
        name = "TRANSMOG",
        color = { 1.0, 0.0, 1.0, 1.0 },       -- Magenta
        icon = "Interface\\Icons\\INV_Arcane_Orb",
    },
    [LOOTHING_RESPONSE.PASS] = {
        name = "PASS",
        color = { 0.5, 0.5, 0.5, 1.0 },       -- Gray
        icon = "Interface\\Buttons\\UI-GroupLoot-Pass-Up",
    },
}

--[[--------------------------------------------------------------------
    Session State
----------------------------------------------------------------------]]

LOOTHING_SESSION_STATE = {
    INACTIVE = 1,   -- No active session
    ACTIVE = 2,     -- Session in progress, items can be added
    CLOSED = 3,     -- No more items, finishing remaining votes
}

--[[--------------------------------------------------------------------
    Item State
----------------------------------------------------------------------]]

LOOTHING_ITEM_STATE = {
    PENDING = 1,    -- Item received, not yet voting
    VOTING = 2,     -- Votes being collected
    TALLIED = 3,    -- Votes counted, awaiting ML decision
    AWARDED = 4,    -- Winner announced
    SKIPPED = 5,    -- ML chose to skip/disenchant
}

--[[--------------------------------------------------------------------
    Voting Mode
----------------------------------------------------------------------]]

LOOTHING_VOTING_MODE = {
    SIMPLE = "SIMPLE",           -- Most votes for response type wins
    RANKED_CHOICE = "RANKED",    -- Instant runoff elimination
}

--[[--------------------------------------------------------------------
    Message Types (Communication Protocol)
----------------------------------------------------------------------]]

LOOTHING_MSG_TYPE = {
    -- Session management
    SESSION_START = "SS",       -- ML -> Raid: Start session
    SESSION_END = "SE",         -- ML -> Raid: End session

    -- Item management
    ITEM_ADD = "IA",            -- ML -> Raid: Add item to session
    ITEM_REMOVE = "IR",         -- ML -> Raid: Remove item

    -- Voting
    VOTE_REQUEST = "VR",        -- ML -> Council: Request votes
    VOTE_COMMIT = "VC",         -- Council -> ML: Submit vote
    VOTE_CANCEL = "VX",         -- ML -> Council: Cancel voting

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
    SYNC_SETTINGS_ACK = "SSA",       -- Target -> ML: Accept settings sync
    SYNC_SETTINGS_DATA = "SSD",      -- ML -> Target: Settings payload
    SYNC_HISTORY_REQUEST = "SHR",    -- ML -> Target: Request to sync history
    SYNC_HISTORY_ACK = "SHA",        -- Target -> ML: Accept history sync
    SYNC_HISTORY_DATA = "SHD",       -- ML -> Target: History payload

    -- Chunked messages
    CHUNK = "C",                -- Chunked message part
}

--[[--------------------------------------------------------------------
    Default Settings
----------------------------------------------------------------------]]

LOOTHING_DEFAULT_SETTINGS = {
    version = 1,

    council = {
        members = {},
        autoIncludeOfficers = true,
        autoIncludeRaidLeader = true,
    },

    settings = {
        votingMode = LOOTHING_VOTING_MODE.SIMPLE,
        votingTimeout = 30,
        autoStartSession = false,
        showMinimapButton = true,
        announceAwards = true,
        announceChannel = "RAID",
        uiScale = 1.0,
        mainFramePosition = nil,
    },

    autoPass = {
        enabled = true,
        weapons = true,
        boe = false,
        transmog = false,
    },

    responses = {
        [LOOTHING_RESPONSE.NEED] = {
            name = "NEED",
            color = { 0.0, 1.0, 0.0, 1.0 },
            icon = "Interface\\Buttons\\UI-GroupLoot-Dice-Up",
            sort = 1,
        },
        [LOOTHING_RESPONSE.GREED] = {
            name = "GREED",
            color = { 1.0, 1.0, 0.0, 1.0 },
            icon = "Interface\\Buttons\\UI-GroupLoot-Coin-Up",
            sort = 2,
        },
        [LOOTHING_RESPONSE.OFFSPEC] = {
            name = "OFFSPEC",
            color = { 1.0, 0.5, 0.0, 1.0 },
            icon = "Interface\\Icons\\Ability_DualWield",
            sort = 3,
        },
        [LOOTHING_RESPONSE.TRANSMOG] = {
            name = "TRANSMOG",
            color = { 1.0, 0.0, 1.0, 1.0 },
            icon = "Interface\\Icons\\INV_Arcane_Orb",
            sort = 4,
        },
        [LOOTHING_RESPONSE.PASS] = {
            name = "PASS",
            color = { 0.5, 0.5, 0.5, 1.0 },
            icon = "Interface\\Buttons\\UI-GroupLoot-Pass-Up",
            sort = 5,
        },
    },

    history = {},
}

--[[--------------------------------------------------------------------
    Item Quality Thresholds
----------------------------------------------------------------------]]

LOOTHING_QUALITY = {
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
LOOTHING_MIN_QUALITY = LOOTHING_QUALITY.EPIC

--[[--------------------------------------------------------------------
    UI Constants
----------------------------------------------------------------------]]

LOOTHING_UI = {
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

LOOTHING_TIMING = {
    DEFAULT_VOTE_TIMEOUT = 30,
    MIN_VOTE_TIMEOUT = 10,
    MAX_VOTE_TIMEOUT = 120,
    SYNC_TIMEOUT = 10,
    MESSAGE_THROTTLE = 0.1,     -- Seconds between messages
    CHUNK_SIZE = 240,           -- Max chars per chunk (leave room for header)
}

--[[--------------------------------------------------------------------
    Class Colors (backup if RAID_CLASS_COLORS unavailable)
----------------------------------------------------------------------]]

LOOTHING_CLASS_COLORS = {
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
