--[[--------------------------------------------------------------------
    Loothing - SchemaMigration

    Forward-only schema migrations for Loothing's per-profile settings.
    Each migration is keyed by the schemaVersion it produces, and is
    invoked when the stored profile's `schemaVersion` is below the
    current Loothing.DefaultSettings.schemaVersion.

    Distinct from Core/Migration.lua:
      * Migration.lua runs AFTER Settings:Init and is for version-string
        keyed data fixups (e.g., one-shot history repairs).
      * SchemaMigration.lua runs BEFORE Settings:Init and rewrites the
        raw profile table to match a new DefaultSettings shape (key
        renames, merges, deletions).

    Migrations must be:
      * Idempotent — safe to run twice on the same profile.
      * In-place — mutate the profile table directly. The caller wraps
        each migration in pcall and bumps schemaVersion on success.
      * Forward-only — there are no downgrade paths. If we ever need to
        roll back, a downgrade migration must be written separately.

    Loaded by Loothing.toc BEFORE Core/Settings.lua so that Settings:Init
    can call SchemaMigration:Run(self.sv) right after the SavedVariables
    database is created.
----------------------------------------------------------------------]]

local _, ns = ...
local Loothing = ns.Addon

local SchemaMigration = {}
ns.SchemaMigration = SchemaMigration

--[[--------------------------------------------------------------------
    Schema v2 — Loothing 2.0.7 settings cleanup

    Collapses redundant keys, renames the `settings.*` namespace into
    real category namespaces, and deletes legacy/dead fields.

    Sources:
      ml.onlyUseInRaids + ml.allowOutOfRaid -> ml.scope
      voting.hideVotes + voting.anonymousVoting -> voting.privacy
      voting.observe -> deleted (observers.openObservation is canonical)
      historySettings.*  -> history.*
      historySettings.sendHistory + sendToGuild -> history.share
      settings.uiScale -> frame.uiScale
      settings.mainFramePosition -> frame.position
      settings.showMinimapButton / ui.showMinimapButton -> frame.showMinimapButton
      ui.minimapButtonAngle -> frame.minimapButtonAngle
      settings.votingMode -> voting.mode
      settings.votingTimeout -> voting.timeout
      settings.sessionTrigger* -> session.triggerAction / triggerTiming /
                                  session.scope.{raid,dungeon,openWorld}
      settings.groupLootMode -> session.groupLootMode
      settings.autoGroupLootGuildOnly -> session.groupLootGuildOnly
      settings.autoTrade -> ml.autoTrade
      settings.sessionTriggerMode -> deleted (legacy single-field model)
      announcements.{awardChannel,awardChannelSecondary,awardText,
                     itemChannel,itemText} -> deleted (superseded by
                     awardLines / itemLines arrays)
      autoAward.reason -> deleted (superseded by reasonId)
      buttonSets -> deleted (superseded by responseSets)
      winnerDetermination.requireConfirmation -> deleted (derived from mode)
----------------------------------------------------------------------]]

local function migrateV2(profile)
    -- ml.onlyUseInRaids + ml.allowOutOfRaid -> ml.scope
    if type(profile.ml) == "table" then
        local ml = profile.ml
        if ml.scope == nil then
            if ml.allowOutOfRaid == true then
                ml.scope = "anywhere"
            elseif ml.onlyUseInRaids == false then
                ml.scope = "raids_and_dungeons"
            else
                ml.scope = "raids_only"
            end
        end
        ml.onlyUseInRaids = nil
        ml.allowOutOfRaid = nil
    end

    -- voting.hideVotes + voting.anonymousVoting -> voting.privacy
    if type(profile.voting) == "table" then
        local v = profile.voting
        if v.privacy == nil then
            if v.anonymousVoting == true then
                v.privacy = "anonymous"
            elseif v.hideVotes == true then
                v.privacy = "hide_counts"
            else
                v.privacy = "open"
            end
        end
        v.hideVotes = nil
        v.anonymousVoting = nil
        -- voting.observe was a redundant shadow of observers.openObservation;
        -- the latter is canonical and lives in observers.*.
        v.observe = nil
    end

    -- historySettings.* -> history.*  (and sendHistory + sendToGuild -> history.share)
    local hs = profile.historySettings
    if type(hs) == "table" then
        profile.history = profile.history or {}
        local h = profile.history

        if h.share == nil then
            if hs.sendHistory == true and hs.sendToGuild == true then
                h.share = "guild"
            elseif hs.sendHistory == true then
                h.share = "group"
            else
                h.share = "off"
            end
        end

        if h.enabled == nil and hs.enabled ~= nil then h.enabled = hs.enabled end
        if h.savePersonalLoot == nil and hs.savePersonalLoot ~= nil then
            h.savePersonalLoot = hs.savePersonalLoot
        end
        if h.maxEntries == nil and hs.maxEntries ~= nil then h.maxEntries = hs.maxEntries end
        if h.autoExportWeb == nil and hs.autoExportWeb ~= nil then
            h.autoExportWeb = hs.autoExportWeb
        end

        profile.historySettings = nil
    end

    -- settings.* renames into category namespaces
    local s = profile.settings
    if type(s) == "table" then
        profile.frame = profile.frame or {}
        if profile.frame.uiScale == nil and s.uiScale ~= nil then
            profile.frame.uiScale = s.uiScale
        end
        if profile.frame.position == nil and s.mainFramePosition ~= nil then
            profile.frame.position = s.mainFramePosition
        end
        if profile.frame.showMinimapButton == nil and s.showMinimapButton ~= nil then
            profile.frame.showMinimapButton = s.showMinimapButton
        end

        profile.session = profile.session or {}
        if profile.session.triggerAction == nil and s.sessionTriggerAction ~= nil then
            profile.session.triggerAction = s.sessionTriggerAction
        end
        if profile.session.triggerTiming == nil and s.sessionTriggerTiming ~= nil then
            profile.session.triggerTiming = s.sessionTriggerTiming
        end
        profile.session.scope = profile.session.scope or {}
        if profile.session.scope.raid == nil and s.sessionTriggerRaid ~= nil then
            profile.session.scope.raid = s.sessionTriggerRaid
        end
        if profile.session.scope.dungeon == nil and s.sessionTriggerDungeon ~= nil then
            profile.session.scope.dungeon = s.sessionTriggerDungeon
        end
        if profile.session.scope.openWorld == nil and s.sessionTriggerOpenWorld ~= nil then
            profile.session.scope.openWorld = s.sessionTriggerOpenWorld
        end
        if profile.session.groupLootMode == nil and s.groupLootMode ~= nil then
            profile.session.groupLootMode = s.groupLootMode
        end
        if profile.session.groupLootGuildOnly == nil and s.autoGroupLootGuildOnly ~= nil then
            profile.session.groupLootGuildOnly = s.autoGroupLootGuildOnly
        end

        profile.voting = profile.voting or {}
        if profile.voting.mode == nil and s.votingMode ~= nil then
            profile.voting.mode = s.votingMode
        end
        if profile.voting.timeout == nil and s.votingTimeout ~= nil then
            profile.voting.timeout = s.votingTimeout
        end

        profile.ml = profile.ml or {}
        if profile.ml.autoTrade == nil and s.autoTrade ~= nil then
            profile.ml.autoTrade = s.autoTrade
        end

        profile.settings = nil
    end

    -- ui.* renames (these were a separate inconsistent namespace)
    if type(profile.ui) == "table" then
        profile.frame = profile.frame or {}
        if profile.ui.showMinimapButton ~= nil and profile.frame.showMinimapButton == nil then
            profile.frame.showMinimapButton = profile.ui.showMinimapButton
        end
        if profile.ui.minimapButtonAngle ~= nil and profile.frame.minimapButtonAngle == nil then
            profile.frame.minimapButtonAngle = profile.ui.minimapButtonAngle
        end
        profile.ui = nil
    end

    -- Drop legacy/dead announcement fields
    if type(profile.announcements) == "table" then
        profile.announcements.awardChannel          = nil
        profile.announcements.awardChannelSecondary = nil
        profile.announcements.awardText             = nil
        profile.announcements.itemChannel           = nil
        profile.announcements.itemText              = nil
    end

    -- Drop legacy autoAward.reason (superseded by reasonId)
    if type(profile.autoAward) == "table" then
        profile.autoAward.reason = nil
    end

    -- Drop legacy buttonSets table (superseded by responseSets)
    profile.buttonSets = nil

    -- Drop dead winnerDetermination.requireConfirmation
    if type(profile.winnerDetermination) == "table" then
        profile.winnerDetermination.requireConfirmation = nil
    end
end

--[[--------------------------------------------------------------------
    Schema v3 — Loothing 2.0.8 dead-weight cleanup

    Drops settings that were registered but had no consumer or were
    wired to the wrong call site:
      rollFrame.autoRollOnSubmit -> deleted (was the misnamed setting
        that pre-rolled on every item display instead of on submit)
      councilTable.rowHeight     -> deleted (only reader was an
        orphaned getter; renderers all used a hardcoded row height)
      voting.numButtons          -> deleted (had no UI surface, no
        setter caller; the single fallback reader was inlined as 5)
      profile.responses          -> deleted (legacy display-metadata
        table, fully superseded by responseSets in earlier versions)

    Idempotent: nilling an already-nil field is a no-op.
----------------------------------------------------------------------]]
local function migrateV3(profile)
    if type(profile.rollFrame) == "table" then
        profile.rollFrame.autoRollOnSubmit = nil
    end
    if type(profile.councilTable) == "table" then
        profile.councilTable.rowHeight = nil
    end
    if type(profile.voting) == "table" then
        profile.voting.numButtons = nil
    end
    profile.responses = nil
end

--[[--------------------------------------------------------------------
    Schema v4 — Loothing 2.0.20 configurable loot filter

    Seeds the new `loot.filter.*` namespace from the legacy hardcoded
    BLACKLISTED_ITEM_CLASSES table so existing users see no behavior
    change on upgrade. Only writes keys that are unset — re-running
    after a user has customised their filter is a no-op.

    Sources:
      Loothing.MinQuality constant -> loot.filter.minQuality
      hardcoded BLACKLISTED_ITEM_CLASSES -> loot.filter.classes.<id>.*
----------------------------------------------------------------------]]
local function migrateV4(profile)
    -- Defensive type guards (mirrors the migrateV2/V3 pattern) — without
    -- these, a corrupt or hostile SVars `loot = false` would error here
    -- and pcall it from the runner, leaving the profile stuck at v3 and
    -- re-erroring on every login.
    if type(profile.loot) ~= "table" then
        profile.loot = {}
    end
    if type(profile.loot.filter) ~= "table" then
        profile.loot.filter = {}
    end
    local filter = profile.loot.filter

    -- minQuality must be a number; auto-heal "epic" / nil / boolean.
    if type(filter.minQuality) ~= "number" then
        -- Default to 0 (no quality filtering). Pre-2.0.20 there was a
        -- hardcoded EPIC-only gate in HandleTradable with no UI surface,
        -- which silently dropped any drop the ML might have wanted to
        -- consider. Existing users get the safer default; if they want
        -- the old strictness back they can raise it under Settings →
        -- Loot Filtering.
        filter.minQuality = 0
    end

    if type(filter.classes) ~= "table" then
        filter.classes = {
            [0]  = { blocked = true },
            [5]  = { blocked = true },
            [7]  = { blocked = true },
            [12] = { blocked = true },
            [15] = { blocked = false, subclasses = { [1] = true, [4] = true } },
            [20] = { blocked = true },
        }
    end
end

--[[--------------------------------------------------------------------
    migrateV5: idempotent cleanup of stale keys from earlier migrations.

    Over iterations of v2.x some profiles ended up with BOTH the old key
    and the new key populated (e.g., `settings.sessionTriggerAction="auto"`
    alongside `session.triggerAction="prompt"`). Readers use the new key,
    but settings exporters / pretty-printers / debug dumps confuse users
    by showing the stale value. migrateV2 was supposed to wipe
    `profile.settings` entirely after copying, but a pcall failure or an
    intermediate write between schema bumps left some profiles in the
    half-migrated state.

    Also purges test-mode council members — they end up persisted when
    a user enables Test Mode, adds synthetic players, then disables Test
    Mode without cleaning up. The `isTestMode` flag on each row is
    authoritative; we just remove every row that carries it.

    Sources dropped:
      settings.*             -> nil (fully superseded by category namespaces)
      ui.*                   -> nil (fully superseded by frame.*)
      historySettings.*      -> nil (fully superseded by history.*)
      ml.onlyUseInRaids      -> nil (superseded by ml.scope in migrateV2)
      ml.allowOutOfRaid      -> nil (same)
      voting.hideVotes       -> nil (superseded by voting.privacy)
      voting.anonymousVoting -> nil (same)
      voting.observe         -> nil (observers.openObservation is canonical)
      council members with isTestMode=true -> removed
----------------------------------------------------------------------]]
local function migrateV5(profile)
    -- Dead namespaces — superseded in v2 but may have survived a partial
    -- migration run. Null only if empty / fully migrated; if somehow a
    -- user has data only in the OLD key, preserve it for forensics rather
    -- than silently discard.
    if type(profile.settings) == "table" then
        -- Legacy keys that are now guaranteed to have new-key counterparts
        -- populated (by migrateV2 if it ran, or by default-fill). Nil them.
        profile.settings.sessionTriggerAction   = nil
        profile.settings.sessionTriggerTiming   = nil
        profile.settings.sessionTriggerRaid     = nil
        profile.settings.sessionTriggerDungeon  = nil
        profile.settings.sessionTriggerOpenWorld = nil
        profile.settings.sessionTriggerMode     = nil  -- deleted entirely in migrateV2
        profile.settings.groupLootMode          = nil
        profile.settings.autoGroupLootGuildOnly = nil
        profile.settings.votingMode             = nil
        profile.settings.votingTimeout          = nil
        profile.settings.autoTrade              = nil
        profile.settings.uiScale                = nil
        profile.settings.mainFramePosition      = nil
        profile.settings.showMinimapButton      = nil
        profile.settings.autoStartSession       = nil  -- superseded by session.triggerAction
        -- If settings is now empty (all cleaned), drop it entirely.
        if next(profile.settings) == nil then
            profile.settings = nil
        end
    end

    if type(profile.ui) == "table" then
        profile.ui.showMinimapButton  = nil
        profile.ui.minimapButtonAngle = nil
        if next(profile.ui) == nil then profile.ui = nil end
    end

    -- historySettings: docblock promises cleanup here; migrateV2 would have
    -- copied these to profile.history.* and nilled profile.historySettings,
    -- but a partial-migration run can leave it behind. Drop the subkeys only
    -- if their target (profile.history.X) is already populated — preserve
    -- orphan data as forensic if history.* is still nil.
    if type(profile.historySettings) == "table" then
        local hs = profile.historySettings
        profile.history = profile.history or {}
        local h = profile.history
        if h.share == nil and (hs.sendHistory ~= nil or hs.sendToGuild ~= nil) then
            if hs.sendHistory == true and hs.sendToGuild == true then
                h.share = "guild"
            elseif hs.sendHistory == true then
                h.share = "group"
            else
                h.share = "off"
            end
        end
        if h.enabled        == nil and hs.enabled        ~= nil then h.enabled        = hs.enabled end
        if h.savePersonalLoot == nil and hs.savePersonalLoot ~= nil then h.savePersonalLoot = hs.savePersonalLoot end
        if h.maxEntries     == nil and hs.maxEntries     ~= nil then h.maxEntries     = hs.maxEntries end
        if h.autoExportWeb  == nil and hs.autoExportWeb  ~= nil then h.autoExportWeb  = hs.autoExportWeb end
        profile.historySettings = nil
    end

    if type(profile.ml) == "table" then
        -- If migrateV2 never derived ml.scope (e.g., it threw and the
        -- pcall isolator bailed before the derivation), recompute it now
        -- BEFORE nilling the legacy fields. Otherwise nilling loses the
        -- signal and the profile silently falls to the "raids_only"
        -- default at the Settings:Get site.
        if profile.ml.scope == nil then
            if profile.ml.allowOutOfRaid == true then
                profile.ml.scope = "anywhere"
            elseif profile.ml.onlyUseInRaids == false then
                profile.ml.scope = "raids_and_dungeons"
            elseif profile.ml.onlyUseInRaids ~= nil or profile.ml.allowOutOfRaid ~= nil then
                -- Legacy flags present but both default — use "raids_only"
                profile.ml.scope = "raids_only"
            end
            -- If both legacy flags are nil, leave scope nil so Settings:Get
            -- falls back to the default. Don't invent a value.
        end
        profile.ml.onlyUseInRaids = nil
        profile.ml.allowOutOfRaid = nil
    end

    if type(profile.voting) == "table" then
        -- Same pattern: derive voting.privacy before nilling legacy fields.
        if profile.voting.privacy == nil then
            if profile.voting.anonymousVoting == true then
                profile.voting.privacy = "anonymous"
            elseif profile.voting.hideVotes == true then
                profile.voting.privacy = "hide_counts"
            elseif profile.voting.anonymousVoting ~= nil or profile.voting.hideVotes ~= nil then
                profile.voting.privacy = "open"
            end
        end
        profile.voting.hideVotes       = nil
        profile.voting.anonymousVoting = nil
        profile.voting.observe         = nil
    end

    -- Additional legacy keys from migrateV3 / removed-feature cleanups.
    if type(profile.winnerDetermination) == "table" then
        profile.winnerDetermination.requireConfirmation = nil
    end
    if type(profile.autoAward) == "table" then
        profile.autoAward.reason = nil
    end
    profile.buttonSets = nil  -- superseded by responseSets

    -- Test-mode council members: purge. These land in the profile when a
    -- user runs /lt test council or the equivalent UI. Without cleanup
    -- they bleed into real sessions as phantom voters.
    if type(profile.council) == "table" then
        -- Council rows may live under `members` or directly as array entries;
        -- handle both shapes defensively.
        local function purgeTestRows(list)
            if type(list) ~= "table" then return end
            -- Walk backwards so removals don't disturb iteration indices.
            for i = #list, 1, -1 do
                local row = list[i]
                if type(row) == "table" and row.isTestMode then
                    table.remove(list, i)
                end
            end
        end
        purgeTestRows(profile.council)
        purgeTestRows(profile.council.members)
    end
end

--- All migration functions, indexed by the target schemaVersion.
local migrations = {
    [2] = migrateV2,
    [3] = migrateV3,
    [4] = migrateV4,
    [5] = migrateV5,
}

--- Run all pending migrations on a SavedVariables store.
-- Iterates every profile and brings it forward to the current
-- schemaVersion. Wraps each step in pcall so that a single bad
-- profile cannot block other profiles from migrating.
--
-- @param sv table - Loolib SavedVariables accessor. The actual data lives
--   at `sv.data` (see Loolib/Data/SavedVariables.lua:231,258: `self.data`
--   holds `.profiles`, `.profileKeys`, scope tables). Pre-2.0.28 this code
--   read `sv.profiles` directly, which silently returned nil because the
--   accessor doesn't proxy through to `sv.data` for arbitrary keys — so
--   ALL migrations since schemaVersion introduction have been no-ops.
--   Legacy keys (settings.sessionTrigger*, ml.onlyUseInRaids, etc.) have
--   been persisting unchanged in users' SV for the entire life of the
--   migration system. Fixed in 2.0.28 by walking `sv.data.profiles`.
function SchemaMigration:Run(sv)
    local data = sv and sv.data
    if type(data) ~= "table" then return end
    if type(data.profiles) ~= "table" then return end

    local target = (Loothing.DefaultSettings and Loothing.DefaultSettings.schemaVersion) or 1

    for profileName, profile in pairs(data.profiles) do
        if type(profile) == "table" then
            -- CRITICAL: Loolib's SavedVariables attaches a __index metatable
            -- to each profile that falls through to PROFILE_DEFAULTS. Since
            -- PROFILE_DEFAULTS.schemaVersion == target, a naive
            -- `profile.schemaVersion` read on a legacy profile that has
            -- never actually stored a schemaVersion returns the DEFAULT
            -- (= target), making the migration loop think "already
            -- migrated" and skipping every step. We must rawget to
            -- distinguish a stored-version number from the metatable
            -- fallback. Fixes the root-cause of "migrations have never
            -- actually run for any user" — the partnered fix to 2.0.28's
            -- sv.data.profiles accessor correction above.
            local current = tonumber(rawget(profile, "schemaVersion")) or 1
            for v = current + 1, target do
                local fn = migrations[v]
                if fn then
                    local ok, err = pcall(fn, profile)
                    if ok then
                        profile.schemaVersion = v
                    else
                        if Loothing and Loothing.Error then
                            Loothing:Error(string.format(
                                "Settings migration v%d failed for profile '%s': %s",
                                v, tostring(profileName), tostring(err)))
                        end
                        -- Bail out on this profile so we don't apply
                        -- subsequent migrations to a half-migrated state.
                        break
                    end
                end
            end
        end
    end
end
