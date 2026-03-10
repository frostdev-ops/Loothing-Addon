local _, ns = ...

--[[--------------------------------------------------------------------
    Loothing - Loot Council Addon for WoW 12.0+
    ErrorHandler - Error capture, dedup, and storage

    Features:
    - Intercepts geterrorhandler() / BugGrabber callbacks
    - Logs errors with configurable stack trace depth (default 10)
    - Deduplicates by message hash
    - Stores in SavedVariables with timestamps and counts
    - Clears errors older than 7 days
    - Structured logging with levels: DEBUG, INFO, WARN, ERROR
    - Circular buffer log (max 4000 entries)
    - /loothing errors  and  /loothing log  commands

    Factory: CreateErrorHandler()
----------------------------------------------------------------------]]
local Loolib = LibStub("Loolib")
local Loothing = ns.Addon

--[[--------------------------------------------------------------------
    Constants
----------------------------------------------------------------------]]

local MAX_STACK_DEPTH = 10
local MAX_ERRORS = 500
local ERROR_EXPIRY_SECONDS = 7 * 24 * 60 * 60  -- 7 days
local MAX_LOG_ENTRIES = 4000

local LOG_LEVEL = {
    DEBUG = 1,
    INFO  = 2,
    WARN  = 3,
    ERROR = 4,
}

local LOG_LEVEL_NAME = {
    [1] = "DEBUG",
    [2] = "INFO",
    [3] = "WARN",
    [4] = "ERROR",
}

local LOG_LEVEL_COLOR = {
    [1] = "|cff808080",  -- gray
    [2] = "|cff00ff00",  -- green
    [3] = "|cffffff00",  -- yellow
    [4] = "|cffff0000",  -- red
}

--[[--------------------------------------------------------------------
    ErrorHandlerMixin
----------------------------------------------------------------------]]

local ErrorHandlerMixin = ns.ErrorHandlerMixin or {}
ns.ErrorHandlerMixin = ErrorHandlerMixin

--- Initialize the error handler
function ErrorHandlerMixin:Init()
    self.errors = {}           -- hash -> error entry
    self.errorOrder = {}       -- array of hashes in insertion order
    self.logBuffer = {}        -- circular buffer of log entries
    self.logHead = 0           -- next write index (0-based)
    self.logCount = 0          -- total entries currently in buffer
    self.minLogLevel = LOG_LEVEL.INFO  -- default threshold for chat output
    self.debugMode = false     -- verbose output toggle
    self.originalHandler = nil -- original error handler reference

    self:InstallHandler()
end

--[[--------------------------------------------------------------------
    Error Handler Installation
----------------------------------------------------------------------]]

--- Install our error handler, chaining the original
function ErrorHandlerMixin:InstallHandler()
    self.originalHandler = geterrorhandler()

    local self_ref = self
    seterrorhandler(function(msg)
        self_ref:CaptureError(msg)
        -- Chain to original handler
        if self_ref.originalHandler then
            self_ref.originalHandler(msg)
        end
    end)

    -- Also hook BugGrabber if available
    local BugGrabber = _G["BugGrabber"]
    if BugGrabber and BugGrabber.RegisterCallback then
        BugGrabber:RegisterCallback("BugGrabber_BugGrabbed", function(_, errObj)
            if errObj and errObj.message then
                self_ref:CaptureError(errObj.message, errObj.stack)
            end
        end)
    end
end

--[[--------------------------------------------------------------------
    Error Capture
----------------------------------------------------------------------]]

--- Generate a stable hash for deduplication
-- @param msg string - Error message
-- @return string - Hash key
local function HashError(msg)
    -- Strip line numbers and memory addresses for dedup
    local cleaned = msg:gsub(":%d+:", ":*:")
    cleaned = cleaned:gsub("0x%x+", "0x*")
    -- Simple string hash (djb2-ish, good enough for dedup)
    local hash = 5381
    for i = 1, #cleaned do
        hash = ((hash * 33) + cleaned:byte(i)) % 0x7FFFFFFF
    end
    return tostring(hash)
end

--- Capture an error, deduplicating by message hash
-- @param msg string - Error message
-- @param stack string|nil - Optional pre-captured stack trace
function ErrorHandlerMixin:CaptureError(msg, stack)
    if not msg then return end
    if Loolib.SecretUtil and Loolib.SecretUtil.IsSecretValue and Loolib.SecretUtil.IsSecretValue(msg) then
        msg = "<secret error>"
    else
        msg = tostring(msg)
    end

    -- Only capture Loothing-related errors (or all in debug mode)
    local isOurs = msg:find("Loothing") or msg:find("loothing") or msg:find("Loolib")
    if not isOurs and not self.debugMode then
        return
    end

    local hash = HashError(msg)

    if self.errors[hash] then
        -- Increment existing
        local entry = self.errors[hash]
        entry.count = entry.count + 1
        entry.lastSeen = time()
    else
        -- New error
        stack = stack or debugstack(3, MAX_STACK_DEPTH, 0)

        local entry = {
            message = msg,
            stack = stack,
            count = 1,
            firstSeen = time(),
            lastSeen = time(),
        }

        self.errors[hash] = entry
        self.errorOrder[#self.errorOrder + 1] = hash

        -- Enforce max errors
        if #self.errorOrder > MAX_ERRORS then
            local oldHash = table.remove(self.errorOrder, 1)
            self.errors[oldHash] = nil
        end
    end

    -- Also log as ERROR level
    self:Log(LOG_LEVEL.ERROR, "ErrorHandler", msg)
end

--[[--------------------------------------------------------------------
    Error Query / Cleanup
----------------------------------------------------------------------]]

--- Get all captured errors (newest first)
-- @return table - Array of { message, stack, count, firstSeen, lastSeen }
function ErrorHandlerMixin:GetErrors()
    local result = {}
    for i = #self.errorOrder, 1, -1 do
        local entry = self.errors[self.errorOrder[i]]
        if entry then
            result[#result + 1] = entry
        end
    end
    return result
end

--- Get error count
-- @return number
function ErrorHandlerMixin:GetErrorCount()
    return #self.errorOrder
end

--- Clear errors older than ERROR_EXPIRY_SECONDS
function ErrorHandlerMixin:PurgeOldErrors()
    local cutoff = time() - ERROR_EXPIRY_SECONDS
    local newOrder = {}
    for _, hash in ipairs(self.errorOrder) do
        local entry = self.errors[hash]
        if entry and entry.lastSeen >= cutoff then
            newOrder[#newOrder + 1] = hash
        else
            self.errors[hash] = nil
        end
    end
    self.errorOrder = newOrder
end

--- Clear all captured errors
function ErrorHandlerMixin:ClearErrors()
    self.errors = {}
    self.errorOrder = {}
end

--[[--------------------------------------------------------------------
    Structured Logging (Circular Buffer)
----------------------------------------------------------------------]]

--- Write a structured log entry
-- @param level number - LOG_LEVEL value
-- @param module string - Module name prefix
-- @param msg string - Log message
function ErrorHandlerMixin:Log(level, module, msg)
    level = level or LOG_LEVEL.INFO
    module = module or "Loothing"

    local entry = {
        level = level,
        module = module,
        message = msg,
        timestamp = time(),
    }

    -- Write into circular buffer
    self.logHead = (self.logHead % MAX_LOG_ENTRIES) + 1
    self.logBuffer[self.logHead] = entry
    if self.logCount < MAX_LOG_ENTRIES then
        self.logCount = self.logCount + 1
    end

    -- Print to chat if above threshold and debug mode is on
    if self.debugMode and level >= self.minLogLevel then
        local color = LOG_LEVEL_COLOR[level] or "|cffffffff"
        local levelName = LOG_LEVEL_NAME[level] or "???"
        print(string.format("%s[%s][%s]|r %s", color, levelName, module, tostring(msg)))
    end
end

--- Convenience: Log at DEBUG level
function ErrorHandlerMixin:LogDebug(module, msg)
    self:Log(LOG_LEVEL.DEBUG, module, msg)
end

--- Convenience: Log at INFO level
function ErrorHandlerMixin:LogInfo(module, msg)
    self:Log(LOG_LEVEL.INFO, module, msg)
end

--- Convenience: Log at WARN level
function ErrorHandlerMixin:LogWarn(module, msg)
    self:Log(LOG_LEVEL.WARN, module, msg)
end

--- Convenience: Log at ERROR level
function ErrorHandlerMixin:LogError(module, msg)
    self:Log(LOG_LEVEL.ERROR, module, msg)
end

--- Get recent log entries (newest first)
-- @param count number - Max entries to return (default 50)
-- @param filterLevel number|nil - Only return entries at this level or above
-- @param filterModule string|nil - Only return entries from this module
-- @return table - Array of log entries
function ErrorHandlerMixin:GetRecentLogs(count, filterLevel, filterModule)
    count = count or 50
    filterLevel = filterLevel or LOG_LEVEL.DEBUG

    local result = {}
    local checked = 0
    local idx = self.logHead

    while checked < self.logCount and #result < count do
        local entry = self.logBuffer[idx]
        if entry then
            local passLevel = entry.level >= filterLevel
            local passModule = not filterModule or entry.module == filterModule
            if passLevel and passModule then
                result[#result + 1] = entry
            end
        end

        idx = idx - 1
        if idx < 1 then
            idx = MAX_LOG_ENTRIES
        end
        checked = checked + 1
    end

    return result
end

--- Get total log entry count
-- @return number
function ErrorHandlerMixin:GetLogCount()
    return self.logCount
end

--- Clear the log buffer
function ErrorHandlerMixin:ClearLogs()
    self.logBuffer = {}
    self.logHead = 0
    self.logCount = 0
end

--[[--------------------------------------------------------------------
    Debug Mode
----------------------------------------------------------------------]]

--- Toggle debug mode (verbose log output)
-- @param enabled boolean|nil - true/false or nil to toggle
function ErrorHandlerMixin:SetDebugMode(enabled)
    if enabled == nil then
        self.debugMode = not self.debugMode
    else
        self.debugMode = enabled
    end
end

--- Check if debug mode is on
-- @return boolean
function ErrorHandlerMixin:IsDebugMode()
    return self.debugMode
end

--- Set minimum log level for chat output
-- @param level number - LOG_LEVEL value
function ErrorHandlerMixin:SetMinLogLevel(level)
    if level >= LOG_LEVEL.DEBUG and level <= LOG_LEVEL.ERROR then
        self.minLogLevel = level
    end
end

--[[--------------------------------------------------------------------
    SavedVariables Integration
----------------------------------------------------------------------]]

--- Save errors to SavedVariables
function ErrorHandlerMixin:SaveToDatabase()
    if not Loothing.Settings then return end

    -- Purge old errors before saving
    self:PurgeOldErrors()

    local serializable = {}
    for _, hash in ipairs(self.errorOrder) do
        local entry = self.errors[hash]
        if entry then
            serializable[#serializable + 1] = {
                h = hash,
                m = entry.message,
                s = entry.stack,
                c = entry.count,
                f = entry.firstSeen,
                l = entry.lastSeen,
            }
        end
    end

    Loothing.Settings:SetGlobalValue("errorLog", serializable)
end

--- Load errors from SavedVariables
function ErrorHandlerMixin:LoadFromDatabase()
    if not Loothing.Settings then return end

    local saved = Loothing.Settings:GetGlobalValue("errorLog")
    if not saved or type(saved) ~= "table" then return end

    self.errors = {}
    self.errorOrder = {}

    for _, data in ipairs(saved) do
        if data.h and data.m then
            self.errors[data.h] = {
                message = data.m,
                stack = data.s or "",
                count = data.c or 1,
                firstSeen = data.f or 0,
                lastSeen = data.l or 0,
            }
            self.errorOrder[#self.errorOrder + 1] = data.h
        end
    end

    -- Purge expired entries
    self:PurgeOldErrors()
end

--[[--------------------------------------------------------------------
    Slash Command Handlers
----------------------------------------------------------------------]]

--- Handle /loothing errors command
-- @param args string - Subcommand arguments ("", "clear", "count")
function ErrorHandlerMixin:HandleErrorsCommand(args)
    args = (args or ""):lower()

    if args == "clear" then
        self:ClearErrors()
        print("|cff00ccff[Loothing]|r Error log cleared.")
        return
    end

    if args == "count" then
        print(string.format("|cff00ccff[Loothing]|r %d captured errors.", self:GetErrorCount()))
        return
    end

    -- Default: show recent errors
    local errors = self:GetErrors()
    if #errors == 0 then
        print("|cff00ccff[Loothing]|r No captured errors.")
        return
    end

    print(string.format("|cff00ccff[Loothing]|r Captured errors (%d total):", #errors))
    local shown = math.min(#errors, 10)
    for i = 1, shown do
        local entry = errors[i]
        local age = time() - entry.lastSeen
        local ageStr
        if age < 60 then
            ageStr = age .. "s ago"
        elseif age < 3600 then
            ageStr = math.floor(age / 60) .. "m ago"
        else
            ageStr = math.floor(age / 3600) .. "h ago"
        end

        print(string.format(
            "|cffff0000  [%dx]|r %s |cff808080(%s)|r",
            entry.count,
            entry.message:sub(1, 120),
            ageStr
        ))
    end

    if #errors > shown then
        print(string.format("|cff808080  ... and %d more|r", #errors - shown))
    end
end

--- Handle /loothing log command
-- @param args string - Subcommand arguments ("", "clear", "debug", "info", "warn", "error", "N")
function ErrorHandlerMixin:HandleLogCommand(args)
    args = (args or ""):lower()

    if args == "clear" then
        self:ClearLogs()
        print("|cff00ccff[Loothing]|r Log buffer cleared.")
        return
    end

    -- Filter by level
    local filterLevel = LOG_LEVEL.DEBUG
    local count = 20

    if args == "debug" then
        filterLevel = LOG_LEVEL.DEBUG
    elseif args == "info" then
        filterLevel = LOG_LEVEL.INFO
    elseif args == "warn" then
        filterLevel = LOG_LEVEL.WARN
    elseif args == "error" then
        filterLevel = LOG_LEVEL.ERROR
    else
        local num = tonumber(args)
        if num and num > 0 then
            count = math.min(num, 100)
        end
    end

    local logs = self:GetRecentLogs(count, filterLevel)
    if #logs == 0 then
        print("|cff00ccff[Loothing]|r No log entries.")
        return
    end

    print(string.format("|cff00ccff[Loothing]|r Recent logs (%d of %d total):", #logs, self:GetLogCount()))
    -- Print oldest-first for readability (logs come newest-first)
    for i = #logs, 1, -1 do
        local entry = logs[i]
        local color = LOG_LEVEL_COLOR[entry.level] or "|cffffffff"
        local levelName = LOG_LEVEL_NAME[entry.level] or "???"
        local ts = date("%H:%M:%S", entry.timestamp)
        print(string.format("  |cff808080%s|r %s[%s][%s]|r %s",
            ts, color, levelName, entry.module, entry.message))
    end
end

--[[--------------------------------------------------------------------
    Factory
----------------------------------------------------------------------]]

--- Create a new error handler instance
-- @return ErrorHandlerMixin
local function CreateErrorHandler()
    local handler = Loolib.CreateFromMixins(ErrorHandlerMixin)
    handler:Init()
    return handler
end
ns.CreateErrorHandler = CreateErrorHandler

--[[--------------------------------------------------------------------
    Expose Constants
----------------------------------------------------------------------]]

Loothing.LogLevel = LOG_LEVEL
