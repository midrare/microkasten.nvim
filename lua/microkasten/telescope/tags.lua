local M = {}

local arrays = require("microkasten.luamisc.arrays")
local makecmd = require("microkasten.telescope.picker.makecmd")
local entrymaker = require("microkasten.telescope.picker.entrymaker")
local useropts = require("microkasten.useropts")

local tsconfig = require("telescope.config").values
local tsfinders = require("telescope.finders")
local tspickers = require("telescope.pickers")

function M.open(opts)
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

  table.insert(opts.additional_args, "--only-matching")
  table.insert(opts.additional_args, "--no-filename")
  table.insert(opts.additional_args, "--no-line-number")
  table.insert(opts.additional_args, "--no-messages")

  opts.prompt = nil

  local patterns = vim.tbl_flatten({useropts.tags_regex()})
  for _, pat in ipairs(patterns) do
    table.insert(opts.additional_args, "-e")
    table.insert(opts.additional_args, pat)
  end

  table.insert(opts.additional_args, "--only-matching")
  table.insert(opts.additional_args, "--replace")
  table.insert(opts.additional_args, "$1$2$3$4$5$6$7$8$9")

  opts.entry_maker = opts.entry_maker or entrymaker.tag_entry_maker(opts)

  local find_cmd = makecmd.make_grep_cmd(opts)
  local find_job = tsfinders.new_oneshot_job(find_cmd, opts)

  tspickers
    .new(opts, {
      prompt_title = opts.title or "Search tags",
      finder = find_job,
      sorter = tsconfig.generic_sorter(opts),
      attach_mappings = useropts.telescope_mappings,
    })
    :find()
end

return M
