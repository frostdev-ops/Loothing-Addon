--[[--------------------------------------------------------------------
    Loothing - Loot Council Addon for WoW 12.0+
    Init - Addon initialization and namespace
----------------------------------------------------------------------]]

local Loolib = LibStub("Loolib")

--[[--------------------------------------------------------------------
    Addon Namespace
----------------------------------------------------------------------]]

Loothing = Loothing or {}
Loothing.version = LOOTHING_VERSION
Loothing.initialized = false

-- Module references (populated during init)
Loothing.Settings = nil
Loothing.ResponseManager = nil
Loothing.RollTracker = nil
Loothing.Session = nil
Loothing.Council = nil
Loothing.Comm = nil
Loothing.History = nil
Loothing.TradeQueue = nil
Loothing.UI = nil

-- Localization shortcut
local L = LOOTHING_LOCALE

--[[--------------------------------------------------------------------
    Static Popup Dialogs
----------------------------------------------------------------------]]

StaticPopupDialogs["LOOTHING_ACCEPT_SETTINGS_SYNC"] = {
    text = "%s wants to sync their Loothing settings to you. Accept?",
    button1 = "Accept",
    button2 = "Decline",
    OnAccept = function(self, data)
        if data and data.onAccept then
            data.onAccept()
        end
    end,
    timeout = 60,
    whileDead = true,
    hideOnEscape = true,
}

StaticPopupDialogs["LOOTHING_ACCEPT_HISTORY_SYNC"] = {
    text = "%s wants to sync their loot history (%s days) to you. Accept?",
    button1 = "Accept",
    button2 = "Decline",
    OnAccept = function(self, data)
        if data and data.onAccept then
            data.onAccept()
        end
    end,
    timeout = 60,
    whileDead = true,
    hideOnEscape = true,
}

--[[--------------------------------------------------------------------
    Event Frame
----------------------------------------------------------------------]]

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("PLAYER_LOGOUT")

--[[--------------------------------------------------------------------
    Initialization
----------------------------------------------------------------------]]

local function InitializeModules()
    -- Get loolib modules
    local Events = Loolib:GetModule("Events")
    local Data = Loolib:GetModule("Data")
    local UI = Loolib:GetModule("UI")

    -- Store loolib references
    Loothing.Loolib = {
        Events = Events,
        Data = Data,
        UI = UI,
    }

    -- Initialize settings (must be first - other modules depend on it)
    if LoothingSettingsMixin then
        Loothing.Settings = LoolibCreateFromMixins(LoothingSettingsMixin)
        Loothing.Settings:Init()
    end

    -- Initialize response manager
    if CreateLoothingResponseManager then
        Loothing.ResponseManager = CreateLoothingResponseManager()
        Loothing.ResponseManager:LoadResponses()
    end

    -- Initialize roll tracker
    if CreateLoothingRollTracker then
        Loothing.RollTracker = CreateLoothingRollTracker()
    end

    -- Initialize history
    if LoothingHistoryMixin then
        Loothing.History = LoolibCreateFromMixins(LoothingHistoryMixin)
        Loothing.History:Init()
    end

    -- Initialize trade queue
    if CreateLoothingTradeQueue then
        Loothing.TradeQueue = CreateLoothingTradeQueue()
    end

    -- Initialize council manager
    if LoothingCouncilMixin then
        Loothing.Council = LoolibCreateFromMixins(LoothingCouncilMixin)
        Loothing.Council:Init()
    end

    -- Initialize communication
    if LoothingCommMixin then
        Loothing.Comm = LoolibCreateFromMixins(LoothingCommMixin)
        Loothing.Comm:Init()
    end

    -- Initialize sync handler
    if LoothingSyncMixin then
        Loothing.Sync = LoolibCreateFromMixins(LoothingSyncMixin)
        Loothing.Sync:Init()
    end

    -- Initialize session manager
    if LoothingSessionMixin then
        Loothing.Session = LoolibCreateFromMixins(LoothingSessionMixin)
        Loothing.Session:Init()
    end

    -- Initialize voting engine (singleton, not a mixin)
    if LoothingVotingEngine then
        Loothing.VotingEngine = LoothingVotingEngine
    end

    -- Initialize UI last (depends on all other modules)
    if LoothingMainFrameMixin then
        Loothing.MainFrame = CreateLoothingMainFrame()
    end
end

local function RegisterEvents()
    local Events = Loothing.Loolib.Events
    if not Events or not Events.Registry then return end

    -- Raid events
    Events.Registry:RegisterEventCallback("GROUP_ROSTER_UPDATE", function()
        if Loothing.Council then
            Loothing.Council:OnRosterUpdate()
        end
        if Loothing.Session then
            Loothing.Session:OnRosterUpdate()
        end
    end, Loothing)

    -- Encounter events
    Events.Registry:RegisterEventCallback("ENCOUNTER_START", function(encounterID, encounterName, difficultyID, groupSize)
        if Loothing.Session then
            Loothing.Session:OnEncounterStart(encounterID, encounterName, difficultyID, groupSize)
        end
    end, Loothing)

    Events.Registry:RegisterEventCallback("ENCOUNTER_END", function(encounterID, encounterName, difficultyID, groupSize, success)
        if Loothing.Session then
            Loothing.Session:OnEncounterEnd(encounterID, encounterName, difficultyID, groupSize, success)
        end
    end, Loothing)

    Events.Registry:RegisterEventCallback("BOSS_KILL", function(encounterID, encounterName)
        if Loothing.Session then
            Loothing.Session:OnBossKill(encounterID, encounterName)
        end
    end, Loothing)

    -- Loot events
    Events.Registry:RegisterEventCallback("ENCOUNTER_LOOT_RECEIVED", function(encounterID, itemID, itemLink, quantity, playerName, className)
        if Loothing.Session then
            Loothing.Session:OnLootReceived(encounterID, itemID, itemLink, quantity, playerName, className)
        end
    end, Loothing)

    -- Addon communication
    Events.Registry:RegisterEventCallback("CHAT_MSG_ADDON", function(prefix, message, channel, sender)
        if prefix == LOOTHING_ADDON_PREFIX and Loothing.Comm then
            Loothing.Comm:OnMessage(message, channel, sender)
        end
    end, Loothing)

    -- Roll tracking
    Events.Registry:RegisterEventCallback("CHAT_MSG_SYSTEM", function(text)
        if Loothing.RollTracker then
            Loothing.RollTracker:OnChatMessage(text)
        end
    end, Loothing)

    -- Trade window events (handled internally by TradeQueue)
    Events.Registry:RegisterEventCallback("TRADE_SHOW", function()
        -- TradeQueue handles this internally
    end, Loothing)

    Events.Registry:RegisterEventCallback("TRADE_CLOSED", function()
        -- TradeQueue handles this internally
    end, Loothing)

    Events.Registry:RegisterEventCallback("TRADE_ACCEPT_UPDATE", function(playerAccepted, targetAccepted)
        -- TradeQueue handles this internally
    end, Loothing)

    Events.Registry:RegisterEventCallback("UI_INFO_MESSAGE", function(messageType, message)
        -- TradeQueue handles this internally
    end, Loothing)
end

local function RegisterSlashCommands()
    SLASH_LOOTHING1 = "/loothing"
    SLASH_LOOTHING2 = "/lt"

    SlashCmdList["LOOTHING"] = function(msg)
        local cmd, args = msg:match("^(%S*)%s*(.*)$")
        cmd = cmd:lower()

        if cmd == "" or cmd == "show" then
            if Loothing.MainFrame then
                Loothing.MainFrame:Show()
            end
        elseif cmd == "hide" then
            if Loothing.MainFrame then
                Loothing.MainFrame:Hide()
            end
        elseif cmd == "toggle" then
            if Loothing.MainFrame then
                if Loothing.MainFrame:IsShown() then
                    Loothing.MainFrame:Hide()
                else
                    Loothing.MainFrame:Show()
                end
            end
        elseif cmd == "config" or cmd == "settings" then
            if Loothing.MainFrame then
                Loothing.MainFrame:Show()
                Loothing.MainFrame:SelectTab("settings")
            end
        elseif cmd == "history" then
            if Loothing.MainFrame then
                Loothing.MainFrame:Show()
                Loothing.MainFrame:SelectTab("history")
            end
        elseif cmd == "council" then
            if Loothing.MainFrame then
                Loothing.MainFrame:Show()
                Loothing.MainFrame:SelectTab("settings")
            end
        elseif cmd == "test" then
            -- Test mode commands
            if LoothingTestMode then
                LoothingTestMode:HandleCommand(args or "")
            else
                print("|cffff0000[Loothing]|r Test mode not available.")
            end
        elseif cmd == "help" then
            print(L["SLASH_HELP"])
            print("  /lt test - Toggle test mode (for development)")
        elseif cmd == "debug" then
            Loothing.debug = not Loothing.debug
            print("Loothing debug mode:", Loothing.debug and "ON" or "OFF")
        elseif cmd == "sync" then
            -- /lt sync settings guild
            -- /lt sync history guild 7
            local subCmd, target, days = args:match("^(%S*)%s*(%S*)%s*(%S*)$")
            subCmd = subCmd and subCmd:lower() or ""

            if subCmd == "settings" then
                if not target or target == "" then
                    target = "guild"
                end
                if Loothing.Sync then
                    Loothing.Sync:RequestSettingsSync(target)
                else
                    print("|cffff0000[Loothing]|r Sync module not available")
                end
            elseif subCmd == "history" then
                if not target or target == "" then
                    target = "guild"
                end
                local numDays = tonumber(days) or 7
                if Loothing.Sync then
                    Loothing.Sync:RequestHistorySync(target, numDays)
                else
                    print("|cffff0000[Loothing]|r Sync module not available")
                end
            else
                print("Sync commands:")
                print("  /lt sync settings [guild|playername] - Sync settings")
                print("  /lt sync history [guild|playername] [days] - Sync history")
            end
        else
            print(L["SLASH_HELP"])
        end
    end
end

--[[--------------------------------------------------------------------
    Event Handlers
----------------------------------------------------------------------]]

eventFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" then
        local addonName = ...
        if addonName == "Loothing" then
            -- Register addon message prefix
            local result = C_ChatInfo.RegisterAddonMessagePrefix(LOOTHING_ADDON_PREFIX)
            if result ~= Enum.RegisterAddonMessagePrefixResult.Success then
                print("Loothing: Failed to register addon message prefix")
            end

            -- Initialize all modules
            InitializeModules()

            -- Register slash commands
            RegisterSlashCommands()

            Loothing.initialized = true
        end
    elseif event == "PLAYER_LOGIN" then
        if Loothing.initialized then
            -- Register for game events after login
            RegisterEvents()

            -- Load trade queue from SavedVariables
            if Loothing.TradeQueue then
                Loothing.TradeQueue:LoadFromDatabase()
            end

            -- Print loaded message
            print(string.format(L["ADDON_LOADED"], LOOTHING_VERSION))
        end
    elseif event == "PLAYER_LOGOUT" then
        -- Save any pending data
        if Loothing.Settings then
            Loothing.Settings:Save()
        end
    end
end)

--[[--------------------------------------------------------------------
    Debug Utilities
----------------------------------------------------------------------]]

Loothing.debug = false

function Loothing:Debug(...)
    if self.debug then
        print("|cff00ff00[Loothing Debug]|r", ...)
    end
end

function Loothing:Error(...)
    print("|cffff0000[Loothing Error]|r", ...)
end

function Loothing:Print(...)
    print("|cff00ccff[Loothing]|r", ...)
end

--[[--------------------------------------------------------------------
    Public API
----------------------------------------------------------------------]]

--- Check if the addon is ready
-- @return boolean
function Loothing:IsReady()
    return self.initialized
end

--- Get current session
-- @return table|nil
function Loothing:GetSession()
    return self.Session
end

--- Get council manager
-- @return table|nil
function Loothing:GetCouncil()
    return self.Council
end

--- Get settings
-- @return table|nil
function Loothing:GetSettings()
    return self.Settings
end

--- Toggle main window
function Loothing:Toggle()
    if self.MainFrame then
        if self.MainFrame:IsShown() then
            self.MainFrame:Hide()
        else
            self.MainFrame:Show()
        end
    end
end
