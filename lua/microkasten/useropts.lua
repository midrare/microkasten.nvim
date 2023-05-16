local M = {}

---@type function()?
M.on_attach = nil

---@type string
M.data_dir = vim.fn.stdpath("data") .. "/microkasten"

---@type string|string[]
M.exts = {}

---@type string?
M.default_ext = nil

return M
