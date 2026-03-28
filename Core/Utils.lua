--[[--------------------------------------------------------------------
    Loothing - Loot Council Addon for WoW 12.0+
    Utils - Helper functions
----------------------------------------------------------------------]]

local _, ns = ...
local Loolib = LibStub("Loolib")
local Loothing = ns.Addon
local date, ipairs, time, tonumber = date, ipairs, time, tonumber

local Utils = ns.Utils or {}
ns.Utils = Utils

--[[--------------------------------------------------------------------
    Secret Value Guards (WoW 12.0+)
    WoW can return opaque "secret values" from unit APIs during combat.
    Any operation (==, string ops, table key) on a secret value errors.
    Use these guards before processing unit API returns.
----------------------------------------------------------------------]]

--- Check if any of the given values are WoW secret values
-- Delegates to Loolib.SecretUtil for backward compatibility.
-- @param ... - Values to check
-- @return boolean - True if any value is secret
function Utils.IsSecretValue(...)
    return Loolib.SecretUtil.IsSecretValue(...)
end

--- Replace secret values with "<secret>" for safe printing
-- Delegates to Loolib.SecretUtil for backward compatibility.
-- @param ... - Values to sanitize
-- @return ... - Sanitized values
function Utils.SecretsForPrint(...)
    return Loolib.SecretUtil.SecretsForPrint(...)
end

local function IsTestModeEnabled()
    local TestMode = ns.TestModeState
    return TestMode and TestMode:IsActive()
end

--[[--------------------------------------------------------------------
    Version Comparison
----------------------------------------------------------------------]]

--- Compare two semantic version strings ("major.minor.patch")
-- @param v1 string
-- @param v2 string
-- @return number - -1 if v1 < v2, 0 if equal, 1 if v1 > v2
function Utils.CompareVersions(v1, v2)
    if not v1 or not v2 then return 0 end

    local major1, minor1, patch1 = v1:match("^(%d+)%.(%d+)%.(%d+)")
    local major2, minor2, patch2 = v2:match("^(%d+)%.(%d+)%.(%d+)")

    major1, minor1, patch1 = tonumber(major1) or 0, tonumber(minor1) or 0, tonumber(patch1) or 0
    major2, minor2, patch2 = tonumber(major2) or 0, tonumber(minor2) or 0, tonumber(patch2) or 0

    if major1 ~= major2 then return major1 < major2 and -1 or 1 end
    if minor1 ~= minor2 then return minor1 < minor2 and -1 or 1 end
    if patch1 ~= patch2 then return patch1 < patch2 and -1 or 1 end

    return 0
end

--[[--------------------------------------------------------------------
    GUID Generation
----------------------------------------------------------------------]]

local guidCounter = 0
local guidSalt = math.random(0, 0xFFFF)  -- Random per-session salt to prevent cross-reload collisions

--- Generate a unique identifier
-- @return string - Unique ID in format "timestamp-salt-counter"
function Utils.GenerateGUID()
    guidCounter = guidCounter + 1
    return string.format("%d-%04x-%d", time(), guidSalt, guidCounter)
end

--[[--------------------------------------------------------------------
    Item Link Parsing
----------------------------------------------------------------------]]

--- Extract item ID from an item link
-- @param itemLink string - Full item link
-- @return number|nil - Item ID or nil if invalid
function Utils.GetItemID(itemLink)
    if not itemLink then return nil end
    local itemID = itemLink:match("item:(%d+)")
    return itemID and tonumber(itemID)
end

--- Extract item name from an item link
-- @param itemLink string - Full item link
-- @return string|nil - Item name or nil if invalid
function Utils.GetItemName(itemLink)
    if not itemLink then return nil end
    return itemLink:match("%[(.-)%]")
end

--- Get item quality from link color
-- @param itemLink string - Full item link
-- @return number - Quality (0-7)
function Utils.GetItemQuality(itemLink)
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
function Utils.GetItemInfo(itemLink)
    if not itemLink then return nil end

    local itemID = Utils.GetItemID(itemLink)
    if not itemID then return nil end

    local name, link, quality, itemLevel, reqLevel, class, subclass,
          _maxStack, equipSlot, texture, _vendorPrice = C_Item.GetItemInfo(itemLink)

    if not name then
        -- Item not cached, return basic info
        return {
            itemID = itemID,
            itemLink = itemLink,
            name = Utils.GetItemName(itemLink) or "Unknown",
            quality = Utils.GetItemQuality(itemLink),
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
function Utils.GetPlayerFullName()
    local name = Loolib.SecretUtil.SafeUnitName("player")
    if not name then return nil end
    local realm = GetNormalizedRealmName() or GetRealmName() or ""
    if realm == "" then
        return name
    end
    return name .. "-" .. realm
end

--- Normalize a player name to "Name-Realm" format
-- @param name string - Player name (may or may not include realm)
-- @return string - Normalized "Name-Realm" format
function Utils.NormalizeName(name)
    if not name or Loolib.SecretUtil.IsSecretValue(name) then return nil end

    -- Already has realm
    if name:find("-") then
        return name
    end

    -- Add current realm (nil-safe: GetNormalizedRealmName can return nil before PLAYER_LOGIN)
    local realm = GetNormalizedRealmName() or GetRealmName() or ""
    if realm == "" then
        return name
    end
    return name .. "-" .. realm
end

--- Get short name (without realm)
-- @param fullName string - "Name-Realm" format
-- @return string - Just the name portion
function Utils.GetShortName(fullName)
    if not fullName or Loolib.SecretUtil.IsSecretValue(fullName) then return nil end
    return fullName:match("^([^-]+)") or fullName
end

--- Check if two names refer to the same player
-- @param name1 string - First name
-- @param name2 string - Second name
-- @return boolean
function Utils.IsSamePlayer(name1, name2)
    if not name1 or not name2 then return false end
    if Loolib.SecretUtil.IsSecretValue(name1, name2) then return false end
    return Utils.NormalizeName(name1) == Utils.NormalizeName(name2)
end

--[[--------------------------------------------------------------------
    Class Colors
----------------------------------------------------------------------]]

--- Get class color for a player
-- @param classFile string - Class file name (e.g., "WARRIOR")
-- @return table - { r, g, b } color values
function Utils.GetClassColor(classFile)
    if not classFile then
        return { r = 1, g = 1, b = 1 }
    end

    -- Try WoW's built-in colors first
    if RAID_CLASS_COLORS and RAID_CLASS_COLORS[classFile] then
        local color = RAID_CLASS_COLORS[classFile]
        return { r = color.r, g = color.g, b = color.b }
    end

    -- Fallback to our constants
    return Loothing.ClassColors[classFile] or { r = 1, g = 1, b = 1 }
end

--- Format text with class color
-- @param text string - Text to color
-- @param classFile string - Class file name
-- @return string - Color-coded text
function Utils.ColorByClass(text, classFile)
    local color = Utils.GetClassColor(classFile)
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
function Utils.IsRaidLeaderOrAssistant()
    -- Test mode bypasses raid requirements
    if IsTestModeEnabled() then
        return true
    end

    -- In party (non-raid), party leader counts as ML equivalent
    if not IsInRaid() then
        return IsInGroup() and UnitIsGroupLeader("player")
    end
    return UnitIsGroupLeader("player") or UnitIsGroupAssistant("player")
end

--- Check if a named player is a group/raid leader or assistant
-- @param name string - Player name (possibly realm-qualified)
-- @return boolean
function Utils.IsPlayerLeaderOrAssistant(name)
    if not name or not IsInGroup() then return false end

    if IsInRaid() then
        for i = 1, GetNumGroupMembers() do
            local rosterName, rank = Loolib.SecretUtil.SafeGetRaidRosterInfo(i)
            if rosterName and Utils.IsSamePlayer(name, rosterName) then
                -- rank: 2 = leader, 1 = assistant, 0 = member
                return rank and rank >= 1
            end
        end
    else
        -- In party, check self first then party1-4
        if Utils.IsSamePlayer(name, Utils.GetPlayerFullName()) then
            return UnitIsGroupLeader("player")
        end
        for i = 1, 4 do
            local unit = "party" .. i
            if UnitExists(unit) then
                local unitName = Loolib.SecretUtil.SafeUnitName(unit)
                if unitName and Utils.IsSamePlayer(name, unitName) then
                    return UnitIsGroupLeader(unit)
                end
            end
        end
    end

    return false
end

--- Check if player is raid/party leader
-- @return boolean
function Utils.IsRaidLeader()
    -- Test mode bypasses raid requirements
    if IsTestModeEnabled() then
        return true
    end

    return UnitIsGroupLeader("player")
end

--- Get the effective group loot mode (MLDB authoritative, local fallback)
-- When MLDB hasn't arrived yet and a session is active, defaults to "passive"
-- to prevent auto-rolling before the ML's intent is known (HIGH-1 race fix).
-- @return string - "active" or "passive"
function Utils.GetEffectiveGroupLootMode()
    local mldb = Loothing and Loothing.MLDB and Loothing.MLDB:Get()
    if mldb and (mldb.groupLootMode == "active" or mldb.groupLootMode == "passive") then
        return mldb.groupLootMode
    end

    -- Conservative default: if MLDB hasn't arrived but a session is active,
    -- assume passive to avoid auto-rolling when ML intended passive mode
    if not mldb and Loothing and Loothing.Session
        and Loothing.Session.state and Loothing.Session.state ~= Loothing.SessionState.INACTIVE then
        return "passive"
    end

    if Loothing and Loothing.Settings and Loothing.Settings.GetGroupLootMode then
        return Loothing.Settings:GetGroupLootMode()
    end

    return "active"
end

--- Check if player is the master looter
-- In WoW 12.0+ Master Loot is removed; falls back to group leader check
-- @return boolean
function Utils.IsMasterLooter()
    -- Test mode bypasses raid requirements
    if IsTestModeEnabled() then
        return true
    end

    -- WoW 12.0+ removed GetLootMethod; treat group leader as ML equivalent
    if not Loothing.GetLootMethod then
        return UnitIsGroupLeader("player")
    end

    local lootMethod, masterLooterPartyID = Loothing.GetLootMethod()
    local masterLooterEnum = Enum and Enum.LootMethod and Enum.LootMethod.Masterlooter
    if lootMethod ~= "master" and lootMethod ~= masterLooterEnum then
        return false
    end

    if masterLooterPartyID == 0 then
        return true  -- Player is ML
    end

    return false
end

--- Check if the local player can manage council/observer rosters.
-- Solo clients may edit their saved defaults; grouped clients must be the active ML.
-- @return boolean
function Utils.CanManageCouncilRoster()
    if IsTestModeEnabled() then
        return true
    end

    if not IsInGroup() then
        return true
    end

    return Loothing:IsCanonicalML()
end

--[[--------------------------------------------------------------------
    Instance Type Utilities
----------------------------------------------------------------------]]

--- Get current instance type info
-- @return string instanceType - "none", "party", "raid", "pvp", "arena", "scenario"
-- @return string difficultyName - e.g. "Normal", "Heroic", "Mythic"
-- @return number difficultyID
function Utils.GetInstanceInfo()
    local instanceType, difficultyID, difficultyName = select(2, GetInstanceInfo())
    return instanceType or "none", difficultyName or "", difficultyID or 0
end

--- Check if current instance is a PvP, arena, or scenario zone
-- These instance types should never trigger ML detection
-- @return boolean
function Utils.IsInPvPOrScenario()
    local instanceType = Utils.GetInstanceInfo()
    return instanceType == "pvp" or instanceType == "arena" or instanceType == "scenario"
end

--- Check if currently in a raid instance
-- @return boolean
function Utils.IsInRaidInstance()
    local instanceType = Utils.GetInstanceInfo()
    return instanceType == "raid"
end

--- Check if currently in a dungeon instance
-- @return boolean
function Utils.IsInDungeonInstance()
    local instanceType = Utils.GetInstanceInfo()
    return instanceType == "party"
end

--- Check if the group is a guild group (leader is in our guild)
-- @return boolean
function Utils.IsGuildGroup()
    if not IsInGuild() then
        return false
    end

    -- Check if group/raid leader is in our guild
    if IsInRaid() then
        for i = 1, GetNumGroupMembers() do
            local name, rank = Loolib.SecretUtil.SafeGetRaidRosterInfo(i)
            if rank == 2 and name then
                -- Raid leader found, check if in guild
                return Utils.IsPlayerInGuild(name)
            end
        end
    elseif IsInGroup() then
        -- Party leader
        if UnitIsGroupLeader("player") then
            return true  -- We're leader and in a guild
        end
        for i = 1, 4 do
            local unit = "party" .. i
            if UnitExists(unit) and UnitIsGroupLeader(unit) then
                return Loothing.UnitIsInMyGuild and Loothing.UnitIsInMyGuild(unit)
            end
        end
    end

    return false
end

--- Check if a player is in our guild
-- @param name string - Player name
-- @return boolean
function Utils.IsPlayerInGuild(name)
    if not name or not IsInGuild() then
        return false
    end

    local numMembers = GetNumGuildMembers()
    for i = 1, numMembers do
        local guildName = Loothing.GetGuildRosterInfo and Loothing.GetGuildRosterInfo(i)
        if guildName then
            -- Guild names include realm: "Name-Realm"
            local shortGuild = guildName:match("^([^-]+)") or guildName
            local shortName = name:match("^([^-]+)") or name
            if shortGuild == shortName then
                return true
            end
        end
    end

    return false
end

--- Get raid roster as a table
-- @return table - Array of { name, rank, class, online, role }
function Utils.GetRaidRoster()
    -- Test mode returns fake roster
    local TestMode = ns.TestModeState
    if IsTestModeEnabled() and TestMode then
        return TestMode:GetFakeRaidRoster()
    end

    local roster = {}

    if IsInRaid() then
        local numMembers = GetNumGroupMembers()
        for i = 1, numMembers do
            local name, rank, subgroup, level, class, fileName, _, online, isDead, role, isML, assignedRole =
                Loolib.SecretUtil.SafeGetRaidRosterInfo(i)

            if name then
                roster[#roster + 1] = {
                    name = Utils.NormalizeName(name),
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
    elseif IsInGroup() then
        -- Party group fallback (up to 4 party members + self)
        local units = { "player" }
        for i = 1, GetNumSubgroupMembers() do
            units[#units + 1] = "party" .. i
        end
        for _, unit in ipairs(units) do
            local name = Loolib.SecretUtil.SafeUnitName(unit)
            if name then
                local localizedClass, classFile = Loolib.SecretUtil.SafeUnitClass(unit)
                local isLeader = UnitIsGroupLeader(unit)
                local isAssistant = UnitIsGroupAssistant(unit)
                roster[#roster + 1] = {
                    name = Utils.NormalizeName(name),
                    shortName = name,
                    rank = isLeader and 2 or (isAssistant and 1 or 0),
                    class = localizedClass,
                    classFile = classFile,
                    online = UnitIsConnected(unit),
                    isDead = UnitIsDead(unit),
                    role = UnitGroupRolesAssigned(unit),
                    isMasterLooter = false,
                }
            end
        end
    else
        Loothing:Debug("GetRaidRoster: not in any group, returning empty roster")
    end

    return roster
end

--- Check if a player is in the current group (raid or party)
-- @param playerName string - Player name (with or without realm suffix)
-- @return boolean
function Utils.IsGroupMember(playerName)
    if IsTestModeEnabled() then return true end
    if not playerName or playerName == "" then return false end
    local roster = Utils.GetRaidRoster()
    for _, member in ipairs(roster) do
        if Utils.IsSamePlayer(member.name, playerName) then
            return true
        end
    end
    return false
end

--- Get officers from raid (rank >= 1)
-- @return table - Array of officer names
function Utils.GetRaidOfficers()
    local officers = {}
    local roster = Utils.GetRaidRoster()

    for _, member in ipairs(roster) do
        if member.rank and member.rank >= 1 then
            officers[#officers + 1] = member.name
        end
    end

    return officers
end

--- Get raid leader name
-- @return string|nil - Leader name or nil
function Utils.GetRaidLeader()
    local roster = Utils.GetRaidRoster()

    for _, member in ipairs(roster) do
        if member.rank == 2 then
            return member.name
        end
    end

    return nil
end

--- Check if a player (by name) is in the current group/raid
-- @param name string - Player name (short or normalized)
-- @return boolean
function Utils.IsPlayerInCurrentGroup(name)
    if not name or Loolib.SecretUtil.IsSecretValue(name) then return false end
    if not IsInGroup() then return false end

    -- Check self first
    if Utils.IsSamePlayer(name, Utils.GetPlayerFullName()) then
        return true
    end

    if IsInRaid() then
        for i = 1, GetNumGroupMembers() do
            local rosterName = Loolib.SecretUtil.SafeGetRaidRosterInfo(i)
            if rosterName and Utils.IsSamePlayer(name, rosterName) then
                return true
            end
        end
    else
        for i = 1, 4 do
            local unit = "party" .. i
            if UnitExists(unit) then
                local unitName = Loolib.SecretUtil.SafeUnitName(unit)
                if unitName and Utils.IsSamePlayer(name, unitName) then
                    return true
                end
            end
        end
    end

    return false
end

--[[--------------------------------------------------------------------
    Time Formatting
----------------------------------------------------------------------]]

--- Format seconds as MM:SS
-- @param seconds number
-- @return string
function Utils.FormatTime(seconds)
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
function Utils.FormatDate(timestamp)
    return date("%Y-%m-%d %H:%M", timestamp)
end

--[[--------------------------------------------------------------------
    Table Utilities
----------------------------------------------------------------------]]

--- Deep copy a table
-- Delegates to Loolib.TableUtil.DeepCopy (handles circular references).
-- @param orig table
-- @return table
function Utils.DeepCopy(orig)
    return Loolib.TableUtil.DeepCopy(orig)
end

--- Check if a value exists in a table
-- Delegates to Loolib.TableUtil.Contains (uses pairs, works on arrays and maps).
-- @param tbl table - Table to search
-- @param value any - Value to find
-- @return boolean
function Utils.Contains(tbl, value)
    return Loolib.TableUtil.Contains(tbl, value)
end

--- Remove a value from an array
-- Delegates to Loolib.TableUtil.RemoveByValue.
-- @param tbl table - Array to modify
-- @param value any - Value to remove
-- @return boolean - True if removed
function Utils.RemoveValue(tbl, value)
    return Loolib.TableUtil.RemoveByValue(tbl, value)
end

--[[--------------------------------------------------------------------
    String Utilities
----------------------------------------------------------------------]]

--- Split a string by delimiter
-- @param str string - String to split
-- @param delimiter string - Delimiter character
-- @return table - Array of parts
function Utils.Split(str, delimiter)
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
function Utils.Join(tbl, delimiter)
    return table.concat(tbl, delimiter)
end

--- Escape special characters for pattern matching
-- @param str string
-- @return string
function Utils.EscapePattern(str)
    return str:gsub("([%^%$%(%)%%%.%[%]%*%+%-%?])", "%%%1")
end

--[[--------------------------------------------------------------------
    Settings UI (config dialog refresh + MLDB sync)
----------------------------------------------------------------------]]

--- Refresh the Loothing entry in the Loolib settings / config dialog.
function Utils.NotifySettingsDialogRefresh()
    local Config = Loolib.Config
    if Config and type(Config.NotifyChange) == "function" then
        Config:NotifyChange("Loothing")
    elseif Config and Config.Dialog then
        Config.Dialog:RefreshContent("Loothing")
    end
end

--- If this client is master looter, broadcast MLDB so the raid stays in sync after edits.
function Utils.BroadcastMLDBIfML()
    if Loothing.MLDB and Loothing.MLDB:IsML() then
        Loothing.MLDB:BroadcastToRaid()
    end
end

--[[--------------------------------------------------------------------
    Color Utilities
----------------------------------------------------------------------]]

--- Convert array-format color {r, g, b, a} to named-field format {r=, g=, b=, a=}
-- Accepts either format; if already named, returns as-is.
-- @param color table
-- @return table - Named format {r=, g=, b=, a=}
function Utils.ColorToNamed(color)
    if not color then return { r = 1, g = 1, b = 1, a = 1 } end
    if color.r ~= nil then return color end
    return { r = color[1] or 1, g = color[2] or 1, b = color[3] or 1, a = color[4] or 1 }
end

--[[--------------------------------------------------------------------
    Schema Validation
----------------------------------------------------------------------]]

--- Validate incoming message data against a field schema
-- Schema entries are { fieldName, expectedType, required }
-- @param data table - The message data to validate
-- @param schema table - Array of { field, type, required } entries
-- @return boolean, string|nil - ok, reason string on failure
function Utils.ValidateSchema(data, schema)
    for _, entry in ipairs(schema) do
        local field, expectedType, required = entry[1], entry[2], entry[3]
        local val = data[field]
        if val == nil then
            if required then
                return false, "missing required field: " .. field
            end
        elseif expectedType and type(val) ~= expectedType then
            return false, "field '" .. field .. "' expected " .. expectedType .. " got " .. type(val)
        end
    end
    return true
end

--- Convert named-field color {r=, g=, b=, a=} to array format {r, g, b, a}
-- Accepts either format; if already array, returns as-is.
-- @param color table
-- @return table - Array format {r, g, b, a}
function Utils.ColorToArray(color)
    if not color then return { 1, 1, 1, 1 } end
    if color.r ~= nil then
        return { color.r, color.g or 1, color.b or 1, color.a or 1 }
    end
    if color[1] ~= nil then
        -- Ensure a dense 4-element array (guards against sparse arrays from SV stripping)
        return { color[1], color[2] or 0, color[3] or 0, color[4] or 1 }
    end
    return { 1, 1, 1, 1 }
end
