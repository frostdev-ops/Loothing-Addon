--[[--------------------------------------------------------------------
    Loothing - PlayerIntelFrame

    Polished tabbed modal that surfaces everything Loothing.PlayerIntel
    knows about a given player. Replaces the cramped inline intel section
    that used to live inside the CouncilTable candidate detail tooltip.

    Public entry points:
        ns.ShowPlayerIntel(playerName)          - open the modal for a player
        ns.PlayerIntelFrames.ApplyTheme()       - theme-dispatch hook (Skinning.lua)

    Tabs:
        Overview  — dashboard of stat cards at a glance
        M+        — Mythic+ activity / score / best key this week
        Parses    — Warcraft Logs parse averages, best, trend
        Raid      — attendance + gear readiness + progression
        Loot      — recent loot history + alt loot summary

    Built on ns.ModalFactory (UI/ModalFactory.lua), which provides:
        - CreateModal      : DIALOG-strata chrome with fade / resize / esc-close
        - CreateTabStrip   : sliding-indicator tab row
        - CreateScrollList : pool-backed scrollable list
        - skinColor / styleSurface / applyTextColor : skin shims

    Data contract (fields consumed from Loothing.PlayerIntel):
        mpWeek (count, highest), mpScore
        parseAvg, parseBest, parseBestBoss, parseTrend
        attendance, raidCount, eventAttendPct, eventAttended, eventEligible
        tierCount, has2pc, has4pc, enchMissing, gemMissing, vaultSlots, raidProg
        loot[]    : { date, name, resp, boss, diff }
        altLoot[] : { alt, cls, count, items }
        spec, class

    Load order: must come after UI/ModalFactory.lua and after
    UI/ThemedScrollBar.lua (for ns.ApplyThemedScrollBar).
----------------------------------------------------------------------]]

local _, ns = ...
local Loolib = LibStub("Loolib")
local Loothing = ns.Addon
local Utils = ns.Utils
local SkinningMixin = ns.SkinningMixin
local format = string.format

--[[--------------------------------------------------------------------
    Constants
----------------------------------------------------------------------]]

local INTEL_WIDTH  = 640   -- Room for 7 tabs (Overview / M+ / Parses / Raid / Loot / Sims / Wishlist) plus breathing space in each tab's content.
local INTEL_HEIGHT = 520

local HEADER_HEIGHT = 72          -- name + badges + tab strip
local FOOTER_HEIGHT = 32
local STAT_CARD_HEIGHT = 78       -- ~2px taller so captions don't kiss the value baseline.
local LOOT_ROW_HEIGHT  = 30
local WISH_ROW_HEIGHT  = 32       -- wishlist entry row (icon + name + priority + tags)

-- Staleness thresholds (seconds)
local STALE_WARNING  = 4 * 3600
local STALE_CRITICAL = 24 * 3600

-- Desktop-synced item quality arrives as a Blizzard localized name
-- ("Epic", "Rare", "Legendary", …). Blizzard's C_Item.GetItemQualityColor
-- expects an Enum.ItemQuality integer — it throws on strings. Map known
-- English names back to ints; anything unknown falls through to white.
local QUALITY_NAME_TO_INT = {
    poor       = 0,
    common     = 1,
    uncommon   = 2,
    rare       = 3,
    epic       = 4,
    legendary  = 5,
    artifact   = 6,
    heirloom   = 7,
    -- WoWHead / third-party alternate spellings
    ["war bound"] = 8,
    wowtoken   = 9,
}

-- Forward-declared singleton slot so ApplyTheme dispatch can reference it.
local intelInstance

--[[--------------------------------------------------------------------
    Locale / helper shims
----------------------------------------------------------------------]]

local function L(key, fallback)
    local locale = ns.Locale or Loothing.Locale or {}
    return locale[key] or fallback or key
end

local function MF()
    return ns.ModalFactory
end

local function skinColor(key, fallback)
    local mf = MF()
    if mf and mf.SkinColor then return mf.SkinColor(key, fallback) end
    return fallback or { 1, 1, 1, 1 }
end

local function applyTextColor(fs, key, fallback)
    local mf = MF()
    if mf and mf.ApplyTextColor then mf.ApplyTextColor(fs, key, fallback) end
end

local function styleSurface(frame, variant)
    local mf = MF()
    if mf and mf.StyleSurface then mf.StyleSurface(frame, variant) end
end

--- Resolve class color for a class file (e.g. "PALADIN"). Falls back to white.
local function classRGB(classFile)
    if classFile and RAID_CLASS_COLORS and RAID_CLASS_COLORS[classFile] then
        local c = RAID_CLASS_COLORS[classFile]
        return c.r or 1, c.g or 1, c.b or 1
    end
    if classFile and Loothing.ClassColors and Loothing.ClassColors[classFile] then
        local c = Loothing.ClassColors[classFile]
        return c.r or 1, c.g or 1, c.b or 1
    end
    return 1, 1, 1
end

--- Short display name (strip realm).
local function shortName(fullName)
    if not fullName then return "" end
    if Utils and Utils.GetShortName then
        return Utils.GetShortName(fullName) or fullName
    end
    return fullName:match("^([^-]+)") or fullName
end

--- Format a duration into a compact "2h ago" / "3d ago" string.
local function formatAge(seconds)
    if type(seconds) ~= "number" then return "" end
    if seconds < 60 then return "Just now" end
    if seconds < 3600 then return format("%dm ago", math.floor(seconds / 60)) end
    if seconds < 86400 then return format("%dh ago", math.floor(seconds / 3600)) end
    return format("%dd ago", math.floor(seconds / 86400))
end

--[[--------------------------------------------------------------------
    Stat card widget

    Small reusable card with:
      - left accent bar (2 px)
      - top label in textSubtle
      - big value in text/accent (FontNormalHuge)
      - bottom caption in textMuted

    Backdrop uses "panelInset" so cards feel sunken relative to the
    modal's main surface. All four children are exposed on the returned
    table so the owner can retint them in ApplyTheme.
----------------------------------------------------------------------]]

local function CreateStatCard(parent, opts)
    opts = opts or {}
    local card = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    card:SetHeight(opts.height or STAT_CARD_HEIGHT)

    if card.SetBackdrop then
        card:SetBackdrop({
            bgFile   = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Buttons\\WHITE8x8",
            tile = false, edgeSize = 1,
            insets = { left = 1, right = 1, top = 1, bottom = 1 },
        })
        card:SetBackdropColor(unpack(skinColor("panelInset", { 0.04, 0.05, 0.07, 0.5 })))
        card:SetBackdropBorderColor(unpack(skinColor("border", { 0.2, 0.2, 0.2, 1 })))
    end

    -- Left accent bar (HIGHLIGHT-independent, always visible)
    local accent = card:CreateTexture(nil, "ARTWORK", nil, 2)
    accent:SetPoint("TOPLEFT", 0, 0)
    accent:SetPoint("BOTTOMLEFT", 0, 0)
    accent:SetWidth(2)
    accent:SetColorTexture(unpack(skinColor("accent", { 1, 0.82, 0, 1 })))

    -- Label (top). Both anchors point at the TOP edge so the FontString
    -- lies flat along the top of the card; mixing TOPLEFT with RIGHT
    -- stretches the bounding box diagonally and pushes the baseline
    -- down into the value row.
    local label = card:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    label:SetPoint("TOPLEFT", 10, -8)
    label:SetPoint("TOPRIGHT", -8, -8)
    label:SetHeight(14)
    label:SetJustifyH("LEFT")
    label:SetJustifyV("TOP")
    label:SetText(opts.label or "")
    applyTextColor(label, "textSubtle", { 0.55, 0.58, 0.65 })

    -- Value (middle) — big. Anchored below the label so the Huge font
    -- doesn't collide with it when the card is compact.
    local value = card:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
    value:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 0, -2)
    value:SetPoint("TOPRIGHT", label, "BOTTOMRIGHT", 0, -2)
    value:SetHeight(26)
    value:SetJustifyH("LEFT")
    value:SetJustifyV("MIDDLE")
    value:SetWordWrap(false)
    value:SetText("")
    applyTextColor(value, "text", { 1, 1, 1 })

    -- Caption (bottom). BOTTOMLEFT + BOTTOMRIGHT so the line sits flush
    -- with the card's bottom edge and wraps predictably.
    local caption = card:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    caption:SetPoint("BOTTOMLEFT", 10, 6)
    caption:SetPoint("BOTTOMRIGHT", -8, 6)
    caption:SetHeight(14)
    caption:SetJustifyH("LEFT")
    caption:SetJustifyV("BOTTOM")
    caption:SetWordWrap(false)
    caption:SetText("")
    applyTextColor(caption, "textMuted", { 0.7, 0.72, 0.76 })

    local out = {
        frame   = card,
        accent  = accent,
        label   = label,
        value   = value,
        caption = caption,
    }

    function out:SetValue(text, colorKey, fallback)
        self.value:SetText(text or "")
        applyTextColor(self.value, colorKey or "text", fallback or { 1, 1, 1 })
    end

    function out:SetCaption(text, colorKey, fallback)
        self.caption:SetText(text or "")
        applyTextColor(self.caption, colorKey or "textMuted", fallback or { 0.7, 0.72, 0.76 })
    end

    function out:SetAccent(colorKey, fallback)
        self.accent:SetColorTexture(unpack(skinColor(colorKey or "accent", fallback or { 1, 0.82, 0, 1 })))
    end

    function out:ApplyTheme()
        if self.frame.SetBackdropColor then
            self.frame:SetBackdropColor(unpack(skinColor("panelInset", { 0.04, 0.05, 0.07, 0.5 })))
            self.frame:SetBackdropBorderColor(unpack(skinColor("border", { 0.2, 0.2, 0.2, 1 })))
        end
    end

    return out
end

--[[--------------------------------------------------------------------
    Tab panel container

    Each tab's content lives on its own Frame parented to the shared
    content container. SelectTab hides prev, Shows new — no layout
    recompute, each panel lays itself out once at build time.
----------------------------------------------------------------------]]

local function CreateTabPanel(parent)
    local panel = CreateFrame("Frame", nil, parent)
    panel:SetPoint("TOPLEFT", 0, 0)
    panel:SetPoint("BOTTOMRIGHT", 0, 0)
    panel:Hide()
    return panel
end

--[[--------------------------------------------------------------------
    Tab builders

    One function per tab. Each receives the panel frame + a table that
    the outer factory uses to stash references for ApplyTheme / Bind.
----------------------------------------------------------------------]]

local function BuildOverviewTab(panel, refs)
    -- 2x3 grid: M+, Parses, Attendance | Gear, Vault, Loot-count
    local gutter = 8
    local colWidth  = (INTEL_WIDTH - 20 - gutter) / 2
    local rowHeight = STAT_CARD_HEIGHT

    local function makeCard(col, row, opts)
        local card = CreateStatCard(panel, opts)
        local x = (col - 1) * (colWidth + gutter)
        local y = (row - 1) * (rowHeight + gutter)
        card.frame:SetWidth(colWidth)
        card.frame:ClearAllPoints()
        card.frame:SetPoint("TOPLEFT", x, -y)
        return card
    end

    refs.overviewCards = {
        mplus      = makeCard(1, 1, { label = L("INTEL_CARD_MPLUS", "Mythic+") }),
        parses     = makeCard(2, 1, { label = L("INTEL_CARD_PARSES", "Parses") }),
        attendance = makeCard(1, 2, { label = L("INTEL_CARD_ATTENDANCE", "Attendance") }),
        gear       = makeCard(2, 2, { label = L("INTEL_CARD_TIER", "Tier set") }),
        vault      = makeCard(1, 3, { label = L("INTEL_CARD_VAULT", "Vault") }),
        loot       = makeCard(2, 3, { label = L("INTEL_CARD_LOOT", "Recent loot") }),
    }
end

local function BindOverviewTab(refs, intel)
    local cards = refs.overviewCards or {}

    -- Mythic+
    if cards.mplus then
        if intel.mpScore and intel.mpScore > 0 then
            cards.mplus:SetValue(format("%d", math.floor(intel.mpScore + 0.5)), "accent", { 0.4, 0.8, 1 })
        else
            cards.mplus:SetValue("—", "textSubtle", { 0.5, 0.5, 0.5 })
        end
        local weekBits = {}
        if intel.mpWeek and intel.mpWeek.count and intel.mpWeek.count > 0 then
            weekBits[#weekBits + 1] = format("%d keys", intel.mpWeek.count)
        end
        if intel.mpWeek and intel.mpWeek.highest and intel.mpWeek.highest > 0 then
            weekBits[#weekBits + 1] = format("+%d best", intel.mpWeek.highest)
        end
        cards.mplus:SetCaption(#weekBits > 0 and table.concat(weekBits, "  ·  ") or L("INTEL_NO_KEYS", "No keys this week"))
        cards.mplus:SetAccent("accentCool", { 0.35, 0.55, 0.9, 1 })
    end

    -- Parses — caption keeps the best-parse number + shortened boss name
    -- (everything before the first comma) so long boss titles like
    -- "Chimaerus, the Undreamt God" don't overflow the 300px card.
    if cards.parses then
        if intel.parseAvg then
            cards.parses:SetValue(format("%.0f", intel.parseAvg), "warning", { 1, 0.82, 0 })
        else
            cards.parses:SetValue("—", "textSubtle", { 0.5, 0.5, 0.5 })
        end
        local parseBits = {}
        if intel.parseBest then
            parseBits[#parseBits + 1] = format("best %.0f", intel.parseBest)
        end
        if intel.parseBestBoss then
            -- Strip the subtitle clause after the first comma, then cap
            -- at ~22 chars so boss names without a comma ("The Primordial
            -- Destroyer Unleashed") don't overrun the 300-px overview card.
            local short = intel.parseBestBoss:match("^([^,]+)") or intel.parseBestBoss
            if #short > 22 then short = short:sub(1, 20) .. "…" end
            parseBits[#parseBits + 1] = short
        end
        cards.parses:SetCaption(#parseBits > 0 and table.concat(parseBits, "  ·  ") or L("INTEL_NO_PARSES", "No logged parses"))
        cards.parses:SetAccent("warning", { 1, 0.82, 0, 1 })
    end

    -- Attendance
    if cards.attendance then
        local pct
        if intel.eventAttendPct then
            pct = intel.eventAttendPct
        elseif intel.attendance then
            pct = intel.attendance * 100
        end
        if pct then
            cards.attendance:SetValue(format("%d%%", math.floor(pct + 0.5)), "success", { 0.3, 0.85, 0.35 })
        else
            cards.attendance:SetValue("—", "textSubtle", { 0.5, 0.5, 0.5 })
        end
        local attBits = {}
        if intel.eventAttended and intel.eventEligible then
            attBits[#attBits + 1] = format("%d/%d events", intel.eventAttended, intel.eventEligible)
        end
        if intel.raidCount and intel.raidCount > 0 then
            attBits[#attBits + 1] = format("%d raid dates", intel.raidCount)
        end
        cards.attendance:SetCaption(#attBits > 0 and table.concat(attBits, "  ·  ") or L("INTEL_NO_ATTENDANCE", "No records"))
        cards.attendance:SetAccent("success", { 0.3, 0.85, 0.35, 1 })
    end

    -- Tier set. Accent literals set directly: SetAccent(nil, fallback)
    -- resolves the theme's "accent" key (the fallback is only used when
    -- the key is missing), so the 2pc/4pc color coding never rendered.
    if cards.gear then
        if intel.tierCount and intel.tierCount > 0 then
            cards.gear:SetValue(format("%dpc", intel.tierCount), "text", { 1, 1, 1 })
            if intel.has4pc then
                cards.gear:SetValue(format("%dpc", intel.tierCount), nil, nil)
                cards.gear.value:SetTextColor(0.64, 0.21, 0.93) -- legendary/epic violet
                cards.gear.accent:SetColorTexture(0.64, 0.21, 0.93, 1)
            elseif intel.has2pc then
                cards.gear.value:SetTextColor(0, 0.44, 0.87)     -- rare blue
                cards.gear.accent:SetColorTexture(0, 0.44, 0.87, 1)
            else
                cards.gear:SetAccent()  -- theme accent for 1pc
            end
        else
            cards.gear:SetValue("—", "textSubtle", { 0.5, 0.5, 0.5 })
            -- Reset: a previously-bound player's 2pc/4pc accent otherwise
            -- leaks onto the no-tier card
            cards.gear:SetAccent()
        end
        local gearBits = {}
        if intel.enchMissing == 0 then
            gearBits[#gearBits + 1] = "|cff33ee33Fully enchanted|r"
        elseif intel.enchMissing and intel.enchMissing > 0 then
            gearBits[#gearBits + 1] = format("|cffee3333%d missing enchants|r", intel.enchMissing)
        end
        if intel.gemMissing == 0 then
            gearBits[#gearBits + 1] = "|cff33ee33Gemmed|r"
        elseif intel.gemMissing and intel.gemMissing > 0 then
            gearBits[#gearBits + 1] = format("|cffee3333%d missing gems|r", intel.gemMissing)
        end
        cards.gear:SetCaption(#gearBits > 0 and table.concat(gearBits, "  ·  ") or L("INTEL_NO_GEAR", "Gear status unknown"))
    end

    -- Vault
    if cards.vault then
        if intel.vaultSlots then
            cards.vault:SetValue(format("%d/9", intel.vaultSlots), "accent", { 0.6, 0.85, 1 })
        else
            cards.vault:SetValue("—", "textSubtle", { 0.5, 0.5, 0.5 })
        end
        cards.vault:SetCaption(intel.raidProg or L("INTEL_NO_PROGRESSION", "Progression unknown"))
        cards.vault:SetAccent("accentCool", { 0.35, 0.55, 0.9, 1 })
    end

    -- Loot count
    if cards.loot then
        local lootCount = intel.loot and #intel.loot or 0
        if lootCount > 0 then
            cards.loot:SetValue(tostring(lootCount), "text", { 1, 1, 1 })
            cards.loot:SetCaption(L("INTEL_LOOT_THIS_TIER", "items this tier"))
        else
            cards.loot:SetValue("0", "textSubtle", { 0.5, 0.5, 0.5 })
            cards.loot:SetCaption(L("INTEL_NO_LOOT_TIER", "No loot this tier"))
        end
        cards.loot:SetAccent("border", { 0.4, 0.4, 0.4, 1 })
    end
end

--- M+ tab — score + keys + highest with bigger typography.
local function BuildMPlusTab(panel, refs)
    -- Three hero metrics across the top
    local gutter = 10
    local colWidth = (INTEL_WIDTH - 20 - gutter * 2) / 3

    local function makeHero(i, opts)
        local card = CreateStatCard(panel, opts)
        card.frame:SetWidth(colWidth)
        card.frame:SetHeight(90)
        card.frame:ClearAllPoints()
        card.frame:SetPoint("TOPLEFT", (i - 1) * (colWidth + gutter), 0)
        card.value:ClearAllPoints()
        card.value:SetPoint("LEFT", 10, 0)
        card.value:SetPoint("RIGHT", -8, 0)
        return card
    end

    refs.mplusCards = {
        score   = makeHero(1, { label = L("INTEL_MPLUS_SCORE", "Rating") }),
        keys    = makeHero(2, { label = L("INTEL_MPLUS_KEYS", "Keys this week") }),
        highest = makeHero(3, { label = L("INTEL_MPLUS_HIGHEST", "Highest key") }),
    }

    -- Info strip below
    local infoStrip = CreateFrame("Frame", nil, panel, "BackdropTemplate")
    infoStrip:SetPoint("TOPLEFT", 0, -100)
    infoStrip:SetPoint("TOPRIGHT", 0, -100)
    infoStrip:SetHeight(60)
    if infoStrip.SetBackdrop then
        infoStrip:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Buttons\\WHITE8x8",
            tile = false, edgeSize = 1,
            insets = { left = 1, right = 1, top = 1, bottom = 1 },
        })
        infoStrip:SetBackdropColor(unpack(skinColor("panelInset", { 0.04, 0.05, 0.07, 0.5 })))
        infoStrip:SetBackdropBorderColor(unpack(skinColor("border", { 0.2, 0.2, 0.2, 1 })))
    end
    refs.mplusInfoStrip = infoStrip

    local info = infoStrip:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    info:SetPoint("TOPLEFT", 12, -10)
    info:SetPoint("BOTTOMRIGHT", -12, 10)
    info:SetJustifyH("LEFT")
    info:SetJustifyV("TOP")
    info:SetWordWrap(true)
    refs.mplusInfoText = info

    -- Empty-state message
    local empty = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    empty:SetPoint("CENTER")
    empty:SetText(L("INTEL_MPLUS_EMPTY", "No Mythic+ activity recorded this week."))
    applyTextColor(empty, "textSubtle", { 0.5, 0.5, 0.5 })
    empty:Hide()
    refs.mplusEmpty = empty
end

local function BindMPlusTab(refs, intel)
    local cards = refs.mplusCards or {}
    local hasAny = (intel.mpScore and intel.mpScore > 0)
        or (intel.mpWeek and ((intel.mpWeek.count or 0) > 0 or (intel.mpWeek.highest or 0) > 0))

    if cards.score then
        cards.score:SetValue(intel.mpScore and format("%d", math.floor(intel.mpScore + 0.5)) or "—",
            intel.mpScore and "accent" or "textSubtle",
            intel.mpScore and { 0.4, 0.8, 1 } or { 0.5, 0.5, 0.5 })
        cards.score:SetCaption(L("INTEL_MPLUS_RATING_CAPTION", "raider.io / detail"))
        cards.score:SetAccent("accentCool", { 0.35, 0.55, 0.9, 1 })
    end
    if cards.keys then
        local count = intel.mpWeek and intel.mpWeek.count or 0
        cards.keys:SetValue(tostring(count),
            count > 0 and "text" or "textSubtle",
            count > 0 and { 1, 1, 1 } or { 0.5, 0.5, 0.5 })
        cards.keys:SetCaption(L("INTEL_MPLUS_WEEK_CAPTION", "completed this reset"))
    end
    if cards.highest then
        local best = intel.mpWeek and intel.mpWeek.highest or 0
        cards.highest:SetValue(best > 0 and ("+" .. best) or "—",
            best > 0 and "warning" or "textSubtle",
            best > 0 and { 1, 0.82, 0 } or { 0.5, 0.5, 0.5 })
        cards.highest:SetCaption(L("INTEL_MPLUS_HIGHEST_CAPTION", "key completed"))
        cards.highest:SetAccent("warning", { 1, 0.82, 0, 1 })
    end

    if refs.mplusInfoText then
        local lines = {}
        if intel.mpScore and intel.mpScore > 0 then
            lines[#lines + 1] = format("|cff6699ccRaider.io rating:|r %d",
                math.floor(intel.mpScore + 0.5))
        end
        if intel.mpWeek and intel.mpWeek.count and intel.mpWeek.count > 0 then
            lines[#lines + 1] = format("|cffffffffThis week:|r %d keys run", intel.mpWeek.count)
        end
        if intel.mpWeek and intel.mpWeek.highest and intel.mpWeek.highest > 0 then
            lines[#lines + 1] = format("|cffffcc66Best this week:|r +%d", intel.mpWeek.highest)
        end
        refs.mplusInfoText:SetText(table.concat(lines, "\n"))
        refs.mplusInfoText:SetJustifyV("TOP")
        applyTextColor(refs.mplusInfoText, "text", { 1, 1, 1 })
    end

    if refs.mplusEmpty then
        refs.mplusEmpty:SetShown(not hasAny)
    end
    if refs.mplusInfoStrip then
        refs.mplusInfoStrip:SetShown(hasAny)
    end
end

--- Parses tab — big Avg + Best cards with trend glyph.
local function BuildParsesTab(panel, refs)
    local gutter = 10
    local colWidth = (INTEL_WIDTH - 20 - gutter) / 2

    local avg = CreateStatCard(panel, { label = L("INTEL_PARSE_AVG", "Average parse") })
    avg.frame:SetWidth(colWidth)
    avg.frame:SetHeight(100)
    avg.frame:ClearAllPoints()
    avg.frame:SetPoint("TOPLEFT", 0, 0)
    avg.value:ClearAllPoints()
    avg.value:SetPoint("LEFT", 10, 0)
    avg.value:SetPoint("RIGHT", -8, 0)
    refs.parseAvgCard = avg

    local best = CreateStatCard(panel, { label = L("INTEL_PARSE_BEST", "Best parse") })
    best.frame:SetWidth(colWidth)
    best.frame:SetHeight(100)
    best.frame:ClearAllPoints()
    best.frame:SetPoint("TOPLEFT", colWidth + gutter, 0)
    best.value:ClearAllPoints()
    best.value:SetPoint("LEFT", 10, 0)
    best.value:SetPoint("RIGHT", -36, 0)   -- leave room for trend glyph
    refs.parseBestCard = best

    -- Trend glyph inside the Best card
    local trend = best.frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    trend:SetPoint("RIGHT", best.frame, "RIGHT", -10, 4)
    if Loolib.Fonts and Loolib.Fonts.SetIconFont then
        Loolib.Fonts:SetIconFont(trend, 18, "")
    end
    trend:Hide()
    refs.parseTrend = trend

    -- Boss info strip. TOPLEFT+TOPRIGHT (not a bare RIGHT, which pins the
    -- string's vertical CENTER to the panel center and stacked both
    -- strips on top of each other mid-panel).
    local boss = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    boss:SetPoint("TOPLEFT", 0, -115)
    boss:SetPoint("TOPRIGHT", 0, -115)
    boss:SetJustifyH("LEFT")
    boss:SetJustifyV("TOP")
    boss:SetHeight(36)
    boss:SetWordWrap(true)
    applyTextColor(boss, "textMuted", { 0.7, 0.72, 0.76 })
    refs.parseBossText = boss

    -- Explainer
    local hint = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    hint:SetPoint("TOPLEFT", 0, -155)
    hint:SetPoint("TOPRIGHT", 0, -155)
    hint:SetJustifyH("LEFT")
    hint:SetJustifyV("TOP")
    hint:SetHeight(48)
    hint:SetWordWrap(true)
    hint:SetText(L("INTEL_PARSE_HINT",
        "Averages and bests come from Warcraft Logs. Trend indicates whether recent parses are trending up, holding steady, or dropping."))
    applyTextColor(hint, "textSubtle", { 0.5, 0.55, 0.6 })
    refs.parseHintText = hint

    local empty = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    empty:SetPoint("CENTER")
    empty:SetText(L("INTEL_PARSES_EMPTY", "No parse data uploaded yet."))
    applyTextColor(empty, "textSubtle", { 0.5, 0.5, 0.5 })
    empty:Hide()
    refs.parseEmpty = empty
end

local function BindParsesTab(refs, intel)
    local hasAny = intel.parseAvg or intel.parseBest

    if refs.parseAvgCard then
        refs.parseAvgCard:SetValue(
            intel.parseAvg and format("%.0f", intel.parseAvg) or "—",
            intel.parseAvg and "warning" or "textSubtle",
            intel.parseAvg and { 1, 0.82, 0 } or { 0.5, 0.5, 0.5 })
        refs.parseAvgCard:SetCaption(L("INTEL_PARSE_AVG_CAPTION", "across tracked bosses"))
        refs.parseAvgCard:SetAccent("warning", { 1, 0.82, 0, 1 })
    end

    if refs.parseBestCard then
        refs.parseBestCard:SetValue(
            intel.parseBest and format("%.0f", intel.parseBest) or "—",
            intel.parseBest and "success" or "textSubtle",
            intel.parseBest and { 0.3, 0.85, 0.35 } or { 0.5, 0.5, 0.5 })
        refs.parseBestCard:SetCaption(L("INTEL_PARSE_BEST_CAPTION", "single-pull peak"))
        refs.parseBestCard:SetAccent("success", { 0.3, 0.85, 0.35, 1 })
    end

    if refs.parseTrend and Loolib.Fonts and Loolib.Fonts.Icon then
        if intel.parseTrend == "up" then
            refs.parseTrend:SetText(Loolib.Fonts:Icon("arrow-up"))
            refs.parseTrend:SetTextColor(0.2, 0.93, 0.2)
            refs.parseTrend:Show()
        elseif intel.parseTrend == "down" then
            refs.parseTrend:SetText(Loolib.Fonts:Icon("arrow-down"))
            refs.parseTrend:SetTextColor(0.93, 0.2, 0.2)
            refs.parseTrend:Show()
        elseif intel.parseTrend == "stable" then
            refs.parseTrend:SetText(Loolib.Fonts:Icon("minus"))
            refs.parseTrend:SetTextColor(0.6, 0.6, 0.6)
            refs.parseTrend:Show()
        else
            refs.parseTrend:Hide()
        end
    end

    if refs.parseBossText then
        if intel.parseBestBoss then
            refs.parseBossText:SetText(format("|cffffcc66Best on|r  %s", intel.parseBestBoss))
        else
            refs.parseBossText:SetText("")
        end
    end

    if refs.parseEmpty  then refs.parseEmpty:SetShown(not hasAny) end
    if refs.parseAvgCard  then refs.parseAvgCard.frame:SetShown(hasAny) end
    if refs.parseBestCard then refs.parseBestCard.frame:SetShown(hasAny) end
    if refs.parseBossText then refs.parseBossText:SetShown(hasAny) end
    if refs.parseHintText then refs.parseHintText:SetShown(hasAny) end
end

--- Raid tab — attendance up top, gear panel below, progression footer.
local function BuildRaidTab(panel, refs)
    local gutter = 10

    -- Attendance strip (top)
    local attStrip = CreateStatCard(panel, { label = L("INTEL_ATTENDANCE", "Attendance") })
    attStrip.frame:SetHeight(76)
    attStrip.frame:ClearAllPoints()
    attStrip.frame:SetPoint("TOPLEFT", 0, 0)
    attStrip.frame:SetPoint("TOPRIGHT", 0, 0)
    attStrip.value:ClearAllPoints()
    attStrip.value:SetPoint("LEFT", 10, 4)
    refs.raidAttendCard = attStrip

    -- Gear readiness card. Height fits: label (14) + 8px top inset + four
    -- metric rows at 22px each (88) + progression row (16) + 12px bottom
    -- inset = 138 minimum; round up to 150 for breathing room.
    local gear = CreateFrame("Frame", nil, panel, "BackdropTemplate")
    gear:SetPoint("TOPLEFT", 0, -(76 + gutter))
    gear:SetPoint("TOPRIGHT", 0, -(76 + gutter))
    gear:SetHeight(150)
    if gear.SetBackdrop then
        gear:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Buttons\\WHITE8x8",
            tile = false, edgeSize = 1,
            insets = { left = 1, right = 1, top = 1, bottom = 1 },
        })
        gear:SetBackdropColor(unpack(skinColor("panelInset", { 0.04, 0.05, 0.07, 0.5 })))
        gear:SetBackdropBorderColor(unpack(skinColor("border", { 0.2, 0.2, 0.2, 1 })))
    end
    refs.raidGearPanel = gear

    local gearAccent = gear:CreateTexture(nil, "ARTWORK", nil, 2)
    gearAccent:SetPoint("TOPLEFT", 0, 0)
    gearAccent:SetPoint("BOTTOMLEFT", 0, 0)
    gearAccent:SetWidth(2)
    gearAccent:SetColorTexture(unpack(skinColor("accentWarm", { 0.93, 0.45, 0.25, 1 })))
    refs.raidGearAccent = gearAccent

    local gearLabel = gear:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    gearLabel:SetPoint("TOPLEFT", 10, -8)
    gearLabel:SetText(L("INTEL_GEAR_READINESS", "Gear readiness"))
    applyTextColor(gearLabel, "textSubtle", { 0.55, 0.58, 0.65 })

    -- Four metrics in a 4-row stack inside the gear card. Each row uses
    -- matching TOPLEFT + TOPRIGHT anchors + an explicit height so a long
    -- right-column value (e.g. "|cffa335ee(4-set)|r") can't stretch the
    -- FontString diagonally into the row above.
    local function makeGearRow(row)
        local fs = gear:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        fs:SetPoint("TOPLEFT", 10, -(28 + (row - 1) * 22))
        fs:SetPoint("TOPRIGHT", -10, -(28 + (row - 1) * 22))
        fs:SetHeight(18)
        fs:SetJustifyH("LEFT")
        fs:SetWordWrap(false)
        return fs
    end
    refs.raidTierText    = makeGearRow(1)
    refs.raidEnchText    = makeGearRow(2)
    refs.raidGemsText    = makeGearRow(3)
    refs.raidVaultText   = makeGearRow(4)

    -- Progression footer inside gear card. BOTTOMLEFT + BOTTOMRIGHT so
    -- the FontString stays flush with the card bottom; word wrap on to
    -- accommodate long progression strings ("3/8 Mythic · 8/8 Heroic").
    local prog = gear:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    prog:SetPoint("BOTTOMLEFT", 10, 10)
    prog:SetPoint("BOTTOMRIGHT", -10, 10)
    prog:SetHeight(14)
    prog:SetJustifyH("LEFT")
    prog:SetJustifyV("BOTTOM")
    prog:SetWordWrap(false)
    applyTextColor(prog, "accent", { 0.6, 0.85, 1 })
    refs.raidProgText = prog

    -- Empty state
    local empty = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    empty:SetPoint("CENTER")
    empty:SetText(L("INTEL_RAID_EMPTY", "No raid data recorded yet."))
    applyTextColor(empty, "textSubtle", { 0.5, 0.5, 0.5 })
    empty:Hide()
    refs.raidEmpty = empty
end

local function BindRaidTab(refs, intel)
    local hasAny = intel.eventAttendPct or intel.attendance or intel.raidCount
        or intel.tierCount or intel.enchMissing or intel.gemMissing
        or intel.vaultSlots or intel.raidProg

    if refs.raidAttendCard then
        local pct = intel.eventAttendPct or (intel.attendance and intel.attendance * 100)
        refs.raidAttendCard:SetValue(
            pct and format("%d%%", math.floor(pct + 0.5)) or "—",
            pct and "success" or "textSubtle",
            pct and { 0.3, 0.85, 0.35 } or { 0.5, 0.5, 0.5 })
        local bits = {}
        if intel.eventAttended and intel.eventEligible then
            bits[#bits + 1] = format("%d/%d events attended", intel.eventAttended, intel.eventEligible)
        end
        if intel.raidCount and intel.raidCount > 0 then
            local label = intel.raidCount == 1 and "raid date" or "raid dates"
            bits[#bits + 1] = format("%d %s", intel.raidCount, label)
        end
        refs.raidAttendCard:SetCaption(#bits > 0 and table.concat(bits, "  ·  ") or L("INTEL_NO_ATTENDANCE", "No records"))
        refs.raidAttendCard:SetAccent("success", { 0.3, 0.85, 0.35, 1 })
    end

    if refs.raidTierText then
        local parts = {}
        if intel.tierCount then
            local color = "|cffffffff"
            if intel.has4pc then color = "|cffa335ee"       -- epic
            elseif intel.has2pc then color = "|cff0070dd" end -- rare
            parts[#parts + 1] = color .. format("%dpc tier|r", intel.tierCount)
            if intel.has4pc then parts[#parts + 1] = "|cffa335ee(4-set)|r"
            elseif intel.has2pc then parts[#parts + 1] = "|cff0070dd(2-set)|r" end
        else
            parts[#parts + 1] = "|cff888888Tier: unknown|r"
        end
        refs.raidTierText:SetText("|cffbbbbbbTier:|r  " .. table.concat(parts, "  "))
    end

    if refs.raidEnchText then
        local t
        if intel.enchMissing == 0 then t = "|cff33ee33Fully enchanted|r"
        elseif intel.enchMissing and intel.enchMissing > 0 then
            t = format("|cffee3333%d missing enchants|r", intel.enchMissing)
        else t = "|cff888888unknown|r" end
        refs.raidEnchText:SetText("|cffbbbbbbEnchants:|r  " .. t)
    end

    if refs.raidGemsText then
        local t
        if intel.gemMissing == 0 then t = "|cff33ee33Fully gemmed|r"
        elseif intel.gemMissing and intel.gemMissing > 0 then
            t = format("|cffee3333%d missing gems|r", intel.gemMissing)
        else t = "|cff888888unknown|r" end
        refs.raidGemsText:SetText("|cffbbbbbbGems:|r  " .. t)
    end

    if refs.raidVaultText then
        local t
        if intel.vaultSlots then t = format("|cff66ccff%d/9 slots|r", intel.vaultSlots)
        else t = "|cff888888unknown|r" end
        refs.raidVaultText:SetText("|cffbbbbbbVault:|r  " .. t)
    end

    if refs.raidProgText then
        if intel.raidProg and intel.raidProg ~= "" then
            refs.raidProgText:SetText("|cffbbbbbbProgression:|r  " .. intel.raidProg)
        else
            refs.raidProgText:SetText("")
        end
    end

    if refs.raidEmpty     then refs.raidEmpty:SetShown(not hasAny) end
    if refs.raidAttendCard then refs.raidAttendCard.frame:SetShown(hasAny) end
    if refs.raidGearPanel  then refs.raidGearPanel:SetShown(hasAny) end
end

--- Loot tab — scroll list of recent loot + alt loot strip.
local function BuildLootTab(panel, refs)
    local mf = MF()
    if not mf or not mf.CreateScrollList then return end

    -- Alt loot header
    local altStrip = CreateFrame("Frame", nil, panel, "BackdropTemplate")
    altStrip:SetPoint("TOPLEFT", 0, 0)
    altStrip:SetPoint("TOPRIGHT", 0, 0)
    altStrip:SetHeight(38)
    if altStrip.SetBackdrop then
        altStrip:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Buttons\\WHITE8x8",
            tile = false, edgeSize = 1,
            insets = { left = 1, right = 1, top = 1, bottom = 1 },
        })
        altStrip:SetBackdropColor(unpack(skinColor("panelInset", { 0.04, 0.05, 0.07, 0.5 })))
        altStrip:SetBackdropBorderColor(unpack(skinColor("border", { 0.2, 0.2, 0.2, 1 })))
    end
    refs.lootAltStrip = altStrip

    local altAccent = altStrip:CreateTexture(nil, "ARTWORK", nil, 2)
    altAccent:SetPoint("TOPLEFT", 0, 0)
    altAccent:SetPoint("BOTTOMLEFT", 0, 0)
    altAccent:SetWidth(2)
    altAccent:SetColorTexture(unpack(skinColor("accentCool", { 0.35, 0.55, 0.9, 1 })))
    refs.lootAltAccent = altAccent

    local altText = altStrip:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    altText:SetPoint("LEFT", 10, 0)
    altText:SetPoint("RIGHT", -8, 0)
    altText:SetJustifyH("LEFT")
    altText:SetWordWrap(false)
    applyTextColor(altText, "text", { 1, 1, 1 })
    refs.lootAltText = altText

    -- Loot scroll list
    local list = mf.CreateScrollList(panel, {
        rowHeight = LOOT_ROW_HEIGHT,
        emptyMessage = L("INTEL_LOOT_EMPTY", "No loot received this tier."),
        initRow = function(row)
            row:SetBackdrop({
                bgFile = "Interface\\Buttons\\WHITE8x8",
                edgeFile = "Interface\\Buttons\\WHITE8x8",
                tile = false, edgeSize = 1,
                insets = { left = 1, right = 1, top = 1, bottom = 1 },
            })
            row:SetBackdropColor(unpack(skinColor("rowAlt", { 0.06, 0.07, 0.1, 0.5 })))
            row:SetBackdropBorderColor(unpack(skinColor("border", { 0.15, 0.15, 0.15, 0.5 })))

            if mf.AddRowHoverAccent then mf.AddRowHoverAccent(row) end

            row.dateFS = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            row.dateFS:SetPoint("LEFT", 10, 0)
            row.dateFS:SetWidth(72)
            row.dateFS:SetJustifyH("LEFT")

            row.itemFS = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            row.itemFS:SetPoint("LEFT", row.dateFS, "RIGHT", 6, 0)
            row.itemFS:SetWidth(220)
            row.itemFS:SetJustifyH("LEFT")
            row.itemFS:SetWordWrap(false)

            row.respFS = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            row.respFS:SetPoint("LEFT", row.itemFS, "RIGHT", 6, 0)
            row.respFS:SetPoint("RIGHT", -10, 0)
            row.respFS:SetJustifyH("RIGHT")
            row.respFS:SetWordWrap(false)
        end,
        bindRow = function(row, data)
            -- Date: compact "Apr 07"
            local dateStr = data.date or "?"
            local _, m, d = dateStr:match("(%d+)-(%d+)-(%d+)")
            if m and d then
                local months = { "Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec" }
                local mi = tonumber(m)
                dateStr = (months[mi] or m) .. " " .. d
            end
            row.dateFS:SetText(dateStr)
            applyTextColor(row.dateFS, "textMuted", { 0.7, 0.72, 0.76 })

            -- Item name + optional boss/difficulty suffix
            local line = data.name or "?"
            if data.diff or data.boss then
                local tail = {}
                if data.boss then tail[#tail + 1] = data.boss end
                if data.diff then tail[#tail + 1] = data.diff end
                line = line .. "  |cff666666(" .. table.concat(tail, ", ") .. ")|r"
            end
            row.itemFS:SetText(line)
            applyTextColor(row.itemFS, "text", { 1, 1, 1 })

            -- Response pill (colored if ResponseInfo has it)
            local resp = data.resp or "?"
            row.respFS:SetText(resp)
            applyTextColor(row.respFS, "textSubtle", { 0.6, 0.65, 0.7 })
        end,
    })
    list.container:SetPoint("TOPLEFT", 0, -48)
    list.container:SetPoint("BOTTOMRIGHT", 0, 0)
    refs.lootList = list
end

local function BindLootTab(refs, intel)
    -- Alt loot header
    if refs.lootAltStrip and refs.lootAltText then
        if intel.altLoot and #intel.altLoot > 0 then
            local parts = {}
            for _, alt in ipairs(intel.altLoot) do
                local altShort = shortName(alt.alt or "?")
                parts[#parts + 1] = format("|cffffffff%s|r (%s) %d items",
                    altShort, alt.cls or "?", alt.count or 0)
            end
            refs.lootAltText:SetText("|cff66ccffAlts:|r  " .. table.concat(parts, "  ·  "))
            refs.lootAltStrip:Show()
        else
            refs.lootAltStrip:Hide()
        end
    end

    -- Re-anchor list based on whether the alt strip is showing
    if refs.lootList then
        refs.lootList.container:ClearAllPoints()
        if refs.lootAltStrip and refs.lootAltStrip:IsShown() then
            refs.lootList.container:SetPoint("TOPLEFT", 0, -48)
        else
            refs.lootList.container:SetPoint("TOPLEFT", 0, 0)
        end
        refs.lootList.container:SetPoint("BOTTOMRIGHT", 0, 0)
        refs.lootList:Refresh(intel.loot)
    end
end

--[[--------------------------------------------------------------------
    Sims tab — item-contextual projections

    Shows Bloodmallet trinket-sim DPS gain + Raidbots Droptimizer upgrade
    for the item the modal was opened against. When the modal is opened
    without an item (context-menu / roster path), shows a friendly empty
    state pointing users at the council voting table as the entry point.
----------------------------------------------------------------------]]

local function BuildSimsTab(panel, refs)
    -- Item header: icon + name (filled in at Bind time).
    local itemHeader = CreateFrame("Frame", nil, panel, "BackdropTemplate")
    itemHeader:SetPoint("TOPLEFT", 0, 0)
    itemHeader:SetPoint("TOPRIGHT", 0, 0)
    itemHeader:SetHeight(44)
    if itemHeader.SetBackdrop then
        itemHeader:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Buttons\\WHITE8x8",
            tile = false, edgeSize = 1,
            insets = { left = 1, right = 1, top = 1, bottom = 1 },
        })
        itemHeader:SetBackdropColor(unpack(skinColor("panelInset", { 0.04, 0.05, 0.07, 0.5 })))
        itemHeader:SetBackdropBorderColor(unpack(skinColor("border", { 0.2, 0.2, 0.2, 1 })))
    end
    refs.simsItemHeader = itemHeader

    local itemAccent = itemHeader:CreateTexture(nil, "ARTWORK", nil, 2)
    itemAccent:SetPoint("TOPLEFT", 0, 0)
    itemAccent:SetPoint("BOTTOMLEFT", 0, 0)
    itemAccent:SetWidth(2)
    itemAccent:SetColorTexture(unpack(skinColor("accent", { 1, 0.82, 0, 1 })))
    refs.simsItemAccent = itemAccent

    local itemIcon = itemHeader:CreateTexture(nil, "ARTWORK")
    itemIcon:SetSize(32, 32)
    itemIcon:SetPoint("LEFT", 10, 0)
    itemIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    itemIcon:Hide()
    refs.simsItemIcon = itemIcon

    local itemName = itemHeader:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    itemName:SetPoint("LEFT", itemIcon, "RIGHT", 8, 4)
    itemName:SetPoint("RIGHT", itemHeader, "RIGHT", -8, 0)
    itemName:SetJustifyH("LEFT")
    itemName:SetWordWrap(false)
    refs.simsItemName = itemName

    local itemSub = itemHeader:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    itemSub:SetPoint("LEFT", itemIcon, "RIGHT", 8, -8)
    itemSub:SetPoint("RIGHT", itemHeader, "RIGHT", -8, 0)
    itemSub:SetJustifyH("LEFT")
    itemSub:SetWordWrap(false)
    applyTextColor(itemSub, "textMuted", { 0.7, 0.72, 0.76 })
    refs.simsItemSub = itemSub

    -- Two hero cards side-by-side: Trinket Sim + Droptimizer.
    local gutter = 10
    local colWidth = (INTEL_WIDTH - 20 - gutter) / 2

    local trinket = CreateStatCard(panel, { label = L("INTEL_SIMS_TRINKET", "Bloodmallet") })
    trinket.frame:SetWidth(colWidth)
    trinket.frame:SetHeight(92)
    trinket.frame:ClearAllPoints()
    trinket.frame:SetPoint("TOPLEFT", itemHeader, "BOTTOMLEFT", 0, -10)
    trinket.value:ClearAllPoints()
    trinket.value:SetPoint("TOPLEFT", trinket.label, "BOTTOMLEFT", 0, -2)
    trinket.value:SetPoint("BOTTOMLEFT", trinket.frame, "BOTTOMLEFT", 10, 24)
    trinket.value:SetPoint("RIGHT", trinket.frame, "RIGHT", -8, 0)
    -- Sim text strings carry multiple color-escape segments and wrap to
    -- two lines; swap the default Huge font for the regular body font
    -- and enable wrap so the 2T/3T/5T breakdown stays readable.
    trinket.value:SetFontObject("GameFontNormal")
    trinket.value:SetJustifyV("TOP")
    trinket.value:SetWordWrap(true)
    refs.simsTrinketCard = trinket

    local dropt = CreateStatCard(panel, { label = L("INTEL_SIMS_DROPT", "Droptimizer") })
    dropt.frame:SetWidth(colWidth)
    dropt.frame:SetHeight(92)
    dropt.frame:ClearAllPoints()
    dropt.frame:SetPoint("TOPLEFT", itemHeader, "BOTTOMLEFT", colWidth + gutter, -10)
    dropt.value:ClearAllPoints()
    dropt.value:SetPoint("TOPLEFT", dropt.label, "BOTTOMLEFT", 0, -2)
    dropt.value:SetPoint("BOTTOMLEFT", dropt.frame, "BOTTOMLEFT", 10, 24)
    dropt.value:SetPoint("RIGHT", dropt.frame, "RIGHT", -8, 0)
    dropt.value:SetFontObject("GameFontNormal")
    dropt.value:SetJustifyV("TOP")
    dropt.value:SetWordWrap(true)
    refs.simsDroptCard = dropt

    -- Wishlist-for-this-item strip below the sim cards.
    local wishStrip = CreateFrame("Frame", nil, panel, "BackdropTemplate")
    wishStrip:SetPoint("TOPLEFT", trinket.frame, "BOTTOMLEFT", 0, -8)
    wishStrip:SetPoint("TOPRIGHT", dropt.frame, "BOTTOMRIGHT", 0, -8)
    wishStrip:SetHeight(40)
    if wishStrip.SetBackdrop then
        wishStrip:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Buttons\\WHITE8x8",
            tile = false, edgeSize = 1,
            insets = { left = 1, right = 1, top = 1, bottom = 1 },
        })
        wishStrip:SetBackdropColor(unpack(skinColor("panelInset", { 0.04, 0.05, 0.07, 0.5 })))
        wishStrip:SetBackdropBorderColor(unpack(skinColor("border", { 0.2, 0.2, 0.2, 1 })))
    end
    refs.simsWishStrip = wishStrip

    local wishAccent = wishStrip:CreateTexture(nil, "ARTWORK", nil, 2)
    wishAccent:SetPoint("TOPLEFT", 0, 0)
    wishAccent:SetPoint("BOTTOMLEFT", 0, 0)
    wishAccent:SetWidth(2)
    wishAccent:SetColorTexture(unpack(skinColor("accentCool", { 0.35, 0.55, 0.9, 1 })))
    refs.simsWishAccent = wishAccent

    local wishText = wishStrip:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    wishText:SetPoint("LEFT", 10, 0)
    wishText:SetPoint("RIGHT", -8, 0)
    wishText:SetJustifyH("LEFT")
    wishText:SetWordWrap(false)
    applyTextColor(wishText, "text", { 1, 1, 1 })
    refs.simsWishText = wishText

    -- Footer hint line (always visible, bottom of panel).
    local hint = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    hint:SetPoint("BOTTOMLEFT", 0, 4)
    hint:SetPoint("BOTTOMRIGHT", 0, 4)
    hint:SetJustifyH("LEFT")
    hint:SetWordWrap(true)
    hint:SetText(L("INTEL_SIMS_HINT",
        "Bloodmallet projections are keyed by spec; Droptimizer is a Raidbots SimulationCraft run. Both come from your desktop app's nightly sync."))
    applyTextColor(hint, "textSubtle", { 0.5, 0.55, 0.6 })
    refs.simsHintText = hint

    -- Empty state (shown when no item context was passed — e.g. opened
    -- from the context menu outside an active vote).
    local empty = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    empty:SetPoint("CENTER")
    empty:SetWidth(INTEL_WIDTH - 80)
    empty:SetJustifyH("CENTER")
    empty:SetWordWrap(true)
    empty:SetText(L("INTEL_SIMS_EMPTY", "Open the intel modal from the council voting table to see sim results for the current item."))
    applyTextColor(empty, "textSubtle", { 0.5, 0.55, 0.6 })
    empty:Hide()
    refs.simsEmpty = empty
end

--- Resolve the candidate's spec from PlayerCache / intel / live info.
--- PlayerCache is preferred because it's populated from WoW's live inspect
--- flow and matches the display-name format TrinketSims.SPEC_SLUGS keys
--- on ("Devourer", "Beast Mastery", …). intel.spec carries the same
--- format when the desktop app is current. Live-fallback only applies to
--- the local player.
local function resolveSpec(intel, playerName)
    if Loothing.PlayerCache and Loothing.PlayerCache.Get then
        local cached = Loothing.PlayerCache:Get(playerName)
        if cached and cached.spec then return cached.spec end
    end
    if intel and intel.spec then return intel.spec end
    if Utils and Utils.IsSamePlayer and Utils.GetPlayerFullName
        and Utils.IsSamePlayer(playerName, Utils.GetPlayerFullName()) then
        local getSpec = C_SpecializationInfo and C_SpecializationInfo.GetSpecialization or GetSpecialization
        local specIndex = getSpec and getSpec()
        if specIndex then
            local getInfo = C_SpecializationInfo and C_SpecializationInfo.GetSpecializationInfo
                or GetSpecializationInfo
            if getInfo then
                local _, specName = getInfo(specIndex)
                return specName
            end
        end
    end
    return nil
end

--- Resolve the candidate's class from PlayerCache / intel / Roster.
--- PlayerCache is preferred because it stores the Blizzard class token
--- ("DEMONHUNTER") that TrinketSims.CLASS_SLUGS expects. intel.class and
--- Roster.cls come from the desktop app and may ship as display names
--- ("Demon Hunter") or bloodmallet slugs ("demon_hunter"); we take them
--- only as a fallback, and the Sims-tab miss caption surfaces whatever
--- was resolved so malformed class strings are visible instead of
--- silently failing BuildSlug.
local function resolveClass(intel, playerName)
    if Loothing.PlayerCache and Loothing.PlayerCache.Get then
        local cached = Loothing.PlayerCache:Get(playerName)
        if cached and cached.class then return cached.class end
    end
    if intel and intel.class then return intel.class end
    if Loothing.Roster and Loothing.Roster.GetMember then
        local member = Loothing.Roster:GetMember(playerName)
        if member and member.cls then return member.cls end
    end
    return nil
end

local function BindSimsTab(refs, intel, playerName, itemCtx)
    local hasItem = itemCtx and itemCtx.itemID

    -- Toggle empty state
    local showEmpty = not hasItem
    if refs.simsEmpty       then refs.simsEmpty:SetShown(showEmpty) end
    if refs.simsItemHeader  then refs.simsItemHeader:SetShown(not showEmpty) end
    if refs.simsTrinketCard then refs.simsTrinketCard.frame:SetShown(not showEmpty) end
    if refs.simsDroptCard   then refs.simsDroptCard.frame:SetShown(not showEmpty) end
    if refs.simsWishStrip   then refs.simsWishStrip:SetShown(not showEmpty) end
    if refs.simsHintText    then refs.simsHintText:SetShown(not showEmpty) end
    if not hasItem then return end

    -- Item header
    if refs.simsItemName and refs.simsItemSub and refs.simsItemIcon then
        local itemID, itemLink = itemCtx.itemID, itemCtx.itemLink
        local name, link, quality, iLevel = itemCtx.itemName, itemLink, nil, itemCtx.itemLevel
        if C_Item and C_Item.GetItemInfo then
            local gotName, gotLink, gotQ, gotLvl = C_Item.GetItemInfo(itemLink or itemID)
            name    = gotName or name
            link    = gotLink or link
            quality = gotQ    or quality
            iLevel  = gotLvl  or iLevel
        end
        -- Colored item name (quality tint via Blizzard's escape if quality known)
        if link then
            refs.simsItemName:SetText(link)
        else
            refs.simsItemName:SetText(name or ("item:" .. tostring(itemID)))
        end

        -- Icon
        local icon
        if C_Item and C_Item.GetItemIconByID then
            icon = C_Item.GetItemIconByID(itemID)
        elseif GetItemIcon then
            icon = GetItemIcon(itemLink or itemID)
        end
        if icon then
            refs.simsItemIcon:SetTexture(icon)
            refs.simsItemIcon:Show()
        else
            refs.simsItemIcon:Hide()
        end

        -- Sub-line: item level + slot
        local subBits = {}
        if iLevel and iLevel > 0 then subBits[#subBits + 1] = format("ilvl %d", iLevel) end
        if itemCtx.equipSlot and itemCtx.equipSlot ~= "" then
            subBits[#subBits + 1] = _G[itemCtx.equipSlot] or itemCtx.equipSlot
        end
        refs.simsItemSub:SetText(#subBits > 0 and table.concat(subBits, "  ·  ") or "")
    end

    -- Prefer class/spec passed explicitly from the council table — they
    -- come straight from the voting session layer where they're already
    -- resolved to the Blizzard class token (DEMONHUNTER / PALADIN / …)
    -- that TrinketSims expects. The resolve* helpers are a fallback for
    -- callers that don't have that context (context-menu outside a vote).
    local candidateClass = itemCtx.candidateClass or resolveClass(intel, playerName)
    local candidateSpec  = itemCtx.candidateSpec  or resolveSpec(intel, playerName)

    -- Trinket sim card
    if refs.simsTrinketCard then
        local simText = nil
        local specLabel = nil
        if Loothing.TrinketSims and Loothing.TrinketSims:HasData()
            and candidateClass and candidateSpec
        then
            simText = Loothing.TrinketSims:GetSimText(itemCtx.itemID, candidateClass, candidateSpec)
            if simText and Loothing.TrinketSims.GetColoredSpecLabel then
                specLabel = Loothing.TrinketSims:GetColoredSpecLabel(candidateClass, candidateSpec)
            end
        end
        if simText then
            refs.simsTrinketCard:SetValue(simText, "accentCool", { 0.6, 0.9, 1.0 })
            refs.simsTrinketCard:SetCaption(specLabel or (candidateSpec or "—"),
                "textMuted", { 0.7, 0.72, 0.76 })
            refs.simsTrinketCard:SetAccent("accentCool", { 0.35, 0.55, 0.9, 1 })
        else
            refs.simsTrinketCard:SetValue("—", "textSubtle", { 0.5, 0.5, 0.5 })
            local reason
            if not Loothing.TrinketSims or not Loothing.TrinketSims:HasData() then
                reason = L("INTEL_SIMS_TRINKET_NO_DATA", "No sim data loaded")
            elseif not candidateClass or not candidateSpec then
                reason = L("INTEL_SIMS_TRINKET_NO_SPEC", "Spec unknown")
            else
                -- Append the resolved class/spec so a miss on a player
                -- whose class resolved to the wrong form (display name
                -- instead of token, or a garbled roster slug) is visible
                -- to the council member rather than failing silently.
                reason = format("%s  |cff888888(%s / %s)|r",
                    L("INTEL_SIMS_TRINKET_MISS", "Not in the simmed set"),
                    tostring(candidateClass), tostring(candidateSpec))
            end
            refs.simsTrinketCard:SetCaption(reason, "textSubtle", { 0.5, 0.55, 0.6 })
            refs.simsTrinketCard:SetAccent("border", { 0.3, 0.3, 0.3, 1 })
        end
    end

    -- Droptimizer card
    if refs.simsDroptCard then
        local upgrade, stale = nil, false
        if Loothing.Droptimizer and Loothing.Droptimizer:HasData() and playerName then
            upgrade = Loothing.Droptimizer:GetUpgradeText(playerName, itemCtx.itemID)
            if upgrade and Loothing.Droptimizer.IsCharStale then
                stale = Loothing.Droptimizer:IsCharStale(playerName)
            end
        end
        if upgrade then
            refs.simsDroptCard:SetValue(upgrade, "success", { 0.3, 0.9, 0.3 })
            local cap = L("INTEL_SIMS_DROPT_SRC", "raidbots.com")
            if stale then cap = cap .. "  |cffFF6600[stale]|r" end
            refs.simsDroptCard:SetCaption(cap, "textMuted", { 0.7, 0.72, 0.76 })
            refs.simsDroptCard:SetAccent("success", { 0.3, 0.85, 0.35, 1 })
        else
            refs.simsDroptCard:SetValue("—", "textSubtle", { 0.5, 0.5, 0.5 })
            local reason
            if not Loothing.Droptimizer or not Loothing.Droptimizer:HasData() then
                reason = L("INTEL_SIMS_DROPT_NO_DATA", "No droptimizer data loaded")
            else
                reason = L("INTEL_SIMS_DROPT_MISS", "Not in the sim report")
            end
            refs.simsDroptCard:SetCaption(reason, "textSubtle", { 0.5, 0.55, 0.6 })
            refs.simsDroptCard:SetAccent("border", { 0.3, 0.3, 0.3, 1 })
        end
    end

    -- Wishlist strip for THIS item
    if refs.simsWishText then
        local entry
        if Loothing.Wishlist and Loothing.Wishlist.GetPlayerEntryForItem then
            entry = Loothing.Wishlist:GetPlayerEntryForItem(itemCtx.itemID, playerName)
        end
        if entry then
            local bits = {}
            if entry.priority and entry.priority > 0 then
                bits[#bits + 1] = format("|cffffcc66Priority %s|r", tostring(entry.priority))
            end
            if entry.isBiS then
                bits[#bits + 1] = "|cffa335eeBiS|r"
            elseif entry.isOffspec then
                bits[#bits + 1] = "|cff888888Off-spec|r"
            elseif entry.needLevel then
                bits[#bits + 1] = "|cff33ee33" .. tostring(entry.needLevel) .. "|r"
            end
            if entry.notes and entry.notes ~= "" then
                bits[#bits + 1] = "|cffbbbbbb" .. entry.notes .. "|r"
            end
            refs.simsWishText:SetText(L("INTEL_SIMS_WISH_PREFIX", "On wishlist:") .. "  " .. table.concat(bits, "  ·  "))
        else
            refs.simsWishText:SetText(L("INTEL_SIMS_WISH_NONE", "Not on wishlist."))
        end
    end
end

--[[--------------------------------------------------------------------
    Wishlist tab — player's full wishlist

    Character header (list name + filled/total) + scrollable list of every
    item they've wishlisted, sorted by priority (1 = highest). Each row
    shows item icon, item name (with quality color + tooltip on hover),
    priority, BiS / Off-spec / need-level badge, and optional notes.
----------------------------------------------------------------------]]

local function BuildWishlistTab(panel, refs)
    local mf = MF()
    if not mf or not mf.CreateScrollList then return end

    -- Header strip
    local headerStrip = CreateFrame("Frame", nil, panel, "BackdropTemplate")
    headerStrip:SetPoint("TOPLEFT", 0, 0)
    headerStrip:SetPoint("TOPRIGHT", 0, 0)
    headerStrip:SetHeight(38)
    if headerStrip.SetBackdrop then
        headerStrip:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Buttons\\WHITE8x8",
            tile = false, edgeSize = 1,
            insets = { left = 1, right = 1, top = 1, bottom = 1 },
        })
        headerStrip:SetBackdropColor(unpack(skinColor("panelInset", { 0.04, 0.05, 0.07, 0.5 })))
        headerStrip:SetBackdropBorderColor(unpack(skinColor("border", { 0.2, 0.2, 0.2, 1 })))
    end
    refs.wishHeaderStrip = headerStrip

    local headerAccent = headerStrip:CreateTexture(nil, "ARTWORK", nil, 2)
    headerAccent:SetPoint("TOPLEFT", 0, 0)
    headerAccent:SetPoint("BOTTOMLEFT", 0, 0)
    headerAccent:SetWidth(2)
    headerAccent:SetColorTexture(unpack(skinColor("accent", { 1, 0.82, 0, 1 })))
    refs.wishHeaderAccent = headerAccent

    local headerText = headerStrip:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    headerText:SetPoint("LEFT", 10, 0)
    headerText:SetPoint("RIGHT", -8, 0)
    headerText:SetJustifyH("LEFT")
    headerText:SetWordWrap(false)
    applyTextColor(headerText, "text", { 1, 1, 1 })
    refs.wishHeaderText = headerText

    -- Scroll list
    local list = mf.CreateScrollList(panel, {
        rowHeight = WISH_ROW_HEIGHT,
        emptyMessage = L("INTEL_WISH_EMPTY", "No wishlist entries for this player."),
        initRow = function(row)
            row:SetBackdrop({
                bgFile = "Interface\\Buttons\\WHITE8x8",
                edgeFile = "Interface\\Buttons\\WHITE8x8",
                tile = false, edgeSize = 1,
                insets = { left = 1, right = 1, top = 1, bottom = 1 },
            })
            row:SetBackdropColor(unpack(skinColor("rowAlt", { 0.06, 0.07, 0.1, 0.5 })))
            row:SetBackdropBorderColor(unpack(skinColor("border", { 0.15, 0.15, 0.15, 0.5 })))

            if mf.AddRowHoverAccent then mf.AddRowHoverAccent(row) end

            -- Item icon
            row.icon = row:CreateTexture(nil, "ARTWORK")
            row.icon:SetSize(22, 22)
            row.icon:SetPoint("LEFT", 8, 0)
            row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

            -- Priority badge
            row.prio = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            row.prio:SetPoint("LEFT", row.icon, "RIGHT", 6, 0)
            row.prio:SetWidth(28)
            row.prio:SetJustifyH("CENTER")

            -- Item name
            row.nameFS = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            row.nameFS:SetPoint("LEFT", row.prio, "RIGHT", 6, 0)
            row.nameFS:SetWidth(340)
            row.nameFS:SetJustifyH("LEFT")
            row.nameFS:SetWordWrap(false)

            -- Badge (BiS / Offspec / need level)
            row.badgeFS = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            row.badgeFS:SetPoint("LEFT", row.nameFS, "RIGHT", 6, 0)
            row.badgeFS:SetPoint("RIGHT", -10, 0)
            row.badgeFS:SetJustifyH("RIGHT")
            row.badgeFS:SetWordWrap(false)

            -- Tooltip on hover of the whole row — shift-gated, strata-aware.
            -- Malformed desktop payloads have shipped non-string `notes` in
            -- the past (arrays, numbers); the type-guard prevents a
            -- GameTooltip concat crash.
            ns.AttachShiftTooltip(row, function(tt, self)
                if not self._itemLink then return false end
                tt:SetHyperlink(self._itemLink)
                if type(self._notes) == "string" and self._notes ~= "" then
                    tt:AddLine(" ")
                    tt:AddLine("|cffbbbbbbNote:|r " .. self._notes, 1, 1, 1, true)
                end
            end)
        end,
        bindRow = function(row, data)
            local details = Loothing.Wishlist
                and Loothing.Wishlist.GetItemDetails
                and Loothing.Wishlist:GetItemDetails(data.itemID)
            local itemName, itemLink, itemIcon, quality
            if C_Item and C_Item.GetItemInfo then
                local gotName, gotLink, gotQ = C_Item.GetItemInfo(data.itemID)
                itemName = gotName
                itemLink = gotLink
                quality  = gotQ
            end
            itemName = itemName or (details and details.name) or ("item:" .. tostring(data.itemID))
            if C_Item and C_Item.GetItemIconByID then
                itemIcon = C_Item.GetItemIconByID(data.itemID)
            end

            row.icon:SetTexture(itemIcon or 134400)

            -- Priority 1 is brightest, fades as number grows.
            local p = data.priority or 0
            local prioColor = "|cffffcc66"
            if p == 1 then prioColor = "|cffffd100"
            elseif p == 2 then prioColor = "|cffffcc66"
            elseif p >= 3 and p <= 5 then prioColor = "|cffbbbbbb"
            elseif p > 5 then prioColor = "|cff888888" end
            row.prio:SetText(p > 0 and (prioColor .. tostring(p) .. "|r") or "|cff555555—|r")

            -- Item name colored by quality. Blizzard's C_Item.GetItemInfo
            -- returns a number (Enum.ItemQuality), but the desktop app
            -- writes Wishlist details.quality as a Blizzard string name
            -- ("Epic", "Rare", …). GetItemQualityColor requires the int
            -- and crashes on strings, so we map the common name forms
            -- before calling it. Unknown strings fall through to white.
            local q = quality or (details and details.quality)
            if type(q) == "string" then
                q = QUALITY_NAME_TO_INT[q:lower()]
            end
            local r, g, b = 1, 1, 1
            if type(q) == "number" and C_Item and C_Item.GetItemQualityColor then
                local rr, gg, bb = C_Item.GetItemQualityColor(q)
                -- API can return nothing for out-of-range quality; keep the white fallback.
                if rr then r, g, b = rr, gg or 1, bb or 1 end
            end
            row.nameFS:SetText(format("|cff%02x%02x%02x%s|r",
                math.floor(r * 255 + 0.5),
                math.floor(g * 255 + 0.5),
                math.floor(b * 255 + 0.5),
                itemName))

            -- Badge
            if data.isBiS then
                row.badgeFS:SetText("|cffa335eeBiS|r")
            elseif data.isOffspec then
                row.badgeFS:SetText("|cff888888Off-spec|r")
            elseif data.needLevel then
                row.badgeFS:SetText("|cff33ee33" .. tostring(data.needLevel) .. "|r")
            elseif type(data.notes) == "string" and data.notes ~= "" then
                -- Show a note glyph (no space for the full note inline).
                row.badgeFS:SetText("|cffbbbbbb\226\128\166|r")  -- ellipsis …
            else
                row.badgeFS:SetText("")
            end

            row._itemLink = itemLink
            row._notes = data.notes
        end,
    })
    list.container:SetPoint("TOPLEFT", 0, -48)
    list.container:SetPoint("BOTTOMRIGHT", 0, 0)
    refs.wishList = list
end

local function BindWishlistTab(refs, intel, playerName)
    local info = Loothing.Wishlist and Loothing.Wishlist.GetCharacterInfo
        and Loothing.Wishlist:GetCharacterInfo(playerName)

    if refs.wishHeaderText then
        if info then
            local title = info.listName or L("INTEL_WISH_DEFAULT_LIST", "Wishlist")
            local bits = {}
            if info.totalItems and info.fulfilledItems then
                bits[#bits + 1] = format("%d/%d filled", info.fulfilledItems, info.totalItems)
            elseif info.totalItems then
                bits[#bits + 1] = format("%d items", info.totalItems)
            end
            refs.wishHeaderText:SetText(#bits > 0
                and format("|cffffcc66%s|r  ·  %s", title, table.concat(bits, "  ·  "))
                or ("|cffffcc66" .. title .. "|r"))
            refs.wishHeaderStrip:Show()
        else
            refs.wishHeaderStrip:Hide()
        end
    end

    if refs.wishList then
        refs.wishList.container:ClearAllPoints()
        if refs.wishHeaderStrip and refs.wishHeaderStrip:IsShown() then
            refs.wishList.container:SetPoint("TOPLEFT", 0, -48)
        else
            refs.wishList.container:SetPoint("TOPLEFT", 0, 0)
        end
        refs.wishList.container:SetPoint("BOTTOMRIGHT", 0, 0)

        local items
        if Loothing.Wishlist and Loothing.Wishlist.GetItemsForPlayer then
            items = Loothing.Wishlist:GetItemsForPlayer(playerName)
        end
        refs.wishList:Refresh(items or {})
    end
end

--[[--------------------------------------------------------------------
    Modal factory (singleton)
----------------------------------------------------------------------]]

local function getPlayerIntelInstance()
    if intelInstance then return intelInstance end

    local mf = MF()
    if not mf or not mf.CreateModal then
        if Loothing.Error then
            Loothing:Error("PlayerIntelFrame: ns.ModalFactory unavailable")
        end
        return nil
    end

    -- Non-resizable: every tab lays out cards at fixed pixel widths derived
    -- from INTEL_WIDTH, and reflowing on user resize would require hooking
    -- OnSizeChanged on each panel. Factory omits the resize grip entirely
    -- when resizable=false.
    local modal = mf.CreateModal("LoothingPlayerIntelFrame",
        INTEL_WIDTH, INTEL_HEIGHT,
        L("INTEL_TITLE", "Player Intel"),
        {
            headerHeight = HEADER_HEIGHT,
            footerHeight = FOOTER_HEIGHT,
            resizable    = false,
        })

    -- ================== Header widgets ==================
    -- Replace the default subtitle with a composite header:
    --   name (class-colored)  [role] [spec]  ilvl
    modal.subtitle:Hide()

    local nameText = modal.frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    nameText:SetPoint("TOPLEFT", 14, -32)
    nameText:SetJustifyH("LEFT")
    modal.nameText = nameText

    local badgesText = modal.frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    badgesText:SetPoint("TOPLEFT", nameText, "TOPRIGHT", 8, -2)
    applyTextColor(badgesText, "textMuted", { 0.6, 0.62, 0.68 })
    modal.badgesText = badgesText

    local ilvlText = modal.frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    ilvlText:SetPoint("TOPRIGHT", -32, -32)
    ilvlText:SetJustifyH("RIGHT")
    applyTextColor(ilvlText, "accent", { 1, 0.82, 0 })
    modal.ilvlText = ilvlText

    -- ================== Tab strip ==================
    -- 7 tabs fit a 640-wide modal at 84px each with 3px gutters
    -- (7*84 + 6*3 = 606px, leaves ~20px of slack inside the 620 body).
    local tabDefs = {
        { id = "overview", text = L("INTEL_TAB_OVERVIEW", "Overview") },
        { id = "mplus",    text = L("INTEL_TAB_MPLUS",    "M+")       },
        { id = "parses",   text = L("INTEL_TAB_PARSES",   "Parses")   },
        { id = "raid",     text = L("INTEL_TAB_RAID",     "Raid")     },
        { id = "loot",     text = L("INTEL_TAB_LOOT",     "Loot")     },
        { id = "sims",     text = L("INTEL_TAB_SIMS",     "Sims")     },
        { id = "wishlist", text = L("INTEL_TAB_WISHLIST", "Wishlist") },
    }

    local panels = {}
    local tabStrip = mf.CreateTabStrip(modal.content, tabDefs,
        function(tabId, _prevId)
            -- Always fully reset panel visibility (not just prev→target
            -- toggle) so any panel that was Shown by a previous code
            -- path — close-then-reopen, interrupted SelectTab during
            -- live-refresh, OnHideCleanup racing with Show — can never
            -- render on top of the target tab's content.
            for id, panel in pairs(panels) do
                if id == tabId then panel:Show() else panel:Hide() end
            end
        end, { tabWidth = 84, spacing = 3 })

    -- Wrap tabStrip container into the content area
    tabStrip.container:SetPoint("TOPLEFT", modal.content, "TOPLEFT", 0, 0)
    tabStrip.container:SetPoint("TOPRIGHT", modal.content, "TOPRIGHT", 0, 0)

    modal.tabStrip = tabStrip

    -- Body area under the tabs (where each tab panel lives). The bottom
    -- is inset 4px so tab panels (which fill with TOPLEFT/BOTTOMRIGHT 0,0)
    -- can't clip their last rows into the footer strip below.
    local body = CreateFrame("Frame", nil, modal.content)
    body:SetPoint("TOPLEFT", tabStrip.container, "BOTTOMLEFT", 0, -10)
    body:SetPoint("BOTTOMRIGHT", modal.content, "BOTTOMRIGHT", 0, 4)
    modal.body = body

    -- Build each tab panel (parented to body)
    local refs = {}
    modal.refs = refs
    for _, def in ipairs(tabDefs) do
        panels[def.id] = CreateTabPanel(body)
    end
    BuildOverviewTab(panels.overview, refs)
    BuildMPlusTab(panels.mplus, refs)
    BuildParsesTab(panels.parses, refs)
    BuildRaidTab(panels.raid, refs)
    BuildLootTab(panels.loot, refs)
    BuildSimsTab(panels.sims, refs)
    BuildWishlistTab(panels.wishlist, refs)
    modal.panels = panels

    -- ================== Footer ==================
    local stalenessText = modal.footer:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    stalenessText:SetPoint("LEFT", 0, 0)
    stalenessText:SetJustifyH("LEFT")
    modal.stalenessText = stalenessText

    local sharedText = modal.footer:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    sharedText:SetPoint("RIGHT", 0, 0)
    sharedText:SetJustifyH("RIGHT")
    applyTextColor(sharedText, "textSubtle", { 0.5, 0.55, 0.6 })
    modal.sharedText = sharedText

    -- ================== Public API ==================

    --- Bind the modal to a player and populate every tab.
    -- @param playerName string  "Name-Realm" format
    -- @param opts       table?  { preserveTab = true, item = { itemID,
    --                            itemLink, itemName, itemLevel, equipSlot } }
    --                  preserveTab — don't reset the active tab (used by
    --                            live-reload so the user doesn't get
    --                            snapped back to Overview mid-browse when
    --                            desktop sync arrives).
    --                  item      — item context for the Sims tab (trinket
    --                            sim + droptimizer are per-item). Passed
    --                            through from the council voting table;
    --                            nil when opened from context menus
    --                            outside an active vote.
    function modal:Bind(playerName, opts)
        opts = opts or {}
        self.playerName = playerName
        local intel = playerName and Loothing.PlayerIntel and Loothing.PlayerIntel:Get(playerName)
        -- Stash for ApplyTheme — on skin change, re-run Bind so FontString
        -- colors baked by SetValue/SetCaption pick up the new palette.
        self.lastIntel = intel
        self.lastPlayerName = playerName
        self.lastItemCtx = opts.item

        -- Header: name + badges + ilvl
        local classFile = intel and intel.class
        -- Pull class from CandidateManager/PlayerCache if not in intel
        if not classFile and Loothing.PlayerCache and Loothing.PlayerCache.Get then
            local cached = Loothing.PlayerCache:Get(playerName)
            if cached then classFile = cached.class end
        end
        local short = shortName(playerName)
        local r, g, b = classRGB(classFile)
        self.nameText:SetText(format("|cff%02x%02x%02x%s|r",
            math.floor(r * 255 + 0.5),
            math.floor(g * 255 + 0.5),
            math.floor(b * 255 + 0.5),
            short))

        local badges = {}
        if intel and intel.spec then badges[#badges + 1] = intel.spec end
        if intel and intel.role and intel.role ~= "NONE" then badges[#badges + 1] = intel.role end
        self.badgesText:SetText(#badges > 0 and ("|cff888888·|r  " .. table.concat(badges, "  |cff888888·|r  ")) or "")

        if intel and intel.ilvl then
            self.ilvlText:SetText(format("ilvl %d", math.floor(intel.ilvl + 0.5)))
        else
            self.ilvlText:SetText("")
        end

        -- Modal title uses the full player name
        self:SetTitle(format("%s  |cff888888—|r  %s",
            L("INTEL_TITLE", "Player Intel"),
            playerName or "?"))

        -- Tab content. Empty table stand-in when the player has no intel
        -- record so every Bind* function can read `intel.X` without nil-chain
        -- guards. Sims + Wishlist tabs receive the live player name and
        -- optional item context regardless of whether intel exists — they
        -- pull from TrinketSims / Droptimizer / Wishlist / PlayerCache /
        -- Roster directly, not from the intel blob.
        local bindIntel = intel or {}
        BindOverviewTab(refs, bindIntel)
        BindMPlusTab(refs, bindIntel)
        BindParsesTab(refs, bindIntel)
        BindRaidTab(refs, bindIntel)
        BindLootTab(refs, bindIntel)
        BindSimsTab(refs, bindIntel, playerName, opts.item)
        BindWishlistTab(refs, bindIntel, playerName)

        -- Footer: staleness badge + shared-by
        if Loothing.PlayerIntel then
            local age = Loothing.PlayerIntel:GetDataAge()
            if age then
                self.stalenessText:SetText(format(L("INTEL_SYNCED_FMT", "Synced %s"), formatAge(age)))
                if age < STALE_WARNING then
                    self.stalenessText:SetTextColor(0.5, 0.8, 0.5)
                elseif age < STALE_CRITICAL then
                    self.stalenessText:SetTextColor(0.9, 0.8, 0.2)
                else
                    self.stalenessText:SetTextColor(0.9, 0.3, 0.3)
                end
            else
                self.stalenessText:SetText(L("INTEL_NEVER_SYNCED", "Never synced"))
                self.stalenessText:SetTextColor(0.5, 0.5, 0.5)
            end

            if Loothing.PlayerIntel:IsSharedData() then
                local sharedBy = select(1, Loothing.PlayerIntel:GetSharedInfo())
                if sharedBy then
                    self.sharedText:SetText(format(L("INTEL_SHARED_BY_FMT", "Shared by %s"), shortName(sharedBy)))
                else
                    self.sharedText:SetText("")
                end
            else
                self.sharedText:SetText("")
            end
        end

        -- Hide EVERY tab panel before running the tab switcher. Without
        -- this, a close-then-reopen cycle leaves the previously-visible
        -- panel still Shown, and `SelectTab("overview")` only hides the
        -- prev tab id — which is nil on a fresh bind. Result: overview
        -- renders on top of (say) Wishlist from the previous session.
        if self.panels then
            for _, panel in pairs(self.panels) do
                panel:Hide()
            end
        end

        -- Tab state — preserve the active tab during live-reload from an
        -- intel share merge; otherwise (fresh open) snap back to Overview.
        local targetTab = "overview"
        if opts.preserveTab and self.tabStrip.currentId
            and self.tabStrip.tabs[self.tabStrip.currentId] then
            targetTab = self.tabStrip.currentId
        end
        self.tabStrip.currentId = nil
        self.tabStrip._positioned = false
        self.tabStrip:SelectTab(targetTab)

        -- Defer a single Refresh so GetLeft() settles on the overview tab
        C_Timer.After(0, function()
            if not self.frame or not self.frame:IsVisible() then return end
            if self.tabStrip then self.tabStrip:Refresh() end
        end)

        return self
    end

    --- Clear stored bindings on hide so history-row references don't pin.
    --- Also close any GameTooltip left up by a Wishlist-row hover and
    --- snap every tab panel back to Hidden — the next open re-runs
    --- SelectTab from a clean slate instead of finding the prior tab
    --- still visible under the overview panel.
    function modal:OnHideCleanup()
        self.playerName     = nil
        self.lastIntel      = nil
        self.lastPlayerName = nil
        self.lastItemCtx    = nil
        if GameTooltip and GameTooltip:IsShown() then
            GameTooltip:Hide()
        end
        if self.panels then
            for _, panel in pairs(self.panels) do
                panel:Hide()
            end
        end
        -- Also clear the tab indicator's active id so the next Bind
        -- guaranteed treats it as a fresh open (no stale "currentId
        -- matches, SelectTab is a no-op" path).
        if self.tabStrip then
            self.tabStrip.currentId = nil
            self.tabStrip._positioned = false
        end
    end

    --- Extend base ApplyTheme to retint our custom chrome (header, footer,
    --- every tab's cards, gear accent, alt-loot strip, loot list).
    local baseApplyTheme = modal.ApplyTheme
    function modal:ApplyTheme()
        baseApplyTheme(self)

        applyTextColor(self.badgesText, "textMuted", { 0.6, 0.62, 0.68 })
        applyTextColor(self.ilvlText,   "accent",    { 1, 0.82, 0 })
        applyTextColor(self.sharedText, "textSubtle", { 0.5, 0.55, 0.6 })

        if self.tabStrip then self.tabStrip:Refresh() end

        -- Retint overview cards
        if self.refs and self.refs.overviewCards then
            for _, card in pairs(self.refs.overviewCards) do
                if card.ApplyTheme then card:ApplyTheme() end
            end
        end
        if self.refs and self.refs.mplusCards then
            for _, card in pairs(self.refs.mplusCards) do
                if card.ApplyTheme then card:ApplyTheme() end
            end
        end
        if self.refs then
            for _, card in pairs({ self.refs.parseAvgCard, self.refs.parseBestCard, self.refs.raidAttendCard }) do
                if card and card.ApplyTheme then card:ApplyTheme() end
            end
            if self.refs.raidGearPanel and self.refs.raidGearPanel.SetBackdropColor then
                self.refs.raidGearPanel:SetBackdropColor(unpack(skinColor("panelInset", { 0.04, 0.05, 0.07, 0.5 })))
                self.refs.raidGearPanel:SetBackdropBorderColor(unpack(skinColor("border", { 0.2, 0.2, 0.2, 1 })))
            end
            if self.refs.raidGearAccent then
                self.refs.raidGearAccent:SetColorTexture(unpack(skinColor("accentWarm", { 0.93, 0.45, 0.25, 1 })))
            end
            if self.refs.lootAltStrip and self.refs.lootAltStrip.SetBackdropColor then
                self.refs.lootAltStrip:SetBackdropColor(unpack(skinColor("panelInset", { 0.04, 0.05, 0.07, 0.5 })))
                self.refs.lootAltStrip:SetBackdropBorderColor(unpack(skinColor("border", { 0.2, 0.2, 0.2, 1 })))
            end
            if self.refs.lootAltAccent then
                self.refs.lootAltAccent:SetColorTexture(unpack(skinColor("accentCool", { 0.35, 0.55, 0.9, 1 })))
            end
            if self.refs.lootList and self.refs.lootList.ApplyTheme then
                self.refs.lootList:ApplyTheme()
            end
        end

        if mf and mf.RefreshHoverAccents then mf.RefreshHoverAccents() end

        -- StatCards bake text colors into SetValue/SetCaption at Bind time,
        -- so a skin/accent change leaves their text stuck at the old palette
        -- until the next Bind. Re-run every tab's Bind against the stashed
        -- intel so big numbers / captions / row strings retint live.
        --
        -- Defer the re-bind a frame when the modal's open fade is in-flight:
        -- BindRaidTab / BindLootTab trigger layout work that can visibly
        -- stutter the 0.22s FadeIn if it lands mid-tween.
        local function runRebind()
            if not self.lastPlayerName or not self.body or not self.body:IsVisible() then return end
            local intel = self.lastIntel or {}
            BindOverviewTab(self.refs, intel)
            BindMPlusTab(self.refs, intel)
            BindParsesTab(self.refs, intel)
            BindRaidTab(self.refs, intel)
            BindLootTab(self.refs, intel)
            BindSimsTab(self.refs, intel, self.lastPlayerName, self.lastItemCtx)
            BindWishlistTab(self.refs, intel, self.lastPlayerName)
        end
        if self.frame and self.frame._loothingFadeGroup then
            C_Timer.After(0.05, runRebind)
        else
            runRebind()
        end
    end

    -- Live refresh: when desktop data reloads (own sync or /lt share merge),
    -- re-bind the modal so an open window picks up new intel immediately.
    -- `preserveTab = true` keeps the user parked on whichever tab they were
    -- browsing instead of snapping back to Overview.
    if Loothing.PlayerIntel and Loothing.PlayerIntel.RegisterCallback then
        Loothing.PlayerIntel:RegisterCallback("OnPlayerIntelLoaded", function()
            if modal:IsShown() and modal.playerName then
                modal:Bind(modal.playerName, {
                    preserveTab = true,
                    item        = modal.lastItemCtx,
                })
            end
        end, modal)
    end

    intelInstance = modal
    return modal
end

--[[--------------------------------------------------------------------
    Public entry points
----------------------------------------------------------------------]]

--- Open the player intel modal for a given player.
-- @param playerName string - "Name-Realm" format
-- @param opts       table?  { item = {itemID, itemLink, itemName,
--                             itemLevel, equipSlot} } — item context for
--                            the Sims tab. Pass when opening from the
--                            council voting table; omit otherwise.
function ns.ShowPlayerIntel(playerName, opts)
    if not playerName or playerName == "" then return end
    local modal = getPlayerIntelInstance()
    if not modal then return end
    modal:Bind(playerName, opts):Show()
end

--- Theme dispatch hook (consumed by Skinning.lua RefreshTheme).
--- Also exposes `UpdateItemContext` so the council voting table can push
--- a new item context when the user switches item tabs while the modal
--- is open — without it the Sims tab would keep showing projections
--- for the previous item until close/reopen.
ns.PlayerIntelFrames = {
    ApplyTheme = function()
        if intelInstance and intelInstance.ApplyTheme then
            intelInstance:ApplyTheme()
        end
    end,

    --- Re-bind the open modal against a new item context. No-op when
    --- the modal hasn't been opened yet or is hidden. Preserves the
    --- active tab (user browsing Wishlist stays on Wishlist) and carries
    --- forward the candidateClass / candidateSpec resolved at open time —
    --- callers at the item-switch seam don't re-resolve those, so we'd
    --- otherwise fall back to the intel/PlayerCache/Roster chain which
    --- can mis-key for classes whose class token doesn't match the
    --- desktop-written field.
    --- @param itemCtx table|nil  New item context (or nil to clear).
    UpdateItemContext = function(itemCtx)
        if not intelInstance or not intelInstance.IsShown or not intelInstance:IsShown() then
            return
        end
        if not intelInstance.playerName then return end
        local prev = intelInstance.lastItemCtx
        if itemCtx and prev then
            -- Only backfill when the new ctx didn't carry the field.
            itemCtx.candidateClass = itemCtx.candidateClass or prev.candidateClass
            itemCtx.candidateSpec  = itemCtx.candidateSpec  or prev.candidateSpec
        end
        intelInstance:Bind(intelInstance.playerName, {
            preserveTab = true,
            item        = itemCtx,
        })
    end,
}
