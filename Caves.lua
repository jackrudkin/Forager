-- Caves: tells whether a map position is inside a cave or mine.
-- Sources, best first:
--   1. Learned: cells you walked through while inside a cave subzone (IsIndoors + GetSubZoneText),
--      plus mobs you saw there. Shared nowhere unless guild sharing is on.
--   2. The game's explored-map overlays: C_MapExplorationInfo.GetExploredAreaIDsAtPosition names the
--      subzone at a position (explored areas only). A cave name from the zone's area list counts.
-- Cave names per zone come from QuestieDB's area table (ns.Zones[uiMap].caves).
local _, ns = ...
local Caves = {}
ns.Caves = Caves

local LEARN = 100         -- learned cells: 1% of the map
local OVER = 50           -- overlay cache cells: 2% of the map
local overlayCache = {}   -- [uiMap] = { [cell] = name | false }
local areaNameCache = {}  -- [uiMap] = { [cell] = name | false } (any subzone, for labels)
local hasOverlayAPI

local function lkey(x, y) return math.floor(x * LEARN) * 1000 + math.floor(y * LEARN) end
local function okey(x, y) return math.floor(x * OVER) * 1000 + math.floor(y * OVER) end

function Caves:IsCaveName(uiMap, name)
    if type(name) ~= "string" or name == "" then return false end
    local z = ns.Zones[uiMap]
    if z and z.caves then
        for _, n in ipairs(z.caves) do if n == name then return true end end
    end
    local l = " " .. name:lower() .. " "
    for _, kw in ipairs(ns.CaveKeywords) do
        if l:find("[%s%p]" .. kw .. "[%s%p]") then return true end
    end
    return false
end

local function overlayAPI()
    if hasOverlayAPI == nil then
        hasOverlayAPI = (C_MapExplorationInfo and C_MapExplorationInfo.GetExploredAreaIDsAtPosition and CreateVector2D
            and C_Map and C_Map.GetAreaInfo) and true or false
    end
    return hasOverlayAPI
end

--- Names of explored subzones at a position (game overlay data), or nil.
local function overlayNames(uiMap, x, y)
    if not overlayAPI() then return nil end
    local ok, ids = pcall(C_MapExplorationInfo.GetExploredAreaIDsAtPosition, uiMap, CreateVector2D(x, y))
    if not ok or type(ids) ~= "table" then return nil end
    local names = {}
    for _, id in ipairs(ids) do
        local n = ns.Safe(C_Map.GetAreaInfo(id))
        if n then names[#names + 1] = n end
    end
    return names
end

--- Subzone name at a position from the explored overlays (any kind of area), cached.
function Caves:AreaName(uiMap, x, y)
    if not uiMap or not x then return nil end
    local c = areaNameCache[uiMap]
    if not c then c = {} areaNameCache[uiMap] = c end
    local k = okey(x, y)
    local v = c[k]
    if v == nil then
        local names = overlayNames(uiMap, (math.floor(x * OVER) + 0.5) / OVER, (math.floor(y * OVER) + 0.5) / OVER)
        v = (names and names[1]) or false
        c[k] = v
    end
    if v then return v end
    -- learned cave name
    local learned = ns.db.caves[uiMap]
    local rec = learned and learned[lkey(x, y)]
    return rec and rec.n or nil
end

local function overlayCave(uiMap, x, y)
    local c = overlayCache[uiMap]
    if not c then c = {} overlayCache[uiMap] = c end
    local k = okey(x, y)
    local v = c[k]
    if v == nil then
        local names = overlayNames(uiMap, (math.floor(x * OVER) + 0.5) / OVER, (math.floor(y * OVER) + 0.5) / OVER)
        if names == nil then
            v = "?"
        else
            v = false
            for _, n in ipairs(names) do if Caves:IsCaveName(uiMap, n) then v = n break end end
        end
        c[k] = v
    end
    if v == "?" then return nil end
    return v
end

--- true/false/nil (unknown), cave name.
function Caves:At(uiMap, x, y)
    if not uiMap or not x then return nil end
    local learned = ns.db.caves[uiMap]
    if learned then
        local cx, cy = math.floor(x * LEARN), math.floor(y * LEARN)
        for dx = -1, 1 do
            for dy = -1, 1 do
                local rec = learned[(cx + dx) * 1000 + (cy + dy)]
                if rec then return true, rec.n end
            end
        end
    end
    local o = overlayCave(uiMap, x, y)
    if o then return true, o end
    if o == false then return false end
    return nil
end

--- Does the zone have any caves/mines at all (bundled names or learned cells)?
function Caves:ZoneHasCaves(uiMap)
    local z = ns.Zones[uiMap]
    if z and z.caves and #z.caves > 0 then return true end
    return ns.db.caves[uiMap] ~= nil and next(ns.db.caves[uiMap]) ~= nil
end

--- Whether cave info exists for a zone (learned cells or the overlay API).
function Caves:Known(uiMap)
    return (ns.db.caves[uiMap] and next(ns.db.caves[uiMap]) ~= nil) or overlayAPI()
end

--- Is a mob a cave dweller in this zone? true/false/nil, cave name.
function Caves:MobInCave(npcID, uiMap, pts)
    local seen = ns.db.caveMobs[npcID]
    if seen and (not uiMap or seen.m == uiMap) then return true, seen.n end
    if not pts or #pts == 0 then return nil end
    local yes, known, name = 0, 0, nil
    for i = 1, #pts, 2 do
        local c, n = Caves:At(uiMap, pts[i], pts[i + 1])
        if c ~= nil then
            known = known + 1
            if c then yes = yes + 1 name = name or n end
        end
    end
    if known == 0 then return nil end
    return yes / known >= 0.5, name
end

--- Learned caves in a zone: { {name, x, y, cells}, ... } (centroid of learned cells).
function Caves:List(uiMap)
    local out, by = {}, {}
    for k, rec in pairs(ns.db.caves[uiMap] or {}) do
        local x, y = (math.floor(k / 1000) + 0.5) / LEARN, ((k % 1000) + 0.5) / LEARN
        local n = rec.n or "Cave"
        local e = by[n]
        if not e then e = { name = n, sx = 0, sy = 0, cells = 0 } by[n] = e out[#out + 1] = e end
        e.sx, e.sy, e.cells = e.sx + x, e.sy + y, e.cells + 1
    end
    for _, e in ipairs(out) do e.x, e.y = e.sx / e.cells, e.sy / e.cells end
    table.sort(out, function(a, b) return a.name < b.name end)
    return out
end

-------------------------------------------------------------------------------
-- learning
-------------------------------------------------------------------------------
--- Player is in a cave right now? Returns caveName or nil.
function Caves:PlayerCave()
    if not (IsIndoors and GetSubZoneText) then return nil end
    if not IsIndoors() then return nil end
    if ns.Player:InRestrictedContent() then return nil end
    local sub = ns.Safe(GetSubZoneText())
    local uiMap = ns.Player:MapID()
    if uiMap and Caves:IsCaveName(uiMap, sub) then return sub, uiMap end
    return nil
end

function Caves:LearnHere()
    local name, uiMap = Caves:PlayerCave()
    if not name then return nil end
    local x, y = ns.Player:Position(uiMap)
    if not x then return nil end
    local z = ns.db.caves[uiMap]
    if not z then z = {} ns.db.caves[uiMap] = z end
    local k = lkey(x, y)
    local rec = z[k]
    if not rec then
        z[k] = { n = name, c = 1 }
        ns:Fire("FORAGER_CAVES_CHANGED", uiMap)
    else
        rec.c = (rec.c or 0) + 1
    end
    return name, uiMap
end

local function learnUnit(unit)
    local name, uiMap = Caves:PlayerCave()
    if not name then return end
    local guid = ns.Safe(UnitGUID(unit))
    local id, kind = ns.IDFromGUID(guid)
    if kind ~= "Creature" or not id then return end
    if UnitCanAttack and not ns.Safe(UnitCanAttack("player", unit)) then return end
    local rec = ns.db.caveMobs[id]
    if not rec then
        ns.db.caveMobs[id] = { m = uiMap, n = name, c = 1 }
    else
        rec.c = (rec.c or 0) + 1
    end
end

--- Forget cached explored-area lookups (after exploring something new).
function Caves:ResetCache()
    wipe(overlayCache)
    wipe(areaNameCache)
end

function Caves:Init()
    ns:On("MAP_EXPLORATION_UPDATED", function() Caves:ResetCache() end)
    ns.Ticker(2, function() if ns.db then Caves:LearnHere() end end)
    ns:On("UPDATE_MOUSEOVER_UNIT", function() learnUnit("mouseover") end)
    ns:On("PLAYER_TARGET_CHANGED", function() learnUnit("target") end)
    ns:On("NAME_PLATE_UNIT_ADDED", function(_, unit) if unit then learnUnit(unit) end end)
end
