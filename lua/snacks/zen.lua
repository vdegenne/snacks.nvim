---@class snacks.zen
local M = {}

---@class snacks.zen.Config
local defaults = {}

Snacks.config.style("zen", {
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
})

Snacks.config.style("zoom", {
  style = "zen",
  backdrop = false,
  width = 0,
})

---@param opts? snacks.win.Config
function M.zen(opts)
  -- close if already open
  if vim.w[vim.api.nvim_get_current_win()].snacks_zen then
    vim.cmd("close")
    return
  end

  local parent_win = vim.api.nvim_get_current_win()
  local buf = vim.api.nvim_get_current_buf()
  local win = Snacks.win(Snacks.win.resolve({ style = "zen" }, opts, { buf = buf }))

  vim.w[win.win].snacks_zen = true

  -- update the buffer of the parent window
  -- when the zen buffer changes
  vim.api.nvim_create_autocmd("BufWinEnter", {
    group = win.augroup,
    callback = function()
      vim.api.nvim_win_set_buf(parent_win, win.buf)
    end,
  })

  -- close when entering another window
  vim.api.nvim_create_autocmd("WinEnter", {
    group = win.augroup,
    callback = function()
      local w = vim.api.nvim_get_current_win()
      if w == win.win then
        return
      end
      -- exit if other window is not a floating window
      if vim.api.nvim_win_get_config(w).relative == "" then
        win:close()
      end
    end,
  })
  return win
end

---@param opts? snacks.win.Config
function M.zoom(opts)
  opts = Snacks.win.resolve({
    style = "zoom",
    col = M.main().col,
    height = function()
      return M.main().height
    end,
  }, opts)
  return M.zen(opts)
end

function M.main()
  local bottom = vim.o.cmdheight + (vim.o.laststatus == 3 and 1 or 0)
  local top = (vim.o.showtabline == 2 or (vim.o.showtabline == 1 and #vim.api.nvim_list_tabpages() > 1)) and 1 or 0
  ---@class snacks.zen.Main values are 0-indexed
  local ret = {
    col = 0,
    width = vim.o.columns,
    row = top,
    height = vim.o.lines - top - bottom,
  }
  return ret
end

return M
