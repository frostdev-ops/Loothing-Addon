--[[--------------------------------------------------------------------
    Loothing - Loot Council Addon for WoW 12.0+
    TestMode - Development testing utilities
----------------------------------------------------------------------]]

local L = LOOTHING_LOCALE

--[[--------------------------------------------------------------------
    Test Mode State
----------------------------------------------------------------------]]

LoothingTestMode = {
    enabled = false,
    fakeCouncilMembers = {},
    fakeItems = {},
}

-- Class data for fake players
local CLASS_DATA = {
    { class = "WARRIOR", color = "C69B6D" },
    { class = "PALADIN", color = "F48CBA" },
    { class = "HUNTER", color = "AAD372" },
    { class = "ROGUE", color = "FFF468" },
    { class = "PRIEST", color = "FFFFFF" },
    { class = "DEATHKNIGHT", color = "C41E3A" },
    { class = "SHAMAN", color = "0070DD" },
    { class = "MAGE", color = "3FC7EB" },
    { class = "WARLOCK", color = "8788EE" },
    { class = "MONK", color = "00FF98" },
    { class = "DRUID", color = "FF7C0A" },
    { class = "DEMONHUNTER", color = "A330C9" },
    { class = "EVOKER", color = "33937F" },
}

-- Fake player name parts
local NAME_PREFIXES = { "Shadow", "Fire", "Ice", "Storm", "Dark", "Light", "Blood", "Soul", "Iron", "Steel", "Thunder", "Frost" }
local NAME_SUFFIXES = { "blade", "strike", "heart", "fang", "claw", "guard", "bane", "fury", "rage", "storm", "walker", "hunter" }

-- Test item IDs (real epic+ items for valid item links)
local TEST_ITEM_IDS = {
    -- Weapons
    19019,  -- Thunderfury, Blessed Blade of the Windseeker
    17182,  -- Sulfuras, Hand of Ragnaros
    22691,  -- Corrupted Ashbringer
    32837,  -- Warglaive of Azzinoth (Main Hand)
    34334,  -- Thori'dal, the Stars' Fury
    -- Armor
    16922,  -- Leggings of Transcendence
    16925,  -- Robes of Transcendence
    19375,  -- Mish'undare, Circlet of the Mind Flayer
    21126,  -- Death's Sting
    30905,  -- Pauldrons of the Forgotten Vanquisher
    -- Trinkets
    19288,  -- Darkmoon Card: Blue Dragon
    23558,  -- The Phylactery of Kel'Thuzad
    32496,  -- Memento of Tyrande
    -- Various epic items
    22812,  -- Nerubian Slavemaker
    22818,  -- The Castigator
    22821,  -- Wand of Fates
    28830,  -- Dragonspine Trophy
    29434,  -- Badge of Tenacity
    30627,  -- Tsunami Talisman
}

--[[--------------------------------------------------------------------
    Test Mode Toggle
----------------------------------------------------------------------]]

--- Enable or disable test mode
-- @param enabled boolean
function LoothingTestMode:SetEnabled(enabled)
    self.enabled = enabled

    if enabled then
        self:GenerateFakeCouncil()
        print("|cff00ff00[Loothing]|r Test mode |cff00ff00ENABLED|r")
        print("  - Raid requirements bypassed")
        print("  - Fake council members created: " .. #self.fakeCouncilMembers)
        print("  - Use '/lt test add [count]' to add fake items")
        print("  - Use '/lt test vote' to simulate votes")
        print("  - Use '/lt test session' to start a test session")
    else
        self:ClearFakeData()
        print("|cff00ff00[Loothing]|r Test mode |cffff0000DISABLED|r")
    end

    -- Notify UI to update
    if Loothing and Loothing.UI and Loothing.UI.MainFrame then
        Loothing.UI.MainFrame:Refresh()
    end
end

--- Check if test mode is enabled
-- @return boolean
function LoothingTestMode:IsEnabled()
    return self.enabled
end

--- Toggle test mode
function LoothingTestMode:Toggle()
    self:SetEnabled(not self.enabled)
end

--[[--------------------------------------------------------------------
    Fake Council Generation
----------------------------------------------------------------------]]

--- Generate fake council members
-- @param count number - Number of members to generate (default 5)
function LoothingTestMode:GenerateFakeCouncil(count)
    count = count or 5
    self.fakeCouncilMembers = {}

    local realm = GetNormalizedRealmName()
    local usedNames = {}

    for i = 1, count do
        local name
        repeat
            local prefix = NAME_PREFIXES[math.random(#NAME_PREFIXES)]
            local suffix = NAME_SUFFIXES[math.random(#NAME_SUFFIXES)]
            name = prefix .. suffix
        until not usedNames[name]

        usedNames[name] = true

        local classData = CLASS_DATA[math.random(#CLASS_DATA)]

        self.fakeCouncilMembers[i] = {
            name = name .. "-" .. realm,
            shortName = name,
            class = classData.class,
            classColor = classData.color,
            rank = i == 1 and 2 or 1,  -- First is "leader", rest are "assistants"
            online = true,
        }
    end

    -- Add the real player as first member
    local playerName = LoothingUtils.GetPlayerFullName()
    local _, playerClass = UnitClass("player")
    table.insert(self.fakeCouncilMembers, 1, {
        name = playerName,
        shortName = UnitName("player"),
        class = playerClass,
        rank = 2,  -- Player is the leader
        online = true,
    })
end

--- Get fake council members
-- @return table - Array of fake council member data
function LoothingTestMode:GetFakeCouncilMembers()
    return self.fakeCouncilMembers
end

--- Get fake raid roster (for testing)
-- @return table - Array formatted like GetRaidRoster()
function LoothingTestMode:GetFakeRaidRoster()
    local roster = {}

    for i, member in ipairs(self.fakeCouncilMembers) do
        roster[i] = {
            name = member.name,
            shortName = member.shortName,
            rank = member.rank,
            subgroup = 1,
            level = 80,
            class = member.class:gsub("^%l", string.upper),  -- Capitalize
            classFile = member.class,
            online = true,
            isDead = false,
            role = "DAMAGER",
            isMasterLooter = (i == 1),
        }
    end

    return roster
end

--[[--------------------------------------------------------------------
    Fake Item Generation
----------------------------------------------------------------------]]

--- Generate a fake item link
-- @param itemID number - Optional specific item ID
-- @return string - Item link
function LoothingTestMode:GenerateFakeItemLink(itemID)
    itemID = itemID or TEST_ITEM_IDS[math.random(#TEST_ITEM_IDS)]

    -- Create a basic item link format
    -- |cff<color>|Hitem:<itemID>::::::::80:::::|h[<name>]|h|r
    local name, link = C_Item.GetItemInfo(itemID)

    if link then
        return link
    end

    -- Fallback: create a synthetic link (may not work perfectly)
    return string.format("|cffa335ee|Hitem:%d::::::::80:::::|h[Test Item %d]|h|r", itemID, itemID)
end

--- Add fake items to the current session
-- @param count number - Number of items to add (default 3)
function LoothingTestMode:AddFakeItems(count)
    count = count or 3

    if not self.enabled then
        print("|cffff0000[Loothing]|r Test mode is not enabled. Use '/lt test' to enable.")
        return
    end

    if not Loothing or not Loothing.Session then
        print("|cffff0000[Loothing]|r Session module not loaded.")
        return
    end

    -- Start session if not active
    if not Loothing.Session:IsActive() then
        Loothing.Session:StartSession(0, "Test Encounter")
    end

    local addedCount = 0
    local usedIDs = {}

    for i = 1, count do
        -- Pick a random item ID not already used
        local itemID
        local attempts = 0
        repeat
            itemID = TEST_ITEM_IDS[math.random(#TEST_ITEM_IDS)]
            attempts = attempts + 1
        until not usedIDs[itemID] or attempts > 20

        usedIDs[itemID] = true

        local itemLink = self:GenerateFakeItemLink(itemID)

        -- Pick a random fake council member as looter
        local looter = self.fakeCouncilMembers[math.random(2, #self.fakeCouncilMembers)]
        local looterName = looter and looter.name or LoothingUtils.GetPlayerFullName()

        local item = Loothing.Session:AddItem(itemLink, looterName)
        if item then
            addedCount = addedCount + 1
            self.fakeItems[#self.fakeItems + 1] = item
        end
    end

    print(string.format("|cff00ff00[Loothing]|r Added %d test items to session.", addedCount))

    -- Refresh UI
    if Loothing.UI and Loothing.UI.MainFrame then
        Loothing.UI.MainFrame:Refresh()
    end
end

--[[--------------------------------------------------------------------
    Vote Simulation
----------------------------------------------------------------------]]

--- Simulate votes on the current voting item
function LoothingTestMode:SimulateVotes()
    if not self.enabled then
        print("|cffff0000[Loothing]|r Test mode is not enabled. Use '/lt test' to enable.")
        return
    end

    if not Loothing or not Loothing.Session then
        print("|cffff0000[Loothing]|r Session module not loaded.")
        return
    end

    local currentItem = Loothing.Session:GetCurrentVotingItem()
    if not currentItem then
        print("|cffff0000[Loothing]|r No item is currently being voted on.")
        print("  Start voting on an item first, then run '/lt test vote'")
        return
    end

    local voteCount = 0

    -- Simulate votes from all fake council members (skip player at index 1)
    for i = 2, #self.fakeCouncilMembers do
        local member = self.fakeCouncilMembers[i]

        -- Skip if already voted
        if not currentItem:HasVoted(member.name) then
            -- Generate random responses
            local responses = self:GenerateRandomResponses()

            -- Add the vote directly
            currentItem:AddVote(member.name, member.class, responses)
            voteCount = voteCount + 1
        end
    end

    print(string.format("|cff00ff00[Loothing]|r Simulated %d votes.", voteCount))

    -- Trigger UI update
    if Loothing.Session.TriggerEvent then
        Loothing.Session:TriggerEvent("OnVoteReceived", currentItem)
    end

    -- Refresh UI
    if Loothing.UI and Loothing.UI.MainFrame then
        Loothing.UI.MainFrame:Refresh()
    end
end

--- Generate random vote responses
-- @return table - Array of LOOTHING_RESPONSE values
function LoothingTestMode:GenerateRandomResponses()
    local responses = {}
    local allResponses = {
        LOOTHING_RESPONSE.NEED,
        LOOTHING_RESPONSE.GREED,
        LOOTHING_RESPONSE.OFFSPEC,
        LOOTHING_RESPONSE.TRANSMOG,
        LOOTHING_RESPONSE.PASS,
    }

    -- Weight towards NEED and GREED for more interesting results
    local weights = { 40, 25, 15, 10, 10 }

    -- Pick first choice with weighting
    local roll = math.random(100)
    local cumulative = 0
    for i, weight in ipairs(weights) do
        cumulative = cumulative + weight
        if roll <= cumulative then
            responses[1] = allResponses[i]
            break
        end
    end

    -- Add 1-2 more choices for ranked voting
    local usedResponses = { [responses[1]] = true }
    for j = 2, math.random(2, 3) do
        local available = {}
        for _, r in ipairs(allResponses) do
            if not usedResponses[r] then
                available[#available + 1] = r
            end
        end
        if #available > 0 then
            local choice = available[math.random(#available)]
            responses[j] = choice
            usedResponses[choice] = true
        end
    end

    return responses
end

--[[--------------------------------------------------------------------
    Test Session Management
----------------------------------------------------------------------]]

--- Start a test session
function LoothingTestMode:StartTestSession()
    if not self.enabled then
        print("|cffff0000[Loothing]|r Test mode is not enabled. Use '/lt test' to enable.")
        return
    end

    if not Loothing or not Loothing.Session then
        print("|cffff0000[Loothing]|r Session module not loaded.")
        return
    end

    if Loothing.Session:IsActive() then
        print("|cffff0000[Loothing]|r A session is already active. End it first.")
        return
    end

    Loothing.Session:StartSession(0, "Test Encounter")
    print("|cff00ff00[Loothing]|r Test session started.")

    -- Refresh UI
    if Loothing.UI and Loothing.UI.MainFrame then
        Loothing.UI.MainFrame:Refresh()
    end
end

--- End the current test session
function LoothingTestMode:EndTestSession()
    if not Loothing or not Loothing.Session then
        return
    end

    if Loothing.Session:IsActive() then
        Loothing.Session:EndSession()
        self.fakeItems = {}
        print("|cff00ff00[Loothing]|r Test session ended.")
    end
end

--[[--------------------------------------------------------------------
    Cleanup
----------------------------------------------------------------------]]

--- Clear all fake data
function LoothingTestMode:ClearFakeData()
    self.fakeCouncilMembers = {}
    self.fakeItems = {}

    -- End any active test session
    if Loothing and Loothing.Session and Loothing.Session:IsActive() then
        Loothing.Session:EndSession()
    end
end

--[[--------------------------------------------------------------------
    Slash Command Handler
----------------------------------------------------------------------]]

--- Handle test mode slash commands
-- @param args string - Command arguments
function LoothingTestMode:HandleCommand(args)
    local cmd, param = args:match("^(%S*)%s*(.*)$")
    cmd = cmd:lower()

    if cmd == "" or cmd == "toggle" then
        self:Toggle()
    elseif cmd == "on" or cmd == "enable" then
        self:SetEnabled(true)
    elseif cmd == "off" or cmd == "disable" then
        self:SetEnabled(false)
    elseif cmd == "add" or cmd == "item" or cmd == "items" then
        local count = tonumber(param) or 3
        self:AddFakeItems(count)
    elseif cmd == "vote" or cmd == "votes" then
        self:SimulateVotes()
    elseif cmd == "session" or cmd == "start" then
        self:StartTestSession()
    elseif cmd == "end" or cmd == "stop" then
        self:EndTestSession()
    elseif cmd == "council" then
        local count = tonumber(param) or 5
        self:GenerateFakeCouncil(count)
        print(string.format("|cff00ff00[Loothing]|r Generated %d fake council members.", count))
    elseif cmd == "help" then
        print("|cff00ff00[Loothing]|r Test mode commands:")
        print("  /lt test - Toggle test mode")
        print("  /lt test on/off - Enable/disable test mode")
        print("  /lt test session - Start a test session")
        print("  /lt test add [count] - Add fake items (default 3)")
        print("  /lt test vote - Simulate votes on current item")
        print("  /lt test council [count] - Regenerate fake council (default 5)")
        print("  /lt test end - End test session")
    else
        print("|cffff0000[Loothing]|r Unknown test command: " .. cmd)
        print("  Use '/lt test help' for available commands.")
    end
end
