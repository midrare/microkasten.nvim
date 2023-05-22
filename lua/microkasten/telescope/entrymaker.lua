local M = {}

local arrays = require("microkasten.luamisc.arrays")
local base64 = require("microkasten.luamisc.base64")
local paths = require("microkasten.luamisc.paths")
local strings = require("microkasten.luamisc.strings")
local tables = require("microkasten.luamisc.tables")
local filenames = require("microkasten.filenames")

local tsstate = require("telescope.state")
local tsutils = require("telescope.utils")

local elipsis = "\xe2\x80\xa6" -- horizontal elipsis "..."

-- NOTE if you want highlights, "display" must be in the original entry
--  not in the metatable

local function highlights(segs)
  local texts = ""
  local hls = {}

  -- NOTE hl ranges start at 0 and are measured in bytes
  local pos = 0
  for _, seg in ipairs(segs) do
    if seg.hl then
      table.insert(hls, { { pos, pos + #seg.text }, seg.hl })
    end

    texts = texts .. seg.text
    pos = pos + #seg.text
  end

  return texts, hls
end

---@param data { text: string } | { bytes: string }
---@return string decoded decoded string
local function decode(data)
  if data.text then
    return data.text
  end
  return base64.decode(data.bytes)
end

---@diagnostic disable-next-line: unused-local
local function file_attrs(opts)
  return {
    path = function(e)
      return paths.abspath(e.filename, e.cwd)
    end,
    basename = function(e)
      return paths.basename(e.filename)
    end,
  }
end

---@diagnostic disable-next-line: unused-local
local function note_attrs(opts)
  return {
    uid = function(e)
      return e._note.uid
    end,
    title = function(e)
      return e._note.title
    end,
    _note = function(e)
      return filenames.parse_filename(e.filename)
    end,
  }
end

---@diagnostic disable-next-line: unused-local
local function ripgrep_attrs(opts)
  return {
    filename = function(e)
      return decode(e._message.data.path)
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
  }
end

---@diagnostic disable-next-line: unused-local
local function ripgrep_text_attrs(opts)
  return {
    value = function(e)
      return decode(e._message.data.lines):gsub("[\r\n]+$", "")
    end,
    text = function(e)
      return e.value:gsub("^%s+", ""):gsub("%s+$", "")
    end,
    ordinal = function(e)
      return e.text
    end,
  }
end

---@diagnostic disable-next-line: unused-local
local function ripgrep_tag_attrs(opts)
  local seen = {}
  return {
    value = function(e)
      local matches = {}
      for _, m in ipairs(e._message.data.submatches) do
        table.insert(matches, decode(m.match))
      end
      return table.concat(matches, " ")
    end,
    text = function(e)
      return e.value
    end,
    ordinal = function(e)
      return e.text
    end,
    valid = function(e)
      if seen[e.value] then
        return false
      end

      seen[e.value] = true
      return true
    end,
  }
end

local function set_lazy_attrs(tbl, metaattrs)
  return setmetatable(tbl, {
    __index = function(e, key)
      local raw = rawget(e, key)
      if raw ~= nil then
        return raw
      end

      local make_value = rawget(metaattrs, key)
      if make_value then
        local value = make_value(e)
        rawset(e, key, value)
        return value
      end

      return nil
    end,
  })
end

local function contiguous(src_text, matches, match_hl)
  local segs = {}

  local last_stop = 1
  for _, m in ipairs(matches) do
    local m_start = 1 + m["start"]
    local m_stop = 1 + m["end"]

    if last_stop < m_start then
      local pre_text = strings.sub(src_text, last_stop, m_start - 1)
      table.insert(segs, { text = pre_text, elidable = true })
    end

    local m_text = strings.sub(src_text, m_start, m_stop - 1)
    table.insert(
      segs,
      { text = m_text, elidable = false, hl = match_hl or "keyword" }
    )

    last_stop = m_stop
  end

  if last_stop < strings.len(src_text) then
    local post_text = strings.sub(src_text, last_stop)
    table.insert(segs, { text = post_text, elidable = true })
  end

  return segs
end

local function strip_ends(segs)
  if #segs <= 0 then
    return
  end

  local count = 0

  if segs[#segs].elidable then
    segs[#segs].text, count = segs[#segs].text:gsub("%s+$", "")
    if count > 0 then
      segs[#segs]._text_len = nil
    end
    if #segs[#segs].text <= 0 then
      table.remove(segs, #segs)
    end
  end

  if segs[1].elidable then
    segs[1].text, count = segs[1].text:gsub("^%s+", "")
    if count > 0 then
      segs[1]._text_len = nil
    end
    if #segs[1].text <= 0 then
      table.remove(segs, 1)
    end
  end
end

local function elidable_len(segs, remainder)
  local last_len = 0
  for i, seg in ipairs(segs) do
    seg._text_len = seg._text_len or strings.len(seg.text)
    local distrib_num = #segs - i + 1
    local distrib_sum = (seg._text_len - last_len) * distrib_num
    if remainder >= distrib_sum then
      remainder = remainder - distrib_sum
    else
      local distrib_len = math.floor(remainder / distrib_num)
      local context_len = last_len + distrib_len
      remainder = remainder - (distrib_len * distrib_num)
      return context_len, remainder
    end
    last_len = seg._text_len
  end

  return math.max(last_len, remainder), 0
end

local function elide(segs, max_len)
  arrays.apply(segs, function(seg)
    seg._text_len = seg._text_len or strings.len(seg.text)
  end)

  local fixed_len = arrays.sum(segs, function(seg)
    return not seg.elidable and seg._text_len or 0
  end)

  local available = max_len - fixed_len
  if available < 0 then
    return false
  end

  local elidables = arrays.get_if(segs, function(s)
    return s.elidable
  end)
  table.sort(elidables, function(a, b)
    return a._text_len < b._text_len
  end)
  local max_elidable_len, remainder = elidable_len(elidables, available)

  assert(not segs[1]._first)
  assert(not segs[#segs]._last)
  segs[1]._first = true
  segs[#segs]._last = true

  for _, seg in ipairs(elidables) do
    if seg._text_len > max_elidable_len and seg._text_len > 1 then
      local extra = (seg._text_len > max_elidable_len + 1 and remainder > 0)
          and 1
        or 0
      remainder = remainder - extra
      local allotted = max_elidable_len + extra

      if seg._first then
        seg.text = elipsis .. strings.sub(seg.text, -(allotted - 1))
        seg._text_len = nil
      elseif seg._last then
        seg.text = strings.sub(seg.text, 1, allotted - 1) .. elipsis
        seg._text_len = nil
      else
        seg.text = strings.sub(seg.text, 1, math.ceil(allotted / 2) - 1)
          .. elipsis
          .. seg.text:sub(-math.floor(allotted / 2))
        seg._text_len = nil
      end
    end
  end

  segs[1]._first = nil
  segs[#segs]._last = nil

  return true
end

local function get_win_width()
  local status = tsstate.get_status(vim.api.nvim_get_current_buf())
  return vim.api.nvim_win_get_width(status.results_win)
    - status.picker.selection_caret:len()
    - 2
end

-- this function is separate from the metatable because highlights don't work
-- unless "display" is in the original entry table
local function ripgrep_file_display(opts)
  local win_width = nil
  return function(e)
    local segs = {}
    win_width = win_width or get_win_width()

    if true or opts.disable_devicons ~= true then
      local ico, hl = tsutils.get_devicons(e.filename, opts.disable_devicons)
      if ico and #ico > 0 then
        table.insert(segs, { text = ico, hl = opts.icon_hl or hl })
        table.insert(segs, { text = " " })
      end
    end

    if opts.disable_uid == false then
      table.insert(segs, { text = e.uid, hl = opts.uid_hl or "comment" })
      table.insert(segs, { text = " " })
    end

    if opts.disable_title == false then
      table.insert(segs, { text = e.title, hl = opts.title_hl })
      table.insert(segs, { text = " " })
    end

    if opts.disable_filename == false then
      local filename = tsutils.transform_path(opts, e.filename)
      table.insert(segs, { text = filename, hl = opts.filename_hl })
      table.insert(segs, { text = " " })
    end

    if opts.disable_coordinates == false and e.lnum then
      table.insert(
        segs,
        { text = tostring(e.lnum), hl = opts.coordinates_hl or "comment" }
      )
      if e.col then
        table.insert(
          segs,
          { text = ":", hl = opts.coordinates_hl or "comment" }
        )
        table.insert(
          segs,
          { text = tostring(e.col), hl = opts.coordinates_hl or "comment" }
        )
      end
      table.insert(segs, { text = " " })
    end

    if opts.disable_text ~= true and e.text then
      local match_segs = contiguous(e.text, e._message.data.submatches)

      if opts.disable_elision ~= true then
        local req_width = arrays.sum(match_segs, function(seg)
          seg._text_len = seg._text_len or strings.len(seg.text)
          if seg.elidable and seg._text_len > 0 then
            return 1
          end
          return seg._text_len
        end)

        strip_ends(match_segs)

        local elided_width = math.ceil(req_width / win_width) * win_width
        elide(match_segs, elided_width)
      end

      arrays.extend(segs, match_segs)
    end

    return highlights(segs)
  end
end

local function ripgrep_entry_maker(opts, make_attrs)
  opts = vim.tbl_deep_extend("force", {}, opts or {})

  local filename = nil
  return function(msg)
    msg = vim.fn.json_decode(msg)
    if not msg then
      return nil
    end

    if msg.type == "begin" then
      filename = decode(msg.data.path)
    elseif msg.type == "match" then
      if not filename then
        return nil
      end

      msg.data.path.text = filename
      msg.data.path.bytes = nil

      return make_attrs(msg)
    elseif msg.type == "end" then
      filename = nil
    end

    return nil
  end
end

function M.filename_entry_maker(opts)
  return function(filename)
    local entry = {
      cwd = opts.cwd,
      ordinal = filename,
      value = filename,
      filename = filename,
      display = function(e)
        local segs = {}

        local icon, icon_hl =
          tsutils.get_devicons(e.value, opts.disable_devicons)
        if icon and icon_hl then
          table.insert(segs, { text = icon, hl = icon_hl })
          table.insert(segs, { text = " " })
        end

        if opts.disable_uid == false and e.uid and #e.uid > 0 then
          table.insert(segs, { text = e.uid, hl = "comment" })
          table.insert(segs, { text = " " })
        end

        table.insert(segs, { text = e.title })

        return highlights(segs)
      end,
    }

    local attrs = {}
    tables.merge(file_attrs(opts), attrs)
    tables.merge(note_attrs(opts), attrs)

    return set_lazy_attrs(entry, attrs)
  end
end

function M.tag_entry_maker(opts)
  opts = vim.tbl_deep_extend("force", {}, opts or {})
  local function display(e)
    local segs = {}

    if not opts.disable_devicons then
      table.insert(segs, { text = "󰓹 " })
    end
    table.insert(segs, { text = e.value })

    return highlights(segs)
  end

  return ripgrep_entry_maker(opts, function(msg)
    local entry = { cwd = opts.cwd, display = display, _message = msg }

    local attrs = ripgrep_attrs(opts)
    tables.merge(ripgrep_tag_attrs(opts), attrs)

    return set_lazy_attrs(entry, attrs)
  end)
end

function M.backlink_entry_maker(opts)
  opts = vim.tbl_deep_extend("force", {}, opts or {})
  return ripgrep_entry_maker(opts, function(msg)
    local entry = {
      cwd = opts.cwd,
      display = ripgrep_file_display(opts),
      _message = msg,
    }

    local attrs = {}
    tables.merge(file_attrs(opts), attrs)
    tables.merge(note_attrs(opts), attrs)
    tables.merge(ripgrep_attrs(opts), attrs)
    tables.merge(ripgrep_text_attrs(opts), attrs)

    return set_lazy_attrs(entry, attrs)
  end)
end

function M.ripgrep_entry_maker(opts)
  opts = vim.tbl_deep_extend("force", {}, opts or {})
  return ripgrep_entry_maker(opts, function(msg)
    local entry = {
      cwd = opts.cwd,
      display = ripgrep_file_display(opts),
      _message = msg,
    }

    local attrs = {}
    tables.merge(file_attrs(opts), attrs)
    tables.merge(note_attrs(opts), attrs)
    tables.merge(ripgrep_attrs(opts), attrs)
    tables.merge(ripgrep_text_attrs(opts), attrs)

    return set_lazy_attrs(entry, attrs)
  end)
end

return M
