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

local function segmented(src_text, matches, match_hl)
  assert(src_text, "expected src text")
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

function M.add_matches_segs(opts, segs, entry)
  if opts.disable_text ~= true and entry.text then
    local match_segs = segmented(entry.text, entry._message.data.submatches)

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
