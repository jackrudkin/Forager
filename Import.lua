-- Import nodes from GatherMate2 / GatherLite SavedVariables (only readable while those addons are enabled).
local _, ns = ...
local Import = {}
ns.Import = Import

local nameToType
local function typeByName(name)
    if not nameToType then
        nameToType = {}
        for id, t in pairs(ns.NodeTypes) do nameToType[t.name:lower()] = id end
    end
    return name and nameToType[name:lower()]
end

local function add(uiMap, x, y, typeKey)
    if not uiMap or not x or not y or x <= 0 or y <= 0 or x >= 1 or y >= 1 then return false end
    local zone = ns.db.nodes[uiMap] or {}
    ns.db.nodes[uiMap] = zone
    -- skip if a learned node of this type is already within ~0.8%
    for key, rec in pairs(zone) do
        if rec.t == typeKey then
            local nx, ny = ns.DecodeXY(key, 1)
            if math.abs(nx - x) < 0.008 and math.abs(ny - y) < 0.008 then return false end
        end
    end
    zone[ns.EncodeXY(x, y)] = { t = typeKey, c = 0, s = "import" }
    return true
end

--- GatherMate2: {GatherMate2HerbDB, GatherMate2MineDB, GatherMate2FishDB}[uiMap][coord] = nodeID.
function Import:GatherMate2()
    local gm = LibStub("AceAddon-3.0", true) and LibStub("AceAddon-3.0"):GetAddon("GatherMate2", true)
    local dbs = { ["Herb Gathering"] = GatherMate2HerbDB, ["Mining"] = GatherMate2MineDB, ["Fishing"] = GatherMate2FishDB }
    local added, skipped, found = 0, 0, false
    for gtype, db in pairs(dbs) do
        if type(db) == "table" then
            found = true
            for uiMap, coords in pairs(db) do
                if type(coords) == "table" and ns.Zones[uiMap] then
                    for coord, nodeID in pairs(coords) do
                        local x, y
                        if gm and gm.DecodeLoc then x, y = gm:DecodeLoc(coord)
                        else
                            x = math.floor(coord / 1000000) / 10000
                            y = math.floor((coord % 1000000) / 100) / 10000
                        end
                        local name = gm and gm.GetNameForNode and gm:GetNameForNode(gtype, nodeID)
                        local t = typeByName(name)
                        if t and add(uiMap, x, y, t) then added = added + 1 else skipped = skipped + 1 end
                    end
                end
            end
        end
    end
    return found, added, skipped
end

--- GatherLite: GatherLiteSettings.global.nodes.{mining,herbalism,fishing} = { {posX,posY,mapID,object}, ... }.
function Import:GatherLite()
    local sv = GatherLiteSettings
    local nodes = type(sv) == "table" and type(sv.global) == "table" and sv.global.nodes
    if type(nodes) ~= "table" then return false, 0, 0 end
    local added, skipped = 0, 0
    for _, kind in ipairs({ "mining", "herbalism", "fishing" }) do
        for _, node in ipairs(nodes[kind] or {}) do
            local t = ns.DS:TypeForObject(tonumber(node.object))
            if t and add(tonumber(node.mapID), tonumber(node.posX), tonumber(node.posY), t) then
                added = added + 1
            else
                skipped = skipped + 1
            end
        end
    end
    return true, added, skipped
end

function Import:Run(quiet)
    local total = 0
    local gmFound, gmAdded, gmSkipped = Import:GatherMate2()
    local glFound, glAdded, glSkipped = Import:GatherLite()
    if gmFound then
        total = total + gmAdded
        if not quiet or gmAdded > 0 then ns:Print(string.format("GatherMate2: %d nodes imported, %d skipped (duplicates/unknown).", gmAdded, gmSkipped)) end
    end
    if glFound then
        total = total + glAdded
        if not quiet or glAdded > 0 then ns:Print(string.format("GatherLite: %d nodes imported, %d skipped.", glAdded, glSkipped)) end
    end
    if not gmFound and not glFound and not quiet then
        ns:Print("Nothing to import. Enable GatherMate2 or GatherLite for one session, then run /forager import.")
    end
    ns.db.imported.last = time()
    ns.db.imported.gm = gmFound or ns.db.imported.gm
    ns.db.imported.gl = glFound or ns.db.imported.gl
    if total > 0 then
        ns.DS:Invalidate()
        ns:Fire("FORAGER_NODES_CHANGED")
    end
    return total
end

--- First run: import silently once if either addon's data is present.
function Import:FirstRun()
    if ns.db.imported.firstRun then return end
    ns.db.imported.firstRun = time()
    Import:Run(true)
end
