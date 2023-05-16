local M = {}

---@param dir string dir to search in
---@param uid string uid of note to find
---@return string? filename note file if found
function M.find_uid_in_dir(dir, uid)
  if not uid or #uid <= 0 then
    return nil
  end

  local filenames = M.list_dir(dir, uid)
  if not filenames or #filenames <= 0 then
    return nil
  end

  return filenames[1]
end

---@param dir string path to dir
---@param prefix string? include only if start of filename matches
---@return string[] filenames filenames in dir
M.list_dir = function(dir, prefix)
  prefix = (prefix and prefix:gsub('[^a-zA-Z0-9_%-:# %.]', '')) or nil
  local filenames = {}

  local cmd = ''
  if vim.fn.has('win32') > 0 then
    local p = dir:gsub('[\\/]+', '\\')
    if prefix and #prefix > 0 then
      p = p .. '\\' .. prefix .. '*'
    end
    -- do /not/ escape backslashes if you want dir command to work
    cmd = 'dir /B "' .. vim.fn.escape(p, '"') .. '" 2>nul'
  else
    local p = dir:gsub('[\\/]+', '/')
    if prefix and #prefix > 0 then
      p = p .. '/' .. prefix
    end
    cmd = 'ls -A -1 "' .. vim.fn.escape(p, '"') .. '"* 2>/dev/null'
  end

  local status_ok, pipe = pcall(io.popen, cmd)
  if status_ok and pipe ~= nil then
    local output = pipe:read('*a')
    pipe:close()

    for line in string.gmatch(output .. '\n', '([^\n]*)\n') do
      line = line:gsub('^%s*', ''):gsub('%s*$', '')
      if #line > 0 then
        table.insert(filenames, line)
      end
    end
  end

  return filenames
end


return M
