local M = {}

local entrymaker = require("microkasten.telescope.picker.entrymaker")
local makecmd = require("microkasten.telescope.picker.makecmd")
local links = require("microkasten.links")
local mappings = require("microkasten.telescope.picker.mappings")
local arrays = require("microkasten.luamisc.arrays")
local tags = require("microkasten.tags")

local tsconfig = require("telescope.config").values
local tsfinders = require("telescope.finders")
local tspickers = require("telescope.pickers")
local tssorters = require("telescope.sorters")


function M.backlinks(opts)
  opts = vim.tbl_deep_extend("force", {}, opts or {})
  opts.cwd = (opts.cwd and vim.fn.expand(opts.cwd)) or vim.loop.cwd()
  if opts.fuzzy == nil then
    opts.fuzzy = false
  end
  if opts.disable_coordinates == nil then
    opts.disable_coordinates = true
  end

  assert(opts.uid, "expected uid to be provided")

  opts.prompt =
    vim.tbl_flatten({ links.generate_incoming_link_regex({ uid = opts.uid }) })
  opts.entry_maker = opts.entry_maker or entrymaker.backlink_entry_maker(opts)

  local find_cmd = makecmd.make_grep_cmd(opts)
  local finder = tsfinders.new_oneshot_job(find_cmd, opts)

  tspickers
    .new(opts, {
      prompt_title = opts.title or "Backlinks",
      finder = finder,
      previewer = tsconfig.grep_previewer(opts),
      sorter = tsconfig.generic_sorter(opts),
      attach_mappings = mappings.telescope_mappings,
    })
    :find()
end

function M.filenames(opts)
  opts = vim.tbl_deep_extend("force", {}, opts or {})
  opts.cwd = (opts.cwd and vim.fn.expand(opts.cwd)) or vim.loop.cwd()

  opts.entry_maker = opts.entry_maker or entrymaker.filename_entry_maker(opts)
  opts.fuzzy = opts.fuzzy or false
  opts.cmd = opts.cmd or makecmd.make_fd_cmd(opts)

  local finder = tsfinders.new_job(
    function(prompt)
      ---@diagnostic disable-next-line: redefined-local
      local opts = vim.tbl_deep_extend("force", {}, opts or {})
      opts.prompt = prompt
      return makecmd.make_fd_cmd(opts)
    end,
    opts.entry_maker or entrymaker.filename_entry_maker(opts),
    opts.max_results,
    opts.cwd
  )

  tspickers
    .new(opts, {
      prompt_title = opts.title or "Files",
      finder = finder,
      previewer = tsconfig.file_previewer(opts),
      sorter = tsconfig.file_sorter(opts),
      attach_mappings = mappings.telescope_mappings,
    })
    :find()
end

function M.tags(opts)
  opts = vim.tbl_deep_extend("force", {}, opts or {})
  opts.additional_args = opts.additional_args or {}

  if not opts.vimgrep_arguments or #opts.vimgrep_arguments <= 0 then
    opts.vimgrep_arguments =
      vim.tbl_deep_extend("force", {}, tsconfig.vimgrep_arguments)
    arrays.remove(opts.vimgrep_arguments, "-H")
    arrays.remove(opts.vimgrep_arguments, "--with-filename")
    arrays.remove(opts.vimgrep_arguments, "-h")
    arrays.remove(opts.vimgrep_arguments, "--no-filename")
    arrays.remove(opts.vimgrep_arguments, "-n")
    arrays.remove(opts.vimgrep_arguments, "--line-number")
    arrays.remove(opts.vimgrep_arguments, "--column")
  end

  -- TODO allow softcoding tags picker pattern

  opts.prompt = nil

  local patterns = vim.tbl_flatten({ tags.generate_tags_regex() })
  for _, pat in ipairs(patterns) do
    table.insert(opts.additional_args, "-e")
    table.insert(opts.additional_args, pat)
  end

  opts.entry_maker = opts.entry_maker or entrymaker.tag_entry_maker(opts)

  local find_cmd = makecmd.make_grep_cmd(opts)
  local find_job = tsfinders.new_oneshot_job(find_cmd, opts)

  tspickers
    .new(opts, {
      prompt_title = opts.title or "Search tags",
      finder = find_job,
      sorter = tsconfig.generic_sorter(opts),
      attach_mappings = mappings.telescope_mappings,
    })
    :find()
end

function M.grep(opts)
  opts = vim.tbl_deep_extend("force", {}, opts or {})
  opts.cwd = opts.cwd and vim.fn.expand(opts.cwd) or vim.loop.cwd()

  local finder = tsfinders.new_job(
    function(prompt)
      ---@diagnostic disable-next-line: redefined-local
      local opts = vim.tbl_deep_extend("force", {}, opts or {})
      opts.prompt = prompt
      if not opts.prompt or #opts.prompt <= 0 then
        return nil
      end
      return makecmd.make_grep_cmd(opts)
    end,
    opts.entry_maker or entrymaker.ripgrep_entry_maker(opts),
    opts.max_results,
    opts.cwd
  )

  tspickers
    .new(opts, {
      prompt_title = opts.title or "grep",
      finder = finder,
      previewer = not opts.disable_previewer and tsconfig.grep_previewer(opts)
        or nil,
      sorter = tssorters.empty(opts),
      attach_mappings = mappings.telescope_mappings,
    })
    :find()
end


return M
