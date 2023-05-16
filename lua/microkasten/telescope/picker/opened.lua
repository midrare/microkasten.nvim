local M = {}

local paths = require('microkasten.luamisc.paths')

M.get_open_filelist = function(cwd)
  local bufnrs = vim.tbl_filter(function(b)
    if 1 ~= vim.fn.buflisted(b) then
      return false
    end
    return true
  end, vim.api.nvim_list_bufs())
  if not next(bufnrs) then
    return
  end

  local filelist = {}
  for _, bufnr in ipairs(bufnrs) do
    local file = vim.api.nvim_buf_get_name(bufnr)
    table.insert(filelist, paths.relpath(file, cwd))
  end
  return filelist
end

return M
