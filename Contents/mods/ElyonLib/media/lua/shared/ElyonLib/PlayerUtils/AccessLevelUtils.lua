---@alias AccessLevels "None"|"Observer"|"GM"|"Overseer"|"Moderator"|"Admin"

local AccessLevelUtils = {}

AccessLevelUtils.ORDER = {
	"None",
	"Observer",
	"GM",
	"Overseer",
	"Moderator",
	"Admin",
}

---@param accessLevel string|nil
---@return AccessLevels|nil
function AccessLevelUtils.normalize(accessLevel)
	accessLevel = tostring(accessLevel or "")
	accessLevel = string.gsub(accessLevel, "^%s*(.-)%s*$", "%1")

	if accessLevel == "" then
		return "None"
	end

	local lowerAccessLevel = string.lower(accessLevel)
	for i = 1, #AccessLevelUtils.ORDER do
		local knownAccessLevel = AccessLevelUtils.ORDER[i]
		if lowerAccessLevel == string.lower(knownAccessLevel) then
			return knownAccessLevel
		end
	end

	return nil
end

---@param playerNum integer|nil
---@return IsoPlayer|nil playerObj
function AccessLevelUtils.getPlayer(playerNum)
	playerNum = playerNum or 0

	if playerNum == 0 and getPlayer then
		return getPlayer()
	end

	if getSpecificPlayer then
		return getSpecificPlayer(playerNum)
	end

	return nil
end

---@param playerNum integer|nil
---@param playerObj IsoPlayer|nil
---@return AccessLevels
function AccessLevelUtils.getPlayerAccessLevel(playerNum, playerObj)
	if not playerObj then
		playerObj = AccessLevelUtils.getPlayer(playerNum)
	end

	if playerObj and playerObj.getAccessLevel then
		return AccessLevelUtils.normalize(playerObj:getAccessLevel()) or "None"
	end

	return "None"
end

---@return boolean
function AccessLevelUtils.isSinglePlayer()
	if isClient then
		return not isClient()
	end

	return true
end

---@param accessLevel string|nil
---@param minimumAccessLevel string|nil
---@return boolean
function AccessLevelUtils.isAtLeast(accessLevel, minimumAccessLevel)
	if not minimumAccessLevel then
		return true
	end

	local playerAccessLevel = AccessLevelUtils.normalize(accessLevel)
	local requiredAccessLevel = AccessLevelUtils.normalize(minimumAccessLevel)
	if not playerAccessLevel or not requiredAccessLevel then
		return false
	end

	local requiredReached = false
	for i = 1, #AccessLevelUtils.ORDER do
		local currentAccessLevel = AccessLevelUtils.ORDER[i]
		if currentAccessLevel == requiredAccessLevel then
			requiredReached = true
		end
		if currentAccessLevel == playerAccessLevel then
			return requiredReached
		end
	end

	return false
end

---@param playerNum integer|nil
---@param minimumAccessLevel string|nil
---@param playerObj IsoPlayer|nil
---@return boolean
function AccessLevelUtils.isPlayerAtLeast(playerNum, minimumAccessLevel, playerObj)
	return AccessLevelUtils.isAtLeast(AccessLevelUtils.getPlayerAccessLevel(playerNum, playerObj), minimumAccessLevel)
end

--- Returns true when the given player object has Admin access (or any higher level).
--- In singleplayer, always returns true.
--- When playerObj is nil, falls back to the client-side isAdmin() / getAccessLevel() globals.
---@param playerObj IsoPlayer|nil
---@return boolean
function AccessLevelUtils.hasAdminAccess(playerObj)
	if AccessLevelUtils.isSinglePlayer() then
		return true
	end

	if playerObj and playerObj.getAccessLevel then
		return AccessLevelUtils.normalize(playerObj:getAccessLevel()) == "Admin"
	end

	if isAdmin and isAdmin() then
		return true
	end

	return AccessLevelUtils.normalize(getAccessLevel()) == "Admin" or false
end

return AccessLevelUtils
