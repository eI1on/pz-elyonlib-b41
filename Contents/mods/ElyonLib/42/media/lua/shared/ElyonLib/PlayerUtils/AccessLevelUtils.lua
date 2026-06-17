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

---@param playerObj IsoPlayer|nil
---@return any|nil
function AccessLevelUtils.getPlayerRole(playerObj)
	if not playerObj or not playerObj.getRole then
		return nil
	end

	return playerObj:getRole()
end

---@param playerObj IsoPlayer|nil
---@return AccessLevels|nil
function AccessLevelUtils.getPlayerRoleAccessLevel(playerObj)
	local role = AccessLevelUtils.getPlayerRole(playerObj)
	if role and role.getName then
		local roleAccessLevel = AccessLevelUtils.normalize(role:getName())
		if roleAccessLevel then
			return roleAccessLevel
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

	local playerAccessLevel = AccessLevelUtils.getPlayerRoleAccessLevel(playerObj)
	if playerAccessLevel and playerAccessLevel ~= "None" then
		return playerAccessLevel
	end

	if AccessLevelUtils.isSinglePlayer() then
		return "Admin"
	end

	return "None"
end

---@return boolean
function AccessLevelUtils.isSinglePlayer()
	if isMultiplayer then
		return isMultiplayer() ~= true
	end

	local runningClient = isClient and isClient() == true or false
	local runningServer = isServer and isServer() == true or false
	return not runningClient and not runningServer
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
---@param playerObj IsoPlayer|nil
---@return boolean
function AccessLevelUtils.hasAdminAccess(playerObj)
	if AccessLevelUtils.isSinglePlayer() then
		return true
	end

	local playerAccessLevel = AccessLevelUtils.getPlayerRoleAccessLevel(playerObj)
	if playerAccessLevel then
		return playerAccessLevel == "Admin"
	end

	local role = AccessLevelUtils.getPlayerRole(playerObj)
	if role and role.hasAdminPower and role:hasAdminPower() then
		return true
	end

	return false
end

return AccessLevelUtils
