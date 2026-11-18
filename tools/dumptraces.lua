-- usage: lua5.1 dumptraces.lua <QuestieDB>/src/corrections/Forever/traces <out prefix>
-- Writes <prefix>_npc.json and <prefix>_obj.json from QuestieDB's Forever trace layer: NPC/object
-- records aggregated from Questie users' own clients (QuestieTrace). build_data.py adds the NPCs the
-- converted Classic data doesn't have (Forever's new NPCs, including the new zones).
local dir, out = arg[1], arg[2]
local modules = {}
QuestieLoader = { CreateModule = function(_, n) local m = {} modules[n] = m return m end,
  ImportModule = function(_, n) return modules[n] or {} end }
local keysN = { name=1, minLevel=2, maxLevel=3, rank=4, spawns=5, zoneID=6, friendlyToFaction=7,
  questStarts_add=8, questEnds_add=9 }
modules.QuestieDB = { npcKeys = keysN, objectKeys = keysN }
modules.ZoneDB = { zoneIDs = setmetatable({}, { __index = function(_, k) return k end }) }
local function enc(v)
  local t = type(v)
  if t == "number" then return tostring(v) elseif t == "string" then return string.format("%q", v)
  elseif t == "table" then
    local parts, n, cnt = {}, #v, 0
    for _ in pairs(v) do cnt = cnt + 1 end
    if n > 0 and cnt == n and type(v[1]) ~= "nil" and not (type(v[1]) == "table" and type(v[1][1]) == "table") then for _, x in ipairs(v) do parts[#parts+1] = enc(x) end return "[" .. table.concat(parts, ",") .. "]" end
    for k, x in pairs(v) do parts[#parts+1] = string.format("%q", tostring(k)) .. ":" .. enc(x) end
    return "{" .. table.concat(parts, ",") .. "}"
  elseif t == "boolean" then return tostring(v) else return "null" end
end
for _, f in ipairs({ { "foreverNpcTraces.lua", "ForeverNpcTraces", "npc" }, { "foreverObjectTraces.lua", "ForeverObjectTraces", "obj" } }) do
  dofile(dir .. "/" .. f[1])
  local data = modules[f[2]]:Load()
  local names = {}
  for k, v in pairs(keysN) do names[v] = k end
  local o = {}
  for id, rec in pairs(data) do
    local r = {}
    for k, v in pairs(rec) do r[names[k] or tostring(k)] = v end
    o[tostring(id)] = r
  end
  local fh = io.open(out .. "_" .. f[3] .. ".json", "w") fh:write(enc(o)) fh:close()
end
