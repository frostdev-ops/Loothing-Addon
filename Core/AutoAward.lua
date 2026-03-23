--[[--------------------------------------------------------------------
    Loothing - Loot Council Addon for WoW 12.0+
    AutoAward - Automatically award items below quality threshold
----------------------------------------------------------------------]]

local _, ns = ...
local Loolib = LibStub("Loolib")
local Loothing = ns.Addon
local L = ns.Locale
local Utils = ns.Utils

--[[--------------------------------------------------------------------
    AutoAwardMixin
----------------------------------------------------------------------]]

ns.AutoAwardMixin = ns.AutoAwardMixin or {}
local AutoAwardMixin = ns.AutoAwardMixin

--- Initialize the auto-award system
function AutoAwardMixin:Init()
    self.pendingAwards = {}
end

--- Check if an item should be auto-awarded based on settings
-- @param itemLink string - Full item link
-- @return boolean - True if item qualifies for auto-award
function AutoAwardMixin:ShouldAutoAward(itemLink)
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
    local itemInfo = Utils.GetItemInfo(itemLink)
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
function AutoAwardMixin:GetAutoAwardTarget()
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
    return Utils.NormalizeName(target)
end

--- Find the designated disenchanter in the raid
-- Priority:
--   1. Check settings for explicit disenchanter name
--   2. Scan raid for players with "DE" or "Disenchanter" in their notes
--   3. Query online guild members with Enchanting profession
-- @return string|nil - Disenchanter name or nil
function AutoAwardMixin:FindDisenchanter()
    -- 1. Check if there's a specific disenchanter set in settings
    local settings = Loothing.Settings:Get("autoAward")
    if settings and settings.disenchanter and settings.disenchanter ~= "" then
        -- Verify they're in the raid
        if self:IsPlayerInRaid(settings.disenchanter) then
            return Utils.NormalizeName(settings.disenchanter)
        end
    end

    -- 2. Scan raid notes for "DE" or "Disenchanter"
    local numMembers = GetNumGroupMembers()
    if numMembers > 0 then
        local isRaid = IsInRaid()
        for i = 1, numMembers do
            local unit = isRaid and ("raid" .. i) or ("party" .. i)
            if UnitExists(unit) then
                local name = Loolib.SecretUtil.SafeUnitName(unit, true)
                local note = ""

                -- Get player's raid note if available
                if isRaid then
                    local _, _, _, _, _, _, _, publicNote = Loolib.SecretUtil.SafeGetRaidRosterInfo(i)
                    note = publicNote or ""
                end

                -- Check for DE/Disenchanter keyword (skip if name is secret/nil)
                if name then
                    local lowerNote = note:lower()
                    if lowerNote:find("disenchant") or lowerNote:find(" de ") or
                       lowerNote:find("^de ") or lowerNote:find(" de$") or lowerNote == "de" then
                        return Utils.NormalizeName(name)
                    end
                end
            end
        end
    end

    -- 3. Check guild roster for enchanters (if we're in a guild)
    if IsInGuild() then
        local numGuildMembers = GetNumGuildMembers()
        for i = 1, numGuildMembers do
            local name, _, _, _, _, _, publicNote, _, isOnline = Loothing.GetGuildRosterInfo(i)
            if isOnline and name then
                local lowerNote = (publicNote or ""):lower()
                if lowerNote:find("enchant") or lowerNote:find(" de ") or lowerNote == "de" then
                    -- Verify they're in our raid
                    if self:IsPlayerInRaid(name) then
                        return Utils.NormalizeName(name)
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
function AutoAwardMixin:IsPlayerInRaid(playerName)
    if not playerName then return false end

    local normalized = Utils.NormalizeName(playerName)
    local numMembers = GetNumGroupMembers()

    if numMembers == 0 then
        -- Solo, check if it's us
        local myName = Loolib.SecretUtil.SafeUnitName("player")
        if not myName then return false end
        return normalized == Utils.NormalizeName(myName)
    end

    local isRaid = IsInRaid()
    for i = 1, numMembers do
        local unit = isRaid and ("raid" .. i) or ("party" .. i)
        if UnitExists(unit) then
            local name = Loolib.SecretUtil.SafeUnitName(unit, true)
            if name and Utils.NormalizeName(name) == normalized then
                return true
            end
        end
    end

    return false
end

-- Reusable tooltip for scanning (created once, reused)
local scanTooltip

local function TooltipContainsText(tooltip, targetText)
    if not tooltip or not targetText then
        return false
    end

    for _, region in ipairs({ tooltip:GetRegions() }) do
        if region and region.GetObjectType and region:GetObjectType() == "FontString" then
            local text = region:GetText()
            if text and text:find(targetText, 1, true) then
                return true
            end
        end
    end

    return false
end

--- Check if an item is Bind on Equip
-- @param itemLink string - Full item link
-- @return boolean - True if item is BoE
function AutoAwardMixin:IsBindOnEquip(itemLink)
    if not itemLink then return false end

    -- Use Blizzard's localized constant (works on all locales)
    local BOE_TEXT = ITEM_BIND_ON_EQUIP

    -- Create tooltip once, reuse it
    if not scanTooltip then
        scanTooltip = CreateFrame("GameTooltip", nil, UIParent, "GameTooltipTemplate")
    end
    scanTooltip:SetOwner(UIParent, "ANCHOR_NONE")
    scanTooltip:ClearLines()
    scanTooltip:SetHyperlink(itemLink)

    if TooltipContainsText(scanTooltip, BOE_TEXT) then
        scanTooltip:Hide()
        return true
    end

    scanTooltip:Hide()
    return false
end

--- Process an item when it's looted
-- Called from the loot handling system
-- @param itemLink string - Full item link
-- @param itemGUID string - Item GUID
-- @return boolean - True if item was auto-awarded
function AutoAwardMixin:ProcessItem(itemLink, itemGUID)
    -- Dedup guard: prevent awarding the same item twice from redundant events
    if self.pendingAwards[itemGUID] then
        Loothing:Debug("AutoAward: skipping duplicate for", itemGUID)
        return false
    end

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
        Loothing:Print(string.format(L["AUTO_AWARD_TARGET_NOT_IN_RAID"], target))
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
function AutoAwardMixin:AwardItem(itemLink, itemGUID, targetPlayer)
    if not Loothing.Session or not Loothing.Session:IsActive() then return false end

    -- Get the structured reason from settings
    local reasonId = Loothing.Settings:GetAutoAwardReasonId()
    local reasonText = nil
    if reasonId then
        local reason = Loothing.Settings:GetAwardReasonById(reasonId)
        reasonText = reason and reason.name or nil
    end

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
        -- Mark as pending before awarding to prevent re-entry from duplicate events
        self.pendingAwards[itemGUID] = true
        Loothing.Session:AwardItem(sessionItem.id, targetPlayer, nil, reasonId, reasonText)

        -- Log the auto-award
        Loothing:Print(string.format(L["ITEM_AWARDED"], itemLink, targetPlayer))

        return true
    end

    return false
end

--- Get quality name from quality level
-- @param quality number - Quality level (0-7)
-- @return string - Quality name
function AutoAwardMixin:GetQualityName(quality)
    local names = {
        [0] = L["QUALITY_POOR"],
        [1] = L["QUALITY_COMMON"],
        [2] = L["QUALITY_UNCOMMON"],
        [3] = L["QUALITY_RARE"],
        [4] = L["QUALITY_EPIC"],
        [5] = L["QUALITY_LEGENDARY"],
        [6] = L["QUALITY_ARTIFACT"],
        [7] = L["QUALITY_HEIRLOOM"],
    }
    return names[quality] or L["QUALITY_UNKNOWN"]
end

--[[--------------------------------------------------------------------
    Factory
----------------------------------------------------------------------]]

ns.CreateAutoAward = ns.CreateAutoAward or function()
    local autoAward = Loolib.CreateFromMixins(AutoAwardMixin)
    autoAward:Init()
    return autoAward
end
