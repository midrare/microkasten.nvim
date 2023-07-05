local M = {}

local dispsegs  = require("microkasten.telescope.common.dispsegs")

local fd = require("microkasten.telescope.common.fd")

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

      fd.dispsegs.add_fileicon_segs(opts, segs, e)
      fd.dispsegs.add_uid_segs(opts, segs, e)
      fd.dispsegs.add_title_segs(opts, segs, e)
      fd.dispsegs.add_filename_segs(opts, segs, e)

      return dispsegs.render(segs)
    end,
  }, fd.attrs.filename_attrs)

  fd.open(opts, attrs)
end

return M
