--[[--------------------------------------------------------------------
    Loothing - Loot Council Addon for WoW 12.0+
    Locale - Korean (koKR) localization
----------------------------------------------------------------------]]

local _, ns = ...
local Loothing = ns.Addon

local locale = (Loothing.ForceLocale or GetLocale())
if locale ~= "koKR" then
    return
end

local base = Loothing.Locale or {}
local L = setmetatable({}, { __index = base })

-- General
L["ADDON_LOADED"] = "Loothing v%s 로딩됨. /loothing 또는 /lt 로 옵션을 확인하세요."
L["SLASH_HELP"] = "명령어: /loothing [show|hide|config|history|council]"

-- Session
L["SESSION"] = "세션"
L["SESSION_START"] = "세션 시작"
L["SESSION_END"] = "세션 종료"
L["SESSION_ACTIVE"] = "세션 활성화"
L["SESSION_INACTIVE"] = "활성 세션 없음"
L["SESSION_STARTED"] = "%s 전리품 위원회 세션 시작"
L["SESSION_ENDED"] = "전리품 위원회 세션 종료"
L["NO_ITEMS"] = "세션에 아이템 없음"
L["YOU_ARE_ML"] = "당신은 전리품 분배자입니다"
L["ERROR_NOT_ML"] = "전리품 분배자만 이 작업을 수행할 수 있습니다"

-- Voting
L["VOTE"] = "투표"
L["VOTING"] = "투표"
L["VOTE_NOW"] = "지금 투표"
L["START_VOTE"] = "투표 시작"
L["VOTING_OPEN"] = "%s 투표 시작"
L["VOTING_CLOSED"] = "투표 종료"
L["VOTES_RECEIVED"] = "%d/%d 투표 수신"
L["TIME_REMAINING"] = "%d초 남음"
L["SUBMIT_VOTE"] = "투표 제출"
L["SUBMIT_RESPONSE"] = "응답 제출"
L["VOTE_SUBMITTED"] = "투표 제출됨"

-- Responses
L["NEED"] = "필요"
L["GREED"] = "욕심"
L["OFFSPEC"] = "부전문화"
L["TRANSMOG"] = "형상변환"
L["PASS"] = "패스"

-- Response descriptions
L["NEED_DESC"] = "주 특성 업그레이드"
L["GREED_DESC"] = "일반적 관심"
L["OFFSPEC_DESC"] = "부전문화 또는 부캐"
L["TRANSMOG_DESC"] = "외형만"
L["PASS_DESC"] = "관심 없음"

-- Awards
L["AWARD"] = "수여"
L["AWARD_TO"] = "%s에게 수여"
L["CONFIRM_AWARD"] = "%s을(를) %s에게 수여하시겠습니까?"
L["ITEM_AWARDED"] = "%s이(가) %s에게 수여됨"
L["SKIP_ITEM"] = "아이템 건너뛰기"
L["DISENCHANT"] = "마력 추출"

-- Results
L["RESULTS"] = "결과"
L["WINNER"] = "수상자"
L["NO_VOTES"] = "수신된 투표 없음"
L["TIE"] = "동점"
L["TOTAL_VOTES"] = "총: %d 투표"

-- Council
L["COUNCIL"] = "위원회"
L["COUNCIL_MEMBERS"] = "위원회 멤버"
L["ADD_MEMBER"] = "멤버 추가"
L["REMOVE_MEMBER"] = "멤버 제거"

-- History
L["HISTORY"] = "기록"
L["LOOT_HISTORY"] = "전리품 기록"
L["NO_HISTORY"] = "기록 없음"
L["CLEAR_HISTORY"] = "기록 삭제"
L["EXPORT"] = "내보내기"
L["SEARCH"] = "검색..."

-- Tabs
L["TAB_SESSION"] = "세션"
L["TAB_TRADE"] = "거래"
L["TAB_HISTORY"] = "기록"
L["TAB_ROSTER"] = "명단"
L["ROSTER_SUMMARY"] = "%d명 | %d 온라인 | %d 설치됨 | %d 의회"
L["ROSTER_NO_GROUP"] = "그룹에 속해 있지 않습니다"
L["ROSTER_QUERY_VERSIONS"] = "버전 확인"
L["ROSTER_ADD_COUNCIL"] = "의회에 추가"
L["ROSTER_REMOVE_COUNCIL"] = "의회에서 제거"
L["ROSTER_SET_ML"] = "전리품 담당자로 지정"
L["ROSTER_CLEAR_ML"] = "전리품 담당자 해제"
L["ROSTER_PROMOTE_LEADER"] = "공격대장으로 승급"
L["ROSTER_PROMOTE_ASSISTANT"] = "부공격대장으로 승급"
L["ROSTER_DEMOTE"] = "강등"
L["ROSTER_UNINVITE"] = "추방"
L["ROSTER_ADD_OBSERVER"] = "관찰자로 추가"
L["ROSTER_REMOVE_OBSERVER"] = "관찰자에서 제거"
L["TAB_SETTINGS"] = "설정"

-- Settings
L["SETTINGS"] = "설정"
L["GENERAL"] = "일반"
L["VOTING_TIMEOUT"] = "투표 시간 제한"
L["SECONDS"] = "초"
L["SHOW_MINIMAP"] = "미니맵 버튼 표시"

-- Announcements
L["ANNOUNCEMENT_SETTINGS"] = "공지 설정"
L["ANNOUNCE_AWARDS"] = "수여 공지"
L["ANNOUNCE_ITEMS"] = "아이템 공지"
L["CHANNEL_RAID"] = "레이드"
L["CHANNEL_GUILD"] = "길드"
L["CHANNEL_PARTY"] = "파티"
L["CHANNEL_NONE"] = "없음"

-- Errors
L["ERROR_NOT_IN_RAID"] = "레이드에 있어야 합니다"
L["ERROR_NO_ITEM"] = "선택된 아이템 없음"
L["ERROR_NO_SESSION"] = "활성 세션 없음"

-- Sync
L["SYNCING"] = "동기화 중..."
L["SYNC_COMPLETE"] = "동기화 완료"

-- Generic
L["YES"] = "예"
L["NO"] = "아니오"

-- Trade
L["TRADE_QUEUE"] = "거래 대기열"
L["AUTO_TRADE"] = "자동 거래"

-- Minimap
L["MINIMAP_TOOLTIP_LEFT"] = "좌클릭: Loothing 열기"
L["MINIMAP_TOOLTIP_RIGHT"] = "우클릭: 옵션"

-- Roll Frame
L["ROLL_FRAME_TITLE"] = "주사위 굴리기"
L["ROLL_SUBMIT"] = "응답 제출"
L["ROLL_TIME_REMAINING"] = "시간: %d초"
L["ROLL_TIME_EXPIRED"] = "시간 만료"

-- Council Table
L["COUNCIL_TABLE_TITLE"] = "전리품 위원회 - 후보자"
L["COUNCIL_AWARD"] = "수여"
L["COUNCIL_SKIP"] = "건너뛰기"

-- Locale Override
L["CONFIG_LOCALE_OVERRIDE"] = "언어 변경"
L["CONFIG_LOCALE_OVERRIDE_DESC"] = "애드온 언어를 수동으로 설정합니다 (/reload 필요)"
L["LOCALE_AUTO"] = "자동 (게임 언어)"

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
