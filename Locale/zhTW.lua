--[[--------------------------------------------------------------------
    Loothing - Loot Council Addon for WoW 12.0+
    Locale - Traditional Chinese (zhTW) localization
----------------------------------------------------------------------]]

local _, ns = ...
local Loothing = ns.Addon

local locale = (Loothing.ForceLocale or GetLocale())
if locale ~= "zhTW" then
    return
end

local base = Loothing.Locale or {}
local L = setmetatable({}, { __index = base })

-- General
L["ADDON_LOADED"] = "Loothing v%s 已載入。輸入 /loothing 或 /lt 查看選項。"
L["SLASH_HELP"] = "指令：/loothing [show|hide|config|history|council]"

-- Session
L["SESSION"] = "場次"
L["SESSION_START"] = "開始場次"
L["SESSION_END"] = "結束場次"
L["SESSION_ACTIVE"] = "場次進行中"
L["SESSION_INACTIVE"] = "無進行中場次"
L["SESSION_STARTED"] = "%s 拾取委員會場次已開始"
L["SESSION_ENDED"] = "拾取委員會場次已結束"
L["NO_ITEMS"] = "場次中沒有物品"
L["MANUAL_SESSION"] = "手動場次"
L["YOU_ARE_ML"] = "你是拾取分配者"
L["ML_IS"] = "分配者：%s"
L["ML_NOT_SET"] = "沒有拾取分配者（不在隊伍中）"
L["ERROR_NOT_ML"] = "只有拾取分配者可以執行此操作"

-- Voting
L["VOTE"] = "投票"
L["VOTING"] = "投票中"
L["VOTE_NOW"] = "立即投票"
L["START_VOTE"] = "開始投票"
L["VOTING_OPEN"] = "%s 投票已開始"
L["VOTING_CLOSED"] = "投票已結束"
L["VOTES_RECEIVED"] = "%d/%d 票已收到"
L["TIME_REMAINING"] = "剩餘 %d 秒"
L["SUBMIT_VOTE"] = "提交投票"
L["SUBMIT_RESPONSE"] = "提交回應"
L["CHANGE_VOTE"] = "更改投票"
L["VOTE_SUBMITTED"] = "投票已提交"

-- Responses
L["NEED"] = "需求"
L["GREED"] = "貪婪"
L["OFFSPEC"] = "副天賦"
L["TRANSMOG"] = "幻化"
L["PASS"] = "放棄"

-- Response descriptions
L["NEED_DESC"] = "主天賦升級"
L["GREED_DESC"] = "一般需求"
L["OFFSPEC_DESC"] = "副天賦或分身"
L["TRANSMOG_DESC"] = "僅外觀"
L["PASS_DESC"] = "不感興趣"

-- Awards
L["AWARD"] = "分配"
L["AWARD_TO"] = "分配給 %s"
L["AWARD_ITEM"] = "分配物品"
L["CONFIRM_AWARD"] = "將 %s 分配給 %s？"
L["ITEM_AWARDED"] = "%s 已分配給 %s"
L["SKIP_ITEM"] = "跳過物品"
L["ITEM_SKIPPED"] = "物品已跳過"
L["DISENCHANT"] = "分解"

-- Results
L["RESULTS"] = "結果"
L["WINNER"] = "獲勝者"
L["NO_VOTES"] = "未收到投票"
L["TIE"] = "平票"
L["TIE_BREAKER"] = "需要打破平局"
L["TOTAL_VOTES"] = "總計：%d 票"

-- Council
L["COUNCIL"] = "委員會"
L["COUNCIL_MEMBERS"] = "委員會成員"
L["ADD_MEMBER"] = "新增成員"
L["REMOVE_MEMBER"] = "移除成員"
L["NOT_COUNCIL"] = "你不是委員會成員"
L["COUNCIL_ONLY"] = "只有委員會成員可以投票"

-- History
L["HISTORY"] = "歷史"
L["LOOT_HISTORY"] = "拾取歷史"
L["NO_HISTORY"] = "無歷史記錄"
L["CLEAR_HISTORY"] = "清除歷史"
L["CONFIRM_CLEAR"] = "清除所有拾取歷史？"
L["EXPORT"] = "匯出"
L["EXPORT_HISTORY"] = "匯出歷史"
L["ENTRIES_COUNT"] = "總計：%d 條記錄"
L["SEARCH"] = "搜尋..."

-- Tabs
L["TAB_SESSION"] = "場次"
L["TAB_TRADE"] = "交易"
L["TAB_HISTORY"] = "歷史"
L["TAB_ROSTER"] = "名冊"
L["ROSTER_SUMMARY"] = "%d 成員 | %d 在線 | %d 已安裝 | %d 委員會"
L["ROSTER_NO_GROUP"] = "不在隊伍中"
L["ROSTER_QUERY_VERSIONS"] = "查詢版本"
L["ROSTER_ADD_COUNCIL"] = "加入委員會"
L["ROSTER_REMOVE_COUNCIL"] = "從委員會移除"
L["ROSTER_SET_ML"] = "設為拾取分配者"
L["ROSTER_CLEAR_ML"] = "取消拾取分配者"
L["ROSTER_PROMOTE_LEADER"] = "晉升為團長"
L["ROSTER_PROMOTE_ASSISTANT"] = "晉升為助理"
L["ROSTER_DEMOTE"] = "降級"
L["ROSTER_UNINVITE"] = "移出隊伍"
L["ROSTER_ADD_OBSERVER"] = "加入為觀察者"
L["ROSTER_REMOVE_OBSERVER"] = "移除觀察者"
L["TAB_SETTINGS"] = "設定"

-- Settings
L["SETTINGS"] = "設定"
L["GENERAL"] = "一般"
L["VOTING_SETTINGS"] = "投票設定"
L["COUNCIL_SETTINGS"] = "委員會設定"
L["UI_SETTINGS"] = "介面設定"
L["VOTING_TIMEOUT"] = "投票逾時"
L["SECONDS"] = "秒"
L["AUTO_START"] = "擊殺首領後自動開始場次"
L["SHOW_MINIMAP"] = "顯示小地圖按鈕"
L["UI_SCALE"] = "介面縮放"

-- Auto-Pass
L["AUTOPASS_SETTINGS"] = "自動放棄設定"
L["ENABLE_AUTOPASS"] = "啟用自動放棄"
L["AUTOPASS_DESC"] = "自動放棄無法使用的物品"

-- Announcements
L["ANNOUNCEMENT_SETTINGS"] = "公告設定"
L["ANNOUNCE_AWARDS"] = "公告分配"
L["ANNOUNCE_ITEMS"] = "公告物品"
L["CHANNEL_RAID"] = "團隊"
L["CHANNEL_RAID_WARNING"] = "團隊警告"
L["CHANNEL_OFFICER"] = "幹部"
L["CHANNEL_GUILD"] = "公會"
L["CHANNEL_PARTY"] = "隊伍"
L["CHANNEL_NONE"] = "無"

-- Auto-Award
L["AUTO_AWARD_SETTINGS"] = "自動分配設定"
L["AUTO_AWARD_ENABLE"] = "啟用自動分配"
L["AUTO_AWARD_DESC"] = "自動分配低於品質門檻的物品"

-- Errors
L["ERROR_NOT_IN_RAID"] = "你必須在團隊中"
L["ERROR_NOT_LEADER"] = "你必須是團隊隊長或助理"
L["ERROR_NO_ITEM"] = "未選擇物品"
L["ERROR_SESSION_ACTIVE"] = "場次已在進行中"
L["ERROR_NO_SESSION"] = "無進行中場次"

-- Sync
L["SYNCING"] = "同步中..."
L["SYNC_COMPLETE"] = "同步完成"
L["SYNC_SETTINGS"] = "同步設定"
L["SYNC_HISTORY"] = "同步歷史"
L["ACCEPT_SYNC"] = "接受同步"
L["DECLINE_SYNC"] = "拒絕同步"

-- Generic
L["YES"] = "是"
L["NO"] = "否"

-- Trade
L["TRADE_QUEUE"] = "交易佇列"
L["NO_PENDING_TRADES"] = "沒有待處理的交易"
L["AUTO_TRADE"] = "自動交易"

-- Minimap
L["MINIMAP_TOOLTIP_LEFT"] = "左鍵點擊：開啟 Loothing"
L["MINIMAP_TOOLTIP_RIGHT"] = "右鍵點擊：選項"

-- Roll Frame
L["ROLL_FRAME_TITLE"] = "擲骰"
L["ROLL_YOUR_RESPONSE"] = "你的回應"
L["ROLL_SUBMIT"] = "提交回應"
L["ROLL_TIME_REMAINING"] = "時間：%d秒"
L["ROLL_TIME_EXPIRED"] = "時間到"

-- Council Table
L["COUNCIL_TABLE_TITLE"] = "拾取委員會 - 候選人"
L["COUNCIL_AWARD"] = "分配"
L["COUNCIL_REVOTE"] = "重新投票"
L["COUNCIL_SKIP"] = "跳過"

-- Filters
L["FILTERS"] = "篩選"
L["ALL_CLASSES"] = "所有職業"
L["ALL_RESPONSES"] = "所有回應"
L["CLEAR_FILTERS"] = "清除篩選"

-- Button Sets
L["BUTTON_SETS"] = "按鈕組"
L["DEFAULT_SET"] = "預設"
L["WHISPER_KEY"] = "密語關鍵詞"

-- Locale Override
L["CONFIG_LOCALE_OVERRIDE"] = "語言覆蓋"
L["CONFIG_LOCALE_OVERRIDE_DESC"] = "手動設定插件語言（需要/reload）"
L["LOCALE_AUTO"] = "自動（遊戲語言）"

-- Observer System (new strings - untranslated placeholders)
L["OBSERVERS"] = L["OBSERVERS"] or "Observers"
L["OBSERVER"] = L["OBSERVER"] or "Observer"
L["OBSERVER_LIST"] = L["OBSERVER_LIST"] or "Observer List"
L["ADD_OBSERVER"] = L["ADD_OBSERVER"] or "Add Observer"
L["REMOVE_OBSERVER"] = L["REMOVE_OBSERVER"] or "Remove Observer"
L["IS_OBSERVER"] = L["IS_OBSERVER"] or "%s is now an observer"
L["REMOVED_OBSERVER"] = L["REMOVED_OBSERVER"] or "%s removed from observers"
L["NO_OBSERVERS"] = L["NO_OBSERVERS"] or "No observers added"
L["CONFIG_ML_OBSERVER"] = L["CONFIG_ML_OBSERVER"] or "ML Observer Mode"
L["CONFIG_ML_OBSERVER_DESC"] = L["CONFIG_ML_OBSERVER_DESC"] or "Master Looter can see everything and manage sessions but cannot vote"
L["OPEN_OBSERVATION"] = L["OPEN_OBSERVATION"] or "Open Observation"
L["OPEN_OBSERVATION_DESC"] = L["OPEN_OBSERVATION_DESC"] or "Allow all raid members to observe voting"
L["OBSERVER_PERMISSIONS"] = L["OBSERVER_PERMISSIONS"] or "Observer Permissions"
L["OBSERVER_SEE_VOTE_COUNTS"] = L["OBSERVER_SEE_VOTE_COUNTS"] or "See Vote Counts"
L["OBSERVER_SEE_VOTE_COUNTS_DESC"] = L["OBSERVER_SEE_VOTE_COUNTS_DESC"] or "Observers can see how many votes each candidate has"
L["OBSERVER_SEE_VOTER_IDS"] = L["OBSERVER_SEE_VOTER_IDS"] or "See Voter Identities"
L["OBSERVER_SEE_VOTER_IDS_DESC"] = L["OBSERVER_SEE_VOTER_IDS_DESC"] or "Observers can see who voted for each candidate"
L["OBSERVER_SEE_RESPONSES"] = L["OBSERVER_SEE_RESPONSES"] or "See Responses"
L["OBSERVER_SEE_RESPONSES_DESC"] = L["OBSERVER_SEE_RESPONSES_DESC"] or "Observers can see what response each candidate selected"
L["OBSERVER_SEE_NOTES"] = L["OBSERVER_SEE_NOTES"] or "See Notes"
L["OBSERVER_SEE_NOTES_DESC"] = L["OBSERVER_SEE_NOTES_DESC"] or "Observers can see candidate notes"
L["CONFIG_OBSERVER_REMOVE_ALL"] = L["CONFIG_OBSERVER_REMOVE_ALL"] or "Remove All Observers"
L["CONFIG_OBSERVER_REMOVE_ALL_DESC"] = L["CONFIG_OBSERVER_REMOVE_ALL_DESC"] or "Remove all observers from the list"

Loothing.Locale = L
ns.Locale = L
return L
