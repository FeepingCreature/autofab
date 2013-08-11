-- I fucking hate Lua.
format = string.format
function printf(text, ...) print(format(text, ...)) end
function split(self, sep, max)
  if not self then return {} end
  assert(sep)
  assert(sep ~= '')
  max = max or -1
  -- printf("split(%s, %s, %i)", self, sep, max)
  assert(max == -1 or max >= 1)
  local rec = {}
  if self:len() > 0 then
    
    local field=1 start=1
    local first, last = string.find(self.."", sep, start, true)
    while first and max ~= 0 do
      rec[field] = self:sub(start, first-1)
      field = field + 1
      start = last + 1
      first, last = string.find(self.."", sep, start, true)
      max = max - 1
    end
    rec[field] = self:sub(start)
  end
  
  return rec
end

function makechestfilename(num)
  return string.format("chests/chest%i.db", num)
end

function join(list, sep)
  sep = sep or ""
  local res = ""
  for i, v in ipairs(list) do
    if res:len() > 0 then res = res .. sep end
    res = res .. v
  end
  return res
end

function strip(s)
  if not s then return nil end
  while s:len() > 0 and (
    s:sub( 1, 1) == " " or s:sub( 1, 1) == "\n") do s = s:sub(2,-1) end
  while s:len() > 0 and (
    s:sub(-1,-1) == " " or s:sub(-1,-1) == "\n") do s = s:sub(1,-2) end
  return s
end

function fmap(list, fun)
  local res = {}
  for i,v in ipairs(list) do
    res[i] = fun(v)
  end
  return res
end

_mark = nil
function mark(text, ...)
  if _mark then _mark(format(text, ...)) end
end

function sstarts(text, with)
  return strip(starts(text, with))
end

function sslice(text, pattern)
  local res = fmap(split(text, pattern, 1), strip)
  return res[1], res[2]
end

function sslice2(text, pattern)
  local res = fmap(split(text, pattern, 1), strip)
  if not res[2] then return nil end
  return res[1], res[2]
end

function ssplit(text, pattern)
  return fmap(split(text, pattern), strip)
end

function times(k, f)
  for i=1,k do f() end
end

function dup(tbl)
  res = {}
  for k, v in pairs(tbl) do res[k] = v end
  return res
end

function concat(a, b, x)
  local res = {}
  if type(a) == "string" and a == "element" then
    a = b
    b = x
    table.insert(res, a)
  else
    for i, v in ipairs(a) do table.insert(res, v) end
  end
  if type(b) == "string" and b == "element" then
    b = x
    table.insert(res, b)
  else
    for i, v in ipairs(b) do table.insert(res, v) end
  end
  return res
end

combine_cache = {}
function combine(a, b)
  function make_listcall(list)
    local res = function()
      for i,f in ipairs(list) do f() end
    end
    combine_cache[res] = list
    return res
  end
  if not b then return a end
  if not a then return b end
  local cca = combine_cache[a]
  local ccb = combine_cache[b]
  if cca and ccb then
    return make_listcall(concat(cca, ccb))
  elseif cca then
    return make_listcall(concat(cca, "element", b))
  elseif ccb then
    return make_listcall(concat("element", a, ccb))
  else
    return make_listcall({a, b})
  end
end

function yieldeverysec(t)
  local last = os.clock()
  return function()
    local now = os.clock()
    if now - last < t then return end
    last = now
    sleep(0)
  end
end

local fileyield = yieldeverysec(2)

function withfile(fname, mode)
  return function(fun)
    fileyield()
    local f = io.open(fname, mode)
    if not f then error ("No such file "..fname) end
    local res = fun(f)
    f:close()
    return res
  end
end

function download(name, to)
  print(name.." --> "..to)
  local url = "http://feephome.no-ip.org/~feep/ftblua/"..name;
  local lines = {}
  if (fs.exists("config.db")) then
    lines = withfile("config.db", "r")(function(f)
      local res = {}
      for line in f:lines() do table.insert(res, line) end
      return res
    end)
  end
  local recipeurl = "http://piratepad.net/ep/pad/export/feepturtle/latest?format=txt"
  if (# lines > 0) then recipeurl = lines[1] end
  if name == "recipes.txt" then
    url = recipeurl
  end
  -- print(url)
  data = http.get(url):readAll()
  sleep(0) -- yield
  f = io.open(to, "w")
  f:write(data)
  f:close()
end

function update(file)
  if file:sub(-3,-1) == ".db" then
    local name = file:sub(1, -4)..".txt"
    download(name, file)
  else
    local name = file..".lua"
    download(name, file)
  end
end

function goback()
  shell.run("navigate", "home")
end

function starts(text, t2)
  if not text then return nil end
  if t2:len() > text:len() then return false end
  if text:sub(1,t2:len()) ~= t2 then return false end
  return text:sub(t2:len()+1, text:len())
end

function ends(text, t2)
  if not text then return nil end
  if t2:len() > text:len() then return false end
  if text:sub(-t2:len(),-1) ~= t2 then return false end
  return text:sub(1, text:len()-t2:len())
end

function countit(s)
  local count = tonumber(split(s, " ", 1)[1])
  if count then s = split(s, " ", 1)[2]
  else count = 1 end
  return count, s
end

local chestcache = {}

function chest(i)
  if chestcache[i] then return chestcache[i] end
  local res = {
    chestid = i,
    transferred = 0,
    datacache = nil,
    filename = function(self) return makechestfilename(self.chestid) end,
    exists = function(self)
      if self.datacache then return true end -- can be assumed
      fileyield()
      local f = io.open(self:filename(), "r")
      local res = false
      if f then
        res = true
        f:close()
      end
      return res
    end,
    readopen = function(self)
      fileyield()
      local f = io.open(self:filename(), "r")
      if not f then error(string.format("No such chest: %i", self.chestid)) end
      return f
    end,
    readdata = function(self)
      if self.datacache then return self.datacache end
      local f = self:readopen()
      self.datacache = f:read("*a")
      f:close()
      return self.datacache
    end,
    items = function(self)
      local res = 0
      self:withp(function(tbl)
        if tbl.count > 0 then res = res + 1 end
      end)
      return res
    end,
    with = function(self, fun, passive, reverse)
      local newdata = ""
      local myres = nil
      local count = 1
      if reverse then count = 14 end
      local loopbody = function(number, line)
        local tbl = {
          count = number,
          item = line,
          id  = count
        }
        if not reverse then count = count + 1
        else count = count - 1 end
        local res = fun(tbl)
        if type(res) ~= "nil" then myres = res end
        if tbl.count > 0 then
          
          if not passive then
            local newline = string.format("%i %s", tbl.count, tbl.item)
            if not reverse then
              newdata = newdata.."\n"..newline
            else
              newdata = newline.."\n"..newdata
            end
          end
        end
      end
      local lines = split(self:readdata(), "\n")
      if reverse then
        local backlines = {}
        local len = 0
        for i,v in ipairs(lines) do len = len + 1 end
        for i,v in ipairs(lines) do backlines[len-i+1] = v end
        lines = backlines
      end
      
      if reverse then
        while count > self:items() do
          loopbody(0, "")
        end
      end
      
      for i,line in ipairs(lines) do
        if myres then -- already returned
          if not passive then
            if not reverse then newdata = newdata.."\n"..line
            else newdata = line.."\n"..newdata end
          end
        else
          local numstr = split(line, " ")[1]
          if numstr then
            line = strip(starts(line, numstr))
            if not line then error "wat" end
            local num = tonumber(numstr)
            loopbody(num, line)
          end
        end
      end
      
      if not reverse then
        while count <= 14 do
          loopbody(0, "")
        end
      end
      if not passive then
        local mydata = strip(newdata).."\n"
        self.datacache = mydata
        sleep(0) -- yield
        local f = io.open(self:filename(), "w")
        f:write(mydata)
        f:close()
        
        self:close()
      end
      
      return myres
    end,
    withp = function(self, fun)
      return self:with(fun, true)
    end,
    withprev = function(self, fun)
      return self:with(fun, true, true)
    end,
    withrev = function(self, fun)
      return self:with(fun, nil, true)
    end,
    open = function(self, to)
      if self.transferred >= to then return end
      shell.run("navigate", string.format("chest%i", self.chestid))
      for k=self.transferred+1,to do 
        turtle.select(k)
        turtle.suck()
      end
      self.transferred = to
    end,
    close = function(self)
      if self.transferred == 0 then return end
      for k=1,self.transferred do
        turtle.select(k)
        turtle.drop()
      end
      self.transferred = 0
    end,
    replace = function(self, id, fun)
      self:open(id)
      fun()
    end
  }
  chestcache[i] = res
  return res
end

function cleanname(name)
  name = split(name, "[", 1)[1] or name
  return strip(name)
end

function getlocation()
  fileyield()
  local f = io.open("location.txt", "r")
  local location = nil
  if f then
    location = f:read()
    f:close()
  end
  return location
end

function rld(str)
  local res = ""
  local rep = nil
  function flush() if rep then
    rep = rep - 1 -- one is already written
    assert(res:len() > 0)
    for k=1,rep do
      res = res..res:sub(-1, -1)
    end
    rep = nil
  end end
  for i=1,str:len() do
    local ch = str:sub(i,i)
    local digit = tonumber(ch)
    if not digit then
      flush()
      res = res..ch
    else
      if not rep then rep = digit
      else rep = rep * 10 + digit end
    end
  end
  flush()
  return res
end

assert(rld("LF5R") == "LFFFFFR")
assert(rld("RF15L") == "RFFFFFFFFFFFFFFFL")

function gotnavinfo(loc)
  return withfile("locations.db","r")(function(f)
    for line in f:lines() do
      local info = strip(starts(strip(starts(line, loc)), "="))
      if info then return rld(info:upper()) end
    end
    return nil
  end)
end

function getnavinfo(loc)
  if not loc or loc == "origin" then return "" end
  local res = gotnavinfo(loc)
  if not res then error("Unknown location: '"..loc.."'") end
  return res
end

perflimit = 2

function perfcheck(info, fun)
  local startt = os.clock()
  
  local markerinfo = nil
  local previnfo = "start"
  local prevt = startt
  local function recordmarker(info)
    local t = os.clock()
    if not markerinfo then markerinfo = {} end
    markerinfo[info] = {from = previnfo, to = info, delta = t - prevt}
    previnfo, prevt = info, t
  end
  local function largestmarker()
    local res = nil
    for k, v in pairs(markerinfo) do
      if not res or res.delta < v.delta then res = v end
    end
    return res
  end
  
  -- global!
  local backup = _mark
  _mark = recordmarker
  local res = fun()
  _mark = backup
  local endt = os.clock()
  
  if endt - startt > perflimit then
    local mesg = ""
    if not markerinfo then
      mesg = format("%fs: %s", endt - startt, info)
    else
      local largest = largestmarker()
      mesg = format("%fs: %s (longest from %s to %s with %fs)", endt - startt, info, largest.from, largest.to, largest.delta)
    end
    printf("WARN: %s", mesg)
    
    local f = io.open("warnings.txt", "r")
    local data = ""
    if f then
      data = f:read("*a")
      f:close()
    end
    
    data = data .. mesg
    
    sleep(0) -- yield
    f = io.open("warnings.txt", "w")
    f:write(data)
    f:close()
  end
  return res
end

function optmove(movestr)
  local original = movestr
  local changed = true
  
  mark("optmove(%s) start", movestr) 
  perfcheck(format("optimizing %s", movestr), function()
    local yield = yieldeverysec(1)
    while changed do
      local start = movestr
      movestr = movestr
        :gsub("FRRF", "RR"):gsub("FLLF", "LL")
        :gsub("LR", ""):gsub("RL", "")
        :gsub("DU", ""):gsub("UD", "")
        :gsub("LLLL", ""):gsub("RRRR", "")
        :gsub("LLL", "R"):gsub("RRR", "L")
        :gsub("FRFRF", "RFR"):gsub("FLFLF", "LFL")
        :gsub("DLLU", "LL"):gsub("DRRU", "RR")
        :gsub("ULLD", "LL"):gsub("URRD", "RR")
        :gsub("FDRFRF", "RFDR"):gsub("FDLFLF", "LFDL")
        -- rule: down first, then turn
        :gsub("UL", "LU"):gsub("UR", "RU")
        :gsub("LD", "DL"):gsub("RD", "DR")
        :gsub("DLU", "L"):gsub("DRU", "R")
        :gsub("DFLFLUF", "LFL"):gsub("DFRFRUF", "RFR")
        :gsub("FDRFRFRUF", "L"):gsub("FDLFLFLUF", "R")
        :gsub("FDFDRFFRFFRUFUF", "L"):gsub("FDFDLFFLFFLUFUF", "R")
        :gsub("UFD", "F"):gsub("DFU", "F")
        :gsub("FRRUF", "RRU"):gsub("FLLUF", "LLU")
        :gsub("FDRRF", "DRR"):gsub("FDLLF", "DLL")
      yield()
      changed = movestr ~= start
    end
  end)
  mark("optmove(%s) end (res %s)", original, movestr)
  return movestr
end

function getinvnavinfo(loc)
  local nav = getnavinfo(loc)
  local res = ""
  for i=nav:len(),1,-1 do
    local sub = nav:sub(i,i)
    if sub == "F" then res = res.."F"
    elseif sub == "B" then res = res.."B"
    elseif sub == "L" then res = res.."R"
    elseif sub == "R" then res = res.."L"
    elseif sub == "U" then res = res.."D"
    elseif sub == "D" then res = res.."U"
    else error("wat: '"..sub.."'") end
  end
  return optmove("LL"..res.."LL")
end

function costfornav(nav)
  return nav:len()
end

function costforchestaccess(ch)
  local thatchest = chest(ch)
  assert(thatchest:exists())
  return thatchest:items()
end

function chest_usecost(prefix, ch, chestcache)
  assert(chestcache)
  if chestcache and chestcache[ch] then return chestcache[ch]
  else
    mark("calculate cost for chest %i: start", ch)
    local nav = optmove(prefix..getnavinfo(format("chest%i", ch)))
    local res = costfornav(nav) + costforchestaccess(ch) * 2
    mark("calculate cost for chest %i: end", ch)
    if chestcache then chestcache[ch] = res end
    return res
  end
end

function _readrecipes()
  return withfile("recipes.db","r")(function(f)
    local res = {}
    local function register(name)
      if name == "nil" then return end
      local item = {}
      local test = tonumber(split(split(name, "[", 1)[2], "]", 1)[1])
      name = cleanname(name)
      if not res[name] then res[name] = item
      else item = res[name] end
      if test then
        if item.stacksize then assert(item.stacksize == test)
        else item.stacksize = test end
      end
    end
    local function merge(id, thing)
      local count = nil
      count, id = countit(id) -- eat number
      
      register(id)
      id = cleanname(id)
      assert(res[id])
      if res[id].mode then
        -- already provided, don't merge (side effect?)
        -- TODO multiproviders (generalize aliases?)
        -- printf("skip merging %s from %s", id, thing.mode)
      else
        for k, v in pairs(thing) do res[id][k] = v end
      end
    end
    
    oplist = {}
    function haveop(name) return nil ~= oplist[name] end
    
    local map = {1,2,3,  5,6,7,  9,10,11}
    local process = nil
    local i = 1
    function parseline(line)
      line = sslice(line, "--")
      local define = starts(line, "define ");
      local craft = starts(line, "craft ");
      local alias = starts(line, "alias ");
      local defop = starts(line, "defop ");
      local opname = sslice(line, " ")
      local parver = sslice2(line, "[")
      if parver and parver:len() < opname:len() then
        opname = parver
      end
      
      if not line or line:len() == 0 then
      elseif process then
        process(line)
      elseif define then
        register(define)
      elseif defop then
        -- defops have the form
        -- defop <name>: <outslot-list> = <inslot-list>
        -- they are used like this
        -- <name>[args] <out-items> = <in-items>
        local name = nil
        local outslots = nil
        local inslots = nil
        name, defop = sslice(defop, ":")
        outslots, defop = sslice(defop, "=")
        outslots = ssplit(outslots, ",")
        inslots = ssplit(defop, ",")
        oplist[name] = {outslots = outslots, inslots = inslots}
      elseif craft then
        local name = strip(split(craft, "=", 1)[1])
        local count = 1
        count, name = countit(name)
        assert(name); register(name)
        name = cleanname(name)
        
        if res[name].mode then
          error("double definitions for "..name)
        end
        res[name].mode = "craft"
        
        local list = fmap(split(split(craft, "=", 1)[2], ","), strip)
        for i,v in ipairs(list) do register(list[i]) end
        list = fmap(list, cleanname)
        
        local shape = {}
        shape.list = list
        
        local linesleft = 3; local index = 1
        local needed = {}; local firstspot = {}; local nextspots = {}
        
        process = function(line)
          for i = 1,3 do
            local ch = line:sub(i,i)
            if ch == "." then shape[index] = nil
            else
              local num = tonumber(ch)
              if not list[num] then
                printf("while decoding %s: invalid index %i", name, num)
                assert(false)
              end
              local name = list[num]
              shape[index] = num
              if not needed[num] then
                needed[num] = 1
                firstspot[num] = map[index]
                nextspots[num] = {}
              else
                needed[num] = needed[num] + 1
                table.insert(nextspots[num], map[index])
              end
            end
            index = index + 1
          end
          if index > 9 then
            res[name].recipe = {
              item = name,
              shape = shape,
              needed = needed,
              firstspot = firstspot,
              nextspots = nextspots,
              count = count
            }
            process = nil
          end
        end
      elseif alias then
        local name = strip(split(alias, "=", 1)[1])
        assert(name); register(name); name = cleanname(name)
        
        local targets = fmap(split(strip(split(alias, "=", 1)[2]), ","), strip)
        for i,target in ipairs(targets) do register(target) end
        targets = fmap(targets, cleanname)
        
        -- assert(not res[name].mode)
        if res[name].mode then
          printf("collision: while defining alias '%s': already %s", name, res[name].mode)
          assert(false);
        end
        merge(name, {mode = "alias", targets = targets})
      elseif haveop(opname) then
        -- example:
        -- defop smelt: furnace_output = furnace_input, furnace_fuel
        -- smelt[power down] stone[64] = cobblestone[64], 2 stick
        local op = oplist[opname]
        local outitems = nil
        local initems = nil
        local opstr = sstarts(line, opname)
        assert(opstr)
        
        local param = nil
        if sstarts(opstr, "[") then
          param, opstr = sslice(sstarts(opstr, "["), "]")
        end
        
        outitems, opstr = sslice(opstr, "=")
        outitems = ssplit(outitems, ",")
        initems = ssplit(opstr, ",")
        -- outitems = {"stone[64]"} initems = {"cobblestone[64]", "2 stick"}
        
        -- transform into {count, item, at} form
        -- also register and clean up
        local inputlist = {}
        local outputlist = {}
        for i, item in ipairs(outitems) do
          local count = nil
          count, item = countit(item)
          register(item)
          item = cleanname(item)
          if item ~= "nil" then
            table.insert(outputlist, {count = count, item = item, at = op.outslots[i]})
          end
        end
        for i, item in ipairs(initems) do
          local count = nil
          count, item = countit(item)
          register(item)
          item = cleanname(item)
          if item ~= "nil" then
            table.insert(inputlist, {count = count, item = item, at = op.inslots[i]})
          end
        end
        
        -- and done
        for i, output in ipairs(outitems) do if output ~= "nil" then
          merge(output, {
            mode = "machine",
            param = param,
            input  = inputlist,
            output = outputlist,
          })
        end end
      else
        printf("Syntax error in recipe file: unknown input")
        printf("recipes.db:%i: %s", i, line)
        assert(false)
      end
      i = i + 1
    end
    for line in f:lines() do parseline(line) end
    return res
  end)
end

function optrec(recipe, itemdata)
  -- find the last input that depends on a recipe, and move it to position 1
  -- this lets us join the craft directly to the next one
  local lastrec = nil
  for i,k in ipairs(recipe.shape.list) do
    if k and itemdata[k].mode == "craft" then lastrec = i end
  end
  if lastrec and lastrec ~= 1 then
    recipe = dup(recipe)
    -- now, swap lastrec and 1 in all the lists
    local function swap(f, a, b)
      local temp = f[a]
      f[a] = f[b]
      f[b] = temp
    end
    recipe.shape = dup(recipe.shape)
    for i,k in ipairs(recipe.shape) do
      if k == lastrec then recipe.shape[k] = 1 end
      if k == 1 then recipe.shape[k] = lastrec end
    end
    
    recipe.shape.list = dup(recipe.shape.list)
    if (recipe.item == "copper cable") then
      printf("swap %i for %i", 1, lastrec)
    end
    swap(recipe.shape.list, 1, lastrec)
    
    recipe.needed = dup(recipe.needed)
    swap(recipe.needed, 1, lastrec)
    
    recipe.firstspot = dup(recipe.firstspot)
    swap(recipe.firstspot, 1, lastrec)
    
    recipe.nextspots = dup(recipe.nextspots)
    swap(recipe.nextspots, 1, lastrec)
  end
  return recipe
end

function readrecipes()
  local recipes = _readrecipes()
  for k,v in pairs(recipes) do
    if v.mode == "craft" then
      recipes[k].recipe = optrec(v.recipe, recipes)
    end
  end
  return recipes
end

function sstarts(text, match) return strip(starts(strip(text), match)) end

function recipe(item, rdata)
  rdata = rdata or readrecipes();
  local res = rdata[item]
  if not res or res.mode ~= "craft" then return nil end
  return res.recipe
end

function _knownitem(name)
  local res = readrecipes()[name]
  if res then return true else return false end
end

function knownitem(name)
  if _knownitem(name) then return true end
  update("recipes.db")
  return _knownitem(name)
end

function didyoumean(name)
  local recipes = readrecipes()
  local res = ""
  local function add(s)
    if res:len() > 0 then
      res = res .. ", "
    end
    res = res .. s
  end
  for k, v in pairs(recipes) do
    if k:lower():find(name:lower()) then add(k) end
  end
  if res:len() > 0 then res = ", did you mean "..res end
  return res
end

-- build an inventory record
function regenInv()
  local items = {}
  local i = 1
  local ch = chest(i)
  while ch:exists() do
    ch:with(function(slot)
      items[slot.item] = (items[slot.item] or 0) + slot.count
    end)
    i = i + 1
    ch = chest(i)
  end
  return items
end

function redsend()
  return {
    dir = "right",
    cmd = "",
    addcmd = function(self, s, ...)
      s = string.format(s, ...)
      if self.cmd:len() > 0 then self.cmd = self.cmd .. "; " end
      self.cmd = self.cmd .. s
    end,
    send = function(self)
      rednet.open(self.dir)
      if self.cmd then rednet.broadcast("monitor "..self.cmd) end
      self.cmd = ""
      rednet.close(self.dir)
    end,
  }
end

function updatemon(i, t, tf, msg, ...)
  if not tf.starttime then
    tf.starttime = os.clock()
  end
  local elapsed = os.clock() - tf.starttime
  local projected = elapsed
  if i > 1 then projected = (elapsed / (i - 1)) * t end
  msg = string.format(msg, ...)
  local function timefmt(t)
    t = math.floor(t)
    local mins = math.floor(t / 60)
    t = t - mins * 60
    local hours = math.floor(mins / 60)
    mins = mins - hours * 60
    if hours > 0 then return string.format("%ih%im", hours, mins)
    else return string.format("%im%i", mins, t) end
  end
  local fixed_i = i
  if fixed_i == t + 1 then fixed_i = t end -- make look good
  local rs = redsend()
  rs:addcmd("term.redirect(mon)")
  rs:addcmd("local w, h = term.getSize()")
  rs:addcmd("term.clear()")
  for i, line in ipairs(split(msg, "\n")) do
    rs:addcmd("term.setCursorPos(1, %i)", i)
    rs:addcmd("term.write(\"%s\")", line)
  end
  rs:addcmd("term.setCursorPos(1, h-1)")
  rs:addcmd("term.write(\"%s eta %s\")", timefmt(elapsed), timefmt(projected - elapsed))
  rs:addcmd("term.setCursorPos(1, h)")
  rs:addcmd("term.write(\"[%i / %i]\")", fixed_i, t)
  rs:addcmd("term.restore()")
  rs:send()
end

function execmon(dir)
  rednet.open(dir)
  while true do
    local senderId = nil msg = nil distance = nil
    senderId, msg, distance = rednet.receive()
    if starts(msg, "monitor ") then
      msg = starts(msg, "monitor ")
      msg = "local mon = peripheral.wrap(\"top\");"..msg
      local fun = loadstring(msg)
      print("execute "..msg)
      fun()
    end
  end
  rednet.close(dir)
end

function urlencode(data)
  local res = ""
  for i=1,data:len() do
    local ch = data:byte(i)
    if (ch >= 48 and ch <= 57) or
       (ch >= 65 and ch <= 90) or
       (ch >= 97 and ch <= 122)
    then
      res = res..data:sub(i,i)
    else
      res = res..string.format("%%%X%X", ch / 16, ch % 16)
    end
  end
  return res
end

function pastebin(data)
  local post = http.post(
    "http://pastebin.ca/quiet-paste.php?api=xWIbY4WQ4blCXWch/HfN5qq8GEAd06Ca",
    "type=1&expiry=1%20hour&content="..urlencode(data)
  )
  local res = post:readAll()
  if not starts(res, "SUCCESS:") then
    print(res)
    print("unexpected pastebin result; wanted \"SUCCESS\"")
    assert(false)
  end
  return "http://pastebin.ca/"..starts(res, "SUCCESS:")
end

trace = nil
function maketracing(fun, name)
  if type(fun) == "string" then
    assert(not name)
    local env = getfenv(2)
    local f = env[fun]
    if not f then
      printf("tried to maketracing(%s) but no such fun in getfenv(2)!", fun)
      assert(false)
    end
    env[fun] = maketracing(f, fun)
    return
  end
  assert(name)
  local prev = trace
  return function(...)
    trace = {name = name, prev = prev}
    -- printf("enter %s", name)
    local res = fun(...)
    -- printf("exit  %s", name)
    trace = prev
    return res
  end
end

function printbacktrace()
  local i = 1
  local cur = trace
  while cur do
    printf("%i: %s", i, cur.name)
    cur = cur.prev
  end
end

  ---- Input ----
function readch(returnvalue, test, direct)
  local blinktime = 0.2
  local blink = os.startTimer(blinktime)
  local blinkon = false
  local x, y = term.getCursorPos()
  local res = " "
  while true do
    local event, param = os.pullEvent()
    term.setCursorPos(x, y)
    if event == "timer" and param == blink then
      if blinkon then
        blinkon = false
        term.write("_")
      else
        blinkon = true
        term.write(res)
      end
      blink = os.startTimer(blinktime)
    elseif event == "char" then
      local t = test(param)
      if nil ~= t then
        if nil ~= returnvalue then return t end
        res = t
        blink = nil
        term.write(param)
      end
    elseif event == "key" then
      -- return and numpad return
      if (param == 28 or param == 156) then
        if nil ~= returnvalue then return returnvalue end
        if res then return res end
      end
      if direct then
        local otherwise = direct(param)
        if otherwise then return otherwise end
      end
    end
  end
end

  ---- Movement ----
function checkfuel()
  messaged = false
  while 0 == turtle.getFuelLevel() do
    turtle.select(16)
    turtle.refuel(1)
    if 0 == turtle.getFuelLevel() then
      if not messaged then
        messaged = true
        print("Please refuel")
      end
      sleep(1)
    end
  end
end

local digout = false
function checkfwd () if digout then turtle.dig()     end end
function checkup  () if digout then turtle.digUp()   end end
function checkdown() if digout then turtle.digDown() end end

local movestr = ""
function add(s) movestr = movestr..s end
function _fwd  () while not turtle.forward() do checkfuel(); checkfwd() end end
function _up   () while not turtle.up     () do checkfuel(); checkup() end end
function _down () while not turtle.down   () do checkfuel(); checkdown() end end
function _left () turtle.turnLeft () end
function _right() turtle.turnRight() end
function fwd  () add("F") end
function up   () add("U") end
function down () add("D") end
function left () add("L") end
function right() add("R") end
function move(s) add(s) end
function commit()
  movestr = optmove(movestr)
  --print("commit: "..movestr)
  --assert(false)
  for i=1,movestr:len() do
    ch = movestr:sub(i,i)
    if     (ch == "F") then _fwd  ()
    elseif (ch == "U") then _up   ()
    elseif (ch == "D") then _down ()
    elseif (ch == "L") then _left ()
    elseif (ch == "R") then _right()
    else error("wat :"..ch) end
  end
  movestr = ""
end
