--[[--------------------------------------------------------------------
    Loothing - Loot Council Addon for WoW 12.0+
    Locale - Simplified Chinese (zhCN) localization
----------------------------------------------------------------------]]

local locale = (Loothing.ForceLocale or GetLocale())
if locale ~= "zhCN" then
    return
end

local base = Loothing.Locale or {}
local L = setmetatable({}, { __index = base })

-- General
L["ADDON_LOADED"] = "Loothing v%s 已加载。输入 /loothing 或 /lt 查看选项。"
L["SLASH_HELP"] = "命令：/loothing [show|hide|config|history|council]"

-- Session
L["SESSION"] = "会话"
L["SESSION_START"] = "开始会话"
L["SESSION_END"] = "结束会话"
L["SESSION_ACTIVE"] = "会话进行中"
L["SESSION_INACTIVE"] = "无活动会话"
L["SESSION_STARTED"] = "%s 拾取委员会会话已开始"
L["SESSION_ENDED"] = "拾取委员会会话已结束"
L["NO_ITEMS"] = "会话中没有物品"
L["MANUAL_SESSION"] = "手动会话"
L["YOU_ARE_ML"] = "你是拾取分配者"
L["ML_IS"] = "分配者：%s"
L["ML_NOT_SET"] = "没有拾取分配者（不在队伍中）"
L["ERROR_NOT_ML"] = "只有拾取分配者可以执行此操作"

-- Voting
L["VOTE"] = "投票"
L["VOTING"] = "投票中"
L["VOTE_NOW"] = "立即投票"
L["START_VOTE"] = "开始投票"
L["VOTING_OPEN"] = "%s 投票已开始"
L["VOTING_CLOSED"] = "投票已结束"
L["VOTES_RECEIVED"] = "%d/%d 票已收到"
L["TIME_REMAINING"] = "剩余 %d 秒"
L["SUBMIT_VOTE"] = "提交投票"
L["SUBMIT_RESPONSE"] = "提交回应"
L["CHANGE_VOTE"] = "更改投票"
L["VOTE_SUBMITTED"] = "投票已提交"

-- Responses
L["NEED"] = "需求"
L["GREED"] = "贪婪"
L["OFFSPEC"] = "副天赋"
L["TRANSMOG"] = "幻化"
L["PASS"] = "放弃"

-- Response descriptions
L["NEED_DESC"] = "主天赋升级"
L["GREED_DESC"] = "一般需求"
L["OFFSPEC_DESC"] = "副天赋或小号"
L["TRANSMOG_DESC"] = "仅外观"
L["PASS_DESC"] = "不感兴趣"

-- Awards
L["AWARD"] = "分配"
L["AWARD_TO"] = "分配给 %s"
L["AWARD_ITEM"] = "分配物品"
L["CONFIRM_AWARD"] = "将 %s 分配给 %s？"
L["ITEM_AWARDED"] = "%s 已分配给 %s"
L["SKIP_ITEM"] = "跳过物品"
L["ITEM_SKIPPED"] = "物品已跳过"
L["DISENCHANT"] = "分解"

-- Results
L["RESULTS"] = "结果"
L["WINNER"] = "获胜者"
L["NO_VOTES"] = "未收到投票"
L["TIE"] = "平票"
L["TIE_BREAKER"] = "需要打破平局"
L["TOTAL_VOTES"] = "总计：%d 票"

-- Council
L["COUNCIL"] = "委员会"
L["COUNCIL_MEMBERS"] = "委员会成员"
L["ADD_MEMBER"] = "添加成员"
L["REMOVE_MEMBER"] = "移除成员"
L["NOT_COUNCIL"] = "你不是委员会成员"
L["COUNCIL_ONLY"] = "只有委员会成员可以投票"

-- History
L["HISTORY"] = "历史"
L["LOOT_HISTORY"] = "拾取历史"
L["NO_HISTORY"] = "无历史记录"
L["CLEAR_HISTORY"] = "清除历史"
L["CONFIRM_CLEAR"] = "清除所有拾取历史？"
L["EXPORT"] = "导出"
L["EXPORT_HISTORY"] = "导出历史"
L["ENTRIES_COUNT"] = "总计：%d 条记录"
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
L["TAB_SETTINGS"] = "设置"

-- Settings
L["SETTINGS"] = "设置"
L["GENERAL"] = "常规"
L["VOTING_SETTINGS"] = "投票设置"
L["COUNCIL_SETTINGS"] = "委员会设置"
L["UI_SETTINGS"] = "界面设置"
L["VOTING_TIMEOUT"] = "投票超时"
L["SECONDS"] = "秒"
L["AUTO_START"] = "击杀Boss后自动开始会话"
L["SHOW_MINIMAP"] = "显示小地图按钮"
L["UI_SCALE"] = "界面缩放"

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
L["ERROR_NOT_IN_RAID"] = "你必须在团队中"
L["ERROR_NOT_LEADER"] = "你必须是团队领袖或助理"
L["ERROR_NO_ITEM"] = "未选择物品"
L["ERROR_SESSION_ACTIVE"] = "会话已在进行中"
L["ERROR_NO_SESSION"] = "无活动会话"

-- Sync
L["SYNCING"] = "同步中..."
L["SYNC_COMPLETE"] = "同步完成"
L["SYNC_SETTINGS"] = "同步设置"
L["SYNC_HISTORY"] = "同步历史"
L["ACCEPT_SYNC"] = "接受同步"
L["DECLINE_SYNC"] = "拒绝同步"

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
L["ROLL_FRAME_TITLE"] = "掷骰"
L["ROLL_YOUR_RESPONSE"] = "你的回应"
L["ROLL_SUBMIT"] = "提交回应"
L["ROLL_TIME_REMAINING"] = "时间：%d秒"
L["ROLL_TIME_EXPIRED"] = "时间到"

-- Council Table
L["COUNCIL_TABLE_TITLE"] = "拾取委员会 - 候选人"
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
L["WHISPER_KEY"] = "密语关键词"

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
return L
