local M = {}

local pack_varargs = table.pack or function(...)
  local a = {}
  for i = 1, select("#", ...) do
    table.insert(a, select(i, ...))
  end
  return a
end

---@diagnostic disable-next-line: deprecated, unused-local
local unpack_varargs = table.unpack or unpack

function M.set_attrs(tbl, ...)
  local lazy_attrs = pack_varargs(...)
  return setmetatable(tbl, {
    __index = function(o, name)
      local value = rawget(o, name)
      if value ~= nil then
        return value
      end

      for _, attrs in ipairs(lazy_attrs) do
        value = rawget(attrs, name)

        -- display() only highlights properly if it's returned as a function
        if type(value) == "function" and name ~= "display" then
          local f = value
          value = f(o)
        end

        if value ~= nil then
          rawset(o, name, value)
          return value
        end
      end

      return nil
    end,
  })
end

return M
