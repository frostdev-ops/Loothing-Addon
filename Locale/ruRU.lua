--[[--------------------------------------------------------------------
    Loothing - Loot Council Addon for WoW 12.0+
    Locale - Russian (RU) localization
----------------------------------------------------------------------]]

local ADDON_NAME, ns = ...
local Loolib = LibStub("Loolib")
local LoolibLocale = Loolib.Locale or Loolib:GetModule("Locale")
local L = LoolibLocale:NewLocale(ADDON_NAME, "ruRU")
if not L then return end

-- General
L["ADDON_NAME"] = "Loothing"
L["ADDON_LOADED"] = "Loothing v%s загружен. Введите /loothing или /lt для параметров."
L["SLASH_HELP_HEADER"] = "Команды Loothing (используйте /lt help <command>):"
L["SLASH_HELP_DETAIL"] = "Использование /lt %s:"
L["SLASH_HELP_UNKNOWN"] = "Неизвестная команда '%s'. Используйте /lt help."
L["SLASH_HELP_DEBUG_NOTE"] = "Включите /lt debug для просмотра команд разработчика."
L["SLASH_NO_MAINFRAME"] = "Главное окно еще недоступно."
L["SLASH_NO_CONFIG"] = "Диалог конфигурации недоступен."
L["SLASH_INVALID_ITEM"] = "Неверная ссылка на предмет."
L["SLASH_SYNC_UNAVAILABLE"] = "Модуль синхронизации недоступен."
L["SLASH_IMPORT_UNAVAILABLE"] = "Модуль импорта недоступен."
L["SLASH_IMPORT_PROMPT"] = "Укажите текст CSV/TSV: /lt import <data>"
L["SLASH_IMPORT_PARSE_ERROR"] = "Ошибка анализа: %s"
L["SLASH_IMPORT_SUCCESS"] = "Импортировано %d записей."
L["SLASH_IMPORT_FAILED"] = "Ошибка импорта: %s"
L["SLASH_DEBUG_STATE"] = "Режим отладки Loothing: %s"
L["SLASH_DEBUG_REQUIRED"] = "Включите режим отладки с помощью /lt debug для использования этой команды."
L["SLASH_TEST_UNAVAILABLE"] = "Тестовый режим недоступен."
L["SLASH_DESC_SHOW"] = "Показать главное окно"
L["SLASH_DESC_HIDE"] = "Скрыть главное окно"
L["SLASH_DESC_TOGGLE"] = "Переключить главное окно"
L["SLASH_DESC_CONFIG"] = "Открыть диалог параметров"
L["SLASH_DESC_HISTORY"] = "Открыть вкладку истории"
L["SLASH_DESC_COUNCIL"] = "Открыть параметры совета"
L["SLASH_DESC_ML"] = "Просмотреть или назначить Ответственного за добычу"
L["SLASH_DESC_IGNORE"] = "Добавить/удалить предмет из списка игнорирования"
L["SLASH_DESC_SYNC"] = "Синхронизировать параметры или историю"
L["SLASH_DESC_IMPORT"] = "Импортировать текст истории добычи"
L["SLASH_DESC_DEBUG"] = "Переключить режим отладки (включает команды разработчика)"
L["SLASH_DESC_TEST"] = "Утилиты тестового режима"
L["SLASH_DESC_TESTMODE"] = "Управление симулятором/тестовым режимом"
L["SLASH_DESC_HELP"] = "Показать справку по командам"
L["SLASH_DESC_START"] = "Активировать распределение добычи"
L["SLASH_DESC_STOP"] = "Деактивировать распределение добычи"

-- Session
L["SESSION_ACTIVE"] = "Сессия активна"
L["SESSION_CLOSED"] = "Сессия закрыта"
L["NO_ITEMS"] = "Нет предметов в сессии"
L["MANUAL_SESSION"] = "Ручная сессия"
L["ITEMS_COUNT"] = "%d предметов (%d ожидающих, %d голосуются, %d завершено)"
L["YOU_ARE_ML"] = "Вы Ответственный за добычу"
L["ML_IS"] = "МЛ: %s"
L["ML_IS_EXPLICIT"] = "Ответственный за добычу: %s (назначен)"
L["ML_IS_RAID_LEADER"] = "Ответственный за добычу: %s (лидер рейда)"
L["ML_NOT_SET"] = "Ответственный за добычу не установлен (не в группе)"
L["ML_CLEARED"] = "Ответственный за добычу сброшен - используется лидер рейда"
L["ML_ASSIGNED"] = "Ответственный за добычу назначен: %s"
L["ML_HANDLING_LOOT"] = "Управление распределением добычи включено."
L["ML_NOT_ACTIVE_SESSION"] = "Loothing не активен для этой сессии. Используйте '/loothing start' для включения вручную."
L["ML_USAGE_PROMPT_TEXT"] = "Вы лидер рейда. Использовать Loothing для распределения добычи?"
L["ML_USAGE_PROMPT_TEXT_INSTANCE"] = "Вы лидер рейда.\nИспользовать Loothing для %s?"
L["ML_STOPPED_HANDLING"] = "Управление распределением добычи остановлено."
L["RECONNECT_RESTORED"] = "Состояние сессии восстановлено из кэша."
L["ERROR_NOT_ML_OR_RL"] = "Это может сделать только Ответственный за добычу или Лидер Рейда"
L["REFRESH"] = "Обновить"
L["ITEM"] = "Предмет"
L["STATUS"] = "Статус"
L["START_ALL"] = "Начать все"
L["DATE"] = "Дата"

-- Voting
L["VOTE"] = "Голос"
L["VOTING"] = "Голосование"
L["START_VOTE"] = "Начать голосование"
L["TIME_REMAINING"] = "%d секунд осталось"
L["SUBMIT_VOTE"] = "Отправить голос"
L["SUBMIT_RESPONSE"] = "Отправить ответ"
L["CHANGE_VOTE"] = "Изменить голос"

-- Responses

-- Response descriptions

-- Awards
L["AWARD"] = "Выдать"
L["AWARD_ITEM"] = "Выдать предмет"
L["CONFIRM_AWARD"] = "Выдать %s для %s?"
L["ITEM_AWARDED"] = "%s выдан(а) %s"
L["SKIP_ITEM"] = "Пропустить предмет"
L["DISENCHANT"] = "Распылить"

-- Results
L["RESULTS"] = "Результаты"
L["WINNER"] = "Победитель"
L["TIE"] = "Ничья"

-- Council
L["COUNCIL"] = "Совет"
L["COUNCIL_MEMBERS"] = "Члены совета"
L["ADD_MEMBER"] = "Добавить члена"
L["REMOVE_MEMBER"] = "Удалить члена"
L["IS_COUNCIL"] = "%s является членом совета"
L["AUTO_OFFICERS"] = "Автоматически включать офицеров"
L["AUTO_RAID_LEADER"] = "Автоматически включать лидера рейда"

-- History
L["HISTORY"] = "История"
L["NO_HISTORY"] = "История добычи отсутствует"
L["CLEAR_HISTORY"] = "Очистить историю"
L["CONFIRM_CLEAR_HISTORY"] = "Очистить всю историю добычи?"
L["EXPORT"] = "Экспорт"
L["EXPORT_HISTORY"] = "Экспортировать историю"
L["EXPORT_EQDKP"] = "EQdkp"
L["SEARCH"] = "Поиск..."
L["SELECT_ALL"] = "Выбрать все"
L["ALL_WINNERS"] = "Все победители"
L["CLEAR"] = "Очистить"

-- Tabs
L["TAB_SESSION"] = "Сессия"
L["TAB_TRADE"] = "Торговля"
L["TAB_HISTORY"] = "История"
L["TAB_ROSTER"] = "Состав"

-- Roster
L["ROSTER_SUMMARY"] = "%d Участников | %d В сети | %d Установлено | %d Совет"
L["ROSTER_NO_GROUP"] = "Вы не в группе"
L["ROSTER_QUERY_VERSIONS"] = "Проверить версии"
L["ROSTER_ADD_COUNCIL"] = "Добавить в совет"
L["ROSTER_REMOVE_COUNCIL"] = "Убрать из совета"
L["ROSTER_SET_ML"] = "Назначить ответственным за добычу"
L["ROSTER_CLEAR_ML"] = "Снять ответственного за добычу"
L["ROSTER_PROMOTE_LEADER"] = "Повысить до лидера"
L["ROSTER_PROMOTE_ASSISTANT"] = "Повысить до помощника"
L["ROSTER_DEMOTE"] = "Понизить"
L["ROSTER_UNINVITE"] = "Исключить"
L["ROSTER_ADD_OBSERVER"] = "Добавить как наблюдателя"
L["ROSTER_REMOVE_OBSERVER"] = "Убрать из наблюдателей"

-- Settings
L["SETTINGS"] = "Параметры"
L["GENERAL"] = "Основное"
L["VOTING_MODE"] = "Режим голосования"
L["SIMPLE_VOTING"] = "Простой (побеждает больше голосов)"
L["RANKED_VOTING"] = "Ранжированный выбор"
L["VOTING_TIMEOUT"] = "Таймаут голосования"
L["SECONDS"] = "секунд"
L["AUTO_INCLUDE_OFFICERS"] = "Автоматически включать офицеров"
L["AUTO_INCLUDE_LEADER"] = "Автоматически включать лидера рейда"
L["ADD"] = "Добавить"

-- Auto-Pass
L["AUTOPASS_SETTINGS"] = "Параметры автоматического отказа"
L["ENABLE_AUTOPASS"] = "Включить автоотказ"
L["AUTOPASS_DESC"] = "Автоматически отказываться от предметов, которые вы не можете использовать"
L["AUTOPASS_WEAPONS"] = "Автоотказ от оружия (неправильные основные характеристики)"

-- Announcement Settings
L["ANNOUNCEMENT_SETTINGS"] = "Параметры объявлений"
L["ANNOUNCE_AWARDS"] = "Объявлять выдачу"
L["ANNOUNCE_ITEMS"] = "Объявлять предметы"
L["ANNOUNCE_BOSS_KILL"] = "Объявлять начало/конец сессии"
L["CHANNEL_RAID"] = "Рейд"
L["CHANNEL_RAID_WARNING"] = "Предупреждение рейда"
L["CHANNEL_OFFICER"] = "Офицеры"
L["CHANNEL_GUILD"] = "Гильдия"
L["CHANNEL_PARTY"] = "Группа"
L["CHANNEL_NONE"] = "Отключено"

-- Auto-Award
L["AUTO_AWARD_SETTINGS"] = "Параметры автоматической выдачи"
L["AUTO_AWARD_ENABLE"] = "Включить автоматическую выдачу"
L["AUTO_AWARD_DESC"] = "Автоматически выдавать предметы ниже порога качества"
L["AUTO_AWARD_TO"] = "Выдать"
L["AUTO_AWARD_TO_DESC"] = "Имя игрока или 'распылитель'"

-- Ignore Items
L["IGNORE_ITEMS_SETTINGS"] = "Игнорируемые предметы"
L["ENABLE_IGNORE_LIST"] = "Включить список игнорирования"
L["IGNORE_LIST_DESC"] = "Предметы в списке игнорирования не будут отслеживаться советом распределения"
L["IGNORED_ITEMS"] = "Игнорируемые предметы"
L["NO_IGNORED_ITEMS"] = "Нет игнорируемых предметов"
L["ADD_IGNORED_ITEM"] = "Добавить предмет в список игнорирования"
L["REMOVE_IGNORED_ITEM"] = "Удалить из списка игнорирования"
L["ITEM_IGNORED"] = "%s добавлен(а) в список игнорирования"
L["ITEM_UNIGNORED"] = "%s удален(а) из списка игнорирования"
L["SLASH_IGNORE"] = "/loothing ignore [itemlink] - Добавить/удалить предмет из списка игнорирования"
L["CLEAR_IGNORED_ITEMS"] = "Очистить все"
L["CONFIRM_CLEAR_IGNORED"] = "Очистить все игнорируемые предметы?"
L["IGNORED_ITEMS_CLEARED"] = "Список игнорирования очищен"
L["IGNORE_CATEGORIES"] = "Фильтры по категории"
L["IGNORE_ADD_DESC"] = "Вставьте ссылку на предмет или введите ID предмета."

-- Locale Override
L["CONFIG_LOCALE_OVERRIDE"] = "Переопределить язык"
L["CONFIG_LOCALE_OVERRIDE_DESC"] = "Установить язык аддона вручную (требуется /reload)"
L["LOCALE_AUTO"] = "Автоматически (язык игры)"

-- Common UI
L["CLOSE"] = "Закрыть"
L["CANCEL"] = "Отмена"
L["NO_LIMIT"] = "Без ограничения"

-- Personal Preferences
L["PERSONAL_PREFERENCES"] = "Личные настройки"
L["CONFIG_LOOT_RESPONSE"] = "Ответ на добычу"
L["CONFIG_ROLLFRAME_AUTO_SHOW"] = "Автопоказ окна ответа"
L["CONFIG_ROLLFRAME_AUTO_SHOW_DESC"] = "Автоматически показывать окно ответа при начале голосования"
L["CONFIG_ROLLFRAME_AUTO_ROLL"] = "Авто-бросок при отправке"
L["CONFIG_ROLLFRAME_AUTO_ROLL_DESC"] = "Автоматически выполнять /roll при отправке ответа"
L["CONFIG_ROLLFRAME_GEAR_COMPARE"] = "Показать сравнение снаряжения"
L["CONFIG_ROLLFRAME_GEAR_COMPARE_DESC"] = "Показать текущее снаряжение для сравнения"
L["CONFIG_ROLLFRAME_REQUIRE_NOTE"] = "Требовать примечание"
L["CONFIG_ROLLFRAME_REQUIRE_NOTE_DESC"] = "Требовать примечание перед отправкой ответа"
L["CONFIG_ROLLFRAME_PRINT_RESPONSE"] = "Вывести ответ в чат"
L["CONFIG_ROLLFRAME_PRINT_RESPONSE_DESC"] = "Вывести отправленный ответ в чат для личной справки"
L["CONFIG_ROLLFRAME_TIMER"] = "Таймер ответа"
L["CONFIG_ROLLFRAME_TIMER_ENABLED"] = "Показать таймер ответа"
L["CONFIG_ROLLFRAME_TIMER_DURATION"] = "Длительность таймера"

-- Session Settings (ML)
L["SESSION_SETTINGS_ML"] = "Настройки сессии (ОД)"
L["VOTING_TIMEOUT_DURATION"] = "Длительность ожидания"

-- Errors
L["ERROR_NO_SESSION"] = "Активная сессия отсутствует"

-- Communication
L["SYNC_COMPLETE"] = "Синхронизация завершена"

-- Guild Sync
L["HISTORY_SYNCED"] = "%d записей истории синхронизировано от %s"
L["SYNC_IN_PROGRESS"] = "Синхронизация уже в процессе"
L["SYNC_TIMEOUT"] = "Таймаут синхронизации"

-- Tooltips
L["TOOLTIP_ITEM_LEVEL"] = "Уровень предмета: %d"
L["TOOLTIP_VOTES"] = "Голосов: %d"

-- Status
L["STATUS_PENDING"] = "Ожидает"
L["STATUS_VOTING"] = "Голосование"
L["STATUS_TALLIED"] = "Подсчитано"
L["STATUS_AWARDED"] = "Выдано"
L["STATUS_SKIPPED"] = "Пропущено"

-- Response Settings
L["RESET_RESPONSES"] = "Восстановить по умолчанию"

-- Award Reason Settings
L["REQUIRE_AWARD_REASON"] = "Требовать причину при выдаче"
L["AWARD_REASONS"] = "Причины выдачи"
L["ADD_REASON"] = "Добавить причину"
L["REASON_NAME"] = "Название причины"
L["AWARD_REASON"] = "Причина выдачи"

-- Trade Panel
L["TRADE_QUEUE"] = "Очередь торговли"
L["TRADE_PANEL_HELP"] = "Нажмите на имя игрока для инициации торговли"
L["NO_PENDING_TRADES"] = "Нет предметов, ожидающих торговли"
L["NO_ITEMS_TO_TRADE"] = "Нет предметов для торговли"
L["ONE_ITEM_TO_TRADE"] = "1 предмет ожидает торговли"
L["N_ITEMS_TO_TRADE"] = "%d предметов ожидают торговли"
L["AUTO_TRADE"] = "Автоторговля"
L["CLEAR_COMPLETED"] = "Очистить завершенные"

-- Minimap

-- Voting Options
L["SELF_VOTE"] = "Разрешить голосование за себя"
L["SELF_VOTE_DESC"] = "Разрешить членам совета голосовать за себя"
L["MULTI_VOTE"] = "Разрешить множественное голосование"
L["MULTI_VOTE_DESC"] = "Разрешить голосование за нескольких кандидатов за предмет"
L["ANONYMOUS_VOTING"] = "Анонимное голосование"
L["ANONYMOUS_VOTING_DESC"] = "Скрывать, кто голосовал за кого до выдачи предмета"
L["HIDE_VOTES"] = "Скрывать подсчеты голосов"
L["HIDE_VOTES_DESC"] = "Не показывать подсчеты голосов до получения всех голосов"
L["OBSERVE_MODE"] = "Режим наблюдения"
L["AUTO_ADD_ROLLS"] = "Автоматически добавлять броски"
L["AUTO_ADD_ROLLS_DESC"] = "Автоматически добавлять результаты /roll кандидатам"
L["REQUIRE_NOTES"] = "Требовать примечания"
L["REQUIRE_NOTES_DESC"] = "Голосующие должны добавить примечание к своему голосу"

-- Button Sets
L["BUTTON_SETS"] = "Наборы кнопок"
L["ACTIVE_SET"] = "Активный набор"
L["NEW_SET"] = "Новый набор"
L["CONFIRM_DELETE_SET"] = "Удалить набор кнопок '%s'?"
L["ADD_BUTTON"] = "Добавить кнопку"
L["MAX_BUTTONS"] = "Максимум 10 кнопок за набор"
L["MIN_BUTTONS"] = "Требуется как минимум 1 кнопка"
L["DEFAULT_SET"] = "По умолчанию"
L["SORT_ORDER"] = "Порядок сортировки"
L["BUTTON_COLOR"] = "Цвет кнопки"

-- Filters
L["FILTERS"] = "Фильтры"
L["FILTER_BY_CLASS"] = "Фильтр по классу"
L["FILTER_BY_RESPONSE"] = "Фильтр по ответу"
L["FILTER_BY_RANK"] = "Фильтр по рангу гильдии"
L["SHOW_EQUIPPABLE_ONLY"] = "Показать только надеваемые"
L["HIDE_PASSED_ITEMS"] = "Скрывать отклоненные предметы"
L["CLEAR_FILTERS"] = "Очистить фильтры"
L["ALL_CLASSES"] = "Все классы"
L["ALL_RESPONSES"] = "Все ответы"
L["ALL_RANKS"] = "Все ранги"
L["FILTERS_ACTIVE"] = "%d фильтр(ов) активно"

-- Generic / Missing strings
L["YES"] = "Да"
L["NO"] = "Нет"
L["TIME_EXPIRED"] = "Время истекло"
L["END_SESSION"] = "Завершить сессию"
L["END_VOTE"] = "Завершить голосование"
L["START_SESSION"] = "Начать сессию"
L["OPEN_MAIN_WINDOW"] = "Открыть главное окно"
L["RE_VOTE"] = "Переголосовать"
L["ROLL_REQUEST"] = "Запрос броска"
L["ROLL_REQUEST_SENT"] = "Запрос броска отправлен"
L["SELECT_RESPONSE"] = "Выбрать ответ"
L["HIDE_MINIMAP_BUTTON"] = "Скрыть кнопку на миникарте"
L["NO_SESSION"] = "Активная сессия отсутствует"
L["MINIMAP_TOOLTIP_LEFT"] = "ЛКМ: Открыть Loothing"
L["MINIMAP_TOOLTIP_RIGHT"] = "ПКМ: Параметры"
L["RESULTS_TITLE"] = "Результаты"
L["VOTE_TITLE"] = "Ответ на добычу"
L["VOTES"] = "Голосы"
L["ITEMS_PENDING"] = "%d предметов ожидают"
L["ITEMS_VOTING"] = "%d предметов голосуют"
L["LINK_IN_CHAT"] = "Ссылка в чат"
L["VIEW"] = "Просмотр"

-- Group Loot

-- Frame/UI Settings

-- Master Looter Settings
L["CONFIG_ML_SETTINGS"] = "Параметры Ответственного за добычу"

-- History Settings
L["CONFIG_HISTORY_SETTINGS"] = "Параметры истории"
L["CONFIG_HISTORY_ENABLED"] = "Включить историю добычи"
L["CONFIG_HISTORY_CLEARALL_CONFIRM"] = "Вы уверены, что хотите удалить ВСЕ записи истории? Это невозможно отменить!"

-- Enhanced Announcements

-- Enhanced Award Reasons
L["CONFIG_REASON_LOG"] = "Логировать в историю"
L["CONFIG_REASON_DISENCHANT"] = "Рассматривать как распыление"
L["CONFIG_REASON_RESET_CONFIRM"] = "Восстановить все причины выдачи по умолчанию?"

-- Council Management
L["CONFIG_COUNCIL_REMOVEALL_CONFIRM"] = "Удалить всех членов совета?"

-- Auto-Pass Enhancements
L["CONFIG_AUTOPASS_TRINKETS"] = "Автопас аксессуаров"
L["CONFIG_AUTOPASS_SILENT"] = "Тихий автоотказ"

-- Voting Enhancements
L["CONFIG_VOTING_MLSEESVOTES"] = "МЛ видит голосы"
L["CONFIG_VOTING_MLSEESVOTES_DESC"] = "Ответственный за добычу может видеть голосы даже при анонимном голосовании"

-- General Enhancements

-- ============================================================================
-- Roll/Vote System Locale Strings
-- ============================================================================

-- RollFrame UI
L["ROLL_YOUR_ROLL"] = "Ваш результат:"

-- RollFrame Settings

-- CouncilTable UI
L["COUNCIL_NO_CANDIDATES"] = "Еще никто не ответил"
L["COUNCIL_AWARD"] = "Выдать"
L["COUNCIL_REVOTE"] = "Переголосовать"
L["COUNCIL_SKIP"] = "Пропустить"
L["COUNCIL_CONFIRM_REVOTE"] = "Очистить все голосы и начать голосование заново?"

-- CouncilTable Settings
L["COUNCIL_COLUMN_PLAYER"] = "Имя игрока"
L["COUNCIL_COLUMN_RESPONSE"] = "Ответ"
L["COUNCIL_COLUMN_ROLL"] = "Бросок"
L["COUNCIL_COLUMN_NOTE"] = "Примечание"
L["COUNCIL_COLUMN_ILVL"] = "Уровень предмета"
L["COUNCIL_COLUMN_ILVL_DIFF"] = "Апгрейд (+/-)"
L["COUNCIL_COLUMN_GEAR1"] = "Слот снаряжения 1"
L["COUNCIL_COLUMN_GEAR2"] = "Слот снаряжения 2"

-- Winner Determination Settings
L["WINNER_DETERMINATION"] = "Определение победителя"
L["WINNER_DETERMINATION_DESC"] = "Настройте, как победители выбираются при завершении голосования."
L["WINNER_MODE"] = "Режим победителя"
L["WINNER_MODE_DESC"] = "Как определяется победитель после голосования"
L["WINNER_MODE_HIGHEST_VOTES"] = "Наибольшее количество голосов совета"
L["WINNER_MODE_ML_CONFIRM"] = "МЛ подтверждает победителя"
L["WINNER_MODE_AUTO_CONFIRM"] = "Авто-выбор наибольшего + подтверждение"
L["WINNER_TIE_BREAKER"] = "Разрешение ничьей"
L["WINNER_TIE_BREAKER_DESC"] = "Как разрешаются ничьи, когда кандидаты имеют равное количество голосов"
L["WINNER_TIE_USE_ROLL"] = "Использовать значение броска"
L["WINNER_TIE_ML_CHOICE"] = "МЛ выбирает"
L["WINNER_TIE_REVOTE"] = "Запустить переголосование"
L["WINNER_AUTO_AWARD_UNANIMOUS"] = "Авто-выдача при единогласии"
L["WINNER_AUTO_AWARD_UNANIMOUS_DESC"] = "Автоматически выдавать, когда все члены совета голосуют за одного кандидата"
L["WINNER_REQUIRE_CONFIRMATION"] = "Требовать подтверждение"
L["WINNER_REQUIRE_CONFIRMATION_DESC"] = "Показать диалог подтверждения перед выдачей предметов"

-- Communication messages

-- Council Management (Guild/Group based)

-- Announcements - Considerations
L["CONFIG_CONSIDERATIONS"] = "Рассмотрения"
L["CONFIG_CONSIDERATIONS_CHANNEL"] = "Канал"
L["CONFIG_CONSIDERATIONS_TEXT"] = "Шаблон сообщения"

-- Announcements - Line Configuration
L["CONFIG_LINE"] = "Строка"
L["CONFIG_ENABLED"] = "Включено"
L["CONFIG_CHANNEL"] = "Канал"

-- Session Announcements

-- Award Reasons
L["CONFIG_NUM_REASONS_DESC"] = "Количество активных причин выдачи (1-20)"
L["CONFIG_AWARD_REASONS_DESC"] = "Настройте причины выдачи. Каждая причина может быть включена в логирование и отмечена как распыление."
L["CONFIG_RESET_REASONS"] = "Восстановить по умолчанию"

-- Frame Settings (using OptionsTable naming convention)
L["CONFIG_FRAME_MINIMIZE_COMBAT"] = "Минимизировать в боевых"
L["CONFIG_FRAME_TIMEOUT_FLASH"] = "Мигать при таймауте"
L["CONFIG_FRAME_BLOCK_TRADES"] = "Блокировать торговлю во время голосования"

-- History Settings
L["CONFIG_HISTORY_SEND"] = "Отправить историю"
L["CONFIG_HISTORY_CLEAR_ALL"] = "Очистить все"
L["CONFIG_HISTORY_AUTO_EXPORT_WEB"] = "Автопоказ веб-экспорта"
L["CONFIG_HISTORY_AUTO_EXPORT_WEB_DESC"] = "По окончании сессии автоматически открывать диалог экспорта с готовым веб-экспортом для копирования"

-- Whisper Commands
L["WHISPER_RESPONSE_RECEIVED"] = "Loothing: Ответ '%s' получен для %s"
L["WHISPER_NO_SESSION"] = "Loothing: Нет активной сессии"
L["WHISPER_NO_VOTING_ITEMS"] = "Loothing: Нет предметов, доступных для голосования"
L["WHISPER_UNKNOWN_COMMAND"] = "Loothing: Неизвестная команда '%s'. Напишите !help для списка команд"
L["WHISPER_HELP_HEADER"] = "Loothing: Команды шепота:"
L["WHISPER_HELP_LINE"] = "  %s - %s"
L["WHISPER_ITEM_SPECIFIED"] = "Loothing: Ответ '%s' получен для %s (#%d)"
L["WHISPER_INVALID_ITEM_NUM"] = "Loothing: Неверный номер предмета %d (в сессии %d предметов)"

-- ============================================================================
-- Phase 1-6 Additional Locale Strings
-- ============================================================================

-- General / UI
L["ADDON_TAGLINE"] = "Аддон совета распределения добычи"
L["VERSION"] = "Версия"
L["VERSION_CHECK"] = "Проверка версии"
L["OUTDATED"] = "Устаревшая"
L["NOT_INSTALLED"] = "Не установлен"
L["CURRENT"] = "Текущая"
L["ENABLED"] = "Включено"
L["REQUIRED"] = "Обязательно"
L["NOTE"] = "Примечание:"
L["PLAYER"] = "Игрок"
L["SEND"] = "Отправить"
L["SEND_TO"] = "Отправить:"
L["WHISPER"] = "Шепот"

-- Blizzard Settings Integration
L["BLIZZARD_SETTINGS_DESC"] = "Нажмите ниже, чтобы открыть полную панель параметров"
L["OPEN_SETTINGS"] = "Открыть параметры Loothing"

-- Slash Commands (Debug)
L["SLASH_DESC_ERRORS"] = "Показать перехваченные ошибки"
L["SLASH_DESC_LOG"] = "Просмотреть последние логи"

-- Session Panel
L["ADD_ITEM"] = "Добавить предмет"
L["ADD_ITEM_TITLE"] = "Добавить предмет в сессию"
L["ENTER_ITEM"] = "Ввести предмет"
L["RECENT_DROPS"] = "Недавние находки"
L["FROM_BAGS"] = "Из сумок"
L["ENTER_ITEM_HINT"] = "Вставьте ссылку на предмет, ID предмета или перетащите предмет сюда"
L["DRAG_ITEM_HERE"] = "Перетащите предмет сюда"
L["NO_RECENT_DROPS"] = "Недавние обмениваемые предметы не найдены"
L["NO_BAG_ITEMS"] = "Нет подходящих предметов в сумках"
L["EQUIPMENT_ONLY"] = "Только экипировка"
L["SLASH_DESC_ADD"] = "Добавить предмет в сессию"
L["AWARD_LATER_ALL"] = "Выдать позже (все)"

-- Session Trigger Modes (legacy)
L["TRIGGER_MANUAL"] = "Вручную (используйте /loothing start)"
L["TRIGGER_AUTO"] = "Автоматически (начать немедленно)"
L["TRIGGER_PROMPT"] = "Запрос (спросить перед началом)"

-- Session Trigger Policy (split model)
L["SESSION_TRIGGER_HEADER"] = "Триггер сессии"
L["SESSION_TRIGGER_ACTION"] = "Действие триггера"
L["SESSION_TRIGGER_ACTION_DESC"] = "Что происходит, когда убийство босса подходит для сессии"
L["SESSION_TRIGGER_TIMING"] = "Время триггера"
L["SESSION_TRIGGER_TIMING_DESC"] = "Когда действие триггера срабатывает относительно убийства босса"
L["TRIGGER_TIMING_ENCOUNTER_END"] = "При убийстве босса"
L["TRIGGER_TIMING_AFTER_LOOT"] = "После добычи с боя"
L["TRIGGER_SCOPE_RAID"] = "Рейдовые боссы"
L["TRIGGER_SCOPE_RAID_DESC"] = "Срабатывать при убийстве рейдовых боссов"
L["TRIGGER_SCOPE_DUNGEON"] = "Боссы подземелий"
L["TRIGGER_SCOPE_DUNGEON_DESC"] = "Срабатывать при убийстве боссов подземелий"
L["TRIGGER_SCOPE_OPEN_WORLD"] = "Открытый мир"
L["TRIGGER_SCOPE_OPEN_WORLD_DESC"] = "Срабатывать на столкновениях в открытом мире (например, мировые боссы)"

-- AutoPass Options
L["CONFIG_AUTOPASS_BOE"] = "Автопас предметов BoE"
L["CONFIG_AUTOPASS_BOE_DESC"] = "Автоматически пасовать на предметы при надевании"
L["CONFIG_AUTOPASS_TRANSMOG"] = "Автопас трансмогрификации"
L["CONFIG_AUTOPASS_TRANSMOG_SOURCE"] = "Пропускать известные облики"

-- Auto Award Options
L["CONFIG_AUTO_AWARD_LOWER_THRESHOLD"] = "Нижний порог качества"
L["CONFIG_AUTO_AWARD_UPPER_THRESHOLD"] = "Верхний порог качества"
L["CONFIG_AUTO_AWARD_REASON"] = "Причина выдачи"
L["CONFIG_AUTO_AWARD_INCLUDE_BOE"] = "Включить предметы BoE"

-- Frame Behavior Options
L["CONFIG_FRAME_BEHAVIOR"] = "Поведение окон"
L["CONFIG_FRAME_AUTO_OPEN"] = "Автооткрытие окон"
L["CONFIG_FRAME_AUTO_CLOSE"] = "Автозакрытие окон"
L["CONFIG_FRAME_SHOW_SPEC_ICON"] = "Показать значки специализации"
L["CONFIG_FRAME_CLOSE_ESCAPE"] = "Закрывать Escape"
L["CONFIG_FRAME_CHAT_OUTPUT"] = "Фрейм вывода чата"

-- ML Usage Options
L["CONFIG_ML_USAGE_MODE"] = "Режим использования"
L["CONFIG_ML_USAGE_NEVER"] = "Никогда"
L["CONFIG_ML_USAGE_GL"] = "Групповая добыча"
L["CONFIG_ML_USAGE_ASK_GL"] = "Спросить при групповой добыче"
L["CONFIG_ML_RAIDS_ONLY"] = "Только рейды"
L["CONFIG_ML_ALLOW_OUTSIDE"] = "Разрешить вне рейдов"
L["CONFIG_ML_SKIP_SESSION"] = "Пропустить фрейм сессии"
L["CONFIG_ML_SORT_ITEMS"] = "Сортировать предметы"
L["CONFIG_ML_AUTO_ADD_BOES"] = "Автодобавление BoE"
L["CONFIG_ML_PRINT_TRADES"] = "Печать завершенных торговель"
L["CONFIG_ML_REJECT_TRADE"] = "Отклонять неверные торговли"
L["CONFIG_ML_AWARD_LATER"] = "Выдать позже"

-- History Options
L["CONFIG_HISTORY_SEND_GUILD"] = "Отправить в гильдию"
L["CONFIG_HISTORY_SAVE_PL"] = "Сохранить личную добычу"

-- Ignore Item Options
L["CONFIG_IGNORE_ENCHANTING_MATS"] = "Игнорировать материалы зачарования"
L["CONFIG_IGNORE_CRAFTING_REAGENTS"] = "Игнорировать реагенты крафта"
L["CONFIG_IGNORE_CONSUMABLES"] = "Игнорировать расходуемые предметы"
L["CONFIG_IGNORE_PERMANENT_ENHANCEMENTS"] = "Игнорировать постоянные улучшения"

-- Announcement Options
L["CONFIG_ANNOUNCEMENT_TOKENS_DESC"] = "Доступные токены: {item}, {winner}, {reason}, {notes}, {ilvl}, {type}, {oldItem}, {ml}, {session}, {votes}"
L["CONFIG_ANNOUNCE_CONSIDERATIONS"] = "Объявлять рассмотрения"
L["CONFIG_ITEM_ANNOUNCEMENTS"] = "Объявления предметов"
L["CONFIG_SESSION_ANNOUNCEMENTS"] = "Объявления сессий"
L["CONFIG_SESSION_START"] = "Начало сессии"
L["CONFIG_SESSION_END"] = "Конец сессии"
L["CONFIG_MESSAGE"] = "Сообщение"

-- Button Sets & Type Code Options
L["CONFIG_BUTTON_SETS"] = "Наборы кнопок"
L["CONFIG_TYPECODE_ASSIGNMENT"] = "Назначение кодов типов"

-- Award Reasons Options
L["CONFIG_AWARD_REASONS"] = "Причины выдачи"
L["NUM_AWARD_REASONS"] = "Количество причин"

-- Council Guild Rank Options
L["CONFIG_GUILD_RANK"] = "Автовключение по рангу гильдии"
L["CONFIG_GUILD_RANK_DESC"] = "Автоматически включать членов гильдии с определенным рангом или выше в совет"
L["CONFIG_MIN_RANK"] = "Минимальный ранг гильдии"
L["CONFIG_MIN_RANK_DESC"] = "Члены гильдии с этим рангом или выше автоматически включаются в совет. 0 = отключено, 1 = Глава гильдии, 2 = Офицеры и т.д."
L["CONFIG_COUNCIL_REMOVE_ALL"] = "Удалить всех членов"

-- Council Table UI
L["CHANGE_RESPONSE"] = "Изменить ответ"

-- Sync Panel UI
L["SYNC_DATA"] = "Синхронизировать данные"
L["SELECT_TARGET"] = "Выбрать цель"
L["SELECT_TARGET_FIRST"] = "Выберите целевого игрока"
L["NO_TARGETS"] = "Нет участников в сети"
L["GUILD"] = "Гильдия (все в сети)"
L["QUERY_GROUP"] = "Запросить группу"
L["LAST_7_DAYS"] = "Последние 7 дней"
L["LAST_30_DAYS"] = "Последние 30 дней"
L["ALL_TIME"] = "За все время"
L["SYNCING_TO"] = "Синхронизация %s с %s..."

-- History Panel UI
L["DATE_RANGE"] = "Период:"
L["FILTER_BY_WINNER"] = "Фильтр по %s"
L["DELETE_ENTRY"] = "Удалить запись"

-- Observer System
L["OBSERVER"] = "Наблюдатель"

-- ML Observer
L["CONFIG_ML_OBSERVER"] = "Режим наблюдателя МЛ"
L["CONFIG_ML_OBSERVER_DESC"] = "Ответственный за добычу видит все и управляет сессиями, но не может голосовать"

-- Open Observation (replaces OBSERVE_MODE)
L["OPEN_OBSERVATION"] = "Открытое наблюдение"
L["OPEN_OBSERVATION_DESC"] = "Разрешить всем членам рейда наблюдать за голосованием (добавляет всех как наблюдателей)"

-- Observer Permissions
L["OBSERVER_PERMISSIONS"] = "Права наблюдателей"
L["OBSERVER_SEE_VOTE_COUNTS"] = "Видеть подсчет голосов"
L["OBSERVER_SEE_VOTE_COUNTS_DESC"] = "Наблюдатели могут видеть, сколько голосов у каждого кандидата"
L["OBSERVER_SEE_VOTER_IDS"] = "Видеть голосовавших"
L["OBSERVER_SEE_VOTER_IDS_DESC"] = "Наблюдатели могут видеть, кто голосовал за каждого кандидата"
L["OBSERVER_SEE_RESPONSES"] = "Видеть ответы"
L["OBSERVER_SEE_RESPONSES_DESC"] = "Наблюдатели могут видеть, какой ответ выбрал каждый кандидат"
L["OBSERVER_SEE_NOTES"] = "Видеть примечания"
L["OBSERVER_SEE_NOTES_DESC"] = "Наблюдатели могут видеть примечания кандидатов"

-- Bulk Actions
L["BULK_START_VOTE"] = "Начать голосование (%d)"
L["BULK_END_VOTE"] = "Завершить голосование (%d)"
L["BULK_SKIP"] = "Пропустить (%d)"
L["BULK_REMOVE"] = "Удалить (%d)"
L["BULK_REVOTE"] = "Переголосовать (%d)"
L["BULK_AWARD_LATER"] = "Выдать позже"
L["DESELECT_ALL"] = "Снять выделение"
L["N_SELECTED"] = "%d выбрано"
L["REMOVE_ITEMS"] = "Удалить предметы"
L["CONFIRM_BULK_SKIP"] = "Пропустить %d выбранных предметов?"
L["CONFIRM_BULK_REMOVE"] = "Удалить %d выбранных предметов из сессии?"
L["CONFIRM_BULK_REVOTE"] = "Переголосовать по %d выбранным предметам?"

-- ============================================================================
-- RCV (Ranked Choice Voting) Audit Strings
-- ============================================================================

-- RCV Settings
L["RCV_SETTINGS"] = "Параметры ранжированного голосования"
L["MAX_RANKS"] = "Максимум рейтингов"
L["MIN_RANKS"] = "Минимум рейтингов"
L["MAX_RANKS_DESC"] = "Максимальное количество выборов, которые может ранжировать голосующий (0 = без ограничений)"
L["MIN_RANKS_DESC"] = "Минимальное количество выборов для отправки голоса"
L["RANK_LIMIT_REACHED"] = "Максимум %d рейтингов достигнут"
L["RANK_MINIMUM_REQUIRED"] = "Ранжируйте как минимум %d выборов"
L["MAX_REVOTES"] = "Максимум переголосований"

-- ML Sees Votes

-- IRV Round Visualization
L["SHOW_IRV_ROUNDS"] = "Показать раунды ИГП (%d раундов)"
L["HIDE_IRV_ROUNDS"] = "Скрыть раунды ИГП"

-- Settings Export/Import
L["PROFILES"] = "Профили"
L["EXPORT_SETTINGS"] = "Экспорт параметров"
L["IMPORT_SETTINGS"] = "Импорт параметров"
L["EXPORT_TITLE"] = "Экспорт параметров"
L["EXPORT_DESC"] = "Нажмите Ctrl+A для выделения, затем Ctrl+C для копирования."
L["EXPORT_FAILED"] = "Ошибка экспорта: %s"
L["IMPORT_TITLE"] = "Импорт параметров"
L["IMPORT_DESC"] = "Вставьте экспортированную строку параметров ниже, затем нажмите Импорт."
L["IMPORT_BUTTON"] = "Импорт"
L["IMPORT_FAILED"] = "Ошибка импорта: %s"
L["IMPORT_VERSION_WARN"] = "Примечание: экспортировано с Loothing v%s (у вас v%s)."
L["IMPORT_SUCCESS_NEW"] = "Параметры импортированы как новый профиль: %s"
L["IMPORT_SUCCESS_CURRENT"] = "Параметры импортированы в текущий профиль."
L["SLASH_DESC_EXPORT"] = "Экспортировать параметры текущего профиля"
L["SLASH_DESC_PROFILE"] = "Управление профилями (список, переключение, создание)"

-- Profile Management
L["PROFILE_CURRENT"] = "Текущий профиль"
L["PROFILE_SWITCH"] = "Переключить профиль"
L["PROFILE_SWITCH_DESC"] = "Выберите профиль для переключения."
L["PROFILE_NEW"] = "Создать новый профиль"
L["PROFILE_NEW_DESC"] = "Введите имя для нового профиля."
L["PROFILE_COPY_FROM"] = "Копировать из"
L["PROFILE_COPY_DESC"] = "Копировать параметры из другого профиля в текущий."
L["PROFILE_COPY_CONFIRM"] = "Это перезапишет все параметры текущего профиля. Продолжить?"
L["PROFILE_DELETE"] = "Удалить профиль"
L["PROFILE_DELETE_CONFIRM"] = "Вы уверены, что хотите удалить этот профиль? Это невозможно отменить."
L["PROFILE_RESET"] = "Восстановить по умолчанию"
L["PROFILE_RESET_CONFIRM"] = "Сбросить профиль '%s' к параметрам по умолчанию? Это невозможно отменить."
L["PROFILE_LIST"] = "Все профили"
L["PROFILE_DEFAULT_SUFFIX"] = "(по умолчанию)"
L["PROFILE_EXPORT_INLINE_DESC"] = "Сформируйте строку экспорта, затем скопируйте её для обмена параметрами."
L["PROFILE_IMPORT_INLINE_DESC"] = "Вставьте экспортированную строку параметров ниже, затем нажмите Импорт."
L["PROFILE_LIST_HEADER"] = "Профили:"
L["PROFILE_SWITCHED"] = "Переключено на профиль: %s"
L["PROFILE_CREATED"] = "Создан и активирован профиль: %s"

-- ============================================================================
-- Additional Translations (207 keys)
-- ============================================================================

-- General UI
L["ACCEPT"] = "Принять"
L["COPY"] = "Копировать"
L["COPY_SUFFIX"] = "(Копия)"
L["DECLINE"] = "Отклонить"
L["DELETE"] = "Удалить"
L["EDIT"] = "Редактировать"
L["KEEP"] = "Оставить"
L["LESS"] = "Меньше"
L["NEW"] = "Новый"
L["OK"] = "OK"
L["OVERWRITE"] = "Перезаписать"
L["RECOMMENDED"] = "Рекомендуется"
L["REMOVE"] = "Удалить"
L["RENAME"] = "Переименовать"
L["RESET"] = "Сбросить"
L["UNKNOWN"] = "Неизвестно"

-- Notes & Input
L["ADD_NOTE_PLACEHOLDER"] = "Добавить примечание..."
L["NOTE_OPTIONAL"] = "Примечание (необязательно):"
L["DISPLAY_TEXT_LABEL"] = "Отображаемый текст:"
L["ICON_LABEL"] = "Значок:"
L["ICON_SET"] = "Значок: ✓"
L["SET_LABEL"] = "Набор:"
L["ILVL_PREFIX"] = "ilvl "
L["CURRENT_COLON"] = "Текущий: "
L["WHISPER_KEYS_LABEL"] = "Ключи шепота:"
L["RESPONSE_TEXT_LABEL"] = "Текст ответа:"

-- Announcements
L["ANN_CONSIDERATIONS_DEFAULT"] = "{ml} рассматривает {item} для распределения"

-- Session
L["SESSION_ENDED_DEFAULT"] = "Сессия совета распределения завершена"
L["SESSION_STARTED_DEFAULT"] = "Сессия совета распределения начата"
L["QUEUED_ITEMS_HINT"] = "Предметы в очереди будут отображаться здесь"

-- Loot Council
L["LOOT_COUNCIL"] = "Совет распределения"
L["LOOT_RESPONSE_TITLE"] = "Ответ на добычу"
L["COUNCIL_VOTING_PROGRESS"] = "Ход голосования совета"
L["NO_COUNCIL_VOTES"] = "Голоса совета не поданы"

-- Status messages
L["NOT_IN_GROUP"] = "Вы не в рейде или группе"
L["NOT_IN_GUILD"] = "Вы не в гильдии"
L["APPLY_TO_CURRENT"] = "Применить к текущему"

-- Columns
L["COLUMN_INST"] = "Экз"
L["COLUMN_ROLE"] = "Роль"
L["COLUMN_VOTE"] = "Голос"
L["COLUMN_WK"] = "Нед"
L["COLUMN_WON"] = "Выигр"
L["COLUMN_TOOLTIP_WON_INSTANCE"] = "Предметы, выигранные в этом подземелье + сложности"
L["COLUMN_TOOLTIP_WON_SESSION"] = "Предметы, выигранные за эту сессию"
L["COLUMN_TOOLTIP_WON_WEEKLY"] = "Предметы, выигранные на этой неделе"

-- Voting
L["VOTE_RANK"] = "Рейтинг"
L["VOTE_RANKED"] = "Ранжировано"
L["VOTES_LABEL"] = "голосов"
L["VOTE_VOTED"] = "Проголосовано"

-- Responses
L["RESPONSE_AUTO_PASS"] = "Автоотказ"
L["RESPONSE_BUTTON_EDITOR"] = "Редактор кнопок ответа"
L["RESPONSE_WAITING"] = "Ожидание..."
L["NEW_BUTTON"] = "Новая кнопка"

-- Config: General
L["CONFIG_LOCAL_PREFS_DESC"] = "Эти параметры влияют только на вас. Они не транслируются в рейд."
L["CONFIG_LOCAL_PREFS_NOTE"] = " Эти параметры влияют только на ваш клиент. Они никогда не отправляются другим участникам рейда."
L["CONFIG_MANAGE"] = "Управление"
L["CONFIG_OPEN_BUTTON_EDITOR"] = "Открыть редактор кнопок ответа"

-- Config: Session/Broadcast
L["CONFIG_SESSION_BROADCAST_DESC"] = "Эти параметры транслируются всем участникам рейда, когда вы Ответственный за добычу. Они управляют сессией для всех."
L["CONFIG_SESSION_BROADCAST_NOTE"] = "Эти параметры транслируются всем участникам рейда, когда вы начинаете сессию как Ответственный за добычу."
L["CONFIG_TRIGGER_SCOPE_NOTE"] = "Столкновения в PvP, на аренах и в сценариях никогда не запускают сессии. По умолчанию только рейды."

-- Config: Voting
L["CONFIG_MAX_REVOTES_DESC"] = "Максимальное количество переголосований за предмет (0 = без переголосований)"
L["CONFIG_VOTING_TIMEOUT_DESC"] = "Если отключено, голосование длится до ручного завершения МЛ."
L["CONFIG_ROLLFRAME_TIMER_ENABLED_DESC"] = "Показывать таймер обратного отсчета на окне ответа. Если отключено, окно остается открытым до вашего ответа или завершения голосования МЛ."

-- Config: Observer
L["CONFIG_OBSERVER_PERMISSIONS_DESC"] = "Управляйте тем, что наблюдатели могут видеть во время голосований."

-- Config: Button Sets
L["CONFIG_BUTTON_SETS_DESC"] = "Настройте наборы кнопок ответа, значки, ключи шепота и назначения кодов типов с помощью визуального редактора."

-- Config: Award Reasons
L["CONFIG_AWARD_REASONS_ENABLED_DESC"] = "Включить или отключить систему причин выдачи"
L["CONFIG_REQUIRE_AWARD_REASON_DESC"] = "Требовать выбора причины выдачи перед выдачей предмета"
L["CONFIG_REASONS"] = "Причины"
L["CONFIG_REASON_DEFAULT"] = "Причина"
L["CONFIG_NEW_REASON_DEFAULT"] = "Новая причина"
L["CONFIG_CONFIRM_REMOVE_REASON"] = "Удалить эту причину выдачи?"
L["CONFIG_CONFIRM_RESET_REASONS"] = "Сбросить все причины выдачи к значениям по умолчанию? Это невозможно отменить."

-- Config: Council
L["CONFIG_COUNCIL_ADD_HELP"] = "Члены совета могут голосовать при распределении добычи. Используйте поле ниже для добавления участников по имени."
L["CONFIG_COUNCIL_ADD_NAME_DESC"] = "Введите имя персонажа (например, 'Имяигрока' или 'Имяигрока-Сервер')"
L["CONFIG_COUNCIL_ALL_REMOVED"] = "Все члены совета удалены"
L["CONFIG_COUNCIL_CONFIRM_REMOVE"] = "Удалить %s из совета?"
L["CONFIG_COUNCIL_CONFIRM_REMOVE_ALL"] = "Удалить ВСЕХ членов совета?"
L["CONFIG_COUNCIL_MEMBER_REMOVED"] = "%s удалён из совета"
L["CONFIG_COUNCIL_NO_MEMBERS"] = "Члены совета ещё не добавлены."
L["CONFIG_COUNCIL_REMOVE_DESC"] = "Выберите участника для удаления из совета"

-- Config: History
L["CONFIG_HISTORY_ALL_CLEARED"] = "Вся история очищена"

-- Auto-Award
L["AUTO_AWARD_TARGET_NOT_IN_RAID"] = "Цель автовыдачи %s не в рейде"
L["AWARD_FOR"] = "Выдать за..."
L["AWARD_LATER_ALL_DESC"] = "Отметить все предметы для выдачи после сессии"
L["AWARD_LATER_ITEM_DESC"] = "Отметить этот предмет для выдачи после сессии"
L["AWARD_LATER_SHORT"] = "Позже"

-- Response Sets
L["CANNOT_DELETE_LAST_SET"] = "Невозможно удалить последний набор ответов."

-- Enchanters
L["CLICK_SELECT_ENCHANTER"] = "Нажмите для выбора зачарователя"
L["SELECT_ENCHANTER"] = "Выбрать зачарователя"
L["DISENCHANT_TARGET"] = "Цель распыления"

-- Equipped Gear
L["EQUIPPED_GEAR"] = "Надетое снаряжение"
L["VIEW_GEAR"] = "Просмотр снаряжения"

-- Item Categories
L["ITEM_CATEGORY_CONSUMABLE"] = "Расходуемое"
L["ITEM_CATEGORY_CRAFTING"] = "Реагент крафта"
L["ITEM_CATEGORY_ENCHANTING"] = "Материал зачарования"
L["ITEM_CATEGORY_GEM"] = "Самоцвет"
L["ITEM_CATEGORY_TRADE_GOODS"] = "Товары"

-- Quality Names
L["QUALITY_POOR"] = "Низкое"
L["QUALITY_COMMON"] = "Обычное"
L["QUALITY_UNCOMMON"] = "Необычное"
L["QUALITY_RARE"] = "Редкое"
L["QUALITY_EPIC"] = "Эпическое"
L["QUALITY_LEGENDARY"] = "Легендарное"
L["QUALITY_ARTIFACT"] = "Артефакт"
L["QUALITY_HEIRLOOM"] = "Наследие"
L["QUALITY_UNKNOWN"] = "Неизвестно"

-- Queue
L["REMOVE_FROM_QUEUE"] = "Удалить из очереди"
L["REMOVE_FROM_SESSION"] = "Удалить из сессии"

-- Roster
L["ROSTER_COUNCIL_MEMBER"] = "Член совета"
L["ROSTER_DEAD"] = "Мертв"
L["ROSTER_MASTER_LOOTER"] = "Ответственный за добычу"
L["ROSTER_NO_ROLE"] = "Нет роли"
L["ROSTER_NOT_INSTALLED"] = "Не установлен"
L["ROSTER_OFFLINE"] = "Не в сети"
L["ROSTER_RANK_MEMBER"] = "Участник"
L["ROSTER_UNKNOWN"] = "Неизвестно"
L["ROSTER_TOOLTIP_GROUP"] = "Группа: "
L["ROSTER_TOOLTIP_LOOT_HISTORY"] = "История добычи: %d предметов"
L["ROSTER_TOOLTIP_ROLE"] = "Роль: "
L["ROSTER_TOOLTIP_TEST_VERSION"] = "Тестовая версия: "
L["ROSTER_TOOLTIP_VERSION"] = "Loothing: "

-- Profiles
L["CREATE_NEW_PROFILE"] = "Создать новый профиль"
L["IMPORT_SUMMARY"] = "Профиль: %s | Экспортировано: %s | Версия: %s"
L["PROFILE_ERR_EMPTY"] = "Имя не может быть пустым"
L["PROFILE_ERR_INVALID_CHARS"] = "Имя содержит недопустимые символы"
L["PROFILE_ERR_NOT_STRING"] = "Имя должно быть строкой"
L["PROFILE_ERR_TOO_LONG"] = "Имя не должно превышать 48 символов"
L["PROFILE_SHARE_BUTTON"] = "Поделиться"
L["PROFILE_SHARE_DESC"] = "Отправить текущую строку экспорта напрямую одному участнику группы в сети."
L["PROFILE_SHARE_FAILED"] = "Не удалось импортировать общие параметры от %s: %s"
L["PROFILE_SHARE_FAILED_GENERIC"] = "Ошибка отправки: %s"
L["PROFILE_SHARE_RECEIVED"] = "Получены общие параметры от %s."
L["PROFILE_SHARE_SENT"] = "Текущий профиль отправлен %s."
L["PROFILE_SHARE_TARGET"] = "Отправить кому"
L["PROFILE_SHARE_TARGET_REQUIRED"] = "Сначала выберите цель."
L["PROFILE_SHARE_UNAVAILABLE"] = "Обмен профилями недоступен."

-- Popups: Award/Skip
L["POPUP_AWARD_LATER"] = "Выдать {item} себе для распределения позже?"
L["POPUP_SKIP_ITEM"] = "Пропустить {item} без выдачи?"
L["POPUP_SKIP_ITEM_FMT"] = "Пропустить %s без выдачи?"

-- Popups: Council
L["POPUP_CLEAR_COUNCIL"] = "Удалить всех членов совета?"
L["POPUP_CLEAR_COUNCIL_COUNT"] = "Удалить всех %d членов совета?"

-- Popups: Ignored Items
L["POPUP_CLEAR_IGNORED"] = "Очистить все игнорируемые предметы?"
L["POPUP_CLEAR_IGNORED_COUNT"] = "Очистить все %d игнорируемых предметов?"

-- Popups: Session
L["POPUP_CONFIRM_END_SESSION"] = "Вы уверены, что хотите завершить текущую сессию? Все ожидающие предметы будут закрыты."
L["POPUP_CONFIRM_USAGE"] = "Вы хотите использовать Loothing для распределения добычи в этом рейде?"
L["POPUP_START_SESSION"] = "Начать сессию для {boss}?"
L["POPUP_START_SESSION_FMT"] = "Начать сессию для %s?"
L["POPUP_START_SESSION_GENERIC"] = "Начать сессию?"

-- Popups: Revote
L["POPUP_CONFIRM_REVOTE"] = "Сбросить все голоса и начать голосование заново за {item}?"
L["POPUP_CONFIRM_REVOTE_FMT"] = "Сбросить все голоса и начать голосование заново за %s?"

-- Popups: Reannounce
L["POPUP_REANNOUNCE"] = "Объявить заново все предметы группе?"
L["POPUP_REANNOUNCE_TITLE"] = "Повторное объявление предметов"
L["POPUP_RENAME_SET"] = "Введите новое имя набора:"
L["POPUP_RESET_ALL_SETS"] = "Сбросить ВСЕ наборы ответов к значениям по умолчанию? Это невозможно отменить."

-- Popups: History
L["POPUP_DELETE_HISTORY_ALL"] = "Удалить ВСЕ записи истории? Это невозможно отменить."
L["POPUP_DELETE_HISTORY_MULTI"] = "Удалить %d записей истории? Это невозможно отменить."
L["POPUP_DELETE_HISTORY_SELECTED"] = "Удалить выбранные записи истории? Это невозможно отменить."
L["POPUP_DELETE_HISTORY_SINGLE"] = "Удалить 1 запись истории? Это невозможно отменить."
L["POPUP_DELETE_RESPONSE_BUTTON"] = "Удалить эту кнопку ответа?"
L["POPUP_DELETE_RESPONSE_SET"] = "Удалить этот набор ответов? Это невозможно отменить."

-- Popups: Import
L["POPUP_IMPORT_OVERWRITE"] = "Этот импорт перезапишет {count} существующих записей истории. Продолжить?"
L["POPUP_IMPORT_OVERWRITE_MULTI"] = "Этот импорт перезапишет %d существующих записей истории. Продолжить?"
L["POPUP_IMPORT_OVERWRITE_SINGLE"] = "Этот импорт перезапишет 1 существующую запись истории. Продолжить?"
L["POPUP_IMPORT_SETTINGS"] = "Выберите способ применения импортированных параметров:"
L["POPUP_IMPORT_SETTINGS_TITLE"] = "Импорт параметров"

-- Popups: Profile
L["POPUP_OVERWRITE_PROFILE"] = "Это перезапишет параметры текущего профиля. Продолжить?"
L["POPUP_OVERWRITE_PROFILE_TITLE"] = "Перезапись профиля"

-- Popups: Keep/Trade
L["POPUP_KEEP_OR_TRADE"] = "Что вы хотите сделать с {item}?"
L["POPUP_KEEP_OR_TRADE_FMT"] = "Что вы хотите сделать с %s?"

-- Popups: Sync
L["POPUP_SYNC_GENERIC_FMT"] = "%s хочет синхронизировать свои %s с вами. Принять?"
L["POPUP_SYNC_HISTORY_FMT"] = "%s хочет синхронизировать свою историю добычи (%d дней) с вами. Принять?"
L["POPUP_SYNC_REQUEST"] = "{player} хочет синхронизировать свои {type} с вами. Принять?"
L["POPUP_SYNC_REQUEST_TITLE"] = "Запрос синхронизации"
L["POPUP_SYNC_SETTINGS_FMT"] = "%s хочет синхронизировать свои параметры Loothing с вами. Принять?"

-- Popups: Trade
L["POPUP_TRADE_ADD_ITEMS"] = "Добавить {count} выданных предметов в торговлю с {player}?"
L["POPUP_TRADE_ADD_MULTI"] = "Добавить %d выданных предметов в торговлю с %s?"
L["POPUP_TRADE_ADD_SINGLE"] = "Добавить 1 выданный предмет в торговлю с %s?"

-- Sync
L["SYNC_ACCEPTED_FROM"] = "Синхронизация принята от %s"
L["SYNC_HISTORY_COMPLETED"] = "Синхронизация истории завершена для %d получателей"
L["SYNC_HISTORY_GUILD_DAYS"] = "Запрос синхронизации истории (%d дней) в гильдию..."
L["SYNC_HISTORY_SENT"] = "Отправлено %d записей истории для %s"
L["SYNC_HISTORY_TO_PLAYER"] = "Запрос синхронизации истории (%d дней) для %s"
L["SYNC_SETTINGS_APPLIED"] = "Применены параметры от %s"
L["SYNC_SETTINGS_COMPLETED"] = "Синхронизация параметров завершена для %d получателей"
L["SYNC_SETTINGS_SENT"] = "Параметры отправлены %s"
L["SYNC_SETTINGS_TO_GUILD"] = "Запрос синхронизации параметров в гильдию..."
L["SYNC_SETTINGS_TO_PLAYER"] = "Запрос синхронизации параметров для %s"

-- Trade
L["TRADE_BTN"] = "Торговля"
L["TRADE_COMPLETED"] = "%s передан(а) %s"
L["TRADE_ITEM_LOCKED"] = "Предмет заблокирован: %s"
L["TRADE_ITEM_NOT_FOUND"] = "Не удалось найти предмет для торговли: %s"
L["TRADE_ITEMS_PENDING"] = "У вас %d предмет(ов) для торговли с %s. Нажмите на предметы, чтобы добавить их в окно торговли."
L["TRADE_TOO_MANY_ITEMS"] = "Слишком много предметов для торговли — будут добавлены только первые 6."
L["TRADE_WINDOW_URGENT"] = "|cffff0000СРОЧНО:|r Окно торговли для %s (выдано %s) истекает через %d мин!"
L["TRADE_WINDOW_WARNING"] = "|cffff9900Внимание:|r Окно торговли для %s (выдано %s) истекает через %d мин!"
L["TRADE_WRONG_RECIPIENT"] = "Внимание: %s передан(а) %s (был выдан %s)"
L["TOO_MANY_ITEMS_WARNING"] = "Слишком много предметов (%d). Показаны кнопки только для первых %d. Используйте навигацию для доступа ко всем."

-- Version Check
L["VERSION_AND_MORE"] = " и ещё %d"
L["VERSION_CHECK_IN_PROGRESS"] = "Проверка версии уже выполняется"
L["VERSION_OUTDATED_MEMBERS"] = "|cffff9900У %d участников группы устаревший Loothing:|r %s"
L["VERSION_RESULTS_CURRENT"] = "  Актуальная: %d"
L["VERSION_RESULTS_HINT"] = "Используйте /lt version show для подробных результатов"
L["VERSION_RESULTS_NOT_INSTALLED"] = "  |cff888888Не установлен: %d|r"
L["VERSION_RESULTS_OUTDATED"] = "  |cffff0000Устаревшая: %d|r"
L["VERSION_RESULTS_TEST"] = "  |cff00ff00Тестовые версии: %d|r"
L["VERSION_RESULTS_TOTAL"] = "Результаты проверки версии: %d всего"
L["PICK_ICON"] = "Выбрать значок…"

-- Profile Broadcast
L["PROFILE_SHARE_BROADCAST_BUTTON"] = "Отправить в группу"
L["PROFILE_SHARE_BROADCAST_DESC"] = "Отправить текущую строку экспорта в активный рейд или группу. Это может сделать только Ответственный за добычу текущей сессии."
L["PROFILE_SHARE_BROADCAST_SENT"] = "Текущий профиль отправлен в активную группу."
L["PROFILE_SHARE_BROADCAST_CONFIRM"] = "Отправить ваш текущий профиль параметров всей активной группе?"
L["PROFILE_SHARE_BROADCAST_NO_SESSION"] = "Для отправки параметров необходима активная сессия Loothing."
L["PROFILE_SHARE_BROADCAST_NOT_ML"] = "Отправлять параметры может только Ответственный за добычу текущей сессии."
L["PROFILE_SHARE_BROADCAST_BUSY"] = "Очередь передачи данных занята. Повторите попытку через некоторое время."
L["PROFILE_SHARE_BROADCAST_COOLDOWN"] = "Параметры были отправлены недавно. Повторите попытку через %d сек."
L["PROFILE_SHARE_QUEUE_FULL"] = "Общие параметры от %s были отброшены, так как другой импорт уже ожидает обработки."


-- Restored keys (accessed via Loothing.Locale)
L["SESSION_STARTED"] = "Сессия распределения добычи начата для %s"
L["SESSION_ENDED"] = "Сессия распределения добычи завершена"
L["AWARD_TO"] = "Выдать %s"
L["TOTAL_VOTES"] = "Всего: %d голосов"
L["LOOTED_BY"] = "Добыт: %s"
L["ENTRIES_COUNT"] = "Всего: %d записей"
L["ENTRIES_FILTERED"] = "Показано: %d из %d записей"
L["AWARDED_TO"] = "Выдано: %s"
L["FROM_ENCOUNTER"] = "От: %s"
L["WITH_VOTES"] = "Голосов: %d"
L["TAB_SETTINGS"] = "Параметры"
L["SELECT_AWARD_REASON"] = "Выбрать причину выдачи"
L["NO_SELECTION"] = "Ничего не выбрано"
L["YOUR_RANKING"] = "Ваш рейтинг"
L["AWARD_NO_REASON"] = "Выдать (Без причины)"
L["CLEARED_TRADES"] = "Очищено %d завершённых обменов"
L["NO_COMPLETED_TRADES"] = "Нет завершённых обменов для очистки"
L["OBSERVE_MODE_MSG"] = "Вы в режиме наблюдения и не можете голосовать."
L["VOTE_NOTE_REQUIRED"] = "Вы должны добавить примечание к своему голосу."
L["SELF_VOTE_DISABLED"] = "Голосование за себя отключено для этой сессии."



-- Voting States
L["VOTING_STATE_PENDING"] = "Ожидает"
L["VOTING_STATE_VOTING"] = "Голосование"
L["VOTING_STATE_TALLYING"] = "Подсчет"
L["VOTING_STATE_DECIDED"] = "Решено"
L["VOTING_STATE_REVOTING"] = "Переголосование"

-- Enchanter/Disenchant
L["NO_ENCHANTERS"] = "Зачарователи в группе не обнаружены"
L["DISENCHANT_TARGET_SET"] = "Цель для распыления установлена: %s"
L["DISENCHANT_TARGET_CLEARED"] = "Цель для распыления сброшена"
