--[[--------------------------------------------------------------------
    Loothing - Loot Council Addon for WoW 12.0+
    Migration - Version-stamped database schema migrations

    Manages database migrations across addon versions. Each migration
    is registered with a version number and a scope:

    - scope "global": runs exactly once per account, tracked in the
      global scope of SavedVariables.
    - scope "profile": runs exactly once per PROFILE, tracked inside
      that profile (profileDB.migrationsRun). Runs for the active
      profile on load and re-runs for any profile that becomes active
      later (profile switch, new alt) that hasn't had it yet. Global
      tracking for these caused the original bug: only the profile
      active at upgrade time ever migrated.

    Key properties:
    - Version-stamped: Each migration has a semantic version string
    - Idempotent: Safe to re-run (checks before modifying) — REQUIRED,
      since existing profiles that migrated under the old global
      tracking re-run their profile-scoped migrations once
    - Ordered: Migrations run in version order (oldest to newest)
    - Logged: Each execution is logged via Loothing:Debug()

    Usage:
        Migration:Init()              -- Register all migrations
        Migration:RunOnLoad()         -- Execute pending migrations
        Migration:HasRun("1.0.0")     -- Check if migration ran
----------------------------------------------------------------------]]
local _, ns = ...

local Loolib = LibStub("Loolib")
local Loothing = ns.Addon
local Utils = ns.Utils
ns.Migration = ns.Migration or {}
local Migration = ns.Migration

-- Private state
local migrations = {}

--[[--------------------------------------------------------------------
    Core Functions
----------------------------------------------------------------------]]

--- Initialize the migration system
function Migration:Init()
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
-- @param scope string|nil - "global" (default): once per account;
--        "profile": once per profile, tracked in the profile itself
function Migration:Register(version, description, func, scope)
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
        scope = scope == "profile" and "profile" or "global",
    })

    Loothing:Debug("Registered migration:", version, "-", description)
end

--- Register all migration functions
-- Each migration is registered with a version, description, and handler
function Migration:RegisterMigrations()
    -- Migration 1.0.0: Initial schema validation
    self:Register("1.0.0", "Initial schema setup", function(_profileDB, globalDB)
        -- Ensure migration tracking exists in global scope
        if not globalDB.migrations then
            globalDB.migrations = {
                version = Loothing.VERSION,
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
    end, "global")

    -- Migration 1.0.1: Add new settings fields
    self:Register("1.0.1", "Add new settings fields", function(profileDB, _globalDB)
        -- Ensure new voting fields exist
        if profileDB.voting then
            if profileDB.voting.mlSeesVotes == nil then
                profileDB.voting.mlSeesVotes = false
            end
        end

        -- v2.0.7: the `settings.*` namespace was deleted by SchemaMigration
        -- before this older version-string migration runs.  The
        -- autoGroupLootGuildOnly bootstrap below is now a no-op for any
        -- profile that survived SchemaMigration.  We keep the block for
        -- defensive purposes in case some legacy profile somehow still
        -- carries `settings`, and we mirror the canonical session.* key.
        if profileDB.settings then
            if profileDB.settings.autoGroupLootGuildOnly == nil then
                profileDB.settings.autoGroupLootGuildOnly = false
            end
        end
        if profileDB.session and profileDB.session.groupLootGuildOnly == nil then
            profileDB.session.groupLootGuildOnly = false
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
    end, "profile")

    -- Migration 1.1.0 (profile half): Remove deprecated profile settings
    self:Register("1.1.0", "Remove deprecated profile settings", function(profileDB, _globalDB)
        if profileDB.settings then
            profileDB.settings.legacyField = nil
        end
        Loothing:Debug("Migration 1.1.0: Removed deprecated profile settings")
    end, "profile")

    -- Migration 1.1.0 (global half): Clean up invalid history entries
    self:Register("1.1.0", "Clean up invalid data", function(_profileDB, globalDB)
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
    end, "global")

    -- Migration 1.2.0 (global half): Protocol v1 → v2 transition
    self:Register("1.2.0", "Protocol v1 to v2 transition", function(_profileDB, globalDB)
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

        Loothing:Debug("Migration 1.2.0: Protocol v1→v2 transition complete")
    end, "global")

    -- Migration 1.2.0 (profile half): Ensure award reasons have new fields
    self:Register("1.2.0", "Backfill award reason fields", function(profileDB, _globalDB)
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
        Loothing:Debug("Migration 1.2.0: Award reason fields backfilled")
    end, "profile")

    -- Migration 1.3.0: Merge responses + buttonSets -> responseSets
    self:Register("1.3.0", "Merge responses + buttonSets into responseSets", function(profileDB, _globalDB)
        -- Skip if already migrated
        if profileDB.responseSets and profileDB.responseSets.sets then
            Loothing:Debug("Migration 1.3.0: responseSets already present, skipping merge")
            return
        end

        local defaults = Loothing.DefaultSettings.responseSets
        local rs = {
            activeSet  = 1,
            sets       = {},
            typeCodeMap = {},
        }

        -- Migrate buttonSets -> responseSets
        local oldSets = profileDB.buttonSets and profileDB.buttonSets.sets
        local oldResponses = profileDB.responses  -- keyed by numeric Loothing.Response id

        if oldSets then
            rs.activeSet = profileDB.buttonSets.activeSet or 1

            for setId, oldSet in pairs(oldSets) do
                local newButtons = {}
                for _, btn in ipairs(oldSet.buttons or {}) do
                    -- Merge icon + responseText from old responses table if available
                    local oldResp = oldResponses and oldResponses[btn.id]
                    local icon = (oldResp and oldResp.icon)
                        or (Loothing.DefaultSettings.responseSets.sets[1]
                            and (function()
                                for _, db in ipairs(Loothing.DefaultSettings.responseSets.sets[1].buttons) do
                                    if db.id == btn.id then return db.icon end
                                end
                            end)())

                    -- Convert per-set whisperKey string to per-button whisperKeys array
                    local whisperKeys = {}
                    if oldSet.whisperKey and oldSet.whisperKey ~= "" then
                        local stripped = oldSet.whisperKey:gsub("^!", ""):lower()
                        -- Assign to button 1 (the "primary" button), empty for others
                        if btn.sort == 1 or btn.id == 1 then
                            whisperKeys = { stripped }
                        end
                    end

                    newButtons[#newButtons + 1] = {
                        id           = btn.id,
                        text         = btn.text or "",
                        responseText = (oldResp and oldResp.name) or btn.text or "",
                        color        = btn.color or { 1, 1, 1, 1 },
                        icon         = icon,
                        sort         = btn.sort or #newButtons + 1,
                        whisperKeys  = whisperKeys,
                    }
                end

                rs.sets[setId] = {
                    name    = oldSet.name or ("Set " .. setId),
                    buttons = newButtons,
                }
            end

            -- Migrate typeCodeMap
            if profileDB.buttonSets.typeCodeMap then
                for tc, sid in pairs(profileDB.buttonSets.typeCodeMap) do
                    rs.typeCodeMap[tc] = sid
                end
            end
        else
            -- No old data: use defaults
            rs = Utils.DeepCopy(defaults)
        end

        profileDB.responseSets = rs
        Loothing:Debug("Migration 1.3.0: Merged responses + buttonSets -> responseSets")
    end, "profile")

    -- Migration 1.3.2: Settings audit cleanup + autoAward structured reasons
    self:Register("1.3.2", "Settings audit cleanup and structured auto-award reasons", function(profileDB, _globalDB)
        -- Remove dead settings
        if profileDB.settings then
            profileDB.settings.appendRealmNames = nil
            profileDB.settings.printResponses = nil
        end
        if profileDB.ml then
            profileDB.ml.autoAddPets = nil
        end
        if profileDB.awardReasons then
            profileDB.awardReasons.numReasons = nil
        end

        -- Migrate autoAward.reason (free-text) -> autoAward.reasonId (structured)
        if profileDB.autoAward and profileDB.autoAward.reason and not profileDB.autoAward.reasonId then
            local freeText = profileDB.autoAward.reason
            local reasons = profileDB.awardReasons and profileDB.awardReasons.reasons
            if reasons and type(reasons) == "table" then
                local lowerText = freeText:lower()
                -- Case-insensitive match against existing reasons
                for _, reason in ipairs(reasons) do
                    if reason.name and reason.name:lower() == lowerText then
                        profileDB.autoAward.reasonId = reason.id
                        Loothing:Debug("Migration 1.3.2: Mapped autoAward.reason '" .. freeText .. "' -> reasonId", reason.id)
                        break
                    end
                end

                -- No match found: create new reason if under cap
                if not profileDB.autoAward.reasonId and freeText ~= "" then
                    if #reasons < 20 then
                        local maxId = 0
                        for _, r in ipairs(reasons) do
                            if r.id and r.id > maxId then maxId = r.id end
                        end
                        local newReason = {
                            id = maxId + 1,
                            name = freeText,
                            color = { 1.0, 1.0, 1.0, 1.0 },
                            sort = #reasons + 1,
                            log = true,
                            disenchant = false,
                        }
                        reasons[#reasons + 1] = newReason
                        profileDB.autoAward.reasonId = newReason.id
                        Loothing:Debug("Migration 1.3.2: Created new reason '" .. freeText .. "' with id", newReason.id)
                    else
                        Loothing:Debug("Migration 1.3.2: Could not map autoAward.reason '" .. freeText .. "' (at 20-reason cap)")
                    end
                end
            end
            -- Keep autoAward.reason in saved vars for backward compat (not actively read)
        end

        Loothing:Debug("Migration 1.3.2: Settings audit cleanup complete")
    end, "profile")
end

--[[--------------------------------------------------------------------
    Migration Execution
----------------------------------------------------------------------]]

--- Run all pending migrations on addon load
-- Called from Init.lua after ADDON_LOADED event.
-- Uses the global scope for migration tracking so it persists across profiles.
function Migration:RunOnLoad()
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
    local currentVersion = Loothing.VERSION

    Loothing:Debug("Running migrations from", oldVersion, "to", currentVersion)

    -- Sort migrations by version
    table.sort(migrations, function(a, b)
        return self:CompareVersions(a.version, b.version) < 0
    end)

    local executed = 0
    local failures = 0
    local completedVersions = self:GetCompletedVersions()

    -- Execute each pending GLOBAL migration (once per account)
    for _, migration in ipairs(migrations) do
        if migration.scope == "global" then
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
                    failures = failures + 1
                    Loothing:Error("Migration", migration.version, "failed:", err)
                end
            end
        end
    end

    -- Profile-scoped migrations: once per profile, tracked in the profile
    local profileExecuted, profileFailures = self:RunPendingProfileMigrations(profileDB, globalDB)
    executed = executed + profileExecuted
    failures = failures + profileFailures

    -- Only advance the stored version stamp on a fully clean run, so
    -- diagnostics don't report a clean migration over a failed one.
    -- Failed migrations retry next login (they're not in history).
    if failures == 0 then
        globalDB.migrations.version = currentVersion
    end
    globalDB.migrations.lastRun = date("%Y-%m-%d %H:%M:%S")

    if executed > 0 then
        Loothing:Debug("Executed", executed, "migrations")
    else
        Loothing:Debug("No migrations needed")
    end

    -- Profiles activated later (switch, new alt profile) get their pending
    -- profile-scoped migrations at that moment
    self:HookProfileChanges()
end

--- Run pending profile-scoped migrations against the given (or active)
--- profile. Completion is tracked in profileDB.migrationsRun so each
--- profile migrates independently. Assumes RegisterMigrations + version
--- sort already ran (RunOnLoad does both before its first call here).
-- @param profileDB table|nil - Profile scope (default: active profile)
-- @param globalDB table|nil - Global scope (default: current)
-- @return number, number - executed count, failure count
function Migration:RunPendingProfileMigrations(profileDB, globalDB)
    if not profileDB then
        profileDB, globalDB = self:GetDataScopes()
    end
    if type(profileDB) ~= "table" then
        return 0, 0
    end
    if type(profileDB.migrationsRun) ~= "table" then
        profileDB.migrationsRun = {}
    end

    local executed, failures = 0, 0
    for _, migration in ipairs(migrations) do
        if migration.scope == "profile" and not profileDB.migrationsRun[migration.version] then
            Loothing:Debug("Executing profile migration:", migration.version, "-", migration.description)

            local success, err = pcall(migration.func, profileDB, globalDB)
            if success then
                executed = executed + 1
                profileDB.migrationsRun[migration.version] = date("%Y-%m-%d %H:%M:%S")
            else
                failures = failures + 1
                Loothing:Error("Migration", migration.version, "(profile) failed:", err)
            end
        end
    end

    if executed > 0 then
        Loothing:Debug("Executed", executed, "profile migrations")
    end
    return executed, failures
end

--- Re-run pending profile migrations whenever the active profile changes -- INTERNAL
function Migration:HookProfileChanges()
    if self.profileHooked then
        return
    end
    local sv = Loothing.Settings and Loothing.Settings.GetDB and Loothing.Settings:GetDB()
    if sv and sv.RegisterCallback then
        sv:RegisterCallback("OnProfileChanged", function()
            self:RunPendingProfileMigrations()
        end, self)
        self.profileHooked = true
    end
end

--- Alias for RunOnLoad (public API name)
function Migration:RunPending()
    self:RunOnLoad()
end

--[[--------------------------------------------------------------------
    Data Scope Access
----------------------------------------------------------------------]]

--- Get profile and global data scopes
-- @return table, table - profileDB, globalDB
function Migration:GetDataScopes()
    local profileDB, globalDB

    -- Try Loolib SavedVariables first
    if Loothing and Loothing.Settings then
        local sv = Loothing.Settings:GetDB()
        if sv then
            profileDB = Loothing.Settings.db
            globalDB = Loothing.Settings.global
        end
    end

    if not profileDB then
        local store = Loolib.Data.SavedVariables.GetAddonData("Loothing", false)
        local playerName = Loolib.SecretUtil.SafeUnitName("player")
        local realmName = GetRealmName()
        local charKey = playerName and realmName and (playerName .. " - " .. realmName) or nil
        profileDB = store and store.profiles and store.profileKeys and store.profiles[(store.profileKeys[charKey or ""] or "Default")] or {}
    end

    if not globalDB then
        local store = Loolib.Data.SavedVariables.GetAddonData("Loothing", false)
        globalDB = (store and store.global) or {}
    end

    return profileDB, globalDB
end

--[[--------------------------------------------------------------------
    Query API
----------------------------------------------------------------------]]

--- Get all completed migration versions
-- @return table - Set of version strings that have been completed (version -> true)
function Migration:GetCompletedVersions()
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
-- Global scope: account-wide. Profile scope: for the ACTIVE profile.
-- @param version string - Migration version to check
-- @return boolean - True if migration has been executed
function Migration:HasRun(version)
    local completed = self:GetCompletedVersions()
    if completed[version] == true then
        return true
    end
    local profileDB = self:GetDataScopes()
    return type(profileDB) == "table"
        and type(profileDB.migrationsRun) == "table"
        and profileDB.migrationsRun[version] ~= nil
end

--- Get the current stored migration version
-- @return string - Version string
function Migration:GetCurrentVersion()
    local _, globalDB = self:GetDataScopes()

    if globalDB and globalDB.migrations then
        return globalDB.migrations.version or "0.0.0"
    end

    return "0.0.0"
end

--- Get migration history (array of completed migration records)
-- @return table - Array of { version, description, timestamp }
function Migration:GetHistory()
    local _, globalDB = self:GetDataScopes()

    if globalDB and globalDB.migrations and globalDB.migrations.history then
        return globalDB.migrations.history
    end

    return {}
end

--- Check if a specific migration has been executed (alias)
-- @param version string - Migration version to check
-- @return boolean
function Migration:HasMigrationRun(version)
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
function Migration:CompareVersions(v1, v2)
    return Utils.CompareVersions(v1, v2)
end

--[[--------------------------------------------------------------------
    Debug Utilities
----------------------------------------------------------------------]]

--- Force re-run all migrations (DANGEROUS - for debugging only)
-- Clears global history and the ACTIVE profile's tracking only; to
-- force-rerun another profile's migrations, switch to it first.
function Migration:ForceRerunAll()
    Loothing:Debug("WARNING: Force re-running all migrations")

    local profileDB, globalDB = self:GetDataScopes()

    if globalDB and globalDB.migrations then
        globalDB.migrations.version = "0.0.0"
        globalDB.migrations.history = {}
    end
    if type(profileDB) == "table" then
        profileDB.migrationsRun = {}
    end

    self:RunOnLoad()
end
