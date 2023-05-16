local M = {}

local paths = require("microkasten.luamisc.paths")
local useropts = require("microkasten.useropts")

local tsutils = require("telescope.utils")

local function resolve_highlights(hlsegs)
  local texts = ""
  local highlights = {}

  local pos = 1
  for _, p in ipairs(hlsegs) do
    local text = p[1]
    local hl = p[2]

    if hl then
      table.insert(highlights, { { pos, pos + #text }, hl })
    end

    texts = texts .. text
    pos = pos + #text
  end

  return texts, highlights
end

local function filename_attrs(opts)
  return {
    filename = function(e)
      return vim.fn.fnamemodify(e.value, ":t")
    end,
    filestem = function(e)
      return vim.fn.fnamemodify(e.filename, ":r")
    end,
    uid = function(e)
      return e._info.uid
    end,
    title = function(e)
      return e._info.title
    end,
    _info = function(e)
      local f = useropts.parse_filename
      return f(e.filename)
    end,
    path = function(e)
      return paths.abspath(e.filename, e.cwd)
    end,
    display = function(e)
      local segs = {}

      local icon, icon_hl =
        tsutils.get_devicons(e.filename, opts.disable_devicons)
      if icon and icon_hl then
        table.insert(segs, {icon, icon_hl})
        table.insert(segs, {' ', nil})
      end

      if not opts.disable_uid and e.uid and #e.uid > 0 then
        table.insert(segs, { e.uid, 'Comment' })
        table.insert(segs, {' ', nil})
      end

      table.insert(segs, { e.title, nil })

      return resolve_highlights(segs)
    end,
  }
end

local function grep_attrs(opts)
  return {
    _parsed = function(e)
      local text = e.value

      ---@diagnostic disable-next-line: redefined-local
      local start, stop, filename, lnum, col =
        text:find("^(.*):([0-9]+):([0-9]+):")
      if not start or not stop then
        start, stop, lnum, col = text:find("^([0-9]+):([0-9]+):")
      end
      if not start or not stop then
        start, stop, lnum = text:find("^([0-9]+):")
      end
      if not start or not stop then
        start, stop, filename, lnum = text:find("^(.*):([0-9]+):")
      end
      if not start or not stop then
        start, stop, filename = text:find("^(.*):")
      end
      if start and stop then
        text = text:sub(1, start - 1) .. text:sub(stop + 1)
      end

      if not opts.disable_strip_text and text then
        text = text:gsub("^%s+", ""):gsub("%s+$", "")
      end

      return {
        text = text,
        lnum = lnum and tonumber(lnum),
        col = col and tonumber(col),
        filename = filename,
      }
    end,
    display = function(e)
      local segs = {}

      if not opts.disable_devicons and e.icon then
        local ico, ico_hl = table.unpack(e._devicon)
        if ico and #ico > 0 then
          table.insert(segs, {ico, ico_hl})
          table.insert(segs, {' ', nil})
        end
      end

      if not opts.disable_filename then
        local filename = tsutils.transform_path(opts, e.filename)
        table.insert(segs, { filename .. ':', 'Comment'})
      end
      if not opts.disable_coordinates and e._parsed.lnum then
        table.insert(segs, { e._parsed.lnum .. ':', 'Comment' })
        if e._parsed.col then
          table.insert(segs, { e._parsed.col .. ':', 'Comment' })
        end
      end
      if not opts.disable_text and e._parsed.text then
        table.insert(segs, { e._parsed.text, nil })
      end

      return resolve_highlights(segs)
    end,
    _devicon = function(e)
      return table.pack(tsutils.get_devicons(e.filename, opts.disable_devicons))
    end,
    path = function(e)
      if paths.isabs(e.filename) then
        return e.filename
      end
      return paths.abspath(e.filename, e.cwd)
    end,
    filename = function(e)
      return e._parsed.filename
    end,
    lnum = function(e)
      return e._parsed.lnum
    end,
    col = function(e)
      return e._parsed.col
    end,
    text = function(e)
      return e._parsed.text
    end,
    ordinal = function(e)
      if opts.only_sort_text then
        return e._parsed.text
      end
      if e._parsed.filename and #e._parsed.filename > 0 then
        return e._parsed.filename
      end
      return e.value and tostring(e.value) or nil
    end,
    filestem = function(e)
      return vim.fn.fnamemodify(e.filename, ":r")
    end,
    uid = function(e)
      return e._info.uid
    end,
    title = function(e)
      return e._info.title
    end,
    _info = function(e)
      local f = useropts.parse_filename
      return f(e.filename)
    end,
  }
end

local function set_attrs(tbl, attrs)
  return setmetatable(tbl, {
    __index = function(e, key)
      local raw = rawget(e, key)
      if raw ~= nil then
        return raw
      end

      local make_value = rawget(attrs, key)
      if make_value then
        local value = make_value(e)
        rawset(e, key, value)
        return value
      end

      return nil
    end,
  })
end

function M.filename_entry_maker(opts)
  return function(filename)
    return set_attrs({
      cwd = opts.cwd,
      ordinal = filename,
      value = filename,
    }, filename_attrs(opts))
  end
end

function M.tag_entry_maker(opts)
  local function display(e)
    local segs = {}

    if not opts.disable_devicons then
      table.insert(segs, {"󰓹 ", nil })
    end

    table.insert(segs, { e.value, nil })

    return resolve_highlights(segs)
  end

  local seen = {}

  return function(tag)
    if seen[tag] then
      return nil
    end
    seen[tag] = true

    return {
      cwd = opts.cwd,
      display = display,
      ordinal = tag,
      value = tag,
    }
  end
end

function M.backlink_entry_maker(opts)
  opts = vim.tbl_deep_extend("force", {}, opts or {})
  if opts.disable_filename == nil then
    opts.disable_filename = true
  end

  return function(match)
    return set_attrs({
      cwd = opts.cwd,
      value = match,
    }, grep_attrs(opts))
  end
end

function M.grep_entry_maker(opts)
  opts = vim.tbl_deep_extend("force", {}, opts or {})

  return function(match)
    return set_attrs({
      cwd = opts.cwd,
      value = match,
    }, grep_attrs(opts))
  end
end

return M
