local modulename, _ = ...
local moduleroot = modulename:gsub('(.+)%..+', '%1')

local paths = require(moduleroot .. '.path')

local M = {}

M.plugin_name = 'microkasten'
M.plugin_datadir = vim.fn.stdpath('data') .. paths.sep() .. 'microkasten'
M.file_extensions = { '.md', '.norg' }
M.default_extension = '.md'

M.verbose = 1

return M
