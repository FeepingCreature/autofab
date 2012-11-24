for i,file in ipairs(fs.list("disk")) do
  if file:sub(-3,-1) == ".db" then
    local from = fs.combine("disk", file)
    local to = file
    
    assert(fs.exists(from))
    if fs.exists(to) then fs.delete(to) end
    fs.copy(from, to)
  end
end
