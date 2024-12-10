local M = {}

function M.fetch()
  if vim.fn.filereadable("glyphnames.json") == 1 then
    return
  end
  local url = "https://github.com/ryanoasis/nerd-fonts/raw/refs/heads/master/glyphnames.json"
  local ret = vim.system({ "curl", "-L", "-o", "glyphnames.json", url }):wait()
  if ret.code ~= 0 then
    error("Failed to fetch icons: " .. ret.stderr)
  end
end

function M.build()
  M.fetch()
  local lines = vim.fn.readfile("glyphnames.json")
  ---@type table<string, {char:string, code:string}>
  local data = vim.json.decode(table.concat(lines, "\n"))
  local icons = {} ---@type table<string, table<string,string>>
  for name, info in pairs(data) do
    if name ~= "METADATA" then
      local font, icon = name:match("^([%w_]+)%-(.*)$")
      if not font then
        error("Invalid icon name: " .. name)
      end
      icons[font] = icons[font] or {}
      icons[font][icon] = info.char .. " "
    end
  end
  for font, font_icons in pairs(icons) do
    local file = "lua/snacks/icons/fonts/" .. font .. ".lua"
    print("Writing " .. file)
    local set_lines = {
      "---@class snacks.icons." .. font,
    }
    vim.list_extend(set_lines, vim.split(vim.inspect(font_icons), "\n"))
    set_lines[2] = "local M = " .. set_lines[2]
    table.insert(set_lines, "return M")
    vim.fn.writefile(set_lines, file)
  end
end

return M
