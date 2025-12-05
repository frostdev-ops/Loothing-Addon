--[[--------------------------------------------------------------------
    Loothing - Loot Council Addon for WoW 12.0+
    VersionCheck - Version comparison and management
----------------------------------------------------------------------]]

local Loolib = LibStub("Loolib")

--[[--------------------------------------------------------------------
    LoothingVersionCheckMixin
----------------------------------------------------------------------]]

LoothingVersionCheckMixin = LoolibCreateFromMixins(LoolibCallbackRegistryMixin)

local VERSION_EVENTS = {
    "OnVersionReceived",
    "OnQueryComplete",
}

--- Initialize version check
function LoothingVersionCheckMixin:Init()
    LoolibCallbackRegistryMixin.OnLoad(self)
    self:GenerateCallbackEvents(VERSION_EVENTS)

    self.versionCache = {}  -- { playerName = { version, timestamp, isOutdated } }
    self.queryInProgress = false
    self.queryStartTime = nil
end

--[[--------------------------------------------------------------------
    Version Comparison
----------------------------------------------------------------------]]

--- Compare two version strings (semantic versioning)
-- @param v1 string - Version string (e.g., "1.0.0")
-- @param v2 string - Version string to compare against
-- @return number - -1 if v1 < v2, 0 if equal, 1 if v1 > v2
function LoothingVersionCheckMixin:CompareVersions(v1, v2)
    if not v1 or not v2 then return 0 end

    local major1, minor1, patch1 = v1:match("(%d+)%.(%d+)%.(%d+)")
    local major2, minor2, patch2 = v2:match("(%d+)%.(%d+)%.(%d+)")

    major1, minor1, patch1 = tonumber(major1) or 0, tonumber(minor1) or 0, tonumber(patch1) or 0
    major2, minor2, patch2 = tonumber(major2) or 0, tonumber(minor2) or 0, tonumber(patch2) or 0

    if major1 > major2 then return 1 end
    if major1 < major2 then return -1 end

    if minor1 > minor2 then return 1 end
    if minor1 < minor2 then return -1 end

    if patch1 > patch2 then return 1 end
    if patch1 < patch2 then return -1 end

    return 0
end

--- Check if a version is outdated compared to current
-- @param version string
-- @return boolean
function LoothingVersionCheckMixin:IsOutdated(version)
    return self:CompareVersions(version, LOOTHING_VERSION) < 0
end

--- Get highest version from cache
-- @return string
function LoothingVersionCheckMixin:GetHighestVersion()
    local highest = LOOTHING_VERSION

    for _, data in pairs(self.versionCache) do
        if self:CompareVersions(data.version, highest) > 0 then
            highest = data.version
        end
    end

    return highest
end

--[[--------------------------------------------------------------------
    Version Queries
----------------------------------------------------------------------]]

--- Query versions from guild or raid
-- @param target string - "guild" or "raid"
function LoothingVersionCheckMixin:Query(target)
    if self.queryInProgress then
        Loothing:Print("Version check already in progress")
        return
    end

    -- Clear old cache
    wipe(self.versionCache)
    self.queryInProgress = true
    self.queryStartTime = GetTime()

    -- Add self to cache
    self:AddVersionEntry(UnitName("player"), LOOTHING_VERSION)

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
function LoothingVersionCheckMixin:QueryGuild()
    if not IsInGuild() then
        Loothing:Print("You are not in a guild")
        self:CompleteQuery()
        return
    end

    -- Pre-populate with online guild members
    local numMembers = GetNumGuildMembers()
    for i = 1, numMembers do
        local name, _, _, _, _, _, _, _, online = GetGuildRosterInfo(i)
        if online and name then
            name = LoothingUtils.NormalizeName(name)
            if not self.versionCache[name] then
                self.versionCache[name] = {
                    version = nil,
                    timestamp = GetTime(),
                    isOutdated = false,
                }
            end
        end
    end

    -- Send request via GUILD channel
    local msg = self:CreateVersionRequest()
    Loothing.Comm:SendGuild(msg)
end

--- Query raid members
function LoothingVersionCheckMixin:QueryRaid()
    if not IsInRaid() and not IsInGroup() then
        Loothing:Print("You are not in a raid or party")
        self:CompleteQuery()
        return
    end

    -- Pre-populate with raid members
    local numMembers = GetNumGroupMembers()
    for i = 1, numMembers do
        local name, _, _, _, _, _, _, online = GetRaidRosterInfo(i)
        if online and name then
            name = LoothingUtils.NormalizeName(name)
            if not self.versionCache[name] then
                self.versionCache[name] = {
                    version = nil,
                    timestamp = GetTime(),
                    isOutdated = false,
                }
            end
        end
    end

    -- Send request via RAID channel
    local msg = self:CreateVersionRequest()
    Loothing.Comm:Send(msg)
end

--- Create version request message
-- @return string
function LoothingVersionCheckMixin:CreateVersionRequest()
    return LoothingProtocol:Encode(LOOTHING_MSG_TYPE.VERSION_REQUEST, {})
end

--- Complete the query
function LoothingVersionCheckMixin:CompleteQuery()
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
end

--[[--------------------------------------------------------------------
    Version Responses
----------------------------------------------------------------------]]

--- Handle version request from another player
-- @param sender string
function LoothingVersionCheckMixin:HandleRequest(sender)
    -- Send our version
    local msg = self:CreateVersionResponse()

    if Loothing.Comm.SendToPlayer then
        Loothing.Comm:SendToPlayer(msg, sender)
    else
        -- Fallback: send to same channel it came from
        Loothing.Comm:Send(msg)
    end
end

--- Handle version response from another player
-- @param version string
-- @param sender string
function LoothingVersionCheckMixin:HandleResponse(version, sender)
    sender = LoothingUtils.NormalizeName(sender)
    self:AddVersionEntry(sender, version)

    self:TriggerEvent("OnVersionReceived", sender, version)
end

--- Create version response message
-- @return string
function LoothingVersionCheckMixin:CreateVersionResponse()
    return LoothingProtocol:Encode(LOOTHING_MSG_TYPE.VERSION_RESPONSE, { LOOTHING_VERSION })
end

--- Add a version entry to cache
-- @param name string
-- @param version string
function LoothingVersionCheckMixin:AddVersionEntry(name, version)
    name = LoothingUtils.NormalizeName(name)

    self.versionCache[name] = {
        version = version,
        timestamp = GetTime(),
        isOutdated = self:IsOutdated(version),
    }
end

--[[--------------------------------------------------------------------
    Display Helpers
----------------------------------------------------------------------]]

--- Get version data sorted by name
-- @return table - Array of { name, version, isOutdated }
function LoothingVersionCheckMixin:GetSortedVersions()
    local versions = {}

    for name, data in pairs(self.versionCache) do
        versions[#versions + 1] = {
            name = name,
            version = data.version or "Unknown",
            isOutdated = data.isOutdated,
        }
    end

    table.sort(versions, function(a, b)
        return a.name < b.name
    end)

    return versions
end

--- Get count of outdated versions
-- @return number
function LoothingVersionCheckMixin:GetOutdatedCount()
    local count = 0

    for _, data in pairs(self.versionCache) do
        if data.isOutdated and data.version ~= "Not Installed" then
            count = count + 1
        end
    end

    return count
end

--- Get count of not installed
-- @return number
function LoothingVersionCheckMixin:GetNotInstalledCount()
    local count = 0

    for _, data in pairs(self.versionCache) do
        if data.version == "Not Installed" then
            count = count + 1
        end
    end

    return count
end

--- Print summary to chat
function LoothingVersionCheckMixin:PrintSummary()
    local total = 0
    local current = 0
    local outdated = 0
    local notInstalled = 0

    for _, data in pairs(self.versionCache) do
        total = total + 1

        if data.version == "Not Installed" then
            notInstalled = notInstalled + 1
        elseif data.isOutdated then
            outdated = outdated + 1
        else
            current = current + 1
        end
    end

    Loothing:Print(string.format("Version Check Results: %d total", total))
    Loothing:Print(string.format("  Up to date: %d", current))

    if outdated > 0 then
        Loothing:Print(string.format("  |cffff0000Outdated: %d|r", outdated))
    end

    if notInstalled > 0 then
        Loothing:Print(string.format("  |cff888888Not Installed: %d|r", notInstalled))
    end

    Loothing:Print("Use /lt version show to see detailed results")
end

--[[--------------------------------------------------------------------
    Singleton Instance
----------------------------------------------------------------------]]

LoothingVersionCheck = LoolibCreateFromMixins(LoothingVersionCheckMixin)
LoothingVersionCheck:Init()
