local entity_id = GetUpdatedEntityID()
local x, y = EntityGetTransform(entity_id)
print(("x(%s), y(%s)"):format(x, y))

local id = GetUpdatedComponentID()
local mTimesExecuted = ComponentGetValue2(id, "mTimesExecuted")
print("mTimesExecuted: " .. tostring(mTimesExecuted))
