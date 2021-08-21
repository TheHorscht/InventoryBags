dofile_once("data/scripts/lib/utilities.lua")
dofile_once("data/scripts/gun/gun_actions.lua")
dofile_once("mods/InventoryBags/lib/coroutines.lua")
-- dofile_once("data/scripts/lib/coroutines.lua")
dofile_once("mods/InventoryBags/lib/polytools/polytools_init.lua").init("mods/InventoryBags/lib/polytools")
local polytools = dofile_once("mods/InventoryBags/lib/polytools/polytools.lua")
local nxml = dofile_once("mods/InventoryBags/lib/nxml.lua")
local EZWand = dofile_once("mods/InventoryBags/lib/EZWand.lua")

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

function set_active_item(wand)
	local player = EntityGetWithTag("player_unit")[1]
	if player then
		local inventory2 = EntityGetFirstComponentIncludingDisabled(player, "Inventory2Component")
		ComponentSetValue2(inventory2, "mActiveItem", wand)
		ComponentSetValue2(inventory2, "mActualActiveItem", 0)
		ComponentSetValue2(inventory2, "mForceRefresh", true)
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
					image_file = get_wand_xml_sprite(image_file)
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
					image_file = get_wand_xml_sprite(image_file)
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
				wand.sprite_image_file = get_wand_xml_sprite(wand.sprite_image_file)
			end
			wand.container_entity_id = container_entity_id
			-- if string.len(serialized_poly) < 5 then
			-- 	print("FUCK UP")
			-- end
			wand.serialized_poly = serialized_poly
			serialized_wands[i] = wand
		end
		return serialized_wands
	else
		return {}
	end
end

--[[ 

  <ItemComponent
    _tags="enabled_in_world"
    item_name="$item_potion"
    max_child_items="0"
    is_pickable="1"
    is_equipable_forced="1"
    ui_sprite="data/ui_gfx/items/potion.png"
    ui_description="$item_description_potion"
    preferred_inventory="QUICK"
  ></ItemComponent>

 ]]

function get_stored_items()
	local item_storage = EntityGetWithName("item_storage_container")
	if item_storage > 0 then
		local items = EntityGetAllChildren(item_storage) or {}
		for i, item in ipairs(items) do
			local item_component = EntityGetFirstComponentIncludingDisabled(item, "ItemComponent")
			local image_file = ComponentGetValue2(item_component, "ui_sprite")
			if ends_with(image_file, ".xml") then
				image_file = get_wand_xml_sprite(image_file)
			end
			items[i] = {
				entity_id = item,
				image_file = image_file
			}
		end
		return items
	else
		return {}
	end
end

---Needs to be called from inside an async function. Kills entity and returns the serialized string.
function serialize_entity(entity)
	-- EntitySetName(entity, "to_be_serialized")
	EntitySetTransform(entity, 6666666, 6666666)
	local serialized = polytools.save(entity)
	-- Wait until polymorph wears off so we can kill the entity
	wait(1)
	-- entity = EntityGetWithName("to_be_serialized")
	entity = EntityGetInRadius(6666666, 6666666, 5)[1]
	EntityKill(entity)
	return serialized
end

function deserialize_entity(str)
	local entity = EntityCreateNew()
	EntitySetTransform(entity, 6666666, 6666666)
	-- local entity = EntityCreateNew("to_be_deserialized")
	-- Apply polymorph which, when it runs out after 1 frame will turn the entity back into it's original form, which we provide
	polytools.load(entity, str)
	-- Wait 1 frame for the polymorph to wear off
	wait(0)
	-- Entity should be ready to collect
	-- entity = EntityGetWithName("to_be_deserialized")
	-- EntitySetName(entity, "")
	entity = EntityGetInRadius(6666666, 6666666, 5)[1]
	EntitySetTransform(entity, 5555555, 5555555)
	-- for i, w in ipairs(wands) do
	-- 	EntitySave(w, "xxx" .. i .. ".xml")
	-- end
	-- print(#wands)
	print("SHIIIIIIIIIIIIIIIIT" .. tostring(entity))
	return entity
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

function put_wand_in_storage(wand)
	local player = EntityGetWithTag("player_unit")[1]
	local wand_storage = EntityGetWithName("wand_storage_container")
	if player and wand_storage > 0 then
		async(function()
			-- EntitySetComponentsWithTagEnabled(wand, "enabled_in_world", false)
			-- EntitySetComponentsWithTagEnabled(wand, "enabled_in_hand", false)
			local ez = EZWand(wand):Serialize()
			local poly = serialize_entity(wand)
			local new_entry = create_storage_entity(ez, poly)
			-- print(("Adding (%d) to (%d)"):format(wand_storage, new_entry))
			EntityAddChild(wand_storage, new_entry)
		end)

	-- 	local inventory2 = EntityGetFirstComponentIncludingDisabled(player, "Inventory2Component")
	-- 	local mActiveItem = ComponentGetValue2(inventory2, "mActiveItem")
	-- 	EntityRemoveFromParent(wand)
	-- 	EntityAddChild(wand_storage, wand)
	-- 	if wand == mActiveItem then
	-- 		ComponentSetValue2(inventory2, "mActiveItem", 0)
	-- 	end
	end
end

function put_item_in_storage(item)
	local item_storage = EntityGetWithName("item_storage_container")
	local num_items_stored = #(EntityGetAllChildren(item_storage) or {})
	local player = EntityGetWithTag("player_unit")[1]
	if player and item_storage > 0 then
		local inventory2 = EntityGetFirstComponentIncludingDisabled(player, "Inventory2Component")
		local mActiveItem = ComponentGetValue2(inventory2, "mActiveItem")
		EntityRemoveFromParent(item)
		EntityAddChild(item_storage, item)
		if item == mActiveItem then
			ComponentSetValue2(inventory2, "mActiveItem", 0)
		end
	end
end

function has_enough_space_for_wand()
	return #get_held_wands() < 4
end

function has_enough_space_for_item()
	return #get_held_items() < 4
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

function retrieve_or_swap_wand(wand)
	local inventory = get_inventory()
	local wand_storage = EntityGetWithName("wand_storage_container")
	if inventory > 0 and wand_storage > 0 then
		local active_item = get_active_item()
		local inventory_slot
		print(("active_item (%d)"):format(active_item))
		if not has_enough_space_for_wand() and active_item and is_wand(active_item) then
			-- Swap
			inventory_slot = get_inventory_position(active_item)
			print(("Putting wand (%d) in storage"):format(active_item))
			-- EntityRemoveFromParent(active_item)
			put_wand_in_storage(active_item)
		end
		local first_free_wand_slot = get_first_free_wand_slot()
		-- Make sure we only pick up the wand if either we have a wand selected that we will swap with, or have enough space
		if inventory_slot or first_free_wand_slot then

			async(function()
				local new_wand = deserialize_entity(wand.serialized_poly)
				EntityKill(wand.container_entity_id)
				-- "Pick up" wand and place it in inventory
				local item_comp = EntityGetFirstComponentIncludingDisabled(new_wand, "ItemComponent")
				ComponentSetValue2(item_comp, "is_pickable", true)
				ComponentSetValue2(item_comp, "play_pick_sound", false)
				ComponentSetValue2(item_comp, "next_frame_pickable", 0)
				ComponentSetValue2(item_comp, "npc_next_frame_pickable", 0)
				local new_slot = inventory_slot and inventory_slot or first_free_wand_slot
				set_inventory_position(new_wand, new_slot)
				EntityAddChild(inventory, new_wand)
				-- /"Pick up" wand and place it in inventory

				-- Scroll to new wand to select it
				local player = EntityGetWithTag("player_unit")[1]
				local controls_comp = EntityGetComponentIncludingDisabled(player, "ControlsComponent")[1]
				-- EntitySetComponentIsEnabled(player, controls_comp, false)
				ComponentSetValue2(controls_comp, "enabled", false)
				-- Just to make sure this gets re-enabled even it a bug occurs in the code after this
				async(function()
					wait(0)
					ComponentSetValue2(controls_comp, "enabled", true)
				end)
				local inventory_slots, active_item = get_inventory_and_active_item()
				local active_item_item_comp = EntityGetFirstComponentIncludingDisabled(active_item, "ItemComponent")
				local currently_selected_slot = ComponentGetValue2(active_item_item_comp, "inventory_slot")
				if not is_wand(active_item) then
					currently_selected_slot = currently_selected_slot + 4
				end
				-- Potions/Items start at 0, so add 4 to get the absolute position of the item in the inventory
				-- local inv_count = #get_held_wands() + #get_held_items()
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
				-- print("is_wand(active_item): " .. type(is_wand(active_item)) .. " - " .. tostring(is_wand(active_item)))
				
				-- if inventory_slot_x == nil then
				-- 	change_amount = inv_count
				-- elseif not is_wand(active_item) then
				-- 	inventory_slot_x = inventory_slot_x + 4
				-- end
				-- if inventory_slot_x ~= nil then
				-- 	change_amount = new_slot - inventory_slot_x
				-- 	if change_amount < 0 then
				-- 		-- Occupied: [0][ ][2][ ] [ ][1][ ][3]
				-- 		-- Selected: 				^
				-- 		-- Add wand to 1 ^
				-- 		change_amount = change_amount + inv_count
				-- 	end
				-- end
				print("change_amount: " .. type(change_amount) .. " - " .. tostring(change_amount))
				ComponentSetValue2(controls_comp, "mButtonDownChangeItemR", true)
				ComponentSetValue2(controls_comp, "mButtonFrameChangeItemR", GameGetFrameNum() + 1)
				ComponentSetValue2(controls_comp, "mButtonCountChangeItemR", change_amount)
				-- /Scroll to new wand to select it



				-- wait(0)
					-- print(tostring(get_active_item()))
				-- end
				-- local sprite = EntityGetFirstComponentIncludingDisabled(new_wand, "SpriteComponent", "enabled_in_hand")
				-- if sprite then
				-- 	EntityRefreshSprite(new_wand, sprite)
				-- end






				-- print("inventory: " .. type(inventory) .. " - " .. tostring(inventory))
				-- print("new_wand: " .. type(new_wand) .. " - " .. tostring(new_wand))
				-- print("inventory_slot: " .. type(inventory_slot) .. " - " .. tostring(inventory_slot))
				-- print("first_free_wand_slot: " .. type(first_free_wand_slot) .. " - " .. tostring(first_free_wand_slot))
				-- set_active_item(new_wand)
			end)



		end
	end
end

function retrieve_or_swap_item(item)
	local inventory = get_inventory()
	local item_storage = EntityGetWithName("item_storage_container")
	if inventory > 0 and item_storage > 0 then
		local active_item = get_active_item()
		local inventory_slot
		if not has_enough_space_for_item() and active_item and is_item(active_item) then
			-- Swap
			inventory_slot = get_inventory_position(active_item)
			EntityRemoveFromParent(active_item)
			EntityAddChild(item_storage, active_item)
		end
		local first_free_item_slot = get_first_free_item_slot()
		-- Make sure we only pick up the item if either we have an item selected that we will swap with, or have enough space
		if inventory_slot or first_free_item_slot then
			EntityRemoveFromParent(item)
			EntityAddChild(inventory, item)
			set_active_item(item)
			set_inventory_position(item, inventory_slot and inventory_slot or first_free_item_slot)
		end
	end
end

function retrieve_wand(wand)
	async(function()
		-- Create a new entity that will be reverse-polymorphed into the wand
		local new_wand = EntityCreateNew()
		-- Move it to a location where no other entities are, so we can get a reference to it with EntityGetInRadius
		EntitySetTransform(new_wand, 6666666, 6666666)
		-- Apply polymorph which, when it runs out after 1 frame will turn the entity back into it's original form, which we provide
		polytools.load(new_wand, serialized)
		-- Wait 1 frame for the polymorph to wear off
		wait(0)
		-- Entity should be ready to collect
		new_wand = EntityGetInRadius(6666666, 6666666, 5)[1]
		for i, v in ipairs(EntityGetInRadius(6666666, 6666666, 5)) do
			print("i: " .. i)
		end
		local player = EntityGetWithTag("player_unit")[1]
		GamePickUpInventoryItem(player, new_wand, false)
	end)
end

--[[ 

    async(function()
      EntitySetTransform(wand, 6666666, 6666666)
      EntitySetComponentsWithTagEnabled(wand, "enabled_in_world", true)
      EntitySetComponentsWithTagEnabled(wand, "enabled_in_hand", false)
      serialized = polytools.save(wand)
      wait(0)
      local wand = EntityGetInRadius(6666666, 6666666, 5)[1]
      EntityKill(new_wand)
    end)
  end
  if GuiButton(gui, 3, 10, 210, "HELLO 2") then
    async(function()
      -- Create a new entity that will be reverse-polymorphed into the wand
      local new_wand = EntityCreateNew()
      -- Move it to a location where no other entities are, so we can get a reference to it with EntityGetInRadius
      EntitySetTransform(new_wand, 6666666, 6666666)
      -- Apply polymorph which, when it runs out after 1 frame will turn the entity back into it's original form, which we provide
      polytools.load(new_wand, serialized)
      -- Wait 1 frame for the polymorph to wear off
      wait(0)
      -- Entity should be ready to collect
      new_wand = EntityGetInRadius(6666666, 6666666, 5)[1]
      local player = EntityGetWithTag("player_unit")[1]
      GamePickUpInventoryItem(player, new_wand, false)
    end)

 ]]

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
		for i=1, 4 do
		-- for i=1, 15*4 do
			local wand = EZWand()
			wand.capacity = 26
			wand:AddSpells("BOMB", 26)
			put_wand_in_storage(wand.entity_id)
			-- EntityAddChild(wand_storage, wand.entity_id)
		end
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

	if GuiButton(gui, 55595, 0, 200, "[ Click me :) ]") then
		local inventory, active_item = get_inventory_and_active_item()
		local str = ""
		for i=1, 8 do
			local entity_id = " "
			local border = { "[", "]" }
			if inventory[i] then
				entity_id = inventory[i]
				if inventory[i] == active_item then
					border = { ">", "<" }
				end
			end
			str = ("%s%s%s%s "):format(str, border[1], entity_id, border[2])
		end
		print(str)
	end

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
					GamePrint(wand.entity_id)
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
					tooltip_item = item.entity_id
					GamePrint(item.entity_id)
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
						retrieve_or_swap_item(item.entity_id)
					end
					local _, _, hovered, x, y, width, height = GuiGetPreviousWidgetInfo(gui)
					local w, h = GuiGetImageDimensions(gui, item.image_file, 1)
					local scale = hovered and 1.2 or 1
					if hovered then
						tooltip_item = item.entity_id
					end
					GuiZSetForNextWidget(gui, -10)
					local potion_color = GameGetPotionColorUint(item.entity_id)
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
			-- This runs every frame and is very inefficient, I know, but at least it's accurate, caching without detecting spell/wand changes correctly
			-- could lead to incorrect tooltips
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
			local ability_component = EntityGetFirstComponentIncludingDisabled(tooltip_item, "AbilityComponent")
			local item_component = EntityGetFirstComponentIncludingDisabled(tooltip_item, "ItemComponent")
			local potion_component = EntityGetFirstComponentIncludingDisabled(tooltip_item, "PotionComponent")
			local description = ComponentGetValue2(item_component, "ui_description")
			description = GameTextGetTranslatedOrNot(description)
			description = split_string(description, "\n")
			local lines = {}
			local item_name = ComponentGetValue2(ability_component, "ui_name")
			-- Item name is either stored on AbilityComponent:ui_name or if that doesn't exist, ItemComponent:item_name
			if not item_name then
				item_name = ComponentGetValue2(item_component, "item_name")
			end
			if potion_component then
				local main_material_id = GetMaterialInventoryMainMaterial(tooltip_item)
				local main_material = CellFactory_GetUIName(main_material_id)
				main_material = GameTextGetTranslatedOrNot(main_material)
				local material_inventory_component = EntityGetFirstComponentIncludingDisabled(tooltip_item, "MaterialInventoryComponent")
				local material_sucker_component = EntityGetFirstComponentIncludingDisabled(tooltip_item, "MaterialSuckerComponent")
				local barrel_size = ComponentGetValue2(material_sucker_component, "barrel_size")
				local count_per_material_type = ComponentGetValue2(material_inventory_component, "count_per_material_type")
				local total_amount = 0
				for material_id, amount in pairs(count_per_material_type) do
					if amount > 0 then
						total_amount = total_amount + amount
						local material_name = CellFactory_GetUIName(material_id-1)
						material_name = GameTextGetTranslatedOrNot(material_name)
						table.insert(lines, ("%s (%d)"):format(material_name:gsub("^%l", string.upper), amount))
					end
				end
				local fill_percent = math.ceil((total_amount / barrel_size) * 100)
				item_name = (GameTextGet(item_name, main_material) .. GameTextGet("$item_potion_fullness", fill_percent)):upper()
			else
				item_name = GameTextGetTranslatedOrNot(item_name):upper()
			end
			GuiBeginAutoBox(gui)
			GuiLayoutBeginHorizontal(gui, origin_x + box_width + 20, origin_y + 5, true)
			GuiLayoutBeginVertical(gui, 0, 0)
			GuiText(gui, 0, 0, item_name)
			for i, line in ipairs(description) do
				GuiText(gui, 0, i == 1 and 7 or 0, line)
			end
			for i, line in ipairs(lines) do
				GuiText(gui, 0, i == 1 and 7 or -1, line)
			end
			GuiLayoutEnd(gui)
			GuiLayoutEnd(gui)
			GuiZSetForNextWidget(gui, 10)
			GuiEndAutoBoxNinePiece(gui)
		end
	end
end
