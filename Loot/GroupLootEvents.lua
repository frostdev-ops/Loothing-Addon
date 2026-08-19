--[[--------------------------------------------------------------------
    Loothing - Group Loot Events
    Event registration and roll handling entry point.

    WoW 12.0 event landscape for loot rolls:
      START_LOOT_ROLL (rollID, rollTime)       — roll window opens
      LOOT_ITEM_ROLL_WON (itemLink, qty, ...)  — winner's client only, fires
                                                 at ~T+30s when roll resolves
                                                 (AlertFrames.lua:473 is the
                                                  stock Blizzard consumer)
      ENCOUNTER_LOOT_RECEIVED                  — fires for any encounter-
                                                 distributed item per
                                                 BossBannerToast.lua:183.
                                                 In 12.0 practice this is
                                                 primarily personal-loot
                                                 drops — group-loot roll
                                                 wins are resolved via
                                                 C_LootHistory and route
                                                 through LOOT_ITEM_ROLL_WON
                                                 on the winner's client.
      LOOT_HISTORY_UPDATE_DROP                 — modern per-drop state
                                                 stream; richer than
                                                 LOOT_ITEM_ROLL_WON but
                                                 not currently hooked.

    Key insight: group-loot wins arrive in the ML's bag ~30s after
    ENCOUNTER_END (the roll window equals our old bag-scan window, so the
    scan consistently raced the delivery). LOOT_ITEM_ROLL_WON fires on the
    winner's client the moment the roll resolves — feeding straight into
    the session buffer avoids the 30s timing race and the link-drift bugs
    in bag-slot matching.
----------------------------------------------------------------------]]

local _, ns = ...
local Loothing = ns.Addon
local Utils = ns.Utils
local CreateFrame = CreateFrame
local GetLootRollItemLink = GetLootRollItemLink
local IsInGroup = IsInGroup
local RollOnLoot = RollOnLoot

ns.GroupLootMixin = ns.GroupLootMixin or {}
ns.GroupLootRoll = ns.GroupLootRoll or {}

local GroupLootMixin = ns.GroupLootMixin
local GroupLootRoll = ns.GroupLootRoll

--- Enable the group loot handler. Registers for:
---   START_LOOT_ROLL      — drives auto-roll behavior
---   LOOT_ITEM_ROLL_WON   — drives ML-self item detection (fires on winner)
function GroupLootMixin:Enable()
    if not self.eventFrame then
        self.eventFrame = CreateFrame("Frame")
        self.eventFrame:SetScript("OnEvent", function(_, event, ...)
            if event == "START_LOOT_ROLL" then
                self:OnStartLootRoll(event, ...)
            elseif event == "LOOT_ITEM_ROLL_WON" then
                self:OnLootItemRollWon(event, ...)
            end
        end)
    end

    self.eventFrame:RegisterEvent("START_LOOT_ROLL")
    self.eventFrame:RegisterEvent("LOOT_ITEM_ROLL_WON")
end

local function GetItemID(itemLink)
    if itemLink and C_Item and C_Item.GetItemInfoInstant then
        return C_Item.GetItemInfoInstant(itemLink)
    end
    return nil
end

--- Disable the group loot handler.
function GroupLootMixin:Disable()
    if self.eventFrame then
        self.eventFrame:UnregisterEvent("START_LOOT_ROLL")
        self.eventFrame:UnregisterEvent("LOOT_ITEM_ROLL_WON")
    end
end

--- Handle LOOT_ITEM_ROLL_WON event — fires on the winning client the moment
--- a group-loot roll resolves (typically ~30s after START_LOOT_ROLL, i.e.
--- right at the edge of the post-encounter bag-scan window).
---
--- This is the authoritative event for "you just won a group-loot item";
--- the itemLink is already in the payload, the item is landing in the bag
--- right now, and we don't have to scan bags or guess trade time. When the
--- winning client is the ML (or has handleLoot=true), route the win into
--- the session pipeline directly via HandleTradable's self-loopback shape.
---
--- @param _event string
--- @param itemLink string - Full hyperlink of the won item
--- @param rollQuantity number - 1 for most items; >1 for stackables
--- @param rollType number - 1=NEED, 2=GREED, 4=TRANSMOG (matches GroupLootRoll)
--- @param roll number - The roll value the player got
--- @param _upgraded any - Upgrade-track / bonus info (unused here)
function GroupLootMixin:OnLootItemRollWon(_event, itemLink, rollQuantity, rollType, roll, _upgraded)
    if not itemLink or itemLink == "" then return end

    -- Gate: accept the win when THIS client is canonically the ML, full
    -- stop. The previous gate also required `Loothing.handleLoot` which
    -- opened a race: during a `GROUP_ROSTER_UPDATE` that fires while rolls
    -- are resolving, `PerformMLCheck` can briefly clear `isMasterLooter`
    -- as it re-verifies, and a roll that resolves in that exact tick
    -- would silently drop. We ship the event through if ANY canonical ML
    -- signal says we are the ML — `IsCanonicalML` reads settings-level
    -- designated ML, leader-designated ML, and raid leader fallback.
    -- `handleLoot` is a local state flag that `IsCanonicalML` does not
    -- require; the council session logic downstream re-gates on it when
    -- it actually matters.
    local Session = Loothing.Session
    local isML = (Loothing.IsCanonicalML and Loothing:IsCanonicalML())
        or (Session and Session.IsMasterLooter and Session:IsMasterLooter())
        or Loothing.isMasterLooter
    if not isML then
        Loothing:Debug("LOOT_ITEM_ROLL_WON: not ML, ignoring",
            itemLink, "(roll", tostring(roll) .. ")")
        return
    end

    local session = Loothing.Session
    if not session then return end

    Loothing:Debug("LOOT_ITEM_ROLL_WON: ML win via rollType", tostring(rollType),
        itemLink, "(roll", tostring(roll) .. ")")

    -- Route through the canonical buffer-or-add pathway so item flow is
    -- identical to a bag-scan discovery: HandleTradable adds to an active
    -- session (with batching) if one exists, else buffers for the picker.
    -- playerName = self — this is our own win.
    --
    -- timeRemaining=0 is harmless: the buffer path (inactive session) does
    -- not read it; the active-session path stores it on the item and a
    -- subsequent bag scan will update it once the tooltip resolver reads
    -- the trade line.
    --
    -- LOOT_ITEM_ROLL_WON does not include the rollID or encounterID, and
    -- START_LOOT_ROLL context cannot be matched back unambiguously for
    -- duplicate items. Leave encounterID nil so HandleTradable treats this as
    -- encounterless loot instead of borrowing stale boss state.
    local itemID = GetItemID(itemLink)

    local ok, err = pcall(session.HandleTradable, session, {
        itemLink      = itemLink,
        itemID        = itemID,
        timeRemaining = 0,
        playerName    = Utils.GetPlayerFullName(),
        rollType      = rollType,
        quantity      = rollQuantity,
        source        = "roll_won",       -- diagnostic breadcrumb
    })
    if not ok then
        Loothing:Error("LOOT_ITEM_ROLL_WON: HandleTradable threw for",
            itemLink, "err=", tostring(err),
            "— falling back to bag-scan backstop (60s window)")
        return
    end

    -- Do not seed reportedTradeableItems here. The follow-up bag scan may be
    -- the first path with a real tooltip trade time; HandleTradable treats
    -- that bag-scan result as a refresh for the roll-won row instead of a
    -- second physical item.
end

--- Handle START_LOOT_ROLL event.
-- @param event string - Event name
-- @param rollID number - The roll ID for this loot item
function GroupLootMixin:OnStartLootRoll(_, rollID)
    local rolls = GroupLootRoll

    if not Loothing.Settings:Get("groupLoot.enabled") then
        return
    end

    if Utils.GetEffectiveGroupLootMode() == "passive" then
        Loothing:Debug("Group loot passive mode active — skipping auto-roll for rollID", rollID)
        return
    end

    if not IsInGroup() then
        return
    end

    -- Auto-roll when ML is handling loot (session active or MLDB signals it).
    -- Loothing.handleLoot is the ML-local flag (true only on the ML's client).
    -- Non-ML clients check the MLDB handleLoot field instead. If the field is
    -- absent (older ML version), MLDB presence alone signals handling for
    -- backward compatibility; handleLoot=false explicitly disables auto-roll.
    --
    -- An EXPLICIT off always wins — even mid-session. SetHandleLoot(false)
    -- deliberately preserves the session (soft toggle) and re-broadcasts
    -- mldb.handleLoot=false precisely so clients stop auto-rolling; the old
    -- `sessionActive OR handling` gate kept auto-rolling on every client
    -- whenever a session was active, overriding the user's toggle.
    local mldb = Loothing.MLDB and Loothing.MLDB:Get()
    if Loothing.isMasterLooter then
        -- Our own toggle is authoritative on the ML's client.
        if not Loothing.handleLoot then
            return
        end
    elseif mldb and mldb.handleLoot == false then
        -- The ML explicitly disabled handling; don't auto-pass to them.
        return
    end

    local sessionActive = Loothing.Session and Loothing.Session:IsActive()
    local mlHandling = Loothing.handleLoot
    if not mlHandling and mldb and mldb.handleLoot ~= false then
        mlHandling = true
    end
    if not sessionActive and not mlHandling then
        return
    end

    -- Instance type gate: never auto-pass in dungeons, keystones, LFR,
    -- PvP, scenarios, or open world — even if handleLoot somehow got set.
    -- Without this check, players in keystones pass all loot to the ML.
    if not Utils.IsEligibleForLootHandling() then
        return
    end

    local link = GetLootRollItemLink(rollID)
    if not link then
        return
    end

    local rollInfo = Loothing.GetLootRollItemData(rollID)
    if not rollInfo then
        return
    end

    local quality = rollInfo.quality
    local canNeed = rollInfo.canNeed
    local canTransmog = rollInfo.canTransmog

    -- Skip below threshold
    local qualityThreshold = Loothing.Settings:Get("groupLoot.qualityThreshold") or Enum.ItemQuality.Epic
    if quality and quality < qualityThreshold then
        return
    end

    -- Skip legendary items - let player decide manually
    if quality and quality >= Enum.ItemQuality.Legendary then
        return
    end

    local isMasterLooter = Loothing:IsCanonicalML()
    local rollType

    if isMasterLooter then
        if canNeed then
            rollType = rolls.NEED
        elseif canTransmog then
            rollType = rolls.TRANSMOG
        else
            rollType = rolls.GREED
        end
    else
        rollType = rolls.PASS
        Loothing:Debug("Auto-passing group loot roll for ML collection:", link)
    end

    self.pendingRolls[rollID] = {
        link = link,
        rollType = rollType,
        timestamp = time(),
    }

    C_Timer.After(0.05, function()
        RollOnLoot(rollID, rollType)
        self:HideGroupLootFrame(rollID)
        self:LogRoll(rollID, link, rollType, isMasterLooter)
    end)
end
