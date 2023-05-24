local M = {}

local paths = require("microkasten.luamisc.paths")
local formats = require("microkasten.formats")
local useropts = require("microkasten.useropts")

---@param filename string file name to parse
---@return noteinfo info note metadata
function M.parse_filename(filename)
  if useropts.parse_filename then
    return useropts.parse_filename(filename)
  end

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
  note = note and vim.deepcopy(note) or {}
  note.ext = paths.canonical_ext(note.ext) or formats.default_ext()

  if useropts.generate_filename then
    return useropts.generate_filename(note)
  end

  local parts = {}

  if note.uid then
    table.insert(parts, note.uid)
  end
  if note.title then
    table.insert(parts, note.title)
  end

  local filename = table.concat(parts, " ")
  return filename .. note.ext
end

return M
