--[[--------------------------------------------------------------------
    Loothing - Loot Council Addon for WoW 12.0+
    Locale - Korean (koKR) localization
----------------------------------------------------------------------]]

local ADDON_NAME, ns = ...
local Loolib = LibStub("Loolib")
local LoolibLocale = Loolib.Locale or Loolib:GetModule("Locale")
local L = LoolibLocale:NewLocale(ADDON_NAME, "koKR")
if not L then return end

-- General
L["ADDON_LOADED"] = "Loothing v%s 로딩됨. /loothing 또는 /lt 로 옵션을 확인하세요."

-- Session
L["SESSION_ACTIVE"] = "세션 활성화"
L["NO_ITEMS"] = "세션에 아이템 없음"
L["YOU_ARE_ML"] = "당신은 전리품 분배자입니다"

-- Voting
L["VOTE"] = "투표"
L["VOTING"] = "투표"
L["START_VOTE"] = "투표 시작"
L["TIME_REMAINING"] = "%d초 남음"
L["SUBMIT_VOTE"] = "투표 제출"
L["SUBMIT_RESPONSE"] = "응답 제출"

-- Responses

-- Response descriptions

-- Awards
L["AWARD"] = "수여"
L["CONFIRM_AWARD"] = "%s을(를) %s에게 수여하시겠습니까?"
L["ITEM_AWARDED"] = "%s이(가) %s에게 수여됨"
L["SKIP_ITEM"] = "아이템 건너뛰기"
L["DISENCHANT"] = "마력 추출"

-- Results
L["RESULTS"] = "결과"
L["WINNER"] = "수상자"
L["TIE"] = "동점"

-- Council
L["COUNCIL"] = "위원회"
L["COUNCIL_MEMBERS"] = "위원회 멤버"
L["ADD_MEMBER"] = "멤버 추가"
L["REMOVE_MEMBER"] = "멤버 제거"

-- History
L["HISTORY"] = "기록"
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

-- Settings
L["SETTINGS"] = "설정"
L["GENERAL"] = "일반"
L["VOTING_TIMEOUT"] = "투표 시간 제한"
L["SECONDS"] = "초"

-- Announcements
L["ANNOUNCEMENT_SETTINGS"] = "공지 설정"
L["ANNOUNCE_AWARDS"] = "수여 공지"
L["ANNOUNCE_ITEMS"] = "아이템 공지"
L["CHANNEL_RAID"] = "레이드"
L["CHANNEL_GUILD"] = "길드"
L["CHANNEL_PARTY"] = "파티"
L["CHANNEL_NONE"] = "없음"

-- Errors
L["ERROR_NO_SESSION"] = "활성 세션 없음"

-- Sync
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

-- Council Table
L["COUNCIL_AWARD"] = "수여"
L["COUNCIL_SKIP"] = "건너뛰기"

-- Locale Override
L["CONFIG_LOCALE_OVERRIDE"] = "언어 변경"
L["CONFIG_LOCALE_OVERRIDE_DESC"] = "애드온 언어를 수동으로 설정합니다 (/reload 필요)"
L["LOCALE_AUTO"] = "자동 (게임 언어)"

-- Observer System (new strings - untranslated placeholders)
