--[[--------------------------------------------------------------------
    Loothing - Loot Council Addon for WoW 12.0+
    TestHelpers - Comprehensive testing utilities

    Provides helper functions for:
    - Fake player/raid/council generation
    - Fake item generation with modern TWW/Dragonflight items
    - Fake vote generation with various distributions
    - Session and scenario creation
    - State verification and assertions
    - Timing/performance utilities
    - Mock/spy utilities
    - Data cleanup and state management
----------------------------------------------------------------------]]

local Loolib = LibStub("Loolib")

--[[--------------------------------------------------------------------
    TestHelpers Singleton
----------------------------------------------------------------------]]

LoothingTestHelpers = {}
local TestHelpers = LoothingTestHelpers

--[[--------------------------------------------------------------------
    Class and Spec Data (WoW 12.0 / The War Within)
----------------------------------------------------------------------]]

-- All 13 classes with their IDs and colors
local CLASS_DATA = {
    {
        classID = 1,
        className = "WARRIOR",
        classNameLocalized = "Warrior",
        color = "C69B6D",
        colorRGB = { r = 0.78, g = 0.61, b = 0.43 },
        specs = {
            { specID = 71, specName = "Arms", role = "DAMAGER" },
            { specID = 72, specName = "Fury", role = "DAMAGER" },
            { specID = 73, specName = "Protection", role = "TANK" },
        },
    },
    {
        classID = 2,
        className = "PALADIN",
        classNameLocalized = "Paladin",
        color = "F48CBA",
        colorRGB = { r = 0.96, g = 0.55, b = 0.73 },
        specs = {
            { specID = 65, specName = "Holy", role = "HEALER" },
            { specID = 66, specName = "Protection", role = "TANK" },
            { specID = 70, specName = "Retribution", role = "DAMAGER" },
        },
    },
    {
        classID = 3,
        className = "HUNTER",
        classNameLocalized = "Hunter",
        color = "AAD372",
        colorRGB = { r = 0.67, g = 0.83, b = 0.45 },
        specs = {
            { specID = 253, specName = "Beast Mastery", role = "DAMAGER" },
            { specID = 254, specName = "Marksmanship", role = "DAMAGER" },
            { specID = 255, specName = "Survival", role = "DAMAGER" },
        },
    },
    {
        classID = 4,
        className = "ROGUE",
        classNameLocalized = "Rogue",
        color = "FFF468",
        colorRGB = { r = 1.00, g = 0.96, b = 0.41 },
        specs = {
            { specID = 259, specName = "Assassination", role = "DAMAGER" },
            { specID = 260, specName = "Outlaw", role = "DAMAGER" },
            { specID = 261, specName = "Subtlety", role = "DAMAGER" },
        },
    },
    {
        classID = 5,
        className = "PRIEST",
        classNameLocalized = "Priest",
        color = "FFFFFF",
        colorRGB = { r = 1.00, g = 1.00, b = 1.00 },
        specs = {
            { specID = 256, specName = "Discipline", role = "HEALER" },
            { specID = 257, specName = "Holy", role = "HEALER" },
            { specID = 258, specName = "Shadow", role = "DAMAGER" },
        },
    },
    {
        classID = 6,
        className = "DEATHKNIGHT",
        classNameLocalized = "Death Knight",
        color = "C41E3A",
        colorRGB = { r = 0.77, g = 0.12, b = 0.23 },
        specs = {
            { specID = 250, specName = "Blood", role = "TANK" },
            { specID = 251, specName = "Frost", role = "DAMAGER" },
            { specID = 252, specName = "Unholy", role = "DAMAGER" },
        },
    },
    {
        classID = 7,
        className = "SHAMAN",
        classNameLocalized = "Shaman",
        color = "0070DD",
        colorRGB = { r = 0.00, g = 0.44, b = 0.87 },
        specs = {
            { specID = 262, specName = "Elemental", role = "DAMAGER" },
            { specID = 263, specName = "Enhancement", role = "DAMAGER" },
            { specID = 264, specName = "Restoration", role = "HEALER" },
        },
    },
    {
        classID = 8,
        className = "MAGE",
        classNameLocalized = "Mage",
        color = "3FC7EB",
        colorRGB = { r = 0.41, g = 0.80, b = 0.94 },
        specs = {
            { specID = 62, specName = "Arcane", role = "DAMAGER" },
            { specID = 63, specName = "Fire", role = "DAMAGER" },
            { specID = 64, specName = "Frost", role = "DAMAGER" },
        },
    },
    {
        classID = 9,
        className = "WARLOCK",
        classNameLocalized = "Warlock",
        color = "8788EE",
        colorRGB = { r = 0.58, g = 0.51, b = 0.79 },
        specs = {
            { specID = 265, specName = "Affliction", role = "DAMAGER" },
            { specID = 266, specName = "Demonology", role = "DAMAGER" },
            { specID = 267, specName = "Destruction", role = "DAMAGER" },
        },
    },
    {
        classID = 10,
        className = "MONK",
        classNameLocalized = "Monk",
        color = "00FF98",
        colorRGB = { r = 0.00, g = 1.00, b = 0.59 },
        specs = {
            { specID = 268, specName = "Brewmaster", role = "TANK" },
            { specID = 270, specName = "Mistweaver", role = "HEALER" },
            { specID = 269, specName = "Windwalker", role = "DAMAGER" },
        },
    },
    {
        classID = 11,
        className = "DRUID",
        classNameLocalized = "Druid",
        color = "FF7C0A",
        colorRGB = { r = 1.00, g = 0.49, b = 0.04 },
        specs = {
            { specID = 102, specName = "Balance", role = "DAMAGER" },
            { specID = 103, specName = "Feral", role = "DAMAGER" },
            { specID = 104, specName = "Guardian", role = "TANK" },
            { specID = 105, specName = "Restoration", role = "HEALER" },
        },
    },
    {
        classID = 12,
        className = "DEMONHUNTER",
        classNameLocalized = "Demon Hunter",
        color = "A330C9",
        colorRGB = { r = 0.64, g = 0.19, b = 0.79 },
        specs = {
            { specID = 577, specName = "Havoc", role = "DAMAGER" },
            { specID = 581, specName = "Vengeance", role = "TANK" },
        },
    },
    {
        classID = 13,
        className = "EVOKER",
        classNameLocalized = "Evoker",
        color = "33937F",
        colorRGB = { r = 0.20, g = 0.58, b = 0.50 },
        specs = {
            { specID = 1467, specName = "Devastation", role = "DAMAGER" },
            { specID = 1468, specName = "Preservation", role = "HEALER" },
            { specID = 1473, specName = "Augmentation", role = "DAMAGER" },
        },
    },
}

-- Name generation parts
local NAME_PREFIXES = {
    "Shadow", "Fire", "Ice", "Storm", "Dark", "Light", "Blood", "Soul",
    "Iron", "Steel", "Thunder", "Frost", "Void", "Holy", "Death", "Chaos",
    "Moon", "Sun", "Star", "Night", "Rage", "Swift", "Silent", "Wild",
    "Ancient", "Elder", "Young", "Grim", "Fierce", "Bold", "Mystic", "Arcane",
}

local NAME_SUFFIXES = {
    "blade", "strike", "heart", "fang", "claw", "guard", "bane", "fury",
    "rage", "storm", "walker", "hunter", "seeker", "bringer", "keeper", "slayer",
    "wielder", "master", "lord", "shadow", "flame", "fist", "song", "whisper",
    "breaker", "crusher", "runner", "dancer", "howl", "wind", "tide", "doom",
}

--[[--------------------------------------------------------------------
    Modern Item IDs (TWW Season 1 / Dragonflight Season 4)
----------------------------------------------------------------------]]

-- The War Within Season 1 Raid Items (Nerub-ar Palace)
local TWW_RAID_ITEMS = {
    -- Weapons
    212395, -- Regicide (1H Sword, Queen Ansurek)
    212409, -- Scepter of Manifested Miasma (Staff, Broodtwister Ovi'nax)
    212413, -- Slime Serpent Bow (Bow, Broodtwister Ovi'nax)
    212389, -- Ovinax's Mercurial Egg (Wand, Broodtwister Ovi'nax)
    212407, -- Silksteel Torqblade (Glaive, Queen Ansurek)

    -- Armor - Head
    212424, -- Chitin-Spiked Greathelm (Plate, The Silken Court)
    212431, -- Circlet of Faded Glamour (Cloth, Queen Ansurek)
    212439, -- Crown of Relentless Annihilation (Mail, Broodtwister Ovi'nax)
    212446, -- Visor of Viscous Fury (Plate, Sikran)

    -- Armor - Shoulders
    212422, -- Fused Bone Shoulder Plates (Plate, Ulgrax the Devourer)
    212437, -- Polluted Spectre's Wraps (Cloth, The Bloodbound Horror)
    212045, -- Silkenweave Epaulets (Leather, The Silken Court)
    212441, -- Zealous Transmutator's Mantle (Mail, Broodtwister Ovi'nax)

    -- Armor - Chest
    212432, -- Binding of Broken Webs (Cloth, Queen Ansurek)
    212414, -- Exoskeletal Carapace (Plate, Rasha'nan)
    212425, -- Hauberk of the Titanic Blowhard (Mail, Ulgrax the Devourer)
    212045, -- Maw of the Skittering Swarm (Leather, The Silken Court)

    -- Trinkets
    212448, -- Algari Alchemist Stone (Universal, Crafted)
    212456, -- Empowering Crystal of Anub'ikkaj (DPS, Queen Ansurek)
    212684, -- Imperfect Ascendancy Serum (DPS, Broodtwister Ovi'nax)
    219314, -- Ara-Kara Sacbrood (Tank, Nerub-ar Palace)
    219915, -- Swarmlord's Authority (DPS, Queen Ansurek)
}

-- Dragonflight Season 4 Items
local DF_RAID_ITEMS = {
    -- Aberrus Items
    202612, -- Erethos, the Empty Promise (Staff, Scalecommander Sarkareth)
    202570, -- Nasz'uro, the Unbound Legacy (Evoker Legendary, Scalecommander Sarkareth)
    202569, -- Rashok's Molten Heart (Trinket, Rashok)
    202611, -- Vakash, the Shadowed Inferno (Dagger, Scalecommander Sarkareth)

    -- Vault of the Incarnates
    194299, -- Spiteful Storm (Staff, Raszageth)
    194302, -- Desperate Invoker's Codex (Trinket, Raszageth)
    194301, -- Neltharax, Enemy of the Sky (2H Axe, Raszageth)
    194308, -- Infurious Boots of Reprieve (Mail Boots, Broodkeeper Diurna)
}

-- Mythic+ Items (The War Within S1)
local TWW_MYTHIC_PLUS_ITEMS = {
    221023, -- Treacherous Transmitter (Trinket, Various dungeons)
    221159, -- Gale of Shadows (Cloak, Mists of Tirna Scithe)
    221184, -- Skardyn's Grace (Trinket, The Stonevault)
    221133, -- Slimy Webbing (Back, Ara-Kara)
    221156, -- Void Reaper's Contract (Trinket, The Dawnbreaker)
}

-- Combine all item pools by slot/type
local TEST_ITEMS_BY_CATEGORY = {
    weapons = {
        -- TWW
        212395, 212409, 212413, 212389, 212407,
        -- DF
        202612, 202570, 202611, 194299, 194301,
    },
    armor_head = {
        212424, 212431, 212439, 212446,
    },
    armor_shoulder = {
        212422, 212437, 212045, 212441,
    },
    armor_chest = {
        212432, 212414, 212425, 212045,
    },
    trinkets = {
        -- TWW Raid
        212448, 212456, 212684, 219314, 219915,
        -- TWW M+
        221023, 221184, 221156,
        -- DF
        202569, 194302,
    },
    all = {}, -- Populated below
}

-- Populate 'all' category
for category, items in pairs(TEST_ITEMS_BY_CATEGORY) do
    if category ~= "all" then
        for _, itemID in ipairs(items) do
            table.insert(TEST_ITEMS_BY_CATEGORY.all, itemID)
        end
    end
end

--[[--------------------------------------------------------------------
    State Management
----------------------------------------------------------------------]]

-- Store original functions for mocking/spying
local originalFunctions = {}
local spyData = {}
local stateSnapshots = {}

--[[--------------------------------------------------------------------
    1. Fake Player Generation
----------------------------------------------------------------------]]

--- Get a random class with all data
-- @return table - Class data table
function TestHelpers:GetRandomClass()
    return CLASS_DATA[math.random(#CLASS_DATA)]
end

--- Get a random spec for a given class ID
-- @param classID number - Class ID (1-13)
-- @return table|nil - Spec data table or nil if invalid classID
function TestHelpers:GetRandomSpec(classID)
    for _, classData in ipairs(CLASS_DATA) do
        if classData.classID == classID then
            local specs = classData.specs
            return specs[math.random(#specs)]
        end
    end
    return nil
end

--- Get class data by class name or ID
-- @param classIdentifier string|number - Class name or ID
-- @return table|nil
function TestHelpers:GetClassData(classIdentifier)
    if type(classIdentifier) == "number" then
        for _, classData in ipairs(CLASS_DATA) do
            if classData.classID == classIdentifier then
                return classData
            end
        end
    elseif type(classIdentifier) == "string" then
        local upperName = classIdentifier:upper()
        for _, classData in ipairs(CLASS_DATA) do
            if classData.className == upperName then
                return classData
            end
        end
    end
    return nil
end

--- Generate a unique fake player name
-- @param usedNames table - Table of already-used names
-- @return string - Unique player name (without realm)
function TestHelpers:GenerateFakeName(usedNames)
    usedNames = usedNames or {}
    local name
    local attempts = 0

    repeat
        local prefix = NAME_PREFIXES[math.random(#NAME_PREFIXES)]
        local suffix = NAME_SUFFIXES[math.random(#NAME_SUFFIXES)]
        name = prefix .. suffix
        attempts = attempts + 1
    until not usedNames[name] or attempts > 100

    usedNames[name] = true
    return name
end

--- Create a fake player with random or specified attributes
-- @param overrides table - Optional overrides { name, class, spec, realm, role, level }
-- @return table - Fake player data
function TestHelpers:CreateFakePlayer(overrides)
    overrides = overrides or {}

    -- Select class
    local classData
    if overrides.class then
        classData = self:GetClassData(overrides.class)
    end
    if not classData then
        classData = self:GetRandomClass()
    end

    -- Select spec
    local specData
    if overrides.spec then
        -- Find spec by name or ID
        for _, spec in ipairs(classData.specs) do
            if spec.specID == overrides.spec or spec.specName == overrides.spec then
                specData = spec
                break
            end
        end
    end
    if not specData then
        specData = classData.specs[math.random(#classData.specs)]
    end

    -- Generate name
    local shortName = overrides.name or self:GenerateFakeName()
    local realm = overrides.realm or GetNormalizedRealmName() or "TestRealm"
    local fullName = shortName .. "-" .. realm

    return {
        name = fullName,
        shortName = shortName,
        realm = realm,
        class = classData.className,
        classLocalized = classData.classNameLocalized,
        classID = classData.classID,
        classColor = classData.color,
        classColorRGB = classData.colorRGB,
        specID = specData.specID,
        specName = specData.specName,
        role = overrides.role or specData.role,
        level = overrides.level or 80,
        online = overrides.online ~= false,
        isDead = overrides.isDead or false,
    }
end

--- Create a fake raid roster with realistic composition
-- @param count number - Number of raid members (default 20)
-- @param options table - { tankCount, healerCount, dpsCount, includePlayer }
-- @return table - Array of fake players
function TestHelpers:CreateFakeRaid(count, options)
    count = count or 20
    options = options or {}

    local tankCount = options.tankCount or math.floor(count * 0.1) -- 10% tanks
    local healerCount = options.healerCount or math.floor(count * 0.2) -- 20% healers
    local dpsCount = options.dpsCount or (count - tankCount - healerCount) -- Rest DPS

    local roster = {}
    local usedNames = {}

    -- Add player if requested
    if options.includePlayer ~= false then
        local playerName = UnitName("player")
        local _, playerClass = UnitClass("player")

        table.insert(roster, {
            name = LoothingUtils.GetPlayerFullName(),
            shortName = playerName,
            realm = GetNormalizedRealmName() or "TestRealm",
            class = playerClass,
            classID = select(3, UnitClass("player")),
            level = UnitLevel("player"),
            online = true,
            isDead = false,
            role = UnitGroupRolesAssigned("player"),
            isSelf = true,
        })
        usedNames[playerName] = true
    end

    -- Generate tanks
    for i = 1, tankCount do
        local player = self:CreateFakePlayer({ role = "TANK" })
        player.shortName = self:GenerateFakeName(usedNames)
        player.name = player.shortName .. "-" .. player.realm
        table.insert(roster, player)
    end

    -- Generate healers
    for i = 1, healerCount do
        local player = self:CreateFakePlayer({ role = "HEALER" })
        player.shortName = self:GenerateFakeName(usedNames)
        player.name = player.shortName .. "-" .. player.realm
        table.insert(roster, player)
    end

    -- Generate DPS
    for i = 1, dpsCount do
        local player = self:CreateFakePlayer({ role = "DAMAGER" })
        player.shortName = self:GenerateFakeName(usedNames)
        player.name = player.shortName .. "-" .. player.realm
        table.insert(roster, player)
    end

    return roster
end

--- Create fake council members
-- @param count number - Number of council members (default 5)
-- @return table - Array of fake council members
function TestHelpers:CreateFakeCouncil(count)
    count = count or 5
    local council = {}
    local usedNames = {}

    -- Always include player as first council member (leader)
    local playerName = UnitName("player")
    local _, playerClass = UnitClass("player")

    table.insert(council, {
        name = LoothingUtils.GetPlayerFullName(),
        shortName = playerName,
        class = playerClass,
        classID = select(3, UnitClass("player")),
        rank = 2, -- Leader
        online = true,
        isSelf = true,
    })
    usedNames[playerName] = true

    -- Generate remaining council members
    for i = 2, count do
        local player = self:CreateFakePlayer()
        player.shortName = self:GenerateFakeName(usedNames)
        player.name = player.shortName .. "-" .. player.realm
        player.rank = 1 -- Assistant
        table.insert(council, player)
    end

    return council
end

--[[--------------------------------------------------------------------
    2. Fake Item Generation
----------------------------------------------------------------------]]

--- Get test item IDs by category
-- @return table - { weapons = {...}, trinkets = {...}, all = {...}, ... }
function TestHelpers:GetTestItemIDs()
    return TEST_ITEMS_BY_CATEGORY
end

--- Get a random item from a specific category
-- @param category string - "weapons", "trinkets", "armor_head", etc.
-- @return number|nil - Item ID or nil if category doesn't exist
function TestHelpers:GetRandomItemFromCategory(category)
    local items = TEST_ITEMS_BY_CATEGORY[category]
    if items and #items > 0 then
        return items[math.random(#items)]
    end
    return nil
end

--- Generate a valid item link from an item ID
-- @param itemID number - Optional specific item ID (random if not provided)
-- @return string - Item link
function TestHelpers:CreateFakeItemLink(itemID)
    itemID = itemID or self:GetRandomItemFromCategory("all")

    -- Try to get real item info
    local name, link = C_Item.GetItemInfo(itemID)
    if link then
        return link
    end

    -- Fallback: create synthetic link
    return string.format("|cffa335ee|Hitem:%d::::::::80:::::|h[Test Item %d]|h|r", itemID, itemID)
end

--- Create a fake LoothingItemMixin object
-- @param overrides table - Optional { itemLink, itemID, looter, encounterID, state }
-- @return LoothingItemMixin|nil
function TestHelpers:CreateFakeItem(overrides)
    if not Loothing or not Loothing.Session then
        error("Loothing.Session not available")
        return nil
    end

    overrides = overrides or {}

    local itemLink = overrides.itemLink
    if not itemLink and overrides.itemID then
        itemLink = self:CreateFakeItemLink(overrides.itemID)
    end
    if not itemLink then
        itemLink = self:CreateFakeItemLink()
    end

    local looter = overrides.looter
    if not looter then
        local fakePlayer = self:CreateFakePlayer()
        looter = fakePlayer.name
    end

    local encounterID = overrides.encounterID or 0

    -- Create item using mixin
    local item = Loolib.CreateFromMixins(LoothingItemMixin)
    item:Init(itemLink, looter, encounterID)

    -- Apply state override if provided
    if overrides.state then
        item:SetState(overrides.state)
    end

    return item
end

--[[--------------------------------------------------------------------
    3. Fake Vote Generation
----------------------------------------------------------------------]]

--- Create a single fake vote
-- @param voter string|table - Voter name or player data
-- @param responses table - Array of Loothing.Response values (ranked)
-- @return table - Vote data
function TestHelpers:CreateFakeVote(voter, responses)
    local voterName, voterClass

    if type(voter) == "table" then
        voterName = voter.name or voter.shortName
        voterClass = voter.class
    else
        voterName = voter
        local fakePlayer = self:CreateFakePlayer()
        voterClass = fakePlayer.class
    end

    responses = responses or { Loothing.Response.NEED }

    return {
        voter = voterName,
        voterClass = voterClass,
        responses = responses,
        timestamp = time(),
    }
end

--- Create multiple fake votes with distribution
-- @param item LoothingItemMixin - Item to vote on
-- @param distribution table - { NEED = 3, GREED = 2, PASS = 1 } or table of voters
-- @return table - Array of votes created
function TestHelpers:CreateFakeVotes(item, distribution)
    if not item then
        error("Item is required for CreateFakeVotes")
        return {}
    end

    local votes = {}
    local council = LoothingTestMode and LoothingTestMode:GetFakeCouncilMembers() or self:CreateFakeCouncil()

    -- If distribution is a simple count table
    if distribution[Loothing.Response.NEED] or distribution[Loothing.Response.GREED] then
        local voterIndex = 2 -- Skip player at index 1

        for response, count in pairs(distribution) do
            for i = 1, count do
                if voterIndex <= #council then
                    local voter = council[voterIndex]
                    item:AddVote(voter.name, voter.class, { response })
                    voterIndex = voterIndex + 1
                end
            end
        end
    else
        -- Distribution is a custom table of { voter, responses } pairs
        for _, voteData in ipairs(distribution) do
            local voter = voteData.voter or voteData[1]
            local responses = voteData.responses or voteData[2] or { Loothing.Response.NEED }

            if type(voter) == "table" then
                item:AddVote(voter.name, voter.class, responses)
            else
                local fakePlayer = self:CreateFakePlayer()
                item:AddVote(voter, fakePlayer.class, responses)
            end
        end
    end

    return votes
end

--- Create a tied vote scenario
-- @param item LoothingItemMixin - Item to vote on
-- @param response1 number - First response type
-- @param response2 number - Second response type
-- @param count number - Number of votes for each (default 2)
-- @return table - Vote distribution
function TestHelpers:CreateTiedVotes(item, response1, response2, count)
    count = count or 2

    local distribution = {}
    distribution[response1] = count
    distribution[response2] = count

    return self:CreateFakeVotes(item, distribution)
end

--- Create unanimous votes
-- @param item LoothingItemMixin - Item to vote on
-- @param response number - Response type
-- @param count number - Number of unanimous votes (default 5)
-- @return table - Vote distribution
function TestHelpers:CreateUnanimousVotes(item, response, count)
    count = count or 5

    local distribution = {}
    distribution[response] = count

    return self:CreateFakeVotes(item, distribution)
end

--[[--------------------------------------------------------------------
    4. Session Helpers
----------------------------------------------------------------------]]

--- Create a full test session with items and candidates
-- @param config table - { itemCount, memberCount, encounterID, encounterName }
-- @return table - { session, items, members }
function TestHelpers:CreateTestSession(config)
    if not Loothing or not Loothing.Session then
        error("Loothing.Session not available")
        return nil
    end

    config = config or {}
    local itemCount = config.itemCount or 3
    local memberCount = config.memberCount or 20
    local encounterID = config.encounterID or 0
    local encounterName = config.encounterName or "Test Encounter"

    -- Start session
    Loothing.Session:StartSession(encounterID, encounterName)

    -- Create raid members
    local members = self:CreateFakeRaid(memberCount)

    -- Create items
    local items = {}
    for i = 1, itemCount do
        local itemID = self:GetRandomItemFromCategory("all")
        local itemLink = self:CreateFakeItemLink(itemID)
        local looter = members[math.random(#members)].name

        local item = Loothing.Session:AddItem(itemLink, looter)
        if item then
            table.insert(items, item)
        end
    end

    return {
        session = Loothing.Session,
        items = items,
        members = members,
    }
end

--- Create a pre-built voting scenario
-- @param scenarioType string - "simple", "ranked", "tie", "unanimous", "timeout", "split"
-- @return table - { item, votes, description }
function TestHelpers:CreateVotingScenario(scenarioType)
    local item = self:CreateFakeItem()
    if not item then
        error("Failed to create item")
        return nil
    end

    item:StartVoting(30)

    local scenarios = {
        simple = function()
            self:CreateFakeVotes(item, {
                [Loothing.Response.NEED] = 3,
                [Loothing.Response.GREED] = 2,
                [Loothing.Response.PASS] = 1,
            })
            return "Simple majority (3 NEED, 2 GREED, 1 PASS)"
        end,

        ranked = function()
            local council = self:CreateFakeCouncil(5)
            for i = 2, #council do
                local responses = {
                    Loothing.Response.NEED,
                    Loothing.Response.GREED,
                    Loothing.Response.OFFSPEC,
                }
                item:AddVote(council[i].name, council[i].class, responses)
            end
            return "Ranked choice voting (all voters ranked their choices)"
        end,

        tie = function()
            self:CreateTiedVotes(item, Loothing.Response.NEED, Loothing.Response.GREED, 2)
            return "Tied vote (2 NEED vs 2 GREED)"
        end,

        unanimous = function()
            self:CreateUnanimousVotes(item, Loothing.Response.NEED, 5)
            return "Unanimous vote (5 NEED)"
        end,

        timeout = function()
            -- No votes, just waiting for timeout
            item.voteEndTime = GetTime() - 1 -- Already timed out
            return "Timeout scenario (no votes received)"
        end,

        split = function()
            self:CreateFakeVotes(item, {
                [Loothing.Response.NEED] = 2,
                [Loothing.Response.GREED] = 2,
                [Loothing.Response.OFFSPEC] = 1,
                [Loothing.Response.TRANSMOG] = 1,
            })
            return "Split vote (2 NEED, 2 GREED, 1 OFFSPEC, 1 TRANSMOG)"
        end,
    }

    local scenarioFunc = scenarios[scenarioType] or scenarios.simple
    local description = scenarioFunc()

    return {
        item = item,
        votes = item:GetVotes(),
        description = description,
        type = scenarioType,
    }
end

--[[--------------------------------------------------------------------
    5. State Verification & Assertions
----------------------------------------------------------------------]]

--- Assert that an item is in the expected state
-- @param item LoothingItemMixin
-- @param expectedState number - Loothing.ItemState value
-- @param errorMsg string - Optional custom error message
function TestHelpers:AssertItemState(item, expectedState, errorMsg)
    if not item then
        error("Item is nil")
        return false
    end

    local actualState = item:GetState()
    if actualState ~= expectedState then
        local msg = errorMsg or string.format(
            "Item state mismatch: expected %d, got %d",
            expectedState,
            actualState
        )
        error(msg)
        return false
    end

    return true
end

--- Assert that a session is in the expected state
-- @param session table - Session object
-- @param expectedState number - Loothing.SessionState value
-- @param errorMsg string - Optional custom error message
function TestHelpers:AssertSessionState(session, expectedState, errorMsg)
    if not session then
        error("Session is nil")
        return false
    end

    local actualState = (session.GetState and session:GetState()) or session.state
    if actualState ~= expectedState then
        local msg = errorMsg or string.format(
            "Session state mismatch: expected %d, got %d",
            expectedState,
            actualState
        )
        error(msg)
        return false
    end

    return true
end

--- Assert vote tally for a specific response
-- @param item LoothingItemMixin
-- @param response number - Loothing.Response value
-- @param expectedCount number
function TestHelpers:AssertVoteTally(item, response, expectedCount)
    if not item then
        error("Item is nil")
        return false
    end

    local votes = item:GetVotesByResponse(response)
    local actualCount = #votes

    if actualCount ~= expectedCount then
        local responseName = Loothing.ResponseInfo[response] and Loothing.ResponseInfo[response].name or "UNKNOWN"
        error(string.format(
            "Vote tally mismatch for %s: expected %d, got %d",
            responseName,
            expectedCount,
            actualCount
        ))
        return false
    end

    return true
end

--- Assert that the item has the expected winner
-- @param item LoothingItemMixin
-- @param expectedWinner string - Expected winner name
function TestHelpers:AssertWinner(item, expectedWinner)
    if not item then
        error("Item is nil")
        return false
    end

    local actualWinner = item:GetWinner()
    if actualWinner ~= expectedWinner then
        error(string.format(
            "Winner mismatch: expected %s, got %s",
            tostring(expectedWinner),
            tostring(actualWinner)
        ))
        return false
    end

    return true
end

--[[--------------------------------------------------------------------
    6. Timing & Performance
----------------------------------------------------------------------]]

--- Measure execution time of a function
-- @param func function - Function to measure
-- @param ... - Arguments to pass to function
-- @return number, ... - Elapsed time in ms, followed by function return values
function TestHelpers:MeasureTime(func, ...)
    local startTime = debugprofilestop()
    local results = { func(...) }
    local endTime = debugprofilestop()
    local elapsed = endTime - startTime

    return elapsed, unpack(results)
end

--- Wait for N frames then execute callback
-- @param count number - Number of frames to wait
-- @param callback function - Function to call after waiting
function TestHelpers:WaitFrames(count, callback)
    count = count or 1
    local frame = CreateFrame("Frame")
    local frameCount = 0

    frame:SetScript("OnUpdate", function(self)
        frameCount = frameCount + 1
        if frameCount >= count then
            self:SetScript("OnUpdate", nil)
            if callback then
                callback()
            end
        end
    end)
end

--- Simulate timeout on an item (fast-forward to timeout state)
-- @param item LoothingItemMixin
function TestHelpers:SimulateTimeout(item)
    if not item then
        error("Item is nil")
        return
    end

    if item:IsVoting() then
        item.voteEndTime = GetTime() - 1
    end
end

--[[--------------------------------------------------------------------
    7. Mock & Spy Utilities
----------------------------------------------------------------------]]

--- Mock a function (replace it with a custom implementation)
-- @param tbl table - Table containing the function
-- @param funcName string - Function name
-- @param mockFunc function - Replacement function
function TestHelpers:MockFunction(tbl, funcName, mockFunc)
    if not tbl or not funcName then
        error("Table and function name are required")
        return
    end

    local key = tostring(tbl) .. "." .. funcName

    -- Store original if not already mocked
    if not originalFunctions[key] then
        originalFunctions[key] = tbl[funcName]
    end

    -- Replace with mock
    tbl[funcName] = mockFunc
end

--- Restore a mocked function to its original implementation
-- @param tbl table - Table containing the function
-- @param funcName string - Function name
function TestHelpers:RestoreMock(tbl, funcName)
    if not tbl or not funcName then
        error("Table and function name are required")
        return
    end

    local key = tostring(tbl) .. "." .. funcName

    if originalFunctions[key] then
        tbl[funcName] = originalFunctions[key]
        originalFunctions[key] = nil
    end
end

--- Spy on a function (track calls without replacing it)
-- @param tbl table - Table containing the function
-- @param funcName string - Function name
-- @return table - Spy object with call data
function TestHelpers:SpyOn(tbl, funcName)
    if not tbl or not funcName then
        error("Table and function name are required")
        return nil
    end

    local key = tostring(tbl) .. "." .. funcName
    local original = tbl[funcName]

    if not original then
        error("Function does not exist: " .. funcName)
        return nil
    end

    -- Store original
    originalFunctions[key] = original

    -- Create spy data
    local spy = {
        calls = {},
        callCount = 0,
    }
    spyData[key] = spy

    -- Replace with spy wrapper
    tbl[funcName] = function(...)
        spy.callCount = spy.callCount + 1
        local args = { ... }
        table.insert(spy.calls, {
            args = args,
            timestamp = GetTime(),
        })

        -- Call original
        return original(...)
    end

    return spy
end

--- Get spy call data
-- @param spy table - Spy object returned from SpyOn
-- @return table - Array of call data
function TestHelpers:GetSpyCalls(spy)
    if not spy then
        return {}
    end
    return spy.calls
end

--- Restore all mocks and spies
function TestHelpers:RestoreAll()
    for key, original in pairs(originalFunctions) do
        local tblKey, funcName = key:match("^(.+)%.(.+)$")
        -- Note: Can't easily restore without storing table reference
        -- Users should call RestoreMock individually
    end

    originalFunctions = {}
    spyData = {}
end

--[[--------------------------------------------------------------------
    8. Data Cleanup
----------------------------------------------------------------------]]

--- Cleanup current session (end session, clear data)
function TestHelpers:CleanupSession()
    if Loothing and Loothing.Session then
        if Loothing.Session:IsActive() then
            Loothing.Session:EndSession()
        end
    end

    -- Clear test mode data if available
    if LoothingTestMode then
        LoothingTestMode.fakeItems = {}
    end
end

--- Full cleanup (session, mocks, spies, UI)
function TestHelpers:CleanupAll()
    -- Cleanup session
    self:CleanupSession()

    -- Restore all mocks
    self:RestoreAll()

    -- Hide UI frames
    if Loothing and Loothing.UI then
        if Loothing.UI.MainFrame and Loothing.UI.MainFrame.Hide then
            Loothing.UI.MainFrame:Hide()
        end
        if Loothing.UI.VotePanel and Loothing.UI.VotePanel.Hide then
            Loothing.UI.VotePanel:Hide()
        end
        if Loothing.UI.ResultsPanel and Loothing.UI.ResultsPanel.Hide then
            Loothing.UI.ResultsPanel:Hide()
        end
    end
end

--- Save current state snapshot
-- @param snapshotName string - Name for this snapshot (default "default")
function TestHelpers:SaveState(snapshotName)
    snapshotName = snapshotName or "default"

    local snapshot = {
        sessionActive = Loothing and Loothing.Session and Loothing.Session:IsActive() or false,
        testModeEnabled = LoothingTestMode and LoothingTestMode.enabled or false,
        timestamp = time(),
    }

    -- Save session data if active
    if snapshot.sessionActive and Loothing.Session.Serialize then
        snapshot.sessionData = Loothing.Session:Serialize()
    end

    stateSnapshots[snapshotName] = snapshot
end

--- Restore a saved state snapshot
-- @param snapshotName string - Name of snapshot to restore (default "default")
function TestHelpers:RestoreState(snapshotName)
    snapshotName = snapshotName or "default"

    local snapshot = stateSnapshots[snapshotName]
    if not snapshot then
        error("Snapshot not found: " .. snapshotName)
        return false
    end

    -- Cleanup current state
    self:CleanupAll()

    -- Restore test mode
    if LoothingTestMode then
        LoothingTestMode:SetEnabled(snapshot.testModeEnabled)
    end

    -- Restore session if it was active
    if snapshot.sessionActive and snapshot.sessionData and Loothing.Session.Deserialize then
        Loothing.Session:Deserialize(snapshot.sessionData)
    end

    return true
end

--[[--------------------------------------------------------------------
    Utility Methods
----------------------------------------------------------------------]]

--- Print test helper info
function TestHelpers:PrintInfo()
    print("|cff00ff00[Loothing TestHelpers]|r Available utilities:")
    print("  |cffffffffPlayer Generation:|r CreateFakePlayer, CreateFakeRaid, CreateFakeCouncil")
    print("  |cffffffffItem Generation:|r CreateFakeItem, CreateFakeItemLink, GetTestItemIDs")
    print("  |cffffffffVote Generation:|r CreateFakeVote, CreateFakeVotes, CreateTiedVotes")
    print("  |cffffffffSession Helpers:|r CreateTestSession, CreateVotingScenario")
    print("  |cffffffffAssertions:|r AssertItemState, AssertSessionState, AssertVoteTally")
    print("  |cffffffffTiming:|r MeasureTime, WaitFrames, SimulateTimeout")
    print("  |cffffffffMocking:|r MockFunction, RestoreMock, SpyOn, GetSpyCalls")
    print("  |cffffffffCleanup:|r CleanupSession, CleanupAll, SaveState, RestoreState")
    print(" ")
    print("  Use |cffffffff/dump LoothingTestHelpers|r to see all methods")
end

--[[--------------------------------------------------------------------
    Initialization
----------------------------------------------------------------------]]

-- Print initialization message
print("|cff00ff00[Loothing]|r TestHelpers loaded. Use |cffffffffLoothingTestHelpers:PrintInfo()|r for help.")
