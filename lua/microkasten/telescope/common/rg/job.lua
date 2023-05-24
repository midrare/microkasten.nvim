local M = {}

-- plenary is a depedency of telescope so may as well use it
local Object = require("plenary.class")

local tsmisc = require("telescope._")
local tsentry = require("telescope.make_entry")

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
      table.insert(a, select(i, ...))
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
  local entry_maker = opts.entry_maker or tsentry.gen_from_string(opts)
  opts = opts and vim.deepcopy(opts) or {}
  opts.batch = opts.batch or M.frequency.line

  local fn_command = function(prompt)
    local command_list = opts.command_generator(prompt)
    if command_list == nil then
      return nil
    end

    local command = table.remove(command_list, 1)

    local res = {
      command = command,
      args = command_list,
    }

    return res
  end

  local job = nil

  local callable = function(_, prompt, process_result, process_complete)
    if job then
      job:close(true)
    end

    local job_opts = fn_command(prompt)
    if not job_opts then
      return
    end

    local writer = nil
    -- if job_opts.writer and Job.is_job(job_opts.writer) then
    --   writer = job_opts.writer
    if opts.writer then
      error("async_job_finder.writer is not yet implemented")
      writer = tsmisc.writer(opts.writer)
    end

    local stdout = tsmisc.LinesPipe()

    job = tsmisc.spawn({
      command = job_opts.command,
      args = job_opts.args,
      cwd = job_opts.cwd or opts.cwd,
      env = job_opts.env or opts.env,
      writer = writer,

      stdout = stdout,
    })

    local emitter = nil
    if opts.batch == M.frequency.file then
      emitter = FileEmitter()
    elseif opts.batch == M.frequency.line then
      emitter = LineEmitter()
    elseif opts.batch == M.frequency.match then
      emitter = MatchEmitter()
    end

    assert(emitter, "need emitter set up")
    local filename = nil
    for line in stdout:iter(true) do
      local msg = vim.fn.json_decode(line)
      assert(msg, "expected json message")

      if msg.type == "begin" then
        filename = decode(msg.data.path)
      elseif msg.type == "match" then
        assert(filename, "this should be impossible. (corrupt stdout?)")
        msg.data.path.text = filename
      end

      emitter:process(msg)

      for _, ev in ipairs(emitter:events()) do
        if process_result(entry_maker(ev)) then
          return
        end
      end

      if msg.type == "end" then
        filename = nil
      end
    end

    process_complete()
  end

  return setmetatable({
    close = function()
      if job then
        job:close(true)
      end
    end,
  }, {
    __call = callable,
  })
end

return M
