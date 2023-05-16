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



function M.on_attach()
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

---@type string|string[]
M.exts = {}

---@type string?
M.default_ext = nil

return M
