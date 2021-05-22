gui = gui or GuiCreate()
open = open or false
current_id = 1

function new_id()
  current_id = current_id + 1
  return current_id
end

GuiStartFrame(gui)

local offset = 0
if ModIsEnabled("new_enemies") or ModIsEnabled("material_randomizer") then
  offset = 2
end

-- Menu toggle button
GuiLayoutBeginVertical(gui, 59, offset)
if GuiButton(gui, 0, 0, "[The floor is lava]", new_id()) then
  open = not open
end

function add_option(menu, type, name, description)
  assert(type == "enable" or type == "disable")
  table.insert(menu, { mode = type, flag = string.format("matran_%s_%s", type, name), description = description })
end

function add_submenu(menu, description)
  table.insert(menu, { mode = "submenu", description = description, children = { parent = menu } })
  return menu[#menu].children
end

local prefix = "tfilava"

if open then
  GuiLayoutBeginVertical(gui, 0, 0)
  if EntityAddComponent2 then -- checking for beta branch
    -- Can floor burn?
    local checked = HasFlagPersistent(prefix.."_floor_ignites")
    local checkbox = checked and "[x] " or "[ ] "
    if GuiButton(gui, 0, 0, checkbox.."Floor causes burning", new_id()) then
      if checked then
        RemoveFlagPersistent(prefix.."_floor_ignites")
      else
        AddFlagPersistent(prefix.."_floor_ignites")
      end
    end
  end
  -- Easy
  local checked = HasFlagPersistent(prefix.."_difficulty_1")
  local checkbox = checked and "[x] " or "[ ] "
  if GuiButton(gui, 0, 0, checkbox.."Easy", new_id()) then
    if not checked then
      AddFlagPersistent(prefix.."_difficulty_1")
      RemoveFlagPersistent(prefix.."_difficulty_2")
      RemoveFlagPersistent(prefix.."_difficulty_3")
      RemoveFlagPersistent(prefix.."_difficulty_4")
    end
  end
  -- Medium
  local checked = HasFlagPersistent(prefix.."_difficulty_2")
  local checkbox = checked and "[x] " or "[ ] "
  if GuiButton(gui, 0, 0, checkbox.."Medium", new_id()) then
    if not checked then
      RemoveFlagPersistent(prefix.."_difficulty_1")
      AddFlagPersistent(prefix.."_difficulty_2")
      RemoveFlagPersistent(prefix.."_difficulty_3")
      RemoveFlagPersistent(prefix.."_difficulty_4")
    end
  end
  -- Hard
  local checked = HasFlagPersistent(prefix.."_difficulty_3")
  local checkbox = checked and "[x] " or "[ ] "
  if GuiButton(gui, 0, 0, checkbox.."Hard", new_id()) then
    if not checked then
      RemoveFlagPersistent(prefix.."_difficulty_1")
      RemoveFlagPersistent(prefix.."_difficulty_2")
      AddFlagPersistent(prefix.."_difficulty_3")
      RemoveFlagPersistent(prefix.."_difficulty_4")
    end
  end
  -- Very Hard
  local checked = HasFlagPersistent(prefix.."_difficulty_4")
  local checkbox = checked and "[x] " or "[ ] "
  if GuiButton(gui, 0, 0, checkbox.."Very Hard", new_id()) then
    if not checked then
      RemoveFlagPersistent(prefix.."_difficulty_1")
      RemoveFlagPersistent(prefix.."_difficulty_2")
      RemoveFlagPersistent(prefix.."_difficulty_3")
      AddFlagPersistent(prefix.."_difficulty_4")
    end
  end

  GuiLayoutEnd(gui)
end
GuiLayoutEnd(gui)
