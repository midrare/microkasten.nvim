local M = {}

local tables = require('microkasten.luamisc.tables')
local date = require('microkasten.luamisc.date')
local paths = require('microkasten.luamisc.paths')
local util = require('microkasten.util')
local actions = require('microkasten.telescope.util.actions')

local tsactions = require('telescope.actions')

local evaluable = {}
local functionable = {}
local flattenable = {}
local _last_uid = nil


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


local function evaluate(o)
  local type_ = type(o)
  if type_ == 'function' then
    return o()
  elseif type_ == 'table' then
    for k, v in pairs(o) do
      o[k] = evaluate(v)
    end
  end

  return o
end


function M.apply_syntax()
  vim.cmd('syntax region String matchgroup=String'
    .. ' start=/\\[\\[/ skip=/[^\\[\\]]/ end=/\\]\\]/ display oneline')
  vim.cmd[[syntax match String "\v#[a-zA-Z]+[a-zA-Z0-9\\-_]*"]]
end


---@return string uid generated uid
function M.generate_uid()
  local pat = '%Y%m%d%H%M'
  local dt = date(true)
  local uid = dt:fmt(pat)

  while uid == _last_uid do
    dt = dt:addminutes(1)
    uid = dt:fmt(pat)
  end

  _last_uid = uid
  return uid
end

---@param filename string file name to parse
---@return noteinfo info note metadata
function M.parse_filename(filename)
  local basename = paths.basename(filename)
  local stem = paths.filestem(basename) or ''
  local ext = paths.fileext(filename)
  local uid = stem:match('^([%d%.%-%_]+)%s+')
  local title = stem:gsub('^[%d%.%-%_]+%s+', '')
  return { uid = uid, title = title, ext = ext }
end


---@param note noteinfo note metadata
---@return string filename constructed filename
function M.generate_filename(note)
  note = note or {}
  local ext = note.ext:gsub('^%.+', '')
  ext = (ext and ('.' .. ext)) or ''

  local parts = {}

  if note.uid then
    table.insert(parts, note.uid)
  end
  if note.title then
    table.insert(parts, note.title)
  end

  local filename = table.concat(parts, ' ')
  return filename .. ext
end


---@param uid string uid of note
---@return string|string[] pat regex matching links that target provided note
function M.backlinks_regex(uid)
  return "\\[\\[[^\\n]*" .. uid .. "[^\\n]*\\]\\]"
end


flattenable.tags_regex = true
---@return string|string[] pat regex pattern to match tags
function M.tags_regex()
  return {
    "(?:\\b|[!\"#$%&\'()*+,\\-\\./:;<=>?@\\^_`{|}~])"
      .. "#([a-zA-Z][a-zA-Z0-9\\-_]*)"
      .. "(?:\\b|[!\"#$%&\'()*+,\\-\\./:;<=>?@\\^_`{|}~])",
    "^\\s*[tT][aA][gG][sS]?:\\s.*"
      .. "(?:\\b|[!\"#$%&\'()*+,\\-\\./:;<=>?@\\^_`{|}~])"
      .. "([a-zA-Z][a-zA-Z0-9\\-_]*)"
      .. "(?:\\b|[!\"#$%&\'()*+,\\-\\./:;<=>?@\\^_`{|}~])"
  }
end


function M.on_attach()
end


function M.telescope_mappings(_, map)
  tsactions.select_default:replace(actions.open_file)
  map("i", "<c-y>", actions.yank_uid)
  map("i", "<c-i>", actions.put_uid)
  map("n", "<c-y>", actions.yank_uid)
  map("n", "<c-i>", actions.put_uid)
  map("n", "<c-c>", actions.close)
  map("n", "<esc>", actions.close)
  return true
end


---@param link string
---@return notelink link
function M.parse_link(link)
  link = link:gsub('^%[%[', '') :gsub('%]%]$', '')

  local start, stop, title = link:find('|%s*(.+)$')
  if start and stop then
    link = link:sub(1, start - 1) .. link:sub(stop + 1)
  end

  ---@diagnostic disable-next-line: redefined-local
  local start, stop, prefix = link:find('^(.+)%s*:%s*')
  if start and stop then
    link = link:sub(1, start - 1) .. link:sub(stop + 1)
  end

  ---@diagnostic disable-next-line: redefined-local, unused-local
  link = link:gsub('^%s+', ''):gsub('%s+$', '')
  local uid = link and #link > 0 and link or nil
  return { uid = uid, title = title, prefix = prefix }
end


---@param dir string dir to search in
---@param uid string uid of note to find
---@return string? filename note file if found
function M.find_uid_in_dir(dir, uid)
  if not uid or #uid <= 0 then
    return nil
  end

  local filenames = util.list_dir(dir, uid)
  if not filenames or #filenames <= 0 then
    return nil
  end

  return filenames[1]
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

---@type string
M.data_dir = vim.fn.stdpath('data') .. '/microkasten'

flattenable.exts = true
---@type string[]
M.exts = { '.md', '.norg' }

---@type string
M.default_ext = '.md'


local M2 = vim.deepcopy(M)
return setmetatable(M, {
  __index = function(o, attr)
    local value = rawget(o, attr)
    if value == nil then
      value = rawget(M2, attr)
    end

    if evaluable[attr] then
      value = evaluate(value)
    end

    if flattenable[attr] then
      if type(value) == "function" then
        local f = value
        value = function(...)
          return tables.flattened({ f(...) })
        end
      else
        value = tables.flattened({ value })
      end
    end

    if functionable[attr] and type(value) ~= "function" then
      local r = value
      value = function()
        return r
      end
    end

    return value
  end,
})
