local TextUtils = require("ElyonLib/TextUtils/TextUtils")

local PerkUtils = {}

local TEXTURES = {
	Accuracy = "media/ui/ElyonLib/ui_skill_spiffo_accuracy.png",
	Agility = "media/ui/ElyonLib/ui_skill_spiffo_agility.png",
	Aiming = "media/ui/ElyonLib/ui_skill_spiffo_aiming.png",
	Axe = "media/ui/ElyonLib/ui_skill_spiffo_axe.png",
	Blunt = "media/ui/ElyonLib/ui_skill_spiffo_blunt.png",
	Carpentry = "media/ui/ElyonLib/ui_skill_spiffo_carpentry.png",
	Combat = "media/ui/ElyonLib/ui_skill_spiffo_combat.png",
	Cooking = "media/ui/ElyonLib/ui_skill_spiffo_cooking.png",
	Crafting = "media/ui/ElyonLib/ui_skill_spiffo_crafting.png",
	Doctor = "media/ui/ElyonLib/ui_skill_spiffo_first_aid.png",
	Electricity = "media/ui/ElyonLib/ui_skill_spiffo_electricity.png",
	Farming = "media/ui/ElyonLib/ui_skill_spiffo_farming.png",
	Firearm = "media/ui/ElyonLib/ui_skill_spiffo_firearm.png",
	Fishing = "media/ui/ElyonLib/ui_skill_spiffo_fishing.png",
	Fitness = "media/ui/ElyonLib/ui_skill_spiffo_fitness.png",
	Lightfoot = "media/ui/ElyonLib/ui_skill_spiffo_lightfooted.png",
	Lightfooted = "media/ui/ElyonLib/ui_skill_spiffo_lightfooted.png",
	LongBlade = "media/ui/ElyonLib/ui_skill_spiffo_long_blade.png",
	Maintenance = "media/ui/ElyonLib/ui_skill_spiffo_maintenance.png",
	Mechanics = "media/ui/ElyonLib/ui_skill_spiffo_mechanics.png",
	MetalWelding = "media/ui/ElyonLib/ui_skill_spiffo_metalworking.png",
	Nimble = "media/ui/ElyonLib/ui_skill_spiffo_nimble.png",
	PlantScavenging = "media/ui/ElyonLib/ui_skill_spiffo_plant_scavenging.png",
	Reloading = "media/ui/ElyonLib/ui_skill_spiffo_reloading.png",
	SmallBlade = "media/ui/ElyonLib/ui_skill_spiffo_small_blade.png",
	SmallBlunt = "media/ui/ElyonLib/ui_skill_spiffo_small_blunt.png",
	Sneak = "media/ui/ElyonLib/ui_skill_spiffo_sneaking.png",
	Sneaking = "media/ui/ElyonLib/ui_skill_spiffo_sneaking.png",
	Spear = "media/ui/ElyonLib/ui_skill_spiffo_spear.png",
	Sprinting = "media/ui/ElyonLib/ui_skill_spiffo_sprinting.png",
	Strength = "media/ui/ElyonLib/ui_skill_spiffo_strength.png",
	Survivalist = "media/ui/ElyonLib/ui_skill_spiffo_survivalist.png",
	Tailoring = "media/ui/Traits/trait_tailor.png",
	Trapping = "media/ui/ElyonLib/ui_skill_spiffo_trapping.png",
	Woodwork = "media/ui/ElyonLib/ui_skill_spiffo_carpentry.png",
}

local SHORT_LABELS = {
	Accuracy = "ACC", Agility = "AGY", Aiming = "AIM", Axe = "BAA", Blunt = "BUA",
	Carpentry = "CRP", Combat = "CMB", Cooking = "COO", Crafting = "CFT", Doctor = "AID",
	Electricity = "ELC", Farming = "FRM", Firearm = "FIR", Fishing = "FIS", Fitness = "FIT",
	Lightfoot = "LFT", Lightfooted = "LFT", LongBlade = "LBA", Maintenance = "MNT", Mechanics = "MCH",
	MetalWelding = "MTL", Nimble = "NIM", None = "NON", PlantScavenging = "FOR", Reloading = "REL",
	SmallBlade = "SBA", SmallBlunt = "SBU", Sneak = "SNE", Sneaking = "SNE", Spear = "SPR",
	Sprinting = "SPT", Strength = "STR", Survivalist = "SUR", Tailoring = "TAL", Trapping = "TRA",
	Woodwork = "WW",
}

local textureCache = {}
local optionsCache = nil

function PerkUtils.resolve(perkName)
	perkName = TextUtils.trim(perkName)
	if perkName == "" or not Perks then
		return nil
	end

	if Perks[perkName] then
		return Perks[perkName]
	end

	if Perks.FromString then
		local perk = Perks.FromString(perkName)
		if perk and perk ~= Perks.None and PerkFactory and PerkFactory.getPerk(perk) then
			return perk
		end
	end

	return nil
end

function PerkUtils.getDisplayName(perkName)
	local perk = PerkUtils.resolve(perkName)
	local info = perk and PerkFactory and PerkFactory.getPerk(perk) or nil
	return info and info.getName and info:getName() or TextUtils.trim(perkName)
end

function PerkUtils.getTexture(perkName)
	perkName = TextUtils.trim(perkName)
	if perkName == "" then
		return nil
	end
	if textureCache[perkName] ~= nil then
		return textureCache[perkName] or nil
	end

	local path = TEXTURES[perkName]
	local texture = path and getTexture and getTexture(path) or nil
	textureCache[perkName] = texture or false
	return texture
end

function PerkUtils.getShortLabel(perkName)
	perkName = TextUtils.trim(perkName)
	return SHORT_LABELS[perkName] or perkName:sub(1, 3):upper()
end

function PerkUtils.getOptions()
	if optionsCache then
		return optionsCache
	end

	local result = {}
	if not Perks or not Perks.getMaxIndex or not PerkFactory then
		return result
	end

	for i = 1, Perks.getMaxIndex() do
		local perk = PerkFactory.getPerk(Perks.fromIndex(i - 1))
		if perk and perk:getParent() ~= Perks.None then
			local label = perk:getName()
			local parentName = PerkFactory.getPerkName(perk:getParent())
			result[#result + 1] = {
				type = tostring(perk:getType()),
				label = label,
				text = parentName and parentName ~= "" and string.format("%s (%s)", label, parentName) or label,
			}
		end
	end

	table.sort(result, function(a, b)
		return tostring(a.label):lower() < tostring(b.label):lower()
	end)
	optionsCache = result
	return result
end

function PerkUtils.clearCache()
	textureCache = {}
	optionsCache = nil
end

return PerkUtils
