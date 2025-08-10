local Constants = require("ElyonLib/Core/Constants");
local TableFormatter = require("ElyonLib/TableUtils/TableFormatter");

---@class Logger
local Logger = {};
Logger.__index = Logger;

Logger.logFileMask = "admin";
Logger.isServer = isServer();
Logger.isClient = isClient();


--- A table to store loggers by mod ID
---@type table<string, Logger>
local loggers = {};

--- Creates a new Logger or returns the existing one for the given mod ID
---@param modID string The mod's unique identifier
---@param modVersion string|nil The mod version for which this Logger is created
---@return Logger logger
function Logger:new(modID, modVersion)
    if loggers[modID] then return loggers[modID]; end

    ---@class Logger
    local o = {};
    setmetatable(o, self);

    --- The current log level (default is INFO)
    ---@type string
    o.currentLogLevel = isDebugEnabled() and Constants.LOG_LEVELS.DEBUG or Constants.LOG_LEVELS.INFO;

    --- Log level mapping to priority values
    ---@type table<string, number>
    o.levels = {
        [Constants.LOG_LEVELS.ERROR] = 1,
        [Constants.LOG_LEVELS.WARNING] = 2,
        [Constants.LOG_LEVELS.INFO] = 3,
        [Constants.LOG_LEVELS.DEBUG] = 4,
    };

    o.modID = modID;
    o.modVersion = modVersion;
    loggers[modID] = o;

    return o;
end

--- Sets the log level of the Logger
---@param level string The log level to set (e.g., "ERROR", "WARNING", "INFO", "DEBUG")
function Logger:setLogLevel(level)
    self.currentLogLevel = level;
end

--- Checks if a message should be logged based on the current log level
---@param level string The level of the log message
---@return boolean shouldLog
function Logger:shouldLog(level)
    return self.levels[level] <= self.levels[self.currentLogLevel];
end

--- Logs a message at the specified log level
---@param level string The level of the log message (e.g., "ERROR", "WARNING", "INFO", "DEBUG")
---@param message string The log message template
---@param ... any Variables to format the message
function Logger:log(level, message, ...)
    if self:shouldLog(level) then
        local formattedMessage = string.format(message, ...);
        print(string.format("[%s] [%s]: %s", self.modID, level, formattedMessage));
    end
end

--- Logs an error message
---@param message string The log message template
---@param ... any Variables to format the message
function Logger:error(message, ...)
    self:log(Constants.LOG_LEVELS.ERROR, message, ...);
end

--- Logs a warning message
---@param message string The log message template
---@param ... any Variables to format the message
function Logger:warning(message, ...)
    self:log(Constants.LOG_LEVELS.WARNING, message, ...);
end

--- Logs an info message
---@param message string The log message template
---@param ... any Variables to format the message
function Logger:info(message, ...)
    self:log(Constants.LOG_LEVELS.INFO, message, ...);
end

--- Logs a debug message
---@param message string The log message template
---@param ... any Variables to format the message
function Logger:debug(message, ...)
    self:log(Constants.LOG_LEVELS.DEBUG, message, ...);
end

--- Logs a pretty-printed table at the specified log level
---@param level string The level of the log message (e.g., "ERROR", "WARNING", "INFO", "DEBUG")
---@param tbl table The table to pretty print
function Logger:logTable(level, tbl)
    if self:shouldLog(level) then
        local formattedTable = TableFormatter.format(tbl);
        self:log(level, "\n%s", formattedTable);
    end
end

function Logger:writeToLogFile(logFileMask, logText)
    writeLog(logFileMask, logText);
end

--- On Client:<br>
---     "client" > logs on the client<br>
---     "server" > sends the log text to the server<br>
---     "both" > logs on the client and sends the log text to the server<br>
--- On Server:<br>
---     "server" > logs on the server<br>
---     "both" > sends the log text to all clients (logging is done locally too)<br>
---@param options table {logFileMask: string, logText: string, logMode: "client"|"server"|"both"}
function Logger:writeLog(options)
    if not options or type(options) ~= "table" then
        self:error("Logger.writeLog requires a table with logFileMask, logText, and logMode.");
        return;
    end

    local logFileMask = options.logFileMask;
    local logText = options.logText or "";
    local logMode = options.logMode or (Logger.isServer and "server" or "client");

    if logMode == "server" and Logger.isServer then
        Logger:writeToLogFile(logFileMask, logText);
    elseif logMode == "client" and not Logger.isServer then
        Logger:writeToLogFile(logFileMask, logText);
    elseif logMode == "both" then
        Logger:writeToLogFile(logFileMask, logText);
        if Logger.isServer then
            sendServerCommand("ElyonLib", "LogToClient", {logFileMask = logFileMask, logText = logText});
        else
            sendClientCommand("ElyonLib", "LogToServer", {logFileMask = logFileMask, logText = logText});
        end
    end
end

-- On the server side, listen for the "LogToServer" command from clients and log the data
if Logger.isServer then
    Events.OnClientCommand.Add(function(module, command, player, args)
        if module == "ElyonLib" and command == "LogToServer" and args then
            Logger:writeToLogFile(args.logFileMask, args.logText);
        end
    end)
end

-- On the client side, listen for the "LogToClient" command from the server and log the data
if not Logger.isServer then
    Events.OnServerCommand.Add(function(module, command, args)
        if module == "ElyonLib" and command == "LogToClient" and args then
            Logger:writeToLogFile(args.logFileMask, args.logText);
        end
    end)
end

return Logger;
