--[[--------------------------------------------------------------------
    Loothing - Loot Council Addon for WoW 12.0+
    Locale - Simplified Chinese (zhCN) localization
----------------------------------------------------------------------]]

local ADDON_NAME, ns = ...
local Loolib = LibStub("Loolib")
local LoolibLocale = Loolib.Locale or Loolib:GetModule("Locale")
local L = LoolibLocale:NewLocale(ADDON_NAME, "zhCN")
if not L then return end

-- General
L["ADDON_LOADED"] = "Loothing v%s 已加载。输入 /loothing 或 /lt 查看选项。"

-- Session
L["SESSION_ACTIVE"] = "会话进行中"
L["NO_ITEMS"] = "会话中没有物品"
L["MANUAL_SESSION"] = "手动会话"
L["YOU_ARE_ML"] = "你是拾取分配者"
L["ML_IS"] = "分配者：%s"
L["ML_NOT_SET"] = "没有拾取分配者（不在队伍中）"

-- Voting
L["VOTE"] = "投票"
L["VOTING"] = "投票中"
L["START_VOTE"] = "开始投票"
L["TIME_REMAINING"] = "剩余 %d 秒"
L["SUBMIT_VOTE"] = "提交投票"
L["SUBMIT_RESPONSE"] = "提交回应"
L["CHANGE_VOTE"] = "更改投票"

-- Responses

-- Response descriptions

-- Awards
L["AWARD"] = "分配"
L["AWARD_ITEM"] = "分配物品"
L["CONFIRM_AWARD"] = "将 %s 分配给 %s？"
L["ITEM_AWARDED"] = "%s 已分配给 %s"
L["SKIP_ITEM"] = "跳过物品"
L["DISENCHANT"] = "分解"

-- Results
L["RESULTS"] = "结果"
L["WINNER"] = "获胜者"
L["TIE"] = "平票"

-- Council
L["COUNCIL"] = "委员会"
L["COUNCIL_MEMBERS"] = "委员会成员"
L["ADD_MEMBER"] = "添加成员"
L["REMOVE_MEMBER"] = "移除成员"

-- History
L["HISTORY"] = "历史"
L["NO_HISTORY"] = "无历史记录"
L["CLEAR_HISTORY"] = "清除历史"
L["EXPORT"] = "导出"
L["EXPORT_HISTORY"] = "导出历史"
L["SEARCH"] = "搜索..."

-- Tabs
L["TAB_SESSION"] = "会话"
L["TAB_TRADE"] = "交易"
L["TAB_HISTORY"] = "历史"
L["TAB_ROSTER"] = "花名册"
L["ROSTER_SUMMARY"] = "%d 成员 | %d 在线 | %d 已安装 | %d 委员会"
L["ROSTER_NO_GROUP"] = "不在队伍中"
L["ROSTER_QUERY_VERSIONS"] = "查询版本"
L["ROSTER_ADD_COUNCIL"] = "添加至委员会"
L["ROSTER_REMOVE_COUNCIL"] = "从委员会移除"
L["ROSTER_SET_ML"] = "设为拾取分配者"
L["ROSTER_CLEAR_ML"] = "取消拾取分配者"
L["ROSTER_PROMOTE_LEADER"] = "提升为团长"
L["ROSTER_PROMOTE_ASSISTANT"] = "提升为助理"
L["ROSTER_DEMOTE"] = "降级"
L["ROSTER_UNINVITE"] = "移出队伍"
L["ROSTER_ADD_OBSERVER"] = "添加为观察者"
L["ROSTER_REMOVE_OBSERVER"] = "移除观察者"

-- Settings
L["SETTINGS"] = "设置"
L["GENERAL"] = "常规"
L["VOTING_TIMEOUT"] = "投票超时"
L["SECONDS"] = "秒"

-- Auto-Pass
L["AUTOPASS_SETTINGS"] = "自动放弃设置"
L["ENABLE_AUTOPASS"] = "启用自动放弃"
L["AUTOPASS_DESC"] = "自动放弃无法使用的物品"

-- Announcements
L["ANNOUNCEMENT_SETTINGS"] = "公告设置"
L["ANNOUNCE_AWARDS"] = "公告分配"
L["ANNOUNCE_ITEMS"] = "公告物品"
L["CHANNEL_RAID"] = "团队"
L["CHANNEL_RAID_WARNING"] = "团队警告"
L["CHANNEL_OFFICER"] = "官员"
L["CHANNEL_GUILD"] = "公会"
L["CHANNEL_PARTY"] = "队伍"
L["CHANNEL_NONE"] = "无"

-- Auto-Award
L["AUTO_AWARD_SETTINGS"] = "自动分配设置"
L["AUTO_AWARD_ENABLE"] = "启用自动分配"
L["AUTO_AWARD_DESC"] = "自动分配低于品质阈值的物品"

-- Errors
L["ERROR_NO_SESSION"] = "无活动会话"

-- Sync
L["SYNC_COMPLETE"] = "同步完成"

-- Generic
L["YES"] = "是"
L["NO"] = "否"

-- Trade
L["TRADE_QUEUE"] = "交易队列"
L["NO_PENDING_TRADES"] = "没有待处理的交易"
L["AUTO_TRADE"] = "自动交易"

-- Minimap
L["MINIMAP_TOOLTIP_LEFT"] = "左键点击：打开 Loothing"
L["MINIMAP_TOOLTIP_RIGHT"] = "右键点击：选项"

-- Roll Frame

-- Council Table
L["COUNCIL_AWARD"] = "分配"
L["COUNCIL_REVOTE"] = "重新投票"
L["COUNCIL_SKIP"] = "跳过"

-- Filters
L["FILTERS"] = "筛选"
L["ALL_CLASSES"] = "所有职业"
L["ALL_RESPONSES"] = "所有回应"
L["CLEAR_FILTERS"] = "清除筛选"

-- Button Sets
L["BUTTON_SETS"] = "按钮组"
L["DEFAULT_SET"] = "默认"

-- Locale Override
L["CONFIG_LOCALE_OVERRIDE"] = "语言覆盖"
L["CONFIG_LOCALE_OVERRIDE_DESC"] = "手动设置插件语言（需要/reload）"
L["LOCALE_AUTO"] = "自动（游戏语言）"

-- Observer System (new strings - untranslated placeholders)
