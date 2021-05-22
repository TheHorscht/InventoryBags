local prefix = "tfilava"

function is_first_time_running()
	local flag1 = HasFlagPersistent(prefix.."_difficulty_1")
	local flag2 = HasFlagPersistent(prefix.."_difficulty_2")
	local flag3 = HasFlagPersistent(prefix.."_difficulty_3")
	local flag4 = HasFlagPersistent(prefix.."_difficulty_4")
	if not (flag1 or flag2 or flag3 or flag4) then
		return true
	end
	return false
end

if is_first_time_running() or HasFlagPersistent(prefix.."_floor_ignites") then
	ModLuaFileAppend("data/scripts/biomes/rainforest.lua", "mods/TheFloorIsLava/files/rainforest_append.lua")
end
ModMagicNumbersFileAdd("mods/TheFloorIsLava/files/magic_numbers.xml")


function set_materials_that_damage(entity_id, materials)
  local damage_model_component = EntityGetFirstComponent(entity_id, "DamageModelComponent")
  if damage_model_component ~= nil then
    -- Store all old values
    local old_values = {}
    local old_damage_multipliers = {}
    for k,v in pairs(ComponentGetMembers(damage_model_component)) do
      if k == "ragdoll_fx_forced" then
        v = ComponentGetValue2(damage_model_component, k)
      end
      old_values[k] = v
    end
    for k,_ in pairs(ComponentObjectGetMembers(damage_model_component, "damage_multipliers")) do
      old_damage_multipliers[k] = ComponentObjectGetValue(damage_model_component, "damage_multipliers", k)
    end

    -- Build comma separated string
    old_values.materials_that_damage = ""
    old_values.materials_how_much_damage = ""
    for material, damage in pairs(materials) do
      local comma = old_values.materials_that_damage == "" and "" or ","
      old_values.materials_that_damage = old_values.materials_that_damage .. comma .. material
      old_values.materials_how_much_damage = old_values.materials_how_much_damage .. comma .. damage
    end

    EntityRemoveComponent(entity_id, damage_model_component)
    damage_model_component = EntityAddComponent(entity_id, "DamageModelComponent", old_values)

    ComponentSetValue2(damage_model_component, "ragdoll_fx_forced", old_values.ragdoll_fx_forced)

    for k, v in pairs(old_damage_multipliers) do
      ComponentObjectSetValue(damage_model_component, "damage_multipliers", k, v)
    end
  end
end

local floor_materials = dofile_once("mods/TheFloorIsLava/files/floor_materials.lua")
local EZWand = dofile_once("mods/TheFloorIsLava/lib/EZWand.lua")

function get_difficulty()
	if HasFlagPersistent(prefix.."_difficulty_1") then
		return 1
	elseif HasFlagPersistent(prefix.."_difficulty_2") then
		return 2
	elseif HasFlagPersistent(prefix.."_difficulty_3") then
		return 3
	elseif HasFlagPersistent(prefix.."_difficulty_4") then
		return 4
	end
end

-- local testForBetaFunc = ModTextFileGetContent

function OnPlayerSpawned(player)
	-- if testForBetaFunc then
	-- 	GameAddFlagRun("is_beta_branch")
	-- end
	local materials_that_damage = {}
	local difficulty = get_difficulty()
	local damage_amounts = { 0.0005, 0.002, 0.005, 0.01}
	local floor_damage = damage_amounts[difficulty] --0.005
	for i, material in ipairs(floor_materials) do
		materials_that_damage[material] = floor_damage
	end

	local wand = EZWand{
		shuffle = 1,
		spellsPerCast = 1,
		castDelay = 300,
		rechargeTime = 300,
		manaMax = 100,
		mana = 100,
		manaChargeSpeed = 20,
		capacity = 3,
		spread = 0,
	}
	wand:AddSpells("SUMMON_ROCK", "SUMMON_ROCK", "SUMMON_ROCK")
	wand:PutInPlayersInventory()

	set_materials_that_damage(player, materials_that_damage)
	if not old_pixel_gravity then
		local character_platforming_component = EntityGetFirstComponent(player, "CharacterPlatformingComponent")
		old_pixel_gravity = ComponentGetValue2(character_platforming_component, "pixel_gravity")
		ComponentSetValue2(character_platforming_component, "pixel_gravity", 0)
	end
end

function OnWorldPreUpdate()
	if GameGetFrameNum() == 20 then
		LoadPixelScene("data/biome_impl/wand_altar.png", "data/biome_impl/wand_altar_visual.png", 216, -95, "", true )
		local player = EntityGetWithTag("player_unit")[1]
		local character_platforming_component = EntityGetFirstComponent(player, "CharacterPlatformingComponent")
		ComponentSetValue2(character_platforming_component, "pixel_gravity", old_pixel_gravity)
	end
	dofile("mods/TheFloorIsLava/files/gui.lua")
end

function OnModInit()
	if is_first_time_running() then
		print("The floor is lava first time running, setting default config.")
		AddFlagPersistent(prefix.."_difficulty_2")
		if EntityAddComponent2 then
			AddFlagPersistent(prefix.."_floor_ignites")
		end
	end
	if ModTextFileGetContent and HasFlagPersistent(prefix.."_floor_ignites") then
		dofile("mods/TheFloorIsLava/files/modify_materials.lua")
	end
end
