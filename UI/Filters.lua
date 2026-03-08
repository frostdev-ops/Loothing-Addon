--[[--------------------------------------------------------------------
    Loothing - Loot Council Addon for WoW 12.0+
    Filters - Filter system for candidate display
----------------------------------------------------------------------]]

local Loolib = LibStub("Loolib")

-- Reusable tooltip for item scanning - created once, reused via ClearLines()
local filterTooltip

local function GetFilterTooltip()
    if not filterTooltip then
        filterTooltip = CreateFrame("GameTooltip", "LoothingFilterTooltip", UIParent, "GameTooltipTemplate")
        filterTooltip:SetOwner(UIParent, "ANCHOR_NONE")
    end
    return filterTooltip
end

--[[--------------------------------------------------------------------
    LoothingFiltersMixin
----------------------------------------------------------------------]]

LoothingFiltersMixin = LoolibCreateFromMixins(LoolibCallbackRegistryMixin)

local FILTER_EVENTS = {
    "OnFiltersChanged",
}

--- Initialize the filters module
function LoothingFiltersMixin:Init()
    LoolibCallbackRegistryMixin.OnLoad(self)
    self:GenerateCallbackEvents(FILTER_EVENTS)
end

--[[--------------------------------------------------------------------
    Filter Logic
----------------------------------------------------------------------]]

--- Check if a candidate should be shown based on current filters
-- @param candidateData table - Candidate data { name, class, response, guildRank, ... }
-- @param itemData table - Item data { itemLink, ... }
-- @return boolean - True if candidate passes all filters
function LoothingFiltersMixin:ShouldShowCandidate(candidateData, itemData)
    if not candidateData then
        return false
    end

    -- Get filter settings
    local settings = Loothing.Settings
    if not settings:GetFiltersEnabled() then
        return true
    end

    -- Class filter
    local classFilters = settings:GetClassFilters()
    if classFilters and next(classFilters) then
        if not candidateData.classFile or not classFilters[candidateData.classFile] then
            return false
        end
    end

    -- Response filter
    local responseFilters = settings:GetResponseFilters()
    if responseFilters and next(responseFilters) then
        if not candidateData.response or not responseFilters[candidateData.response] then
            return false
        end
    end

    -- Guild rank filter
    local rankFilters = settings:GetGuildRankFilters()
    if rankFilters and next(rankFilters) then
        if not candidateData.guildRank or not rankFilters[candidateData.guildRank] then
            return false
        end
    end

    -- Hide passed items
    if settings:GetHidePassedItems() then
        if candidateData.response == LOOTHING_RESPONSE.PASS then
            return false
        end
    end

    -- Show only equippable
    if settings:GetShowOnlyEquippable() and itemData then
        if not self:CanEquipItem(candidateData, itemData) then
            return false
        end
    end

    return true
end

--- Check if a candidate can equip an item
-- Uses C_Item APIs to check class/spec restrictions, armor type, and weapon proficiency
-- @param candidateData table - Candidate data (needs classID field)
-- @param itemData table - Item data (needs itemLink field)
-- @return boolean
function LoothingFiltersMixin:CanEquipItem(candidateData, itemData)
    if not candidateData or not itemData or not itemData.itemLink then
        return true  -- Default to true if we can't determine
    end

    -- Get item info
    local itemInfo = LoothingUtils.GetItemInfo(itemData.itemLink)
    if not itemInfo then
        return true
    end

    local candidateClassID = candidateData.classID
    if not candidateClassID then
        return true  -- Can't determine class, allow
    end

    -- Check explicit class restrictions on the item
    local classRestrictions = self:GetItemClassRestrictions(itemData.itemLink)
    if classRestrictions and #classRestrictions > 0 then
        local classAllowed = false
        for _, allowedClassID in ipairs(classRestrictions) do
            if allowedClassID == candidateClassID then
                classAllowed = true
                break
            end
        end
        if not classAllowed then
            return false
        end
    end

    -- Check armor type restrictions
    if itemInfo.itemClassID == Enum.ItemClass.Armor and itemInfo.itemSubClass then
        if not self:CanClassWearArmorType(candidateClassID, itemInfo.itemSubClass) then
            return false
        end
    end

    -- Check weapon type restrictions
    if itemInfo.itemClassID == Enum.ItemClass.Weapon and itemInfo.itemSubClass then
        if not self:CanClassUseWeaponType(candidateClassID, itemInfo.itemSubClass) then
            return false
        end
    end

    -- Check trinket spec restrictions using TrinketData
    if itemInfo.itemEquipLoc == "INVTYPE_TRINKET" and LoothingTrinketData then
        if not LoothingTrinketData:CanClassUse(itemInfo.itemID, candidateClassID) then
            return false
        end
    end

    return true
end

--- Get class restrictions from item tooltip
-- @param itemLink string - Item link
-- @return table|nil - Array of class IDs that can use the item, or nil if unrestricted
function LoothingFiltersMixin:GetItemClassRestrictions(itemLink)
    if not itemLink then return nil end

    -- Reuse the file-scope tooltip; clear previous content before scanning
    local tooltip = GetFilterTooltip()
    tooltip:ClearLines()
    tooltip:SetHyperlink(itemLink)

    local restrictions = nil

    for i = 1, tooltip:NumLines() do
        local line = _G["LoothingFilterTooltipTextLeft" .. i]
        if line then
            local text = line:GetText()
            if text and text:find("^Classes:") then
                restrictions = {}
                -- Parse the class names
                local classNames = text:gsub("Classes:%s*", "")
                for className in classNames:gmatch("([^,]+)") do
                    className = className:match("^%s*(.-)%s*$")  -- Trim
                    local classID = self:GetClassIDByName(className)
                    if classID then
                        restrictions[#restrictions + 1] = classID
                    end
                end
                break
            end
        end
    end

    tooltip:Hide()
    return restrictions
end

--- Get class ID by localized class name
-- @param className string - Localized class name
-- @return number|nil - Class ID or nil
function LoothingFiltersMixin:GetClassIDByName(className)
    if not className then return nil end
    local upperName = className:upper()

    for classID = 1, 13 do
        local info = C_CreatureInfo.GetClassInfo(classID)
        if info and info.className:upper() == upperName then
            return classID
        end
    end
    return nil
end

--- Check if a class can wear an armor type
-- @param classID number - Class ID (1-13)
-- @param armorSubClass number - Armor sub-class from itemInfo
-- @return boolean
function LoothingFiltersMixin:CanClassWearArmorType(classID, armorSubClass)
    -- Armor sub-classes: 0=Generic, 1=Cloth, 2=Leather, 3=Mail, 4=Plate, 5=Cosmetic, 6=Shield
    -- Skip generic, cosmetic, and shields (handled separately)
    if armorSubClass == 0 or armorSubClass == 5 then
        return true
    end

    -- Shield check (Paladin, Warrior, Shaman only)
    if armorSubClass == 6 then
        return classID == 2 or classID == 1 or classID == 7  -- Paladin, Warrior, Shaman
    end

    -- Armor type by class (at max level):
    -- Plate (4): Warrior (1), Paladin (2), Death Knight (6)
    -- Mail (3): Hunter (3), Shaman (7), Evoker (13)
    -- Leather (2): Rogue (4), Druid (11), Monk (10), Demon Hunter (12)
    -- Cloth (1): Priest (5), Mage (8), Warlock (9)

    local armorByClass = {
        [1] = 4,  -- Warrior = Plate
        [2] = 4,  -- Paladin = Plate
        [3] = 3,  -- Hunter = Mail
        [4] = 2,  -- Rogue = Leather
        [5] = 1,  -- Priest = Cloth
        [6] = 4,  -- Death Knight = Plate
        [7] = 3,  -- Shaman = Mail
        [8] = 1,  -- Mage = Cloth
        [9] = 1,  -- Warlock = Cloth
        [10] = 2, -- Monk = Leather
        [11] = 2, -- Druid = Leather
        [12] = 2, -- Demon Hunter = Leather
        [13] = 3, -- Evoker = Mail
    }

    local classArmorType = armorByClass[classID]
    if not classArmorType then
        return true  -- Unknown class, allow
    end

    -- Classes can only equip their armor type (not lower for primary stats)
    return armorSubClass == classArmorType
end

--- Check if a class can use a weapon type
-- @param classID number - Class ID (1-13)
-- @param weaponSubClass number - Weapon sub-class from itemInfo
-- @return boolean
function LoothingFiltersMixin:CanClassUseWeaponType(classID, weaponSubClass)
    -- Weapon sub-classes:
    -- 0=1H Axe, 1=2H Axe, 2=Bows, 3=Guns, 4=1H Mace, 5=2H Mace
    -- 6=Polearm, 7=1H Sword, 8=2H Sword, 9=Warglaives, 10=Staves
    -- 13=Fist, 14=Misc, 15=Daggers, 16=Thrown, 18=Crossbow, 19=Wands, 20=Fishing

    -- This is a simplified check - WoW's actual weapon restrictions are complex
    -- For now, we trust the game's equip restrictions and only filter obvious cases
    local weaponRestrictions = {
        [9] = { [12] = true },  -- Warglaives: DH only
        [19] = { [5] = true, [8] = true, [9] = true },  -- Wands: Priest, Mage, Warlock
    }

    local restrictions = weaponRestrictions[weaponSubClass]
    if restrictions then
        return restrictions[classID] == true
    end

    return true  -- Allow by default
end

--- Get filtered list of candidates
-- @param allCandidates table - Array of all candidates
-- @param itemData table - Item data (optional)
-- @return table - Filtered array of candidates
function LoothingFiltersMixin:GetFilteredCandidates(allCandidates, itemData)
    if not allCandidates then
        return {}
    end

    local filtered = {}
    for _, candidate in ipairs(allCandidates) do
        if self:ShouldShowCandidate(candidate, itemData) then
            filtered[#filtered + 1] = candidate
        end
    end

    return filtered
end

--- Get count of active filters
-- @return number - Number of active filters
function LoothingFiltersMixin:GetActiveFilterCount()
    local settings = Loothing.Settings
    if not settings:GetFiltersEnabled() then
        return 0
    end

    local count = 0

    local classFilters = settings:GetClassFilters()
    if classFilters and next(classFilters) then
        count = count + 1
    end

    local responseFilters = settings:GetResponseFilters()
    if responseFilters and next(responseFilters) then
        count = count + 1
    end

    local rankFilters = settings:GetGuildRankFilters()
    if rankFilters and next(rankFilters) then
        count = count + 1
    end

    if settings:GetShowOnlyEquippable() then
        count = count + 1
    end

    if settings:GetHidePassedItems() then
        count = count + 1
    end

    return count
end

--[[--------------------------------------------------------------------
    UI Creation
----------------------------------------------------------------------]]

--- Create filter bar UI
-- @param parent Frame - Parent frame
-- @return Frame - Filter bar frame
function LoothingFiltersMixin:CreateFilterBar(parent)
    local L = LOOTHING_LOCALE

    local filterBar = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    filterBar:SetHeight(80)
    filterBar:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        tileSize = 8,
        edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 }
    })
    filterBar:SetBackdropColor(0.05, 0.05, 0.05, 0.9)
    filterBar:SetBackdropBorderColor(0.4, 0.4, 0.4, 1.0)

    -- Title
    local title = filterBar:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 10, -10)
    title:SetText(L["FILTERS"])

    -- Active filter count
    local activeCount = filterBar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    activeCount:SetPoint("LEFT", title, "RIGHT", 10, 0)
    activeCount:SetTextColor(0.7, 0.7, 0.7)
    filterBar.activeCount = activeCount

    -- Row 1: Class and Response filters
    local yOffset = -35

    -- Class filter button
    local classButton = CreateFrame("Button", nil, filterBar, "UIPanelButtonTemplate")
    classButton:SetSize(120, 22)
    classButton:SetPoint("TOPLEFT", 10, yOffset)
    classButton:SetText(L["FILTER_BY_CLASS"])
    classButton:SetScript("OnClick", function()
        self:ShowClassFilterMenu(classButton)
    end)
    filterBar.classButton = classButton

    -- Response filter button
    local responseButton = CreateFrame("Button", nil, filterBar, "UIPanelButtonTemplate")
    responseButton:SetSize(130, 22)
    responseButton:SetPoint("LEFT", classButton, "RIGHT", 5, 0)
    responseButton:SetText(L["FILTER_BY_RESPONSE"])
    responseButton:SetScript("OnClick", function()
        self:ShowResponseFilterMenu(responseButton)
    end)
    filterBar.responseButton = responseButton

    -- Guild rank filter button
    local rankButton = CreateFrame("Button", nil, filterBar, "UIPanelButtonTemplate")
    rankButton:SetSize(140, 22)
    rankButton:SetPoint("LEFT", responseButton, "RIGHT", 5, 0)
    rankButton:SetText(L["FILTER_BY_RANK"])
    rankButton:SetScript("OnClick", function()
        self:ShowRankFilterMenu(rankButton)
    end)
    filterBar.rankButton = rankButton

    -- Clear filters button
    local clearButton = CreateFrame("Button", nil, filterBar, "UIPanelButtonTemplate")
    clearButton:SetSize(100, 22)
    clearButton:SetPoint("TOPRIGHT", -10, yOffset)
    clearButton:SetText(L["CLEAR_FILTERS"])
    clearButton:SetScript("OnClick", function()
        Loothing.Settings:ClearAllFilters()
        self:TriggerEvent("OnFiltersChanged")
        self:UpdateFilterBar(filterBar)
    end)
    filterBar.clearButton = clearButton

    -- Row 2: Checkboxes
    yOffset = yOffset - 30

    -- Show only equippable checkbox
    local equippableCheck = CreateFrame("CheckButton", nil, filterBar, "UICheckButtonTemplate")
    equippableCheck:SetPoint("TOPLEFT", 10, yOffset)
    equippableCheck:SetSize(22, 22)
    equippableCheck.text = equippableCheck:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    equippableCheck.text:SetPoint("LEFT", equippableCheck, "RIGHT", 5, 0)
    equippableCheck.text:SetText(L["SHOW_EQUIPPABLE_ONLY"])
    equippableCheck:SetChecked(Loothing.Settings:GetShowOnlyEquippable())
    equippableCheck:SetScript("OnClick", function(self)
        Loothing.Settings:SetShowOnlyEquippable(self:GetChecked())
        LoothingFiltersMixin:TriggerEvent("OnFiltersChanged")
        LoothingFiltersMixin:UpdateFilterBar(filterBar)
    end)
    filterBar.equippableCheck = equippableCheck

    -- Hide passed items checkbox
    local passedCheck = CreateFrame("CheckButton", nil, filterBar, "UICheckButtonTemplate")
    passedCheck:SetPoint("LEFT", equippableCheck.text, "RIGHT", 20, 0)
    passedCheck:SetSize(22, 22)
    passedCheck.text = passedCheck:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    passedCheck.text:SetPoint("LEFT", passedCheck, "RIGHT", 5, 0)
    passedCheck.text:SetText(L["HIDE_PASSED_ITEMS"])
    passedCheck:SetChecked(Loothing.Settings:GetHidePassedItems())
    passedCheck:SetScript("OnClick", function(self)
        Loothing.Settings:SetHidePassedItems(self:GetChecked())
        LoothingFiltersMixin:TriggerEvent("OnFiltersChanged")
        LoothingFiltersMixin:UpdateFilterBar(filterBar)
    end)
    filterBar.passedCheck = passedCheck

    -- Update display
    self:UpdateFilterBar(filterBar)

    return filterBar
end

--- Update filter bar display
-- @param filterBar Frame - Filter bar frame
function LoothingFiltersMixin:UpdateFilterBar(filterBar)
    if not filterBar then return end

    local L = LOOTHING_LOCALE
    local count = self:GetActiveFilterCount()

    if count > 0 then
        filterBar.activeCount:SetText(string.format(L["FILTERS_ACTIVE"], count))
        filterBar.activeCount:Show()
    else
        filterBar.activeCount:Hide()
    end

    -- Update checkboxes
    if filterBar.equippableCheck then
        filterBar.equippableCheck:SetChecked(Loothing.Settings:GetShowOnlyEquippable())
    end

    if filterBar.passedCheck then
        filterBar.passedCheck:SetChecked(Loothing.Settings:GetHidePassedItems())
    end
end

--[[--------------------------------------------------------------------
    Filter Menus
----------------------------------------------------------------------]]

--- Show class filter menu
-- @param anchor Frame - Anchor frame for menu
function LoothingFiltersMixin:ShowClassFilterMenu(anchor)
    local L = LOOTHING_LOCALE
    local settings = Loothing.Settings
    local classFilters = settings:GetClassFilters()

    MenuUtil.CreateContextMenu(anchor, function(ownerRegion, rootDescription)
        -- Add "All Classes" option
        rootDescription:CreateCheckbox(L["ALL_CLASSES"],
            function() return not next(classFilters) end,
            function()
                settings:SetClassFilters({})
                self:TriggerEvent("OnFiltersChanged")
                self:UpdateFilterBar(anchor:GetParent())
            end
        )

        rootDescription:CreateDivider()

        -- Add each class
        local classes = {
            "WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST",
            "DEATHKNIGHT", "SHAMAN", "MAGE", "WARLOCK", "MONK",
            "DRUID", "DEMONHUNTER", "EVOKER"
        }

        for _, classFile in ipairs(classes) do
            local className = classFile:sub(1, 1) .. classFile:sub(2):lower()
            rootDescription:CreateCheckbox(className,
                function() return classFilters[classFile] == true end,
                function()
                    if classFilters[classFile] then
                        settings:RemoveClassFilter(classFile)
                    else
                        settings:AddClassFilter(classFile)
                    end
                    self:TriggerEvent("OnFiltersChanged")
                    self:UpdateFilterBar(anchor:GetParent())
                end
            )
        end
    end)
end

--- Show response filter menu
-- @param anchor Frame - Anchor frame for menu
function LoothingFiltersMixin:ShowResponseFilterMenu(anchor)
    local L = LOOTHING_LOCALE
    local settings = Loothing.Settings
    local responseFilters = settings:GetResponseFilters()

    MenuUtil.CreateContextMenu(anchor, function(ownerRegion, rootDescription)
        -- Add "All Responses" option
        rootDescription:CreateCheckbox(L["ALL_RESPONSES"],
            function() return not next(responseFilters) end,
            function()
                settings:SetResponseFilters({})
                self:TriggerEvent("OnFiltersChanged")
                self:UpdateFilterBar(anchor:GetParent())
            end
        )

        rootDescription:CreateDivider()

        -- Add each response type
        for responseId, responseInfo in pairs(LOOTHING_RESPONSE_INFO) do
            rootDescription:CreateCheckbox(L[responseInfo.name] or responseInfo.name,
                function() return responseFilters[responseId] == true end,
                function()
                    if responseFilters[responseId] then
                        settings:RemoveResponseFilter(responseId)
                    else
                        settings:AddResponseFilter(responseId)
                    end
                    self:TriggerEvent("OnFiltersChanged")
                    self:UpdateFilterBar(anchor:GetParent())
                end
            )
        end
    end)
end

--- Show guild rank filter menu
-- @param anchor Frame - Anchor frame for menu
function LoothingFiltersMixin:ShowRankFilterMenu(anchor)
    local L = LOOTHING_LOCALE
    local settings = Loothing.Settings
    local rankFilters = settings:GetGuildRankFilters()

    MenuUtil.CreateContextMenu(anchor, function(ownerRegion, rootDescription)
        -- Add "All Ranks" option
        rootDescription:CreateCheckbox(L["ALL_RANKS"],
            function() return not next(rankFilters) end,
            function()
                settings:SetGuildRankFilters({})
                self:TriggerEvent("OnFiltersChanged")
                self:UpdateFilterBar(anchor:GetParent())
            end
        )

        rootDescription:CreateDivider()

        -- Get guild ranks
        local numRanks = GuildControlGetNumRanks()
        if numRanks and numRanks > 0 then
            for i = 1, numRanks do
                local rankName = GuildControlGetRankName(i)
                if rankName then
                    rootDescription:CreateCheckbox(rankName,
                        function() return rankFilters[i] == true end,
                        function()
                            if rankFilters[i] then
                                settings:RemoveGuildRankFilter(i)
                            else
                                settings:AddGuildRankFilter(i)
                            end
                            self:TriggerEvent("OnFiltersChanged")
                            self:UpdateFilterBar(anchor:GetParent())
                        end
                    )
                end
            end
        else
            local btn = rootDescription:CreateButton("Not in guild")
            btn:SetEnabled(false)
        end
    end)
end
