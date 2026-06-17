local VehicleUtilsEx = {}

local scriptCache = nil

local function addScript(cache, script)
	if not script then
		return
	end

	local scriptName = script:getFullName()
	if scriptName and scriptName ~= "" then
		cache[scriptName] = script
	end
end

---@param excluded table|nil table keyed by full vehicle script name
---@param refresh boolean|nil
---@return table<string, boolean>
function VehicleUtilsEx.getVehicleScriptSet(excluded, refresh)
	if refresh or not scriptCache then
		scriptCache = {}
		local manager = getScriptManager and getScriptManager() or nil
		local scripts = manager and manager:getAllVehicleScripts() or nil
		if scripts then
			for i = 0, scripts:size() - 1 do
				addScript(scriptCache, scripts:get(i))
			end
		end
	end

	local result = {}
	for scriptName in pairs(scriptCache) do
		if not excluded or not excluded[scriptName] then
			result[scriptName] = true
		end
	end
	return result
end

---@param scriptName string|nil
---@param excluded table|nil
---@return boolean
function VehicleUtilsEx.isVehicleScriptValid(scriptName, excluded)
	if type(scriptName) ~= "string" or string.match(scriptName, "[^%w%._%-]") then
		return false
	end
	return VehicleUtilsEx.getVehicleScriptSet(excluded)[scriptName] == true
end

---@param callback fun(vehicle:BaseVehicle):nil
---@return integer count
function VehicleUtilsEx.forEachLoadedVehicle(callback)
	if not callback then
		return 0
	end

	local cell = getCell and getCell() or nil
	if not cell then
		return 0
	end

	local vehicles = cell:getVehicles()
	if not vehicles then
		return 0
	end

	local count = 0
	local iterator = vehicles:iterator()
	while iterator:hasNext() do
		local vehicle = iterator:next()
		if vehicle then
			count = count + 1
			callback(vehicle)
		end
	end
	return count
end

---@param x1 number?
---@param y1 number?
---@param x2 number?
---@param y2 number?
---@return integer count
function VehicleUtilsEx.countLoadedVehiclesInBounds(x1, y1, x2, y2)
	x1 = tonumber(x1)
	y1 = tonumber(y1)
	x2 = tonumber(x2)
	y2 = tonumber(y2)
	if not x1 or not y1 or not x2 or not y2 then
		return 0
	end

	if x2 < x1 then
		x1, x2 = x2, x1
	end
	if y2 < y1 then
		y1, y2 = y2, y1
	end

	local count = 0
	VehicleUtilsEx.forEachLoadedVehicle(function(vehicle)
		local vx = vehicle:getX()
		local vy = vehicle:getY()
		if vx >= x1 and vx <= x2 and vy >= y1 and vy <= y2 then
			count = count + 1
		end
	end)
	return count
end

---@param square IsoGridSquare|nil
---@param range integer|nil
---@return boolean
function VehicleUtilsEx.isSquareClearOfVehicles(square, range)
	if not square then
		return false
	end

	local function hasVehicleOn(testSquare)
		if not testSquare then
			return false
		end
		local objects = testSquare:getMovingObjects()
		for i = 0, objects:size() - 1 do
			local obj = objects:get(i)
			if obj and obj:getObjectName() == "Vehicle" then
				return true
			end
		end
		return false
	end

	if hasVehicleOn(square) then
		return false
	end

	range = tonumber(range) or 0
	local x = square:getX()
	local y = square:getY()
	local z = square:getZ()
	for adjX = x - range, x + range do
		for adjY = y - range, y + range do
			if adjX ~= x or adjY ~= y then
				if hasVehicleOn(getSquare(adjX, adjY, z)) then
					return false
				end
			end
		end
	end

	return true
end

---@param intervalString string|nil
---@param defaultMin integer|nil
---@param defaultMax integer|nil
---@return integer minQuality
---@return integer maxQuality
function VehicleUtilsEx.parseQualityRange(intervalString, defaultMin, defaultMax)
	local minQuality = tonumber(defaultMin) or 1
	local maxQuality = tonumber(defaultMax) or 100

	if intervalString then
		local values = {}
		for value in string.gmatch(tostring(intervalString), "([^;]+)") do
			local number = tonumber(value)
			if number then
				values[#values + 1] = number
			end
		end

		if #values == 1 then
			minQuality = values[1]
			maxQuality = values[1]
		elseif #values >= 2 then
			minQuality = math.min(values[1], values[2])
			maxQuality = math.max(values[1], values[2])
		end
	end

	minQuality = math.max(1, math.min(100, math.floor(minQuality)))
	maxQuality = math.max(1, math.min(100, math.floor(maxQuality)))
	return minQuality, maxQuality
end

---@param vehicle BaseVehicle
---@param minQuality integer
---@param maxQuality integer
---@param rand any|nil
---@return integer engineQuality
---@return integer engineLoudness
---@return integer enginePower
function VehicleUtilsEx.applyEngineQuality(vehicle, minQuality, maxQuality, rand)
	if not vehicle then
		return 0, 0, 0
	end

	local vehicleScript = vehicle:getScript()
	local engineQuality = 100
	local engineLoudness = 30
	local enginePower = vehicleScript and vehicleScript:getEngineForce() or 100

	if SandboxVars and SandboxVars.VehicleEasyUse then
		vehicle:setEngineFeature(engineQuality, engineLoudness, enginePower)
		return engineQuality, engineLoudness, enginePower
	end

	rand = rand or newrandom()
	minQuality, maxQuality = VehicleUtilsEx.parseQualityRange(nil, minQuality, maxQuality)

	local randomizedQuality = minQuality
	if maxQuality > minQuality then
		randomizedQuality = rand:random(minQuality, maxQuality)
	end

	local rollMin = math.max(minQuality, randomizedQuality - 10)
	local rollMax = math.min(maxQuality, randomizedQuality + 10)
	engineQuality = rollMin
	if rollMax > rollMin then
		engineQuality = rand:random(rollMin, rollMax)
	end
	engineQuality = math.max(minQuality, math.min(maxQuality, engineQuality))

	if vehicleScript then
		engineLoudness = (vehicleScript:getEngineLoudness() or 100) * (SandboxVars.ZombieAttractionMultiplier or 1)
		local qualityBoosted = math.min(engineQuality * 1.6, 100)
		local qualityModifier = math.max(qualityBoosted / 100, 0.6)
		enginePower = vehicleScript:getEngineForce() * qualityModifier
	end

	vehicle:setEngineFeature(engineQuality, engineLoudness, enginePower)
	return engineQuality, engineLoudness, enginePower
end

return VehicleUtilsEx
