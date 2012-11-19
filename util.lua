-- I fucking hate Lua.
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

function dup(tbl)
  res = {}
  for k, v in pairs(tbl) do res[k] = v end
  return res
end

function download(name, to)
  print(name.." --> "..to)
  data = http.get("http://feephome.no-ip.org/~feep/ftblua/"..name):readAll()
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
  shell.run("navigate", "0")
end

function withfile(fname, mode)
  return function(fun)
    local f = io.open(fname, mode)
    if not f then error ("No such file "..fname) end
    local res = fun(f)
    f:close()
    return res
  end
end

function starts(text, t2)
  if t2:len() > text:len() then return false end
  if text:sub(1,t2:len()) ~= t2 then return false end
  return text:sub(t2:len()+1, text:len())
end

function countit(s)
  local count = tonumber(split(s, " ", 1)[1])
  if count then s = split(s, " ", 1)[2]
  else count = 1 end
  return count, s
end

function chest(i)
  return {
    chestid = i,
    transferred = 0,
    filename = function(self) return string.format("chest%i.db", self.chestid) end,
    exists = function(self)
      local f = io.open(self:filename(), "r")
      local res = false
      if f then
        res = true
        f:close()
      end
      return res
    end,
    readopen = function(self)
      local f = io.open(self:filename(), "r")
      if not f then error(string.format("No such chest: %i", self.chestid)) end
      return f
    end,
    items = function(self)
      local res = 0
      self:with(function(tbl)
        if tbl.count > 0 then res = res + 1 end
      end)
      return res
    end,
    with = function(self, fun, passive, reverse)
      local f = self:readopen()
      local newdata = ""
      local myres = nil
      local count = 1
      if reverse then count = 14 end
      local loopbody = function(number, line)
        if (count > 1000) then
          self:close()
          assert(false)
        end
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
          local newline = string.format("%i %s", tbl.count, tbl.item)
          if not reverse then
            newdata = newdata.."\n"..newline
          else
            newdata = newline.."\n"..newdata
          end
        end
      end
      local lines = {}
      for line in f:lines() do table.insert(lines, line) end
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
          if not reverse then newdata = newdata.."\n"..line
          else newdata = line.."\n"..newdata end
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
      f:close()
      if not passive then
        
        f = io.open(self:filename(), "w")
        f:write(strip(newdata).."\n")
        f:close()
        
        self:close()
      end
      
      return myres
    end,
    withp = function(self, fun)
      return self:with(fun, true)
    end,
    withrev = function(self, fun)
      return self:with(fun, nil, true)
    end,
    open = function(self, to)
      if self.transferred >= to then return end
      shell.run("navigate", string.format("%i", self.chestid))
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
end

function cleanname(name)
  name = split(name, "[", 1)[1] or name
  return strip(name)
end

function _readrecipes()
  return withfile("recipes.db","r")(function(f)
    local map = {1,2,3,  5,6,7,  9,10,11}
    local res = {}
    local process = nil
    local function register(name)
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
      register(id)
      for k, v in pairs(thing) do res[id][k] = v end
    end
    for line in f:lines() do
      local define = starts(line, "define ");
      local craft = starts(line, "craft ");
      local alias = starts(line, "alias ");
      local smelt = starts(line, "smelt ");
      if process then
        process(line)
      elseif define then
        register(define)
      elseif smelt then
        local name = strip(split(smelt, "=", 1)[1])
        local count = 1
        count, name = countit(name)
        assert(name); register(name)
        name = cleanname(name)
        
        if res[name].mode then
          error("double definitions for "..name)
        end
        
        local list = fmap(split(split(smelt, "=", 1)[2], ","), strip)
        assert(list[1] and list[2] and not list[3])
        
        register(list[1])
        register(list[2])
        
        list[1] = cleanname(list[1])
        list[2] = cleanname(list[2])
        
        local fcount = 1 icount = 1
        icount, list[1] = countit(list[1])
        fcount, list[2] = countit(list[2])
        
        merge(name, {
          mode = "smelt",
          input = {count=icount, item=list[1]},
          fuel  = {count=fcount, item=list[2]},
          output= {count= count, item=name}
        })
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
              local name = list[num]
              assert(name)
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
      end
    end
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

function updatemon(i, t, tf, msg, ...)
  if not tf.starttime then
    tf.starttime = os.clock()
  end
  local elapsed = os.clock() - tf.starttime
  local projected = elapsed
  if i > 1 then projected = (elapsed / (i - 1)) * t end
  msg = string.format(msg, ...)
  local dir = "right"
  rednet.open(dir)
  local cmd = ""
  local function timefmt(t)
    t = math.floor(t)
    local mins = math.floor(t / 60)
    t = t - mins * 60
    local hours = math.floor(mins / 60)
    mins = mins - hours * 60
    if hours > 0 then return string.format("%ih%im", hours, mins)
    else return string.format("%im%i", mins, t) end
  end
  local function addcmd(s, ...)
    s = string.format(s, ...)
    if cmd:len() > 0 then cmd = cmd .. "; " end
    cmd = cmd .. s
  end
  addcmd("local mon = peripheral.wrap(\"top\")")
  addcmd("term.redirect(mon)")
  addcmd("local w, h = term.getSize()")
  addcmd("term.clear()")
  addcmd("term.setCursorPos(1, 1)")
  addcmd("term.write(\"%s\")", msg)
  addcmd("term.setCursorPos(1, h-1)")
  addcmd("term.write(\"%s eta %s\")", timefmt(elapsed), timefmt(projected - elapsed))
  addcmd("term.setCursorPos(1, h)")
  addcmd("term.write(\"[%i / %i]\")", i, t)
  addcmd("term.restore()")
  rednet.broadcast("monitor "..cmd)
  rednet.close(dir)
end

function execmon(dir)
  rednet.open(dir)
  while true do
    local senderId = nil msg = nil distance = nil
    senderId, msg, distance = rednet.receive()
    if starts(msg, "monitor ") then
      msg = starts(msg, "monitor ")
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
    print("unexpected pastebin result")
    print(res)
    assert(false)
  end
  return "http://pastebin.ca/"..starts(res, "SUCCESS:")
end
