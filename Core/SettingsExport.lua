--[[--------------------------------------------------------------------
    Loothing - Settings Export/Import
    Serialize → Compress(6) → Base64 for sharing profiles as strings.
    Import reverses the pipeline with validation at each step.
----------------------------------------------------------------------]]

local _, ns = ...
local Loothing = ns.Addon
local L = ns.Locale
local Loolib = LibStub("Loolib")
local Utils = ns.Utils

ns.SettingsExportMixin = ns.SettingsExportMixin or {}
local SettingsExportMixin = ns.SettingsExportMixin

local EXPORT_VERSION = 1
local SHARE_SCOPE_DIRECT = "direct"
local RECENT_SHARE_TTL = 180
local BROADCAST_COOLDOWN = 30
local BROADCAST_QUEUE_PRESSURE_LIMIT = 0.75
local MAX_PENDING_SHARED_IMPORTS = 5

local function PrintMessage(msg)
    print("|cFF33FF99Loothing|r: " .. msg)
end

--[[--------------------------------------------------------------------
    Initialization
----------------------------------------------------------------------]]

function SettingsExportMixin:Init()
    self.ExportCodec = Loolib.ExportCodec
    self.exportFrame = nil
    self.importFrame = nil
    self.pendingImportQueue = {}
    self.activeImportDialog = nil
    self.recentShareKeys = {}
    self.lastRecentShareSweep = 0
    self.lastBroadcastAt = 0
end

--[[--------------------------------------------------------------------
    Export Pipeline
----------------------------------------------------------------------]]

--- Remove machine-specific fields from profile data
-- @param data table - Deep copy of profile data
-- @return table - Sanitized data (mutated in place)
function SettingsExportMixin:SanitizeProfileData(data)
    if not data then return {} end

    if data.frame then
        data.frame.position = nil
    end
    if data.rollFrame then
        data.rollFrame.position = nil
    end
    if data.settings then
        data.settings.mainFramePosition = nil
    end

    -- History belongs in global scope, not profile exports
    data.history = nil

    return data
end

--- Build the export envelope with metadata
-- @return table|nil
function SettingsExportMixin:BuildExportPayload()
    local profileData = Loothing.Settings:GetProfileData()
    if not profileData then return nil end

    return {
        _exportVersion = EXPORT_VERSION,
        _addonVersion  = Loothing.VERSION,
        _profileName   = Loothing.Settings:GetCurrentProfile() or "Default",
        _exportDate    = time(),
        settings       = self:SanitizeProfileData(profileData),
    }
end

--- Export current profile to a Base64 string
-- @return string|nil encoded
-- @return string|nil errMsg
function SettingsExportMixin:Export()
    local payload = self:BuildExportPayload()
    if not payload then
        return nil, "Failed to build export payload"
    end

    if not self.ExportCodec then
        return nil, "Export codec unavailable"
    end

    return self.ExportCodec:EncodeTable(payload, {
        compression = "deflate",
        level = 6,
    })
end

--[[--------------------------------------------------------------------
    Import Pipeline
----------------------------------------------------------------------]]

--- Import a Base64 settings string
-- @return boolean success
-- @return table|string payload or error message
function SettingsExportMixin:Import(base64String)
    if not self.ExportCodec then
        return false, "Export codec unavailable"
    end

    local success, payload = self.ExportCodec:DecodeTable(base64String, {
        compression = "deflate",
        level = 6,
    })
    if not success then
        if payload == "Decompression failed" then
            return false, "Decompression failed — data may be corrupted"
        end
        return false, payload
    end

    local valid, validErr = self:ValidatePayload(payload)
    if not valid then
        return false, validErr
    end

    return true, payload
end

--- Validate an import payload
-- @return boolean valid
-- @return string|nil errMsg
function SettingsExportMixin:ValidatePayload(payload)
    if type(payload) ~= "table" then
        return false, "Invalid payload type"
    end

    if not payload._exportVersion then
        return false, "Not a Loothing settings export"
    end

    if payload._exportVersion > EXPORT_VERSION then
        return false, string.format(
            "Export version %d is newer than supported (%d) — update Loothing first",
            payload._exportVersion, EXPORT_VERSION)
    end

    if type(payload.settings) ~= "table" then
        return false, "Missing or invalid settings data"
    end

    return true
end

--[[--------------------------------------------------------------------
    Merge Logic
----------------------------------------------------------------------]]

--- Deep-merge imported settings with PROFILE_DEFAULTS.
-- Keys only in defaults → filled from defaults.
-- Keys only in import → dropped.
-- Type mismatches → keep default.
-- @param imported table
-- @return table
function SettingsExportMixin:MergeWithDefaults(imported)
    local defaults = Loothing.Settings:GetProfileDefaults()
    if not defaults then return imported end
    return self:DeepMerge(imported, defaults)
end

--- Recursive deep merge
-- @param src table - Imported data
-- @param def table - Default data
-- @return table
function SettingsExportMixin:DeepMerge(src, def)
    local result = {}

    for k, defaultVal in pairs(def) do
        local importedVal = src[k]

        if importedVal == nil then
            result[k] = Utils.DeepCopy(defaultVal)
        elseif type(importedVal) ~= type(defaultVal) then
            result[k] = Utils.DeepCopy(defaultVal)
        elseif type(defaultVal) == "table" then
            result[k] = self:DeepMerge(importedVal, defaultVal)
        else
            result[k] = importedVal
        end
    end

    return result
end

--[[--------------------------------------------------------------------
    Apply Import
----------------------------------------------------------------------]]

--- Apply a validated import payload
-- @param payload table
-- @param mode string - "new" or "current"
function SettingsExportMixin:ApplyImport(payload, mode)

    local merged = self:MergeWithDefaults(payload.settings)

    if mode == "new" then
        local baseName = payload._profileName or "Imported"
        local profileName = self:GetUniqueProfileName(baseName)

        Loothing.Settings:SetProfile(profileName)
        Loothing.Settings:SetProfileData(merged)

        PrintMessage(string.format(
            L["IMPORT_SUCCESS_NEW"], profileName))
    else
        Loothing.Settings:SetProfileData(merged)

        PrintMessage(L["IMPORT_SUCCESS_CURRENT"])
    end

    -- Refresh dependent systems
    if Loothing.ResponseManager then
        Loothing.ResponseManager:LoadResponses()
    end
    if Loolib.Config then
        Loolib.Config:NotifyChange("Loothing")
    end
end

--- Print a compact chat summary for an imported payload.
-- @param payload table
-- @param sender string|nil
function SettingsExportMixin:PrintImportSummary(payload, sender)
    if sender then
        PrintMessage(string.format(L["PROFILE_SHARE_RECEIVED"], sender))
    end

    PrintMessage(string.format(L["IMPORT_SUMMARY"],
        payload._profileName or L["UNKNOWN"],
        payload._exportDate and date("%Y-%m-%d %H:%M", payload._exportDate) or L["UNKNOWN"],
        payload._addonVersion or L["UNKNOWN"]))
end

--- Present a validated settings payload to the user for confirmation.
-- @param payload table
-- @param parentFrame Frame|nil
-- @param sender string|nil
-- @param metadata table|nil
function SettingsExportMixin:PresentImportPayload(payload, parentFrame, sender, metadata)
    if sender then
        local accepted, reason = self:QueueIncomingImport(payload, parentFrame, sender, metadata)
        if not accepted and reason then
            PrintMessage(reason)
        end
        return
    end

    self:ShowImportConfirmation({
        payload = payload,
        parentFrame = parentFrame,
        sender = sender,
        metadata = metadata,
    })
end

--- Remove expired incoming share dedupe markers.
-- @param now number|nil
function SettingsExportMixin:SweepRecentShareKeys(now)
    now = now or GetTime()
    if now - (self.lastRecentShareSweep or 0) < 30 then
        return
    end

    self.lastRecentShareSweep = now
    for key, seenAt in pairs(self.recentShareKeys) do
        if now - seenAt > RECENT_SHARE_TTL then
            self.recentShareKeys[key] = nil
        end
    end
end

--- Build a stable dedupe key for an inbound shared export.
-- @param payload table
-- @param sender string
-- @param metadata table|nil
-- @return string
function SettingsExportMixin:GetIncomingShareKey(payload, sender, metadata)
    if metadata and metadata.shareID and metadata.shareID ~= "" then
        return sender .. ":" .. metadata.shareID
    end

    return table.concat({
        sender or "unknown",
        metadata and metadata.scope or SHARE_SCOPE_DIRECT,
        tostring(payload._exportDate or 0),
        tostring(payload._profileName or ""),
        tostring(payload._addonVersion or ""),
    }, ":")
end

--- Record an inbound shared export and reject recent duplicates.
-- @param key string
-- @return boolean
function SettingsExportMixin:RememberIncomingShare(key)
    local now = GetTime()
    self:SweepRecentShareKeys(now)

    if self.recentShareKeys[key] and (now - self.recentShareKeys[key]) <= RECENT_SHARE_TTL then
        return false
    end

    self.recentShareKeys[key] = now
    return true
end

--- Queue an inbound shared export so confirmation popups are serialized.
-- @param payload table
-- @param parentFrame Frame|nil
-- @param sender string
-- @param metadata table|nil
-- @return boolean accepted
-- @return string|nil errMsg
function SettingsExportMixin:QueueIncomingImport(payload, parentFrame, sender, metadata)
    local key = self:GetIncomingShareKey(payload, sender, metadata)
    if not self:RememberIncomingShare(key) then
        Loothing:Debug("Dropped duplicate shared settings import from", sender)
        return false
    end

    if #self.pendingImportQueue >= MAX_PENDING_SHARED_IMPORTS then
        Loothing:Debug("Dropped shared settings import from", sender, "- import queue full")
        return false, string.format(L["PROFILE_SHARE_QUEUE_FULL"], sender or L["UNKNOWN"])
    end

    self.pendingImportQueue[#self.pendingImportQueue + 1] = {
        payload = payload,
        parentFrame = parentFrame,
        sender = sender,
        metadata = metadata,
    }

    self:ShowNextQueuedImport()
    return true
end

--- Show the next queued shared import confirmation, if any.
function SettingsExportMixin:ShowNextQueuedImport()
    if self.activeImportDialog then
        return
    end

    local nextImport = table.remove(self.pendingImportQueue, 1)
    if not nextImport then
        return
    end

    self:ShowImportConfirmation(nextImport)
end

--- Render one import confirmation popup and advance the queue when it closes.
-- @param request table
function SettingsExportMixin:ShowImportConfirmation(request)
    local payload = request.payload
    local parentFrame = request.parentFrame
    local sender = request.sender

    if payload._addonVersion and payload._addonVersion ~= Loothing.VERSION then
        PrintMessage(string.format(
            L["IMPORT_VERSION_WARN"],
            payload._addonVersion, Loothing.VERSION))
    end

    self:PrintImportSummary(payload, sender)

    local Popups = ns.Popups
    if not Popups then
        return
    end

    local mixin = self
    local dialog = Popups:Show("LOOTHING_SETTINGS_IMPORT_CONFIRM", {
        onNewProfile = function()
            mixin:ApplyImport(payload, "new")
            if parentFrame then parentFrame:Hide() end
        end,
        onApplyCurrent = function()
            mixin:ApplyImport(payload, "current")
            if parentFrame then parentFrame:Hide() end
        end,
    })

    self.activeImportDialog = dialog or true
    if dialog and dialog.RegisterCallback then
        dialog:RegisterCallback("OnHide", function()
            if mixin.activeImportDialog == dialog then
                mixin.activeImportDialog = nil
            end
            mixin:ShowNextQueuedImport()
        end)
    else
        self.activeImportDialog = nil
    end
end

--- Export the current profile and send it over addon comm to one target.
-- @param target string
-- @return boolean success
-- @return string|nil errMsg
function SettingsExportMixin:SendSharedExport(target)

    if type(target) ~= "string" or target == "" then
        return false, L["PROFILE_SHARE_TARGET_REQUIRED"]
    end

    if not Loothing.Comm or not Loothing.Comm.SendProfileExport then
        return false, L["PROFILE_SHARE_UNAVAILABLE"]
    end

    local encoded, err = self:Export()
    if not encoded then
        return false, err or "Export failed"
    end

    Loothing.Comm:SendProfileExport(encoded, target, {
        scope = SHARE_SCOPE_DIRECT,
        shareID = Utils.GenerateGUID(),
    })
    PrintMessage(string.format(
        L["PROFILE_SHARE_SENT"],
        target))
    return true
end

--- Validate whether the current user can broadcast a shared export to the active group.
-- @return boolean
-- @return string|nil
function SettingsExportMixin:CanBroadcastSharedExport()
    if not Loothing.Comm or not Loothing.Comm.BroadcastProfileExport then
        return false, L["PROFILE_SHARE_UNAVAILABLE"]
    end

    if not Loothing.Session or not Loothing.Session:IsActive() then
        return false, L["PROFILE_SHARE_BROADCAST_NO_SESSION"]
    end

    if not Loothing.Session:IsMasterLooter() then
        return false, L["PROFILE_SHARE_BROADCAST_NOT_ML"]
    end

    if not IsInRaid() and not IsInGroup() then
        return false, L["PROFILE_SHARE_BROADCAST_NO_GROUP"]
    end

    local queuePressure = Loolib.Comm and Loolib.Comm:GetQueuePressure() or 0
    if Loolib.Comm and (Loolib.Comm:IsQueueFull() or queuePressure >= BROADCAST_QUEUE_PRESSURE_LIMIT) then
        return false, L["PROFILE_SHARE_BROADCAST_BUSY"]
    end

    local remaining = BROADCAST_COOLDOWN - (GetTime() - (self.lastBroadcastAt or 0))
    if remaining > 0 then
        return false, string.format(L["PROFILE_SHARE_BROADCAST_COOLDOWN"], math.ceil(remaining))
    end

    return true
end

--- Export the current profile and broadcast it to the active raid/party.
-- Restricted to the active session's master looter.
-- @return boolean success
-- @return string|nil errMsg
function SettingsExportMixin:BroadcastSharedExport()
    local allowed, reason = self:CanBroadcastSharedExport()
    if not allowed then
        return false, reason
    end

    local encoded, err = self:Export()
    if not encoded then
        return false, err or "Export failed"
    end

    local sessionID = Loothing.Session and Loothing.Session:GetSessionID() or nil
    local shareID = Utils.GenerateGUID()

    Loothing.Comm:BroadcastProfileExport(encoded, shareID, sessionID)
    self.lastBroadcastAt = GetTime()

    PrintMessage(L["PROFILE_SHARE_BROADCAST_SENT"])
    return true
end

--- Handle a settings export received over addon comm.
-- @param exportString string
-- @param sender string
-- @param metadata table|nil
function SettingsExportMixin:HandleSharedExport(exportString, sender, metadata)
    if Utils.IsSamePlayer(sender, Utils.GetPlayerFullName()) then
        return
    end

    local success, payload = self:Import(exportString)
    if not success then
        PrintMessage(string.format(
            L["PROFILE_SHARE_FAILED"],
            sender or "unknown", payload or "unknown"))
        return
    end

    self:PresentImportPayload(payload, nil, sender, metadata)
end

--- Generate a unique profile name
-- @param baseName string
-- @return string
function SettingsExportMixin:GetUniqueProfileName(baseName)
    local profiles = Loothing.Settings:GetProfiles() or {}
    local existing = {}
    for _, name in ipairs(profiles) do
        existing[name] = true
    end

    if not existing[baseName] then return baseName end

    for i = 2, 99 do
        local candidate = baseName .. " (" .. i .. ")"
        if not existing[candidate] then return candidate end
    end

    return baseName .. " (" .. time() .. ")"
end

--[[--------------------------------------------------------------------
    UI — Export Dialog (lazy singleton)
----------------------------------------------------------------------]]

function SettingsExportMixin:ShowExportDialog()


    local encoded, err = self:Export()
    if not encoded then
        PrintMessage(string.format(L["EXPORT_FAILED"], err or "unknown"))
        return
    end

    local frame = self:GetOrCreateExportFrame()
    frame.editBox:SetText(encoded)
    frame.editBox:HighlightText()
    frame.editBox:SetFocus()
    frame:Show()
end

function SettingsExportMixin:GetOrCreateExportFrame()
    if self.exportFrame then return self.exportFrame end



    local f = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    f:SetSize(500, 350)
    f:SetPoint("CENTER")
    f:SetFrameStrata("DIALOG")
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    f:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 8, right = 8, top = 8, bottom = 8 },
    })
    f:SetBackdropColor(0, 0, 0, 0.9)

    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", 0, -16)
    title:SetText(L["EXPORT_TITLE"])

    local desc = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    desc:SetPoint("TOP", title, "BOTTOM", 0, -4)
    desc:SetText(L["EXPORT_DESC"])

    local scrollFrame = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 16, -56)
    scrollFrame:SetPoint("BOTTOMRIGHT", -32, 48)

    local editBox = CreateFrame("EditBox", nil, scrollFrame)
    editBox:SetMultiLine(true)
    editBox:SetAutoFocus(false)
    editBox:SetFontObject(ChatFontNormal)
    editBox:SetWidth(440)
    editBox:SetScript("OnEscapePressed", function(eb) eb:ClearFocus(); f:Hide() end)
    scrollFrame:SetScrollChild(editBox)
    f.editBox = editBox

    local closeBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    closeBtn:SetSize(80, 24)
    closeBtn:SetPoint("BOTTOM", 0, 12)
    closeBtn:SetText(L["CLOSE"])
    closeBtn:SetScript("OnClick", function() f:Hide() end)

    local xBtn = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    xBtn:SetPoint("TOPRIGHT", -4, -4)

    f:Hide()
    self.exportFrame = f
    return f
end

--[[--------------------------------------------------------------------
    UI — Import Dialog (lazy singleton)
----------------------------------------------------------------------]]

function SettingsExportMixin:ShowImportDialog()
    local frame = self:GetOrCreateImportFrame()
    frame.editBox:SetText("")
    frame.editBox:SetFocus()
    frame:Show()
end

function SettingsExportMixin:GetOrCreateImportFrame()
    if self.importFrame then return self.importFrame end


    local mixin = self

    local f = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    f:SetSize(500, 350)
    f:SetPoint("CENTER")
    f:SetFrameStrata("DIALOG")
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    f:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 8, right = 8, top = 8, bottom = 8 },
    })
    f:SetBackdropColor(0, 0, 0, 0.9)

    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", 0, -16)
    title:SetText(L["IMPORT_TITLE"])

    local desc = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    desc:SetPoint("TOP", title, "BOTTOM", 0, -4)
    desc:SetText(L["IMPORT_DESC"])

    local scrollFrame = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 16, -56)
    scrollFrame:SetPoint("BOTTOMRIGHT", -32, 48)

    local editBox = CreateFrame("EditBox", nil, scrollFrame)
    editBox:SetMultiLine(true)
    editBox:SetAutoFocus(false)
    editBox:SetFontObject(ChatFontNormal)
    editBox:SetWidth(440)
    editBox:SetScript("OnEscapePressed", function(eb) eb:ClearFocus(); f:Hide() end)
    scrollFrame:SetScrollChild(editBox)
    f.editBox = editBox

    local importBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    importBtn:SetSize(100, 24)
    importBtn:SetPoint("BOTTOMRIGHT", -52, 12)
    importBtn:SetText(L["IMPORT_BUTTON"])
    importBtn:SetScript("OnClick", function()
        mixin:ProcessImport(editBox:GetText(), f)
    end)

    local cancelBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    cancelBtn:SetSize(80, 24)
    cancelBtn:SetPoint("RIGHT", importBtn, "LEFT", -8, 0)
    cancelBtn:SetText(L["CANCEL"])
    cancelBtn:SetScript("OnClick", function() f:Hide() end)

    local xBtn = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    xBtn:SetPoint("TOPRIGHT", -4, -4)

    f:Hide()
    self.importFrame = f
    return f
end

--- Validate pasted string and show confirmation popup
-- @param text string
-- @param parentFrame Frame
function SettingsExportMixin:ProcessImport(text, parentFrame)


    local success, payload = self:Import(text)
    if not success then
        PrintMessage(string.format(L["IMPORT_FAILED"], payload))
        return
    end

    self:PresentImportPayload(payload, parentFrame, nil)
end

--- Validate pasted string and show confirmation popup (inline version — no parent frame)
-- Delegates to ProcessImport with nil parentFrame.
-- @param text string
function SettingsExportMixin:ProcessImportInline(text)
    self:ProcessImport(text, nil)
end

-- ns.SettingsExportMixin exported above
