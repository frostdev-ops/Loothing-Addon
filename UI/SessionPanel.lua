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
    self.itemRows = {}

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

--- Create item list
function LoothingSessionPanelMixin:CreateItemList()
    local L = LOOTHING_LOCALE

    -- List container
    local container = CreateFrame("Frame", nil, self.frame, "BackdropTemplate")
    container:SetPoint("TOPLEFT", 8, -66)
    container:SetPoint("BOTTOMRIGHT", -8, 50)
    container:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        tileSize = 8,
        edgeSize = 12,
        insets = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    container:SetBackdropColor(0.05, 0.05, 0.05, 0.9)

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
    content:SetSize(scrollFrame:GetWidth(), 800)
    scrollFrame:SetScrollChild(content)

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

    Loothing.Session:RegisterCallback("OnItemAdded", function(item)
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
        return
    end

    local state = Loothing.Session:GetState()

    if isML then
        self.sessionButton:Show()

        if state == LOOTHING_SESSION_STATE.INACTIVE then
            self.sessionButton:SetText(L["START_SESSION"])
            self.sessionButton:Enable()
            self.startAllButton:Hide()
        elseif state == LOOTHING_SESSION_STATE.ACTIVE then
            self.sessionButton:SetText(L["END_SESSION"])
            self.sessionButton:Enable()

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
        end
    else
        self.sessionButton:Hide()
        self.startAllButton:Hide()
    end
end

--- Refresh item list
function LoothingSessionPanelMixin:RefreshItems()
    -- Clear existing rows
    for _, row in ipairs(self.itemRows) do
        if row.frame then
            row.frame:Hide()
        end
    end
    wipe(self.itemRows)

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

    local yOffset = 0
    local rowHeight = 44
    local spacing = 2

    for _, item in items:Enumerate() do
        local row = CreateLoothingItemRow(self.listContent)
        row:SetItem(item)
        row:SetWidth(self.listContent:GetWidth())

        row:GetFrame():SetPoint("TOPLEFT", 0, yOffset)
        row:GetFrame():SetPoint("TOPRIGHT", 0, yOffset)
        row:GetFrame():Show()

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

--- Open vote panel for an item
function LoothingSessionPanelMixin:OnVote(item)
    if Loothing.UI and Loothing.UI.VotePanel then
        Loothing.UI.VotePanel:SetItem(item)
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

    -- Reset item state and start voting again
    if item.StartVoting then
        item.votes:Flush()
        item:SetState(LOOTHING_ITEM_STATE.PENDING)
        Loothing.Session:StartVoting(item.guid)
    end

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
