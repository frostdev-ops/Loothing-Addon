--[[--------------------------------------------------------------------
    Loothing - Loot Council Addon for WoW 12.0+
    SettingsExportTests - Regression coverage for export codec integration
----------------------------------------------------------------------]]

local _, ns = ...

local TestRunner = ns.TestRunner
local Assert = ns.Assert
local Loothing = ns.Addon
local Loolib = LibStub("Loolib")

local originalSettings
local originalSettingsExport
local originalGetRaidRoster
local originalPopups
local exportMixin

TestRunner:Describe("Settings Export", function()
    TestRunner:BeforeEach(function()
        originalSettings = Loothing.Settings
        originalSettingsExport = Loothing.SettingsExport
        originalGetRaidRoster = ns.Utils.GetRaidRoster
        originalPopups = ns.Popups

        exportMixin = setmetatable({}, { __index = ns.SettingsExportMixin })
        exportMixin:Init()

        Loothing.Settings = {
            GetProfileData = function()
                return {
                    settings = {
                        uiScale = 1.2,
                        mainFramePosition = { point = "CENTER" },
                    },
                    frame = {
                        position = { point = "CENTER" },
                    },
                    history = {
                        ignored = true,
                    },
                    voting = {
                        timeout = 30,
                    },
                }
            end,
            GetCurrentProfile = function()
                return "Test Profile"
            end,
            GetProfileDefaults = function()
                return {
                    settings = {
                        uiScale = 1.0,
                        mainFramePosition = nil,
                    },
                    frame = {},
                    voting = {
                        timeout = 30,
                    },
                }
            end,
        }
    end)

    TestRunner:AfterEach(function()
        Loothing.Settings = originalSettings
        Loothing.SettingsExport = originalSettingsExport
        ns.Utils.GetRaidRoster = originalGetRaidRoster
        ns.Popups = originalPopups
    end)

    TestRunner:It("round-trips payloads through Loolib ExportCodec", function()
        local payload = {
            name = "Profile",
            nested = {
                enabled = true,
                list = { 1, 2, 3 },
            },
        }

        local encoded, err = Loolib.ExportCodec:EncodeTable(payload, {
            compression = "deflate",
            level = 6,
        })
        Assert.NotNil(encoded, err or "Expected encoded payload")

        encoded = encoded:sub(1, 16) .. "\n" .. encoded:sub(17)

        local success, decoded = Loolib.ExportCodec:DecodeTable(encoded, {
            compression = "deflate",
            level = 6,
        })
        Assert.IsTrue(success, decoded)
        Assert.Equals("Profile", decoded.name)
        Assert.Equals(3, decoded.nested.list[3])
        Assert.IsTrue(decoded.nested.enabled)
    end, { category = "unit" })

    TestRunner:It("exports and imports settings payloads via the shared codec", function()
        local encoded, err = exportMixin:Export()
        Assert.NotNil(encoded, err or "Expected encoded export")

        local success, payload = exportMixin:Import(encoded)
        Assert.IsTrue(success, payload)
        Assert.Equals(1, payload._exportVersion)
        Assert.Equals("Test Profile", payload._profileName)
        Assert.IsNil(payload.settings.frame.position, "Machine-specific frame position should be removed")
        Assert.IsNil(payload.settings.history, "History should not be included in settings exports")
        Assert.Equals(30, payload.settings.voting.timeout)
    end, { category = "unit" })

    TestRunner:It("routes shared exports through the same import confirmation path", function()
        local encoded = exportMixin:Export()
        local receivedSender
        local receivedPayload

        function exportMixin:PresentImportPayload(payload, _, sender)
            receivedPayload = payload
            receivedSender = sender
        end

        exportMixin:HandleSharedExport(encoded, "Friend-Realm")

        Assert.Equals("Friend-Realm", receivedSender)
        Assert.NotNil(receivedPayload)
        Assert.Equals("Test Profile", receivedPayload._profileName)
    end, { category = "unit" })

    TestRunner:It("only accepts shared exports from group members", function()
        local calledSender
        Loothing.SettingsExport = {
            HandleSharedExport = function(_, _, sender)
                calledSender = sender
            end,
        }

        ns.Utils.GetRaidRoster = function()
            return {
                { name = "Friend-Realm", online = true },
            }
        end

        local comm = setmetatable({}, { __index = ns.CommMixin })
        comm:HandleProfileExportShare({ exportString = "abc" }, "Friend-Realm")
        Assert.Equals("Friend-Realm", calledSender)

        calledSender = nil
        comm:HandleProfileExportShare({ exportString = "abc" }, "Stranger-Realm")
        Assert.IsNil(calledSender)
    end, { category = "unit" })
end)
