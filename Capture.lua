-- Capture: records every gather, skin, pick pocket and creature loot with zone + coordinates, and
-- measures what the estimates need: fights and downtime, travel speed, repairs, and farm sessions
-- (active time only: the clock pauses while you are AFK or idle). Every value is checked with issecretvalue.
local _, ns = ...
local Capture = {}
ns.Capture = Capture
local DS = ns.DS
local Safe = ns.Safe

local spellKind = {}     -- [spellID] = kind
local nameKind = {}      -- [localized spell name] = kind
local pending            -- { kind, time, target }
local lootDone           -- guard: one record per loot window
local seenCorpse = {}    -- [guid] = true (this session) so a corpse counts once
local castStart          -- { kind, time } of the gather cast in progress (for measured cast times)
local lootTimer          -- { kind, time } of the open gather loot window
local TIMED = { herb = true, ore = true, skin = true, mob = true }
local session = { start = nil, active = 0, value = 0, items = {}, gathers = 0, kills = 0, money = 0 }
Capture.session = session
local IDLE = 180          -- seconds without moving, looting, casting or fighting = idle
local lastActivity = 0
local fight, lastFight    -- { start, stop, kills, down } current / previous fight
local fightEnd            -- GetTime() the previous fight ended (downtime is measured from here)
local repairStart         -- repair cost when a merchant opened
local corpseCount = 0
local corpsesThisLoot = {}  -- npcIDs of the corpses in the open loot window (coin is shared between them)

function Capture:Activity() lastActivity = GetTime() end

local function buildSpellTables()
    for kind, ids in pairs(ns.GatherSpells) do
        for _, id in ipairs(ids) do
            spellKind[id] = kind
            local name = C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(id)
            if not name and GetSpellInfo then name = GetSpellInfo(id) end
            if name then nameKind[name] = kind end
        end
    end
end

local function kindForSpell(spellID)
    spellID = Safe(spellID)
    if not spellID then return nil end
    local k = spellKind[spellID]
    if k then return k end
    local name = C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(spellID)
    name = Safe(name)
    if name and nameKind[name] then
        spellKind[spellID] = nameKind[name] -- remember Forever's own spell ID
        return nameKind[name]
    end
end
Capture.KindForSpell = kindForSpell

function Capture:Init()
    buildSpellTables()
    ns:On("UNIT_SPELLCAST_START", function(_, unit, _, spellID)
        if unit ~= "player" then return end
        local kind = kindForSpell(spellID)
        castStart = kind and TIMED[kind] and { kind = kind, time = GetTime() } or nil
        if kind then
            lastActivity = GetTime()
            if kind ~= "skin" then fightEnd = nil end -- gathering between fights is not downtime
        end
    end)
    ns:On("UNIT_SPELLCAST_SUCCEEDED", function(_, unit, _, spellID)
        if unit ~= "player" then return end
        local kind = kindForSpell(spellID)
        if kind then pending = { kind = kind, time = GetTime() } end
        if kind and castStart and castStart.kind == kind then ns.Learn:AddCast(kind, GetTime() - castStart.time) end
        castStart = nil
    end)
    ns:On("UNIT_SPELLCAST_INTERRUPTED", function(_, unit) if unit == "player" then castStart = nil end end)
    ns:On("UNIT_SPELLCAST_FAILED", function(_, unit) if unit == "player" then castStart = nil end end)
    ns:On("UNIT_SPELLCAST_CHANNEL_START", function(_, unit, _, spellID)
        if unit ~= "player" then return end
        local kind = kindForSpell(spellID)
        if kind == "fish" then pending = { kind = kind, time = GetTime() + 30 } end
    end)
    ns:On("LOOT_READY", function() Capture:OnLoot() end)
    ns:On("LOOT_OPENED", function() Capture:OnLoot() end)
    ns:On("LOOT_CLOSED", function()
        lootDone = nil
        if lootTimer then ns.Learn:AddLootTime(lootTimer.kind, GetTime() - lootTimer.time) lootTimer = nil end
    end)
    ns:On("PLAYER_MONEY", function()
        local m = GetMoney()
        if Capture.lastMoney and m > Capture.lastMoney and Capture.lootOpenAt and GetTime() - Capture.lootOpenAt < 5 then
            local gain = m - Capture.lastMoney
            Capture:AddValue(gain, nil, 0)
            session.money = session.money + gain
            ns.db.stats.gold = (ns.db.stats.gold or 0) + gain
            -- coin per mob: shared between the corpses of this loot window
            if #corpsesThisLoot > 0 then
                local each = gain / #corpsesThisLoot
                for _, npc in ipairs(corpsesThisLoot) do
                    local rec = ns.db.mobs[npc]
                    if rec then rec.c = (rec.c or 0) + each end
                end
                wipe(corpsesThisLoot)
            end
        end
        Capture.lastMoney = m
    end)
    Capture.lastMoney = GetMoney()
    -- fights: seconds in combat per kill, and the downtime before each fight
    ns:On("PLAYER_REGEN_DISABLED", function() Capture:FightStart() end)
    ns:On("PLAYER_REGEN_ENABLED", function() Capture:FightEnd() end)
    ns:On("PLAYER_DEAD", function() fight, fightEnd = nil, nil end)
    -- repairs: cost before and after a merchant visit
    ns:On("MERCHANT_SHOW", function() repairStart = Capture.RepairCost() end)
    ns:On("UPDATE_INVENTORY_DURABILITY", function() Capture:CheckRepair() end)
    ns:On("MERCHANT_CLOSED", function() Capture:CheckRepair() repairStart = nil end)
    ns:On("PLAYER_FLAGS_CHANGED", function() ns:Fire("FORAGER_SESSION_UPDATE") end)
    ns.Ticker(2, function()
        local ok, err = pcall(Capture.Tick, Capture)
        if not ok then ns:Error("capture tick", err) end
    end)
end

-------------------------------------------------------------------------------
-- fights, speed, idle clock, repairs
-------------------------------------------------------------------------------
function Capture:FightStart()
    local now = GetTime()
    lastActivity = now
    local down = fightEnd and (now - fightEnd) or nil
    fight = { start = now, kills = 0, down = down }
end

function Capture:FightEnd()
    local now = GetTime()
    lastActivity = now
    if not fight then return end
    fight.stop = now
    local f = fight
    fight, lastFight = nil, f
    fightEnd = now
    -- loot comes after combat: book the fight once its corpses have had time to be looted
    ns.After(30, function()
        if f.kills > 0 then ns.Learn:AddFight(f.stop - f.start, f.kills, f.down) end
    end)
end

--- A corpse was looted: it belongs to the fight in progress or the one that just ended.
function Capture:CountKill()
    local f = fight or (lastFight and lastFight.stop and GetTime() - lastFight.stop < 30 and lastFight)
    if f then f.kills = f.kills + 1 end
end

--- Total repair cost of your gear now (copper), or nil.
function Capture.RepairCost()
    if not GetRepairAllCost then return nil end
    local ok, cost = pcall(GetRepairAllCost)
    cost = ok and Safe(cost) or nil
    return type(cost) == "number" and cost or nil
end

function Capture:CheckRepair()
    if not repairStart then return end
    local now = Capture.RepairCost()
    if now and now < repairStart then
        local spent = repairStart - now
        local stats = ns.db.stats
        local kills = (stats.kills or 0) - (stats.repairMark or 0)
        stats.repairMark = stats.kills or 0
        ns.Learn:AddRepair(spent, kills)
        repairStart = now
    end
end

--- Every 2 s: active-time clock (pauses when AFK/idle) and a travel speed sample.
function Capture:Tick()
    local now = GetTime()
    local inCombat = InCombatLockdown()
    if not inCombat and GetUnitSpeed and not (UnitOnTaxi and UnitOnTaxi("player")) and not (UnitIsDeadOrGhost and UnitIsDeadOrGhost("player")) then
        local ok, cur = pcall(GetUnitSpeed, "player")
        cur = ok and Safe(cur) or nil
        if type(cur) == "number" and cur > 0 then
            lastActivity = now
            if not (IsSwimming and IsSwimming()) then ns.Learn:AddSpeed(IsMounted and IsMounted() and true or false, cur) end
        end
    elseif inCombat then
        lastActivity = now
    end
    if session.start then
        local dt = now - (session.tick or now)
        session.tick = now
        local afk = UnitIsAFK and Safe(UnitIsAFK("player"))
        local idle = ns.settings.afkPause ~= false and (afk or now - lastActivity > IDLE)
        if dt > 0 and dt < 10 and not idle then session.active = session.active + dt end
        session.paused = idle or nil
    end
end

-------------------------------------------------------------------------------
-- helpers
-------------------------------------------------------------------------------
local function slotItem(slot)
    local link = Safe(GetLootSlotLink(slot))
    if not link then return nil end
    local itemID = tonumber(link:match("item:(%d+)"))
    local _, _, qty = GetLootSlotInfo(slot)
    qty = Safe(qty) or 1
    return itemID, qty, link
end

local function slotSources(slot)
    local out = {}
    local t = { pcall(GetLootSourceInfo, slot) }
    if not t[1] then return out end
    for i = 2, #t, 2 do
        local guid = Safe(t[i])
        if type(guid) == "string" then out[#out + 1] = guid end
    end
    return out
end

local function isGear(itemID)
    if not (C_Item and C_Item.GetItemInfoInstant) then return false end
    local _, _, _, _, _, classID = C_Item.GetItemInfoInstant(itemID)
    return classID == 2 or classID == 4
end
Capture.IsGear = isGear

function Capture:AddValue(copper, itemID, qty)
    if not session.start then session.start, session.tick = time(), GetTime() end
    session.value = session.value + (copper or 0)
    if itemID then session.items[itemID] = (session.items[itemID] or 0) + (qty or 1) end
    ns:Fire("FORAGER_SESSION_UPDATE")
end

local function stat(itemID, qty)
    local s = ns.db.stats.items
    s[itemID] = (s[itemID] or 0) + qty
    local price = ns.Prices:Get(itemID)
    Capture:AddValue(price * qty, itemID, qty)
end

local function zoneStat(uiMap, field)
    if not uiMap then return end
    local z = ns.db.stats.zones[uiMap] or {}
    ns.db.stats.zones[uiMap] = z
    z[field] = (z[field] or 0) + 1
end

-------------------------------------------------------------------------------
-- node recording
-------------------------------------------------------------------------------
--- Record a gathered node at x,y (0-1) on uiMap. Merges with a learned node of the same type within 15 yd.
--- Returns key, record and whether this loot starts a new visit (veins can be looted several times).
function Capture:RecordNode(uiMap, x, y, typeKey, items, source)
    local zone = ns.db.nodes[uiMap]
    if not zone then zone = {} ns.db.nodes[uiMap] = zone end
    local best, bestD
    for key, rec in pairs(zone) do
        if rec.t == typeKey then
            local nx, ny = ns.DecodeXY(key, 1)
            local d = ns.Player:Distance(uiMap, x, y, nx, ny)
            if d < 15 and (not bestD or d < bestD) then best, bestD = key, d end
        end
    end
    local rec
    local newVisit = true
    if best then
        rec = zone[best]
        newVisit = not rec.l or (time() - rec.l) > ns.Learn.VISIT_GAP
        if newVisit and rec.l and (source or "me") == "me" then ns.Learn:AddReturn(typeKey, time() - rec.l) end
    else
        rec = { t = typeKey, c = 0, y = {}, s = source or "me" }
        zone[ns.EncodeXY(x, y)] = rec
    end
    rec.c = (rec.c or 0) + 1
    if newVisit then rec.v = (rec.v or 0) + 1 end
    rec.l = time()
    if items then
        rec.y = rec.y or {}
        for id, q in pairs(items) do rec.y[id] = (rec.y[id] or 0) + q end
    end
    DS:Invalidate(uiMap)
    ns:Fire("FORAGER_NODES_CHANGED", uiMap)
    return best or ns.EncodeXY(x, y), rec, newVisit
end

local function resolveNodeType(kind, sources, items, firstItem)
    for _, guid in ipairs(sources) do
        local id, gkind = ns.IDFromGUID(guid)
        if gkind == "GameObject" then
            local t = DS:TypeForObject(id)
            if t then return t, id end
        end
    end
    -- fall back to the main gathered item
    local primary = firstItem
    for id in pairs(items) do
        local t = DS:TypeForItem(id)
        if t and ns.NodeTypes[t].kind == kind then return t end
    end
    if primary then
        local key = "i" .. primary
        if not ns.db.names[key] then
            ns.db.names[key] = DS:ItemName(primary)
            ns.db.names[key .. ":k"] = kind
        end
        return key
    end
end

-------------------------------------------------------------------------------
-- loot handler
-------------------------------------------------------------------------------
function Capture:OnLoot()
    if lootDone then return end
    lootDone = true
    lastActivity = GetTime()
    Capture.lootOpenAt = GetTime()
    local n = Safe(GetNumLootItems()) or 0
    if n == 0 then return end
    local now = GetTime()
    local kind = pending and (now - pending.time) < 8 and pending.kind or nil
    pending = nil

    local uiMap = ns.Player:MapID()
    local x, y = ns.Player:Position(uiMap)

    if kind and TIMED[kind] then lootTimer = { kind = kind, time = now } end

    -- gather: herb / ore / fish
    if kind == "herb" or kind == "ore" or kind == "fish" then
        local items, first, sources = {}, nil, {}
        for slot = 1, n do
            local itemID, qty = slotItem(slot)
            if itemID then
                items[itemID] = (items[itemID] or 0) + qty
                first = first or itemID
                stat(itemID, qty)
                for _, g in ipairs(slotSources(slot)) do sources[#sources + 1] = g end
            end
        end
        if not first then return end
        local typeKey = resolveNodeType(kind, sources, items, first)
        local isPool = typeKey and type(typeKey) == "number" and ns.NodeTypes[typeKey].kind == "fish"
        ns.db.stats.gathers[typeKey or "?"] = (ns.db.stats.gathers[typeKey or "?"] or 0) + 1
        session.gathers = session.gathers + 1
        zoneStat(uiMap, "g")
        if kind == "fish" and not isPool then
            -- open-water catch: keep zone catch stats instead of a node
            if uiMap then
                local f = ns.db.fish[uiMap] or { casts = 0, items = {} }
                ns.db.fish[uiMap] = f
                f.casts = f.casts + 1
                for id, q in pairs(items) do f.items[id] = (f.items[id] or 0) + q end
            end
            return
        end
        if uiMap and x and typeKey then
            local key, _, newVisit = Capture:RecordNode(uiMap, x, y, typeKey, items, "me")
            ns.Learn:AddNode(typeKey, items, newVisit)
            ns:Fire("FORAGER_NODE_GATHERED", uiMap, x, y, typeKey)
            if ns.Comms then ns.Comms:Share(typeKey, uiMap, key) end
            ns:CountGatherForReminder()
        end
        return
    end

    -- skinning / pick pocket: attribute to the creature
    if kind == "skin" or kind == "pick" then
        local npcID
        local items = {}
        for slot = 1, n do
            local itemID, qty = slotItem(slot)
            if itemID then
                items[itemID] = (items[itemID] or 0) + qty
                stat(itemID, qty)
            end
            for _, g in ipairs(slotSources(slot)) do
                local id, gk = ns.IDFromGUID(g)
                if gk == "Creature" then npcID = id end
            end
        end
        if npcID then
            local m = ns.db.mobs[npcID] or {}
            ns.db.mobs[npcID] = m
            if kind == "skin" then
                m.s = (m.s or 0) + 1
                m.si = m.si or {}
                m.sq = m.sq or {}
                m.ss = (m.ss or 0) + 1 -- skins counted with quantities (1.7+)
                for id, q in pairs(items) do
                    m.si[id] = (m.si[id] or 0) + 1
                    m.sq[id] = (m.sq[id] or 0) + q
                end
                ns.db.stats.skins = (ns.db.stats.skins or 0) + 1
                ns.Learn:AddSkin(DS:GetMob(npcID), items)
            else
                m.p = (m.p or 0) + 1
                m.pi = m.pi or {}
                for id in pairs(items) do m.pi[id] = (m.pi[id] or 0) + 1 end
            end
        end
        return
    end

    -- creature loot (possibly several corpses with area loot)
    lootTimer = { kind = "mob", time = now }
    wipe(corpsesThisLoot)
    local perCorpse = {}
    for slot = 1, n do
        local itemID, qty = slotItem(slot)
        local sources = slotSources(slot)
        for _, g in ipairs(sources) do
            local id, gk = ns.IDFromGUID(g)
            if gk == "Creature" or gk == "Vehicle" then
                local c = perCorpse[g]
                if not c then c = { npc = id, items = {} } perCorpse[g] = c end
                if itemID then c.items[itemID] = (c.items[itemID] or 0) + qty end
            end
        end
        if itemID and #sources <= 1 then stat(itemID, qty) end
    end
    for guid, c in pairs(perCorpse) do
        if not seenCorpse[guid] and c.npc then
            seenCorpse[guid] = true
            corpseCount = corpseCount + 1
            if corpseCount > 400 then wipe(seenCorpse) corpseCount = 0 seenCorpse[guid] = true end
            Capture:CountKill()
            local m = ns.db.mobs[c.npc] or {}
            ns.db.mobs[c.npc] = m
            m.k = (m.k or 0) + 1
            m.n, m.cn = (m.n or 0) + 1, (m.cn or 0) + 1 -- corpses with quantities / coin recorded (2.1+)
            m.i = m.i or {}
            m.iq = m.iq or {}
            m.q = m.q or {}
            corpsesThisLoot[#corpsesThisLoot + 1] = c.npc
            local gotQ = {}
            for id, qty in pairs(c.items) do
                m.iq[id] = (m.iq[id] or 0) + qty
                m.i[id] = (m.i[id] or 0) + 1
                if isGear(id) then
                    local q = DS:ItemQuality(id)
                    if q and q >= 2 and q <= 4 then gotQ[q] = true end
                end
            end
            for q in pairs(gotQ) do m.q[q] = (m.q[q] or 0) + 1 end
            ns.db.stats.kills = (ns.db.stats.kills or 0) + 1
            session.kills = session.kills + 1
            zoneStat(uiMap, "k")
        end
    end
end

-------------------------------------------------------------------------------
-- session
-------------------------------------------------------------------------------
--- Copper per hour of active time, and the active seconds.
function Capture:SessionPerHour()
    if not session.start then return 0, 0 end
    local secs = math.max(60, session.active)
    return session.value * 3600 / secs, session.active
end

function Capture:ResetSession()
    Capture:FinishFarm()
    ns:SaveSession()
    session.start, session.active, session.tick, session.paused = nil, 0, nil, nil
    session.value, session.gathers, session.kills, session.money = 0, 0, 0, 0
    session.farm, session.group, session.est, session.label = nil, nil, nil, nil
    wipe(session.items)
    ns:Fire("FORAGER_SESSION_UPDATE")
end

--- Farming a spot starts a fresh session tied to it, so it can be compared with the estimate.
function Capture:BeginFarm(r)
    if not r then return end
    local key = ns.Learn.FarmKey(r)
    if session.farm == key then return end
    Capture:ResetSession()
    session.farm, session.group, session.est = key, ns.Learn.FarmGroup(r), r.estGross
    session.label = (r.areaName and (r.areaName .. ", ") or "") .. (r.zoneName or "")
    session.start, session.tick = time(), GetTime()
    lastActivity = GetTime()
    ns:Fire("FORAGER_SESSION_UPDATE")
end

--- Book the farm session for calibration (needs 10 minutes of active farming).
function Capture:FinishFarm()
    if not session.farm or not session.est or session.est <= 0 then return end
    if ns.settings.calibrate ~= false and session.active >= 600 then
        local perHour = Capture:SessionPerHour()
        ns.Learn:AddFarm(session.farm, session.group, session.est, perHour, session.active / 3600)
    end
    session.farm = nil
end

function ns:SaveSession()
    if not session.start or not ns.db then return end
    local perHour, secs = Capture:SessionPerHour()
    if secs < 60 and session.value == 0 then return end
    table.insert(ns.db.sessions, 1, {
        start = session.start, secs = secs, value = session.value, perHour = perHour,
        gathers = session.gathers, kills = session.kills, char = ns.CharKey(), zone = ns.Player:MapID(),
        est = session.est, spot = session.label,
    })
    while #ns.db.sessions > 30 do table.remove(ns.db.sessions) end
end
