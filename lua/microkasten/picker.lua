local modulename, _ = ...
local moduleroot = (modulename or 'microkasten.x'):gsub('(.+)%..+', '%1')

local os = require('os')

local paths = require(moduleroot .. '.luamisc.path')
local state = require(moduleroot .. '.state')
local util = require(moduleroot .. '.util')

local Path = require('plenary.path')

local actions = require('telescope.actions')
local actions_state = require('telescope.actions.state')
local conf = require('telescope.config').values
local finders = require('telescope.finders')
local make_entry = require('telescope.make_entry')
local pickers = require('telescope.pickers')
local previewers = require('telescope.previewers')
local sorters = require('telescope.sorters')
local utils = require('telescope.utils')

local M = {}

local get_open_filelist = function(cwd)
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
    table.insert(filelist, Path:new(file):make_relative(cwd))
  end
  return filelist
end

local function gen_entry_maker(opts)
  local function to_display(e)
    local hls = {}
    local display = e.title

    if opts.show_uid and e.uid and #e.uid > 0 then
      display = e.uid .. ' ' .. display
    end

    local icon, icon_hl = utils.get_devicons(e.filename, opts.disable_devicons)
    if icon and icon_hl then
      display = icon .. ' ' .. display
    end

    if icon and icon_hl then
      table.insert(hls, { { 1, 3 }, icon_hl })
    end

    if opts.show_uid and e.uid and #e.uid > 0 then
      local start = 1
      if icon and icon_hl then
        start = 4
      end
      table.insert(hls, { { start, start + #e.uid }, 'Comment' })
    end

    return display, hls
  end

  local cwd = vim.fn.expand(opts.cwd or vim.loop.cwd())

  local key_to_gen = {
    filename = function(e)
      return vim.fn.fnamemodify(e.value, ':t')
    end,
    filestem = function(e)
      return vim.fn.fnamemodify(e.filename, ':r')
    end,
    uid = function(e)
      return util.parse_uid(e.filename)
    end,
    title = function(e)
      return util.parse_title(e.filename)
    end,
  }

  local metatbl = {
    __index = function(e, key)
      local raw = rawget(e, key)
      if raw then
        return raw
      end

      local gen = rawget(key_to_gen, key)
      if gen then
        local value = gen(e)
        rawset(e, key, value)
        return value
      end

      return nil
    end,
  }

  return function(line)
    return setmetatable({
      cwd = cwd,
      display = to_display,
      ordinal = line,
      path = paths.abspath(line, cwd),
      value = line,
    }, metatbl)
  end
end

local function gen_grep_cmd(opts)
  opts = (opts and vim.tbl_deep_extend('force', {}, opts)) or {}
  opts.cwd = opts.cwd and vim.fn.expand(opts.cwd) or vim.loop.cwd()

  local vimgrep_arguments = opts.vimgrep_arguments or conf.vimgrep_arguments

  local additional_args = {}
  if type(opts.additional_args) == 'function' then
    additional_args = opts.additional_args(opts)
  elseif type(opts.additional_args) == 'string' then
    table.insert(additional_args, opts.additional_args)
  end

  if opts.type_filter then
    table.insert(additional_args, '--type=' .. opts.type_filter)
  end

  if type(opts.glob_pattern) == 'string' then
    table.insert(additional_args, '--glob=' .. opts.glob_pattern)
  elseif type(opts.glob_pattern) == 'table' then
    for _, pat in ipairs(opts.glob_pattern) do
      table.insert(additional_args, '--glob=' .. pat)
    end
  end

  local search_list = {}
  if opts.grep_open_files then
    search_list = get_open_filelist(opts.cwd) or {}
  elseif opts.search_dirs then
    for _, path in ipairs(opts.search_dirs) do
      table.insert(search_list, vim.fn.expand(path))
    end
  end

  return vim.tbl_flatten({
    vimgrep_arguments,
    additional_args,
    '-l',
    '--',
    opts.prompt or '',
    search_list,
  })
end

local function open_live_grep(opts)
  opts = (opts and vim.tbl_deep_extend('force', {}, opts)) or {}
  opts.cwd = opts.cwd and vim.fn.expand(opts.cwd) or vim.loop.cwd()

  local finder = finders.new_job(function(prompt)
    local opts = (opts and vim.tbl_deep_extend('force', {}, opts)) or {}
    opts.prompt = prompt
    if not opts.prompt or opts.prompt == '' then
      return nil
    end
    return gen_grep_cmd(opts)
  end, opts.entry_maker or gen_entry_maker(opts), opts.max_results, opts.cwd)

  pickers
    .new(opts, {
      prompt_title = opts.title or 'grep',
      finder = finder,
      previewer = conf.grep_previewer(opts),
      sorter = sorters.empty(opts),
      attach_mappings = function(prompt_bufnr, map)
        map('i', '<c-space>', actions.to_fuzzy_refine)
        actions.select_default:replace(function()
          actions.close(prompt_bufnr)
          local selection = actions_state.get_selected_entry()
          if selection and opts.callback then
            opts.callback(selection)
          end
        end)
        return true
      end,
    })
    :find()
end

local function gen_list_cmd()
  local find_cmd = nil
  if vim.fn.has('win32') > 0 then
    find_cmd = { 'cmd', '/c', 'dir /b /A-D' }
  else
    find_cmd = {
      'find',
      '.',
      '-maxdepth',
      '1',
      '-type',
      'f',
      '-printf',
      '%f\\n',
    }
  end
  return find_cmd
end

local function open_filename_picker(opts)
  opts = vim.tbl_deep_extend('force', {}, opts or {})
  opts.cwd = (opts.cwd and vim.fn.expand(opts.cwd)) or vim.loop.cwd()
  opts.entry_maker = gen_entry_maker(opts)
  if opts.fuzzy == nil then
    opts.fuzzy = false
  end

  local find_cmd = opts.cmd
  if not find_cmd then
    find_cmd = gen_list_cmd()
  end

  pickers
    .new(opts, {
      prompt_title = opts.title or 'Find file',
      finder = finders.new_oneshot_job(find_cmd, opts),
      previewer = conf.file_previewer(opts),
      sorter = conf.generic_sorter(opts),
      attach_mappings = function(prompt_bufnr, map)
        actions.select_default:replace(function()
          actions.close(prompt_bufnr)
          local selection = actions_state.get_selected_entry()
          if selection and opts.callback then
            opts.callback(selection)
          end
        end)
        return true
      end,
    })
    :find()
end

local function open_tag_picker(opts)
  opts = (opts and vim.tbl_deep_extend('force', {}, opts)) or {}
  opts.additional_args = opts.additional_args or {}
  opts.prompt = '(^|\\s|"|")#[a-zA-Z][a-zA-Z0-9-_]*'
  table.insert(opts.additional_args, '-INow')

  local find_cmd = gen_grep_cmd(opts)
  local find_job = finders.new_oneshot_job(find_cmd, opts)

  pickers
    .new(opts, {
      prompt_title = 'Search tags',
      finder = find_job,
      sorter = conf.generic_sorter(opts),
      attach_mappings = function(prompt_bufnr, map)
        map('i', '<c-space>', actions.to_fuzzy_refine)
        actions.select_default:replace(function()
          actions.close(prompt_bufnr)
          local selection = actions_state.get_selected_entry()
          if selection and opts.callback then
            opts.callback(selection)
          end
        end)
        return true
      end,
    })
    :find()
end

local function open_backlink_picker(uid, opts)
  opts = vim.tbl_deep_extend('force', {}, opts or {})
  opts.cwd = (opts.cwd and vim.fn.expand(opts.cwd)) or vim.loop.cwd()
  opts.entry_maker = gen_entry_maker(opts)
  if opts.fuzzy == nil then
    opts.fuzzy = false
  end

  opts.prompt = '\\[\\[([a-zA-Z0-9_-]+:)?'
    .. uid
    .. '(\\s*\\|[^\\r\\n\\]]*)?\\]\\]'
  local find_cmd = gen_grep_cmd(opts)
  local finder = finders.new_oneshot_job(find_cmd, opts)

  pickers
    .new(opts, {
      prompt_title = opts.title or 'Backlinks',
      finder = finder,
      previewer = conf.grep_previewer(opts),
      sorter = conf.generic_sorter(opts),
      attach_mappings = function(prompt_bufnr, map)
        actions.select_default:replace(function()
          actions.close(prompt_bufnr)
          local selection = actions_state.get_selected_entry()
          if selection and opts.callback then
            opts.callback(selection)
          end
        end)
        return true
      end,
    })
    :find()
end

function M.open_filename_picker(dir, callback)
  dir = dir or vim.fn.getcwd(-1, -1)
  open_filename_picker({ cwd = dir, callback = callback })
end

function M.open_live_grep_picker(dir, callback)
  dir = dir or vim.fn.getcwd(-1, -1)
  open_live_grep({ cwd = dir, callback = callback })
end

function M.open_tag_picker(dir, callback)
  dir = dir or vim.fn.getcwd(-1, -1)
  open_tag_picker({ cwd = dir, callback = callback })
end

function M.open_backlink_picker(uid, dir, callback)
  open_backlink_picker(uid, { cwd = dir, callback = callback })
end

return M
