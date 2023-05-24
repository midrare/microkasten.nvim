local M = {}

local paths = require("microkasten.luamisc.paths")

local filenames = require("microkasten.filenames")

local rgutil = require("microkasten.telescope.common.rg.util")

M.filename_attrs = {
  filename = function(e)
    return rgutil.decode(e._message.data.path)
  end,
  path = function(e)
    return paths.abspath(e.filename, e.cwd)
  end,
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

M.coordinate_attrs = {
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

M.tag_attrs = {
  value = function(e)
    local matches = {}
    for _, m in ipairs(e._message.data.submatches) do
      table.insert(matches, rgutil.decode(m.match))
    end
    return table.concat(matches, " ")
  end,
  text = function(e)
    return e.value:gsub("^%s+", ""):gsub("%s+$", "")
  end,
  ordinal = function(e)
    return e.text
  end,
}

M.line_attrs = {
  value = function(e)
    return rgutil.decode(e._message.data.lines):gsub("[\r\n]+$", "")
  end,
  text = function(e)
    return e.value:gsub("^%s+", ""):gsub("%s+$", "")
  end,
  ordinal = function(e)
    return e.text
  end,
}

return M
