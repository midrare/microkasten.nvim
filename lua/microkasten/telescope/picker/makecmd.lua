local M = {}

local tele_config = require("telescope.config").values

local arrays = require("microkasten.luamisc.arrays")
local opened = require("microkasten.telescope.picker.opened")

local function add_flag(cmd, flag, is_enabled)
  if type(is_enabled) == "function" then
    is_enabled = is_enabled()
  end

  if is_enabled then
    table.insert(cmd, flag)
  end
end

local function add_values(cmd, flag, value)
  local type_ = type(value)
  if type_ == "table" then
    for _, val in ipairs(value) do
      add_values(cmd, flag, val)
    end
  elseif type_ == "function" then
    add_values(cmd, flag, value())
  elseif value ~= nil then
    table.insert(cmd, flag)
    table.insert(cmd, value)
  end
end

function M.make_grep_cmd(opts)
  opts = (opts and vim.tbl_deep_extend("force", {}, opts)) or {}
  opts.cwd = opts.cwd and vim.fn.expand(opts.cwd) or vim.loop.cwd()

  local grep_cmd = opts.vimgrep_arguments or tele_config.vimgrep_arguments

  local additional_args = {}
  if type(opts.additional_args) == "function" then
    additional_args = opts.additional_args(opts)
  elseif opts.additional_args then
    additional_args = vim.tbl_flatten(opts.additional_args)
  end

  if opts.type_filter then
    table.insert(additional_args, "--type=" .. opts.type_filter)
  end

  if type(opts.glob_pattern) == "string" then
    table.insert(additional_args, "--glob=" .. opts.glob_pattern)
  elseif type(opts.glob_pattern) == "table" then
    for _, pat in ipairs(opts.glob_pattern) do
      table.insert(additional_args, "--glob=" .. pat)
    end
  end

  add_values(additional_args, "--regexp", vim.tbl_flatten({ opts.prompt }))

  local search_paths = vim.tbl_flatten({ opts.search_dirs })
  arrays.transform(search_paths, vim.fn.expand)
  if opts.grep_open_files then
    arrays.extend(search_paths, opened.get_open_filelist(opts.cwd) or {})
  end

  return vim.tbl_flatten({
    grep_cmd,
    additional_args,
    "--color=never",
    "--no-heading",
    "--",
    search_paths,
  })
end

function M.make_listdir_cmd(opts)
  opts = vim.tbl_deep_extend("force", {}, opts or {})

  -- telescope will set cwd so we can omit dirname in args
  if vim.fn.has("win32") > 0 then
    return { "cmd", "/c", "dir", "/B", "/A-D-H-S", "/O" }
  end

  return {
    "find",
    ".",
    "-maxdepth",
    "1",
    "-type",
    "f",
    "-printf",
    "%f\\n",
  }
end

function M.make_fd_cmd(opts)
  opts = (opts and vim.tbl_deep_extend("force", {}, opts)) or {}
  opts.cwd = opts.cwd and vim.fn.expand(opts.cwd) or vim.loop.cwd()
  opts.additional_args = opts.additional_args or {}
  local cmd = { "fd" }

  if opts.ignore == nil then
    opts.ignore = true
  end

  if opts.follow == nil then
    opts.follow = true
  end

  table.insert(cmd, opts.additional_args or {})

  add_flag(cmd, "--hidden", opts.hidden)
  add_flag(cmd, "--no-ignore", opts.ignore)
  add_flag(cmd, "--follow", opts.follow)

  add_values(cmd, "--search-path", opts.search_dirs)
  add_values(cmd, "--exclude", opts.exclude)
  add_values(cmd, "--extension", opts.ext_filter)

  assert(
    type(opts.prompt) ~= "table" or #opts.prompt <= 1,
    "multiple regex not supported for fd"
  )

  return vim.tbl_flatten({
    cmd,
    "--color=never",
    "--",
    opts.prompt,
  })
end

return M
