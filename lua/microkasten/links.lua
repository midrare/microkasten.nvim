local M = {}

local function find_pat_at(pat, s, idx)
  local pos = 1
  while pos <= #s do
    local start, stop = s:find(pat, pos)
    if not start or not stop then
      break
    end
    if start <= idx and stop >= idx then
      return s:sub(start, stop)
    end
    pos = stop + 1
  end
  return nil
end

---@param link string
---@return notelink link
function M.parse_link(link)
  link = link:gsub("^%[%[", ""):gsub("%]%]$", "")

  local start, stop, title = link:find("|%s*(.+)$")
  if start and stop then
    link = link:sub(1, start - 1) .. link:sub(stop + 1)
  end

  ---@diagnostic disable-next-line: redefined-local
  local start, stop, prefix = link:find("^(.+)%s*:%s*")
  if start and stop then
    link = link:sub(1, start - 1) .. link:sub(stop + 1)
  end

  ---@diagnostic disable-next-line: redefined-local, unused-local
  link = link:gsub("^%s+", ""):gsub("%s+$", "")
  local uid = link and #link > 0 and link or nil
  return { uid = uid, title = title, prefix = prefix }
end

---@param uid string uid of note
---@return string|string[] pat regex matching links that target provided note
function M.backlinks_regex(uid)
  return "\\[\\[[^\\n]*" .. uid .. "[^\\n]*\\]\\]"
end

---@param pat? string link pattern
---@param pos? cursor cursor pos
---@return string? link link string
function M.get_link_at(pos, pat)
  pat = pat or "%[%[..*%]%]"
  if not pos then
    local o = vim.fn.getpos(".")
    pos = { row = o[2], col = o[3] }
  end

  local line = vim.fn.getline(pos.row)
  if not line or #line <= 0 then
    return nil
  end

  return find_pat_at(pat, line, pos.col)
end

return M
