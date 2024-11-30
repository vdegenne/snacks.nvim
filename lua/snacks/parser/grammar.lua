-- Lua lpeg grammer based on https://github.com/neovim/neovim/blob/4426a326e2441326e280a0478f83128e09305806/scripts/luacats_grammar.lua

local lpeg = vim.lpeg
local P, R, S = lpeg.P, lpeg.R, lpeg.S
local C, Ct, Cg = lpeg.C, lpeg.Ct, lpeg.Cg
local Cc = lpeg.Cc

--- @param x vim.lpeg.Pattern
local function rep(x)
  return x ^ 0
end

--- @param x vim.lpeg.Pattern
local function rep1(x)
  return x ^ 1
end

--- @param x vim.lpeg.Pattern
local function opt(x)
  return x ^ -1
end

local ws = rep1(S(" \t"))
local fill = opt(ws)
local any = P(1)
local letter = R("az", "AZ")
local num = R("09")

--- @param x string | vim.lpeg.Pattern
local function Pf(x)
  return fill * P(x) * fill
end

--- @param x string | vim.lpeg.Pattern
local function Plf(x)
  return fill * P(x)
end

--- @param x string
local function Sf(x)
  return fill * S(x) * fill
end

--- @param x vim.lpeg.Pattern
local function paren(x)
  return Pf("(") * x * fill * P(")")
end

--- @param x vim.lpeg.Pattern
local function parenOpt(x)
  return paren(x) + x
end

--- @param x vim.lpeg.Pattern
local function comma1(x)
  return parenOpt(x * rep(Pf(",") * x))
end

--- @param x vim.lpeg.Pattern
local function comma(x)
  return opt(comma1(x))
end

--- @type table<string,vim.lpeg.Pattern>
local v = setmetatable({}, {
  __index = function(_, k)
    return lpeg.V(k)
  end,
})

local function annot(nm, pat)
  if type(nm) == "string" then
    nm = P(nm)
  end
  if pat then
    return Ct(Cg(P(nm), "kind") * fill * pat)
  end
  return Ct(Cg(P(nm), "kind"))
end
--- @class TypeNode
--- @field kind string
--- @field value? string
--- @field types? TypeNode[]
--- @field keyType? TypeNode
--- @field valueType? TypeNode
--- @field params? TypeNode[]
--- @field returns? TypeNode[]
--- @field name? string
--- @field optional? boolean
--- @field array? boolean

local builtins = {
  "nil",
  "number",
  "string",
  "boolean",
  "table",
  "function",
  "thread",
  "userdata",
}

local function makeType(kind, value)
  if kind == "identifier" and (value == "true" or value == "false") then
    kind = "literal"
  end
  if kind == "identifier" and vim.tbl_contains(builtins, value) then
    kind = value
    value = nil
  end
  if kind == "literal" then
    if value == "true" or value == "false" then
      kind, value = "boolean", value == "true"
    elseif value:find("^['\"]") then
      kind, value = "string", value:sub(2, -2)
    else
      assert(tonumber(value), "invalid number literal: " .. value)
      kind, value = "number", tonumber(value)
    end
  end
  return { kind = kind, value = value }
end

local function makeUnion(types)
  return { kind = "union", types = types }
end

local function makeArray(baseType)
  return { kind = "array", value = baseType, array = true }
end

local function makeOptional(baseType)
  return { kind = "optional", value = baseType, optional = true }
end

local colon = Pf(":")
local ellipsis = P("...")
local ident_first = P("_") + letter
local ident = ident_first * rep(ident_first + num)
local opt_ident = ident * opt(P("?"))
local ty_ident_sep = S("-._")
local ty_ident = ident * rep(ty_ident_sep * ident)
local string_single = P("'") * rep(any - P("'")) * P("'")
local string_double = P('"') * rep(any - P('"')) * P('"')
local generic = P("`") * ty_ident * P("`")
local literal = string_single + string_double + (opt(P("-")) * rep1(num)) + P("false") + P("true")
local ty_prims = (ty_ident / function(t)
  return makeType("identifier", t)
end) + (literal / function(l)
  return makeType("literal", l)
end) + (generic / function(g)
  return makeType("generic", g)
end)

local array_postfix = rep1(Plf("[]"))
local opt_postfix = rep1(Plf("?"))
local rep_array_opt_postfix = rep(array_postfix + opt_postfix)

local typedef = P({
  "typedef",
  typedef = v.type,

  type = (v.ty * rep_array_opt_postfix * rep(Pf("|") * v.ty * rep_array_opt_postfix)) / function(...)
    local types = { ... }
    if #types == 1 then
      return types[1]
    end
    return makeUnion(types)
  end,

  ty = v.composite + paren(v.typedef),

  composite = (v.types * array_postfix / makeArray) + (v.types * opt_postfix / makeOptional) + v.types,

  types = v.kv_table + v.generics + v.tuple + v.dict + v.table_literal + v.fun + ty_prims,

  tuple = (Pf("[") * comma1(v.type) * Plf("]")) / function(...)
    return { kind = "tuple", types = { ... } }
  end,

  dict = (Pf("{") * comma1(Pf("[") * v.type * Pf("]") * colon * v.type) * Plf("}")) / function(...)
    local entries = { ... }
    return {
      kind = "dictionary",
      keyType = entries[1],
      valueType = entries[2],
    }
  end,

  kv_table = (Pf("table") * Pf("<") * v.type * Pf(",") * v.type * Plf(">")) / function(k, v)
    return {
      kind = "table",
      key = k,
      value = v,
    }
  end,

  table_literal = (Pf("{") * comma1(opt_ident * Pf(":") * v.type) * Plf("}")) / function(...)
    local fields = { ... }
    return {
      kind = "table_literal",
      fields = fields,
    }
  end,

  fun_param = ((opt_ident + ellipsis) * opt(colon * v.type)) / function(name, typ)
    return {
      kind = "parameter",
      name = name,
      type = typ,
    }
  end,

  fun_ret = (v.type + (ellipsis * opt(colon * v.type))) / function(t)
    return {
      kind = "return",
      type = t,
    }
  end,

  fun = (Pf("fun") * paren(comma(v.fun_param)) * opt(Pf(":") * comma1(v.fun_ret))) / function(params, returns)
    return {
      kind = "function",
      params = params or {},
      returns = returns or {},
    }
  end,

  generics = (Cg(P(ty_ident), "name") * Pf("<") * comma1(v.type) * Plf(">")) / function(name, ...)
    return {
      kind = "generic",
      name = name,
      types = { ... },
    }
  end,
})

local opt_exact = opt(Cg(Pf("(exact)"), "access"))
local access = P("private") + P("protected") + P("package")
local caccess = Cg(access, "access")
local desc_delim = Sf("#:") + ws
local desc = Cg(rep(any), "desc")
local opt_desc = opt(desc_delim * desc)
local ty_name = Cg(ty_ident, "name")
local opt_parent = opt(colon * Cg(ty_ident, "parent"))
local optional = (Cg(opt(P("?")) / function(v)
  return v == "?" and true or nil
end, "optional"))
local lname = (ident + ellipsis)

local grammar = P({
  rep1(P("@") * (v.ats + v.ext_ats)),

  ats = annot("param", Cg(lname, "name") * optional * ws * v.ctype * opt_desc)
    + annot("return", comma1(Ct(v.ctype * opt(ws * (ty_name + Cg(ellipsis, "name"))))) * opt_desc)
    + annot("type", comma1(Ct(v.ctype)) * opt_desc)
    + annot("cast", ty_name * ws * opt(Sf("+-")) * v.ctype)
    + annot("generic", ty_name * opt(colon * v.ctype))
    + annot("class", opt_exact * opt(paren(caccess)) * fill * ty_name * opt_parent)
    + annot("field", opt(caccess * ws) * v.field_name * ws * v.ctype * opt_desc)
    + annot("operator", ty_name * opt(paren(Cg(v.ctype, "argtype"))) * colon * v.ctype)
    + annot(access)
    + annot("deprecated")
    + annot("|", fill * opt(P("'")) * v.ctype * opt(P("'")) * opt_desc)
    + annot("alias", ty_name * opt(ws * v.ctype) * opt_desc)
    + annot("enum", ty_name)
    + annot("overload", v.ctype)
    + annot("see", opt(desc_delim) * desc)
    + annot("diagnostic", opt(desc_delim) * desc)
    + annot("meta"),

  --- Custom extensions
  ext_ats = (annot("note", desc) + annot("since", desc) + annot("nodoc") + annot("inlinedoc") + annot("brief", desc)),

  field_name = Cg(lname + v.ty_index, "name") * optional,
  ty_index = C(Pf("[") * typedef * fill * P("]")),
  ctype = Cg(typedef, "type"),
})

return grammar
