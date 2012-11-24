for i,file in ipairs(fs.list("/")) do
  if file:sub(-3,-1) == ".db" then
    local from = file
    local to = fs.combine("disk", file)
    
    assert(fs.exists(from))
    if fs.exists(to) then fs.delete(to) end
    fs.copy(from, to)
  end
end
