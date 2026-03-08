--[[--------------------------------------------------------------------
    Loothing UI - Candidate Result Row Component
    Per-candidate row for the ResultsPanel showing name, response,
    roll, council votes, and winner highlight.
----------------------------------------------------------------------]]

--- Create a candidate result row and return the frame
-- @param parent Frame - Scroll content parent
-- @param candidate table - LoothingCandidateMixin
-- @param yOffset number - Vertical offset
-- @param totalVotes number - Total council votes for percentage
-- @param isWinner boolean - Whether this candidate is the winner
-- @param onClick function|nil - Called with (candidate, row) on click
function LoothingUI_CreateCandidateResultRow(parent, candidate, yOffset, totalVotes, isWinner, onClick)
    local row = CreateFrame("Button", nil, parent, "BackdropTemplate")
    row:SetPoint("TOPLEFT", 0, yOffset)
    row:SetPoint("TOPRIGHT", 0, yOffset)
    row:SetHeight(60)

    row:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        tile = false,
        tileSize = 0,
        edgeSize = 1,
        insets = { left = 0, right = 0, top = 0, bottom = 0 },
    })

    -- Look up response info from both standard and system response tables
    local responseInfo = nil
    local response = candidate.response
    if response then
        responseInfo = LOOTHING_RESPONSE_INFO[response] or LOOTHING_SYSTEM_RESPONSE_INFO[response]
    end

    local rawColor = (responseInfo and responseInfo.color) or { r = 0.5, g = 0.5, b = 0.5 }
    local r, g, b
    if rawColor.r then
        r, g, b = rawColor.r, rawColor.g, rawColor.b
    else
        r, g, b = rawColor[1] or 0.5, rawColor[2] or 0.5, rawColor[3] or 0.5
    end

    -- Store base colors for hover/select restore
    row._bgR, row._bgG, row._bgB = r, g, b
    row._isSelected = false

    row:SetBackdropColor(r * 0.2, g * 0.2, b * 0.2, 0.8)
    row:SetBackdropBorderColor(r * 0.5, g * 0.5, b * 0.5, 1)

    -- Left color bar
    local colorBar = row:CreateTexture(nil, "ARTWORK")
    colorBar:SetSize(4, 58)
    colorBar:SetPoint("LEFT", 1, 0)
    colorBar:SetTexture("Interface\\Buttons\\WHITE8X8")
    colorBar:SetVertexColor(r, g, b, 1)

    -- Player name (class-colored, top-left)
    local nameText = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    nameText:SetPoint("TOPLEFT", colorBar, "TOPRIGHT", 8, -4)
    if candidate.GetColoredName then
        nameText:SetText(candidate:GetColoredName())
    else
        nameText:SetText(candidate.playerName or "Unknown")
    end

    -- Council votes count (top-right, large)
    local votesText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    votesText:SetPoint("TOPRIGHT", -8, -4)
    local councilVotes = candidate.councilVotes or 0
    votesText:SetText(tostring(councilVotes))
    votesText:SetTextColor(1, 1, 1)

    -- Response badge (below name)
    local responseName = (responseInfo and responseInfo.name) or "No Response"
    local responseText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    responseText:SetPoint("TOPLEFT", nameText, "BOTTOMLEFT", 0, -2)
    responseText:SetText(responseName)
    responseText:SetTextColor(r, g, b)

    -- Roll value (right of response)
    if candidate.roll then
        local rollText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        rollText:SetPoint("LEFT", responseText, "RIGHT", 8, 0)
        rollText:SetText(string.format("Roll: %d", candidate.roll))
        rollText:SetTextColor(0.8, 0.8, 0.8)
    end

    -- Vote percentage bar
    local total = totalVotes or 1
    local percentage = total > 0 and (councilVotes / total) or 0

    local barBg = row:CreateTexture(nil, "BACKGROUND")
    barBg:SetPoint("TOPLEFT", responseText, "BOTTOMLEFT", 0, -4)
    barBg:SetSize(200, 12)
    barBg:SetTexture("Interface\\Buttons\\WHITE8X8")
    barBg:SetVertexColor(0.1, 0.1, 0.1, 0.8)

    local bar = row:CreateTexture(nil, "ARTWORK")
    bar:SetPoint("TOPLEFT", barBg, "TOPLEFT", 1, -1)
    bar:SetSize(math.max(1, (200 - 2) * percentage), 10)
    bar:SetTexture("Interface\\Buttons\\WHITE8X8")
    bar:SetVertexColor(r, g, b, 0.8)

    local percentText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    percentText:SetPoint("LEFT", barBg, "RIGHT", 4, 0)
    if total > 0 then
        percentText:SetText(string.format("%.0f%%", percentage * 100))
    else
        percentText:SetText("")
    end
    percentText:SetTextColor(0.7, 0.7, 0.7)

    -- Winner glow
    if isWinner then
        local glow = row:CreateTexture(nil, "OVERLAY")
        glow:SetAllPoints()
        glow:SetTexture("Interface\\Buttons\\WHITE8X8")
        glow:SetVertexColor(1, 0.82, 0, 0.1)

        local winnerBadge = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        winnerBadge:SetPoint("RIGHT", votesText, "LEFT", -8, 0)
        winnerBadge:SetText(LOOTHING_LOCALE["WINNER"])
        winnerBadge:SetTextColor(1, 0.82, 0)
    end

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

    -- Click handler
    row:SetScript("OnClick", function(self)
        if onClick then
            onClick(candidate, self)
        end
    end)

    return row
end
