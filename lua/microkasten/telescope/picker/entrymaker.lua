local M = {}

local arrays = require("microkasten.luamisc.arrays")
local base64 = require("microkasten.luamisc.base64")
local paths = require("microkasten.luamisc.paths")
local filenames = require("microkasten.filenames")

local tsutils = require("telescope.utils")

-- NOTE if you want highlights, "display" must be in the original entry
--  not in the metatable
local function resolve_highlights(hlsegs)
  local texts = ""
  local highlights = {}

  local pos = 0  -- for some reason hl range start at 0
  for _, p in ipairs(hlsegs) do
    local text = tostring(p[1])
    local hl = p[2]

    if hl then
      table.insert(highlights, { { pos, pos + #text }, hl })
    end

    texts = texts .. text
    pos = pos + #text
  end

  return texts, highlights
end

local function rg_decode(data)
  if data.text then
    return data.text
  end
  return base64.decode(data.bytes)
end

---@diagnostic disable-next-line: unused-local
local function filename_attrs(opts)
  return {
    path = function(e)
      return paths.abspath(e.value, e.cwd)
    end,
    filestem = function(e)
      return vim.fn.fnamemodify(e.value, ":r")
    end,
    uid = function(e)
      return e._metadata.uid
    end,
    title = function(e)
      return e._metadata.title
    end,
    _metadata = function(e)
      return filenames.parse_filename(e.value)
    end,
  }
end

---@diagnostic disable-next-line: unused-local
local function grep_attrs(opts)
  return {
    basename = function(e)
      return paths.basename(e.filename)
    end,
    path = function(e)
      return paths.abspath(e.filename, e.cwd)
    end,
    lnum = function(e)
      return e._message.data.line_number
    end,
    col = function(e)
      if not e._message.data.submatches[1] then
        return nil
      end
      return e._message.data.submatches[1].start
    end,
    text = function(e)
      return e.value
    end,
    value = function(e)
      return rg_decode(e._message.data.lines):gsub("[\r\n]+$", "")
    end,
    ordinal = function(e)
      return e.text:gsub("^%s+", ""):gsub("%s+$", "")
    end,
    filestem = function(e)
      return vim.fn.fnamemodify(e.filename, ":r")
    end,
    _metadata = function(e)
      return filenames.parse_filename(e.filename)
    end,
    uid = function(e)
      return e._metadata.uid
    end,
    title = function(e)
      return e._metadata.title
    end,
  }
end

-- this function is separate from the metatable because highlights don't work
-- unless "display" is in the original entry table
local function grep_display(opts)
  return function(e)
    local segs = {}

    if true or opts.disable_devicons ~= true then
      local ico, hl = tsutils.get_devicons(e.filename, opts.disable_devicons)
      if ico and #ico > 0 then
        table.insert(segs, { ico, opts.icon_hl or hl })
        table.insert(segs, { " ", nil })
      end
    end

    if opts.disable_uid == false then
      table.insert(segs, { e._metadata.uid, opts.uid_hl or "comment" })
      table.insert(segs, { " ", nil })
    end

    if opts.disable_title == false then
      table.insert(segs, { e._metadata.title, opts.title_hl })
      table.insert(segs, { " ", nil })
    end

    if opts.disable_filename == false then
      local filename = tsutils.transform_path(opts, e.filename)
      table.insert(segs, { filename, opts.filename_hl })
      table.insert(segs, { " ", nil })
    end

    if opts.disable_coordinates == false and e.lnum then
      table.insert(segs, { e.lnum, opts.coordinates_hl or "comment" })
      if e.col then
        table.insert(segs, { ":", opts.coordinates_hl or "comment"  })
        table.insert(segs, { e.col, opts.coordinates_hl or "comment" })
      end
      table.insert(segs, { " ", nil })
    end

    if opts.disable_text ~= true and e.text then
      local last_stop = 1
      for _, m in ipairs(e._message.data.submatches) do
        local start = 1 + m["start"]
        local stop = 1 + m["end"]

        if last_stop < start then
          table.insert(segs,
            { e.text:sub(last_stop, start - 1), opts.text_hl or nil })
        end

        table.insert(segs, { e.text:sub(start, stop - 1),
          opts.match_hl or "keyword" })
        last_stop = stop
      end

      if last_stop < #e.text then
        table.insert(segs, { e.text:sub(last_stop), opts.text_hl or nil })
      end
    end

    return resolve_highlights(segs)
  end
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
      filename = filename,
      display = function(e)
        local segs = {}

        local icon, icon_hl = tsutils.get_devicons(e.value, opts.disable_devicons)
        if icon and icon_hl then
          table.insert(segs, { icon, icon_hl })
          table.insert(segs, { " ", nil })
        end

        if not opts.disable_uid and e.uid and #e.uid > 0 then
          table.insert(segs, { e.uid, "@comment" })
          table.insert(segs, { " ", nil })
        end

        table.insert(segs, { e.title, nil })

        return resolve_highlights(segs)
      end,
    }, filename_attrs(opts))
  end
end

function M.tag_entry_maker(opts)
  local function display(e)
    local segs = {}

    if not opts.disable_devicons then
      table.insert(segs, { "󰓹 ", nil })
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

  return function(match)
    return set_attrs({
      cwd = opts.cwd,
      display = grep_display(opts),
      value = match,
    }, grep_attrs(opts))
  end
end

function M.grep_entry_maker(opts)
  opts = vim.tbl_deep_extend("force", {}, opts or {})

  local filename = nil
  return function(line)
    local msg = vim.fn.json_decode(line)
    if not msg then
      return nil
    end

    if msg.type == "begin" then
      filename = rg_decode(msg.data.path)
    elseif msg.type == "match" then
      if not filename then
        return nil
      end

      return set_attrs({
        cwd = opts.cwd,
        display = grep_display(opts),
        filename = filename,
        _message = msg,
      }, grep_attrs(opts))
    elseif msg.type == "end" then
      filename = nil
    end

    return nil
  end
end

return M
