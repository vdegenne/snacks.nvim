# 🍿 dashboard

## 🚀 Usage

The dashboard comes with a set of default sections, that
can be customized with `opts.preset` or
fully replaced with `opts.sections`.

The default preset comes with support for:

- pickers:
  - [fzf-lua](https://github.com/ibhagwan/fzf-lua)
  - [telescope.nvim](https://github.com/nvim-telescope/telescope.nvim)
  - [mini.pick](https://github.com/echasnovski/mini.pick)
- session managers: (only works with [lazy.nvim](https://github.com/folke/lazy.nvim))
  - [persistence.nvim](https://github.com/folke/persistence.nvim)
  - [persisted.nvim](https://github.com/olimorris/persisted.nvim)
  - [neovim-session-manager](https://github.com/Shatur/neovim-session-manager)
  - [posession.nvim](https://github.com/jedrzejboczar/possession.nvim)

### Section actions

A section can have an `action` property that will be executed as:

- a command if it starts with `:`
- a keymap if it's a string not starting with `:`
- a function if it's a function

```lua
-- command
{
  action = ":Telescope find_files",
  key = "f",
},
```

```lua
-- keymap
{
  action = "<leader>ff",
  key = "f",
},
```

```lua
-- function
{
  action = function()
    require("telescope.builtin").find_files()
  end,
  key = "h",
},
```

### Section text

Every section should have a `text` property with an array of `snacks.dashboard.Text` objects.
If the `text` property is not provided, the `snacks.dashboard.Config.formats`
will be used to generate the text.

In the example below, both sections are equivalent.

```lua
{
  text = {
    { "  ", hl = "SnacksDashboardIcon" },
    { "Find File", hl = "SnacksDashboardDesc", width = 50 },
    { "[f]", hl = "SnacksDashboardKey" },
  },
  action = ":Telescope find_files",
  key = "f",
},
```

```lua
{
  action = ":Telescope find_files",
  key = "f",
  desc = "Find File",
  icon = " ",
},
```

<!-- docgen -->

## ⚙️ Config

```lua
---@class snacks.dashboard.Config
---@field sections (snacks.dashboard.Section|fun(opts:snacks.dashboard.Opts):(snacks.dashboard.Section|snacks.dashboard.Section[]|nil))[]
---@field formats table<string, snacks.dashboard.Text|fun(value:string):snacks.dashboard.Text>
{
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
```

## 🎨 Styles

### `dashboard`

The default style for the dashboard.
When opening the dashboard during startup, only the `bo` and `wo` options are used.
The other options are used with `:lua Snacks.dashboard()`

```lua
{
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
}
```

## 📚 Types

```lua
---@class snacks.dashboard.Text
---@field [1] string the text
---@field hl? string the highlight group
---@field align? "left" | "center" | "right"
---@field width? number the width used for alignment
```

```lua
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
```

```lua
---@class snacks.dashboard.Opts: snacks.dashboard.Config
---@field buf? number the buffer to use. If not provided, a new buffer will be created
---@field win? number the window to use. If not provided, a new floating window will be created
```

## 📦 Module

### `Snacks.dashboard()`

```lua
---@type fun(opts?: snacks.dashboard.Opts): snacks.dashboard.Class
Snacks.dashboard()
```

### `Snacks.dashboard.have_pugin()`

Checks if the plugin is installed.
Only works with [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
---@param name string
Snacks.dashboard.have_pugin(name)
```

### `Snacks.dashboard.icon()`

Get an icon

```lua
---@param cat "file" | "filetype" | "extension"
---@param name string
---@param default? string
---@return snacks.dashboard.Text
Snacks.dashboard.icon(cat, name, default)
```

### `Snacks.dashboard.open()`

```lua
---@param opts? snacks.dashboard.Opts
---@return snacks.dashboard.Class
Snacks.dashboard.open(opts)
```

### `Snacks.dashboard.pick()`

Used by the default preset to pick something

```lua
---@param cmd string
Snacks.dashboard.pick(cmd, opts)
```

### `Snacks.dashboard.sections.recent_files()`

Get the most recent files

```lua
---@param opts? {limit?:number}
Snacks.dashboard.sections.recent_files(opts)
```

### `Snacks.dashboard.sections.session()`

Adds a section to restore the session if any of the supported plugins are installed.

```lua
---@param opts snacks.dashboard.Opts
Snacks.dashboard.sections.session(opts)
```

### `Snacks.dashboard.sections.startup()`

Add the startup section

```lua
---@return snacks.dashboard.Section?
Snacks.dashboard.sections.startup()
```

### `Snacks.dashboard.setup()`

Check if the dashboard should be opened

```lua
Snacks.dashboard.setup()
```
