local M = {}

local dispsegs = require("microkasten.telescope.common.dispsegs")
local rg = require("microkasten.telescope.common.rg")

-- entries:
-- * per-file
-- * per-line
-- * per-match

function M.open(opts)
  opts = opts and vim.deepcopy(opts) or {}
  opts.cwd = opts.cwd and vim.fn.expand(opts.cwd) or vim.loop.cwd()

  local attrs = vim.tbl_deep_extend("force", {
    display = function(e)
      local segs = {}

      rg.dispsegs.add_fileicon_segs(opts, segs, e)
      rg.dispsegs.add_uid_segs(opts, segs, e)
      rg.dispsegs.add_title_segs(opts, segs, e)
      rg.dispsegs.add_coordinate_segs(opts, segs, e)
      rg.dispsegs.add_matches_segs(opts, segs, e)

      return dispsegs.render(segs)
    end,
  }, rg.attrs.filename_attrs, rg.attrs.coordinate_attrs, rg.attrs.line_attrs)

  rg.open(opts, attrs)
end

return M