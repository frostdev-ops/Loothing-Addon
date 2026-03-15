--[[--------------------------------------------------------------------
    Loothing - Loot Council Addon for WoW 12.0+
    WhisperHandler - Process whisper commands from raid members

    When ML is handling loot, raid members can whisper response keywords
    (e.g., !need, !greed, !pass) to submit their response without the
    addon UI. The ML auto-responds with confirmation.
----------------------------------------------------------------------]]

local _, ns = ...
local Loothing = ns.Addon
local Loolib = LibStub("Loolib")
local CreateFromMixins = Loolib.CreateFromMixins
local Utils = ns.Utils

ns.WhisperHandlerMixin = ns.WhisperHandlerMixin or {}

--[[--------------------------------------------------------------------
    WhisperHandlerMixin
----------------------------------------------------------------------]]

local WhisperHandlerMixin = ns.WhisperHandlerMixin

local L = Loothing.Locale
local GetTime = GetTime

-- Frame used to listen for CHAT_MSG_WHISPER
local whisperFrame = nil

-- Track outgoing whispers to filter from chat frame
local outgoingWhispers = {}

-- Per-sender rate limiting to prevent whisper-spam abuse
local whisperCooldowns = {}
local WHISPER_COOLDOWN = 2  -- seconds between accepted commands per sender

--- Initialize the whisper handler
function WhisperHandlerMixin:Init()
    self.enabled = false
    self.chatFilterRegistered = false
end

--- Enable whisper command processing (called when ML starts handling loot)
function WhisperHandlerMixin:Enable()
    if self.enabled then return end

    self.enabled = true

    -- Create event frame if needed
    if not whisperFrame then
        whisperFrame = CreateFrame("Frame")
    end

    whisperFrame:RegisterEvent("CHAT_MSG_WHISPER")
    whisperFrame:SetScript("OnEvent", function(_, event, message, sender)
        if event == "CHAT_MSG_WHISPER" then
            self:OnWhisperReceived(message, sender)
        end
    end)

    -- Register chat filter to suppress outgoing confirmation whispers
    if not self.chatFilterRegistered then
        ChatFrame_AddMessageEventFilter("CHAT_MSG_WHISPER_INFORM", function(_, _, message)
            return self:FilterOutgoingWhisper(message)
        end)
        self.chatFilterRegistered = true
    end

    Loothing:Debug("WhisperHandler enabled")
end

--- Disable whisper command processing (called when ML stops handling loot)
function WhisperHandlerMixin:Disable()
    if not self.enabled then return end

    self.enabled = false

    if whisperFrame then
        whisperFrame:UnregisterEvent("CHAT_MSG_WHISPER")
    end

    wipe(outgoingWhispers)
    wipe(whisperCooldowns)

    Loothing:Debug("WhisperHandler disabled")
end

--[[--------------------------------------------------------------------
    Whisper Processing
----------------------------------------------------------------------]]

--- Handle an incoming whisper message
-- @param message string - Whisper text
-- @param sender string - Sender name (may include realm)
function WhisperHandlerMixin:OnWhisperReceived(message, sender)
    if not self.enabled then return end

    -- Only process if we're the ML and handling loot
    if not Loothing.isMasterLooter or not Loothing.handleLoot then
        return
    end

    -- Detaint event payload strings for combat safety
    message = tostring(message)
    sender = tostring(sender)

    -- Trim whitespace and normalize
    message = strtrim(message)

    -- Must start with ! to be a command
    if message:sub(1, 1) ~= "!" then
        return
    end

    local normalizedSender = Utils.NormalizeName(sender)

    -- Per-sender rate limiting
    local now = GetTime()
    if whisperCooldowns[normalizedSender] and now - whisperCooldowns[normalizedSender] < WHISPER_COOLDOWN then
        return
    end
    whisperCooldowns[normalizedSender] = now

    -- Validate sender is in our group/raid before processing
    local roster = Utils.GetRaidRoster and Utils.GetRaidRoster()
    if roster then
        local found = false
        for _, member in ipairs(roster) do
            if Utils.IsSamePlayer(member.name, normalizedSender) then
                found = true
                break
            end
        end
        if not found then
            Loothing:Debug("WhisperHandler: ignoring whisper from non-group member", normalizedSender)
            return
        end
    end

    -- Parse command and optional item number
    local command, itemNum = self:ParseCommand(message)
    if not command then return end

    -- Handle !help
    if command == "help" then
        self:SendHelp(normalizedSender)
        return
    end

    -- Check for active session
    if not Loothing.Session or Loothing.Session:GetState() == Loothing.SessionState.INACTIVE then
        self:SendWhisper(normalizedSender, L["WHISPER_NO_SESSION"])
        return
    end

    -- Match command to a button response
    local responseID, responseName = self:MatchCommand(command)
    if not responseID then
        self:SendWhisper(normalizedSender, string.format(L["WHISPER_UNKNOWN_COMMAND"], "!" .. command))
        return
    end

    -- Find the target item (first voting item, or specified by number)
    local targetItem, itemIndex = self:FindTargetItem(itemNum)
    if not targetItem then
        if itemNum and itemNum > 0 then
            local votingCount = self:GetVotingItemCount()
            self:SendWhisper(normalizedSender, string.format(L["WHISPER_INVALID_ITEM_NUM"], itemNum, votingCount))
        else
            self:SendWhisper(normalizedSender, L["WHISPER_NO_VOTING_ITEMS"])
        end
        return
    end

    -- Submit the response on behalf of the whisper sender
    self:SubmitWhisperResponse(targetItem, normalizedSender, responseID, itemIndex)

    -- Send confirmation
    if itemNum then
        self:SendWhisper(normalizedSender, string.format(L["WHISPER_ITEM_SPECIFIED"], responseName, targetItem.itemLink, itemIndex))
    else
        self:SendWhisper(normalizedSender, string.format(L["WHISPER_RESPONSE_RECEIVED"], responseName, targetItem.itemLink))
    end
end

--- Parse a whisper command string
-- Supports: "!need", "!need 2", "!1", "!2" (button number), "!pass"
-- @param message string - Full whisper message starting with !
-- @return string|nil command - Lowercased command name
-- @return number|nil itemNum - Optional item number
function WhisperHandlerMixin:ParseCommand(message)
    -- Remove the ! prefix
    local text = message:sub(2)
    if text == "" then return nil end

    -- Split by space: "need 2" -> {"need", "2"}
    local parts = {}
    for part in text:gmatch("%S+") do
        parts[#parts + 1] = part
    end

    local command = parts[1]:lower()
    local itemNum = nil

    if parts[2] then
        itemNum = tonumber(parts[2])
    end

    return command, itemNum
end

--- Match a command string to a response button
-- Checks: button whisperKeys, button text (lowered), button sort index ("!1", "!2", etc.)
-- @param command string - Lowercased command
-- @return number|nil responseID - Loothing.Response value or button ID
-- @return string|nil responseName - Display name
function WhisperHandlerMixin:MatchCommand(command)
    -- Get the active button set
    local buttons = self:GetActiveButtons()
    if not buttons then return nil end

    -- Check if command is a number (e.g., "1" -> first button)
    local numCmd = tonumber(command)
    if numCmd then
        for _, button in ipairs(buttons) do
            if button.sort == numCmd or button.id == numCmd then
                return button.id, button.text
            end
        end
        return nil
    end

    -- Check each button for whisperKeys array or text match
    for _, button in ipairs(buttons) do
        -- Check per-button whisperKeys array
        if button.whisperKeys and type(button.whisperKeys) == "table" then
            for _, key in ipairs(button.whisperKeys) do
                local k = key:lower():gsub("^!", "")
                if k == command then
                    return button.id, button.text
                end
            end
        -- Fallback: legacy single whisperKey string
        elseif button.whisperKey then
            local key = button.whisperKey:lower():gsub("^!", "")
            if key == command then
                return button.id, button.text
            end
        end

        -- Check button text (lowered)
        if button.text and button.text:lower() == command then
            return button.id, button.text
        end
    end

    -- Also check built-in response names
    for id, info in pairs(Loothing.ResponseInfo) do
        if info.name and info.name:lower() == command then
            return id, info.name
        end
    end

    return nil
end

--- Get the active response set's buttons
-- @return table|nil - Array of button definitions
function WhisperHandlerMixin:GetActiveButtons()
    if not Loothing.Settings then return nil end
    local buttons = Loothing.Settings:GetResponseButtons()
    return #buttons > 0 and buttons or nil
end

--- Find the target item for a whisper response
-- @param itemNum number|nil - Optional item number (1-based)
-- @return table|nil item - Session item data
-- @return number|nil index - 1-based item index among voting items
function WhisperHandlerMixin:FindTargetItem(itemNum)
    if not Loothing.Session then return nil end

    local items = Loothing.Session:GetItems()
    if not items then return nil end

    -- Collect voting items
    local votingItems = {}
    for _, item in items:Enumerate() do
        if item:GetState() == Loothing.ItemState.VOTING then
            votingItems[#votingItems + 1] = item
        end
    end

    if #votingItems == 0 then return nil end

    if itemNum then
        if itemNum >= 1 and itemNum <= #votingItems then
            return votingItems[itemNum], itemNum
        end
        return nil
    end

    -- Default: first voting item
    return votingItems[1], 1
end

--- Get count of items currently in voting state
-- @return number
function WhisperHandlerMixin:GetVotingItemCount()
    if not Loothing.Session then return 0 end

    local items = Loothing.Session:GetItems()
    if not items then return 0 end

    local count = 0
    for _, item in items:Enumerate() do
        if item:GetState() == Loothing.ItemState.VOTING then
            count = count + 1
        end
    end

    return count
end

--- Submit a response for a player via whisper
-- @param item table - Session item
-- @param playerName string - Normalized player name
-- @param responseID number - Response/button ID
-- @param itemIndex number - Index among voting items
function WhisperHandlerMixin:SubmitWhisperResponse(item, playerName, responseID, _itemIndex)
    if not Loothing.Session then return end

    -- Generate a silent roll for the whisper response
    local rollSettings = Loothing.Settings and Loothing.Settings:Get("rollFrame.rollRange")
    local whisperRollMin = rollSettings and rollSettings.min or 1
    local whisperRollMax = rollSettings and rollSettings.max or 100

    -- Create a response payload matching the PlayerResponse format
    local payload = {
        itemGUID = item.guid,
        response = responseID,
        note = nil,
        roll = math.random(whisperRollMin, whisperRollMax),
        rollMin = whisperRollMin,
        rollMax = whisperRollMax,
        playerName = playerName,
        sessionID = Loothing.Session and Loothing.Session:GetSessionID() or nil,
        source = "whisper",
    }

    -- Route through the session's response handler
    if Loothing.Session.HandlePlayerResponse then
        Loothing.Session:HandlePlayerResponse(payload)
    end

    Loothing:Debug("Whisper response:", playerName, "->", responseID, "for item", item.guid)
end

--[[--------------------------------------------------------------------
    Whisper Sending & Filtering
----------------------------------------------------------------------]]

--- Send a whisper to a player and mark it for chat filtering
-- @param target string - Player name
-- @param message string - Message text
function WhisperHandlerMixin:SendWhisper(target, message)
    if not target or not message then return end

    -- Mark for filtering before sending
    outgoingWhispers[message] = true

    -- Schedule cleanup after a short delay
    C_Timer.After(2, function()
        outgoingWhispers[message] = nil
    end)

    C_ChatInfo.SendChatMessage(message, "WHISPER", nil, target)
end

--- Send help listing available commands
-- @param target string - Player name
function WhisperHandlerMixin:SendHelp(target)
    self:SendWhisper(target, L["WHISPER_HELP_HEADER"])

    local buttons = self:GetActiveButtons()
    if buttons then
        for _, button in ipairs(buttons) do
            local key = "!" .. button.text:lower()
            if button.whisperKey then
                key = button.whisperKey:lower()
                if key:sub(1, 1) ~= "!" then
                    key = "!" .. key
                end
            end
            self:SendWhisper(target, string.format(L["WHISPER_HELP_LINE"], key, button.text))
        end
    end
end

--- Filter outgoing Loothing confirmation whispers from the chat frame
-- @param message string - Outgoing whisper text
-- @return boolean - True to suppress the message
function WhisperHandlerMixin:FilterOutgoingWhisper(message)
    if not message then return false end

    -- Check if this is one of our outgoing whispers
    if outgoingWhispers[message] then
        return true  -- Suppress from chat frame
    end

    return false
end

--[[--------------------------------------------------------------------
    Factory
----------------------------------------------------------------------]]

function ns.CreateWhisperHandler()
    local handler = CreateFromMixins(WhisperHandlerMixin)
    handler:Init()
    return handler
end

-- ns.WhisperHandlerMixin and ns.CreateWhisperHandler exported above
