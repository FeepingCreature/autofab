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

retrieve = function()
  printheader("  retrieval")
  
  term.write("item name  = "); local name = read()
  term.write("item count = "); local num  = read()
  if tonumber(num) and tonumber(num) > 0 then
    print("")
    print("Retrieving .. ")
    local res = frun("retrieve %i %s", tonumber(num), name)
    frun("navigate 0")
    if not mcheck(res) then return end
    if turtle.getItemCount(15) > 0 then
      print("Please retrieve the item from slot:15.")
    end
    while turtle.getItemCount(15) > 0 do sleep(0.1) end
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
  frun("navigate 0")
  if not mcheck(res) then return end
end

craft = function()
  printheader("  crafting")
  term.write("result item = "); local item = read()
  term.write("number (1)  = "); local num  = read()
  if num == "" then num = "1" end
  local nn = tonumber(num)
  print()
  printf("  crafting %i '%s' .. ", nn, item)
  local res = true
  for i=1,nn do
    res = res and frun("make y %s", item)
  end
  frun("navigate 0")
  if not mcheck(res) then return end
  if turtle.getItemCount(15) > 0 then
    print("Please retrieve the item from slot:15.")
  end
  while turtle.getItemCount(15) > 0 do sleep(0.1) end
end

-- textutils.slowWrite(".........")
function selectmenu(tbl)
  printheader("Please select an action.")
  local i = 1
  local fulllen = 33
  for i,k2 in ipairs(tbl) do
    local k = tbl[k2]
    if k then
      local dots = fulllen - k2:len() - 1 - 3
      printf("%s %s  %i", k2, rep(".", dots), i)
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
mainmenu["retrieve"] = retrieve ; mainmenu[3] = "retrieve"
mainmenu["craft"   ] = craft    ; mainmenu[4] = "craft"
mainmenu["upgrade" ] = upgrade  ; mainmenu[5] = "upgrade"
mainmenu["shutdown"] = shutdown ; mainmenu[6] = "shutdown"
mainmenu["exit to shell"]=function() running = false end
mainmenu[7] = "exit to shell"
while running do selectmenu(mainmenu) end
cls()
