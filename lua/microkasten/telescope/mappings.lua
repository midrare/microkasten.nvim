local M = {}

local actions = require("microkasten.telescope.actions")
local tsactions = require("telescope.actions")

function M.telescope_mappings(_, map)
  tsactions.select_default:replace(actions.open_file)

  map("i", "<c-y>", actions.yank_uid)
  map("i", "<c-i>", actions.put_uid)
  map("i", "<c-s>", tsactions.select_horizontal)
  map("i", "<c-v>", tsactions.select_vertical)
  map("i", "<c-cr>", function(bufnr)
    actions.open_file(bufnr, true)
  end)

  map("n", "<c-y>", actions.yank_uid)
  map("n", "<c-i>", actions.put_uid)
  map("n", "<c-s>", tsactions.select_horizontal)
  map("n", "<c-v>", tsactions.select_vertical)
  map("n", "<c-cr>", function(bufnr)
    actions.open_file(bufnr, true)
  end)

  map("n", "<c-c>", tsactions.close)
  map("n", "<esc>", tsactions.close)

  return true
end

return M
