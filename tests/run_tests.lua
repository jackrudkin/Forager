-- Forager test harness: lua5.1 tests/run_tests.lua (from the build directory)
package.path = "tests/?.lua;" .. package.path
local ADDON_DIR, DATA_DIR, BACKUP_DIR = arg[1] or "Forager", arg[2] or "Forager_Data", arg[3] or "Forager_Backup"
local M = require("wowmock")
M.Install()

local passed, failed = 0, 0
local function test(name, fn)
    local ok, err = pcall(fn)
    if ok then passed = passed + 1 print("  ok   " .. name)
    else failed = failed + 1 print("  FAIL " .. name .. "\n       " .. tostring(err)) end
end
local function assertTrue(v, msg) if not v then error(msg or "assertion failed", 2) end end

-- HereBeDragons stub (the real library needs the full map API).
dofile(ADDON_DIR .. "/Libs/LibStub/LibStub.lua")
dofile(ADDON_DIR .. "/Libs/CallbackHandler-1.0/CallbackHandler-1.0.lua")
dofile(ADDON_DIR .. "/Libs/LibDataBroker-1.1/LibDataBroker-1.1.lua")
local HBD = LibStub:NewLibrary("HereBeDragons-2.0", 999)
function HBD:GetZoneSize(map) return 4000, 2666 end
function HBD:GetWorldCoordinatesFromZone(x, y, map) return x * 4000, y * 2666, 0 end
function HBD:GetPlayerWorldPosition() return M.pos[1] * 4000, M.pos[2] * 2666, 0 end
function HBD:GetWorldVector(i, x1, y1, x2, y2) local dx, dy = x2 - x1, y2 - y1 return math.atan2(dx, dy), math.sqrt(dx * dx + dy * dy) end
-- continent 1415 contains the zones at a quarter scale; other zones are unrelated
function HBD:TranslateZoneCoordinates(x, y, o, d)
    if o == d then return x, y end
    if d == 1415 then return 0.5 + x / 4, 0.5 + y / 4 end
    return nil
end
local Pins = LibStub:NewLibrary("HereBeDragons-Pins-2.0", 999)
Pins.refs = {}
function Pins:Count(ref) return self.refs[ref] or 0 end
function Pins:AddMinimapIconMap(ref) self.refs[ref] = (self.refs[ref] or 0) + 1 end
function Pins:AddWorldMapIconMap(ref) self.refs[ref] = (self.refs[ref] or 0) + 1 end
function Pins:RemoveAllMinimapIcons(ref) self.refs[ref] = 0 end
function Pins:RemoveAllWorldMapIcons(ref) self.refs[ref] = 0 end

local ns = {}
local function loadToc(dir, toc, addon, nsTable)
    for line in io.lines(dir .. "/" .. toc) do
        line = line:gsub("\r", "")
        if line ~= "" and not line:match("^#") and line:match("%.lua$") then
            local path = dir .. "/" .. line:gsub("\\", "/")
            local chunk = assert(loadfile(path))
            chunk(addon, nsTable)
        end
    end
end
function M.LoadDataAddon() loadToc(DATA_DIR, "Forager_Data.toc", "Forager_Data", {}) end

print("Loading Forager...")
loadToc(ADDON_DIR, "Forager.toc", "Forager", ns)
loadToc(BACKUP_DIR, "Forager_Backup.toc", "Forager_Backup", {})

print("Tests:")
test("login initialises DB, skills, data", function()
    M.Fire("PLAYER_LOGIN")
    assertTrue(ns.db and ns.db.version == 4, "db")
    assertTrue(ns.Player:Skill("herb") == 50, "herb skill")
    assertTrue(ForagerData and ForagerData.nodes, "data loaded")
end)

test("TOC metadata for packaging (CurseForge ID, versions match)", function()
    local toc = io.open(ADDON_DIR .. "/Forager.toc"):read("*a")
    assertTrue(toc:find("## X%-Curse%-Project%-ID: 1806735"), "CurseForge project ID missing from Forager.toc")
    assertTrue(toc:find("## Interface: 16001"), "interface")
    local v = toc:match("## Version: ([%d%.]+)")
    for _, f in ipairs({ BACKUP_DIR .. "/Forager_Backup.toc", DATA_DIR .. "/Forager_Data.toc" }) do
        assertTrue(io.open(f):read("*a"):match("## Version: ([%d%.]+)") == v, "version mismatch in " .. f)
    end
end)

test("node types have Forever additions and objects", function()
    local peace = ns.NodeTypes[1]
    assertTrue(peace.name == "Peacebloom" and #peace.objects > 0)
    assertTrue(ns.DS:TypeForObject(1618) == 1)
end)

test("zone nodes decode for Elwynn", function()
    local nodes = ns.DS:GetZoneNodes(1429)
    assertTrue(#nodes > 50, "nodes " .. #nodes)
    for _, n in ipairs(nodes) do assertTrue(n.x >= 0 and n.x <= 1 and n.y >= 0 and n.y <= 1) end
end)

test("finder herbalism gold mode ranks zones", function()
    local res = ns.Finder:Run({ goal = "herb", mode = "gold", perZone = 2 })
    assertTrue(#res > 0, "no results")
    local r = res[1]
    assertTrue(r.perHour > 0 and r.route and #r.route.points > 0, "route")
    for _, x in ipairs(res) do
        local z = ns.Zones[x.uiMap]
        assertTrue(z.faction ~= "H", "enemy zone included: " .. z.name)
    end
    print("       top: " .. r.zoneName .. " " .. math.floor(r.perHour) .. "c/h, " .. #r.route.points .. " waypoints, min skill " .. r.minSkill)
end)

test("finder skill-up mode favours orange/yellow nodes", function()
    local res = ns.Finder:Run({ goal = "herb", mode = "skill", perZone = 1 })
    assertTrue(#res > 0)
    assertTrue(res[1].mode == "skill")
end)

test("finder skinning and cloth mob goals", function()
    local res = ns.Finder:Run({ goal = "skin", mode = "gold", perZone = 1 })
    assertTrue(#res > 0, "skin")
    local cloth = ns.Finder:Run({ goal = "cloth", perZone = 1 })
    assertTrue(#cloth > 0, "cloth")
    local greens = ns.Finder:Run({ goal = "greens", perZone = 1 })
    assertTrue(#greens > 0, "greens")
end)

test("finder fishing goal", function()
    M.skills[3] = { "Fishing", 120, 150, 356 }
    ns.Player:RefreshSkills()
    local res = ns.Finder:Run({ goal = "fish" })
    assertTrue(#res > 0, "fish")
end)

test("questing mode restricts zones and adds detour", function()
    ns.Quests:Set(1429, nil)
    local best, all = ns.Finder:Best("herb", "gold")
    assertTrue(best and best.uiMap == 1429, "zone")
    assertTrue(best.detourMin ~= nil, "detour")
    for _, r in ipairs(all) do assertTrue(r.uiMap == 1429) end
    ns.Quests:Set(nil, nil)
end)

test("quest objective names parsed", function()
    local names = ns.Quests:ObjectiveNames()
    assertTrue(names["prowler"], "prowler")
end)

test("route build + start + progress", function()
    local pts = {}
    for i = 1, 30 do pts[i] = { x = 0.3 + (i % 6) * 0.03, y = 0.4 + math.floor(i / 6) * 0.03, w = i } end
    local route = ns.Route:Build(1429, pts, 20)
    assertTrue(#route.points >= 10 and route.length > 0)
    ns.Route:Start({ uiMap = 1429, route = route, rect = { 0.3, 0.4, 0.5, 0.6 }, goal = "herb", mode = "gold", perHour = 1, zoneName = "Elwynn" })
    local wp, d = ns.Route:Next()
    assertTrue(wp and d, "next")
    M.pos = { wp.x, wp.y }
    ns.Route:Update()
    assertTrue(ns.Route.active.visited == 1, "advanced")
    ns.Overlay:DrawMinimap()
    ns.Overlay:UpdateArrow()
    ns.Route:Stop()
end)

test("tooltip lines for Ornery Plainstrider (3245)", function()
    local lines = ns.Tooltip:Lines(3245, 17)
    local text = ""
    for _, l in ipairs(lines) do text = text .. l[1] .. " " .. (l[2] or "") .. "\n" end
    assertTrue(text:find("Skinnable 70"), "skin req: " .. text)
    assertTrue(text:find("Gear:"), "gear line")
    assertTrue(text:find("Classic est"), "label")
end)

test("tooltip post-call hook with secret guid does not error", function()
    M.tooltipLines = {}
    M.tooltipPostCall(GameTooltip, { guid = M.secret })
    M.tooltipPostCall(GameTooltip, { guid = "Creature-0-1-0-1-3245-0000ABCD" })
    assertTrue(#M.tooltipLines > 0, "lines added")
end)

test("capture herb gather records learned node", function()
    M.pos = { 0.41, 0.61 }
    M.Fire("UNIT_SPELLCAST_SUCCEEDED", "player", "cast-1", 2366)
    M.loot = { { link = "|cffffffff|Hitem:2447::::::::|h[Peacebloom]|h|r", qty = 2, sources = { "GameObject-0-1-0-1-1618-00AA", 2 } } }
    M.Fire("LOOT_READY")
    M.Fire("LOOT_CLOSED")
    local zone = ns.db.nodes[1429]
    assertTrue(zone, "zone")
    local found
    for k, rec in pairs(zone) do if rec.t == 1 then found = rec end end
    assertTrue(found and found.c == 1 and found.y[2447] == 2, "peacebloom record")
    -- second gather at nearly the same place merges
    M.pos = { 0.4105, 0.6102 }
    M.Fire("UNIT_SPELLCAST_SUCCEEDED", "player", "cast-2", 2366)
    M.Fire("LOOT_READY")
    M.Fire("LOOT_CLOSED")
    assertTrue(found.c == 2, "merged")
    assertTrue(M.sent and #M.sent == 0 or not M.sent, "sharing off by default")
end)

test("capture unknown Forever herb becomes learned type by item", function()
    M.Fire("UNIT_SPELLCAST_SUCCEEDED", "player", "cast-3", 99999) -- Forever's own spell ID, matched by name? no
    -- simulate a spell ID unknown to us but with the same name
    _G.C_Spell.GetSpellName = (function(old) return function(id) if id == 470001 then return "Herb Gathering" end return old(id) end end)(_G.C_Spell.GetSpellName)
    M.Fire("UNIT_SPELLCAST_SUCCEEDED", "player", "cast-4", 470001)
    M.loot = { { link = "|Hitem:250001::|h[Marefoil]|h", qty = 1, sources = { "GameObject-0-1-0-1-777777-00AA", 1 } } }
    M.pos = { 0.7, 0.2 }
    M.Fire("LOOT_READY")
    M.Fire("LOOT_CLOSED")
    local got
    for _, rec in pairs(ns.db.nodes[1429]) do if rec.t == "i250001" then got = rec end end
    assertTrue(got, "learned type")
    assertTrue(ns.DS:GetType("i250001").name, "type name")
end)

test("capture creature loot counts corpse once with gear grade", function()
    M.loot = {
        { link = "|Hitem:2589::|h[Linen Cloth]|h", qty = 1, sources = { "Creature-0-1-0-1-589-0000BEEF", 1 } },
        { link = "|Hitem:9999::|h[Green Vest]|h", qty = 1, sources = { "Creature-0-1-0-1-589-0000BEEF", 1 } },
    }
    M.Fire("LOOT_READY") M.Fire("LOOT_CLOSED")
    M.Fire("LOOT_READY") M.Fire("LOOT_CLOSED")
    local m = ns.db.mobs[589]
    assertTrue(m and m.k == 1, "kills " .. tostring(m and m.k))
    assertTrue(m.q[2] == 1, "green counted")
end)

test("capture skinning attributes to creature", function()
    M.Fire("UNIT_SPELLCAST_SUCCEEDED", "player", "cast-5", 8613)
    M.loot = { { link = "|Hitem:2318::|h[Light Leather]|h", qty = 1, sources = { "Creature-0-1-0-1-3245-0000F00D", 1 } } }
    M.Fire("LOOT_READY") M.Fire("LOOT_CLOSED")
    local m = ns.db.mobs[3245]
    assertTrue(m and m.s == 1 and m.si[2318] == 1)
end)

test("secret loot values are ignored without errors", function()
    M.Fire("UNIT_SPELLCAST_SUCCEEDED", "player", "cast-6", 2575)
    M.loot = { { link = M.secret, qty = M.secret, sources = { M.secret, 1 } } }
    M.Fire("LOOT_READY") M.Fire("LOOT_CLOSED")
end)

test("sharing sends when enabled and receives valid messages only", function()
    ns.settings.shareGuild = true
    M.sent = {}
    ns.Comms:Share(1, 1429, "abcdef")
    assertTrue(#M.sent == 1 and M.sent[1][3] == "GUILD", "sent")
    M.Fire("CHAT_MSG_ADDON", "Forager", "N1|5|1429|0a10b0", "GUILD", "Friend-Realm")
    M.Fire("CHAT_MSG_ADDON", "Forager", "N1|5|99999|0a10b0", "GUILD", "Friend-Realm")
    M.Fire("CHAT_MSG_ADDON", "Forager", "garbage", "GUILD", "Friend-Realm")
    assertTrue(ns.db.shared[1429] and ns.db.shared[1429]["0a10b0"], "stored")
    assertTrue(not ns.db.shared[99999], "invalid map ignored")
    ns.settings.shareGuild = false
end)

test("import GatherMate2 + GatherLite saved variables", function()
    _G.GatherMate2HerbDB = { [1429] = { [4100006100] = 1 } }
    _G.GatherLiteSettings = { global = { nodes = { herbalism = { { posX = 0.55, posY = 0.33, mapID = 1429, object = 1617 } } } } }
    local n = ns.Import:Run(true)
    assertTrue(n >= 1, "imported " .. n)
end)

test("backup write + restore on empty load + safe mode", function()
    local ok = ns:WriteBackup(true)
    assertTrue(ok, "backup written")
    local saved = ForagerBackupDB
    ForagerDB = nil
    ns:InitDB()
    assertTrue(ns.DataSize(ForagerDB) > 0, "restored")
    ForagerDB.version = 99
    ns:InitDB()
    assertTrue(ns.safeMode, "safe mode")
    local ok2 = ns:WriteBackup(true)
    assertTrue(not ok2, "backup blocked in safe mode")
    ForagerDB.version = 1
    ns:InitDB()
    assertTrue(not ns.safeMode)
    assertTrue(ForagerBackupDB == saved)
end)

test("backup refuses when data shrank", function()
    ForagerBackupDB = { data = {}, size = 1000, time = 0 }
    local ok, why = ns:WriteBackup(false)
    assertTrue(not ok and why:find("shrank"), tostring(why))
end)

test("UI builds every tab and Start farming works", function()
    ns.Main:Toggle()
    for i = 1, #ns.Main.tabs do ns.Main:SelectTab(i) end
    for _, l in ipairs(M.printed) do assertTrue(not tostring(l):find("UI error"), tostring(l)) end
    ns.Main:StartFarming()
    assertTrue(ns.Route.active, "route active")
    ns.Main:SelectTabByKey("map")
    ns.Main:SelectTabByKey("stats")
end)

test("slash commands", function()
    for _, c in ipairs({ "", "help", "status", "quest Elwynn", "quest off", "mode skill", "mode gold", "start cloth", "stop", "find", "backup", "mob" }) do
        ns.Slash(c)
    end
    M.unitGUID = "Creature-0-1-0-1-3245-0000F00D"
    ns.Slash("mob")
end)

test("maps: no node pins, just the route", function()
    local HP = LibStub("HereBeDragons-Pins-2.0")
    assertTrue(ns.Pins == nil, "no pin module")
    assertTrue(ns.settings.showRoute and ns.settings.routeMinimap == "next" and not ns.settings.showArea, "defaults")
    assertTrue(not ns.settings.gamePin and not ns.settings.tomtom, "no extra waypoints by default")
    M.mapID, M.pos = 1429, { 0.45, 0.6 }
    WorldMapFrame._shown = true
    M.worldMapID = 1429
    M.userWaypoint = nil
    local best = ns.Finder:Run({ goal = "herb", zones = { 1429 }, perZone = 1 })[1]
    ns.Route:Start(best)
    M.Fire("ZONE_CHANGED_NEW_AREA")
    M.Fire("PLAYER_ENTERING_WORLD")
    M.RunTimers()
    local total = 0
    for _, v in pairs(HP.refs) do total = total + v end
    assertTrue(total == 0, "nothing pinned on the maps")
    assertTrue(M.userWaypoint == nil, "no game map pin unless asked")
    ns.Overlay.lastError = nil
    for _, mode in ipairs({ "next", "loop", "off" }) do
        ns.settings.routeMinimap = mode
        ns.Overlay.DrawMinimap()
    end
    ns.settings.routeMinimap = "next"
    ns.settings.showArea = true
    ns.Overlay.DrawWorldMap()
    ns.Overlay.DrawMinimap()
    ns.settings.showArea = false
    assertTrue(ns.Overlay.lastError == nil, "draw error: " .. tostring(ns.Overlay.lastError))
    -- explicit "Set waypoint" still places the game pin
    ns.Overlay:SetFarmPin(best, true)
    assertTrue(M.userWaypoint and M.userWaypoint.uiMapID == best.uiMap, "explicit waypoint")
    ns.Route:Stop()
    assertTrue(M.userWaypoint == nil, "cleared on stop")
end)

test("OpenMap: route above its art, positions via its API, view glides to the farm", function()
    local calls = {}
    OpenMapAPI = {
        major = 1, version = 4,
        IsStitched = function() return true end,
        WorldFromMap = function(map, x, y) return 0.4 + x * 0.05, 0.3 + y * 0.05 end,
        MapFromWorld = function(map, u, v) calls.mapFromWorld = (calls.mapFromWorld or 0) + 1 return (u - 0.38) * 10, (v - 0.28) * 10 end,
        ArtTopLevel = function() return 3200 end,
        ShowWorld = function(u, v, zoom) calls.show = { u, v, zoom } return true end,
        RegisterCallback = function() end,
    }
    local best = ns.Finder:Run({ goal = "herb", zones = { 1429 }, perZone = 1 })[1]
    ns.Main:Toggle("farm")
    assertTrue(ns.Main.frame:IsShown(), "window open")
    ns.Route:Preview(best)
    ns.Overlay.lastError = nil
    WorldMapFrame._shown = false
    ns.Overlay:OpenMapTo(best.uiMap)
    M.RunTimers()
    assertTrue(not ns.Main.frame:IsShown(), "Forager window hidden while the map is open")
    assertTrue(calls.show and calls.show[3] >= 1 and calls.show[3] <= 40, "OpenMap view glides to the farm")
    M.worldMapID = 1415 -- OpenMap's host map can be a neighbouring zone or continent
    ns.Overlay.DrawWorldMap()
    assertTrue(ns.Overlay.lastError == nil, "draw error: " .. tostring(ns.Overlay.lastError))
    assertTrue((calls.mapFromWorld or 0) > 0, "positions from OpenMap's API")
    assertTrue(ns.Overlay:WorldMapLayer():GetFrameLevel() > 3200, "route layer above OpenMap's art")
    WorldMapFrame:Hide()
    assertTrue(ns.Route.preview == nil, "preview cleared when the map closes")
    assertTrue(ns.Main.frame:IsShown(), "Forager window back after the map closes")
    ns.Main.frame:Hide()
    OpenMapAPI = nil
end)

test("gather + kill: time-shared rate, best-ratio mob choice, results usable as a farm", function()
    local res = ns.Combo:Run({ gather = "ore", perZone = 2 })
    assertTrue(#res > 0, "combo results")
    for i, r in ipairs(res) do
        if i > 1 then assertTrue(res[i - 1].perHour >= r.perHour, "sorted") end
        assertTrue(r.goal == "combo:ore" and r.source == "combo", "goal")
        assertTrue(math.abs(r.nodeRate + r.mobRate - r.perHour) < 1, "split adds up")
        assertTrue(r.perHour + 1 >= r.nodesOnlyRate, "never worse than gathering alone")
        assertTrue(math.abs(r.walkSec + r.gatherSec + r.fightSec - r.loopSec) < 0.01, "time adds up")
        local avg = r.perHour / 3600
        for _, m in ipairs(r.worthy) do assertTrue(m.perMin / 60 >= avg - 1e-6, "worthy mob beats the loop rate") end
        for _, m in ipairs(r.skipped) do assertTrue(m.perMin / 60 <= avg + 1e-6, "skipped mob doesn't") end
        assertTrue(#r.route.points > 0 and r.rect, "route + area")
    end
    local top = res[1]
    print(string.format("       combo top: %s %s/h (ore %s + mobs %s; ore only %s, mobs only %s), %d worth killing, %d skipped",
        top.zoneName, ns.Money(top.perHour, true), ns.Money(top.nodeRate, true), ns.Money(top.mobRate, true),
        ns.Money(top.nodesOnlyRate, true), ns.Money(top.mobsOnlyRate, true), #top.worthy, #top.skipped))
    -- slower kills -> mobs worth less of your time -> mob share can't grow
    local old = ns.settings.comboKillSeconds
    ns.settings.comboKillSeconds = 90
    local slow = ns.Combo:Run({ gather = "ore", zones = { top.uiMap }, perZone = 1 })[1]
    ns.settings.comboKillSeconds = 10
    local fast = ns.Combo:Run({ gather = "ore", zones = { top.uiMap }, perZone = 1 })[1]
    ns.settings.comboKillSeconds = old
    assertTrue(slow and fast and fast.mobRate >= slow.mobRate and fast.perHour >= slow.perHour, "kill speed monotonic")
    -- herbs and both
    assertTrue(#ns.Combo:Run({ gather = "herb", perZone = 1 }) > 0, "herb combo")
    assertTrue(#ns.Combo:Run({ gather = "both", perZone = 1 }) > 0, "both combo")
    -- start it like any farm
    assertTrue(ns.Finder:GoalInfo("combo:ore").label == "Mining + mobs", "goal label")
    ns.Route:Start(top)
    ns.Overlay.lastError = nil
    ns.Overlay.UpdateArrow()
    ns.Overlay.DrawMinimap()
    assertTrue(ns.Overlay.lastError == nil, "hud/minimap with combo: " .. tostring(ns.Overlay.lastError))
    ns.Main:Toggle("combo")
    ns.Main:Toggle("route")
    ns.Main.frame:Hide()
    ns.Route:Stop()
    for _, l in ipairs(M.printed) do assertTrue(not tostring(l):find("UI error") and not tostring(l):find("Gather %+ Kill error"), tostring(l)) end
end)

test("settings migration to v4 (route only)", function()
    local savedDB, savedBackup = ForagerDB, ForagerBackupDB
    ForagerBackupDB = nil
    ForagerDB = { version = 2, settings = { worldNodes = "goal", minimapNodes = "goal", areaAlpha = 0.25, routeAlpha = 0.9, pinScale = 1.3,
        showArea = true, gamePin = true, tomtom = true, hiddenTypes = { ["1"] = true } },
        nodes = { [1429] = { a = { t = 1, x = 0.5, y = 0.5 } } } }
    ns:InitDB()
    local st = ns.settings
    assertTrue(ns.db.version == 4 and not ns.safeMode, "migrated")
    assertTrue(st.worldNodes == nil and st.minimapNodes == nil and st.farmMinimap == nil and st.pinScale == nil and st.hiddenTypes == nil, "pin settings removed")
    assertTrue(st.showRoute and st.routeMinimap == "next" and not st.showArea and not st.gamePin and not st.tomtom, "route only")
    assertTrue(st.areaAlpha == 0.12 and st.routeAlpha == 0.8, "styles")
    ForagerDB, ForagerBackupDB = savedDB, savedBackup
    ns:InitDB()
    assertTrue(ns.db.version == 4, "restored")
end)

test("caves: names, learning, overlay areas and finder filter", function()
    assertTrue(ns.Caves:IsCaveName(1429, "Fargodeep Mine"), "bundled cave name")
    assertTrue(ns.Caves:IsCaveName(1411, "Dustwind Cave"), "keyword cave")
    assertTrue(not ns.Caves:IsCaveName(1429, "Goldshire"), "town is not a cave")
    assertTrue(ns.Caves:ZoneHasCaves(1429), "elwynn has caves")
    -- learning while indoors in a cave subzone
    M.mapID, M.pos = 1429, { 0.40, 0.80 }
    M.indoors, M.subzone = true, "Fargodeep Mine"
    for i = 0, 4 do M.pos = { 0.39 + i * 0.01, 0.80 } ns.Caves:LearnHere() end
    M.indoors, M.subzone = false, ""
    local cave, name = ns.Caves:At(1429, 0.41, 0.80)
    assertTrue(cave == true and name == "Fargodeep Mine", "learned cell")
    assertTrue(#ns.Caves:List(1429) == 1, "cave list")
    -- explored-map overlay: Jasperlode Mine around (0.61, 0.52)
    M.areaNames[54] = "Jasperlode Mine"
    M.exploredAt = function(map, x, y) if map == 1429 and math.abs(x - 0.61) < 0.06 and math.abs(y - 0.50) < 0.06 then return { 54 } end return {} end
    M.Fire("MAP_EXPLORATION_UPDATED")
    local c2, n2 = ns.Caves:At(1429, 0.61, 0.50)
    assertTrue(c2 == true and n2 == "Jasperlode Mine", "overlay cave")
    assertTrue(ns.Caves:At(1429, 0.2, 0.2) == false, "explored, not a cave")
    -- mob seen while in a cave
    M.indoors, M.subzone, M.unitGUID = true, "Fargodeep Mine", "Creature-0-1-0-1-40-0000F00D"
    M.Fire("PLAYER_TARGET_CHANGED")
    assertTrue(ns.db.caveMobs[40] and ns.db.caveMobs[40].n == "Fargodeep Mine", "cave mob learned")
    M.indoors, M.subzone = false, ""
    -- finder: caves only
    ns.settings.location = "cave"
    local res = ns.Finder:Run({ goal = "gold", zones = { 1429 }, perZone = 2 })
    ns.settings.location = "any"
    assertTrue(#res > 0, "cave results")
    for _, r in ipairs(res) do
        for _, p in ipairs(r.points) do assertTrue(ns.Caves:At(1429, p.x, p.y) == true, "point outside cave") end
        assertTrue(r.cave, "result flagged cave")
    end
    print("       cave top: " .. res[1].zoneName .. " / " .. tostring(res[1].areaName) .. " " .. ns.Money(res[1].perHour, true) .. "/h")
    local out = ns.Finder:Run({ goal = "gold", zones = { 1429 }, perZone = 1, location = "outdoor" })
    assertTrue(#out > 0 and not out[1].cave, "outdoor results")
    -- zones without caves are skipped in cave mode
    local any = ns.Finder:Run({ goal = "herb", location = "cave", anyLevel = true })
    for _, r in ipairs(any) do assertTrue(ns.Caves:ZoneHasCaves(r.uiMap), "cave zone") end
    M.exploredAt = function() return {} end
    ns.Caves:ResetCache()
end)

test("item goals, suggestions and farm-this-mob", function()
    local sug = ns.Finder:Suggest("peace", 5)
    assertTrue(sug[1] and sug[1].kind == "item" and sug[1].text == "Peacebloom", "suggest Peacebloom")
    local cat = ns.Finder:Suggest("herb", 5)
    assertTrue(cat[1] and cat[1].kind == "goal" and cat[1].key == "herb", "category first")
    local res = ns.Finder:Run({ goal = "item:2447", perZone = 1 })
    assertTrue(#res > 0 and res[1].source == "node", "peacebloom from nodes")
    assertTrue(res[1].itemUnits and res[1].itemUnits > 0, "units per hour")
    for _, it in ipairs(res[1].items) do assertTrue(it.id == 2447, "only the item") end
    local cloth = ns.Finder:Run({ goal = "item:2589", perZone = 1 })
    assertTrue(#cloth > 0 and cloth[1].source == "mob", "linen from mobs")
    local r = ns.Finder:MobResult(cloth[1].mobs[1].npc, cloth[1].uiMap)
    assertTrue(r and #r.route.points > 0 and r.rect and r.perHour >= 0, "mob result")
    ns.Route:Start(r)
    assertTrue(ns.Route.active.result == r, "farming mob")
    ns.Route:Stop()
end)

test("preview, open map at farm, map pin and world map translation", function()
    local best = ns.Finder:Best("herb", "gold")
    WorldMapFrame._shown = false
    ns.Route:Preview(best)
    assertTrue(ns.Route:Shown() and ns.Route:Shown().preview, "preview shown")
    ns.Overlay:OpenMapTo(best.uiMap)
    assertTrue(M.worldMapID == best.uiMap, "map opened at farm zone")
    ns.Route:Start(best)
    assertTrue(ns.Route.preview == nil and ns.Route:Shown() == ns.Route.active, "start clears preview")
    assertTrue(M.userWaypoint == nil, "no game map pin by default")
    ns.Overlay:SetFarmPin(best, true)
    assertTrue(M.userWaypoint and M.userWaypoint.uiMapID == best.uiMap, "game map pin set")
    -- draw on the farm zone and on a continent (OpenMap-style) view without errors
    ns.Overlay.lastError = nil
    M.worldMapID = best.uiMap
    ns.Overlay.DrawWorldMap()
    M.worldMapID = 1415
    ns.Overlay.DrawWorldMap()
    M.worldMapID = 9999
    ns.Overlay.DrawWorldMap()
    ns.Overlay.UpdateArrow()
    ns.Overlay.DrawMinimap()
    assertTrue(ns.Overlay.lastError == nil, "draw error: " .. tostring(ns.Overlay.lastError))
    ns.Route:Stop()
    assertTrue(M.userWaypoint == nil, "pin cleared on stop")
    ns.Slash("diag")
    ns.Slash("caves")
    ns.Slash("map")
end)

test("missing data addon degrades gracefully", function()
    local saved = ForagerData
    ForagerData = nil
    M.noData = true
    ns.DS.warned = nil
    ns.DS:Invalidate()
    local res = ns.Finder:Run({ goal = "herb" })
    assertTrue(type(res) == "table")
    local lines = ns.Tooltip:Lines(3245, 17)
    assertTrue(#lines >= 1)
    ForagerData = saved
    M.noData = nil
    ns.DS:Invalidate()
end)

test("logout writes backup", function()
    ForagerBackupDB = nil
    M.Fire("PLAYER_LOGOUT")
    assertTrue(type(ForagerBackupDB) == "table" and ForagerBackupDB.size > 0)
end)

M.RunTimers(10)
print(string.format("\n%d passed, %d failed", passed, failed))
os.exit(failed == 0 and 0 or 1)
