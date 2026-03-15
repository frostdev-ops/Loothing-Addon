--[[--------------------------------------------------------------------
    Loothing - Settings Export/Import
    Serialize → Compress(6) → Base64 for sharing profiles as strings.
    Import reverses the pipeline with validation at each step.
----------------------------------------------------------------------]]

local _, ns = ...
local Loothing = ns.Addon
local Loolib = LibStub("Loolib")
local Utils = ns.Utils

ns.SettingsExportMixin = ns.SettingsExportMixin or {}
local SettingsExportMixin = ns.SettingsExportMixin

local EXPORT_VERSION = 1

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
    local L = Loothing.Locale
    local merged = self:MergeWithDefaults(payload.settings)

    if mode == "new" then
        local baseName = payload._profileName or "Imported"
        local profileName = self:GetUniqueProfileName(baseName)

        Loothing.Settings:SetProfile(profileName)
        Loothing.Settings:SetProfileData(merged)

        PrintMessage(string.format(
            L["IMPORT_SUCCESS_NEW"] or "Settings imported as new profile: %s", profileName))
    else
        Loothing.Settings:SetProfileData(merged)

        PrintMessage(L["IMPORT_SUCCESS_CURRENT"] or "Settings imported to current profile.")
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
        PrintMessage(string.format(
            Loothing.Locale["PROFILE_SHARE_RECEIVED"]
                or "Received shared settings from %s.",
            sender))
    end

    PrintMessage(string.format("Profile: %s | Exported: %s | Version: %s",
        payload._profileName or "Unknown",
        payload._exportDate and date("%Y-%m-%d %H:%M", payload._exportDate) or "unknown",
        payload._addonVersion or "unknown"))
end

--- Present a validated settings payload to the user for confirmation.
-- @param payload table
-- @param parentFrame Frame|nil
-- @param sender string|nil
function SettingsExportMixin:PresentImportPayload(payload, parentFrame, sender)
    local L = Loothing.Locale

    if payload._addonVersion and payload._addonVersion ~= Loothing.VERSION then
        PrintMessage(string.format(
            L["IMPORT_VERSION_WARN"] or "Note: exported with Loothing v%s (you have v%s).",
            payload._addonVersion, Loothing.VERSION))
    end

    self:PrintImportSummary(payload, sender)

    local Popups = ns.Popups
    if Popups then
        local mixin = self
        Popups:Show("LOOTHING_SETTINGS_IMPORT_CONFIRM", {
            onNewProfile = function()
                mixin:ApplyImport(payload, "new")
                if parentFrame then parentFrame:Hide() end
            end,
            onApplyCurrent = function()
                mixin:ApplyImport(payload, "current")
                if parentFrame then parentFrame:Hide() end
            end,
        })
    end
end

--- Export the current profile and send it over addon comm to one target.
-- @param target string
-- @return boolean success
-- @return string|nil errMsg
function SettingsExportMixin:SendSharedExport(target)
    local L = Loothing.Locale
    if type(target) ~= "string" or target == "" then
        return false, L["PROFILE_SHARE_TARGET_REQUIRED"] or "Select a target first."
    end

    if not Loothing.Comm or not Loothing.Comm.SendProfileExport then
        return false, L["PROFILE_SHARE_UNAVAILABLE"] or "Profile sharing is unavailable."
    end

    local encoded, err = self:Export()
    if not encoded then
        return false, err or "Export failed"
    end

    Loothing.Comm:SendProfileExport(encoded, target)
    PrintMessage(string.format(
        L["PROFILE_SHARE_SENT"] or "Shared current profile with %s.",
        target))
    return true
end

--- Handle a settings export received over addon comm.
-- @param exportString string
-- @param sender string
function SettingsExportMixin:HandleSharedExport(exportString, sender)
    local L = Loothing.Locale
    local success, payload = self:Import(exportString)
    if not success then
        PrintMessage(string.format(
            L["PROFILE_SHARE_FAILED"] or "Shared settings from %s could not be imported: %s",
            sender or "unknown", payload or "unknown"))
        return
    end

    self:PresentImportPayload(payload, nil, sender)
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
    local L = Loothing.Locale

    local encoded, err = self:Export()
    if not encoded then
        PrintMessage(string.format(L["EXPORT_FAILED"] or "Export failed: %s", err or "unknown"))
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

    local L = Loothing.Locale

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
    title:SetText(L["EXPORT_TITLE"] or "Export Settings")

    local desc = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    desc:SetPoint("TOP", title, "BOTTOM", 0, -4)
    desc:SetText(L["EXPORT_DESC"] or "Press Ctrl+A to select all, then Ctrl+C to copy.")

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
    closeBtn:SetText(L["CLOSE"] or "Close")
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

    local L = Loothing.Locale
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
    title:SetText(L["IMPORT_TITLE"] or "Import Settings")

    local desc = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    desc:SetPoint("TOP", title, "BOTTOM", 0, -4)
    desc:SetText(L["IMPORT_DESC"] or "Paste an exported settings string below, then click Import.")

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
    importBtn:SetText(L["IMPORT_BUTTON"] or "Import")
    importBtn:SetScript("OnClick", function()
        mixin:ProcessImport(editBox:GetText(), f)
    end)

    local cancelBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    cancelBtn:SetSize(80, 24)
    cancelBtn:SetPoint("RIGHT", importBtn, "LEFT", -8, 0)
    cancelBtn:SetText(L["CANCEL"] or "Cancel")
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
    local L = Loothing.Locale

    local success, payload = self:Import(text)
    if not success then
        PrintMessage(string.format(L["IMPORT_FAILED"] or "Import failed: %s", payload))
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
