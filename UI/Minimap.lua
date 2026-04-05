--[[--------------------------------------------------------------------
    Loothing - Loot Council Addon for WoW 12.0+
    Minimap - Addon Compartment + custom minimap button
----------------------------------------------------------------------]]

local ADDON_NAME, ns = ...
local Loolib = LibStub("Loolib")
local Config = Loolib.Config
local GlobalBridge = Loolib.Compat.GlobalBridge
local CreateFromMixins = Loolib.CreateFromMixins
local Loothing = ns.Addon
local Utils = ns.Utils

local LOGO_TEXTURE = "Interface\\AddOns\\Loothing\\Media\\logo"

local function OnAddonCompartmentClick(_, mouseButton)
    if mouseButton == "RightButton" then
        if Config then
            Config:Open("Loothing")
        end
    else
        if Loothing and Loothing.UI and Loothing.UI.MainFrame then
            Loothing.UI.MainFrame:Toggle()
        end
    end
end

local function OnAddonCompartmentEnter(_, menuButtonFrame)
    GameTooltip:SetOwner(menuButtonFrame, "ANCHOR_LEFT")
    GameTooltip:AddLine("Loothing", 1, 0.82, 0)
    local version = (Loothing and Loothing.version) or Loothing.VERSION or "1.0.0"
    GameTooltip:AddLine("v" .. version, 0.5, 0.5, 0.5)
    GameTooltip:AddLine(" ")
    local L = Loothing.Locale
    if L then
        GameTooltip:AddLine(L["MINIMAP_TOOLTIP_LEFT"], 1, 1, 1)
        GameTooltip:AddLine(L["MINIMAP_TOOLTIP_RIGHT"], 1, 1, 1)
    end
    GameTooltip:Show()
end

local function OnAddonCompartmentLeave()
    GameTooltip:Hide()
end

GlobalBridge:RegisterAddonCompartment(ADDON_NAME, {
    OnClick = OnAddonCompartmentClick,
    OnEnter = OnAddonCompartmentEnter,
    OnLeave = OnAddonCompartmentLeave,
})

--[[--------------------------------------------------------------------
    Custom Minimap Button (traditional edge-of-minimap icon)

    Modelled after MRT's working implementation. Uses shape-aware
    positioning that works with round, square, and corner minimaps.
----------------------------------------------------------------------]]

local MinimapButtonMixin = ns.MinimapButtonMixin or {}
ns.MinimapButtonMixin = MinimapButtonMixin

local BUTTON_SIZE = 32
local ICON_SIZE = 20

-- Minimap shape lookup for positioning
local minimapShapes = {
    ["ROUND"] = {true, true, true, true},
    ["SQUARE"] = {false, false, false, false},
    ["CORNER-TOPLEFT"] = {false, false, false, true},
    ["CORNER-TOPRIGHT"] = {false, false, true, false},
    ["CORNER-BOTTOMLEFT"] = {false, true, false, false},
    ["CORNER-BOTTOMRIGHT"] = {true, false, false, false},
    ["SIDE-LEFT"] = {false, true, false, true},
    ["SIDE-RIGHT"] = {true, false, true, false},
    ["SIDE-TOP"] = {false, false, true, true},
    ["SIDE-BOTTOM"] = {true, true, false, false},
    ["TRICORNER-TOPLEFT"] = {false, true, true, true},
    ["TRICORNER-TOPRIGHT"] = {true, false, true, true},
    ["TRICORNER-BOTTOMLEFT"] = {true, true, false, true},
    ["TRICORNER-BOTTOMRIGHT"] = {true, true, true, false},
}

--- Initialize the minimap button
function MinimapButtonMixin:Init()
    self.angle = 225 -- Default position (degrees)
    self.isDragging = false

    -- Load saved position
    self:LoadPosition()

    -- Create the button
    self:CreateButton()

    -- Update visibility based on settings
    self:UpdateVisibility()
end

--- Create the minimap button frame
function MinimapButtonMixin:CreateButton()
    local button = CreateFrame("Button", "LoothingMinimapButton", Minimap)
    button:SetSize(BUTTON_SIZE, BUTTON_SIZE)
    button:SetFrameStrata("MEDIUM")
    button:SetFrameLevel(8)
    button:SetDontSavePosition(true)

    -- Icon (BACKGROUND layer - sits behind the border overlay)
    local icon = button:CreateTexture(nil, "BACKGROUND")
    icon:SetSize(ICON_SIZE, ICON_SIZE)
    icon:SetPoint("CENTER", 1, 0)
    icon:SetTexture(LOGO_TEXTURE)
    button.icon = icon

    -- Border (ARTWORK layer - overlays the icon to give circular clipping look)
    local border = button:CreateTexture(nil, "ARTWORK")
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    border:SetTexCoord(0, 0.6, 0, 0.6)
    border:SetAllPoints()

    -- Highlight
    button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

    -- Scripts
    button:RegisterForClicks("AnyUp")
    button:RegisterForDrag("LeftButton")

    button:SetScript("OnMouseUp", function(_, btn)
        self:OnClick(btn)
    end)

    button:SetScript("OnEnter", function()
        self:OnEnter()
    end)

    button:SetScript("OnLeave", function()
        self:OnLeave()
    end)

    button:SetScript("OnDragStart", function()
        self:OnDragStart()
    end)

    button:SetScript("OnDragStop", function()
        self:OnDragStop()
    end)

    self.button = button

    -- Position the button
    self:UpdatePosition()
end

--- Update button position on minimap (shape-aware)
function MinimapButtonMixin:UpdatePosition()
    if not self.button then return end

    local angle = math.rad(self.angle)
    local x, y = math.cos(angle), math.sin(angle)

    -- Determine quadrant
    local q = 1
    if x < 0 then q = q + 1 end
    if y > 0 then q = q + 2 end

    local getMinimapShape = _G["GetMinimapShape"]
    local minimapShape = getMinimapShape and getMinimapShape() or "ROUND"
    local quadTable = minimapShapes[minimapShape]

    local w = (Minimap:GetWidth() / 2) + 5
    local h = (Minimap:GetHeight() / 2) + 5

    if quadTable and quadTable[q] then
        x, y = x * w, y * h
    else
        local diagRadiusW = math.sqrt(2 * w ^ 2) - 10
        local diagRadiusH = math.sqrt(2 * h ^ 2) - 10
        x = math.max(-w, math.min(x * diagRadiusW, w))
        y = math.max(-h, math.min(y * diagRadiusH, h))
    end

    self.button:ClearAllPoints()
    self.button:SetPoint("CENTER", Minimap, "CENTER", x, y)
end

--- Handle click
-- @param mouseButton string
function MinimapButtonMixin:OnClick(mouseButton)
    if self.isDragging then return end

    if mouseButton == "LeftButton" then
        if Loothing.UI and Loothing.UI.MainFrame then
            Loothing.UI.MainFrame:Toggle()
        end
    elseif mouseButton == "RightButton" then
        self:ShowContextMenu()
    end
end

--- Show context menu
function MinimapButtonMixin:ShowContextMenu()
    local L = Loothing.Locale

    MenuUtil.CreateContextMenu(self.button, function(_, rootDescription)
        rootDescription:CreateTitle("Loothing")
        rootDescription:CreateButton(L["OPEN_MAIN_WINDOW"], function()
            if Loothing.UI and Loothing.UI.MainFrame then
                Loothing.UI.MainFrame:Show()
            end
        end)
        rootDescription:CreateButton(L["SETTINGS"], function()
            if Config then
                Config:Open("Loothing")
            end
        end)
        if Loothing.Session and Loothing.Session:IsActive() then
            local L = Loothing.Locale
            rootDescription:CreateDivider()
            rootDescription:CreateTitle(L and L["MINIMAP_ACTIVE_SESSION"] or "Active Session")
            rootDescription:CreateButton(L and L["MINIMAP_REOPEN_COUNCIL"] or "Reopen Council Table", function()
                local ct = Loothing.UI and Loothing.UI.CouncilTable
                if ct then ct:Show() end
            end)
            rootDescription:CreateButton(L and L["MINIMAP_REOPEN_RESPONSE"] or "Reopen Response Frame", function()
                local tracker = Loothing.ResponseTracker
                if tracker and tracker:GetUnrespondedCount() > 0 then
                    tracker:CheckAndReshowFrame()
                end
            end)
            rootDescription:CreateButton(L and L["MINIMAP_REOPEN_AWARD"] or "Reopen Award Panel", function()
                if Loothing.UI and Loothing.UI.MainFrame then
                    Loothing.UI.MainFrame:Show()
                    if Loothing.UI.MainFrame.SelectTab then
                        Loothing.UI.MainFrame:SelectTab("session")
                    end
                end
            end)
        end
        rootDescription:CreateDivider()
        rootDescription:CreateButton(L["HIDE_MINIMAP_BUTTON"], function()
            self:Hide()
            if Loothing.Settings then
                Loothing.Settings:Set("ui.showMinimapButton", false)
            end
        end)
    end)
end

--- Handle mouse enter
function MinimapButtonMixin:OnEnter()
    local L = Loothing.Locale

    GameTooltip:SetOwner(self.button, "ANCHOR_LEFT")
    GameTooltip:AddLine("Loothing", 1, 0.82, 0)

    local version = Loothing.VERSION or "1.0.0"
    GameTooltip:AddLine(string.format("v%s", version), 0.5, 0.5, 0.5)

    GameTooltip:AddLine(" ")
    GameTooltip:AddLine(L["MINIMAP_TOOLTIP_LEFT"], 1, 1, 1)
    GameTooltip:AddLine(L["MINIMAP_TOOLTIP_RIGHT"], 1, 1, 1)

    if Loothing.Session then
        local isML = Loothing.Session.IsMasterLooter and Loothing.Session:IsMasterLooter()
        if isML then
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine("You are the Master Looter", 1, 0.82, 0)
        else
            local ml = Loothing.Session:GetMasterLooter()
            if ml then
                GameTooltip:AddLine(" ")
                GameTooltip:AddLine(string.format("ML: %s", Utils.GetShortName(ml)), 0.7, 0.7, 0.7)
            end
        end

        if Loothing.Session:GetState() ~= Loothing.SessionState.INACTIVE then
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine(L["SESSION_ACTIVE"], 0, 1, 0)

            local items = Loothing.Session:GetItems()
            if items then
                local pending = 0
                local voting = 0
                for _, item in items:Enumerate() do
                    if item.state == Loothing.ItemState.PENDING then
                        pending = pending + 1
                    elseif item.state == Loothing.ItemState.VOTING then
                        voting = voting + 1
                    end
                end

                if pending > 0 then
                    GameTooltip:AddLine(string.format(L["ITEMS_PENDING"], pending), 1, 1, 0)
                end
                if voting > 0 then
                    GameTooltip:AddLine(string.format(L["ITEMS_VOTING"], voting), 0, 1, 0)
                end
            end
        end
    end

    GameTooltip:Show()
end

--- Handle mouse leave
function MinimapButtonMixin:OnLeave()
    GameTooltip:Hide()
end

--- Handle drag start
function MinimapButtonMixin:OnDragStart()
    self.isDragging = true
    self.button:LockHighlight()
    self.button:SetScript("OnUpdate", function()
        self:OnDragUpdate()
    end)
    GameTooltip:Hide()
end

--- Handle drag update (shape-aware)
function MinimapButtonMixin:OnDragUpdate()
    local mx, my = Minimap:GetCenter()
    local cx, cy = GetCursorPosition()
    local scale = Minimap:GetEffectiveScale()

    cx, cy = cx / scale, cy / scale

    local dx = cx - mx
    local dy = cy - my

    self.angle = math.deg(math.atan2(dy, dx))
    self:UpdatePosition()
end

--- Handle drag stop
function MinimapButtonMixin:OnDragStop()
    self.button:UnlockHighlight()
    self.button:SetScript("OnUpdate", nil)
    self:SavePosition()
    -- Delay clearing isDragging so the OnMouseUp doesn't fire a click
    C_Timer.After(0.05, function()
        self.isDragging = false
    end)
end

--[[--------------------------------------------------------------------
    Visibility
----------------------------------------------------------------------]]

function MinimapButtonMixin:Show()
    if self.button then
        self.button:Show()
    end
end

function MinimapButtonMixin:Hide()
    if self.button then
        self.button:Hide()
    end
end

function MinimapButtonMixin:Toggle()
    if self.button then
        if self.button:IsShown() then
            self:Hide()
        else
            self:Show()
        end
    end
end

function MinimapButtonMixin:UpdateVisibility()
    local show = true
    if Loothing.Settings then
        show = Loothing.Settings:Get("ui.showMinimapButton")
        if show == nil then
            show = true
        end
    end

    if show then
        self:Show()
    else
        self:Hide()
    end
end

--[[--------------------------------------------------------------------
    Persistence
----------------------------------------------------------------------]]

function MinimapButtonMixin:LoadPosition()
    if not Loothing.Settings then return end

    local angle = Loothing.Settings:Get("ui.minimapButtonAngle")
    if angle then
        self.angle = angle
    end
end

function MinimapButtonMixin:SavePosition()
    if not Loothing.Settings then return end

    Loothing.Settings:Set("ui.minimapButtonAngle", self.angle)
end

--[[--------------------------------------------------------------------
    Status Indicator
----------------------------------------------------------------------]]

function MinimapButtonMixin:SetActiveIndicator(active)
    if not self.button then return end

    if active then
        if not self.glowFrame then
            local glow = CreateFrame("Frame", nil, self.button)
            glow:SetAllPoints()

            local glowTex = glow:CreateTexture(nil, "OVERLAY")
            glowTex:SetSize(BUTTON_SIZE + 8, BUTTON_SIZE + 8)
            glowTex:SetPoint("CENTER")
            glowTex:SetTexture("Interface\\SpellActivationOverlay\\IconAlert")
            glowTex:SetTexCoord(0.00781250, 0.50781250, 0.27734375, 0.52734375)
            glowTex:SetVertexColor(1, 0.8, 0)

            self.glowFrame = glow
            self.glowTex = glowTex
        end

        self.glowFrame:Show()

        if not self.glowAnim then
            local ag = self.glowTex:CreateAnimationGroup()
            local alpha = ag:CreateAnimation("Alpha")
            alpha:SetFromAlpha(0.5)
            alpha:SetToAlpha(1)
            alpha:SetDuration(0.5)
            alpha:SetSmoothing("IN_OUT")

            ag:SetLooping("BOUNCE")
            self.glowAnim = ag
        end

        self.glowAnim:Play()
    else
        if self.glowFrame then
            self.glowFrame:Hide()
        end
        if self.glowAnim then
            self.glowAnim:Stop()
        end
    end
end

--[[--------------------------------------------------------------------
    Factory
----------------------------------------------------------------------]]

local function CreateMinimapButton()
    local button = CreateFromMixins(MinimapButtonMixin)
    button:Init()
    return button
end

ns.CreateMinimapButton = CreateMinimapButton
