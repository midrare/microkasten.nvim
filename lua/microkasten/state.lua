local module, _ = {}, nil
module.name, _ = ...
local moduleroot = module.name:gsub('(.+)%..+', '%1')
local paths = require(moduleroot .. '.luamisc.path')

module.plugin_name = 'microkasten'
module.plugin_datadir = vim.fn.stdpath('data') .. paths.sep() .. 'microkasten'
module.file_extensions = { '.md', '.norg' }
module.default_extension = '.md'

module.verbose = 1

return module
