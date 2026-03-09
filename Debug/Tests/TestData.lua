--[[--------------------------------------------------------------------
    Loothing - Loot Council Addon for WoW 12.0+
    TestData - Comprehensive test fixtures and mock data for testing

    This module provides realistic test data for:
    - Item data (weapons, armor, trinkets, tokens) from TWW/DF
    - Player fixtures (tanks, healers, DPS) with full raid compositions
    - Vote scenarios (simple majority, ties, ranked choice, edge cases)
    - Session scenarios (normal raids, stress tests, edge cases)
    - History entries (valid, malformed, import data)
    - Communication protocol test data
    - Auto-pass test cases
    - Encounter data (TWW Season 1+ raid bosses)

    Usage:
        local TestData = TestData
        local trinket = TestData.Items.Trinkets[1]
        local tank = TestData.Players.Tank
        local scenario = TestData.VoteScenarios.SimpleMajority
----------------------------------------------------------------------]]

local _, ns = ...
local Loothing = ns.Addon
local Utils = ns.Utils

--[[--------------------------------------------------------------------
    Global TestData Table
----------------------------------------------------------------------]]

TestData = {}
local TestData = TestData

--[[====================================================================
    ITEM DATA - Modern TWW/DF Items

    All IDs are realistic and can be tested in-game.
    Organized by type and expansion tier.
======================================================================]]

TestData.Items = {}

--[[--------------------------------------------------------------------
    The War Within Season 1 - Nerub-ar Palace (Raid Tier 11.0.2)
    Instance ID: 1273
----------------------------------------------------------------------]]

-- Weapons (15+ realistic IDs from TWW Season 1)
TestData.Items.Weapons = {
    -- Two-Handed
    212405, -- Regicide (2H Sword)
    212406, -- Anub'ikkaj's Hammer (2H Mace)
    212407, -- Anu'barash's Fury (2H Axe)
    212408, -- Silken Court Greatstaff (Staff)

    -- One-Handed
    212409, -- Voracious Bloodblade (1H Sword)
    212410, -- Sikran's Shadowdagger (Dagger)
    212411, -- Rasha's Ritual Knife (Dagger)
    212412, -- Queen's Vengeance (1H Mace)
    212413, -- Broodkeeper's Glaive (Warglaive)

    -- Ranged
    212414, -- Umbral Webspinner (Bow)
    212415, -- Nether-gorger's Handcannon (Gun)
    212416, -- Xal'atath's Wand (Wand)

    -- Off-hands
    212417, -- Shield of the Scarab Lord (Shield)
    212418, -- Tome of Eternal Whispers (Off-hand)
}

-- Armor organized by type
TestData.Items.Armor = {
    -- Cloth (Mage, Priest, Warlock)
    Cloth = {
        212450, -- Whispering Veil (Head)
        212451, -- Robes of the Sureki (Chest)
        212452, -- Silkweaver's Gloves (Hands)
        212453, -- Leggings of Dark Omens (Legs)
        212454, -- Mantle of the Awakened (Shoulders)
        212455, -- Girdle of Forgotten Knowledge (Waist)
        212456, -- Slippers of the Void (Feet)
        212457, -- Bindings of the Harbinger (Wrists)
    },

    -- Leather (Druid, Demon Hunter, Monk, Rogue)
    Leather = {
        212460, -- Cowl of the Silent Predator (Head)
        212461, -- Cuirass of the Nerub Warden (Chest)
        212462, -- Grips of the Web Master (Hands)
        212463, -- Legguards of the Skittering Swarm (Legs)
        212464, -- Spaulders of the Silk Reaper (Shoulders)
        212465, -- Belt of the Venomous (Waist)
        212466, -- Boots of the Stalking Shadow (Feet)
        212467, -- Bracers of the Chitinous (Wrists)
    },

    -- Mail (Hunter, Shaman, Evoker)
    Mail = {
        212470, -- Helm of the Nerubian Lord (Head)
        212471, -- Hauberk of the Sureki Empire (Chest)
        212472, -- Gauntlets of the Web Queen (Hands)
        212473, -- Greaves of the Skittering Host (Legs)
        212474, -- Pauldrons of the Silk Court (Shoulders)
        212475, -- Cincture of the Arachnid (Waist)
        212476, -- Treads of the Spider Monarch (Feet)
        212477, -- Vambraces of the Chittering (Wrists)
    },

    -- Plate (Warrior, Paladin, Death Knight)
    Plate = {
        212480, -- Crown of the Sureki Sovereign (Head)
        212481, -- Breastplate of the Nerubian Guard (Chest)
        212482, -- Crushers of the Black Blood (Hands)
        212483, -- Legplates of the Void Touched (Legs)
        212484, -- Shoulderplates of the Scarab (Shoulders)
        212485, -- Waistguard of the Silken Guard (Waist)
        212486, -- Sabatons of the Royal Court (Feet)
        212487, -- Vambraces of the Spider Lord (Wrists)
    },
}

-- Trinkets (10+ with realistic stat distributions)
TestData.Items.Trinkets = {
    -- Tank trinkets
    212500, -- Viscous Chitin (Tank, armor proc)
    212501, -- Nerubian Pheromones (Tank, avoidance)

    -- Strength trinkets
    212502, -- Spymaster's Web (Strength DPS, crit proc)
    212503, -- Ovinax's Mercurial Egg (Strength DPS/Tank, versatility)

    -- Agility trinkets
    212504, -- Sikran's Endless Arsenal (Agility DPS, haste proc)
    212505, -- Mad Queen's Mandate (Agility DPS, mastery)

    -- Intellect DPS trinkets
    212506, -- Ara-Kara Sacbrood (Int DPS, intellect proc)
    212507, -- Void Reaper's Contract (Int DPS, crit)

    -- Healer trinkets
    212508, -- Swarmlord's Authority (Healer, mana regen)
    212509, -- Queen Ansurek's Pact (Healer, healing proc)

    -- Universal
    212510, -- Quickwick Candlestick (Universal, movement speed)
}

-- Tier Tokens (from TokenData.lua - TWW Season 1)
TestData.Items.Tokens = {
    -- Dreadful (Plate: DK, Paladin, Warrior)
    225614, -- Dreadful Blasphemer's Effigy (Chest)
    225618, -- Dreadful Stalwart's Emblem (Hands)
    225622, -- Dreadful Conniver's Badge (Head)
    225626, -- Dreadful Slayer's Icon (Legs)
    225630, -- Dreadful Obscenity's Idol (Shoulders)

    -- Mystic (Leather: DH, Druid, Monk, Rogue)
    225615, -- Mystic Blasphemer's Effigy (Chest)
    225619, -- Mystic Stalwart's Emblem (Hands)
    225623, -- Mystic Conniver's Badge (Head)
    225627, -- Mystic Slayer's Icon (Legs)
    225631, -- Mystic Obscenity's Idol (Shoulders)

    -- Venerated (Mail: Evoker, Hunter, Shaman)
    225616, -- Venerated Blasphemer's Effigy (Chest)
    225620, -- Venerated Stalwart's Emblem (Hands)
    225624, -- Venerated Conniver's Badge (Head)
    225628, -- Venerated Slayer's Icon (Legs)
    225632, -- Venerated Obscenity's Idol (Shoulders)

    -- Zenith (Cloth: Mage, Priest, Warlock)
    225617, -- Zenith Blasphemer's Effigy (Chest)
    225621, -- Zenith Stalwart's Emblem (Hands)
    225625, -- Zenith Conniver's Badge (Head)
    225629, -- Zenith Slayer's Icon (Legs)
    225633, -- Zenith Obscenity's Idol (Shoulders)
}

-- Mythic+ Dungeon Items (TWW Season 1)
TestData.Items.MythicPlus = {
    212520, -- Darkflame Halberd (Darkflame Cleft)
    212521, -- Cinderbee Stompers (Cinderbrew Meadery)
    212522, -- Mire's Malice (Priory of the Sacred Flame)
    212523, -- Dawnbreaker's Winged Crown (The Dawnbreaker)
    212524, -- Rookery's Signet (The Rookery)
    212525, -- Stonevault Warhelm (The Stonevault)
    212526, -- Ara-Kara Carapace (Ara-Kara, City of Echoes)
    212527, -- City of Threads Vestments (City of Threads)
}

-- Legacy Items (for backward compatibility testing)
TestData.Items.Legacy = {
    -- Classic legendaries
    19019, -- Thunderfury, Blessed Blade of the Windseeker
    17182, -- Sulfuras, Hand of Ragnaros
    21134, -- Cloak of Clarity (AQ40)

    -- TBC
    30916, -- Vashj's Vial Remnant (SSC)
    32837, -- Warglaive of Azzinoth (BT)

    -- Wrath
    50274, -- Shadowmourne (ICC)

    -- Cata
    71617, -- Crystallized Firestone (Firelands)
}

--[[====================================================================
    PLAYER DATA

    Pre-built player fixtures with realistic names, classes, and specs.
    Includes individual fixtures and full raid compositions.
======================================================================]]

TestData.Players = {}
TestData.Classes = {}

-- Individual player fixtures by role
TestData.Players.Tank = {
    name = "Tankmaster-TestRealm",
    class = "WARRIOR",
    classID = 1,
    specIndex = 3, -- Protection
    specName = "Protection",
    role = "TANK",
    level = 80,
    itemLevel = 626,
    realm = "TestRealm",
    guildRank = "Raider",
    guildRankIndex = 3,
}

TestData.Players.Healer = {
    name = "Healbot-TestRealm",
    class = "PRIEST",
    classID = 5,
    specIndex = 2, -- Holy
    specName = "Holy",
    role = "HEALER",
    level = 80,
    itemLevel = 623,
    realm = "TestRealm",
    guildRank = "Raider",
    guildRankIndex = 3,
}

TestData.Players.MeleeDPS = {
    name = "Stabbyface-TestRealm",
    class = "ROGUE",
    classID = 4,
    specIndex = 1, -- Assassination
    specName = "Assassination",
    role = "DAMAGER",
    level = 80,
    itemLevel = 620,
    realm = "TestRealm",
    guildRank = "Member",
    guildRankIndex = 4,
}

TestData.Players.RangedDPS = {
    name = "Pewpew-TestRealm",
    class = "HUNTER",
    classID = 3,
    specIndex = 1, -- Beast Mastery
    specName = "Beast Mastery",
    role = "DAMAGER",
    level = 80,
    itemLevel = 618,
    realm = "TestRealm",
    guildRank = "Member",
    guildRankIndex = 4,
}

TestData.Players.MasterLooter = {
    name = "Lootmaster-TestRealm",
    class = "PALADIN",
    classID = 2,
    specIndex = 2, -- Protection
    specName = "Protection",
    role = "TANK",
    level = 80,
    itemLevel = 630,
    realm = "TestRealm",
    guildRank = "Officer",
    guildRankIndex = 1,
    isML = true,
}

-- Full raid composition (20 players)
TestData.Players.FullRaid = {
    -- Tanks (2)
    { name = "Tankmaster-TestRealm", class = "WARRIOR", classID = 1, specIndex = 3, role = "TANK", itemLevel = 626 },
    { name = "Holytank-TestRealm", class = "PALADIN", classID = 2, specIndex = 2, role = "TANK", itemLevel = 625 },

    -- Healers (4)
    { name = "Healbot-TestRealm", class = "PRIEST", classID = 5, specIndex = 2, role = "HEALER", itemLevel = 623 },
    { name = "Treehugger-TestRealm", class = "DRUID", classID = 11, specIndex = 4, role = "HEALER", itemLevel = 622 },
    { name = "Chainmail-TestRealm", class = "SHAMAN", classID = 7, specIndex = 3, role = "HEALER", itemLevel = 621 },
    { name = "Holylight-TestRealm", class = "PALADIN", classID = 2, specIndex = 1, role = "HEALER", itemLevel = 620 },

    -- Melee DPS (7)
    { name = "Stabbyface-TestRealm", class = "ROGUE", classID = 4, specIndex = 1, role = "DAMAGER", itemLevel = 620 },
    { name = "Backstabber-TestRealm", class = "ROGUE", classID = 4, specIndex = 3, role = "DAMAGER", itemLevel = 619 },
    { name = "Frostbite-TestRealm", class = "DEATHKNIGHT", classID = 6, specIndex = 2, role = "DAMAGER", itemLevel = 618 },
    { name = "Demonslayer-TestRealm", class = "DEMONHUNTER", classID = 12, specIndex = 1, role = "DAMAGER", itemLevel = 617 },
    { name = "Catface-TestRealm", class = "DRUID", classID = 11, specIndex = 2, role = "DAMAGER", itemLevel = 616 },
    { name = "Spintowin-TestRealm", class = "WARRIOR", classID = 1, specIndex = 2, role = "DAMAGER", itemLevel = 615 },
    { name = "Holysmash-TestRealm", class = "PALADIN", classID = 2, specIndex = 3, role = "DAMAGER", itemLevel = 614 },

    -- Ranged DPS (7)
    { name = "Pewpew-TestRealm", class = "HUNTER", classID = 3, specIndex = 1, role = "DAMAGER", itemLevel = 618 },
    { name = "Boomkin-TestRealm", class = "DRUID", classID = 11, specIndex = 1, role = "DAMAGER", itemLevel = 617 },
    { name = "Fireball-TestRealm", class = "MAGE", classID = 8, specIndex = 2, role = "DAMAGER", itemLevel = 616 },
    { name = "Frostbolt-TestRealm", class = "MAGE", classID = 8, specIndex = 3, role = "DAMAGER", itemLevel = 615 },
    { name = "Shadowpriest-TestRealm", class = "PRIEST", classID = 5, specIndex = 3, role = "DAMAGER", itemLevel = 614 },
    { name = "Demonlock-TestRealm", class = "WARLOCK", classID = 9, specIndex = 2, role = "DAMAGER", itemLevel = 613 },
    { name = "Lightningbolt-TestRealm", class = "SHAMAN", classID = 7, specIndex = 1, role = "DAMAGER", itemLevel = 612 },
}

-- Council (5 officers/trusted raiders)
TestData.Players.Council = {
    { name = "Lootmaster-TestRealm", class = "PALADIN", classID = 2, specIndex = 2, role = "TANK", guildRank = "Officer", isML = true },
    { name = "Raidleader-TestRealm", class = "WARRIOR", classID = 1, specIndex = 3, role = "TANK", guildRank = "Officer" },
    { name = "Healinglord-TestRealm", class = "PRIEST", classID = 5, specIndex = 2, role = "HEALER", guildRank = "Officer" },
    { name = "Dpsgod-TestRealm", class = "ROGUE", classID = 4, specIndex = 1, role = "DAMAGER", guildRank = "Raider" },
    { name = "Strategist-TestRealm", class = "MAGE", classID = 8, specIndex = 2, role = "DAMAGER", guildRank = "Officer" },
}

-- Class data (all 13 classes with full spec info)
TestData.Classes = {
    [1] = {
        name = "WARRIOR",
        displayName = "Warrior",
        armorType = "PLATE",
        specs = {
            { id = 1, name = "Arms", role = "DAMAGER" },
            { id = 2, name = "Fury", role = "DAMAGER" },
            { id = 3, name = "Protection", role = "TANK" },
        },
    },
    [2] = {
        name = "PALADIN",
        displayName = "Paladin",
        armorType = "PLATE",
        specs = {
            { id = 1, name = "Holy", role = "HEALER" },
            { id = 2, name = "Protection", role = "TANK" },
            { id = 3, name = "Retribution", role = "DAMAGER" },
        },
    },
    [3] = {
        name = "HUNTER",
        displayName = "Hunter",
        armorType = "MAIL",
        specs = {
            { id = 1, name = "Beast Mastery", role = "DAMAGER" },
            { id = 2, name = "Marksmanship", role = "DAMAGER" },
            { id = 3, name = "Survival", role = "DAMAGER" },
        },
    },
    [4] = {
        name = "ROGUE",
        displayName = "Rogue",
        armorType = "LEATHER",
        specs = {
            { id = 1, name = "Assassination", role = "DAMAGER" },
            { id = 2, name = "Outlaw", role = "DAMAGER" },
            { id = 3, name = "Subtlety", role = "DAMAGER" },
        },
    },
    [5] = {
        name = "PRIEST",
        displayName = "Priest",
        armorType = "CLOTH",
        specs = {
            { id = 1, name = "Discipline", role = "HEALER" },
            { id = 2, name = "Holy", role = "HEALER" },
            { id = 3, name = "Shadow", role = "DAMAGER" },
        },
    },
    [6] = {
        name = "DEATHKNIGHT",
        displayName = "Death Knight",
        armorType = "PLATE",
        specs = {
            { id = 1, name = "Blood", role = "TANK" },
            { id = 2, name = "Frost", role = "DAMAGER" },
            { id = 3, name = "Unholy", role = "DAMAGER" },
        },
    },
    [7] = {
        name = "SHAMAN",
        displayName = "Shaman",
        armorType = "MAIL",
        specs = {
            { id = 1, name = "Elemental", role = "DAMAGER" },
            { id = 2, name = "Enhancement", role = "DAMAGER" },
            { id = 3, name = "Restoration", role = "HEALER" },
        },
    },
    [8] = {
        name = "MAGE",
        displayName = "Mage",
        armorType = "CLOTH",
        specs = {
            { id = 1, name = "Arcane", role = "DAMAGER" },
            { id = 2, name = "Fire", role = "DAMAGER" },
            { id = 3, name = "Frost", role = "DAMAGER" },
        },
    },
    [9] = {
        name = "WARLOCK",
        displayName = "Warlock",
        armorType = "CLOTH",
        specs = {
            { id = 1, name = "Affliction", role = "DAMAGER" },
            { id = 2, name = "Demonology", role = "DAMAGER" },
            { id = 3, name = "Destruction", role = "DAMAGER" },
        },
    },
    [10] = {
        name = "MONK",
        displayName = "Monk",
        armorType = "LEATHER",
        specs = {
            { id = 1, name = "Brewmaster", role = "TANK" },
            { id = 2, name = "Mistweaver", role = "HEALER" },
            { id = 3, name = "Windwalker", role = "DAMAGER" },
        },
    },
    [11] = {
        name = "DRUID",
        displayName = "Druid",
        armorType = "LEATHER",
        specs = {
            { id = 1, name = "Balance", role = "DAMAGER" },
            { id = 2, name = "Feral", role = "DAMAGER" },
            { id = 3, name = "Guardian", role = "TANK" },
            { id = 4, name = "Restoration", role = "HEALER" },
        },
    },
    [12] = {
        name = "DEMONHUNTER",
        displayName = "Demon Hunter",
        armorType = "LEATHER",
        specs = {
            { id = 1, name = "Havoc", role = "DAMAGER" },
            { id = 2, name = "Vengeance", role = "TANK" },
        },
    },
    [13] = {
        name = "EVOKER",
        displayName = "Evoker",
        armorType = "MAIL",
        specs = {
            { id = 1, name = "Devastation", role = "DAMAGER" },
            { id = 2, name = "Preservation", role = "HEALER" },
            { id = 3, name = "Augmentation", role = "DAMAGER" },
        },
    },
}

--[[====================================================================
    VOTE SCENARIOS

    Pre-configured voting scenarios for testing different vote outcomes.
    Each scenario includes votes and expected results.
======================================================================]]

TestData.VoteScenarios = {}

-- Simple majority - NEED wins
TestData.VoteScenarios.SimpleMajority = {
    description = "Three voters, NEED wins with 2 votes",
    votes = {
        { voter = "Player1-TestRealm", candidate = "Winner-TestRealm", responses = { Loothing.Response.NEED } },
        { voter = "Player2-TestRealm", candidate = "Winner-TestRealm", responses = { Loothing.Response.NEED } },
        { voter = "Player3-TestRealm", candidate = "Loser-TestRealm", responses = { Loothing.Response.GREED } },
    },
    expectedWinner = "Winner-TestRealm",
    expectedResponse = Loothing.Response.NEED,
}

-- Tie scenario
TestData.VoteScenarios.TieBreaker = {
    description = "Two candidates with equal votes, requires tie-breaker",
    votes = {
        { voter = "Player1-TestRealm", candidate = "Candidate1-TestRealm", responses = { Loothing.Response.NEED } },
        { voter = "Player2-TestRealm", candidate = "Candidate1-TestRealm", responses = { Loothing.Response.NEED } },
        { voter = "Player3-TestRealm", candidate = "Candidate2-TestRealm", responses = { Loothing.Response.NEED } },
        { voter = "Player4-TestRealm", candidate = "Candidate2-TestRealm", responses = { Loothing.Response.NEED } },
    },
    expectedWinner = nil, -- Requires manual tie-breaking
    isTied = true,
}

-- Ranked choice voting (instant runoff)
TestData.VoteScenarios.RankedChoice = {
    description = "Ranked choice with 3 candidates, elimination rounds",
    votes = {
        { voter = "Player1-TestRealm", candidate = "CandidateA-TestRealm", responses = { Loothing.Response.NEED, Loothing.Response.GREED, Loothing.Response.OFFSPEC } },
        { voter = "Player2-TestRealm", candidate = "CandidateB-TestRealm", responses = { Loothing.Response.GREED, Loothing.Response.NEED, Loothing.Response.OFFSPEC } },
        { voter = "Player3-TestRealm", candidate = "CandidateC-TestRealm", responses = { Loothing.Response.OFFSPEC, Loothing.Response.NEED, Loothing.Response.GREED } },
        { voter = "Player4-TestRealm", candidate = "CandidateA-TestRealm", responses = { Loothing.Response.NEED, Loothing.Response.OFFSPEC, Loothing.Response.GREED } },
        { voter = "Player5-TestRealm", candidate = "CandidateB-TestRealm", responses = { Loothing.Response.GREED, Loothing.Response.OFFSPEC, Loothing.Response.NEED } },
    },
    votingMode = Loothing.VotingMode.RANKED_CHOICE,
}

-- Edge case: Single voter
TestData.VoteScenarios.SingleVoter = {
    description = "Only one council member votes",
    votes = {
        { voter = "Player1-TestRealm", candidate = "Winner-TestRealm", responses = { Loothing.Response.NEED } },
    },
    expectedWinner = "Winner-TestRealm",
    expectedResponse = Loothing.Response.NEED,
}

-- Edge case: All pass
TestData.VoteScenarios.AllPass = {
    description = "All candidates pass on the item",
    votes = {
        { voter = "Player1-TestRealm", candidate = "Candidate1-TestRealm", responses = { Loothing.Response.PASS } },
        { voter = "Player2-TestRealm", candidate = "Candidate2-TestRealm", responses = { Loothing.Response.PASS } },
        { voter = "Player3-TestRealm", candidate = "Candidate3-TestRealm", responses = { Loothing.Response.PASS } },
    },
    expectedWinner = nil,
    allPassed = true,
}

-- Edge case: Unanimous decision
TestData.VoteScenarios.Unanimous = {
    description = "All voters choose the same candidate with same response",
    votes = {
        { voter = "Player1-TestRealm", candidate = "Winner-TestRealm", responses = { Loothing.Response.NEED } },
        { voter = "Player2-TestRealm", candidate = "Winner-TestRealm", responses = { Loothing.Response.NEED } },
        { voter = "Player3-TestRealm", candidate = "Winner-TestRealm", responses = { Loothing.Response.NEED } },
        { voter = "Player4-TestRealm", candidate = "Winner-TestRealm", responses = { Loothing.Response.NEED } },
        { voter = "Player5-TestRealm", candidate = "Winner-TestRealm", responses = { Loothing.Response.NEED } },
    },
    expectedWinner = "Winner-TestRealm",
    expectedResponse = Loothing.Response.NEED,
    isUnanimous = true,
}

-- Edge case: No votes submitted
TestData.VoteScenarios.NoVotes = {
    description = "Voting timed out with no votes",
    votes = {},
    expectedWinner = nil,
    timedOut = true,
}

-- Complex: Multi-response priority
TestData.VoteScenarios.MultiResponsePriority = {
    description = "Multiple candidates with different response types",
    votes = {
        { voter = "Player1-TestRealm", candidate = "NeedPlayer-TestRealm", responses = { Loothing.Response.NEED } },
        { voter = "Player2-TestRealm", candidate = "GreedPlayer-TestRealm", responses = { Loothing.Response.GREED } },
        { voter = "Player3-TestRealm", candidate = "GreedPlayer-TestRealm", responses = { Loothing.Response.GREED } },
        { voter = "Player4-TestRealm", candidate = "OffspecPlayer-TestRealm", responses = { Loothing.Response.OFFSPEC } },
        { voter = "Player5-TestRealm", candidate = "NeedPlayer-TestRealm", responses = { Loothing.Response.NEED } },
    },
    expectedWinner = "NeedPlayer-TestRealm", -- NEED beats GREED even with fewer votes
    expectedResponse = Loothing.Response.NEED,
}

--[[====================================================================
    SESSION SCENARIOS

    Pre-configured session scenarios for testing different raid situations.
======================================================================]]

TestData.SessionScenarios = {}

-- Normal raid session
TestData.SessionScenarios.NormalRaid = {
    description = "Typical 20-player raid with 5 items",
    encounterID = 2902, -- Ulgrax the Devourer (example)
    encounterName = "Ulgrax the Devourer",
    instanceID = 1273, -- Nerub-ar Palace
    instanceName = "Nerub-ar Palace",
    difficulty = 15, -- Heroic
    itemCount = 5,
    memberCount = 20,
    councilCount = 5,
}

-- Stress test
TestData.SessionScenarios.StressTest = {
    description = "Stress test with many items and players",
    encounterID = 2902,
    encounterName = "Ulgrax the Devourer",
    instanceID = 1273,
    instanceName = "Nerub-ar Palace",
    difficulty = 16, -- Mythic
    itemCount = 50,
    memberCount = 40, -- Full mythic raid
    councilCount = 10,
}

-- Edge case: Empty session
TestData.SessionScenarios.EmptySession = {
    description = "Session with no items looted",
    encounterID = 2902,
    encounterName = "Ulgrax the Devourer",
    instanceID = 1273,
    instanceName = "Nerub-ar Palace",
    difficulty = 14, -- Normal
    itemCount = 0,
    memberCount = 15,
    councilCount = 5,
}

-- Edge case: Single item
TestData.SessionScenarios.SingleItem = {
    description = "Session with only one item",
    encounterID = 2902,
    encounterName = "Ulgrax the Devourer",
    instanceID = 1273,
    instanceName = "Nerub-ar Palace",
    difficulty = 15, -- Heroic
    itemCount = 1,
    memberCount = 5, -- Small group
    councilCount = 3,
}

-- Mythic+ dungeon session
TestData.SessionScenarios.MythicPlus = {
    description = "Mythic+ dungeon with 5 players",
    encounterID = nil, -- No encounter ID for M+
    encounterName = "End of Dungeon",
    instanceID = 1274, -- Example dungeon
    instanceName = "The Stonevault",
    difficulty = 23, -- Mythic Keystone
    keystoneLevel = 12,
    itemCount = 3,
    memberCount = 5,
    councilCount = 5, -- All members vote in small groups
}

--[[====================================================================
    HISTORY ENTRIES

    Valid and malformed history entries for import/export testing.
======================================================================]]

TestData.HistoryEntries = {}

-- Valid entry
TestData.HistoryEntries.ValidEntry = {
    timestamp = 1701907800, -- 2025-12-06 03:30:00
    winner = "Player-TestRealm",
    itemName = "Regicide",
    itemLink = "|cffa335ee|Hitem:212405::::::::80:1::3:1:28:2905:::::|h[Regicide]|h|r",
    itemID = 212405,
    response = Loothing.Response.NEED,
    responseName = "NEED",
    votes = 5,
    class = "WARRIOR",
    encounterID = 2902,
    encounterName = "Ulgrax the Devourer",
    instanceID = 1273,
    instanceName = "Nerub-ar Palace",
    difficulty = 15, -- Heroic
    difficultyName = "Heroic",
    itemLevel = 626,
    notes = "BiS for main spec",
    sessionID = "session_12345",
    masterLooter = "Lootmaster-TestRealm",
}

-- CSV import data (valid)
TestData.HistoryEntries.CSVImportData = [[Date,Item,ItemID,Winner,Response,Votes,Notes,Encounter,EncounterID,Class,ItemLevel
2025-12-06 03:30:00,Regicide,212405,Player-TestRealm,Need,5,BiS for main spec,Ulgrax the Devourer,2902,WARRIOR,626
2025-12-06 03:45:00,Robes of the Sureki,212451,Healer-TestRealm,Need,4,Upgrade,Ulgrax the Devourer,2902,PRIEST,623
2025-12-06 04:00:00,Spymaster's Web,212502,Dps-TestRealm,Greed,3,Minor upgrade,Ulgrax the Devourer,2902,ROGUE,620]]

-- TSV import data (valid)
TestData.HistoryEntries.TSVImportData = [[Date	Item	ItemID	Winner	Response	Votes	Notes	Encounter	EncounterID	Class	ItemLevel
2025-12-06 03:30:00	Regicide	212405	Player-TestRealm	Need	5	BiS for main spec	Ulgrax the Devourer	2902	WARRIOR	626
2025-12-06 03:45:00	Robes of the Sureki	212451	Healer-TestRealm	Need	4	Upgrade	Ulgrax the Devourer	2902	PRIEST	623
2025-12-06 04:00:00	Spymaster's Web	212502	Dps-TestRealm	Greed	3	Minor upgrade	Ulgrax the Devourer	2902	ROGUE	620]]

-- Malformed: Missing required fields
TestData.HistoryEntries.MissingFields = {
    timestamp = 1701907800,
    winner = "Player-TestRealm",
    -- Missing itemName, itemID
    response = Loothing.Response.NEED,
    votes = 5,
}

-- Malformed: Invalid date format
TestData.HistoryEntries.InvalidDate = [[Date,Item,ItemID,Winner,Response
invalid-date,Regicide,212405,Player-TestRealm,Need]]

-- Malformed: Invalid item ID
TestData.HistoryEntries.InvalidItemID = [[Date,Item,ItemID,Winner,Response
2025-12-06 03:30:00,Unknown Item,999999999,Player-TestRealm,Need]]

-- Malformed: Unknown response type
TestData.HistoryEntries.InvalidResponse = [[Date,Item,ItemID,Winner,Response
2025-12-06 03:30:00,Regicide,212405,Player-TestRealm,INVALID_RESPONSE]]

--[[====================================================================
    COMMUNICATION TEST DATA

    Protocol messages for testing addon communication.
======================================================================]]

TestData.Protocol = {}

-- Valid protocol messages
TestData.Protocol.SessionStart = {
    type = Loothing.MsgType.SESSION_START,
    encounterID = 2902,
    encounterName = "Ulgrax the Devourer",
    instanceID = 1273,
    timestamp = time(),
}

TestData.Protocol.ItemAdd = {
    type = Loothing.MsgType.ITEM_ADD,
    itemLink = "|cffa335ee|Hitem:212405::::::::80:1::3:1:28:2905:::::|h[Regicide]|h|r",
    guid = "item_abc123",
    looter = "Player-TestRealm",
    encounterID = 2902,
    timestamp = time(),
}

TestData.Protocol.VoteCommit = {
    type = Loothing.MsgType.VOTE_COMMIT,
    itemGUID = "item_abc123",
    voter = "Councilmember-TestRealm",
    votes = {
        { candidate = "Player1-TestRealm", responses = { 1, 2, 3 } }, -- NEED, GREED, OFFSPEC
        { candidate = "Player2-TestRealm", responses = { 2, 3, 5 } }, -- GREED, OFFSPEC, PASS
    },
    timestamp = time(),
}

TestData.Protocol.VoteAward = {
    type = Loothing.MsgType.VOTE_AWARD,
    itemGUID = "item_abc123",
    itemLink = "|cffa335ee|Hitem:212405::::::::80:1::3:1:28:2905:::::|h[Regicide]|h|r",
    winner = "Player-TestRealm",
    response = Loothing.Response.NEED,
    votes = 5,
    timestamp = time(),
}

-- Edge cases
TestData.Protocol.LongMessage = {
    type = Loothing.MsgType.SYNC_DATA,
    data = string.rep("x", 300), -- Exceeds single message limit, requires chunking
}

TestData.Protocol.SpecialChars = {
    type = Loothing.MsgType.ITEM_ADD,
    itemLink = "|cffa335ee|Hitem:212405::::::::80:1::3:1:28:2905:::::|h[Test: Item with | pipes : and colons]|h|r",
    notes = "Player said: \"This is my BiS!\" with quotes",
}

-- Malformed messages
TestData.Protocol.MissingType = {
    -- Missing 'type' field
    itemGUID = "item_abc123",
    winner = "Player-TestRealm",
}

TestData.Protocol.InvalidType = {
    type = "INVALID_MSG_TYPE",
    data = "test",
}

--[[====================================================================
    AUTO-PASS TEST DATA

    Test cases for armor type and trinket auto-pass logic.
======================================================================]]

TestData.AutoPass = {}

-- Armor type mismatches
TestData.AutoPass.ArmorMismatches = {
    -- Plate on cloth wearer (should auto-pass)
    {
        itemID = 212480, -- Crown of the Sureki Sovereign (Plate)
        playerClass = "MAGE",
        playerArmorType = "CLOTH",
        shouldAutoPass = true,
        reason = "Armor type mismatch (PLATE on CLOTH)",
    },

    -- Cloth on cloth wearer (should NOT auto-pass)
    {
        itemID = 212450, -- Whispering Veil (Cloth)
        playerClass = "MAGE",
        playerArmorType = "CLOTH",
        shouldAutoPass = false,
    },

    -- Leather on mail wearer (should auto-pass)
    {
        itemID = 212460, -- Cowl of the Silent Predator (Leather)
        playerClass = "HUNTER",
        playerArmorType = "MAIL",
        shouldAutoPass = true,
        reason = "Armor type mismatch (LEATHER on MAIL)",
    },

    -- Mail on leather wearer (should auto-pass)
    {
        itemID = 212470, -- Helm of the Nerubian Lord (Mail)
        playerClass = "DRUID",
        playerArmorType = "LEATHER",
        shouldAutoPass = true,
        reason = "Armor type mismatch (MAIL on LEATHER)",
    },
}

-- Trinket restrictions (based on TrinketData.lua spec flags)
TestData.AutoPass.TrinketRestrictions = {
    -- Strength trinket on intellect class (should auto-pass)
    {
        itemID = 212502, -- Spymaster's Web (Strength)
        playerClass = "MAGE",
        playerSpec = 2, -- Fire
        shouldAutoPass = true,
        reason = "Trinket restricted to Strength classes",
    },

    -- Intellect trinket on intellect class (should NOT auto-pass)
    {
        itemID = 212506, -- Ara-Kara Sacbrood (Intellect DPS)
        playerClass = "MAGE",
        playerSpec = 2, -- Fire
        shouldAutoPass = false,
    },

    -- Tank trinket on DPS spec (should auto-pass)
    {
        itemID = 212500, -- Viscous Chitin (Tank)
        playerClass = "WARRIOR",
        playerSpec = 2, -- Fury
        shouldAutoPass = true,
        reason = "Trinket restricted to Tank specs",
    },

    -- Healer trinket on healer (should NOT auto-pass)
    {
        itemID = 212508, -- Swarmlord's Authority (Healer)
        playerClass = "PRIEST",
        playerSpec = 2, -- Holy
        shouldAutoPass = false,
    },

    -- Agility trinket on strength class (should auto-pass)
    {
        itemID = 212504, -- Sikran's Endless Arsenal (Agility)
        playerClass = "PALADIN",
        playerSpec = 3, -- Retribution
        shouldAutoPass = true,
        reason = "Trinket restricted to Agility classes",
    },
}

-- Token restrictions (based on TokenData.lua)
TestData.AutoPass.TokenRestrictions = {
    -- Dreadful (Plate) token on cloth class (should auto-pass)
    {
        itemID = 225622, -- Dreadful Conniver's Badge (Plate: DK, Paladin, Warrior)
        playerClass = "MAGE",
        shouldAutoPass = true,
        reason = "Token restricted to Plate classes",
    },

    -- Mystic (Leather) token on leather class (should NOT auto-pass)
    {
        itemID = 225623, -- Mystic Conniver's Badge (Leather: DH, Druid, Monk, Rogue)
        playerClass = "ROGUE",
        shouldAutoPass = false,
    },

    -- Venerated (Mail) token on plate class (should auto-pass)
    {
        itemID = 225624, -- Venerated Conniver's Badge (Mail: Evoker, Hunter, Shaman)
        playerClass = "WARRIOR",
        shouldAutoPass = true,
        reason = "Token restricted to Mail classes",
    },

    -- Zenith (Cloth) token on cloth class (should NOT auto-pass)
    {
        itemID = 225625, -- Zenith Conniver's Badge (Cloth: Mage, Priest, Warlock)
        playerClass = "WARLOCK",
        shouldAutoPass = false,
    },
}

--[[====================================================================
    ENCOUNTER DATA

    Boss and loot data for The War Within raids.
======================================================================]]

TestData.Encounters = {}

-- Nerub-ar Palace (TWW Season 1) - 8 bosses
TestData.Encounters.NerubarPalace = {
    instanceID = 1273,
    instanceName = "Nerub-ar Palace",
    tier = 11, -- TWW
    season = 1,

    bosses = {
        -- Boss 1: Ulgrax the Devourer
        [2902] = {
            encounterID = 2902,
            name = "Ulgrax the Devourer",
            order = 1,
            items = { 212405, 212406, 212450, 212460, 212500, 212502 },
        },

        -- Boss 2: The Bloodbound Horror
        [2903] = {
            encounterID = 2903,
            name = "The Bloodbound Horror",
            order = 2,
            items = { 212407, 212451, 212461, 212501, 212503 },
        },

        -- Boss 3: Sikran, Captain of the Sureki
        [2904] = {
            encounterID = 2904,
            name = "Sikran, Captain of the Sureki",
            order = 3,
            items = { 212408, 212452, 212462, 212504 },
        },

        -- Boss 4: Rasha'nan
        [2905] = {
            encounterID = 2905,
            name = "Rasha'nan",
            order = 4,
            items = { 212409, 212453, 212463, 212505 },
        },

        -- Boss 5: Broodtwister Ovi'nax
        [2906] = {
            encounterID = 2906,
            name = "Broodtwister Ovi'nax",
            order = 5,
            items = { 212410, 212454, 212464, 212506 },
        },

        -- Boss 6: Nexus-Princess Ky'veza
        [2907] = {
            encounterID = 2907,
            name = "Nexus-Princess Ky'veza",
            order = 6,
            items = { 212411, 212455, 212465, 212507 },
        },

        -- Boss 7: The Silken Court
        [2908] = {
            encounterID = 2908,
            name = "The Silken Court",
            order = 7,
            items = { 212412, 212456, 212466, 212508 },
        },

        -- Boss 8: Queen Ansurek (Final Boss)
        [2909] = {
            encounterID = 2909,
            name = "Queen Ansurek",
            order = 8,
            items = { 212413, 212414, 212457, 212467, 212509, 212510 },
        },
    },
}

--[[====================================================================
    UTILITY FUNCTIONS

    Helper functions for working with test data.
======================================================================]]

TestData.Utils = {}

--- Get a random item from a table
-- @param tbl table - The table to pick from
-- @return any - Random element
function TestData.Utils.GetRandomItem(tbl)
    if type(tbl) ~= "table" or #tbl == 0 then
        return nil
    end
    return tbl[math.random(#tbl)]
end

--- Get multiple random items from a table
-- @param tbl table - The table to pick from
-- @param count number - Number of items to pick
-- @return table - Array of random elements
function TestData.Utils.GetRandomItems(tbl, count)
    local result = {}
    local used = {}

    if type(tbl) ~= "table" or #tbl == 0 or count <= 0 then
        return result
    end

    count = math.min(count, #tbl)

    while #result < count do
        local item = tbl[math.random(#tbl)]
        if not used[item] then
            result[#result + 1] = item
            used[item] = true
        end
    end

    return result
end

--- Create a mock item link
-- @param itemID number - Item ID
-- @param itemLevel number - Item level (optional)
-- @return string - Item link
function TestData.Utils.CreateItemLink(itemID, itemLevel)
    itemLevel = itemLevel or 626
    return string.format("|cffa335ee|Hitem:%d::::::::80:1::3:1:28:%d:::::|h[Test Item %d]|h|r",
        itemID, itemLevel, itemID)
end

--- Create a mock player name
-- @param class string - Class name (e.g., "WARRIOR")
-- @param index number - Player index (optional)
-- @return string - Player name with realm
function TestData.Utils.CreatePlayerName(class, index)
    index = index or 1
    local classLower = class:lower()
    local className = classLower:sub(1, 1):upper() .. classLower:sub(2)
    return string.format("%s%d-TestRealm", className, index)
end

--- Deep copy a table
-- @param orig table - Original table
-- @return table - Deep copy
function TestData.Utils.DeepCopy(orig)
    local copy
    if type(orig) == "table" then
        copy = {}
        for k, v in pairs(orig) do
            copy[k] = TestData.Utils.DeepCopy(v)
        end
    else
        copy = orig
    end
    return copy
end

--- Print test data summary
function TestData.Utils.PrintSummary()
    print("=== Loothing Test Data Summary ===")
    print(string.format("Weapons: %d", #TestData.Items.Weapons))
    print(string.format("Armor: Cloth=%d, Leather=%d, Mail=%d, Plate=%d",
        #TestData.Items.Armor.Cloth,
        #TestData.Items.Armor.Leather,
        #TestData.Items.Armor.Mail,
        #TestData.Items.Armor.Plate))
    print(string.format("Trinkets: %d", #TestData.Items.Trinkets))
    print(string.format("Tokens: %d", #TestData.Items.Tokens))
    print(string.format("Classes: %d", 13))
    print(string.format("Full Raid: %d players", #TestData.Players.FullRaid))
    print(string.format("Vote Scenarios: %d", 8))
    print(string.format("Session Scenarios: %d", 5))
    print(string.format("Encounters (Nerub-ar Palace): %d bosses", 8))
end

-- Initialize on load
if Loothing then
    Loothing.TestData = TestData
    Loothing:Debug("TestData module loaded")
end

return TestData
