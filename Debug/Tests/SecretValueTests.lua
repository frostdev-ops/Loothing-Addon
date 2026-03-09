--[[--------------------------------------------------------------------
    Loothing - Loot Council Addon for WoW 12.0+
    SecretValueTests - Tests for LoolibSecretUtil and LoothingUtils delegates

    Verifies that LoolibSecretUtil core functions and the LoothingUtils
    backward-compatible delegates correctly handle WoW 12.0 secret values.
----------------------------------------------------------------------]]

local TestRunner = LoothingTestRunner
local Assert = LoothingAssert

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
    Tests - LoolibSecretUtil (library level)
----------------------------------------------------------------------]]

TestRunner:Describe("LoolibSecretUtil", function()

    TestRunner:AfterEach(function()
        RemoveMock()
    end)

    ------------------------------------------------------------------
    -- IsAvailable
    ------------------------------------------------------------------

    TestRunner:Describe("IsAvailable", function()

        TestRunner:It("returns false when issecretvalue is nil", function()
            issecretvalue = nil
            Assert.IsFalse(LoolibSecretUtil.IsAvailable())
        end, { category = "unit" })

        TestRunner:It("returns true when issecretvalue exists", function()
            InstallMock()
            Assert.IsTrue(LoolibSecretUtil.IsAvailable())
        end, { category = "unit" })
    end)

    ------------------------------------------------------------------
    -- IsSecretValue
    ------------------------------------------------------------------

    TestRunner:Describe("IsSecretValue", function()

        TestRunner:It("returns false when issecretvalue is not available", function()
            issecretvalue = nil
            Assert.IsFalse(LoolibSecretUtil.IsSecretValue("hello"))
            Assert.IsFalse(LoolibSecretUtil.IsSecretValue(42))
            Assert.IsFalse(LoolibSecretUtil.IsSecretValue(nil))
        end, { category = "unit" })

        TestRunner:It("returns false for normal values", function()
            InstallMock()
            Assert.IsFalse(LoolibSecretUtil.IsSecretValue("PlayerName"))
            Assert.IsFalse(LoolibSecretUtil.IsSecretValue(123))
            Assert.IsFalse(LoolibSecretUtil.IsSecretValue(nil))
            Assert.IsFalse(LoolibSecretUtil.IsSecretValue(true))
        end, { category = "unit" })

        TestRunner:It("returns true for secret values", function()
            InstallMock()
            Assert.IsTrue(LoolibSecretUtil.IsSecretValue(SECRET_SENTINEL))
        end, { category = "unit" })

        TestRunner:It("returns true if any argument is secret (varargs)", function()
            InstallMock()
            Assert.IsTrue(LoolibSecretUtil.IsSecretValue("normal", SECRET_SENTINEL))
            Assert.IsTrue(LoolibSecretUtil.IsSecretValue(SECRET_SENTINEL, "normal"))
            Assert.IsFalse(LoolibSecretUtil.IsSecretValue("a", "b", "c"))
        end, { category = "unit" })

        TestRunner:It("handles zero arguments", function()
            InstallMock()
            Assert.IsFalse(LoolibSecretUtil.IsSecretValue())
        end, { category = "unit" })
    end)

    ------------------------------------------------------------------
    -- SecretsForPrint
    ------------------------------------------------------------------

    TestRunner:Describe("SecretsForPrint", function()

        TestRunner:It("passes through normal values when issecretvalue unavailable", function()
            issecretvalue = nil
            local a, b = LoolibSecretUtil.SecretsForPrint("hello", 42)
            Assert.Equals("hello", a)
            Assert.Equals(42, b)
        end, { category = "unit" })

        TestRunner:It("replaces secret values with <secret>", function()
            InstallMock()
            local a, b, c = LoolibSecretUtil.SecretsForPrint("normal", SECRET_SENTINEL, 123)
            Assert.Equals("normal", a)
            Assert.Equals("<secret>", b)
            Assert.Equals("123", c)
        end, { category = "unit" })

        TestRunner:It("handles zero arguments", function()
            InstallMock()
            local result = { LoolibSecretUtil.SecretsForPrint() }
            Assert.Equals(0, #result)
        end, { category = "unit" })
    end)

    ------------------------------------------------------------------
    -- Guard
    ------------------------------------------------------------------

    TestRunner:Describe("Guard", function()

        TestRunner:It("returns value when not secret", function()
            InstallMock()
            Assert.Equals("hello", LoolibSecretUtil.Guard("hello"))
            Assert.Equals(42, LoolibSecretUtil.Guard(42))
        end, { category = "unit" })

        TestRunner:It("returns nil for secret value (no fallback)", function()
            InstallMock()
            Assert.IsNil(LoolibSecretUtil.Guard(SECRET_SENTINEL))
        end, { category = "unit" })

        TestRunner:It("returns fallback for secret value", function()
            InstallMock()
            Assert.Equals("fallback", LoolibSecretUtil.Guard(SECRET_SENTINEL, "fallback"))
        end, { category = "unit" })

        TestRunner:It("passthrough when issecretvalue is nil", function()
            issecretvalue = nil
            Assert.Equals("test", LoolibSecretUtil.Guard("test"))
        end, { category = "unit" })
    end)

    ------------------------------------------------------------------
    -- GuardToString
    ------------------------------------------------------------------

    TestRunner:Describe("GuardToString", function()

        TestRunner:It("returns tostring for non-secret", function()
            InstallMock()
            Assert.Equals("42", LoolibSecretUtil.GuardToString(42))
            Assert.Equals("hello", LoolibSecretUtil.GuardToString("hello"))
        end, { category = "unit" })

        TestRunner:It("returns <secret> for secret value", function()
            InstallMock()
            Assert.Equals("<secret>", LoolibSecretUtil.GuardToString(SECRET_SENTINEL))
        end, { category = "unit" })

        TestRunner:It("returns custom placeholder for secret value", function()
            InstallMock()
            Assert.Equals("???", LoolibSecretUtil.GuardToString(SECRET_SENTINEL, "???"))
        end, { category = "unit" })

        TestRunner:It("passthrough when issecretvalue is nil", function()
            issecretvalue = nil
            Assert.Equals("42", LoolibSecretUtil.GuardToString(42))
        end, { category = "unit" })
    end)
end)

--[[--------------------------------------------------------------------
    Tests - LoothingUtils Delegates (backward compatibility)
----------------------------------------------------------------------]]

TestRunner:Describe("SecretValue Guards (LoothingUtils delegates)", function()

    TestRunner:AfterEach(function()
        RemoveMock()
    end)

    ------------------------------------------------------------------
    -- IsSecretValue delegation
    ------------------------------------------------------------------

    TestRunner:Describe("IsSecretValue (delegate)", function()

        TestRunner:It("delegates to LoolibSecretUtil", function()
            InstallMock()
            Assert.IsTrue(LoothingUtils.IsSecretValue(SECRET_SENTINEL))
            Assert.IsFalse(LoothingUtils.IsSecretValue("normal"))
        end, { category = "unit" })

        TestRunner:It("returns false when issecretvalue is nil", function()
            issecretvalue = nil
            Assert.IsFalse(LoothingUtils.IsSecretValue("hello"))
        end, { category = "unit" })
    end)

    ------------------------------------------------------------------
    -- SecretsForPrint delegation
    ------------------------------------------------------------------

    TestRunner:Describe("SecretsForPrint (delegate)", function()

        TestRunner:It("delegates to LoolibSecretUtil", function()
            InstallMock()
            local a, b = LoothingUtils.SecretsForPrint("normal", SECRET_SENTINEL)
            Assert.Equals("normal", a)
            Assert.Equals("<secret>", b)
        end, { category = "unit" })

        TestRunner:It("passes through when issecretvalue is nil", function()
            issecretvalue = nil
            local a, b = LoothingUtils.SecretsForPrint("a", "b")
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
            Assert.IsNil(LoothingUtils.NormalizeName(SECRET_SENTINEL))
        end, { category = "unit" })

        TestRunner:It("still works for normal names", function()
            InstallMock()
            local result = LoothingUtils.NormalizeName("PlayerName")
            Assert.IsNotNil(result)
            Assert.IsTrue(type(result) == "string")
        end, { category = "unit" })

        TestRunner:It("still returns nil for nil input", function()
            InstallMock()
            Assert.IsNil(LoothingUtils.NormalizeName(nil))
        end, { category = "unit" })
    end)

    ------------------------------------------------------------------
    -- GetShortName with secret values
    ------------------------------------------------------------------

    TestRunner:Describe("GetShortName (secret guard)", function()

        TestRunner:It("returns nil for secret name", function()
            InstallMock()
            Assert.IsNil(LoothingUtils.GetShortName(SECRET_SENTINEL))
        end, { category = "unit" })

        TestRunner:It("still works for normal names", function()
            InstallMock()
            Assert.Equals("Player", LoothingUtils.GetShortName("Player-Realm"))
        end, { category = "unit" })
    end)

    ------------------------------------------------------------------
    -- IsSamePlayer with secret values
    ------------------------------------------------------------------

    TestRunner:Describe("IsSamePlayer (secret guard)", function()

        TestRunner:It("returns false when first name is secret", function()
            InstallMock()
            Assert.IsFalse(LoothingUtils.IsSamePlayer(SECRET_SENTINEL, "PlayerName"))
        end, { category = "unit" })

        TestRunner:It("returns false when second name is secret", function()
            InstallMock()
            Assert.IsFalse(LoothingUtils.IsSamePlayer("PlayerName", SECRET_SENTINEL))
        end, { category = "unit" })

        TestRunner:It("returns false when both names are secret", function()
            InstallMock()
            Assert.IsFalse(LoothingUtils.IsSamePlayer(SECRET_SENTINEL, SECRET_SENTINEL))
        end, { category = "unit" })

        TestRunner:It("still works for normal names", function()
            InstallMock()
            local result = LoothingUtils.IsSamePlayer("Player-Realm", "Player-Realm")
            Assert.IsTrue(result)
        end, { category = "unit" })
    end)

    ------------------------------------------------------------------
    -- Backward compatibility
    ------------------------------------------------------------------

    TestRunner:Describe("Backward Compatibility", function()

        TestRunner:It("all guards are no-ops when issecretvalue is nil", function()
            issecretvalue = nil
            Assert.IsFalse(LoothingUtils.IsSecretValue("test"))
            Assert.Equals("Name", LoothingUtils.GetShortName("Name-Realm"))
            Assert.IsNotNil(LoothingUtils.NormalizeName("Name"))
            Assert.IsFalse(LoothingUtils.IsSamePlayer(nil, "test"))
            local a, b = LoothingUtils.SecretsForPrint("a", "b")
            Assert.Equals("a", a)
            Assert.Equals("b", b)
        end, { category = "unit" })
    end)
end)
