The in-game companion addon for [Loothing.xyz](https://loothing.xyz), a free guild management platform. Loot history, council decisions, and session data sync to your guild's dashboard on the web.

Having issues or suggestions? Head over to the [Loothing GitHub Issues](https://github.com/frostdev-ops/Loothing-Addon/issues) page!

## Requirements
**WoW 12.0+ (Midnight), retail only.** All dependencies are bundled.

## Group Loot
Since Dragonflight, raids use group loot only. Loothing handles this by having the group leader automatically need on loot while everyone else passes. Configurable to guild-only groups and per quality threshold.

All raid members should have Loothing installed for automatic rolling. If someone doesn't, they should pass manually and let the leader collect. If an item ends up with the wrong person, have them trade it to the leader or use `/lt add PlayerName [item]` to add it to the session manually.

## Features

- **Loot Council Automation** — Detects tradable items after boss kills and prompts the ML to start a session. Council members vote, raiders submit responses.
- **Dual Voting** — Simple Majority or Ranked Choice / Instant Runoff. Configurable tie-breaking (rolls, ML choice, revote).
- **Custom Response Buttons** — Two built-in sets (Need/Greed/Offspec/Transmog/Pass and BIS/Major/Minor/Sidegrade/Pass). Fully customizable text, colors, and count (1-10).
- **Custom Council** — Auto-include guild officers, raid leader, or specific members. Solo council mode available.
- **Real-Time Voting** — Live vote updates across the raid. Anonymous voting, hidden counts, self-voting restrictions, required notes.
- **Trade Distribution** — After awarding, the item owner sees who to trade to. Click to auto-trade when in range. Tracks bind-on-trade timers.
- **Whisper Support** — Raiders without the addon can whisper `!need`, `!greed`, `!pass` etc. to the ML.
- **Auto Pass** — Skips items your class can't equip. Optional auto-pass on weapons, BoE, transmog, and off-class trinkets.
- **Auto Award** — Auto-award items in a quality range to a designated player (e.g., disenchanter).
- **Loot History** — Full metadata logging (winner, reason, ilvl, votes, timestamp, encounter). CSV/TSV import/export. Guild sync.
- **Announcements** — Template-based award/item announcements with tokens (`{item}`, `{winner}`, `{reason}`, `{ilvl}`, etc.) to any channel.
- **Award Reasons** — Six built-in (Main Spec, Off Spec, PvP, DE, Free Roll, Bank). Customizable names, colors, sort order.
- **Sync** — Sync settings and history across guild members. Late joiners auto-sync session state.
- **Item Filtering** — Filter by class, response, rank, equippability. Permanent ignore list for unwanted items.
- **Encounter-Aware Comms** — Messages queue during boss fights and replay after — no lost votes or awards.
- **Version Check** — See who has Loothing and what version from the addon UI.
- **Test Mode** — Simulates full loot council workflows with fake items. No raid required.
- **Localization** — EN, DE, ES, PT, RU, FR, IT, KO, zhCN, zhTW, and Brainrot.
- **Minimap & Addon Compartment** — Click to toggle, right-click for settings.

## Setup
Install Loothing and you're ready to go. Raiders without the addon can whisper responses to the ML using keywords.

## Usage
The raid leader is prompted to enable Loothing upon entering a raid. When enabled, the addon watches for tradable items after boss kills. The ML sees a Session Frame with detected items — click "Start" to begin.

Council members see the Voting Frame (candidates, responses, gear comparisons, ilvl diffs, items won). Raiders see the Roll Frame to pick their response. The ML right-clicks a candidate to award or skip. The item owner then sees the Trade Panel to complete the handoff.

Works out of the box. Settings panel available for voting rules, announcements, auto-pass, auto-award, button sets, council, and more.

## Commands
Prefix: `/lt` or `/loothing`

| Command | Description |
|---------|-------------|
| `/lt` or `/lt show` | Show the main window |
| `/lt hide` | Hide the main window |
| `/lt toggle` | Toggle the main window |
| `/lt config [section]` | Open settings (`council`, etc.) |
| `/lt history` | Open the history tab |
| `/lt council` | Open council settings |
| `/lt ml [name\|clear]` | Show, set, or clear the Master Looter |
| `/lt ignore <item>` | Add/remove an item from the ignore list |
| `/lt sync settings [target]` | Sync settings to guild or a player |
| `/lt sync history [target] [days]` | Sync loot history (default 7 days) |
| `/lt import <data>` | Import history from CSV/TSV |
| `/lt help [command]` | Show command list or detailed usage |

### Debug Commands (require `/lt debug on`)
| Command | Description |
|---------|-------------|
| `/lt debug [on\|off]` | Toggle debug mode |
| `/lt test ...` | Test mode utilities |
| `/lt testmode ...` | Control test mode persistence |
