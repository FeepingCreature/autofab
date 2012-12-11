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

local yield = yieldeverysec(1)

function resolve(top)
  local forall = foritems
  if top then forall = fortopitems end
  local funforward = nil
  local funbackward = nil
  local reapplied_items = {}
  local function reapply()
    for k, v in ipairs(reapplied_items) do
      setnum(v.k, getnum(v.k) + v.v)
    end
  end
  local function addfront()
    if not funbackward then funbackward = funforward
    else funbackward = combine(funforward, funbackward) end
    funforward = nil
    fortopitems(function(k, v)
    end)
  end
  local function add(f)
    assert(f)
    if not funforward then funforward = f
    else funforward = combine(funforward, f) end
  end
  -- resolve crafts
  local function resolvecrafts()
    local todo = {}
    forall(function(k, v)
      if v < 0 and recipe(k, itemdata) then
        if debugme and not k:find("wood") then printf("craft todo %s", k) end
        table.insert(todo, {k=k, v=v})
      end
    end)
    local changed = false
    for i,v in ipairs(todo) do changed = true
      local k = v.k
      local v = v.v
      local goal = getnum(k) - v
      while getnum(k) < goal do
        if debugme then printf("craft resolve %s (%i by %i)", k, getnum(k), v) end
        add(mkcraft(recipe(k, itemdata)))
      end
    end
    -- do here!
    for i,v in ipairs(todo) do
      local k = v.k
      if getnum(k) > 0 then
        -- printf("craft: %s has %i", k, getnum(k))
        table.insert(reapplied_items, {k=k, v=getnum(k)})
        setnum(k, 0)
      end
    end
    addfront()
    return changed
  end
  --resolve generic machine ops
  local function resolvemachines()
    local todo = {}
    forall(function(k, v)
      -- if v < 0 then printf("%s? %s", k, tostring(itemdata[k].mode)) end
      if v < 0 and itemdata[k] and itemdata[k].mode == "machine" then
        table.insert(todo, {k=k, v=v})
      end
    end)
    local changed = false
    for i,v in ipairs(todo) do changed = true
      local k = v.k
      local v = v.v
      local goal = getnum(k) - v
      while getnum(k) < goal do
        if debugme then printf("machine resolve %s (%i by %i)", k, getnum(k), v) end
        add(mkmachine(k))
      end
    end
    -- do here!
    for i,v in ipairs(todo) do
      local k = v.k
      if getnum(k) > 0 then
        -- printf("machina: %s has %i", v, getnum(v))
        table.insert(reapplied_items, {k=k, v=getnum(k)})
        setnum(k, 0)
      end
    end
    addfront()
    return changed
  end
  local running = true
  while running do
    yield()
    running = false
    while resolvecrafts() do running = true end
    while resolvemachines() do running = true end
  end
  reapply()
  local fun = funbackward
  if not fun then fun = function() end end
  return fun
end

function store(count, item)
  setnum(item, getnum(item) + count)
  addcommand({type = "store", count = count, item = item})
end

function mkfetch(count, item, at, checkempty)
  -- if at then printf("fetch %s %s (%s) to %s", tostring(count), item, tostring(getnum(item)), at)
  -- else printf("fetch %s %s (%s)", tostring(count), item, tostring(getnum(item))) end
  setnum(item, getnum(item) - count) -- mark as claimed!
  return function()
    addcommand({type = "fetch", count = count, item = item})
    if at then addcommand({type = "deposit", count = count, item = item, at = at, checkempty = checkempty}) end
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
        param = info.param,
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
    local res = mkfetch(v, k, "craftchest", not fetchs)
    if nil == res then return nil end
    fetchs = combine(fetchs, res)
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
      table.insert(res, {type = "deposit", item = d1.item, count = d1.count + d2.count, at = d1.at, checkempty = f1.checkempty})
    end
    table.insert(res, {type = "craft", recipe = c1.recipe, count = c1.count + c2.count})
    table.insert(res, {type = "store", item   = s1.item  , count = s1.count + s2.count})
    return res
  end
  return res
end

function genmachinemergerule(num_inputs)
  local res = {}
  res.types = {}
  -- first set
  for i=1,num_inputs do table.insert(res.types, "fetch"); table.insert(res.types, "deposit") end
  table.insert(res.types, "pickup"); table.insert(res.types, "store")
  -- second set
  for i=1,num_inputs do table.insert(res.types, "fetch"); table.insert(res.types, "deposit") end
  table.insert(res.types, "pickup"); table.insert(res.types, "store")
  
  res.subst = function(...)
    local args = { ... }
    local halfpoint = num_inputs*2+2
    assert(#args == halfpoint*2)
    
    local p1 = args[num_inputs*2+1]; local p2 = args[num_inputs*2+1 + halfpoint]
    local s1 = args[num_inputs*2+2]; local s2 = args[num_inputs*2+2 + halfpoint]
    assert(p1.type == "pickup" and p2.type == "pickup" and s1.type == "store" and s2.type == "store")
    if s1.item ~= s2.item or p1.item ~= p2.item or s1.count + s2.count > (itemdata[s1.item].stacksize or -1) then return nil end
    
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
      table.insert(res, {type = "deposit", item = d1.item, count = d1.count + d2.count, at = d1.at, checkempty = f1.checkempty})
    end
    table.insert(res, {type = "pickup", item = p1.item, count = p1.count + p2.count, at = p1.at, param = commajoin(p1.param, p2.param)})
    table.insert(res, {type = "store",  item = s1.item, count = s1.count + s2.count})
    return res
  end
  return res
end

function commajoin(a, b)
  if not a and not b then return nil end
  if a and not b then return a end
  if b and not a then return b end
  if a == b then return a end
  return a .. "," .. b
end

function different_devices(at1, at2)
  local isdevice1 = at1:find("_")
  local isdevice2 = at2:find("_")
  if not isdevice1 or not isdevice2 then return false end -- cannot be certain
  local dev1 = split(at1, "_", 1)[1]
  local dev2 = split(at2, "_", 1)[1]
  return dev1 ~= dev2
end

function same_device(at1, at2)
  local isdevice1 = at1:find("_")
  local isdevice2 = at2:find("_")
  if not isdevice1 or not isdevice2 then return false end -- cannot be certain
  local dev1 = split(at1, "_", 1)[1]
  local dev2 = split(at2, "_", 1)[1]
  return dev1 == dev2
end

opts = {
  -- merge identical crafts
  gencraftmergerule(1),
  gencraftmergerule(2),
  gencraftmergerule(3),
  gencraftmergerule(4),
  gencraftmergerule(5),
  -- merge identical machine tasks
  genmachinemergerule(1),
  genmachinemergerule(2),
  genmachinemergerule(3),
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
          {type = "pickup", item = p1.item, count = p1.count + p2.count, at = p1.at, param = commajoin(p1.param, p2.param)},
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
        return {type = "deposit", at = d1.at, item = d1.item, count = d1.count + d2.count, checkempty = d1.checkempty}
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
  genmachinemergerule(1),
  genmachinemergerule(2),
  genmachinemergerule(3),
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
  -- finally, fuse fetch-to-machine/fetch-from-machine into a faster form
  { types = {"pickup", "store", "fetch", "deposit"},
    subst = function(p, s, f, d)
      if  p.count == s.count and
          f.count == d.count and
          s.item ~= f.item
      then
        local t_1 = {type="slot-transfer", from = 15, to = 14, count = f.count}
        local t_2 = {type="slot-transfer", from = 15, to = 13, count = p.count}
        local t1_ = {type="slot-transfer", from = 14, to = 15, count = f.count}
        local t2_ = {type="slot-transfer", from = 13, to = 15, count = p.count}
        return {f, t_1, p, t_2, t1_, d, t2_, s}
      end
    end
  },
  { steps = 2,
    subst = function(a, b)
      if  a.type == "slot-transfer" and b.type == "deposit" and 
          a.from ~= 15 and a.to ~= 15
      then return {b, a} end
    end
  },
  { types = {"slot-transfer", "slot-transfer"},
    subst = function(a, b)
      if a.count == b.count and a.to == b.from then
        return {type="slot-transfer", from = a.from, to = b.to, count = a.count}
      end
    end
  },
  { types = {"slot-transfer", "slot-transfer", "slot-transfer"},
    subst = function(a, b, c)
      if  a.from == c.to and c.from == a.to and
          b.from ~= a.from and b.from ~= a.to and
          b.to ~= a.from and b.to ~= a.to
      then return {b} end
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
  local len = 0
  for i,v in ipairs(items.commands) do
    if v.type ~= "slot-transfer" then len = len + 1 end
  end
  printf("optimized: %i => %i(%i total)", startsize, len, #items.commands)
end)

local planlength = 0
local data = ""
function format_task(v)
  if v.type == "craft" then
    return format("craft %i x %i '%s'", v.count, v.recipe.count, v.recipe.item)
  elseif v.type == "fetch" then
    return format("fetch %i '%s'", v.count, v.item)
  elseif v.type == "deposit" then
    return format("deposit %i '%s' at %s", v.count, v.item, v.at)
  elseif v.type == "pickup" then
    return format("pick up %i '%s' at %s %s", v.count, v.item, v.at, v.param or "")
    -- if v.machinestate then
    --   data = data..format("[machine state: %i '%s']", v.machinestate.load, v.machinestate.item)
    -- end
  elseif v.type == "store" then
    return format("store %i %s", v.count, v.item)
  elseif v.type == "suckall" then
    return format("pick up all items")
  elseif v.type == "slot-transfer" then
    return format("move slot %i(%i) -> %i", v.from, v.count, v.to)
  else
    print("unknown type: "..v.type)
    assert(false)
  end
end

for i, v in ipairs(items.commands) do
  if v.type ~= "slot-transfer" then
    data = data..string.format("%i: ", planlength)
    planlength = planlength + 1
  else
    if planlength < 10 then data = data.." : "
    elseif planlength < 100 then data = data.."  : "
    elseif planlength < 1000 then data = data.."   : "
    else data = data.."    : " end
  end
  data = data .. format_task(v) .. "\n"
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
local reallen = 0
for i,v in ipairs(items.commands) do
  if v.type ~= "slot-transfer" then len = len + 1 end -- effectively free
  reallen = reallen + 1
end

local tf = {}
local count = 0
for i,v in ipairs(items.commands) do
  local function update(text, ...) return updatemon(count, len, tf, text, ...) end
  if v.type ~= "slot-transfer" then count = count + 1 end
  
  local function do_pickup(v, slot)
    slot = slot or 15
    local at = v.at
    update("pick up %i '%s' at %s %s", v.count, v.item, at, v.param or "")
    local down = ends(at, "[down]")
    local up = ends(at, "[up]")
    local suckfn = turtle.suck dropfn = turtle.drop
    if down then at = strip(down); suckfn = turtle.suckDown; dropfn = turtle.dropDown end
    if up   then at = strip(up)  ; suckfn = turtle.suckUp  ; dropfn = turtle.dropUp   end
    assert(shell.run("navigate", at))
    turtle.select(slot)
    local start = turtle.getItemCount(slot)
    if (v.param or ""):find("power down") then redstone.setOutput("bottom", true) end
    while turtle.getItemCount(slot) - start < v.count do
      suckfn()
      sleep(0.2)
    end
    if (v.param or ""):find("power down") then redstone.setOutput("bottom", false) end
    local uppicked = turtle.getItemCount(slot) - start
    if uppicked > v.count then
      assert(dropfn(uppicked - v.count)) -- make sure we don't have too much
    end
  end
  
  local function do_deposit(v, slot)
    slot = slot or 15
    local at = v.at
    update("deposit %i '%s' at %s", v.count, v.item, at)
    printf("deposit %i '%s' at %s", v.count, v.item, at)
    local down = ends(at, "[down]")
    local up = ends(at, "[up]")
    if down then at = strip(down) end
    if up   then at = strip(up)   end
    
    local dfun = turtle.drop
    if up   then dfun = turtle.dropUp end
    if down then dfun = turtle.dropDown end
    
    assert(shell.run("navigate", at))
    if v.checkempty then
      local sfun = turtle.suck
      if up then sfun = turtle.suckUp end
      if down then sfun = turtle.suckDown end
      turtle.select(1)
      if sfun() then
        dfun() -- oops
        error(format("cannot deposit: %s was not empty!", v.at))
      end
    end
    turtle.select(slot)
    assert(dfun())
  end
  
  if v.type == "pickup" then
    do_pickup(v)
  elseif v.type == "deposit" then
    do_deposit(v)
  elseif v.type == "fetch" then
    update("fetch %i '%s'", v.count, v.item)
    printf("> retrieve %i %s", v.count, v.item)
    assert(shell.run("retrieve", format("%i", v.count), format("%s", v.item)))
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
  elseif v.type == "slot-transfer" then
    turtle.select(v.from)
    turtle.transferTo(v.to, v.count)
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
      error(format("could not craft %s in %s: invalid recipe? ", rec.item, goal))
    end
    turtle.select(16)
    -- turtle.transferTo(1, rec.count * v.count)
    turtle.transferTo(15, rec.count * v.count)
    if droppedFuel then assert(turtle.suck()) end
  end
end
updatemon(len + 1, len, tf, "done")
