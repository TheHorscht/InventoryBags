dofile_once("data/scripts/lib/utilities.lua")
dofile_once("data/scripts/lib/utilities.lua")
dofile_once("data/scripts/gun/gun_actions.lua")
local nxml = dofile_once("mods/WandBag/lib/nxml.lua")
local EZWand = dofile_once("mods/WandBag/lib/EZWand.lua")

local rows = 4

local spell_icon_lookup = {}
for i, action in ipairs(actions) do
	spell_icon_lookup[action.id] = action.sprite
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
	return EntityGetFirstComponentIncludingDisabled(entity, "ManaReloaderComponent")
end

function get_held_wands()
	local inventory = EntityGetWithName("inventory_quick")
	if inventory > 0 then
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
	local num_wands_stored = #(EntityGetAllChildren(wand_storage) or {})
	if num_wands_stored >= rows * 4 then GamePrint("Wand bag is full") return end
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
		local active_item = get_active_item()
		local inventory_slot
		if not has_enough_space_for_wand() and active_item and is_wand(active_item) then
			-- Swap
			inventory_slot = get_inventory_position(active_item)
			EntityRemoveFromParent(active_item)
			EntityAddChild(wand_storage, active_item)
		end
		local first_free_wand_slot = get_first_free_wand_slot()
		-- Make sure we only pick up the wand if either we have a wand selected that we will swap with, or have enough space
		if inventory_slot or first_free_wand_slot then
			EntityRemoveFromParent(wand)
			EntityAddChild(inventory, wand)
			set_active_item(wand)
			set_inventory_position(wand, inventory_slot and inventory_slot or first_free_wand_slot)
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

function is_inventory_open()
	local player = EntityGetWithTag("player_unit")[1]
	if player then
		local inventory_gui_component = EntityGetFirstComponentIncludingDisabled(player, "InventoryGuiComponent")
		if inventory_gui_component then
			return ComponentGetValue2(inventory_gui_component, "mActive")
		end
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
	GuiOptionsAdd(gui, GUI_OPTION.NoPositionTween)
	local inventory_open = is_inventory_open()
	if not inventory_open and GuiImageButton(gui, new_id(), 2, 22, "", "mods/WandBag/files/gui_button.png") then
		open = not open
	end
	if open and not inventory_open then
		local slot_width, slot_height = 16, 16
		local slot_margin = 1
		local slot_width_total, slot_height_total = (slot_width + slot_margin * 2), (slot_height + slot_margin * 2)
		local spacer = 4
		local box_width, box_height = slot_width_total * 4, slot_height_total * (rows+1) + spacer
		local origin_x, origin_y = 23, 48
		GuiZSetForNextWidget(gui, 20)
		GuiImageNinePiece(gui, new_id(), origin_x, origin_y, box_width, box_height, 1, "mods/WandBag/files/container_9piece.png", "mods/WandBag/files/container_9piece.png")
		local tooltip_wand
		local held_wands = get_held_wands()
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
					tooltip_wand = wand.entity_id
				end
				GuiZSetForNextWidget(gui, -9)
				if wand.active then
					GuiImage(gui, new_id(), x + (width / 2 - (16 * scale) / 2), y + (height / 2 - (16 * scale) / 2), "mods/WandBag/files/highlight_box.png", 1, scale, scale)
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
		local stored_wands = get_stored_wands()
		for iy=0, (rows-1) do
			for ix=0, (4-1) do
				local wand = stored_wands[(iy*4 + ix) + 1]
				if wand then
					if GuiImageButton(gui, new_id(), origin_x + slot_margin + ix * slot_width_total, origin_y + spacer + slot_margin + slot_height_total + iy * slot_height_total, "", "data/ui_gfx/inventory/inventory_box.png") then
						retrieve_or_swap_wand(wand.entity_id)
					end
					local _, _, hovered, x, y, width, height = GuiGetPreviousWidgetInfo(gui)
					local w, h = GuiGetImageDimensions(gui, wand.image_file, 1) -- scale
					local scale = hovered and 1.2 or 1
					if hovered then
						tooltip_wand = wand.entity_id
					end
					GuiZSetForNextWidget(gui, -10)
					GuiImage(gui, new_id(), x + (width / 2 - (w * scale) / 2), y + (height / 2 - (h *scale) / 2), wand.image_file, 1, scale, scale, 0, GUI_RECT_ANIMATION_PLAYBACK.Loop)
				else
					GuiImage(gui, new_id(), origin_x + slot_margin + ix * slot_width_total, origin_y + spacer + slot_margin + slot_height_total + iy * slot_height_total, "data/ui_gfx/inventory/inventory_box.png", 1, 1, 1)
				end
			end
		end
		-- Render a tooltip of the hovered wand if we have any
		if tooltip_wand then
			local wand = EZWand(tooltip_wand)
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
			GuiText(gui, 0, 5, GameTextGetTranslatedOrNot(wand.shuffle and "$menu_yes" or "$menu_no"))
			GuiText(gui, 0, margin, string.format("%.0f", wand.spellsPerCast))
			GuiText(gui, 0, margin, string.format("%.2f s", wand.castDelay / 60))
			GuiText(gui, 0, margin, string.format("%.2f s", wand.rechargeTime / 60))
			GuiText(gui, 0, margin, string.format("%.0f", wand.manaMax))
			GuiText(gui, 0, margin, string.format("%.0f", wand.manaChargeSpeed))
			GuiText(gui, 0, margin, string.format("%.0f", wand.capacity))
			GuiText(gui, 0, margin, string.format("%.1f DEG", wand.spread))
			GuiLayoutEnd(gui)
			GuiLayoutEnd(gui)
			local spells = wand:GetSpells()
			GuiLayoutBeginHorizontal(gui, spread_icon_x, spread_icon_y + spread_icon_height + 3, true)
			local row = 0
			local spell_icon_scale = 0.75
			for i, spell in ipairs(spells) do
				GuiZSetForNextWidget(gui, 9)
				GuiImage(gui, new_id(), 0, 0, "data/ui_gfx/inventory/inventory_box.png", 1, spell_icon_scale, spell_icon_scale)
				local _, _, _, x, y = GuiGetPreviousWidgetInfo(gui)
				GuiZSetForNextWidget(gui, 8)
				GuiOptionsAddForNextWidget(gui, GUI_OPTION.Layout_NoLayouting)
				GuiImage(gui, new_id(), x, y, spell_icon_lookup[spell.action_id], 1, spell_icon_scale, spell_icon_scale)
				-- Start a new row after 10 spells
				if i % 10 == 0 then
					row = row + 1
					GuiLayoutEnd(gui)
					GuiLayoutBeginHorizontal(gui, spread_icon_x, spread_icon_y + spread_icon_height + 3 + row * 20 * spell_icon_scale, true)
				end
			end
			GuiLayoutEnd(gui)
			GuiZSetForNextWidget(gui, 10)
			GuiEndAutoBoxNinePiece(gui)
		end
	end
end
