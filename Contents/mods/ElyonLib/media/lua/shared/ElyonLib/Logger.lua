local Constants = require("ElyonLib/Constants");

--- @class Logger
local Logger = {};
Logger.__index = Logger;

--- A table to store loggers by mod ID
--- @type table<string, Logger>
local loggers = {};

--- Creates a new Logger or returns the existing one for the given mod ID
--- @param modID string The mod's unique identifier
--- @return Logger logger
function Logger:new(modID)
    if loggers[modID] then return loggers[modID]; end

    ---@class Logger
    local o = {};
    setmetatable(o, self);

    --- the current log level (default is INFO)
    --- @type string
    o.currentLogLevel = isDebugEnabled() and Constants.LOG_LEVELS.DEBUG or Constants.LOG_LEVELS.INFO;

    --- log level mapping to priority values
    --- @type table<string, number>
    o.levels = {
        [Constants.LOG_LEVELS.ERROR] = 1,
        [Constants.LOG_LEVELS.WARNING] = 2,
        [Constants.LOG_LEVELS.INFO] = 3,
        [Constants.LOG_LEVELS.DEBUG] = 4,
    };

    o.modID = modID;
    loggers[modID] = o;

    return o;
end

--- Sets the log level of the Logger
--- @param level string The log level to set (e.g., "ERROR", "WARNING", "INFO", "DEBUG")
function Logger:setLogLevel(level)
    self.currentLogLevel = level;
end

--- Checks if a message should be logged based on the current log level
--- @param level string The level of the log message
--- @return boolean shouldLog
function Logger:shouldLog(level)
    return self.levels[level] <= self.levels[self.currentLogLevel];
end

--- Logs a message at the specified log level
--- @param level string The level of the log message (e.g., "ERROR", "WARNING", "INFO", "DEBUG")
--- @param message string|table|nil
--- @param indent number|nil
function Logger:log(level, message, indent)
    if self:shouldLog(level) then
        local outputMessage = type(message) == "table" and self:printTable(message, indent) or tostring(message);
        print(string.format("[%s] [%s]: %s", self.modID, level, outputMessage));
    end
end

--- Logs an error message
--- @param message string|table|nil
function Logger:error(message)
    self:log(Constants.LOG_LEVELS.ERROR, message);
end

--- Logs a warning message
--- @param message string|table|nil
function Logger:warning(message)
    self:log(Constants.LOG_LEVELS.WARNING, message);
end

--- Logs an info message
--- @param message string|table|nil
function Logger:info(message)
    self:log(Constants.LOG_LEVELS.INFO, message);
end

--- Logs a debug message
--- @param message string|table|nil
function Logger:debug(message)
    self:log(Constants.LOG_LEVELS.DEBUG, message);
end

--- Recursively pretty-prints a table
--- @param tbl table The table to pretty print
--- @param indent number|nil The current indentation level (used for recursion)
--- @param seen table|nil A table used to track circular references
function Logger:printTable(tbl, indent, seen)
    indent = indent or 0;
    seen = seen or {};
    local spacing = string.rep("  ", indent);

    if seen[tbl] then
        print(spacing .. "<Circular Reference>");
        return;
    end
    seen[tbl] = true;

    if type(tbl) ~= "table" then
        print(spacing .. tostring(tbl));
        return;
    end

    print(spacing .. "{");
    for k, v in pairs(tbl) do
        local key = (type(k) == "string") and ('"' .. k .. '"') or tostring(k);
        if type(v) == "table" then
            print(spacing .. "  [" .. key .. "] = ");
            self:printTable(v, indent + 1, seen);
        else
            local value = (type(v) == "string") and ('"' .. v .. '"') or tostring(v);
            print(spacing .. "  [" .. key .. "] = " .. value);
        end
    end
    print(spacing .. "}");
    seen[tbl] = nil;
end

--- Logs a pretty-printed table at the specified log level
--- @param level string The level of the log message (e.g., "ERROR", "WARNING", "INFO", "DEBUG")
--- @param t table The table to pretty print
function Logger:logTable(level, t)
    if self:shouldLog(level) then
        self:printTable(t);
    end
end

return Logger;
