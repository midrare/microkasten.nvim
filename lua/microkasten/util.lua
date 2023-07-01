local M = {}

local paths = require("microkasten.luamisc.paths")

function M.rename_bufs(p1, p2)
  if not p2 or #p2 <= 0 then
    return
  end

  local bufnr1 = vim.fn.bufnr(p1)
  local bufnr2 = vim.fn.bufnr(p1:gsub("[\\/]+", "/"))
  local bufnr3 = vim.fn.bufnr(p1:gsub("[\\/]+", "\\"))

  local old_winid = vim.fn.win_getid()

  for _, bufnr in ipairs({bufnr1, bufnr2, bufnr3}) do
    if bufnr >= 0 then
      vim.api.nvim_buf_set_name(bufnr, p2)
      for _, winid in ipairs(vim.fn.win_findbuf(bufnr)) do
        vim.api.nvim_set_current_win(winid)
        vim.cmd("silent! edit")
      end
    end
  end

  if old_winid >= 0 then
    vim.api.nvim_set_current_win(old_winid)
  end
end

---@param filename string file to open
---@param pick_win? boolean true to ask user for window
function M.open_in_window(filename, pick_win)
  if pick_win then
    local winnr = require("window-picker").pick_window({
      include_current_win = true,
      selection_chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890",
    })
    if winnr and winnr > 0 then
      vim.api.nvim_set_current_win(winnr)
      vim.cmd("silent! edit! " .. vim.fn.escape(filename, " "))
    end
  else
    vim.cmd("silent! edit " .. vim.fn.escape(filename, " "))
  end
end

return M
