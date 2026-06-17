local ColorUtils = {}

---@param h number
---@param s number
---@param l number
---@return number r
---@return number g
---@return number b
function ColorUtils.hslToRgb(h, s, l)
	local r, g, b

	if s == 0 then
		r, g, b = l, l, l
	else
		local function hue2rgb(p, q, t)
			if t < 0 then
				t = t + 1
			end
			if t > 1 then
				t = t - 1
			end
			if t < 1 / 6 then
				return p + (q - p) * 6 * t
			end
			if t < 1 / 2 then
				return q
			end
			if t < 2 / 3 then
				return p + (q - p) * (2 / 3 - t) * 6
			end
			return p
		end

		local q = l < 0.5 and l * (1 + s) or l + s - l * s
		local p = 2 * l - q

		r = hue2rgb(p, q, h + 1 / 3)
		g = hue2rgb(p, q, h)
		b = hue2rgb(p, q, h - 1 / 3)
	end

	return r, g, b
end

---@param r number
---@param g number
---@param b number
---@return number h
---@return number s
---@return number l
function ColorUtils.rgbToHsl(r, g, b)
	local maxValue = math.max(r, g, b)
	local minValue = math.min(r, g, b)
	local h, s, l = 0, 0, (maxValue + minValue) / 2

	if maxValue ~= minValue then
		local delta = maxValue - minValue
		s = l > 0.5 and delta / (2 - maxValue - minValue) or delta / (maxValue + minValue)

		if maxValue == r then
			h = (g - b) / delta + (g < b and 6 or 0)
		elseif maxValue == g then
			h = (b - r) / delta + 2
		else
			h = (r - g) / delta + 4
		end

		h = h / 6
	end

	return h, s, l
end

---@param r number|nil
---@param g number|nil
---@param b number|nil
---@param a number|nil
---@return table color
function ColorUtils.createColor(r, g, b, a)
	return {
		r = r or 0,
		g = g or 0,
		b = b or 0,
		a = a or 1,
	}
end

---@param color table|nil
---@param fallback table|nil
---@return table|nil color
function ColorUtils.copy(color, fallback)
	if not color and not fallback then
		return nil
	end

	local defaultColor = fallback or {}
	local source = color or defaultColor

	return {
		r = source.r ~= nil and source.r or defaultColor.r or 0,
		g = source.g ~= nil and source.g or defaultColor.g or 0,
		b = source.b ~= nil and source.b or defaultColor.b or 0,
		a = source.a ~= nil and source.a or defaultColor.a or 1,
	}
end

---@param color table
---@param factor number
---@return table color
function ColorUtils.lighten(color, factor)
	local h, s, l = ColorUtils.rgbToHsl(color.r, color.g, color.b)
	l = math.min(1, l + factor)
	local r, g, b = ColorUtils.hslToRgb(h, s, l)
	return ColorUtils.createColor(r, g, b, color.a)
end

---@param color table
---@param factor number
---@return table color
function ColorUtils.darken(color, factor)
	local h, s, l = ColorUtils.rgbToHsl(color.r, color.g, color.b)
	l = math.max(0, l - factor)
	local r, g, b = ColorUtils.hslToRgb(h, s, l)
	return ColorUtils.createColor(r, g, b, color.a)
end

return ColorUtils
