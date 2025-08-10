local getTimeInMillis = getTimeInMillis

local Timer = {}
Timer.__index = Timer

local timers = {}
local timerIdCounter = 0

function Timer:new(callback, interval, loop)
	local newTimer = {
		id = timerIdCounter + 1,
		callback = callback,
		interval = interval,
		nextTrigger = getTimeInMillis() + interval,
		loop = loop or false,
	}
	timerIdCounter = timerIdCounter + 1
	setmetatable(newTimer, Timer)
	return newTimer
end

local TimerManager = {}

---@param callback function The function to call
---@param interval number The interval in milliseconds
---@param loop boolean Whether the timer should loop
---@return number id The timer ID
function TimerManager:add(callback, interval, loop)
	local timer = Timer:new(callback, interval, loop)
	timers[timer.id] = timer
	return timer.id
end

---@param callback function The function to call
---@param seconds number The interval in seconds
---@param loop boolean Whether the timer should loop
---@return number id The timer ID
function TimerManager:addSeconds(callback, seconds, loop)
	return self:add(callback, seconds * 1000, loop)
end

---@param callback function The function to call
---@param minutes number The interval in minutes
---@param loop boolean Whether the timer should loop
---@return number id The timer ID
function TimerManager:addMinutes(callback, minutes, loop)
	return self:add(callback, minutes * 60 * 1000, loop)
end

---@param id number The ID of the timer to remove
function TimerManager:remove(id)
	timers[id] = nil
end

function TimerManager:update()
	local currentTime = getTimeInMillis()
	for id, timer in pairs(timers) do
		if currentTime >= timer.nextTrigger then
			local success, err = pcall(timer.callback)
			if timer.loop then
				timer.nextTrigger = timer.nextTrigger + timer.interval
				while currentTime >= timer.nextTrigger do
					timer.nextTrigger = timer.nextTrigger + timer.interval
				end
			else
				timers[id] = nil
			end
		end
	end
end

if isServer() then
	Events.EveryOneMinute.Add(function()
		TimerManager:update()
	end)
else
	Events.OnTick.Add(function()
		TimerManager:update()
	end)
end

return TimerManager
