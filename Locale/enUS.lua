--[[--------------------------------------------------------------------
    Loothing - Loot Council Addon for WoW 12.0+
    Locale - English (US) localization
----------------------------------------------------------------------]]

local L = {}

-- General
L["ADDON_NAME"] = "Loothing"
L["ADDON_LOADED"] = "Loothing v%s loaded. Type /loothing or /lt for options."
L["SLASH_HELP"] = "Commands: /loothing [show|hide|config|history|council]"

-- Session
L["SESSION"] = "Session"
L["SESSION_START"] = "Start Session"
L["SESSION_END"] = "End Session"
L["SESSION_ACTIVE"] = "Session Active"
L["SESSION_INACTIVE"] = "No Active Session"
L["SESSION_STARTED"] = "Loot council session started for %s"
L["SESSION_ENDED"] = "Loot council session ended"
L["SESSION_CLOSED"] = "Session Closed"
L["NO_ITEMS"] = "No items in session"
L["MANUAL_SESSION"] = "Manual Session"
L["ITEMS_COUNT"] = "%d items (%d pending, %d voting, %d done)"
L["YOU_ARE_ML"] = "You are Master Looter"
L["ML_IS"] = "ML: %s"
L["REFRESH"] = "Refresh"
L["ITEM"] = "Item"
L["STATUS"] = "Status"
L["START_ALL"] = "Start All"
L["DATE"] = "Date"

-- Voting
L["VOTE"] = "Vote"
L["VOTING"] = "Voting"
L["VOTE_NOW"] = "Vote Now"
L["START_VOTE"] = "Start Vote"
L["VOTING_OPEN"] = "Voting open for %s"
L["VOTING_CLOSED"] = "Voting closed"
L["VOTES_RECEIVED"] = "%d/%d votes received"
L["TIME_REMAINING"] = "%d seconds remaining"
L["SUBMIT_VOTE"] = "Submit Vote"
L["CHANGE_VOTE"] = "Change Vote"
L["VOTE_SUBMITTED"] = "Vote submitted"
L["ALREADY_VOTED"] = "You have already voted on this item"

-- Responses
L["NEED"] = "Need"
L["GREED"] = "Greed"
L["OFFSPEC"] = "Offspec"
L["TRANSMOG"] = "Transmog"
L["PASS"] = "Pass"

-- Response descriptions
L["NEED_DESC"] = "Main spec upgrade"
L["GREED_DESC"] = "General interest"
L["OFFSPEC_DESC"] = "Offspec or alt"
L["TRANSMOG_DESC"] = "Appearance only"
L["PASS_DESC"] = "Not interested"

-- Awards
L["AWARD"] = "Award"
L["AWARD_TO"] = "Award to %s"
L["AWARD_ITEM"] = "Award Item"
L["CONFIRM_AWARD"] = "Award %s to %s?"
L["ITEM_AWARDED"] = "%s awarded to %s"
L["SKIP_ITEM"] = "Skip Item"
L["ITEM_SKIPPED"] = "Item skipped"
L["DISENCHANT"] = "Disenchant"

-- Results
L["RESULTS"] = "Results"
L["WINNER"] = "Winner"
L["NO_VOTES"] = "No votes received"
L["TIE"] = "Tie"
L["TIE_BREAKER"] = "Tie breaker required"

-- Council
L["COUNCIL"] = "Council"
L["COUNCIL_MEMBERS"] = "Council Members"
L["ADD_MEMBER"] = "Add Member"
L["REMOVE_MEMBER"] = "Remove Member"
L["NOT_COUNCIL"] = "You are not a council member"
L["IS_COUNCIL"] = "%s is a council member"
L["COUNCIL_ONLY"] = "Only council members can vote"
L["AUTO_OFFICERS"] = "Auto-include officers"
L["AUTO_RAID_LEADER"] = "Auto-include raid leader"

-- History
L["HISTORY"] = "History"
L["LOOT_HISTORY"] = "Loot History"
L["NO_HISTORY"] = "No loot history"
L["CLEAR_HISTORY"] = "Clear History"
L["CONFIRM_CLEAR"] = "Clear all loot history?"
L["CONFIRM_CLEAR_HISTORY"] = "Clear all loot history?"
L["EXPORT"] = "Export"
L["EXPORT_HISTORY"] = "Export History"
L["EXPORT_EQDKP"] = "EQdkp"
L["EXPORT_EQDKP_DESC"] = "Export to EQdkp-Plus XML format"
L["ENTRIES_COUNT"] = "Total: %d entries"
L["ENTRIES_FILTERED"] = "Showing: %d of %d entries"
L["SEARCH"] = "Search..."
L["SELECT_ALL"] = "Select All"
L["ALL_WINNERS"] = "All Winners"
L["AWARDED_TO"] = "Awarded to: %s"
L["FROM_ENCOUNTER"] = "From: %s"
L["WITH_VOTES"] = "Votes: %d"
L["CLEAR"] = "Clear"

-- Tabs
L["TAB_SESSION"] = "Session"
L["TAB_HISTORY"] = "History"
L["TAB_SETTINGS"] = "Settings"

-- Settings
L["SETTINGS"] = "Settings"
L["GENERAL"] = "General"
L["VOTING_SETTINGS"] = "Voting Settings"
L["COUNCIL_SETTINGS"] = "Council Settings"
L["UI_SETTINGS"] = "UI Settings"
L["VOTING_MODE"] = "Voting Mode"
L["MODE_SIMPLE"] = "Simple (Most votes wins)"
L["MODE_RANKED"] = "Ranked Choice"
L["SIMPLE_VOTING"] = "Simple (Most votes wins)"
L["RANKED_VOTING"] = "Ranked Choice"
L["VOTING_TIMEOUT"] = "Voting Timeout"
L["SECONDS"] = "seconds"
L["AUTO_START"] = "Auto-start session on boss kill"
L["AUTO_START_SESSION"] = "Auto-start session on boss kill"
L["AUTO_INCLUDE_OFFICERS"] = "Auto-include officers"
L["AUTO_INCLUDE_LEADER"] = "Auto-include raid leader"
L["SHOW_MINIMAP"] = "Show minimap button"
L["SHOW_MINIMAP_BUTTON"] = "Show minimap button"
L["UI_SCALE"] = "UI Scale"
L["ADD"] = "Add"

-- Auto-Pass
L["AUTOPASS_SETTINGS"] = "Auto-Pass Settings"
L["ENABLE_AUTOPASS"] = "Enable Auto-Pass"
L["AUTOPASS_DESC"] = "Automatically pass on items you cannot use"
L["AUTOPASS_WEAPONS"] = "Auto-pass weapons (wrong primary stats)"
L["AUTOPASS_BOE"] = "Auto-pass Bind-on-Equip items"
L["AUTOPASS_TRANSMOG"] = "Auto-pass known transmog appearances"

-- Errors
L["ERROR_NOT_IN_RAID"] = "You must be in a raid"
L["ERROR_NOT_LEADER"] = "You must be the raid leader or assistant"
L["ERROR_NO_ITEM"] = "No item selected"
L["ERROR_SESSION_ACTIVE"] = "A session is already active"
L["ERROR_NO_SESSION"] = "No active session"
L["ERROR_VOTING_ACTIVE"] = "Voting is already in progress"
L["ERROR_SYNC_FAILED"] = "Failed to sync with raid leader"

-- Communication
L["SYNCING"] = "Syncing..."
L["SYNC_COMPLETE"] = "Sync complete"
L["SYNC_REQUEST"] = "Requesting sync from raid leader"

-- Guild Sync
L["SYNC_SETTINGS"] = "Sync Settings"
L["SYNC_HISTORY"] = "Sync History"
L["SYNC_SETTINGS_GUILD"] = "Sync Settings to Guild"
L["SYNC_HISTORY_GUILD"] = "Sync History to Guild"
L["SYNC_SETTINGS_REQUEST"] = "%s wants to sync their settings to you"
L["SYNC_HISTORY_REQUEST"] = "%s wants to sync their history (%d days) to you"
L["ACCEPT_SYNC"] = "Accept Sync"
L["DECLINE_SYNC"] = "Decline Sync"
L["SETTINGS_SYNCED"] = "Settings synced from %s"
L["HISTORY_SYNCED"] = "%d history entries synced from %s"
L["SYNC_IN_PROGRESS"] = "Sync already in progress"
L["SYNC_TIMEOUT"] = "Sync timed out"
L["SYNC_DAYS"] = "Days of history"

-- Tooltips
L["TOOLTIP_ITEM_LEVEL"] = "Item Level: %d"
L["TOOLTIP_LOOTER"] = "Looted by: %s"
L["TOOLTIP_VOTES"] = "Votes: %d"
L["TOOLTIP_STATUS"] = "Status: %s"

-- Status
L["STATUS_PENDING"] = "Pending"
L["STATUS_VOTING"] = "Voting"
L["STATUS_TALLIED"] = "Tallied"
L["STATUS_AWARDED"] = "Awarded"
L["STATUS_SKIPPED"] = "Skipped"

-- Response Settings
L["RESPONSE_SETTINGS"] = "Response Settings"
L["RESET_RESPONSES"] = "Reset to Defaults"

-- Minimap
L["MINIMAP_LEFT_CLICK"] = "Left-click to toggle window"
L["MINIMAP_RIGHT_CLICK"] = "Right-click for options"

-- Make locale available globally
LOOTHING_LOCALE = L

-- Return for module use
return L
