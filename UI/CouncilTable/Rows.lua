--[[--------------------------------------------------------------------
    Loothing - UI: Council Table Rows
    Row creation, cell rendering, context menu, and detail tooltip
----------------------------------------------------------------------]]

local _, ns = ...
local Loothing = ns.Addon
local Utils = ns.Utils
local TestMode = ns.TestMode

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
    cell:SetMouseMotionEnabled(false)

    -- Text (used by most columns)
    local text = cell:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    text:SetPoint("LEFT", 2, 0)
    text:SetPoint("RIGHT", -2, 0)
    text:SetJustifyH("LEFT")
    text:SetWordWrap(false)
    cell.text = text

    -- Icon (used by class, role, gear, note columns)
    if col.id == "class" or col.id == "spec" or col.id == "role" or col.id == "gear1" or col.id == "gear2" or col.id == "note" then
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

    -- Hover handlers for detail tooltip (show on enter, hide on leave unless pinned)
    if not row._hoverHooked then
        row:SetScript("OnEnter", function(r)
            if not r.candidate then return end
            if not r._councilTable.tooltipPinned then
                r._councilTable:UpdateDetailTooltip(r.candidate)
            end
        end)
        row:SetScript("OnLeave", function(r)
            if not r._councilTable.tooltipPinned then
                r._councilTable:HideDetailTooltip()
            end
        end)
        row._hoverHooked = true
    end

    -- Hook cells that have mouse motion enabled (tooltips) to also propagate
    -- hover to the row for the detail tooltip. Cells with mouse motion disabled
    -- pass events through to the row automatically.
    for _, cell in pairs(row.cells) do
        if not cell._hoverForwarded then
            cell:HookScript("OnEnter", function()
                local r = cell:GetParent()
                if r and r.candidate and r._councilTable then
                    if not r._councilTable.tooltipPinned then
                        r._councilTable:UpdateDetailTooltip(r.candidate)
                    end
                end
            end)
            cell:HookScript("OnLeave", function()
                local r = cell:GetParent()
                if r and r._councilTable and not r._councilTable.tooltipPinned then
                    r._councilTable:HideDetailTooltip()
                end
            end)
            cell._hoverForwarded = true
        end
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

        -- Spec ID from PlayerCache (if available)
        if not candidate.specID and Loothing.PlayerCache then
            local cached = Loothing.PlayerCache:Get(candidate.playerName or candidate.name)
            if cached and cached.specID then
                candidate.specID = cached.specID
            end
        end

        -- For local player, always use the live spec
        if not candidate.specID and Utils.IsSamePlayer(candidate.playerName or candidate.name, Utils.GetPlayerFullName()) then
            local specIndex = GetSpecialization and GetSpecialization()
            if specIndex then
                local getInfo = C_SpecializationInfo and C_SpecializationInfo.GetSpecializationInfo or GetSpecializationInfo
                if getInfo then
                    candidate.specID = getInfo(specIndex)
                end
            end
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
    Candidate Selection & Detail Tooltip
----------------------------------------------------------------------]]

function CouncilTableMixin:SelectCandidate(candidate)
    self.selectedCandidate = candidate
    self.tooltipPinned = true
    self:RefreshCandidates()
    self:UpdateDetailTooltip(candidate)
    self:TriggerEvent("OnCandidateSelected", candidate)
end

function CouncilTableMixin:UpdateDetailTooltip(candidate)
    if not self.detailTooltip then return end
    if not candidate then
        self:HideDetailTooltip()
        return
    end

    self.detailTooltip:Show()

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
    local responseInfo = candidate.response and (Loothing.ResponseInfo[candidate.response] or Loothing.SystemResponseInfo[candidate.response])
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

    -- Wishlist section
    if self.moreInfoWishlist then
        local wishEntry = candidate.wishlistEntry
        if wishEntry then
            local nlInfo = Loothing.NeedLevel[wishEntry.needLevel]
            local label = nlInfo and nlInfo.label or (wishEntry.needLevel or "?")
            local c = nlInfo and nlInfo.color or { r = 1, g = 1, b = 1 }

            local wishParts = {}
            wishParts[#wishParts + 1] = string.format("Wishlist: %s \194\183 Priority %d", label, wishEntry.priority or 0)

            -- Character progress
            local charInfo = Loothing.Wishlist and Loothing.Wishlist:GetCharacterInfo(candidate.playerName)
            if charInfo and charInfo.totalItems and charInfo.totalItems > 0 then
                local fulfilled = charInfo.fulfilledItems or 0
                wishParts[#wishParts + 1] = string.format("  |  Progress: %d/%d", fulfilled, charInfo.totalItems)
            end

            -- Notes from wishlist entry
            if wishEntry.notes and wishEntry.notes ~= "" then
                wishParts[#wishParts + 1] = "\n" .. wishEntry.notes
            end

            self.moreInfoWishlist:SetText(table.concat(wishParts))
            self.moreInfoWishlist:SetTextColor(c.r, c.g, c.b)
        else
            self.moreInfoWishlist:SetText("")
        end
    end

    -- Item source (from itemDetails, loaded via desktop sync)
    if self.moreInfoSource then
        local itemID = self.currentItem and self.currentItem.itemID
        local details = itemID and Loothing.Wishlist and Loothing.Wishlist:GetItemDetails(itemID)
        if details and details.sourceBoss then
            local sourceText = string.format("Drops from: %s", details.sourceBoss)
            if details.source then
                sourceText = sourceText .. " \194\183 " .. details.source
            end
            if details.difficulty then
                sourceText = sourceText .. " (" .. details.difficulty .. ")"
            end
            self.moreInfoSource:SetText(sourceText)
        else
            self.moreInfoSource:SetText("")
        end
    end

    -- Player Intel section (from desktop sync)
    local intel = Loothing.PlayerIntel and Loothing.PlayerIntel:Get(candidate.playerName)
    if intel then
        self:UpdatePlayerIntelSection(intel)
    else
        self:ClearPlayerIntelSection()
    end

    -- Resize tooltip to fit content
    self:ResizeDetailTooltip()
end

--[[--------------------------------------------------------------------
    Player Intel Display (Desktop-synced data)
----------------------------------------------------------------------]]

function CouncilTableMixin:UpdatePlayerIntelSection(intel)
    -- Show separator
    if self.moreInfoIntelSep then
        self.moreInfoIntelSep:Show()
    end

    -- M+ Activity
    if self.moreInfoMythicPlus then
        local parts = {}
        if intel.mpWeek then
            if intel.mpWeek.count and intel.mpWeek.count > 0 then
                parts[#parts + 1] = string.format("%d keys this week", intel.mpWeek.count)
            end
            if intel.mpWeek.highest and intel.mpWeek.highest > 0 then
                parts[#parts + 1] = string.format("Highest: +%d", intel.mpWeek.highest)
            end
        end
        if intel.mpScore and intel.mpScore > 0 then
            parts[#parts + 1] = string.format("Score: %.0f", intel.mpScore)
        end
        if #parts > 0 then
            self.moreInfoMythicPlus:SetText("M+: " .. table.concat(parts, "  |  "))
            self.moreInfoMythicPlus:SetTextColor(0.4, 0.8, 1.0)
        else
            self.moreInfoMythicPlus:SetText("M+: No data")
            self.moreInfoMythicPlus:SetTextColor(0.5, 0.5, 0.5)
        end
    end

    -- Parse Performance
    if self.moreInfoParses then
        local parts = {}
        if intel.parseAvg then
            parts[#parts + 1] = string.format("Avg: %.0f", intel.parseAvg)
        end
        if intel.parseBest then
            local bestText = string.format("Best: %.0f", intel.parseBest)
            if intel.parseBestBoss then
                bestText = bestText .. " (" .. intel.parseBestBoss .. ")"
            end
            parts[#parts + 1] = bestText
        end

        -- Trend indicator
        if intel.parseTrend == "up" then
            parts[#parts + 1] = "|cff33ee33\226\150\178|r"  -- green ▲
        elseif intel.parseTrend == "down" then
            parts[#parts + 1] = "|cffee3333\226\150\188|r"  -- red ▼
        elseif intel.parseTrend == "stable" then
            parts[#parts + 1] = "|cff999999\226\151\134|r"  -- gray ◆
        end

        if #parts > 0 then
            self.moreInfoParses:SetText("Parses: " .. table.concat(parts, "  |  "))
            self.moreInfoParses:SetTextColor(1.0, 0.8, 0.4)
        else
            self.moreInfoParses:SetText("Parses: No data")
            self.moreInfoParses:SetTextColor(0.5, 0.5, 0.5)
        end
    end

    -- Attendance (prefer event-based data, fall back to roster member percentage)
    if self.moreInfoAttendance then
        local parts = {}
        if intel.eventAttendPct then
            -- Event-based attendance from the events system
            parts[#parts + 1] = string.format("%.0f%%", intel.eventAttendPct)
            if intel.eventAttended and intel.eventEligible then
                parts[#parts + 1] = string.format("%d/%d events", intel.eventAttended, intel.eventEligible)
            end
        elseif intel.attendance then
            -- Fallback to roster member attendance percentage
            parts[#parts + 1] = string.format("%.0f%%", intel.attendance * 100)
        end
        if intel.raidCount and intel.raidCount > 0 then
            parts[#parts + 1] = string.format("%d raid dates", intel.raidCount)
        end
        if #parts > 0 then
            self.moreInfoAttendance:SetText("Attendance: " .. table.concat(parts, "  |  "))
        else
            self.moreInfoAttendance:SetText("")
        end
    end

    -- Gear Readiness (from audit data merged into intel)
    if self.moreInfoGearReady then
        local parts = {}
        -- Tier set
        if intel.tierCount then
            local tierText = string.format("%dpc", intel.tierCount)
            if intel.has4pc then
                tierText = "|cffa335ee" .. tierText .. "|r"
            elseif intel.has2pc then
                tierText = "|cff0070dd" .. tierText .. "|r"
            end
            parts[#parts + 1] = "Tier: " .. tierText
        end
        -- Enchants
        if intel.enchMissing then
            if intel.enchMissing == 0 then
                parts[#parts + 1] = "|cff33ee33Enchanted|r"
            else
                parts[#parts + 1] = string.format("|cffee3333%d missing enchants|r", intel.enchMissing)
            end
        end
        -- Gems
        if intel.gemMissing then
            if intel.gemMissing == 0 then
                parts[#parts + 1] = "|cff33ee33Gemmed|r"
            else
                parts[#parts + 1] = string.format("|cffee3333%d missing gems|r", intel.gemMissing)
            end
        end
        -- Vault
        if intel.vaultSlots then
            parts[#parts + 1] = string.format("Vault: %d/9", intel.vaultSlots)
        end
        -- Raid progression
        if intel.raidProg and intel.raidProg ~= "" then
            parts[#parts + 1] = intel.raidProg
        end
        if #parts > 0 then
            self.moreInfoGearReady:SetText(table.concat(parts, "  |  "))
            self.moreInfoGearReady:SetTextColor(0.7, 0.8, 0.7)
        else
            self.moreInfoGearReady:SetText("")
        end
    end

    -- Recent Loot History (compact, last 3 items)
    if self.moreInfoLootHistory then
        if intel.loot and #intel.loot > 0 then
            local lines = {}
            local maxShow = math.min(#intel.loot, 3)
            for i = 1, maxShow do
                local item = intel.loot[i]
                local text = string.format("[%s] %s (%s)", item.date or "?", item.name or "?", item.resp or "?")
                lines[#lines + 1] = text
            end
            if #intel.loot > maxShow then
                lines[#lines + 1] = string.format("  ...and %d more", #intel.loot - maxShow)
            end
            self.moreInfoLootHistory:SetText("Recent Loot: " .. table.concat(lines, "\n"))
            self.moreInfoLootHistory:SetTextColor(0.8, 0.8, 0.8)
        else
            self.moreInfoLootHistory:SetText("Recent Loot: None this tier")
            self.moreInfoLootHistory:SetTextColor(0.5, 0.5, 0.5)
        end
    end

    -- Alt Loot Summary
    if self.moreInfoAltLoot then
        if intel.altLoot and #intel.altLoot > 0 then
            local parts = {}
            for _, alt in ipairs(intel.altLoot) do
                local altName = alt.alt or "?"
                -- Strip realm from display
                local dashIdx = altName:find("-")
                local shortName = dashIdx and altName:sub(1, dashIdx - 1) or altName
                parts[#parts + 1] = string.format("%s (%s): %d items", shortName, alt.cls or "?", alt.count or 0)
            end
            self.moreInfoAltLoot:SetText("Alt Loot: " .. table.concat(parts, "  |  "))
        else
            self.moreInfoAltLoot:SetText("")
        end
    end

    -- Staleness indicator
    if self.moreInfoStaleness then
        local staleText, r, g, b = Loothing.PlayerIntel:GetStalenessInfo()
        if staleText then
            self.moreInfoStaleness:SetText("Synced " .. staleText)
            self.moreInfoStaleness:SetTextColor(r, g, b)
        else
            self.moreInfoStaleness:SetText("")
        end
    end
end

function CouncilTableMixin:ClearPlayerIntelSection()
    -- Hide separator
    if self.moreInfoIntelSep then
        self.moreInfoIntelSep:Hide()
    end

    local noDataMsg = Loothing.PlayerIntel and not Loothing.PlayerIntel:HasData()
        and "Sync from desktop app for player intel" or ""

    if self.moreInfoMythicPlus then
        self.moreInfoMythicPlus:SetText(noDataMsg)
        self.moreInfoMythicPlus:SetTextColor(0.5, 0.5, 0.5)
    end
    if self.moreInfoParses then self.moreInfoParses:SetText("") end
    if self.moreInfoAttendance then self.moreInfoAttendance:SetText("") end
    if self.moreInfoGearReady then self.moreInfoGearReady:SetText("") end
    if self.moreInfoLootHistory then self.moreInfoLootHistory:SetText("") end
    if self.moreInfoAltLoot then self.moreInfoAltLoot:SetText("") end
    if self.moreInfoStaleness then self.moreInfoStaleness:SetText("") end
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

    if not self.currentItem then
        Loothing:Debug("OnVoteClick: no currentItem")
        return
    end

    -- In ranked mode, open the council voting modal instead of toggling a vote.
    local votingMode = Loothing.Settings and Loothing.Settings:GetVotingMode()
    if votingMode == Loothing.VotingMode.RANKED_CHOICE then
        if Loothing.Session and Loothing.Session.ShowVotingUIForItem then
            Loothing.Session:ShowVotingUIForItem(self.currentItem)
        else
            Loothing:Error("Council voting UI is unavailable.")
        end
        return
    end

    if not Loothing.Session then
        Loothing:Debug("OnVoteClick: no Session")
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
