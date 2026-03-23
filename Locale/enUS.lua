--[[--------------------------------------------------------------------
    Loothing - Loot Council Addon for WoW 12.0+
    Locale - English (US) localization
----------------------------------------------------------------------]]

local ADDON_NAME, ns = ...
local Loolib = LibStub("Loolib")
local LoolibLocale = Loolib.Locale or Loolib:GetModule("Locale")
local L = LoolibLocale:NewLocale(ADDON_NAME, "enUS", true)

-- General
L["ADDON_NAME"] = "Loothing"
L["ADDON_LOADED"] = "Loothing v%s loaded. Type /loothing or /lt for options."
L["SLASH_HELP_HEADER"] = "Loothing commands (use /lt help <command>):"
L["SLASH_HELP_DETAIL"] = "Usage for /lt %s:"
L["SLASH_HELP_UNKNOWN"] = "Unknown command '%s'. Use /lt help."
L["SLASH_HELP_DEBUG_NOTE"] = "Enable /lt debug to see developer commands."
L["SLASH_NO_MAINFRAME"] = "Main window not available yet."
L["SLASH_NO_CONFIG"] = "Config dialog not available."
L["SLASH_INVALID_ITEM"] = "Invalid item link."
L["SLASH_SYNC_UNAVAILABLE"] = "Sync module not available."
L["SLASH_IMPORT_UNAVAILABLE"] = "Import module not available."
L["SLASH_IMPORT_PROMPT"] = "Provide CSV/TSV text: /lt import <data>"
L["SLASH_IMPORT_PARSE_ERROR"] = "Parse error: %s"
L["SLASH_IMPORT_SUCCESS"] = "Imported %d entries."
L["SLASH_IMPORT_FAILED"] = "Import failed: %s"
L["SLASH_DEBUG_STATE"] = "Loothing debug: %s"
L["SLASH_DEBUG_REQUIRED"] = "Enable debug mode with /lt debug to use this command."
L["SLASH_TEST_UNAVAILABLE"] = "Test mode not available."
L["SLASH_DESC_SHOW"] = "Show main window"
L["SLASH_DESC_HIDE"] = "Hide main window"
L["SLASH_DESC_TOGGLE"] = "Toggle main window"
L["SLASH_DESC_CONFIG"] = "Open settings dialog"
L["SLASH_DESC_HISTORY"] = "Open history tab"
L["SLASH_DESC_COUNCIL"] = "Open council settings"
L["SLASH_DESC_ML"] = "View or assign Master Looter"
L["SLASH_DESC_IGNORE"] = "Add/remove item from ignore list"
L["SLASH_DESC_SYNC"] = "Sync settings or history"
L["SLASH_DESC_IMPORT"] = "Import loot history text"
L["SLASH_DESC_DEBUG"] = "Toggle debug mode (enables dev commands)"
L["SLASH_DESC_TEST"] = "Test mode utilities"
L["SLASH_DESC_TESTMODE"] = "Control simulator/test mode"
L["SLASH_DESC_HELP"] = "Show command help"
L["SLASH_DESC_START"] = "Activate loot handling"
L["SLASH_DESC_STOP"] = "Deactivate loot handling"

-- Session
L["SESSION_ACTIVE"] = "Session Active"
L["SESSION_CLOSED"] = "Session Closed"
L["NO_ITEMS"] = "No items in session"
L["MANUAL_SESSION"] = "Manual Session"
L["ITEMS_COUNT"] = "%d items (%d pending, %d voting, %d done)"
L["YOU_ARE_ML"] = "You are Master Looter"
L["ML_IS"] = "ML: %s"
L["ML_IS_EXPLICIT"] = "Master Looter: %s (assigned)"
L["ML_IS_RAID_LEADER"] = "Master Looter: %s (raid leader)"
L["ML_NOT_SET"] = "No Master Looter (not in a group)"
L["ML_CLEARED"] = "Master Looter cleared - using raid leader"
L["ML_ASSIGNED"] = "Master Looter assigned to %s"
L["ML_HANDLING_LOOT"] = "Now handling loot distribution."
L["ML_NOT_ACTIVE_SESSION"] = "Loothing is not active for this session. Use '/loothing start' to enable manually."
L["ML_USAGE_PROMPT_TEXT"] = "You are the raid leader. Use Loothing for loot distribution?"
L["ML_USAGE_PROMPT_TEXT_INSTANCE"] = "You are the raid leader.\nUse Loothing for %s?"
L["ML_STOPPED_HANDLING"] = "Stopped handling loot distribution."
L["RECONNECT_RESTORED"] = "Restored session state from cache."
L["ERROR_NOT_ML_OR_RL"] = "Only the Master Looter or Raid Leader can do this"
L["REFRESH"] = "Refresh"
L["ITEM"] = "Item"
L["STATUS"] = "Status"
L["START_ALL"] = "Start All"
L["DATE"] = "Date"

-- Voting
L["VOTE"] = "Vote"
L["VOTING"] = "Voting"
L["START_VOTE"] = "Start Vote"
L["TIME_REMAINING"] = "%d seconds remaining"
L["SUBMIT_VOTE"] = "Submit Vote"
L["SUBMIT_RESPONSE"] = "Submit Response"
L["CHANGE_VOTE"] = "Change Vote"

-- Awards
L["AWARD"] = "Award"
L["AWARD_ITEM"] = "Award Item"
L["CONFIRM_AWARD"] = "Award %s to %s?"
L["ITEM_AWARDED"] = "%s awarded to %s"
L["SKIP_ITEM"] = "Skip Item"
L["DISENCHANT"] = "Disenchant"

-- Results
L["RESULTS"] = "Results"
L["WINNER"] = "Winner"
L["TIE"] = "Tie"

-- Council
L["COUNCIL"] = "Council"
L["COUNCIL_MEMBERS"] = "Council Members"
L["ADD_MEMBER"] = "Add Member"
L["REMOVE_MEMBER"] = "Remove Member"
L["IS_COUNCIL"] = "%s is a council member"
L["AUTO_OFFICERS"] = "Auto-include officers"
L["AUTO_RAID_LEADER"] = "Auto-include raid leader"

-- History
L["HISTORY"] = "History"
L["NO_HISTORY"] = "No loot history"
L["CLEAR_HISTORY"] = "Clear History"
L["CONFIRM_CLEAR_HISTORY"] = "Clear all loot history?"
L["EXPORT"] = "Export"
L["EXPORT_HISTORY"] = "Export History"
L["EXPORT_EQDKP"] = "EQdkp"
L["SEARCH"] = "Search..."
L["SELECT_ALL"] = "Select All"
L["ALL_WINNERS"] = "All Winners"
L["CLEAR"] = "Clear"

-- Tabs
L["TAB_SESSION"] = "Session"
L["TAB_TRADE"] = "Trade"
L["TAB_HISTORY"] = "History"
L["TAB_ROSTER"] = "Roster"

-- Roster
L["ROSTER_SUMMARY"] = "%d Members | %d Online | %d Installed | %d Council"
L["ROSTER_NO_GROUP"] = "Not in a group"
L["ROSTER_QUERY_VERSIONS"] = "Query Versions"
L["ROSTER_ADD_COUNCIL"] = "Add to Council"
L["ROSTER_REMOVE_COUNCIL"] = "Remove from Council"
L["ROSTER_SET_ML"] = "Set as Master Looter"
L["ROSTER_CLEAR_ML"] = "Remove as Master Looter"
L["ROSTER_PROMOTE_LEADER"] = "Promote to Leader"
L["ROSTER_PROMOTE_ASSISTANT"] = "Promote to Assistant"
L["ROSTER_DEMOTE"] = "Demote"
L["ROSTER_UNINVITE"] = "Uninvite"
L["ROSTER_ADD_OBSERVER"] = "Add as Observer"
L["ROSTER_REMOVE_OBSERVER"] = "Remove as Observer"

-- Settings
L["SETTINGS"] = "Settings"
L["GENERAL"] = "General"
L["VOTING_MODE"] = "Voting Mode"
L["VOTING_MODE_DESC"] = "Simple: each council member casts one vote per candidate. Ranked Choice: members rank candidates by preference using instant-runoff elimination."
L["SIMPLE_VOTING"] = "Simple (Most votes wins)"
L["RANKED_VOTING"] = "Ranked Choice"
L["VOTING_TIMEOUT"] = "Voting Timeout"
L["SECONDS"] = "seconds"
L["AUTO_INCLUDE_OFFICERS"] = "Auto-include officers"
L["AUTO_INCLUDE_LEADER"] = "Auto-include raid leader"
L["ADD"] = "Add"

-- Auto-Pass
L["AUTOPASS_SETTINGS"] = "Auto-Pass Settings"
L["ENABLE_AUTOPASS"] = "Enable Auto-Pass"
L["AUTOPASS_DESC"] = "Automatically pass on items you cannot use"
L["AUTOPASS_WEAPONS"] = "Auto-pass weapons (wrong primary stats)"

-- Announcement Settings
L["ANNOUNCEMENT_SETTINGS"] = "Announcement Settings"
L["ANNOUNCE_AWARDS"] = "Announce Awards"
L["ANNOUNCE_ITEMS"] = "Announce Items"
L["ANNOUNCE_BOSS_KILL"] = "Announce Session Start/End"
L["CHANNEL_RAID"] = "Raid"
L["CHANNEL_RAID_WARNING"] = "Raid Warning"
L["CHANNEL_OFFICER"] = "Officer"
L["CHANNEL_GUILD"] = "Guild"
L["CHANNEL_PARTY"] = "Party"
L["CHANNEL_NONE"] = "None"

-- Auto-Award
L["AUTO_AWARD_SETTINGS"] = "Auto Award Settings"
L["AUTO_AWARD_ENABLE"] = "Enable Auto Award"
L["AUTO_AWARD_DESC"] = "Automatically award items below quality threshold"
L["AUTO_AWARD_TO"] = "Award To"
L["AUTO_AWARD_TO_DESC"] = "Player name or 'disenchanter'"

-- Ignore Items
L["IGNORE_ITEMS_SETTINGS"] = "Ignore Items"
L["ENABLE_IGNORE_LIST"] = "Enable Ignore List"
L["IGNORE_LIST_DESC"] = "Items on the ignore list will not be tracked by the loot council"
L["IGNORED_ITEMS"] = "Ignored Items"
L["NO_IGNORED_ITEMS"] = "No items are currently ignored"
L["ADD_IGNORED_ITEM"] = "Add Item to Ignore List"
L["REMOVE_IGNORED_ITEM"] = "Remove from ignore list"
L["ITEM_IGNORED"] = "%s added to ignore list"
L["ITEM_UNIGNORED"] = "%s removed from ignore list"
L["SLASH_IGNORE"] = "/loothing ignore [itemlink] - Add/remove item from ignore list"
L["CLEAR_IGNORED_ITEMS"] = "Clear All"
L["CONFIRM_CLEAR_IGNORED"] = "Clear all ignored items?"
L["IGNORED_ITEMS_CLEARED"] = "Ignore list cleared"
L["IGNORE_CATEGORIES"] = "Category Filters"
L["IGNORE_ADD_DESC"] = "Paste an item link or enter an item ID."

-- Common UI
L["CLOSE"] = "Close"
L["CANCEL"] = "Cancel"
L["NO_LIMIT"] = "No Limit"

-- Brainrot Mode
L["CONFIG_BRAINROT_MODE"] = "Brainrot Mode"
L["CONFIG_BRAINROT_MODE_DESC"] = "Replace addon text with the brainrot variant (requires /reload)"

-- Settings Tab Names
L["CONFIG_TAB_GENERAL"] = "General"
L["CONFIG_TAB_GENERAL_DESC"] = "Personal preferences that only affect your client"
L["CONFIG_TAB_MASTER_LOOTER"] = "Master Looter"
L["CONFIG_TAB_MASTER_LOOTER_DESC"] = "ML behavior, auto-award, item filtering, and loot history"
L["CONFIG_TAB_SESSION"] = "Session & Voting"
L["CONFIG_TAB_SESSION_DESC"] = "Voting rules, winner determination, and response buttons"
L["CONFIG_TAB_COUNCIL"] = "Council"
L["CONFIG_TAB_COUNCIL_DESC"] = "Council roster, guild rank auto-include, and observer permissions"

-- Personal Preferences
L["PERSONAL_PREFERENCES"] = "Personal Preferences"
L["CONFIG_LOOT_RESPONSE"] = "Loot Response"
L["CONFIG_ROLLFRAME_AUTO_SHOW"] = "Auto-Show Response Frame"
L["CONFIG_ROLLFRAME_AUTO_SHOW_DESC"] = "Automatically show the response frame when voting starts"
L["CONFIG_ROLLFRAME_AUTO_ROLL"] = "Auto-Roll on Submit"
L["CONFIG_ROLLFRAME_AUTO_ROLL_DESC"] = "Automatically trigger /roll when submitting a response"
L["CONFIG_ROLLFRAME_GEAR_COMPARE"] = "Show Gear Comparison"
L["CONFIG_ROLLFRAME_GEAR_COMPARE_DESC"] = "Show your currently equipped items for comparison"
L["CONFIG_ROLLFRAME_REQUIRE_NOTE"] = "Require Note"
L["CONFIG_ROLLFRAME_REQUIRE_NOTE_DESC"] = "Require a note before submitting a response"
L["CONFIG_ROLLFRAME_PRINT_RESPONSE"] = "Print Response to Chat"
L["CONFIG_ROLLFRAME_PRINT_RESPONSE_DESC"] = "Print your submitted response to chat for personal reference"
L["CONFIG_ROLLFRAME_TIMER"] = "Response Timer"
L["CONFIG_ROLLFRAME_TIMER_ENABLED"] = "Show Response Timer"
L["CONFIG_ROLLFRAME_TIMER_DURATION"] = "Timer Duration"

-- Session Settings (ML)
L["SESSION_SETTINGS_ML"] = "Session Settings (ML)"
L["VOTING_TIMEOUT_DURATION"] = "Timeout Duration"

-- Errors
L["ERROR_NO_SESSION"] = "No active session"

-- Communication
L["SYNC_COMPLETE"] = "Sync complete"

-- Guild Sync
L["HISTORY_SYNCED"] = "%d history entries synced from %s"
L["SYNC_IN_PROGRESS"] = "Sync already in progress"
L["SYNC_TIMEOUT"] = "Sync timed out"

-- Tooltips
L["TOOLTIP_ITEM_LEVEL"] = "Item Level: %d"
L["TOOLTIP_VOTES"] = "Votes: %d"

-- Status
L["STATUS_PENDING"] = "Pending"
L["VOTING_STATE_PENDING"] = "Pending"
L["VOTING_STATE_VOTING"] = "Voting"
L["VOTING_STATE_TALLYING"] = "Tallying"
L["VOTING_STATE_DECIDED"] = "Decided"
L["VOTING_STATE_REVOTING"] = "Re-voting"
L["STATUS_VOTING"] = "Voting"
L["STATUS_TALLIED"] = "Tallied"
L["STATUS_AWARDED"] = "Awarded"
L["STATUS_SKIPPED"] = "Skipped"

-- Response Settings
L["RESET_RESPONSES"] = "Reset to Defaults"

-- Award Reason Settings
L["REQUIRE_AWARD_REASON"] = "Require reason when awarding"
L["AWARD_REASONS"] = "Award Reasons"
L["ADD_REASON"] = "Add Reason"
L["REASON_NAME"] = "Reason Name"
L["AWARD_REASON"] = "Award Reason"

-- Trade Panel
L["TRADE_QUEUE"] = "Trade Queue"
L["TRADE_PANEL_HELP"] = "Click a player name to initiate trade"
L["NO_PENDING_TRADES"] = "No items pending trade"
L["NO_ITEMS_TO_TRADE"] = "No items to trade"
L["ONE_ITEM_TO_TRADE"] = "1 item awaiting trade"
L["N_ITEMS_TO_TRADE"] = "%d items awaiting trade"
L["AUTO_TRADE"] = "Auto-trade"
L["CLEAR_COMPLETED"] = "Clear Completed"

-- Voting Options
L["SELF_VOTE"] = "Allow Self-Vote"
L["SELF_VOTE_DESC"] = "Allow council members to vote for themselves"
L["MULTI_VOTE"] = "Allow Multi-Vote"
L["MULTI_VOTE_DESC"] = "Allow voting for multiple candidates per item"
L["ANONYMOUS_VOTING"] = "Anonymous Voting"
L["ANONYMOUS_VOTING_DESC"] = "Hide who voted for whom until item is awarded"
L["HIDE_VOTES"] = "Hide Vote Counts"
L["HIDE_VOTES_DESC"] = "Don't show vote counts until all votes are in"
L["OBSERVE_MODE"] = "Observe Mode"
L["AUTO_ADD_ROLLS"] = "Auto-add Rolls"
L["AUTO_ADD_ROLLS_DESC"] = "Automatically add /roll results to candidates"
L["REQUIRE_NOTES"] = "Require Notes"
L["REQUIRE_NOTES_DESC"] = "Require a note with votes and loot responses"

-- Button Sets
L["BUTTON_SETS"] = "Button Sets"
L["ACTIVE_SET"] = "Active Set"
L["NEW_SET"] = "New Set"
L["CONFIRM_DELETE_SET"] = "Delete button set '%s'?"
L["ADD_BUTTON"] = "Add Button"
L["MAX_BUTTONS"] = "Maximum 10 buttons per set"
L["MIN_BUTTONS"] = "At least 1 button required"
L["DEFAULT_SET"] = "Default"
L["SORT_ORDER"] = "Sort Order"
L["BUTTON_COLOR"] = "Button Color"

-- Filters
L["FILTERS"] = "Filters"
L["FILTER_BY_CLASS"] = "Filter by Class"
L["FILTER_BY_RESPONSE"] = "Filter by Response"
L["FILTER_BY_RANK"] = "Filter by Guild Rank"
L["SHOW_EQUIPPABLE_ONLY"] = "Show Equippable Only"
L["HIDE_PASSED_ITEMS"] = "Hide Passed Items"
L["CLEAR_FILTERS"] = "Clear Filters"
L["ALL_CLASSES"] = "All Classes"
L["ALL_RESPONSES"] = "All Responses"
L["ALL_RANKS"] = "All Ranks"
L["FILTERS_ACTIVE"] = "%d filter(s) active"

-- Generic / Missing strings
L["YES"] = "Yes"
L["NO"] = "No"
L["TIME_EXPIRED"] = "Time expired"
L["END_SESSION"] = "End Session"
L["END_VOTE"] = "End Vote"
L["START_SESSION"] = "Start Session"
L["OPEN_MAIN_WINDOW"] = "Open main window"
L["RE_VOTE"] = "Re-Vote"
L["ROLL_REQUEST"] = "Roll Request"
L["ROLL_REQUEST_SENT"] = "Roll request sent"
L["SELECT_RESPONSE"] = "Select Response"
L["HIDE_MINIMAP_BUTTON"] = "Hide minimap button"
L["NO_SESSION"] = "No active session"
L["MINIMAP_TOOLTIP_LEFT"] = "Left-click: Open Loothing"
L["MINIMAP_TOOLTIP_RIGHT"] = "Right-click: Options"
L["RESULTS_TITLE"] = "Results"
L["VOTE_TITLE"] = "Loot Response"
L["VOTES"] = "Votes"
L["ITEMS_PENDING"] = "%d items pending"
L["ITEMS_VOTING"] = "%d items voting"
L["LINK_IN_CHAT"] = "Link in Chat"
L["VIEW"] = "View"

-- Master Looter Settings
L["CONFIG_ML_SETTINGS"] = "Master Looter Settings"

-- History Settings
L["CONFIG_HISTORY_SETTINGS"] = "History Settings"
L["CONFIG_HISTORY_ENABLED"] = "Enable Loot History"
L["CONFIG_HISTORY_CLEARALL_CONFIRM"] = "Are you sure you want to delete ALL history entries? This cannot be undone!"

-- Enhanced Award Reasons
L["CONFIG_REASON_LOG"] = "Log to History"
L["CONFIG_REASON_DISENCHANT"] = "Treat as Disenchant"
L["CONFIG_REASON_RESET_CONFIRM"] = "Reset all award reasons to defaults?"

-- Council Management
L["CONFIG_COUNCIL_REMOVEALL_CONFIRM"] = "Remove all council members?"

-- Auto-Pass Enhancements
L["CONFIG_AUTOPASS_TRINKETS"] = "Auto-pass Trinkets"
L["CONFIG_AUTOPASS_SILENT"] = "Silent Auto-Pass"
L["CONFIG_AUTOPASS_SILENT_DESC"] = "Suppress auto-pass chat notifications for all raid members"

-- Voting Enhancements
L["CONFIG_VOTING_MLSEESVOTES"] = "ML Sees Votes"
L["CONFIG_VOTING_MLSEESVOTES_DESC"] = "Master Looter can see votes even when anonymous"

-- RollFrame UI
L["ROLL_YOUR_ROLL"] = "Your Roll:"

-- CouncilTable UI
L["COUNCIL_NO_CANDIDATES"] = "No candidates have responded yet"
L["COUNCIL_AWARD"] = "Award"
L["COUNCIL_REVOTE"] = "Re-vote"
L["COUNCIL_SKIP"] = "Skip"
L["COUNCIL_CONFIRM_REVOTE"] = "Clear all votes and restart voting?"

-- CouncilTable Settings
L["COUNCIL_COLUMN_PLAYER"] = "Player Name"
L["COUNCIL_COLUMN_RESPONSE"] = "Response"
L["COUNCIL_COLUMN_ROLL"] = "Roll"
L["COUNCIL_COLUMN_NOTE"] = "Note"
L["COUNCIL_COLUMN_ILVL"] = "Item Level"
L["COUNCIL_COLUMN_ILVL_DIFF"] = "Upgrade (+/-)"
L["COUNCIL_COLUMN_GEAR1"] = "Gear Slot 1"
L["COUNCIL_COLUMN_GEAR2"] = "Gear Slot 2"

-- Winner Determination Settings
L["WINNER_DETERMINATION"] = "Winner Determination"
L["WINNER_DETERMINATION_DESC"] = "Configure how winners are selected when voting ends."
L["WINNER_MODE"] = "Winner Mode"
L["WINNER_MODE_DESC"] = "How the winner is determined after voting"
L["WINNER_MODE_HIGHEST_VOTES"] = "Highest Council Votes"
L["WINNER_MODE_ML_CONFIRM"] = "ML Confirms Winner"
L["WINNER_MODE_AUTO_CONFIRM"] = "Auto-select Highest + Confirm"
L["WINNER_TIE_BREAKER"] = "Tie Breaker"
L["WINNER_TIE_BREAKER_DESC"] = "How ties are resolved when candidates have equal votes"
L["WINNER_TIE_USE_ROLL"] = "Use Roll Value"
L["WINNER_TIE_ML_CHOICE"] = "ML Chooses"
L["WINNER_TIE_REVOTE"] = "Trigger Re-vote"
L["WINNER_AUTO_AWARD_UNANIMOUS"] = "Auto-award on Unanimous"
L["WINNER_AUTO_AWARD_UNANIMOUS_DESC"] = "Automatically award when all council members vote for the same candidate"
L["WINNER_REQUIRE_CONFIRMATION"] = "Require Confirmation"
L["WINNER_REQUIRE_CONFIRMATION_DESC"] = "Show confirmation dialog before awarding items"

-- Announcements - Considerations
L["CONFIG_CONSIDERATIONS"] = "Considerations"
L["CONFIG_CONSIDERATIONS_CHANNEL"] = "Channel"
L["CONFIG_CONSIDERATIONS_TEXT"] = "Message Template"

-- Announcements - Line Configuration
L["CONFIG_LINE"] = "Line"
L["CONFIG_ENABLED"] = "Enabled"
L["CONFIG_ENABLED_DESC"] = "Enable or disable this announcement line"
L["CONFIG_CHANNEL"] = "Channel"
L["CONFIG_CHANNEL_DESC"] = "The chat channel to send this announcement to"
L["CONFIG_MESSAGE_DESC"] = "The message template. Supports tokens like {item}, {winner}, {reason}, etc."

-- Award Reasons
L["CONFIG_NUM_REASONS_DESC"] = "Number of active award reasons (1-20)"
L["CONFIG_AWARD_REASONS_DESC"] = "Configure award reasons. Each reason can be toggled for logging and marked as disenchant."
L["CONFIG_RESET_REASONS"] = "Reset to Defaults"

-- Frame Settings (using OptionsTable naming convention)
L["CONFIG_FRAME_MINIMIZE_COMBAT"] = "Minimize in Combat"
L["CONFIG_FRAME_TIMEOUT_FLASH"] = "Flash on Timeout"
L["CONFIG_FRAME_BLOCK_TRADES"] = "Block Trades During Voting"

-- History Settings (CONFIG_HISTORY_ENABLED/DESC defined above in Config section)
L["CONFIG_HISTORY_SEND"] = "Send History"
L["CONFIG_HISTORY_CLEAR_ALL"] = "Clear All"
L["CONFIG_HISTORY_AUTO_EXPORT_WEB"] = "Auto-Show Web Export"
L["CONFIG_HISTORY_AUTO_EXPORT_WEB_DESC"] = "When a loot session ends, automatically open the export dialog with the Web export ready to copy"

-- Whisper Commands
L["WHISPER_RESPONSE_RECEIVED"] = "Loothing: Response '%s' received for %s"
L["WHISPER_NO_SESSION"] = "Loothing: No active session"
L["WHISPER_NO_VOTING_ITEMS"] = "Loothing: No items currently open for voting"
L["WHISPER_UNKNOWN_COMMAND"] = "Loothing: Unknown command '%s'. Whisper !help for options"
L["WHISPER_HELP_HEADER"] = "Loothing: Whisper commands:"
L["WHISPER_HELP_LINE"] = "  %s - %s"
L["WHISPER_ITEM_SPECIFIED"] = "Loothing: Response '%s' received for %s (#%d)"
L["WHISPER_INVALID_ITEM_NUM"] = "Loothing: Invalid item number %d (session has %d items)"

-- General / UI
L["ADDON_TAGLINE"] = "Loot Council Addon"
L["VERSION"] = "Version"
L["VERSION_CHECK"] = "Version Check"
L["OUTDATED"] = "Outdated"
L["NOT_INSTALLED"] = "Not Installed"
L["CURRENT"] = "Current"
L["ENABLED"] = "Enabled"
L["REQUIRED"] = "Required"
L["NOTE"] = "Note:"
L["PLAYER"] = "Player"
L["SEND"] = "Send"
L["SEND_TO"] = "Send To:"
L["WHISPER"] = "Whisper"

-- Blizzard Settings Integration
L["BLIZZARD_SETTINGS_DESC"] = "Click below to open the full settings panel"
L["OPEN_SETTINGS"] = "Open Loothing Settings"

-- Slash Commands (Debug)
L["SLASH_DESC_ERRORS"] = "Show captured errors"
L["SLASH_DESC_LOG"] = "View recent logs"

-- Session Panel
L["ADD_ITEM"] = "Add Item"
L["ADD_ITEM_TITLE"] = "Add Item to Session"
L["ENTER_ITEM"] = "Enter Item"
L["RECENT_DROPS"] = "Recent Drops"
L["FROM_BAGS"] = "From Bags"
L["ENTER_ITEM_HINT"] = "Paste item link, item ID, or drag an item here"
L["DRAG_ITEM_HERE"] = "Drop item here"
L["NO_RECENT_DROPS"] = "No recent tradeable items found"
L["NO_BAG_ITEMS"] = "No eligible items in bags"
L["EQUIPMENT_ONLY"] = "Equipment Only"
L["SLASH_DESC_ADD"] = "Add item to session"
L["AWARD_LATER_ALL"] = "Award Later (All)"

-- Session Trigger Modes (legacy — kept for backward compat)
L["TRIGGER_MANUAL"] = "Manual (use /loothing start)"
L["TRIGGER_AUTO"] = "Automatic (start immediately)"
L["TRIGGER_PROMPT"] = "Prompt (ask before starting)"

-- Session Trigger Policy (split model)
L["SESSION_TRIGGER_HEADER"] = "Session Trigger"
L["SESSION_TRIGGER_ACTION"] = "Trigger Action"
L["SESSION_TRIGGER_ACTION_DESC"] = "What happens when a boss kill is eligible"
L["SESSION_TRIGGER_TIMING"] = "Trigger Timing"
L["SESSION_TRIGGER_TIMING_DESC"] = "When the trigger action fires relative to the boss kill"
L["TRIGGER_TIMING_ENCOUNTER_END"] = "On Boss Kill"
L["TRIGGER_TIMING_AFTER_LOOT"] = "After ML Receives Loot"
L["TRIGGER_SCOPE_RAID"] = "Raid Bosses"
L["TRIGGER_SCOPE_RAID_DESC"] = "Trigger on raid boss kills"
L["TRIGGER_SCOPE_DUNGEON"] = "Dungeon Bosses"
L["TRIGGER_SCOPE_DUNGEON_DESC"] = "Trigger on dungeon boss kills"
L["TRIGGER_SCOPE_OPEN_WORLD"] = "Open World"
L["TRIGGER_SCOPE_OPEN_WORLD_DESC"] = "Trigger on open-world encounters (e.g. world bosses)"

-- AutoPass Options
L["CONFIG_AUTOPASS_BOE"] = "AutoPass BoE Items"
L["CONFIG_AUTOPASS_BOE_DESC"] = "Automatically pass on Bind on Equip items"
L["CONFIG_AUTOPASS_WEAPONS_DESC"] = "Auto-pass on weapons that don't match your class's primary stat (Strength, Agility, or Intellect)"
L["CONFIG_AUTOPASS_TRINKETS_DESC"] = "Auto-pass on trinkets your class cannot equip or benefit from"
L["CONFIG_AUTOPASS_TRANSMOG"] = "AutoPass Transmog"
L["CONFIG_AUTOPASS_TRANSMOG_DESC"] = "Auto-pass on items whose armor type your class cannot equip"
L["CONFIG_AUTOPASS_TRANSMOG_SOURCE"] = "Skip Known Appearances"
L["CONFIG_AUTOPASS_TRANSMOG_SOURCE_DESC"] = "Auto-pass on items whose appearance you have already collected"

-- Auto Award Options
L["CONFIG_AUTO_AWARD_LOWER_THRESHOLD"] = "Lower Quality Threshold"
L["CONFIG_AUTO_AWARD_LOWER_THRESHOLD_DESC"] = "Minimum item quality for auto-awarding. Items below this quality are ignored."
L["CONFIG_AUTO_AWARD_UPPER_THRESHOLD"] = "Upper Quality Threshold"
L["CONFIG_AUTO_AWARD_UPPER_THRESHOLD_DESC"] = "Maximum item quality for auto-awarding. Items above this quality go through the loot council."
L["CONFIG_AUTO_AWARD_REASON"] = "Award Reason"
L["CONFIG_AUTO_AWARD_REASON_DESC"] = "The reason recorded in loot history when items are auto-awarded"
L["CONFIG_AUTO_AWARD_INCLUDE_BOE"] = "Include BoE Items"
L["CONFIG_AUTO_AWARD_INCLUDE_BOE_DESC"] = "Also auto-award Bind on Equip items within the quality range. When off, BoE items always go through the council."

-- Frame Behavior Options
L["CONFIG_FRAME_BEHAVIOR"] = "Frame Behavior"
L["CONFIG_FRAME_AUTO_OPEN"] = "Auto-Open Frames"
L["CONFIG_FRAME_AUTO_OPEN_DESC"] = "Automatically open the voting and loot frames when a loot council session starts"
L["CONFIG_FRAME_AUTO_CLOSE"] = "Auto-Close Frames"
L["CONFIG_FRAME_AUTO_CLOSE_DESC"] = "Automatically close loot council frames when the session ends or all items are awarded"
L["CONFIG_FRAME_SHOW_SPEC_ICON"] = "Show Spec Icons"
L["CONFIG_FRAME_SHOW_SPEC_ICON_DESC"] = "Display the player's current specialization icon next to their name in the voting frame"
L["CONFIG_FRAME_CLOSE_ESCAPE"] = "Close with Escape"
L["CONFIG_FRAME_CLOSE_ESCAPE_DESC"] = "Allow pressing Escape to close loot council frames. When off, frames can only be closed via the X button."
L["CONFIG_FRAME_CHAT_OUTPUT"] = "Chat Output Frame"
L["CONFIG_FRAME_CHAT_OUTPUT_DESC"] = "Select which chat window Loothing messages are printed to"
L["CONFIG_FRAME_MINIMIZE_COMBAT_DESC"] = "Minimize the main loot council window to a small bar when you enter combat. Restores when combat ends."
L["CONFIG_FRAME_TIMEOUT_FLASH_DESC"] = "Flash the loot frame taskbar icon when the response timer is about to expire"
L["CONFIG_FRAME_BLOCK_TRADES_DESC"] = "Block trade windows from opening while a voting session is active"

-- ML Usage Options
L["CONFIG_ML_USAGE_MODE"] = "Usage Mode"
L["CONFIG_ML_USAGE_MODE_DESC"] = "Controls when Loothing activates. Never: disabled. Group Loot: auto-activate as leader. Ask: prompt before activating."
L["CONFIG_ML_USAGE_NEVER"] = "Never"
L["CONFIG_ML_USAGE_GL"] = "Group Loot"
L["CONFIG_ML_USAGE_ASK_GL"] = "Ask on Group Loot"
L["CONFIG_ML_RAIDS_ONLY"] = "Raids Only"
L["CONFIG_ML_RAIDS_ONLY_DESC"] = "Only activate loot council features in raid groups. Disables ML functionality in dungeons and parties."
L["CONFIG_ML_ALLOW_OUTSIDE"] = "Allow Outside Raids"
L["CONFIG_ML_ALLOW_OUTSIDE_DESC"] = "Allow loot council sessions to start even when not inside a raid instance"
L["CONFIG_ML_SKIP_SESSION"] = "Skip Session Frame"
L["CONFIG_ML_SKIP_SESSION_DESC"] = "Skip the session setup frame and start sessions immediately with all detected loot items"
L["CONFIG_ML_SORT_ITEMS"] = "Sort Items"
L["CONFIG_ML_SORT_ITEMS_DESC"] = "Sort loot items by quality (highest first) in the session and voting frames"
L["CONFIG_ML_AUTO_ADD_BOES"] = "Auto-Add BoEs"
L["CONFIG_ML_AUTO_ADD_BOES_DESC"] = "Automatically add tradeable Bind on Equip items to the loot session alongside BoP items"
L["CONFIG_ML_PRINT_TRADES"] = "Print Completed Trades"
L["CONFIG_ML_PRINT_TRADES_DESC"] = "Print a chat message when a loot trade between players is completed"
L["CONFIG_ML_REJECT_TRADE"] = "Reject Invalid Trades"
L["CONFIG_ML_REJECT_TRADE_DESC"] = "Automatically cancel incoming trade windows from players not in the current loot trade queue"
L["CONFIG_ML_AWARD_LATER"] = "Award Later"
L["CONFIG_ML_AWARD_LATER_DESC"] = "Keep awarded items visible in the session frame, allowing you to change the winner until the session ends"

-- History Options
L["CONFIG_HISTORY_ENABLED_DESC"] = "Record all loot council awards in a persistent history log that you can browse and export"
L["CONFIG_HISTORY_SEND_DESC"] = "Broadcast your loot history to other Loothing users in the raid so they can sync records"
L["CONFIG_HISTORY_SEND_GUILD"] = "Send to Guild"
L["CONFIG_HISTORY_SEND_GUILD_DESC"] = "Also send loot history entries over the guild channel so members not in the raid can sync"
L["CONFIG_HISTORY_SAVE_PL"] = "Save Personal Loot"
L["CONFIG_HISTORY_SAVE_PL_DESC"] = "Record items received via personal loot (not council-awarded) in your history log"

-- Ignore Item Options
L["CONFIG_IGNORE_ENCHANTING_MATS"] = "Ignore Enchanting Materials"
L["CONFIG_IGNORE_ENCHANTING_MATS_DESC"] = "Exclude enchanting materials from loot council sessions"
L["CONFIG_IGNORE_CRAFTING_REAGENTS"] = "Ignore Crafting Reagents"
L["CONFIG_IGNORE_CRAFTING_REAGENTS_DESC"] = "Exclude crafting reagents from loot council sessions"
L["CONFIG_IGNORE_CONSUMABLES"] = "Ignore Consumables"
L["CONFIG_IGNORE_CONSUMABLES_DESC"] = "Exclude consumable items (potions, food, etc.) from loot council sessions"
L["CONFIG_IGNORE_PERMANENT_ENHANCEMENTS"] = "Ignore Permanent Enhancements"
L["CONFIG_IGNORE_PERMANENT_ENHANCEMENTS_DESC"] = "Exclude permanent enhancement items (enchant scrolls, etc.) from loot council sessions"

-- Announcement Options
L["CONFIG_ANNOUNCEMENT_TOKENS_DESC"] = "Available tokens: {item}, {winner}, {reason}, {notes}, {ilvl}, {type}, {oldItem}, {ml}, {session}, {votes}"
L["CONFIG_ANNOUNCE_AWARDS_DESC"] = "Post a message in chat when an item is awarded to a player"
L["CONFIG_ANNOUNCE_ITEMS_DESC"] = "Announce each loot item being considered by the council to chat"
L["CONFIG_ANNOUNCE_BOSS_KILL_DESC"] = "Announce when a loot council session starts and ends"
L["CONFIG_ANNOUNCE_CONSIDERATIONS"] = "Announce Considerations"
L["CONFIG_ANNOUNCE_CONSIDERATIONS_DESC"] = "Announce the candidates and their responses being considered for each item"
L["CONFIG_CONSIDERATIONS_CHANNEL_DESC"] = "The chat channel used for consideration announcements"
L["CONFIG_CONSIDERATIONS_TEXT_DESC"] = "The message template for consideration announcements. Supports standard announcement tokens."
L["CONFIG_ITEM_ANNOUNCEMENTS"] = "Item Announcements"
L["CONFIG_SESSION_ANNOUNCEMENTS"] = "Session Announcements"
L["CONFIG_SESSION_START"] = "Session Start"
L["CONFIG_SESSION_END"] = "Session End"
L["CONFIG_MESSAGE"] = "Message"

-- Button Sets & Type Code Options
L["CONFIG_BUTTON_SETS"] = "Button Sets"
L["CONFIG_TYPECODE_ASSIGNMENT"] = "Type Code Assignment"

-- Award Reasons Options
L["CONFIG_AWARD_REASONS"] = "Award Reasons"
L["NUM_AWARD_REASONS"] = "Number of Reasons"
L["CONFIG_REASON_LOG_DESC"] = "Record awards using this reason in the loot history log"
L["CONFIG_REASON_DISENCHANT_DESC"] = "Mark this reason as a disenchant. Items awarded with this reason are tracked separately."

-- Council Guild Rank Options
L["CONFIG_GUILD_RANK"] = "Guild Rank Auto-Include"
L["CONFIG_GUILD_RANK_DESC"] = "Automatically include guild members at or above a certain rank in the council"
L["CONFIG_MIN_RANK"] = "Minimum Guild Rank"
L["CONFIG_MIN_RANK_DESC"] = "Guild members at this rank or higher will be auto-included as council members. 0 = disabled, 1 = Guild Master, 2 = Officers, etc."
L["CONFIG_COUNCIL_REMOVE_ALL"] = "Remove All Members"

-- Council Table UI
L["CHANGE_RESPONSE"] = "Change Response"

-- Sync Panel UI
L["SYNC_DATA"] = "Sync Data"
L["SELECT_TARGET"] = "Select Target"
L["SELECT_TARGET_FIRST"] = "Select a target player"
L["NO_TARGETS"] = "No online members found"
L["GUILD"] = "Guild (All Online)"
L["QUERY_GROUP"] = "Query Group"
L["LAST_7_DAYS"] = "Last 7 Days"
L["LAST_30_DAYS"] = "Last 30 Days"
L["ALL_TIME"] = "All Time"
L["SYNCING_TO"] = "Syncing %s to %s..."

-- History Panel UI
L["DATE_RANGE"] = "Date Range:"
L["FILTER_BY_WINNER"] = "Filter by %s"
L["DELETE_ENTRY"] = "Delete Entry"

-- Observer System
L["OBSERVER"] = "Observer"

-- ML Observer
L["CONFIG_ML_OBSERVER"] = "ML Observer Mode"
L["CONFIG_ML_OBSERVER_DESC"] = "Master Looter can see everything and manage sessions but cannot vote"

-- Open Observation (replaces OBSERVE_MODE)
L["OPEN_OBSERVATION"] = "Open Observation"
L["OPEN_OBSERVATION_DESC"] = "Allow all raid members to observe voting (adds everyone as an observer)"

-- Observer Permissions
L["OBSERVER_PERMISSIONS"] = "Observer Permissions"
L["OBSERVER_SEE_VOTE_COUNTS"] = "See Vote Counts"
L["OBSERVER_SEE_VOTE_COUNTS_DESC"] = "Observers can see how many votes each candidate has"
L["OBSERVER_SEE_VOTER_IDS"] = "See Voter Identities"
L["OBSERVER_SEE_VOTER_IDS_DESC"] = "Observers can see who voted for each candidate"
L["OBSERVER_SEE_RESPONSES"] = "See Responses"
L["OBSERVER_SEE_RESPONSES_DESC"] = "Observers can see what response each candidate selected"
L["OBSERVER_SEE_NOTES"] = "See Notes"
L["OBSERVER_SEE_NOTES_DESC"] = "Observers can see candidate notes"

-- Bulk Actions
L["BULK_START_VOTE"] = "Start Vote (%d)"
L["BULK_END_VOTE"] = "End Vote (%d)"
L["BULK_SKIP"] = "Skip (%d)"
L["BULK_REMOVE"] = "Remove (%d)"
L["BULK_REVOTE"] = "Re-Vote (%d)"
L["BULK_AWARD_LATER"] = "Award Later"
L["DESELECT_ALL"] = "Deselect"
L["N_SELECTED"] = "%d selected"
L["REMOVE_ITEMS"] = "Remove Items"
L["CONFIRM_BULK_SKIP"] = "Skip %d selected items?"
L["CONFIRM_BULK_REMOVE"] = "Remove %d selected items from the session?"
L["CONFIRM_BULK_REVOTE"] = "Re-vote on %d selected items?"

-- RCV Settings
L["RCV_SETTINGS"] = "Ranked Choice Settings"
L["MAX_RANKS"] = "Maximum Rankings"
L["MIN_RANKS"] = "Minimum Rankings"
L["MAX_RANKS_DESC"] = "Maximum number of choices a voter can rank (0 = unlimited)"
L["MIN_RANKS_DESC"] = "Minimum number of choices required to submit a vote"
L["RANK_LIMIT_REACHED"] = "Maximum %d ranks reached"
L["RANK_MINIMUM_REQUIRED"] = "Rank at least %d choices"
L["MAX_REVOTES"] = "Maximum Re-votes"

-- IRV Round Visualization
L["SHOW_IRV_ROUNDS"] = "Show IRV Rounds (%d rounds)"
L["HIDE_IRV_ROUNDS"] = "Hide IRV Rounds"

-- Settings Export/Import
L["PROFILES"] = "Profiles"
L["EXPORT_SETTINGS"] = "Export Settings"
L["IMPORT_SETTINGS"] = "Import Settings"
L["EXPORT_TITLE"] = "Export Settings"
L["EXPORT_DESC"] = "Press Ctrl+A to select all, then Ctrl+C to copy."
L["EXPORT_FAILED"] = "Export failed: %s"
L["IMPORT_TITLE"] = "Import Settings"
L["IMPORT_DESC"] = "Paste an exported settings string below, then click Import."
L["IMPORT_BUTTON"] = "Import"
L["IMPORT_FAILED"] = "Import failed: %s"
L["IMPORT_VERSION_WARN"] = "Note: exported with Loothing v%s (you have v%s)."
L["IMPORT_SUCCESS_NEW"] = "Settings imported as new profile: %s"
L["IMPORT_SUCCESS_CURRENT"] = "Settings imported to current profile."
L["SLASH_DESC_EXPORT"] = "Export current profile settings"
L["SLASH_DESC_PROFILE"] = "Manage profiles (list, switch, create)"

-- Profile Management
L["PROFILE_CURRENT"] = "Current Profile"
L["PROFILE_SWITCH"] = "Switch Profile"
L["PROFILE_SWITCH_DESC"] = "Select a profile to switch to."
L["PROFILE_NEW"] = "Create New Profile"
L["PROFILE_NEW_DESC"] = "Enter a name for the new profile."
L["PROFILE_COPY_FROM"] = "Copy From"
L["PROFILE_COPY_DESC"] = "Copy settings from another profile into the current one."
L["PROFILE_COPY_CONFIRM"] = "This will overwrite all settings in your current profile. Continue?"
L["PROFILE_DELETE"] = "Delete Profile"
L["PROFILE_DELETE_CONFIRM"] = "Are you sure you want to delete this profile? This cannot be undone."
L["PROFILE_RESET"] = "Reset to Defaults"
L["PROFILE_RESET_CONFIRM"] = "Reset profile '%s' to default settings? This cannot be undone."
L["PROFILE_LIST"] = "All Profiles"
L["PROFILE_DEFAULT_SUFFIX"] = "(default)"
L["PROFILE_EXPORT_INLINE_DESC"] = "Generate an export string, then copy it to share your settings."
L["PROFILE_IMPORT_INLINE_DESC"] = "Paste an exported settings string below, then click Import."
L["PROFILE_SHARE_TARGET"] = "Share To"
L["PROFILE_SHARE_BUTTON"] = "Share"
L["PROFILE_SHARE_DESC"] = "Send the current export string directly to one online group member."
L["PROFILE_SHARE_SENT"] = "Shared current profile with %s."
L["PROFILE_SHARE_RECEIVED"] = "Received shared settings from %s."
L["PROFILE_SHARE_FAILED"] = "Shared settings from %s could not be imported: %s"
L["PROFILE_SHARE_FAILED_GENERIC"] = "Share failed: %s"
L["PROFILE_SHARE_TARGET_REQUIRED"] = "Select a target first."
L["PROFILE_SHARE_UNAVAILABLE"] = "Profile sharing is unavailable."
L["PROFILE_SHARE_BROADCAST_BUTTON"] = "Broadcast to Group"
L["PROFILE_SHARE_BROADCAST_DESC"] = "Broadcast the current export string to the active raid or party. Only the active session's Master Looter can do this."
L["PROFILE_SHARE_BROADCAST_SENT"] = "Broadcast current profile to the active group."
L["PROFILE_SHARE_BROADCAST_CONFIRM"] = "Broadcast your current settings profile to the entire active group?"
L["PROFILE_SHARE_BROADCAST_NO_SESSION"] = "You need an active Loothing session to broadcast settings."
L["PROFILE_SHARE_BROADCAST_NOT_ML"] = "Only the active session's Master Looter can broadcast settings."
L["PROFILE_SHARE_BROADCAST_NO_GROUP"] = "You must be in the active raid or party to broadcast settings."
L["PROFILE_SHARE_BROADCAST_BUSY"] = "The addon comm queue is busy. Try again in a moment."
L["PROFILE_SHARE_BROADCAST_COOLDOWN"] = "Settings were broadcast recently. Try again in %d seconds."
L["PROFILE_SHARE_QUEUE_FULL"] = "Shared settings from %s were dropped because too many other imports are already waiting."
L["PROFILE_LIST_HEADER"] = "Profiles:"
L["PROFILE_SWITCHED"] = "Switched to profile: %s"
L["PROFILE_CREATED"] = "Created and switched to profile: %s"

--[[--------------------------------------------------------------------
    Localization Pass: UI Panels
----------------------------------------------------------------------]]

-- RosterPanel rank names
L["ROSTER_RANK_MEMBER"] = "Member"

-- RosterPanel misc
L["ROSTER_NOT_INSTALLED"] = "Not Installed"
L["ROSTER_NO_ROLE"] = "No Role"

-- RosterPanel tooltip
L["ROSTER_TOOLTIP_ROLE"] = "Role: "
L["ROSTER_TOOLTIP_GROUP"] = "Group: "
L["ROSTER_OFFLINE"] = "Offline"
L["ROSTER_DEAD"] = "Dead"
L["ROSTER_TOOLTIP_VERSION"] = "Loothing: "
L["ROSTER_TOOLTIP_TEST_VERSION"] = "Test Version: "
L["ROSTER_UNKNOWN"] = "Unknown"
L["ROSTER_COUNCIL_MEMBER"] = "Council Member"
L["ROSTER_MASTER_LOOTER"] = "Master Looter"
L["ROSTER_TOOLTIP_LOOT_HISTORY"] = "Loot History: %d items"

-- CouncilTable/Columns
L["COLUMN_ROLE"] = "Role"
L["COLUMN_WON"] = "Won"
L["COLUMN_INST"] = "Inst"
L["COLUMN_WK"] = "Wk"
L["COLUMN_VOTE"] = "Vote"
L["COLUMN_TOOLTIP_WON_SESSION"] = "Items won this session"
L["COLUMN_TOOLTIP_WON_INSTANCE"] = "Items won in this instance + difficulty"
L["COLUMN_TOOLTIP_WON_WEEKLY"] = "Items won this week"
L["RESPONSE_AUTO_PASS"] = "Auto Pass"
L["RESPONSE_WAITING"] = "Waiting..."
L["VOTE_RANK"] = "Rank"
L["VOTE_RANKED"] = "Ranked"
L["VOTE_VOTED"] = "Voted"

-- CouncilTable
L["LOOT_COUNCIL"] = "Loot Council"
L["DISENCHANT_TARGET"] = "Disenchant Target"
L["CLICK_SELECT_ENCHANTER"] = "Click to select an enchanter"
L["CURRENT_COLON"] = "Current: "
L["SELECT_ENCHANTER"] = "Select Enchanter"
L["COUNCIL_VOTING_PROGRESS"] = "Council Voting Progress"
L["NO_ENCHANTERS"] = "No enchanters detected in the group"
L["DISENCHANT_TARGET_SET"] = "Disenchant target set to: %s"
L["DISENCHANT_TARGET_CLEARED"] = "Disenchant target cleared"

-- ResultsPanel
L["NO_COUNCIL_VOTES"] = "No council votes cast"
L["RECOMMENDED"] = "Recommended"
L["VOTES_LABEL"] = "votes"

-- TradePanel
L["TRADE_BTN"] = "Trade"
L["REMOVE_FROM_QUEUE"] = "Remove from queue"

-- AddItemFrame
L["QUEUED_ITEMS_HINT"] = "Queued items will appear here"
L["ILVL_PREFIX"] = "iLvl "

-- SessionPanel
L["AWARD_LATER_ALL_DESC"] = "Set all items to be awarded after the session"
L["REMOVE_FROM_SESSION"] = "Remove from session"
L["AWARD_LATER_SHORT"] = "Later"
L["AWARD_LATER_ITEM_DESC"] = "Mark this item to be awarded after the session"

-- RollFrame/UI
L["LOOT_RESPONSE_TITLE"] = "Loot Response"
L["TOO_MANY_ITEMS_WARNING"] = "Too many items (%d). Only showing buttons for first %d items. Use navigation to access all."
L["EQUIPPED_GEAR"] = "Equipped Gear"
L["NOTE_OPTIONAL"] = "Note (optional):"
L["ADD_NOTE_PLACEHOLDER"] = "Add a note..."

-- CouncilTable/Rows
L["VIEW_GEAR"] = "View Gear"
L["AWARD_FOR"] = "Award For..."

--[[--------------------------------------------------------------------
    Localization Pass: Popups
----------------------------------------------------------------------]]

L["POPUP_CONFIRM_USAGE"] = "Do you want to use Loothing for loot distribution in this raid?"
L["POPUP_CONFIRM_END_SESSION"] = "Are you sure you want to end the current loot session? All pending items will be closed."
L["POPUP_AWARD_LATER"] = "Award {item} to yourself to distribute later?"
L["POPUP_TRADE_ADD_ITEMS"] = "Add {count} awarded items to trade with {player}?"
L["POPUP_TRADE_ADD_SINGLE"] = "Add 1 awarded item to trade with %s?"
L["POPUP_TRADE_ADD_MULTI"] = "Add %d awarded items to trade with %s?"
L["POPUP_KEEP_OR_TRADE"] = "What would you like to do with {item}?"
L["POPUP_KEEP_OR_TRADE_FMT"] = "What would you like to do with %s?"
L["KEEP"] = "Keep"
L["POPUP_SYNC_REQUEST_TITLE"] = "Sync Request"
L["POPUP_SYNC_REQUEST"] = "{player} wants to sync their {type} to you. Accept?"
L["POPUP_SYNC_SETTINGS_FMT"] = "%s wants to sync their Loothing settings to you. Accept?"
L["POPUP_SYNC_HISTORY_FMT"] = "%s wants to sync their loot history (%d days) to you. Accept?"
L["POPUP_SYNC_GENERIC_FMT"] = "%s wants to sync their %s to you. Accept?"
L["ACCEPT"] = "Accept"
L["DECLINE"] = "Decline"
L["UNKNOWN"] = "Unknown"
L["POPUP_IMPORT_OVERWRITE"] = "This import will overwrite {count} existing history entries. Continue?"
L["POPUP_IMPORT_OVERWRITE_SINGLE"] = "This import will overwrite 1 existing history entry. Continue?"
L["POPUP_IMPORT_OVERWRITE_MULTI"] = "This import will overwrite %d existing history entries. Continue?"
L["POPUP_DELETE_HISTORY_SINGLE"] = "Delete 1 history entry? This cannot be undone."
L["POPUP_DELETE_HISTORY_ALL"] = "Delete ALL history entries? This cannot be undone."
L["POPUP_DELETE_HISTORY_MULTI"] = "Delete %d history entries? This cannot be undone."
L["POPUP_DELETE_HISTORY_SELECTED"] = "Delete selected history entries? This cannot be undone."
L["POPUP_CLEAR_COUNCIL_COUNT"] = "Remove all %d council members?"
L["POPUP_CLEAR_COUNCIL"] = "Remove all council members?"
L["POPUP_SKIP_ITEM"] = "Skip {item} without awarding it?"
L["POPUP_SKIP_ITEM_FMT"] = "Skip %s without awarding it?"
L["POPUP_CONFIRM_REVOTE"] = "Clear all votes and restart voting for {item}?"
L["POPUP_CONFIRM_REVOTE_FMT"] = "Clear all votes and restart voting for %s?"
L["POPUP_CLEAR_IGNORED_COUNT"] = "Clear all %d ignored items?"
L["POPUP_CLEAR_IGNORED"] = "Clear all ignored items?"
L["POPUP_REANNOUNCE_TITLE"] = "Re-announce Items"
L["POPUP_REANNOUNCE"] = "Re-announce all items to the group?"
L["POPUP_START_SESSION"] = "Start loot session for {boss}?"
L["POPUP_START_SESSION_FMT"] = "Start loot session for %s?"
L["POPUP_START_SESSION_GENERIC"] = "Start loot session?"
L["POPUP_OVERWRITE_PROFILE_TITLE"] = "Overwrite Profile"
L["POPUP_OVERWRITE_PROFILE"] = "This will overwrite your current profile settings. Continue?"
L["OVERWRITE"] = "Overwrite"
L["POPUP_IMPORT_SETTINGS_TITLE"] = "Import Settings"
L["POPUP_IMPORT_SETTINGS"] = "Choose how to apply the imported settings:"
L["CREATE_NEW_PROFILE"] = "Create New Profile"
L["APPLY_TO_CURRENT"] = "Apply to Current"
L["OK"] = "OK"

--[[--------------------------------------------------------------------
    Localization Pass: ResponseButtonSettingsFrame
----------------------------------------------------------------------]]

L["RESPONSE_BUTTON_EDITOR"] = "Response Button Editor"
L["SET_LABEL"] = "Set:"
L["NEW"] = "New"
L["COPY"] = "Copy"
L["RENAME"] = "Rename"
L["COPY_SUFFIX"] = "(Copy)"
L["POPUP_RENAME_SET"] = "Enter new name for set:"
L["POPUP_DELETE_RESPONSE_SET"] = "Delete this response set? This cannot be undone."
L["DELETE"] = "Delete"
L["CANNOT_DELETE_LAST_SET"] = "Cannot delete the last response set."
L["POPUP_RESET_ALL_SETS"] = "Reset ALL response sets to defaults? This cannot be undone."
L["RESET"] = "Reset"
L["NEW_BUTTON"] = "New Button"
L["LESS"] = "Less"
L["EDIT"] = "Edit"
L["POPUP_DELETE_RESPONSE_BUTTON"] = "Delete this response button?"
L["DISPLAY_TEXT_LABEL"] = "Display Text:"
L["RESPONSE_TEXT_LABEL"] = "Response Text:"
L["ICON_LABEL"] = "Icon:"
L["WHISPER_KEYS_LABEL"] = "Whisper Keys:"
L["ICON_SET"] = "Icon: ✓"
L["PICK_ICON"] = "Pick Icon…"

--[[--------------------------------------------------------------------
    Localization Pass: Options (SessionSettings, LocalPreferences, ProfileOptions)
----------------------------------------------------------------------]]

-- SessionSettings
L["CONFIG_SESSION_BROADCAST_DESC"] = "These settings are broadcast to all raid members when you are the Master Looter. They control the session for everyone."
L["CONFIG_SESSION_BROADCAST_NOTE"] = "These settings are broadcast to all raid members when you start a session as Master Looter."
L["CONFIG_VOTING_TIMEOUT_DESC"] = "When disabled, voting runs until the ML manually ends it."
L["CONFIG_TRIGGER_SCOPE_NOTE"] = "PvP, arena, and scenario encounters never trigger sessions. Raid-only is the default."
L["GROUP_LOOT_MODE"] = "Loot Roll Handling"
L["GROUP_LOOT_MODE_DESC"] = "Choose whether Loothing auto-rolls for the raid or leaves Blizzard's native roll window in control during the session."
L["GROUP_LOOT_MODE_ACTIVE"] = "Active: Loothing auto-rolls"
L["GROUP_LOOT_MODE_PASSIVE"] = "Passive: Use WoW rolls"
L["CONFIG_BUTTON_SETS_DESC"] = "Configure response button sets, icons, whisper keys, and type-code assignments using the visual editor."
L["CONFIG_OPEN_BUTTON_EDITOR"] = "Open Response Button Editor"
L["CONFIG_MAX_REVOTES_DESC"] = "Maximum number of re-votes allowed per item (0 = no re-votes)"
L["CONFIG_COUNCIL_NO_MEMBERS"] = "No council members added yet."
L["CONFIG_COUNCIL_ADD_HELP"] = "Council members can vote on loot distribution. Use the field below to add members by name."
L["CONFIG_COUNCIL_ADD_NAME_DESC"] = "Enter character name (e.g., 'Playername' or 'Playername-Realm')"
L["CONFIG_COUNCIL_REMOVE_DESC"] = "Select a member to remove from the council"
L["CONFIG_COUNCIL_MEMBER_REMOVED"] = "%s removed from council"
L["CONFIG_COUNCIL_CONFIRM_REMOVE"] = "Remove %s from the council?"
L["CONFIG_COUNCIL_ALL_REMOVED"] = "All council members removed"
L["CONFIG_COUNCIL_CONFIRM_REMOVE_ALL"] = "Remove ALL council members?"
L["CONFIG_AWARD_REASONS_ENABLED_DESC"] = "Enable or disable the award reasons system"
L["CONFIG_REQUIRE_AWARD_REASON_DESC"] = "Require an award reason to be selected before awarding an item"
L["CONFIG_OBSERVER_PERMISSIONS_DESC"] = "Control what observers can see during voting sessions."
L["CONFIG_REASON_DEFAULT"] = "Reason"
L["REMOVE"] = "Remove"
L["CONFIG_CONFIRM_REMOVE_REASON"] = "Remove this award reason?"
L["CONFIG_REASONS"] = "Reasons"
L["CONFIG_MANAGE"] = "Manage"
L["CONFIG_NEW_REASON_DEFAULT"] = "New Reason"
L["CONFIG_CONFIRM_RESET_REASONS"] = "Reset all award reasons to their default values? This cannot be undone."

-- LocalPreferences
L["QUALITY_POOR"] = "Poor"
L["QUALITY_COMMON"] = "Common"
L["QUALITY_UNCOMMON"] = "Uncommon"
L["QUALITY_RARE"] = "Rare"
L["QUALITY_EPIC"] = "Epic"
L["QUALITY_LEGENDARY"] = "Legendary"
L["QUALITY_ARTIFACT"] = "Artifact"
L["QUALITY_HEIRLOOM"] = "Heirloom"
L["QUALITY_UNKNOWN"] = "Unknown"
L["CONFIG_LOCAL_PREFS_DESC"] = "These settings only affect you. They are not broadcast to the raid."
L["CONFIG_LOCAL_PREFS_NOTE"] = " These settings only affect your client. They are never sent to other raid members."
L["CONFIG_ROLLFRAME_TIMER_ENABLED_DESC"] = "Show a countdown timer on the response frame. When disabled, the frame stays open until you respond or the ML ends voting."
L["CONFIG_HISTORY_ALL_CLEARED"] = "All history cleared"

-- ProfileOptions
L["PROFILE_ERR_NOT_STRING"] = "Name must be a string"
L["PROFILE_ERR_EMPTY"] = "Name cannot be empty"
L["PROFILE_ERR_TOO_LONG"] = "Name must be 48 characters or fewer"
L["PROFILE_ERR_INVALID_CHARS"] = "Name contains invalid characters"

--[[--------------------------------------------------------------------
    Localization Pass: Comm / Core / Modules
----------------------------------------------------------------------]]

-- Sync
L["SYNC_SETTINGS_TO_GUILD"] = "Requesting settings sync to guild..."
L["SYNC_SETTINGS_TO_PLAYER"] = "Requesting settings sync to %s"
L["SYNC_SETTINGS_COMPLETED"] = "Settings sync completed to %d recipients"
L["SYNC_ACCEPTED_FROM"] = "Accepted sync from %s"
L["SYNC_SETTINGS_SENT"] = "Sent settings to %s"
L["SYNC_SETTINGS_APPLIED"] = "Applied settings from %s"
L["SYNC_HISTORY_GUILD_DAYS"] = "Requesting history sync (%d days) to guild..."
L["SYNC_HISTORY_TO_PLAYER"] = "Requesting history sync (%d days) to %s"
L["SYNC_HISTORY_COMPLETED"] = "History sync completed to %d recipients"
L["SYNC_HISTORY_SENT"] = "Sent %d history entries to %s"

-- ItemFilter categories
L["ITEM_CATEGORY_CONSUMABLE"] = "Consumable"
L["ITEM_CATEGORY_ENCHANTING"] = "Enchanting Material"
L["ITEM_CATEGORY_CRAFTING"] = "Crafting Reagent"
L["ITEM_CATEGORY_TRADE_GOODS"] = "Trade Goods"
L["ITEM_CATEGORY_GEM"] = "Gem"

-- AutoAward
L["AUTO_AWARD_TARGET_NOT_IN_RAID"] = "Auto-award target %s is not in the raid"

-- Announcer defaults
L["ANN_CONSIDERATIONS_DEFAULT"] = "{ml} is considering {item} for distribution"
L["SESSION_STARTED_DEFAULT"] = "Loot council session started"
L["SESSION_ENDED_DEFAULT"] = "Loot council session ended"

-- VersionCheck
L["VERSION_CHECK_IN_PROGRESS"] = "Version check already in progress"
L["NOT_IN_GUILD"] = "You are not in a guild"
L["NOT_IN_GROUP"] = "You are not in a raid or party"
L["VERSION_OUTDATED_MEMBERS"] = "|cffff9900%d group member(s) have outdated Loothing:|r %s"
L["VERSION_AND_MORE"] = " and %d more"
L["VERSION_RESULTS_TOTAL"] = "Version Check Results: %d total"
L["VERSION_RESULTS_CURRENT"] = "  Up to date: %d"
L["VERSION_RESULTS_TEST"] = "  |cff00ff00Test versions: %d|r"
L["VERSION_RESULTS_OUTDATED"] = "  |cffff0000Outdated: %d|r"
L["VERSION_RESULTS_NOT_INSTALLED"] = "  |cff888888Not Installed: %d|r"
L["VERSION_RESULTS_HINT"] = "Use /lt version show to see detailed results"

-- TradeQueue
L["TRADE_ITEMS_PENDING"] = "You have %d item(s) to trade to %s. Click items to add them to the trade window."
L["TRADE_TOO_MANY_ITEMS"] = "Too many items to trade - only first 6 will be added."
L["TRADE_ITEM_NOT_FOUND"] = "Could not find item to trade: %s"
L["TRADE_ITEM_LOCKED"] = "Item is locked: %s"
L["TRADE_COMPLETED"] = "Traded %s to %s"
L["TRADE_WRONG_RECIPIENT"] = "Warning: Traded %s to %s (was awarded to %s)"
L["TRADE_WINDOW_WARNING"] = "|cffff9900Warning:|r Trade window for %s (awarded to %s) expires in %d minutes!"
L["TRADE_WINDOW_URGENT"] = "|cffff0000URGENT:|r Trade window for %s (awarded to %s) expires in %d minutes!"

-- SettingsExport
L["IMPORT_SUMMARY"] = "Profile: %s | Exported: %s | Version: %s"

--[[--------------------------------------------------------------------
    Keys accessed via Loothing.Locale["KEY"] (not L["KEY"])
----------------------------------------------------------------------]]

-- Session / Awards
L["SESSION_STARTED"] = "Loot council session started for %s"
L["SESSION_ENDED"] = "Loot council session ended"
L["AWARD_TO"] = "Award to %s"
L["AWARDED_TO"] = "Awarded to: %s"
L["AWARD_NO_REASON"] = "Award (No Reason)"
L["SELECT_AWARD_REASON"] = "Select Award Reason"

-- History / Results
L["ENTRIES_COUNT"] = "Total: %d entries"
L["ENTRIES_FILTERED"] = "Showing: %d of %d entries"
L["LOOTED_BY"] = "Looted by: %s"
L["FROM_ENCOUNTER"] = "From: %s"
L["TOTAL_VOTES"] = "Total: %d votes"
L["WITH_VOTES"] = "Votes: %d"
L["YOUR_RANKING"] = "Your Ranking"
L["NO_SELECTION"] = "No selection"
L["TAB_SETTINGS"] = "Settings"

-- Trade
L["CLEARED_TRADES"] = "Cleared %d completed trade(s)"
L["NO_COMPLETED_TRADES"] = "No completed trades to clear"

-- Voting / Council
L["OBSERVE_MODE_MSG"] = "You are in observe mode and cannot cast votes."
L["VOTE_NOTE_REQUIRED"] = "You must add a note with your vote."
L["SELF_VOTE_DISABLED"] = "Self-voting is disabled for this session."

-- Award Reason Editor (Work Stream 1)
L["AWARD_REASON_EDITOR"] = "Award Reason Editor"
L["CONFIG_AWARD_REASONS_EDITOR_DESC"] = "Configure award reasons that appear when the Master Looter awards an item."
L["CONFIG_OPEN_AWARD_REASON_EDITOR"] = "Open Editor"
L["MAX_REASONS"] = "Maximum of 20 reasons reached."
L["MIN_REASONS"] = "Cannot delete the last reason."
L["POPUP_DELETE_AWARD_REASON"] = "Delete this award reason?"
L["POPUP_RESET_ALL_REASONS"] = "Reset all award reasons to defaults? This cannot be undone."

-- Settings Audit (Work Stream 4B)
L["CONFIG_ML_GUILD_ONLY"] = "Guild Groups Only"
L["CONFIG_ML_GUILD_ONLY_DESC"] = "Only enable automatic group loot handling in guild groups"
L["CONFIG_HISTORY_MAX_ENTRIES"] = "Max History Entries"
L["CONFIG_HISTORY_MAX_ENTRIES_DESC"] = "Maximum number of loot history entries to keep. Oldest entries are pruned when this limit is reached."
L["NONE"] = "None"

return L
