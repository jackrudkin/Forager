-- Finder: ranks zones and sub-areas for a goal by gold/hour or skill-ups/hour.
-- All numbers are estimates; see README "How numbers are calculated".
local _, ns = ...
local Finder = {}
ns.Finder = Finder
local DS, P = ns.DS, ns.Player

local GRID = 20

-------------------------------------------------------------------------------
-- value functions
-------------------------------------------------------------------------------
local function price(id) return (ns.Prices:Get(id)) end

--- Value (copper) of one gather of a node type and the main items it gives.
function Finder:NodeValue(t)
    local v = 0
    if t.yields and #t.yields > 0 then
        for _, y in ipairs(t.yields) do v = v + price(y[1]) * y[2] end
    elseif t.item and t.item > 0 then
        v = price(t.item) * 1.5
    end
    return v * (t.taps or 1)
end

local CAT_FOR_GOAL = { cloth = "cloth", meat = "meat", elemental = "elemental", lockbox = "lockbox" }

--- Expected copper per kill for a goal, plus a short list of the items that make it up.
function Finder:MobValue(m, goal, skills, level)
    local v, parts = 0, {}
    local function add(id, p, mult)
        local c = price(id) * p * (mult or 1)
        v = v + c
        parts[#parts + 1] = { id = id, p = p, value = c }
    end
    local cat = CAT_FOR_GOAL[goal]
    if cat == "lockbox" then
        for _, e in ipairs(m.pickpocket) do add(e[1], e[2]) end
    elseif cat then
        for _, e in ipairs(m.farm) do if DS:ItemCategory(e[1]) == cat then add(e[1], e[2], 1.2) end end
    end
    if goal == "skin" or goal == "leather" or (goal == "gold" and skills.skin) then
        local need = ns.SkinSkillForLevel(m.maxLevel)
        local have = skills.skin or (goal ~= "gold" and 300) or 0
        if m.skinnable and have >= need then
            for _, e in ipairs(m.skin) do add(e[1], e[2]) end
        end
    end
    if goal == "greens" or goal == "gold" then
        if m.green and m.green > 0 then
            local dv = ns.Prices:DisenchantValue(m.greenIlvl or m.maxLevel, 2)
            v = v + m.green * dv
            parts[#parts + 1] = { greens = true, p = m.green, value = m.green * dv }
        end
        if m.blue and m.blue > 0 then
            local bv = ns.Prices:DisenchantValue(m.greenIlvl or m.maxLevel, 3)
            v = v + m.blue * bv
        end
    end
    if goal == "gold" then
        for _, e in ipairs(m.farm) do add(e[1], e[2]) end
        v = v + (m.copper or 0)
    end
    return v, parts
end

--- Skill-ups per action for a goal (skinning: per skin; lockbox: per box).
local function mobSkillUp(m, goal, skills)
    if goal == "skin" or goal == "leather" then
        if not m.skinnable then return 0 end
        local col = ns.SkillColor(ns.SkinSkillForLevel(m.maxLevel), skills.skin or 1)
        return ns.SkillUpChance[col] or 0
    elseif goal == "lockbox" then
        local s = 0
        for _, e in ipairs(m.pickpocket) do
            local req = ns.Junkboxes[e[1]]
            if req then s = s + e[2] * (ns.SkillUpChance[ns.SkillColor(req, skills.lock or 1)] or 0) end
        end
        return s
    end
    return 0
end

local function levelFactor(m, level, showDangerous)
    local avg = (m.minLevel + m.maxLevel) / 2
    local d = avg - level
    if m.rank and m.rank > 0 then
        if not showDangerous then return 0 end
        return 0.3
    end
    if d > 3 then return showDangerous and 0.4 or 0 end
    if d > 1 then return 0.8 end
    if d < -10 then return 1.5 end
    if d < -4 then return 1.25 end
    return 1.0
end

-------------------------------------------------------------------------------
-- grid + window search
-------------------------------------------------------------------------------
local function newGrid()
    local g = {}
    for i = 0, GRID * GRID - 1 do g[i] = 0 end
    return g
end
local function cellOf(x, y)
    local cx = math.min(GRID - 1, math.max(0, math.floor(x * GRID)))
    local cy = math.min(GRID - 1, math.max(0, math.floor(y * GRID)))
    return cx, cy
end

--- Best W x W window by summed value. Returns cx0, cy0, sum.
local function bestWindow(grid, W, exclude)
    local best, bx, by = -1, 0, 0
    for cy = 0, GRID - W do
        for cx = 0, GRID - W do
            local s = 0
            for yy = cy, cy + W - 1 do
                local row = yy * GRID
                for xx = cx, cx + W - 1 do s = s + grid[row + xx] end
            end
            if exclude then
                for _, e in ipairs(exclude) do
                    if not (cx + W <= e[1] or e[1] + W <= cx or cy + W <= e[2] or e[2] + W <= cy) then s = -1 break end
                end
            end
            if s > best then best, bx, by = s, cx, cy end
        end
    end
    return bx, by, best
end

local function windowSize(uiMap)
    local w = P:ZoneSize(uiMap)
    local cellYards = w / GRID
    return ns.Clamp(math.floor(800 / cellYards + 0.5), 3, 9)
end

-------------------------------------------------------------------------------
-- per-zone evaluation
-------------------------------------------------------------------------------
local function riskFor(zone, faction)
    if zone.faction == "S" then return "Sanctuary", 0 end
    if zone.faction == "C" then return "Contested", 1 end
    if zone.faction == faction then return "Friendly", 0 end
    return "Enemy territory", 2
end

local function zoneCandidates(opts)
    local list = {}
    if opts.zones then
        for _, z in ipairs(opts.zones) do if z and ns.Zones[z] then list[#list + 1] = z end end
        return list
    end
    for id, z in pairs(ns.Zones) do
        local tooHigh = z.min > (opts.level or 1) + 5 and not ns.settings.showDangerous
        if z.faction ~= "S" and not tooHigh and (opts.includeEnemy or z.faction == "C" or z.faction == opts.faction) then
            list[#list + 1] = id
        end
    end
    return list
end

local function evalNodes(uiMap, goal, opts, out)
    local s = ns.settings
    local have = opts.skills[goal.prof]
    local grid = newGrid()
    local cellPts = {}
    local typesSeen, minSkill = {}, nil
    for _, pt in ipairs(DS:GetZoneNodes(uiMap)) do
        local t = DS:GetType(pt.t)
        if t and t.kind == goal.prof then
            local col = ns.SkillColor(t.skill or 0, have or 300)
            local w
            if opts.mode == "skill" then
                w = ns.SkillUpChance[col] or 0
            elseif col ~= "red" then
                w = Finder:NodeValue(t)
            end
            if w and w > 0 then
                local cx, cy = cellOf(pt.x, pt.y)
                local idx = cy * GRID + cx
                grid[idx] = grid[idx] + w
                cellPts[idx] = cellPts[idx] or {}
                table.insert(cellPts[idx], { x = pt.x, y = pt.y, w = w, t = pt.t })
                typesSeen[pt.t] = (typesSeen[pt.t] or 0) + 1
                minSkill = math.min(minSkill or 999, t.skill or 0)
            end
        end
    end
    if not minSkill then return end
    local W = windowSize(uiMap)
    local picked = {}
    for rank = 1, opts.perZone or 1 do
        local cx, cy, sum = bestWindow(grid, W, picked)
        if sum <= 0 then break end
        picked[#picked + 1] = { cx, cy }
        local pts, wsum = {}, 0
        for yy = cy, cy + W - 1 do
            for xx = cx, cx + W - 1 do
                for _, p in ipairs(cellPts[yy * GRID + xx] or {}) do pts[#pts + 1] = p wsum = wsum + p.w end
            end
        end
        local n = #pts
        local route = ns.Route:Build(uiMap, pts, 40)
        local speed = P:Speed()
        local active = n * s.activeFraction
        local loopSec = route.length / speed + active * s.gatherSeconds
        local loopsPerHour = 3600 / math.max(60, loopSec)
        local perNode = wsum / n
        local perHour = active * perNode * loopsPerHour
        local mix = {}
        for tk, c in pairs(typesSeen) do mix[#mix + 1] = { t = tk, n = c } end
        table.sort(mix, function(a, b) return a.n > b.n end)
        local areaKm = (W / GRID) ^ 2
        out[#out + 1] = {
            uiMap = uiMap, goal = goal.key, mode = opts.mode, rank = rank,
            rect = { cx / GRID, cy / GRID, (cx + W) / GRID, (cy + W) / GRID },
            points = pts, route = route, perHour = perHour, loopSec = loopSec, unitsPerHour = active * loopsPerHour,
            count = n, minSkill = minSkill, mix = mix, density = n / areaKm,
            why = string.format("%d spawn points (%d on route), ~%.0f live nodes/loop, loop %s", n, #route.points, active,
                SecondsToTime and SecondsToTime(loopSec) or (math.floor(loopSec) .. "s")),
            confidence = "Classic spawns",
        }
    end
end

local function evalMobs(uiMap, goal, opts, out)
    local s = ns.settings
    local grid = newGrid()
    local cellPts = {}
    local mobsSeen = {}
    local minL, maxL, minSkill = 99, 0, nil
    local needsSkill = goal.prof == "skin" or goal.key == "leather"
    for npcID, pts in pairs(DS:GetZoneMobs(uiMap)) do
        local m = DS:GetMob(npcID)
        if m then
            local lf = levelFactor(m, opts.level, s.showDangerous)
            local w
            if lf > 0 then
                if opts.mode == "skill" and (needsSkill or goal.key == "lockbox") then
                    w = mobSkillUp(m, goal.key, opts.skills)
                else
                    w = Finder:MobValue(m, goal.key, opts.skills, opts.level)
                end
                w = w * lf
            end
            if w and w > 0 then
                local spawnCount = #pts / 2
                mobsSeen[npcID] = { m = m, n = spawnCount, w = w }
                minL, maxL = math.min(minL, m.minLevel), math.max(maxL, m.maxLevel)
                if needsSkill then minSkill = math.min(minSkill or 999, ns.SkinSkillForLevel(m.maxLevel)) end
                for i = 1, #pts, 2 do
                    local cx, cy = cellOf(pts[i], pts[i + 1])
                    local idx = cy * GRID + cx
                    grid[idx] = grid[idx] + w
                    cellPts[idx] = cellPts[idx] or {}
                    table.insert(cellPts[idx], { x = pts[i], y = pts[i + 1], w = w, npc = npcID })
                end
            end
        end
    end
    if maxL == 0 then return end
    local W = windowSize(uiMap)
    local picked = {}
    local qnames = opts.questNames or {}
    for rank = 1, opts.perZone or 1 do
        local cx, cy, sum = bestWindow(grid, W, picked)
        if sum <= 0 then break end
        picked[#picked + 1] = { cx, cy }
        local pts, wsum, perMob = {}, 0, {}
        for yy = cy, cy + W - 1 do
            for xx = cx, cx + W - 1 do
                for _, p in ipairs(cellPts[yy * GRID + xx] or {}) do
                    pts[#pts + 1] = p
                    wsum = wsum + p.w
                    perMob[p.npc] = (perMob[p.npc] or 0) + 1
                end
            end
        end
        local n = #pts
        local density = math.min(1, n / 25)
        local perKill = wsum / n
        local kph = s.killsPerHour * density
        local mobs, questOverlap = {}, {}
        for npc, c in pairs(perMob) do
            local mm = mobsSeen[npc].m
            mobs[#mobs + 1] = { npc = npc, n = c, m = mm }
            local q = qnames[mm.name:lower()]
            if q then questOverlap[#questOverlap + 1] = mm.name end
        end
        table.sort(mobs, function(a, b) return a.n > b.n end)
        local route = ns.Route:Build(uiMap, ns.Route:Clusters(pts, 14), 14)
        out[#out + 1] = {
            uiMap = uiMap, goal = goal.key, mode = opts.mode, rank = rank,
            rect = { cx / GRID, cy / GRID, (cx + W) / GRID, (cy + W) / GRID },
            points = pts, route = route, perHour = perKill * kph, unitsPerHour = kph, perUnit = perKill,
            count = n, mobs = mobs, minLevel = minL, maxLevel = maxL, minSkill = minSkill,
            questOverlap = questOverlap, loopSec = route.length / P:Speed(),
            why = string.format("%d mob spawns, %d types, ~%.0f kills/h, %s per kill", n, #mobs, kph,
                opts.mode == "skill" and string.format("%.2f skill-ups", perKill) or ns.Money(perKill)),
            confidence = "Classic estimate",
        }
    end
end

local function evalFish(uiMap, goal, opts, out)
    local f = ForagerData and ForagerData.fishing and ForagerData.fishing[uiMap]
    if not f then return end
    local s = ns.settings
    local zoneSkill = f[1] or 0
    local have = opts.skills.fish or 0
    local catch = have >= zoneSkill and 1 or math.max(0.1, (have / math.max(1, zoneSkill)) ^ 2)
    local v = 0
    local items = {}
    for i = 2, #f do
        v = v + price(f[i][1]) * f[i][2]
        items[#items + 1] = { id = f[i][1], p = f[i][2] }
    end
    local own = ns.db.fish[uiMap]
    if own and own.casts >= s.minSamples then
        v = 0
        wipe(items)
        for id, q in pairs(own.items) do
            v = v + price(id) * q / own.casts
            items[#items + 1] = { id = id, p = q / own.casts }
        end
    end
    local perHour
    if opts.mode == "skill" then
        local chance = ns.Clamp((300 - have) / 300 + 0.05, 0.05, 1) * 0.6
        perHour = s.castsPerHour * catch * chance
    else
        perHour = s.castsPerHour * catch * v
    end
    if perHour <= 0 then return end
    out[#out + 1] = {
        uiMap = uiMap, goal = "fish", mode = opts.mode, rank = 1, rect = nil, points = {}, route = { points = {}, length = 0 },
        perHour = perHour, unitsPerHour = s.castsPerHour * catch, perUnit = v, minSkill = zoneSkill, fishItems = items,
        why = string.format("zone fishing skill %d, ~%d catches/h", zoneSkill, s.castsPerHour * catch),
        confidence = (own and own.casts >= s.minSamples) and ("My data (n=" .. own.casts .. ")") or "Classic estimate",
    }
end

-------------------------------------------------------------------------------
-- public
-------------------------------------------------------------------------------
--- opts: goal, mode, zones (optional list), level, faction, skills, perZone, questing (bool)
function Finder:Run(opts)
    DS:Load()
    opts = opts or {}
    local goal = ns.GoalByKey[opts.goal or "herb"]
    opts.mode = opts.mode or ns.settings.mode
    opts.level = opts.level or P:Level()
    opts.faction = opts.faction or P:Faction()
    opts.skills = opts.skills or {}
    if not next(opts.skills) then
        for k, v in pairs(P.skills) do opts.skills[k] = v.rank end
    end
    if opts.mode == "skill" and not (goal.kind == "node" or goal.kind == "fish" or goal.key == "skin" or goal.key == "leather" or goal.key == "lockbox") then
        opts.mode = "gold"
    end
    local out = {}
    for _, uiMap in ipairs(zoneCandidates(opts)) do
        local zone = ns.Zones[uiMap]
        local before = #out
        if goal.kind == "node" then evalNodes(uiMap, goal, opts, out)
        elseif goal.kind == "mob" then evalMobs(uiMap, goal, opts, out)
        elseif goal.kind == "fish" then evalFish(uiMap, goal, opts, out) end
        for i = before + 1, #out do
            local r = out[i]
            r.zoneName = zone.name
            r.zoneMin, r.zoneMax = zone.min, zone.max
            r.risk, r.riskLevel = riskFor(zone, opts.faction)
        end
    end
    if opts.questing then Finder:ApplyQuesting(out, opts) end
    table.sort(out, function(a, b) return (a.score or a.perHour) > (b.score or b.perHour) end)
    Finder.last = { opts = opts, results = out, goal = goal, time = time() }
    ns:Fire("FORAGER_FINDER_UPDATED")
    return out
end

--- Questing-zone mode: score = rate including the detour from the nearest quest POI.
function Finder:ApplyQuesting(results, opts)
    local speed = P:Speed()
    local poisByMap = {}
    for _, r in ipairs(results) do
        poisByMap[r.uiMap] = poisByMap[r.uiMap] or ns.Quests:POIs(r.uiMap)
        local pois = poisByMap[r.uiMap]
        if r.rect then
            local cx, cy = (r.rect[1] + r.rect[3]) / 2, (r.rect[2] + r.rect[4]) / 2
            local best
            for _, poi in ipairs(pois) do
                local d = P:Distance(r.uiMap, cx, cy, poi.x, poi.y)
                if not best or d < best then best = d end
            end
            r.poiCount = 0
            for _, poi in ipairs(pois) do
                if poi.x >= r.rect[1] and poi.x <= r.rect[3] and poi.y >= r.rect[2] and poi.y <= r.rect[4] then r.poiCount = r.poiCount + 1 end
            end
            best = best or 0
            local travel = 2 * best / speed
            local loop = math.max(60, r.loopSec or 600)
            r.detourMin = (travel + loop) / 60
            r.travelMin = travel / 60
            r.score = r.perHour * loop / (loop + travel)
            r.noPOIs = #pois == 0
        else
            r.score = r.perHour
        end
    end
end

--- One-click: best spot for the current character, including questing zone if set.
function Finder:Best(goalKey, mode)
    local opts = { goal = goalKey, mode = mode, perZone = 2 }
    if ns.Quests:IsActive() then
        local z1, z2 = ns.Quests:Zones()
        opts.zones = { z1, z2 }
        opts.questing = true
        opts.questNames = ns.Quests:ObjectiveNames()
    end
    local res = Finder:Run(opts)
    return res[1], res
end

--- Suggested goal from professions (first gathering profession found).
function Finder:DefaultGoal()
    if ns.char.goal then return ns.char.goal end
    if P.skills.herb then return "herb" end
    if P.skills.ore then return "ore" end
    if P.skills.skin then return "skin" end
    return "cloth"
end
