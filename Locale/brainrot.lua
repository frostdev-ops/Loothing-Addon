--[[--------------------------------------------------------------------
    Loothing - "Brainrot Mode" string overlay
    Internet slang translations overlaid on the real locale via metatable.
    Toggle: Settings > Personal Preferences > Brainrot Mode
----------------------------------------------------------------------]]

local ADDON_NAME, ns = ...

local B = {}
ns.BrainrotStrings = B

-- BRAINROT TRANSLATION - PEAK INTERNET SLANG EDITION

-- General
B["ADDON_NAME"] = "Loothing"
B["ADDON_LOADED"] = "Yo fr fr Loothing v%s just dropped. Type /lt to see the bussin settings, no cap."
B["ADDON_TAGLINE"] = "Built different"
B["SLASH_HELP_HEADER"] = "Fr fr use /lt help <command>, ain't rocket science:"
B["SLASH_HELP_DETAIL"] = "Usage for /lt %s periodt:"
B["SLASH_HELP_UNKNOWN"] = "Bruh what is '%s'? Giving L energy. Use /lt help smh."
B["SLASH_HELP_DEBUG_NOTE"] = "Bro enable /lt debug to unlock sigma commands fr fr."
B["SLASH_NO_MAINFRAME"] = "Main window cap hasn't loaded yet bestie."
B["SLASH_NO_CONFIG"] = "Nah that's not available rn (skill issue)."
B["SLASH_INVALID_ITEM"] = "Ong that item link is mid fr."
B["SLASH_SYNC_UNAVAILABLE"] = "Sync module hitting different but not available rn."
B["SLASH_IMPORT_UNAVAILABLE"] = "Nah skibidi that ain't loaded."
B["SLASH_IMPORT_PROMPT"] = "Drop that CSV/TSV: /lt import <data> no cap"
B["SLASH_IMPORT_PARSE_ERROR"] = "Parse error got you: %s this aint it chief"
B["SLASH_IMPORT_SUCCESS"] = "Imported %d entries, you're lowkey goated fr."
B["SLASH_IMPORT_FAILED"] = "RIP import failed bruh: %s L moment"
B["SLASH_DEBUG_STATE"] = "Sigma vibes activated: %s"
B["SLASH_DEBUG_REQUIRED"] = "Gotta enable /lt debug first, don't be mid."
B["SLASH_TEST_UNAVAILABLE"] = "Nah that's not available no cap."
B["SLASH_DESC_SHOW"] = "W moment"
B["SLASH_DESC_HIDE"] = "L moment"
B["SLASH_DESC_TOGGLE"] = "Based behavior"
B["SLASH_DESC_CONFIG"] = "Customize your sigma grind"
B["SLASH_DESC_HISTORY"] = "Look at your Ws"
B["SLASH_DESC_COUNCIL"] = "Gather your homies"
B["SLASH_DESC_ML"] = "The ultimate sigma"
B["SLASH_DESC_IGNORE"] = "Giving trash energy"
B["SLASH_DESC_SYNC"] = "Share the sigma energy"
B["SLASH_DESC_IMPORT"] = "No skill required"
B["SLASH_DESC_DEBUG"] = "Main character energy only"
B["SLASH_DESC_TEST"] = "For the sigma grinders"
B["SLASH_DESC_TESTMODE"] = "Built different"
B["SLASH_DESC_HELP"] = "You got this bro"
B["SLASH_DESC_START"] = "Let's get this bread"
B["SLASH_DESC_STOP"] = "Pack it up"
B["SLASH_DESC_ADD"] = "Drop the loot in"
B["SLASH_DESC_ERRORS"] = "The L receipts"
B["SLASH_DESC_LOG"] = "What went down"
B["SLASH_DESC_EXPORT"] = "Share your sigma config"
B["SLASH_DESC_PROFILE"] = "Organize the grind"

-- Session
B["SESSION_ACTIVE"] = "We eating fr fr"
B["SESSION_CLOSED"] = "Moving on to the next W"
B["NO_ITEMS"] = "The drought is REAL fr"
B["MANUAL_SESSION"] = "Big sigma energy"
B["ITEMS_COUNT"] = "Let's get this bread: %d drips (%d pending, %d voting, %d done)"
B["YOU_ARE_ML"] = "Main character energy unlocked"
B["ML_IS"] = "This dude got the drip: %s"
B["ML_IS_EXPLICIT"] = "Big man assigned: %s"
B["ML_IS_RAID_LEADER"] = "Raid leader sigma: %s"
B["ML_NOT_SET"] = "We're not organized fr (skill issue)"
B["ML_CLEARED"] = "L move but we adapt"
B["ML_ASSIGNED"] = "They're built different: %s"
B["ML_HANDLING_LOOT"] = "Sigma mode engaged no cap."
B["ML_NOT_ACTIVE_SESSION"] = "Ain't active rn. Use '/loothing start' to manually engage fr."
B["ML_USAGE_PROMPT_TEXT"] = "Sigma choice: use Loothing?"
B["ML_USAGE_PROMPT_TEXT_INSTANCE"] = "Let's get this bread for %s?"
B["ML_STOPPED_HANDLING"] = "Sigma mode deactivated."
B["RECONNECT_RESTORED"] = "We back like we never left fr."
B["ERROR_NOT_ML_OR_RL"] = "Only the ML or Raid Leader can do this periodt"
B["REFRESH"] = "Let me see that tea"
B["ITEM"] = "The drip"
B["STATUS"] = "How's the grind"
B["START_ALL"] = "Let's get this bread fam"
B["DATE"] = "When it went down"

-- Voting
B["VOTE"] = "Drop your opinion king"
B["VOTING"] = "Democracy hits different"
B["START_VOTE"] = "Time to decide things"
B["TIME_REMAINING"] = "Speedrun it bestie (%d sec)"
B["SUBMIT_VOTE"] = "Lock it in"
B["SUBMIT_RESPONSE"] = "Facts only"
B["CHANGE_VOTE"] = "Nah this ain't it"

-- Awards
B["AWARD"] = "Periodt that's yours"
B["AWARD_ITEM"] = "Who's gonna slay with this"
B["CONFIRM_AWARD"] = "Lock it in homie: %s to %s?"
B["ITEM_AWARDED"] = "That's the move fr fr: %s to %s"
B["SKIP_ITEM"] = "Nah this mid"
B["DISENCHANT"] = "Turn this to stardust no cap"

-- Results
B["RESULTS"] = "Here's the tea"
B["WINNER"] = "Main character energy"
B["TIE"] = "Both hitting different"

-- Council
B["COUNCIL"] = "The homie squad"
B["COUNCIL_MEMBERS"] = "The real ones fr"
B["ADD_MEMBER"] = "Bring the sigma"
B["REMOVE_MEMBER"] = "They lost the vibe check"
B["IS_COUNCIL"] = "Main character energy: %s"
B["AUTO_OFFICERS"] = "The real G squad"
B["AUTO_RAID_LEADER"] = "Automatically goated"

-- History
B["HISTORY"] = "The highlight reel"
B["NO_HISTORY"] = "Fresh start energy"
B["CLEAR_HISTORY"] = "Forget your Ls"
B["CONFIRM_CLEAR_HISTORY"] = "No cap this is permanent?"
B["EXPORT"] = "Share the drip"
B["EXPORT_HISTORY"] = "Let's show em the goods"
B["EXPORT_EQDKP"] = "Old head format fr"
B["SEARCH"] = "Find that specific drip..."
B["SELECT_ALL"] = "Grab everything no cap"
B["ALL_WINNERS"] = "These dudes are goated"
B["CLEAR"] = "Reset this vibe"

-- Tabs
B["TAB_SESSION"] = "Let's go"
B["TAB_TRADE"] = "The economy hits different"
B["TAB_HISTORY"] = "The receipts"
B["TAB_ROSTER"] = "The squad check"
B["ROSTER_SUMMARY"] = "%d Fam | %d Vibing | %d Got the App | %d Council"
B["ROSTER_NO_GROUP"] = "No squad detected fr fr"
B["ROSTER_QUERY_VERSIONS"] = "Who's up to date"
B["ROSTER_ADD_COUNCIL"] = "You're in the inner circle"
B["ROSTER_REMOVE_COUNCIL"] = "You fell off"
B["ROSTER_SET_ML"] = "Main character energy"
B["ROSTER_CLEAR_ML"] = "NPC arc"
B["ROSTER_PROMOTE_LEADER"] = "W rizz"
B["ROSTER_PROMOTE_ASSISTANT"] = "Side quest approved"
B["ROSTER_DEMOTE"] = "L moment"
B["ROSTER_UNINVITE"] = "Ratio + you're out"
B["ROSTER_ADD_OBSERVER"] = "Lurker pass"
B["ROSTER_REMOVE_OBSERVER"] = "No more lurking"

-- Settings
B["SETTINGS"] = "Personalize the grind"
B["GENERAL"] = "The vibe setup"
B["VOTING_MODE"] = "How we decide"
B["SIMPLE_VOTING"] = "Most votes wins periodt"
B["RANKED_VOTING"] = "Sigma tier voting fr"
B["VOTING_TIMEOUT"] = "Hurry up bestie"
B["SECONDS"] = "Tick tock"
B["AUTO_INCLUDE_OFFICERS"] = "Respect the rank"
B["AUTO_INCLUDE_LEADER"] = "Leader automatically invited"
B["ADD"] = "Bring it in"

-- Auto-Pass
B["AUTOPASS_SETTINGS"] = "Mid gear protection"
B["ENABLE_AUTOPASS"] = "Filter the trash fr"
B["AUTOPASS_DESC"] = "Skill issue detection for gear you can't use"
B["AUTOPASS_WEAPONS"] = "Wrong stats = L move"

-- Announcement Settings
B["ANNOUNCEMENT_SETTINGS"] = "Let the world know"
B["ANNOUNCE_AWARDS"] = "Flex the Ws"
B["ANNOUNCE_ITEMS"] = "Drop incoming"
B["ANNOUNCE_BOSS_KILL"] = "Slay or stay home"
B["CHANNEL_RAID"] = "Everyone gets the tea"
B["CHANNEL_RAID_WARNING"] = "IMPORTANT ANNOUNCEMENT ENERGY"
B["CHANNEL_OFFICER"] = "Inner circle only"
B["CHANNEL_GUILD"] = "Whole fam eats fr"
B["CHANNEL_PARTY"] = "Squad goals"
B["CHANNEL_NONE"] = "Keep it lowkey"

-- Auto-Award
B["AUTO_AWARD_SETTINGS"] = "Automatic sigma moves"
B["AUTO_AWARD_ENABLE"] = "Ez mode activated"
B["AUTO_AWARD_DESC"] = "Skill issue gear be gone"
B["AUTO_AWARD_TO"] = "Where the mid goes fr"
B["AUTO_AWARD_TO_DESC"] = "Player name or 'disenchanter'"

-- Ignore Items
B["IGNORE_ITEMS_SETTINGS"] = "Mid gear blacklist"
B["ENABLE_IGNORE_LIST"] = "Filter the smoke"
B["IGNORE_LIST_DESC"] = "Not even worth tracking fr"
B["IGNORED_ITEMS"] = "The trash we ignore"
B["NO_IGNORED_ITEMS"] = "Everything's potentially valid fr"
B["ADD_IGNORED_ITEM"] = "Blacklist this mid"
B["REMOVE_IGNORED_ITEM"] = "Maybe it had potential"
B["ITEM_IGNORED"] = "It's mid fr: %s"
B["ITEM_UNIGNORED"] = "Actually maybe we want it: %s"
B["SLASH_IGNORE"] = "/lt ignore [link] - No cap this filter is fire"
B["CLEAR_IGNORED_ITEMS"] = "Unblacklist everything"
B["CONFIRM_CLEAR_IGNORED"] = "You sure bout this?"
B["IGNORED_ITEMS_CLEARED"] = "Fresh start fr"
B["IGNORE_CATEGORIES"] = "Sort the mid from the bussin"
B["IGNORE_ADD_DESC"] = "Paste an item link or enter an ID bestie."

-- Common UI
B["CLOSE"] = "Bounce"
B["CANCEL"] = "Nah"
B["NO_LIMIT"] = "No cap"

-- Personal Preferences
B["PERSONAL_PREFERENCES"] = "Your Vibe Settings"
B["CONFIG_LOOT_RESPONSE"] = "Your answer energy"
B["CONFIG_ROLLFRAME_AUTO_SHOW"] = "Pop up when it's time"
B["CONFIG_ROLLFRAME_AUTO_SHOW_DESC"] = "So you don't miss the bag"
B["CONFIG_ROLLFRAME_AUTO_ROLL"] = "Let it rip"
B["CONFIG_ROLLFRAME_AUTO_ROLL_DESC"] = "Sigma efficiency for /roll"
B["CONFIG_ROLLFRAME_GEAR_COMPARE"] = "The drip check"
B["CONFIG_ROLLFRAME_GEAR_COMPARE_DESC"] = "See if you're cooked"
B["CONFIG_ROLLFRAME_REQUIRE_NOTE"] = "Explain yourself"
B["CONFIG_ROLLFRAME_REQUIRE_NOTE_DESC"] = "No free passes fr"
B["CONFIG_ROLLFRAME_PRINT_RESPONSE"] = "Keep the receipts"
B["CONFIG_ROLLFRAME_PRINT_RESPONSE_DESC"] = "Print your submitted response to chat for personal reference"
B["CONFIG_ROLLFRAME_TIMER"] = "The clock is ticking"
B["CONFIG_ROLLFRAME_TIMER_ENABLED"] = "Countdown energy"
B["CONFIG_ROLLFRAME_TIMER_DURATION"] = "How long you got"

-- Session Settings (ML)
B["SESSION_SETTINGS_ML"] = "The boss settings"
B["VOTING_TIMEOUT_DURATION"] = "Tick tock"

-- Errors
B["ERROR_NO_SESSION"] = "Start one first sigma"

-- Communication
B["SYNC_COMPLETE"] = "We're on the same page fr"

-- Guild Sync
B["HISTORY_SYNCED"] = "Got the receipts: %d entries from %s"
B["SYNC_IN_PROGRESS"] = "One at a time bestie"
B["SYNC_TIMEOUT"] = "Connection gave up fr"

-- Tooltips
B["TOOLTIP_ITEM_LEVEL"] = "Ilvl grinding: %d"
B["TOOLTIP_VOTES"] = "Consensus: %d"

-- Status
B["STATUS_PENDING"] = "Waiting for drop"
B["STATUS_VOTING"] = "Democracy in action"
B["STATUS_TALLIED"] = "Votes counted periodt"
B["STATUS_AWARDED"] = "They got it fr"
B["STATUS_SKIPPED"] = "We ain't want it"

-- Response Settings
B["RESET_RESPONSES"] = "Back to basics"

-- Award Reason Settings
B["REQUIRE_AWARD_REASON"] = "Gotta justify it fr"
B["AWARD_REASONS"] = "The excuses"
B["ADD_REASON"] = "Create new justification"
B["REASON_NAME"] = "What's it called"
B["AWARD_REASON"] = "The justification"

-- Trade Panel
B["TRADE_QUEUE"] = "Items waiting fr"
B["TRADE_PANEL_HELP"] = "Let's get it"
B["NO_PENDING_TRADES"] = "Everyone already got their stuff"
B["NO_ITEMS_TO_TRADE"] = "The cupboard is empty fr"
B["ONE_ITEM_TO_TRADE"] = "Almost there (1 item)"
B["N_ITEMS_TO_TRADE"] = "Bunch of stuff to hand out: %d"
B["AUTO_TRADE"] = "Automated moves"
B["CLEAR_COMPLETED"] = "Finished business gone"

-- Voting Options
B["SELF_VOTE"] = "Vote for yourself no cap"
B["SELF_VOTE_DESC"] = "Main character energy allowed"
B["MULTI_VOTE"] = "Multiple dubs per item"
B["MULTI_VOTE_DESC"] = "Share the wealth fr"
B["ANONYMOUS_VOTING"] = "Secret ballot fr"
B["ANONYMOUS_VOTING_DESC"] = "No snitching until awarded"
B["HIDE_VOTES"] = "Keep the suspense"
B["HIDE_VOTES_DESC"] = "Don't influence them"
B["OBSERVE_MODE"] = "No cap watching only"
B["AUTO_ADD_ROLLS"] = "Automatic dice energy"
B["AUTO_ADD_ROLLS_DESC"] = "The numbers don't lie"
B["REQUIRE_NOTES"] = "Document the reasons"
B["REQUIRE_NOTES_DESC"] = "Explain yourself king"

-- Button Sets
B["BUTTON_SETS"] = "Your response menu fr"
B["ACTIVE_SET"] = "Using this right now"
B["NEW_SET"] = "Fresh vibes"
B["CONFIRM_DELETE_SET"] = "You sure about yeeting '%s'?"
B["ADD_BUTTON"] = "New response option"
B["MAX_BUTTONS"] = "Can't have everything fr (Max 10)"
B["MIN_BUTTONS"] = "Gotta have something (Min 1)"
B["DEFAULT_SET"] = "The standard setup"
B["SORT_ORDER"] = "Arrange it how you want"
B["BUTTON_COLOR"] = "Make it visible bestie"

-- Filters
B["FILTERS"] = "Narrow it down fr"
B["FILTER_BY_CLASS"] = "Only certain classes"
B["FILTER_BY_RESPONSE"] = "Only certain answers"
B["FILTER_BY_RANK"] = "Rank only"
B["SHOW_EQUIPPABLE_ONLY"] = "Wearable gear no cap"
B["HIDE_PASSED_ITEMS"] = "Nobody wanted these"
B["CLEAR_FILTERS"] = "See everything"
B["ALL_CLASSES"] = "Everyone counts"
B["ALL_RESPONSES"] = "Every answer matters"
B["ALL_RANKS"] = "No rank filter fr"
B["FILTERS_ACTIVE"] = "Narrowed down: %d active"

-- Generic / Missing strings
B["YES"] = "Facts"
B["NO"] = "Cap"
B["TIME_EXPIRED"] = "Too slow fam"
B["END_SESSION"] = "Wrap it up"
B["END_VOTE"] = "Decision time"
B["START_SESSION"] = "Let's begin fr"
B["OPEN_MAIN_WINDOW"] = "Main character energy"
B["RE_VOTE"] = "Try again"
B["ROLL_REQUEST"] = "Dice energy"
B["ROLL_REQUEST_SENT"] = "Waiting for numbers"
B["SELECT_RESPONSE"] = "Pick your vibe"
B["HIDE_MINIMAP_BUTTON"] = "Remove from view"
B["NO_SESSION"] = "Nothing happening rn"
B["MINIMAP_TOOLTIP_LEFT"] = "Quick open"
B["MINIMAP_TOOLTIP_RIGHT"] = "More choices fr"
B["RESULTS_TITLE"] = "Here's what happened"
B["VOTE_TITLE"] = "Drop your vote periodt"
B["VOTES"] = "The count"
B["ITEMS_PENDING"] = "Coming up next: %d"
B["ITEMS_VOTING"] = "Vote now no cap: %d"
B["LINK_IN_CHAT"] = "Flex the item"
B["VIEW"] = "Let me see"

-- Phase 1-6 Additional: General / UI
B["VERSION"] = "What build we on"
B["VERSION_CHECK"] = "Is everyone updated"
B["OUTDATED"] = "You fell off bro update"
B["NOT_INSTALLED"] = "They don't even have it smh"
B["CURRENT"] = "Up to date, based"
B["ENABLED"] = "It's on fr"
B["REQUIRED"] = "Non-negotiable no cap"
B["NOTE"] = "Read this bestie:"
B["PLAYER"] = "The homie"
B["SEND"] = "Ship it"
B["SEND_TO"] = "Who gets it:"
B["WHISPER"] = "DM energy"

-- Blizzard Settings Integration
B["BLIZZARD_SETTINGS_DESC"] = "The real menu fr"
B["OPEN_SETTINGS"] = "Customize the grind"

-- Session Panel
B["ADD_ITEM"] = "Drop the loot in"
B["ADD_ITEM_TITLE"] = "Bring the drip"
B["ENTER_ITEM"] = "Paste it in fr"
B["RECENT_DROPS"] = "What just hit the floor"
B["FROM_BAGS"] = "Check your inventory king"
B["ENTER_ITEM_HINT"] = "Any of those work fr"
B["DRAG_ITEM_HERE"] = "Yeet it in"
B["NO_RECENT_DROPS"] = "The drought is real"
B["NO_BAG_ITEMS"] = "Your bags are mid fr"
B["EQUIPMENT_ONLY"] = "Wearable drip only"
B["AWARD_LATER_ALL"] = "Save em all for the sigma moment"

-- Session Trigger Modes
B["TRIGGER_MANUAL"] = "DIY energy"
B["TRIGGER_AUTO"] = "No cap auto"
B["TRIGGER_PROMPT"] = "Respectful king asks first"

-- Session Trigger Policy
B["SESSION_TRIGGER_HEADER"] = "When it pops off"
B["SESSION_TRIGGER_ACTION"] = "What happens"
B["SESSION_TRIGGER_ACTION_DESC"] = "The play for boss kills"
B["SESSION_TRIGGER_TIMING"] = "When it fires"
B["SESSION_TRIGGER_TIMING_DESC"] = "The timing is everything"
B["TRIGGER_TIMING_ENCOUNTER_END"] = "As soon as they're dead fr"
B["TRIGGER_TIMING_AFTER_LOOT"] = "Patience is sigma"
B["TRIGGER_SCOPE_RAID"] = "The big ones"
B["TRIGGER_SCOPE_RAID_DESC"] = "Raid content fr"
B["TRIGGER_SCOPE_DUNGEON"] = "The smaller ones"
B["TRIGGER_SCOPE_DUNGEON_DESC"] = "Dungeon grind"
B["TRIGGER_SCOPE_OPEN_WORLD"] = "Outside vibes"
B["TRIGGER_SCOPE_OPEN_WORLD_DESC"] = "Touching grass and looting"

-- AutoPass Options
B["CONFIG_AUTOPASS_BOE"] = "Skip the tradeable mid"
B["CONFIG_AUTOPASS_BOE_DESC"] = "They mid fr"
B["CONFIG_AUTOPASS_TRANSMOG"] = "Drip you already got"
B["CONFIG_AUTOPASS_TRANSMOG_SOURCE"] = "Been there dripped that"

-- Auto Award Options
B["CONFIG_AUTO_AWARD_LOWER_THRESHOLD"] = "Where mid starts"
B["CONFIG_AUTO_AWARD_UPPER_THRESHOLD"] = "Where mid ends"
B["CONFIG_AUTO_AWARD_REASON"] = "Why it got auto'd"
B["CONFIG_AUTO_AWARD_INCLUDE_BOE"] = "Tradeable stuff too"

-- Frame Behavior Options
B["CONFIG_FRAME_BEHAVIOR"] = "How the UI moves"
B["CONFIG_FRAME_AUTO_OPEN"] = "Pop up automatically"
B["CONFIG_FRAME_AUTO_CLOSE"] = "Disappear when done"
B["CONFIG_FRAME_SHOW_SPEC_ICON"] = "Specialization drip"
B["CONFIG_FRAME_CLOSE_ESCAPE"] = "ESC key works"
B["CONFIG_FRAME_CHAT_OUTPUT"] = "Where the messages go"

-- ML Usage Options
B["CONFIG_ML_USAGE_MODE"] = "When ML activates"
B["CONFIG_ML_USAGE_NEVER"] = "Disabled energy"
B["CONFIG_ML_USAGE_GL"] = "Auto on group loot"
B["CONFIG_ML_USAGE_ASK_GL"] = "Respectful king asks first"
B["CONFIG_ML_RAIDS_ONLY"] = "Raid exclusive fr"
B["CONFIG_ML_ALLOW_OUTSIDE"] = "Works everywhere"
B["CONFIG_ML_SKIP_SESSION"] = "Speedrun it"
B["CONFIG_ML_SORT_ITEMS"] = "Organize the drip"
B["CONFIG_ML_AUTO_ADD_BOES"] = "Include tradeable gear"
B["CONFIG_ML_PRINT_TRADES"] = "Flex when it's done"
B["CONFIG_ML_REJECT_TRADE"] = "Block the randoms"
B["CONFIG_ML_AWARD_LATER"] = "Save for later"

-- History Options
B["CONFIG_HISTORY_SEND_GUILD"] = "Guild-wide broadcast"
B["CONFIG_HISTORY_SAVE_PL"] = "Solo drops too"

-- Ignore Item Options
B["CONFIG_IGNORE_ENCHANTING_MATS"] = "Vendor trash energy"
B["CONFIG_IGNORE_CRAFTING_REAGENTS"] = "Crafting is mid"
B["CONFIG_IGNORE_CONSUMABLES"] = "Food and pots we don't care"
B["CONFIG_IGNORE_PERMANENT_ENHANCEMENTS"] = "Gems and stuff"

-- Announcement Options
B["CONFIG_ANNOUNCEMENT_TOKENS_DESC"] = "Use these placeholders fr: {item}, {winner}, {reason}, {notes}, {ilvl}, {type}, {oldItem}, {ml}, {session}, {votes}"
B["CONFIG_ANNOUNCE_CONSIDERATIONS"] = "Let em know we thinking"
B["CONFIG_ITEM_ANNOUNCEMENTS"] = "Broadcast the drops"
B["CONFIG_SESSION_ANNOUNCEMENTS"] = "Start and end broadcasts"
B["CONFIG_SESSION_START"] = "The beginning"
B["CONFIG_SESSION_END"] = "That's a wrap"
B["CONFIG_MESSAGE"] = "What to say"

-- Button Sets & Type Code Options
B["CONFIG_BUTTON_SETS"] = "Response menu config"
B["CONFIG_TYPECODE_ASSIGNMENT"] = "Categorize the drip"

-- Award Reasons Options
B["CONFIG_AWARD_REASONS"] = "The excuse list"
B["NUM_AWARD_REASONS"] = "How many excuses"

-- Council Guild Rank Options
B["CONFIG_GUILD_RANK"] = "Rank-based invites"
B["CONFIG_GUILD_RANK_DESC"] = "Rank = sigma fr"
B["CONFIG_MIN_RANK"] = "Lowest rank that counts"
B["CONFIG_MIN_RANK_DESC"] = "Rank hierarchy fr"
B["CONFIG_COUNCIL_REMOVE_ALL"] = "Purge the list"

-- Council Table UI
B["CHANGE_RESPONSE"] = "Nah switch it up"

-- Sync Panel UI
B["SYNC_DATA"] = "Share the knowledge"
B["SELECT_TARGET"] = "Pick who gets it"
B["SELECT_TARGET_FIRST"] = "Choose your homie first"
B["NO_TARGETS"] = "Where'd everyone go fr"
B["GUILD"] = "The whole fam"
B["QUERY_GROUP"] = "Check who's vibing"
B["LAST_7_DAYS"] = "This week's tea"
B["LAST_30_DAYS"] = "This month's highlights"
B["ALL_TIME"] = "The complete saga"
B["SYNCING_TO"] = "Sharing the vibes to %s rn (%s)"

-- History Panel UI
B["DATE_RANGE"] = "When to look:"
B["FILTER_BY_WINNER"] = "Filter by %s"
B["DELETE_ENTRY"] = "Yeet this record"

-- Master Looter Settings
B["CONFIG_ML_SETTINGS"] = "Big sigma settings"

-- History Settings
B["CONFIG_HISTORY_SETTINGS"] = "Keep the receipts"
B["CONFIG_HISTORY_CLEARALL_CONFIRM"] = "No takesies backsies fr?"

-- Enhanced Award Reasons
B["CONFIG_REASON_LOG"] = "Save it fr"
B["CONFIG_REASON_DISENCHANT"] = "Mark it as dust"
B["CONFIG_REASON_RESET_CONFIRM"] = "You sure about that?"

-- Council Management
B["CONFIG_COUNCIL_REMOVEALL_CONFIRM"] = "You sure?"

-- Auto-Pass Enhancements
B["CONFIG_AUTOPASS_TRINKETS"] = "Jewelry be gone"
B["CONFIG_AUTOPASS_SILENT"] = "No announcements"

-- Voting Enhancements
B["CONFIG_VOTING_MLSEESVOTES"] = "Leader transparency"
B["CONFIG_VOTING_MLSEESVOTES_DESC"] = "Sigma privilege"

-- RollFrame UI
B["ROLL_YOUR_ROLL"] = "The number:"

-- CouncilTable UI
B["COUNCIL_NO_CANDIDATES"] = "Nobody voting rn"
B["COUNCIL_AWARD"] = "Give it to em"
B["COUNCIL_REVOTE"] = "Try again"
B["COUNCIL_SKIP"] = "Pass on this one"
B["COUNCIL_CONFIRM_REVOTE"] = "Reset everything fr?"

-- CouncilTable Settings
B["COUNCIL_COLUMN_PLAYER"] = "Who voted"
B["COUNCIL_COLUMN_RESPONSE"] = "Their answer"
B["COUNCIL_COLUMN_ROLL"] = "The dice number"
B["COUNCIL_COLUMN_NOTE"] = "Why they want it"
B["COUNCIL_COLUMN_ILVL"] = "Gear score"
B["COUNCIL_COLUMN_ILVL_DIFF"] = "Upgrade value"
B["COUNCIL_COLUMN_GEAR1"] = "Equipment slot"
B["COUNCIL_COLUMN_GEAR2"] = "Another slot"

-- Winner Determination Settings
B["WINNER_DETERMINATION"] = "Who gets it"
B["WINNER_DETERMINATION_DESC"] = "Set the rules fr."
B["WINNER_MODE"] = "How to decide"
B["WINNER_MODE_DESC"] = "The algorithm"
B["WINNER_MODE_HIGHEST_VOTES"] = "Most votes wins"
B["WINNER_MODE_ML_CONFIRM"] = "ML chooses from top"
B["WINNER_MODE_AUTO_CONFIRM"] = "Auto then confirm"
B["WINNER_TIE_BREAKER"] = "What if it's tied"
B["WINNER_TIE_BREAKER_DESC"] = "Settle the draw fr"
B["WINNER_TIE_USE_ROLL"] = "Higher roll wins"
B["WINNER_TIE_ML_CHOICE"] = "Leader decides"
B["WINNER_TIE_REVOTE"] = "Vote again periodt"
B["WINNER_AUTO_AWARD_UNANIMOUS"] = "Everyone agrees"
B["WINNER_AUTO_AWARD_UNANIMOUS_DESC"] = "Skip if consensus"
B["WINNER_REQUIRE_CONFIRMATION"] = "Double check"
B["WINNER_REQUIRE_CONFIRMATION_DESC"] = "Confirm before awarding"

-- Announcements - Considerations
B["CONFIG_CONSIDERATIONS"] = "The thinking phase"
B["CONFIG_CONSIDERATIONS_CHANNEL"] = "Where to say it"
B["CONFIG_CONSIDERATIONS_TEXT"] = "What to say"

-- Announcements - Line Configuration
B["CONFIG_LINE"] = "Announcement line"
B["CONFIG_ENABLED"] = "Turn it on"
B["CONFIG_CHANNEL"] = "Where"

-- Award Reasons
B["CONFIG_NUM_REASONS_DESC"] = "Customize the excuse menu"
B["CONFIG_AWARD_REASONS_DESC"] = "Set it up fr."
B["CONFIG_RESET_REASONS"] = "Go back to basics"

-- Frame Settings
B["CONFIG_FRAME_MINIMIZE_COMBAT"] = "Hide when fighting"
B["CONFIG_FRAME_TIMEOUT_FLASH"] = "Warning animation"
B["CONFIG_FRAME_BLOCK_TRADES"] = "No interruptions"

-- History Settings
B["CONFIG_HISTORY_ENABLED"] = "Keep receipts"
B["CONFIG_HISTORY_SEND"] = "Share the data"
B["CONFIG_HISTORY_CLEAR_ALL"] = "Nuclear option"
B["CONFIG_HISTORY_AUTO_EXPORT_WEB"] = "Instant share"
B["CONFIG_HISTORY_AUTO_EXPORT_WEB_DESC"] = "Upload to loothing.xyz no cap"

-- Whisper Commands
B["WHISPER_RESPONSE_RECEIVED"] = "They locked in: '%s' for %s"
B["WHISPER_NO_SESSION"] = "Nothing happening bestie"
B["WHISPER_NO_VOTING_ITEMS"] = "The queue is empty fr"
B["WHISPER_UNKNOWN_COMMAND"] = "Bruh what is '%s'? Whisper !help for the real commands"
B["WHISPER_HELP_HEADER"] = "The DM meta:"
B["WHISPER_HELP_LINE"] = "  %s - %s"
B["WHISPER_ITEM_SPECIFIED"] = "Locked in fr: '%s' for %s (#%d)"
B["WHISPER_INVALID_ITEM_NUM"] = "Skill issue: Invalid item %d (only %d items)"

-- Observer System
B["OBSERVER"] = "Lurker mode"
B["CONFIG_ML_OBSERVER"] = "Sigma spectator"
B["CONFIG_ML_OBSERVER_DESC"] = "All-seeing sigma"
B["OPEN_OBSERVATION"] = "Let everyone watch"
B["OPEN_OBSERVATION_DESC"] = "Everyone gets the lurker pass"
B["OBSERVER_PERMISSIONS"] = "What lurkers can see"
B["OBSERVER_SEE_VOTE_COUNTS"] = "The numbers"
B["OBSERVER_SEE_VOTE_COUNTS_DESC"] = "Transparency fr"
B["OBSERVER_SEE_VOTER_IDS"] = "Who voted"
B["OBSERVER_SEE_VOTER_IDS_DESC"] = "No anonymous for lurkers"
B["OBSERVER_SEE_RESPONSES"] = "The answers"
B["OBSERVER_SEE_RESPONSES_DESC"] = "Full visibility"
B["OBSERVER_SEE_NOTES"] = "The reasoning"
B["OBSERVER_SEE_NOTES_DESC"] = "Read their thoughts fr"

-- Bulk Actions
B["BULK_START_VOTE"] = "Let's gooo (%d)"
B["BULK_END_VOTE"] = "Wrap it up (%d)"
B["BULK_SKIP"] = "Nah on all of em (%d)"
B["BULK_REMOVE"] = "Yeet em out (%d)"
B["BULK_REVOTE"] = "Try again fr (%d)"
B["BULK_AWARD_LATER"] = "Save for the sigma moment"
B["DESELECT_ALL"] = "Undo that"
B["N_SELECTED"] = "Locked in: %d"
B["REMOVE_ITEMS"] = "Yeet the whole batch"
B["CONFIRM_BULK_SKIP"] = "You sure about skipping all %d?"
B["CONFIRM_BULK_REMOVE"] = "Gone forever fr: Remove %d items?"
B["CONFIRM_BULK_REVOTE"] = "Democracy round 2: %d items?"

-- RCV Audit Strings
B["RCV_SETTINGS"] = "Sigma tier voting config"
B["MAX_RANKS"] = "Most you can pick"
B["MIN_RANKS"] = "Least you gotta pick"
B["MAX_RANKS_DESC"] = "No cap literally (0 = unlimited)"
B["MIN_RANKS_DESC"] = "Gotta rank at least this many fr"
B["RANK_LIMIT_REACHED"] = "You hit the ceiling bestie (%d)"
B["RANK_MINIMUM_REQUIRED"] = "Gotta pick more fr (min %d)"
B["MAX_REVOTES"] = "How many do-overs"

-- IRV Round Visualization
B["SHOW_IRV_ROUNDS"] = "The elimination arc (%d rounds)"
B["HIDE_IRV_ROUNDS"] = "Skip the drama"

-- Settings Export/Import
B["PROFILES"] = "Your loadouts"
B["EXPORT_SETTINGS"] = "Share your sigma config"
B["IMPORT_SETTINGS"] = "Absorb someone else's sigma"
B["EXPORT_TITLE"] = "The sharing screen"
B["EXPORT_DESC"] = "Ctrl+A then Ctrl+C (basic computer skills fr)."
B["EXPORT_FAILED"] = "L moment ong: %s"
B["IMPORT_TITLE"] = "The absorbing screen"
B["IMPORT_DESC"] = "Paste it below and click Import (easy fr)."
B["IMPORT_BUTTON"] = "Bring it in"
B["IMPORT_FAILED"] = "Couldn't absorb the sigma: %s"
B["IMPORT_VERSION_WARN"] = "Exported with v%s, you have v%s. Might be different no cap."
B["IMPORT_SUCCESS_NEW"] = "Fresh loadout unlocked: %s"
B["IMPORT_SUCCESS_CURRENT"] = "Absorbed the sigma."

-- Profile Management
B["PROFILE_CURRENT"] = "What you're running rn"
B["PROFILE_SWITCH"] = "Change loadout"
B["PROFILE_SWITCH_DESC"] = "Pick your vibe."
B["PROFILE_NEW"] = "Fresh start"
B["PROFILE_NEW_DESC"] = "Name your sigma loadout."
B["PROFILE_COPY_FROM"] = "Steal their settings"
B["PROFILE_COPY_DESC"] = "Absorb their energy."
B["PROFILE_COPY_CONFIRM"] = "No cap this is permanent. Continue?"
B["PROFILE_DELETE"] = "Yeet a loadout"
B["PROFILE_DELETE_CONFIRM"] = "Gone forever fr. Delete?"
B["PROFILE_RESET"] = "Factory reset"
B["PROFILE_RESET_CONFIRM"] = "Back to square one fr?"
B["PROFILE_LIST"] = "The collection"
B["PROFILE_DEFAULT_SUFFIX"] = "(the OG)"
B["PROFILE_EXPORT_INLINE_DESC"] = "Generate it and spread the sigma."
B["PROFILE_IMPORT_INLINE_DESC"] = "Paste it below to absorb the drip."
B["PROFILE_LIST_HEADER"] = "Your loadouts:"
B["PROFILE_SWITCHED"] = "New loadout activated: %s"
B["PROFILE_CREATED"] = "Fresh sigma deployed: %s"

-- UI Actions & Extras
B["ACCEPT"] = "Bet"
B["DECLINE"] = "Hard Pass"
B["DELETE"] = "Yeet"
B["EDIT"] = "Tweak"
B["COPY"] = "Yoink"
B["COPY_SUFFIX"] = "(Yoinked)"
B["KEEP"] = "Mine Now"
B["LESS"] = "Shrink"
B["NEW"] = "Fresh"
B["OK"] = "Aight"
B["OVERWRITE"] = "No Mercy"
B["REMOVE"] = "Yeet Out"
B["RENAME"] = "Rebrand"
B["RESET"] = "Factory Reset"
B["UNKNOWN"] = "Who Dis"

-- Quality Names
B["QUALITY_POOR"] = "Down Bad"
B["QUALITY_COMMON"] = "NPC Tier"
B["QUALITY_UNCOMMON"] = "Lowkey Decent"
B["QUALITY_RARE"] = "Kinda Fire"
B["QUALITY_EPIC"] = "Bussin"
B["QUALITY_LEGENDARY"] = "Goated"
B["QUALITY_ARTIFACT"] = "Sigma Relic"
B["QUALITY_HEIRLOOM"] = "Generational Rizz"
B["QUALITY_UNKNOWN"] = "Mystery Drip"

-- Columns
B["COLUMN_INST"] = "Inst"
B["COLUMN_ROLE"] = "Role"
B["COLUMN_VOTE"] = "Vote"
B["COLUMN_WK"] = "Wk"
B["COLUMN_WON"] = "Won"
B["COLUMN_TOOLTIP_WON_INSTANCE"] = "Local Ws"
B["COLUMN_TOOLTIP_WON_SESSION"] = "Sesh Ws"
B["COLUMN_TOOLTIP_WON_WEEKLY"] = "Weekly bag"

-- Loot Council / Voting
B["LOOT_COUNCIL"] = "The sigma senate"
B["LOOT_RESPONSE_TITLE"] = "What's your take"
B["COUNCIL_VOTING_PROGRESS"] = "Democracy loading"
B["NO_COUNCIL_VOTES"] = "Nobody pulled up"
B["VOTE_RANK"] = "Rank"
B["VOTE_RANKED"] = "Tier listed"
B["VOTE_VOTED"] = "Locked in"
B["VOTES_LABEL"] = "votes"

-- Responses
B["RESPONSE_AUTO_PASS"] = "Skill issue filter"
B["RESPONSE_BUTTON_EDITOR"] = "Customize the menu"
B["RESPONSE_TEXT_LABEL"] = "Response Text:"
B["RESPONSE_WAITING"] = "Loading the rizz..."

-- Notes
B["ADD_NOTE_PLACEHOLDER"] = "Drop a note bestie..."
B["NOTE_OPTIONAL"] = "Spill the tea:"

-- Item Categories
B["ITEM_CATEGORY_CONSUMABLE"] = "Snacks"
B["ITEM_CATEGORY_CRAFTING"] = "DIY materials"
B["ITEM_CATEGORY_ENCHANTING"] = "Sparkle dust"
B["ITEM_CATEGORY_GEM"] = "Shiny rock"
B["ITEM_CATEGORY_TRADE_GOODS"] = "The goods fr"

-- Equipped Gear
B["EQUIPPED_GEAR"] = "Current drip"
B["VIEW_GEAR"] = "Inspect the drip"
B["ILVL_PREFIX"] = "iLvl "

-- Announcements
B["ANN_CONSIDERATIONS_DEFAULT"] = "The deliberation arc: {ml} looking at {item}"
B["SESSION_ENDED_DEFAULT"] = "That's a wrap fr"
B["SESSION_STARTED_DEFAULT"] = "Let's eat"

-- Status
B["NOT_IN_GROUP"] = "Solo arc"
B["NOT_IN_GUILD"] = "Lone wolf energy"

-- Config
B["CONFIG_MANAGE"] = "Run it"
B["CONFIG_LOCAL_PREFS_DESC"] = "These only affect you bestie. Not broadcast no cap."
B["CONFIG_LOCAL_PREFS_NOTE"] = "Never sent to other members fr."
B["CONFIG_SESSION_BROADCAST_DESC"] = "Broadcast to everyone when you're ML no cap."
B["CONFIG_SESSION_BROADCAST_NOTE"] = "Broadcast when you start a sesh fr."
B["CONFIG_TRIGGER_SCOPE_NOTE"] = "Touch grass encounters don't count."

B["CONFIG_MAX_REVOTES_DESC"] = "Max do-overs (0 = skill issue)"
B["CONFIG_VOTING_TIMEOUT_DESC"] = "No time pressure fr."

B["CONFIG_BUTTON_SETS_DESC"] = "Customize the whole menu fr."
B["CONFIG_OPEN_BUTTON_EDITOR"] = "Tweak the buttons"

B["CONFIG_AWARD_REASONS_ENABLED_DESC"] = "The excuse machine"
B["CONFIG_REQUIRE_AWARD_REASON_DESC"] = "Gotta justify it"
B["CONFIG_CONFIRM_REMOVE_REASON"] = "Yeet this excuse?"
B["CONFIG_CONFIRM_RESET_REASONS"] = "No takesies backsies. Reset?"
B["CONFIG_NEW_REASON_DEFAULT"] = "Fresh Reason"
B["CONFIG_REASON_DEFAULT"] = "Reason"
B["CONFIG_REASONS"] = "The excuse menu"

B["CONFIG_COUNCIL_ADD_HELP"] = "Recruit the homies."
B["CONFIG_COUNCIL_ADD_NAME_DESC"] = "Playername no cap"
B["CONFIG_COUNCIL_ALL_REMOVED"] = "All yeeted"
B["CONFIG_COUNCIL_CONFIRM_REMOVE"] = "They getting the boot: %s?"
B["CONFIG_COUNCIL_CONFIRM_REMOVE_ALL"] = "Full purge energy?"
B["CONFIG_COUNCIL_MEMBER_REMOVED"] = "They fell off: %s"
B["CONFIG_COUNCIL_NO_MEMBERS"] = "The squad is empty fr."
B["CONFIG_COUNCIL_REMOVE_DESC"] = "Pick who gets yeeted"

B["CONFIG_HISTORY_ALL_CLEARED"] = "Receipts destroyed"

B["CONFIG_OBSERVER_PERMISSIONS_DESC"] = "Lurker permissions fr."

B["CONFIG_ROLLFRAME_TIMER_ENABLED_DESC"] = "No pressure bestie if disabled."

-- Labels
B["SET_LABEL"] = "Set:"
B["DISPLAY_TEXT_LABEL"] = "Display Text:"
B["ICON_LABEL"] = "Icon:"
B["ICON_SET"] = "Icon: ✓"
B["WHISPER_KEYS_LABEL"] = "Whisper Keys:"
B["CURRENT_COLON"] = "Current: "
B["RECOMMENDED"] = "The move fr"
B["APPLY_TO_CURRENT"] = "Lock it in"

-- Buttons
B["NEW_BUTTON"] = "Fresh option"

-- Enchanter
B["CLICK_SELECT_ENCHANTER"] = "Pick the dust merchant"
B["SELECT_ENCHANTER"] = "Who's doing the dusting"
B["DISENCHANT_TARGET"] = "The dust merchant"

-- Pick Icon
B["PICK_ICON"] = "Choose your drip symbol..."

-- Queue
B["QUEUED_ITEMS_HINT"] = "Patience bestie"
B["REMOVE_FROM_QUEUE"] = "Yeet from the line"
B["REMOVE_FROM_SESSION"] = "Kicked from the sesh"

-- Auto Award
B["AUTO_AWARD_TARGET_NOT_IN_RAID"] = "They ghosted fr: %s"

-- Award
B["AWARD_FOR"] = "Who deserves it"
B["AWARD_LATER_ALL_DESC"] = "Save the whole bag"
B["AWARD_LATER_ITEM_DESC"] = "Save for later"
B["AWARD_LATER_SHORT"] = "Not rn"

-- Response Sets
B["CANNOT_DELETE_LAST_SET"] = "Gotta keep at least one fr."

-- Popups - Awards & Items
B["POPUP_AWARD_LATER"] = "Stash {item} for the sigma moment?"
B["POPUP_SKIP_ITEM"] = "Nobody wants {item} fr?"
B["POPUP_SKIP_ITEM_FMT"] = "Nobody wants %s fr?"
B["POPUP_CONFIRM_REVOTE"] = "Democracy reset for {item}?"
B["POPUP_CONFIRM_REVOTE_FMT"] = "Round 2 fr: %s?"
B["POPUP_REANNOUNCE"] = "Broadcast again?"
B["POPUP_REANNOUNCE_TITLE"] = "Say it louder"

-- Popups - Session
B["POPUP_START_SESSION"] = "Let's eat: {boss}?"
B["POPUP_START_SESSION_FMT"] = "Time to feast: %s?"
B["POPUP_START_SESSION_GENERIC"] = "Let's get this bread?"
B["POPUP_CONFIRM_END_SESSION"] = "No cap it's over?"
B["POPUP_CONFIRM_USAGE"] = "Sigma choice: Use Loothing?"

-- Popups - Council
B["POPUP_CLEAR_COUNCIL"] = "Purge the squad?"
B["POPUP_CLEAR_COUNCIL_COUNT"] = "Full squad wipe: %d members?"

-- Popups - Ignored Items
B["POPUP_CLEAR_IGNORED"] = "Unblock everything?"
B["POPUP_CLEAR_IGNORED_COUNT"] = "Mass unblock: %d items?"

-- Popups - History
B["POPUP_DELETE_HISTORY_ALL"] = "Receipts gone forever fr?"
B["POPUP_DELETE_HISTORY_MULTI"] = "Mass yeet: %d entries?"
B["POPUP_DELETE_HISTORY_SELECTED"] = "Yeet the selection?"
B["POPUP_DELETE_HISTORY_SINGLE"] = "One receipt gone?"

-- Popups - Response Buttons/Sets
B["POPUP_DELETE_RESPONSE_BUTTON"] = "Yeet this option?"
B["POPUP_DELETE_RESPONSE_SET"] = "Gone forever fr?"
B["POPUP_RENAME_SET"] = "Rebrand it:"
B["POPUP_RESET_ALL_SETS"] = "Factory reset no cap?"

-- Popups - Import/Export
B["POPUP_IMPORT_OVERWRITE"] = "Incoming data raid: Overwrite {count} entries?"
B["POPUP_IMPORT_OVERWRITE_MULTI"] = "Mass overwrite energy: %d entries?"
B["POPUP_IMPORT_OVERWRITE_SINGLE"] = "One entry getting bodied?"
B["POPUP_IMPORT_SETTINGS"] = "Pick your path:"
B["POPUP_IMPORT_SETTINGS_TITLE"] = "Absorb the sigma"

-- Popups - Keep or Trade
B["POPUP_KEEP_OR_TRADE"] = "Keep or nah: {item}?"
B["POPUP_KEEP_OR_TRADE_FMT"] = "Keep or yeet: %s?"

-- Popups - Profile
B["POPUP_OVERWRITE_PROFILE"] = "No going back fr?"
B["POPUP_OVERWRITE_PROFILE_TITLE"] = "Sigma override"

-- Popups - Sync
B["POPUP_SYNC_GENERIC_FMT"] = "Incoming vibes: %s syncing %s to you. Accept?"
B["POPUP_SYNC_HISTORY_FMT"] = "Receipts incoming: %s syncing %d days to you. Accept?"
B["POPUP_SYNC_REQUEST"] = "Data transfer vibes: {player} syncing {type} to you. Accept?"
B["POPUP_SYNC_REQUEST_TITLE"] = "Someone's sharing"
B["POPUP_SYNC_SETTINGS_FMT"] = "Sigma config incoming: %s syncing settings. Accept?"

-- Popups - Trade
B["POPUP_TRADE_ADD_ITEMS"] = "Hand over the goods: {count} items to {player}?"
B["POPUP_TRADE_ADD_MULTI"] = "Bulk delivery fr: %d items to %s?"
B["POPUP_TRADE_ADD_SINGLE"] = "One piece of drip incoming: %s?"

-- Profiles
B["CREATE_NEW_PROFILE"] = "Fresh loadout"
B["IMPORT_SUMMARY"] = "Profile: %s | Exported: %s | Version: %s"
B["PROFILE_ERR_EMPTY"] = "Gotta call it something fr"
B["PROFILE_ERR_INVALID_CHARS"] = "Keep it clean bestie"
B["PROFILE_ERR_NOT_STRING"] = "What did you even type"
B["PROFILE_ERR_TOO_LONG"] = "Too long no cap"
B["PROFILE_SHARE_BUTTON"] = "Spread the sigma"
B["PROFILE_SHARE_DESC"] = "DM the drip."
B["PROFILE_SHARE_FAILED"] = "L transfer: %s - %s"
B["PROFILE_SHARE_FAILED_GENERIC"] = "Couldn't send the vibes: %s"
B["PROFILE_SHARE_RECEIVED"] = "New vibes unlocked from %s."
B["PROFILE_SHARE_SENT"] = "Sigma config dispatched to %s."
B["PROFILE_SHARE_TARGET"] = "Pick the recipient"
B["PROFILE_SHARE_TARGET_REQUIRED"] = "Who's getting it bestie."
B["PROFILE_SHARE_UNAVAILABLE"] = "Can't share rn."
B["PROFILE_SHARE_BROADCAST_BUTTON"] = "Sigma airdrop"
B["PROFILE_SHARE_BROADCAST_DESC"] = "Only the ML has the rizz for this no cap."
B["PROFILE_SHARE_BROADCAST_SENT"] = "Skibidi settings deployed fr fr."
B["PROFILE_SHARE_BROADCAST_CONFIRM"] = "Ong you broadcasting to EVERYONE? You sure?"
B["PROFILE_SHARE_BROADCAST_NO_SESSION"] = "Can't airdrop without a lobby bestie."
B["PROFILE_SHARE_BROADCAST_NOT_ML"] = "You ain't the sigma here no cap."
B["PROFILE_SHARE_BROADCAST_BUSY"] = "Throttled fr, try again."
B["PROFILE_SHARE_BROADCAST_COOLDOWN"] = "Cooldown is real (%d seconds)."
B["PROFILE_SHARE_QUEUE_FULL"] = "Ratio'd by queue limits."

-- Roster
B["ROSTER_COUNCIL_MEMBER"] = "Inner circle"
B["ROSTER_DEAD"] = "Got ratioed"
B["ROSTER_MASTER_LOOTER"] = "The sigma"
B["ROSTER_NO_ROLE"] = "Vibing"
B["ROSTER_NOT_INSTALLED"] = "Doesn't have it smh"
B["ROSTER_OFFLINE"] = "Ghosted us"
B["ROSTER_RANK_MEMBER"] = "Regular homie"
B["ROSTER_UNKNOWN"] = "Mystery person"
B["ROSTER_TOOLTIP_GROUP"] = "Group: "
B["ROSTER_TOOLTIP_LOOT_HISTORY"] = "Their W count: %d"
B["ROSTER_TOOLTIP_ROLE"] = "Role: "
B["ROSTER_TOOLTIP_TEST_VERSION"] = "Test Version: "
B["ROSTER_TOOLTIP_VERSION"] = "Loothing: "

-- Sync
B["SYNC_ACCEPTED_FROM"] = "Vibes received from %s"
B["SYNC_HISTORY_COMPLETED"] = "Receipts distributed fr (%d)"
B["SYNC_HISTORY_GUILD_DAYS"] = "Broadcasting receipts (%d days)..."
B["SYNC_HISTORY_SENT"] = "Receipts delivered (%d to %s)"
B["SYNC_HISTORY_TO_PLAYER"] = "Sending the tea (%d days to %s)"
B["SYNC_SETTINGS_APPLIED"] = "Sigma absorbed from %s"
B["SYNC_SETTINGS_COMPLETED"] = "Config distributed (%d)"
B["SYNC_SETTINGS_SENT"] = "Vibes dispatched to %s"
B["SYNC_SETTINGS_TO_GUILD"] = "Guild-wide sigma broadcast..."
B["SYNC_SETTINGS_TO_PLAYER"] = "Direct delivery to %s"

-- Trade
B["TRADE_BTN"] = "Hand it over"
B["TRADE_COMPLETED"] = "Drip delivered fr: %s to %s"
B["TRADE_ITEM_LOCKED"] = "Can't touch this: %s"
B["TRADE_ITEM_NOT_FOUND"] = "It vanished fr: %s"
B["TRADE_ITEMS_PENDING"] = "Get it done bestie: %d item(s) to %s."
B["TRADE_TOO_MANY_ITEMS"] = "Trade window has limits fr (first 6 only)."
B["TRADE_WINDOW_URGENT"] = "|cffff0000HURRY UP FR:|r %s to %s expires in %d mins!"
B["TRADE_WINDOW_WARNING"] = "|cffff9900Clock ticking:|r %s to %s expires in %d mins!"
B["TRADE_WRONG_RECIPIENT"] = "Wrong person got the drip ong: %s to %s (was for %s)"

-- Too Many Items
B["TOO_MANY_ITEMS_WARNING"] = "Scroll down bestie: Too many items (%d), showing %d."

-- Version Check
B["VERSION_AND_MORE"] = " and %d more"
B["VERSION_CHECK_IN_PROGRESS"] = "One at a time fr"
B["VERSION_OUTDATED_MEMBERS"] = "|cffff9900They need to update smh (%d):|r %s"
B["VERSION_RESULTS_CURRENT"] = "  Based and current-pilled: %d"
B["VERSION_RESULTS_HINT"] = "Get the full tea with /lt version show"
B["VERSION_RESULTS_NOT_INSTALLED"] = "  |cff888888They don't even have it: %d|r"
B["VERSION_RESULTS_OUTDATED"] = "  |cffff0000Fell off: %d|r"
B["VERSION_RESULTS_TEST"] = "  |cff00ff00Sigma testers: %d|r"
B["VERSION_RESULTS_TOTAL"] = "The census: %d total"

-- Voting States
B["VOTING_STATE_PENDING"] = "Waiting to start"
B["VOTING_STATE_VOTING"] = "Vote now fr"
B["VOTING_STATE_TALLYING"] = "Counting the votes"
B["VOTING_STATE_DECIDED"] = "Winner chosen"
B["VOTING_STATE_REVOTING"] = "Try again bestie"

-- Enchanter/Disenchant
B["NO_ENCHANTERS"] = "No enchanters in the squad fr fr"
B["DISENCHANT_TARGET_SET"] = "Catching the shards: %s"
B["DISENCHANT_TARGET_CLEARED"] = "No more shard duty"

-- Restored keys
B["SESSION_STARTED"] = "Periodt that's fire: %s"
B["SESSION_ENDED"] = "It hit different ngl"
B["AWARD_TO"] = "They earned the W: %s"
B["TOTAL_VOTES"] = "The final answer: %d"
B["LOOTED_BY"] = "They got the drop: %s"
B["ENTRIES_COUNT"] = "That's a lot of Ws bestie: %d"
B["ENTRIES_FILTERED"] = "Filtered for the sigma grind: %d of %d"
B["AWARDED_TO"] = "They slay: %s"
B["FROM_ENCOUNTER"] = "Where it came from: %s"
B["WITH_VOTES"] = "Agreed: %d"
B["TAB_SETTINGS"] = "Customize your sigma"
B["SELECT_AWARD_REASON"] = "Pick the excuse"
B["NO_SELECTION"] = "Pick something bestie"
B["YOUR_RANKING"] = "Where you placed em"
B["AWARD_NO_REASON"] = "No excuse needed fr"
B["CLEARED_TRADES"] = "Yeeted %d completed trade(s)"
B["NO_COMPLETED_TRADES"] = "No completed trades to yeet bestie"
B["OBSERVE_MODE_MSG"] = "You're in lurk mode and can't vote no cap."
B["VOTE_NOTE_REQUIRED"] = "You gotta drop a note with your vote fr fr."
B["SELF_VOTE_DISABLED"] = "Self-voting is off this session no cap."

-- Brainrot Mode toggle
B["CONFIG_BRAINROT_MODE"] = "Brainrot Mode (no cap)"
B["CONFIG_BRAINROT_MODE_DESC"] = "Yeet the normie text completely (/reload fr)"
