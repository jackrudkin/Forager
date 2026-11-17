-- Combo: gather + kill (+ skin). Ranks areas where you mine and/or pick herbs AND kill (and skin) the
-- mobs along the way, with time as the shared budget, so the incomes are not simply added up.
--
-- Model, per loop of the route:
--   walk   = route length / speed
--   gather = live nodes near the route x seconds per gather
--   fight  = mobs killed x (seconds per kill + seconds per skin if you skin it), faster for lower levels
--   rate   = (node value + mob value) x 3600 / (walk + gather + fight)
-- "Value" is gold (Gold / hour) or skill-up chance (Skill-ups / hour: gathering + skinning together).
-- Skinning: a mob's skins count only if your Skinning is high enough for it (Forever formula), cost
-- extra seconds, and are reported separately from the rest of its loot.
-- Which mobs to kill: a mob type is worth it only when its value per second of fighting beats the
-- loop's current value per second. Taking types in order of value per fighting second while that holds
-- gives the best possible total (the classic best-ratio rule). Mobs you killed are only back after
-- their respawn time, so a short loop finds fewer of them; this is solved by iterating.
-- Two routes are tried per area: through the nodes only, and through the nodes plus the best camps
-- of worthwhile mobs that the node route misses. The better one wins.
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

function Combo:Mode() return ns.settings.comboMode == "skill" and "skill" or "gold" end
function Combo:KillFor() return ns.settings.comboKill == "skin" and "skin" or "all" end

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
--- route: built route; nodes/mobs: points in the area; info: per-npc values; ctx: settings.
--- Nodes carry v (ranked value), g (gold), su (skill-ups); mob types carry v, loot, skinG, su, killT.
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
    -- nodes you pass (on the route or within reach of it)
    local nodeOn, nodeV, nodeG, nodeSU, byType, gatherT = {}, 0, 0, 0, {}, 0
    for _, p in ipairs(nodes) do
        if near(p) then
            nodeOn[#nodeOn + 1] = p
            local a = p.a -- chance the spawn point holds a live node
            nodeV = nodeV + p.v * a
            nodeG = nodeG + p.g * a
            nodeSU = nodeSU + p.su * a
            gatherT = gatherT + p.secs * a
            byType[p.t] = (byType[p.t] or 0) + a
        end
    end
    local liveNodes = 0
    for _, a in pairs(byType) do liveNodes = liveNodes + a end
    local walk = route.length / ctx.speed
    local gather = gatherT
    -- mobs you pass, per type
    local types, mobOn = {}, {}
    for _, p in ipairs(mobs) do
        if near(p) then
            local e = types[p.npc]
            if not e then
                local inf = info[p.npc]
                e = { npc = p.npc, inf = inf, m = inf.m, v = inf.v, c = 0, killT = inf.killT, rate = inf.v / inf.killT,
                    resp = math.max(30, DS:MobRespawn(inf.m, ctx.respawn)) }
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
    local base = walk + gather
    local T, I, chosen, avail = base, nodeV, {}, 1
    for _ = 1, 5 do
        local Tn, In, ac, an = base, nodeV, 0, 0
        chosen = {}
        for _, e in ipairs(order) do
            local av = math.min(1, T / e.resp) -- share of this type that has respawned since the last loop
            ac, an = ac + e.c * av, an + e.c
            if e.rate > 0 and (Tn <= 0 or e.rate > In / Tn) then
                local a = e.c * av
                Tn, In = Tn + a * e.killT, In + a * e.v
                chosen[e.npc] = a
            end
        end
        avail = an > 0 and ac / an or 1
        T, I = Tn, In
    end
    if T <= 0 then return nil end
    local kills, loot, skinG, skinSU, skins = 0, 0, 0, 0, 0
    for _, e in ipairs(order) do
        local a = chosen[e.npc]
        if a then
            kills = kills + a
            loot = loot + a * e.inf.loot
            skinG = skinG + a * e.inf.skinG
            skinSU = skinSU + a * e.inf.su
            if e.inf.skinOK then skins = skins + a end
        end
    end
    local k = 3600 / T
    return {
        route = route, perHour = I * k,
        nodeRate = nodeV * k, mobRate = (I - nodeV) * k,
        nodeGold = nodeG * k, skinGold = skinG * k, lootGold = loot * k, gold = (nodeG + skinG + loot) * k,
        nodeSU = nodeSU * k, skinSU = skinSU * k, skillups = (nodeSU + skinSU) * k,
        nodesOnlyRate = base > 0 and nodeV * 3600 / base or 0,
        loopSec = T, walk = walk, gather = gather, fight = math.max(0, T - base), avail = avail,
        liveNodes = liveNodes, kills = kills, skins = skins, nodeOn = nodeOn, mobOn = mobOn, byType = byType,
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
local function topWindows(grid, W, k)
    local out, blocked = {}, {}
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

--- Items per hour for a result: node yields + drops (and skins) of the mobs you kill.
local function itemsPerHour(r, sim, info, level)
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
        for _, y in ipairs(t and ns.Learn:NodeInfo(t).perNode or {}) do
            local q = c * y[2] * loops -- c = live nodes of the type per loop
            add(y[1], { id = y[1], node = true }, q, q * priceOf(y[1]))
        end
    end
    for npc, a in pairs(sim.chosen) do
        local inf = info[npc]
        local _, parts = ns.Finder:MobValue(inf.m, "gold", inf.lootSkills, level)
        for _, pa in ipairs(parts) do
            local key = pa.id or (pa.greens and ("greens" .. pa.greens)) or "coin"
            add(key, { id = pa.id, greens = pa.greens, coin = pa.coin }, pa.p * a * loops, pa.value * a * loops)
        end
        if inf.skinOK then
            for _, e in ipairs(inf.m.skin) do
                add(e[1], { id = e[1], skin = true }, e[2] * a * loops, e[2] * priceOf(e[1]) * a * loops)
            end
        end
    end
    local list = {}
    for _, e in pairs(items) do list[#list + 1] = e end
    table.sort(list, function(a, b) return a.value > b.value or (a.value == b.value and a.perHour > b.perHour) end)
    return list
end

--- Per-mob-type values for this character: loot (without skins), skins, skinning skill-ups, time per kill.
local function mobInfo(m, lf, ctx, skills, lootSkills, level)
    local loot = ns.Finder:MobValue(m, "gold", lootSkills, level)
    local req = m.skinnable and ns.SkinSkillForLevel(m.maxLevel) or nil
    local have = skills.skin
    local skinOK = req ~= nil and have ~= nil and have >= req
    local skinG, su, col = 0, 0, nil
    if skinOK then
        for _, e in ipairs(m.skin) do skinG = skinG + e[2] * priceOf(e[1]) end
        col = ns.SkillColor(req, have, "skin")
        su = ns.SkillUpChance[col] or 0
    elseif req and have then
        col = "red"
    end
    if ctx.killFor == "skin" and not skinOK then return nil end
    local killT = (ctx.killSec + (skinOK and ctx.skinSec or 0) + ctx.pull / 2 / ctx.speed) / lf
    local v = ctx.mode == "skill" and su or (loot + skinG)
    if v <= 0 then return nil end
    return { m = m, lf = lf, v = v, loot = loot, skinG = skinG, su = su, skinOK = skinOK, req = req, col = col,
        killT = killT, lootSkills = lootSkills }
end
Combo.MobInfo = mobInfo

local function evalZone(uiMap, gather, opts, ctx, out)
    local kinds = Combo.KINDS[gather]
    local skills, level, loc = opts.skills, opts.level, opts.location
    local lootSkills = {}
    for k, v in pairs(skills) do if k ~= "skin" then lootSkills[k] = v end end
    -- Realistic: skip ground near mobs that are too hard (orange/red/elite) or enemy settlements
    local unsafe = opts.realistic and ns.Risk:UnsafeCells(uiMap, GRID, level) or nil
    local function safe(x, y)
        if not unsafe then return true end
        local cx = math.min(GRID - 1, math.max(0, math.floor(x * GRID)))
        local cy = math.min(GRID - 1, math.max(0, math.floor(y * GRID)))
        return not unsafe[cy * GRID + cx]
    end
    -- nodes you can gather, valued per visit
    local nodes, minSkill = {}, nil
    for _, pt in ipairs(DS:GetZoneNodes(uiMap)) do
        local t = DS:GetType(pt.t)
        if t and kinds[t.kind] and safe(pt.x, pt.y) and allowed(loc, uiMap, pt.x, pt.y) then
            local have = skills[t.kind]
            local col = have and ns.NodeSkillColor(t, have)
            if col and col ~= "red" then
                local info = ns.Learn:NodeInfo(t)
                local g = ns.Finder:NodeValue(t)
                local su = (ns.SkillUpChance[col] or 0) * info.taps
                local v = ctx.mode == "skill" and su or g
                if v > 0 then
                    local a = DS:LiveShare(t, uiMap)
                    nodes[#nodes + 1] = { x = pt.x, y = pt.y, t = pt.t, v = v, g = g, su = su, secs = info.secs, a = a, w = v * a }
                    minSkill = math.min(minSkill or 999, t.skill or 0)
                end
            end
        end
    end
    if #nodes < 3 then return end
    -- mobs you can kill (and skin)
    local info, mobs = {}, {}
    for npc, flat in pairs(DS:GetZoneMobs(uiMap)) do
        local m = DS:GetMob(npc)
        if m and not DS:IsFriendly(m) and not (opts.realistic and ns.Risk.TooHard(m, level)) then
            local lf = ns.Finder.LevelFactor(m, level, ns.settings.showDangerous)
            if lf > 0 then
                local inf = mobInfo(m, lf, ctx, skills, lootSkills, level)
                if inf then
                    info[npc] = inf
                    for i = 1, #flat, 2 do
                        if safe(flat[i], flat[i + 1]) and allowed(loc, uiMap, flat[i], flat[i + 1]) then
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
    local avgSecs, avgA = 0, 0
    for _, p in ipairs(nodes) do avgSecs, avgA = avgSecs + p.secs / #nodes, avgA + p.a / #nodes end
    for _, p in ipairs(nodes) do
        local cx, cy = cell(p.x, p.y)
        gNodes[cy * GRID + cx] = gNodes[cy * GRID + cx] + p.w
        gBoth[cy * GRID + cx] = gBoth[cy * GRID + cx] + p.w
    end
    for _, p in ipairs(mobs) do
        local cx, cy = cell(p.x, p.y)
        local inf = info[p.npc]
        -- a kill costs killT; weigh it like the same time spent gathering
        gBoth[cy * GRID + cx] = gBoth[cy * GRID + cx] + inf.v * avgSecs / inf.killT * avgA
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
            local simA = simulate(uiMap, ns.Route:Build(uiMap, an, 40), an, am, info, ctx)
            local best = simA
            -- variant B: add the best camps of worthwhile mobs that the node route misses
            if simA and #am > 0 then
                local bar = simA.perHour / 3600
                local campPts = {}
                for _, p in ipairs(am) do
                    local inf = info[p.npc]
                    if inf.v / inf.killT > bar then campPts[#campPts + 1] = { x = p.x, y = p.y, w = inf.v } end
                end
                if #campPts > 0 then
                    local pts = {}
                    for _, p in ipairs(an) do pts[#pts + 1] = p end
                    local added = 0
                    for _, cp in ipairs(ns.Route:Clusters(campPts, 6)) do
                        if cp.n >= 2 and added < 3 then
                            pts[#pts + 1] = { x = cp.x, y = cp.y, w = cp.w * simA.avail, n = cp.n, camp = true }
                            added = added + 1
                        end
                    end
                    if added > 0 then
                        local simB = simulate(uiMap, ns.Route:Build(uiMap, pts, 44), an, am, info, ctx)
                        if simB and simB.perHour > best.perHour then best = simB end
                    end
                end
            end
            if best then
                best.rect = { x1, y1, x2, y2 }
                if opts.realistic then
                    -- assess risk on the ground the loop actually covers
                    local bx1, by1, bx2, by2 = 1, 1, 0, 0
                    for _, p in ipairs(best.route and best.route.points or an) do
                        bx1, by1 = math.min(bx1, p.x), math.min(by1, p.y)
                        bx2, by2 = math.max(bx2, p.x), math.max(by2, p.y)
                    end
                    if bx2 > bx1 then best.rect = { math.max(x1, bx1 - 0.015), math.max(y1, by1 - 0.015), math.min(x2, bx2 + 0.015), math.min(y2, by2 + 0.015) } end
                end
                best.cell = c
                best.nodesOnlyRate = simA.nodesOnlyRate
                best.areaMobs = am
                evaluated[#evaluated + 1] = best
            end
        end
    end
    table.sort(evaluated, function(a, b) return a.perHour > b.perHour end)
    -- keep up to 2 non-overlapping areas per zone (Realistic: only areas that pass the check)
    local kept = {}
    for _, e in ipairs(evaluated) do
        local overlap = false
        for _, k in ipairs(kept) do
            if not (e.cell[1] + W <= k.cell[1] or k.cell[1] + W <= e.cell[1] or e.cell[2] + W <= k.cell[2] or k.cell[2] + W <= e.cell[2]) then overlap = true end
        end
        if not overlap and opts.realistic then
            local probe = { uiMap = uiMap, rect = e.rect, points = e.nodeOn }
            ns.Finder.NameArea(probe)
            ns.Risk:Assess(probe)
            local ok, why = ns.Risk:RealisticCheck(probe)
            if not ok then
                overlap = true
                ns.Risk.AddHidden(ctx.hidden, why)
            end
        end
        if not overlap then kept[#kept + 1] = e end
        if #kept >= (opts.perZone or 2) then break end
    end
    local zone = ns.Zones[uiMap]
    for rank, sim in ipairs(kept) do
        -- dedicated mob farming (or skinning) in the same area, the Finder's way, for comparison
        local mobsOnly, nm = 0, 0
        for _, p in ipairs(sim.areaMobs) do
            local inf = info[p.npc]
            local up = math.min(1, 300 / math.max(30, DS:MobRespawn(inf.m, 300)))
            mobsOnly, nm = mobsOnly + inf.v * inf.lf * up, nm + up
        end
        if nm > 0 then mobsOnly = mobsOnly / nm * ns.Learn:KillsPerHour() * math.min(1, nm / 25) end
        local mobsList, worthy, skipped, minL, maxL, minSkin = {}, {}, {}, 99, 0, nil
        for _, e in ipairs(sim.types) do
            local a = sim.chosen[e.npc]
            local inf = e.inf
            local row = { npc = e.npc, m = e.m, n = e.c, perKill = inf.loot + inf.skinG, loot = inf.loot, skinG = inf.skinG,
                su = inf.su, skinOK = inf.skinOK, req = inf.req, col = inf.col, killT = e.killT,
                perMin = e.rate * 60, kills = a and a * 3600 / sim.loopSec or 0 }
            if a then
                worthy[#worthy + 1] = row
                mobsList[#mobsList + 1] = row
                minL, maxL = math.min(minL, e.m.minLevel), math.max(maxL, e.m.maxLevel)
                if inf.skinOK then minSkin = math.min(minSkin or 999, inf.req) end
            else
                skipped[#skipped + 1] = row
            end
        end
        local pts = {}
        for _, p in ipairs(sim.nodeOn) do pts[#pts + 1] = p end
        for _, p in ipairs(sim.mobOn) do if sim.chosen[p.npc] then pts[#pts + 1] = p end end
        local k = 3600 / sim.loopSec
        local r = {
            uiMap = uiMap, goal = "combo:" .. gather .. (ctx.killFor == "skin" and ":skin" or ""), mode = ctx.mode,
            killFor = ctx.killFor, gather = gather, rank = rank, source = "combo",
            rect = sim.rect, points = pts, route = sim.route, perHour = sim.perHour,
            nodeRate = sim.nodeRate, mobRate = sim.mobRate, nodesOnlyRate = sim.nodesOnlyRate, mobsOnlyRate = mobsOnly,
            nodeGold = sim.nodeGold, skinGold = sim.skinGold, lootGold = sim.lootGold, gold = sim.gold,
            nodeSU = sim.nodeSU, skinSU = sim.skinSU, skillups = sim.skillups,
            loopSec = sim.loopSec, walkSec = sim.walk, gatherSec = sim.gather, fightSec = sim.fight,
            nodesPerHour = sim.liveNodes * k, killsPerHour = sim.kills * k, skinsPerHour = sim.skins * k,
            unitsPerHour = sim.kills * k, unitLabel = "kills/h",
            mobs = mobsList, worthy = worthy, skipped = skipped, minSkill = minSkill, minSkin = minSkin,
            minLevel = maxL > 0 and minL or nil, maxLevel = maxL > 0 and maxL or nil,
            active = #sim.nodeOn > 0 and sim.liveNodes / #sim.nodeOn or 0,
            zoneName = DS:ZoneName(uiMap), zoneMin = zone.min, zoneMax = zone.max, note = ns.HotfixNotes[uiMap], confidence = ns.Finder.YieldSource(sim.byType),
            assumedSkin = ctx.assumedSkin,
        }
        r.items = itemsPerHour(r, sim, info, level)
        r.why = string.format("%d nodes and %d mobs near the route; a mob is killed only when it pays more per second than gathering",
            #sim.nodeOn, #sim.mobOn)
        r.risk, r.riskLevel = ns.Finder.RiskFor(zone, opts.faction)
        ns.Finder.NameArea(r)
        ns.Risk:Assess(r)
        out[#out + 1] = r
    end
end

-------------------------------------------------------------------------------
-- public
-------------------------------------------------------------------------------
--- opts: gather ("ore"|"herb"|"both"), mode ("gold"|"skill"), killFor ("all"|"skin"), zones, location,
--- includeEnemy, perZone, skills
local cache = {}
function Combo:FlushCache() wipe(cache) end

function Combo:Run(opts)
    opts = opts or {}
    local key = ns.OptsKey(opts, "combo")
    for i, c in ipairs(cache) do
        if c.key == key then
            table.insert(cache, 1, table.remove(cache, i))
            Combo.last = c.last
            return c.results
        end
    end
    local out = Combo:Search(opts)
    table.insert(cache, 1, { key = key, results = out, last = Combo.last })
    while #cache > 3 do table.remove(cache) end
    return out
end

function Combo:Search(opts)
    DS:Load()
    local gather = opts.gather or Combo:DefaultGather()
    local s = ns.settings
    opts.level = opts.level or P:Level()
    opts.faction = opts.faction or P:Faction()
    opts.location = opts.location or s.location or "any"
    opts.skills = opts.skills or {}
    if not next(opts.skills) then for k, v in pairs(P.skills) do opts.skills[k] = v.rank end end
    -- a profession you don't have: assume enough skill to see the spots (like the Finder does)
    for k in pairs(Combo.KINDS[gather]) do opts.skills[k] = opts.skills[k] or 300 end
    local killFor = opts.killFor or Combo:KillFor()
    local assumedSkin = false
    if killFor == "skin" and not opts.skills.skin then opts.skills.skin, assumedSkin = 300, true end
    if opts.includeEnemy == nil then opts.includeEnemy = s.includeEnemy end
    if opts.realistic == nil then opts.realistic = s.realistic and true or false end
    if not opts.zones and ns.Quests:IsActive() then
        local z1, z2 = ns.Quests:Zones()
        opts.zones = { z1, z2 }
    end
    -- skinning time: your measured cast + loot once Forager has 10 skins, else the slider
    local skinCast, skinSrc = ns.Learn:CastSeconds("skin")
    local skinSec = (skinSrc == "me") and (skinCast + (ns.Learn:LootSeconds("skin"))) or s.comboSkinSeconds
    local ctx = {
        speed = P:Speed(),
        killSec = ns.Learn:KillSeconds(), skinSec = skinSec, skinMeasured = skinSrc == "me", pull = s.comboPullYards,
        respawn = math.max(30, s.comboRespawn), mode = opts.mode or Combo:Mode(), killFor = killFor, assumedSkin = assumedSkin,
        hidden = opts.realistic and { n = 0, reasons = {} } or nil,
    }
    local out = {}
    local cands = ns.Finder.ZoneCandidates(opts)
    for ci, uiMap in ipairs(cands) do
        ns.Async.progress = ci / #cands
        local ok, err = pcall(evalZone, uiMap, gather, opts, ctx, out)
        if not ok then ns:Error("combo " .. uiMap, err) end
        ns.Yield()
    end
    ns.Net:ApplyAll(out)
    table.sort(out, function(a, b) return a.perHour > b.perHour end)
    out = ns.Risk:Filter(out)
    local hidden = ctx.hidden
    if opts.realistic then out, hidden = ns.Risk:Realistic(out, hidden) end
    Combo.last = { opts = opts, results = out, gather = gather, mode = ctx.mode, killFor = killFor, time = time(), hidden = hidden }
    return out
end
