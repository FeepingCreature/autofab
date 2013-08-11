shell.run("util")
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

function readmovement()
  printheader("navigate")
  term.write("Enter start location: ")
  local start = read()
  if start and start:len() > 0 then
    shell.run("navigate", start)
  end
  -- assert(shell.run("navigate", "origin"))
  local res = optmove(getnavinfo(getlocation()))
  local done = false
  local actuallyact = nil
  function control()
    term.clear()
    -- term.setCursorPos(1,1)
    term.setCursorPos(2,2)
    print("Please enter movement commands: ")
    term.write("> "..res:lower())
    if actuallyact then actuallyact(); actuallyact = nil end
    local ch = readmove():upper()
    if (ch == "X") then
      done = true
      return
    end
    if (ch == "Y") then -- backspace, lol
      if res:len() == 0 then ch = ""
      else
        ch = inv(res:sub(res:len(), res:len()))
      end
    end
    actuallyact = function()
      move(ch)
      commit()
    end
    res = optmove(res..ch)
  end
  while not done do control() end
  return res
end

function addlocation(line)
  local f = io.open("locations.db", "r")
  local l = {}
  for line in f:lines() do
    table.insert(l, line)
  end
  f:close()
  
  table.insert(l, line)

  f = io.open("locations.db", "w")
  f:write(join(l, "\n"))
  f:close()
end
