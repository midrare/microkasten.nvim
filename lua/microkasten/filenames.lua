local M = {}

local paths = require("microkasten.luamisc.paths")

---@param filename string file name to parse
---@return noteinfo info note metadata
function M.parse_filename(filename)
  local basename = paths.basename(filename)
  local stem = paths.filestem(basename) or ""
  local ext = paths.fileext(filename)
  local uid = stem:match("^([%d%.%-%_]+)%s+")
  local title = stem:gsub("^[%d%.%-%_]+%s+", "")
  return { uid = uid, title = title, ext = ext }
end

---@param note noteinfo note metadata
---@return string filename constructed filename
function M.generate_filename(note)
  note = note or {}
  local ext = note.ext:gsub("^%.+", "")
  ext = (ext and ("." .. ext)) or ""

  local parts = {}

  if note.uid then
    table.insert(parts, note.uid)
  end
  if note.title then
    table.insert(parts, note.title)
  end

  local filename = table.concat(parts, " ")
  return filename .. ext
end

return M
