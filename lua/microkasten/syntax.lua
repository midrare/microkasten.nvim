local M = {}

local useropts = require("microkasten.useropts")

function M.apply_syntax()
  if useropts.apply_syntax then
    useropts.apply_syntax()
    return
  end
  vim.cmd(
    "syntax region String matchgroup=String"
      .. " start=/\\[\\[/ skip=/[^\\[\\]]/ end=/\\]\\]/ display oneline"
  )
  vim.cmd([[syntax match String "\v#[a-zA-Z]+[a-zA-Z0-9\\-_]*"]])
end

---@return string|string[] pat regex pattern to match tags
function M.tags_regex()
  if useropts.generate_tags_regex then
    return useropts.generate_tags_regex()
  end

  return {
    "(?:\\b|[!\"#$%&'()*+,\\-\\./:;<=>?@\\^_`{|}~])"
      .. "#([a-zA-Z][a-zA-Z0-9\\-_]*)"
      .. "(?:\\b|[!\"#$%&'()*+,\\-\\./:;<=>?@\\^_`{|}~])",
    "^\\s*[tT][aA][gG][sS]?:\\s.*"
      .. "(?:\\b|[!\"#$%&'()*+,\\-\\./:;<=>?@\\^_`{|}~])"
      .. "([a-zA-Z][a-zA-Z0-9\\-_]*)"
      .. "(?:\\b|[!\"#$%&'()*+,\\-\\./:;<=>?@\\^_`{|}~])",
  }
end

---@param note noteinfo note targeted by link
---@return string|string[] pat regex matching link that targets note
function M.links_regex(note)
  return "\\[\\[[^\\n]*" .. note.uid .. "[^\\n]*\\]\\]"
end

return M
