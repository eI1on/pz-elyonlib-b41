---@class DateTable
---@field year number The year component
---@field month number The month component (1-12)
---@field day number The day component (1-31)
---@field hour number The hour component (0-23)
---@field min number The minute component (0-59)
---@field second number|nil The second component (0-59), may be nil
---@field sec number|nil Alternative field for seconds, may be nil
---@field isdst boolean|nil Daylight saving time flag, may be nil

local DateTimeUtility = {}

DateTimeUtility.CALENDAR = {
	YEAR = 1,
	MONTH = 2,
	DAY_OF_MONTH = 5,
	HOUR_OF_DAY = 11,
	MINUTE = 12,
	SECOND = 13,
	MILLISECOND = 14,

	ZONE_OFFSET = 15,
	DST_OFFSET = 16,
}

DateTimeUtility.FORMAT = {
	ISO = "ISO", -- 1970-12-31T14:30:00Z (ISO 8601)
	US = "US", -- 12/31/1970 2:30 PM
	EU = "EU", -- 31/12/1970 14:30
	CUSTOM = "CUSTOM",
}

DateTimeUtility.FORMAT_STRINGS = {
	[DateTimeUtility.FORMAT.ISO] = "%Y-%m-%dT%H:%M:%SZ",
	[DateTimeUtility.FORMAT.US] = "%m/%d/%Y %I:%M %p",
	[DateTimeUtility.FORMAT.EU] = "%d/%m/%Y %H:%M",
}

-- Month names and short names
---@type string[]
DateTimeUtility.MONTHS = {
	"January",
	"February",
	"March",
	"April",
	"May",
	"June",
	"July",
	"August",
	"September",
	"October",
	"November",
	"December",
}

---@type string[]
DateTimeUtility.SHORT_MONTHS = { "Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec" }

---@type integer[]
DateTimeUtility.DAYS_IN_MONTH = { 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 }

---@type string[]
DateTimeUtility.DAYS_OF_WEEK_SUNDAY_FIRST = { "Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat" }

---@type string[]
DateTimeUtility.DAYS_OF_WEEK_MONDAY_FIRST = { "Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun" }

local pzCalendarInstance = nil

--- Get the PZCalendar instance (cached)
---@return PZCalendar pzCalendar
function DateTimeUtility.getPZCalendarInstance()
	-- if not pzCalendarInstance then
	-- 	pzCalendarInstance = PZCalendar.getInstance()
	-- end
	return PZCalendar.getInstance() -- pzCalendarInstance
end

--- Get the local timezone offset in seconds
---@return number offset The timezone offset in seconds
function DateTimeUtility.getLocalTimezoneOffset()
	local pzCalendar = DateTimeUtility.getPZCalendarInstance()

	local zoneOffsetMs = pzCalendar:get(DateTimeUtility.CALENDAR.ZONE_OFFSET)
	local dstOffsetMs = pzCalendar:get(DateTimeUtility.CALENDAR.DST_OFFSET)

	return (zoneOffsetMs + dstOffsetMs) / 1000
end

--- Convert a date table from one timezone to another
---@param dateTable DateTable Table with year, month, day, hour, min, second
---@param fromOffset number? Source timezone offset in seconds (or nil for UTC)
---@param toOffset number? Target timezone offset in seconds (or nil for UTC)
---@return DateTable convertedDate New date table in target timezone
function DateTimeUtility.convertTimezone(dateTable, fromOffset, toOffset)
	fromOffset = fromOffset or 0
	toOffset = toOffset or 0

	local sourceTime = os.time({
		year = dateTable.year or 1970,
		month = dateTable.month or 1,
		day = dateTable.day or 1,
		hour = dateTable.hour or 0,
		min = dateTable.min or 0,
		sec = dateTable.second or dateTable.sec or 0,
		isdst = false,
	})

	local targetTime = sourceTime - fromOffset + toOffset

	return os.date("*t", targetTime) --[[@as DateTable]]
end

--- Convert a date table to UTC
---@param dateTable DateTable Date table in local timezone
---@param timezoneOffset number? The timezone offset in seconds
---@return DateTable utcDate Date table in UTC
function DateTimeUtility.toUTC(dateTable, timezoneOffset)
	return DateTimeUtility.convertTimezone(dateTable, timezoneOffset, 0)
end

--- Convert a UTC date table to local timezone
---@param utcDateTable DateTable Date table in UTC
---@return DateTable localDate Date table in local timezone
function DateTimeUtility.toLocalTime(utcDateTable)
	local offset = DateTimeUtility.getLocalTimezoneOffset()
	return DateTimeUtility.convertTimezone(utcDateTable, 0, offset)
end

--- Format a date table using a specified format
---@param dateTable DateTable Table with year, month, day, hour, min, second
---@param format string|DateFormat One of DateTimeUtility.FORMAT constants or a custom format string
---@return string formattedDate Formatted date string
function DateTimeUtility.formatDate(dateTable, format)
	if not dateTable then
		return "Invalid Date"
	end

	local formatString = DateTimeUtility.FORMAT_STRINGS[format] or format

	local timestamp = os.time({
		year = dateTable.year or 1970,
		month = dateTable.month or 1,
		day = dateTable.day or 1,
		hour = dateTable.hour or 0,
		min = dateTable.min or 0,
		sec = dateTable.second or dateTable.sec or 0,
		isdst = false,
	})

	return os.date(formatString, timestamp) --[[@as string]]
end

--- Parse a date string into a date table
---@param dateStr string The date string to parse
---@param format string|DateFormat The format the string is in
---@return DateTable|nil dateTable Date table with year, month, day, hour, min, second, or nil if parsing failed
function DateTimeUtility.parseDate(dateStr, format)
	if not dateStr or dateStr == "" then
		return nil
	end

	local formatString = DateTimeUtility.FORMAT_STRINGS[format] or format

	if
		format == DateTimeUtility.FORMAT.ISO
		or formatString == DateTimeUtility.FORMAT_STRINGS[DateTimeUtility.FORMAT.ISO]
	then
		-- ISO format: 1970-12-31T14:30:00Z
		local year, month, day, hour, min, sec = dateStr:match("(%d%d%d%d)-(%d%d)-(%d%d)T(%d%d):(%d%d):(%d%d)Z")
		if year then
			return {
				year = tonumber(year),
				month = tonumber(month),
				day = tonumber(day),
				hour = tonumber(hour),
				min = tonumber(min),
				second = tonumber(sec),
			}
		end
	elseif
		format == DateTimeUtility.FORMAT.US
		or formatString == DateTimeUtility.FORMAT_STRINGS[DateTimeUtility.FORMAT.US]
	then
		-- US format: 12/31/1970 2:30 PM
		local month, day, year, hour, min, ampm = dateStr:match("(%d+)/(%d+)/(%d+)%s+(%d+):(%d+)%s+(%w+)")
		if year then
			hour = tonumber(hour)
			if ampm:upper() == "PM" and hour < 12 then
				hour = hour + 12
			elseif ampm:upper() == "AM" and hour == 12 then
				hour = 0
			end

			return {
				year = tonumber(year),
				month = tonumber(month),
				day = tonumber(day),
				hour = hour,
				min = tonumber(min),
				second = 0,
			}
		end
	elseif
		format == DateTimeUtility.FORMAT.EU
		or formatString == DateTimeUtility.FORMAT_STRINGS[DateTimeUtility.FORMAT.EU]
	then
		-- EU format: 31/12/1970 14:30
		local day, month, year, hour, min = dateStr:match("(%d+)/(%d+)/(%d+)%s+(%d+):(%d+)")
		if year then
			return {
				year = tonumber(year),
				month = tonumber(month),
				day = tonumber(day),
				hour = tonumber(hour),
				min = tonumber(min),
				second = 0,
			}
		end
	end

	return nil
end

--- Check if a year is a leap year
---@param year number The year to check
---@return boolean isLeapYear True if the year is a leap year
function DateTimeUtility.isLeapYear(year)
	return (year % 4 == 0 and year % 100 ~= 0) or (year % 400 == 0)
end

--- Get the number of days in a month, accounting for leap years
---@param month number The month (1-12)
---@param year number The year
---@return number daysInMonth The number of days in the month
function DateTimeUtility.getDaysInMonth(month, year)
	if month == 2 and DateTimeUtility.isLeapYear(year) then
		return 29
	end
	return DateTimeUtility.DAYS_IN_MONTH[month]
end

--- Get the day of the week for the first day of a month (1-7, where 1 is Sunday)
---@param year number The year
---@param month number The month (1-12)
---@return number dayOfWeek The day of the week (1-7, where 1 is Sunday)
function DateTimeUtility.getFirstDayOfMonth(year, month)
	local t = {
		year = year,
		month = month,
		day = 1,
		hour = 12,
		min = 0,
		sec = 0,
	}

	local timestamp = os.time(t)
	return tonumber(os.date("%w", timestamp)) + 1 -- +1 because Lua's os.date returns 0-6. See: https://www.tutorialspoint.com/c_standard_library/c_function_strftime.htm
end

--- Create a UTC date table from individual components
---@param year number? Year (defaults to current year)
---@param month number? Month (defaults to 1)
---@param day number? Day (defaults to 1)
---@param hour number? Hour (defaults to 0)
---@param min number? Minute (defaults to 0)
---@param sec number? Second (defaults to 0)
---@return DateTable dateTable The created date table
function DateTimeUtility.createUTCDate(year, month, day, hour, min, sec)
	return {
		year = year or 1970,
		month = month or 1,
		day = day or 1,
		hour = hour or 0,
		min = min or 0,
		second = sec or 0,
	}
end

--- Get the current date in local timezone
---@return DateTable currentDate The current local date
function DateTimeUtility.getCurrentLocalDate()
	local pzCalendar = DateTimeUtility.getPZCalendarInstance()
	return {
		year = pzCalendar:get(DateTimeUtility.CALENDAR.YEAR),
		month = pzCalendar:get(DateTimeUtility.CALENDAR.MONTH) + 1, -- Calendar months are 0-based
		day = pzCalendar:get(DateTimeUtility.CALENDAR.DAY_OF_MONTH),
		hour = pzCalendar:get(DateTimeUtility.CALENDAR.HOUR_OF_DAY),
		min = pzCalendar:get(DateTimeUtility.CALENDAR.MINUTE),
		second = pzCalendar:get(DateTimeUtility.CALENDAR.SECOND),
	}
end

--- Get the current date in UTC
---@return DateTable currentDate The current UTC date
function DateTimeUtility.getCurrentUTCDate()
	return DateTimeUtility.toUTC(DateTimeUtility.getCurrentLocalDate(), DateTimeUtility.getLocalTimezoneOffset())
end

--- Get the current game time as a DateTable
---@return DateTable currentGameDate The current game time
function DateTimeUtility.getCurrentGameDate()
	local gameTime = getGameTime()

	return {
		year = gameTime:getYear(),
		month = gameTime:getMonth() + 1, -- PZ months are 0-based
		day = gameTime:getDay() + 1, -- PZ days are 0-based
		hour = gameTime:getHour(),
		min = gameTime:getMinutes(),
		second = 0,
	}
end

--- Convert a date table to a timestamp
---@param dateTable DateTable Table with year, month, day, hour, min, second/sec
---@return number|nil timestamp Timestamp in seconds since epoch, or nil if conversion failed
function DateTimeUtility.toTimestamp(dateTable)
	if not dateTable then
		return nil
	end

	return os.time({
		year = dateTable.year or 1970,
		month = dateTable.month or 1,
		day = dateTable.day or 1,
		hour = dateTable.hour or 0,
		min = dateTable.min or 0,
		sec = dateTable.second or dateTable.sec or 0,
		isdst = false,
	})
end

--- Convert a timestamp to a date table
---@param timestamp number The timestamp in seconds since epoch
---@param useUTC boolean? Whether to return the date in UTC (true) or local time (false)
---@return DateTable|nil dateTable The date table, or nil if conversion failed
function DateTimeUtility.fromTimestamp(timestamp, useUTC)
	if not timestamp then
		return nil
	end

	if useUTC then
		return DateTimeUtility.toUTC(
			os.date("*t", timestamp) --[[@as DateTable]],
			DateTimeUtility.getLocalTimezoneOffset()
		)
	else
		return os.date("*t", timestamp) --[[@as DateTable]]
	end
end

--- Validate a date table
---@param dateTable DateTable The date table to validate
---@return boolean isValid True if the date is valid
function DateTimeUtility.isValidDate(dateTable)
	if not dateTable then
		return false
	end

	if not dateTable.year or dateTable.year < 1971 or dateTable.year > 2037 then
		return false
	end

	if not dateTable.month or dateTable.month < 1 or dateTable.month > 12 then
		return false
	end

	local daysInMonth = DateTimeUtility.getDaysInMonth(dateTable.month, dateTable.year)
	if not dateTable.day or dateTable.day < 1 or dateTable.day > daysInMonth then
		return false
	end

	if dateTable.hour and (dateTable.hour < 0 or dateTable.hour > 23) then
		return false
	end

	if dateTable.min and (dateTable.min < 0 or dateTable.min > 59) then
		return false
	end

	local sec = dateTable.second or dateTable.sec
	if sec and (sec < 0 or sec > 59) then
		return false
	end

	return true
end

--- Compare two date tables
---@param dateTable1 DateTable The first date to compare
---@param dateTable2 DateTable The second date to compare
---@return number comparison -1 if date1 < date2, 0 if equal, 1 if date1 > date2
function DateTimeUtility.compareDates(dateTable1, dateTable2)
	if not dateTable1 and not dateTable2 then
		return 0
	end
	if not dateTable1 then
		return -1
	end
	if not dateTable2 then
		return 1
	end

	local timestamp1 = DateTimeUtility.toTimestamp(dateTable1)
	local timestamp2 = DateTimeUtility.toTimestamp(dateTable2)

	if not timestamp1 and not timestamp2 then
		return 0
	end
	if not timestamp1 then
		return -1
	end
	if not timestamp2 then
		return 1
	end

	if timestamp1 < timestamp2 then
		return -1
	elseif timestamp1 > timestamp2 then
		return 1
	else
		return 0
	end
end

--- Check if the first date is before the second date
---@param dateTable1 DateTable The first date
---@param dateTable2 DateTable The second date
---@return boolean isBefore True if dateTable1 is before dateTable2
function DateTimeUtility.isDateBefore(dateTable1, dateTable2)
	return DateTimeUtility.compareDates(dateTable1, dateTable2) < 0
end

--- Check if the first date is after the second date
---@param dateTable1 DateTable The first date
---@param dateTable2 DateTable The second date
---@return boolean isAfter True if dateTable1 is after dateTable2
function DateTimeUtility.isDateAfter(dateTable1, dateTable2)
	return DateTimeUtility.compareDates(dateTable1, dateTable2) > 0
end

--- Check if two dates are equal
---@param dateTable1 DateTable The first date
---@param dateTable2 DateTable The second date
---@return boolean isEqual True if the dates are equal
function DateTimeUtility.isDateEqual(dateTable1, dateTable2)
	return DateTimeUtility.compareDates(dateTable1, dateTable2) == 0
end

--- Check if the first date is before or equal to the second date
---@param dateTable1 DateTable The first date
---@param dateTable2 DateTable The second date
---@return boolean isBeforeOrEqual True if dateTable1 is before or equal to dateTable2
function DateTimeUtility.isDateBeforeOrEqual(dateTable1, dateTable2)
	return DateTimeUtility.compareDates(dateTable1, dateTable2) <= 0
end

--- Check if the first date is after or equal to the second date
---@param dateTable1 DateTable The first date
---@param dateTable2 DateTable The second date
---@return boolean isAfterOrEqual True if dateTable1 is after or equal to dateTable2
function DateTimeUtility.isDateAfterOrEqual(dateTable1, dateTable2)
	return DateTimeUtility.compareDates(dateTable1, dateTable2) >= 0
end

--- Compare two timestamps
---@param timestamp1 number? The first timestamp
---@param timestamp2 number? The second timestamp
---@return number comparison -1 if timestamp1 < timestamp2, 0 if equal, 1 if timestamp1 > timestamp2
function DateTimeUtility.compareTimestamps(timestamp1, timestamp2)
	if not timestamp1 and not timestamp2 then
		return 0
	end
	if not timestamp1 then
		return -1
	end
	if not timestamp2 then
		return 1
	end

	if timestamp1 < timestamp2 then
		return -1
	elseif timestamp1 > timestamp2 then
		return 1
	else
		return 0
	end
end

--- Check if the first timestamp is before the second timestamp
---@param timestamp1 number? The first timestamp
---@param timestamp2 number? The second timestamp
---@return boolean isBefore True if timestamp1 is before timestamp2
function DateTimeUtility.isTimestampBefore(timestamp1, timestamp2)
	return DateTimeUtility.compareTimestamps(timestamp1, timestamp2) < 0
end

--- Check if the first timestamp is after the second timestamp
---@param timestamp1 number? The first timestamp
---@param timestamp2 number? The second timestamp
---@return boolean isAfter True if timestamp1 is after timestamp2
function DateTimeUtility.isTimestampAfter(timestamp1, timestamp2)
	return DateTimeUtility.compareTimestamps(timestamp1, timestamp2) > 0
end

--- Get timezone abbreviation (e.g., "EST", "PDT")
---@return string|osdate tzAbbr The timezone abbreviation or offset string
function DateTimeUtility.getTimezoneAbbr()
	local tzAbbr = os.date("%Z") -- might not work on all systems implementations

	-- fallback if %Z doesn't work
	if not tzAbbr or tzAbbr == "" or tzAbbr == "UTC" or tzAbbr == "%Z" then
		local offset = DateTimeUtility.getLocalTimezoneOffset()
		local hours = math.floor(math.abs(offset) / 3600)
		return string.format("%s%s%02d", tzAbbr == "UTC" and "UTC" or "", offset >= 0 and "+" or "-", hours)
	end

	return tzAbbr
end

--- Calculate the difference between two date tables in days
---@param dateTable1 DateTable The first date
---@param dateTable2 DateTable The second date
---@return number daysDiff The number of days between the dates
function DateTimeUtility.daysDifference(dateTable1, dateTable2)
	local timestamp1 = DateTimeUtility.toTimestamp(dateTable1)
	local timestamp2 = DateTimeUtility.toTimestamp(dateTable2)

	return math.floor((timestamp2 - timestamp1) / (24 * 60 * 60))
end

--- Format a date for display in a short format (e.g., "1970-12-31")
---@param dateTable DateTable The date to format
---@return string|osdate formattedDate The formatted date string
function DateTimeUtility.formatShortDate(dateTable)
	return DateTimeUtility.formatDate(dateTable, "%Y-%m-%d")
end

--- Format a time for display (e.g., "14:30" or "2:30 PM")
---@param dateTable DateTable The date containing the time to format
---@param use24Hour boolean Whether to use 24-hour format (true) or 12-hour format (false)
---@return string|osdate formattedTime The formatted time string
function DateTimeUtility.formatTime(dateTable, use24Hour)
	if use24Hour then
		return DateTimeUtility.formatDate(dateTable, "%H:%M")
	else
		return DateTimeUtility.formatDate(dateTable, "%I:%M %p")
	end
end

--- Format a datetime for display with timezone info
---@param dateTable DateTable The date to format
---@param format string|DateFormat? The format to use (defaults to ISO)
---@return string formattedDateTime The formatted date-time string with timezone
function DateTimeUtility.formatDateTimeWithTZ(dateTable, format)
	local formatted = DateTimeUtility.formatDate(dateTable, format or DateTimeUtility.FORMAT.ISO)
	local tzAbbr = DateTimeUtility.getTimezoneAbbr()

	return formatted .. " " .. tzAbbr
end

return DateTimeUtility
