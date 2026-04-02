--[[--------------------------------------------------------------------
    Loothing - Loot Council Addon for WoW 12.0+
    Locale - Portuguese (Brazilian) localization
----------------------------------------------------------------------]]

local ADDON_NAME, ns = ...
local Loolib = LibStub("Loolib")
local LoolibLocale = Loolib.Locale or Loolib:GetModule("Locale")
local L = LoolibLocale:NewLocale(ADDON_NAME, "ptBR")
if not L then return end

-- General
L["ADDON_NAME"] = "Loothing"
L["ADDON_LOADED"] = "Loothing v%s carregado. Digite /loothing ou /lt para opções."
L["SLASH_HELP_HEADER"] = "Comandos Loothing (use /lt help <comando>):"
L["SLASH_HELP_DETAIL"] = "Uso para /lt %s:"
L["SLASH_HELP_UNKNOWN"] = "Comando desconhecido '%s'. Use /lt help."
L["SLASH_HELP_DEBUG_NOTE"] = "Ative /lt debug para ver comandos de desenvolvedor."
L["SLASH_NO_MAINFRAME"] = "Janela principal ainda não disponível."
L["SLASH_NO_CONFIG"] = "Diálogo de configuração não disponível."
L["SLASH_INVALID_ITEM"] = "Link de item inválido."
L["SLASH_SYNC_UNAVAILABLE"] = "Módulo de sincronização não disponível."
L["SLASH_IMPORT_UNAVAILABLE"] = "Módulo de importação não disponível."
L["SLASH_IMPORT_PROMPT"] = "Forneça texto CSV/TSV: /lt import <dados>"
L["SLASH_IMPORT_PARSE_ERROR"] = "Erro ao processar: %s"
L["SLASH_IMPORT_SUCCESS"] = "Importados %d itens."
L["SLASH_IMPORT_FAILED"] = "Falha na importação: %s"
L["SLASH_DEBUG_STATE"] = "Debug Loothing: %s"
L["SLASH_DEBUG_REQUIRED"] = "Ative o modo debug com /lt debug para usar este comando."
L["SLASH_TEST_UNAVAILABLE"] = "Modo teste não disponível."
L["SLASH_DESC_SHOW"] = "Mostrar janela principal"
L["SLASH_DESC_HIDE"] = "Ocultar janela principal"
L["SLASH_DESC_TOGGLE"] = "Alternar janela principal"
L["SLASH_DESC_CONFIG"] = "Abrir diálogo de configurações"
L["SLASH_DESC_HISTORY"] = "Abrir aba de histórico"
L["SLASH_DESC_COUNCIL"] = "Abrir configurações do conselho"
L["SLASH_DESC_ML"] = "Ver ou atribuir Mestre do Saque"
L["SLASH_DESC_IGNORE"] = "Adicionar/remover item da lista de ignorados"
L["SLASH_DESC_SYNC"] = "Sincronizar configurações ou histórico"
L["SLASH_DESC_IMPORT"] = "Importar texto de histórico de Loot"
L["SLASH_DESC_DEBUG"] = "Alternar modo debug (ativa comandos de dev)"
L["SLASH_DESC_TEST"] = "Utilitários de modo teste"
L["SLASH_DESC_TESTMODE"] = "Controlar simulador/modo teste"
L["SLASH_DESC_HELP"] = "Mostrar ajuda de comandos"
L["SLASH_DESC_START"] = "Ativar distribuição de saque"
L["SLASH_DESC_STOP"] = "Desativar distribuição de saque"

-- Session
L["SESSION_ACTIVE"] = "Sessão Ativa"
L["SESSION_CLOSED"] = "Sessão Encerrada"
L["NO_ITEMS"] = "Nenhum item na sessão"
L["MANUAL_SESSION"] = "Sessão Manual"
L["ITEMS_COUNT"] = "%d itens (%d pendentes, %d votação, %d concluídos)"
L["YOU_ARE_ML"] = "Você é o Mestre do Saque"
L["ML_IS"] = "ML: %s"
L["ML_IS_EXPLICIT"] = "Mestre do Saque: %s (atribuído)"
L["ML_IS_RAID_LEADER"] = "Mestre do Saque: %s (líder de raide)"
L["ML_NOT_SET"] = "Nenhum Mestre do Saque (não em grupo)"
L["ML_CLEARED"] = "Mestre do Saque limpo - usando líder de raide"
L["ML_ASSIGNED"] = "Mestre do Saque atribuído a %s"
L["ML_HANDLING_LOOT"] = "Agora distribuindo o saque."
L["ML_NOT_ACTIVE_SESSION"] = "Loothing não está ativo para esta sessão. Use '/loothing start' para ativar manualmente."
L["ML_USAGE_PROMPT_TEXT"] = "Você é o líder de raide. Usar Loothing para distribuição de saque?"
L["ML_USAGE_PROMPT_TEXT_INSTANCE"] = "Você é o líder de raide.\nUsar Loothing para %s?"
L["ML_STOPPED_HANDLING"] = "Parou de distribuir o saque."
L["RECONNECT_RESTORED"] = "Estado da sessão restaurado do cache."
L["ERROR_NOT_ML_OR_RL"] = "Apenas o Mestre do Saque ou Líder de Raide podem fazer isto"
L["REFRESH"] = "Atualizar"
L["ITEM"] = "Item"
L["STATUS"] = "Status"
L["START_ALL"] = "Iniciar Todos"
L["DATE"] = "Data"

-- Voting
L["VOTE"] = "Voto"
L["VOTING"] = "Votação"
L["START_VOTE"] = "Iniciar Votação"
L["TIME_REMAINING"] = "%d segundos restantes"
L["SUBMIT_VOTE"] = "Enviar Voto"
L["SUBMIT_RESPONSE"] = "Enviar Resposta"
L["CHANGE_VOTE"] = "Mudar Voto"

-- Responses

-- Response descriptions

-- Awards
L["AWARD"] = "Prêmio"
L["AWARD_ITEM"] = "Premiar Item"
L["CONFIRM_AWARD"] = "Premiar %s para %s?"
L["ITEM_AWARDED"] = "%s premiado para %s"
L["SKIP_ITEM"] = "Pular Item"
L["DISENCHANT"] = "Desencantamento"

-- Results
L["RESULTS"] = "Resultados"
L["WINNER"] = "Vencedor"
L["TIE"] = "Empate"

-- Council
L["COUNCIL"] = "Conselho"
L["COUNCIL_MEMBERS"] = "Membros do Conselho"
L["ADD_MEMBER"] = "Adicionar Membro"
L["REMOVE_MEMBER"] = "Remover Membro"
L["IS_COUNCIL"] = "%s é membro do conselho"
L["AUTO_OFFICERS"] = "Incluir automaticamente oficiais"
L["AUTO_RAID_LEADER"] = "Incluir automaticamente líder de raide"

-- History
L["HISTORY"] = "Histórico"
L["NO_HISTORY"] = "Nenhum histórico de loot"
L["CLEAR_HISTORY"] = "Limpar Histórico"
L["CONFIRM_CLEAR_HISTORY"] = "Limpar todo o histórico de loot?"
L["EXPORT"] = "Exportar"
L["EXPORT_HISTORY"] = "Exportar Histórico"
L["EXPORT_EQDKP"] = "EQdkp"
L["SEARCH"] = "Pesquisar..."
L["SELECT_ALL"] = "Selecionar Tudo"
L["ALL_WINNERS"] = "Todos os Vencedores"
L["CLEAR"] = "Limpar"

-- Tabs
L["TAB_SESSION"] = "Sessão"
L["TAB_TRADE"] = "Comércio"
L["TAB_HISTORY"] = "Histórico"
L["TAB_ROSTER"] = "Lista"

-- Roster
L["ROSTER_SUMMARY"] = "%d Membros | %d Online | %d Instalados | %d Conselho"
L["ROSTER_NO_GROUP"] = "Não está em um grupo"
L["ROSTER_QUERY_VERSIONS"] = "Verificar versões"
L["ROSTER_ADD_COUNCIL"] = "Adicionar ao Conselho"
L["ROSTER_REMOVE_COUNCIL"] = "Remover do Conselho"
L["ROSTER_SET_ML"] = "Definir como Mestre de Saque"
L["ROSTER_CLEAR_ML"] = "Remover como Mestre de Saque"
L["ROSTER_PROMOTE_LEADER"] = "Promover a Líder"
L["ROSTER_PROMOTE_ASSISTANT"] = "Promover a Assistente"
L["ROSTER_DEMOTE"] = "Rebaixar"
L["ROSTER_UNINVITE"] = "Expulsar"
L["ROSTER_ADD_OBSERVER"] = "Adicionar como Observador"
L["ROSTER_REMOVE_OBSERVER"] = "Remover como Observador"

-- Settings
L["SETTINGS"] = "Configurações"
L["GENERAL"] = "Geral"
L["VOTING_MODE"] = "Modo de Votação"
L["SIMPLE_VOTING"] = "Simples (Maioria vence)"
L["RANKED_VOTING"] = "Escolha Classificada"
L["VOTING_TIMEOUT"] = "Tempo Limite de Votação"
L["SECONDS"] = "segundos"
L["AUTO_INCLUDE_OFFICERS"] = "Incluir automaticamente oficiais"
L["AUTO_INCLUDE_LEADER"] = "Incluir automaticamente líder de raide"
L["ADD"] = "Adicionar"

-- Auto-Pass
L["AUTOPASS_SETTINGS"] = "Configurações de Auto-Pass"
L["ENABLE_AUTOPASS"] = "Ativar Auto-Pass"
L["AUTOPASS_DESC"] = "Passe automaticamente em itens que não pode usar"
L["AUTOPASS_WEAPONS"] = "Auto-pass armas (estatísticas primárias erradas)"

-- Announcement Settings
L["ANNOUNCEMENT_SETTINGS"] = "Configurações de Anúncio"
L["ANNOUNCE_AWARDS"] = "Anunciar Prêmios"
L["ANNOUNCE_ITEMS"] = "Anunciar Itens"
L["ANNOUNCE_BOSS_KILL"] = "Anunciar Início/Fim de Sessão"
L["CHANNEL_RAID"] = "Raide"
L["CHANNEL_RAID_WARNING"] = "Aviso de Raide"
L["CHANNEL_OFFICER"] = "Oficial"
L["CHANNEL_GUILD"] = "Guilda"
L["CHANNEL_PARTY"] = "Grupo"
L["CHANNEL_NONE"] = "Nenhum"

-- Auto-Award
L["AUTO_AWARD_SETTINGS"] = "Configurações de Auto-Prêmio"
L["AUTO_AWARD_ENABLE"] = "Ativar Auto-Prêmio"
L["AUTO_AWARD_DESC"] = "Premiar automaticamente itens abaixo do limite de qualidade"
L["AUTO_AWARD_TO"] = "Premiar Para"
L["AUTO_AWARD_TO_DESC"] = "Nome do jogador ou 'desencantador'"

-- Ignore Items
L["IGNORE_ITEMS_SETTINGS"] = "Itens Ignorados"
L["ENABLE_IGNORE_LIST"] = "Ativar Lista de Ignorados"
L["IGNORE_LIST_DESC"] = "Itens na lista de ignorados não serão rastreados pelo loot council"
L["IGNORED_ITEMS"] = "Itens Ignorados"
L["NO_IGNORED_ITEMS"] = "Nenhum item está sendo ignorado"
L["ADD_IGNORED_ITEM"] = "Adicionar Item à Lista de Ignorados"
L["REMOVE_IGNORED_ITEM"] = "Remover da lista de ignorados"
L["ITEM_IGNORED"] = "%s adicionado à lista de ignorados"
L["ITEM_UNIGNORED"] = "%s removido da lista de ignorados"
L["SLASH_IGNORE"] = "/loothing ignore [itemlink] - Adicionar/remover item da lista de ignorados"
L["CLEAR_IGNORED_ITEMS"] = "Limpar Tudo"
L["CONFIRM_CLEAR_IGNORED"] = "Limpar todos os itens ignorados?"
L["IGNORED_ITEMS_CLEARED"] = "Lista de ignorados limpa"
L["IGNORE_CATEGORIES"] = "Filtros de Categoria"
L["IGNORE_ADD_DESC"] = "Cole um link de item ou insira um ID de item."

-- Locale Override
L["CONFIG_LOCALE_OVERRIDE"] = "Substituir Idioma"
L["CONFIG_LOCALE_OVERRIDE_DESC"] = "Definir idioma do addon manualmente (requer /reload)"
L["LOCALE_AUTO"] = "Automático (idioma do jogo)"

-- Common UI
L["CLOSE"] = "Fechar"
L["CANCEL"] = "Cancelar"
L["NO_LIMIT"] = "Sem limite"

-- Personal Preferences
L["PERSONAL_PREFERENCES"] = "Preferências pessoais"
L["CONFIG_LOOT_RESPONSE"] = "Resposta de saque"
L["CONFIG_ROLLFRAME_AUTO_SHOW"] = "Mostrar quadro de resposta automaticamente"
L["CONFIG_ROLLFRAME_AUTO_SHOW_DESC"] = "Mostrar automaticamente o quadro de resposta quando a votação iniciar"
L["CONFIG_ROLLFRAME_AUTO_ROLL"] = "Auto-rolar ao enviar"
L["CONFIG_ROLLFRAME_AUTO_ROLL_DESC"] = "Executar /roll automaticamente ao enviar uma resposta"
L["CONFIG_ROLLFRAME_GEAR_COMPARE"] = "Mostrar comparação de equipamento"
L["CONFIG_ROLLFRAME_GEAR_COMPARE_DESC"] = "Mostrar itens equipados atualmente para comparação"
L["CONFIG_ROLLFRAME_REQUIRE_NOTE"] = "Exigir nota"
L["CONFIG_ROLLFRAME_REQUIRE_NOTE_DESC"] = "Exigir uma nota antes de enviar uma resposta"
L["CONFIG_ROLLFRAME_PRINT_RESPONSE"] = "Imprimir resposta no chat"
L["CONFIG_ROLLFRAME_PRINT_RESPONSE_DESC"] = "Imprimir sua resposta enviada no chat como referência pessoal"
L["CONFIG_ROLLFRAME_TIMER"] = "Temporizador de resposta"
L["CONFIG_ROLLFRAME_TIMER_ENABLED"] = "Mostrar temporizador de resposta"
L["CONFIG_ROLLFRAME_TIMER_DURATION"] = "Duração do temporizador"

-- Session Settings (ML)
L["SESSION_SETTINGS_ML"] = "Configurações de sessão (MS)"
L["VOTING_TIMEOUT_DURATION"] = "Duração do tempo limite"

-- Errors
L["ERROR_NO_SESSION"] = "Nenhuma sessão ativa"

-- Communication
L["SYNC_COMPLETE"] = "Sincronização completa"

-- Guild Sync
L["HISTORY_SYNCED"] = "%d entradas de histórico sincronizadas de %s"
L["SYNC_IN_PROGRESS"] = "Sincronização já em andamento"
L["SYNC_TIMEOUT"] = "Sincronização expirou"

-- Tooltips
L["TOOLTIP_ITEM_LEVEL"] = "Nível do Item: %d"
L["TOOLTIP_VOTES"] = "Votos: %d"

-- Status
L["STATUS_PENDING"] = "Pendente"
L["STATUS_VOTING"] = "Votação"
L["STATUS_TALLIED"] = "Contabilizado"
L["STATUS_AWARDED"] = "Premiado"
L["STATUS_SKIPPED"] = "Pulado"

-- Response Settings
L["RESET_RESPONSES"] = "Redefinir Padrões"

-- Award Reason Settings
L["REQUIRE_AWARD_REASON"] = "Exigir motivo ao premiar"
L["AWARD_REASONS"] = "Motivos de Prêmio"
L["ADD_REASON"] = "Adicionar Motivo"
L["REASON_NAME"] = "Nome do Motivo"
L["AWARD_REASON"] = "Motivo do Prêmio"

-- Trade Panel
L["TRADE_QUEUE"] = "Fila de Comércio"
L["TRADE_PANEL_HELP"] = "Clique em um nome de jogador para iniciar comércio"
L["NO_PENDING_TRADES"] = "Nenhum item aguardando comércio"
L["NO_ITEMS_TO_TRADE"] = "Nenhum item para comerciar"
L["ONE_ITEM_TO_TRADE"] = "1 item aguardando comércio"
L["N_ITEMS_TO_TRADE"] = "%d itens aguardando comércio"
L["AUTO_TRADE"] = "Auto-comércio"
L["CLEAR_COMPLETED"] = "Limpar Concluídos"

-- Minimap

-- Voting Options
L["SELF_VOTE"] = "Permitir Auto-Voto"
L["SELF_VOTE_DESC"] = "Permitir que membros do conselho votem em si mesmos"
L["MULTI_VOTE"] = "Permitir Multi-Voto"
L["MULTI_VOTE_DESC"] = "Permitir votação em múltiplos candidatos por item"
L["ANONYMOUS_VOTING"] = "Votação Anônima"
L["ANONYMOUS_VOTING_DESC"] = "Ocultar quem votou em quem até o item ser premiado"
L["HIDE_VOTES"] = "Ocultar Contagem de Votos"
L["HIDE_VOTES_DESC"] = "Não mostrar contagem de votos até todos os votos chegarem"
L["OBSERVE_MODE"] = "Modo Observação"
L["AUTO_ADD_ROLLS"] = "Auto-adicionar Rolls"
L["AUTO_ADD_ROLLS_DESC"] = "Adicionar automaticamente resultados de /roll aos candidatos"
L["REQUIRE_NOTES"] = "Exigir Notas"
L["REQUIRE_NOTES_DESC"] = "Eleitores devem adicionar uma nota com seu voto"

-- Button Sets
L["BUTTON_SETS"] = "Conjuntos de Botões"
L["ACTIVE_SET"] = "Conjunto Ativo"
L["NEW_SET"] = "Novo Conjunto"
L["CONFIRM_DELETE_SET"] = "Deletar conjunto de botões '%s'?"
L["ADD_BUTTON"] = "Adicionar Botão"
L["MAX_BUTTONS"] = "Máximo 10 botões por conjunto"
L["MIN_BUTTONS"] = "Mínimo 1 botão requerido"
L["DEFAULT_SET"] = "Padrão"
L["SORT_ORDER"] = "Ordem de Classificação"
L["BUTTON_COLOR"] = "Cor do Botão"

-- Filters
L["FILTERS"] = "Filtros"
L["FILTER_BY_CLASS"] = "Filtrar por Classe"
L["FILTER_BY_RESPONSE"] = "Filtrar por Resposta"
L["FILTER_BY_RANK"] = "Filtrar por Patente de Guilda"
L["SHOW_EQUIPPABLE_ONLY"] = "Mostrar Apenas Equipáveis"
L["HIDE_PASSED_ITEMS"] = "Ocultar Itens Passados"
L["CLEAR_FILTERS"] = "Limpar Filtros"
L["ALL_CLASSES"] = "Todas as Classes"
L["ALL_RESPONSES"] = "Todas as Respostas"
L["ALL_RANKS"] = "Todas as Patentes"
L["FILTERS_ACTIVE"] = "%d filtro(s) ativo(s)"

-- Generic / Missing strings
L["YES"] = "Sim"
L["NO"] = "Não"
L["TIME_EXPIRED"] = "Tempo expirado"
L["END_SESSION"] = "Encerrar Sessão"
L["END_VOTE"] = "Encerrar Votação"
L["START_SESSION"] = "Iniciar Sessão"
L["OPEN_MAIN_WINDOW"] = "Abrir janela principal"
L["RE_VOTE"] = "Re-Votar"
L["ROLL_REQUEST"] = "Solicitação de Roll"
L["ROLL_REQUEST_SENT"] = "Solicitação de roll enviada"
L["SELECT_RESPONSE"] = "Selecionar Resposta"
L["HIDE_MINIMAP_BUTTON"] = "Ocultar botão do minimapa"
L["NO_SESSION"] = "Nenhuma sessão ativa"
L["MINIMAP_TOOLTIP_LEFT"] = "Clique esquerdo: Abrir Loothing"
L["MINIMAP_TOOLTIP_RIGHT"] = "Clique direito: Opções"
L["RESULTS_TITLE"] = "Resultados"
L["VOTE_TITLE"] = "Resposta de Loot"
L["VOTES"] = "Votos"
L["ITEMS_PENDING"] = "%d itens pendentes"
L["ITEMS_VOTING"] = "%d itens votando"
L["LINK_IN_CHAT"] = "Link no Chat"
L["VIEW"] = "Visualizar"

-- Group Loot

-- Frame/UI Settings

-- Master Looter Settings
L["CONFIG_ML_SETTINGS"] = "Configurações do Mestre do Saque"

-- History Settings
L["CONFIG_HISTORY_SETTINGS"] = "Configurações de Histórico"
L["CONFIG_HISTORY_ENABLED"] = "Ativar Histórico de Loot"
L["CONFIG_HISTORY_CLEARALL_CONFIRM"] = "Tem certeza de que quer deletar TODAS as entradas de histórico? Isto não pode ser desfeito!"

-- Enhanced Announcements

-- Enhanced Award Reasons
L["CONFIG_REASON_LOG"] = "Registrar no Histórico"
L["CONFIG_REASON_DISENCHANT"] = "Tratar como Desencantamento"
L["CONFIG_REASON_RESET_CONFIRM"] = "Redefinir todos os motivos de prêmio para padrões?"

-- Council Management
L["CONFIG_COUNCIL_REMOVEALL_CONFIRM"] = "Remover todos os membros do conselho?"

-- Auto-Pass Enhancements
L["CONFIG_AUTOPASS_TRINKETS"] = "Passar Berloques Automaticamente"
L["CONFIG_AUTOPASS_SILENT"] = "Auto-Pass Silencioso"

-- Voting Enhancements
L["CONFIG_VOTING_MLSEESVOTES"] = "Mestre Vê Votos"
L["CONFIG_VOTING_MLSEESVOTES_DESC"] = "Mestre do Saque pode ver votos mesmo quando anônimo"

-- General Enhancements

-- ============================================================================
-- Roll/Vote System Locale Strings
-- ============================================================================

-- RollFrame UI
L["ROLL_YOUR_ROLL"] = "Sua Rolagem:"

-- RollFrame Settings

-- CouncilTable UI
L["COUNCIL_NO_CANDIDATES"] = "Nenhum candidato respondeu ainda"
L["COUNCIL_AWARD"] = "Premiar"
L["COUNCIL_REVOTE"] = "Re-votar"
L["COUNCIL_SKIP"] = "Pular"
L["COUNCIL_CONFIRM_REVOTE"] = "Limpar todos os votos e reiniciar votação?"

-- CouncilTable Settings
L["COUNCIL_COLUMN_PLAYER"] = "Nome do Jogador"
L["COUNCIL_COLUMN_RESPONSE"] = "Resposta"
L["COUNCIL_COLUMN_ROLL"] = "Rolagem"
L["COUNCIL_COLUMN_NOTE"] = "Nota"
L["COUNCIL_COLUMN_ILVL"] = "Nível do Item"
L["COUNCIL_COLUMN_ILVL_DIFF"] = "Upgrade (+/-)"
L["COUNCIL_COLUMN_GEAR1"] = "Slot de Equipamento 1"
L["COUNCIL_COLUMN_GEAR2"] = "Slot de Equipamento 2"

-- Winner Determination Settings
L["WINNER_DETERMINATION"] = "Determinação de Vencedor"
L["WINNER_DETERMINATION_DESC"] = "Configure como vencedores são selecionados quando votação termina."
L["WINNER_MODE"] = "Modo de Vencedor"
L["WINNER_MODE_DESC"] = "Como o vencedor é determinado após votação"
L["WINNER_MODE_HIGHEST_VOTES"] = "Votos Mais Altos do Conselho"
L["WINNER_MODE_ML_CONFIRM"] = "ML Confirma Vencedor"
L["WINNER_MODE_AUTO_CONFIRM"] = "Auto-selecionar Mais Alto + Confirmar"
L["WINNER_TIE_BREAKER"] = "Desempate"
L["WINNER_TIE_BREAKER_DESC"] = "Como empates são resolvidos quando candidatos têm votos iguais"
L["WINNER_TIE_USE_ROLL"] = "Usar Valor da Rolagem"
L["WINNER_TIE_ML_CHOICE"] = "ML Escolhe"
L["WINNER_TIE_REVOTE"] = "Disparar Re-votação"
L["WINNER_AUTO_AWARD_UNANIMOUS"] = "Auto-premiar em Unânime"
L["WINNER_AUTO_AWARD_UNANIMOUS_DESC"] = "Premiar automaticamente quando todos os membros do conselho votam no mesmo candidato"
L["WINNER_REQUIRE_CONFIRMATION"] = "Exigir Confirmação"
L["WINNER_REQUIRE_CONFIRMATION_DESC"] = "Mostrar diálogo de confirmação antes de premiar itens"

-- Communication messages

-- Council Management (Guild/Group based)

-- Announcements - Considerations
L["CONFIG_CONSIDERATIONS"] = "Considerações"
L["CONFIG_CONSIDERATIONS_CHANNEL"] = "Canal"
L["CONFIG_CONSIDERATIONS_TEXT"] = "Modelo de Mensagem"

-- Announcements - Line Configuration
L["CONFIG_LINE"] = "Linha"
L["CONFIG_ENABLED"] = "Ativado"
L["CONFIG_CHANNEL"] = "Canal"

-- Session Announcements

-- Award Reasons
L["CONFIG_NUM_REASONS_DESC"] = "Número de motivos de prêmio ativos (1-20)"
L["CONFIG_AWARD_REASONS_DESC"] = "Configure motivos de prêmio. Cada motivo pode ser alternado para registro e marcado como desencantamento."
L["CONFIG_RESET_REASONS"] = "Redefinir Padrões"

-- Frame Settings (using OptionsTable naming convention)
L["CONFIG_FRAME_MINIMIZE_COMBAT"] = "Minimizar em Combate"
L["CONFIG_FRAME_TIMEOUT_FLASH"] = "Piscar ao Expirar"
L["CONFIG_FRAME_BLOCK_TRADES"] = "Bloquear Comércios Durante Votação"

-- History Settings
L["CONFIG_HISTORY_SEND"] = "Enviar Histórico"
L["CONFIG_HISTORY_CLEAR_ALL"] = "Limpar Tudo"
L["CONFIG_HISTORY_AUTO_EXPORT_WEB"] = "Mostrar exportação web automaticamente"
L["CONFIG_HISTORY_AUTO_EXPORT_WEB_DESC"] = "Ao encerrar uma sessão, abrir automaticamente o diálogo de exportação com a exportação web pronta para copiar"

-- Whisper Commands
L["WHISPER_RESPONSE_RECEIVED"] = "Loothing: Resposta '%s' recebida para %s"
L["WHISPER_NO_SESSION"] = "Loothing: Nenhuma sessão ativa"
L["WHISPER_NO_VOTING_ITEMS"] = "Loothing: Nenhum item em votação no momento"
L["WHISPER_UNKNOWN_COMMAND"] = "Loothing: Comando desconhecido '%s'. Sussurre !help para opções"
L["WHISPER_HELP_HEADER"] = "Loothing: Comandos de sussurro:"
L["WHISPER_HELP_LINE"] = "  %s - %s"
L["WHISPER_ITEM_SPECIFIED"] = "Loothing: Resposta '%s' recebida para %s (#%d)"
L["WHISPER_INVALID_ITEM_NUM"] = "Loothing: Número de item inválido %d (sessão tem %d itens)"

-- ============================================================================
-- Phase 1-6 Additional Locale Strings
-- ============================================================================

-- General / UI
L["ADDON_TAGLINE"] = "Addon de Loot Council"
L["VERSION"] = "Versão"
L["VERSION_CHECK"] = "Verificação de Versão"
L["OUTDATED"] = "Desatualizado"
L["NOT_INSTALLED"] = "Não Instalado"
L["CURRENT"] = "Atual"
L["ENABLED"] = "Ativado"
L["REQUIRED"] = "Obrigatório"
L["NOTE"] = "Nota:"
L["PLAYER"] = "Jogador"
L["SEND"] = "Enviar"
L["SEND_TO"] = "Enviar Para:"
L["WHISPER"] = "Sussurro"

-- Blizzard Settings Integration
L["BLIZZARD_SETTINGS_DESC"] = "Clique abaixo para abrir o painel completo de configurações"
L["OPEN_SETTINGS"] = "Abrir Configurações do Loothing"

-- Slash Commands (Debug)
L["SLASH_DESC_ERRORS"] = "Mostrar erros capturados"
L["SLASH_DESC_LOG"] = "Ver logs recentes"

-- Session Panel
L["ADD_ITEM"] = "Adicionar Item"
L["ADD_ITEM_TITLE"] = "Adicionar Item à Sessão"
L["ENTER_ITEM"] = "Inserir Item"
L["RECENT_DROPS"] = "Drops Recentes"
L["FROM_BAGS"] = "Das Bolsas"
L["ENTER_ITEM_HINT"] = "Cole um link de item, ID de item, ou arraste um item aqui"
L["DRAG_ITEM_HERE"] = "Solte o item aqui"
L["NO_RECENT_DROPS"] = "Nenhum item negociável recente encontrado"
L["NO_BAG_ITEMS"] = "Nenhum item elegível nas bolsas"
L["EQUIPMENT_ONLY"] = "Apenas Equipamentos"
L["SLASH_DESC_ADD"] = "Adicionar item à sessão"
L["AWARD_LATER_ALL"] = "Premiar Depois (Todos)"

-- Session Trigger Modes (legacy)
L["TRIGGER_MANUAL"] = "Manual (use /loothing start)"
L["TRIGGER_AUTO"] = "Automático (iniciar imediatamente)"
L["TRIGGER_PROMPT"] = "Perguntar (confirmar antes de iniciar)"

-- Session Trigger Policy (split model)
L["SESSION_TRIGGER_HEADER"] = "Disparo de Sessão"
L["SESSION_TRIGGER_ACTION"] = "Ação de Disparo"
L["SESSION_TRIGGER_ACTION_DESC"] = "O que acontece quando a morte do chefe é elegível"
L["SESSION_TRIGGER_TIMING"] = "Temporização do Disparo"
L["SESSION_TRIGGER_TIMING_DESC"] = "Quando a ação de disparo ocorre em relação à morte do chefe"
L["TRIGGER_TIMING_ENCOUNTER_END"] = "Na Morte do Chefe"
L["TRIGGER_TIMING_AFTER_LOOT"] = "Após o saque do encontro"
L["TRIGGER_SCOPE_RAID"] = "Chefes de Raide"
L["TRIGGER_SCOPE_RAID_DESC"] = "Disparar em mortes de chefes de raide"
L["TRIGGER_SCOPE_DUNGEON"] = "Chefes de Masmorra"
L["TRIGGER_SCOPE_DUNGEON_DESC"] = "Disparar em mortes de chefes de masmorra"
L["TRIGGER_SCOPE_OPEN_WORLD"] = "Mundo Aberto"
L["TRIGGER_SCOPE_OPEN_WORLD_DESC"] = "Disparar em encontros de mundo aberto (ex: chefes mundiais)"

-- AutoPass Options
L["CONFIG_AUTOPASS_BOE"] = "AutoPass Itens BoE"
L["CONFIG_AUTOPASS_BOE_DESC"] = "Passar automaticamente em itens Vinculado ao Equipar"
L["CONFIG_AUTOPASS_TRANSMOG"] = "AutoPass Transmog"
L["CONFIG_AUTOPASS_TRANSMOG_SOURCE"] = "Pular Aparências Conhecidas"

-- Auto Award Options
L["CONFIG_AUTO_AWARD_LOWER_THRESHOLD"] = "Limite de Qualidade Inferior"
L["CONFIG_AUTO_AWARD_UPPER_THRESHOLD"] = "Limite de Qualidade Superior"
L["CONFIG_AUTO_AWARD_REASON"] = "Motivo do Prêmio"
L["CONFIG_AUTO_AWARD_INCLUDE_BOE"] = "Incluir Itens BoE"

-- Frame Behavior Options
L["CONFIG_FRAME_BEHAVIOR"] = "Comportamento de Frame"
L["CONFIG_FRAME_AUTO_OPEN"] = "Abrir Frames Automaticamente"
L["CONFIG_FRAME_AUTO_CLOSE"] = "Fechar Frames Automaticamente"
L["CONFIG_FRAME_SHOW_SPEC_ICON"] = "Mostrar Ícones de Especialização"
L["CONFIG_FRAME_CLOSE_ESCAPE"] = "Fechar com Escape"
L["CONFIG_FRAME_CHAT_OUTPUT"] = "Frame de Chat de Saída"

-- ML Usage Options
L["CONFIG_ML_USAGE_MODE"] = "Modo de Uso"
L["CONFIG_ML_USAGE_NEVER"] = "Nunca"
L["CONFIG_ML_USAGE_GL"] = "Group Loot"
L["CONFIG_ML_USAGE_ASK_GL"] = "Perguntar em Group Loot"
L["CONFIG_ML_RAIDS_ONLY"] = "Apenas Raides"
L["CONFIG_ML_ALLOW_OUTSIDE"] = "Permitir Fora de Raides"
L["CONFIG_ML_SKIP_SESSION"] = "Pular Frame de Sessão"
L["CONFIG_ML_SORT_ITEMS"] = "Ordenar Itens"
L["CONFIG_ML_AUTO_ADD_BOES"] = "Auto-Adicionar BoEs"
L["CONFIG_ML_PRINT_TRADES"] = "Imprimir Comércios Completos"
L["CONFIG_ML_REJECT_TRADE"] = "Rejeitar Comércios Inválidos"
L["CONFIG_ML_AWARD_LATER"] = "Premiar Depois"

-- History Options
L["CONFIG_HISTORY_SEND_GUILD"] = "Enviar para Guilda"
L["CONFIG_HISTORY_SAVE_PL"] = "Salvar Loot Pessoal"

-- Ignore Item Options
L["CONFIG_IGNORE_ENCHANTING_MATS"] = "Ignorar Materiais de Encantamento"
L["CONFIG_IGNORE_CRAFTING_REAGENTS"] = "Ignorar Reagentes de Criação"
L["CONFIG_IGNORE_CONSUMABLES"] = "Ignorar Consumíveis"
L["CONFIG_IGNORE_PERMANENT_ENHANCEMENTS"] = "Ignorar Melhorias Permanentes"

-- Announcement Options
L["CONFIG_ANNOUNCEMENT_TOKENS_DESC"] = "Tokens disponíveis: {item}, {winner}, {reason}, {notes}, {ilvl}, {type}, {oldItem}, {ml}, {session}, {votes}"
L["CONFIG_ANNOUNCE_CONSIDERATIONS"] = "Anunciar Considerações"
L["CONFIG_ITEM_ANNOUNCEMENTS"] = "Anúncios de Item"
L["CONFIG_SESSION_ANNOUNCEMENTS"] = "Anúncios de Sessão"
L["CONFIG_SESSION_START"] = "Início de Sessão"
L["CONFIG_SESSION_END"] = "Fim de Sessão"
L["CONFIG_MESSAGE"] = "Mensagem"

-- Button Sets & Type Code Options
L["CONFIG_BUTTON_SETS"] = "Conjuntos de Botões"
L["CONFIG_TYPECODE_ASSIGNMENT"] = "Atribuição de Código de Tipo"

-- Award Reasons Options
L["CONFIG_AWARD_REASONS"] = "Motivos de Prêmio"
L["NUM_AWARD_REASONS"] = "Número de Motivos"

-- Council Guild Rank Options
L["CONFIG_GUILD_RANK"] = "Auto-Inclusão por Patente de Guilda"
L["CONFIG_GUILD_RANK_DESC"] = "Incluir automaticamente membros da guilda com patente igual ou superior no conselho"
L["CONFIG_MIN_RANK"] = "Patente Mínima de Guilda"
L["CONFIG_MIN_RANK_DESC"] = "Membros da guilda com esta patente ou superior serão auto-incluídos como membros do conselho. 0 = desativado, 1 = Mestre de Guilda, 2 = Oficiais, etc."
L["CONFIG_COUNCIL_REMOVE_ALL"] = "Remover Todos os Membros"

-- Council Table UI
L["CHANGE_RESPONSE"] = "Mudar Resposta"

-- Sync Panel UI
L["SYNC_DATA"] = "Sincronizar Dados"
L["SELECT_TARGET"] = "Selecionar Alvo"
L["SELECT_TARGET_FIRST"] = "Selecione um jogador alvo"
L["NO_TARGETS"] = "Nenhum membro online encontrado"
L["GUILD"] = "Guilda (Todos Online)"
L["QUERY_GROUP"] = "Consultar Grupo"
L["LAST_7_DAYS"] = "Últimos 7 Dias"
L["LAST_30_DAYS"] = "Últimos 30 Dias"
L["ALL_TIME"] = "Todo o Período"
L["SYNCING_TO"] = "Sincronizando %s para %s..."

-- History Panel UI
L["DATE_RANGE"] = "Período:"
L["FILTER_BY_WINNER"] = "Filtrar por %s"
L["DELETE_ENTRY"] = "Deletar Entrada"

-- Observer System
L["OBSERVER"] = "Observador"

-- ML Observer
L["CONFIG_ML_OBSERVER"] = "Modo Observador do ML"
L["CONFIG_ML_OBSERVER_DESC"] = "Mestre do Saque pode ver tudo e gerenciar sessões mas não pode votar"

-- Open Observation (replaces OBSERVE_MODE)
L["OPEN_OBSERVATION"] = "Observação Aberta"
L["OPEN_OBSERVATION_DESC"] = "Permitir que todos os membros da raide observem a votação (adiciona todos como observador)"

-- Observer Permissions
L["OBSERVER_PERMISSIONS"] = "Permissões de Observador"
L["OBSERVER_SEE_VOTE_COUNTS"] = "Ver Contagem de Votos"
L["OBSERVER_SEE_VOTE_COUNTS_DESC"] = "Observadores podem ver quantos votos cada candidato tem"
L["OBSERVER_SEE_VOTER_IDS"] = "Ver Identidade dos Votantes"
L["OBSERVER_SEE_VOTER_IDS_DESC"] = "Observadores podem ver quem votou em cada candidato"
L["OBSERVER_SEE_RESPONSES"] = "Ver Respostas"
L["OBSERVER_SEE_RESPONSES_DESC"] = "Observadores podem ver qual resposta cada candidato selecionou"
L["OBSERVER_SEE_NOTES"] = "Ver Notas"
L["OBSERVER_SEE_NOTES_DESC"] = "Observadores podem ver notas dos candidatos"

-- Bulk Actions
L["BULK_START_VOTE"] = "Iniciar Votação (%d)"
L["BULK_END_VOTE"] = "Encerrar Votação (%d)"
L["BULK_SKIP"] = "Pular (%d)"
L["BULK_REMOVE"] = "Remover (%d)"
L["BULK_REVOTE"] = "Re-Votar (%d)"
L["BULK_AWARD_LATER"] = "Premiar Depois"
L["DESELECT_ALL"] = "Desmarcar"
L["N_SELECTED"] = "%d selecionados"
L["REMOVE_ITEMS"] = "Remover Itens"
L["CONFIRM_BULK_SKIP"] = "Pular %d itens selecionados?"
L["CONFIRM_BULK_REMOVE"] = "Remover %d itens selecionados da sessão?"
L["CONFIRM_BULK_REVOTE"] = "Re-votar em %d itens selecionados?"

-- ============================================================================
-- RCV (Ranked Choice Voting) Audit Strings
-- ============================================================================

-- RCV Settings
L["RCV_SETTINGS"] = "Configurações de Escolha Classificada"
L["MAX_RANKS"] = "Máximo de Classificações"
L["MIN_RANKS"] = "Mínimo de Classificações"
L["MAX_RANKS_DESC"] = "Número máximo de escolhas que um votante pode classificar (0 = ilimitado)"
L["MIN_RANKS_DESC"] = "Número mínimo de escolhas obrigatórias para enviar um voto"
L["RANK_LIMIT_REACHED"] = "Máximo de %d classificações atingido"
L["RANK_MINIMUM_REQUIRED"] = "Classifique pelo menos %d escolhas"
L["MAX_REVOTES"] = "Máximo de Re-votações"

-- ML Sees Votes

-- IRV Round Visualization
L["SHOW_IRV_ROUNDS"] = "Mostrar Rodadas IRV (%d rodadas)"
L["HIDE_IRV_ROUNDS"] = "Ocultar Rodadas IRV"

-- Settings Export/Import
L["PROFILES"] = "Perfis"
L["EXPORT_SETTINGS"] = "Exportar Configurações"
L["IMPORT_SETTINGS"] = "Importar Configurações"
L["EXPORT_TITLE"] = "Exportar Configurações"
L["EXPORT_DESC"] = "Pressione Ctrl+A para selecionar tudo, depois Ctrl+C para copiar."
L["EXPORT_FAILED"] = "Falha na exportação: %s"
L["IMPORT_TITLE"] = "Importar Configurações"
L["IMPORT_DESC"] = "Cole o texto de configurações exportado abaixo, depois clique em Importar."
L["IMPORT_BUTTON"] = "Importar"
L["IMPORT_FAILED"] = "Falha na importação: %s"
L["IMPORT_VERSION_WARN"] = "Nota: exportado com Loothing v%s (você tem v%s)."
L["IMPORT_SUCCESS_NEW"] = "Configurações importadas como novo perfil: %s"
L["IMPORT_SUCCESS_CURRENT"] = "Configurações importadas no perfil atual."
L["SLASH_DESC_EXPORT"] = "Exportar configurações do perfil atual"
L["SLASH_DESC_PROFILE"] = "Gerenciar perfis (listar, alternar, criar)"

-- Profile Management
L["PROFILE_CURRENT"] = "Perfil Atual"
L["PROFILE_SWITCH"] = "Trocar Perfil"
L["PROFILE_SWITCH_DESC"] = "Selecione um perfil para trocar."
L["PROFILE_NEW"] = "Criar Novo Perfil"
L["PROFILE_NEW_DESC"] = "Insira um nome para o novo perfil."
L["PROFILE_COPY_FROM"] = "Copiar De"
L["PROFILE_COPY_DESC"] = "Copiar configurações de outro perfil para o atual."
L["PROFILE_COPY_CONFIRM"] = "Isto substituirá todas as configurações do perfil atual. Continuar?"
L["PROFILE_DELETE"] = "Deletar Perfil"
L["PROFILE_DELETE_CONFIRM"] = "Tem certeza de que quer deletar este perfil? Isto não pode ser desfeito."
L["PROFILE_RESET"] = "Redefinir Padrões"
L["PROFILE_RESET_CONFIRM"] = "Redefinir perfil '%s' para configurações padrão? Isto não pode ser desfeito."
L["PROFILE_LIST"] = "Todos os Perfis"
L["PROFILE_DEFAULT_SUFFIX"] = "(padrão)"
L["PROFILE_EXPORT_INLINE_DESC"] = "Gere um texto de exportação, depois copie para compartilhar suas configurações."
L["PROFILE_IMPORT_INLINE_DESC"] = "Cole o texto de configurações exportado abaixo, depois clique em Importar."
L["PROFILE_LIST_HEADER"] = "Perfis:"
L["PROFILE_SWITCHED"] = "Perfil trocado para: %s"
L["PROFILE_CREATED"] = "Criado e trocado para perfil: %s"

-- ============================================================================
-- Missing Translations (207 keys)
-- ============================================================================

-- General UI Labels
L["ACCEPT"] = "Aceitar"
L["COPY"] = "Copiar"
L["COPY_SUFFIX"] = "(Cópia)"
L["DECLINE"] = "Recusar"
L["DELETE"] = "Deletar"
L["EDIT"] = "Editar"
L["KEEP"] = "Manter"
L["LESS"] = "Menos"
L["NEW"] = "Novo"
L["OK"] = "OK"
L["OVERWRITE"] = "Sobrescrever"
L["RECOMMENDED"] = "Recomendado"
L["REMOVE"] = "Remover"
L["RENAME"] = "Renomear"
L["RESET"] = "Redefinir"
L["UNKNOWN"] = "Desconhecido"

-- Session & Loot
L["LOOT_COUNCIL"] = "Conselho de Saque"
L["LOOT_RESPONSE_TITLE"] = "Resposta de Saque"
L["SESSION_ENDED_DEFAULT"] = "Sessão do conselho de saque encerrada"
L["SESSION_STARTED_DEFAULT"] = "Sessão do conselho de saque iniciada"
L["EQUIPPED_GEAR"] = "Equipamento Atual"
L["VIEW_GEAR"] = "Ver Equipamento"

-- Notes & Placeholders
L["ADD_NOTE_PLACEHOLDER"] = "Adicionar uma nota..."
L["NOTE_OPTIONAL"] = "Nota (opcional):"

-- Announcements
L["ANN_CONSIDERATIONS_DEFAULT"] = "{ml} está considerando {item} para distribuição"

-- Config: General
L["APPLY_TO_CURRENT"] = "Aplicar ao Atual"
L["CONFIG_MANAGE"] = "Gerenciar"
L["CONFIG_LOCAL_PREFS_DESC"] = "Estas configurações afetam apenas você. Não são transmitidas para a raide."
L["CONFIG_LOCAL_PREFS_NOTE"] = " Estas configurações afetam apenas seu cliente. Nunca são enviadas para outros membros da raide."
L["CONFIG_SESSION_BROADCAST_DESC"] = "Estas configurações são transmitidas para todos os membros da raide quando você é o Mestre do Saque. Elas controlam a sessão para todos."
L["CONFIG_SESSION_BROADCAST_NOTE"] = "Estas configurações são transmitidas para todos os membros da raide quando você inicia uma sessão como Mestre do Saque."
L["CONFIG_TRIGGER_SCOPE_NOTE"] = "Encontros PvP, arena e cenário nunca disparam sessões. Apenas raides é o padrão."

-- Config: Award Reasons
L["CONFIG_AWARD_REASONS_ENABLED_DESC"] = "Ativar ou desativar o sistema de motivos de prêmio"
L["CONFIG_CONFIRM_REMOVE_REASON"] = "Remover este motivo de prêmio?"
L["CONFIG_CONFIRM_RESET_REASONS"] = "Redefinir todos os motivos de prêmio para os valores padrão? Isto não pode ser desfeito."
L["CONFIG_NEW_REASON_DEFAULT"] = "Novo Motivo"
L["CONFIG_REASON_DEFAULT"] = "Motivo"
L["CONFIG_REASONS"] = "Motivos"
L["CONFIG_REQUIRE_AWARD_REASON_DESC"] = "Exigir que um motivo de prêmio seja selecionado antes de premiar um item"

-- Config: Button Sets
L["CONFIG_BUTTON_SETS_DESC"] = "Configure conjuntos de botões de resposta, ícones, teclas de sussurro e atribuições de código de tipo usando o editor visual."
L["CONFIG_OPEN_BUTTON_EDITOR"] = "Abrir Editor de Botões de Resposta"

-- Config: Council
L["CONFIG_COUNCIL_ADD_HELP"] = "Membros do conselho podem votar na distribuição de saque. Use o campo abaixo para adicionar membros por nome."
L["CONFIG_COUNCIL_ADD_NAME_DESC"] = "Insira o nome do personagem (ex: 'NomeDoJogador' ou 'NomeDoJogador-Reino')"
L["CONFIG_COUNCIL_ALL_REMOVED"] = "Todos os membros do conselho removidos"
L["CONFIG_COUNCIL_CONFIRM_REMOVE"] = "Remover %s do conselho?"
L["CONFIG_COUNCIL_CONFIRM_REMOVE_ALL"] = "Remover TODOS os membros do conselho?"
L["CONFIG_COUNCIL_MEMBER_REMOVED"] = "%s removido do conselho"
L["CONFIG_COUNCIL_NO_MEMBERS"] = "Nenhum membro do conselho adicionado."
L["CONFIG_COUNCIL_REMOVE_DESC"] = "Selecione um membro para remover do conselho"

-- Config: History
L["CONFIG_HISTORY_ALL_CLEARED"] = "Todo o histórico limpo"

-- Config: Voting
L["CONFIG_MAX_REVOTES_DESC"] = "Número máximo de re-votações permitidas por item (0 = sem re-votações)"
L["CONFIG_OBSERVER_PERMISSIONS_DESC"] = "Controlar o que observadores podem ver durante sessões de votação."
L["CONFIG_VOTING_TIMEOUT_DESC"] = "Quando desativado, a votação continua até o ML encerrá-la manualmente."

-- Config: RollFrame
L["CONFIG_ROLLFRAME_TIMER_ENABLED_DESC"] = "Mostrar um temporizador de contagem regressiva no quadro de resposta. Quando desativado, o quadro permanece aberto até você responder ou o ML encerrar a votação."

-- Columns
L["COLUMN_INST"] = "Inst"
L["COLUMN_ROLE"] = "Papel"
L["COLUMN_TOOLTIP_WON_INSTANCE"] = "Itens ganhos nesta instância + dificuldade"
L["COLUMN_TOOLTIP_WON_SESSION"] = "Itens ganhos nesta sessão"
L["COLUMN_TOOLTIP_WON_WEEKLY"] = "Itens ganhos esta semana"
L["COLUMN_VOTE"] = "Voto"
L["COLUMN_WK"] = "Sem"
L["COLUMN_WON"] = "Ganho"

-- Council Voting
L["COUNCIL_VOTING_PROGRESS"] = "Progresso da Votação do Conselho"
L["NO_COUNCIL_VOTES"] = "Nenhum voto do conselho registrado"

-- Profiles
L["CREATE_NEW_PROFILE"] = "Criar Novo Perfil"
L["CURRENT_COLON"] = "Atual: "
L["IMPORT_SUMMARY"] = "Perfil: %s | Exportado: %s | Versão: %s"
L["PROFILE_ERR_EMPTY"] = "O nome não pode estar vazio"
L["PROFILE_ERR_INVALID_CHARS"] = "O nome contém caracteres inválidos"
L["PROFILE_ERR_NOT_STRING"] = "O nome deve ser uma string"
L["PROFILE_ERR_TOO_LONG"] = "O nome deve ter 48 caracteres ou menos"
L["PROFILE_SHARE_BUTTON"] = "Compartilhar"
L["PROFILE_SHARE_DESC"] = "Enviar o texto de exportação atual diretamente para um membro online do grupo."
L["PROFILE_SHARE_FAILED"] = "Configurações compartilhadas de %s não puderam ser importadas: %s"
L["PROFILE_SHARE_FAILED_GENERIC"] = "Compartilhamento falhou: %s"
L["PROFILE_SHARE_RECEIVED"] = "Configurações compartilhadas recebidas de %s."
L["PROFILE_SHARE_SENT"] = "Perfil atual compartilhado com %s."
L["PROFILE_SHARE_TARGET"] = "Compartilhar Com"
L["PROFILE_SHARE_TARGET_REQUIRED"] = "Selecione um alvo primeiro."
L["PROFILE_SHARE_UNAVAILABLE"] = "Compartilhamento de perfil indisponível."

-- Auto-Award
L["AUTO_AWARD_TARGET_NOT_IN_RAID"] = "Alvo de auto-prêmio %s não está na raide"

-- Award Actions
L["AWARD_FOR"] = "Premiar Por..."
L["AWARD_LATER_ALL_DESC"] = "Definir todos os itens para serem premiados após a sessão"
L["AWARD_LATER_ITEM_DESC"] = "Marcar este item para ser premiado após a sessão"
L["AWARD_LATER_SHORT"] = "Depois"

-- Buttons & Response Editor
L["CANNOT_DELETE_LAST_SET"] = "Não é possível deletar o último conjunto de respostas."
L["DISPLAY_TEXT_LABEL"] = "Texto de Exibição:"
L["ICON_LABEL"] = "Ícone:"
L["ICON_SET"] = "Ícone: ✓"
L["NEW_BUTTON"] = "Novo Botão"
L["PICK_ICON"] = "Escolher Ícone…"
L["RESPONSE_AUTO_PASS"] = "Auto Pass"
L["RESPONSE_BUTTON_EDITOR"] = "Editor de Botões de Resposta"
L["RESPONSE_TEXT_LABEL"] = "Texto da Resposta:"
L["RESPONSE_WAITING"] = "Aguardando..."
L["SET_LABEL"] = "Conjunto:"
L["WHISPER_KEYS_LABEL"] = "Teclas de Sussurro:"

-- Disenchant
L["CLICK_SELECT_ENCHANTER"] = "Clique para selecionar um encantador"
L["DISENCHANT_TARGET"] = "Alvo de Desencantamento"
L["SELECT_ENCHANTER"] = "Selecionar Encantador"

-- Item Categories
L["ITEM_CATEGORY_CONSUMABLE"] = "Consumível"
L["ITEM_CATEGORY_CRAFTING"] = "Reagente de Criação"
L["ITEM_CATEGORY_ENCHANTING"] = "Material de Encantamento"
L["ITEM_CATEGORY_GEM"] = "Gema"
L["ITEM_CATEGORY_TRADE_GOODS"] = "Mercadorias"

-- Item Level
L["ILVL_PREFIX"] = "iLvl "

-- Quality Names
L["QUALITY_ARTIFACT"] = "Artefato"
L["QUALITY_COMMON"] = "Comum"
L["QUALITY_EPIC"] = "Épico"
L["QUALITY_HEIRLOOM"] = "Herança"
L["QUALITY_LEGENDARY"] = "Lendário"
L["QUALITY_POOR"] = "Pobre"
L["QUALITY_RARE"] = "Raro"
L["QUALITY_UNCOMMON"] = "Incomum"
L["QUALITY_UNKNOWN"] = "Desconhecido"

-- Group Status
L["NOT_IN_GROUP"] = "Você não está em uma raide ou grupo"
L["NOT_IN_GUILD"] = "Você não está em uma guilda"

-- Queued Items
L["QUEUED_ITEMS_HINT"] = "Itens na fila aparecerão aqui"
L["REMOVE_FROM_QUEUE"] = "Remover da fila"
L["REMOVE_FROM_SESSION"] = "Remover da sessão"

-- Popup Dialogs
L["POPUP_AWARD_LATER"] = "Premiar {item} para você mesmo para distribuir depois?"
L["POPUP_CLEAR_COUNCIL"] = "Remover todos os membros do conselho?"
L["POPUP_CLEAR_COUNCIL_COUNT"] = "Remover todos os %d membros do conselho?"
L["POPUP_CLEAR_IGNORED"] = "Limpar todos os itens ignorados?"
L["POPUP_CLEAR_IGNORED_COUNT"] = "Limpar todos os %d itens ignorados?"
L["POPUP_CONFIRM_END_SESSION"] = "Tem certeza de que quer encerrar a sessão de saque atual? Todos os itens pendentes serão fechados."
L["POPUP_CONFIRM_REVOTE"] = "Limpar todos os votos e reiniciar votação para {item}?"
L["POPUP_CONFIRM_REVOTE_FMT"] = "Limpar todos os votos e reiniciar votação para %s?"
L["POPUP_CONFIRM_USAGE"] = "Deseja usar Loothing para distribuição de saque nesta raide?"
L["POPUP_DELETE_HISTORY_ALL"] = "Deletar TODAS as entradas de histórico? Isto não pode ser desfeito."
L["POPUP_DELETE_HISTORY_MULTI"] = "Deletar %d entradas de histórico? Isto não pode ser desfeito."
L["POPUP_DELETE_HISTORY_SELECTED"] = "Deletar entradas de histórico selecionadas? Isto não pode ser desfeito."
L["POPUP_DELETE_HISTORY_SINGLE"] = "Deletar 1 entrada de histórico? Isto não pode ser desfeito."
L["POPUP_DELETE_RESPONSE_BUTTON"] = "Deletar este botão de resposta?"
L["POPUP_DELETE_RESPONSE_SET"] = "Deletar este conjunto de respostas? Isto não pode ser desfeito."
L["POPUP_IMPORT_OVERWRITE"] = "Esta importação sobrescreverá {count} entradas de histórico existentes. Continuar?"
L["POPUP_IMPORT_OVERWRITE_MULTI"] = "Esta importação sobrescreverá %d entradas de histórico existentes. Continuar?"
L["POPUP_IMPORT_OVERWRITE_SINGLE"] = "Esta importação sobrescreverá 1 entrada de histórico existente. Continuar?"
L["POPUP_IMPORT_SETTINGS"] = "Escolha como aplicar as configurações importadas:"
L["POPUP_IMPORT_SETTINGS_TITLE"] = "Importar Configurações"
L["POPUP_KEEP_OR_TRADE"] = "O que você gostaria de fazer com {item}?"
L["POPUP_KEEP_OR_TRADE_FMT"] = "O que você gostaria de fazer com %s?"
L["POPUP_OVERWRITE_PROFILE"] = "Isto sobrescreverá as configurações do perfil atual. Continuar?"
L["POPUP_OVERWRITE_PROFILE_TITLE"] = "Sobrescrever Perfil"
L["POPUP_REANNOUNCE"] = "Reanunciar todos os itens para o grupo?"
L["POPUP_REANNOUNCE_TITLE"] = "Reanunciar Itens"
L["POPUP_RENAME_SET"] = "Insira o novo nome para o conjunto:"
L["POPUP_RESET_ALL_SETS"] = "Redefinir TODOS os conjuntos de respostas para padrão? Isto não pode ser desfeito."
L["POPUP_SKIP_ITEM"] = "Pular {item} sem premiá-lo?"
L["POPUP_SKIP_ITEM_FMT"] = "Pular %s sem premiá-lo?"
L["POPUP_START_SESSION"] = "Iniciar sessão de saque para {boss}?"
L["POPUP_START_SESSION_FMT"] = "Iniciar sessão de saque para %s?"
L["POPUP_START_SESSION_GENERIC"] = "Iniciar sessão de saque?"
L["POPUP_SYNC_GENERIC_FMT"] = "%s quer sincronizar %s com você. Aceitar?"
L["POPUP_SYNC_HISTORY_FMT"] = "%s quer sincronizar o histórico de saque (%d dias) com você. Aceitar?"
L["POPUP_SYNC_REQUEST"] = "{player} quer sincronizar {type} com você. Aceitar?"
L["POPUP_SYNC_REQUEST_TITLE"] = "Solicitação de Sincronização"
L["POPUP_SYNC_SETTINGS_FMT"] = "%s quer sincronizar as configurações do Loothing com você. Aceitar?"
L["POPUP_TRADE_ADD_ITEMS"] = "Adicionar {count} itens premiados ao comércio com {player}?"
L["POPUP_TRADE_ADD_MULTI"] = "Adicionar %d itens premiados ao comércio com %s?"
L["POPUP_TRADE_ADD_SINGLE"] = "Adicionar 1 item premiado ao comércio com %s?"

-- Roster
L["ROSTER_COUNCIL_MEMBER"] = "Membro do Conselho"
L["ROSTER_DEAD"] = "Morto"
L["ROSTER_MASTER_LOOTER"] = "Mestre do Saque"
L["ROSTER_NO_ROLE"] = "Sem Papel"
L["ROSTER_NOT_INSTALLED"] = "Não Instalado"
L["ROSTER_OFFLINE"] = "Offline"
L["ROSTER_RANK_MEMBER"] = "Membro"
L["ROSTER_TOOLTIP_GROUP"] = "Grupo: "
L["ROSTER_TOOLTIP_LOOT_HISTORY"] = "Histórico de Saque: %d itens"
L["ROSTER_TOOLTIP_ROLE"] = "Papel: "
L["ROSTER_TOOLTIP_TEST_VERSION"] = "Versão de Teste: "
L["ROSTER_TOOLTIP_VERSION"] = "Loothing: "
L["ROSTER_UNKNOWN"] = "Desconhecido"

-- Sync Messages
L["SYNC_ACCEPTED_FROM"] = "Sincronização aceita de %s"
L["SYNC_HISTORY_COMPLETED"] = "Sincronização de histórico concluída para %d destinatários"
L["SYNC_HISTORY_GUILD_DAYS"] = "Solicitando sincronização de histórico (%d dias) para a guilda..."
L["SYNC_HISTORY_SENT"] = "Enviadas %d entradas de histórico para %s"
L["SYNC_HISTORY_TO_PLAYER"] = "Solicitando sincronização de histórico (%d dias) para %s"
L["SYNC_SETTINGS_APPLIED"] = "Configurações de %s aplicadas"
L["SYNC_SETTINGS_COMPLETED"] = "Sincronização de configurações concluída para %d destinatários"
L["SYNC_SETTINGS_SENT"] = "Configurações enviadas para %s"
L["SYNC_SETTINGS_TO_GUILD"] = "Solicitando sincronização de configurações para a guilda..."
L["SYNC_SETTINGS_TO_PLAYER"] = "Solicitando sincronização de configurações para %s"

-- Trade
L["TRADE_BTN"] = "Comerciar"
L["TRADE_COMPLETED"] = "%s comercializado para %s"
L["TRADE_ITEM_LOCKED"] = "Item bloqueado: %s"
L["TRADE_ITEM_NOT_FOUND"] = "Não foi possível encontrar o item para comerciar: %s"
L["TRADE_ITEMS_PENDING"] = "Você tem %d item(ns) para comerciar com %s. Clique nos itens para adicioná-los à janela de comércio."
L["TRADE_TOO_MANY_ITEMS"] = "Muitos itens para comerciar - apenas os 6 primeiros serão adicionados."
L["TRADE_WINDOW_URGENT"] = "|cffff0000URGENTE:|r Janela de comércio para %s (premiado a %s) expira em %d minutos!"
L["TRADE_WINDOW_WARNING"] = "|cffff9900Aviso:|r Janela de comércio para %s (premiado a %s) expira em %d minutos!"
L["TRADE_WRONG_RECIPIENT"] = "Aviso: %s comercializado para %s (foi premiado a %s)"
L["TOO_MANY_ITEMS_WARNING"] = "Muitos itens (%d). Mostrando botões apenas para os primeiros %d itens. Use a navegação para acessar todos."

-- Version Check
L["VERSION_AND_MORE"] = " e mais %d"
L["VERSION_CHECK_IN_PROGRESS"] = "Verificação de versão já em andamento"
L["VERSION_OUTDATED_MEMBERS"] = "|cffff9900%d membro(s) do grupo com Loothing desatualizado:|r %s"
L["VERSION_RESULTS_CURRENT"] = "  Atualizado: %d"
L["VERSION_RESULTS_HINT"] = "Use /lt version show para ver resultados detalhados"
L["VERSION_RESULTS_NOT_INSTALLED"] = "  |cff888888Não Instalado: %d|r"
L["VERSION_RESULTS_OUTDATED"] = "  |cffff0000Desatualizado: %d|r"
L["VERSION_RESULTS_TEST"] = "  |cff00ff00Versões de teste: %d|r"
L["VERSION_RESULTS_TOTAL"] = "Resultados da Verificação de Versão: %d total"

-- Voting
L["VOTE_RANK"] = "Classificação"
L["VOTE_RANKED"] = "Classificado"
L["VOTES_LABEL"] = "votos"
L["VOTE_VOTED"] = "Votou"

-- Profile Broadcast
L["PROFILE_SHARE_BROADCAST_BUTTON"] = "Transmitir para o Grupo"
L["PROFILE_SHARE_BROADCAST_DESC"] = "Transmitir o texto de exportação atual para a raide ou grupo ativo. Apenas o Mestre do Saque da sessão ativa pode fazer isso."
L["PROFILE_SHARE_BROADCAST_SENT"] = "Perfil atual transmitido para o grupo ativo."
L["PROFILE_SHARE_BROADCAST_CONFIRM"] = "Transmitir seu perfil de configurações atual para todo o grupo ativo?"
L["PROFILE_SHARE_BROADCAST_NO_SESSION"] = "Você precisa de uma sessão Loothing ativa para transmitir configurações."
L["PROFILE_SHARE_BROADCAST_NOT_ML"] = "Apenas o Mestre do Saque da sessão ativa pode transmitir configurações."
L["PROFILE_SHARE_BROADCAST_BUSY"] = "A fila de comunicação do addon está ocupada. Tente novamente em instantes."
L["PROFILE_SHARE_BROADCAST_COOLDOWN"] = "As configurações foram transmitidas recentemente. Tente novamente em %d segundos."
L["PROFILE_SHARE_QUEUE_FULL"] = "Configurações compartilhadas de %s foram descartadas porque outra importação já está aguardando."


-- Restored keys (accessed via Loothing.Locale)
L["SESSION_STARTED"] = "Sessão de loot council iniciada para %s"
L["SESSION_ENDED"] = "Sessão de loot council encerrada"
L["AWARD_TO"] = "Prêmio para %s"
L["TOTAL_VOTES"] = "Total: %d votos"
L["LOOTED_BY"] = "Saqueado por: %s"
L["ENTRIES_COUNT"] = "Total: %d entradas"
L["ENTRIES_FILTERED"] = "Mostrando: %d de %d entradas"
L["AWARDED_TO"] = "Premiado para: %s"
L["FROM_ENCOUNTER"] = "De: %s"
L["WITH_VOTES"] = "Votos: %d"
L["TAB_SETTINGS"] = "Configurações"
L["SELECT_AWARD_REASON"] = "Selecionar Motivo do Prêmio"
L["NO_SELECTION"] = "Nenhuma seleção"
L["YOUR_RANKING"] = "Sua Classificação"
L["AWARD_NO_REASON"] = "Premiar (Sem Motivo)"
L["CLEARED_TRADES"] = "%d troca(s) concluída(s) removida(s)"
L["NO_COMPLETED_TRADES"] = "Nenhuma troca concluída para remover"
L["OBSERVE_MODE_MSG"] = "Você está no modo observador e não pode votar."
L["VOTE_NOTE_REQUIRED"] = "Você deve adicionar uma nota ao seu voto."
L["SELF_VOTE_DISABLED"] = "Autovotar está desativado para esta sessão."



-- Voting States
L["VOTING_STATE_PENDING"] = "Pendente"
L["VOTING_STATE_VOTING"] = "Votação"
L["VOTING_STATE_TALLYING"] = "Contabilizando"
L["VOTING_STATE_DECIDED"] = "Decidido"
L["VOTING_STATE_REVOTING"] = "Re-votação"

-- Enchanter/Disenchant
L["NO_ENCHANTERS"] = "Nenhum encantador detectado no grupo"
L["DISENCHANT_TARGET_SET"] = "Alvo de desencantar definido para: %s"
L["DISENCHANT_TARGET_CLEARED"] = "Alvo de desencantar removido"
