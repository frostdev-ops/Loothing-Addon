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

    TestRunner:Describe("Trinket Sims v1 (backward compat)", function()
        TestRunner:It("reads ranks from numeric item keys", function()
            InstallDesktopExchange({
                trinketSims = {
                    generatedAt = 1775943224,
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

        TestRunner:It("GetSimText falls back to rank for v1 data", function()
            InstallDesktopExchange({
                trinketSims = {
                    generatedAt = 1775943224,
                    source = "bloodmallet.com",
                    version = 1,
                    trinkets = {
                        [151310] = {
                            priest_shadow = 5,
                        },
                    },
                },
            })

            local reader = CreateFromMixins(ns.TrinketSimsMixin)
            reader:Init()

            Assert.Equals("#5", reader:GetSimText(151310, "PRIEST", "Shadow"))
        end, { category = "unit" })
    end)

    TestRunner:Describe("Trinket Sims v2 (multi-target + DPS gain)", function()
        TestRunner:It("reads rank and DPS gain from v2 numeric keys", function()
            InstallDesktopExchange({
                trinketSims = {
                    generatedAt = 1775943224,
                    source = "bloodmallet.com",
                    version = 2,
                    trinkets = {
                        [151310] = {
                            priest_shadow = {
                                r = 3, g = 12500,
                                r3 = 7, g3 = 8200,
                                r5 = 12, g5 = 4100,
                            },
                        },
                    },
                },
            })

            local reader = CreateFromMixins(ns.TrinketSimsMixin)
            reader:Init()

            -- Rank queries (1T)
            Assert.Equals(3, reader:GetRank(151310, "PRIEST", "Shadow"))

            -- DPS gain queries per target count
            Assert.Equals(12500, reader:GetDpsGain(151310, "PRIEST", "Shadow", "1T"))
            Assert.Equals(8200, reader:GetDpsGain(151310, "PRIEST", "Shadow", "3T"))
            Assert.Equals(4100, reader:GetDpsGain(151310, "PRIEST", "Shadow", "5T"))

            -- Default target count is 1T
            Assert.Equals(12500, reader:GetDpsGain(151310, "PRIEST", "Shadow"))
        end, { category = "unit" })

        TestRunner:It("reads v2 data from string item keys", function()
            InstallDesktopExchange({
                trinketSims = {
                    generatedAt = 1775943224,
                    source = "bloodmallet.com",
                    version = 2,
                    trinkets = {
                        ["151310"] = {
                            mage_fire = {
                                r = 1, g = 18700,
                                r3 = 2, g3 = 15300,
                                r5 = 5, g5 = 9800,
                            },
                        },
                    },
                },
            })

            local reader = CreateFromMixins(ns.TrinketSimsMixin)
            reader:Init()

            Assert.Equals(1, reader:GetRank(151310, "MAGE", "Fire"))
            Assert.Equals(18700, reader:GetDpsGain(151310, "MAGE", "Fire", "1T"))
            Assert.Equals(15300, reader:GetDpsGain(151310, "MAGE", "Fire", "3T"))
        end, { category = "unit" })

        TestRunner:It("GetSimText formats DPS gains across all targets", function()
            InstallDesktopExchange({
                trinketSims = {
                    generatedAt = 1775943224,
                    source = "bloodmallet.com",
                    version = 2,
                    trinkets = {
                        [151310] = {
                            priest_shadow = {
                                r = 3, g = 12500,
                                r3 = 7, g3 = 8200,
                                r5 = 12, g5 = 4100,
                            },
                        },
                    },
                },
            })

            local reader = CreateFromMixins(ns.TrinketSimsMixin)
            reader:Init()

            local simText = reader:GetSimText(151310, "PRIEST", "Shadow")
            -- Should contain all three target counts with rank + DPS gains
            -- Labels are color-escaped so check for the key content
            Assert.Truthy(simText:find("1T", 1, true) ~= nil)
            Assert.Truthy(simText:find("#3 +12.5k", 1, true) ~= nil)
            Assert.Truthy(simText:find("3T", 1, true) ~= nil)
            Assert.Truthy(simText:find("#7 +8.2k", 1, true) ~= nil)
            Assert.Truthy(simText:find("5T", 1, true) ~= nil)
            Assert.Truthy(simText:find("#12 +4.1k", 1, true) ~= nil)
            -- Dividers present
            Assert.Truthy(simText:find("|||r", 1, true) ~= nil)
        end, { category = "unit" })

        TestRunner:It("GetSimText handles partial fight style data", function()
            InstallDesktopExchange({
                trinketSims = {
                    generatedAt = 1775943224,
                    source = "bloodmallet.com",
                    version = 2,
                    trinkets = {
                        [151310] = {
                            priest_shadow = {
                                r = 3, g = 12500,
                                -- No 3T or 5T data (e.g. healer spec)
                            },
                        },
                    },
                },
            })

            local reader = CreateFromMixins(ns.TrinketSimsMixin)
            reader:Init()

            local simText = reader:GetSimText(151310, "PRIEST", "Shadow")
            Assert.Truthy(simText:find("1T", 1, true) ~= nil)
            Assert.Truthy(simText:find("#3 +12.5k", 1, true) ~= nil)
            -- Should NOT contain 3T or 5T
            Assert.Falsy(simText:find("3T", 1, true))
            Assert.Falsy(simText:find("5T", 1, true))
            -- No dividers when there's only one section
            Assert.Falsy(simText:find("|||r", 1, true))
        end, { category = "unit" })

        TestRunner:It("returns nil for unknown spec", function()
            InstallDesktopExchange({
                trinketSims = {
                    generatedAt = 1775943224,
                    source = "bloodmallet.com",
                    version = 2,
                    trinkets = {
                        [151310] = {
                            priest_shadow = { r = 3, g = 12500 },
                        },
                    },
                },
            })

            local reader = CreateFromMixins(ns.TrinketSimsMixin)
            reader:Init()

            Assert.IsNil(reader:GetRank(151310, "MAGE", "Fire"))
            Assert.IsNil(reader:GetDpsGain(151310, "MAGE", "Fire"))
            Assert.IsNil(reader:GetSimText(151310, "MAGE", "Fire"))
        end, { category = "unit" })
    end)
end)
