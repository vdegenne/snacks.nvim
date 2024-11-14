# 🍿 dashboard

<!-- docgen -->

## ⚙️ Config

```lua
---@class snacks.dashboard.Config
---@field sections (snacks.dashboard.Section|fun():snacks.dashboard.Section[])[]
---@field formats table<string, snacks.dashboard.Text|fun(value:string):snacks.dashboard.Text>
---@field wo vim.wo window options
---@field bo vim.bo buffer options
{
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
           ██╗      █████╗ ███████╗██╗   ██╗██╗   ██╗██╗███╗   ███╗          Z
           ██║     ██╔══██╗╚══███╔╝╚██╗ ██╔╝██║   ██║██║████╗ ████║      Z    
           ██║     ███████║  ███╔╝  ╚████╔╝ ██║   ██║██║██╔████╔██║   z       
           ██║     ██╔══██║ ███╔╝    ╚██╔╝  ╚██╗ ██╔╝██║██║╚██╔╝██║ z         
           ███████╗██║  ██║███████╗   ██║    ╚████╔╝ ██║██║ ╚═╝ ██║           
           ╚══════╝╚═╝  ╚═╝╚══════╝   ╚═╝     ╚═══╝  ╚═╝╚═╝     ╚═╝           
          ]],
    },
    -- {
    --   text = {
    --     { " ", hl = "SnacksDashboardIcon" },
    --     { " Find File", hl = "SnacksDashboardDesc", width = 50 },
    --     { "[f]", hl = "SnacksDashboardKey" },
    --   },
    --   action = "lua LazyVim.pick()()",
    --   key = "f",
    -- },
    { action = "<leader>ff", desc = "Find File", icon = " ", key = "f" },
    {},
    { action = ":ene | startinsert", desc = "New File", icon = " ", key = "n" },
    {},
    { action = "<leader>sg", desc = "Find Text", icon = " ", key = "g" },
    {},
    { action = "<leader>fc", desc = "Config", icon = " ", key = "c" },
    {},
    { action = "<leader>qs", desc = "Restore Session", icon = " ", key = "s" },
    {},
    { action = ":LazyExtras", desc = "Lazy Extras", icon = " ", key = "x" },
    {},
    { action = ":Lazy", desc = "Lazy", icon = "󰒲 ", key = "l" },
    {},
    { action = ":qa", desc = "Quit", icon = " ", key = "q" },
    {},
    { action = "<leader>fr", desc = "Recent Files", icon = " ", key = "r" },
    -- function()
    --   return Snacks.dashboard.sections.recent_files()
    -- end,
    {},
    function()
      return Snacks.dashboard.sections.startup()
    end,
  },
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

### `Snacks.dashboard.icon()`

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

### `Snacks.dashboard.sections.recent_files()`

Get the most recent files

```lua
---@param opts? {limit?:number}
Snacks.dashboard.sections.recent_files(opts)
```

### `Snacks.dashboard.sections.startup()`

Add the startup section

```lua
---@return snacks.dashboard.Section[]
Snacks.dashboard.sections.startup()
```

### `Snacks.dashboard.setup()`

Check if the dashboard should be opened

```lua
Snacks.dashboard.setup()
```
