local args = { ... }
shell.run("util")
local chestnum = tonumber(args[1])
local movestr = args[2]
if (not chestnum or not movestr) and (chestnum or not args[1] or args[2]) then
  print("Usage: makechest [<number>] <movement string>")
  return
end

if not chestnum then
  assert(args[1])
  assert(not args[2])
  chestnum = 1
  while chest(chestnum):exists() do chestnum = chestnum + 1 end
  movestr = args[1]
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

local chestfile = string.format("chest%i.db", chestnum)
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
table.insert(l, string.format("chest%i = %s", chestnum, movestr))

f = io.open("locations.db", "w")
f:write(join(l, "\n"))
f:close()
