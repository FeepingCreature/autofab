local args = { ... }
shell.run("util")
local chestnum = tonumber(args[1])
local movestr = args[2]
if not chestnum and movestr then
  print("Usage: makechest [<number> <movement string>]")
  return
end

if not chestnum then
  -- assert(args[1])
  assert(not args[2])
  chestnum = 1
  while chest(chestnum):exists() do chestnum = chestnum + 1 end
  movestr = args[1]
end

function readmove()
  return readch("X", function(param)
    if param == "l" or param == "r"
        or param == "u" or param == "d"
        or param == "f"
    then
      return param
    end
  end, function(param)
    if param == 14 then return "Y" end
  end)
end

-- if we manually navigated to the chest, write our location.db as the one we're about to add
local writeloc = false

function inv(ch)
  if ch == "F" then return "LLFLL" -- B
  elseif ch == "L" then return "R"
  elseif ch == "R" then return "L"
  elseif ch == "U" then return "D"
  elseif ch == "D" then return "U"
  end
  print("?? "..ch)
  assert(false)
end

if not movestr then
  -- assert(shell.run("navigate", "origin"))
  movestr = optmove(getnavinfo(getlocation()))
  local done = false
  local actuallyact = nil
  function control()
    term.clear()
    -- term.setCursorPos(1,1)
    term.setCursorPos(2,2)
    print("Please enter movement commands: ")
    term.write("> "..movestr:lower())
    if actuallyact then actuallyact(); actuallyact = nil end
    local ch = readmove():upper()
    if (ch == "X") then
      done = true
      return
    end
    if (ch == "Y") then -- backspace, lol
      if movestr:len() == 0 then ch = ""
      else
        ch = inv(movestr:sub(movestr:len(), movestr:len()))
      end
    end
    actuallyact = function()
      move(ch)
      commit()
    end
    movestr = optmove(movestr..ch)
  end
  while not done do control() end
  writeloc = true
end

local ch = chest(chestnum)
if ch:exists() then
  printf("Error: chest %i already exists. ", chestnum)
  assert(false)
end

local prevch = chest(chestnum - 1)
if not prevch:exists() then
  printf("Error: discontinuity when creating %i: %i doesn't exist. ", chestnum, chestnum - 1)
  assert(false)
end

local chestfile = makechestfilename(chestnum)
local chestname = string.format("chest%i", chestnum)
local prevchestname = string.format("chest%i", chestnum - 1)

if gotnavinfo(chestname) then
  printf("Error: chest %i already has navigation info. ", chestnum)
  assert(false)
end

if not gotnavinfo(prevchestname) then
  printf("Error: discontinuity when creating %i: %i doesn't have navigation info. ", chestnum, chestnum - 1)
  assert(false)
end

local f = io.open(chestfile, "w")
f:write("")
f:close()

f = io.open("locations.db", "r")
local l = {}
for line in f:lines() do
  table.insert(l, line)
end
f:close()
local newloc = string.format("chest%i = %s", chestnum, movestr:lower())
table.insert(l, newloc)

f = io.open("locations.db", "w")
f:write(join(l, "\n"))
f:close()

if writeloc then
  f = io.open("location.txt","w")
  f:write(string.format("chest%i", chestnum))
  f:close()
end
