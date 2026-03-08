# Changelog

All notable changes to Loothing will be documented in this file.

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
