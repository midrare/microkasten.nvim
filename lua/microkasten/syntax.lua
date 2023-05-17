local M = {}

local useropts = require("microkasten.useropts")

function M.apply_syntax()
  if useropts.apply_syntax then
    useropts.apply_syntax()
    return
  end
  vim.cmd("syntax region String matchgroup=String" .. " start=/\\[\\[/ skip=/[^\\[\\]]/ end=/\\]\\]/ display oneline")
  vim.cmd([[syntax match String "\v#[a-zA-Z]+[a-zA-Z0-9\\-_]*"]])
end

return M
