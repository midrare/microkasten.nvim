local M = {}

---@param cmd string[]
---@param flag string
---@param enabled boolean?
function M.add_flag(cmd, flag, enabled)
  if enabled then
    table.insert(cmd, flag)
  end
end

---@param cmd string[]
---@param flag string
---@param value nil|any|any[]
function M.add_values(cmd, flag, value)
  local type_ = type(value)
  if type_ == "table" then
    for _, val in ipairs(value) do
      M.add_values(cmd, flag, val)
    end
  elseif value ~= nil then
    table.insert(cmd, flag)
    table.insert(cmd, value)
  end
end

local function close_gaps(cmd, max_idx)
  local i = 1
  for j = 1, max_idx do
    if cmd[j] ~= nil then
      local val = cmd[j]
      cmd[j] = nil
      cmd[i] = val
    end
  end
end

---@param cmd string[]
---@vararg string
function M.remove_flags(cmd, ...)
  local max = #cmd

  for i = 1, max do
    for j = 1, select("#", ...) do
      if cmd[i] == select(j, ...) then
        cmd[i] = nil
        break
      end
    end
  end

  close_gaps(cmd, max)
end

---@param cmd string[]
---@vararg string
function M.remove_values(cmd, ...)
  local max = #cmd

  for i = 1, max do
    for j = 1, select("#", ...) do
      if cmd[i] == select(j, ...) then
        cmd[i] = nil
        cmd[i+1] = nil
        break
      end
    end
  end

  close_gaps(cmd, max)
end

return M
