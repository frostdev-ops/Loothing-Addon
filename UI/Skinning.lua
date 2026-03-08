--[[--------------------------------------------------------------------
    Loothing - Loot Council Addon for WoW 12.0+
    Skinning - Frame skinning, combat minimize, scale, Escape-to-close
----------------------------------------------------------------------]]

local Loolib = LibStub("Loolib")

--[[--------------------------------------------------------------------
    Skin Presets
----------------------------------------------------------------------]]

LOOTHING_SKIN_PRESETS = {
    Default = {
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true,
        tileSize = 32,
        edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 },
        bgColor = { 0.09, 0.09, 0.19, 1 },
        borderColor = { 0.7, 0.7, 0.7, 1 },
    },
    Dark = {
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        tile = false,
        tileSize = 0,
        edgeSize = 2,
        insets = { left = 2, right = 2, top = 2, bottom = 2 },
        bgColor = { 0.06, 0.06, 0.06, 0.95 },
        borderColor = { 0.2, 0.2, 0.2, 1 },
    },
    Minimal = {
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        tile = false,
        tileSize = 0,
        edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 },
        bgColor = { 0.05, 0.05, 0.05, 0.85 },
        borderColor = { 0.15, 0.15, 0.15, 0.8 },
    },
}

--[[--------------------------------------------------------------------
    LoothingSkinningMixin

    Provides:
    - Frame skin application (backdrop, colors)
    - Per-frame position/scale/color persistence in db.UI[frameName]
    - Ctrl+Scroll to adjust frame scale
    - Combat minimize/maximize
    - Escape-to-close registration
----------------------------------------------------------------------]]

LoothingSkinningMixin = {}

--- Managed frames (for combat minimize/maximize)
local managedFrames = {}
local combatFrame = nil
local isInCombat = false

--[[--------------------------------------------------------------------
    Skin Application
----------------------------------------------------------------------]]

--- Apply a skin preset to a frame
-- @param frame Frame - The frame to skin
-- @param skinName string|nil - Preset name (nil = use current setting)
function LoothingSkinningMixin:ApplySkin(frame, skinName)
    if not frame or not frame.SetBackdrop then return end

    skinName = skinName or self:GetCurrentSkin()
    local skin = LOOTHING_SKIN_PRESETS[skinName]
    if not skin then
        skin = LOOTHING_SKIN_PRESETS.Default
    end

    frame:SetBackdrop({
        bgFile = skin.bgFile,
        edgeFile = skin.edgeFile,
        tile = skin.tile,
        tileSize = skin.tileSize,
        edgeSize = skin.edgeSize,
        insets = skin.insets,
    })

    frame:SetBackdropColor(unpack(skin.bgColor))
    frame:SetBackdropBorderColor(unpack(skin.borderColor))
end

--- Get the current skin name
-- @return string
function LoothingSkinningMixin:GetCurrentSkin()
    if Loothing.Settings then
        return Loothing.Settings:Get("frame.skin") or "Default"
    end
    return "Default"
end

--- Set the current skin and apply to all managed frames
-- @param skinName string
function LoothingSkinningMixin:SetCurrentSkin(skinName)
    if not LOOTHING_SKIN_PRESETS[skinName] then return end

    if Loothing.Settings then
        Loothing.Settings:Set("frame.skin", skinName)
    end

    -- Re-skin all managed frames
    for _, entry in ipairs(managedFrames) do
        if entry.frame and entry.frame:IsObjectType("Frame") then
            self:ApplySkin(entry.frame, skinName)
        end
    end
end

--- Apply per-frame overrides (bgColor, borderColor)
-- @param frame Frame
-- @param frameName string - Key for db.UI lookup
function LoothingSkinningMixin:ApplyFrameOverrides(frame, frameName)
    if not Loothing.Settings or not frame then return end

    local uiData = Loothing.Settings:Get("frame.UI." .. frameName)
    if not uiData then return end

    if uiData.bgColor then
        frame:SetBackdropColor(unpack(uiData.bgColor))
    end
    if uiData.borderColor then
        frame:SetBackdropBorderColor(unpack(uiData.borderColor))
    end
end

--[[--------------------------------------------------------------------
    Per-Frame Position/Scale Persistence
----------------------------------------------------------------------]]

--- Save frame position and scale to db.UI[frameName]
-- @param frame Frame
-- @param frameName string
function LoothingSkinningMixin:SaveFrameState(frame, frameName)
    if not Loothing.Settings or not frame then return end

    local point, _, relativePoint, x, y = frame:GetPoint()
    local width, height = frame:GetSize()
    local scale = frame:GetScale()

    Loothing.Settings:Set("frame.UI." .. frameName, {
        point = point,
        relativePoint = relativePoint,
        x = x,
        y = y,
        width = width,
        height = height,
        scale = scale,
    })
end

--- Load frame position and scale from db.UI[frameName]
-- @param frame Frame
-- @param frameName string
function LoothingSkinningMixin:LoadFrameState(frame, frameName)
    if not Loothing.Settings or not frame then return end

    local uiData = Loothing.Settings:Get("frame.UI." .. frameName)
    if not uiData then return end

    if uiData.point then
        frame:ClearAllPoints()
        frame:SetPoint(
            uiData.point,
            UIParent,
            uiData.relativePoint or uiData.point,
            uiData.x or 0,
            uiData.y or 0
        )
    end

    if uiData.width and uiData.height then
        frame:SetSize(uiData.width, uiData.height)
    end

    if uiData.scale then
        frame:SetScale(uiData.scale)
    end
end

--[[--------------------------------------------------------------------
    Ctrl+Scroll Scale
----------------------------------------------------------------------]]

--- Enable Ctrl+Scroll scaling on a frame
-- @param frame Frame
-- @param frameName string - Key for persistence
-- @param minScale number - Minimum scale (default 0.5)
-- @param maxScale number - Maximum scale (default 2.0)
function LoothingSkinningMixin:EnableCtrlScroll(frame, frameName, minScale, maxScale)
    if not frame then return end

    minScale = minScale or 0.5
    maxScale = maxScale or 2.0

    frame:EnableMouseWheel(true)
    frame:HookScript("OnMouseWheel", function(f, delta)
        if IsControlKeyDown() then
            local currentScale = f:GetScale()
            local step = 0.05

            if delta > 0 then
                currentScale = math.min(maxScale, currentScale + step)
            else
                currentScale = math.max(minScale, currentScale - step)
            end

            f:SetScale(currentScale)

            -- Persist
            if frameName then
                self:SaveFrameState(f, frameName)
            end
        end
    end)
end

--[[--------------------------------------------------------------------
    Combat Minimize/Maximize
----------------------------------------------------------------------]]

--- Register a frame for combat minimize/maximize
-- @param frame Frame - The frame to manage
-- @param frameName string - Name for tracking
-- @param minimizeFunc function|nil - Custom minimize (default: frame:Hide())
-- @param maximizeFunc function|nil - Custom maximize (default: frame:Show())
function LoothingSkinningMixin:RegisterForCombatMinimize(frame, frameName, minimizeFunc, maximizeFunc)
    if not frame then return end

    managedFrames[#managedFrames + 1] = {
        frame = frame,
        name = frameName,
        minimize = minimizeFunc or function(f) f:Hide() end,
        maximize = maximizeFunc or function(f) f:Show() end,
        wasShown = false,
    }

    -- Create combat event frame if needed
    if not combatFrame then
        combatFrame = CreateFrame("Frame")
        combatFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
        combatFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
        combatFrame:SetScript("OnEvent", function(_, event)
            if event == "PLAYER_REGEN_DISABLED" then
                LoothingSkinningMixin:OnCombatStart()
            elseif event == "PLAYER_REGEN_ENABLED" then
                LoothingSkinningMixin:OnCombatEnd()
            end
        end)
    end
end

--- Unregister a frame from combat minimize
-- @param frame Frame
function LoothingSkinningMixin:UnregisterForCombatMinimize(frame)
    for i = #managedFrames, 1, -1 do
        if managedFrames[i].frame == frame then
            table.remove(managedFrames, i)
            break
        end
    end
end

--- Handle combat start - minimize all registered frames
function LoothingSkinningMixin:OnCombatStart()
    if not Loothing.Settings then return end

    local minimizeInCombat = Loothing.Settings:Get("frame.minimizeInCombat", false)
    if not minimizeInCombat then return end

    isInCombat = true

    for _, entry in ipairs(managedFrames) do
        if entry.frame:IsShown() then
            entry.wasShown = true
            entry.minimize(entry.frame)
        else
            entry.wasShown = false
        end
    end
end

--- Handle combat end - restore minimized frames
function LoothingSkinningMixin:OnCombatEnd()
    isInCombat = false

    for _, entry in ipairs(managedFrames) do
        if entry.wasShown then
            entry.maximize(entry.frame)
            entry.wasShown = false
        end
    end
end

--[[--------------------------------------------------------------------
    Escape-to-Close
----------------------------------------------------------------------]]

--- Register a frame for Escape-to-close
-- @param frame Frame - Must have a global name
-- @param globalName string - Global frame name
function LoothingSkinningMixin:RegisterForEscapeClose(frame, globalName)
    if not frame or not globalName then return end

    -- Check setting
    if Loothing.Settings then
        local closeWithEscape = Loothing.Settings:Get("frame.closeWithEscape", false)
        if not closeWithEscape then return end
    end

    -- Add to UISpecialFrames if not already there
    if UISpecialFrames then
        for _, name in ipairs(UISpecialFrames) do
            if name == globalName then return end
        end
        tinsert(UISpecialFrames, globalName)
    end
end

--[[--------------------------------------------------------------------
    Full Frame Setup (convenience)
----------------------------------------------------------------------]]

--- Setup a frame with all skinning features
-- @param frame Frame
-- @param frameName string - Unique name for persistence
-- @param globalName string|nil - Global name for Escape-to-close
-- @param options table|nil - { combatMinimize, ctrlScroll, escapeClose }
function LoothingSkinningMixin:SetupFrame(frame, frameName, globalName, options)
    if not frame then return end
    options = options or {}

    -- Apply skin
    self:ApplySkin(frame)
    self:ApplyFrameOverrides(frame, frameName)

    -- Load saved position/scale
    self:LoadFrameState(frame, frameName)

    -- Ctrl+Scroll
    if options.ctrlScroll ~= false then
        self:EnableCtrlScroll(frame, frameName)
    end

    -- Combat minimize
    if options.combatMinimize ~= false then
        self:RegisterForCombatMinimize(frame, frameName)
    end

    -- Escape-to-close
    if globalName and options.escapeClose ~= false then
        self:RegisterForEscapeClose(frame, globalName)
    end
end

--[[--------------------------------------------------------------------
    Init (called from Core/Init.lua)
----------------------------------------------------------------------]]

function LoothingSkinningMixin:Init()
    -- Ensure defaults exist
    if Loothing.Settings and not Loothing.Settings:Get("frame.skin") then
        Loothing.Settings:Set("frame.skin", "Default")
    end
end
