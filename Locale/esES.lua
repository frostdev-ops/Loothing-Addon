--[[--------------------------------------------------------------------
    Loothing - Loot Council Addon for WoW 12.0+
    Locale - Spanish (Spain/Mexico) localization
----------------------------------------------------------------------]]

local ADDON_NAME, ns = ...
local Loolib = LibStub("Loolib")
local LoolibLocale = Loolib.Locale or Loolib:GetModule("Locale")
local L = LoolibLocale:NewLocale(ADDON_NAME, "esES")
       or LoolibLocale:NewLocale(ADDON_NAME, "esMX")
if not L then return end

-- General
L["ADDON_NAME"] = "Loothing"
L["ADDON_LOADED"] = "Loothing v%s cargado. Escribe /loothing o /lt para opciones."
L["SLASH_HELP_HEADER"] = "Comandos de Loothing (usa /lt help <comando>):"
L["SLASH_HELP_DETAIL"] = "Uso para /lt %s:"
L["SLASH_HELP_UNKNOWN"] = "Comando desconocido '%s'. Usa /lt help."
L["SLASH_HELP_DEBUG_NOTE"] = "Activa /lt debug para ver comandos de desarrollador."
L["SLASH_NO_MAINFRAME"] = "La ventana principal aún no está disponible."
L["SLASH_NO_CONFIG"] = "El diálogo de configuración no está disponible."
L["SLASH_INVALID_ITEM"] = "Enlace de objeto inválido."
L["SLASH_SYNC_UNAVAILABLE"] = "El módulo de sincronización no está disponible."
L["SLASH_IMPORT_UNAVAILABLE"] = "El módulo de importación no está disponible."
L["SLASH_IMPORT_PROMPT"] = "Proporciona texto CSV/TSV: /lt import <datos>"
L["SLASH_IMPORT_PARSE_ERROR"] = "Error de análisis: %s"
L["SLASH_IMPORT_SUCCESS"] = "%d entradas importadas."
L["SLASH_IMPORT_FAILED"] = "Importación fallida: %s"
L["SLASH_DEBUG_STATE"] = "Debug de Loothing: %s"
L["SLASH_DEBUG_REQUIRED"] = "Activa el modo debug con /lt debug para usar este comando."
L["SLASH_TEST_UNAVAILABLE"] = "El modo de prueba no está disponible."
L["SLASH_DESC_SHOW"] = "Mostrar ventana principal"
L["SLASH_DESC_HIDE"] = "Ocultar ventana principal"
L["SLASH_DESC_TOGGLE"] = "Alternar ventana principal"
L["SLASH_DESC_CONFIG"] = "Abrir diálogo de configuración"
L["SLASH_DESC_HISTORY"] = "Abrir pestaña de historial"
L["SLASH_DESC_COUNCIL"] = "Abrir configuración del consejo"
L["SLASH_DESC_ML"] = "Ver o asignar Maestro Despojador"
L["SLASH_DESC_IGNORE"] = "Agregar/eliminar objeto de la lista de ignorados"
L["SLASH_DESC_SYNC"] = "Sincronizar configuración o historial"
L["SLASH_DESC_IMPORT"] = "Importar texto de historial de botín"
L["SLASH_DESC_DEBUG"] = "Alternar modo debug (habilita comandos de desarrollador)"
L["SLASH_DESC_TEST"] = "Utilidades del modo de prueba"
L["SLASH_DESC_TESTMODE"] = "Controlar simulador/modo de prueba"
L["SLASH_DESC_HELP"] = "Mostrar ayuda de comandos"
L["SLASH_DESC_START"] = "Activar distribución de botín"
L["SLASH_DESC_STOP"] = "Desactivar distribución de botín"

-- Session
L["SESSION_ACTIVE"] = "Sesión Activa"
L["SESSION_CLOSED"] = "Sesión Cerrada"
L["NO_ITEMS"] = "Sin objetos en la sesión"
L["MANUAL_SESSION"] = "Sesión Manual"
L["ITEMS_COUNT"] = "%d objetos (%d pendientes, %d votación, %d completados)"
L["YOU_ARE_ML"] = "Eres el Maestro Despojador"
L["ML_IS"] = "MD: %s"
L["ML_IS_EXPLICIT"] = "Maestro Despojador: %s (asignado)"
L["ML_IS_RAID_LEADER"] = "Maestro Despojador: %s (líder de banda)"
L["ML_NOT_SET"] = "Sin Maestro Despojador (no estás en un grupo)"
L["ML_CLEARED"] = "Maestro Despojador eliminado - usando líder de banda"
L["ML_ASSIGNED"] = "Maestro Despojador asignado a %s"
L["ML_HANDLING_LOOT"] = "Ahora gestionando la distribución de botín."
L["ML_NOT_ACTIVE_SESSION"] = "Loothing no está activo para esta sesión. Usa '/loothing start' para activarlo manualmente."
L["ML_USAGE_PROMPT_TEXT"] = "Eres el líder de banda. ¿Usar Loothing para la distribución de botín?"
L["ML_USAGE_PROMPT_TEXT_INSTANCE"] = "Eres el líder de banda.\n¿Usar Loothing para %s?"
L["ML_STOPPED_HANDLING"] = "Se detuvo la gestión de distribución de botín."
L["RECONNECT_RESTORED"] = "Estado de sesión restaurado desde la caché."
L["ERROR_NOT_ML_OR_RL"] = "Solo el Maestro Despojador o el Líder de Banda pueden hacer esto"
L["REFRESH"] = "Actualizar"
L["ITEM"] = "Objeto"
L["STATUS"] = "Estado"
L["START_ALL"] = "Iniciar Todo"
L["DATE"] = "Fecha"

-- Voting
L["VOTE"] = "Voto"
L["VOTING"] = "Votación"
L["START_VOTE"] = "Iniciar Votación"
L["TIME_REMAINING"] = "%d segundos restantes"
L["SUBMIT_VOTE"] = "Enviar Voto"
L["SUBMIT_RESPONSE"] = "Enviar Respuesta"
L["CHANGE_VOTE"] = "Cambiar Voto"

-- Responses

-- Response descriptions

-- Awards
L["AWARD"] = "Otorgar"
L["AWARD_ITEM"] = "Otorgar Objeto"
L["CONFIRM_AWARD"] = "¿Otorgar %s a %s?"
L["ITEM_AWARDED"] = "%s otorgado a %s"
L["SKIP_ITEM"] = "Saltar Objeto"
L["DISENCHANT"] = "Desencantar"

-- Results
L["RESULTS"] = "Resultados"
L["WINNER"] = "Ganador"
L["TIE"] = "Empate"

-- Council
L["COUNCIL"] = "Consejo"
L["COUNCIL_MEMBERS"] = "Miembros del Consejo"
L["ADD_MEMBER"] = "Agregar Miembro"
L["REMOVE_MEMBER"] = "Eliminar Miembro"
L["IS_COUNCIL"] = "%s es miembro del consejo"
L["AUTO_OFFICERS"] = "Incluir automáticamente oficiales"
L["AUTO_RAID_LEADER"] = "Incluir automáticamente líder de banda"

-- History
L["HISTORY"] = "Historial"
L["NO_HISTORY"] = "Sin historial de botín"
L["CLEAR_HISTORY"] = "Limpiar Historial"
L["CONFIRM_CLEAR_HISTORY"] = "¿Limpiar todo el historial de botín?"
L["EXPORT"] = "Exportar"
L["EXPORT_HISTORY"] = "Exportar Historial"
L["EXPORT_EQDKP"] = "EQdkp"
L["SEARCH"] = "Buscar..."
L["SELECT_ALL"] = "Seleccionar Todo"
L["ALL_WINNERS"] = "Todos los Ganadores"
L["CLEAR"] = "Limpiar"

-- Tabs
L["TAB_SESSION"] = "Sesión"
L["TAB_TRADE"] = "Intercambio"
L["TAB_HISTORY"] = "Historial"
L["TAB_ROSTER"] = "Lista"

-- Roster
L["ROSTER_SUMMARY"] = "%d Miembros | %d Conectados | %d Instalados | %d Consejo"
L["ROSTER_NO_GROUP"] = "No estás en un grupo"
L["ROSTER_QUERY_VERSIONS"] = "Consultar versiones"
L["ROSTER_ADD_COUNCIL"] = "Añadir al Consejo"
L["ROSTER_REMOVE_COUNCIL"] = "Quitar del Consejo"
L["ROSTER_SET_ML"] = "Asignar como Maestro Saqueador"
L["ROSTER_CLEAR_ML"] = "Quitar como Maestro Saqueador"
L["ROSTER_PROMOTE_LEADER"] = "Ascender a Líder"
L["ROSTER_PROMOTE_ASSISTANT"] = "Ascender a Asistente"
L["ROSTER_DEMOTE"] = "Degradar"
L["ROSTER_UNINVITE"] = "Expulsar"
L["ROSTER_ADD_OBSERVER"] = "Añadir como Observador"
L["ROSTER_REMOVE_OBSERVER"] = "Quitar como Observador"

-- Settings
L["SETTINGS"] = "Configuración"
L["GENERAL"] = "General"
L["VOTING_MODE"] = "Modo de Votación"
L["SIMPLE_VOTING"] = "Simple (Más votos gana)"
L["RANKED_VOTING"] = "Elección Clasificada"
L["VOTING_TIMEOUT"] = "Tiempo de Votación"
L["SECONDS"] = "segundos"
L["AUTO_INCLUDE_OFFICERS"] = "Incluir automáticamente oficiales"
L["AUTO_INCLUDE_LEADER"] = "Incluir automáticamente líder de banda"
L["ADD"] = "Agregar"

-- Auto-Pass
L["AUTOPASS_SETTINGS"] = "Configuración de Paso Automático"
L["ENABLE_AUTOPASS"] = "Habilitar Paso Automático"
L["AUTOPASS_DESC"] = "Pasar automáticamente en objetos que no puedes usar"
L["AUTOPASS_WEAPONS"] = "Pasar automáticamente armas (estadísticas principales incorrectas)"

-- Announcement Settings
L["ANNOUNCEMENT_SETTINGS"] = "Configuración de Anuncios"
L["ANNOUNCE_AWARDS"] = "Anunciar Otorgamientos"
L["ANNOUNCE_ITEMS"] = "Anunciar Objetos"
L["ANNOUNCE_BOSS_KILL"] = "Anunciar Inicio/Fin de Sesión"
L["CHANNEL_RAID"] = "Banda"
L["CHANNEL_RAID_WARNING"] = "Advertencia de Banda"
L["CHANNEL_OFFICER"] = "Oficial"
L["CHANNEL_GUILD"] = "Hermandad"
L["CHANNEL_PARTY"] = "Grupo"
L["CHANNEL_NONE"] = "Ninguno"

-- Auto-Award
L["AUTO_AWARD_SETTINGS"] = "Configuración de Otorgamiento Automático"
L["AUTO_AWARD_ENABLE"] = "Habilitar Otorgamiento Automático"
L["AUTO_AWARD_DESC"] = "Otorgar automáticamente objetos por debajo del umbral de calidad"
L["AUTO_AWARD_TO"] = "Otorgar a"
L["AUTO_AWARD_TO_DESC"] = "Nombre del jugador o 'desencantador'"

-- Ignore Items
L["IGNORE_ITEMS_SETTINGS"] = "Ignorar Objetos"
L["ENABLE_IGNORE_LIST"] = "Habilitar Lista de Ignorados"
L["IGNORE_LIST_DESC"] = "Los objetos en la lista de ignorados no serán rastreados por el consejo de botín"
L["IGNORED_ITEMS"] = "Objetos Ignorados"
L["NO_IGNORED_ITEMS"] = "Actualmente no hay objetos ignorados"
L["ADD_IGNORED_ITEM"] = "Agregar Objeto a Lista de Ignorados"
L["REMOVE_IGNORED_ITEM"] = "Eliminar de lista de ignorados"
L["ITEM_IGNORED"] = "%s agregado a la lista de ignorados"
L["ITEM_UNIGNORED"] = "%s eliminado de la lista de ignorados"
L["SLASH_IGNORE"] = "/loothing ignore [enlace de objeto] - Agregar/eliminar objeto de la lista de ignorados"
L["CLEAR_IGNORED_ITEMS"] = "Limpiar Todo"
L["CONFIRM_CLEAR_IGNORED"] = "¿Limpiar todos los objetos ignorados?"
L["IGNORED_ITEMS_CLEARED"] = "Lista de ignorados limpiada"
L["IGNORE_CATEGORIES"] = "Filtros de Categoría"
L["IGNORE_ADD_DESC"] = "Pega un enlace de objeto o introduce un ID de objeto."

-- Errors
L["ERROR_NO_SESSION"] = "Sin sesión activa"

-- Communication
L["SYNC_COMPLETE"] = "Sincronización completada"

-- Guild Sync
L["HISTORY_SYNCED"] = "%d entradas de historial sincronizadas desde %s"
L["SYNC_IN_PROGRESS"] = "Sincronización ya en progreso"
L["SYNC_TIMEOUT"] = "Sincronización agotada"

-- Tooltips
L["TOOLTIP_ITEM_LEVEL"] = "Nivel de Objeto: %d"
L["TOOLTIP_VOTES"] = "Votos: %d"

-- Status
L["STATUS_PENDING"] = "Pendiente"
L["STATUS_VOTING"] = "Votación"
L["STATUS_TALLIED"] = "Contabilizado"
L["STATUS_AWARDED"] = "Otorgado"
L["STATUS_SKIPPED"] = "Omitido"

-- Response Settings
L["RESET_RESPONSES"] = "Restablecer a Predeterminados"

-- Award Reason Settings
L["REQUIRE_AWARD_REASON"] = "Requerir motivo al otorgar"
L["AWARD_REASONS"] = "Motivos de Otorgamiento"
L["ADD_REASON"] = "Agregar Motivo"
L["REASON_NAME"] = "Nombre del Motivo"
L["AWARD_REASON"] = "Motivo de Otorgamiento"

-- Trade Panel
L["TRADE_QUEUE"] = "Cola de Intercambio"
L["TRADE_PANEL_HELP"] = "Haz clic en un nombre de jugador para iniciar el intercambio"
L["NO_PENDING_TRADES"] = "Sin objetos pendientes de intercambio"
L["NO_ITEMS_TO_TRADE"] = "Sin objetos para intercambiar"
L["ONE_ITEM_TO_TRADE"] = "1 objeto esperando intercambio"
L["N_ITEMS_TO_TRADE"] = "%d objetos esperando intercambio"
L["AUTO_TRADE"] = "Intercambio Automático"
L["CLEAR_COMPLETED"] = "Limpiar Completados"

-- Minimap

-- Voting Options
L["SELF_VOTE"] = "Permitir Auto-Voto"
L["SELF_VOTE_DESC"] = "Permitir que miembros del consejo voten por sí mismos"
L["MULTI_VOTE"] = "Permitir Multi-Voto"
L["MULTI_VOTE_DESC"] = "Permitir votar por múltiples candidatos por objeto"
L["ANONYMOUS_VOTING"] = "Votación Anónima"
L["ANONYMOUS_VOTING_DESC"] = "Ocultar quién votó por quién hasta que se otorgue el objeto"
L["HIDE_VOTES"] = "Ocultar Recuentos de Votos"
L["HIDE_VOTES_DESC"] = "No mostrar recuentos de votos hasta que estén todos"
L["OBSERVE_MODE"] = "Modo Observador"
L["AUTO_ADD_ROLLS"] = "Agregar Tiradas Automáticamente"
L["AUTO_ADD_ROLLS_DESC"] = "Agregar automáticamente resultados de /roll a candidatos"
L["REQUIRE_NOTES"] = "Requerir Notas"
L["REQUIRE_NOTES_DESC"] = "Los votantes deben agregar una nota con su voto"

-- Button Sets
L["BUTTON_SETS"] = "Conjuntos de Botones"
L["ACTIVE_SET"] = "Conjunto Activo"
L["NEW_SET"] = "Nuevo Conjunto"
L["CONFIRM_DELETE_SET"] = "¿Eliminar conjunto de botones '%s'?"
L["ADD_BUTTON"] = "Agregar Botón"
L["MAX_BUTTONS"] = "Máximo 10 botones por conjunto"
L["MIN_BUTTONS"] = "Se requiere al menos 1 botón"
L["DEFAULT_SET"] = "Predeterminado"
L["SORT_ORDER"] = "Orden de Clasificación"
L["BUTTON_COLOR"] = "Color del Botón"

-- Filters
L["FILTERS"] = "Filtros"
L["FILTER_BY_CLASS"] = "Filtrar por Clase"
L["FILTER_BY_RESPONSE"] = "Filtrar por Respuesta"
L["FILTER_BY_RANK"] = "Filtrar por Rango de Hermandad"
L["SHOW_EQUIPPABLE_ONLY"] = "Mostrar Solo Equipables"
L["HIDE_PASSED_ITEMS"] = "Ocultar Objetos Omitidos"
L["CLEAR_FILTERS"] = "Limpiar Filtros"
L["ALL_CLASSES"] = "Todas las Clases"
L["ALL_RESPONSES"] = "Todas las Respuestas"
L["ALL_RANKS"] = "Todos los Rangos"
L["FILTERS_ACTIVE"] = "%d filtro(s) activo(s)"

-- Generic / Missing strings
L["YES"] = "Sí"
L["NO"] = "No"
L["TIME_EXPIRED"] = "Tiempo agotado"
L["END_SESSION"] = "Finalizar Sesión"
L["END_VOTE"] = "Finalizar Votación"
L["START_SESSION"] = "Iniciar Sesión"
L["OPEN_MAIN_WINDOW"] = "Abrir ventana principal"
L["RE_VOTE"] = "Re-Votar"
L["ROLL_REQUEST"] = "Solicitud de Tirada"
L["ROLL_REQUEST_SENT"] = "Solicitud de tirada enviada"
L["SELECT_RESPONSE"] = "Seleccionar Respuesta"
L["HIDE_MINIMAP_BUTTON"] = "Ocultar botón de minimapa"
L["NO_SESSION"] = "Sin sesión activa"
L["MINIMAP_TOOLTIP_LEFT"] = "Clic izquierdo: Abrir Loothing"
L["MINIMAP_TOOLTIP_RIGHT"] = "Clic derecho: Opciones"
L["RESULTS_TITLE"] = "Resultados"
L["VOTE_TITLE"] = "Respuesta de Botín"
L["VOTES"] = "Votos"
L["ITEMS_PENDING"] = "%d objetos pendientes"
L["ITEMS_VOTING"] = "%d objetos votando"
L["LINK_IN_CHAT"] = "Enlazar en Chat"
L["VIEW"] = "Ver"

-- Group Loot

-- Frame/UI Settings

-- Master Looter Settings
L["CONFIG_ML_SETTINGS"] = "Configuración de Maestro Despojador"

-- History Settings
L["CONFIG_HISTORY_SETTINGS"] = "Configuración de Historial"
L["CONFIG_HISTORY_ENABLED"] = "Habilitar Historial de Botín"
L["CONFIG_HISTORY_CLEARALL_CONFIRM"] = "¿Estás seguro de que deseas eliminar TODAS las entradas de historial? ¡Esto no se puede deshacer!"

-- Enhanced Announcements

-- Enhanced Award Reasons
L["CONFIG_REASON_LOG"] = "Registrar en Historial"
L["CONFIG_REASON_DISENCHANT"] = "Tratar como Desencantamiento"
L["CONFIG_REASON_RESET_CONFIRM"] = "¿Restablecer todos los motivos de otorgamiento a predeterminados?"

-- Council Management
L["CONFIG_COUNCIL_REMOVEALL_CONFIRM"] = "¿Eliminar todos los miembros del consejo?"

-- Auto-Pass Enhancements
L["CONFIG_AUTOPASS_TRINKETS"] = "Pasar Automáticamente Joyas"
L["CONFIG_AUTOPASS_SILENT"] = "Paso Automático Silencioso"

-- Voting Enhancements
L["CONFIG_VOTING_MLSEESVOTES"] = "MD Ve Votos"
L["CONFIG_VOTING_MLSEESVOTES_DESC"] = "El Maestro Despojador puede ver votos incluso cuando es anónimo"

-- General Enhancements

-- Locale Override
L["CONFIG_LOCALE_OVERRIDE"] = "Anular idioma"
L["CONFIG_LOCALE_OVERRIDE_DESC"] = "Establecer el idioma del addon manualmente (requiere /reload)"
L["LOCALE_AUTO"] = "Automático (idioma del juego)"

-- Common UI
L["CLOSE"] = "Cerrar"
L["CANCEL"] = "Cancelar"
L["NO_LIMIT"] = "Sin límite"

-- Personal Preferences
L["PERSONAL_PREFERENCES"] = "Preferencias personales"
L["CONFIG_LOOT_RESPONSE"] = "Respuesta de botín"
L["CONFIG_ROLLFRAME_AUTO_SHOW"] = "Mostrar marco de respuesta automáticamente"
L["CONFIG_ROLLFRAME_AUTO_SHOW_DESC"] = "Mostrar automáticamente el marco de respuesta al iniciar la votación"
L["CONFIG_ROLLFRAME_AUTO_ROLL"] = "Auto-tirar al enviar"
L["CONFIG_ROLLFRAME_AUTO_ROLL_DESC"] = "Ejecutar /roll automáticamente al enviar una respuesta"
L["CONFIG_ROLLFRAME_GEAR_COMPARE"] = "Mostrar comparación de equipo"
L["CONFIG_ROLLFRAME_GEAR_COMPARE_DESC"] = "Mostrar los objetos equipados actualmente para comparación"
L["CONFIG_ROLLFRAME_REQUIRE_NOTE"] = "Requerir nota"
L["CONFIG_ROLLFRAME_REQUIRE_NOTE_DESC"] = "Requerir una nota antes de enviar una respuesta"
L["CONFIG_ROLLFRAME_PRINT_RESPONSE"] = "Imprimir respuesta en el chat"
L["CONFIG_ROLLFRAME_PRINT_RESPONSE_DESC"] = "Imprimir tu respuesta enviada en el chat como referencia personal"
L["CONFIG_ROLLFRAME_TIMER"] = "Temporizador de respuesta"
L["CONFIG_ROLLFRAME_TIMER_ENABLED"] = "Mostrar temporizador de respuesta"
L["CONFIG_ROLLFRAME_TIMER_DURATION"] = "Duración del temporizador"

-- Session Settings (ML)
L["SESSION_SETTINGS_ML"] = "Configuración de sesión (MD)"
L["VOTING_TIMEOUT_DURATION"] = "Duración del tiempo límite"

-- ============================================================================
-- Roll/Vote System Locale Strings
-- ============================================================================

-- RollFrame UI
L["ROLL_YOUR_ROLL"] = "Tu Tirada:"

-- RollFrame Settings

-- CouncilTable UI
L["COUNCIL_NO_CANDIDATES"] = "Aún no hay candidatos que hayan respondido"
L["COUNCIL_AWARD"] = "Otorgar"
L["COUNCIL_REVOTE"] = "Re-Votar"
L["COUNCIL_SKIP"] = "Saltar"
L["COUNCIL_CONFIRM_REVOTE"] = "¿Limpiar todos los votos y reiniciar la votación?"

-- CouncilTable Settings
L["COUNCIL_COLUMN_PLAYER"] = "Nombre del Jugador"
L["COUNCIL_COLUMN_RESPONSE"] = "Respuesta"
L["COUNCIL_COLUMN_ROLL"] = "Tirada"
L["COUNCIL_COLUMN_NOTE"] = "Nota"
L["COUNCIL_COLUMN_ILVL"] = "Nivel de Objeto"
L["COUNCIL_COLUMN_ILVL_DIFF"] = "Mejora (+/-)"
L["COUNCIL_COLUMN_GEAR1"] = "Ranura de Equipo 1"
L["COUNCIL_COLUMN_GEAR2"] = "Ranura de Equipo 2"

-- Winner Determination Settings
L["WINNER_DETERMINATION"] = "Determinación del Ganador"
L["WINNER_DETERMINATION_DESC"] = "Configurar cómo se seleccionan los ganadores cuando termina la votación."
L["WINNER_MODE"] = "Modo de Ganador"
L["WINNER_MODE_DESC"] = "Cómo se determina el ganador después de la votación"
L["WINNER_MODE_HIGHEST_VOTES"] = "Votos del Consejo Más Altos"
L["WINNER_MODE_ML_CONFIRM"] = "MB Confirma Ganador"
L["WINNER_MODE_AUTO_CONFIRM"] = "Auto-seleccionar Más Alto + Confirmar"
L["WINNER_TIE_BREAKER"] = "Desempate"
L["WINNER_TIE_BREAKER_DESC"] = "Cómo se resuelven los empates cuando los candidatos tienen votos iguales"
L["WINNER_TIE_USE_ROLL"] = "Usar Valor de Tirada"
L["WINNER_TIE_ML_CHOICE"] = "MB Elige"
L["WINNER_TIE_REVOTE"] = "Desencadenar Re-Votación"
L["WINNER_AUTO_AWARD_UNANIMOUS"] = "Auto-otorgar en Unánime"
L["WINNER_AUTO_AWARD_UNANIMOUS_DESC"] = "Otorgar automáticamente cuando todos los miembros del consejo voten por el mismo candidato"
L["WINNER_REQUIRE_CONFIRMATION"] = "Requerir Confirmación"
L["WINNER_REQUIRE_CONFIRMATION_DESC"] = "Mostrar diálogo de confirmación antes de otorgar objetos"

-- Communication messages

-- Council Management (Guild/Group based)

-- Announcements - Considerations
L["CONFIG_CONSIDERATIONS"] = "Consideraciones"
L["CONFIG_CONSIDERATIONS_CHANNEL"] = "Canal"
L["CONFIG_CONSIDERATIONS_TEXT"] = "Plantilla de Mensaje"

-- Announcements - Line Configuration
L["CONFIG_LINE"] = "Línea"
L["CONFIG_ENABLED"] = "Habilitado"
L["CONFIG_CHANNEL"] = "Canal"

-- Session Announcements

-- Award Reasons
L["CONFIG_NUM_REASONS_DESC"] = "Número de motivos de otorgamiento activos (1-20)"
L["CONFIG_AWARD_REASONS_DESC"] = "Configurar motivos de otorgamiento. Cada motivo puede alternarse para registro y marcarse como desencantamiento."
L["CONFIG_RESET_REASONS"] = "Restablecer a Predeterminados"

-- Frame Settings (using OptionsTable naming convention)
L["CONFIG_FRAME_MINIMIZE_COMBAT"] = "Minimizar en Combate"
L["CONFIG_FRAME_TIMEOUT_FLASH"] = "Parpadear al Tiempo Agotado"
L["CONFIG_FRAME_BLOCK_TRADES"] = "Bloquear Intercambios Durante Votación"

-- History Settings
L["CONFIG_HISTORY_SEND"] = "Enviar Historial"
L["CONFIG_HISTORY_CLEAR_ALL"] = "Limpiar Todo"
L["CONFIG_HISTORY_AUTO_EXPORT_WEB"] = "Mostrar exportación web automáticamente"
L["CONFIG_HISTORY_AUTO_EXPORT_WEB_DESC"] = "Al terminar una sesión, abrir automáticamente el diálogo de exportación con la exportación web lista para copiar"

-- Whisper Commands
L["WHISPER_RESPONSE_RECEIVED"] = "Loothing: Respuesta '%s' recibida para %s"
L["WHISPER_NO_SESSION"] = "Loothing: Sin sesión activa"
L["WHISPER_NO_VOTING_ITEMS"] = "Loothing: No hay objetos abiertos para votación"
L["WHISPER_UNKNOWN_COMMAND"] = "Loothing: Comando desconocido '%s'. Susurra !help para opciones"
L["WHISPER_HELP_HEADER"] = "Loothing: Comandos por susurro:"
L["WHISPER_HELP_LINE"] = "  %s - %s"
L["WHISPER_ITEM_SPECIFIED"] = "Loothing: Respuesta '%s' recibida para %s (#%d)"
L["WHISPER_INVALID_ITEM_NUM"] = "Loothing: Número de objeto inválido %d (la sesión tiene %d objetos)"

-- ============================================================================
-- Phase 1-6 Additional Locale Strings
-- ============================================================================

-- General / UI
L["ADDON_TAGLINE"] = "Addon de Consejo de Botín"
L["VERSION"] = "Versión"
L["VERSION_CHECK"] = "Verificar Versión"
L["OUTDATED"] = "Desactualizado"
L["NOT_INSTALLED"] = "No Instalado"
L["CURRENT"] = "Actual"
L["ENABLED"] = "Habilitado"
L["REQUIRED"] = "Requerido"
L["NOTE"] = "Nota:"
L["PLAYER"] = "Jugador"
L["SEND"] = "Enviar"
L["SEND_TO"] = "Enviar a:"
L["WHISPER"] = "Susurro"

-- Blizzard Settings Integration
L["BLIZZARD_SETTINGS_DESC"] = "Haz clic abajo para abrir el panel de configuración completo"
L["OPEN_SETTINGS"] = "Abrir Configuración de Loothing"

-- Slash Commands (Debug)
L["SLASH_DESC_ERRORS"] = "Mostrar errores capturados"
L["SLASH_DESC_LOG"] = "Ver registros recientes"

-- Session Panel
L["ADD_ITEM"] = "Agregar Objeto"
L["ADD_ITEM_TITLE"] = "Agregar Objeto a la Sesión"
L["ENTER_ITEM"] = "Introducir Objeto"
L["RECENT_DROPS"] = "Botín Reciente"
L["FROM_BAGS"] = "Desde Bolsas"
L["ENTER_ITEM_HINT"] = "Pega un enlace de objeto, ID de objeto, o arrastra un objeto aquí"
L["DRAG_ITEM_HERE"] = "Suelta el objeto aquí"
L["NO_RECENT_DROPS"] = "No se encontraron objetos intercambiables recientes"
L["NO_BAG_ITEMS"] = "No hay objetos elegibles en las bolsas"
L["EQUIPMENT_ONLY"] = "Solo Equipamiento"
L["SLASH_DESC_ADD"] = "Agregar objeto a la sesión"
L["AWARD_LATER_ALL"] = "Otorgar Después (Todos)"

-- Session Trigger Modes (legacy -- kept for backward compat)
L["TRIGGER_MANUAL"] = "Manual (usa /loothing start)"
L["TRIGGER_AUTO"] = "Automático (iniciar inmediatamente)"
L["TRIGGER_PROMPT"] = "Preguntar (consultar antes de iniciar)"

-- Session Trigger Policy (split model)
L["SESSION_TRIGGER_HEADER"] = "Activación de Sesión"
L["SESSION_TRIGGER_ACTION"] = "Acción de Activación"
L["SESSION_TRIGGER_ACTION_DESC"] = "Qué ocurre cuando la muerte de un jefe es elegible"
L["SESSION_TRIGGER_TIMING"] = "Momento de Activación"
L["SESSION_TRIGGER_TIMING_DESC"] = "Cuándo se ejecuta la acción de activación respecto a la muerte del jefe"
L["TRIGGER_TIMING_ENCOUNTER_END"] = "Al Matar al Jefe"
L["TRIGGER_TIMING_AFTER_LOOT"] = "Tras el botín del encuentro"
L["TRIGGER_SCOPE_RAID"] = "Jefes de Banda"
L["TRIGGER_SCOPE_RAID_DESC"] = "Activar al matar jefes de banda"
L["TRIGGER_SCOPE_DUNGEON"] = "Jefes de Mazmorra"
L["TRIGGER_SCOPE_DUNGEON_DESC"] = "Activar al matar jefes de mazmorra"
L["TRIGGER_SCOPE_OPEN_WORLD"] = "Mundo Abierto"
L["TRIGGER_SCOPE_OPEN_WORLD_DESC"] = "Activar en encuentros de mundo abierto (ej: jefes de mundo)"

-- AutoPass Options
L["CONFIG_AUTOPASS_BOE"] = "Paso Automático en Objetos BoE"
L["CONFIG_AUTOPASS_BOE_DESC"] = "Pasar automáticamente en objetos Vinculados al Equipo"
L["CONFIG_AUTOPASS_TRANSMOG"] = "Paso Automático en Transfiguración"
L["CONFIG_AUTOPASS_TRANSMOG_SOURCE"] = "Saltar Apariencias Conocidas"

-- Auto Award Options
L["CONFIG_AUTO_AWARD_LOWER_THRESHOLD"] = "Umbral de Calidad Inferior"
L["CONFIG_AUTO_AWARD_UPPER_THRESHOLD"] = "Umbral de Calidad Superior"
L["CONFIG_AUTO_AWARD_REASON"] = "Motivo de Otorgamiento"
L["CONFIG_AUTO_AWARD_INCLUDE_BOE"] = "Incluir Objetos BoE"

-- Frame Behavior Options
L["CONFIG_FRAME_BEHAVIOR"] = "Comportamiento del Marco"
L["CONFIG_FRAME_AUTO_OPEN"] = "Abrir Marcos Automáticamente"
L["CONFIG_FRAME_AUTO_CLOSE"] = "Cerrar Marcos Automáticamente"
L["CONFIG_FRAME_SHOW_SPEC_ICON"] = "Mostrar Iconos de Especialidad"
L["CONFIG_FRAME_CLOSE_ESCAPE"] = "Cerrar con Escape"
L["CONFIG_FRAME_CHAT_OUTPUT"] = "Marco de Chat de Salida"

-- ML Usage Options
L["CONFIG_ML_USAGE_MODE"] = "Modo de Uso"
L["CONFIG_ML_USAGE_NEVER"] = "Nunca"
L["CONFIG_ML_USAGE_GL"] = "Botín de Grupo"
L["CONFIG_ML_USAGE_ASK_GL"] = "Preguntar en Botín de Grupo"
L["CONFIG_ML_RAIDS_ONLY"] = "Solo en Bandas"
L["CONFIG_ML_ALLOW_OUTSIDE"] = "Permitir Fuera de Bandas"
L["CONFIG_ML_SKIP_SESSION"] = "Saltar Marco de Sesión"
L["CONFIG_ML_SORT_ITEMS"] = "Clasificar Objetos"
L["CONFIG_ML_AUTO_ADD_BOES"] = "Agregar BoEs Automáticamente"
L["CONFIG_ML_PRINT_TRADES"] = "Imprimir Intercambios Completados"
L["CONFIG_ML_REJECT_TRADE"] = "Rechazar Intercambios Inválidos"
L["CONFIG_ML_AWARD_LATER"] = "Otorgar Después"

-- History Options
L["CONFIG_HISTORY_SEND_GUILD"] = "Enviar a Hermandad"
L["CONFIG_HISTORY_SAVE_PL"] = "Guardar Botín Personal"

-- Ignore Item Options
L["CONFIG_IGNORE_ENCHANTING_MATS"] = "Ignorar Materiales de Encantamiento"
L["CONFIG_IGNORE_CRAFTING_REAGENTS"] = "Ignorar Reactivos de Creación"
L["CONFIG_IGNORE_CONSUMABLES"] = "Ignorar Consumibles"
L["CONFIG_IGNORE_PERMANENT_ENHANCEMENTS"] = "Ignorar Mejoras Permanentes"

-- Announcement Options
L["CONFIG_ANNOUNCEMENT_TOKENS_DESC"] = "Etiquetas disponibles: {item}, {winner}, {reason}, {notes}, {ilvl}, {type}, {oldItem}, {ml}, {session}, {votes}"
L["CONFIG_ANNOUNCE_CONSIDERATIONS"] = "Anunciar Consideraciones"
L["CONFIG_ITEM_ANNOUNCEMENTS"] = "Anuncios de Objeto"
L["CONFIG_SESSION_ANNOUNCEMENTS"] = "Anuncios de Sesión"
L["CONFIG_SESSION_START"] = "Inicio de Sesión"
L["CONFIG_SESSION_END"] = "Fin de Sesión"
L["CONFIG_MESSAGE"] = "Mensaje"

-- Button Sets & Type Code Options
L["CONFIG_BUTTON_SETS"] = "Conjuntos de Botones"
L["CONFIG_TYPECODE_ASSIGNMENT"] = "Asignación de Código de Tipo"

-- Award Reasons Options
L["CONFIG_AWARD_REASONS"] = "Motivos de Otorgamiento"
L["NUM_AWARD_REASONS"] = "Número de Motivos"

-- Council Guild Rank Options
L["CONFIG_GUILD_RANK"] = "Inclusión Automática por Rango de Hermandad"
L["CONFIG_GUILD_RANK_DESC"] = "Incluir automáticamente a miembros de hermandad de cierto rango o superior en el consejo"
L["CONFIG_MIN_RANK"] = "Rango Mínimo de Hermandad"
L["CONFIG_MIN_RANK_DESC"] = "Los miembros de hermandad con este rango o superior se incluirán automáticamente como consejeros. 0 = desactivado, 1 = Líder de Hermandad, 2 = Oficiales, etc."
L["CONFIG_COUNCIL_REMOVE_ALL"] = "Eliminar Todos los Miembros"

-- Council Table UI
L["CHANGE_RESPONSE"] = "Cambiar Respuesta"

-- Sync Panel UI
L["SYNC_DATA"] = "Sincronizar Datos"
L["SELECT_TARGET"] = "Seleccionar Objetivo"
L["SELECT_TARGET_FIRST"] = "Selecciona un jugador objetivo"
L["NO_TARGETS"] = "No se encontraron miembros conectados"
L["GUILD"] = "Hermandad (Todos Conectados)"
L["QUERY_GROUP"] = "Consultar Grupo"
L["LAST_7_DAYS"] = "Últimos 7 Días"
L["LAST_30_DAYS"] = "Últimos 30 Días"
L["ALL_TIME"] = "Todo el Tiempo"
L["SYNCING_TO"] = "Sincronizando %s a %s..."

-- History Panel UI
L["DATE_RANGE"] = "Rango de Fechas:"
L["FILTER_BY_WINNER"] = "Filtrar por %s"
L["DELETE_ENTRY"] = "Eliminar Entrada"

-- Observer System
L["OBSERVER"] = "Observador"

-- ML Observer
L["CONFIG_ML_OBSERVER"] = "Modo Observador del MD"
L["CONFIG_ML_OBSERVER_DESC"] = "El Maestro Despojador puede ver todo y gestionar sesiones pero no puede votar"

-- Open Observation (replaces OBSERVE_MODE)
L["OPEN_OBSERVATION"] = "Observación Abierta"
L["OPEN_OBSERVATION_DESC"] = "Permitir que todos los miembros de banda observen la votación (agrega a todos como observadores)"

-- Observer Permissions
L["OBSERVER_PERMISSIONS"] = "Permisos de Observador"
L["OBSERVER_SEE_VOTE_COUNTS"] = "Ver Recuentos de Votos"
L["OBSERVER_SEE_VOTE_COUNTS_DESC"] = "Los observadores pueden ver cuántos votos tiene cada candidato"
L["OBSERVER_SEE_VOTER_IDS"] = "Ver Identidad de Votantes"
L["OBSERVER_SEE_VOTER_IDS_DESC"] = "Los observadores pueden ver quién votó por cada candidato"
L["OBSERVER_SEE_RESPONSES"] = "Ver Respuestas"
L["OBSERVER_SEE_RESPONSES_DESC"] = "Los observadores pueden ver qué respuesta seleccionó cada candidato"
L["OBSERVER_SEE_NOTES"] = "Ver Notas"
L["OBSERVER_SEE_NOTES_DESC"] = "Los observadores pueden ver las notas de los candidatos"

-- Bulk Actions
L["BULK_START_VOTE"] = "Iniciar Votación (%d)"
L["BULK_END_VOTE"] = "Finalizar Votación (%d)"
L["BULK_SKIP"] = "Saltar (%d)"
L["BULK_REMOVE"] = "Eliminar (%d)"
L["BULK_REVOTE"] = "Re-Votar (%d)"
L["BULK_AWARD_LATER"] = "Otorgar Después"
L["DESELECT_ALL"] = "Deseleccionar"
L["N_SELECTED"] = "%d seleccionados"
L["REMOVE_ITEMS"] = "Eliminar Objetos"
L["CONFIRM_BULK_SKIP"] = "¿Saltar %d objetos seleccionados?"
L["CONFIRM_BULK_REMOVE"] = "¿Eliminar %d objetos seleccionados de la sesión?"
L["CONFIRM_BULK_REVOTE"] = "¿Re-votar en %d objetos seleccionados?"

-- ============================================================================
-- RCV (Ranked Choice Voting) Audit Strings
-- ============================================================================

-- RCV Settings
L["RCV_SETTINGS"] = "Configuración de Voto por Clasificación"
L["MAX_RANKS"] = "Clasificaciones Máximas"
L["MIN_RANKS"] = "Clasificaciones Mínimas"
L["MAX_RANKS_DESC"] = "Número máximo de opciones que un votante puede clasificar (0 = ilimitado)"
L["MIN_RANKS_DESC"] = "Número mínimo de opciones requeridas para enviar un voto"
L["RANK_LIMIT_REACHED"] = "Máximo de %d clasificaciones alcanzado"
L["RANK_MINIMUM_REQUIRED"] = "Clasifica al menos %d opciones"
L["MAX_REVOTES"] = "Máximo de Re-Votaciones"

-- ML Sees Votes

-- IRV Round Visualization
L["SHOW_IRV_ROUNDS"] = "Mostrar Rondas IRV (%d rondas)"
L["HIDE_IRV_ROUNDS"] = "Ocultar Rondas IRV"

-- Settings Export/Import
L["PROFILES"] = "Perfiles"
L["EXPORT_SETTINGS"] = "Exportar Configuración"
L["IMPORT_SETTINGS"] = "Importar Configuración"
L["EXPORT_TITLE"] = "Exportar Configuración"
L["EXPORT_DESC"] = "Presiona Ctrl+A para seleccionar todo, luego Ctrl+C para copiar."
L["EXPORT_FAILED"] = "Exportación fallida: %s"
L["IMPORT_TITLE"] = "Importar Configuración"
L["IMPORT_DESC"] = "Pega una cadena de configuración exportada abajo, luego haz clic en Importar."
L["IMPORT_BUTTON"] = "Importar"
L["IMPORT_FAILED"] = "Importación fallida: %s"
L["IMPORT_VERSION_WARN"] = "Nota: exportado con Loothing v%s (tienes v%s)."
L["IMPORT_SUCCESS_NEW"] = "Configuración importada como nuevo perfil: %s"
L["IMPORT_SUCCESS_CURRENT"] = "Configuración importada al perfil actual."
L["SLASH_DESC_EXPORT"] = "Exportar configuración del perfil actual"
L["SLASH_DESC_PROFILE"] = "Gestionar perfiles (listar, cambiar, crear)"

-- Profile Management
L["PROFILE_CURRENT"] = "Perfil Actual"
L["PROFILE_SWITCH"] = "Cambiar Perfil"
L["PROFILE_SWITCH_DESC"] = "Selecciona un perfil al cual cambiar."
L["PROFILE_NEW"] = "Crear Nuevo Perfil"
L["PROFILE_NEW_DESC"] = "Introduce un nombre para el nuevo perfil."
L["PROFILE_COPY_FROM"] = "Copiar Desde"
L["PROFILE_COPY_DESC"] = "Copiar configuración de otro perfil al perfil actual."
L["PROFILE_COPY_CONFIRM"] = "Esto sobrescribirá toda la configuración de tu perfil actual. ¿Continuar?"
L["PROFILE_DELETE"] = "Eliminar Perfil"
L["PROFILE_DELETE_CONFIRM"] = "¿Estás seguro de que deseas eliminar este perfil? Esto no se puede deshacer."
L["PROFILE_RESET"] = "Restablecer a Predeterminados"
L["PROFILE_RESET_CONFIRM"] = "¿Restablecer perfil '%s' a la configuración predeterminada? Esto no se puede deshacer."
L["PROFILE_LIST"] = "Todos los Perfiles"
L["PROFILE_DEFAULT_SUFFIX"] = "(predeterminado)"
L["PROFILE_EXPORT_INLINE_DESC"] = "Genera una cadena de exportación, luego cópiala para compartir tu configuración."
L["PROFILE_IMPORT_INLINE_DESC"] = "Pega una cadena de configuración exportada abajo, luego haz clic en Importar."
L["PROFILE_LIST_HEADER"] = "Perfiles:"
L["PROFILE_SWITCHED"] = "Cambiado al perfil: %s"
L["PROFILE_CREATED"] = "Creado y cambiado al perfil: %s"

-- ============================================================================
-- Additional Translations (207 keys)
-- ============================================================================

-- General UI Actions
L["ACCEPT"] = "Aceptar"
L["COPY"] = "Copiar"
L["COPY_SUFFIX"] = "(Copia)"
L["DECLINE"] = "Rechazar"
L["DELETE"] = "Eliminar"
L["EDIT"] = "Editar"
L["KEEP"] = "Conservar"
L["LESS"] = "Menos"
L["NEW"] = "Nuevo"
L["OK"] = "Aceptar"
L["OVERWRITE"] = "Sobrescribir"
L["RECOMMENDED"] = "Recomendado"
L["REMOVE"] = "Eliminar"
L["RENAME"] = "Renombrar"
L["RESET"] = "Restablecer"
L["UNKNOWN"] = "Desconocido"
L["VIEW_GEAR"] = "Ver Equipo"

-- Labels & Prefixes
L["ADD_NOTE_PLACEHOLDER"] = "Agregar una nota..."
L["CURRENT_COLON"] = "Actual: "
L["DISPLAY_TEXT_LABEL"] = "Texto de Visualización:"
L["EQUIPPED_GEAR"] = "Equipo Equipado"
L["ICON_LABEL"] = "Icono:"
L["ICON_SET"] = "Icono: ✓"
L["ILVL_PREFIX"] = "iLvl "
L["NOTE_OPTIONAL"] = "Nota (opcional):"
L["SET_LABEL"] = "Conjunto:"
L["WHISPER_KEYS_LABEL"] = "Claves de Susurro:"
L["RESPONSE_TEXT_LABEL"] = "Texto de Respuesta:"

-- Announcements
L["ANN_CONSIDERATIONS_DEFAULT"] = "{ml} está considerando {item} para distribución"
L["SESSION_ENDED_DEFAULT"] = "Sesión del consejo de botín finalizada"
L["SESSION_STARTED_DEFAULT"] = "Sesión del consejo de botín iniciada"

-- Awards
L["AWARD_FOR"] = "Otorgar a..."
L["AWARD_LATER_ALL_DESC"] = "Marcar todos los objetos para otorgar después de la sesión"
L["AWARD_LATER_ITEM_DESC"] = "Marcar este objeto para otorgar después de la sesión"
L["AWARD_LATER_SHORT"] = "Después"

-- Auto-Award
L["AUTO_AWARD_TARGET_NOT_IN_RAID"] = "El objetivo de otorgamiento automático %s no está en la banda"

-- Columns
L["COLUMN_INST"] = "Inst"
L["COLUMN_ROLE"] = "Rol"
L["COLUMN_TOOLTIP_WON_INSTANCE"] = "Objetos ganados en esta instancia + dificultad"
L["COLUMN_TOOLTIP_WON_SESSION"] = "Objetos ganados esta sesión"
L["COLUMN_TOOLTIP_WON_WEEKLY"] = "Objetos ganados esta semana"
L["COLUMN_VOTE"] = "Voto"
L["COLUMN_WK"] = "Sem"
L["COLUMN_WON"] = "Gan"

-- Config: General
L["APPLY_TO_CURRENT"] = "Aplicar al Actual"
L["CONFIG_AWARD_REASONS_ENABLED_DESC"] = "Habilitar o deshabilitar el sistema de motivos de otorgamiento"
L["CONFIG_BUTTON_SETS_DESC"] = "Configurar conjuntos de botones de respuesta, iconos, claves de susurro y asignaciones de código de tipo usando el editor visual."
L["CONFIG_CONFIRM_REMOVE_REASON"] = "¿Eliminar este motivo de otorgamiento?"
L["CONFIG_CONFIRM_RESET_REASONS"] = "¿Restablecer todos los motivos de otorgamiento a sus valores predeterminados? Esto no se puede deshacer."
L["CONFIG_LOCAL_PREFS_DESC"] = "Estas configuraciones solo te afectan a ti. No se transmiten a la banda."
L["CONFIG_LOCAL_PREFS_NOTE"] = " Estas configuraciones solo afectan tu cliente. Nunca se envían a otros miembros de banda."
L["CONFIG_MANAGE"] = "Administrar"
L["CONFIG_MAX_REVOTES_DESC"] = "Número máximo de re-votaciones permitidas por objeto (0 = sin re-votaciones)"
L["CONFIG_NEW_REASON_DEFAULT"] = "Nuevo Motivo"
L["CONFIG_OBSERVER_PERMISSIONS_DESC"] = "Controlar lo que los observadores pueden ver durante las sesiones de votación."
L["CONFIG_OPEN_BUTTON_EDITOR"] = "Abrir Editor de Botones de Respuesta"
L["CONFIG_REASON_DEFAULT"] = "Motivo"
L["CONFIG_REASONS"] = "Motivos"
L["CONFIG_REQUIRE_AWARD_REASON_DESC"] = "Requerir seleccionar un motivo de otorgamiento antes de otorgar un objeto"
L["CONFIG_ROLLFRAME_TIMER_ENABLED_DESC"] = "Mostrar un temporizador de cuenta regresiva en el marco de respuesta. Cuando está deshabilitado, el marco permanece abierto hasta que respondas o el MD finalice la votación."
L["CONFIG_SESSION_BROADCAST_DESC"] = "Estas configuraciones se transmiten a todos los miembros de banda cuando eres el Maestro Despojador. Controlan la sesión para todos."
L["CONFIG_SESSION_BROADCAST_NOTE"] = "Estas configuraciones se transmiten a todos los miembros de banda cuando inicias una sesión como Maestro Despojador."
L["CONFIG_TRIGGER_SCOPE_NOTE"] = "Los encuentros de JcJ, arena y escenarios nunca activan sesiones. Solo banda es el valor predeterminado."
L["CONFIG_VOTING_TIMEOUT_DESC"] = "Cuando está deshabilitado, la votación continúa hasta que el MD la finalice manualmente."

-- Config: Council
L["CONFIG_COUNCIL_ADD_HELP"] = "Los miembros del consejo pueden votar en la distribución de botín. Usa el campo a continuación para agregar miembros por nombre."
L["CONFIG_COUNCIL_ADD_NAME_DESC"] = "Introduce nombre del personaje (ej: 'NombreJugador' o 'NombreJugador-Reino')"
L["CONFIG_COUNCIL_ALL_REMOVED"] = "Todos los miembros del consejo eliminados"
L["CONFIG_COUNCIL_CONFIRM_REMOVE"] = "¿Eliminar a %s del consejo?"
L["CONFIG_COUNCIL_CONFIRM_REMOVE_ALL"] = "¿Eliminar a TODOS los miembros del consejo?"
L["CONFIG_COUNCIL_MEMBER_REMOVED"] = "%s eliminado del consejo"
L["CONFIG_COUNCIL_NO_MEMBERS"] = "Aún no se han agregado miembros al consejo."
L["CONFIG_COUNCIL_REMOVE_DESC"] = "Selecciona un miembro para eliminar del consejo"

-- Config: History
L["CONFIG_HISTORY_ALL_CLEARED"] = "Todo el historial limpiado"

-- Response Sets
L["CANNOT_DELETE_LAST_SET"] = "No se puede eliminar el último conjunto de respuestas."
L["NEW_BUTTON"] = "Nuevo Botón"
L["PICK_ICON"] = "Elegir Icono…"
L["RESPONSE_BUTTON_EDITOR"] = "Editor de Botones de Respuesta"

-- Council Voting
L["CLICK_SELECT_ENCHANTER"] = "Haz clic para seleccionar un encantador"
L["COUNCIL_VOTING_PROGRESS"] = "Progreso de Votación del Consejo"
L["DISENCHANT_TARGET"] = "Objetivo de Desencantamiento"
L["LOOT_COUNCIL"] = "Consejo de Botín"
L["LOOT_RESPONSE_TITLE"] = "Respuesta de Botín"
L["NO_COUNCIL_VOTES"] = "No se han emitido votos del consejo"
L["SELECT_ENCHANTER"] = "Seleccionar Encantador"
L["VOTE_RANK"] = "Rango"
L["VOTE_RANKED"] = "Clasificado"
L["VOTES_LABEL"] = "votos"
L["VOTE_VOTED"] = "Votado"

-- Response States
L["RESPONSE_AUTO_PASS"] = "Paso Automático"
L["RESPONSE_WAITING"] = "Esperando..."

-- Group Status
L["NOT_IN_GROUP"] = "No estás en una banda o grupo"
L["NOT_IN_GUILD"] = "No estás en una hermandad"

-- Profiles
L["CREATE_NEW_PROFILE"] = "Crear Nuevo Perfil"
L["IMPORT_SUMMARY"] = "Perfil: %s | Exportado: %s | Versión: %s"
L["PROFILE_ERR_EMPTY"] = "El nombre no puede estar vacío"
L["PROFILE_ERR_INVALID_CHARS"] = "El nombre contiene caracteres inválidos"
L["PROFILE_ERR_NOT_STRING"] = "El nombre debe ser una cadena de texto"
L["PROFILE_ERR_TOO_LONG"] = "El nombre debe tener 48 caracteres o menos"
L["PROFILE_SHARE_BUTTON"] = "Compartir"
L["PROFILE_SHARE_DESC"] = "Enviar la cadena de exportación actual directamente a un miembro del grupo conectado."
L["PROFILE_SHARE_FAILED"] = "La configuración compartida de %s no pudo importarse: %s"
L["PROFILE_SHARE_FAILED_GENERIC"] = "Error al compartir: %s"
L["PROFILE_SHARE_RECEIVED"] = "Configuración compartida recibida de %s."
L["PROFILE_SHARE_SENT"] = "Perfil actual compartido con %s."
L["PROFILE_SHARE_TARGET"] = "Compartir Con"
L["PROFILE_SHARE_TARGET_REQUIRED"] = "Selecciona un objetivo primero."
L["PROFILE_SHARE_UNAVAILABLE"] = "El compartir perfiles no está disponible."

-- Quality Names
L["QUALITY_ARTIFACT"] = "Artefacto"
L["QUALITY_COMMON"] = "Común"
L["QUALITY_EPIC"] = "Épico"
L["QUALITY_HEIRLOOM"] = "Reliquia"
L["QUALITY_LEGENDARY"] = "Legendario"
L["QUALITY_POOR"] = "Pobre"
L["QUALITY_RARE"] = "Raro"
L["QUALITY_UNCOMMON"] = "Poco Común"
L["QUALITY_UNKNOWN"] = "Desconocido"

-- Item Categories
L["ITEM_CATEGORY_CONSUMABLE"] = "Consumible"
L["ITEM_CATEGORY_CRAFTING"] = "Reactivo de Creación"
L["ITEM_CATEGORY_ENCHANTING"] = "Material de Encantamiento"
L["ITEM_CATEGORY_GEM"] = "Gema"
L["ITEM_CATEGORY_TRADE_GOODS"] = "Materiales de Comercio"

-- Session Items
L["QUEUED_ITEMS_HINT"] = "Los objetos en cola aparecerán aquí"
L["REMOVE_FROM_QUEUE"] = "Eliminar de la cola"
L["REMOVE_FROM_SESSION"] = "Eliminar de la sesión"
L["TOO_MANY_ITEMS_WARNING"] = "Demasiados objetos (%d). Solo se muestran botones para los primeros %d objetos. Usa la navegación para acceder a todos."

-- Roster
L["ROSTER_COUNCIL_MEMBER"] = "Miembro del Consejo"
L["ROSTER_DEAD"] = "Muerto"
L["ROSTER_MASTER_LOOTER"] = "Maestro Despojador"
L["ROSTER_NO_ROLE"] = "Sin Rol"
L["ROSTER_NOT_INSTALLED"] = "No Instalado"
L["ROSTER_OFFLINE"] = "Desconectado"
L["ROSTER_RANK_MEMBER"] = "Miembro"
L["ROSTER_TOOLTIP_GROUP"] = "Grupo: "
L["ROSTER_TOOLTIP_LOOT_HISTORY"] = "Historial de Botín: %d objetos"
L["ROSTER_TOOLTIP_ROLE"] = "Rol: "
L["ROSTER_TOOLTIP_TEST_VERSION"] = "Versión de Prueba: "
L["ROSTER_TOOLTIP_VERSION"] = "Loothing: "
L["ROSTER_UNKNOWN"] = "Desconocido"

-- Popups: Confirmations
L["POPUP_AWARD_LATER"] = "¿Otorgar {item} a ti mismo para distribuir después?"
L["POPUP_CLEAR_COUNCIL"] = "¿Eliminar todos los miembros del consejo?"
L["POPUP_CLEAR_COUNCIL_COUNT"] = "¿Eliminar los %d miembros del consejo?"
L["POPUP_CLEAR_IGNORED"] = "¿Limpiar todos los objetos ignorados?"
L["POPUP_CLEAR_IGNORED_COUNT"] = "¿Limpiar los %d objetos ignorados?"
L["POPUP_CONFIRM_END_SESSION"] = "¿Estás seguro de que quieres finalizar la sesión de botín actual? Todos los objetos pendientes serán cerrados."
L["POPUP_CONFIRM_REVOTE"] = "¿Limpiar todos los votos y reiniciar la votación para {item}?"
L["POPUP_CONFIRM_REVOTE_FMT"] = "¿Limpiar todos los votos y reiniciar la votación para %s?"
L["POPUP_CONFIRM_USAGE"] = "¿Quieres usar Loothing para la distribución de botín en esta banda?"
L["POPUP_DELETE_HISTORY_ALL"] = "¿Eliminar TODAS las entradas del historial? Esto no se puede deshacer."
L["POPUP_DELETE_HISTORY_MULTI"] = "¿Eliminar %d entradas del historial? Esto no se puede deshacer."
L["POPUP_DELETE_HISTORY_SELECTED"] = "¿Eliminar las entradas del historial seleccionadas? Esto no se puede deshacer."
L["POPUP_DELETE_HISTORY_SINGLE"] = "¿Eliminar 1 entrada del historial? Esto no se puede deshacer."
L["POPUP_DELETE_RESPONSE_BUTTON"] = "¿Eliminar este botón de respuesta?"
L["POPUP_DELETE_RESPONSE_SET"] = "¿Eliminar este conjunto de respuestas? Esto no se puede deshacer."
L["POPUP_KEEP_OR_TRADE"] = "¿Qué quieres hacer con {item}?"
L["POPUP_KEEP_OR_TRADE_FMT"] = "¿Qué quieres hacer con %s?"
L["POPUP_REANNOUNCE"] = "¿Re-anunciar todos los objetos al grupo?"
L["POPUP_REANNOUNCE_TITLE"] = "Re-anunciar Objetos"
L["POPUP_RENAME_SET"] = "Introduce un nuevo nombre para el conjunto:"
L["POPUP_RESET_ALL_SETS"] = "¿Restablecer TODOS los conjuntos de respuestas a predeterminados? Esto no se puede deshacer."
L["POPUP_SKIP_ITEM"] = "¿Saltar {item} sin otorgarlo?"
L["POPUP_SKIP_ITEM_FMT"] = "¿Saltar %s sin otorgarlo?"
L["POPUP_START_SESSION"] = "¿Iniciar sesión de botín para {boss}?"
L["POPUP_START_SESSION_FMT"] = "¿Iniciar sesión de botín para %s?"
L["POPUP_START_SESSION_GENERIC"] = "¿Iniciar sesión de botín?"
L["POPUP_OVERWRITE_PROFILE"] = "Esto sobrescribirá la configuración de tu perfil actual. ¿Continuar?"
L["POPUP_OVERWRITE_PROFILE_TITLE"] = "Sobrescribir Perfil"

-- Popups: Import
L["POPUP_IMPORT_OVERWRITE"] = "Esta importación sobrescribirá {count} entradas de historial existentes. ¿Continuar?"
L["POPUP_IMPORT_OVERWRITE_MULTI"] = "Esta importación sobrescribirá %d entradas de historial existentes. ¿Continuar?"
L["POPUP_IMPORT_OVERWRITE_SINGLE"] = "Esta importación sobrescribirá 1 entrada de historial existente. ¿Continuar?"
L["POPUP_IMPORT_SETTINGS"] = "Elige cómo aplicar la configuración importada:"
L["POPUP_IMPORT_SETTINGS_TITLE"] = "Importar Configuración"

-- Popups: Sync
L["POPUP_SYNC_GENERIC_FMT"] = "%s quiere sincronizar su %s contigo. ¿Aceptar?"
L["POPUP_SYNC_HISTORY_FMT"] = "%s quiere sincronizar su historial de botín (%d días) contigo. ¿Aceptar?"
L["POPUP_SYNC_REQUEST"] = "{player} quiere sincronizar su {type} contigo. ¿Aceptar?"
L["POPUP_SYNC_REQUEST_TITLE"] = "Solicitud de Sincronización"
L["POPUP_SYNC_SETTINGS_FMT"] = "%s quiere sincronizar su configuración de Loothing contigo. ¿Aceptar?"

-- Popups: Trade
L["POPUP_TRADE_ADD_ITEMS"] = "¿Agregar {count} objetos otorgados al intercambio con {player}?"
L["POPUP_TRADE_ADD_MULTI"] = "¿Agregar %d objetos otorgados al intercambio con %s?"
L["POPUP_TRADE_ADD_SINGLE"] = "¿Agregar 1 objeto otorgado al intercambio con %s?"

-- Sync Messages
L["SYNC_ACCEPTED_FROM"] = "Sincronización aceptada de %s"
L["SYNC_HISTORY_COMPLETED"] = "Sincronización de historial completada a %d destinatarios"
L["SYNC_HISTORY_GUILD_DAYS"] = "Solicitando sincronización de historial (%d días) a la hermandad..."
L["SYNC_HISTORY_SENT"] = "Enviadas %d entradas de historial a %s"
L["SYNC_HISTORY_TO_PLAYER"] = "Solicitando sincronización de historial (%d días) a %s"
L["SYNC_SETTINGS_APPLIED"] = "Configuración aplicada de %s"
L["SYNC_SETTINGS_COMPLETED"] = "Sincronización de configuración completada a %d destinatarios"
L["SYNC_SETTINGS_SENT"] = "Configuración enviada a %s"
L["SYNC_SETTINGS_TO_GUILD"] = "Solicitando sincronización de configuración a la hermandad..."
L["SYNC_SETTINGS_TO_PLAYER"] = "Solicitando sincronización de configuración a %s"

-- Trade Messages
L["TRADE_BTN"] = "Intercambiar"
L["TRADE_COMPLETED"] = "Intercambiado %s a %s"
L["TRADE_ITEM_LOCKED"] = "Objeto bloqueado: %s"
L["TRADE_ITEM_NOT_FOUND"] = "No se pudo encontrar el objeto para intercambiar: %s"
L["TRADE_ITEMS_PENDING"] = "Tienes %d objeto(s) para intercambiar con %s. Haz clic en los objetos para agregarlos a la ventana de intercambio."
L["TRADE_TOO_MANY_ITEMS"] = "Demasiados objetos para intercambiar - solo se agregarán los primeros 6."
L["TRADE_WINDOW_URGENT"] = "|cffff0000¡URGENTE:|r ¡La ventana de intercambio para %s (otorgado a %s) expira en %d minutos!"
L["TRADE_WINDOW_WARNING"] = "|cffff9900Advertencia:|r La ventana de intercambio para %s (otorgado a %s) expira en %d minutos!"
L["TRADE_WRONG_RECIPIENT"] = "Advertencia: Se intercambió %s a %s (fue otorgado a %s)"

-- Version Check
L["VERSION_AND_MORE"] = " y %d más"
L["VERSION_CHECK_IN_PROGRESS"] = "Verificación de versión ya en progreso"
L["VERSION_OUTDATED_MEMBERS"] = "|cffff9900%d miembro(s) del grupo tienen Loothing desactualizado:|r %s"
L["VERSION_RESULTS_CURRENT"] = "  Actualizado: %d"
L["VERSION_RESULTS_HINT"] = "Usa /lt version show para ver resultados detallados"
L["VERSION_RESULTS_NOT_INSTALLED"] = "  |cff888888No Instalado: %d|r"
L["VERSION_RESULTS_OUTDATED"] = "  |cffff0000Desactualizado: %d|r"
L["VERSION_RESULTS_TEST"] = "  |cff00ff00Versiones de prueba: %d|r"
L["VERSION_RESULTS_TOTAL"] = "Resultados de Verificación de Versión: %d total"

-- Profile Broadcast
L["PROFILE_SHARE_BROADCAST_BUTTON"] = "Transmitir al Grupo"
L["PROFILE_SHARE_BROADCAST_DESC"] = "Transmitir la cadena de exportación actual a la banda o grupo activo. Solo el Maestro Despojador de la sesión activa puede hacer esto."
L["PROFILE_SHARE_BROADCAST_SENT"] = "Perfil actual transmitido al grupo activo."
L["PROFILE_SHARE_BROADCAST_CONFIRM"] = "¿Transmitir tu perfil de configuración actual a todo el grupo activo?"
L["PROFILE_SHARE_BROADCAST_NO_SESSION"] = "Necesitas una sesión activa de Loothing para transmitir la configuración."
L["PROFILE_SHARE_BROADCAST_NOT_ML"] = "Solo el Maestro Despojador de la sesión activa puede transmitir la configuración."
L["PROFILE_SHARE_BROADCAST_BUSY"] = "La cola de comunicación del addon está ocupada. Inténtalo de nuevo en un momento."
L["PROFILE_SHARE_BROADCAST_COOLDOWN"] = "La configuración fue transmitida recientemente. Inténtalo de nuevo en %d segundos."
L["PROFILE_SHARE_QUEUE_FULL"] = "La configuración compartida de %s fue descartada porque otra importación ya está en espera."


-- Restored keys (accessed via Loothing.Locale)
L["SESSION_STARTED"] = "Sesión de consejo de botín iniciada para %s"
L["SESSION_ENDED"] = "Sesión de consejo de botín finalizada"
L["AWARD_TO"] = "Otorgar a %s"
L["TOTAL_VOTES"] = "Total: %d votos"
L["LOOTED_BY"] = "Obtenido por: %s"
L["ENTRIES_COUNT"] = "Total: %d entradas"
L["ENTRIES_FILTERED"] = "Mostrando: %d de %d entradas"
L["AWARDED_TO"] = "Otorgado a: %s"
L["FROM_ENCOUNTER"] = "De: %s"
L["WITH_VOTES"] = "Votos: %d"
L["TAB_SETTINGS"] = "Configuración"
L["SELECT_AWARD_REASON"] = "Seleccionar Motivo de Otorgamiento"
L["NO_SELECTION"] = "Sin selección"
L["YOUR_RANKING"] = "Tu Clasificación"
L["AWARD_NO_REASON"] = "Otorgar (Sin Motivo)"
L["CLEARED_TRADES"] = "Se borraron %d intercambio(s) completado(s)"
L["NO_COMPLETED_TRADES"] = "No hay intercambios completados para borrar"
L["OBSERVE_MODE_MSG"] = "Estás en modo observador y no puedes votar."
L["VOTE_NOTE_REQUIRED"] = "Debes añadir una nota con tu voto."
L["SELF_VOTE_DISABLED"] = "La autovotación está desactivada para esta sesión."



-- Voting States
L["VOTING_STATE_PENDING"] = "Pendiente"
L["VOTING_STATE_VOTING"] = "Votación"
L["VOTING_STATE_TALLYING"] = "Contabilizando"
L["VOTING_STATE_DECIDED"] = "Decidido"
L["VOTING_STATE_REVOTING"] = "Re-Votando"

-- Enchanter/Disenchant
L["NO_ENCHANTERS"] = "No se detectaron encantadores en el grupo"
L["DISENCHANT_TARGET_SET"] = "Objetivo de desencantar establecido en: %s"
L["DISENCHANT_TARGET_CLEARED"] = "Objetivo de desencantar eliminado"
