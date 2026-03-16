--[[--------------------------------------------------------------------
    Loothing - Loot Council Addon für WoW 12.0+
    Locale - German (deDE) localization
----------------------------------------------------------------------]]

local ADDON_NAME, ns = ...
local Loolib = LibStub("Loolib")
local LoolibLocale = Loolib.Locale or Loolib:GetModule("Locale")
local L = LoolibLocale:NewLocale(ADDON_NAME, "deDE")
if not L then return end

-- General
L["ADDON_NAME"] = "Loothing"
L["ADDON_LOADED"] = "Loothing v%s geladen. Tippe /loothing oder /lt für Optionen."
L["SLASH_HELP_HEADER"] = "Loothing Befehle (verwende /lt help <befehl>):"
L["SLASH_HELP_DETAIL"] = "Verwendung für /lt %s:"
L["SLASH_HELP_UNKNOWN"] = "Unbekannter Befehl '%s'. Verwende /lt help."
L["SLASH_HELP_DEBUG_NOTE"] = "Aktiviere /lt debug um Entwickler-Befehle zu sehen."
L["SLASH_NO_MAINFRAME"] = "Hauptfenster noch nicht verfügbar."
L["SLASH_NO_CONFIG"] = "Konfigurationsdialog nicht verfügbar."
L["SLASH_INVALID_ITEM"] = "Ungültiger Itemlink."
L["SLASH_SYNC_UNAVAILABLE"] = "Synchronisierungsmodul nicht verfügbar."
L["SLASH_IMPORT_UNAVAILABLE"] = "Importmodul nicht verfügbar."
L["SLASH_IMPORT_PROMPT"] = "Bereitstellung von CSV/TSV Text: /lt import <daten>"
L["SLASH_IMPORT_PARSE_ERROR"] = "Analysefehler: %s"
L["SLASH_IMPORT_SUCCESS"] = "%d Einträge importiert."
L["SLASH_IMPORT_FAILED"] = "Import fehlgeschlagen: %s"
L["SLASH_DEBUG_STATE"] = "Loothing Debug: %s"
L["SLASH_DEBUG_REQUIRED"] = "Aktiviere den Debug-Modus mit /lt debug um diesen Befehl zu verwenden."
L["SLASH_TEST_UNAVAILABLE"] = "Testmodus nicht verfügbar."
L["SLASH_DESC_SHOW"] = "Hauptfenster anzeigen"
L["SLASH_DESC_HIDE"] = "Hauptfenster verbergen"
L["SLASH_DESC_TOGGLE"] = "Hauptfenster umschalten"
L["SLASH_DESC_CONFIG"] = "Einstellungsdialog öffnen"
L["SLASH_DESC_HISTORY"] = "Verlauf-Tab öffnen"
L["SLASH_DESC_COUNCIL"] = "Beuterat-Einstellungen öffnen"
L["SLASH_DESC_ML"] = "Plündermeister anzeigen oder zuweisen"
L["SLASH_DESC_IGNORE"] = "Item zur Ignorier-Liste hinzufügen/entfernen"
L["SLASH_DESC_SYNC"] = "Einstellungen oder Verlauf synchronisieren"
L["SLASH_DESC_IMPORT"] = "Beuteverlauf-Text importieren"
L["SLASH_DESC_DEBUG"] = "Debug-Modus umschalten (aktiviert Entwickler-Befehle)"
L["SLASH_DESC_TEST"] = "Testmodus-Utilities"
L["SLASH_DESC_TESTMODE"] = "Simulator/Testmodus steuern"
L["SLASH_DESC_HELP"] = "Befehlshilfe anzeigen"
L["SLASH_DESC_START"] = "Beuteverteilung aktivieren"
L["SLASH_DESC_STOP"] = "Beuteverteilung deaktivieren"

-- Session
L["SESSION_ACTIVE"] = "Session aktiv"
L["SESSION_CLOSED"] = "Session beendet"
L["NO_ITEMS"] = "Keine Items in der Session"
L["MANUAL_SESSION"] = "Manuelle Session"
L["ITEMS_COUNT"] = "%d Items (%d ausstehend, %d abstimmend, %d fertig)"
L["YOU_ARE_ML"] = "Du bist Plündermeister"
L["ML_IS"] = "PM: %s"
L["ML_IS_EXPLICIT"] = "Plündermeister: %s (zugewiesen)"
L["ML_IS_RAID_LEADER"] = "Plündermeister: %s (Schlachtzugsleiter)"
L["ML_NOT_SET"] = "Kein Plündermeister (nicht in einer Gruppe)"
L["ML_CLEARED"] = "Plündermeister gelöscht - verwende Schlachtzugsleiter"
L["ML_ASSIGNED"] = "Plündermeister zugewiesen an %s"
L["ML_HANDLING_LOOT"] = "Verteile jetzt die Beute."
L["ML_NOT_ACTIVE_SESSION"] = "Loothing ist für diese Session nicht aktiv. Verwende '/loothing start' zum manuellen Aktivieren."
L["ML_USAGE_PROMPT_TEXT"] = "Du bist der Schlachtzugsleiter. Loothing für die Beuteverteilung verwenden?"
L["ML_USAGE_PROMPT_TEXT_INSTANCE"] = "Du bist der Schlachtzugsleiter.\nLoothing für %s verwenden?"
L["ML_STOPPED_HANDLING"] = "Beuteverteilung beendet."
L["RECONNECT_RESTORED"] = "Session-Status aus dem Cache wiederhergestellt."
L["ERROR_NOT_ML_OR_RL"] = "Nur der Plündermeister oder Schlachtzugsleiter kann dies tun"
L["REFRESH"] = "Aktualisieren"
L["ITEM"] = "Gegenstand"
L["STATUS"] = "Status"
L["START_ALL"] = "Alle starten"
L["DATE"] = "Datum"

-- Voting
L["VOTE"] = "Abstimmung"
L["VOTING"] = "Abstimmung"
L["START_VOTE"] = "Abstimmung starten"
L["TIME_REMAINING"] = "%d Sekunden verbleibend"
L["SUBMIT_VOTE"] = "Abstimmung abgeben"
L["SUBMIT_RESPONSE"] = "Antwort abgeben"
L["CHANGE_VOTE"] = "Abstimmung ändern"

-- Responses

-- Response descriptions

-- Awards
L["AWARD"] = "Zuteilung"
L["AWARD_ITEM"] = "Item zuteilen"
L["CONFIRM_AWARD"] = "%s an %s zuteilen?"
L["ITEM_AWARDED"] = "%s zugewiesen an %s"
L["SKIP_ITEM"] = "Item überspringen"
L["DISENCHANT"] = "Entzaubern"

-- Results
L["RESULTS"] = "Ergebnisse"
L["WINNER"] = "Gewinner"
L["TIE"] = "Gleichstand"

-- Council
L["COUNCIL"] = "Beuterat"
L["COUNCIL_MEMBERS"] = "Beuterat-Mitglieder"
L["ADD_MEMBER"] = "Mitglied hinzufügen"
L["REMOVE_MEMBER"] = "Mitglied entfernen"
L["IS_COUNCIL"] = "%s ist ein Beuterat-Mitglied"
L["AUTO_OFFICERS"] = "Offiziere automatisch einbeziehen"
L["AUTO_RAID_LEADER"] = "Schlachtzugsleiter automatisch einbeziehen"

-- History
L["HISTORY"] = "Verlauf"
L["NO_HISTORY"] = "Kein Beuteverlauf"
L["CLEAR_HISTORY"] = "Verlauf löschen"
L["CONFIRM_CLEAR_HISTORY"] = "Gesamten Beuteverlauf löschen?"
L["EXPORT"] = "Exportieren"
L["EXPORT_HISTORY"] = "Verlauf exportieren"
L["EXPORT_EQDKP"] = "EQdkp"
L["SEARCH"] = "Suchen..."
L["SELECT_ALL"] = "Alle auswählen"
L["ALL_WINNERS"] = "Alle Gewinner"
L["CLEAR"] = "Löschen"

-- Tabs
L["TAB_SESSION"] = "Sitzung"
L["TAB_TRADE"] = "Handel"
L["TAB_HISTORY"] = "Verlauf"
L["TAB_ROSTER"] = "Aufstellung"

-- Roster
L["ROSTER_SUMMARY"] = "%d Mitglieder | %d Online | %d Installiert | %d Rat"
L["ROSTER_NO_GROUP"] = "Nicht in einer Gruppe"
L["ROSTER_QUERY_VERSIONS"] = "Versionen abfragen"
L["ROSTER_ADD_COUNCIL"] = "Zum Rat hinzufügen"
L["ROSTER_REMOVE_COUNCIL"] = "Aus dem Rat entfernen"
L["ROSTER_SET_ML"] = "Als Plündermeister festlegen"
L["ROSTER_CLEAR_ML"] = "Plündermeister entfernen"
L["ROSTER_PROMOTE_LEADER"] = "Zum Anführer befördern"
L["ROSTER_PROMOTE_ASSISTANT"] = "Zum Assistenten befördern"
L["ROSTER_DEMOTE"] = "Degradieren"
L["ROSTER_UNINVITE"] = "Aus Gruppe entfernen"
L["ROSTER_ADD_OBSERVER"] = "Als Beobachter hinzufügen"
L["ROSTER_REMOVE_OBSERVER"] = "Beobachter entfernen"

-- Settings
L["SETTINGS"] = "Einstellungen"
L["GENERAL"] = "Allgemein"
L["VOTING_MODE"] = "Abstimmungsmodus"
L["SIMPLE_VOTING"] = "Einfach (Die meisten Stimmen gewinnen)"
L["RANKED_VOTING"] = "Rangordnung"
L["VOTING_TIMEOUT"] = "Abstimmungs-Timeout"
L["SECONDS"] = "Sekunden"
L["AUTO_INCLUDE_OFFICERS"] = "Offiziere automatisch einbeziehen"
L["AUTO_INCLUDE_LEADER"] = "Schlachtzugsleiter automatisch einbeziehen"
L["ADD"] = "Hinzufügen"

-- Auto-Pass
L["AUTOPASS_SETTINGS"] = "Automatisch Passen"
L["ENABLE_AUTOPASS"] = "Automatisch Passen aktivieren"
L["AUTOPASS_DESC"] = "Automatisch passen bei Gegenständen die du nicht verwenden kannst"
L["AUTOPASS_WEAPONS"] = "Waffen automatisch passen (falsches Primärattribut)"

-- Announcement Settings
L["ANNOUNCEMENT_SETTINGS"] = "Ankündigungseinstellungen"
L["ANNOUNCE_AWARDS"] = "Zuteilen ankündigen"
L["ANNOUNCE_ITEMS"] = "Items ankündigen"
L["ANNOUNCE_BOSS_KILL"] = "Session-Start/-Ende ankündigen"
L["CHANNEL_RAID"] = "Schlachtzug"
L["CHANNEL_RAID_WARNING"] = "Schlachtzugswarnung"
L["CHANNEL_OFFICER"] = "Offizier"
L["CHANNEL_GUILD"] = "Gilde"
L["CHANNEL_PARTY"] = "Gruppe"
L["CHANNEL_NONE"] = "Keine"

-- Auto-Award
L["AUTO_AWARD_SETTINGS"] = "Auto-Zuteilung Einstellungen"
L["AUTO_AWARD_ENABLE"] = "Auto-Zuteilung aktivieren"
L["AUTO_AWARD_DESC"] = "Items automatisch unterhalb der Qualitätsschwelle zuteilen"
L["AUTO_AWARD_TO"] = "Zuteilung an"
L["AUTO_AWARD_TO_DESC"] = "Spielername oder 'disenchanter'"

-- Ignore Items
L["IGNORE_ITEMS_SETTINGS"] = "Ignorierte Items"
L["ENABLE_IGNORE_LIST"] = "Ignorier-Liste aktivieren"
L["IGNORE_LIST_DESC"] = "Items auf der Ignorier-Liste werden nicht vom Loot Council verfolgt"
L["IGNORED_ITEMS"] = "Ignorierte Items"
L["NO_IGNORED_ITEMS"] = "Derzeit werden keine Items ignoriert"
L["ADD_IGNORED_ITEM"] = "Item zur Ignorier-Liste hinzufügen"
L["REMOVE_IGNORED_ITEM"] = "Von Ignorier-Liste entfernen"
L["ITEM_IGNORED"] = "%s zur Ignorier-Liste hinzugefügt"
L["ITEM_UNIGNORED"] = "%s von Ignorier-Liste entfernt"
L["SLASH_IGNORE"] = "/loothing ignore [itemlink] - Item zur/von Ignorier-Liste hinzufügen/entfernen"
L["CLEAR_IGNORED_ITEMS"] = "Alle löschen"
L["CONFIRM_CLEAR_IGNORED"] = "Alle ignorierten Items löschen?"
L["IGNORED_ITEMS_CLEARED"] = "Ignorier-Liste gelöscht"
L["IGNORE_CATEGORIES"] = "Kategoriefilter"
L["IGNORE_ADD_DESC"] = "Füge einen Itemlink ein oder gib eine Item-ID ein."

-- Errors
L["ERROR_NO_SESSION"] = "Keine aktive Session"

-- Communication
L["SYNC_COMPLETE"] = "Synchronisierung abgeschlossen"

-- Guild Sync
L["HISTORY_SYNCED"] = "%d Verlaufseinträge synchronisiert von %s"
L["SYNC_IN_PROGRESS"] = "Synchronisierung bereits im Gange"
L["SYNC_TIMEOUT"] = "Synchronisierung abgelaufen"

-- Tooltips
L["TOOLTIP_ITEM_LEVEL"] = "Gegenstandsstufe: %d"
L["TOOLTIP_VOTES"] = "Stimmen: %d"

-- Status
L["STATUS_PENDING"] = "Ausstehend"
L["STATUS_VOTING"] = "Abstimmung"
L["STATUS_TALLIED"] = "Gezählt"
L["STATUS_AWARDED"] = "Zugewiesen"
L["STATUS_SKIPPED"] = "Übersprungen"

-- Response Settings
L["RESET_RESPONSES"] = "Auf Standard zurücksetzen"

-- Award Reason Settings
L["REQUIRE_AWARD_REASON"] = "Grund beim Zuteilen erforderlich"
L["AWARD_REASONS"] = "Zuteilungsgründe"
L["ADD_REASON"] = "Grund hinzufügen"
L["REASON_NAME"] = "Grundname"
L["AWARD_REASON"] = "Zuteilungsgrund"

-- Trade Panel
L["TRADE_QUEUE"] = "Tausch-Warteschlange"
L["TRADE_PANEL_HELP"] = "Klick auf einen Spielernamen um Handel zu starten"
L["NO_PENDING_TRADES"] = "Keine ausstehenden Tauschs"
L["NO_ITEMS_TO_TRADE"] = "Keine Items zum Tausch"
L["ONE_ITEM_TO_TRADE"] = "1 Item wartet auf Tausch"
L["N_ITEMS_TO_TRADE"] = "%d Items warten auf Tausch"
L["AUTO_TRADE"] = "Auto-Tausch"
L["CLEAR_COMPLETED"] = "Abgeschlossene löschen"

-- Minimap

-- Voting Options
L["SELF_VOTE"] = "Selbst-Abstimmung erlauben"
L["SELF_VOTE_DESC"] = "Beuterat-Mitglieder können für sich selbst abstimmen"
L["MULTI_VOTE"] = "Mehrfach-Abstimmung erlauben"
L["MULTI_VOTE_DESC"] = "Mehrere Kandidaten pro Item abstimmen"
L["ANONYMOUS_VOTING"] = "Anonyme Abstimmung"
L["ANONYMOUS_VOTING_DESC"] = "Verbergen wer für wen abstimmt bis Item zugewiesen ist"
L["HIDE_VOTES"] = "Stimmen-Anzahl verbergen"
L["HIDE_VOTES_DESC"] = "Stimmen-Anzahl nicht anzeigen bis alle Stimmen eingegangen sind"
L["OBSERVE_MODE"] = "Beobachtermodus"
L["AUTO_ADD_ROLLS"] = "Auto-Rolls hinzufügen"
L["AUTO_ADD_ROLLS_DESC"] = "Automatisch /roll Ergebnisse zu Kandidaten hinzufügen"
L["REQUIRE_NOTES"] = "Notizen erforderlich"
L["REQUIRE_NOTES_DESC"] = "Abstimmende müssen eine Notiz mit ihrer Abstimmung hinzufügen"

-- Button Sets
L["BUTTON_SETS"] = "Tasten-Sets"
L["ACTIVE_SET"] = "Aktives Set"
L["NEW_SET"] = "Neues Set"
L["CONFIRM_DELETE_SET"] = "Tasten-Set '%s' löschen?"
L["ADD_BUTTON"] = "Taste hinzufügen"
L["MAX_BUTTONS"] = "Maximal 10 Tasten pro Set"
L["MIN_BUTTONS"] = "Mindestens 1 Taste erforderlich"
L["DEFAULT_SET"] = "Standard"
L["SORT_ORDER"] = "Sortierreihenfolge"
L["BUTTON_COLOR"] = "Tasten-Farbe"

-- Filters
L["FILTERS"] = "Filter"
L["FILTER_BY_CLASS"] = "Nach Klasse filtern"
L["FILTER_BY_RESPONSE"] = "Nach Antwort filtern"
L["FILTER_BY_RANK"] = "Nach Gilden-Rang filtern"
L["SHOW_EQUIPPABLE_ONLY"] = "Nur Ausrüstbare anzeigen"
L["HIDE_PASSED_ITEMS"] = "Übersprungene Items verbergen"
L["CLEAR_FILTERS"] = "Filter löschen"
L["ALL_CLASSES"] = "Alle Klassen"
L["ALL_RESPONSES"] = "Alle Antworten"
L["ALL_RANKS"] = "Alle Ränge"
L["FILTERS_ACTIVE"] = "%d Filter aktiv"

-- Generic / Missing strings
L["YES"] = "Ja"
L["NO"] = "Nein"
L["TIME_EXPIRED"] = "Zeit abgelaufen"
L["END_SESSION"] = "Session beenden"
L["END_VOTE"] = "Abstimmung beenden"
L["START_SESSION"] = "Session starten"
L["OPEN_MAIN_WINDOW"] = "Hauptfenster öffnen"
L["RE_VOTE"] = "Neu abstimmen"
L["ROLL_REQUEST"] = "Roll-Anfrage"
L["ROLL_REQUEST_SENT"] = "Roll-Anfrage gesendet"
L["SELECT_RESPONSE"] = "Antwort auswählen"
L["HIDE_MINIMAP_BUTTON"] = "Minimap-Button verbergen"
L["NO_SESSION"] = "Keine aktive Session"
L["MINIMAP_TOOLTIP_LEFT"] = "Linksklick: Loothing öffnen"
L["MINIMAP_TOOLTIP_RIGHT"] = "Rechtsklick: Optionen"
L["RESULTS_TITLE"] = "Ergebnisse"
L["VOTE_TITLE"] = "Loot-Antwort"
L["VOTES"] = "Stimmen"
L["ITEMS_PENDING"] = "%d Items ausstehend"
L["ITEMS_VOTING"] = "%d Items abstimmend"
L["LINK_IN_CHAT"] = "Im Chat verlinken"
L["VIEW"] = "Anzeigen"

-- Group Loot

-- Frame/UI Settings

-- Master Looter Settings
L["CONFIG_ML_SETTINGS"] = "Plündermeister-Einstellungen"

-- History Settings
L["CONFIG_HISTORY_SETTINGS"] = "Verlauf-Einstellungen"
L["CONFIG_HISTORY_ENABLED"] = "Verlauf aktivieren"
L["CONFIG_HISTORY_CLEARALL_CONFIRM"] = "Bist du sicher dass du ALLE Verlaufseinträge löschen möchtest? Dies kann nicht rückgängig gemacht werden!"

-- Enhanced Announcements

-- Enhanced Award Reasons
L["CONFIG_REASON_LOG"] = "In History protokollieren"
L["CONFIG_REASON_DISENCHANT"] = "Als Entzaubern behandeln"
L["CONFIG_REASON_RESET_CONFIRM"] = "Alle Zuteilung-Gründe auf Standard zurücksetzen?"

-- Council Management
L["CONFIG_COUNCIL_REMOVEALL_CONFIRM"] = "Alle Beuterat-Mitglieder entfernen?"

-- Auto-Pass Enhancements
L["CONFIG_AUTOPASS_TRINKETS"] = "Auto-Pass Schmuckstücke"
L["CONFIG_AUTOPASS_SILENT"] = "Stilles Auto-Pass"

-- Voting Enhancements
L["CONFIG_VOTING_MLSEESVOTES"] = "PM sieht Stimmen"
L["CONFIG_VOTING_MLSEESVOTES_DESC"] = "Plündermeister kann Stimmen sehen auch wenn anonym"

-- General Enhancements

-- ============================================================================
-- Roll/Vote System Locale Strings
-- ============================================================================

-- RollFrame UI
L["ROLL_YOUR_ROLL"] = "Dein Wurf:"

-- RollFrame Settings

-- CouncilTable UI
L["COUNCIL_NO_CANDIDATES"] = "Noch keine Kandidaten haben geantwortet"
L["COUNCIL_AWARD"] = "Zuteilen"
L["COUNCIL_REVOTE"] = "Neu abstimmen"
L["COUNCIL_SKIP"] = "Überspringen"
L["COUNCIL_CONFIRM_REVOTE"] = "Alle Stimmen löschen und Abstimmung neu starten?"

-- CouncilTable Settings
L["COUNCIL_COLUMN_PLAYER"] = "Spielername"
L["COUNCIL_COLUMN_RESPONSE"] = "Antwort"
L["COUNCIL_COLUMN_ROLL"] = "Wurf"
L["COUNCIL_COLUMN_NOTE"] = "Notiz"
L["COUNCIL_COLUMN_ILVL"] = "Gegenstandsstufe"
L["COUNCIL_COLUMN_ILVL_DIFF"] = "Upgrade (+/-)"
L["COUNCIL_COLUMN_GEAR1"] = "Ausrüstungsplatz 1"
L["COUNCIL_COLUMN_GEAR2"] = "Ausrüstungsplatz 2"

-- Winner Determination Settings
L["WINNER_DETERMINATION"] = "Gewinner-Bestimmung"
L["WINNER_DETERMINATION_DESC"] = "Konfiguriere wie Gewinner ausgewählt werden wenn Abstimmung endet."
L["WINNER_MODE"] = "Gewinner-Modus"
L["WINNER_MODE_DESC"] = "Wie der Gewinner nach der Abstimmung bestimmt wird"
L["WINNER_MODE_HIGHEST_VOTES"] = "Höchste Beuterat-Stimmen"
L["WINNER_MODE_ML_CONFIRM"] = "ML bestätigt Gewinner"
L["WINNER_MODE_AUTO_CONFIRM"] = "Auto-select Höchste + Bestätigung"
L["WINNER_TIE_BREAKER"] = "Tie-Breaker"
L["WINNER_TIE_BREAKER_DESC"] = "Wie Gleichstände werden aufgelöst wenn Kandidaten gleiche Stimmen haben"
L["WINNER_TIE_USE_ROLL"] = "Würfelwert verwenden"
L["WINNER_TIE_ML_CHOICE"] = "ML wählt"
L["WINNER_TIE_REVOTE"] = "Neu abstimmen auslösen"
L["WINNER_AUTO_AWARD_UNANIMOUS"] = "Auto-Zuteilung bei einstimmig"
L["WINNER_AUTO_AWARD_UNANIMOUS_DESC"] = "Automatisch zuteilen wenn alle Beuterat-Mitglieder für denselben Kandidaten abstimmen"
L["WINNER_REQUIRE_CONFIRMATION"] = "Bestätigung erforderlich"
L["WINNER_REQUIRE_CONFIRMATION_DESC"] = "Bestätigungsdialog vor dem Zuteilen von Items anzeigen"

-- Communication messages

-- Council Management (Guild/Group based)

-- Announcements - Considerations
L["CONFIG_CONSIDERATIONS"] = "Überlegungen"
L["CONFIG_CONSIDERATIONS_CHANNEL"] = "Kanal"
L["CONFIG_CONSIDERATIONS_TEXT"] = "Nachrichtenvorlage"

-- Announcements - Line Configuration
L["CONFIG_LINE"] = "Zeile"
L["CONFIG_ENABLED"] = "Aktiviert"
L["CONFIG_CHANNEL"] = "Kanal"

-- Session Announcements

-- Award Reasons
L["CONFIG_NUM_REASONS_DESC"] = "Anzahl der aktiven Zuteilung-Gründe (1-20)"
L["CONFIG_AWARD_REASONS_DESC"] = "Konfiguriere Zuteilungsgründe. Jeder Grund kann zum Protokollieren ein- und ausgeschaltet werden und als Entzaubern markiert werden."
L["CONFIG_RESET_REASONS"] = "Auf Standard zurücksetzen"

-- Frame Settings (using OptionsTable naming convention)
L["CONFIG_FRAME_MINIMIZE_COMBAT"] = "Im Kampf minimieren"
L["CONFIG_FRAME_TIMEOUT_FLASH"] = "Bei Timeout blinken"
L["CONFIG_FRAME_BLOCK_TRADES"] = "Tauschs während Abstimmung blockieren"

-- History Settings (OptionsTable variants)
L["CONFIG_HISTORY_SEND"] = "Verlauf senden"
L["CONFIG_HISTORY_CLEAR_ALL"] = "Alle löschen"
L["CONFIG_HISTORY_AUTO_EXPORT_WEB"] = "Web-Export automatisch anzeigen"
L["CONFIG_HISTORY_AUTO_EXPORT_WEB_DESC"] = "Nach Session-Ende automatisch den Export-Dialog mit Web-Export zum Kopieren öffnen"

-- Whisper Commands
L["WHISPER_RESPONSE_RECEIVED"] = "Loothing: Antwort '%s' erhalten für %s"
L["WHISPER_NO_SESSION"] = "Loothing: Keine aktive Session"
L["WHISPER_NO_VOTING_ITEMS"] = "Loothing: Keine Items derzeit zur Abstimmung offen"
L["WHISPER_UNKNOWN_COMMAND"] = "Loothing: Unbekannter Befehl '%s'. Flüstere !help für Optionen"
L["WHISPER_HELP_HEADER"] = "Loothing: Flüster-Befehle:"
L["WHISPER_HELP_LINE"] = "  %s - %s"
L["WHISPER_ITEM_SPECIFIED"] = "Loothing: Antwort '%s' erhalten für %s (#%d)"
L["WHISPER_INVALID_ITEM_NUM"] = "Loothing: Ungültige Item-Nummer %d (Session hat %d Items)"

-- ============================================================================
-- Phase 1-6 Additional Locale Strings
-- ============================================================================

-- General / UI
L["ADDON_TAGLINE"] = "Loot Council Addon"
L["VERSION"] = "Version"
L["VERSION_CHECK"] = "Versionsprüfung"
L["OUTDATED"] = "Veraltet"
L["NOT_INSTALLED"] = "Nicht installiert"
L["CURRENT"] = "Aktuell"
L["ENABLED"] = "Aktiviert"
L["REQUIRED"] = "Erforderlich"
L["NOTE"] = "Notiz:"
L["PLAYER"] = "Spieler"
L["SEND"] = "Senden"
L["SEND_TO"] = "Senden an:"
L["WHISPER"] = "Flüstern"

-- Blizzard Settings Integration
L["BLIZZARD_SETTINGS_DESC"] = "Klicke unten um das vollständige Einstellungsfenster zu öffnen"
L["OPEN_SETTINGS"] = "Loothing-Einstellungen öffnen"

-- Slash Commands (Debug)
L["SLASH_DESC_ERRORS"] = "Erfasste Fehler anzeigen"
L["SLASH_DESC_LOG"] = "Letzte Protokolle anzeigen"

-- Session Panel
L["ADD_ITEM"] = "Item hinzufügen"
L["ADD_ITEM_TITLE"] = "Item zur Session hinzufügen"
L["ENTER_ITEM"] = "Item eingeben"
L["RECENT_DROPS"] = "Letzte Drops"
L["FROM_BAGS"] = "Aus Taschen"
L["ENTER_ITEM_HINT"] = "Itemlink, Item-ID einfügen oder Item hierher ziehen"
L["DRAG_ITEM_HERE"] = "Item hier ablegen"
L["NO_RECENT_DROPS"] = "Keine handelbaren Items gefunden"
L["NO_BAG_ITEMS"] = "Keine geeigneten Items in den Taschen"
L["EQUIPMENT_ONLY"] = "Nur Ausrüstung"
L["SLASH_DESC_ADD"] = "Item zur Session hinzufügen"
L["AWARD_LATER_ALL"] = "Später zuteilen (Alle)"

-- Session Trigger Modes (legacy)
L["TRIGGER_MANUAL"] = "Manuell (verwende /loothing start)"
L["TRIGGER_AUTO"] = "Automatisch (sofort starten)"
L["TRIGGER_PROMPT"] = "Nachfragen (vor dem Start fragen)"

-- Session Trigger Policy (split model)
L["SESSION_TRIGGER_HEADER"] = "Session-Auslöser"
L["SESSION_TRIGGER_ACTION"] = "Auslöser-Aktion"
L["SESSION_TRIGGER_ACTION_DESC"] = "Was passiert wenn ein Boss-Sieg berechtigt ist"
L["SESSION_TRIGGER_TIMING"] = "Auslöser-Zeitpunkt"
L["SESSION_TRIGGER_TIMING_DESC"] = "Wann die Auslöser-Aktion relativ zum Boss-Sieg ausgeführt wird"
L["TRIGGER_TIMING_ENCOUNTER_END"] = "Bei Boss-Sieg"
L["TRIGGER_TIMING_AFTER_LOOT"] = "Nachdem ML Loot erhalten hat"
L["TRIGGER_SCOPE_RAID"] = "Schlachtzug-Bosse"
L["TRIGGER_SCOPE_RAID_DESC"] = "Bei Schlachtzug-Boss-Siegen auslösen"
L["TRIGGER_SCOPE_DUNGEON"] = "Dungeon-Bosse"
L["TRIGGER_SCOPE_DUNGEON_DESC"] = "Bei Dungeon-Boss-Siegen auslösen"
L["TRIGGER_SCOPE_OPEN_WORLD"] = "Offene Welt"
L["TRIGGER_SCOPE_OPEN_WORLD_DESC"] = "Bei offenen-Welt-Begegnungen auslösen (z.B. Weltbosse)"

-- AutoPass Options
L["CONFIG_AUTOPASS_BOE"] = "Auto-Pass BoE-Items"
L["CONFIG_AUTOPASS_BOE_DESC"] = "Automatisch passen bei Beim-Anlegen-Gebundenen Items"
L["CONFIG_AUTOPASS_TRANSMOG"] = "Auto-Pass Transmog"
L["CONFIG_AUTOPASS_TRANSMOG_SOURCE"] = "Bekannte Vorlagen überspringen"

-- Auto Award Options
L["CONFIG_AUTO_AWARD_LOWER_THRESHOLD"] = "Untere Qualitätsschwelle"
L["CONFIG_AUTO_AWARD_UPPER_THRESHOLD"] = "Obere Qualitätsschwelle"
L["CONFIG_AUTO_AWARD_REASON"] = "Zuteilungsgrund"
L["CONFIG_AUTO_AWARD_INCLUDE_BOE"] = "BoE-Items einbeziehen"

-- Frame Behavior Options
L["CONFIG_FRAME_BEHAVIOR"] = "Fenster-Verhalten"
L["CONFIG_FRAME_AUTO_OPEN"] = "Fenster automatisch öffnen"
L["CONFIG_FRAME_AUTO_CLOSE"] = "Fenster automatisch schließen"
L["CONFIG_FRAME_SHOW_SPEC_ICON"] = "Spezialisierungs-Icons anzeigen"
L["CONFIG_FRAME_CLOSE_ESCAPE"] = "Mit Escape schließen"
L["CONFIG_FRAME_CHAT_OUTPUT"] = "Chat-Ausgabe Fenster"

-- ML Usage Options
L["CONFIG_ML_USAGE_MODE"] = "Verwendungsmodus"
L["CONFIG_ML_USAGE_NEVER"] = "Nie"
L["CONFIG_ML_USAGE_GL"] = "Gruppen-Loot"
L["CONFIG_ML_USAGE_ASK_GL"] = "Fragen bei Gruppen-Loot"
L["CONFIG_ML_RAIDS_ONLY"] = "Nur Schlachtzüge"
L["CONFIG_ML_ALLOW_OUTSIDE"] = "Außerhalb von Schlachtzügen erlauben"
L["CONFIG_ML_SKIP_SESSION"] = "Session-Fenster überspringen"
L["CONFIG_ML_SORT_ITEMS"] = "Items sortieren"
L["CONFIG_ML_AUTO_ADD_BOES"] = "BoEs automatisch hinzufügen"
L["CONFIG_ML_PRINT_TRADES"] = "Abgeschlossene Tauschs drucken"
L["CONFIG_ML_REJECT_TRADE"] = "Ungültige Tauschs ablehnen"
L["CONFIG_ML_AWARD_LATER"] = "Später zuteilen"

-- History Options
L["CONFIG_HISTORY_SEND_GUILD"] = "An Gilde senden"
L["CONFIG_HISTORY_SAVE_PL"] = "Persönlichen Loot speichern"

-- Ignore Item Options
L["CONFIG_IGNORE_ENCHANTING_MATS"] = "Verzauberungsmaterialien ignorieren"
L["CONFIG_IGNORE_CRAFTING_REAGENTS"] = "Handwerksmaterialien ignorieren"
L["CONFIG_IGNORE_CONSUMABLES"] = "Verbrauchsgegenstände ignorieren"
L["CONFIG_IGNORE_PERMANENT_ENHANCEMENTS"] = "Dauerhafte Verbesserungen ignorieren"

-- Announcement Options
L["CONFIG_ANNOUNCEMENT_TOKENS_DESC"] = "Verfügbare Token: {item}, {winner}, {reason}, {notes}, {ilvl}, {type}, {oldItem}, {ml}, {session}, {votes}"
L["CONFIG_ANNOUNCE_CONSIDERATIONS"] = "Überlegungen ankündigen"
L["CONFIG_ITEM_ANNOUNCEMENTS"] = "Item-Ankündigungen"
L["CONFIG_SESSION_ANNOUNCEMENTS"] = "Session-Ankündigungen"
L["CONFIG_SESSION_START"] = "Session-Start"
L["CONFIG_SESSION_END"] = "Session-Ende"
L["CONFIG_MESSAGE"] = "Nachricht"

-- Button Sets & Type Code Options
L["CONFIG_BUTTON_SETS"] = "Tasten-Sets"
L["CONFIG_TYPECODE_ASSIGNMENT"] = "Typencode-Zuweisung"

-- Award Reasons Options
L["CONFIG_AWARD_REASONS"] = "Zuteilungsgründe"
L["NUM_AWARD_REASONS"] = "Anzahl der Gründe"

-- Council Guild Rank Options
L["CONFIG_GUILD_RANK"] = "Gilden-Rang automatisch einbeziehen"
L["CONFIG_GUILD_RANK_DESC"] = "Gilden-Mitglieder ab einem bestimmten Rang automatisch in den Beuterat einbeziehen"
L["CONFIG_MIN_RANK"] = "Mindest-Gildenrang"
L["CONFIG_MIN_RANK_DESC"] = "Gilden-Mitglieder mit diesem Rang oder höher werden automatisch als Beuterat-Mitglieder einbezogen. 0 = deaktiviert, 1 = Gildenmeister, 2 = Offiziere, usw."
L["CONFIG_COUNCIL_REMOVE_ALL"] = "Alle Mitglieder entfernen"

-- Council Table UI
L["CHANGE_RESPONSE"] = "Antwort ändern"

-- Sync Panel UI
L["SYNC_DATA"] = "Daten synchronisieren"
L["SELECT_TARGET"] = "Ziel auswählen"
L["SELECT_TARGET_FIRST"] = "Zuerst einen Zielspieler auswählen"
L["NO_TARGETS"] = "Keine Online-Mitglieder gefunden"
L["GUILD"] = "Gilde (Alle Online)"
L["QUERY_GROUP"] = "Gruppe abfragen"
L["LAST_7_DAYS"] = "Letzte 7 Tage"
L["LAST_30_DAYS"] = "Letzte 30 Tage"
L["ALL_TIME"] = "Gesamter Zeitraum"
L["SYNCING_TO"] = "Synchronisiere %s an %s..."

-- History Panel UI
L["DATE_RANGE"] = "Zeitraum:"
L["FILTER_BY_WINNER"] = "Filtern nach %s"
L["DELETE_ENTRY"] = "Eintrag löschen"

-- Observer System
L["OBSERVER"] = "Beobachter"

-- ML Observer
L["CONFIG_ML_OBSERVER"] = "PM-Beobachtermodus"
L["CONFIG_ML_OBSERVER_DESC"] = "Plündermeister kann alles sehen und Sessions verwalten, aber nicht abstimmen"

-- Open Observation (replaces OBSERVE_MODE)
L["OPEN_OBSERVATION"] = "Offene Beobachtung"
L["OPEN_OBSERVATION_DESC"] = "Allen Schlachtzugsmitgliedern erlauben die Abstimmung zu beobachten (fügt alle als Beobachter hinzu)"

-- Observer Permissions
L["OBSERVER_PERMISSIONS"] = "Beobachter-Berechtigungen"
L["OBSERVER_SEE_VOTE_COUNTS"] = "Stimmen-Anzahl sehen"
L["OBSERVER_SEE_VOTE_COUNTS_DESC"] = "Beobachter können sehen wie viele Stimmen jeder Kandidat hat"
L["OBSERVER_SEE_VOTER_IDS"] = "Abstimmende sehen"
L["OBSERVER_SEE_VOTER_IDS_DESC"] = "Beobachter können sehen wer für welchen Kandidaten gestimmt hat"
L["OBSERVER_SEE_RESPONSES"] = "Antworten sehen"
L["OBSERVER_SEE_RESPONSES_DESC"] = "Beobachter können sehen welche Antwort jeder Kandidat gewählt hat"
L["OBSERVER_SEE_NOTES"] = "Notizen sehen"
L["OBSERVER_SEE_NOTES_DESC"] = "Beobachter können Kandidaten-Notizen sehen"

-- Bulk Actions
L["BULK_START_VOTE"] = "Abstimmung starten (%d)"
L["BULK_END_VOTE"] = "Abstimmung beenden (%d)"
L["BULK_SKIP"] = "Überspringen (%d)"
L["BULK_REMOVE"] = "Entfernen (%d)"
L["BULK_REVOTE"] = "Neu abstimmen (%d)"
L["BULK_AWARD_LATER"] = "Später zuteilen"
L["DESELECT_ALL"] = "Auswahl aufheben"
L["N_SELECTED"] = "%d ausgewählt"
L["REMOVE_ITEMS"] = "Items entfernen"
L["CONFIRM_BULK_SKIP"] = "%d ausgewählte Items überspringen?"
L["CONFIRM_BULK_REMOVE"] = "%d ausgewählte Items aus der Session entfernen?"
L["CONFIRM_BULK_REVOTE"] = "Neu abstimmen über %d ausgewählte Items?"

-- ============================================================================
-- RCV (Ranked Choice Voting) Audit Strings
-- ============================================================================

-- RCV Settings
L["RCV_SETTINGS"] = "Rangwahl-Einstellungen"
L["MAX_RANKS"] = "Maximale Rangplätze"
L["MIN_RANKS"] = "Mindest-Rangplätze"
L["MAX_RANKS_DESC"] = "Maximale Anzahl an Wahlen die ein Abstimmender platzieren kann (0 = unbegrenzt)"
L["MIN_RANKS_DESC"] = "Mindestanzahl an Wahlen die zum Absenden einer Stimme erforderlich sind"
L["RANK_LIMIT_REACHED"] = "Maximum von %d Rangplätzen erreicht"
L["RANK_MINIMUM_REQUIRED"] = "Mindestens %d Wahlen platzieren"
L["MAX_REVOTES"] = "Maximale Neu-Abstimmungen"

-- ML Sees Votes

-- IRV Round Visualization
L["SHOW_IRV_ROUNDS"] = "IRV-Runden anzeigen (%d Runden)"
L["HIDE_IRV_ROUNDS"] = "IRV-Runden verbergen"

-- Settings Export/Import
L["PROFILES"] = "Profile"
L["EXPORT_SETTINGS"] = "Einstellungen exportieren"
L["IMPORT_SETTINGS"] = "Einstellungen importieren"
L["EXPORT_TITLE"] = "Einstellungen exportieren"
L["EXPORT_DESC"] = "Drücke Strg+A um alles auszuwählen, dann Strg+C zum Kopieren."
L["EXPORT_FAILED"] = "Export fehlgeschlagen: %s"
L["IMPORT_TITLE"] = "Einstellungen importieren"
L["IMPORT_DESC"] = "Füge eine exportierte Einstellungs-Zeichenkette unten ein und klicke auf Importieren."
L["IMPORT_BUTTON"] = "Importieren"
L["IMPORT_FAILED"] = "Import fehlgeschlagen: %s"
L["IMPORT_VERSION_WARN"] = "Hinweis: exportiert mit Loothing v%s (du hast v%s)."
L["IMPORT_SUCCESS_NEW"] = "Einstellungen als neues Profil importiert: %s"
L["IMPORT_SUCCESS_CURRENT"] = "Einstellungen in aktuelles Profil importiert."
L["SLASH_DESC_EXPORT"] = "Aktuelle Profil-Einstellungen exportieren"
L["SLASH_DESC_PROFILE"] = "Profile verwalten (auflisten, wechseln, erstellen)"

-- Profile Management
L["PROFILE_CURRENT"] = "Aktuelles Profil"
L["PROFILE_SWITCH"] = "Profil wechseln"
L["PROFILE_SWITCH_DESC"] = "Wähle ein Profil zum Wechseln."
L["PROFILE_NEW"] = "Neues Profil erstellen"
L["PROFILE_NEW_DESC"] = "Gib einen Namen für das neue Profil ein."
L["PROFILE_COPY_FROM"] = "Kopieren von"
L["PROFILE_COPY_DESC"] = "Einstellungen von einem anderen Profil in das aktuelle kopieren."
L["PROFILE_COPY_CONFIRM"] = "Dies überschreibt alle Einstellungen in deinem aktuellen Profil. Fortfahren?"
L["PROFILE_DELETE"] = "Profil löschen"
L["PROFILE_DELETE_CONFIRM"] = "Bist du sicher dass du dieses Profil löschen möchtest? Dies kann nicht rückgängig gemacht werden."
L["PROFILE_RESET"] = "Auf Standard zurücksetzen"
L["PROFILE_RESET_CONFIRM"] = "Profil '%s' auf Standardeinstellungen zurücksetzen? Dies kann nicht rückgängig gemacht werden."
L["PROFILE_LIST"] = "Alle Profile"
L["PROFILE_DEFAULT_SUFFIX"] = "(Standard)"
L["PROFILE_EXPORT_INLINE_DESC"] = "Erstelle eine Export-Zeichenkette und kopiere sie um deine Einstellungen zu teilen."
L["PROFILE_IMPORT_INLINE_DESC"] = "Füge eine exportierte Einstellungs-Zeichenkette unten ein und klicke auf Importieren."
L["PROFILE_LIST_HEADER"] = "Profile:"
L["PROFILE_SWITCHED"] = "Gewechselt zu Profil: %s"
L["PROFILE_CREATED"] = "Erstellt und gewechselt zu Profil: %s"

-- Locale Override
L["CONFIG_LOCALE_OVERRIDE"] = "Sprache überschreiben"
L["CONFIG_LOCALE_OVERRIDE_DESC"] = "Addon-Sprache manuell einstellen (erfordert /reload)"
L["LOCALE_AUTO"] = "Automatisch (Spielsprache)"

-- Common UI
L["CLOSE"] = "Schließen"
L["CANCEL"] = "Abbrechen"
L["NO_LIMIT"] = "Kein Limit"

-- Personal Preferences
L["PERSONAL_PREFERENCES"] = "Persönliche Einstellungen"
L["CONFIG_LOOT_RESPONSE"] = "Beuteantwort"
L["CONFIG_ROLLFRAME_AUTO_SHOW"] = "Antwortfenster automatisch anzeigen"
L["CONFIG_ROLLFRAME_AUTO_SHOW_DESC"] = "Antwortfenster automatisch anzeigen wenn Abstimmung beginnt"
L["CONFIG_ROLLFRAME_AUTO_ROLL"] = "Auto-Würfeln beim Absenden"
L["CONFIG_ROLLFRAME_AUTO_ROLL_DESC"] = "Automatisch /roll auslösen beim Absenden einer Antwort"
L["CONFIG_ROLLFRAME_GEAR_COMPARE"] = "Ausrüstungsvergleich anzeigen"
L["CONFIG_ROLLFRAME_GEAR_COMPARE_DESC"] = "Aktuell angelegte Items zum Vergleich anzeigen"
L["CONFIG_ROLLFRAME_REQUIRE_NOTE"] = "Notiz erforderlich"
L["CONFIG_ROLLFRAME_REQUIRE_NOTE_DESC"] = "Notiz vor dem Absenden einer Antwort verlangen"
L["CONFIG_ROLLFRAME_PRINT_RESPONSE"] = "Antwort im Chat ausgeben"
L["CONFIG_ROLLFRAME_PRINT_RESPONSE_DESC"] = "Abgesendete Antwort zur eigenen Referenz im Chat ausgeben"
L["CONFIG_ROLLFRAME_TIMER"] = "Antwort-Timer"
L["CONFIG_ROLLFRAME_TIMER_ENABLED"] = "Antwort-Timer anzeigen"
L["CONFIG_ROLLFRAME_TIMER_DURATION"] = "Timer-Dauer"

-- Session Settings (ML)
L["SESSION_SETTINGS_ML"] = "Session-Einstellungen (PM)"
L["VOTING_TIMEOUT_DURATION"] = "Zeitlimit-Dauer"

-- ============================================================================
-- Missing Translations Batch (207 keys)
-- ============================================================================

-- General UI
L["ACCEPT"] = "Annehmen"
L["DECLINE"] = "Ablehnen"
L["OK"] = "OK"
L["EDIT"] = "Bearbeiten"
L["DELETE"] = "Löschen"
L["COPY"] = "Kopieren"
L["COPY_SUFFIX"] = "(Kopie)"
L["RESET"] = "Zurücksetzen"
L["KEEP"] = "Behalten"
L["LESS"] = "Weniger"
L["NEW"] = "Neu"
L["REMOVE"] = "Entfernen"
L["RENAME"] = "Umbenennen"
L["OVERWRITE"] = "Überschreiben"
L["UNKNOWN"] = "Unbekannt"
L["RECOMMENDED"] = "Empfohlen"

-- Notes / Labels
L["ADD_NOTE_PLACEHOLDER"] = "Notiz hinzufügen..."
L["NOTE_OPTIONAL"] = "Notiz (optional):"
L["DISPLAY_TEXT_LABEL"] = "Anzeigetext:"
L["ICON_LABEL"] = "Symbol:"
L["ICON_SET"] = "Symbol: ✓"
L["ILVL_PREFIX"] = "iLvl "
L["SET_LABEL"] = "Set:"
L["CURRENT_COLON"] = "Aktuell: "
L["RESPONSE_TEXT_LABEL"] = "Antworttext:"
L["WHISPER_KEYS_LABEL"] = "Flüster-Schlüssel:"

-- Announcements
L["ANN_CONSIDERATIONS_DEFAULT"] = "{ml} erwägt {item} zur Verteilung"

-- Config / Settings
L["APPLY_TO_CURRENT"] = "Auf Aktuelles anwenden"
L["CONFIG_AWARD_REASONS_ENABLED_DESC"] = "Zuteilungsgründe-System aktivieren oder deaktivieren"
L["CONFIG_BUTTON_SETS_DESC"] = "Konfiguriere Antwort-Tasten-Sets, Symbole, Flüster-Schlüssel und Typencode-Zuweisungen mit dem visuellen Editor."
L["CONFIG_CONFIRM_REMOVE_REASON"] = "Diesen Zuteilungsgrund entfernen?"
L["CONFIG_CONFIRM_RESET_REASONS"] = "Alle Zuteilungsgründe auf Standardwerte zurücksetzen? Dies kann nicht rückgängig gemacht werden."
L["CONFIG_LOCAL_PREFS_DESC"] = "Diese Einstellungen betreffen nur dich. Sie werden nicht an den Schlachtzug übertragen."
L["CONFIG_LOCAL_PREFS_NOTE"] = " Diese Einstellungen betreffen nur deinen Client. Sie werden nie an andere Schlachtzugsmitglieder gesendet."
L["CONFIG_MANAGE"] = "Verwalten"
L["CONFIG_MAX_REVOTES_DESC"] = "Maximale Anzahl an Neu-Abstimmungen pro Item (0 = keine Neu-Abstimmungen)"
L["CONFIG_NEW_REASON_DEFAULT"] = "Neuer Grund"
L["CONFIG_OBSERVER_PERMISSIONS_DESC"] = "Kontrolliere was Beobachter während der Abstimmung sehen können."
L["CONFIG_OPEN_BUTTON_EDITOR"] = "Antwort-Tasten-Editor öffnen"
L["CONFIG_REASON_DEFAULT"] = "Grund"
L["CONFIG_REASONS"] = "Gründe"
L["CONFIG_REQUIRE_AWARD_REASON_DESC"] = "Ein Zuteilungsgrund muss ausgewählt werden bevor ein Item zugeteilt wird"
L["CONFIG_ROLLFRAME_TIMER_ENABLED_DESC"] = "Countdown-Timer im Antwortfenster anzeigen. Wenn deaktiviert, bleibt das Fenster offen bis du antwortest oder der PM die Abstimmung beendet."
L["CONFIG_SESSION_BROADCAST_DESC"] = "Diese Einstellungen werden an alle Schlachtzugsmitglieder übertragen wenn du der Plündermeister bist. Sie steuern die Session für alle."
L["CONFIG_SESSION_BROADCAST_NOTE"] = "Diese Einstellungen werden an alle Schlachtzugsmitglieder übertragen wenn du eine Session als Plündermeister startest."
L["CONFIG_TRIGGER_SCOPE_NOTE"] = "PvP-, Arena- und Szenario-Begegnungen lösen nie Sessions aus. Nur-Schlachtzug ist die Standardeinstellung."
L["CONFIG_VOTING_TIMEOUT_DESC"] = "Wenn deaktiviert, läuft die Abstimmung bis der PM sie manuell beendet."

-- Council
L["CONFIG_COUNCIL_ADD_HELP"] = "Beuteratsmitglieder können über die Beuteverteilung abstimmen. Verwende das Feld unten um Mitglieder per Name hinzuzufügen."
L["CONFIG_COUNCIL_ADD_NAME_DESC"] = "Charaktername eingeben (z.B. 'Spielername' oder 'Spielername-Realm')"
L["CONFIG_COUNCIL_ALL_REMOVED"] = "Alle Beuteratsmitglieder entfernt"
L["CONFIG_COUNCIL_CONFIRM_REMOVE"] = "%s aus dem Beuterat entfernen?"
L["CONFIG_COUNCIL_CONFIRM_REMOVE_ALL"] = "ALLE Beuteratsmitglieder entfernen?"
L["CONFIG_COUNCIL_MEMBER_REMOVED"] = "%s aus dem Beuterat entfernt"
L["CONFIG_COUNCIL_NO_MEMBERS"] = "Noch keine Beuteratsmitglieder hinzugefügt."
L["CONFIG_COUNCIL_REMOVE_DESC"] = "Wähle ein Mitglied zum Entfernen aus dem Beuterat"

-- History Config
L["CONFIG_HISTORY_ALL_CLEARED"] = "Gesamter Verlauf gelöscht"

-- Columns
L["COLUMN_INST"] = "Inst"
L["COLUMN_ROLE"] = "Rolle"
L["COLUMN_TOOLTIP_WON_INSTANCE"] = "In dieser Instanz + Schwierigkeit gewonnene Items"
L["COLUMN_TOOLTIP_WON_SESSION"] = "In dieser Session gewonnene Items"
L["COLUMN_TOOLTIP_WON_WEEKLY"] = "Diese Woche gewonnene Items"
L["COLUMN_VOTE"] = "Stimme"
L["COLUMN_WK"] = "Wo"
L["COLUMN_WON"] = "Gew."

-- Loot Council
L["LOOT_COUNCIL"] = "Beuterat"
L["LOOT_RESPONSE_TITLE"] = "Beuteantwort"
L["COUNCIL_VOTING_PROGRESS"] = "Beuterat-Abstimmungsfortschritt"
L["NO_COUNCIL_VOTES"] = "Keine Beuterat-Stimmen abgegeben"

-- Items
L["EQUIPPED_GEAR"] = "Angelegte Ausrüstung"
L["QUEUED_ITEMS_HINT"] = "Warteschlangen-Items werden hier angezeigt"
L["REMOVE_FROM_QUEUE"] = "Aus Warteschlange entfernen"
L["REMOVE_FROM_SESSION"] = "Aus Session entfernen"
L["ITEM_CATEGORY_CONSUMABLE"] = "Verbrauchsgegenstand"
L["ITEM_CATEGORY_CRAFTING"] = "Handwerksmaterial"
L["ITEM_CATEGORY_ENCHANTING"] = "Verzauberungsmaterial"
L["ITEM_CATEGORY_GEM"] = "Edelstein"
L["ITEM_CATEGORY_TRADE_GOODS"] = "Handelswaren"
L["TOO_MANY_ITEMS_WARNING"] = "Zu viele Items (%d). Zeige nur Tasten für die ersten %d Items. Verwende Navigation um alle zu erreichen."

-- Award
L["AWARD_FOR"] = "Zuteilen für..."
L["AWARD_LATER_ALL_DESC"] = "Alle Items für spätere Zuteilung nach der Session markieren"
L["AWARD_LATER_ITEM_DESC"] = "Dieses Item für spätere Zuteilung nach der Session markieren"
L["AWARD_LATER_SHORT"] = "Später"

-- Auto Award
L["AUTO_AWARD_TARGET_NOT_IN_RAID"] = "Auto-Zuteilungsziel %s ist nicht im Schlachtzug"

-- Not in group/guild
L["NOT_IN_GROUP"] = "Du bist nicht in einem Schlachtzug oder einer Gruppe"
L["NOT_IN_GUILD"] = "Du bist nicht in einer Gilde"

-- Enchanter
L["CLICK_SELECT_ENCHANTER"] = "Klicken um einen Verzauberer auszuwählen"
L["SELECT_ENCHANTER"] = "Verzauberer auswählen"
L["DISENCHANT_TARGET"] = "Entzauberungsziel"

-- Responses
L["RESPONSE_AUTO_PASS"] = "Automatisch gepasst"
L["RESPONSE_BUTTON_EDITOR"] = "Antwort-Tasten-Editor"
L["RESPONSE_WAITING"] = "Warten..."
L["NEW_BUTTON"] = "Neue Taste"
L["PICK_ICON"] = "Symbol wählen…"
L["CANNOT_DELETE_LAST_SET"] = "Das letzte Antwort-Set kann nicht gelöscht werden."

-- Profiles
L["CREATE_NEW_PROFILE"] = "Neues Profil erstellen"
L["IMPORT_SUMMARY"] = "Profil: %s | Exportiert: %s | Version: %s"

-- Profile Sharing
L["PROFILE_SHARE_BUTTON"] = "Teilen"
L["PROFILE_SHARE_DESC"] = "Die aktuelle Export-Zeichenkette direkt an ein Online-Gruppenmitglied senden."
L["PROFILE_SHARE_FAILED"] = "Geteilte Einstellungen von %s konnten nicht importiert werden: %s"
L["PROFILE_SHARE_FAILED_GENERIC"] = "Teilen fehlgeschlagen: %s"
L["PROFILE_SHARE_RECEIVED"] = "Geteilte Einstellungen von %s erhalten."
L["PROFILE_SHARE_SENT"] = "Aktuelles Profil mit %s geteilt."
L["PROFILE_SHARE_TARGET"] = "Teilen mit"
L["PROFILE_SHARE_TARGET_REQUIRED"] = "Zuerst ein Ziel auswählen."
L["PROFILE_SHARE_UNAVAILABLE"] = "Profil-Teilen ist nicht verfügbar."
L["PROFILE_SHARE_BROADCAST_BUTTON"] = "An Gruppe senden"
L["PROFILE_SHARE_BROADCAST_DESC"] = "Die aktuelle Export-Zeichenkette an den aktiven Schlachtzug oder die Gruppe senden. Nur der Plündermeister der aktiven Session kann dies tun."
L["PROFILE_SHARE_BROADCAST_SENT"] = "Aktuelles Profil an die aktive Gruppe gesendet."
L["PROFILE_SHARE_BROADCAST_CONFIRM"] = "Dein aktuelles Einstellungsprofil an die gesamte aktive Gruppe senden?"
L["PROFILE_SHARE_BROADCAST_NO_SESSION"] = "Du brauchst eine aktive Loothing-Session um Einstellungen zu senden."
L["PROFILE_SHARE_BROADCAST_NOT_ML"] = "Nur der Plündermeister der aktiven Session kann Einstellungen senden."
L["PROFILE_SHARE_BROADCAST_BUSY"] = "Die Addon-Kommunikationswarteschlange ist ausgelastet. Versuche es gleich nochmal."
L["PROFILE_SHARE_BROADCAST_COOLDOWN"] = "Einstellungen wurden kürzlich gesendet. Versuche es in %d Sekunden erneut."
L["PROFILE_SHARE_QUEUE_FULL"] = "Geteilte Einstellungen von %s wurden verworfen, da bereits ein anderer Import wartet."

-- Profile Errors
L["PROFILE_ERR_EMPTY"] = "Name darf nicht leer sein"
L["PROFILE_ERR_INVALID_CHARS"] = "Name enthält ungültige Zeichen"
L["PROFILE_ERR_NOT_STRING"] = "Name muss eine Zeichenkette sein"
L["PROFILE_ERR_TOO_LONG"] = "Name darf maximal 48 Zeichen lang sein"

-- Quality Names
L["QUALITY_POOR"] = "Schlecht"
L["QUALITY_COMMON"] = "Gewöhnlich"
L["QUALITY_UNCOMMON"] = "Ungewöhnlich"
L["QUALITY_RARE"] = "Selten"
L["QUALITY_EPIC"] = "Episch"
L["QUALITY_LEGENDARY"] = "Legendär"
L["QUALITY_ARTIFACT"] = "Artefakt"
L["QUALITY_HEIRLOOM"] = "Erbstück"
L["QUALITY_UNKNOWN"] = "Unbekannt"

-- Popups - Award / Session
L["POPUP_AWARD_LATER"] = "{item} an dich selbst zuteilen um es später zu verteilen?"
L["POPUP_CONFIRM_END_SESSION"] = "Bist du sicher dass du die aktuelle Beutesession beenden möchtest? Alle ausstehenden Items werden geschlossen."
L["POPUP_CONFIRM_REVOTE"] = "Alle Stimmen löschen und Abstimmung für {item} neu starten?"
L["POPUP_CONFIRM_REVOTE_FMT"] = "Alle Stimmen löschen und Abstimmung für %s neu starten?"
L["POPUP_CONFIRM_USAGE"] = "Möchtest du Loothing für die Beuteverteilung in diesem Schlachtzug verwenden?"
L["POPUP_REANNOUNCE"] = "Alle Items erneut an die Gruppe ankündigen?"
L["POPUP_REANNOUNCE_TITLE"] = "Items erneut ankündigen"
L["POPUP_RENAME_SET"] = "Neuen Namen für das Set eingeben:"
L["POPUP_RESET_ALL_SETS"] = "ALLE Antwort-Sets auf Standard zurücksetzen? Dies kann nicht rückgängig gemacht werden."
L["POPUP_SKIP_ITEM"] = "{item} ohne Zuteilung überspringen?"
L["POPUP_SKIP_ITEM_FMT"] = "%s ohne Zuteilung überspringen?"
L["POPUP_START_SESSION"] = "Beutesession für {boss} starten?"
L["POPUP_START_SESSION_FMT"] = "Beutesession für %s starten?"
L["POPUP_START_SESSION_GENERIC"] = "Beutesession starten?"

-- Popups - Council
L["POPUP_CLEAR_COUNCIL"] = "Alle Beuteratsmitglieder entfernen?"
L["POPUP_CLEAR_COUNCIL_COUNT"] = "Alle %d Beuteratsmitglieder entfernen?"

-- Popups - Ignored Items
L["POPUP_CLEAR_IGNORED"] = "Alle ignorierten Items löschen?"
L["POPUP_CLEAR_IGNORED_COUNT"] = "Alle %d ignorierten Items löschen?"

-- Popups - History
L["POPUP_DELETE_HISTORY_ALL"] = "ALLE Verlaufseinträge löschen? Dies kann nicht rückgängig gemacht werden."
L["POPUP_DELETE_HISTORY_MULTI"] = "%d Verlaufseinträge löschen? Dies kann nicht rückgängig gemacht werden."
L["POPUP_DELETE_HISTORY_SELECTED"] = "Ausgewählte Verlaufseinträge löschen? Dies kann nicht rückgängig gemacht werden."
L["POPUP_DELETE_HISTORY_SINGLE"] = "1 Verlaufseintrag löschen? Dies kann nicht rückgängig gemacht werden."

-- Popups - Response Sets
L["POPUP_DELETE_RESPONSE_BUTTON"] = "Diese Antwort-Taste löschen?"
L["POPUP_DELETE_RESPONSE_SET"] = "Dieses Antwort-Set löschen? Dies kann nicht rückgängig gemacht werden."

-- Popups - Import
L["POPUP_IMPORT_OVERWRITE"] = "Dieser Import überschreibt {count} bestehende Verlaufseinträge. Fortfahren?"
L["POPUP_IMPORT_OVERWRITE_MULTI"] = "Dieser Import überschreibt %d bestehende Verlaufseinträge. Fortfahren?"
L["POPUP_IMPORT_OVERWRITE_SINGLE"] = "Dieser Import überschreibt 1 bestehenden Verlaufseintrag. Fortfahren?"
L["POPUP_IMPORT_SETTINGS"] = "Wähle wie die importierten Einstellungen angewendet werden sollen:"
L["POPUP_IMPORT_SETTINGS_TITLE"] = "Einstellungen importieren"
L["POPUP_OVERWRITE_PROFILE"] = "Dies überschreibt deine aktuellen Profil-Einstellungen. Fortfahren?"
L["POPUP_OVERWRITE_PROFILE_TITLE"] = "Profil überschreiben"

-- Popups - Keep or Trade
L["POPUP_KEEP_OR_TRADE"] = "Was möchtest du mit {item} machen?"
L["POPUP_KEEP_OR_TRADE_FMT"] = "Was möchtest du mit %s machen?"

-- Popups - Sync
L["POPUP_SYNC_GENERIC_FMT"] = "%s möchte seine/ihre %s mit dir synchronisieren. Annehmen?"
L["POPUP_SYNC_HISTORY_FMT"] = "%s möchte seinen/ihren Beuteverlauf (%d Tage) mit dir synchronisieren. Annehmen?"
L["POPUP_SYNC_REQUEST"] = "{player} möchte seine/ihre {type} mit dir synchronisieren. Annehmen?"
L["POPUP_SYNC_REQUEST_TITLE"] = "Synchronisierungsanfrage"
L["POPUP_SYNC_SETTINGS_FMT"] = "%s möchte seine/ihre Loothing-Einstellungen mit dir synchronisieren. Annehmen?"

-- Popups - Trade
L["POPUP_TRADE_ADD_ITEMS"] = "{count} zugeteilte Items zum Handel mit {player} hinzufügen?"
L["POPUP_TRADE_ADD_MULTI"] = "%d zugeteilte Items zum Handel mit %s hinzufügen?"
L["POPUP_TRADE_ADD_SINGLE"] = "1 zugeteiltes Item zum Handel mit %s hinzufügen?"

-- Roster
L["ROSTER_COUNCIL_MEMBER"] = "Beuteratsmitglied"
L["ROSTER_DEAD"] = "Tot"
L["ROSTER_MASTER_LOOTER"] = "Plündermeister"
L["ROSTER_NO_ROLE"] = "Keine Rolle"
L["ROSTER_NOT_INSTALLED"] = "Nicht installiert"
L["ROSTER_OFFLINE"] = "Offline"
L["ROSTER_RANK_MEMBER"] = "Mitglied"
L["ROSTER_UNKNOWN"] = "Unbekannt"
L["ROSTER_TOOLTIP_GROUP"] = "Gruppe: "
L["ROSTER_TOOLTIP_LOOT_HISTORY"] = "Beuteverlauf: %d Items"
L["ROSTER_TOOLTIP_ROLE"] = "Rolle: "
L["ROSTER_TOOLTIP_TEST_VERSION"] = "Test-Version: "
L["ROSTER_TOOLTIP_VERSION"] = "Loothing: "

-- Session
L["SESSION_ENDED_DEFAULT"] = "Beuterat-Session beendet"
L["SESSION_STARTED_DEFAULT"] = "Beuterat-Session gestartet"

-- Sync
L["SYNC_ACCEPTED_FROM"] = "Synchronisierung von %s angenommen"
L["SYNC_HISTORY_COMPLETED"] = "Verlaufs-Synchronisierung an %d Empfänger abgeschlossen"
L["SYNC_HISTORY_GUILD_DAYS"] = "Verlaufs-Synchronisierung (%d Tage) an Gilde wird angefragt..."
L["SYNC_HISTORY_SENT"] = "%d Verlaufseinträge an %s gesendet"
L["SYNC_HISTORY_TO_PLAYER"] = "Verlaufs-Synchronisierung (%d Tage) an %s wird angefragt"
L["SYNC_SETTINGS_APPLIED"] = "Einstellungen von %s angewendet"
L["SYNC_SETTINGS_COMPLETED"] = "Einstellungs-Synchronisierung an %d Empfänger abgeschlossen"
L["SYNC_SETTINGS_SENT"] = "Einstellungen an %s gesendet"
L["SYNC_SETTINGS_TO_GUILD"] = "Einstellungs-Synchronisierung an Gilde wird angefragt..."
L["SYNC_SETTINGS_TO_PLAYER"] = "Einstellungs-Synchronisierung an %s wird angefragt"

-- Trade
L["TRADE_BTN"] = "Handeln"
L["TRADE_COMPLETED"] = "%s an %s gehandelt"
L["TRADE_ITEM_LOCKED"] = "Item ist gesperrt: %s"
L["TRADE_ITEM_NOT_FOUND"] = "Item zum Handeln nicht gefunden: %s"
L["TRADE_ITEMS_PENDING"] = "Du hast %d Item(s) zum Handeln an %s. Klicke Items an um sie zum Handelsfenster hinzuzufügen."
L["TRADE_TOO_MANY_ITEMS"] = "Zu viele Items zum Handeln - nur die ersten 6 werden hinzugefügt."
L["TRADE_WINDOW_URGENT"] = "|cffff0000DRINGEND:|r Handelsfenster für %s (zugeteilt an %s) läuft in %d Minuten ab!"
L["TRADE_WINDOW_WARNING"] = "|cffff9900Warnung:|r Handelsfenster für %s (zugeteilt an %s) läuft in %d Minuten ab!"
L["TRADE_WRONG_RECIPIENT"] = "Warnung: %s an %s gehandelt (war zugeteilt an %s)"

-- Version Check
L["VERSION_AND_MORE"] = " und %d weitere"
L["VERSION_CHECK_IN_PROGRESS"] = "Versionsprüfung bereits im Gange"
L["VERSION_OUTDATED_MEMBERS"] = "|cffff9900%d Gruppenmitglied(er) haben veraltetes Loothing:|r %s"
L["VERSION_RESULTS_CURRENT"] = "  Aktuell: %d"
L["VERSION_RESULTS_HINT"] = "Verwende /lt version show für detaillierte Ergebnisse"
L["VERSION_RESULTS_NOT_INSTALLED"] = "  |cff888888Nicht installiert: %d|r"
L["VERSION_RESULTS_OUTDATED"] = "  |cffff0000Veraltet: %d|r"
L["VERSION_RESULTS_TEST"] = "  |cff00ff00Test-Versionen: %d|r"
L["VERSION_RESULTS_TOTAL"] = "Versionsprüfung-Ergebnisse: %d gesamt"

-- Voting
L["VIEW_GEAR"] = "Ausrüstung anzeigen"
L["VOTE_RANK"] = "Rang"
L["VOTE_RANKED"] = "Platziert"
L["VOTES_LABEL"] = "Stimmen"
L["VOTE_VOTED"] = "Abgestimmt"

-- Voting States
L["VOTING_STATE_PENDING"] = "Ausstehend"
L["VOTING_STATE_VOTING"] = "Abstimmung"
L["VOTING_STATE_TALLYING"] = "Zählung"
L["VOTING_STATE_DECIDED"] = "Entschieden"
L["VOTING_STATE_REVOTING"] = "Neu abstimmen"

-- Enchanter/Disenchant
L["NO_ENCHANTERS"] = "Keine Verzauberer in der Gruppe gefunden"
L["DISENCHANT_TARGET_SET"] = "Entzauberungsziel gesetzt auf: %s"
L["DISENCHANT_TARGET_CLEARED"] = "Entzauberungsziel gelöscht"

-- Restored keys (accessed via Loothing.Locale)
L["SESSION_STARTED"] = "Loot Council Session gestartet für %s"
L["SESSION_ENDED"] = "Loot Council Session beendet"
L["AWARD_TO"] = "Zuteilung an %s"
L["TOTAL_VOTES"] = "Gesamt: %d Stimmen"
L["LOOTED_BY"] = "Geplündert von: %s"
L["ENTRIES_COUNT"] = "Gesamt: %d Einträge"
L["ENTRIES_FILTERED"] = "Anzeige: %d von %d Einträgen"
L["AWARDED_TO"] = "Zugewiesen an: %s"
L["FROM_ENCOUNTER"] = "Von: %s"
L["WITH_VOTES"] = "Stimmen: %d"
L["TAB_SETTINGS"] = "Einstellungen"
L["SELECT_AWARD_REASON"] = "Zuteilungsgrund auswählen"
L["NO_SELECTION"] = "Keine Auswahl"
L["YOUR_RANKING"] = "Deine Rangfolge"
L["AWARD_NO_REASON"] = "Zuteilen (Kein Grund)"
L["CLEARED_TRADES"] = "%d abgeschlossene Handel(s) gelöscht"
L["NO_COMPLETED_TRADES"] = "Keine abgeschlossenen Handel zum Löschen"
L["OBSERVE_MODE_MSG"] = "Du bist im Beobachtungsmodus und kannst nicht abstimmen."
L["VOTE_NOTE_REQUIRED"] = "Du musst eine Notiz zu deiner Stimme hinzufügen."
L["SELF_VOTE_DISABLED"] = "Selbstabstimmung ist für diese Sitzung deaktiviert."
