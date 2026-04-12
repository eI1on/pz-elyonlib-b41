require "ISUI/ISPanel"
require "ISUI/ISButton"
require "ISUI/ISToolTip"

local MathUtils = require("ElyonLib/MathUtils/MathUtils")
local AccessLevelUtils = require("ElyonLib/PlayerUtils/AccessLevelUtils")
local TextUtils = require("ElyonLib/TextUtils/TextUtils")
local UIUtils = require("ElyonLib/UI/Utils/UIUtils")

local clamp = MathUtils.clamp
local lerp = MathUtils.lerp
local easeOut = MathUtils.easeOutCubic
local frameStep = UIUtils.frameStep
local isScreenPointInElement = UIUtils.isScreenPointInElement
local fitTextToWidth = TextUtils.fitToWidth

local DOCK = {
	PUCK_SIZE = 40,
	DOCK_VISIBLE = 20,
	HOVER_VISIBLE = 28,
	MAGNET_RANGE = 96,
	DRAG_THRESHOLD = 4,
	EDGE_PADDING = 8,
	RAIL_GAP = 5,
	RAIL_PADDING = 4,
	RAIL_SLOT = 40,
	RAIL_GAP_Y = 4,
	RAIL_MAX_VISIBLE = 8,
	RAIL_SCROLL_HINT = 10,
	EXPAND_ANIM_STEP = 0.2,
	PUCK_ANIM_STEP = 0.18,
	DISPLAY_NAME = "Menu Dock",
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
	local shouldCheckAccessLevel = minimumAccessLevel and not (entry.allowSinglePlayer and AccessLevelUtils.isSinglePlayer())

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

---@class MenuDockRail : ISPanel
MenuDockRail = ISPanel:derive("MenuDockRail")

---@class MenuDockButton : ISButton
MenuDockButton = ISButton:derive("MenuDockButton")

function MenuDockButton:render()
	ISButton.render(self)

	if self.image or not self.entryText or self.entryText == "" then
		return
	end

	local font = self.entryTextFont or UIFont.Small
	local height = getTextManager():MeasureStringY(font, self.entryText)
	local y = (self.height / 2) - (height / 2)
	local alpha = self.enable and self.textColor.a or 0.45
	local r = self.enable and self.textColor.r or 0.45
	local g = self.enable and self.textColor.g or 0.45
	local b = self.enable and self.textColor.b or 0.45

	self:drawTextCentre(self.entryText, self.width / 2, y, r, g, b, alpha, font)
end

function MenuDockButton:new(x, y, width, height, target, onclick)
	local o = ISButton:new(x, y, width, height, "", target, onclick)
	setmetatable(o, self)
	self.__index = self
	o.entryText = nil
	o.entryTextFont = UIFont.Small
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
		return DOCK.RAIL_PADDING + DOCK.RAIL_SCROLL_HINT
	end
	return DOCK.RAIL_PADDING
end

function MenuDockRail:calculateHeight()
	local visibleCount = self:getVisibleCount()
	if visibleCount <= 0 then
		return DOCK.RAIL_PADDING * 2 + DOCK.RAIL_SLOT
	end

	local height = (DOCK.RAIL_PADDING * 2) + (visibleCount * DOCK.RAIL_SLOT) + ((visibleCount - 1) * DOCK.RAIL_GAP_Y)
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
	for i = 1, visibleCount do
		local entry = entries[self.scrollIndex + i - 1]
		if entry then
			local button = MenuDockButton:new(DOCK.RAIL_PADDING, y, DOCK.RAIL_SLOT, DOCK.RAIL_SLOT, self, MenuDockRail.onEntryButton)
			button:initialise()
			button.entry = entry
			button:setDisplayBackground(true)
			button.backgroundColor = { r = 0.08, g = 0.08, b = 0.08, a = 0.72 }
			button.backgroundColorMouseOver = { r = 0.22, g = 0.24, b = 0.25, a = 0.92 }
			button.borderColor = { r = 0.72, g = 0.72, b = 0.72, a = 0.45 }
			button.textureColor = { r = 1, g = 1, b = 1, a = 1 }
			button:setTooltip(entry.title or entry.id or "Menu")

			if entry.texture then
				button:setImage(entry.texture)
				button:forceImageSize(30, 30)
			else
				button.entryText = fitTextToWidth(getEntryLabel(entry), UIFont.Small, DOCK.RAIL_SLOT - 8)
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

function MenuDockRail:onMouseWheel(del)
	if not self:hasOverflow() then
		return false
	end

	local visibleCount = self:getVisibleCount()
	local maxScroll = math.max(1, self:getEntryCount() - visibleCount + 1)
	local direction = del > 0 and 1 or -1
	local nextIndex = clamp((self.scrollIndex or 1) + direction, 1, maxScroll)

	if nextIndex ~= self.scrollIndex then
		self.scrollIndex = nextIndex
		self:refreshButtons()
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

	local alpha = 0.82 * (self.openFraction or 1)
	self:drawRect(0, 0, self.width, self.height, alpha, 0.05, 0.05, 0.05)
	self:drawRectBorder(0, 0, self.width, self.height, 0.55 * (self.openFraction or 1), 0.72, 0.72, 0.72)

	local entryCount = self:getEntryCount()

	if entryCount <= 0 then
		self:drawTextCentre("...", self.width / 2, (self.height / 2) - 6, 0.8, 0.8, 0.8, alpha, UIFont.Small)
	elseif self:hasOverflow() then
		if self.scrollIndex > 1 then
			self:drawTextCentre("^", self.width / 2, 0, 0.85, 0.85, 0.85, alpha, UIFont.Small)
		end

		if self.scrollIndex + self:getVisibleCount() - 1 < entryCount then
			self:drawTextCentre("v", self.width / 2, self.height - DOCK.RAIL_SCROLL_HINT, 0.85, 0.85, 0.85, alpha, UIFont.Small)
		end
	end
end

function MenuDockRail:new(owner)
	local width = DOCK.RAIL_PADDING * 2 + DOCK.RAIL_SLOT
	local o = ISPanel:new(0, 0, width, DOCK.RAIL_PADDING * 2 + DOCK.RAIL_SLOT)
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
	self:setX(self:getFullX())
end

function MenuDock:startDrag()
	self:setExpanded(false)
	self.dragging = true
	self.magnetEdge = nil
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

function MenuDock:dockToEdge(edge)
	local centerX = self:getX() + (DOCK.PUCK_SIZE / 2)

	self.edge = edge or (centerX < (getCore():getScreenWidth() / 2) and "left" or "right")
	self.expanded = false
	self.dragging = false
	self.mouseDown = false
	self.magnetEdge = nil

	MenuDock.state.edge = self.edge
	MenuDock.state.y = self:getY()
end

function MenuDock:onMouseDown(x, y)
	if not self:getIsVisible() then
		return true
	end

	self.mouseDown = true
	self.dragging = false
	self.magnetEdge = nil
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
		self:dockToEdge(self.magnetEdge)
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
	self.expandProgress = self.expandProgress + ((targetExpand - self.expandProgress) * frameStep(DOCK.EXPAND_ANIM_STEP))
	if math.abs(targetExpand - self.expandProgress) < 0.01 then
		self.expandProgress = targetExpand
	end

	if not self.mouseDown then
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

	local alpha = 0.92
	if self.dragging then
		alpha = 0.78
	elseif self.expanded or self:isMouseOver() then
		alpha = 1
	end

	if self.texture then
		self:drawTextureScaled(self.texture, 0, 0, DOCK.PUCK_SIZE, DOCK.PUCK_SIZE, alpha, 1, 1, 1)
	else
		self:drawRect(0, 0, DOCK.PUCK_SIZE, DOCK.PUCK_SIZE, 0.85, 0.07, 0.07, 0.07)
		self:drawRectBorder(0, 0, DOCK.PUCK_SIZE, DOCK.PUCK_SIZE, 0.8, 0.72, 0.72, 0.72)
	end

	if self.magnetEdge then
		self:drawRectBorder(1, 1, DOCK.PUCK_SIZE - 2, DOCK.PUCK_SIZE - 2, 0.75, 0.95, 0.95, 0.95)
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
	o.mouseDown = false
	o.dragging = false
	o.magnetEdge = nil
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
		table.insert(MenuDock.entries, entry)
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
