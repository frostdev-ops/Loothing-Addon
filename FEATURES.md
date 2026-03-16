# Loothing — Feature Reference

**Version:** 1.2.8
**Target:** World of Warcraft 12.0+ (Midnight / Retail)
**Interface:** 120000
**Category:** Raid
**Dependency:** Loolib (custom addon library)
**License:** MIT

---

## Overview

Loothing is a full-featured **loot council addon** for WoW 12.0+. It manages the entire lifecycle of a loot session — from detecting boss kills and parsing loot, to collecting council votes, determining a winner, announcing the award, and persisting history — all over an encrypted, compressed addon-channel protocol.

It is built on **Loolib**, a custom mixin-based addon library, and uses Blizzard's native `C_*` namespace APIs throughout.

---

## Architecture

```
Core (Init, Settings, Utils)
 ├── Data Layer      (Session, History, Candidates, ItemData, PlayerCache, MLDB)
 ├── Council Layer   (CouncilManager, VotingSession, VotingEngine, Observers)
 ├── Comm Layer      (Protocol v3, MessageHandler, Sync, AckTracker, WhisperHandler)
 ├── Loot Layer      (GroupLoot, GroupLootEvents, GroupLootState)
 ├── UI Layer        (MainFrame + 12 panels/components)
 └── Debug Layer     (TestMode, ErrorHandler, 15 test suites)
```

---

## Core Systems

### Master Looter Detection
Loothing auto-detects the Master Looter role. On joining a raid group, it inspects `GetLootMethod()` and `GetRaidRosterInfo()`, with a configurable retry timer. State is tracked across reconnects and group changes. The ML flag gates all loot-handling behavior — non-ML members participate as voters or observers only.

### Session Trigger Modes
The session start behavior is configurable:

| Mode | Behavior |
|------|----------|
| `auto` | Loot session starts automatically when loot window opens |
| `prompt` | ML is prompted with a dialog before starting |
| `manual` | ML starts the session explicitly |
| `afterRolls` | Session starts after the group loot roll phase completes |

### Settings & Multi-Profile Support
All settings are stored in `LoolibDB` via Loolib's `SavedVariables` system. Data is split into two scopes:

- **Profile scope** — per-character preferences (voting mode, council list, response buttons, announcements, filters, etc.)
- **Global scope** — shared across profiles (loot history, trade queue, item storage, player GUID cache, migration state)

A metatable proxy on `self.db` ensures stale references always route to the active profile.

---

## Voting System

### Voting Modes

| Mode | Algorithm |
|------|-----------|
| **Simple** | Most votes wins; ties detected and flagged |
| **Ranked Choice** | Instant-runoff voting — candidates with fewest first-choice votes are eliminated in rounds until a majority is reached |

### Voting Session State Machine
Each item has its own `VotingSession` state machine:

```
PENDING → VOTING → TALLYING → DECIDED
                  ↓
               REVOTING (on tie or ML override)
```

- Configurable vote timeout (per-session override or global default)
- Up to 2 revotes allowed per item
- Countdown tick events emitted every second for UI display
- Results object contains: `winner`, `response`, `vote counts`, `isTie`, `tiedCandidates`

### Response Button Sets
Responses are fully configurable via named **response sets** (e.g., "Standard", "PvP", "Alt Run"). Each set defines:
- Button text and response text
- Color
- Icon
- Response ID (used in vote tallying and history)

The active set is selectable at runtime. Response metadata populates `LOOTHING_RESPONSE_INFO` globally.

### Voting Options
- **Hide votes** — council members cannot see others' votes in real time
- **Anonymous voting** — voters are not identified in the results view
- **Multi-vote** — council members may vote for more than one candidate
- **Require notes** — votes without a note field are rejected

---

## Council Management

### CouncilManager
Maintains the list of active council members. Members receive broadcast loot data and their votes are collected and tallied. Council membership is persisted per-profile.

### ObserverManager
Observers are raid members who receive the full loot UI (see items, candidates, results) but **do not vote**. Useful for leadership accountability or officer visibility without inflating vote counts.

### CouncilSettings
Per-council configuration: minimum rank, exclusion list, and dynamic roster update handling.

---

## Loot Handling

### Group Loot Integration
Loothing integrates with WoW's native group loot system. On each loot roll window, it can automatically cast a roll on behalf of the player based on item eligibility:

| Roll Type | Value |
|-----------|-------|
| Pass | 0 |
| Need | 1 |
| Greed | 2 |
| Disenchant | 3 |
| Transmog | 4 |

`GroupLootEvents`, `GroupLootState`, and `GroupLootDisplay` split concerns across event handling, state tracking, and UI display.

### Item Filter
Items can be excluded from loot sessions by item ID, quality, or slot. The `ItemFilter` module gates which items enter the session pipeline.

---

## Automation

### AutoPass
Automatically passes on items the player cannot use, based on:
- **Armor subtype** — class-to-armor compatibility table (Cloth/Leather/Mail/Plate)
- **Weapon type** — per-class weapon proficiency check
- **Trinket spec filtering** — via `TrinketData` spec-to-trinket mapping
- **Class restriction parsing** — reads class requirements from item tooltips
- **Transmog check** — passes if appearance is already known
- **Bitwise class flag system** — efficient multi-class restriction encoding

AutoPass behavior is configurable; it can be disabled globally or per item type.

### AutoAward
Automatically awards items to a designated player when they fall within a configurable quality range. Configuration:

- Enable/disable toggle
- Lower and upper quality thresholds (e.g., Uncommon → Rare)
- Optional BoE inclusion/exclusion
- Deduplication guard to prevent double-awards

---

## Communication (Protocol v3)

### Encoding Pipeline
```
Serialize(version, command, data)
  → Compress (level 3)
  → Adler-32 checksum appended (4-byte big-endian)
  → EncodeForAddonChannel (null-byte safe)
```

### Decoding Pipeline
```
DecodeForAddonChannel
  → Strip checksum → Decompress
  → Verify Adler-32 (mismatch = nil, message dropped)
  → Deserialize → { version, command, data }
```

Uses `LoolibSerializer` and `LoolibCompressor` from Loolib. All messages include the protocol version for forward-compatibility gating.

### Transport
`LoolibComm` handles chunking, throttling, and queuing over WoW's addon channel. Supported send modes:
- `Send()` — standard delivery
- `SendGuaranteed()` — with acknowledgment tracking
- `SendGuild()` — guild-channel broadcast
- `Broadcast*` — raid/party helpers

### AckTracker
Tracks guaranteed message acknowledgment. Unacknowledged messages can be retried or flagged as lost.

### Encounter Restrictions
During boss encounters, non-critical messages are queued and replayed after the encounter ends. This prevents communication congestion during combat without losing data.

### WhisperHandler
Raid members who don't have Loothing installed can still respond via whisper commands (e.g., `!need`, `!greed`, `!pass`). The ML receives these, maps them to response IDs, and auto-whispers a confirmation. Outgoing confirmations are suppressed from the chat frame.

---

## Sync System

Late joiners and reconnecting players automatically receive a full state sync from the ML:
- Active loot session data
- Current votes (if permitted by voting settings)
- Observer roster

Sync is request/response based with a configurable timeout. `OnSyncComplete`, `OnSyncFailed`, and `OnSyncProgress` callback events are fired throughout the process.

---

## Announcements

The `Announcer` module posts loot results to any WoW chat channel, with queuing during combat.

### Supported Channels
`RAID`, `RAID_WARNING`, `OFFICER`, `GUILD`, `PARTY`, `SAY`, `YELL`, `WHISPER`, and a `group` alias that resolves to `RAID` or `PARTY` contextually.

### Template Tokens
Announcement messages support dynamic substitution:

| Token | Value |
|-------|-------|
| `{item}` | Item link |
| `{winner}` | Winner player name |
| `{reason}` | Award response/reason |
| `{notes}` | Player notes |
| `{ilvl}` | Item level |
| `{type}` | Item type/slot |
| `{oldItem}` | Winner's currently equipped item in that slot |
| `{ml}` | Master Looter name |
| `{session}` | Encounter/session name |
| `{votes}` | Number of votes received |

---

## History

### Storage
All loot awards are persisted to `LoolibDB` in the global scope (shared across profiles). Each entry includes: timestamp, GUID, item link, winner, response, notes, encounter, voter data, and award reason.

A `LoolibDataProvider` backs the history list for reactive UI updates. Filter state (text search, winner, encounter name, date range) drives a separate filtered `DataProvider` view.

### CSV/TSV Import
Historical loot data from other addons (RCLootCouncil, etc.) can be imported via CSV or TSV. The import pipeline emits progress callbacks (`OnImportStarted`, `OnImportProgress`, `OnImportComplete`, `OnImportError`) and tracks import stats (imported, skipped, error counts).

---

## Version Management

`VersionCheck` queries all raid members for their installed Loothing version and caches results (persisted to `LoolibDB`). Features:
- Outdated member warnings (throttled to 60s between warnings)
- Roster check throttling (minimum 30s between full checks)
- `GroupHasVersion(minVersion)` — gate features behind a minimum group-wide version
- Test version (`tVersion`) support for pre-release builds without triggering outdated warnings

---

## UI Panels

| Panel | Purpose |
|-------|---------|
| **MainFrame** | Primary container and layout host |
| **SessionPanel** | Active loot session — item queue, start/stop controls |
| **CouncilTable** | Tabular council vote view with sortable columns |
| **RollFrame** | Candidate roll/response submission UI |
| **ResultsPanel** | Post-tally winner display with full vote breakdown |
| **HistoryPanel** | Searchable, filterable loot history list |
| **TradePanel** | Tracks trade-eligible awarded items and trade timers |
| **RosterPanel** | Raid roster with class, role, and council membership |
| **SettingsPanel** | Full settings UI (all option categories) |
| **SyncPanel** | Manual sync controls and status |
| **VersionCheckPanel** | Group version overview, outdated member list |
| **Minimap Button** | Addon compartment integration with click/enter/leave callbacks |

### Additional UI Components
- **IconPickerFrame** — searchable icon browser for response button customization
- **ResponseButtonSettingsFrame** — configure button text, color, icon per response set
- **Popups** — reusable confirmation/input dialog system
- **Filters** — column and content filter controls
- **Skinning** — visual skin management for all frames

---

## Data Tables

| File | Contents |
|------|----------|
| `TrinketData.lua` | Spec-to-trinket eligibility map |
| `TokenData.lua` | Token item ID → type code mapping |
| `EncounterData.lua` | Boss encounter name/ID data |
| `PlayerCache.lua` | GUID-keyed player info (class, role, spec) with persistence |
| `MLDB.lua` | ML database with compressed key storage |
| `ItemStorage.lua` | Awarded item trade-timer tracking |
| `TradeQueue.lua` | Pending trade queue with expiry |

---

## Localization

Loothing ships with translations for 10 locales:

| Locale | Language |
|--------|----------|
| `enUS` | English (base) |
| `deDE` | German |
| `esES` | Spanish |
| `ptBR` | Portuguese (Brazil) |
| `ruRU` | Russian |
| `frFR` | French |
| `itIT` | Italian |
| `koKR` | Korean |
| `zhCN` | Simplified Chinese |
| `zhTW` | Traditional Chinese |
| `brainrot` | Brainrot (novelty) |

---

## Debug & Testing

### TestMode
A sandboxed simulation mode for developing and testing without a live raid. Guards persistence writes behind `GuardPersistence()` to prevent test data from polluting the live database.

### ErrorHandler
Structured error capture and reporting. Wraps addon-level errors with context for easier diagnosis.

### Test Suite (15 files)

| Suite | Coverage |
|-------|----------|
| `SessionTests` | Session lifecycle, state transitions |
| `VotingTests` | Simple and ranked-choice tally algorithms |
| `ItemTests` | Item data parsing, filter logic |
| `CommunicationTests` | Encode/decode roundtrip, message routing |
| `ReconnectTests` | ML disconnect/reconnect state recovery |
| `RestrictionTests` | Encounter restriction queuing and replay |
| `TradeTimerTests` | Trade window tracking and expiry |
| `AutoPassTests` | Armor/weapon/trinket/class autopass logic |
| `MLDBTests` | Master Looter DB compression and retrieval |
| `IntegrationTests` | End-to-end loot flow scenarios |
| `StressTests` | High-volume message and session load |
| `RollFrameSessionSettingsTests` | Per-session setting override behavior |

---

## Loot Flow (End-to-End)

```
Boss kill detected
  → GroupLootEvents captures loot window
  → Items parsed through ItemFilter
  → ML prompted or session auto-starts
  → Loot table broadcast to council (via Protocol v3)
  → LootFrame displayed to candidates (response submission)
  → AutoPass auto-submits ineligible candidates
  → WhisperHandler collects non-addon responses
  → Voting timeout fires → VotingEngine:Tally()
  → Results broadcast → ResultsPanel updated
  → ML awards item → History entry persisted
  → Announcer posts to configured channels
  → TradePanel tracks tradable award window
```

---

## Slash Commands & Minimap

Loothing integrates with WoW's **Addon Compartment** (the compartment menu in the minimap area). Click opens the MainFrame; hover shows a tooltip summary. A dedicated minimap icon button is also available as an alternative access point.

---

*Built by James Kueller for WoW 12.0+ (Midnight). Powered by Loolib.*
