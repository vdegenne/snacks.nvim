---@class snacks.parser
local M = {}

---@class snacks.parser.Type
---@field kind string
---@field value? string
---@field types? snacks.parser.Type[]

---@class snacks.parser.Field
---@field kind "field"
---@field name string
---@field desc? string
---@field optional? boolean
---@field type snacks.parser.Type

---@class snacks.parser.Alias
---@field kind "alias"
---@field name string
---@field desc? string
---@field type snacks.parser.Type

---@class snacks.parser.Class
---@field kind "class"
---@field name string
---@field parent? string
---@field desc? string
---@field fields? table<string, snacks.parser.Field>

---@param opts {file?: string, code?: string}
function M.parse(opts)
  assert(opts.file or opts.code, "file or code is required")
  assert(not (opts.file and opts.code), "only one of file or code is allowed")

  -- FIXME: remove this when lpeg is fixed
  package.loaded["snacks.parser.grammar"] = nil
  local grammar = require("snacks.parser.grammar")

  local ret = {} ---@type table<string,snacks.parser.Alias|snacks.parser.Class>
  local lines = opts.file and vim.fn.readfile(opts.file) or vim.split(opts.code, "\n", { plain = true })

  local last ---@type snacks.parser.Alias|snacks.parser.Class

  for _, line in ipairs(lines) do
    local doc = line:match("^%s*%-%-%-%s*(.*)")
    if doc then
      doc = doc:gsub("^|", "@|")
      local a = grammar:match(doc)
      if not a then
      elseif a.kind == "field" then
        if last and last.kind == "class" then
          last.fields = last.fields or {}
          last.fields[a.name] = a
        end
      elseif a.kind == "alias" or a.kind == "class" then
        ret[a.name] = a
        last = a
      elseif a.kind == "|" then
        if last and last.kind == "alias" then
          if not (last.type and last.type.types) then
            last.type = last.type or {}
            if last.type.value then
              last.desc = last.type.value .. (last.desc and " " .. last.desc or "")
            end
            last.type = { kind = "union", types = {} }
          end
          a.type.desc = a.desc
          table.insert(last.type.types, a.type)
        end
      end
    end
  end
  return ret
end

function M.resolve(types)
  local function _resolve(node)
    if type(node) == "table" then
      if node.kind == "class" and node.parent then
        local parent = types[node.parent]
        if parent then
          node.desc = node.desc or parent.desc
          node.fields = vim.tbl_extend("force", {}, parent.fields, node.fields)
        end
      end
      for k, child in pairs(node) do
        if type(child) == "table" and child.kind == "identifier" then
          local other = types[child.value]
          if other then
            if other.kind == "alias" then
              node[k] = other.type
            else
              node[k] = other
            end
          end
        else
          _resolve(child)
        end
      end
      if node.kind == "union" and type(node.types) == "table" then
        local keep = {}
        for i, child in ipairs(node.types) do
          if child.kind == "union" then
            vim.list_extend(keep, child.types)
          else
            table.insert(keep, child)
          end
        end
        node.types = keep
      end
    end
  end
  _resolve(types)
  return types
end

-- dd(M.resolve(M.parse({ file = "lua/snacks/profiler/init.lua" })))
dd(M.resolve(M.parse({ file = "lua/snacks/profiler/init.lua" }))["snacks.profiler.Pick"])

dd(M.parse({
  code = [[
---@alias Foo "a"|"b"|"c"
---@alias snacks.profiler.Field testing
---| "name" fully qualified name of the function
---| "name" 
---| name
---| '"def"' # definition
---| '"ref"' # reference (caller)
---| '"require"' # require
---| '"autocmd"' # autocmd
---| '"modname"' # module name of the called function
---| '"def_file"' # file of the definition
---| '"def_modname"' # module name of the definition
---| '"def_plugin"' # plugin that defines the function
---| '"ref_file"' # file of the reference
---| '"ref_modname"' # module name of the reference
---| '"ref_plugin"' # plugin that references the function
]],
}))

return M
