local modulename, _ = ...
local os = require('os')

local paths = require((modulename or 'microkasten') .. '.luamisc.paths')
local picker = require((modulename or 'microkasten') .. '.picker')
local state = require((modulename or 'microkasten') .. '.state')
local util = require((modulename or 'microkasten') .. '.util')

local file_extensions = { '.md', '.norg' }

local function get_current_uid()
  local uid = vim.fn.expand('%:p:t')
  return (uid and util.parse_uid(uid)) or nil
end

local function parse_link_at(row, col)
  local line = vim.fn.getline(row)
  local contents = nil

  local i = 1
  while i <= #line do
    local start, stop = line:find(util.link_pattern, i)
    if not start or not stop then
      break
    elseif start <= col and stop >= col then
      local entire = line:sub(start, stop)
      contents = (entire or ''):match(util.link_pattern)
      break
    end
    i = stop + 1
  end

  local seq = nil
  local uid = nil
  local label = nil
  if contents and #contents > 0 then
    label = contents:match('|%s*(.+)$')
    if label and #label > 0 then
      contents = contents:match('^(.*)%s*|')
    end

    seq = contents:match('^(.+)%s*:')
    if seq and #seq > 0 then
      contents = contents:match(':%s*(.*)%s*$')
    end

    uid = contents:match('^%s*(.*)%s*$')
  end

  return uid, label, seq
end

local function parse_link_at_cursor()
  local pos = vim.fn.getpos('.')
  local row = pos[2]
  local col = pos[3]
  return parse_link_at(row, col)
end

local function list_filenames(dir, prefix)
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

local function open_note_in_dir(uid, dir, pick_win)
  local filenames = list_filenames(dir, uid)
  if filenames and #filenames > 0 then
    table.sort(filenames)
    if #filenames[1] > 0 then
      if pick_win then
        local winnr = require('window-picker').pick_window({
          include_current_win = true,
          selection_chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890',
        })
        if winnr and winnr > 0 then
          vim.api.nvim_set_current_win(winnr)
          vim.cmd('silent! edit! ' .. vim.fn.escape(filenames[1], ' '))
        end
      else
        vim.cmd('silent! edit ' .. vim.fn.escape(filenames[1], ' '))
      end
    end
  end
end

local function create_note_at(dir, title, file_ext)
  if not dir or #dir <= 0 then
    dir = vim.fn.getcwd(-1, -1)
  end
  dir = vim.fn.fnamemodify(dir, ':p')

  file_ext = (file_ext and file_ext:lower())
    or state.default_extension
    or state.file_extensions[1]
    or '.md'
  if file_ext:sub(1, 1) ~= '.' then
    file_ext = '.' .. file_ext
  end

  local filename = util.generate_uid()
  if title and #title > 0 then
    filename = filename .. ' ' .. title
  end
  filename = filename .. file_ext

  local path_sep = '/'
  if vim.fn.has('win32') > 0 then
    path_sep = '\\'
  end

  local filepath = dir .. path_sep .. filename
  vim.cmd(
    'silent! edit! ' .. vim.fn.escape(filepath, ' ') .. ' | silent! write'
  )
end

local function retitle_note_at(filepath, title)
  local cwd = vim.fn.getcwd(-1, -1)
  local src_fn = paths.canonical(filepath, cwd)
  local target_fn = util.to_retitled_filename(src_fn, title)

  vim.fn.mkdir(paths.dirname(target_fn), 'p')
  vim.fn.rename(src_fn, target_fn)

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

local action_to_callback = {
  put_uid = function(e)
    if e.uid and #e.uid > 0 then
      vim.api.nvim_put({ e.uid }, 'b', false, true)
    end
  end,
  put_path = function(e)
    if e.path and #e.path > 0 then
      vim.api.nvim_put({ e.path }, 'b', false, true)
    end
  end,
  yank_uid = function(e)
    vim.fn.setreg('"', e.uid)
  end,
  yank_path = function(e)
    vim.fn.setreg('"', e.path)
  end,
  open = function(e)
    if e.path and #e.path > 0 then
      local winnr = require('window-picker').pick_window({
        include_current_win = true,
        selection_chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890',
      })
      if winnr and winnr > 0 then
        vim.api.nvim_set_current_win(winnr)
        vim.cmd('edit! ' .. vim.fn.escape(e.path, ' '))
      end
    end
  end,
}

local M = {}

function M.setup(opts)
  opts = opts or {}

  state.file_extensions = opts.file_extensions or file_extensions
  state.default_extension = opts.default_extension or file_extensions[1]

  _MicrokastenOnAttach = nil

  vim.cmd('augroup microkasten_syntax')
  vim.cmd('autocmd!')

  for _, ext in ipairs(state.file_extensions) do
    ext = ext:gsub('^%.+', '')
    if ext and #ext > 0 then
      vim.cmd(
        'autocmd BufEnter,BufRead,BufNewFile *.'
          .. ext
          .. ' '
          .. 'syntax region String matchgroup=String '
          .. 'start=/\\[\\[/ end=/\\]\\]/ display oneline'
      )
      vim.cmd(
        'autocmd BufEnter,BufRead,BufNewFile *.'
          .. ext
          .. ' '
          .. 'syntax match String "\v#[a-zA-ZÀ-ÿ]+[a-zA-ZÀ-ÿ0-9/\\-_]*"'
      )

      if type(opts.on_attach) == 'function' then
        _MicrokastenOnAttach = opts.on_attach
        vim.cmd(
          'autocmd BufEnter,BufRead,BufNewFile *.'
            .. ext
            .. ' '
            .. 'lua if _MicrokastenOnAttach then _MicrokastenOnAttach() end'
        )
      end
    end
  end

  vim.cmd('augroup END')
end

function M.open_link_at_cursor(dir, pick_win)
  if not dir then
    dir = vim.fn.expand('%:p:h')
  end
  local uid, _, _ = parse_link_at_cursor()
  if uid and #uid > 0 then
    open_note_in_dir(uid, dir, pick_win)
  end
end

function M.open_note(uid, dir, pick_win)
  open_note_in_dir(uid, dir, pick_win)
end

function M.open_filename_finder(action)
  action = action or 'open'
  picker.open_filename_picker(vim.fn.getcwd(-1, -1), action_to_callback[action])
end

function M.open_live_grep_finder(action)
  action = action or 'open'
  picker.open_live_grep_picker(
    vim.fn.getcwd(-1, -1),
    action_to_callback[action]
  )
end

function M.open_backlink_finder(action)
  action = action or 'open'
  local uid = get_current_uid()
  if uid and uid ~= '' then
    picker.open_backlink_picker(
      uid,
      vim.fn.getcwd(-1, -1),
      action_to_callback[action]
    )
  end
end

function M.parse_uid(filename)
  return util.parse_uid(filename)
end

function M.get_current_uid()
  return get_current_uid()
end

function M.parse_link_at(row, col)
  return parse_link_at(row, col)
end

function M.parse_link_at_cursor()
  return parse_link_at_cursor()
end

function M.create_note_at(dir, title, file_ext)
  create_note_at(dir, title, file_ext)
end

function M.create_note()
  vim.ui.input({ prompt = 'Note title: ', default = '' }, function(title)
    title = (title or ''):gsub('^%s*', ''):gsub('%s*$', '')
    if title and #title > 0 then
      create_note_at(nil, title, nil)
    end
  end)
end

function M.retitle_note_at(filepath, title)
  retitle_note_at(filepath, title)
end

function M.retitle_current_note()
  local filepath = vim.fn.expand('%:p')
  if filepath and #filepath > 0 then
    vim.ui.input({ prompt = 'Rename note: ', default = '' }, function(title)
      title = (title or ''):gsub('^%s*', ''):gsub('%s*$', '')
      if title and #title > 0 then
        retitle_note_at(filepath, title)
      end
    end)
  end
end

function M.generate_uid()
  return util.generate_uid()
end

return M
