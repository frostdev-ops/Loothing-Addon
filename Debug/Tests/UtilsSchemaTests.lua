--[[--------------------------------------------------------------------
    Loothing - Loot Council Addon for WoW 12.0+
    UtilsSchemaTests - ValidateSchema hardening regressions
----------------------------------------------------------------------]]

local _, ns = ...

local TestRunner = ns.TestRunner
local Assert = ns.Assert
local Utils = ns.Utils

if TestRunner and Assert and Utils then
    TestRunner:Describe("Utils.ValidateSchema", function()
        TestRunner:It("fails closed for nil data", function()
            local ok, reason = Utils.ValidateSchema(nil, {
                { "itemLink", "string", true },
            })

            Assert.IsFalse(ok)
            Assert.Equals("data must be table", reason)
        end, { category = "unit" })

        TestRunner:It("fails closed for nil schema", function()
            local ok, reason = Utils.ValidateSchema({}, nil)

            Assert.IsFalse(ok)
            Assert.Equals("schema must be table", reason)
        end, { category = "unit" })

        TestRunner:It("accepts valid required fields", function()
            local ok, reason = Utils.ValidateSchema({ itemLink = "link" }, {
                { "itemLink", "string", true },
            })

            Assert.IsTrue(ok)
            Assert.IsNil(reason)
        end, { category = "unit" })
    end)
end
