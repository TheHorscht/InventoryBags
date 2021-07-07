dofile("data/scripts/lib/mod_settings.lua")

local mod_id = "InventoryBags"
mod_settings_version = 1
mod_settings =
{
	{
		id = "pos_x",
		ui_name = "Horizontal position",
		ui_description = "",
		value_default = 2,
		value_min = 0,
		value_max = 1000,
		value_display_multiplier = 1,
		value_display_formatting = " x = $0",
		scope = MOD_SETTING_SCOPE_RUNTIME,
	},
	{
		id = "pos_y",
		ui_name = "Vertical position",
		ui_description = "",
		value_default = 22,
		value_min = 0,
		value_max = 1000,
		value_display_multiplier = 1,
		value_display_formatting = " y = $0",
		scope = MOD_SETTING_SCOPE_RUNTIME,
	},
	{
		ui_fn = mod_setting_vertical_spacing,
		not_setting = true,
	},
	{
		id = "locked",
		ui_name = "Lock button",
		ui_description = "When unlocked, button can be dragged to a new position",
		value_default = true,
		scope = MOD_SETTING_SCOPE_RUNTIME,
	},
}

function adjust_setting_values(screen_width, screen_height)
	if not screen_width then
		local gui = GuiCreate()
		GuiStartFrame(gui)
		screen_width, screen_height = GuiGetScreenDimensions(gui)
	end
	for i, setting in ipairs(mod_settings) do
		if setting.id == "pos_x" then
			setting.value_max = screen_width
		elseif setting.id == "pos_y" then
			setting.value_max = screen_height
		end
	end
end

local function MigrateWandBagSettingsToInventoryBags()
	ModSettingRemove("WandBag._version")
	for i, setting in ipairs(mod_settings) do
		if not setting.not_setting then
			local setting_id = mod_setting_get_id("WandBag",  setting.id)
			local old_value = ModSettingGet(setting_id)
			ModSettingRemove(setting_id)
			ModSettingSetNextValue(mod_setting_get_id(mod_id, setting.id), old_value, true)
		end
	end
end

function ModSettingsUpdate(init_scope)
	local old_version = mod_settings_get_version(mod_id)
	if ModSettingGet("WandBag._version") == 1 then
		MigrateWandBagSettingsToInventoryBags()
	end
	mod_settings_update(mod_id, mod_settings, init_scope)
end

function ModSettingsGuiCount()
	return mod_settings_gui_count(mod_id, mod_settings)
end

function ModSettingsGui( gui, in_main_menu )
	new_screen_width, new_screen_height = GuiGetScreenDimensions(gui)
	-- Update settings when resolution changes
	if screen_width ~= new_screen_width or screen_height ~= new_screen_height then
		adjust_setting_values(new_screen_width, new_screen_height)
	end
	screen_width = new_screen_width
	screen_height = new_screen_height

	mod_settings_gui( mod_id, mod_settings, gui, in_main_menu )
end
