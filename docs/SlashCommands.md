# Loothing Slash Commands

Primary entry: `/lt` (alias `/loothing`). Use `/lt help` or `/lt help <command>` for inline help. Unknown commands fall back to help.

## Player commands
- `/lt` or `/lt show` — show the main window.
- `/lt hide` — hide the main window.
- `/lt toggle` — toggle the main window.
- `/lt config [section]` — open settings (use `council`, etc. for a section).
- `/lt history` — open the history tab.
- `/lt council` — open council settings in the config dialog.
- `/lt ml [name|clear]` — show, set, or clear the Master Looter.
- `/lt vote` (alias `ct`) — toggle the council voting table.
- `/lt roll` (alias `respond`) — reopen the Roll Frame for unresponded items.
- `/lt reopen response` — reopen the loot response frame.
- `/lt reopen council` — reopen the council voting table.
- `/lt reopen award` — reopen the session/award panel.
- `/lt resend` — resend loot responses for items in voting.
- `/lt resync` — discard local session state and resync from the Master Looter.
- `/lt diag` — show communication pipeline diagnostics.
- `/lt ignore <itemLink|itemID>` — add/remove an item from the ignore list.
- `/lt sync settings [guild|player]` — sync settings to a target.
- `/lt sync history [guild|player] [days]` — sync loot history (defaults to 7 days).
- `/lt import <csv|tsv data>` — import history text using the import module.
- `/lt export` — show the export dialog.
- `/lt profile [list|name]` — manage profiles.
- `/lt help [command]` — show command list or detailed usage for one command.

## Developer-only commands (require `/lt debug on`)
- `/lt debug [on|off]` — toggle debug mode; dev commands remain hidden until enabled.
- `/lt test ...` — test-mode utilities (fake items, workflows, test suites).
- `/lt testmode ...` — control simulator/test mode persistence and status.

## Notes
- All outputs are localized; errors mention when modules (config/import/sync) are unavailable.
- Help omits developer commands unless debug mode is enabled.
