--[[--------------------------------------------------------------------
    Loothing - ItemTooltipHover

    Shift-gated, strata-aware GameTooltip helper for browser & item
    selector hover targets.

    Two problems this solves:

      1. The native GameTooltip lives on the TOOLTIP strata, which is
         above DIALOG. When a Loothing modal (HistoryDetailFrame, etc.)
         stacks over a row in MainFrame, hovering that row would still
         render its tooltip *above* the covering modal. We pin the
         tooltip to the owner's strata + a higher level so a modal that
         visually covers the owner also covers its tooltip.

      2. Item tooltips in the browser and the new LootPickerFrame are
         spammy when the user is just scanning lists. They now show only
         while Shift is held. Toggling Shift while hovering shows / hides
         the tooltip live without forcing the user to re-enter the row.

    API:

      ns.AttachItemTooltip(region, getLink, extraLines, anchor)
        Convenience for a row that displays a single item link.
        getLink and extraLines may each be either a value or a thunk.
        extraLines and anchor are optional.

      ns.AttachShiftTooltip(region, setupFn, anchor)
        Generic form. setupFn(GameTooltip, region) populates the tooltip
        and may return false to abort (Hide is called automatically).
        anchor is optional and defaults to "ANCHOR_RIGHT".
----------------------------------------------------------------------]]

local _, ns = ...

local hover -- { region, setup, anchor }
local listener

local function resolve(value)
    if type(value) == "function" then return value() end
    return value
end

local function pinStrata(owner)
    local strata = owner:GetFrameStrata() or "TOOLTIP"
    local level = (owner:GetFrameLevel() or 0) + 10
    GameTooltip:SetFrameStrata(strata)
    GameTooltip:SetFrameLevel(level)
end

local function showTooltip(state)
    GameTooltip:SetOwner(state.region, state.anchor)
    pinStrata(state.region)
    local ok = state.setup(GameTooltip, state.region)
    if ok == false then
        GameTooltip:Hide()
        return
    end
    GameTooltip:Show()
end

local function hideTooltip()
    GameTooltip:Hide()
    GameTooltip:SetFrameStrata("TOOLTIP")
    GameTooltip:SetFrameLevel(1)
end

local function ensureListener()
    if listener then return end
    listener = CreateFrame("Frame")
    listener:RegisterEvent("MODIFIER_STATE_CHANGED")
    listener:SetScript("OnEvent", function(_, _, key, down)
        if not hover then return end
        if key ~= "LSHIFT" and key ~= "RSHIFT" then return end
        if down == 1 then
            showTooltip(hover)
        else
            hideTooltip()
        end
    end)
end

function ns.AttachShiftTooltip(region, setupFn, anchor)
    ensureListener()
    region:EnableMouse(true)
    region:SetScript("OnEnter", function(r)
        hover = { region = r, setup = setupFn, anchor = anchor or "ANCHOR_RIGHT" }
        if IsShiftKeyDown() then showTooltip(hover) end
    end)
    region:SetScript("OnLeave", function()
        hover = nil
        hideTooltip()
    end)
end

function ns.AttachItemTooltip(region, getLink, extraLines, anchor)
    ns.AttachShiftTooltip(region, function(tt)
        local link = resolve(getLink)
        if not link then return false end
        tt:SetHyperlink(link)
        local extra = resolve(extraLines)
        if extra then
            for _, line in ipairs(extra) do
                tt:AddLine(line, 1, 0.82, 0)
            end
        end
    end, anchor)
end
