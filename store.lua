format = string.format
function printf(text, ...) print(format(text, ...)) end
function min(a, b) if a < b then return a else return b end end
function max(a, b) if a > b then return a else return b end end

shell.run("util")

args = { ... }

local start = 1
local starts_high = false
if args[1] == "yes" then starts_high = true; start = 2 end

if not args[start] or args[start]:len() == 0 then
  error("Expected argument: item name")
end
local item = ""
for i=start,# args do
  if item:len() > 0 then item = item.." " end
  item = item..args[i]
end

if not knownitem(item) then error("Unknown item: "..item) end
local startpos = 1
if starts_high then startpos = 15 end
local count = turtle.getItemCount(startpos)
if count == 0 then error("No items found. Please use slot:1. ") end

local stacksize = turtle.getItemSpace(startpos) + count

for i=1,15 do if i ~= startpos and turtle.getItemCount(i) > 0 then
    error(format("Please clear slot:%i. ", i))
end end

if not starts_high then
  turtle.select(1)
  turtle.transferTo(15, count)
end

function countchests()
  local res = 0
  while true do
    local f = io.open(format("chest%i.db", res + 1))
    if not f then return res end
    f:close()
    res = res + 1
  end
end

-- try to fill up existing chests first
for i=1,countchests() do
  local ch = chest(i)
  ch:with(function(slot)
    if slot.item == item then
      local freespace = stacksize - slot.count
      local tomove = min(freespace, count)
      if tomove > 0 then
        ch:replace(slot.id, function()
          turtle.select(15)
          turtle.transferTo(slot.id, tomove)
          
          slot.count = slot.count + tomove
        end)
        count = count - tomove
      end
    end
  end)
end
-- now, fill the first empty slot with the rest
local i=1
while count > 0 do
  local ch = chest(i)
  ch:with(function(slot)
    if count > 0 and slot.count == 0 then
      ch:replace(slot.id, function()
        turtle.select(15)
        turtle.transferTo(slot.id, count)
        slot.count = count
        slot.item = item
      end)
      count = 0
    end
  end)
  i = i + 1
end
