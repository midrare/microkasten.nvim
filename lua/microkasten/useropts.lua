local M = {}

---@type function()?
M.on_attach = nil

---@type string
M.data_dir = vim.fn.stdpath("data") .. "/microkasten"

---@type string|string[]
M.exts = {}

---@type string?
M.default_ext = nil

M.formats = {}

M.parse_filename = nil
M.generate_filename = nil

M.links = {
  regex = nil,
  luapat = nil,
}

return M
