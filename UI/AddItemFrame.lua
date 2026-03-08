--[[--------------------------------------------------------------------
    Loothing - Loot Council Addon for WoW 12.0+
    AddItemFrame - Dedicated frame for adding items to a session
----------------------------------------------------------------------]]

local L = LOOTHING_LOCALE

--[[--------------------------------------------------------------------
    Item Resolution Pipeline
----------------------------------------------------------------------]]

local RESOLVE_MAX_RETRIES = 20
local RESOLVE_RETRY_DELAY = 0.05

--- Resolve an item link, item ID, or item name to a full item link.
-- Retries up to RESOLVE_MAX_RETRIES times for uncached items.
-- @param input string - Item link, numeric ID, or name
-- @param callback function - Called with (link, name, ilvl, quality, icon) on success
-- @param retries number - Internal retry counter
local function ResolveItem(input, callback, retries)
    retries = retries or 0
    if not input or input == "" then return end

    local name, link, quality, ilvl, _, _, _, _, _, icon = C_Item.GetItemInfo(input)
    if link then
        callback(link, name, ilvl or 0, quality or 0, icon)
        return
    end

    if retries < RESOLVE_MAX_RETRIES then
        C_Timer.After(RESOLVE_RETRY_DELAY, function()
            ResolveItem(input, callback, retries + 1)
        end)
    end
end

--[[--------------------------------------------------------------------
    LoothingAddItemFrameMixin
----------------------------------------------------------------------]]

LoothingAddItemFrameMixin = {}

function LoothingAddItemFrameMixin:Init()
    self.activeTab = 1
    self.resolvedLink = nil   -- Tab 1 resolved item
    self.selectedLink = nil   -- Tab 2/3 selected item
    self.bagRows = {}
    self.recentRows = {}
    self:BuildFrame()
end

function LoothingAddItemFrameMixin:BuildFrame()
    local frame = CreateFrame("Frame", "LoothingAddItemFrame", UIParent, "BackdropTemplate")
    frame:SetSize(380, 420)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("DIALOG")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function(f) f:StartMoving() end)
    frame:SetScript("OnDragStop", function(f) f:StopMovingOrSizing() end)
    frame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        tile = false, edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    frame:SetBackdropColor(0.08, 0.08, 0.08, 0.95)
    frame:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)
    frame:Hide()
    self.frame = frame

    -- Title
    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOPLEFT", 8, -8)
    title:SetText(L["ADD_ITEM_TITLE"] or "Add Item to Session")
    title:SetTextColor(1, 0.82, 0)

    -- Close button
    local closeBtn = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    closeBtn:SetSize(22, 22)
    closeBtn:SetPoint("TOPRIGHT", -2, -2)
    closeBtn:SetScript("OnClick", function() self:Hide() end)

    -- Tab separator line under title
    local sep1 = frame:CreateTexture(nil, "ARTWORK")
    sep1:SetPoint("TOPLEFT", 4, -26)
    sep1:SetPoint("TOPRIGHT", -4, -26)
    sep1:SetHeight(1)
    sep1:SetColorTexture(0.25, 0.25, 0.25, 1)

    -- Tab buttons
    local tabLabels = {
        L["ENTER_ITEM"] or "Enter Item",
        L["RECENT_DROPS"] or "Recent Drops",
        L["FROM_BAGS"] or "From Bags",
    }
    self.tabButtons = {}
    local tabW = (380 - 16) / 3
    for i, label in ipairs(tabLabels) do
        local tab = CreateFrame("Button", nil, frame, "BackdropTemplate")
        tab:SetSize(tabW, 22)
        tab:SetPoint("TOPLEFT", 8 + (i - 1) * tabW, -28)
        tab:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8x8",
            tile = false,
            insets = { left = 0, right = 0, top = 0, bottom = 0 },
        })
        tab:SetBackdropColor(0.15, 0.15, 0.15, 1)

        local txt = tab:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        txt:SetPoint("CENTER")
        txt:SetText(label)
        tab._text = txt

        tab:SetScript("OnClick", function() self:SelectTab(i) end)
        tab:SetScript("OnEnter", function(b)
            if self.activeTab ~= i then
                b:SetBackdropColor(0.2, 0.2, 0.2, 1)
            end
        end)
        tab:SetScript("OnLeave", function(b)
            if self.activeTab ~= i then
                b:SetBackdropColor(0.15, 0.15, 0.15, 1)
            end
        end)
        self.tabButtons[i] = tab
    end

    -- Tab content separator
    local sep2 = frame:CreateTexture(nil, "ARTWORK")
    sep2:SetPoint("TOPLEFT", 4, -51)
    sep2:SetPoint("TOPRIGHT", -4, -51)
    sep2:SetHeight(1)
    sep2:SetColorTexture(0.25, 0.25, 0.25, 1)

    -- Content area
    local content = CreateFrame("Frame", nil, frame)
    content:SetPoint("TOPLEFT", 8, -53)
    content:SetPoint("BOTTOMRIGHT", -8, 44)
    self.content = content

    -- Footer
    local footer = CreateFrame("Frame", nil, frame)
    footer:SetPoint("BOTTOMLEFT", 8, 8)
    footer:SetPoint("BOTTOMRIGHT", -8, 8)
    footer:SetHeight(30)

    self.addBtn = CreateFrame("Button", nil, footer, "UIPanelButtonTemplate")
    self.addBtn:SetSize(110, 24)
    self.addBtn:SetPoint("RIGHT")
    self.addBtn:SetText(L["ADD"] or "Add")
    self.addBtn:SetEnabled(false)
    self.addBtn:SetScript("OnClick", function() self:OnAddClick() end)

    local cancelBtn = CreateFrame("Button", nil, footer, "UIPanelButtonTemplate")
    cancelBtn:SetSize(80, 24)
    cancelBtn:SetPoint("RIGHT", self.addBtn, "LEFT", -4, 0)
    cancelBtn:SetText(CANCEL or "Cancel")
    cancelBtn:SetScript("OnClick", function() self:Hide() end)

    -- Build panels
    self:BuildEnterItemPanel()
    self:BuildRecentDropsPanel()
    self:BuildFromBagsPanel()

    self:SelectTab(1)
end

--[[--------------------------------------------------------------------
    Tab 1: Enter Item
----------------------------------------------------------------------]]

function LoothingAddItemFrameMixin:BuildEnterItemPanel()
    local panel = CreateFrame("Frame", nil, self.content)
    panel:SetAllPoints()
    panel:Hide()
    self.enterItemPanel = panel

    -- Hint text
    local hint = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    hint:SetPoint("TOPLEFT")
    hint:SetText(L["ENTER_ITEM_HINT"] or "Paste item link, item ID, or drag an item here")
    hint:SetTextColor(0.7, 0.7, 0.7)
    hint:SetJustifyH("LEFT")

    -- EditBox container
    local editFrame = CreateFrame("Frame", nil, panel, "BackdropTemplate")
    editFrame:SetPoint("TOPLEFT", 0, -18)
    editFrame:SetPoint("TOPRIGHT", 0, -18)
    editFrame:SetHeight(28)
    editFrame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        tile = false, edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    editFrame:SetBackdropColor(0.04, 0.04, 0.04, 1)
    editFrame:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)

    local editBox = CreateFrame("EditBox", nil, editFrame)
    editBox:SetPoint("TOPLEFT", 4, -4)
    editBox:SetPoint("BOTTOMRIGHT", -4, 4)
    editBox:SetAutoFocus(false)
    editBox:SetFontObject("ChatFontNormal")
    editBox:SetScript("OnTextChanged", function(eb)
        self:OnItemInputChanged(eb:GetText())
    end)
    editBox:SetScript("OnReceiveDrag", function()
        self:AcceptDraggedItem()
    end)
    editBox:SetScript("OnMouseDown", function()
        if GetCursorInfo() then
            self:AcceptDraggedItem()
        end
    end)
    self.editBox = editBox

    -- Drag target area
    local dragArea = CreateFrame("Button", nil, panel, "BackdropTemplate")
    dragArea:SetPoint("TOPLEFT", 0, -54)
    dragArea:SetPoint("TOPRIGHT", 0, -54)
    dragArea:SetHeight(40)
    dragArea:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        tile = false, edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    dragArea:SetBackdropColor(0.04, 0.04, 0.10, 0.8)
    dragArea:SetBackdropBorderColor(0.3, 0.3, 0.5, 1)
    dragArea:RegisterForDrag("LeftButton")
    dragArea:SetScript("OnReceiveDrag", function() self:AcceptDraggedItem() end)
    dragArea:SetScript("OnMouseDown", function()
        if GetCursorInfo() then self:AcceptDraggedItem() end
    end)

    local dragLabel = dragArea:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    dragLabel:SetPoint("CENTER")
    dragLabel:SetText(L["DRAG_ITEM_HERE"] or "Drop item here")
    dragLabel:SetTextColor(0.5, 0.5, 0.7)

    -- Item preview
    local preview = CreateFrame("Frame", nil, panel, "BackdropTemplate")
    preview:SetPoint("TOPLEFT", 0, -102)
    preview:SetPoint("TOPRIGHT", 0, -102)
    preview:SetHeight(56)
    preview:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        tile = false, edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    preview:SetBackdropColor(0.05, 0.05, 0.05, 0.9)
    preview:SetBackdropBorderColor(0.2, 0.2, 0.2, 1)
    preview:Hide()
    self.preview = preview

    local previewIcon = preview:CreateTexture(nil, "ARTWORK")
    previewIcon:SetSize(40, 40)
    previewIcon:SetPoint("LEFT", 8, 0)
    self.previewIcon = previewIcon

    local previewName = preview:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    previewName:SetPoint("TOPLEFT", previewIcon, "TOPRIGHT", 8, -4)
    previewName:SetPoint("RIGHT", -8, 0)
    previewName:SetJustifyH("LEFT")
    self.previewName = previewName

    local previewIlvl = preview:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    previewIlvl:SetPoint("BOTTOMLEFT", previewIcon, "BOTTOMRIGHT", 8, 4)
    previewIlvl:SetTextColor(0.7, 0.7, 0.7)
    self.previewIlvl = previewIlvl
end

function LoothingAddItemFrameMixin:OnItemInputChanged(text)
    self.resolvedLink = nil
    self.addBtn:SetEnabled(false)
    self.preview:Hide()
    if not text or text == "" then return end

    ResolveItem(text, function(link, name, ilvl, quality, icon)
        -- Guard: frame may have closed or input changed
        if not self.frame:IsShown() then return end
        self.resolvedLink = link
        self:ShowPreview(link, name, ilvl, quality, icon)
        if self.activeTab == 1 then
            self.addBtn:SetEnabled(true)
        end
    end)
end

function LoothingAddItemFrameMixin:AcceptDraggedItem()
    local infoType, itemID, itemLink = GetCursorInfo()
    if infoType == "item" then
        ClearCursor()
        self.editBox:SetText(itemLink or tostring(itemID))
    end
end

function LoothingAddItemFrameMixin:ShowPreview(link, name, ilvl, quality, icon)
    self.previewIcon:SetTexture(icon)
    self.previewName:SetText(name or link)

    if quality and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[quality] then
        local c = ITEM_QUALITY_COLORS[quality]
        self.previewName:SetTextColor(c.r, c.g, c.b)
    else
        self.previewName:SetTextColor(1, 1, 1)
    end

    if ilvl and ilvl > 0 then
        self.previewIlvl:SetText("iLvl " .. ilvl)
    else
        self.previewIlvl:SetText("")
    end
    self.preview:Show()
end

--[[--------------------------------------------------------------------
    Tab 2: Recent Drops
----------------------------------------------------------------------]]

function LoothingAddItemFrameMixin:BuildRecentDropsPanel()
    local panel = CreateFrame("Frame", nil, self.content)
    panel:SetAllPoints()
    panel:Hide()
    self.recentDropsPanel = panel

    local empty = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    empty:SetPoint("CENTER")
    empty:SetText(L["NO_RECENT_DROPS"] or "No recent tradeable items found")
    empty:SetTextColor(0.5, 0.5, 0.5)
    self.recentEmpty = empty

    local scroll = CreateFrame("ScrollFrame", nil, panel, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT")
    scroll:SetPoint("BOTTOMRIGHT", -20, 0)
    self.recentScroll = scroll

    local sc = CreateFrame("Frame", nil, scroll)
    sc:SetWidth(scroll:GetWidth())
    sc:SetHeight(600)
    scroll:SetScrollChild(sc)
    self.recentContent = sc
end

function LoothingAddItemFrameMixin:RefreshRecentDrops()
    for _, row in ipairs(self.recentRows) do row:Hide() end
    wipe(self.recentRows)
    self.selectedLink = nil
    self.addBtn:SetEnabled(false)

    local drops = {}

    -- Scan bags for recently looted tradeable items
    for bag = 0, NUM_BAG_SLOTS do
        local numSlots = C_Container.GetContainerNumSlots(bag)
        for slot = 1, numSlots do
            local link = C_Container.GetContainerItemLink(bag, slot)
            if link then
                local _, _, quality, ilvl = C_Item.GetItemInfo(link)
                if quality and quality >= (LOOTHING_MIN_QUALITY or 4) then
                    local timeRemaining = nil
                    if Loothing.TradeQueue and Loothing.TradeQueue.GetContainerItemTradeTimeRemaining then
                        timeRemaining = Loothing.TradeQueue:GetContainerItemTradeTimeRemaining(bag, slot)
                    end
                    -- Only show items with valid trade timers
                    if timeRemaining and timeRemaining > 0 and timeRemaining ~= math.huge then
                        local name = C_Item.GetItemInfo(link)
                        drops[#drops + 1] = {
                            link = link,
                            name = name,
                            ilvl = ilvl or 0,
                            quality = quality,
                            timeRemaining = timeRemaining,
                        }
                    end
                end
            end
        end
    end

    if #drops == 0 then
        self.recentEmpty:Show()
        self.recentScroll:Hide()
        return
    end

    self.recentEmpty:Hide()
    self.recentScroll:Show()

    local yOffset = 0
    for _, drop in ipairs(drops) do
        local row = self:CreateItemRow(self.recentContent, drop, function(data)
            self.selectedLink = data.link
            self.addBtn:SetEnabled(true)
        end)
        row:SetPoint("TOPLEFT", 0, yOffset)
        row:SetWidth(self.recentContent:GetWidth())
        row:Show()
        yOffset = yOffset - 38
        self.recentRows[#self.recentRows + 1] = row
    end
    self.recentContent:SetHeight(math.abs(yOffset) + 8)
end

--[[--------------------------------------------------------------------
    Tab 3: From Bags
----------------------------------------------------------------------]]

function LoothingAddItemFrameMixin:BuildFromBagsPanel()
    local panel = CreateFrame("Frame", nil, self.content)
    panel:SetAllPoints()
    panel:Hide()
    self.fromBagsPanel = panel

    -- Filter bar
    local equipOnly = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
    equipOnly:SetSize(20, 20)
    equipOnly:SetPoint("TOPLEFT")
    equipOnly:SetScript("OnClick", function() self:RefreshBagList() end)
    self.bagEquipOnly = equipOnly

    local equipLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    equipLabel:SetPoint("LEFT", equipOnly, "RIGHT", 2, 0)
    equipLabel:SetText(L["EQUIPMENT_ONLY"] or "Equipment Only")
    equipLabel:SetTextColor(0.8, 0.8, 0.8)

    local empty = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    empty:SetPoint("CENTER")
    empty:SetText(L["NO_BAG_ITEMS"] or "No eligible items in bags")
    empty:SetTextColor(0.5, 0.5, 0.5)
    self.bagsEmpty = empty

    local scroll = CreateFrame("ScrollFrame", nil, panel, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 0, -24)
    scroll:SetPoint("BOTTOMRIGHT", -20, 0)
    self.bagsScroll = scroll

    local sc = CreateFrame("Frame", nil, scroll)
    sc:SetWidth(scroll:GetWidth())
    sc:SetHeight(600)
    scroll:SetScrollChild(sc)
    self.bagsContent = sc
end

function LoothingAddItemFrameMixin:RefreshBagList()
    for _, row in ipairs(self.bagRows) do row:Hide() end
    wipe(self.bagRows)
    self.selectedLink = nil
    self.addBtn:SetEnabled(false)

    local equipOnly = self.bagEquipOnly and self.bagEquipOnly:GetChecked()
    local items = {}

    for bag = 0, NUM_BAG_SLOTS do
        local numSlots = C_Container.GetContainerNumSlots(bag)
        for slot = 1, numSlots do
            local link = C_Container.GetContainerItemLink(bag, slot)
            if link then
                local name, _, quality, ilvl, _, _, _, _, equipLoc = C_Item.GetItemInfo(link)
                if name and quality and quality >= 2 then
                    local isEquippable = equipLoc and equipLoc ~= "" and equipLoc ~= "INVTYPE_NON_EQUIP_IGNORE"
                    if not equipOnly or isEquippable then
                        items[#items + 1] = {
                            link = link,
                            name = name,
                            ilvl = ilvl or 0,
                            quality = quality,
                            equipLoc = equipLoc,
                        }
                    end
                end
            end
        end
    end

    if #items == 0 then
        self.bagsEmpty:Show()
        self.bagsScroll:Hide()
        return
    end

    self.bagsEmpty:Hide()
    self.bagsScroll:Show()

    local yOffset = 0
    for _, item in ipairs(items) do
        local row = self:CreateItemRow(self.bagsContent, item, function(data)
            self.selectedLink = data.link
            self.addBtn:SetEnabled(true)
        end)
        row:SetPoint("TOPLEFT", 0, yOffset)
        row:SetWidth(self.bagsContent:GetWidth())
        row:Show()
        yOffset = yOffset - 38
        self.bagRows[#self.bagRows + 1] = row
    end
    self.bagsContent:SetHeight(math.abs(yOffset) + 8)
end

--[[--------------------------------------------------------------------
    Shared Item Row
----------------------------------------------------------------------]]

function LoothingAddItemFrameMixin:CreateItemRow(parent, itemData, onSelect)
    local row = CreateFrame("Button", nil, parent, "BackdropTemplate")
    row:SetHeight(36)
    row:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        tile = false, edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    row:SetBackdropColor(0.08, 0.08, 0.08, 1)
    row:SetBackdropBorderColor(0.15, 0.15, 0.15, 1)

    -- Quality-colored left bar
    local qBar = row:CreateTexture(nil, "ARTWORK")
    qBar:SetSize(3, 34)
    qBar:SetPoint("LEFT", 1, 0)
    if itemData.quality and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[itemData.quality] then
        local c = ITEM_QUALITY_COLORS[itemData.quality]
        qBar:SetColorTexture(c.r, c.g, c.b, 1)
    else
        qBar:SetColorTexture(0.5, 0.5, 0.5, 1)
    end

    -- Icon
    local icon = row:CreateTexture(nil, "ARTWORK")
    icon:SetSize(28, 28)
    icon:SetPoint("LEFT", 6, 0)
    local _, _, _, _, _, _, _, _, _, iconTex = C_Item.GetItemInfo(itemData.link)
    if iconTex then icon:SetTexture(iconTex) end

    -- Name
    local nameText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    nameText:SetPoint("TOPLEFT", icon, "TOPRIGHT", 6, -3)
    nameText:SetPoint("TOPRIGHT", -62, -3)
    nameText:SetJustifyH("LEFT")
    nameText:SetText(itemData.name or "")
    if itemData.quality and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[itemData.quality] then
        local c = ITEM_QUALITY_COLORS[itemData.quality]
        nameText:SetTextColor(c.r, c.g, c.b)
    end

    -- iLvl
    local ilvlText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    ilvlText:SetPoint("BOTTOMLEFT", icon, "BOTTOMRIGHT", 6, 3)
    ilvlText:SetTextColor(0.7, 0.7, 0.7)
    if itemData.ilvl and itemData.ilvl > 0 then
        ilvlText:SetText("iLvl " .. itemData.ilvl)
    end

    -- Time remaining (for recent drops tab)
    if itemData.timeRemaining then
        local mins = math.floor(itemData.timeRemaining / 60)
        local secs = itemData.timeRemaining % 60
        local tText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        tText:SetPoint("RIGHT", -4, 0)
        tText:SetTextColor(1, 0.82, 0)
        tText:SetText(string.format("%d:%02d", mins, secs))
    end

    -- Hover highlight
    local hl = row:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints()
    hl:SetColorTexture(1, 1, 1, 0.05)

    row:SetScript("OnClick", function(btn)
        -- Deselect peer rows
        for _, peer in ipairs(self.bagRows) do
            if peer ~= btn then peer:SetBackdropColor(0.08, 0.08, 0.08, 1) end
        end
        for _, peer in ipairs(self.recentRows) do
            if peer ~= btn then peer:SetBackdropColor(0.08, 0.08, 0.08, 1) end
        end
        btn:SetBackdropColor(0.12, 0.12, 0.28, 1)
        if onSelect then onSelect(itemData) end
    end)

    row:SetScript("OnEnter", function(btn)
        GameTooltip:SetOwner(btn, "ANCHOR_RIGHT")
        GameTooltip:SetHyperlink(itemData.link)
        GameTooltip:Show()
    end)
    row:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    return row
end

--[[--------------------------------------------------------------------
    Tab Management
----------------------------------------------------------------------]]

function LoothingAddItemFrameMixin:SelectTab(index)
    self.activeTab = index
    self.selectedLink = nil
    self.resolvedLink = nil
    self.addBtn:SetEnabled(false)

    for i, tab in ipairs(self.tabButtons) do
        if i == index then
            tab:SetBackdropColor(0.10, 0.10, 0.28, 1)
            tab._text:SetTextColor(1, 0.82, 0)
        else
            tab:SetBackdropColor(0.15, 0.15, 0.15, 1)
            tab._text:SetTextColor(0.8, 0.8, 0.8)
        end
    end

    self.enterItemPanel:SetShown(index == 1)
    self.recentDropsPanel:SetShown(index == 2)
    self.fromBagsPanel:SetShown(index == 3)

    if index == 1 then
        self.addBtn:SetText(L["ADD"] or "Add")
    else
        self.addBtn:SetText(L["ADD_SELECTED"] or "Add Selected")
    end

    if index == 2 then
        self:RefreshRecentDrops()
    elseif index == 3 then
        self:RefreshBagList()
    end
end

--[[--------------------------------------------------------------------
    Add Action
----------------------------------------------------------------------]]

function LoothingAddItemFrameMixin:OnAddClick()
    local link = (self.activeTab == 1) and self.resolvedLink or self.selectedLink
    if not link then return end

    if not Loothing.Session then
        print("|cffff0000[Loothing]|r Session module not available.")
        return
    end

    local item = Loothing.Session:AddItem(link, UnitName("player"), nil, true)
    if item then
        self:Hide()
    else
        print("|cffff0000[Loothing]|r Failed to add item to session.")
    end
end

--[[--------------------------------------------------------------------
    Show / Hide
----------------------------------------------------------------------]]

function LoothingAddItemFrameMixin:Show()
    self.frame:Show()
    self:SelectTab(1)
    self.editBox:SetFocus()
end

function LoothingAddItemFrameMixin:Hide()
    self.frame:Hide()
    self.editBox:SetText("")
    self.resolvedLink = nil
    self.selectedLink = nil
    self.addBtn:SetEnabled(false)
    self.preview:Hide()
end

function LoothingAddItemFrameMixin:IsShown()
    return self.frame:IsShown()
end

--[[--------------------------------------------------------------------
    Factory
----------------------------------------------------------------------]]

function CreateLoothingAddItemFrame()
    local obj = LoolibCreateFromMixins(LoothingAddItemFrameMixin)
    obj:Init()
    return obj
end
