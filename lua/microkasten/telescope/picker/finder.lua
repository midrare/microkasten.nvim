local M = {}

local make_entry = require("telescope.make_entry")
local log = require("telescope.log")

local async_static_finder = require("telescope.finders.async_static_finder")
local async_oneshot_finder = require("telescope.finders.async_oneshot_finder")
local async_job_finder = require("telescope.finders.async_job_finder")

function M.new_backlinks_job(command_list, opts)
  opts = opts or {}

  assert(not opts.results, "`results` should be used with finder.new_table")

  command_list = vim.deepcopy(command_list)
  local command = table.remove(command_list, 1)

  return async_oneshot_finder({
    entry_maker = opts.entry_maker or make_entry.gen_from_string(opts),

    cwd = opts.cwd,
    maximum_results = opts.maximum_results,

    fn_command = function()
      return {
        command = command,
        args = command_list,
      }
    end,
  })
end
return M
