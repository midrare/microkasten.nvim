local M = {}

local dispsegs  = require("microkasten.telescope.common.dispsegs")

local fd = require("microkasten.telescope.common.fd")

function M.open(opts)
  opts = vim.tbl_deep_extend("force", {}, opts or {})
  opts.cwd = opts.cwd and vim.fn.expand(opts.cwd) or vim.loop.cwd()

  local attrs = vim.tbl_deep_extend("force", {
    display = function(e)
      local segs = {}

      fd.dispsegs.add_fileicon_segs(opts, segs, e)
      fd.dispsegs.add_uid_segs(opts, segs, e)
      fd.dispsegs.add_title_segs(opts, segs, e)

      return dispsegs.render(segs)
    end,
  }, fd.attrs.filename_attrs)

  fd.open(opts, attrs)
end

return M
