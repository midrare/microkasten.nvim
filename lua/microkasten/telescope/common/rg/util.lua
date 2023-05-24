local M = {}

local base64 = require("microkasten.luamisc.base64")

---@param o { text: string?, bytes: string? }
---@return string?
function M.decode(o)
  if o.text == nil and o.bytes ~= nil then
    o.text = base64.decode(o.bytes)
  end

  return o.text
end


return M
