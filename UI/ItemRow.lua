--[[--------------------------------------------------------------------
    Loothing - Loot Council Addon for WoW 12.0+
    ItemRow - Individual loot item display row
----------------------------------------------------------------------]]

local Loolib = LibStub("Loolib")

--[[--------------------------------------------------------------------
    Constants
----------------------------------------------------------------------]]

local ROW_HEIGHT = 44
local ICON_SIZE = 36
local PADDING = 4

--[[--------------------------------------------------------------------
    LoothingItemRowMixin
----------------------------------------------------------------------]]

LoothingItemRowMixin = {}

--- Initialize the item row
-- @param parent Frame - Parent frame
function LoothingItemRowMixin:Init(parent)
    self.parent = parent
    self.item = nil
    self.isSelected = false
    self.callbacks = {}

    self:CreateElements()
    self:SetupScripts()
end

--- Create UI elements
function LoothingItemRowMixin:CreateElements()
    -- Main frame
    self.frame = CreateFrame("Button", nil, self.parent)
    self.frame:SetHeight(ROW_HEIGHT)
    self.frame.mixin = self

    -- Background
    self.bg = self.frame:CreateTexture(nil, "BACKGROUND")
    self.bg:SetAllPoints()
    self.bg:SetColorTexture(0.1, 0.1, 0.1, 0.5)

    -- Highlight
    self.highlight = self.frame:CreateTexture(nil, "HIGHLIGHT")
    self.highlight:SetAllPoints()
    self.highlight:SetColorTexture(1, 1, 1, 0.1)

    -- Selection indicator
    self.selection = self.frame:CreateTexture(nil, "BORDER")
    self.selection:SetAllPoints()
    self.selection:SetColorTexture(0.3, 0.5, 0.8, 0.3)
    self.selection:Hide()

    -- Item icon
    self.icon = self.frame:CreateTexture(nil, "ARTWORK")
    self.icon:SetSize(ICON_SIZE, ICON_SIZE)
    self.icon:SetPoint("LEFT", PADDING, 0)

    -- Icon border (quality color)
    self.iconBorder = self.frame:CreateTexture(nil, "OVERLAY")
    self.iconBorder:SetSize(ICON_SIZE + 2, ICON_SIZE + 2)
    self.iconBorder:SetPoint("CENTER", self.icon, "CENTER")
    self.iconBorder:SetTexture("Interface\\Common\\WhiteIconFrame")

    -- Item name
    self.nameText = self.frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    self.nameText:SetPoint("TOPLEFT", self.icon, "TOPRIGHT", PADDING, -2)
    self.nameText:SetPoint("RIGHT", -150, 0)
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

    -- Status text
    self.statusText = self.frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    self.statusText:SetPoint("RIGHT", -100, 0)
    self.statusText:SetJustifyH("RIGHT")

    -- Vote count / Timer
    self.infoText = self.frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    self.infoText:SetPoint("RIGHT", self.statusText, "LEFT", -8, 0)
    self.infoText:SetJustifyH("RIGHT")
    self.infoText:SetTextColor(1, 1, 1)

    -- Action button
    self.actionButton = CreateFrame("Button", nil, self.frame, "UIPanelButtonTemplate")
    self.actionButton:SetSize(70, 22)
    self.actionButton:SetPoint("RIGHT", -PADDING, 0)
    self.actionButton:SetScript("OnClick", function()
        self:OnActionClick()
    end)

    -- Winner text (shown when awarded)
    self.winnerText = self.frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    self.winnerText:SetPoint("RIGHT", self.actionButton, "LEFT", -8, 0)
    self.winnerText:SetJustifyH("RIGHT")
    self.winnerText:Hide()
end

--- Setup event scripts
function LoothingItemRowMixin:SetupScripts()
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
function LoothingItemRowMixin:SetItem(item)
    self.item = item
    self:Refresh()
end

--- Get the item data
-- @return table|nil
function LoothingItemRowMixin:GetItem()
    return self.item
end

--- Refresh the display
function LoothingItemRowMixin:Refresh()
    if not self.item then
        self:Clear()
        return
    end

    local L = LOOTHING_LOCALE

    -- Icon
    local texture = self.item.texture or GetItemIcon(self.item.itemID or 0)
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

    -- Slot
    if self.item.equipSlot and self.item.equipSlot ~= "" then
        local slotName = _G[self.item.equipSlot] or self.item.equipSlot
        self.slotText:SetText(slotName)
    else
        self.slotText:SetText("")
    end

    -- Status
    self:UpdateStatus()

    -- Action button
    self:UpdateActionButton()

    -- Winner
    self:UpdateWinner()
end

--- Update status display
function LoothingItemRowMixin:UpdateStatus()
    if not self.item then return end

    local L = LOOTHING_LOCALE
    local state = self.item.state or LOOTHING_ITEM_STATE.PENDING

    if state == LOOTHING_ITEM_STATE.PENDING then
        self.statusText:SetText(L["STATUS_PENDING"])
        self.statusText:SetTextColor(0.7, 0.7, 0.7)
        self.infoText:SetText("")

    elseif state == LOOTHING_ITEM_STATE.VOTING then
        self.statusText:SetText(L["STATUS_VOTING"])
        self.statusText:SetTextColor(0, 1, 0)

        -- Show vote count or time remaining
        local voteCount = self.item:GetVoteCount()
        local timeRemaining = self.item:GetTimeRemaining()

        if timeRemaining > 0 then
            self.infoText:SetText(string.format("%ds", math.ceil(timeRemaining)))
            self.infoText:SetTextColor(1, 1, 0)
        else
            self.infoText:SetText(string.format("%d %s", voteCount, L["VOTES"]))
            self.infoText:SetTextColor(1, 1, 1)
        end

    elseif state == LOOTHING_ITEM_STATE.TALLIED then
        self.statusText:SetText(L["STATUS_TALLIED"])
        self.statusText:SetTextColor(1, 0.82, 0)

        local voteCount = self.item:GetVoteCount()
        self.infoText:SetText(string.format("%d %s", voteCount, L["VOTES"]))
        self.infoText:SetTextColor(1, 1, 1)

    elseif state == LOOTHING_ITEM_STATE.AWARDED then
        self.statusText:SetText(L["STATUS_AWARDED"])
        self.statusText:SetTextColor(0.2, 0.8, 0.2)
        self.infoText:SetText("")

    elseif state == LOOTHING_ITEM_STATE.SKIPPED then
        self.statusText:SetText(L["STATUS_SKIPPED"])
        self.statusText:SetTextColor(0.5, 0.5, 0.5)
        self.infoText:SetText("")
    end
end

--- Update action button
function LoothingItemRowMixin:UpdateActionButton()
    if not self.item then
        self.actionButton:Hide()
        return
    end

    local L = LOOTHING_LOCALE
    local state = self.item.state or LOOTHING_ITEM_STATE.PENDING
    local isML = LoothingUtils.IsRaidLeaderOrAssistant()
    local isCouncil = Loothing.Council and Loothing.Council:IsPlayerCouncilMember()

    if state == LOOTHING_ITEM_STATE.PENDING then
        if isML then
            self.actionButton:SetText(L["START_VOTE"])
            self.actionButton:Show()
            self.actionButton:Enable()
        else
            self.actionButton:Hide()
        end

    elseif state == LOOTHING_ITEM_STATE.VOTING then
        if isCouncil then
            local hasVoted = self.item:HasVoted(LoothingUtils.GetPlayerName())
            if hasVoted then
                self.actionButton:SetText(L["CHANGE_VOTE"])
            else
                self.actionButton:SetText(L["VOTE"])
            end
            self.actionButton:Show()
            self.actionButton:Enable()
        elseif isML then
            self.actionButton:SetText(L["END_VOTE"])
            self.actionButton:Show()
            self.actionButton:Enable()
        else
            self.actionButton:Hide()
        end

    elseif state == LOOTHING_ITEM_STATE.TALLIED then
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
function LoothingItemRowMixin:UpdateWinner()
    if not self.item then
        self.winnerText:Hide()
        return
    end

    if self.item.state == LOOTHING_ITEM_STATE.AWARDED and self.item.winner then
        local winnerName = LoothingUtils.GetShortName(self.item.winner)
        -- Try to get class color
        local coloredName = winnerName
        if IsInRaid() then
            local roster = LoothingUtils.GetRaidRoster()
            for _, entry in ipairs(roster) do
                if LoothingUtils.IsSamePlayer(self.item.winner, entry.name) then
                    coloredName = LoothingUtils.ColorByClass(winnerName, entry.classFile)
                    break
                end
            end
        end

        self.winnerText:SetText(coloredName)
        self.winnerText:Show()
    else
        self.winnerText:Hide()
    end
end

--- Clear the display
function LoothingItemRowMixin:Clear()
    self.item = nil

    self.icon:SetTexture(nil)
    self.iconBorder:SetVertexColor(1, 1, 1)
    self.nameText:SetText("")
    self.ilvlText:SetText("")
    self.slotText:SetText("")
    self.statusText:SetText("")
    self.infoText:SetText("")
    self.winnerText:Hide()
    self.actionButton:Hide()
end

--[[--------------------------------------------------------------------
    Selection
----------------------------------------------------------------------]]

--- Set selected state
-- @param selected boolean
function LoothingItemRowMixin:SetSelected(selected)
    self.isSelected = selected

    if selected then
        self.selection:Show()
    else
        self.selection:Hide()
    end
end

--- Get selected state
-- @return boolean
function LoothingItemRowMixin:IsSelected()
    return self.isSelected
end

--[[--------------------------------------------------------------------
    Events
----------------------------------------------------------------------]]

--- Handle mouse enter
function LoothingItemRowMixin:OnEnter()
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
        GameTooltip:AddLine(string.format(LOOTHING_LOCALE["LOOTED_BY"], self.item.looter), 1, 0.82, 0)
    end

    GameTooltip:Show()
end

--- Handle mouse leave
function LoothingItemRowMixin:OnLeave()
    GameTooltip:Hide()
end

--- Handle click
-- @param button string
function LoothingItemRowMixin:OnClick(button)
    if button == "LeftButton" then
        -- Select this row
        if self.callbacks.onSelect then
            self.callbacks.onSelect(self, self.item)
        end
    elseif button == "RightButton" then
        -- Show context menu
        self:ShowContextMenu()
    end
end

--- Handle action button click
function LoothingItemRowMixin:OnActionClick()
    if not self.item then return end

    local state = self.item.state or LOOTHING_ITEM_STATE.PENDING

    if state == LOOTHING_ITEM_STATE.PENDING then
        -- Start voting
        if self.callbacks.onStartVote then
            self.callbacks.onStartVote(self, self.item)
        end

    elseif state == LOOTHING_ITEM_STATE.VOTING then
        local isML = LoothingUtils.IsRaidLeaderOrAssistant()
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

    elseif state == LOOTHING_ITEM_STATE.TALLIED then
        local isML = LoothingUtils.IsRaidLeaderOrAssistant()
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
function LoothingItemRowMixin:ShowContextMenu()
    if not self.item then return end

    local L = LOOTHING_LOCALE
    local isML = LoothingUtils.IsRaidLeaderOrAssistant()

    local menu = {
        { text = self.item.name or "Item", isTitle = true, notCheckable = true },
    }

    if isML then
        if self.item.state == LOOTHING_ITEM_STATE.PENDING then
            table.insert(menu, {
                text = L["START_VOTE"],
                notCheckable = true,
                func = function()
                    if self.callbacks.onStartVote then
                        self.callbacks.onStartVote(self, self.item)
                    end
                end
            })
            table.insert(menu, {
                text = L["SKIP_ITEM"],
                notCheckable = true,
                func = function()
                    if self.callbacks.onSkip then
                        self.callbacks.onSkip(self, self.item)
                    end
                end
            })
        elseif self.item.state == LOOTHING_ITEM_STATE.VOTING then
            table.insert(menu, {
                text = L["END_VOTE"],
                notCheckable = true,
                func = function()
                    if self.callbacks.onEndVote then
                        self.callbacks.onEndVote(self, self.item)
                    end
                end
            })
        elseif self.item.state == LOOTHING_ITEM_STATE.TALLIED then
            table.insert(menu, {
                text = L["AWARD"],
                notCheckable = true,
                func = function()
                    if self.callbacks.onAward then
                        self.callbacks.onAward(self, self.item)
                    end
                end
            })
            table.insert(menu, {
                text = L["RE_VOTE"],
                notCheckable = true,
                func = function()
                    if self.callbacks.onRevote then
                        self.callbacks.onRevote(self, self.item)
                    end
                end
            })
        end
    end

    -- Link in chat
    if self.item.itemLink then
        table.insert(menu, {
            text = L["LINK_IN_CHAT"],
            notCheckable = true,
            func = function()
                ChatEdit_InsertLink(self.item.itemLink)
            end
        })
    end

    if EasyMenu and #menu > 1 then
        EasyMenu(menu, CreateFrame("Frame", "LoothingItemRowMenu", UIParent, "UIDropDownMenuTemplate"), "cursor", 0, 0, "MENU")
    end
end

--[[--------------------------------------------------------------------
    Callbacks
----------------------------------------------------------------------]]

--- Set callback
-- @param event string - Event name
-- @param callback function
function LoothingItemRowMixin:SetCallback(event, callback)
    self.callbacks[event] = callback
end

--[[--------------------------------------------------------------------
    Frame Access
----------------------------------------------------------------------]]

--- Get the frame
-- @return Frame
function LoothingItemRowMixin:GetFrame()
    return self.frame
end

--- Set frame width
-- @param width number
function LoothingItemRowMixin:SetWidth(width)
    self.frame:SetWidth(width)
end

--- Set frame height
-- @param height number
function LoothingItemRowMixin:SetHeight(height)
    self.frame:SetHeight(height)
end

--[[--------------------------------------------------------------------
    Factory
----------------------------------------------------------------------]]

--- Create a new item row
-- @param parent Frame
-- @return table - LoothingItemRow
function CreateLoothingItemRow(parent)
    local row = LoolibCreateFromMixins(LoothingItemRowMixin)
    row:Init(parent)
    return row
end

--[[--------------------------------------------------------------------
    Pool Reset Function
----------------------------------------------------------------------]]

--- Reset function for frame pool
-- @param pool table - Pool reference
-- @param row table - Row to reset
function LoothingItemRow_Reset(pool, row)
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
