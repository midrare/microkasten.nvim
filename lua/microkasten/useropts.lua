local M = {}

--- invoked whenever a note-containing buffer is opened. if this is an array,
--- each element is invoked in the order in which it appears
---@type (fun()|fun()[])?
M.on_attach = nil

--- if a file with this name exists in the current or a parent folder then
--- the current buffer is considered a note file
---@type nil|boolean|string
M.marker = ".microkasten"

--- file extensions supported. used for filetype detection. should be
--- lowercase and including leading "."
---@type string[]?
M.exts = {}

--- file extension to use when creating new notes when a file extension is not
--- explicitly specified
---@type string?
M.default_ext = nil

--- parse a string into a link
---@type (fun(link: string): notelink)?
M.parse_link = nil

--- extract from a line of text, a link at the given char index. returned
--- string should include all link markup. return nil if there is no link
--- at the given pos
---@type (fun(line: string, pos: integer): string?)?
M.get_link_from_line = nil

--- takes a new note's metadata for and generates the initial note text. if
--- a table is provided, the keys are lowercase file extensions including the
--- leading "." and values are the text-generating functions. this
--- functionality is provided as a more flexible substitute for note templates
---@type (fun(note: noteinfo)|table<string, fun(note: noteinfo): string>)?
M.generate_note = nil

--- takes a note's filename and parses out metadata from it. if
--- you follow a file naming convention `generate_filename()` also needs to be
--- adjusted appropriately.
---@type (fun(filename: string): noteinfo)?
M.parse_filename = nil

--- takes a note's metadata and generates an appropriate filename for it. if
--- you follow a file naming convention `parse_filename()` also needs to be
--- adjusted appropriately.
---@type (fun(note: noteinfo): string)?
M.generate_filename = nil

--- apply syntax highlighting to the current buffer. typically this would
--- consist of vim.cmd[[syntax ...]] commands
---@type fun()?
M.apply_syntax = nil

--- returns a set of regex patterns that matches tags of all forms
---@type (fun(): string|string[])?
M.generate_tags_regex = nil

return M
