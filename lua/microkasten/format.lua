local M = {}

local defaultable = require("microkasten.defaultable")
local util = require("microkasten.util")


local attrs = {}

local function clean_tags(tags)
  local cleaned = {}
  for _, tag in ipairs(tags) do
    tag = tag:gsub('^#', '')
    tag = tag:gsub('[^a-zA-Z0-9_%-%.]', '')
    if tag and #tag > 0 and not tag:match('^%s*$') then
      tag = '#' .. tag
      table.insert(cleaned, tag)
    end
  end
  return tags
end


---@param note noteinfo note info
---@return string? note plain text note contents
function M.generate_note_md(note)
  local tags = clean_tags(note.tags)
  local created = util.generate_timestamp()

  local lines = {}
  if note.title then
    table.insert(lines, 'title: ' .. note.title)
  end
  if note.uid then
    table.insert(lines, 'uid: ' .. note.uid)
  end
  if tags and #tags > 0 then
    table.insert(lines, 'tags: ' .. table.concat(tags, ', '))
  end
  table.insert(lines, 'created: ' .. created)

  if lines and #lines > 0 then
    table.insert(lines, 1, '---')
    table.insert(lines, '---')
    table.insert(lines, '')
    table.insert(lines, '')
  end

  return table.concat(lines, '\n')
end

---@param note noteinfo note info
---@return string? note plain text note contents
function M.generate_note_norg(note)
  local tags = clean_tags(note.tags)
  local created = util.generate_timestamp()

  local lines = {}
  if note.title then
    table.insert(lines, 'title: ' .. note.title)
  end
  if note.uid then
    table.insert(lines, 'uid: ' .. note.uid)
  end
  if tags and #tags > 0 then
    table.insert(lines, 'tags: [ ' .. table.concat(tags, ', ') .. ' ]')
  end
  table.insert(lines, 'created: ' .. created)

  if lines and #lines > 0 then
    table.insert(lines, 1, '@document.meta')
    table.insert(lines, '@end')
    table.insert(lines, '')
    table.insert(lines, '')
  end

  return table.concat(lines, '\n')
end


---@param note noteinfo note info
---@return string? note plain text note contents
function M.generate_note(note)
  local ext_to_gen = {
    md = M.generate_note_md,
    norg = M.generate_note_norg,
  }

  local ext = note.ext or '.md'
  ext = ext:gsub('^%.+', ''):lower()
  if not ext or #ext <= 0 then
    return nil
  end

  if not ext_to_gen[ext] then
    return nil
  end

  ---@diagnostic disable-next-line: param-type-mismatch
  return ext_to_gen[ext](ext)
end

function M.exts()
  return { '.md', '.norg' }
end

---@type string
M.default_ext = '.md'

return M
