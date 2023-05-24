local M = {}

local tsconfig = require("telescope.config").values
local tsfinders = require("telescope.finders")
local tspickers = require("telescope.pickers")
local tssorters = require("telescope.sorters")
local tsmisc = require("telescope._")
local tsasync = require("telescope.finders.async_job_finder")

local arrays = require("microkasten.luamisc.arrays")
local base64 = require("microkasten.luamisc.base64")
local tables = require("microkasten.luamisc.tables")

local mappings = require("microkasten.telescope.mappings")

local opened = require("microkasten.telescope.common.openedfiles")
local makecmd = require("microkasten.telescope.common.makecmd")
local commonattrs = require("microkasten.telescope.common.attrs")

local rgattrs = require("microkasten.telescope.common.rg.attrs")
local rgjob = require("microkasten.telescope.common.rg.job")
local rgutil = require("microkasten.telescope.common.rg.util")
local rgdispsegs = require("microkasten.telescope.common.rg.dispsegs")

local function get_exe(opts)
  local vimgrep_args = opts.vimgrep_arguments or tsconfig.vimgrep_arguments
  local basename = vimgrep_args[1] and vimgrep_args[1]:gsub("^.*[\\/]+", "")
  if not basename then
    return nil
  end

  local stem = basename:gsub("%.[^%.]*$", "")
  if
    not stem:match("^[rR][gG]$")
    and not stem:match("^[rR][iI][pP][gG][rR][eE][pP]$")
  then
    return nil
  end

  return vimgrep_args[1]
end

---@param opts table<string, any>
---@return string[] cmd command to use in finder
local function make_cmd(opts)
  opts = (opts and vim.tbl_deep_extend("force", {}, opts)) or {}
  opts.cwd = opts.cwd and vim.fn.expand(opts.cwd) or vim.loop.cwd()

  local cmd = { get_exe(opts) or "rg" }
  vim.list_extend(cmd, vim.tbl_flatten({ opts.additional_args }))

  -- TODO check for and remove all rg options incompatible with --json
  makecmd.remove_flags(cmd, "--files")
  makecmd.remove_flags(cmd, "-l", "--files-with-matches")
  makecmd.remove_flags(cmd, "--files-without-match")
  makecmd.remove_flags(cmd, "-c", "--count", "--count-matches")
  makecmd.remove_flags(cmd, "-o", "--only-matching")
  makecmd.remove_flags(cmd, "-V", "--version")

  makecmd.add_values(cmd, "--type", opts.type_filter)
  makecmd.add_values(cmd, "--glob", opts.glob_pattern)
  makecmd.add_values(cmd, "--regexp", opts.prompt)

  local search_paths = vim.tbl_flatten({ opts.search_dirs })
  for i = 1, #search_paths do
    search_paths[i] = vim.fn.expand(search_paths[i])
  end

  if opts.grep_open_files then
    vim.list_extend(search_paths, opened.get_open_filelist(opts.cwd))
  end

  return vim.tbl_flatten({
    cmd,
    "--color=never",
    "--json",
    "--",
    search_paths,
  })
end

local function make_entry_maker(opts, attrs)
  opts = opts and vim.deepcopy(opts) or {}
  return function(ev)
    local entry = { cwd = opts.cwd, _event = ev }
    return commonattrs.set_attrs(entry, attrs)
  end
end

local function make_finder(opts, attrs)
  opts = opts and vim.deepcopy(opts) or {}
  opts.batch = rgjob.frequency.file

  opts.command_generator = function(prompt)
    ---@diagnostic disable-next-line: redefined-local
    local opts = opts and vim.deepcopy(opts) or {}
    opts.prompt = opts.prompt or prompt
    return make_cmd(opts)
  end

  opts.entry_maker = make_entry_maker(opts, attrs)

  return rgjob.async_job_finder(opts)
end

function M.open(opts, attrs)
  local previewer = nil
  if not opts.disable_previewer then
    previewer = previewer or opts.previewer or tsconfig.grep_previewer(opts)
  end

  tspickers
    .new(opts, {
      prompt_title = opts.title or "grep",
      finder = make_finder(opts, attrs),
      previewer = previewer,
      sorter = tssorters.empty(opts),
      attach_mappings = opts.mappings or mappings.telescope_mappings,
    })
    :find()
end

M.attrs = rgattrs
M.decode = rgutil.decode
M.dispsegs = rgdispsegs

return M
