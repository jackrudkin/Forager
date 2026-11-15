-- Find tab: ranked zones/sub-areas for the selected goal.
local _, ns = ...
local UI, Main = ns.UI, ns.Main

local function rateText(r)
    if r.mode == "skill" then return string.format("%.0f/h", r.perHour) end
    return ns.Money(r.perHour, true) .. "/h"
end

local function areaText(r)
    if not r.rect then return "whole zone" end
    return string.format("%.0f,%.0f", (r.rect[1] + r.rect[3]) * 50, (r.rect[2] + r.rect[4]) * 50)
end

local function levelText(r)
    if r.minLevel then return r.minLevel .. "-" .. r.maxLevel end
    return r.zoneMin .. "-" .. r.zoneMax
end

local function skillText(r)
    if not r.minSkill then return "-" end
    local goal = ns.GoalByKey[r.goal]
    local have = goal.prof and ns.Player:Skill(goal.prof)
    local col = ns.SkillColor(r.minSkill, have or (goal.prof and 0) or 300)
    return "|cff" .. ns.ColorHex[col] .. r.minSkill .. "|r"
end

local RISK_COLOR = { [0] = "40c040", [1] = "ffd100", [2] = "ff4040" }

local function rowTooltip(owner, r)
    local lines = { r.why, { "Confidence", r.confidence or "-" } }
    if r.mix then
        lines[#lines + 1] = " "
        for i = 1, math.min(6, #r.mix) do
            local t = ns.DS:GetType(r.mix[i].t)
            if t then lines[#lines + 1] = { "|T" .. ns.DS:TypeIcon(t) .. ":14|t " .. t.name, r.mix[i].n .. " spawns · skill " .. (t.skill or 0) } end
        end
    end
    if r.mobs then
        lines[#lines + 1] = " "
        for i = 1, math.min(6, #r.mobs) do
            local e = r.mobs[i]
            local v = ns.Finder:MobValue(e.m, r.goal, ns.Finder.last and ns.Finder.last.opts.skills or {}, ns.Player:Level())
            lines[#lines + 1] = { string.format("%s (%d-%d)", e.m.name, e.m.minLevel, e.m.maxLevel), e.n .. " spawns · " .. ns.Money(v) .. "/kill" }
        end
    end
    if r.fishItems then
        lines[#lines + 1] = " "
        for i = 1, math.min(6, #r.fishItems) do lines[#lines + 1] = { ns.DS:ColoredItem(r.fishItems[i].id), string.format("%.2f per catch", r.fishItems[i].p) } end
    end
    if r.questOverlap and #r.questOverlap > 0 then
        lines[#lines + 1] = "|cffffd100Quest mobs here:|r " .. table.concat(r.questOverlap, ", ")
    end
    if r.poiCount and r.poiCount > 0 then lines[#lines + 1] = "|cffffd100Quest objectives in this area:|r " .. r.poiCount end
    if r.detourMin then lines[#lines + 1] = string.format("Detour from nearest quest objective: +%.0f min (travel %.0f min + one loop)", r.detourMin, r.travelMin or 0) end
    if r.noPOIs then lines[#lines + 1] = "|cff9d9d9dNo quest objectives found on this map - ranked without detour.|r" end
    lines[#lines + 1] = "|cff9d9d9dClick: draw area + route and start the arrow.|r"
    UI.Tip(owner, string.format("%s - %s (%s)", r.zoneName, ns.GoalByKey[r.goal].label, areaText(r)), lines)
end

Main:RegisterTab("find", "Find", function(panel)
    local top = UI.Label(panel, "", "GameFontHighlightSmall")
    top:SetPoint("TOPLEFT", 2, -4)
    top:SetPoint("RIGHT", -230, 0)
    top:SetHeight(28)
    top:SetJustifyV("TOP")

    local search = UI.Button(panel, "Search", 90)
    search:SetPoint("TOPRIGHT", -2, -2)
    local enemy = UI.Check(panel, "Include enemy zones", function() return ns.settings.includeEnemy end, function(v) ns.settings.includeEnemy = v end,
        "Also rank zones controlled by the other faction.")
    enemy:SetPoint("RIGHT", search, "LEFT", -130, 0)

    local cols = {
        { key = "zone", label = "Zone", width = 150, get = function(r) return r.zoneName .. (r.rank > 1 and (" #" .. r.rank) or "") end, sort = function(r) return r.zoneName end },
        { key = "area", label = "Area", width = 70, get = areaText },
        { key = "rate", label = "Rate", width = 80, align = "RIGHT", get = rateText, sort = function(r) return r.perHour end, tip = "Gold per hour (or skill-ups per hour) - estimate." },
        { key = "score", label = "w/ travel", width = 80, align = "RIGHT", get = function(r) return r.score and (r.mode == "skill" and string.format("%.0f/h", r.score) or ns.Money(r.score, true) .. "/h") or "-" end,
            sort = function(r) return r.score or r.perHour end, tip = "Questing mode: rate including the detour from your quest objectives." },
        { key = "detour", label = "Detour", width = 56, align = "RIGHT", get = function(r) return r.detourMin and string.format("+%.0fm", r.detourMin) or "-" end, sort = function(r) return r.detourMin or 0 end },
        { key = "lvl", label = "Levels", width = 56, align = "CENTER", get = levelText, sort = function(r) return r.minLevel or r.zoneMin end },
        { key = "skill", label = "Skill", width = 44, align = "CENTER", get = skillText, sort = function(r) return r.minSkill or 0 end },
        { key = "count", label = "Density", width = 60, align = "RIGHT", get = function(r) return r.count and tostring(r.count) or "-" end, sort = function(r) return r.count or 0 end, tip = "Node spawn points or mob spawns in the area." },
        { key = "risk", label = "Risk", width = 90, get = function(r) return "|cff" .. RISK_COLOR[r.riskLevel or 0] .. r.risk .. "|r" end, sort = function(r) return r.riskLevel or 0 end },
        { key = "conf", label = "Data", width = 100, get = function(r) return "|cff9d9d9d" .. (r.confidence or "") .. "|r" end },
    }
    local tbl = UI.Table(panel, cols, 20, function(r)
        ns.Route:Start(r)
        ns:Print(string.format("Route set: %s in %s (%s).", ns.GoalByKey[r.goal].label, r.zoneName, rateText(r)))
    end, rowTooltip)
    tbl:SetPoint("TOPLEFT", 0, -34)
    tbl.sortKey = "score"

    local best = UI.Label(panel, "", "GameFontHighlightSmall")
    best:SetPoint("TOPLEFT", tbl, "BOTTOMLEFT", 2, -6)
    best:SetPoint("RIGHT", -2, 0)

    local function show(results, chosen)
        tbl:SetData(results or {})
        local f = ns.Finder.last
        if not f then top:SetText("") return end
        local goal = f.goal
        local skill = goal.prof and ns.Player:Skill(goal.prof)
        local txt = string.format("|cffffd100%s|r · %s · level %d %s · skill %s · prices: %s",
            goal.label, f.opts.mode == "skill" and "skill-ups/hour" or "gold/hour", f.opts.level, f.opts.faction == "H" and "Horde" or "Alliance",
            goal.prof and (skill and tostring(skill) or "|cffff4040not learned|r") or "-", table.concat(ns.Prices:Available(), " > "))
        if goal.prof and not skill then txt = txt .. "\n|cffff8040You don't have this profession - showing what's possible at max skill.|r" end
        top:SetText(txt)
        if f.opts.questing then
            local any = ns.Finder:Run({ goal = goal.key, mode = f.opts.mode, perZone = 1 })
            ns.Finder.last = f -- keep questing results as "last"
            local b = any[1]
            if b then
                best:SetText(string.format("|cff9d9d9dBest anywhere for comparison:|r %s %s (%s)", b.zoneName, rateText(b), areaText(b)))
            else
                best:SetText("")
            end
        else
            best:SetText(#results == 0 and "|cffff8040Nothing found. Check your skill/level, or tick 'Include enemy zones'.|r" or "")
        end
    end

    local function run()
        local goal = Main:Goal()
        local opts = { goal = goal, perZone = 2, includeEnemy = ns.settings.includeEnemy }
        if ns.Quests:IsActive() then
            local z1, z2 = ns.Quests:Zones()
            opts.zones, opts.questing, opts.questNames = { z1, z2 }, true, ns.Quests:ObjectiveNames()
            opts.perZone = 4
        end
        show(ns.Finder:Run(opts))
    end
    search:SetScript("OnClick", run)
    ns:On("FORAGER_GOAL_CHANGED", function() if panel:IsVisible() then run() end end)
    ns:On("FORAGER_QUESTZONE_CHANGED", function() if panel:IsVisible() then run() end end)
    ns:On("FORAGER_SHOW_RESULTS", function(_, results) show(results) end)
    panel.OnActivate = function() if not ns.Finder.last then run() end end
end)
