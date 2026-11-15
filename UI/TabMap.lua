-- Map & Route tab: active route, waypoints, layer toggles and legend.
local _, ns = ...
local UI, Main = ns.UI, ns.Main

Main:RegisterTab("map", "Map & Route", function(panel)
    local info = UI.Label(panel, "", "GameFontHighlight")
    info:SetPoint("TOPLEFT", 2, -4)
    info:SetPoint("RIGHT", -300, 0)
    info:SetHeight(46)
    info:SetJustifyV("TOP")

    local cols = {
        { key = "i", label = "#", width = 30, get = function(r) return (r.current and "|cff33ddff> |r" or "") .. r.i end },
        { key = "xy", label = "Coords", width = 80, get = function(r) return string.format("%.1f, %.1f", r.p.x * 100, r.p.y * 100) end },
        { key = "what", label = "Target", width = 220, get = function(r)
            if r.p.t then local t = ns.DS:GetType(r.p.t) return t and ("|T" .. ns.DS:TypeIcon(t) .. ":14|t " .. t.name) or "?" end
            if r.p.n then return r.p.n .. " mob spawns" end
            return "-"
        end },
        { key = "d", label = "From previous", width = 100, align = "RIGHT", get = function(r) return r.d and string.format("%d yd", r.d) or "-" end },
    }
    local tbl = UI.Table(panel, cols, 18)
    tbl:SetPoint("TOPLEFT", 0, -54)

    -- right column: buttons, layers, legend
    local right = CreateFrame("Frame", nil, panel)
    right:SetPoint("TOPRIGHT", -2, -4)
    right:SetSize(280, 440)
    local y = 0
    local function place(w, h) w:SetPoint("TOPLEFT", right, "TOPLEFT", 0, -y) y = y + (h or 26) end
    local b1 = UI.Button(right, "Open world map", 130, function() if not InCombatLockdown() then ToggleWorldMap() end end)
    place(b1, 0)
    local b2 = UI.Button(right, "Skip waypoint", 130, function() ns.Route:Skip() end)
    b2:SetPoint("LEFT", b1, "RIGHT", 6, 0)
    y = 26
    local b3 = UI.Button(right, "Restart from here", 130, function() local a = ns.Route.active if a then ns.Route:Start(a.result) end end)
    place(b3, 0)
    local b4 = UI.Button(right, "Stop route", 130, function() ns.Route:Stop() end)
    b4:SetPoint("LEFT", b3, "RIGHT", 6, 0)
    y = y + 34
    local h = UI.Header(right, "Layers")
    place(h, 18)
    local function layer(label, key)
        local c = UI.Check(right, label, function() return ns.settings[key] end, function(v) ns.settings[key] = v ns:Fire("FORAGER_SETTINGS_CHANGED") end)
        place(c, 24)
    end
    layer("Recommended area", "showArea")
    layer("Route", "showRoute")
    layer("Next-waypoint arrow", "showArrow")
    layer("Mob camps", "showMobCamps")
    layer("Node pins on minimap", "showNodesMinimap")
    layer("Node pins on world map", "showNodesWorld")
    y = y + 8
    place(UI.Header(right, "Legend"), 18)
    local legend = UI.Label(right, table.concat({
        "|cffffd100■|r Recommended area (shaded)   |cff33ddff—|r Route",
        "|cffff5959●|r Mob camp   |cffffff00●|r Next waypoint",
        "Pin icon = item it gives; border = your skill:",
        "  |cffff8040■|r orange  |cffffff00■|r yellow  |cff40c040■|r green  |cff808080■|r grey  |cffff2020■|r too high",
        "Pins are known spawn points (database, learned,",
        "shared or imported), not live nodes. The game's",
        "yellow tracking dots still show live nodes.",
    }, "\n"), "GameFontHighlightSmall")
    place(legend, 100)

    local function refresh()
        local a = ns.Route.active
        if not a then
            info:SetText("|cff9d9d9dNo active route. Use Start farming or click a row in Find.|r")
            tbl:SetData({})
            return
        end
        local r = a.result
        local _, d, prog, loops = ns.Route:Next()
        local rate = r.mode == "skill" and string.format("%.0f skill-ups/h", r.perHour) or (ns.Money(r.perHour, true) .. "/h")
        info:SetText(string.format("|cffffd100%s|r in %s · %s\nRoute: %d waypoints, %d yd loop (~%s) · loop %d · %d%% · next %s",
            ns.GoalByKey[r.goal].label, r.zoneName, rate, #a.route.points, a.route.length or 0,
            SecondsToTime and SecondsToTime((a.route.length or 0) / ns.Player:Speed()) or "?", (loops or 0) + 1, (prog or 0) * 100,
            d and string.format("%d yd", d) or "-"))
        local rows = {}
        local pts = a.route.points
        for i, p in ipairs(pts) do
            local prev = pts[(i - 2) % #pts + 1]
            rows[#rows + 1] = { i = i, p = p, current = i == a.index, d = #pts > 1 and ns.Player:Distance(a.uiMap, prev.x, prev.y, p.x, p.y) or nil }
        end
        tbl:SetData(rows, true)
    end
    ns:On("FORAGER_ROUTE_CHANGED", function() if panel:IsVisible() then refresh() end end)
    ns:On("FORAGER_ROUTE_PROGRESS", function() if panel:IsVisible() then refresh() end end)
    panel.OnActivate = refresh
end)
