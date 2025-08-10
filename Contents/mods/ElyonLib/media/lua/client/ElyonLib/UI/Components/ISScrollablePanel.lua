require("ISUI/ISPanel")

---@class ISScrollablePanel : ISPanel
ISScrollablePanel = ISPanel:derive("ISScrollablePanel")

function ISScrollablePanel:initialise()
	ISPanel.initialise(self)

	self.contentPanel = ISPanel:new(0, 0, self.width - 20, 800)
	self.contentPanel:initialise()
	self.contentPanel.backgroundColor = { r = 0, g = 0, b = 0, a = 0 }
	self.contentPanel.borderColor = { r = 0, g = 0, b = 0, a = 0 }
	self:addChild(self.contentPanel)

	self.vscroll = ISCustomScrollBar:new(self, true)
	self.vscroll:initialise()
	self:addChild(self.vscroll)

	self.scrollBarVisible = false
end

function ISScrollablePanel:createChildren()
	ISPanel.createChildren(self)
end

function ISScrollablePanel:prerender()
	ISPanel.prerender(self)
	self:setStencilRect(0, 0, self.width, self.height)
end

function ISScrollablePanel:render()
	ISPanel.render(self)
	self:clearStencilRect()
end

function ISScrollablePanel:onMouseWheel(del)
	if self.scrollBarVisible then
		self:setYScroll(self:getYScroll() - (del * 20))
		return true
	end
	return false
end

function ISScrollablePanel:addContent(element)
	self.contentPanel:addChild(element)

	self:updateContentHeight()
end

function ISScrollablePanel:updateContentHeight()
	local maxY = 0

	for _, element in pairs(self.contentPanel:getChildren()) do
		local elementBottom = element:getY() + element:getHeight()
		if elementBottom > maxY then
			maxY = elementBottom
		end
	end

	maxY = maxY + 20

	self.contentPanel:setHeight(maxY)
	self:setScrollHeight(maxY)

	local needsScrollbar = maxY > self.height

	self.scrollBarVisible = needsScrollbar

	if self.vscroll then
		self.vscroll:setVisible(needsScrollbar)
	end
end

function ISScrollablePanel:setYScroll(y)
	ISPanel.setYScroll(self, y)
	self.contentPanel:setY(self:getYScroll())
end

function ISScrollablePanel:clear()
	self.contentPanel:clearChildren()

	self:setYScroll(0)

	self:updateContentHeight()
end

function ISScrollablePanel:onResize()
	ISPanel.onResize(self)

	self.contentPanel:setWidth(self.width - (self.scrollBarVisible and self.vscroll:getWidth() or 0))

	self:updateContentHeight()
end

function ISScrollablePanel:new(x, y, width, height)
	local o = ISPanel:new(x, y, width, height)
	setmetatable(o, self)
	self.__index = self

	o.backgroundColor = { r = 0, g = 0, b = 0, a = 0.0 }
	o.contentHeight = 0

	return o
end

return ISScrollablePanel
