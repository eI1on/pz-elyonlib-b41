require("ISUI/ISScrollingListBox")

local UIUtils = require("ElyonLib/UI/Utils/UIUtils")

local ISClippedScrollingListBox = ISScrollingListBox:derive("ISClippedScrollingListBox")

function ISClippedScrollingListBox:prerender()
	self.doRepaintStencil = true
	if self.vscroll then
		self.vscroll.doSetStencil = true
		self.vscroll.doRepaintStencil = true
	end
	UIUtils.syncListScrollBar(self)
	ISScrollingListBox.prerender(self)
end

return ISClippedScrollingListBox
