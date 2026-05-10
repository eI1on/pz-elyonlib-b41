-- Reusable layout helpers for Project Zomboid UI panels.
-- All functions operate on ISUIElement-derived objects and return final
-- geometry so callers can chain positions.
--
-- Usage:
--   local Layout = require("ElyonLib/UI/Layout/LayoutUtils")

local LayoutUtils = {}

-- ---------------------------------------------------------------------------
-- Geometry helpers
-- ---------------------------------------------------------------------------

-- set position and size on any ISUIElement in one call.
function LayoutUtils.setBounds(control, x, y, width, height)
	if not control then
		return
	end
	x = math.floor(tonumber(x) or 0)
	y = math.floor(tonumber(y) or 0)
	if width ~= nil then
		width = math.max(1, math.floor(tonumber(width) or 1))
	end
	if height ~= nil then
		height = math.max(1, math.floor(tonumber(height) or 1))
	end
	control:setX(x)
	control:setY(y)
	if width ~= nil then
		control:setWidth(width)
	end
	if height ~= nil then
		control:setHeight(height)
	end
end

-- return the bottom Y edge of a control (y + height).
function LayoutUtils.bottom(control)
	if not control then
		return 0
	end
	return control:getY() + control:getHeight()
end

-- return the right X edge of a control (x + width).
function LayoutUtils.right(control)
	if not control then
		return 0
	end
	return control:getX() + control:getWidth()
end

-- ---------------------------------------------------------------------------
-- Screen clamping
-- ---------------------------------------------------------------------------

-- Clamp a window position so it stays fully on-screen
-- Returns clamped x, y
function LayoutUtils.clampToScreen(x, y, width, height)
	local sw = getCore and getCore():getScreenWidth() or 1920
	local sh = getCore and getCore():getScreenHeight() or 1080
	x = math.max(0, math.min(x, sw - width))
	y = math.max(0, math.min(y, sh - height))
	return x, y
end

-- Centre a window on the screen. Returns x, y
function LayoutUtils.centreOnScreen(width, height)
	local sw = getCore and getCore():getScreenWidth() or 1920
	local sh = getCore and getCore():getScreenHeight() or 1080
	local x = math.max(0, math.floor((sw - width) / 2))
	local y = math.max(0, math.floor((sh - height) / 2))
	return x, y
end

-- Default window open geometry: capped to screen, centred, with a margin.
-- Returns x, y, width, height.
function LayoutUtils.defaultWindowGeometry(desiredW, desiredH, minW, minH, margin)
	margin = margin or 20
	local sw = getCore and getCore():getScreenWidth() or 1920
	local sh = getCore and getCore():getScreenHeight() or 1080
	local w = math.min(desiredW, math.max(minW or desiredW, sw - margin * 2))
	local h = math.min(desiredH, math.max(minH or desiredH, sh - margin * 2))
	local x = math.max(margin, math.floor((sw - w) / 2))
	local y = math.max(margin, math.floor((sh - h) / 2))
	return x, y, w, h
end

-- ---------------------------------------------------------------------------
-- Visibility helpers
-- ---------------------------------------------------------------------------

function LayoutUtils.setVisible(control, visible)
	if control then
		control:setVisible(visible == true)
	end
end

function LayoutUtils.setGroupVisible(controls, visible)
	if not controls then
		return
	end
	for i = 1, #controls do
		LayoutUtils.setVisible(controls[i], visible)
	end
end

function LayoutUtils.setEnabled(control, enabled)
	if not control then
		return
	end
	control.enable = enabled == true
end

return LayoutUtils
