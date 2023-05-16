local M = {}

local arrays = require("microkasten.luamisc.arrays")
local paths = require("microkasten.luamisc.paths")
local tables = require("microkasten.luamisc.tables")
local useropts = require("microkasten.useropts")
local util = require("microkasten.util")

local function clean_tags(tags)
  local cleaned = {}
  for _, tag in ipairs(tags) do
    tag = tag:gsub("^#", "")
    tag = tag:gsub("[^a-zA-Z0-9_%-%.]", "")
    if tag and #tag > 0 and not tag:match("^%s*$") then
      tag = "#" .. tag
      table.insert(cleaned, tag)
    end
  end
  return tags
end


---@param note noteinfo note info
---@return string? note plain text note contents
local function generate_markdown(note)
  local tags = clean_tags(note.tags)
  local created = util.generate_timestamp()

  local lines = {}
  if note.title then
    table.insert(lines, "title: " .. note.title)
  end
  if note.uid then
    table.insert(lines, "uid: " .. note.uid)
  end
  if tags and #tags > 0 then
    table.insert(lines, "tags: " .. table.concat(tags, ", "))
  end
  table.insert(lines, "created: " .. created)

  if lines and #lines > 0 then
    table.insert(lines, 1, "---")
    table.insert(lines, "---")
    table.insert(lines, "")
    table.insert(lines, "")
  end

  return table.concat(lines, "\n")
end

---@param note noteinfo note info
---@return string? note plain text note contents
local function generate_neorg(note)
  local tags = clean_tags(note.tags)
  local created = util.generate_timestamp()

  local lines = {}
  if note.title then
    table.insert(lines, "title: " .. note.title)
  end
  if note.uid then
    table.insert(lines, "uid: " .. note.uid)
  end
  if tags and #tags > 0 then
    table.insert(lines, "tags: [ " .. table.concat(tags, ", ") .. " ]")
  end
  table.insert(lines, "created: " .. created)

  if lines and #lines > 0 then
    table.insert(lines, 1, "@document.meta")
    table.insert(lines, "@end")
    table.insert(lines, "")
    table.insert(lines, "")
  end

  return table.concat(lines, "\n")
end

---@param note noteinfo note info
---@return string? note plain text note contents
function M.generate_note(note)
  local ext_to_gen = {
    md = generate_markdown,
    norg = generate_neorg,
  }

  local ext = paths.canonical_ext(note.ext) or M.default_ext()
  if not ext then
    return nil
  end

  if type((useropts.formats or {}).generate) == "function" then
    return useropts.formats.generate(note)
  elseif
    type((useropts.formats or {}).generate) == "table"
    and useropts.formats[ext]
  then
    return useropts.formats[ext](note)
  end

  if not ext_to_gen[ext] then
    return nil
  end

  ---@diagnostic disable-next-line: param-type-mismatch
  return ext_to_gen[ext](ext)
end

---@return string[] exts file extensions
function M.exts()
  local exts = tables.flattened({ useropts.exts })
  table.insert(exts, useropts.default_ext)
  arrays.transform(exts, paths.canonical_ext)
  arrays.uniqify(exts)

  if #exts > 0 then
    return exts
  end

  return { ".md", ".norg" }
end

---@return string ext default file extension
function M.default_ext()
  if useropts.default_ext then
    local ext = paths.canonical_ext(useropts.default_ext)
    if ext and #ext > 0 then
      return ext
    end
  end

  local exts = M.exts()
  if exts and #exts > 0 then
    return exts[1]
  end

  return ".md"
end

return M
