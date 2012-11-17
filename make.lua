local format = string.format
function printf(text, ...) print(string.format(text, ...)) end

shell.run("util")

args = { ... }
local start = 1
local skipstore = false
if args[1] == "y" then start = 2; skipstore = true end

local goal = nil
for i=start,# args do
  goal = goal and (goal .. " ")
  goal = (goal or "") .. args[i]
end
if not goal then error("expected parameter: goal item") end
if not knownitem(goal) then error("unknown item: "..goal) end

local items = regenInv()
items.properties = {properties = true, commands = true, prev = true}
items.commands = {}
function getnum(item)
  local cur = items
  while cur do
    if cur[item] then return cur[item] end
    cur = cur.prev
  end
  return 0
end
function setnum(item, num) items[item] = num end
function addcommand(cmd) table.insert(items.commands, cmd) end
function isvalid()
  local cur = items
  local checked = {}
  while cur do
    for k, v in pairs(cur) do if not cur.properties[k] and not checked[k] then
        if v < 0 then return false end
        checked[k] = true
    end end
    cur = cur.prev
  end
  return true
end
function start()
  items = {prev = items, properties = items.properties, commands = {}}
end
function commit()
  assert(items.prev)
  for k, v in pairs(items) do if not items.properties[k] then
      items.prev[k] = v
  end end
  for i,k in ipairs(items.commands) do
    table.insert(items.prev.commands, k)
  end
  items = items.prev
end
function rollback()
  items = items.prev
end

local itemdata = readrecipes()

function planfab_item(item, skipstore)
  local rec = recipe(item, itemdata)
  if not rec then error("missing recipe for "..item) end
  return planfab(rec, skipstore)
end

function planfab(rec, skipstore)
  function fetch(count, item)
    if getnum(item) < count then
      local subrec = recipe(item, itemdata)
      if subrec then
        while getnum(item) < count do planfab_item(item) end
      end
    end
    return function()
      addcommand({type = "fetch", count = count, item = item})
      setnum(item, getnum(item) - count)
      addcommand({type = "deposit", to = "-1"})
    end
  end
  
  -- if the recipe has any aliased blocks, then
  local hasaliased = false
  for i,k in ipairs(rec.shape.list) do
    if itemdata[k].mode == "alias" then hasaliased = true end
  end
  if hasaliased then
    rec_copy = dup(rec)
    rec_copy.shape = dup(rec_copy.shape)
    rec_copy.shape.list = dup(rec_copy.shape.list) -- will be substituted
    function recurse()
      local toreplace = nil
      local data = nil
      for i,k in ipairs(rec_copy.shape.list) do if not toreplace then
        data = itemdata[k]
        if data.mode == "alias" then
          toreplace = i
        end
      end end
      if toreplace then
        for i,target in ipairs(data.targets) do
          rec_copy.shape.list[toreplace] = target
          if (recurse()) then return true end
        end
        return false
      else
        -- substitution complete - try new plan
        start()
        planfab(rec_copy)
        if (isvalid()) then
          commit()
          return true
        else
          rollback()
        end
      end
      printf("fail")
      return false -- no match found
    end
    if recurse() then return true
    else
      error(format("Unable to find enough source material for aliases in  '%s'", rec.item))
    end
  end
  function store(item, count)
    addcommand({type = "store", item = item, count = count})
    setnum(item, getnum(item) + count)
  end
  function craft(recipe)
    addcommand({type = "craft", recipe = recipe})
  end
  -- delay our fetches until prelims are done!
  local fetchs = nil
  for i,k in ipairs(rec.shape.list) do
    local v = rec.needed[i]; assert(v)
    local res = fetch(v, k)
    if res then
      if fetchs then
        local prev_fetchs = fetchs
        fetchs = function() prev_fetchs(); res() end
      else fetchs = res
      end
    end
  end
  fetchs()
  craft(rec)
  if not skipstore then store(rec.item, rec.count) end
end

planfab_item(goal, skipstore)
assert(not items.prev) -- make sure items list is closed

local missing = false
for k,v in pairs(items) do if not items.properties[k] then
    if v < 0 then
      printf("insufficient '%s': short %i", k, -v)
      missing = true
    end
end end
assert(not missing)

data = ""
for i, v in ipairs(items.commands) do
  if data:len() then data = data..", " end
  if v.type == "craft" then
    data = data..format("craft %s", v.recipe.item)
  elseif v.type == "fetch" then
    data = data..format("fetch %i %s", v.count, v.item)
  elseif v.type == "deposit" then
    data = data..format("deposit to %s", v.to)
  elseif v.type == "store" then
    data = data..format("store %i %s", v.count, v.item)
  else data = data..v.type
  end
end

-- print(data)

for i,v in ipairs(items.commands) do
  if v.type == "deposit" then
    assert(shell.run("navigate", v.to))
    turtle.select(15)
    assert(turtle.drop())
  elseif v.type == "fetch" then
    -- printf("retrieve %i %s", v.count, v.item)
    assert(shell.run("retrieve", format("%i", v.count), format("%s", v.item)))
  elseif v.type == "store" then
    assert(shell.run("store", "yes", format("%s", v.item)))
  elseif v.type == "craft" then
    local rec = v.recipe
    for i,item in ipairs(rec.shape.list) do
      local from  = rec.firstspot[i]
      turtle.select(from)
      turtle.suck()
      for i, field in ipairs(rec.nextspots[i]) do
        turtle.transferTo(field, 1)
      end
    end
    turtle.select(16)
    assert(turtle.drop()) -- drop fuel
    if not turtle.craft() then
      turtle.select(16)
      turtle.suck()
      error(format("could not craft %s: invalid recipe? ", goal))
    end
    turtle.select(16)
    -- turtle.transferTo(1, rec.count)
    turtle.transferTo(15, rec.count)
    assert(turtle.suck())
  end
end
