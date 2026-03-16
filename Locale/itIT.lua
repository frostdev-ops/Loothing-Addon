--[[--------------------------------------------------------------------
    Loothing - Loot Council Addon for WoW 12.0+
    Locale - Italian (itIT) localization
----------------------------------------------------------------------]]

local ADDON_NAME, ns = ...
local Loolib = LibStub("Loolib")
local LoolibLocale = Loolib.Locale or Loolib:GetModule("Locale")
local L = LoolibLocale:NewLocale(ADDON_NAME, "itIT")
if not L then return end

-- General
L["ADDON_LOADED"] = "Loothing v%s caricato. Digita /loothing o /lt per le opzioni."

-- Session
L["SESSION_ACTIVE"] = "Sessione attiva"
L["NO_ITEMS"] = "Nessun oggetto nella sessione"
L["YOU_ARE_ML"] = "Sei il Maestro del bottino"

-- Voting
L["VOTE"] = "Voto"
L["VOTING"] = "Votazione"
L["START_VOTE"] = "Inizia votazione"
L["TIME_REMAINING"] = "%d secondi rimanenti"
L["SUBMIT_VOTE"] = "Invia voto"
L["SUBMIT_RESPONSE"] = "Invia risposta"

-- Responses

-- Response descriptions

-- Awards
L["AWARD"] = "Assegna"
L["CONFIRM_AWARD"] = "Assegnare %s a %s?"
L["ITEM_AWARDED"] = "%s assegnato a %s"
L["SKIP_ITEM"] = "Salta oggetto"
L["DISENCHANT"] = "Disincanta"

-- Results
L["RESULTS"] = "Risultati"
L["WINNER"] = "Vincitore"
L["TIE"] = "Parità"

-- Council
L["COUNCIL"] = "Consiglio"
L["COUNCIL_MEMBERS"] = "Membri del consiglio"
L["ADD_MEMBER"] = "Aggiungi membro"
L["REMOVE_MEMBER"] = "Rimuovi membro"

-- History
L["HISTORY"] = "Cronologia"
L["NO_HISTORY"] = "Nessuna cronologia"
L["CLEAR_HISTORY"] = "Cancella cronologia"
L["EXPORT"] = "Esporta"
L["SEARCH"] = "Cerca..."

-- Tabs
L["TAB_SESSION"] = "Sessione"
L["TAB_TRADE"] = "Scambio"
L["TAB_HISTORY"] = "Cronologia"
L["TAB_ROSTER"] = "Roster"
L["ROSTER_SUMMARY"] = "%d Membri | %d Online | %d Installati | %d Consiglio"
L["ROSTER_NO_GROUP"] = "Non sei in un gruppo"
L["ROSTER_QUERY_VERSIONS"] = "Verifica versioni"
L["ROSTER_ADD_COUNCIL"] = "Aggiungi al Consiglio"
L["ROSTER_REMOVE_COUNCIL"] = "Rimuovi dal Consiglio"
L["ROSTER_SET_ML"] = "Imposta come Maestro del bottino"
L["ROSTER_CLEAR_ML"] = "Rimuovi come Maestro del bottino"
L["ROSTER_PROMOTE_LEADER"] = "Promuovi a Leader"
L["ROSTER_PROMOTE_ASSISTANT"] = "Promuovi ad Assistente"
L["ROSTER_DEMOTE"] = "Degrada"
L["ROSTER_UNINVITE"] = "Espelli"
L["ROSTER_ADD_OBSERVER"] = "Aggiungi come Osservatore"
L["ROSTER_REMOVE_OBSERVER"] = "Rimuovi come Osservatore"

-- Settings
L["SETTINGS"] = "Impostazioni"
L["GENERAL"] = "Generale"
L["VOTING_TIMEOUT"] = "Timeout votazione"
L["SECONDS"] = "secondi"

-- Announcements
L["ANNOUNCEMENT_SETTINGS"] = "Impostazioni annunci"
L["ANNOUNCE_AWARDS"] = "Annuncia assegnazioni"
L["ANNOUNCE_ITEMS"] = "Annuncia oggetti"
L["CHANNEL_RAID"] = "Raid"
L["CHANNEL_GUILD"] = "Gilda"
L["CHANNEL_PARTY"] = "Gruppo"
L["CHANNEL_NONE"] = "Nessuno"

-- Errors
L["ERROR_NO_SESSION"] = "Nessuna sessione attiva"

-- Sync
L["SYNC_COMPLETE"] = "Sincronizzazione completata"

-- Generic
L["YES"] = "Sì"
L["NO"] = "No"

-- Trade
L["TRADE_QUEUE"] = "Coda scambi"
L["AUTO_TRADE"] = "Scambio auto"

-- Minimap
L["MINIMAP_TOOLTIP_LEFT"] = "Clic sinistro: Apri Loothing"
L["MINIMAP_TOOLTIP_RIGHT"] = "Clic destro: Opzioni"

-- Roll Frame

-- Council Table
L["COUNCIL_AWARD"] = "Assegna"
L["COUNCIL_SKIP"] = "Salta"

-- Locale Override
L["CONFIG_LOCALE_OVERRIDE"] = "Sovrascrittura lingua"
L["CONFIG_LOCALE_OVERRIDE_DESC"] = "Imposta la lingua dell'addon manualmente (richiede /reload)"
L["LOCALE_AUTO"] = "Automatico (lingua del gioco)"

-- Observer System (new strings - untranslated placeholders)
