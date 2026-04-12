local TextUtils = {}

function TextUtils.fitToWidth(text, font, maxWidth)
	text = tostring(text or "")

	local textManager = getTextManager and getTextManager() or nil
	if text == "" or not textManager or not maxWidth then
		return text
	end

	font = font or (UIFont and UIFont.Small)
	if not font or textManager:MeasureStringX(font, text) <= maxWidth then
		return text
	end

	local suffix = "."
	local maxLength = math.min(string.len(text), 6)

	for length = maxLength, 1, -1 do
		local candidate = string.sub(text, 1, length) .. suffix
		if textManager:MeasureStringX(font, candidate) <= maxWidth then
			return candidate
		end
	end

	return string.sub(text, 1, 1)
end

return TextUtils
