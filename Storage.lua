-- Storage: account-wide SavedVariables (ForagerDB) with a separate backup addon,
-- auto-restore, versioned migrations and safe mode. Same approach as AuctionTrends.
local _, ns = ...

ns.DB_VERSION = 4

local DEFAULT_SETTINGS = {
    -- layers
    -- maps: Forager draws only the route (nodes are the game's own tracking)
    showRoute = true,            -- route line on the world map
    routeMinimap = "next",       -- off | next (you -> next stop + following legs) | loop (whole route)
    showArea = false,            -- farm area outline
    location = "any",            -- finder/mobs location filter: any | cave | outdoor
    gamePin = false,             -- place the game's own map pin on the farm spot when starting
    tomtom = false,              -- also add a TomTom waypoint when starting (if installed)
    hud = true,                  -- route HUD with arrow
    includeEnemy = false,        -- rank enemy-faction zones too
    ruleset = "auto",            -- auto | pvp | normal (gank risk only on PvP)
    maxRisk = "any",             -- hide spots at/above: any | high | medium | low
    comboGather = "auto",        -- Gather + Kill: auto | ore | herb | both
    comboMode = "gold",          -- gold | skill (gathering + skinning skill-ups)
    comboKill = "all",           -- all | skin (only mobs you can skin)
    comboKillSeconds = 30,       -- fight + loot per equal-level mob
    comboSkinSeconds = 3,        -- extra per skin (cast + loot), only for mobs you can skin
    comboPullYards = 30,         -- mobs and nodes this close to the route count as "on the way"
    comboRespawn = 300,          -- seconds before a killed mob is back
    areaAlpha = 0.12, routeAlpha = 0.8,
    hideInCombat = true, hideInInstances = true,
    -- finder
    mode = "gold",               -- gold | skill
    activeFraction = 0.30,       -- share of spawn points with a live node at any moment
    killsPerHour = 45,
    castsPerHour = 220,
    gatherSeconds = 3,
    speed = "auto",              -- auto | run | mount60 | mount100
    showDangerous = false,
    minSamples = 30,             -- own data replaces Classic estimates from this sample size
    -- prices
    priceSources = { "AuctionTrends", "Auctionator", "Vendor" },
    -- tooltip
    tooltip = true, tooltipGear = true, tooltipFarm = true, tooltipSkin = true, tooltipPickpocket = true,
    -- sharing
    shareGuild = false, shareParty = false,
    -- misc
    minimap = { angle = 200, hide = false },
    saveReminder = 30,           -- gathers between "/forager save" reminders (0 = off)
    debug = false,
}

local function defaults()
    return {
        version = ns.DB_VERSION,
        settings = ns.CopyTable(DEFAULT_SETTINGS),
        nodes = {},      -- [uiMap][xxxyyy] = { t = typeKey, c = count, l = last time, y = {[itemID]=n}, s = source }
        shared = {},     -- same shape, from guild/party
        mobs = {},       -- [npcID] = { k, i, q, s, si, p, pi, g }
        fish = {},       -- [uiMap] = { casts = n, items = {[itemID] = n} } open-water catches
        caves = {},      -- [uiMap][cellKey] = { n = subzone name, c = samples } learned cave footprint (1% cells)
        caveMobs = {},   -- [npcID] = { m = uiMap, n = cave name, c = sightings }
        deaths = {},     -- [uiMap][cellKey] = count (2% cells) your deaths, for the risk estimate
        names = {},      -- learned node type names for unknown types: ["i<itemID>"] = name
        stats = { items = {}, gathers = {}, kills = 0, skins = 0, zones = {}, gold = 0 },
        sessions = {},   -- recent sessions summary
        chars = {},      -- [char-realm] = { questZone, questZone2, goal }
        imported = {},
        meta = { created = time(), lastSave = 0 },
    }
end
ns.DefaultSettings = DEFAULT_SETTINGS

-- Fill missing keys from defaults (non-destructive).
local function fill(dst, src)
    for k, v in pairs(src) do
        if dst[k] == nil then
            dst[k] = ns.CopyTable(v)
        elseif type(v) == "table" and type(dst[k]) == "table" and k ~= "priceSources" then
            fill(dst[k], v)
        end
    end
end

-- Migrations: [fromVersion] = function(db). Each runs protected.
local migrations = {
    [1] = function(db)
        -- 1.1.0: world map shows only the active farm's nodes by default
        db.settings = db.settings or {}
        db.settings.worldNodes = "goal"
        db.settings.minimapNodes = (db.settings.showNodesMinimap == false) and "off" or "all"
        db.settings.hud = db.settings.showArrow ~= false
        db.caves = db.caves or {}
        db.caveMobs = db.caveMobs or {}
        db.version = 2
    end,
    [2] = function(db)
        -- 1.2.0: calm maps while farming; node pins only on request
        local st = db.settings or {}
        db.settings = st
        st.farmWorld, st.farmMinimap = "clean", "clean"
        if st.minimapNodes == "goal" then st.minimapNodes = "off" st.farmMinimap = "dots" end
        if st.worldNodes ~= "all" then st.worldNodes = "off" end
        if st.areaAlpha == 0.25 then st.areaAlpha = 0.12 end
        if st.routeAlpha == 0.9 then st.routeAlpha = 0.8 end
        db.version = 3
    end,
    [3] = function(db)
        -- 1.3.0: no Forager node pins at all; maps show just the route
        local st = db.settings or {}
        db.settings = st
        for _, k in ipairs({ "farmWorld", "farmMinimap", "worldNodes", "minimapNodes", "pinStyle", "pinScale", "pinAlpha",
            "distanceFade", "fadeYards", "onlyEligibleNodes", "kinds", "hiddenTypes", "showBundled", "showLearned", "showShared",
            "showNodesMinimap", "showNodesWorld", "showArrow", "showMobCamps" }) do st[k] = nil end
        st.showRoute = true
        st.routeMinimap = "next"
        st.showArea = false
        st.gamePin = false
        st.tomtom = false
        db.version = 4
    end,
}

local function sizeOf(db)
    if type(db) ~= "table" then return 0 end
    local n = 0
    for _, zone in pairs(db.nodes or {}) do n = n + ns.Count(zone) end
    return n + ns.Count(db.mobs)
end
ns.DataSize = sizeOf

local function looksEmpty(db)
    return type(db) ~= "table" or (sizeOf(db) == 0 and ns.Count(db.stats and db.stats.items) == 0)
end

function ns:InitDB()
    local restored
    if looksEmpty(ForagerDB) and type(ForagerBackupDB) == "table" and not looksEmpty(ForagerBackupDB.data) then
        ForagerDB = ns.CopyTable(ForagerBackupDB.data)
        restored = true
    end
    if type(ForagerDB) ~= "table" then ForagerDB = defaults() end
    local db = ForagerDB
    ns.safeMode = nil
    if (db.version or 0) > ns.DB_VERSION then
        ns.safeMode = "data from a newer Forager version (v" .. tostring(db.version) .. ")"
    else
        while (db.version or ns.DB_VERSION) < ns.DB_VERSION do
            local step = migrations[db.version]
            if not step then db.version = ns.DB_VERSION break end
            local ok, err = pcall(step, db)
            if not ok then
                ns.safeMode = "migration from v" .. tostring(db.version) .. " failed: " .. tostring(err)
                break
            end
        end
    end
    fill(db, defaults())
    ns.db = db
    ns.settings = db.settings
    local ck = ns.CharKey()
    db.chars[ck] = db.chars[ck] or {}
    ns.char = db.chars[ck]
    ns.unsavedGathers = 0
    if restored then ns:Print("|cffffff00Your data file loaded empty - restored from the Forager Backup file.|r") end
    if ns.safeMode then
        ns:Print("|cffff4040Safe mode:|r " .. ns.safeMode .. ". Data left untouched; backup will not be overwritten.")
    end
end

--- Copy data into the backup addon's SavedVariable if the data looks healthy.
function ns:WriteBackup(force)
    if ns.safeMode then return false, "safe mode" end
    if not C_AddOns or not C_AddOns.IsAddOnLoaded or not C_AddOns.IsAddOnLoaded("Forager_Backup") then
        return false, "Forager Backup addon not enabled"
    end
    local cur = sizeOf(ForagerDB)
    local prev = type(ForagerBackupDB) == "table" and (ForagerBackupDB.size or 0) or 0
    if not force and prev > 20 and cur < prev * 0.5 then
        return false, "data shrank to " .. cur .. " entries (backup has " .. prev .. "); backup kept"
    end
    ForagerBackupDB = { data = ns.CopyTable(ForagerDB), size = cur, time = time(), version = ns.version }
    return true
end

function ns:RestoreBackup()
    if type(ForagerBackupDB) ~= "table" or looksEmpty(ForagerBackupDB.data) then
        ns:Print("No usable backup found.")
        return
    end
    ForagerDB = ns.CopyTable(ForagerBackupDB.data)
    ns.resetIntent = true
    ReloadUI()
end

function ns:ResetData(what)
    local db = ns.db
    if what == "nodes" then db.nodes = {}; db.shared = {}
    elseif what == "mobs" then db.mobs = {}
    elseif what == "stats" then db.stats = defaults().stats; db.sessions = {}
    else
        local keepSettings = db.settings
        ForagerDB = defaults()
        ForagerDB.settings = keepSettings
        ns.db = ForagerDB
    end
    ns:WriteBackup(true)
    ns:Fire("FORAGER_DATA_CHANGED")
end

function ns:BackupStatus()
    if type(ForagerBackupDB) ~= "table" then return "no backup yet" end
    local age = time() - (ForagerBackupDB.time or 0)
    return string.format("%d entries, %s old", ForagerBackupDB.size or 0, SecondsToTime and SecondsToTime(age) or (age .. "s"))
end

ns:On("PLAYER_LOGOUT", function()
    if not ns.db then return end
    ns.db.meta.lastSave = time()
    ns:SaveSession()
    ns:WriteBackup(ns.resetIntent)
end)

--- WoW only writes SavedVariables on reload/logout; this forces a write now.
function ns:SaveNow()
    if InCombatLockdown() then ns:Print("Can't reload in combat.") return end
    ReloadUI()
end

function ns:CountGatherForReminder()
    ns.unsavedGathers = (ns.unsavedGathers or 0) + 1
    local every = ns.settings.saveReminder or 0
    if every > 0 and ns.unsavedGathers % every == 0 then
        ns:Print(string.format("%d gathers not written to disk yet. Type |cffffffff/forager save|r to save now (reloads UI).", ns.unsavedGathers))
    end
end
