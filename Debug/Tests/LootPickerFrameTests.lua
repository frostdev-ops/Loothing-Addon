--[[--------------------------------------------------------------------
    Loothing - Loot Council Addon for WoW 12.0+
    LootPickerFrameTests - Picker row rebuild regressions
----------------------------------------------------------------------]]

local _, ns = ...

local TestRunner = ns.TestRunner
local Assert = ns.Assert
local Loothing = ns.Addon

if TestRunner and Assert then
    TestRunner:Describe("LootPickerFrame regressions", function()
        local originalFilter
        local originalSession
        local originalPicker
        local originalWarn
        local originalHandleLoot
        local originalIsMasterLooter
        local originalSettings
        local originalComm
        local originalCContainer
        local originalNumBagSlots
        local originalTooltipScan
        local originalCItem
        local originalTradeQueue
        local originalIsInGroup

        TestRunner:BeforeEach(function()
            originalFilter = Loothing.ItemFilter
            originalSession = Loothing.Session
            originalPicker = ns.LootPickerFrame
            originalWarn = Loothing.Warn
            originalHandleLoot = Loothing.handleLoot
            originalIsMasterLooter = Loothing.isMasterLooter
            originalSettings = Loothing.Settings
            originalComm = Loothing.Comm
            originalCContainer = C_Container
            originalNumBagSlots = NUM_BAG_SLOTS
            originalTooltipScan = ns.TooltipScan
            originalCItem = C_Item
            originalTradeQueue = Loothing.TradeQueue
            originalIsInGroup = IsInGroup
        end)

        TestRunner:AfterEach(function()
            Loothing.ItemFilter = originalFilter
            Loothing.Session = originalSession
            ns.LootPickerFrame = originalPicker
            Loothing.Warn = originalWarn
            Loothing.handleLoot = originalHandleLoot
            Loothing.isMasterLooter = originalIsMasterLooter
            Loothing.Settings = originalSettings
            Loothing.Comm = originalComm
            C_Container = originalCContainer
            NUM_BAG_SLOTS = originalNumBagSlots
            ns.TooltipScan = originalTooltipScan
            C_Item = originalCItem
            Loothing.TradeQueue = originalTradeQueue
            IsInGroup = originalIsInGroup
        end)

        local function CreatePicker(encounterID)
            return setmetatable({
                encounterID = encounterID,
                entries = {},
            }, { __index = ns.LootPickerFrameMixin })
        end

        TestRunner:It("preserves duplicate row check states one-for-one", function()
            Loothing.ItemFilter = {
                EvaluateItem = function()
                    return { allowed = true }
                end,
            }

            local link = "|cffa335ee|Hitem:222222::::::::80:::::|h[Test Blade]|h|r"
            local picker = CreatePicker(101)
            picker.entries = {
                { itemLink = link, playerName = "Raider-Realm", encounterID = 101, checked = true, eval = { allowed = true } },
                { itemLink = link, playerName = "Raider-Realm", encounterID = 101, checked = false, eval = { allowed = true } },
            }

            picker:RebuildEntries({
                { itemLink = link, playerName = "Raider-Realm", encounterID = 101 },
                { itemLink = link, playerName = "Raider-Realm", encounterID = 101 },
            })

            Assert.Equals(2, #picker.entries)
            Assert.IsTrue(picker.entries[1].checked)
            Assert.IsFalse(picker.entries[2].checked)
        end, { category = "unit" })

        TestRunner:It("keeps a preserved picker scoped to its encounter", function()
            Loothing.ItemFilter = {
                EvaluateItem = function()
                    return { allowed = true }
                end,
            }

            local oldLink = "|cffa335ee|Hitem:111111::::::::80:::::|h[Old Boss Item]|h|r"
            local newLink = "|cffa335ee|Hitem:333333::::::::80:::::|h[New Boss Item]|h|r"
            local picker = CreatePicker(101)

            picker:RebuildEntries({
                { itemLink = oldLink, playerName = "Raider-Realm", encounterID = 101 },
                { itemLink = newLink, playerName = "Raider-Realm", encounterID = 202 },
            })

            Assert.Equals(1, #picker.entries)
            Assert.Equals(oldLink, picker.entries[1].itemLink)
        end, { category = "unit" })

        TestRunner:It("shows encounterless roll-won rows in an encounter picker", function()
            Loothing.ItemFilter = {
                EvaluateItem = function()
                    return { allowed = true }
                end,
            }

            local link = "|cffa335ee|Hitem:555555::::::::80:::::|h[Unscoped Roll Loot]|h|r"
            local picker = CreatePicker(101)

            picker:RebuildEntries({
                { itemLink = link, playerName = "Raider-Realm", encounterID = 0, source = "roll_won" },
            })

            Assert.Equals(1, #picker.entries)
            Assert.Equals(link, picker.entries[1].itemLink)
        end, { category = "unit" })

        TestRunner:It("does not re-evaluate cached filter results on refresh", function()
            local evalCount = 0
            Loothing.ItemFilter = {
                EvaluateItem = function()
                    evalCount = evalCount + 1
                    return { allowed = evalCount == 1 }
                end,
            }

            local link = "|cffa335ee|Hitem:444444::::::::80:::::|h[Cold Cache Item]|h|r"
            local picker = CreatePicker(101)
            local buffer = {
                { itemLink = link, playerName = "Raider-Realm", encounterID = 101 },
            }

            picker:RebuildEntries(buffer)
            picker:RebuildEntries(buffer)

            Assert.Equals(1, evalCount)
            Assert.IsTrue(picker.entries[1].eval.allowed)
        end, { category = "unit" })

        TestRunner:It("shows all-hidden copy even while scan is active", function()
            local text
            local picker = CreatePicker(101)
            picker.entries = {
                { eval = { allowed = false } },
                { eval = { allowed = false } },
            }
            picker.emptyText = {
                SetText = function(_, value)
                    text = value
                end,
            }
            Loothing.Session = {
                bagScanTimer = {},
                bagScanStartedAt = 100,
            }

            picker:UpdateEmptyStateText()

            Assert.Equals("2 items hidden - toggle Show blocked to review.", text)
        end, { category = "unit" })

        TestRunner:It("preserves buffer when encounter-start auto-commit fails", function()
            local warnCount = 0
            Loothing.Warn = function()
                warnCount = warnCount + 1
            end
            ns.LootPickerFrame = {
                IsShown = function() return true end,
                HasCheckedSelections = function() return true end,
                AutoCommitForEncounterStart = function() return false end,
            }

            local session = setmetatable({
                lootBuffer = {
                    { itemLink = "old", playerName = "Raider-Realm", encounterID = 101 },
                },
                reportedTradeableItems = {},
                changed = false,
                stopped = false,
                snapshotted = false,
                receivedLootCount = 7,
                TriggerEvent = function(self)
                    self.changed = true
                end,
                StopPostEncounterBagScan = function(self)
                    self.stopped = true
                end,
                SnapshotBags = function(self)
                    self.snapshotted = true
                end,
            }, { __index = ns.SessionMixin })

            session:OnEncounterStart(202, "Next Boss")

            Assert.Equals(1, #session.lootBuffer)
            Assert.Equals("old", session.lootBuffer[1].itemLink)
            Assert.IsFalse(session.changed)
            Assert.IsFalse(session.stopped)
            Assert.IsTrue(session.snapshotted)
            Assert.Equals(7, session.receivedLootCount)
            Assert.Equals(1, warnCount)
        end, { category = "unit" })

        TestRunner:It("does not wipe preserved buffer after successful encounter-start auto-commit", function()
            ns.LootPickerFrame = {
                IsShown = function() return true end,
                HasCheckedSelections = function() return true end,
                AutoCommitForEncounterStart = function() return true end,
            }

            local session = setmetatable({
                lootBuffer = {
                    { itemLink = "future", playerName = "Raider-Realm", encounterID = 202 },
                },
                reportedTradeableItems = {},
                changed = false,
                TriggerEvent = function(self)
                    self.changed = true
                end,
                StopPostEncounterBagScan = function() end,
                SnapshotBags = function() end,
            }, { __index = ns.SessionMixin })

            session:OnEncounterStart(303, "Next Boss")

            Assert.Equals(1, #session.lootBuffer)
            Assert.Equals("future", session.lootBuffer[1].itemLink)
            Assert.IsFalse(session.changed)
        end, { category = "unit" })

        TestRunner:It("defers active-session loot from a different encounter", function()
            Loothing.handleLoot = true
            Loothing.isMasterLooter = true

            local session = setmetatable({
                state = Loothing.SessionState.ACTIVE,
                encounterID = 101,
                encounterName = "Old Boss",
                lastEncounterID = 202,
                lastEncounterName = "New Boss",
                lootBuffer = {},
                IsMasterLooter = function() return true end,
                TriggerEvent = function() end,
            }, { __index = ns.SessionMixin })

            session:HandleTradable({
                itemLink = "|cffa335ee|Hitem:555555::::::::80:::::|h[New Boss Loot]|h|r",
                playerName = "Raider-Realm",
                encounterID = 202,
                encounterName = "New Boss",
            })

            Assert.Equals(1, #session.lootBuffer)
            Assert.Equals(202, session.lootBuffer[1].encounterID)
            Assert.Equals("New Boss", session.lootBuffer[1].encounterName)
        end, { category = "unit" })

        TestRunner:It("keeps duplicate roll-win creation events as separate rows", function()
            local link = "|cffa335ee|Hitem:555555::::::::80:::::|h[Duplicated Loot]|h|r"
            local session = setmetatable({
                lootBuffer = {},
                lastEncounterID = 101,
                lastEncounterName = "Boss",
                TriggerEvent = function() end,
            }, { __index = ns.SessionMixin })

            session:BufferDeferredLoot({
                itemLink = link,
                playerName = "Raider-Realm",
                source = "roll_won",
            }, 101, "Boss")
            session:BufferDeferredLoot({
                itemLink = link,
                playerName = "Raider-Realm",
                source = "roll_won",
            }, 101, "Boss")

            Assert.Equals(2, #session.lootBuffer)
        end, { category = "unit" })

        TestRunner:It("does not assign roll-win loot to stale prior encounter context", function()
            Loothing.handleLoot = true
            local session = setmetatable({
                lootBuffer = {},
                lastEncounterID = 101,
                lastEncounterName = "Prior Boss",
                TriggerEvent = function() end,
            }, { __index = ns.SessionMixin })

            session:HandleTradable({
                itemLink = "|cffa335ee|Hitem:555555::::::::80:::::|h[Unscoped Roll Loot]|h|r",
                itemID = 555555,
                playerName = "Raider-Realm",
                source = "roll_won",
            })

            Assert.Equals(1, #session.lootBuffer)
            Assert.Equals(0, session.lootBuffer[1].encounterID)
            Assert.Equals("Loot", session.lootBuffer[1].encounterName)
        end, { category = "unit" })

        TestRunner:It("refreshes roll-won buffered loot from bag scan without adding a duplicate", function()
            Loothing.handleLoot = true
            local rollLink = "|cffa335ee|Hitem:555555::::::::80:::::|h[Duplicated Loot]|h|r"
            local bagLink = "|cffa335ee|Hitem:555555::::::::80::6:1:9999:|h[Duplicated Loot]|h|r"
            local session = setmetatable({
                lootBuffer = {
                    {
                        itemLink = rollLink,
                        itemID = 555555,
                        playerName = "Raider-Realm",
                        encounterID = 0,
                        source = "roll_won",
                    },
                },
                lastEncounterID = 101,
                lastEncounterName = "Prior Boss",
                TriggerEvent = function() end,
            }, { __index = ns.SessionMixin })

            session:HandleTradable({
                itemLink = bagLink,
                itemID = 555555,
                playerName = "Raider-Realm",
                encounterID = 101,
                timeRemaining = 7200,
                source = "bag_scan",
            })

            Assert.Equals(1, #session.lootBuffer)
            Assert.Equals(7200, session.lootBuffer[1].tradeTimeRemaining)
            Assert.Equals(0, session.lootBuffer[1].encounterID)
        end, { category = "unit" })

        TestRunner:It("refreshes active-session roll-won buffer before bag scan can add a duplicate", function()
            Loothing.handleLoot = true
            Loothing.isMasterLooter = true
            local addCount = 0
            local session = setmetatable({
                state = Loothing.SessionState.ACTIVE,
                encounterID = 101,
                lootBuffer = {
                    {
                        itemLink = "|cffa335ee|Hitem:555555::::::::80:::::|h[Duplicated Loot]|h|r",
                        itemID = 555555,
                        playerName = "Raider-Realm",
                        encounterID = 0,
                        source = "roll_won",
                    },
                },
                items = {
                    Enumerate = function()
                        return function() return nil end
                    end,
                },
                IsMasterLooter = function() return true end,
                AddItem = function()
                    addCount = addCount + 1
                    return { guid = "new-guid" }
                end,
                TriggerEvent = function() end,
            }, { __index = ns.SessionMixin })

            session:HandleTradable({
                itemLink = "|cffa335ee|Hitem:555555::::::::80::6:1:9999:|h[Duplicated Loot]|h|r",
                itemID = 555555,
                playerName = "Raider-Realm",
                encounterID = 101,
                timeRemaining = 3600,
                source = "bag_scan",
            })

            Assert.Equals(0, addCount)
            Assert.Equals(1, #session.lootBuffer)
            Assert.Equals(3600, session.lootBuffer[1].tradeTimeRemaining)
        end, { category = "unit" })

        TestRunner:It("does not treat roll-win creation as an active-session tradability update", function()
            Loothing.handleLoot = true
            Loothing.isMasterLooter = true
            Loothing.Comm = nil

            local addCount = 0
            local updateCount = 0
            local existing = {
                itemID = 555555,
                looter = "Raider-Realm",
            }
            local session = setmetatable({
                state = Loothing.SessionState.ACTIVE,
                encounterID = 101,
                items = {
                    Enumerate = function()
                        local yielded = false
                        return function()
                            if yielded then return nil end
                            yielded = true
                            return existing
                        end
                    end,
                },
                IsMasterLooter = function() return true end,
                AddItem = function()
                    addCount = addCount + 1
                    return { guid = "new-guid" }
                end,
                TriggerEvent = function(_, event)
                    if event == "OnItemTradabilityChanged" then
                        updateCount = updateCount + 1
                    end
                end,
            }, { __index = ns.SessionMixin })

            session:HandleTradable({
                itemLink = "|cffa335ee|Hitem:555555::::::::80:::::|h[Duplicated Loot]|h|r",
                itemID = 555555,
                playerName = "Raider-Realm",
                encounterID = 101,
                source = "roll_won",
            })

            Assert.Equals(1, addCount)
            Assert.Equals(0, updateCount)
        end, { category = "unit" })

        TestRunner:It("keeps hide cleanup suppressed until asynchronous OnHide fires", function()
            local started = false
            local disabled = false
            local picker = CreatePicker(101)
            picker.entries = {
                { itemLink = "picked", playerName = "Raider-Realm", checked = true },
            }
            picker.startBtn = {
                Disable = function()
                    disabled = true
                end,
            }
            picker.Hide = function(self)
                started = self._suppressOnHideCleanup == true
            end
            picker.IsShown = function() return true end
            Loothing.Session = {
                StartSessionWithPickedItems = function()
                    return true
                end,
            }

            local ok = picker:OnStart()

            Assert.IsTrue(ok)
            Assert.IsTrue(started)
            Assert.IsTrue(disabled)
            Assert.IsTrue(picker._suppressOnHideCleanup)
            Assert.IsTrue(picker._starting)
        end, { category = "unit" })

        TestRunner:It("does not start twice while the picker fade-out hide is pending", function()
            local startCount = 0
            local disabledCount = 0
            local picker = CreatePicker(101)
            picker.entries = {
                { itemLink = "picked", playerName = "Raider-Realm", checked = true },
            }
            picker.startBtn = {
                Disable = function()
                    disabledCount = disabledCount + 1
                end,
            }
            picker.Hide = function() end
            picker.IsShown = function() return true end
            Loothing.Session = {
                StartSessionWithPickedItems = function()
                    startCount = startCount + 1
                    return true
                end,
            }

            local first = picker:OnStart()
            local second = picker:OnStart()

            Assert.IsTrue(first)
            Assert.IsFalse(second)
            Assert.Equals(1, startCount)
            Assert.Equals(1, disabledCount)
            Assert.IsTrue(picker._starting)
        end, { category = "unit" })

        TestRunner:It("does not let delayed Show unlock a picker start in progress", function()
            local mouseEnabled = false
            local picker = CreatePicker(101)
            picker._built = true
            picker._starting = true
            picker.frame = {
                IsShown = function() return true end,
                EnableMouse = function()
                    mouseEnabled = true
                end,
            }
            picker.RegisterSessionCallback = function() end

            picker:Show(101, "Old Boss", {})

            Assert.IsTrue(picker._starting)
            Assert.IsFalse(mouseEnabled)
        end, { category = "unit" })

        TestRunner:It("clears consumed picker prompt state after a successful session start", function()
            local canceled = false
            local session = setmetatable({
                pendingLootTimer = {
                    Cancel = function()
                        canceled = true
                    end,
                },
                pendingBufferedPrompt = { id = 101, name = "Old Boss" },
                receivedLootCount = 3,
            }, { __index = ns.SessionMixin })

            session:OnLootPickerSessionStarted()

            Assert.IsTrue(canceled)
            Assert.Equals(nil, session.pendingLootTimer)
            Assert.Equals(nil, session.pendingBufferedPrompt)
            Assert.Equals(0, session.receivedLootCount)
        end, { category = "unit" })

        TestRunner:It("counts pre-pull trade-window items as pre-encounter inventory", function()
            NUM_BAG_SLOTS = 0
            C_Container = {
                GetContainerNumSlots = function() return 3 end,
                GetContainerItemID = function(_, slot)
                    if slot == 1 or slot == 2 then return 111 end
                    if slot == 3 then return 222 end
                    return nil
                end,
            }
            ns.TooltipScan = {
                GetContainerItemTradeTimeRemaining = function(_, _, slot)
                    if slot == 2 then return 3600 end
                    return 0
                end,
            }

            local session = setmetatable({
                preEncounterBagSnapshot = {},
            }, { __index = ns.SessionMixin })

            session:SnapshotBags()

            Assert.Equals(2, session.preEncounterBagSnapshot[111])
            Assert.Equals(1, session.preEncounterBagSnapshot[222])
        end, { category = "unit" })

        TestRunner:It("does count tracked session trade-window items as pre-encounter inventory", function()
            NUM_BAG_SLOTS = 0
            C_Container = {
                GetContainerNumSlots = function() return 2 end,
                GetContainerItemID = function(_, slot)
                    if slot == 1 or slot == 2 then return 111 end
                    return nil
                end,
            }
            ns.TooltipScan = {
                GetContainerItemTradeTimeRemaining = function(_, _, slot)
                    if slot == 2 then return 3600 end
                    return 0
                end,
            }

            local session = setmetatable({
                preEncounterBagSnapshot = {},
                lootBuffer = {},
                items = {
                    Enumerate = function()
                        local done = false
                        return function()
                            if done then return nil end
                            done = true
                            return { itemID = 111, isTradable = true }
                        end
                    end,
                },
            }, { __index = ns.SessionMixin })

            session:SnapshotBags()

            Assert.Equals(2, session.preEncounterBagSnapshot[111])
        end, { category = "unit" })

        TestRunner:It("adds active roll-won loot without an encounter id to the active session", function()
            local addCount = 0
            local deferred = false
            Loothing.handleLoot = true
            Loothing.isMasterLooter = true
            Loothing.Settings = {
                GetSessionTriggerAction = function() return "prompt" end,
            }
            Loothing.Comm = nil

            local session = setmetatable({
                state = Loothing.SessionState.ACTIVE,
                encounterID = 101,
                sessionID = "session",
                items = {
                    Enumerate = function()
                        return function() return nil end
                    end,
                },
                IsMasterLooter = function() return true end,
                AddItem = function()
                    addCount = addCount + 1
                    return { guid = "roll-guid" }
                end,
                BufferDeferredLoot = function()
                    deferred = true
                    return true
                end,
            }, { __index = ns.SessionMixin })

            session:HandleTradable({
                itemLink = "|cffa335ee|Hitem:777777::::::::80:::::|h[Roll Won Loot]|h|r",
                itemID = 777777,
                playerName = "Raider-Realm",
                source = "roll_won",
            })

            Assert.Equals(1, addCount)
            Assert.IsFalse(deferred)
        end, { category = "unit" })

        TestRunner:It("does not let bag-scan duplicate copies get swallowed by roll-won refresh", function()
            local addCount = 0
            local forceArg
            Loothing.handleLoot = true
            Loothing.isMasterLooter = true
            Loothing.Settings = {
                GetSessionTriggerAction = function() return "prompt" end,
            }

            local session = setmetatable({
                state = Loothing.SessionState.ACTIVE,
                encounterID = 101,
                sessionID = "session",
                lootBuffer = {
                    {
                        itemLink = "|cffa335ee|Hitem:111::::::::80:::::|h[Same Loot]|h|r",
                        itemID = 111,
                        playerName = "Raider-Realm",
                        source = "roll_won",
                    },
                },
                items = {
                    Enumerate = function()
                        return function() return nil end
                    end,
                },
                IsMasterLooter = function() return true end,
                AddItem = function(_, _, _, _, force)
                    addCount = addCount + 1
                    forceArg = force
                    return { guid = "second-copy" }
                end,
                TriggerEvent = function() end,
            }, { __index = ns.SessionMixin })

            session:HandleTradable({
                itemLink = "|cffa335ee|Hitem:111::::::::80:::::|h[Same Loot]|h|r",
                itemID = 111,
                playerName = "Raider-Realm",
                source = "bag_scan",
                timeRemaining = 3500,
            })

            Assert.Equals(0, addCount)
            Assert.Equals(3500, session.lootBuffer[1].tradeTimeRemaining)

            session:HandleTradable({
                itemLink = "|cffa335ee|Hitem:111::::::::80:::::|h[Same Loot]|h|r",
                itemID = 111,
                playerName = "Raider-Realm",
                source = "bag_scan",
                timeRemaining = 3600,
                forceCreate = true,
            })

            Assert.Equals(1, addCount)
            Assert.IsTrue(forceArg)
        end, { category = "unit" })

        TestRunner:It("includes encounter metadata on non-ML bag-scan reports", function()
            local sent = {}
            IsInGroup = function() return true end
            NUM_BAG_SLOTS = 0
            C_Container = {
                GetContainerNumSlots = function() return 2 end,
                GetContainerItemID = function(_, slot)
                    return slot <= 2 and 111 or nil
                end,
                GetContainerItemLink = function(_, slot)
                    return "|cffa335ee|Hitem:111::::::::80:::::|h[Same Loot " .. slot .. "]|h|r"
                end,
            }
            Loothing.TradeQueue = {
                GetContainerItemTradeTimeRemaining = function(_, _, slot)
                    return slot == 1 and 3500 or 3600
                end,
            }
            Loothing.Settings = {
                GetSessionTriggerAction = function() return "prompt" end,
            }
            Loothing.Comm = {
                Send = function(_, command, data)
                    sent[#sent + 1] = { command = command, data = data }
                end,
            }

            local session = setmetatable({
                preEncounterBagSnapshot = {},
                bagScanSnapshot = {},
                reportedTradeableItems = {},
                bagScanEncounterID = 202,
                bagScanEncounterName = "Boss Two",
                IsMasterLooter = function() return false end,
            }, { __index = ns.SessionMixin })

            session:ScanBagsForTradeableItems()

            Assert.Equals(2, #sent)
            Assert.Equals(Loothing.MsgType.TRADABLE, sent[1].command)
            Assert.Equals(202, sent[1].data.encounterID)
            Assert.Equals("Boss Two", sent[1].data.encounterName)
            Assert.Equals("bag_scan", sent[1].data.source)
            Assert.IsFalse(sent[1].data.forceCreate)
            Assert.IsTrue(sent[2].data.forceCreate)
        end, { category = "unit" })

        TestRunner:It("does not mix encounter-scoped rows into an encounterless picker", function()
            Loothing.ItemFilter = {
                EvaluateItem = function()
                    return { allowed = true }
                end,
            }

            local picker = CreatePicker(0)
            picker:RebuildEntries({
                { itemLink = "generic", playerName = "Raider-Realm" },
                { itemLink = "future", playerName = "Raider-Realm", encounterID = 202 },
            })

            Assert.Equals(1, #picker.entries)
            Assert.Equals("generic", picker.entries[1].itemLink)
        end, { category = "unit" })

        TestRunner:It("clears only matching encounter rows from mixed buffer", function()
            local session = setmetatable({
                lootBuffer = {
                    { itemLink = "old", encounterID = 101 },
                    { itemLink = "unknown" },
                    { itemLink = "new", encounterID = 202 },
                },
                TriggerEvent = function() end,
            }, { __index = ns.SessionMixin })

            local removed = session:ClearLootBufferForEncounter(101)

            Assert.Equals(1, removed)
            Assert.Equals(2, #session.lootBuffer)
            Assert.Equals("unknown", session.lootBuffer[1].itemLink)
            Assert.Equals("new", session.lootBuffer[2].itemLink)
        end, { category = "unit" })

        TestRunner:It("clears encounterless rows without wiping future encounters", function()
            local session = setmetatable({
                lootBuffer = {
                    { itemLink = "manual" },
                    { itemLink = "manual-zero", encounterID = 0 },
                    { itemLink = "future", encounterID = 202 },
                },
                TriggerEvent = function() end,
            }, { __index = ns.SessionMixin })

            local removed = session:ClearLootBufferForEncounter(nil)

            Assert.Equals(2, removed)
            Assert.Equals(1, #session.lootBuffer)
            Assert.Equals("future", session.lootBuffer[1].itemLink)
        end, { category = "unit" })

        TestRunner:It("finds encounterless buffered loot after ending an encounter session", function()
            local session = setmetatable({
                lootBuffer = {
                    { itemLink = "boss", encounterID = 101 },
                    { itemLink = "manual" },
                },
            }, { __index = ns.SessionMixin })

            local encounter = session:FindBufferedEncounter(101)

            Assert.Equals(0, encounter.id)
            Assert.Equals("Loot", encounter.name)
        end, { category = "unit" })

        TestRunner:It("defers OnLootReceived from a different active encounter", function()
            Loothing.handleLoot = true
            Loothing.isMasterLooter = true
            Loothing.Settings = {
                GetSessionTriggerTiming = function() return "encounterEnd" end,
                GetSessionTriggerAction = function() return "prompt" end,
            }

            local session = setmetatable({
                state = Loothing.SessionState.ACTIVE,
                encounterID = 101,
                encounterName = "Old Boss",
                lastEncounterID = 202,
                lastEncounterName = "New Boss",
                lootBuffer = {},
                IsMasterLooter = function() return true end,
                TriggerEvent = function() end,
            }, { __index = ns.SessionMixin })

            session:OnLootReceived(202, nil, "|cffa335ee|Hitem:666666::::::::80:::::|h[New Event Loot]|h|r", 1, "Raider-Realm")

            Assert.Equals(1, #session.lootBuffer)
            Assert.Equals(202, session.lootBuffer[1].encounterID)
        end, { category = "unit" })

        TestRunner:It("queues buffered prompt until picker hide completes", function()
            Loothing.handleLoot = true
            local appliedID
            ns.LootPickerFrame = {
                IsShown = function() return true end,
            }

            local session = setmetatable({
                state = Loothing.SessionState.INACTIVE,
                lootBuffer = {
                    { itemLink = "new", encounterID = 202, encounterName = "New Boss" },
                },
                ApplyTriggerAction = function(_, encounterID)
                    appliedID = encounterID
                end,
            }, { __index = ns.SessionMixin })

            session:PromptForBufferedLoot({ id = 202, name = "New Boss" })
            Assert.Equals(nil, appliedID)
            Assert.Equals(202, session.pendingBufferedPrompt.id)

            ns.LootPickerFrame = {
                IsShown = function() return false end,
            }
            session:PromptForBufferedLoot(session.pendingBufferedPrompt)

            Assert.Equals(202, appliedID)
        end, { category = "unit" })
    end)
end
