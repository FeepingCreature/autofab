format = string.format
function printf(text, ...) print(format(text, ...)) end
function min(a, b) if a < b then return a else return b end end
function max(a, b) if a > b then return a else return b end end

shell.run("util")

args = { ... }

local start = 1 -- start of the item name

-- store internal stick - internal store; allow use of chest1
local internal = false
if args[start] == "internal" then internal = true; start = start + 1 end

-- store y stick - item already starts in high field (15)
local starts_high = false
if args[start] == "yes" then starts_high = true; start = start + 1 end

-- store 2 stick
local totransfer = nil
if tonumber(args[start]) then totransfer = tonumber(args[start]); start = start + 1 end

-- local startchest = 2
-- if internal then startchest = 1 end
local startchest = 1 -- not necessary now that we have load levelling

if not args[start] or args[start]:len() == 0 then
  error("Expected argument: item name")
end
local item = ""
for i=start,# args do
  if item:len() > 0 then item = item.." " end
  item = item..args[i]
end

if not knownitem(item) then error("Unknown item: "..item) end
local startfield = 1
if starts_high then startfield = 15 end
local count = turtle.getItemCount(startfield)
if count == 0 then error("No items found. Please use slot:1. ") end

local stacksize = turtle.getItemSpace(startfield) + count

totransfer = totransfer or count

for i=1,15 do if i ~= startfield and turtle.getItemCount(i) > 0 then
    error(format("Please clear slot:%i. ", i))
end end

if not starts_high then
  turtle.select(1)
  turtle.transferTo(15, totransfer)
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

local chestorder = {}
for i=startchest,countchests() do table.insert(chestorder, i) end
-- load levelling
chestcache = {}
table.sort(chestorder, function(ch1, ch2) return chest_usecost(ch1) < chest_usecost(ch2) end)
chestcache = nil

-- try to fill up existing chests first
for q,i in ipairs(chestorder) do
  -- printf("chest: %i = %i", q, i)
  local ch = chest(i)
  ch:with(function(slot)
    if slot.item == item then
      local freespace = stacksize - slot.count
      local tomove = min(freespace, totransfer)
      if tomove > 0 then
        ch:replace(slot.id, function()
          turtle.select(15)
          turtle.transferTo(slot.id, tomove)
          
          slot.count = slot.count + tomove
        end)
        totransfer = totransfer - tomove
      end
    end
  end)
end
-- now, fill the first empty slot with the rest
local i=1
while totransfer > 0 do
  if i > #chestorder then
    printf("No such chest: %i", i)
    assert(false)
  end
  local ch = chest(chestorder[i])
  ch:with(function(slot)
    if totransfer > 0 and slot.count == 0 then
      ch:replace(slot.id, function()
        turtle.select(15)
        turtle.transferTo(slot.id, totransfer)
        slot.count = totransfer
        slot.item = item
      end)
      totransfer = 0
    end
  end)
  i = i + 1
end
