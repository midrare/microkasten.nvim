local M = {}

local makecmd = require("microkasten.telescope.picker.makecmd")
local entrymaker = require("microkasten.telescope.picker.entrymaker")
local useropts = require("microkasten.useropts")

local tsconfig = require("telescope.config").values
local tsfinders = require("telescope.finders")
local tspickers = require("telescope.pickers")
local tssorters = require("telescope.sorters")

function M.open(opts)
  opts = vim.tbl_deep_extend("force", {}, opts or {})
  opts.cwd = opts.cwd and vim.fn.expand(opts.cwd) or vim.loop.cwd()

  if opts.disable_filename == nil then
    opts.disable_filename = true
  end

  if opts.disable_text == nil then
    opts.disable_text = false
  end

  if opts.disable_coordinates == nil then
    opts.disable_coordinates = true
  end

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
    opts.entry_maker or entrymaker.grep_entry_maker(opts),
    opts.max_results,
    opts.cwd
  )

  tspickers
    .new(opts, {
      prompt_title = opts.title or "grep",
      finder = finder,
      previewer = tsconfig.grep_previewer(opts),
      sorter = tssorters.empty(opts),
      attach_mappings = useropts.telescope_mappings,
    })
    :find()
end

return M
