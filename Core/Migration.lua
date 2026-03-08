--[[--------------------------------------------------------------------
    Loothing - Loot Council Addon for WoW 12.0+
    Migration - Version-stamped database schema migrations

    Manages database migrations across addon versions. Each migration
    is registered with a version number, runs exactly once, and is
    tracked in the global scope of SavedVariables (persists across
    profiles).

    Key properties:
    - Version-stamped: Each migration has a semantic version string
    - Idempotent: Safe to re-run (checks before modifying)
    - Ordered: Migrations run in version order (oldest to newest)
    - Tracked: Completed versions stored in global scope
    - Logged: Each execution is logged via Loothing:Debug()

    Usage:
        LoothingMigration:Init()              -- Register all migrations
        LoothingMigration:RunOnLoad()         -- Execute pending migrations
        LoothingMigration:HasRun("1.0.0")     -- Check if migration ran
----------------------------------------------------------------------]]

LoothingMigration = {}

-- Private state
local migrations = {}

--[[--------------------------------------------------------------------
    Core Functions
----------------------------------------------------------------------]]

--- Initialize the migration system
function LoothingMigration:Init()
    -- Clear any stale migrations from previous sessions
    migrations = {}

    -- Register all migrations
    self:RegisterMigrations()

    Loothing:Debug("Migration system initialized with", #migrations, "registered migrations")
end

--- Register a migration for a specific version
-- @param version string - Semantic version (e.g., "1.0.0")
-- @param description string - Human-readable description
-- @param func function - Migration handler: function(profileDB, globalDB)
function LoothingMigration:Register(version, description, func)
    if not version or not func then
        Loothing:Error("Migration:Register - version and func are required")
        return
    end

    -- Validate version format (X.Y.Z)
    if not version:match("^%d+%.%d+%.%d+$") then
        Loothing:Error("Migration:Register - Invalid version format:", version)
        return
    end

    table.insert(migrations, {
        version = version,
        description = description or "",
        func = func,
    })

    Loothing:Debug("Registered migration:", version, "-", description)
end

--- Register all migration functions
-- Each migration is registered with a version, description, and handler
function LoothingMigration:RegisterMigrations()
    -- Migration 1.0.0: Initial schema validation
    self:Register("1.0.0", "Initial schema setup", function(profileDB, globalDB)
        -- Ensure migration tracking exists in global scope
        if not globalDB.migrations then
            globalDB.migrations = {
                version = LOOTHING_VERSION,
                history = {},
                lastRun = nil,
            }
        end

        -- Ensure global data tables exist
        if not globalDB.history then
            globalDB.history = {}
        end
        if not globalDB.tradeQueue then
            globalDB.tradeQueue = {}
        end
        if not globalDB.itemStorage then
            globalDB.itemStorage = {}
        end
        if not globalDB.playerCache then
            globalDB.playerCache = {}
        end

        Loothing:Debug("Migration 1.0.0: Initial schema validated")
    end)

    -- Migration 1.0.1: Add new settings fields
    self:Register("1.0.1", "Add new settings fields", function(profileDB, globalDB)
        -- Ensure new voting fields exist
        if profileDB.voting then
            if profileDB.voting.mlSeesVotes == nil then
                profileDB.voting.mlSeesVotes = false
            end
        end

        -- Ensure new settings fields exist
        if profileDB.settings then
            if profileDB.settings.appendRealmNames == nil then
                profileDB.settings.appendRealmNames = false
            end
            if profileDB.settings.printResponses == nil then
                profileDB.settings.printResponses = false
            end
            if profileDB.settings.autoGroupLootGuildOnly == nil then
                profileDB.settings.autoGroupLootGuildOnly = false
            end
        end

        -- Ensure new autoPass fields exist
        if profileDB.autoPass then
            if profileDB.autoPass.trinkets == nil then
                profileDB.autoPass.trinkets = false
            end
            if profileDB.autoPass.transmogSource == nil then
                profileDB.autoPass.transmogSource = false
            end
            if profileDB.autoPass.silent == nil then
                profileDB.autoPass.silent = false
            end
        end

        Loothing:Debug("Migration 1.0.1: Added new settings fields")
    end)

    -- Migration 1.1.0: Clean up invalid data
    self:Register("1.1.0", "Clean up invalid data", function(profileDB, globalDB)
        -- Remove deprecated settings fields
        if profileDB.settings then
            profileDB.settings.legacyField = nil
        end

        -- Clean up history entries with missing required fields
        if globalDB.history then
            local cleaned = 0
            for i = #globalDB.history, 1, -1 do
                local entry = globalDB.history[i]
                if not entry.itemLink or not entry.winner then
                    table.remove(globalDB.history, i)
                    cleaned = cleaned + 1
                end
            end

            if cleaned > 0 then
                Loothing:Debug("Migration 1.1.0: Cleaned", cleaned, "invalid history entries")
            end
        end

        Loothing:Debug("Migration 1.1.0: Cleanup complete")
    end)

    -- Migration 1.2.0: Protocol v1 → v2 transition
    self:Register("1.2.0", "Protocol v1 to v2 transition", function(profileDB, globalDB)
        -- Clear any cached v1 protocol data that may be stored
        -- V1 used colon-separated string format; v2 uses structured tables

        -- Clear stale sync state (v1 format may be incompatible)
        if globalDB.syncState then
            globalDB.syncState = nil
            Loothing:Debug("Migration 1.2.0: Cleared stale v1 sync state")
        end

        -- Clear any v1-format cached comms data
        if globalDB.pendingComms then
            globalDB.pendingComms = nil
            Loothing:Debug("Migration 1.2.0: Cleared v1 pending comms")
        end

        -- Clear player cache to force refresh with new format
        if globalDB.playerCache then
            local count = 0
            for _ in pairs(globalDB.playerCache) do
                count = count + 1
            end
            if count > 0 then
                globalDB.playerCache = {}
                Loothing:Debug("Migration 1.2.0: Cleared", count, "player cache entries (protocol change)")
            end
        end

        -- Ensure award reasons have new fields
        if profileDB.awardReasons and profileDB.awardReasons.reasons then
            for i, reason in ipairs(profileDB.awardReasons.reasons) do
                if reason.log == nil then
                    reason.log = true
                end
                if reason.disenchant == nil then
                    reason.disenchant = false
                end
                if reason.sort == nil then
                    reason.sort = i
                end
            end
        end

        Loothing:Debug("Migration 1.2.0: Protocol v1→v2 transition complete")
    end)
end

--[[--------------------------------------------------------------------
    Migration Execution
----------------------------------------------------------------------]]

--- Run all pending migrations on addon load
-- Called from Init.lua after ADDON_LOADED event.
-- Uses the global scope for migration tracking so it persists across profiles.
function LoothingMigration:RunOnLoad()
    -- Get data scopes
    local profileDB, globalDB = self:GetDataScopes()
    if not profileDB and not globalDB then
        Loothing:Error("Migration:RunOnLoad - No database available")
        return
    end

    -- Initialize migration tracking in global scope
    if not globalDB.migrations then
        globalDB.migrations = {
            version = "0.0.0",
            history = {},
            lastRun = nil,
        }
    end

    local oldVersion = globalDB.migrations.version or "0.0.0"
    local currentVersion = LOOTHING_VERSION

    Loothing:Debug("Running migrations from", oldVersion, "to", currentVersion)

    -- Sort migrations by version
    table.sort(migrations, function(a, b)
        return self:CompareVersions(a.version, b.version) < 0
    end)

    local executed = 0
    local completedVersions = self:GetCompletedVersions()

    -- Execute each pending migration
    for _, migration in ipairs(migrations) do
        -- Skip if already completed
        if completedVersions[migration.version] then
            Loothing:Debug("Skipping migration:", migration.version, "(already executed)")
        else
            Loothing:Debug("Executing migration:", migration.version, "-", migration.description)

            -- Execute in a protected call
            local success, err = pcall(migration.func, profileDB, globalDB)

            if success then
                executed = executed + 1

                -- Record completion in global scope
                if not globalDB.migrations.history then
                    globalDB.migrations.history = {}
                end
                table.insert(globalDB.migrations.history, {
                    version = migration.version,
                    description = migration.description,
                    timestamp = date("%Y-%m-%d %H:%M:%S"),
                })

                Loothing:Debug("Migration", migration.version, "completed successfully")
            else
                Loothing:Error("Migration", migration.version, "failed:", err)
            end
        end
    end

    -- Update stored version
    globalDB.migrations.version = currentVersion
    globalDB.migrations.lastRun = date("%Y-%m-%d %H:%M:%S")

    if executed > 0 then
        Loothing:Debug("Executed", executed, "migrations")
    else
        Loothing:Debug("No migrations needed")
    end
end

--- Alias for RunOnLoad (public API name)
function LoothingMigration:RunPending()
    self:RunOnLoad()
end

--[[--------------------------------------------------------------------
    Data Scope Access
----------------------------------------------------------------------]]

--- Get profile and global data scopes
-- @return table, table - profileDB, globalDB
function LoothingMigration:GetDataScopes()
    local profileDB, globalDB

    -- Try Loolib SavedVariables first
    if Loothing and Loothing.Settings then
        local sv = Loothing.Settings:GetDB()
        if sv then
            profileDB = Loothing.Settings.db
            globalDB = Loothing.Settings.global
        end
    end

    -- Fallback to direct LoothingDB access (pre-migration or first load)
    if not profileDB then
        if LoothingDB then
            profileDB = LoothingDB
        else
            profileDB = {}
        end
    end

    if not globalDB then
        -- On first load, global data may still be in the flat LoothingDB
        if LoothingDB and LoothingDB.global then
            globalDB = LoothingDB.global
        elseif LoothingDB then
            globalDB = LoothingDB
        else
            globalDB = {}
        end
    end

    return profileDB, globalDB
end

--[[--------------------------------------------------------------------
    Query API
----------------------------------------------------------------------]]

--- Get all completed migration versions
-- @return table - Set of version strings that have been completed (version -> true)
function LoothingMigration:GetCompletedVersions()
    local _, globalDB = self:GetDataScopes()
    local completed = {}

    if globalDB and globalDB.migrations and globalDB.migrations.history then
        for _, entry in ipairs(globalDB.migrations.history) do
            local version = type(entry) == "table" and entry.version or entry
            if version then
                completed[version] = true
            end
        end
    end

    return completed
end

--- Check if a specific migration has been executed
-- @param version string - Migration version to check
-- @return boolean - True if migration has been executed
function LoothingMigration:HasRun(version)
    local completed = self:GetCompletedVersions()
    return completed[version] == true
end

--- Get the current stored migration version
-- @return string - Version string
function LoothingMigration:GetCurrentVersion()
    local _, globalDB = self:GetDataScopes()

    if globalDB and globalDB.migrations then
        return globalDB.migrations.version or "0.0.0"
    end

    return "0.0.0"
end

--- Get migration history (array of completed migration records)
-- @return table - Array of { version, description, timestamp }
function LoothingMigration:GetHistory()
    local _, globalDB = self:GetDataScopes()

    if globalDB and globalDB.migrations and globalDB.migrations.history then
        return globalDB.migrations.history
    end

    return {}
end

--- Check if a specific migration has been executed (alias)
-- @param version string - Migration version to check
-- @return boolean
function LoothingMigration:HasMigrationRun(version)
    return self:HasRun(version)
end

--[[--------------------------------------------------------------------
    Version Comparison
----------------------------------------------------------------------]]

--- Compare two semantic version strings
-- Returns -1 if v1 < v2, 0 if equal, 1 if v1 > v2
-- @param v1 string - First version (e.g., "1.2.3")
-- @param v2 string - Second version (e.g., "1.2.4")
-- @return number
function LoothingMigration:CompareVersions(v1, v2)
    return LoothingUtils.CompareVersions(v1, v2)
end

--[[--------------------------------------------------------------------
    Debug Utilities
----------------------------------------------------------------------]]

--- Force re-run all migrations (DANGEROUS - for debugging only)
function LoothingMigration:ForceRerunAll()
    Loothing:Debug("WARNING: Force re-running all migrations")

    local _, globalDB = self:GetDataScopes()

    if globalDB and globalDB.migrations then
        globalDB.migrations.version = "0.0.0"
        globalDB.migrations.history = {}
    end

    self:RunOnLoad()
end
