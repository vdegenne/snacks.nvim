---@class snacks.dashboard
---@overload fun(opts?: snacks.dashboard.Opts): snacks.dashboard.Class
local M = setmetatable({}, {
  __call = function(M, opts)
    return M.open(opts)
  end,
})

---@alias sncaks.dashboard.Format.ctx {width?:number}

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

---@class snacks.dashboard.Config
---@field sections snacks.dashboard.Section
---@field formats table<string, snacks.dashboard.Text|fun(item:snacks.dashboard.Item, ctx:sncaks.dashboard.Format.ctx):snacks.dashboard.Text>
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
    file = function(item, ctx)
      local fname = vim.fn.fnamemodify(item.file, ":p:~:.")
      return { ctx.width and #fname > ctx.width and vim.fn.pathshorten(fname) or fname, hl = "file" }
    end,
  },
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
      {
        icon = " ",
        key = "c",
        desc = "Config",
        action = ":lua Snacks.dashboard.pick('files', {cwd = vim.fn.stdpath('config')})",
      },
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
---@field _size? {width:number, height:number}
local D = {}

---@param opts? snacks.dashboard.Opts
---@return snacks.dashboard.Class
function M.open(opts)
  local self = setmetatable({}, { __index = D })
  self.opts = Snacks.config.get("dashboard", defaults, opts) --[[@as snacks.dashboard.Opts]]
  self.buf = self.opts.buf or vim.api.nvim_create_buf(false, true)
  self.win = self.opts.win or Snacks.win({ style = "dashboard", buf = self.buf, enter = true }).win --[[@as number]]
  self:init()
  self:render()
  return self
end

function D:init()
  local links = {
    Normal = "Normal",
    Title = "Title",
    Icon = "Special",
    Key = "Number",
    Desc = "Special",
    File = "Special",
    Header = "Title",
    Footer = "Title",
  }
  for group, link in pairs(links) do
    vim.api.nvim_set_hl(0, "SnacksDashboard" .. group, { link = link, default = true })
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

---@param hl? string
function D:hl(hl)
  return hl and hl:find("^[a-z]") and ("SnacksDashboard" .. hl:sub(1, 1):upper() .. hl:sub(2)) or hl
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
        vim.cmd(action:sub(2))
      else
        local keys = vim.api.nvim_replace_termcodes(action, true, true, true)
        vim.api.nvim_feedkeys(keys, "tm", true)
      end
    else
      action()
    end
  end)
end

---@param item snacks.dashboard.Item
---@param field string
---@param width? number
---@return snacks.dashboard.Text
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
    local text = vim.deepcopy(format or { "%s" })
    text.hl = text.hl or field
    text[1] = text[1]:format(item[field])
    return text
  end
end

---@param item snacks.dashboard.Item
---@return snacks.dashboard.Text[]
function D:format(item)
  if item.text then
    return type(item.text) == "string" and { { item.text } } or item.text
  end

  local ret = {} ---@type snacks.dashboard.Text[]
  local width = item.indent or 0

  ---@param fields string[]
  ---@param opts {align?:"left"|"center"|"right", padding?:number, flex?:boolean}
  local function find(fields, opts)
    local flex = opts.flex and math.max(0, self.opts.width - width) or nil
    for _, k in ipairs(fields) do
      if item[k] then
        local text = self:format_field(item, k, flex)
        local tw = (text.width or flex or vim.api.nvim_strwidth(text[1] or "")) + (opts.padding or 0)
        text[1] = self:align(text[1], { width = tw, align = opts.align or text.align or item.align })
        width = width + tw
        return { text }
      end
    end
  end

  vim.list_extend(ret, find({ "icon" }, { align = "left", padding = 1 }) or {})
  local right = find({ "label", "key" }, { align = "right", padding = 1 })
  vim.list_extend(ret, find({ "file", "desc", "header", "footer", "title" }, { flex = true }) or {})
  vim.list_extend(ret, right or {})
  return ret
end

---@param str string
---@param opts {width:number, align?:"left"|"center"|"right"}
function D:align(str, opts)
  local align, len = opts.align or "left", vim.fn.strdisplaywidth(str)
  if align == "left" then
    return str .. (" "):rep(opts.width - len)
  elseif align == "right" then
    return (" "):rep(opts.width - len) .. str
  end
  local before = math.floor((opts.width - len) / 2)
  return (" "):rep(before) .. str .. (" "):rep(opts.width - len - before)
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
      local items = M.sections[item.section](item.opts)
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
  end
  return results
end

function D:render()
  local lines = {} ---@type string[]
  local hls = {} ---@type {row:number, col:number, hl:string, len:number}[]
  local first_action, last_action = nil, nil ---@type number?, number?
  local items = {} ---@type table<number, snacks.dashboard.Item>

  for _, item in ipairs(self:resolve(self.opts.sections)) do
    local row = math.max(#lines, 1)
    lines[row] = ""
    for t, text in ipairs(self:format(item)) do
      for l, line in ipairs(vim.split(text[1] or "", "\n", { plain = true })) do
        row = l > 1 and row + 1 or row --[[@as number]]
        if (l > 1 or t == 1) and item.indent then
          lines[row] = (lines[row] or "") .. (" "):rep(item.indent)
        end
        lines[row] = (lines[row] or "") .. line
        if text.hl then
          table.insert(hls, { row = row - 1, col = #lines[row] - #line, hl = self:hl(text.hl), len = #line })
        end
        items[row] = item
        if item.action then
          first_action, last_action = first_action or row, row
        end
      end
    end
    for _ = 1, 1 + (item.spacing or 0) do
      row = row + 1
      lines[row] = ""
    end
    if item.key then
      vim.keymap.set("n", item.key, function()
        self:action(item.action)
      end, { buffer = self.buf, nowait = true, desc = "Dashboard action" })
    end
  end

  self._size = self:size()

  -- center horizontally
  local offsets_col = {} ---@type number[]
  for i, line in ipairs(lines) do
    local len = vim.api.nvim_strwidth(line)
    local before = math.max(math.floor((self._size.width - len) / 2), 0)
    offsets_col[i] = before
    lines[i] = (" "):rep(before) .. line
  end

  -- center vertically
  local offset_row = math.max(math.floor((self._size.height - #lines) / 2), 0)
  for _ = 1, offset_row do
    table.insert(lines, 1, "")
  end

  -- set lines
  vim.bo[self.buf].modifiable = true
  vim.api.nvim_buf_set_lines(self.buf, 0, -1, false, lines)
  vim.bo[self.buf].modifiable = false

  -- highlights
  vim.api.nvim_buf_clear_namespace(self.buf, M.ns, 0, -1)
  for _, hl in ipairs(hls) do
    local col = hl.col + offsets_col[hl.row + 1]
    local row = hl.row + offset_row
    vim.api.nvim_buf_set_extmark(self.buf, M.ns, row, col, { end_col = col + hl.len, hl_group = hl.hl })
  end

  -- actions on enter
  vim.keymap.set("n", "<cr>", function()
    local section = items[vim.api.nvim_win_get_cursor(self.win)[1] - offset_row]
    return section and section.action and self:action(section.action)
  end, { buffer = self.buf, nowait = true, desc = "Dashboard action" })

  -- cursor movement
  local last = first_action
  vim.api.nvim_create_autocmd("CursorMoved", {
    group = vim.api.nvim_create_augroup("snacks_dashboard_cursor", { clear = true }),
    buffer = self.buf,
    callback = function()
      local row = vim.api.nvim_win_get_cursor(self.win)[1]
      local action = (row > last and last_action or first_action) + offset_row
      for i = row, row > last and vim.o.lines or 1, row > last and 1 or -1 do
        local section = items[i - offset_row]
        if section and section.action then
          action = i
          break
        end
      end
      vim.api.nvim_win_set_cursor(self.win, { action, (lines[action]:find("[%w%d%p]") or 1) - 1 })
      last = action
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
  if vim.uv.guess_handle(3) == "pipe" then
    return
  end

  -- don't open the dashboard if there is any text in the buffer
  if vim.api.nvim_buf_line_count(buf) > 1 or #(vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1] or "") > 0 then
    return
  end
  M.open({ buf = buf, win = wins[1] })
end

-- Get an icon
---@param cat "file" | "filetype" | "extension"
---@param name string
---@param default? string
---@return snacks.dashboard.Text
function M.icon(cat, name, default)
  local try = {
    function()
      return require("mini.icons").get(cat, name)
    end,
    function()
      if cat == "filetype" then
        return require("nvim-web-devicons").get_icon_by_filetype(name)
      elseif cat == "file" then
        return require("nvim-web-devicons").get_icon(name)
      elseif cat == "extension" then
        return require("nvim-web-devicons").get_icon(nil, name)
      end
    end,
  }
  for _, fn in ipairs(try) do
    local ok, icon, hl = pcall(fn)
    if ok then
      return { icon, hl = hl, width = 2 }
    end
  end
  return { default or " ", hl = "icon", width = 2 }
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
function M.have_pugin(name)
  return package.loaded.lazy and require("lazy.core.config").spec.plugins[name] ~= nil
end

M.sections = {}

-- Adds a section to restore the session if any of the supported plugins are installed.
function M.sections.session()
  local config = Snacks.config.get("dashboard", defaults)
  if config.preset.session then
    return { action = config.preset.session }
  end
  local plugins = {
    ["persistence.nvim"] = ":lua require('persistence').load()",
    ["persisted.nvim"] = ":SessionLoad",
    ["neovim-session-manager"] = ":SessionManager load_current_dir_session",
    ["possession.nvim"] = ":PossessionLoadCwd",
  }
  for name, action in pairs(plugins) do
    if M.have_pugin(name) then
      return { action = action }
    end
  end
end

--- Get the most recent files
---@param opts? {limit?:number, cwd?:boolean}
function M.sections.recent_files(opts)
  local limit = opts and opts.limit or 5
  local root = opts and opts.cwd and vim.fs.normalize(vim.fn.getcwd()) or ""
  local ret = {} ---@type snacks.dashboard.Section
  for _, file in ipairs(vim.v.oldfiles) do
    file = vim.fs.normalize(file)
    if vim.fn.filereadable(file) == 1 and file:find(root) == 1 then
      ret[#ret + 1] = {
        file = file,
        icon = M.icon("file", file),
        action = function()
          vim.cmd("e " .. file)
        end,
        key = tostring(#ret + 1),
      }
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
  if not package.loaded.lazy then
    return
  end
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
