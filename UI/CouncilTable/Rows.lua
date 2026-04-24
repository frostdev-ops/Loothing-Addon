--[[--------------------------------------------------------------------
    Loothing - UI: Council Table Rows
    Row creation, cell rendering, context menu, and detail tooltip
----------------------------------------------------------------------]]

local _, ns = ...
local Loolib = LibStub("Loolib")
local Loothing = ns.Addon
local Utils = ns.Utils
local TestMode = ns.TestMode
local SkinningMixin = ns.SkinningMixin

local CouncilTableMixin = ns.CouncilTableMixin or {}
ns.CouncilTableMixin = CouncilTableMixin

local ROW_HEIGHT = 24
local CELL_PADDING = 2

-- Blizzard exposes `nop` as a global (defined in FrameXML), but relying on
-- undocumented globals is fragile and trips lint warnings. Use our own.
local nop = function() end

-- Return responses for menu iteration in a stable, custom-set-safe order.
-- Prefers ResponseManager:GetSortedResponses() (the full active button set,
-- including guild customizations). Falls back to ResponsePriority +
-- ResponseInfo during early init when ResponseManager is not constructed
-- yet. Output shape per entry: { id = <number>, name = <string> }.
local function iterateOrderedResponses()
    local ordered = {}
    local seen = {}

    if Loothing.ResponseManager and Loothing.ResponseManager.GetSortedResponses then
        local ok, sorted = pcall(function()
            return Loothing.ResponseManager:GetSortedResponses()
        end)
        if ok and type(sorted) == "table" then
            for _, entry in ipairs(sorted) do
                if entry.id and entry.name then
                    ordered[#ordered + 1] = { id = entry.id, name = entry.name }
                    seen[entry.id] = true
                end
            end
        end
    end

    -- Fallback / union: walk ResponsePriority, then any extra numeric keys
    -- in ResponseInfo that ResponseManager didn't already surface.
    if Loothing.ResponsePriority and Loothing.ResponseInfo then
        for _, responseID in ipairs(Loothing.ResponsePriority) do
            if not seen[responseID] then
                local info = Loothing.ResponseInfo[responseID]
                if info and info.name then
                    ordered[#ordered + 1] = { id = responseID, name = info.name }
                    seen[responseID] = true
                end
            end
        end
        for responseID, info in pairs(Loothing.ResponseInfo) do
            if type(responseID) == "number" and not seen[responseID]
                and info and info.name then
                ordered[#ordered + 1] = { id = responseID, name = info.name }
                seen[responseID] = true
            end
        end
    end

    return ordered
end

local function HasMasterLooterVisibility()
    return CouncilTableMixin.HasMasterLooterVisibility
        and CouncilTableMixin.HasMasterLooterVisibility()
end

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
    if SkinningMixin then
        SkinningMixin:StyleText(text, "bodySmall", "text")
    end
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
        local voteBtn = ns.CreateThemedButton(cell)
        voteBtn:SetSize(46, 18)
        voteBtn:SetPoint("RIGHT", cell, "RIGHT", -2, 0)
        voteBtn:Hide()
        cell.voteButton = voteBtn
        if SkinningMixin then
            SkinningMixin:StylePlainButton(voteBtn)
        end
        -- Vote count shown to the left of the button
        text:SetPoint("LEFT", 2, 0)
    end

    -- Intel button — opens the per-candidate intel modal for the player
    -- on this row. Hidden when the player has no intel record (keeps the
    -- column visually quiet for council members without desktop sync).
    -- Column text is hidden; the whole cell is the button's clickable area.
    if col.id == "intel" then
        text:Hide()
        local intelBtn = ns.CreateThemedButton(cell)
        intelBtn:SetSize(44, 18)
        intelBtn:SetPoint("CENTER", cell, "CENTER", 0, 0)
        intelBtn:SetText(Loothing.Locale and Loothing.Locale["COLUMN_INTEL"] or "Intel")
        intelBtn:Hide()
        cell.intelButton = intelBtn
        if SkinningMixin then
            SkinningMixin:StylePlainButton(intelBtn)
        end
    end

    -- Player column: left-click opens the candidate's history profile;
    -- right-click forwards to the row's context menu so the existing
    -- ML actions still work. Motion is enabled so the HIGHLIGHT-layer
    -- underline can show on hover as a clickability affordance.
    if col.id == "player" then
        cell:SetMouseClickEnabled(true)
        cell:SetMouseMotionEnabled(true)
        cell:RegisterForClicks("LeftButtonUp", "RightButtonUp")

        -- Hover underline, HIGHLIGHT draw-layer so it only renders on mouseover
        local underline = cell:CreateTexture(nil, "HIGHLIGHT")
        underline:SetHeight(1)
        underline:SetPoint("BOTTOMLEFT", text, "BOTTOMLEFT", 0, -1)
        underline:SetPoint("BOTTOMRIGHT", text, "BOTTOMRIGHT", 0, -1)
        underline:SetColorTexture(1, 1, 1, 0.55)

        cell:SetScript("OnClick", function(_, button)
            local row = cell:GetParent()
            local candidate = row and row.candidate
            if button == "LeftButton" then
                -- Preserve the row-level ML shortcut: Alt+Left on the
                -- Player cell opens the context menu just like it does
                -- on every other cell in the row. Falls through to the
                -- profile open when no modifier is held.
                if IsAltKeyDown() and HasMasterLooterVisibility() then
                    if row and row._councilTable and candidate then
                        row._councilTable:ShowCandidateContextMenu(row, candidate)
                    end
                    return
                end
                if candidate and candidate.name and ns.ShowCandidateProfile then
                    ns.ShowCandidateProfile(candidate.name)
                end
            elseif button == "RightButton" then
                if row and row._councilTable and candidate then
                    row._councilTable:ShowCandidateContextMenu(row, candidate)
                end
            end
        end)
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
        row._clickHooked = true
        row:SetScript("OnClick", function(r, button)
            if not r.candidate then return end
            if button == "RightButton" then
                r._councilTable:ShowCandidateContextMenu(r, r.candidate)
            elseif button == "LeftButton" then
                if IsAltKeyDown() and HasMasterLooterVisibility() then
                    r._councilTable:ShowCandidateContextMenu(r, r.candidate)
                    return
                end
                r._councilTable:SelectCandidate(r.candidate)
            end
        end)
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
        row.bg:SetColorTexture(unpack(SkinningMixin:GetColor("row")))
    else
        row.bg:SetColorTexture(unpack(SkinningMixin:GetColor("rowAlt")))
    end

    -- Selected highlight
    if self.selectedCandidate and candidate.name == self.selectedCandidate.name then
        row.bg:SetColorTexture(unpack(SkinningMixin:GetColor("rowSelected")))
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
            voteCell.voteButton._voteHooked = true
            voteCell.voteButton:SetScript("OnClick", function(btn)
                btn._parentRow._councilTable:OnVoteClick(btn._parentRow.candidate)
            end)
        end
    end

    -- Intel button click handler — opens the PlayerIntel modal for this
    -- candidate, threading the current item through as context so the
    -- Sims tab can render trinket + droptimizer projections for it.
    local intelCell = row.cells.intel
    if intelCell and intelCell.intelButton then
        intelCell.intelButton._parentRow = row
        if not intelCell.intelButton._intelHooked then
            intelCell.intelButton._intelHooked = true
            intelCell.intelButton:SetScript("OnClick", function(btn)
                local r = btn._parentRow
                local ct = r and r._councilTable
                local cand = r and r.candidate
                if not (ct and cand and cand.playerName and ns.ShowPlayerIntel) then return end
                local item = ct.currentItem
                -- Candidate class + spec come from the voting session layer
                -- where they're already resolved to the Blizzard class
                -- token (PALADIN / DEMONHUNTER / …) that TrinketSims
                -- expects. Pull from PlayerCache for spec when the
                -- candidate doesn't carry it directly.
                local cls = cand.class
                local spc = cand.spec
                if not spc and Loothing.PlayerCache and Loothing.PlayerCache.Get then
                    local cached = Loothing.PlayerCache:Get(cand.playerName or cand.name)
                    if cached then spc = spc or cached.spec; cls = cls or cached.class end
                end
                local ctx = item and {
                    itemID         = item.itemID,
                    itemLink       = item.itemLink,
                    itemName       = item.name,
                    itemLevel      = item.itemLevel,
                    equipSlot      = item.equipSlot,
                    candidateClass = cls,
                    candidateSpec  = spc,
                } or nil
                ns.ShowPlayerIntel(cand.playerName, { item = ctx })
            end)
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
            instanceName = self.currentItem.instanceData.name
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

        -- Loot count enrichment from history cache.
        -- Three branches, ordered by precedence:
        --   1. TestMode is on — leave whatever AddFakeCandidatesToItem seeded.
        --   2. TestMode is off AND we have a cache — assign from history.
        --   3. TestMode is off AND cache is unavailable — zero the counters so
        --      stale random values from a prior TestMode run cannot persist
        --      after `/lt test` is disabled mid-session.
        if not (TestMode and TestMode.enabled) then
            if countCache then
                local normalized = Utils.NormalizeName(candidate.playerName or candidate.name)
                local counts = normalized and countCache[normalized]
                candidate.itemsWonInstance = counts and counts.instance or 0
                candidate.itemsWonWeekly = counts and counts.weekly or 0
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

--- Select a candidate row — drives the row-selection highlight via
--- `self.selectedCandidate` (read by UpdateRow when painting the bg).
--- The detail tooltip was retired in v2.0.22; per-candidate intel /
--- sims / wishlist now live in the LoothingPlayerIntelFrame modal,
--- launched from the "Intel" column button on each row.
---
--- Also refreshes the action footer so the Award button enables the
--- moment a candidate is picked — the tooltip used to give the ML
--- visible feedback that the pick "took", and the footer state is the
--- remaining cue that confirmation landed.
function CouncilTableMixin:SelectCandidate(candidate)
    self.selectedCandidate = candidate
    self:RefreshCandidates()
    if self.UpdateActionButtons then self:UpdateActionButtons() end
    self:TriggerEvent("OnCandidateSelected", candidate)
end


--[[--------------------------------------------------------------------
    Context Menu
----------------------------------------------------------------------]]

function CouncilTableMixin:ShowCandidateContextMenu(row, candidate)
    local L = Loothing.Locale or {}
    local isML = HasMasterLooterVisibility()

    MenuUtil.CreateContextMenu(row, function(_, rootDescription)
        rootDescription:CreateTitle(candidate.name or "Unknown")

        -- Everyone-facing quick-nav: jump into this candidate's lifetime
        -- history profile. Available regardless of ML status. Label uses
        -- the short (realm-stripped) name for consistency with the rest
        -- of the addon's display conventions.
        if candidate.name and ns.ShowCandidateProfile then
            local short = Utils.GetShortName(candidate.name) or candidate.name
            rootDescription:CreateButton(
                L["VIEW_PROFILE_FMT"] and string.format(L["VIEW_PROFILE_FMT"], short)
                    or ("Profile: " .. short),
                function() ns.ShowCandidateProfile(candidate.name) end)
        end
        -- Item summary — where else has this item dropped and who won it?
        if self.currentItem and (self.currentItem.itemID or self.currentItem.itemLink)
            and ns.ShowItemSummary
        then
            local itemID = self.currentItem.itemID or self.currentItem.itemLink
            rootDescription:CreateButton(
                L["VIEW_ITEM_SUMMARY"] or "View item history",
                function() ns.ShowItemSummary(itemID) end)
        end
        -- Player intel modal (M+ / parses / attendance / loot / sims / wishlist).
        -- The item context is built at click-time (not menu-open-time) so
        -- the modal always opens against whatever item is currently
        -- selected — if a remote award switches items while the menu is
        -- sitting open, the user still gets fresh sim data.
        if candidate.playerName and ns.ShowPlayerIntel then
            rootDescription:CreateButton(
                L["VIEW_PLAYER_INTEL"] or "View player intel",
                function()
                    local cur = self.currentItem
                    local cls = candidate.class
                    local spc = candidate.spec
                    if not spc and Loothing.PlayerCache and Loothing.PlayerCache.Get then
                        local cached = Loothing.PlayerCache:Get(candidate.playerName or candidate.name)
                        if cached then spc = spc or cached.spec; cls = cls or cached.class end
                    end
                    local ctx = cur and {
                        itemID         = cur.itemID,
                        itemLink       = cur.itemLink,
                        itemName       = cur.name,
                        itemLevel      = cur.itemLevel,
                        equipSlot      = cur.equipSlot,
                        candidateClass = cls,
                        candidateSpec  = spc,
                    } or nil
                    ns.ShowPlayerIntel(candidate.playerName, { item = ctx })
                end)
        end
        rootDescription:CreateDivider()

        -- ML-only actions
        if isML and self.currentItem then
            local itemGUID = self.currentItem.guid

            rootDescription:CreateButton(L["AWARD_ITEM"], function()
                if Loothing.Session then
                    Loothing.Session:AwardItem(itemGUID, candidate.name)
                    self:TriggerEvent("OnCandidateAwarded", self.currentItem, candidate)
                end
            end)

            -- Award with response type. Route through ResponseManager:GetSortedResponses
            -- so guilds running custom button sets (extra responses, renamed
            -- IDs) see every response in the menu — the previous
            -- `ipairs(Loothing.ResponsePriority)` hardcoded the default-5
            -- list and silently hid customizations. Priority falls back to
            -- iterating ResponseInfo in a stable order if ResponseManager
            -- is unavailable during early init.
            local orderedResponses = iterateOrderedResponses()
            for _, info in ipairs(orderedResponses) do
                local label = string.format(L["AWARD_PREFIX_FMT"], info.name)
                rootDescription:CreateButton(label, function()
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

        -- Change response (ML only). Same ordered-custom-safe iteration as above.
        if isML then
            local responseSubmenu = rootDescription:CreateButton(L["CHANGE_RESPONSE"], nop)
            for _, info in ipairs(iterateOrderedResponses()) do
                local responseID = info.id
                if responseID then
                    responseSubmenu:CreateButton(info.name, function()
                        if self.currentItem and self.currentItem.candidateManager then
                            self.currentItem.candidateManager:SetCandidateResponse(candidate.name, responseID)
                            self:RefreshCandidates()
                        end
                    end)
                end
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
