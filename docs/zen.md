# 🍿 zen

<!-- docgen -->

## 📦 Setup

```lua
-- lazy.nvim
{
  "folke/snacks.nvim",
  opts = {
    zen = {
      -- your zen configuration comes here
      -- or leave it empty to use the default settings
      -- refer to the configuration section below
    }
  }
}
```

## ⚙️ Config

```lua
---@class snacks.zen.Config
{}
```

## 🎨 Styles

### `zen`

```lua
{
  enter = true,
  fixbuf = false,
  minimal = false,
  width = 120,
  height = 0,
  backdrop = { transparent = true, blend = 20 },
  keys = { q = false },
  wo = {
    winhighlight = "NormalFloat:Normal",
  },
}
```

### `zoom`

```lua
{
  style = "zen",
  backdrop = false,
  width = 0,
}
```

## 📦 Module

### `Snacks.zen.main()`

```lua
Snacks.zen.main()
```

### `Snacks.zen.zen()`

```lua
---@param opts? snacks.win.Config
Snacks.zen.zen(opts)
```

### `Snacks.zen.zoom()`

```lua
---@param opts? snacks.win.Config
Snacks.zen.zoom(opts)
```
