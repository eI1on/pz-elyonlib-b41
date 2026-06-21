local Globals = require("ElyonLib/Core/Globals")
local TextUtils = require("ElyonLib/TextUtils/TextUtils")

local TraitUtils = {}

local textureCache = {}
local listCache = nil
local optionsCache = nil

function TraitUtils.has(player, traitType)
	traitType = TextUtils.trim(traitType)
	return player ~= nil
		and traitType ~= ""
		and player.getTraits ~= nil
		and player:getTraits() ~= nil
		and player:getTraits():contains(traitType)
end

function TraitUtils.syncPlayer(player)
	if player and SyncXp then
		SyncXp(player)
	end
end

function TraitUtils.add(player, traitType, sync)
	traitType = TextUtils.trim(traitType)
	if not player or traitType == "" or TraitUtils.has(player, traitType) then
		return false
	end

	player:getTraits():add(traitType)
	if sync ~= false then
		TraitUtils.syncPlayer(player)
	end
	return true
end

function TraitUtils.remove(player, traitType, sync)
	traitType = TextUtils.trim(traitType)
	if not player or traitType == "" or not TraitUtils.has(player, traitType) then
		return false
	end

	player:getTraits():remove(traitType)
	if sync ~= false then
		TraitUtils.syncPlayer(player)
	end
	return true
end

function TraitUtils.getInfo(traitType)
	traitType = TextUtils.trim(traitType)
	if traitType == "" or not TraitFactory or not TraitFactory.getTrait then
		return nil
	end

	local trait = TraitFactory.getTrait(traitType)
	if not trait then
		return nil
	end

	local cost = trait.getCost and (trait:getCost() or 0) or 0
	return {
		type = tostring(trait:getType() or traitType),
		label = tostring(trait:getLabel() or traitType),
		description = tostring(trait:getDescription() or ""),
		cost = cost,
		positive = cost >= 0,
	}
end

function TraitUtils.getConflictTypes(traitType)
	local trait = TraitFactory and TraitFactory.getTrait and TraitFactory.getTrait(TextUtils.trim(traitType)) or nil
	local result = {}
	if not trait or not trait.getMutuallyExclusiveTraits then
		return result
	end

	local conflicts = trait:getMutuallyExclusiveTraits()
	if not conflicts then
		return result
	end

	for index = 0, conflicts:size() - 1 do
		local conflictType = TextUtils.trim(conflicts:get(index))
		if conflictType ~= "" then
			result[#result + 1] = conflictType
		end
	end
	table.sort(result)
	return result
end

function TraitUtils.getList()
	if listCache then
		return listCache
	end

	local result = {}
	local traits = TraitFactory and TraitFactory.getTraits and TraitFactory.getTraits() or nil
	if not traits then
		return result
	end

	for index = 0, traits:size() - 1 do
		local trait = traits:get(index)
		local traitType = trait and TextUtils.trim(trait:getType()) or ""
		local removedInMultiplayer = trait and trait.isRemoveInMP and trait:isRemoveInMP() or false
		if trait and traitType ~= "" and (not removedInMultiplayer or not Globals.isClient) then
			local info = TraitUtils.getInfo(traitType)
			if info then
				result[#result + 1] = info
			end
		end
	end

	table.sort(result, function(a, b)
		if a.positive ~= b.positive then
			return a.positive and not b.positive
		end
		return tostring(a.label):lower() < tostring(b.label):lower()
	end)
	listCache = result
	return result
end

function TraitUtils.getFilteredList(excludedTypes)
	local source = TraitUtils.getList()
	local result = {}
	for i = 1, #source do
		local trait = source[i]
		if type(excludedTypes) ~= "table" or excludedTypes[trait.type] ~= true then
			result[#result + 1] = trait
		end
	end
	return result
end

function TraitUtils.getTexture(traitType)
	traitType = TextUtils.trim(traitType)
	if traitType == "" then
		return nil
	end
	if textureCache[traitType] ~= nil then
		return textureCache[traitType] or nil
	end

	local trait = TraitFactory and TraitFactory.getTrait and TraitFactory.getTrait(traitType) or nil
	local texture = trait and trait.getTexture and trait:getTexture() or nil
	textureCache[traitType] = texture or false
	return texture
end

function TraitUtils.getLabel(traitType)
	local info = TraitUtils.getInfo(traitType)
	return info and info.label or TextUtils.trim(traitType or "Trait")
end

function TraitUtils.getShortLabel(traitType)
	local compact = TraitUtils.getLabel(traitType):gsub("[%s%p_]+", ""):upper()
	if #compact >= 3 then
		return compact:sub(1, 3)
	end
	return compact ~= "" and compact or "TR"
end

function TraitUtils.getInitials(label, maximumLetters)
	maximumLetters = math.max(1, math.floor(tonumber(maximumLetters) or 2))
	local letters = {}
	for word in tostring(label or ""):gmatch("[%w']+") do
		letters[#letters + 1] = word:sub(1, 1):upper()
		if #letters >= maximumLetters then
			break
		end
	end

	if #letters == 0 then
		local fallback = tostring(label or ""):sub(1, maximumLetters):upper()
		return fallback ~= "" and fallback or "?"
	end
	return table.concat(letters)
end

function TraitUtils.sortByLabel(traits)
	if type(traits) ~= "table" then
		return traits
	end
	table.sort(traits, function(a, b)
		return tostring(a and a.label or ""):lower() < tostring(b and b.label or ""):lower()
	end)
	return traits
end

function TraitUtils.getTooltip(traitType)
	local info = TraitUtils.getInfo(traitType)
	if not info then
		return tostring(traitType or "")
	end

	local prefix = info.positive and "+" or "-"
	local description = TextUtils.trim(info.description)
	return description ~= "" and string.format("%s %s\n%s", prefix, info.label, description)
		or string.format("%s %s", prefix, info.label)
end

function TraitUtils.getOptions()
	if optionsCache then
		return optionsCache
	end

	local source = TraitUtils.getList()
	local result = {}
	for i = 1, #source do
		local trait = source[i]
		result[#result + 1] = {
			type = trait.type,
			label = trait.label,
			description = trait.description,
			positive = trait.positive,
			text = string.format("%s %s", trait.positive and "[+]" or "[-]", trait.label),
		}
	end
	optionsCache = result
	return result
end

function TraitUtils.clearCache()
	textureCache = {}
	listCache = nil
	optionsCache = nil
end

return TraitUtils
