dofile_once("data/scripts/lib/utilities.lua")
dofile_once("data/scripts/gun/gun_actions.lua")
dofile_once("mods/InventoryBags/lib/coroutines.lua")
local sha1 = dofile_once("mods/InventoryBags/lib/sha1.lua")
dofile_once("mods/InventoryBags/lib/polytools/polytools_init.lua").init("mods/InventoryBags/lib/polytools")
local polytools = dofile_once("mods/InventoryBags/lib/polytools/polytools.lua")
local nxml = dofile_once("mods/InventoryBags/lib/nxml.lua")
local EZWand = dofile_once("mods/InventoryBags/lib/EZWand.lua")

local print_ = print
function print(...)
	print_(("(%d) %s"):format(GameGetFrameNum(), select(1, ...)) , select(2, ...))
end

local spell_icon_lookup = {}
for i, action in ipairs(actions) do
	spell_icon_lookup[action.id] = action.sprite
end

local function split_string(inputstr, sep)
  sep = sep or "%s"
  local t= {}
  for str in string.gmatch(inputstr, "([^"..sep.."]+)") do
    table.insert(t, str)
  end
  return t
end

local function ends_with(str, ending)
  return ending == "" or str:sub(-#ending) == ending
end

function get_active_item()
	local player = EntityGetWithTag("player_unit")[1]
	if player then
		local inventory2 = EntityGetFirstComponentIncludingDisabled(player, "Inventory2Component")
		local mActualActiveItem = ComponentGetValue2(inventory2, "mActualActiveItem")
		return mActualActiveItem > 0 and mActualActiveItem or nil
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
	local ability_component = EntityGetFirstComponentIncludingDisabled(entity, "AbilityComponent")
	return ComponentGetValue2(ability_component, "use_gun_script") == true
end

function is_item(entity)
	local ability_component = EntityGetFirstComponentIncludingDisabled(entity, "AbilityComponent")
	local ending_mc_guffin_component = EntityGetFirstComponentIncludingDisabled(entity, "EndingMcGuffinComponent")
	return ending_mc_guffin_component or ComponentGetValue2(ability_component, "use_gun_script") == false
end

function get_inventory()
	local player = EntityGetWithTag("player_unit")[1]
	if player then
		for i, child in ipairs(EntityGetAllChildren(player) or {}) do
			if EntityGetName(child) == "inventory_quick" then
				return child
			end
		end
	end
end

function get_held_wands()
	local inventory = get_inventory()
	if inventory then
		local active_item = get_active_item()
		local wands = {}
		for i, wand in ipairs(EntityGetAllChildren(inventory) or {}) do
			if is_wand(wand) then
				local sprite_component = EntityGetFirstComponentIncludingDisabled(wand, "SpriteComponent")
				local image_file = ComponentGetValue2(sprite_component, "image_file")
				if ends_with(image_file, ".xml") then
					image_file = get_xml_sprite(image_file)
				end
				table.insert(wands, {
					entity_id = wand,
					image_file = image_file,
					inventory_slot = get_inventory_position(wand),
					active = wand == active_item
				})
			end
		end
		return wands
	else
		return {}
	end
end

function get_held_items()
	local inventory = get_inventory()
	if inventory then
		local active_item = get_active_item()
		local items = {}
		for i, item in ipairs(EntityGetAllChildren(inventory) or {}) do
			if is_item(item) then
				local item_component = EntityGetFirstComponentIncludingDisabled(item, "ItemComponent")
				local image_file = ComponentGetValue2(item_component, "ui_sprite")
				if ends_with(image_file, ".xml") then
					image_file = get_xml_sprite(image_file)
				end
				table.insert(items, {
					entity_id = item,
					image_file = image_file,
					inventory_slot = get_inventory_position(item),
					active = item == active_item
				})
			end
		end
		return items
	else
		return {}
	end
end

function get_stored_wands()
	local wand_storage = EntityGetWithName("wand_storage_container")
	if wand_storage > 0 then
		local serialized_wands = EntityGetAllChildren(wand_storage) or {}
		for i, container_entity_id in ipairs(serialized_wands) do
			local serialized_ez, serialized_poly
			for i, comp in ipairs(EntityGetComponentIncludingDisabled(container_entity_id, "VariableStorageComponent")) do
				if ComponentGetValue2(comp, "name") == "serialized_ez" then
					serialized_ez = ComponentGetValue2(comp, "value_string")
				end
				if ComponentGetValue2(comp, "name") == "serialized_poly" then
					serialized_poly = ComponentGetValue2(comp, "value_string")
				end
			end
			local wand = EZWand.Deserialize(serialized_ez)
			if ends_with(wand.sprite_image_file, ".xml") then
				wand.sprite_image_file = get_xml_sprite(wand.sprite_image_file)
			end
			wand.container_entity_id = container_entity_id
			wand.serialized_poly = serialized_poly
			serialized_wands[i] = wand
		end
		return serialized_wands
	else
		return {}
	end
end

function get_stored_items()
	local item_storage = EntityGetWithName("item_storage_container")
	if item_storage > 0 then
		local serialized_items = EntityGetAllChildren(item_storage) or {}
		for i, container_entity_id in ipairs(serialized_items) do
			local image_file, potion_color, tooltip, serialized_poly
			for i, comp in ipairs(EntityGetComponentIncludingDisabled(container_entity_id, "VariableStorageComponent")) do
				if ComponentGetValue2(comp, "name") == "serialized_image_file" then
					image_file = ComponentGetValue2(comp, "value_string")
				end
				if ComponentGetValue2(comp, "name") == "serialized_potion_color" then
					potion_color = ComponentGetValue2(comp, "value_int")
				end
				if ComponentGetValue2(comp, "name") == "serialized_tooltip" then
					tooltip = ComponentGetValue2(comp, "value_string")
				end
				if ComponentGetValue2(comp, "name") == "serialized_poly" then
					serialized_poly = ComponentGetValue2(comp, "value_string")
				end
			end
			local item = {}
			item.container_entity_id = container_entity_id
			item.serialized_poly = serialized_poly
			item.image_file = image_file
			item.potion_color = potion_color
			item.tooltip = tooltip
			serialized_items[i] = item
		end
		return serialized_items
	else
		return {}
	end
end

function string_match_percent(ser1, ser2)
  local character_match_amount = 0
  local longest_length = math.max(ser1:len(), ser2:len())
  for i=1, longest_length do
    if ser1:sub(i,i) == ser2:sub(i,i) then
      character_match_amount = character_match_amount + 1
    end
  end
  return character_match_amount / longest_length
end

---Needs to be called from inside an async function. Kills entity and returns the serialized string after 1 frame.
function serialize_entity(entity, dont_kill)
	if not coroutine.running() then
		error("serialize_entity() must be called from inside an async function", 2)
	end
	EntityRemoveFromParent(entity)
	EntityApplyTransform(entity, 6666666, 6666666)
	local serialized = polytools.save(entity)
	wait(0)
	entity = EntityGetInRadius(6666666, 6666666, 5)[1]
	if not dont_kill then EntityKill(entity) end
	return serialized
end

function deserialize_entity(str)
	if not coroutine.running() then
		error("deserialize_entity() must be called from inside an async function", 2)
	end
	-- Move the entity to a unique location so that we can get a reference to the entity with EntityGetInRadius once polymorph wears off
	-- Apply polymorph which, when it runs out after 1 frame will turn the entity back into it's original form, which we provide
	polytools.spawn(666666, 666666, str)
	-- Wait 1 frame for the polymorph to wear off
	wait(0)
	local all_entities = EntityGetInRadius(666666, 666666, 3)
	return all_entities[1]
end

function create_storage_entity(ez, poly)
	-- print(("create_storage_entity(%s, %s) called"):format(ez, sha1.hex(poly):sub(1,8)))
	local entity = EntityCreateNew()
	EntityAddComponent2(entity, "VariableStorageComponent", {
		name = "serialized_ez",
		value_string = ez
	})
	EntityAddComponent2(entity, "VariableStorageComponent", {
		name = "serialized_poly",
		value_string = poly
	})
	return entity
end

function create_item_storage_entity(image_file, potion_color, tooltip, poly)
	-- print(("create_storage_entity(%s, %s) called"):format(ez, sha1.hex(poly):sub(1,8)))
	local entity = EntityCreateNew()
	EntityAddComponent2(entity, "VariableStorageComponent", {
		name = "serialized_image_file",
		value_string = image_file
	})
	EntityAddComponent2(entity, "VariableStorageComponent", {
		name = "serialized_potion_color",
		value_int = potion_color
	})
	EntityAddComponent2(entity, "VariableStorageComponent", {
		name = "serialized_tooltip",
		value_string = tooltip
	})
	EntityAddComponent2(entity, "VariableStorageComponent", {
		name = "serialized_poly",
		value_string = poly
	})
	return entity
end

function put_wand_in_storage(wand)
	local player = EntityGetWithTag("player_unit")[1]
	local wand_storage = EntityGetWithName("wand_storage_container")
	if player and wand_storage > 0 then
		async(function()
			local ez = EZWand(wand):Serialize()
			local poly = serialize_entity(wand)
			local new_entry = create_storage_entity(ez, poly)
			EntityAddChild(wand_storage, new_entry)
		end)
	end
end

function tooltipify_item(item)
	local ability_component = EntityGetFirstComponentIncludingDisabled(item, "AbilityComponent")
	local item_component = EntityGetFirstComponentIncludingDisabled(item, "ItemComponent")
	local potion_component = EntityGetFirstComponentIncludingDisabled(item, "PotionComponent")
	local description = ComponentGetValue2(item_component, "ui_description")
	description = GameTextGetTranslatedOrNot(description)
	local material_inventory_lines = ""
	local item_name = ComponentGetValue2(ability_component, "ui_name")
	-- Item name is either stored on AbilityComponent:ui_name or if that doesn't exist, ItemComponent:item_name
	if not item_name then
		item_name = ComponentGetValue2(item_component, "item_name")
	end
	if potion_component then
		local main_material_id = GetMaterialInventoryMainMaterial(item)
		local main_material = CellFactory_GetUIName(main_material_id)
		main_material = GameTextGetTranslatedOrNot(main_material)
		local material_inventory_component = EntityGetFirstComponentIncludingDisabled(item, "MaterialInventoryComponent")
		local material_sucker_component = EntityGetFirstComponentIncludingDisabled(item, "MaterialSuckerComponent")
		local barrel_size = ComponentGetValue2(material_sucker_component, "barrel_size")
		local count_per_material_type = ComponentGetValue2(material_inventory_component, "count_per_material_type")
		local total_amount = 0
		for material_id, amount in pairs(count_per_material_type) do
			if amount > 0 then
				total_amount = total_amount + amount
				local material_name = CellFactory_GetUIName(material_id-1)
				material_name = GameTextGetTranslatedOrNot(material_name)
				material_inventory_lines = material_inventory_lines .. ("%s (%d)"):format(material_name:gsub("^%l", string.upper), amount) .. "\n"
			end
		end
		local fill_percent = math.ceil((total_amount / barrel_size) * 100)
		item_name = (GameTextGet(item_name, main_material) .. GameTextGet("$item_potion_fullness", fill_percent)):upper()
	else
		item_name = GameTextGetTranslatedOrNot(item_name):upper()
	end

	local potion_color = GameGetPotionColorUint(item)
	local tooltip = item_name .. "\n \n"
	tooltip = tooltip .. description .. "\n \n"
	tooltip = tooltip .. material_inventory_lines
	local image_file = ComponentGetValue2(item_component, "ui_sprite")
	if ends_with(image_file, ".xml") then
		image_file = get_xml_sprite(image_file)
	end
	return image_file, potion_color, tooltip
end

function put_item_in_storage(item)
	local item_storage = EntityGetWithName("item_storage_container")
	local num_items_stored = #(EntityGetAllChildren(item_storage) or {})
	local player = EntityGetWithTag("player_unit")[1]
	if player and item_storage > 0 then
		local image_file, potion_color, tooltip = tooltipify_item(item)
		async(function()
			local poly = serialize_entity(item)
			local new_entry = create_item_storage_entity(image_file, potion_color ,tooltip, poly)
			EntityAddChild(item_storage, new_entry)
		end)
	end
end

function has_enough_space_for_wand()
	return #get_held_wands() < 4
end

function has_enough_space_for_item()
	return #get_held_items() < 4
end

function scroll_inventory(amount)
	local player = EntityGetWithTag("player_unit")[1]
	local controls_comp = EntityGetComponentIncludingDisabled(player, "ControlsComponent")[1]
	-- Disable the controls component so we can set the state ourself instead of it getting it from the input device
	ComponentSetValue2(controls_comp, "enabled", false)
	-- Just to make sure this gets re-enabled even it a bug occurs in the code after this
	async(function()
		-- Wait one frame then enable it again
		wait(0)
		ComponentSetValue2(controls_comp, "enabled", true)
	end)
	-- This allows us to simulate inventory scrolling
	-- Thanks to Lobzyr on the Noita discord for figuring this out
	ComponentSetValue2(controls_comp, "mButtonDownChangeItemR", true)
	ComponentSetValue2(controls_comp, "mButtonFrameChangeItemR", GameGetFrameNum() + 1)
	ComponentSetValue2(controls_comp, "mButtonCountChangeItemR", amount)
end

---Returns a table of entity ids currently occupying the inventory, their index is their inventory position
---@return table inventory In the form: { [0] = nil, [1] = 307, } etc
---@return number active_item
function get_inventory_and_active_item()
	local inventory = get_inventory()
	inventory = EntityGetAllChildren(inventory) or {}
	local current_active_item = get_active_item()
	local inv_out = {}
	local active_item
	for i, entity_id in ipairs(inventory) do
		if entity_id == current_active_item then
			active_item = current_active_item
		end
		local item_component = EntityGetFirstComponentIncludingDisabled(entity_id, "ItemComponent")
		local inventory_slot_x = ComponentGetValue2(item_component, "inventory_slot")
		local non_wand_offset = not is_wand(entity_id) and 4 or 0
		inv_out[inventory_slot_x+1 + non_wand_offset] = entity_id
	end
	return inv_out, active_item
end

function create_and_pick_up_wand(serialized, slot)
	print(("create_and_pick_up_wand(%s, %s) called"):format(sha1.hex(serialized):sub(1,8), slot))
	async(function()
		local new_wand = deserialize_entity(serialized)
		-- "Pick up" wand and place it in inventory
		local item_comp = EntityGetFirstComponentIncludingDisabled(new_wand, "ItemComponent")
		ComponentSetValue2(item_comp, "is_pickable", true)
		ComponentSetValue2(item_comp, "play_pick_sound", false)
		ComponentSetValue2(item_comp, "next_frame_pickable", 0)
		ComponentSetValue2(item_comp, "npc_next_frame_pickable", 0)
		local first_free_wand_slot = get_first_free_wand_slot()
		local new_slot = slot and slot or first_free_wand_slot
		GamePickUpInventoryItem(EntityGetWithTag("player_unit")[1], new_wand)
		set_inventory_position(new_wand, new_slot)
		local inventory = get_inventory()
		EntityAddChild(inventory, new_wand)
		-- /"Pick up" wand and place it in inventory

		-- Scroll to new wand to select it
		local inventory_slots, active_item = get_inventory_and_active_item()
		local active_item_item_comp = EntityGetFirstComponentIncludingDisabled(active_item, "ItemComponent")
		local currently_selected_slot = ComponentGetValue2(active_item_item_comp, "inventory_slot")
		print("active_item: " .. type(active_item) .. " - " .. tostring(active_item))
		if not active_item then
			currently_selected_slot = 0
		elseif not is_wand(active_item) then
			currently_selected_slot = currently_selected_slot + 4
		end
		-- Potions/Items start at 0, so add 4 to get the absolute position of the item in the inventory
		local change_amount = 0
		for i=currently_selected_slot, currently_selected_slot+8 do
			local slot_to_check = i % 8
			print("Checking slot " .. tostring(slot_to_check))
			if slot_to_check == new_slot then
				print("Change amount found: " .. tostring(change_amount))
				break
			end
			if inventory_slots[slot_to_check+1] then
				print("inventory_slots[slot_to_check] ("..tostring(slot_to_check)..") exists, adding change_amount + 1")
				change_amount = change_amount + 1
			end
		end
		if not active_item then
			change_amount = change_amount + 1
		end
		scroll_inventory(change_amount)
		-- /Scroll to new wand to select it
	end)
end

function create_and_pick_up_item(serialized, slot)
	print(("create_and_pick_up_item(%s, %s) called"):format(sha1.hex(serialized):sub(1,8), slot))
	async(function()
		local new_item = deserialize_entity(serialized)
		-- "Pick up" item and place it in inventory
		local item_comp = EntityGetFirstComponentIncludingDisabled(new_item, "ItemComponent")
		ComponentSetValue2(item_comp, "is_pickable", true)
		ComponentSetValue2(item_comp, "play_pick_sound", false)
		ComponentSetValue2(item_comp, "next_frame_pickable", 0)
		ComponentSetValue2(item_comp, "npc_next_frame_pickable", 0)
		local first_free_item_slot = get_first_free_item_slot()
		local new_slot = slot and slot or first_free_item_slot
		GamePickUpInventoryItem(EntityGetWithTag("player_unit")[1], new_item)
		set_inventory_position(new_item, new_slot)
		print("slot: " .. type(slot) .. " - " .. tostring(slot))
		print("NEW SLOOOOOOOT: " .. tostring(new_slot))
		local inventory = get_inventory()
		EntityAddChild(inventory, new_item)
		-- /"Pick up" item and place it in inventory

		-- Scroll to new item to select it
		local inventory_slots, active_item = get_inventory_and_active_item()
		local active_item_item_comp = EntityGetFirstComponentIncludingDisabled(active_item, "ItemComponent")
		local currently_selected_slot = ComponentGetValue2(active_item_item_comp, "inventory_slot")
		print("active_item: " .. type(active_item) .. " - " .. tostring(active_item))
		if not active_item then
			currently_selected_slot = 0
		elseif not is_wand(active_item) then
			currently_selected_slot = currently_selected_slot + 4
		end
		-- Potions/Items start at 0, so add 4 to get the absolute position of the item in the inventory
		-- local inv_count = #get_held_wands() + #get_held_items()
		local change_amount = 0
		for i=currently_selected_slot, currently_selected_slot+8 do
			local slot_to_check = i % 8
			print("Checking slot " .. tostring(slot_to_check+1))
			if slot_to_check == new_slot then
				print("Change amount found: " .. tostring(change_amount))
				break
			end
			if inventory_slots[slot_to_check+1] then -- and inventory_slots[slot_to_check+1] ~= new_item
				print("inventory_slots[slot_to_check] ("..tostring(slot_to_check+1)..") exists, adding change_amount + 1")
				change_amount = change_amount + 1
			end
		end
		if not active_item then
			change_amount = change_amount + 1
		end
		scroll_inventory(change_amount)
		-- /Scroll to new item to select it
	end)
end

function retrieve_or_swap_wand(wand)
	local inventory = get_inventory()
	if inventory > 0 then
		local active_item = get_active_item()
		local inventory_slot
		-- If we're already holding 4 wands and have none selected, don't do anything, otherwise swap the held wand with the stored one
		if not has_enough_space_for_wand() and active_item then
			if not is_wand(active_item) then
				return
			else
				-- Swap
				inventory_slot = get_inventory_position(active_item)
				put_wand_in_storage(active_item)
			end
		end
		local first_free_wand_slot = get_first_free_wand_slot()
		-- Make sure we only pick up the wand if either we have a wand selected that we will swap with, or have enough space
		if inventory_slot or first_free_wand_slot then
			create_and_pick_up_wand(wand.serialized_poly, inventory_slot or first_free_wand_slot)
			EntityKill(wand.container_entity_id)
		end
	end
end

function retrieve_or_swap_item(item)
	local inventory = get_inventory()
	local item_storage = EntityGetWithName("item_storage_container")
	if inventory > 0 and item_storage > 0 then
		local active_item = get_active_item()
		local inventory_slot
		if not has_enough_space_for_item() and active_item then
			if is_wand(active_item) then
				return
			else
				-- Swap
				inventory_slot = get_inventory_position(active_item)
				put_item_in_storage(active_item)
			end
		end
		local first_free_item_slot = get_first_free_item_slot()
		-- Make sure we only pick up the item if either we have an item selected that we will swap with, or have enough space
		if inventory_slot or first_free_item_slot then
			create_and_pick_up_item(item.serialized_poly, (inventory_slot or first_free_item_slot) + 4)
			EntityKill(item.container_entity_id)
		end
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

function get_first_free_item_slot()
	local items = get_held_items()
	local free_item_slots = { true, true, true, true }
	for i, item in ipairs(items) do
		free_item_slots[item.inventory_slot+1] = false
	end
	for slot, slot_is_free in ipairs(free_item_slots) do
		if slot_is_free then
			return slot-1
		end
	end
end

local sprite_xml_path_cache = {}
local _ModTextFileGetContent = ModTextFileGetContent
function get_xml_sprite(sprite_xml_path)
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
		async(function()
			wait(5)
			for i=1, 20 do
				local wand = EntityLoad("data/entities/items/wand_unshuffle_06.xml", 50 + i, 50)
				GamePickUpInventoryItem(player, wand)
				put_wand_in_storage(wand)
				wait(5)
			end
			for i=1, 20 do
				local item = EntityLoad("data/entities/items/pickup/potion.xml", 50 + i, 50)
				GamePickUpInventoryItem(player, item)
				put_item_in_storage(item)
				wait(5)
			end
		end)
	end
	local item_storage = EntityGetWithName("item_storage_container")
	if item_storage == 0 then
		item_storage = EntityCreateNew("item_storage_container")
		EntityAddChild(player, item_storage)
	end
end

function is_inventory_open()
	local player = EntityGetWithTag("player_unit")[1]
	if player then
		local inventory_gui_component = EntityGetFirstComponentIncludingDisabled(player, "InventoryGuiComponent")
		if inventory_gui_component then
			return ComponentGetValue2(inventory_gui_component, "mActive")
		end
	end
end

button_pos_x = ModSettingGet("InventoryBags.pos_x")
button_pos_y = ModSettingGet("InventoryBags.pos_y")
button_locked = ModSettingGet("InventoryBags.locked")

-- OnModSettingsChanged() seems to not work
function OnPausedChanged(is_paused, is_inventory_pause)
	if not button_locked and is_paused then
		ModSettingSetNextValue("InventoryBags.pos_x", button_pos_x, false)
		ModSettingSetNextValue("InventoryBags.pos_y", button_pos_y, false)
	else
		button_pos_x = ModSettingGet("InventoryBags.pos_x")
		button_pos_y = ModSettingGet("InventoryBags.pos_y")
	end
	button_locked = ModSettingGet("InventoryBags.locked")
end

function OnWorldPreUpdate()
	-- This is for making async functions work
	wake_up_waiting_threads(1)
	gui = gui or GuiCreate()
	open = open or false
	current_id = 1
	local function new_id()
		current_id = current_id + 1
		return current_id
	end
	GuiStartFrame(gui)
	GuiOptionsAdd(gui, GUI_OPTION.NoPositionTween)

	local inventory_open = is_inventory_open()
	-- If button dragging is enabled in the settings and the inventory is not open, make it draggable
	if not inventory_open and not button_locked then
		GuiOptionsAddForNextWidget(gui, GUI_OPTION.IsExtraDraggable)
		GuiOptionsAddForNextWidget(gui, GUI_OPTION.DrawNoHoverAnimation)
		GuiImageButton(gui, 5318008, button_pos_x, button_pos_y, "", "mods/InventoryBags/files/gui_button_invisible.png")
		local _, _, hovered, x, y, draw_width, draw_height, draw_x, draw_y = GuiGetPreviousWidgetInfo(gui)
		if draw_x ~= 0 and draw_y ~= 0 and draw_x ~= button_pos_x and draw_y ~= button_pos_y then
			button_pos_x = draw_x - draw_width / 2
			button_pos_y = draw_y - draw_height / 2
		end
	end
	-- Toggle it open/closed
	if not inventory_open and GuiImageButton(gui, new_id(), button_pos_x, button_pos_y, "", "mods/InventoryBags/files/gui_button.png") then
		open = not open
	end

	if open and not inventory_open then
		local slot_width, slot_height = 16, 16
		local slot_margin = 1
		local slot_width_total, slot_height_total = (slot_width + slot_margin * 2), (slot_height + slot_margin * 2)
		local spacer = 4
		local held_wands = get_held_wands()
		local stored_wands = get_stored_wands()
		local held_items = get_held_items()
		local stored_items = get_stored_items()
		local rows_wands = math.max(4, math.ceil(#stored_wands / 4))
		local rows_items = math.max(4, math.ceil(#stored_items / 4))
		local box_width = slot_width_total * 4
		local box_height_wands = slot_height_total * (rows_wands+1) + spacer
		local box_height_items = slot_height_total * (rows_items+1) + spacer
		-- Render wand bag
		local origin_x, origin_y = 23, 48
		GuiZSetForNextWidget(gui, 20)
		GuiImageNinePiece(gui, new_id(), origin_x, origin_y, box_width, box_height_wands, 1, "mods/InventoryBags/files/container_9piece.png", "mods/InventoryBags/files/container_9piece.png")
		local tooltip_wand
		local taken_slots = {}
		-- Render the held wands and save the taken positions so we can render the empty slots after this
		for i, wand in ipairs(held_wands) do
			if wand then
				taken_slots[wand.inventory_slot] = true
				if GuiImageButton(gui, new_id(), origin_x + slot_margin + wand.inventory_slot * slot_width_total, origin_y + slot_margin, "", "data/ui_gfx/inventory/inventory_box.png") then
					put_wand_in_storage(wand.entity_id)
				end
				local _, _, hovered, x, y, width, height = GuiGetPreviousWidgetInfo(gui)
				local w, h = GuiGetImageDimensions(gui, wand.image_file, 1) -- scale
				local scale = hovered and 1.2 or 1
				if hovered then
					tooltip_wand = EZWand.Deserialize(EZWand(wand.entity_id):Serialize()) --wand.entity_id
				end
				GuiZSetForNextWidget(gui, -9)
				if wand.active then
					GuiImage(gui, new_id(), x + (width / 2 - (16 * scale) / 2), y + (height / 2 - (16 * scale) / 2), "mods/InventoryBags/files/highlight_box.png", 1, scale, scale)
				end
				GuiZSetForNextWidget(gui, -10)
				GuiImage(gui, new_id(), x + (width / 2 - (w * scale) / 2), y + (height / 2 - (h * scale) / 2), wand.image_file, 1, scale, scale, 0, GUI_RECT_ANIMATION_PLAYBACK.Loop)
			end
		end
		for i=0, (4-1) do
			if not taken_slots[i] then
				GuiImage(gui, new_id(), origin_x + slot_margin + i * slot_width_total, origin_y + slot_margin, "data/ui_gfx/inventory/inventory_box.png", 1, 1, 1)
			end
		end
		for iy=0, (rows_wands-1) do
			for ix=0, (4-1) do
				local wand = stored_wands[(iy*4 + ix) + 1]
				if wand then
					if GuiImageButton(gui, new_id(), origin_x + slot_margin + ix * slot_width_total, origin_y + spacer + slot_margin + slot_height_total + iy * slot_height_total, "", "data/ui_gfx/inventory/inventory_box.png") then
						retrieve_or_swap_wand(wand)
					end
					local _, _, hovered, x, y, width, height = GuiGetPreviousWidgetInfo(gui)
					local w, h = GuiGetImageDimensions(gui, wand.sprite_image_file, 1) -- scale
					local scale = hovered and 1.2 or 1
					if hovered then
						tooltip_wand = wand
					end
					GuiZSetForNextWidget(gui, -10)
					GuiImage(gui, new_id(), x + (width / 2 - (w * scale) / 2), y + (height / 2 - (h *scale) / 2), wand.sprite_image_file, 1, scale, scale, 0, GUI_RECT_ANIMATION_PLAYBACK.Loop)
				else
					GuiImage(gui, new_id(), origin_x + slot_margin + ix * slot_width_total, origin_y + spacer + slot_margin + slot_height_total + iy * slot_height_total, "data/ui_gfx/inventory/inventory_box.png", 1, 1, 1)
				end
			end
		end
		-- Render item bag
		origin_x = origin_x + box_width + 9
		GuiZSetForNextWidget(gui, 20)
		GuiImageNinePiece(gui, new_id(), origin_x, origin_y, box_width, box_height_items, 1, "mods/InventoryBags/files/container_9piece.png", "mods/InventoryBags/files/container_9piece.png")
		local tooltip_item
		local taken_slots = {}
		-- Render the held items and save the taken positions so we can render the empty slots after this
		for i, item in ipairs(held_items) do
			if item then
				taken_slots[item.inventory_slot] = true
				if GuiImageButton(gui, new_id(), origin_x + slot_margin + item.inventory_slot * slot_width_total, origin_y + slot_margin, "", "data/ui_gfx/inventory/inventory_box.png") then
					put_item_in_storage(item.entity_id)
				end
				local _, _, hovered, x, y, width, height = GuiGetPreviousWidgetInfo(gui)
				local w, h = GuiGetImageDimensions(gui, item.image_file, 1)
				local scale = hovered and 1.2 or 1
				if hovered then
					local image_file, potion_color, tooltip = tooltipify_item(item.entity_id)
					tooltip_item = tooltip
				end
				GuiZSetForNextWidget(gui, -9)
				if item.active then
					GuiImage(gui, new_id(), x + (width / 2 - (16 * scale) / 2), y + (height / 2 - (16 * scale) / 2), "mods/InventoryBags/files/highlight_box.png", 1, scale, scale)
				end
				GuiZSetForNextWidget(gui, -10)
				local potion_color = GameGetPotionColorUint(item.entity_id)
				if potion_color ~= 0 then
					local b = bit.rshift(bit.band(potion_color, 0xFF0000), 16) / 0xFF
					local g = bit.rshift(bit.band(potion_color, 0xFF00), 8) / 0xFF
					local r = bit.band(potion_color, 0xFF) / 0xFF
					GuiColorSetForNextWidget(gui, r, g, b, 1)
				end
				GuiImage(gui, new_id(), x + (width / 2 - (w * scale) / 2), y + (height / 2 - (h * scale) / 2), item.image_file, 1, scale, scale, 0, GUI_RECT_ANIMATION_PLAYBACK.Loop)
			end
		end
		for i=0, (4-1) do
			if not taken_slots[i] then
				GuiImage(gui, new_id(), origin_x + slot_margin + i * slot_width_total, origin_y + slot_margin, "data/ui_gfx/inventory/inventory_box.png", 1, 1, 1)
			end
		end
		for iy=0, (rows_items-1) do
			for ix=0, (4-1) do
				local item = stored_items[(iy*4 + ix) + 1]
				if item then
					if GuiImageButton(gui, new_id(), origin_x + slot_margin + ix * slot_width_total, origin_y + spacer + slot_margin + slot_height_total + iy * slot_height_total, "", "data/ui_gfx/inventory/inventory_box.png") then
						retrieve_or_swap_item(item)
					end
					local _, _, hovered, x, y, width, height = GuiGetPreviousWidgetInfo(gui)
					local w, h = GuiGetImageDimensions(gui, item.image_file, 1)
					local scale = hovered and 1.2 or 1
					if hovered then
						tooltip_item = item.tooltip
					end
					GuiZSetForNextWidget(gui, -10)
					local potion_color = item.potion_color
					if potion_color ~= 0 then
						local b = bit.rshift(bit.band(potion_color, 0xFF0000), 16) / 0xFF
						local g = bit.rshift(bit.band(potion_color, 0xFF00), 8) / 0xFF
						local r = bit.band(potion_color, 0xFF) / 0xFF
						GuiColorSetForNextWidget(gui, r, g, b, 1)
					end
					GuiImage(gui, new_id(), x + (width / 2 - (w * scale) / 2), y + (height / 2 - (h *scale) / 2), item.image_file, 1, scale, scale, 0, GUI_RECT_ANIMATION_PLAYBACK.Loop)
				else
					GuiImage(gui, new_id(), origin_x + slot_margin + ix * slot_width_total, origin_y + spacer + slot_margin + slot_height_total + iy * slot_height_total, "data/ui_gfx/inventory/inventory_box.png", 1, 1, 1)
				end
			end
		end
		-- Render a tooltip of the hovered wand if we have any
		if tooltip_wand then
			local wand = tooltip_wand
			local margin = -3
			local wand_name = "WAND"
			local _, _, _, spread_icon_x, spread_icon_y, spread_icon_width, spread_icon_height -- Saves the position and width of the spread icon so we can draw the spells below it
			GuiBeginAutoBox(gui)
			GuiLayoutBeginHorizontal(gui, origin_x + box_width + 20, origin_y + 5, true)
			GuiLayoutBeginVertical(gui, 0, 0)
			GuiText(gui, 0, 0, wand_name)
			GuiImage(gui, new_id(), 0, 7, "data/ui_gfx/inventory/icon_gun_shuffle.png", 1, 1, 1)
			GuiImage(gui, new_id(), 0, 1, "data/ui_gfx/inventory/icon_gun_actions_per_round.png", 1, 1, 1)
			GuiImage(gui, new_id(), 0, 1, "data/ui_gfx/inventory/icon_fire_rate_wait.png", 1, 1, 1)
			GuiImage(gui, new_id(), 0, 1, "data/ui_gfx/inventory/icon_gun_reload_time.png", 1, 1, 1)
			GuiImage(gui, new_id(), 0, 1, "data/ui_gfx/inventory/icon_mana_max.png", 1, 1, 1)
			GuiImage(gui, new_id(), 0, 1, "data/ui_gfx/inventory/icon_mana_charge_speed.png", 1, 1, 1)
			GuiImage(gui, new_id(), 0, 1, "data/ui_gfx/inventory/icon_gun_capacity.png", 1, 1, 1)
			GuiImage(gui, new_id(), 0, 1, "data/ui_gfx/inventory/icon_spread_degrees.png", 1, 1, 1)
			_, _, _, spread_icon_x, spread_icon_y, spread_icon_width, spread_icon_height = GuiGetPreviousWidgetInfo(gui)
			GuiLayoutEnd(gui)
			local wand_name_width = GuiGetTextDimensions(gui, wand_name)
			GuiLayoutBeginVertical(gui, 12 - wand_name_width, 0, true)
			GuiText(gui, 0, 0, " ")
			GuiText(gui, 0, 5, GameTextGetTranslatedOrNot("$inventory_shuffle"))
			GuiText(gui, 0, margin, GameTextGetTranslatedOrNot("$inventory_actionspercast"))
			GuiText(gui, 0, margin, GameTextGetTranslatedOrNot("$inventory_castdelay"))
			GuiText(gui, 0, margin, GameTextGetTranslatedOrNot("$inventory_rechargetime"))
			GuiText(gui, 0, margin, GameTextGetTranslatedOrNot("$inventory_manamax"))
			GuiText(gui, 0, margin, GameTextGetTranslatedOrNot("$inventory_manachargespeed"))
			GuiText(gui, 0, margin, GameTextGetTranslatedOrNot("$inventory_capacity"))
			GuiText(gui, 0, margin, GameTextGetTranslatedOrNot("$inventory_spread"))
			GuiLayoutEnd(gui)
			GuiLayoutBeginVertical(gui, 0, 0, true)
			GuiText(gui, 0, 0, " ")
			GuiText(gui, 0, 5, GameTextGetTranslatedOrNot(wand.props.shuffle and "$menu_yes" or "$menu_no"))
			GuiText(gui, 0, margin, string.format("%.0f", wand.props.spellsPerCast))
			GuiText(gui, 0, margin, string.format("%.2f s", wand.props.castDelay / 60))
			GuiText(gui, 0, margin, string.format("%.2f s", wand.props.rechargeTime / 60))
			GuiText(gui, 0, margin, string.format("%.0f", wand.props.manaMax))
			GuiText(gui, 0, margin, string.format("%.0f", wand.props.manaChargeSpeed))
			GuiText(gui, 0, margin, string.format("%.0f", wand.props.capacity))
			GuiText(gui, 0, margin, string.format("%.1f DEG", wand.props.spread))
			GuiLayoutEnd(gui)
			GuiLayoutEnd(gui)
			local spells = wand.spells
			GuiLayoutBeginHorizontal(gui, spread_icon_x, spread_icon_y + spread_icon_height + 7, true)
			local row = 0
			local spell_icon_scale = 0.75
			for i=1, wand.props.capacity do
				GuiZSetForNextWidget(gui, 9)
				GuiImage(gui, new_id(), -0.5, -0.5, "data/ui_gfx/inventory/inventory_box.png", 1, spell_icon_scale, spell_icon_scale)
				if spells[i] then
					local _, _, _, x, y = GuiGetPreviousWidgetInfo(gui)
					GuiZSetForNextWidget(gui, 8)
					GuiOptionsAddForNextWidget(gui, GUI_OPTION.Layout_NoLayouting)
					GuiImage(gui, new_id(), x, y, spell_icon_lookup[spells[i]] or "data/ui_gfx/gun_actions/unidentified.png", 1, spell_icon_scale, spell_icon_scale)
				end
				-- Start a new row after 10 spells
				if i % 10 == 0 then
					row = row + 1
					GuiLayoutEnd(gui)
					GuiLayoutBeginHorizontal(gui, spread_icon_x, spread_icon_y + spread_icon_height + 7 + row * 18 * spell_icon_scale, true)
				end
			end
			GuiLayoutEnd(gui)
			GuiZSetForNextWidget(gui, 10)
			GuiEndAutoBoxNinePiece(gui)
		end
		-- Render a tooltip of the hovered item if we have any
		if tooltip_item then


			-- GuiText(gui, 0, 0, item_name)
			-- for i, line in ipairs(description) do
			-- 	GuiText(gui, 0, i == 1 and 7 or 0, line)
			-- end
			-- for i, line in ipairs(lines) do
			-- 	GuiText(gui, 0, i == 1 and 7 or -1, line)
			-- end




			GuiBeginAutoBox(gui)
			GuiLayoutBeginHorizontal(gui, origin_x + box_width + 20, origin_y + 5, true)
			GuiLayoutBeginVertical(gui, 0, 0)
			local lines = split_string(tooltip_item, "\n")
			for i, line in ipairs(lines) do
				-- GuiText(gui, 0, 0, line)
				local offset = line == " " and -7 or 0
				GuiText(gui, 0, offset, line)
				-- GuiText(gui, 0, i == 2 and -4 or 0, line)
				-- GuiText(gui, 0, i == 1 and 7 or 0, line)
			end
			GuiLayoutEnd(gui)
			GuiLayoutEnd(gui)
			GuiZSetForNextWidget(gui, 10)
			GuiEndAutoBoxNinePiece(gui)
		end
	end
end
