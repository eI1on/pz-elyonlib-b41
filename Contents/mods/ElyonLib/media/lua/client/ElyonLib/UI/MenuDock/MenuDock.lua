require("ISUI/ISPanel")
require("ISUI/ISButton")
require("ISUI/ISToolTip")

local MathUtils = require("ElyonLib/MathUtils/MathUtils")
local AccessLevelUtils = require("ElyonLib/PlayerUtils/AccessLevelUtils")
local TextUtils = require("ElyonLib/TextUtils/TextUtils")
local UIUtils = require("ElyonLib/UI/Utils/UIUtils")

local clamp = MathUtils.clamp
local lerp = MathUtils.lerp
local easeOut = MathUtils.easeOutCubic
local frameSeconds = UIUtils.frameSeconds
local frameStep = UIUtils.frameStep
local isScreenPointInElement = UIUtils.isScreenPointInElement

local DOCK = {
	PUCK_SIZE = 44,
	DOCK_VISIBLE = 22,
	HOVER_VISIBLE = 32,
	MAGNET_RANGE = 112,
	DRAG_THRESHOLD = 4,
	EDGE_PADDING = 8,
	RAIL_GAP = 8,
	RAIL_PADDING = 5,
	RAIL_SLOT = 42,
	RAIL_TEXT_MAX = 220,
	RAIL_BUTTON_EXPAND = 12,
	RAIL_BUTTON_EXPAND_Y = 7,
	RAIL_ICON_SIZE = 27,
	RAIL_ICON_HOVER_SIZE = 36,
	RAIL_GAP_Y = 14,
	RAIL_MAX_VISIBLE = 8,
	RAIL_SCROLL_HINT = 14,
	BUTTON_HOVER_ANIM_STEP = 0.22,
	EXPAND_ANIM_STEP = 0.18,
	HOVER_ANIM_STEP = 0.18,
	PUCK_ANIM_STEP = 0.12,
	SNAP_DURATION = 0.28,
	DISPLAY_NAME = "Menu Dock",
	--- Default diameter (px) for entry.badge texture + text overlays on rail buttons
	BADGE_DIAMETER = 20,
	BADGE_OFFSET_X = 1,
	BADGE_OFFSET_Y = 1,
}

local function getEntryLabel(entry)
	if not entry then
		return nil
	end
	return entry.label or entry.title or entry.id
end

local function getEntryMinimumAccessLevel(entry)
	if not entry then
		return nil
	end

	return entry.minimumAccessLevel
end

---@alias MenuDockAccessLevel "None"|"Observer"|"GM"|"Overseer"|"Moderator"|"Admin"
---@alias MenuDockClickCallback fun(playerNum: integer, entry: MenuDockEntry)
---@alias MenuDockTargetClickCallback fun(target: any, playerNum: integer, entry: MenuDockEntry)
---@alias MenuDockVisibilityCallback fun(playerNum: integer, playerObj: IsoPlayer|nil, entry: MenuDockEntry): boolean
---@alias MenuDockTargetVisibilityCallback fun(target: any, playerNum: integer, playerObj: IsoPlayer|nil, entry: MenuDockEntry): boolean

---@class MenuDockEntry
---@field id string Unique entry id. Registering the same id replaces the old entry.
---@field title string|nil Tooltip text. The id is used when omitted.
---@field label string|nil Short text drawn when no icon is supplied.
---@field icon string|nil Texture path, for example "media/ui/MyMod/my_icon.png".
---@field texture Texture|nil Preloaded texture. If absent and icon is supplied, MenuDock loads icon with getTexture().
---@field target any|nil Optional callback target.
---@field onClick MenuDockClickCallback|MenuDockTargetClickCallback|nil Called when the entry button is clicked.
---@field minimumAccessLevel MenuDockAccessLevel|nil Minimum player access level required to show this entry.
---@field allowSinglePlayer boolean|nil When true, minimumAccessLevel is only enforced in multiplayer.
---@field visible boolean|nil Set to false to hide this entry.
---@field visibleWhen MenuDockVisibilityCallback|MenuDockTargetVisibilityCallback|nil Custom visibility predicate.
---@field badge MenuDockBadge|nil Optional overlay (e.g. notification count). Prefer MenuDock.setEntryBadge(id, ...) to mutate at runtime.

---@class MenuDockBadge
---@field texture string|nil Texture path relative to mod, e.g. "media/ui/badge.png" (passed to getTexture).
---@field textureObj Texture|nil Pre-loaded texture; wins over texture.
---@field text string|number|nil|fun(entry: MenuDockEntry): string|nil Label drawn centered on the badge.
---@field visible boolean|fun(entry: MenuDockEntry): boolean|nil When false, badge is skipped.
---@field size number|nil Diameter in pixels (square draw). Defaults to DOCK.BADGE_DIAMETER.
---@field anchor string|nil "topleft" | "topright" within the button's visual bounds. Default "topleft".
---@field offsetX number|nil Nudges badge from anchor edge (default BADGE_OFFSET_X).
---@field offsetY number|nil
---@field hideWhenEmpty boolean|nil Hide when resolved text is "" (default true).
---@field hideWhenZero boolean|nil Hide when text parses as zero (default true).
---@field maxBeforePlus number|nil If set and tonumber(text) exceeds this, displays "<maxBeforePlus>+".
---@field font userdata|nil UIFont enum; picks by width when omitted.
---@field textColor { r: number, g: number, b: number }|nil Default white.

---@class MenuDock : ISPanel
MenuDock = ISPanel:derive("MenuDock")
MenuDock.entries = {}
MenuDock.state = { edge = "right" }
MenuDock.players = {}
MenuDock.instance = nil
MenuDock.displayName = DOCK.DISPLAY_NAME

function MenuDock.runVisibilityPredicate(entry, predicate, playerNum, playerObj)
	if type(predicate) ~= "function" then
		return predicate == true
	end

	if entry.target then
		return predicate(entry.target, playerNum, playerObj, entry) == true
	end

	return predicate(playerNum, playerObj, entry) == true
end

function MenuDock.isEntryVisible(entry, playerNum)
	if not entry or entry.visible == false then
		return false
	end

	playerNum = playerNum or 0
	local playerObj = AccessLevelUtils.getPlayer(playerNum)
	local minimumAccessLevel = getEntryMinimumAccessLevel(entry)
	local shouldCheckAccessLevel = minimumAccessLevel
		and not (entry.allowSinglePlayer and AccessLevelUtils.isSinglePlayer())

	if shouldCheckAccessLevel and not AccessLevelUtils.isPlayerAtLeast(playerNum, minimumAccessLevel, playerObj) then
		return false
	end

	if entry.visibleWhen ~= nil then
		return MenuDock.runVisibilityPredicate(entry, entry.visibleWhen, playerNum, playerObj)
	end

	return true
end

function MenuDock.getVisibleEntries(playerNum)
	local visibleEntries = {}
	local entries = MenuDock.entries
	local entryCount = #entries

	for i = 1, entryCount do
		local entry = entries[i]
		if MenuDock.isEntryVisible(entry, playerNum) then
			visibleEntries[#visibleEntries + 1] = entry
		end
	end

	return visibleEntries
end

--- Prefer the largest font that still fits inside the badge width.
local function pickBadgeFont(displayText, maxWidth)
	displayText = tostring(displayText)
	local fonts = {}
	local push = function(f)
		if f then
			fonts[#fonts + 1] = f
		end
	end

	push(UIFont and UIFont.Small)
	push(UIFont and UIFont.Medium)

	if #fonts == 0 then
		return UIFont.Small
	end

	local tm = getTextManager()
	table.sort(fonts, function(a, b)
		return tm:getFontHeight(a) < tm:getFontHeight(b)
	end)

	for i = #fonts, 1, -1 do
		local font = fonts[i]
		if tm:MeasureStringX(font, displayText) <= maxWidth then
			return font
		end
	end

	return fonts[1]
end

--- Called from rail buttons - draws entry.badge (texture + centered label) without mod-specific branching.
function MenuDock.drawBadgeOnRailButton(btn, visualX, visualY, visualWidth, visualHeight, fgAlpha)
	if not btn or not btn.entry or not btn.entry.badge then
		return
	end

	local entry = btn.entry
	local b = entry.badge

	local vis = b.visible
	if vis == false then
		return
	end
	if type(vis) == "function" and not vis(entry) then
		return
	end

	local rawText = b.text
	if type(rawText) == "function" then
		rawText = rawText(entry)
	end
	if rawText == nil then
		rawText = ""
	else
		rawText = tostring(rawText)
	end

	local numValBefore = tonumber(rawText)
	local maxBp = tonumber(b.maxBeforePlus)
	if maxBp and numValBefore and numValBefore > maxBp then
		rawText = tostring(math.floor(maxBp)) .. "+"
	end

	local hideEmpty = b.hideWhenEmpty ~= false

	local hideZero = b.hideWhenZero ~= false
	if hideZero then
		if rawText == "0" then
			return
		end
		if numValBefore ~= nil and numValBefore <= 0 then
			return
		end
	end

	if hideEmpty and rawText == "" then
		return
	end

	local tex = b.textureObj
	if not tex and b.texture then
		tex = getTexture(b.texture)
		b.textureObj = tex
	end

	local dia = tonumber(b.size) or DOCK.BADGE_DIAMETER
	local ox = tonumber(b.offsetX)
	if ox == nil then
		ox = DOCK.BADGE_OFFSET_X
	end
	local oy = tonumber(b.offsetY)
	if oy == nil then
		oy = DOCK.BADGE_OFFSET_Y
	end

	local anchor = tostring(b.anchor or "topleft"):lower()
	local bx
	local by
	if anchor == "topright" then
		bx = visualX + visualWidth - dia - ox
		by = visualY + oy
	else
		bx = visualX + ox
		by = visualY + oy
	end

	local railA = btn.parent and btn.parent.openFraction or 1
	local ba = fgAlpha * railA * (tonumber(b.alpha) or 1)

	if tex then
		btn:drawTextureScaled(tex, bx, by, dia, dia, ba, 1, 1, 1)
	else
		btn:drawRect(bx + 1, by + 1, dia - 2, dia - 2, 0.35 * ba, 0.45, 0.05, 0.05)
		btn:drawRect(bx, by, dia, dia, 0.88 * ba, 0.85, 0.12, 0.14)
	end

	local maxTxtW = dia * 0.74
	local display = rawText
	local font = b.font or pickBadgeFont(display, maxTxtW)
	if TextUtils.measureWidth(font, display) > maxTxtW then
		display = TextUtils.trimToWidth(font, display, maxTxtW, "") or ""
	end

	if hideEmpty and display == "" then
		return
	end

	local tm = getTextManager()
	local tw = tm:MeasureStringX(font, display)
	-- ISInventoryPage / ISButton use getFontHeight for vertical row alignment; MeasureStringY is often
	-- taller than the visible ink for digit-only strings (extra descender/leading in the line box),
	-- which makes naive (dia - th)/2 centering look too low.
	local lineH = tm.getFontHeight and tm:getFontHeight(font) or tm:MeasureStringY(font, display)
	if not lineH or lineH < 1 then
		lineH = tm:MeasureStringY(font, display)
	end
	local leftX = bx + (dia - tw) / 2
	local topY = by + (dia - lineH) / 2
	-- Approximate optical centering: digits sit high in the em box; shift up ~0.11×lineH, capped vs badge diameter.
	local opticalUp = clamp(math.floor(lineH * 11 / 100 + 0.5), 0, math.max(0, math.floor(dia * 15 / 100)))
	topY = topY - opticalUp
	local tr, tg, tb = 1, 1, 1
	local tc = b.textColor
	if type(tc) == "table" then
		tr = tonumber(tc.r) or tr
		tg = tonumber(tc.g) or tg
		tb = tonumber(tc.b) or tb
	end

	btn:drawText(display, leftX, topY, tr, tg, tb, ba, font)
end

---@class MenuDockRail : ISPanel
MenuDockRail = ISPanel:derive("MenuDockRail")

---@class MenuDockButton : ISButton
MenuDockButton = ISButton:derive("MenuDockButton")

function MenuDockButton:getVisualBounds()
	local hoverProgress = self.hoverProgress or 0
	local baseWidth = self.baseWidth or self.width
	local baseHeight = self.baseHeight or self.height
	local growX = DOCK.RAIL_BUTTON_EXPAND * hoverProgress
	local growY = DOCK.RAIL_BUTTON_EXPAND_Y * hoverProgress
	local x = DOCK.RAIL_BUTTON_EXPAND - growX
	local y = DOCK.RAIL_BUTTON_EXPAND_Y - growY

	return x, y, baseWidth + (growX * 2), baseHeight + (growY * 2), hoverProgress
end

function MenuDockButton:update()
	if ISButton.update then
		ISButton.update(self)
	end

	local targetHover = (self.enable and self:isMouseOver()) and 1 or 0
	self.hoverProgress = self.hoverProgress
		+ ((targetHover - self.hoverProgress) * frameStep(DOCK.BUTTON_HOVER_ANIM_STEP))

	if math.abs(targetHover - self.hoverProgress) < 0.01 then
		self.hoverProgress = targetHover
	end
end

function MenuDockButton:prerender()
	local visualX, visualY, visualWidth, visualHeight, hoverProgress = self:getVisualBounds()
	local railAlpha = self.parent and self.parent.openFraction or 1
	local alpha = (0.64 + (0.22 * hoverProgress)) * railAlpha
	local borderAlpha = (0.20 + (0.38 * hoverProgress)) * railAlpha
	local color = lerp(0.08, 0.22, hoverProgress)

	self:drawRect(visualX + 1, visualY + 2, visualWidth, visualHeight, 0.16 * railAlpha, 0, 0, 0)
	self:drawRect(visualX, visualY, visualWidth, visualHeight, alpha, color, color, color)
	self:drawRectBorder(visualX, visualY, visualWidth, visualHeight, borderAlpha, 0.72, 0.72, 0.72)
end

function MenuDockButton:render()
	local visualX, visualY, visualWidth, visualHeight, hoverProgress = self:getVisualBounds()
	local centerX = visualX + (visualWidth / 2)
	local centerY = visualY + (visualHeight / 2)
	local alpha = self.enable and (0.78 + (0.22 * hoverProgress)) or 0.35

	if self.image then
		local imageSize = lerp(DOCK.RAIL_ICON_SIZE, DOCK.RAIL_ICON_HOVER_SIZE, hoverProgress)
		self:drawTextureScaled(
			self.image,
			centerX - (imageSize / 2),
			centerY - (imageSize / 2),
			imageSize,
			imageSize,
			alpha,
			1,
			1,
			1
		)
	elseif self.entryText and self.entryText ~= "" then
		local font = self.entryTextFont or UIFont.Small
		local height = getTextManager():MeasureStringY(font, self.entryText)
		local y = centerY - (height / 2)
		local r = self.enable and self.textColor.r or 0.45
		local g = self.enable and self.textColor.g or 0.45
		local b = self.enable and self.textColor.b or 0.45

		self:drawTextCentre(self.entryText, centerX, y, r, g, b, alpha, font)
	end

	MenuDock.drawBadgeOnRailButton(self, visualX, visualY, visualWidth, visualHeight, alpha)
end

function MenuDockButton:new(x, y, width, height, target, onclick)
	local o = ISButton:new(x, y, width, height, "", target, onclick)
	setmetatable(o, self)
	self.__index = self
	o.entryText = nil
	o.entryTextFont = UIFont.Small
	o.baseWidth = width
	o.baseHeight = height
	o.hoverProgress = 0
	return o
end

function MenuDockRail:getEntries()
	if not self.visibleEntries then
		self.visibleEntries = MenuDock.getVisibleEntries(self.owner and self.owner.playerNum or 0)
	end

	return self.visibleEntries
end

function MenuDockRail:getEntryCount()
	return #self:getEntries()
end

function MenuDockRail:getVisibleCount()
	return math.min(self:getEntryCount(), DOCK.RAIL_MAX_VISIBLE)
end

function MenuDockRail:hasOverflow()
	return self:getEntryCount() > DOCK.RAIL_MAX_VISIBLE
end

function MenuDockRail:getButtonStartY()
	if self:hasOverflow() then
		return DOCK.RAIL_PADDING + DOCK.RAIL_SCROLL_HINT + DOCK.RAIL_BUTTON_EXPAND_Y
	end
	return DOCK.RAIL_PADDING + DOCK.RAIL_BUTTON_EXPAND_Y
end

function MenuDockRail:calculateHeight()
	local visibleCount = self:getVisibleCount()
	if visibleCount <= 0 then
		return DOCK.RAIL_PADDING * 2 + DOCK.RAIL_SLOT + (DOCK.RAIL_BUTTON_EXPAND_Y * 2)
	end

	local height = (DOCK.RAIL_PADDING * 2)
		+ (DOCK.RAIL_BUTTON_EXPAND_Y * 2)
		+ (visibleCount * DOCK.RAIL_SLOT)
		+ ((visibleCount - 1) * DOCK.RAIL_GAP_Y)
	if self:hasOverflow() then
		height = height + (DOCK.RAIL_SCROLL_HINT * 2)
	end
	return height
end

function MenuDockRail:refreshButtons()
	if not self.javaObject then
		return
	end

	self:clearChildren()

	local playerNum = self.owner and self.owner.playerNum or 0
	self.visibleEntries = MenuDock.getVisibleEntries(playerNum)

	local entries = self.visibleEntries
	local count = #entries
	local visibleCount = self:getVisibleCount()
	local maxScroll = math.max(1, count - visibleCount + 1)

	self.scrollIndex = clamp(self.scrollIndex or 1, 1, maxScroll)
	self:setHeight(self:calculateHeight())

	local y = self:getButtonStartY()
	local buttonX = DOCK.RAIL_PADDING
	local font = UIFont.Small
	local tm = getTextManager()

	local textSlot = DOCK.RAIL_SLOT
	for idx = 1, visibleCount do
		local entry = entries[self.scrollIndex + idx - 1]
		if entry and not entry.texture then
			local label = getEntryLabel(entry) or ""
			local lw = tm:MeasureStringX(font, label)
			textSlot = math.max(textSlot, lw + 12)
		end
	end
	textSlot = clamp(textSlot, DOCK.RAIL_SLOT, DOCK.RAIL_TEXT_MAX)

	local newRailW = DOCK.RAIL_PADDING * 2 + textSlot + (DOCK.RAIL_BUTTON_EXPAND * 2)
	if self:getWidth() ~= newRailW then
		self:setWidth(newRailW)
		if self.owner and self.owner.setExpanded and self.owner.expanded then
			self:setOpenFraction(self.openFraction or 1)
		end
	end

	local buttonWidth = textSlot + (DOCK.RAIL_BUTTON_EXPAND * 2)
	local buttonHeight = DOCK.RAIL_SLOT + (DOCK.RAIL_BUTTON_EXPAND_Y * 2)
	for i = 1, visibleCount do
		local entry = entries[self.scrollIndex + i - 1]
		if entry then
			local button = MenuDockButton:new(
				buttonX,
				y - DOCK.RAIL_BUTTON_EXPAND_Y,
				buttonWidth,
				buttonHeight,
				self,
				MenuDockRail.onEntryButton
			)
			button:initialise()
			button.entry = entry
			button.baseWidth = textSlot
			button.baseHeight = DOCK.RAIL_SLOT
			button:setDisplayBackground(false)
			button.borderColor = { r = 0, g = 0, b = 0, a = 0 }
			button.textColor = { r = 0.90, g = 0.90, b = 0.90, a = 1 }
			button.textureColor = { r = 1, g = 1, b = 1, a = 1 }
			button:setTooltip(entry.title or entry.id or "Menu")

			if entry.texture then
				button:setImage(entry.texture)
			else
				button.entryText = getEntryLabel(entry)
			end

			self:addChild(button)
			y = y + DOCK.RAIL_SLOT + DOCK.RAIL_GAP_Y
		end
	end
end

function MenuDockRail:onEntryButton(button)
	local entry = button and button.entry
	if not entry then
		return
	end

	if not MenuDock.isEntryVisible(entry, self.owner and self.owner.playerNum or 0) then
		self:refreshButtons()
		return
	end

	if self.owner then
		self.owner:setExpanded(false)
	end

	if entry.onClick then
		if entry.target then
			entry.onClick(entry.target, self.owner and self.owner.playerNum or 0, entry)
		else
			entry.onClick(self.owner and self.owner.playerNum or 0, entry)
		end
	end
end

function MenuDockRail:setScrollIndex(index)
	local visibleCount = self:getVisibleCount()
	local maxScroll = math.max(1, self:getEntryCount() - visibleCount + 1)
	local nextIndex = clamp(index, 1, maxScroll)

	if nextIndex == self.scrollIndex then
		return false
	end

	self.scrollIndex = nextIndex
	self:refreshButtons()
	return true
end

function MenuDockRail:onMouseWheel(del)
	if not self:hasOverflow() then
		return false
	end

	local direction = del > 0 and 1 or -1
	self:setScrollIndex((self.scrollIndex or 1) + direction)

	return true
end

function MenuDockRail:onMouseDown(x, y)
	if self:hasOverflow() then
		local arrowBottom = DOCK.RAIL_PADDING + DOCK.RAIL_SCROLL_HINT
		local arrowTop = self.height - DOCK.RAIL_PADDING - DOCK.RAIL_SCROLL_HINT
		local canScrollUp = self.scrollIndex > 1
		local canScrollDown = self.scrollIndex + self:getVisibleCount() - 1 < self:getEntryCount()

		if canScrollUp and y <= arrowBottom then
			self:setScrollIndex((self.scrollIndex or 1) - 1)
			return true
		end

		if canScrollDown and y >= arrowTop then
			self:setScrollIndex((self.scrollIndex or 1) + 1)
			return true
		end
	end

	if self.owner then
		self.owner:setExpanded(false)
	end
	return true
end

function MenuDockRail:onMouseDownOutside(x, y)
	if self.owner and isScreenPointInElement(self.owner, getMouseX(), getMouseY()) then
		return
	end

	if self.owner then
		self.owner:setExpanded(false)
	else
		self:setOpenFraction(0)
	end
end

function MenuDockRail:setOpenFraction(fraction)
	self.openFraction = clamp(fraction or 0, 0, 1)

	if self.owner then
		local eased = easeOut(self.openFraction)
		local hiddenX = self.owner:getRailHiddenX()
		local openX = self.owner:getRailOpenX()
		self:setX(lerp(hiddenX, openX, eased))
		self:setY(self.owner:getRailY())
	end

	self:setVisible(self.openFraction > 0.02)
end

function MenuDockRail:prerender()
	self:setAlwaysOnTop(true)

	local alpha = self.openFraction or 1
	local entryCount = self:getEntryCount()

	if entryCount <= 0 then
		local emptySize = DOCK.RAIL_SLOT
		local emptyX = (self.width - emptySize) / 2
		local emptyY = (self.height - emptySize) / 2
		self:drawRect(emptyX + 1, emptyY + 2, emptySize, emptySize, 0.12 * alpha, 0, 0, 0)
		self:drawRect(emptyX, emptyY, emptySize, emptySize, 0.45 * alpha, 0.05, 0.05, 0.05)
		self:drawRectBorder(emptyX, emptyY, emptySize, emptySize, 0.24 * alpha, 0.72, 0.72, 0.72)
		self:drawTextCentre("...", self.width / 2, (self.height / 2) - 6, 0.82, 0.82, 0.82, alpha, UIFont.Small)
	elseif self:hasOverflow() then
		local arrowWidth = 28
		local arrowHeight = DOCK.RAIL_SCROLL_HINT
		local arrowX = (self.width - arrowWidth) / 2

		if self.scrollIndex > 1 then
			local arrowY = DOCK.RAIL_PADDING
			self:drawRect(arrowX + 1, arrowY + 1, arrowWidth, arrowHeight, 0.12 * alpha, 0, 0, 0)
			self:drawRect(arrowX, arrowY, arrowWidth, arrowHeight, 0.46 * alpha, 0.05, 0.05, 0.05)
			self:drawRectBorder(arrowX, arrowY, arrowWidth, arrowHeight, 0.24 * alpha, 0.72, 0.72, 0.72)
			self:drawTextCentre("^", self.width / 2, arrowY - 1, 0.85, 0.85, 0.85, alpha, UIFont.Small)
		end

		if self.scrollIndex + self:getVisibleCount() - 1 < entryCount then
			local arrowY = self.height - DOCK.RAIL_PADDING - arrowHeight
			self:drawRect(arrowX + 1, arrowY + 1, arrowWidth, arrowHeight, 0.12 * alpha, 0, 0, 0)
			self:drawRect(arrowX, arrowY, arrowWidth, arrowHeight, 0.46 * alpha, 0.05, 0.05, 0.05)
			self:drawRectBorder(arrowX, arrowY, arrowWidth, arrowHeight, 0.24 * alpha, 0.72, 0.72, 0.72)
			self:drawTextCentre("v", self.width / 2, arrowY - 1, 0.85, 0.85, 0.85, alpha, UIFont.Small)
		end
	end
end

function MenuDockRail:new(owner)
	local width = DOCK.RAIL_PADDING * 2 + DOCK.RAIL_SLOT + (DOCK.RAIL_BUTTON_EXPAND * 2)
	local o = ISPanel:new(0, 0, width, DOCK.RAIL_PADDING * 2 + DOCK.RAIL_SLOT + (DOCK.RAIL_BUTTON_EXPAND_Y * 2))
	setmetatable(o, self)
	self.__index = self

	o.owner = owner
	o.background = false
	o.keepOnScreen = false
	o.openFraction = 0
	o.scrollIndex = 1
	o.visibleEntries = nil

	return o
end

function MenuDock:getDockedX()
	if self.edge == "left" then
		return -DOCK.DOCK_VISIBLE
	end
	return getCore():getScreenWidth() - DOCK.DOCK_VISIBLE
end

function MenuDock:getPeekX()
	if self.edge == "left" then
		return -(DOCK.PUCK_SIZE - DOCK.HOVER_VISIBLE)
	end
	return getCore():getScreenWidth() - DOCK.HOVER_VISIBLE
end

function MenuDock:getFullX()
	if self.edge == "left" then
		return 0
	end
	return getCore():getScreenWidth() - DOCK.PUCK_SIZE
end

function MenuDock:getTargetX()
	if self.dragging or self.expanded then
		return self:getFullX()
	end

	if self:isMouseOver() then
		return self:getPeekX()
	end

	return self:getDockedX()
end

function MenuDock:getRailHiddenX()
	if not self.rail then
		return 0
	end

	if self.edge == "left" then
		return -self.rail:getWidth() - DOCK.RAIL_GAP
	end

	return getCore():getScreenWidth() + DOCK.RAIL_GAP
end

function MenuDock:getRailOpenX()
	if not self.rail then
		return 0
	end

	if self.edge == "left" then
		return self:getFullX() + DOCK.PUCK_SIZE + DOCK.RAIL_GAP
	end

	return self:getFullX() - self.rail:getWidth() - DOCK.RAIL_GAP
end

function MenuDock:getRailY()
	if not self.rail then
		return self:getY()
	end

	local y = self:getY() + (DOCK.PUCK_SIZE / 2) - (self.rail:getHeight() / 2)
	return clamp(y, DOCK.EDGE_PADDING, getCore():getScreenHeight() - self.rail:getHeight() - DOCK.EDGE_PADDING)
end

function MenuDock:clampY()
	local maxY = getCore():getScreenHeight() - DOCK.PUCK_SIZE - DOCK.EDGE_PADDING
	self:setY(clamp(self:getY(), DOCK.EDGE_PADDING, maxY))
	MenuDock.state.y = self:getY()
end

function MenuDock:setExpanded(expanded)
	self.expanded = expanded == true
	if self.expanded then
		self:bringToTop()
		if self.rail then
			self.rail:refreshButtons()
			self.rail:bringToTop()
		end
	end
end

function MenuDock:refreshRailIfAccessChanged()
	local accessLevel = AccessLevelUtils.normalize(AccessLevelUtils.getPlayerAccessLevel(self.playerNum))
	if accessLevel == self.lastAccessLevel then
		return
	end

	self.lastAccessLevel = accessLevel
	if self.rail then
		self.rail:refreshButtons()
	end
end

function MenuDock:showFullForPointer()
	self.puckAnimation = nil
	self:setX(self:getFullX())
end

function MenuDock:startPuckAnimation(targetX, targetY, duration)
	duration = duration or DOCK.SNAP_DURATION
	targetY = targetY or self:getY()

	if duration <= 0 then
		self:setX(targetX)
		self:setY(targetY)
		self.puckAnimation = nil
		return
	end

	self.puckAnimation = {
		startX = self:getX(),
		startY = self:getY(),
		targetX = targetX,
		targetY = targetY,
		elapsed = 0,
		duration = duration,
	}
end

function MenuDock:updatePuckAnimation()
	if not self.puckAnimation then
		return false
	end

	local animation = self.puckAnimation
	animation.elapsed = animation.elapsed + frameSeconds(33.3)

	local progress = clamp(animation.elapsed / animation.duration, 0, 1)
	local easedProgress = easeOut(progress)

	self:setX(lerp(animation.startX, animation.targetX, easedProgress))
	self:setY(lerp(animation.startY, animation.targetY, easedProgress))

	if progress >= 1 then
		self:setX(animation.targetX)
		self:setY(animation.targetY)
		self.puckAnimation = nil
	end

	return true
end

function MenuDock:startDrag()
	self:setExpanded(false)
	self.dragging = true
	self.magnetEdge = nil
	self.puckAnimation = nil
end

function MenuDock:updateDragPosition()
	local screenWidth = getCore():getScreenWidth()
	local screenHeight = getCore():getScreenHeight()
	local newX = getMouseX() - self.dragOffsetX
	local newY = getMouseY() - self.dragOffsetY

	newX = clamp(newX, 0, screenWidth - DOCK.PUCK_SIZE)
	newY = clamp(newY, DOCK.EDGE_PADDING, screenHeight - DOCK.PUCK_SIZE - DOCK.EDGE_PADDING)

	local leftDistance = newX
	local rightDistance = screenWidth - (newX + DOCK.PUCK_SIZE)
	self.magnetEdge = nil

	if leftDistance <= DOCK.MAGNET_RANGE then
		local pull = 1 - (leftDistance / DOCK.MAGNET_RANGE)
		newX = lerp(newX, 0, 0.25 + (0.55 * pull))
		self.magnetEdge = "left"
	elseif rightDistance <= DOCK.MAGNET_RANGE then
		local pull = 1 - (rightDistance / DOCK.MAGNET_RANGE)
		newX = lerp(newX, screenWidth - DOCK.PUCK_SIZE, 0.25 + (0.55 * pull))
		self.magnetEdge = "right"
	end

	self:setX(newX)
	self:setY(newY)
end

function MenuDock:dockToEdge(edge, animate)
	local centerX = self:getX() + (DOCK.PUCK_SIZE / 2)

	self.edge = edge or (centerX < (getCore():getScreenWidth() / 2) and "left" or "right")
	self.expanded = false
	self.dragging = false
	self.mouseDown = false
	self.magnetEdge = nil

	MenuDock.state.edge = self.edge
	MenuDock.state.y = self:getY()

	local targetX = self:getDockedX()
	if animate then
		self:startPuckAnimation(targetX, self:getY(), DOCK.SNAP_DURATION)
	else
		self.puckAnimation = nil
		self:setX(targetX)
	end
end

function MenuDock:onMouseDown(x, y)
	if not self:getIsVisible() then
		return true
	end

	self.mouseDown = true
	self.dragging = false
	self.magnetEdge = nil
	self.puckAnimation = nil
	self.dragStartMouseX = getMouseX()
	self.dragStartMouseY = getMouseY()

	self:showFullForPointer()
	self.dragOffsetX = getMouseX() - self:getX()
	self.dragOffsetY = getMouseY() - self:getY()

	self:setCapture(true)
	self:bringToTop()
	return true
end

function MenuDock:onMouseDownOutside(x, y)
	if self.rail and isScreenPointInElement(self.rail, getMouseX(), getMouseY()) then
		return
	end

	if self.expanded then
		self:setExpanded(false)
	end
end

function MenuDock:onMouseMove(dx, dy)
	if not self.mouseDown then
		return
	end

	local movedX = math.abs(getMouseX() - self.dragStartMouseX)
	local movedY = math.abs(getMouseY() - self.dragStartMouseY)

	if not self.dragging and (movedX + movedY) >= DOCK.DRAG_THRESHOLD then
		self:startDrag()
	end

	if self.dragging then
		self:updateDragPosition()
	end
end

function MenuDock:onMouseMoveOutside(dx, dy)
	self:onMouseMove(dx, dy)
end

function MenuDock:onMouseUp(x, y)
	if not self.mouseDown then
		return true
	end

	self:setCapture(false)

	if self.dragging then
		self:dockToEdge(self.magnetEdge, true)
		UIUtils.playSound("UIActivateButton")
	else
		self:setExpanded(not self.expanded)
		UIUtils.playSound("UIActivateButton")
	end

	self.mouseDown = false
	self.dragging = false
	return true
end

function MenuDock:onMouseUpOutside(x, y)
	return self:onMouseUp(x, y)
end

function MenuDock:updateTooltip()
	local shouldShow = self:isMouseOver() and not self.mouseDown and not self.expanded

	if shouldShow then
		if not self.tooltipUI then
			self.tooltipUI = ISToolTip:new()
			self.tooltipUI:setOwner(self)
			self.tooltipUI:setAlwaysOnTop(true)
			self.tooltipUI:setVisible(false)
		end

		if not self.tooltipUI:getIsVisible() then
			self.tooltipUI:addToUIManager()
			self.tooltipUI:setVisible(true)
		end

		self.tooltipUI.description = self.displayName
		self.tooltipUI:setDesiredPosition(getMouseX(), self:getAbsoluteY() + self:getHeight() + 8)
	elseif self.tooltipUI and self.tooltipUI:getIsVisible() then
		self.tooltipUI:setVisible(false)
		self.tooltipUI:removeFromUIManager()
	end
end

function MenuDock:update()
	ISPanel.update(self)

	self:clampY()
	self:refreshRailIfAccessChanged()

	local targetExpand = self.expanded and 1 or 0
	self.expandProgress = self.expandProgress
		+ ((targetExpand - self.expandProgress) * frameStep(DOCK.EXPAND_ANIM_STEP))
	if math.abs(targetExpand - self.expandProgress) < 0.01 then
		self.expandProgress = targetExpand
	end

	local targetHover = (self.expanded or self.dragging or self:isMouseOver() or self.puckAnimation ~= nil) and 1 or 0
	self.hoverProgress = self.hoverProgress + ((targetHover - self.hoverProgress) * frameStep(DOCK.HOVER_ANIM_STEP))
	if math.abs(targetHover - self.hoverProgress) < 0.01 then
		self.hoverProgress = targetHover
	end

	local isPuckAnimating = self:updatePuckAnimation()
	if not self.mouseDown and not isPuckAnimating then
		local targetX = self:getTargetX()
		self:setX(lerp(self:getX(), targetX, frameStep(DOCK.PUCK_ANIM_STEP)))
	end

	if self.rail then
		self.rail:setOpenFraction(self.expandProgress)
	end

	self:updateTooltip()
end

function MenuDock:prerender()
	self:setAlwaysOnTop(true)

	local hoverProgress = self.hoverProgress or 0
	local alpha = 0.90 + (0.10 * hoverProgress)
	if self.dragging then
		alpha = 0.80
	end

	if self.texture then
		self:drawTextureScaled(
			self.texture,
			2,
			3,
			DOCK.PUCK_SIZE,
			DOCK.PUCK_SIZE,
			0.18 + (0.10 * hoverProgress),
			0,
			0,
			0
		)
		self:drawTextureScaled(self.texture, 0, 0, DOCK.PUCK_SIZE, DOCK.PUCK_SIZE, alpha, 1, 1, 1)
	else
		self:drawRect(2, 3, DOCK.PUCK_SIZE, DOCK.PUCK_SIZE, 0.20 + (0.10 * hoverProgress), 0, 0, 0)
		self:drawRect(0, 0, DOCK.PUCK_SIZE, DOCK.PUCK_SIZE, 0.86, 0.05, 0.05, 0.05)
		self:drawRectBorder(0, 0, DOCK.PUCK_SIZE, DOCK.PUCK_SIZE, 0.42 + (0.28 * hoverProgress), 0.72, 0.72, 0.72)
	end

	local gripX = self.edge == "left" and DOCK.PUCK_SIZE - 7 or 5
	self:drawRect(gripX, (DOCK.PUCK_SIZE / 2) - 8, 2, 16, 0.22 + (0.26 * hoverProgress), 0.85, 0.85, 0.85)

	if self.magnetEdge then
		self:drawRectBorder(1, 1, DOCK.PUCK_SIZE - 2, DOCK.PUCK_SIZE - 2, 0.78, 0.95, 0.95, 0.95)
	end
end

function MenuDock:removeFromUIManager()
	if self.tooltipUI and self.tooltipUI:getIsVisible() then
		self.tooltipUI:setVisible(false)
		self.tooltipUI:removeFromUIManager()
	end

	if self.rail then
		self.rail:removeFromUIManager()
	end

	ISPanel.removeFromUIManager(self)
end

function MenuDock:initialise()
	ISPanel.initialise(self)

	self.rail = MenuDockRail:new(self)
	self.rail:initialise()
	self.rail:instantiate()
	self.rail:refreshButtons()
	self.rail:setOpenFraction(0)
end

function MenuDock:new(playerNum)
	local screenWidth = getCore():getScreenWidth()
	local screenHeight = getCore():getScreenHeight()
	local edge = MenuDock.state.edge or "right"
	local y = MenuDock.state.y or ((screenHeight - DOCK.PUCK_SIZE) / 2)
	local x = edge == "left" and -DOCK.DOCK_VISIBLE or screenWidth - DOCK.DOCK_VISIBLE

	local o = ISPanel:new(x, y, DOCK.PUCK_SIZE, DOCK.PUCK_SIZE)
	setmetatable(o, self)
	self.__index = self

	o.playerNum = playerNum or 0
	o.edge = edge
	o.keepOnScreen = false
	o.background = false
	o.texture = getTexture("media/ui/ElyonLib/ui_menu_dock.png")
	o.expanded = false
	o.expandProgress = 0
	o.hoverProgress = 0
	o.mouseDown = false
	o.dragging = false
	o.magnetEdge = nil
	o.puckAnimation = nil
	o.lastAccessLevel = AccessLevelUtils.normalize(AccessLevelUtils.getPlayerAccessLevel(o.playerNum))
	o:setY(clamp(y, DOCK.EDGE_PADDING, screenHeight - DOCK.PUCK_SIZE - DOCK.EDGE_PADDING))

	return o
end

function MenuDock.findEntryIndex(id)
	if not id then
		return nil
	end

	local entries = MenuDock.entries
	local entryCount = #entries
	for i = 1, entryCount do
		local entry = entries[i]
		if entry.id == id then
			return i
		end
	end

	return nil
end

function MenuDock.refreshRails()
	local playerCount = #MenuDock.players
	for playerNum = 0, playerCount do
		local dock = MenuDock.players[playerNum]
		if dock and dock.rail then
			dock.rail:refreshButtons()
		end
	end
end

---Register a button in the menu dock rail.
---Use minimumAccessLevel = "Moderator" for moderator+ entries, minimumAccessLevel = "Admin" for admin-only entries,
---or allowSinglePlayer = true to allow SP but enforce minimumAccessLevel in MP.
---or visibleWhen(playerNum, playerObj, entry) for custom visibility.
---When target is supplied, visibleWhen is called as visibleWhen(target, playerNum, playerObj, entry).
---Callback signature is onClick(playerNum, entry), or onClick(target, playerNum, entry) when target is supplied.
---@param entry MenuDockEntry
---@return MenuDockEntry|nil entry
function MenuDock.registerButton(entry)
	if not entry or not entry.id then
		return nil
	end

	if entry.icon and not entry.texture then
		entry.texture = getTexture(entry.icon)
	end

	local index = MenuDock.findEntryIndex(entry.id)
	if index then
		MenuDock.entries[index] = entry
	else
		MenuDock.entries[#MenuDock.entries + 1] = entry
	end

	MenuDock.refreshRails()
	return entry
end

---@param id string
---@return boolean removed
function MenuDock.unregisterButton(id)
	local index = MenuDock.findEntryIndex(id)
	if not index then
		return false
	end

	table.remove(MenuDock.entries, index)
	MenuDock.refreshRails()
	return true
end

--- Shallow-merge fields onto MenuDock.entries[entryId].badge (creates the table if needed).
--- Clearing keys: assign nil (e.g. setEntryBadge(id, { text = "", texture = nil }) then clear textureObj handled when texture changes).
--- Does not rebuild the dock unless you call MenuDock.refreshRails().
---@param entryId string
---@param patch MenuDockBadge|table|nil
---@return boolean ok
function MenuDock.setEntryBadge(entryId, patch)
	local ix = MenuDock.findEntryIndex(entryId)
	if not ix then
		return false
	end
	local e = MenuDock.entries[ix]
	if type(patch) ~= "table" then
		return true
	end
	e.badge = e.badge or {}
	for k, v in pairs(patch) do
		if k == "texture" then
			if v ~= e.badge.texture then
				e.badge.textureObj = nil
			end
			e.badge.texture = v
		else
			e.badge[k] = v
		end
	end
	return true
end

--- Removes the badge overlay for an entry id.
---@param entryId string
---@return boolean ok
function MenuDock.clearEntryBadge(entryId)
	local ix = MenuDock.findEntryIndex(entryId)
	if not ix then
		return false
	end
	MenuDock.entries[ix].badge = nil
	return true
end

--- Namespaced aliases for readability from other mods.
MenuDock.Badge = {
	set = MenuDock.setEntryBadge,
	clear = MenuDock.clearEntryBadge,
	drawOnRailButton = MenuDock.drawBadgeOnRailButton,
}

function MenuDock.OnCreatePlayer(playerNum)
	if playerNum ~= 0 then
		return
	end

	if MenuDock.players[playerNum] then
		return
	end

	local dock = MenuDock:new(playerNum)
	dock:initialise()

	if dock.rail then
		dock.rail:addToUIManager()
		dock.rail:setVisible(false)
	end

	dock:addToUIManager()
	dock:bringToTop()

	MenuDock.players[playerNum] = dock
	MenuDock.instance = dock
end

function MenuDock.OnPlayerDeath(playerObj)
	if not playerObj then
		return
	end

	local playerNum = playerObj:getPlayerNum()
	local dock = MenuDock.players[playerNum]
	if dock then
		dock:removeFromUIManager()
		MenuDock.players[playerNum] = nil
	end

	if MenuDock.instance == dock then
		MenuDock.instance = nil
	end
end

function MenuDock.OnResolutionChange()
	local playerCount = #MenuDock.players
	for playerNum = 0, playerCount do
		local dock = MenuDock.players[playerNum]
		if dock then
			dock.puckAnimation = nil
			dock:clampY()
			dock:setX(dock:getTargetX())
			if dock.rail then
				dock.rail:setOpenFraction(dock.expandProgress or 0)
			end
		end
	end
end

Events.OnCreatePlayer.Add(MenuDock.OnCreatePlayer)
Events.OnPlayerDeath.Add(MenuDock.OnPlayerDeath)
Events.OnResolutionChange.Add(MenuDock.OnResolutionChange)

return MenuDock
