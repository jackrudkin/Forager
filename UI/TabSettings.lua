-- Settings tab.
local _, ns = ...
local UI, Main = ns.UI, ns.Main

Main:RegisterTab("settings", "Settings", "Interface\\Icons\\Trade_Engineering", function(panel)
    local S = function() return ns.settings end
    local changed = function() ns:Fire("FORAGER_SETTINGS_CHANGED") end
    local cols = { 0, 272, 544 }
    local ys = { 0, 0, 0 }
    local function place(col, w, h)
        w:SetPoint("TOPLEFT", panel, "TOPLEFT", cols[col], -ys[col])
        ys[col] = ys[col] + (h or 24)
    end
    local function check(col, label, key, tip)
        place(col, UI.Check(panel, label, function() return S()[key] end, function(v) S()[key] = v changed() end, tip))
    end
    local function slider(col, label, key, lo, hi, step, fmt)
        place(col, UI.Slider(panel, label, lo, hi, step, function() return S()[key] end, function(v) S()[key] = v changed() end, fmt), 42)
    end
    local function seg(col, label, key, items)
        place(col, UI.Muted(panel, label), 16)
        place(col, UI.Segmented(panel, items, function() return S()[key] end, function(v) S()[key] = v changed() end), 30)
    end
    local pct = function(v) return math.floor(v * 100 + 0.5) .. "%" end

    place(1, UI.Header(panel, "Map & minimap"), 22)
    local FARM = { { key = "clean", label = "Clean" }, { key = "dots", label = "Spawn dots" }, { key = "icons", label = "Icons" } }
    seg(1, "While farming: world map", "farmWorld", FARM)
    seg(1, "While farming: minimap", "farmMinimap", FARM)
    seg(1, "Not farming: world map nodes", "worldNodes", { { key = "off", label = "Off" }, { key = "all", label = "All in zone" } })
    seg(1, "Not farming: minimap nodes", "minimapNodes", { { key = "off", label = "Off" }, { key = "all", label = "Nearby" } })
    seg(1, "Node pin style (not farming)", "pinStyle", { { key = "icons", label = "Icons" }, { key = "dots", label = "Dots" } })
    check(1, "Database spawn points", "showBundled", "Classic spawn points from QuestieDB (Forever coordinates).")
    check(1, "Learned nodes", "showLearned")
    check(1, "Shared nodes", "showShared")
    check(1, "Distance fade on minimap", "distanceFade")
    check(1, "Hide overlays in combat", "hideInCombat")
    check(1, "Hide overlays in instances", "hideInInstances")
    slider(1, "Pin size", "pinScale", 0.6, 2, 0.1, pct)
    slider(1, "Pin opacity", "pinAlpha", 0.2, 1, 0.05, pct)

    place(2, UI.Header(panel, "Farming"), 22)
    check(2, "Route HUD with arrow", "hud")
    check(2, "Game map pin on the farm spot", "gamePin")
    check(2, "TomTom waypoint (if installed)", "tomtom")
    check(2, "Rank enemy-faction zones", "includeEnemy")
    check(2, "Include elites / high-level mobs", "showDangerous")
    slider(2, "Area opacity", "areaAlpha", 0, 0.8, 0.05, pct)
    slider(2, "Route opacity", "routeAlpha", 0.2, 1, 0.05, pct)
    ys[2] = ys[2] + 4
    place(2, UI.Header(panel, "Finder assumptions"), 22)
    slider(2, "Live share of spawn points", "activeFraction", 0.1, 0.8, 0.05, pct)
    slider(2, "Kills per hour (equal level)", "killsPerHour", 15, 120, 5)
    slider(2, "Fishing casts per hour", "castsPerHour", 100, 400, 10)
    slider(2, "Seconds per gather", "gatherSeconds", 1, 8, 0.5)
    slider(2, "My data replaces estimates at n =", "minSamples", 5, 200, 5)
    place(2, UI.Muted(panel, "Travel speed"), 16)
    place(2, UI.Dropdown(panel, 170, function()
        return { { text = "Auto (by level)", value = "auto" }, { text = "Running (7 yd/s)", value = "run" },
            { text = "60% mount", value = "mount60" }, { text = "100% mount", value = "mount100" } }
    end, function() return S().speed end, function(v) S().speed = v end), 28)

    place(3, UI.Header(panel, "Mob tooltip"), 22)
    check(3, "Forager lines on mob tooltips", "tooltip")
    check(3, "Skinning chances", "tooltipSkin")
    check(3, "Cloth / meat / elemental drops", "tooltipFarm")
    check(3, "Gear grade chances (green/blue/purple)", "tooltipGear")
    check(3, "Pick pocket boxes (Rogue)", "tooltipPickpocket")
    ys[3] = ys[3] + 4
    place(3, UI.Header(panel, "Prices"), 22)
    local prices = UI.Muted(panel, "")
    place(3, prices, 18)
    place(3, UI.Dropdown(panel, 240, function()
        return {
            { text = "AuctionTrends > Auctionator > Vendor", value = "ATAV" },
            { text = "Auctionator > AuctionTrends > Vendor", value = "AATV" },
            { text = "Vendor only", value = "V" },
        }
    end, function()
        local p = S().priceSources
        if #p == 1 then return "V" end
        return p[1] == "Auctionator" and "AATV" or "ATAV"
    end, function(v)
        S().priceSources = (v == "V" and { "Vendor" }) or (v == "AATV" and { "Auctionator", "AuctionTrends", "Vendor" }) or { "AuctionTrends", "Auctionator", "Vendor" }
        ns:Fire("FORAGER_GOAL_CHANGED")
    end), 30)
    place(3, UI.Header(panel, "Sharing (off by default)"), 22)
    check(3, "Share my node finds with guild", "shareGuild", "Sends node type, zone and position only. Never in instances.")
    check(3, "Share with party", "shareParty")
    ys[3] = ys[3] + 4
    place(3, UI.Header(panel, "Other"), 22)
    check(3, "Hide minimap button", "minimapHide")
    slider(3, "Save reminder every N gathers (0 = off)", "saveReminder", 0, 100, 5)
    check(3, "Debug messages", "debug")
    local diag = UI.Button(panel, "Print diagnostics", 130, function() ns.Slash("diag") end)
    place(3, diag, 26)

    panel.OnActivate = function()
        prices:SetText("Available: " .. table.concat(ns.Prices:Available(), ", "))
    end
end)
