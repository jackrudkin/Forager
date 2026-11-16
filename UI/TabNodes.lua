-- Nodes tab: the node database per zone (what the finder ranks) and imports. No map pins.
local _, ns = ...
local UI, Main = ns.UI, ns.Main

Main:RegisterTab("nodes", "Nodes", "Interface\\Icons\\INV_Ore_Copper_01", function(panel)
    local zone
    local zl = UI.Label(panel, "Zone", "GameFontNormalSmall")
    zl:SetPoint("TOPLEFT", 2, -4)
    local dd = UI.Dropdown(panel, 200, function() return Main.ZoneItems(false, false) end, function() return zone end, function(v) zone = v panel:OnActivate() end)
    dd:SetPoint("LEFT", zl, "RIGHT", 6, 0)
    local here = UI.Button(panel, "Current zone", 100, function() zone = ns.Player:MapID() dd:Refresh() panel:OnActivate() end)
    here:SetPoint("LEFT", dd, "RIGHT", 4, 0)
    local summary = UI.Label(panel, "", "GameFontHighlightSmall")
    summary:SetPoint("LEFT", here, "RIGHT", 10, 0)

    local cols = {
        { key = "name", label = "Node", width = 210, get = function(r) return "|T" .. ns.DS:TypeIcon(r.t) .. ":14|t " .. r.t.name .. (r.t.forever and " |cff7fd36b(Forever)|r" or "") end, sort = function(r) return r.t.name end },
        { key = "kind", label = "Type", width = 60, get = function(r) return r.t.kind end, sort = function(r) return r.t.kind end },
        { key = "skill", label = "Skill", width = 50, align = "CENTER", get = function(r)
            local have = ns.Player:Skill(r.t.kind)
            return "|cff" .. ns.ColorHex[ns.SkillColor(r.t.skill or 0, have)] .. (r.t.skill or 0) .. "|r"
        end, sort = function(r) return r.t.skill or 0 end },
        { key = "db", label = "Database", width = 70, align = "RIGHT", get = function(r) return r.bundled end, sort = function(r) return r.bundled end },
        { key = "learned", label = "Learned", width = 70, align = "RIGHT", get = function(r) return r.learned end, sort = function(r) return r.learned end },
        { key = "shared", label = "Shared", width = 60, align = "RIGHT", get = function(r) return r.shared end, sort = function(r) return r.shared end },
        { key = "gathered", label = "Gathered", width = 70, align = "RIGHT", get = function(r) return r.gathered end, sort = function(r) return r.gathered end },
        { key = "value", label = "Value/node", width = 90, align = "RIGHT", get = function(r) return ns.Money(r.value) end, sort = function(r) return r.value end },
    }
    local tbl = UI.Table(panel, cols, 19, nil, function(owner, r)
        local lines = { { "Required skill", r.t.skill or 0 } }
        for _, y in ipairs(r.t.yields or {}) do lines[#lines + 1] = { ns.DS:ColoredItem(y[1]), string.format("%.2f per gather", y[2]) } end
        if (r.t.taps or 1) > 1 then lines[#lines + 1] = { "Gathers per node", string.format("%.1f", r.t.taps) } end
        UI.Tip(owner, r.t.name, lines)
    end)
    tbl:SetPoint("TOPLEFT", 0, -30)
    tbl.sortKey = "skill"
    tbl.sortDesc = false

    local by = -30 - 21 * 18
    local imp = UI.Button(panel, "Import GatherMate2 / GatherLite", 220, function() ns.Import:Run() panel:OnActivate() end)
    imp:SetPoint("TOPLEFT", 0, by - 4)
    local forget = UI.Button(panel, "Forget learned nodes in zone", 200, function()
        if zone then ns.db.nodes[zone] = nil ns.DS:Invalidate(zone) ns:Fire("FORAGER_NODES_CHANGED", zone) panel:OnActivate() end
    end)
    forget:SetPoint("LEFT", imp, "RIGHT", 6, 0)
    function panel:OnActivate()
        ns.DS:Load()
        zone = zone or ns.Player:MapID()
        if not zone or not ns.Zones[zone] then zone = 1429 end
        dd:Refresh()
        local byType = {}
        local total = 0
        for _, pt in ipairs(ns.DS:GetZoneNodes(zone)) do
            local k = pt.t
            local e = byType[k]
            if not e then
                local t = ns.DS:GetType(k)
                if t then
                    e = { key = k, t = t, bundled = 0, learned = 0, shared = 0, gathered = 0, value = ns.Finder:NodeValue(t) }
                    byType[k] = e
                end
            end
            if e then
                total = total + 1
                if pt.src == "bundled" then e.bundled = e.bundled + 1
                elseif pt.src == "shared" then e.shared = e.shared + 1
                else e.learned = e.learned + 1 e.gathered = e.gathered + (pt.rec and pt.rec.c or 0) end
            end
        end
        local rows = {}
        for _, e in pairs(byType) do rows[#rows + 1] = e end
        tbl:SetData(rows, true)
        summary:SetText(string.format("%d points · %d types · database %s", total, #rows, ns.DS:HasBundled() and "loaded" or "|cffff4040not loaded|r"))
    end
end)
