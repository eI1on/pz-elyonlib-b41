local TextUtils = {}

function TextUtils.trim(text)
	local value = tostring(text or ""):gsub("^%s+", "")
	return value:gsub("%s+$", "")
end

function TextUtils.measureWidth(font, text)
	local textManager = getTextManager and getTextManager() or nil
	text = tostring(text or "")
	if not textManager then
		return #text
	end
	font = font or (UIFont and UIFont.Small)
	if not font then
		return #text
	end
	return textManager:MeasureStringX(font, text)
end

function TextUtils.trimToWidth(font, text, maxWidth, ellipsis)
	text = tostring(text or ""):gsub("[%c]+", " ")
	if not maxWidth or maxWidth <= 0 then
		return ""
	end
	if TextUtils.measureWidth(font, text) <= maxWidth then
		return text
	end

	ellipsis = ellipsis or "..."
	if TextUtils.measureWidth(font, ellipsis) > maxWidth then
		return ""
	end

	local low = 0
	local high = #text
	while low < high do
		local mid = math.ceil((low + high) / 2)
		local candidate = TextUtils.trim(text:sub(1, mid)) .. ellipsis
		if TextUtils.measureWidth(font, candidate) <= maxWidth then
			low = mid
		else
			high = mid - 1
		end
	end

	return TextUtils.trim(text:sub(1, low)) .. ellipsis
end

function TextUtils.wrapLines(text, font, maxWidth, maxLines)
	local lines = {}
	if not maxWidth or maxWidth <= 0 then
		return lines
	end

	font = font or (UIFont and UIFont.Small)
	maxLines = maxLines or 2147483647
	text = tostring(text or ""):gsub("\r", "")

	for paragraph in (text .. "\n"):gmatch("([^\n]*)\n") do
		local line = ""
		for word in paragraph:gmatch("%S+") do
			local candidate = line == "" and word or (line .. " " .. word)
			if TextUtils.measureWidth(font, candidate) <= maxWidth then
				line = candidate
			elseif line == "" then
				lines[#lines + 1] = TextUtils.trimToWidth(font, word, maxWidth)
				if #lines >= maxLines then
					return lines
				end
			else
				lines[#lines + 1] = TextUtils.trimToWidth(font, line, maxWidth)
				if #lines >= maxLines then
					return lines
				end
				line = word
			end
		end

		if line ~= "" or paragraph == "" then
			lines[#lines + 1] = TextUtils.trimToWidth(font, line, maxWidth)
			if #lines >= maxLines then
				return lines
			end
		end
	end

	return lines
end

function TextUtils.fitToWidth(text, font, maxWidth)
	return TextUtils.trimToWidth(font, text, maxWidth, ".")
end

--- Sanitize a single path segment for sandbox save paths (avoid separators / reserved chars).
---@param segment string|nil
---@param maxLen integer|nil
---@return string
function TextUtils.sanitizeFileSegment(segment, maxLen)
	segment = tostring(segment or "")
	segment = segment:gsub("[%c%z]", "")
	segment = segment:gsub('[\\/:%*%?"<>|%[%]]', "_")
	segment = TextUtils.trim(segment)
	if segment == "." or segment == ".." then
		segment = "_"
	end
	maxLen = maxLen or 80
	if #segment > maxLen then
		segment = segment:sub(1, maxLen)
	end
	if segment == "" then
		segment = "_unknown"
	end
	return segment
end

return TextUtils
