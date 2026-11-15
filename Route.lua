-- Route: optimised loop through node spawns / mob camps (nearest neighbour + 2-opt),
-- next-waypoint tracking and loop progress.
local _, ns = ...
local Route = {}
ns.Route = Route
local P = ns.Player

local function dist(uiMap, a, b) return P:Distance(uiMap, a.x, a.y, b.x, b.y) end

local function tourLength(uiMap, pts)
    local L = 0
    for i = 1, #pts do L = L + dist(uiMap, pts[i], pts[i % #pts + 1]) end
    return L
end

--- Pick up to maxPoints by weight, at least 25 yd apart.
local function thin(uiMap, pts, maxPoints)
    local sorted = {}
    for i, p in ipairs(pts) do sorted[i] = p end
    table.sort(sorted, function(a, b) return (a.w or 0) > (b.w or 0) end)
    local out = {}
    for _, p in ipairs(sorted) do
        local ok = true
        for _, q in ipairs(out) do
            if dist(uiMap, p, q) < 25 then ok = false break end
        end
        if ok then out[#out + 1] = { x = p.x, y = p.y, w = p.w, t = p.t, npc = p.npc } end
        if #out >= maxPoints then break end
    end
    return out
end

--- Build a closed loop. Returns { points = {...}, length = yards }.
function Route:Build(uiMap, pts, maxPoints, startX, startY)
    if not pts or #pts == 0 then return { points = {}, length = 0, uiMap = uiMap } end
    local cand = thin(uiMap, pts, maxPoints or 40)
    local n = #cand
    if n <= 2 then return { points = cand, length = n == 2 and 2 * dist(uiMap, cand[1], cand[2]) or 0, uiMap = uiMap } end
    -- nearest neighbour from the point closest to the start (or the heaviest point)
    local startIdx = 1
    if startX then
        local bd
        for i, p in ipairs(cand) do
            local d = P:Distance(uiMap, startX, startY, p.x, p.y)
            if not bd or d < bd then bd, startIdx = d, i end
        end
    end
    local used, tour = {}, { cand[startIdx] }
    used[startIdx] = true
    for _ = 2, n do
        local last, bi, bd = tour[#tour], nil, nil
        for i, p in ipairs(cand) do
            if not used[i] then
                local d = dist(uiMap, last, p)
                if not bd or d < bd then bd, bi = d, i end
            end
        end
        used[bi] = true
        tour[#tour + 1] = cand[bi]
    end
    -- 2-opt
    local improved, guard = true, 0
    while improved and guard < 50 do
        improved, guard = false, guard + 1
        for i = 1, n - 2 do
            for k = i + 1, n - 1 do
                local a, b, c, d = tour[i], tour[i + 1], tour[k], tour[k % n + 1]
                local delta = dist(uiMap, a, c) + dist(uiMap, b, d) - dist(uiMap, a, b) - dist(uiMap, c, d)
                if delta < -0.5 then
                    local lo, hi = i + 1, k
                    while lo < hi do tour[lo], tour[hi] = tour[hi], tour[lo] lo, hi = lo + 1, hi - 1 end
                    improved = true
                end
            end
        end
    end
    return { points = tour, length = tourLength(uiMap, tour), uiMap = uiMap }
end

--- Group mob spawn points into weighted camp centroids (2.5% cells), top k.
function Route:Clusters(pts, k)
    local cells = {}
    for _, p in ipairs(pts) do
        local key = math.floor(p.x * 40) .. ":" .. math.floor(p.y * 40)
        local c = cells[key]
        if not c then c = { sx = 0, sy = 0, n = 0, w = 0 } cells[key] = c end
        c.sx, c.sy, c.n, c.w = c.sx + p.x, c.sy + p.y, c.n + 1, c.w + (p.w or 1)
    end
    local out = {}
    for _, c in pairs(cells) do out[#out + 1] = { x = c.sx / c.n, y = c.sy / c.n, w = c.w, n = c.n } end
    table.sort(out, function(a, b) return a.w > b.w end)
    while #out > (k or 14) do table.remove(out) end
    return out
end

-------------------------------------------------------------------------------
-- active route state
-------------------------------------------------------------------------------
Route.active = nil -- { result, route, uiMap, index, loops, visited }

function Route:Start(result)
    if not result then return end
    local route = result.route
    if not route or #route.points == 0 then
        Route.preview = nil
        Route.active = { result = result, route = route or { points = {} }, uiMap = result.uiMap, index = 1, loops = 0, visited = 0 }
        ns:Fire("FORAGER_ROUTE_CHANGED")
        return
    end
    -- rotate so the loop starts at the waypoint nearest the player
    local x, y = P:Position(result.uiMap)
    local start = 1
    if x then
        local bd
        for i, p in ipairs(route.points) do
            local d = P:Distance(result.uiMap, x, y, p.x, p.y)
            if not bd or d < bd then bd, start = d, i end
        end
    end
    Route.preview = nil
    Route.active = { result = result, route = route, uiMap = result.uiMap, index = start, loops = 0, visited = 0, startIndex = start }
    ns:Fire("FORAGER_ROUTE_CHANGED")
end

function Route:Stop()
    Route.active = nil
    ns:Fire("FORAGER_ROUTE_CHANGED")
end

--- Show a result on the maps without starting it ("Show on map"). nil clears.
function Route:Preview(result)
    if result and Route.active and Route.active.result == result then result = nil end
    Route.preview = result and { result = result, route = result.route or { points = {} }, uiMap = result.uiMap, preview = true } or nil
    ns:Fire("FORAGER_ROUTE_CHANGED")
end

--- What the maps should draw: the preview if one is set, otherwise the active farm.
function Route:Shown()
    return Route.preview or Route.active
end

--- Current waypoint, distance (yd), progress 0-1, loops completed.
function Route:Next()
    local a = Route.active
    if not a or #a.route.points == 0 then return nil end
    local wp = a.route.points[a.index]
    local x, y, map = P:Position(a.uiMap)
    local d
    if x and map == a.uiMap then d = P:Distance(a.uiMap, x, y, wp.x, wp.y) end
    local n = #a.route.points
    return wp, d, (a.visited % n) / n, a.loops, a.index
end

--- Called periodically: advance when within 25 yd of the waypoint.
function Route:Update()
    local a = Route.active
    if not a or #a.route.points == 0 then return end
    local _, d = Route:Next()
    if d and d < 25 then
        local n = #a.route.points
        a.index = a.index % n + 1
        a.visited = a.visited + 1
        if a.visited % n == 0 then a.loops = a.loops + 1 end
        ns:Fire("FORAGER_ROUTE_PROGRESS")
    end
end

function Route:Skip()
    local a = Route.active
    if not a or #a.route.points == 0 then return end
    a.index = a.index % #a.route.points + 1
    a.visited = a.visited + 1
    ns:Fire("FORAGER_ROUTE_PROGRESS")
end
