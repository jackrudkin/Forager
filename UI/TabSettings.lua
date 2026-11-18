-- Settings tab: three pages (Maps & farming, Estimates, Tooltips & prices) so each stays readable.
local _, ns = ...
local UI, Main, L = ns.UI, ns.Main, ns.L

Main:RegisterTab("settings", "Settings", "Interface\\Icons\\Trade_Engineering", function(panel)
    local S = function() return ns.settings end
    local changed = function() ns:Fire("FORAGER_SETTINGS_CHANGED") end
    local pct = function(v) return math.floor(v * 100 + 0.5) .. "%" end
    local TOP = 40

    local pages, current = {}, "farm"
    local function newPage(key)
        local p = CreateFrame("Frame", nil, panel)
        p:SetPoint("TOPLEFT", 0, -TOP)
        p:SetPoint("BOTTOMRIGHT")
        p:Hide()
        local cols, ys = { 0, 272, 544 }, { 0, 0, 0 }
        local api = { frame = p }
        function api.place(col, w, h)
            w:SetPoint("TOPLEFT", p, "TOPLEFT", cols[col], -ys[col])
            ys[col] = ys[col] + (h or 24)
            return w
        end
        function api.gap(col, h) ys[col] = ys[col] + (h or 6) end
        function api.header(col, text) api.place(col, UI.Header(p, L[text]), 22) end
        function api.check(col, label, key, tip, onSet)
            return api.place(col, UI.Check(p, L[label], function() return S()[key] end,
                function(v) S()[key] = v changed() if onSet then onSet(v) end end, tip and L[tip]))
        end
        function api.slider(col, label, key, lo, hi, step, fmt, tip)
            local f = UI.Slider(p, L[label], lo, hi, step, function() return S()[key] end, function(v) S()[key] = v changed() end, fmt)
            if tip then f:EnableMouse(true) UI.AttachTip(f, L[label], L[tip]) end
            return api.place(col, f, 42)
        end
        function api.muted(col, text, h, width)
            local m = UI.Muted(p, text and L[text] or "")
            m:SetWidth(width or 258)
            m:SetJustifyH("LEFT")
            return api.place(col, m, h or 18)
        end
        function api.dropdown(col, label, width, items, get, set)
            if label then api.place(col, UI.Muted(p, L[label]), 16) end
            return api.place(col, UI.Dropdown(p, width, items, get, set), 30)
        end
        pages[key] = api
        return api
    end

    ---------------------------------------------------------------------------
    -- page 1: maps & farming
    ---------------------------------------------------------------------------
    local A = newPage("farm")
    A.header(1, "Map & minimap")
    A.check(1, "Route on the world map", "showRoute")
    A.place(1, UI.Muted(A.frame, L["Route on the minimap"]), 16)
    A.place(1, UI.Segmented(A.frame, { { key = "off", label = L["Off"] }, { key = "next", label = L["Next stops"] }, { key = "loop", label = L["Whole loop"] } },
        function() return S().routeMinimap end, function(v) S().routeMinimap = v changed() end), 30)
    A.check(1, "Farm area outline", "showArea")
    A.check(1, "Hide overlays in combat", "hideInCombat")
    A.check(1, "Hide overlays in instances", "hideInInstances")
    A.slider(1, "Route opacity", "routeAlpha", 0.2, 1, 0.05, pct)
    A.slider(1, "Area opacity", "areaAlpha", 0, 0.8, 0.05, pct)
    A.muted(1, "Nodes: Forager draws no node pins; use the game's own tracking (Find Herbs / Find Minerals).", 30)

    A.header(2, "Farming")
    A.check(2, "Route HUD with arrow", "hud")
    A.check(2, "Game map pin when starting", "gamePin")
    A.check(2, "TomTom arrow when starting", "tomtom")
    A.check(2, "Rank enemy-faction zones", "includeEnemy")
    A.check(2, "Include elites / high-level mobs", "showDangerous")
    A.dropdown(2, "Your ruleset (for gank risk)", 220, function()
        local learned = ns.db.ruleset
        return { { text = L["Auto"] .. (learned and (" (" .. L["detected"] .. ": " .. (learned == "pvp" and "PvP" or "Normal") .. ")") or (" (" .. L["not detected yet: PvP assumed"] .. ")")), value = "auto" },
            { text = "PvP", value = "pvp" }, { text = L["Normal (PvE)"], value = "normal" } }
    end, function() return S().ruleset end, function(v) S().ruleset = v ns:Fire("FORAGER_GOAL_CHANGED") end)
    A.dropdown(2, "Hide spots with risk", 220, function()
        return { { text = L["Show all"], value = "any" }, { text = L["Very high"], value = "high" },
            { text = L["High or worse"], value = "medium" }, { text = L["Medium or worse (Low only)"], value = "low" } }
    end, function() return S().maxRisk end, function(v) S().maxRisk = v ns:Fire("FORAGER_GOAL_CHANGED") end)
    local hc = A.muted(2, "", 30)

    A.header(3, "Farming helpers")
    A.check(3, "Flip Find Herbs / Find Minerals", "trackSwitch",
        "On routes with both herbs and ore (and both professions): switches tracking every 4 s while you move, out of combat and not casting. Forever allows only one resource tracker at a time.")
    A.check(3, "Turn tracking back on after dying", "retrack", "Dying clears tracking in Forever; this turns your herb or ore tracking back on once you are alive.")
    A.check(3, "Ready check when starting a farm", "readyCheck",
        "Warns when tracking is off or your Mining Pick / Skinning Knife is not in your bags, with a one-click fix for tracking.")
    A.check(3, "Skip stops you just gathered", "coolStops",
        "The route arrow skips stops whose node you gathered until it can have respawned (spawn data, or faster if you have seen it back sooner).")
    A.check(3, "Pause the session clock when idle", "afkPause", "Session gold/hour counts active time only: AFK or 3 minutes without moving, looting or fighting pauses the clock.")
    A.check(3, "Save nodes I point at", "detectNodes",
        "Hover a herb or ore dot on the minimap, or face a node in the world: Forager saves it as a spawn point (no yields) so free roam and the rankings know it exists. Free roam locks on to hovered dots either way.")

    ---------------------------------------------------------------------------
    -- page 2: estimates
    ---------------------------------------------------------------------------
    local B = newPage("estimates")
    B.header(1, "Spawns and yields")
    B.check(1, "Use spawn-pool data", "spawnData",
        "Live nodes per spawn point by node type and zone, and respawn time per mob, from the CMaNGOS spawn pools. Off: the flat share below and 5 min respawns.",
        function() ns.Touch() end)
    B.slider(1, "Live share when spawn data is off", "activeFraction", 0.1, 0.8, 0.05, pct)
    B.slider(1, "Estimate weight (samples)", "minSamples", 5, 200, 5, nil,
        "Your data is blended with the estimates: after n of your samples it counts n / (n + this). At 30, your data counts half after 30 samples.")
    B.slider(1, "Extra seconds per node", "gatherSeconds", 0, 6, 0.5, nil, "Dismount, walk in. Cast and loot times are measured.")
    B.slider(1, "Fishing casts per hour", "castsPerHour", 100, 400, 10)
    B.dropdown(1, "Bountiful Harvest (Legacy perk)", 220, function()
        local out = {}
        for r = 0, 5 do out[#out + 1] = { text = r == 0 and L["Not learned"] or string.format(L["Rank %d: +%d%% Scarce"], r, r * 20), value = r } end
        return out
    end, function() return S().harvestRank or 0 end, function(v)
        S().harvestRank = v
        ns.Learn:SetHarvestRank(v)
        changed()
    end)

    B.header(2, "Kills and travel")
    B.slider(2, "Kills per hour until measured", "killsPerHour", 15, 120, 5, nil,
        "Equal-level mobs. Forager measures your fights and the time between them and blends that in.")
    B.dropdown(2, "Travel speed", 220, function()
        return { { text = L["Auto (measured, else by level)"], value = "auto" }, { text = L["Running (7 yd/s)"], value = "run" },
            { text = L["60% mount"], value = "mount60" }, { text = L["100% mount"], value = "mount100" } }
    end, function() return S().speed end, function(v) S().speed = v changed() end)
    B.gap(2, 4)
    B.place(2, UI.Header(B.frame, L["Measured from your play"]), 22)
    local measured = B.muted(2, "", 120)

    B.header(3, "Gold per hour")
    B.check(3, "After AH cut and repairs", "netGold",
        "Takes the 5% auction house cut off items priced from the AH, and your measured repair cost per kill. Deposits are left out (1c minimum, returned on sale).")
    B.check(3, "Calibrate with my farm sessions", "calibrate",
        "After 10+ minutes farming a spot, its estimate is scaled by what you actually made there (and spots of the same kind, once you have an hour).")
    B.gap(3, 4)
    local calib = B.muted(3, "", 60)

    ---------------------------------------------------------------------------
    -- page 3: tooltips, prices, other
    ---------------------------------------------------------------------------
    local C = newPage("other")
    C.header(1, "Tooltips")
    C.check(1, "Forager lines on mob tooltips", "tooltip")
    C.check(1, "Skinning chances", "tooltipSkin")
    C.check(1, "Cloth / meat / elemental drops", "tooltipFarm")
    C.check(1, "Gear grade chances (green/blue/purple)", "tooltipGear")
    C.check(1, "Pick pocket boxes (Rogue)", "tooltipPickpocket")
    C.check(1, "Best spot on item tooltips", "tooltipItem", "Items you can farm show the best spot for your character. Alt+Shift+click an item link to farm it.")

    C.header(2, "Prices")
    local prices = C.muted(2, "", 18)
    local ORDERS = {
        ATAV = { "AuctionTrends", "Auctionator", "TSM", "Vendor" },
        AATV = { "Auctionator", "AuctionTrends", "TSM", "Vendor" },
        TSM = { "TSM", "AuctionTrends", "Auctionator", "Vendor" },
        V = { "Vendor" },
    }
    C.dropdown(2, nil, 240, function()
        return {
            { text = "AuctionTrends > Auctionator > TSM > Vendor", value = "ATAV" },
            { text = "Auctionator > AuctionTrends > TSM > Vendor", value = "AATV" },
            { text = "TSM > AuctionTrends > Auctionator > Vendor", value = "TSM" },
            { text = L["Vendor only"], value = "V" },
        }
    end, function()
        local p = S().priceSources
        if #p == 1 then return "V" end
        if p[1] == "TSM" then return "TSM" end
        return p[1] == "Auctionator" and "AATV" or "ATAV"
    end, function(v)
        S().priceSources = ns.CopyTable(ORDERS[v] or ORDERS.ATAV)
        ns.Prices:Flush()
        ns:Fire("FORAGER_GOAL_CHANGED")
    end)
    C.dropdown(2, "TSM price", 240, function()
        return {
            { text = "DBMarket (realm, 14-day)", value = "dbmarket" },
            { text = "DBMinBuyout (realm, lowest now)", value = "dbminbuyout" },
            { text = "DBRecent (realm, last scan)", value = "dbrecent" },
            { text = "DBRegionMarketAvg (region)", value = "dbregionmarketavg" },
        }
    end, function() return S().tsmPrice end, function(v)
        S().tsmPrice = v
        ns.Prices:Flush()
        ns:Fire("FORAGER_GOAL_CHANGED")
    end)
    C.muted(2, "Prices come from your price addon, which keeps them per realm and faction.", 30)

    C.header(3, "Sharing (off by default)")
    C.check(3, "Share my node finds with guild", "shareGuild", "Sends node type, zone and position only. Never in instances.")
    C.check(3, "Share with party", "shareParty")
    C.gap(3, 4)
    C.header(3, "Other")
    C.check(3, "Hide minimap button", "minimapHide")
    C.slider(3, "Save reminder every N gathers (0 = off)", "saveReminder", 0, 100, 5)
    C.check(3, "Debug messages", "debug")
    local b1 = UI.Button(C.frame, L["Self-test"], 100, function() ns.SelfTest() end)
    C.place(3, b1, 28)
    local b2 = UI.Button(C.frame, L["Diagnostics"], 100, function() ns.Slash("diag") end)
    b2:SetPoint("LEFT", b1, "RIGHT", 8, 0)
    local errs = C.muted(3, "", 18)

    ---------------------------------------------------------------------------
    -- page switcher
    ---------------------------------------------------------------------------
    local function show(key)
        current = key
        for k, p in pairs(pages) do p.frame:SetShown(k == key) end
        if panel.OnActivate then panel:OnActivate() end
    end
    local seg = UI.Segmented(panel, { { key = "farm", label = L["Maps & farming"] }, { key = "estimates", label = L["Estimates"] },
        { key = "other", label = L["Tooltips, prices & more"] } }, function() return current end, show)
    seg:SetPoint("TOPLEFT", 0, 0)
    pages.farm.frame:Show()

    panel.OnActivate = function()
        prices:SetText(L["Available"] .. ": " .. table.concat(ns.Prices:Available(), ", "))
        hc:SetText(ns.Risk:IsHardcore() and ("|cffff8040" .. L["Hardcore character: Realistic spots are stricter."] .. "|r") or "")
        local lines = {}
        local times, types, ready = ns.Learn:Summary()
        lines[#lines + 1] = L["Cast times"] .. ": " .. (times ~= "" and times or L["none yet"])
        lines[#lines + 1] = string.format(L["Yields: %d node types, %d mostly yours"], types, ready)
        for _, l in ipairs(ns.Learn:Measured()) do lines[#lines + 1] = l end
        measured:SetText(table.concat(lines, "\n"))
        local spots, hours = 0, 0
        for k, c in pairs(ns.Learn.Store().calib) do
            if not k:find("^group:") then spots, hours = spots + 1, hours + (c.h or 0) end
        end
        calib:SetText(spots > 0 and string.format(L["Calibrated from %d spots, %.1f h farmed."], spots, hours)
            or L["No farm sessions yet: start a farm and play 10+ minutes."])
        local ne = #(ns.db.errors or {})
        errs:SetText(ne > 0 and string.format("|cffff8040" .. L["%d errors caught"] .. "|r (/forage errors)", ne) or "")
    end
end)
