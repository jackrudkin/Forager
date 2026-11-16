-- Overlay: the route on the world map (any map that contains the farm zone, so continent views
-- and OpenMap's seamless map work too) and the minimap. Forager draws no node pins: nodes are the
-- game's own tracking. Optional farm-area outline, route HUD with arrow, optional game map pin /
-- TomTom waypoint, "open the world map at the farm".
local _, ns = ...
local Overlay = {}
ns.Overlay = Overlay
local HBD = LibStub("HereBeDragons-2.0")
local P, Route = ns.Player, ns.Route
local T = ns.Theme

local function guard(name, fn)
    return function(...)
        local ok, err = pcall(fn, ...)
        if not ok then
            Overlay.lastError = name .. ": " .. tostring(err)
            ns:Debug(Overlay.lastError)
        end
    end
end

-------------------------------------------------------------------------------
-- translate route-zone coords to the map being displayed
-------------------------------------------------------------------------------
--- OpenMap (seamless world map) API, when OpenMap is loaded and its stitched map is showing.
--- docs: github.com/openmap-world/openmap docs/api.md (major 1)
local function openMap()
    local OM = OpenMapAPI
    if type(OM) == "table" and OM.major == 1 and OM.IsStitched then
        local ok, on = pcall(OM.IsStitched)
        if ok and on then return OM end
    end
end
Overlay.OpenMapAPI = openMap

--- Route-zone coords -> coords on the map under the world map's canvas. On OpenMap's stitched map the
--- canvas belongs to whatever zone/continent the view is on, and points off it (outside 0..1) are kept.
local function toMap(x, y, fromMap, toMapID)
    local OM = openMap()
    if OM then
        local ok, u, v = pcall(OM.WorldFromMap, fromMap, x, y)
        if ok and u then
            local ok2, hx, hy = pcall(OM.MapFromWorld, toMapID, u, v)
            if ok2 and hx then return hx, hy end
        end
    end
    if fromMap == toMapID then return x, y end
    local tx, ty = HBD:TranslateZoneCoordinates(x, y, fromMap, toMapID, true)
    return tx, ty
end

-------------------------------------------------------------------------------
-- world map
-------------------------------------------------------------------------------
local wm, wmLines, wmTex = nil, {}, {}

local function wmLine(i)
    local l = wmLines[i]
    if not l then l = wm:CreateLine(nil, "OVERLAY") wmLines[i] = l end
    l:Show()
    return l
end
local function wmTexture(i)
    local t = wmTex[i]
    if not t then t = wm:CreateTexture(nil, "ARTWORK") wmTex[i] = t end
    t:Show()
    return t
end
local function hideFrom(list, n) for i = n, #list do list[i]:Hide() end end

local function drawWorldMap()
    if not wm then return end
    local a = Route:Shown()
    local s = ns.settings
    local mapID = WorldMapFrame:GetMapID()
    local nl, nt = 1, 1
    if a and mapID and not (s.hideInCombat and InCombatLockdown()) then
        local pts0 = a.route and a.route.points
        local w, h = wm:GetWidth(), wm:GetHeight()
        local scale = (WorldMapFrame.ScrollContainer and WorldMapFrame.ScrollContainer.GetCanvasScale and WorldMapFrame.ScrollContainer:GetCanvasScale()) or 1
        local thick = 3 / math.max(0.25, scale)
        local zoneView = mapID == a.uiMap
        local r = a.result
        -- skip maps that don't contain the farm (translated centre far outside the canvas)
        local cx, cy = 0.5, 0.5
        if r.rect then cx, cy = (r.rect[1] + r.rect[3]) / 2, (r.rect[2] + r.rect[4]) / 2
        elseif pts0 and pts0[1] then cx, cy = pts0[1].x, pts0[1].y end
        local tx, ty = toMap(cx, cy, a.uiMap, mapID)
        local OM = openMap()
        if not tx or (not OM and (tx < -0.2 or tx > 1.2 or ty < -0.2 or ty > 1.2)) then
            hideFrom(wmLines, 1) hideFrom(wmTex, 1)
            return
        end
        -- stay above OpenMap's stitched art (it covers canvas frames below ArtTopLevel)
        local level = wm:GetParent():GetFrameLevel() + 1500
        if OM and OM.ArtTopLevel then
            local ok, top = pcall(OM.ArtTopLevel)
            if ok and type(top) == "number" then level = math.max(level, top + 10) end
        end
        if wm:GetFrameLevel() ~= level then wm:SetFrameLevel(level) end
        if s.showArea and r.rect then
            local x1, y1 = toMap(r.rect[1], r.rect[2], a.uiMap, mapID)
            local x2, y2 = toMap(r.rect[3], r.rect[4], a.uiMap, mapID)
            if x1 and x2 then
                local fill = wmTexture(nt) nt = nt + 1
                fill:SetColorTexture(r.cave and T.cave[1] or T.area[1], r.cave and T.cave[2] or T.area[2], r.cave and T.cave[3] or T.area[3], s.areaAlpha)
                fill:ClearAllPoints()
                fill:SetPoint("TOPLEFT", wm, "TOPLEFT", x1 * w, -y1 * h)
                fill:SetPoint("BOTTOMRIGHT", wm, "TOPLEFT", x2 * w, -y2 * h)
                local corners = { { x1, y1 }, { x2, y1 }, { x2, y2 }, { x1, y2 } }
                local oc = r.cave and T.cave or T.area
                for i = 1, 4 do
                    local p, q = corners[i], corners[i % 4 + 1]
                    local l = wmLine(nl) nl = nl + 1
                    l:SetThickness(thick * 0.6)
                    l:SetColorTexture(oc[1], oc[2], oc[3], 0.7)
                    l:SetStartPoint("TOPLEFT", wm, p[1] * w, -p[2] * h)
                    l:SetEndPoint("TOPLEFT", wm, q[1] * w, -q[2] * h)
                end
            end
        end
        local pts = a.route.points
        if s.showRoute and #pts > 1 then
            local prev
            for i = 1, #pts + 1 do
                local p = pts[(i - 1) % #pts + 1]
                local x, y = toMap(p.x, p.y, a.uiMap, mapID)
                if x and prev then
                    local l = wmLine(nl) nl = nl + 1
                    l:SetThickness(thick * (zoneView and 0.75 or 0.55))
                    l:SetColorTexture(T.route[1], T.route[2], T.route[3], s.routeAlpha)
                    l:SetStartPoint("TOPLEFT", wm, prev[1] * w, -prev[2] * h)
                    l:SetEndPoint("TOPLEFT", wm, x * w, -y * h)
                end
                prev = x and { x, y } or nil
            end
        end
    end
    hideFrom(wmLines, nl)
    hideFrom(wmTex, nt)
end
Overlay.DrawWorldMap = guard("world map", drawWorldMap)
function Overlay:WorldMapLayer() return wm end -- tests / diagnostics

local function setupWorldMap()
    if wm or not WorldMapFrame then return end
    local canvas = WorldMapFrame.GetCanvas and WorldMapFrame:GetCanvas()
    if not canvas then return end
    wm = CreateFrame("Frame", nil, canvas)
    wm:SetAllPoints(canvas)
    wm:SetFrameLevel(canvas:GetFrameLevel() + 1500)
    local lastScale
    wm:SetScript("OnUpdate", function()
        local sc = WorldMapFrame.ScrollContainer and WorldMapFrame.ScrollContainer.GetCanvasScale and WorldMapFrame.ScrollContainer:GetCanvasScale()
        if sc ~= lastScale then lastScale = sc Overlay.DrawWorldMap() end
    end)
    wm:SetScript("OnSizeChanged", function() Overlay.DrawWorldMap() end)
    hooksecurefunc(WorldMapFrame, "OnMapChanged", function() Overlay.DrawWorldMap() end)
    WorldMapFrame:HookScript("OnShow", function() Overlay.DrawWorldMap() end)
    WorldMapFrame:HookScript("OnHide", function()
        if Route.preview then Route:Preview(nil) end
        if Overlay.restoreMain and ns.Main.frame then ns.Main.frame:Show() end
        Overlay.restoreMain = nil
    end)
    -- OpenMap: redraw when its view moves or it switches between its map and Blizzard's
    local OM = OpenMapAPI
    if type(OM) == "table" and OM.major == 1 and OM.RegisterCallback then
        pcall(OM.RegisterCallback, Overlay, "OpenMap_ViewChanged", function() Overlay.DrawWorldMap() end)
        pcall(OM.RegisterCallback, Overlay, "OpenMap_StitchedChanged", function() Overlay.DrawWorldMap() end)
    end
end

--- Open the world map at the farm zone (or a given zone). Works with OpenMap (same WorldMapFrame).
--- With OpenMap's stitched map: glide its view to the farm area, zoomed so the area fills about a third.
local function showOnOpenMap(OM, shown, uiMap)
    local r = shown and shown.result
    local x1, y1, x2, y2 = 0.3, 0.3, 0.7, 0.7
    if r and r.rect then x1, y1, x2, y2 = r.rect[1], r.rect[2], r.rect[3], r.rect[4] end
    local ok1, u1, v1 = pcall(OM.WorldFromMap, uiMap, x1, y1)
    local ok2, u2, v2 = pcall(OM.WorldFromMap, uiMap, x2, y2)
    if not (ok1 and ok2 and u1 and u2) then return false end
    local span = math.max(math.abs(u2 - u1), math.abs(v2 - v1), 0.002)
    local zoom = ns.Clamp(1 / (span * 3), 1, 40)
    local ok, res = pcall(OM.ShowWorld, (u1 + u2) / 2, (v1 + v2) / 2, zoom)
    return ok and res
end

--- Open the world map at the farm zone (or a given zone), with the route drawn. The Forager window is
--- hidden while the map is open (it would cover it) and comes back when the map closes.
function Overlay:OpenMapTo(uiMap)
    local shown = Route:Shown()
    uiMap = uiMap or (shown and shown.uiMap) or P:MapID()
    if not uiMap or not WorldMapFrame then return end
    if ns.Main.frame and ns.Main.frame:IsShown() then
        ns.Main.frame:Hide()
        Overlay.restoreMain = true
    end
    if not WorldMapFrame:IsShown() then
        if OpenWorldMap then pcall(OpenWorldMap, uiMap)
        elseif ToggleWorldMap then pcall(ToggleWorldMap) end
    end
    local OM = openMap()
    if not (OM and showOnOpenMap(OM, shown, uiMap)) and WorldMapFrame.SetMapID then
        pcall(WorldMapFrame.SetMapID, WorldMapFrame, uiMap)
    end
    Overlay.DrawWorldMap()
    -- OpenMap builds its stitched map on first showing: centre on the farm again once it's up
    ns.After(0.3, function()
        local om = openMap()
        if om and WorldMapFrame:IsShown() then showOnOpenMap(om, Route:Shown(), uiMap) end
        Overlay.DrawWorldMap()
    end)
end

-------------------------------------------------------------------------------
-- game map pin + TomTom on the farm spot
-------------------------------------------------------------------------------
local tomtomUID, ourPin

--- force = set even if the "on start" settings are off (explicit Set waypoint buttons).
function Overlay:SetFarmPin(result, force)
    Overlay:ClearFarmPin()
    if not result or not result.uiMap then return end
    local x, y
    if result.rect then x, y = (result.rect[1] + result.rect[3]) / 2, (result.rect[2] + result.rect[4]) / 2
    else x, y = 0.5, 0.5 end
    local title = "Forager: " .. ns.Finder:GoalInfo(result.goal).label .. (result.areaName and (" - " .. result.areaName) or "")
    if (force or ns.settings.gamePin) and C_Map and C_Map.SetUserWaypoint and UiMapPoint and UiMapPoint.CreateFromCoordinates then
        local ok = pcall(function()
            if C_Map.CanSetUserWaypointOnMap and not C_Map.CanSetUserWaypointOnMap(result.uiMap) then error("not allowed") end
            C_Map.SetUserWaypoint(UiMapPoint.CreateFromCoordinates(result.uiMap, x, y))
            if C_SuperTrack and C_SuperTrack.SetSuperTrackedUserWaypoint then C_SuperTrack.SetSuperTrackedUserWaypoint(true) end
        end)
        ourPin = ok or nil
    end
    if (force or ns.settings.tomtom) and TomTom and TomTom.AddWaypoint then
        local ok, uid = pcall(TomTom.AddWaypoint, TomTom, result.uiMap, x, y, { title = title, persistent = false, minimap = true, world = true, from = "Forager" })
        if ok then tomtomUID = uid end
    end
end

function Overlay:ClearFarmPin()
    if ourPin and C_Map and C_Map.ClearUserWaypoint then pcall(C_Map.ClearUserWaypoint) end
    ourPin = nil
    if tomtomUID and TomTom and TomTom.RemoveWaypoint then pcall(TomTom.RemoveWaypoint, TomTom, tomtomUID) end
    tomtomUID = nil
end

-------------------------------------------------------------------------------
-- minimap lines
-------------------------------------------------------------------------------
local mm, mmLines = nil, {}
local mmWorld = {}

local function mmLine(i)
    local l = mmLines[i]
    if not l then l = mm:CreateLine(nil, "OVERLAY") mmLines[i] = l end
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
    local a = Route:Shown()
    if not a then return end
    local function w(x, y)
        local wx, wy = HBD:GetWorldCoordinatesFromZone(x, y, a.uiMap)
        if not wx then return nil end
        return { wx, wy }
    end
    mmWorld.route = {}
    for i, p in ipairs(a.route.points) do mmWorld.route[i] = w(p.x, p.y) or false end
    if a.result.rect then
        local r = a.result.rect
        local c1, c2, c3, c4 = w(r[1], r[2]), w(r[3], r[2]), w(r[3], r[4]), w(r[1], r[4])
        if c1 and c2 and c3 and c4 then mmWorld.area = { c1, c2, c3, c4 } end
    end
end

local function drawMinimap()
    if not mm then return end
    local n = 1
    local a = Route:Shown()
    local s = ns.settings
    local px, py = HBD:GetPlayerWorldPosition()
    local hide = not a or not px or (s.hideInCombat and InCombatLockdown()) or (s.hideInInstances and P:InRestrictedContent())
    if not hide and mmWorld.route and not a.preview then
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
            local oc = a.result and a.result.cave and T.cave or T.area
            for i = 1, 4 do seg(mmWorld.area[i], mmWorld.area[i % 4 + 1], oc, 0.55, 1) end
        end
        local r, mode = mmWorld.route, s.routeMinimap
        local alpha = s.routeAlpha * 0.85
        if mode == "loop" and #r > 1 then
            for i = 1, #r do
                local p, q = r[i], r[i % #r + 1]
                if p and q then seg(p, q, T.route, alpha, 1.5) end
            end
        elseif mode == "next" and #r > 0 then
            -- like a sat-nav: you -> next stop, then the following legs, fading out
            local idx = a.index or 1
            local prev = { px, py }
            for k = 0, math.min(3, #r - 1) do
                local q = r[(idx - 1 + k) % #r + 1]
                if q then
                    seg(prev, q, T.route, alpha * (1 - k * 0.2), k == 0 and 2 or 1.5)
                    prev = q
                end
            end
        end
    end
    hideFrom(mmLines, n)
end
Overlay.DrawMinimap = guard("minimap", drawMinimap)

local function setupMinimap()
    if mm then return end
    mm = CreateFrame("Frame", nil, Minimap)
    mm:SetAllPoints(Minimap)
    mm:SetFrameLevel(Minimap:GetFrameLevel() + 5)
end

-------------------------------------------------------------------------------
-- route HUD (arrow + next waypoint + quick buttons)
-------------------------------------------------------------------------------
local hud

local function flatButton(parent, text, w, onClick)
    local b = CreateFrame("Button", nil, parent, "BackdropTemplate")
    b:SetSize(w, 18)
    b:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
    b:SetBackdropColor(T.panel2[1], T.panel2[2], T.panel2[3], 1)
    b:SetBackdropBorderColor(T.border[1], T.border[2], T.border[3], 1)
    b.text = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    b.text:SetPoint("CENTER")
    b.text:SetText(text)
    b:SetScript("OnEnter", function(self) self:SetBackdropBorderColor(T.accent[1], T.accent[2], T.accent[3], 1) end)
    b:SetScript("OnLeave", function(self) self:SetBackdropBorderColor(T.border[1], T.border[2], T.border[3], 1) end)
    b:SetScript("OnClick", onClick)
    return b
end

local function setupHUD()
    hud = CreateFrame("Frame", "ForagerHUD", UIParent, "BackdropTemplate")
    hud:SetSize(250, 74)
    hud:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
    hud:SetBackdropColor(T.bg[1], T.bg[2], T.bg[3], 0.88)
    hud:SetBackdropBorderColor(T.border[1], T.border[2], T.border[3], 1)
    hud:SetMovable(true)
    hud:EnableMouse(true)
    hud:SetClampedToScreen(true)
    hud:RegisterForDrag("LeftButton")
    hud:SetScript("OnDragStart", hud.StartMoving)
    hud:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local p, _, rp, x, y = self:GetPoint()
        ns.settings.hudPos = { p, rp, x, y }
    end)
    local pos = ns.settings.hudPos
    if pos then hud:SetPoint(pos[1], UIParent, pos[2], pos[3], pos[4]) else hud:SetPoint("TOP", UIParent, "TOP", 0, -120) end
    hud.arrow = hud:CreateTexture(nil, "ARTWORK")
    hud.arrow:SetSize(44, 44)
    hud.arrow:SetPoint("LEFT", 8, 4)
    hud.arrow:SetTexture("Interface\\Minimap\\MinimapArrow")
    hud.arrow:SetVertexColor(T.route[1], T.route[2], T.route[3])
    hud.dist = hud:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    hud.dist:SetPoint("TOP", hud.arrow, "BOTTOM", 0, 2)
    hud.title = hud:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    hud.title:SetPoint("TOPLEFT", 60, -7)
    hud.title:SetPoint("RIGHT", -8, 0)
    hud.title:SetJustifyH("LEFT")
    hud.title:SetWordWrap(false)
    hud.info = hud:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    hud.info:SetPoint("TOPLEFT", hud.title, "BOTTOMLEFT", 0, -3)
    hud.info:SetPoint("RIGHT", -8, 0)
    hud.info:SetJustifyH("LEFT")
    hud.info:SetWordWrap(false)
    local stop = flatButton(hud, "Stop", 46, function() Route:Stop() end)
    stop:SetPoint("BOTTOMRIGHT", -6, 6)
    local skip = flatButton(hud, "Skip", 46, function() Route:Skip() end)
    skip:SetPoint("RIGHT", stop, "LEFT", -4, 0)
    local map = flatButton(hud, "Map", 46, function() Overlay:OpenMapTo() end)
    map:SetPoint("RIGHT", skip, "LEFT", -4, 0)
    local win = flatButton(hud, "Forager", 60, function() ns.Main:Toggle("farm") end)
    win:SetPoint("RIGHT", map, "LEFT", -4, 0)
    hud:Hide()
end

local function updateHUD()
    local a = Route.active
    if not hud then return end
    if not a or not ns.settings.hud or (ns.settings.hideInCombat and InCombatLockdown()) then hud:Hide() return end
    local r = a.result
    local goal = ns.Finder:GoalInfo(r.goal)
    hud.title:SetText(string.format("%s · %s%s", goal.label, r.areaName and (r.areaName .. ", ") or "", r.zoneName or P:ZoneName(a.uiMap)))
    hud:Show()
    local n = #a.route.points
    if n == 0 then
        hud.arrow:SetAlpha(0.25)
        hud.dist:SetText("")
        hud.info:SetText(r.source == "fish" and "Fish anywhere in this zone's water" or "No route points")
        return
    end
    local wp, d, prog, loops, idx = Route:Next()
    local px, py, inst = HBD:GetPlayerWorldPosition()
    local facing = ns.Safe(GetPlayerFacing())
    local wx, wy = HBD:GetWorldCoordinatesFromZone(wp.x, wp.y, a.uiMap)
    local angle, yards
    if px and wx and facing then angle, yards = HBD:GetWorldVector(inst, px, py, wx, wy) end
    if not angle then
        hud.arrow:SetAlpha(0.25)
        hud.dist:SetText("")
        hud.info:SetText("Travel to " .. (r.zoneName or "the zone") .. " to start  ·  " .. n .. " stops")
        return
    end
    hud.arrow:SetAlpha(1)
    hud.arrow:SetRotation(angle - facing)
    hud.dist:SetText(string.format("%d yd", yards or d or 0))
    local rate = r.mode == "skill" and string.format("%.0f skill-ups/h", r.perHour) or (ns.Money(r.perHour, true) .. "/h")
    hud.info:SetText(string.format("Stop %d/%d  ·  loop %d (%d%%)  ·  %s", idx, n, loops + 1, prog * 100, rate))
end
Overlay.UpdateArrow = guard("hud", updateHUD)

-------------------------------------------------------------------------------
function Overlay:Init()
    setupWorldMap()
    setupMinimap()
    setupHUD()
    ns:On("FORAGER_ROUTE_CHANGED", function()
        local ok, err = pcall(Overlay.CacheWorld, Overlay)
        if not ok then Overlay.lastError = "cache: " .. tostring(err) end
        Overlay.DrawWorldMap()
        Overlay.DrawMinimap()
        Overlay.UpdateArrow()
        if Route.active then
            if Overlay.pinFor ~= Route.active.result then Overlay:SetFarmPin(Route.active.result) Overlay.pinFor = Route.active.result end
        elseif Overlay.pinFor then
            Overlay:ClearFarmPin()
            Overlay.pinFor = nil
        end
    end)
    ns:On("FORAGER_ROUTE_PROGRESS", function() Overlay.DrawWorldMap() end)
    ns:On("FORAGER_SETTINGS_CHANGED", function() Overlay.DrawWorldMap() Overlay.DrawMinimap() Overlay.UpdateArrow() end)
    ns:On("PLAYER_REGEN_DISABLED", function() if ns.settings.hideInCombat then Overlay.DrawMinimap() Overlay.UpdateArrow() end end)
    ns:On("PLAYER_REGEN_ENABLED", function() Overlay.UpdateArrow() end)
    ns.Ticker(0.1, function()
        if Route.active then
            local ok, err = pcall(Route.Update, Route)
            if not ok then Overlay.lastError = "route: " .. tostring(err) end
            Overlay.DrawMinimap()
            Overlay.UpdateArrow()
        end
    end)
end
