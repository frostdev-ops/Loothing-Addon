# Loothing

A loot council addon for World of Warcraft 12.0+ (Midnight). Built on [Loolib](https://github.com/frostdev-ops/Loolib).

**Version**: 1.3.2 | **Interface**: 120000 | **License**: MIT

---

## Features

- **Council voting** — Designate council members who vote on each item. Votes are tallied in real time with percentage bars and a recommended winner
- **Candidate table** — Sortable columns for class, role, item level, equipped gear, response, roll, loot count (session / instance / weekly), and council votes
- **Session management** — Master Looter adds items, starts sessions, and awards loot with optional award reasons. Items can be queued for later
- **Observer system** — Granular observer permissions: ML-observer mode, per-player observer list, open observation for the whole raid. Configurable visibility of votes, voter identities, responses, and notes
- **Roster tab** — Full raid overview with version status, council membership, role, item level, and history counts. Right-click to manage council/observer/ML assignments
- **Trade queue** — Awarded items are automatically tracked for the 2-hour trade window
- **Loot history** — Per-player history with instance and weekly counts. Used to populate loot-count columns
- **Silent rolls** — Every response includes a roll value (auto-generated if the player doesn't `/roll`) so the council always has a tiebreaker
- **Whisper responses** — Players without the addon can respond via whisper
- **Version check** — Broadcasts addon version to the raid; Roster tab shows color-coded version status per player
- **Test mode** — Full in-game test harness (`/lt test`) with fake candidates, votes, and stress tests

---

## Requirements

- World of Warcraft 12.0+ (Midnight, Interface 120000)
- [Loolib](https://github.com/frostdev-ops/Loolib) (required dependency)

---

## Installation

1. Download the latest release zip
2. Extract `Loothing/` into your `World of Warcraft/_retail_/Interface/AddOns/` directory
3. Standalone `Loolib/` is only needed for source-linked development workflows; the release package embeds the required runtime subset automatically
4. Reload or launch the game

---

## Usage

Open the main window via the minimap button or `/lt`.

| Command | Description |
| --- | --- |
| `/lt` | Toggle main window |
| `/lt test` | Open test mode menu |
| `/lt version` | Print addon version |

**Setting up a session:**

1. Zone into a raid instance
2. The Master Looter opens Loothing and items appear automatically when looted
3. Start a session — candidates respond via the RollFrame or whisper
4. Council members vote in the CouncilTable
5. ML selects a winner in the ResultsPanel and clicks Award

---

## Slash Commands

- `/lt` — Toggle main frame
- `/lt test [subcommand]` — Test mode (see in-game menu)
- `/lt debug` — Toggle debug output

---

## License

MIT — see [LICENSE](LICENSE)
