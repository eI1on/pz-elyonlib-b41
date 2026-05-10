local Logger = require("ElyonLib/Core/ElyonLibLogger")
local NetUtils = {}

local function getLocalCommandPlayer()
	return (getPlayer and getPlayer()) or (getSpecificPlayer and getSpecificPlayer(0)) or nil
end

local function sendClientCommandSafe(moduleName, command, args)
	local player = getLocalCommandPlayer()
	if player then
		sendClientCommand(player, moduleName, command, args)
		return true
	end

	Logger:error(
		string.format("NetUtils: no local player for command '%s' in '%s'", tostring(command), tostring(moduleName))
	)
	return false
end

--- Executes a named server command.
---
--- When running as a network client the command is sent over the wire with
--- sendClientCommand(playerObj, moduleName, command, args)
---
--- When running locally (singleplayer or listen-server) the corresponding
--- ServerCommands handler is called directly, avoiding a round-trip
--- The server module is expected to expose:
---   serverModule.Server.ServerCommands[command](player, args)
---
---@param moduleName string         The mod's MODULE constant used as the network channel name
---@param serverRequirePath string  require() path for the mod's server file, e.g. "DailyRewards/Server"
---@param command string            Command name key in ServerCommands
---@param args table|nil            Payload table (will default to {})
---@return boolean success
function NetUtils.executeCommand(moduleName, serverRequirePath, command, args)
	args = args or {}

	if isClient() and not isServer() then
		return sendClientCommandSafe(moduleName, command, args)
	end

	local serverModule = require(serverRequirePath)
	if type(serverModule) ~= "table" then
		Logger:error(string.format("NetUtils.executeCommand: failed to require '%s'", tostring(serverRequirePath)))
		return false
	end

	local commands = serverModule.Server and serverModule.Server.ServerCommands
	if type(commands) ~= "table" then
		Logger:error(
			string.format("NetUtils.executeCommand: ServerCommands not found in '%s'", tostring(serverRequirePath))
		)
		return false
	end

	local handler = commands[command]
	if type(handler) ~= "function" then
		Logger:error(
			string.format(
				"NetUtils.executeCommand: no handler for command '%s' in '%s'",
				tostring(command),
				tostring(serverRequirePath)
			)
		)
		return false
	end

	local player = getLocalCommandPlayer()
	handler(player, args)
	return true
end

--- Executes a named server command against modules that expose a single
--- processCommand(command, player, args) function instead of a ServerCommands
--- table. This keeps SP/local tests on the same validation path as MP while
--- preserving sendClientCommand for network clients.
---@param moduleName string
---@param serverRequirePath string
---@param command string
---@param args table|nil
---@param processFunctionName string|nil Defaults to "processCommand"
---@return boolean success
function NetUtils.executeProcessCommand(moduleName, serverRequirePath, command, args, processFunctionName)
	args = args or {}

	if isClient and isClient() and not (isServer and isServer()) then
		return sendClientCommandSafe(moduleName, command, args)
	end

	local serverModule = require(serverRequirePath)
	if type(serverModule) ~= "table" then
		Logger:error(
			string.format("NetUtils.executeProcessCommand: failed to require '%s'", tostring(serverRequirePath))
		)
		return false
	end

	local fnName = processFunctionName or "processCommand"
	local handler = serverModule[fnName]
	if type(handler) ~= "function" then
		Logger:error(
			string.format(
				"NetUtils.executeProcessCommand: no '%s' in '%s'",
				tostring(fnName),
				tostring(serverRequirePath)
			)
		)
		return false
	end

	local player = getLocalCommandPlayer()
	handler(command, player, args)
	return true
end

return NetUtils
