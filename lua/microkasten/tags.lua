local M = {}

local useropts = require("microkasten.useropts")

---@return string|string[] pat regex pattern to match tags
function M.generate_tags_regex()
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

return M
