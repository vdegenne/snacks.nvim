---@class snacks.dashboard
---@overload fun(opts?: snacks.dashboard.Opts): snacks.dashboard.Class
local M = setmetatable({}, {
  __call = function(M, opts)
    return M.open(opts)
  end,
})

---@class snacks.dashboard.Text
---@field [1] string the text
---@field hl? string the highlight group
---@field align? "left" | "center" | "right"
---@field width? number the width used for alignment

---@class snacks.dashboard.Section
--- The action to run when the section is selected or the key is pressed.
--- * if it's a string starting with `:`, it will be run as a command
--- * if it's a string, it will be executed as a keymap
--- * if it's a function, it will be called
---@field action? fun()|string
---@field enabled? boolean|fun(opts:snacks.dashboard.Opts):boolean if false, the section will be disabled
---@field nl? boolean if true, add an extra newline after the section
---@field key? string shortcut key
---@field text? snacks.dashboard.Text[]|fun():snacks.dashboard.Text[]
--- If text is not provided, these fields will be used to generate the text.
--- See `snacks.dashboard.Config.formats` for the default formats.
---@field desc? string
---@field file? string
---@field file_icon? string
---@field footer? string
---@field header? string
---@field icon? string
---@field title? string

---@class snacks.dashboard.Config
---@field sections (snacks.dashboard.Section|fun(opts:snacks.dashboard.Opts):(snacks.dashboard.Section|snacks.dashboard.Section[]|nil))[]
---@field formats table<string, snacks.dashboard.Text|fun(value:string):snacks.dashboard.Text>
local defaults = {
  -- These settings are only relevant if you don't configure your own sections
  preset = {
    -- Set this to the action to restore the session.
    -- The default tries to use one of `persistence.nvim`, `persisted.nvim`, `neovim-session-manager` or `posession.nvim`
    ---@type string|fun()|nil
    session = nil,
    -- Defaults to a picker that supports `fzf-lua`, `telescope.nvim` and `mini.pick`
    ---@type fun(cmd:string, opts:table)|nil
    pick = nil,
    recent_files = false, -- if true, show recent files
  },
  formats = {
    key = { "[%s]", hl = "SnacksDashboardKey" },
    icon = { "%s", hl = "SnacksDashboardIcon", width = 3 },
    desc = { "%s", hl = "SnacksDashboardDesc", width = 50 },
    header = { "%s", hl = "SnacksDashboardHeader" },
    footer = { "%s", hl = "SnacksDashboardFooter" },
    title = { "%s", hl = "SnacksDashboardTitle", width = 53 },
    file_icon = function(file)
      return Snacks.dashboard.icon("file", file)
    end,
    file = function(file)
      local fname = vim.fn.fnamemodify(file, ":p:~:.")
      return { #fname > 50 and vim.fn.pathshorten(fname) or fname, hl = "SnacksDashboardFile", width = 50 }
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
    { action = ":lua Snacks.dashboard.pick('files')", desc = "Find File", icon = " ", key = "f", nl = true },
    { action = ":ene | startinsert", desc = "New File", icon = " ", key = "n", nl = true },
    { action = ":lua Snacks.dashboard.pick('live_grep')", desc = "Find Text", icon = " ", key = "g", nl = true },
    {
      action = ":lua Snacks.dashboard.pick('files', {cwd = vim.fn.stdpath('config')})",
      desc = "Config",
      icon = " ",
      key = "c",
      nl = true,
    },
    ---@param opts snacks.dashboard.Opts
    function(opts)
      return Snacks.dashboard.sections.session(opts)
    end,
    { action = ":Lazy", desc = "Lazy", icon = "󰒲 ", key = "l", nl = true, enabled = package.loaded.lazy },
    { action = ":qa", desc = "Quit", icon = " ", key = "q", nl = true },
    { action = ":lua Snacks.dashboard.pick('oldfiles')", desc = "Recent Files", icon = " ", key = "r" },
    ---@param opts snacks.dashboard.Opts
    function(opts)
      return opts.preset.recent_files and Snacks.dashboard.sections.recent_files()
    end,
    {},
    function()
      return Snacks.dashboard.sections.startup()
    end,
  },
}

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
  self.win = self.opts.win or Snacks.win({
    style = "dashboard",
    buf = self.buf,
    enter = true,
  }).win --[[@as number]]
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

---@param section snacks.dashboard.Section
function D:text(section)
  if section.text then
    return type(section.text) == "function" and section.text() or section.text --[[@as snacks.dashboard.Text[] ]]
  end
  local ret = {} ---@type snacks.dashboard.Text[]
  for _, k in ipairs({ "icon", "file_icon", "file", "desc", "key", "header", "footer", "title" }) do
    if section[k] then
      local format = self.opts.formats[k]
      if type(format) == "function" then
        ret[#ret + 1] = format(section[k])
      else
        local text = vim.deepcopy(format or { "%s" })
        text[1] = text[1]:format(section[k])
        ret[#ret + 1] = text
      end
    end
  end
  return ret
end

---@param line string
---@param text snacks.dashboard.Text
function D:align(line, text)
  if not text.width then
    return line
  end
  local align, len = text.align or "left", vim.fn.strdisplaywidth(line)
  local padding = math.max(align == "center" and math.floor((text.width - len) / 2) or (text.width - len), 0)
  local rep = string.rep(" ", padding)
  return align == "right" and rep .. line or align == "center" and rep .. line .. rep or line .. rep
end

function D:sections()
  local ret = {} ---@type snacks.dashboard.Section[]
  ---@param section snacks.dashboard.Section
  local function enabled(section)
    local e = section.enabled
    if type(e) == "function" then
      return e(self.opts)
    end
    return e == nil or e
  end
  for _, section in ipairs(self.opts.sections) do
    local sections = type(section) == "function" and (section(self.opts) or {}) or { section }
    ---@cast sections snacks.dashboard.Section[]|snacks.dashboard.Section
    sections = vim.tbl_isempty(sections) and {} or sections[1] and sections or { sections }
    ---@cast sections snacks.dashboard.Section[]
    for _, s in ipairs(sections) do
      if enabled(s) then
        table.insert(ret, s)
      end
    end
  end
  return ret
end

function D:render()
  local lines = {} ---@type string[]
  local hls = {} ---@type {row:number, col:number, hl:string, len:number}[]
  local first_action, last_action = nil, nil ---@type number?, number?
  local sections = {} ---@type table<number, snacks.dashboard.Section>

  for _, section in ipairs(self:sections()) do
    local row = #lines + 1
    lines[row] = ""
    for _, text in ipairs(self:text(section)) do
      for l, line in ipairs(vim.split(text[1] or "", "\n", { plain = true })) do
        row = l > 1 and row + 1 or row --[[@as number]]
        line = self:align(line, text)
        lines[row] = (lines[row] or "") .. line
        if text.hl then
          table.insert(hls, { row = row - 1, col = #lines[row] - #line, hl = text.hl, len = #line })
        end
        sections[row] = section
        if section.action then
          first_action, last_action = first_action or row, row
        end
      end
    end
    if section.nl then
      lines[row + 1] = ""
    end
    if section.key then
      vim.keymap.set("n", section.key, function()
        self:action(section.action)
      end, { buffer = self.buf, nowait = true, desc = "Dashboard action" })
    end
  end

  self._size = self:size()

  -- center horizontally
  local offsets_col = {} ---@type number[]
  for i, line in ipairs(lines) do
    local len = vim.fn.strdisplaywidth(line)
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
    local section = sections[vim.api.nvim_win_get_cursor(self.win)[1] - offset_row]
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
        local section = sections[i - offset_row]
        if section and section.action then
          action = i
          break
        end
      end
      vim.api.nvim_win_set_cursor(self.win, { action, (lines[action]:find("%w") or 1) - 1 })
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
      return { icon, hl = hl, width = 3 }
    end
  end
  return { default or " ", hl = "SnacksDashboardIcon", width = 3 }
end

function M.pick(cmd, opts)
  local config = Snacks.config.get("dashboard", defaults, opts)
  local try = {
    function()
      return config.preset.pick(cmd, opts)
    end,
    function()
      return require("fzf-lua")[cmd](opts)
    end,
    function()
      cmd = cmd == "files" and "find_files" or cmd
      return require("telescope.builtin")[cmd](opts)
    end,
    function()
      return require("mini.pick").builtin[cmd](opts)
    end,
  }
  for _, fn in ipairs(try) do
    if pcall(fn) then
      return
    end
  end
  Snacks.notify.error("No picker found for " .. cmd)
end

function M.have_pugin(name)
  return package.loaded.lazy and require("lazy.core.config").spec.plugins[name] ~= nil
end

M.sections = {}

---@param opts snacks.dashboard.Opts
function M.sections.session(opts)
  local load = opts.preset.session
  if load == nil then
    local plugins = {
      ["persistence.nvim"] = ":lua require('persistence').load()",
      ["persisted.nvim"] = ":SessionLoad",
      ["neovim-session-manager"] = ":SessionManager load_current_dir_session",
      ["possession.nvim"] = ":PossessionLoadCwd",
    }
    for name, action in pairs(plugins) do
      if M.have_pugin(name) then
        load = action
        break
      end
    end
  end
  return load
    and {
      action = load,
      desc = "Restore Session",
      icon = " ",
      key = "s",
      nl = true,
    }
end

--- Get the most recent files
---@param opts? {limit?:number}
function M.sections.recent_files(opts)
  local limit = opts and opts.limit or 5
  local ret = {} ---@type snacks.dashboard.Section[]
  for _, file in ipairs(vim.v.oldfiles) do
    if vim.fn.filereadable(file) == 1 then
      ret[#ret + 1] = {
        file_icon = file,
        file = vim.fn.fnamemodify(file, ":p:~:."),
        action = function()
          vim.cmd("e " .. file)
        end,
        key = tostring(#ret),
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
    text = {
      { "⚡ Neovim loaded ", hl = "SnacksDashboardFooter" },
      { M.lazy_stats.loaded .. "/" .. M.lazy_stats.count, hl = "SnacksDashboardSpecial" },
      { " plugins in ", hl = "SnacksDashboardFooter" },
      { ms .. "ms", hl = "SnacksDashboardSpecial" },
    },
  }
end

return M
