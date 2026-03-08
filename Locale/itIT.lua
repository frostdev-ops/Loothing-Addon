--[[--------------------------------------------------------------------
    Loothing - Loot Council Addon for WoW 12.0+
    Locale - Italian (itIT) localization
----------------------------------------------------------------------]]

local locale = (LOOTHING_FORCE_LOCALE or GetLocale())
if locale ~= "itIT" then
    return
end

local base = LOOTHING_LOCALE or {}
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

LOOTHING_LOCALE = L
return L
