local module, _ = {}, nil
module.name, _ = ...

local moduleroot = module.name:gsub('(.+)%..+', '%1')
local date = require(moduleroot .. '.luamisc.date')
local paths = require(moduleroot .. '.luamisc.paths')


module.uid_template = '%Y%m%d%H%M'
module.link_pattern = '%[%[(..-)%]%]'

local last_uid = nil

local path_sep = vim.fn.has('win32') > 0 and  '\\' or '/'

function module.generate_uid()
  local dt = date(true)
  local uid = dt:fmt(module.uid_template)

  while uid == last_uid do
    dt = dt:addminutes(1)
    uid = dt:fmt(module.uid_template)
  end

  last_uid = uid
  return uid
end

function module.parse_uid(filename)
  local tail = paths.basename(filename)
  return tail:match('^([%d%.%-%_]+)%s+')
end

function module.parse_title(filename)
  local s = filename:gsub('^[%d%.%-%_]+%s+', '')
  return paths.filestem(s):gsub('^%s*', ''):gsub('%s*$', '')
end

function module.to_retitled_filename(filename, title)
  local uid = module.parse_uid(filename)
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

return module
