local usermisc = require('microkasten.usermisc')
local pickers = require('microkasten.telescope')


local default_opts = {}
local user_opts = vim.tbl_deep_extend("force", {}, default_opts)


local function pick_filename(opts)
  opts = vim.tbl_deep_extend("force", user_opts, opts or {})
  opts.cwd = opts.cwd or vim.fn.getcwd(-1, -1)
  pickers.filenames.open(opts)
end

local function pick_tag(opts)
  opts = vim.tbl_deep_extend("force", user_opts, opts or {})
  opts.cwd = opts.cwd or vim.fn.getcwd(-1, -1)
  pickers.tags.open(opts)
end

local function pick_backlink(opts)
  opts = vim.tbl_deep_extend("force", user_opts, opts or {})
  opts.cwd = opts.cwd or vim.fn.getcwd(-1, -1)
  if not opts.uid then
    local parse_filename = usermisc.parse_filename
    local filename = opts.filename or vim.fn.expand('%:t')
    local note = parse_filename(filename)
    opts.uid = note and note.uid or nil
  end
  if opts.uid and #opts.uid > 0 then
    pickers.backlinks.open(opts)
  end
end

local function pick_grep(opts)
  opts = vim.tbl_deep_extend("force", user_opts, opts or {})
  opts.cwd = opts.cwd or vim.fn.getcwd(-1, -1)
  pickers.grep.open(opts)
end


return require('telescope').register_extension({
  setup = function(cfg)
    user_opts = vim.tbl_deep_extend("force", default_opts, cfg)
  end,
  exports = {
    microkasten = pick_filename,
    filenames = pick_filename,
    tags = pick_tag,
    backlinks = pick_backlink,
    grep = pick_grep,
  },
})
