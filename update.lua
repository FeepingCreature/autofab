shell.run("util")
local args = { ... }
if args[1] then
  update(args[1])
else
  update("update") -- lol
  update("make")
  update("store")
  update("retrieve")
  update("navigate")
  update("util")
  update("mainmenu")
  update("recipes.db")
  update("makechest")
  os.reboot()
end
