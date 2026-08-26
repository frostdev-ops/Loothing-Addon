local _, ns = ...
--[[--------------------------------------------------------------------
    Loothing - ModalFactory

    Shared modal-chrome factory for polished Loothing modals. Originally
    lived inside UI/HistoryDetailFrame.lua; extracted so other modal
    families (PlayerIntelFrame, and future consumers) can build on the
    same chrome without duplicating ~500 lines of plumbing.

    Exposes (via `ns.ModalFactory`):
        CreateModal(globalName, width, height, titleText, opts?)
            Returns a modal mixin pre-wired with:
              • DIALOG strata, level 110
              • Gradient accent strip (SkinningMixin accent)
              • Pixel border (borderStrong)
              • Title + subtitle FontStrings
              • Close button with AttachIconButtonPolish
              • Drag-to-move, clamped, ESC-close via UISpecialFrames
              • Resize grip + SetResizeBounds(width, height, 1600, 1000)
              • OnHide cleanup (stops fade group, resets alpha to 0)
              • modal:Show() / :Hide() with 0.22/0.13s fade
              • modal:ApplyTheme() re-paints chrome from skin

        CreateTabStrip(parent, tabDefs, onSelect)
            Horizontal tab row with a sliding indicator.
            tabDefs = { { id, text }, ... }
            strip:SelectTab(id) → paints tabs + animates indicator

        CreateScrollList(parent, opts)
            Pool-backed vertical list.
            opts = { rowHeight, rowSpacing, emptyMessage, initRow, bindRow }
            list:Refresh(entries) → rebuild rows from an array

        AddRowHoverAccent(row)    — HIGHLIGHT-layer 3px accent bar
        RefreshHoverAccents()     — re-tint every tracked bar

        skinColor / applyTextColor / styleSurface / styleButton
            Thin shims over SkinningMixin.

    Contract & lessons — see the `loothing-ui-polish` skill for the
    full set. Key ones enforced here:

      • `AnimationUtil.CreateGroup` is dot form (not colon).
      • `SetAlpha(0)` before FadeIn so an interrupted fade can't leave
        alpha stuck at a partial value.
      • Hide via AnimationPresets.FadeOut which snaps alpha in its
        onFinished callback; OnHide hook is defensive.
      • Tab indicator is parented to the container, positioned via
        BOTTOMLEFT → BOTTOMLEFT offset, so parent resizes reflow it.
      • Row pool uses BackdropTemplate so `row:SetBackdrop(...)` works.
      • _allRows tracks every row ever acquired so skin-change retints
        pool-idle rows, not just visible ones.

    Dependencies (load order):
        Loolib.AnimationUtil / AnimationPresets / PixelUtil  (Loolib)
        ns.FramePolish.ApplyAccentGlow                       (UI/FramePolish.lua)
        ns.FramePolish.AttachIconButtonPolish                (UI/FramePolish.lua)
        ns.SkinningMixin                                     (Core/Init.lua)
        ns.ApplyThemedScrollBar                              (UI/ThemedScrollBar.lua)
----------------------------------------------------------------------]]

local Loolib = LibStub("Loolib")

local AnimationUtil    = Loolib.AnimationUtil
local AnimationPresets = Loolib.AnimationPresets
local PixelUtil        = Loolib.PixelUtil

-- SkinningMixin + FramePolish are resolved at CALL time, not file-load
-- time, because Skinning.lua / FramePolish.lua may have loaded after
-- this file in some TOC orderings. All helpers below go through these
-- getters so they pick up the live module whenever it becomes available.
local function getSkinning()  return ns.SkinningMixin end
local function getFramePolish() return ns.FramePolish end

--[[--------------------------------------------------------------------
    Default dimensions — callers can override per-modal.
----------------------------------------------------------------------]]

local DEFAULT_HEADER_HEIGHT = 52
local DEFAULT_TAB_HEIGHT    = 30
local DEFAULT_FOOTER_HEIGHT = 40
local DEFAULT_ROW_HEIGHT    = 28

--[[--------------------------------------------------------------------
    Skin helpers
----------------------------------------------------------------------]]

local function skinColor(key, fallback)
    local sk = getSkinning()
    if sk and sk.GetColor then
        return sk:GetColor(key, fallback)
    end
    return fallback or { 1, 1, 1, 1 }
end

local function styleSurface(frame, variant)
    if not frame then return end
    local sk = getSkinning()
    if sk and sk.StyleSurface then
        sk:StyleSurface(frame, variant)
    end
end

local function applyTextColor(fs, key, fallback)
    if not fs then return end
    local c = skinColor(key, fallback)
    fs:SetTextColor(c[1], c[2], c[3], c[4] or 1)
end

local function styleButton(btn, variant)
    if not btn then return end
    local sk = getSkinning()
    if sk and sk.StylePlainButton then
        sk:StylePlainButton(btn, variant)
    end
end

local function applyAccentGlow(texture, topAlpha)
    local fp = getFramePolish()
    if fp and type(fp.ApplyAccentGlow) == "function" then
        fp.ApplyAccentGlow(texture, topAlpha)
    end
end

local function attachIconButtonPolish(button, opts)
    local fp = getFramePolish()
    if fp and type(fp.AttachIconButtonPolish) == "function" then
        fp.AttachIconButtonPolish(button, opts)
    end
end

--[[--------------------------------------------------------------------
    Hover accent registry

    Row frames register a 3px HIGHLIGHT-layer bar on their left edge.
    HIGHLIGHT textures only draw while the cursor is over the frame —
    zero script cost while idle, no OnEnter/OnLeave hook chain, and
    they compose cleanly with any tooltip script the row sets up
    separately. Theme-refresh retints every tracked bar.
----------------------------------------------------------------------]]

-- Weak-keyed registry: if a row frame is ever destroyed the texture
-- entry gets collected rather than pinned here indefinitely. (Row
-- frames are pooled in practice, so this is primarily intent.)
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

local function refreshHoverAccents()
    local c = skinColor("accent", { 1, 0.82, 0 })
    for tex in pairs(hoverAccentRegistry) do
        if type(tex.SetColorTexture) == "function" then
            tex:SetColorTexture(c[1], c[2], c[3], c[4] or 1)
        end
    end
end

--[[--------------------------------------------------------------------
    Modal factory
----------------------------------------------------------------------]]

local function CreateModal(globalName, width, height, titleText, opts)
    opts = opts or {}
    local headerHeight = opts.headerHeight or DEFAULT_HEADER_HEIGHT
    local footerHeight = opts.footerHeight or DEFAULT_FOOTER_HEIGHT
    local minWidth  = opts.minWidth  or width
    local minHeight = opts.minHeight or height
    local maxWidth  = opts.maxWidth  or 1600
    local maxHeight = opts.maxHeight or 1000
    local resizeHintText = opts.resizeHint or "Drag to resize"
    -- Callers can pass resizable=false when the modal's tabs have fixed
    -- layouts that won't reflow; we hide the grip entirely instead of
    -- rendering a dead handle the user can hover over.
    local resizable = opts.resizable
    if resizable == nil then resizable = (minWidth ~= maxWidth) or (minHeight ~= maxHeight) end

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
        local sk = getSkinning()
        if sk and sk.SaveFrameState then
            sk:SaveFrameState(f, globalName)
        end
    end)

    frame:SetResizable(resizable)
    if resizable then
        if frame.SetResizeBounds then
            frame:SetResizeBounds(minWidth, minHeight, maxWidth, maxHeight)
        elseif frame.SetMinResize then
            frame:SetMinResize(minWidth, minHeight)
            frame:SetMaxResize(maxWidth, maxHeight)
        end
    end

    frame:Hide()
    frame:SetAlpha(0)

    styleSurface(frame, "frame")
    local sk = getSkinning()
    if sk and sk.DecorateWindow then sk:DecorateWindow(frame) end

    -- Gradient accent strip behind the title
    local headerStrip = frame:CreateTexture(nil, "BACKGROUND", nil, 2)
    headerStrip:SetPoint("TOPLEFT", 2, -2)
    headerStrip:SetPoint("TOPRIGHT", -2, -2)
    headerStrip:SetHeight(headerHeight - 8)
    headerStrip:SetColorTexture(1, 1, 1, 1)
    applyAccentGlow(headerStrip, 0.18)

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

    -- Subtitle (optional)
    local subtitle = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    subtitle:SetPoint("TOPLEFT", 14, -32)
    applyTextColor(subtitle, "textMuted", { 0.7, 0.7, 0.7 })

    -- Close button
    local closeBtn = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    closeBtn:SetSize(22, 22)
    closeBtn:SetPoint("TOPRIGHT", -2, -2)
    attachIconButtonPolish(closeBtn, { hoverScale = 1.15, pressScale = 0.90 })

    -- Content container (callers attach children here)
    local content = CreateFrame("Frame", nil, frame)
    content:SetPoint("TOPLEFT", 10, -(headerHeight))
    content:SetPoint("BOTTOMRIGHT", -10, footerHeight + 4)

    -- Footer (callers attach buttons here)
    local footer = CreateFrame("Frame", nil, frame)
    footer:SetPoint("BOTTOMLEFT", 10, 8)
    footer:SetPoint("BOTTOMRIGHT", -10, 8)
    footer:SetHeight(footerHeight - 8)

    -- Resize grip. Dimensions match HistoryDetailFrame.lua so the two modal
    -- families stay visually identical (12×12 at -1/+1 offsets, diagonal
    -- line inset math uses inset*2 for height and -1 - inset*3 for x).
    -- Only built when the modal is resizable; otherwise a visible grip
    -- that doesn't respond to drags would confuse the user.
    local resizeGrip
    if resizable then
        resizeGrip = CreateFrame("Button", nil, frame)
        resizeGrip:SetSize(12, 12)
        resizeGrip:SetPoint("BOTTOMRIGHT", -1, 1)
        resizeGrip:SetFrameLevel(frame:GetFrameLevel() + 5)

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
        resizeGrip._highlight = hl  -- Named reference so ApplyTheme can re-tint it directly.

        resizeGrip:SetScript("OnMouseDown", function(_, btn)
            if btn == "LeftButton" then frame:StartSizing("BOTTOMRIGHT") end
        end)
        resizeGrip:SetScript("OnMouseUp", function()
            frame:StopMovingOrSizing()
            local sk2 = getSkinning()
            if sk2 and sk2.SaveFrameState then
                sk2:SaveFrameState(frame, globalName)
            end
        end)
        resizeGrip:SetScript("OnEnter", function()
            GameTooltip:SetOwner(resizeGrip, "ANCHOR_TOP")
            GameTooltip:SetText(resizeHintText)
            GameTooltip:Show()
        end)
        resizeGrip:SetScript("OnLeave", function() GameTooltip:Hide() end)
    end

    local modal = {
        frame       = frame,
        headerStrip = headerStrip,
        pixelBorder = pixelBorder,
        title       = title,
        subtitle    = subtitle,
        closeBtn    = closeBtn,
        content     = content,
        footer      = footer,
        resizeGrip  = resizeGrip,
        globalName  = globalName,
    }

    closeBtn:SetScript("OnClick", function() modal:Hide() end)

    -- Position persistence + ESC-to-close via UISpecialFrames
    if sk and sk.SetupFrame then
        sk:SetupFrame(frame, globalName, globalName, {
            escapeClose    = true,
            combatMinimize = false,
        })
    end

    -- SetupFrame calls LoadFrameState, which reapplies any persisted
    -- width/height from SavedVariables. For non-resizable modals that's
    -- wrong: a size saved during a pre-release build (or a future flip
    -- back to resizable=true and back) could shrink the modal below its
    -- designed dimensions and clip tabs. Pin the authoritative size back
    -- after LoadFrameState runs.
    if not resizable then
        frame:SetSize(width, height)
    end

    -- Belt-and-suspenders: cancel any in-flight drag-move or resize if the
    -- frame gets hidden mid-gesture (ESC during resize, combat auto-hide,
    -- etc.). Without this the frame reopens in a sizing state and steals
    -- further mouse input.
    frame:HookScript("OnHide", function(f) f:StopMovingOrSizing() end)

    -- Route every Hide (ESC via UISpecialFrames, external Hide(), parent
    -- tear-down) through cleanup: stop in-flight fade, reset alpha to 0,
    -- then invoke the caller's OnHideCleanup if defined.
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
            self.frame._loothingFadeGroup = AnimationPresets.FadeOut(
                self.frame, 0.13, "inCubic", true,
                function() if self.frame then self.frame:SetAlpha(0) end end)
        else
            self.frame:Hide()
        end
    end

    function modal:IsShown()
        return self.frame and self.frame:IsShown() or false
    end

    function modal:SetTitle(text)    self.title:SetText(text or "") end
    function modal:SetSubtitle(text) self.subtitle:SetText(text or "") end

    --- Re-apply all theme-driven paint. Called from :Show() and from
    --- the outer ApplyTheme() dispatch.
    function modal:ApplyTheme()
        styleSurface(self.frame, "frame")
        applyTextColor(self.title, "text", { 1, 0.82, 0 })
        applyTextColor(self.subtitle, "textMuted", { 0.7, 0.7, 0.7 })
        if self.headerStrip then
            applyAccentGlow(self.headerStrip, 0.18)
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
        if self.resizeGrip and self.resizeGrip._highlight then
            self.resizeGrip._highlight:SetColorTexture(unpack(skinColor("accent", { 1, 0.82, 0, 1 })))
            self.resizeGrip._highlight:SetAlpha(0.35)
        end
    end

    return modal
end

--[[--------------------------------------------------------------------
    Tab strip factory
----------------------------------------------------------------------]]

local function CreateTabStrip(parent, tabDefs, onSelect, opts)
    opts = opts or {}
    local tabHeight = opts.tabHeight or DEFAULT_TAB_HEIGHT
    local tabWidth  = opts.tabWidth  or 110
    local spacing   = opts.spacing   or 4

    local tabContainer = CreateFrame("Frame", nil, parent)
    tabContainer:SetPoint("TOPLEFT", 0, 0)
    tabContainer:SetPoint("TOPRIGHT", 0, 0)
    tabContainer:SetHeight(tabHeight + 6)

    local indicator = tabContainer:CreateTexture(nil, "OVERLAY", nil, 7)
    indicator:SetHeight(3)
    indicator:SetPoint("BOTTOMLEFT", tabContainer, "BOTTOMLEFT", 2, 2)
    indicator:SetWidth(0)
    indicator:SetColorTexture(1, 1, 1, 1)
    indicator:Hide()

    local strip = {
        container    = tabContainer,
        indicator    = indicator,
        tabs         = {},
        order        = {},
        currentId    = nil,
        _positioned  = false,
    }

    local xOffset = 0
    for _, def in ipairs(tabDefs) do
        local tab = CreateFrame("Button", nil, tabContainer, "BackdropTemplate")
        tab:SetSize(tabWidth, tabHeight)
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
        local sk = getSkinning()
        if sk and sk.StyleText then
            sk:StyleText(text, "header", "textMuted")
        end
        tab.text = text
        tab.id = def.id

        local tabId = def.id
        tab:SetScript("OnClick", function() strip:SelectTab(tabId) end)

        strip.tabs[def.id] = tab
        strip.order[#strip.order + 1] = def.id
        xOffset = xOffset + tabWidth + spacing
    end

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
            baseAnchor = {
                point = "BOTTOMLEFT", relativeTo = self.container,
                relativePoint = "BOTTOMLEFT", x = curX, y = 2,
            },
            from = { 0, 0 },
            to = { targetX - curX, 0 },
            duration = 0.22,
            easing = "outCubic",
        })
        group:CreateAnimation("width", {
            target   = self.indicator,
            from     = curWidth,
            to       = targetWidth,
            duration = 0.22,
            easing   = "outCubic",
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
----------------------------------------------------------------------]]

local function CreateScrollList(parent, opts)
    opts = opts or {}
    local rowHeight    = opts.rowHeight    or DEFAULT_ROW_HEIGHT
    local rowSpacing   = opts.rowSpacing   or 2
    local initRow      = opts.initRow
    local bindRow      = opts.bindRow
    local emptyMessage = opts.emptyMessage or "No data."

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
    content:SetPoint("TOPLEFT", 0, 0)
    content:SetSize(1, 1)
    scrollFrame:SetScrollChild(content)
    scrollFrame:SetScript("OnSizeChanged", function(_sf, w, _h)
        content:SetWidth(w)
        if _sf.UpdateScrollChildRect then _sf:UpdateScrollChildRect() end
        if _sf.SetVerticalScroll and _sf.GetVerticalScroll then
            _sf:SetVerticalScroll(_sf:GetVerticalScroll() or 0)
        end
    end)

    if ns.ApplyThemedScrollBar then
        ns.ApplyThemedScrollBar(scrollFrame, {
            autoHide    = true,
            showButtons = true,
            thickness   = 10,
        })
    end

    -- Reset does NOT nil the row scripts: initRow installs them exactly
    -- once (guarded by row._initialized) and their closures read row
    -- fields that bindRow rewrites on every acquire — the same
    -- install-once pattern as CouncilTable rows. Nil'ing scripts here
    -- while keeping _initialized set permanently killed every
    -- initRow-installed handler (wishlist shift-tooltips, row clicks)
    -- after the first Refresh; re-running initRow instead would leak a
    -- fresh set of FontStrings per release/acquire cycle.
    local rowPool = CreateFramePool("Button", content, "BackdropTemplate", function(_p, row)
        row:Hide()
        row:ClearAllPoints()
    end)

    local emptyText = container:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    emptyText:SetPoint("CENTER")
    emptyText:SetText(emptyMessage)
    applyTextColor(emptyText, "textSubtle", { 0.5, 0.5, 0.5 })
    emptyText:Hide()

    local list = {
        container   = container,
        scrollFrame = scrollFrame,
        content     = content,
        rowPool     = rowPool,
        emptyText   = emptyText,
        pixelBorder = pixelBorder,
        _rows       = {},
        _allRows    = {},
    }

    local function registerRow(self, row)
        if not row._registered then
            row._registered = true
            self._allRows[#self._allRows + 1] = row
        end
    end

    function list:Refresh(entries)
        for _, row in ipairs(self._rows) do
            self.rowPool:Release(row)
        end
        wipe(self._rows)

        -- Reset scroll offset and hide any lingering hyperlink tooltip
        -- from a row that was hovered when the previous bind tore down.
        -- Without this, binding a new player with fewer items leaves the
        -- scroll parked at a position that's now outside the content
        -- range (visually blank), and an item tooltip from the prior
        -- player can linger over the new modal until mouse-leave.
        if self.scrollFrame and self.scrollFrame.SetVerticalScroll then
            self.scrollFrame:SetVerticalScroll(0)
        end
        if GameTooltip and GameTooltip:IsShown() then
            GameTooltip:Hide()
        end

        local count = entries and #entries or 0
        if count == 0 then
            self.emptyText:Show()
            self.content:SetHeight(1)
            -- Even on empty, force a scroll-range recompute so the themed
            -- scrollbar reliably hides itself (it auto-hides when the
            -- range is ≤ 1, but needs a recompute tick to notice).
            if self.scrollFrame.UpdateScrollChildRect then
                self.scrollFrame:UpdateScrollChildRect()
            end
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
        local rowColor = skinColor("rowAlt", { 0.06, 0.07, 0.1, 0.5 })
        for _, row in ipairs(self._allRows) do
            if row.SetBackdropColor then
                row:SetBackdropColor(rowColor[1], rowColor[2], rowColor[3], rowColor[4] or 1)
            end
        end
    end

    return list
end

--[[--------------------------------------------------------------------
    Public surface
----------------------------------------------------------------------]]

ns.ModalFactory = {
    -- Factory functions
    CreateModal      = CreateModal,
    CreateTabStrip   = CreateTabStrip,
    CreateScrollList = CreateScrollList,

    -- Row hover accents
    AddRowHoverAccent   = addRowHoverAccent,
    RefreshHoverAccents = refreshHoverAccents,

    -- Skin shims
    SkinColor      = skinColor,
    StyleSurface   = styleSurface,
    ApplyTextColor = applyTextColor,
    StyleButton    = styleButton,

    -- FramePolish passthroughs (kept here so callers can go through a
    -- single entry point even if FramePolish ends up being renamed later)
    ApplyAccentGlow        = applyAccentGlow,
    AttachIconButtonPolish = attachIconButtonPolish,
}
