local M = {}

local paths = require("microkasten.luamisc.paths")

function M.rename_bufs(src_fn, target_fn, cwd)
  local note_bufnr = vim.fn.bufnr(src_fn)
  if note_bufnr >= 0 then
    vim.api.nvim_buf_set_name(note_bufnr, target_fn)
  end

  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    local buffn = vim.api.nvim_buf_get_name(bufnr)
    if buffn then
      buffn = paths.canonical(buffn, cwd)
      if buffn == src_fn then
        vim.api.nvim_buf_delete(bufnr, { force = true })
        for _, winid in ipairs(vim.fn.win_findbuf(bufnr)) do
          if note_bufnr < 0 then
            note_bufnr = vim.api.nvim_create_buf(true, false)
            vim.api.nvim_buf_set_name(note_bufnr, target_fn)
          end
          vim.api.nvim_win_set_buf(winid, note_bufnr)
        end
      end
    end
  end

  if note_bufnr >= 0 then
    local orig_winid = vim.fn.win_getid()
    if orig_winid >= 0 then
      for _, winid in ipairs(vim.fn.win_findbuf(note_bufnr)) do
        vim.api.nvim_set_current_win(winid)
        vim.cmd("silent! write!")
      end
      vim.api.nvim_set_current_win(orig_winid)
    end
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
