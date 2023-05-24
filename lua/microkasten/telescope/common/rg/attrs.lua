local M = {}

local paths = require("microkasten.luamisc.paths")

local filenames = require("microkasten.filenames")

M.filename_attrs = {
  filename = function(e)
    return e._event.filename
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
    return e._event.lnum
  end,
  col = function(e)
    return e._event.col
  end,
}

M.tag_attrs = {
  value = function(e)
    local srcs = {}
    for _, m in ipairs(e._event.matches) do
      local s = m.src:gsub("^%s+", ""):gsub("%s+$", "")
      table.insert(srcs, s)
    end
    return table.concat(srcs, " ")
  end,
  text = function(e)
    return e.value
  end,
  ordinal = function(e)
    return e.text
  end,
}

M.line_attrs = {
  value = function(e)
    local srcs = {}
    for _, m in ipairs(e._event.matches) do
      table.insert(srcs, m.src)
    end
    return table.concat(srcs, " ")
  end,
  text = function(e)
    return e.value
  end,
  ordinal = function(e)
    return e.text
  end,
}

return M
