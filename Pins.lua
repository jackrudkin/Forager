-- Pins: Forager's own node icons and route waypoints on the minimap and world map (native yellow
-- dots can't be read or restyled on Forever). Pins are pooled and only created for the current /
-- displayed zone. World map default: only the nodes of the active farm (no clutter).
local _, ns = ...
local Pins = {}
ns.Pins = Pins
local HBD = LibStub("HereBeDragons-2.0")
local HBDPins = LibStub("HereBeDragons-Pins-2.0")
local DS, P = ns.DS, ns.Player

local REF_MM, REF_WM = "ForagerMinimap", "ForagerWorldmap"
local REF_RMM, REF_RWM = "ForagerRouteMinimap", "ForagerRouteWorldmap"
local SHOW_CONTINENT = HBD_PINS_WORLDMAP_SHOW_CONTINENT or 2
local pool, wpPool = {}, {}
local active = { mm = {}, wm = {}, rmm = {}, rwm = {} }
local mmZone, wmZone

local SOURCE_LABEL = { bundled = "Database (Classic spawn)", learned = "Learned (you gathered it)", shared = "Shared by guild/party", import = "Imported" }

local function colorFor(t)
    if t.kind == "fish" then return ns.ColorRGB.green end
    return ns.ColorRGB[ns.SkillColor(t.skill or 0, P:Skill(t.kind))] or ns.ColorRGB.grey
end

local function onEnter(self)
    local d = self.data
    if not d then return end
    local t = DS:GetType(d.t)
    if not t then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:AddLine(t.name, 1, 1, 1)
    local have = P:Skill(t.kind)
    if t.kind ~= "fish" then
        local col = ns.SkillColor(t.skill or 0, have)
        GameTooltip:AddDoubleLine("Required skill", string.format("|cff%s%d|r (you: %s)", ns.ColorHex[col], t.skill or 0, have or "none"))
    end
    GameTooltip:AddDoubleLine("Source", SOURCE_LABEL[d.src] or d.src, 0.7, 0.7, 0.7, 0.9, 0.9, 0.9)
    local cave, caveName = ns.Caves:At(d.map or mmZone, d.x, d.y)
    if cave then GameTooltip:AddDoubleLine("Location", "|cff9e7af2Cave|r " .. (caveName or ""), 0.7, 0.7, 0.7, 1, 1, 1) end
    local rec = d.rec
    if rec then
        GameTooltip:AddDoubleLine("Times gathered", rec.c or 0, 0.7, 0.7, 0.7, 1, 1, 1)
        if rec.l then GameTooltip:AddDoubleLine("Last gathered", date("%d %b %H:%M", rec.l), 0.7, 0.7, 0.7, 1, 1, 1) end
        if rec.y and next(rec.y) then
            GameTooltip:AddLine("Yielded:", 0.7, 0.7, 0.7)
            for id, q in pairs(rec.y) do GameTooltip:AddDoubleLine("  " .. DS:ColoredItem(id), "x" .. q) end
        end
        if rec.from then GameTooltip:AddDoubleLine("From", rec.from, 0.7, 0.7, 0.7, 1, 1, 1) end
    end
    if t.yields and #t.yields > 0 and (not rec or not rec.y) then
        GameTooltip:AddLine("Typical yield (Classic):", 0.7, 0.7, 0.7)
        for i = 1, math.min(3, #t.yields) do
            GameTooltip:AddDoubleLine("  " .. DS:ColoredItem(t.yields[i][1]), string.format("%.2f", t.yields[i][2]))
        end
    end
    GameTooltip:AddLine("A pin shows a known spawn point, not a live node.", 0.5, 0.5, 0.5, true)
    GameTooltip:Show()
end

local function acquire()
    local f = table.remove(pool)
    if not f then
        f = CreateFrame("Button", nil, UIParent)
        f:SetSize(14, 14)
        f.border = f:CreateTexture(nil, "BACKGROUND")
        f.border:SetPoint("TOPLEFT", -1, 1)
        f.border:SetPoint("BOTTOMRIGHT", 1, -1)
        f.border:SetColorTexture(1, 1, 1, 1)
        f.icon = f:CreateTexture(nil, "ARTWORK")
        f.icon:SetAllPoints()
        f.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        f:SetScript("OnEnter", onEnter)
        f:SetScript("OnLeave", function() GameTooltip:Hide() end)
    end
    f:EnableMouse(true)
    return f
end

-------------------------------------------------------------------------------
-- node filters
-------------------------------------------------------------------------------
local function eligible(pt, t)
    local s = ns.settings
    if not t then return false end
    if not s.kinds[t.kind] then return false end
    if s.hiddenTypes[tostring(pt.t)] then return false end
    if pt.src == "bundled" and not s.showBundled then return false end
    if pt.src == "learned" and not s.showLearned then return false end
    if pt.src == "shared" and not s.showShared then return false end
    if s.onlyEligibleNodes and pt.src == "bundled" and t.kind ~= "fish" then
        local have = P:Skill(t.kind)
        if not have or have < (t.skill or 0) then return false end
    end
    return true
end

--- Does a node belong to the active farm's goal?
local function inGoal(t)
    local a = ns.Route:Shown()
    if not a then return false end
    local goal = ns.Finder:GoalInfo(a.result.goal)
    if goal.kind == "node" then return t.kind == goal.prof end
    if goal.kind == "item" then
        for _, y in ipairs(t.yields or {}) do if y[1] == goal.item then return true end end
        return t.item == goal.item
    end
    return false
end

local function wanted(mode, pt, t)
    if mode == "off" then return false end
    if not eligible(pt, t) then return false end
    if mode == "goal" then return inGoal(t) end
    return true
end
Pins.Wanted = wanted

local function style(f, t, scale)
    f.icon:SetTexture(DS:TypeIcon(t))
    local c = colorFor(t)
    f.border:SetVertexColor(c[1], c[2], c[3], 1)
    local size = 14 * (scale or 1) * ns.settings.pinScale
    f:SetSize(size, size)
    f:SetAlpha(ns.settings.pinAlpha)
end

local function clear(which)
    if which == "mm" then HBDPins:RemoveAllMinimapIcons(REF_MM)
    elseif which == "wm" then HBDPins:RemoveAllWorldMapIcons(REF_WM)
    elseif which == "rmm" then HBDPins:RemoveAllMinimapIcons(REF_RMM)
    elseif which == "rwm" then HBDPins:RemoveAllWorldMapIcons(REF_RWM) end
    local p = (which == "rmm" or which == "rwm") and wpPool or pool
    for _, f in ipairs(active[which]) do
        f:Hide()
        f:ClearAllPoints()
        f.data = nil
        p[#p + 1] = f
    end
    wipe(active[which])
end

local function hiddenNow()
    local s = ns.settings
    if s.hideInInstances and P:InRestrictedContent() then return true end
    if s.hideInCombat and InCombatLockdown() then return true end
    return false
end

function Pins:RefreshMinimap()
    clear("mm")
    mmZone = P:MapID()
    local mode = ns.settings.minimapNodes or "all"
    if mode == "off" or not mmZone or hiddenNow() then return end
    for _, pt in ipairs(DS:GetZoneNodes(mmZone)) do
        local t = DS:GetType(pt.t)
        if wanted(mode, pt, t) then
            local f = acquire()
            pt.map = mmZone
            f.data = pt
            style(f, t, 1)
            f.wx, f.wy = HBD:GetWorldCoordinatesFromZone(pt.x, pt.y, mmZone)
            HBDPins:AddMinimapIconMap(REF_MM, f, mmZone, pt.x, pt.y, false, false)
            active.mm[#active.mm + 1] = f
        end
    end
end

function Pins:RefreshWorldMap()
    clear("wm")
    if not WorldMapFrame or not WorldMapFrame:IsShown() then return end
    local mode = ns.settings.worldNodes or "goal"
    if mode == "off" or hiddenNow() then return end
    -- goal mode draws the farm zone's nodes (also visible on continent views, e.g. OpenMap)
    local zone, flag
    if mode == "goal" then
        local shown = ns.Route:Shown()
        if not shown then return end
        zone, flag = shown.uiMap, SHOW_CONTINENT
    else
        zone, flag = WorldMapFrame:GetMapID(), 0
    end
    if not zone or not ns.Zones[zone] then return end
    wmZone = zone
    local n = 0
    for _, pt in ipairs(DS:GetZoneNodes(zone)) do
        local t = DS:GetType(pt.t)
        if wanted(mode, pt, t) then
            local f = acquire()
            pt.map = zone
            f.data = pt
            style(f, t, 1.1)
            HBDPins:AddWorldMapIconMap(REF_WM, f, zone, pt.x, pt.y, flag)
            active.wm[#active.wm + 1] = f
            n = n + 1
            if n >= 1500 then break end
        end
    end
end

-------------------------------------------------------------------------------
-- route waypoints (HBD pins: reliable on every map view, including OpenMap's)
-------------------------------------------------------------------------------
local function acquireWP()
    local f = table.remove(wpPool)
    if not f then
        f = CreateFrame("Frame", nil, UIParent)
        f:SetSize(16, 16)
        f.ring = f:CreateTexture(nil, "BACKGROUND")
        f.ring:SetAllPoints()
        f.ring:SetTexture("Interface\\Common\\Indicator-Gray")
        f.dot = f:CreateTexture(nil, "ARTWORK")
        f.dot:SetPoint("CENTER")
        f.dot:SetSize(10, 10)
        f.dot:SetTexture("Interface\\Common\\Indicator-Gray")
        f.num = f:CreateFontString(nil, "OVERLAY", "SystemFont_Shadow_Small")
        f.num:SetPoint("CENTER", 0, 0)
    end
    return f
end

local function styleWP(f, i, current, world)
    local r, g, b = ns.Theme.route[1], ns.Theme.route[2], ns.Theme.route[3]
    local size = world and (current and 22 or 16) or (current and 14 or 8)
    f:SetSize(size, size)
    f.ring:SetVertexColor(0, 0, 0, 0.8)
    f.dot:SetSize(size - 4, size - 4)
    if current then f.dot:SetVertexColor(1, 0.85, 0.1, 1) else f.dot:SetVertexColor(r, g, b, 1) end
    f.num:SetText(world and tostring(i) or "")
    f:SetAlpha(1)
end

function Pins:RefreshRoute()
    clear("rmm")
    clear("rwm")
    local a = ns.Route:Shown()
    if not a or not a.route or #a.route.points == 0 or hiddenNow() or not ns.settings.showRoute then return end
    for i, p in ipairs(a.route.points) do
        local cur = not a.preview and i == a.index
        local fw = acquireWP()
        styleWP(fw, i, cur, true)
        HBDPins:AddWorldMapIconMap(REF_RWM, fw, a.uiMap, p.x, p.y, SHOW_CONTINENT)
        active.rwm[#active.rwm + 1] = fw
        local fm = acquireWP()
        styleWP(fm, i, cur, false)
        HBDPins:AddMinimapIconMap(REF_RMM, fm, a.uiMap, p.x, p.y, false, cur)
        active.rmm[#active.rmm + 1] = fm
    end
end

--- Distance fade for minimap pins.
local function fade()
    if not ns.settings.distanceFade or #active.mm == 0 then return end
    local px, py = HBD:GetPlayerWorldPosition()
    if not px then return end
    local far = ns.settings.fadeYards
    local base = ns.settings.pinAlpha
    for _, f in ipairs(active.mm) do
        if f.wx then
            local dx, dy = f.wx - px, f.wy - py
            local d = math.sqrt(dx * dx + dy * dy)
            f:SetAlpha(base * ns.Clamp(1.15 - d / far, 0.35, 1))
        end
    end
end

function Pins:RefreshAll()
    Pins:RefreshMinimap()
    Pins:RefreshWorldMap()
    Pins:RefreshRoute()
end

local function safe(fn)
    return function(...)
        local ok, err = pcall(fn, ...)
        if not ok then ns:Debug("pins:", err) end
    end
end

function Pins:Init()
    local mm, wmr, all, route = safe(Pins.RefreshMinimap), safe(Pins.RefreshWorldMap), safe(Pins.RefreshAll), safe(Pins.RefreshRoute)
    ns:On("ZONE_CHANGED_NEW_AREA", function() ns.After(0.5, function() mm(Pins) end) end)
    ns:On("PLAYER_ENTERING_WORLD", function() ns.After(1, function() all(Pins) end) end)
    ns:On("FORAGER_NODES_CHANGED", function(_, map)
        if not map or map == mmZone then mm(Pins) end
        if not map or map == wmZone then wmr(Pins) end
    end)
    ns:On("FORAGER_SETTINGS_CHANGED", function() all(Pins) end)
    ns:On("FORAGER_ROUTE_CHANGED", function() all(Pins) end)
    ns:On("FORAGER_ROUTE_PROGRESS", function() route(Pins) end)
    ns:On("PLAYER_REGEN_DISABLED", function()
        if ns.settings.hideInCombat then clear("mm") clear("wm") clear("rmm") clear("rwm") end
    end)
    ns:On("PLAYER_REGEN_ENABLED", function() if ns.settings.hideInCombat then all(Pins) end end)
    ns:On("SKILL_LINES_CHANGED", function() ns.After(0.2, function() all(Pins) end) end)
    if WorldMapFrame then
        hooksecurefunc(WorldMapFrame, "OnMapChanged", function() if (ns.settings.worldNodes or "goal") == "all" then wmr(Pins) end end)
        WorldMapFrame:HookScript("OnShow", function() wmr(Pins) end)
        WorldMapFrame:HookScript("OnHide", function()
            clear("wm")
            if ns.Route.preview then ns.Route:Preview(nil) end
        end)
    end
    ns.Ticker(0.5, fade)
end
