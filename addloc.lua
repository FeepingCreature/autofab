local args = { ... }
shell.run("util")
shell.run("move")

printheader("add location")
term.write("location = "); local loc = read()
if not loc or loc:len() == 0 then return end

local movestr = readmovement()

local newloc = string.format("%s = %s", loc, movestr:lower())
addlocation(newloc)

term.write("location added.")

local f = io.open("location.txt","w")
f:write(loc)
f:close()
