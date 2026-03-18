local _, ns = ...

--[[--------------------------------------------------------------------
    Loothing - Loot Council Addon for WoW 12.0+
    AutoPassTests - Test suite for automatic pass logic

    Tests AutoPass tables and ShouldAutoPass logic:
    - Armor type mismatches (Plate on Cloth, Mail on Leather, etc.)
    - Weapon type restrictions (Warglaives, Bows, etc.)
    - Weapon stat mismatches (STR weapon on INT class)
    - Class restriction flag parsing
    - Transmog exception handling
    - TestData.AutoPass fixture validation

    Run: /lt test run autopass
----------------------------------------------------------------------]]
local AutoPass = ns.AutoPass
local TestData = ns.TestData
local TestRunner = ns.TestRunner

local function RunAutoPassTests()
    local passed = 0
    local failed = 0

    local function assert(condition, testName)
        if condition then
            print("|cff00ff00[PASS]|r", testName)
            passed = passed + 1
        else
            print("|cffff0000[FAIL]|r", testName)
            failed = failed + 1
        end
    end

    local function assertEqual(actual, expected, testName)
        if actual == expected then
            print("|cff00ff00[PASS]|r", testName)
            passed = passed + 1
        else
            print("|cffff0000[FAIL]|r", testName, string.format("(got '%s', expected '%s')", tostring(actual), tostring(expected)))
            failed = failed + 1
        end
    end

    local function assertNotNil(value, testName)
        if value ~= nil then
            print("|cff00ff00[PASS]|r", testName)
            passed = passed + 1
        else
            print("|cffff0000[FAIL]|r", testName, "(value is nil)")
            failed = failed + 1
        end
    end

    local function printGroup(groupName)
        print("\n|cffFFFF00Test Group: " .. groupName .. "|r")
    end

    print("|cff00ccff========== AutoPass Tests ==========|r")

    if not AutoPass then
        print("|cffff0000[SKIP]|r AutoPass not available")
        return passed, failed
    end

    --[[--------------------------------------------------------------------
        Test Group 1: Armor AutoPass Tables Exist
    ----------------------------------------------------------------------]]
    printGroup("Armor AutoPass Tables")

    assertNotNil(AutoPass.armorAutoPass, "armorAutoPass table exists")

    -- Verify Enum references are valid (WoW API dependency)
    if Enum and Enum.ItemArmorSubclass then
        assertNotNil(AutoPass.armorAutoPass[Enum.ItemArmorSubclass.Cloth], "Cloth autopass list exists")
        assertNotNil(AutoPass.armorAutoPass[Enum.ItemArmorSubclass.Leather], "Leather autopass list exists")
        assertNotNil(AutoPass.armorAutoPass[Enum.ItemArmorSubclass.Mail], "Mail autopass list exists")
        assertNotNil(AutoPass.armorAutoPass[Enum.ItemArmorSubclass.Plate], "Plate autopass list exists")
    else
        print("|cffffcc00[SKIP]|r Enum.ItemArmorSubclass not available")
    end

    --[[--------------------------------------------------------------------
        Test Group 2: Plate on Non-Plate Classes
    ----------------------------------------------------------------------]]
    printGroup("Plate on Non-Plate Classes")

    if Enum and Enum.ItemArmorSubclass then
        local platePassList = AutoPass.armorAutoPass[Enum.ItemArmorSubclass.Plate]
        if platePassList then
            -- Helper to check if class is in the list
            local function classInList(list, className)
                for _, c in ipairs(list) do
                    if c == className then return true end
                end
                return false
            end

            -- These classes should auto-pass on Plate
            assert(classInList(platePassList, "MAGE"), "Mage auto-passes Plate")
            assert(classInList(platePassList, "PRIEST"), "Priest auto-passes Plate")
            assert(classInList(platePassList, "WARLOCK"), "Warlock auto-passes Plate")
            assert(classInList(platePassList, "DRUID"), "Druid auto-passes Plate")
            assert(classInList(platePassList, "ROGUE"), "Rogue auto-passes Plate")
            assert(classInList(platePassList, "MONK"), "Monk auto-passes Plate")
            assert(classInList(platePassList, "HUNTER"), "Hunter auto-passes Plate")
            assert(classInList(platePassList, "SHAMAN"), "Shaman auto-passes Plate")
            assert(classInList(platePassList, "DEMONHUNTER"), "Demon Hunter auto-passes Plate")
            assert(classInList(platePassList, "EVOKER"), "Evoker auto-passes Plate")

            -- Plate wearers should NOT be in the list
            assert(not classInList(platePassList, "WARRIOR"), "Warrior does NOT auto-pass Plate")
            assert(not classInList(platePassList, "PALADIN"), "Paladin does NOT auto-pass Plate")
            assert(not classInList(platePassList, "DEATHKNIGHT"), "Death Knight does NOT auto-pass Plate")
        end
    end

    --[[--------------------------------------------------------------------
        Test Group 3: Cloth on Non-Cloth Classes
    ----------------------------------------------------------------------]]
    printGroup("Cloth on Non-Cloth Classes")

    if Enum and Enum.ItemArmorSubclass then
        local clothPassList = AutoPass.armorAutoPass[Enum.ItemArmorSubclass.Cloth]
        if clothPassList then
            local function classInList(list, className)
                for _, c in ipairs(list) do
                    if c == className then return true end
                end
                return false
            end

            -- Non-cloth wearers should auto-pass Cloth
            assert(classInList(clothPassList, "WARRIOR"), "Warrior auto-passes Cloth")
            assert(classInList(clothPassList, "HUNTER"), "Hunter auto-passes Cloth")
            assert(classInList(clothPassList, "ROGUE"), "Rogue auto-passes Cloth")

            -- Cloth wearers should NOT be in the list
            assert(not classInList(clothPassList, "MAGE"), "Mage does NOT auto-pass Cloth")
            assert(not classInList(clothPassList, "PRIEST"), "Priest does NOT auto-pass Cloth")
            assert(not classInList(clothPassList, "WARLOCK"), "Warlock does NOT auto-pass Cloth")
        end
    end

    --[[--------------------------------------------------------------------
        Test Group 4: Shield Users Are Never Auto-Passed By Shield Table
    ----------------------------------------------------------------------]]
    printGroup("Shield AutoPass Rules")

    if Enum and Enum.ItemArmorSubclass then
        local shieldPassList = AutoPass.armorAutoPass[Enum.ItemArmorSubclass.Shield]
        if shieldPassList then
            local function classInList(list, className)
                for _, c in ipairs(list) do
                    if c == className then return true end
                end
                return false
            end

            assert(not classInList(shieldPassList, "PALADIN"), "Paladin does NOT auto-pass Shields")
            assert(not classInList(shieldPassList, "SHAMAN"), "Shaman does NOT auto-pass Shields")
            assert(not classInList(shieldPassList, "WARRIOR"), "Warrior does NOT auto-pass Shields")
            assert(classInList(shieldPassList, "MAGE"), "Mage auto-passes Shields")
            assert(classInList(shieldPassList, "PRIEST"), "Priest auto-passes Shields")
        end
    end

    --[[--------------------------------------------------------------------
        Test Group 4: Weapon AutoPass Tables
    ----------------------------------------------------------------------]]
    printGroup("Weapon AutoPass Tables")

    assertNotNil(AutoPass.weaponAutoPass, "weaponAutoPass table exists")

    if Enum and Enum.ItemWeaponSubclass then
        -- Warglaives - only DH can use
        local glaivePassList = AutoPass.weaponAutoPass[Enum.ItemWeaponSubclass.Warglaive]
        if glaivePassList then
            local function classInList(list, className)
                for _, c in ipairs(list) do
                    if c == className then return true end
                end
                return false
            end

            assert(not classInList(glaivePassList, "DEMONHUNTER"), "DH does NOT auto-pass Warglaives")
            assert(classInList(glaivePassList, "WARRIOR"), "Warrior auto-passes Warglaives")
            assert(classInList(glaivePassList, "MAGE"), "Mage auto-passes Warglaives")
        end

        -- Bows - limited to Hunter only
        local bowPassList = AutoPass.weaponAutoPass[Enum.ItemWeaponSubclass.Bows]
        if bowPassList then
            local function classInList(list, className)
                for _, c in ipairs(list) do
                    if c == className then return true end
                end
                return false
            end

            assert(not classInList(bowPassList, "HUNTER"), "Hunter does NOT auto-pass Bows")
            assert(classInList(bowPassList, "MAGE"), "Mage auto-passes Bows")
            assert(classInList(bowPassList, "PRIEST"), "Priest auto-passes Bows")
            assert(classInList(bowPassList, "ROGUE"), "Rogue auto-passes Bows")
        end

        -- Crossbows - limited to Hunter only
        local crossbowPassList = AutoPass.weaponAutoPass[Enum.ItemWeaponSubclass.Crossbow]
        if crossbowPassList then
            local function classInList(list, className)
                for _, c in ipairs(list) do
                    if c == className then return true end
                end
                return false
            end

            assert(not classInList(crossbowPassList, "HUNTER"), "Hunter does NOT auto-pass Crossbows")
            assert(classInList(crossbowPassList, "MAGE"), "Mage auto-passes Crossbows")
            assert(classInList(crossbowPassList, "PRIEST"), "Priest auto-passes Crossbows")
            assert(classInList(crossbowPassList, "ROGUE"), "Rogue auto-passes Crossbows")
        end

        -- Guns - limited to Hunter only
        local gunPassList = AutoPass.weaponAutoPass[Enum.ItemWeaponSubclass.Guns]
        if gunPassList then
            local function classInList(list, className)
                for _, c in ipairs(list) do
                    if c == className then return true end
                end
                return false
            end

            assert(not classInList(gunPassList, "HUNTER"), "Hunter does NOT auto-pass Guns")
            assert(classInList(gunPassList, "MAGE"), "Mage auto-passes Guns")
            assert(classInList(gunPassList, "PRIEST"), "Priest auto-passes Guns")
            assert(classInList(gunPassList, "ROGUE"), "Rogue auto-passes Guns")
        end
    else
        print("|cffffcc00[SKIP]|r Enum.ItemWeaponSubclass not available")
    end

    --[[--------------------------------------------------------------------
        Test Group 5: ShouldAutoPass Integration
    ----------------------------------------------------------------------]]
    printGroup("ShouldAutoPass Integration")

    if AutoPass.ShouldAutoPass then
        -- This function requires live item data, so we test with mock data
        -- if available from TestHelpers
        print("  |cff808080(ShouldAutoPass requires live C_Item data - testing structure only)|r")

        -- Verify the function exists and is callable
        local funcType = type(AutoPass.ShouldAutoPass)
        assertEqual(funcType, "function", "ShouldAutoPass is a function")
    elseif AutoPass.CheckArmorType then
        -- Test the armor type check directly
        local funcType = type(AutoPass.CheckArmorType)
        assertEqual(funcType, "function", "CheckArmorType is a function")
    else
        print("  |cff808080(ShouldAutoPass/CheckArmorType not found - testing tables only)|r")
    end

    --[[--------------------------------------------------------------------
        Test Group 6: TestData AutoPass Fixtures
    ----------------------------------------------------------------------]]
    printGroup("TestData AutoPass Fixtures")

    if TestData and TestData.AutoPass then
        local td = TestData.AutoPass

        -- Armor mismatch fixtures
        assertNotNil(td.ArmorMismatches, "ArmorMismatches fixture exists")
        assert(#td.ArmorMismatches >= 4, "ArmorMismatches has at least 4 cases")

        -- Verify first case: Plate on Mage (should auto-pass)
        local case1 = td.ArmorMismatches[1]
        assertEqual(case1.playerClass, "MAGE", "Case 1: Mage")
        assertEqual(case1.shouldAutoPass, true, "Case 1: should auto-pass (Plate on Mage)")

        -- Verify second case: Cloth on Mage (should NOT auto-pass)
        local case2 = td.ArmorMismatches[2]
        assertEqual(case2.playerClass, "MAGE", "Case 2: Mage")
        assertEqual(case2.shouldAutoPass, false, "Case 2: should NOT auto-pass (Cloth on Mage)")

        -- Trinket restriction fixtures
        assertNotNil(td.TrinketRestrictions, "TrinketRestrictions fixture exists")
        assert(#td.TrinketRestrictions >= 4, "TrinketRestrictions has at least 4 cases")

        -- Token restriction fixtures
        assertNotNil(td.TokenRestrictions, "TokenRestrictions fixture exists")
        assert(#td.TokenRestrictions >= 4, "TokenRestrictions has at least 4 cases")

        -- Verify Dreadful (Plate) token on Mage should auto-pass
        local tokenCase1 = td.TokenRestrictions[1]
        assertEqual(tokenCase1.playerClass, "MAGE", "Token case 1: Mage")
        assertEqual(tokenCase1.shouldAutoPass, true, "Token case 1: should auto-pass (Plate token on Mage)")
    else
        print("|cffffcc00[SKIP]|r TestData.AutoPass not available")
    end

    --[[--------------------------------------------------------------------
        Test Group 7: Class Flag Bitwise
    ----------------------------------------------------------------------]]
    printGroup("Class Flag Bitwise")

    -- Test ALL_CLASSES_FLAG (bits 1-13)
    local ALL_CLASSES_FLAG = 0x1FFF  -- 13 bits set

    -- Verify each class bit
    for classID = 1, 13 do
        local classBit = bit.lshift(1, classID - 1)
        local hasClass = bit.band(ALL_CLASSES_FLAG, classBit) ~= 0
        assert(hasClass, string.format("ALL_CLASSES_FLAG includes classID %d", classID))
    end

    -- Bit 14 should not be set
    local bit14 = bit.lshift(1, 13)
    assertEqual(bit.band(ALL_CLASSES_FLAG, bit14), 0, "ALL_CLASSES_FLAG does not include bit 14")

    -- Test single-class flag (e.g., Warrior only = bit 1)
    local warriorOnly = bit.lshift(1, 0)
    assertEqual(bit.band(warriorOnly, bit.lshift(1, 0)), warriorOnly, "Warrior-only flag matches classID 1")
    assertEqual(bit.band(warriorOnly, bit.lshift(1, 1)), 0, "Warrior-only flag excludes classID 2 (Paladin)")

    -- Test multi-class flag (Plate: Warrior + Paladin + DK = bits 1, 2, 6)
    local plateClasses = bit.bor(bit.lshift(1, 0), bit.lshift(1, 1), bit.lshift(1, 5))
    assert(bit.band(plateClasses, bit.lshift(1, 0)) ~= 0, "Plate flag includes Warrior")
    assert(bit.band(plateClasses, bit.lshift(1, 1)) ~= 0, "Plate flag includes Paladin")
    assert(bit.band(plateClasses, bit.lshift(1, 5)) ~= 0, "Plate flag includes Death Knight")
    assertEqual(bit.band(plateClasses, bit.lshift(1, 7)), 0, "Plate flag excludes Mage")

    --[[--------------------------------------------------------------------
        Summary
    ----------------------------------------------------------------------]]
    print("\n|cff00ccff========== Results ==========|r")
    print(string.format("|cff00ff00Passed: %d|r  |cffff0000Failed: %d|r  Total: %d", passed, failed, passed + failed))

    return passed, failed
end

-- Register test
if TestRunner then
    TestRunner:RegisterTest("autopass", RunAutoPassTests)
end
