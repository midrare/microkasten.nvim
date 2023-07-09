local M = {}

local tsfinders = require("telescope.finders")
local tsconfig = require("telescope.config").values
local tspickers = require("telescope.pickers")
local tssorters = require("telescope.sorters")
local tsmisc = require("telescope._")
local tsasync = require("telescope.finders.async_job_finder")
local tsutils = require("telescope.utils")

local tables = require("microkasten.luamisc.tables")

local mappings = require("microkasten.telescope.mappings")

local commonattrs = require("microkasten.telescope.common.attrs")
local makecmd = require("microkasten.telescope.common.makecmd")
local opened = require("microkasten.telescope.common.openedfiles")

local fzfattrs = require("microkasten.telescope.common.fzf.attrs")
local fzfdispsegs = require("microkasten.telescope.common.fzf.dispsegs")

local function make_cmd(opts)
  opts = opts and vim.deepcopy(opts) or {}
  opts.cwd = opts.cwd and vim.fn.expand(opts.cwd) or vim.loop.cwd()

  if not opts.prompt or #opts.prompt <= 0 then
    return nil
  end

  local cmd = { "rg", opts.additional_args }

  makecmd.add_values(cmd, "--type", opts.type_filter)
  makecmd.add_values(cmd, "--glob", opts.glob_pattern)

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
    "--files",
    "--",
    search_paths,
  })
end

local function make_entry_maker(opts, attrs)
  opts = opts and vim.deepcopy(opts) or {}
  return function(filename)
    assert(filename, "need filename. (corrupt stdout?)")
    local entry = { cwd = opts.cwd, filename = filename }
    return commonattrs.set_attrs(entry, attrs)
  end
end

local function make_finder(opts, attrs)
  return tsfinders.new_job(function(prompt)
    ---@diagnostic disable-next-line: redefined-local
    local opts = opts and vim.deepcopy(opts) or {}
    opts.prompt = opts.prompt or prompt
    return make_cmd(opts)
  end, opts.entry_maker or
    (opts.make_entry_maker and opts.make_entry_maker(opts, attrs)) or
    make_entry_maker(opts, attrs), opts.max_results, opts.cwd)
end

function M.open(opts, attrs)
  local previewer = nil
  if not opts.disable_previewer then
    previewer = previewer or opts.previewer or tsconfig.file_previewer(opts)
  end

  tspickers
    .new(opts, {
      prompt_title = opts.title or "Files",
      finder = make_finder(opts, attrs),
      previewer = previewer,
      sorter = tsconfig.file_sorter(opts),
      attach_mappings = opts.mappings or mappings.telescope_mappings,
    })
    :find()
end

M.attrs = fzfattrs
M.dispsegs = fzfdispsegs

return M
