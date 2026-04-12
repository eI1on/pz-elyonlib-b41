local MathUtils = {}

function MathUtils.clamp(value, minValue, maxValue)
	if minValue > maxValue then
		minValue, maxValue = maxValue, minValue
	end
	return math.min(math.max(value, minValue), maxValue)
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
