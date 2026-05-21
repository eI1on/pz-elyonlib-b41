local WorldUtils = {}

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
