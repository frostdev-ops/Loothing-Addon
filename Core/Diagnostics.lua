--[[--------------------------------------------------------------------
    Loothing - Loot Council Addon for WoW 12.0+
    Diagnostics - Lightweight taint and global namespace audit helpers
----------------------------------------------------------------------]]

local ADDON_NAME, ns = ...
local Loolib = LibStub("Loolib")
local CreateFrame = CreateFrame
local CreateFromMixins = Loolib.CreateFromMixins
local ipairs = ipairs
local pairs = pairs
local pcall = pcall
local rawget = rawget
local sort = table.sort
local time = time
local wipe = wipe
local _G = _G

local Loothing = ns.Addon
local SecretUtil = Loolib.SecretUtil

local DiagnosticsMixin = ns.DiagnosticsMixin or {}
ns.DiagnosticsMixin = DiagnosticsMixin

local AUDIT_LOG_MODULE = "TaintAudit"
local MAX_EVENT_HISTORY = 25
local MAX_SCAN_HISTORY = 20

local TRACKED_GLOBALS = {
    "GetPlayerInfoByGUID",
    "GetRaidRosterInfo",
    "NotifyInspect",
    "SlashCmdList",
    "StaticPopupDialogs",
    "UnitGUID",
    "UnitName",
}

local EXPECTED_GLOBALS = {
    ["LibStub"] = true,
    ["Loolib"] = true,
    ["LoolibDB"] = true,
    ["SLASH_LOOTHING1"] = true,
    ["SLASH_LOOTHING2"] = true,
    ["Loolib_GlobalBridge_Loothing_OnAddonCompartmentClick"] = true,
    ["Loolib_GlobalBridge_Loothing_OnAddonCompartmentEnter"] = true,
    ["Loolib_GlobalBridge_Loothing_OnAddonCompartmentLeave"] = true,
}

local EXPECTED_INSECURE_GLOBALS = {
    ["SlashCmdList"] = true,
    ["StaticPopupDialogs"] = true,
}

local function CopyArray(source)
    local copy = {}
    for index, value in ipairs(source or {}) do
        copy[index] = value
    end
    return copy
end

local function SafeToString(value)
    if SecretUtil and SecretUtil.GuardToString then
        return SecretUtil.GuardToString(value, "<secret>")
    end
    return tostring(value)
end

local function SafeGetSecureState(name)
    if not issecurevariable then
        return true, nil
    end

    local ok, secure, taintedBy = pcall(issecurevariable, name)
    if not ok then
        return nil, "error"
    end

    return secure, taintedBy
end

local function PushLimited(list, value, maxCount)
    list[#list + 1] = value
    if #list > maxCount then
        table.remove(list, 1)
    end
end

function DiagnosticsMixin:Init()
    self.runtimeReady = false
    self.baseline = {
        tracked = {},
    }
    self.latestReport = nil
    self.scanHistory = {}
    self.blockedActions = {}

    local eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("ADDON_ACTION_BLOCKED")
    eventFrame:RegisterEvent("ADDON_ACTION_FORBIDDEN")
    eventFrame:SetScript("OnEvent", function(_, event, ...)
        self:OnEvent(event, ...)
    end)
    self.eventFrame = eventFrame
end

function DiagnosticsMixin:Log(level, message)
    local handler = Loothing and Loothing.ErrorHandler
    if not handler then
        return
    end

    if level == "error" and handler.LogError then
        handler:LogError(AUDIT_LOG_MODULE, message)
    elseif level == "warn" and handler.LogWarn then
        handler:LogWarn(AUDIT_LOG_MODULE, message)
    else
        handler:LogInfo(AUDIT_LOG_MODULE, message)
    end
end

function DiagnosticsMixin:OnEvent(event, ...)
    local values = { ... }
    local message = string.format(
        "%s: %s",
        event,
        table.concat({
            SafeToString(values[1]),
            SafeToString(values[2]),
            SafeToString(values[3]),
            SafeToString(values[4]),
        }, " | ")
    )

    local entry = {
        event = event,
        timestamp = time(),
        args = {
            SafeToString(values[1]),
            SafeToString(values[2]),
            SafeToString(values[3]),
            SafeToString(values[4]),
        },
        message = message,
    }

    PushLimited(self.blockedActions, entry, MAX_EVENT_HISTORY)
    self:Log("warn", message)
end

function DiagnosticsMixin:CaptureBaseline()
    wipe(self.baseline.tracked)

    for _, name in ipairs(TRACKED_GLOBALS) do
        self.baseline.tracked[name] = rawget(_G, name)
    end
end

function DiagnosticsMixin:MarkRuntimeReady()
    self.runtimeReady = true
    self:CaptureBaseline()
end

function DiagnosticsMixin:GetTrackedGlobalStatus()
    local statuses = {}

    for _, name in ipairs(TRACKED_GLOBALS) do
        local current = rawget(_G, name)
        local secure, taintedBy = SafeGetSecureState(name)
        statuses[#statuses + 1] = {
            name = name,
            present = current ~= nil,
            secure = secure,
            taintedBy = taintedBy,
            changedFromBaseline = self.runtimeReady and self.baseline.tracked[name] ~= current or false,
        }
    end

    sort(statuses, function(left, right)
        return left.name < right.name
    end)

    return statuses
end

function DiagnosticsMixin:GetUnexpectedGlobals()
    local unexpected = {}

    for name in pairs(_G) do
        if type(name) == "string"
            and (name:match("^Loothing") or name:match("^Loolib"))
            and not EXPECTED_GLOBALS[name]
        then
            unexpected[#unexpected + 1] = name
        end
    end

    sort(unexpected)
    return unexpected
end

function DiagnosticsMixin:GetMissingExpectedGlobals()
    local missing = {}

    for name in pairs(EXPECTED_GLOBALS) do
        if rawget(_G, name) == nil then
            missing[#missing + 1] = name
        end
    end

    sort(missing)
    return missing
end

function DiagnosticsMixin:RunScan(reason)
    local trackedGlobals = self:GetTrackedGlobalStatus()
    local unexpectedGlobals = self:GetUnexpectedGlobals()
    local missingExpected = self:GetMissingExpectedGlobals()

    local changedTracked = 0
    local insecureTracked = 0
    for _, entry in ipairs(trackedGlobals) do
        if entry.changedFromBaseline then
            changedTracked = changedTracked + 1
        end
        if entry.secure == false and not EXPECTED_INSECURE_GLOBALS[entry.name] then
            insecureTracked = insecureTracked + 1
        end
    end

    local report = {
        timestamp = time(),
        reason = reason or "manual",
        trackedGlobals = trackedGlobals,
        unexpectedGlobals = unexpectedGlobals,
        missingExpectedGlobals = missingExpected,
        blockedActions = CopyArray(self.blockedActions),
        summary = {
            trackedCount = #trackedGlobals,
            changedTrackedCount = changedTracked,
            insecureTrackedCount = insecureTracked,
            unexpectedGlobalCount = #unexpectedGlobals,
            missingExpectedCount = #missingExpected,
            blockedActionCount = #self.blockedActions,
        },
    }

    self.latestReport = report
    PushLimited(self.scanHistory, report, MAX_SCAN_HISTORY)

    local level = (report.summary.changedTrackedCount > 0
        or report.summary.unexpectedGlobalCount > 0
        or report.summary.blockedActionCount > 0
        or report.summary.missingExpectedCount > 0)
        and "warn"
        or "info"

    self:Log(level, string.format(
        "scan=%s unexpected=%d changed=%d insecure=%d blocked=%d missing=%d",
        report.reason,
        report.summary.unexpectedGlobalCount,
        report.summary.changedTrackedCount,
        report.summary.insecureTrackedCount,
        report.summary.blockedActionCount,
        report.summary.missingExpectedCount
    ))

    return report
end

function DiagnosticsMixin:GetReport()
    return self.latestReport
end

function DiagnosticsMixin:Clear()
    self.latestReport = nil
    wipe(self.scanHistory)
    wipe(self.blockedActions)
    wipe(self.baseline.tracked)

    if self.runtimeReady then
        self:CaptureBaseline()
    end
end

function DiagnosticsMixin:PrintReport(report, printer)
    report = report or self.latestReport
    printer = printer or function(message)
        if Loothing and Loothing.Print then
            Loothing:Print(message)
        end
    end

    if not report then
        printer("No taint audit report available.")
        return
    end

    printer(string.format(
        "Taint audit: unexpected=%d changed=%d insecure=%d blocked=%d missing=%d",
        report.summary.unexpectedGlobalCount,
        report.summary.changedTrackedCount,
        report.summary.insecureTrackedCount,
        report.summary.blockedActionCount,
        report.summary.missingExpectedCount
    ))

    if #report.unexpectedGlobals > 0 then
        printer("Unexpected globals: " .. table.concat(report.unexpectedGlobals, ", "))
    end

    if #report.missingExpectedGlobals > 0 then
        printer("Missing expected globals: " .. table.concat(report.missingExpectedGlobals, ", "))
    end

    local trackedIssues = {}
    for _, entry in ipairs(report.trackedGlobals) do
        if entry.changedFromBaseline or (entry.secure == false and not EXPECTED_INSECURE_GLOBALS[entry.name]) then
            local parts = { entry.name }
            if entry.changedFromBaseline then
                parts[#parts + 1] = "changed"
            end
            if entry.secure == false then
                parts[#parts + 1] = "tainted"
                if entry.taintedBy and entry.taintedBy ~= "error" then
                    parts[#parts + 1] = "by " .. SafeToString(entry.taintedBy)
                end
            end
            trackedIssues[#trackedIssues + 1] = table.concat(parts, " ")
        end
    end

    if #trackedIssues > 0 then
        printer("Tracked global issues: " .. table.concat(trackedIssues, ", "))
    else
        printer("Tracked globals are secure and unchanged from baseline.")
    end

    if #report.blockedActions > 0 then
        local latest = report.blockedActions[#report.blockedActions]
        printer("Latest blocked action: " .. latest.message)
    end
end

local function CreateDiagnostics()
    local diagnostics = CreateFromMixins(DiagnosticsMixin)
    diagnostics:Init()
    return diagnostics
end

ns.CreateDiagnostics = CreateDiagnostics
