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
local Pins = LibStub:NewLibrary("HereBeDragons-Pins-2.0", 999)
Pins.mm, Pins.wm = 0, 0
function Pins:AddMinimapIconMap() self.mm = self.mm + 1 end
function Pins:AddWorldMapIconMap() self.wm = self.wm + 1 end
function Pins:RemoveAllMinimapIcons() self.mm = 0 end
function Pins:RemoveAllWorldMapIcons() self.wm = 0 end

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
    assertTrue(ns.db and ns.db.version == 1, "db")
    assertTrue(ns.Player:Skill("herb") == 50, "herb skill")
    assertTrue(ForagerData and ForagerData.nodes, "data loaded")
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

test("pins refresh and world map pins", function()
    ns.Pins:RefreshMinimap()
    assertTrue(LibStub("HereBeDragons-Pins-2.0").mm > 0, "minimap pins")
    WorldMapFrame._shown = true
    ns.Pins:RefreshWorldMap()
    assertTrue(LibStub("HereBeDragons-Pins-2.0").wm > 0, "world pins")
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
