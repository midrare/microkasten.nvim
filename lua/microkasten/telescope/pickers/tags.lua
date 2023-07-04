local M = {}

local strings = require("microkasten.luamisc.strings")

local links = require("microkasten.links")
local syntax = require("microkasten.syntax")

local dispsegs = require("microkasten.telescope.common.dispsegs")
local rg = require("microkasten.telescope.common.rg")
local rgjob = require("microkasten.telescope.common.rg.job")
local commonattrs = require("microkasten.telescope.common.attrs")

---@diagnostic disable-next-line: unused-local
local function add_icon_segs(opts, segs, entry)
  if opts.disable_devicons ~= true then
    if #segs > 0 then
      table.insert(segs, { text = " " })
    end
    table.insert(segs, { text = "󰓹" })
  end
end

---@diagnostic disable-next-line: unused-local
local function add_tags_segs(opts, segs, entry)
  for _, m in ipairs(entry._event.matches) do
    if m.start <= m.stop then
      if #segs > 0 then
        table.insert(segs, { text = " " })
      end
      local text = strings.sub(m.src, m.start, m.stop):gsub("[%s\r\n]+", " "):gsub("^%s+", ""):gsub("%s+$", "")
      table.insert(segs, { text = text, hl = opts.tag_hl or "keyword" })
    end
  end
end

local function make_entry_maker(opts, attrs)
  opts = opts and vim.deepcopy(opts) or {}
  seen = {}
  return function(ev)
    local tag = ev.matches[1].text
    if seen[tag] then
      return nil
    end

    seen[tag] = true
    local entry = { cwd = opts.cwd, _event = ev }
    return commonattrs.set_attrs(entry, attrs)
  end
end

function M.open(opts)
  opts = opts and vim.deepcopy(opts) or {}
  opts.cwd = opts.cwd and vim.fn.expand(opts.cwd) or vim.loop.cwd()
  opts.prompt = vim.tbl_flatten({ syntax.tags_regex() })
  opts.make_entry_maker = make_entry_maker
  opts.batch = rgjob.frequency.match

  local attrs = vim.tbl_deep_extend("force", {
    display = function(e)
      local segs = {}

      add_icon_segs(opts, segs, e)
      add_tags_segs(opts, segs, e)

      return dispsegs.render(segs)
    end,
  }, rg.attrs.filename_attrs, rg.attrs.coordinate_attrs, rg.attrs.tag_attrs)

  rg.open(opts, attrs)
end

return M
