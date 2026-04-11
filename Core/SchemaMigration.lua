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

--- All migration functions, indexed by the target schemaVersion.
local migrations = {
    [2] = migrateV2,
    [3] = migrateV3,
}

--- Run all pending migrations on a SavedVariables store.
-- Iterates every profile and brings it forward to the current
-- schemaVersion. Wraps each step in pcall so that a single bad
-- profile cannot block other profiles from migrating.
-- @param sv table - Loolib SavedVariables instance (must expose .profiles)
function SchemaMigration:Run(sv)
    if not sv or type(sv.profiles) ~= "table" then
        return
    end
    local target = (Loothing.DefaultSettings and Loothing.DefaultSettings.schemaVersion) or 1

    for profileName, profile in pairs(sv.profiles) do
        if type(profile) == "table" then
            local current = tonumber(profile.schemaVersion) or 1
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
