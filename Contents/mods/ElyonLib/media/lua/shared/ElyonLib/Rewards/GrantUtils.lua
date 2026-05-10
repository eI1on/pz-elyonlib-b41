local Globals = require("ElyonLib/Core/Globals")

local GrantUtils = {}

--- Resolves a perk name string to the Perk enum value used by PZ.
--- Tries direct table lookup first, then Perks.FromString, then a
--- case-insensitive scan of all known perks.
---@param perkName string
---@return any|nil perk  The Perks enum value, or nil if not found
function GrantUtils.findPerk(perkName)
	perkName = tostring(perkName or "")
	if perkName == "" then
		return nil
	end

	if Perks and Perks[perkName] then
		return Perks[perkName]
	end

	if Perks and Perks.FromString then
		local perk = Perks.FromString(perkName)
		if perk and PerkFactory and PerkFactory.getPerk(perk) then
			return perk
		end
	end

	return nil
end

--- Grants one or more items of the given full type to the player's inventory.
--- In a dedicated-server context uses sendObjectChange for network-safe delivery.
--- Appends a summary string to `summaries` on success, or an error to `errors`.
---@param player IsoPlayer
---@param itemType string   Full type, e.g. "Base.WaterBottleFull"
---@param count integer
---@param summaries string[]
---@param errors string[]
function GrantUtils.grantItem(player, itemType, count, summaries, errors)
	if not player or not player.getInventory then
		errors[#errors + 1] = "Player inventory unavailable"
		return
	end

	itemType = tostring(itemType or "")
	count = math.floor(tonumber(count) or 1)

	if itemType == "" or count <= 0 then
		errors[#errors + 1] = "Invalid item reward (type='" .. itemType .. "' count=" .. tostring(count) .. ")"
		return
	end

	local scriptItem = ScriptManager and ScriptManager.instance and ScriptManager.instance:getItem(itemType) or nil
	if not scriptItem then
		errors[#errors + 1] = "Missing item " .. itemType
		return
	end

	if Globals.isServer then
		player:sendObjectChange("addItemOfType", { type = itemType, count = count })
	else
		for i = 1, count do
			player:getInventory():AddItem(itemType)
		end
	end

	summaries[#summaries + 1] = string.format("%dx %s", count, scriptItem:getDisplayName())
end

--- Grants XP to the player for the named perk.
--- Appends a summary string to `summaries` on success, or an error to `errors`.
---@param player IsoPlayer
---@param perkName string   Perk name as used by Perks table, e.g. "Cooking"
---@param amount number     XP amount (positive to add, negative to remove)
---@param summaries string[]
---@param errors string[]
function GrantUtils.grantXp(player, perkName, amount, summaries, errors)
	if not player or not player.getXp then
		errors[#errors + 1] = "Player XP unavailable"
		return
	end

	local perk = GrantUtils.findPerk(perkName)
	amount = tonumber(amount) or 0

	if not perk or amount == 0 then
		errors[#errors + 1] = "Invalid XP reward (perk='" .. tostring(perkName) .. "')"
		return
	end

	player:getXp():AddXP(perk, amount)

	local perkInfo = PerkFactory and PerkFactory.getPerk(perk) or nil
	local displayName = perkInfo and perkInfo:getName() or tostring(perkName)
	summaries[#summaries + 1] = string.format("%s XP +%s", displayName, tostring(amount))
end

return GrantUtils
