-- TODO: Add something like filters
-- For instance 4 buttons at the top, labeled [1][2][3][4] and you can set tooltip names for it in the mod settings

dofile_once("data/scripts/lib/utilities.lua")
dofile_once("data/scripts/gun/gun_enums.lua")
dofile_once("mods/InventoryBags/lib/coroutines.lua")
dofile_once("mods/InventoryBags/lib/polytools/polytools_init.lua").init("mods/InventoryBags/lib/polytools")
local polytools = dofile_once("mods/InventoryBags/lib/polytools/polytools.lua")
local nxml = dofile_once("mods/InventoryBags/lib/nxml.lua")
local EZWand = dofile_once("mods/InventoryBags/lib/EZWand/EZWand.lua")

local num_tabs = 5
local storage_version = 1
local wand_storage_changed = true
local item_storage_changed = true

local function split_string(inputstr, sep)
  sep = sep or "%s"
  local t= {}
  for str in string.gmatch(inputstr, "([^"..sep.."]+)") do
    table.insert(t, str)
  end
  return t
end

local function ends_with(str, ending)
	if not str then error("str is nil", 2) end
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
	return (not ability_component) or ending_mc_guffin_component or ComponentGetValue2(ability_component, "use_gun_script") == false
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

function get_stored_wands(tab_number)
	tab_number = tab_number or 1
	if not wand_storage_changed then
		return cached_stored_wands
	else
		local wand_storage = EntityGetWithName("wand_storage_container")
		local out = {}
		if wand_storage > 0 then
			local tab_entity = get_tab_entity(wand_storage, tab_number)
			local serialized_wands = EntityGetAllChildren(tab_entity) or {}
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
			table.sort(serialized_wands, function (a, b)
				return a.container_entity_id < b.container_entity_id
			end)
			out = serialized_wands
		end
		wand_storage_changed = false
		cached_stored_wands = out
		return cached_stored_wands
	end
end

function get_stored_items(tab_number)
	tab_number = tab_number or 1
	if not item_storage_changed then
		return cached_stored_items
	else
		local item_storage = EntityGetWithName("item_storage_container")
		local out = {}
		if item_storage > 0 then
			local tab_entity = get_tab_entity(item_storage, tab_number)
			local serialized_items = EntityGetAllChildren(tab_entity) or {}
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
			table.sort(serialized_items, function (a, b)
				return a.container_entity_id < b.container_entity_id
			end)
			out = serialized_items
		end
		item_storage_changed = false
		cached_stored_items = out
		return cached_stored_items
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
function serialize_entity(entity)
	if not coroutine.running() then
		error("serialize_entity() must be called from inside an async function", 2)
	end
	EntityRemoveFromParent(entity)
	EntityApplyTransform(entity, 6666666, 6666666)
	local serialized = polytools.save(entity)
	wait(0)
	entity = EntityGetInRadius(6666666, 6666666, 5)[1]
	EntityKill(entity)
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
	return EntityGetRootEntity(all_entities[1])
end

function get_tab_entity(storage_entity, tab_number)
	for i, child in ipairs(EntityGetAllChildren(storage_entity) or {}) do
		if EntityGetName(child) == "tab_" .. tab_number then
			return child
		end
	end
end

function create_storage_entity(ez, poly)
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

function put_wand_in_storage(wand, tab_number)
	if not coroutine.running() then
		error("put_wand_in_storage() must be called from inside an async function", 2)
	end
	tab_number = tab_number or 1
	local player = EntityGetWithTag("player_unit")[1]
	local wand_storage = EntityGetWithName("wand_storage_container")
	if player and wand_storage > 0 then
		wait(0) -- I don't know why this is needed but it won't work otherwise...
		local ez = EZWand(wand):Serialize()
		local poly = serialize_entity(wand)
		local new_entry = create_storage_entity(ez, poly)
		local tab_entity = get_tab_entity(wand_storage, tab_number)
		EntityAddChild(tab_entity, new_entry)
		wand_storage_changed = true
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

function put_item_in_storage(item, tab_number)
	if not coroutine.running() then
		error("put_item_in_storage() must be called from inside an async function", 2)
	end
	tab_number = tab_number or 1
	local item_storage = EntityGetWithName("item_storage_container")
	local num_items_stored = #(EntityGetAllChildren(item_storage) or {})
	local player = EntityGetWithTag("player_unit")[1]
	if player and item_storage > 0 then
		wait(0) -- I don't know why this is needed but it won't work otherwise...
		local image_file, potion_color, tooltip = tooltipify_item(item)
		local poly = serialize_entity(item)
		local new_entry = create_item_storage_entity(image_file, potion_color ,tooltip, poly)
		local tab_entity = get_tab_entity(item_storage, tab_number)
		EntityAddChild(tab_entity, new_entry)
		item_storage_changed = true
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
	if not coroutine.running() then
		error("create_and_pick_up_wand() must be called from inside an async function", 2)
	end
	local new_wand = deserialize_entity(serialized)
	-- "Pick up" wand and place it in inventory
	local item_comp = EntityGetFirstComponentIncludingDisabled(new_wand, "ItemComponent")
	ComponentSetValue2(item_comp, "is_pickable", true)
	ComponentSetValue2(item_comp, "play_pick_sound", false)
	ComponentSetValue2(item_comp, "next_frame_pickable", 0)
	ComponentSetValue2(item_comp, "npc_next_frame_pickable", 0)
	local first_free_wand_slot = get_first_free_wand_slot()
	local new_slot = slot and slot or first_free_wand_slot
	GamePickUpInventoryItem(EntityGetWithTag("player_unit")[1], new_wand, false)
	set_inventory_position(new_wand, new_slot)
	local inventory = get_inventory()
	EntityAddChild(inventory, new_wand)
	-- /"Pick up" wand and place it in inventory

	-- Scroll to new wand to select it
	local inventory_slots, active_item = get_inventory_and_active_item()
	local active_item_item_comp = EntityGetFirstComponentIncludingDisabled(active_item, "ItemComponent")
	local currently_selected_slot = ComponentGetValue2(active_item_item_comp, "inventory_slot")
	if not active_item then
		currently_selected_slot = 0
	elseif not is_wand(active_item) then
		-- Potions/Items start at 0, so add 4 to get the absolute position of the item in the inventory
		currently_selected_slot = currently_selected_slot + 4
	end
	local change_amount = 0
	for i=currently_selected_slot, currently_selected_slot+8 do
		local slot_to_check = i % 8
		if slot_to_check == new_slot then
			break
		end
		if inventory_slots[slot_to_check+1] then
			change_amount = change_amount + 1
		end
	end
	if not active_item then
		change_amount = change_amount + 1
	end
	scroll_inventory(change_amount)
	-- /Scroll to new wand to select it
end

function create_and_pick_up_item(serialized, slot)
	local new_item = deserialize_entity(serialized)
	-- "Pick up" item and place it in inventory
	local item_comp = EntityGetFirstComponentIncludingDisabled(new_item, "ItemComponent")
	ComponentSetValue2(item_comp, "is_pickable", true)
	ComponentSetValue2(item_comp, "play_pick_sound", false)
	ComponentSetValue2(item_comp, "next_frame_pickable", 0)
	ComponentSetValue2(item_comp, "npc_next_frame_pickable", 0)
	local first_free_item_slot = get_first_free_item_slot()
	local new_slot = slot and slot or first_free_item_slot
	GamePickUpInventoryItem(EntityGetWithTag("player_unit")[1], new_item, false)
	set_inventory_position(new_item, new_slot)
	local inventory = get_inventory()
	EntityAddChild(inventory, new_item)
	-- /"Pick up" item and place it in inventory

	-- Scroll to new item to select it
	local inventory_slots, active_item = get_inventory_and_active_item()
	local active_item_item_comp = EntityGetFirstComponentIncludingDisabled(active_item, "ItemComponent")
	local currently_selected_slot = ComponentGetValue2(active_item_item_comp, "inventory_slot")
	if not active_item then
		currently_selected_slot = 0
	elseif not is_wand(active_item) then
		-- Potions/Items start at 0, so add 4 to get the absolute position of the item in the inventory
		currently_selected_slot = currently_selected_slot + 4
	end
	local change_amount = 0
	for i=currently_selected_slot, currently_selected_slot+8 do
		local slot_to_check = i % 8
		if slot_to_check == new_slot then
			break
		end
		if inventory_slots[slot_to_check+1] then
			change_amount = change_amount + 1
		end
	end
	if not active_item then
		change_amount = change_amount + 1
	end
	scroll_inventory(change_amount)
	-- /Scroll to new item to select it
end

function retrieve_or_swap_wand(wand, tab_number)
	if not tab_number then
		error("Tab number expected", 2)
	end
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
				put_wand_in_storage(active_item, tab_number)
			end
		end
		local first_free_wand_slot = get_first_free_wand_slot()
		-- Make sure we only pick up the wand if either we have a wand selected that we will swap with, or have enough space
		if inventory_slot or first_free_wand_slot then
			create_and_pick_up_wand(wand.serialized_poly, inventory_slot or first_free_wand_slot)
			EntityKill(wand.container_entity_id)
			async(function()
				wait(0)
				wand_storage_changed = true
			end)
		end
	end
end

function retrieve_or_swap_item(item, tab_number)
	if not tab_number then
		error("Tab number expected", 2)
	end
	local inventory = get_inventory()
	local item_storage = EntityGetWithName("item_storage_container")
	if inventory > 0 and item_storage > 0 then
		local active_item = get_active_item()
		local inventory_slot
		if not has_enough_space_for_item() and active_item then
			if not is_item(active_item) then
				return
			else
				-- Swap
				inventory_slot = get_inventory_position(active_item)
				put_item_in_storage(active_item, tab_number)
			end
		end
		local first_free_item_slot = get_first_free_item_slot()
		-- Make sure we only pick up the item if either we have an item selected that we will swap with, or have enough space
		if inventory_slot or first_free_item_slot then
			create_and_pick_up_item(item.serialized_poly, (inventory_slot or first_free_item_slot) + 4)
			EntityKill(item.container_entity_id)
			async(function()
				wait(0)
				item_storage_changed = true
			end)
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

local spell_type_bgs = {
	[ACTION_TYPE_PROJECTILE] = "data/ui_gfx/inventory/item_bg_projectile.png",
	[ACTION_TYPE_STATIC_PROJECTILE] = "data/ui_gfx/inventory/item_bg_static_projectile.png",
	[ACTION_TYPE_MODIFIER] = "data/ui_gfx/inventory/item_bg_modifier.png",
	[ACTION_TYPE_DRAW_MANY] = "data/ui_gfx/inventory/item_bg_draw_many.png",
	[ACTION_TYPE_MATERIAL] = "data/ui_gfx/inventory/item_bg_material.png",
	[ACTION_TYPE_OTHER] = "data/ui_gfx/inventory/item_bg_other.png",
	[ACTION_TYPE_UTILITY] = "data/ui_gfx/inventory/item_bg_utility.png",
	[ACTION_TYPE_PASSIVE] = "data/ui_gfx/inventory/item_bg_passive.png",
}

local function get_spell_bg(action_id)
	return spell_type_bgs[spell_lookup[action_id] and spell_lookup[action_id].type] or spell_type_bgs[ACTION_TYPE_OTHER]
end

function OnPlayerSpawned(player)
	if not spell_lookup then
		spell_lookup = {}
		dofile_once("data/scripts/gun/gun_actions.lua")
		for i, action in ipairs(actions) do
			spell_lookup[action.id] = { 
				icon = action.sprite,
				type = action.type
			}
		end
	end
	local function create_and_add_tab_storage_entities(parent_container_id, num_tabs)
		local first_tab_storage_entity
		for i=1, num_tabs do
			local tab_entity = EntityCreateNew("tab_" .. i)
			if i == 1 then
				first_tab_storage_entity = tab_entity
			end
			EntityAddChild(parent_container_id, tab_entity)
		end
		return first_tab_storage_entity
	end
	local wand_storage = EntityGetWithName("wand_storage_container")
	if wand_storage == 0 then
		wand_storage = EntityCreateNew("wand_storage_container")
		create_and_add_tab_storage_entities(wand_storage, num_tabs)
		EntityAddChild(player, wand_storage)
		GlobalsSetValue("InventoryBags_active_storage_version", storage_version)
	else
		if tonumber(GlobalsGetValue("InventoryBags_active_storage_version", "0")) ~= storage_version then
			local old_wands = EntityGetAllChildren(wand_storage)
			local first_tab_storage_entity = create_and_add_tab_storage_entities(wand_storage, num_tabs)
			-- Child entities are serialized wands
			for i, entity_id in ipairs(old_wands or {}) do
				EntityRemoveFromParent(entity_id)
				EntityAddChild(first_tab_storage_entity, entity_id)
			end
		end
	end
	local item_storage = EntityGetWithName("item_storage_container")
	if item_storage == 0 then
		item_storage = EntityCreateNew("item_storage_container")
		create_and_add_tab_storage_entities(item_storage, num_tabs)
		EntityAddChild(player, item_storage)
	else
		if tonumber(GlobalsGetValue("InventoryBags_active_storage_version", "0")) ~= storage_version then
			GlobalsSetValue("InventoryBags_active_storage_version", storage_version)
			local old_items = EntityGetAllChildren(item_storage)
			local first_tab_storage_entity = create_and_add_tab_storage_entities(item_storage, num_tabs)
			-- Child entities are serialized items
			for i, entity_id in ipairs(old_items or {}) do
				EntityRemoveFromParent(entity_id)
				EntityAddChild(first_tab_storage_entity, entity_id)
			end
		end
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

local tab_labels = {
	wands = {},
	items = {},
}

function load_label_settings()
	for i=1, num_tabs do
		tab_labels.wands[i] = ModSettingGet("InventoryBags.tab_label_wands_" .. i) or ""
		tab_labels.items[i] = ModSettingGet("InventoryBags.tab_label_items_" .. i) or ""
	end
end

load_label_settings()

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
	load_label_settings()
end

local active_wand_tab = 1
local active_item_tab = 1

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
		local stored_wands = get_stored_wands(active_wand_tab)
		local held_items = get_held_items()
		local stored_items = get_stored_items(active_item_tab)
		local rows_wands = math.max(4, math.ceil((#stored_wands + 1) / 4))
		local rows_items = math.max(4, math.ceil((#stored_items + 1) / 4))
		local box_width = slot_width_total * 4
		local box_height_wands = slot_height_total * (rows_wands+1) + spacer
		local box_height_items = slot_height_total * (rows_items+1) + spacer
		-- Render wand bag
		local origin_x, origin_y = 23, 48
		GuiZSetForNextWidget(gui, 20)
		GuiImageNinePiece(gui, new_id(), origin_x, origin_y, box_width, box_height_wands, 1, "mods/InventoryBags/files/container_9piece.png", "mods/InventoryBags/files/container_9piece.png")
		-- Render an invisible image over the whole bag to prevent clicks firing wands
		for offset_y=0, box_height_wands+8, 10 do
			GuiZSetForNextWidget(gui, -99999)
			GuiImage(gui, new_id(), origin_x - 4, origin_y - 4 + offset_y, "mods/InventoryBags/files/invisible_80x10.png", 1, 1, 1)
		end
		-- Render tabs
		for i=1, num_tabs do
			local add_text_offset = 0
			if i == 1 then
				add_text_offset = 1
			end
			-- Left side (Wand tabs)
			GuiZSetForNextWidget(gui, 21)
			local is_active_wand_tab = function() return active_wand_tab == i end
			if GuiImageButton(gui, new_id(), origin_x - 16, origin_y + 5 + (i-1) * 17, "", "mods/InventoryBags/files/tab_left_empty" .. (is_active_wand_tab() and "_active" or "") .. ".png") then
				active_wand_tab = i
				wand_storage_changed = true
			end
			if tab_labels.wands[i] ~= "" then
				GuiTooltip(gui, tab_labels.wands[i], "")
			end
			GuiColorSetForNextWidget(gui, 1, 1, 1, is_active_wand_tab() and 0.8 or 0.5)
			GuiText(gui, origin_x - 10 + add_text_offset, origin_y + 8 + (i-1) * 17, i)
			-- Right side (Item tabs)
			GuiZSetForNextWidget(gui, 21)
			local is_active_item_tab = function() return active_item_tab == i end
			if GuiImageButton(gui, new_id(), origin_x + 157, origin_y + 5 + (i-1) * 17, "", "mods/InventoryBags/files/tab_right_empty" .. (is_active_item_tab() and "_active" or "") .. ".png") then
				active_item_tab = i
				item_storage_changed = true
			end
			if tab_labels.items[i] ~= "" then
				GuiTooltip(gui, tab_labels.items[i], "")
			end
			GuiColorSetForNextWidget(gui, 1, 1, 1, is_active_item_tab() and 0.8 or 0.5)
			GuiText(gui, origin_x + 159 + add_text_offset, origin_y + 8 + (i-1) * 17, i)
		end
		local tooltip_wand
		local taken_slots = {}
		-- Render the held wands and save the taken positions so we can render the empty slots after this
		for i, wand in ipairs(held_wands) do
			if wand then
				taken_slots[wand.inventory_slot] = true
				if GuiImageButton(gui, new_id(), origin_x + slot_margin + wand.inventory_slot * slot_width_total, origin_y + slot_margin, "", "data/ui_gfx/inventory/inventory_box.png") then
					async(function()
						put_wand_in_storage(wand.entity_id, active_wand_tab)
					end)
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
						async(function()
							retrieve_or_swap_wand(wand, active_wand_tab)
						end)
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
		-- Render an invisible image over the whole bag to prevent clicks firing wands
		for offset_y=0, box_height_items+8, 10 do
			GuiZSetForNextWidget(gui, -99999)
			GuiImage(gui, new_id(), origin_x - 4, origin_y - 4 + offset_y, "mods/InventoryBags/files/invisible_80x10.png", 1, 1, 1)
		end
		local tooltip_item
		local taken_slots = {}
		-- Render the held items and save the taken positions so we can render the empty slots after this
		for i, item in ipairs(held_items) do
			if item then
				taken_slots[item.inventory_slot] = true
				if GuiImageButton(gui, new_id(), origin_x + slot_margin + item.inventory_slot * slot_width_total, origin_y + slot_margin, "", "data/ui_gfx/inventory/inventory_box.png") then
					async(function()
						put_item_in_storage(item.entity_id, active_item_tab)
					end)
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
						async(function()
							retrieve_or_swap_item(item, active_item_tab)
						end)
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
			EZWand.RenderTooltip(origin_x + box_width + 30, origin_y + 5, tooltip_wand, gui)
		end
		-- Render a tooltip of the hovered item if we have any
		if tooltip_item then
			GuiBeginAutoBox(gui)
			GuiLayoutBeginHorizontal(gui, origin_x + box_width + 30, origin_y + 5, true)
			GuiLayoutBeginVertical(gui, 0, 0)
			local lines = split_string(tooltip_item, "\n")
			for i, line in ipairs(lines) do
				local offset = line == " " and -7 or 0
				GuiText(gui, 0, offset, line)
			end
			GuiLayoutEnd(gui)
			GuiLayoutEnd(gui)
			GuiZSetForNextWidget(gui, 10)
			GuiEndAutoBoxNinePiece(gui)
		end
	end
end
