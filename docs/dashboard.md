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
---@field sections snacks.dashboard.Section
---@field formats table<string, snacks.dashboard.Text|fun(item:snacks.dashboard.Item, ctx:snacks.dashboard.Format.ctx):snacks.dashboard.Text>
{
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
---@alias snacks.dashboard.Format.ctx {width?:number}
```

```lua
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
```

```lua
---@alias snacks.dashboard.Gen fun(opts:snacks.dashboard.Opts):(snacks.dashboard.Item|snacks.dashboard.Item[])
---@class snacks.dashboard.Section: snacks.dashboard.Item
---@field [number] snacks.dashboard.Section|snacks.dashboard.Gen
```

```lua
---@class snacks.dashboard.Text
---@field [1] string the text
---@field hl? string the highlight group
---@field width? number the width used for alignment
---@field align? "left" | "center" | "right"
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

### `Snacks.dashboard.file_icon()`

Get an icon

```lua
---@param name string
---@return snacks.dashboard.Text
Snacks.dashboard.file_icon(name)
```

### `Snacks.dashboard.have_plugin()`

Checks if the plugin is installed.
Only works with [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
---@param name string
Snacks.dashboard.have_plugin(name)
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
---@param opts? {limit?:number, cwd?:boolean}
Snacks.dashboard.sections.recent_files(opts)
```

### `Snacks.dashboard.sections.session()`

Adds a section to restore the session if any of the supported plugins are installed.

```lua
Snacks.dashboard.sections.session()
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
