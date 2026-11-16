-- Combo: gather + kill. Ranks areas where you mine and/or pick herbs AND kill the mobs along the way,
-- with time as the shared budget, so the two incomes are not simply added up.
--
-- Model, per loop of the route:
--   walk   = route length / speed
--   gather = live nodes near the route x seconds per gather
--   fight  = mobs killed x seconds per kill (scaled by how much lower level they are)
--   gold/h = (node value + mob value) x 3600 / (walk + gather + fight)
-- Which mobs to kill: a mob type is worth it only when its gold per second of fighting beats the
-- loop's current gold per second. Taking types in order of gold per fighting second while that holds
-- gives the best possible total (the classic best-ratio rule). Mobs you killed are only back after
-- their respawn time, so a short loop finds fewer of them; this is solved by iterating.
-- Two routes are tried per area: through the nodes only, and through the nodes plus the best camps
-- of worthwhile mobs that the node route misses. The faster one wins.
local _, ns = ...
local Combo = {}
ns.Combo = Combo
local DS, P = ns.DS, ns.Player

local GRID = 20
Combo.KINDS = { ore = { ore = true }, herb = { herb = true }, both = { ore = true, herb = true } }

function Combo:DefaultGather()
    local g = ns.settings.comboGather
    if g and Combo.KINDS[g] then return g end
    if P.skills.ore then return "ore" end
    if P.skills.herb then return "herb" end
    return "ore"
end

-------------------------------------------------------------------------------
-- geometry (yards)
-------------------------------------------------------------------------------
local function segDist2(px, py, ax, ay, bx, by)
    local dx, dy = bx - ax, by - ay
    local len2 = dx * dx + dy * dy
    local t = 0
    if len2 > 0 then t = math.max(0, math.min(1, ((px - ax) * dx + (py - ay) * dy) / len2)) end
    local qx, qy = ax + t * dx - px, ay + t * dy - py
    return qx * qx + qy * qy
end

--- Route as yard segments with bounding boxes (padded by R) for quick corridor tests.
local function corridor(route, w, h, R)
    local segs, pts = {}, route.points
    local n = #pts
    for i = 1, n do
        local a, b = pts[i], pts[i % n + 1]
        local ax, ay, bx, by = a.x * w, a.y * h, b.x * w, b.y * h
        segs[i] = { ax, ay, bx, by, math.min(ax, bx) - R, math.min(ay, by) - R, math.max(ax, bx) + R, math.max(ay, by) + R }
    end
    return segs
end

local function inCorridor(segs, x, y, R2)
    for _, s in ipairs(segs) do
        if x >= s[5] and x <= s[7] and y >= s[6] and y <= s[8] and segDist2(x, y, s[1], s[2], s[3], s[4]) <= R2 then return true end
    end
    return false
end

-------------------------------------------------------------------------------
-- one loop: who to kill, time and income
-------------------------------------------------------------------------------
--- route: built route; nodes/mobs: points in the area; info: per-npc { m, v, lf }; ctx: settings.
local function simulate(uiMap, route, nodes, mobs, info, ctx)
    local w, h = P:ZoneSize(uiMap)
    local R = ctx.pull
    local segs = corridor(route, w, h, R)
    local R2 = R * R
    local single = #route.points == 1 and route.points[1]
    local function near(p)
        if single then
            local dx, dy = (p.x - single.x) * w, (p.y - single.y) * h
            return dx * dx + dy * dy <= R2
        end
        return inCorridor(segs, p.x * w, p.y * h, R2)
    end
    -- nodes you pass (they're on the route or within pull range of it)
    local nodeOn, nodeIncome, byType = {}, 0, {}
    for _, p in ipairs(nodes) do
        if near(p) then
            nodeOn[#nodeOn + 1] = p
            nodeIncome = nodeIncome + p.v * ctx.active
            byType[p.t] = (byType[p.t] or 0) + 1
        end
    end
    local liveNodes = #nodeOn * ctx.active
    local walk = route.length / ctx.speed
    local gather = liveNodes * ctx.gatherSec
    -- mobs you pass, per type
    local types, mobOn = {}, {}
    for _, p in ipairs(mobs) do
        if near(p) then
            local e = types[p.npc]
            if not e then
                local inf = info[p.npc]
                e = { npc = p.npc, m = inf.m, v = inf.v, c = 0, killT = (ctx.killSec + R / 2 / ctx.speed) / inf.lf }
                e.rate = e.v / e.killT
                types[p.npc] = e
            end
            e.c = e.c + 1
            mobOn[#mobOn + 1] = p
        end
    end
    local order = {}
    for _, e in pairs(types) do order[#order + 1] = e end
    table.sort(order, function(a, b) return a.rate > b.rate end)
    -- best-ratio selection with respawn feedback (a short loop meets fewer respawned mobs)
    local T, I, chosen, avail = walk + gather, nodeIncome, {}, 1
    for _ = 1, 5 do
        avail = math.min(1, T / ctx.respawn)
        local Tn, In = walk + gather, nodeIncome
        chosen = {}
        for _, e in ipairs(order) do
            if Tn <= 0 or e.rate > In / Tn then
                local a = e.c * avail
                Tn, In = Tn + a * e.killT, In + a * e.v
                chosen[e.npc] = a
            end
        end
        T, I = Tn, In
    end
    if T <= 0 then return nil end
    local fight = math.max(0, T - walk - gather)
    local kills = 0
    for _, a in pairs(chosen) do kills = kills + a end
    return {
        route = route, perHour = I * 3600 / T, nodeRate = nodeIncome * 3600 / T, mobRate = (I - nodeIncome) * 3600 / T,
        nodesOnlyRate = (walk + gather) > 0 and nodeIncome * 3600 / (walk + gather) or 0,
        loopSec = T, walk = walk, gather = gather, fight = fight, avail = avail,
        liveNodes = liveNodes, kills = kills, nodeOn = nodeOn, mobOn = mobOn, byType = byType,
        types = order, chosen = chosen,
    }
end

-------------------------------------------------------------------------------
-- areas
-------------------------------------------------------------------------------
local function newGrid() local g = {} for i = 0, GRID * GRID - 1 do g[i] = 0 end return g end
local function cell(x, y)
    return math.min(GRID - 1, math.max(0, math.floor(x * GRID))), math.min(GRID - 1, math.max(0, math.floor(y * GRID)))
end

--- Top non-overlapping W x W windows of a grid: { {cx, cy, score}, ... }
local function topWindows(grid, W, k, taken)
    local out = {}
    local blocked = {}
    for _, t in ipairs(taken or {}) do blocked[#blocked + 1] = t end
    for _ = 1, k do
        local best, bx, by = 0, nil, nil
        for cy = 0, GRID - W do
            for cx = 0, GRID - W do
                local ok = true
                for _, e in ipairs(blocked) do
                    if not (cx + W <= e[1] or e[1] + W <= cx or cy + W <= e[2] or e[2] + W <= cy) then ok = false break end
                end
                if ok then
                    local s = 0
                    for yy = cy, cy + W - 1 do for xx = cx, cx + W - 1 do s = s + grid[yy * GRID + xx] end end
                    if s > best then best, bx, by = s, cx, cy end
                end
            end
        end
        if not bx then break end
        out[#out + 1] = { bx, by, best }
        blocked[#blocked + 1] = { bx, by }
    end
    return out
end

local function allowed(loc, uiMap, x, y)
    if not loc or loc == "any" then return true end
    local c = ns.Caves:At(uiMap, x, y)
    if loc == "cave" then return c == true end
    return c ~= true
end

local function priceOf(id) return (ns.Prices:Get(id)) end

--- Items per hour for a result: node yields + drops of the mobs you kill.
local function itemsPerHour(r, sim, info, skills, level)
    local loops = 3600 / sim.loopSec
    local items = {}
    local function add(key, fields, qty, value)
        local e = items[key]
        if not e then e = fields e.perHour, e.value = 0, 0 items[key] = e end
        e.perHour = e.perHour + qty
        e.value = e.value + value
    end
    for tk, c in pairs(sim.byType) do
        local t = DS:GetType(tk)
        for _, y in ipairs(t and t.yields or {}) do
            local q = c * r.active * y[2] * (t.taps or 1) * loops
            add(y[1], { id = y[1], node = true }, q, q * priceOf(y[1]))
        end
    end
    for npc, a in pairs(sim.chosen) do
        local _, parts = ns.Finder:MobValue(info[npc].m, "gold", skills, level)
        for _, pa in ipairs(parts) do
            local key = pa.id or (pa.greens and ("greens" .. pa.greens)) or "coin"
            add(key, { id = pa.id, greens = pa.greens, coin = pa.coin }, pa.p * a * loops, pa.value * a * loops)
        end
    end
    local list = {}
    for _, e in pairs(items) do list[#list + 1] = e end
    table.sort(list, function(a, b) return a.value > b.value or (a.value == b.value and a.perHour > b.perHour) end)
    return list
end

local function evalZone(uiMap, gather, opts, ctx, out)
    local kinds = Combo.KINDS[gather]
    local skills, level, loc = opts.skills, opts.level, opts.location
    -- nodes you can gather, valued per visit
    local nodes, minSkill = {}, nil
    for _, pt in ipairs(DS:GetZoneNodes(uiMap)) do
        local t = DS:GetType(pt.t)
        if t and kinds[t.kind] and allowed(loc, uiMap, pt.x, pt.y) then
            local have = skills[t.kind]
            if have and ns.SkillColor(t.skill or 0, have) ~= "red" then
                local v = ns.Finder:NodeValue(t)
                if v > 0 then
                    nodes[#nodes + 1] = { x = pt.x, y = pt.y, t = pt.t, v = v, w = v * ctx.active }
                    minSkill = math.min(minSkill or 999, t.skill or 0)
                end
            end
        end
    end
    if #nodes < 3 then return end
    -- mobs you can kill, valued per kill (all loot, skins if you can skin)
    local info, mobs = {}, {}
    for npc, flat in pairs(DS:GetZoneMobs(uiMap)) do
        local m = DS:GetMob(npc)
        if m then
            local lf = ns.Finder.LevelFactor(m, level, ns.settings.showDangerous)
            if lf > 0 then
                local v = ns.Finder:MobValue(m, "gold", skills, level)
                if v > 0 then
                    info[npc] = { m = m, v = v, lf = lf }
                    for i = 1, #flat, 2 do
                        if allowed(loc, uiMap, flat[i], flat[i + 1]) then
                            mobs[#mobs + 1] = { x = flat[i], y = flat[i + 1], npc = npc }
                        end
                    end
                end
            end
        end
    end
    -- shortlist windows: best for nodes alone, and best for nodes + mobs (rough weights)
    local W = ns.Clamp(math.floor((loc == "cave" and 450 or 800) / (P:ZoneSize(uiMap) / GRID) + 0.5), 2, 9)
    local gNodes, gBoth = newGrid(), newGrid()
    for _, p in ipairs(nodes) do
        local cx, cy = cell(p.x, p.y)
        gNodes[cy * GRID + cx] = gNodes[cy * GRID + cx] + p.w
        gBoth[cy * GRID + cx] = gBoth[cy * GRID + cx] + p.w
    end
    for _, p in ipairs(mobs) do
        local cx, cy = cell(p.x, p.y)
        local inf = info[p.npc]
        -- a kill costs ~killSec; weigh it like the same time spent gathering
        gBoth[cy * GRID + cx] = gBoth[cy * GRID + cx] + inf.v * ctx.gatherSec / (ctx.killSec / inf.lf) * ctx.active
    end
    local cands = topWindows(gNodes, W, 3)
    for _, c in ipairs(topWindows(gBoth, W, 3)) do
        local dup = false
        for _, d in ipairs(cands) do if d[1] == c[1] and d[2] == c[2] then dup = true end end
        if not dup then cands[#cands + 1] = c end
    end
    -- evaluate each candidate exactly
    local evaluated = {}
    for _, c in ipairs(cands) do
        local x1, y1, x2, y2 = c[1] / GRID, c[2] / GRID, (c[1] + W) / GRID, (c[2] + W) / GRID
        local an, am = {}, {}
        for _, p in ipairs(nodes) do if p.x >= x1 and p.x < x2 and p.y >= y1 and p.y < y2 then an[#an + 1] = p end end
        for _, p in ipairs(mobs) do if p.x >= x1 and p.x < x2 and p.y >= y1 and p.y < y2 then am[#am + 1] = p end end
        if #an >= 3 then
            local routeA = ns.Route:Build(uiMap, an, 40)
            local simA = simulate(uiMap, routeA, an, am, info, ctx)
            local best, simOnly = simA, simA
            -- variant B: add the best camps of worthwhile mobs that the node route misses
            if simA and #am > 0 then
                local worth = {}
                for npc in pairs(simA.chosen) do worth[npc] = true end
                for _, e in ipairs(simA.types) do if e.rate > simA.perHour / 3600 then worth[e.npc] = true end end
                for npc, inf in pairs(info) do
                    if not worth[npc] and inf.v / ((ctx.killSec + ctx.pull / 2 / ctx.speed) / inf.lf) > simA.perHour / 3600 then worth[npc] = true end
                end
                local campPts = {}
                for _, p in ipairs(am) do
                    if worth[p.npc] then campPts[#campPts + 1] = { x = p.x, y = p.y, w = info[p.npc].v } end
                end
                if #campPts > 0 then
                    local camps = ns.Route:Clusters(campPts, 6)
                    local pts = {}
                    for _, p in ipairs(an) do pts[#pts + 1] = p end
                    local added = 0
                    for _, cp in ipairs(camps) do
                        if cp.n >= 2 and added < 3 then
                            pts[#pts + 1] = { x = cp.x, y = cp.y, w = cp.w * simA.avail, n = cp.n, camp = true }
                            added = added + 1
                        end
                    end
                    if added > 0 then
                        local routeB = ns.Route:Build(uiMap, pts, 44)
                        local simB = simulate(uiMap, routeB, an, am, info, ctx)
                        if simB and simB.perHour > best.perHour then best = simB end
                    end
                end
            end
            if best then
                best.rect = { x1, y1, x2, y2 }
                best.cell = c
                best.nodesOnlyRate = simOnly.nodesOnlyRate
                best.areaNodes, best.areaMobs = an, am
                evaluated[#evaluated + 1] = best
            end
        end
    end
    table.sort(evaluated, function(a, b) return a.perHour > b.perHour end)
    -- keep up to 2 non-overlapping areas per zone
    local kept = {}
    for _, e in ipairs(evaluated) do
        local overlap = false
        for _, k in ipairs(kept) do
            if not (e.cell[1] + W <= k.cell[1] or k.cell[1] + W <= e.cell[1] or e.cell[2] + W <= k.cell[2] or k.cell[2] + W <= e.cell[2]) then overlap = true end
        end
        if not overlap then kept[#kept + 1] = e end
        if #kept >= (opts.perZone or 2) then break end
    end
    local zone = ns.Zones[uiMap]
    for rank, sim in ipairs(kept) do
        -- dedicated mob farming in the same area, the Finder's way, for comparison
        local mobsOnly, nm = 0, 0
        for _, p in ipairs(sim.areaMobs) do
            local inf = info[p.npc]
            mobsOnly, nm = mobsOnly + inf.v * inf.lf, nm + 1
        end
        if nm > 0 then mobsOnly = mobsOnly / nm * ns.settings.killsPerHour * math.min(1, nm / 25) end
        local mobsList, worthy, skipped, minL, maxL = {}, {}, {}, 99, 0
        for _, e in ipairs(sim.types) do
            local a = sim.chosen[e.npc]
            local row = { npc = e.npc, m = e.m, n = e.c, perKill = e.v, killT = e.killT, perMin = e.rate * 60,
                kills = a and a * 3600 / sim.loopSec or 0 }
            if a then
                worthy[#worthy + 1] = row
                mobsList[#mobsList + 1] = row
                minL, maxL = math.min(minL, e.m.minLevel), math.max(maxL, e.m.maxLevel)
            else
                skipped[#skipped + 1] = row
            end
        end
        local pts = {}
        for _, p in ipairs(sim.nodeOn) do pts[#pts + 1] = p end
        for _, p in ipairs(sim.mobOn) do if sim.chosen[p.npc] then pts[#pts + 1] = p end end
        local r = {
            uiMap = uiMap, goal = "combo:" .. gather, mode = "gold", rank = rank, source = "combo",
            rect = sim.rect, points = pts, route = sim.route, perHour = sim.perHour,
            nodeRate = sim.nodeRate, mobRate = sim.mobRate, nodesOnlyRate = sim.nodesOnlyRate, mobsOnlyRate = mobsOnly,
            loopSec = sim.loopSec, walkSec = sim.walk, gatherSec = sim.gather, fightSec = sim.fight,
            nodesPerHour = sim.liveNodes * 3600 / sim.loopSec, killsPerHour = sim.kills * 3600 / sim.loopSec,
            unitsPerHour = sim.kills * 3600 / sim.loopSec, unitLabel = "kills/h",
            mobs = mobsList, worthy = worthy, skipped = skipped, minSkill = minSkill,
            minLevel = maxL > 0 and minL or nil, maxLevel = maxL > 0 and maxL or nil, active = ctx.active,
            zoneName = zone.name, zoneMin = zone.min, zoneMax = zone.max, confidence = "Classic estimate",
        }
        r.items = itemsPerHour(r, sim, info, skills, level)
        r.why = string.format("%d nodes and %d mobs near the route; mobs killed only when they pay more per second than gathering",
            #sim.nodeOn, #sim.mobOn)
        r.risk, r.riskLevel = ns.Finder.RiskFor(zone, opts.faction)
        ns.Finder.NameArea(r)
        out[#out + 1] = r
    end
end

-------------------------------------------------------------------------------
-- public
-------------------------------------------------------------------------------
--- opts: gather ("ore"|"herb"|"both"), zones, location, includeEnemy, perZone
function Combo:Run(opts)
    DS:Load()
    opts = opts or {}
    local gather = opts.gather or Combo:DefaultGather()
    local s = ns.settings
    opts.level = opts.level or P:Level()
    opts.faction = opts.faction or P:Faction()
    opts.location = opts.location or s.location or "any"
    opts.skills = opts.skills or {}
    if not next(opts.skills) then for k, v in pairs(P.skills) do opts.skills[k] = v.rank end end
    -- a profession you don't have: assume enough skill to see the spots (like the Finder does)
    for k in pairs(Combo.KINDS[gather]) do opts.skills[k] = opts.skills[k] or 300 end
    if opts.includeEnemy == nil then opts.includeEnemy = s.includeEnemy end
    if not opts.zones and ns.Quests:IsActive() then
        local z1, z2 = ns.Quests:Zones()
        opts.zones = { z1, z2 }
    end
    local ctx = {
        speed = P:Speed(), active = s.activeFraction, gatherSec = s.gatherSeconds,
        killSec = s.comboKillSeconds, pull = s.comboPullYards, respawn = math.max(30, s.comboRespawn),
    }
    local out = {}
    for _, uiMap in ipairs(ns.Finder.ZoneCandidates(opts)) do
        local ok, err = pcall(evalZone, uiMap, gather, opts, ctx, out)
        if not ok then ns:Debug("combo " .. uiMap .. ": " .. tostring(err)) end
    end
    table.sort(out, function(a, b) return a.perHour > b.perHour end)
    Combo.last = { opts = opts, results = out, gather = gather, time = time() }
    return out
end
