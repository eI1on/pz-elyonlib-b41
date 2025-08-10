require("ISUI/ISUIElement")

ISCustomScrollBar = ISUIElement:derive("ISCustomScrollBar")

function ISCustomScrollBar:initialise()
	ISUIElement.initialise(self)
end

function ISCustomScrollBar:onMouseDown(x, y)
	self.scrolling = false
	if not self.barx then
		return false
	end
	if self.barwidth == 0 or self.barheight == 0 then
		return false
	end
	if x >= self.barx and x <= self.barx + self.barwidth then
		if y >= self.bary and y <= self.bary + self.barheight then
			self.scrolling = true
			self:setCapture(true)
		end
	end
end

function ISCustomScrollBar:onMouseUp(x, y)
	if not self.scrolling then
		return false
	end
	self.scrolling = false
	self:setCapture(false)
end

function ISCustomScrollBar:refresh()
	if self.vertical then
		local sh = self.parent:getScrollHeight()
		if sh > self.parent:getScrollAreaHeight() then
			if -self.parent:getYScroll() > sh - self.parent:getScrollAreaHeight() then
				self.parent:setYScroll(-(sh - self.parent:getScrollAreaHeight()))
			end
		end
	else
		local sw = self.parent:getScrollWidth()
		if sw > self.parent:getScrollAreaWidth() then
			if -self.parent:getXScroll() > sw - self.parent:getScrollAreaWidth() then
				self.parent:setXScroll(-(sw - self.parent:getScrollAreaWidth()))
			end
		end
	end
end

function ISCustomScrollBar:onMouseUpOutside(x, y)
	self.scrolling = false
	self:setCapture(false)
end

function ISCustomScrollBar:onMouseMoveOutside(dx, dy)
	self:onMouseMove(dx, dy)
end

function ISCustomScrollBar:updatePos()
	if self.vertical then
		local sh = self.parent:getScrollHeight()
		if sh and self.parent and sh > self.parent:getScrollAreaHeight() then
			local dif = self.parent:getScrollAreaHeight()
			local yscroll = -self.parent:getYScroll()
			self.pos = yscroll / (sh - dif)

			if self.pos < 0 then
				self.pos = 0
			end
			if self.pos > 1 then
				self.pos = 1
			end
		end
	else
		local sw = self.parent:getScrollWidth()
		if self.parent and sw > self.parent:getScrollAreaWidth() then
			local parentWidth = self.parent:getScrollAreaWidth()
			local xscroll = -self.parent:getXScroll()
			self.pos = xscroll / (sw - parentWidth)
			if self.pos < 0 then
				self.pos = 0
			end
			if self.pos > 1 then
				self.pos = 1
			end
		end
	end
end

function ISCustomScrollBar:onMouseMove(dx, dy)
	if self.scrolling then
		if self.vertical then
			local sh = self.parent:getScrollHeight()
			if sh > self.parent:getScrollAreaHeight() then
				local del = self:getHeight() / sh
				local boxheight = del * (self:getHeight() - (self.buttonSize * 2))
				local dif = self:getHeight() - (self.buttonSize * 2) - boxheight
				self.pos = self.pos + (dy / dif)

				if self.pos < 0 then
					self.pos = 0
				end
				if self.pos > 1 then
					self.pos = 1
				end
				self.parent:setYScroll(-(self.pos * (sh - self.parent:getScrollAreaHeight())))
			end
		else
			local sw = self.parent:getScrollWidth()
			if sw > self.parent:getScrollAreaWidth() then
				local del = self:getWidth() / sw
				local boxwidth = del * (self:getWidth() - (self.buttonSize * 2))
				local dif = self:getWidth() - (self.buttonSize * 2) - boxwidth
				self.pos = self.pos + (dx / dif)
				if self.pos < 0 then
					self.pos = 0
				end
				if self.pos > 1 then
					self.pos = 1
				end
				self.parent:setXScroll(-(self.pos * (sw - self.parent:getScrollAreaWidth())))
			end
		end
	end
end

function ISCustomScrollBar:instantiate()
	self.javaObject = UIElement.new(self)
	if self.vertical then
		self.anchorLeft = false
		self.anchorRight = true
		self.anchorBottom = true
		self.x = self.parent.width - self.width
		self.y = 0
		self.height = self.parent.height
	else
		self.anchorTop = false
		self.anchorRight = true
		self.anchorBottom = true
		self.x = 0
		self.y = self.parent.height - self.height
		self.width = self.parent.width - (self.parent.vscroll and 13 or 0)
	end

	self.javaObject:setX(self.x)
	self.javaObject:setY(self.y)
	self.javaObject:setHeight(self.height)
	self.javaObject:setWidth(self.width)
	self.javaObject:setAnchorLeft(self.anchorLeft)
	self.javaObject:setAnchorRight(self.anchorRight)
	self.javaObject:setAnchorTop(self.anchorTop)
	self.javaObject:setAnchorBottom(self.anchorBottom)
	self.javaObject:setScrollWithParent(false)
end

function ISCustomScrollBar:render()
	if self.vertical then
		local sh = self.parent:getScrollHeight()
		if sh > self:getHeight() then
			if self.doSetStencil then
				self:setStencilRect(0, 0, self.width, self.height)
			end

			-- draw background area
			if self.background then
				self:drawRect(
					0,
					0,
					self.width,
					self.height,
					self.backgroundColor.a,
					self.backgroundColor.r,
					self.backgroundColor.g,
					self.backgroundColor.b
				)
			end

			local del = self:getHeight() / sh
			local boxheight = del * (self:getHeight() - (self.buttonSize * 2))
			boxheight = math.ceil(boxheight)
			boxheight = math.max(boxheight, 8)

			local dif = self:getHeight() - (self.buttonSize * 2) - boxheight
			dif = dif * self.pos
			dif = math.ceil(dif)

			local contentPadding = self.elementPadding
			local buttonWidth = self.width - (contentPadding * 2)

			self.barx = contentPadding
			self.bary = self.buttonSize + dif
			self.barwidth = buttonWidth
			self.barheight = boxheight

			-- draw up button
			self:drawRect(
				contentPadding,
				0,
				buttonWidth,
				self.buttonSize,
				self.buttonColor.a,
				self.buttonColor.r,
				self.buttonColor.g,
				self.buttonColor.b
			)

			-- draw down button
			self:drawRect(
				contentPadding,
				self.height - self.buttonSize,
				buttonWidth,
				self.buttonSize,
				self.buttonColor.a,
				self.buttonColor.r,
				self.buttonColor.g,
				self.buttonColor.b
			)

			-- draw the scroll thumb
			self:drawRect(
				self.barx,
				self.bary,
				self.barwidth,
				self.barheight,
				self.thumbColor.a,
				self.thumbColor.r,
				self.thumbColor.g,
				self.thumbColor.b
			)

			-- draw borders
			if self.drawBorder then
				-- main border
				self:drawRectBorder(
					0,
					0,
					self.width,
					self.height,
					self.borderColor.a,
					self.borderColor.r,
					self.borderColor.g,
					self.borderColor.b
				)

				-- up button border
				self:drawRectBorder(
					contentPadding,
					0,
					buttonWidth,
					self.buttonSize,
					self.borderColor.a,
					self.borderColor.r,
					self.borderColor.g,
					self.borderColor.b
				)

				-- down button border
				self:drawRectBorder(
					contentPadding,
					self.height - self.buttonSize,
					buttonWidth,
					self.buttonSize,
					self.borderColor.a,
					self.borderColor.r,
					self.borderColor.g,
					self.borderColor.b
				)

				-- thumb border
				self:drawRectBorder(
					self.barx,
					self.bary,
					self.barwidth,
					self.barheight,
					self.borderColor.a,
					self.borderColor.r,
					self.borderColor.g,
					self.borderColor.b
				)
			end

			if self.doSetStencil then
				self:clearStencilRect()
			end
		else
			self.barx = 0
			self.bary = 0
			self.barwidth = 0
			self.barheight = 0
		end
	else
		local sw = self.parent:getScrollWidth()
		if sw > self:getWidth() then
			if self.doSetStencil then
				self:setStencilRect(0, 0, self.width, self.height)
			end

			-- draw background area
			if self.background then
				self:drawRect(
					0,
					0,
					self.width,
					self.height,
					self.backgroundColor.a,
					self.backgroundColor.r,
					self.backgroundColor.g,
					self.backgroundColor.b
				)
			end

			local del = self:getWidth() / sw
			local boxwidth = del * (self:getWidth() - (self.buttonSize * 2))
			boxwidth = math.ceil(boxwidth)
			boxwidth = math.max(boxwidth, 8)

			local dif = self:getWidth() - (self.buttonSize * 2) - boxwidth
			dif = dif * self.pos
			dif = math.ceil(dif)

			local contentPadding = self.elementPadding
			local buttonHeight = self.height - (contentPadding * 2)

			self.barx = self.buttonSize + dif
			self.bary = contentPadding
			self.barwidth = boxwidth
			self.barheight = buttonHeight

			-- draw left button
			self:drawRect(
				0,
				contentPadding,
				self.buttonSize,
				buttonHeight,
				self.buttonColor.a,
				self.buttonColor.r,
				self.buttonColor.g,
				self.buttonColor.b
			)

			-- draw right button
			self:drawRect(
				self.width - self.buttonSize,
				contentPadding,
				self.buttonSize,
				buttonHeight,
				self.buttonColor.a,
				self.buttonColor.r,
				self.buttonColor.g,
				self.buttonColor.b
			)

			-- draw the scroll thumb
			self:drawRect(
				self.barx,
				self.bary,
				self.barwidth,
				self.barheight,
				self.thumbColor.a,
				self.thumbColor.r,
				self.thumbColor.g,
				self.thumbColor.b
			)

			-- draw borders
			if self.drawBorder then
				-- main border
				self:drawRectBorder(
					0,
					0,
					self.width,
					self.height,
					self.borderColor.a,
					self.borderColor.r,
					self.borderColor.g,
					self.borderColor.b
				)

				-- left button border
				self:drawRectBorder(
					0,
					contentPadding,
					self.buttonSize,
					buttonHeight,
					self.borderColor.a,
					self.borderColor.r,
					self.borderColor.g,
					self.borderColor.b
				)

				-- right button border
				self:drawRectBorder(
					self.width - self.buttonSize,
					contentPadding,
					self.buttonSize,
					buttonHeight,
					self.borderColor.a,
					self.borderColor.r,
					self.borderColor.g,
					self.borderColor.b
				)

				-- thumb border
				self:drawRectBorder(
					self.barx,
					self.bary,
					self.barwidth,
					self.barheight,
					self.borderColor.a,
					self.borderColor.r,
					self.borderColor.g,
					self.borderColor.b
				)
			end

			if self.doSetStencil then
				self:clearStencilRect()
			end
		else
			self.barx = 0
			self.bary = 0
			self.barwidth = 0
			self.barheight = 0
		end
	end
end

function ISCustomScrollBar:new(parent, vertical, width, height)
	local o = {}
	o = ISUIElement:new(0, 0, 0, 0)
	setmetatable(o, self)
	self.__index = self

	o.buttonSize = 15
	o.elementPadding = 2
	o.drawBorder = true
	o.background = true

	o.backgroundColor = { r = 0.1, g = 0.1, b = 0.1, a = 0.6 }
	o.borderColor = { r = 0.4, g = 0.4, b = 0.4, a = 1.0 }
	o.buttonColor = { r = 0.3, g = 0.3, b = 0.3, a = 1.0 }
	o.thumbColor = { r = 0.5, g = 0.5, b = 0.5, a = 1.0 }

	o.anchorLeft = true
	o.anchorRight = false
	o.anchorTop = true
	o.anchorBottom = false
	o.parent = parent
	o.vertical = vertical
	o.pos = 0
	o.scrolling = false

	if vertical then
		o.width = width or 16
		o.height = height or parent.height
	else
		o.width = width or parent.width - (parent.vscroll and 16 or 0)
		o.height = height or 16
	end

	return o
end
