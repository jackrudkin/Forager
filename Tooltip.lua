-- Mob tooltip: skinnable + required skill, skin item chances, cloth/meat/elemental drops,
-- gear grade chances (green/blue/purple) with disenchant hint, pick pocket boxes.
-- Bundled rates are Classic-era estimates (+ Forever Scarce where sourced); own observations replace them from minSamples.
local _, ns = ...
local Tooltip = {}
ns.Tooltip = Tooltip
local DS, P, Safe = ns.DS, ns.Player, ns.Safe

local GREY = "|cff9d9d9d"

local function itemText(id, p)
    return DS:ColoredItem(id) .. " " .. ns.Pct(p)
end

local function joinList(list, max)
    local parts = {}
    for i = 1, math.min(max or 4, #list) do parts[#parts + 1] = itemText(list[i][1], list[i][2]) end
    return table.concat(parts, GREY .. " · |r")
end

--- Merge bundled list {{id,p}} with own counts {[id]=n} over total. Returns list, label.
local function rates(bundled, ownCounts, ownTotal, minSamples)
    if ownTotal and ownTotal >= minSamples and ownCounts then
        local out = {}
        for id, n in pairs(ownCounts) do out[#out + 1] = { id, n / ownTotal } end
        table.sort(out, function(a, b) return a[2] > b[2] end)
        return out, "|cff7fd36bmy data n=" .. ownTotal .. "|r"
    end
    local label = GREY .. "estimate" .. ((ownTotal and ownTotal > 0) and (" | me n=" .. ownTotal) or "") .. "|r"
    if not bundled or #bundled == 0 then
        if ownTotal and ownTotal > 0 and ownCounts then
            local out = {}
            for id, n in pairs(ownCounts) do out[#out + 1] = { id, n / ownTotal } end
            table.sort(out, function(a, b) return a[2] > b[2] end)
            return out, GREY .. "learning (n=" .. ownTotal .. ")|r"
        end
        return nil, label
    end
    return bundled, label
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
            local list, label = rates(m and m.skin, own and own.si, own and own.s, minN)
            add(string.format("|cff%sSkinnable %d|r%s", ns.ColorHex[col], need, have and (GREY .. " (you " .. have .. ")|r") or ""), label)
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
        local list, label = rates(m and m.farm, ownFarm, own and own.k, minN)
        if list and #list > 0 then
            add("|cffffd100Drops|r", label)
            add("  " .. joinList(list, 4))
        end
    end

    -- gear grades
    if s.tooltipGear then
        local g, b, e, label
        local k = own and own.k or 0
        if k >= minN then
            local q = own.q or {}
            g, b, e = (q[2] or 0) / k, (q[3] or 0) / k, (q[4] or 0) / k
            label = "|cff7fd36bmy data n=" .. k .. "|r"
        elseif m and m.green then
            g, b, e = m.green, m.blue, m.epic
            label = GREY .. "Classic est." .. (k > 0 and (" | me n=" .. k) or "") .. "|r"
        elseif k > 0 then
            local q = own.q or {}
            g, b, e = (q[2] or 0) / k, (q[3] or 0) / k, (q[4] or 0) / k
            label = GREY .. "learning (n=" .. k .. ")|r"
        end
        if g then
            add(string.format("Gear: |cff1eff00%s|r · |cff0070dd%s|r · |cffa335ee%s|r", ns.Pct(g), ns.Pct(b), ns.Pct(e)), label)
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

function Tooltip:Init()
    if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and Enum and Enum.TooltipDataType then
        TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit, function(tt, data)
            local ok, err = pcall(onUnitTooltip, tt, data)
            if not ok then ns:Debug("tooltip", err) end
        end)
    else
        GameTooltip:HookScript("OnTooltipSetUnit", function(tt) pcall(onUnitTooltip, tt, nil) end)
    end
end
