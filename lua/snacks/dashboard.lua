---@class snacks.dashboard
---@overload fun(opts?: snacks.dashboard.Opts): snacks.dashboard.Class
local M = setmetatable({}, {
  __call = function(M, opts)
    return M.open(opts)
  end,
})

local uv = vim.uv or vim.loop

---@alias snacks.dashboard.Format.ctx {width?:number}

---@class snacks.dashboard.Item
---@field indent? number
---@field align? "left" | "center" | "right"
---@field spacing? number
--- The action to run when the section is selected or the key is pressed.
--- * if it's a string starting with `:`, it will be run as a command
--- * if it's a string, it will be executed as a keymap
--- * if it's a function, it will be called
---@field action? fun()|string
---@field enabled? boolean|fun(opts:snacks.dashboard.Opts):boolean if false, the section will be disabled
---@field section? string the name of a section to include. See `Snacks.dashboard.sections`
---@field opts? table options to pass to the section
---@field key? string shortcut key
---@field autokey? boolean automatically assign a numerical key
---@field label? string
---@field desc? string
---@field file? string
---@field footer? string
---@field header? string
---@field icon? string
---@field title? string
---@field text? string|snacks.dashboard.Text[]

---@alias snacks.dashboard.Gen fun(opts:snacks.dashboard.Opts):(snacks.dashboard.Item|snacks.dashboard.Item[])
---@class snacks.dashboard.Section: snacks.dashboard.Item
---@field [number] snacks.dashboard.Section|snacks.dashboard.Gen

---@class snacks.dashboard.Text
---@field [1] string the text
---@field hl? string the highlight group
---@field width? number the width used for alignment
---@field align? "left" | "center" | "right"

---@private
---@class snacks.dashboard.Line
---@field [number] snacks.dashboard.Text
---@field width number

---@private
---@class snacks.dashboard.Block
---@field [number] snacks.dashboard.Line
---@field width number

---@class snacks.dashboard.Config
---@field sections snacks.dashboard.Section
---@field formats table<string, snacks.dashboard.Text|fun(item:snacks.dashboard.Item, ctx:snacks.dashboard.Format.ctx):snacks.dashboard.Text>
local defaults = {
  width = 56,
  -- These settings are only relevant if you don't configure your own sections
  preset = {
    -- Defaults to a picker that supports `fzf-lua`, `telescope.nvim` and `mini.pick`
    ---@type fun(cmd:string, opts:table)|nil
    pick = nil,
    recent_files = true, -- if true, show recent files
  },
  formats = {
    icon = { "%s", width = 2 },
    footer = { "%s", align = "center" },
    header = { "%s", align = "center" },
    file = function(item, ctx)
      local fname = vim.fn.fnamemodify(item.file, ":p:~:.")
      return { ctx.width and #fname > ctx.width and vim.fn.pathshorten(fname) or fname, hl = "file" }
    end,
  },
  -- stylua: ignore
  sections = {
    {
      header = [[
███╗   ██╗███████╗ ██████╗ ██╗   ██╗██╗███╗   ███╗
████╗  ██║██╔════╝██╔═══██╗██║   ██║██║████╗ ████║
██╔██╗ ██║█████╗  ██║   ██║██║   ██║██║██╔████╔██║
██║╚██╗██║██╔══╝  ██║   ██║╚██╗ ██╔╝██║██║╚██╔╝██║
██║ ╚████║███████╗╚██████╔╝ ╚████╔╝ ██║██║ ╚═╝ ██║
╚═╝  ╚═══╝╚══════╝ ╚═════╝   ╚═══╝  ╚═╝╚═╝     ╚═╝
          ]],
    },
    { title = "Keymaps", icon = " " },
    {
      indent = 2,
      -- spacing = 1,
      { icon = " ", key = "f", desc = "Find File", action = ":lua Snacks.dashboard.pick('files')" },
      { icon = " ", key = "n", desc = "New File", action = ":ene | startinsert" },
      { icon = " ", key = "g", desc = "Find Text", action = ":lua Snacks.dashboard.pick('live_grep')" },
      { icon = " ", key = "r", desc = "Recent Files", action = ":lua Snacks.dashboard.pick('oldfiles')" },
      { icon = " ", key = "c", desc = "Config", action = ":lua Snacks.dashboard.pick('files', {cwd = vim.fn.stdpath('config')})" },
      { icon = " ", key = "s", desc = "Restore Session", section = "session" },
      { icon = "󰒲 ", key = "l", desc = "Lazy", action = ":Lazy", enabled = package.loaded.lazy },
      { icon = " ", key = "q", desc = "Quit", action = ":qa" },
    },
    {},
    { title = "Recent Files", icon = " " },
    {
      section = "recent_files",
      opts = { limit = 5, cwd = false },
      indent = 2,
    },
    {},
    { section = "startup" },
  },
}

-- The default style for the dashboard.
-- When opening the dashboard during startup, only the `bo` and `wo` options are used.
-- The other options are used with `:lua Snacks.dashboard()`
Snacks.config.style("dashboard", {
  zindex = 10,
  height = 0.6,
  width = 0.6,
  bo = {
    bufhidden = "wipe",
    buftype = "nofile",
    filetype = "snacks_dashboard",
    swapfile = false,
    undofile = false,
  },
  wo = {
    cursorcolumn = false,
    cursorline = false,
    list = false,
    number = false,
    relativenumber = false,
    sidescrolloff = 0,
    signcolumn = "no",
    spell = false,
    statuscolumn = "",
    statusline = "",
    winbar = "",
    winhighlight = "Normal:SnacksDashboardNormal,NormalFloat:SnacksDashboardNormal",
    wrap = false,
  },
})

M.ns = vim.api.nvim_create_namespace("snacks_dashboard")

---@class snacks.dashboard.Opts: snacks.dashboard.Config
---@field buf? number the buffer to use. If not provided, a new buffer will be created
---@field win? number the window to use. If not provided, a new floating window will be created

---@class snacks.dashboard.Class
---@field opts snacks.dashboard.Opts
---@field buf number
---@field win number
---@field hls table<string, string>
---@field _size? {width:number, height:number}
local D = {}

---@param opts? snacks.dashboard.Opts
---@return snacks.dashboard.Class
function M.open(opts)
  local self = setmetatable({}, { __index = D })
  self.opts = Snacks.config.get("dashboard", defaults, opts) --[[@as snacks.dashboard.Opts]]
  self.buf = self.opts.buf or vim.api.nvim_create_buf(false, true)
  self.win = self.opts.win or Snacks.win({ style = "dashboard", buf = self.buf, enter = true }).win --[[@as number]]
  self.hls = {}
  self:init()
  self:render()
  return self
end

function D:init()
  local links = {
    Desc = "Special",
    File = "Special",
    Footer = "Title",
    Header = "Title",
    Icon = "Special",
    Key = "Number",
    Normal = "Normal",
    Special = "Special",
    Title = "Title",
  }
  for group, link in pairs(links) do
    vim.api.nvim_set_hl(0, "SnacksDashboard" .. group, { link = link, default = true })
    self.hls[group:lower()] = "SnacksDashboard" .. group
  end
  vim.api.nvim_win_set_buf(self.win, self.buf)

  vim.o.ei = "all"
  local style = Snacks.config.styles.dashboard
  for k, v in pairs(style.wo or {}) do
    vim.api.nvim_set_option_value(k, v, { scope = "local", win = self.win })
  end
  for k, v in pairs(style.bo or {}) do
    vim.api.nvim_set_option_value(k, v, { buf = self.buf })
  end
  vim.o.ei = ""
  if self:is_float() then
    vim.keymap.set("n", "<esc>", "<cmd>bd<cr>", { silent = true, buffer = self.buf })
  end
  vim.keymap.set("n", "q", "<cmd>bd<cr>", { silent = true, buffer = self.buf })
  vim.api.nvim_create_autocmd("WinResized", {
    buffer = self.buf,
    callback = function(ev)
      local win = tonumber(ev.match)
      -- only render if the window is the same as the dashboard window
      -- and the size has changed
      if win == self.win and not vim.deep_equal(self._size, self:size()) then
        self:render()
      end
    end,
  })
end

---@return {width:number, height:number}
function D:size()
  return {
    width = vim.api.nvim_win_get_width(self.win),
    height = vim.api.nvim_win_get_height(self.win) + (vim.o.laststatus >= 2 and 1 or 0),
  }
end

function D:is_float()
  return vim.api.nvim_win_get_config(self.win).relative ~= ""
end

---@param action string|fun()
function D:action(action)
  -- close the window before running the action if it's floating
  if self:is_float() then
    vim.api.nvim_win_close(self.win, true)
    self.win = nil
  end
  vim.schedule(function()
    if type(action) == "string" then
      if action:find("^:") then
        return vim.cmd(action:sub(2))
      else
        local keys = vim.api.nvim_replace_termcodes(action, true, true, true)
        return vim.api.nvim_feedkeys(keys, "tm", true)
      end
    end
    action()
  end)
end

---@param item snacks.dashboard.Item
---@param field string
---@param width? number
---@return snacks.dashboard.Text|snacks.dashboard.Text[]
function D:format_field(item, field, width)
  if type(item[field]) == "table" then
    return item[field]
  end
  local format = self.opts.formats[field]
  if format == nil then
    return { item[field], hl = field }
  elseif type(format) == "function" then
    return format(item, { width = width })
  else
    local text = format and setmetatable({ format[1] }, { __index = format }) or { "%s" }
    text.hl = text.hl or field
    text[1] = text[1] == "%s" and item[field] or text[1]:format(item[field])
    return text
  end
end

---@param item snacks.dashboard.Text|snacks.dashboard.Line
---@param width? number
---@param align? "left"|"center"|"right"
function D:align(item, width, align)
  local len = 0
  if type(item[1]) == "string" then ---@cast item snacks.dashboard.Text
    width, align, len = width or item.width, align or item.align, vim.api.nvim_strwidth(item[1])
  else ---@cast item snacks.dashboard.Line
    if #item == 1 then -- only one text, so align that instead
      self:align(item[1], width, align)
      item.width = item[1].width
      return
    end
    len = item.width
  end

  if not width or width <= 0 or width == len then
    return
  end

  align = align or "left"
  local before = align == "center" and math.floor((width - len) / 2) or align == "right" and width - len or 0
  local after = align == "center" and width - len - before or align == "left" and width - len or 0

  if type(item[1]) == "string" then ---@cast item snacks.dashboard.Text
    item[1] = (" "):rep(before) .. item[1] .. (" "):rep(after)
    item.width = width
  else ---@cast item snacks.dashboard.Line
    if before > 0 then
      table.insert(item, 1, { (" "):rep(before) })
    end
    if after > 0 then
      table.insert(item, { (" "):rep(after) })
    end
    item.width = width
  end
end

---@param texts snacks.dashboard.Text[]|snacks.dashboard.Text|string
function D:block(texts)
  texts = type(texts) == "string" and { { texts } } or texts
  texts = type(texts[1]) == "string" and { texts } or texts
  ---@cast texts snacks.dashboard.Text[]
  local ret = { { width = 0 }, width = 0 } ---@type snacks.dashboard.Block
  for _, text in ipairs(texts) do
    -- PERF: only split lines when needed
    local lines = text[1]:find("\n", 1, true) and vim.split(text[1], "\n", { plain = true }) or { text[1] }
    for l, line in ipairs(lines) do
      if l > 1 then
        ret[#ret + 1] = { width = 0 }
      end
      local child = setmetatable({ line }, { __index = text })
      self:align(child)
      ret[#ret].width = ret[#ret].width + vim.api.nvim_strwidth(child[1])
      ret.width = math.max(ret.width, ret[#ret].width)
      table.insert(ret[#ret], child)
    end
  end
  return ret
end

---@param item snacks.dashboard.Item
function D:format(item)
  local width = item.indent or 0

  ---@param fields string[]
  ---@param opts {align?:"left"|"center"|"right", padding?:number, flex?:boolean}
  local function find(fields, opts)
    local flex = opts.flex and math.max(0, self.opts.width - width) or nil
    for _, k in ipairs(fields) do
      if item[k] then
        local block = self:block(self:format_field(item, k, flex))
        block.width = block.width + (opts.padding or 0)
        width = width + block.width
        return block
      end
    end
    return { width = 0 }
  end

  local block = item.text and self:block(item.text)
  local left = block and { width = 0 } or find({ "icon" }, { align = "left", padding = 1 })
  local right = block and { width = 0 } or find({ "label", "key" }, { align = "right", padding = 1 })
  local center = block or find({ "file", "desc", "header", "footer", "title" }, { flex = true })

  local ret = { width = self.opts.width } ---@type snacks.dashboard.Block
  for l = 1, math.max(#left, #center, #right, 1) + (item.spacing or 0) do
    ret[l] = { width = self.opts.width }
    left[l] = left[l] or { width = 0 }
    right[l] = right[l] or { width = 0 }
    center[l] = center[l] or { width = 0 }
    self:align(left[l], left.width, "left")
    if item.indent then
      self:align(left[l], left[l].width + item.indent, "right")
    end
    self:align(right[l], right.width, "right")
    self:align(center[l], self.opts.width - left[l].width - right[l].width, item.align)
    vim.list_extend(ret[l], left[l])
    vim.list_extend(ret[l], center[l])
    vim.list_extend(ret[l], right[l])
  end
  return ret
end

---@param item snacks.dashboard.Item
function D:enabled(item)
  local e = item.enabled
  if type(e) == "function" then
    return e(self.opts)
  end
  return e == nil or e
end

---@param item snacks.dashboard.Section|snacks.dashboard.Gen|snacks.dashboard.Item[]
---@param results? snacks.dashboard.Item[]
---@param parent? snacks.dashboard.Item
function D:resolve(item, results, parent)
  results = results or {}
  if type(item) == "table" then
    setmetatable(item, nil)
  end
  if type(item) == "function" then
    return self:resolve(item(self.opts), results, parent)
  elseif type(item) == "table" and self:enabled(item) then
    if item.section then
      setmetatable(item, { __index = parent })
      local items = M.sections[item.section](item.opts) ---@type snacks.dashboard.Item[]
      self:resolve(items, results, item)
    elseif item[1] then
      setmetatable(item, { __index = parent })
      for _, child in ipairs(item) do
        self:resolve(child, results, item)
      end
    else
      setmetatable(item, { __index = parent })
      table.insert(results, item)
    end
  else
    Snacks.notify.error("Invalid item:\n```lua\n" .. vim.inspect(item) .. "\n```", { title = "Dashboard" })
  end
  return results
end

function D:render()
  self._size = self:size()

  local lines = {} ---@type string[]
  local hls = {} ---@type {row:number, col:number, hl:string, len:number}[]
  local items = {} ---@type table<number, snacks.dashboard.Item>
  local indent = (" "):rep(math.max(math.floor((self._size.width - self.opts.width) / 2), 0))

  local autokeys = 0
  for _, item in ipairs(self:resolve(self.opts.sections)) do
    if item.autokey then
      item.key = tostring(autokeys)
      autokeys = autokeys + 1
    end
    for _, line in ipairs(self:format(item)) do
      lines[#lines + 1] = indent
      items[#lines] = item
      ---@cast line snacks.dashboard.Line
      for _, text in ipairs(line) do
        lines[#lines] = lines[#lines] .. text[1]
        if text.hl then
          local hl = self.hls[text.hl] or text.hl
          table.insert(hls, { row = #lines - 1, col = #lines[#lines] - #text[1], hl = hl, len = #text[1] })
        end
      end
    end
    if item.key then
      vim.keymap.set("n", item.key, function()
        self:action(item.action)
      end, { buffer = self.buf, nowait = not item.autokey, desc = "Dashboard action" })
    end
  end

  -- vertical centering
  local offset = math.max(math.floor((self._size.height - #lines) / 2), 0)
  for _ = 1, offset do
    table.insert(lines, 1, "")
  end

  -- set lines
  vim.bo[self.buf].modifiable = true
  vim.api.nvim_buf_set_lines(self.buf, 0, -1, false, lines)
  vim.bo[self.buf].modifiable = false

  -- highlights
  vim.api.nvim_buf_clear_namespace(self.buf, M.ns, 0, -1)
  for _, hl in ipairs(hls) do
    local row = hl.row + offset
    vim.api.nvim_buf_set_extmark(self.buf, M.ns, row, hl.col, { end_col = hl.col + hl.len, hl_group = hl.hl })
  end

  -- actions on enter
  vim.keymap.set("n", "<cr>", function()
    local section = items[vim.api.nvim_win_get_cursor(self.win)[1] - offset]
    return section and section.action and self:action(section.action)
  end, { buffer = self.buf, nowait = true, desc = "Dashboard action" })

  -- cursor movement
  local last = 0
  vim.api.nvim_create_autocmd("CursorMoved", {
    group = vim.api.nvim_create_augroup("snacks_dashboard_cursor", { clear = true }),
    buffer = self.buf,
    callback = function()
      local row, action = vim.api.nvim_win_get_cursor(self.win)[1], nil
      for l = offset, #lines do
        if items[l - offset] and items[l - offset].action and not lines[l]:match("^%s*$") then
          if action and row < last and l > row then
            break
          end
          action = l
          if row > last and l > row then
            break
          end
        end
      end
      last = action or row
      vim.api.nvim_win_set_cursor(self.win, { last, (lines[last]:find("[%w%d%p]") or 1) - 1 })
    end,
  })
end

--- Check if the dashboard should be opened
function M.setup()
  local buf = 1

  -- don't open the dashboard if there are any arguments
  if vim.fn.argc() > 0 then
    return
  end

  -- there should be only one non-floating window and it should be the first buffer
  local wins = vim.tbl_filter(function(win)
    return vim.api.nvim_win_get_config(win).relative == ""
  end, vim.api.nvim_list_wins())
  if #wins ~= 1 or vim.api.nvim_win_get_buf(wins[1]) ~= buf then
    return
  end

  -- don't open the dashboard if input is piped
  if uv.guess_handle(3) == "pipe" then
    return
  end

  -- don't open the dashboard if there is any text in the buffer
  if vim.api.nvim_buf_line_count(buf) > 1 or #(vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1] or "") > 0 then
    return
  end
  M.open({ buf = buf, win = wins[1] })
end

-- Get an icon
---@param name string
---@param cat? string
---@return snacks.dashboard.Text
function M.icon(name, cat)
  -- stylua: ignore
  local try = {
    function() return require("mini.icons").get(cat or "file", name) end,
    function() return require("nvim-web-devicons").get_icon(name) end,
  }
  for _, fn in ipairs(try) do
    local ok, icon, hl = pcall(fn)
    if ok then
      return { icon, hl = hl, width = 2 }
    end
  end
  return { " ", hl = "icon", width = 2 }
end

-- Used by the default preset to pick something
---@param cmd string
function M.pick(cmd, opts)
  local config = Snacks.config.get("dashboard", defaults, opts)
  -- stylua: ignore
  local try = {
    function() return config.preset.pick(cmd, opts) end,
    function() return require("fzf-lua")[cmd](opts) end,
    function() return require("telescope.builtin")[cmd == "files" and "find_files" or cmd](opts) end,
    function() return require("mini.pick").builtin[cmd](opts) end,
  }
  for _, fn in ipairs(try) do
    if pcall(fn) then
      return
    end
  end
  Snacks.notify.error("No picker found for " .. cmd)
end

-- Checks if the plugin is installed.
-- Only works with [lazy.nvim](https://github.com/folke/lazy.nvim)
---@param name string
function M.have_plugin(name)
  return package.loaded.lazy and require("lazy.core.config").spec.plugins[name] ~= nil
end

M.sections = {}

-- Adds a section to restore the session if any of the supported plugins are installed.
function M.sections.session()
  local plugins = {
    ["persistence.nvim"] = ":lua require('persistence').load()",
    ["persisted.nvim"] = ":SessionLoad",
    ["neovim-session-manager"] = ":SessionManager load_current_dir_session",
    ["possession.nvim"] = ":PossessionLoadCwd",
  }
  for name, action in pairs(plugins) do
    if M.have_plugin(name) then
      return { action = action }
    end
  end
end

--- Get the most recent files
---@param opts? {limit?:number, cwd?:string|boolean}
function M.sections.recent_files(opts)
  opts = opts or {}
  local limit = opts.limit or 5
  local root = opts.cwd and vim.fs.normalize(type(opts.cwd) == "boolean" and vim.fn.getcwd() or opts.cwd)
  local ret = {} ---@type snacks.dashboard.Section
  for _, file in ipairs(vim.v.oldfiles) do
    file = vim.fs.normalize(file, { _fast = true, expand_env = false })
    if file:sub(1, #root) == root and uv.fs_stat(file) then
      ret[#ret + 1] = { file = file, icon = M.icon(file), action = ":e " .. file, autokey = true }
      if #ret >= limit then
        break
      end
    end
  end
  return ret
end

--- Add the startup section
---@return snacks.dashboard.Section?
function M.sections.startup()
  M.lazy_stats = M.lazy_stats and M.lazy_stats.startuptime > 0 and M.lazy_stats or require("lazy.stats").stats()
  local ms = (math.floor(M.lazy_stats.startuptime * 100 + 0.5) / 100)
  return {
    align = "center",
    text = {
      { "⚡ Neovim loaded ", hl = "footer" },
      { M.lazy_stats.loaded .. "/" .. M.lazy_stats.count, hl = "special" },
      { " plugins in ", hl = "footer" },
      { ms .. "ms", hl = "special" },
    },
  }
end

return M
