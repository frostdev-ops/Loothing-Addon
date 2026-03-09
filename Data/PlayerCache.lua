--[[--------------------------------------------------------------------
    Loothing - Loot Council Addon for WoW 12.0+
    PlayerCache - GUID-based player data cache

    Provides a caching layer for player information (name, class, role,
    ilvl, spec, etc.) keyed by GUID. Supports cross-session persistence
    via SavedVariables global scope.

    Follows RCLootCouncil's Data.Player pattern:
    - Primary key: GUID (Player-XXXX-XXXXXXXX)
    - Secondary lookup: Name-Realm
    - TTL-based expiry (2 days default, council members never expire)
    - Handles GetPlayerInfoByGUID() null-byte bug

    Usage:
        local cache = CreateLoothingPlayerCache()
        local player = cache:Get("Player-1234-ABCDEF")
        local player = cache:GetOrCreate("PlayerName-RealmName")
        cache:Update("Player-1234-ABCDEF", { role = "TANK", ilvl = 600 })
----------------------------------------------------------------------]]

local Loolib = LibStub("Loolib")

--[[--------------------------------------------------------------------
    LoothingPlayerCacheMixin
----------------------------------------------------------------------]]

LoothingPlayerCacheMixin = LoolibCreateFromMixins(LoolibCallbackRegistryMixin)

local PLAYER_CACHE_EVENTS = {
    "OnPlayerAdded",
    "OnPlayerUpdated",
    "OnPlayerRemoved",
    "OnCacheCleared",
}

-- Cache TTL: 2 days in seconds
local DEFAULT_TTL = 2 * 24 * 60 * 60

-- GUID pattern: "Player-XXXX-XXXXXXXX"
local GUID_PATTERN = "^Player%-%d+%-%x+$"

--- Initialize the player cache
function LoothingPlayerCacheMixin:Init()
    LoolibCallbackRegistryMixin.OnLoad(self)
    self:GenerateCallbackEvents(PLAYER_CACHE_EVENTS)

    -- In-memory cache: guid -> player table
    self.byGUID = {}
    self.savePending = false

    -- Secondary index: "Name-Realm" -> guid
    self.byName = {}

    -- Load from SavedVariables if available
    self:LoadFromSavedVariables()

    Loothing:Debug("PlayerCache initialized with", self:GetSize(), "entries")
end

--[[--------------------------------------------------------------------
    Core Access Methods
----------------------------------------------------------------------]]

--- Get a player by GUID or Name-Realm
-- Checks cache first, then falls back to GetPlayerInfoByGUID() for GUIDs
-- @param nameOrGUID string - GUID or "Name-Realm"
-- @return table|nil - Player data table or nil
function LoothingPlayerCacheMixin:Get(nameOrGUID)
    if not nameOrGUID or nameOrGUID == "" then
        return nil
    end
    if LoolibSecretUtil.IsSecretValue(nameOrGUID) then return nil end

    -- Check if it's a GUID
    if nameOrGUID:match(GUID_PATTERN) then
        local player = self.byGUID[nameOrGUID]
        if player and self:IsValid(player) then
            return player
        end

        -- Fall back to GetPlayerInfoByGUID
        return self:FetchFromGUID(nameOrGUID)
    end

    -- Name-Realm lookup
    local guid = self.byName[nameOrGUID]
    if guid then
        local player = self.byGUID[guid]
        if player and self:IsValid(player) then
            return player
        end
    end

    return nil
end

--- Get or create a player entry
-- Creates an empty entry if not cached
-- @param nameOrGUID string - GUID or "Name-Realm"
-- @return table - Player data table (may be empty)
function LoothingPlayerCacheMixin:GetOrCreate(nameOrGUID)
    local player = self:Get(nameOrGUID)
    if player then
        return player
    end
    if LoolibSecretUtil.IsSecretValue(nameOrGUID) then return nil end

    -- Create new empty entry
    if nameOrGUID:match(GUID_PATTERN) then
        -- Try to fetch basic info from GUID
        local fetchedPlayer = self:FetchFromGUID(nameOrGUID)
        if fetchedPlayer then
            return fetchedPlayer
        end

        -- Create bare entry with just the GUID
        return self:CreateEntry(nameOrGUID, nil, nil, nil)
    end

    -- Name-based: create minimal entry without GUID
    local name, realm = self:SplitNameRealm(nameOrGUID)
    return self:CreateEntry(nil, name, realm, nil)
end

--- Update specific fields on a cached player
-- @param guid string - Player GUID
-- @param fields table - Fields to update (e.g., { role = "TANK", ilvl = 600 })
function LoothingPlayerCacheMixin:Update(guid, fields)
    if not guid or not fields then return end

    local player = self.byGUID[guid]
    if not player then
        -- Create new entry if updating by GUID
        player = self:CreateEntry(guid, nil, nil, nil)
    end

    -- Apply field updates
    for key, value in pairs(fields) do
        player[key] = value
    end
    player.cacheTime = time()

    self:TriggerEvent("OnPlayerUpdated", player)
    self:MarkDirty()
end

--- Remove a player from the cache
-- @param nameOrGUID string - GUID or "Name-Realm"
-- @return boolean - True if removed
function LoothingPlayerCacheMixin:Invalidate(nameOrGUID)
    if not nameOrGUID or nameOrGUID == "" then
        return false
    end
    if LoolibSecretUtil.IsSecretValue(nameOrGUID) then return false end

    local guid

    if nameOrGUID:match(GUID_PATTERN) then
        guid = nameOrGUID
    else
        guid = self.byName[nameOrGUID]
    end

    if not guid or not self.byGUID[guid] then
        return false
    end

    local player = self.byGUID[guid]

    -- Remove from secondary index
    if player.name and player.realm then
        self.byName[player.name .. "-" .. player.realm] = nil
    end
    if player.name then
        self.byName[player.name] = nil
    end

    -- Remove from primary cache
    self.byGUID[guid] = nil

    self:TriggerEvent("OnPlayerRemoved", player)
    self:MarkDirty()

    Loothing:Debug("PlayerCache:Invalidate", nameOrGUID)
    return true
end

--- Remove all expired entries from cache
-- @return number - Number of entries removed
function LoothingPlayerCacheMixin:CleanExpired()
    local removed = 0
    local currentTime = time()
    local expiredGUIDs = {}

    for guid, player in pairs(self.byGUID) do
        if not self:IsValid(player) then
            expiredGUIDs[#expiredGUIDs + 1] = guid
        end
    end

    for _, guid in ipairs(expiredGUIDs) do
        self:Invalidate(guid)
        removed = removed + 1
    end

    if removed > 0 then
        Loothing:Debug("PlayerCache:CleanExpired - removed", removed, "entries")
        self:SaveToSavedVariables()
    end

    return removed
end

--- Clear the entire cache
function LoothingPlayerCacheMixin:Clear()
    wipe(self.byGUID)
    wipe(self.byName)
    self:SaveToSavedVariables() -- Immediate save for destructive operations
    self:TriggerEvent("OnCacheCleared")
    Loothing:Debug("PlayerCache cleared")
end

--- Get the number of cached players
-- @return number
function LoothingPlayerCacheMixin:GetSize()
    local count = 0
    for _ in pairs(self.byGUID) do
        count = count + 1
    end
    return count
end

--[[--------------------------------------------------------------------
    Internal Methods
----------------------------------------------------------------------]]

--- Create a new cache entry
-- @param guid string|nil - Player GUID
-- @param name string|nil - Player name
-- @param realm string|nil - Player realm
-- @param class string|nil - Player class (uppercase file name)
-- @return table - New player entry
function LoothingPlayerCacheMixin:CreateEntry(guid, name, realm, class)
    local player = {
        guid = guid,
        name = name,
        realm = realm,
        class = class,
        role = nil,
        rank = nil,
        enchanter = nil,
        ilvl = nil,
        specID = nil,
        isInGuild = nil,
        isCouncil = nil,
        cacheTime = time(),
    }

    -- Add to primary index
    if guid then
        self.byGUID[guid] = player
    end

    -- Add to secondary index
    if name and realm then
        self.byName[name .. "-" .. realm] = guid
    end
    -- Only store short name if no collision exists (cross-realm players may share names)
    if name and guid then
        local existingGUID = self.byName[name]
        if not existingGUID or existingGUID == guid then
            self.byName[name] = guid
        end
        -- If collision: don't overwrite, require full Name-Realm lookup
    end

    self:TriggerEvent("OnPlayerAdded", player)
    self:MarkDirty()

    return player
end

--- Fetch player data from GetPlayerInfoByGUID and cache it
-- @param guid string - Player GUID
-- @return table|nil - Player data or nil if not available
function LoothingPlayerCacheMixin:FetchFromGUID(guid)
    if not guid or not GetPlayerInfoByGUID then
        return nil
    end

    local _, englishClass, _, _, _, name, realmName = LoolibSecretUtil.SafeGetPlayerInfoByGUID(guid)

    if not name then
        return nil
    end

    -- Handle null-byte bug in GetPlayerInfoByGUID
    name = self:StripNullBytes(name)
    if realmName then
        realmName = self:StripNullBytes(realmName)
    end

    -- Use current realm if not returned
    -- (GetNormalizedRealmName can return nil before PLAYER_LOGIN; fall back to GetRealmName)
    if not realmName or realmName == "" then
        realmName = GetNormalizedRealmName() or GetRealmName()
    end

    -- Check if we already have this entry
    local existing = self.byGUID[guid]
    if existing then
        -- Update with fresh data
        existing.name = name
        existing.realm = realmName
        existing.class = englishClass
        existing.cacheTime = time()

        -- Update secondary index
        self.byName[name .. "-" .. realmName] = guid
        -- Only store short name if no collision
        local existingShort = self.byName[name]
        if not existingShort or existingShort == guid then
            self.byName[name] = guid
        end

        return existing
    end

    -- Create new entry
    return self:CreateEntry(guid, name, realmName, englishClass)
end

--- Check if a cached player entry is still valid (not expired)
-- @param player table - Player data
-- @return boolean
function LoothingPlayerCacheMixin:IsValid(player)
    if not player or not player.cacheTime then
        return false
    end

    -- Council members never expire
    if player.isCouncil then
        return true
    end

    local elapsed = time() - player.cacheTime
    return elapsed < DEFAULT_TTL
end

--- Strip null-byte padding from GetPlayerInfoByGUID results
-- @param str string - Potentially padded string
-- @return string - Clean string
function LoothingPlayerCacheMixin:StripNullBytes(str)
    if not str then return str end
    local found = str:find("\000")
    if found then
        return str:sub(1, found - 1)
    end
    return str
end

--- Split "Name-Realm" into components
-- @param fullName string - "Name-Realm" or just "Name"
-- @return string, string|nil - name, realm
function LoothingPlayerCacheMixin:SplitNameRealm(fullName)
    if not fullName or LoolibSecretUtil.IsSecretValue(fullName) then
        return nil, nil
    end
    local name, realm = fullName:match("^(.+)-(.+)$")
    if not name then
        return fullName, nil
    end
    return name, realm
end

--[[--------------------------------------------------------------------
    Player Convenience Methods
----------------------------------------------------------------------]]

--- Get a player's class-colored name
-- @param nameOrGUID string - GUID or "Name-Realm"
-- @return string - Colored name or plain name
function LoothingPlayerCacheMixin:GetClassColoredName(nameOrGUID)
    local player = self:Get(nameOrGUID)
    if not player or not player.name then
        return nameOrGUID or "Unknown"
    end

    if player.class then
        local colors = RAID_CLASS_COLORS and RAID_CLASS_COLORS[player.class]
            or LOOTHING_CLASS_COLORS and LOOTHING_CLASS_COLORS[player.class]
        if colors then
            local hex = string.format("%02x%02x%02x",
                (colors.r or 1) * 255,
                (colors.g or 1) * 255,
                (colors.b or 1) * 255)
            return "|cff" .. hex .. player.name .. "|r"
        end
    end

    return player.name
end

--- Get all enchanters from the cache
-- Scans the GUID-keyed cache for players with the enchanter flag set.
-- @return table - Array of { name, class, guid } for each enchanter
function LoothingPlayerCacheMixin:GetEnchanters()
    local enchanters = {}
    for guid, player in pairs(self.byGUID) do
        if player.enchanter and self:IsValid(player) then
            enchanters[#enchanters + 1] = {
                name = player.name or "Unknown",
                class = player.class,
                guid = guid,
            }
        end
    end
    return enchanters
end

--- Get short name (without realm if same realm)
-- @param nameOrGUID string - GUID or "Name-Realm"
-- @return string - Short name
function LoothingPlayerCacheMixin:GetShortName(nameOrGUID)
    local player = self:Get(nameOrGUID)
    if not player or not player.name then
        return nameOrGUID or "Unknown"
    end

    -- Strip realm if same as player's realm
    local myRealm = GetNormalizedRealmName() or GetRealmName()
    if player.realm and player.realm == myRealm then
        return player.name
    end

    if player.realm then
        return player.name .. "-" .. player.realm
    end

    return player.name
end

--[[--------------------------------------------------------------------
    Persistence (SavedVariables global scope)
----------------------------------------------------------------------]]

--- Load cache from SavedVariables global scope
function LoothingPlayerCacheMixin:LoadFromSavedVariables()
    if not Loothing or not Loothing.Settings then
        return
    end

    local stored = Loothing.Settings:GetGlobalValue("playerCache", {})
    if not stored or type(stored) ~= "table" then
        return
    end

    local loaded = 0
    local expired = 0

    for guid, playerData in pairs(stored) do
        if type(playerData) == "table" and playerData.name then
            -- Create player entry
            local player = {
                guid = guid,
                name = playerData.name,
                realm = playerData.realm,
                class = playerData.class,
                role = playerData.role,
                rank = playerData.rank,
                enchanter = playerData.enchanter,
                ilvl = playerData.ilvl,
                specID = playerData.specID,
                isInGuild = playerData.isInGuild,
                isCouncil = playerData.isCouncil,
                cacheTime = playerData.cacheTime or 0,
            }

            -- Check expiry
            if self:IsValid(player) then
                self.byGUID[guid] = player

                if player.name and player.realm then
                    self.byName[player.name .. "-" .. player.realm] = guid
                end
                -- Only store short name if no collision
                if player.name then
                    local existingShort = self.byName[player.name]
                    if not existingShort or existingShort == guid then
                        self.byName[player.name] = guid
                    end
                end

                loaded = loaded + 1
            else
                expired = expired + 1
            end
        end
    end

    Loothing:Debug("PlayerCache loaded:", loaded, "valid,", expired, "expired")
end

--- Mark cache as dirty and schedule a batched save (2s delay)
-- Prevents excessive SavedVariables writes during rapid updates.
function LoothingPlayerCacheMixin:MarkDirty()
    if self.savePending then return end
    self.savePending = true
    C_Timer.After(2, function()
        self.savePending = false
        self:SaveToSavedVariables()
    end)
end

--- Save cache to SavedVariables global scope
-- Note: Only entries with a GUID are persisted. Entries created with nil GUID
-- (via name-only GetOrCreate) are session-only and will not survive reload.
function LoothingPlayerCacheMixin:SaveToSavedVariables()
    if not Loothing or not Loothing.Settings then
        return
    end

    local toStore = {}

    for guid, player in pairs(self.byGUID) do
        if self:IsValid(player) then
            toStore[guid] = {
                name = player.name,
                realm = player.realm,
                class = player.class,
                role = player.role,
                rank = player.rank,
                enchanter = player.enchanter,
                ilvl = player.ilvl,
                specID = player.specID,
                isInGuild = player.isInGuild,
                isCouncil = player.isCouncil,
                cacheTime = player.cacheTime,
            }
        end
    end

    Loothing.Settings:SetGlobalValue("playerCache", toStore)
end

--[[--------------------------------------------------------------------
    Factory
----------------------------------------------------------------------]]

--- Create a new player cache instance
-- @return table - PlayerCache instance
function CreateLoothingPlayerCache()
    local cache = LoolibCreateFromMixins(LoothingPlayerCacheMixin)
    cache:Init()
    return cache
end
