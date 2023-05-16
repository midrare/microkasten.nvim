local M = {}

local entrymaker = require("microkasten.telescope.picker.entrymaker")
local makecmd = require("microkasten.telescope.picker.makecmd")
local mappings = require("microkasten.telescope.picker.mappings")

local tsconfig = require("telescope.config").values
local tsfinders = require("telescope.finders")
local tspickers = require("telescope.pickers")

function M.open(opts)
  opts = vim.tbl_deep_extend("force", {}, opts or {})
  opts.cwd = (opts.cwd and vim.fn.expand(opts.cwd)) or vim.loop.cwd()

  opts.entry_maker = opts.entry_maker or entrymaker.filename_entry_maker(opts)
  opts.fuzzy = opts.fuzzy or false
  opts.cmd = opts.cmd or makecmd.make_fd_cmd(opts)

  local finder = tsfinders.new_job(function(prompt)
    ---@diagnostic disable-next-line: redefined-local
    local opts = vim.tbl_deep_extend("force", {}, opts or {})
    opts.prompt = prompt
    return makecmd.make_fd_cmd(opts)
  end, opts.entry_maker or entrymaker.filename_entry_maker(opts), opts.max_results, opts.cwd)

  tspickers
    .new(opts, {
      prompt_title = opts.title or "Files",
      finder = finder,
      previewer = tsconfig.file_previewer(opts),
      sorter = tsconfig.file_sorter(opts),
      attach_mappings = mappings.telescope_mappings,
    })
    :find()
end

return M
