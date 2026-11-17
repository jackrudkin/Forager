-- Farm tab: "What do you want to farm?" search, category chips, location (caves) filter, ranked
-- result cards and a detail panel with a map preview, loot per hour and Start farming.
local _, ns = ...
local UI, Main = ns.UI, ns.Main
local T = ns.Theme
local DS, Finder = ns.DS, ns.Finder

local RISK_COLOR = { [0] = "|cff7fd36b", [1] = "|cffffd100", [2] = "|cffff5050" }

local function itemIcon(id)
    return (C_Item and C_Item.GetItemIconByID and C_Item.GetItemIconByID(id)) or "Interface\\Icons\\INV_Misc_QuestionMark"
end

--- icon, label for a loot line of a result
local function lootLabel(it)
    if it.coin then return "Interface\\Icons\\INV_Misc_Coin_01", "|cffffffffCoin|r" end
    if it.greens == 2 then return "Interface\\Icons\\INV_Enchant_DustStrange", "|cff1eff00Green gear|r |cff9d9d9d(DE)|r" end
    if it.greens == 3 then return "Interface\\Icons\\INV_Enchant_ShardGlimmeringSmall", "|cff0070ddBlue gear|r |cff9d9d9d(DE)|r" end
    return itemIcon(it.id), DS:ColoredItem(it.id)
end

local function titleFor(r)
    return (r.zoneName or "?") .. (r.areaName and ("  ·  " .. r.areaName) or "")
end

local function subFor(r)
    local bits = {}
    if r.source == "mob" then bits[#bits + 1] = string.format("Mobs %d-%d", r.minLevel or 0, r.maxLevel or 0)
    elseif r.source == "node" then bits[#bits + 1] = "Nodes from skill " .. (r.minSkill or 0)
    elseif r.source == "fish" then bits[#bits + 1] = "Fishing skill " .. (r.minSkill or 0) end
    if r.minSkill and r.source == "mob" then bits[#bits + 1] = "skin " .. r.minSkill end
    bits[#bits + 1] = r.danger and (ns.Risk:Short(r) .. " |cff9d9d9d(" .. (r.risk or "") .. ")|r")
        or ((RISK_COLOR[r.riskLevel or 0] or "") .. (r.risk or "") .. "|r")
    if r.detourMin then bits[#bits + 1] = string.format("%d min detour", r.travelMin or 0) end
    return table.concat(bits, "  ·  ")
end

Main:RegisterTab("farm", "Farm", "Interface\\Icons\\INV_Misc_Herb_07", function(panel)
    local CW = panel:GetWidth() > 0 and panel:GetWidth() or 808
    local state = { results = {}, selected = nil }

    ---------------------------------------------------------------------------
    -- row 1: search + rank by
    ---------------------------------------------------------------------------
    local search
    local function applySuggestion(s)
        if not s then return end
        UI.CloseList()
        if s.kind == "mob" then
            search:SetText("")
            Main:SelectTabByKey("mobs")
            ns:Fire("FORAGER_MOB_SEARCH", (DS:GetMob(s.id) or {}).name)
            return
        end
        search:SetText("")
        ns.char.goal = s.key
        ns:Fire("FORAGER_GOAL_CHANGED")
    end
    search = UI.SearchBox(panel, 430, "What do you want to farm?  e.g. Peacebloom, Copper Ore, Linen Cloth", function(text, user)
        if not user then return end
        if #text < 2 then UI.CloseList() return end
        local items = {}
        for _, s in ipairs(Finder:Suggest(text, 14)) do
            local tag = s.kind == "goal" and "|cff7fd36bcategory|r  " or (s.kind == "mob" and "|cff9d9d9dmob|r  " or "")
            items[#items + 1] = { text = tag .. s.text, value = s, icon = s.icon or (s.kind == "mob" and "Interface\\Icons\\Ability_Hunter_Pet_Wolf"),
                itemID = s.kind == "item" and s.id or nil }
        end
        state.suggest = items
        UI.OpenList(search, items, function(v) applySuggestion(v) end, 430)
    end, function()
        if state.suggest and state.suggest[1] then applySuggestion(state.suggest[1].value) end
    end)
    search:SetPoint("TOPLEFT", 0, 0)

    local rankLbl = UI.Muted(panel, "Rank by")
    local rank = UI.Segmented(panel, {
        { key = "gold", label = "Gold / hour" },
        { key = "skill", label = "Skill-ups / hour", tip = "For gathering professions, skinning, fishing and lockpicking." },
    }, function() return ns.settings.mode end, function(v) ns.settings.mode = v ns:Fire("FORAGER_GOAL_CHANGED") end)
    rank:SetPoint("TOPRIGHT", 0, -2)
    rankLbl:SetPoint("RIGHT", rank, "LEFT", -8, 0)

    ---------------------------------------------------------------------------
    -- row 2: category chips (+ the searched item as a chip)
    ---------------------------------------------------------------------------
    local chipArea = CreateFrame("Frame", nil, panel)
    chipArea:SetPoint("TOPLEFT", 0, -38)
    chipArea:SetSize(CW, 54)
    local chips = {}
    local itemChip = UI.Chip(chipArea, "item", "Interface\\Icons\\INV_Misc_QuestionMark", function() end)
    itemChip:HookScript("OnEnter", function(self)
        local gi = Finder:GoalInfo(Main:Goal())
        if gi.kind == "item" and gi.item then UI.ItemTip(self, gi.item, { { "Click", "stop farming this item" } }) end
    end)
    itemChip:HookScript("OnLeave", function() GameTooltip:Hide() end)
    for _, g in ipairs(ns.Goals) do
        local c = UI.Chip(chipArea, g.short, g.icon, function()
            ns.char.goal = g.key
            ns:Fire("FORAGER_GOAL_CHANGED")
        end)
        c.key = g.key
        UI.AttachTip(c, g.label, nil)
        chips[#chips + 1] = c
    end
    local function layoutChips()
        local goal = Main:Goal()
        local list = {}
        local gi = Finder:GoalInfo(goal)
        if gi.kind == "item" then
            itemChip.text:SetText(gi.label .. "  x")
            itemChip.icon:SetTexture(gi.icon)
            itemChip:SetWidth(math.ceil(itemChip.text:GetStringWidth()) + 34)
            itemChip:SetActive(true)
            itemChip:SetScript("OnClick", function() ns.char.goal = nil ns:Fire("FORAGER_GOAL_CHANGED") end)
            itemChip:Show()
            list[1] = itemChip
        else
            itemChip:Hide()
        end
        for _, c in ipairs(chips) do
            c:SetActive(c.key == goal)
            list[#list + 1] = c
        end
        local h = UI.FlowLayout(chipArea, list, CW, 6)
        chipArea:SetHeight(h)
    end

    ---------------------------------------------------------------------------
    -- row 3: location + search scope
    ---------------------------------------------------------------------------
    local row3 = CreateFrame("Frame", nil, panel)
    row3:SetPoint("TOPLEFT", 0, -98)
    row3:SetSize(CW, 26)
    local locLbl = UI.Muted(row3, "Location")
    locLbl:SetPoint("LEFT", 0, 0)
    local loc = UI.Segmented(row3, {
        { key = "any", label = "Anywhere" },
        { key = "cave", label = "Caves & mines", tip = "Only spots inside caves and mines: from the game's explored-map areas and the caves you have walked through. Unexplored caves show up once you have been there." },
        { key = "outdoor", label = "Outdoors" },
    }, function() return ns.settings.location end, function(v) ns.settings.location = v ns:Fire("FORAGER_GOAL_CHANGED") end)
    loc:SetPoint("LEFT", locLbl, "RIGHT", 8, 0)
    local scopeLbl = UI.Muted(row3, "Search in")
    scopeLbl:SetPoint("LEFT", loc, "RIGHT", 18, 0)
    local scope = UI.Dropdown(row3, 190, function() return Main.ZoneItems(true, true) end,
        function() return ns.char.questZone or false end,
        function(v) ns.Quests:Set(v or nil, v and ns.char.questZone2 or nil) end)
    scope:SetPoint("LEFT", scopeLbl, "RIGHT", 8, 0)
    UI.AttachTip(scope, "Questing zone", "Pick the zone you're questing in to rank spots there, counting the detour from your quest objectives. Everywhere = best spot for your level.")
    local enemy = UI.Check(row3, "Enemy zones", function() return ns.settings.includeEnemy end,
        function(v) ns.settings.includeEnemy = v ns:Fire("FORAGER_GOAL_CHANGED") end, "Also rank zones controlled by the other faction.")
    enemy:SetPoint("LEFT", scope, "RIGHT", 10, 0)
    local realistic = UI.Check(row3, "Realistic spots", function() return ns.settings.realistic end,
        function(v) ns.settings.realistic = v ns:Fire("FORAGER_GOAL_CHANGED") end, "Only spots you can farm solo at your level: no mobs more than 2 levels above you (orange, red or skull) or elites in or near the area, death and hyperspawn risk below High, gank and overall risk below Very high. Routes steer around dangerous ground.")
    realistic:SetPoint("LEFT", enemy.label, "RIGHT", 10, 0)

    ---------------------------------------------------------------------------
    -- results (cards)
    ---------------------------------------------------------------------------
    local LISTW, CARDH = 318, 70
    local listTop = -132
    local visible = 6
    local list = UI.CardList(panel, CARDH, visible, function(c)
        c.num = c:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        c.num:SetPoint("TOPLEFT", 8, -8)
        c.num:SetTextColor(T.muted[1], T.muted[2], T.muted[3])
        c.title = UI.Label(c, "", "GameFontNormal")
        c.title:SetPoint("TOPLEFT", 32, -7)
        c.title:SetPoint("RIGHT", -92, 0)
        c.title:SetWordWrap(false)
        c.sub = UI.Muted(c, "")
        c.sub:SetPoint("TOPLEFT", c.title, "BOTTOMLEFT", 0, -3)
        c.sub:SetPoint("RIGHT", -8, 0)
        c.sub:SetWordWrap(false)
        c.rate = UI.Label(c, "", "GameFontNormal")
        c.rate:SetPoint("TOPRIGHT", -8, -7)
        c.rate:SetJustifyH("RIGHT")
        c.badge = UI.Label(c, "", "GameFontNormalSmall")
        c.badge:SetPoint("TOPRIGHT", c.rate, "BOTTOMRIGHT", 0, -3)
        c.icons, c.iconHover = {}, {}
        for i = 1, 5 do
            local t = c:CreateTexture(nil, "ARTWORK")
            t:SetSize(18, 18)
            t:SetTexCoord(0.08, 0.92, 0.08, 0.92)
            t:SetPoint("BOTTOMLEFT", 32 + (i - 1) * 22, 7)
            c.icons[i] = t
            local h = UI.ItemHover(c, function(self) return UI.LootTipInfo(self.loot) end)
            h:SetAllPoints(t)
            c.iconHover[i] = h
        end
        c.more = UI.Muted(c, "")
        c.more:SetPoint("BOTTOMLEFT", 32 + 5 * 22, 9)
    end, function(c, r, _, idx)
        c.num:SetText(idx)
        c.title:SetText(titleFor(r))
        c.sub:SetText(subFor(r))
        c.rate:SetText("|cffffd100" .. Main:RateText(r) .. "|r")
        local badge = {}
        if r.cave then badge[#badge + 1] = "|cff9e7af2CAVE|r" end
        if ns.Route.active and ns.Route.active.result == r then badge[#badge + 1] = "|cff7fd36bFARMING|r" end
        if r.questOverlap and #r.questOverlap > 0 then badge[#badge + 1] = "|cffffd100QUEST|r" end
        c.badge:SetText(table.concat(badge, " "))
        local n = 0
        for i, it in ipairs(r.items or {}) do
            if i > 5 then break end
            n = i
            c.icons[i]:SetTexture((lootLabel(it)))
            c.icons[i]:Show()
            c.iconHover[i].loot = it
            c.iconHover[i]:Show()
        end
        for i = n + 1, 5 do c.icons[i]:Hide() c.iconHover[i]:Hide() end
        c.more:SetText(#(r.items or {}) > 5 and ("+" .. (#r.items - 5)) or "")
    end, function(r) panel:Select(r) end)
    list:SetPoint("TOPLEFT", 0, listTop)
    list:SetWidth(LISTW)

    ---------------------------------------------------------------------------
    -- detail panel
    ---------------------------------------------------------------------------
    local d = UI.Panel(panel, T.panel, T.border)
    d:SetPoint("TOPLEFT", list, "TOPRIGHT", 10, 0)
    d:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", 0, 0)
    d.title = UI.Label(d, "", "GameFontNormalLarge")
    d.title:SetPoint("TOPLEFT", 12, -10)
    d.title:SetPoint("RIGHT", -130, 0)
    d.title:SetWordWrap(false)
    d.sub = UI.Muted(d, "")
    d.sub:SetPoint("TOPLEFT", d.title, "BOTTOMLEFT", 0, -4)
    d.sub:SetPoint("RIGHT", -150, 0)
    d.sub:SetWordWrap(false)
    d.rate = d:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    d.rate:SetPoint("TOPRIGHT", -12, -10)
    d.rate:SetTextColor(T.gold[1], T.gold[2], T.gold[3])
    d.units = UI.Muted(d, "")
    d.units:SetPoint("TOPRIGHT", d.rate, "BOTTOMRIGHT", 0, -4)

    local preview = UI.MapPreview(d, 222, 148)
    preview:SetPoint("TOPLEFT", 12, -52)
    preview:SetScript("OnClick", function() if state.selected then ns.Route:Preview(state.selected) ns.Overlay:OpenMapTo(state.selected.uiMap) end end)
    UI.AttachTip(preview, "Click to open the world map", "Shows this area and route on the world map until you close it.")
    local legend = UI.Muted(d, "|cffffd100■|r area |cff9e7af2■|r cave |cff33d9ff—|r route |cffffd900●|r you", "GameFontHighlightSmall")
    legend:SetPoint("TOPLEFT", preview, "BOTTOMLEFT", 0, -4)

    local lootHdr = UI.Header(d, "Per hour")
    lootHdr:SetPoint("TOPLEFT", preview, "TOPRIGHT", 14, 0)
    d.loot = {}
    for i = 1, 8 do
        local row = CreateFrame("Frame", nil, d)
        row:SetSize(200, 18)
        row:SetPoint("TOPLEFT", lootHdr, "BOTTOMLEFT", 0, -6 - (i - 1) * 19)
        row:SetPoint("RIGHT", d, "RIGHT", -12, 0)
        row.icon = row:CreateTexture(nil, "ARTWORK")
        row.icon:SetSize(16, 16)
        row.icon:SetPoint("LEFT")
        row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        row.name = UI.Label(row, "", "GameFontHighlightSmall")
        row.name:SetPoint("LEFT", row.icon, "RIGHT", 5, 0)
        row.name:SetPoint("RIGHT", -88, 0)
        row.name:SetWordWrap(false)
        row.qty = UI.Muted(row, "")
        row.qty:SetPoint("RIGHT", -50, 0)
        row.qty:SetJustifyH("RIGHT")
        row.val = UI.Label(row, "", "GameFontHighlightSmall")
        row.val:SetPoint("RIGHT")
        row.val:SetJustifyH("RIGHT")
        row.hover = UI.ItemHover(row, function() return UI.LootTipInfo(row.it) end)
        row.hover:SetAllPoints(row)
        d.loot[i] = row
    end

    d.extraHdr = UI.Header(d, "")
    d.extraHdr:SetPoint("TOPLEFT", legend, "BOTTOMLEFT", 0, -10)
    d.extra = UI.Label(d, "", "GameFontHighlightSmall")
    d.extra:SetPoint("TOPLEFT", d.extraHdr, "BOTTOMLEFT", 0, -4)
    d.extra:SetPoint("RIGHT", -12, 0)
    d.extra:SetJustifyV("TOP")
    d.extra:SetSpacing(2)
    d.why = UI.Muted(d, "")
    d.why:SetPoint("BOTTOMLEFT", 12, 44)
    d.why:SetPoint("RIGHT", -12, 0)
    d.risk = CreateFrame("Button", nil, d)
    d.risk:SetPoint("BOTTOMLEFT", 12, 60)
    d.risk:SetPoint("RIGHT", -12, 0)
    d.risk:SetHeight(16)
    d.risk.text = UI.Label(d.risk, "", "GameFontHighlightSmall")
    d.risk.text:SetAllPoints()
    d.risk.text:SetWordWrap(false)
    d.risk:SetScript("OnEnter", function(self) if state.selected then ns.Risk:Tooltip(self, state.selected) end end)
    d.risk:SetScript("OnLeave", function() GameTooltip:Hide() end)

    d.start = UI.Button(d, "Start farming here", 170, function()
        local r = state.selected
        if not r then return end
        if ns.Route.active and ns.Route.active.result == r then ns.Route:Stop() else ns.Route:Start(r) end
        panel:Select(r)
        list:Refresh()
    end, "primary", 30)
    d.start:SetPoint("BOTTOMLEFT", 12, 10)
    d.showMap = UI.Button(d, "Show on world map", 140, function()
        local r = state.selected
        if r then
            if not (ns.Route.active and ns.Route.active.result == r) then ns.Route:Preview(r) end
            ns.Overlay:OpenMapTo(r.uiMap)
        end
    end, nil, 30)
    d.showMap:SetPoint("LEFT", d.start, "RIGHT", 8, 0)
    d.pin = UI.Button(d, "Set waypoint", 110, function()
        if state.selected then ns.Overlay:SetFarmPin(state.selected, true) ns:Print("Waypoint set (game map pin" .. (TomTom and " + TomTom" or "") .. ").") end
    end, nil, 30)
    d.pin:SetPoint("LEFT", d.showMap, "RIGHT", 8, 0)
    UI.AttachTip(d.pin, "Set waypoint", "Places the game's own map pin (and a TomTom arrow if installed) on the centre of the area.")

    d.empty = UI.Muted(d, "")
    d.empty:SetPoint("TOPLEFT", 16, -16)
    d.empty:SetPoint("RIGHT", -16, 0)
    d.empty:SetJustifyV("TOP")
    d.empty:SetSpacing(3)

    local detailWidgets = { d.title, d.sub, d.rate, d.units, preview, legend, lootHdr, d.extraHdr, d.extra, d.why, d.risk, d.start, d.showMap, d.pin }
    local function showDetail(on)
        for _, w in ipairs(detailWidgets) do w:SetShown(on) end
        for _, r in ipairs(d.loot) do if not on then r:Hide() end end
        d.empty:SetShown(not on)
    end

    function panel:Select(r)
        state.selected = r
        list.selected = r
        list:Refresh()
        if not r then showDetail(false) return end
        showDetail(true)
        d.title:SetText(titleFor(r) .. (r.cave and "  |cff9e7af2(cave)|r" or ""))
        d.sub:SetText(subFor(r) .. "  ·  " .. (r.confidence or ""))
        d.rate:SetText(Main:RateText(r))
        local units = {}
        if r.unitsPerHour then units[#units + 1] = string.format("~%.0f %s", r.unitsPerHour, r.unitLabel or "") end
        if r.loopSec and r.loopSec > 0 then units[#units + 1] = "loop " .. (SecondsToTime and SecondsToTime(r.loopSec, true) or (math.floor(r.loopSec / 60) .. " min")) end
        d.units:SetText(table.concat(units, "  ·  "))
        preview:SetResult(r)
        for i, row in ipairs(d.loot) do
            local it = r.items and r.items[i]
            if it then
                local icon, label = lootLabel(it)
                row.it = it
                row.icon:SetTexture(icon)
                row.name:SetText(label)
                row.qty:SetText(it.coin and "" or string.format("%.1f", it.perHour))
                row.val:SetText(it.value > 0 and ns.Money(it.value, true) or "|cff9d9d9d-|r")
                row:Show()
            else
                row:Hide()
            end
        end
        local lines = {}
        if r.source == "mob" and r.mobs then
            d.extraHdr:SetText("Mobs here")
            for i, m in ipairs(r.mobs) do
                if i > 5 then break end
                local cave, caveName = ns.Caves:MobInCave(m.npc, r.uiMap)
                lines[#lines + 1] = string.format("%s |cff9d9d9d(%d-%d)|r  x%d  ·  %s/kill%s", m.m.name, m.m.minLevel, m.m.maxLevel, m.n,
                    ns.Money(m.perKill, true), cave and ("  |cff9e7af2" .. (caveName or "cave") .. "|r") or "")
            end
            if r.questOverlap and #r.questOverlap > 0 then
                lines[#lines + 1] = "|cffffd100Also on your quests:|r " .. table.concat(r.questOverlap, ", ")
            end
        elseif r.source == "node" and r.mix then
            d.extraHdr:SetText("Nodes in the area")
            for i, m in ipairs(r.mix) do
                if i > 5 then break end
                local t = DS:GetType(m.t)
                if t then
                    local col = ns.ColorHex[ns.NodeSkillColor(t, ns.Player:Skill(t.kind))] or "ffffff"
                    lines[#lines + 1] = string.format("|T%s:14|t %s  x%d  |cff%s(skill %d)|r", DS:TypeIcon(t), t.name, m.n, col, t.skill or 0)
                end
            end
        else
            d.extraHdr:SetText("Where")
            lines[#lines + 1] = "Any open water in the zone; pools show on the minimap as you find them."
        end
        if r.poiCount and r.poiCount > 0 then lines[#lines + 1] = string.format("|cffffd100%d quest objective(s)|r inside this area", r.poiCount) end
        d.extra:SetText(table.concat(lines, "\n"))
        d.why:SetText(r.why or "")
        d.risk.text:SetText(ns.Risk:Line(r) .. "  |cff9d9d9d(hover for why)|r")
        local farming = ns.Route.active and ns.Route.active.result == r
        d.start:SetText(farming and "Stop farming" or "Start farming here")
    end

    ---------------------------------------------------------------------------
    -- run
    ---------------------------------------------------------------------------
    local function emptyText()
        local goal = Finder:GoalInfo(Main:Goal())
        local lines = { "|cffffffffNo spots for " .. goal.label .. "|r with your current skill and level." }
        local hid = ns.Risk.HiddenText(Finder.last and Finder.last.hidden)
        if hid then
            lines[#lines + 1] = ""
            lines[#lines + 1] = hid .. " Untick Realistic spots to see them, or come back a level or two later."
        end
        if ns.settings.location == "cave" then
            lines[#lines + 1] = ""
            lines[#lines + 1] = "Cave spots come from the map areas you have explored and the caves you've walked through. Caves in zones for your level:"
            local lvl = ns.Player:Level()
            local n = 0
            local zl = {}
            for id, z in pairs(ns.Zones) do
                if z.caves and #z.caves > 0 and z.min <= lvl + 5 and z.max >= lvl - 8 then zl[#zl + 1] = { id = id, z = z } end
            end
            table.sort(zl, function(a, b) return a.z.min < b.z.min end)
            for _, e in ipairs(zl) do
                for _, c in ipairs(e.z.caves) do
                    if n < 10 then lines[#lines + 1] = "  |cff9e7af2" .. c .. "|r  ·  " .. e.z.name n = n + 1 end
                end
            end
            lines[#lines + 1] = ""
            lines[#lines + 1] = "Or switch Location to Anywhere."
        elseif ns.Quests:IsActive() then
            lines[#lines + 1] = "Set Search in to Everywhere to look outside your questing zone."
        elseif goal.kind == "item" then
            local sc = goal.item and ns.Scarce[goal.item]
            if sc then
                local n = 0
                if sc.kind ~= "skin" then n = select(2, ns.Learn:ScarceNodeRate(goal.item)) end
                lines[#lines + 1] = string.format("%s is a Scarce find. No source publishes its drop rate, so Forager learns it from your %s (%d of %d so far).",
                    sc.name, sc.kind == "skin" and "skins" or "gathers", n, ns.Learn.SCARCE_MIN)
            else
                lines[#lines + 1] = "Nothing in the database drops or yields this item in zones for your level."
            end
        end
        return table.concat(lines, "\n")
    end

    function panel:Run(selectResult)
        layoutChips()
        rank:Refresh()
        loc:Refresh()
        scope:Refresh()
        realistic:SetChecked(ns.settings.realistic and true or false)
        local ok, res = pcall(Finder.Run, Finder, Finder:Options(Main:Goal(), ns.settings.mode))
        if not ok then
            ns:Print("Finder error: " .. tostring(res))
            res = {}
        end
        state.results = res
        local et = #res == 0 and emptyText() or nil
        list:SetItems(res, et and "No results - see the panel on the right." or nil)
        d.empty:SetText(et or "")
        local pick = selectResult
        if not pick and ns.Route.active then
            for _, r in ipairs(res) do
                if r.uiMap == ns.Route.active.uiMap and r.goal == ns.Route.active.result.goal and r.rank == ns.Route.active.result.rank then pick = r end
            end
        end
        panel:Select(pick or res[1])
    end

    local pending
    local function rerun()
        if pending then return end
        pending = true
        ns.After(0.05, function() pending = false if panel:IsVisible() then panel:Run() else panel.stale = true end end)
    end
    ns:On("FORAGER_GOAL_CHANGED", rerun)
    ns:On("FORAGER_QUESTZONE_CHANGED", rerun)
    ns:On("SKILL_LINES_CHANGED", function() panel.stale = true end)
    ns:On("FORAGER_ROUTE_CHANGED", function() if panel:IsVisible() then list:Refresh() if state.selected then panel:Select(state.selected) end end end)
    ns:On("FORAGER_SHOW_RESULTS", function(_, all, best)
        layoutChips()
        state.results = all or {}
        list:SetItems(state.results)
        panel:Select(best)
    end)
    panel.OnActivate = function()
        if panel.stale or #state.results == 0 then panel.stale = false panel:Run() else layoutChips() list:Refresh() end
    end
end)
