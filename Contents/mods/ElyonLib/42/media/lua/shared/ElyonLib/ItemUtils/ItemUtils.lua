local TextUtils = require("ElyonLib/TextUtils/TextUtils")

local ItemUtils = {}
ItemUtils.Cache = ItemUtils.Cache or {}
ItemUtils.TextureReferenceCache = ItemUtils.TextureReferenceCache or {}

local function getFullType(itemOrType)
	if type(itemOrType) == "string" then
		return TextUtils.trim(itemOrType)
	end
	if not itemOrType then
		return ""
	end
	if itemOrType.getFullName then
		local fullName = itemOrType:getFullName()
		if fullName and fullName ~= "" then
			return TextUtils.trim(fullName)
		end
	end
	if itemOrType.getFullType then
		local fullType = itemOrType:getFullType()
		if fullType and fullType ~= "" then
			return TextUtils.trim(fullType)
		end
	end
	return ""
end

local function loadTextureChoice(id, icons)
	if not getTexture then
		return nil
	end
	if id >= 0 and id < icons:size() then
		return getTexture("Item_" .. tostring(icons:get(id)))
	end
	return nil
end

local function getScriptItem(fullType)
	local scriptManager = getScriptManager and getScriptManager() or nil
	local item = scriptManager and scriptManager:FindItem(fullType) or nil
	if not item and ScriptManager and ScriptManager.instance and ScriptManager.instance.getItem then
		item = ScriptManager.instance:getItem(fullType)
	end
	return item
end

local function getFallbackDisplayName(fullType)
	local itemName = getItemNameFromFullType and getItemNameFromFullType(fullType) or nil
	if itemName and itemName ~= "" then
		return itemName
	end
	return fullType
end

local function resolveEntry(fullType)
	local entry = ItemUtils.Cache[fullType]
	if entry then
		return entry
	end

	local item = getScriptItem(fullType)
	local displayName = getFallbackDisplayName(fullType)
	if item and item.getDisplayName then
		local itemDisplayName = item:getDisplayName()
		if itemDisplayName and itemDisplayName ~= "" then
			displayName = itemDisplayName
		end
	end

	entry = {
		fullType = fullType,
		item = item or false,
		displayName = displayName,
		texture = false,
		textureName = false,
		textureResolved = false,
	}
	ItemUtils.Cache[fullType] = entry
	return entry
end

local function resolveTexture(entry)
	if not entry or entry.textureResolved then
		return entry
	end

	entry.textureResolved = true
	local item = entry.item or nil
	if not item then
		return entry
	end

	local texture = item.getNormalTexture and item:getNormalTexture() or nil
	if not texture and item.InstanceItem then
		local itemObject = item:InstanceItem(nil)
		if itemObject then
			local icons = item.getIconsForTexture and item:getIconsForTexture() or nil
			if icons and icons:size() > 0 and itemObject.getVisual then
				local visual = itemObject:getVisual()
				if visual then
					texture = loadTextureChoice(visual:getBaseTexture(), icons)
						or loadTextureChoice(visual:getTextureChoice(), icons)
				end
			end
			if not texture and itemObject.getTexture then
				texture = itemObject:getTexture()
			end
		end
	end

	if not texture and item.getTexture then
		texture = item:getTexture()
	end
	if not texture and item.getIcon then
		local icon = item:getIcon()
		if icon and icon ~= "" and getTexture then
			texture = getTexture("Item_" .. tostring(icon))
			if not texture then
				texture = getTexture("media/textures/Item_" .. tostring(icon) .. ".png")
			end
		end
	end

	entry.texture = texture or false
	if texture and texture.getName then
		local textureName = texture:getName()
		if textureName and textureName ~= "" then
			if textureName:find("[\\/]+") then
				entry.textureName = textureName:match(".*(media[\\/].+)") or textureName
			else
				entry.textureName = textureName
			end
		end
	end

	return entry
end

function ItemUtils.getScriptItem(itemOrType)
	local fullType = getFullType(itemOrType)
	if fullType == "" then
		return nil
	end
	local entry = resolveEntry(fullType)
	return entry.item or nil
end

function ItemUtils.getTexture(itemOrType)
	local fullType = getFullType(itemOrType)
	if fullType == "" then
		return nil
	end
	local entry = resolveTexture(resolveEntry(fullType))
	return entry and entry.texture or nil
end

function ItemUtils.getTextureName(itemOrType)
	local fullType = getFullType(itemOrType)
	if fullType == "" then
		return nil
	end
	local entry = resolveTexture(resolveEntry(fullType))
	return entry and entry.textureName or nil
end

function ItemUtils.getDisplayName(itemOrType)
	local fullType = getFullType(itemOrType)
	if fullType == "" then
		return tostring(itemOrType or "")
	end
	local entry = resolveEntry(fullType)
	return entry and entry.displayName or fullType
end

function ItemUtils.getTextureFromReference(reference)
	if type(reference) ~= "string" then
		return ItemUtils.getTexture(reference)
	end

	local value = TextUtils.trim(reference)
	if value == "" then
		return nil
	end
	if ItemUtils.TextureReferenceCache[value] ~= nil then
		return ItemUtils.TextureReferenceCache[value] or nil
	end

	local texture = ItemUtils.getTexture(value)
	if not texture and getTexture then
		texture = getTexture(value)
	end
	if not texture and getTexture and not value:find("[/\\]") and not value:find("%.png$") then
		texture = getTexture("media/textures/" .. value .. ".png")
	end
	if not texture and getTexture and value:sub(1, 5) == "Item_" then
		texture = getTexture("media/textures/" .. value .. ".png")
	end

	ItemUtils.TextureReferenceCache[value] = texture or false
	return texture
end

function ItemUtils.clearCache(fullType)
	fullType = getFullType(fullType)
	if fullType ~= "" then
		ItemUtils.Cache[fullType] = nil
		ItemUtils.TextureReferenceCache[fullType] = nil
		return
	end
	ItemUtils.Cache = {}
	ItemUtils.TextureReferenceCache = {}
end

return ItemUtils
