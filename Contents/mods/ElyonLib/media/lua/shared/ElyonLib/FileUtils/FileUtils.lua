local Logger = require("ElyonLib/Core/ElyonLibLogger");
local JSON = require("ElyonLib/FileUtils/JSON");

local FileUtils = {};

--- Reads the entire content of a file
--- @param fileReader BufferedReader The BufferedReader instance
--- @param modId string The mod's unique identifier (optional)
--- @param options table { isModFile: boolean, createIfNull: boolean }
--- @return string|nil content The content of the file or nil if an error occurs
local function bufferedRead(fileReader, modId, options)
    local buffer = {};
    local line = fileReader:readLine();

    while line do
        table.insert(buffer, line);
        line = fileReader:readLine();
    end

    fileReader:close();
    return table.concat(buffer, "\n");
end

--- Writes content to a file
--- @param fileWriter LuaFileWriter The LuaFileWriter instance
--- @param content string The content to write to the file
--- @param modId string The mod's unique identifier (optional)
--- @return boolean success Returns true if writing was successful, false otherwise
local function writeToFile(fileWriter, content, modId)
    local success, err = pcall(function() fileWriter:write(content); fileWriter:close(); end);

    if not success then
        local logger = Logger:new(modId);
        logger:error(string.format("Failed to write content: %s", err));
    end

    return success;
end

--- Reads a text file from mod or Lua directory
--- @param filePath string The path to the file
--- @param modId string The mod's unique identifier
--- @param options table { isModFile: boolean, createIfNull: boolean }
--- @return string|nil content The content of the file or nil if an error occurs
function FileUtils.readFile(filePath, modId, options)
    options = options or {};
    local fileReader;

    if options.isModFile then
        fileReader = getModFileReader(modId, filePath, options.createIfNull or false);
    else
        fileReader = getFileReader(filePath, options.createIfNull or false);
    end

    if not fileReader then
        local logger = Logger:new(modId);
        logger:error(string.format("Failed to open file for reading: %s", filePath));
        return nil;
    end

    return bufferedRead(fileReader, modId, options);
end

--- Writes text content to a file in mod or Lua directory
--- @param filePath string The path to the file
--- @param content string The content to write
--- @param modId string The mod's unique identifier
--- @param options table { isModFile: boolean, createIfNull: boolean, append: boolean }
--- @return boolean success Returns true if writing was successful, false otherwise
function FileUtils.writeFile(filePath, content, modId, options)
    options = options or {};
    local fileWriter;

    if options.isModFile then
        fileWriter = getModFileWriter(modId, filePath, options.createIfNull or false, options.append or false);
    else
        fileWriter = getFileWriter(filePath, options.createIfNull or false, options.append or false);
    end

    if not fileWriter then
        local logger = Logger:new(modId);
        logger:error(string.format("Failed to open file for writing: %s", filePath));
        return false;
    end

    return writeToFile(fileWriter, content, modId);
end

--- Reads and parses a json file from mod or Lua directory
--- @param filePath string The path to the json file
--- @param modId string The mod's unique identifier
--- @param options table { isModFile: boolean }
--- @return table|nil data The parsed json data as a Lua table or nil if an error occurs
function FileUtils.readJson(filePath, modId, options)
    local content = FileUtils.readFile(filePath, modId, options);
    if not content then return nil; end

    local success, data = pcall(JSON.parse, content)
    if not success then
        local logger = Logger:new(modId);
        logger:error(string.format("Failed to parse json from file: %s. Error: %s", filePath, data));
        return nil;
    end

    return data;
end

--- Serializes and writes a Lua table as json to a file in mod or Lua directory.
--- @param filePath string The path to the json file
--- @param data table The Lua table to serialize and write
--- @param modId string The mod's unique identifier
--- @param options table { isModFile: boolean, createIfNull: boolean, append: boolean }
--- @return boolean success Returns true if writing was successful, false otherwise
function FileUtils.writeJson(filePath, data, modId, options)
    local success, content = pcall(JSON.stringify, data);
    if not success then
        local logger = Logger:new(modId);
        logger:error(string.format("Failed to serialize data to json for file: %s. Error: %s", filePath, content));
        return false;
    end

    return FileUtils.writeFile(filePath, content, modId, options);
end

return FileUtils
