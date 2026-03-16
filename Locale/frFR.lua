--[[--------------------------------------------------------------------
    Loothing - Loot Council Addon for WoW 12.0+
    Locale - French (frFR) localization
----------------------------------------------------------------------]]

local ADDON_NAME, ns = ...
local Loolib = LibStub("Loolib")
local LoolibLocale = Loolib.Locale or Loolib:GetModule("Locale")
local L = LoolibLocale:NewLocale(ADDON_NAME, "frFR")
if not L then return end

-- General
L["ADDON_LOADED"] = "Loothing v%s chargé. Tapez /loothing ou /lt pour les options."
L["SLASH_HELP_HEADER"] = "Commandes Loothing (utilisez /lt help <commande>) :"
L["SLASH_HELP_DETAIL"] = "Utilisation de /lt %s :"
L["SLASH_HELP_UNKNOWN"] = "Commande inconnue '%s'. Utilisez /lt help."

-- Session
L["SESSION_ACTIVE"] = "Session active"
L["NO_ITEMS"] = "Aucun objet dans la session"
L["MANUAL_SESSION"] = "Session manuelle"
L["YOU_ARE_ML"] = "Vous êtes le Maître du butin"
L["ML_IS"] = "MB : %s"
L["ML_NOT_SET"] = "Pas de Maître du butin (pas dans un groupe)"

-- Voting
L["VOTE"] = "Vote"
L["VOTING"] = "Vote"
L["START_VOTE"] = "Démarrer le vote"
L["TIME_REMAINING"] = "%d secondes restantes"
L["SUBMIT_VOTE"] = "Soumettre le vote"
L["SUBMIT_RESPONSE"] = "Soumettre la réponse"
L["CHANGE_VOTE"] = "Changer de vote"

-- Responses

-- Response descriptions

-- Awards
L["AWARD"] = "Attribuer"
L["AWARD_ITEM"] = "Attribuer l'objet"
L["CONFIRM_AWARD"] = "Attribuer %s à %s ?"
L["ITEM_AWARDED"] = "%s attribué à %s"
L["SKIP_ITEM"] = "Passer l'objet"
L["DISENCHANT"] = "Désenchanter"

-- Results
L["RESULTS"] = "Résultats"
L["WINNER"] = "Gagnant"
L["TIE"] = "Égalité"

-- Council
L["COUNCIL"] = "Conseil"
L["COUNCIL_MEMBERS"] = "Membres du conseil"
L["ADD_MEMBER"] = "Ajouter un membre"
L["REMOVE_MEMBER"] = "Retirer un membre"

-- History
L["HISTORY"] = "Historique"
L["NO_HISTORY"] = "Aucun historique"
L["CLEAR_HISTORY"] = "Effacer l'historique"
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

-- Settings
L["SETTINGS"] = "Paramètres"
L["GENERAL"] = "Général"
L["VOTING_TIMEOUT"] = "Délai de vote"
L["SECONDS"] = "secondes"

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
L["ERROR_NO_SESSION"] = "Aucune session active"

-- Sync
L["SYNC_COMPLETE"] = "Synchronisation terminée"

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

-- Council Table
L["COUNCIL_AWARD"] = "Attribuer"
L["COUNCIL_REVOTE"] = "Re-voter"
L["COUNCIL_SKIP"] = "Passer"

-- Locale Override
L["CONFIG_LOCALE_OVERRIDE"] = "Remplacement de la langue"
L["CONFIG_LOCALE_OVERRIDE_DESC"] = "Définir la langue de l'addon manuellement (nécessite /reload)"
L["LOCALE_AUTO"] = "Automatique (langue du jeu)"

-- Observer System (new strings - untranslated placeholders)
