local PlayerUtils = {}

--- Returns a stable string key for the given player object.
--- Resolution order: username > displayName > onlineId > tostring(player).
--- Returns nil only when playerObj is nil.
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

	if playerObj.getOnlineID then
		local onlineId = tonumber(playerObj:getOnlineID())
		if onlineId and onlineId >= 0 then
			return "online-" .. tostring(onlineId)
		end
	end

	if playerObj.getPlayerNum then
		return "player-" .. tostring(playerObj:getPlayerNum())
	end

	return nil
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
				local key = PlayerUtils.getPlayerKey(player)
				if key and not seen[key] then
					seen[key] = true
					result[#result + 1] = player
				end
			end
		end
	end

	local localPlayer = getPlayer and getPlayer() or nil
	if localPlayer then
		local key = PlayerUtils.getPlayerKey(localPlayer)
		if key and not seen[key] then
			seen[key] = true
			result[#result + 1] = localPlayer
		end
	end

	table.sort(result, function(a, b)
		return tostring(PlayerUtils.getPlayerKey(a)):lower() < tostring(PlayerUtils.getPlayerKey(b)):lower()
	end)

	return result
end

--- Returns the first online player whose key matches the given username (case-sensitive).
---@param username string
---@return IsoPlayer|nil
function PlayerUtils.getOnlinePlayerByUsername(username)
	username = tostring(username or ""):gsub("^%s*(.-)%s*$", "%1")
	if username == "" then
		return nil
	end

	local players = PlayerUtils.getOnlinePlayers()
	for i = 1, #players do
		if PlayerUtils.getPlayerKey(players[i]) == username then
			return players[i]
		end
	end

	return nil
end

return PlayerUtils
