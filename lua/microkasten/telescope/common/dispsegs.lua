local M = {}

local tsstate = require("telescope.state")

local arrays = require("microkasten.luamisc.arrays")
local strings = require("microkasten.luamisc.strings")

local elipsis = "\xe2\x80\xa6" -- horizontal "..." char

---@class seg
---@field text string?
---@field _text_len integer?
---@field elidable boolean?
---@field hl string?

---@param segs seg[]
function M.strip(segs)
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

---@param segs seg[]
---@param max_len integer
---@return boolean is_success
function M.elide(segs, max_len)
  arrays.apply(segs, function(seg)
    seg._text_len = seg._text_len or (seg.text and strings.len(seg.text) or 0)
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

  -- TODO need cleaner, non-mutating way of marking first and last text segment

  ---@diagnostic disable-next-line: undefined-field
  assert(not segs[1]._first)
  ---@diagnostic disable-next-line: undefined-field
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

      assert(seg.text, "segment must have text")
      local seg_text = seg.text
      if seg._first then
        seg.text = elipsis .. strings.sub(seg_text, -(allotted - 1))
        seg._text_len = nil
      elseif seg._last then
        seg.text = strings.sub(seg_text, 1, allotted - 1) .. elipsis
        seg._text_len = nil
      else
        seg.text = strings.sub(seg_text, 1, math.ceil(allotted / 2) - 1)
          .. elipsis
          .. seg_text:sub(-math.floor(allotted / 2))
        seg._text_len = nil
      end
    end
  end

  segs[1]._first = nil
  segs[#segs]._last = nil

  return true
end

---@return integer len available screen width in telescope window
function M.win_width()
  local status = tsstate.get_status(vim.api.nvim_get_current_buf())
  return vim.api.nvim_win_get_width(status.results_win)
    - status.picker.selection_caret:len()
    - 2
end

---@param segs seg[]
---@return string text
---@return table hls
function M.render(segs)
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

return M
