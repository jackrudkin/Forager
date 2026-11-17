-- Risk: how dangerous a farm spot is, as a 0-100 score with three parts.
--   Gank        PvP ruleset only: who owns the zone (friendly / contested / enemy) and how close the
--               nearest enemy settlement or flight path is (QuestieDB NPCs friendly to one faction).
--   Death       mobs above your level, elites, packs (mobs within social-aggro range of each other),
--               caves, and your own deaths in that area.
--   Hyperspawn  how many (non-grey) mob spawns are packed into the area, and caves, where players
--               report fast respawns are worst.
-- Overall = 1 - (1 - gank)(1 - death)(1 - hyperspawn), as if they were independent chances.
-- The ruleset (PvP or Normal) is learned: on PvP rulesets you are always flagged in contested and
-- enemy zones, so being unflagged there once proves Normal.
local _, ns = ...
local Risk = {}
ns.Risk = Risk
local DS, P = ns.DS, ns.Player

Risk.LEVELS = {
    { max = 20, label = "Low", color = "7fd36b" },
    { max = 40, label = "Medium", color = "ffd100" },
    { max = 65, label = "High", color = "ff8040" },
    { max = 101, label = "Very high", color = "ff3030" },
}
Risk.FILTER = { any = 101, high = 65, medium = 40, low = 20 } -- hide spots at or above this score

local PACK_YARDS = 12      -- mobs this close to each other tend to pull together
local DEATH_CELL = 50      -- death log cells: 2% of the map

-------------------------------------------------------------------------------
-- ruleset
-------------------------------------------------------------------------------
--- "pvp" | "normal", guessed (true when not known yet).
function Risk:Ruleset()
    local s = ns.settings.ruleset
    if s == "pvp" or s == "normal" then return s, false end
    local learned = ns.db and ns.db.ruleset
    if learned == "pvp" or learned == "normal" then return learned, false end
    return "pvp", true
end

function Risk:LearnRuleset()
    if not (GetZonePVPInfo and UnitIsPVP) or not ns.db then return end
    local zt = ns.Safe(GetZonePVPInfo())
    if zt ~= "contested" and zt ~= "hostile" then return end
    if P:InRestrictedContent() then return end
    local flagged = ns.Safe(UnitIsPVP("player"))
    if flagged == nil then return end
    if not flagged then
        ns.db.ruleset = "normal"
    elseif ns.db.ruleset ~= "normal" then
        -- flagged in contested/enemy zones on two different zones -> PvP ruleset
        local m = P:MapID()
        ns.db.rulesetPvpZones = ns.db.rulesetPvpZones or {}
        if m then ns.db.rulesetPvpZones[m] = true end
        if ns.Count(ns.db.rulesetPvpZones) >= 2 then ns.db.ruleset = "pvp" end
    end
end

-------------------------------------------------------------------------------
-- deaths
-------------------------------------------------------------------------------
local function dkey(x, y) return math.floor(x * DEATH_CELL) * 1000 + math.floor(y * DEATH_CELL) end

function Risk:RecordDeath()
    local m = P:MapID()
    if not m or P:InRestrictedContent() then return end
    local x, y = P:Position(m)
    if not x then return end
    ns.db.deaths[m] = ns.db.deaths[m] or {}
    local k = dkey(x, y)
    ns.db.deaths[m][k] = (ns.db.deaths[m][k] or 0) + 1
end

--- Your deaths inside a rect (zone coords).
function Risk:DeathsIn(uiMap, rect)
    local z = ns.db.deaths[uiMap]
    if not z or not rect then return 0 end
    local n = 0
    for k, c in pairs(z) do
        local x, y = (math.floor(k / 1000) + 0.5) / DEATH_CELL, ((k % 1000) + 0.5) / DEATH_CELL
        if x >= rect[1] - 0.01 and x <= rect[3] + 0.01 and y >= rect[2] - 0.01 and y <= rect[4] + 0.01 then n = n + c end
    end
    return n
end

-------------------------------------------------------------------------------
-- assessment
-------------------------------------------------------------------------------
local zoneMobs = {} -- [uiMap] = { {x, y, lvl, elite}, ... } (static data, built once)
local function mobsOf(uiMap)
    local key = P:Faction() .. uiMap
    local list = zoneMobs[key]
    if list then return list end
    list = {}
    for npc, flat in pairs(DS:GetZoneMobs(uiMap)) do
        local m = DS:GetMob(npc)
        if m and not DS:IsFriendly(m) then
            local elite = m.rank == 1 or m.rank == 2 or m.rank == 3
            for i = 1, #flat, 2 do list[#list + 1] = { flat[i], flat[i + 1], m.maxLevel, elite } end
        end
    end
    zoneMobs[key] = list
    return list
end

local function greyBelow(level)
    if level <= 5 then return 0 end
    if level <= 39 then return level - 5 - math.floor(level / 10) end
    return level - 1 - math.floor(level / 5)
end

function Risk:Label(score)
    for _, l in ipairs(Risk.LEVELS) do if score < l.max then return l.label, l.color end end
    return "Very high", "ff3030"
end

--- Adds r.danger = { score, label, color, gank, death, hyper, why = {gank=, death=, hyper=}, guess }.
function Risk:Assess(r)
    local zone = ns.Zones[r.uiMap]
    if not zone then return end
    local level, faction = P:Level(), P:Faction()
    local w, h = P:ZoneSize(r.uiMap)
    local rect = r.rect
    local cx, cy = 0.5, 0.5
    if rect then cx, cy = (rect[1] + rect[3]) / 2, (rect[2] + rect[4]) / 2 end
    local why = { gank = {}, death = {}, hyper = {} }

    -- gank -------------------------------------------------------------------
    local ruleset, guess = Risk:Ruleset()
    local gank = 0
    if zone.faction == "S" then
        why.gank[#why.gank + 1] = "sanctuary"
    elseif ruleset ~= "pvp" then
        why.gank[#why.gank + 1] = "Normal ruleset: only if you flag yourself"
    else
        if zone.faction == "C" then gank = 45 why.gank[#why.gank + 1] = "contested zone"
        elseif zone.faction ~= faction then gank = 70 why.gank[#why.gank + 1] = "enemy territory"
        else gank = 5 why.gank[#why.gank + 1] = "your faction's zone" end
        if gank > 5 and rect then
            local enemyD, enemyFP, ownD
            for _, hub in ipairs(zone.hubs or {}) do
                local d = P:Distance(r.uiMap, cx, cy, hub[2], hub[3])
                if hub[1] ~= faction then
                    if not enemyD or d < enemyD then enemyD, enemyFP = d, hub[5] end
                elseif not ownD or d < ownD then
                    ownD = d
                end
            end
            local enemyName = faction == "A" and "Horde" or "Alliance"
            if enemyD and enemyD < 300 then
                gank = gank + 25 + (enemyFP and 10 or 0)
                why.gank[#why.gank + 1] = string.format("%s %s %d yd away", enemyName, enemyFP and "flight path" or "camp", enemyD)
            elseif enemyD and enemyD < 700 then
                gank = gank + 12
                why.gank[#why.gank + 1] = string.format("%s %s %d yd away", enemyName, enemyFP and "flight path" or "camp", enemyD)
            end
            if ownD and ownD < 250 then
                gank = gank - 10
                why.gank[#why.gank + 1] = string.format("own guards %d yd away", ownD)
            end
        end
        if guess then why.gank[#why.gank + 1] = "PvP ruleset assumed" end
    end
    gank = ns.Clamp(gank, 0, 100)

    -- death and hyperspawn (mobs in and around the area) ------------------------
    local death, hyper = 0, 0
    if rect then
        local m = 0.02
        local x1, y1, x2, y2 = rect[1] - m, rect[2] - m, rect[3] + m, rect[4] + m
        local grey = greyBelow(level)
        local inArea, maxLvl, elites = {}, 0, 0
        for _, p in ipairs(mobsOf(r.uiMap)) do
            if p[1] >= x1 and p[1] <= x2 and p[2] >= y1 and p[2] <= y2 then
                if p[4] then
                    elites = elites + 1
                elseif p[3] > grey then
                    inArea[#inArea + 1] = p
                    if p[3] > maxLvl then maxLvl = p[3] end
                end
            end
        end
        local over = maxLvl - level
        if over > 0 then
            death = death + math.min(50, over * 12)
            why.death[#why.death + 1] = string.format("mobs up to %d levels above you", over)
        end
        if elites >= 6 then death = death + 35 why.death[#why.death + 1] = elites .. " elite spawns"
        elseif elites >= 1 then death = death + 20 why.death[#why.death + 1] = elites .. " elite spawn" .. (elites > 1 and "s" or "") end
        -- packs: average neighbours within social-aggro range (sampled)
        local n = #inArea
        if n >= 2 then
            local step = math.max(1, math.floor(n / 120))
            local sum, cnt = 0, 0
            local R2 = PACK_YARDS * PACK_YARDS
            for i = 1, n, step do
                local a = inArea[i]
                local k = 0
                for j = 1, n do
                    if j ~= i then
                        local b = inArea[j]
                        local dx, dy = (a[1] - b[1]) * w, (a[2] - b[2]) * h
                        if dx * dx + dy * dy <= R2 then k = k + 1 end
                    end
                end
                sum, cnt = sum + k, cnt + 1
            end
            local avg = sum / cnt
            if avg >= 2 then death = death + 20 why.death[#why.death + 1] = string.format("tight packs (%.1f mobs nearby each)", avg)
            elseif avg >= 1 then death = death + 10 why.death[#why.death + 1] = "mobs in pairs" end
        end
        if r.cave then
            death = death + 10
            hyper = hyper + 20
            why.death[#why.death + 1] = "cave"
            why.hyper[#why.hyper + 1] = "cave (fast respawns are worst in caves)"
        end
        local deaths = Risk:DeathsIn(r.uiMap, rect)
        if deaths > 0 then
            death = death + math.min(45, deaths * 15)
            why.death[#why.death + 1] = string.format("you died here %d time%s", deaths, deaths > 1 and "s" or "")
        end
        -- spawn density per 100 x 100 yd
        local areaYd2 = math.max(1, (x2 - x1) * w * (y2 - y1) * h)
        local dens = n / (areaYd2 / 10000)
        local add = (dens >= 3 and 60) or (dens >= 2 and 45) or (dens >= 1 and 25) or (dens >= 0.5 and 10) or 0
        hyper = hyper + add
        if add > 0 then why.hyper[#why.hyper + 1] = string.format("%.1f mob spawns per 100x100 yd", dens) end
    end
    death, hyper = ns.Clamp(death, 0, 100), ns.Clamp(hyper, 0, 100)
    local score = 100 * (1 - (1 - gank / 100) * (1 - death / 100) * (1 - hyper / 100))
    local label, color = Risk:Label(score)
    r.danger = { score = score, label = label, color = color, gank = gank, death = death, hyper = hyper, why = why, guess = guess }
    return r.danger
end

--- Colored short text: "Risk: Medium".
function Risk:Short(r)
    local d = r and r.danger
    if not d then return "" end
    return string.format("|cff%sRisk: %s|r", d.color, d.label)
end

local function partLine(name, v, reasons)
    local label, color = Risk:Label(v)
    return string.format("|cff%s%s %s|r%s", color, name, label:lower(), #reasons > 0 and (" (" .. table.concat(reasons, ", ") .. ")") or "")
end

--- One line with the three parts.
function Risk:Line(r)
    local d = r and r.danger
    if not d then return "" end
    return string.format("%s  ·  %s  ·  %s  ·  %s", Risk:Short(r), partLine("gank", d.gank, {}), partLine("death", d.death, {}),
        partLine("hyperspawn", d.hyper, {}))
end

--- Tooltip with reasons.
function Risk:Tooltip(owner, r)
    local d = r and r.danger
    if not d then return end
    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    GameTooltip:AddLine(string.format("Risk: |cff%s%s|r (%d/100)", d.color, d.label, d.score + 0.5), 1, 1, 1)
    for _, part in ipairs({ { "Gank", d.gank, d.why.gank }, { "Death", d.death, d.why.death }, { "Hyperspawn", d.hyper, d.why.hyper } }) do
        local label, color = Risk:Label(part[2])
        GameTooltip:AddDoubleLine(part[1], string.format("|cff%s%s|r", color, label), 0.8, 0.8, 0.8)
        for _, reason in ipairs(part[3]) do GameTooltip:AddLine("   " .. reason, 0.7, 0.7, 0.7, true) end
    end
    GameTooltip:AddLine("Estimate from zone ownership, settlements, mob levels, elites, packs, spawn density and your deaths.", 0.5, 0.5, 0.5, true)
    GameTooltip:Show()
end

--- Hide results above the "Hide spots above risk" setting.
function Risk:Filter(results)
    local cap = Risk.FILTER[ns.settings.maxRisk or "any"] or 101
    if cap >= 101 then return results end
    local out = {}
    for _, r in ipairs(results) do
        if not r.danger or r.danger.score < cap then out[#out + 1] = r end
    end
    return out
end

function Risk:Init()
    ns:On("PLAYER_DEAD", function() Risk:RecordDeath() end)
    local learn = function() ns.After(2, function() Risk:LearnRuleset() end) end
    ns:On("ZONE_CHANGED_NEW_AREA", learn)
    ns:On("PLAYER_ENTERING_WORLD", learn)
    ns:On("UNIT_FLAGS", function(_, unit) if unit == "player" then learn() end end)
end
