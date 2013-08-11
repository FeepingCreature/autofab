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

shell.run("move")

-- if we manually navigated to the chest, write our location.db as the one we're about to add
local writeloc = false

if not movestr then
  movestr = readmovement()
  if not movestr then return end
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

local newloc = string.format("chest%i = %s", chestnum, movestr:lower())
addlocation(newloc)

if writeloc then
  f = io.open("location.txt","w")
  f:write(string.format("chest%i", chestnum))
  f:close()
end
