local M = {}

local tele_config = require("telescope.config").values

local arrays = require("microkasten.luamisc.arrays")
local opened = require("microkasten.telescope.picker.opened")

local function add_flag(cmd, opts, flag, is_enabled)
  if type(is_enabled) == "function" then
    is_enabled = is_enabled(opts)
  end

  if is_enabled then
    table.insert(cmd, flag)
  end
end

local function add_values(cmd, opts, flag, value)
  local type_ = type(value)
  if type_ == "table" then
    for _, val in ipairs(value) do
      add_values(cmd, opts, flag, val)
    end
  elseif type_ == "function" then
    add_values(cmd, opts, flag, value(opts))
  elseif value ~= nil then
    table.insert(cmd, flag)
    table.insert(cmd, value)
  end
end

function M.make_grep_cmd(opts)
  opts = (opts and vim.tbl_deep_extend("force", {}, opts)) or {}
  opts.cwd = opts.cwd and vim.fn.expand(opts.cwd) or vim.loop.cwd()

  local cmd =
    vim.deepcopy(opts.vimgrep_arguments or tele_config.vimgrep_arguments)

  if type(opts.additional_args) == "function" then
    arrays.extend(cmd, opts.additional_args(opts))
  elseif opts.additional_args then
    arrays.extend(cmd, vim.tbl_flatten({opts.additional_args}))
  end

  add_values(cmd, opts, "--type", opts.type_filter)
  add_values(cmd, opts, "--glob", opts.glob_pattern)
  add_values(cmd, opts, "--regexp", opts.prompt)

  local search_paths = vim.tbl_flatten({ opts.search_dirs })
  arrays.transform(search_paths, vim.fn.expand)
  if opts.grep_open_files then
    arrays.extend(search_paths, opened.get_open_filelist(opts.cwd) or {})
  end

  local foo = vim.tbl_flatten({
    cmd,
    "--color=never",
    "--json",
    "--",
    search_paths,
  })

  return foo
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

  add_flag(cmd, opts, "--hidden", opts.hidden)
  add_flag(cmd, opts, "--no-ignore", opts.ignore)
  add_flag(cmd, opts, "--follow", opts.follow)

  add_values(cmd, opts, "--search-path", opts.search_dirs)
  add_values(cmd, opts, "--exclude", opts.exclude)
  add_values(cmd, opts, "--extension", opts.ext_filter)

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
