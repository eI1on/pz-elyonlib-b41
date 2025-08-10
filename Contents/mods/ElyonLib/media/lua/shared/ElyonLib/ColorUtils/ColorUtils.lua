local ColorUtils = {}

---Convert HSL color values to RGB
---@param h number Hue (0-1)
---@param s number Saturation (0-1)
---@param l number Lightness (0-1)
---@return number r Red component (0-1)
---@return number g Green component (0-1)
---@return number b Blue component (0-1)
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

---Convert RGB to HSL
---@param r number Red component (0-1)
---@param g number Green component (0-1)
---@param b number Blue component (0-1)
---@return number h Hue (0-1)
---@return number s Saturation (0-1)
---@return number l Lightness (0-1)
function ColorUtils.rgbToHsl(r, g, b)
	local max, min = math.max(r, g, b), math.min(r, g, b)
	local h, s, l = 0, 0, (max + min) / 2

	if max ~= min then
		local d = max - min
		s = l > 0.5 and d / (2 - max - min) or d / (max + min)

		if max == r then
			h = (g - b) / d + (g < b and 6 or 0)
		elseif max == g then
			h = (b - r) / d + 2
		elseif max == b then
			h = (r - g) / d + 4
		end

		h = h / 6
	end

	return h, s, l
end

---Create a color table with RGBA values
---@param r number Red component (0-1)
---@param g number Green component (0-1)
---@param b number Blue component (0-1)
---@param a number Alpha component (0-1)
---@return table color Color table with r, g, b, a fields
function ColorUtils.createColor(r, g, b, a)
	return {
		r = r or 0,
		g = g or 0,
		b = b or 0,
		a = a or 1,
	}
end

---Lighten a color by a factor
---@param color table Color table with r, g, b, a fields
---@param factor number Lighten factor (0-1)
---@return table color Lightened color
function ColorUtils.lighten(color, factor)
	local h, s, l = ColorUtils.rgbToHsl(color.r, color.g, color.b)
	l = math.min(1, l + factor)
	local r, g, b = ColorUtils.hslToRgb(h, s, l)
	return ColorUtils.createColor(r, g, b, color.a)
end

---Darken a color by a factor
---@param color table Color table with r, g, b, a fields
---@param factor number Darken factor (0-1)
---@return table color Darkened color
function ColorUtils.darken(color, factor)
	local h, s, l = ColorUtils.rgbToHsl(color.r, color.g, color.b)
	l = math.max(0, l - factor)
	local r, g, b = ColorUtils.hslToRgb(h, s, l)
	return ColorUtils.createColor(r, g, b, color.a)
end

return ColorUtils
