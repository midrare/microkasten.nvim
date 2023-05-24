local M = {}

M.grep = require("microkasten.telescope.pickers.grep").open
M.filenames = require("microkasten.telescope.pickers.filenames").open
M.backlinks = require("microkasten.telescope.pickers.backlinks").open
M.tags = require("microkasten.telescope.pickers.tags").open

return M
