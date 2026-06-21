local TableUtils = {}

---Deep copy a table with all its values
---@param original table Table to copy
---@return table copy Deep copy of the original table
function TableUtils.deepCopy(original)
	local function copyValue(value, seen)
		if type(value) ~= "table" then
			return value
		end

		if seen[value] then
			return seen[value]
		end

		local copy = {}
		seen[value] = copy
		for k, v in pairs(value) do
			copy[copyValue(k, seen)] = copyValue(v, seen)
		end
		setmetatable(copy, copyValue(getmetatable(value), seen))
		return copy
	end

	return copyValue(original, {})
end

---Shallow copy a table (only copies immediate values)
---@param original table Table to copy
---@return table copy Shallow copy of the original table
function TableUtils.shallowCopy(original)
	if type(original) ~= "table" then
		return original
	end

	local copy = {}
	for k, v in pairs(original) do
		copy[k] = v
	end
	return copy
end

---Check if a table contains a value
---@param tbl table Table to search
---@param value any Value to find
---@return boolean found True if value is found
function TableUtils.contains(tbl, value)
	for _, v in pairs(tbl) do
		if v == value then
			return true
		end
	end
	return false
end

---Check whether an array contains a value using its contiguous numeric indices.
---@param list table|nil
---@param value any
---@return boolean found
function TableUtils.arrayContains(list, value)
	if type(list) ~= "table" then
		return false
	end

	for i = 1, #list do
		if list[i] == value then
			return true
		end
	end

	return false
end

---Insert a value into an array only when it is not already present.
---@param list table|nil
---@param value any
---@return boolean inserted
function TableUtils.insertUnique(list, value)
	if type(list) ~= "table" or value == nil or TableUtils.arrayContains(list, value) then
		return false
	end

	list[#list + 1] = value
	return true
end

---Remove the last matching value from an array.
---@param list table|nil
---@param value any
---@return boolean removed
function TableUtils.removeValue(list, value)
	if type(list) ~= "table" then
		return false
	end

	for i = #list, 1, -1 do
		if list[i] == value then
			table.remove(list, i)
			return true
		end
	end

	return false
end

---Copy the contiguous numeric values from an array.
---@param list table|nil
---@return table copy
function TableUtils.copyArray(list)
	local result = {}
	if type(list) ~= "table" then
		return result
	end

	for i = 1, #list do
		result[#result + 1] = list[i]
	end
	return result
end

---Create a set from the non-nil values in an array.
---@param list table|nil
---@return table set
function TableUtils.arrayToSet(list)
	local result = {}
	if type(list) ~= "table" then
		return result
	end

	for i = 1, #list do
		local value = list[i]
		if value ~= nil then
			result[value] = true
		end
	end
	return result
end

---Copy only truthy entries from a keyed set.
---@param source table|nil
---@return table set
function TableUtils.copyTruthySet(source)
	local result = {}
	if type(source) ~= "table" then
		return result
	end

	for key, value in pairs(source) do
		if value then
			result[key] = true
		end
	end
	return result
end

---Count truthy values in a keyed table.
---@param source table|nil
---@return integer count
function TableUtils.countTruthy(source)
	local count = 0
	if type(source) ~= "table" then
		return count
	end

	for _, value in pairs(source) do
		if value then
			count = count + 1
		end
	end
	return count
end

---Merge two tables into a new table
---@param t1 table First table
---@param t2 table Second table
---@return table merged Merged table
function TableUtils.merge(t1, t2)
	local result = TableUtils.shallowCopy(t1)
	for k, v in pairs(t2) do
		result[k] = v
	end
	return result
end

return TableUtils
