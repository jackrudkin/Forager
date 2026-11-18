-- Learn: turns your own play into the numbers the finders use.
-- Your data is blended with the Classic / Forever estimates instead of replacing them at a fixed
-- count: with n of your samples and the estimate weight k (setting "minSamples"),
--   value = (n x yours + k x estimate) / (n + k)
-- so your data counts for half at n = k and takes over smoothly after that.
--   * node yields per visit and gathers per node (Mining veins take several)
--   * cast and loot seconds per profession once 10 casts are measured
--   * Scarce find rates pooled per Scarce item, normalised by your Bountiful Harvest rank
--     (Legacy perk: +20% Scarce from Mining, Herbalism and Skinning per rank, 5 ranks)
--   * herb seed rates pooled over the herbs that are known to give them
--   * seconds per kill and downtime between fights (kills per hour), travel speed on foot and mounted
--   * repair cost per kill, and how your farm sessions compared with the estimate (calibration)
-- Static fallbacks: Classic loot tables (CMaNGOS), Classic cast times (classicdb), and the Forever
-- sources listed in Data/Static.lua.
local _, ns = ...
local Learn = {}
ns.Learn = Learn

Learn.TIME_MIN = 10      -- measured casts before your own cast time is used
Learn.SCARCE_MIN = 100   -- gathers/skins before a pooled Scarce or seed rate is used
Learn.VISIT_GAP = 90     -- seconds: loots on the same node closer than this are one visit
Learn.SPEED_MIN = 30     -- speed samples (2 s apart) before your measured speed is used
Learn.FIGHT_GAP = 90     -- seconds between fights that still count as downtime between kills
Learn.CALIB_MAX = 120    -- farm calibration entries kept

local infoCache, cacheKey = {}, nil

local function store()
    local d = ns.db.learn
    if type(d) ~= "table" then d = {} ns.db.learn = d end
    d.nodes = d.nodes or {}
    d.cast = d.cast or {}
    d.loot = d.loot or {}
    d.scarceSkin = d.scarceSkin or {}
    d.bh = d.bh or {}
    d.fight = d.fight or { n = 0, f = 0, dn = 0, d = 0 }
    d.speed = d.speed or {}
    d.repair = d.repair or { c = 0, k = 0 }
    d.calib = d.calib or {}
    d.back = d.back or {}
    return d
end
Learn.Store = store

local function minN() return (ns.settings and ns.settings.minSamples) or 30 end
local function extraSec() return (ns.settings and ns.settings.gatherSeconds) or 1 end

--- Blend n own samples (value own) with a prior: (n*own + k*prior)/(n+k).
function Learn.Blend(n, own, prior)
    if not n or n <= 0 or own == nil then return prior end
    if prior == nil then return own end
    local k = minN()
    return (n * own + k * prior) / (n + k)
end

--- Weight of your own data after n samples (0..1).
function Learn:OwnShare(n) return (n or 0) / ((n or 0) + minN()) end

--- Label for blended numbers: "my data n=40", "blend n=12", "estimate".
function Learn:SourceLabel(n, est)
    n = n or 0
    if n >= minN() then return "my data n=" .. math.floor(n) end
    if n > 0 then return "blend n=" .. math.floor(n) end
    return est or "estimate"
end

--- Blend a prior list {{id, p}} with own counts {[id]=c} over total samples. Returns sorted list, n.
--- No prior: your counts as they are.
function Learn:BlendList(prior, counts, total)
    total = total or 0
    local out = {}
    if total <= 0 or not counts then
        for i, e in ipairs(prior or {}) do out[i] = { e[1], e[2] } end
        return out, 0
    end
    if not prior or #prior == 0 then
        for id, c in pairs(counts) do out[#out + 1] = { id, c / total } end
    else
        local w = Learn:OwnShare(total)
        local m = {}
        for _, e in ipairs(prior) do m[e[1]] = (m[e[1]] or 0) + (1 - w) * e[2] end
        for id, c in pairs(counts) do m[id] = (m[id] or 0) + w * c / total end
        for id, p in pairs(m) do out[#out + 1] = { id, p } end
    end
    table.sort(out, function(a, b) return a[2] > b[2] end)
    return out, total
end

function Learn:Changed()
    wipe(infoCache)
    if ns.DS and ns.DS.InvalidateMobs then ns.DS:InvalidateMobs() end
    ns.gen = (ns.gen or 0) + 1
end

local function addAvg(t, kind, secs, cap)
    local r = t[kind] or { n = 0, s = 0 }
    t[kind] = r
    r.n, r.s = r.n + 1, r.s + secs
    if r.n > (cap or 200) then r.n, r.s = r.n / 2, r.s / 2 end -- keep the average recent
end

-------------------------------------------------------------------------------
-- Bountiful Harvest
-------------------------------------------------------------------------------
--- Scarce multiplier for a Bountiful Harvest rank (default: the setting).
function Learn.HarvestMult(rank)
    rank = rank or (ns.settings and ns.settings.harvestRank) or 0
    return 1 + 0.2 * ns.Clamp(math.floor(rank), 0, 5)
end

local function bhEntry(scarceID)
    local d = store()
    local e = d.bh[scarceID]
    if e then return e end
    -- first use: seed from what was recorded before (rank at that time unknown: the current setting)
    e = { g = 0, f = 0 }
    for key, r in pairs(d.nodes) do
        local t = type(key) == "number" and ns.NodeTypes[key]
        if t and ns.ScarceForNode[t.name] == scarceID then
            e.g = e.g + (r.n or 0)
            e.f = e.f + (r.y and r.y[scarceID] or 0)
        end
    end
    e.m = e.g * Learn.HarvestMult()
    e.seed = e.g
    d.bh[scarceID] = e
    return e
end

--- The rank setting changed: data seeded at the old rank with nothing recorded since is re-scaled.
function Learn:SetHarvestRank(rank)
    local mult = Learn.HarvestMult(rank)
    local d = store()
    for _, e in pairs(d.bh) do if e.seed and e.g == e.seed then e.m = e.g * mult end end
    for _, r in pairs(d.scarceSkin) do if r.seed and r.n == r.seed then r.m = r.n * mult end end
    Learn:Changed()
end

-------------------------------------------------------------------------------
-- casts, loot windows, nodes, skins
-------------------------------------------------------------------------------
--- A finished gather cast (UNIT_SPELLCAST_START -> SUCCEEDED) of kind herb/ore/skin.
function Learn:AddCast(kind, secs)
    if not kind or type(secs) ~= "number" or secs < 0.3 or secs > 15 then return end
    addAvg(store().cast, kind, secs)
    wipe(infoCache)
end

--- Seconds a loot window was open (LOOT_READY -> LOOT_CLOSED); kind herb/ore/skin/mob.
function Learn:AddLootTime(kind, secs)
    if not kind or type(secs) ~= "number" or secs < 0 or secs > 10 then return end
    addAvg(store().loot, kind, secs)
    wipe(infoCache)
end

--- Seconds per cast for a kind and where it comes from ("me" or "classic").
function Learn:CastSeconds(kind)
    local r = store().cast[kind]
    if r and r.n >= Learn.TIME_MIN then return r.s / r.n, "me", r.n end
    if ns.CastSeconds[kind] then return ns.CastSeconds[kind], "classic", r and r.n or 0 end
    return nil, nil, r and r.n or 0
end

function Learn:LootSeconds(kind)
    local r = store().loot[kind]
    if r and r.n >= Learn.TIME_MIN then return r.s / r.n, "me", r.n end
    return 0, nil, r and r.n or 0
end

--- One gather loot on a node. newVisit: first loot of this visit (veins can be looted several times).
function Learn:AddNode(typeKey, items, newVisit)
    if typeKey == nil then return end
    local t = type(typeKey) == "number" and ns.NodeTypes[typeKey]
    local sid = t and ns.ScarceForNode[t.name]
    local e = sid and bhEntry(sid) -- seeded from what was recorded before this loot
    local d = store().nodes
    local r = d[typeKey] or { v = 0, n = 0, y = {} }
    d[typeKey] = r
    r.n = r.n + 1
    if newVisit or r.v == 0 then r.v = r.v + 1 end
    for id, q in pairs(items or {}) do r.y[id] = (r.y[id] or 0) + q end
    if e then e.g, e.m, e.f = e.g + 1, (e.m or 0) + Learn.HarvestMult(), e.f + ((items and items[sid]) or 0) end
    wipe(infoCache)
    ns.gen = (ns.gen or 0) + 1
end

--- Shortest time a gathered spot was back (seconds), per node type: an upper bound for its respawn.
function Learn:AddReturn(typeKey, secs)
    if typeKey == nil or type(secs) ~= "number" or secs < 30 then return end
    local b = store().back
    if not b[typeKey] or secs < b[typeKey] then b[typeKey] = math.floor(secs) end
end

--- Seconds a gathered spot of this type stays empty: spawn data, capped by what you have seen.
function Learn:Respawn(t)
    if not t then return 300 end
    local r = (ns.settings.spawnData ~= false and t.respawn) or 300
    local seen = store().back[t.id]
    if seen and seen < r then r = seen end
    return r
end

--- One skin of mob m (decoded bundled mob or nil) with the items it gave.
function Learn:AddSkin(m, items)
    if not m then return end
    local d = store().scarceSkin
    for _, sd in ipairs(ns.ScarceSkin) do
        if Learn.InScarceBand(m, sd) then
            local r = d[sd.id]
            if not r then r = { n = 0, c = 0, m = 0, seed = 0 } d[sd.id] = r end
            r.m = (r.m or r.n * Learn.HarvestMult()) + Learn.HarvestMult()
            r.n = r.n + 1
            r.c = r.c + ((items and items[sd.id]) or 0)
        end
    end
    Learn:Changed()
end

function Learn.InScarceBand(m, sd)
    return m.ctype == sd.ctype and (m.minLevel or 0) <= sd.maxLevel and (m.maxLevel or 0) >= sd.minLevel
end

--- Pooled Scarce rate per gather at your current Bountiful Harvest rank: rate, gathers.
function Learn:ScarceNodeRate(scarceID)
    local e = bhEntry(scarceID)
    if e.g <= 0 or (e.m or 0) <= 0 then return 0, e.g end
    return e.f / e.m * Learn.HarvestMult(), e.g
end

--- Pooled rate of a bonus item (herb seeds) per gather over the named node types: rate, gathers.
function Learn:BonusNodeRate(itemID, names)
    local loots, found = 0, 0
    for key, r in pairs(store().nodes) do
        local t = type(key) == "number" and ns.NodeTypes[key]
        if t and names[t.name] then
            loots = loots + (r.n or 0)
            found = found + (r.y and r.y[itemID] or 0)
        end
    end
    return loots > 0 and found / loots or 0, loots
end

--- Per-gather rates of the bonus items a node type can give (Scarce, seeds), once pooled data is in.
local function bonusRates(t, info)
    local out = {}
    if info.scarce then
        local rate, n = Learn:ScarceNodeRate(info.scarce)
        info.scarceN = n
        if n >= Learn.SCARCE_MIN then out[info.scarce] = rate info.scarceRate = rate end
    end
    for _, sd in ipairs(ns.HerbSeeds or {}) do
        if sd.from and sd.from[t.name] then
            local rate, n = Learn:BonusNodeRate(sd.id, sd.from)
            if n >= Learn.SCARCE_MIN then out[sd.id] = rate end
        end
    end
    return out
end

--- Effective numbers for a node type:
--- { perNode = {{itemID, qty per node}}, taps, secs (per node), learned, n, src, scarce, scarceRate, scarceN }
function Learn:NodeInfo(t)
    local key = minN() .. ":" .. extraSec() .. ":" .. Learn.HarvestMult()
    if key ~= cacheKey then wipe(infoCache) cacheKey = key end
    local c = infoCache[t.id or t.name]
    if c then return c end
    local r = t.id ~= nil and store().nodes[t.id] or nil
    local n = r and r.v or 0
    local info = { perNode = {}, scarce = ns.ScarceForNode[t.name], n = n }
    -- estimate: Classic yields per gather x Classic gathers per node
    local priorTaps = t.taps or 1
    local prior = {}
    if t.yields and #t.yields > 0 then
        for _, y in ipairs(t.yields) do prior[y[1]] = (prior[y[1]] or 0) + y[2] end
    elseif t.item and t.item > 0 then
        prior[t.item] = 1.5
    end
    local w = Learn:OwnShare(n)
    info.taps = (n > 0) and (w * (r.n / r.v) + (1 - w) * priorTaps) or priorTaps
    info.learned = n >= minN()
    info.src = Learn:SourceLabel(n, "Classic est.")
    -- bonus items (Scarce, seeds): pooled rate per gather x gathers per node, the same for estimate and you
    local bonus = bonusRates(t, info)
    local qty = {}
    for id, q in pairs(prior) do if not bonus[id] then qty[id] = (1 - w) * q * priorTaps end end
    if n > 0 then
        for id, q in pairs(r.y) do if not bonus[id] then qty[id] = (qty[id] or 0) + w * q / r.v end end
        if info.scarce and not info.scarceRate and info.learned then info.scarceRate = (r.y[info.scarce] or 0) / math.max(1, r.n) end
    end
    for id, rate in pairs(bonus) do qty[id] = rate * info.taps end
    for id, q in pairs(qty) do if q > 0 then info.perNode[#info.perNode + 1] = { id, q } end end
    table.sort(info.perNode, function(a, b) return a[2] > b[2] end)
    local cast = Learn:CastSeconds(t.kind) or extraSec()
    info.secs = info.taps * (cast + (Learn:LootSeconds(t.kind))) + extraSec()
    infoCache[t.id or t.name] = info
    return info
end

--- Expected count of an item per node of a type.
function Learn:NodeQty(t, itemID)
    for _, y in ipairs(Learn:NodeInfo(t).perNode) do if y[1] == itemID then return y[2] end end
    return 0
end

--- Skin Scarce rate for a band entry at your Bountiful Harvest rank (estimate scaled as rank 0).
function Learn:SkinScarceRate(sd)
    local r = store().scarceSkin[sd.id]
    local mult = Learn.HarvestMult()
    local est = sd.rate * mult
    if not r or r.n <= 0 then return est, 0 end
    local m = (r.m and r.m > 0) and r.m or r.n
    if r.n >= Learn.SCARCE_MIN then return r.c / m * mult, r.n end
    return est, r.n
end

--- Effective skin list for a decoded mob: your skins blended with the Classic list plus Forever
--- Scarce (Pristine Leather) where a source gives a level band. Returns list, label, mostly-yours.
function Learn:SkinList(m)
    local base = {}
    for i, e in ipairs(m.skinBase or {}) do base[i] = e end
    if m.skinnable then
        for _, sd in ipairs(ns.ScarceSkin) do
            if Learn.InScarceBand(m, sd) then base[#base + 1] = { sd.id, (Learn:SkinScarceRate(sd)) } end
        end
    end
    local own = ns.db and ns.db.mobs and ns.db.mobs[m.id]
    local counts, n = nil, 0
    if own and (own.ss or 0) > 0 then counts, n = own.sq or {}, own.ss -- with quantities (1.7+)
    elseif own and (own.s or 0) > 0 then counts, n = own.si or {}, own.s end
    if n <= 0 then return base, "estimate", false end
    local out = Learn:BlendList(base, counts, n)
    return out, Learn:SourceLabel(n), n >= minN()
end

--- Blend your creature loot into a decoded mob: drops (quantities from 2.1, else per corpse), coin and
--- gear grades. Mobs without a bundled loot table (Forever's new NPCs) use your loot as it is.
function Learn:MobLoot(m)
    local own = ns.db and ns.db.mobs and ns.db.mobs[m.id]
    if not own or (own.k or 0) <= 0 then return m end
    local raw, n = own.i, own.k
    if (own.n or 0) > 0 then raw, n = own.iq or {}, own.n end
    -- weapons and armour are counted through the gear grades (disenchant value), not one by one
    local counts = {}
    local isGear = ns.Capture and ns.Capture.IsGear
    for id, c in pairs(raw or {}) do if not (isGear and isGear(id)) then counts[id] = c end end
    local base = m.noLoot and nil or m.farmBase
    m.farm = (Learn:BlendList(base, counts, n))
    if (own.cn or 0) > 0 then
        local coin = (own.c or 0) / own.cn
        m.copper = m.noLoot and coin or Learn.Blend(own.cn, coin, m.copper or 0)
    end
    local q, k = own.q or {}, own.k
    if m.green and not m.noLoot then
        m.green = Learn.Blend(k, (q[2] or 0) / k, m.green)
        m.blue = Learn.Blend(k, (q[3] or 0) / k, m.blue)
        m.epic = Learn.Blend(k, (q[4] or 0) / k, m.epic)
    elseif q[2] or q[3] or q[4] then
        m.green, m.blue, m.epic = (q[2] or 0) / k, (q[3] or 0) / k, (q[4] or 0) / k
        m.greenIlvl = m.greenIlvl or m.maxLevel
    end
    if not m.skinnable and (own.s or 0) > 0 then m.skinnable = true end
    m.lootSrc = Learn:SourceLabel(n, m.noLoot and "no data yet" or "estimate")
    return m
end

-------------------------------------------------------------------------------
-- fights, kills per hour
-------------------------------------------------------------------------------
--- A finished fight: seconds in combat, kills looted from it, and the downtime before it (or nil).
function Learn:AddFight(secs, kills, downSecs)
    if type(secs) ~= "number" or type(kills) ~= "number" or kills < 1 or secs < 1 or secs > 600 then return end
    local f = store().fight
    f.n, f.f = f.n + kills, f.f + secs
    if downSecs and downSecs >= 0 and downSecs <= Learn.FIGHT_GAP then f.dn, f.d = f.dn + kills, f.d + downSecs end
    if f.n > 400 then f.n, f.f, f.dn, f.d = f.n / 2, f.f / 2, f.dn / 2, f.d / 2 end
    ns.gen = (ns.gen or 0) + 1
end

--- Seconds per kill (fight + loot) for Gather + Kill: your fights blended with the setting.
function Learn:KillSeconds()
    local f = store().fight
    local prior = (ns.settings and ns.settings.comboKillSeconds) or 30
    if f.n <= 0 then return prior, "setting", 0 end
    local own = f.f / f.n + (Learn:LootSeconds("mob"))
    return Learn.Blend(f.n, own, prior), Learn:SourceLabel(f.n, "setting"), f.n
end

--- Kills per hour (equal level) for mob farming: your fight + downtime cycle blended with the setting.
function Learn:KillsPerHour()
    local f = store().fight
    local prior = (ns.settings and ns.settings.killsPerHour) or 45
    if f.dn < 5 or f.n <= 0 then return prior, "setting", f.dn end
    local cycle = f.f / f.n + f.d / f.dn
    local own = 3600 / math.max(5, cycle)
    return Learn.Blend(f.dn, own, prior), Learn:SourceLabel(f.dn, "setting"), f.dn
end

-------------------------------------------------------------------------------
-- travel speed
-------------------------------------------------------------------------------
--- A moving-speed sample in yards/second (out of combat, not on a taxi, not swimming).
function Learn:AddSpeed(mounted, yps)
    if type(yps) ~= "number" or yps < 4 or yps > 40 then return end -- walking and odd values left out
    addAvg(store().speed, mounted and "mount" or "foot", yps, 300)
end

--- Your measured speed mounted or on foot (yd/s), or nil, and the sample count.
function Learn:Speed(mounted)
    local r = store().speed[mounted and "mount" or "foot"]
    if r and r.n >= Learn.SPEED_MIN then return r.s / r.n, r.n end
    return nil, r and r.n or 0
end

-------------------------------------------------------------------------------
-- repairs and calibration
-------------------------------------------------------------------------------
--- Copper spent on repairs and the kills since the last repair.
function Learn:AddRepair(copper, kills)
    if type(copper) ~= "number" or copper <= 0 then return end
    local r = store().repair
    r.c, r.k = r.c + copper, r.k + math.max(0, kills or 0)
    if r.k > 5000 then r.c, r.k = r.c / 2, r.k / 2 end
end

--- Repair copper per kill once 50 kills are covered, else 0; and the kill count.
function Learn:RepairPerKill()
    local r = store().repair
    if r.k >= 50 then return r.c / r.k, r.k end
    return 0, r.k
end

--- Stable key for a farm spot: zone, goal and the area centre on a 2% grid.
function Learn.FarmKey(r)
    if not r or not r.uiMap then return nil end
    local cx, cy = 0, 0
    if r.rect then cx, cy = (r.rect[1] + r.rect[3]) / 2, (r.rect[2] + r.rect[4]) / 2 end
    return string.format("%d:%s:%d:%d", r.uiMap, tostring(r.goal), math.floor(cx * 50), math.floor(cy * 50))
end

--- Group key for calibration of spots you have not farmed yet: source + goal family.
function Learn.FarmGroup(r)
    if not r then return nil end
    if r.source == "combo" then return "combo:" .. tostring(r.gather) end
    return tostring(r.source) .. ":" .. tostring(r.goal)
end

--- A farm session finished: estimated and actual copper per hour over hours of active farming.
function Learn:AddFarm(key, group, estPerHour, actualPerHour, hours)
    if not key or type(hours) ~= "number" or hours < 0.1 or not estPerHour or estPerHour <= 0 then return end
    local cal = store().calib
    for _, k in ipairs({ key, group and ("group:" .. group) or nil }) do
        local c = cal[k] or { e = 0, a = 0, h = 0 }
        c.e, c.a, c.h, c.t = c.e + estPerHour * hours, c.a + (actualPerHour or 0) * hours, c.h + hours, time()
        if c.h > 50 then c.e, c.a, c.h = c.e / 2, c.a / 2, c.h / 2 end
        cal[k] = c
    end
    -- keep the most recent entries
    local n = ns.Count(cal)
    if n > Learn.CALIB_MAX then
        local list = {}
        for k, c in pairs(cal) do list[#list + 1] = { k, c.t or 0 } end
        table.sort(list, function(a, b) return a[2] < b[2] end)
        for i = 1, n - Learn.CALIB_MAX do cal[list[i][1]] = nil end
    end
    ns.gen = (ns.gen or 0) + 1
end

--- Actual / estimated for a spot (or its group), shrunk toward 1: factor, hours, "spot"|"type"|nil.
--- A spot needs 15 minutes of farming, a group 1 hour; one hour of data counts as much as the estimate.
function Learn:Calibration(key, group)
    local cal = store().calib
    local c = key and cal[key]
    if c and c.h >= 0.25 and c.e > 0 then
        return ns.Clamp((c.a / c.e * c.h + 1) / (c.h + 1), 0.25, 3), c.h, "spot"
    end
    local g = group and cal["group:" .. group]
    if g and g.h >= 1 and g.e > 0 then
        return ns.Clamp((g.a / g.e * g.h + 1) / (g.h + 1), 0.25, 3), g.h, "type"
    end
    return 1, 0, nil
end

-------------------------------------------------------------------------------
-- migration helpers, summary
-------------------------------------------------------------------------------
--- Seed the store from data recorded before 1.7 (node yields kept per spot).
function Learn:SeedFromNodes(db)
    db.learn = db.learn or {}
    local d = db.learn
    d.nodes = d.nodes or {}
    for _, zone in pairs(db.nodes or {}) do
        for _, rec in pairs(zone) do
            if (rec.s == nil or rec.s == "me") and rec.t ~= nil and (rec.c or 0) > 0 then
                local t = type(rec.t) == "number" and ns.NodeTypes[rec.t]
                local taps = (t and t.taps) or 1
                local r = d.nodes[rec.t] or { v = 0, n = 0, y = {} }
                d.nodes[rec.t] = r
                r.n = r.n + rec.c
                r.v = r.v + math.max(1, rec.c / taps) -- old data has no visit count: Classic taps estimate
                for id, q in pairs(rec.y or {}) do r.y[id] = (r.y[id] or 0) + q end
            end
        end
    end
end

--- Short summary for /forage diag and the Settings tab.
function Learn:Summary()
    local d = store()
    local parts = {}
    for _, kind in ipairs({ "herb", "ore", "skin" }) do
        local sec, src, n = Learn:CastSeconds(kind)
        if sec then
            parts[#parts + 1] = string.format("%s %.1fs (%s)", kind, sec, src == "me" and ("you, n=" .. math.floor(n)) or "Classic")
        elseif n > 0 then
            parts[#parts + 1] = string.format("%s measuring (n=%d)", kind, n)
        end
    end
    local types, ready = 0, 0
    for _, r in pairs(d.nodes) do
        types = types + 1
        if r.v >= minN() then ready = ready + 1 end
    end
    return table.concat(parts, ", "), types, ready
end

--- Lines describing what Forager has learned from you (Settings tab, /forage diag).
function Learn:Measured()
    local lines = {}
    local kph, ksrc = Learn:KillsPerHour()
    local ks = Learn:KillSeconds()
    lines[#lines + 1] = string.format("Kills: %.0f/h, %.0f s per kill (%s)", kph, ks, ksrc)
    local foot, fn = Learn:Speed(false)
    local mount, mn = Learn:Speed(true)
    lines[#lines + 1] = string.format("Speed: on foot %s, mounted %s",
        foot and string.format("%.1f yd/s", foot) or ("measuring " .. math.floor(fn) .. "/" .. Learn.SPEED_MIN),
        mount and string.format("%.1f yd/s", mount) or ("measuring " .. math.floor(mn) .. "/" .. Learn.SPEED_MIN))
    local rpk, rk = Learn:RepairPerKill()
    lines[#lines + 1] = rk >= 50 and ("Repairs: " .. ns.Money(rpk) .. " per kill") or string.format("Repairs: measuring (%d/50 kills)", rk)
    return lines
end
