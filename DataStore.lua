-- DataStore: lazy access to bundled data (Forager_Data, load-on-demand) merged with learned data.
local _, ns = ...
local DS = {}
ns.DS = DS

local zoneNodeCache = {}   -- [uiMap] = array of nodes (bundled+learned+shared), rebuilt on change
local zoneMobCache = {}    -- [uiMap] = { [npcID] = {pts} }
local mobCache = {}        -- [npcID] = decoded mob
local objectToType = {}

for id, t in pairs(ns.NodeTypes) do
    t.id = id
    for _, o in ipairs(t.objects) do objectToType[o] = id end
end
local itemToType = {}
for id, t in pairs(ns.NodeTypes) do
    if t.item and t.item > 0 and not t.forever and not itemToType[t.item] then itemToType[t.item] = id end
end
DS.objectToType = objectToType

--- Load the bundled data addon (allowed out of combat only).
function DS:Load()
    if ForagerData and ForagerData.nodes then return true end
    if InCombatLockdown() then return false end
    if C_AddOns and C_AddOns.LoadAddOn then
        local ok, reason = C_AddOns.LoadAddOn("Forager_Data")
        if not ok then
            ns:Debug("Forager_Data not loaded:", reason)
            if not DS.warned then
                DS.warned = true
                ns:Print("Bundled data addon |cffffffffForager Data|r is missing or disabled (" .. tostring(reason) .. "). Only your own data is shown.")
            end
        end
    end
    return ForagerData and ForagerData.nodes ~= nil
end

function DS:HasBundled() return ForagerData and ForagerData.nodes ~= nil end

-------------------------------------------------------------------------------
-- node types (bundled numeric ids + learned "i<itemID>" keys for unknown Forever nodes)
-------------------------------------------------------------------------------
function DS:GetType(key)
    if type(key) == "number" then return ns.NodeTypes[key] end
    if type(key) == "string" then
        local item = tonumber(key:match("^i(%d+)$"))
        if item then
            local kind = (ns.db.names[key .. ":k"]) or "herb"
            return {
                id = key, name = ns.db.names[key] or ("Item " .. item), kind = kind,
                skill = ns.db.names[key .. ":s"] or 0, item = item, taps = 1, yields = {}, learnedType = true,
            }
        end
    end
end

function DS:TypeForObject(objectID) return objectID and objectToType[objectID] end
function DS:TypeForItem(itemID) return itemID and itemToType[itemID] end

function DS:TypeIcon(t)
    if not t then return "Interface\\Icons\\INV_Misc_QuestionMark" end
    local item = t.item
    if (not item or item == 0) and t.yields and t.yields[1] then item = t.yields[1][1] end
    if item and item > 0 and C_Item and C_Item.GetItemIconByID then
        return C_Item.GetItemIconByID(item) or "Interface\\Icons\\INV_Misc_QuestionMark"
    end
    if t.kind == "ore" then return "Interface\\Icons\\INV_Ore_Copper_01" elseif t.kind == "fish" then return "Interface\\Icons\\Trade_Fishing" end
    return "Interface\\Icons\\INV_Misc_Flower_02"
end

-------------------------------------------------------------------------------
-- zone nodes
-------------------------------------------------------------------------------
local function addPoint(list, x, y, t, src, rec, key)
    list[#list + 1] = { x = x, y = y, t = t, src = src, rec = rec, key = key }
end

function DS:Invalidate(uiMap)
    if uiMap then zoneNodeCache[uiMap] = nil else wipe(zoneNodeCache) end
end

--- All known node points in a zone. Learned points suppress bundled points of the same type within ~1%.
function DS:GetZoneNodes(uiMap)
    local cached = zoneNodeCache[uiMap]
    if cached then return cached end
    local list = {}
    local learned = ns.db.nodes[uiMap]
    local occupied = {}
    local function cell(x, y) return math.floor(x * 100) .. ":" .. math.floor(y * 100) end
    if learned then
        for key, rec in pairs(learned) do
            local x, y = ns.DecodeXY(key, 1)
            addPoint(list, x, y, rec.t, "learned", rec, key)
            occupied[cell(x, y) .. ":" .. tostring(rec.t)] = true
        end
    end
    local shared = ns.db.shared[uiMap]
    if shared then
        for key, rec in pairs(shared) do
            local x, y = ns.DecodeXY(key, 1)
            local c = cell(x, y) .. ":" .. tostring(rec.t)
            if not occupied[c] then
                addPoint(list, x, y, rec.t, "shared", rec, key)
                occupied[c] = true
            end
        end
    end
    local str = ForagerData and ForagerData.nodes and ForagerData.nodes[uiMap]
    if str then
        for part in str:gmatch("[^;]+") do
            local tid, coords = part:match("^(%d+):(.*)$")
            tid = tonumber(tid)
            for i = 1, #coords - 5, 6 do
                local x, y = ns.DecodeXY(coords, i)
                if not occupied[cell(x, y) .. ":" .. tid] then addPoint(list, x, y, tid, "bundled") end
            end
        end
    end
    zoneNodeCache[uiMap] = list
    return list
end

function DS:CountBundledNodes()
    local n = 0
    if ForagerData and ForagerData.nodes then
        for _, s in pairs(ForagerData.nodes) do
            for part in s:gmatch("[^;]+") do n = n + math.floor((#part - (part:find(":") or 0)) / 6) end
        end
    end
    return n
end

-------------------------------------------------------------------------------
-- mobs
-------------------------------------------------------------------------------
local function parseList(s)
    local out = {}
    if s and s ~= "" and s ~= "-" then
        for id, p in s:gmatch("(%d+):([%d%.]+)") do out[#out + 1] = { tonumber(id), tonumber(p) / 100 } end
    end
    return out
end

--- Decoded bundled mob record (Classic-era loot estimates) or nil.
--- Is this creature friendly to your faction (guards, villagers, vendors)? Those are never farm targets.
function DS:IsFriendly(m)
    return m and m.friendly ~= nil and m.friendly == ns.Player:Faction()
end

--- Drop decoded mobs (own skin data or Scarce rates changed).
function DS:InvalidateMobs() wipe(mobCache) end

function DS:GetMob(npcID)
    if not npcID then return nil end
    local mn = ns.settings and ns.settings.minSamples
    if mn ~= DS.mobCacheMin then wipe(mobCache) DS.mobCacheMin = mn end
    local m = mobCache[npcID]
    if m ~= nil then return m or nil end
    local s = ForagerData and ForagerData.mobs and ForagerData.mobs[npcID]
    if not s then mobCache[npcID] = false return nil end
    local f = { strsplit("|", s) }
    m = {
        id = npcID, name = f[1], minLevel = tonumber(f[2]) or 1, maxLevel = tonumber(f[3]) or 1,
        ctype = tonumber(f[4]) or 10, rank = tonumber(f[5]) or 0,
        skinnable = f[6] ~= nil and f[6] ~= "", skin = parseList(f[6]), farm = parseList(f[7]),
        pickpocket = parseList(f[9]), copper = tonumber(f[10]) or 0,
        friendly = (f[11] == "A" or f[11] == "H") and f[11] or nil,
    }
    if f[8] and f[8] ~= "" then
        local g, b, e, il = strsplit(",", f[8])
        m.green, m.blue, m.epic = (tonumber(g) or 0) / 100, (tonumber(b) or 0) / 100, (tonumber(e) or 0) / 100
        m.greenIlvl = tonumber(il) or m.maxLevel
    end
    -- skin = what the finders use: your own skins from minSamples, else Classic + Forever Scarce
    m.skinBase = m.skin
    if ns.Learn and ns.db then m.skin, m.skinSrc = ns.Learn:SkinList(m) end
    mobCache[npcID] = m
    return m
end

--- { [npcID] = {x1,y1,x2,y2,...} } for a zone (bundled spawns only).
function DS:GetZoneMobs(uiMap)
    local c = zoneMobCache[uiMap]
    if c then return c end
    c = {}
    local str = ForagerData and ForagerData.mobSpawns and ForagerData.mobSpawns[uiMap]
    if str then
        for part in str:gmatch("[^;]+") do
            local nid, coords = part:match("^(%d+):(.*)$")
            nid = tonumber(nid)
            local pts = {}
            for i = 1, #coords - 5, 6 do
                local x, y = ns.DecodeXY(coords, i)
                pts[#pts + 1] = x
                pts[#pts + 1] = y
            end
            c[nid] = pts
        end
    end
    zoneMobCache[uiMap] = c
    return c
end

--- Iterate all bundled mob IDs (for search). Returns array.
function DS:AllMobIDs()
    local out = {}
    if ForagerData and ForagerData.mobs then
        for id in pairs(ForagerData.mobs) do out[#out + 1] = id end
    end
    table.sort(out)
    return out
end

-------------------------------------------------------------------------------
-- items
-------------------------------------------------------------------------------
function DS:ItemName(itemID)
    if not itemID then return "?" end
    local name = C_Item and C_Item.GetItemNameByID and C_Item.GetItemNameByID(itemID)
    if name then return name end
    local b = ForagerData and ForagerData.items and ForagerData.items[itemID]
    if b then return b[1] end
    if ns.EnchantNames[itemID] then return ns.EnchantNames[itemID] end
    if ns.Scarce[itemID] then return ns.Scarce[itemID].name end
    if C_Item and C_Item.RequestLoadItemDataByID then C_Item.RequestLoadItemDataByID(itemID) end
    return "item:" .. itemID
end

function DS:ItemQuality(itemID)
    local q = C_Item and C_Item.GetItemQualityByID and C_Item.GetItemQualityByID(itemID)
    if q then return q end
    local b = ForagerData and ForagerData.items and ForagerData.items[itemID]
    if not b and ns.Scarce[itemID] then return 2 end -- Scarce materials are Uncommon
    return b and b[2] or 1
end

function DS:ItemCategory(itemID)
    local b = ForagerData and ForagerData.items and ForagerData.items[itemID]
    if not b and ns.Scarce[itemID] then return "trade" end
    return b and b[4] or "other"
end

function DS:ItemVendor(itemID)
    if C_Item and C_Item.GetItemInfo then
        local sell = select(11, C_Item.GetItemInfo(itemID))
        if sell and sell > 0 then return sell end
    end
    local b = ForagerData and ForagerData.items and ForagerData.items[itemID]
    if not b and ns.Scarce[itemID] then return ns.Scarce[itemID].vendor end
    return b and b[3] or 0
end

function DS:ColoredItem(itemID)
    local q = DS:ItemQuality(itemID)
    return "|cff" .. (ns.ColorHex[q] or "ffffff") .. DS:ItemName(itemID) .. "|r"
end

--- Reverse index: which mobs (bundled farm/skin/pickpocket lists) can give itemID.
function DS:MobsForItem(itemID)
    local out = {}
    if not (ForagerData and ForagerData.mobs) then return out end
    local pat = "[|,]" .. itemID .. ":"
    for id, s in pairs(ForagerData.mobs) do
        if s:find(pat) then out[#out + 1] = id end
    end
    return out
end

ns:On("FORAGER_DATA_CHANGED", function() DS:Invalidate() end)
