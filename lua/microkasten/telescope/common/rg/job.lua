local M = {}

-- plenary is a depedency of telescope so may as well use it
local Object = require("plenary.class")

local tsmisc = require("telescope._")
local tsentry = require("telescope.make_entry")
local tsfinders = require("telescope.finders")

local base64 = require("microkasten.luamisc.base64")

---@class match
---@field start integer
---@field stop integer
---@field col integer
---@field lnum integer
---@field offset integer
---@field text string
---@field src string

---@class event
---@field filename string
---@field col integer
---@field lnum integer
---@field offset integer
---@field matches match[]


---@param o { text: string?, bytes: string? }
---@return string?
local function decode(o)
  if o.text == nil and o.bytes ~= nil then
    o.text = base64.decode(o.bytes)
  end

  return o.text
end

local pack_varargs = table.pack
  or function(...)
    local a = {}
    for i = 1, select("#", ...) do
      local val = select(i, ...)
      table.insert(a, val)
    end
    return a
  end

---@diagnostic disable-next-line: deprecated, unused-local
local unpack_varargs = table.unpack or unpack

local function set_attrs(tbl, ...)
  local lazy_attrs = pack_varargs(...)
  return setmetatable(tbl, {
    __index = function(o, name)
      local value = rawget(o, name)
      if value ~= nil then
        return value
      end

      for _, attrs in ipairs(lazy_attrs) do
        value = rawget(attrs, name)
        if type(value) == "function" then
          local f = value
          value = f()
        end
        if value ~= nil then
          rawset(o, name, value)
          return value
        end
      end

      return nil
    end,
  })
end

local function split_lines(lines)
  local a = {}
  local _ = lines:gsub("[^\r\n]+", function(s)
    table.insert(a, s)
  end)
  return a
end


local Emitter = Object:extend()

function Emitter:new()
  Emitter.super.new(self)
end

---@diagnostic disable-next-line: unused-local
function Emitter:process(msg)
end

---@return event[]
function Emitter:events()
  return {}
end

---@param msg table<string, any>
---@param submatch table<string, any>
---@return match
function Emitter:_make_match(msg, submatch)
  return set_attrs({
    -- add +1 for lua's weird 1-based arrays
    start = 1 + submatch["start"],
    -- add +1 for lua's 1-based array then -1 for closed-closed ranges
    stop = submatch["end"],
    col = 1 + submatch["start"],
    lnum = msg.data.line_number,
    offset = 1 + msg.data.absolute_offset,
  }, {
    text = function()
      return decode(submatch.match)
    end,
    src = function()
      return decode(msg.data.lines)
    end,
  })
end


local MatchEmitter = Emitter:extend()

function MatchEmitter:new()
  MatchEmitter.super.new(self)
  self._queue = {}
end

---@param msg table<string, any>
function MatchEmitter:process(msg)
  MatchEmitter.super.process(msg)
  if msg.type ~= "match" then
    return
  end

  for _, o in ipairs(msg.data.submatches) do
    local event = {
      filename = decode(msg.data.path),
      col = o["start"],
      lnum = msg.data.line_number,
      offset = msg.data.absolute_offset + o["start"],
      matches = { self:_make_match(msg, o) },
    }

    table.insert(self._queue, event)
  end
end

---@return event[] events
function MatchEmitter:events()
  local events = self._queue
  self._queue = {}
  return events
end


local LineEmitter = Emitter:extend()

function LineEmitter:new()
  LineEmitter.super.new(self)

  self._filename = nil
  self._col = nil
  self._lnum = nil
  self._offset = nil
  self._matches = {}
  self._queue = {}
end

---@param msg table<string, any>
function LineEmitter:process(msg)
  if msg.type == "end"
    or (self._lnum and msg.data.line_number ~= self._lnum)
    or (self._filename and decode(msg.data.path) ~= self._filename) then

    if #self._matches > 0 then
      local event = {
        filename = self._filename,
        col = self._col,
        lnum = self._lnum,
        offset = self._offset,
        matches = self._matches,
      }

      table.insert(self._queue, event)

      self._filename = nil
      self._col = nil
      self._lnum = nil
      self._offset = nil
      self._matches = {}
    end
  end

  if msg.type == "match" then
    self._filename = decode(msg.data.path)
    self._lnum = self._lnum or msg.data.line_number
    self._offset = self._offset or msg.data.absolute_offset

    for _, submatch in ipairs(msg.data.submatches) do
      self._col = self._col or submatch.start
      table.insert(self._matches, self:_make_match(msg, submatch))
    end
  end
end

---@return event[] events
function LineEmitter:events()
  local queue = self._queue
  self._queue = {}
  return queue
end



local FileEmitter = Emitter:extend()

function FileEmitter:new()
  FileEmitter.super.new(self)

  self._filename = nil
  self._col = nil
  self._lnum = nil
  self._offset = nil
  self._matches = {}
  self._queue = {}
end

---@param msg table<string, any>
function FileEmitter:process(msg)
  if msg.type == "end" then
    if #self._matches > 0 then
      table.insert(self._queue, set_attrs({
        filename = self._filename,
        col = self._col,
        lnum = self._lnum,
        offset = self._offset,
        matches = self._matches,
      }, {}))
    end

    self._filename = nil
    self._col = nil
    self._lnum = nil
    self._offset = nil
    self._matches = {}
  end

  if msg.type == "begin" then
    self._filename = decode(msg.data.path)
  end

  if msg.type == "match" then
    self._lnum = self._lnum or msg.data.line_number
    self._offset = self._offset or msg.data.absolute_offset

    for _, submatch in ipairs(msg.data.submatches) do
      self._col = self._col or submatch.start
      table.insert(self._matches, self:_make_match(msg, submatch))
    end
  end
end

---@return event[] events
function FileEmitter:events()
  local queue = self._queue
  self._queue = {}
  return queue
end


M.frequency = {
  file = "file",
  line = "line",
  match = "match",
}

function M.async_job_finder(opts)
  opts = opts and vim.deepcopy(opts) or {}
  opts.batch = opts.batch or M.frequency.line

  local emitter = nil
  if opts.batch == M.frequency.file then
    emitter = FileEmitter()
  elseif opts.batch == M.frequency.line then
    emitter = LineEmitter()
  elseif opts.batch == M.frequency.match then
    emitter = MatchEmitter()
  end

  -- HACK monkey-patch for telescope to emit more than one entry per line
  --    https://github.com/nvim-telescope/telescope.nvim/pull/2230

  local filename = nil
  local entry_maker = opts.entry_maker
  opts.entry_maker = function(line)
    local msg = vim.fn.json_decode(line)
    assert(msg, "expected json message")

    if msg.type == "begin" then
      filename = decode(msg.data.path)
    elseif msg.type == "match" then
      assert(filename, "this should be impossible. (corrupt stdout?)")
      msg.data.path.text = filename
    end

    emitter:process(msg)

    local entries = {}
    for _, ev in ipairs(emitter:events()) do
      local entry = entry_maker(ev)
      if entry then
        table.insert(entries, entry)
      end
    end

    if msg.type == "end" then
      filename = nil
    end
    return entries
  end

  local job = tsfinders.new_async_job(opts)
  local call = getmetatable(job).__call

  getmetatable(job).__call = function(...)
    local args = pack_varargs(...)
    local process_result = args[3]

    args[3] = function(entries)
      local ret = nil
      for _, entry in ipairs(entries) do
        ret = process_result(entry) or ret
      end
      return ret
    end

    return call(unpack_varargs(args))
  end

  return job
end

return M
