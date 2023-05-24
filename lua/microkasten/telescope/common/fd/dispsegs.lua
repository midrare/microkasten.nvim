local M = {}

local tsutils = require("telescope.utils")

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
  if opts.disable_title ~= true then
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

return M
