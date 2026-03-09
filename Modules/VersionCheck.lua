--[[--------------------------------------------------------------------
    Loothing - Loot Council Addon for WoW 12.0+
    VersionCheck - Version comparison, gating, and management

    Stores version info in db.global.verTestCandidates (persisted).
    Provides GroupHasVersion() to gate features behind minimum versions.
    Warns about outdated group members on join.
    Supports test versions (tVersion) that don't trigger outdated warnings.
----------------------------------------------------------------------]]

local ADDON_NAME, ns = ...
local Loolib = LibStub("Loolib")
local Loothing = ns.Addon
local Utils = ns.Utils
local C_Timer = C_Timer
local GetNumGroupMembers = GetNumGroupMembers
local GetNumGuildMembers = GetNumGuildMembers
local GetTime = GetTime
local IsInGroup = IsInGroup
local IsInGuild = IsInGuild
local IsInRaid = IsInRaid
local UnitExists = UnitExists
local ipairs, pairs, time, type = ipairs, pairs, time, type
local tconcat = table.concat
local tsort = table.sort

--[[--------------------------------------------------------------------
    VersionCheckMixin
----------------------------------------------------------------------]]

local VersionCheckMixin = Loolib.CreateFromMixins(Loolib.CallbackRegistryMixin)

local VERSION_EVENTS = {
    "OnVersionReceived",
    "OnQueryComplete",
    "OnOutdatedWarning",
}

-- Throttle: minimum 30s between group roster version checks
local ROSTER_CHECK_THROTTLE = 30
-- Throttle: minimum 60s between outdated warnings
local OUTDATED_WARN_THROTTLE = 60

--- Initialize version check
function VersionCheckMixin:Init()
    Loolib.CallbackRegistryMixin.OnLoad(self)
    self:GenerateCallbackEvents(VERSION_EVENTS)

    self.versionCache = {}  -- { playerName = { version, tVersion, timestamp, isOutdated } }
    self.queryInProgress = false
    self.queryStartTime = nil
    self.lastRosterCheck = 0
    self.lastOutdatedWarn = 0

    -- Test version (set to a string like "alpha1" for pre-release builds, nil for release)
    self.tVersion = nil

    -- Load persisted version data from global SavedVariables
    self:LoadPersistedVersions()
end

--[[--------------------------------------------------------------------
    Persisted Version Storage
----------------------------------------------------------------------]]

--- Load version data from SavedVariables global scope
function VersionCheckMixin:LoadPersistedVersions()
    if not Loothing.Settings then return end

    local stored = Loothing.Settings:GetGlobalValue("verTestCandidates", {})
    if type(stored) == "table" then
        -- Merge stored data into cache (don't overwrite fresh data)
        for name, data in pairs(stored) do
            if not self.versionCache[name] then
                self.versionCache[name] = data
            end
        end
    end
end

--- Save version data to SavedVariables global scope
function VersionCheckMixin:SavePersistedVersions()
    if not Loothing.Settings then return end

    -- Only persist entries with actual versions (not nil/"Not Installed")
    local toSave = {}
    local now = time()  -- Use real clock to match stored timestamps
    for name, data in pairs(self.versionCache) do
        if data.version and data.version ~= "Not Installed" then
            -- Only persist entries less than 7 days old
            if data.timestamp and (now - data.timestamp) < (7 * 24 * 60 * 60) then
                toSave[name] = {
                    version = data.version,
                    tVersion = data.tVersion,
                    timestamp = data.timestamp,
                    isOutdated = data.isOutdated,
                }
            end
        end
    end

    Loothing.Settings:SetGlobalValue("verTestCandidates", toSave)
end

--[[--------------------------------------------------------------------
    Version Comparison
----------------------------------------------------------------------]]

--- Compare two version strings (semantic versioning)
-- @param v1 string - Version string (e.g., "1.0.0")
-- @param v2 string - Version string to compare against
-- @return number - -1 if v1 < v2, 0 if equal, 1 if v1 > v2
function VersionCheckMixin:CompareVersions(v1, v2)
    return Utils.CompareVersions(v1, v2)
end

--- Check if a version is outdated compared to current
-- @param version string
-- @return boolean
function VersionCheckMixin:IsOutdated(version)
    return self:CompareVersions(version, Loothing.VERSION) < 0
end

--- Get highest version from cache
-- @return string
function VersionCheckMixin:GetHighestVersion()
    local highest = Loothing.VERSION

    for _, data in pairs(self.versionCache) do
        if data.version and self:CompareVersions(data.version, highest) > 0 then
            highest = data.version
        end
    end

    return highest
end

--[[--------------------------------------------------------------------
    Version Gating
----------------------------------------------------------------------]]

--- Check if all group members (with Loothing installed) meet a minimum version
-- @param minVersion string - Minimum version required (e.g., "1.1.0")
-- @return boolean - True if all group members meet the minimum version
function VersionCheckMixin:GroupHasVersion(minVersion)
    if not minVersion then return true end

    -- Our own version must meet the minimum
    if self:CompareVersions(Loothing.VERSION, minVersion) < 0 then
        return false
    end

    -- Check all cached group members
    if not IsInGroup() then return true end

    local numMembers = GetNumGroupMembers()
    for i = 1, numMembers do
        local name
        if IsInRaid() then
            name = Loolib.SecretUtil.SafeGetRaidRosterInfo(i)
        else
            local unit = (i == numMembers) and "player" or ("party" .. i)
            if UnitExists(unit) then
                name = Loolib.SecretUtil.SafeUnitName(unit)
            end
        end

        if name then
            name = Utils.NormalizeName(name)
            local data = self.versionCache[name]
            if data and data.version and data.version ~= "Not Installed" then
                -- Test versions are not gated (they're always considered up-to-date)
                if not data.tVersion then
                    if self:CompareVersions(data.version, minVersion) < 0 then
                        return false
                    end
                end
            end
            -- Players without version data are not gated (may not have addon)
        end
    end

    return true
end

--- Get list of group members below a minimum version
-- @param minVersion string - Minimum version required
-- @return table - Array of { name, version } for outdated members
function VersionCheckMixin:GetOutdatedMembers(minVersion)
    local outdated = {}

    if not IsInGroup() then return outdated end

    local numMembers = GetNumGroupMembers()
    for i = 1, numMembers do
        local name
        if IsInRaid() then
            name = Loolib.SecretUtil.SafeGetRaidRosterInfo(i)
        else
            local unit = (i == numMembers) and "player" or ("party" .. i)
            if UnitExists(unit) then
                local rawName = Loolib.SecretUtil.SafeUnitName(unit)
                name = rawName
            end
        end

        if name then
            name = Utils.NormalizeName(name)
            local data = self.versionCache[name]
            if data and data.version and data.version ~= "Not Installed" then
                if not data.tVersion and self:CompareVersions(data.version, minVersion) < 0 then
                    outdated[#outdated + 1] = {
                        name = name,
                        version = data.version,
                    }
                end
            end
        end
    end

    return outdated
end

--- Get a set of current group member names (normalized)
-- @return table - { [name] = true }
function VersionCheckMixin:GetCurrentRosterNames()
    local names = {}
    if not IsInGroup() then
        local pName = Loolib.SecretUtil.SafeUnitName("player")
        if pName then
            names[Utils.NormalizeName(pName)] = true
        end
        return names
    end
    local roster = Utils.GetRaidRoster()
    for _, member in ipairs(roster) do
        names[member.name] = true
    end
    return names
end

--[[--------------------------------------------------------------------
    Group Roster Version Check (automatic)
----------------------------------------------------------------------]]

--- Called on GROUP_ROSTER_UPDATE - throttled version request
function VersionCheckMixin:OnGroupRosterUpdate()
    if not IsInGroup() then return end

    local now = GetTime()
    if (now - self.lastRosterCheck) < ROSTER_CHECK_THROTTLE then
        return
    end
    self.lastRosterCheck = now

    -- Send version request to group (non-blocking, just fires and forgets)
    if Loothing.Comm then
        Loothing.Comm:SendVersionRequest()
    end

    -- Check for outdated members and warn (throttled)
    if (now - self.lastOutdatedWarn) >= OUTDATED_WARN_THROTTLE then
        self:WarnOutdatedMembers()
        self.lastOutdatedWarn = now
    end
end

--- Print a warning about outdated group members
function VersionCheckMixin:WarnOutdatedMembers()
    local rosterNames = self:GetCurrentRosterNames()
    local outdatedCount = 0
    local outdatedNames = {}

    for name, data in pairs(self.versionCache) do
        if rosterNames[name] and data.version and data.version ~= "Not Installed" and not data.tVersion then
            if self:IsOutdated(data.version) then
                outdatedCount = outdatedCount + 1
                if outdatedCount <= 3 then
                    local shortName = Utils.GetShortName(name)
                    outdatedNames[#outdatedNames + 1] = string.format("%s (%s)", shortName, data.version)
                end
            end
        end
    end

    if outdatedCount > 0 then
        local msg = string.format("|cffff9900%d group member(s) have outdated Loothing:|r %s",
            outdatedCount,
            tconcat(outdatedNames, ", "))
        if outdatedCount > 3 then
            msg = msg .. string.format(" and %d more", outdatedCount - 3)
        end
        Loothing:Print(msg)
        self:TriggerEvent("OnOutdatedWarning", outdatedCount)
    end
end

--[[--------------------------------------------------------------------
    Version Queries
----------------------------------------------------------------------]]

--- Query versions from guild or raid
-- @param target string - "guild" or "raid"
function VersionCheckMixin:Query(target)
    if self.queryInProgress then
        Loothing:Print("Version check already in progress")
        return
    end

    -- Prune cache: remove entries not in current roster
    local rosterNames = self:GetCurrentRosterNames()
    for name in pairs(self.versionCache) do
        if not rosterNames[name] then
            self.versionCache[name] = nil
        end
    end

    -- Reset version for roster members so they must re-respond
    for name, entry in pairs(self.versionCache) do
        entry.version = nil
        entry.tVersion = nil
        entry.isOutdated = false
    end
    self.queryInProgress = true
    self.queryStartTime = GetTime()

    -- Add self to cache (include tVersion if set)
    self:AddVersionEntry(Loolib.SecretUtil.SafeUnitName("player"), Loothing.VERSION, self.tVersion)

    -- Send request
    if target == "guild" then
        self:QueryGuild()
    elseif target == "raid" then
        self:QueryRaid()
    end

    -- Schedule completion
    C_Timer.After(5, function()
        self:CompleteQuery()
    end)
end

--- Query guild members
function VersionCheckMixin:QueryGuild()
    if not IsInGuild() then
        Loothing:Print("You are not in a guild")
        self:CompleteQuery()
        return
    end

    -- Pre-populate with online guild members
    local numMembers = GetNumGuildMembers()
    for i = 1, numMembers do
        local name, _, _, _, _, _, _, _, online = Loothing.GetGuildRosterInfo(i)
        if online and name then
            name = Utils.NormalizeName(name)
            self.versionCache[name] = {
                version = nil,
                tVersion = nil,
                timestamp = time(),
                isOutdated = false,
            }
        end
    end

    -- Send request via GUILD channel
    Loothing.Comm:SendVersionRequest("guild")
end

--- Query raid members
function VersionCheckMixin:QueryRaid()
    if not IsInRaid() and not IsInGroup() then
        Loothing:Print("You are not in a raid or party")
        self:CompleteQuery()
        return
    end

    -- Pre-populate with group members
    local roster = Utils.GetRaidRoster()
    for _, member in ipairs(roster) do
        if member.online and member.name then
            self.versionCache[member.name] = {
                version = nil,
                tVersion = nil,
                timestamp = time(),
                isOutdated = false,
            }
        end
    end

    -- Send request via RAID channel
    Loothing.Comm:SendVersionRequest()
end

--- Complete the query
function VersionCheckMixin:CompleteQuery()
    if not self.queryInProgress then return end

    self.queryInProgress = false
    self:TriggerEvent("OnQueryComplete", self.versionCache)

    -- Mark unknown versions as "Not Installed"
    for name, data in pairs(self.versionCache) do
        if not data.version then
            data.version = "Not Installed"
            data.isOutdated = true
        end
    end

    -- Persist updated version data
    self:SavePersistedVersions()
end

--[[--------------------------------------------------------------------
    Version Responses
----------------------------------------------------------------------]]

--- Handle version request from another player
-- @param sender string
function VersionCheckMixin:HandleRequest(sender)
    -- Send our version via Comm convenience method
    Loothing.Comm:SendVersionResponse(sender)
end

--- Handle version response from another player
-- @param version string
-- @param sender string
-- @param tVersion string|nil - Test version identifier
function VersionCheckMixin:HandleResponse(version, sender, tVersion)
    sender = Utils.NormalizeName(sender)
    self:AddVersionEntry(sender, version, tVersion)

    self:TriggerEvent("OnVersionReceived", sender, version)

    -- Persist on each response
    self:SavePersistedVersions()
end

--- Add a version entry to cache
-- @param name string
-- @param version string
-- @param tVersion string|nil - Test version identifier
function VersionCheckMixin:AddVersionEntry(name, version, tVersion)
    name = Utils.NormalizeName(name)

    self.versionCache[name] = {
        version = version,
        tVersion = tVersion,
        timestamp = time(),  -- Use real clock for cross-session persistence
        -- Test versions are never considered outdated for warning purposes
        isOutdated = tVersion and false or self:IsOutdated(version),
    }
end

--[[--------------------------------------------------------------------
    Display Helpers
----------------------------------------------------------------------]]

--- Get version data sorted by name, scoped to current roster
-- @return table - Array of { name, version, tVersion, isOutdated }
function VersionCheckMixin:GetSortedVersions()
    local rosterNames = self:GetCurrentRosterNames()
    local versions = {}

    for name, data in pairs(self.versionCache) do
        if rosterNames[name] then
            versions[#versions + 1] = {
                name = name,
                version = data.version or "Unknown",
                tVersion = data.tVersion,
                isOutdated = data.isOutdated,
            }
        end
    end

    tsort(versions, function(a, b)
        return a.name < b.name
    end)

    return versions
end

--- Get count of outdated versions, scoped to current roster
-- @return number
function VersionCheckMixin:GetOutdatedCount()
    local rosterNames = self:GetCurrentRosterNames()
    local count = 0

    for name, data in pairs(self.versionCache) do
        if rosterNames[name] and data.isOutdated and data.version ~= "Not Installed" and not data.tVersion then
            count = count + 1
        end
    end

    return count
end

--- Get count of not installed, scoped to current roster
-- @return number
function VersionCheckMixin:GetNotInstalledCount()
    local rosterNames = self:GetCurrentRosterNames()
    local count = 0

    for name, data in pairs(self.versionCache) do
        if rosterNames[name] and data.version == "Not Installed" then
            count = count + 1
        end
    end

    return count
end

--- Print summary to chat, scoped to current roster
function VersionCheckMixin:PrintSummary()
    local rosterNames = self:GetCurrentRosterNames()
    local total = 0
    local current = 0
    local outdated = 0
    local notInstalled = 0
    local testVersions = 0

    for name, data in pairs(self.versionCache) do
        if rosterNames[name] then
            total = total + 1

            if data.version == "Not Installed" then
                notInstalled = notInstalled + 1
            elseif data.tVersion then
                testVersions = testVersions + 1
            elseif data.isOutdated then
                outdated = outdated + 1
            else
                current = current + 1
            end
        end
    end

    Loothing:Print(string.format("Version Check Results: %d total", total))
    Loothing:Print(string.format("  Up to date: %d", current))

    if testVersions > 0 then
        Loothing:Print(string.format("  |cff00ff00Test versions: %d|r", testVersions))
    end

    if outdated > 0 then
        Loothing:Print(string.format("  |cffff0000Outdated: %d|r", outdated))
    end

    if notInstalled > 0 then
        Loothing:Print(string.format("  |cff888888Not Installed: %d|r", notInstalled))
    end

    Loothing:Print("Use /lt version show to see detailed results")
end

--[[--------------------------------------------------------------------
    Namespace Instance
----------------------------------------------------------------------]]

local VersionCheck = ns.VersionCheck or Loolib.CreateFromMixins(VersionCheckMixin)
ns.VersionCheck = VersionCheck
-- Defer Init() - LoadPersistedVersions() requires Loothing.Settings which is
-- not available until InitializeModules() has run. The PLAYER_LOGIN handler
-- in Init.lua calls ns.VersionCheck:Init() after Settings is ready.
-- Only set up the callback registry and basic state here.
Loolib.CallbackRegistryMixin.OnLoad(VersionCheck)
VersionCheck:GenerateCallbackEvents(VERSION_EVENTS)
VersionCheck.versionCache = {}
VersionCheck.queryInProgress = false
VersionCheck.queryStartTime = nil
VersionCheck.lastRosterCheck = 0
VersionCheck.lastOutdatedWarn = 0
VersionCheck.tVersion = nil
