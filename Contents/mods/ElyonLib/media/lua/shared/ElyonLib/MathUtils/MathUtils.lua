local MathUtils = {}

function MathUtils.clamp(value, minValue, maxValue)
	if minValue > maxValue then
		minValue, maxValue = maxValue, minValue
	end
	return math.min(math.max(value, minValue), maxValue)
end

function MathUtils.parseNumber(value, fallback, minValue, maxValue)
	local text = tostring(value or ""):gsub("^%s+", "")
	text = text:gsub("%s+$", "")
	local number = tonumber(text)
	if number == nil then
		number = fallback
	end
	if number == nil then
		return nil
	end
	if minValue ~= nil and maxValue ~= nil and minValue > maxValue then
		minValue, maxValue = maxValue, minValue
	end
	if minValue ~= nil and number < minValue then
		number = minValue
	end
	if maxValue ~= nil and number > maxValue then
		number = maxValue
	end
	return number
end

function MathUtils.lerp(a, b, t)
	return a + ((b - a) * t)
end

function MathUtils.easeOutCubic(t)
	t = MathUtils.clamp(t, 0, 1)
	local inverse = 1 - t
	return 1 - (inverse * inverse * inverse)
end

return MathUtils
