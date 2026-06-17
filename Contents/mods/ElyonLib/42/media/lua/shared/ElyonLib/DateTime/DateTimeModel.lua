local DateTimeUtility = require("ElyonLib/DateTime/DateTimeUtility")

---@class DateTimeModel
---@field private utcDate DateTable Internal storage of date in UTC
---@field private useGameTime boolean Whether to use game time instead of real time
---@field private timezoneOffset number Timezone offset in seconds
---@field private displayFormat string|DateFormat Format used for displaying the date
local DateTimeModel = {}
DateTimeModel.__index = DateTimeModel

---@class DateTimeModelOptions
---@field date DateTable? Initial date table (nil for current time)
---@field timezone number? Timezone offset in seconds (nil for local timezone)
---@field format string|DateFormat? Display format (nil for ISO)
---@field useGameTime boolean? Whether to use game time instead of real time

---Create a new DateTimeModel instance
---@param options DateTimeModelOptions? Optional settings
---@return DateTimeModel
function DateTimeModel:new(options)
	local o = {}
	setmetatable(o, self)

	options = options or {}
	o.useGameTime = options.useGameTime or false
	o.displayFormat = options.format or DateTimeUtility.FORMAT.ISO

	if o.useGameTime then
		if options.date then
			o.utcDate = options.date
		else
			o.utcDate = DateTimeUtility.getCurrentGameDate()
		end
		o.timezoneOffset = 0
	else
		if options.date then
			if options.timezone then
				o.utcDate = DateTimeUtility.toUTC(options.date, options.timezone)
			else
				o.utcDate = options.date
			end
		else
			o.utcDate = DateTimeUtility.getCurrentUTCDate()
		end
		-- timezone offset (only relevant for real time)
		o.timezoneOffset = options.timezone or DateTimeUtility.getLocalTimezoneOffset()
	end

	return o
end

---Get the date in UTC or game time
---@return DateTable dateTable The date in UTC or game time
function DateTimeModel:getUTCDate()
	return {
		year = self.utcDate.year,
		month = self.utcDate.month,
		day = self.utcDate.day,
		hour = self.utcDate.hour,
		min = self.utcDate.min,
		second = self.utcDate.sec or self.utcDate.second or 0,
	}
end

---Get the date in the model's timezone or game time
---@return DateTable convertedDate The date in local timezone or game time
function DateTimeModel:getLocalDate()
	if self.useGameTime then
		return self:getUTCDate()
	else
		return DateTimeUtility.convertTimezone(self.utcDate, 0, self.timezoneOffset)
	end
end

---Get the date in a specific timezone
---@param timezoneOffset number The timezone offset in seconds
---@return DateTable convertedDate The date in the specified timezone
function DateTimeModel:getDateInTimezone(timezoneOffset)
	return DateTimeUtility.convertTimezone(self.utcDate, 0, timezoneOffset)
end

---Set the date (in the current timezone or directly for game time)
---@param dateTable DateTable The new date
function DateTimeModel:setDate(dateTable)
	if self.useGameTime then
		self.utcDate = dateTable
	else
		self.utcDate = DateTimeUtility.toUTC(dateTable, self.timezoneOffset)
	end
end

---Set the date in UTC
---@param utcDateTable DateTable The new UTC date
function DateTimeModel:setUTCDate(utcDateTable)
	self.utcDate = utcDateTable
end

---Set the timezone offset
---@param timezoneOffset number The timezone offset in seconds
function DateTimeModel:setTimezoneOffset(timezoneOffset)
	self.timezoneOffset = timezoneOffset
end

---Get the timezone offset
---@return number timezoneOffset The timezone offset in seconds
function DateTimeModel:getTimezoneOffset()
	return self.timezoneOffset
end

---Set the display format
---@param format string|DateFormat The format to use
function DateTimeModel:setDisplayFormat(format)
	self.displayFormat = format
end

---Get a formatted string representation of the date
---@param format string|DateFormat? Optional format override
---@return string formattedDate Formatted date string
function DateTimeModel:format(format)
	local localDate = self:getLocalDate()
	return DateTimeUtility.formatDate(localDate, format or self.displayFormat)
end

---Format the date with timezone information
---@param format string|DateFormat? Optional format override
---@return string formattedDateTime  Formatted date string with timezone
function DateTimeModel:formatWithTimezone(format)
	local localDate = self:getLocalDate()
	return DateTimeUtility.formatDateTimeWithTZ(localDate, format or self.displayFormat)
end

---Convert to a timestamp (seconds since epoch) or game timestamp
---@return number|nil Timestamp
function DateTimeModel:toTimestamp()
	if self.useGameTime then
		local date = self:getUTCDate()
		local secondsSinceStart = (date.year * 365 * 24 * 60)
			+ (date.month * 30 * 24 * 60)
			+ (date.day * 24 * 60)
			+ (date.hour * 60)
			+ (date.min * 60)
			+ (date.second or 0)
		return secondsSinceStart
	else
		return DateTimeUtility.toTimestamp(self.utcDate)
	end
end

---Create a DateTimeModel from a timestamp
---@param timestamp number The timestamp
---@param timezoneOffset number? Optional timezone offset
---@param useGameTime boolean? Whether this is a game time timestamp
---@return DateTimeModel dateTimeModel New DateTimeModel instance
function DateTimeModel.fromTimestamp(timestamp, timezoneOffset, useGameTime)
	if useGameTime then
		local totalSeconds = timestamp
		local totalMinutes = math.floor(totalSeconds / 60)
		local seconds = totalSeconds % 60

		local minutes = totalMinutes % 60
		local totalHours = math.floor(totalMinutes / 60)

		local hours = totalHours % 24
		local totalDays = math.floor(totalHours / 24)

		local days = (totalDays % 30) + 1
		local totalMonths = math.floor(totalDays / 30)

		local months = (totalMonths % 12) + 1
		local years = math.floor(totalMonths / 12)

		return DateTimeModel:new({
			date = {
				year = years,
				month = months,
				day = days,
				hour = hours,
				min = minutes,
				second = seconds,
			},
			useGameTime = true,
		})
	else
		local utcDate = DateTimeUtility.fromTimestamp(timestamp, true)
		return DateTimeModel:new({
			date = utcDate,
			timezone = timezoneOffset,
		})
	end
end

---Parse a date string into a DateTimeModel
---@param dateStr string The date string
---@param format string|DateFormat The format of the date string
---@param timezoneOffset number? Optional timezone offset of the input string
---@return DateTimeModel|nil dateTimeModel New DateTimeModel instance or nil if parsing failed
function DateTimeModel.parseDate(dateStr, format, timezoneOffset)
	local dateTable = DateTimeUtility.parseDate(dateStr, format)

	if not dateTable then
		return nil
	end

	return DateTimeModel:new({
		date = dateTable,
		timezone = timezoneOffset,
		format = format,
	})
end

---Check if this date is equal to another date
---@param other DateTimeModel The other date to compare to
---@return boolean equals True if dates are equal
function DateTimeModel:equals(other)
	if not other or not other.utcDate then
		return false
	end

	return self:toTimestamp() == other:toTimestamp()
end

---Check if this date is before another date
---@param other DateTimeModel The other date to compare to
---@return boolean isBefore True if this date is before the other
function DateTimeModel:isBefore(other)
	if not other or not other.utcDate then
		return false
	end

	return self:toTimestamp() < other:toTimestamp()
end

---Check if this date is after another date
---@param other DateTimeModel The other date to compare to
---@return boolean isAfter True if this date is after the other
function DateTimeModel:isAfter(other)
	if not other or not other.utcDate then
		return false
	end

	return self:toTimestamp() > other:toTimestamp()
end

---Check if this date is between two other dates
---@param start DateTimeModel The start date
---@param endDate DateTimeModel The end date
---@return boolean isBetween True if this date is between start and end
function DateTimeModel:isBetween(start, endDate)
	if not start or not endDate then
		return false
	end

	local timestamp = self:toTimestamp()
	local startTimestamp = start:toTimestamp()
	local endTimestamp = endDate:toTimestamp()

	return timestamp >= startTimestamp and timestamp <= endTimestamp
end

---Create a copy of this DateTimeModel
---@return DateTimeModel New DateTimeModel instance
function DateTimeModel:clone()
	return DateTimeModel:new({
		date = self:getUTCDate(),
		timezone = self.timezoneOffset,
		format = self.displayFormat,
	})
end

---@return table serializedData Serialized representation
function DateTimeModel:serialize()
	return {
		timestamp = self:toTimestamp(),
		timezone = self.timezoneOffset,
		format = self.displayFormat,
	}
end

---@param data table The serialized data (requires timestamp field)
---@return DateTimeModel dateTimeModel New DateTimeModel instance
function DateTimeModel.deserialize(data)
	if not data or not data.timestamp then
		return DateTimeModel:new()
	end

	local model = DateTimeModel.fromTimestamp(data.timestamp)

	if data.timezone then
		model:setTimezoneOffset(data.timezone)
	end

	if data.format then
		model:setDisplayFormat(data.format)
	end

	return model
end

return DateTimeModel
