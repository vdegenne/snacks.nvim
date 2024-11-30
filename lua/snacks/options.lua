---@class snacks.options
local M = {}

Snacks.config.style("options", {
  width = 80,
  height = 30,
  bo = {
    filetype = "lua",
    buftype = "",
  },
  minimal = false,
  noautocmd = false,
  zindex = 20,
  wo = { winhighlight = "NormalFloat:Normal" },
  border = "rounded",
  title = " Options ",
  title_pos = "center",
})

Snacks.config.style("options_help", {
  focusable = false,
  enter = false,
  noautocmd = false,
})

Snacks.util.set_hl({
  Key = "DiagnosticVirtualTextInfo",
  Desc = "DiagnosticInfo",
}, { prefix = "SnacksOptions" })

---@alias snacks.options.field "string" | "number" | "boolean"

---@class snacks.options.Field
---@field name string
---@field keymap string
---@field desc? string
---@field empty? any value to represent nil
---@field type? type
---@field input? "select"|"toggle"|"input"|"table"
---@field values? (string|number|boolean|snacks.options.Value)[]

---@class snacks.options.Value
---@field value string|number|boolean
---@field desc? string

---@class snacks.options.Opts
---@field title? string
---@field type? string
---@field module? string
---@field fields? snacks.options.Field[]
---@field cb? fun(options: table<string,any>)

---@class snacks.options.Class
---@field options table<string,any>
---@field opts snacks.options.Opts
---@field win? snacks.win
---@field help_win? snacks.win
---@field updating boolean
---@field lines string[]
---@field valid? boolean
local P = {}

local ns = vim.api.nvim_create_namespace("snacks.options")

---@param options table<string,any>
---@param opts? snacks.options.Opts
function P.new(options, opts)
  local self = setmetatable({}, { __index = P })
  self.options = options
  self.opts = opts or {}
  self.updating = false
  self.lines = {}
  self.valid = true
  self:init()
  return self --[[@as snacks.options.Class]]
end

function P:init()
  ---@type snacks.win.Config
  local opts = { style = "options", keys = {}, title = self.opts.title and "   " .. self.opts.title .. " " or nil }
  for _, field in ipairs(self.opts.fields or {}) do
    opts.keys[field.keymap] = function()
      self:edit(field)
    end
  end
  if self.opts.cb then
    opts.keys["<c-s>"] = function()
      if self:parse() then
        vim.schedule(function()
          -- self.win:close()
          self.opts.cb(self.options)
        end)
      end
    end
  end
  self.win = Snacks.win(opts)
  self:render()
  self:help()
  vim.api.nvim_buf_set_name(self.win.buf, os.tmpname() .. ".lua")
  vim.bo[self.win.buf].filetype = "lua"
  vim.api.nvim_create_autocmd({ "InsertLeave", "TextChanged" }, {
    buffer = self.win.buf,
    callback = function()
      if self.updating then
        return
      end
      if self:parse() then
        self:render()
      end
    end,
  })
  vim.api.nvim_create_autocmd("BufWipeout", {
    buffer = self.win.buf,
    callback = function()
      pcall(function()
        self.help_win:close()
      end)
    end,
  })
end

function P:help()
  local keys = {} ---@type {key:string,desc:string}[]
  if self.opts.cb then
    keys[#keys + 1] = { key = "<C-s>", desc = "Save and close" }
  end
  keys[#keys + 1] = { key = "q", desc = "Close" }
  local width_desc, width_key = 0, 0
  for _, field in ipairs(self.opts.fields or {}) do
    if field.keymap then
      table.insert(keys, { key = field.keymap, desc = field.desc or field.name })
    end
  end
  for _, key in ipairs(keys) do
    key.key = vim.fn.keytrans(vim.keycode(key.key))
    width_desc = math.max(width_desc, vim.api.nvim_strwidth(key.desc))
    width_key = math.max(width_key, vim.api.nvim_strwidth(key.key))
  end
  table.sort(keys, function(a, b)
    return a.key < b.key
  end)
  local size = self.win:size()
  self.help_win = Snacks.win({
    style = "options_help",
    zindex = self.win.opts.zindex + 1,
    relative = "win",
    win = self.win.win,
    col = size.width - 3,
    row = 0,
    width = width_key + width_desc + 4,
    height = #keys,
    anchor = "NE",
  })
  vim.api.nvim_buf_set_lines(self.help_win.buf, 0, -1, false, vim.split(string.rep("\n", #keys), "\n"))
  for i, key in ipairs(keys) do
    local pad_key = string.rep(" ", width_key - vim.api.nvim_strwidth(key.key))
    local pad_desc = string.rep(" ", width_desc - vim.api.nvim_strwidth(key.desc))
    vim.api.nvim_buf_set_extmark(self.help_win.buf, ns, i - 1, 0, {
      virt_text = {
        { (" %s%s "):format(pad_key, key.key), "SnacksOptionsKey" },
        { (" %s%s "):format(key.desc, pad_desc), "SnacksOptionsDesc" },
      },
      virt_text_pos = "overlay",
    })
  end
end

---@param field snacks.options.Field
function P:edit(field)
  if not self:parse() then
    return
  end
  local value = self.options[assert(field.name, "field name required")]
  field = vim.deepcopy(field)
  field.type = field.type or type(value)
  field.empty = field.empty == nil and "" or field.empty
  if not field.input then
    if field.type == "boolean" then
      field.input, field.values = "toggle", { true, false }
    elseif field.values and #field.values > 0 then
      field.input = field.values and (#field.values <= 4 and "toggle" or "select") or "input"
    else
      field.input = "input"
    end
  end
  ---@type fun(self:snacks.options.Class, field: snacks.options.Field, value: any, cb: fun(value: any))
  local getter = self["_" .. field.input]
  assert(getter, "invalid input type: " .. field.input)
  getter(self, field, value, function(v)
    if v == nil then
      return
    end
    if v == field.empty then
      v = nil
    elseif field.type == "number" then
      v = tonumber(v) or nil
    end
    self.options[field.name] = v
    self:render()
  end)
end

---@param field snacks.options.Field
---@return snacks.options.Value[]
function P:values(field)
  return vim.tbl_map(function(it)
    return type(it) == "table" and it or { value = it }
  end, field.values or {})
end

---@param field snacks.options.Field
---@param value any
---@param cb fun(value: any)
function P:_input(field, value, cb)
  vim.ui.input({
    prompt = field.desc or field.name,
    default = value and tostring(value) or nil,
  }, cb)
end

---@param field snacks.options.Field
---@param cb fun(value: any)
function P:_select(field, _, cb)
  assert(field.values, "select input requires values")
  local values = self:values(field)
  vim.ui.select(values, {
    prompt = field.desc or field.name,
    ---@param it snacks.options.Value
    format_item = function(it)
      return tostring(it.value) .. (it.desc and " - " .. it.desc or "")
    end,
  }, function(it)
    if it ~= nil then
      cb(it.value)
    end
  end)
end

---@param field snacks.options.Field
---@param value any
---@param cb fun(value: any)
function P:_toggle(field, value, cb)
  assert(field.values, "toggle input requires values")
  local values = self:values(field)
  local idx = 0
  for i, v in ipairs(values) do
    if v.value == value then
      idx = i
      break
    end
  end
  cb(values[idx % #values + 1].value)
end

---@param field snacks.options.Field
---@param t any
---@param cb fun(value: any)
function P:_table(field, t, cb)
  assert(field.values, "table input requires values")
  t = type(t) == "table" and t or {}
  self:_select(field, _, function(key)
    self:_input(field, t[key] or "", function(v)
      if not v then
        return
      end
      if v == field.empty then
        t[key] = nil
      else
        t[key] = v
      end
      cb(t)
    end)
  end)
end

function P:parse()
  if not self.win:valid() then
    return
  end
  local lines = vim.api.nvim_buf_get_lines(self.win.buf, 0, -1, false)
  local chunk = load(table.concat(lines, "\n"), "options.lua")
  local ok, ret = pcall(chunk)
  self.valid = false
  local err
  if not ok then
    err = "parse error: " .. ret
  end
  if type(ret) ~= "table" then
    err = "invalid return type: " .. type(ret)
  end
  if err then
    Snacks.notify.error(err, {
      id = "snacks_options_error",
      keep = function()
        return not self.valid
      end,
    })
    return
  end
  self.valid = true
  self.options = ret
  return true
end

function P:render()
  self.lines = {}
  if self.opts.module then
    table.insert(self.lines, ("---@module '%s'"):format(self.opts.module))
  end
  if self.opts.type then
    table.insert(self.lines, ("---@type %s"):format(self.opts.type))
  end
  vim.list_extend(self.lines, vim.split("return " .. vim.inspect(self.options), "\n"))
  self.updating = true
  vim.api.nvim_buf_set_lines(self.win.buf, 0, -1, false, self.lines)
  vim.bo[self.win.buf].modified = false
  self.updating = false
end

---@param opts snacks.options.Opts
function M.from(opts)
  assert(opts.module, "module is required")
  assert(opts.type, "type is required")
  local file
  for _, postfix in ipairs({ ".lua", "/init.lua" }) do
    file = vim.api.nvim_get_runtime_file("lua/" .. opts.module:gsub("%.", "/") .. postfix, false)[1]
    if file then
      break
    end
  end
  if not file then
    return Snacks.notify.error("module not found: " .. opts.module)
  end
  local parsed = Snacks.parser.resolve(Snacks.parser.parse({ file = file }))[opts.type]
  if not parsed then
    return Snacks.notify.error("type not found: " .. opts.type)
  end
  opts.fields = opts.fields or {}
  local i = 0
  local used = { g = true }

  for name, field in pairs(parsed.fields or {}) do
    local key = name:sub(1, 1):lower()
    if used[key] then
      key = key:upper()
    end
    if used[key] then
      i = i + 1
      key = tostring(i)
    end
    used[key] = true
    ---@type snacks.options.Field
    local option = {
      name = name,
      keymap = "g" .. key,
      desc = field.desc,
      type = field.type.kind,
    }
    if field.type.kind == "union" then
      option.type = nil
      option.values = {}
      for _, it in ipairs(field.type.types) do
        if it.value ~= nil then
          table.insert(option.values, { value = it.value, desc = it.desc })
        elseif it.kind == "boolean" then
          table.insert(option.values, { value = true, desc = it.desc })
          table.insert(option.values, { value = false, desc = it.desc })
        end
      end
    end
    if field.kind == "number" then
      option.type = "number"
    end
    table.insert(opts.fields, option)
  end
  dd(opts)
  P.new({}, opts)
end

M.from({
  module = "snacks.profiler",
  type = "snacks.profiler.Pick",
})

---@param options? snacks.profiler.Pick
function M.profiler(options)
  options = options or { structure = true, sort = "time", group = "name" }
  ---@type snacks.options.Value[]
  local trace_fields = {
    { value = "name", desc = "fully qualified name of the function" },
    { value = "def", desc = "definition" },
    { value = "ref", desc = "reference (caller)" },
    { value = "require", desc = "require" },
    { value = "autocmd", desc = "autocmd" },
    { value = "modname", desc = "module name of the called function" },
    { value = "def_file", desc = "file of the definition" },
    { value = "def_modname", desc = "module name of the definition" },
    { value = "def_plugin", desc = "pugin that defines the function" },
    { value = "ref_file", desc = "file of the reference" },
    { value = "ref_modname", desc = "module name of the reference" },
    { value = "ref_plugin", desc = "plugin that references the function" },
  }
  return P.new(options, {
    cb = function(opts)
      Snacks.profiler.pick(opts)
    end,
    title = "Profiler Picker Options",
    type = "snacks.profiler.Pick",
    module = "snacks.profiler",
    fields = {
      { name = "structure", keymap = "<localleader>S", desc = "Show structure", type = "boolean" },
      {
        name = "picker",
        keymap = "<localleader>p",
        desc = "Picker",
        type = "string",
        values = { "auto", "fzf-lua", "telescope", "trouble" },
      },
      {
        name = "sort",
        keymap = "<localleader>s",
        desc = "Sort by",
        type = "string",
        values = { "time", "count", "" },
      },
      {
        name = "loc",
        keymap = "<localleader>l",
        desc = "preview location",
        type = "string",
        values = { "def", "ref" },
      },
      {
        name = "filter",
        keymap = "<localleader>f",
        desc = "Filter",
        type = "string",
        input = "table",
        values = trace_fields,
      },
      { name = "group", keymap = "<localleader>g", desc = "Group by", type = "string", values = trace_fields },
      { name = "min_time", keymap = "<localleader>t", desc = "Min time", type = "number" },
    },
  })
end

return M
