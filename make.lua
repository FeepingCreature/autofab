local format = string.format
function printf(text, ...) print(string.format(text, ...)) end

shell.run("util")

args = { ... }
local start = 1

local planmode = false
if args[start] == "_plan" then planmode = true; start = start + 1
elseif args[start] == "_paste" then planmode = "paste"; start = start + 1 end

local skipstore = false
if args[start] == "y" then skipstore = true; start = start + 1 end

local goal = nil
for i=start,# args do
  goal = goal and (goal .. " ")
  goal = (goal or "") .. args[i]
end
if not goal then error("expected parameter: goal item") end

local goallist = nil
if goal:find(",") then
  goallist = ssplit(goal, ",")
end

if goallist then
  for i, item in ipairs(goallist) do
    local toreturn = nil
    toreturn, item = countit(item)
    if not knownitem(item) then error("unknown item: "..item..didyoumean(item)) end
  end
else
  local toreturn = nil
  local item = goal
  toreturn, item = countit(item)
  if not knownitem(item) then error("unknown item: "..item..didyoumean(item)) end
end

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

function addcommand(cmd)
  -- printf("add to %i", #items.commands)
  -- printbacktrace()
  table.insert(items.commands, cmd)
end
function foritems(fun)
  local cur = items
  local checked = {}
  while cur do
    for k, v in pairs(cur) do if not cur.properties[k] and not checked[k] then
        local res = fun(k, v)
        if nil ~= res then return res end
        checked[k] = true
    end end
    cur = cur.prev
  end
end
function fortopitems(fun)
  for k, v in pairs(items) do if not items.properties[k] then
      local res = fun(k, v)
      if nil ~= res then return res end
  end end
end

function withpopped(f)
  local backup = items
  items = items.prev
  local res = f()
  items = backup
  return res
end

function isvalid()
  local res = foritems(function(k, v) if v < 0 then return false end end)
  if nil ~= res then return res end
  return true
end

function topisvalid()
  local res = fortopitems(function(k, v) if v < 0 then return false end end)
  if nil ~= res then return res end
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

debugme = false

function resolve(top)
  local forall = foritems
  if top then forall = fortopitems end
  local fun = nil
  local function addfront(f)
    assert(f)
    if not fun then
      fun = f
    else
      fun = combine(f, fun)
    end
  end
  -- resolve crafts
  local function resolvecrafts()
    local todo = {}
    forall(function(k, v)
      if v < 0 and recipe(k, itemdata) then
        if debugme and not k:find("wood") then printf("craft todo %s", k) end
        table.insert(todo, k)
      end
    end)
    local changed = false
    for i,v in ipairs(todo) do changed = true
      while getnum(v) < 0 do
        if debugme and not v:find("wood") then printf("craft resolve %s (%i)", v, getnum(v)) end
        addfront(mkcraft(recipe(v, itemdata)))
      end
    end
    return changed
  end
  --resolve generic machine ops
  local function resolvemachines()
    local todo = {}
    forall(function(k, v)
      -- if v < 0 then printf("%s? %s", k, tostring(itemdata[k].mode)) end
      if v < 0 and itemdata[k] and itemdata[k].mode == "machine" then
        table.insert(todo, k)
      end
    end)
    local changed = false
    for i,v in ipairs(todo) do changed = true
      while getnum(v) < 0 do
        if debugme then printf("machine resolve %s (%i)", v, getnum(v)) end
        addfront(mkmachine(v))
      end
    end
    return changed
  end
  local running = true
  while running do
    running = false
    while resolvecrafts() do running = true end
    while resolvemachines() do running = true end
  end
  if not fun then fun = function() end end
  return fun
end

function store(count, item)
  setnum(item, getnum(item) + count)
  addcommand({type = "store", count = count, item = item})
end

function mkfetch(count, item, at)
  -- if at then printf("fetch %s %s (%s) to %s", tostring(count), item, tostring(getnum(item)), at)
  -- else printf("fetch %s %s (%s)", tostring(count), item, tostring(getnum(item))) end
  setnum(item, getnum(item) - count) -- mark as claimed!
  return function()
    addcommand({type = "fetch", count = count, item = item})
    if at then addcommand({type = "deposit", count = count, item = item, at = at}) end
  end
end

function mkmachine(item)
  local info = itemdata[item]
  assert(info and info.mode == "machine")
  local fun = nil
  for i, inputdata in ipairs(info.input) do
    fun = combine(fun, mkfetch(inputdata.count, inputdata.item, inputdata.at))
  end
  for i, outputdata in ipairs(info.output) do
    setnum(outputdata.item, getnum(outputdata.item) + outputdata.count)
  end
  return combine(fun, function()
    for i, outputdata in ipairs(info.output) do
      addcommand({type = "pickup",
        count = outputdata.count,
        item  = outputdata.item,
        at    = outputdata.at,
        -- machinestate = {item = info.input[#info.input].item, load = info.input[#info.input].count}
      })
      addcommand({type = "store" , count = outputdata.count, item = outputdata.item})
    end
  end)
end

function printmissing(tostring, top)
  local res = ""
  local cur = items
  local checked = {}
  local forall = foritems
  if top then forall = fortopitems end
  forall(function(k, v)
    if v < 0 then
      if tostring then res = res..string.format("insufficient '%s': short %i\n", k, -v)
      else printf("insufficient '%s': short %i", k, -v) end
    end
  end)
  if tostring then return res end
end

function mkcraft(rec)
  -- if the recipe has any aliased blocks, then
  local hasaliased = false
  for i,k in ipairs(rec.shape.list) do
    if itemdata[k].mode == "alias" then hasaliased = true end
  end
  -- printf("execute recipe %s to create %i", rec.item, -getnum(rec.item))
  if hasaliased then
    local rec_copy = dup(rec)
    rec_copy.shape = dup(rec_copy.shape)
    rec_copy.shape.list = dup(rec_copy.shape.list) -- will be substituted
    local function recurse()
      local toreplace = nil
      local data = nil
      for i,k in ipairs(rec_copy.shape.list) do if not toreplace then
        data = itemdata[k]
        if data.mode == "alias" then
          toreplace = i
        end
      end end
      -- if we've had to resort to recording a fetch for the pre-alias name before
      -- then that means we can skip the lookup - if it's failed before, it's gonna
      -- fail now.
      if getnum(rec_copy.shape.list[toreplace]) < 0 then return nil end
      if toreplace then
        for i,target in ipairs(data.targets) do
          start()
          -- printf("try to substitute %s with %s - %s", rec.shape.list[toreplace], target, tostring(topisvalid()))
          setnum(target, getnum(target) - rec.needed[toreplace]) -- speculatively subtract
          resolve(true)()
          local ival = topisvalid()
          -- printf("outcome: %s", tostring(ival))
          -- printmissing(nil, true)
          rollback()
          if ival then
            rec_copy.shape.list[toreplace] = target
            local res = recurse()
            -- if nil ~= res then return res end
            return res
          end
        end
        return nil
      else
        -- substitution complete - try new plan
        start()
        local res = mkcraft(rec_copy)
        -- local temp = getnum(rec_copy.item) -- backup
        setnum(rec_copy.item, 0) -- make sure the resolve/topisvalid doesn't trip over this
        -- debugme = true
        resolve(true)()
        -- debugme = false
        if (topisvalid()) then
          -- don't! this will apply the resolve(true)()d changes -
          -- leave them for later so they bunch up better.
          -- setnum(rec_copy.item, temp) -- restore
          -- commit()
          -- return res
          -- instead, back off and recraft on the main set
          rollback()
          return mkcraft(rec_copy)
        else
          -- printf("substitution/resolution did not produce a valid top set")
          -- printmissing(nil, true)
          -- assert(false)
          rollback()
        end
      end
      return nil -- no match found
    end
    local res = recurse()
    if nil ~= res then
      -- printf("for %s: ", rec.item)
      -- printf("num stix=%i planx=%i oax=%i sprux=%i", getnum("sticks"), getnum("wood planks"), getnum("oak wood"), getnum("spruce wood"))
      -- print(res)
      return res
    else
      -- let's just pretend it's items .. the latter claim code will
      -- subtract what we wanted so it shows up under missing
      -- printf("Unable to find enough source material for aliases in '%s'", rec.item)
    end
  end
  -- delay our fetchs until prelims are done!
  local fetchs = nil
  for i,k in ipairs(rec.shape.list) do
    -- printf("%i rec? %s to %s", i, rec.item, k)
    local v = rec.needed[i]; assert(v)
    local res = mkfetch(v, k, "craftchest")
    if nil == res then return nil end
    if fetchs then
      local prev_fetchs = fetchs
      fetchs = function() prev_fetchs(); res() end
    else fetchs = res end
  end
  setnum(rec.item, getnum(rec.item) + rec.count)
  return combine(fetchs, function()
    addcommand({type = "craft", recipe = rec, count = 1})
    addcommand({type = "store", count = rec.count, item = rec.item})
  end)
end

function produce(item, num, tolerant)
  local f = mkfetch(num, item)
  resolve()()
  if not isvalid() then
    if tolerant then return end
    printf("could not produce %i '%s' (unknown error)", num, item)
    printmissing(nil)
    assert(false)
  end
  f()
  store(num, item)
end

-- maketracing("mkfetch")
-- maketracing("mkcraft")
-- maketracing("mkmachine")
-- maketracing("produce")
-- maketracing("resolve")
-- maketracing("store")

if goallist then -- making an item list
  
  local fetches = nil
  for i, item in ipairs(goallist) do
    local toreturn = nil
    toreturn, item = countit(item)
    
    if getnum(item) < toreturn then
      -- produce(item, toreturn)
      local f = mkfetch(toreturn, item)
      fetches = combine(fetches, function()
        f()
        store(toreturn, item)
      end)
    end
  end
  resolve()()
  if not isvalid() then
    printf("could not resolve items (unknown error)")
    printmissing(nil, true)
    assert(false)
  end
  if fetches then fetches() end
  assert(not items.prev)
  
else
  
  local toreturn = nil
  local item = goal
  toreturn, item = countit(item)

  if getnum(item) < toreturn then
    produce(item, toreturn)
    assert(not items.prev) -- make sure items list is closed
  end
end

if not planmode and not isvalid() then
  printmissing()
  assert(false)
end -- otherwise print it later

if goallist then
  assert(#goallist <= 15) -- more can't fit in our inv
  if skipstore then
    for i, item in ipairs(goallist) do
      local toreturn = nil
      toreturn, item = countit(item)
      
      -- stuff them in the (now empty) craft chest
      addcommand({type = "fetch", count = toreturn, item = item})
      addcommand({type = "deposit", count = toreturn, item = item, at = "craftchest"})
    end
    addcommand({type = "suckall"})
  end
else
  local toreturn = nil
  local item = goal
  toreturn, item = countit(item)
  
  if skipstore then -- optimizer will remove the redundant store
    addcommand({type = "fetch", count = toreturn, item = item})
  end
end

-- now produced via function to reduce copypaste
function gencraftmergerule(num_inputs)
  local res = {}
  res.types = {}
  -- first set
  for i=1,num_inputs do table.insert(res.types, "fetch"); table.insert(res.types, "deposit") end
  table.insert(res.types, "craft"); table.insert(res.types, "store")
  -- second set
  for i=1,num_inputs do table.insert(res.types, "fetch"); table.insert(res.types, "deposit") end
  table.insert(res.types, "craft"); table.insert(res.types, "store")
  
  res.subst = function(...)
    local args = { ... }
    local halfpoint = num_inputs*2+2
    assert(#args == halfpoint*2)
    
    local c1 = args[num_inputs*2+1]; local c2 = args[num_inputs*2+1 + halfpoint]
    local s1 = args[num_inputs*2+2]; local s2 = args[num_inputs*2+2 + halfpoint]
    assert(c1.type == "craft" and c2.type == "craft" and s1.type == "store" and s2.type == "store")
    if s1.item ~= s2.item or c1.item ~= c2.item or s1.count + s2.count > (itemdata[s1.item].stacksize or -1) then return nil end
    
    local res = {}
    for i=1,num_inputs do
      local f1 = args[i*2-1]
      local f2 = args[i*2-1 + halfpoint]; assert(f2.type == "fetch")
      if f1.item ~= f2.item then return nil end
      
      if f1.count + f2.count > (itemdata[f1.item].stacksize or -1) then return nil end
      
      local d1 = args[i*2]
      local d2 = args[i*2 + halfpoint]; assert(d2.type == "deposit")
      if d1.at ~= d2.at then return nil end
      
      table.insert(res, {type = "fetch",   item = f1.item, count = f1.count + f2.count})
      table.insert(res, {type = "deposit", item = d1.item, count = d1.count + d2.count, at = d1.at})
    end
    table.insert(res, {type = "craft", recipe = c1.recipe, count = c1.count + c2.count})
    table.insert(res, {type = "store", item   = s1.item  , count = s1.count + s2.count})
    return res
  end
  return res
end

opts = {
  -- merge identical crafts
  gencraftmergerule(1),
  gencraftmergerule(2),
  gencraftmergerule(3),
  gencraftmergerule(4),
  gencraftmergerule(5),
  -- pickup stuff, store it, craft something: the craft and pick/store tasks are independent
  { types = {"pickup", "store", "craft", "store"},
    subst = function(p, s1, c, s2)
      if (p.at ~= "craftchest" and c.recipe.count == s2.count) then
        return {c, s2, p, s1}
      end
    end
  },
  -- always run input tasks before non-input tasks (this lets us make more effective use of time)
  { types = {"fetch", "deposit", "fetch", "deposit"},
    subst = function(f1, d1, f2, d2)
      -- if d2 is input and d1 is not input and they're not part of the same machine .. 
      if (not d1.at:find("_input") and d2.at:find("_input") and not d1.at:find(split(d2.at, "_", 1)[1])
          and f1.count == d1.count and f2.count == d2.count)
      then
        return {f2, d2, f1, d1}
      end
    end
  },
  -- merge two pickup-stores for the same material if the size permits it
  { types = {"pickup", "store", "pickup", "store"},
    subst = function(p1, s1, p2, s2)
      if (p1.at == p2.at and p1.count + p2.count <= (itemdata[p1.item].stacksize or -1)) then
        if (p1.item ~= p2.item) then
          printf("p(%i %s at %s) s(%i %s) p(%i %s at %s) s(%i %s) at %s", p1.count, p1.item, p1.at, s1.count, s1.item, p2.count, p2.item, p2.at, s2.count, s2.item, p1.at)
        end
        assert(p1.item == p2.item)
        return {
          {type = "pickup", item = p1.item, count = p1.count + p2.count, at = p1.at},
          {type = "store", item = s1.item, count = s1.count + s2.count}}
      end
    end
  },
  -- deposit fuel, fetch fuel, deposit fuel
  { types = {"deposit", "fetch", "deposit"},
    subst = function(d1, f, d2)
      if (d1.item == d2.item and d1.at == d2.at and
          d1.count + d2.count <= (itemdata[d1.item].stacksize or -1)) then
        return {f, d1, d2}
      end
    end
  },
  -- deposit a, deposit a: merge
  { types = {"deposit", "deposit"},
    subst = function(d1, d2)
      if (d1.item == d2.item and d1.at == d2.at and
          d1.count + d2.count <= (itemdata[d1.item].stacksize or -1)) then
        return {type = "deposit", at = d1.at, item = d1.item, count = d1.count + d2.count}
      end
    end
  },
  -- fetch a, fetch a: merge
  { types = {"fetch", "fetch"},
    subst = function(f1, f2)
      if (f1.item == f2.item and
          f1.count + f2.count <= (itemdata[f1.item].stacksize or -1)) then
        return {type = "fetch", item = f1.item, count = f1.count + f2.count}
      end
    end
  },
  -- merge two identical machine ops
  { types = {"fetch", "deposit", "pickup", "store", "fetch", "deposit", "pickup", "store"},
    subst = function(f1, d1, p1, s1, f2, d2, p2, s2)
      if f1.item == f2.item and d1.at == d2.at and
         p1.at == p2.at and p1.item == p2.item and
         d1.count + d2.count <= (itemdata[d1.item].stacksize or -1) and
         p1.count + p2.count <= (itemdata[p1.item].stacksize or -1)
      then
        assert(s1.item == s2.item)
        return {
          {type = "fetch",   item = f1.item, count = f1.count + f2.count},
          {type = "deposit", item = d1.item, count = d1.count + d2.count, at = d1.at},
          {type = "pickup",  item = p1.item, count = p1.count + p2.count, at = p1.at},
          {type = "store",   item = s1.item, count = s1.count + s2.count}
        }
      end
    end
  },
  -- do these last so they don't fuck up eventual earlier opts
  { types = {"store", "fetch"},
    subst = function(s, f)
      if (s.item == f.item) then
        if (s.count > f.count) then -- store 4 sticks, fetch 2 sticks
          return {type = "store", item = s.item, count = s.count - f.count}
        else -- store 2 sticks, fetch 4 sticks = fetch 2 sticks
          return {type = "fetch", item = s.item, count = f.count - s.count}
        end
      end
    end
  },
  { types = {"fetch", "store"},
    subst = function(f, s)
      if (f.item == s.item) then
        if (f.count > s.count) then -- fetch 4 sticks, store 2 sticks
          return {type = "fetch", item = f.item, count = f.count - s.count}
        else -- fetch 2 sticks, store 4 sticks = store 2 sticks
          return {type = "store", item = f.item, count = s.count - f.count}
        end
      end
    end
  },
  -- two unrelated tasks in a row? try to interleave them.
  { types = {"pickup", "store", "fetch", "deposit"},
    subst = function(p, s, f, d)
      function different_devices(at1, at2)
        local isdevice1 = at1:find("_")
        local isdevice2 = at2:find("_")
        if not isdevice1 or not isdevice2 then return false end -- cannot be certain
        local dev1 = split(at1, "_", 1)[1]
        local dev2 = split(at2, "_", 1)[1]
        return dev1 ~= dev2
      end
      if (s.item ~= f.item and different_devices(p.at, d.at))
      then
        return {f, d, p, s}
      end
    end
  },
  -- if possible, set the machine running as early as possible
  { types = {"craft", "store", "fetch", "deposit"},
    subst = function(c, s, f, d)
      if (c.recipe.count * c.count == s.count and f.count == d.count and
          d.at:find("_input") and f.item ~= s.item)
      then
        return {f, d, c, s}
      end
    end
  },
  { steps = 1,
    subst = function(a)
      if (a.type == "store" or a.type == "fetch") and a.count == 0 then
        return {}
      end
    end
  },
}

function apply(stream, opt)
  local n = 0
  for i, v in ipairs(stream) do n = n + 1 end
  local m = opt.steps
  local types = nil
  if not m then
    if not opt.types then
      print("Missing selector in optimization")
      assert(false)
    end
    types = opt.types
    m = 0
    for i,v in ipairs(types) do m = m + 1 end
  end
  local changed = false
  local i = 1
  local res = {}
  while i <= n-m+1 do
    local par = {}
    for k=i,i+m-1 do table.insert(par, stream[k]) end
    local outp = nil
    if not types then -- no type match given
      outp = opt.subst(unpack(par))
    else -- only even call the function if the types match up
      local match = true
      for i, v in ipairs(types) do
        if par[i].type ~= v then match = false end
      end
      if match then outp = opt.subst(unpack(par)) end
    end
    if not outp then
      table.insert(res, stream[i])
    else
      if not outp[1] then
        local empty = true
        for i, k in pairs(outp) do empty = false end
        if not empty then table.insert(res, outp) end
      else
        for i,v in ipairs(outp) do table.insert(res, v) end
      end
      changed = true
      i = i + m - 1
    end
    i = i + 1
  end
  while i <= n do table.insert(res, stream[i]); i = i + 1 end
  return res, changed
end

local yield = yieldevery(10)
perfcheck("optimize task plan", function()
  local startsize = #items.commands
  local changed = true -- true = enable opts, false = disable opts
  while changed do
    -- once we find a pass that made changes, restart!
    -- in other words, only move on once we've exhausted possibilities
    yield()
    changed = false
    for i, v in ipairs(opts) do if not changed then
        local opt_changed
        items.commands, opt_changed = apply(items.commands, v)
        changed = changed or opt_changed
    end end
  end
  printf("optimized: %i => %i", startsize, #items.commands)
end)

local planlength = 0
local data = ""
for i, v in ipairs(items.commands) do
  data = data..string.format("%i: ", i)
  planlength = planlength + 1
  if v.type == "craft" then
    data = data..format("craft %i x %i '%s'", v.count, v.recipe.count, v.recipe.item)
  elseif v.type == "fetch" then
    data = data..format("fetch %i '%s'", v.count, v.item)
  elseif v.type == "deposit" then
    data = data..format("deposit %i '%s' at %s", v.count, v.item, v.at)
  elseif v.type == "pickup" then
    data = data..format("pick up %i '%s' at %s", v.count, v.item, v.at)
    -- if v.machinestate then
    --   data = data..format("[machine state: %i '%s']", v.machinestate.load, v.machinestate.item)
    -- end
  elseif v.type == "store" then
    data = data..format("store %i %s", v.count, v.item)
  elseif v.type == "suckall" then
    data = data..format("pick up all items")
  else
    print("unknown type: "..v.type)
    assert(false)
  end
  data = data.."\n"
end

if planmode then
  local canrun = 0
  local made = 0
  
  local toreturn = nil
  local item = goal
  toreturn, item = countit(item)
  
  local function consume()
    if isvalid() then
      made = made + getnum(item)
      setnum(item, 0)
    end
  end
  start()
  consume()
  if goallist then
    canrun = 1
  else
    while isvalid() do
      -- printf("still valid at pass %i, got %i", canrun, made)
      -- printf("num tinx=%i orex=%i dusx=%i", getnum("tin"), getnum("tin ore"), getnum("tin dust"))
      canrun = canrun + 1
      produce(item, toreturn, true)
      consume()
    end
  end
  rollback()
  assert(not items.prev)
  data = data..string.format("plan(%i) can execute %i times for %i output\n", planlength, canrun, made)
  data = data..printmissing(true)
  if planmode == "paste" then
    print(pastebin(data))
  else
    print(data)
  end
  return
end

local len = 0
for i,v in ipairs(items.commands) do len = len + 1 end

local tf = {}
for i,v in ipairs(items.commands) do
  local function update(text, ...) return updatemon(i, len, tf, text, ...) end
  if v.type == "deposit" then
    local at = v.at
    update("deposit %i '%s' at %s", v.count, v.item, at)
    printf("deposit %i '%s' at %s", v.count, v.item, at)
    local down = ends(at, "[down]")
    local up = ends(at, "[up]")
    if down then at = strip(down) end
    if up   then at = strip(up)   end
    assert(shell.run("navigate", at))
    turtle.select(15)
    if up then assert(turtle.dropUp())
    elseif down then assert(turtle.dropDown())
    else assert(turtle.drop()) end
  elseif v.type == "fetch" then
    update("fetch %i '%s'", v.count, v.item)
    printf("> retrieve %i %s", v.count, v.item)
    assert(shell.run("retrieve", format("%i", v.count), format("%s", v.item)))
  elseif v.type == "pickup" then
    local at = v.at
    update("pick up %i '%s' at %s", v.count, v.item, at)
    local down = ends(at, "[down]")
    local up = ends(at, "[up]")
    local suckfn = turtle.suck dropfn = turtle.drop
    if down then at = strip(down); suckfn = turtle.suckDown; dropfn = turtle.dropDown end
    if up   then at = strip(up)  ; suckfn = turtle.suckUp  ; dropfn = turtle.dropUp   end
    assert(shell.run("navigate", at))
    turtle.select(15)
    local start = turtle.getItemCount(15)
    while turtle.getItemCount(15) - start < v.count do
      suckfn()
      sleep(0.2)
    end
    local uppicked = turtle.getItemCount(15) - start
    if uppicked > v.count then
      assert(dropfn(uppicked - v.count)) -- make sure we don't have too much
    end
  elseif v.type == "store" then
    update("store %i '%s'", v.count, v.item)
    assert(shell.run("store", "internal", "yes", format("%i", v.count), format("%s", v.item)))
  elseif v.type == "suckall" then
    update("grab items")
    assert(shell.run("navigate", "craftchest"))
    for i=1,15 do
      turtle.select(i)
      turtle.suck()
    end
  elseif v.type == "craft" then
    update("craft %ix%i '%s'", v.count, v.recipe.count, v.recipe.item)
    assert(shell.run("navigate", "craftchest"))
    local rec = v.recipe
    for i,item in ipairs(rec.shape.list) do
      local from  = rec.firstspot[i]
      turtle.select(from)
      turtle.suck()
      for i, field in ipairs(rec.nextspots[i]) do
        turtle.transferTo(field, v.count)
      end
    end
    turtle.select(16)
    local droppedFuel = false
    if turtle.drop() then droppedFuel = true end -- drop fuel
    if not turtle.craft() then
      turtle.select(16)
      turtle.suck()
      error(format("could not craft %s: invalid recipe? ", goal))
    end
    turtle.select(16)
    -- turtle.transferTo(1, rec.count * v.count)
    turtle.transferTo(15, rec.count * v.count)
    if droppedFuel then assert(turtle.suck()) end
  end
end
updatemon(len + 1, len, tf, "done")
