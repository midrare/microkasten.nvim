local M = {}

local tsutils = require("telescope.utils")

local arrays = require("microkasten.luamisc.arrays")
local strings = require("microkasten.luamisc.strings")

local dispsegs = require("microkasten.telescope.common.dispsegs")

function M.add_fileicon_segs(opts, segs, entry)
  if opts.disable_devicons ~= true then
    local ico, hl = tsutils.get_devicons(entry.filename, opts.disable_devicons)
    if ico and #ico > 0 then
      if #segs > 0 then
        table.insert(segs, { text = " " })
      end
      table.insert(segs, { text = ico, hl = opts.icon_hl or hl })
    end
  end
end

function M.add_uid_segs(opts, segs, entry)
  if opts.disable_uid == false then
    if #segs > 0 then
      table.insert(segs, { text = " " })
    end
    table.insert(segs, { text = entry.uid, hl = opts.uid_hl or "comment" })
  end
end

function M.add_title_segs(opts, segs, entry)
  if opts.disable_title == false then
    if #segs > 0 then
      table.insert(segs, { text = " " })
    end
    table.insert(segs, { text = entry.title, hl = opts.title_hl })
  end
end

function M.add_filename_segs(opts, segs, entry)
  if opts.disable_filename == false then
    if #segs > 0 then
      table.insert(segs, { text = " " })
    end
    local filename = tsutils.transform_path(opts, entry.filename)
    table.insert(segs, { text = filename, hl = opts.filename_hl })
  end
end

function M.add_coordinate_segs(opts, segs, entry)
  if opts.disable_coordinates == false and entry.lnum then
    if #segs > 0 then
      table.insert(segs, { text = " " })
    end

    table.insert(
      segs,
      { text = tostring(entry.lnum), hl = opts.coordinates_hl or "comment" }
    )
    if entry.col then
      table.insert(segs, { text = ":", hl = opts.coordinates_hl or "comment" })
      table.insert(
        segs,
        { text = tostring(entry.col), hl = opts.coordinates_hl or "comment" }
      )
    end
  end
end

---@param matches match[]
---@param match_hl string?
---@return seg[] segments
local function to_segs(matches, match_hl)
  match_hl = match_hl or "keyword"

  local sentinel = 0
  matches = vim.tbl_extend("force", {}, matches)
  table.insert(matches, sentinel)

  local segs = {}

  local pos = nil
  local src = nil
  local lnum = nil

  for _, m in ipairs(matches) do
    if pos and lnum and (m == sentinel or lnum ~= m.lnum) then
      local post = strings.sub(src, pos):gsub("[\n\r]+", " ")
      if post and #post > 0 then
        table.insert(segs, { text = post, elidable = true })
      end
    end

    if m == sentinel then
      break
    elseif lnum ~= m.lnum then
      pos = 1
      lnum = m.lnum
      src = m.src
    end

    if pos < m.start then
      local pre = strings.sub(m.src, pos, m.start - 1):gsub("[\n\r]+", " ")
      table.insert(segs, { text = pre, elidable = true })
    end

    if m.start <= m.stop then
      local text = strings.sub(m.src, m.start, m.stop):gsub("[\n\r]+", " ")
      table.insert(segs, { text = text, elidable = false, hl = match_hl })
    end

    pos = m.stop + 1
  end

  return segs
end

function M.add_matches_segs(opts, segs, entry)
  if opts.disable_text ~= true then
    local match_segs = to_segs(entry._event.matches)

    if opts.disable_elision ~= true then
      local req_width = arrays.sum(match_segs, function(seg)
        seg._text_len = seg._text_len or strings.len(seg.text)
        if seg.elidable and seg._text_len > 0 then
          return 1
        end
        return seg._text_len
      end)

      dispsegs.strip(match_segs)

      local win_width = dispsegs.win_width()
      local elided_width = math.ceil(req_width / win_width) * win_width
      dispsegs.elide(match_segs, elided_width)
    end

    if #segs > 0 then
      table.insert(segs, { text = " " })
    end
    vim.list_extend(segs, match_segs)
  end
end

return M
