--[[--------------------------------------------------------------------
    Loothing - Group Loot Events
    Event registration and roll handling entry point.

    WoW 12.0 event landscape for loot rolls:
      START_LOOT_ROLL (rollID, rollTime)       — roll window opens
      LOOT_ITEM_ROLL_WON (itemLink, qty, ...)  — winner's client only, fires
                                                 at ~T+30s when roll resolves
      ENCOUNTER_LOOT_RECEIVED                  — personal loot ONLY; does NOT
                                                 fire for group-loot wins
                                                 (BossBannerToast.lua:183 is
                                                  the sole Blizzard consumer)

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
local time = time

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

    -- Gate: we only care when this client is acting as ML and is handling
    -- loot. Non-ML wins (e.g., legendary rolls where Loothing deliberately
    -- stays out, or quality-gated items below threshold) remain the user's
    -- personal drop and should not enter a council session.
    local isML = Loothing.handleLoot and (Loothing.isMasterLooter
        or (Loothing.Session and Loothing.Session:IsMasterLooter())
        or (Loothing.IsCanonicalML and Loothing:IsCanonicalML()))
    if not isML then
        Loothing:Debug("LOOT_ITEM_ROLL_WON: not ML/handleLoot, ignoring",
            itemLink, "(roll", tostring(roll) .. ")")
        return
    end

    local session = Loothing.Session
    if not session then return end

    Loothing:Debug("LOOT_ITEM_ROLL_WON: ML win via rollType", tostring(rollType),
        itemLink, "(roll", tostring(roll) .. ")")

    -- Route through the canonical buffer-or-add pathway so item flow is
    -- identical to a bag-scan discovery: HandleTradable dedupes, adds to
    -- active session (with batching) if one exists, else buffers for the
    -- picker. playerName = self — this is our own win.
    --
    -- timeRemaining=0 is harmless: the buffer path (inactive session) does
    -- not read it; the active-session path stores it on the item and a
    -- subsequent bag scan will update it once the tooltip resolver reads
    -- the trade line.
    --
    -- Derive itemID once so HandleTradable's matcher can hit the identity
    -- branch (rather than falling back to raw-link equality which is
    -- unreliable for post-roll links). C_Item.GetItemInfoInstant is
    -- synchronous and cache-warm immediately after LOOT_ITEM_ROLL_WON.
    local itemID
    if C_Item and C_Item.GetItemInfoInstant then
        itemID = C_Item.GetItemInfoInstant(itemLink)
    end

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

    -- Seed the bag-scan dedup table so the post-encounter ticker doesn't
    -- re-buffer this item when it finds the same itemID in the bag on the
    -- next tick. Without this, the ML would see two picker rows for a
    -- single roll win (one from the event, one from the next bag scan).
    if itemID and session.reportedTradeableItems then
        session.reportedTradeableItems[itemID] = true
    end
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
    local sessionActive = Loothing.Session and Loothing.Session:IsActive()
    local mlHandling = Loothing.handleLoot
    if not mlHandling and Loothing.MLDB then
        local mldb = Loothing.MLDB:Get()
        if mldb and mldb.handleLoot ~= false then
            mlHandling = true
        end
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
