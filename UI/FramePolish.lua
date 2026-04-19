--[[--------------------------------------------------------------------
    Loothing - Loot Council Addon for WoW 12.0+
    FramePolish - Shared ToxiUI-style polish helpers

    Centralizes the two helpers that every polished Loothing frame uses:
    - ApplyAccentGlow: soft vertical accent gradient for header bands
    - AttachIconButtonPolish: hover scale + press pulse on icon buttons

    Both pull their colors from ns.SkinningMixin so they track the user's
    Frame Behavior settings (skin, accent, density). See the skill at
    ~/.claude/skills/loothing-ui-polish/SKILL.md for the full contract.

    Dependencies (must be loaded before this file):
    - Core/Init.lua (ns.SkinningMixin)
    - Loolib  (Loolib.AnimationUtil)
----------------------------------------------------------------------]]

local _, ns = ...
local Loolib = LibStub("Loolib")

local AnimationUtil = Loolib.AnimationUtil

local FramePolish = ns.FramePolish or {}
ns.FramePolish = FramePolish

-- SkinningMixin is resolved lazily inside each helper, so this file can load
-- before Skinning.lua without crashing (ns.SkinningMixin may be nil at load
-- time). At call time it will be populated.
local function getSkinning()
    return ns.SkinningMixin
end

--- Soft vertical accent glow on a texture region, sourced from SkinningMixin.
--- Top edge uses the current accent color at `topAlpha` (default 0.18);
--- bottom fades to 0. No-op if SetGradient or CreateColor are unavailable.
--- @param texture Texture
--- @param topAlpha number|nil (0..1, default 0.18)
function FramePolish.ApplyAccentGlow(texture, topAlpha)
    if type(texture) ~= "table" or type(texture.SetGradient) ~= "function" then return end
    if type(_G.CreateColor) ~= "function" then return end
    local skinning = getSkinning()
    local accent = (skinning and skinning:GetColor("accent")) or { 0.4, 0.55, 0.9, 1 }
    local r, g, b = accent[1] or 0.4, accent[2] or 0.55, accent[3] or 0.9
    texture:SetColorTexture(1, 1, 1, 1)
    texture:SetGradient(
        "VERTICAL",
        _G.CreateColor(r, g, b, 0),                 -- bottom: transparent
        _G.CreateColor(r, g, b, topAlpha or 0.18)   -- top: accent at low alpha
    )
end

--- Attach hover scale + press pulse to an icon-style button.
--- Idempotent per button via `button._ltIconPolishHooked`.
---
--- IMPORTANT — anchor-offset caveat: `SetScale(s)` on a WoW frame with
--- `SetPoint(..., xOffset, yOffset)` shifts the button's visual position
--- by `(xOffset * (s - 1), yOffset * (s - 1))`. For buttons with small
--- offsets (e.g. a close button at TOPRIGHT, -5, -5) the shift is
--- sub-pixel and invisible. For buttons with LARGE offsets — typically
--- grid-layout children like `-row * rowHeight` — the shift grows
--- linearly with the offset and reads as the button "jumping" on hover.
--- If your button is anchored at a large parent offset, do NOT attach
--- this polish; rely on Blizzard's SetHighlightTexture or add a
--- scale-free glow overlay instead.
---
--- @param button Button
--- @param opts table|nil  { hoverScale (1.12), pressScale (0.92),
---                          rotateOnHover (false), hoverRotation (pi/8) }
function FramePolish.AttachIconButtonPolish(button, opts)
    if type(button) ~= "table" or not AnimationUtil then return end
    if button._ltIconPolishHooked then return end
    button._ltIconPolishHooked = true

    opts = opts or {}
    local hoverScale = opts.hoverScale or 1.12
    local pressScale = opts.pressScale or 0.92
    local rotateOnHover = opts.rotateOnHover == true
    local hoverRotation = opts.hoverRotation or math.pi / 8

    button._ltIconBaseScale = button._ltIconBaseScale or (button:GetScale() or 1)

    local function playScale(to, duration, easing)
        if button._ltIconScaleGroup then button._ltIconScaleGroup:Stop() end
        local group = AnimationUtil.CreateGroup(button)
        group:CreateAnimation("scale", {
            target = button,
            from = button:GetScale() or 1,
            to = to,
            duration = duration,
            easing = easing,
        })
        button._ltIconScaleGroup = group
        group:Play()
    end

    button:HookScript("OnEnter", function()
        playScale(button._ltIconBaseScale * hoverScale, 0.14, "outBack")
        if rotateOnHover then
            local normal = button.GetNormalTexture and button:GetNormalTexture()
            if normal and type(normal.SetRotation) == "function" then
                normal:SetRotation(hoverRotation)
            end
        end
    end)
    button:HookScript("OnLeave", function()
        playScale(button._ltIconBaseScale, 0.18, "outCubic")
        if rotateOnHover then
            local normal = button.GetNormalTexture and button:GetNormalTexture()
            if normal and type(normal.SetRotation) == "function" then
                normal:SetRotation(0)
            end
        end
    end)
    button:HookScript("OnMouseDown", function()
        playScale(button._ltIconBaseScale * pressScale, 0.05, "outQuad")
    end)
    button:HookScript("OnMouseUp", function()
        local target = button:IsMouseOver()
            and button._ltIconBaseScale * hoverScale
             or button._ltIconBaseScale
        playScale(target, 0.1, "outBack")
    end)
end
