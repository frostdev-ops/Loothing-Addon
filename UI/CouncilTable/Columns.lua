--[[--------------------------------------------------------------------
    Loothing - UI: Council Table Columns
    Column definitions, sort mappings, header creation, and DoCellUpdate
----------------------------------------------------------------------]]

local _, ns = ...
local Loothing = ns.Addon
local Utils = ns.Utils
local L = Loothing.Locale

local CouncilTableMixin = ns.CouncilTableMixin or {}
ns.CouncilTableMixin = CouncilTableMixin

local CELL_PADDING = 2

CouncilTableMixin.COLUMNS = {
    { id = "priority",     name = "#",                              width = 30,  maxWidth = 36,  flex = 0, sortable = true,  settingsKey = "priority" },
    { id = "class",        name = "",                               width = 22,  maxWidth = 22,  flex = 0, sortable = true,  settingsKey = "class" },
    { id = "spec",         name = "",                               width = 24,  maxWidth = 24,  flex = 0, sortable = false, settingsKey = "spec" },
    { id = "player",       name = L["COUNCIL_COLUMN_PLAYER"],       width = 100, maxWidth = 180, flex = 2, stretch = 4, sortable = true,  settingsKey = "player" },
    { id = "role",         name = L["COLUMN_ROLE"],                 width = 30,  maxWidth = 36,  flex = 0, sortable = true,  settingsKey = "role" },
    { id = "response",     name = L["COUNCIL_COLUMN_RESPONSE"],     width = 120, maxWidth = 200, flex = 2, stretch = 4, sortable = true,  settingsKey = "response" },
    { id = "ilvl",         name = L["COUNCIL_COLUMN_ILVL"],         width = 40,  maxWidth = 48,  flex = 0, sortable = true,  settingsKey = "ilvl" },
    { id = "ilvlDiff",     name = L["COUNCIL_COLUMN_ILVL_DIFF"],    width = 40,  maxWidth = 48,  flex = 0, sortable = true,  settingsKey = "ilvlDiff" },
    { id = "wonSession",   name = L["COLUMN_WON"],                  width = 32,  maxWidth = 40,  flex = 0, sortable = true,  settingsKey = "wonSession" },
    { id = "wonInstance",  name = L["COLUMN_INST"],                 width = 32,  maxWidth = 40,  flex = 0, sortable = true,  settingsKey = "wonInstance" },
    { id = "wonWeekly",    name = L["COLUMN_WK"],                   width = 32,  maxWidth = 40,  flex = 0, sortable = true,  settingsKey = "wonWeekly" },
    { id = "gear1",        name = L["COUNCIL_COLUMN_GEAR1"],        width = 28,  maxWidth = 28,  flex = 0, sortable = false, settingsKey = "gear1" },
    { id = "gear2",        name = L["COUNCIL_COLUMN_GEAR2"],        width = 28,  maxWidth = 28,  flex = 0, sortable = false, settingsKey = "gear2" },
    { id = "roll",         name = L["COUNCIL_COLUMN_ROLL"],         width = 40,  maxWidth = 55,  flex = 1, sortable = true,  settingsKey = "roll" },
    { id = "note",         name = L["COUNCIL_COLUMN_NOTE"],         width = 24,  maxWidth = 28,  flex = 0, sortable = false, settingsKey = "note" },
    { id = "vote",         name = L["COLUMN_VOTE"],                 width = 55,  maxWidth = 70,  flex = 1, stretch = 1, sortable = true,  settingsKey = "vote" },
}

CouncilTableMixin.COLUMN_SORT_MAP = {
    priority = "priority",
    player = "name",
    class = "class",
    role = "role",
    response = "response",
    roll = "roll",
    ilvl = "ilvl",
    ilvlDiff = "ilvlDiff",
    vote = "councilVotes",
    wonSession = "itemsWonThisSession",
    wonInstance = "itemsWonInstance",
    wonWeekly = "itemsWonWeekly",
}

CouncilTableMixin.COLUMN_TOOLTIPS = {
    wonSession = L["COLUMN_TOOLTIP_WON_SESSION"],
    wonInstance = L["COLUMN_TOOLTIP_WON_INSTANCE"],
    wonWeekly = L["COLUMN_TOOLTIP_WON_WEEKLY"],
}

-- Role icon textures
local ROLE_ICONS = {
    TANK = "Interface\\LFGFrame\\UI-LFG-ICON-PORTRAITROLES",
    HEALER = "Interface\\LFGFrame\\UI-LFG-ICON-PORTRAITROLES",
    DAMAGER = "Interface\\LFGFrame\\UI-LFG-ICON-PORTRAITROLES",
}
local ROLE_COORDS = {
    TANK = { 0, 19/64, 22/64, 41/64 },
    HEALER = { 20/64, 39/64, 1/64, 20/64 },
    DAMAGER = { 20/64, 39/64, 22/64, 41/64 },
}

--[[--------------------------------------------------------------------
    Column Visibility
----------------------------------------------------------------------]]

function CouncilTableMixin:IsColumnVisible(columnId)
    -- Spec column is controlled by the frame.showSpecIcon setting
    if columnId == "spec" then
        return Loothing.Settings and Loothing.Settings:Get("frame.showSpecIcon") or false
    end

    if not Loothing.Settings then
        return true
    end
    local columns = Loothing.Settings:Get("councilTable.columns", {})
    if columns[columnId] == nil then
        return true
    end
    return columns[columnId]
end

function CouncilTableMixin:GetVisibleColumns()
    local visible = {}
    for _, column in ipairs(self.COLUMNS) do
        if self:IsColumnVisible(column.id) then
            visible[#visible + 1] = column
        end
    end
    return visible
end

function CouncilTableMixin:ToggleColumnVisibility(columnId)
    if not Loothing.Settings then return end
    local columns = Loothing.Settings:Get("councilTable.columns", {})
    local currentState = columns[columnId]
    if currentState == nil then currentState = true end
    columns[columnId] = not currentState
    Loothing.Settings:Set("councilTable.columns", columns)
    if self.RebuildColumnHeaders then self:RebuildColumnHeaders() end
    if self.RefreshCandidates then self:RefreshCandidates() end
end

--[[--------------------------------------------------------------------
    Column Layout
----------------------------------------------------------------------]]

local function DistributeRemainingWidth(widths, visible, extra, key)
    if extra <= 0 then
        return 0
    end

    local weighted = {}
    local totalWeight = 0
    for i, col in ipairs(visible) do
        local weight = col[key] or 0
        if weight > 0 then
            weighted[#weighted + 1] = { index = i, weight = weight }
            totalWeight = totalWeight + weight
        end
    end

    if totalWeight == 0 then
        return 0
    end

    local distributed = 0
    for _, entry in ipairs(weighted) do
        local bonus = math.floor(extra * entry.weight / totalWeight)
        widths[entry.index] = widths[entry.index] + bonus
        distributed = distributed + bonus
    end

    local remainder = extra - distributed
    local cursor = 1
    while remainder > 0 and #weighted > 0 do
        local entry = weighted[cursor]
        widths[entry.index] = widths[entry.index] + 1
        remainder = remainder - 1
        cursor = cursor + 1
        if cursor > #weighted then
            cursor = 1
        end
    end

    return extra
end

--- Compute column widths that fill available space proportionally.
-- Each column starts at its base width. Extra space is distributed to flex
-- columns up to their soft maxWidth, then any remaining space stretches the
-- most important columns so wide windows still use their available space.
-- @param availableWidth number - Total width to fill
-- @return table - Array of {col, computedWidth} matching visible column order
function CouncilTableMixin:ComputeColumnWidths(availableWidth)
    local visible = self:GetVisibleColumns()
    local padding = CELL_PADDING
    local totalPadding = math.max(0, #visible - 1) * padding
    local usable = availableWidth - totalPadding

    -- Start every column at its base width
    local widths = {}
    local totalBase = 0
    for i, col in ipairs(visible) do
        widths[i] = col.width
        totalBase = totalBase + col.width
    end

    local extra = math.max(0, usable - totalBase)

    -- Distribute extra space in passes (capped columns free space for others)
    if extra > 0 then
        local capped = {}
        for _ = 1, 4 do
            local totalFlex = 0
            for i, col in ipairs(visible) do
                if not capped[i] and (col.flex or 0) > 0 then
                    totalFlex = totalFlex + col.flex
                end
            end
            if totalFlex == 0 then break end

            local distributed = 0
            local newCap = false
            for i, col in ipairs(visible) do
                if not capped[i] and (col.flex or 0) > 0 then
                    local bonus = math.floor(extra * col.flex / totalFlex)
                    local maxW = col.maxWidth or (col.width * 3)
                    local target = col.width + bonus
                    if target > maxW then
                        target = maxW
                        capped[i] = true
                        newCap = true
                    end
                    distributed = distributed + (target - widths[i])
                    widths[i] = target
                end
            end
            extra = math.max(0, extra - distributed)
            if not newCap or extra < 1 then break end
        end
    end

    if extra > 0 then
        local stretchDistributed = DistributeRemainingWidth(widths, visible, extra, "stretch")
        extra = math.max(0, extra - stretchDistributed)
    end

    if extra > 0 then
        DistributeRemainingWidth(widths, visible, extra, "flex")
    end

    local result = {}
    for i, col in ipairs(visible) do
        result[#result + 1] = { col = col, width = widths[i] }
    end
    return result
end

--[[--------------------------------------------------------------------
    Column Headers
----------------------------------------------------------------------]]

function CouncilTableMixin:RebuildColumnHeaders()
    -- Clear existing headers
    if self.headerButtons then
        for _, btn in pairs(self.headerButtons) do
            btn:Hide()
        end
    end
    self.headerButtons = {}

    if not self.headersContainer then return end

    local containerWidth = self.scrollFrame and self.scrollFrame:GetWidth() or self.headersContainer:GetWidth()
    if containerWidth < 1 then containerWidth = 600 end -- fallback before layout
    local padding = CELL_PADDING
    local computed = self:ComputeColumnWidths(containerWidth)

    -- Cache computed widths for row creation
    self._computedColumnWidths = {}
    for _, entry in ipairs(computed) do
        self._computedColumnWidths[entry.col.id] = entry.width
    end

    local xOffset = 0
    for _, entry in ipairs(computed) do
        local col = entry.col
        local w = entry.width

        local btn = CreateFrame("Button", nil, self.headersContainer)
        btn:SetSize(w, 20)
        btn:SetPoint("LEFT", xOffset, 0)

        local text = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        text:SetPoint("LEFT", btn, "LEFT", 2, 0)
        text:SetPoint("RIGHT", btn, "RIGHT", col.sortable and -10 or -2, 0)
        text:SetJustifyH("CENTER")
        text:SetWordWrap(false)
        text:SetText(col.name)
        text:SetTextColor(0.8, 0.8, 0.6)
        btn.text = text

        -- Sort indicator
        local sortArrow = btn:CreateTexture(nil, "OVERLAY")
        sortArrow:SetSize(8, 8)
        sortArrow:SetPoint("RIGHT", -1, 0)
        sortArrow:SetTexture("Interface\\Buttons\\UI-SortArrow")
        sortArrow:Hide()
        btn.sortArrow = sortArrow

        if col.sortable then
            btn:SetScript("OnClick", function()
                self:OnColumnHeaderClick(col.id)
            end)
            btn:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
        end

        -- Show sort arrow for current sort column
        if self.sortColumn == col.id then
            sortArrow:Show()
            if self.sortAscending then
                sortArrow:SetTexCoord(0, 0.5625, 1, 0)
            else
                sortArrow:SetTexCoord(0, 0.5625, 0, 1)
            end
        end

        -- Column header tooltips
        local tooltip = self.COLUMN_TOOLTIPS and self.COLUMN_TOOLTIPS[col.id]
        if tooltip then
            btn:SetScript("OnEnter", function(b)
                GameTooltip:SetOwner(b, "ANCHOR_BOTTOM")
                GameTooltip:AddLine(tooltip, 1, 1, 1)
                GameTooltip:Show()
            end)
            btn:SetScript("OnLeave", function()
                GameTooltip:Hide()
            end)
        end

        self.headerButtons[col.id] = btn
        xOffset = xOffset + w + padding
    end

    -- Separator line below headers
    if not self.headerSep then
        self.headerSep = self.headersContainer:CreateTexture(nil, "ARTWORK")
        self.headerSep:SetHeight(1)
        self.headerSep:SetColorTexture(0.4, 0.4, 0.4, 1)
    end
    self.headerSep:SetPoint("TOPLEFT", self.headersContainer, "BOTTOMLEFT", 0, -2)
    self.headerSep:SetPoint("TOPRIGHT", self.headersContainer, "BOTTOMRIGHT", 0, -2)
end

function CouncilTableMixin:OnColumnHeaderClick(columnId)
    if self.sortColumn == columnId then
        self.sortAscending = not self.sortAscending
    else
        self.sortColumn = columnId
        self.sortAscending = true
    end

    self:RebuildColumnHeaders()
    self:RefreshCandidates()
    self:TriggerEvent("OnSortChanged", columnId, self.sortAscending)
end

--[[--------------------------------------------------------------------
    DoCellUpdate - Per-Column Cell Rendering
----------------------------------------------------------------------]]

--- Update a single cell based on column type
-- @param cell Frame - Cell frame with .text, .icon, .colorBar etc
-- @param col table - Column definition
-- @param candidate table - Candidate data
-- @param row Frame - Parent row frame
function CouncilTableMixin:DoCellUpdate(cell, col, candidate, row)
    local handler = self.CellUpdaters[col.id]
    if handler then
        handler(self, cell, candidate, row)
    end
end

CouncilTableMixin.CellUpdaters = {}

-- Priority / row number
CouncilTableMixin.CellUpdaters.priority = function(_, cell, _candidate, row)
    cell.text:SetText(tostring(row.rowIndex or ""))
    cell.text:SetTextColor(0.6, 0.6, 0.6)
end

-- Class icon
CouncilTableMixin.CellUpdaters.class = function(_, cell, candidate)
    local class = candidate.class
    if class and cell.icon then
        local coords = CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[class]
        cell.icon:SetTexture("Interface\\Glues\\CharacterCreate\\UI-CharacterCreate-Classes")
        if coords then
            cell.icon:SetTexCoord(unpack(coords))
        else
            cell.icon:SetTexCoord(0, 1, 0, 1)
        end
        cell.icon:Show()
    elseif cell.icon then
        cell.icon:Hide()
    end
end

-- Player name (class-colored)
CouncilTableMixin.CellUpdaters.player = function(_, cell, candidate)
    local name = candidate.shortName or candidate.name or "Unknown"
    local class = candidate.class

    if class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class] then
        local cc = RAID_CLASS_COLORS[class]
        cell.text:SetText(name)
        cell.text:SetTextColor(cc.r, cc.g, cc.b)
    else
        cell.text:SetText(name)
        cell.text:SetTextColor(1, 1, 1)
    end
end

-- Role icon
CouncilTableMixin.CellUpdaters.role = function(_, cell, candidate)
    local role = candidate.role
    if role and role ~= "NONE" and ROLE_COORDS[role] and cell.icon then
        cell.icon:SetTexture(ROLE_ICONS[role])
        cell.icon:SetTexCoord(unpack(ROLE_COORDS[role]))
        cell.icon:Show()
    elseif cell.icon then
        cell.icon:Hide()
    end
end

-- Spec icon
CouncilTableMixin.CellUpdaters.spec = function(_, cell, candidate)
    if not cell.icon then return end
    local specID = candidate.specID
    if specID then
        local _, _, _, icon = C_SpecializationInfo.GetSpecializationInfoByID(specID)
        if icon then
            cell.icon:SetTexture(icon)
            cell.icon:SetTexCoord(0, 1, 0, 1)
            cell.icon:Show()
            return
        end
    end
    cell.icon:Hide()
end

-- Response (color bar + text)
CouncilTableMixin.CellUpdaters.response = function(_, cell, candidate)
    local canSeeResponses = not Loothing.Observer or Loothing.Observer:CanPlayerSeeResponses()
    if not canSeeResponses then
        cell.text:SetText("?")
        cell.text:SetTextColor(0.5, 0.5, 0.5)
        if cell.colorBar then cell.colorBar:Hide() end
        return
    end
    local responseId = candidate.response
    local responseInfo = responseId and Loothing.ResponseInfo[responseId]

    if responseInfo then
        cell.text:SetText(responseInfo.name)
        cell.text:SetTextColor(responseInfo.color.r, responseInfo.color.g, responseInfo.color.b)
        if cell.colorBar then
            cell.colorBar:SetColorTexture(responseInfo.color.r, responseInfo.color.g, responseInfo.color.b, 1)
            cell.colorBar:Show()
        end
    elseif candidate.response == "AUTOPASS" then
        cell.text:SetText(L["RESPONSE_AUTO_PASS"])
        cell.text:SetTextColor(0.5, 0.5, 0.5)
        if cell.colorBar then
            cell.colorBar:SetColorTexture(0.5, 0.5, 0.5, 1)
            cell.colorBar:Show()
        end
    elseif candidate.response == "WAIT" or not candidate.response then
        cell.text:SetText(L["RESPONSE_WAITING"])
        cell.text:SetTextColor(0.5, 0.5, 0.5)
        if cell.colorBar then
            cell.colorBar:Hide()
        end
    else
        cell.text:SetText(tostring(candidate.response))
        cell.text:SetTextColor(0.7, 0.7, 0.7)
        if cell.colorBar then
            cell.colorBar:Hide()
        end
    end

    -- Non-tradeable indicator
    if candidate.nonTradeable and cell.ntIndicator then
        cell.ntIndicator:Show()
    elseif cell.ntIndicator then
        cell.ntIndicator:Hide()
    end
end

-- Item level (equipped slot)
CouncilTableMixin.CellUpdaters.ilvl = function(_, cell, candidate)
    local ilvl = candidate.equippedIlvl
    if ilvl and ilvl > 0 then
        cell.text:SetText(tostring(ilvl))
        cell.text:SetTextColor(1, 1, 1)
    else
        cell.text:SetText("")
    end
end

-- Item level difference
CouncilTableMixin.CellUpdaters.ilvlDiff = function(_, cell, candidate)
    local diff = candidate.ilvlDiff
    if diff and diff ~= 0 then
        if diff > 0 then
            cell.text:SetText(string.format("|cff00ff00+%d|r", diff))
        else
            cell.text:SetText(string.format("|cffff0000%d|r", diff))
        end
    elseif diff == 0 then
        cell.text:SetText("|cffffff000|r")
    else
        cell.text:SetText("")
    end
end

-- Items won this session
CouncilTableMixin.CellUpdaters.wonSession = function(_, cell, candidate)
    local count = candidate.itemsWonThisSession or 0
    cell.text:SetText(tostring(count))
    if count > 0 then
        cell.text:SetTextColor(1, 0.82, 0) -- Gold
    else
        cell.text:SetTextColor(0.4, 0.4, 0.4)
    end
end

-- Items won this instance + difficulty
CouncilTableMixin.CellUpdaters.wonInstance = function(_, cell, candidate)
    local count = candidate.itemsWonInstance or 0
    cell.text:SetText(tostring(count))
    if count > 0 then
        cell.text:SetTextColor(1, 0.6, 0) -- Orange
    else
        cell.text:SetTextColor(0.4, 0.4, 0.4)
    end
end

-- Items won this week
CouncilTableMixin.CellUpdaters.wonWeekly = function(_, cell, candidate)
    local count = candidate.itemsWonWeekly or 0
    cell.text:SetText(tostring(count))
    if count > 0 then
        cell.text:SetTextColor(0.6, 0.8, 1) -- Light blue
    else
        cell.text:SetTextColor(0.4, 0.4, 0.4)
    end
end

-- Gear slot 1 icon
CouncilTableMixin.CellUpdaters.gear1 = function(_, cell, candidate)
    if candidate.gear1Link and cell.icon then
        local texture = select(10, C_Item.GetItemInfo(candidate.gear1Link))
        cell.icon:SetTexture(texture or "Interface\\Icons\\INV_Misc_QuestionMark")
        cell.icon:Show()

        -- Tooltip on hover
        if not cell._gear1Hooked then
            cell:SetScript("OnEnter", function(c)
                if c.candidate and c.candidate.gear1Link then
                    GameTooltip:SetOwner(c, "ANCHOR_RIGHT")
                    GameTooltip:SetHyperlink(c.candidate.gear1Link)
                    GameTooltip:Show()
                end
            end)
            cell:SetScript("OnLeave", function()
                GameTooltip:Hide()
            end)
            cell._gear1Hooked = true
        end
        cell.candidate = candidate
    elseif cell.icon then
        cell.icon:Hide()
    end
end

-- Gear slot 2 icon
CouncilTableMixin.CellUpdaters.gear2 = function(_, cell, candidate)
    if candidate.gear2Link and cell.icon then
        local texture = select(10, C_Item.GetItemInfo(candidate.gear2Link))
        cell.icon:SetTexture(texture or "Interface\\Icons\\INV_Misc_QuestionMark")
        cell.icon:Show()

        if not cell._gear2Hooked then
            cell:SetScript("OnEnter", function(c)
                if c.candidate and c.candidate.gear2Link then
                    GameTooltip:SetOwner(c, "ANCHOR_RIGHT")
                    GameTooltip:SetHyperlink(c.candidate.gear2Link)
                    GameTooltip:Show()
                end
            end)
            cell:SetScript("OnLeave", function()
                GameTooltip:Hide()
            end)
            cell._gear2Hooked = true
        end
        cell.candidate = candidate
    elseif cell.icon then
        cell.icon:Hide()
    end
end

-- Roll value
CouncilTableMixin.CellUpdaters.roll = function(_, cell, candidate)
    if candidate.roll then
        cell.text:SetText(tostring(candidate.roll))
        cell.text:SetTextColor(1, 0.82, 0)
    else
        cell.text:SetText("-")
        cell.text:SetTextColor(0.4, 0.4, 0.4)
    end
end

-- Note icon (hover to see note)
CouncilTableMixin.CellUpdaters.note = function(_, cell, candidate)
    local canSeeNotes = not Loothing.Observer or Loothing.Observer:CanPlayerSeeNotes()
    if not canSeeNotes then
        if cell.icon then cell.icon:Hide() end
        return
    end
    if candidate.note and candidate.note ~= "" then
        if cell.icon then
            cell.icon:SetTexture("Interface\\Buttons\\UI-GuildButton-PublicNote-Up")
            cell.icon:Show()
        end
        if not cell._noteHooked then
            cell:SetScript("OnEnter", function(c)
                if c.candidate and c.candidate.note and c.candidate.note ~= "" then
                    GameTooltip:SetOwner(c, "ANCHOR_RIGHT")
                    GameTooltip:AddLine(L["COUNCIL_COLUMN_NOTE"] .. ":", 1, 0.82, 0)
                    GameTooltip:AddLine(c.candidate.note, 1, 1, 1, true)
                    GameTooltip:Show()
                end
            end)
            cell:SetScript("OnLeave", function()
                GameTooltip:Hide()
            end)
            cell._noteHooked = true
        end
        cell.candidate = candidate
    else
        if cell.icon then
            cell.icon:Hide()
        end
    end
end

-- Vote button / vote count
CouncilTableMixin.CellUpdaters.vote = function(_, cell, candidate)
    local voteCount = candidate.councilVotes or 0
    local isML = Loothing.Session and Loothing.Session:IsMasterLooter()
    local hideVotes = Loothing.Settings and Loothing.Settings:GetHideVotes() and not isML

    -- Vote count to the left of the button
    local canSeeVoteCounts = not Loothing.Observer or Loothing.Observer:CanPlayerSeeVoteCounts()
    if hideVotes or not canSeeVoteCounts then
        cell.text:SetText("")
    else
        cell.text:SetText(voteCount > 0 and tostring(voteCount) or "")
        cell.text:SetTextColor(0.8, 0.8, 0.8)
    end

    -- Voter tooltip on hover of vote count text
    if not cell._voteTextHooked then
        cell:SetScript("OnEnter", function(c)
            if not c.candidate then return end
            local voters = c.candidate.voters
            if not voters or #voters == 0 then return end
            local canSeeCount = not Loothing.Observer or Loothing.Observer:CanPlayerSeeVoteCounts()
            if not canSeeCount then return end
            local _isML = Loothing.Session and Loothing.Session:IsMasterLooter()
            if Loothing.Settings and Loothing.Settings:GetHideVotes() and not _isML then return end
            local anonymous = Loothing.Settings and Loothing.Settings:GetAnonymousVoting()
            local mlOverride = _isML and Loothing.Settings and Loothing.Settings:GetMlSeesVotes()
            GameTooltip:SetOwner(c, "ANCHOR_RIGHT")
            GameTooltip:AddLine(string.format(L["TOOLTIP_VOTES"], #voters), 1, 0.82, 0)
            local canSeeIds = not Loothing.Observer or Loothing.Observer:CanPlayerSeeVoterIdentities()
            if (not anonymous or mlOverride) and canSeeIds then
                for _, voterName in ipairs(voters) do
                    local short = voterName:match("^([^%-]+)")
                    GameTooltip:AddLine(short or voterName, 1, 1, 1)
                end
            end
            GameTooltip:Show()
        end)
        cell:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)
        cell._voteTextHooked = true
    end
    cell.candidate = candidate

    -- Vote toggle button
    if cell.voteButton then
        -- RCV mode: show "Rank" / "Ranked" instead of "Vote" / "Voted"
        local votingMode = Loothing.Settings and Loothing.Settings:GetVotingMode()
        local isRCV = votingMode == Loothing.VotingMode.RANKED_CHOICE

        local canVote = Loothing.Council and Loothing.Council:CanPlayerVote()
        local hasVoted = candidate.hasMyVote

        if canVote then
            -- Check if this is a self-vote and selfVote is disabled
            local candidateName = candidate.playerName or candidate.name
            local isSelf = candidateName and Utils.IsSamePlayer(candidateName, Utils.GetPlayerFullName())
            local selfVoteAllowed = not Loothing.Settings or Loothing.Settings:GetSelfVote()
            if isSelf and not selfVoteAllowed then
                cell.voteButton:Show()
                cell.voteButton:SetAlpha(0.4)
                cell.voteButton:Disable()
                cell.voteButton:SetText(isRCV and L["VOTE_RANK"] or L["COLUMN_VOTE"])
            else
                cell.voteButton:Show()
                cell.voteButton:SetAlpha(1)
                cell.voteButton:Enable()
                cell.voteButton:SetText(hasVoted and (isRCV and "|cff33ee33" .. L["VOTE_RANKED"] .. "|r" or "|cff33ee33" .. L["VOTE_VOTED"] .. "|r") or (isRCV and L["VOTE_RANK"] or L["COLUMN_VOTE"]))
            end
        else
            local isObserver = Loothing.Observer and (Loothing.Observer:IsPlayerObserver() or Loothing.Observer:IsMLObserver())
            if isObserver then
                cell.voteButton:Show()
                cell.voteButton:SetAlpha(0.4)
                cell.voteButton:Disable()
                cell.voteButton:SetText(isRCV and L["VOTE_RANK"] or L["COLUMN_VOTE"])
            else
                cell.voteButton:Hide()
            end
        end
    end
end
