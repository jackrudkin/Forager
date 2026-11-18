-- Finder: ranks zones and sub-areas for a goal (profession, material category or any item)
-- by gold/hour or skill-ups/hour, optionally only in caves or only outdoors.
-- All numbers are estimates; see README "How the numbers are calculated".
local _, ns = ...
local Finder = {}
ns.Finder = Finder
local DS, P = ns.DS, ns.Player

local GRID = 20

-------------------------------------------------------------------------------
-- goals (static categories + dynamic "item:<id>")
-------------------------------------------------------------------------------
local COMBO = {
    ["combo:ore"] = { label = "Mining + mobs", short = "Mining + mobs", icon = "Interface\\Icons\\Trade_Mining", gather = "ore" },
    ["combo:herb"] = { label = "Herbs + mobs", short = "Herbs + mobs", icon = "Interface\\Icons\\Trade_Herbalism", gather = "herb" },
    ["combo:both"] = { label = "Herbs, ore + mobs", short = "Herbs, ore + mobs", icon = "Interface\\Icons\\INV_Pick_02", gather = "both" },
}
COMBO["combo:ore:skin"] = { label = "Mining + skinning", short = "Mining + skinning", icon = "Interface\\Icons\\INV_Misc_Pelt_Wolf_01", gather = "ore" }
COMBO["combo:herb:skin"] = { label = "Herbs + skinning", short = "Herbs + skinning", icon = "Interface\\Icons\\INV_Misc_Pelt_Wolf_01", gather = "herb" }
COMBO["combo:both:skin"] = { label = "Herbs, ore + skinning", short = "Herbs, ore + skinning", icon = "Interface\\Icons\\INV_Misc_Pelt_Wolf_01", gather = "both" }
for k, g in pairs(COMBO) do g.key, g.kind = k, "combo" end

function Finder:GoalInfo(key)
    if ns.GoalByKey[key] then return ns.GoalByKey[key] end
    if COMBO[key] then return COMBO[key] end
    local id = type(key) == "string" and tonumber(key:match("^item:(%d+)$"))
    if id then
        return { key = key, label = DS:ItemName(id), kind = "item", item = id,
            icon = (C_Item and C_Item.GetItemIconByID and C_Item.GetItemIconByID(id)) or "Interface\\Icons\\INV_Misc_QuestionMark" }
    end
    return ns.GoalByKey.herb
end

function Finder:ItemGoal(itemID) return "item:" .. itemID end

-------------------------------------------------------------------------------
-- value functions
-------------------------------------------------------------------------------
local function price(id) return (ns.Prices:Get(id)) end

--- Value (copper) of one node of a type (all gathers on it). Uses your own yields from
--- minSamples visits (Scarce finds included), else Classic yields (+ learned Scarce rate).
function Finder:NodeValue(t)
    local v = 0
    for _, y in ipairs(ns.Learn:NodeInfo(t).perNode) do v = v + price(y[1]) * y[2] end
    return v
end

--- Expected count of an item per node of a type.
local function nodeItemQty(t, itemID) return ns.Learn:NodeQty(t, itemID) end

local CAT_FOR_GOAL = { cloth = "cloth", meat = "meat", elemental = "elemental", lockbox = "lockbox" }

local function canSkin(m, skills, goal)
    if not m.skinnable then return false end
    local have = skills.skin or ((goal == "skin" or goal == "leather") and 300) or 0
    return have >= ns.SkinSkillForLevel(m.maxLevel)
end

--- Expected loot per kill for a goal: copper value and a list { {id, p, value}, ... }.
--- Item goals: p = chance per kill for that item.
function Finder:MobValue(m, goal, skills, level)
    local v, parts = 0, {}
    local function add(id, p)
        local c = price(id) * p
        v = v + c
        parts[#parts + 1] = { id = id, p = p, value = c }
    end
    local itemID = type(goal) == "string" and tonumber(goal:match("^item:(%d+)$"))
    if itemID then
        for _, list in ipairs({ m.farm, m.pickpocket }) do
            for _, e in ipairs(list) do if e[1] == itemID then add(e[1], e[2]) end end
        end
        if canSkin(m, skills, "skin") then
            for _, e in ipairs(m.skin) do if e[1] == itemID then add(e[1], e[2]) end end
        end
        return v, parts
    end
    local cat = CAT_FOR_GOAL[goal]
    if cat == "lockbox" then
        for _, e in ipairs(m.pickpocket) do add(e[1], e[2]) end
    elseif cat then
        for _, e in ipairs(m.farm) do if DS:ItemCategory(e[1]) == cat then add(e[1], e[2]) end end
    end
    if goal == "skin" or goal == "leather" or (goal == "gold" and skills.skin) then
        if canSkin(m, skills, goal) then
            for _, e in ipairs(m.skin) do add(e[1], e[2]) end
        end
    end
    if goal == "greens" or goal == "gold" then
        if m.green and m.green > 0 then
            local dv = ns.Prices:DisenchantValue(m.greenIlvl or m.maxLevel, 2)
            v = v + m.green * dv
            parts[#parts + 1] = { greens = 2, p = m.green, value = m.green * dv }
        end
        if m.blue and m.blue > 0 then
            local bv = ns.Prices:DisenchantValue(m.greenIlvl or m.maxLevel, 3)
            v = v + m.blue * bv
            parts[#parts + 1] = { greens = 3, p = m.blue, value = m.blue * bv }
        end
    end
    if goal == "gold" then
        for _, e in ipairs(m.farm) do add(e[1], e[2]) end
        if m.copper and m.copper > 0 then
            v = v + m.copper
            parts[#parts + 1] = { coin = true, p = 1, value = m.copper }
        end
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
    if m.rank and m.rank > 0 then return showDangerous and 0.3 or 0 end
    if d > 3 then return showDangerous and 0.4 or 0 end
    if d > 1 then return 0.8 end
    if d < -10 then return 1.5 end
    if d < -4 then return 1.25 end
    return 1.0
end
Finder.LevelFactor = levelFactor

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

local function windowSize(uiMap, location)
    local w = P:ZoneSize(uiMap)
    local cellYards = w / GRID
    local target = location == "cave" and 450 or 800
    return ns.Clamp(math.floor(target / cellYards + 0.5), 2, 9)
end

--- Location filter for a single point.
local function allowed(opts, uiMap, x, y)
    local loc = opts.location
    if not loc or loc == "any" then return true end
    local c = ns.Caves:At(uiMap, x, y)
    if loc == "cave" then return c == true end
    return c ~= true
end

--- Shrink a window rect to the bounding box of its points (+ margin) so caves get a tight area.
local function tightRect(pts, rect)
    if #pts == 0 then return rect end
    local x1, y1, x2, y2 = 1, 1, 0, 0
    for _, p in ipairs(pts) do
        if p.x < x1 then x1 = p.x end
        if p.y < y1 then y1 = p.y end
        if p.x > x2 then x2 = p.x end
        if p.y > y2 then y2 = p.y end
    end
    local m = 0.015
    return { math.max(rect[1], x1 - m), math.max(rect[2], y1 - m), math.min(rect[3], x2 + m), math.min(rect[4], y2 + m) }
end

local function nameArea(r)
    if not r.rect then return end
    local cx, cy = (r.rect[1] + r.rect[3]) / 2, (r.rect[2] + r.rect[4]) / 2
    local caves, total, caveName = 0, 0, nil
    for i = 1, #r.points, math.max(1, math.floor(#r.points / 25)) do
        local p = r.points[i]
        local c, n = ns.Caves:At(r.uiMap, p.x, p.y)
        total = total + 1
        if c then caves = caves + 1 caveName = caveName or n end
    end
    r.cave = total > 0 and caves / total >= 0.5
    r.caveName = r.cave and caveName or nil
    r.areaName = r.caveName or ns.Caves:AreaName(r.uiMap, cx, cy)
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

Finder.RiskFor = riskFor
Finder.NameArea = nameArea

--- Build a farm result for one mob type in a zone (Mobs & Drops "Farm this mob").
function Finder:MobResult(npcID, uiMap)
    DS:Load()
    local m = DS:GetMob(npcID)
    local flat = DS:GetZoneMobs(uiMap)[npcID]
    if not m or not flat or #flat < 2 then return nil end
    local skills = {}
    for k, v in pairs(P.skills) do skills[k] = v.rank end
    local pts = {}
    for i = 1, #flat, 2 do pts[#pts + 1] = { x = flat[i], y = flat[i + 1], w = 1, npc = npcID } end
    -- densest camp: best 2.5% cell, then everything within 8% of the map around it
    local c = ns.Route:Clusters(pts, 1)[1]
    local camp = {}
    for _, p in ipairs(pts) do
        if math.abs(p.x - c.x) <= 0.08 and math.abs(p.y - c.y) <= 0.08 then camp[#camp + 1] = p end
    end
    local x1, y1, x2, y2 = 1, 1, 0, 0
    for _, p in ipairs(camp) do
        x1, y1, x2, y2 = math.min(x1, p.x), math.min(y1, p.y), math.max(x2, p.x), math.max(y2, p.y)
    end
    local rect = { math.max(0, x1 - 0.015), math.max(0, y1 - 0.015), math.min(1, x2 + 0.015), math.min(1, y2 + 0.015) }
    local v, parts = Finder:MobValue(m, "gold", skills, P:Level())
    local kph = ns.Learn:KillsPerHour() * math.min(1, #camp / 12) * levelFactor(m, P:Level(), true)
    local items = {}
    for _, pa in ipairs(parts) do
        items[#items + 1] = { id = pa.id, greens = pa.greens, coin = pa.coin, perHour = pa.p * kph, value = pa.value * kph }
    end
    table.sort(items, function(a, b) return a.value > b.value end)
    local zone = ns.Zones[uiMap] or { name = P:ZoneName(uiMap), min = m.minLevel, max = m.maxLevel, faction = "C" }
    local r = {
        uiMap = uiMap, goal = "gold", mode = "gold", rank = 1, source = "mob", rect = rect, points = camp,
        route = ns.Route:Build(uiMap, ns.Route:Clusters(camp, 10), 10),
        perHour = v * kph, unitsPerHour = kph, unitLabel = "kills/h", perUnit = v, count = #camp,
        mobs = { { npc = npcID, n = #camp, m = m, perKill = v, kills = kph } }, minLevel = m.minLevel, maxLevel = m.maxLevel,
        items = items, zoneName = DS:ZoneName(uiMap), zoneMin = zone.min, zoneMax = zone.max, note = ns.HotfixNotes[uiMap],
        why = string.format("%s camp: %d spawns, ~%.0f kills/h", m.name, #camp, kph), confidence = "Classic estimate",
    }
    r.loopSec = r.route.length / P:Speed()
    r.risk, r.riskLevel = riskFor(zone, P:Faction())
    nameArea(r)
    ns.Risk:Assess(r)
    return r
end

local function zoneCandidates(opts)
    local list = {}
    if opts.zones then
        for _, z in ipairs(opts.zones) do if z and ns.Zones[z] then list[#list + 1] = z end end
        return list
    end
    for id, z in pairs(ns.Zones) do
        local tooHigh = z.min > (opts.level or 1) + 5 and not ns.settings.showDangerous and not opts.anyLevel
        -- Realistic: a zone whose weakest mobs are already orange or worse has no realistic spot
        if opts.realistic and z.min > (opts.level or 1) + ns.Risk:Profile().above then tooHigh = true end
        local noCaves = opts.location == "cave" and not ns.Caves:ZoneHasCaves(id)
        if z.faction ~= "S" and not tooHigh and not noCaves and (opts.includeEnemy or z.faction == "C" or z.faction == opts.faction) then
            list[#list + 1] = id
        end
    end
    return list
end
Finder.ZoneCandidates = zoneCandidates

--- "Classic spawns · your yields" style label for a node mix { [typeKey] = count }.
function Finder.YieldSource(byType)
    local mine, total = 0, 0
    for tk, c in pairs(byType) do
        total = total + c
        local t = DS:GetType(tk)
        if t and ns.Learn:NodeInfo(t).learned then mine = mine + c end
    end
    if total > 0 and mine == total then return "Classic spawns · your yields" end
    if mine > 0 then return string.format("Classic spawns · your yields for %d%%", math.floor(mine / total * 100 + 0.5)) end
    return "Classic spawns + yields"
end

local function evalNodes(uiMap, goal, opts, out)
    local itemID = goal.item
    local kind = goal.prof
    local have = kind and opts.skills[kind]
    local grid, cellPts = newGrid(), {}
    local minSkill
    local unsafe = opts.realistic and ns.Risk:UnsafeCells(uiMap, GRID, opts.level) or nil
    for _, pt in ipairs(DS:GetZoneNodes(uiMap)) do
        local t = DS:GetType(pt.t)
        local w
        if t and t.kind ~= "fish" then
            if itemID then
                local q = nodeItemQty(t, itemID)
                if q > 0 then
                    local col = ns.NodeSkillColor(t, opts.skills[t.kind] or 300)
                    if col ~= "red" then w = q * math.max(1, price(itemID)) end
                end
            elseif t.kind == kind then
                local col = ns.NodeSkillColor(t, have or 300)
                if opts.mode == "skill" then w = (ns.SkillUpChance[col] or 0) * ns.Learn:NodeInfo(t).taps
                elseif col ~= "red" then w = Finder:NodeValue(t) end
            end
        end
        local cx, cy = cellOf(pt.x, pt.y)
        local idx = cy * GRID + cx
        if w and w > 0 and not (unsafe and unsafe[idx]) and allowed(opts, uiMap, pt.x, pt.y) then
            -- weight by the chance this spawn point holds a live node (spawn pools)
            local a = DS:LiveShare(t, uiMap)
            w = w * a
            grid[idx] = grid[idx] + w
            cellPts[idx] = cellPts[idx] or {}
            table.insert(cellPts[idx], { x = pt.x, y = pt.y, w = w, t = pt.t, a = a })
            minSkill = math.min(minSkill or 999, t.skill or 0)
        end
    end
    if not minSkill then return end
    local W = windowSize(uiMap, opts.location)
    local picked = {}
    for rank = 1, opts.perZone or 1 do
        local cx, cy, sum = bestWindow(grid, W, picked)
        if sum <= 0 then break end
        picked[#picked + 1] = { cx, cy }
        local pts, wsum, byType, liveBy = {}, 0, {}, {}
        for yy = cy, cy + W - 1 do
            for xx = cx, cx + W - 1 do
                for _, p in ipairs(cellPts[yy * GRID + xx] or {}) do
                    pts[#pts + 1] = p
                    wsum = wsum + p.w
                    byType[p.t] = (byType[p.t] or 0) + 1
                    liveBy[p.t] = (liveBy[p.t] or 0) + p.a
                end
            end
        end
        local n = #pts
        local route = ns.Route:Build(uiMap, pts, 40)
        -- live nodes per loop = sum of each point's live share; time at nodes: casts x gathers (+ loot, + extra)
        local active, gatherSec = 0, 0
        for tk, a in pairs(liveBy) do
            active = active + a
            gatherSec = gatherSec + a * ns.Learn:NodeInfo(DS:GetType(tk)).secs
        end
        local loopSec = route.length / P:Speed() + gatherSec
        local loopsPerHour = 3600 / math.max(60, loopSec)
        local nodesPerHour = active * loopsPerHour
        -- item breakdown
        local items, mix, gold = {}, {}, 0
        for tk, c in pairs(byType) do
            mix[#mix + 1] = { t = tk, n = c }
            local t = DS:GetType(tk)
            local share = liveBy[tk] * loopsPerHour
            for _, y in ipairs(ns.Learn:NodeInfo(t).perNode) do
                if not itemID or y[1] == itemID then
                    local e = items[y[1]] or { id = y[1], perHour = 0, value = 0 }
                    items[y[1]] = e
                    local q = share * y[2]
                    e.perHour = e.perHour + q
                    e.value = e.value + q * price(y[1])
                end
            end
        end
        local list = {}
        for _, e in pairs(items) do list[#list + 1] = e gold = gold + e.value end
        table.sort(list, function(a, b) return a.value > b.value or (a.value == b.value and a.perHour > b.perHour) end)
        table.sort(mix, function(a, b) return a.n > b.n end)
        local perHour
        if opts.mode == "skill" and not itemID then perHour = wsum * loopsPerHour else perHour = gold end
        local rect = { cx / GRID, cy / GRID, (cx + W) / GRID, (cy + W) / GRID }
        out[#out + 1] = {
            uiMap = uiMap, goal = goal.key, mode = (itemID and "gold") or opts.mode, rank = rank, source = "node",
            rect = (opts.location == "cave" or opts.realistic) and tightRect(pts, rect) or rect,
            points = pts, route = route, perHour = perHour, loopSec = loopSec, unitsPerHour = nodesPerHour,
            unitLabel = "nodes/h", count = n, minSkill = minSkill, mix = mix, items = list,
            itemUnits = itemID and (items[itemID] and items[itemID].perHour or 0) or nil,
            why = string.format("%d spawn points, ~%.0f live per loop, loop %s", n, active,
                SecondsToTime and SecondsToTime(loopSec) or (math.floor(loopSec) .. "s")),
            confidence = Finder.YieldSource(byType),
        }
    end
end

local function evalMobs(uiMap, goal, opts, out)
    local s = ns.settings
    local grid, cellPts, mobsSeen = newGrid(), {}, {}
    local minL, maxL, minSkill = 99, 0, nil
    local itemID = goal.item
    local needsSkill = goal.key == "skin" or goal.key == "leather"
    local skillMode = opts.mode == "skill" and (needsSkill or goal.key == "lockbox") and not itemID
    local unsafe = opts.realistic and ns.Risk:UnsafeCells(uiMap, GRID, opts.level) or nil
    for npcID, pts in pairs(DS:GetZoneMobs(uiMap)) do
        local m = DS:GetMob(npcID)
        if m and not DS:IsFriendly(m) and not (opts.realistic and ns.Risk.TooHard(m, opts.level)) then
            local lf = levelFactor(m, opts.level, s.showDangerous or opts.anyLevel)
            local w
            if lf > 0 then
                if skillMode then
                    w = mobSkillUp(m, goal.key, opts.skills)
                else
                    local v, parts = Finder:MobValue(m, goal.key, opts.skills, opts.level)
                    w = v
                    if itemID and w == 0 and #parts > 0 then w = parts[1].p * 0.01 end -- no price: rank by chance
                end
                w = w * lf
            end
            if w and w > 0 then
                local kept = 0
                for i = 1, #pts, 2 do
                    local cx, cy = cellOf(pts[i], pts[i + 1])
                    local idx = cy * GRID + cx
                    if not (unsafe and unsafe[idx]) and allowed(opts, uiMap, pts[i], pts[i + 1]) then
                        kept = kept + 1
                        grid[idx] = grid[idx] + w
                        cellPts[idx] = cellPts[idx] or {}
                        table.insert(cellPts[idx], { x = pts[i], y = pts[i + 1], w = w, npc = npcID })
                    end
                end
                if kept > 0 then
                    mobsSeen[npcID] = { m = m, w = w, lf = lf }
                    minL, maxL = math.min(minL, m.minLevel), math.max(maxL, m.maxLevel)
                    if needsSkill or (itemID and m.skinnable) then minSkill = math.min(minSkill or 999, ns.SkinSkillForLevel(m.maxLevel)) end
                end
            end
        end
    end
    if maxL == 0 then return end
    local W = windowSize(uiMap, opts.location)
    local picked = {}
    local qnames = opts.questNames or {}
    for rank = 1, opts.perZone or 1 do
        local cx, cy, sum = bestWindow(grid, W, picked)
        if sum <= 0 then break end
        picked[#picked + 1] = { cx, cy }
        local pts, perMob = {}, {}
        for yy = cy, cy + W - 1 do
            for xx = cx, cx + W - 1 do
                for _, p in ipairs(cellPts[yy * GRID + xx] or {}) do
                    pts[#pts + 1] = p
                    perMob[p.npc] = (perMob[p.npc] or 0) + 1
                end
            end
        end
        local n = #pts
        -- spawns that are up often enough to pull from: slow respawns (rares, 10+ min) count for less
        local eff, effBy = 0, {}
        for npc, c in pairs(perMob) do
            local r = c * math.min(1, 300 / math.max(30, DS:MobRespawn(mobsSeen[npc].m, 300)))
            effBy[npc] = r
            eff = eff + r
        end
        local density = math.min(1, eff / 25)
        local kph = ns.Learn:KillsPerHour() * density
        local mobs, questOverlap, items, gold, skillups = {}, {}, {}, 0, 0
        for npc, c in pairs(perMob) do
            local e = mobsSeen[npc]
            local mm = e.m
            local killsHere = kph * effBy[npc] / math.max(eff, 1e-6) * e.lf
            local v, parts = Finder:MobValue(mm, goal.key, opts.skills, opts.level)
            mobs[#mobs + 1] = { npc = npc, n = c, m = mm, perKill = v, kills = killsHere }
            gold = gold + v * killsHere
            if skillMode then skillups = skillups + mobSkillUp(mm, goal.key, opts.skills) * killsHere end
            for _, pa in ipairs(parts) do
                local key = pa.id or (pa.greens and ("greens" .. pa.greens)) or "coin"
                local it = items[key] or { id = pa.id, greens = pa.greens, coin = pa.coin, perHour = 0, value = 0 }
                items[key] = it
                it.perHour = it.perHour + pa.p * killsHere
                it.value = it.value + pa.value * killsHere
            end
            if qnames[mm.name:lower()] then questOverlap[#questOverlap + 1] = mm.name end
        end
        table.sort(mobs, function(a, b) return a.perKill * a.n > b.perKill * b.n end)
        local list = {}
        for _, it in pairs(items) do list[#list + 1] = it end
        table.sort(list, function(a, b) return a.value > b.value or (a.value == b.value and a.perHour > b.perHour) end)
        local route = ns.Route:Build(uiMap, ns.Route:Clusters(pts, 14), 14)
        local rect = { cx / GRID, cy / GRID, (cx + W) / GRID, (cy + W) / GRID }
        out[#out + 1] = {
            uiMap = uiMap, goal = goal.key, mode = skillMode and "skill" or "gold", rank = rank, source = "mob",
            rect = (opts.location == "cave" or opts.realistic) and tightRect(pts, rect) or rect,
            points = pts, route = route, perHour = skillMode and skillups or gold, unitsPerHour = kph, unitLabel = "kills/h",
            perUnit = gold / math.max(1, kph),
            count = n, mobs = mobs, minLevel = minL, maxLevel = maxL, minSkill = minSkill, items = list,
            itemUnits = itemID and (items[itemID] and items[itemID].perHour or 0) or nil,
            questOverlap = questOverlap, loopSec = route.length / P:Speed(),
            why = string.format("%d mob spawns, %d kinds, ~%.0f kills/h", n, #mobs, kph),
            confidence = "Classic estimate",
        }
    end
end

local function evalFish(uiMap, goal, opts, out)
    local f = ForagerData and ForagerData.fishing and ForagerData.fishing[uiMap]
    if not f or opts.location == "cave" then return end
    local s = ns.settings
    local zoneSkill = math.max(0, f[1] or 0)
    local have = opts.skills.fish or 0
    local catch = have >= zoneSkill and 1 or math.max(0.1, (have / math.max(1, zoneSkill)) ^ 2)
    local itemID = goal.item
    local items, v = {}, 0
    local cph = s.castsPerHour * catch
    local function add(id, perCatch)
        if itemID and id ~= itemID then return end
        items[#items + 1] = { id = id, perHour = perCatch * cph, value = perCatch * cph * price(id) }
        v = v + price(id) * perCatch
    end
    local own = ns.db.fish[uiMap]
    local prior = {}
    for i = 2, #f do prior[#prior + 1] = { f[i][1], f[i][2] } end
    local n = own and own.casts or 0
    for _, e in ipairs((ns.Learn:BlendList(prior, own and own.items, n))) do add(e[1], e[2]) end
    local confidence = n >= s.minSamples and ("My data (n=" .. n .. ")") or (n > 0 and ("Classic + yours (n=" .. n .. ")") or "Classic estimate")
    if #items == 0 then return end
    table.sort(items, function(a, b) return a.value > b.value or (a.value == b.value and a.perHour > b.perHour) end)
    local skillMode = opts.mode == "skill" and not itemID
    local perHour = skillMode and (cph * ns.Clamp((300 - have) / 300 + 0.05, 0.05, 1) * 0.6) or (cph * v)
    out[#out + 1] = {
        uiMap = uiMap, goal = goal.key, mode = skillMode and "skill" or "gold", rank = 1, source = "fish",
        rect = nil, points = {}, route = { points = {}, length = 0 },
        perHour = perHour, unitsPerHour = cph, unitLabel = "catches/h", perUnit = v, minSkill = zoneSkill, items = items,
        itemUnits = itemID and (items[1] and items[1].perHour) or nil,
        why = string.format("zone fishing skill %d, ~%d catches/h", zoneSkill, cph),
        confidence = confidence,
    }
end

-------------------------------------------------------------------------------
-- public
-------------------------------------------------------------------------------
local cache = {} -- recent searches: { key, results, last } (newest first, 4 kept)
function Finder:FlushCache() wipe(cache) end

--- opts: goal, mode, zones, level, faction, skills, perZone, questing, location, includeEnemy
function Finder:Run(opts)
    local key = ns.OptsKey(opts, "finder")
    for i, c in ipairs(cache) do
        if c.key == key then
            table.insert(cache, 1, table.remove(cache, i))
            Finder.last = c.last
            return c.results
        end
    end
    local out = Finder:Search(opts)
    table.insert(cache, 1, { key = key, results = out, last = Finder.last })
    while #cache > 4 do table.remove(cache) end
    return out
end

function Finder:Search(opts)
    DS:Load()
    opts = opts or {}
    local goal = Finder:GoalInfo(opts.goal or "herb")
    opts.mode = opts.mode or ns.settings.mode
    opts.level = opts.level or P:Level()
    opts.faction = opts.faction or P:Faction()
    opts.location = opts.location or ns.settings.location or "any"
    if opts.realistic == nil then opts.realistic = ns.settings.realistic and true or false end
    opts.skills = opts.skills or {}
    if not next(opts.skills) then
        for k, v in pairs(P.skills) do opts.skills[k] = v.rank end
    end
    if opts.mode == "skill" and not (goal.kind == "node" or goal.kind == "fish" or goal.key == "skin" or goal.key == "leather" or goal.key == "lockbox") then
        opts.mode = "gold"
    end
    local out = {}
    -- Realistic: evaluate spare areas per zone so a spot that fails the check is replaced by the next one
    local want = opts.perZone or 1
    local hidden = opts.realistic and { n = 0, reasons = {} } or nil
    if opts.realistic then opts.perZone = want * 3 end
    local cands = zoneCandidates(opts)
    for ci, uiMap in ipairs(cands) do
        ns.Async.progress = ci / #cands
        local zone = ns.Zones[uiMap]
        local before = #out
        if goal.kind == "node" then evalNodes(uiMap, goal, opts, out)
        elseif goal.kind == "mob" then evalMobs(uiMap, goal, opts, out)
        elseif goal.kind == "fish" then evalFish(uiMap, goal, opts, out)
        elseif goal.kind == "item" then
            evalNodes(uiMap, goal, opts, out)
            evalMobs(uiMap, goal, opts, out)
            evalFish(uiMap, goal, opts, out)
        end
        for i = before + 1, #out do
            local r = out[i]
            r.zoneName = DS:ZoneName(uiMap)
            r.zoneMin, r.zoneMax = zone.min, zone.max
            r.note = ns.HotfixNotes[uiMap]
            r.risk, r.riskLevel = riskFor(zone, opts.faction)
            nameArea(r)
            ns.Risk:Assess(r)
        end
        if opts.realistic then
            local keptBy, j = {}, before
            for i = before + 1, #out do
                local r = out[i]
                local ok, why = ns.Risk:RealisticCheck(r)
                local src = r.source or "?"
                if ok and (keptBy[src] or 0) < want then
                    keptBy[src] = (keptBy[src] or 0) + 1
                    j = j + 1
                    out[j] = r
                elseif not ok then
                    ns.Risk.AddHidden(hidden, why)
                end
            end
            for i = #out, j + 1, -1 do out[i] = nil end
        end
        ns.Yield()
    end
    opts.perZone = want
    ns.Net:ApplyAll(out)
    if opts.questing then Finder:ApplyQuesting(out, opts) end
    local byUnits = goal.kind == "item" and (ns.Prices:Get(goal.item)) == 0
    table.sort(out, function(a, b)
        if byUnits then return (a.itemUnits or 0) > (b.itemUnits or 0) end
        return (a.score or a.perHour) > (b.score or b.perHour)
    end)
    out = ns.Risk:Filter(out)
    Finder.last = { opts = opts, results = out, goal = goal, time = time(), byUnits = byUnits, hidden = hidden }
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

--- Standard options for the current character (questing zone, location filter, enemy zones).
function Finder:Options(goalKey, mode)
    local opts = { goal = goalKey, mode = mode or ns.settings.mode, perZone = 2, includeEnemy = ns.settings.includeEnemy,
        location = ns.settings.location }
    if ns.Quests:IsActive() then
        local z1, z2 = ns.Quests:Zones()
        opts.zones, opts.questing, opts.questNames = { z1, z2 }, true, ns.Quests:ObjectiveNames()
        opts.perZone = 4
    end
    return opts
end

--- One-click: best spot for the current character, including questing zone if set.
function Finder:Best(goalKey, mode)
    local res = Finder:Run(Finder:Options(goalKey, mode))
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

--- Search suggestions for the "What do you want to farm?" box: goals, items, mobs.
function Finder:Suggest(text, max)
    DS:Load()
    max = max or 12
    text = (text or ""):lower()
    local out = {}
    if text == "" then return out end
    for _, g in ipairs(ns.Goals) do
        if g.label:lower():find(text, 1, true) or g.key:find(text, 1, true) then
            out[#out + 1] = { kind = "goal", key = g.key, text = g.label, icon = g.icon }
        end
    end
    local seen = {}
    local function addItem(id, name)
        if seen[id] or #out >= max then return end
        if name and name:lower():find(text, 1, true) then
            seen[id] = true
            out[#out + 1] = { kind = "item", key = Finder:ItemGoal(id), id = id, text = name,
                icon = C_Item and C_Item.GetItemIconByID and C_Item.GetItemIconByID(id) }
        end
    end
    for _, t in pairs(ns.NodeTypes) do
        for _, y in ipairs(t.yields) do addItem(y[1], DS:ItemName(y[1])) end
    end
    for id, e in pairs(ns.KnownItems) do addItem(id, DS:ItemName(id) or e[1]) end
    if ForagerData and ForagerData.items then
        for id, it in pairs(ForagerData.items) do addItem(id, it[1]) end
    end
    if #out < max and ForagerData and ForagerData.mobs then
        local n = 0
        for id, raw in pairs(ForagerData.mobs) do
            -- match on the raw name first: decoding every mob would fill the cache
            local name = raw:match("^([^|]*)")
            local m = name and name:lower():find(text, 1, true) and DS:GetMob(id)
            if m then
                out[#out + 1] = { kind = "mob", id = id, text = m.name .. string.format(" (%d-%d)", m.minLevel, m.maxLevel) }
                n = n + 1
                if n >= 4 or #out >= max then break end
            end
        end
    end
    local order = { goal = 1, item = 2, mob = 3 }
    table.sort(out, function(a, b)
        if order[a.kind] ~= order[b.kind] then return order[a.kind] < order[b.kind] end
        local ap, bp = a.text:lower():find(text, 1, true) == 1, b.text:lower():find(text, 1, true) == 1
        if ap ~= bp then return ap end
        return a.text < b.text
    end)
    return out
end
