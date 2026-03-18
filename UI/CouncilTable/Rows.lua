--[[--------------------------------------------------------------------
    Loothing - UI: Council Table Rows
    Row creation, cell rendering, context menu, and "More Info" panel
----------------------------------------------------------------------]]

local _, ns = ...
local Loothing = ns.Addon
local Utils = ns.Utils
local TestMode = ns.TestMode
local L = Loothing.Locale

local CouncilTableMixin = ns.CouncilTableMixin or {}
ns.CouncilTableMixin = CouncilTableMixin

local ROW_HEIGHT = 24
local CELL_PADDING = 2

--[[--------------------------------------------------------------------
    Row Creation & Cell Factory
----------------------------------------------------------------------]]

--- Create a cell frame for a specific column type
-- @param parent Frame - Row frame
-- @param col table - Column definition
-- @return Frame
function CouncilTableMixin:CreateCell(parent, col)
    local cell = CreateFrame("Button", nil, parent)
    cell:SetSize(col.width, ROW_HEIGHT)
    cell:SetMouseClickEnabled(false)
    cell:SetMouseMotionEnabled(true)

    -- Text (used by most columns)
    local text = cell:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    text:SetPoint("LEFT", 2, 0)
    text:SetPoint("RIGHT", -2, 0)
    text:SetJustifyH("LEFT")
    text:SetWordWrap(false)
    cell.text = text

    -- Icon (used by class, role, gear, note columns)
    if col.id == "class" or col.id == "role" or col.id == "gear1" or col.id == "gear2" or col.id == "note" then
        local icon = cell:CreateTexture(nil, "ARTWORK")
        icon:SetSize(ROW_HEIGHT - 4, ROW_HEIGHT - 4)
        icon:SetPoint("CENTER")
        cell.icon = icon
        text:Hide()
    end

    -- Response color bar
    if col.id == "response" then
        local colorBar = cell:CreateTexture(nil, "ARTWORK")
        colorBar:SetPoint("LEFT", 0, 0)
        colorBar:SetSize(4, ROW_HEIGHT - 2)
        colorBar:SetColorTexture(1, 1, 1, 1)
        colorBar:Hide()
        cell.colorBar = colorBar

        text:SetPoint("LEFT", 8, 0)

        -- Non-tradeable indicator
        local nt = cell:CreateTexture(nil, "OVERLAY")
        nt:SetSize(12, 12)
        nt:SetPoint("RIGHT", -2, 0)
        nt:SetTexture("Interface\\Buttons\\UI-GroupLoot-Pass-Up")
        nt:SetVertexColor(1, 0.3, 0.3)
        nt:Hide()
        cell.ntIndicator = nt
    end

    -- Vote button (toggle button replacing checkbox)
    if col.id == "vote" then
        local voteBtn = CreateFrame("Button", nil, cell, "UIPanelButtonTemplate")
        voteBtn:SetSize(46, 18)
        voteBtn:SetPoint("RIGHT", cell, "RIGHT", -2, 0)
        voteBtn:Hide()
        cell.voteButton = voteBtn
        -- Vote count shown to the left of the button
        text:SetPoint("LEFT", 2, 0)
    end

    cell.columnId = col.id
    return cell
end

--- Create a candidate row with all visible cells
-- @param parent Frame - List content frame
-- @return Frame
function CouncilTableMixin:CreateCandidateRow(_parent)
    local row = self.rowPool:Acquire()
    row:SetHeight(ROW_HEIGHT)
    row:EnableMouse(true)

    -- Row background (alternating)
    if not row.bg then
        row.bg = row:CreateTexture(nil, "BACKGROUND")
        row.bg:SetAllPoints()
    end

    -- Selection highlight
    if not row.selectHighlight then
        row.selectHighlight = row:CreateTexture(nil, "HIGHLIGHT")
        row.selectHighlight:SetAllPoints()
        row.selectHighlight:SetColorTexture(1, 1, 1, 0.08)
    end

    -- Create cells for visible columns
    if not row.cells then
        row.cells = {}
    end

    local visible = self:GetVisibleColumns()
    local widths = self._computedColumnWidths or {}
    local xOffset = 0

    -- Reuse or create cells
    for _, col in ipairs(visible) do
        local w = widths[col.id] or col.width
        local cell = row.cells[col.id]
        if not cell then
            cell = self:CreateCell(row, col)
            row.cells[col.id] = cell
        end
        cell:ClearAllPoints()
        cell:SetPoint("LEFT", xOffset, 0)
        cell:SetSize(w, ROW_HEIGHT)
        cell:Show()
        xOffset = xOffset + w + CELL_PADDING
    end

    -- Hide cells for hidden columns
    for id, cell in pairs(row.cells) do
        local found = false
        for _, col in ipairs(visible) do
            if col.id == id then found = true; break end
        end
        if not found then
            cell:Hide()
        end
    end

    row:RegisterForClicks("LeftButtonUp", "RightButtonUp")

    -- Set OnClick once per frame (guard prevents re-allocation on every pool reuse).
    -- _councilTable stores the owning CouncilTable; r.candidate is read dynamically.
    if not row._clickHooked then
        row._councilTable = self
        row:SetScript("OnClick", function(r, button)
            if not r.candidate then return end
            if button == "RightButton" then
                r._councilTable:ShowCandidateContextMenu(r, r.candidate)
            elseif button == "LeftButton" then
                if IsAltKeyDown() and Loothing.Session and Loothing.Session:IsMasterLooter() then
                    r._councilTable:ShowCandidateContextMenu(r, r.candidate)
                    return
                end
                r._councilTable:SelectCandidate(r.candidate)
            end
        end)
        row._clickHooked = true
    end

    return row
end

--- Update all cells in a row with candidate data
-- @param row Frame - Row frame
-- @param candidate table - Candidate data
-- @param index number - Row index
function CouncilTableMixin:UpdateRow(row, candidate, index)
    row.candidate = candidate
    row.rowIndex = index

    -- Alternating row colors
    if index % 2 == 0 then
        row.bg:SetColorTexture(0.08, 0.08, 0.12, 0.6)
    else
        row.bg:SetColorTexture(0.05, 0.05, 0.08, 0.4)
    end

    -- Selected highlight
    if self.selectedCandidate and candidate.name == self.selectedCandidate.name then
        row.bg:SetColorTexture(0.15, 0.15, 0.25, 0.8)
    end

    -- Update each cell via DoCellUpdate
    local visible = self:GetVisibleColumns()
    for _, col in ipairs(visible) do
        local cell = row.cells[col.id]
        if cell then
            self:DoCellUpdate(cell, col, candidate, row)
        end
    end

    -- Vote button click handler — _parentRow pointer updated each refresh so the
    -- closure always reads the current candidate without allocating a new closure.
    local voteCell = row.cells.vote
    if voteCell and voteCell.voteButton then
        voteCell.voteButton._parentRow = row
        if not voteCell.voteButton._voteHooked then
            voteCell.voteButton:SetScript("OnClick", function(btn)
                btn._parentRow._councilTable:OnVoteClick(btn._parentRow.candidate)
            end)
            voteCell.voteButton._voteHooked = true
        end
    end
end

--[[--------------------------------------------------------------------
    Refresh Candidates
----------------------------------------------------------------------]]

function CouncilTableMixin:RefreshCandidates()
    if not self.rowPool then return end
    self.rowPool:ReleaseAll()

    if not self.currentItem or not self.currentItem.candidateManager then
        if self.emptyText then self.emptyText:Show() end
        return
    end

    local candidates = self.currentItem.candidateManager:GetAllCandidates()
    if #candidates == 0 then
        if self.emptyText then self.emptyText:Show() end
        return
    end
    if self.emptyText then self.emptyText:Hide() end

    -- Enrich candidates with role and equipped ilvl
    self:EnrichCandidates(candidates)

    -- Sort candidates
    self:SortCandidates(candidates)

    local yOffset = 0
    for i, candidate in ipairs(candidates) do
        local row = self:CreateCandidateRow(self.listContent)
        row:SetPoint("TOPLEFT", 0, yOffset)
        row:SetPoint("TOPRIGHT", 0, yOffset)

        self:UpdateRow(row, candidate, i)

        row:Show()
        yOffset = yOffset - ROW_HEIGHT
    end

    -- Update content height
    if self.listContent then
        self.listContent:SetHeight(math.max(1, math.abs(yOffset)))
    end

    -- Update voter progress indicator
    if self.UpdateVoterProgress then
        self:UpdateVoterProgress()
    end
end

--[[--------------------------------------------------------------------
    Enrich Candidates
----------------------------------------------------------------------]]

function CouncilTableMixin:EnrichCandidates(candidates)
    local roster = Utils.GetRaidRoster()

    -- Build name-keyed lookup
    local rosterByName = {}
    for _, entry in ipairs(roster) do
        rosterByName[entry.name] = entry
        if entry.shortName then
            rosterByName[entry.shortName] = entry
        end
    end

    -- Build loot count cache from history (single pass)
    local countCache
    if Loothing.History then
        local instanceName, difficultyID
        if self.currentItem and self.currentItem.instanceData then
            instanceName = self.currentItem.instanceData.instance
            difficultyID = self.currentItem.instanceData.difficultyID
        end
        local resetTime = Loothing.History:GetLastWeeklyResetTime()
        countCache = Loothing.History:BuildPlayerCountCache(instanceName, difficultyID, resetTime)
    end

    for _, candidate in ipairs(candidates) do
        -- Role from raid roster
        local rosterEntry = rosterByName[candidate.playerName]
            or rosterByName[candidate.name]
            or rosterByName[candidate.shortName]
        if rosterEntry and rosterEntry.role then
            candidate.role = rosterEntry.role
        end

        -- Equipped ilvl = best of gear1ilvl / gear2ilvl
        local g1 = candidate.gear1ilvl or 0
        local g2 = candidate.gear2ilvl or 0
        candidate.equippedIlvl = math.max(g1, g2)

        -- Loot count enrichment from history cache
        if countCache and not (TestMode and TestMode.enabled) then
            local normalized = Utils.NormalizeName(candidate.playerName or candidate.name)
            local counts = normalized and countCache[normalized]
            if counts then
                candidate.itemsWonInstance = counts.instance
                candidate.itemsWonWeekly = counts.weekly
            else
                candidate.itemsWonInstance = 0
                candidate.itemsWonWeekly = 0
            end
        end
    end
end

--[[--------------------------------------------------------------------
    Sorting
----------------------------------------------------------------------]]

function CouncilTableMixin:SortCandidates(candidates)
    if not self.sortColumn then return end

    local sortKey = self.COLUMN_SORT_MAP[self.sortColumn] or self.sortColumn
    local asc = self.sortAscending

    table.sort(candidates, function(a, b)
        local valA = a[sortKey]
        local valB = b[sortKey]

        local nameA = a.playerName or a.name or ""
        local nameB = b.playerName or b.name or ""

        -- Nil handling
        if valA == nil and valB == nil then return nameA < nameB end
        if valA == nil then return false end
        if valB == nil then return true end

        if valA == valB then
            return nameA < nameB
        end

        -- Normalize mixed types (numeric responses vs string system responses)
        -- to prevent Lua comparison errors
        local tA, tB = type(valA), type(valB)
        if tA ~= tB then
            valA = tostring(valA)
            valB = tostring(valB)
        end

        if asc then
            return valA < valB
        else
            return valA > valB
        end
    end)
end

--[[--------------------------------------------------------------------
    Candidate Selection & "More Info"
----------------------------------------------------------------------]]

function CouncilTableMixin:SelectCandidate(candidate)
    self.selectedCandidate = candidate
    self:RefreshCandidates()
    self:UpdateMoreInfoPanel(candidate)
    self:TriggerEvent("OnCandidateSelected", candidate)
end

function CouncilTableMixin:UpdateMoreInfoPanel(candidate)
    if not self.moreInfoPanel then return end
    if not candidate then
        self.moreInfoPanel:Hide()
        return
    end

    self.moreInfoPanel:Show()

    -- Player name with class color
    local class = candidate.class
    local name = candidate.name or "Unknown"
    if class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class] then
        local cc = RAID_CLASS_COLORS[class]
        self.moreInfoName:SetText(name)
        self.moreInfoName:SetTextColor(cc.r, cc.g, cc.b)
    else
        self.moreInfoName:SetText(name)
        self.moreInfoName:SetTextColor(1, 1, 1)
    end

    -- Response
    local responseInfo = candidate.response and Loothing.ResponseInfo[candidate.response]
    if responseInfo then
        self.moreInfoResponse:SetText(responseInfo.name)
        self.moreInfoResponse:SetTextColor(responseInfo.color.r, responseInfo.color.g, responseInfo.color.b)
    else
        self.moreInfoResponse:SetText(tostring(candidate.response or "Waiting"))
        self.moreInfoResponse:SetTextColor(0.7, 0.7, 0.7)
    end

    -- Note
    self.moreInfoNote:SetText(candidate.note or "")

    -- Item level & role
    local infoLines = {}
    if candidate.equippedIlvl and candidate.equippedIlvl > 0 then
        infoLines[#infoLines + 1] = string.format("iLvl: %d", candidate.equippedIlvl)
    end
    if candidate.role and candidate.role ~= "NONE" then
        infoLines[#infoLines + 1] = string.format("Role: %s", candidate.role)
    end
    if candidate.rank then
        infoLines[#infoLines + 1] = string.format("Rank: %s", candidate.rank)
    end
    if candidate.enchanter then
        infoLines[#infoLines + 1] = "Enchanter"
    end
    self.moreInfoDetails:SetText(table.concat(infoLines, "  |  "))

    -- Gear comparison
    local gearLines = {}
    if candidate.gear1Link then
        local _, link = C_Item.GetItemInfo(candidate.gear1Link)
        gearLines[#gearLines + 1] = "Slot 1: " .. (link or candidate.gear1Link)
    end
    if candidate.gear2Link then
        local _, link = C_Item.GetItemInfo(candidate.gear2Link)
        gearLines[#gearLines + 1] = "Slot 2: " .. (link or candidate.gear2Link)
    end
    self.moreInfoGear:SetText(table.concat(gearLines, "\n"))

    -- Vote breakdown
    if self.moreInfoVoteBreakdown then
        local breakdownParts = {}
        local totalVotes = candidate.councilVotes or 0
        if totalVotes > 0 then
            breakdownParts[#breakdownParts + 1] = string.format("Votes: %d", totalVotes)
        end

        -- Show vote counts per response across all candidates for this item
        if self.currentItem and self.currentItem.candidateManager then
            local allCandidates = self.currentItem.candidateManager:GetAllCandidates()
            local responseCounts = {}
            for _, c in ipairs(allCandidates) do
                local resp = c.response
                if resp and (c.councilVotes or 0) > 0 then
                    local info = Loothing.ResponseInfo[resp]
                    local respName = info and info.name or tostring(resp)
                    responseCounts[respName] = (responseCounts[respName] or 0) + c.councilVotes
                end
            end
            for respName, count in pairs(responseCounts) do
                breakdownParts[#breakdownParts + 1] = string.format("%s: %d", respName, count)
            end
        end

        if #breakdownParts > 0 then
            self.moreInfoVoteBreakdown:SetText(table.concat(breakdownParts, "  |  "))
        else
            self.moreInfoVoteBreakdown:SetText("")
        end
    end
end

--[[--------------------------------------------------------------------
    Context Menu
----------------------------------------------------------------------]]

function CouncilTableMixin:ShowCandidateContextMenu(row, candidate)
    local L = Loothing.Locale or {}
    local isML = Loothing.Session and Loothing.Session:IsMasterLooter()

    MenuUtil.CreateContextMenu(row, function(_, rootDescription)
        rootDescription:CreateTitle(candidate.name or "Unknown")

        -- ML-only actions
        if isML and self.currentItem then
            local itemGUID = self.currentItem.guid

            rootDescription:CreateButton(L["AWARD_ITEM"], function()
                if Loothing.Session then
                    Loothing.Session:AwardItem(itemGUID, candidate.name)
                    self:TriggerEvent("OnCandidateAwarded", self.currentItem, candidate)
                end
            end)

            -- Award with response type
            for _, info in pairs(Loothing.ResponseInfo) do
                rootDescription:CreateButton(string.format("Award: %s", info.name), function()
                    if Loothing.Session then
                        Loothing.Session:AwardItem(itemGUID, candidate.name, info.name)
                        self:TriggerEvent("OnCandidateAwarded", self.currentItem, candidate)
                    end
                end)
            end

            -- "Award For..." submenu using award reasons from settings
            if Loothing.Settings then
                local reasons = Loothing.Settings:GetAwardReasons()
                if reasons and #reasons > 0 then
                    local awardForMenu = rootDescription:CreateButton(L["AWARD_FOR"], nop)
                    for _, reason in ipairs(reasons) do
                        local r, g, b = 1, 1, 1
                        if reason.color then
                            r, g, b = reason.color[1] or 1, reason.color[2] or 1, reason.color[3] or 1
                        end
                        local coloredName = string.format("|cff%02x%02x%02x%s|r", r * 255, g * 255, b * 255, reason.name)
                        awardForMenu:CreateButton(coloredName, function()
                            if Loothing.Session then
                                Loothing.Session:AwardItem(itemGUID, candidate.name, nil, reason.id)
                                self:TriggerEvent("OnCandidateAwarded", self.currentItem, candidate)
                            end
                        end)
                    end
                end
            end

            rootDescription:CreateDivider()
        end

        -- Whisper
        rootDescription:CreateButton(L["WHISPER"], function()
            ChatFrame_OpenChat("/w " .. (candidate.name or ""))
        end)

        -- View Gear
        if candidate.gear1Link or candidate.gear2Link then
            rootDescription:CreateButton(L["VIEW_GEAR"], function()
                GameTooltip:SetOwner(UIParent, "ANCHOR_CURSOR")
                if candidate.gear1Link then
                    GameTooltip:SetHyperlink(candidate.gear1Link)
                elseif candidate.gear2Link then
                    GameTooltip:SetHyperlink(candidate.gear2Link)
                end
                GameTooltip:Show()
            end)
        end

        -- Change response (ML only)
        if isML then
            local responseSubmenu = rootDescription:CreateButton(L["CHANGE_RESPONSE"], nop)
            for id, info in pairs(Loothing.ResponseInfo) do
                responseSubmenu:CreateButton(info.name, function()
                    if self.currentItem and self.currentItem.candidateManager then
                        self.currentItem.candidateManager:SetCandidateResponse(candidate.name, id)
                        self:RefreshCandidates()
                    end
                end)
            end
        end

        -- Disenchant submenu (ML only, requires enchanters in group)
        if isML and self.currentItem then
            local enchanters = Loothing.PlayerCache and Loothing.PlayerCache:GetEnchanters() or {}
            if #enchanters > 0 then
                rootDescription:CreateDivider()
                local deSubmenu = rootDescription:CreateButton(L["DISENCHANT"], nop)
                for _, enc in ipairs(enchanters) do
                    local classColor = RAID_CLASS_COLORS and RAID_CLASS_COLORS[enc.class] or { r = 1, g = 1, b = 1 }
                    local coloredName = string.format("|cff%02x%02x%02x%s|r",
                        classColor.r * 255, classColor.g * 255, classColor.b * 255, enc.name)
                    deSubmenu:CreateButton(coloredName, function()
                        -- Find the disenchant award reason
                        local deReasonId = nil
                        if Loothing.Settings then
                            local reasons = Loothing.Settings:GetAwardReasons()
                            for _, reason in ipairs(reasons) do
                                if reason.disenchant then
                                    deReasonId = reason.id
                                    break
                                end
                            end
                        end
                        if Loothing.Session then
                            Loothing.Session:AwardItem(self.currentItem.guid, enc.name, nil, deReasonId)
                            self:TriggerEvent("OnCandidateAwarded", self.currentItem, { name = enc.name })
                        end
                    end)
                end
            end
        end
    end)
end

--[[--------------------------------------------------------------------
    Vote Handling
----------------------------------------------------------------------]]

function CouncilTableMixin:OnVoteClick(candidate)
    Loothing:Debug("OnVoteClick: candidate =", candidate and candidate.name, "item =", self.currentItem and self.currentItem.guid)

    -- In RCV mode, open the VotePanel instead of toggling a vote
    local votingMode = Loothing.Settings and Loothing.Settings:GetVotingMode()
    if votingMode == Loothing.VotingMode.RANKED_CHOICE then
        if Loothing.VotePanel then
            Loothing.VotePanel:SetVotingMode(Loothing.VotingMode.RANKED_CHOICE)
            Loothing.VotePanel:SetItem(self.currentItem)
            Loothing.VotePanel:Show()
        end
        return
    end

    if not Loothing.Session then
        Loothing:Debug("OnVoteClick: no Session")
        return
    end
    if not self.currentItem then
        Loothing:Debug("OnVoteClick: no currentItem")
        return
    end

    -- Observers and ML-observers can see the table but cannot vote
    if not (Loothing.Council and Loothing.Council:CanPlayerVote()) then
        Loothing:Debug("OnVoteClick: not eligible to vote")
        return
    end

    local hasVoted = candidate.hasMyVote
    Loothing:Debug("OnVoteClick: hasVoted =", tostring(hasVoted), "itemState =", self.currentItem:GetState())

    if hasVoted then
        -- Retract vote
        local ok = Loothing.Session:RetractVote(self.currentItem.guid, candidate.name)
        Loothing:Debug("OnVoteClick: RetractVote returned", tostring(ok))
    else
        -- Check self-vote setting
        local selfVote = Loothing.Settings and Loothing.Settings:GetSelfVote()
        if not selfVote then
            local playerName = Utils.GetPlayerFullName()
            if Utils.IsSamePlayer(candidate.name, playerName) then
                Loothing:Print(Loothing.Locale["SELF_VOTE_DISABLED"])
                return
            end
        end

        -- Check multi-vote setting
        local multiVote = Loothing.Settings and Loothing.Settings:GetMultiVote()
        if not multiVote then
            Loothing.Session:RetractAllVotes(self.currentItem.guid)
        end
        local ok = Loothing.Session:CastVote(self.currentItem.guid, candidate.name)
        Loothing:Debug("OnVoteClick: CastVote returned", tostring(ok))
    end

    self:RefreshCandidates()
end
