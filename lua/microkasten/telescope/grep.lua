local M = {}

local makecmd = require("microkasten.telescope.picker.makecmd")
local entrymaker = require("microkasten.telescope.picker.entrymaker")
local mappings = require("microkasten.telescope.picker.mappings")

local tsactions = require("telescope.actions")
local tsconfig = require("telescope.config").values
local tsfinders = require("telescope.finders")
local tsmakeentry = require("telescope.make_entry")
local tspickers = require("telescope.pickers")
local tssorters = require("telescope.sorters")

function M.open(opts)
  opts = vim.tbl_deep_extend("force", {}, opts or {})
  opts.cwd = opts.cwd and vim.fn.expand(opts.cwd) or vim.loop.cwd()

  local finder = tsfinders.new_job(
    function(prompt)
      ---@diagnostic disable-next-line: redefined-local
      local opts = vim.tbl_deep_extend("force", {}, opts or {})
      opts.prompt = prompt
      if not opts.prompt or #opts.prompt <= 0 then
        return nil
      end
      return makecmd.make_grep_cmd(opts)
    end,
    opts.entry_maker or entrymaker.ripgrep_entry_maker(opts),
    opts.max_results,
    opts.cwd
  )

  tspickers
    .new(opts, {
      prompt_title = opts.title or "grep",
      finder = finder,
      previewer = not opts.disable_previewer and tsconfig.grep_previewer(opts)
        or nil,
      sorter = tssorters.empty(opts),
      attach_mappings = mappings.telescope_mappings,
    })
    :find()
end

return M
