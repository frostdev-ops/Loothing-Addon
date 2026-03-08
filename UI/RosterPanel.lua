--[[--------------------------------------------------------------------
    Loothing - Loot Council Addon for WoW 12.0+
    RosterPanel - Group/raid roster overview with version, council, and history info
----------------------------------------------------------------------]]

local Loolib = LibStub("Loolib")

--[[--------------------------------------------------------------------
    LoothingRosterPanelMixin
----------------------------------------------------------------------]]

LoothingRosterPanelMixin = LoolibCreateFromMixins(LoolibCallbackRegistryMixin)

local ROSTER_PANEL_EVENTS = {}

local ROW_HEIGHT = 30
local HEADER_HEIGHT = 28
local COLUMN_HEADER_HEIGHT = 22
local FOOTER_HEIGHT = 36

-- Column definitions: { id, width (nil = FILL), label }
local COLUMNS = {
    { id = "status",  width = 20,  label = "" },
    { id = "name",    width = nil, label = "Name" },
    { id = "role",    width = 28,  label = "" },
    { id = "ilvl",    width = 40,  label = "iLvl" },
    { id = "version", width = 90,  label = "Loothing" },
    { id = "council", width = 58,  label = "Council" },
    { id = "loot",    width = 44,  label = "Loot" },
    { id = "rank",    width = 60,  label = "Rank" },
}

local FIXED_WIDTH_TOTAL = 0
for _, col in ipairs(COLUMNS) do
    if col.width then
        FIXED_WIDTH_TOTAL = FIXED_WIDTH_TOTAL + col.width
    end
end

-- Role atlas names
local ROLE_ATLASES = {
    TANK = "roleicon-tiny-tank",
    HEALER = "roleicon-tiny-healer",
    DAMAGER = "roleicon-tiny-dps",
}

-- Rank display names
local RANK_NAMES = { [2] = "Leader", [1] = "Assist", [0] = "Member" }

-- Sort comparators keyed by column id
local SORT_COMPARATORS = {
    status = function(a, b) return (a.online and 1 or 0) > (b.online and 1 or 0) end,
    name = function(a, b) return a.name < b.name end,
    role = function(a, b) return (a.role or "") < (b.role or "") end,
    ilvl = function(a, b) return (a.ilvl or 0) > (b.ilvl or 0) end,
    version = function(a, b) return (a.versionStr or "") < (b.versionStr or "") end,
    council = function(a, b)
        local ac = a.isCouncil and 1 or 0
        local bc = b.isCouncil and 1 or 0
        return ac > bc
    end,
    loot = function(a, b) return (a.historyCount or 0) > (b.historyCount or 0) end,
    rank = function(a, b) return (a.rank or 0) > (b.rank or 0) end,
}

--- Initialize the roster panel
-- @param parent Frame - Parent frame
function LoothingRosterPanelMixin:Init(parent)
    LoolibCallbackRegistryMixin.OnLoad(self)
    self:GenerateCallbackEvents(ROSTER_PANEL_EVENTS)

    self.parent = parent
    self.rosterData = {}
    self.sortColumn = "name"
    self.sortAscending = true
    self.versionCallbackRegistered = false

    self:CreateFrame()
    self:CreateElements()
end

--- Create the main frame
function LoothingRosterPanelMixin:CreateFrame()
    local frame = CreateFrame("Frame", nil, self.parent)
    frame:SetAllPoints()
    self.frame = frame
end

--- Create UI elements
function LoothingRosterPanelMixin:CreateElements()
    self:CreateHeader()
    self:CreateColumnHeaders()
    self:CreateScrollList()
    self:CreateFooter()
    self:CreateEmptyState()
end

--[[--------------------------------------------------------------------
    Header
----------------------------------------------------------------------]]

function LoothingRosterPanelMixin:CreateHeader()
    local header = CreateFrame("Frame", nil, self.frame)
    header:SetPoint("TOPLEFT", 8, -4)
    header:SetPoint("TOPRIGHT", -8, -4)
    header:SetHeight(HEADER_HEIGHT)

    self.summaryText = header:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    self.summaryText:SetPoint("LEFT")
    self.summaryText:SetTextColor(0.7, 0.7, 0.7)

    self.headerFrame = header
end

--[[--------------------------------------------------------------------
    Column Headers
----------------------------------------------------------------------]]

function LoothingRosterPanelMixin:CreateColumnHeaders()
    -- Align with scroll content area: list container (8px inset) + scroll frame (2px left, 22px right)
    local container = CreateFrame("Frame", nil, self.frame)
    container:SetPoint("TOPLEFT", 10, -(4 + HEADER_HEIGHT))
    container:SetPoint("TOPRIGHT", -30, -(4 + HEADER_HEIGHT))
    container:SetHeight(COLUMN_HEADER_HEIGHT)

    self.columnContainer = container
    self.columnButtons = {}

    -- Separator below column headers
    local sep = self.frame:CreateTexture(nil, "ARTWORK")
    sep:SetPoint("TOPLEFT", container, "BOTTOMLEFT")
    sep:SetPoint("TOPRIGHT", container, "BOTTOMRIGHT")
    sep:SetHeight(1)
    sep:SetColorTexture(0.3, 0.3, 0.3, 1)

    -- We'll position columns in LayoutColumns (called on first Refresh)
    self.columnsNeedLayout = true
end

--- Create column header buttons (called once)
function LoothingRosterPanelMixin:CreateColumnButtons()
    for _, col in ipairs(COLUMNS) do
        local btn = CreateFrame("Button", nil, self.columnContainer)
        btn:SetHeight(COLUMN_HEADER_HEIGHT)

        local text = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        text:SetPoint("LEFT", 2, 0)
        text:SetText(col.label)
        text:SetTextColor(0.6, 0.6, 0.6)
        btn.label = text

        -- Sort arrow
        local arrow = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        arrow:SetPoint("LEFT", text, "RIGHT", 2, 0)
        arrow:SetTextColor(1, 0.82, 0)
        arrow:Hide()
        btn.arrow = arrow

        local colId = col.id
        btn:SetScript("OnClick", function()
            self:OnColumnClick(colId)
        end)
        btn:SetScript("OnEnter", function(b)
            b.label:SetTextColor(1, 1, 1)
        end)
        btn:SetScript("OnLeave", function(b)
            b.label:SetTextColor(0.6, 0.6, 0.6)
        end)

        btn.colId = colId
        btn.colWidth = col.width -- nil for fill column
        self.columnButtons[#self.columnButtons + 1] = btn
    end
end

--- Get the usable content width (scroll frame is the single source of truth)
function LoothingRosterPanelMixin:GetContentWidth()
    local w = self.scrollFrame:GetWidth()
    if w <= 0 then w = 440 end
    return w
end

--- Layout column header buttons based on current container width
function LoothingRosterPanelMixin:LayoutColumns()
    -- Create buttons on first call
    if #self.columnButtons == 0 then
        self:CreateColumnButtons()
    end

    local containerWidth = self:GetContentWidth()
    local fillWidth = math.max(60, containerWidth - FIXED_WIDTH_TOTAL)
    local xOffset = 0

    for _, btn in ipairs(self.columnButtons) do
        local w = btn.colWidth or fillWidth
        btn:ClearAllPoints()
        btn:SetPoint("LEFT", xOffset, 0)
        btn:SetWidth(w)
        btn:Show()
        xOffset = xOffset + w
    end

    self:UpdateSortArrows()
    self.columnsNeedLayout = false
end

--- Update sort arrow indicators
function LoothingRosterPanelMixin:UpdateSortArrows()
    for _, btn in ipairs(self.columnButtons) do
        if btn.colId == self.sortColumn then
            btn.arrow:SetText(self.sortAscending and " v" or " ^")
            btn.arrow:Show()
        else
            btn.arrow:Hide()
        end
    end
end

--- Handle column header click
function LoothingRosterPanelMixin:OnColumnClick(colId)
    if self.sortColumn == colId then
        self.sortAscending = not self.sortAscending
    else
        self.sortColumn = colId
        self.sortAscending = true
    end

    self:UpdateSortArrows()
    self:SortAndDisplay()
end

--[[--------------------------------------------------------------------
    Scroll List
----------------------------------------------------------------------]]

function LoothingRosterPanelMixin:CreateScrollList()
    local listTop = 4 + HEADER_HEIGHT + COLUMN_HEADER_HEIGHT + 2

    local container = CreateFrame("Frame", nil, self.frame, "BackdropTemplate")
    container:SetPoint("TOPLEFT", 8, -listTop)
    container:SetPoint("BOTTOMRIGHT", -8, FOOTER_HEIGHT + 8)
    container:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        tile = false,
        edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    container:SetBackdropColor(0.05, 0.05, 0.05, 0.9)
    container:SetBackdropBorderColor(0.2, 0.2, 0.2, 1)

    local scrollFrame = CreateFrame("ScrollFrame", nil, container, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 2, -2)
    scrollFrame:SetPoint("BOTTOMRIGHT", -22, 2)

    local content = CreateFrame("Frame", nil, scrollFrame)
    content:SetSize(1, 1)
    scrollFrame:SetScrollChild(content)

    scrollFrame:SetScript("OnSizeChanged", function(sf, w, h)
        content:SetWidth(w)
    end)

    self.listContainer = container
    self.scrollFrame = scrollFrame
    self.listContent = content

    self.rowPool = CreateFramePool("Button", self.listContent, nil, function(pool, row)
        row:Hide()
        row:ClearAllPoints()
        row:SetScript("OnClick", nil)
        row:SetScript("OnEnter", nil)
        row:SetScript("OnLeave", nil)
    end)
end

--[[--------------------------------------------------------------------
    Footer
----------------------------------------------------------------------]]

function LoothingRosterPanelMixin:CreateFooter()
    local L = LOOTHING_LOCALE

    local footer = CreateFrame("Frame", nil, self.frame)
    footer:SetPoint("BOTTOMLEFT", 8, 8)
    footer:SetPoint("BOTTOMRIGHT", -8, 8)
    footer:SetHeight(FOOTER_HEIGHT)

    -- Refresh button
    local refreshBtn = CreateFrame("Button", nil, footer, "UIPanelButtonTemplate")
    refreshBtn:SetSize(80, 26)
    refreshBtn:SetPoint("LEFT")
    refreshBtn:SetText(L["REFRESH"])
    refreshBtn:SetScript("OnClick", function()
        self:Refresh()
    end)

    -- Query Versions button
    local queryBtn = CreateFrame("Button", nil, footer, "UIPanelButtonTemplate")
    queryBtn:SetSize(120, 26)
    queryBtn:SetPoint("RIGHT")
    queryBtn:SetText(L["ROSTER_QUERY_VERSIONS"] or "Query Versions")
    queryBtn:SetScript("OnClick", function()
        self:QueryVersions()
    end)
    self.queryButton = queryBtn

    self.footer = footer
end

--[[--------------------------------------------------------------------
    Empty State
----------------------------------------------------------------------]]

function LoothingRosterPanelMixin:CreateEmptyState()
    local L = LOOTHING_LOCALE

    self.emptyText = self.listContainer:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    self.emptyText:SetPoint("CENTER")
    self.emptyText:SetText(L["ROSTER_NO_GROUP"] or "Not in a group")
    self.emptyText:SetTextColor(0.5, 0.5, 0.5)
    self.emptyText:Hide()
end

--[[--------------------------------------------------------------------
    Data Gathering
----------------------------------------------------------------------]]

--- Build a name-to-unitID map for the current group
-- @return table - { ["Name-Realm"] = "raidN" or "partyN" or "player" }
local function BuildUnitMap()
    local map = {}
    if IsInRaid() then
        for i = 1, GetNumGroupMembers() do
            local unit = "raid" .. i
            local name = UnitName(unit)
            if name then
                map[LoothingUtils.NormalizeName(name)] = unit
            end
        end
    elseif IsInGroup() then
        local playerName = UnitName("player")
        if playerName then
            map[LoothingUtils.NormalizeName(playerName)] = "player"
        end
        for i = 1, GetNumSubgroupMembers() do
            local unit = "party" .. i
            local name = UnitName(unit)
            if name then
                map[LoothingUtils.NormalizeName(name)] = unit
            end
        end
    end
    return map
end

--- Get item level for a unit (returns nil if unavailable)
-- @param unit string - Unit ID
-- @return number|nil
local function GetUnitItemLevel(unit)
    if not unit or not UnitExists(unit) then return nil end

    if UnitIsUnit(unit, "player") then
        local _, equipped = GetAverageItemLevel()
        if equipped and equipped > 0 then
            return equipped
        end
    end

    -- For other units, no passive API exists without inspect
    return nil
end

--- Gather roster data from all sources
function LoothingRosterPanelMixin:GatherRosterData()
    local roster = LoothingUtils.GetRaidRoster()

    if #roster == 0 then
        wipe(self.rosterData)
        return
    end

    -- Build name-to-unit map for ilvl lookups
    local unitMap = BuildUnitMap()

    -- Build council lookup using GetMembersInRaid (handles test mode + auto-include)
    local councilLookup = {}
    if Loothing.Council then
        for _, cName in ipairs(Loothing.Council:GetMembersInRaid()) do
            councilLookup[LoothingUtils.NormalizeName(cName)] = true
        end
    end

    -- Resolve ML name once (not per member)
    local mlName = Loothing.Settings and Loothing.Settings:GetMasterLooter() or nil

    -- Build history counts in a single O(H) pass
    local playerCounts = {}
    if Loothing.History then
        for _, entry in Loothing.History:GetEntries():Enumerate() do
            if entry.winner then
                local name = LoothingUtils.NormalizeName(entry.winner)
                playerCounts[name] = (playerCounts[name] or 0) + 1
            end
        end
    end

    local data = {}
    for _, member in ipairs(roster) do
        local entry = {
            name = member.name,
            shortName = member.shortName or LoothingUtils.GetShortName(member.name),
            classFile = member.classFile,
            class = member.class,
            online = member.online,
            role = member.role,
            rank = member.rank or 0,
            subgroup = member.subgroup,
            isDead = member.isDead,
        }

        -- Item level: try unit API first, then PlayerCache fallback
        local unit = unitMap[member.name]
        entry.ilvl = GetUnitItemLevel(unit)
        if not entry.ilvl and Loothing.PlayerCache then
            local cached = Loothing.PlayerCache:Get(member.name)
            if cached then
                entry.ilvl = cached.ilvl
                entry.specID = cached.specID
            end
        end

        -- Spec: try unit API if we have a unit and didn't get from cache
        if not entry.specID and unit and UnitIsUnit(unit, "player") then
            local specIndex = GetSpecialization()
            if specIndex then
                entry.specID = GetSpecializationInfo(specIndex)
            end
        end

        -- Version data
        if LoothingVersionCheck and LoothingVersionCheck.versionCache then
            local vData = LoothingVersionCheck.versionCache[member.name]
            if vData then
                entry.versionStr = vData.version
                entry.tVersion = vData.tVersion
                entry.isOutdated = vData.isOutdated
            end
        end

        -- Council (uses GetMembersInRaid lookup for test mode + auto-include support)
        entry.isCouncil = councilLookup[member.name] or false

        -- Observer
        entry.isObserver = Loothing.Observer and Loothing.Observer:IsObserver(member.name) or false

        -- Master Looter
        entry.isMasterLooter = mlName and LoothingUtils.IsSamePlayer(member.name, mlName) or false

        -- History
        entry.historyCount = playerCounts[member.name] or 0

        data[#data + 1] = entry
    end

    self.rosterData = data
end

--[[--------------------------------------------------------------------
    Sorting & Display
----------------------------------------------------------------------]]

--- Sort roster data and redisplay
function LoothingRosterPanelMixin:SortAndDisplay()
    local comp = SORT_COMPARATORS[self.sortColumn]
    if not comp then return end

    local asc = self.sortAscending

    table.sort(self.rosterData, function(a, b)
        -- Offline always sorts to bottom
        if a.online ~= b.online then
            return a.online and true or false
        end

        -- Swap arguments for descending (preserves strict weak ordering)
        if asc then
            return comp(a, b)
        else
            return comp(b, a)
        end
    end)

    self:DisplayRows()
end

--- Display rows from sorted rosterData
function LoothingRosterPanelMixin:DisplayRows()
    self.rowPool:ReleaseAll()

    if #self.rosterData == 0 then
        self.emptyText:Show()
        self.listContent:SetHeight(1)
        return
    end

    self.emptyText:Hide()

    local containerWidth = self:GetContentWidth()
    local fillWidth = math.max(60, containerWidth - FIXED_WIDTH_TOTAL)
    local yOffset = 0

    for _, entry in ipairs(self.rosterData) do
        local row = self.rowPool:Acquire()
        self:SetupRow(row, entry, yOffset, fillWidth)
        yOffset = yOffset - ROW_HEIGHT
    end

    self.listContent:SetHeight(math.abs(yOffset) + 4)
end

--- Initialize row child elements (called once per pooled frame)
local function InitRowElements(row)
    row:SetHeight(ROW_HEIGHT)

    row.bg = row:CreateTexture(nil, "BACKGROUND")
    row.bg:SetAllPoints()
    row.bg:SetColorTexture(0.1, 0.1, 0.1, 0.3)

    row.hl = row:CreateTexture(nil, "HIGHLIGHT")
    row.hl:SetAllPoints()
    row.hl:SetColorTexture(1, 1, 1, 0.08)

    -- Status dot
    row.statusDot = row:CreateTexture(nil, "ARTWORK")
    row.statusDot:SetSize(8, 8)

    -- Class icon
    row.classIcon = row:CreateTexture(nil, "ARTWORK")
    row.classIcon:SetSize(16, 16)

    -- Name text
    row.nameText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.nameText:SetJustifyH("LEFT")
    row.nameText:SetWordWrap(false)

    -- Role icon
    row.roleIcon = row:CreateTexture(nil, "ARTWORK")
    row.roleIcon:SetSize(16, 16)

    -- iLvl text
    row.ilvlText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.ilvlText:SetJustifyH("CENTER")

    -- Version text
    row.versionText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.versionText:SetJustifyH("LEFT")

    -- Council text
    row.councilText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.councilText:SetJustifyH("CENTER")

    -- Loot count text
    row.lootText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.lootText:SetJustifyH("CENTER")

    -- Rank text
    row.rankText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.rankText:SetJustifyH("LEFT")

    row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    row._initialized = true
end

--- Clear anchor points on all child elements of a reused row
local function ClearRowChildPoints(row)
    row.statusDot:ClearAllPoints()
    row.classIcon:ClearAllPoints()
    row.nameText:ClearAllPoints()
    row.roleIcon:ClearAllPoints()
    row.ilvlText:ClearAllPoints()
    row.versionText:ClearAllPoints()
    row.councilText:ClearAllPoints()
    row.lootText:ClearAllPoints()
    row.rankText:ClearAllPoints()
end

--- Setup a pooled row with entry data
function LoothingRosterPanelMixin:SetupRow(row, entry, yOffset, fillWidth)
    if not row._initialized then
        InitRowElements(row)
    else
        ClearRowChildPoints(row)
    end

    row:ClearAllPoints()
    row:SetPoint("TOPLEFT", 0, yOffset)
    row:SetPoint("TOPRIGHT", 0, yOffset)

    -- Alternating row background
    local idx = math.abs(yOffset / ROW_HEIGHT)
    if idx % 2 == 1 then
        row.bg:SetColorTexture(0.12, 0.12, 0.12, 0.4)
    else
        row.bg:SetColorTexture(0.08, 0.08, 0.08, 0.3)
    end

    -- Dim offline players
    local alpha = entry.online and 1.0 or 0.4

    -- Layout columns left to right
    local xPos = 0

    -- Status dot (20px)
    row.statusDot:SetPoint("LEFT", xPos + 6, 0)
    if entry.online then
        row.statusDot:SetColorTexture(0.2, 0.8, 0.2, 1)
    else
        row.statusDot:SetColorTexture(0.5, 0.5, 0.5, 0.6)
    end
    xPos = xPos + 20

    -- Name column (fillWidth): class icon + class-colored name
    row.classIcon:SetPoint("LEFT", xPos, 0)
    if entry.classFile then
        local coords = CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[entry.classFile]
        if coords then
            row.classIcon:SetTexture("Interface\\GLUES\\CHARACTERCREATE\\UI-CHARACTERCREATE-CLASSES")
            row.classIcon:SetTexCoord(unpack(coords))
        else
            row.classIcon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
            row.classIcon:SetTexCoord(0, 1, 0, 1)
        end
    else
        row.classIcon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
        row.classIcon:SetTexCoord(0, 1, 0, 1)
    end
    row.classIcon:SetAlpha(alpha)

    row.nameText:SetPoint("LEFT", xPos + 20, 0)
    row.nameText:SetWidth(fillWidth - 24)
    local displayName = entry.shortName or entry.name
    local mlTag = entry.isMasterLooter and " |cffffd100[ML]|r" or ""
    local classColor = RAID_CLASS_COLORS and entry.classFile and RAID_CLASS_COLORS[entry.classFile]
    if classColor then
        row.nameText:SetText(string.format("|cff%02x%02x%02x%s|r%s",
            classColor.r * 255, classColor.g * 255, classColor.b * 255,
            displayName, mlTag))
    else
        row.nameText:SetText(displayName .. mlTag)
    end
    row.nameText:SetAlpha(alpha)
    xPos = xPos + fillWidth

    -- Role (28px)
    row.roleIcon:SetPoint("LEFT", xPos + 6, 0)
    local roleAtlas = entry.role and ROLE_ATLASES[entry.role]
    if roleAtlas then
        row.roleIcon:SetAtlas(roleAtlas)
        row.roleIcon:Show()
    else
        row.roleIcon:Hide()
    end
    row.roleIcon:SetAlpha(alpha)
    xPos = xPos + 28

    -- iLvl (40px)
    row.ilvlText:SetPoint("LEFT", xPos, 0)
    row.ilvlText:SetWidth(40)
    if entry.ilvl and entry.ilvl > 0 then
        row.ilvlText:SetText(tostring(math.floor(entry.ilvl)))
    else
        row.ilvlText:SetText("?")
    end
    row.ilvlText:SetTextColor(0.7, 0.7, 0.7)
    row.ilvlText:SetAlpha(alpha)
    xPos = xPos + 40

    -- Version (90px)
    row.versionText:SetPoint("LEFT", xPos + 2, 0)
    row.versionText:SetWidth(86)
    if entry.versionStr then
        if entry.versionStr == "Not Installed" then
            row.versionText:SetText("Not Installed")
            row.versionText:SetTextColor(0.5, 0.5, 0.5)
        elseif entry.isOutdated then
            row.versionText:SetText(entry.versionStr)
            row.versionText:SetTextColor(1, 0.5, 0)
        else
            row.versionText:SetText(entry.versionStr)
            row.versionText:SetTextColor(0.2, 0.8, 0.2)
        end
    else
        row.versionText:SetText("--")
        row.versionText:SetTextColor(0.4, 0.4, 0.4)
    end
    row.versionText:SetAlpha(alpha)
    xPos = xPos + 90

    -- Council (58px)
    row.councilText:SetPoint("LEFT", xPos, 0)
    row.councilText:SetWidth(58)
    if entry.isCouncil then
        row.councilText:SetText("|cff00ff00\226\156\147|r")
        row.councilText:SetTextColor(1, 1, 1)
    else
        row.councilText:SetText("--")
        row.councilText:SetTextColor(0.4, 0.4, 0.4)
    end
    row.councilText:SetAlpha(alpha)
    xPos = xPos + 58

    -- Loot (44px)
    row.lootText:SetPoint("LEFT", xPos, 0)
    row.lootText:SetWidth(44)
    if entry.historyCount and entry.historyCount > 0 then
        row.lootText:SetText(tostring(entry.historyCount))
        row.lootText:SetTextColor(0.7, 0.7, 0.7)
    else
        row.lootText:SetText("--")
        row.lootText:SetTextColor(0.4, 0.4, 0.4)
    end
    row.lootText:SetAlpha(alpha)
    xPos = xPos + 44

    -- Rank (60px)
    row.rankText:SetPoint("LEFT", xPos + 2, 0)
    row.rankText:SetWidth(56)
    row.rankText:SetText(RANK_NAMES[entry.rank] or "Member")
    if entry.rank == 2 then
        row.rankText:SetTextColor(1, 0.82, 0)
    elseif entry.rank == 1 then
        row.rankText:SetTextColor(0.6, 0.8, 1)
    else
        row.rankText:SetTextColor(0.5, 0.5, 0.5)
    end
    row.rankText:SetAlpha(alpha)

    -- Tooltip + right-click context menu
    local panel = self
    row:SetScript("OnClick", function(_, button)
        if button == "RightButton" then
            panel:ShowRowContextMenu(row, entry)
        end
    end)
    row:SetScript("OnEnter", function()
        panel:ShowRowTooltip(row, entry)
    end)
    row:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    row:Show()
end

--[[--------------------------------------------------------------------
    Tooltip
----------------------------------------------------------------------]]

function LoothingRosterPanelMixin:ShowRowTooltip(row, entry)
    GameTooltip:SetOwner(row, "ANCHOR_RIGHT")

    -- Class-colored name header
    local classColor = RAID_CLASS_COLORS and entry.classFile and RAID_CLASS_COLORS[entry.classFile]
    if classColor then
        GameTooltip:AddLine(string.format("|cff%02x%02x%02x%s|r",
            classColor.r * 255, classColor.g * 255, classColor.b * 255,
            entry.name), 1, 1, 1)
    else
        GameTooltip:AddLine(entry.name, 1, 1, 1)
    end

    -- Role + Spec
    local roleStr = entry.role or "NONE"
    if roleStr == "NONE" or roleStr == "" then roleStr = "No Role" end
    local specStr = ""
    if entry.specID and entry.specID > 0 then
        local _, specName = GetSpecializationInfoByID(entry.specID)
        if specName then
            specStr = " - " .. specName
        end
    end
    GameTooltip:AddLine("Role: " .. roleStr .. specStr, 0.7, 0.7, 0.7)

    -- Item Level
    if entry.ilvl and entry.ilvl > 0 then
        GameTooltip:AddLine("Item Level: " .. math.floor(entry.ilvl), 0.7, 0.7, 0.7)
    end

    -- Subgroup
    if entry.subgroup then
        GameTooltip:AddLine("Group: " .. entry.subgroup, 0.7, 0.7, 0.7)
    end

    -- Online/Dead status
    if not entry.online then
        GameTooltip:AddLine("Offline", 1, 0.3, 0.3)
    elseif entry.isDead then
        GameTooltip:AddLine("Dead", 1, 0.3, 0.3)
    end

    GameTooltip:AddLine(" ")

    -- Version
    if entry.versionStr then
        local vColor = entry.isOutdated and "|cffff8000" or "|cff00cc00"
        GameTooltip:AddLine("Loothing: " .. vColor .. entry.versionStr .. "|r", 1, 1, 1)
        if entry.tVersion then
            GameTooltip:AddLine("Test Version: " .. entry.tVersion, 0.5, 0.8, 1)
        end
    else
        GameTooltip:AddLine("Loothing: |cff888888Unknown|r", 1, 1, 1)
    end

    -- Council
    if entry.isCouncil then
        GameTooltip:AddLine("Council Member", 0.2, 0.8, 0.2)
    end

    -- Master Looter
    if entry.isMasterLooter then
        GameTooltip:AddLine("Master Looter", 1, 0.82, 0)
    end

    -- Observer
    if entry.isObserver then
        GameTooltip:AddLine("Observer", 0.5, 0.8, 1)
    end

    -- History breakdown by response
    if entry.historyCount and entry.historyCount > 0 and Loothing.History then
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("Loot History: " .. entry.historyCount .. " items", 1, 0.82, 0)

        -- Build response breakdown
        local responseCounts = {}
        for _, histEntry in Loothing.History:GetEntries():Enumerate() do
            if histEntry.winner then
                local hName = LoothingUtils.NormalizeName(histEntry.winner)
                if hName == entry.name and histEntry.winnerResponse then
                    local resp = histEntry.winnerResponse
                    responseCounts[resp] = (responseCounts[resp] or 0) + 1
                end
            end
        end

        for resp, count in pairs(responseCounts) do
            local info = LOOTHING_RESPONSE_INFO and LOOTHING_RESPONSE_INFO[resp]
            local respName = info and info.name or tostring(resp)
            GameTooltip:AddLine("  " .. respName .. ": " .. count, 0.7, 0.7, 0.7)
        end
    end

    GameTooltip:Show()
end

--[[--------------------------------------------------------------------
    Right-Click Context Menu
----------------------------------------------------------------------]]

function LoothingRosterPanelMixin:ShowRowContextMenu(row, entry)
    local L = LOOTHING_LOCALE
    local playerName = LoothingUtils.GetPlayerFullName()
    local isPlayerLeader = UnitIsGroupLeader("player")
    local isPlayerAssistant = IsInRaid() and UnitIsGroupAssistant("player")
    local canManageRaid = isPlayerLeader or isPlayerAssistant
    local isSelf = LoothingUtils.IsSamePlayer(entry.name, playerName)

    MenuUtil.CreateContextMenu(row, function(ownerRegion, rootDescription)
        -- Header: class-colored player name
        local classColor = RAID_CLASS_COLORS and entry.classFile and RAID_CLASS_COLORS[entry.classFile]
        if classColor then
            rootDescription:CreateTitle(string.format("|cff%02x%02x%02x%s|r",
                classColor.r * 255, classColor.g * 255, classColor.b * 255,
                entry.shortName or entry.name))
        else
            rootDescription:CreateTitle(entry.shortName or entry.name)
        end

        -- Council toggle
        if Loothing.Council and not isSelf then
            if entry.isCouncil then
                rootDescription:CreateButton(L["ROSTER_REMOVE_COUNCIL"] or "Remove from Council", function()
                    Loothing.Council:RemoveMember(entry.name)
                    self:Refresh()
                end)
            else
                rootDescription:CreateButton(L["ROSTER_ADD_COUNCIL"] or "Add to Council", function()
                    Loothing.Council:AddMember(entry.name)
                    self:Refresh()
                end)
            end
        end

        -- Observer toggle
        if Loothing.Observer and not isSelf then
            if entry.isObserver then
                rootDescription:CreateButton(L["ROSTER_REMOVE_OBSERVER"] or "Remove as Observer", function()
                    Loothing.Observer:RemoveObserver(entry.name)
                    self:Refresh()
                end)
            else
                rootDescription:CreateButton(L["ROSTER_ADD_OBSERVER"] or "Add as Observer", function()
                    Loothing.Observer:AddObserver(entry.name)
                    self:Refresh()
                end)
            end
        end

        -- Master Looter assignment
        if Loothing.Settings then
            local explicitML = Loothing.Settings:GetMasterLooterName()
            local isExplicitML = explicitML and LoothingUtils.IsSamePlayer(entry.name, explicitML)

            if isExplicitML then
                rootDescription:CreateButton(L["ROSTER_CLEAR_ML"] or "Remove as Master Looter", function()
                    Loothing.Settings:ClearMasterLooter()
                    Loothing:Print(string.format("%s is no longer Master Looter", entry.shortName or entry.name))
                    self:Refresh()
                end)
            else
                rootDescription:CreateButton(L["ROSTER_SET_ML"] or "Set as Master Looter", function()
                    Loothing.Settings:SetMasterLooterName(entry.name)
                    Loothing:Print(string.format("%s is now Master Looter", entry.shortName or entry.name))
                    self:Refresh()
                end)
            end
        end

        rootDescription:CreateDivider()

        -- Whisper
        if not isSelf then
            rootDescription:CreateButton(L["WHISPER"] or "Whisper", function()
                ChatFrame_OpenChat("/w " .. entry.name .. " ")
            end)
        end

        -- Raid management (leader/assistant only, not self)
        if canManageRaid and not isSelf and IsInRaid() then
            rootDescription:CreateDivider()

            -- Promote to Leader (leader only)
            if isPlayerLeader then
                rootDescription:CreateButton(L["ROSTER_PROMOTE_LEADER"] or "Promote to Leader", function()
                    PromoteToLeader(entry.name)
                end)
            end

            -- Promote to Assistant / Demote
            if entry.rank == 0 then
                rootDescription:CreateButton(L["ROSTER_PROMOTE_ASSISTANT"] or "Promote to Assistant", function()
                    PromoteToAssistant(entry.name)
                end)
            elseif entry.rank == 1 and isPlayerLeader then
                rootDescription:CreateButton(L["ROSTER_DEMOTE"] or "Demote", function()
                    DemoteAssistant(entry.name)
                end)
            end

            -- Uninvite (red text for danger)
            rootDescription:CreateButton("|cffff3333" .. (L["ROSTER_UNINVITE"] or "Uninvite") .. "|r", function()
                UninviteUnit(entry.name)
            end)
        end
    end)
end

--[[--------------------------------------------------------------------
    Version Query
----------------------------------------------------------------------]]

function LoothingRosterPanelMixin:QueryVersions()
    if not LoothingVersionCheck then return end

    -- Register for callbacks on first query
    if not self.versionCallbackRegistered then
        LoothingVersionCheck:RegisterCallback("OnVersionReceived", function()
            self:Refresh()
        end, self)
        LoothingVersionCheck:RegisterCallback("OnQueryComplete", function()
            self:Refresh()
        end, self)
        self.versionCallbackRegistered = true
    end

    if IsInRaid() or IsInGroup() then
        LoothingVersionCheck:Query("raid")
    elseif IsInGuild() then
        LoothingVersionCheck:Query("guild")
    end
end

--[[--------------------------------------------------------------------
    Summary
----------------------------------------------------------------------]]

function LoothingRosterPanelMixin:UpdateSummary()
    local L = LOOTHING_LOCALE

    if #self.rosterData == 0 then
        self.summaryText:SetText("")
        return
    end

    local total = #self.rosterData
    local onlineCount = 0
    local installedCount = 0
    local councilCount = 0

    for _, entry in ipairs(self.rosterData) do
        if entry.online then onlineCount = onlineCount + 1 end
        if entry.versionStr and entry.versionStr ~= "Not Installed" then
            installedCount = installedCount + 1
        end
        if entry.isCouncil then councilCount = councilCount + 1 end
    end

    local fmt = L["ROSTER_SUMMARY"] or "%d Members | %d Online | %d Installed | %d Council"
    self.summaryText:SetText(string.format(fmt, total, onlineCount, installedCount, councilCount))
end

--[[--------------------------------------------------------------------
    Refresh
----------------------------------------------------------------------]]

function LoothingRosterPanelMixin:Refresh()
    if self.columnsNeedLayout then
        self:LayoutColumns()
    end

    self:GatherRosterData()
    self:UpdateSummary()

    if #self.rosterData == 0 then
        self.rowPool:ReleaseAll()
        self.emptyText:Show()
        self.summaryText:SetText("")
        self.listContent:SetHeight(1)
        return
    end

    self.emptyText:Hide()
    self:SortAndDisplay()
end

--- OnResize - no-op, scroll frame handles layout
function LoothingRosterPanelMixin:OnResize()
    self.columnsNeedLayout = true
    if self.frame:IsShown() then
        self:LayoutColumns()
        self:DisplayRows()
    end
end

--[[--------------------------------------------------------------------
    Frame Access
----------------------------------------------------------------------]]

function LoothingRosterPanelMixin:GetFrame()
    return self.frame
end

function LoothingRosterPanelMixin:Show()
    self.frame:Show()
    self:Refresh()
end

function LoothingRosterPanelMixin:Hide()
    self.frame:Hide()
end

--[[--------------------------------------------------------------------
    Factory
----------------------------------------------------------------------]]

function CreateLoothingRosterPanel(parent)
    local panel = LoolibCreateFromMixins(LoothingRosterPanelMixin)
    panel:Init(parent)
    return panel
end
