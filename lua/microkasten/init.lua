local M = {}

local arrays = require("microkasten.luamisc.arrays")
local files = require("microkasten.luamisc.files")
local paths = require("microkasten.luamisc.paths")
local tables = require("microkasten.luamisc.tables")

local formats = require("microkasten.formats")
local filesystem = require("microkasten.filesystem")
local links = require("microkasten.links")
local filenames = require("microkasten.filenames")
local syntax = require("microkasten.syntax")
local useropts = require("microkasten.useropts")
local util = require("microkasten.util")

function M._run_hook(hook)
  local type_ = type(hook)
  if type_ == "table" then
    for _, hk in ipairs(hook) do
      M._run_hook(hk)
    end
  elseif type_ == "function" then
    hook()
  end
end

function M._on_attach()
  syntax.apply_syntax()
  M._run_hook(useropts.on_attach)
end

local function init_autocmds()
  vim.cmd("augroup microkasten_syntax")
  vim.cmd("autocmd!")

  local pats = formats.exts()
  arrays.transform(pats, function(s)
    return "*" .. s
  end)
  local exts_pat = table.concat(pats, ",")

  if exts_pat and #exts_pat > 0 then
    local cmd = ([[
      autocmd BufEnter,BufRead,BufNewFile {EXTS} lua
      \ do
      \   local microkasten_ok, microkasten = pcall(require, "microkasten")
      \   if microkasten_ok and microkasten then
      \     microkasten._on_attach()
      \   end
      \ end
    ]]):gsub("{EXTS}", exts_pat)
    vim.cmd(cmd)
  end

  vim.cmd("augroup END")
end

--- set up module for use. can safely be called more than once
---@param opts? table options
function M.setup(opts)
  opts = opts or {}

  tables.overwrite({}, useropts)
  tables.merge(opts, useropts)

  init_autocmds() -- TODO: make autocmds configurable
end

function M.tag_picker(opts)
  local is_ok, telescope = pcall(require, "telescope")
  if is_ok and telescope then
    opts = opts and vim.deepcopy(opts) or {}
    opts.cwd = opts.cwd or vim.fn.getcwd(-1, -1)
    telescope.extensions.microkasten.tags(opts)
  end
end

function M.filename_picker(opts)
  local is_ok, telescope = pcall(require, "telescope")
  if is_ok and telescope then
    opts = opts and vim.deepcopy(opts) or {}
    opts.cwd = opts.cwd or vim.fn.getcwd(-1, -1)
    telescope.extensions.microkasten.filenames(opts)
  end
end

function M.grep_picker(opts)
  local is_ok, telescope = pcall(require, "telescope")
  if is_ok and telescope then
    opts = opts and vim.deepcopy(opts) or {}
    opts.cwd = opts.cwd or vim.fn.getcwd(-1, -1)
    telescope.extensions.microkasten.grep(opts)
  end
end

function M.backlink_picker(opts)
  local is_ok, telescope = pcall(require, "telescope")
  if is_ok and telescope then
    opts = opts and vim.deepcopy(opts) or {}
    opts.cwd = opts.cwd or vim.fn.getcwd(-1, -1)
    telescope.extensions.microkasten.backlinks(opts)
  end
end

---@param dir? string dir to search in or default for cwd
---@param uid string uid of target note
---@param pick_win? boolean false to disable window picker
function M.open_uid(dir, uid, pick_win)
  pick_win = pick_win ~= false
  dir = dir or vim.loop.cwd()
  if not dir then
    return
  end
  local target = filesystem.find_uid_in_dir(dir, uid)
  if not target or #target <= 0 then
    return
  end
  util.open_in_window(target, pick_win)
end

---@param dir? string dir to search in
---@param link notelink link to target note
---@param pick_win? boolean false to disable window picker
function M.open_link(dir, link, pick_win)
  pick_win = pick_win ~= false
  if not link or not link.uid or #link.uid <= 0 then
    return
  end
  M.open_uid(dir, link.uid, pick_win)
end

---@param pos? cursor cursor pos
---@return notelink? link link info if link exists
function M.parse_link_at(pos)
  local link = links.get_link_at(pos)
  if not link then
    return nil
  end
  return links.parse_link(link)
end

---@param pos? cursor cursor pos
---@param pick_win? boolean false to disable window picker
function M.open_link_at(pos, pick_win)
  pick_win = pick_win ~= false
  local link = M.parse_link_at(pos)
  if not link then
    return
  end

  local dir = vim.fn.expand("%:p:h")
  if not dir or #dir <= 0 then
    return
  end

  M.open_link(dir, link, pick_win)
end

---@param filename? string filename or default for current file
---@return noteinfo? note note info
function M.parse_filename(filename)
  filename = filename or vim.fn.expand("%:t")
  if not filename or #filename <= 0 then
    return nil
  end

  return filenames.parse_filename(filename)
end

function M.parse_uid(filename)
  local info = M.parse_filename(filename)
  return info and info.uid or nil
end

function M.parse_title(filename)
  local info = M.parse_filename(filename)
  return info and info.title or nil
end

---@param dir? string folder to put new note in or default for cwd
---@param title? string title of new note or default to prompt user
---@param ext? string file extension for new note or default from config
function M.create(dir, title, ext)
  dir = dir or vim.fn.getcwd(-1, -1)
  dir = dir:gsub("[\\/]+", "")
  title = (title and title:gsub("^%s*", ""):gsub("%s*$", "")) or nil

  vim.ui.input({ prompt = "Note title: ", default = "" }, function(s)
    title = (s and s:gsub("^%s*", ""):gsub("%s*$", "")) or nil
  end)
  if not title then
    return
  end

  if #title <= 0 then
    title = nil
  end

  ext = paths.canonical_ext(ext) or formats.default_ext()
  if #ext <= 0 then
    ext = nil
  end

  local info = { uid = formats.generate_uid(), title = title, ext = ext }
  local basename = filenames.generate_filename(info)
  local filename = dir .. paths.sep() .. basename
  local content = formats.generate_note(info)

  files.makedirs(dir)
  if content and #content > 0 then
    files.write_file(filename, content)
  end

  vim.cmd(
    "silent! edit! " .. vim.fn.escape(filename, " ") .. " | silent! write"
  )
end

---@param filename? string file to rename or default is current file
---@param title? string new title or default to prompt user
function M.rename(filename, title)
  filename = filename or vim.fn.expand("%:p")
  if not filename or #filename <= 0 then
    return
  end

  local cwd = vim.fn.getcwd(-1, -1)
  filename = paths.canonical(filename, cwd)
  if not filename or #filename <= 0 then
    return
  end

  local info = filenames.parse_filename(filename)
  if not title or #title <= 0 then
    vim.ui.input({ prompt = "Rename note: ", default = "" }, function(s)
      title = s
    end)
  end

  title = (title and title:gsub("^%s*", ""):gsub("%s*$", ""):gsub("[\\/]+", ""))
    or nil
  if not title or #title <= 0 or title == info.title then
    return
  end

  info.title = title

  local new_filename = filenames.generate_filename(info)

  vim.fn.mkdir(paths.dirname(new_filename), "p")
  ---@diagnostic disable-next-line: param-type-mismatch
  vim.fn.rename(filename, new_filename)
end

---@return string uid generated uid
function M.generate_uid()
  return formats.generate_uid()
end

return M
