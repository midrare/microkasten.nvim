local M = {}

local paths = require("microkasten.luamisc.paths")

local metadata = require("microkasten.metadata")


M.filename_attrs = {
  value = function(e)
    return e.filename
  end,
  text = function(e)
    return e.filename
  end,
  ordinal = function(e)
    return e.filename
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
    return metadata.parse_filename(e.filename)
  end,
}

return M
