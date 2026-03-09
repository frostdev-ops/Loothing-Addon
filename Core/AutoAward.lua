--[[--------------------------------------------------------------------
    Loothing - Loot Council Addon for WoW 12.0+
    AutoAward - Automatically award items below quality threshold
----------------------------------------------------------------------]]

local Loolib = LibStub("Loolib")

--[[--------------------------------------------------------------------
    LoothingAutoAwardMixin
----------------------------------------------------------------------]]

LoothingAutoAwardMixin = {}

--- Initialize the auto-award system
function LoothingAutoAwardMixin:Init()
    self.pendingAwards = {}
end

--- Check if an item should be auto-awarded based on settings
-- @param itemLink string - Full item link
-- @return boolean - True if item qualifies for auto-award
function LoothingAutoAwardMixin:ShouldAutoAward(itemLink)
    if not Loothing.Settings then return false end

    -- Check if auto-award is enabled
    if not Loothing.Settings:GetAutoAwardEnabled() then
        return false
    end

    -- Check if target player is set (cache for ProcessItem to reuse)
    local target = self:GetAutoAwardTarget()
    self._lastAutoAwardTarget = target
    if not target or target == "" then
        return false
    end

    -- Get item info
    local itemInfo = LoothingUtils.GetItemInfo(itemLink)
    if not itemInfo then return false end

    local quality = itemInfo.quality
    if not quality then return false end

    -- Check quality thresholds
    local lowerThreshold, upperThreshold = Loothing.Settings:GetAutoAwardThresholds()
    if quality < lowerThreshold or quality > upperThreshold then
        return false
    end

    -- Check BoE setting
    if not Loothing.Settings:GetAutoAwardIncludeBoE() then
        -- Check if item is BoE
        if self:IsBindOnEquip(itemLink) then
            return false
        end
    end

    return true
end

--- Get the player to auto-award items to
-- @return string|nil - Player name or nil
function LoothingAutoAwardMixin:GetAutoAwardTarget()
    if not Loothing.Settings then return nil end

    local target = Loothing.Settings:GetAutoAwardTo()
    if not target or target == "" then
        return nil
    end

    -- Handle special keywords
    if target:lower() == "disenchanter" then
        -- Find the designated disenchanter in raid
        return self:FindDisenchanter()
    end

    -- Normalize the player name
    return LoothingUtils.NormalizeName(target)
end

--- Find the designated disenchanter in the raid
-- Priority:
--   1. Check settings for explicit disenchanter name
--   2. Scan raid for players with "DE" or "Disenchanter" in their notes
--   3. Query online guild members with Enchanting profession
-- @return string|nil - Disenchanter name or nil
function LoothingAutoAwardMixin:FindDisenchanter()
    -- 1. Check if there's a specific disenchanter set in settings
    local settings = Loothing.Settings:Get("autoAward")
    if settings and settings.disenchanter and settings.disenchanter ~= "" then
        -- Verify they're in the raid
        if self:IsPlayerInRaid(settings.disenchanter) then
            return LoothingUtils.NormalizeName(settings.disenchanter)
        end
    end

    -- 2. Scan raid notes for "DE" or "Disenchanter"
    local numMembers = GetNumGroupMembers()
    if numMembers > 0 then
        local isRaid = IsInRaid()
        for i = 1, numMembers do
            local unit = isRaid and ("raid" .. i) or ("party" .. i)
            if UnitExists(unit) then
                local name = LoolibSecretUtil.SafeUnitName(unit, true)
                local note = ""

                -- Get player's raid note if available
                if isRaid then
                    local _, _, _, _, _, _, _, publicNote = LoolibSecretUtil.SafeGetRaidRosterInfo(i)
                    note = publicNote or ""
                end

                -- Check for DE/Disenchanter keyword (skip if name is secret/nil)
                if name then
                    local lowerNote = note:lower()
                    if lowerNote:find("disenchant") or lowerNote:find(" de ") or
                       lowerNote:find("^de ") or lowerNote:find(" de$") or lowerNote == "de" then
                        return LoothingUtils.NormalizeName(name)
                    end
                end
            end
        end
    end

    -- 3. Check guild roster for enchanters (if we're in a guild)
    if IsInGuild() then
        local numGuildMembers = GetNumGuildMembers()
        for i = 1, numGuildMembers do
            local name, _, _, _, _, _, publicNote, _, isOnline = GetGuildRosterInfo(i)
            if isOnline and name then
                local lowerNote = (publicNote or ""):lower()
                if lowerNote:find("enchant") or lowerNote:find(" de ") or lowerNote == "de" then
                    -- Verify they're in our raid
                    if self:IsPlayerInRaid(name) then
                        return LoothingUtils.NormalizeName(name)
                    end
                end
            end
        end
    end

    -- No disenchanter found
    Loothing:Debug("FindDisenchanter: No disenchanter found in raid")
    return nil
end

--- Check if a player is in the current raid/party
-- @param playerName string - Player name (with or without realm)
-- @return boolean - True if player is in group
function LoothingAutoAwardMixin:IsPlayerInRaid(playerName)
    if not playerName then return false end

    local normalized = LoothingUtils.NormalizeName(playerName)
    local numMembers = GetNumGroupMembers()

    if numMembers == 0 then
        -- Solo, check if it's us
        local myName = LoolibSecretUtil.SafeUnitName("player")
        if not myName then return false end
        return normalized == LoothingUtils.NormalizeName(myName)
    end

    local isRaid = IsInRaid()
    for i = 1, numMembers do
        local unit = isRaid and ("raid" .. i) or ("party" .. i)
        if UnitExists(unit) then
            local name = LoolibSecretUtil.SafeUnitName(unit, true)
            if name and LoothingUtils.NormalizeName(name) == normalized then
                return true
            end
        end
    end

    return false
end

-- Reusable tooltip for scanning (created once, reused)
local scanTooltip

--- Check if an item is Bind on Equip
-- @param itemLink string - Full item link
-- @return boolean - True if item is BoE
function LoothingAutoAwardMixin:IsBindOnEquip(itemLink)
    if not itemLink then return false end

    -- Use Blizzard's localized constant (works on all locales)
    local BOE_TEXT = ITEM_BIND_ON_EQUIP

    -- Create tooltip once, reuse it
    if not scanTooltip then
        scanTooltip = CreateFrame("GameTooltip", "LoothingAutoAwardTooltip", UIParent, "GameTooltipTemplate")
    end
    scanTooltip:SetOwner(UIParent, "ANCHOR_NONE")
    scanTooltip:ClearLines()
    scanTooltip:SetHyperlink(itemLink)

    -- Scan tooltip for localized BoE text
    for i = 1, scanTooltip:NumLines() do
        local line = _G["LoothingAutoAwardTooltipTextLeft" .. i]
        if line then
            local text = line:GetText()
            if text and BOE_TEXT and text:find(BOE_TEXT, 1, true) then
                scanTooltip:Hide()
                return true
            end
        end
    end

    scanTooltip:Hide()
    return false
end

--- Process an item when it's looted
-- Called from the loot handling system
-- @param itemLink string - Full item link
-- @param itemGUID string - Item GUID
-- @return boolean - True if item was auto-awarded
function LoothingAutoAwardMixin:ProcessItem(itemLink, itemGUID)
    if not self:ShouldAutoAward(itemLink) then
        return false
    end

    -- Reuse the target already resolved by ShouldAutoAward() to avoid a duplicate call
    local target = self._lastAutoAwardTarget
    if not target then
        return false
    end

    -- Check if target is in the raid
    if not self:IsPlayerInRaid(target) then
        Loothing:Print(string.format("Auto-award target %s is not in the raid", target))
        return false
    end

    -- Award the item
    return self:AwardItem(itemLink, itemGUID, target)
end

--- Award an item to a player
-- @param itemLink string - Full item link
-- @param itemGUID string - Item GUID
-- @param targetPlayer string - Player name
-- @return boolean - True if award was successful
function LoothingAutoAwardMixin:AwardItem(itemLink, itemGUID, targetPlayer)
    if not Loothing.Session then return false end

    -- Get the reason from settings
    local reason = Loothing.Settings:GetAutoAwardReason()

    -- Create a session item if one doesn't exist
    local sessionItem = Loothing.Session:FindItemByGUID(itemGUID)
    if not sessionItem then
        -- Add item to session
        sessionItem = Loothing.Session:AddItem(itemLink, itemGUID)
        if not sessionItem then
            return false
        end
    end

    -- Award the item
    if Loothing.Session.AwardItem then
        Loothing.Session:AwardItem(sessionItem.id, targetPlayer, reason)

        -- Log the auto-award
        Loothing:Print(string.format("Auto-awarded %s to %s", itemLink, targetPlayer))

        return true
    end

    return false
end

--- Get quality name from quality level
-- @param quality number - Quality level (0-7)
-- @return string - Quality name
function LoothingAutoAwardMixin:GetQualityName(quality)
    local names = {
        [0] = "Poor",
        [1] = "Common",
        [2] = "Uncommon",
        [3] = "Rare",
        [4] = "Epic",
        [5] = "Legendary",
        [6] = "Artifact",
        [7] = "Heirloom",
    }
    return names[quality] or "Unknown"
end

--[[--------------------------------------------------------------------
    Factory
----------------------------------------------------------------------]]

function CreateLoothingAutoAward()
    local autoAward = LoolibCreateFromMixins(LoothingAutoAwardMixin)
    autoAward:Init()
    return autoAward
end
