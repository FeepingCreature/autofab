shell.run("util")

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
local movestr = ""
function add(s) movestr = movestr..s end
function _fwd  () while not turtle.forward() do checkfuel() end end
function _up   () while not turtle.up     () do checkfuel() end end
function _down () while not turtle.down   () do checkfuel() end end
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
function moveto(loc)
  local location = getlocation()
  
  move(getinvnavinfo(location))
  move(getnavinfo(loc))
  -- printf("a: %s: %s", location, getinvnavinfo(location))
  -- printf("b: %s: %s", loc, getnavinfo(loc))
  -- assert(false)
  commit()
  f = io.open("location.txt","w")
  f:write(loc)
  f:close()
end
args = { ... }
if not args[1] then error("missing arg: destination expected") end
moveto(args[1])
