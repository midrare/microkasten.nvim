local M = {}

local tsmt = require("telescope.actions.mt")
local tsactions = require("telescope.actions")
local tsstate = require("telescope.actions.state")

local winpicker_ok, winpicker = pcall(require, "window-picker")
winpicker = winpicker_ok and winpicker or nil

function M.put_uid(prompt_bufnr)
  ---@diagnostic disable-next-line: unused-local
  local picker = tsstate.get_current_picker(prompt_bufnr)
  local entry = tsstate.get_selected_entry()
  tsactions.close(prompt_bufnr)
  if entry.uid and #entry.uid > 0 then
    vim.api.nvim_put({ entry.uid }, "b", false, true)
  end
end

function M.put_path(prompt_bufnr)
  ---@diagnostic disable-next-line: unused-local
  local picker = tsstate.get_current_picker(prompt_bufnr)
  local entry = tsstate.get_selected_entry()
  tsactions.close(prompt_bufnr)
  if entry.filename and #entry.filename > 0 then
    vim.api.nvim_put({ entry.filename }, "b", false, true)
  end
end

function M.yank_uid(prompt_bufnr)
  ---@diagnostic disable-next-line: unused-local
  local picker = tsstate.get_current_picker(prompt_bufnr)
  local entry = tsstate.get_selected_entry()
  local reg = vim.api.nvim_get_vvar("register") or '"'
  tsactions.close(prompt_bufnr)
  vim.fn.setreg(reg, entry.uid)
end

function M.yank_path(prompt_bufnr)
  ---@diagnostic disable-next-line: unused-local
  local picker = tsstate.get_current_picker(prompt_bufnr)
  local entry = tsstate.get_selected_entry()
  local reg = vim.api.nvim_get_vvar("register") or '"'
  tsactions.close(prompt_bufnr)
  vim.fn.setreg(reg, entry.filename)
end

function M.open_file(prompt_bufnr)
  ---@diagnostic disable-next-line: unused-local
  local picker = tsstate.get_current_picker(prompt_bufnr)
  local entry = tsstate.get_selected_entry()
  tsactions.close(prompt_bufnr)
  if entry.filename and #entry.filename > 0 then
    if winpicker_ok and winpicker then
      local winnr = winpicker.pick_window({
        include_current_win = true,
        selection_chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890",
      })

      if not winnr or winnr < 0 then
        return
      end

      vim.api.nvim_set_current_win(winnr)
    end

    vim.cmd("silent! edit! " .. vim.fn.escape(entry.filename, " "))
  end
end

return tsmt.transform_mod(M)
