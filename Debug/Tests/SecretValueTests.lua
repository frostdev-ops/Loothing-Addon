--[[--------------------------------------------------------------------
    Loothing - Loot Council Addon for WoW 12.0+
    SecretValueTests - Tests for Loolib.SecretUtil and Utils delegates

    Verifies that Loolib.SecretUtil core functions and the Utils
    backward-compatible delegates correctly handle WoW 12.0 secret values.
----------------------------------------------------------------------]]

local _, ns = ...
local Loolib = LibStub("Loolib")
local Loothing = ns.Addon
local Utils = ns.Utils

local TestRunner = TestRunner
local Assert = Assert

--[[--------------------------------------------------------------------
    Mock Setup
----------------------------------------------------------------------]]

-- Create a sentinel object that simulates a WoW secret value
local SECRET_SENTINEL = setmetatable({}, {
    __tostring = function() return "<secret>" end,
})

-- Save/restore the global issecretvalue
local savedIssecretvalue = issecretvalue

--- Install a mock issecretvalue that recognizes our sentinel
local function InstallMock()
    issecretvalue = function(v)
        return v == SECRET_SENTINEL
    end
end

--- Remove the mock
local function RemoveMock()
    issecretvalue = savedIssecretvalue
end

--[[--------------------------------------------------------------------
    Tests - Loolib.SecretUtil (library level)
----------------------------------------------------------------------]]

TestRunner:Describe("Loolib.SecretUtil", function()

    TestRunner:AfterEach(function()
        RemoveMock()
    end)

    ------------------------------------------------------------------
    -- IsAvailable
    ------------------------------------------------------------------

    TestRunner:Describe("IsAvailable", function()

        TestRunner:It("returns false when issecretvalue is nil", function()
            issecretvalue = nil
            Assert.IsFalse(Loolib.SecretUtil.IsAvailable())
        end, { category = "unit" })

        TestRunner:It("returns true when issecretvalue exists", function()
            InstallMock()
            Assert.IsTrue(Loolib.SecretUtil.IsAvailable())
        end, { category = "unit" })
    end)

    ------------------------------------------------------------------
    -- IsSecretValue
    ------------------------------------------------------------------

    TestRunner:Describe("IsSecretValue", function()

        TestRunner:It("returns false when issecretvalue is not available", function()
            issecretvalue = nil
            Assert.IsFalse(Loolib.SecretUtil.IsSecretValue("hello"))
            Assert.IsFalse(Loolib.SecretUtil.IsSecretValue(42))
            Assert.IsFalse(Loolib.SecretUtil.IsSecretValue(nil))
        end, { category = "unit" })

        TestRunner:It("returns false for normal values", function()
            InstallMock()
            Assert.IsFalse(Loolib.SecretUtil.IsSecretValue("PlayerName"))
            Assert.IsFalse(Loolib.SecretUtil.IsSecretValue(123))
            Assert.IsFalse(Loolib.SecretUtil.IsSecretValue(nil))
            Assert.IsFalse(Loolib.SecretUtil.IsSecretValue(true))
        end, { category = "unit" })

        TestRunner:It("returns true for secret values", function()
            InstallMock()
            Assert.IsTrue(Loolib.SecretUtil.IsSecretValue(SECRET_SENTINEL))
        end, { category = "unit" })

        TestRunner:It("returns true if any argument is secret (varargs)", function()
            InstallMock()
            Assert.IsTrue(Loolib.SecretUtil.IsSecretValue("normal", SECRET_SENTINEL))
            Assert.IsTrue(Loolib.SecretUtil.IsSecretValue(SECRET_SENTINEL, "normal"))
            Assert.IsFalse(Loolib.SecretUtil.IsSecretValue("a", "b", "c"))
        end, { category = "unit" })

        TestRunner:It("handles zero arguments", function()
            InstallMock()
            Assert.IsFalse(Loolib.SecretUtil.IsSecretValue())
        end, { category = "unit" })
    end)

    ------------------------------------------------------------------
    -- SecretsForPrint
    ------------------------------------------------------------------

    TestRunner:Describe("SecretsForPrint", function()

        TestRunner:It("passes through normal values when issecretvalue unavailable", function()
            issecretvalue = nil
            local a, b = Loolib.SecretUtil.SecretsForPrint("hello", 42)
            Assert.Equals("hello", a)
            Assert.Equals(42, b)
        end, { category = "unit" })

        TestRunner:It("replaces secret values with <secret>", function()
            InstallMock()
            local a, b, c = Loolib.SecretUtil.SecretsForPrint("normal", SECRET_SENTINEL, 123)
            Assert.Equals("normal", a)
            Assert.Equals("<secret>", b)
            Assert.Equals("123", c)
        end, { category = "unit" })

        TestRunner:It("handles zero arguments", function()
            InstallMock()
            local result = { Loolib.SecretUtil.SecretsForPrint() }
            Assert.Equals(0, #result)
        end, { category = "unit" })
    end)

    ------------------------------------------------------------------
    -- Guard
    ------------------------------------------------------------------

    TestRunner:Describe("Guard", function()

        TestRunner:It("returns value when not secret", function()
            InstallMock()
            Assert.Equals("hello", Loolib.SecretUtil.Guard("hello"))
            Assert.Equals(42, Loolib.SecretUtil.Guard(42))
        end, { category = "unit" })

        TestRunner:It("returns nil for secret value (no fallback)", function()
            InstallMock()
            Assert.IsNil(Loolib.SecretUtil.Guard(SECRET_SENTINEL))
        end, { category = "unit" })

        TestRunner:It("returns fallback for secret value", function()
            InstallMock()
            Assert.Equals("fallback", Loolib.SecretUtil.Guard(SECRET_SENTINEL, "fallback"))
        end, { category = "unit" })

        TestRunner:It("passthrough when issecretvalue is nil", function()
            issecretvalue = nil
            Assert.Equals("test", Loolib.SecretUtil.Guard("test"))
        end, { category = "unit" })
    end)

    ------------------------------------------------------------------
    -- GuardToString
    ------------------------------------------------------------------

    TestRunner:Describe("GuardToString", function()

        TestRunner:It("returns tostring for non-secret", function()
            InstallMock()
            Assert.Equals("42", Loolib.SecretUtil.GuardToString(42))
            Assert.Equals("hello", Loolib.SecretUtil.GuardToString("hello"))
        end, { category = "unit" })

        TestRunner:It("returns <secret> for secret value", function()
            InstallMock()
            Assert.Equals("<secret>", Loolib.SecretUtil.GuardToString(SECRET_SENTINEL))
        end, { category = "unit" })

        TestRunner:It("returns custom placeholder for secret value", function()
            InstallMock()
            Assert.Equals("???", Loolib.SecretUtil.GuardToString(SECRET_SENTINEL, "???"))
        end, { category = "unit" })

        TestRunner:It("passthrough when issecretvalue is nil", function()
            issecretvalue = nil
            Assert.Equals("42", Loolib.SecretUtil.GuardToString(42))
        end, { category = "unit" })
    end)
end)

--[[--------------------------------------------------------------------
    Tests - Utils Delegates (backward compatibility)
----------------------------------------------------------------------]]

TestRunner:Describe("SecretValue Guards (Utils delegates)", function()

    TestRunner:AfterEach(function()
        RemoveMock()
    end)

    ------------------------------------------------------------------
    -- IsSecretValue delegation
    ------------------------------------------------------------------

    TestRunner:Describe("IsSecretValue (delegate)", function()

        TestRunner:It("delegates to Loolib.SecretUtil", function()
            InstallMock()
            Assert.IsTrue(Utils.IsSecretValue(SECRET_SENTINEL))
            Assert.IsFalse(Utils.IsSecretValue("normal"))
        end, { category = "unit" })

        TestRunner:It("returns false when issecretvalue is nil", function()
            issecretvalue = nil
            Assert.IsFalse(Utils.IsSecretValue("hello"))
        end, { category = "unit" })
    end)

    ------------------------------------------------------------------
    -- SecretsForPrint delegation
    ------------------------------------------------------------------

    TestRunner:Describe("SecretsForPrint (delegate)", function()

        TestRunner:It("delegates to Loolib.SecretUtil", function()
            InstallMock()
            local a, b = Utils.SecretsForPrint("normal", SECRET_SENTINEL)
            Assert.Equals("normal", a)
            Assert.Equals("<secret>", b)
        end, { category = "unit" })

        TestRunner:It("passes through when issecretvalue is nil", function()
            issecretvalue = nil
            local a, b = Utils.SecretsForPrint("a", "b")
            Assert.Equals("a", a)
            Assert.Equals("b", b)
        end, { category = "unit" })
    end)

    ------------------------------------------------------------------
    -- NormalizeName with secret values
    ------------------------------------------------------------------

    TestRunner:Describe("NormalizeName (secret guard)", function()

        TestRunner:It("returns nil for secret name", function()
            InstallMock()
            Assert.IsNil(Utils.NormalizeName(SECRET_SENTINEL))
        end, { category = "unit" })

        TestRunner:It("still works for normal names", function()
            InstallMock()
            local result = Utils.NormalizeName("PlayerName")
            Assert.IsNotNil(result)
            Assert.IsTrue(type(result) == "string")
        end, { category = "unit" })

        TestRunner:It("still returns nil for nil input", function()
            InstallMock()
            Assert.IsNil(Utils.NormalizeName(nil))
        end, { category = "unit" })
    end)

    ------------------------------------------------------------------
    -- GetShortName with secret values
    ------------------------------------------------------------------

    TestRunner:Describe("GetShortName (secret guard)", function()

        TestRunner:It("returns nil for secret name", function()
            InstallMock()
            Assert.IsNil(Utils.GetShortName(SECRET_SENTINEL))
        end, { category = "unit" })

        TestRunner:It("still works for normal names", function()
            InstallMock()
            Assert.Equals("Player", Utils.GetShortName("Player-Realm"))
        end, { category = "unit" })
    end)

    ------------------------------------------------------------------
    -- IsSamePlayer with secret values
    ------------------------------------------------------------------

    TestRunner:Describe("IsSamePlayer (secret guard)", function()

        TestRunner:It("returns false when first name is secret", function()
            InstallMock()
            Assert.IsFalse(Utils.IsSamePlayer(SECRET_SENTINEL, "PlayerName"))
        end, { category = "unit" })

        TestRunner:It("returns false when second name is secret", function()
            InstallMock()
            Assert.IsFalse(Utils.IsSamePlayer("PlayerName", SECRET_SENTINEL))
        end, { category = "unit" })

        TestRunner:It("returns false when both names are secret", function()
            InstallMock()
            Assert.IsFalse(Utils.IsSamePlayer(SECRET_SENTINEL, SECRET_SENTINEL))
        end, { category = "unit" })

        TestRunner:It("still works for normal names", function()
            InstallMock()
            local result = Utils.IsSamePlayer("Player-Realm", "Player-Realm")
            Assert.IsTrue(result)
        end, { category = "unit" })
    end)

    ------------------------------------------------------------------
    -- Backward compatibility
    ------------------------------------------------------------------

    TestRunner:Describe("Backward Compatibility", function()

        TestRunner:It("all guards are no-ops when issecretvalue is nil", function()
            issecretvalue = nil
            Assert.IsFalse(Utils.IsSecretValue("test"))
            Assert.Equals("Name", Utils.GetShortName("Name-Realm"))
            Assert.IsNotNil(Utils.NormalizeName("Name"))
            Assert.IsFalse(Utils.IsSamePlayer(nil, "test"))
            local a, b = Utils.SecretsForPrint("a", "b")
            Assert.Equals("a", a)
            Assert.Equals("b", b)
        end, { category = "unit" })
    end)
end)
