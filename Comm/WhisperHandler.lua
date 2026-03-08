--[[--------------------------------------------------------------------
    Loothing - Loot Council Addon for WoW 12.0+
    WhisperHandler - Process whisper commands from raid members

    When ML is handling loot, raid members can whisper response keywords
    (e.g., !need, !greed, !pass) to submit their response without the
    addon UI. The ML auto-responds with confirmation.
----------------------------------------------------------------------]]

local Loolib = LibStub("Loolib")

--[[--------------------------------------------------------------------
    LoothingWhisperHandlerMixin
----------------------------------------------------------------------]]

LoothingWhisperHandlerMixin = {}

local L = LOOTHING_LOCALE

-- Frame used to listen for CHAT_MSG_WHISPER
local whisperFrame = nil

-- Track outgoing whispers to filter from chat frame
local outgoingWhispers = {}

--- Initialize the whisper handler
function LoothingWhisperHandlerMixin:Init()
    self.enabled = false
    self.chatFilterRegistered = false
end

--- Enable whisper command processing (called when ML starts handling loot)
function LoothingWhisperHandlerMixin:Enable()
    if self.enabled then return end

    self.enabled = true

    -- Create event frame if needed
    if not whisperFrame then
        whisperFrame = CreateFrame("Frame")
    end

    whisperFrame:RegisterEvent("CHAT_MSG_WHISPER")
    whisperFrame:SetScript("OnEvent", function(_, event, message, sender, ...)
        if event == "CHAT_MSG_WHISPER" then
            self:OnWhisperReceived(message, sender)
        end
    end)

    -- Register chat filter to suppress outgoing confirmation whispers
    if not self.chatFilterRegistered then
        ChatFrame_AddMessageEventFilter("CHAT_MSG_WHISPER_INFORM", function(_, _, message, ...)
            return self:FilterOutgoingWhisper(message)
        end)
        self.chatFilterRegistered = true
    end

    Loothing:Debug("WhisperHandler enabled")
end

--- Disable whisper command processing (called when ML stops handling loot)
function LoothingWhisperHandlerMixin:Disable()
    if not self.enabled then return end

    self.enabled = false

    if whisperFrame then
        whisperFrame:UnregisterEvent("CHAT_MSG_WHISPER")
    end

    wipe(outgoingWhispers)

    Loothing:Debug("WhisperHandler disabled")
end

--[[--------------------------------------------------------------------
    Whisper Processing
----------------------------------------------------------------------]]

--- Handle an incoming whisper message
-- @param message string - Whisper text
-- @param sender string - Sender name (may include realm)
function LoothingWhisperHandlerMixin:OnWhisperReceived(message, sender)
    if not self.enabled then return end

    -- Only process if we're the ML and handling loot
    if not Loothing.isMasterLooter or not Loothing.handleLoot then
        return
    end

    -- Trim whitespace and normalize
    message = strtrim(message)

    -- Must start with ! to be a command
    if message:sub(1, 1) ~= "!" then
        return
    end

    local normalizedSender = LoothingUtils.NormalizeName(sender)

    -- Validate sender is in our group/raid before processing
    local roster = LoothingUtils.GetRaidRoster and LoothingUtils.GetRaidRoster()
    if roster then
        local found = false
        for _, member in ipairs(roster) do
            if LoothingUtils.IsSamePlayer(member.name, normalizedSender) then
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
    if not Loothing.Session or Loothing.Session:GetState() == LOOTHING_SESSION_STATE.INACTIVE then
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
    local itemName = LoothingUtils.GetItemName(targetItem.itemLink) or "item"
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
function LoothingWhisperHandlerMixin:ParseCommand(message)
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
-- @return number|nil responseID - LOOTHING_RESPONSE value or button ID
-- @return string|nil responseName - Display name
function LoothingWhisperHandlerMixin:MatchCommand(command)
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

    -- Check each button for whisperKey match or text match
    for _, button in ipairs(buttons) do
        -- Check explicit whisperKey on button (if set)
        if button.whisperKey then
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
    for id, info in pairs(LOOTHING_RESPONSE_INFO) do
        if info.name and info.name:lower() == command then
            return id, info.name
        end
    end

    return nil
end

--- Get the active button set's buttons
-- @return table|nil - Array of button definitions
function LoothingWhisperHandlerMixin:GetActiveButtons()
    if not Loothing.Settings then return nil end

    local settings = Loothing.Settings:Get("buttonSets")
    if not settings or not settings.sets then return nil end

    local activeIdx = settings.activeSet or 1
    local activeSet = settings.sets[activeIdx]
    if not activeSet then return nil end

    return activeSet.buttons
end

--- Find the target item for a whisper response
-- @param itemNum number|nil - Optional item number (1-based)
-- @return table|nil item - Session item data
-- @return number|nil index - 1-based item index among voting items
function LoothingWhisperHandlerMixin:FindTargetItem(itemNum)
    if not Loothing.Session then return nil end

    local items = Loothing.Session:GetItems()
    if not items then return nil end

    -- Collect voting items
    local votingItems = {}
    for _, item in items:Enumerate() do
        if item:GetState() == LOOTHING_ITEM_STATE.VOTING then
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
function LoothingWhisperHandlerMixin:GetVotingItemCount()
    if not Loothing.Session then return 0 end

    local items = Loothing.Session:GetItems()
    if not items then return 0 end

    local count = 0
    for _, item in items:Enumerate() do
        if item:GetState() == LOOTHING_ITEM_STATE.VOTING then
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
function LoothingWhisperHandlerMixin:SubmitWhisperResponse(item, playerName, responseID, itemIndex)
    if not Loothing.Session then return end

    -- Create a response payload matching the PlayerResponse format
    local payload = {
        itemGUID = item.guid,
        response = responseID,
        note = nil,
        roll = nil,
        rollMin = 1,
        rollMax = 100,
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
function LoothingWhisperHandlerMixin:SendWhisper(target, message)
    if not target or not message then return end

    -- Mark for filtering before sending
    outgoingWhispers[message] = true

    -- Schedule cleanup after a short delay
    C_Timer.After(2, function()
        outgoingWhispers[message] = nil
    end)

    SendChatMessage(message, "WHISPER", nil, target)
end

--- Send help listing available commands
-- @param target string - Player name
function LoothingWhisperHandlerMixin:SendHelp(target)
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
function LoothingWhisperHandlerMixin:FilterOutgoingWhisper(message)
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

function CreateLoothingWhisperHandler()
    local handler = LoolibCreateFromMixins(LoothingWhisperHandlerMixin)
    handler:Init()
    return handler
end
