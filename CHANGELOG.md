# Changelog

All notable changes to Loothing will be documented in this file.

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
