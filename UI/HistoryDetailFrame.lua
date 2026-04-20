--[[--------------------------------------------------------------------
    Loothing - HistoryDetailFrame

    Four read-only modals that surface the full audit trail already
    captured on each history entry by Session.lua:1893-1943.

        ns.ShowHistoryDetail(entry)          -- Item Detail modal (3 tabs)
        ns.ShowSessionSummary(entry)         -- Sibling items from the same encounter/pull
        ns.ShowCandidateProfile(playerName)  -- Lifetime history for one player
        ns.ShowVoterProfile(voterName)       -- Lifetime council votes cast by one voter

    All four are singletons - one shared frame per modal type, rebound per
    invocation. They stack on strata DIALOG and coexist with the main
    history panel and with each other (opening Session Summary from Item
    Detail does not close Item Detail; opening a Candidate Profile from
    the Candidates tab does not close the Item Detail).

    Follows the Loothing-native frame pattern (raw CreateFrame +
    SkinningMixin + FramePolish) used by LootPickerFrame.lua and
    MainFrame.lua. See the loothing-ui-polish skill for the contract.

    Data shape reference - historyEntry fields consumed:
        itemLink, itemID, itemName, itemLevel, quality, equipSlot
        winner, winnerClass, winnerResponse, winnerResponseText,
        winnerRoll, winnerNote, winnerGear1, winnerGear2,
        winnerGear1ilvl, winnerGear2ilvl, winnerIlvlDiff
        encounterID, encounterName, instance, difficultyName,
        groupSize, timestamp, date, time
        awardReason, owner, votes
        candidates[]   - per-candidate response/roll/note/gear/vote count
        councilVotes[] - per-voter voter/voterClass/responses[]/note
----------------------------------------------------------------------]]

local _, ns = ...
local Loolib = LibStub("Loolib")
local Loothing = ns.Addon
local Utils = ns.Utils
local SkinningMixin = ns.SkinningMixin

local AnimationUtil = Loolib.AnimationUtil
local AnimationPresets = Loolib.AnimationPresets
local PixelUtil = Loolib.PixelUtil

local ApplyAccentGlow = ns.FramePolish.ApplyAccentGlow
local AttachIconButtonPolish = ns.FramePolish.AttachIconButtonPolish

--[[--------------------------------------------------------------------
    Dimensions (stay inside a 1080p safe area - the main frame is 600x450
    and this modal should visually dwarf it without clipping on 720p).
----------------------------------------------------------------------]]

local ITEM_DETAIL_WIDTH = 720
local ITEM_DETAIL_HEIGHT = 560
local SESSION_SUMMARY_WIDTH = 560
local SESSION_SUMMARY_HEIGHT = 460
local PROFILE_WIDTH = 680
local PROFILE_HEIGHT = 520
-- Scope summary modals (Raid / Boss / Season) show a five-column grid
-- (item / date / boss / winner / response) — need ~760 px of inner room
-- to render the Response column inside the frame.
local SCOPE_SUMMARY_WIDTH = 780
local SCOPE_SUMMARY_HEIGHT = 520

local HEADER_HEIGHT = 52
local TAB_HEIGHT = 30
local FOOTER_HEIGHT = 40
local ROW_HEIGHT = 28
local CANDIDATE_ROW_HEIGHT = 36

--[[--------------------------------------------------------------------
    Small helpers
----------------------------------------------------------------------]]

local function L(key, fallback)
    local locale = ns.Locale or Loothing.Locale or {}
    return locale[key] or fallback or key
end

--- Quality color from an item quality int, with a link-based fallback for
--- entries that carry `itemLink` but not `quality` (common on legacy or
--- remote-synced history entries that pre-date the backfill pass).
local function qualityColor(quality, itemLink)
    if type(quality) ~= "number" and itemLink and C_Item and C_Item.GetItemInfo then
        local _, _, q = C_Item.GetItemInfo(itemLink)
        quality = q
    end
    if type(quality) == "number" and C_Item and C_Item.GetItemQualityColor then
        local r, g, b = C_Item.GetItemQualityColor(quality)
        return r, g, b
    end
    return 0.5, 0.5, 0.5
end

--- Class color for a classFile (e.g. "PALADIN"). Falls back to white.
--- Returns r, g, b in [0, 1].
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

--- Format a player's name class-colored with realm stripped.
--- Returns a wow color-coded string.
local function classColoredName(playerName, classFile)
    if not playerName then return "" end
    local short = Utils.GetShortName(playerName) or playerName
    local r, g, b = classRGB(classFile)
    return string.format("|cff%02x%02x%02x%s|r",
        math.floor(r * 255 + 0.5),
        math.floor(g * 255 + 0.5),
        math.floor(b * 255 + 0.5),
        short)
end

--- Resolve the winner's actual roll response for a history entry.
--- The real award code path in `ResultsPanel.lua` / `AutoAward.lua`
--- passes `nil` for the response arg of `Session:AwardItem`, so
--- `entry.winnerResponse` is nil for every real award — only the
--- award REASON (Main Spec / Off Spec / BiS / etc) is captured there.
--- The winner's actual NEED / GREED / OFFSPEC / TRANSMOG / PASS
--- lives in the candidate snapshot `entry.candidates[i].response`.
--- This helper prefers the explicit field when present (tests, future
--- code paths that do pass it) and falls back to the candidate lookup.
local function getWinnerResponse(entry)
    if not entry then return nil end
    if entry.winnerResponse then return entry.winnerResponse end
    if type(entry.candidates) == "table" and entry.winner then
        for _, c in ipairs(entry.candidates) do
            if type(c) == "table" and c.playerName == entry.winner and c.response then
                return c.response
            end
        end
    end
    return nil
end

--- Wrap a response id in its configured color. Returns nil (not "") on a
--- missing id so `responseColoredText(x) or fallback` works as intended.
local function responseColoredText(responseId)
    if not responseId then return nil end
    local info = Loothing.ResponseInfo[responseId]
        or (Loothing.SystemResponseInfo and Loothing.SystemResponseInfo[responseId])
    if not info then return tostring(responseId) end
    local c = info.color or {}
    local r = math.floor((c.r or 1) * 255 + 0.5)
    local g = math.floor((c.g or 1) * 255 + 0.5)
    local b = math.floor((c.b or 1) * 255 + 0.5)
    return string.format("|cff%02x%02x%02x%s|r", r, g, b, info.text or info.name or tostring(responseId))
end

--- Get a color table {r,g,b,a} for the skin (for SetTextColor unpacking).
local function skinColor(key, fallback)
    if SkinningMixin and SkinningMixin.GetColor then
        return SkinningMixin:GetColor(key, fallback)
    end
    return fallback or { 1, 1, 1, 1 }
end

--- Apply a style-surface on a frame if SkinningMixin is available.
local function styleSurface(frame, variant)
    if not frame then return end
    if SkinningMixin and SkinningMixin.StyleSurface then
        SkinningMixin:StyleSurface(frame, variant)
    end
end

--- Apply text color from the skin.
local function applyTextColor(fs, key, fallback)
    if not fs then return end
    local c = skinColor(key, fallback)
    fs:SetTextColor(c[1], c[2], c[3], c[4] or 1)
end

--- Style a button via SkinningMixin if available.
local function styleButton(btn, variant)
    if not btn then return end
    if SkinningMixin and SkinningMixin.StylePlainButton then
        SkinningMixin:StylePlainButton(btn, variant)
    end
end

--- Insert `text` into the chat edit box, opening it first if necessary.
--- ChatEdit_InsertLink alone silently no-ops when the edit box is closed,
--- which is why the plain "Link in Chat" button used to appear dead.
local function insertChatText(text)
    if not text or text == "" then return end
    local active = ChatEdit_GetActiveWindow and ChatEdit_GetActiveWindow()
        or (ChatEdit_GetLastActiveWindow and ChatEdit_GetLastActiveWindow())
    if active then
        if not active:IsShown() then active:Show() end
        active:SetFocus()
        if active.Insert then
            active:Insert(text)
        else
            active:SetText((active:GetText() or "") .. text)
        end
    elseif ChatFrame_OpenChat then
        ChatFrame_OpenChat(text)
    end
end

ns.InsertChatText = insertChatText

--[[--------------------------------------------------------------------
    Hover polish helpers

    Every clickable row / name button in the modal system gets two
    zero-script visual affordances that read as "this is hoverable":

      - `addRowHoverAccent(row)` — a 3px accent-colored bar pinned to the
        row's left edge on the HIGHLIGHT draw-layer, which WoW only
        renders while the cursor is over the frame. No HookScript / no
        animation group / no OnEnter plumbing, so it stacks cleanly with
        the bindRow's tooltip/click handlers.

      - `addClickableUnderline(button)` — a 1px white underline on the
        HIGHLIGHT layer under the button's FontString. Cheap, dependable,
        paints anywhere the pointer moves across the text.

    Both helpers are idempotent per frame via a `_*added` flag so a
    pooled row / reused button doesn't stack duplicates. Theme changes
    re-tint the accent bars via the dispatch hook at the bottom of the
    file.
----------------------------------------------------------------------]]

-- Forward-declare every modal's singleton slot so the theme-refresh
-- dispatch at the bottom of the file, and any cross-modal `ns.Show*`
-- closures, can reference them regardless of the in-file factory order.
local detailInstance, summaryInstance, candidateInstance, voterInstance
local raidSummaryInstance, bossSummaryInstance, seasonSummaryInstance
local browserInstance, awardMatrixInstance, itemSummaryInstance

-- Weak-keyed registry: if a row frame is ever destroyed the texture
-- entry can be collected rather than pinned here indefinitely. In
-- practice row frames live for the addon's lifetime (they're pooled,
-- not destroyed), so this is primarily a statement of intent.
local hoverAccentRegistry = setmetatable({}, { __mode = "k" })

local function addRowHoverAccent(row)
    if not row or row._hoverAccentAdded then return end
    row._hoverAccentAdded = true
    local bar = row:CreateTexture(nil, "HIGHLIGHT")
    bar:SetWidth(3)
    bar:SetPoint("TOPLEFT", 0, 0)
    bar:SetPoint("BOTTOMLEFT", 0, 0)
    local c = skinColor("accent", { 1, 0.82, 0 })
    bar:SetColorTexture(c[1], c[2], c[3], c[4] or 1)
    row._hoverBar = bar
    hoverAccentRegistry[bar] = true
end

local function addClickableUnderline(button)
    if not button or button._underlineAdded then return end
    button._underlineAdded = true
    local fs = button.text or (button.GetFontString and button:GetFontString())
    if not fs then return end
    local u = button:CreateTexture(nil, "HIGHLIGHT")
    u:SetHeight(1)
    u:SetPoint("BOTTOMLEFT", fs, "BOTTOMLEFT", 0, -1)
    u:SetPoint("BOTTOMRIGHT", fs, "BOTTOMRIGHT", 0, -1)
    u:SetColorTexture(1, 1, 1, 0.55)
    button._underline = u
    button:EnableMouse(true)
end

--- Toggle a button between clickable and inert. When `clickable` is
--- false we disable mouse on the button and hide its underline so it
--- stops advertising itself as interactive — the parent row still
--- receives the click and can forward to a fallback action (e.g., open
--- the item detail modal instead of a boss summary when the row is for
--- an entry with no encounter info).
local function setButtonClickable(button, clickable)
    if not button then return end
    button:EnableMouse(clickable and true or false)
    if button._underline then
        if clickable then
            button._underline:Show()
        else
            button._underline:Hide()
        end
    end
end

--- Walked on skin/accent change so every tracked hover bar restains.
local function refreshHoverAccents()
    local c = skinColor("accent", { 1, 0.82, 0 })
    for tex in pairs(hoverAccentRegistry) do
        if type(tex.SetColorTexture) == "function" then
            tex:SetColorTexture(c[1], c[2], c[3], c[4] or 1)
        end
    end
end

--[[--------------------------------------------------------------------
    Cross-UI clickable helpers (exported on `ns`)

    Any Button frame anywhere in the addon can be made a clickable link
    into the history-detail modal family via one of these helpers. Each
    one installs:

      - `region:EnableMouse(true)` + `RegisterForClicks("LeftButtonUp")`
      - OnClick handler that opens the relevant modal
      - `addClickableUnderline(region)` — HIGHLIGHT-layer underline so
        the link affordance is visible on hover

    Helpers are idempotent per frame (underline / OnClick are safely
    re-settable) and short-circuit on nil inputs.

    Example — make a player-name Button open their profile:

        ns.MakeCharacterClickable(row.nameBtn, function() return row.playerName end)
----------------------------------------------------------------------]]

--- Wrap a Button so clicking it opens the candidate profile for
--- `getName()`. The getter is invoked on every click so callers can
--- rebind the underlying name freely between paints.
--- @param region Button
--- @param getName function  must return a player name string (or nil)
function ns.MakeCharacterClickable(region, getName)
    if not region or type(getName) ~= "function" then return end
    region:EnableMouse(true)
    if region.RegisterForClicks then
        region:RegisterForClicks("LeftButtonUp")
    end
    region:SetScript("OnClick", function()
        local name = getName()
        if name and name ~= "" and ns.ShowCandidateProfile then
            ns.ShowCandidateProfile(name)
        end
    end)
    addClickableUnderline(region)
end

--- Wrap a Button so clicking it opens the item summary for `getItem()`,
--- which may return either a numeric itemID or a WoW item link.
--- @param region Button
--- @param getItem function  must return number|string|nil
function ns.MakeItemClickable(region, getItem)
    if not region or type(getItem) ~= "function" then return end
    region:EnableMouse(true)
    if region.RegisterForClicks then
        region:RegisterForClicks("LeftButtonUp")
    end
    region:SetScript("OnClick", function()
        local item = getItem()
        if item and ns.ShowItemSummary then
            ns.ShowItemSummary(item)
        end
    end)
    addClickableUnderline(region)
end

--- Wrap a Button so clicking a response pill opens the Award Matrix
--- pre-sorted on that response column — quick "who uses this response
--- the most" view.
--- @param region Button
--- @param getResponseId function  must return number|nil
function ns.MakeResponseClickable(region, getResponseId)
    if not region or type(getResponseId) ~= "function" then return end
    region:EnableMouse(true)
    if region.RegisterForClicks then
        region:RegisterForClicks("LeftButtonUp")
    end
    region:SetScript("OnClick", function()
        local respId = getResponseId()
        if not respId or not ns.ShowAwardMatrix then return end
        -- ShowAwardMatrix triggers the lazy build of the modal and
        -- populates the forward-declared `awardMatrixInstance` upvalue.
        ns.ShowAwardMatrix()
        local m = awardMatrixInstance
        if not m or not m.columns then return end
        -- Guard against sorting on a column that doesn't exist (e.g. a
        -- response id not in the current response set) — without this
        -- check the matrix ends up with an orphan sortCol and no
        -- visible sort arrow.
        local targetCol = "resp" .. tostring(respId)
        local found
        for _, c in ipairs(m.columns) do
            if c.id == targetCol then found = true; break end
        end
        if not found then return end
        m.sortCol = targetCol
        m.sortDir = "desc"
        if m.RefreshSortArrows then m:RefreshSortArrows() end
        if m.Rebuild then m:Rebuild() end
    end)
    addClickableUnderline(region)
end

--- Anchor a tooltip on a region and show an item link.
local function attachItemTooltip(region, getLink, extraLines)
    region:EnableMouse(true)
    region:SetScript("OnEnter", function(r)
        local link = type(getLink) == "function" and getLink() or getLink
        GameTooltip:SetOwner(r, "ANCHOR_RIGHT")
        if link then
            GameTooltip:SetHyperlink(link)
        end
        if extraLines then
            for _, line in ipairs(extraLines) do
                GameTooltip:AddLine(line, 1, 0.82, 0)
            end
        end
        GameTooltip:Show()
    end)
    region:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

--[[--------------------------------------------------------------------
    Modal frame factory

    Produces a reusable polished modal chrome:
      - DIALOG strata, level 110 so it sits above MainFrame (HIGH).
      - Backdrop styled with the current skin.
      - Gradient accent strip behind the title (dynamic via SkinningMixin).
      - Pixel-perfect inner border with borderStrong color.
      - Title FontString + subtitle FontString.
      - Close button with AttachIconButtonPolish.
      - Draggable; clamped to screen; ESC-to-close registered.
      - Fade-in / fade-out on Show / Hide.
      - mixin:ApplyTheme() re-applies accent/border/colors on skin change.

    Returns a mixin table + the frame. Caller is responsible for building
    content inside `mixin.content`.
----------------------------------------------------------------------]]

local function CreateModal(globalName, width, height, titleText)
    local frame = CreateFrame("Frame", globalName, UIParent, "BackdropTemplate")
    frame:SetSize(width, height)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("DIALOG")
    frame:SetFrameLevel(110)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:SetClampedToScreen(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function(f) f:StartMoving() end)
    frame:SetScript("OnDragStop", function(f)
        f:StopMovingOrSizing()
        if SkinningMixin and SkinningMixin.SaveFrameState then
            SkinningMixin:SaveFrameState(f, globalName)
        end
    end)

    -- Resize support: every modal can be dragged to any size between its
    -- initial dimensions (as minimum) and a roomy cap. Internal content
    -- is anchored TOPLEFT/BOTTOMRIGHT, TOPLEFT/TOPRIGHT, or
    -- BOTTOMLEFT/BOTTOMRIGHT so it reflows automatically.
    frame:SetResizable(true)
    if frame.SetResizeBounds then
        frame:SetResizeBounds(width, height, 1600, 1000)
    elseif frame.SetMinResize then
        -- Legacy API fallback for older clients.
        frame:SetMinResize(width, height)
        frame:SetMaxResize(1600, 1000)
    end

    frame:Hide()
    frame:SetAlpha(0)

    -- Base skin
    styleSurface(frame, "frame")
    if SkinningMixin and SkinningMixin.DecorateWindow then
        SkinningMixin:DecorateWindow(frame)
    end

    -- Gradient accent strip behind the title
    local headerStrip = frame:CreateTexture(nil, "BACKGROUND", nil, 2)
    headerStrip:SetPoint("TOPLEFT", 2, -2)
    headerStrip:SetPoint("TOPRIGHT", -2, -2)
    headerStrip:SetHeight(HEADER_HEIGHT - 8)
    headerStrip:SetColorTexture(1, 1, 1, 1)
    ApplyAccentGlow(headerStrip, 0.18)

    -- Pixel border
    local pixelBorder
    if PixelUtil and type(PixelUtil.SetThinBorder) == "function" then
        pixelBorder = PixelUtil.SetThinBorder(frame, skinColor("borderStrong", { 0, 0, 0, 1 }))
    end

    -- Title
    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 14, -12)
    title:SetText(titleText or "")
    applyTextColor(title, "text", { 1, 0.82, 0 })

    -- Subtitle (optional - populated by caller)
    local subtitle = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    subtitle:SetPoint("TOPLEFT", 14, -32)
    applyTextColor(subtitle, "textMuted", { 0.7, 0.7, 0.7 })

    -- Close button
    local closeBtn = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    closeBtn:SetSize(22, 22)
    closeBtn:SetPoint("TOPRIGHT", -2, -2)
    AttachIconButtonPolish(closeBtn, { hoverScale = 1.15, pressScale = 0.90 })

    -- Content container (callers attach children here)
    local content = CreateFrame("Frame", nil, frame)
    content:SetPoint("TOPLEFT", 10, -(HEADER_HEIGHT))
    content:SetPoint("BOTTOMRIGHT", -10, FOOTER_HEIGHT + 4)

    -- Footer (callers attach buttons here)
    local footer = CreateFrame("Frame", nil, frame)
    footer:SetPoint("BOTTOMLEFT", 10, 8)
    footer:SetPoint("BOTTOMRIGHT", -10, 8)
    footer:SetHeight(FOOTER_HEIGHT - 8)

    -- Resize grip in the bottom-right corner. 12x12 at (-1, 1) keeps it
    -- flush with the frame corner without intruding on the footer row's
    -- Close button (anchored RIGHT inside the footer, height 24 centered).
    -- Drag resizes within the SetResizeBounds limits;
    -- StopMovingOrSizing + SaveFrameState persists the new size to
    -- SavedVariables (same path as drag-move).
    local resizeGrip = CreateFrame("Button", nil, frame)
    resizeGrip:SetSize(12, 12)
    resizeGrip:SetPoint("BOTTOMRIGHT", -1, 1)
    resizeGrip:SetFrameLevel(frame:GetFrameLevel() + 5)

    -- Visual: three diagonal lines drawn as small textures. Cheap, no
    -- Blizzard asset dependency, matches the minimal aesthetic of the
    -- polished UI. Accent-tinted on hover via the standard HIGHLIGHT layer.
    local function makeGripLine(inset)
        local tex = resizeGrip:CreateTexture(nil, "ARTWORK")
        tex:SetColorTexture(1, 1, 1, 0.5)
        tex:SetSize(2, 2 + inset * 2)
        tex:SetPoint("BOTTOMRIGHT", -1 - inset * 3, 1)
        tex:SetRotation(math.rad(-45))
        return tex
    end
    resizeGrip._lines = { makeGripLine(0), makeGripLine(1), makeGripLine(2) }

    local hl = resizeGrip:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints()
    hl:SetColorTexture(unpack(skinColor("accent", { 1, 0.82, 0, 1 })))
    hl:SetAlpha(0.35)
    resizeGrip._highlight = hl

    resizeGrip:SetScript("OnMouseDown", function(_, btn)
        if btn == "LeftButton" then
            frame:StartSizing("BOTTOMRIGHT")
        end
    end)
    resizeGrip:SetScript("OnMouseUp", function()
        frame:StopMovingOrSizing()
        if SkinningMixin and SkinningMixin.SaveFrameState then
            SkinningMixin:SaveFrameState(frame, globalName)
        end
    end)
    resizeGrip:SetScript("OnEnter", function()
        GameTooltip:SetOwner(resizeGrip, "ANCHOR_TOP")
        GameTooltip:SetText(L("HISTORY_DETAIL_RESIZE_HINT", "Drag to resize"))
        GameTooltip:Show()
    end)
    resizeGrip:SetScript("OnLeave", function() GameTooltip:Hide() end)

    -- Belt-and-suspenders: if the frame is hidden mid-drag (Escape, combat
    -- auto-hide, external caller), cancel any in-flight sizing so the
    -- frame doesn't reopen in a "still sizing" state on the next Show.
    frame:HookScript("OnHide", function(f) f:StopMovingOrSizing() end)

    local modal = {
        frame = frame,
        headerStrip = headerStrip,
        pixelBorder = pixelBorder,
        title = title,
        subtitle = subtitle,
        closeBtn = closeBtn,
        content = content,
        footer = footer,
        resizeGrip = resizeGrip,
        globalName = globalName,
    }

    closeBtn:SetScript("OnClick", function() modal:Hide() end)

    -- Theming, position persistence, ESC-close
    if SkinningMixin and SkinningMixin.SetupFrame then
        SkinningMixin:SetupFrame(frame, globalName, globalName, {
            escapeClose = true,
            combatMinimize = false,
        })
    end

    -- Route every Hide (Escape via UISpecialFrames, external frame:Hide(),
    -- parent-destroyed) through the same cleanup so an in-flight fade group
    -- never leaves alpha stuck at a partial value, and so a subsequent Show
    -- starts clean. Also clears the bound entry + footer closures so dead
    -- references don't pin history-row data longer than necessary.
    frame:HookScript("OnHide", function()
        if frame._loothingFadeGroup then
            frame._loothingFadeGroup:Stop()
            frame._loothingFadeGroup = nil
        end
        frame:SetAlpha(0)
        if modal.OnHideCleanup then modal:OnHideCleanup() end
    end)

    function modal:Show()
        if self.frame._loothingFadeGroup then
            self.frame._loothingFadeGroup:Stop()
            self.frame._loothingFadeGroup = nil
        end
        -- Snap to 0 so FadeIn always starts from transparent, even if a
        -- prior FadeOut was interrupted mid-animation.
        self.frame:SetAlpha(0)
        self.frame:Show()
        self.frame:Raise()
        if type(self.ApplyTheme) == "function" then self:ApplyTheme() end
        if AnimationPresets then
            self.frame._loothingFadeGroup = AnimationPresets.FadeIn(self.frame, 0.22, "outCubic")
        else
            self.frame:SetAlpha(1)
        end
    end

    function modal:Hide()
        if not self.frame then return end
        if self.frame._loothingFadeGroup then
            self.frame._loothingFadeGroup:Stop()
            self.frame._loothingFadeGroup = nil
        end
        if AnimationPresets and self.frame:IsVisible() then
            self.frame._loothingFadeGroup = AnimationPresets.FadeOut(self.frame, 0.13, "inCubic", true, function()
                if self.frame then self.frame:SetAlpha(0) end
            end)
        else
            self.frame:Hide()
        end
    end

    function modal:IsShown()
        return self.frame and self.frame:IsShown() or false
    end

    function modal:SetTitle(text) self.title:SetText(text or "") end
    function modal:SetSubtitle(text) self.subtitle:SetText(text or "") end

    --- Re-apply all theme-driven paint to the modal chrome. Call from Show()
    --- and also from the outer ApplyTheme() dispatch.
    function modal:ApplyTheme()
        styleSurface(self.frame, "frame")
        applyTextColor(self.title, "text", { 1, 0.82, 0 })
        applyTextColor(self.subtitle, "textMuted", { 0.7, 0.7, 0.7 })
        if self.headerStrip then
            ApplyAccentGlow(self.headerStrip, 0.18)
            self.headerStrip:SetAlpha(1)
        end
        if self.pixelBorder then
            local c = skinColor("borderStrong", { 0, 0, 0, 1 })
            for _, tex in pairs(self.pixelBorder) do
                if type(tex) == "table" and type(tex.SetColorTexture) == "function" then
                    tex:SetColorTexture(c[1] or 0, c[2] or 0, c[3] or 0, c[4] or 1)
                end
            end
        end
        -- Re-tint the resize grip's hover accent so skin/accent changes
        -- apply to it live along with the rest of the chrome.
        if self.resizeGrip and self.resizeGrip._highlight then
            self.resizeGrip._highlight:SetColorTexture(
                unpack(skinColor("accent", { 1, 0.82, 0, 1 })))
            self.resizeGrip._highlight:SetAlpha(0.35)
        end
    end

    return modal
end

--[[--------------------------------------------------------------------
    Tab strip factory

    Simplified version of MainFrame's tab system - just the pieces we
    need for an in-modal tab switcher:
      - A tabContainer hosting N tab Buttons
      - A single tabIndicator texture that slides to the active tab
      - tabs: array of { id = "...", text = "...", panel = Frame }
      - mixin:SelectTab(id) switches the visible panel + animates indicator
----------------------------------------------------------------------]]

local function CreateTabStrip(parent, tabDefs, onSelect)
    local tabContainer = CreateFrame("Frame", nil, parent)
    tabContainer:SetPoint("TOPLEFT", 0, 0)
    tabContainer:SetPoint("TOPRIGHT", 0, 0)
    tabContainer:SetHeight(TAB_HEIGHT + 6)

    local indicator = tabContainer:CreateTexture(nil, "OVERLAY", nil, 7)
    indicator:SetHeight(3)
    indicator:SetPoint("BOTTOMLEFT", tabContainer, "BOTTOMLEFT", 2, 2)
    indicator:SetWidth(0)
    indicator:SetColorTexture(1, 1, 1, 1)
    indicator:Hide()

    local strip = {
        container = tabContainer,
        indicator = indicator,
        tabs = {},
        order = {},
        currentId = nil,
        _positioned = false,
    }

    local tabWidth = 110
    local spacing = 4
    local xOffset = 0

    for _, def in ipairs(tabDefs) do
        local tab = CreateFrame("Button", nil, tabContainer, "BackdropTemplate")
        tab:SetSize(tabWidth, TAB_HEIGHT)
        tab:SetPoint("BOTTOMLEFT", xOffset, 0)
        styleSurface(tab, "alt")

        local highlight = tab:CreateTexture(nil, "HIGHLIGHT")
        highlight:SetAllPoints()
        highlight:SetColorTexture(1, 1, 1, 0.08)

        local text = tab:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        text:SetPoint("LEFT", 8, 0)
        text:SetPoint("RIGHT", -8, 0)
        text:SetJustifyH("CENTER")
        text:SetWordWrap(false)
        text:SetText(def.text or def.id)
        if SkinningMixin and SkinningMixin.StyleText then
            SkinningMixin:StyleText(text, "header", "textMuted")
        end
        tab.text = text
        tab.id = def.id

        local tabId = def.id
        tab:SetScript("OnClick", function() strip:SelectTab(tabId) end)

        strip.tabs[def.id] = tab
        strip.order[#strip.order + 1] = def.id
        xOffset = xOffset + tabWidth + spacing
    end

    --- Snap/slide the indicator under the target tab.
    function strip:MoveIndicatorTo(tab)
        if not self.indicator or not tab then return end
        local containerLeft = self.container:GetLeft() or 0
        local tabLeft = tab:GetLeft() or 0
        local targetX = (tabLeft - containerLeft) + 2
        local targetWidth = math.max(0, tab:GetWidth() - 4)
        self.indicator:SetVertexColor(unpack(skinColor("accent", { 1, 0.82, 0 })))
        self.indicator:Show()

        local skipAnim = not AnimationUtil or not self.container:IsVisible() or not self._positioned
        if skipAnim then
            self.indicator:ClearAllPoints()
            self.indicator:SetPoint("BOTTOMLEFT", self.container, "BOTTOMLEFT", targetX, 2)
            self.indicator:SetWidth(targetWidth)
            self._positioned = true
            return
        end

        local _, _, _, curX = self.indicator:GetPoint(1)
        curX = curX or targetX
        local curWidth = self.indicator:GetWidth() or 0

        self.indicator:ClearAllPoints()
        self.indicator:SetPoint("BOTTOMLEFT", self.container, "BOTTOMLEFT", curX, 2)

        if self._animGroup then self._animGroup:Stop() end
        local group = AnimationUtil.CreateGroup(self.indicator)
        group:CreateAnimation("move", {
            target = self.indicator,
            baseAnchor = { point = "BOTTOMLEFT", relativeTo = self.container, relativePoint = "BOTTOMLEFT", x = curX, y = 2 },
            from = { 0, 0 },
            to = { targetX - curX, 0 },
            duration = 0.22,
            easing = "outCubic",
        })
        group:CreateAnimation("width", {
            target = self.indicator,
            from = curWidth,
            to = targetWidth,
            duration = 0.22,
            easing = "outCubic",
        })
        group:SetOnFinished(function()
            if not self.indicator then return end
            self.indicator:ClearAllPoints()
            self.indicator:SetPoint("BOTTOMLEFT", self.container, "BOTTOMLEFT", targetX, 2)
            self.indicator:SetWidth(targetWidth)
        end)
        self._animGroup = group
        self._positioned = true
        group:Play()
    end

    --- Apply active/idle color to a tab. Snap form; the sliding indicator
    --- provides the animation so per-tab color tweens are overkill.
    local function paintTab(tab, active)
        if not tab then return end
        if active then
            tab:SetBackdropColor(unpack(skinColor("panel", { 0.1, 0.1, 0.1, 1 })))
            tab:SetBackdropBorderColor(unpack(skinColor("accent", { 1, 0.82, 0, 1 })))
            applyTextColor(tab.text, "accent", { 1, 0.82, 0 })
        else
            tab:SetBackdropColor(unpack(skinColor("panelAlt", { 0.08, 0.08, 0.08, 1 })))
            tab:SetBackdropBorderColor(unpack(skinColor("borderStrong", { 0.3, 0.3, 0.3, 1 })))
            applyTextColor(tab.text, "textMuted", { 0.66, 0.70, 0.79 })
        end
    end

    function strip:SelectTab(tabId)
        if self.currentId == tabId then return end
        local prevId = self.currentId
        self.currentId = tabId

        for _, tab in pairs(self.tabs) do
            paintTab(tab, tab.id == tabId)
        end

        self:MoveIndicatorTo(self.tabs[tabId])

        if onSelect then onSelect(tabId, prevId) end
    end

    function strip:Refresh()
        for _, tab in pairs(self.tabs) do
            paintTab(tab, tab.id == self.currentId)
        end
        if self.currentId and self.container:IsVisible() then
            self:MoveIndicatorTo(self.tabs[self.currentId])
        end
    end

    return strip
end

--[[--------------------------------------------------------------------
    Scroll list factory

    Thin wrapper around CreateFrame("ScrollFrame") + a frame pool for
    rows. Caller provides:
        rowHeight     - fixed height per row
        initRow(row)  - one-time init of row children; called on first use
        bindRow(row, data, index)  - per-entry data binding; called every refresh
    The factory returns a table with:
        scrollFrame, content, rowPool, pixelBorder, emptyText
        list:Refresh(entries)   - rebuild rows from an entries array
        list:ApplyTheme()       - re-style surface + border
----------------------------------------------------------------------]]

local function CreateScrollList(parent, opts)
    opts = opts or {}
    local rowHeight = opts.rowHeight or ROW_HEIGHT
    local rowSpacing = opts.rowSpacing or 2
    local initRow = opts.initRow
    local bindRow = opts.bindRow
    local emptyMessage = opts.emptyMessage or L("HISTORY_DETAIL_NO_DATA", "No data captured for this entry.")

    local container = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    styleSurface(container, "inset")

    local pixelBorder
    if PixelUtil and type(PixelUtil.SetThinBorder) == "function" then
        pixelBorder = PixelUtil.SetThinBorder(container, skinColor("borderStrong", { 0, 0, 0, 1 }))
    end

    local scrollFrame = CreateFrame("ScrollFrame", nil, container)
    scrollFrame:SetPoint("TOPLEFT", 4, -4)
    scrollFrame:SetPoint("BOTTOMRIGHT", -14, 4)
    scrollFrame:SetClipsChildren(true)

    local content = CreateFrame("Frame", nil, scrollFrame)
    -- ScrollFrame's scroll child needs an explicit TOPLEFT anchor OR
    -- SetSize + SetScrollChild to position reliably. Without an anchor,
    -- a parent resize can reset the child's effective position and
    -- rows drawn at fixed y-offsets appear "orphaned" / invisible
    -- above or below the viewport.
    content:SetPoint("TOPLEFT", 0, 0)
    content:SetSize(1, 1)
    scrollFrame:SetScrollChild(content)
    scrollFrame:SetScript("OnSizeChanged", function(sf, w, _h)
        content:SetWidth(w)
        -- Recompute scroll bounds against the new viewport size; without
        -- this call Blizzard's internal scroll math keeps its old
        -- visible-range cache, and rows that were scrolled off-screen
        -- stay detached from the viewport even after the resize grows
        -- the scroll area large enough to show them.
        if sf.UpdateScrollChildRect then
            sf:UpdateScrollChildRect()
        end
        -- Reassert the current scroll offset so Blizzard clamps it
        -- against the new range (e.g. if the viewport grew enough that
        -- the content no longer needs scrolling, this pulls the offset
        -- back to 0). Deferred so the scroll-range cache from
        -- UpdateScrollChildRect settles first.
        if sf.SetVerticalScroll and sf.GetVerticalScroll then
            sf:SetVerticalScroll(sf:GetVerticalScroll() or 0)
        end
    end)

    if ns.ApplyThemedScrollBar then
        ns.ApplyThemedScrollBar(scrollFrame, {
            autoHide = true,
            showButtons = true,
            thickness = 10,
        })
    end

    local rowPool = CreateFramePool("Button", content, "BackdropTemplate", function(_p, row)
        row:Hide()
        row:ClearAllPoints()
        row:SetScript("OnEnter", nil)
        row:SetScript("OnLeave", nil)
        row:SetScript("OnClick", nil)
    end)

    local emptyText = container:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    emptyText:SetPoint("CENTER")
    emptyText:SetText(emptyMessage)
    applyTextColor(emptyText, "textSubtle", { 0.5, 0.5, 0.5 })
    emptyText:Hide()

    local list = {
        container = container,
        scrollFrame = scrollFrame,
        content = content,
        rowPool = rowPool,
        emptyText = emptyText,
        pixelBorder = pixelBorder,
        _rows = {},
        -- Every row ever acquired from the pool, in insertion order.
        -- Grown on Acquire, never shrunk. Used by :ApplyTheme to retint
        -- the backdrop of inactive (pool-idle) rows on skin change so
        -- they don't stick at the old color when reused.
        _allRows = {},
    }

    local function registerRow(self, row)
        if not row._registered then
            row._registered = true
            self._allRows[#self._allRows + 1] = row
        end
    end

    function list:Refresh(entries)
        -- Release all rows to the pool, then re-acquire as needed.
        for _, row in ipairs(self._rows) do
            self.rowPool:Release(row)
        end
        wipe(self._rows)

        local count = entries and #entries or 0
        if count == 0 then
            self.emptyText:Show()
            self.content:SetHeight(1)
            return
        end
        self.emptyText:Hide()

        local yOffset = 0
        for i, data in ipairs(entries) do
            local row = self.rowPool:Acquire()
            registerRow(self, row)
            row:SetHeight(rowHeight)
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", 2, -yOffset)
            row:SetPoint("TOPRIGHT", -2, -yOffset)
            if initRow and not row._initialized then
                initRow(row)
                row._initialized = true
            end
            if bindRow then bindRow(row, data, i) end
            row:Show()
            self._rows[#self._rows + 1] = row
            yOffset = yOffset + rowHeight + rowSpacing
        end
        self.content:SetHeight(math.max(1, yOffset))
        -- Force the ScrollFrame to re-query its scroll range so the themed
        -- scrollbar updates visibility/thumb size against the new content
        -- height. Without this, the first open of a long list sometimes
        -- shows no scrollbar until the user nudges the mousewheel.
        if self.scrollFrame.UpdateScrollChildRect then
            self.scrollFrame:UpdateScrollChildRect()
        end
    end

    function list:ApplyTheme()
        styleSurface(self.container, "inset")
        if self.pixelBorder then
            local c = skinColor("borderStrong", { 0, 0, 0, 1 })
            for _, tex in pairs(self.pixelBorder) do
                if type(tex) == "table" and type(tex.SetColorTexture) == "function" then
                    tex:SetColorTexture(c[1] or 0, c[2] or 0, c[3] or 0, c[4] or 1)
                end
            end
        end
        -- Retint every row's backdrop so skin / accent changes propagate
        -- to rows currently idle in the pool (which keep their old color
        -- until pool-released-and-reused, which may never happen).
        local rowColor = skinColor("rowAlt", { 0.06, 0.07, 0.1, 0.5 })
        for _, row in ipairs(self._allRows) do
            if row.SetBackdropColor then
                row:SetBackdropColor(
                    rowColor[1], rowColor[2], rowColor[3], rowColor[4] or 1)
            end
        end
    end

    return list
end

--[[--------------------------------------------------------------------
    History query helpers

    These walk Loothing.Settings:GetHistory-equivalent data (actually the
    in-memory data provider on Loothing.History) to aggregate what each
    profile modal needs. Kept simple; caller is always user-initiated.
----------------------------------------------------------------------]]

--- Iterate every history entry; accumulate to `out` if accept(entry) returns true.
local function collectEntries(accept)
    local out = {}
    if not Loothing.History or not Loothing.History.GetEntries then return out end
    for _, entry in Loothing.History:GetEntries():Enumerate() do
        if entry and (not accept or accept(entry)) then
            out[#out + 1] = entry
        end
    end
    -- Most recent first
    table.sort(out, function(a, b)
        return (a.timestamp or 0) > (b.timestamp or 0)
    end)
    return out
end

--- Session window: two history entries belong to the same "session" when
--- they share encounterID and their timestamps are within SESSION_WINDOW.
--- 2 hours is a safe upper bound for a single pull/lockout cluster.
local SESSION_WINDOW = 2 * 60 * 60

local function isSameSession(a, b)
    if not (a and b) then return false end
    if a.encounterID ~= b.encounterID then return false end
    local ta, tb = a.timestamp or 0, b.timestamp or 0
    if ta == 0 or tb == 0 then return false end
    return math.abs(ta - tb) <= SESSION_WINDOW
end

--[[======================================================================
    ITEM DETAIL MODAL
======================================================================]]

local function getDetailInstance()
    if detailInstance then return detailInstance end

    local modal = CreateModal("LoothingHistoryDetailFrame",
        ITEM_DETAIL_WIDTH, ITEM_DETAIL_HEIGHT,
        L("HISTORY_DETAIL_TITLE", "Loot Detail"))

    -- Header extras: item icon + quality border + encounter metadata
    local icon = modal.frame:CreateTexture(nil, "ARTWORK")
    icon:SetSize(36, 36)
    icon:SetPoint("TOPLEFT", 12, -14)
    modal.icon = icon

    local iconBorder = modal.frame:CreateTexture(nil, "OVERLAY")
    iconBorder:SetSize(38, 38)
    iconBorder:SetPoint("CENTER", icon, "CENTER")
    iconBorder:SetTexture("Interface\\Common\\WhiteIconFrame")
    modal.iconBorder = iconBorder

    -- Invisible clickable overlay over icon+title for itemlink tooltip + chat link
    local itemClick = CreateFrame("Button", nil, modal.frame)
    itemClick:SetPoint("TOPLEFT", 12, -10)
    itemClick:SetPoint("BOTTOMRIGHT", modal.frame, "TOPLEFT", 460, -(HEADER_HEIGHT - 2))
    itemClick:RegisterForClicks("LeftButtonUp")
    modal.itemClick = itemClick

    -- Re-anchor the title to the right of the icon (overrides CreateModal)
    modal.title:ClearAllPoints()
    modal.title:SetPoint("TOPLEFT", icon, "TOPRIGHT", 10, -2)
    modal.subtitle:ClearAllPoints()
    modal.subtitle:SetPoint("TOPLEFT", modal.title, "BOTTOMLEFT", 0, -2)

    -- Header quick-nav row: View Session / View Raid / View Boss. Each
    -- is hidden until Bind determines the entry has the required scope
    -- context (encounter + timestamp for Session, instance for Raid,
    -- encounterName for Boss).
    local sessionLink = ns.CreateThemedButton(modal.frame)
    sessionLink:SetSize(110, 20)
    sessionLink:SetPoint("TOPRIGHT", modal.closeBtn, "TOPLEFT", -4, -2)
    sessionLink:SetText(L("HISTORY_DETAIL_VIEW_SESSION", "View Session"))
    styleButton(sessionLink, "ghost")
    modal.sessionLinkBtn = sessionLink

    local raidLink = ns.CreateThemedButton(modal.frame)
    raidLink:SetSize(100, 20)
    raidLink:SetPoint("TOPRIGHT", sessionLink, "TOPLEFT", -4, 0)
    raidLink:SetText(L("HISTORY_DETAIL_VIEW_RAID", "View Raid"))
    styleButton(raidLink, "ghost")
    modal.raidLinkBtn = raidLink

    local bossLink = ns.CreateThemedButton(modal.frame)
    bossLink:SetSize(100, 20)
    bossLink:SetPoint("TOPRIGHT", raidLink, "TOPLEFT", -4, 0)
    bossLink:SetText(L("HISTORY_DETAIL_VIEW_BOSS", "View Boss"))
    styleButton(bossLink, "ghost")
    modal.bossLinkBtn = bossLink

    -- Tab strip
    local tabArea = CreateFrame("Frame", nil, modal.frame)
    tabArea:SetPoint("TOPLEFT", 10, -(HEADER_HEIGHT + 2))
    tabArea:SetPoint("TOPRIGHT", -10, -(HEADER_HEIGHT + 2))
    tabArea:SetHeight(TAB_HEIGHT + 6)
    modal.tabArea = tabArea

    local tabDefs = {
        { id = "overview",   text = L("HISTORY_DETAIL_TAB_OVERVIEW",   "Overview") },
        { id = "candidates", text = L("HISTORY_DETAIL_TAB_CANDIDATES", "Candidates") },
        { id = "votes",      text = L("HISTORY_DETAIL_TAB_VOTES",      "Council Votes") },
    }
    modal.tabStrip = CreateTabStrip(tabArea, tabDefs, function(tabId)
        modal:ShowTab(tabId)
    end)

    -- Content area below tab strip
    local contentArea = CreateFrame("Frame", nil, modal.frame)
    contentArea:SetPoint("TOPLEFT", tabArea, "BOTTOMLEFT", 0, -4)
    contentArea:SetPoint("BOTTOMRIGHT", -10, FOOTER_HEIGHT + 4)
    modal.contentArea = contentArea

    -- Tab panel: Overview (fixed layout)
    local overview = CreateFrame("Frame", nil, contentArea, "BackdropTemplate")
    overview:SetAllPoints()
    styleSurface(overview, "inset")
    overview:Hide()
    modal.overviewPanel = overview

    -- Overview fields
    local function mkLabel(text, fontKey, colorKey)
        local fs = overview:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        fs:SetJustifyH("LEFT")
        if SkinningMixin and SkinningMixin.StyleText then
            SkinningMixin:StyleText(fs, fontKey or "body", colorKey or "text")
        end
        fs:SetText(text or "")
        return fs
    end

    modal.ov = {}
    local pad = 16
    local col1X, col2X = pad, 320
    local rowY = -pad

    modal.ov.winnerHeader = mkLabel(L("HISTORY_DETAIL_WINNER", "Winner"), "bodySmall", "textMuted")
    modal.ov.winnerHeader:SetPoint("TOPLEFT", col1X, rowY)
    modal.ov.winnerText = mkLabel("", "title", "text")
    modal.ov.winnerText:SetPoint("TOPLEFT", col1X, rowY - 16)

    modal.ov.responseHeader = mkLabel(L("HISTORY_DETAIL_RESPONSE", "Response"), "bodySmall", "textMuted")
    modal.ov.responseHeader:SetPoint("TOPLEFT", col2X, rowY)
    modal.ov.responseText = mkLabel("", "header", "text")
    modal.ov.responseText:SetPoint("TOPLEFT", col2X, rowY - 16)

    rowY = rowY - 52

    modal.ov.rollHeader = mkLabel(L("HISTORY_DETAIL_ROLL", "Roll"), "bodySmall", "textMuted")
    modal.ov.rollHeader:SetPoint("TOPLEFT", col1X, rowY)
    modal.ov.rollText = mkLabel("", "header", "text")
    modal.ov.rollText:SetPoint("TOPLEFT", col1X, rowY - 16)

    modal.ov.ilvlDiffHeader = mkLabel(L("HISTORY_DETAIL_ILVL_DIFF", "Item Level Difference"), "bodySmall", "textMuted")
    modal.ov.ilvlDiffHeader:SetPoint("TOPLEFT", col2X, rowY)
    modal.ov.ilvlDiffText = mkLabel("", "header", "text")
    modal.ov.ilvlDiffText:SetPoint("TOPLEFT", col2X, rowY - 16)

    rowY = rowY - 52

    modal.ov.gearHeader = mkLabel(L("HISTORY_DETAIL_EQUIPPED_GEAR", "Equipped Gear (at time of roll)"), "bodySmall", "textMuted")
    modal.ov.gearHeader:SetPoint("TOPLEFT", col1X, rowY)

    local gear1Btn = CreateFrame("Button", nil, overview)
    gear1Btn:SetPoint("TOPLEFT", col1X, rowY - 16)
    gear1Btn:SetSize(290, 20)
    gear1Btn.text = gear1Btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    gear1Btn.text:SetAllPoints()
    gear1Btn.text:SetJustifyH("LEFT")
    gear1Btn.text:SetWordWrap(false)
    -- HIGHLIGHT-layer backdrop tint so the gear link reads as hoverable.
    do
        local gearHl = gear1Btn:CreateTexture(nil, "HIGHLIGHT")
        gearHl:SetAllPoints()
        gearHl:SetColorTexture(1, 1, 1, 0.08)
    end
    addClickableUnderline(gear1Btn)
    modal.ov.gear1Btn = gear1Btn

    local gear2Btn = CreateFrame("Button", nil, overview)
    gear2Btn:SetPoint("TOPLEFT", col1X, rowY - 36)
    gear2Btn:SetSize(290, 20)
    gear2Btn.text = gear2Btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    gear2Btn.text:SetAllPoints()
    gear2Btn.text:SetJustifyH("LEFT")
    gear2Btn.text:SetWordWrap(false)
    do
        local gearHl = gear2Btn:CreateTexture(nil, "HIGHLIGHT")
        gearHl:SetAllPoints()
        gearHl:SetColorTexture(1, 1, 1, 0.08)
    end
    addClickableUnderline(gear2Btn)
    modal.ov.gear2Btn = gear2Btn

    rowY = rowY - 76

    modal.ov.reasonHeader = mkLabel(L("HISTORY_DETAIL_AWARD_REASON", "Award Reason"), "bodySmall", "textMuted")
    modal.ov.reasonHeader:SetPoint("TOPLEFT", col1X, rowY)
    modal.ov.reasonText = mkLabel("", "body", "text")
    modal.ov.reasonText:SetPoint("TOPLEFT", col1X, rowY - 16)

    rowY = rowY - 40

    modal.ov.noteHeader = mkLabel(L("HISTORY_DETAIL_WINNER_NOTE", "Winner Note"), "bodySmall", "textMuted")
    modal.ov.noteHeader:SetPoint("TOPLEFT", col1X, rowY)
    modal.ov.noteText = mkLabel("", "body", "textMuted")
    modal.ov.noteText:SetPoint("TOPLEFT", col1X, rowY - 16)
    modal.ov.noteText:SetPoint("RIGHT", overview, "RIGHT", -pad, 0)
    modal.ov.noteText:SetJustifyH("LEFT")
    modal.ov.noteText:SetWordWrap(true)

    rowY = rowY - 40

    modal.ov.mlNoteHeader = mkLabel(L("HISTORY_DETAIL_LOOTER", "Looter / Item Owner"), "bodySmall", "textMuted")
    modal.ov.mlNoteHeader:SetPoint("TOPLEFT", col1X, rowY)
    modal.ov.mlNoteText = mkLabel("", "body", "text")
    modal.ov.mlNoteText:SetPoint("TOPLEFT", col1X, rowY - 16)

    modal.ov.votesHeader = mkLabel(L("HISTORY_DETAIL_TOTAL_VOTES", "Council Votes Cast"), "bodySmall", "textMuted")
    modal.ov.votesHeader:SetPoint("TOPLEFT", col2X, rowY)
    modal.ov.votesText = mkLabel("", "header", "text")
    modal.ov.votesText:SetPoint("TOPLEFT", col2X, rowY - 16)

    -- Tab panel: Candidates (scrolling list)
    local candPanel = CreateFrame("Frame", nil, contentArea)
    candPanel:SetAllPoints()
    candPanel:Hide()
    modal.candPanel = candPanel

    local candHeader = CreateFrame("Frame", nil, candPanel)
    candHeader:SetPoint("TOPLEFT", 0, 0)
    candHeader:SetPoint("TOPRIGHT", 0, 0)
    candHeader:SetHeight(22)
    local function mkHeader(parent, text, xOff, width)
        local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        fs:SetPoint("LEFT", xOff, 0)
        fs:SetWidth(width)
        fs:SetJustifyH("LEFT")
        applyTextColor(fs, "textMuted", { 0.66, 0.70, 0.79 })
        fs:SetText(text)
        return fs
    end
    mkHeader(candHeader, L("HISTORY_DETAIL_COL_PLAYER",   "Player"),   8,   140)
    mkHeader(candHeader, L("HISTORY_DETAIL_COL_RESPONSE", "Response"), 160, 90)
    mkHeader(candHeader, L("HISTORY_DETAIL_COL_ROLL",     "Roll"),     256, 40)
    mkHeader(candHeader, L("HISTORY_DETAIL_COL_ILVL",     "iLvl Δ"),   302, 50)
    mkHeader(candHeader, L("HISTORY_DETAIL_COL_VOTES",    "Votes"),    360, 40)
    mkHeader(candHeader, L("HISTORY_DETAIL_COL_NOTE",     "Note"),     410, 260)

    local candList = CreateScrollList(candPanel, {
        rowHeight = CANDIDATE_ROW_HEIGHT,
        rowSpacing = 1,
        emptyMessage = L("HISTORY_DETAIL_NO_CANDIDATES",
            "No candidate data captured for this entry.\n(Entry predates the candidate snapshot feature.)"),
        initRow = function(row)
            row:SetBackdrop({
                bgFile = "Interface\\Buttons\\WHITE8x8",
                tile = false, edgeSize = 0,
                insets = { left = 0, right = 0, top = 0, bottom = 0 },
            })
            row:SetBackdropColor(unpack(skinColor("rowAlt", { 0.06, 0.07, 0.1, 0.5 })))

            local hl = row:CreateTexture(nil, "HIGHLIGHT")
            hl:SetAllPoints()
            hl:SetColorTexture(1, 1, 1, 0.08)
            addRowHoverAccent(row)

            row.nameBtn = CreateFrame("Button", nil, row)
            row.nameBtn:SetPoint("LEFT", 8, 0)
            row.nameBtn:SetSize(140, CANDIDATE_ROW_HEIGHT)
            row.nameBtn.text = row.nameBtn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            row.nameBtn.text:SetPoint("LEFT")
            row.nameBtn.text:SetPoint("RIGHT")
            row.nameBtn.text:SetJustifyH("LEFT")
            row.nameBtn.text:SetWordWrap(false)
            addClickableUnderline(row.nameBtn)

            row.responseText = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            row.responseText:SetPoint("LEFT", 160, 0)
            row.responseText:SetWidth(90)
            row.responseText:SetJustifyH("LEFT")
            row.responseText:SetWordWrap(false)

            row.rollText = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            row.rollText:SetPoint("LEFT", 256, 0)
            row.rollText:SetWidth(40)
            row.rollText:SetJustifyH("LEFT")

            row.ilvlDiffText = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            row.ilvlDiffText:SetPoint("LEFT", 302, 0)
            row.ilvlDiffText:SetWidth(50)
            row.ilvlDiffText:SetJustifyH("LEFT")

            row.votesText = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            row.votesText:SetPoint("LEFT", 360, 0)
            row.votesText:SetWidth(40)
            row.votesText:SetJustifyH("LEFT")

            row.noteText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            row.noteText:SetPoint("LEFT", 410, 0)
            row.noteText:SetPoint("RIGHT", -6, 0)
            row.noteText:SetJustifyH("LEFT")
            row.noteText:SetWordWrap(false)
            applyTextColor(row.noteText, "textMuted", { 0.66, 0.70, 0.79 })
        end,
        bindRow = function(row, data)
            row.nameBtn.text:SetText(classColoredName(data.playerName, data.playerClass))
            -- Clicking the row name opens the candidate profile. If the
            -- candidate has no player name for any reason, mark the
            -- button inert so the underline doesn't advertise a click
            -- that does nothing.
            local pname = data.playerName
            if pname then
                row.nameBtn:SetScript("OnClick", function()
                    ns.ShowCandidateProfile(pname)
                end)
                row.nameBtn:SetScript("OnEnter", function()
                    GameTooltip:SetOwner(row.nameBtn, "ANCHOR_RIGHT")
                    GameTooltip:AddLine(Utils.GetShortName(pname) or pname)
                    GameTooltip:AddLine(L("HISTORY_DETAIL_OPEN_PROFILE_HINT", "Click to view player profile"), 0.8, 0.8, 0.8)
                    GameTooltip:Show()
                end)
                row.nameBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
                setButtonClickable(row.nameBtn, true)
            else
                row.nameBtn:SetScript("OnClick", nil)
                row.nameBtn:SetScript("OnEnter", nil)
                row.nameBtn:SetScript("OnLeave", nil)
                setButtonClickable(row.nameBtn, false)
            end

            row.responseText:SetText(responseColoredText(data.response) or data.responseText or "")

            if data.roll and data.roll > 0 then
                row.rollText:SetText(tostring(data.roll))
                applyTextColor(row.rollText, "text")
            else
                row.rollText:SetText("—")
                applyTextColor(row.rollText, "textSubtle", { 0.5, 0.5, 0.5 })
            end

            if data.ilvlDiff and data.ilvlDiff ~= 0 then
                local prefix = data.ilvlDiff > 0 and "+" or ""
                row.ilvlDiffText:SetText(prefix .. tostring(data.ilvlDiff))
                if data.ilvlDiff > 0 then
                    applyTextColor(row.ilvlDiffText, "success", { 0.3, 0.8, 0.5 })
                else
                    applyTextColor(row.ilvlDiffText, "danger", { 0.85, 0.4, 0.4 })
                end
            else
                row.ilvlDiffText:SetText("—")
                applyTextColor(row.ilvlDiffText, "textSubtle", { 0.5, 0.5, 0.5 })
            end

            local votes = data.councilVotes or 0
            row.votesText:SetText(votes > 0 and tostring(votes) or "—")

            row.noteText:SetText(data.note or "")

            -- Hover shows gear tooltip (combined gear1 + gear2)
            local gear1, gear2 = data.gear1Link, data.gear2Link
            row:SetScript("OnEnter", function(r)
                if not (gear1 or gear2) then return end
                GameTooltip:SetOwner(r, "ANCHOR_RIGHT")
                GameTooltip:AddLine(L("HISTORY_DETAIL_EQUIPPED_AT_ROLL", "Equipped at time of roll"), 1, 0.82, 0)
                if gear1 then
                    GameTooltip:AddLine(gear1)
                end
                if gear2 then
                    GameTooltip:AddLine(gear2)
                end
                GameTooltip:Show()
            end)
            row:SetScript("OnLeave", function() GameTooltip:Hide() end)
        end,
    })
    candList.container:SetPoint("TOPLEFT", candHeader, "BOTTOMLEFT", 0, -2)
    candList.container:SetPoint("BOTTOMRIGHT", 0, 0)
    modal.candList = candList

    -- Tab panel: Council Votes
    local votesPanel = CreateFrame("Frame", nil, contentArea)
    votesPanel:SetAllPoints()
    votesPanel:Hide()
    modal.votesPanel = votesPanel

    local votesHeader = CreateFrame("Frame", nil, votesPanel)
    votesHeader:SetPoint("TOPLEFT", 0, 0)
    votesHeader:SetPoint("TOPRIGHT", 0, 0)
    votesHeader:SetHeight(22)
    mkHeader(votesHeader, L("HISTORY_DETAIL_COL_VOTER",      "Voter"),        8,   140)
    mkHeader(votesHeader, L("HISTORY_DETAIL_COL_PICKS",      "Picks (Ranked)"), 160, 300)
    mkHeader(votesHeader, L("HISTORY_DETAIL_COL_VOTER_NOTE", "Note"),         466, 220)

    local votesList = CreateScrollList(votesPanel, {
        rowHeight = ROW_HEIGHT,
        rowSpacing = 1,
        emptyMessage = L("HISTORY_DETAIL_NO_COUNCIL_VOTES",
            "No council votes were cast on this item (or the entry predates the voter snapshot feature)."),
        initRow = function(row)
            row:SetBackdrop({
                bgFile = "Interface\\Buttons\\WHITE8x8",
                tile = false, edgeSize = 0,
                insets = { left = 0, right = 0, top = 0, bottom = 0 },
            })
            row:SetBackdropColor(unpack(skinColor("rowAlt", { 0.06, 0.07, 0.1, 0.5 })))

            local hl = row:CreateTexture(nil, "HIGHLIGHT")
            hl:SetAllPoints()
            hl:SetColorTexture(1, 1, 1, 0.08)
            addRowHoverAccent(row)

            row.nameBtn = CreateFrame("Button", nil, row)
            row.nameBtn:SetPoint("LEFT", 8, 0)
            row.nameBtn:SetSize(140, ROW_HEIGHT)
            row.nameBtn.text = row.nameBtn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            row.nameBtn.text:SetAllPoints()
            row.nameBtn.text:SetJustifyH("LEFT")
            row.nameBtn.text:SetWordWrap(false)
            addClickableUnderline(row.nameBtn)

            row.picksText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            row.picksText:SetPoint("LEFT", 160, 0)
            row.picksText:SetWidth(300)
            row.picksText:SetJustifyH("LEFT")
            row.picksText:SetWordWrap(false)

            row.voterNote = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            row.voterNote:SetPoint("LEFT", 466, 0)
            row.voterNote:SetPoint("RIGHT", -6, 0)
            row.voterNote:SetJustifyH("LEFT")
            row.voterNote:SetWordWrap(false)
            applyTextColor(row.voterNote, "textMuted", { 0.66, 0.70, 0.79 })
        end,
        bindRow = function(row, data)
            row.nameBtn.text:SetText(classColoredName(data.voter, data.voterClass))
            local vname = data.voter
            if vname then
                row.nameBtn:SetScript("OnClick", function()
                    ns.ShowVoterProfile(vname)
                end)
                row.nameBtn:SetScript("OnEnter", function()
                    GameTooltip:SetOwner(row.nameBtn, "ANCHOR_RIGHT")
                    GameTooltip:AddLine(Utils.GetShortName(vname) or vname)
                    GameTooltip:AddLine(L("HISTORY_DETAIL_OPEN_VOTER_HINT", "Click to view voter profile"), 0.8, 0.8, 0.8)
                    GameTooltip:Show()
                end)
                row.nameBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
                setButtonClickable(row.nameBtn, true)
            else
                row.nameBtn:SetScript("OnClick", nil)
                row.nameBtn:SetScript("OnEnter", nil)
                row.nameBtn:SetScript("OnLeave", nil)
                setButtonClickable(row.nameBtn, false)
            end

            -- `data.responses` is an array of numeric response IDs (the
            -- voter's ranked preference across Need/Greed/OS/etc). Render
            -- each as the response's colored name. Strings are a legacy
            -- / remote-sync shape and render verbatim.
            local picks = "—"
            if data.responses and #data.responses > 0 then
                local parts = {}
                for i, r in ipairs(data.responses) do
                    if type(r) == "number" then
                        parts[#parts + 1] = string.format("%d. %s", i, responseColoredText(r))
                    elseif type(r) == "string" then
                        parts[#parts + 1] = string.format("%d. %s", i, r)
                    end
                end
                picks = table.concat(parts, "  ")
            end
            row.picksText:SetText(picks)
            row.voterNote:SetText(data.note or "")
        end,
    })
    votesList.container:SetPoint("TOPLEFT", votesHeader, "BOTTOMLEFT", 0, -2)
    votesList.container:SetPoint("BOTTOMRIGHT", 0, 0)
    modal.votesList = votesList

    -- Footer buttons
    local linkBtn = ns.CreateThemedButton(modal.footer)
    linkBtn:SetSize(120, 24)
    linkBtn:SetPoint("LEFT")
    linkBtn:SetText(L("HISTORY_DETAIL_LINK_IN_CHAT", "Link in Chat"))
    styleButton(linkBtn, "ghost")
    modal.linkBtn = linkBtn

    local closeFooterBtn = ns.CreateThemedButton(modal.footer)
    closeFooterBtn:SetSize(100, 24)
    closeFooterBtn:SetPoint("RIGHT")
    closeFooterBtn:SetText(L("HISTORY_DETAIL_CLOSE", "Close"))
    styleButton(closeFooterBtn, "primary")
    closeFooterBtn:SetScript("OnClick", function() modal:Hide() end)

    --- Switch visible tab panel.
    function modal:ShowTab(tabId)
        self.overviewPanel:Hide()
        self.candPanel:Hide()
        self.votesPanel:Hide()
        if tabId == "overview" then
            self.overviewPanel:Show()
        elseif tabId == "candidates" then
            self.candPanel:Show()
        elseif tabId == "votes" then
            self.votesPanel:Show()
        end
    end

    --- Bind the currently-loaded entry to the UI.
    function modal:Bind(entry)
        self.entry = entry
        if not entry then return end

        -- Title & subtitle
        local titleStr = entry.itemName or entry.itemLink or L("HISTORY_DETAIL_UNKNOWN_ITEM", "Unknown item")
        self:SetTitle(titleStr)
        local parts = {}
        if entry.encounterName then parts[#parts + 1] = entry.encounterName end
        if entry.difficultyName then parts[#parts + 1] = entry.difficultyName end
        if entry.instance then parts[#parts + 1] = entry.instance end
        if entry.timestamp and entry.timestamp > 0 then
            parts[#parts + 1] = Utils.FormatDate(entry.timestamp)
        end
        self:SetSubtitle(table.concat(parts, "   •   "))

        -- Item icon + quality border
        local texture = entry.itemID and C_Item.GetItemIconByID(entry.itemID)
            or "Interface\\Icons\\INV_Misc_QuestionMark"
        self.icon:SetTexture(texture)
        local qr, qg, qb = qualityColor(entry.quality, entry.itemLink)
        self.iconBorder:SetVertexColor(qr, qg, qb)

        -- Clickable area = item tooltip + shift-click to link. Route
        -- through insertChatText so the chat edit box opens if it wasn't
        -- already (ChatEdit_InsertLink silently no-ops when no edit box
        -- is focused).
        self.itemClick:SetScript("OnClick", function()
            if entry.itemLink and IsShiftKeyDown() then
                insertChatText(entry.itemLink)
            end
        end)
        attachItemTooltip(self.itemClick, entry.itemLink)

        -- Header quick-nav row: each button shows only when the entry
        -- has the scope context needed to drill into that summary modal.
        if entry.encounterID and entry.timestamp then
            self.sessionLinkBtn:Show()
            self.sessionLinkBtn:SetScript("OnClick", function()
                ns.ShowSessionSummary(entry)
            end)
        else
            self.sessionLinkBtn:Hide()
        end

        if entry.instance and entry.instance ~= "" then
            self.raidLinkBtn:Show()
            local instance = entry.instance
            self.raidLinkBtn:SetScript("OnClick", function()
                ns.ShowRaidSummary(instance)
            end)
        else
            self.raidLinkBtn:Hide()
        end

        if entry.encounterName and entry.encounterName ~= "" then
            self.bossLinkBtn:Show()
            local encounter, instance = entry.encounterName, entry.instance
            self.bossLinkBtn:SetScript("OnClick", function()
                ns.ShowBossSummary(encounter, instance)
            end)
        else
            self.bossLinkBtn:Hide()
        end

        -- Footer link button: inserts the item link into the chat edit box,
        -- opening chat first if needed. (Custom cross-user history hyperlinks
        -- don't survive WoW's outgoing chat sanitizer, so we stick with the
        -- plain item link — peers see the normal item tooltip.)
        self.linkBtn:SetScript("OnClick", function()
            if entry.itemLink then
                insertChatText(entry.itemLink)
            end
        end)
        self.linkBtn:SetEnabled(entry.itemLink ~= nil)

        -- Overview fields
        self.ov.winnerText:SetText(classColoredName(entry.winner, entry.winnerClass))
        self.ov.responseText:SetText(responseColoredText(getWinnerResponse(entry))
            or entry.winnerResponseText or entry.response or "—")

        if entry.winnerRoll and entry.winnerRoll > 0 then
            self.ov.rollText:SetText(tostring(entry.winnerRoll))
            applyTextColor(self.ov.rollText, "text")
        else
            self.ov.rollText:SetText("—")
            applyTextColor(self.ov.rollText, "textSubtle", { 0.5, 0.5, 0.5 })
        end

        local diff = entry.winnerIlvlDiff
        if diff and diff ~= 0 then
            local prefix = diff > 0 and "+" or ""
            self.ov.ilvlDiffText:SetText(prefix .. tostring(diff))
            if diff > 0 then
                applyTextColor(self.ov.ilvlDiffText, "success", { 0.3, 0.8, 0.5 })
            else
                applyTextColor(self.ov.ilvlDiffText, "danger", { 0.85, 0.4, 0.4 })
            end
        else
            self.ov.ilvlDiffText:SetText("—")
            applyTextColor(self.ov.ilvlDiffText, "textSubtle", { 0.5, 0.5, 0.5 })
        end

        -- Gear buttons. When the winner didn't have anything in the slot
        -- there's nothing to tooltip or link — mark the button inert so
        -- the hover underline + HIGHLIGHT wash don't advertise a click
        -- that does nothing.
        local function bindGearBtn(btn, link, ilvl)
            if link then
                local suffix = ilvl and ilvl > 0 and string.format("  |cff888888(%d)|r", ilvl) or ""
                btn.text:SetText(link .. suffix)
                btn:Show()
                attachItemTooltip(btn, link)
                btn:SetScript("OnClick", nil)
                setButtonClickable(btn, true)
            else
                btn.text:SetText("|cff666666" .. L("HISTORY_DETAIL_NO_GEAR_SLOT", "(empty slot)") .. "|r")
                btn:SetScript("OnEnter", nil)
                btn:SetScript("OnLeave", nil)
                btn:SetScript("OnClick", nil)
                setButtonClickable(btn, false)
            end
        end
        bindGearBtn(self.ov.gear1Btn, entry.winnerGear1, entry.winnerGear1ilvl)
        bindGearBtn(self.ov.gear2Btn, entry.winnerGear2, entry.winnerGear2ilvl)

        self.ov.reasonText:SetText(entry.awardReason or L("HISTORY_DETAIL_NO_REASON", "(no reason recorded)"))
        self.ov.noteText:SetText(entry.winnerNote and entry.winnerNote ~= "" and entry.winnerNote
            or "|cff666666" .. L("HISTORY_DETAIL_NO_NOTE", "(no note)") .. "|r")
        self.ov.mlNoteText:SetText(entry.owner and (Utils.GetShortName(entry.owner) or entry.owner)
            or L("HISTORY_DETAIL_NO_OWNER", "—"))
        self.ov.votesText:SetText(tostring(entry.votes or 0))

        -- Bind lists
        self.candList:Refresh(entry.candidates or {})
        self.votesList:Refresh(entry.councilVotes or {})

        -- Open on Overview by default. Force the tab switch even if the
        -- last-open tab was "overview" already (otherwise SelectTab's
        -- early-return skips the indicator snap and it stays parked under
        -- whichever tab the user last clicked on a prior session).
        self.tabStrip.currentId = nil
        self.tabStrip:SelectTab("overview")
        -- Snap indicator after a frame so GetLeft() has settled
        C_Timer.After(0, function()
            if not self.frame or not self.frame:IsVisible() then return end
            if self.tabStrip then self.tabStrip:Refresh() end
        end)
    end

    --- Extend ApplyTheme to re-paint inner content.
    local baseApplyTheme = modal.ApplyTheme
    function modal:ApplyTheme()
        baseApplyTheme(self)
        self.iconBorder:SetTexture("Interface\\Common\\WhiteIconFrame")
        styleSurface(self.overviewPanel, "inset")
        if self.tabStrip then self.tabStrip:Refresh() end
        if self.candList then self.candList:ApplyTheme() end
        if self.votesList then self.votesList:ApplyTheme() end
        styleButton(self.linkBtn, "ghost")
        styleButton(self.sessionLinkBtn, "ghost")
        styleButton(self.raidLinkBtn, "ghost")
        styleButton(self.bossLinkBtn, "ghost")
        styleButton(closeFooterBtn, "primary")
        -- Re-apply overview text colors so skin changes propagate
        applyTextColor(self.ov.winnerHeader, "textMuted")
        applyTextColor(self.ov.responseHeader, "textMuted")
        applyTextColor(self.ov.rollHeader, "textMuted")
        applyTextColor(self.ov.ilvlDiffHeader, "textMuted")
        applyTextColor(self.ov.gearHeader, "textMuted")
        applyTextColor(self.ov.reasonHeader, "textMuted")
        applyTextColor(self.ov.noteHeader, "textMuted")
        applyTextColor(self.ov.mlNoteHeader, "textMuted")
        applyTextColor(self.ov.votesHeader, "textMuted")
    end

    --- Drop stale references when the modal is hidden — Escape, combat,
    --- manual close, parent teardown — so a lingering `entry` table from
    --- a deleted history row doesn't stay pinned in closure.
    function modal:OnHideCleanup()
        self.entry = nil
        if self.linkBtn then self.linkBtn:SetScript("OnClick", nil) end
        if self.sessionLinkBtn then self.sessionLinkBtn:SetScript("OnClick", nil) end
        if self.raidLinkBtn then self.raidLinkBtn:SetScript("OnClick", nil) end
        if self.bossLinkBtn then self.bossLinkBtn:SetScript("OnClick", nil) end
        if self.itemClick then self.itemClick:SetScript("OnClick", nil) end
    end

    -- Close the modal if the entry it's showing gets deleted out from under
    -- it (e.g. user right-clicks Delete in the history panel).
    if Loothing.History and Loothing.History.RegisterCallback then
        Loothing.History:RegisterCallback("OnEntryRemoved", function(_, removed)
            if not removed then return end
            if modal.entry and modal.entry == removed and modal:IsShown() then
                modal:Hide()
            end
        end, modal)
    end

    detailInstance = modal
    return modal
end

--- Open the item detail modal for a single history entry.
--- @param entry table  A history entry (with candidates[] / councilVotes[] snapshots)
function ns.ShowHistoryDetail(entry)
    if not entry then return end
    local modal = getDetailInstance()
    modal:Bind(entry)
    modal:Show()
end

--[[======================================================================
    SESSION SUMMARY MODAL

    Lists every history entry that shares encounterID + timestamp
    proximity with the seed entry. Row click drills into the Item Detail.
======================================================================]]

local function getSummaryInstance()
    if summaryInstance then return summaryInstance end

    local modal = CreateModal("LoothingSessionSummaryFrame",
        SESSION_SUMMARY_WIDTH, SESSION_SUMMARY_HEIGHT,
        L("HISTORY_DETAIL_SESSION_TITLE", "Session Summary"))

    -- Header quick-nav row mirrors Item Detail: jump to the same pull's
    -- raid or boss summary without closing this modal.
    local raidLink = ns.CreateThemedButton(modal.frame)
    raidLink:SetSize(100, 20)
    raidLink:SetPoint("TOPRIGHT", modal.closeBtn, "TOPLEFT", -4, -2)
    raidLink:SetText(L("HISTORY_DETAIL_VIEW_RAID", "View Raid"))
    styleButton(raidLink, "ghost")
    modal.raidLinkBtn = raidLink

    local bossLink = ns.CreateThemedButton(modal.frame)
    bossLink:SetSize(100, 20)
    bossLink:SetPoint("TOPRIGHT", raidLink, "TOPLEFT", -4, 0)
    bossLink:SetText(L("HISTORY_DETAIL_VIEW_BOSS", "View Boss"))
    styleButton(bossLink, "ghost")
    modal.bossLinkBtn = bossLink

    local header = CreateFrame("Frame", nil, modal.content)
    header:SetPoint("TOPLEFT", 0, 0)
    header:SetPoint("TOPRIGHT", 0, 0)
    header:SetHeight(22)
    local function mkHeader(text, xOff, width)
        local fs = header:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        fs:SetPoint("LEFT", xOff, 0)
        fs:SetWidth(width)
        fs:SetJustifyH("LEFT")
        applyTextColor(fs, "textMuted", { 0.66, 0.70, 0.79 })
        fs:SetText(text)
        return fs
    end
    mkHeader(L("HISTORY_DETAIL_COL_ITEM",     "Item"),     8,   240)
    mkHeader(L("HISTORY_DETAIL_COL_WINNER",   "Winner"),   260, 140)
    mkHeader(L("HISTORY_DETAIL_COL_RESPONSE", "Response"), 406, 90)
    mkHeader(L("HISTORY_DETAIL_COL_ROLL",     "Roll"),     500, 40)

    local list = CreateScrollList(modal.content, {
        rowHeight = CANDIDATE_ROW_HEIGHT,
        rowSpacing = 1,
        emptyMessage = L("HISTORY_DETAIL_NO_SESSION_ITEMS",
            "No other items from this session were found."),
        initRow = function(row)
            row:SetBackdrop({
                bgFile = "Interface\\Buttons\\WHITE8x8",
                tile = false, edgeSize = 0,
                insets = { left = 0, right = 0, top = 0, bottom = 0 },
            })
            row:SetBackdropColor(unpack(skinColor("rowAlt", { 0.06, 0.07, 0.1, 0.5 })))
            local hl = row:CreateTexture(nil, "HIGHLIGHT")
            hl:SetAllPoints()
            hl:SetColorTexture(1, 1, 1, 0.08)
            addRowHoverAccent(row)

            row.icon = row:CreateTexture(nil, "ARTWORK")
            row.icon:SetSize(24, 24)
            row.icon:SetPoint("LEFT", 8, 0)

            row.iconBorder = row:CreateTexture(nil, "OVERLAY")
            row.iconBorder:SetSize(26, 26)
            row.iconBorder:SetPoint("CENTER", row.icon, "CENTER")
            row.iconBorder:SetTexture("Interface\\Common\\WhiteIconFrame")

            row.itemText = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            row.itemText:SetPoint("LEFT", row.icon, "RIGHT", 8, 0)
            row.itemText:SetWidth(200)
            row.itemText:SetJustifyH("LEFT")
            row.itemText:SetWordWrap(false)

            row.winnerText = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            row.winnerText:SetPoint("LEFT", 260, 0)
            row.winnerText:SetWidth(140)
            row.winnerText:SetJustifyH("LEFT")
            row.winnerText:SetWordWrap(false)

            row.responseText = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            row.responseText:SetPoint("LEFT", 406, 0)
            row.responseText:SetWidth(90)
            row.responseText:SetJustifyH("LEFT")
            row.responseText:SetWordWrap(false)

            row.rollText = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            row.rollText:SetPoint("LEFT", 500, 0)
            row.rollText:SetWidth(40)
            row.rollText:SetJustifyH("LEFT")

            row:RegisterForClicks("LeftButtonUp")
        end,
        bindRow = function(row, entry)
            local tex = entry.itemID and C_Item.GetItemIconByID(entry.itemID)
                or "Interface\\Icons\\INV_Misc_QuestionMark"
            row.icon:SetTexture(tex)
            local qr, qg, qb = qualityColor(entry.quality, entry.itemLink)
            row.iconBorder:SetVertexColor(qr, qg, qb)
            row.itemText:SetText(entry.itemName or entry.itemLink or "?")
            row.itemText:SetTextColor(qr, qg, qb)
            row.winnerText:SetText(classColoredName(entry.winner, entry.winnerClass))
            row.responseText:SetText(responseColoredText(getWinnerResponse(entry)) or entry.response or "—")
            if entry.winnerRoll and entry.winnerRoll > 0 then
                row.rollText:SetText(tostring(entry.winnerRoll))
            else
                row.rollText:SetText("—")
            end
            row:SetScript("OnEnter", function(r)
                GameTooltip:SetOwner(r, "ANCHOR_RIGHT")
                if entry.itemLink then
                    GameTooltip:SetHyperlink(entry.itemLink)
                end
                GameTooltip:AddLine(" ")
                GameTooltip:AddLine(L("HISTORY_DETAIL_CLICK_FOR_DETAILS", "Click for full details"), 0.8, 0.8, 0.8)
                GameTooltip:Show()
            end)
            row:SetScript("OnLeave", function() GameTooltip:Hide() end)
            row:SetScript("OnClick", function()
                ns.ShowHistoryDetail(entry)
            end)
        end,
    })
    list.container:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -2)
    list.container:SetPoint("BOTTOMRIGHT", 0, 0)
    modal.list = list

    local closeFooterBtn = ns.CreateThemedButton(modal.footer)
    closeFooterBtn:SetSize(100, 24)
    closeFooterBtn:SetPoint("RIGHT")
    closeFooterBtn:SetText(L("HISTORY_DETAIL_CLOSE", "Close"))
    styleButton(closeFooterBtn, "primary")
    closeFooterBtn:SetScript("OnClick", function() modal:Hide() end)

    function modal:Bind(seedEntry)
        if not seedEntry then return end
        self.seedEntry = seedEntry

        self:SetTitle(seedEntry.encounterName or L("HISTORY_DETAIL_SESSION_TITLE", "Session Summary"))
        local parts = {}
        if seedEntry.difficultyName then parts[#parts + 1] = seedEntry.difficultyName end
        if seedEntry.instance then parts[#parts + 1] = seedEntry.instance end
        if seedEntry.groupSize then parts[#parts + 1] = string.format("%d-player", seedEntry.groupSize) end
        if seedEntry.timestamp and seedEntry.timestamp > 0 then
            parts[#parts + 1] = Utils.FormatDate(seedEntry.timestamp)
        end
        self:SetSubtitle(table.concat(parts, "   •   "))

        -- Header quick-nav wiring
        if seedEntry.instance and seedEntry.instance ~= "" then
            self.raidLinkBtn:Show()
            local inst = seedEntry.instance
            self.raidLinkBtn:SetScript("OnClick", function() ns.ShowRaidSummary(inst) end)
        else
            self.raidLinkBtn:Hide()
        end
        if seedEntry.encounterName and seedEntry.encounterName ~= "" then
            self.bossLinkBtn:Show()
            local enc, inst = seedEntry.encounterName, seedEntry.instance
            self.bossLinkBtn:SetScript("OnClick", function() ns.ShowBossSummary(enc, inst) end)
        else
            self.bossLinkBtn:Hide()
        end

        local siblings = collectEntries(function(e)
            return isSameSession(e, seedEntry)
        end)
        self.list:Refresh(siblings)
    end

    function modal:OnHideCleanup()
        self.seedEntry = nil
        if self.raidLinkBtn then self.raidLinkBtn:SetScript("OnClick", nil) end
        if self.bossLinkBtn then self.bossLinkBtn:SetScript("OnClick", nil) end
    end

    -- Keep the sibling list fresh if history mutates while the modal is open.
    if Loothing.History and Loothing.History.RegisterCallback then
        Loothing.History:RegisterCallback("OnHistoryChanged", function()
            if modal:IsShown() and modal.seedEntry then
                modal:Bind(modal.seedEntry)
            end
        end, modal)
    end

    local baseApplyTheme = modal.ApplyTheme
    function modal:ApplyTheme()
        baseApplyTheme(self)
        if self.list then self.list:ApplyTheme() end
        styleButton(closeFooterBtn, "primary")
        styleButton(self.raidLinkBtn, "ghost")
        styleButton(self.bossLinkBtn, "ghost")
    end

    summaryInstance = modal
    return modal
end

--- Open the session summary modal. Accepts any history entry; siblings
--- are computed as entries that share encounterID + timestamp proximity.
--- @param entry table
function ns.ShowSessionSummary(entry)
    if not entry then return end
    local modal = getSummaryInstance()
    modal:Bind(entry)
    modal:Show()
end

--[[======================================================================
    CANDIDATE PROFILE MODAL

    Shows every history entry where `playerName` appeared as winner or in
    the candidates[] snapshot. Two tabs: Awards (they won) and All Rolls
    (any entry they participated in). Summary stats in the header.
======================================================================]]

local function getCandidateInstance()
    if candidateInstance then return candidateInstance end

    local modal = CreateModal("LoothingCandidateProfileFrame",
        PROFILE_WIDTH, PROFILE_HEIGHT,
        L("HISTORY_DETAIL_CANDIDATE_PROFILE", "Candidate Profile"))

    -- Stats row (two lines under the title)
    local stats = modal.frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    stats:SetPoint("TOPLEFT", 14, -50)
    stats:SetPoint("TOPRIGHT", -14, -50)
    stats:SetJustifyH("LEFT")
    stats:SetWordWrap(false)
    applyTextColor(stats, "textMuted", { 0.7, 0.7, 0.7 })
    modal.stats = stats

    -- Tab strip
    local tabArea = CreateFrame("Frame", nil, modal.frame)
    tabArea:SetPoint("TOPLEFT", 10, -(HEADER_HEIGHT + 16))
    tabArea:SetPoint("TOPRIGHT", -10, -(HEADER_HEIGHT + 16))
    tabArea:SetHeight(TAB_HEIGHT + 6)
    modal.tabArea = tabArea

    local tabDefs = {
        { id = "awards", text = L("HISTORY_DETAIL_TAB_AWARDS",    "Awards") },
        { id = "rolls",  text = L("HISTORY_DETAIL_TAB_ALL_ROLLS", "All Rolls") },
    }
    modal.tabStrip = CreateTabStrip(tabArea, tabDefs, function(tabId)
        modal:ShowTab(tabId)
    end)

    local contentArea = CreateFrame("Frame", nil, modal.frame)
    contentArea:SetPoint("TOPLEFT", tabArea, "BOTTOMLEFT", 0, -4)
    contentArea:SetPoint("BOTTOMRIGHT", -10, FOOTER_HEIGHT + 4)
    modal.contentArea = contentArea

    -- Shared row init/bind for both tabs (columns are the same, behavior differs slightly)
    local function buildListPanel(showWinnerColumn)
        local panel = CreateFrame("Frame", nil, contentArea)
        panel:SetAllPoints()
        panel:Hide()

        local header = CreateFrame("Frame", nil, panel)
        header:SetPoint("TOPLEFT", 0, 0)
        header:SetPoint("TOPRIGHT", 0, 0)
        header:SetHeight(22)
        local function mkHeader(text, xOff, width)
            local fs = header:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            fs:SetPoint("LEFT", xOff, 0)
            fs:SetWidth(width)
            fs:SetJustifyH("LEFT")
            applyTextColor(fs, "textMuted", { 0.66, 0.70, 0.79 })
            fs:SetText(text)
            return fs
        end
        mkHeader(L("HISTORY_DETAIL_COL_ITEM",     "Item"),     8,   210)
        mkHeader(L("HISTORY_DETAIL_COL_DATE",     "Date"),     224, 104)
        mkHeader(L("HISTORY_DETAIL_COL_RESPONSE", "Response"), 332, 90)
        mkHeader(L("HISTORY_DETAIL_COL_ROLL",     "Roll"),     426, 42)
        if showWinnerColumn then
            mkHeader(L("HISTORY_DETAIL_COL_WON_BY", "Won By"), 476, 140)
        else
            mkHeader(L("HISTORY_DETAIL_COL_ILVL", "iLvl Δ"),   476, 60)
        end

        local list = CreateScrollList(panel, {
            rowHeight = CANDIDATE_ROW_HEIGHT,
            rowSpacing = 1,
            emptyMessage = L("HISTORY_DETAIL_NO_PLAYER_HISTORY",
                "No history entries found for this player."),
            initRow = function(row)
                row:SetBackdrop({
                    bgFile = "Interface\\Buttons\\WHITE8x8",
                    tile = false, edgeSize = 0,
                    insets = { left = 0, right = 0, top = 0, bottom = 0 },
                })
                row:SetBackdropColor(unpack(skinColor("rowAlt", { 0.06, 0.07, 0.1, 0.5 })))
                local hl = row:CreateTexture(nil, "HIGHLIGHT")
                hl:SetAllPoints()
                hl:SetColorTexture(1, 1, 1, 0.08)
                addRowHoverAccent(row)

                row.icon = row:CreateTexture(nil, "ARTWORK")
                row.icon:SetSize(24, 24)
                row.icon:SetPoint("LEFT", 8, 0)

                row.iconBorder = row:CreateTexture(nil, "OVERLAY")
                row.iconBorder:SetSize(26, 26)
                row.iconBorder:SetPoint("CENTER", row.icon, "CENTER")
                row.iconBorder:SetTexture("Interface\\Common\\WhiteIconFrame")

                row.itemText = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
                row.itemText:SetPoint("LEFT", row.icon, "RIGHT", 6, 0)
                row.itemText:SetWidth(180)
                row.itemText:SetJustifyH("LEFT")
                row.itemText:SetWordWrap(false)

                row.dateText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                row.dateText:SetPoint("LEFT", 224, 0)
                row.dateText:SetWidth(104)
                row.dateText:SetJustifyH("LEFT")
                applyTextColor(row.dateText, "textMuted", { 0.66, 0.70, 0.79 })

                row.responseText = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
                row.responseText:SetPoint("LEFT", 332, 0)
                row.responseText:SetWidth(90)
                row.responseText:SetJustifyH("LEFT")

                row.rollText = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
                row.rollText:SetPoint("LEFT", 426, 0)
                row.rollText:SetWidth(42)
                row.rollText:SetJustifyH("LEFT")

                row.extraText = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
                row.extraText:SetPoint("LEFT", 476, 0)
                row.extraText:SetPoint("RIGHT", -6, 0)
                row.extraText:SetJustifyH("LEFT")
                row.extraText:SetWordWrap(false)

                row:RegisterForClicks("LeftButtonUp")
            end,
            bindRow = function(row, rowData)
                local entry = rowData.entry
                local tex = entry.itemID and C_Item.GetItemIconByID(entry.itemID)
                    or "Interface\\Icons\\INV_Misc_QuestionMark"
                row.icon:SetTexture(tex)
                local qr, qg, qb = qualityColor(entry.quality, entry.itemLink)
                row.iconBorder:SetVertexColor(qr, qg, qb)

                row.itemText:SetText(entry.itemName or entry.itemLink or "?")
                row.itemText:SetTextColor(qr, qg, qb)

                row.dateText:SetText(entry.date or (entry.timestamp and entry.timestamp > 0 and Utils.FormatDate(entry.timestamp)) or "")
                row.responseText:SetText(responseColoredText(rowData.response) or rowData.responseText or "")

                if rowData.roll and rowData.roll > 0 then
                    row.rollText:SetText(tostring(rowData.roll))
                    applyTextColor(row.rollText, "text")
                else
                    row.rollText:SetText("—")
                    applyTextColor(row.rollText, "textSubtle", { 0.5, 0.5, 0.5 })
                end

                if showWinnerColumn then
                    row.extraText:SetText(classColoredName(entry.winner, entry.winnerClass))
                else
                    local diff = rowData.ilvlDiff
                    if diff and diff ~= 0 then
                        local prefix = diff > 0 and "+" or ""
                        row.extraText:SetText(prefix .. tostring(diff))
                        if diff > 0 then
                            applyTextColor(row.extraText, "success", { 0.3, 0.8, 0.5 })
                        else
                            applyTextColor(row.extraText, "danger", { 0.85, 0.4, 0.4 })
                        end
                    else
                        row.extraText:SetText("—")
                        applyTextColor(row.extraText, "textSubtle", { 0.5, 0.5, 0.5 })
                    end
                end

                row:SetScript("OnEnter", function(r)
                    GameTooltip:SetOwner(r, "ANCHOR_RIGHT")
                    if entry.itemLink then GameTooltip:SetHyperlink(entry.itemLink) end
                    GameTooltip:AddLine(" ")
                    GameTooltip:AddLine(L("HISTORY_DETAIL_CLICK_FOR_DETAILS", "Click for full details"), 0.8, 0.8, 0.8)
                    GameTooltip:Show()
                end)
                row:SetScript("OnLeave", function() GameTooltip:Hide() end)
                row:SetScript("OnClick", function() ns.ShowHistoryDetail(entry) end)
            end,
        })
        list.container:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -2)
        list.container:SetPoint("BOTTOMRIGHT", 0, 0)

        panel.list = list
        return panel
    end

    modal.awardsPanel = buildListPanel(false)  -- player is the winner; show iLvl Δ column
    modal.rollsPanel = buildListPanel(true)    -- show "Won By" column

    function modal:ShowTab(tabId)
        self.awardsPanel:Hide()
        self.rollsPanel:Hide()
        if tabId == "awards" then self.awardsPanel:Show()
        else self.rollsPanel:Show() end
    end

    local closeFooterBtn = ns.CreateThemedButton(modal.footer)
    closeFooterBtn:SetSize(100, 24)
    closeFooterBtn:SetPoint("RIGHT")
    closeFooterBtn:SetText(L("HISTORY_DETAIL_CLOSE", "Close"))
    styleButton(closeFooterBtn, "primary")
    closeFooterBtn:SetScript("OnClick", function() modal:Hide() end)

    function modal:Bind(playerName)
        if not playerName then return end
        self.playerName = playerName

        -- Aggregate
        local awardsData = {}
        local rollsData = {}
        local responseTally = {}
        local rollTotal, rollCount = 0, 0
        local classFile
        -- Hoist the short-name derivation out of the per-entry inner loop
        -- (history can have hundreds of entries, each with many candidates).
        local shortTarget = Utils.GetShortName(playerName) or playerName

        if not Loothing.History or not Loothing.History.GetEntries then
            self:SetTitle(classColoredName(playerName, nil))
            self.stats:SetText("")
            self.awardsPanel.list:Refresh({})
            self.rollsPanel.list:Refresh({})
            self.tabStrip.currentId = nil
            self.tabStrip:SelectTab("awards")
            return
        end

        for _, entry in Loothing.History:GetEntries():Enumerate() do
            -- Matches against full name or short name (history may store either form)
            local matches = Utils.IsSamePlayer and Utils.IsSamePlayer(entry.winner, playerName)
                or entry.winner == playerName
                or (entry.winner and Utils.GetShortName(entry.winner) == shortTarget)

            if matches then
                if entry.winnerClass then classFile = classFile or entry.winnerClass end
                -- Resolve the winner's actual response from their candidate
                -- snapshot (real award path leaves entry.winnerResponse nil).
                awardsData[#awardsData + 1] = {
                    entry = entry,
                    response = getWinnerResponse(entry),
                    responseText = entry.winnerResponseText,
                    roll = entry.winnerRoll,
                    ilvlDiff = entry.winnerIlvlDiff,
                }
            end

            -- Walk the candidate snapshot too so this works for non-winners
            if entry.candidates then
                for _, c in ipairs(entry.candidates) do
                    local candidateMatches = c.playerName and (
                        c.playerName == playerName
                        or (Utils.GetShortName(c.playerName) == shortTarget)
                    )
                    if candidateMatches then
                        if c.playerClass then classFile = classFile or c.playerClass end
                        rollsData[#rollsData + 1] = {
                            entry = entry,
                            response = c.response,
                            responseText = c.responseText,
                            roll = c.roll,
                            ilvlDiff = c.ilvlDiff,
                        }
                        if c.response then
                            responseTally[c.response] = (responseTally[c.response] or 0) + 1
                        end
                        if c.roll and c.roll > 0 then
                            rollTotal = rollTotal + c.roll
                            rollCount = rollCount + 1
                        end
                    end
                end
            end
        end

        table.sort(awardsData, function(a, b)
            return (a.entry.timestamp or 0) > (b.entry.timestamp or 0)
        end)
        table.sort(rollsData, function(a, b)
            return (a.entry.timestamp or 0) > (b.entry.timestamp or 0)
        end)

        self:SetTitle(classColoredName(playerName, classFile))

        -- Stats: Awards / Rolled / Win Rate / Avg Roll / Response breakdown
        local wins = #awardsData
        local rolled = #rollsData
        local winRate = rolled > 0 and string.format("%.0f%%", (wins / rolled) * 100) or "—"
        local avgRoll = rollCount > 0 and string.format("%.1f", rollTotal / rollCount) or "—"

        local tallyParts = {}
        for respId, count in pairs(responseTally) do
            local info = Loothing.ResponseInfo[respId]
            if info then
                local c = info.color or {}
                tallyParts[#tallyParts + 1] = string.format("|cff%02x%02x%02x%s %d|r",
                    math.floor((c.r or 1) * 255 + 0.5),
                    math.floor((c.g or 1) * 255 + 0.5),
                    math.floor((c.b or 1) * 255 + 0.5),
                    info.name or "?", count)
            end
        end
        local tallyStr = #tallyParts > 0 and table.concat(tallyParts, "  ") or L("HISTORY_DETAIL_NO_RESPONSES", "no responses")

        self.stats:SetText(string.format(
            L("HISTORY_DETAIL_PROFILE_STATS",
                "Awards: %d   •   Items Rolled: %d   •   Win Rate: %s   •   Avg Roll: %s   •   %s"),
            wins, rolled, winRate, avgRoll, tallyStr))

        self.awardsPanel.list:Refresh(awardsData)
        self.rollsPanel.list:Refresh(rollsData)

        self.tabStrip.currentId = nil
        self.tabStrip:SelectTab("awards")
        C_Timer.After(0, function()
            if not self.frame or not self.frame:IsVisible() then return end
            if self.tabStrip then self.tabStrip:Refresh() end
        end)
    end

    local baseApplyTheme = modal.ApplyTheme
    function modal:ApplyTheme()
        baseApplyTheme(self)
        applyTextColor(self.stats, "textMuted", { 0.7, 0.7, 0.7 })
        if self.tabStrip then self.tabStrip:Refresh() end
        if self.awardsPanel and self.awardsPanel.list then self.awardsPanel.list:ApplyTheme() end
        if self.rollsPanel and self.rollsPanel.list then self.rollsPanel.list:ApplyTheme() end
        styleButton(closeFooterBtn, "primary")
    end

    function modal:OnHideCleanup()
        self.playerName = nil
    end

    -- Refresh stats + list if history mutates while the modal is open so
    -- the profile stays accurate across live award / delete events.
    if Loothing.History and Loothing.History.RegisterCallback then
        Loothing.History:RegisterCallback("OnHistoryChanged", function()
            if modal:IsShown() and modal.playerName then
                modal:Bind(modal.playerName)
            end
        end, modal)
    end

    candidateInstance = modal
    return modal
end

--- Open the candidate profile modal.
--- @param playerName string  Full or short player name (matched against entry.winner and candidates[].playerName)
function ns.ShowCandidateProfile(playerName)
    if not playerName or playerName == "" then return end
    local modal = getCandidateInstance()
    modal:Bind(playerName)
    modal:Show()
end

--[[======================================================================
    VOTER PROFILE MODAL

    Shows every history entry where `voterName` appears in the councilVotes[]
    snapshot. Summary: total votes cast, most-voted-for candidate. Each row
    shows the item, date, the voter's ranked picks, the voter's note, and
    the final winner.
======================================================================]]

local function getVoterInstance()
    if voterInstance then return voterInstance end

    local modal = CreateModal("LoothingVoterProfileFrame",
        PROFILE_WIDTH, PROFILE_HEIGHT,
        L("HISTORY_DETAIL_VOTER_PROFILE", "Voter Profile"))

    local stats = modal.frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    stats:SetPoint("TOPLEFT", 14, -50)
    stats:SetPoint("TOPRIGHT", -14, -50)
    stats:SetJustifyH("LEFT")
    stats:SetWordWrap(false)
    applyTextColor(stats, "textMuted", { 0.7, 0.7, 0.7 })
    modal.stats = stats

    local contentArea = CreateFrame("Frame", nil, modal.frame)
    contentArea:SetPoint("TOPLEFT", 10, -(HEADER_HEIGHT + 18))
    contentArea:SetPoint("BOTTOMRIGHT", -10, FOOTER_HEIGHT + 4)
    modal.contentArea = contentArea

    local header = CreateFrame("Frame", nil, contentArea)
    header:SetPoint("TOPLEFT", 0, 0)
    header:SetPoint("TOPRIGHT", 0, 0)
    header:SetHeight(22)
    local function mkHeader(text, xOff, width)
        local fs = header:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        fs:SetPoint("LEFT", xOff, 0)
        fs:SetWidth(width)
        fs:SetJustifyH("LEFT")
        applyTextColor(fs, "textMuted", { 0.66, 0.70, 0.79 })
        fs:SetText(text)
        return fs
    end
    mkHeader(L("HISTORY_DETAIL_COL_ITEM",   "Item"),            8,   200)
    mkHeader(L("HISTORY_DETAIL_COL_DATE",   "Date"),            214, 98)
    mkHeader(L("HISTORY_DETAIL_COL_PICKS",  "Picks (Ranked)"),  316, 200)
    mkHeader(L("HISTORY_DETAIL_COL_WINNER", "Winner"),          520, 140)

    local list = CreateScrollList(contentArea, {
        rowHeight = CANDIDATE_ROW_HEIGHT,
        rowSpacing = 1,
        emptyMessage = L("HISTORY_DETAIL_NO_VOTER_HISTORY",
            "No council votes recorded for this voter."),
        initRow = function(row)
            row:SetBackdrop({
                bgFile = "Interface\\Buttons\\WHITE8x8",
                tile = false, edgeSize = 0,
                insets = { left = 0, right = 0, top = 0, bottom = 0 },
            })
            row:SetBackdropColor(unpack(skinColor("rowAlt", { 0.06, 0.07, 0.1, 0.5 })))
            local hl = row:CreateTexture(nil, "HIGHLIGHT")
            hl:SetAllPoints()
            hl:SetColorTexture(1, 1, 1, 0.08)
            addRowHoverAccent(row)

            row.icon = row:CreateTexture(nil, "ARTWORK")
            row.icon:SetSize(24, 24)
            row.icon:SetPoint("LEFT", 8, 0)
            row.iconBorder = row:CreateTexture(nil, "OVERLAY")
            row.iconBorder:SetSize(26, 26)
            row.iconBorder:SetPoint("CENTER", row.icon, "CENTER")
            row.iconBorder:SetTexture("Interface\\Common\\WhiteIconFrame")

            row.itemText = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            row.itemText:SetPoint("LEFT", row.icon, "RIGHT", 6, 0)
            row.itemText:SetWidth(170)
            row.itemText:SetJustifyH("LEFT")
            row.itemText:SetWordWrap(false)

            row.dateText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            row.dateText:SetPoint("LEFT", 214, 0)
            row.dateText:SetWidth(98)
            row.dateText:SetJustifyH("LEFT")
            applyTextColor(row.dateText, "textMuted", { 0.66, 0.70, 0.79 })

            row.picksText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            row.picksText:SetPoint("LEFT", 316, 0)
            row.picksText:SetWidth(200)
            row.picksText:SetJustifyH("LEFT")
            row.picksText:SetWordWrap(false)

            row.winnerText = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            row.winnerText:SetPoint("LEFT", 520, 0)
            row.winnerText:SetPoint("RIGHT", -6, 0)
            row.winnerText:SetJustifyH("LEFT")
            row.winnerText:SetWordWrap(false)

            row:RegisterForClicks("LeftButtonUp")
        end,
        bindRow = function(row, rowData)
            local entry = rowData.entry
            local vote = rowData.vote

            local tex = entry.itemID and C_Item.GetItemIconByID(entry.itemID)
                or "Interface\\Icons\\INV_Misc_QuestionMark"
            row.icon:SetTexture(tex)
            local qr, qg, qb = qualityColor(entry.quality, entry.itemLink)
            row.iconBorder:SetVertexColor(qr, qg, qb)

            row.itemText:SetText(entry.itemName or entry.itemLink or "?")
            row.itemText:SetTextColor(qr, qg, qb)

            row.dateText:SetText(entry.date or (entry.timestamp and entry.timestamp > 0 and Utils.FormatDate(entry.timestamp)) or "")

            local picks = "—"
            if vote.responses and #vote.responses > 0 then
                local parts = {}
                for i, r in ipairs(vote.responses) do
                    if type(r) == "number" then
                        parts[#parts + 1] = string.format("%d. %s", i, responseColoredText(r))
                    elseif type(r) == "string" then
                        parts[#parts + 1] = string.format("%d. %s", i, r)
                    end
                end
                picks = table.concat(parts, "  ")
            end
            row.picksText:SetText(picks)
            row.winnerText:SetText(classColoredName(entry.winner, entry.winnerClass))

            row:SetScript("OnEnter", function(r)
                GameTooltip:SetOwner(r, "ANCHOR_RIGHT")
                if entry.itemLink then GameTooltip:SetHyperlink(entry.itemLink) end
                if vote.note and vote.note ~= "" then
                    GameTooltip:AddLine(" ")
                    GameTooltip:AddLine(L("HISTORY_DETAIL_VOTER_NOTE", "Voter Note:"), 1, 0.82, 0)
                    GameTooltip:AddLine(vote.note, 1, 1, 1, true)
                end
                GameTooltip:AddLine(" ")
                GameTooltip:AddLine(L("HISTORY_DETAIL_CLICK_FOR_DETAILS", "Click for full details"), 0.8, 0.8, 0.8)
                GameTooltip:Show()
            end)
            row:SetScript("OnLeave", function() GameTooltip:Hide() end)
            row:SetScript("OnClick", function() ns.ShowHistoryDetail(entry) end)
        end,
    })
    list.container:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -2)
    list.container:SetPoint("BOTTOMRIGHT", 0, 0)
    modal.list = list

    local closeFooterBtn = ns.CreateThemedButton(modal.footer)
    closeFooterBtn:SetSize(100, 24)
    closeFooterBtn:SetPoint("RIGHT")
    closeFooterBtn:SetText(L("HISTORY_DETAIL_CLOSE", "Close"))
    styleButton(closeFooterBtn, "primary")
    closeFooterBtn:SetScript("OnClick", function() modal:Hide() end)

    function modal:Bind(voterName)
        if not voterName then return end
        self.voterName = voterName

        local rows = {}
        local responseTally = {}  -- responseID -> count (voter's top pick per vote)
        local classFile
        local shortTarget = Utils.GetShortName(voterName) or voterName

        if not Loothing.History or not Loothing.History.GetEntries then
            self:SetTitle(classColoredName(voterName, nil))
            self.stats:SetText("")
            self.list:Refresh({})
            return
        end

        for _, entry in Loothing.History:GetEntries():Enumerate() do
            if entry.councilVotes then
                for _, vote in ipairs(entry.councilVotes) do
                    local voterMatches = vote.voter and (
                        vote.voter == voterName
                        or (Utils.GetShortName(vote.voter) == shortTarget)
                    )
                    if voterMatches then
                        if vote.voterClass then classFile = classFile or vote.voterClass end
                        rows[#rows + 1] = { entry = entry, vote = vote }
                        if vote.responses and vote.responses[1] and type(vote.responses[1]) == "number" then
                            local top = vote.responses[1]
                            responseTally[top] = (responseTally[top] or 0) + 1
                        end
                    end
                end
            end
        end
        table.sort(rows, function(a, b)
            return (a.entry.timestamp or 0) > (b.entry.timestamp or 0)
        end)

        self:SetTitle(classColoredName(voterName, classFile))

        -- Build a colored response tally string: "NEED 42  GREED 10  OS 3"
        local tallyParts = {}
        for respId, count in pairs(responseTally) do
            local info = Loothing.ResponseInfo[respId]
            if info then
                local c = info.color or {}
                tallyParts[#tallyParts + 1] = string.format("|cff%02x%02x%02x%s %d|r",
                    math.floor((c.r or 1) * 255 + 0.5),
                    math.floor((c.g or 1) * 255 + 0.5),
                    math.floor((c.b or 1) * 255 + 0.5),
                    info.name or "?", count)
            end
        end
        local tallyStr = #tallyParts > 0 and table.concat(tallyParts, "  ")
            or L("HISTORY_DETAIL_NO_RESPONSES", "no responses")

        self.stats:SetText(string.format(
            L("HISTORY_DETAIL_VOTER_STATS_FMT",
                "Votes Cast: %d   •   Top Picks: %s"),
            #rows, tallyStr))

        self.list:Refresh(rows)
    end

    local baseApplyTheme = modal.ApplyTheme
    function modal:ApplyTheme()
        baseApplyTheme(self)
        applyTextColor(self.stats, "textMuted", { 0.7, 0.7, 0.7 })
        if self.list then self.list:ApplyTheme() end
        styleButton(closeFooterBtn, "primary")
    end

    function modal:OnHideCleanup()
        self.voterName = nil
    end

    if Loothing.History and Loothing.History.RegisterCallback then
        Loothing.History:RegisterCallback("OnHistoryChanged", function()
            if modal:IsShown() and modal.voterName then
                modal:Bind(modal.voterName)
            end
        end, modal)
    end

    voterInstance = modal
    return modal
end

--- Open the voter profile modal.
--- @param voterName string  Full or short voter name
function ns.ShowVoterProfile(voterName)
    if not voterName or voterName == "" then return end
    local modal = getVoterInstance()
    modal:Bind(voterName)
    modal:Show()
end

--[[======================================================================
    SCOPE SUMMARY MODALS (Raid / Boss / Season)

    All three show the same rendering: a stats header, a scrolling list
    of award rows (icon / item / date / winner / response / roll), and a
    close button. Row click opens the item detail modal. What differs
    between them is just:
      - title / subtitle composition
      - the accept(entry) predicate used to filter the history DB

    So we factor everything common into `buildScopeSummary` and the
    three entry points are thin wrappers.
======================================================================]]

--- Build a scope-summary-style modal. Returns a modal table augmented
--- with a `:Bind(scope)` method that the caller supplies via opts.bind.
--- @param opts table
---   globalName    string  - frame global for SetupFrame / ESC-close
---   title         string  - header title
---   emptyMessage  string  - shown when no matching entries
---   bind          function(self, scope) - set title/subtitle + filter
local function buildScopeSummary(opts)
    local modal = CreateModal(opts.globalName,
        SCOPE_SUMMARY_WIDTH, SCOPE_SUMMARY_HEIGHT, opts.title)

    -- Stats band (populated by bind)
    local stats = modal.frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    stats:SetPoint("TOPLEFT", 14, -50)
    stats:SetPoint("TOPRIGHT", -14, -50)
    stats:SetJustifyH("LEFT")
    stats:SetWordWrap(false)
    applyTextColor(stats, "textMuted", { 0.7, 0.7, 0.7 })
    modal.stats = stats

    local contentArea = CreateFrame("Frame", nil, modal.frame)
    contentArea:SetPoint("TOPLEFT", 10, -(HEADER_HEIGHT + 18))
    contentArea:SetPoint("BOTTOMRIGHT", -10, FOOTER_HEIGHT + 4)
    modal.contentArea = contentArea

    -- Column header strip
    local header = CreateFrame("Frame", nil, contentArea)
    header:SetPoint("TOPLEFT", 0, 0)
    header:SetPoint("TOPRIGHT", 0, 0)
    header:SetHeight(22)
    local function mkHeader(text, xOff, width)
        local fs = header:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        fs:SetPoint("LEFT", xOff, 0)
        fs:SetWidth(width)
        fs:SetJustifyH("LEFT")
        applyTextColor(fs, "textMuted", { 0.66, 0.70, 0.79 })
        fs:SetText(text)
        return fs
    end
    mkHeader(L("HISTORY_DETAIL_COL_ITEM",     "Item"),     8,   220)
    mkHeader(L("HISTORY_DETAIL_COL_DATE",     "Date"),     240, 104)
    mkHeader(L("HISTORY_DETAIL_COL_BOSS",     "Boss"),     348, 150)
    mkHeader(L("HISTORY_DETAIL_COL_WINNER",   "Winner"),   504, 130)
    mkHeader(L("HISTORY_DETAIL_COL_RESPONSE", "Response"), 640, 90)

    local list = CreateScrollList(contentArea, {
        rowHeight = CANDIDATE_ROW_HEIGHT,
        rowSpacing = 1,
        emptyMessage = opts.emptyMessage or
            L("HISTORY_DETAIL_NO_SCOPE_MATCHES", "No history entries found for this scope."),
        initRow = function(row)
            row:SetBackdrop({
                bgFile = "Interface\\Buttons\\WHITE8x8",
                tile = false, edgeSize = 0,
                insets = { left = 0, right = 0, top = 0, bottom = 0 },
            })
            row:SetBackdropColor(unpack(skinColor("rowAlt", { 0.06, 0.07, 0.1, 0.5 })))
            local hl = row:CreateTexture(nil, "HIGHLIGHT")
            hl:SetAllPoints()
            hl:SetColorTexture(1, 1, 1, 0.08)
            addRowHoverAccent(row)

            row.icon = row:CreateTexture(nil, "ARTWORK")
            row.icon:SetSize(24, 24)
            row.icon:SetPoint("LEFT", 8, 0)
            row.iconBorder = row:CreateTexture(nil, "OVERLAY")
            row.iconBorder:SetSize(26, 26)
            row.iconBorder:SetPoint("CENTER", row.icon, "CENTER")
            row.iconBorder:SetTexture("Interface\\Common\\WhiteIconFrame")

            row.itemText = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            row.itemText:SetPoint("LEFT", row.icon, "RIGHT", 6, 0)
            -- Width aligns with the "Item" column header (8..228) minus icon+pad:
            -- icon is at x=8, 24px wide + 6px pad → text starts at x=38, reaches x=228.
            row.itemText:SetWidth(190)
            row.itemText:SetJustifyH("LEFT")
            row.itemText:SetWordWrap(false)

            row.dateText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            row.dateText:SetPoint("LEFT", 240, 0)
            row.dateText:SetWidth(104)
            row.dateText:SetJustifyH("LEFT")
            applyTextColor(row.dateText, "textMuted", { 0.66, 0.70, 0.79 })

            row.bossBtn = CreateFrame("Button", nil, row)
            row.bossBtn:SetPoint("LEFT", 348, 0)
            row.bossBtn:SetSize(150, CANDIDATE_ROW_HEIGHT)
            row.bossBtn.text = row.bossBtn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            row.bossBtn.text:SetAllPoints()
            row.bossBtn.text:SetJustifyH("LEFT")
            row.bossBtn.text:SetWordWrap(false)
            addClickableUnderline(row.bossBtn)

            row.winnerBtn = CreateFrame("Button", nil, row)
            row.winnerBtn:SetPoint("LEFT", 504, 0)
            row.winnerBtn:SetSize(130, CANDIDATE_ROW_HEIGHT)
            row.winnerBtn.text = row.winnerBtn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            row.winnerBtn.text:SetAllPoints()
            row.winnerBtn.text:SetJustifyH("LEFT")
            row.winnerBtn.text:SetWordWrap(false)
            addClickableUnderline(row.winnerBtn)

            row.responseText = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            row.responseText:SetPoint("LEFT", 640, 0)
            row.responseText:SetPoint("RIGHT", -6, 0)
            row.responseText:SetJustifyH("LEFT")

            row:RegisterForClicks("LeftButtonUp")
        end,
        bindRow = function(row, entry)
            local tex = entry.itemID and C_Item.GetItemIconByID(entry.itemID)
                or "Interface\\Icons\\INV_Misc_QuestionMark"
            row.icon:SetTexture(tex)
            local qr, qg, qb = qualityColor(entry.quality, entry.itemLink)
            row.iconBorder:SetVertexColor(qr, qg, qb)

            row.itemText:SetText(entry.itemName or entry.itemLink or "?")
            row.itemText:SetTextColor(qr, qg, qb)

            row.dateText:SetText(entry.date
                or (entry.timestamp and entry.timestamp > 0 and Utils.FormatDate(entry.timestamp))
                or "")

            -- Boss column (clickable → BossSummary). When the entry has
            -- no encounterName, the text is shown but the button is made
            -- inert (underline hidden, mouse disabled) so the row's own
            -- OnClick runs instead of silently swallowing the click.
            local bossName = entry.encounterName or entry.boss or "—"
            row.bossBtn.text:SetText(bossName)
            applyTextColor(row.bossBtn.text, "text")
            if entry.encounterName then
                row.bossBtn:SetScript("OnClick", function()
                    ns.ShowBossSummary(entry.encounterName, entry.instance)
                end)
                setButtonClickable(row.bossBtn, true)
            else
                row.bossBtn:SetScript("OnClick", nil)
                setButtonClickable(row.bossBtn, false)
            end

            -- Winner column (clickable → CandidateProfile)
            row.winnerBtn.text:SetText(classColoredName(entry.winner, entry.winnerClass))
            if entry.winner then
                row.winnerBtn:SetScript("OnClick", function()
                    ns.ShowCandidateProfile(entry.winner)
                end)
                setButtonClickable(row.winnerBtn, true)
            else
                row.winnerBtn:SetScript("OnClick", nil)
                setButtonClickable(row.winnerBtn, false)
            end

            row.responseText:SetText(
                responseColoredText(getWinnerResponse(entry)) or entry.response or "—")

            row:SetScript("OnEnter", function(r)
                GameTooltip:SetOwner(r, "ANCHOR_RIGHT")
                if entry.itemLink then GameTooltip:SetHyperlink(entry.itemLink) end
                GameTooltip:AddLine(" ")
                GameTooltip:AddLine(L("HISTORY_DETAIL_CLICK_FOR_DETAILS",
                    "Click for full details"), 0.8, 0.8, 0.8)
                GameTooltip:Show()
            end)
            row:SetScript("OnLeave", function() GameTooltip:Hide() end)
            row:SetScript("OnClick", function() ns.ShowHistoryDetail(entry) end)
        end,
    })
    list.container:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -2)
    list.container:SetPoint("BOTTOMRIGHT", 0, 0)
    modal.list = list

    local closeFooterBtn = ns.CreateThemedButton(modal.footer)
    closeFooterBtn:SetSize(100, 24)
    closeFooterBtn:SetPoint("RIGHT")
    closeFooterBtn:SetText(L("HISTORY_DETAIL_CLOSE", "Close"))
    styleButton(closeFooterBtn, "primary")
    closeFooterBtn:SetScript("OnClick", function() modal:Hide() end)
    modal.closeFooterBtn = closeFooterBtn

    local baseApplyTheme = modal.ApplyTheme
    function modal:ApplyTheme()
        baseApplyTheme(self)
        applyTextColor(self.stats, "textMuted", { 0.7, 0.7, 0.7 })
        if self.list then self.list:ApplyTheme() end
        styleButton(self.closeFooterBtn, "primary")
    end

    return modal
end

--- Compute shared stats for a scoped entry list (used in every summary
--- modal's header band): total count, unique winners, most recent date.
local function computeScopeStats(entries)
    local winners = {}
    local latestTs = 0
    local uniqueWinnerCount = 0
    for _, e in ipairs(entries) do
        if e.winner and not winners[e.winner] then
            winners[e.winner] = true
            uniqueWinnerCount = uniqueWinnerCount + 1
        end
        if e.timestamp and e.timestamp > latestTs then
            latestTs = e.timestamp
        end
    end
    local latestStr = latestTs > 0 and Utils.FormatDate(latestTs) or "—"
    return #entries, uniqueWinnerCount, latestStr
end

--[[======================================================================
    RAID SUMMARY MODAL
======================================================================]]

local function getRaidSummaryInstance()
    if raidSummaryInstance then return raidSummaryInstance end

    local modal = buildScopeSummary({
        globalName = "LoothingRaidSummaryFrame",
        title = L("HISTORY_DETAIL_RAID_SUMMARY_TITLE", "Raid Summary"),
        emptyMessage = L("HISTORY_DETAIL_NO_RAID_HISTORY",
            "No awards recorded for this raid."),
    })

    function modal:Bind(instanceName)
        if not instanceName then return end
        self.instanceName = instanceName

        self:SetTitle(instanceName)

        if not Loothing.History or not Loothing.History.GetEntries then
            self:SetSubtitle("")
            self.stats:SetText("")
            self.list:Refresh({})
            return
        end

        local entries = collectEntries(function(e)
            return e.instance == instanceName
        end)

        local total, uniqueWinners, latest = computeScopeStats(entries)

        -- Optional season context
        local season = Loothing.Seasons and entries[1]
            and Loothing.Seasons:GetForEntry(entries[1])
        local subtitleParts = {}
        if season then subtitleParts[#subtitleParts + 1] = season.name end
        subtitleParts[#subtitleParts + 1] = string.format(
            L("HISTORY_DETAIL_ITEMS_COUNT_FMT", "%d items"), total)
        self:SetSubtitle(table.concat(subtitleParts, "   •   "))

        self.stats:SetText(string.format(
            L("HISTORY_DETAIL_SCOPE_STATS_FMT",
                "Awards: %d   •   Unique Winners: %d   •   Most Recent: %s"),
            total, uniqueWinners, latest))

        self.list:Refresh(entries)
    end

    function modal:OnHideCleanup() self.instanceName = nil end

    if Loothing.History and Loothing.History.RegisterCallback then
        Loothing.History:RegisterCallback("OnHistoryChanged", function()
            if modal:IsShown() and modal.instanceName then
                modal:Bind(modal.instanceName)
            end
        end, modal)
    end

    raidSummaryInstance = modal
    return modal
end

--- Open the raid summary for a specific instance name.
--- @param instanceName string
function ns.ShowRaidSummary(instanceName)
    if not instanceName or instanceName == "" then return end
    local modal = getRaidSummaryInstance()
    modal:Bind(instanceName)
    modal:Show()
end

--[[======================================================================
    BOSS SUMMARY MODAL
======================================================================]]

local function getBossSummaryInstance()
    if bossSummaryInstance then return bossSummaryInstance end

    local modal = buildScopeSummary({
        globalName = "LoothingBossSummaryFrame",
        title = L("HISTORY_DETAIL_BOSS_SUMMARY_TITLE", "Boss Summary"),
        emptyMessage = L("HISTORY_DETAIL_NO_BOSS_HISTORY",
            "No awards recorded for this encounter."),
    })

    function modal:Bind(encounterName, instanceName)
        if not encounterName then return end
        self.encounterName = encounterName
        self.instanceName = instanceName

        self:SetTitle(encounterName)

        if not Loothing.History or not Loothing.History.GetEntries then
            self:SetSubtitle(instanceName or "")
            self.stats:SetText("")
            self.list:Refresh({})
            return
        end

        local entries = collectEntries(function(e)
            if e.encounterName ~= encounterName then return false end
            if instanceName and e.instance ~= instanceName then return false end
            return true
        end)

        local total, uniqueWinners, latest = computeScopeStats(entries)
        local subtitleParts = {}
        if instanceName then subtitleParts[#subtitleParts + 1] = instanceName end
        subtitleParts[#subtitleParts + 1] = string.format(
            L("HISTORY_DETAIL_ITEMS_COUNT_FMT", "%d items"), total)
        self:SetSubtitle(table.concat(subtitleParts, "   •   "))

        self.stats:SetText(string.format(
            L("HISTORY_DETAIL_SCOPE_STATS_FMT",
                "Awards: %d   •   Unique Winners: %d   •   Most Recent: %s"),
            total, uniqueWinners, latest))

        self.list:Refresh(entries)
    end

    function modal:OnHideCleanup()
        self.encounterName = nil
        self.instanceName = nil
    end

    if Loothing.History and Loothing.History.RegisterCallback then
        Loothing.History:RegisterCallback("OnHistoryChanged", function()
            if modal:IsShown() and modal.encounterName then
                modal:Bind(modal.encounterName, modal.instanceName)
            end
        end, modal)
    end

    bossSummaryInstance = modal
    return modal
end

--- Open the boss summary for a specific encounter (optionally scoped
--- to a particular instance to disambiguate reused boss names).
function ns.ShowBossSummary(encounterName, instanceName)
    if not encounterName or encounterName == "" then return end
    local modal = getBossSummaryInstance()
    modal:Bind(encounterName, instanceName)
    modal:Show()
end

--[[======================================================================
    SEASON SUMMARY MODAL
======================================================================]]

local function getSeasonSummaryInstance()
    if seasonSummaryInstance then return seasonSummaryInstance end

    local modal = buildScopeSummary({
        globalName = "LoothingSeasonSummaryFrame",
        title = L("HISTORY_DETAIL_SEASON_SUMMARY_TITLE", "Season Summary"),
        emptyMessage = L("HISTORY_DETAIL_NO_SEASON_HISTORY",
            "No awards recorded for this season."),
    })

    function modal:Bind(seasonId)
        if not seasonId then return end
        self.seasonId = seasonId

        local season = Loothing.Seasons and Loothing.Seasons:GetById(seasonId)
        self:SetTitle(season and season.name or seasonId)

        if not Loothing.History or not Loothing.History.GetEntries then
            self:SetSubtitle("")
            self.stats:SetText("")
            self.list:Refresh({})
            return
        end

        local entries = collectEntries(function(e)
            return Loothing.Seasons and Loothing.Seasons:EntryMatches(e, seasonId) or false
        end)

        local total, uniqueWinners, latest = computeScopeStats(entries)

        -- Count distinct raids within this season for context
        local raids = {}
        local raidCount = 0
        for _, e in ipairs(entries) do
            if e.instance and not raids[e.instance] then
                raids[e.instance] = true
                raidCount = raidCount + 1
            end
        end

        self:SetSubtitle(string.format(
            L("HISTORY_DETAIL_SEASON_SUBTITLE_FMT", "%d raids  •  %d awards"),
            raidCount, total))

        self.stats:SetText(string.format(
            L("HISTORY_DETAIL_SCOPE_STATS_FMT",
                "Awards: %d   •   Unique Winners: %d   •   Most Recent: %s"),
            total, uniqueWinners, latest))

        self.list:Refresh(entries)
    end

    function modal:OnHideCleanup() self.seasonId = nil end

    if Loothing.History and Loothing.History.RegisterCallback then
        Loothing.History:RegisterCallback("OnHistoryChanged", function()
            if modal:IsShown() and modal.seasonId then
                modal:Bind(modal.seasonId)
            end
        end, modal)
    end

    seasonSummaryInstance = modal
    return modal
end

--- Open the season summary for a specific season id (e.g. "MIDNIGHT_S1").
function ns.ShowSeasonSummary(seasonId)
    if not seasonId or seasonId == "" then return end
    local modal = getSeasonSummaryInstance()
    modal:Bind(seasonId)
    modal:Show()
end

--[[======================================================================
    ITEM SUMMARY MODAL

    Scoped to a specific itemID — shows every time *this* item has been
    awarded, across every raid / boss / difficulty / date. Mirrors the
    raid/boss/season modals but the filter predicate is by itemID.
======================================================================]]

local function getItemSummaryInstance()
    if itemSummaryInstance then return itemSummaryInstance end

    local modal = buildScopeSummary({
        globalName = "LoothingItemSummaryFrame",
        title = L("HISTORY_DETAIL_ITEM_SUMMARY_TITLE", "Item Summary"),
        emptyMessage = L("HISTORY_DETAIL_NO_ITEM_HISTORY",
            "No award history recorded for this item."),
    })

    function modal:Bind(itemID)
        if not itemID then return end
        -- Defensive coercion — ShowItemSummary normalizes inputs, but a
        -- stray future caller passing "12345" as a string would silently
        -- produce an empty list (entry.itemID is a number). Coerce here
        -- so the modal works regardless of caller discipline.
        itemID = tonumber(itemID) or itemID
        self.itemID = itemID

        if not Loothing.History or not Loothing.History.GetEntries then
            self:SetTitle(tostring(itemID))
            self:SetSubtitle("")
            self.stats:SetText("")
            self.list:Refresh({})
            return
        end

        local entries = collectEntries(function(e)
            return e.itemID == itemID
        end)

        -- Prefer the most recent entry's link / name for display; falls
        -- back to the raw id if no entries remain (e.g. after deletion).
        local sample = entries[1]
        local titleStr
        if sample then
            titleStr = sample.itemName or sample.itemLink or tostring(itemID)
        else
            titleStr = tostring(itemID)
        end
        self:SetTitle(titleStr)

        local total, uniqueWinners, latest = computeScopeStats(entries)

        -- Track distinct raids / bosses / difficulties for the subtitle
        local raids, bosses, difficulties = {}, {}, {}
        local raidCount, bossCount, diffCount = 0, 0, 0
        for _, e in ipairs(entries) do
            if e.instance and not raids[e.instance] then
                raids[e.instance] = true; raidCount = raidCount + 1
            end
            if e.encounterName and not bosses[e.encounterName] then
                bosses[e.encounterName] = true; bossCount = bossCount + 1
            end
            if e.difficultyName and not difficulties[e.difficultyName] then
                difficulties[e.difficultyName] = true; diffCount = diffCount + 1
            end
        end

        local subtitleParts = {}
        if sample and sample.itemLevel then
            subtitleParts[#subtitleParts + 1] = string.format(
                L("HISTORY_DETAIL_ITEM_LEVEL_FMT", "iLvl %d"), sample.itemLevel)
        end
        subtitleParts[#subtitleParts + 1] = string.format(
            L("HISTORY_DETAIL_ITEMS_COUNT_FMT", "%d items"), total)
        if bossCount > 0 then
            subtitleParts[#subtitleParts + 1] = string.format(
                L("HISTORY_DETAIL_ITEM_SUMMARY_FROM_FMT", "from %d bosses"), bossCount)
        end
        self:SetSubtitle(table.concat(subtitleParts, "   •   "))

        self.stats:SetText(string.format(
            L("HISTORY_DETAIL_SCOPE_STATS_FMT",
                "Awards: %d   •   Unique Winners: %d   •   Most Recent: %s"),
            total, uniqueWinners, latest))

        self.list:Refresh(entries)
    end

    function modal:OnHideCleanup() self.itemID = nil end

    if Loothing.History and Loothing.History.RegisterCallback then
        Loothing.History:RegisterCallback("OnHistoryChanged", function()
            if modal:IsShown() and modal.itemID then
                modal:Bind(modal.itemID)
            end
        end, modal)
    end

    itemSummaryInstance = modal
    return modal
end

--- Open the item summary modal for a specific item id.
--- Accepts either a numeric itemID or a WoW item link (from which the
--- id is extracted).
--- @param itemIDOrLink number|string
function ns.ShowItemSummary(itemIDOrLink)
    if not itemIDOrLink then return end
    local itemID = itemIDOrLink
    if type(itemIDOrLink) == "string" then
        local parsed = tonumber(itemIDOrLink:match("item:(%d+)"))
            or tonumber(itemIDOrLink)
        if parsed then itemID = parsed end
    end
    if type(itemID) ~= "number" or itemID <= 0 then return end
    local modal = getItemSummaryInstance()
    modal:Bind(itemID)
    modal:Show()
end

--[[======================================================================
    HISTORY BROWSER (hub picker)

    Top-level entry point for the scope-summary family. Tabs pick the
    dimension; each tab shows distinct values + count + most-recent date.
    Clicking a value opens the matching summary modal (Raid / Boss /
    Season / CandidateProfile for "players").
======================================================================]]

local function getBrowserInstance()
    if browserInstance then return browserInstance end

    local modal = CreateModal("LoothingHistoryBrowserFrame",
        PROFILE_WIDTH, PROFILE_HEIGHT,
        L("HISTORY_DETAIL_BROWSER_TITLE", "Browse History"))

    local subtitleHint = modal.subtitle
    applyTextColor(subtitleHint, "textMuted", { 0.7, 0.7, 0.7 })
    subtitleHint:SetText(L("HISTORY_DETAIL_BROWSER_HINT",
        "Pick a dimension to drill into. Click any row to open its summary."))

    -- Tab strip
    local tabArea = CreateFrame("Frame", nil, modal.frame)
    tabArea:SetPoint("TOPLEFT", 10, -(HEADER_HEIGHT + 2))
    tabArea:SetPoint("TOPRIGHT", -10, -(HEADER_HEIGHT + 2))
    tabArea:SetHeight(TAB_HEIGHT + 6)
    modal.tabArea = tabArea

    local tabDefs = {
        { id = "raid",   text = L("HISTORY_DETAIL_TAB_RAIDS",   "Raids") },
        { id = "boss",   text = L("HISTORY_DETAIL_TAB_BOSSES",  "Bosses") },
        { id = "season", text = L("HISTORY_DETAIL_TAB_SEASONS", "Seasons") },
        { id = "item",   text = L("HISTORY_DETAIL_TAB_ITEMS",   "Items") },
        { id = "player", text = L("HISTORY_DETAIL_TAB_PLAYERS", "Players") },
    }
    modal.tabStrip = CreateTabStrip(tabArea, tabDefs, function(tabId)
        modal:ShowTab(tabId)
    end)

    local contentArea = CreateFrame("Frame", nil, modal.frame)
    contentArea:SetPoint("TOPLEFT", tabArea, "BOTTOMLEFT", 0, -4)
    contentArea:SetPoint("BOTTOMRIGHT", -10, FOOTER_HEIGHT + 4)
    modal.contentArea = contentArea

    -- Shared row init/bind for all four tabs: label / count / latest / chevron
    local function buildBrowserList()
        return CreateScrollList(contentArea, {
            rowHeight = 30,
            rowSpacing = 1,
            emptyMessage = L("HISTORY_DETAIL_BROWSER_EMPTY",
                "No entries found for this dimension."),
            initRow = function(row)
                row:SetBackdrop({
                    bgFile = "Interface\\Buttons\\WHITE8x8",
                    tile = false, edgeSize = 0,
                    insets = { left = 0, right = 0, top = 0, bottom = 0 },
                })
                row:SetBackdropColor(unpack(skinColor("rowAlt", { 0.06, 0.07, 0.1, 0.5 })))
                local hl = row:CreateTexture(nil, "HIGHLIGHT")
                hl:SetAllPoints()
                hl:SetColorTexture(1, 1, 1, 0.08)
                addRowHoverAccent(row)

                row.labelText = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
                row.labelText:SetPoint("LEFT", 10, 0)
                row.labelText:SetPoint("RIGHT", row, "LEFT", 360, 0)
                row.labelText:SetJustifyH("LEFT")
                row.labelText:SetWordWrap(false)

                row.countText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                row.countText:SetPoint("LEFT", 370, 0)
                row.countText:SetWidth(80)
                row.countText:SetJustifyH("LEFT")
                applyTextColor(row.countText, "textMuted", { 0.66, 0.70, 0.79 })

                row.latestText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                row.latestText:SetPoint("LEFT", 460, 0)
                row.latestText:SetPoint("RIGHT", -10, 0)
                row.latestText:SetJustifyH("LEFT")
                applyTextColor(row.latestText, "textSubtle", { 0.5, 0.5, 0.5 })

                row:RegisterForClicks("LeftButtonUp")
            end,
            bindRow = function(row, data)
                row.labelText:SetText(data.label or "?")
                if data.labelColor then
                    row.labelText:SetTextColor(data.labelColor[1], data.labelColor[2], data.labelColor[3])
                else
                    applyTextColor(row.labelText, "text")
                end
                row.countText:SetText(string.format(
                    L("HISTORY_DETAIL_BROWSER_COUNT_FMT", "%d awards"),
                    data.count or 0))
                row.latestText:SetText(data.latest or "")
                row:SetScript("OnEnter", function(r)
                    GameTooltip:SetOwner(r, "ANCHOR_RIGHT")
                    GameTooltip:AddLine(data.label or "?", 1, 0.82, 0)
                    if data.tooltip then GameTooltip:AddLine(data.tooltip, 0.8, 0.8, 0.8) end
                    GameTooltip:AddLine(" ")
                    GameTooltip:AddLine(L("HISTORY_DETAIL_BROWSER_OPEN_HINT",
                        "Click to open summary"), 0.6, 0.85, 1)
                    GameTooltip:Show()
                end)
                row:SetScript("OnLeave", function() GameTooltip:Hide() end)
                row:SetScript("OnClick", function()
                    if data.onClick then data.onClick() end
                end)
            end,
        })
    end

    modal.lists = {}
    for _, def in ipairs(tabDefs) do
        local panel = CreateFrame("Frame", nil, contentArea)
        panel:SetAllPoints()
        panel:Hide()
        local list = buildBrowserList()
        list.container:SetParent(panel)
        list.container:ClearAllPoints()
        list.container:SetPoint("TOPLEFT", 0, 0)
        list.container:SetPoint("BOTTOMRIGHT", 0, 0)
        panel.list = list
        modal.lists[def.id] = panel
    end

    local function aggregate(kind)
        local out = {}
        if not Loothing.History or not Loothing.History.GetEntries then return out end

        if kind == "raid" then
            local buckets = {}
            for _, entry in Loothing.History:GetEntries():Enumerate() do
                if entry.instance then
                    local b = buckets[entry.instance] or { count = 0, latest = 0 }
                    b.count = b.count + 1
                    if (entry.timestamp or 0) > b.latest then b.latest = entry.timestamp end
                    buckets[entry.instance] = b
                end
            end
            for instance, info in pairs(buckets) do
                out[#out + 1] = {
                    label = instance,
                    count = info.count,
                    latest = info.latest > 0 and Utils.FormatDate(info.latest) or "",
                    sortKey = -info.latest,
                    onClick = function() ns.ShowRaidSummary(instance) end,
                }
            end

        elseif kind == "boss" then
            -- Key by (instance, encounterName) so bosses unique across raids
            local buckets = {}
            for _, entry in Loothing.History:GetEntries():Enumerate() do
                if entry.encounterName then
                    local key = (entry.instance or "?") .. "\0" .. entry.encounterName
                    local b = buckets[key] or {
                        count = 0, latest = 0,
                        instance = entry.instance, encounter = entry.encounterName,
                    }
                    b.count = b.count + 1
                    if (entry.timestamp or 0) > b.latest then b.latest = entry.timestamp end
                    buckets[key] = b
                end
            end
            for _, info in pairs(buckets) do
                local label = info.encounter
                if info.instance then
                    label = string.format("%s  |cff888888(%s)|r", info.encounter, info.instance)
                end
                out[#out + 1] = {
                    label = label,
                    count = info.count,
                    latest = info.latest > 0 and Utils.FormatDate(info.latest) or "",
                    tooltip = info.instance,
                    sortKey = -info.latest,
                    onClick = function() ns.ShowBossSummary(info.encounter, info.instance) end,
                }
            end

        elseif kind == "season" then
            if not Loothing.Seasons then return out end
            local buckets = {}
            for _, entry in Loothing.History:GetEntries():Enumerate() do
                local season = Loothing.Seasons:GetForEntry(entry)
                local id = season and season.id or "UNCLASSIFIED"
                local b = buckets[id] or { count = 0, latest = 0, season = season }
                b.count = b.count + 1
                if (entry.timestamp or 0) > b.latest then b.latest = entry.timestamp end
                buckets[id] = b
            end
            for _, seasonRow in ipairs(Loothing.Seasons:GetAll()) do
                local info = buckets[seasonRow.id]
                if info then
                    out[#out + 1] = {
                        label = seasonRow.name,
                        count = info.count,
                        latest = info.latest > 0 and Utils.FormatDate(info.latest) or "",
                        sortKey = seasonRow.order or 99,
                        onClick = function() ns.ShowSeasonSummary(seasonRow.id) end,
                    }
                end
            end

        elseif kind == "player" then
            local buckets = {}
            local classByName = {}
            for _, entry in Loothing.History:GetEntries():Enumerate() do
                if entry.winner then
                    local b = buckets[entry.winner] or { count = 0, latest = 0 }
                    b.count = b.count + 1
                    if (entry.timestamp or 0) > b.latest then b.latest = entry.timestamp end
                    buckets[entry.winner] = b
                    if entry.winnerClass then classByName[entry.winner] = entry.winnerClass end
                end
            end
            for name, info in pairs(buckets) do
                local r, g, b = classRGB(classByName[name])
                out[#out + 1] = {
                    label = Utils.GetShortName(name) or name,
                    labelColor = { r, g, b },
                    count = info.count,
                    latest = info.latest > 0 and Utils.FormatDate(info.latest) or "",
                    sortKey = -info.count,
                    onClick = function() ns.ShowCandidateProfile(name) end,
                }
            end

        elseif kind == "item" then
            -- One row per distinct itemID, keyed by id (item names / links
            -- can vary with random stats and random-property suffixes).
            local buckets = {}
            for _, entry in Loothing.History:GetEntries():Enumerate() do
                if entry.itemID then
                    local b = buckets[entry.itemID] or {
                        count = 0, latest = 0,
                        itemLink = entry.itemLink,
                        itemName = entry.itemName,
                        quality = entry.quality,
                    }
                    b.count = b.count + 1
                    if (entry.timestamp or 0) > b.latest then b.latest = entry.timestamp end
                    -- Keep the most-recent non-nil link/name/quality to
                    -- display — older entries may have dropped these.
                    if entry.itemLink and not b.itemLink then b.itemLink = entry.itemLink end
                    if entry.itemName and not b.itemName then b.itemName = entry.itemName end
                    if entry.quality and not b.quality then b.quality = entry.quality end
                    buckets[entry.itemID] = b
                end
            end
            for itemID, info in pairs(buckets) do
                local label = info.itemLink or info.itemName or ("item:" .. tostring(itemID))
                out[#out + 1] = {
                    label = label,
                    count = info.count,
                    latest = info.latest > 0 and Utils.FormatDate(info.latest) or "",
                    tooltip = info.itemLink,
                    sortKey = -info.count,
                    -- Capture itemID for the click closure; don't let an
                    -- accidental re-bucket steal the id.
                    onClick = (function(id) return function() ns.ShowItemSummary(id) end end)(itemID),
                }
            end
        end

        table.sort(out, function(a, b)
            local ka, kb = a.sortKey or 0, b.sortKey or 0
            if ka ~= kb then return ka < kb end
            return (a.label or "") < (b.label or "")
        end)
        return out
    end

    function modal:ShowTab(tabId)
        for id, panel in pairs(self.lists) do
            if id == tabId then
                panel:Show()
                panel.list:Refresh(aggregate(id))
            else
                panel:Hide()
            end
        end
    end

    local closeFooterBtn = ns.CreateThemedButton(modal.footer)
    closeFooterBtn:SetSize(100, 24)
    closeFooterBtn:SetPoint("RIGHT")
    closeFooterBtn:SetText(L("HISTORY_DETAIL_CLOSE", "Close"))
    styleButton(closeFooterBtn, "primary")
    closeFooterBtn:SetScript("OnClick", function() modal:Hide() end)
    modal.closeFooterBtn = closeFooterBtn

    function modal:Bind(initialKind)
        self.initialKind = initialKind or "raid"
        self.tabStrip.currentId = nil
        self.tabStrip:SelectTab(self.initialKind)
        C_Timer.After(0, function()
            if not self.frame or not self.frame:IsVisible() then return end
            if self.tabStrip then self.tabStrip:Refresh() end
        end)
    end

    function modal:OnHideCleanup() self.initialKind = nil end

    if Loothing.History and Loothing.History.RegisterCallback then
        Loothing.History:RegisterCallback("OnHistoryChanged", function()
            if modal:IsShown() and modal.tabStrip and modal.tabStrip.currentId then
                modal:ShowTab(modal.tabStrip.currentId)
            end
        end, modal)
    end

    local baseApplyTheme = modal.ApplyTheme
    function modal:ApplyTheme()
        baseApplyTheme(self)
        if self.tabStrip then self.tabStrip:Refresh() end
        for _, panel in pairs(self.lists or {}) do
            if panel.list then panel.list:ApplyTheme() end
        end
        styleButton(self.closeFooterBtn, "primary")
    end

    browserInstance = modal
    return modal
end

local VALID_BROWSER_KINDS = {
    raid = true, boss = true, season = true, item = true, player = true,
}

--- Open the history browser on a specific dimension tab.
--- @param kind string "raid" | "boss" | "season" | "item" | "player"  (default "raid")
function ns.ShowHistoryBrowser(kind)
    -- Validate defensively — an unrecognized kind would open a blank
    -- modal with no tab selected (SelectTab silently no-ops for missing
    -- ids). Falling back to "raid" gives the user something to see.
    if not VALID_BROWSER_KINDS[kind] then kind = "raid" end
    local modal = getBrowserInstance()
    modal:Bind(kind)
    modal:Show()
end

--[[======================================================================
    AWARD MATRIX MODAL

    Leaderboard view: one row per player, one column per response type
    plus a Total column. The three buttons in the filter band narrow the
    dataset by raid / boss / season; selecting a raid auto-narrows the
    boss filter to that raid's encounters (and clears any stale boss
    selection that no longer matches). Column headers are click-to-sort
    with direction arrow glyphs on the active column; default sort is
    Total desc. Row click opens the player's Candidate Profile.
======================================================================]]

local AWARD_MATRIX_WIDTH = 760
local AWARD_MATRIX_HEIGHT = 540

local function buildAwardMatrixColumns()
    -- Build column defs dynamically from Loothing.ResponsePriority so
    -- the matrix stays in sync if response constants ever change.
    local cols = {}
    local x = 8

    cols[#cols + 1] = {
        id = "player", label = L("HISTORY_DETAIL_COL_PLAYER", "Player"),
        x = x, w = 180, align = "LEFT", defaultDir = "asc",
        sortKey = function(row) return (row.shortName or row.playerName or ""):lower() end,
    }
    x = x + 180 + 2

    for _, respId in ipairs(Loothing.ResponsePriority or {}) do
        local info = Loothing.ResponseInfo[respId]
        if info then
            -- TRANSMOG's label is long ("TRANSMOG"); give it a touch more.
            local w = (respId == Loothing.Response.TRANSMOG) and 76 or 56
            cols[#cols + 1] = {
                id = "resp" .. respId,
                label = info.name,
                x = x, w = w, align = "CENTER",
                responseId = respId,
                color = info.color,
                defaultDir = "desc",
                sortKey = function(row) return row.counts[respId] or 0 end,
            }
            x = x + w + 2
        end
    end

    cols[#cols + 1] = {
        id = "other", label = L("HISTORY_DETAIL_MATRIX_COL_OTHER", "Other"),
        x = x, w = 56, align = "CENTER", defaultDir = "desc",
        sortKey = function(row) return row.otherCount or 0 end,
    }
    x = x + 56 + 2

    -- "Won" = how many items the player actually received. Distinct from
    -- the response-type columns which count what they ROLLED regardless
    -- of outcome — so a player who needs everything and never wins
    -- shows big NEED with Won = 0.
    cols[#cols + 1] = {
        id = "won", label = L("HISTORY_DETAIL_MATRIX_COL_WON", "Won"),
        x = x, w = 66, align = "CENTER", defaultDir = "desc",
        isWonColumn = true,
        sortKey = function(row) return row.wins or 0 end,
    }
    x = x + 66 + 2

    cols[#cols + 1] = {
        id = "total", label = L("HISTORY_DETAIL_MATRIX_COL_TOTAL", "Total"),
        x = x, w = 84, align = "CENTER", defaultDir = "desc",
        sortKey = function(row) return row.total or 0 end,
    }

    return cols
end

local function getAwardMatrixInstance()
    if awardMatrixInstance then return awardMatrixInstance end

    local modal = CreateModal("LoothingAwardMatrixFrame",
        AWARD_MATRIX_WIDTH, AWARD_MATRIX_HEIGHT,
        L("HISTORY_DETAIL_MATRIX_TITLE", "Awards by Response Type"))

    modal.subtitle:SetText(L("HISTORY_DETAIL_MATRIX_SUBTITLE",
        "Per-player totals. Filter and sort by raid, boss, or season."))

    -- State
    modal.filters = { raid = nil, boss = nil, season = nil }
    modal.sortCol = "total"
    modal.sortDir = "desc"

    -- Filter band
    local filterBar = CreateFrame("Frame", nil, modal.frame)
    filterBar:SetPoint("TOPLEFT", 12, -(HEADER_HEIGHT + 4))
    filterBar:SetPoint("TOPRIGHT", -12, -(HEADER_HEIGHT + 4))
    filterBar:SetHeight(26)
    modal.filterBar = filterBar

    local function mkFilterBtn(anchor, offsetX, initialText)
        local btn = ns.CreateThemedButton(filterBar)
        btn:SetSize(168, 22)
        if anchor then
            btn:SetPoint("LEFT", anchor, "RIGHT", offsetX or 4, 0)
        else
            btn:SetPoint("LEFT", 0, 0)
        end
        btn:SetText(initialText)
        styleButton(btn, "default")
        return btn
    end

    modal.raidFilterBtn   = mkFilterBtn(nil, 0,
        L("HISTORY_DETAIL_MATRIX_FILTER_RAID_ALL", "Raid: All"))
    modal.bossFilterBtn   = mkFilterBtn(modal.raidFilterBtn, 4,
        L("HISTORY_DETAIL_MATRIX_FILTER_BOSS_ALL", "Boss: All"))
    modal.seasonFilterBtn = mkFilterBtn(modal.bossFilterBtn, 4,
        L("HISTORY_DETAIL_MATRIX_FILTER_SEASON_ALL", "Season: All"))

    modal.clearFilterBtn = ns.CreateThemedButton(filterBar)
    modal.clearFilterBtn:SetSize(64, 22)
    modal.clearFilterBtn:SetPoint("RIGHT")
    modal.clearFilterBtn:SetText(L("CLEAR", "Clear"))
    styleButton(modal.clearFilterBtn, "primary")

    -- Column header row (below filter band)
    local COLUMNS = buildAwardMatrixColumns()
    modal.columns = COLUMNS

    local headerRow = CreateFrame("Frame", nil, modal.frame)
    headerRow:SetPoint("TOPLEFT", 12, -(HEADER_HEIGHT + 38))
    headerRow:SetPoint("TOPRIGHT", -12, -(HEADER_HEIGHT + 38))
    headerRow:SetHeight(24)
    modal.headerRow = headerRow

    -- Build one clickable Button per column with its label + a sort arrow
    -- that only shows on the currently-active sort column.
    modal.headerBtns = {}
    for _, col in ipairs(COLUMNS) do
        local btn = CreateFrame("Button", nil, headerRow)
        btn:SetPoint("LEFT", col.x, 0)
        btn:SetSize(col.w, 22)

        local hl = btn:CreateTexture(nil, "HIGHLIGHT")
        hl:SetAllPoints()
        hl:SetColorTexture(1, 1, 1, 0.08)

        local labelFS = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        labelFS:SetAllPoints()
        labelFS:SetJustifyH(col.align or "LEFT")
        labelFS:SetText(col.label)
        applyTextColor(labelFS, "textMuted", { 0.66, 0.70, 0.79 })
        if col.color then
            labelFS:SetTextColor(col.color.r, col.color.g, col.color.b)
        end

        -- Sort arrow sits to the right of the label (or centered-offset
        -- for center-aligned columns). Uses the Loolib icon font so
        -- WoW's default fonts don't render it as tofu.
        local arrow = btn:CreateFontString(nil, "OVERLAY")
        Loolib.Fonts:SetIconFont(arrow, 9, "")
        arrow:SetText(Loolib.Fonts:Icon("caret-down"))
        if col.align == "CENTER" then
            arrow:SetPoint("LEFT", labelFS, "RIGHT", -6, 0)
        else
            arrow:SetPoint("LEFT", labelFS, "LEFT", labelFS:GetStringWidth() + 2, 0)
        end
        arrow:Hide()

        btn.labelFS = labelFS
        btn.arrow = arrow
        btn.col = col

        btn:SetScript("OnClick", function()
            modal:SortBy(col.id)
        end)

        modal.headerBtns[col.id] = btn
    end

    -- Scrollable list
    local list = CreateScrollList(modal.frame, {
        rowHeight = CANDIDATE_ROW_HEIGHT,
        rowSpacing = 1,
        emptyMessage = L("HISTORY_DETAIL_MATRIX_EMPTY",
            "No awards match the current filters."),
        initRow = function(row)
            row:SetBackdrop({
                bgFile = "Interface\\Buttons\\WHITE8x8",
                tile = false, edgeSize = 0,
                insets = { left = 0, right = 0, top = 0, bottom = 0 },
            })
            row:SetBackdropColor(unpack(skinColor("rowAlt", { 0.06, 0.07, 0.1, 0.5 })))
            local hl = row:CreateTexture(nil, "HIGHLIGHT")
            hl:SetAllPoints()
            hl:SetColorTexture(1, 1, 1, 0.08)
            addRowHoverAccent(row)

            -- Player column (click → CandidateProfile). Anchor is
            -- invariant across rebinds — set it once in initRow so the
            -- per-bind path only touches handlers + text.
            local playerCol = COLUMNS[1]
            row.playerBtn = CreateFrame("Button", nil, row)
            row.playerBtn:SetPoint("LEFT", playerCol.x, 0)
            row.playerBtn:SetSize(playerCol.w, CANDIDATE_ROW_HEIGHT)
            row.playerBtn.text = row.playerBtn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            row.playerBtn.text:SetAllPoints()
            row.playerBtn.text:SetJustifyH("LEFT")
            row.playerBtn.text:SetWordWrap(false)
            addClickableUnderline(row.playerBtn)

            -- One FontString per response / other / total column
            row.cells = {}
            for _, col in ipairs(COLUMNS) do
                if col.id ~= "player" then
                    local fs = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
                    fs:SetPoint("LEFT", col.x, 0)
                    fs:SetWidth(col.w)
                    fs:SetJustifyH(col.align or "LEFT")
                    fs:SetWordWrap(false)
                    row.cells[col.id] = fs
                end
            end

            row:RegisterForClicks("LeftButtonUp")
        end,
        bindRow = function(row, rowData)
            -- Player (clickable if we have a name)
            row.playerBtn.text:SetText(classColoredName(rowData.playerName, rowData.playerClass))
            if rowData.playerName then
                local pname = rowData.playerName
                row.playerBtn:SetScript("OnClick", function()
                    ns.ShowCandidateProfile(pname)
                end)
                setButtonClickable(row.playerBtn, true)
            else
                row.playerBtn:SetScript("OnClick", nil)
                setButtonClickable(row.playerBtn, false)
            end

            -- Response / other / won / total cells
            for _, col in ipairs(COLUMNS) do
                local fs = row.cells[col.id]
                if fs then
                    local value
                    if col.responseId then
                        value = rowData.counts[col.responseId] or 0
                    elseif col.id == "other" then
                        value = rowData.otherCount or 0
                    elseif col.id == "won" then
                        value = rowData.wins or 0
                    elseif col.id == "total" then
                        value = rowData.total or 0
                    end
                    if value and value > 0 then
                        fs:SetText(tostring(value))
                        if col.color then
                            fs:SetTextColor(col.color.r, col.color.g, col.color.b, 1)
                        elseif col.id == "won" then
                            applyTextColor(fs, "warning", { 0.95, 0.78, 0.30 })
                        elseif col.id == "total" then
                            applyTextColor(fs, "accent", { 1, 0.82, 0 })
                        else
                            applyTextColor(fs, "text")
                        end
                    else
                        fs:SetText("—")
                        applyTextColor(fs, "textSubtle", { 0.5, 0.5, 0.5 })
                    end
                end
            end

            -- Row click (outside the Player button) opens the profile
            -- too, so the whole row is one big affordance for exploring
            -- a player's awards.
            row:SetScript("OnClick", function()
                if rowData.playerName then
                    ns.ShowCandidateProfile(rowData.playerName)
                end
            end)
            row:SetScript("OnEnter", function(r)
                GameTooltip:SetOwner(r, "ANCHOR_RIGHT")
                GameTooltip:AddLine(classColoredName(rowData.playerName, rowData.playerClass))
                GameTooltip:AddLine(string.format(
                    L("HISTORY_DETAIL_MATRIX_TOOLTIP_ROLLS_FMT",
                        "%d total rolls   •   %d awards won"),
                    rowData.total or 0, rowData.wins or 0), 1, 0.82, 0)
                GameTooltip:AddLine(" ")
                GameTooltip:AddLine(L("HISTORY_DETAIL_OPEN_PROFILE_HINT",
                    "Click to view player profile"), 0.6, 0.85, 1)
                GameTooltip:Show()
            end)
            row:SetScript("OnLeave", function() GameTooltip:Hide() end)
        end,
    })
    list.container:SetPoint("TOPLEFT", 12, -(HEADER_HEIGHT + 66))
    list.container:SetPoint("BOTTOMRIGHT", -12, FOOTER_HEIGHT + 4)
    modal.list = list

    -- Footer
    local closeFooterBtn = ns.CreateThemedButton(modal.footer)
    closeFooterBtn:SetSize(100, 24)
    closeFooterBtn:SetPoint("RIGHT")
    closeFooterBtn:SetText(L("HISTORY_DETAIL_CLOSE", "Close"))
    styleButton(closeFooterBtn, "primary")
    closeFooterBtn:SetScript("OnClick", function() modal:Hide() end)
    modal.closeFooterBtn = closeFooterBtn

    local statusText = modal.footer:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    statusText:SetPoint("LEFT")
    applyTextColor(statusText, "textMuted", { 0.66, 0.70, 0.79 })
    modal.statusText = statusText

    -- ============================================================
    -- Filter menus + aggregation
    -- ============================================================

    local function distinctInstances()
        local seen, out = {}, {}
        if Loothing.History and Loothing.History.GetEntries then
            for _, e in Loothing.History:GetEntries():Enumerate() do
                if e.instance and e.instance ~= "" and not seen[e.instance] then
                    seen[e.instance] = true
                    out[#out + 1] = e.instance
                end
            end
        end
        table.sort(out)
        return out
    end

    local function distinctBosses(raidFilter)
        local seen, out = {}, {}
        if Loothing.History and Loothing.History.GetEntries then
            for _, e in Loothing.History:GetEntries():Enumerate() do
                if e.encounterName and e.encounterName ~= "" then
                    if not raidFilter or e.instance == raidFilter then
                        if not seen[e.encounterName] then
                            seen[e.encounterName] = true
                            out[#out + 1] = e.encounterName
                        end
                    end
                end
            end
        end
        table.sort(out)
        return out
    end

    function modal:ShowRaidFilterMenu()
        MenuUtil.CreateContextMenu(self.raidFilterBtn, function(_ownerRegion, root)
            root:CreateTitle(L("HISTORY_DETAIL_MATRIX_FILTER_RAID", "Filter by Raid"))
            root:CreateButton(L("HISTORY_DETAIL_MATRIX_FILTER_ALL", "All"), function()
                self:SetRaidFilter(nil)
            end)
            root:CreateDivider()
            for _, name in ipairs(distinctInstances()) do
                root:CreateButton(name, function() self:SetRaidFilter(name) end)
            end
        end)
    end

    function modal:ShowBossFilterMenu()
        MenuUtil.CreateContextMenu(self.bossFilterBtn, function(_ownerRegion, root)
            root:CreateTitle(L("HISTORY_DETAIL_MATRIX_FILTER_BOSS", "Filter by Boss"))
            root:CreateButton(L("HISTORY_DETAIL_MATRIX_FILTER_ALL", "All"), function()
                self:SetBossFilter(nil)
            end)
            root:CreateDivider()
            for _, name in ipairs(distinctBosses(self.filters.raid)) do
                root:CreateButton(name, function() self:SetBossFilter(name) end)
            end
        end)
    end

    function modal:ShowSeasonFilterMenu()
        MenuUtil.CreateContextMenu(self.seasonFilterBtn, function(_ownerRegion, root)
            root:CreateTitle(L("HISTORY_DETAIL_MATRIX_FILTER_SEASON", "Filter by Season"))
            root:CreateButton(L("HISTORY_DETAIL_MATRIX_FILTER_ALL", "All"), function()
                self:SetSeasonFilter(nil)
            end)
            root:CreateDivider()
            if Loothing.Seasons then
                for _, season in ipairs(Loothing.Seasons:GetAll()) do
                    root:CreateButton(season.name, function() self:SetSeasonFilter(season.id) end)
                end
            end
        end)
    end

    function modal:SetRaidFilter(raid)
        self.filters.raid = raid
        -- If the currently-selected boss isn't in the new raid, drop it.
        if raid and self.filters.boss then
            local ok = false
            for _, b in ipairs(distinctBosses(raid)) do
                if b == self.filters.boss then ok = true; break end
            end
            if not ok then self.filters.boss = nil end
        end
        self:RefreshFilterLabels()
        self:Rebuild()
    end

    function modal:SetBossFilter(boss)
        self.filters.boss = boss
        self:RefreshFilterLabels()
        self:Rebuild()
    end

    function modal:SetSeasonFilter(seasonId)
        self.filters.season = seasonId
        self:RefreshFilterLabels()
        self:Rebuild()
    end

    function modal:ClearAllFilters()
        self.filters.raid, self.filters.boss, self.filters.season = nil, nil, nil
        self:RefreshFilterLabels()
        self:Rebuild()
    end

    function modal:RefreshFilterLabels()
        self.raidFilterBtn:SetText(string.format("%s: %s",
            L("HISTORY_DETAIL_MATRIX_FILTER_RAID_LABEL", "Raid"),
            self.filters.raid or L("HISTORY_DETAIL_MATRIX_FILTER_ALL", "All")))
        self.bossFilterBtn:SetText(string.format("%s: %s",
            L("HISTORY_DETAIL_MATRIX_FILTER_BOSS_LABEL", "Boss"),
            self.filters.boss or L("HISTORY_DETAIL_MATRIX_FILTER_ALL", "All")))
        local seasonLabel = L("HISTORY_DETAIL_MATRIX_FILTER_ALL", "All")
        if self.filters.season and Loothing.Seasons then
            local s = Loothing.Seasons:GetById(self.filters.season)
            if s then seasonLabel = s.name end
        end
        self.seasonFilterBtn:SetText(string.format("%s: %s",
            L("HISTORY_DETAIL_MATRIX_FILTER_SEASON_LABEL", "Season"),
            seasonLabel))
    end

    -- Wire filter buttons
    modal.raidFilterBtn:SetScript("OnClick",   function() modal:ShowRaidFilterMenu()   end)
    modal.bossFilterBtn:SetScript("OnClick",   function() modal:ShowBossFilterMenu()   end)
    modal.seasonFilterBtn:SetScript("OnClick", function() modal:ShowSeasonFilterMenu() end)
    modal.clearFilterBtn:SetScript("OnClick",  function() modal:ClearAllFilters()      end)

    -- ============================================================
    -- Sort
    -- ============================================================

    function modal:SortBy(colId)
        local col
        for _, c in ipairs(self.columns) do
            if c.id == colId then col = c; break end
        end
        if not col then return end

        if self.sortCol == colId then
            -- Flip direction
            self.sortDir = (self.sortDir == "asc") and "desc" or "asc"
        else
            self.sortCol = colId
            self.sortDir = col.defaultDir or "desc"
        end
        self:RefreshSortArrows()
        self:Rebuild()
    end

    function modal:RefreshSortArrows()
        for id, btn in pairs(self.headerBtns) do
            if id == self.sortCol then
                btn.arrow:SetText(Loolib.Fonts:Icon(
                    self.sortDir == "asc" and "caret-up" or "caret-down"))
                btn.arrow:Show()
                applyTextColor(btn.labelFS, "accent", { 1, 0.82, 0 })
            else
                btn.arrow:Hide()
                if btn.col.color then
                    btn.labelFS:SetTextColor(btn.col.color.r, btn.col.color.g, btn.col.color.b)
                else
                    applyTextColor(btn.labelFS, "textMuted", { 0.66, 0.70, 0.79 })
                end
            end
        end
    end

    -- ============================================================
    -- Aggregation + rebuild
    -- ============================================================

    local function entryMatchesFilters(entry, filters)
        if filters.raid and entry.instance ~= filters.raid then return false end
        if filters.boss and entry.encounterName ~= filters.boss then return false end
        if filters.season then
            if not Loothing.Seasons then return false end
            if not Loothing.Seasons:EntryMatches(entry, filters.season) then
                return false
            end
        end
        return true
    end

    local RESPONSE_ID_SET
    local function buildResponseIdSet()
        if RESPONSE_ID_SET then return RESPONSE_ID_SET end
        RESPONSE_ID_SET = {}
        for _, id in ipairs(Loothing.ResponsePriority or {}) do
            RESPONSE_ID_SET[id] = true
        end
        return RESPONSE_ID_SET
    end

    function modal:Aggregate()
        local rows = {}
        local byName = {}
        if not Loothing.History or not Loothing.History.GetEntries then
            return rows, 0, 0
        end
        local knownResponses = buildResponseIdSet()
        local totalResponses, totalAwards = 0, 0

        local WAIT = Loothing.SystemResponse and Loothing.SystemResponse.WAIT
        local NOTANNOUNCED = Loothing.SystemResponse and Loothing.SystemResponse.NOTANNOUNCED

        local function upsertPlayer(name, class)
            if not name then return nil end
            local r = byName[name]
            if r then
                if not r.playerClass and class then r.playerClass = class end
                return r
            end
            r = {
                playerName = name,
                playerClass = class,
                shortName = Utils.GetShortName(name) or name,
                counts = {},
                otherCount = 0,
                wins = 0,
                total = 0,
            }
            byName[name] = r
            rows[#rows + 1] = r
            return r
        end

        for _, entry in Loothing.History:GetEntries():Enumerate() do
            if entryMatchesFilters(entry, self.filters) then
                -- Count every candidate's submitted response (winners AND
                -- non-winners) so players who rolled-but-lost still appear.
                if entry.candidates then
                    for _, c in ipairs(entry.candidates) do
                        -- Only count candidates with an actual submitted
                        -- response. WAIT / NOTANNOUNCED mean the roll
                        -- never resolved; nil means never responded.
                        local rId = c.response
                        if c.playerName and rId ~= nil
                            and rId ~= WAIT and rId ~= NOTANNOUNCED
                        then
                            local r = upsertPlayer(c.playerName, c.playerClass)
                            if r then
                                if type(rId) == "number" and knownResponses[rId] then
                                    r.counts[rId] = (r.counts[rId] or 0) + 1
                                else
                                    r.otherCount = r.otherCount + 1
                                end
                                r.total = r.total + 1
                                totalResponses = totalResponses + 1
                            end
                        end
                    end
                end

                -- Track wins on a separate axis — this ensures the matrix
                -- shows an accurate award count even for legacy entries
                -- where `candidates[]` is missing. If the winner ONLY
                -- appears as a winner (no candidate entry), they still
                -- get a row with Won = 1 and zeroes elsewhere.
                if entry.winner then
                    local r = upsertPlayer(entry.winner, entry.winnerClass)
                    if r then
                        r.wins = r.wins + 1
                        totalAwards = totalAwards + 1
                    end
                end
            end
        end
        return rows, totalResponses, totalAwards
    end

    function modal:SortRows(rows)
        local col
        for _, c in ipairs(self.columns) do
            if c.id == self.sortCol then col = c; break end
        end
        if not col or not col.sortKey then return end
        local desc = (self.sortDir == "desc")
        table.sort(rows, function(a, b)
            local ka, kb = col.sortKey(a), col.sortKey(b)
            if ka == kb then
                -- Stable tiebreak by player name
                return (a.shortName or "") < (b.shortName or "")
            end
            if type(ka) == "number" and type(kb) == "number" then
                if desc then return ka > kb else return ka < kb end
            else
                local sa, sb = tostring(ka), tostring(kb)
                if desc then return sa > sb else return sa < sb end
            end
        end)
    end

    function modal:Rebuild()
        local rows, totalResponses, totalAwards = self:Aggregate()
        self:SortRows(rows)
        self.list:Refresh(rows)

        local uniquePlayers = #rows
        self.statusText:SetText(string.format(
            L("HISTORY_DETAIL_MATRIX_STATUS_FMT",
                "%d players   •   %d responses   •   %d awards"),
            uniquePlayers, totalResponses, totalAwards))
    end

    function modal:Bind()
        self:RefreshFilterLabels()
        self:RefreshSortArrows()
        self:Rebuild()
    end

    function modal:OnHideCleanup()
        -- Filters and sort persist across opens intentionally; this is a
        -- leaderboard the user refines over time. Nothing to clear here.
    end

    -- Live refresh on history mutation
    if Loothing.History and Loothing.History.RegisterCallback then
        Loothing.History:RegisterCallback("OnHistoryChanged", function()
            if modal:IsShown() then modal:Rebuild() end
        end, modal)
    end

    local baseApplyTheme = modal.ApplyTheme
    function modal:ApplyTheme()
        baseApplyTheme(self)
        styleButton(self.raidFilterBtn, "default")
        styleButton(self.bossFilterBtn, "default")
        styleButton(self.seasonFilterBtn, "default")
        styleButton(self.clearFilterBtn, "primary")
        styleButton(self.closeFooterBtn, "primary")
        if self.list then self.list:ApplyTheme() end
        applyTextColor(self.statusText, "textMuted", { 0.66, 0.70, 0.79 })
        -- Re-tint headers (accent on the active sort column) and preserve
        -- the response color accents on the others.
        if self.RefreshSortArrows then self:RefreshSortArrows() end
    end

    awardMatrixInstance = modal
    return modal
end

--- Open the Award Matrix modal — a per-player / per-response-type
--- leaderboard with raid / boss / season filters and click-to-sort
--- column headers. Default sort: Total descending.
function ns.ShowAwardMatrix()
    local modal = getAwardMatrixInstance()
    modal:Bind()
    modal:Show()
end

--[[======================================================================
    Theme refresh dispatch

    SkinningMixin:RefreshTheme iterates a list of panels whose ApplyTheme
    should fire on skin/accent/density change. Expose a single entry point
    that live-repaints any of the four lazy singletons if they've been
    instantiated. Hook this into Skinning.lua's dispatch list.
======================================================================]]

ns.HistoryDetailFrames = {
    ApplyTheme = function()
        refreshHoverAccents()
        if detailInstance and detailInstance.ApplyTheme then detailInstance:ApplyTheme() end
        if summaryInstance and summaryInstance.ApplyTheme then summaryInstance:ApplyTheme() end
        if candidateInstance and candidateInstance.ApplyTheme then candidateInstance:ApplyTheme() end
        if voterInstance and voterInstance.ApplyTheme then voterInstance:ApplyTheme() end
        if raidSummaryInstance and raidSummaryInstance.ApplyTheme then raidSummaryInstance:ApplyTheme() end
        if bossSummaryInstance and bossSummaryInstance.ApplyTheme then bossSummaryInstance:ApplyTheme() end
        if seasonSummaryInstance and seasonSummaryInstance.ApplyTheme then seasonSummaryInstance:ApplyTheme() end
        if browserInstance and browserInstance.ApplyTheme then browserInstance:ApplyTheme() end
        if awardMatrixInstance and awardMatrixInstance.ApplyTheme then awardMatrixInstance:ApplyTheme() end
        if itemSummaryInstance and itemSummaryInstance.ApplyTheme then itemSummaryInstance:ApplyTheme() end
    end,
}

