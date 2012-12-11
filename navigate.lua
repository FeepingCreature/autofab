shell.run("util")
function moveto(loc)
  local location = getlocation()
  
  move(getinvnavinfo(location))
  move(getnavinfo(loc))
  -- printf("a: %s: %s", location, getinvnavinfo(location))
  -- printf("b: %s: %s", loc, getnavinfo(loc))
  -- assert(false)
  commit()
  sleep(0)
  f = io.open("location.txt","w")
  f:write(loc)
  f:close()
end
args = { ... }
if not args[1] then error("missing arg: destination expected") end
moveto(args[1])
