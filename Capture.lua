-- Capture: records every gather, skin, pick pocket and creature loot with zone + coordinates.
-- Out-of-combat events only matter here; every value is checked with issecretvalue.
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
local session = { start = nil, value = 0, items = {}, gathers = 0, kills = 0, money = 0 }
Capture.session = session

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
    ns:On("UNIT_SPELLCAST_SUCCEEDED", function(_, unit, _, spellID)
        if unit ~= "player" then return end
        local kind = kindForSpell(spellID)
        if kind then pending = { kind = kind, time = GetTime() } end
    end)
    ns:On("UNIT_SPELLCAST_CHANNEL_START", function(_, unit, _, spellID)
        if unit ~= "player" then return end
        local kind = kindForSpell(spellID)
        if kind == "fish" then pending = { kind = kind, time = GetTime() + 30 } end
    end)
    ns:On("LOOT_READY", function() Capture:OnLoot() end)
    ns:On("LOOT_OPENED", function() Capture:OnLoot() end)
    ns:On("LOOT_CLOSED", function() lootDone = nil end)
    ns:On("PLAYER_MONEY", function()
        local m = GetMoney()
        if Capture.lastMoney and m > Capture.lastMoney and Capture.lootOpenAt and GetTime() - Capture.lootOpenAt < 5 then
            Capture:AddValue(m - Capture.lastMoney, nil, 0)
            session.money = session.money + (m - Capture.lastMoney)
            ns.db.stats.gold = (ns.db.stats.gold or 0) + (m - Capture.lastMoney)
        end
        Capture.lastMoney = m
    end)
    Capture.lastMoney = GetMoney()
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

function Capture:AddValue(copper, itemID, qty)
    if not session.start then session.start = time() end
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
    if best then
        rec = zone[best]
    else
        rec = { t = typeKey, c = 0, y = {}, s = source or "me" }
        zone[ns.EncodeXY(x, y)] = rec
    end
    rec.c = (rec.c or 0) + 1
    rec.l = time()
    if items then
        rec.y = rec.y or {}
        for id, q in pairs(items) do rec.y[id] = (rec.y[id] or 0) + q end
    end
    DS:Invalidate(uiMap)
    ns:Fire("FORAGER_NODES_CHANGED", uiMap)
    return best or ns.EncodeXY(x, y), rec
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
    Capture.lootOpenAt = GetTime()
    local n = Safe(GetNumLootItems()) or 0
    if n == 0 then return end
    local now = GetTime()
    local kind = pending and (now - pending.time) < 8 and pending.kind or nil
    pending = nil

    local uiMap = ns.Player:MapID()
    local x, y = ns.Player:Position(uiMap)

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
            local key = Capture:RecordNode(uiMap, x, y, typeKey, items, "me")
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
                for id, q in pairs(items) do m.si[id] = (m.si[id] or 0) + 1 end
                ns.db.stats.skins = (ns.db.stats.skins or 0) + 1
            else
                m.p = (m.p or 0) + 1
                m.pi = m.pi or {}
                for id in pairs(items) do m.pi[id] = (m.pi[id] or 0) + 1 end
            end
        end
        return
    end

    -- creature loot (possibly several corpses with area loot)
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
            local m = ns.db.mobs[c.npc] or {}
            ns.db.mobs[c.npc] = m
            m.k = (m.k or 0) + 1
            m.i = m.i or {}
            m.q = m.q or {}
            local gotQ = {}
            for id in pairs(c.items) do
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
function Capture:SessionPerHour()
    if not session.start then return 0, 0 end
    local secs = math.max(60, time() - session.start)
    return session.value * 3600 / secs, secs
end

function Capture:ResetSession()
    ns:SaveSession()
    session.start, session.value, session.gathers, session.kills, session.money = nil, 0, 0, 0, 0
    wipe(session.items)
    ns:Fire("FORAGER_SESSION_UPDATE")
end

function ns:SaveSession()
    if not session.start or not ns.db then return end
    local perHour, secs = Capture:SessionPerHour()
    table.insert(ns.db.sessions, 1, {
        start = session.start, secs = secs, value = session.value, perHour = perHour,
        gathers = session.gathers, kills = session.kills, char = ns.CharKey(), zone = ns.Player:MapID(),
    })
    while #ns.db.sessions > 30 do table.remove(ns.db.sessions) end
end
