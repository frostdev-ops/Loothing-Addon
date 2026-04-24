--[[--------------------------------------------------------------------
    Loothing - Loot Council Addon for WoW 12.0+
    ItemRow - Individual loot item display row
----------------------------------------------------------------------]]

local _, ns = ...
local Loolib = LibStub("Loolib")
local Loothing = ns.Addon
local Utils = ns.Utils

--[[--------------------------------------------------------------------
    Constants
----------------------------------------------------------------------]]

local ROW_HEIGHT = 44
local ICON_SIZE = 36
local PADDING = 4

--[[--------------------------------------------------------------------
    ItemRowMixin
----------------------------------------------------------------------]]

local ItemRowMixin = ns.ItemRowMixin or {}
ns.ItemRowMixin = ItemRowMixin

local function HasMasterLooterVisibility()
    return Loothing.HasMasterLooterVisibility
        and Loothing:HasMasterLooterVisibility()
end

local function CanSeeVoteCounts()
    local isML = HasMasterLooterVisibility()
    if Loothing.Settings and Loothing.Settings:GetHideVotes() and not isML then
        return false
    end
    return not Loothing.Observer or Loothing.Observer:CanPlayerSeeVoteCounts()
end

--- Initialize the item row
-- @param parent Frame - Parent frame
function ItemRowMixin:Init(parent)
    self.parent = parent
    self.item = nil
    self.isSelected = false
    self.callbacks = {}

    self:CreateElements()
    self:SetupScripts()
end

--- Create UI elements
function ItemRowMixin:CreateElements()
    -- Main frame
    self.frame = CreateFrame("Button", nil, self.parent, "BackdropTemplate")
    self.frame:SetHeight(ROW_HEIGHT)
    self.frame.mixin = self

    -- Enhanced backdrop
    self.frame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        tile = false,
        edgeSize = 1,
        insets = { left = 0, right = 0, top = 0, bottom = 0 },
    })
    self.frame:SetBackdropColor(0.12, 0.12, 0.12, 0.8)
    self.frame:SetBackdropBorderColor(0.25, 0.25, 0.25, 1)

    -- Background (alias to frame for color updates)
    self.bg = self.frame

    -- Highlight
    self.highlight = self.frame:CreateTexture(nil, "HIGHLIGHT")
    self.highlight:SetAllPoints()
    self.highlight:SetColorTexture(1, 1, 1, 0.05)

    -- Selection indicator (glow)
    self.selection = self.frame:CreateTexture(nil, "BACKGROUND", nil, -1)
    self.selection:SetAllPoints()
    self.selection:SetColorTexture(0.3, 0.3, 0.5, 0.3)
    self.selection:Hide()

    -- Selection border (overlay)
    self.selectionBorder = self.frame:CreateTexture(nil, "OVERLAY", nil, 7)
    self.selectionBorder:SetPoint("TOPLEFT")
    self.selectionBorder:SetPoint("BOTTOMLEFT")
    self.selectionBorder:SetWidth(3)
    self.selectionBorder:SetColorTexture(1, 0.82, 0, 1)
    self.selectionBorder:Hide()

    -- Item icon
    self.icon = self.frame:CreateTexture(nil, "ARTWORK")
    self.icon:SetSize(ICON_SIZE, ICON_SIZE)
    self.icon:SetPoint("LEFT", PADDING + 4, 0)

    -- Icon border (quality color)
    self.iconBorder = self.frame:CreateTexture(nil, "OVERLAY")
    self.iconBorder:SetSize(ICON_SIZE + 2, ICON_SIZE + 2)
    self.iconBorder:SetPoint("CENTER", self.icon, "CENTER")
    self.iconBorder:SetTexture("Interface\\Common\\WhiteIconFrame")

    -- Item name
    self.nameText = self.frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    self.nameText:SetJustifyH("LEFT")
    self.nameText:SetWordWrap(false)

    -- Item level
    self.ilvlText = self.frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    self.ilvlText:SetPoint("BOTTOMLEFT", self.icon, "BOTTOMRIGHT", PADDING, 2)
    self.ilvlText:SetJustifyH("LEFT")
    self.ilvlText:SetTextColor(1, 0.82, 0)

    -- Slot text
    self.slotText = self.frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    self.slotText:SetPoint("LEFT", self.ilvlText, "RIGHT", 8, 0)
    self.slotText:SetJustifyH("LEFT")
    self.slotText:SetTextColor(0.7, 0.7, 0.7)

    -- Action button (rightmost element in chain)
    self.actionButton = ns.CreateThemedButton(self.frame)
    self.actionButton:SetSize(70, 22)
    ns.SkinningMixin:StylePlainButton(self.actionButton)

    -- Status text (left of action button)
    self.statusText = self.frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")

    -- Vote count / Timer (left of status text)
    self.infoText = self.frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    self.infoText:SetTextColor(1, 1, 1)

    self.actionButton:SetScript("OnClick", function()
        self:OnActionClick()
    end)

    -- Winner text (shown when awarded)
    self.winnerText = self.frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    self.winnerText:SetJustifyH("RIGHT")
    self.winnerText:SetWordWrap(false)
    self.winnerText:Hide()

    -- Trophy glyph shown alongside the winner name when the item is awarded.
    self.winnerTrophy = self.frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    Loolib.Fonts:SetIconFont(self.winnerTrophy, 12, "")
    self.winnerTrophy:SetText(Loolib.Fonts:Icon("trophy"))
    self.winnerTrophy:SetTextColor(1.0, 0.82, 0.0)
    self.winnerTrophy:Hide()

    self:ApplyDefaultLayout()
end

--- Setup event scripts
function ItemRowMixin:SetupScripts()
    self.frame:SetScript("OnEnter", function()
        self:OnEnter()
    end)

    self.frame:SetScript("OnLeave", function()
        self:OnLeave()
    end)

    self.frame:SetScript("OnClick", function(_, btn)
        self:OnClick(btn)
    end)

    self.frame:RegisterForClicks("LeftButtonUp", "RightButtonUp")
end

--[[--------------------------------------------------------------------
    Data Binding
----------------------------------------------------------------------]]

--- Set the item data
-- @param item table - LoothingItem
function ItemRowMixin:SetItem(item)
    self.item = item
    self:Refresh()

    -- Tier tokens (and any cold-cache item) resolve equipSlot/classesFlag
    -- asynchronously inside ItemMixin:LoadItemInfo. Re-render once the info
    -- arrives so the slot label and "(Token)" badge appear without waiting
    -- for an external redraw.
    if item and not item.itemInfoLoaded and item.RegisterCallback then
        item:RegisterCallback("OnItemInfoLoaded", function()
            if item.UnregisterCallback then
                item:UnregisterCallback("OnItemInfoLoaded", self)
            end
            if self.item == item then
                self:Refresh()
            end
        end, self)
    end
end

--- Get the item data
-- @return table|nil
function ItemRowMixin:GetItem()
    return self.item
end

--- Refresh the display
function ItemRowMixin:Refresh()
    if not self.item then
        self:Clear()
        return
    end

    -- Icon
    local texture = self.item.texture or C_Item.GetItemIconByID(self.item.itemID or 0)
    self.icon:SetTexture(texture or "Interface\\Icons\\INV_Misc_QuestionMark")

    -- Quality color
    local quality = self.item.quality or 1
    local r, g, b = C_Item.GetItemQualityColor(quality)
    self.iconBorder:SetVertexColor(r, g, b)
    self.nameText:SetTextColor(r, g, b)

    -- Name
    self.nameText:SetText(self.item.name or self.item.itemLink or "Unknown Item")

    -- Item level
    if self.item.itemLevel and self.item.itemLevel > 0 then
        self.ilvlText:SetText(string.format("ilvl %d", self.item.itemLevel))
    else
        self.ilvlText:SetText("")
    end

    -- Slot (FormatItemSlot handles equipSlot, tokenSlot fallback, and the
    -- " (Token)" badge in one call.)
    self.slotText:SetText(
        (ns.TokenData and ns.TokenData:FormatItemSlot(self.item)) or "")

    -- Status
    self:UpdateStatus()

    -- Action button
    self:UpdateActionButton()

    -- Winner
    self:UpdateWinner()

    -- Keep the text chain aligned for the current item state.
    self:UpdateLayout()
end

--- Restore the default row layout used outside ML-only pending controls.
function ItemRowMixin:ApplyDefaultLayout()
    self.actionButton:ClearAllPoints()
    self.actionButton:SetPoint("RIGHT", -PADDING, 0)

    self.statusText:ClearAllPoints()
    self.statusText:SetPoint("RIGHT", self.actionButton, "LEFT", -8, 0)
    self.statusText:SetJustifyH("RIGHT")

    self.infoText:ClearAllPoints()
    self.infoText:SetPoint("RIGHT", self.statusText, "LEFT", -8, 0)
    self.infoText:SetJustifyH("RIGHT")

    self.nameText:ClearAllPoints()
    self.nameText:SetPoint("TOPLEFT", self.icon, "TOPRIGHT", PADDING + 2, -2)
    self.nameText:SetPoint("RIGHT", self.infoText, "LEFT", -8, 0)

    self.winnerText:ClearAllPoints()
    self.winnerText:SetWidth(0)
    self.winnerText:SetPoint("RIGHT", self.actionButton, "LEFT", -8, 0)
    self.winnerText:SetJustifyH("RIGHT")
    self.winnerText:SetWordWrap(false)
end

--- Adjust the row layout for the current display state.
function ItemRowMixin:UpdateLayout()
    local isAwarded = self.item and self.item.state == Loothing.ItemState.AWARDED and self.item.winner

    if isAwarded == self._layoutAwarded then return end
    self._layoutAwarded = isAwarded

    if isAwarded then
        -- Awarded chain: nameText → winnerTrophy → winnerText → statusText → actionButton(hidden)
        self.winnerText:ClearAllPoints()
        self.winnerText:SetPoint("RIGHT", self.statusText, "LEFT", -8, 0)

        if self.winnerTrophy then
            self.winnerTrophy:ClearAllPoints()
            self.winnerTrophy:SetPoint("RIGHT", self.winnerText, "LEFT", -4, 0)
        end

        self.nameText:ClearAllPoints()
        self.nameText:SetPoint("TOPLEFT", self.icon, "TOPRIGHT", PADDING + 2, -2)
        self.nameText:SetPoint("RIGHT", self.winnerTrophy or self.winnerText, "LEFT", -8, 0)
    else
        self:ApplyDefaultLayout()
    end
end

--- Update status display
function ItemRowMixin:UpdateStatus()
    if not self.item then return end

    local L = Loothing.Locale
    local state = self.item.state or Loothing.ItemState.PENDING

    if state == Loothing.ItemState.PENDING then
        self.statusText:SetText(L["STATUS_PENDING"])
        self.statusText:SetTextColor(0.7, 0.7, 0.7)
        self.infoText:SetText("")

    elseif state == Loothing.ItemState.VOTING then
        self.statusText:SetText(L["STATUS_VOTING"])
        self.statusText:SetTextColor(0, 1, 0)

        -- Show vote count or time remaining
        local voteCount = self.item:GetVoteCount()
        local timeRemaining = self.item:GetTimeRemaining()
        local canSeeVotes = CanSeeVoteCounts()

        if timeRemaining == math.huge then
            self.infoText:SetText(L["NO_LIMIT"])
            self.infoText:SetTextColor(0.2, 0.8, 0.2)
        elseif timeRemaining > 0 then
            self.infoText:SetText(string.format("%ds", math.ceil(timeRemaining)))
            self.infoText:SetTextColor(1, 1, 0)
        elseif not canSeeVotes then
            self.infoText:SetText("")
        else
            self.infoText:SetText(string.format("%d %s", voteCount, L["VOTES"]))
            self.infoText:SetTextColor(1, 1, 1)
        end

    elseif state == Loothing.ItemState.TALLIED then
        self.statusText:SetText(L["STATUS_TALLIED"])
        self.statusText:SetTextColor(1, 0.82, 0)

        local canSeeVotes = CanSeeVoteCounts()
        local voteCount = self.item:GetVoteCount()
        if not canSeeVotes then
            self.infoText:SetText("")
        else
            self.infoText:SetText(string.format("%d %s", voteCount, L["VOTES"]))
            self.infoText:SetTextColor(1, 1, 1)
        end

    elseif state == Loothing.ItemState.AWARDED then
        self.statusText:SetText(L["STATUS_AWARDED"])
        self.statusText:SetTextColor(0.2, 0.8, 0.2)
        self.infoText:SetText("")

    elseif state == Loothing.ItemState.SKIPPED then
        self.statusText:SetText(L["STATUS_SKIPPED"])
        self.statusText:SetTextColor(0.5, 0.5, 0.5)
        self.infoText:SetText("")
    end
end

--- Update action button
function ItemRowMixin:UpdateActionButton()
    if not self.item then
        self.actionButton:Hide()
        return
    end

    local L = Loothing.Locale
    local state = self.item.state or Loothing.ItemState.PENDING
    local isML = HasMasterLooterVisibility()
    local isCouncil = Loothing.Council and Loothing.Council:IsPlayerCouncilMember()

    if state == Loothing.ItemState.PENDING then
        if isML then
            self.actionButton:SetText(L["START_VOTE"])
            self.actionButton:Show()
            self.actionButton:Enable()
        else
            self.actionButton:Hide()
        end

    elseif state == Loothing.ItemState.VOTING then
        if isML then
            self.actionButton:SetText(L["END_VOTE"])
            self.actionButton:Show()
            self.actionButton:Enable()
        elseif isCouncil then
            local hasVoted = self.item:HasVoted(Utils.GetPlayerFullName())
            if hasVoted then
                self.actionButton:SetText(L["CHANGE_VOTE"])
            else
                self.actionButton:SetText(L["VOTE"])
            end
            self.actionButton:Show()
            self.actionButton:Enable()
        else
            self.actionButton:Hide()
        end

    elseif state == Loothing.ItemState.TALLIED then
        if isML then
            self.actionButton:SetText(L["AWARD"])
            self.actionButton:Show()
            self.actionButton:Enable()
        else
            self.actionButton:SetText(L["VIEW"])
            self.actionButton:Show()
            self.actionButton:Enable()
        end

    else
        self.actionButton:Hide()
    end
end

--- Update winner display
function ItemRowMixin:UpdateWinner()
    if not self.item then
        self.winnerText:Hide()
        return
    end

    if self.item.state == Loothing.ItemState.AWARDED and self.item.winner then
        local winnerName = Utils.GetShortName(self.item.winner)
        -- Try to get class color
        local coloredName = winnerName
        if IsInGroup() then
            local roster = Utils.GetRaidRoster()
            for _, entry in ipairs(roster) do
                if Utils.IsSamePlayer(self.item.winner, entry.name) then
                    coloredName = Utils.ColorByClass(winnerName, entry.classFile)
                    break
                end
            end
        end

        self.winnerText:SetText(coloredName)
        self.winnerText:Show()
        -- Anchor is owned by UpdateLayout; only toggle visibility here.
        if self.winnerTrophy then self.winnerTrophy:Show() end
    else
        self.winnerText:Hide()
        if self.winnerTrophy then self.winnerTrophy:Hide() end
    end
end

--- Clear the display
function ItemRowMixin:Clear()
    self.item = nil
    self._layoutAwarded = nil

    self.icon:SetTexture(nil)
    self.iconBorder:SetVertexColor(1, 1, 1)
    self.nameText:SetText("")
    self.ilvlText:SetText("")
    self.slotText:SetText("")
    self.statusText:SetText("")
    self.infoText:SetText("")
    self.winnerText:Hide()
    if self.winnerTrophy then self.winnerTrophy:Hide() end
    self.actionButton:Hide()
    self:ApplyDefaultLayout()
end

--[[--------------------------------------------------------------------
    Selection
----------------------------------------------------------------------]]

--- Set selected state
-- @param selected boolean
function ItemRowMixin:SetSelected(selected)
    self.isSelected = selected

    if selected then
        self.selection:Show()
        self.selectionBorder:Show()
        self.frame:SetBackdropColor(0.2, 0.2, 0.3, 0.9)
        self.frame:SetBackdropBorderColor(0.5, 0.5, 0.6, 1)
    else
        self.selection:Hide()
        self.selectionBorder:Hide()
        self.frame:SetBackdropColor(0.12, 0.12, 0.12, 0.8)
        self.frame:SetBackdropBorderColor(0.25, 0.25, 0.25, 1)
    end
end

--- Get selected state
-- @return boolean
function ItemRowMixin:IsSelected()
    return self.isSelected
end

--[[--------------------------------------------------------------------
    Events
----------------------------------------------------------------------]]

--- Handle mouse enter
function ItemRowMixin:OnEnter()
    if not self.item then return end

    -- Show item tooltip
    GameTooltip:SetOwner(self.frame, "ANCHOR_RIGHT")

    if self.item.itemLink then
        GameTooltip:SetHyperlink(self.item.itemLink)
    else
        GameTooltip:AddLine(self.item.name or "Unknown Item")
    end

    -- Add loot info
    if self.item.looter then
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(string.format(Loothing.Locale["LOOTED_BY"], self.item.looter), 1, 0.82, 0)
    end

    GameTooltip:Show()
end

--- Handle mouse leave
function ItemRowMixin:OnLeave()
    GameTooltip:Hide()
end

--- Handle click
-- @param button string
function ItemRowMixin:OnClick(button)
    if button == "LeftButton" then
        -- Select this row
        if self.callbacks.onSelect then
            self.callbacks.onSelect(self, self.item)
        end
    elseif button == "RightButton" then
        -- Allow parent to intercept right-click (e.g. bulk context menu)
        if self.callbacks.onContextMenu and self.callbacks.onContextMenu(self, self.item) then
            return
        end
        -- Show context menu
        self:ShowContextMenu()
    end
end

--- Handle action button click
function ItemRowMixin:OnActionClick()
    if not self.item then return end

    local state = self.item.state or Loothing.ItemState.PENDING

    if state == Loothing.ItemState.PENDING then
        -- Start voting
        if self.callbacks.onStartVote then
            self.callbacks.onStartVote(self, self.item)
        end

    elseif state == Loothing.ItemState.VOTING then
        local isML = HasMasterLooterVisibility()
        if isML then
            -- End voting
            if self.callbacks.onEndVote then
                self.callbacks.onEndVote(self, self.item)
            end
        else
            -- Open vote panel
            if self.callbacks.onVote then
                self.callbacks.onVote(self, self.item)
            end
        end

    elseif state == Loothing.ItemState.TALLIED then
        local isML = HasMasterLooterVisibility()
        if isML then
            -- Open award dialog
            if self.callbacks.onAward then
                self.callbacks.onAward(self, self.item)
            end
        else
            -- View results
            if self.callbacks.onViewResults then
                self.callbacks.onViewResults(self, self.item)
            end
        end
    end
end

--- Show context menu
function ItemRowMixin:ShowContextMenu()
    if not self.item then return end

    local L = Loothing.Locale
    local isML = HasMasterLooterVisibility()

    MenuUtil.CreateContextMenu(self.frame, function(_, rootDescription)
        rootDescription:CreateTitle(self.item.name or "Item")

        if isML then
            if self.item.state == Loothing.ItemState.PENDING then
                rootDescription:CreateButton(L["START_VOTE"], function()
                    if self.callbacks.onStartVote then
                        self.callbacks.onStartVote(self, self.item)
                    end
                end)
                rootDescription:CreateButton(L["SKIP_ITEM"], function()
                    if self.callbacks.onSkip then
                        self.callbacks.onSkip(self, self.item)
                    end
                end)
            elseif self.item.state == Loothing.ItemState.VOTING then
                rootDescription:CreateButton(L["END_VOTE"], function()
                    if self.callbacks.onEndVote then
                        self.callbacks.onEndVote(self, self.item)
                    end
                end)
            elseif self.item.state == Loothing.ItemState.TALLIED then
                rootDescription:CreateButton(L["AWARD"], function()
                    if self.callbacks.onAward then
                        self.callbacks.onAward(self, self.item)
                    end
                end)
                rootDescription:CreateButton(L["RE_VOTE"], function()
                    if self.callbacks.onRevote then
                        self.callbacks.onRevote(self, self.item)
                    end
                end)
            end
        end

        -- Link in chat
        if self.item.itemLink then
            rootDescription:CreateButton(L["LINK_IN_CHAT"], function()
                ChatEdit_InsertLink(self.item.itemLink)
            end)
        end
    end)
end

--[[--------------------------------------------------------------------
    Callbacks
----------------------------------------------------------------------]]

--- Set callback
-- @param event string - Event name
-- @param callback function
function ItemRowMixin:SetCallback(event, callback)
    self.callbacks[event] = callback
end

--[[--------------------------------------------------------------------
    Frame Access
----------------------------------------------------------------------]]

--- Get the frame
-- @return Frame
function ItemRowMixin:GetFrame()
    return self.frame
end

--- Set frame width
-- @param width number
function ItemRowMixin:SetWidth(width)
    self.frame:SetWidth(width)
end

--- Set frame height
-- @param height number
function ItemRowMixin:SetHeight(height)
    self.frame:SetHeight(height)
end

--[[--------------------------------------------------------------------
    Factory
----------------------------------------------------------------------]]

--- Create a new item row
-- @param parent Frame
-- @return table - LoothingItemRow
local function CreateItemRow(parent)
    local row = Loolib.CreateFromMixins(ItemRowMixin)
    row:Init(parent)
    return row
end

ns.CreateItemRow = CreateItemRow

--[[--------------------------------------------------------------------
    Pool Reset Function
----------------------------------------------------------------------]]

--- Reset function for frame pool
-- @param pool table - Pool reference
-- @param row table - Row to reset
local function ResetItemRow(_, row)
    if row.Clear then
        row:Clear()
    end
    if row.SetSelected then
        row:SetSelected(false)
    end
    local frame = row.frame or row
    frame:Hide()
    frame:ClearAllPoints()
end

ns.ResetItemRow = ResetItemRow
