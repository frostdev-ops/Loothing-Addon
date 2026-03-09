--[[--------------------------------------------------------------------
    Loothing UI - Response Row Component
    Shared row builder for results lists.
----------------------------------------------------------------------]]

-- Create a response row and return the frame
-- @param parent Frame - Scroll content parent
-- @param data table - { response, count, voters, info }
-- @param yOffset number - Vertical offset
-- @param totalVotes number - Total vote count for percentage
-- @param isWinner boolean - whether this response is the winner
function LoothingUI_CreateResponseRow(parent, data, yOffset, totalVotes, isWinner)
    local row = CreateFrame("Frame", nil, parent, "BackdropTemplate")
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

    local rawColor = (data.info and data.info.color) or { r = 0.5, g = 0.5, b = 0.5 }
    local r, g, b
    if rawColor.r then
        r, g, b = rawColor.r, rawColor.g, rawColor.b
    else
        r, g, b = rawColor[1] or 0.5, rawColor[2] or 0.5, rawColor[3] or 0.5
    end
    row:SetBackdropColor(r * 0.2, g * 0.2, b * 0.2, 0.8)
    row:SetBackdropBorderColor(r * 0.5, g * 0.5, b * 0.5, 1)

    local colorBar = row:CreateTexture(nil, "ARTWORK")
    colorBar:SetSize(4, 58)
    colorBar:SetPoint("LEFT", 1, 0)
    colorBar:SetTexture("Interface\\Buttons\\WHITE8X8")
    colorBar:SetVertexColor(r, g, b, 1)

    local nameText = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    nameText:SetPoint("TOPLEFT", colorBar, "TOPRIGHT", 8, -4)
    nameText:SetText((data.info and data.info.name) or "Unknown")
    nameText:SetTextColor(r, g, b)

    local countText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    countText:SetPoint("TOPRIGHT", -8, -4)
    countText:SetText(tostring(data.count))
    countText:SetTextColor(1, 1, 1)

    local total = totalVotes or 1
    local percentage = total > 0 and (data.count / total) or 0

    local barBg = row:CreateTexture(nil, "BACKGROUND")
    barBg:SetPoint("TOPLEFT", nameText, "BOTTOMLEFT", 0, -4)
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
    percentText:SetText(string.format("%.0f%%", percentage * 100))
    percentText:SetTextColor(0.7, 0.7, 0.7)

    local votersText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    votersText:SetPoint("BOTTOMLEFT", colorBar, "BOTTOMRIGHT", 8, 4)
    votersText:SetPoint("BOTTOMRIGHT", -8, 4)
    votersText:SetJustifyH("LEFT")
    votersText:SetWordWrap(false)

    if data.voters and #data.voters > 0 then
        local voterNames = {}
        for _, voter in ipairs(data.voters) do
            local shortName = LoothingUtils.GetShortName(voter)
            if IsInGroup() then
                local roster = LoothingUtils.GetRaidRoster()
                for _, entry in ipairs(roster) do
                    if LoothingUtils.IsSamePlayer(voter, entry.name) then
                        shortName = LoothingUtils.ColorByClass(shortName, entry.classFile)
                        break
                    end
                end
            end
            voterNames[#voterNames + 1] = shortName
        end
        votersText:SetText(table.concat(voterNames, ", "))
    else
        votersText:SetText("")
    end

    if isWinner then
        local glow = row:CreateTexture(nil, "OVERLAY")
        glow:SetAllPoints()
        glow:SetTexture("Interface\\Buttons\\WHITE8X8")
        glow:SetVertexColor(1, 0.82, 0, 0.1)

        local winnerText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        winnerText:SetPoint("RIGHT", countText, "LEFT", -8, 0)
        winnerText:SetText(Loothing.Locale["WINNER"])
        winnerText:SetTextColor(1, 0.82, 0)
    end

    return row
end

