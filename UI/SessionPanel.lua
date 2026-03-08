--[[--------------------------------------------------------------------
    Loothing - Loot Council Addon for WoW 12.0+
    SessionPanel - Active loot session view
----------------------------------------------------------------------]]

local Loolib = LibStub("Loolib")

--[[--------------------------------------------------------------------
    LoothingSessionPanelMixin
----------------------------------------------------------------------]]

LoothingSessionPanelMixin = LoolibCreateFromMixins(LoolibCallbackRegistryMixin)

local SESSION_PANEL_EVENTS = {
    "OnItemSelected",
    "OnStartSession",
    "OnEndSession",
}

--- Initialize the session panel
-- @param parent Frame - Parent frame (usually a tab content area)
function LoothingSessionPanelMixin:Init(parent)
    LoolibCallbackRegistryMixin.OnLoad(self)
    self:GenerateCallbackEvents(SESSION_PANEL_EVENTS)

    self.parent = parent
    self.selectedItem = nil
    self.itemRows = {}      -- active rows (in use this frame)
    self.itemRowPool = {}   -- recycled rows waiting for reuse

    self:CreateFrame()
    self:CreateElements()
    self:RegisterEvents()
end

--- Create the main frame
function LoothingSessionPanelMixin:CreateFrame()
    local frame = CreateFrame("Frame", nil, self.parent)
    frame:SetAllPoints()

    self.frame = frame
end

--- Create UI elements
function LoothingSessionPanelMixin:CreateElements()
    local L = LOOTHING_LOCALE

    -- Header area
    self:CreateHeader()

    -- Filter bar
    self:CreateFilterBar()

    -- Item list area
    self:CreateItemList()

    -- Footer with controls
    self:CreateFooter()
end

--- Create header
function LoothingSessionPanelMixin:CreateHeader()
    local L = LOOTHING_LOCALE

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
function LoothingSessionPanelMixin:CreateFilterBar()
    -- Initialize filters if not already done
    if not Loothing.Filters then
        Loothing.Filters = LoolibCreateAndInitFromMixin(LoothingFiltersMixin)
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
function LoothingSessionPanelMixin:ToggleFilterBar()
    if self.filterBar:IsShown() then
        self.filterBar:Hide()
        self.listContainer:SetPoint("TOPLEFT", 8, -66)
    else
        self.filterBar:Show()
        self.listContainer:SetPoint("TOPLEFT", 8, -154)
    end
end

--- Create item list
function LoothingSessionPanelMixin:CreateItemList()
    local L = LOOTHING_LOCALE

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

--- Create footer with controls
function LoothingSessionPanelMixin:CreateFooter()
    local L = LOOTHING_LOCALE

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
function LoothingSessionPanelMixin:RegisterEvents()
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
function LoothingSessionPanelMixin:Refresh()
    self:UpdateHeader()
    self:UpdateFooter()
    self:RefreshItems()
end

--- Update header display
function LoothingSessionPanelMixin:UpdateHeader()
    local L = LOOTHING_LOCALE

    if not Loothing.Session then
        self.statusText:SetText(L["NO_SESSION"])
        self.statusText:SetTextColor(0.5, 0.5, 0.5)
        self.encounterText:SetText("")
        self.itemCountText:SetText("")
        self.mlIndicator:SetText("")
        return
    end

    local state = Loothing.Session:GetState()

    if state == LOOTHING_SESSION_STATE.INACTIVE then
        self.statusText:SetText(L["NO_SESSION"])
        self.statusText:SetTextColor(0.5, 0.5, 0.5)
        self.encounterText:SetText("")
        self.itemCountText:SetText("")
    elseif state == LOOTHING_SESSION_STATE.ACTIVE then
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
                if item.state == LOOTHING_ITEM_STATE.PENDING then
                    pending = pending + 1
                elseif item.state == LOOTHING_ITEM_STATE.VOTING then
                    voting = voting + 1
                elseif item.state == LOOTHING_ITEM_STATE.AWARDED or item.state == LOOTHING_ITEM_STATE.SKIPPED then
                    completed = completed + 1
                end
            end

            self.itemCountText:SetText(string.format(L["ITEMS_COUNT"], total, pending, voting, completed))
        end
    elseif state == LOOTHING_SESSION_STATE.CLOSED then
        self.statusText:SetText(L["SESSION_CLOSED"])
        self.statusText:SetTextColor(0.5, 0.5, 0.5)
    end

    -- ML indicator
    local isML = LoothingUtils.IsRaidLeaderOrAssistant()
    if isML then
        self.mlIndicator:SetText(L["YOU_ARE_ML"])
        self.mlIndicator:SetTextColor(1, 0.82, 0)
    else
        local ml = Loothing.Session:GetMasterLooter()
        if ml then
            self.mlIndicator:SetText(string.format(L["ML_IS"], LoothingUtils.GetShortName(ml)))
            self.mlIndicator:SetTextColor(0.7, 0.7, 0.7)
        else
            self.mlIndicator:SetText("")
        end
    end
end

--- Update footer buttons
function LoothingSessionPanelMixin:UpdateFooter()
    local L = LOOTHING_LOCALE
    local isML = LoothingUtils.IsRaidLeaderOrAssistant()

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

        if state == LOOTHING_SESSION_STATE.INACTIVE then
            self.sessionButton:SetText(L["START_SESSION"])
            self.sessionButton:Enable()
            self.startAllButton:Hide()
            self.addItemBtn:Hide()
            self.awardLaterCheck:Hide()
        elseif state == LOOTHING_SESSION_STATE.ACTIVE then
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
                    if item.state == LOOTHING_ITEM_STATE.PENDING then
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
function LoothingSessionPanelMixin:SortItems(items)
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
function LoothingSessionPanelMixin:AcquireItemRow()
    local row = table.remove(self.itemRowPool)
    if not row then
        row = CreateLoothingItemRow(self.listContent)
    end
    return row
end

--- Release all active rows back to the pool
function LoothingSessionPanelMixin:ReleaseAllItemRows()
    for _, row in ipairs(self.itemRows) do
        LoothingItemRow_Reset(nil, row)
        self.itemRowPool[#self.itemRowPool + 1] = row
    end
    wipe(self.itemRows)
end

--- Refresh item list
function LoothingSessionPanelMixin:RefreshItems()
    -- Return active rows to pool
    self:ReleaseAllItemRows()

    if not Loothing.Session then
        self.emptyText:Show()
        return
    end

    local items = Loothing.Session:GetItems()
    if not items or items:GetSize() == 0 then
        self.emptyText:Show()
        return
    end

    self.emptyText:Hide()

    -- Collect and sort items
    local itemArray = {}
    for _, item in items:Enumerate() do
        itemArray[#itemArray + 1] = item
    end
    itemArray = self:SortItems(itemArray)

    local isML = LoothingUtils.IsRaidLeaderOrAssistant()
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

        -- Highlight selected
        if self.selectedItem and self.selectedItem.guid == item.guid then
            row:SetSelected(true)
        end

        self.itemRows[#self.itemRows + 1] = row
        yOffset = yOffset - rowHeight - spacing
    end

    -- Update content height
    self.listContent:SetHeight(math.abs(yOffset) + 20)
end

--- Hide ML-only controls and restore the row's default layout.
-- @param row table - Item row
function LoothingSessionPanelMixin:ResetMLControls(row)
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
function LoothingSessionPanelMixin:AddMLControls(row, item)
    local frame = row:GetFrame()
    if not frame then return end

    -- Only add controls for PENDING items
    if item.state ~= LOOTHING_ITEM_STATE.PENDING then return end

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

--- Handle item selection
function LoothingSessionPanelMixin:OnItemSelect(row, item)
    -- Deselect previous
    for _, r in ipairs(self.itemRows) do
        r:SetSelected(false)
    end

    -- Select new
    self.selectedItem = item
    row:SetSelected(true)

    self:TriggerEvent("OnItemSelected", item)
end

--- Start voting for an item
function LoothingSessionPanelMixin:OnStartVote(item)
    if not Loothing.Session then return end

    Loothing.Session:StartVoting(item.guid)
    self:RefreshItems()
end

--- End voting for an item
function LoothingSessionPanelMixin:OnEndVote(item)
    if not Loothing.Session then return end

    Loothing.Session:EndVoting(item.guid)
    self:RefreshItems()
end

--- Open vote panel for an item (routes to RollFrame since VotePanel is disabled)
function LoothingSessionPanelMixin:OnVote(item)
    if Loothing.UI and Loothing.UI.RollFrame then
        Loothing.UI.RollFrame:SetItem(item)
    end
end

--- Open award dialog for an item
function LoothingSessionPanelMixin:OnAward(item)
    if Loothing.UI and Loothing.UI.ResultsPanel then
        Loothing.UI.ResultsPanel:SetItem(item)
    end
end

--- View results for an item
function LoothingSessionPanelMixin:OnViewResults(item)
    if Loothing.UI and Loothing.UI.ResultsPanel then
        Loothing.UI.ResultsPanel:SetItem(item)
    end
end

--- Skip an item
function LoothingSessionPanelMixin:OnSkip(item)
    if not Loothing.Session then return end

    Loothing.Session:SkipItem(item.guid)
    self:RefreshItems()
end

--- Start revote for an item
function LoothingSessionPanelMixin:OnRevote(item)
    if not Loothing.Session then return end

    Loothing.Session:RevoteItem(item.guid)

    self:RefreshItems()
end

--[[--------------------------------------------------------------------
    Session Controls
----------------------------------------------------------------------]]

--- Handle session button click
function LoothingSessionPanelMixin:OnSessionButtonClick()
    if not Loothing.Session then return end

    local state = Loothing.Session:GetState()

    if state == LOOTHING_SESSION_STATE.INACTIVE then
        Loothing.Session:StartSession()
        self:TriggerEvent("OnStartSession")
    else
        Loothing.Session:EndSession()
        self:TriggerEvent("OnEndSession")
    end

    self:Refresh()
end

--- Start voting on all pending items
function LoothingSessionPanelMixin:OnStartAllClick()
    if not Loothing.Session then return end

    local items = Loothing.Session:GetItems()
    if not items then return end

    for _, item in items:Enumerate() do
        if item.state == LOOTHING_ITEM_STATE.PENDING then
            Loothing.Session:StartVoting(item.guid)
        end
    end

    self:RefreshItems()
end

--[[--------------------------------------------------------------------
    Frame Access
----------------------------------------------------------------------]]

function LoothingSessionPanelMixin:GetFrame()
    return self.frame
end

function LoothingSessionPanelMixin:Show()
    self.frame:Show()
    self:Refresh()
end

function LoothingSessionPanelMixin:Hide()
    self.frame:Hide()
end

--[[--------------------------------------------------------------------
    Factory
----------------------------------------------------------------------]]

function CreateLoothingSessionPanel(parent)
    local panel = LoolibCreateFromMixins(LoothingSessionPanelMixin)
    panel:Init(parent)
    return panel
end
