format = string.format
function printf(text, ...) print(format(text, ...)) end
function frun(text, ...) return shell.run(format(text, ...)) end
function rep(s, i)
  res = ""
  for k=1,i do res = res..s end
  return res
end

shell.run("util")

function cls()
  term.clear()
  term.setCursorPos(1,1)
end
function readnum(test)
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
      local num = tonumber(param)
      if num and test(num) then
        res = param
        blink = nil
        term.write(res)
      end
    elseif event == "key" then
      if res and (param == 28 or param == 156) then
        return tonumber(res)
      end
    end
  end
end
function wait(msg)
  msg = msg or ""
  print(msg.."Press any key to continue.")
  os.pullEvent("key")
end
function mcheck(b)
  if not b then wait() end
  return b
end

function printheader(msg)
  cls()
  local space = 28
  -- 39 chars
  print("                            +---------+")
  print("                            |INVENTORY|")
--print("  Please select an action.  +---------+")
  print("  "..msg..rep(" ", space-msg:len()-2).."+---------+")
  print("")
end

upgrade = function()
  printheader("  upgrading")
  if not mcheck(frun("update")) then return end
end

shutdown = function()
  os.shutdown()
end

list = function()
  printheader("  inventory")
  term.write("match = "); local term = read()
  printheader("  inventory["..term.."]")
  function matches(s)
    local res = false
    if s:find(term) then res = true end
    return res
  end
  local items = regenInv()
  local lines = 7
  local left = lines
  local pages = 1
  for k, v in pairs(items) do if v > 0 and matches(k) then
    left = left - 1
    if left == 0 then pages = pages + 1; left = lines; end
  end end
  left = lines
  local page = 1
  for k, v in pairs(items) do if v > 0 and matches(k) then
    printf("%i%s%s", v, rep(" ", 5-format("%i",v):len()), k)
    left = left - 1
    if left == 0 then
      wait(format("(%i/%i) ", page, pages))
      page = page + 1
      printheader("  inventory["..term.."]")
      left = lines
    end
  end end
  while left > 0 do print(); left = left - 1 end
  wait(format("(%i/%i) ", page, pages))
end

validate = function()
  printheader("  validation")
  print("validating chests .. ")
  
  local data = ""
  
  local itemdata = readrecipes()
  local chestid=1
  while true do
    local ch = chest(chestid)
    if not ch:exists() then
      if data:len() == 0 then
        print("No errors. ")
      elseif data:len() < 100 then
        print(data)
      else
        print(pastebin(data))
      end
      frun("navigate home")
      wait()
      return
    end
    -- compare item numbers
    ch:withp(function(slot)
      ch:open(slot.id) -- grab all
      local c = turtle.getItemCount(slot.id)
      local s = turtle.getItemSpace(slot.id)
      if slot.count ~= c then
        data = data..format("Error in chest %i index %i (%s): tracking %i but found %i\n",
          chestid, slot.id, slot.item, slot.count, c)
      else
        local maxsize = itemdata[slot.item] and itemdata[slot.item].stacksize
        if maxsize and maxsize ~= s + c then
          data = data..format("Error in chest %i index %i (%s): maximum size was %i, expected %i for material\n",
            chestid, slot.id, slot.item, c+s, maxsize)
        end
      end
    end)
    -- compare item types
    ch:with(function(slot)
      if slot.item:len() > 0 then
        turtle.select(slot.id)
        ch:withp(function(slot2)
          if slot2.id ~= slot.id and slot.item == slot2.item then
            if not turtle.compareTo(slot2.id) then
              data = data..format("Error in chest %i: %i and %i should be the same, but differ\n",
                chestid, slot.id, slot2.id)
            end
          end
        end)
      end
    end)
    chestid = chestid + 1
  end
end

store = function()
  printheader("  store")
  
  term.write("item name  = "); local name = read()
  if not name or name:len() == 0 then return end
  
  if turtle.getItemCount(1) == 0 then
    print("Please place the item in slot:1.")
  end
  while turtle.getItemCount(1) == 0 do sleep(0.1) end
  print("")
  print("Storing .. ")
  local res = frun("store %s", name)
  frun("navigate home")
  if not mcheck(res) then return end
end

request = function(plan)
  if plan then printheader("  planning")
  else printheader("  requesting") end
  term.write("result item = "); local item = read()
  local num = split(strip(item), " ", 1)[1]
  if tonumber(num) then
    item = split(strip(item), " ", 1)[2]
  else
    num = "1"
  end
  -- term.write("number (1)  = "); local num  = read()
  local nn = tonumber(num)
  print()
  if plan then
    frun("make _plan y %i %s", nn, item)
    wait()
    return
  end
  printf("  requesting %i '%s' .. ", nn, item)
  local res = frun("make y %i %s", nn, item)
  frun("navigate home")
  if not mcheck(res) then return end
  if turtle.getItemCount(15) > 0 then
    print("Please retrieve the item from slot:15.")
  end
  while turtle.getItemCount(15) > 0 do sleep(0.1) end
end

plan = function() return request(true) end

-- textutils.slowWrite(".........")
function selectmenu(tbl)
  printheader("Please select an action.")
  local i = 1
  local fulllen = 28
  local leftspace = 8
  for i,k2 in ipairs(tbl) do
    local k = tbl[k2]
    if k then
      local dots = fulllen - k2:len() - 1 - 2 - leftspace
      printf("%s%s %s %i", rep(" ", leftspace), k2, rep(".", dots), i)
    end
    i = i + 1
  end
  print("")
  term.write(rep(" ", fulllen - 2).."[")
  
  local x, y = term.getCursorPos()
  term.write(" ]")
  term.setCursorPos(x, y)
  
  local n = readnum(function(num)
    for i,k2 in ipairs(tbl) do
      local k = tbl[k2]
      if k and num == i then return true end
    end
    return false
  end)
  local i = 1
  for i,k2 in ipairs(tbl) do
    local k = tbl[k2]
    if k then
      if i == n then k() end
    end
    i = i + 1
  end
end
local mainmenu = {}
local running = true
mainmenu["list"    ] = list     ; mainmenu[1] = "list"
mainmenu["store"   ] = store    ; mainmenu[2] = "store"
mainmenu["request" ] = request  ; mainmenu[3] = "request"
mainmenu["plan"    ] = plan     ; mainmenu[4] = "plan"
mainmenu["upgrade" ] = upgrade  ; mainmenu[5] = "upgrade"
mainmenu["shutdown"] = shutdown ; mainmenu[6] = "shutdown"
mainmenu["validate"] = validate ; mainmenu[7] = "validate"
mainmenu["exit to shell"]=function() running = false end
mainmenu[8] = "exit to shell"
while running do selectmenu(mainmenu) end
cls()
