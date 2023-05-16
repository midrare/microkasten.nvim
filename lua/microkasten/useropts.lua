local M = {}

local tables = require('microkasten.luamisc.tables')
local date = require('microkasten.luamisc.date')
local paths = require('microkasten.luamisc.paths')
local util = require('microkasten.util')
local actions = require('microkasten.telescope.picker.actions')

local tsactions = require('telescope.actions')

local evaluable = {}
local functionable = {}
local flattenable = {}
local _last_uid = nil


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
