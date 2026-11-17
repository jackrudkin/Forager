-- Learn: turns your own gathers into the numbers the finders use, replacing Classic-era estimates.
--   * node yields per visit (all items, Scarce finds included) once a node type has minSamples visits
--   * gathers per node (Mining veins take several) from the same visits
--   * cast and loot seconds per profession once 10 casts are measured
--   * Scarce find rates, pooled per Scarce item (herbs/ore: per gather, skinning: per skin)
-- Static fallbacks: Classic loot tables (CMaNGOS), Classic cast times (classicdb), and the Forever
-- sources listed in Data/Static.lua.
local _, ns = ...
local Learn = {}
ns.Learn = Learn

Learn.TIME_MIN = 10      -- measured casts before your own cast time is used
Learn.SCARCE_MIN = 100   -- gathers/skins before a pooled Scarce rate is used
Learn.VISIT_GAP = 90     -- seconds: loots on the same node closer than this are one visit

local infoCache, cacheKey = {}, nil

local function store()
    local d = ns.db.learn
    if type(d) ~= "table" then d = {} ns.db.learn = d end
    d.nodes = d.nodes or {}
    d.cast = d.cast or {}
    d.loot = d.loot or {}
    d.scarceSkin = d.scarceSkin or {}
    return d
end
Learn.Store = store

local function minN() return (ns.settings and ns.settings.minSamples) or 30 end
local function extraSec() return (ns.settings and ns.settings.gatherSeconds) or 1 end

function Learn:Changed()
    wipe(infoCache)
    if ns.DS and ns.DS.InvalidateMobs then ns.DS:InvalidateMobs() end
end

local function addAvg(t, kind, secs)
    local r = t[kind] or { n = 0, s = 0 }
    t[kind] = r
    r.n, r.s = r.n + 1, r.s + secs
    if r.n > 200 then r.n, r.s = r.n / 2, r.s / 2 end -- keep the average recent
end

--- A finished gather cast (UNIT_SPELLCAST_START -> SUCCEEDED) of kind herb/ore/skin.
function Learn:AddCast(kind, secs)
    if not kind or type(secs) ~= "number" or secs < 0.3 or secs > 15 then return end
    addAvg(store().cast, kind, secs)
    wipe(infoCache)
end

--- Seconds a gather loot window was open (LOOT_READY -> LOOT_CLOSED).
function Learn:AddLootTime(kind, secs)
    if not kind or type(secs) ~= "number" or secs < 0 or secs > 10 then return end
    addAvg(store().loot, kind, secs)
    wipe(infoCache)
end

--- Seconds per cast for a kind and where it comes from ("me" or "classic").
function Learn:CastSeconds(kind)
    local r = store().cast[kind]
    if r and r.n >= Learn.TIME_MIN then return r.s / r.n, "me", r.n end
    if ns.CastSeconds[kind] then return ns.CastSeconds[kind], "classic", r and r.n or 0 end
    return nil, nil, r and r.n or 0
end

function Learn:LootSeconds(kind)
    local r = store().loot[kind]
    if r and r.n >= Learn.TIME_MIN then return r.s / r.n, "me", r.n end
    return 0, nil, r and r.n or 0
end

--- One gather loot on a node. newVisit: first loot of this visit (veins can be looted several times).
function Learn:AddNode(typeKey, items, newVisit)
    if typeKey == nil then return end
    local d = store().nodes
    local r = d[typeKey] or { v = 0, n = 0, y = {} }
    d[typeKey] = r
    r.n = r.n + 1
    if newVisit or r.v == 0 then r.v = r.v + 1 end
    for id, q in pairs(items or {}) do r.y[id] = (r.y[id] or 0) + q end
    wipe(infoCache)
end

--- One skin of mob m (decoded bundled mob or nil) with the items it gave.
function Learn:AddSkin(m, items)
    if not m then return end
    local d = store().scarceSkin
    for _, sd in ipairs(ns.ScarceSkin) do
        if Learn.InScarceBand(m, sd) then
            local r = d[sd.id] or { n = 0, c = 0 }
            d[sd.id] = r
            r.n = r.n + 1
            r.c = r.c + ((items and items[sd.id]) or 0)
        end
    end
    Learn:Changed()
end

function Learn.InScarceBand(m, sd)
    return m.ctype == sd.ctype and (m.minLevel or 0) <= sd.maxLevel and (m.maxLevel or 0) >= sd.minLevel
end

--- Pooled Scarce rate per gather over all node types that give it: rate, gathers.
function Learn:ScarceNodeRate(scarceID)
    local loots, found = 0, 0
    for key, r in pairs(store().nodes) do
        local t = type(key) == "number" and ns.NodeTypes[key]
        if t and ns.ScarceForNode[t.name] == scarceID then
            loots = loots + (r.n or 0)
            found = found + (r.y and r.y[scarceID] or 0)
        end
    end
    return loots > 0 and found / loots or 0, loots
end

--- Effective numbers for a node type:
--- { perNode = {{itemID, qty per node}}, taps, secs (per node), learned, n, src, scarce, scarceRate, scarceN }
function Learn:NodeInfo(t)
    local key = minN() .. ":" .. extraSec()
    if key ~= cacheKey then wipe(infoCache) cacheKey = key end
    local c = infoCache[t.id or t.name]
    if c then return c end
    local r = t.id ~= nil and store().nodes[t.id] or nil
    local info = { perNode = {}, scarce = ns.ScarceForNode[t.name], n = r and r.v or 0 }
    if r and r.v >= minN() then
        info.learned, info.src = true, "my data"
        info.taps = r.n / r.v
        for id, q in pairs(r.y) do info.perNode[#info.perNode + 1] = { id, q / r.v } end
        table.sort(info.perNode, function(a, b) return a[2] > b[2] end)
        if info.scarce then info.scarceRate = (r.y[info.scarce] or 0) / r.n info.scarceN = r.n end
    else
        info.src = "Classic est."
        info.taps = t.taps or 1
        if t.yields and #t.yields > 0 then
            for _, y in ipairs(t.yields) do info.perNode[#info.perNode + 1] = { y[1], y[2] * info.taps } end
        elseif t.item and t.item > 0 then
            info.perNode[1] = { t.item, 1.5 * info.taps }
        end
        if info.scarce then
            local rate, n = Learn:ScarceNodeRate(info.scarce)
            info.scarceN = n
            if n >= Learn.SCARCE_MIN then
                info.scarceRate = rate
                info.perNode[#info.perNode + 1] = { info.scarce, rate * info.taps }
            end
        end
    end
    local cast = Learn:CastSeconds(t.kind) or extraSec()
    info.secs = info.taps * (cast + (Learn:LootSeconds(t.kind))) + extraSec()
    infoCache[t.id or t.name] = info
    return info
end

--- Expected count of an item per node of a type.
function Learn:NodeQty(t, itemID)
    for _, y in ipairs(Learn:NodeInfo(t).perNode) do if y[1] == itemID then return y[2] end end
    return 0
end

--- Effective skin list for a decoded mob: own data from minSamples skins, else the Classic list
--- plus Forever Scarce (Pristine Leather) where a source gives a level band. Returns list, label.
function Learn:SkinList(m)
    local own = ns.db and ns.db.mobs and ns.db.mobs[m.id]
    local s = own and own.s or 0
    if s >= minN() then
        local counts = own.si or {}
        if (own.ss or 0) >= minN() then counts, s = own.sq or {}, own.ss end -- with quantities (1.7+)
        local out = {}
        for id, q in pairs(counts) do out[#out + 1] = { id, q / s } end
        table.sort(out, function(a, b) return a[2] > b[2] end)
        return out, "my data n=" .. s, true
    end
    local out = {}
    for i, e in ipairs(m.skinBase or {}) do out[i] = e end
    if m.skinnable then
        for _, sd in ipairs(ns.ScarceSkin) do
            if Learn.InScarceBand(m, sd) then
                local r = ns.db and ns.db.learn and ns.db.learn.scarceSkin and ns.db.learn.scarceSkin[sd.id]
                local rate = sd.rate
                if r and r.n >= Learn.SCARCE_MIN then rate = r.c / r.n end
                out[#out + 1] = { sd.id, rate }
            end
        end
    end
    return out, "estimate", false
end

--- Seed the store from data recorded before 1.7 (node yields kept per spot).
function Learn:SeedFromNodes(db)
    db.learn = db.learn or {}
    local d = db.learn
    d.nodes = d.nodes or {}
    for _, zone in pairs(db.nodes or {}) do
        for _, rec in pairs(zone) do
            if (rec.s == nil or rec.s == "me") and rec.t ~= nil and (rec.c or 0) > 0 then
                local t = type(rec.t) == "number" and ns.NodeTypes[rec.t]
                local taps = (t and t.taps) or 1
                local r = d.nodes[rec.t] or { v = 0, n = 0, y = {} }
                d.nodes[rec.t] = r
                r.n = r.n + rec.c
                r.v = r.v + math.max(1, rec.c / taps) -- old data has no visit count: Classic taps estimate
                for id, q in pairs(rec.y or {}) do r.y[id] = (r.y[id] or 0) + q end
            end
        end
    end
end

--- Short summary for /forage diag and the Settings tab.
function Learn:Summary()
    local d = store()
    local parts = {}
    for _, kind in ipairs({ "herb", "ore", "skin" }) do
        local sec, src, n = Learn:CastSeconds(kind)
        if sec then
            parts[#parts + 1] = string.format("%s %.1fs (%s)", kind, sec, src == "me" and ("you, n=" .. math.floor(n)) or "Classic")
        elseif n > 0 then
            parts[#parts + 1] = string.format("%s measuring (n=%d)", kind, n)
        end
    end
    local types, ready = 0, 0
    for _, r in pairs(d.nodes) do
        types = types + 1
        if r.v >= minN() then ready = ready + 1 end
    end
    return table.concat(parts, ", "), types, ready
end
