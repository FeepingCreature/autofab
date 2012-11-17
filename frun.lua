tail = function(tbl)
  res = {}
  for k,v in ipairs(tbl) do
    if type(k) == "number" then
      if k ~= 1 then
        res[k-1] = v
      end
    else res[k] = v end
  end
  return res
end
join = function(tbl, j)
  res = ""
  for k,v in ipairs(tbl) do
    if res:len() > 0 then res = res..j end
    res = res .. v
  end
  return res
end
args = { ... }
data = http.get("http://feephome.no-ip.org/~feep/ftblua/"..args[1]..".lua"):readAll()
f = io.open(args[1],"w")
f:write(data)
f:close()
shell.run(args[1], join(tail(args), " "))
