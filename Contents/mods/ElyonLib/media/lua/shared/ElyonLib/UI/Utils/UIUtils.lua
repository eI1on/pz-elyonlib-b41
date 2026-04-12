local MathUtils = require("ElyonLib/MathUtils/MathUtils")

local UIUtils = {}

function UIUtils.frameStep(scale)
	local millis = UIManager and UIManager.getMillisSinceLastRender and UIManager.getMillisSinceLastRender() or 33.3
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

return UIUtils
