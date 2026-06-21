local PlayerUtils = {}

local function trim(value)
	return tostring(value or ""):gsub("^%s*(.-)%s*$", "%1")
end

---@param playerNum integer|nil
---@return IsoPlayer|nil
function PlayerUtils.getLocalPlayer(playerNum)
	playerNum = playerNum or 0
	if playerNum == 0 and getPlayer then
		local player = getPlayer()
		if player then
			return player
		end
	end
	return getSpecificPlayer and getSpecificPlayer(playerNum) or nil
end

---@param playerObj IsoPlayer|nil
---@return string|nil
function PlayerUtils.getUsername(playerObj)
	if not playerObj or not playerObj.getUsername then
		return nil
	end

	local username = trim(playerObj:getUsername())
	return username ~= "" and username or nil
end

---@param playerObj IsoPlayer|nil
---@param fallback string|nil
---@return string
function PlayerUtils.getDisplayName(playerObj, fallback)
	if not playerObj then
		return fallback or "Unknown"
	end

	if playerObj.getDisplayName then
		local displayName = trim(playerObj:getDisplayName())
		if displayName ~= "" then
			return displayName
		end
	end

	local username = PlayerUtils.getUsername(playerObj)
	if username then
		return username
	end

	if playerObj.getDescriptor then
		local descriptor = playerObj:getDescriptor()
		if descriptor then
			local fullName = trim(string.format("%s %s", descriptor:getForename() or "", descriptor:getSurname() or ""))
			if fullName ~= "" then
				return fullName
			end
		end
	end

	return fallback or "Unknown"
end

---Returns a unique runtime key without ever falling back to display name.
---Resolution order: username > online ID > local player number > tostring(player).
---@param playerObj IsoPlayer|nil
---@return string|nil
function PlayerUtils.getUniquePlayerKey(playerObj)
	if not playerObj then
		return nil
	end

	local username = PlayerUtils.getUsername(playerObj)
	if username then
		return username
	end

	if playerObj.getOnlineID then
		local onlineId = tonumber(playerObj:getOnlineID())
		if onlineId and onlineId >= 0 then
			return "online-" .. tostring(onlineId)
		end
	end

	if playerObj.getPlayerNum then
		return "player-" .. tostring(playerObj:getPlayerNum())
	end

	return tostring(playerObj)
end

---@param displayName any
---@param playerKey any
---@param fallback string|nil
---@return string
function PlayerUtils.formatDisplayLabel(displayName, playerKey, fallback)
	displayName = trim(displayName)
	playerKey = trim(playerKey)
	local syntheticKey = playerKey:find("^player%-") or playerKey:find("^online%-")

	if displayName ~= "" and playerKey ~= "" and not syntheticKey and displayName ~= playerKey then
		return string.format("%s [%s]", displayName, playerKey)
	end
	if displayName ~= "" then
		return displayName
	end
	if playerKey ~= "" then
		return playerKey
	end
	return fallback or "Unknown"
end

---Returns the legacy username-or-display-name key used by existing ElyonLib consumers.
---New code that persists player identity should use getUniquePlayerKey instead.
---@param playerObj IsoPlayer|nil
---@return string|nil
function PlayerUtils.getPlayerKey(playerObj)
	if not playerObj then
		return nil
	end

	if playerObj.getUsername then
		local username = tostring(playerObj:getUsername() or ""):gsub("^%s*(.-)%s*$", "%1")
		if username ~= "" then
			return username
		end
	end

	if playerObj.getDisplayName then
		local displayName = tostring(playerObj:getDisplayName() or ""):gsub("^%s*(.-)%s*$", "%1")
		if displayName ~= "" then
			return displayName
		end
	end

	return nil
end

---@param playerObj IsoPlayer|nil
---@param playerKey any
---@return boolean
function PlayerUtils.matchesPlayerKey(playerObj, playerKey)
	if playerKey == nil then
		return false
	end

	local resolvedKey = PlayerUtils.getPlayerKey(playerObj)
	return resolvedKey ~= nil and tostring(resolvedKey) == tostring(playerKey)
end

---@param data table|nil
---@param playerObj IsoPlayer|nil
---@param keyField string|nil
---@return boolean
function PlayerUtils.isDataForPlayer(data, playerObj, keyField)
	if type(data) ~= "table" then
		return false
	end

	return PlayerUtils.matchesPlayerKey(playerObj, data[keyField or "playerId"])
end

--- Returns a sorted list of all currently online players, deduped by player key.
--- Includes the local player when present.
---@return IsoPlayer[]
function PlayerUtils.getOnlinePlayers()
	local result = {}
	local seen = {}

	if getOnlinePlayers then
		local onlinePlayers = getOnlinePlayers()
		if onlinePlayers then
			for i = 0, onlinePlayers:size() - 1 do
				local player = onlinePlayers:get(i)
				local key = PlayerUtils.getUniquePlayerKey(player)
				if key and not seen[key] then
					seen[key] = true
					result[#result + 1] = player
				end
			end
		end
	end

	local localPlayer = PlayerUtils.getLocalPlayer()
	if localPlayer then
		local key = PlayerUtils.getUniquePlayerKey(localPlayer)
		if key and not seen[key] then
			seen[key] = true
			result[#result + 1] = localPlayer
		end
	end

	table.sort(result, function(a, b)
		local aDisplay = PlayerUtils.getDisplayName(a):lower()
		local bDisplay = PlayerUtils.getDisplayName(b):lower()
		if aDisplay ~= bDisplay then
			return aDisplay < bDisplay
		end
		return tostring(PlayerUtils.getUniquePlayerKey(a)):lower()
			< tostring(PlayerUtils.getUniquePlayerKey(b)):lower()
	end)

	return result
end

--- Returns the first online player whose key matches the given username (case-sensitive).
---@param username string
---@return IsoPlayer|nil
function PlayerUtils.getOnlinePlayerByUsername(username)
	username = trim(username)
	if username == "" then
		return nil
	end

	local players = PlayerUtils.getOnlinePlayers()
	for i = 1, #players do
		if PlayerUtils.getUsername(players[i]) == username then
			return players[i]
		end
	end

	return nil
end

---@param playerKey any
---@return IsoPlayer|nil
function PlayerUtils.findOnlinePlayerByKey(playerKey)
	playerKey = trim(playerKey)
	if playerKey == "" then
		return nil
	end

	local players = PlayerUtils.getOnlinePlayers()
	for i = 1, #players do
		if PlayerUtils.getUniquePlayerKey(players[i]) == playerKey then
			return players[i]
		end
	end
	return nil
end

return PlayerUtils
