-- Roam: free roam. Gather a profession anywhere without a fixed route.
--   * The arrow points to the nearest spot a node can be: spawn points you can gather (bundled, yours,
--     shared, and nodes you have seen), weighted by how often that node type is up (spawn pools).
--   * Spots you pass within 30 yd are checked (a node there would be on your minimap) and spots you
--     gather are cooling: neither is pointed at again until the node type can have respawned.
--   * Hover a herb/ore dot on the minimap and the arrow locks on to it (Detect reads the dot).
--   * Every node you gather or point at is saved, so zones without spawn data fill in as you go.
-- It runs as a farm without route points, so the HUD, Stop, the session clock, the tracking switcher
-- (Herbs + ore) and the ready check all work as usual.
local _, ns = ...
local Roam = {}
ns.Roam = Roam
local DS, P, L = ns.DS, ns.Player, ns.L

Roam.CHECK_YARDS = 30    -- passing this close shows the node on your minimap if one is up
Roam.REACH_YARDS = 12    -- the arrow's target counts as reached
Roam.MAX_YARDS = 500     -- how far to look for the next spot
Roam.LOCK_SECONDS = 120  -- a dot you hovered stays the target this long (or until reached)
Roam.SWITCH = 0.7        -- a new spot must score 30% better to replace the current target

local KINDS = { herb = { herb = true }, ore = { ore = true }, both = { herb = true, ore = true } }
local LABELS = { herb = "Herbalism", ore = "Mining", both = "herbs + ore" }
Roam.LABELS = LABELS
Roam.GOALS = {
    ["roam:herb"] = { key = "roam:herb", label = "Free roam: Herbalism", short = "Roam: herbs", icon = "Interface\\Icons\\Trade_Herbalism", kind = "roam" },
    ["roam:ore"] = { key = "roam:ore", label = "Free roam: Mining", short = "Roam: ore", icon = "Interface\\Icons\\Trade_Mining", kind = "roam" },
    ["roam:both"] = { key = "roam:both", label = "Free roam: herbs + ore", short = "Roam: both", icon = "Interface\\Icons\\INV_Misc_Flower_02", kind = "roam" },
}

--- The active free roam farm, or nil.
function Roam:Active()
    local a = ns.Route.active
    return a and a.roam and a or nil
end

--- What to roam for: the Farm goal if it is herbs or ore (or an item from them), else your professions.
function Roam:DefaultKind()
    local g = ns.char and ns.char.goal
    local gi = g and ns.Finder:GoalInfo(g)
    if gi then
        if gi.key == "herb" or gi.key == "ore" then return gi.key end
        if gi.kind == "item" and gi.item then
            local tk = DS:TypeForItem(gi.item)
            local t = tk and ns.NodeTypes[tk]
            if t and (t.kind == "herb" or t.kind == "ore") then return t.kind end
        end
    end
    local h, o = P.skills.herb, P.skills.ore
    if h and o then return "both" elseif o then return "ore" end
    return "herb"
end

local function result(kind, uiMap)
    return { source = "roam", roam = kind, goal = "roam:" .. kind, uiMap = uiMap, zoneName = DS:ZoneName(uiMap),
        mode = "gold", perHour = 0, items = {} }
end

--- Start free roam for "herb", "ore" or "both" (default: Roam:DefaultKind()) in your current zone.
function Roam:Start(kind)
    kind = KINDS[kind] and kind or Roam:DefaultKind()
    DS:Load()
    local uiMap = P:MapID()
    if not uiMap or P:InRestrictedContent() then
        ns:Print(L["Free roam works outdoors: step outside first."])
        return false
    end
    ns.Route.preview = nil
    ns.Route.active = { roam = true, kind = kind, result = result(kind, uiMap), route = { points = {} }, uiMap = uiMap,
        index = 1, loops = 0, visited = 0, cool = {}, checked = {}, nChecked = 0, gathered = 0, seen = 0 }
    ns.Route:Started(ns.Route.active.result)
    Roam:Update(true)
    ns:Print(string.format(L["Free roam: %s. The arrow points to the nearest likely node; hover a dot on your minimap to lock on to it."],
        L[LABELS[kind]]))
    return true
end

--- Start, or stop if free roam is already on.
function Roam:Toggle(kind)
    if Roam:Active() then ns.Route:Stop() else Roam:Start(kind) end
end

local function canGather(t)
    local have = P:Skill(t.kind)
    return not have or (t.skill or 0) <= have
end

local function spotKey(pt)
    if not pt.rk then pt.rk = math.floor(pt.x * 2000) .. ":" .. math.floor(pt.y * 2000) end
    return pt.rk
end

local function wanted(a, tk)
    local t = DS:GetType(tk)
    return t and KINDS[a.kind][t.kind] and canGather(t) and t or nil
end

--- Pick the arrow's target (called by the overlay ticker; works every 0.5 s, or now when forced).
function Roam:Update(force)
    local a = Roam:Active()
    if not a then return end
    local now = GetTime()
    if not force and a.nextPick and now < a.nextPick then return end
    a.nextPick = now + 0.5
    -- follow the player from zone to zone
    local uiMap = P:MapID()
    if uiMap and uiMap ~= a.uiMap and not P:InRestrictedContent() then
        a.uiMap, a.target, a.lock = uiMap, nil, nil
        a.result.uiMap, a.result.zoneName = uiMap, DS:ZoneName(uiMap)
        ns:Fire("FORAGER_ROUTE_PROGRESS")
    end
    local x, y = P:Position(a.uiMap)
    if not x then a.target = nil return end
    -- a dot you hovered on the minimap is a node that is up: go there first
    if a.lock then
        local d = P:Distance(a.uiMap, x, y, a.lock.x, a.lock.y)
        if now - a.lock.at > Roam.LOCK_SECONDS or a.lock.uiMap ~= a.uiMap or d < Roam.REACH_YARDS then a.lock = nil end
    end
    local best, bestScore, curScore
    local tKey = a.target and not a.target.locked and a.target.key
    for _, pt in ipairs(DS:GetZoneNodes(a.uiMap)) do
        local t = wanted(a, pt.t)
        if t then
            local key = spotKey(pt)
            local d = P:Distance(a.uiMap, x, y, pt.x, pt.y)
            local exp = a.checked[key]
            local open = not exp or exp < now
            -- passing close: a node there would be on your minimap; the target itself only when reached
            if open and d < (key == tKey and Roam.REACH_YARDS or Roam.CHECK_YARDS) then
                a.checked[key] = now + ns.Learn:Respawn(t)
                a.nChecked = a.nChecked + 1
                open = false
            end
            if open and d <= Roam.MAX_YARDS then
                local score = d / (0.5 + DS:LiveShare(t, a.uiMap))
                if not bestScore or score < bestScore then
                    best, bestScore = { x = pt.x, y = pt.y, t = pt.t, key = key, src = pt.src }, score
                end
                if key == tKey then curScore = score end
            end
        end
    end
    if a.lock then a.target = a.lock return end
    if curScore and bestScore and bestScore > curScore * Roam.SWITCH then return end -- keep the current target
    a.target = best
end

--- Distance and the target, for the HUD and the card.
function Roam:Target()
    local a = Roam:Active()
    if not a or not a.target then return nil end
    local x, y = P:Position(a.uiMap)
    local d = x and P:Distance(a.uiMap, x, y, a.target.x, a.target.y)
    return a.target, d
end

--- A node was gathered: spots around it are cooling.
function Roam:OnGathered(uiMap, x, y, tk)
    local a = Roam:Active()
    if not a or uiMap ~= a.uiMap or not x then return end
    a.gathered = a.gathered + 1
    local now = GetTime()
    for _, pt in ipairs(DS:GetZoneNodes(uiMap)) do
        if pt.t == tk and P:Distance(uiMap, x, y, pt.x, pt.y) < 20 then
            a.checked[spotKey(pt)] = now + ns.Learn:Respawn(DS:GetType(tk))
        end
    end
    if a.lock and P:Distance(uiMap, x, y, a.lock.x, a.lock.y) < 25 then a.lock = nil end
    a.nextPick = nil
end

--- A node was seen (Detect): a dot hovered on the minimap becomes the target.
function Roam:OnSeen(uiMap, x, y, tk, how, again)
    local a = Roam:Active()
    if not a or uiMap ~= a.uiMap or not wanted(a, tk) then return end
    if not again then a.seen = a.seen + 1 end
    if how == "minimap" then
        a.lock = { x = x, y = y, t = tk, at = GetTime(), uiMap = uiMap, locked = true }
        a.target = a.lock
        a.nextPick = nil
    end
end

ns:On("FORAGER_NODE_GATHERED", function(_, uiMap, x, y, tk) Roam:OnGathered(uiMap, x, y, tk) end)
ns:On("FORAGER_NODE_SEEN", function(_, uiMap, x, y, tk, how, again) Roam:OnSeen(uiMap, x, y, tk, how, again) end)
