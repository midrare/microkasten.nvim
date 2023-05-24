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

local fdattrs = require("microkasten.telescope.common.fd.attrs")
local fddispsegs = require("microkasten.telescope.common.fd.dispsegs")

local function make_cmd(opts)
  opts = opts and vim.deepcopy(opts) or {}
  opts.cwd = opts.cwd and vim.fn.expand(opts.cwd) or vim.loop.cwd()

  local cmd = { "fd", opts.additional_args }

  makecmd.add_flag(cmd, "--hidden", opts.hidden == true)
  makecmd.add_flag(cmd, "--no-ignore", opts.ignore == false)
  makecmd.add_flag(cmd, "--follow", opts.follow ~= false)

  makecmd.add_values(cmd, "--search-path", opts.search_dirs)
  makecmd.add_values(cmd, "--exclude", opts.exclude)
  makecmd.add_values(cmd, "--extension", opts.ext_filter)

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
    if not opts.prompt or #opts.prompt <= 0 then
      return nil
    end
    return make_cmd(opts)
  end, make_entry_maker(opts, attrs), opts.max_results, opts.cwd)
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

M.attrs = fdattrs
M.dispsegs = fddispsegs

return M
