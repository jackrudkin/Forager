-- Mobs & Drops tab: what the mobs in a zone (or all zones for your level) drop, ranked by gold per
-- kill, with a cave/outdoor filter, item search and "Farm this mob".
local _, ns = ...
local UI, Main = ns.UI, ns.Main
local T = ns.Theme
local DS = ns.DS

local function itemIcon(id)
    return (C_Item and C_Item.GetItemIconByID and C_Item.GetItemIconByID(id)) or "Interface\\Icons\\INV_Misc_QuestionMark"
end

--- Classic-style con colour for a mob level relative to the player.
local function levelColor(mobLevel)
    local d = mobLevel - ns.Player:Level()
    if d >= 5 then return "|cffff2020" end
    if d >= 3 then return "|cffff8040" end
    if d >= -2 then return "|cffffff00" end
    local lvl = ns.Player:Level()
    local grey = lvl <= 5 and 0 or (lvl <= 39 and (lvl - 5 - math.floor(lvl / 10)) or (lvl - 1 - math.floor(lvl / 5)))
    if mobLevel <= grey then return "|cff808080" end
    return "|cff40c040"
end

Main:RegisterTab("mobs", "Mobs & Drops", "Interface\\Icons\\INV_Misc_Bag_10", function(panel)
    local zoneMode = "here" -- "here" | "level" | uiMapID
    local searchItem, searchText = nil, ""

    local zoneDD = UI.Dropdown(panel, 210, function()
        local items = { { text = "Current zone", value = "here" }, { text = "All zones for my level", value = "level" } }
        for _, it in ipairs(Main.ZoneItems(false, false)) do items[#items + 1] = it end
        return items
    end, function() return zoneMode end, function(v) zoneMode = v panel:Search() end)
    zoneDD:SetPoint("TOPLEFT", 0, -3)

    local loc = UI.Segmented(panel, {
        { key = "any", label = "Anywhere" },
        { key = "cave", label = "Caves & mines" },
        { key = "outdoor", label = "Outdoors" },
    }, function() return ns.settings.location end, function(v) ns.settings.location = v panel:Search() ns:Fire("FORAGER_GOAL_CHANGED") end)
    loc:SetPoint("LEFT", zoneDD, "RIGHT", 10, 0)

    local search
    search = UI.SearchBox(panel, 250, "Filter by mob or item name", function(text, user)
        if not user then return end
        searchItem = nil
        searchText = text
        if #text >= 3 then
            local items = {}
            for _, s in ipairs(ns.Finder:Suggest(text, 10)) do
                if s.kind == "item" then items[#items + 1] = { text = s.text, value = s, icon = s.icon } end
            end
            if #items > 0 then
                UI.OpenList(search, items, function(v)
                    searchItem = v.id
                    search:SetText(v.text)
                    UI.CloseList()
                    panel:Search()
                end, 250)
            else
                UI.CloseList()
            end
        else
            UI.CloseList()
        end
        if panel.timer then panel.timer:Cancel() end
        panel.timer = C_Timer and C_Timer.NewTimer and C_Timer.NewTimer(0.4, function() panel:Search() end)
    end, function() panel:Search() end)
    search:SetPoint("TOPRIGHT", 0, 0)

    local cols = {
        { key = "name", label = "Mob", width = 150, get = function(r)
            local q = (r.m.rank and r.m.rank > 0) and " |cffffd100(elite)|r" or ""
            return r.m.name .. q
        end, sort = function(r) return r.m.name end },
        { key = "lvl", label = "Lvl", width = 46, align = "CENTER", get = function(r)
            return levelColor(r.m.maxLevel) .. r.m.minLevel .. "-" .. r.m.maxLevel .. "|r"
        end, sort = function(r) return r.m.maxLevel end },
        { key = "where", label = "Where", width = 100, get = function(r)
            if r.cave == true then return "|cff9e7af2" .. (r.caveName or "Cave") .. "|r" end
            if r.cave == false then return "|cff9d9d9dOutdoors|r" end
            return "|cff5d5d5d?|r"
        end, sort = function(r) return r.cave == true and 2 or (r.cave == false and 1 or 0) end,
            tip = "Cave or mine name where this mob lives (explored map areas + caves you've walked through). ? = not known yet." },
        { key = "zone", label = "Zone", width = 96, get = function(r) return ns.Player:ZoneName(r.zone) end, sort = function(r) return ns.Player:ZoneName(r.zone) end },
        { key = "val", label = "Gold/kill", width = 72, align = "RIGHT", get = function(r) return "|cffffd100" .. ns.Money(r.value, true) .. "|r" end,
            sort = function(r) return r.value end, tip = "Expected value per kill: drops at auction/vendor price, coin, disenchant value of greens/blues, and skins if you have Skinning." },
        { key = "best", label = "Best drop", width = 140, get = function(r)
            local b = r.best
            if not b then return "-" end
            return string.format("|T%s:14|t %s |cff9d9d9d%s|r", itemIcon(b.id), DS:ColoredItem(b.id), ns.Pct(b.p))
        end, sort = function(r) return r.best and (searchItem and r.best.p or r.best.value) or 0 end },
        { key = "g", label = "Green", width = 46, align = "RIGHT", get = function(r) return r.m.green and ("|cff1eff00" .. ns.Pct(r.m.green) .. "|r") or "-" end, sort = function(r) return r.m.green or 0 end },
        { key = "b", label = "Blue", width = 46, align = "RIGHT", get = function(r) return r.m.blue and ("|cff0070dd" .. ns.Pct(r.m.blue) .. "|r") or "-" end, sort = function(r) return r.m.blue or 0 end },
        { key = "skin", label = "Skin", width = 40, align = "CENTER", get = function(r)
            if not r.m.skinnable then return "-" end
            local need = ns.SkinSkillForLevel(r.m.maxLevel)
            return "|cff" .. ns.ColorHex[ns.SkillColor(need, ns.Player:Skill("skin"))] .. need .. "|r"
        end, sort = function(r) return r.m.skinnable and ns.SkinSkillForLevel(r.m.maxLevel) or 0 end },
        { key = "n", label = "Spawns", width = 50, align = "RIGHT", get = function(r) return r.spawns end, sort = function(r) return r.spawns end },
    }
    local selected
    local tbl = UI.Table(panel, cols, 17, function(r) selected = r panel:ShowDetail(r) end, function(owner, r)
        GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
        GameTooltip:AddLine(string.format("%s (%d-%d)", r.m.name, r.m.minLevel, r.m.maxLevel), 1, 1, 1)
        for _, l in ipairs(ns.Tooltip:Lines(r.m.id, r.m.maxLevel)) do
            if l[2] then GameTooltip:AddDoubleLine(l[1], l[2], 1, 1, 1, 1, 1, 1) else GameTooltip:AddLine(l[1], 1, 1, 1) end
        end
        GameTooltip:AddLine("Click for drops and Farm this mob.", 0.5, 0.5, 0.5)
        GameTooltip:Show()
    end)
    tbl:SetPoint("TOPLEFT", 0, -36)
    tbl.sortKey = "val"

    -- detail strip ---------------------------------------------------------------
    local d = UI.Panel(panel, T.panel, T.border)
    d:SetPoint("TOPLEFT", tbl, "BOTTOMLEFT", 0, -8)
    d:SetPoint("BOTTOMRIGHT", 0, 0)
    d.title = UI.Label(d, "", "GameFontNormal")
    d.title:SetPoint("TOPLEFT", 10, -8)
    d.sub = UI.Muted(d, "")
    d.sub:SetPoint("LEFT", d.title, "RIGHT", 10, 0)
    d.drops = {}
    for i = 1, 8 do
        local col, row = (i - 1) % 4, math.floor((i - 1) / 4)
        local fs = UI.Label(d, "", "GameFontHighlightSmall")
        fs:SetPoint("TOPLEFT", 10 + col * 196, -30 - row * 18)
        fs:SetWidth(190)
        fs:SetWordWrap(false)
        d.drops[i] = fs
    end
    d.farm = UI.Button(d, "Farm this mob", 130, function()
        if not selected then return end
        local r = ns.Finder:MobResult(selected.m.id, selected.zone)
        if not r then ns:Print("No spawn points known for " .. selected.m.name .. ".") return end
        ns.Route:Start(r)
        ns:Print(string.format("Farming %s in %s: ~%s/h. Route and area are on the map.", selected.m.name, r.zoneName, ns.Money(r.perHour, true)))
    end, "primary", 26)
    d.farm:SetPoint("BOTTOMLEFT", 10, 8)
    d.map = UI.Button(d, "Show on world map", 140, function()
        if not selected then return end
        local r = ns.Finder:MobResult(selected.m.id, selected.zone)
        if r then ns.Route:Preview(r) ns.Overlay:OpenMapTo(r.uiMap) end
    end, nil, 26)
    d.map:SetPoint("LEFT", d.farm, "RIGHT", 8, 0)
    d.hint = UI.Muted(d, "Select a mob to see everything it drops.")
    d.hint:SetPoint("TOPLEFT", 10, -10)

    function panel:ShowDetail(r)
        local on = r ~= nil
        d.hint:SetShown(not on)
        d.title:SetShown(on) d.sub:SetShown(on) d.farm:SetShown(on) d.map:SetShown(on)
        for _, fs in ipairs(d.drops) do fs:SetText("") end
        if not r then return end
        d.title:SetText(string.format("%s |cff9d9d9d(%d-%d)|r", r.m.name, r.m.minLevel, r.m.maxLevel))
        d.sub:SetText(string.format("%s  ·  %s/kill  ·  %d spawns%s", ns.Player:ZoneName(r.zone), ns.Money(r.value, true), r.spawns,
            r.cave and ("  ·  |cff9e7af2" .. (r.caveName or "cave") .. "|r") or ""))
        local parts = {}
        for _, p in ipairs(r.parts) do parts[#parts + 1] = p end
        table.sort(parts, function(a, b) if a.value ~= b.value then return a.value > b.value end return a.p > b.p end)
        local i = 0
        for _, p in ipairs(parts) do
            if i >= 8 then break end
            i = i + 1
            local icon, label
            if p.coin then icon, label = "Interface\\Icons\\INV_Misc_Coin_01", "Coin"
            elseif p.greens then icon, label = "Interface\\Icons\\INV_Enchant_DustStrange", p.greens == 3 and "|cff0070ddBlue gear|r" or "|cff1eff00Green gear|r"
            else icon, label = itemIcon(p.id), DS:ColoredItem(p.id) end
            d.drops[i]:SetText(string.format("|T%s:14|t %s |cff9d9d9d%s · %s|r", icon, label, p.coin and "" or ns.Pct(p.p), ns.Money(p.value, true)))
        end
        if i == 0 then d.drops[1]:SetText("|cff9d9d9dNo priced drops (try Auctionator/AuctionTrends price data).|r") end
    end

    -- search -------------------------------------------------------------------
    local function zonesToScan()
        if zoneMode == "here" then
            local m = ns.Player:MapID()
            return (m and ns.Zones[m]) and { m } or {}
        elseif zoneMode == "level" then
            local lvl, out = ns.Player:Level(), {}
            for id, z in pairs(ns.Zones) do
                if z.faction ~= "S" and z.min <= lvl + 3 and z.max >= lvl - 6 then out[#out + 1] = id end
            end
            return out
        end
        return { zoneMode }
    end

    local function resolveItem(text)
        if searchItem then return searchItem end
        local lower = text:lower()
        if lower == "" then return nil end
        if ForagerData and ForagerData.items then
            for iid, it in pairs(ForagerData.items) do if it[1]:lower() == lower then return iid end end
        end
    end

    function panel:Search()
        DS:Load()
        local text = strtrim(searchText or "")
        local itemID = resolveItem(text)
        local lower = text:lower()
        local skills = {}
        for k, v in pairs(ns.Player.skills) do skills[k] = v.rank end
        local lvl = ns.Player:Level()
        local wantLoc = ns.settings.location
        local rows = {}
        local zones = zonesToScan()
        for _, zone in ipairs(zones) do
            for npc, pts in pairs(DS:GetZoneMobs(zone)) do
                local m = DS:GetMob(npc)
                if m and not DS:IsFriendly(m) and (zoneMode ~= "level" or (m.maxLevel <= lvl + 3 and m.maxLevel >= lvl - 10)) then
                    local keep = true
                    local itemP
                    if itemID then
                        keep = false
                        for _, list in ipairs({ m.farm, m.skin, m.pickpocket }) do
                            for _, e in ipairs(list) do if e[1] == itemID then itemP = math.max(itemP or 0, e[2]) keep = true end end
                        end
                    elseif lower ~= "" then
                        keep = m.name:lower():find(lower, 1, true) ~= nil
                        if not keep then
                            for _, e in ipairs(m.farm) do
                                local n = DS:ItemName(e[1])
                                if n and n:lower():find(lower, 1, true) then keep = true break end
                            end
                        end
                    end
                    local cave, caveName
                    if keep then
                        cave, caveName = ns.Caves:MobInCave(npc, zone, pts)
                        if wantLoc == "cave" then keep = cave == true
                        elseif wantLoc == "outdoor" then keep = cave ~= true end
                    end
                    if keep then
                        local v, parts = ns.Finder:MobValue(m, "gold", skills, lvl)
                        local best
                        if itemID then
                            best = { id = itemID, p = itemP or 0, value = (ns.Prices:Get(itemID)) * (itemP or 0) }
                        else
                            for _, p in ipairs(parts) do
                                if p.id and (not best or p.value > best.value or (p.value == best.value and p.p > best.p)) then best = p end
                            end
                        end
                        rows[#rows + 1] = { m = m, zone = zone, pts = pts, spawns = #pts / 2, value = v, parts = parts, best = best,
                            cave = cave, caveName = caveName }
                    end
                end
            end
        end
        local empty
        if #zones == 0 then empty = "You're not in a farming zone. Pick a zone or 'All zones for my level'."
        elseif wantLoc == "cave" then empty = "No cave mobs known here yet. Caves fill in from explored map areas and as you walk through caves and mines."
        else empty = "No mobs match." end
        tbl.sortKey = itemID and "best" or (tbl.sortKey == "best" and "val" or tbl.sortKey)
        tbl:SetData(rows, false, empty)
        selected = nil
        panel:ShowDetail(nil)
    end

    ns:On("FORAGER_MOB_SEARCH", function(_, name)
        if not name then return end
        searchText, searchItem = name, nil
        search:SetText(name)
        zoneMode = "level"
        zoneDD:Refresh()
        panel:Search()
    end)
    ns:On("ZONE_CHANGED_NEW_AREA", function() if zoneMode == "here" then panel.stale = true end end)
    panel.OnActivate = function()
        loc:Refresh()
        if panel.stale or #tbl.data == 0 then panel.stale = false panel:Search() end
    end
end)
