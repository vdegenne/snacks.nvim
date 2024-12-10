---@class snacks.icons
---@field cod snacks.icons.cod
---@field custom snacks.icons.custom
---@field dev snacks.icons.dev
---@field fa snacks.icons.fa
---@field fae snacks.icons.fae
---@field iec snacks.icons.iec
---@field indent snacks.icons.indent
---@field indentation snacks.icons.indentation
---@field linux snacks.icons.linux
---@field md snacks.icons.md
---@field oct snacks.icons.oct
---@field pl snacks.icons.pl
---@field ple snacks.icons.ple
---@field pom snacks.icons.pom
---@field seti snacks.icons.seti
---@field weather snacks.icons.weather
local M = {}

M.meta = {
  desc = "Icon sets",
  hide = true,
}

M.fonts = {
  "cod",
  "custom",
  "dev",
  "fa",
  "fae",
  "iec",
  "indent",
  "indentation",
  "linux",
  "md",
  "oct",
  "pl",
  "ple",
  "pom",
  "seti",
  "weather",
}

setmetatable(M, {
  __index = function(t, k)
    if not vim.tbl_contains(M.fonts, k) then
      return nil
    end
    ---@type table<string, string>
    t[k] = require("snacks.icons." .. k)
    return rawget(t, k)
  end,
})

---@return {font: string, name:string, icon: string}[]
function M.list()
  local items = {} ---@type {font: string, name:string, icon: string}[]
  for _, font in ipairs(M.fonts) do
    ---@type table<string, string>
    local icons = require("snacks.icons.fonts." .. font)
    for name, icon in pairs(icons) do
      items[#items + 1] = { font = font, name = name, icon = icon }
    end
  end
  return items
end

--- Select an icon from all available sets.
--- If no options are provided, the selected icon will be yanked.
---@param opts? { select: fun(icon: {font: string, name:string, icon: string}) }
function M.select(opts)
  local select = opts and opts.select
    or function(selected)
      if selected then
        vim.fn.setreg("+", selected.icon)
      end
    end
  vim.ui.select(M.list(), {
    prompt = "Select icon",
    format_item = function(item)
      return ("%s [%s] %s"):format(item.icon, item.font, item.name)
    end,
  }, select)
end

return M
