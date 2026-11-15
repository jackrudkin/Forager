-- usage: lua5.1 dumpq.lua <questie data file> <field: objectData|npcData> <out.json>
local path, field, out = arg[1], arg[2], arg[3]
local src = io.open(path):read("*a")
local s = src:match(field .. "%s*=%s*%[(=*)%[")
local eq = s
local pat = field .. "%s*=%s*%[" .. eq .. "%[(.-)%]" .. eq .. "%]"
local body = src:match(pat)
assert(body, "no body")
local f = assert(loadstring(body))
local t = f()
local function enc(v)
  local tv = type(v)
  if tv == "number" then return tostring(v)
  elseif tv == "string" then return string.format("%q", v):gsub("\\\n","\\n")
  elseif tv == "boolean" then return tostring(v)
  elseif tv == "nil" then return "null"
  elseif tv == "table" then
    local parts = {}
    for k, val in pairs(v) do parts[#parts+1] = '"' .. tostring(k) .. '":' .. enc(val) end
    return "{" .. table.concat(parts, ",") .. "}"
  end
end
local o = io.open(out, "w")
o:write("{")
local first = true
for id, row in pairs(t) do
  if not first then o:write(",") end
  first = false
  o:write('"', id, '":', enc(row), "\n")
end
o:write("}")
o:close()
