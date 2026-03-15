# Changelog

All notable changes to Loothing will be documented in this file.

## [1.2.7] - 2026-03-15

### Added

#### Comm-Based Profile Sharing (`Core/SettingsExport.lua`, `Comm/MessageHandler.lua`, `Comm/Handlers/Core.lua`, `Core/Options/ProfileOptions.lua`)

- Added direct profile sharing over addon comm using the same printable settings export string as manual export/import
- Shared imports now land in the existing confirmation modal, so receivers choose `Create New Profile` or `Apply to Current` before anything is written
- Added an online group-member target selector and `Share` action to the Profiles options panel

#### Shared Export Codec (`../Loolib/Comm/ExportCodec.lua`)

- Added a reusable export codec to Loolib so printable table exports use one serializer/compressor path instead of duplicating the pipeline in addon code

#### Export Decoder Utility (`tools/decode_export.py`)

- Added a Python CLI that decodes both settings exports and compact loot exports outside the game client

### Fixed

#### Decoder Table Semantics (`tools/decode_export.py`)

- Empty Lua tables now decode to JSON objects by default instead of empty arrays, which better matches map-like settings payloads

### Documentation

- Updated visible version references to `1.2.7` in `README.md`, `Loothing.toc`, `Loothing-Dev.toc`, and export metadata fixtures

## [1.2.5] - 2026-03-12

### Changed

#### Session Trigger Policy Refactor (`Core/Constants.lua`, `Core/SettingsVoting.lua`, `Data/Session.lua`)

- Replaced the single `sessionTriggerMode` setting with a split policy model:
  - **`sessionTriggerAction`**: `manual` | `prompt` | `auto` — what happens on an eligible boss kill
  - **`sessionTriggerTiming`**: `encounterEnd` | `afterLoot` — when the action fires relative to the kill
  - **Encounter scope toggles**: `sessionTriggerRaid` (default on), `sessionTriggerDungeon` (default off), `sessionTriggerOpenWorld` (default off)
- `OnEncounterEnd` now gates on instance type: PvP, arena, and scenario encounters are always rejected; raid/dungeon/open-world are controlled by the scope toggles (test mode bypasses the scope gate)
- Extracted `ClassifyEncounterScope()`, `IsScopeEnabled()`, and `ApplyTriggerAction()` as focused helpers on `SessionMixin`
- afterLoot timing now uses `ApplyTriggerAction()` (respects action=auto for direct start after debounce, not just prompt)
- Default behavior is unchanged: prompt + encounterEnd + raid-only

#### Settings UI (`Core/Options/SessionSettings.lua`)

- Replaced the single "Session Trigger Mode" dropdown with two dropdowns (Action, Timing) and three scope toggles (Raid, Dungeon, Open World) under a "Session Trigger" header
- Added help text noting PvP/arena/scenario exclusion and raid-only default

#### MLDB Sync (`Data/MLDB.lua`)

- Session trigger policy fields are now broadcast to raid members via MLDB (5 new compression keys: `sta`, `stt`, `str`, `std`, `stow`)
- `GatherSettings()` includes the split trigger fields; `ApplyFromML()` applies them through the validated setters

#### Locale (`Locale/enUS.lua`)

- Added 11 new locale strings for the split trigger controls (header, action, timing, scope labels and descriptions)

### Fixed

#### Migration and Profile Switch Safety (`Core/SettingsVoting.lua`)

- Lazy migration from legacy `sessionTriggerMode` to split fields on first access; legacy `GetSessionTriggerMode`/`SetSessionTriggerMode` remain as compatibility shims
- Removed instance-level migration flag that prevented migration from running after profile switches

#### Stale afterLoot Debounce on New Encounter (`Data/Session.lua`)

- `OnEncounterStart` now cancels any pending afterLoot debounce timer and resets the loot count, preventing stale state from a previous encounter from firing mid-combat

#### Cleanup Path State Reset (`Data/Session.lua`)

- `EndSession` and `OnSessionStartReceived` now correctly clear `lastEligibleEncounter` and legacy aliases

### Tests (`Debug/Tests/RollFrameSessionSettingsTests.lua`)

- Replaced all placeholder trigger-mode tests with behavioral tests covering scope classification, default policy, scope enable/disable, wipe rejection, active-session suppression, afterLoot ML-only filtering, afterLoot+auto direct start, manual caching, legacy migration round-trips, and MLDB compression round-trips
- Added constants validation for new `SessionTriggerAction`, `SessionTriggerTiming`, and `SessionTriggerScope` enums
- Updated integration tests to verify new split accessor methods and helper method existence

## [1.2.4] - 2026-03-12

### Added

#### Manifest-Driven Builder And Analyzer (`../builder.py`, `../package.sh`, `../Loolib/manifest.lua`)

- Replaced the old shell-heavy packager with a Python builder that now supports build, lint, analyze, and manifest inspection workflows
- Restored a dedicated `loothing` preset and aligned release packaging with Loothing’s real embedded Loolib runtime requirements

### Fixed

#### Embedded Loolib Runtime Hardening (`../Loolib/`)

- Pulled in the full Loolib hardening wave that stabilized all shipped families, including core lifecycle/data/event layers and the hardened UI families
- Resolved the reviewed `ui-appearance` frame-validation regression and the late-discovered `ui-canvas` sync/history edge cases before finalizing the release

#### Versioning And Release Metadata (`README.md`, `Loothing.toc`, `Loothing-Dev.toc`, `Debug/Tests/HistoryExportTests.lua`)

- Updated live version references to 1.2.4 across release docs, dev TOC metadata, and export test fixtures
- README installation notes now reflect packaged reality: the release zip embeds the required Loolib runtime subset, while standalone `Loolib/` is only needed for source-linked development

## [1.2.3] - 2026-03-11

### Fixed

#### Roster iLvl Sync And Display (`Comm/MessageHandler.lua`, `Modules/VersionCheck.lua`, `UI/RosterPanel.lua`, `Core/Init.lua`)

- Version replies now include the responder's equipped iLvl, active spec ID, and optional test-version tag so roster consumers can rebuild shared player metadata instead of only knowing the remote addon version
- `VersionCheck` now writes responder iLvl/spec data into `PlayerCache` using the live group unit GUID when available, restoring remote roster iLvl visibility for everyone viewing the roster tab
- The roster tab now falls back to version-query metadata if cache hydration has not completed yet, avoiding `?` rows while responses are still being processed
- Opening the roster tab now triggers the existing throttled group version refresh path, so remote iLvl data is requested when the panel is viewed instead of waiting for a separate roster-change event
- Manual raid/guild version queries now preserve previously known iLvl/spec metadata for online members until fresh responses arrive, preventing temporary roster iLvl flicker or accidental metadata loss during mixed-response queries
- Group roster updates now always rescope the live version snapshot back to the actual party/raid roster, so a prior solo guild query can no longer leave raid members outside the stale guild snapshot
- Guild queries no longer wipe persisted version-cache entries for offline or non-responding members before the query completes, preserving the intended cross-session version cache behavior
- Version responses now ignore malformed or secret sender names instead of risking a nil-index write into the version cache

#### History Export Reliability (`Data/History.lua`, `UI/HistoryPanel.lua`)

- JSON history export now escapes raw WoW pipe codes (`|c...|Hitem...`) as `\u007C`, so large exports render and copy correctly in WoW's export edit box instead of collapsing into formatted garbage
- JSON and compact/Web exports now include the original `itemLink` field alongside `itemID`/`itemName`, preserving full item-link fidelity for downstream imports
- Compact/Web export now preserves nested array data inside snapshot tables, including `councilVotes.responses`, instead of silently dropping non-scalar nested fields
- Large export dialogs now focus the export edit box automatically when shown, so the advertised `Ctrl+A`, `Ctrl+C` workflow works immediately without an extra click

### Tests

- Added `Debug/Tests/HistoryExportTests.lua` with regression coverage for pipe-safe JSON export, nested compact export serialization, and `itemLink` preservation

### Documentation

- Updated the addon data import guide to reflect the current 8 export formats, the JSON `{ metadata, entries }` envelope, and the restored `itemLink` field in exported entries

## [1.2.2] - 2026-03-10

### Added

#### Runtime Taint Audit And Diagnostics

- Added `Core/Diagnostics.lua` with a lightweight runtime audit that tracks:
  - `ADDON_ACTION_BLOCKED` / `ADDON_ACTION_FORBIDDEN` events
  - secure-state checks for `UnitGUID`, `NotifyInspect`, `UnitName`, `GetRaidRosterInfo`, `GetPlayerInfoByGUID`, `SlashCmdList`, and `StaticPopupDialogs`
  - unexpected `Loothing*` / `Loolib*` globals outside the explicit allowlist
- Added dev-only `/lt taint`, `/lt taint scan`, and `/lt taint clear` commands
- Diagnostics reuse the existing structured log buffer through the `TaintAudit` module name; no new SavedVariables were added

#### Winner Determination Settings (`Core/Options/SessionSettings.lua`)

New **Winner Determination** settings group in Session Settings:
- **Winner Mode** — `HIGHEST_VOTES` (auto-award top candidate), `ML_CONFIRM` (ML confirms from shortlist), `AUTO_HIGHEST_CONFIRM` (auto-select highest then show confirmation)
- **Tie Breaker** — `ROLL` (simulated random roll), `ML_CHOICE` (ML decides), `REVOTE` (force another vote round)
- **Auto-award on Unanimous** — automatically award when every council member votes for the same candidate
- **Require Confirmation** — show a confirmation dialog before the award is applied
- **Maximum Re-votes** slider (0–10); `VotingSession` now reads this at init instead of using a hardcoded value of 2

#### IRV Rounds Visualization (`UI/ResultsPanel.lua`)

When IRV (Instant-Runoff Voting) results include round data, the Results Panel shows a collapsible round-by-round breakdown:
- Toggle button below the response summary shows "Show IRV Rounds (N rounds)"
- Expanding the container shows per-round vote tallies and eliminations
- Candidate rows reflow correctly when the rounds container is toggled

#### Interactive Ranked Choice Display (`UI/VotePanel.lua`)

`CreateRankedDisplay` rewritten from a static text field to an interactive reorderable panel:
- Candidate rows can be dragged to reorder rankings
- Helper text enforces min/max rank constraints inline ("Rank at least 2 choices", "Maximum 5 ranks reached")
- Clear button resets all rankings instantly
- Locale lookups use safe fallbacks throughout

#### RCV-Aware Vote Button Labels (`UI/CouncilTable`)

Council table vote buttons and row click handler are now aware of voting mode:
- Button text shows **Rank** / **Ranked** (green) in `RANKED_CHOICE` mode, **Vote** / **Voted** in `SIMPLE` mode
- Clicking the Vote button in RCV mode opens the `VotePanel` for ranking instead of toggling a simple vote

### Fixed

#### Secret-Value And Unsafe Runtime Callers

- `Loolib/Data/SavedVariables.lua` now guards scope-key generation against secret or missing unit API returns, falling back to stable placeholder values instead of crashing on tainted paths
- `Loolib/Data/SavedVariables.lua` now waits for its actual saved-variable table before initializing on `ADDON_LOADED`, avoiding session-long attachment to a fresh empty table during unrelated addon loads
- `Core/Migration.lua` no longer rebuilds profile keys from raw `UnitName("player")`; it now uses `SafeUnitName("player")` while preserving the SavedVariables character-key format (`"Name - Realm"`)
- `Data/TradeQueue.lua` no longer makes the invalid `UnitName("NPC")` call when the trade recipient label is empty
- Production-loaded `Debug/TestMode.lua` now uses safe player-name accessors instead of raw `UnitName("player")`
- `Debug/TestMode.lua` once again routes `/lt test on|off|toggle` through the real simulator lifecycle while still honoring `TestModeState` prerequisite checks

#### Namespace And Global-Surface Cleanup

- Added the expected-global allowlist to diagnostics without tripping the architecture audit
- Removed the remaining repo-owned bare global factory exports from optional Loolib popup/canvas modules by keeping those factory functions local to their modules
- `Loolib/UI/Widgets/PopupMenu.lua` now preserves explicit `false` item values and propagates parent `OnSelect` callbacks into nested submenus
- Optional popup examples and the popup test harness now use `Loolib.UI` module exports instead of the removed bare globals

#### `CHAT_MSG_SYSTEM` Secret-String Crash (`Data/RollTracker.lua`, `UI/RollFrame/Events.lua`)

**Symptom**: `[Loolib Error] Callback error for event CHAT_MSG_SYSTEM : attempt to perform string conversion on a secret string value (tainted by 'Loothing')` — fired twice per death/system message in a raid.

**Root cause**: In WoW 12.0, hardware-protected system messages (player deaths, `[You died.]`) arrive as secret-valued strings. `tostring()` itself is a string-conversion operation that throws on secret strings in untrusted addon code. Two separate `Events.Registry` registrations (one in `RollTracker:Init()`, one in `Core/Init.lua`) both invoked `OnChatMessage`, doubling every error.

**Fix**:
- Added `if SecretUtil.IsSecretValue(text) then return end` guard before `tostring()` in both `RollTrackerMixin:OnChatMessage` and `RollFrameMixin:OnChatMessage`. Roll messages are never secret-valued, so legitimate rolls are unaffected.
- Removed the redundant `CHAT_MSG_SYSTEM` registration from `Core/Init.lua`; `RollTracker:Init()` self-registers and is the sole listener.
- Cached `local SecretUtil = Loolib.SecretUtil` at module level in both files to avoid repeated table traversal on a hot event path.

#### Loolib Note Modules: `SecretUtil` Wrappers (`Loolib/UI/Note/`)

`NoteRenderer.lua` and `NoteMarkup.lua` called `GetRaidRosterInfo()`, `UnitName()`, and `UnitClass()` without secret-value protection, creating taint risk on any tainted code path in combat.

- **`NoteRenderer.lua`** — `UpdateRaidRoster()`: replaced 7 raw API calls with `SecretUtil.SafeGetRaidRosterInfo()`, `SecretUtil.SafeUnitName()`, and `SecretUtil.SafeUnitClass()`
- **`NoteMarkup.lua`** — `UpdatePlayerContext()`: replaced 4 raw API calls with safe wrappers; consolidated the two `SafeUnitClass("player")` calls into one (`local _, classToken, classID = SecretUtil.SafeUnitClass("player")`); added `if not fullName then return end` guard to prevent `nil:match()` when the player name is secret

#### `GroupLootDisplay`: Taint-Safe Frame Removal (`Loot/GroupLootDisplay.lua`)

`GroupLootContainer_RemoveFrame(GroupLootContainer, frame)` is now wrapped in `pcall` so that if Blizzard secures or removes `GroupLootContainer` in a future patch, the error is silently swallowed rather than propagating up the call stack. The loot frame may remain visible in that edge case, which is preferable to an unhandled Lua error.

### Tests

- Added `Debug/Tests/VotingTests.lua` with coverage for winner-determination modes (highest-votes, ML-confirm, auto-confirm), tie-breaker selection, and unanimous auto-award logic
- Added `Debug/Tests/DiagnosticsTests.lua` to cover unexpected-global detection, allowlist handling, blocked-action capture, tracked-global secure-state/baseline reporting, missing-expected-global detection, and audit reset behavior
- Extended `Debug/Tests/SecretValueTests.lua` with regression coverage for SavedVariables scope-key fallbacks and migration profile-key lookup

### Validation

- `luac -p` passes on all edited Lua files
- `./lint.sh --audit` passes with 0 errors and 0 warnings

## [1.2.1] - 2026-03-10

### Performance

#### Web Export: Eliminated UI Freeze for Large History Sets

The "Web" export button previously caused a 10–60+ second UI freeze when exporting large history datasets (500+ entries). Three compounding bottlenecks were identified and resolved.

##### Compressor: Hash-Chain LZ77 (`Loolib/Comm/Compressor.lua`)

Replaced the naive `FindLongestMatch` (O(N × 32768) backward scan) with `FindLongestMatchHC`, a hash-chain implementation:
- 3-byte rolling hash maps each position into a 65536-bucket chain; walk capped at 64 steps
- Worst-case comparisons drop from `N × 32,768` to `N × 64` — **estimated 100–500× speedup** on typical JSON input
- Pre-computed reversed Huffman codes (`FIXED_LIT_REV/LEN`, `FIXED_DIST_REV/LEN`) eliminate a per-symbol bit-reversal loop — **~2–4× throughput** in the compression hot loop
- Pre-computed length/distance lookup tables (`LENGTH_CODE_LOOKUP_C/E`, `DIST_CODE_LOOKUP_C/E`) replace linear search through 30 base entries — **~5–15× improvement** per match-code lookup
- Pre-computed Base64 lookup table (`BASE64_LOOKUP[0..63]`) eliminates four `string:sub()` allocations per 3-byte group in `EncodeForPrint`

##### Compact JSON Serialiser (`Data/History.lua`)

New `ExportCompactJSON()` replaces the recursive `toJSON()` used by `ExportCompact()`:
- Fixed `string.format` template covers all 36 fields per entry — no recursion, no intermediate table allocation, no key sorting, no indentation
- **Estimated 3–10× faster** JSON serialisation; combined with compressor gains, Web export for 2000 entries is projected to drop from 10–60 s to under 1 s
- `ExportCompact()` updated to use compression level 6 (level 9 was previously a no-op)

##### Large-Export EditBox Routing (`UI/HistoryPanel.lua`)

WoW's `MultiLineEditBox` layout pass freezes the frame for inputs larger than ~40 KB:
- Added `GetOrCreateHugeExportFrame()` — lazy singleton 700×80 frame with a single-line `EditBox` that skips the full layout pass, rendering any-size string instantly
- `SetExportText(text)` routes by size: ≥40 KB → single-line frame; <40 KB → existing scrollable editBox
- All 8 format buttons and the default CSV load route through `SetExportText`

## [1.2.0] - 2026-03-09

### Changed

#### Complete Namespace Migration to Loolib Interface Model
Loothing no longer creates any `Loothing*`, `CreateLoothing*`, or `Loothing_*` runtime globals. All addon code now resolves shared state through the `ns` (addon namespace) table, with Loolib owning all Blizzard-facing integration points.

##### Bootstrap Shim Removed
- **`Core/Bootstrap.lua`**: Removed the 77-line `_G` metatable proxy that intercepted reads/writes to `Loothing*` globals. Bootstrap now contains only the 9-line namespace setup: `ns.Locale`, `ns.Addon`, and `Addon.Locale`/`Addon.ns`.
- **`ns.GlobalSymbols`** table eliminated — no code references it.

##### Core Namespace Conversions (16 files)
- `LoothingUtils` → `ns.Utils` (local alias `Utils`) — 49 consumer files migrated
- `LoothingSettingsMixin` → `ns.SettingsMixin` (~250 refs in Settings.lua)
- `LoothingSessionMixin` → `ns.SessionMixin` (~71 refs in Session.lua)
- `LoothingMLDBMixin` → `ns.MLDBMixin`, `CreateLoothingMLDB` → `ns.CreateMLDB`
- `LoothingClassColors` → `ns.ClassColors`
- `LoothingResponseManager` → `ns.ResponseManager`
- `LoothingItemFilter` → `ns.ItemFilter`
- `LoothingAutoAward` → `ns.AutoAward`
- `LoothingAnnouncer` → `ns.Announcer`
- `LoothingOptionsTable` → `ns.OptionsTable`

##### Data Layer Conversions (17 files)
- `LoothingItemDataMixin` → `ns.ItemDataMixin` (~64 refs)
- `LoothingCandidateDataMixin` → `ns.CandidateDataMixin` (~73 refs)
- `LoothingVoteDataMixin` → `ns.VoteDataMixin` (~61 refs)
- `LoothingCandidateMixin` → `ns.CandidateMixin`
- `LoothingCandidateCollectionMixin` → `ns.CandidateCollectionMixin`
- `LoothingVoteMixin` → `ns.VoteMixin`
- `LoothingHistoryMixin` → `ns.HistoryMixin`
- `LoothingTradeQueueMixin` → `ns.TradeQueueMixin`
- `LoothingItemStorageMixin` → `ns.ItemStorageMixin`
- `LoothingPlayerCacheMixin` → `ns.PlayerCacheMixin`
- `LoothingRollTrackerMixin` → `ns.RollTrackerMixin`
- `LoothingEncounterData` → `ns.EncounterData`
- `LoothingTrinketData` → `ns.TrinketData`
- `_G.LoothingTokenTable` → `ns.TokenTable`, `_G.LoothingTokenIlvls` → `ns.TokenIlvls`

##### Communication Layer Conversions (7 files)
- `LoothingCommMixin` → `ns.CommMixin`
- `LoothingProtocolMixin` → `ns.Protocol`
- `LoothingWhisperHandlerMixin` → `ns.WhisperHandlerMixin`
- `LoothingAckTrackerMixin` → `ns.AckTrackerMixin`
- `LoothingSyncMixin` → `ns.SyncMixin`
- `LoothingRestrictionsMixin` → `ns.RestrictionsMixin`

##### Council & Loot Conversions (6 files)
- `LoothingVotingEngine` → `ns.VotingEngine`
- `LoothingVotingSessionMixin` → `ns.VotingSessionMixin`
- `LoothingAutoPass` → `ns.AutoPass`

##### UI Layer Conversions (28 files)
- All UI mixin/factory exports moved to `ns.*` (SessionPanel, RollFrame, CouncilTable, TradePanel, RosterPanel, HistoryPanel, MainFrame, VotePanel, Skinning, Filters, etc.)
- All `CreateLoothing*` factory functions renamed to `Create*` on `ns`
- `LoothingUI_*` helper functions renamed (e.g., `CreateCandidateResultRow`, `CreateResponseRow`)

##### Debug & Test Conversions (15 files)
- `LoothingTestMode` → `ns.TestMode` (dev-only export; production uses `ns.TestModeState`)
- `LoothingTestRunner` → `TestRunner` (global, no `Loothing` prefix)
- `LoothingTestHelpers` → `TestHelpers` (global)
- `LoothingAssert` → `Assert` (global)
- Updated user-facing print messages to reference new API names

##### Compat.lua Cleanup
- `function Loothing.GetLootMethod()` → `function Addon.GetLootMethod()` (uses `local Addon = ns.Addon`)
- `function Loothing.GetLootRollItemData()` → `function Addon.GetLootRollItemData()`

##### Validation
- All 104 Lua files pass `luac -p` syntax validation
- `lint.sh` passes with 0 new errors, 0 new warnings
- Static grep confirms zero `Loothing[A-Z]` identifiers in executable code (only in comments and string literals for stable WoW/UI identifiers)

### Migration Notes
- **SavedVariables**: Uses `LoolibDB` as the sole SavedVariables root.
- **WoW frame names**: String literals like `"LoothingMainFrame"`, `"LoothingRollFrame"`, `"LoothingCouncilTable"`, `"LoothingAutoAwardTooltip"`, `"LoothingAutoPassTooltip"` are intentionally preserved — these are WoW UI frame names that must remain stable.

## [1.1.8] - 2026-03-09

### Added

#### `LoolibSecretUtil` — Library-level secret value handling
WoW 12.0 introduced "secret values" — opaque Lua values returned by unit APIs (`UnitName`, `UnitClass`, `GetRaidRosterInfo`, `GetPlayerInfoByGUID`) on tainted execution paths during combat. Any operation (`==`, `string.find()`, `#`, table key) on a secret value errors. The `issecretvalue(value)` global detects them.

v1.1.8 initially added `LoothingUtils.IsSecretValue()` and `LoothingUtils.SecretsForPrint()` at the addon level. This release **elevates** that functionality into Loolib as `LoolibSecretUtil` — a proper reusable module any Loolib consumer can use — then migrates all 14+ Loothing files to the library version.

##### Core Detection Functions
- **`LoolibSecretUtil.IsAvailable()`**: Returns `true` if `issecretvalue` global exists (WoW 12.0+)
- **`LoolibSecretUtil.IsSecretValue(...)`**: Variadic check — returns `true` if any argument is a WoW secret value. No-op when `issecretvalue` is unavailable
- **`LoolibSecretUtil.SecretsForPrint(...)`**: Replaces secret values with `"<secret>"` for safe output. Passthrough when `issecretvalue` is unavailable
- **`LoolibSecretUtil.Guard(value, fallback?)`**: Returns `fallback` (default `nil`) if value is secret
- **`LoolibSecretUtil.GuardToString(value, placeholder?)`**: Returns `tostring(value)` or `placeholder` (default `"<secret>"`) if secret

##### Safe Unit API Wrappers
- **`LoolibSecretUtil.SafeUnitName(unit, showServerName?)`**: Wraps `UnitName`/`GetUnitName` — returns `nil, nil` when name is secret
- **`LoolibSecretUtil.SafeUnitClass(unit)`**: Wraps `UnitClass` — replaces secret returns with `nil`
- **`LoolibSecretUtil.SafeGetRaidRosterInfo(index)`**: Wraps `GetRaidRosterInfo` — returns `nil` when name is secret, guards class/fileName/zone
- **`LoolibSecretUtil.SafeGetPlayerInfoByGUID(guid)`**: Wraps `GetPlayerInfoByGUID` — returns `nil` when name is secret, guards class/race/realm

##### Module Registration
- **`Loolib/Utils/SecretUtil.lua`** (NEW): ~182 lines, registered via `Loolib:RegisterModule("SecretUtil", LoolibSecretUtil)`
- **`Loolib/loolib.toc`**: Added `Utils\SecretUtil.lua` before `Utils\Transmog.lua` in the Utils section
- All functions are pre-12.0 compatible (early-return raw API results when `issecretvalue` is nil)

##### Backward Compatibility
- **`LoothingUtils.IsSecretValue`** and **`LoothingUtils.SecretsForPrint`** retained as thin delegates to `LoolibSecretUtil` equivalents
- **`Debug/Tests/SecretValueTests.lua`**: Added `LoolibSecretUtil` test suite (IsAvailable, IsSecretValue, SecretsForPrint, Guard, GuardToString) alongside existing delegation verification tests

### Changed

#### Migration from manual guards to `LoolibSecretUtil` safe wrappers (14 files)
All raw `UnitName`/`UnitClass`/`GetRaidRosterInfo`/`GetPlayerInfoByGUID` calls with manual `IsSecretValue` guards replaced with single `LoolibSecretUtil.Safe*` wrapper calls across the codebase:

- **`Core/Utils.lua`**: `GetPlayerFullName`, `NormalizeName`, `GetShortName`, `IsSamePlayer`, `GetRaidRoster`, `IsGuildGroup` — all migrated to `LoolibSecretUtil` calls
- **`Core/Init.lua`**: `DetermineML` raid/party branches, `Debug`/`Error`/`Print` varargs
- **`Core/SettingsVoting.lua`**: `GetMasterLooter` raid/party branches
- **`Core/AutoAward.lua`**: `FindDisenchanter`, `IsPlayerInRaid` (solo + loop)
- **`Comm/Handlers/Core.lua`**: `isGroupLeaderOrAssistant` raid/party branches
- **`Council/CouncilMembers.lua`**: `GetCurrentGroupMembers` party branch
- **`Modules/VersionCheck.lua`**: `GroupHasVersion`, `GetOutdatedMembers`, `GetCurrentRosterNames`, `Query`
- **`Data/Session.lua`**: `OnLootReceived` ownership check
- **`Data/PlayerCache.lua`**: `Get`, `GetOrCreate`, `FetchFromGUID`, `Invalidate`, `SplitNameRealm`
- **`Debug/ErrorHandler.lua`**: `CaptureError` defensive guard
- **`UI/RosterPanel.lua`**: `BuildUnitMap` all 3 branches
- **`UI/TradePanel.lua`**: `FindUnitIdForPlayer` group loop + target
- **`UI/VersionCheckPanel.lua`**: `QueryVersions` solo branch
- **`UI/SyncPanel.lua`**: `GetOnlineMembers` player name

### Fixed

#### Name-handling functions crash on secret values
- **`GetPlayerFullName()`**: `UnitName("player")` can return a secret value during combat on tainted paths. Now uses `SafeUnitName` and returns `nil` instead of crashing
- **`NormalizeName(name)`**: Secret name input caused `name:find("-")` to error. Now returns `nil` for secret inputs
- **`GetShortName(fullName)`**: Secret input caused `fullName:match()` to error. Now returns `nil` for secret inputs
- **`IsSamePlayer(name1, name2)`**: Either name being secret caused comparison crash. Now returns `false` for secret inputs
- **`GetRaidRoster()` raid branch**: Uses `SafeGetRaidRosterInfo` — secret names skip the roster entry
- **`GetRaidRoster()` party branch**: Uses `SafeUnitName`/`SafeUnitClass` — secret names skip the entry, secret class sets class fields to nil
- **`IsGuildGroup()`**: Raw `GetRaidRosterInfo` call migrated to `SafeGetRaidRosterInfo` with nil guard on name

#### ML detection crash on secret values during combat
- **`DetermineML()` in `Init.lua`**: Uses `SafeGetRaidRosterInfo`/`SafeUnitName` — nil name triggers ML retry
- **`GetMasterLooter()` in `SettingsVoting.lua`**: Uses `SafeGetRaidRosterInfo`/`SafeUnitName` — skips secret names

#### Comm handler crash on secret values
- **`isGroupLeaderOrAssistant()` in `Comm/Handlers/Core.lua`**: Uses `SafeGetRaidRosterInfo`/`SafeUnitName` — prevents combat-time message rejection crashes

#### AutoAward crash on secret values
- **`FindDisenchanter()`**: Uses `SafeUnitName(unit, true)` and `SafeGetRaidRosterInfo` — nil name safely handled by `note = publicNote or ""`
- **`IsPlayerInRaid()`**: Uses `SafeUnitName` for both solo check and group loop

#### UI panel crashes on secret values during combat
- **`BuildUnitMap()` in `RosterPanel.lua`**: All 3 `UnitName` calls replaced with `SafeUnitName`
- **`FindUnitIdForPlayer()` in `TradePanel.lua`**: Uses `SafeUnitName` with nil checks
- **`QueryVersions()` solo branch in `VersionCheckPanel.lua`**: Uses `SafeUnitName`/`SafeUnitClass`
- **`GetOnlineMembers()` in `SyncPanel.lua`**: Uses `SafeUnitName` — single call replaces raw API + guard

#### Council/module crashes on secret values
- **`GetCurrentGroupMembers()` in `CouncilMembers.lua`**: Uses `SafeUnitName`/`SafeUnitClass`
- **`GroupHasVersion()`/`GetOutdatedMembers()`/`GetCurrentRosterNames()`/`Query()` in `VersionCheck.lua`**: All migrated to `SafeGetRaidRosterInfo`/`SafeUnitName`
- **`OnLootReceived()` in `Session.lua`**: Uses `SafeUnitName` for ownership check

#### PlayerCache crashes on secret value inputs
- **`Get(nameOrGUID)`**: Early return `nil` via `LoolibSecretUtil.IsSecretValue`
- **`GetOrCreate(nameOrGUID)`**: Early return `nil` before creating entries with secret keys
- **`FetchFromGUID(guid)`**: Uses `SafeGetPlayerInfoByGUID` — replaces raw call + 3 manual guards
- **`Invalidate(nameOrGUID)`**: Early return `false` if input is secret
- **`SplitNameRealm(fullName)`**: Early return `nil, nil` if input is secret

#### Error handler crash on secret error messages
- **`CaptureError(msg)` in `ErrorHandler.lua`**: Uses `LoolibSecretUtil.IsSecretValue` for defensive guard

#### Debug/Print output safety
- **`Loothing:Debug()`**, **`Loothing:Error()`**, **`Loothing:Print()`** in `Init.lua`: Pass varargs through `LoolibSecretUtil.SecretsForPrint()`

## [1.1.7] - 2026-03-08

### Fixed

#### Taint-unsafe string method calls on event payloads
- **`CHAT_MSG_SYSTEM` roll parsing crashed during combat**: `RollFrame/Events.lua` called `text:match()` on the tainted event payload string, triggering "attempt to index local 'text' (a secret string value tainted by 'Loothing')" errors when another player `/roll`ed during combat. Fixed with `tostring()` detaint + `string.match()` global function call (same pattern as RollTracker fix in v1.1.6)
- **`CHAT_MSG_WHISPER` handler crashed during combat**: `WhisperHandler.lua` called `strtrim(message)`, `message:sub()`, `text:gmatch()`, and `parts[1]:lower()` on tainted event payload strings. Both `message` and `sender` are now detainted with `tostring()` at the handler entry point, making all downstream string operations safe
- **Defensive `string.sub()` in Announcer**: `Announcer.lua` used `text:sub(1, 40)` in a debug log inside `SendToChannel()`. While `text` is internally constructed (not from an event), changed to `string.sub(text, 1, 40)` for consistency with the project's taint-safe pattern

## [1.1.6] - 2026-03-08

### Fixed

#### Nil-realm crash on early addon load
- **`GetPlayerFullName()` crashed before PLAYER_LOGIN completed**: `GetNormalizedRealmName()` returns `nil` during early initialization (before PLAYER_LOGIN fires or on first load). The function naively concatenated `name .. "-" .. nil`, producing a Lua error that propagated up through `Session:IsMasterLooter()` → `SessionPanel:UpdateHeader()` → `MainFrame:Init()`, preventing the addon from loading at all
- **`NormalizeName()` had the identical crash**: Any call path that normalized a name without an existing realm suffix (roster building, ML detection, `IsSamePlayer()`) would also crash with a nil concatenation when both realm APIs returned nil
- **`PlayerCache` could store nil realm and crash on index key**: When `GetPlayerInfoByGUID` returned an empty realm and `GetNormalizedRealmName()` was also nil, the fallback assigned nil to `realmName`. A subsequent `byName[name .. "-" .. realmName]` index write then crashed identically
- **Fix (all three sites)**: Replaced bare `GetNormalizedRealmName()` with the nil-safe fallback chain `GetNormalizedRealmName() or GetRealmName() or ""`. An empty-string guard avoids a trailing `-` when both APIs return nil/empty. `PlayerCache:GetShortName()` same-realm comparison updated to use the same fallback so same-realm players aren't shown with a redundant realm suffix after first load

#### Removed stale temp file
- **`Core/Constants.lua.tmp`** (empty 1-line leftover) deleted from the repository

## [1.1.5] - 2026-03-08

### Added

#### Bulk Actions for SessionPanel Items
- **Multi-select support**: Ctrl+click to toggle individual items, Shift+click for range selection, plain click for single-select (backward compatible)
- **Bulk action bar**: Gold-tinted toolbar appears when 2+ items are selected, showing state-aware action buttons with counts: Start Vote (N), End Vote (N), Skip (N), Remove (N), Re-Vote (N), plus Select All / Deselect buttons and a right-aligned selection count label
- **Bulk action handlers**: Each button filters selected items by applicable state and calls existing Session methods. Destructive actions (Skip, Remove, Re-Vote) show `LoothingPopups:Confirm()` dialogs before executing
- **Bulk context menu**: Right-clicking a multi-selected row shows a context menu with state-filtered bulk actions via `MenuUtil.CreateContextMenu()`. Right-clicking an unselected row falls through to the normal single-item context menu
- **Selection pruning**: When items are removed/awarded during a session, stale GUIDs are automatically pruned from the selection set on the next `RefreshItems()` call
- **ItemRow `onContextMenu` callback**: New callback hook in `LoothingItemRowMixin:OnClick()` allows parent panels to intercept right-click before the default context menu fires (returns `true` to suppress default)
- **12 new locale strings** in `enUS.lua`: `BULK_START_VOTE`, `BULK_END_VOTE`, `BULK_SKIP`, `BULK_REMOVE`, `BULK_REVOTE`, `BULK_AWARD_LATER`, `DESELECT_ALL`, `N_SELECTED`, `REMOVE_ITEMS`, `CONFIRM_BULK_SKIP`, `CONFIRM_BULK_REMOVE`, `CONFIRM_BULK_REVOTE`

### Changed
- **SessionPanel selection model**: Replaced single `selectedItem` tracking with `selectedItems` (guid -> item map) plus `lastClickedGuid` for range selection. `selectedItem` is still set for backward compatibility when exactly 1 item is selected
- **Bulk bar visibility**: ML-only action buttons are hidden (not just disabled) for non-ML users. Select All / Deselect buttons remain visible for all users
- **Scroll frame anchor adjustment**: Scroll frame top anchor shifts down by 28px when the bulk bar is visible, matching the existing `ToggleFilterBar()` pattern

### Fixed

#### VotePanel Call Signature Mismatch (vote commit rejection)
- **Council votes were rejected by ML with "Rejected vote commit with invalid responses"**: `VotePanel:SubmitVote()` was calling `Session:SubmitVote(guid, playerName, playerClass, responses, note)` but `Session:SubmitVote` only accepts `(itemGUID, responses)`. The `responses` parameter in Session was receiving `playerName` (a string), causing `type(data.responses) ~= "table"` to reject every vote
- **Fix**: Removed unused `playerName` and `playerClass` locals from `VotePanel:SubmitVote()`; call is now `Session:SubmitVote(self.item.guid, responses)`

#### SESSION_END Rejected from ML After Heartbeat Timeout
- **Clients rejected SESSION_END from the ML with "Rejected SESSION_END from non-ML"**: `isMasterLooter()` in `Comm/Handlers/Core.lua` relied solely on `Session:GetMasterLooter()`, which returns `nil` after `EndSession()` clears `self.masterLooter`. When a heartbeat timeout ended the session before the SESSION_END message arrived, the ML check failed for all 18+ handler call sites
- **Fix**: `isMasterLooter()` now falls back to `Settings:GetMasterLooter()` when the session ML is nil, preserving authorization through the end-of-session window
- **Also fixed**: `Session:IsMasterLooter()` now uses `LoothingUtils.IsSamePlayer()` instead of `==` for cross-realm name comparison safety

#### MLDB Key Collision Corrupts Button Colors After Sync
- **Synced RollFrame/VotePanel buttons appeared white after MLDB broadcast**: `MLDB:ReplaceKeys()` recursed into ALL nested tables using the full compression/decompression map. Color tables `{r=0, g=1, b=0}` were corrupted during decompression because `DECOMPRESSION_KEYS["r"] = "reason"`, producing `{reason=0, g=1, b=0}` — the red channel was lost and all buttons rendered white
- **Fix**: Added `LEAF_KEYS` set marking `color`/`c` and `whisperKeys`/`wk` as leaf tables. `ReplaceKeys()` skips key replacement when entering a leaf subtable and propagates the `isLeaf` flag to all nested levels, preventing collision for the full leaf subtree

#### Vote Retraction from Non-ML Council Silently Failed
- **Non-ML council members could not retract votes**: `RetractAllVotes()` sends `{}` (empty responses) via `SendVoteCommit` to signal retraction, but `HandleRemoteVoteCommit` rejected any payload with `#data.responses == 0`
- **Fix**: Split the validation — non-table payloads are still rejected, but an empty table is now treated as a retraction: calls `item:RemoveVote(data.voter)` and broadcasts updated voter lists to the council (mirroring the ML-local retraction path). Added nil guard on `data.voter` to prevent spurious broadcasts when voter is absent

#### Loolib: Global LUA_WARNING Noise
- **Blizzard and third-party addon warnings appeared as "[Loolib ERROR]"**: `LoolibErrorHandlerMixin:OnLuaWarning()` captured all `LUA_WARNING` events globally (e.g., Blizzard's `EditModeManager.lua` trying to anchor `ChatFrame1` to the missing `LeftChatPanel` region in WoW 12.0), unlike `ADDON_ACTION_BLOCKED/FORBIDDEN` which filter by addon name
- **Fix**: `OnLuaWarning` now captures the call stack at warning time and only records the warning if any frame references `AddOns/Loolib/` or a registered Loolib-based addon path. Blizzard and unrelated third-party warnings are silently ignored

## [1.1.4-r2] - 2026-03-08

### Added

#### Bulk Add Items to Session
- **AddItemFrame now supports queuing multiple items before adding**: Previously, each item required opening the frame, adding one item, and the frame closing. Now items accumulate in a queue before being submitted all at once
- **Tab 1 (Enter Item)**: Paste/drag items one after another — each resolved item appends to a scrollable queue list with per-item remove buttons. Duplicate links are rejected. EditBox auto-clears after each successful queue
- **Tabs 2 & 3 (Recent Drops / From Bags)**: Rows now toggle multi-select on click instead of exclusive single-select. Selected rows highlight (`0.12, 0.12, 0.28`), deselected rows reset. Queue tracks all selected items across the list
- **Add button shows count**: Button text updates to "Add (N)" reflecting current queue size; disabled when queue is empty
- **Bulk add on submit**: `OnAddClick` loops over the queue, calling `Session:AddItem()` for each entry, then reports the total added count
- **Queue cleared on tab switch and frame open/close**: Prevents stale state from carrying across tabs or sessions
- **Stale resolve guard**: Added generation counter (`_resolveGen`) to `OnItemInputChanged` — only the most recent resolve callback is honored, preventing partial typing of item IDs from queuing intermediate items

### Fixed

#### Multi-Vote Bypass with `multiVote` Disabled
- **Wrong default fallback allowed multi-voting**: `Rows.lua` used `Settings:Get("voting.multiVote", true)` — the `true` fallback meant multi-vote was always allowed when the setting was absent. Replaced with the typed getter `Settings:GetMultiVote()` which defaults to `false`, matching `Constants.lua`

#### Self-Vote Never Enforced
- **`selfVote` setting had no effect**: The setting was defined, synced via MLDB, and configurable in the options UI, but never checked when casting votes. Added client-side guard in `OnVoteClick` that blocks self-votes with a user message, and visual feedback in `Columns.lua` that dims/disables the vote button for the player's own candidate row when `selfVote` is disabled

#### No Server-Side Vote Validation
- **ML accepted any vote payload**: `HandleRemoteVoteCommit` in `Session.lua` accepted multi-candidate responses even when `multiVote` was disabled, and never checked `selfVote`. Added ML-side enforcement: multi-vote payloads are truncated to the last vote when `multiVote` is off, and self-vote candidates are filtered from responses when `selfVote` is off

#### "Hide Vote Counts" Session Setting Not Working
- **Vote counts displayed regardless of `hideVotes` setting**: The `GetHideVotes()` check was only applied in `CouncilTable/Columns.lua`. Three other UI locations displayed vote counts unconditionally:
  - **ItemRow.lua** (VOTING state): Showed `"X Votes"` when timer expired, ignoring hideVotes
  - **ItemRow.lua** (TALLIED state): Always showed vote count text
  - **ResultsPanel.lua** (`SetItem`): Total votes summary always displayed in item header
  - **ResultsPanel.lua** (`UpdateWinnerSection`): Winner recommendation showed `"(X votes)"` suffix
- **Fix**: All four locations now check `Loothing.Settings:GetHideVotes()` with ML bypass (ML always sees counts). Non-ML council members see empty text when hideVotes is enabled

#### AddItemFrame Queue Desync on Filter Toggle
- **Tab 3 "Equipment Only" checkbox caused stale queue**: Toggling the checkbox called `RefreshBagList()` directly (not via `SelectTab`), which rebuilt all rows but left `itemQueue` populated with entries from destroyed rows. New rows started unselected while queue still held old data
- **Fix**: Both `RefreshBagList()` and `RefreshRecentDrops()` now wipe `itemQueue` and update the Add button when rebuilding rows

### Changed

#### MLDB Now Propagates All Session-Relevant Settings
- **Previously only voting + observer settings were synced**: MLDB broadcast only covered 8 voting flags, timeout, sort order, observer config, and responseSets. Council members used their own local values for everything else, causing inconsistent behavior across raid members
- **Now propagates**: `votingMode`, `autoPass` (full table), `autoAward` (full table), `awardReasons` (full table with reason definitions), `winnerDetermination` (mode, tieBreaker, autoAwardOnUnanimous, requireConfirmation), `announcements` (full table), `ignoreItems` (full table)
- **Key compression extended**: Added ~40 new compression codes to keep bandwidth impact minimal
- **Full table overrides on apply**: New settings categories use full table replacement in `ApplyFromML()` rather than per-field nil checks, ensuring no stale local values persist

## [1.1.4-r1] - 2026-03-08

### Fixed

#### ML Cannot See Session Controls (Production Bug)
- **`IsMasterLooter()` chicken-and-egg deadlock**: `Session:IsMasterLooter()` compared `self.masterLooter == playerName`, but `self.masterLooter` is only set inside `StartSession()`. Before any session starts it was always `nil`, so the method returned `false` even for the actual ML — the SessionPanel never showed the "Start Session" button, creating a deadlock where the ML couldn't start sessions
- **Fix**: Falls back to `Loothing.handleLoot == true` when `self.masterLooter` is `nil` (pre-session). During active sessions, behavior is unchanged since `self.masterLooter` is set. Verified safe across all 30+ callers

#### Taint Errors + TestMode Leak from Test Mocks
- **`IsInGroup` mock tainting Blizzard secure globals**: `MockSessionPermissions()` in SessionTests.lua replaced `IsInGroup` — a Blizzard secure global — with an addon function. Since tests execute at TOC load time and `It()` wraps in `pcall`, any test error before `RestoreSessionPermissions()` left the mock in place permanently, tainting all Blizzard unit frame code (health bars, nameplates, heal prediction showing "secret number value tainted by 'Loothing'" errors)
- **`LoothingTestMode` leak causing "not in a group" on Roster + phantom test mode on `/lt start`**: Mocking `LoothingTestMode.enabled = true` to bypass `IsInGroup()` had global side effects — `IsTestModeEnabled()` is checked by `GetRaidRoster()`, which then returned fake roster data instead of the real raid. If any test errored before restore, TestMode stayed on permanently
- **Fix**: Removed both `IsInGroup` and `LoothingTestMode` mocks entirely. Tests now only mock `Loothing.handleLoot` (addon-owned field with no side effects). Tests pass when in a group, fail gracefully via `pcall` when solo — no Blizzard globals tainted, no TestMode leaked

## [1.1.4] - 2026-03-08

### Fixed

#### Council Members Seeing ML Controls
- **Raid assistants incorrectly identified as Master Looter**: Council members who were raid assistants saw the full ML view — "You are Master Looter" text, End Vote/End Session/Add Item/Award buttons, per-item ML controls, and ML-only context menu options. Root cause: UI checked `LoothingUtils.IsRaidLeaderOrAssistant()` (returns `true` for any assistant) instead of `Loothing.Session:IsMasterLooter()`
- **Affected files**: SessionPanel (`UpdateHeader`, `UpdateFooter`, `RefreshItems`), ItemRow (`UpdateActionButton`, `OnActionClick` ×2, `ShowContextMenu`), ResultsPanel (`UpdateActionButtons`)
- **Sync guard hardened**: `BroadcastCouncilRoster`, `HandleObserverRoster`, and `HandleCouncilRoster` in Sync.lua now use `Session:IsMasterLooter()` instead of the assistant check, preventing non-ML assistants from broadcasting rosters or bypassing roster mirroring

#### Award Popup Z-Order
- **Award confirmation popup hidden behind ResultsPanel**: Both ResultsPanel and the Loolib Dialog used `SetFrameStrata("DIALOG")`. Modal dialogs (award confirmation) now elevate to `FULLSCREEN_DIALOG` strata in `LoolibDialogMixin:Show()`, guaranteeing they render above all `DIALOG`-strata frames
- **Modal overlay strata mismatch**: The darkened overlay behind modal dialogs stayed at `DIALOG` strata while the dialog itself was elevated. `UpdateModalOverlay()` now sets the overlay to `FULLSCREEN_DIALOG` when active and resets to `DIALOG` when hidden

#### History Panel UI
- **Filter bar overflow at default width**: Filter bar relocated from inside `historyPane` to top of the panel frame (`TOPLEFT (8,-8)` / `TOPRIGHT (-8,-8)` of main frame, height 28). Three-pane container now starts at `-40` offset, giving the filter bar ~580px instead of ~288px — eliminates button overflow at all supported frame sizes
- **Floating "Search..." label**: Removed the `FontString` label anchored above the search box (which extended outside the pane container boundary). Replaced with an inline placeholder pattern: EditBox shows grayed-out placeholder text when empty/unfocused, clears on `OnEditFocusGained`, restores on `OnEditFocusLost`
- **Visual disconnection between panes**: `listContainer` now anchors `TOPLEFT (0,0)` instead of `(0,-38)`, filling the entire right pane. All three panes now have consistent full-height visual treatment
- **Date/player pane button overflow**: `allDatesBtn` and date pool buttons reduced from 110px → 72px (fits 100px pane with 4px inset + 22px scrollbar). `allPlayersBtn` and player pool buttons reduced from 130px → 92px (fits 120px pane with 4px inset + 22px scrollbar). Prevents horizontal overflow clipping in both panes
- **Pane content width stale on resize**: Added `OnSizeChanged` handlers to `dateScroll` and `playerScroll` so `dateContent` and `playerContent` frame widths update correctly when the user resizes the MainFrame (matching the existing handler on `listContent`)
- **Placeholder suppression edge case**: Replaced string-equality guard (`if text == L["SEARCH"] then return end`) with a `_placeholderActive` boolean flag on the filter bar frame, eliminating the edge case where typing the exact placeholder string would silently prevent the search filter from firing
- **Nil-safe placeholder**: `L["SEARCH"]` now stored as `filterBar._placeholder` with `or "Search..."` fallback; all placeholder references in scripts and `ClearFilters` use this stored value, preventing a Lua error if a locale file is missing the key
- **`GetItemIcon` deprecated API**: Replaced `GetItemIcon(itemID)` with `C_Item.GetItemIconByID(itemID)` in `SetupHistoryRow`

## [1.1.3] - 2026-03-08

### Fixed

#### Loolib - Duplicate XML Template Registration
- **"Deferred XML Node already exists" errors when embedded Loolib loaded alongside standalone**: Replaced `Templates.xml` with `Templates.lua` containing 14 Lua init functions guarded by `_G.LOOLIB_TEMPLATES_VERSION`. LibStub guards Lua from double-loading; XML had no such guard mechanism, causing WoW's XML parser to unconditionally re-register named virtual templates
- **Affected templates**: LoolibPanelTemplate, LoolibCloseButtonTemplate, LoolibButtonTemplate, LoolibListItemTemplate, LoolibScrollableListTemplate, LoolibTabButtonTemplate, LoolibTabbedPanelTemplate, LoolibTooltipTemplate, LoolibDialogTemplate, LoolibModalOverlayTemplate, LoolibDropdownTemplate, LoolibDropdownMenuTemplate, LoolibDropdownMenuItemTemplate, LoolibInputDialogTemplate
- **Updated consumers**: Dialog.lua, Dropdown.lua, ScrollableList.lua, TabbedPanel.lua, Tooltip.lua factory functions now create frames with `BackdropTemplate` (or plain frame) + call `LoolibTemplates.Init*()` instead of referencing XML template names
- **Frame pools converted**: ScrollableList item pool and TabbedPanel tab button pool switched from `CreateLoolibFramePool` (XML template) to `CreateLoolibObjectPool` (Lua creator function) for default templates; consumer-provided XML templates still work via `SetItemTemplate()`
- **Redundant strata calls removed**: Cleaned up duplicate `SetFrameStrata` calls that were already set by init functions (Dialog modal overlay, Dropdown menu, Dropdown submenu)

### Added

#### History Export
- **Export metadata headers**: All 7 export formats now include addon name, version, date/time, character, realm, guild, and entry count
  - CSV/TSV: `# ` comment-prefixed header lines (parsers skip `#` lines)
  - Lua: `-- ` comment-prefixed header lines
  - BBCode: `[b]Loothing Data Export[/b]` block
  - Discord: Markdown-formatted header with `#` heading and `**bold**` fields
  - JSON: `"metadata"` object wrapping the `"entries"` array (`{ "metadata": {...}, "entries": [...] }`)
  - EQdkp: `<exportinfo>` XML section with guild, rank, date, time, and entry count
- **Shared metadata helpers**: `GetExportMetadata()` and `FormatCommentHeader()` eliminate duplicated guild/character/date logic across exporters
- **"Copy for Web Import" compact export** (`ExportCompact()`): One-click export producing a single opaque string for pasting into the web app
  - Format: `LOOTHING:1:<base64(zlib(json))>` — version-tagged, compressed, base64-encoded JSON
  - Uses Loolib's existing `CompressZlib` (level 9) and `EncodeForPrint` (standard base64) — no new dependencies
  - Inner JSON is the same `{ metadata, entries }` structure from `ExportJSON()`
  - Web-side decompression: `zlib.inflateSync(Buffer.from(payload, 'base64'))`
- **"Web" export button** in HistoryPanel export dialog — sits after EQdkp, before Select All
  - Export dialog widened from 500px to 580px to accommodate the 8th format button

### Fixed

#### History Import
- **Metadata headers broke CSV/TSV import**: `DetectFormat()` now skips `#`-prefixed comment lines when detecting format from the first line
- **Comment lines parsed as data rows**: `ParseDelimited()` filters out `#`-comment lines before processing, preventing metadata headers from appearing as malformed entries

### Changed
- **Loolib version bump**: TOC `1.0.0` → `1.1.3`, LibStub minor `1` → `2`, README updated
- **Loolib TOC**: `UI\Templates\Templates.xml` → `UI\Templates\Templates.lua`
- **Templates.xml deleted**: No longer needed — all templates defined in Lua

## [1.1.2] - 2026-03-07

### Changed
- **ResultsPanel ML candidate selection**: The ML can now click any candidate row to select them as the award recipient, replacing the old flow where Award always targeted the most-voted candidate (or forced a tie-breaker context menu for ties)
  - Winner is auto-selected (gold border) when the panel opens; clicking any other row transfers selection
  - Award button text updates dynamically to "Award to {name}" with auto-sizing width
  - Ties are now informational only (header shows "Tie: A, B") — no longer block the award flow
  - `ShowTieDialog()` removed; `ShowAwardReasonDropdown()` routes directly to the confirm dialog for the selected candidate
- **CandidateResultRow interactivity**: Rows are now `Button` frames with hover highlight (lightened backdrop), hand cursor on hover, and gold border when selected

### Fixed

#### UI
- **CouncilTable right-click hit area**: Right-clicking a candidate row only triggered the context menu in the narrow gap after the last cell. Cell frames now use `SetMouseClickEnabled(false)` + `SetMouseMotionEnabled(true)`, letting click events pass through to the row while preserving tooltip hover scripts. Row registers `RightButtonUp` via `RegisterForClicks` and handles both buttons in a single `OnClick` handler

## [1.1.1] - 2026-03-07

### Fixed

#### UI
- **ResultsPanel showed no meaningful information**: Replaced the response-type view (NEED: 3, GREED: 1) with a candidate-centric display showing each candidate's class-colored name, response, roll, council votes with percentage bar, and winner highlight. ML can now see WHO to award at a glance
- **ResultsPanel tie detection broken**: `ShowTieDialog()` checked `self.results.tiedCandidates` but `TallySimple` returned `tiedResponses`. Tie detection now reads directly from candidateManager — finds all candidates sharing the max vote count
- **Award popup appeared behind all frames**: `LoolibDialogMixin:Show()` never called `Raise()`, so dialogs rendered under sibling DIALOG-strata frames (CouncilTable, ResultsPanel, RollFrame). Added `self:Raise()` after `Show()`
- **ItemRow awarded layout overlap**: `winnerText` and `statusText` were both anchored to `actionButton`'s left, causing text overlap on awarded items. Awarded layout now chains: `nameText` → `winnerText` → `statusText` → `actionButton`(hidden)
- **Stale ML controls on pooled rows**: `ResetMLControls` now hides delete/Later controls when rows are recycled from the pool, preventing ghost controls from appearing on non-PENDING items
- **Hardcoded winnerText width**: Replaced `SetWidth(120)` with auto-size so longer character names are no longer truncated

#### Test Mode
- **`CreateFakeResults` key mismatch**: Stored vote tallies under `results.tallies` but `DisplayResults` checked `results.counts` — fixed key to `counts`
- **`CreateFakeResults` voter format**: Stored voters as `{name, class}` tables but `ResponseRow` called `GetShortName(voter)` expecting strings — voters now stored as plain name strings
- **`TallyActualVotes` same bugs**: Had identical `tallies`/voter-format issues as `CreateFakeResults` — fixed to use `counts` key and plain string voters
- **`ShowResultsPanel` empty display**: `/lt test results` created a bare item without candidates. Now calls `AddFakeCandidatesToItem()` and adds random council votes before display
- **Quick-test flow empty ResultsPanel**: `OnResponseSubmitted` (RollFrame → auto-tally → ResultsPanel) didn't populate candidateManager. Added `PopulateCandidateManagerFromVotes()` to bridge legacy vote data into the candidate system
- **StressTests ResultsPanel test**: `Test_ResultsPanelFortyVoters` now populates candidateManager with fake candidates and council votes before measuring refresh performance

#### Trade
- **Awarded items not queued for trade**: `Session.OnItemAwarded` was never wired to `TradeQueue`. Added bridge callback in `Init.lua` that calls `TradeQueue:AddToQueue()` when the local player is the looter, using `item.timestamp` for accurate 2-hour trade window tracking

#### Performance
- **Redundant layout work per row**: Reordered `RefreshItems` to call `ResetMLControls` before `SetItem`, eliminating a redundant `UpdateLayout` pass per row
- **UpdateLayout full-reset on every Refresh**: Added `_layoutAwarded` guard so anchor recalculation only runs when the awarded state actually changes

#### Cleanup
- **Duplicate anchor setup in CreateElements**: Removed initial anchor points overwritten by `ApplyDefaultLayout()` — canonical anchors now live solely in `ApplyDefaultLayout()`
- **Mixed line endings in ItemRow.lua**: Normalized to consistent `\n`

### Added
- **CandidateResultRow component** (`UI/Components/CandidateResultRow.lua`): New per-candidate row for the ResultsPanel. Shows class-colored name, response badge (checks both `LOOTHING_RESPONSE_INFO` and `LOOTHING_SYSTEM_RESPONSE_INFO`), roll value, council vote count with percentage bar, and gold winner glow. Follows the same `BackdropTemplate` structure as `ResponseRow`
- **ResultsPanel winner header**: Shows "Recommended: {name} ({votes} votes)", "Tie: {name1}, {name2}", or "No council votes cast" above the candidate rows
- **ResultsPanel response summary**: Compact colored line showing response distribution (e.g., "NEED: 3 | GREED: 1 | PASS: 2")
- **`LoothingTestMode:PopulateCandidateManagerFromVotes()`**: Bridges legacy vote data into candidateManager for the quick-test flow
- **Loot Count Columns**: Three new sortable columns in the CouncilTable showing how many items each candidate has already received:
  - **Won** (gold) — items won this session (`itemsWonThisSession`)
  - **Inst** (orange) — items won in this instance + difficulty, queried from History
  - **Wk** (light blue) — items won this week (since last weekly reset), queried from History
  - Columns appear after the +/- (ilvlDiff) column, before gear slots
  - Header tooltips explain each abbreviation on hover
  - All three columns are sortable and can be hidden via column visibility settings
  - History queries use a single O(H) cache pass per refresh, not per candidate
- `LoothingHistoryMixin:GetLastWeeklyResetTime()` — computes last weekly reset timestamp via `C_DateAndTime.GetSecondsUntilWeeklyReset()`
- `LoothingHistoryMixin:BuildPlayerCountCache()` — single-pass history scan returning per-player instance and weekly loot counts
- `LoothingCandidateMixin` now initializes `itemsWonInstance` and `itemsWonWeekly` fields (ephemeral, not serialized)
- Test mode generates random values for all three loot count columns
- **Roster Tab** (`UI/RosterPanel.lua`): New 4th tab in the MainFrame showing all group/raid members at a glance
  - Columns: online status dot, class icon + class-colored name, role icon, item level, Loothing version (color-coded green/orange/gray), council membership checkmark, loot history count, raid rank
  - All columns are sortable (click header to sort, click again to toggle asc/desc); offline players always sort to bottom
  - Summary header shows member/online/installed/council counts
  - Rich tooltip on hover shows spec, item level, subgroup, version details, council status, and loot history breakdown by response type
  - "Query Versions" button triggers VersionCheck with lazy callback registration (only subscribes on first use)
  - Empty state shown when not in a group
  - History counts use a single O(H) pass (not per-player) for efficient data gathering
  - Pooled row frames with proper `ClearAllPoints()` on child elements to prevent anchor accumulation on reuse
  - Column header buttons created once and repositioned on resize (no frame leaks)
  - Right-click context menu on roster rows with:
    - Toggle council membership (Add/Remove from Council)
    - Toggle observer status (Add/Remove as Observer)
    - Set/Clear Master Looter designation
    - Whisper player
    - Promote to Leader / Promote to Assistant / Demote (raid leader/assistant only)
    - Uninvite from group (raid leader/assistant only)
  - Master Looter indicator: gold `[ML]` tag displayed next to the current ML's name
  - Observer status shown in tooltip (light blue "Observer" line)
  - Council column uses `GetMembersInRaid()` for correct test mode + auto-include support
  - Item level sourced from `GetAverageItemLevel()` for local player (PlayerCache fallback for others)
  - Localized `TAB_ROSTER` + 13 roster keys in all 11 locale files
  - 8 new locale keys for context menu actions
- **Observer System Overhaul**: Complete replacement of the single `voting.observe` boolean with a full observer management system
  - **ML Observer Mode**: Master Looter can optionally observe (sees everything, manages sessions/awards, but cannot vote). Toggle in Session Settings
  - **Observer List**: ML-managed list of specific players who can observe voting sessions. Add/remove via roster right-click menu
  - **Open Observation**: Replaces old "Observe Mode" — when enabled, all raid members can observe (subject to permissions)
  - **Configurable Permissions**: Granular control over what observers can see: vote counts, voter identities, candidate responses, candidate notes. Council and ML always see everything
  - **Observer Sync**: Observer roster and permissions broadcast via OBSERVER_ROSTER comm message and included in late-join sync packets
  - New module: `Council/ObserverManager.lua` — observer list management, permission queries, remote roster support
  - New comm message: `OBSERVER_ROSTER` (ML → Raid) for observer list and permission sync
  - New settings: `observers.list`, `observers.openObservation`, `observers.mlIsObserver`, `observers.permissions.*`
  - MLDB compression keys for observer settings sync
  - 22 new locale strings across all 11 locale files
  - CouncilTable vote button uses `CanPlayerVote()` (council AND not ML-observer)
  - CouncilTable voter progress excludes ML when in observer mode
  - Response, notes, vote count, and voter identity columns permission-gated for observers
  - Backward compatible: old `voting.observe` kept in sync with `observers.openObservation`

## [1.1.0] - 2026-03-07

### Added
- **Silent Roll**: Every candidate response now includes a roll number. When a player submits a response without doing an explicit `/roll`, a random roll is generated silently (no chat broadcast) so the council frame roll column is always populated instead of showing "-".
  - RollFrame `SendResponse()` generates a fallback `math.random()` when `GetItemRoll()` returns nil
  - WhisperHandler `SubmitWhisperResponse()` generates a roll for whisper-based responses
  - Session `HandlePlayerResponse()` generates a ML-side defensive fallback for responses arriving without a roll (e.g., from older client versions)
  - Roll range respects the existing `rollFrame.rollRange` setting (default 1-100)
  - No new settings, toggles, or visual distinctions — silent rolls are indistinguishable from real rolls on the council frame

### Fixed

#### Security
- **ML spoofing via sync handlers (H2, H6)**: Added `isGroupMember(sender)` authorization guards to all 6 settings/history sync handlers and `HandlePlayerInfoResponse` — prevents non-group-members from injecting fake data
- **Award dialog targeting wrong player (H3)**: `ShowAwardDialog` was reading council voter names from `voters[1]` instead of the winning candidate — now uses `candidateManager:GetMostVoted()` with `.playerName`
- **Stale session on inactive sync (H4)**: `ApplySyncData` now calls `EndSession()` when the ML reports INACTIVE but the local client still has an active session, clearing stale items and UI
- **Tradability matching by link instead of GUID (H7)**: `HandleTradable`/`HandleNonTradable` now use 3-tier matching (GUID → itemID+looter → link+looter) to correctly handle duplicate drops

#### UI
- **CouncilTable Results button dead (H8)**: Fixed `Loothing.ResultsPanel` → `Loothing.UI.ResultsPanel` in click handler and visibility check
- **SessionPanel OnVote no-op (H9)**: Redirected from disabled `VotePanel` to `RollFrame`

#### Robustness
- **Remote council roster never cleared (M1)**: `EndSession()` now calls `ClearRemoteRoster()` so council membership doesn't persist across sessions
- **Cross-realm relay loop (M6)**: `HandleXRealm` rejects inner messages with command XREALM or BATCH to prevent recursive processing
- **History sync schema validation (M8)**: `HandleHistoryData` validates `itemLink` and `winner` fields before importing entries
- **CLOSED session state guards (M5)**: `AddItem()` and `StartVoting()` now reject mutations when session is CLOSED

### Changed
- **History auto-pruning (M4)**: Entries older than 180 days are automatically pruned on addon load via existing `DeleteByAge()`
- **Dynamic class bitmask (M7)**: `ALL_CLASSES_FLAG` computed from `CLASS_ID_TO_NAME` table length instead of hardcoded `0x1FFF`
- **VotingEngine iteration helper (L1)**: Extracted `EnumerateVotes()` helper, replacing 4 inline dual-mode iteration patterns
- **CountVotes fix (L4)**: Fallback path uses `#votes` instead of `ipairs` to handle tables with holes
- **StressTests API alignment (M3)**: Fixed `SetResults()` → `SetItem(item, results)` to match current `ResultsPanel` API
- **TOC updates (M2, M3)**: Added `RollFrameSessionSettingsTests.lua` to TOC; documented test file section for production toggling
- **Code style (L2, L3)**: Standardized `table.insert` → `t[#t+1]`; marked `ShowVotePanelForItem` and `EndVoting` as deprecated

## [1.0.1] - Initial tracked release
