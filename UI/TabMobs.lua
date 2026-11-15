-- Mobs tab: look up any mob or material.
local _, ns = ...
local UI, Main = ns.UI, ns.Main
local DS = ns.DS

local function firstZone(npcID)
    for id in pairs(ns.Zones) do
        local mobs = DS:GetZoneMobs(id)
        if mobs[npcID] then return id end
    end
end

Main:RegisterTab("mobs", "Mobs", function(panel)
    local box = CreateFrame("EditBox", nil, panel, "InputBoxTemplate")
    box:SetSize(220, 20)
    box:SetPoint("TOPLEFT", 8, -4)
    box:SetAutoFocus(false)
    local hint = UI.Label(panel, "Mob name or material (e.g. |cffffffffLinen Cloth|r, |cffffffffBoar|r)", "GameFontDisableSmall")
    hint:SetPoint("LEFT", box, "RIGHT", 8, 0)
    local zoneOnly = UI.Check(panel, "Current zone only", function() return panel.zoneOnly end, function(v) panel.zoneOnly = v panel:Search() end)
    zoneOnly:SetPoint("TOPRIGHT", -150, -2)

    local cols = {
        { key = "name", label = "Mob", width = 170, get = function(r) return r.m.name end, sort = function(r) return r.m.name end },
        { key = "lvl", label = "Lvl", width = 46, align = "CENTER", get = function(r) return r.m.minLevel .. "-" .. r.m.maxLevel end, sort = function(r) return r.m.maxLevel end },
        { key = "type", label = "Type", width = 70, get = function(r) return ns.CreatureTypes[r.m.ctype] or "?" end, sort = function(r) return r.m.ctype end },
        { key = "zone", label = "Zone", width = 120, get = function(r) return r.zone and ns.Player:ZoneName(r.zone) or "-" end, sort = function(r) return r.zone and ns.Player:ZoneName(r.zone) or "" end },
        { key = "item", label = "Chance", width = 60, align = "RIGHT", get = function(r) return r.itemP and ns.Pct(r.itemP) or "-" end, sort = function(r) return r.itemP or 0 end,
            tip = "Chance for the searched material (per kill, per skin, or per pick pocket)." },
        { key = "skin", label = "Skin", width = 50, align = "CENTER", get = function(r)
            if not r.m.skinnable then return "-" end
            local need = ns.SkinSkillForLevel(r.m.maxLevel)
            return "|cff" .. ns.ColorHex[ns.SkillColor(need, ns.Player:Skill("skin"))] .. need .. "|r"
        end, sort = function(r) return r.m.skinnable and ns.SkinSkillForLevel(r.m.maxLevel) or 0 end },
        { key = "g", label = "Green", width = 52, align = "RIGHT", get = function(r) return r.m.green and ("|cff1eff00" .. ns.Pct(r.m.green) .. "|r") or "-" end, sort = function(r) return r.m.green or 0 end },
        { key = "b", label = "Blue", width = 52, align = "RIGHT", get = function(r) return r.m.blue and ("|cff0070dd" .. ns.Pct(r.m.blue) .. "|r") or "-" end, sort = function(r) return r.m.blue or 0 end },
        { key = "e", label = "Epic", width = 52, align = "RIGHT", get = function(r) return r.m.epic and ("|cffa335ee" .. ns.Pct(r.m.epic) .. "|r") or "-" end, sort = function(r) return r.m.epic or 0 end },
        { key = "val", label = "Value/kill", width = 80, align = "RIGHT", get = function(r) return ns.Money(r.value) end, sort = function(r) return r.value end },
        { key = "n", label = "My n", width = 50, align = "RIGHT", get = function(r) local o = ns.db.mobs[r.m.id] return o and tostring(o.k or 0) or "0" end,
            sort = function(r) local o = ns.db.mobs[r.m.id] return o and o.k or 0 end },
    }
    local tbl = UI.Table(panel, cols, 21, nil, function(owner, r)
        GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
        GameTooltip:AddLine(string.format("%s (%d-%d)", r.m.name, r.m.minLevel, r.m.maxLevel), 1, 1, 1)
        for _, l in ipairs(ns.Tooltip:Lines(r.m.id, r.m.maxLevel)) do
            if l[2] then GameTooltip:AddDoubleLine(l[1], l[2], 1, 1, 1, 1, 1, 1) else GameTooltip:AddLine(l[1], 1, 1, 1) end
        end
        GameTooltip:Show()
    end)
    tbl:SetPoint("TOPLEFT", 0, -30)
    tbl.sortKey = "item"

    local status = UI.Label(panel, "", "GameFontHighlightSmall")
    status:SetPoint("TOPLEFT", tbl, "BOTTOMLEFT", 2, -6)

    local function itemIDFromText(text)
        local id = tonumber(text:match("item:(%d+)")) or tonumber(text)
        if id then return id end
        local lower = text:lower()
        if ForagerData and ForagerData.items then
            for iid, it in pairs(ForagerData.items) do if it[1]:lower() == lower then return iid end end
        end
        for iid, name in pairs(ns.EnchantNames) do if name:lower() == lower then return iid end end
    end

    function panel:Search()
        DS:Load()
        local text = strtrim(box:GetText() or "")
        local rows = {}
        local zoneFilter = panel.zoneOnly and ns.Player:MapID()
        local skills = {}
        for k, v in pairs(ns.Player.skills) do skills[k] = v.rank end
        local itemID = text ~= "" and itemIDFromText(text)
        local ids
        if itemID then
            ids = DS:MobsForItem(itemID)
            status:SetText("Mobs that give " .. DS:ColoredItem(itemID) .. " (Classic estimates + your data)")
        else
            ids = {}
            local pool = zoneFilter and DS:GetZoneMobs(zoneFilter) or nil
            local lower = text:lower()
            if pool then for id in pairs(pool) do ids[#ids + 1] = id end else ids = DS:AllMobIDs() end
            if lower ~= "" then
                local f = {}
                for _, id in ipairs(ids) do local m = DS:GetMob(id) if m and m.name:lower():find(lower, 1, true) then f[#f + 1] = id end end
                ids = f
            end
            status:SetText(text == "" and "Type a mob or material name and press Enter." or (#ids .. " mobs"))
            if text == "" and not zoneFilter then ids = {} end
        end
        for _, id in ipairs(ids) do
            local m = DS:GetMob(id)
            if m and #rows < 400 then
                local zone = zoneFilter or firstZone(id)
                if not zoneFilter or DS:GetZoneMobs(zoneFilter)[id] then
                    local p
                    if itemID then
                        for _, list in ipairs({ m.farm, m.skin, m.pickpocket }) do
                            for _, e in ipairs(list) do if e[1] == itemID then p = math.max(p or 0, e[2]) end end
                        end
                    end
                    rows[#rows + 1] = { m = m, zone = zone, itemP = p, value = (ns.Finder:MobValue(m, "gold", skills, ns.Player:Level())) }
                end
            end
        end
        tbl:SetData(rows)
    end
    box:SetScript("OnEnterPressed", function(self) self:ClearFocus() panel:Search() end)
    box:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    panel.OnActivate = function() if #tbl.data == 0 then panel.zoneOnly = true zoneOnly:SetChecked(true) panel:Search() end end
end)
