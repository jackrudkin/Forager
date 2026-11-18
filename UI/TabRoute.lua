-- Route tab: the active farm, its waypoints, map layers and what is drawn where.
local _, ns = ...
local UI, Main = ns.UI, ns.Main
local T = ns.Theme

Main:RegisterTab("route", "Route & Map", "Interface\\Icons\\INV_Misc_Map_01", function(panel)
    local info = UI.Label(panel, "", "GameFontNormal")
    info:SetPoint("TOPLEFT", 2, -2)
    info:SetPoint("RIGHT", -290, 0)
    local info2 = UI.Muted(panel, "")
    info2:SetPoint("TOPLEFT", info, "BOTTOMLEFT", 0, -4)
    info2:SetPoint("RIGHT", -290, 0)

    local preview = UI.MapPreview(panel, 240, 160)
    preview:SetPoint("TOPLEFT", 0, -44)
    preview:SetScript("OnClick", function() ns.Overlay:OpenMapTo() end)
    UI.AttachTip(preview, "Open the world map at the farm", nil)

    local cols = {
        { key = "i", label = "#", width = 26, get = function(r) return (r.current and "|cffffd100> |r" or "") .. r.i end },
        { key = "xy", label = "Coords", width = 66, get = function(r) return string.format("%.1f, %.1f", r.p.x * 100, r.p.y * 100) end },
        { key = "what", label = "Target", width = 110, get = function(r)
            if r.p.t then local t = ns.DS:GetType(r.p.t) return t and ("|T" .. ns.DS:TypeIcon(t) .. ":14|t " .. t.name) or "?" end
            if r.p.n then return r.p.n .. " spawns" end
            return "-"
        end },
        { key = "d", label = "Leg", width = 56, align = "RIGHT", get = function(r) return r.d and string.format("%d yd", r.d) or "-" end },
    }
    local tbl = UI.Table(panel, cols, 12)
    tbl:SetPoint("TOPLEFT", preview, "TOPRIGHT", 12, 0)

    local b1 = UI.Button(panel, "Open world map at farm", 160, function() ns.Overlay:OpenMapTo() end, "primary", 26)
    b1:SetPoint("TOPLEFT", preview, "BOTTOMLEFT", 0, -10)
    local b2 = UI.Button(panel, "Skip stop", 74, function() ns.Route:Skip() end, nil, 26)
    b2:SetPoint("LEFT", b1, "RIGHT", 6, 0)
    local b3 = UI.Button(panel, "Restart here", 90, function() local a = ns.Route.active if a then ns.Route:Start(a.result) end end, nil, 26)
    b3:SetPoint("TOPLEFT", b1, "BOTTOMLEFT", 0, -6)
    local b4 = UI.Button(panel, "Waypoint", 76, function() local a = ns.Route.active if a then ns.Overlay:SetFarmPin(a.result, true) end end, nil, 26)
    b4:SetPoint("LEFT", b3, "RIGHT", 6, 0)
    local b5 = UI.Button(panel, "Stop", 60, function() ns.Route:Stop() end, nil, 26)
    b5:SetPoint("LEFT", b4, "RIGHT", 6, 0)

    -- right column: layers
    local right = UI.Panel(panel, T.panel, T.border)
    right:SetPoint("TOPRIGHT", 0, 0)
    right:SetPoint("BOTTOMRIGHT", 0, 0)
    right:SetWidth(270)
    local y = -10
    local function place(w, h, x) w:SetPoint("TOPLEFT", right, "TOPLEFT", x or 10, y) y = y - (h or 24) end
    local changed = function() ns:Fire("FORAGER_SETTINGS_CHANGED") end
    place(UI.Header(right, "On the maps"), 22)
    local function layer(label, key, tip)
        place(UI.Check(right, label, function() return ns.settings[key] end, function(v) ns.settings[key] = v changed() end, tip), 24)
    end
    layer("Route on the world map", "showRoute")
    y = y - 4
    place(UI.Muted(right, "Route on the minimap"), 16)
    place(UI.Segmented(right, {
        { key = "off", label = "Off" },
        { key = "next", label = "Next stops", tip = "A line from you to the next stop, then the next few legs (fading)." },
        { key = "loop", label = "Whole loop" },
    }, function() return ns.settings.routeMinimap end, function(v) ns.settings.routeMinimap = v changed() end), 32)
    layer("Farm area outline", "showArea")
    layer("Route HUD with arrow", "hud", "Small movable panel: arrow to the next stop, distance, loop progress, Skip/Map/Stop.")
    layer("Game map pin when starting", "gamePin", "Puts the game's own waypoint on the farm area when you press Start farming.")
    layer("TomTom arrow when starting", "tomtom", "If TomTom is installed.")
    y = y - 8
    place(UI.Header(right, "Nodes"), 20)
    local legend = UI.Label(right, table.concat({
        "Forager draws no node pins. Use the game's",
        "own tracking (Find Herbs / Find Minerals).",
        "",
        "|cff33d9ff—|r the route through the best spawn points",
        "|cffffd100■|r farm area (if the outline is on)",
        "The HUD arrow points to the next stop.",
    }, "\n"), "GameFontHighlightSmall")
    legend:SetJustifyV("TOP")
    legend:SetSpacing(2)
    place(legend, 100)

    local function refresh()
        local a = ns.Route.active
        if not a then
            info:SetText("|cff9d9d9dNo active farm|r")
            info2:SetText("Use Farm or Mobs & Drops and press Start farming.")
            tbl:SetData({}, false, "No route")
            preview:SetResult(nil)
            return
        end
        local r = a.result
        if a.roam then
            local tg, td = ns.Roam:Target()
            info:SetText(string.format("%s  ·  %s", ns.L[ns.Roam.GOALS[r.goal].label], r.zoneName or "?"))
            info2:SetText(string.format(ns.L["%d gathered · %d checked"], a.gathered, a.nChecked) .. "  ·  "
                .. string.format(ns.L["%d seen on the minimap"], a.seen) .. "  ·  "
                .. (tg and string.format("%s %d yd", (ns.DS:GetType(tg.t) or {}).name or "?", td or 0) or ns.L["no spot nearby"]))
            preview:SetResult(nil)
            tbl:SetData({}, false, ns.L["Free roam has no stops: follow the arrow."])
            return
        end
        local _, d, prog, loops = ns.Route:Next()
        info:SetText(string.format("%s  ·  %s%s  ·  |cffffd100%s|r", ns.Finder:GoalInfo(r.goal).label, r.areaName and (r.areaName .. ", ") or "", r.zoneName or "?", Main:RateText(r)))
        info2:SetText(string.format("%d stops  ·  %d yd loop (~%s)  ·  loop %d, %d%%  ·  next stop %s", #a.route.points, a.route.length or 0,
            SecondsToTime and SecondsToTime((a.route.length or 0) / ns.Player:Speed(), true) or "?", (loops or 0) + 1, (prog or 0) * 100,
            d and string.format("%d yd", d) or "(not in zone)"))
        preview:SetResult(r)
        local rows = {}
        local pts = a.route.points
        for i, p in ipairs(pts) do
            local prev = pts[(i - 2) % #pts + 1]
            rows[#rows + 1] = { i = i, p = p, current = i == a.index, d = #pts > 1 and ns.Player:Distance(a.uiMap, prev.x, prev.y, p.x, p.y) or nil }
        end
        tbl:SetData(rows, true, r.source == "fish" and "Fishing has no route: fish any water in the zone." or "No stops")
    end
    ns:On("FORAGER_ROUTE_CHANGED", function() if panel:IsVisible() then refresh() end end)
    ns:On("FORAGER_ROUTE_PROGRESS", function() if panel:IsVisible() then refresh() end end)
    panel.OnActivate = refresh
end)
