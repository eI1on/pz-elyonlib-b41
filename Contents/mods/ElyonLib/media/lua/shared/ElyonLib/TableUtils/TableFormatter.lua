---@class TableFormatter
local TableFormatter = {};

---@param tbl table The table to format
---@param indent number|nil The current indentation level
---@param seen table|nil A table used to track circular references
---@return string formattedTable
function TableFormatter.format(tbl, indent, seen)
    indent = indent or 0;
    seen = seen or {};
    local spacing = string.rep("  ", indent);
    local result = {};

    if seen[tbl] then
        return spacing .. "<Circular Reference>";
    end
    seen[tbl] = true;

    if type(tbl) ~= "table" then
        return spacing .. tostring(tbl);
    end

    table.insert(result, spacing .. "{");
    for k, v in pairs(tbl) do
        local key = (type(k) == "string") and ('"' .. k .. '"') or tostring(k);
        if type(v) == "table" then
            table.insert(result, spacing .. "  [" .. key .. "] =");
            table.insert(result, TableFormatter.format(v, indent + 1, seen));
        else
            local value = (type(v) == "string") and ('"' .. v .. '"') or tostring(v);
            table.insert(result, spacing .. "  [" .. key .. "] = " .. value);
        end
    end
    table.insert(result, spacing .. "}");
    seen[tbl] = nil;

    return table.concat(result, "\n");
end

return TableFormatter;
