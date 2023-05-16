local M = {}

local entrymaker = require("microkasten.telescope.picker.entrymaker")
local makecmd = require("microkasten.telescope.picker.makecmd")
local links = require("microkasten.links")
local useropts = require("microkasten.useropts")

local tsconfig = require("telescope.config").values
local tsfinders = require("telescope.finders")
local tspickers = require("telescope.pickers")

function M.open(opts)
  opts = vim.tbl_deep_extend("force", {}, opts or {})
  opts.cwd = (opts.cwd and vim.fn.expand(opts.cwd)) or vim.loop.cwd()
  if opts.fuzzy == nil then
    opts.fuzzy = false
  end
  if opts.disable_coordinates == nil then
    opts.disable_coordinates = true
  end

  assert(opts.uid, 'expected uid to be provided')

  opts.prompt = vim.tbl_flatten({links.backlinks_regex(opts.uid)})
  opts.entry_maker = opts.entry_maker or entrymaker.backlink_entry_maker(opts)

  local find_cmd = makecmd.make_grep_cmd(opts)
  local finder = tsfinders.new_oneshot_job(find_cmd, opts)

  tspickers
    .new(opts, {
      prompt_title = opts.title or "Backlinks",
      finder = finder,
      previewer = tsconfig.grep_previewer(opts),
      sorter = tsconfig.generic_sorter(opts),
      attach_mappings = useropts.telescope_mappings,
    })
    :find()
end

return M
