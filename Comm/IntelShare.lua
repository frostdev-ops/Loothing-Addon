--[[--------------------------------------------------------------------
    Loothing - Loot Council Addon for WoW 12.0+
    IntelShare - Manual broadcast of desktop-app-synced data

    Lets users with the Tauri desktop app share player intel, trinket
    sims, droptimizer results, wishlists, and roster data with group
    or guild members who lack the desktop app.

    Uses Loothing.Comm convenience methods for all communication.
    All messages sent at BULK priority so session traffic takes precedence.
----------------------------------------------------------------------]]

local _, ns = ...
local Loolib = LibStub("Loolib")
local Loothing = ns.Addon
local L = ns.Locale
local CreateFromMixins = Loolib.CreateFromMixins
local Utils = ns.Utils

ns.IntelShareMixin = CreateFromMixins(Loolib.CallbackRegistryMixin, ns.IntelShareMixin or {})

local IntelShareMixin = ns.IntelShareMixin

--[[--------------------------------------------------------------------
    Constants
----------------------------------------------------------------------]]

local PACE_INTERVAL = 0.5       -- Seconds between dataset sends
local RECEIVE_TIMEOUT = 180     -- Seconds before discarding incomplete transfer
local SHARE_COOLDOWN = 60       -- Seconds between share initiations
local PRESSURE_YIELD = 0.5      -- Skip tick when queue pressure exceeds this

--- Ordered list of datasets to transfer (smallest first for fast initial progress)
local DATASET_ORDER = {
    "roster",       -- ~2.4 KB
    "playerIntel",  -- ~1 KB per 20 players
    "wishlists",    -- ~60 KB
    "trinketSims",  -- ~47 KB
    "droptimizer",  -- ~80 KB
}

--- Map dataset name → desktopExchange key
local EXCHANGE_KEYS = {
    roster       = "roster",
    playerIntel  = "playerIntel",
    trinketSims  = "trinketSims",
    droptimizer  = "droptimizer",
    wishlists    = "wishlists",
}

--- Map dataset name → Loothing module field (for reload after merge)
local MODULE_FIELDS = {
    roster       = "Roster",
    playerIntel  = "PlayerIntel",
    trinketSims  = "TrinketSims",
    droptimizer  = "Droptimizer",
    wishlists    = "Wishlist",
}

--- Map dataset name → timestamp field name in the exchange sub-table
local TIMESTAMP_KEYS = {
    roster       = "updatedAt",
    playerIntel  = "generatedAt",
    trinketSims  = "generatedAt",
    droptimizer  = "generatedAt",
    wishlists    = "updatedAt",
}

--- Human-readable labels for each dataset
local DATASET_LABELS = {
    roster       = "Roster",
    playerIntel  = "Player Intel",
    trinketSims  = "Trinket Sims",
    droptimizer  = "Droptimizer",
    wishlists    = "Wishlists",
}

local INTEL_SHARE_EVENTS = {
    "OnIntelShareStarted",
    "OnIntelShareProgress",
    "OnIntelShareComplete",
    "OnIntelShareFailed",
    "OnIntelReceiveStarted",
    "OnIntelReceiveProgress",
    "OnIntelReceiveComplete",
    "OnIntelReceiveFailed",
}

--[[--------------------------------------------------------------------
    Initialization
----------------------------------------------------------------------]]

function IntelShareMixin:Init()
    Loolib.CallbackRegistryMixin.OnLoad(self)
    self:GenerateCallbackEvents(INTEL_SHARE_EVENTS)

    -- Sender state
    self.activeSend = nil       -- { transferID, target, datasetIndex, ticker, startTime }
    self.lastShareTime = 0

    -- Receiver state: { [transferID] = { sender, manifest, datasets, timer } }
    self.pendingReceive = {}
end

--[[--------------------------------------------------------------------
    Sender: Data Collection
----------------------------------------------------------------------]]

--- Get the desktopExchange table from SavedVariables
-- @return table|nil
local function GetExchange()
    if not Loothing.Settings then return nil end
    return Loothing.Settings:GetGlobalValue("desktopExchange")
end

--- Check which datasets are available and return their exchange sub-tables
-- @return table datasets { [name] = exchangeSubTable }
-- @return number count of available datasets
function IntelShareMixin:GetAvailableDatasets()
    local exchange = GetExchange()
    if not exchange then return {}, 0 end

    local datasets = {}
    local count = 0
    for _, name in ipairs(DATASET_ORDER) do
        local key = EXCHANGE_KEYS[name]
        local sub = exchange[key]
        if sub and next(sub) then
            datasets[name] = sub
            count = count + 1
        end
    end
    return datasets, count
end

--[[--------------------------------------------------------------------
    Sender: Share Flow
----------------------------------------------------------------------]]

--- Start sharing desktop intel to group or guild
-- @param target string "group" or "guild"
-- @return boolean success
-- @return string|nil error message
function IntelShareMixin:StartShare(target)
    target = (target or "group"):lower()

    -- Validate target
    if target == "guild" and not IsInGuild() then
        return false, L["INTEL_SHARE_NOT_IN_GUILD"]
    end
    if target == "group" and not IsInGroup() then
        return false, L["INTEL_SHARE_NOT_IN_GROUP"]
    end

    -- Check cooldown
    local now = GetTime()
    local remaining = SHARE_COOLDOWN - (now - self.lastShareTime)
    if remaining > 0 then
        return false, string.format(L["INTEL_SHARE_COOLDOWN"], math.ceil(remaining))
    end

    -- Check for active send
    if self.activeSend then
        return false, L["INTEL_SHARE_BUSY"]
    end

    -- Collect available datasets
    local datasets, count = self:GetAvailableDatasets()
    if count == 0 then
        return false, L["INTEL_SHARE_NO_DATA"]
    end

    -- Build transfer ID
    local transferID = Utils.GetPlayerFullName() .. "-" .. math.floor(now) .. "-" .. math.random(1000, 9999)

    -- Build manifest
    local manifest = {
        transferID = transferID,
        sender = Utils.GetPlayerFullName(),
        version = Loothing.VERSION,
        datasets = {},
    }
    -- Build ordered list of datasets to send
    local sendQueue = {}
    for _, name in ipairs(DATASET_ORDER) do
        if datasets[name] then
            local tsKey = TIMESTAMP_KEYS[name]
            manifest.datasets[name] = {
                generatedAt = datasets[name][tsKey],
            }
            sendQueue[#sendQueue + 1] = {
                name = name,
                data = datasets[name],
            }
        end
    end

    -- Send manifest
    local sendFn = target == "guild" and function(cmd, data)
        Loothing.Comm:SendGuild(cmd, data, "BULK")
    end or function(cmd, data)
        Loothing.Comm:Send(cmd, data, nil, "BULK")
    end

    sendFn(Loothing.MsgType.INTEL_SHARE_MANIFEST, manifest)

    -- Set up paced ticker state
    self.lastShareTime = now
    self.activeSend = {
        transferID = transferID,
        target = target,
        sendQueue = sendQueue,
        sendFn = sendFn,
        datasetIndex = 0,
        startTime = now,
        total = #sendQueue,
    }

    self:TriggerEvent("OnIntelShareStarted", transferID, target, #sendQueue)
    Loothing:Print(string.format(L["INTEL_SHARE_STARTED"], target))

    -- Start paced ticker
    self.activeSend.ticker = C_Timer.NewTicker(PACE_INTERVAL, function()
        self:SendNextDataset()
    end)

    return true
end

--- Send the next dataset in the queue (called by ticker)
function IntelShareMixin:SendNextDataset()
    local send = self.activeSend
    if not send then return end

    -- Check queue pressure — yield if too high
    if Loothing.Comm then
        local Comm = Loolib.Comm
        if Comm and Comm.GetQueuePressure then
            local pressure = Comm:GetQueuePressure()
            if pressure > PRESSURE_YIELD then
                Loothing:Debug("IntelShare: yielding tick, pressure =", string.format("%.2f", pressure))
                return  -- Skip this tick, ticker will fire again
            end
        end
    end

    -- Advance to next dataset
    send.datasetIndex = send.datasetIndex + 1
    local entry = send.sendQueue[send.datasetIndex]

    if not entry then
        -- All datasets sent
        self:FinishSend()
        return
    end

    -- Send dataset
    local payload = {
        transferID = send.transferID,
        type = entry.name,
        data = entry.data,
    }

    send.sendFn(Loothing.MsgType.INTEL_SHARE, payload)

    self:TriggerEvent("OnIntelShareProgress", send.transferID, send.datasetIndex, entry.name)
    Loothing:Print(string.format(L["INTEL_SHARE_PROGRESS"],
        DATASET_LABELS[entry.name], send.datasetIndex, send.total))

    -- If this was the last one, finish
    if send.datasetIndex >= send.total then
        self:FinishSend()
    end
end

--- Finish the send operation and clean up
function IntelShareMixin:FinishSend()
    local send = self.activeSend
    if not send then return end

    if send.ticker then
        send.ticker:Cancel()
    end

    local total = send.total
    self:TriggerEvent("OnIntelShareComplete", send.transferID, send.target)
    Loothing:Print(string.format(L["INTEL_SHARE_COMPLETE"], total))

    self.activeSend = nil
end

--- Cancel an active share operation
function IntelShareMixin:CancelShare()
    local send = self.activeSend
    if not send then return end

    if send.ticker then
        send.ticker:Cancel()
    end

    self:TriggerEvent("OnIntelShareFailed", send.transferID, "cancelled")
    self.activeSend = nil
end

--[[--------------------------------------------------------------------
    Receiver: Manifest Handler
----------------------------------------------------------------------]]

--- Handle incoming INTEL_SHARE_MANIFEST
-- @param data table { transferID, sender, version, datasets }
-- @param sender string
-- @param distribution string
function IntelShareMixin:HandleManifest(data, sender, distribution)
    -- Ignore own broadcasts (fail-closed: if localName is nil, skip to be safe)
    local localName = Utils.GetPlayerFullName()
    if not localName or Utils.IsSamePlayer(sender, localName) then return end

    local transferID = data.transferID
    if not transferID then return end

    -- Don't create duplicate entries
    if self.pendingReceive[transferID] then return end

    -- Count expected datasets
    local expectedCount = 0
    if data.datasets then
        for _ in pairs(data.datasets) do
            expectedCount = expectedCount + 1
        end
    end

    if expectedCount == 0 then return end

    -- Create pending entry (not yet accepted — datasets buffer until user confirms)
    self.pendingReceive[transferID] = {
        sender = sender,
        manifest = data,
        datasets = {},
        receivedCount = 0,
        expectedCount = expectedCount,
        receivedAt = GetTime(),
        accepted = false,
    }

    -- Start timeout timer (NewTimer returns a cancellable handle; After does not)
    self.pendingReceive[transferID].timer = C_Timer.NewTimer(RECEIVE_TIMEOUT, function()
        self:OnReceiveTimeout(transferID)
    end)

    self:TriggerEvent("OnIntelReceiveStarted", transferID, sender)

    -- Show confirmation popup — datasets arriving in the meantime are buffered
    local Popups = ns.Popups
    if Popups then
        Popups:Show("LOOTHING_INTEL_SHARE_REQUEST", {
            player = Ambiguate(sender, "short"),
            count = expectedCount,
            onAccept = function()
                self:AcceptTransfer(transferID)
            end,
            onCancel = function()
                self:DeclineTransfer(transferID)
            end,
        })
    else
        -- Fallback: auto-accept if popup system unavailable
        self:AcceptTransfer(transferID)
    end
end

--- Accept a pending intel transfer and merge any buffered datasets
-- @param transferID string
function IntelShareMixin:AcceptTransfer(transferID)
    local pending = self.pendingReceive[transferID]
    if not pending then return end

    pending.accepted = true
    Loothing:Print(string.format(L["INTEL_RECEIVE_STARTED"], Ambiguate(pending.sender, "short")))

    -- If all datasets already arrived while waiting for confirmation, merge now
    if pending.receivedCount >= pending.expectedCount then
        self:MergeIntel(transferID)
    end
end

--- Decline a pending intel transfer and discard all buffered data
-- @param transferID string
function IntelShareMixin:DeclineTransfer(transferID)
    local pending = self.pendingReceive[transferID]
    if not pending then return end

    if pending.timer then
        pending.timer:Cancel()
    end

    Loothing:Print(string.format(L["INTEL_RECEIVE_DECLINED"], Ambiguate(pending.sender, "short")))
    self.pendingReceive[transferID] = nil
end

--[[--------------------------------------------------------------------
    Receiver: Dataset Handler
----------------------------------------------------------------------]]

--- Handle incoming INTEL_SHARE dataset message
-- @param data table { transferID, type, data }
-- @param sender string
-- @param distribution string
function IntelShareMixin:HandleDataset(data, sender, distribution)
    -- Ignore own broadcasts (fail-closed: if localName is nil, skip to be safe)
    local localName = Utils.GetPlayerFullName()
    if not localName or Utils.IsSamePlayer(sender, localName) then return end

    local transferID = data.transferID
    if not transferID then return end

    local pending = self.pendingReceive[transferID]
    if not pending then return end  -- No manifest received (or timed out)

    local datasetType = data.type
    if not datasetType or not EXCHANGE_KEYS[datasetType] then return end

    -- Don't process duplicate datasets
    if pending.datasets[datasetType] then return end

    pending.datasets[datasetType] = data.data
    pending.receivedCount = pending.receivedCount + 1

    -- Only show progress and trigger merge if the user has accepted
    if pending.accepted then
        self:TriggerEvent("OnIntelReceiveProgress", transferID, sender,
            pending.receivedCount, pending.expectedCount)
        Loothing:Print(string.format(L["INTEL_RECEIVE_PROGRESS"],
            Ambiguate(sender, "short"), pending.receivedCount, pending.expectedCount))

        -- Check if all datasets received
        if pending.receivedCount >= pending.expectedCount then
            self:MergeIntel(transferID)
        end
    end
    -- If not yet accepted, datasets just buffer silently
end

--[[--------------------------------------------------------------------
    Receiver: Merge Logic
----------------------------------------------------------------------]]

--- Merge received datasets into local desktopExchange SavedVariables
-- @param transferID string
function IntelShareMixin:MergeIntel(transferID)
    local pending = self.pendingReceive[transferID]
    if not pending then return end

    -- Cancel timeout timer
    if pending.timer then
        pending.timer:Cancel()
        pending.timer = nil
    end

    local mergedCount = 0
    local sender = pending.sender
    local now = time()

    -- Process each received dataset, deferred across frames to avoid hitching
    local datasetsToMerge = {}
    for name, incomingData in pairs(pending.datasets) do
        datasetsToMerge[#datasetsToMerge + 1] = { name = name, data = incomingData }
    end

    local function mergeNext(index)
        if index > #datasetsToMerge then
            -- All done
            self:TriggerEvent("OnIntelReceiveComplete", transferID, sender, mergedCount)
            Loothing:Print(string.format(L["INTEL_RECEIVE_COMPLETE"],
                Ambiguate(sender, "short"), mergedCount, pending.expectedCount))
            self.pendingReceive[transferID] = nil
            return
        end

        local entry = datasetsToMerge[index]
        local name = entry.name
        local incomingData = entry.data
        local exchangeKey = EXCHANGE_KEYS[name]
        local tsKey = TIMESTAMP_KEYS[name]

        if exchangeKey and incomingData then
            local exchange = GetExchange() or {}
            local local_sub = exchange[exchangeKey]
            local localTs = local_sub and local_sub[tsKey]
            local incomingTs = incomingData[tsKey]

            -- Merge if incoming is newer or local has no data
            local shouldMerge = not localTs or (incomingTs and incomingTs > localTs)

            -- Also skip merge if local data is from the desktop app (no sharedBy)
            -- and incoming is shared data. Desktop data is authoritative.
            if local_sub and not local_sub.sharedBy and localTs then
                -- Local is desktop-sourced. Only merge if incoming is strictly newer.
                shouldMerge = incomingTs and incomingTs > localTs
            end

            if shouldMerge then
                -- Stamp with sharing metadata
                incomingData.sharedBy = sender
                incomingData.sharedAt = now

                -- Persist to SavedVariables
                Loothing.Settings:SetGlobalValue("desktopExchange." .. exchangeKey, incomingData)

                -- Reload the corresponding module
                local moduleField = MODULE_FIELDS[name]
                local mod = moduleField and Loothing[moduleField]
                if mod and mod.LoadFromSaved then
                    mod:LoadFromSaved()
                end

                mergedCount = mergedCount + 1
            end
        end

        -- Defer next merge to next frame
        C_Timer.After(0, function()
            mergeNext(index + 1)
        end)
    end

    -- Start the merge chain
    mergeNext(1)
end

--- Handle receive timeout
-- @param transferID string
function IntelShareMixin:OnReceiveTimeout(transferID)
    local pending = self.pendingReceive[transferID]
    if not pending then return end

    -- If user never accepted, silently discard
    if not pending.accepted then
        self.pendingReceive[transferID] = nil
        return
    end

    -- Merge whatever we did receive
    if pending.receivedCount > 0 then
        self:MergeIntel(transferID)
    else
        self:TriggerEvent("OnIntelReceiveFailed", transferID, "timeout")
        Loothing:Print(string.format(L["INTEL_RECEIVE_TIMEOUT"],
            Ambiguate(pending.sender, "short"),
            pending.receivedCount, pending.expectedCount))
        self.pendingReceive[transferID] = nil
    end
end

--[[--------------------------------------------------------------------
    Purge Shared Data
----------------------------------------------------------------------]]

--- Remove all shared (non-desktop-sourced) intel from SavedVariables
-- @return number purgedCount
function IntelShareMixin:PurgeSharedData()
    local exchange = GetExchange()
    if not exchange then
        Loothing:Print(L["INTEL_PURGE_NOTHING"])
        return 0
    end

    local purgedCount = 0

    for _, name in ipairs(DATASET_ORDER) do
        local key = EXCHANGE_KEYS[name]
        local sub = exchange[key]
        if sub and sub.sharedBy then
            Loothing.Settings:SetGlobalValue("desktopExchange." .. key, nil)

            -- Reload the module (will clear its state since data is gone)
            local moduleField = MODULE_FIELDS[name]
            local mod = moduleField and Loothing[moduleField]
            if mod and mod.LoadFromSaved then
                mod:LoadFromSaved()
            end

            purgedCount = purgedCount + 1
        end
    end

    if purgedCount > 0 then
        Loothing:Print(L["INTEL_PURGE_DONE"])
    else
        Loothing:Print(L["INTEL_PURGE_NOTHING"])
    end

    return purgedCount
end

--[[--------------------------------------------------------------------
    Status Report
----------------------------------------------------------------------]]

--- Print status of all desktop intel datasets
function IntelShareMixin:PrintStatus()
    Loothing:Print(L["INTEL_SHARE_STATUS_HEADER"])

    local exchange = GetExchange()
    if not exchange then
        Loothing:Print(L["INTEL_SHARE_STATUS_NONE"])
        return
    end

    local hasAny = false
    for _, name in ipairs(DATASET_ORDER) do
        local key = EXCHANGE_KEYS[name]
        local sub = exchange[key]
        if sub and next(sub) then
            hasAny = true
            local tsKey = TIMESTAMP_KEYS[name]
            local ts = sub[tsKey]
            local age = ts and (time() - ts) or nil
            local ageStr = age and self:FormatAge(age) or "unknown age"

            local sourceStr
            if sub.sharedBy then
                sourceStr = string.format(L["INTEL_SHARE_STATUS_SHARED"],
                    Ambiguate(sub.sharedBy, "short"))
            else
                sourceStr = L["INTEL_SHARE_STATUS_DESKTOP"]
            end

            Loothing:Print(string.format(L["INTEL_SHARE_STATUS_LINE"],
                DATASET_LABELS[name], ageStr, sourceStr))
        end
    end

    if not hasAny then
        Loothing:Print(L["INTEL_SHARE_STATUS_NONE"])
    end
end

--- Format seconds into human-readable age string
-- @param seconds number
-- @return string
function IntelShareMixin:FormatAge(seconds)
    if seconds < 60 then
        return "just now"
    elseif seconds < 3600 then
        return string.format("%dm ago", math.floor(seconds / 60))
    elseif seconds < 86400 then
        return string.format("%dh ago", math.floor(seconds / 3600))
    else
        return string.format("%dd ago", math.floor(seconds / 86400))
    end
end

--[[--------------------------------------------------------------------
    Send Progress Query (for UI)
----------------------------------------------------------------------]]

--- Get current send progress
-- @return number|nil current index (nil if not sending)
-- @return number|nil total count
-- @return string|nil current dataset name
function IntelShareMixin:GetSendProgress()
    local send = self.activeSend
    if not send then return nil, nil, nil end

    local entry = send.sendQueue[send.datasetIndex]
    local name = entry and entry.name or nil
    return send.datasetIndex, send.total, name
end

--- Check if a share is currently in progress
-- @return boolean
function IntelShareMixin:IsSending()
    return self.activeSend ~= nil
end
