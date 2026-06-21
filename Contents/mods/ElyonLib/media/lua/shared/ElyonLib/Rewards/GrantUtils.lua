local Globals = require("ElyonLib/Core/Globals")
local PerkUtils = require("ElyonLib/PlayerUtils/PerkUtils")
local TraitUtils = require("ElyonLib/PlayerUtils/TraitUtils")

local GrantUtils = {}

--- Resolves a perk name string to the Perk enum value used by PZ.
--- Tries direct table lookup first, then Perks.FromString, then a
--- case-insensitive scan of all known perks.
---@param perkName string
---@return any|nil perk  The Perks enum value, or nil if not found
function GrantUtils.findPerk(perkName)
	return PerkUtils.resolve(perkName)
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

	local displayName = PerkUtils.getDisplayName(perkName)
	summaries[#summaries + 1] = string.format("%s XP +%s", displayName, tostring(amount))
end

---@param player IsoPlayer
---@param traitType string
---@param summaries string[]
---@param errors string[]
function GrantUtils.grantTrait(player, traitType, summaries, errors)
	if not player or not player.getTraits then
		errors[#errors + 1] = "Player traits unavailable"
		return
	end

	local traitInfo = TraitUtils.getInfo(traitType)
	if not traitInfo then
		errors[#errors + 1] = "Invalid trait reward " .. tostring(traitType)
		return
	end

	local traits = player:getTraits()
	local conflicts = TraitUtils.getConflictTypes(traitInfo.type)
	for i = 1, #conflicts do
		local conflictType = conflicts[i]
		if traits:contains(conflictType) then
			local conflictInfo = TraitUtils.getInfo(conflictType)
			errors[#errors + 1] = string.format(
				"%s conflicts with %s",
				traitInfo.label,
				conflictInfo and conflictInfo.label or conflictType
			)
			return
		end
	end

	if traits:contains(traitInfo.type) then
		summaries[#summaries + 1] = string.format("Trait %s (already had it)", traitInfo.label)
		return
	end

	traits:add(traitInfo.type)
	if player.resetModelNextFrame then
		player:resetModelNextFrame()
	end
	summaries[#summaries + 1] = string.format("Trait %s", traitInfo.label)
end

return GrantUtils
