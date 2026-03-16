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
local originalGetPlayerFullName
local originalPopups
local originalSession
local originalComm
local originalLoolibComm
local exportMixin

TestRunner:Describe("Settings Export", function()
    TestRunner:BeforeEach(function()
        originalSettings = Loothing.Settings
        originalSettingsExport = Loothing.SettingsExport
        originalGetRaidRoster = ns.Utils.GetRaidRoster
        originalGetPlayerFullName = ns.Utils.GetPlayerFullName
        originalPopups = ns.Popups
        originalSession = Loothing.Session
        originalComm = Loothing.Comm
        originalLoolibComm = Loolib.Comm

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

        ns.Utils.GetPlayerFullName = function()
            return "Local-Realm"
        end
    end)

    TestRunner:AfterEach(function()
        Loothing.Settings = originalSettings
        Loothing.SettingsExport = originalSettingsExport
        ns.Utils.GetRaidRoster = originalGetRaidRoster
        ns.Utils.GetPlayerFullName = originalGetPlayerFullName
        ns.Popups = originalPopups
        Loothing.Session = originalSession
        Loothing.Comm = originalComm
        Loolib.Comm = originalLoolibComm
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

    TestRunner:It("requires an active master looter session for group broadcast", function()
        local broadcastCalls = 0

        Loothing.Comm = {
            BroadcastProfileExport = function(_, exportString, shareID, sessionID)
                broadcastCalls = broadcastCalls + 1
                Assert.NotNil(exportString)
                Assert.NotNil(shareID)
                Assert.Equals("session-1", sessionID)
            end,
        }

        Loolib.Comm = {
            GetQueuePressure = function()
                return 0
            end,
            IsQueueFull = function()
                return false
            end,
        }

        local allowed, reason = exportMixin:CanBroadcastSharedExport()
        Assert.IsFalse(allowed)
        Assert.Equals(ns.Locale["PROFILE_SHARE_BROADCAST_NO_SESSION"], reason)

        Loothing.Session = {
            IsActive = function()
                return true
            end,
            IsMasterLooter = function()
                return false
            end,
        }

        allowed, reason = exportMixin:CanBroadcastSharedExport()
        Assert.IsFalse(allowed)
        Assert.Equals(ns.Locale["PROFILE_SHARE_BROADCAST_NOT_ML"], reason)

        Loothing.Session = {
            IsActive = function()
                return true
            end,
            IsMasterLooter = function()
                return true
            end,
            GetSessionID = function()
                return "session-1"
            end,
        }

        allowed = exportMixin:CanBroadcastSharedExport()
        Assert.IsTrue(allowed)

        local success, err = exportMixin:BroadcastSharedExport()
        Assert.IsTrue(success, err)
        Assert.Equals(1, broadcastCalls)

        success, err = exportMixin:BroadcastSharedExport()
        Assert.IsFalse(success)
        Assert.Matches(err, "Try again in")
        Assert.Equals(1, broadcastCalls)
    end, { category = "unit" })

    TestRunner:It("queues shared import popups and drops duplicate shares", function()
        local encoded = exportMixin:Export()
        local shown = {}

        ns.Popups = {
            Show = function(_, name, data)
                Assert.Equals("LOOTHING_SETTINGS_IMPORT_CONFIRM", name)
                local dialog = {
                    hideCallback = nil,
                    RegisterCallback = function(self, event, callback)
                        if event == "OnHide" then
                            self.hideCallback = callback
                        end
                    end,
                    Hide = function(self)
                        if self.hideCallback then
                            self.hideCallback()
                        end
                    end,
                }
                shown[#shown + 1] = {
                    name = name,
                    data = data,
                    dialog = dialog,
                }
                return dialog
            end,
        }

        exportMixin:HandleSharedExport(encoded, "Friend-Realm", {
            shareID = "share-1",
            scope = "group",
        })
        Assert.Equals(1, #shown)
        Assert.Equals(0, #exportMixin.pendingImportQueue)

        exportMixin:HandleSharedExport(encoded, "Friend-Realm", {
            shareID = "share-1",
            scope = "group",
        })
        Assert.Equals(1, #shown)
        Assert.Equals(0, #exportMixin.pendingImportQueue)

        exportMixin:HandleSharedExport(encoded, "Second-Realm", {
            shareID = "share-2",
            scope = "group",
        })
        Assert.Equals(1, #shown)
        Assert.Equals(1, #exportMixin.pendingImportQueue)

        shown[1].dialog:Hide()
        Assert.Equals(2, #shown)
        Assert.Equals(0, #exportMixin.pendingImportQueue)
    end, { category = "unit" })

    TestRunner:It("only accepts group broadcasts from the active session master looter", function()
        local received
        Loothing.SettingsExport = {
            HandleSharedExport = function(_, exportString, sender, metadata)
                received = {
                    exportString = exportString,
                    sender = sender,
                    metadata = metadata,
                }
            end,
        }

        Loothing.Session = {
            IsActive = function()
                return true
            end,
            IsCurrentSession = function(_, sessionID)
                return sessionID == "session-1"
            end,
            GetMasterLooter = function()
                return "Master-Realm"
            end,
        }

        ns.Utils.GetRaidRoster = function()
            return {
                { name = "Master-Realm", online = true },
                { name = "Friend-Realm", online = true },
            }
        end

        local comm = setmetatable({}, { __index = ns.CommMixin })
        comm:HandleProfileExportShare({
            exportString = "abc",
            scope = "group",
            shareID = "share-1",
            sessionID = "session-1",
        }, "Master-Realm", "RAID")

        Assert.NotNil(received)
        Assert.Equals("Master-Realm", received.sender)
        Assert.Equals("group", received.metadata.scope)
        Assert.Equals("session-1", received.metadata.sessionID)

        received = nil
        comm:HandleProfileExportShare({
            exportString = "abc",
            scope = "group",
            shareID = "share-1",
            sessionID = "session-1",
        }, "Master-Realm", "WHISPER")
        Assert.IsNil(received)

        comm:HandleProfileExportShare({
            exportString = "abc",
            scope = "group",
            shareID = "share-1",
            sessionID = "wrong-session",
        }, "Master-Realm", "RAID")
        Assert.IsNil(received)

        comm:HandleProfileExportShare({
            exportString = "abc",
            scope = "group",
            shareID = "share-1",
            sessionID = "session-1",
        }, "Friend-Realm", "RAID")
        Assert.IsNil(received)
    end, { category = "unit" })
end)
