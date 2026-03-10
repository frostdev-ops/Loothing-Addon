--[[--------------------------------------------------------------------
    Loothing - Loot Council Addon for WoW 12.0+
    SessionPanel - Active loot session view
----------------------------------------------------------------------]]

local _, ns = ...
local Loolib = LibStub("Loolib")
local Loothing = ns.Addon
local Utils = ns.Utils
local Loothing = ns.Addon
local Popups = ns.Popups

--[[--------------------------------------------------------------------
    SessionPanelMixin
----------------------------------------------------------------------]]

local SessionPanelMixin = ns.SessionPanelMixin or Loolib.CreateFromMixins(Loolib.CallbackRegistryMixin)
ns.SessionPanelMixin = SessionPanelMixin

local SESSION_PANEL_EVENTS = {
    "OnItemSelected",
    "OnStartSession",
    "OnEndSession",
}

--- Initialize the session panel
-- @param parent Frame - Parent frame (usually a tab content area)
function SessionPanelMixin:Init(parent)
    Loolib.CallbackRegistryMixin.OnLoad(self)
    self:GenerateCallbackEvents(SESSION_PANEL_EVENTS)

    self.parent = parent
    self.selectedItem = nil
    self.selectedItems = {}     -- guid -> item (multi-select)
    self.lastClickedGuid = nil  -- for shift-click range select
    self.itemRows = {}          -- active rows (in use this frame)
    self.itemRowPool = {}       -- recycled rows waiting for reuse

    self:CreateFrame()
    self:CreateElements()
    self:RegisterEvents()
end

--- Create the main frame
function SessionPanelMixin:CreateFrame()
    local frame = CreateFrame("Frame", nil, self.parent)
    frame:SetAllPoints()

    self.frame = frame
end

--- Create UI elements
function SessionPanelMixin:CreateElements()
    local L = Loothing.Locale

    -- Header area
    self:CreateHeader()

    -- Filter bar
    self:CreateFilterBar()

    -- Item list area
    self:CreateItemList()

    -- Bulk action bar (hidden by default, shown on multi-select)
    self:CreateBulkActionBar()

    -- Footer with controls
    self:CreateFooter()
end

--- Create header
function SessionPanelMixin:CreateHeader()
    local L = Loothing.Locale

    local header = CreateFrame("Frame", nil, self.frame)
    header:SetPoint("TOPLEFT", 8, -8)
    header:SetPoint("TOPRIGHT", -8, -8)
    header:SetHeight(50)

    -- Session status
    self.statusText = header:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    self.statusText:SetPoint("TOPLEFT")
    self.statusText:SetText(L["NO_SESSION"])

    -- Encounter info
    self.encounterText = header:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    self.encounterText:SetPoint("TOPLEFT", self.statusText, "BOTTOMLEFT", 0, -4)
    self.encounterText:SetTextColor(0.7, 0.7, 0.7)

    -- Item count
    self.itemCountText = header:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    self.itemCountText:SetPoint("TOPRIGHT")
    self.itemCountText:SetTextColor(0.7, 0.7, 0.7)

    -- ML indicator
    self.mlIndicator = header:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    self.mlIndicator:SetPoint("TOPRIGHT", self.itemCountText, "BOTTOMRIGHT", 0, -2)

    self.header = header
end

--- Create filter bar
function SessionPanelMixin:CreateFilterBar()
    -- Initialize filters if not already done
    if not Loothing.Filters then
        Loothing.Filters = Loolib.CreateAndInitFromMixin(ns.FiltersMixin)
    end

    -- Create filter bar
    local filterBar = Loothing.Filters:CreateFilterBar(self.frame)
    filterBar:SetPoint("TOPLEFT", 8, -66)
    filterBar:SetPoint("TOPRIGHT", -8, -66)

    -- Initially hidden - can be toggled
    filterBar:Hide()

    self.filterBar = filterBar

    -- Register for filter changes
    Loothing.Filters:RegisterCallback("OnFiltersChanged", function()
        self:Refresh()
    end, self)
end

--- Toggle filter bar visibility
function SessionPanelMixin:ToggleFilterBar()
    if self.filterBar:IsShown() then
        self.filterBar:Hide()
        self.listContainer:SetPoint("TOPLEFT", 8, -66)
    else
        self.filterBar:Show()
        self.listContainer:SetPoint("TOPLEFT", 8, -154)
    end
end

--- Create item list
function SessionPanelMixin:CreateItemList()
    local L = Loothing.Locale

    -- List container
    local container = CreateFrame("Frame", nil, self.frame, "BackdropTemplate")
    container:SetPoint("TOPLEFT", 8, -66)
    container:SetPoint("BOTTOMRIGHT", -8, 50)
    container:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        tile = false,
        edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    container:SetBackdropColor(0.05, 0.05, 0.05, 0.9)
    container:SetBackdropBorderColor(0.2, 0.2, 0.2, 1)

    -- Column headers
    local headerFrame = CreateFrame("Frame", nil, container)
    headerFrame:SetPoint("TOPLEFT", 8, -4)
    headerFrame:SetPoint("TOPRIGHT", -24, -4)
    headerFrame:SetHeight(20)

    local itemHeader = headerFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    itemHeader:SetPoint("LEFT")
    itemHeader:SetText(L["ITEM"])
    itemHeader:SetTextColor(0.7, 0.7, 0.7)

    local statusHeader = headerFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    statusHeader:SetPoint("RIGHT", -80, 0)
    statusHeader:SetText(L["STATUS"])
    statusHeader:SetTextColor(0.7, 0.7, 0.7)

    -- Separator
    local sep = container:CreateTexture(nil, "ARTWORK")
    sep:SetPoint("TOPLEFT", 8, -24)
    sep:SetPoint("TOPRIGHT", -8, -24)
    sep:SetHeight(1)
    sep:SetColorTexture(0.3, 0.3, 0.3, 1)

    -- Scroll frame
    local scrollFrame = CreateFrame("ScrollFrame", nil, container, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 4, -28)
    scrollFrame:SetPoint("BOTTOMRIGHT", -24, 4)

    local content = CreateFrame("Frame", nil, scrollFrame)
    content:SetSize(1, 800) -- width managed by OnSizeChanged below
    scrollFrame:SetScrollChild(content)

    -- Keep scroll child width in sync with scroll frame
    scrollFrame:SetScript("OnSizeChanged", function(sf, w, h)
        content:SetWidth(w)
    end)

    self.listContainer = container
    self.listContent = content
    self.scrollFrame = scrollFrame

    -- Empty state text
    self.emptyText = container:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    self.emptyText:SetPoint("CENTER")
    self.emptyText:SetText(L["NO_ITEMS"])
    self.emptyText:SetTextColor(0.5, 0.5, 0.5)
end

--[[--------------------------------------------------------------------
    Multi-Select Helpers
----------------------------------------------------------------------]]

--- Check if an item is selected
-- @param guid string - Item GUID
-- @return boolean
function SessionPanelMixin:IsItemSelected(guid)
    return self.selectedItems[guid] ~= nil
end

--- Get all selected items
-- @return table - Array of items
function SessionPanelMixin:GetSelectedItems()
    local items = {}
    for _, item in pairs(self.selectedItems) do
        items[#items + 1] = item
    end
    return items
end

--- Get count of selected items
-- @return number
function SessionPanelMixin:GetSelectedCount()
    local count = 0
    for _ in pairs(self.selectedItems) do
        count = count + 1
    end
    return count
end

--- Get selected items filtered by state
-- @param state number - Loothing.ItemState value
-- @return table - Array of items matching state
function SessionPanelMixin:GetSelectedItemsByState(state)
    local items = {}
    for _, item in pairs(self.selectedItems) do
        if item.state == state then
            items[#items + 1] = item
        end
    end
    return items
end

--- Select an item
-- @param item table - Item to select
function SessionPanelMixin:SelectItem(item)
    self.selectedItems[item.guid] = item
end

--- Deselect an item by guid
-- @param guid string
function SessionPanelMixin:DeselectItem(guid)
    self.selectedItems[guid] = nil
end

--- Toggle selection on an item
-- @param item table
function SessionPanelMixin:ToggleItemSelection(item)
    if self.selectedItems[item.guid] then
        self.selectedItems[item.guid] = nil
    else
        self.selectedItems[item.guid] = item
    end
end

--- Clear all selection
function SessionPanelMixin:ClearSelection()
    wipe(self.selectedItems)
    self.selectedItem = nil
    self.lastClickedGuid = nil
end

--- Select all visible items
function SessionPanelMixin:SelectAllItems()
    for _, row in ipairs(self.itemRows) do
        local item = row:GetItem()
        if item then
            self.selectedItems[item.guid] = item
        end
    end
end

--- Select a range of items from one guid to another (based on display order)
-- @param fromGuid string
-- @param toGuid string
function SessionPanelMixin:SelectRange(fromGuid, toGuid)
    local startIdx, endIdx
    for i, row in ipairs(self.itemRows) do
        local item = row:GetItem()
        if item then
            if item.guid == fromGuid then startIdx = i end
            if item.guid == toGuid then endIdx = i end
        end
    end

    if not startIdx or not endIdx then return end

    -- Ensure start <= end
    if startIdx > endIdx then
        startIdx, endIdx = endIdx, startIdx
    end

    for i = startIdx, endIdx do
        local item = self.itemRows[i]:GetItem()
        if item then
            self.selectedItems[item.guid] = item
        end
    end
end

--- Sync selectedItem (backward compat) and show/hide bulk bar
function SessionPanelMixin:UpdateSelectionState()
    local count = self:GetSelectedCount()
    if count == 1 then
        -- Exactly one selected - set backward-compat selectedItem
        for _, item in pairs(self.selectedItems) do
            self.selectedItem = item
        end
    else
        self.selectedItem = nil
    end

    -- Show/hide bulk bar
    if count >= 2 then
        self:ShowBulkBar()
    else
        self:HideBulkBar()
    end

    if self.bulkBar then
        self:UpdateBulkBarButtons()
    end
end

--- Update visual selection state on all rows
function SessionPanelMixin:UpdateSelectionVisuals()
    for _, row in ipairs(self.itemRows) do
        local item = row:GetItem()
        if item then
            row:SetSelected(self:IsItemSelected(item.guid))
        end
    end
end

--[[--------------------------------------------------------------------
    Bulk Action Bar
----------------------------------------------------------------------]]

--- Create the bulk action bar (hidden by default)
function SessionPanelMixin:CreateBulkActionBar()
    local L = Loothing.Locale

    local bar = CreateFrame("Frame", nil, self.listContainer, "BackdropTemplate")
    bar:SetPoint("TOPLEFT", 0, -25)
    bar:SetPoint("TOPRIGHT", 0, -25)
    bar:SetHeight(28)
    bar:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        tile = false,
        edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    bar:SetBackdropColor(0.15, 0.12, 0.02, 0.9)
    bar:SetBackdropBorderColor(0.6, 0.5, 0.1, 1)
    bar:SetFrameLevel(self.listContainer:GetFrameLevel() + 10)
    bar:Hide()

    -- Select All button
    local selectAllBtn = CreateFrame("Button", nil, bar, "UIPanelButtonTemplate")
    selectAllBtn:SetSize(70, 22)
    selectAllBtn:SetPoint("LEFT", 4, 0)
    selectAllBtn:SetText(L["SELECT_ALL"])
    selectAllBtn:SetScript("OnClick", function()
        self:OnSelectAll()
    end)

    -- Deselect button
    local deselectBtn = CreateFrame("Button", nil, bar, "UIPanelButtonTemplate")
    deselectBtn:SetSize(60, 22)
    deselectBtn:SetPoint("LEFT", selectAllBtn, "RIGHT", 4, 0)
    deselectBtn:SetText(L["DESELECT_ALL"])
    deselectBtn:SetScript("OnClick", function()
        self:OnDeselectAll()
    end)

    -- Separator
    local sep = bar:CreateTexture(nil, "ARTWORK")
    sep:SetPoint("LEFT", deselectBtn, "RIGHT", 6, 0)
    sep:SetSize(1, 18)
    sep:SetColorTexture(0.4, 0.4, 0.4, 1)

    -- Start Vote bulk button
    local startVoteBtn = CreateFrame("Button", nil, bar, "UIPanelButtonTemplate")
    startVoteBtn:SetSize(90, 22)
    startVoteBtn:SetPoint("LEFT", sep, "RIGHT", 6, 0)
    startVoteBtn:SetText(string.format(L["BULK_START_VOTE"], 0))
    startVoteBtn:SetScript("OnClick", function()
        self:OnBulkStartVote()
    end)

    -- End Vote bulk button
    local endVoteBtn = CreateFrame("Button", nil, bar, "UIPanelButtonTemplate")
    endVoteBtn:SetSize(85, 22)
    endVoteBtn:SetPoint("LEFT", startVoteBtn, "RIGHT", 4, 0)
    endVoteBtn:SetText(string.format(L["BULK_END_VOTE"], 0))
    endVoteBtn:SetScript("OnClick", function()
        self:OnBulkEndVote()
    end)

    -- Skip bulk button
    local skipBtn = CreateFrame("Button", nil, bar, "UIPanelButtonTemplate")
    skipBtn:SetSize(65, 22)
    skipBtn:SetPoint("LEFT", endVoteBtn, "RIGHT", 4, 0)
    skipBtn:SetText(string.format(L["BULK_SKIP"], 0))
    skipBtn:SetScript("OnClick", function()
        self:OnBulkSkip()
    end)

    -- Remove bulk button
    local removeBtn = CreateFrame("Button", nil, bar, "UIPanelButtonTemplate")
    removeBtn:SetSize(80, 22)
    removeBtn:SetPoint("LEFT", skipBtn, "RIGHT", 4, 0)
    removeBtn:SetText(string.format(L["BULK_REMOVE"], 0))
    removeBtn:SetScript("OnClick", function()
        self:OnBulkRemove()
    end)

    -- Re-Vote bulk button
    local revoteBtn = CreateFrame("Button", nil, bar, "UIPanelButtonTemplate")
    revoteBtn:SetSize(80, 22)
    revoteBtn:SetPoint("LEFT", removeBtn, "RIGHT", 4, 0)
    revoteBtn:SetText(string.format(L["BULK_REVOTE"], 0))
    revoteBtn:SetScript("OnClick", function()
        self:OnBulkRevote()
    end)

    -- Selected count label (right-aligned)
    local countLabel = bar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    countLabel:SetPoint("RIGHT", -8, 0)
    countLabel:SetTextColor(1, 0.82, 0)
    countLabel:SetText("")

    self.bulkBar = bar
    self.bulkBarButtons = {
        startVote = startVoteBtn,
        endVote = endVoteBtn,
        skip = skipBtn,
        remove = removeBtn,
        revote = revoteBtn,
    }
    self.bulkCountLabel = countLabel
end

--- Show bulk action bar and adjust scroll frame
function SessionPanelMixin:ShowBulkBar()
    if not self.bulkBar then return end
    if self.bulkBar:IsShown() then return end

    self.bulkBar:Show()
    -- Push scroll frame down to make room
    self.scrollFrame:SetPoint("TOPLEFT", 4, -56)
end

--- Hide bulk action bar and restore scroll frame
function SessionPanelMixin:HideBulkBar()
    if not self.bulkBar then return end
    if not self.bulkBar:IsShown() then return end

    self.bulkBar:Hide()
    -- Restore scroll frame position
    self.scrollFrame:SetPoint("TOPLEFT", 4, -28)
end

--- Update bulk bar button states based on selected items
function SessionPanelMixin:UpdateBulkBarButtons()
    if not self.bulkBar then return end

    local L = Loothing.Locale
    local isML = Loothing.Session and Loothing.Session:IsMasterLooter() or false
    local count = self:GetSelectedCount()

    -- Count label
    self.bulkCountLabel:SetText(string.format(L["N_SELECTED"], count))

    -- Count items by state
    local pendingItems = self:GetSelectedItemsByState(Loothing.ItemState.PENDING)
    local votingItems = self:GetSelectedItemsByState(Loothing.ItemState.VOTING)
    local talliedItems = self:GetSelectedItemsByState(Loothing.ItemState.TALLIED)
    local nPending = #pendingItems
    local nVoting = #votingItems
    local nTallied = #talliedItems

    local btns = self.bulkBarButtons

    -- Start Vote: enabled when PENDING items exist
    btns.startVote:SetText(string.format(L["BULK_START_VOTE"], nPending))
    if isML and nPending > 0 then
        btns.startVote:Enable()
        btns.startVote:Show()
    else
        btns.startVote:Disable()
        if not isML then btns.startVote:Hide() end
    end

    -- End Vote: enabled when VOTING items exist
    btns.endVote:SetText(string.format(L["BULK_END_VOTE"], nVoting))
    if isML and nVoting > 0 then
        btns.endVote:Enable()
        btns.endVote:Show()
    else
        btns.endVote:Disable()
        if not isML then btns.endVote:Hide() end
    end

    -- Skip: enabled when PENDING or VOTING items exist
    local nSkippable = nPending + nVoting
    btns.skip:SetText(string.format(L["BULK_SKIP"], nSkippable))
    if isML and nSkippable > 0 then
        btns.skip:Enable()
        btns.skip:Show()
    else
        btns.skip:Disable()
        if not isML then btns.skip:Hide() end
    end

    -- Remove: enabled when PENDING items exist
    btns.remove:SetText(string.format(L["BULK_REMOVE"], nPending))
    if isML and nPending > 0 then
        btns.remove:Enable()
        btns.remove:Show()
    else
        btns.remove:Disable()
        if not isML then btns.remove:Hide() end
    end

    -- Re-Vote: enabled when TALLIED items exist
    btns.revote:SetText(string.format(L["BULK_REVOTE"], nTallied))
    if isML and nTallied > 0 then
        btns.revote:Enable()
        btns.revote:Show()
    else
        btns.revote:Disable()
        if not isML then btns.revote:Hide() end
    end
end

--[[--------------------------------------------------------------------
    Bulk Action Handlers
----------------------------------------------------------------------]]

--- Start voting on all selected PENDING items
function SessionPanelMixin:OnBulkStartVote()
    if not Loothing.Session then return end

    local items = self:GetSelectedItemsByState(Loothing.ItemState.PENDING)
    for _, item in ipairs(items) do
        Loothing.Session:StartVoting(item.guid)
    end

    self:ClearSelection()
    self:RefreshItems()
end

--- End voting on all selected VOTING items
function SessionPanelMixin:OnBulkEndVote()
    if not Loothing.Session then return end

    local items = self:GetSelectedItemsByState(Loothing.ItemState.VOTING)
    for _, item in ipairs(items) do
        Loothing.Session:EndVoting(item.guid)
    end

    self:ClearSelection()
    self:RefreshItems()
end

--- Skip all selected PENDING/VOTING items (with confirmation)
function SessionPanelMixin:OnBulkSkip()
    if not Loothing.Session then return end

    local L = Loothing.Locale
    local pending = self:GetSelectedItemsByState(Loothing.ItemState.PENDING)
    local voting = self:GetSelectedItemsByState(Loothing.ItemState.VOTING)
    local count = #pending + #voting
    if count == 0 then return end

    Popups:Confirm(
        L["SKIP_ITEM"],
        string.format(L["CONFIRM_BULK_SKIP"], count),
        function()
            for _, item in ipairs(pending) do
                Loothing.Session:SkipItem(item.guid)
            end
            for _, item in ipairs(voting) do
                Loothing.Session:SkipItem(item.guid)
            end
            self:ClearSelection()
            self:RefreshItems()
        end
    )
end

--- Remove all selected PENDING items (with confirmation)
function SessionPanelMixin:OnBulkRemove()
    if not Loothing.Session then return end

    local L = Loothing.Locale
    local items = self:GetSelectedItemsByState(Loothing.ItemState.PENDING)
    if #items == 0 then return end

    Popups:Confirm(
        L["REMOVE_ITEMS"],
        string.format(L["CONFIRM_BULK_REMOVE"], #items),
        function()
            for _, item in ipairs(items) do
                Loothing.Session:RemoveItem(item.guid)
            end
            self:ClearSelection()
            self:RefreshItems()
        end
    )
end

--- Re-vote on all selected TALLIED items (with confirmation)
function SessionPanelMixin:OnBulkRevote()
    if not Loothing.Session then return end

    local L = Loothing.Locale
    local items = self:GetSelectedItemsByState(Loothing.ItemState.TALLIED)
    if #items == 0 then return end

    Popups:Confirm(
        L["RE_VOTE"],
        string.format(L["CONFIRM_BULK_REVOTE"], #items),
        function()
            for _, item in ipairs(items) do
                Loothing.Session:RevoteItem(item.guid)
            end
            self:ClearSelection()
            self:RefreshItems()
        end
    )
end

--- Select all visible items
function SessionPanelMixin:OnSelectAll()
    self:SelectAllItems()
    self:UpdateSelectionVisuals()
    self:UpdateSelectionState()
end

--- Deselect all items
function SessionPanelMixin:OnDeselectAll()
    self:ClearSelection()
    self:UpdateSelectionVisuals()
    self:UpdateSelectionState()
end

--[[--------------------------------------------------------------------
    Bulk Context Menu
----------------------------------------------------------------------]]

--- Show context menu for multi-selected items
-- @param row table - The right-clicked row
function SessionPanelMixin:ShowBulkContextMenu(row)
    local L = Loothing.Locale
    local isML = Loothing.Session and Loothing.Session:IsMasterLooter() or false
    local count = self:GetSelectedCount()

    MenuUtil.CreateContextMenu(row:GetFrame(), function(ownerRegion, rootDescription)
        rootDescription:CreateTitle(string.format(L["N_SELECTED"], count))

        if isML then
            local pending = self:GetSelectedItemsByState(Loothing.ItemState.PENDING)
            local voting = self:GetSelectedItemsByState(Loothing.ItemState.VOTING)
            local tallied = self:GetSelectedItemsByState(Loothing.ItemState.TALLIED)

            if #pending > 0 then
                rootDescription:CreateButton(string.format(L["BULK_START_VOTE"], #pending), function()
                    self:OnBulkStartVote()
                end)
            end

            if #voting > 0 then
                rootDescription:CreateButton(string.format(L["BULK_END_VOTE"], #voting), function()
                    self:OnBulkEndVote()
                end)
            end

            local nSkippable = #pending + #voting
            if nSkippable > 0 then
                rootDescription:CreateButton(string.format(L["BULK_SKIP"], nSkippable), function()
                    self:OnBulkSkip()
                end)
            end

            if #pending > 0 then
                rootDescription:CreateButton(string.format(L["BULK_REMOVE"], #pending), function()
                    self:OnBulkRemove()
                end)
            end

            if #tallied > 0 then
                rootDescription:CreateButton(string.format(L["BULK_REVOTE"], #tallied), function()
                    self:OnBulkRevote()
                end)
            end
        end

        rootDescription:CreateButton(L["DESELECT_ALL"], function()
            self:OnDeselectAll()
        end)
    end)
end

--- Create footer with controls
function SessionPanelMixin:CreateFooter()
    local L = Loothing.Locale

    local footer = CreateFrame("Frame", nil, self.frame)
    footer:SetPoint("BOTTOMLEFT", 8, 8)
    footer:SetPoint("BOTTOMRIGHT", -8, 8)
    footer:SetHeight(36)

    -- Start/End session button (ML only)
    self.sessionButton = CreateFrame("Button", nil, footer, "UIPanelButtonTemplate")
    self.sessionButton:SetSize(120, 26)
    self.sessionButton:SetPoint("LEFT")
    self.sessionButton:SetText(L["START_SESSION"])
    self.sessionButton:SetScript("OnClick", function()
        self:OnSessionButtonClick()
    end)

    -- Start all votes button
    self.startAllButton = CreateFrame("Button", nil, footer, "UIPanelButtonTemplate")
    self.startAllButton:SetSize(100, 26)
    self.startAllButton:SetPoint("LEFT", self.sessionButton, "RIGHT", 8, 0)
    self.startAllButton:SetText(L["START_ALL"])
    self.startAllButton:SetScript("OnClick", function()
        self:OnStartAllClick()
    end)
    self.startAllButton:Hide()

    -- Add Item button (ML only)
    self.addItemBtn = CreateFrame("Button", nil, footer, "UIPanelButtonTemplate")
    self.addItemBtn:SetSize(80, 26)
    self.addItemBtn:SetPoint("LEFT", self.startAllButton, "RIGHT", 8, 0)
    self.addItemBtn:SetText(L["ADD_ITEM"] or "Add Item")
    self.addItemBtn:SetScript("OnClick", function()
        if Loothing.AddItemFrame then
            Loothing.AddItemFrame:Show()
        end
    end)
    self.addItemBtn:Hide()

    -- Global "Award Later" checkbox
    self.awardLaterCheck = CreateFrame("CheckButton", nil, footer, "UICheckButtonTemplate")
    self.awardLaterCheck:SetSize(24, 24)
    self.awardLaterCheck:SetPoint("LEFT", self.addItemBtn, "RIGHT", 8, 0)
    self.awardLaterCheck.text = self.awardLaterCheck:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    self.awardLaterCheck.text:SetPoint("LEFT", self.awardLaterCheck, "RIGHT", 2, 0)
    self.awardLaterCheck.text:SetText(L["AWARD_LATER_ALL"] or "Award Later (All)")
    self.awardLaterCheck.text:SetTextColor(0.7, 0.7, 0.7)
    self.awardLaterCheck:SetScript("OnClick", function(btn)
        local checked = btn:GetChecked()
        if Loothing.Session then
            local items = Loothing.Session:GetItems()
            if items then
                for _, item in items:Enumerate() do
                    item.awardLater = checked
                end
            end
        end
        self:RefreshItems()
    end)
    self.awardLaterCheck:SetScript("OnEnter", function(btn)
        GameTooltip:SetOwner(btn, "ANCHOR_RIGHT")
        GameTooltip:SetText(L["AWARD_LATER_ALL"] or "Award Later (All)", 1, 0.82, 0)
        GameTooltip:AddLine("Set all items to be awarded after the session", 1, 1, 1, true)
        GameTooltip:Show()
    end)
    self.awardLaterCheck:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    self.awardLaterCheck:Hide()

    -- Refresh button
    self.refreshButton = CreateFrame("Button", nil, footer, "UIPanelButtonTemplate")
    self.refreshButton:SetSize(80, 26)
    self.refreshButton:SetPoint("RIGHT")
    self.refreshButton:SetText(L["REFRESH"])
    self.refreshButton:SetScript("OnClick", function()
        self:Refresh()
    end)

    self.footer = footer
end

--[[--------------------------------------------------------------------
    Event Registration
----------------------------------------------------------------------]]

--- Register for session events
function SessionPanelMixin:RegisterEvents()
    if not Loothing.Session then return end

    Loothing.Session:RegisterCallback("OnSessionStarted", function()
        self:Refresh()
    end, self)

    Loothing.Session:RegisterCallback("OnSessionEnded", function()
        self:Refresh()
    end, self)

    Loothing.Session:RegisterCallback("OnItemAdded", function(_, item)
        self:Refresh()
    end, self)

    Loothing.Session:RegisterCallback("OnItemRemoved", function()
        self:Refresh()
    end, self)

    Loothing.Session:RegisterCallback("OnItemStateChanged", function()
        self:Refresh()
    end, self)

    Loothing.Session:RegisterCallback("OnVoteReceived", function()
        self:RefreshItems()
    end, self)

    -- Cinematic auto-hide: hide session panel during cinematics
    if not self.cinematicFrame then
        local cinematicFrame = CreateFrame("Frame")
        cinematicFrame:RegisterEvent("CINEMATIC_START")
        cinematicFrame:RegisterEvent("CINEMATIC_STOP")
        cinematicFrame:SetScript("OnEvent", function(_, event)
            if event == "CINEMATIC_START" then
                if self.frame and self.frame:IsShown() then
                    self.wasShowingBeforeCinematic = true
                    self.frame:Hide()
                end
            elseif event == "CINEMATIC_STOP" then
                if self.wasShowingBeforeCinematic then
                    self.wasShowingBeforeCinematic = false
                    self.frame:Show()
                end
            end
        end)
        self.cinematicFrame = cinematicFrame
    end
end

--[[--------------------------------------------------------------------
    Display
----------------------------------------------------------------------]]

--- Refresh all display elements
function SessionPanelMixin:Refresh()
    self:UpdateHeader()
    self:UpdateFooter()
    self:RefreshItems()
end

--- Update header display
function SessionPanelMixin:UpdateHeader()
    local L = Loothing.Locale

    if not Loothing.Session then
        self.statusText:SetText(L["NO_SESSION"])
        self.statusText:SetTextColor(0.5, 0.5, 0.5)
        self.encounterText:SetText("")
        self.itemCountText:SetText("")
        self.mlIndicator:SetText("")
        return
    end

    local state = Loothing.Session:GetState()

    if state == Loothing.SessionState.INACTIVE then
        self.statusText:SetText(L["NO_SESSION"])
        self.statusText:SetTextColor(0.5, 0.5, 0.5)
        self.encounterText:SetText("")
        self.itemCountText:SetText("")
    elseif state == Loothing.SessionState.ACTIVE then
        self.statusText:SetText(L["SESSION_ACTIVE"])
        self.statusText:SetTextColor(0, 1, 0)

        local encounterName = Loothing.Session:GetEncounterName()
        if encounterName and encounterName ~= "" then
            self.encounterText:SetText(encounterName)
        else
            self.encounterText:SetText(L["MANUAL_SESSION"])
        end

        -- Item counts
        local items = Loothing.Session:GetItems()
        if items then
            local total = items:GetSize()
            local pending = 0
            local voting = 0
            local completed = 0

            for _, item in items:Enumerate() do
                if item.state == Loothing.ItemState.PENDING then
                    pending = pending + 1
                elseif item.state == Loothing.ItemState.VOTING then
                    voting = voting + 1
                elseif item.state == Loothing.ItemState.AWARDED or item.state == Loothing.ItemState.SKIPPED then
                    completed = completed + 1
                end
            end

            self.itemCountText:SetText(string.format(L["ITEMS_COUNT"], total, pending, voting, completed))
        end
    elseif state == Loothing.SessionState.CLOSED then
        self.statusText:SetText(L["SESSION_CLOSED"])
        self.statusText:SetTextColor(0.5, 0.5, 0.5)
    end

    -- ML indicator
    local isML = Loothing.Session and Loothing.Session:IsMasterLooter() or false
    if isML then
        self.mlIndicator:SetText(L["YOU_ARE_ML"])
        self.mlIndicator:SetTextColor(1, 0.82, 0)
    else
        local ml = Loothing.Session:GetMasterLooter()
        if ml then
            self.mlIndicator:SetText(string.format(L["ML_IS"], Utils.GetShortName(ml)))
            self.mlIndicator:SetTextColor(0.7, 0.7, 0.7)
        else
            self.mlIndicator:SetText("")
        end
    end
end

--- Update footer buttons
function SessionPanelMixin:UpdateFooter()
    local L = Loothing.Locale
    local isML = Loothing.Session and Loothing.Session:IsMasterLooter() or false

    if not Loothing.Session then
        self.sessionButton:Hide()
        self.startAllButton:Hide()
        self.addItemBtn:Hide()
        self.awardLaterCheck:Hide()
        return
    end

    local state = Loothing.Session:GetState()

    if isML then
        self.sessionButton:Show()

        if state == Loothing.SessionState.INACTIVE then
            self.sessionButton:SetText(L["START_SESSION"])
            self.sessionButton:Enable()
            self.startAllButton:Hide()
            self.addItemBtn:Hide()
            self.awardLaterCheck:Hide()
        elseif state == Loothing.SessionState.ACTIVE then
            self.sessionButton:SetText(L["END_SESSION"])
            self.sessionButton:Enable()

            -- Show ML-only controls during active session
            self.addItemBtn:Show()
            self.awardLaterCheck:Show()

            -- Show start all if there are pending items
            local items = Loothing.Session:GetItems()
            local hasPending = false
            if items then
                for _, item in items:Enumerate() do
                    if item.state == Loothing.ItemState.PENDING then
                        hasPending = true
                        break
                    end
                end
            end

            if hasPending then
                self.startAllButton:Show()
            else
                self.startAllButton:Hide()
            end
        else
            self.sessionButton:SetText(L["START_SESSION"])
            self.sessionButton:Enable()
            self.startAllButton:Hide()
            self.addItemBtn:Hide()
            self.awardLaterCheck:Hide()
        end
    else
        self.sessionButton:Hide()
        self.startAllButton:Hide()
        self.addItemBtn:Hide()
        self.awardLaterCheck:Hide()
    end
end

--- Sort items by typeCode then ilvl descending
-- @param items table - Array of items
-- @return table - Sorted copy
function SessionPanelMixin:SortItems(items)
    local sorted = {}
    for _, item in ipairs(items) do
        sorted[#sorted + 1] = item
    end

    table.sort(sorted, function(a, b)
        -- Sort by typeCode first (group similar items)
        local typeA = a.typeCode or "default"
        local typeB = b.typeCode or "default"
        if typeA ~= typeB then
            return typeA < typeB
        end
        -- Then by ilvl descending
        local ilvlA = a.itemLevel or a.ilvl or 0
        local ilvlB = b.itemLevel or b.ilvl or 0
        return ilvlA > ilvlB
    end)

    return sorted
end

--- Acquire a row from the pool or create a new one
function SessionPanelMixin:AcquireItemRow()
    local row = table.remove(self.itemRowPool)
    if not row then
        row = ns.CreateItemRow(self.listContent)
    end
    return row
end

--- Release all active rows back to the pool
function SessionPanelMixin:ReleaseAllItemRows()
    for _, row in ipairs(self.itemRows) do
        ns.ResetItemRow(nil, row)
        self.itemRowPool[#self.itemRowPool + 1] = row
    end
    wipe(self.itemRows)
end

--- Refresh item list
function SessionPanelMixin:RefreshItems()
    -- Return active rows to pool
    self:ReleaseAllItemRows()

    if not Loothing.Session then
        self.emptyText:Show()
        self:HideBulkBar()
        return
    end

    local items = Loothing.Session:GetItems()
    if not items or items:GetSize() == 0 then
        self.emptyText:Show()
        self:HideBulkBar()
        return
    end

    self.emptyText:Hide()

    -- Collect and sort items
    local itemArray = {}
    local activeGuids = {}
    for _, item in items:Enumerate() do
        itemArray[#itemArray + 1] = item
        activeGuids[item.guid] = true
    end
    itemArray = self:SortItems(itemArray)

    -- Prune selectedItems of guids no longer in session
    for guid in pairs(self.selectedItems) do
        if not activeGuids[guid] then
            self.selectedItems[guid] = nil
        end
    end

    local isML = Loothing.Session and Loothing.Session:IsMasterLooter() or false
    local yOffset = 0
    local rowHeight = 44
    local spacing = 2

    for _, item in ipairs(itemArray) do
        local row = self:AcquireItemRow()
        self:ResetMLControls(row)
        row:SetItem(item)

        row:GetFrame():SetPoint("TOPLEFT", 0, yOffset)
        row:GetFrame():SetPoint("TOPRIGHT", 0, yOffset)
        row:GetFrame():Show()

        -- ML-only: Add delete button and "Award Later" checkbox per item
        if isML then
            self:AddMLControls(row, item)
        end

        -- Setup callbacks
        row:SetCallback("onSelect", function(r, i)
            self:OnItemSelect(r, i)
        end)

        row:SetCallback("onStartVote", function(r, i)
            self:OnStartVote(i)
        end)

        row:SetCallback("onEndVote", function(r, i)
            self:OnEndVote(i)
        end)

        row:SetCallback("onVote", function(r, i)
            self:OnVote(i)
        end)

        row:SetCallback("onAward", function(r, i)
            self:OnAward(i)
        end)

        row:SetCallback("onViewResults", function(r, i)
            self:OnViewResults(i)
        end)

        row:SetCallback("onSkip", function(r, i)
            self:OnSkip(i)
        end)

        row:SetCallback("onRevote", function(r, i)
            self:OnRevote(i)
        end)

        -- Context menu callback for bulk actions
        row:SetCallback("onContextMenu", function(r, i)
            if self:IsItemSelected(i.guid) and self:GetSelectedCount() >= 2 then
                self:ShowBulkContextMenu(r)
                return true
            end
            return false
        end)

        -- Highlight selected (multi-select aware)
        if self:IsItemSelected(item.guid) then
            row:SetSelected(true)
        end

        self.itemRows[#self.itemRows + 1] = row
        yOffset = yOffset - rowHeight - spacing
    end

    -- Update content height
    self.listContent:SetHeight(math.abs(yOffset) + 20)

    -- Sync selection state (backward compat + bulk bar)
    self:UpdateSelectionState()
end

--- Hide ML-only controls and restore the row's default layout.
-- @param row table - Item row
function SessionPanelMixin:ResetMLControls(row)
    local frame = row and row:GetFrame()
    if not frame then return end

    if frame._deleteButton then
        frame._deleteButton:Hide()
    end

    if frame._awardLaterCB then
        frame._awardLaterCB:Hide()
    end

    -- Force layout recalculation on next SetItem by clearing cached state
    row._layoutAwarded = nil
    row:ApplyDefaultLayout()
end

--- Add ML-specific controls to an item row (delete button, award later checkbox)
-- @param row table - Item row
-- @param item table - Item data
function SessionPanelMixin:AddMLControls(row, item)
    local frame = row:GetFrame()
    if not frame then return end

    -- Only add controls for PENDING items
    if item.state ~= Loothing.ItemState.PENDING then return end

    -- Delete button (remove item from session)
    if not frame._deleteButton then
        local deleteBtn = CreateFrame("Button", nil, frame)
        deleteBtn:SetSize(16, 16)
        deleteBtn:SetPoint("RIGHT", -4, 0)
        deleteBtn:SetNormalTexture("Interface\\Buttons\\UI-GroupLoot-Pass-Up")
        deleteBtn:SetHighlightTexture("Interface\\Buttons\\UI-GROUPLOOT-PASS-HIGHLIGHT")
        deleteBtn:SetScript("OnEnter", function(btn)
            GameTooltip:SetOwner(btn, "ANCHOR_RIGHT")
            GameTooltip:SetText("Remove from session", nil, nil, nil, nil, true)
            GameTooltip:Show()
        end)
        deleteBtn:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)
        frame._deleteButton = deleteBtn
    end

    frame._deleteButton:SetScript("OnClick", function()
        if Loothing.Session then
            Loothing.Session:RemoveItem(item.guid)
            self:RefreshItems()
        end
    end)
    frame._deleteButton:Show()

    -- Award Later checkbox
    if not frame._awardLaterCB then
        local cb = CreateFrame("CheckButton", nil, frame, "UICheckButtonTemplate")
        cb:SetSize(18, 18)
        cb:SetPoint("RIGHT", frame._deleteButton, "LEFT", -4, 0)

        local label = cb:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        label:SetPoint("RIGHT", cb, "LEFT", -2, 0)
        label:SetText("Later")
        label:SetTextColor(0.6, 0.6, 0.6)
        cb._label = label

        cb:SetScript("OnEnter", function(btn)
            GameTooltip:SetOwner(btn, "ANCHOR_RIGHT")
            GameTooltip:SetText("Award Later", 1, 0.82, 0)
            GameTooltip:AddLine("Mark this item to be awarded after the session", 1, 1, 1, true)
            GameTooltip:Show()
        end)
        cb:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)
        frame._awardLaterCB = cb
    end

    frame._awardLaterCB:SetChecked(item.awardLater or false)
    frame._awardLaterCB:SetScript("OnClick", function(cb)
        item.awardLater = cb:GetChecked()
    end)
    frame._awardLaterCB:Show()

    -- Reposition elements left to make room for ML controls
    -- Layout (right to left): [deleteBtn 16px] [CB 18px] ["Later" ~28px] [actionButton 70px] [statusText] [nameText]
    local actionButton = row.actionButton
    if actionButton then
        actionButton:ClearAllPoints()
        actionButton:SetPoint("RIGHT", frame._awardLaterCB._label, "LEFT", -4, 0)
    end
    local statusText = row.statusText
    if statusText then
        statusText:ClearAllPoints()
        statusText:SetPoint("RIGHT", actionButton, "LEFT", -8, 0)
        statusText:SetJustifyH("RIGHT")
    end
    local nameText = row.nameText
    if nameText then
        nameText:ClearAllPoints()
        nameText:SetPoint("TOPLEFT", row.icon, "TOPRIGHT", 6, -2)
        nameText:SetPoint("RIGHT", statusText, "LEFT", -8, 0)
    end
end

--[[--------------------------------------------------------------------
    Item Actions
----------------------------------------------------------------------]]

--- Handle item selection (supports Ctrl+click multi-select and Shift+click range)
function SessionPanelMixin:OnItemSelect(row, item)
    local isCtrl = IsControlKeyDown()
    local isShift = IsShiftKeyDown()

    if isCtrl then
        -- Ctrl+click: toggle individual item
        self:ToggleItemSelection(item)
    elseif isShift and self.lastClickedGuid then
        -- Shift+click: range select
        self:SelectRange(self.lastClickedGuid, item.guid)
    else
        -- Plain click: clear all, select one
        self:ClearSelection()
        self:SelectItem(item)
    end

    self.lastClickedGuid = item.guid

    -- Update visuals
    self:UpdateSelectionVisuals()
    self:UpdateSelectionState()

    self:TriggerEvent("OnItemSelected", item)
end

--- Start voting for an item
function SessionPanelMixin:OnStartVote(item)
    if not Loothing.Session then return end

    Loothing.Session:StartVoting(item.guid)
    self:RefreshItems()
end

--- End voting for an item
function SessionPanelMixin:OnEndVote(item)
    if not Loothing.Session then return end

    Loothing.Session:EndVoting(item.guid)
    self:RefreshItems()
end

--- Open vote panel for an item (routes to RollFrame since VotePanel is disabled)
function SessionPanelMixin:OnVote(item)
    if Loothing.UI and Loothing.UI.RollFrame then
        Loothing.UI.RollFrame:SetItem(item)
    end
end

--- Open award dialog for an item
function SessionPanelMixin:OnAward(item)
    if Loothing.UI and Loothing.UI.ResultsPanel then
        Loothing.UI.ResultsPanel:SetItem(item)
    end
end

--- View results for an item
function SessionPanelMixin:OnViewResults(item)
    if Loothing.UI and Loothing.UI.ResultsPanel then
        Loothing.UI.ResultsPanel:SetItem(item)
    end
end

--- Skip an item
function SessionPanelMixin:OnSkip(item)
    if not Loothing.Session then return end

    Loothing.Session:SkipItem(item.guid)
    self:RefreshItems()
end

--- Start revote for an item
function SessionPanelMixin:OnRevote(item)
    if not Loothing.Session then return end

    Loothing.Session:RevoteItem(item.guid)

    self:RefreshItems()
end

--[[--------------------------------------------------------------------
    Session Controls
----------------------------------------------------------------------]]

--- Handle session button click
function SessionPanelMixin:OnSessionButtonClick()
    if not Loothing.Session then return end

    local state = Loothing.Session:GetState()

    if state == Loothing.SessionState.INACTIVE then
        Loothing.Session:StartSession()
        self:TriggerEvent("OnStartSession")
    else
        Loothing.Session:EndSession()
        self:TriggerEvent("OnEndSession")
    end

    self:Refresh()
end

--- Start voting on all pending items
function SessionPanelMixin:OnStartAllClick()
    if not Loothing.Session then return end

    local items = Loothing.Session:GetItems()
    if not items then return end

    for _, item in items:Enumerate() do
        if item.state == Loothing.ItemState.PENDING then
            Loothing.Session:StartVoting(item.guid)
        end
    end

    self:RefreshItems()
end

--[[--------------------------------------------------------------------
    Frame Access
----------------------------------------------------------------------]]

function SessionPanelMixin:GetFrame()
    return self.frame
end

function SessionPanelMixin:Show()
    self.frame:Show()
    self:Refresh()
end

function SessionPanelMixin:Hide()
    self.frame:Hide()
end

--[[--------------------------------------------------------------------
    Factory
----------------------------------------------------------------------]]

local function CreateSessionPanel(parent)
    local panel = Loolib.CreateFromMixins(SessionPanelMixin)
    panel:Init(parent)
    return panel
end

ns.CreateSessionPanel = CreateSessionPanel
