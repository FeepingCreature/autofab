-- I fucking hate Lua.
function split(self, sep, max)
  assert(sep)
  assert(sep ~= '')
  max = max or -1
  assert(max == -1 or max >= 1)
  local rec = {}
  if self:len() > 0 then
    
    local field=1 start=1
    local first, last = string.find(self.."", sep, start)
    while first and max ~= 0 do
      rec[field] = self:sub(start, first-1)
      field = field + 1
      start = last + 1
      first, last = string.find(self.."", sep, start)
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

function chest(i)
  return {
    transferred = 0,
    filename = function(self) return string.format("chest%i.db", i) end,
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
      if not f then error(string.format("No such chest: %i", i)) end
      return f
    end,
    items = function(self)
      local res = 0
      self:with(function(tbl)
        if tbl.count > 0 then res = res + 1 end
      end)
      return res
    end,
    with = function(self, fun)
      local f = self:readopen()
      local newdata = ""
      local myres = nil
      local count = 1
      function loopbody(number, line)
        local tbl = {
          count = number,
          item = line,
          id  = count
        }
        count = count + 1
        local res = fun(tbl)
        if type(res) ~= "nil" then myres = res end
        if tbl.count > 0 then
          newdata = newdata.."\n"..string.format("%i %s", tbl.count, tbl.item)
        end
      end
      for line in f:lines() do
        if myres then -- already returned
          newdata = newdata.."\n"..line
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
      while count <= 14 do
        loopbody(0, "")
      end
      f:close()
      
      f = io.open(self:filename(), "w")
      f:write(strip(newdata).."\n")
      f:close()
      
      self:close()
      
      return myres
    end,
    open = function(self, to)
      if self.transferred >= to then return end
      shell.run("navigate", string.format("%i", i))
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

function readrecipes()
  return withfile("recipes.db","r")(function(f)
    local map = {1,2,3,  5,6,7,  9,10,11}
    local res = {}
    local process = nil
    function register(name)
      name = strip(name)
      if not res[name] then res[name] = {} end
    end
    for line in f:lines() do
      local define = starts(line, "define ");
      local craft = starts(line, "craft ");
      local alias = starts(line, "alias ");
      if process then
        process(line)
      elseif define then
        register(define)
      elseif craft then
        local name = strip(split(craft, "=", 1)[1])
        local count = tonumber(split(name, " ", 1)[1])
        if count then name = split(name, " ", 1)[2]
        else count = 1 end
        assert(name); register(name)
        
        if res[name] and res[name].mode then
          error("double definitions for "..name)
        end
        
        res[name].mode = "craft"
        
        local list = split(split(craft, "=", 1)[2], ",")
        local len = 0
        for i,v in ipairs(list) do
          len = len + 1
          list[i] = strip(list[i])
          register(list[i])
        end
        local shape = {}
        shape.len = len
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
        assert(name); register(name)
        local targets = fmap(split(strip(split(alias, "=", 1)[2]), ","), strip)
        for i,target in ipairs(targets) do register(target) end
        -- assert(not res[name].mode)
        if res[name].mode then
          printf("collision: while defining alias '%s': already %s", name, res[name].mode)
          assert(false);
        end
        res[name].mode = "alias"
        res[name].targets = targets
      end
    end
    return res
  end)
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
