--[[--------------------------------------------------------------------
    Loothing - Loot Council Addon for WoW 12.0+
    Announcer - Multi-channel announcement system
----------------------------------------------------------------------]]

local Loolib = LibStub("Loolib")
local CreateFromMixins = Loolib.CreateFromMixins
local Events = Loolib.Events

--[[--------------------------------------------------------------------
    LoothingAnnouncerMixin
----------------------------------------------------------------------]]

LoothingAnnouncerMixin = {}

-- Valid chat channels for announcements
local CHANNELS = {
    RAID = "RAID",
    RAID_WARNING = "RAID_WARNING",
    OFFICER = "OFFICER",
    GUILD = "GUILD",
    PARTY = "PARTY",
    SAY = "SAY",
    YELL = "YELL",
    WHISPER = "WHISPER",
    NONE = nil,
}

-- Alias for "group" - resolves to RAID or PARTY based on current group type
local GROUP_CHANNEL_ALIAS = "group"

-- All supported replacement tokens
-- {item} = Item link
-- {winner} = Winner name (short)
-- {reason} = Response/award reason
-- {notes} = Player notes
-- {ilvl} = Item level
-- {type} = Item type/slot
-- {oldItem} = Player's current equipped item
-- {ml} = Master Looter name
-- {session} = Session/encounter name
-- {votes} = Number of votes received
local SUPPORTED_TOKENS = {
    "item", "winner", "reason", "notes", "ilvl", "type",
    "oldItem", "ml", "session", "votes"
}

--- Initialize the announcer
function LoothingAnnouncerMixin:Init()
    -- Queue for announcements blocked by combat/encounter restrictions
    self.announcementQueue = {}

    -- Register for combat end to flush queued announcements
    if Events and Events.Registry then
        Events.Registry:RegisterEventCallback("PLAYER_REGEN_ENABLED", function()
            self:ProcessQueuedAnnouncements()
        end, self)
    end

    -- Also listen for addon restriction lift if Restrictions module is available
    if Loothing and Loothing.Restrictions and Loothing.Restrictions.RegisterCallback then
        Loothing.Restrictions:RegisterCallback("OnRestrictionChanged", function(_, isRestricted)
            if not isRestricted then
                self:ProcessQueuedAnnouncements()
            end
        end, self)
    end
end

--- Build a full replacement table with all possible tokens
-- @param params table - Partial params
-- @return table - Full params with defaults
function LoothingAnnouncerMixin:BuildReplacements(params)
    local replacements = {}

    -- Item info
    replacements.item = params.itemLink or params.item or ""
    replacements.ilvl = params.itemLevel or params.ilvl or ""
    replacements.type = params.itemType or params.type or ""

    -- Winner info
    replacements.winner = params.winner or ""
    if replacements.winner ~= "" then
        replacements.winner = LoothingUtils.GetShortName(replacements.winner) or replacements.winner
    end

    -- Response/reason
    local reason = params.reason or ""
    if Loothing.ResponseManager and reason ~= "" then
        local responseInfo = Loothing.ResponseManager:GetResponseByName(reason)
        if responseInfo then
            reason = responseInfo.name
        end
    end
    replacements.reason = reason

    -- Notes
    replacements.notes = params.notes or ""

    -- Old item (what winner currently has equipped)
    replacements.oldItem = params.oldItem or ""

    -- Master Looter
    -- FIX(Area4-4): Use SafeUnitName to avoid secret value tainting
    replacements.ml = params.ml or Loolib.SecretUtil.SafeUnitName("player") or ""
    replacements.ml = LoothingUtils.GetShortName(replacements.ml) or replacements.ml

    -- Session/encounter name
    replacements.session = params.session or params.encounterName or ""

    -- Votes
    replacements.votes = tostring(params.votes or 0)

    return replacements
end

--- Announce an item award using multi-line configuration
-- @param itemLink string - Item link
-- @param winner string - Winner name
-- @param reason string - Response reason
-- @param extraParams table - Optional extra params (notes, votes, oldItem, etc.)
function LoothingAnnouncerMixin:AnnounceAward(itemLink, winner, reason, extraParams)
    if not Loothing.Settings or not Loothing.Settings:GetAnnounceAwards() then
        return
    end

    extraParams = extraParams or {}

    -- Build full replacement table
    local replacements = self:BuildReplacements({
        itemLink = itemLink,
        winner = winner,
        reason = reason,
        notes = extraParams.notes,
        itemLevel = extraParams.itemLevel,
        itemType = extraParams.itemType,
        oldItem = extraParams.oldItem,
        votes = extraParams.votes,
        session = extraParams.session,
        ml = extraParams.ml,
    })

    -- Get award lines configuration
    local awardLines = Loothing.Settings:GetAwardLines()

    if awardLines and #awardLines > 0 then
        -- New multi-line system
        for i, line in ipairs(awardLines) do
            if line and line.enabled and line.channel ~= "NONE" and line.text and line.text ~= "" then
                local message = self:FormatText(line.text, replacements)
                self:SendToChannel(message, line.channel)
            end
        end
    else
        -- Legacy fallback
        local template = Loothing.Settings:GetAwardText()
        local message = self:FormatText(template, replacements)

        local primaryChannel = Loothing.Settings:GetAwardChannel()
        self:SendToChannel(message, primaryChannel)

        local secondaryChannel = Loothing.Settings:GetAwardChannelSecondary()
        if secondaryChannel ~= "NONE" and secondaryChannel ~= primaryChannel then
            self:SendToChannel(message, secondaryChannel)
        end
    end
end

--- Announce a new item added to session using multi-line configuration
-- @param itemLink string - Item link
-- @param extraParams table - Optional extra params (itemLevel, itemType, session, etc.)
function LoothingAnnouncerMixin:AnnounceItem(itemLink, extraParams)
    if not Loothing.Settings or not Loothing.Settings:GetAnnounceItems() then
        return
    end

    extraParams = extraParams or {}

    -- Build full replacement table
    local replacements = self:BuildReplacements({
        itemLink = itemLink,
        itemLevel = extraParams.itemLevel,
        itemType = extraParams.itemType,
        session = extraParams.session,
        ml = extraParams.ml,
    })

    -- Get item lines configuration
    local itemLines = Loothing.Settings:GetItemLines()

    if itemLines and #itemLines > 0 then
        -- New multi-line system
        for i, line in ipairs(itemLines) do
            if line and line.enabled and line.channel ~= "NONE" and line.text and line.text ~= "" then
                local message = self:FormatText(line.text, replacements)
                self:SendToChannel(message, line.channel)
            end
        end
    else
        -- Legacy fallback
        local template = Loothing.Settings:GetItemText()
        local message = self:FormatText(template, replacements)
        local channel = Loothing.Settings:GetItemChannel()
        self:SendToChannel(message, channel)
    end
end

--- Announce that ML is considering an item (new feature)
-- @param itemLink string - Item link
-- @param extraParams table - Optional extra params
function LoothingAnnouncerMixin:AnnounceConsiderations(itemLink, extraParams)
    if not Loothing.Settings then
        return
    end

    local announcements = Loothing.Settings:Get("announcements")
    if not announcements or not announcements.announceConsiderations then
        return
    end

    extraParams = extraParams or {}

    local replacements = self:BuildReplacements({
        itemLink = itemLink,
        itemLevel = extraParams.itemLevel,
        itemType = extraParams.itemType,
        session = extraParams.session,
        ml = extraParams.ml,
    })

    local template = announcements.considerationsText or "{ml} is considering {item} for distribution"
    local channel = announcements.considerationsChannel or "RAID"

    local message = self:FormatText(template, replacements)
    self:SendToChannel(message, channel)
end

--- Announce session start
-- @param sessionName string - Optional session/encounter name
function LoothingAnnouncerMixin:AnnounceSessionStart(sessionName)
    if not Loothing.Settings or not Loothing.Settings:GetAnnounceBossKill() then
        return
    end

    local announcements = Loothing.Settings:Get("announcements")
    local template = announcements and announcements.sessionStartText or "Loot council session started"
    local channel = announcements and announcements.sessionStartChannel or "RAID"

    local replacements = self:BuildReplacements({
        session = sessionName or "Manual Session",
    })

    local message = self:FormatText(template, replacements)
    self:SendToChannel(message, channel)
end

--- Announce session end
function LoothingAnnouncerMixin:AnnounceSessionEnd()
    if not Loothing.Settings or not Loothing.Settings:GetAnnounceBossKill() then
        return
    end

    local announcements = Loothing.Settings:Get("announcements")
    local template = announcements and announcements.sessionEndText or "Loot council session ended"
    local channel = announcements and announcements.sessionEndChannel or "RAID"

    local message = self:FormatText(template, {})
    self:SendToChannel(message, channel)
end

--- Format text by replacing placeholders
-- @param template string - Template with {placeholder} tokens
-- @param replacements table - Key-value pairs for replacement
-- @return string
function LoothingAnnouncerMixin:FormatText(template, replacements)
    local result = template

    for key, value in pairs(replacements) do
        -- Convert to string and escape % characters to prevent gsub issues
        local strValue = tostring(value or "")
        local escapedValue = strValue:gsub("%%", "%%%%")
        -- Replace {key} with value
        result = result:gsub("{" .. key .. "}", escapedValue)
    end

    return result
end

--- Check if announcements should be suppressed due to combat/encounter restrictions
-- @return boolean - True if announcements should be skipped
function LoothingAnnouncerMixin:IsRestricted()
    -- Skip during encounter restrictions (addon comm restrictions active)
    if Loothing.Restrictions and Loothing.Restrictions:IsRestricted() then
        return true
    end

    -- Skip during active combat
    if UnitAffectingCombat("player") then
        return true
    end

    return false
end

--- Send message to a chat channel
-- @param text string - Message to send
-- @param channel string - Channel name (RAID, GUILD, etc.)
function LoothingAnnouncerMixin:SendToChannel(text, channel)
    if not text or text == "" then
        return
    end

    if not channel or channel == "NONE" then
        return
    end

    -- Resolve "group" alias to RAID or PARTY
    if channel:lower() == GROUP_CHANNEL_ALIAS then
        channel = IsInRaid() and "RAID" or "PARTY"
    end

    -- Validate channel
    if not CHANNELS[channel] then
        if Loothing.Logger then
            Loothing.Logger:Warn("Invalid announcement channel: " .. tostring(channel))
        end
        return
    end

    -- Check combat/encounter restrictions - queue instead of dropping
    if self:IsRestricted() then
        Loothing:Debug("Announcement queued (combat/encounter restriction):", string.sub(text, 1, 40))
        self.announcementQueue[#self.announcementQueue + 1] = { text = text, channel = channel }
        return
    end

    -- Check permissions for channel
    if not self:CanSendToChannel(channel) then
        if Loothing.Logger then
            Loothing.Logger:Warn("No permission to send to channel: " .. channel)
        end
        return
    end

    -- Send the message
    SendChatMessage(text, channel)
end

--- Check if player can send to a specific channel
-- @param channel string - Channel name
-- @return boolean
function LoothingAnnouncerMixin:CanSendToChannel(channel)
    if channel == "RAID" then
        return IsInRaid()
    elseif channel == "RAID_WARNING" then
        -- Raid warning requires raid leader or assistant
        return IsInRaid() and (UnitIsGroupLeader("player") or UnitIsGroupAssistant("player"))
    elseif channel == "OFFICER" then
        -- Officer channel requires guild rank with officer chat privilege
        return IsInGuild() and C_GuildInfo.IsGuildOfficer()
    elseif channel == "GUILD" then
        return IsInGuild()
    elseif channel == "PARTY" then
        return IsInGroup()
    elseif channel == "SAY" or channel == "YELL" then
        return true  -- Always available
    end

    return false
end

--- Process any announcements that were queued during combat/encounter restrictions
function LoothingAnnouncerMixin:ProcessQueuedAnnouncements()
    if not self.announcementQueue or #self.announcementQueue == 0 then
        return
    end

    -- Don't flush if still restricted
    if self:IsRestricted() then
        return
    end

    local queue = self.announcementQueue
    self.announcementQueue = {}

    for _, entry in ipairs(queue) do
        self:SendToChannel(entry.text, entry.channel)
    end

    Loothing:Debug("Flushed", #queue, "queued announcements")
end

--- Get list of available channels for current player
-- @return table - Array of channel names
function LoothingAnnouncerMixin:GetAvailableChannels()
    local channels = {}

    if IsInRaid() then
        channels[#channels + 1] = "RAID"
        if UnitIsGroupLeader("player") or UnitIsGroupAssistant("player") then
            channels[#channels + 1] = "RAID_WARNING"
        end
    elseif IsInGroup() then
        channels[#channels + 1] = "PARTY"
    end

    if IsInGuild() then
        channels[#channels + 1] = "GUILD"
        if C_GuildInfo.IsGuildOfficer() then
            channels[#channels + 1] = "OFFICER"
        end
    end

    channels[#channels + 1] = "NONE"

    return channels
end

--[[--------------------------------------------------------------------
    Factory
----------------------------------------------------------------------]]

function CreateLoothingAnnouncer()
    local announcer = CreateFromMixins(LoothingAnnouncerMixin)
    announcer:Init()
    return announcer
end
