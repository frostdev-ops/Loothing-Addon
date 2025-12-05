--[[--------------------------------------------------------------------
    Loothing - Loot Council Addon for WoW 12.0+
    Utils - Helper functions
----------------------------------------------------------------------]]

local Loolib = LibStub("Loolib")

LoothingUtils = {}

--[[--------------------------------------------------------------------
    GUID Generation
----------------------------------------------------------------------]]

local guidCounter = 0

--- Generate a unique identifier
-- @return string - Unique ID in format "timestamp-counter"
function LoothingUtils.GenerateGUID()
    guidCounter = guidCounter + 1
    return string.format("%d-%d", time(), guidCounter)
end

--[[--------------------------------------------------------------------
    Item Link Parsing
----------------------------------------------------------------------]]

--- Extract item ID from an item link
-- @param itemLink string - Full item link
-- @return number|nil - Item ID or nil if invalid
function LoothingUtils.GetItemID(itemLink)
    if not itemLink then return nil end
    local itemID = itemLink:match("item:(%d+)")
    return itemID and tonumber(itemID)
end

--- Extract item name from an item link
-- @param itemLink string - Full item link
-- @return string|nil - Item name or nil if invalid
function LoothingUtils.GetItemName(itemLink)
    if not itemLink then return nil end
    return itemLink:match("%[(.-)%]")
end

--- Get item quality from link color
-- @param itemLink string - Full item link
-- @return number - Quality (0-7)
function LoothingUtils.GetItemQuality(itemLink)
    if not itemLink then return 0 end

    local colorCode = itemLink:match("|c(%x%x%x%x%x%x%x%x)")
    if not colorCode then return 0 end

    -- Map color codes to quality
    local qualityColors = {
        ["ff9d9d9d"] = 0,  -- Poor (gray)
        ["ffffffff"] = 1,  -- Common (white)
        ["ff1eff00"] = 2,  -- Uncommon (green)
        ["ff0070dd"] = 3,  -- Rare (blue)
        ["ffa335ee"] = 4,  -- Epic (purple)
        ["ffff8000"] = 5,  -- Legendary (orange)
        ["ffe6cc80"] = 6,  -- Artifact (tan)
        ["ff00ccff"] = 7,  -- Heirloom (cyan)
    }

    return qualityColors[colorCode:lower()] or 0
end

--- Get detailed item info
-- @param itemLink string - Full item link
-- @return table|nil - Item info table or nil
function LoothingUtils.GetItemInfo(itemLink)
    if not itemLink then return nil end

    local itemID = LoothingUtils.GetItemID(itemLink)
    if not itemID then return nil end

    local name, link, quality, itemLevel, reqLevel, class, subclass,
          maxStack, equipSlot, texture, vendorPrice = C_Item.GetItemInfo(itemLink)

    if not name then
        -- Item not cached, return basic info
        return {
            itemID = itemID,
            itemLink = itemLink,
            name = LoothingUtils.GetItemName(itemLink) or "Unknown",
            quality = LoothingUtils.GetItemQuality(itemLink),
        }
    end

    return {
        itemID = itemID,
        itemLink = link or itemLink,
        name = name,
        quality = quality,
        itemLevel = itemLevel,
        reqLevel = reqLevel,
        class = class,
        subclass = subclass,
        equipSlot = equipSlot,
        texture = texture,
    }
end

--[[--------------------------------------------------------------------
    Player Name Handling
----------------------------------------------------------------------]]

--- Get the player's full name including realm
-- @return string - "Name-Realm" format
function LoothingUtils.GetPlayerFullName()
    local name = UnitName("player")
    local realm = GetNormalizedRealmName()
    return name .. "-" .. realm
end

--- Normalize a player name to "Name-Realm" format
-- @param name string - Player name (may or may not include realm)
-- @return string - Normalized "Name-Realm" format
function LoothingUtils.NormalizeName(name)
    if not name then return nil end

    -- Already has realm
    if name:find("-") then
        return name
    end

    -- Add current realm
    local realm = GetNormalizedRealmName()
    return name .. "-" .. realm
end

--- Get short name (without realm)
-- @param fullName string - "Name-Realm" format
-- @return string - Just the name portion
function LoothingUtils.GetShortName(fullName)
    if not fullName then return nil end
    return fullName:match("^([^-]+)") or fullName
end

--- Check if two names refer to the same player
-- @param name1 string - First name
-- @param name2 string - Second name
-- @return boolean
function LoothingUtils.IsSamePlayer(name1, name2)
    if not name1 or not name2 then return false end
    return LoothingUtils.NormalizeName(name1) == LoothingUtils.NormalizeName(name2)
end

--[[--------------------------------------------------------------------
    Class Colors
----------------------------------------------------------------------]]

--- Get class color for a player
-- @param classFile string - Class file name (e.g., "WARRIOR")
-- @return table - { r, g, b } color values
function LoothingUtils.GetClassColor(classFile)
    if not classFile then
        return { r = 1, g = 1, b = 1 }
    end

    -- Try WoW's built-in colors first
    if RAID_CLASS_COLORS and RAID_CLASS_COLORS[classFile] then
        local color = RAID_CLASS_COLORS[classFile]
        return { r = color.r, g = color.g, b = color.b }
    end

    -- Fallback to our constants
    return LOOTHING_CLASS_COLORS[classFile] or { r = 1, g = 1, b = 1 }
end

--- Format text with class color
-- @param text string - Text to color
-- @param classFile string - Class file name
-- @return string - Color-coded text
function LoothingUtils.ColorByClass(text, classFile)
    local color = LoothingUtils.GetClassColor(classFile)
    return string.format("|cff%02x%02x%02x%s|r",
        math.floor(color.r * 255),
        math.floor(color.g * 255),
        math.floor(color.b * 255),
        text)
end

--[[--------------------------------------------------------------------
    Raid/Group Utilities
----------------------------------------------------------------------]]

--- Check if player is raid leader or assistant
-- @return boolean
function LoothingUtils.IsRaidLeaderOrAssistant()
    -- Test mode bypasses raid requirements
    if LoothingTestMode and LoothingTestMode:IsEnabled() then
        return true
    end

    if not IsInRaid() then return false end
    return UnitIsGroupLeader("player") or UnitIsGroupAssistant("player")
end

--- Check if player is the master looter
-- @return boolean
function LoothingUtils.IsMasterLooter()
    -- Test mode bypasses raid requirements
    if LoothingTestMode and LoothingTestMode:IsEnabled() then
        return true
    end

    local lootMethod, masterLooterPartyID = GetLootMethod()
    if lootMethod ~= "master" then return false end

    if masterLooterPartyID == 0 then
        return true  -- Player is ML
    end

    return false
end

--- Get raid roster as a table
-- @return table - Array of { name, rank, class, online, role }
function LoothingUtils.GetRaidRoster()
    -- Test mode returns fake roster
    if LoothingTestMode and LoothingTestMode:IsEnabled() then
        return LoothingTestMode:GetFakeRaidRoster()
    end

    local roster = {}

    if not IsInRaid() then
        return roster
    end

    local numMembers = GetNumGroupMembers()
    for i = 1, numMembers do
        local name, rank, subgroup, level, class, fileName, zone,
              online, isDead, role, isML, assignedRole = GetRaidRosterInfo(i)

        if name then
            roster[#roster + 1] = {
                name = LoothingUtils.NormalizeName(name),
                shortName = name,
                rank = rank,
                subgroup = subgroup,
                level = level,
                class = class,
                classFile = fileName,
                online = online,
                isDead = isDead,
                role = assignedRole or role,
                isMasterLooter = isML,
            }
        end
    end

    return roster
end

--- Get officers from raid (rank >= 1)
-- @return table - Array of officer names
function LoothingUtils.GetRaidOfficers()
    local officers = {}
    local roster = LoothingUtils.GetRaidRoster()

    for _, member in ipairs(roster) do
        if member.rank and member.rank >= 1 then
            officers[#officers + 1] = member.name
        end
    end

    return officers
end

--- Get raid leader name
-- @return string|nil - Leader name or nil
function LoothingUtils.GetRaidLeader()
    local roster = LoothingUtils.GetRaidRoster()

    for _, member in ipairs(roster) do
        if member.rank == 2 then
            return member.name
        end
    end

    return nil
end

--[[--------------------------------------------------------------------
    Time Formatting
----------------------------------------------------------------------]]

--- Format seconds as MM:SS
-- @param seconds number
-- @return string
function LoothingUtils.FormatTime(seconds)
    if not seconds or seconds < 0 then
        return "0:00"
    end

    local mins = math.floor(seconds / 60)
    local secs = math.floor(seconds % 60)
    return string.format("%d:%02d", mins, secs)
end

--- Format timestamp as date string
-- @param timestamp number - Unix timestamp
-- @return string - Formatted date
function LoothingUtils.FormatDate(timestamp)
    return date("%Y-%m-%d %H:%M", timestamp)
end

--[[--------------------------------------------------------------------
    Table Utilities
----------------------------------------------------------------------]]

--- Deep copy a table
-- @param orig table
-- @return table
function LoothingUtils.DeepCopy(orig)
    local copy
    if type(orig) == "table" then
        copy = {}
        for key, value in next, orig, nil do
            copy[LoothingUtils.DeepCopy(key)] = LoothingUtils.DeepCopy(value)
        end
        setmetatable(copy, LoothingUtils.DeepCopy(getmetatable(orig)))
    else
        copy = orig
    end
    return copy
end

--- Check if a value exists in an array
-- @param tbl table - Array to search
-- @param value any - Value to find
-- @return boolean
function LoothingUtils.Contains(tbl, value)
    for _, v in ipairs(tbl) do
        if v == value then
            return true
        end
    end
    return false
end

--- Remove a value from an array
-- @param tbl table - Array to modify
-- @param value any - Value to remove
-- @return boolean - True if removed
function LoothingUtils.RemoveValue(tbl, value)
    for i, v in ipairs(tbl) do
        if v == value then
            table.remove(tbl, i)
            return true
        end
    end
    return false
end

--[[--------------------------------------------------------------------
    String Utilities
----------------------------------------------------------------------]]

--- Split a string by delimiter
-- @param str string - String to split
-- @param delimiter string - Delimiter character
-- @return table - Array of parts
function LoothingUtils.Split(str, delimiter)
    local result = {}
    local pattern = string.format("([^%s]+)", delimiter)
    for match in str:gmatch(pattern) do
        result[#result + 1] = match
    end
    return result
end

--- Join array elements with delimiter
-- @param tbl table - Array to join
-- @param delimiter string - Delimiter
-- @return string
function LoothingUtils.Join(tbl, delimiter)
    return table.concat(tbl, delimiter)
end

--- Escape special characters for pattern matching
-- @param str string
-- @return string
function LoothingUtils.EscapePattern(str)
    return str:gsub("([%^%$%(%)%%%.%[%]%*%+%-%?])", "%%%1")
end
