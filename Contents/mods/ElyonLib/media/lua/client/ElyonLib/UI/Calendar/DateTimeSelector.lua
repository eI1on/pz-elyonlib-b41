local DateTimeUtility = require("ElyonLib/DateTime/DateTimeUtility")
local DateTimeModel = require("ElyonLib/DateTime/DateTimeModel")

---@class DateTimeSelector : ISPanel
DateTimeSelector = ISPanel:derive("DateTimeSelector")

local function copyColor(color)
	if not color then
		return nil
	end
	return {
		r = color.r,
		g = color.g,
		b = color.b,
		a = color.a,
	}
end

local CONST = {
	LAYOUT = {
		BUTTON = {
			WIDTH = 110,
			HEIGHT = 25,
			DAY = 35,
			TIME_PICKER = 35,
			NAV = 16,
		},
		LABEL = {
			WIDTH = 80,
		},
		ENTRY = {
			WIDTH = 200,
			TIME_HEIGHT = 30,
		},
		NUMBER_ENTRY = {
			WIDTH = 50,
		},
		PADDING = 10,
		SPACING = {
			SECTION = 10,
			ITEM = 5,
		},
		ELEMENT_HEIGHT = 25,
		HEADER = {
			HEIGHT = 40,
			DAY = 25,
			MONTH_YEAR = 30,
			TIMEZONE_HEIGHT = 20,
		},
		ARROW_SIZE = 12,
	},
	FONT = {
		SMALL = UIFont.Small,
		MEDIUM = UIFont.Medium,
		LARGE = UIFont.Large,
	},
	COLORS = {
		BACKGROUND = {
			NORMAL = { r = 0.1, g = 0.1, b = 0.1, a = 0.8 },
			FIELD = { r = 0.15, g = 0.15, b = 0.15, a = 0.8 },
			PANEL = { r = 0.1, g = 0.1, b = 0.1, a = 0.5 },
		},
		BORDER = {
			NORMAL = { r = 0.4, g = 0.4, b = 0.4, a = 1 },
			DARK = { r = 0.2, g = 0.2, b = 0.2, a = 1 },
			LIGHT = { r = 0.5, g = 0.5, b = 0.5, a = 1 },
		},
		HEADER = {
			BACKGROUND = { r = 0.15, g = 0.15, b = 0.15, a = 0.9 },
		},
		BUTTON = {
			NORMAL = { r = 0.2, g = 0.2, b = 0.2, a = 0.8 },
			HOVER = { r = 0.3, g = 0.3, b = 0.3, a = 0.8 },
			PRESSED = { r = 0.25, g = 0.25, b = 0.35, a = 0.9 },
			SELECTED = { r = 0.3, g = 0.5, b = 0.7, a = 0.8 },
			ACCEPT = { r = 0.2, g = 0.5, b = 0.2, a = 0.85 },
			CLOSE = { r = 0.8, g = 0.2, b = 0.2, a = 0.8 },
			CLOSE_HOVER = { r = 0.9, g = 0.3, b = 0.3, a = 0.8 },
		},
		TEXT = {
			NORMAL = { r = 1, g = 1, b = 1, a = 1 },
			BACKGROUND = { r = 0.12, g = 0.12, b = 0.15, a = 0.8 },
			DIM = { r = 0.7, g = 0.7, b = 0.7, a = 1 },
			INACTIVE = { r = 0.5, g = 0.5, b = 0.5, a = 1 },
			ERROR = { r = 1, g = 0.2, b = 0.2, a = 1 },
		},
		DAY = {
			NORMAL = { r = 0.2, g = 0.2, b = 0.2, a = 0.85 },
			HOVER = { r = 0.3, g = 0.3, b = 0.4, a = 0.9 },
			SELECTED = { r = 0.2, g = 0.3, b = 0.5, a = 0.9 },
			CURRENT = { r = 0.2, g = 0.5, b = 0.3, a = 0.85 },
			INACTIVE = { r = 0.15, g = 0.15, b = 0.15, a = 0.8 },
		},
	},
}

---Create a new DateTimeSelector
---@param x number X position
---@param y number Y position
---@param width number Width
---@param height number Height
---@param useGameTime boolean? Whether to use game time
---@param initialValue DateTable? Optional initial date/time value
---@return DateTimeSelector
function DateTimeSelector:new(x, y, width, height, useGameTime, initialValue)
	local o = ISPanel:new(x, y, width, height)
	setmetatable(o, self)
	self.__index = self

	o.useGameTime = useGameTime or false
	o.showTime = true -- whether to show time selection (hours/minutes)
	o.showSeconds = false -- whether to show seconds selection
	o.startOnMonday = true -- whether to start week on Monday (true) or Sunday (false)
	o.showTimezoneInfo = not o.useGameTime -- only show timezone info for real time
	o.use24HourFormat = true -- whether to use 24-hour format (true) or AM/PM (false)

	o.currentYear = nil
	o.currentMonth = nil
	o.selectedDay = nil
	o.selectedHour = nil
	o.selectedMinute = nil
	o.selectedSecond = nil
	o.selectedAMPM = "AM"

	o.backgroundColor = copyColor(CONST.COLORS.BACKGROUND.NORMAL)
	o.borderColor = copyColor(CONST.COLORS.BORDER.NORMAL)

	if initialValue then
		o.dateModel = DateTimeModel:new({
			date = initialValue,
			useGameTime = o.useGameTime,
		})
	else
		if o.useGameTime then
			o.dateModel = DateTimeModel:new({
				date = DateTimeUtility.getCurrentGameDate(),
				useGameTime = o.useGameTime,
			})
		else
			o.dateModel = DateTimeModel:new({
				useGameTime = o.useGameTime,
			})
		end
	end

	local date = o.dateModel:getLocalDate()
	o.currentYear = date.year
	o.currentMonth = date.month
	o.selectedDay = date.day
	o.selectedHour = date.hour
	o.selectedMinute = date.min
	o.selectedSecond = date.second or date.sec or 0

	if not o.use24HourFormat then
		if o.selectedHour >= 12 then
			o.selectedAMPM = "PM"
			if o.selectedHour > 12 then
				o.selectedHour = o.selectedHour - 12
			end
		else
			o.selectedAMPM = "AM"
			if o.selectedHour == 0 then
				o.selectedHour = 12
			end
		end
	end

	o.callback = nil
	o.target = nil

	o.dayButtons = {}
	o.timeInputs = {}

	o.arrowLeftTexture = getTexture("media/ui/ArrowLeft.png")
	o.arrowRightTexture = getTexture("media/ui/ArrowRight.png")
	o.arrowUpTexture = getTexture("media/ui/ArrowUp.png")
	o.arrowDownTexture = getTexture("media/ui/ArrowDown.png")
	o.arrowBackTexture = getTexture("media/ui/Back.png")

	o.moveWithMouse = true

	local optimalWidth, optimalHeight = o:calculateOptimalSize()
	o:setWidth(optimalWidth)
	o:setHeight(optimalHeight)

	o:centerOnScreen()

	---@diagnostic disable-next-line: return-type-mismatch
	return o
end

function DateTimeSelector:centerOnScreen()
	local screenWidth = getCore():getScreenWidth()
	local screenHeight = getCore():getScreenHeight()

	local x = (screenWidth - self:getWidth()) / 2
	local y = (screenHeight - self:getHeight()) / 2

	self:setX(x)
	self:setY(y)
end

function DateTimeSelector:calculateOptimalSize()
	local padX = CONST.LAYOUT.PADDING
	local padY = CONST.LAYOUT.PADDING

	local headerHeight = padY + CONST.LAYOUT.HEADER.MONTH_YEAR + CONST.LAYOUT.PADDING

	local dayHeaderHeight = CONST.LAYOUT.HEADER.DAY + CONST.LAYOUT.SPACING.ITEM

	local dayButtonHeight = (CONST.LAYOUT.BUTTON.DAY + CONST.LAYOUT.SPACING.ITEM) * 6

	local timePickerHeight = 0
	if self.showTime then
		timePickerHeight = CONST.LAYOUT.BUTTON.TIME_PICKER + CONST.LAYOUT.PADDING
	end

	local timezoneHeight = 0
	if self.showTimezoneInfo then
		timezoneHeight = CONST.LAYOUT.HEADER.TIMEZONE_HEIGHT + CONST.LAYOUT.PADDING
	end

	local buttonTextHeight = getTextManager():MeasureStringY(UIFont.Small, "OK")
	local buttonHeight = buttonTextHeight + padY
	local buttonSectionHeight = buttonHeight + padY

	local totalHeight = headerHeight
		+ dayHeaderHeight
		+ dayButtonHeight
		+ timePickerHeight
		+ timezoneHeight
		+ buttonSectionHeight

	local dayLabelWidth = 0
	local daysOfWeek = self.startOnMonday and DateTimeUtility.DAYS_OF_WEEK_MONDAY_FIRST
		or DateTimeUtility.DAYS_OF_WEEK_SUNDAY_FIRST
	for i = 1, #daysOfWeek do
		local dayName = daysOfWeek[i]
		dayLabelWidth = math.max(dayLabelWidth, getTextManager():MeasureStringX(UIFont.Small, dayName))
	end

	local dayButtonWidth = math.max(CONST.LAYOUT.BUTTON.DAY, dayLabelWidth + CONST.LAYOUT.SPACING.ITEM)
	local calendarWidth = (dayButtonWidth + CONST.LAYOUT.SPACING.ITEM) * 7

	local timePickerWidth = 0
	if self.showTime then
		local timeDigitsWidth = getTextManager():MeasureStringX(UIFont.Small, "88")
		local timeInputWidth = timeDigitsWidth + 20
		local separatorWidth = getTextManager():MeasureStringX(UIFont.Small, ":")
		timePickerWidth = getTextManager():MeasureStringX(UIFont.Small, "Time:")
			+ CONST.LAYOUT.SPACING.ITEM * 2
			+ (timeInputWidth * 2)
			+ (separatorWidth + CONST.LAYOUT.SPACING.ITEM)

		if self.showSeconds then
			timePickerWidth = timePickerWidth + (separatorWidth + CONST.LAYOUT.SPACING.ITEM) + timeInputWidth
		end

		if not self.use24HourFormat then
			local ampmTextWidth = math.max(
				getTextManager():MeasureStringX(UIFont.Small, "AM"),
				getTextManager():MeasureStringX(UIFont.Small, "PM")
			)
			timePickerWidth = timePickerWidth + CONST.LAYOUT.SPACING.ITEM * 2 + (ampmTextWidth + 30)
		end
	end

	local okWidth = getTextManager():MeasureStringX(UIFont.Small, "OK") + 20
	local cancelWidth = getTextManager():MeasureStringX(UIFont.Small, "Cancel") + 20
	local buttonWidth = math.max(80, math.max(okWidth, cancelWidth))
	local buttonSectionWidth = (buttonWidth * 2) + CONST.LAYOUT.SPACING.ITEM * 2

	local timezoneWidth = 0
	if self.showTimezoneInfo then
		local offset = self.dateModel and self.dateModel:getTimezoneOffset() or 0
		local hours = math.floor(math.abs(offset) / 3600)
		local sign = offset >= 0 and "+" or "-"
		local tzInfo = string.format("Timezone: UTC%s%02d", sign, hours)
		timezoneWidth = getTextManager():MeasureStringX(UIFont.Small, tzInfo)
	end

	local contentWidth = math.max(calendarWidth, timePickerWidth, buttonSectionWidth, timezoneWidth)

	local requiredWidth = contentWidth + (padX * 2)

	return requiredWidth, totalHeight
end

function DateTimeSelector:initialise()
	ISPanel.initialise(self)
	self:createChildren()
end

---Set callback for date-time selection
---@param target any Target object for the callback
---@param callback function Callback function to be called when date is selected
function DateTimeSelector:setOnDateTimeSelected(target, callback)
	self.target = target
	self.callback = callback
end

---Set whether to show time selection
---@param show boolean Whether to show time selection
function DateTimeSelector:setShowTime(show)
	if self.showTime == show then
		return
	end
	self.showTime = show
	self:recreateChildren()
end

---Set whether to show seconds
---@param show boolean Whether to show seconds
function DateTimeSelector:setShowSeconds(show)
	if self.showSeconds == show then
		return
	end
	self.showSeconds = show
	if self.showTime then
		self:recreateChildren()
	end
end

---Set whether to use 24-hour format
---@param use24Hour boolean Whether to use 24-hour format
function DateTimeSelector:setUse24HourFormat(use24Hour)
	if self.use24HourFormat == use24Hour then
		return
	end

	self.use24HourFormat = use24Hour

	if use24Hour then
		if self.selectedAMPM == "PM" and self.selectedHour < 12 then
			self.selectedHour = self.selectedHour + 12
		elseif self.selectedAMPM == "AM" and self.selectedHour == 12 then
			self.selectedHour = 0
		end
	else
		if self.selectedHour >= 12 then
			self.selectedAMPM = "PM"
			if self.selectedHour > 12 then
				self.selectedHour = self.selectedHour - 12
			end
		else
			self.selectedAMPM = "AM"
			if self.selectedHour == 0 then
				self.selectedHour = 12
			end
		end
	end

	if self.showTime then
		self:recreateChildren()
	end
end

---Set whether the week starts on Monday
---@param startOnMonday boolean Whether the week starts on Monday
function DateTimeSelector:setStartOnMonday(startOnMonday)
	if self.startOnMonday == startOnMonday then
		return
	end
	self.startOnMonday = startOnMonday
	self:refreshCalendar()
end

---Set whether to show timezone information
---@param show boolean Whether to show timezone information
function DateTimeSelector:setShowTimezoneInfo(show)
	if self.showTimezoneInfo == show then
		return
	end
	self.showTimezoneInfo = show
	self:recreateChildren()
end

---Set the date model
---@param dateModel DateTimeModel The date model to use
function DateTimeSelector:setDateModel(dateModel)
	if not dateModel then
		return
	end
	self.dateModel = dateModel

	local date = self.dateModel:getLocalDate()
	self.currentYear = date.year
	self.currentMonth = date.month
	self.selectedDay = date.day
	self.selectedHour = date.hour
	self.selectedMinute = date.min
	self.selectedSecond = date.second or date.sec or 0

	if not self.use24HourFormat then
		if self.selectedHour >= 12 then
			self.selectedAMPM = "PM"
			if self.selectedHour > 12 then
				self.selectedHour = self.selectedHour - 12
			end
		else
			self.selectedAMPM = "AM"
			if self.selectedHour == 0 then
				self.selectedHour = 12
			end
		end
	end

	self:refreshCalendar()
	self:updateTimeDisplay()
end

function DateTimeSelector:recreateChildren()
	self:clearChildren()

	local optimalWidth, optimalHeight = self:calculateOptimalSize()
	self:setWidth(optimalWidth)
	self:setHeight(optimalHeight)

	self:createChildren()
end

function DateTimeSelector:createChildren()
	self:createHeader()
	self:createDayHeaders()
	self:createCalendarGrid()

	if self.showTime then
		self:createTimePicker()
	end

	if self.showTimezoneInfo then
		self:createTimezoneInfo()
	end

	self:createButtons()
	self:refreshCalendar()

	if self.showTime then
		self:updateTimeDisplay()
	end
end

function DateTimeSelector:createHeader()
	local y = CONST.LAYOUT.PADDING
	local headerWidth = self.width - (CONST.LAYOUT.PADDING * 2)

	self.headerBg = ISPanel:new(CONST.LAYOUT.PADDING, y, headerWidth, CONST.LAYOUT.HEADER.HEIGHT)
	self.headerBg:initialise()
	self.headerBg.backgroundColor = copyColor(CONST.COLORS.HEADER.BACKGROUND)
	self.headerBg.borderColor = self.borderColor
	self:addChild(self.headerBg)

	local navButtonSize = CONST.LAYOUT.BUTTON.NAV

	self.prevMonthBtn = ISButton:new(
		CONST.LAYOUT.PADDING + CONST.LAYOUT.SPACING.ITEM,
		y + (CONST.LAYOUT.HEADER.HEIGHT - navButtonSize) / 2,
		navButtonSize,
		navButtonSize,
		"",
		self,
		self.onPrevMonth
	)
	self.prevMonthBtn:initialise()
	self.prevMonthBtn.backgroundColor = { r = 0, g = 0, b = 0, a = 0 }
	self.prevMonthBtn.backgroundColorMouseOver = { r = 0.2, g = 0.2, b = 0.3, a = 0.3 }
	self.prevMonthBtn.borderColor = { r = 0, g = 0, b = 0, a = 0 }
	self:addChild(self.prevMonthBtn)

	self.nextMonthBtn = ISButton:new(
		CONST.LAYOUT.PADDING + headerWidth - navButtonSize - CONST.LAYOUT.SPACING.ITEM,
		y + (CONST.LAYOUT.HEADER.HEIGHT - navButtonSize) / 2,
		navButtonSize,
		navButtonSize,
		"",
		self,
		self.onNextMonth
	)
	self.nextMonthBtn:initialise()
	self.nextMonthBtn.backgroundColor = { r = 0, g = 0, b = 0, a = 0 }
	self.nextMonthBtn.backgroundColorMouseOver = { r = 0.2, g = 0.2, b = 0.3, a = 0.3 }
	self.nextMonthBtn.borderColor = { r = 0, g = 0, b = 0, a = 0 }
	self:addChild(self.nextMonthBtn)

	local monthYearWidth = headerWidth - (navButtonSize * 2) - (CONST.LAYOUT.SPACING.ITEM * 4)
	local monthWidth = math.floor(monthYearWidth * 0.6)
	local yearWidth = monthYearWidth - monthWidth - CONST.LAYOUT.SPACING.ITEM

	self.monthSelector = ISComboBox:new(
		CONST.LAYOUT.PADDING + navButtonSize + (CONST.LAYOUT.SPACING.ITEM * 2),
		y + (CONST.LAYOUT.HEADER.HEIGHT - CONST.LAYOUT.HEADER.MONTH_YEAR) / 2,
		monthWidth,
		CONST.LAYOUT.HEADER.MONTH_YEAR
	)
	self.monthSelector:initialise()
	for i = 1, #DateTimeUtility.MONTHS do
		local monthName = DateTimeUtility.MONTHS[i]
		self.monthSelector:addOption(monthName)
	end
	self.monthSelector.selected = self.currentMonth
	self.monthSelector.target = self
	self.monthSelector.onChange = self.onMonthSelected
	self.monthSelector.backgroundColor = copyColor(CONST.COLORS.HEADER.BACKGROUND)
	self.monthSelector.borderColor = self.borderColor
	self:addChild(self.monthSelector)

	self.yearSelector = self:createYearSelector(
		CONST.LAYOUT.PADDING + navButtonSize + (CONST.LAYOUT.SPACING.ITEM * 2) + monthWidth + CONST.LAYOUT.SPACING.ITEM,
		y + (CONST.LAYOUT.HEADER.HEIGHT - CONST.LAYOUT.HEADER.MONTH_YEAR) / 2,
		yearWidth,
		CONST.LAYOUT.HEADER.MONTH_YEAR
	)
	self:addChild(self.yearSelector)
end

function DateTimeSelector:createYearSelector(x, y, width, height)
	local yearPanel = ISPanel:new(x, y, width, height)
	yearPanel:initialise()
	yearPanel.backgroundColor = copyColor(CONST.COLORS.HEADER.BACKGROUND)
	yearPanel.borderColor = self.borderColor

	local arrowWidth = CONST.LAYOUT.ARROW_SIZE + 4
	yearPanel.textEntry = ISTextEntryBox:new(tostring(self.currentYear), 0, 0, width - arrowWidth, height)
	yearPanel.textEntry:initialise()
	yearPanel.textEntry:instantiate()
	yearPanel.textEntry:setOnlyNumbers(true)
	yearPanel.textEntry:setMaxTextLength(4)
	yearPanel.textEntry.backgroundColor = copyColor(CONST.COLORS.HEADER.BACKGROUND)
	yearPanel.textEntry.borderColor = { r = 0, g = 0, b = 0, a = 0 }
	yearPanel.textEntry.onCommandEntered = function()
		local newValue = tonumber(yearPanel.textEntry:getText())
		if newValue then
			self:onYearChanged(newValue)
		end
	end
	yearPanel:addChild(yearPanel.textEntry)

	yearPanel.render = function(self)
		ISPanel.render(self)
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

		local arrowSize = CONST.LAYOUT.ARROW_SIZE
		local arrowX = self.width - arrowSize - 2

		if self.parent.arrowUpTexture then
			self:drawTexture(self.parent.arrowUpTexture, arrowX, 2, 1, 0.9, 0.9, 0.9)
		end

		if self.parent.arrowDownTexture then
			self:drawTexture(self.parent.arrowDownTexture, arrowX, self.height - arrowSize - 2, 1, 0.9, 0.9, 0.9)
		end
	end

	yearPanel.onMouseDown = function(self, x, y)
		local arrowSize = CONST.LAYOUT.ARROW_SIZE
		local arrowX = self.width - arrowSize - 2

		if x >= arrowX and x < arrowX + arrowSize and y >= 2 and y < 2 + arrowSize then
			self.parent:onYearChanged(self.parent.currentYear + 1)
			return true
		end

		if x >= arrowX and x < arrowX + arrowSize and y >= self.height - arrowSize - 2 and y < self.height - 2 then
			self.parent:onYearChanged(self.parent.currentYear - 1)
			return true
		end

		return false
	end

	yearPanel.onMouseWheel = function(self, del)
		self.parent:onYearChanged(self.parent.currentYear + (del > 0 and 1 or -1))
		return true
	end

	return yearPanel
end

function DateTimeSelector:createDayHeaders()
	local dayHeaderY = CONST.LAYOUT.PADDING + CONST.LAYOUT.HEADER.HEIGHT + CONST.LAYOUT.PADDING
	local daysOfWeek = self.startOnMonday and DateTimeUtility.DAYS_OF_WEEK_MONDAY_FIRST
		or DateTimeUtility.DAYS_OF_WEEK_SUNDAY_FIRST
	local dayWidth = CONST.LAYOUT.BUTTON.DAY

	local gridWidth = 7 * dayWidth
	local startX = (self.width - gridWidth) / 2

	for i = 1, 7 do
		local x = startX + (i - 1) * dayWidth
		local dayLabel = ISLabel:new(
			x,
			dayHeaderY,
			CONST.LAYOUT.HEADER.DAY,
			daysOfWeek[i],
			CONST.COLORS.TEXT.NORMAL.r,
			CONST.COLORS.TEXT.NORMAL.g,
			CONST.COLORS.TEXT.NORMAL.b,
			CONST.COLORS.TEXT.NORMAL.a,
			UIFont.Small,
			true
		)
		dayLabel:initialise()
		dayLabel:setWidth(dayWidth)
		dayLabel:setX(x + (dayWidth - dayLabel:getWidth()) / 2)
		self:addChild(dayLabel)
	end
end

function DateTimeSelector:createCalendarGrid()
	self.dayButtons = {}

	local gridY = CONST.LAYOUT.PADDING + CONST.LAYOUT.HEADER.HEIGHT + CONST.LAYOUT.PADDING + CONST.LAYOUT.HEADER.DAY
	local dayWidth = CONST.LAYOUT.BUTTON.DAY
	local dayHeight = CONST.LAYOUT.BUTTON.DAY

	local gridWidth = 7 * dayWidth
	local startX = (self.width - gridWidth) / 2

	for row = 1, 6 do
		for col = 1, 7 do
			local x = startX + (col - 1) * dayWidth
			local y = gridY + (row - 1) * dayHeight

			local dayButton = ISButton:new(x, y, dayWidth, dayHeight, "", self, self.onDaySelected)
			dayButton:initialise()
			dayButton.backgroundColor = copyColor(CONST.COLORS.DAY.NORMAL)
			dayButton.backgroundColorMouseOver = copyColor(CONST.COLORS.DAY.HOVER)
			dayButton.borderColor = self.borderColor
			dayButton.textColor = CONST.COLORS.TEXT.NORMAL
			dayButton.row = row
			dayButton.col = col
			dayButton.day = 0
			dayButton.isCurrentMonth = false

			table.insert(self.dayButtons, dayButton)
			self:addChild(dayButton)
		end
	end
end

function DateTimeSelector:createTimePicker()
	local timeY = CONST.LAYOUT.PADDING
		+ CONST.LAYOUT.HEADER.HEIGHT
		+ CONST.LAYOUT.PADDING
		+ CONST.LAYOUT.HEADER.DAY
		+ (6 * CONST.LAYOUT.BUTTON.DAY)
		+ CONST.LAYOUT.PADDING

	local timeWidth = self.width - (CONST.LAYOUT.PADDING * 2)
	self.timeContainer = ISPanel:new(CONST.LAYOUT.PADDING, timeY, timeWidth, CONST.LAYOUT.BUTTON.TIME_PICKER)
	self.timeContainer:initialise()
	self.timeContainer.backgroundColor = copyColor(CONST.COLORS.BACKGROUND.NORMAL)
	self.timeContainer.borderColor = self.borderColor
	self:addChild(self.timeContainer)

	self.timeLabel = ISLabel:new(
		CONST.LAYOUT.SPACING.ITEM * 2,
		(CONST.LAYOUT.BUTTON.TIME_PICKER - 20) / 2,
		20,
		"Time:",
		CONST.COLORS.TEXT.NORMAL.r,
		CONST.COLORS.TEXT.NORMAL.g,
		CONST.COLORS.TEXT.NORMAL.b,
		CONST.COLORS.TEXT.NORMAL.a,
		UIFont.Small,
		true
	)
	self.timeLabel:initialise()
	self.timeContainer:addChild(self.timeLabel)

	local labelWidth = getTextManager():MeasureStringX(UIFont.Small, "Time:")
	local startX = (CONST.LAYOUT.SPACING.ITEM * 3) + labelWidth
	local inputWidth = 50 -- Increased width
	local inputHeight = CONST.LAYOUT.ENTRY.TIME_HEIGHT
	local inputY = (CONST.LAYOUT.BUTTON.TIME_PICKER - inputHeight) / 2
	local separatorWidth = 15

	self.timeInputs = {}

	self:createCustomTimeInput(
		"hour",
		startX,
		inputY,
		inputWidth,
		inputHeight,
		self.selectedHour,
		0,
		self.use24HourFormat and 23 or 12
	)

	local separatorX = startX + inputWidth + CONST.LAYOUT.SPACING.ITEM
	local separator1 = ISLabel:new(
		separatorX,
		inputY,
		separatorWidth,
		":",
		CONST.COLORS.TEXT.NORMAL.r,
		CONST.COLORS.TEXT.NORMAL.g,
		CONST.COLORS.TEXT.NORMAL.b,
		CONST.COLORS.TEXT.NORMAL.a,
		UIFont.Large,
		true
	)
	separator1:initialise()
	separator1:setY(inputY + (inputHeight - separator1:getHeight()) / 2)
	self.timeContainer:addChild(separator1)

	self:createCustomTimeInput(
		"minute",
		separatorX + separatorWidth,
		inputY,
		inputWidth,
		inputHeight,
		self.selectedMinute,
		0,
		59
	)

	if self.showSeconds then
		local separator2X = separatorX + separatorWidth + inputWidth + CONST.LAYOUT.SPACING.ITEM
		local separator2 = ISLabel:new(
			separator2X,
			inputY,
			separatorWidth,
			":",
			CONST.COLORS.TEXT.NORMAL.r,
			CONST.COLORS.TEXT.NORMAL.g,
			CONST.COLORS.TEXT.NORMAL.b,
			CONST.COLORS.TEXT.NORMAL.a,
			UIFont.Large,
			true
		)
		separator2:initialise()
		separator2:setY(inputY + (inputHeight - separator2:getHeight()) / 2)
		self.timeContainer:addChild(separator2)

		self:createCustomTimeInput(
			"second",
			separator2X + separatorWidth,
			inputY,
			inputWidth,
			inputHeight,
			self.selectedSecond,
			0,
			59
		)
	end

	if not self.use24HourFormat then
		local ampmX = startX + inputWidth * 2 + separatorWidth * 2 + (CONST.LAYOUT.SPACING.ITEM * 3)
		if self.showSeconds then
			ampmX = ampmX + inputWidth + separatorWidth
		end

		local ampmTextWidth = math.max(
			getTextManager():MeasureStringX(UIFont.Small, "AM"),
			getTextManager():MeasureStringX(UIFont.Small, "PM")
		)
		local ampmWidth = ampmTextWidth + 30

		self.ampmSelector = ISComboBox:new(ampmX, inputY, ampmWidth, inputHeight)
		self.ampmSelector:initialise()
		self.ampmSelector:addOption("AM")
		self.ampmSelector:addOption("PM")
		self.ampmSelector.selected = self.selectedAMPM == "AM" and 1 or 2
		self.ampmSelector.target = self
		self.ampmSelector.onChange = self.onAMPMSelected
		self.ampmSelector.backgroundColor = copyColor(CONST.COLORS.BACKGROUND.FIELD)
		self.ampmSelector.borderColor = self.borderColor
		self.timeContainer:addChild(self.ampmSelector)
	end
end

---Create a custom time input component (hour/minute/second)
---@param type string The type of input ("hour", "minute", "second")
---@param x number X position
---@param y number Y position
---@param width number Width
---@param height number Height
---@param initialValue number Initial value
---@param minValue number Minimum value
---@param maxValue number Maximum value
function DateTimeSelector:createCustomTimeInput(type, x, y, width, height, initialValue, minValue, maxValue)
	local container = ISPanel:new(x, y, width, height)
	container:initialise()
	container.backgroundColor = copyColor(CONST.COLORS.BACKGROUND.FIELD)
	container.borderColor = self.borderColor
	container.type = type
	container.value = initialValue or 0
	container.minValue = minValue or 0
	container.maxValue = maxValue or 59
	self.timeContainer:addChild(container)

	container.textEntry =
		ISTextEntryBox:new(string.format("%02d", container.value), 0, 0, width - (CONST.LAYOUT.ARROW_SIZE + 4), height)
	container.textEntry:initialise()
	container.textEntry:instantiate()
	container.textEntry:setOnlyNumbers(true)
	container.textEntry:setMaxTextLength(2)
	container.textEntry.backgroundColor = copyColor(CONST.COLORS.BACKGROUND.FIELD)
	container.textEntry.borderColor = { r = 0, g = 0, b = 0, a = 0 }
	container.textEntry.onCommandEntered = function()
		local newValue = tonumber(container.textEntry:getText())
		if newValue then
			self:onTimeChange(type, newValue - container.value)
		end
		container.textEntry:setText(
			string.format(
				"%02d",
				(type == "hour" and self.selectedHour)
					or (type == "minute" and self.selectedMinute or self.selectedSecond)
			)
		)
	end
	container:addChild(container.textEntry)

	container.render = function(self)
		ISPanel.render(self)
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

		local arrowSize = CONST.LAYOUT.ARROW_SIZE
		local arrowX = self.width - arrowSize - 2

		if self.parent.parent.arrowUpTexture then
			self:drawTexture(self.parent.parent.arrowUpTexture, arrowX, 2, 1, 0.8, 0.8, 0.8)
		end

		if self.parent.parent.arrowDownTexture then
			self:drawTexture(self.parent.parent.arrowDownTexture, arrowX, self.height - arrowSize - 2, 1, 0.8, 0.8, 0.8)
		end
	end

	container.onMouseDown = function(self, x, y)
		local arrowSize = CONST.LAYOUT.ARROW_SIZE
		local arrowX = self.width - arrowSize - 2

		if x >= arrowX and x < arrowX + arrowSize and y >= 2 and y < 2 + arrowSize then
			self.parent.parent:onTimeChange(self.type, 1)
			return true
		end

		if x >= arrowX and x < arrowX + arrowSize and y >= self.height - arrowSize - 2 and y < self.height - 2 then
			self.parent.parent:onTimeChange(self.type, -1)
			return true
		end

		return false
	end

	container.onMouseWheel = function(self, del)
		self.parent.parent:onTimeChange(self.type, del > 0 and 1 or -1)
		return true
	end

	table.insert(self.timeInputs, {
		container = container,
		type = type,
	})

	return container
end

function DateTimeSelector:createTimezoneInfo()
	local timeY = CONST.LAYOUT.PADDING
		+ CONST.LAYOUT.HEADER.HEIGHT
		+ CONST.LAYOUT.PADDING
		+ CONST.LAYOUT.HEADER.DAY
		+ (6 * CONST.LAYOUT.BUTTON.DAY)
		+ CONST.LAYOUT.PADDING
	local tzY = timeY + CONST.LAYOUT.BUTTON.TIME_PICKER + CONST.LAYOUT.PADDING
	if not self.showTime then
		tzY = timeY
	end

	local tzHeight = CONST.LAYOUT.HEADER.TIMEZONE_HEIGHT

	local offset = self.dateModel:getTimezoneOffset()
	local hours = math.floor(math.abs(offset) / 3600)
	local minutes = math.floor((math.abs(offset) % 3600) / 60)
	local sign = offset >= 0 and "+" or "-"
	local tzInfo = string.format("Timezone: UTC%s%02d:%02d", sign, hours, minutes)

	self.tzLabel = ISLabel:new(
		CONST.LAYOUT.PADDING,
		tzY,
		tzHeight,
		tzInfo,
		CONST.COLORS.TEXT.NORMAL.r,
		CONST.COLORS.TEXT.NORMAL.g,
		CONST.COLORS.TEXT.NORMAL.b,
		CONST.COLORS.TEXT.NORMAL.a,
		UIFont.Small,
		true
	)
	self.tzLabel:initialise()
	self.tzLabel:setX((self.width - self.tzLabel:getWidth()) / 2)
	self:addChild(self.tzLabel)
end

function DateTimeSelector:createButtons()
	local buttonY = self.height - CONST.LAYOUT.BUTTON.HEIGHT - CONST.LAYOUT.PADDING
	local buttonWidth = 80
	local spacing = CONST.LAYOUT.SPACING.ITEM * 2

	self.cancelButton = ISButton:new(
		self.width - buttonWidth - CONST.LAYOUT.PADDING,
		buttonY,
		buttonWidth,
		CONST.LAYOUT.BUTTON.HEIGHT,
		"Cancel",
		self,
		self.onCancel
	)
	self.cancelButton:initialise()
	self.cancelButton.backgroundColor = copyColor(CONST.COLORS.BUTTON.CLOSE)
	self.cancelButton.backgroundColorMouseOver = copyColor(CONST.COLORS.BUTTON.HOVER)
	self.cancelButton.borderColor = self.borderColor
	self.cancelButton.textColor = CONST.COLORS.TEXT.NORMAL
	self:addChild(self.cancelButton)

	self.okButton = ISButton:new(
		self.width - (buttonWidth * 2) - spacing - CONST.LAYOUT.PADDING,
		buttonY,
		buttonWidth,
		CONST.LAYOUT.BUTTON.HEIGHT,
		"OK",
		self,
		self.onOK
	)
	self.okButton:initialise()
	self.okButton.backgroundColor = copyColor(CONST.COLORS.BUTTON.ACCEPT)
	self.okButton.backgroundColorMouseOver = copyColor(CONST.COLORS.BUTTON.HOVER)
	self.okButton.borderColor = self.borderColor
	self.okButton.textColor = CONST.COLORS.TEXT.NORMAL
	self:addChild(self.okButton)
end

function DateTimeSelector:onMonthSelected()
	if not self.monthSelector or not self.monthSelector.selected then
		return
	end

	self.currentMonth = self.monthSelector.selected
	self:refreshCalendar()
end

function DateTimeSelector:onYearChanged(newYear)
	if not newYear then
		return
	end

	self.currentYear = math.max(1900, math.min(2100, newYear))
	if self.yearSelector and self.yearSelector.textEntry then
		self.yearSelector.textEntry:setText(tostring(self.currentYear))
	end

	self:refreshCalendar()
end

function DateTimeSelector:onPrevMonth()
	self.currentMonth = self.currentMonth - 1
	if self.currentMonth < 1 then
		self.currentMonth = 12
		self.currentYear = self.currentYear - 1
	end

	if self.monthSelector then
		self.monthSelector.selected = self.currentMonth
	end
	if self.yearSelector and self.yearSelector.textEntry then
		self.yearSelector.textEntry:setText(tostring(self.currentYear))
	end

	self:refreshCalendar()
end

function DateTimeSelector:onNextMonth()
	self.currentMonth = self.currentMonth + 1
	if self.currentMonth > 12 then
		self.currentMonth = 1
		self.currentYear = self.currentYear + 1
	end

	if self.monthSelector then
		self.monthSelector.selected = self.currentMonth
	end

	if self.yearSelector and self.yearSelector.textEntry then
		self.yearSelector.textEntry:setText(tostring(self.currentYear))
	end

	self:refreshCalendar()
end

---Handle day selection
---@param button ISButton The clicked day button
function DateTimeSelector:onDaySelected(button)
	if not button or button.day <= 0 then
		return
	end
	if not button.isCurrentMonth then
		if button.monthOffset == -1 then
			self:onPrevMonth()
		elseif button.monthOffset == 1 then
			self:onNextMonth()
		end

		self.selectedDay = button.day
	else
		self.selectedDay = button.day
	end

	local date = self.dateModel:getLocalDate()
	date.year = self.currentYear
	date.month = self.currentMonth
	date.day = self.selectedDay
	self.dateModel:setDate(date)

	self:refreshCalendar()
end

---Handle time input change
---@param type string The type of time input changed ("hour", "minute", "second")
---@param delta number The amount to change the value by
function DateTimeSelector:onTimeChange(type, delta)
	local date = self.dateModel:getLocalDate()

	if type == "hour" then
		if self.use24HourFormat then
			local hour = self.selectedHour + delta
			if hour < 0 then
				hour = 23
			elseif hour > 23 then
				hour = 0
			end

			self.selectedHour = hour
			date.hour = hour
		else
			local hour = self.selectedHour + delta

			if hour < 1 then
				hour = 12
				self.selectedAMPM = self.selectedAMPM == "AM" and "PM" or "AM"
				if self.ampmSelector then
					self.ampmSelector.selected = self.selectedAMPM == "AM" and 1 or 2
				end
			elseif hour > 12 then
				hour = 1
				self.selectedAMPM = self.selectedAMPM == "AM" and "PM" or "AM"
				if self.ampmSelector then
					self.ampmSelector.selected = self.selectedAMPM == "AM" and 1 or 2
				end
			end

			self.selectedHour = hour

			if self.selectedAMPM == "PM" and hour < 12 then
				date.hour = hour + 12
			elseif self.selectedAMPM == "AM" and hour == 12 then
				date.hour = 0
			else
				date.hour = hour
			end
		end
	elseif type == "minute" then
		local minute = self.selectedMinute + delta
		if minute < 0 then
			minute = 59
		elseif minute > 59 then
			minute = 0
		end

		self.selectedMinute = minute
		date.min = minute
	elseif type == "second" then
		local second = self.selectedSecond + delta
		if second < 0 then
			second = 59
		elseif second > 59 then
			second = 0
		end

		self.selectedSecond = second
		date.second = second
	end

	self.dateModel:setDate(date)
	self:updateTimeDisplay()
end

function DateTimeSelector:onAMPMSelected()
	if not self.ampmSelector or not self.ampmSelector.selected then
		return
	end

	local selectedText = self.ampmSelector:getOptionText(self.ampmSelector.selected)
	if selectedText then
		if self.selectedAMPM ~= selectedText then
			self.selectedAMPM = selectedText

			local date = self.dateModel:getLocalDate()
			local hour = self.selectedHour

			if self.selectedAMPM == "PM" and hour < 12 then
				date.hour = hour + 12
			elseif self.selectedAMPM == "AM" and hour == 12 then
				date.hour = 0
			else
				date.hour = hour
			end

			self.dateModel:setDate(date)
		end
	end
end

function DateTimeSelector:onOK()
	if self.callback and self.target then
		local localDate = self.dateModel:getLocalDate()
		localDate.year = self.currentYear
		localDate.month = self.currentMonth
		localDate.day = self.selectedDay
		localDate.hour = self.selectedHour
		localDate.min = self.selectedMinute
		localDate.second = self.selectedSecond

		self.dateModel:setDate(localDate)

		self.callback(self.target, localDate, false)
	end

	self:close()
end

function DateTimeSelector:onCancel()
	if self.callback and self.target then
		self.callback(self.target, nil, true)
	end

	self:close()
end

function DateTimeSelector:updateTimeDisplay()
	for i, input in ipairs(self.timeInputs) do
		local value = 0

		if input.type == "hour" then
			value = self.selectedHour
		elseif input.type == "minute" then
			value = self.selectedMinute
		elseif input.type == "second" then
			value = self.selectedSecond
		end

		if input.container.textEntry then
			input.container.textEntry:setText(string.format("%02d", value))
		end
	end
end

---Check if a date is today
---@param year number Year
---@param month number Month (1-12)
---@param day number Day
---@return boolean Is today
function DateTimeSelector:isCurrentDay(year, month, day)
	if self.useGameTime then
		local gameTime = getGameTime()
		if gameTime then
			return year == gameTime:getYear() and month == gameTime:getMonth() + 1 and day == gameTime:getDay() + 1
		end
	else
		local now = DateTimeUtility.getCurrentLocalDate()
		return year == now.year and month == now.month and day == now.day
	end

	return false
end

function DateTimeSelector:refreshCalendar()
	if not self.currentYear or not self.currentMonth or #self.dayButtons == 0 then
		return
	end

	local firstDay = DateTimeUtility.getFirstDayOfMonth(self.currentYear, self.currentMonth)

	if self.startOnMonday then
		firstDay = firstDay - 1
		if firstDay == 0 then
			firstDay = 7
		end
	end

	local daysInMonth = DateTimeUtility.getDaysInMonth(self.currentMonth, self.currentYear)

	local prevMonth = self.currentMonth - 1
	local prevYear = self.currentYear
	if prevMonth < 1 then
		prevMonth = 12
		prevYear = prevYear - 1
	end
	local daysInPrevMonth = DateTimeUtility.getDaysInMonth(prevMonth, prevYear)

	for i, button in ipairs(self.dayButtons) do
		button:setTitle("")
		button.day = 0
		button.isCurrentMonth = false
		button.backgroundColor = copyColor(CONST.COLORS.DAY.INACTIVE)
		button.textColor = copyColor(CONST.COLORS.TEXT.INACTIVE)
	end

	for i = 1, firstDay - 1 do
		local index = i
		local button = self.dayButtons[index]
		if button then
			local prevMonthDay = daysInPrevMonth - (firstDay - 1) + i
			button:setTitle(tostring(prevMonthDay))
			button.day = prevMonthDay
			button.isCurrentMonth = false
			button.monthOffset = -1
		end
	end

	local isSelectedMonthYear = (self.currentMonth == self.dateModel:getLocalDate().month)
		and (self.currentYear == self.dateModel:getLocalDate().year)

	for i = 1, daysInMonth do
		local index = firstDay - 1 + i
		local button = self.dayButtons[index]
		if button then
			button:setTitle(tostring(i))
			button.day = i
			button.isCurrentMonth = true
			button.monthOffset = 0

			button.backgroundColor = copyColor(CONST.COLORS.DAY.NORMAL)
			button.textColor = CONST.COLORS.TEXT.NORMAL

			if isSelectedMonthYear and i == self.selectedDay then
				button.backgroundColor = copyColor(CONST.COLORS.DAY.SELECTED)
			elseif self:isCurrentDay(self.currentYear, self.currentMonth, i) then
				button.backgroundColor = copyColor(CONST.COLORS.DAY.CURRENT)
			end
		end
	end

	local nextMonthStart = firstDay + daysInMonth - 1
	local nextMonthDay = 1

	for i = nextMonthStart + 1, #self.dayButtons do
		local button = self.dayButtons[i]
		if button then
			button:setTitle(tostring(nextMonthDay))
			button.day = nextMonthDay
			button.isCurrentMonth = false
			button.monthOffset = 1
			nextMonthDay = nextMonthDay + 1
		end
	end
end

---Mouse wheel handler
---@param del number Wheel delta
---@return boolean handled Whether the event was handled
function DateTimeSelector:onMouseWheel(del)
	for _, input in ipairs(self.timeInputs) do
		local x = self:getMouseX()
		local y = self:getMouseY()

		local container = input.container
		local containerX = container:getX() + self.timeContainer:getX()
		local containerY = container:getY() + self.timeContainer:getY()

		if
			x >= containerX
			and x < containerX + container:getWidth()
			and y >= containerY
			and y < containerY + container:getHeight()
		then
			self:onTimeChange(input.type, del > 0 and 1 or -1)
			return true
		end
	end

	if del > 0 then
		self:onPrevMonth()
	else
		self:onNextMonth()
	end

	return true
end

function DateTimeSelector:renderArrows()
	if self.prevMonthBtn and self.arrowLeftTexture then
		self.prevMonthBtn:drawTexture(
			self.arrowLeftTexture,
			(self.prevMonthBtn:getWidth() - 16) / 2,
			(self.prevMonthBtn:getHeight() - 16) / 2,
			1,
			1,
			1,
			1
		)
	end

	if self.nextMonthBtn and self.arrowRightTexture then
		self.nextMonthBtn:drawTexture(
			self.arrowRightTexture,
			(self.nextMonthBtn:getWidth() - 16) / 2,
			(self.nextMonthBtn:getHeight() - 16) / 2,
			1,
			1,
			1,
			1
		)
	end
end

function DateTimeSelector:prerender()
	ISPanel.prerender(self)
end

function DateTimeSelector:render()
	ISPanel.render(self)
	self:renderArrows()
end

function DateTimeSelector:close()
	self:setVisible(false)
	self:removeFromUIManager()
end

return DateTimeSelector
