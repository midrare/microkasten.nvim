local M = {}

local date = require('microkasten.luamisc.date')
local paths = require('microkasten.luamisc.paths')


local function find_pat_at(pat, s, idx)
  local pos = 1
  while pos <= #s do
    local start, stop = s:find(pat, pos)
    if not start or not stop then
      break
    end
    if start <= idx and stop >= idx then
      return s:sub(start, stop)
    end
    pos = stop + 1
  end
  return nil
end


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
        vim.cmd('silent! write!')
      end
      vim.api.nvim_set_current_win(orig_winid)
    end
  end
end

---@param pat? string link pattern
---@param pos? cursor cursor pos
---@return string? link link string
M.get_link_at = function(pos, pat)
  pat = pat or '%[%[..*%]%]'
  if not pos then
    local o = vim.fn.getpos('.')
    pos = { row = o[2], col = o[3] }
  end

  local line = vim.fn.getline(pos.row)
  if not line or #line <= 0 then
    return nil
  end

  return find_pat_at(pat, line, pos.col)
end

---@param dir string path to dir
---@param prefix string? include only if start of filename matches
---@return string[] filenames filenames in dir
M.list_dir = function(dir, prefix)
  prefix = (prefix and prefix:gsub('[^a-zA-Z0-9_%-:# %.]', '')) or nil
  local filenames = {}

  local cmd = ''
  if vim.fn.has('win32') > 0 then
    local p = dir:gsub('[\\/]+', '\\')
    if prefix and #prefix > 0 then
      p = p .. '\\' .. prefix .. '*'
    end
    -- do /not/ escape backslashes if you want dir command to work
    cmd = 'dir /B "' .. vim.fn.escape(p, '"') .. '" 2>nul'
  else
    local p = dir:gsub('[\\/]+', '/')
    if prefix and #prefix > 0 then
      p = p .. '/' .. prefix
    end
    cmd = 'ls -A -1 "' .. vim.fn.escape(p, '"') .. '"* 2>/dev/null'
  end

  local status_ok, pipe = pcall(io.popen, cmd)
  if status_ok and pipe ~= nil then
    local output = pipe:read('*a')
    pipe:close()

    for line in string.gmatch(output .. '\n', '([^\n]*)\n') do
      line = line:gsub('^%s*', ''):gsub('%s*$', '')
      if #line > 0 then
        table.insert(filenames, line)
      end
    end
  end

  return filenames
end

---@param filename string file to open
---@param pick_win? boolean true to ask user for window
M.open_in_window = function(filename, pick_win)
  if pick_win then
    local winnr = require('window-picker').pick_window({
      include_current_win = true,
      selection_chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890',
    })
    if winnr and winnr > 0 then
      vim.api.nvim_set_current_win(winnr)
      vim.cmd('silent! edit! ' .. vim.fn.escape(filename, ' '))
    end
  else
    vim.cmd('silent! edit ' .. vim.fn.escape(filename, ' '))
  end
end

---@return string timestamp timestamp for note metadata
function M.generate_timestamp()
  local datetime_pat = '%Y/%m/%d %I:%M %p %Z'
  local dt = date(true)
  return dt:fmt(datetime_pat)
end

return M
