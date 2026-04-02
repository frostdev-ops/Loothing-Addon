--[[--------------------------------------------------------------------
    Loothing - Loot Council Addon for WoW 12.0+
    AddItemFrame - Dedicated frame for adding items to a session
----------------------------------------------------------------------]]

local _, ns = ...
local Loolib = LibStub("Loolib")
local Loothing = ns.Addon

local L = Loothing.Locale

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
    AddItemFrameMixin
----------------------------------------------------------------------]]

local AddItemFrameMixin = ns.AddItemFrameMixin or {}
ns.AddItemFrameMixin = AddItemFrameMixin

function AddItemFrameMixin:Init()
    self.activeTab = 1
    self.itemQueue = {}
    self.nextQueueID = 0
    self.bagRows = {}
    self.recentRows = {}
    self.queueRows = {}
    self:BuildFrame()
end

function AddItemFrameMixin:BuildFrame()
    local frame = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
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
    ns.AddItemFrame = frame

    local WM = Loolib:GetModule("WindowManager")
    if WM then WM:Register(frame) end

    -- Title
    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOPLEFT", 8, -8)
    title:SetText(L["ADD_ITEM_TITLE"])
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
        L["ENTER_ITEM"],
        L["RECENT_DROPS"],
        L["FROM_BAGS"],
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
    self.addBtn:SetText(L["ADD"])
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

function AddItemFrameMixin:BuildEnterItemPanel()
    local panel = CreateFrame("Frame", nil, self.content)
    panel:SetAllPoints()
    panel:Hide()
    self.enterItemPanel = panel

    -- Hint text
    local hint = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    hint:SetPoint("TOPLEFT")
    hint:SetText(L["ENTER_ITEM_HINT"])
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
    dragLabel:SetText(L["DRAG_ITEM_HERE"])
    dragLabel:SetTextColor(0.5, 0.5, 0.7)

    -- Queue list (replaces single-item preview)
    self:BuildQueueList(panel)
end

function AddItemFrameMixin:BuildQueueList(panel)
    local scroll = CreateFrame("ScrollFrame", nil, panel, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 0, -102)
    scroll:SetPoint("BOTTOMRIGHT", -20, 0)
    self.queueScroll = scroll

    local sc = CreateFrame("Frame", nil, scroll)
    sc:SetWidth(scroll:GetWidth())
    sc:SetHeight(1)
    scroll:SetScrollChild(sc)
    self.queueContent = sc

    -- Empty hint
    local emptyHint = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    emptyHint:SetPoint("TOP", 0, -118)
    emptyHint:SetText(L["QUEUED_ITEMS_HINT"])
    emptyHint:SetTextColor(0.4, 0.4, 0.4)
    self.queueEmptyHint = emptyHint
end

function AddItemFrameMixin:RefreshQueueList()
    for _, row in ipairs(self.queueRows) do row:Hide() end
    wipe(self.queueRows)

    if #self.itemQueue == 0 then
        self.queueEmptyHint:Show()
        self.queueScroll:Hide()
        return
    end

    self.queueEmptyHint:Hide()
    self.queueScroll:Show()

    local yOffset = 0
    for _, entry in ipairs(self.itemQueue) do
        local row = self:CreateQueueRow(self.queueContent, entry)
        row:SetPoint("TOPLEFT", 0, yOffset)
        row:SetWidth(self.queueContent:GetWidth())
        row:Show()
        yOffset = yOffset - 38
        self.queueRows[#self.queueRows + 1] = row
    end
    self.queueContent:SetHeight(math.abs(yOffset) + 8)
end

function AddItemFrameMixin:CreateQueueRow(parent, itemData)
    local row = CreateFrame("Frame", nil, parent, "BackdropTemplate")
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
    if itemData.icon then
        icon:SetTexture(itemData.icon)
    end

    -- Name
    local nameText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    nameText:SetPoint("TOPLEFT", icon, "TOPRIGHT", 6, -3)
    nameText:SetPoint("TOPRIGHT", -28, -3)
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
        ilvlText:SetText(L["ILVL_PREFIX"] .. itemData.ilvl)
    end

    -- Remove button
    local removeBtn = CreateFrame("Button", nil, row)
    removeBtn:SetSize(20, 20)
    removeBtn:SetPoint("RIGHT", -4, 0)
    local removeTxt = removeBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    removeTxt:SetPoint("CENTER")
    removeTxt:SetText("X")
    removeTxt:SetTextColor(0.8, 0.3, 0.3)
    removeBtn:SetScript("OnClick", function()
        self:RemoveFromQueue(itemData.queueID)
        self:RefreshQueueList()
    end)
    removeBtn:SetScript("OnEnter", function()
        removeTxt:SetTextColor(1, 0.4, 0.4)
    end)
    removeBtn:SetScript("OnLeave", function()
        removeTxt:SetTextColor(0.8, 0.3, 0.3)
    end)

    -- Tooltip
    row:EnableMouse(true)
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

function AddItemFrameMixin:OnItemInputChanged(text)
    if not text or text == "" then return end

    -- Increment generation to invalidate stale resolve callbacks
    -- (prevents partial typing from queuing intermediate item IDs)
    self._resolveGen = (self._resolveGen or 0) + 1
    local gen = self._resolveGen

    ResolveItem(text, function(link, name, ilvl, quality, icon)
        -- Guard: stale resolve, frame closed, or wrong tab
        if gen ~= self._resolveGen then return end
        if not self.frame:IsShown() then return end
        if self.activeTab ~= 1 then return end

        self.nextQueueID = (self.nextQueueID or 0) + 1
        self.itemQueue[#self.itemQueue + 1] = {
            link = link,
            name = name,
            ilvl = ilvl,
            quality = quality,
            icon = icon,
            queueID = self.nextQueueID,
        }
        self.editBox:SetText("")
        self:RefreshQueueList()
        self:UpdateAddButton()
    end)
end

function AddItemFrameMixin:AcceptDraggedItem()
    local infoType, itemID, itemLink = GetCursorInfo()
    if infoType == "item" then
        ClearCursor()
        self.editBox:SetText(itemLink or tostring(itemID))
    end
end

--[[--------------------------------------------------------------------
    Tab 2: Recent Drops
----------------------------------------------------------------------]]

function AddItemFrameMixin:BuildRecentDropsPanel()
    local panel = CreateFrame("Frame", nil, self.content)
    panel:SetAllPoints()
    panel:Hide()
    self.recentDropsPanel = panel

    local empty = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    empty:SetPoint("CENTER")
    empty:SetText(L["NO_RECENT_DROPS"])
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

function AddItemFrameMixin:RefreshRecentDrops()
    for _, row in ipairs(self.recentRows) do row:Hide() end
    wipe(self.recentRows)
    wipe(self.itemQueue)
    self:UpdateAddButton()

    local drops = {}

    -- Scan bags for recently looted tradeable items
    for bag = 0, NUM_BAG_SLOTS do
        local numSlots = C_Container.GetContainerNumSlots(bag)
        for slot = 1, numSlots do
            local link = C_Container.GetContainerItemLink(bag, slot)
            if link then
                local _, _, quality, ilvl = C_Item.GetItemInfo(link)
                if quality and quality >= (Loothing.MinQuality or 4) then
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
        local row = self:CreateItemRow(self.recentContent, drop)
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

function AddItemFrameMixin:BuildFromBagsPanel()
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
    equipLabel:SetText(L["EQUIPMENT_ONLY"])
    equipLabel:SetTextColor(0.8, 0.8, 0.8)

    local empty = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    empty:SetPoint("CENTER")
    empty:SetText(L["NO_BAG_ITEMS"])
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

function AddItemFrameMixin:RefreshBagList()
    for _, row in ipairs(self.bagRows) do row:Hide() end
    wipe(self.bagRows)
    wipe(self.itemQueue)
    self:UpdateAddButton()

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
        local row = self:CreateItemRow(self.bagsContent, item)
        row:SetPoint("TOPLEFT", 0, yOffset)
        row:SetWidth(self.bagsContent:GetWidth())
        row:Show()
        yOffset = yOffset - 38
        self.bagRows[#self.bagRows + 1] = row
    end
    self.bagsContent:SetHeight(math.abs(yOffset) + 8)
end

--[[--------------------------------------------------------------------
    Shared Item Row (Tabs 2 & 3 — toggle multi-select)
----------------------------------------------------------------------]]

function AddItemFrameMixin:CreateItemRow(parent, itemData)
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
        ilvlText:SetText(L["ILVL_PREFIX"] .. itemData.ilvl)
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

    -- Toggle multi-select on click
    row._selected = false
    row:SetScript("OnClick", function(btn)
        if btn._selected then
            -- Deselect
            btn._selected = false
            btn:SetBackdropColor(0.08, 0.08, 0.08, 1)
            if btn._queueID then
                self:RemoveFromQueue(btn._queueID)
            end
        else
            -- Select (duplicates allowed for multiple copies of same item)
            btn._selected = true
            btn:SetBackdropColor(0.12, 0.12, 0.28, 1)
            self.nextQueueID = (self.nextQueueID or 0) + 1
            btn._queueID = self.nextQueueID
            self.itemQueue[#self.itemQueue + 1] = {
                link = itemData.link,
                name = itemData.name,
                ilvl = itemData.ilvl or 0,
                quality = itemData.quality,
                icon = iconTex,
                queueID = self.nextQueueID,
            }
        end
        self:UpdateAddButton()
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
    Queue Helpers
----------------------------------------------------------------------]]

function AddItemFrameMixin:RemoveFromQueue(queueID)
    for i = #self.itemQueue, 1, -1 do
        if self.itemQueue[i].queueID == queueID then
            table.remove(self.itemQueue, i)
            break
        end
    end
    self:UpdateAddButton()
end

function AddItemFrameMixin:UpdateAddButton()
    local count = #self.itemQueue
    if count == 0 then
        self.addBtn:SetEnabled(false)
        self.addBtn:SetText(L["ADD"])
    else
        self.addBtn:SetEnabled(true)
        self.addBtn:SetText((L["ADD"]) .. " (" .. count .. ")")
    end
end

--[[--------------------------------------------------------------------
    Tab Management
----------------------------------------------------------------------]]

function AddItemFrameMixin:SelectTab(index)
    self.activeTab = index
    wipe(self.itemQueue)
    self:UpdateAddButton()

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
        self:RefreshQueueList()
    elseif index == 2 then
        self:RefreshRecentDrops()
    elseif index == 3 then
        self:RefreshBagList()
    end
end

--[[--------------------------------------------------------------------
    Add Action
----------------------------------------------------------------------]]

function AddItemFrameMixin:OnAddClick()
    if #self.itemQueue == 0 then return end

    if not Loothing.Session then
        Loothing:Error("Session module not available.")
        return
    end

    -- Auto-start a session if one isn't active (items need a session context)
    if Loothing.Session:GetState() == Loothing.SessionState.INACTIVE then
        if not Loothing.handleLoot then
            Loothing:StartHandleLoot()
        end
        Loothing.Session:StartSession(nil, "Manual Session")
    end

    local added = 0
    for _, entry in ipairs(self.itemQueue) do
        -- Use SafeUnitName to avoid secret value tainting
        local item = Loothing.Session:AddItem(entry.link, Loolib.SecretUtil.SafeUnitName("player"), nil, true)
        if item then
            added = added + 1
        end
    end

    if added > 0 then
        Loothing:Print(added .. " item(s) added to session.")
        self:Hide()
    else
        Loothing:Error("Failed to add items to session.")
    end
end

--[[--------------------------------------------------------------------
    Show / Hide
----------------------------------------------------------------------]]

function AddItemFrameMixin:Show()
    wipe(self.itemQueue)
    self.frame:Show()
    self.frame:Raise()
    self:SelectTab(1)
    self.editBox:SetFocus()
end

function AddItemFrameMixin:Hide()
    self.frame:Hide()
    self.editBox:SetText("")
    wipe(self.itemQueue)
    self.addBtn:SetEnabled(false)
end

function AddItemFrameMixin:IsShown()
    return self.frame:IsShown()
end

--[[--------------------------------------------------------------------
    Factory
----------------------------------------------------------------------]]

local function CreateAddItemFrame()
    local obj = Loolib.CreateFromMixins(AddItemFrameMixin)
    obj:Init()
    return obj
end

ns.CreateAddItemFrame = CreateAddItemFrame
