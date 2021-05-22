--[[ 
  In case you're reading this and wondering what the whole "if not EntityCreateNew then" is for,
  i'm running it externally using a luajit executable in a different environment, so I need to
  adapt the file paths for that. To determine wether it's running in noita or not,
  I'm checking if the EntityCreateNew function exists.
]]

-- Only used for developing using an external luajit.exe
local noita_path = "C:/Program Files (x86)/Steam/steamapps/common/Noita/"
local data_wak = noita_path .. "data/data.wak"
local output_file = "materials_new.xml"
local floor_materials
local xml2lua
if not EntityCreateNew then
  xml2lua = dofile(noita_path .. "mods/TheFloorIsLava/lib/xml2lua.lua")
  floor_materials = dofile("files/floor_materials.lua")
else
  xml2lua = dofile("mods/TheFloorIsLava/lib/xml2lua.lua")
  floor_materials = dofile_once("mods/TheFloorIsLava/files/floor_materials.lua")
end
local handler
if not EntityCreateNew then
  local wak = dofile("lib/wak.lua")
  local ar = wak.open(data_wak)
  local materials_file = ar:open("data/materials.xml")
  local materials_xml = materials_file:read() 
  handler = xml2lua.parse(materials_xml)

  function HasFlagPersistent(flag)
    return ({
    })[flag]
  end
else
  local xml = ModTextFileGetContent("data/materials.xml")
  handler = xml2lua.parse(xml)
end

function parse_tags(tags)
  local output = {}
  if tags == nil then
    return output
  end
  local a = string.gmatch(tags, "%[([%w_]+)%]")
  for i in a do
    output[i] = true
  end
  return output
end

function material_get_type(element)
  local a = element._attr
  if a.cell_type == "liquid" and (a.liquid_sand == nil or a.liquid_sand == "0") then
    return "liquid"
  elseif a.cell_type == "liquid" and a.liquid_sand == "1"
         and (a.liquid_static == nil or a.liquid_static == "0")
         and (a.liquid_sticks_to_ceiling == nil or a.liquid_sticks_to_ceiling == "0") then
    return "sand"
  elseif a.cell_type == "solid" then
    -- Used for physics stuff and pixel scenes etc
    return "solid"
  elseif (a.cell_type == "solid" and a.solid_break_to_type ~= nil) or a.convert_to_box2d_material then
    return "breakable"
  elseif a.cell_type == "liquid" and a.liquid_sand == "1" then
    -- Used by the world by wang generator and biomes
    return "ground"
  elseif a.cell_type == "fire" then
    return "fire"
  elseif a.cell_type == "gas" then
    return "gas"
  end
  return "unknown"
end

function table.contains(t, element)
  for i, v in ipairs(t) do
    if v == element then
      return true
    end
  end
  return false
end


-- First loop, collect all materials and textures
local safe_materials = {}
for i, p in pairs(handler.root.Materials) do
  if i == "CellDataChild" or i == "CellData" then
    for i2, p2 in pairs(handler.root.Materials[i]) do
      local name = p2._attr.name      
      if p2._attr.name == "templebrick_static" or p2._attr.name == "templebrick_noedge_static" then
        p2._attr.always_ignites_damagemodel = "0"
      end
      if table.contains(floor_materials, name) then
        -- p2.Graphics = {
        --   _attr = {
        --     color = "0xFFFF0000"
        --   }
        -- }
        p2._attr.always_ignites_damagemodel = "1"
        -- p2.ParticleEffect = {
        --   _attr = {
        --     ["vel.y"] = "-8.14",
        --     ["vel_random.min_x"] = "-11.71",
        --     ["vel_random.max_x"] = "11.71",
        --     ["vel_random.min_y"] = "-17.18",
        --     ["vel_random.max_y"] = "-2.8",
        --     ["lifetime.min"] = "0.9",
        --     ["lifetime.max"] = "1.6",
        --     ["gravity.y"] = "-60",
        --     ["render_on_grid"] = "1",
        --     ["airflow_force"] = "0.6314",
        --     ["airflow_scale"] = "0.1371",
        --     ["friction"] = "0.0002",
        --     ["probability"] = "0.3003",
        --     ["count.min"] = "1",
        --     ["count.max"] = "1",
        --   }
        -- }
      end
    end
  end
end






if not EntityCreateNew then
  local f = assert(io.open(output_file, "w"))
  f:write(xml2lua.toXml(handler.root, "Materials", 0))
  f:close()
else
  ModTextFileSetContent("data/materials.xml", xml2lua.toXml(handler.root, "Materials", 0))
end
