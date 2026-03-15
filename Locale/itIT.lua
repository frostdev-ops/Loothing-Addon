--[[--------------------------------------------------------------------
    Loothing - Loot Council Addon for WoW 12.0+
    Locale - Italian (itIT) localization
----------------------------------------------------------------------]]

local _, ns = ...
local Loothing = ns.Addon

local locale = (Loothing.ForceLocale or GetLocale())
if locale ~= "itIT" then
    return
end

local base = Loothing.Locale or {}
local L = setmetatable({}, { __index = base })

-- General
L["ADDON_LOADED"] = "Loothing v%s caricato. Digita /loothing o /lt per le opzioni."
L["SLASH_HELP"] = "Comandi: /loothing [show|hide|config|history|council]"

-- Session
L["SESSION"] = "Sessione"
L["SESSION_START"] = "Inizia sessione"
L["SESSION_END"] = "Termina sessione"
L["SESSION_ACTIVE"] = "Sessione attiva"
L["SESSION_INACTIVE"] = "Nessuna sessione attiva"
L["SESSION_STARTED"] = "Sessione del consiglio bottino avviata per %s"
L["SESSION_ENDED"] = "Sessione del consiglio bottino terminata"
L["NO_ITEMS"] = "Nessun oggetto nella sessione"
L["YOU_ARE_ML"] = "Sei il Maestro del bottino"
L["ERROR_NOT_ML"] = "Solo il Maestro del bottino può farlo"

-- Voting
L["VOTE"] = "Voto"
L["VOTING"] = "Votazione"
L["VOTE_NOW"] = "Vota ora"
L["START_VOTE"] = "Inizia votazione"
L["VOTING_OPEN"] = "Votazione aperta per %s"
L["VOTING_CLOSED"] = "Votazione chiusa"
L["VOTES_RECEIVED"] = "%d/%d voti ricevuti"
L["TIME_REMAINING"] = "%d secondi rimanenti"
L["SUBMIT_VOTE"] = "Invia voto"
L["SUBMIT_RESPONSE"] = "Invia risposta"
L["VOTE_SUBMITTED"] = "Voto inviato"

-- Responses
L["NEED"] = "Necessità"
L["GREED"] = "Avidità"
L["OFFSPEC"] = "Spec secondaria"
L["TRANSMOG"] = "Transmog"
L["PASS"] = "Passa"

-- Response descriptions
L["NEED_DESC"] = "Potenziamento spec principale"
L["GREED_DESC"] = "Interesse generale"
L["OFFSPEC_DESC"] = "Spec secondaria o alt"
L["TRANSMOG_DESC"] = "Solo aspetto"
L["PASS_DESC"] = "Non interessato"

-- Awards
L["AWARD"] = "Assegna"
L["AWARD_TO"] = "Assegna a %s"
L["CONFIRM_AWARD"] = "Assegnare %s a %s?"
L["ITEM_AWARDED"] = "%s assegnato a %s"
L["SKIP_ITEM"] = "Salta oggetto"
L["DISENCHANT"] = "Disincanta"

-- Results
L["RESULTS"] = "Risultati"
L["WINNER"] = "Vincitore"
L["NO_VOTES"] = "Nessun voto ricevuto"
L["TIE"] = "Parità"
L["TOTAL_VOTES"] = "Totale: %d voti"

-- Council
L["COUNCIL"] = "Consiglio"
L["COUNCIL_MEMBERS"] = "Membri del consiglio"
L["ADD_MEMBER"] = "Aggiungi membro"
L["REMOVE_MEMBER"] = "Rimuovi membro"

-- History
L["HISTORY"] = "Cronologia"
L["LOOT_HISTORY"] = "Cronologia bottino"
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
L["TAB_SETTINGS"] = "Impostazioni"

-- Settings
L["SETTINGS"] = "Impostazioni"
L["GENERAL"] = "Generale"
L["VOTING_TIMEOUT"] = "Timeout votazione"
L["SECONDS"] = "secondi"
L["SHOW_MINIMAP"] = "Mostra pulsante minimappa"

-- Announcements
L["ANNOUNCEMENT_SETTINGS"] = "Impostazioni annunci"
L["ANNOUNCE_AWARDS"] = "Annuncia assegnazioni"
L["ANNOUNCE_ITEMS"] = "Annuncia oggetti"
L["CHANNEL_RAID"] = "Raid"
L["CHANNEL_GUILD"] = "Gilda"
L["CHANNEL_PARTY"] = "Gruppo"
L["CHANNEL_NONE"] = "Nessuno"

-- Errors
L["ERROR_NOT_IN_RAID"] = "Devi essere in un raid"
L["ERROR_NO_ITEM"] = "Nessun oggetto selezionato"
L["ERROR_NO_SESSION"] = "Nessuna sessione attiva"

-- Sync
L["SYNCING"] = "Sincronizzazione..."
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
L["ROLL_FRAME_TITLE"] = "Tiro del dado"
L["ROLL_SUBMIT"] = "Invia risposta"
L["ROLL_TIME_REMAINING"] = "Tempo: %ds"
L["ROLL_TIME_EXPIRED"] = "Tempo scaduto"

-- Council Table
L["COUNCIL_TABLE_TITLE"] = "Consiglio bottino - Candidati"
L["COUNCIL_AWARD"] = "Assegna"
L["COUNCIL_SKIP"] = "Salta"

-- Locale Override
L["CONFIG_LOCALE_OVERRIDE"] = "Sovrascrittura lingua"
L["CONFIG_LOCALE_OVERRIDE_DESC"] = "Imposta la lingua dell'addon manualmente (richiede /reload)"
L["LOCALE_AUTO"] = "Automatico (lingua del gioco)"

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
