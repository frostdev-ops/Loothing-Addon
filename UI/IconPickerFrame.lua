--[[--------------------------------------------------------------------
    Loothing - Loot Council Addon for WoW 12.0+
    IconPickerFrame - Modal grid for picking a response button icon
----------------------------------------------------------------------]]

local _, ns = ...
local Loothing = ns.Addon

local GRID_COLS    = 8
local ICON_SIZE    = 36
local ICON_PADDING = 4
local SEARCH_HEIGHT = 24
local FRAME_PADDING = 12
local MAX_VISIBLE_ROWS = 8

local IconPickerMixin = ns.IconPickerMixin or {}
ns.IconPickerMixin = IconPickerMixin

--- Show the icon picker near anchorFrame.
-- onSelect(iconPath) is called when the user clicks an icon.
-- Pass nil to clear the current icon.
-- @param anchorFrame Frame
-- @param onSelect function(iconPath)
function IconPickerMixin:Open(anchorFrame, onSelect)
    self.onSelect  = onSelect
    self.searchStr = ""
    self.searchBox:SetText("")
    self:Refresh()

    self:ClearAllPoints()
    self:SetPoint("TOPLEFT", anchorFrame, "TOPRIGHT", 4, 0)
    self:Show()
    self:Raise()
end

--- Close the picker without selecting
function IconPickerMixin:Close()
    self:Hide()
end

--- Rebuild the icon grid based on current search string
function IconPickerMixin:Refresh()
    local search  = self.searchStr and self.searchStr:lower() or ""
    local filtered = {}
    for _, entry in ipairs(Loothing.IconList) do
        if search == "" or entry.label:lower():find(search, 1, true) then
            filtered[#filtered + 1] = entry
        end
    end

    -- Show/hide icon buttons
    for i, btn in ipairs(self.iconButtons) do
        local entry = filtered[i]
        if entry then
            btn.icon:SetTexture(entry.path)
            btn.entry = entry
            btn:Show()
        else
            btn:Hide()
            btn.entry = nil
        end
    end

    -- Grow buttons if needed
    for i = #self.iconButtons + 1, #filtered do
        self:CreateIconButton(i)
        local entry = filtered[i]
        self.iconButtons[i].icon:SetTexture(entry.path)
        self.iconButtons[i].entry = entry
    end

    -- Resize scroll child to fit grid
    local rows = math.ceil(#filtered / GRID_COLS)
    local gridH = rows * (ICON_SIZE + ICON_PADDING)
    self.scrollChild:SetHeight(math.max(gridH, 1))

    -- Clamp visible height
    local visibleRows = math.min(rows, MAX_VISIBLE_ROWS)
    local visibleH = visibleRows * (ICON_SIZE + ICON_PADDING)
    local totalH = FRAME_PADDING * 2 + SEARCH_HEIGHT + 4 + visibleH
    self:SetHeight(totalH)
end

--- Create a single icon button at grid index i
function IconPickerMixin:CreateIconButton(i)
    local col = ((i - 1) % GRID_COLS)
    local row = math.floor((i - 1) / GRID_COLS)

    local btn = CreateFrame("Button", nil, self.scrollChild)
    btn:SetSize(ICON_SIZE, ICON_SIZE)
    btn:SetPoint("TOPLEFT",
        col * (ICON_SIZE + ICON_PADDING),
        -(row * (ICON_SIZE + ICON_PADDING)))

    local bg = btn:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0.15, 0.15, 0.15, 0.8)
    btn.bg = bg

    local hl = btn:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints()
    hl:SetColorTexture(1, 0.82, 0, 0.25)
    btn.highlight = hl

    local tex = btn:CreateTexture(nil, "ARTWORK")
    tex:SetAllPoints()
    btn.icon = tex

    btn:SetScript("OnClick", function()
        if btn.entry then
            if self.onSelect then self.onSelect(btn.entry.path) end
            self:Close()
        end
    end)

    btn:SetScript("OnEnter", function()
        if btn.entry then
            GameTooltip:SetOwner(btn, "ANCHOR_RIGHT")
            GameTooltip:SetText(btn.entry.label, 1, 1, 1)
            GameTooltip:Show()
        end
    end)
    btn:SetScript("OnLeave", function() GameTooltip:Hide() end)

    self.iconButtons[i] = btn
    return btn
end

--- Build the frame on first use
function IconPickerMixin:OnLoad()
    self:SetFrameStrata("FULLSCREEN_DIALOG")
    self:SetMovable(true)
    self:EnableMouse(true)
    self:SetClampedToScreen(true)
    self:SetBackdrop({
        bgFile   = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile     = true,
        tileSize = 16,
        edgeSize = 16,
        insets   = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    self:SetBackdropColor(0.1, 0.1, 0.1, 0.95)
    self:SetBackdropBorderColor(0.6, 0.6, 0.6, 1)

    local gridW = GRID_COLS * (ICON_SIZE + ICON_PADDING) - ICON_PADDING
    local scrollBarW = 20
    self:SetWidth(FRAME_PADDING * 2 + gridW + scrollBarW)

    -- Close button
    local closeBtn = CreateFrame("Button", nil, self, "UIPanelCloseButton")
    closeBtn:SetSize(20, 20)
    closeBtn:SetPoint("TOPRIGHT", -2, -2)
    closeBtn:SetScript("OnClick", function() self:Close() end)

    -- Search box
    local search = CreateFrame("EditBox", nil, self, "InputBoxTemplate")
    search:SetHeight(SEARCH_HEIGHT)
    search:SetPoint("TOPLEFT", FRAME_PADDING, -FRAME_PADDING)
    search:SetPoint("TOPRIGHT", -FRAME_PADDING - 24, -FRAME_PADDING)
    search:SetAutoFocus(false)
    search:SetMaxLetters(32)
    search:SetScript("OnTextChanged", function(eb)
        self.searchStr = eb:GetText()
        self:Refresh()
    end)
    -- Placeholder hint
    local hint = search:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    hint:SetPoint("LEFT", search, "LEFT", 4, 0)
    hint:SetText("Search...")
    search:SetScript("OnEditFocusGained", function() hint:Hide() end)
    search:SetScript("OnEditFocusLost",   function()
        if search:GetText() == "" then hint:Show() end
    end)
    self.searchBox = search

    -- "No icon" clear button
    local clearBtn = CreateFrame("Button", nil, self)
    clearBtn:SetSize(SEARCH_HEIGHT, SEARCH_HEIGHT)
    clearBtn:SetPoint("LEFT", search, "RIGHT", 4, 0)
    clearBtn:SetNormalFontObject("GameFontNormalSmall")
    clearBtn:SetText("X")
    clearBtn:SetScript("OnClick", function()
        if self.onSelect then self.onSelect(nil) end
        self:Close()
    end)
    clearBtn:SetScript("OnEnter", function()
        GameTooltip:SetOwner(clearBtn, "ANCHOR_RIGHT")
        GameTooltip:SetText("Clear icon (no icon)", 1, 1, 1)
        GameTooltip:Show()
    end)
    clearBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)

    -- Scroll frame for the icon grid
    local scrollFrame = CreateFrame("ScrollFrame", nil, self, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", FRAME_PADDING, -(FRAME_PADDING + SEARCH_HEIGHT + 4))
    scrollFrame:SetPoint("BOTTOMRIGHT", -FRAME_PADDING, FRAME_PADDING)
    self.scrollFrame = scrollFrame

    local scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetWidth(gridW)
    scrollChild:SetHeight(1)
    scrollFrame:SetScrollChild(scrollChild)
    self.scrollChild = scrollChild

    self.iconButtons = {}

    -- Pre-create buttons for the full icon list
    for i = 1, #Loothing.IconList do
        self:CreateIconButton(i)
    end

    self:Hide()
end

local function GetIconPickerFrame()
    local frame = ns.IconPickerFrame
    if not frame then
        frame = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
        Mixin(frame, IconPickerMixin)
        frame:OnLoad()
        ns.IconPickerFrame = frame
        -- frame already stored in ns.IconPickerFrame above
    end
    return frame
end

local function IconPicker_Open(anchorFrame, onSelect, currentIcon)
    GetIconPickerFrame():Open(anchorFrame, onSelect, currentIcon)
end

ns.OpenIconPicker = IconPicker_Open

