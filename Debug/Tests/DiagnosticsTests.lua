--[[--------------------------------------------------------------------
    Loothing - Loot Council Addon for WoW 12.0+
    DiagnosticsTests - Coverage for runtime taint/global audit helpers
----------------------------------------------------------------------]]

local _, ns = ...

local TestRunner = ns.TestRunner
local Assert = ns.Assert

local UNSET = {}
local originalGlobals = {}
local createdDiagnostics = {}

local function SetTemporaryGlobal(name, value)
    if originalGlobals[name] == nil then
        local existing = rawget(_G, name)
        originalGlobals[name] = existing == nil and UNSET or existing
    end
    _G[name] = value
end

local function RestoreGlobals()
    for name, value in pairs(originalGlobals) do
        _G[name] = value == UNSET and nil or value
        originalGlobals[name] = nil
    end
end

local function CreateDiagnostics()
    local diagnostics = ns.CreateDiagnostics()
    diagnostics:MarkRuntimeReady()
    createdDiagnostics[#createdDiagnostics + 1] = diagnostics
    return diagnostics
end

TestRunner:Describe("Diagnostics", function()

    TestRunner:AfterEach(function()
        RestoreGlobals()
        for index = #createdDiagnostics, 1, -1 do
            local diagnostics = createdDiagnostics[index]
            if diagnostics.eventFrame and diagnostics.eventFrame.UnregisterAllEvents then
                diagnostics.eventFrame:UnregisterAllEvents()
                diagnostics.eventFrame:SetScript("OnEvent", nil)
            end
            createdDiagnostics[index] = nil
        end
    end)

    TestRunner:It("reports unexpected Loothing-prefixed globals", function()
        local diagnostics = CreateDiagnostics()
        SetTemporaryGlobal("LoothingUnexpectedGlobal", true)

        local report = diagnostics:RunScan("unit")

        Assert.Contains(report.unexpectedGlobals, "LoothingUnexpectedGlobal")
    end, { category = "unit" })

    TestRunner:It("ignores allowlisted globals", function()
        local diagnostics = CreateDiagnostics()
        SetTemporaryGlobal("SLASH_LOOTHING1", "/loothing")

        local report = diagnostics:RunScan("unit")
        local found = false
        for _, name in ipairs(report.unexpectedGlobals) do
            if name == "SLASH_LOOTHING1" then
                found = true
                break
            end
        end

        Assert.IsFalse(found)
    end, { category = "unit" })

    TestRunner:It("records blocked-action events", function()
        local diagnostics = CreateDiagnostics()

        diagnostics:OnEvent("ADDON_ACTION_BLOCKED", "Loothing", "TestFunc")

        local report = diagnostics:RunScan("unit")
        Assert.Equals(1, report.summary.blockedActionCount)
        Assert.Matches(report.blockedActions[1].message, "ADDON_ACTION_BLOCKED")
    end, { category = "unit" })

    TestRunner:It("clear resets prior findings", function()
        local diagnostics = CreateDiagnostics()
        SetTemporaryGlobal("LoothingUnexpectedGlobal", true)
        diagnostics:RunScan("unit")

        diagnostics:Clear()
        SetTemporaryGlobal("LoothingUnexpectedGlobal", nil)

        local report = diagnostics:RunScan("unit")
        Assert.Equals(0, report.summary.blockedActionCount)
        local found = false
        for _, name in ipairs(report.unexpectedGlobals) do
            if name == "LoothingUnexpectedGlobal" then
                found = true
                break
            end
        end
        Assert.IsFalse(found)
    end, { category = "unit" })

    TestRunner:It("marks tracked globals changed from baseline and reports secure state", function()
        local baselineUnitGUID = function() return "baseline" end
        local changedUnitGUID = function() return "changed" end

        SetTemporaryGlobal("UnitGUID", baselineUnitGUID)
        SetTemporaryGlobal("issecurevariable", function(name)
            if name == "UnitGUID" then
                return false, "Loothing"
            end
            return true, nil
        end)

        local diagnostics = CreateDiagnostics()
        SetTemporaryGlobal("UnitGUID", changedUnitGUID)

        local report = diagnostics:RunScan("unit")
        local status
        for _, entry in ipairs(report.trackedGlobals) do
            if entry.name == "UnitGUID" then
                status = entry
                break
            end
        end

        Assert.TypeOf(status, "table")
        Assert.IsTrue(status.changedFromBaseline)
        Assert.IsFalse(status.secure)
        Assert.Equals("Loothing", status.taintedBy)
    end, { category = "unit" })

    TestRunner:It("reports missing expected globals", function()
        SetTemporaryGlobal("SLASH_LOOTHING1", "/loothing")
        local diagnostics = CreateDiagnostics()
        SetTemporaryGlobal("SLASH_LOOTHING1", nil)

        local report = diagnostics:RunScan("unit")

        Assert.Contains(report.missingExpectedGlobals, "SLASH_LOOTHING1")
    end, { category = "unit" })
end)
