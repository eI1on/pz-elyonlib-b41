local MathUtils = require("ElyonLib/MathUtils/MathUtils")
local TextUtils = require("ElyonLib/TextUtils/TextUtils")
local LayoutUtils = require("ElyonLib/UI/Layout/LayoutUtils")

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

UIUtils.setVisible = LayoutUtils.setVisible
UIUtils.setBounds = LayoutUtils.setBounds

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

function UIUtils.getVisibleListScrollBarWidth(list)
	if list and list.vscroll and list.isVScrollBarVisible and list:isVScrollBarVisible() then
		return list.vscroll:getWidth()
	end
	return 0
end

function UIUtils.getListContentRight(list, rightInset)
	if not list then
		return 0
	end
	return list:getWidth() - UIUtils.getVisibleListScrollBarWidth(list) - (rightInset or 0)
end

function UIUtils.syncListScrollBar(list)
	if not list or not list.vscroll then
		return
	end

	local scrollWidth = list.vscroll:getWidth()
	list.vscroll:setX(list:getWidth() - scrollWidth)
	list.vscroll:setY(0)
	list.vscroll:setHeight(list:getHeight())
	list.vscroll:recalcSize()
end

function UIUtils.setListGeometry(list, x, y, width, height)
	if not list then
		return
	end

	LayoutUtils.setBounds(list, x, y, width, height)
	list:recalcSize()
	UIUtils.syncListScrollBar(list)
end

function UIUtils.getElementFrameRect(element, padding)
	if not element then
		return LayoutUtils.rect(0, 0, 0, 0)
	end

	padding = tonumber(padding) or 0
	return LayoutUtils.rect(
		element:getX() - padding,
		element:getY() - padding,
		element:getWidth() + (padding * 2),
		element:getHeight() + (padding * 2)
	)
end

function UIUtils.getListStencilBounds(list, y, height, scrollbarClipPadding)
	if not list then
		return nil
	end

	local bordered = list.drawBorder == true
	local borderInset = bordered and 1 or 0
	local yScroll = list.getYScroll and list:getYScroll() or 0
	local clipX = borderInset
	local clipY = math.max(0, y + yScroll)
	local scrollbarVisible = list.vscroll and list.isVScrollBarVisible and list:isVScrollBarVisible()
	local clipX2 = scrollbarVisible and (list.vscroll.x + (scrollbarClipPadding or 0))
		or (list:getWidth() - borderInset)
	local clipY2 = math.min(list:getHeight() - borderInset, y + height + yScroll)

	if clipX2 <= clipX or clipY2 <= clipY then
		return nil
	end

	return clipX, clipY, clipX2 - clipX, clipY2 - clipY
end

function UIUtils.drawClippedListRow(list, y, height, drawFn, scrollbarClipPadding)
	local clipX, clipY, clipW, clipH = UIUtils.getListStencilBounds(list, y, height, scrollbarClipPadding)
	if not clipX then
		return false
	end

	list:setStencilRect(clipX, clipY, clipW, clipH)
	drawFn()
	list:clearStencilRect()
	list:repaintStencilRect(clipX, clipY, clipW, clipH)
	return true
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

function UIUtils.getTextureSize(texture)
	if not texture then
		return 0, 0
	end

	local width = texture.getWidthOrig and texture:getWidthOrig() or texture:getWidth()
	local height = texture.getHeightOrig and texture:getHeightOrig() or texture:getHeight()
	return width or 0, height or 0
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

function UIUtils.drawFieldLabel(panel, text, control, width, color, font, gap)
	if not panel or not control then
		return
	end

	font = font or (UIFont and UIFont.Small)
	color = color or { r = 1, g = 1, b = 1, a = 1 }
	gap = gap or 4
	local textManager = getTextManager and getTextManager() or nil
	local fontHeight = textManager and font and textManager:getFontHeight(font) or 10
	panel:drawText(
		TextUtils.trimToWidth(font, text, width or control:getWidth()),
		control:getX(),
		control:getY() - fontHeight - gap,
		color.r or 1,
		color.g or 1,
		color.b or 1,
		color.a or 1,
		font
	)
end

return UIUtils
