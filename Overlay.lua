-- Overlay: recommended area + route lines + mob camps on the world map and minimap,
-- plus the next-waypoint arrow with distance and loop progress.
local _, ns = ...
local Overlay = {}
ns.Overlay = Overlay
local HBD = LibStub("HereBeDragons-2.0")
local P, Route = ns.Player, ns.Route

local ROUTE_COLOR = { 0.2, 0.85, 1 }
local AREA_COLOR = { 1, 0.82, 0 }
local CAMP_COLOR = { 1, 0.35, 0.35 }

-------------------------------------------------------------------------------
-- world map
-------------------------------------------------------------------------------
local wm, wmLines, wmTex = nil, {}, {}

local function wmLine(i)
    local l = wmLines[i]
    if not l then
        l = wm:CreateLine(nil, "OVERLAY")
        wmLines[i] = l
    end
    l:Show()
    return l
end
local function wmTexture(i)
    local t = wmTex[i]
    if not t then
        t = wm:CreateTexture(nil, "ARTWORK")
        wmTex[i] = t
    end
    t:Show()
    return t
end

local function hideFrom(list, n)
    for i = n, #list do list[i]:Hide() end
end

function Overlay:DrawWorldMap()
    if not wm then return end
    local a = Route.active
    local s = ns.settings
    local mapID = WorldMapFrame:GetMapID()
    local nl, nt = 1, 1
    if a and a.uiMap == mapID and not (s.hideInCombat and InCombatLockdown()) then
        local w, h = wm:GetWidth(), wm:GetHeight()
        local scale = WorldMapFrame.ScrollContainer and WorldMapFrame.ScrollContainer:GetCanvasScale() or 1
        local thick = 3 / math.max(0.3, scale)
        local r = a.result
        -- area
        if s.showArea and r.rect then
            local x1, y1, x2, y2 = r.rect[1], r.rect[2], r.rect[3], r.rect[4]
            local fill = wmTexture(nt) nt = nt + 1
            fill:SetColorTexture(AREA_COLOR[1], AREA_COLOR[2], AREA_COLOR[3], s.areaAlpha)
            fill:ClearAllPoints()
            fill:SetPoint("TOPLEFT", wm, "TOPLEFT", x1 * w, -y1 * h)
            fill:SetPoint("BOTTOMRIGHT", wm, "TOPLEFT", x2 * w, -y2 * h)
            local corners = { { x1, y1 }, { x2, y1 }, { x2, y2 }, { x1, y2 } }
            for i = 1, 4 do
                local p, q = corners[i], corners[i % 4 + 1]
                local l = wmLine(nl) nl = nl + 1
                l:SetThickness(thick)
                l:SetColorTexture(AREA_COLOR[1], AREA_COLOR[2], AREA_COLOR[3], 0.9)
                l:SetStartPoint("TOPLEFT", wm, p[1] * w, -p[2] * h)
                l:SetEndPoint("TOPLEFT", wm, q[1] * w, -q[2] * h)
            end
        end
        -- mob camps
        if s.showMobCamps and r.mobs and r.route then
            for _, c in ipairs(r.route.points) do
                local t = wmTexture(nt) nt = nt + 1
                t:SetTexture("Interface\\Common\\Indicator-Red")
                t:SetVertexColor(CAMP_COLOR[1], CAMP_COLOR[2], CAMP_COLOR[3], 0.9)
                t:ClearAllPoints()
                local sz = 10 / math.max(0.3, scale)
                t:SetSize(sz, sz)
                t:SetPoint("CENTER", wm, "TOPLEFT", c.x * w, -c.y * h)
            end
        end
        -- route
        local pts = a.route.points
        if s.showRoute and #pts > 1 then
            for i = 1, #pts do
                local p, q = pts[i], pts[i % #pts + 1]
                local l = wmLine(nl) nl = nl + 1
                l:SetThickness(thick)
                local hl = (i == ((a.index - 2) % #pts) + 1)
                l:SetColorTexture(ROUTE_COLOR[1], ROUTE_COLOR[2], ROUTE_COLOR[3], s.routeAlpha * (hl and 1 or 0.75))
                l:SetStartPoint("TOPLEFT", wm, p.x * w, -p.y * h)
                l:SetEndPoint("TOPLEFT", wm, q.x * w, -q.y * h)
            end
            local wp = pts[a.index]
            if wp then
                local t = wmTexture(nt) nt = nt + 1
                t:SetTexture("Interface\\Common\\Indicator-Yellow")
                local sz = 18 / math.max(0.3, scale)
                t:SetSize(sz, sz)
                t:SetVertexColor(1, 1, 1, 1)
                t:ClearAllPoints()
                t:SetPoint("CENTER", wm, "TOPLEFT", wp.x * w, -wp.y * h)
            end
        end
    end
    hideFrom(wmLines, nl)
    hideFrom(wmTex, nt)
end

local function setupWorldMap()
    if wm or not WorldMapFrame then return end
    local canvas = WorldMapFrame.GetCanvas and WorldMapFrame:GetCanvas()
    if not canvas then return end
    wm = CreateFrame("Frame", nil, canvas)
    wm:SetAllPoints(canvas)
    wm:SetFrameLevel(canvas:GetFrameLevel() + 2000)
    local lastScale
    wm:SetScript("OnUpdate", function(self)
        local sc = WorldMapFrame.ScrollContainer and WorldMapFrame.ScrollContainer:GetCanvasScale()
        if sc ~= lastScale then lastScale = sc Overlay:DrawWorldMap() end
    end)
    wm:SetScript("OnSizeChanged", function() Overlay:DrawWorldMap() end)
    hooksecurefunc(WorldMapFrame, "OnMapChanged", function() Overlay:DrawWorldMap() end)
    WorldMapFrame:HookScript("OnShow", function() Overlay:DrawWorldMap() end)
end

-------------------------------------------------------------------------------
-- minimap
-------------------------------------------------------------------------------
local mm, mmLines = nil, {}
local mmWorld = {} -- cached world coords for the active route/area

local function mmLine(i)
    local l = mmLines[i]
    if not l then
        l = mm:CreateLine(nil, "OVERLAY")
        mmLines[i] = l
    end
    l:Show()
    return l
end

local function radius()
    if C_Minimap and C_Minimap.GetViewRadius then
        local r = C_Minimap.GetViewRadius()
        if r and r > 0 then return r end
    end
    local zoom = Minimap:GetZoom()
    local outdoor = { [0] = 466 + 2 / 3, 400, 333 + 1 / 3, 266 + 2 / 6, 200, 133 + 1 / 3 }
    return (outdoor[zoom] or 233) / 2
end

-- Clip segment (x1,y1)-(x2,y2) to a circle of radius R centred at 0,0 (Liang-Barsky style for circles).
local function clipCircle(x1, y1, x2, y2, R)
    local dx, dy = x2 - x1, y2 - y1
    local a = dx * dx + dy * dy
    if a == 0 then return nil end
    local b = 2 * (x1 * dx + y1 * dy)
    local c = x1 * x1 + y1 * y1 - R * R
    local disc = b * b - 4 * a * c
    if disc <= 0 then return nil end
    local sq = math.sqrt(disc)
    local t1, t2 = (-b - sq) / (2 * a), (-b + sq) / (2 * a)
    local s, e = math.max(0, t1), math.min(1, t2)
    if s >= e then return nil end
    return x1 + dx * s, y1 + dy * s, x1 + dx * e, y1 + dy * e
end
local function clipSquare(x1, y1, x2, y2, R)
    local t0, t1 = 0, 1
    local dx, dy = x2 - x1, y2 - y1
    local p = { -dx, dx, -dy, dy }
    local q = { x1 + R, R - x1, y1 + R, R - y1 }
    for i = 1, 4 do
        if p[i] == 0 then
            if q[i] < 0 then return nil end
        else
            local t = q[i] / p[i]
            if p[i] < 0 then if t > t0 then t0 = t end else if t < t1 then t1 = t end end
        end
    end
    if t0 > t1 then return nil end
    return x1 + dx * t0, y1 + dy * t0, x1 + dx * t1, y1 + dy * t1
end

function Overlay:CacheWorld()
    wipe(mmWorld)
    local a = Route.active
    if not a then return end
    local function w(x, y)
        local wx, wy = HBD:GetWorldCoordinatesFromZone(x, y, a.uiMap)
        return { wx, wy }
    end
    mmWorld.route = {}
    for i, p in ipairs(a.route.points) do mmWorld.route[i] = w(p.x, p.y) end
    if a.result.rect then
        local r = a.result.rect
        mmWorld.area = { w(r[1], r[2]), w(r[3], r[2]), w(r[3], r[4]), w(r[1], r[4]) }
    end
end

function Overlay:DrawMinimap()
    if not mm then return end
    local n = 1
    local a = Route.active
    local s = ns.settings
    local px, py = HBD:GetPlayerWorldPosition()
    local hide = not a or not px or (s.hideInCombat and InCombatLockdown()) or (s.hideInInstances and P:InRestrictedContent())
    if not hide and mmWorld.route then
        local R = radius()
        local half = mm:GetWidth() / 2
        local rotate = GetCVar("rotateMinimap") == "1"
        local facing = rotate and ns.Safe(GetPlayerFacing()) or 0
        local sinF, cosF = math.sin(facing or 0), math.cos(facing or 0)
        local square = GetMinimapShape and GetMinimapShape() == "SQUARE"
        local function toPx(pt)
            local xd, yd = px - pt[1], py - pt[2]
            if rotate then xd, yd = xd * cosF - yd * sinF, xd * sinF + yd * cosF end
            return xd / R * half, -yd / R * half
        end
        local function seg(p, q, color, alpha, thick)
            local x1, y1 = toPx(p)
            local x2, y2 = toPx(q)
            local lim = half * 0.95
            local cx1, cy1, cx2, cy2
            if square then cx1, cy1, cx2, cy2 = clipSquare(x1, y1, x2, y2, lim)
            else cx1, cy1, cx2, cy2 = clipCircle(x1, y1, x2, y2, lim) end
            if cx1 then
                local l = mmLine(n) n = n + 1
                l:SetThickness(thick)
                l:SetColorTexture(color[1], color[2], color[3], alpha)
                l:SetStartPoint("CENTER", mm, cx1, cy1)
                l:SetEndPoint("CENTER", mm, cx2, cy2)
            end
        end
        if s.showArea and mmWorld.area then
            for i = 1, 4 do seg(mmWorld.area[i], mmWorld.area[i % 4 + 1], AREA_COLOR, 0.8, 1.5) end
        end
        if s.showRoute then
            local r = mmWorld.route
            if #r > 1 then
                for i = 1, #r do seg(r[i], r[i % #r + 1], ROUTE_COLOR, s.routeAlpha, 2) end
            end
        end
    end
    hideFrom(mmLines, n)
end

local function setupMinimap()
    if mm then return end
    mm = CreateFrame("Frame", nil, Minimap)
    mm:SetAllPoints(Minimap)
    mm:SetFrameLevel(Minimap:GetFrameLevel() + 5)
end

-------------------------------------------------------------------------------
-- arrow
-------------------------------------------------------------------------------
local arrow
local function setupArrow()
    arrow = CreateFrame("Button", "ForagerArrow", UIParent)
    arrow:SetSize(56, 56)
    arrow:SetMovable(true)
    arrow:EnableMouse(true)
    arrow:RegisterForDrag("LeftButton")
    arrow:SetScript("OnDragStart", arrow.StartMoving)
    arrow:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local p, _, rp, x, y = self:GetPoint()
        ns.settings.arrowPos = { p, rp, x, y }
    end)
    local pos = ns.settings.arrowPos
    if pos then arrow:SetPoint(pos[1], UIParent, pos[2], pos[3], pos[4]) else arrow:SetPoint("TOP", UIParent, "TOP", 0, -140) end
    arrow.tex = arrow:CreateTexture(nil, "ARTWORK")
    arrow.tex:SetAllPoints()
    arrow.tex:SetTexture("Interface\\Minimap\\MinimapArrow")
    arrow.tex:SetVertexColor(ROUTE_COLOR[1], ROUTE_COLOR[2], ROUTE_COLOR[3])
    arrow.dist = arrow:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    arrow.dist:SetPoint("TOP", arrow, "BOTTOM", 0, -2)
    arrow.info = arrow:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    arrow.info:SetPoint("TOP", arrow.dist, "BOTTOM", 0, -2)
    arrow:SetScript("OnClick", function(_, btn) if btn == "RightButton" then Route:Skip() end end)
    arrow:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    arrow:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        GameTooltip:AddLine("Forager route")
        GameTooltip:AddLine("Drag to move. Right-click: skip waypoint.", 0.8, 0.8, 0.8)
        GameTooltip:Show()
    end)
    arrow:SetScript("OnLeave", function() GameTooltip:Hide() end)
    arrow:Hide()
end

function Overlay:UpdateArrow()
    local a = Route.active
    if not arrow then return end
    if not a or not ns.settings.showArrow or #a.route.points == 0 or (ns.settings.hideInCombat and InCombatLockdown()) then
        arrow:Hide()
        return
    end
    local wp, d, prog, loops, idx = Route:Next()
    local px, py, inst = HBD:GetPlayerWorldPosition()
    local facing = ns.Safe(GetPlayerFacing())
    if not wp or not px or not facing then
        arrow:Show()
        arrow.tex:SetAlpha(0.3)
        arrow.dist:SetText(P:ZoneName(a.uiMap))
        arrow.info:SetText("Travel to the zone to start")
        return
    end
    local wx, wy = HBD:GetWorldCoordinatesFromZone(wp.x, wp.y, a.uiMap)
    local angle, yards = HBD:GetWorldVector(inst, px, py, wx, wy)
    if not angle then arrow:Hide() return end
    arrow:Show()
    arrow.tex:SetAlpha(1)
    arrow.tex:SetRotation(angle - facing)
    arrow.dist:SetText(string.format("%d yd", yards or d or 0))
    arrow.info:SetText(string.format("Waypoint %d/%d  ·  loop %d  ·  %d%%", idx, #a.route.points, loops + 1, prog * 100))
end

-------------------------------------------------------------------------------
function Overlay:Init()
    setupWorldMap()
    setupMinimap()
    setupArrow()
    ns:On("FORAGER_ROUTE_CHANGED", function()
        Overlay:CacheWorld()
        Overlay:DrawWorldMap()
        Overlay:DrawMinimap()
        Overlay:UpdateArrow()
    end)
    ns:On("FORAGER_ROUTE_PROGRESS", function() Overlay:DrawWorldMap() end)
    ns:On("FORAGER_SETTINGS_CHANGED", function() Overlay:DrawWorldMap() Overlay:DrawMinimap() end)
    ns:On("PLAYER_REGEN_DISABLED", function() if ns.settings.hideInCombat then Overlay:DrawMinimap() Overlay:UpdateArrow() end end)
    ns.Ticker(0.1, function()
        if Route.active then
            Route:Update()
            Overlay:DrawMinimap()
            Overlay:UpdateArrow()
        end
    end)
end
