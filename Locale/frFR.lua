--[[--------------------------------------------------------------------
    Loothing - Loot Council Addon for WoW 12.0+
    Locale - French (frFR) localization
----------------------------------------------------------------------]]

local locale = (LOOTHING_FORCE_LOCALE or GetLocale())
if locale ~= "frFR" then
    return
end

local base = LOOTHING_LOCALE or {}
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

LOOTHING_LOCALE = L
return L
