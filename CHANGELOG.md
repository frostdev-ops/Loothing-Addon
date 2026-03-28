# Changelog

User-facing release notes for Loothing.

## [1.5.5] - 2026-03-28

### Fixed
- **Fixed group members not auto-passing items for the Master Looter between sessions.** When the ML was handling loot but no session was active (e.g., between boss encounters, during trash), group members did not auto-pass items in the group loot roll — the ML had to manually collect everything. Auto-pass now activates as soon as the ML starts handling loot, not just during active sessions.
- **Fixed false "Response may not have reached the Master Looter" error during combat.** When you submitted a loot response during combat, the addon incorrectly timed out and showed an error telling you to resubmit — even though the response was safely queued and would be sent automatically when combat ended. The timeout now pauses during combat instead of firing prematurely.
- **Fixed Roll Frame reappearing after combat with "Already submitted" status.** After submitting a response during combat, the Roll Frame would close correctly when combat ended (response delivered), then reappear a few seconds later showing your already-submitted response with disabled buttons. The frame no longer re-shows for items you've already responded to.
- **Fixed new group members not receiving Master Looter settings when joining mid-raid.** Players who joined a group after the ML started handling loot never received the ML's settings broadcast, so they wouldn't auto-pass items or see the correct session configuration. The ML now re-broadcasts settings when the group roster changes.

### Added
- **Sessions now auto-end when all items are awarded or skipped.** The ML no longer needs to manually end the session after the last item is resolved.

### Improved
- **Desktop sync status in the main frame title bar now shows a "Desktop:" prefix** (e.g., "Desktop: Synced", "Desktop: Stale") so it's clearly about the companion app sync, not the loot session status.

## [1.5.4] - 2026-03-27

### Fixed
- **Fixed sessions becoming permanently stuck when group members join mid-session.** If anyone joined the group after a loot session started, the addon would stop working for everyone — even ending and starting new sessions didn't fix it, requiring all members to `/reload`. The root cause was stale session state that survived across sessions: ending a session didn't clear the global Master Looter identity, new session broadcasts were silently rejected if a previous session was still active, and sync data for a new session was rejected if the old session hadn't been cleaned up. Sessions now properly self-heal in all these scenarios.
- **Fixed sync storms crashing the addon channel under raid load.** When 25 players detected state divergence from the same heartbeat, they all fired sync requests simultaneously — overwhelming the 800 bytes/sec addon channel with 125+ KB of sync responses, causing cascading timeouts and retries. Sync requests are now spread across an 8-second jitter window, the Master Looter batches sync responses, and a circuit breaker stops retry loops after repeated failures.
- **Fixed loot responses being permanently lost if the acknowledgment was missed.** If a player's loot response was dropped during network congestion, they could never resubmit — the button stayed disabled forever. Now: the first timeout auto-retries the response, the second timeout re-enables the Submit button (preserving the player's original selection), and the Master Looter automatically polls for missing responses 15 seconds after voting starts.
- **Fixed players in combat missing the entire loot session.** If a player was in combat when the Master Looter started a session and began voting, they would never see the Roll Frame — even after leaving combat. Recovery now happens within 2-6 seconds of leaving combat instead of waiting up to 30 seconds, and restored voting items correctly appear in the Roll Frame.
- **Fixed Master Looter handoff (`/lt ml`) leaving both players active simultaneously.** When transferring ML to another player, the old ML continued handling loot for up to 2 seconds (until the periodic ML check ran). Now the old ML stops immediately on handoff.
- **Fixed Master Looter identity going out of sync across addon systems.** The addon tracked ML identity in three separate places (session, settings, and global state) that could disagree after a handoff or MLDB broadcast. All three are now synchronized whenever MLDB is applied.
- **Fixed cleanup messages from previous Master Looter being rejected after double handoff.** If ML was transferred twice (A→B→C), player A's stop/session-end messages were silently rejected because only the most recent sender was tracked. The addon now tracks all recent MLDB broadcasters.
- **Fixed session becoming permanently orphaned when Master Looter leaves the group.** If the ML disconnected or left during an active session, the session died with no recovery. The new raid leader now automatically enters ML detection and is prompted to take over. Players now see a chat message explaining what happened and what to do next, and any manual ML override (`/lt ml`) pointing to the departed player is automatically cleared.
- **Fixed Master Looter detection stalling during mass group invites.** When many players joined a group in quick succession, each roster update restarted a 2-second detection timer — delaying ML detection by 4+ seconds (or indefinitely in extreme cases). Detection now fires within 3.5 seconds regardless of how many roster changes occur.
- **Fixed old Master Looter continuing to handle loot after passive ML change detection.** If the ML changed through any means other than an explicit `/lt ml` handoff (e.g., raid leader promotion change), the old ML could continue handling loot until the next roster update. The addon now immediately stops loot handling on any ML change.
- **Faster Master Looter handoff.** After using `/lt ml` to transfer or clear the Master Looter, the new ML is detected within 0.5 seconds instead of 2 seconds. Reduces the window where clients may reject messages from the new ML.

### Added
- **Session State Engine.** Your loot response state now persists independently of the Roll Frame. Closing the frame, entering combat, or syncing no longer loses your response data. Previously, closing the Roll Frame wiped all response tracking — you couldn't reopen it or see what you'd already responded to.
- **`/lt roll` command** (also `/lt respond`) — reopens the Roll Frame with all voting items you haven't responded to yet.
- **`/lt resend` command** — manually resends your loot response for all items currently in voting. Use this if you suspect your response was lost.
- **Combat-aware Submit button.** During combat, the Submit button shows "Submit (Queued)" and queues your response for automatic delivery when combat ends. After submitting, it shows "Queued (Combat)" until the acknowledgment arrives.
- **Automatic frame reappearance.** If you close the Roll Frame with unresponded items, it gently re-shows after 30 seconds (configurable — disable with "Auto-reshow" in Frame settings). A chat message also reminds you: "Type /lt roll to reopen."
- **Incremental sync** — when only a subset of session data has diverged (e.g., council roster or ML settings), the addon now requests just that piece instead of a full state dump, dramatically reducing bandwidth usage.
- **ML addon validation** — `/lt ml PlayerName` now warns if the target player doesn't appear to have Loothing installed. Use `/lt ml PlayerName force` to override.
- **Out-of-raid ML warning** — `/lt ml` now warns when assigning a Master Looter outside a raid instance while the "only use in raids" setting is active.

### Improved
- **Post-combat recovery is now 2-6 seconds** instead of up to 30 seconds. Players who were in combat when voting started now see the Roll Frame almost immediately after leaving combat, instead of waiting for the next heartbeat cycle.
- **Combat message queue increased from 50 to 100 messages.** Reduces the chance of messages being silently dropped during long combat encounters.
- **Better diagnostics for communication issues.** The addon now tracks message drops, checksum failures, and decode errors. View stats with `/lt diag`.

## [1.5.3] - 2026-03-26

### Fixed
- **Fixed Master Looter handoff not working outside raid instances.** When passing ML to another player via the roster panel or `/lt ml`, neither the old nor new ML detected the change — both saw stale state and neither could start sessions for each other. The "only use in raids" setting now correctly allows ML transitions and handoffs even when testing outside a raid instance.
- **Fixed loot handling state persisting into PvP battlegrounds and arenas.** If you were handling loot in a raid and then entered a PvP instance, the addon's ML state was never cleaned up. Active loot handling is now automatically stopped when entering PvP or scenario instances.
- **Fixed session end messages from a previous Master Looter being able to end a different session.** Session end messages now include the session ID so they can only end the matching session.

### Improved
- **Master Looter can now revote on already-awarded or skipped items.** Previously, completed items could not be revoted. The ML can now force a revote with a confirmation popup asking to clear the existing result and restart voting.

## [1.5.2] - 2026-03-25

### Fixed
- **Fixed session settings permanently overwriting your personal preferences.** When the Master Looter broadcast their settings to the raid, your local voting, autopass, auto-award, announcement, and response button settings were overwritten and never restored. Your personal settings are now automatically saved before the ML's settings are applied and restored when the session ends.
- **Fixed transferring Master Looter to another player (`/lt ml set`) not working.** The new ML's client never detected the role change — their roster tab stayed unchanged and they couldn't start sessions. The old ML's cleanup messages (stop handling, session end) were also silently rejected. ML transfers now correctly trigger detection on the receiving player, and cleanup messages from the outgoing ML are properly accepted.
- **Fixed results panel crash when sorting candidates with mixed response types.** When a candidate had a system response (like Auto Pass) and another had a normal response (like Need), the sort comparator crashed with "attempt to compare string with number." All candidate sort functions now handle mixed response types correctly.
- **Fixed leaving a group during an active session not cleaning up session state.** Non-ML players who left a group (or were disconnected) while a loot session was active would retain stale session data until the next login. Session state is now properly ended on group leave.

### Improved
- **Session settings are now locked for non-ML players during active sessions.** When a loot session is in progress, all ML-controlled settings (voting, response buttons, winner determination, council, award reasons, observer permissions, autopass, auto-award, announcements, and ignore items) are greyed out in the settings panel for non-ML players. A message indicates which Master Looter controls the settings. The Response Button Editor and Award Reasons Editor are also locked during sessions.

## [1.5.1] - 2026-03-25

### Fixed
- **Fixed batched messages (multiple votes, candidate updates) losing data when queued during combat.** When a batch of messages was sent during combat, the internal message buffer was released before the queued copy could be replayed, causing the replayed batch to contain empty or corrupted data. Messages are now safely copied before the buffer is released.
- **Fixed guild channel messages (version checks, settings sync) ignoring combat state.** Guild messages bypassed the combat awareness system entirely, causing WoW to silently drop them. Now properly detected and dropped with a debug log — retry after combat ends.
- **Fixed message replay continuing after leaving a group.** If you left a group while queued messages were being replayed (e.g., kicked during post-combat replay), the replay ticker would continue running and waste resources sending messages to nobody. Now properly cancelled on group leave.
- Fixed incomplete schema validation on PLAYER_RESPONSE, VOTE_AWARD, and VOTE_COMMIT messages allowing malformed data to pass handler validation.
- Fixed ML self-response ACK race condition — acknowledgment could arrive before the RollFrame's timeout timer was created, causing a missed clear. Self-loopback ACK is now deferred one frame.
- Fixed double-click on RollFrame submit sending duplicate responses with different roll values. Added pending-state guard.
- Fixed `SendGuild` silently dropping messages on encode failure with no error logging.

## [1.5.0] - 2026-03-25

### Improved
- **Dramatically improved communication handling during combat, encounter restrictions, and reconnects.** WoW 12.0 blocks all addon messages during combat (not just during boss encounters). New centralized communication state machine properly handles this:
  - **Full combat message queuing**: All messages are now queued during combat since WoW drops them silently. Session-critical messages (votes, awards, session start/end) are placed in a guaranteed delivery queue and replayed first when combat ends. Non-critical messages (heartbeats, version checks, sync requests) are held in a separate lower-priority queue.
  - **Paced queue replay after combat**: Previously, all queued messages were sent in a single burst when an encounter ended, causing a traffic spike and frame hitch. Messages are now replayed at a controlled rate (up to 3 per 100ms), sorted by priority (votes and awards before sync data), and adaptive to current network congestion. Replay automatically pauses if you re-enter combat mid-drain.
  - **Correct encounter-to-combat transitions**: When a boss encounter ends but trash mobs keep you in combat, the addon now correctly waits until combat fully ends before replaying queued messages. Previously, the replay would fire as soon as the encounter restriction lifted, and WoW would silently drop every message.
  - **Reconnect thundering herd prevention**: When multiple raid members reconnect simultaneously (e.g., after a mass disconnect), sync requests are now staggered with random jitter instead of all firing at the same instant. A 5-second grace period after reconnect suppresses redundant sync attempts from heartbeat mismatches and roster change detection.
  - **Automatic catch-up after combat**: WoW also blocks incoming messages while you are in combat. If the Master Looter awards an item or adds loot while you are fighting, your addon now automatically syncs with the ML a few seconds after you leave combat to recover any messages you missed. Previously, you would have to wait up to 30 seconds for the periodic heartbeat to detect the gap.
  - **ML heartbeat skip during combat**: The Master Looter's 30-second heartbeat broadcast is now skipped during combat where WoW drops addon messages anyway, saving transport queue budget for real messages after combat ends.

- **Progressive backpressure under network congestion.** Instead of a single on/off threshold, message handling now has four levels of congestion response: at light load, non-critical messages are deprioritized; at moderate load, low-priority messages are dropped; at heavy load, most non-critical messages are shed to protect session-critical traffic like votes and awards.

### Fixed
- **Fixed Master Looter unable to respond to their own loot items ("No response from master looter").** All WHISPER-to-self messages now bypass the WoW addon message network entirely via a local loopback in the comm send path. Previously, PLAYER_RESPONSE and PLAYER_RESPONSE_ACK whispers to self went through the full throttled queue and were unreliable.
- **Fixed RollFrame not appearing for other raid members during loot sessions.** Multiple root causes addressed:
  - SESSION_START from non-leader MLs (designated via `/lt ml`) was rejected by clients because `DetermineML()` had already tagged the raid leader as ML. Clients now accept SESSION_START from any group member and adopt the sender as the authoritative ML.
  - The received ML identity was not propagated to the global `Loothing.masterLooter`, causing subsequent ITEM_ADD and VOTE_REQUEST handler checks to fail. Now set on SESSION_START acceptance.
  - `isMasterLooter()` security check did not consult the global ML identity as a fallback, only Session and Settings sources. Added fallback.
- **Fixed silent message drops throughout the communication pipeline.** `Protocol:Encode` could return nil (from Serializer, Compressor, or channel encoder failures) with zero error logging — `Send()` silently discarded the message. All encoding steps are now pcall-wrapped with error-level logging on failure.
- **Fixed Loolib `ProcessSendQueue` silently discarding messages on non-throttle WoW API errors.** `C_ChatInfo.SendAddonMessage` returns result codes like `InvalidPrefix`, `NotInGroup`, and `EncounteredAddonRestriction`, but only `AddonMessageThrottle` was checked — all other errors were treated as successful sends. Now checks for explicit `Success` result, retries on throttle/restriction, and logs non-recoverable errors.
- **Fixed double-click on RollFrame submit causing duplicate responses.** Added pending-state guard to prevent resubmission while waiting for ML acknowledgment.

### Added
- `/lt diag` command — prints communication pipeline state: ML identity (global/session/settings), session state, comm queue depth, prefix registration, encounter restriction status, and an encode/decode round-trip test.

## [1.4.5] - 2026-03-24

### Fixed
- **Fixed items added via AddItemFrame or `/lt add` never reaching other raid members.** Both paths called `Session:AddItem` with `force=true` without checking whether a session was active. With no active session, the sessionID was nil (so clients rejected ITEM_ADD), the session state was INACTIVE (so the auto-start voting timer silently skipped), and no VOTE_REQUEST was ever broadcast. The RollFrame never appeared on any client. Now auto-starts a session when items are added outside of one.
- Fixed 99% CPU usage for all raid members caused by the Loolib LUA_WARNING handler running expensive `debugstack` and string processing on every WoW taint warning. During active loot council sessions in combat, WoW can fire hundreds of taint warnings per frame, and each one triggered full stack capture and pattern matching. Added a rate limiter (5 warnings/second) to prevent the handler from exceeding WoW's per-frame execution budget.

## [1.4.4] - 2026-03-24

### Fixed
- **Fixed the entire addon being non-functional when the Master Looter is not the raid leader.** All session broadcasts (SESSION_START, MLDB, ITEM_ADD, etc.) were rejected by raid members because the comm handler required the sender to be a raid leader or assistant. Clients had no way to learn the ML identity from a non-leader, creating a circular authentication failure. Now accepts session and MLDB messages from any group member when the ML identity is unknown, then validates subsequent messages against the established ML.
- Fixed removing a voting item from a session leaving its vote timer running, which could fire on an orphaned item and cause state corruption.
- Fixed the auto-start voting timer firing after a session had already ended, potentially starting votes on an inactive session.
- Fixed council votes arriving after voting ended still triggering phantom vote-update broadcasts to all council members, causing vote count desync between ML and council.
- Fixed non-ML clients accepting duplicate award messages for already-completed items, which could overwrite the awarded state.
- Fixed a missing null guard on voter identity in vote commit handling that could cause silent data corruption from malformed messages.
- Fixed session sync data overwriting an active session with data from a different session, which could clobber in-progress voting state on reconnect.

## [1.4.3] - 2026-03-24

### Fixed
- Fixed items not appearing on session members' screens when the ML adds items to a loot council session. The ITEM_ADD broadcast was missing the `sessionID` field, so every receiving client silently rejected the item as belonging to an unknown session. The RollFrame (loot response popup) never appeared because voting could never start on an item that was never accepted.
- Fixed `/lt start` rejecting the Master Looter when they are not also the raid leader. Now allows group leaders, raid assistants, and the designated ML.
- Fixed loot history entries broadcast to group/guild members being silently dropped. The HISTORY_ENTRY message type had no handler registered, so all incoming history broadcasts were discarded.
- Fixed the ML removing an item from the session not propagating to other raid members. ITEM_REMOVE was broadcast but Session never listened for it, so clients kept stale items in their UI.
- Fixed the heartbeat broadcast using incorrect method call syntax, which could prevent session state digests from reaching raid members.

## [1.4.2] - 2026-03-24

### Fixed
- Fixed `/lt start` rejecting the Master Looter with "Only the group/raid leader can activate loot handling" when the ML was not also the raid leader. Now allows group leaders, raid assistants, and the designated ML.
- Hardened the entire Loolib DEFLATE decompressor against truncated or corrupted network messages. Every `ReadBits` call in the decompression path now checks for end-of-data and returns a clean error instead of crashing. Previously, truncated messages could cause "attempt to perform arithmetic on nil" or "invalid value (nil) in table for concat" errors.

## [1.4.1] - 2026-03-24

### Added
#### Desktop Companion App
- New Tauri v2 desktop app that bridges your WoW addon data with the Loothing web platform — no more manual imports or exports.
- **Discord login**: Sign in with your Discord account using the same credentials as loothing.xyz. Works via browser redirect with a token-paste fallback for Linux desktop environments.
- **WoW directory detection**: Automatically finds your WoW installation and account SavedVariables. Supports manual selection if auto-detect misses your setup.
- **Loot history sync**: Uploads new loot history entries from your addon SavedVariables to your guild on loothing.xyz. Only uploads entries since the last sync.
- **Wishlist download**: Fetches guild and public wishlists from loothing.xyz and writes them into your SavedVariables so the addon can display them during loot council sessions.
- **Multi-guild support**: Switch between guilds from the navigation bar — all syncs target the selected guild.
- **Background monitoring**: Detects when WoW closes and can trigger automatic syncs. File watcher notices SavedVariables changes in real time.
- **System tray**: Minimizes to tray on close with quick-access Sync Now and Quit options.
- **History viewer**: Browse and filter your full loot history with item quality colors, sortable columns, and CSV export.
- **Session management**: View and manage your active desktop sessions from Settings.

#### Wishlist Column (Council Table)
- Council members now see a "Wish" column during loot voting that shows each candidate's wishlist priority for the current item.
- Priorities are color-coded by need level: orange (BiS), green (Major Upgrade), yellow (Minor Upgrade), gray (Optional), magenta (Transmog).
- Hover the column to see the full wishlist entry with need level, notes, and BiS indicator.
- The column is sortable and can be toggled on/off in Council Table settings.

#### Desktop Sync Status (Main Frame)
- The addon's main frame now shows a sync freshness indicator: green "Synced" (under 1 hour), yellow age (1–24 hours), or red "Stale" (over 24 hours).

#### Auto-Export on Logout
- The addon now writes session metadata (character name, class, GUID, addon version) to SavedVariables on every logout, enabling the desktop app to identify which character last played.

### Fixed
- Fixed the minimap button not being collected by Minimap Button Bag (MBB) and similar minimap organizer addons. The button was created without a global name, so organizers couldn't detect it.
- Fixed wishlist data write path targeting the wrong SavedVariables location — data now correctly writes to `LoolibDB.addons.Loothing.global.desktopExchange`.
- Fixed history extraction reading from wrong SavedVariables path — now correctly reads from `LoolibDB.addons.Loothing.global.history`.
- Fixed WoW configuration not persisting between app restarts (missing store save after config write).
- Fixed JSON-to-Lua conversion failing silently when writing wishlist data to SavedVariables — replaced serde deserialization with a proper recursive converter that handles arbitrary JSON objects and arrays.
- Fixed desktop app sync failing with "Authentication required" (401) — the server's unified permission middleware only recognized session-based auth, not Bearer JWT tokens from the desktop app. Added a global auth bridge that translates desktop JWTs into session-compatible format.
- Fixed a crash in the Loolib DEFLATE decompressor when a corrupted network message produced an out-of-range distance code. Now returns a clean decompression error instead of a hard Lua error.

## [1.3.3] - 2026-03-23

### Fixed
- Fixed the Roll Frame layout breaking when both the roll section and vote timer were visible at the same time.
- Fixed auto-pass reason text not displaying correctly when the AutoPass module hadn't loaded yet.

### Improved
- Cleaned up unused code and shadowed variables across the addon and Loolib library for better maintainability and smaller memory footprint.
- Tightened luacheck and architecture lint configuration so all shipped code passes with zero warnings.
- Standardized file headers across all source files so every file opens with a clear description of its purpose.
- Added table-of-contents navigation to large files (Init, Session, Settings, ConfigDialog) for easier code review.
- Added inline documentation explaining complex patterns like closure optimization, DEFLATE compression, and event dispatch safety.
- Cleaned up internal development comments throughout both Loothing and Loolib so the source reads cleanly for community contributors.

## [1.3.2] - 2026-03-22

### Added
#### Ranked Choice Voting (Council)
- Council members can now rank candidates in order of preference when Ranked Choice Voting mode is enabled. Click the Vote button on any candidate in the Council Table to open the ranking panel.
- Interactive ranking display with drag-to-reorder arrows and configurable min/max rank limits.
- Previous votes are restored when reopening the panel for an item you already voted on.
- Observe mode correctly disables the ranking panel for observers.

### Fixed
#### Communication
- Fixed tradable/non-tradable item notifications never reaching the raid. Messages were silently dropped instead of broadcasting to the group.
- Fixed loot history entries not syncing to other group members after an item was awarded.
- Fixed the "Stop Handle Loot" broadcast not reaching the raid when the ML disables loot handling.

#### Council Voting
- Fixed ranked-choice Vote clicks in the Council Table so they always route through the active council voting UI instead of silently failing when the vote modal is unavailable.
- Unified council voting entrypoints so Session, SessionPanel, and CouncilTable all use the same runtime path for ranked-choice voting.

#### Award History And Announcements
- Fixed awarded items with award reasons so the resolved reason text is reused consistently for loot history and announcement tokens.
- Fixed the announcer path in `AwardItem` referencing an out-of-scope award-reason value.

#### Secret Value Safety
- Hardened shipped runtime scope-key generation so SavedVariables no longer call raw secret-prone unit APIs directly when deriving player, class, and realm scope keys.
- Fixed remaining shipped debug/testmode helpers to use secret-safe class wrappers for player identity data.

#### Library
- Fixed a minor timing drift in Loolib’s message send queue that could cause micro-delays under heavy load.

### Changed
#### Require Note
- "Require Note" is now a session-level MLDB setting only. Removed the per-button require-notes option from the response button editor and the personal "Require Note" toggle from Local Preferences. When the ML enables Require Notes in Session Settings, all raid members must add a note to both loot responses and council votes.

#### Loolib Runtime Surface
- Consolidated slash-command and static-popup global writes behind `Loolib.Compat.GlobalBridge`, removing duplicate registry mutation paths from shipped helpers.
- Moved non-TOC Loolib runtime-style modules out of the active source tree into `_archive/` so the repository’s shipped surface matches the actual production load order.

### Documentation
- Added a shipping-surface audit script to catch raw secret-value API usage, unexpected global registry writes, and non-TOC Lua drift before release builds.

## [1.3.1] - 2026-03-19

### Fixed
#### Group Loot
- Fixed auto-pass on loot rolls firing all the time, not just during active loot council sessions. Non-ML raid members now see normal roll frames when no session is running.

#### Session State Guards
- Fixed tradability updates (HandleTradable/HandleNonTradable) processing outside an active session, which could modify stale item data from a previous session.
- Fixed remote item-add messages accepted without verifying the session ID, allowing a delayed network message from a previous session to inject items into a new one.
- Fixed vote timeout timers that fired after a session ended still broadcasting stale vote results to the raid.
- Fixed auto-award attempting to award items on an ended session if the call raced with session cleanup.

## [1.3.0] - 2026-03-18

### Added
#### Auto-Pass is now fully functional
- All auto-pass settings (enabled, weapons, BoE, transmog, trinkets) now take effect during loot sessions. Previously these settings existed in the UI but had no runtime impact.
- When a voting item arrives that you can't use, the addon automatically sends an Auto Pass response to the Master Looter and skips the Roll Frame popup.
- If item data hasn't loaded yet when voting starts, the addon retries the auto-pass check once item info becomes available.
- A chat notification tells you when an item is auto-passed and why (e.g., "Cannot wear Plate armor", "Wrong primary stats for class"). The ML can suppress these notifications for everyone via Session Settings.

### Fixed
#### Auto-Pass
- Rogues now correctly auto-pass on Bows, Crossbows, and Guns — only Hunters can equip ranged weapons in modern WoW.
- Fixed the class restriction fast-path never activating because the item data sentinel value didn't match the auto-pass constant. Class-restricted items are now detected without a tooltip scan fallback.

#### Security
- MLDB (Master Looter settings sync) no longer accepts broadcasts from any group member when the ML is unknown. Only group leaders and raid assistants can bootstrap the initial MLDB on login or reconnect.

#### Passive Mode
- Fixed a race condition where the first loot roll after joining or reconnecting could auto-roll before the ML's passive mode setting arrived. The addon now defaults to passive when a session is active but MLDB hasn't been received yet.

#### Settings Sync
- Fixed ML settings sync overwriting newer client-only settings keys. Clients running a newer addon version no longer lose local settings when the ML runs an older version.
- Fixed the "Silent Auto-Pass" setting being overwritten by the ML's preference even though it appeared under personal settings. It is now an ML-controlled session setting as intended.

#### Council Table
- Fixed a crash when sorting the Council Table response column while both numeric responses (Need, Greed, Pass) and system responses (Auto Pass) are present.

#### History Export
- Fixed a crash when exporting loot history (Lua or JSON) for items that were auto-passed or awarded with a system response.
- Auto Pass responses now display correctly in the Council Table "More Info" panel and candidate tooltips instead of showing raw response codes.

#### Award Reasons
- Fixed award reasons always showing blank in loot history. Selecting "Main Spec", "Off Spec", etc. when awarding an item now correctly records the reason.
- Fixed the `{reason}` token in award announcements always showing the vote response (e.g. "NEED") instead of the selected award reason (e.g. "Main Spec").
- Fixed auto-awarded items writing the reason into the wrong field, which caused the winner's response to display as the reason text and the actual reason to be lost.

### Changed
- Debug messages now appear when passive mode blocks an auto-roll and when the addon auto-passes a group loot roll for ML collection. Visible with `/lt debug` enabled.
- "Silent Auto-Pass" has moved from the personal Local Preferences panel to Session Settings where the ML can control it for the entire raid.

## [1.2.10] - 2026-03-17

### Fixed
#### Master Looter assignment persistence (`Core/Init.lua`, `Core/SettingsVoting.lua`)
- Fixed explicit Master Looter assignments persisting in SavedVariables across sessions, relogs, and entirely different raids.
- Master Looter overrides are now runtime-only, per-session state synced to the raid via MLDB instead of a local saved setting.

#### Stale Master Looter detection (`Core/Init.lua`, `Core/Utils.lua`)
- Fixed the addon continuing to treat a previously assigned ML as authoritative even when that player was no longer in the group.
- Added group membership validation so explicit ML assignments fall through to raid leader detection when the assigned player is absent.

#### Passive loot mode not applying to raid members (`Data/MLDB.lua`)
- Fixed MLDB broadcasts being silently dropped on clients that hadn't completed ML detection yet, preventing passive loot mode (and all other session settings) from reaching raid members on login or reconnect.

#### Passive loot mode enforcement (`Loot/GroupLootEvents.lua`, `Utils/AutoPass.lua`)
- Fixed passive loot mode so group-loot handling now resolves the authoritative session loot mode from MLDB before falling back to local settings.
- Fixed passive loot mode still allowing Loothing AutoPass logic to fire on unusable items after native group-loot auto-rolling had been disabled.

#### Shield AutoPass classification (`Utils/AutoPass.lua`)
- Fixed shield handling so shield-capable classes are never auto-passed by the generic shield armor heuristic.
- Paladins, shamans, and warriors now correctly remain eligible for shields instead of being filtered out as unusable armor.

### Changed
#### ML assignment sync model (`Data/MLDB.lua`, `UI/RosterPanel.lua`)
- ML reassignments via `/lt ml` or the Roster panel now broadcast immediately to the raid and trigger an ML re-evaluation on all clients.
- The `masterLooter` field is now included in MLDB so late joiners and reconnecting players receive the correct ML override.

## [1.2.9] - 2026-03-17

### Added
#### Passive loot handling mode (`Loot/GroupLootEvents.lua`)
- Added a session-level passive mode that leaves Blizzard's native group loot rolls in control during an active Loothing session.
- Master Looters can now switch loot roll handling between active Loothing auto-rolls and passive WoW rolls from Session Settings.

### Fixed
#### Session loot mode sync (`Data/MLDB.lua`)
- Fixed raid members being forced into Loothing's native auto-roll behavior when the session should defer to default WoW rolls.
- Fixed the session loot handling mode so it now broadcasts correctly to the raid and applies to all clients consistently.

## [1.2.8] - 2026-03-15

### Fixed
#### Council roster permissions (`UI/RosterPanel.lua`)
- Fixed non-lead, non-ML raid members seeing council-member and observer management actions they could not safely use.
- Fixed grouped non-ML clients so mirrored council and observer roster changes fail closed instead of relying on UI visibility alone.

#### Roll response rerolls (`UI/RollFrame.lua`)
- Fixed roll-type responses so players cannot keep pressing submit to generate fresh rolls on the same item.
- Fixed submitted and pending roll responses so the Roll/Pass controls lock immediately and stay locked after acknowledgement.

#### Council frame width usage (`UI/CouncilTable/Columns.lua`)
- Fixed expanded council table layouts leaving unused space on the right side of the frame.
- Wider council windows now stretch the player, response, and vote columns to use the available width more effectively.

## [1.2.7] - 2026-03-15

### Added
- Added direct profile sharing so you can send your settings profile to another player in your group.
- Added a small decoder utility for unpacking Loothing settings exports and compact loot exports outside the game.
- Added Brainrot Mode as a dedicated toggle in Personal Preferences, replacing the old language override dropdown.

### Fixed
- Fixed decoder output so empty settings tables are shown as objects instead of empty arrays.
- Fixed Brainrot Mode not activating due to SavedVariables not being available at early load time.

### Changed
- Existing brainrot language override users are automatically migrated to the new toggle on first load.
- Updated release-facing version references to `1.2.7`.

## [1.2.6] - 2026-03-15

### Added
- Added profile export and import for settings, including create-new-profile and apply-to-current options.
- Added full profile management in the settings UI: create, switch, copy, delete, reset, export, and import.
- Added ignore-list management in settings so items can be added or removed more easily.
- Enabled session announcement flows that were configured but not previously firing.

### Fixed
- Fixed a long list of raid-critical issues affecting vote resolution, sync stability, ML detection retries, auto-award deduping, rate-limited whisper handling, and RollFrame timer cleanup.
- Fixed multiline config inputs so large pasted exports no longer overflow or behave badly in the config UI.
- Fixed several profile UI edge cases around deletion, import handling, and settings persistence.

### Changed
- Added the settings API needed to support profile export and import cleanly.

## [1.2.5] - 2026-03-13

### Added
- Added more flexible session trigger settings with separate action, timing, and scope controls.
- Added matching settings UI for raid, dungeon, and open-world trigger behavior.

### Fixed
- Fixed legacy trigger migration so switching profiles no longer leaves old trigger settings behind.
- Fixed after-loot debounce state so stale encounter state does not trigger later in the wrong fight.
- Fixed settings navigation and layout issues in the options UI.
- Fixed award-reason settings so edits now persist correctly.

### Changed
- Session start behavior is now easier to configure without changing the default raid-only prompt flow.

## [1.2.4] - 2026-03-12

### Added
- Added a manifest-driven build and packaging workflow.
- Expanded Loolib documentation and public metadata for shipped library families.

### Fixed
- Fixed and hardened large parts of the embedded Loolib runtime, especially around UI, drag/drop, notes, canvas sync, and lifecycle cleanup.
- Fixed release packaging so Loothing ships with the Loolib pieces it actually needs.

### Changed
- Updated release docs and metadata to match the real packaged addon contents.

## [1.2.3] - 2026-03-11

### Fixed
- Fixed roster version replies so remote item level and spec information show up correctly.
- Fixed history exports so JSON and compact exports preserve item links and nested vote data.
- Fixed export dialogs so copy-heavy workflows are easier and more reliable.

### Added
- Added regression coverage for history export formatting and compact export integrity.

## [1.2.2] - 2026-03-10

### Added
- Added runtime taint diagnostics and audit tooling for development builds.
- Added winner-determination settings such as tie-breaker mode, confirmation behavior, and unanimous auto-award.
- Added IRV round-by-round display in the Results panel.
- Added a more interactive ranked-choice voting panel.

### Fixed
- Fixed multiple secret-value and taint-related crash paths across SavedVariables, migration, trade handling, UI, note rendering, and chat-event processing.
- Fixed several namespace and runtime-surface issues in both Loothing and Loolib.
- Fixed a group-loot display edge case so frame-removal failures no longer bubble into a hard Lua error.

## [1.2.1] - 2026-03-10

### Added
- Added stronger ranked-choice voting controls, including rank limits, revote limits, and winner-determination settings in the UI.
- Added IRV round visualizations in the Results panel.
- Added a better ranking workflow for council voting.
- Added automatic web-export opening at session end as an optional history setting.

### Fixed
- Fixed multiple ranked-choice voting correctness issues, including candidate extraction and tie-breaking behavior.
- Fixed web export performance so very large history exports no longer freeze the UI as badly.
- Fixed compact web exports so response definitions are included for downstream importers.
- Fixed namespace cleanup and several performance hot spots in history, version checking, trade watching, and addon comm processing.

## [1.2.0] - 2026-03-09

### Changed
- Completed the move away from addon-owned runtime globals to the shared namespace and Loolib interface model.
- Cleaned up core, data, communication, council, UI, and test exports to use consistent namespaced access.

### Fixed
- Improved compatibility and stability after the namespace migration by removing legacy global access patterns.

## [1.1.8] - 2026-03-09

### Added
- Added `LoolibSecretUtil`, a reusable library for safely handling WoW 12.0 secret values.

### Fixed
- Fixed crashes caused by secret values in name handling, ML detection, roster iteration, comm authorization, UI panels, player cache, and debug/error output.

### Changed
- Migrated Loothing to use the new Loolib secret-value wrappers instead of manual guards.

## [1.1.7] - 2026-03-08

### Fixed
- Fixed taint-unsafe string handling in combat event payloads for roll parsing, whisper commands, and related debug output.

## [1.1.6] - 2026-03-08

### Fixed
- Fixed early-load crashes caused by missing realm names before player/login state was fully available.
- Removed a stale temporary file from the repo.

## [1.1.5] - 2026-03-08

### Added
- Added bulk actions for session items, including multi-select, bulk vote controls, bulk remove/skip/revote, and a bulk action bar.

### Fixed
- Fixed council vote submission from the VotePanel.
- Fixed `SESSION_END` authorization after heartbeat timeout edge cases.
- Fixed MLDB key collisions that could corrupt synced button colors.
- Fixed vote retraction behavior for non-ML council members.
- Fixed noisy Loolib warning capture from unrelated addons and Blizzard UI.

### Changed
- Expanded MLDB sync so more session-relevant settings are shared across the group.

## [1.1.4-r2] - 2026-03-08

### Added
- Added bulk item queueing to the Add Item frame so multiple items can be added in one pass.

### Fixed
- Fixed multi-vote behavior when multi-voting is disabled.
- Fixed self-vote enforcement in both the UI and ML-side validation.
- Fixed hidden-vote-count settings so non-ML users no longer see vote counts where they should not.
- Fixed Add Item queue desync when changing filters.

### Changed
- Expanded MLDB sync to include more session settings such as auto-pass, auto-award, announcements, and ignore lists.

## [1.1.4-r1] - 2026-03-08

### Fixed
- Fixed a pre-session ML detection deadlock that could prevent the actual master looter from seeing session controls.
- Fixed taint and test-mode leakage caused by unsafe test mocks.

## [1.1.4] - 2026-03-08

### Fixed
- Fixed council assistants incorrectly seeing ML-only controls and actions.
- Fixed award confirmation popups appearing behind other frames.
- Fixed several History panel layout and resizing issues.

## [1.1.3] - 2026-03-08

### Added
- Added metadata-rich history exports across supported formats.
- Added compact web export strings for quick external import.

### Fixed
- Fixed duplicate Loolib XML template registration problems when embedded and standalone copies were both loaded.
- Fixed history import so metadata headers no longer break CSV and TSV imports.

### Changed
- Moved Loolib template initialization from XML to Lua for safer loading.

## [1.1.2] - 2026-03-07

### Changed
- Changed ResultsPanel awarding so the master looter can directly select a candidate instead of being forced through the old tie-only flow.

### Fixed
- Fixed CouncilTable right-click behavior so the row context menu is easier to trigger.

## [1.1.1] - 2026-03-07

### Added
- Added the candidate-centric Results panel layout.
- Added loot-history columns to the CouncilTable.
- Added the Roster tab with version, role, council, and loot-history visibility.
- Added the observer system overhaul with configurable observer visibility and syncing.

### Fixed
- Fixed multiple ResultsPanel, ItemRow, trade queue, and test-mode issues that made awarding and testing unreliable.

## [1.1.0] - 2026-03-07

### Added
- Added silent rolls so every response always has a roll value, even if the player does not type `/roll`.

### Fixed
- Fixed several security and sync issues around ML spoofing, stale sessions, tradability matching, and remote roster cleanup.
- Fixed CouncilTable and SessionPanel UI paths that were pointing at dead or incorrect panels.

### Changed
- Added automatic pruning for very old history entries.

## [1.0.1] - Initial tracked release

### Added
- Initial tracked release of Loothing.
