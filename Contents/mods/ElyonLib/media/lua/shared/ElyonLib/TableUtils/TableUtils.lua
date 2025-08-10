local TableUtils = {}

---Deep copy a table with all its values
---@param original table Table to copy
---@return table copy Deep copy of the original table
function TableUtils.deepCopy(original)
    local copy
    if type(original) == 'table' then
        copy = {}
        for k, v in pairs(original) do
            copy[TableUtils.deepCopy(k)] = TableUtils.deepCopy(v)
        end
        setmetatable(copy, TableUtils.deepCopy(getmetatable(original)))
    else -- primitive types
        copy = original
    end
    return copy
end

---Shallow copy a table (only copies immediate values)
---@param original table Table to copy
---@return table copy Shallow copy of the original table
function TableUtils.shallowCopy(original)
    if type(original) ~= 'table' then return original end

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