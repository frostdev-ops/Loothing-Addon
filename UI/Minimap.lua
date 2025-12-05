--[[--------------------------------------------------------------------
    Loothing - Loot Council Addon for WoW 12.0+
    Minimap - Minimap button for quick access
----------------------------------------------------------------------]]

local Loolib = LibStub("Loolib")

--[[--------------------------------------------------------------------
    LoothingMinimapButtonMixin
----------------------------------------------------------------------]]

LoothingMinimapButtonMixin = {}

local BUTTON_SIZE = 32
local ICON_TEXTURE = "Interface\\Icons\\INV_Misc_Coin_02" -- Placeholder, replace with custom

--- Initialize the minimap button
function LoothingMinimapButtonMixin:Init()
    self.angle = 225 -- Default position (degrees)
    self.radius = 80 -- Distance from minimap center
    self.isDragging = false

    -- Load saved position
    self:LoadPosition()

    -- Create the button
    self:CreateButton()

    -- Update visibility based on settings
    self:UpdateVisibility()
end

--- Create the minimap button frame
function LoothingMinimapButtonMixin:CreateButton()
    local button = CreateFrame("Button", "LoothingMinimapButton", Minimap)
    button:SetSize(BUTTON_SIZE, BUTTON_SIZE)
    button:SetFrameStrata("MEDIUM")
    button:SetFrameLevel(8)

    -- Background
    local bg = button:CreateTexture(nil, "BACKGROUND")
    bg:SetSize(BUTTON_SIZE, BUTTON_SIZE)
    bg:SetPoint("CENTER")
    bg:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")

    -- Icon
    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetSize(20, 20)
    icon:SetPoint("CENTER")
    icon:SetTexture(ICON_TEXTURE)
    button.icon = icon

    -- Highlight
    local highlight = button:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetSize(BUTTON_SIZE, BUTTON_SIZE)
    highlight:SetPoint("CENTER")
    highlight:SetTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

    -- Scripts
    button:SetScript("OnClick", function(_, btn)
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

    button:RegisterForDrag("LeftButton")
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")

    self.button = button

    -- Position the button
    self:UpdatePosition()
end

--- Update button position on minimap
function LoothingMinimapButtonMixin:UpdatePosition()
    if not self.button then return end

    local angle = math.rad(self.angle)
    local x = math.cos(angle) * self.radius
    local y = math.sin(angle) * self.radius

    self.button:ClearAllPoints()
    self.button:SetPoint("CENTER", Minimap, "CENTER", x, y)
end

--- Handle click
-- @param mouseButton string
function LoothingMinimapButtonMixin:OnClick(mouseButton)
    if mouseButton == "LeftButton" then
        -- Toggle main frame
        if Loothing.UI and Loothing.UI.MainFrame then
            Loothing.UI.MainFrame:Toggle()
        end
    elseif mouseButton == "RightButton" then
        -- Show context menu or settings
        self:ShowContextMenu()
    end
end

--- Show context menu
function LoothingMinimapButtonMixin:ShowContextMenu()
    local L = LOOTHING_LOCALE

    -- Simple dropdown menu
    local menu = {
        { text = "Loothing", isTitle = true, notCheckable = true },
        { text = L["OPEN_MAIN_WINDOW"], notCheckable = true, func = function()
            if Loothing.UI and Loothing.UI.MainFrame then
                Loothing.UI.MainFrame:Show()
            end
        end },
        { text = L["SETTINGS"], notCheckable = true, func = function()
            if Loothing.UI and Loothing.UI.MainFrame then
                Loothing.UI.MainFrame:Show()
                Loothing.UI.MainFrame:SelectTab("settings")
            end
        end },
        { text = "", notCheckable = true, disabled = true }, -- Separator
        { text = L["HIDE_MINIMAP_BUTTON"], notCheckable = true, func = function()
            self:Hide()
            if Loothing.Settings then
                Loothing.Settings:Set("ui.showMinimapButton", false)
            end
        end },
    }

    -- Use EasyMenu if available, otherwise create simple menu
    if EasyMenu then
        EasyMenu(menu, CreateFrame("Frame", "LoothingMinimapMenu", UIParent, "UIDropDownMenuTemplate"), "cursor", 0, 0, "MENU")
    end
end

--- Handle mouse enter
function LoothingMinimapButtonMixin:OnEnter()
    local L = LOOTHING_LOCALE

    GameTooltip:SetOwner(self.button, "ANCHOR_LEFT")
    GameTooltip:AddLine("Loothing", 1, 0.82, 0)
    GameTooltip:AddLine(L["MINIMAP_TOOLTIP_LEFT"], 1, 1, 1)
    GameTooltip:AddLine(L["MINIMAP_TOOLTIP_RIGHT"], 1, 1, 1)

    -- Show session status if active
    if Loothing.Session and Loothing.Session:GetState() ~= LOOTHING_SESSION_STATE.INACTIVE then
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(L["SESSION_ACTIVE"], 0, 1, 0)

        local items = Loothing.Session:GetItems()
        if items then
            local pending = 0
            local voting = 0
            for _, item in items:Enumerate() do
                if item.state == LOOTHING_ITEM_STATE.PENDING then
                    pending = pending + 1
                elseif item.state == LOOTHING_ITEM_STATE.VOTING then
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

    GameTooltip:Show()
end

--- Handle mouse leave
function LoothingMinimapButtonMixin:OnLeave()
    GameTooltip:Hide()
end

--- Handle drag start
function LoothingMinimapButtonMixin:OnDragStart()
    self.isDragging = true
    self.button:SetScript("OnUpdate", function()
        self:OnDragUpdate()
    end)
end

--- Handle drag update
function LoothingMinimapButtonMixin:OnDragUpdate()
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
function LoothingMinimapButtonMixin:OnDragStop()
    self.isDragging = false
    self.button:SetScript("OnUpdate", nil)
    self:SavePosition()
end

--[[--------------------------------------------------------------------
    Visibility
----------------------------------------------------------------------]]

--- Show the button
function LoothingMinimapButtonMixin:Show()
    if self.button then
        self.button:Show()
    end
end

--- Hide the button
function LoothingMinimapButtonMixin:Hide()
    if self.button then
        self.button:Hide()
    end
end

--- Toggle visibility
function LoothingMinimapButtonMixin:Toggle()
    if self.button then
        if self.button:IsShown() then
            self:Hide()
        else
            self:Show()
        end
    end
end

--- Update visibility based on settings
function LoothingMinimapButtonMixin:UpdateVisibility()
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

--- Load position from settings
function LoothingMinimapButtonMixin:LoadPosition()
    if not Loothing.Settings then return end

    local angle = Loothing.Settings:Get("ui.minimapButtonAngle")
    if angle then
        self.angle = angle
    end
end

--- Save position to settings
function LoothingMinimapButtonMixin:SavePosition()
    if not Loothing.Settings then return end

    Loothing.Settings:Set("ui.minimapButtonAngle", self.angle)
end

--[[--------------------------------------------------------------------
    Status Indicator
----------------------------------------------------------------------]]

--- Set status indicator (glow effect for active session)
-- @param active boolean
function LoothingMinimapButtonMixin:SetActiveIndicator(active)
    if not self.button then return end

    if active then
        -- Add glow or pulsing effect
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

        -- Animate
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

function CreateLoothingMinimapButton()
    local button = LoolibCreateFromMixins(LoothingMinimapButtonMixin)
    button:Init()
    return button
end
