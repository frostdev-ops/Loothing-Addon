--[[--------------------------------------------------------------------
    Loothing - Loot Council Addon for WoW 12.0+
    Simulator - Full-pipeline boss kill harness

    Drives the real loot pipeline starting from ENCOUNTER_END through
    SESSION_INIT broadcast and award. Unlike Debug/TestMode.lua (which
    seeds items directly into Session:AddItem), this module fires the
    encounter event handlers and feeds items via Session:HandleTradable
    so the bag-scan -> tradable -> ApplyTriggerAction path is exercised.
----------------------------------------------------------------------]]


local _, ns = ...
local Loolib = LibStub("Loolib")
local Loothing = ns.Addon
local Utils = ns.Utils

local Simulator = ns.Simulator or Loolib.CreateFromMixins(Loolib.CallbackRegistryMixin)
ns.Simulator = Simulator

local SIMULATOR_EVENTS = {
    "OnSimStateChanged",
    "OnQueueChanged",
    "OnAutofireChanged",
    "OnSelectedRaidChanged",
}

local DEFAULT_INSTANCE_KEY = "NerubarPalace"
local DEFAULT_DIFFICULTY = 16        -- Mythic
local DEFAULT_GROUP_SIZE = 20
local DEFAULT_ITEMS_PER_KILL = 3
local DEFAULT_TRADE_TIME = 7200      -- 2 hours, max trade window
local AUTOFIRE_DELAY = 1.5           -- delay between session-end and next queued kill
local FLUSH_DELAY_DEFAULT = 6        -- spacing between back-to-back flushed kills
local DEFAULT_RAID_SIZE = 20         -- fake raid roster size on Enable()

-- Class pool used to give fake raiders realistic class spreads.
-- Must match WoW's classFile constants (uppercase, no spaces).
local FAKE_CLASS_POOL = {
    { class = "WARRIOR",     localized = "Warrior",      role = "TANK"    },
    { class = "PALADIN",     localized = "Paladin",      role = "TANK"    },
    { class = "DEATHKNIGHT", localized = "Death Knight", role = "TANK"    },
    { class = "DRUID",       localized = "Druid",        role = "HEALER"  },
    { class = "PRIEST",      localized = "Priest",       role = "HEALER"  },
    { class = "SHAMAN",      localized = "Shaman",       role = "HEALER"  },
    { class = "MONK",        localized = "Monk",         role = "HEALER"  },
    { class = "EVOKER",      localized = "Evoker",       role = "HEALER"  },
    { class = "HUNTER",      localized = "Hunter",       role = "DAMAGER" },
    { class = "ROGUE",       localized = "Rogue",        role = "DAMAGER" },
    { class = "MAGE",        localized = "Mage",         role = "DAMAGER" },
    { class = "WARLOCK",     localized = "Warlock",      role = "DAMAGER" },
    { class = "DEMONHUNTER", localized = "Demon Hunter", role = "DAMAGER" },
}

local FAKE_NAME_PREFIXES = {
    "Shadow", "Fire", "Ice", "Storm", "Dark", "Light", "Blood", "Soul",
    "Iron", "Steel", "Thunder", "Frost", "Moon", "Sun", "Star", "Void",
    "Dawn", "Dusk", "Wind", "Stone", "Wild", "Grim", "Holy", "Ash",
}
local FAKE_NAME_SUFFIXES = {
    "blade", "strike", "heart", "fang", "claw", "guard", "bane", "fury",
    "rage", "storm", "walker", "hunter", "song", "weaver", "born", "wing",
    "shroud", "mantle", "whisper", "step", "reaver", "warden", "ember",
}

-- Response weights for auto-generated candidate responses
local RESPONSE_WEIGHTS = {
    { value = 1, weight = 35 },  -- NEED
    { value = 2, weight = 25 },  -- GREED
    { value = 3, weight = 15 },  -- OFFSPEC
    { value = 4, weight = 5  },  -- TRANSMOG
    { value = 5, weight = 20 },  -- PASS
}

local function safePrint(...)
    if Loothing and Loothing.Print then
        Loothing:Print(...)
    else
        print(...)
    end
end

local function safeDebug(...)
    if Loothing and Loothing.Debug then
        Loothing:Debug(...)
    end
end

--[[--------------------------------------------------------------------
    Initialization
----------------------------------------------------------------------]]

function Simulator:OnLoad()
    if self._loaded then return end
    self._loaded = true

    Loolib.CallbackRegistryMixin.OnLoad(self)
    self:GenerateCallbackEvents(SIMULATOR_EVENTS)

    self.queue = {}
    self.state = {
        active = false,
        currentKill = nil,
        autoFireNext = true,
    }
    self.callbacksRegistered = false
    self.cachedRaid = nil          -- populated lazily by GetCurrentRaid()
    self.savedMLState = nil        -- ML/settings snapshot for restore on Disable()
    self.fakeRaiders = nil         -- 20-person fake raid roster
    self.rosterHooked = false      -- TestMode.GetFakeRaidRoster override flag
    self.autoRespond = true        -- auto-populate candidates+responses on item add
    self.itemHookOwner = "Simulator_Items"
end

--[[--------------------------------------------------------------------
    Activation
----------------------------------------------------------------------]]

function Simulator:Enable(force)
    if self.state.active then
        self:Status()
        return true
    end

    -- Refuse to enable in any context where the simulator's ML override,
    -- fake council, or synthesized ENCOUNTER_END events would corrupt real
    -- raid/instance state. The simulator also leaks addon comms to the
    -- live network (TestModeState:OnOutgoingComm only warns; it does not
    -- intercept), so a sim run in a real raid would broadcast spoofed
    -- session/vote messages to other Loothing users. `force=true` allows
    -- override for advanced users who understand the consequences.
    if not force then
        if IsEncounterInProgress and IsEncounterInProgress() then
            safePrint("Simulator refused: an encounter is in progress. Pass `force` to override.")
            return false
        end
        if Loothing.Session and Loothing.Session.state ~= Loothing.SessionState.INACTIVE then
            safePrint("Simulator refused: a Loothing session is active. End it first or pass `force`.")
            return false
        end
        if ns.LootPickerFrame and ns.LootPickerFrame.IsShown
           and ns.LootPickerFrame:IsShown() then
            safePrint("Simulator refused: the Loot Picker is open. Dismiss it first or pass `force`.")
            return false
        end
        if IsInRaid and IsInRaid() then
            safePrint("Simulator refused: you are in a real raid group. Pass `force` to override.")
            return false
        end
    end

    if ns.TestModeState and not ns.TestModeState:IsActive() then
        -- Allow Settings persistence so InstallMLState can actually write
        -- session.triggerTiming. Without `allowPersistence = true` the
        -- TestModeState guard silently drops the SetSessionTriggerTiming
        -- call and the simulator's pipeline fails to fire when the user
        -- has triggerTiming = "afterLoot".
        local ok = ns.TestModeState:Enter({ force = force, allowPersistence = true })
        if not ok then
            return false
        end
        self._enteredTestMode = true
    end

    -- Ensure fake council exists so HandleTradable looters resolve to known players.
    -- Stash the prior `ns.TestMode.enabled` so Disable() can restore it.
    if ns.TestMode then
        if not ns.TestMode.fakeCouncilMembers or #ns.TestMode.fakeCouncilMembers < 2 then
            ns.TestMode:GenerateFakeCouncil()
        end
        self._priorTestModeEnabled = ns.TestMode.enabled
        ns.TestMode.enabled = true
    end

    -- Generation counter — captured in C_Timer closures so that, if Disable
    -- is called mid-flight, late-firing timers can detect they're stale.
    self._gen = (self._gen or 0) + 1

    self:InstallMLState()
    self:HookRaidRoster()
    if not self.fakeRaiders then
        self:GenerateFakeRaid(DEFAULT_RAID_SIZE)
    end

    self.state.active = true
    self:RegisterSessionCallbacks()
    self:TriggerEvent("OnSimStateChanged", true)

    safePrint(string.format("Simulator ENABLED. Fake raid: %d. Use /lt sim help.",
        self.fakeRaiders and #self.fakeRaiders or 0))
    return true
end

function Simulator:Disable()
    if not self.state.active then return false end
    self.state.active = false
    self.state.currentKill = nil
    -- Clear the FireKill mutex so a new Enable cycle starts clean even
    -- if a prior firing was aborted mid-flight. The `_gen` counter also
    -- invalidates any in-flight C_Timer closures.
    self._firing = false
    self._autofireRetries = nil
    self:UnregisterSessionCallbacks()
    self:UnhookRaidRoster()
    self:RestoreMLState()

    -- Restore prior TestMode flag (don't unilaterally turn off — the user
    -- may have been in a real test mode session before sim started).
    if ns.TestMode then
        ns.TestMode.enabled = self._priorTestModeEnabled and true or false
        -- Remove the fake council Enable() injected into the LIVE roster.
        -- Without this the fakes survived /lt sim off, and the next
        -- council edit's SaveToSettings persisted them into SavedVariables.
        -- Skip when restoring an active test mode — the fakes are then
        -- still that session's working set.
        if not ns.TestMode.enabled and ns.TestMode.ClearFakeData then
            ns.TestMode:ClearFakeData()
        end
    end
    self._priorTestModeEnabled = nil

    -- Exit TestModeState only if Enable() entered it on this user's behalf.
    if self._enteredTestMode and ns.TestModeState and ns.TestModeState:IsActive() then
        ns.TestModeState:Exit()
    end
    self._enteredTestMode = nil

    self:TriggerEvent("OnSimStateChanged", false)
    safePrint("Simulator DISABLED.")
    return true
end

--- Helper: returns true if a captured generation matches current state.
--- Used by deferred C_Timer closures to detect stale firings after Disable.
function Simulator:_isCurrent(gen)
    return self.state.active and self._gen == gen
end

--- Install ML state so HandleTradable accepts injected items.
--- Saves prior values for restore in RestoreMLState().
---
--- Without this, HandleTradable rejects items at the `not isML` gate.
--- The user's `session.triggerAction` setting (manual/prompt/auto) is
--- left untouched so the simulator can exercise the picker UI when the
--- ML has chosen "prompt" — only `triggerTiming` is forced to
--- `encounterEnd` so the trigger fires directly from the synthesised
--- ENCOUNTER_END instead of waiting for a real loot drop.
function Simulator:InstallMLState()
    if self.savedMLState then return end  -- already installed

    local playerName = Utils.GetPlayerFullName()

    self.savedMLState = {
        handleLoot      = Loothing.handleLoot,
        isMasterLooter  = Loothing.isMasterLooter,
        masterLooter    = Loothing.masterLooter,
        explicitML      = Loothing.explicitMasterLooter,
        triggerTiming   = Loothing.Settings and Loothing.Settings:GetSessionTriggerTiming(),
    }

    Loothing.handleLoot           = true
    Loothing.isMasterLooter       = true
    Loothing.masterLooter         = playerName
    Loothing.explicitMasterLooter = playerName

    if Loothing.Settings then
        -- Stash the original triggerTiming to LoolibDB so a /reload or crash
        -- mid-simulation can restore it on next addon load. Without this
        -- stash, the user's saved setting permanently flips to "encounterEnd"
        -- if they reload while sim is active.
        if LoolibDB then
            LoolibDB.simStashedTriggerTiming = self.savedMLState.triggerTiming
        end
        Loothing.Settings:SetSessionTriggerTiming("encounterEnd")
    end

    local action = Loothing.Settings and Loothing.Settings:GetSessionTriggerAction() or "?"
    safeDebug("[Sim] InstallMLState: ML=", playerName, " action=", action, " timing=encounterEnd")
end

function Simulator:RestoreMLState()
    if not self.savedMLState then return end
    local s = self.savedMLState
    Loothing.handleLoot           = s.handleLoot
    Loothing.isMasterLooter       = s.isMasterLooter
    Loothing.masterLooter         = s.masterLooter
    Loothing.explicitMasterLooter = s.explicitML

    if Loothing.Settings then
        if s.triggerTiming then Loothing.Settings:SetSessionTriggerTiming(s.triggerTiming) end
    end
    if LoolibDB then LoolibDB.simStashedTriggerTiming = nil end
    self.savedMLState = nil
    safeDebug("[Sim] RestoreMLState: prior ML state restored")
end

--- Detect a /reload-orphaned simulator stash on the next addon load and
--- restore the user's original triggerTiming. Called from Init.lua during
--- addon bootstrap. No-op when no stash is present.
function Simulator:RecoverOrphanedStash()
    if not LoolibDB then return end
    local stashed = LoolibDB.simStashedTriggerTiming
    if stashed == nil then return end
    if Loothing.Settings and Loothing.Settings.SetSessionTriggerTiming then
        Loothing.Settings:SetSessionTriggerTiming(stashed)
        safePrint("[Sim] Recovered triggerTiming after orphaned simulator stash: " .. tostring(stashed))
    end
    LoolibDB.simStashedTriggerTiming = nil
end

function Simulator:IsActive()
    return self.state.active == true
end

function Simulator:RegisterSessionCallbacks()
    if self.callbacksRegistered then return end
    if not Loothing.Session or not Loothing.Session.RegisterCallback then return end

    Loothing.Session:RegisterCallback("OnSessionStarted", function(_, sessionID, encounterID)
        safeDebug("[Sim] Session started:", tostring(sessionID), "encounter:", tostring(encounterID))
    end, "Simulator")

    Loothing.Session:RegisterCallback("OnSessionEnded", function(_, sessionID)
        safeDebug("[Sim] Session ended:", tostring(sessionID))
        self:OnSessionEnded(sessionID)
    end, "Simulator")

    Loothing.Session:RegisterCallback("OnItemAdded", function(_, item)
        if not self.autoRespond then return end
        local gen = self._gen
        -- Schedule on next frame so the item's CandidateManager + voting state
        -- have stabilized before we dump candidates into it. Bail if the sim
        -- was disabled in between.
        C_Timer.After(0.1, function()
            if not self:_isCurrent(gen) then return end
            self:PopulateCandidates(item)
        end)
    end, self.itemHookOwner)

    self.callbacksRegistered = true
end

function Simulator:UnregisterSessionCallbacks()
    if not self.callbacksRegistered then return end
    if Loothing.Session and Loothing.Session.UnregisterCallback then
        Loothing.Session:UnregisterCallback("OnSessionStarted", "Simulator")
        Loothing.Session:UnregisterCallback("OnSessionEnded", "Simulator")
        Loothing.Session:UnregisterCallback("OnItemAdded", self.itemHookOwner)
    end
    self.callbacksRegistered = false
end

function Simulator:OnSessionEnded()
    if not self.state.active then return end
    if not self.state.autoFireNext then return end
    if #self.queue == 0 then return end

    local gen = self._gen
    C_Timer.After(AUTOFIRE_DELAY, function()
        if not self:_isCurrent(gen) then return end
        if Loothing.Session and Loothing.Session.state ~= Loothing.SessionState.INACTIVE then
            return  -- Another session is already active; defer
        end
        -- Don't autofire on top of an open Loot Picker — the user is
        -- still deciding what to do with the prior boss's loot.
        if ns.LootPickerFrame and ns.LootPickerFrame.IsShown
            and ns.LootPickerFrame:IsShown() then
            -- Re-arm a polling check so we resume the queue once the
            -- picker is dismissed (max 5 attempts to avoid lingering).
            self._autofireRetries = (self._autofireRetries or 0) + 1
            if self._autofireRetries < 10 then
                C_Timer.After(2, function() self:OnSessionEnded() end)
            end
            return
        end
        self._autofireRetries = nil
        self:FireNext()
    end)
end

--[[--------------------------------------------------------------------
    Encounter resolution (live from the Encounter Journal)

    We pull the current raid + bosses from the Encounter Journal so the
    simulator always reflects the current tier without code changes when
    a new raid ships. EJ data is static for a given client install, so we
    cache the result for the session.

    The EncounterJournal addon is loaded on demand; we force-load it via
    C_AddOns.LoadAddOn before reading EJ_* globals.
----------------------------------------------------------------------]]

local function ensureEJLoaded()
    if EJ_GetNumTiers and EJ_GetInstanceByIndex then return true end
    if C_AddOns and C_AddOns.LoadAddOn then
        C_AddOns.LoadAddOn("Blizzard_EncounterJournal")
    elseif LoadAddOn then
        LoadAddOn("Blizzard_EncounterJournal")
    end
    return EJ_GetNumTiers ~= nil and EJ_GetInstanceByIndex ~= nil
end

--- List every raid in the Encounter Journal, grouped by tier.
--- Ordered latest-first by tier, and latest-first within each tier.
--- Cached for the session (EJ data is static per client install).
--- @return table[] { { tierIndex, tierName, instanceID, instanceName, isLatest }, ... }
function Simulator:ListRaids()
    if self._cachedRaidsList then return self._cachedRaidsList end
    if not ensureEJLoaded() then return {} end

    local out = {}
    local numTiers = EJ_GetNumTiers() or 0
    for tier = numTiers, 1, -1 do
        EJ_SelectTier(tier)
        local tierName = EJ_GetTierInfo(tier) or ("Tier " .. tier)

        -- Collect raids in their EJ order, then reverse so the latest
        -- within this tier ends up first.
        local tierRaids = {}
        local idx = 1
        while true do
            local instanceID, name = EJ_GetInstanceByIndex(idx, true)  -- true = isRaid
            if not instanceID then break end
            tierRaids[#tierRaids + 1] = { instanceID = instanceID, instanceName = name }
            idx = idx + 1
        end
        for i = #tierRaids, 1, -1 do
            out[#out + 1] = {
                tierIndex    = tier,
                tierName     = tierName,
                instanceID   = tierRaids[i].instanceID,
                instanceName = tierRaids[i].instanceName,
                isLatest     = (tier == numTiers) and (i == #tierRaids),
            }
        end
    end

    self._cachedRaidsList = out
    return out
end

--- Temporarily clear the EJ class/spec loot filter and return the
--- prior (classID, specID) so the caller can restore it. The EJ filter
--- is sticky and persists across sessions — if the user has it set to
--- their own class/spec, C_EncounterJournal.GetLootInfoByIndex hides
--- any item that isn't usable by that class/spec (trinkets with class
--- restrictions, off-class tier tokens, etc.). Since the simulator
--- wants the FULL loot table, clear before reading.
local function pushEJLootFilter()
    if not EJ_GetLootFilter or not EJ_SetLootFilter then return 0, 0 end
    local classID, specID = EJ_GetLootFilter()
    classID, specID = classID or 0, specID or 0
    if classID ~= 0 or specID ~= 0 then
        EJ_SetLootFilter(0, 0)
    end
    return classID, specID
end

--- Restore the prior EJ class/spec loot filter. ALWAYS re-applies so an
--- interloping Set between push/pop doesn't leave the filter stale.
local function popEJLootFilter(classID, specID)
    if not EJ_SetLootFilter then return end
    EJ_SetLootFilter(classID or 0, specID or 0)
end

--- Load a specific raid's boss list by Encounter Journal instance ID.
--- Caches per-instance; safe to call repeatedly.
function Simulator:LoadRaid(instanceID)
    if not instanceID then return nil end
    self.cachedRaidsByID = self.cachedRaidsByID or {}
    if self.cachedRaidsByID[instanceID] then
        return self.cachedRaidsByID[instanceID]
    end
    if not ensureEJLoaded() then return nil end

    EJ_SelectInstance(instanceID)

    -- EJ_GetEncounterInfoByIndex returns:
    --   name, description, journalEncounterID, rootSectionID, link,
    --   journalInstanceID, dungeonEncounterID, ...
    -- We need BOTH IDs:
    --   * dungeonEncounterID  — the gameplay ENCOUNTER_END id (sent to Session)
    --   * journalEncounterID  — the EJ id required by EJ_SelectEncounter
    local bossList = {}
    local bossKeyed = {}
    local order = 1
    while true do
        local name, _, journalEncounterID, _, _, _, dungeonEncounterID =
            EJ_GetEncounterInfoByIndex(order, instanceID)
        if not name then break end
        if not dungeonEncounterID or dungeonEncounterID == 0 then
            -- Some EJ entries (intro events, council "encounters") have no
            -- dungeonEncounterID — skip them so we never try to fire an
            -- ENCOUNTER_END with a bogus id.
            order = order + 1
        else
            local boss = {
                encounterID        = dungeonEncounterID,
                journalEncounterID = journalEncounterID,
                name               = name,
                order              = order,
                items              = nil,  -- loot loaded lazily via LoadBossLoot()
            }
            bossList[#bossList + 1] = boss
            bossKeyed[dungeonEncounterID] = boss
            order = order + 1
        end
    end

    if #bossList == 0 then return nil end

    -- Attach instanceName / tierName from the ListRaids metadata so
    -- consumers (panel, slash output) can render human-readable labels.
    local raidInfo
    for _, r in ipairs(self:ListRaids()) do
        if r.instanceID == instanceID then raidInfo = r; break end
    end

    local raid = {
        instanceID   = instanceID,
        instanceName = raidInfo and raidInfo.instanceName or "(unknown)",
        tierName     = raidInfo and raidInfo.tierName     or "(unknown)",
        tierIndex    = raidInfo and raidInfo.tierIndex,
        bosses       = bossKeyed,
        bossList     = bossList,
    }
    self.cachedRaidsByID[instanceID] = raid
    safeDebug("[Sim] LoadRaid:", raid.instanceName, "(tier=", raid.tierName, ", bosses=", #bossList, ")")
    return raid
end

--- Instance ID of the latest raid (most recent tier, last entry in that tier).
function Simulator:GetLatestRaidID()
    local raids = self:ListRaids()
    return raids[1] and raids[1].instanceID or nil
end

--- The instance ID the user (or default) has currently selected for firing.
function Simulator:GetSelectedRaidID()
    return self.selectedRaidID or self:GetLatestRaidID()
end

--- Change the active raid. Invalidates the single-raid cache + any currently
--- selected boss is cleared (the caller is responsible for reflecting that
--- in the UI, since the selection lives in the panel mixin).
function Simulator:SelectRaid(instanceID)
    if instanceID == self.selectedRaidID then return false end
    self.selectedRaidID = instanceID
    self.cachedRaid = nil  -- LoadCurrentRaid will re-resolve next call
    self:TriggerEvent("OnSelectedRaidChanged", instanceID)
    safeDebug("[Sim] Selected raid:", tostring(instanceID))
    return true
end

--- Build a cached descriptor of the currently-selected raid (defaults to
--- the latest available). Kept as the canonical entry point for
--- ResolveBoss/ListBosses/etc. so the rest of the module doesn't need to
--- know about the multi-raid cache.
--- @return table|nil { instanceID, instanceName, tierName, bosses (id->boss), bossList (ordered) }
function Simulator:LoadCurrentRaid()
    if self.cachedRaid then return self.cachedRaid end

    if not ensureEJLoaded() then
        safePrint("[Sim] Encounter Journal unavailable — cannot resolve raid list.")
        return nil
    end

    local id = self:GetSelectedRaidID()
    if not id then return nil end

    self.cachedRaid = self:LoadRaid(id)
    return self.cachedRaid
end

function Simulator:RefreshTier()
    self.cachedRaid = nil
    self.cachedRaidsByID = {}
    self._cachedRaidsList = nil
end

--- Lazily fetch the EJ loot list for a boss, caching it on the boss table.
--- Pre-2.0.20 this filtered to weapons+armor (class 2/4) to dodge the
--- old hardcoded blacklist in Session.lua. With the configurable
--- loot.filter.* settings + Loot Picker UI, the user's filter (or the
--- picker's per-item override) decides what goes through — so we let
--- everything through at the EJ stage.
function Simulator:LoadBossLoot(boss)
    if boss.items then return boss.items end
    if not ensureEJLoaded() then
        boss.items = {}
        return boss.items
    end
    if not boss.journalEncounterID then
        boss.items = {}
        return boss.items
    end

    EJ_SelectEncounter(boss.journalEncounterID)

    -- Clear any sticky EJ class/spec filter for the duration of this
    -- read. Otherwise trinkets / off-class tokens / spec-restricted
    -- items are silently dropped from the loot list the sim sees.
    -- The read is pcall-wrapped so any EJ read error ALWAYS restores
    -- the user's filter (without pcall, an error leaked the cleared
    -- filter into the player's live Encounter Journal UI permanently).
    local priorClassID, priorSpecID = pushEJLootFilter()

    local items = {}
    local ok, err = pcall(function()
        local n = (EJ_GetNumLoot and EJ_GetNumLoot()) or 0
        for i = 1, n do
            local lootInfo
            if C_EncounterJournal and C_EncounterJournal.GetLootInfoByIndex then
                lootInfo = C_EncounterJournal.GetLootInfoByIndex(i)
            end
            if lootInfo and lootInfo.itemID then
                -- Kick off the item cache load so HandleTradable's quality
                -- check (which parses the |c color code) sees a fully
                -- decorated link by the time we inject it. EJ's lootInfo.link
                -- often lacks the color code on first read, which would make
                -- Utils.GetItemQuality return 0.
                if C_Item and C_Item.RequestLoadItemDataByID then
                    C_Item.RequestLoadItemDataByID(lootInfo.itemID)
                end
                items[#items + 1] = {
                    itemID = lootInfo.itemID,
                }
            end
        end
    end)

    popEJLootFilter(priorClassID, priorSpecID)

    if not ok then
        safeDebug("[Sim] LoadBossLoot error:", tostring(err))
        items = {}
    end

    boss.items = items
    safeDebug("[Sim] LoadBossLoot:", boss.name, "loot=", #items)
    return items
end

function Simulator:ResolveBoss(token)
    local raid = self:LoadCurrentRaid()
    if not raid then return nil end

    if not token or token == "" or token == "random" then
        if #raid.bossList == 0 then return nil end
        return raid.bossList[math.random(#raid.bossList)]
    end

    local id = tonumber(token)
    if id and raid.bosses[id] then
        return raid.bosses[id]
    end

    local lc = tostring(token):lower()
    for _, boss in ipairs(raid.bossList) do
        if boss.name:lower():find(lc, 1, true) then
            return boss
        end
    end
    return nil
end

function Simulator:ListBosses()
    local raid = self:LoadCurrentRaid()
    if not raid then return {} end
    local out = {}
    for _, boss in ipairs(raid.bossList) do
        out[#out + 1] = { id = boss.encounterID, name = boss.name, order = boss.order }
    end
    return out
end

function Simulator:GetCurrentRaidName()
    local raid = self:LoadCurrentRaid()
    if not raid then return "(unknown)" end
    return raid.instanceName or "(unnamed)"
end

--[[--------------------------------------------------------------------
    Item + looter generation
----------------------------------------------------------------------]]

local function makeLink(itemID)
    local TestData = ns.TestData
    if TestData and TestData.Utils and TestData.Utils.CreateItemLink then
        return TestData.Utils.CreateItemLink(itemID)
    end
    return string.format("|cffa335ee|Hitem:%d::::::::80:::::|h[Test Item %d]|h|r", itemID, itemID)
end

--- Resolve an itemID to a fully decorated link (with quality color).
--- Prefers the cached C_Item.GetItemInfo link; falls back to a synthetic
--- epic-colored link so the quality check passes even on cold items.
local function resolveLink(itemID)
    if not itemID then return nil end
    if C_Item and C_Item.GetItemInfo then
        local _, link = C_Item.GetItemInfo(itemID)
        if link and link:find("|c") then
            return link
        end
    end
    return makeLink(itemID)
end

function Simulator:GenerateItemsForBoss(boss, count)
    count = count or DEFAULT_ITEMS_PER_KILL
    local items = {}

    -- Fetch current raid loot from the Encounter Journal (cached per boss).
    local pool = boss and self:LoadBossLoot(boss) or {}

    if #pool == 0 then
        -- Defensive fallback: a few well-known modern IDs so the simulator
        -- still produces *something* if EJ returns nothing for this boss
        -- (rare, but possible during pre-release / PTR builds).
        pool = { 212405, 212450, 212460, 212470, 212480, 212502, 212504, 212506 }
    end

    -- Randomised pick without duplicates. The old cyclic `pool[i %% N]`
    -- selection always returned items 1..count in EJ order, which meant
    -- trinkets (typically at positions 10+ of an EJ loot list) never
    -- dropped at default `count = 3`. Shuffle a copy so every item is
    -- equally likely.
    local shuffled = {}
    for i = 1, #pool do shuffled[i] = pool[i] end
    for i = #shuffled, 2, -1 do
        local j = math.random(i)
        shuffled[i], shuffled[j] = shuffled[j], shuffled[i]
    end

    for i = 1, count do
        -- Wrap once shuffled is exhausted (when user asks for count > #pool)
        local entry = shuffled[((i - 1) % #shuffled) + 1]
        local itemID = type(entry) == "table" and entry.itemID or entry
        items[#items + 1] = resolveLink(itemID)
    end
    return items
end

function Simulator:GetCouncil()
    return (ns.TestMode and ns.TestMode.fakeCouncilMembers) or {}
end

--- Get the simulator's full fake raid roster (or the council as a fallback).
function Simulator:GetRosterPool()
    if self.fakeRaiders and #self.fakeRaiders > 0 then
        return self.fakeRaiders
    end
    return self:GetCouncil()
end

function Simulator:PickLooter(token)
    local pool = self:GetRosterPool()

    if token and token ~= "" then
        local lc = tostring(token):lower()
        if lc == "random" then
            -- fall through to random pick
        elseif lc == "self" or lc == "player" or lc == "me" then
            return Utils.GetPlayerFullName()
        else
            for _, m in ipairs(pool) do
                if m.name:lower():find(lc, 1, true) then
                    return m.name
                end
            end
            return token  -- Pass through arbitrary supplied name
        end
    end

    if #pool == 0 then return Utils.GetPlayerFullName() end
    return pool[math.random(#pool)].name
end

--[[--------------------------------------------------------------------
    Fake Raid Generation + Roster Hook
----------------------------------------------------------------------]]

local function uniqueName(used)
    -- Generate a name that hasn't been used yet
    for _ = 1, 50 do
        local prefix = FAKE_NAME_PREFIXES[math.random(#FAKE_NAME_PREFIXES)]
        local suffix = FAKE_NAME_SUFFIXES[math.random(#FAKE_NAME_SUFFIXES)]
        local name = prefix .. suffix
        if not used[name] then
            used[name] = true
            return name
        end
    end
    -- Last-resort numeric suffix to guarantee uniqueness
    local fallback = "Sim" .. tostring(math.random(10000, 99999))
    used[fallback] = true
    return fallback
end

--- Generate a fake raid roster with realistic class spread.
--- Returns the new roster (also stored on self.fakeRaiders).
--- The first slot is the player themselves (so the ML appears in the raid).
function Simulator:GenerateFakeRaid(count)
    count = math.max(2, math.min(40, tonumber(count) or DEFAULT_RAID_SIZE))

    local realm = GetNormalizedRealmName() or "TestRealm"
    local used = {}

    -- Slot 1: real player so we can be both ML and raider
    local _, playerClassFile = Loolib.SecretUtil.SafeUnitClass("player")
    playerClassFile = playerClassFile or "WARRIOR"
    local playerLocalized
    for _, c in ipairs(FAKE_CLASS_POOL) do
        if c.class == playerClassFile then playerLocalized = c.localized; break end
    end

    local roster = {
        {
            name = Utils.GetPlayerFullName(),
            shortName = Loolib.SecretUtil.SafeUnitName("player") or "Player",
            rank = 2,                       -- raid leader
            subgroup = 1,
            level = 80,
            class = playerLocalized or "Warrior",
            classFile = playerClassFile,
            online = true,
            isDead = false,
            role = "DAMAGER",
            isMasterLooter = true,
        },
    }

    for i = 2, count do
        local cls = FAKE_CLASS_POOL[math.random(#FAKE_CLASS_POOL)]
        local short = uniqueName(used)
        roster[#roster + 1] = {
            name      = short .. "-" .. realm,
            shortName = short,
            rank      = (i <= 6) and 1 or 0,           -- first 5 are assistants
            subgroup  = math.ceil((i - 1) / 5),         -- 5 per subgroup
            level     = 80,
            class     = cls.localized,
            classFile = cls.class,
            online    = true,
            isDead    = false,
            role      = cls.role,
            isMasterLooter = false,
        }
    end

    self.fakeRaiders = roster
    safeDebug("[Sim] GenerateFakeRaid:", #roster, "members")
    return roster
end

--- Hook TestMode.GetFakeRaidRoster so Utils.GetRaidRoster() returns our raid.
function Simulator:HookRaidRoster()
    if self.rosterHooked then return end
    if not ns.TestMode then return end

    self._origGetFakeRaidRoster = ns.TestMode.GetFakeRaidRoster
    ns.TestMode.GetFakeRaidRoster = function(_self)
        if Simulator.fakeRaiders and #Simulator.fakeRaiders > 0 then
            return Simulator.fakeRaiders
        end
        if Simulator._origGetFakeRaidRoster then
            return Simulator._origGetFakeRaidRoster(_self)
        end
        return {}
    end
    self.rosterHooked = true
end

function Simulator:UnhookRaidRoster()
    if not self.rosterHooked then return end
    if ns.TestMode and self._origGetFakeRaidRoster then
        ns.TestMode.GetFakeRaidRoster = self._origGetFakeRaidRoster
    end
    self._origGetFakeRaidRoster = nil
    self.rosterHooked = false
end

--[[--------------------------------------------------------------------
    Auto-respond: populate candidates with random responses + rolls
----------------------------------------------------------------------]]

local function pickWeightedResponse()
    local total = 0
    for _, w in ipairs(RESPONSE_WEIGHTS) do total = total + w.weight end
    local roll = math.random(total)
    local acc = 0
    for _, w in ipairs(RESPONSE_WEIGHTS) do
        acc = acc + w.weight
        if roll <= acc then return w.value end
    end
    return RESPONSE_WEIGHTS[1].value
end

--- Populate `item` with one Candidate per fake raider, each with a random
--- response. The ML (player) is included so the voting UI shows them too.
function Simulator:PopulateCandidates(item)
    if not item then return end
    if not item.GetCandidateManager then return end

    local cm = item:GetCandidateManager()
    if not cm and item.candidateManager == nil then
        item.candidateManager = ns.CreateCandidateManager()
        cm = item.candidateManager
    end
    if not cm then return end

    local roster = self:GetRosterPool()
    if #roster == 0 then return end

    local rollSettings = Loothing.Settings and Loothing.Settings:Get("rollFrame.rollRange")
    local rollMin = (rollSettings and rollSettings.min) or 1
    local rollMax = (rollSettings and rollSettings.max) or 100

    local added = 0
    for _, member in ipairs(roster) do
        local candidate = cm:GetOrCreateCandidate(member.name, member.classFile or "WARRIOR")
        if candidate and not candidate:HasResponded() then
            local response = pickWeightedResponse()
            candidate:SetResponse(response, nil)
            candidate:SetRoll(math.random(rollMin, rollMax), rollMin, rollMax)
            added = added + 1
        end
    end

    if added > 0 then
        safeDebug("[Sim] PopulateCandidates:", item.itemLink or "?", "candidates=", added)
        if Loothing.Session and Loothing.Session.TriggerEvent then
            Loothing.Session:TriggerEvent("OnCandidateUpdated", item)
        end
    end
end

--- Re-populate candidates for every item in the active session (manual trigger).
function Simulator:RespondAll()
    if not Loothing.Session or not Loothing.Session.items then
        safePrint("[Sim] No active session.")
        return false
    end
    local n = 0
    for _, item in Loothing.Session.items:Enumerate() do
        self:PopulateCandidates(item)
        n = n + 1
    end
    safePrint(string.format("[Sim] Re-populated candidates on %d item(s).", n))
    return true
end

--[[--------------------------------------------------------------------
    Firing kills
----------------------------------------------------------------------]]

function Simulator:FireKill(boss, items, looters)
    if not self.state.active then
        safePrint("Simulator not active. Use /lt sim on first.")
        return false
    end
    if not boss then
        safePrint("No boss provided to FireKill.")
        return false
    end
    if not Loothing.Session then
        safePrint("Session module not loaded.")
        return false
    end

    -- Mutex: refuse to fire a new kill on top of an active session, an
    -- open picker, or a kill that's still mid-dispatch. Without this the
    -- nested timers below smash each other and `lootBuffer` gets
    -- partially wiped from under the in-flight injection.
    if self._firing then
        safePrint("[Sim] A kill is already in flight; ignoring this one.")
        return false
    end
    if Loothing.Session.state and Loothing.Session.state ~= Loothing.SessionState.INACTIVE then
        safePrint("[Sim] A loot session is already active; end it first.")
        return false
    end
    if ns.LootPickerFrame and ns.LootPickerFrame.IsShown
        and ns.LootPickerFrame:IsShown() then
        safePrint("[Sim] Loot Picker is open; cancel/start it first.")
        return false
    end

    items = items or {}
    self.state.currentKill = boss
    self._firing = true
    local gen = self._gen

    safePrint(string.format("[Sim] Firing kill: %s (id=%d, items=%d)",
        boss.name, boss.encounterID, #items))

    -- Mirror the real ENCOUNTER_START -> ENCOUNTER_END dispatch chain
    -- (Core/Init.lua:1042-1052). Calling the handlers directly is the same
    -- entry point Blizzard's event dispatch uses. pcall-wrap so a handler
    -- error can't leave `_firing` stuck true forever.
    if Loothing.Session.OnEncounterStart then
        local ok, err = pcall(Loothing.Session.OnEncounterStart, Loothing.Session,
            boss.encounterID, boss.name, DEFAULT_DIFFICULTY, DEFAULT_GROUP_SIZE)
        if not ok then
            safeDebug("[Sim] OnEncounterStart error:", tostring(err))
            self._firing = false
            return false
        end
    end

    C_Timer.After(0.1, function()
        if not self:_isCurrent(gen) then self._firing = false; return end

        local ok, err = pcall(Loothing.Session.OnEncounterEnd, Loothing.Session,
            boss.encounterID, boss.name, DEFAULT_DIFFICULTY, DEFAULT_GROUP_SIZE, 1)
        if not ok then
            safeDebug("[Sim] OnEncounterEnd error:", tostring(err))
            self._firing = false
            return
        end

        -- After OnEncounterEnd has cached lastEligibleEncounter and started
        -- the bag scan, inject items via HandleTradable. This mirrors what
        -- the bag scanner does at Data/Session.lua:2317 when it finds new
        -- tradable items.
        C_Timer.After(0.2, function()
            if not self:_isCurrent(gen) then self._firing = false; return end
            for i, link in ipairs(items) do
                local looter = (looters and looters[i]) or self:PickLooter()
                pcall(Loothing.Session.HandleTradable, Loothing.Session, {
                    itemLink = link,
                    timeRemaining = DEFAULT_TRADE_TIME,
                    playerName = looter,
                })
            end
            self._firing = false
        end)
    end)

    return true
end

function Simulator:FireKillForBoss(token, count, looterToken)
    local boss = self:ResolveBoss(token)
    if not boss then
        safePrint("Unknown boss: " .. tostring(token) .. ". Try /lt sim list.")
        return false
    end
    count = tonumber(count) or DEFAULT_ITEMS_PER_KILL
    local items = self:GenerateItemsForBoss(boss, count)
    local looters
    if looterToken and looterToken ~= "" then
        looters = {}
        for i = 1, count do looters[i] = self:PickLooter(looterToken) end
    end
    return self:FireKill(boss, items, looters)
end

--[[--------------------------------------------------------------------
    Loot drops (mid-session or pre-session injection)
----------------------------------------------------------------------]]

function Simulator:AddLoot(itemToken, looterToken)
    if not self.state.active then
        safePrint("Simulator not active.")
        return false
    end
    if not itemToken or itemToken == "" then
        safePrint("Usage: /lt sim loot <itemLink|id> [looter]")
        return false
    end
    if not Loothing.Session then return false end

    local link = itemToken
    local id = tonumber(itemToken)
    if id then link = makeLink(id) end

    local looter = self:PickLooter(looterToken)
    Loothing.Session:HandleTradable({
        itemLink = link,
        timeRemaining = DEFAULT_TRADE_TIME,
        playerName = looter,
    })
    safePrint(string.format("[Sim] Added loot: %s (looter=%s)", link, looter))
    return true
end

--[[--------------------------------------------------------------------
    Queue
----------------------------------------------------------------------]]

function Simulator:QueueKill(token, count, looterToken)
    local boss = self:ResolveBoss(token)
    if not boss then
        safePrint("Unknown boss: " .. tostring(token))
        return false
    end
    count = tonumber(count) or DEFAULT_ITEMS_PER_KILL
    local items = self:GenerateItemsForBoss(boss, count)
    local looters
    if looterToken and looterToken ~= "" then
        looters = {}
        for i = 1, count do looters[i] = self:PickLooter(looterToken) end
    end

    table.insert(self.queue, {
        encounter = boss,
        items = items,
        looters = looters,
        itemCount = count,
    })
    self:TriggerEvent("OnQueueChanged", self.queue)
    safePrint(string.format("[Sim] Queued kill: %s (%d items). Queue size: %d",
        boss.name, count, #self.queue))
    return true
end

function Simulator:RemoveQueueEntry(index)
    if not self.queue[index] then return false end
    local entry = table.remove(self.queue, index)
    self:TriggerEvent("OnQueueChanged", self.queue)
    safePrint(string.format("[Sim] Removed queued kill: %s", entry.encounter.name))
    return true
end

function Simulator:ClearQueue()
    if #self.queue == 0 then return end
    wipe(self.queue)
    self:TriggerEvent("OnQueueChanged", self.queue)
end

function Simulator:GetQueue()
    return self.queue
end

function Simulator:FireNext()
    local entry = table.remove(self.queue, 1)
    if not entry then
        safePrint("[Sim] Queue empty.")
        return false
    end
    self:TriggerEvent("OnQueueChanged", self.queue)
    return self:FireKill(entry.encounter, entry.items, entry.looters)
end

function Simulator:Flush(delay)
    delay = tonumber(delay) or FLUSH_DELAY_DEFAULT
    if #self.queue == 0 then
        safePrint("[Sim] Queue empty.")
        return false
    end
    safePrint(string.format("[Sim] Flushing %d queued kills (every %ds)...", #self.queue, delay))

    -- Staleness guard like every other deferred closure in this file:
    -- without it, /lt sim off mid-flush left the chain ticking, draining
    -- the queue into FireKill's "Simulator not active" error each tick.
    local gen = self._gen
    local function fireNextWithDelay()
        if not self:_isCurrent(gen) then return end
        if #self.queue == 0 then return end
        self:FireNext()
        C_Timer.After(delay, fireNextWithDelay)
    end
    fireNextWithDelay()
    return true
end

function Simulator:SetAutoFire(enabled)
    self.state.autoFireNext = not not enabled
    self:TriggerEvent("OnAutofireChanged", self.state.autoFireNext)
    safePrint(string.format("[Sim] Autofire: %s", self.state.autoFireNext and "ON" or "OFF"))
end

function Simulator:IsAutoFire()
    return self.state.autoFireNext == true
end

--[[--------------------------------------------------------------------
    Lifecycle helpers
----------------------------------------------------------------------]]

function Simulator:EndSession()
    if not Loothing.Session then return false end
    if Loothing.Session.state == Loothing.SessionState.INACTIVE then
        safePrint("[Sim] No active session.")
        return false
    end
    Loothing.Session:EndSession()
    safePrint("[Sim] Session ended.")
    return true
end

function Simulator:Reset()
    if Loothing.Session and Loothing.Session.state ~= Loothing.SessionState.INACTIVE then
        Loothing.Session:EndSession()
    end
    self:ClearQueue()
    self:Disable()
    safePrint("[Sim] Reset complete.")
end

function Simulator:Status()
    local sessActive = Loothing.Session
        and Loothing.Session.state ~= Loothing.SessionState.INACTIVE
    safePrint(string.format("[Sim] Active=%s  Autofire=%s  Session=%s  Queue=%d",
        tostring(self.state.active), tostring(self.state.autoFireNext),
        tostring(sessActive), #self.queue))
end

--[[--------------------------------------------------------------------
    Slash dispatch
----------------------------------------------------------------------]]

local function parseArgs(rest)
    local out = {}
    for token in tostring(rest or ""):gmatch("%S+") do
        out[#out + 1] = token
    end
    return out
end

function Simulator:HandleCommand(rest)
    local args = parseArgs(rest)
    local cmd = (args[1] or ""):lower()

    if cmd == "" or cmd == "help" then
        return self:PrintHelp()
    elseif cmd == "on" or cmd == "enable" then
        local force = (args[2] or ""):lower() == "force"
        return self:Enable(force)
    elseif cmd == "off" or cmd == "disable" then
        return self:Disable()
    elseif cmd == "status" then
        return self:Status()
    elseif cmd == "panel" then
        -- Loothing.UI is rebuilt during PLAYER_LOGIN (Core/Init.lua:401), so
        -- look up the mixin via ns directly rather than Loothing.UI.
        local Panel = ns.SimulatorPanelMixin or (Loothing.UI and Loothing.UI.SimulatorPanel)
        if Panel and Panel.Toggle then
            Panel:Toggle()
        else
            safePrint("[Sim] Panel not loaded.")
        end
        return
    elseif cmd == "list" or cmd == "bosses" then
        return self:PrintBosses()
    elseif cmd == "raid" then
        local n = tonumber(args[2]) or DEFAULT_RAID_SIZE
        self:GenerateFakeRaid(n)
        safePrint(string.format("[Sim] Fake raid regenerated: %d members.",
            self.fakeRaiders and #self.fakeRaiders or 0))
        return
    elseif cmd == "respond" then
        return self:RespondAll()
    elseif cmd == "autorespond" then
        local v = (args[2] or ""):lower()
        self.autoRespond = (v == "on" or v == "true" or v == "yes" or v == "1")
        safePrint("[Sim] Auto-respond: " .. (self.autoRespond and "ON" or "OFF"))
        return
    elseif cmd == "kill" then
        return self:FireKillForBoss(args[2], args[3], args[4])
    elseif cmd == "loot" then
        return self:AddLoot(args[2], args[3])
    elseif cmd == "queue" then
        return self:QueueKill(args[2], args[3], args[4])
    elseif cmd == "next" then
        return self:FireNext()
    elseif cmd == "flush" then
        return self:Flush(args[2])
    elseif cmd == "autofire" then
        local val = (args[2] or ""):lower()
        return self:SetAutoFire(val == "on" or val == "true" or val == "yes" or val == "1")
    elseif cmd == "end" or cmd == "stop" then
        return self:EndSession()
    elseif cmd == "reset" then
        return self:Reset()
    end

    safePrint("[Sim] Unknown subcommand: " .. cmd .. ". Try /lt sim help.")
end

function Simulator:PrintHelp()
    safePrint("Simulator commands:")
    safePrint("  /lt sim on [force] / off / status")
    safePrint("  /lt sim panel             - Toggle Simulator UI panel")
    safePrint("  /lt sim list              - List bosses for current raid tier")
    safePrint("  /lt sim raid [N]          - (Re)generate a fake raid of N (default 20)")
    safePrint("  /lt sim respond           - Re-populate candidates+responses on active items")
    safePrint("  /lt sim autorespond on|off- Auto-populate candidates on item add")
    safePrint("  /lt sim kill [boss] [N] [looter]   - Fire a kill + N items")
    safePrint("  /lt sim loot <link|id> [looter]    - Add loot to current session")
    safePrint("  /lt sim queue [boss] [N] [looter]  - Queue a kill")
    safePrint("  /lt sim next              - Fire next queued kill now")
    safePrint("  /lt sim flush [delay]     - Fire all queued kills back-to-back")
    safePrint("  /lt sim autofire on|off   - Toggle auto-fire on session end")
    safePrint("  /lt sim end               - End current session cleanly")
    safePrint("  /lt sim reset             - Drain queue + end session + disable")
end

function Simulator:PrintBosses()
    local raid = self:LoadCurrentRaid()
    if not raid then
        safePrint("[Sim] Could not resolve current raid from the Encounter Journal.")
        return
    end
    safePrint(string.format("Current raid: %s (tier: %s)",
        raid.instanceName or "?", raid.tierName or "?"))
    for _, b in ipairs(self:ListBosses()) do
        safePrint(string.format("  [%d] %s  (id=%d)", b.order, b.name, b.id))
    end
end

-- Initialize on load
Simulator:OnLoad()
