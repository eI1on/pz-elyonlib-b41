local MathUtils = require("ElyonLib/MathUtils/MathUtils")
local TextUtils = require("ElyonLib/TextUtils/TextUtils")

local UIUtils = {}

function UIUtils.frameMillis(defaultMillis)
	local millis = nil
	if UIManager and UIManager.getMillisSinceLastRender then
		millis = UIManager.getMillisSinceLastRender()
	end
	return millis or defaultMillis or 33.3
end

function UIUtils.frameSeconds(defaultMillis)
	return UIUtils.frameMillis(defaultMillis) / 1000
end

function UIUtils.frameStep(scale)
	local millis = UIUtils.frameMillis(33.3)
	return MathUtils.clamp(scale * (millis / 33.3), 0, 1)
end

function UIUtils.playSound(sound)
	local soundManager = getSoundManager and getSoundManager() or nil
	if soundManager then
		soundManager:playUISound(sound)
	end
end

function UIUtils.isScreenPointInElement(element, x, y)
	if not element or not element.getIsVisible or not element:getIsVisible() then
		return false
	end

	local left = element:getAbsoluteX()
	local top = element:getAbsoluteY()

	return x >= left and x < left + element:getWidth() and y >= top and y < top + element:getHeight()
end

function UIUtils.setVisible(element, visible)
	if element then
		element:setVisible(visible == true)
	end
end

function UIUtils.setBounds(element, x, y, width, height)
	if not element then
		return
	end
	element:setX(x)
	element:setY(y)
	if width ~= nil then
		element:setWidth(width)
	end
	if height ~= nil then
		element:setHeight(height)
	end
end

function UIUtils.getListScrollBarWidth(list, defaultWidth)
	if list and list.vscroll and list.vscroll.getWidth then
		return list.vscroll:getWidth()
	end
	return defaultWidth or 20
end

function UIUtils.getListContentWidth(list, reserveScrollbar, defaultScrollBarWidth)
	if not list then
		return 0
	end
	local width = list:getWidth()
	if list.isVScrollBarVisible and list:isVScrollBarVisible() then
		return width - UIUtils.getListScrollBarWidth(list, defaultScrollBarWidth)
	end
	if reserveScrollbar then
		return width - UIUtils.getListScrollBarWidth(list, defaultScrollBarWidth)
	end
	return width
end

function UIUtils.getEntryText(entry)
	if not entry then
		return ""
	end
	if entry.getInternalText then
		local text = entry:getInternalText()
		if text ~= nil then
			return tostring(text)
		end
	end
	if entry.getText then
		local text = entry:getText()
		if text ~= nil then
			return tostring(text)
		end
	end
	return ""
end

function UIUtils.setEntryText(entry, text)
	if entry then
		entry:setText(tostring(text or ""))
	end
end

function UIUtils.drawWrappedText(panel, text, x, y, maxWidth, color, font, maxLines, lineHeight)
	if not panel then
		return y
	end

	font = font or (UIFont and UIFont.Small)
	color = color or { r = 1, g = 1, b = 1, a = 1 }
	if lineHeight == nil then
		local textManager = getTextManager and getTextManager() or nil
		lineHeight = textManager and font and (textManager:getFontHeight(font) + 3) or 14
	end

	local lines = TextUtils.wrapLines(text, font, maxWidth, maxLines or 8)
	for i = 1, #lines do
		panel:drawText(lines[i], x, y, color.r or 1, color.g or 1, color.b or 1, color.a or 1, font)
		y = y + lineHeight
	end

	return y
end

return UIUtils
