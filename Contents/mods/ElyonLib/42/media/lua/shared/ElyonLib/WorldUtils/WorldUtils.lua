local WorldUtils = {}

local VEHICLE_ZONE_CELL_SIZE = 256

local function toInt(value, defaultValue)
	value = tonumber(value)
	if value == nil then
		return defaultValue
	end
	return math.floor(value)
end

--- Resolve a grid square from tile coordinates (current cell).
---@param x number
---@param y number
---@param z number|nil (default 0)
---@return IsoGridSquare|nil
function WorldUtils.getSquareFromWorldCoords(x, y, z)
	local cell = getWorld and getWorld():getCell() or nil
	if not cell then
		return nil
	end
	z = tonumber(z) or 0
	x = math.floor(tonumber(x) or 0)
	y = math.floor(tonumber(y) or 0)
	return cell:getGridSquare(x, y, z)
end

--- Move player onto the center of the square (client-side).
---@param player IsoPlayer|nil
---@param square IsoGridSquare|nil
---@return boolean ok
function WorldUtils.teleportPlayerToSquare(player, square)
	if not player or not square then
		return false
	end
	local px = square:getX() + 0.5
	local py = square:getY() + 0.5
	local pz = square:getZ()
	player:setX(px)
	player:setY(py)
	player:setZ(pz)
	player:setLx(px)
	player:setLy(py)
	player:setLz(pz)
	return true
end

---@return integer
function WorldUtils.getVehicleZoneCellSize()
	if getCellSizeInSquares then
		local size = getCellSizeInSquares()
		if tonumber(size) then
			return math.floor(tonumber(size))
		end
	end

	return VEHICLE_ZONE_CELL_SIZE
end

---@param cellx integer
---@param celly integer
---@return integer x1
---@return integer y1
---@return integer x2
---@return integer y2
function WorldUtils.getVehicleZoneCellBounds(cellx, celly)
	cellx = toInt(cellx, 0)
	celly = toInt(celly, 0)
	local cellSize = WorldUtils.getVehicleZoneCellSize()
	local x1 = cellx * cellSize
	local y1 = celly * cellSize
	return x1, y1, x1 + cellSize - 1, y1 + cellSize - 1
end

---@param zone any
---@return string|nil
function WorldUtils.getZoneName(zone)
	if not zone then
		return nil
	end

	local name = zone:getName()
	if name ~= nil then
		return tostring(name)
	end

	return nil
end

---@param zone any
---@return integer|nil x
---@return integer|nil y
---@return integer|nil w
---@return integer|nil h
---@return integer|nil z
function WorldUtils.getZoneBounds(zone)
	if not zone then
		return nil, nil, nil, nil, nil
	end

	local x, y, w, h, z = zone:getX(), zone:getY(), zone:getWidth(), zone:getHeight(), zone:getZ()
	if x ~= nil and y ~= nil and w ~= nil and h ~= nil then
		return tonumber(x), tonumber(y), tonumber(w), tonumber(h), tonumber(z) or 0
	end

	return nil, nil, nil, nil, nil
end

---@param zone any
---@return string|nil
function WorldUtils.getZoneKey(zone)
	local x, y, w, h, z = WorldUtils.getZoneBounds(zone)
	if not x or not y or not w or not h then
		return nil
	end

	return string.format("%s:%d:%d:%d:%d:%d", WorldUtils.getZoneName(zone) or "", x, y, z or 0, w, h)
end

---@param zone any
---@return string|nil
function WorldUtils.getVehicleZoneDirection(zone)
	if not zone then
		return nil
	end

	local direction = zone.dir
	if direction ~= nil then
		return tostring(direction)
	end

	return nil
end

---@param x number
---@param y number
---@param z number|nil
---@return any|nil vehicleZone
function WorldUtils.getVehicleZoneAt(x, y, z)
	if not getVehicleZoneAt then
		return nil
	end

	x = math.floor(tonumber(x) or 0)
	y = math.floor(tonumber(y) or 0)
	z = math.floor(tonumber(z) or 0)
	return getVehicleZoneAt(x, y, z)
end

---@param square IsoGridSquare|nil
---@return any|nil vehicleZone
function WorldUtils.getVehicleZoneAtSquare(square)
	if not square then
		return nil
	end

	return WorldUtils.getVehicleZoneAt(square:getX(), square:getY(), square:getZ())
end

---Find one currently-loaded square inside a B42 vehicle zone without enumerating hidden Java lists.
---@param x1 number
---@param y1 number
---@param x2 number
---@param y2 number
---@param z number|nil
---@param maxAttempts integer|nil
---@param rand any|nil
---@param validator fun(square:any, zone:any):boolean|nil
---@return IsoGridSquare|nil square
---@return any|nil vehicleZone
function WorldUtils.findLoadedVehicleZoneSquareInArea(x1, y1, x2, y2, z, maxAttempts, rand, validator)
	local cell = getCell and getCell() or nil
	if not cell then
		return nil, nil
	end

	x1 = math.floor(tonumber(x1) or 0)
	y1 = math.floor(tonumber(y1) or 0)
	x2 = math.floor(tonumber(x2) or x1)
	y2 = math.floor(tonumber(y2) or y1)
	z = math.floor(tonumber(z) or 0)

	if x2 < x1 then
		x1, x2 = x2, x1
	end
	if y2 < y1 then
		y1, y2 = y2, y1
	end

	maxAttempts = math.max(1, math.floor(tonumber(maxAttempts) or 1))
	local rng = rand or newrandom()

	for _ = 1, maxAttempts do
		local x = rng:random(x1, x2 + 1)
		local y = rng:random(y1, y2 + 1)
		local square = cell:getGridSquare(x, y, z)
		if square and square:getChunk() ~= nil then
			local zone = WorldUtils.getVehicleZoneAtSquare(square)
			if zone and (not validator or validator(square, zone)) then
				return square, zone
			end
		end
	end

	return nil, nil
end

---@return any|nil metaGrid
function WorldUtils.getMetaGrid()
	local world = getWorld and getWorld() or nil
	return world and world:getMetaGrid() or nil
end

---B42 does not expose a supported Lua API for enumerating all vehicle zones.
---Use getVehicleZoneAt/getVehicleZoneAtSquare or bounded loaded-square probing instead.
---@return nil
function WorldUtils.getAllVehicleZones()
	return nil
end

function WorldUtils.buildVehicleZoneCellCache()
end

---Compatibility stub. B42 vehicle-zone enumeration is not exposed to Lua.
---@param cellx integer
---@param celly integer
---@return table vehicleZones
function WorldUtils.getVehicleZonesForCell(cellx, celly)
	return {}
end

function WorldUtils.clearVehicleZoneCache()
end

return WorldUtils
