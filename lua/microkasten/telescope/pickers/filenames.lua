local M = {}

local dispsegs  = require("microkasten.telescope.common.dispsegs")

local fd = require("microkasten.telescope.common.fd")
local fzf = require("microkasten.telescope.common.fzf")

function M.open(opts)
  opts = vim.tbl_deep_extend("force", {}, opts or {})
  opts.cwd = opts.cwd and vim.fn.expand(opts.cwd) or vim.loop.cwd()

  opts.disable_title = opts.disable_title == true
  opts.disable_coordinates = opts.disable_coordinates ~= false
  opts.disable_filename = opts.disable_filename ~= false
  opts.disable_uid = opts.disable_uid ~= false
  opts.disable_text = opts.disable_text ~= false

  local attrs = vim.tbl_deep_extend("force", {
    display = function(e)
      local segs = {}

      fzf.dispsegs.add_fileicon_segs(opts, segs, e)
      fzf.dispsegs.add_uid_segs(opts, segs, e)
      fzf.dispsegs.add_title_segs(opts, segs, e)
      fzf.dispsegs.add_filename_segs(opts, segs, e)

      return dispsegs.render(segs)
    end,
  }, fzf.attrs.filename_attrs)

  fzf.open(opts, attrs)
end

return M
