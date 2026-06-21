local IdUtils = {}

---Generate a compact timestamp-and-random-value identifier.
---@param separator string|nil
---@param minimum integer|nil
---@param maximum integer|nil
---@return string id
function IdUtils.generateTimestampId(separator, minimum, maximum)
	separator = separator or "_"
	minimum = math.floor(tonumber(minimum) or 100000)
	maximum = math.floor(tonumber(maximum) or 999999)
	if minimum > maximum then
		minimum, maximum = maximum, minimum
	end

	local randomValue
	if ZombRand then
		randomValue = ZombRand(minimum, maximum + 1)
	else
		randomValue = math.random(minimum, maximum)
	end

	return string.format("%d%s%d", os.time(), separator, randomValue)
end

return IdUtils
