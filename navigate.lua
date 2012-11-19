function times(k, f)
  for i=1,k do f() end
end
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
  local changed = true
  while changed do
    local start = movestr
    movestr = movestr
      :gsub("FRRF", "RR"):gsub("FLLF", "LL")
      :gsub("ULLD", "LL"):gsub("URRD", "RR")
      :gsub("LR", ""):gsub("RL", "")
      :gsub("DU", ""):gsub("UD", "")
      :gsub("LLLL", ""):gsub("RRRR", "")
      :gsub("LLL", "R"):gsub("RRR", "L")
    changed = movestr ~= start
  end
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
  if loc == "monitor" then loc = "1" end
  
  f = io.open("location.txt", "r")
  location = 0
  if f then
    location = f:read()
    f:close()
  end
  loc_i = tonumber(loc)
  location_i = tonumber(location)
  -- home
  if location == loc then return end
  if location == "-1" then move("RRFFLUF") end
  if location_i and location_i > 0 then
    left()
    times(location_i*2-2, fwd)
    up()
    fwd()
  end
  if location == "furnace_fuel" then move("DLLFFFFFFFFRFFFLFFLUF") end
  if location == "furnace_input" then move("DDDLLFFFFFFFFRFFFLFFLUF") end
  if location == "furnace_output" then move("DDLFFFLFFFFFFFFRFFFLFFLUF") end
  -- and to target
  if loc == "-1" then
    move("LLFDRFF")
  end
  if loc_i and loc_i > 0 then
    move("RRFD")
    times(loc*2-2, fwd)
    left()
  end
  if loc == "furnace_fuel" then move("LLFDRFFRFFFLFFFFFFFFU") end
  if loc == "furnace_input" then move("LLFDRFFRFFFLFFFFFFFFUUU") end
  if loc == "furnace_output" then move("LLFDRFFRFFFLFFFFFFFFRFFFLUU") end
  commit()
  f = io.open("location.txt","w")
  f:write(loc)
  f:close()
end
args = { ... }
if not args[1] then error("missing arg: destination expected") end
moveto(args[1])
