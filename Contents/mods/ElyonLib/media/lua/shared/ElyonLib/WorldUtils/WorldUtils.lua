local WorldUtils = {}

function WorldUtils.normalizeRectangle(rectangle)
	if type(rectangle) ~= "table" then
		return nil
	end

	local x1 = tonumber(rectangle.x1)
	local y1 = tonumber(rectangle.y1)
	local x2 = tonumber(rectangle.x2)
	local y2 = tonumber(rectangle.y2)
	if not (x1 and y1 and x2 and y2) then
		return nil
	end

	return {
		x1 = math.floor(math.min(x1, x2)),
		y1 = math.floor(math.min(y1, y2)),
		x2 = math.floor(math.max(x1, x2)),
		y2 = math.floor(math.max(y1, y2)),
	}
end

function WorldUtils.isPointInRectangle(x, y, rectangle)
	local normalized = WorldUtils.normalizeRectangle(rectangle)
	x = tonumber(x)
	y = tonumber(y)
	if not normalized or not x or not y then
		return false
	end

	x = math.floor(x)
	y = math.floor(y)
	return x >= normalized.x1 and x <= normalized.x2 and y >= normalized.y1 and y <= normalized.y2
end

function WorldUtils.isPlayerInRectangle(player, rectangle)
	return player ~= nil
		and player.getX ~= nil
		and player.getY ~= nil
		and WorldUtils.isPointInRectangle(player:getX(), player:getY(), rectangle)
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

return WorldUtils
