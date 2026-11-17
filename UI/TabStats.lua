-- Stats tab: session gold/hour, gathered totals, sessions, data health.
local _, ns = ...
local UI, Main = ns.UI, ns.Main
local DS = ns.DS

Main:RegisterTab("stats", "Stats", "Interface\\Icons\\INV_Misc_Coin_02", function(panel)
    local sess = UI.Label(panel, "", "GameFontHighlight")
    sess:SetPoint("TOPLEFT", 2, -4)
    sess:SetWidth(420)
    sess:SetJustifyV("TOP")
    sess:SetHeight(64)
    local reset = UI.Button(panel, "New session", 110, function() ns.Capture:ResetSession() panel:OnActivate() end)
    reset:SetPoint("TOPLEFT", 2, -70)

    local itemCols = {
        { key = "name", label = "Item gathered/looted", width = 170, get = function(r) return DS:ColoredItem(r.id) end, sort = function(r) return DS:ItemName(r.id) end },
        { key = "n", label = "Total", width = 50, align = "RIGHT", get = function(r) return r.n end, sort = function(r) return r.n end },
        { key = "s", label = "Session", width = 56, align = "RIGHT", get = function(r) return r.s > 0 and r.s or "-" end, sort = function(r) return r.s end },
        { key = "v", label = "Value", width = 74, align = "RIGHT", get = function(r) return ns.Money(r.v, true) end, sort = function(r) return r.v end },
    }
    local items = UI.Table(panel, itemCols, 15, nil, function(owner, r)
        local lines = { { "Gathered/looted (all time)", tostring(r.n) } }
        if (r.s or 0) > 0 then lines[#lines + 1] = { "This session", tostring(r.s) } end
        if (r.v or 0) > 0 then lines[#lines + 1] = { "Worth now", ns.Money(r.v, true) } end
        UI.ItemTip(owner, r.id, lines)
    end)
    items:SetPoint("TOPLEFT", 0, -100)
    items.sortKey = "v"

    local sessCols = {
        { key = "d", label = "Session", width = 96, get = function(r) return date("%d %b %H:%M", r.start) end, sort = function(r) return r.start end },
        { key = "t", label = "Time", width = 50, align = "RIGHT", get = function(r) return string.format("%dm", r.secs / 60) end, sort = function(r) return r.secs end },
        { key = "v", label = "Value", width = 66, align = "RIGHT", get = function(r) return ns.Money(r.value, true) end, sort = function(r) return r.value end },
        { key = "h", label = "Per hour", width = 66, align = "RIGHT", get = function(r) return ns.Money(r.perHour, true) end, sort = function(r) return r.perHour end },
        { key = "z", label = "Zone", width = 96, get = function(r) return r.zone and ns.Player:ZoneName(r.zone) or "-" end },
    }
    local sessions = UI.Table(panel, sessCols, 9)
    sessions:SetPoint("TOPLEFT", items, "TOPRIGHT", 14, 0)
    sessions.sortKey = "d"

    local health = UI.Label(panel, "", "GameFontHighlightSmall")
    health:SetPoint("TOPLEFT", sessions, "BOTTOMLEFT", 2, -8)
    health:SetWidth(420)
    health:SetJustifyV("TOP")
    local save = UI.Button(panel, "Save now (reload)", 140, function() ns:SaveNow() end)
    save:SetPoint("TOPLEFT", health, "BOTTOMLEFT", -2, -70)
    local backup = UI.Button(panel, "Backup now", 100, function()
        local ok, why = ns:WriteBackup(true)
        ns:Print(ok and "Backup written (saved to disk at next reload/logout)." or ("Backup not written: " .. tostring(why)))
    end)
    backup:SetPoint("LEFT", save, "RIGHT", 6, 0)

    function panel:OnActivate()
        local s = ns.Capture.session
        local perHour, secs = ns.Capture:SessionPerHour()
        sess:SetText(string.format("|cffffd100This session|r  %s\nValue: %s  ·  %s/hour\nGathers: %d  ·  Kills looted: %d  ·  Coin: %s",
            s.start and (math.floor((secs or 0) / 60) .. " min") or "(starts at your first gather/loot)",
            ns.Money(s.value), ns.Money(perHour), s.gathers, s.kills, ns.Money(s.money)))
        local rows = {}
        for id, n in pairs(ns.db.stats.items) do
            rows[#rows + 1] = { id = id, n = n, s = s.items[id] or 0, v = ns.Prices:Get(id) * n }
        end
        items:SetData(rows, true)
        sessions:SetData(ns.db.sessions, true)
        local learned, zones = 0, 0
        for _, z in pairs(ns.db.nodes) do learned = learned + ns.Count(z) zones = zones + 1 end
        local shared = 0
        for _, z in pairs(ns.db.shared) do shared = shared + ns.Count(z) end
        health:SetText(string.format(
            "|cffffd100Data|r\nLearned nodes: %d in %d zones  ·  shared: %d\nMobs observed: %d  ·  kills: %d  ·  skins: %d\nDatabase: %s  ·  Last write: %s\nBackup: %s%s",
            learned, zones, shared, ns.Count(ns.db.mobs), ns.db.stats.kills or 0, ns.db.stats.skins or 0,
            DS:HasBundled() and (DS:CountBundledNodes() .. " spawn points") or "|cffff4040not loaded|r",
            ns.db.meta.lastSave > 0 and date("%d %b %H:%M", ns.db.meta.lastSave) or "never",
            ns:BackupStatus(), ns.safeMode and ("\n|cffff4040Safe mode: " .. ns.safeMode .. "|r") or ""))
    end
    ns:On("FORAGER_SESSION_UPDATE", function() if panel:IsVisible() then panel:OnActivate() end end)
end)
