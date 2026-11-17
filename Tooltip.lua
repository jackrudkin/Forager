-- Mob tooltip: skinnable + required skill, skin item chances, cloth/meat/elemental drops,
-- gear grade chances (green/blue/purple) with disenchant hint, pick pocket boxes.
-- Bundled rates are Classic-era estimates (+ Forever Scarce where sourced); your observations are blended in
-- (they count half at minSamples, see Learn.Blend).
local _, ns = ...
local Tooltip = {}
ns.Tooltip = Tooltip
local DS, P, Safe, L = ns.DS, ns.Player, ns.Safe, ns.L

local GREY = "|cff9d9d9d"

local function itemText(id, p)
    return DS:ColoredItem(id) .. " " .. ns.Pct(p)
end

local function joinList(list, max)
    local parts = {}
    for i = 1, math.min(max or 4, #list) do parts[#parts + 1] = itemText(list[i][1], list[i][2]) end
    return table.concat(parts, GREY .. " · |r")
end

local function label(n, minSamples)
    if n and n >= minSamples then return "|cff7fd36bmy data n=" .. n .. "|r" end
    if n and n > 0 then return GREY .. "blend n=" .. n .. "|r" end
    return GREY .. "estimate|r"
end

--- Blend bundled list {{id,p}} with own counts {[id]=n} over total. Returns list (or nil), label.
local function rates(bundled, ownCounts, ownTotal, minSamples)
    ownTotal = ownTotal or 0
    if (not bundled or #bundled == 0) and (ownTotal == 0 or not ownCounts) then return nil, label(0, minSamples) end
    local list = ns.Learn:BlendList(bundled, ownCounts, ownTotal)
    return list, label(ownTotal, minSamples)
end

function Tooltip:Lines(npcID, level, opts)
    local s = ns.settings
    local m = DS:GetMob(npcID)
    local own = ns.db.mobs[npcID]
    local lines = {}
    local function add(l, r) lines[#lines + 1] = { l, r } end
    if not m and not own then
        add(GREY .. "Forager: learning (n=0)|r")
        return lines
    end
    level = level or (m and m.maxLevel) or 1
    local minN = s.minSamples or 30

    -- skinning
    if s.tooltipSkin then
        local skinnable = (m and m.skinnable) or (own and (own.s or 0) > 0)
        if skinnable then
            local need = ns.SkinSkillForLevel(level)
            local have = P:Skill("skin")
            local col = ns.SkillColor(need, have)
            -- m.skin is already blended with your skins (Learn:SkinList)
            local list = m and m.skin
            local lab = label(own and (own.ss or own.s) or 0, minN)
            if not m and own and own.si then list = rates(nil, own.si, own.s, minN) end
            add(string.format("|cff%sSkinnable %d|r%s", ns.ColorHex[col], need, have and (GREY .. " (you " .. have .. ")|r") or ""), lab)
            if list then add("  " .. joinList(list, 4)) end
        end
    end

    -- farmables (cloth, meat, elemental, trade goods, lockboxes)
    if s.tooltipFarm then
        local ownFarm
        if own and own.i then
            ownFarm = {}
            for id, n in pairs(own.i) do
                local cat = DS:ItemCategory(id)
                if cat ~= "other" then ownFarm[id] = n end
            end
        end
        local list, lab = rates(m and m.farm, ownFarm, own and own.k, minN)
        if list and #list > 0 then
            add("|cffffd100Drops|r", lab)
            add("  " .. joinList(list, 4))
        end
    end

    -- gear grades
    if s.tooltipGear then
        local g, b, e
        local k = own and own.k or 0
        local q = own and own.q or {}
        local B = ns.Learn.Blend
        if m and m.green then
            g, b, e = B(k, (q[2] or 0) / math.max(1, k), m.green), B(k, (q[3] or 0) / math.max(1, k), m.blue), B(k, (q[4] or 0) / math.max(1, k), m.epic)
        elseif k > 0 then
            g, b, e = (q[2] or 0) / k, (q[3] or 0) / k, (q[4] or 0) / k
        end
        if g then
            add(string.format("Gear: |cff1eff00%s|r · |cff0070dd%s|r · |cffa335ee%s|r", ns.Pct(g), ns.Pct(b), ns.Pct(e)), label(k, minN))
            if g > 0 and m and m.greenIlvl and m.greenIlvl > 0 then
                local v, best = ns.Prices:DisenchantValue(m.greenIlvl, 2)
                add(string.format("  %sGreen (ilvl ~%d) DE: %s ≈ %s|r", GREY, m.greenIlvl, best and DS:ItemName(best) or "-", ns.Money(v)))
            end
        end
    end

    -- pick pocket (rogues)
    if s.tooltipPickpocket and P.skills.lock then
        local list = rates(m and m.pickpocket, own and own.pi, own and own.p, minN)
        if list and #list > 0 then add("Pick pocket: " .. joinList(list, 2)) end
    end
    return lines
end

local function onUnitTooltip(tooltip, data)
    if not ns.db or not ns.settings.tooltip then return end
    if tooltip ~= GameTooltip then return end
    local guid = data and Safe(data.guid)
    if not guid then
        local ok, _, unit = pcall(tooltip.GetUnit, tooltip)
        unit = ok and Safe(unit)
        if unit then guid = Safe(UnitGUID(unit)) end
    end
    if not guid then return end
    local npcID, kind = ns.IDFromGUID(guid)
    if kind ~= "Creature" or not npcID then return end
    local level = Safe(UnitLevel("mouseover"))
    if level and level < 0 then level = nil end
    local ok, lines = pcall(Tooltip.Lines, Tooltip, npcID, level)
    if not ok or not lines or #lines == 0 then return end
    for _, l in ipairs(lines) do
        if l[2] then tooltip:AddDoubleLine(l[1], l[2], 1, 1, 1, 1, 1, 1) else tooltip:AddLine(l[1], 1, 1, 1) end
    end
end

-------------------------------------------------------------------------------
-- item tooltips: best spot for this character, Alt+Shift+click to farm
-------------------------------------------------------------------------------
local best, bestN = {}, 0   -- [itemID] = { text, gen, at } (capped)
local hovered

--- Can Forager search this item? (node yields, mob drops in the data, Scarce, seeds)
function Tooltip.Farmable(itemID)
    if not itemID then return false end
    if ns.KnownItems[itemID] or DS:TypeForItem(itemID) then return true end
    return ForagerData and ForagerData.items and ForagerData.items[itemID] ~= nil or false
end

local function bestText(r)
    if not r then return GREY .. "Forager: no spot for your level and skills|r" end
    local where = (r.areaName and (r.areaName .. ", ") or "") .. (r.zoneName or "")
    local rate = r.itemUnits and r.itemUnits > 0 and string.format("~%.0f/h", r.itemUnits) or (ns.Money(r.perHour, true) .. "/h")
    return "|cff7fd36bForager:|r " .. L["best spot"] .. " |cffffffff" .. where .. "|r " .. GREY .. rate .. "|r"
end

--- Search the best spot for an item in the background (one at a time; a newer hover replaces it).
function Tooltip:QueueBest(itemID)
    if InCombatLockdown() or not DS:HasBundled() then return end
    ns.RunJob("itemtip", function()
        local keep = ns.Finder.last
        local res = ns.Finder:Search(ns.Finder:Options(ns.Finder:ItemGoal(itemID), "gold"))
        ns.Finder.last = keep
        return res
    end, function(res)
        if not res then return end
        if bestN >= 100 then wipe(best) bestN = 0 end
        if not best[itemID] then bestN = bestN + 1 end
        best[itemID] = { text = bestText(res[1]), gen = ns.gen, at = GetTime() }
        if hovered == itemID and GameTooltip:IsShown() and GameTooltip.RefreshData then pcall(GameTooltip.RefreshData, GameTooltip) end
    end)
end

local function onItemTooltip(tooltip, data)
    if not ns.db or not ns.settings.tooltipItem or (ns.UI and ns.UI.ownTip) then return end
    if tooltip ~= GameTooltip and tooltip ~= ItemRefTooltip then return end
    local id = data and Safe(data.id)
    if type(id) ~= "number" or not Tooltip.Farmable(id) then return end
    local b = best[id]
    if b and b.gen == ns.gen and GetTime() - b.at < 600 then
        tooltip:AddLine(b.text, 1, 1, 1)
    else
        hovered = id
        ns.After(0.4, function() if hovered == id and GameTooltip:IsShown() then Tooltip:QueueBest(id) end end)
    end
    tooltip:AddLine(GREY .. L["Alt+Shift+click: farm this with Forager"] .. "|r", 1, 1, 1)
end

--- Alt+Shift+click on any item link: open Forager's Farm tab on that item.
function Tooltip.OnModifiedClick(link)
    if not (IsAltKeyDown and IsAltKeyDown() and IsShiftKeyDown and IsShiftKeyDown()) then return end
    local id = type(link) == "string" and tonumber(link:match("item:(%d+)"))
    if not id or not Tooltip.Farmable(id) then return end
    ns.char.goal = ns.Finder:ItemGoal(id)
    ns.Main:Toggle("farm")
    ns:Fire("FORAGER_GOAL_CHANGED")
    ns:Print(string.format(L["Looking for the best place to farm %s."], DS:ItemName(id)))
end

function Tooltip:Init()
    if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and Enum and Enum.TooltipDataType and Enum.TooltipDataType.Item then
        TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tt, data)
            local ok, err = pcall(onItemTooltip, tt, data)
            if not ok then ns:Error("item tooltip", err) end
        end)
    end
    if HandleModifiedItemClick then
        hooksecurefunc("HandleModifiedItemClick", function(link)
            local ok, err = pcall(Tooltip.OnModifiedClick, link)
            if not ok then ns:Error("item click", err) end
        end)
    end
    GameTooltip:HookScript("OnHide", function() hovered = nil end)
    if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and Enum and Enum.TooltipDataType then
        TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit, function(tt, data)
            local ok, err = pcall(onUnitTooltip, tt, data)
            if not ok then ns:Debug("tooltip", err) end
        end)
    else
        GameTooltip:HookScript("OnTooltipSetUnit", function(tt) pcall(onUnitTooltip, tt, nil) end)
    end
end
