local M = {}

local pickers = require("microkasten.telescope.pickers")

M.filenames = pickers.filenames
M.grep = pickers.grep
M.tags = pickers.tags
M.backlinks = pickers.backlinks

return M
