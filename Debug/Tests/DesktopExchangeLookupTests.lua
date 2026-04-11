--[[--------------------------------------------------------------------
    Loothing - Loot Council Addon for WoW 12.0+
    DesktopExchangeLookupTests - Regression tests for desktop-synced item maps

    Verifies that addon readers can resolve desktop sync payloads regardless
    of whether item IDs are stored as numeric Lua keys or string keys.
----------------------------------------------------------------------]]

local _, ns = ...
local Loothing = ns.Addon

local TestRunner = ns.TestRunner
local Assert = ns.Assert

local savedLoothingSettings = Loothing.Settings

local function InstallDesktopExchange(exchange)
    Loothing.Settings = {
        GetGlobalValue = function(_, key)
            if key == "desktopExchange" then
                return exchange
            end
            return nil
        end,
    }
end

local function RestoreDesktopExchange()
    Loothing.Settings = savedLoothingSettings
end

TestRunner:Describe("Desktop Exchange Item Lookup", function()
    TestRunner:AfterEach(function()
        RestoreDesktopExchange()
    end)

    TestRunner:Describe("Droptimizer", function()
        TestRunner:It("reads upgrades from numeric item keys", function()
            InstallDesktopExchange({
                droptimizer = {
                    generatedAt = 1775943225,
                    source = "raidbots.com",
                    version = 1,
                    characters = {
                        ["Felbane-Duskwood"] = {
                            upgrades = {
                                [249343] = {
                                    g = 12450,
                                    p = 5.3,
                                },
                            },
                        },
                    },
                },
            })

            local reader = CreateFromMixins(ns.DroptimizerMixin)
            reader:Init()

            Assert.TableEquals({ g = 12450, p = 5.3 }, reader:GetUpgrade("Felbane-Duskwood", 249343))
            Assert.Equals("+12,450 DPS (+5.3%)", reader:GetUpgradeText("Felbane-Duskwood", 249343))
        end, { category = "unit" })

        TestRunner:It("still reads upgrades from string item keys", function()
            InstallDesktopExchange({
                droptimizer = {
                    generatedAt = 1775943225,
                    source = "raidbots.com",
                    version = 1,
                    characters = {
                        ["Felbane-Duskwood"] = {
                            upgrades = {
                                ["249343"] = {
                                    g = -3887.78,
                                    p = -1.54,
                                },
                            },
                        },
                    },
                },
            })

            local reader = CreateFromMixins(ns.DroptimizerMixin)
            reader:Init()

            Assert.TableEquals({ g = -3887.78, p = -1.54 }, reader:GetUpgrade("Felbane-Duskwood", 249343))
            Assert.Equals("-3,888 DPS (-1.5%)", reader:GetUpgradeText("Felbane-Duskwood", 249343))
        end, { category = "unit" })
    end)

    TestRunner:Describe("Trinket Sims", function()
        TestRunner:It("reads ranks from numeric item keys", function()
            InstallDesktopExchange({
                trinketSims = {
                    generatedAt = 1775943224,
                    fightStyle = "castingpatchwerk",
                    source = "bloodmallet.com",
                    version = 1,
                    trinkets = {
                        [151310] = {
                            priest_shadow = 7,
                        },
                    },
                },
            })

            local reader = CreateFromMixins(ns.TrinketSimsMixin)
            reader:Init()

            Assert.Equals(7, reader:GetRank(151310, "PRIEST", "Shadow"))
            Assert.Truthy(reader:GetRankText(151310, "PRIEST", "Shadow"):find("#7 for", 1, true) ~= nil)
        end, { category = "unit" })

        TestRunner:It("still reads ranks from string item keys", function()
            InstallDesktopExchange({
                trinketSims = {
                    generatedAt = 1775943224,
                    fightStyle = "castingpatchwerk",
                    source = "bloodmallet.com",
                    version = 1,
                    trinkets = {
                        ["151310"] = {
                            priest_shadow = 12,
                        },
                    },
                },
            })

            local reader = CreateFromMixins(ns.TrinketSimsMixin)
            reader:Init()

            Assert.Equals(12, reader:GetRank(151310, "PRIEST", "Shadow"))
            Assert.Truthy(reader:GetRankText(151310, "PRIEST", "Shadow"):find("#12 for", 1, true) ~= nil)
        end, { category = "unit" })
    end)
end)
