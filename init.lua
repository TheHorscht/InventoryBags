dofile_once("data/scripts/lib/utilities.lua")
local nxml = dofile_once("mods/WandStorage/lib/nxml.lua")

local function ends_with(str, ending)
  return ending == "" or str:sub(-#ending) == ending
end

function get_active_item()
	local player = EntityGetWithTag("player_unit")[1]
	if player then
		local inventory2 = EntityGetFirstComponentIncludingDisabled(player, "Inventory2Component")
		local mActiveItem = ComponentGetValue2(inventory2, "mActiveItem")
		return mActiveItem > 0 and mActiveItem or nil
	end
end

function set_active_item(wand)
	local player = EntityGetWithTag("player_unit")[1]
	if player then
		local inventory2 = EntityGetFirstComponentIncludingDisabled(player, "Inventory2Component")
		ComponentSetValue2(inventory2, "mActiveItem", wand)
	end
end

function get_inventory_position(entity)
	local item_component = EntityGetFirstComponentIncludingDisabled(entity, "ItemComponent")
	return ComponentGetValue2(item_component, "inventory_slot")
end

function set_inventory_position(entity, slot)
	local item_component = EntityGetFirstComponentIncludingDisabled(entity, "ItemComponent")
	ComponentSetValue2(item_component, "inventory_slot", slot, 0)
end

function is_wand(entity)
	return EntityGetFirstComponentIncludingDisabled(entity, "ManaReloaderComponent")
end

function get_held_wands()
	local inventory = EntityGetWithName("inventory_quick")
	if inventory > 0 then
		local wands = {}
		for i, wand in ipairs(EntityGetAllChildren(inventory) or {}) do
			if is_wand(wand) then
				local sprite_component = EntityGetFirstComponentIncludingDisabled(wand, "SpriteComponent")
				local image_file = ComponentGetValue2(sprite_component, "image_file")
				if ends_with(image_file, ".xml") then
					image_file = get_wand_xml_sprite(image_file)
				end
				table.insert(wands, {
					entity_id = wand,
					image_file = image_file,
					inventory_slot = get_inventory_position(wand)
				})
			end
		end
		return wands
	else
		return {}
	end
end

function get_stored_wands()
	local wand_storage = EntityGetWithName("wand_storage_container")
	if wand_storage > 0 then
		local wands = EntityGetAllChildren(wand_storage) or {}
		for i, wand in ipairs(wands) do
			local sprite_component = EntityGetFirstComponentIncludingDisabled(wand, "SpriteComponent")
			local image_file = ComponentGetValue2(sprite_component, "image_file")
			if ends_with(image_file, ".xml") then
				image_file = get_wand_xml_sprite(image_file)
			end
			wands[i] = {
				entity_id = wand,
				image_file = image_file
			}
		end
		return wands
	else
		return {}
	end
end

function put_wand_in_storage(wand)
	local wand_storage = EntityGetWithName("wand_storage_container")
	local player = EntityGetWithTag("player_unit")[1]
	if player and wand_storage > 0 then
		local inventory2 = EntityGetFirstComponentIncludingDisabled(player, "Inventory2Component")
		local mActiveItem = ComponentGetValue2(inventory2, "mActiveItem")
		EntityRemoveFromParent(wand)
		EntityAddChild(wand_storage, wand)
		if wand == mActiveItem then
			ComponentSetValue2(inventory2, "mActiveItem", 0)
		end
	end
end

function has_enough_space_for_wand()
	local inventory = EntityGetWithName("inventory_quick")
	return #get_held_wands() < 4
end

function retrieve_or_swap_wand(wand)
	local inventory = EntityGetWithName("inventory_quick")
	local wand_storage = EntityGetWithName("wand_storage_container")
	if inventory > 0 and wand_storage > 0 then
		EntityRemoveFromParent(wand)
		local active_item = get_active_item()
		local inventory_slot
		if active_item and is_wand(active_item) then
			-- Swap
			inventory_slot = get_inventory_position(active_item)
			EntityRemoveFromParent(active_item)
			EntityAddChild(wand_storage, active_item)
		end
		EntityAddChild(inventory, wand)
		set_active_item(wand)
		set_inventory_position(wand, inventory_slot and inventory_slot or get_first_free_wand_slot())
	end
end

function get_first_free_wand_slot()
	local wands = get_held_wands()
	local free_wand_slots = { true, true, true, true }
	for i, wand in ipairs(wands) do
		free_wand_slots[wand.inventory_slot+1] = false
	end
	for slot, slot_is_free in ipairs(free_wand_slots) do
		if slot_is_free then
			return slot-1
		end
	end
end

local sprite_xml_path_cache = {}
local _ModTextFileGetContent = ModTextFileGetContent
function get_wand_xml_sprite(sprite_xml_path)
	if sprite_xml_path_cache[sprite_xml_path] then
		return sprite_xml_path_cache[sprite_xml_path]
	end
	local xml = nxml.parse(_ModTextFileGetContent(sprite_xml_path))
	sprite_xml_path_cache[sprite_xml_path] = xml.attr.filename
	return xml.attr.filename
end

function OnPlayerSpawned(player)
	local wand_storage = EntityGetWithName("wand_storage_container")
	if wand_storage == 0 then
		wand_storage = EntityCreateNew("wand_storage_container")
		EntityAddChild(player, wand_storage)
	end
end

function OnWorldPreUpdate()
	gui = gui or GuiCreate()
	open = open or false
	current_id = 1
	local function new_id()
		current_id = current_id + 1
		return current_id
	end
	GuiStartFrame(gui)
	local screen_width, screen_height = GuiGetScreenDimensions(gui)
	GuiOptionsAdd(gui, GUI_OPTION.NoPositionTween)
	if GuiButton(gui, new_id(), 0, 0, "X") then
		open = not open
	end
	if open then
		local slot_width, slot_height = 16, 16
		local box_width, box_height = 100, 100
		GuiLayoutBeginVertical(gui, 50, 50)
		GuiText(gui, -box_width/2, -box_height/2, "")
		GuiLayoutBeginHorizontal(gui, 0, 0)
		GuiZSetForNextWidget(gui, 20)
		GuiImageNinePiece(gui, new_id(), (screen_width - box_width) / 2, (screen_height - box_height) / 2, box_width, box_height, 1, "mods/WandStorage/files/container_9piece.png", "mods/WandStorage/files/container_9piece.png")
		-- Offset the layouting position
		GuiText(gui, -box_width/2, -box_height/2, "")
		local held_wands = get_held_wands()
		for i=1, 4 do
			local wand = held_wands[i]
			if wand then
				if GuiImageButton(gui, new_id(), 0, 0, "", "data/ui_gfx/inventory/inventory_box.png") then
					put_wand_in_storage(wand.entity_id)
				end
				local _, _, _, x, y, width, height = GuiGetPreviousWidgetInfo(gui)
				local w, h = GuiGetImageDimensions(gui, wand.image_file, 1) -- scale
				GuiOptionsAddForNextWidget(gui, GUI_OPTION.Layout_NoLayouting)
				GuiZSetForNextWidget(gui, -10)
				GuiImage(gui, new_id(), x + (width / 2 - w / 2), y + (height / 2 - h / 2), wand.image_file, 1, 1, 1, 0, GUI_RECT_ANIMATION_PLAYBACK.Loop)
			else
				GuiImage(gui, new_id(), 0, 0, "data/ui_gfx/inventory/inventory_box.png", 1, 1, 1)
			end
		end
		GuiLayoutEnd(gui)
		GuiText(gui, 0, 0, "")
		GuiLayoutBeginHorizontal(gui, 0, 0)
		GuiText(gui, -box_width/2, -box_height/2, "")
		local wands = get_stored_wands()
		for i, wand in ipairs(wands) do
			if GuiImageButton(gui, new_id(), 0, 0, "", wand.image_file) then
				if has_enough_space_for_wand() then
					retrieve_or_swap_wand(wand.entity_id)
				end
			end
		end
		GuiLayoutEnd(gui)
		GuiLayoutEnd(gui)
	end
end
