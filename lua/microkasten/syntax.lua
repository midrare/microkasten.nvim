local M = {}

function M.apply_syntax()
  vim.cmd('syntax region String matchgroup=String'
    .. ' start=/\\[\\[/ skip=/[^\\[\\]]/ end=/\\]\\]/ display oneline')
  vim.cmd[[syntax match String "\v#[a-zA-Z]+[a-zA-Z0-9\\-_]*"]]
end

return M
