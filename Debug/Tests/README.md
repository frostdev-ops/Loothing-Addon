# Loothing Test Suite

Comprehensive testing framework for the Loothing addon, including unit tests, integration tests, and stress tests.

## Test Files

### Core Test Infrastructure

- **TestHelpers.lua** - Shared testing utilities including:
  - Fake player/raid/council generation
  - Fake item generation with TWW/Dragonflight items
  - Vote simulation with various distributions
  - Session and scenario creation
  - State verification and assertions
  - Timing/performance utilities
  - Mock/spy utilities

- **TestRunner.lua** - Test execution framework with:
  - Suite management
  - Test lifecycle (setup/teardown)
  - Result reporting
  - Performance tracking

- **TestData.lua** - Test data fixtures and constants

### Unit Tests

- **ItemTests.lua** - Item data model tests
  - Item creation and initialization
  - State transitions
  - Vote management
  - Serialization/deserialization

- **VotingTests.lua** - Voting system tests
  - Vote submission and tracking
  - Vote tallying (simple and ranked choice)
  - Tie-breaking scenarios
  - Anonymous voting

- **SessionTests.lua** - Session management tests
  - Session lifecycle
  - Item management
  - State synchronization
  - Error handling

- **CommunicationTests.lua** - Network communication tests
  - Message encoding/decoding
  - Chunked message handling
  - Sync protocols
  - Version checking

### Integration Tests

- **IntegrationTests.lua** - End-to-end workflow tests
  - Full session workflows (start → add items → vote → award → end)
  - Multi-item sessions (5, 10, 50 items)
  - Ranked choice voting workflows
  - Auto-award workflows
  - Auto-pass workflows
  - Sync workflows (settings, history, MLDB)
  - Trade workflows
  - Error recovery scenarios

### Stress Tests

- **StressTests.lua** - Performance and stress tests
  - Large item counts (50, 100 items)
  - Large raid sizes (40 players)
  - Rapid operations (100 votes, 50 items)
  - Memory leak detection
  - Message volume handling
  - History performance (1000+ entries)
  - UI refresh performance

## Running Tests

### Quick Start

```lua
-- Enable test mode
/lt test

-- Run all tests
/lttest run

-- Run specific test suite
/ltintegtest run
/ltstress run
```

### Slash Commands

#### Main Test Runner
```lua
/lttest               -- List all test suites
/lttest run           -- Run all tests
/lttest [suite]       -- Run specific suite (item, voting, session, etc.)
/lttest list          -- List all available suites
```

#### Integration Tests
```lua
/ltintegtest          -- Run all integration tests
/ltintegtest list     -- List integration tests
/ltintegtest [name]   -- Run specific integration test
/ltit                 -- Short alias
```

#### Stress Tests
```lua
/ltstress             -- Run all stress tests
/ltstress list        -- List stress tests
/ltstress [name]      -- Run specific stress test
/ltst                 -- Short alias
```

### Test Mode

Test mode bypasses raid requirements and provides fake data:

```lua
/lt test              -- Toggle test mode
/lt test on           -- Enable test mode
/lt test off          -- Disable test mode
/lt test help         -- Show test mode commands

-- Test mode utilities
/lt test session      -- Start test session
/lt test add [N]      -- Add N fake items
/lt test vote         -- Simulate council votes
/lt test full         -- Full workflow test
```

## Writing Tests

### Basic Test Structure

```lua
local function Test_MyFeature()
    -- Setup
    TestHelpers:SetupTest()

    -- Test logic
    local result = MyFeature:DoSomething()

    -- Assertions
    Assert(result ~= nil, "Result should not be nil")
    AssertEqual(result.value, 42, "Value should be 42")

    -- Teardown
    TestHelpers:TeardownTest()
end
```

### Using Test Helpers

```lua
-- Create fake players
local player = TestHelpers:CreateFakePlayer()
local raid = TestHelpers:CreateFakeRaid(20)
local council = TestHelpers:CreateFakeCouncil(5)

-- Create fake items
local item = TestHelpers:CreateFakeItem()
local itemLink = TestHelpers:CreateFakeItemLink(212395)

-- Create fake votes
TestHelpers:CreateFakeVotes(item, {
    [LOOTHING_RESPONSE.NEED] = 3,
    [LOOTHING_RESPONSE.GREED] = 2,
    [LOOTHING_RESPONSE.PASS] = 1,
})

-- Create scenarios
local scenario = TestHelpers:CreateVotingScenario("tie")
local session = TestHelpers:CreateTestSession({
    itemCount = 5,
    memberCount = 20,
})
```

### Performance Testing

```lua
local metrics = NewPerfMetrics("My Operation", 100) -- 100ms threshold

for i = 1, 100 do
    local duration = Measure(function()
        MyModule:DoExpensiveOperation()
    end)
    RecordOp(metrics, duration)
end

PrintMetrics(metrics)
AssertPerf(metrics, "Operation should be under threshold")
```

### Assertions

```lua
-- Basic assertions
Assert(condition, "Error message")
AssertEqual(actual, expected, "Values should match")
AssertNotNil(value, "Value should exist")

-- Test helper assertions
TestHelpers:AssertItemState(item, LOOTHING_ITEM_STATE.AWARDED)
TestHelpers:AssertSessionState(session, LOOTHING_SESSION_STATE.ACTIVE)
TestHelpers:AssertVoteTally(item, LOOTHING_RESPONSE.NEED, 3)
TestHelpers:AssertWinner(item, "PlayerName-Realm")
```

## Test Categories

### Integration Tests

1. **Happy Path Workflow** - Standard success scenarios
2. **Multi-Item Sessions** - Handling multiple items in sequence
3. **Ranked Choice Workflow** - Instant runoff voting
4. **Auto-Award Workflow** - Automatic item distribution
5. **Auto-Pass Workflow** - Automatic pass restrictions
6. **Sync Workflow** - Settings and history synchronization
7. **Trade Workflow** - Trade queue integration
8. **Error Recovery** - Disconnect and error handling

### Stress Tests

1. **Large Item Count** - 50-100 items per session
2. **Large Raid Size** - 40-player raid simulation
3. **Rapid Operations** - Burst vote/item handling
4. **Memory Tests** - Leak detection and growth monitoring
5. **Message Volume** - Encoding/decoding performance
6. **History Tests** - Large history datasets
7. **UI Performance** - Frame refresh under load
8. **Timing Thresholds** - 16ms (60fps) critical operations

## Performance Thresholds

| Category | Threshold | Description |
|----------|-----------|-------------|
| Critical | 16ms | 60fps operations (UI updates, event handlers) |
| Acceptable | 100ms | General operations (votes, state changes) |
| Slow | 500ms | Bulk operations (history export, large syncs) |

## Test Data

### Test Item IDs

The test suite uses real WoW item IDs from current content:

- **The War Within S1** - Nerub-ar Palace raid items
- **Dragonflight S4** - Aberrus and Vault items
- **Mythic+ Items** - TWW Season 1 dungeon drops

Categories: weapons, armor (head/shoulder/chest), trinkets

### Fake Player Generation

- 13 classes with accurate spec data
- Role-appropriate assignments (tank/healer/DPS)
- Realistic name generation
- Configurable raid compositions

## Continuous Integration

Tests can be automated via:

```lua
-- Run all tests and report results
local passed, failed, skipped = LoothingTests:RunAll()

-- Generate report
LoothingTests:GenerateReport("text") -- or "json"

-- Exit with status code
if failed > 0 then
    error("Tests failed")
end
```

## Troubleshooting

### Tests Failing

1. **Enable test mode**: `/lt test on`
2. **Clear state**: `TestHelpers:CleanupAll()`
3. **Check dependencies**: Ensure Loolib is loaded
4. **Verify item data**: Some tests require item cache

### Performance Issues

1. **Disable addons**: Test with minimal addon set
2. **Check frame rate**: Use `/frameratecap 60`
3. **Review thresholds**: Adjust for your hardware
4. **Profile operations**: Use debugprofilestop()

### Memory Leaks

1. **Force GC**: `collectgarbage("collect")`
2. **Monitor growth**: Run memory tests in isolation
3. **Check cleanup**: Verify teardown functions
4. **Review references**: Use WeakTables for caches

## Contributing

When adding new tests:

1. Follow existing naming conventions (`Test_FeatureName`)
2. Include setup/teardown
3. Add assertions with clear messages
4. Document test purpose and scenarios
5. Add to appropriate test suite
6. Update this README

## Test Results

Test results include:

- Total tests run
- Passed/Failed/Skipped counts
- Assertion counts
- Execution time per test
- Performance metrics (min/max/avg/p95/p99)
- Memory usage deltas

Example output:

```
[1/15] Running: Full Session Workflow
  ✓ PASSED (12 assertions, 45.23ms)

[2/15] Running: 40-Player Raid
  ✓ PASSED (8 assertions, 123.45ms)
  Performance Metrics:
    Vote Processing: Min 0.12ms, Max 2.34ms, Avg 0.89ms, P95 1.56ms
```

## License

Tests are part of the Loothing addon and follow the same MIT license.
