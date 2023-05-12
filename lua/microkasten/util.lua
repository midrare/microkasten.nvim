local modulename, _ = ...
local moduleroot = modulename:gsub('(.+)%..+', '%1')

local os = require('os')

local date = require((moduleroot or 'microkasten') .. '.date')
local paths = require((moduleroot or 'microkasten') .. '.path')

local M = {}

M.uid_template = '%Y%m%d%H%M'
M.link_pattern = '%[%[(..-)%]%]'

local last_uid = nil

local path_sep = '/'
if vim.fn.has('win32') > 0 then
  path_sep = '\\'
end

function M.generate_uid()
  local dt = date(true)
  local uid = dt:fmt(M.uid_template)

  while uid == last_uid do
    dt = dt:addminutes(1)
    uid = dt:fmt(M.uid_template)
  end

  last_uid = uid
  return uid
end

function M.parse_uid(filename)
  local tail = paths.basename(filename)
  return tail:match('^([%d%.%-%_]+)%s+')
end

function M.parse_title(filename)
  local s = filename:gsub('^[%d%.%-%_]+%s+', '')
  return paths.filestem(s):gsub('^%s*', ''):gsub('%s*$', '')
end

function M.to_retitled_filename(filename, title)
  local uid = M.parse_uid(filename)
  local ext = paths.fileext(filename)

  local new_filename = ''
  if uid and #uid > 0 then
    new_filename = new_filename .. uid .. ' '
  end
  if title and #title > 0 then
    new_filename = new_filename .. title
  end
  if ext and #ext > 0 then
    new_filename = new_filename .. ext
  end

  local dir = paths.dirname(filename)
  local new_filepath = new_filename
  if dir and #dir > 0 then
    new_filepath = dir .. path_sep .. new_filename
  end

  return new_filepath
end

return M
