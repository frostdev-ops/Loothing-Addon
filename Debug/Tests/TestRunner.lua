--[[--------------------------------------------------------------------
    Loothing - Loot Council Addon for WoW 12.0+
    TestRunner - Lightweight testing framework for WoW addons

    Inspired by Busted, Mocha, and Jest. Provides:
    - Describe/It test organization
    - Before/After hooks
    - Rich assertion library
    - Color-coded output
    - Performance tracking
    - Test filtering by category
    - Skip/Focus for debugging

    Usage:
        TestRunner:Describe("VotingEngine", function()
            TestRunner:BeforeEach(function()
                -- Setup code
            end)

            TestRunner:It("should tally votes correctly", function()
                local result = TallyVotes(votes)
                Assert.Equals(3, result.total)
            end, { category = "unit" })
        end)

        TestRunner:RunAll()
----------------------------------------------------------------------]]

--[[--------------------------------------------------------------------
    Global Namespace
----------------------------------------------------------------------]]

LoothingTestRunner = {}
LoothingAssert = {}

-- Local references for cleaner code
local TestRunner = LoothingTestRunner
local Assert = LoothingAssert

--[[--------------------------------------------------------------------
    Color Codes
----------------------------------------------------------------------]]

local COLOR = {
    GREEN = "|cff00ff00",
    RED = "|cffff0000",
    YELLOW = "|cffffff00",
    BLUE = "|cff3fc7eb",
    CYAN = "|cff00ffff",
    GRAY = "|cff808080",
    WHITE = "|cffffffff",
    ORANGE = "|cffff9900",
    RESET = "|r",
}

--[[--------------------------------------------------------------------
    Internal State
----------------------------------------------------------------------]]

--- @class TestSuite
--- @field name string - Suite name
--- @field tests table<number, Test> - Array of tests
--- @field beforeEach function[] - Before each hooks
--- @field afterEach function[] - After each hooks
--- @field beforeAll function[] - Before all hooks
--- @field afterAll function[] - After all hooks
--- @field focused boolean - Whether this suite is focused

--- @class Test
--- @field name string - Test name
--- @field func function - Test function
--- @field category string - Test category (unit, integration, stress, ui)
--- @field skip boolean - Whether to skip this test
--- @field skipReason string - Reason for skipping
--- @field focused boolean - Whether this test is focused
--- @field suite TestSuite - Parent suite

--- @class TestResult
--- @field name string - Test name
--- @field suiteName string - Suite name
--- @field status "pass"|"fail"|"skip" - Test status
--- @field error string - Error message if failed
--- @field stackTrace string - Stack trace if failed
--- @field duration number - Execution time in milliseconds
--- @field category string - Test category

local state = {
    suites = {},              -- All registered suites
    currentSuite = nil,       -- Suite being defined
    currentTest = nil,        -- Test being executed
    results = {},             -- All test results
    hasFocusedTests = false,  -- Whether any tests are focused
    options = {
        showPassed = true,
        showSkipped = true,
        showStackTrace = true,
        slowThreshold = 100,  -- Tests slower than this (ms) are highlighted
    },
}

--[[--------------------------------------------------------------------
    Test Suite Registration
----------------------------------------------------------------------]]

--- Define a test suite
--- @param suiteName string - Name of the test suite
--- @param suiteFunc function - Function containing test definitions
function TestRunner:Describe(suiteName, suiteFunc)
    assert(type(suiteName) == "string", "Suite name must be a string")
    assert(type(suiteFunc) == "function", "Suite function must be a function")

    -- Create suite
    local suite = {
        name = suiteName,
        tests = {},
        beforeEach = {},
        afterEach = {},
        beforeAll = {},
        afterAll = {},
        focused = false,
    }

    table.insert(state.suites, suite)

    -- Set as current suite and run suite definition
    local previousSuite = state.currentSuite
    state.currentSuite = suite

    local success, err = pcall(suiteFunc)
    if not success then
        print(COLOR.RED .. "[TestRunner] Error defining suite '" .. suiteName .. "': " .. tostring(err) .. COLOR.RESET)
    end

    state.currentSuite = previousSuite
end

--- Define a test case
--- @param testName string - Name of the test
--- @param testFunc function - Test function
--- @param options table - Optional test options { category = "unit", skip = false, focus = false }
function TestRunner:It(testName, testFunc, options)
    assert(state.currentSuite, "It() must be called inside a Describe() block")
    assert(type(testName) == "string", "Test name must be a string")
    assert(type(testFunc) == "function", "Test function must be a function")

    options = options or {}

    local test = {
        name = testName,
        func = testFunc,
        category = options.category or "unit",
        skip = options.skip or false,
        skipReason = options.skipReason or "No reason provided",
        focused = options.focus or false,
        suite = state.currentSuite,
    }

    table.insert(state.currentSuite.tests, test)

    if test.focused then
        state.hasFocusedTests = true
    end
end

--[[--------------------------------------------------------------------
    Hooks
----------------------------------------------------------------------]]

--- Register a function to run before each test in the current suite
--- @param func function - Hook function
function TestRunner:BeforeEach(func)
    assert(state.currentSuite, "BeforeEach() must be called inside a Describe() block")
    assert(type(func) == "function", "BeforeEach argument must be a function")
    table.insert(state.currentSuite.beforeEach, func)
end

--- Register a function to run after each test in the current suite
--- @param func function - Hook function
function TestRunner:AfterEach(func)
    assert(state.currentSuite, "AfterEach() must be called inside a Describe() block")
    assert(type(func) == "function", "AfterEach argument must be a function")
    table.insert(state.currentSuite.afterEach, func)
end

--- Register a function to run once before all tests in the current suite
--- @param func function - Hook function
function TestRunner:BeforeAll(func)
    assert(state.currentSuite, "BeforeAll() must be called inside a Describe() block")
    assert(type(func) == "function", "BeforeAll argument must be a function")
    table.insert(state.currentSuite.beforeAll, func)
end

--- Register a function to run once after all tests in the current suite
--- @param func function - Hook function
function TestRunner:AfterAll(func)
    assert(state.currentSuite, "AfterAll() must be called inside a Describe() block")
    assert(type(func) == "function", "AfterAll argument must be a function")
    table.insert(state.currentSuite.afterAll, func)
end

--[[--------------------------------------------------------------------
    Test Control
----------------------------------------------------------------------]]

--- Skip the current test
--- @param reason string - Reason for skipping
function TestRunner:Skip(reason)
    assert(state.currentTest, "Skip() must be called during test execution")
    error("SKIP: " .. (reason or "No reason provided"))
end

--- Focus this test (only focused tests will run)
function TestRunner:Focus()
    -- This is a marker function - actual focusing is handled via options.focus
    -- Users should call It("test name", func, { focus = true }) instead
    print(COLOR.YELLOW .. "[TestRunner] Note: Use It(name, func, { focus = true }) instead of calling Focus()" .. COLOR.RESET)
end

--[[--------------------------------------------------------------------
    Test Execution
----------------------------------------------------------------------]]

--- Run a single test
--- @param test Test - Test to run
--- @return TestResult
local function RunTest(test)
    local result = {
        name = test.name,
        suiteName = test.suite.name,
        status = "pass",
        error = nil,
        stackTrace = nil,
        duration = 0,
        category = test.category,
    }

    -- Check if test should be skipped
    if test.skip then
        result.status = "skip"
        result.error = test.skipReason
        return result
    end

    -- Check if we should run this test (based on focus)
    if state.hasFocusedTests and not test.focused then
        result.status = "skip"
        result.error = "Not focused"
        return result
    end

    state.currentTest = test

    -- Run beforeEach hooks
    for _, hook in ipairs(test.suite.beforeEach) do
        local success, err = pcall(hook)
        if not success then
            result.status = "fail"
            result.error = "BeforeEach hook failed: " .. tostring(err)
            result.stackTrace = debugstack(2)
            state.currentTest = nil
            return result
        end
    end

    -- Run the test
    local startTime = debugprofilestop()
    local success, err = pcall(test.func)
    local endTime = debugprofilestop()

    result.duration = endTime - startTime

    if not success then
        -- Check if it's a skip
        if type(err) == "string" and err:match("^SKIP:") then
            result.status = "skip"
            result.error = err:gsub("^SKIP: ", "")
        else
            result.status = "fail"
            result.error = tostring(err)
            result.stackTrace = debugstack(2)
        end
    end

    -- Run afterEach hooks (even if test failed)
    for _, hook in ipairs(test.suite.afterEach) do
        local success, err = pcall(hook)
        if not success then
            -- Don't override test failure, but report hook failure
            if result.status == "pass" then
                result.status = "fail"
                result.error = "AfterEach hook failed: " .. tostring(err)
                result.stackTrace = debugstack(2)
            else
                print(COLOR.ORANGE .. "  [Warning] AfterEach hook failed: " .. tostring(err) .. COLOR.RESET)
            end
        end
    end

    state.currentTest = nil
    return result
end

--- Run all tests in a suite
--- @param suite TestSuite - Suite to run
--- @return TestResult[]
local function RunSuite(suite)
    local results = {}

    print(COLOR.CYAN .. "\n" .. suite.name .. COLOR.RESET)

    -- Run beforeAll hooks
    for _, hook in ipairs(suite.beforeAll) do
        local success, err = pcall(hook)
        if not success then
            print(COLOR.RED .. "  BeforeAll hook failed: " .. tostring(err) .. COLOR.RESET)
            -- Skip all tests in this suite
            for _, test in ipairs(suite.tests) do
                local result = {
                    name = test.name,
                    suiteName = suite.name,
                    status = "skip",
                    error = "BeforeAll hook failed",
                    stackTrace = nil,
                    duration = 0,
                    category = test.category,
                }
                table.insert(results, result)
            end
            return results
        end
    end

    -- Run tests
    for _, test in ipairs(suite.tests) do
        local result = RunTest(test)
        table.insert(results, result)

        -- Print result
        if result.status == "pass" then
            if state.options.showPassed then
                local icon = COLOR.GREEN .. "✓" .. COLOR.RESET
                local duration = result.duration >= state.options.slowThreshold
                    and COLOR.YELLOW .. string.format(" (%.2fms)", result.duration) .. COLOR.RESET
                    or COLOR.GRAY .. string.format(" (%.2fms)", result.duration) .. COLOR.RESET
                print("  " .. icon .. " " .. test.name .. duration)
            end
        elseif result.status == "fail" then
            local icon = COLOR.RED .. "✗" .. COLOR.RESET
            print("  " .. icon .. " " .. test.name)
            print(COLOR.RED .. "    Error: " .. result.error .. COLOR.RESET)
            if state.options.showStackTrace and result.stackTrace then
                print(COLOR.GRAY .. "    Stack trace:" .. COLOR.RESET)
                for line in result.stackTrace:gmatch("[^\n]+") do
                    print(COLOR.GRAY .. "      " .. line .. COLOR.RESET)
                end
            end
        elseif result.status == "skip" then
            if state.options.showSkipped then
                local icon = COLOR.YELLOW .. "○" .. COLOR.RESET
                print("  " .. icon .. " " .. test.name .. COLOR.GRAY .. " (skipped: " .. result.error .. ")" .. COLOR.RESET)
            end
        end
    end

    -- Run afterAll hooks
    for _, hook in ipairs(suite.afterAll) do
        local success, err = pcall(hook)
        if not success then
            print(COLOR.ORANGE .. "  AfterAll hook failed: " .. tostring(err) .. COLOR.RESET)
        end
    end

    return results
end

--- Run all registered test suites
function TestRunner:RunAll()
    print(COLOR.WHITE .. "========================================" .. COLOR.RESET)
    print(COLOR.WHITE .. "  Loothing Test Runner" .. COLOR.RESET)
    print(COLOR.WHITE .. "========================================" .. COLOR.RESET)

    state.results = {}

    for _, suite in ipairs(state.suites) do
        local suiteResults = RunSuite(suite)
        for _, result in ipairs(suiteResults) do
            table.insert(state.results, result)
        end
    end

    self:PrintSummary()
end

--- Run a specific test suite by name
--- @param suiteName string - Name of suite to run
function TestRunner:RunSuite(suiteName)
    for _, suite in ipairs(state.suites) do
        if suite.name == suiteName then
            print(COLOR.WHITE .. "========================================" .. COLOR.RESET)
            print(COLOR.WHITE .. "  Running Suite: " .. suiteName .. COLOR.RESET)
            print(COLOR.WHITE .. "========================================" .. COLOR.RESET)

            state.results = RunSuite(suite)
            self:PrintSummary()
            return
        end
    end

    print(COLOR.RED .. "[TestRunner] Suite not found: " .. suiteName .. COLOR.RESET)
end

--- Run a specific test by suite and test name
--- @param suiteName string - Name of suite
--- @param testName string - Name of test
function TestRunner:RunTest(suiteName, testName)
    for _, suite in ipairs(state.suites) do
        if suite.name == suiteName then
            for _, test in ipairs(suite.tests) do
                if test.name == testName then
                    print(COLOR.WHITE .. "========================================" .. COLOR.RESET)
                    print(COLOR.WHITE .. "  Running: " .. suiteName .. " > " .. testName .. COLOR.RESET)
                    print(COLOR.WHITE .. "========================================" .. COLOR.RESET)

                    local result = RunTest(test)
                    state.results = { result }
                    self:PrintSummary()
                    return
                end
            end
            print(COLOR.RED .. "[TestRunner] Test not found: " .. testName .. COLOR.RESET)
            return
        end
    end

    print(COLOR.RED .. "[TestRunner] Suite not found: " .. suiteName .. COLOR.RESET)
end

--- Run all tests in a specific category
--- @param category string - Category to run (unit, integration, stress, ui)
function TestRunner:RunCategory(category)
    print(COLOR.WHITE .. "========================================" .. COLOR.RESET)
    print(COLOR.WHITE .. "  Running Category: " .. category .. COLOR.RESET)
    print(COLOR.WHITE .. "========================================" .. COLOR.RESET)

    state.results = {}

    for _, suite in ipairs(state.suites) do
        local hasTestsInCategory = false
        for _, test in ipairs(suite.tests) do
            if test.category == category then
                hasTestsInCategory = true
                break
            end
        end

        if hasTestsInCategory then
            print(COLOR.CYAN .. "\n" .. suite.name .. COLOR.RESET)

            -- Run beforeAll hooks
            for _, hook in ipairs(suite.beforeAll) do
                pcall(hook)
            end

            -- Run only tests in category
            for _, test in ipairs(suite.tests) do
                if test.category == category then
                    local result = RunTest(test)
                    table.insert(state.results, result)

                    -- Print result (same as RunSuite)
                    if result.status == "pass" then
                        if state.options.showPassed then
                            local icon = COLOR.GREEN .. "✓" .. COLOR.RESET
                            local duration = result.duration >= state.options.slowThreshold
                                and COLOR.YELLOW .. string.format(" (%.2fms)", result.duration) .. COLOR.RESET
                                or COLOR.GRAY .. string.format(" (%.2fms)", result.duration) .. COLOR.RESET
                            print("  " .. icon .. " " .. test.name .. duration)
                        end
                    elseif result.status == "fail" then
                        local icon = COLOR.RED .. "✗" .. COLOR.RESET
                        print("  " .. icon .. " " .. test.name)
                        print(COLOR.RED .. "    Error: " .. result.error .. COLOR.RESET)
                    elseif result.status == "skip" then
                        if state.options.showSkipped then
                            local icon = COLOR.YELLOW .. "○" .. COLOR.RESET
                            print("  " .. icon .. " " .. test.name .. COLOR.GRAY .. " (skipped)" .. COLOR.RESET)
                        end
                    end
                end
            end

            -- Run afterAll hooks
            for _, hook in ipairs(suite.afterAll) do
                pcall(hook)
            end
        end
    end

    self:PrintSummary()
end

--[[--------------------------------------------------------------------
    Reporting
----------------------------------------------------------------------]]

--- Print test summary
function TestRunner:PrintSummary()
    local passed = 0
    local failed = 0
    local skipped = 0
    local totalDuration = 0
    local slowTests = {}

    for _, result in ipairs(state.results) do
        if result.status == "pass" then
            passed = passed + 1
        elseif result.status == "fail" then
            failed = failed + 1
        elseif result.status == "skip" then
            skipped = skipped + 1
        end

        totalDuration = totalDuration + result.duration

        if result.status == "pass" and result.duration >= state.options.slowThreshold then
            table.insert(slowTests, result)
        end
    end

    local total = passed + failed + skipped

    print(COLOR.WHITE .. "\n========================================" .. COLOR.RESET)
    print(COLOR.WHITE .. "  Summary" .. COLOR.RESET)
    print(COLOR.WHITE .. "========================================" .. COLOR.RESET)

    if failed == 0 then
        print(COLOR.GREEN .. "  All tests passed! (" .. passed .. "/" .. total .. ")" .. COLOR.RESET)
    else
        print(COLOR.RED .. "  Tests failed: " .. failed .. "/" .. total .. COLOR.RESET)
    end

    print(COLOR.WHITE .. "  Total: " .. total .. COLOR.RESET)
    print(COLOR.GREEN .. "  Passed: " .. passed .. COLOR.RESET)
    print(COLOR.RED .. "  Failed: " .. failed .. COLOR.RESET)
    print(COLOR.YELLOW .. "  Skipped: " .. skipped .. COLOR.RESET)
    print(COLOR.WHITE .. "  Duration: " .. string.format("%.2fms", totalDuration) .. COLOR.RESET)

    -- Show slow tests
    if #slowTests > 0 then
        print(COLOR.YELLOW .. "\n  Slow tests (>" .. state.options.slowThreshold .. "ms):" .. COLOR.RESET)
        table.sort(slowTests, function(a, b) return a.duration > b.duration end)
        for i, result in ipairs(slowTests) do
            if i <= 5 then -- Show top 5
                print(COLOR.YELLOW .. "    " .. string.format("%.2fms", result.duration) .. " - " .. result.suiteName .. " > " .. result.name .. COLOR.RESET)
            end
        end
    end

    -- Show failed tests summary
    if failed > 0 then
        print(COLOR.RED .. "\n  Failed tests:" .. COLOR.RESET)
        for _, result in ipairs(state.results) do
            if result.status == "fail" then
                print(COLOR.RED .. "    ✗ " .. result.suiteName .. " > " .. result.name .. COLOR.RESET)
                print(COLOR.RED .. "      " .. result.error .. COLOR.RESET)
            end
        end
    end

    print(COLOR.WHITE .. "========================================" .. COLOR.RESET)
end

--- Get test results
--- @return TestResult[]
function TestRunner:GetResults()
    return state.results
end

--- Clear all registered tests and results
function TestRunner:Reset()
    state.suites = {}
    state.currentSuite = nil
    state.currentTest = nil
    state.results = {}
    state.hasFocusedTests = false
end

--- Set test runner options
--- @param options table - Options table
function TestRunner:SetOptions(options)
    for key, value in pairs(options) do
        state.options[key] = value
    end
end

--[[--------------------------------------------------------------------
    Assertions
----------------------------------------------------------------------]]

--- Compare two values for strict equality
--- @param expected any - Expected value
--- @param actual any - Actual value
--- @param message string - Optional error message
function Assert.Equals(expected, actual, message)
    if expected ~= actual then
        local msg = message or string.format("Expected %s to equal %s", tostring(actual), tostring(expected))
        error(msg, 2)
    end
end

--- Compare two values for inequality
--- @param a any - First value
--- @param b any - Second value
--- @param message string - Optional error message
function Assert.NotEquals(a, b, message)
    if a == b then
        local msg = message or string.format("Expected %s to not equal %s", tostring(a), tostring(b))
        error(msg, 2)
    end
end

--- Assert value is true
--- @param value any - Value to check
--- @param message string - Optional error message
function Assert.IsTrue(value, message)
    if value ~= true then
        local msg = message or string.format("Expected true but got %s", tostring(value))
        error(msg, 2)
    end
end

--- Assert value is false
--- @param value any - Value to check
--- @param message string - Optional error message
function Assert.IsFalse(value, message)
    if value ~= false then
        local msg = message or string.format("Expected false but got %s", tostring(value))
        error(msg, 2)
    end
end

--- Assert value is nil
--- @param value any - Value to check
--- @param message string - Optional error message
function Assert.IsNil(value, message)
    if value ~= nil then
        local msg = message or string.format("Expected nil but got %s", tostring(value))
        error(msg, 2)
    end
end

--- Assert value is not nil
--- @param value any - Value to check
--- @param message string - Optional error message
function Assert.NotNil(value, message)
    if value == nil then
        local msg = message or "Expected value to not be nil"
        error(msg, 2)
    end
end

--- Deep table comparison
--- @param expected table - Expected table
--- @param actual table - Actual table
--- @param message string - Optional error message
function Assert.TableEquals(expected, actual, message)
    local function deepCompare(t1, t2, path)
        if type(t1) ~= type(t2) then
            return false, path .. ": type mismatch (" .. type(t1) .. " vs " .. type(t2) .. ")"
        end

        if type(t1) ~= "table" then
            if t1 ~= t2 then
                return false, path .. ": " .. tostring(t1) .. " ~= " .. tostring(t2)
            end
            return true
        end

        -- Check all keys in t1
        for k, v in pairs(t1) do
            local newPath = path .. "." .. tostring(k)
            local match, err = deepCompare(v, t2[k], newPath)
            if not match then
                return false, err
            end
        end

        -- Check for extra keys in t2
        for k in pairs(t2) do
            if t1[k] == nil then
                return false, path .. "." .. tostring(k) .. ": unexpected key in actual"
            end
        end

        return true
    end

    local match, err = deepCompare(expected, actual, "table")
    if not match then
        local msg = message or ("Tables not equal: " .. err)
        error(msg, 2)
    end
end

--- Assert table contains value
--- @param tbl table - Table to search
--- @param value any - Value to find
--- @param message string - Optional error message
function Assert.Contains(tbl, value, message)
    if type(tbl) ~= "table" then
        error("First argument must be a table", 2)
    end

    for _, v in pairs(tbl) do
        if v == value then
            return
        end
    end

    local msg = message or string.format("Table does not contain %s", tostring(value))
    error(msg, 2)
end

--- Assert function throws an error
--- @param func function - Function to call
--- @param message string - Optional error message
function Assert.Throws(func, message)
    if type(func) ~= "function" then
        error("First argument must be a function", 2)
    end

    local success, err = pcall(func)
    if success then
        local msg = message or "Expected function to throw an error"
        error(msg, 2)
    end
end

--- Assert value is of specific type
--- @param value any - Value to check
--- @param expectedType string - Expected type name
--- @param message string - Optional error message
function Assert.TypeOf(value, expectedType, message)
    local actualType = type(value)
    if actualType ~= expectedType then
        local msg = message or string.format("Expected type %s but got %s", expectedType, actualType)
        error(msg, 2)
    end
end

--- Assert value is truthy (not nil and not false)
--- @param value any - Value to check
--- @param message string - Optional error message
function Assert.Truthy(value, message)
    if not value then
        local msg = message or string.format("Expected truthy value but got %s", tostring(value))
        error(msg, 2)
    end
end

--- Assert value is falsy (nil or false)
--- @param value any - Value to check
--- @param message string - Optional error message
function Assert.Falsy(value, message)
    if value then
        local msg = message or string.format("Expected falsy value but got %s", tostring(value))
        error(msg, 2)
    end
end

--- Assert number is greater than threshold
--- @param value number - Value to check
--- @param threshold number - Minimum value (exclusive)
--- @param message string - Optional error message
function Assert.GreaterThan(value, threshold, message)
    if type(value) ~= "number" or type(threshold) ~= "number" then
        error("Both arguments must be numbers", 2)
    end

    if value <= threshold then
        local msg = message or string.format("Expected %s to be greater than %s", tostring(value), tostring(threshold))
        error(msg, 2)
    end
end

--- Assert number is less than threshold
--- @param value number - Value to check
--- @param threshold number - Maximum value (exclusive)
--- @param message string - Optional error message
function Assert.LessThan(value, threshold, message)
    if type(value) ~= "number" or type(threshold) ~= "number" then
        error("Both arguments must be numbers", 2)
    end

    if value >= threshold then
        local msg = message or string.format("Expected %s to be less than %s", tostring(value), tostring(threshold))
        error(msg, 2)
    end
end

--- Assert string matches pattern
--- @param str string - String to check
--- @param pattern string - Lua pattern to match
--- @param message string - Optional error message
function Assert.Matches(str, pattern, message)
    if type(str) ~= "string" then
        error("First argument must be a string", 2)
    end

    if not str:match(pattern) then
        local msg = message or string.format("String '%s' does not match pattern '%s'", str, pattern)
        error(msg, 2)
    end
end

--- Assert table has specific length
--- @param tbl table - Table to check
--- @param length number - Expected length
--- @param message string - Optional error message
function Assert.Length(tbl, length, message)
    if type(tbl) ~= "table" then
        error("First argument must be a table", 2)
    end

    local count = 0
    for _ in pairs(tbl) do
        count = count + 1
    end

    if count ~= length then
        local msg = message or string.format("Expected table length %d but got %d", length, count)
        error(msg, 2)
    end
end

--[[--------------------------------------------------------------------
    Utility Functions
----------------------------------------------------------------------]]

--- Get list of all registered suites
--- @return table<number, TestSuite>
function TestRunner:GetSuites()
    return state.suites
end

--- Get current test statistics
--- @return table - Stats table with counts
function TestRunner:GetStats()
    local stats = {
        totalSuites = #state.suites,
        totalTests = 0,
        byCategory = {},
    }

    for _, suite in ipairs(state.suites) do
        for _, test in ipairs(suite.tests) do
            stats.totalTests = stats.totalTests + 1
            stats.byCategory[test.category] = (stats.byCategory[test.category] or 0) + 1
        end
    end

    return stats
end

--- Print all registered tests
function TestRunner:ListTests()
    print(COLOR.WHITE .. "Registered Tests:" .. COLOR.RESET)

    for _, suite in ipairs(state.suites) do
        print(COLOR.CYAN .. "\n" .. suite.name .. COLOR.RESET)
        for _, test in ipairs(suite.tests) do
            local icon = test.skip and COLOR.YELLOW .. "○" .. COLOR.RESET
                or test.focused and COLOR.BLUE .. "●" .. COLOR.RESET
                or COLOR.WHITE .. "•" .. COLOR.RESET
            local category = COLOR.GRAY .. " [" .. test.category .. "]" .. COLOR.RESET
            print("  " .. icon .. " " .. test.name .. category)
        end
    end

    local stats = self:GetStats()
    print(COLOR.WHITE .. "\nTotal: " .. stats.totalTests .. " tests in " .. stats.totalSuites .. " suites" .. COLOR.RESET)
end

--[[--------------------------------------------------------------------
    Example Usage (commented out - for reference)
----------------------------------------------------------------------]]

--[[

-- Example 1: Basic unit tests
TestRunner:Describe("TableUtil", function()
    TestRunner:It("should create a shallow copy", function()
        local original = { a = 1, b = 2 }
        local copy = TableUtil.Copy(original)

        Assert.NotEquals(original, copy, "Copy should be different table")
        Assert.TableEquals(original, copy, "Copy should have same contents")
    end, { category = "unit" })

    TestRunner:It("should merge two tables", function()
        local t1 = { a = 1, b = 2 }
        local t2 = { b = 3, c = 4 }
        local merged = TableUtil.Merge(t1, t2)

        Assert.Equals(1, merged.a)
        Assert.Equals(3, merged.b)
        Assert.Equals(4, merged.c)
    end, { category = "unit" })
end)

-- Example 2: Integration tests with hooks
TestRunner:Describe("VotingEngine", function()
    local session

    TestRunner:BeforeEach(function()
        session = CreateTestSession()
    end)

    TestRunner:AfterEach(function()
        session:Cleanup()
    end)

    TestRunner:It("should tally simple votes correctly", function()
        local votes = {
            { player = "Player1", response = "NEED" },
            { player = "Player2", response = "NEED" },
            { player = "Player3", response = "GREED" },
        }

        local result = session:TallyVotes(votes)

        Assert.Equals(3, result.totalVotes)
        Assert.Equals(2, result.tallies.NEED.count)
        Assert.Equals(1, result.tallies.GREED.count)
    end, { category = "integration" })

    TestRunner:It("should handle ranked choice voting", function()
        -- Implementation
    end, { category = "integration" })
end)

-- Example 3: Skipping and focusing
TestRunner:Describe("Performance Tests", function()
    TestRunner:It("should complete in under 100ms", function()
        local start = debugprofilestop()
        PerformExpensiveOperation()
        local duration = debugprofilestop() - start

        Assert.LessThan(duration, 100)
    end, { category = "stress", skip = true, skipReason = "Too slow in CI" })

    TestRunner:It("should handle 1000 items", function()
        -- This test is focused for debugging
        local items = GenerateFakeItems(1000)
        Assert.Length(items, 1000)
    end, { category = "stress", focus = true })
end)

-- Run tests
TestRunner:RunAll()
TestRunner:RunCategory("unit")
TestRunner:RunSuite("VotingEngine")
TestRunner:RunTest("VotingEngine", "should tally simple votes correctly")

]]--

--[[--------------------------------------------------------------------
    Standalone Test Registration

    Test files that use their own assertion helpers (not Describe/It)
    register via RegisterTest(name, func). These are invoked by name
    via /lt test run <name>.
----------------------------------------------------------------------]]

--- @type table<string, function>
local standaloneTests = {}

--- Register a standalone test function
--- @param name string - Test name (used in /lt test run <name>)
--- @param func function - Test function, returns passed, failed counts
function TestRunner:RegisterTest(name, func)
    assert(type(name) == "string", "Test name must be a string")
    assert(type(func) == "function", "Test function must be a function")
    standaloneTests[name] = func
end

--- Run a standalone test by name
--- @param name string - Test name
function TestRunner:RunRegisteredTest(name)
    local func = standaloneTests[name]
    if not func then
        print(COLOR.RED .. "[TestRunner] Standalone test not found: " .. tostring(name) .. COLOR.RESET)
        print(COLOR.WHITE .. "Available standalone tests:" .. COLOR.RESET)
        for testName in pairs(standaloneTests) do
            print("  " .. COLOR.CYAN .. testName .. COLOR.RESET)
        end
        return
    end

    local success, p, f = pcall(func)
    if not success then
        print(COLOR.RED .. "[TestRunner] Test '" .. name .. "' crashed: " .. tostring(p) .. COLOR.RESET)
    end
end

--- List all registered standalone tests
function TestRunner:ListRegisteredTests()
    print(COLOR.WHITE .. "Registered Standalone Tests:" .. COLOR.RESET)
    local names = {}
    for name in pairs(standaloneTests) do
        names[#names + 1] = name
    end
    table.sort(names)
    for _, name in ipairs(names) do
        print("  " .. COLOR.CYAN .. name .. COLOR.RESET)
    end
end

--- Run all standalone tests
function TestRunner:RunAllRegistered()
    print(COLOR.WHITE .. "========================================" .. COLOR.RESET)
    print(COLOR.WHITE .. "  Loothing Standalone Tests" .. COLOR.RESET)
    print(COLOR.WHITE .. "========================================" .. COLOR.RESET)

    local totalPassed = 0
    local totalFailed = 0
    local names = {}
    for name in pairs(standaloneTests) do
        names[#names + 1] = name
    end
    table.sort(names)

    for _, name in ipairs(names) do
        local success, p, f = pcall(standaloneTests[name])
        if success then
            totalPassed = totalPassed + (p or 0)
            totalFailed = totalFailed + (f or 0)
        else
            print(COLOR.RED .. "[TestRunner] Test '" .. name .. "' crashed: " .. tostring(p) .. COLOR.RESET)
            totalFailed = totalFailed + 1
        end
    end

    print(COLOR.WHITE .. "\n========================================" .. COLOR.RESET)
    print(string.format("%sTotal Passed: %d%s  %sTotal Failed: %d%s",
        COLOR.GREEN, totalPassed, COLOR.RESET,
        COLOR.RED, totalFailed, COLOR.RESET))
    print(COLOR.WHITE .. "========================================" .. COLOR.RESET)
end

--[[--------------------------------------------------------------------
    Initialization
----------------------------------------------------------------------]]

print(COLOR.GREEN .. "[Loothing] TestRunner loaded" .. COLOR.RESET)
