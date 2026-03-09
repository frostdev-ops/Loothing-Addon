--[[--------------------------------------------------------------------
    Loothing - Loot Council Addon for WoW 12.0+
    Locale - French (frFR) localization
----------------------------------------------------------------------]]

local locale = (Loothing.ForceLocale or GetLocale())
if locale ~= "frFR" then
    return
end

local base = Loothing.Locale or {}
local L = setmetatable({}, { __index = base })

-- General
L["ADDON_LOADED"] = "Loothing v%s chargé. Tapez /loothing ou /lt pour les options."
L["SLASH_HELP"] = "Commandes : /loothing [show|hide|config|history|council]"
L["SLASH_HELP_HEADER"] = "Commandes Loothing (utilisez /lt help <commande>) :"
L["SLASH_HELP_DETAIL"] = "Utilisation de /lt %s :"
L["SLASH_HELP_UNKNOWN"] = "Commande inconnue '%s'. Utilisez /lt help."

-- Session
L["SESSION"] = "Session"
L["SESSION_START"] = "Démarrer la session"
L["SESSION_END"] = "Terminer la session"
L["SESSION_ACTIVE"] = "Session active"
L["SESSION_INACTIVE"] = "Aucune session active"
L["SESSION_STARTED"] = "Session du conseil de butin démarrée pour %s"
L["SESSION_ENDED"] = "Session du conseil de butin terminée"
L["NO_ITEMS"] = "Aucun objet dans la session"
L["MANUAL_SESSION"] = "Session manuelle"
L["YOU_ARE_ML"] = "Vous êtes le Maître du butin"
L["ML_IS"] = "MB : %s"
L["ML_NOT_SET"] = "Pas de Maître du butin (pas dans un groupe)"
L["ERROR_NOT_ML"] = "Seul le Maître du butin peut faire cela"

-- Voting
L["VOTE"] = "Vote"
L["VOTING"] = "Vote"
L["VOTE_NOW"] = "Voter maintenant"
L["START_VOTE"] = "Démarrer le vote"
L["VOTING_OPEN"] = "Vote ouvert pour %s"
L["VOTING_CLOSED"] = "Vote terminé"
L["VOTES_RECEIVED"] = "%d/%d votes reçus"
L["TIME_REMAINING"] = "%d secondes restantes"
L["SUBMIT_VOTE"] = "Soumettre le vote"
L["SUBMIT_RESPONSE"] = "Soumettre la réponse"
L["CHANGE_VOTE"] = "Changer de vote"
L["VOTE_SUBMITTED"] = "Vote soumis"

-- Responses
L["NEED"] = "Besoin"
L["GREED"] = "Cupidité"
L["OFFSPEC"] = "Spé secondaire"
L["TRANSMOG"] = "Transmog"
L["PASS"] = "Passer"

-- Response descriptions
L["NEED_DESC"] = "Amélioration de spé principale"
L["GREED_DESC"] = "Intérêt général"
L["OFFSPEC_DESC"] = "Spé secondaire ou reroll"
L["TRANSMOG_DESC"] = "Apparence uniquement"
L["PASS_DESC"] = "Pas intéressé"

-- Awards
L["AWARD"] = "Attribuer"
L["AWARD_TO"] = "Attribuer à %s"
L["AWARD_ITEM"] = "Attribuer l'objet"
L["CONFIRM_AWARD"] = "Attribuer %s à %s ?"
L["ITEM_AWARDED"] = "%s attribué à %s"
L["SKIP_ITEM"] = "Passer l'objet"
L["ITEM_SKIPPED"] = "Objet passé"
L["DISENCHANT"] = "Désenchanter"

-- Results
L["RESULTS"] = "Résultats"
L["WINNER"] = "Gagnant"
L["NO_VOTES"] = "Aucun vote reçu"
L["TIE"] = "Égalité"
L["TIE_BREAKER"] = "Départage nécessaire"
L["TOTAL_VOTES"] = "Total : %d votes"

-- Council
L["COUNCIL"] = "Conseil"
L["COUNCIL_MEMBERS"] = "Membres du conseil"
L["ADD_MEMBER"] = "Ajouter un membre"
L["REMOVE_MEMBER"] = "Retirer un membre"
L["NOT_COUNCIL"] = "Vous n'êtes pas membre du conseil"
L["COUNCIL_ONLY"] = "Seuls les membres du conseil peuvent voter"

-- History
L["HISTORY"] = "Historique"
L["LOOT_HISTORY"] = "Historique du butin"
L["NO_HISTORY"] = "Aucun historique"
L["CLEAR_HISTORY"] = "Effacer l'historique"
L["CONFIRM_CLEAR"] = "Effacer tout l'historique du butin ?"
L["EXPORT"] = "Exporter"
L["EXPORT_HISTORY"] = "Exporter l'historique"
L["SEARCH"] = "Rechercher..."

-- Tabs
L["TAB_SESSION"] = "Session"
L["TAB_TRADE"] = "Échange"
L["TAB_HISTORY"] = "Historique"
L["TAB_ROSTER"] = "Liste"
L["ROSTER_SUMMARY"] = "%d Membres | %d En ligne | %d Installés | %d Conseil"
L["ROSTER_NO_GROUP"] = "Pas dans un groupe"
L["ROSTER_QUERY_VERSIONS"] = "Vérifier les versions"
L["ROSTER_ADD_COUNCIL"] = "Ajouter au Conseil"
L["ROSTER_REMOVE_COUNCIL"] = "Retirer du Conseil"
L["ROSTER_SET_ML"] = "Définir comme Maître du butin"
L["ROSTER_CLEAR_ML"] = "Retirer comme Maître du butin"
L["ROSTER_PROMOTE_LEADER"] = "Promouvoir Chef"
L["ROSTER_PROMOTE_ASSISTANT"] = "Promouvoir Assistant"
L["ROSTER_DEMOTE"] = "Rétrograder"
L["ROSTER_UNINVITE"] = "Exclure"
L["ROSTER_ADD_OBSERVER"] = "Ajouter comme Observateur"
L["ROSTER_REMOVE_OBSERVER"] = "Retirer comme Observateur"
L["TAB_SETTINGS"] = "Paramètres"

-- Settings
L["SETTINGS"] = "Paramètres"
L["GENERAL"] = "Général"
L["VOTING_SETTINGS"] = "Paramètres de vote"
L["COUNCIL_SETTINGS"] = "Paramètres du conseil"
L["UI_SETTINGS"] = "Paramètres d'interface"
L["VOTING_TIMEOUT"] = "Délai de vote"
L["SECONDS"] = "secondes"
L["AUTO_START"] = "Démarrer auto la session après un boss"
L["SHOW_MINIMAP"] = "Afficher le bouton minimap"
L["UI_SCALE"] = "Échelle de l'interface"

-- Auto-Pass
L["AUTOPASS_SETTINGS"] = "Paramètres auto-passer"
L["ENABLE_AUTOPASS"] = "Activer auto-passer"
L["AUTOPASS_DESC"] = "Passer automatiquement les objets que vous ne pouvez pas utiliser"

-- Announcements
L["ANNOUNCEMENT_SETTINGS"] = "Paramètres d'annonce"
L["ANNOUNCE_AWARDS"] = "Annoncer les attributions"
L["ANNOUNCE_ITEMS"] = "Annoncer les objets"
L["CHANNEL_RAID"] = "Raid"
L["CHANNEL_RAID_WARNING"] = "Alerte raid"
L["CHANNEL_OFFICER"] = "Officier"
L["CHANNEL_GUILD"] = "Guilde"
L["CHANNEL_PARTY"] = "Groupe"
L["CHANNEL_NONE"] = "Aucun"

-- Auto-Award
L["AUTO_AWARD_SETTINGS"] = "Paramètres d'auto-attribution"
L["AUTO_AWARD_ENABLE"] = "Activer l'auto-attribution"
L["AUTO_AWARD_DESC"] = "Attribuer automatiquement les objets sous le seuil de qualité"

-- Errors
L["ERROR_NOT_IN_RAID"] = "Vous devez être dans un raid"
L["ERROR_NOT_LEADER"] = "Vous devez être le chef de raid ou assistant"
L["ERROR_NO_ITEM"] = "Aucun objet sélectionné"
L["ERROR_SESSION_ACTIVE"] = "Une session est déjà active"
L["ERROR_NO_SESSION"] = "Aucune session active"

-- Sync
L["SYNCING"] = "Synchronisation..."
L["SYNC_COMPLETE"] = "Synchronisation terminée"
L["SYNC_SETTINGS"] = "Synchroniser les paramètres"
L["SYNC_HISTORY"] = "Synchroniser l'historique"
L["ACCEPT_SYNC"] = "Accepter la synchro"
L["DECLINE_SYNC"] = "Refuser la synchro"

-- Generic
L["YES"] = "Oui"
L["NO"] = "Non"

-- Trade Panel
L["TRADE_QUEUE"] = "File d'échange"
L["NO_PENDING_TRADES"] = "Aucun échange en attente"
L["AUTO_TRADE"] = "Échange auto"

-- Minimap
L["MINIMAP_TOOLTIP_LEFT"] = "Clic gauche : Ouvrir Loothing"
L["MINIMAP_TOOLTIP_RIGHT"] = "Clic droit : Options"

-- Roll Frame
L["ROLL_FRAME_TITLE"] = "Lancer de dé"
L["ROLL_YOUR_RESPONSE"] = "Votre réponse"
L["ROLL_SUBMIT"] = "Soumettre la réponse"
L["ROLL_TIME_REMAINING"] = "Temps : %ds"
L["ROLL_TIME_EXPIRED"] = "Temps écoulé"

-- Council Table
L["COUNCIL_TABLE_TITLE"] = "Conseil de butin - Candidats"
L["COUNCIL_AWARD"] = "Attribuer"
L["COUNCIL_REVOTE"] = "Re-voter"
L["COUNCIL_SKIP"] = "Passer"

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
