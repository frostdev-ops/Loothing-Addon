--[[--------------------------------------------------------------------
    Loothing - Loot Council Addon for WoW 12.0+
    Locale - Traditional Chinese (zhTW) localization
----------------------------------------------------------------------]]

local ADDON_NAME, ns = ...
local Loolib = LibStub("Loolib")
local LoolibLocale = Loolib.Locale or Loolib:GetModule("Locale")
local L = LoolibLocale:NewLocale(ADDON_NAME, "zhTW")
if not L then return end

-- General
L["ADDON_LOADED"] = "Loothing v%s 已載入。輸入 /loothing 或 /lt 查看選項。"

-- Session
L["SESSION_ACTIVE"] = "場次進行中"
L["NO_ITEMS"] = "場次中沒有物品"
L["MANUAL_SESSION"] = "手動場次"
L["YOU_ARE_ML"] = "你是拾取分配者"
L["ML_IS"] = "分配者：%s"
L["ML_NOT_SET"] = "沒有拾取分配者（不在隊伍中）"

-- Voting
L["VOTE"] = "投票"
L["VOTING"] = "投票中"
L["START_VOTE"] = "開始投票"
L["TIME_REMAINING"] = "剩餘 %d 秒"
L["SUBMIT_VOTE"] = "提交投票"
L["SUBMIT_RESPONSE"] = "提交回應"
L["CHANGE_VOTE"] = "更改投票"

-- Responses

-- Response descriptions

-- Awards
L["AWARD"] = "分配"
L["AWARD_ITEM"] = "分配物品"
L["CONFIRM_AWARD"] = "將 %s 分配給 %s？"
L["ITEM_AWARDED"] = "%s 已分配給 %s"
L["SKIP_ITEM"] = "跳過物品"
L["DISENCHANT"] = "分解"

-- Results
L["RESULTS"] = "結果"
L["WINNER"] = "獲勝者"
L["TIE"] = "平票"

-- Council
L["COUNCIL"] = "委員會"
L["COUNCIL_MEMBERS"] = "委員會成員"
L["ADD_MEMBER"] = "新增成員"
L["REMOVE_MEMBER"] = "移除成員"

-- History
L["HISTORY"] = "歷史"
L["NO_HISTORY"] = "無歷史記錄"
L["CLEAR_HISTORY"] = "清除歷史"
L["EXPORT"] = "匯出"
L["EXPORT_HISTORY"] = "匯出歷史"
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

-- Settings
L["SETTINGS"] = "設定"
L["GENERAL"] = "一般"
L["VOTING_TIMEOUT"] = "投票逾時"
L["SECONDS"] = "秒"

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
L["ERROR_NO_SESSION"] = "無進行中場次"

-- Sync
L["SYNC_COMPLETE"] = "同步完成"

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

-- Council Table
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

-- Locale Override
L["CONFIG_LOCALE_OVERRIDE"] = "語言覆蓋"
L["CONFIG_LOCALE_OVERRIDE_DESC"] = "手動設定插件語言（需要/reload）"
L["LOCALE_AUTO"] = "自動（遊戲語言）"

-- Observer System (new strings - untranslated placeholders)
