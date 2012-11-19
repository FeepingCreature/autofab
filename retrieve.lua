format = string.format
function printf(text, ...) print(format(text, ...)) end
function min(a, b) if a < b then return a else return b end end
function max(a, b) if a > b then return a else return b end end

shell.run("util")

args = { ... }

local all = tonumber(args[1])
if not all then error("Expected argument: item count") end
local left = all

local item = args[2]
local item = nil
for i=2,# args do
  item = item and (item .. " ")
  item = (item or "") .. args[i]
end
if not item then error("Expected argument: item name") end
if not knownitem(item) then error("Unknown item: "..item) end

for i=1,14 do if turtle.getItemCount(i) > 0 then
    error(format("Please clear slot:%i. ", i))
end end

function putback()
  local taken = all - left
  if taken > 0 then
    -- put it back
    turtle.select(15)
    turtle.transferTo(1, taken)
    assert(shell.run("store "..item))
  end
end

local i=1
while left > 0 do
  local ch = chest(i)
  if not ch:exists() then
    putback()
    error(format("out of %s: %i short", item, left))
  end
  failfun = nil
  -- must retrieve in REVERSE because otherwise item organization will get fucked up bad on store
  ch:withrev(function(slot)
    if not failfun and slot.item == item then
      local tomove = min(slot.count, left)
      if tomove > 0 then
        ch:replace(slot.id, function()
          turtle.select(slot.id)
          turtle.transferTo(15, tomove)
          slot.count = slot.count - tomove
        end)
        left = left - tomove
        local space = turtle.getItemSpace(15)
        local count = turtle.getItemCount(15)
        local total = space + count
        if space < left then
          -- store back
          tomove = min(count, total - slot.count)
          ch:replace(slot.id, function()
            turtle.select(15)
            turtle.transferTo(slot.id, tomove)
            slot.count = slot.count + tomove
          end)
          left = left + tomove
          
          failfun = function ()
            putback()
            printf("cannot retrieve %i %s", all, item)
            error(format("max stack size is %i", total))
          end
        end
      end
    end
  end)
  if failfun then failfun() end
  i = i + 1
end
