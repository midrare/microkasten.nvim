local M = {}

local links = require("microkasten.links")
local syntax = require("microkasten.syntax")

local dispsegs = require("microkasten.telescope.common.dispsegs")
local rg = require("microkasten.telescope.common.rg")

---@diagnostic disable-next-line: unused-local
local function add_icon_segs(opts, segs, entry)
  if opts.disable_devicons ~= true then
    if #segs > 0 then
      table.insert(segs, { text = " " })
    end
    table.insert(segs, { text = "󰓹" })
  end
end

function M.open(opts)
  opts = opts and vim.deepcopy(opts) or {}
  opts.cwd = opts.cwd and vim.fn.expand(opts.cwd) or vim.loop.cwd()
  opts.prompt = vim.tbl_flatten({ syntax.generate_tags_regex() })

  local attrs = vim.tbl_deep_extend("force", {
    display = function(e)
      local segs = {}

      add_icon_segs(opts, segs, e)
      rg.dispsegs.add_matches_segs(opts, segs, e)

      return dispsegs.render(segs)
    end,
  }, rg.attrs.filename_attrs, rg.attrs.coordinate_attrs, rg.attrs.line_attrs)

  rg.open(opts, attrs)
end

return M
