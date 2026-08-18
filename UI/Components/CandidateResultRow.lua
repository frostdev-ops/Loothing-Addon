--[[--------------------------------------------------------------------
    Loothing UI - Candidate Result Row Component
    Per-candidate row for the ResultsPanel showing name, response,
    roll, council votes, and winner highlight.

    Rows are pooled: WoW never destroys frames, and DisplayResults runs on
    every VOTE_RESULTS / Results-button open — creating fresh frames each
    refresh leaked a frame + ~10 regions per candidate per refresh. Callers
    pass a pool table and release rows back into it (see ResultsPanel).
----------------------------------------------------------------------]]

local _, ns = ...
local Loothing = ns.Addon

local BAR_WIDTH = 200

--- Build a bare row frame with every region created once.
-- Scripts read dynamic fields (row.candidate / row._onClick / row._bg*),
-- never per-refresh captures, so recycled rows stay correct.
local function ConstructRow(parent)
    local row = CreateFrame("Button", nil, parent, "BackdropTemplate")
    row:SetHeight(60)

    row:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        tile = false,
        tileSize = 0,
        edgeSize = 1,
        insets = { left = 0, right = 0, top = 0, bottom = 0 },
    })

    -- Left color bar
    row.colorBar = row:CreateTexture(nil, "ARTWORK")
    row.colorBar:SetSize(4, 58)
    row.colorBar:SetPoint("LEFT", 1, 0)
    row.colorBar:SetTexture("Interface\\Buttons\\WHITE8X8")

    -- Player name (class-colored, top-left)
    row.nameText = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    row.nameText:SetPoint("TOPLEFT", row.colorBar, "TOPRIGHT", 8, -4)

    -- Council votes count (top-right, large)
    row.votesText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    row.votesText:SetPoint("TOPRIGHT", -8, -4)
    row.votesText:SetTextColor(1, 1, 1)

    -- Response badge (below name)
    row.responseText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.responseText:SetPoint("TOPLEFT", row.nameText, "BOTTOMLEFT", 0, -2)

    -- Roll value (right of response)
    row.rollText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.rollText:SetPoint("LEFT", row.responseText, "RIGHT", 8, 0)
    row.rollText:SetTextColor(0.8, 0.8, 0.8)

    -- Vote percentage bar
    row.barBg = row:CreateTexture(nil, "BACKGROUND")
    row.barBg:SetPoint("TOPLEFT", row.responseText, "BOTTOMLEFT", 0, -4)
    row.barBg:SetSize(BAR_WIDTH, 12)
    row.barBg:SetTexture("Interface\\Buttons\\WHITE8X8")
    row.barBg:SetVertexColor(0.1, 0.1, 0.1, 0.8)

    row.bar = row:CreateTexture(nil, "ARTWORK")
    row.bar:SetPoint("TOPLEFT", row.barBg, "TOPLEFT", 1, -1)
    row.bar:SetSize(1, 10)
    row.bar:SetTexture("Interface\\Buttons\\WHITE8X8")

    row.percentText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.percentText:SetPoint("LEFT", row.barBg, "RIGHT", 4, 0)
    row.percentText:SetTextColor(0.7, 0.7, 0.7)

    -- Winner glow + badge (hidden unless winner)
    row.glow = row:CreateTexture(nil, "OVERLAY")
    row.glow:SetAllPoints()
    row.glow:SetTexture("Interface\\Buttons\\WHITE8X8")
    row.glow:SetVertexColor(1, 0.82, 0, 0.1)
    row.glow:Hide()

    row.winnerBadge = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.winnerBadge:SetPoint("RIGHT", row.votesText, "LEFT", -8, 0)
    row.winnerBadge:SetTextColor(1, 0.82, 0)
    row.winnerBadge:Hide()

    -- Selection state API
    function row:SetSelected(selected)
        self._isSelected = selected
        local br, bg, bb = self._bgR, self._bgG, self._bgB
        if selected then
            self:SetBackdropColor(br * 0.25, bg * 0.25, bb * 0.25, 0.9)
            self:SetBackdropBorderColor(1, 0.82, 0, 1)
        else
            self:SetBackdropColor(br * 0.2, bg * 0.2, bb * 0.2, 0.8)
            self:SetBackdropBorderColor(br * 0.5, bg * 0.5, bb * 0.5, 1)
        end
    end

    -- Hover highlight
    row:SetScript("OnEnter", function(self)
        SetCursor("CAST_CURSOR")
        local br, bg, bb = self._bgR, self._bgG, self._bgB
        if self._isSelected then
            self:SetBackdropColor(br * 0.35, bg * 0.35, bb * 0.35, 0.95)
            self:SetBackdropBorderColor(1, 0.82, 0, 1)
        else
            self:SetBackdropColor(br * 0.3, bg * 0.3, bb * 0.3, 0.9)
            self:SetBackdropBorderColor(br * 0.6, bg * 0.6, bb * 0.6, 1)
        end
    end)

    row:SetScript("OnLeave", function(self)
        SetCursor(nil)
        local br, bg, bb = self._bgR, self._bgG, self._bgB
        if self._isSelected then
            self:SetBackdropColor(br * 0.25, bg * 0.25, bb * 0.25, 0.9)
            self:SetBackdropBorderColor(1, 0.82, 0, 1)
        else
            self:SetBackdropColor(br * 0.2, bg * 0.2, bb * 0.2, 0.8)
            self:SetBackdropBorderColor(br * 0.5, bg * 0.5, bb * 0.5, 1)
        end
    end)

    -- Click handler reads dynamic fields so recycled rows dispatch correctly
    row:SetScript("OnClick", function(self)
        if self._onClick then
            self._onClick(self.candidate, self)
        end
    end)

    return row
end

--- Create (or recycle) a candidate result row and return the frame
-- @param parent Frame - Scroll content parent
-- @param candidate table - CandidateMixin
-- @param yOffset number - Vertical offset
-- @param totalVotes number - Total council votes for percentage
-- @param isWinner boolean - Whether this candidate is the winner
-- @param onClick function|nil - Called with (candidate, row) on click
-- @param showVotes boolean|nil - Whether to show vote counts and percentages
-- @param showResponses boolean|nil - Whether to show response text/color
-- @param pool table|nil - Free list; released rows are recycled from here
local function CreateCandidateResultRow(parent, candidate, yOffset, totalVotes, isWinner, onClick, showVotes, showResponses, pool)
    showVotes = showVotes ~= false
    showResponses = showResponses ~= false

    local row = pool and table.remove(pool)
    if not row then
        row = ConstructRow(parent)
    end
    row:SetParent(parent)
    row:ClearAllPoints()
    row:SetPoint("TOPLEFT", 0, yOffset)
    row:SetPoint("TOPRIGHT", 0, yOffset)

    row.candidate = candidate
    row._onClick = onClick
    row._isSelected = false

    -- Look up response info from both standard and system response tables
    local responseInfo = nil
    local response = candidate.response
    if response then
        responseInfo = Loothing.ResponseInfo[response] or Loothing.SystemResponseInfo[response]
    end

    local rawColor = (showResponses and responseInfo and responseInfo.color) or { r = 0.5, g = 0.5, b = 0.5 }
    local r, g, b
    if rawColor.r then
        r, g, b = rawColor.r, rawColor.g, rawColor.b
    else
        r, g, b = rawColor[1] or 0.5, rawColor[2] or 0.5, rawColor[3] or 0.5
    end

    -- Store base colors for hover/select restore
    row._bgR, row._bgG, row._bgB = r, g, b

    row:SetBackdropColor(r * 0.2, g * 0.2, b * 0.2, 0.8)
    row:SetBackdropBorderColor(r * 0.5, g * 0.5, b * 0.5, 1)
    row.colorBar:SetVertexColor(r, g, b, 1)

    if candidate.GetColoredName then
        row.nameText:SetText(candidate:GetColoredName())
    else
        row.nameText:SetText(candidate.playerName or "Unknown")
    end

    local councilVotes = candidate.councilVotes or 0
    row.votesText:SetText(showVotes and tostring(councilVotes) or "")

    local responseName = showResponses and ((responseInfo and responseInfo.name) or "No Response")
        or (Loothing.Locale and Loothing.Locale["RESPONSES_HIDDEN"] or "Responses hidden")
    row.responseText:SetText(responseName)
    row.responseText:SetTextColor(r, g, b)

    if showResponses and candidate.roll then
        row.rollText:SetText(string.format("Roll: %d", candidate.roll))
        row.rollText:Show()
    else
        row.rollText:SetText("")
        row.rollText:Hide()
    end

    -- Vote percentage bar
    local total = totalVotes or 1
    local percentage = total > 0 and (councilVotes / total) or 0
    row.bar:SetSize(math.max(1, (BAR_WIDTH - 2) * percentage), 10)
    row.bar:SetVertexColor(r, g, b, 0.8)
    if showVotes then
        row.barBg:Show()
        row.bar:Show()
    else
        row.barBg:Hide()
        row.bar:Hide()
    end

    if showVotes and total > 0 then
        row.percentText:SetText(string.format("%.0f%%", percentage * 100))
    else
        row.percentText:SetText("")
    end

    if isWinner then
        row.glow:Show()
        row.winnerBadge:SetText(Loothing.Locale["WINNER"])
        row.winnerBadge:Show()
    else
        row.glow:Hide()
        row.winnerBadge:Hide()
    end

    row:Show()
    return row
end

--- Release a row back into a pool for reuse.
-- @param row Frame - Row produced by CreateCandidateResultRow
-- @param pool table - Free list to return it to
local function ReleaseCandidateResultRow(row, pool)
    if not row then return end
    row:Hide()
    row:ClearAllPoints()
    row.candidate = nil
    row._onClick = nil
    row._isSelected = false
    if pool then
        pool[#pool + 1] = row
    end
end

ns.CreateCandidateResultRow = CreateCandidateResultRow
ns.ReleaseCandidateResultRow = ReleaseCandidateResultRow
