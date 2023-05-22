local M = {}

local actions = require("microkasten.telescope.actions")
local tsactions = require("telescope.actions")

function M.telescope_mappings(_, map)
  tsactions.select_default:replace(actions.open_file)
  map("i", "<c-y>", actions.yank_uid)
  map("i", "<c-i>", actions.put_uid)
  map("n", "<c-y>", actions.yank_uid)
  map("n", "<c-i>", actions.put_uid)
  map("n", "<c-c>", tsactions.close)
  map("n", "<esc>", tsactions.close)
  return true
end

return M
