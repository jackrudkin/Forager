-- Forager test harness: lua5.1 tests/run_tests.lua (from the build directory)
package.path = "tests/?.lua;" .. package.path
local ADDON_DIR, DATA_DIR, BACKUP_DIR = arg[1] or "Forager", arg[2] or "Forager_Data", arg[3] or "Forager_Backup"
local M = require("wowmock")
M.Install()

local passed, failed = 0, 0
local function test(name, fn)
    local ok, err = xpcall(fn, function(e) return os.getenv("TRACE") and debug.traceback(e, 2) or e end)
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
    assertTrue(ns.db and ns.db.version == 6, "db")
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
    assertTrue(text:find("estimate"), "label")
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

test("Forever skill colours: herbs stay yellow 15 points longer, Dreamfoil from the wiki", function()
    assertTrue(ns.SkillColor(1, 60, "herb") == "yellow", "Peacebloom at 60 is yellow in Forever (1/25/65/100)")
    assertTrue(ns.SkillColor(1, 60, "ore") == "green", "Copper at 60 is green (1/25/50/100)")
    assertTrue(ns.SkillColor(1, 65, "herb") == "green" and ns.SkillColor(1, 100, "herb") == "grey", "herb green and grey")
    local dream = ns.NodeTypes[24]
    assertTrue(dream.name == "Dreamfoil", "type 24 is Dreamfoil")
    assertTrue(ns.NodeSkillColor(dream, 289) == "orange" and ns.NodeSkillColor(dream, 295) == "yellow"
        and ns.NodeSkillColor(dream, 345) == "green" and ns.NodeSkillColor(dream, 370) == "grey", "Dreamfoil 270/290/340/370")
end)

test("time per node: Classic cast times x gathers per vein, then your measured casts", function()
    local copper, peace = ns.NodeTypes[34], ns.NodeTypes[1]
    ns.Learn.Store().nodes, ns.Learn.Store().bh = {}, {}
    ns.Learn:Changed()
    local ci, pi = ns.Learn:NodeInfo(copper), ns.Learn:NodeInfo(peace)
    assertTrue(math.abs(ci.secs - (3 * 3.2 + 1)) < 0.01, "copper vein: 3 x 3.2 s + 1 s = " .. ci.secs)
    assertTrue(math.abs(pi.secs - (5 + 1)) < 0.01, "peacebloom: 5 s + 1 s = " .. pi.secs)
    -- measure 10 herb casts of 1.5 s and loot windows of 0.5 s (fresh timing store)
    ns.Learn.Store().cast, ns.Learn.Store().loot = {}, {}
    for i = 1, 10 do
        M.Fire("UNIT_SPELLCAST_START", "player", "c" .. i, 2366)
        M.now = M.now + 1.5
        M.Fire("UNIT_SPELLCAST_SUCCEEDED", "player", "c" .. i, 2366)
        M.loot = { { link = "|Hitem:2447::|h[Peacebloom]|h", qty = 1, sources = { "GameObject-0-1-0-1-1618-00A" .. i, 1 } } }
        M.pos = { 0.1 + i * 0.03, 0.1 }
        M.Fire("LOOT_READY")
        M.now = M.now + 0.5
        M.Fire("LOOT_CLOSED")
    end
    local sec, src = ns.Learn:CastSeconds("herb")
    assertTrue(src == "me" and math.abs(sec - 1.5) < 0.01, "measured herb cast " .. tostring(sec))
    local ls = ns.Learn:LootSeconds("herb")
    assertTrue(math.abs(ns.Learn:NodeInfo(peace).secs - (1.5 + 0.5 + 1)) < 0.01, "node time uses measured cast + loot: "
        .. ns.Learn:NodeInfo(peace).secs .. " loot " .. tostring(ls))
    -- an interrupted cast is not measured
    M.Fire("UNIT_SPELLCAST_START", "player", "x", 2366)
    M.now = M.now + 4
    M.Fire("UNIT_SPELLCAST_INTERRUPTED", "player")
    M.Fire("UNIT_SPELLCAST_SUCCEEDED", "player", "x", 2366)
    assertTrue(math.abs(ns.Learn:CastSeconds("herb") - 1.5) < 0.01, "interrupted cast ignored")
end)

test("mining: loots on one vein are one visit; your yields are blended with Classic (n vs estimate weight)", function()
    local before = ns.Learn.Store().nodes[34]
    local v0, n0 = before and before.v or 0, before and before.n or 0
    M.pos = { 0.33, 0.77 }
    for tap = 1, 3 do
        M.Fire("UNIT_SPELLCAST_SUCCEEDED", "player", "m" .. tap, 2575)
        M.loot = { { link = "|Hitem:2770::|h[Copper Ore]|h", qty = 2, sources = { "GameObject-0-1-0-1-1731-00B1", 2 } } }
        if tap == 3 then M.loot[2] = { link = "|Hitem:249391::|h[Pyrite]|h", qty = 1, sources = { "GameObject-0-1-0-1-1731-00B1", 1 } } end
        M.Fire("LOOT_READY") M.Fire("LOOT_CLOSED")
    end
    local r = ns.Learn.Store().nodes[34]
    assertTrue(r.v == v0 + 1 and r.n == n0 + 3, "one visit, three loots")
    -- few visits: mostly the Classic estimate, Scarce pending
    local copper = ns.NodeTypes[34]
    local info = ns.Learn:NodeInfo(copper)
    assertTrue(not info.learned and info.scarce == 249391 and not info.scarceRate and info.src:find("blend"), "blend + scarce pending")
    -- 40 visits: 2 loots of 2 ore each per vein, Pyrite on 1 in 10 loots; k = 30 -> 40/70 yours
    ns.Learn.Store().nodes[34] = { v = 40, n = 80, y = { [2770] = 160, [249391] = 8 } }
    ns.Learn.Store().bh = {}
    ns.Learn:Changed()
    info = ns.Learn:NodeInfo(copper)
    local w = 40 / 70
    local classicOre = 0
    for _, y in ipairs(copper.yields) do if y[1] == 2770 then classicOre = classicOre + y[2] end end
    assertTrue(info.learned and math.abs(info.taps - (w * 2 + (1 - w) * copper.taps)) < 0.001, "blended taps " .. info.taps)
    local wantOre = w * 4 + (1 - w) * classicOre * copper.taps
    assertTrue(math.abs(ns.Learn:NodeQty(copper, 2770) - wantOre) < 0.001, "blended ore per node " .. ns.Learn:NodeQty(copper, 2770) .. " want " .. wantOre)
    assertTrue(math.abs(ns.Learn:NodeQty(copper, 249391) - w * 0.2) < 0.001, "pyrite: yours blended with no estimate")
    assertTrue(math.abs(info.scarceRate - 0.1) < 0.001, "scarce rate per gather")
    assertTrue(ns.Finder:NodeValue(copper) > 0, "value from learned yields")
    -- pooled Scarce rate (per gather x gathers per node) for every Pyrite node once 100 gathers are logged
    ns.Learn.Store().nodes[34] = { v = 60, n = 120, y = { [2770] = 240, [249391] = 12 } }
    ns.Learn.Store().nodes[35] = nil
    ns.Learn.Store().bh = {}
    ns.Learn:Changed()
    local rate, n = ns.Learn:ScarceNodeRate(249391)
    assertTrue(n == 120 and math.abs(rate - 0.1) < 0.001, "pooled")
    local tin = ns.Learn:NodeInfo(ns.NodeTypes[35])
    assertTrue(tin.scarceRate and ns.Learn:NodeQty(ns.NodeTypes[35], 249391) > 0, "tin gets the pooled Pyrite rate")
    assertTrue(ns.DS:ItemName(249391) == "Pyrite" and ns.DS:ItemVendor(249391) == 100 and ns.DS:ItemQuality(249391) == 2, "scarce item data")
    local copperInfo = ns.Learn:NodeInfo(copper)
    assertTrue(math.abs(ns.Learn:NodeQty(copper, 249391) - 0.1 * copperInfo.taps) < 0.001, "pooled rate x gathers per node")
    -- Bountiful Harvest rank 2: +40% on the pooled rate; data seeded at rank 0 with nothing new is re-scaled
    ns.settings.harvestRank = 2
    ns.Learn:SetHarvestRank(2)
    rate = ns.Learn:ScarceNodeRate(249391)
    assertTrue(math.abs(rate - 0.1) < 0.001, "seeded data re-scaled to the new rank: same measured rate " .. rate)
    ns.Learn:AddNode(34, { [2770] = 2 }, true)
    rate = ns.Learn:ScarceNodeRate(249391)
    assertTrue(rate < 0.1 and rate > 0.098, "new gathers count at rank 2 " .. rate)
    ns.settings.harvestRank = 0
    ns.Learn:SetHarvestRank(0)
    ns.Learn.Store().nodes[34], ns.Learn.Store().nodes[35] = nil, nil
    ns.Learn.Store().bh = {}
    ns.Learn:Changed()
end)

test("skinning: Pristine Leather for beasts 10-26, own skins with quantities blended with estimates", function()
    local own = ns.db.mobs[3245]
    local keep = { own.s, own.ss, own.si, own.sq }
    own.s, own.ss, own.si, own.sq = 0, nil, nil, nil
    ns.DS:InvalidateMobs()
    local m = ns.DS:GetMob(3245) -- Ornery Plainstrider, beast
    local hasPL = false
    for _, e in ipairs(m.skin) do if e[1] == 249427 then hasPL = math.abs(e[2] - 0.029) < 1e-6 end end
    assertTrue(m.ctype == 1 and (m.minLevel <= 26 and m.maxLevel >= 10) == hasPL, "Pristine Leather seed matches level band")
    local baseLeather = 0
    for _, e in ipairs(m.skinBase) do if e[1] == 2318 then baseLeather = e[2] end end
    -- 40 of your skins (with quantities) vs estimate weight 30
    own.s, own.ss = 40, 40
    own.si = { [2318] = 40 }
    own.sq = { [2318] = 60, [249427] = 2 }
    ns.DS:InvalidateMobs()
    local mine = ns.DS:GetMob(3245)
    local leather, pl
    for _, e in ipairs(mine.skin) do if e[1] == 2318 then leather = e[2] elseif e[1] == 249427 then pl = e[2] end end
    local w = 40 / 70
    assertTrue(math.abs(leather - (w * 1.5 + (1 - w) * baseLeather)) < 1e-6, "leather blended " .. leather)
    assertTrue(math.abs(pl - (w * 0.05 + (1 - w) * 0.029)) < 1e-6 and mine.skinSrc:find("my data"), "pristine blended " .. pl)
    -- Bountiful Harvest rank 5 doubles the Scarce estimate
    own.s, own.ss = 0, nil
    ns.settings.harvestRank = 5
    ns.DS:InvalidateMobs()
    for _, e in ipairs(ns.DS:GetMob(3245).skin) do if e[1] == 249427 then pl = e[2] end end
    assertTrue(math.abs(pl - 0.058) < 1e-6, "rank 5: 2 x 2.9% = " .. pl)
    ns.settings.harvestRank = 0
    own.s, own.ss, own.si, own.sq = keep[1], keep[2], keep[3], keep[4]
    ns.DS:InvalidateMobs()
end)

test("TradeSkillMaster price source (TSM_API.GetCustomPriceValue)", function()
    local asked
    _G.TSM_API = { GetCustomPriceValue = function(str, item) asked = str .. "|" .. item if item == "i:2770" then return 777 end end }
    ns.Prices:Flush()
    local saved = ns.settings.priceSources
    ns.settings.priceSources = { "TSM", "Vendor" }
    local v, src = ns.Prices:Get(2770)
    assertTrue(v == 777 and src == "TSM" and asked == "dbmarket|i:2770", "TSM price " .. tostring(asked))
    local v2, src2 = ns.Prices:Get(2589)
    assertTrue(src2 == "Vendor" or src2 == "none", "falls through when TSM has no price")
    local avail = table.concat(ns.Prices:Available(), ",")
    assertTrue(avail:find("TSM"), "listed as available")
    _G.TSM_API = nil
    ns.settings.priceSources = saved
    ns.Prices:Flush()
end)

test("realistic spots: no orange/red/elite mobs, risk under the caps, still finds spots", function()
    local savedLevel, savedSkills = M.level, M.skills
    local savedRs = ns.settings.ruleset
    M.level = 25
    M.skills = { { "Mining", 150, 150, 186 }, { "Skinning", 125, 150, 393 } }
    ns.Player:RefreshSkills()
    ns.settings.ruleset = "normal"
    -- the mob test
    local R = ns.Risk.REALISTIC
    assertTrue(ns.Risk.TooHard({ maxLevel = 28, rank = 0 }, 25) and not ns.Risk.TooHard({ maxLevel = 27, rank = 0 }, 25)
        and ns.Risk.TooHard({ maxLevel = 20, rank = 1 }, 25), "orange (+3) and elites are too hard, yellow (+2) is fine")
    local function check(list, label)
        for _, r in ipairs(list) do
            local d = r.danger
            assertTrue(d and (d.maxAbove or 0) <= R.above and (d.elites or 0) == 0 and d.death < R.death and d.hyper < R.hyper
                and d.gank < R.gank and 100 * (1 - (1 - d.death / 100) * (1 - d.hyper / 100)) < R.pve
                and (d.label == "Low" or d.label == "Medium"), label .. " " .. tostring(r.zoneName) .. " broke a rule")
            for _, mob in ipairs(r.mobs or {}) do assertTrue(not ns.Risk.TooHard(mob.m, 25), label .. ": too-hard mob chosen") end
            for _, w in ipairs(r.worthy or {}) do assertTrue(not ns.Risk.TooHard(w.m, 25), label .. ": too-hard mob worth killing") end
        end
    end
    for _, goal in ipairs({ "ore", "skin", "gold" }) do
        local all = ns.Finder:Run({ goal = goal, perZone = 2, realistic = false })
        local real = ns.Finder:Run({ goal = goal, perZone = 2, realistic = true })
        local hidden = ns.Finder.last.hidden
        local unrealistic = 0
        for _, r in ipairs(all) do if not ns.Risk:RealisticCheck(r) then unrealistic = unrealistic + 1 end end
        print(string.format("    %s: %d spots (%d unrealistic) -> %d realistic, %d hidden after search", goal, #all, unrealistic, #real, hidden.n))

        assertTrue(#real > 0, goal .. ": realistic spots exist at level 25")
        check(real, goal)
    end
    -- PvP ruleset: contested zones stay, but never enemy territory or right next to an enemy camp
    ns.settings.ruleset = "pvp"
    local pvp = ns.Finder:Run({ goal = "ore", perZone = 2, realistic = true })
    assertTrue(#pvp > 0, "PvP: realistic spots exist")
    for _, r in ipairs(pvp) do assertTrue(r.danger.gank < R.gank, "PvP: no very high gank risk in " .. r.zoneName) end
    ns.settings.ruleset = "normal"
    ns.settings.comboKill = "skin"
    local combo = ns.Combo:Run({ gather = "ore", perZone = 2, realistic = true })
    print(string.format("    gather + kill (mining + skinning): %d realistic, %d hidden", #combo, ns.Combo.last.hidden.n))
    assertTrue(#combo > 0, "realistic Gather + Kill spots exist")
    check(combo, "combo")
    ns.settings.comboKill = "all"
    -- the setting drives the default, and the empty state explains what was hidden
    SlashCmdList.FORAGER("realistic on")
    assertTrue(ns.settings.realistic == true, "/forage realistic on")
    ns.Finder:Run({ goal = "ore", perZone = 1 })
    assertTrue(ns.Finder.last.opts.realistic == true, "setting on -> realistic search")
    assertTrue(ns.Risk.HiddenText({ n = 3, reasons = { ["mobs up to X levels above you"] = 2, elites = 1 } })
        == "Realistic spots hid 3 spots: mobs too high for you (2), elites (1).", "hidden text")
    if not ns.Main.frame then ns.Main:Toggle() end
    ns.Main:SelectTabByKey("farm")
    ns.Main:SelectTabByKey("combo")
    ns.settings.realistic = false
    ns.settings.ruleset = savedRs
    M.level, M.skills = savedLevel, savedSkills
    ns.Player:RefreshSkills()
end)

test("item tooltips: game tooltip + Forager price on every item the window shows", function()
    local function reset() M.tooltipLines, M.tooltipItem = {}, nil end
    local function has(text) for _, l in ipairs(M.tooltipLines) do if l:find(text, 1, true) then return true end end end
    -- helper: the game's tooltip, then Forager's price and the extra lines
    reset()
    ns.UI.ItemTip(UIParent, 2770, { { "Per hour here", "12.0" } })
    assertTrue(M.tooltipItem == 2770 and has("Per hour here"), "SetItemByID + extra lines")
    assertTrue(has("Forager price"), "Forager price line")
    -- non-items get a plain tooltip
    local id, extra = ns.UI.LootTipInfo({ id = 2770, perHour = 12, value = 3000 })
    assertTrue(id == 2770 and extra[1][1] == "Per hour here", "loot entry -> item")
    assertTrue(type(ns.UI.LootTipInfo({ coin = true, value = 500 })) == "table", "coin -> plain tooltip")
    assertTrue(type(ns.UI.LootTipInfo({ greens = 2, perHour = 1, value = 900 })) == "table", "greens -> plain tooltip")
    -- every hover area that holds an item in the open window shows that item's tooltip
    local function hoverAll(field)
        local n = 0
        for _, f in ipairs(M.allFrames) do
            local v = f[field]
            if v and f._shown and f._scripts.OnEnter then
                local want = v.id
                reset()
                f._scripts.OnEnter(f)
                if want then
                    assertTrue(M.tooltipItem == want, field .. " hover shows item " .. tostring(want))
                    n = n + 1
                else
                    assertTrue(#M.tooltipLines > 0, field .. " hover shows a plain tooltip")
                end
            end
        end
        return n
    end
    if not ns.Main.frame then ns.Main:Toggle() end
    ns.char.goal = "ore"
    ns.Main:SelectTabByKey("farm")
    local cards, rows = hoverAll("loot"), hoverAll("it")
    ns.Main:SelectTabByKey("combo")
    local slots = hoverAll("it")
    print(string.format("    farm card icons %d, farm/combo loot rows %d + %d", cards, rows, slots))
    assertTrue(cards > 0 and rows > 0, "farm cards and rows show item tooltips")
    -- the item suggestions list shows item tooltips too
    reset()
    ns.UI.OpenList(UIParent, { { text = "Copper Ore", value = {}, itemID = 2770 } }, function() end, 200)
    local popup = _G.ForagerDropdownPopup
    popup.buttons[1]._scripts.OnEnter(popup.buttons[1])
    assertTrue(M.tooltipItem == 2770, "suggestion hover")
    ns.UI.CloseList()
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
        assertTrue(math.abs(r.nodeGold + r.skinGold + r.lootGold - r.perHour) < 1, "gold split adds up (gathering + skins + loot)")
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

test("gather + kill with skinning: skins counted only when you can skin, skin-only mode, skill-ups", function()
    -- character: Mining (assumed) + Skinning 40 (mock), level 12
    local res = ns.Combo:Run({ gather = "ore", perZone = 2, killFor = "all", mode = "gold" })
    assertTrue(#res > 0, "results")
    for _, r in ipairs(res) do
        for _, m in ipairs(r.worthy) do
            if m.skinOK then
                assertTrue(m.req <= 40, "skinnable within skill")
            else
                assertTrue(m.skinG == 0, "no skin value without the skill")
            end
        end
    end
    -- skinnable only: every mob considered is one you can skin
    local skinRes = ns.Combo:Run({ gather = "ore", perZone = 2, killFor = "skin", mode = "gold" })
    assertTrue(#skinRes > 0, "skin-only results")
    local anySkin = 0
    for _, r in ipairs(skinRes) do
        assertTrue(r.goal == "combo:ore:skin", "goal key")
        for _, m in ipairs(r.worthy) do assertTrue(m.skinOK, "worthy mob skinnable") anySkin = anySkin + 1 end
        for _, m in ipairs(r.skipped) do assertTrue(m.skinOK, "skipped mob skinnable") end
        assertTrue(r.skinsPerHour <= r.killsPerHour + 1e-6, "skins <= kills")
    end
    assertTrue(ns.Finder:GoalInfo("combo:ore:skin").label == "Mining + skinning", "label")
    -- no skinning skill at all: skins never counted
    local noSkin = ns.Combo:Run({ gather = "ore", perZone = 1, killFor = "all", mode = "gold", skills = { ore = 300 } })
    for _, r in ipairs(noSkin) do assertTrue(r.skinGold == 0 and r.skinsPerHour == 0, "no skins without Skinning") end
    -- slower skinning never helps
    local zone = skinRes[1].uiMap
    local old = ns.settings.comboSkinSeconds
    ns.settings.comboSkinSeconds = 0
    local quick = ns.Combo:Run({ gather = "ore", zones = { zone }, perZone = 1, killFor = "skin", mode = "gold" })[1]
    ns.settings.comboSkinSeconds = 10
    local slow = ns.Combo:Run({ gather = "ore", zones = { zone }, perZone = 1, killFor = "skin", mode = "gold" })[1]
    ns.settings.comboSkinSeconds = old
    assertTrue(quick.perHour + 1e-6 >= slow.perHour, "skin time monotonic")
    -- skill-ups mode: gathering + skinning skill-ups, best-ratio property in skill units
    local sk = ns.Combo:Run({ gather = "herb", perZone = 2, killFor = "skin", mode = "skill" })
    assertTrue(#sk > 0, "skill results")
    for _, r in ipairs(sk) do
        assertTrue(r.mode == "skill" and math.abs(r.nodeSU + r.skinSU - r.perHour) < 0.01, "skill split adds up")
        local avg = r.perHour / 3600
        for _, m in ipairs(r.worthy) do assertTrue(m.perMin / 60 >= avg - 1e-9 and m.su > 0, "worthy skill mob") end
    end
    assertTrue(ns.Main:RateText(sk[1]):find("skill%-ups"), "rate text")
    print(string.format("       skin combo top: %s %s/h (ore %s + skins %s + loot %s), %d skinnable mobs worth it; skill top %s: %.0f skill-ups/h",
        skinRes[1].zoneName, ns.Money(skinRes[1].perHour, true), ns.Money(skinRes[1].nodeGold, true), ns.Money(skinRes[1].skinGold, true),
        ns.Money(skinRes[1].lootGold, true), anySkin, sk[1].zoneName, sk[1].perHour))
    -- UI renders both modes
    ns.settings.comboKill, ns.settings.comboMode = "skin", "skill"
    ns.Main:Toggle("combo")
    ns.Main.tabs[2].panel:Run()
    ns.settings.comboKill, ns.settings.comboMode = "all", "gold"
    ns.Main.tabs[2].panel:Run()
    ns.Main.frame:Hide()
    for _, l in ipairs(M.printed) do assertTrue(not tostring(l):find("Gather %+ Kill error") and not tostring(l):find("UI error"), tostring(l)) end
end)

test("risk: gank by ruleset/zone/settlements, death, hyperspawn, deaths learned, filter", function()
    -- ruleset detection: unflagged in a contested zone proves Normal
    ns.db.ruleset, ns.db.rulesetPvpZones = nil, nil
    local rs, guess = ns.Risk:Ruleset()
    assertTrue(rs == "pvp" and guess, "unknown -> PvP assumed")
    M.zonePvp, M.pvpFlag = "contested", true
    M.mapID = 1434 ns.Risk:LearnRuleset()
    M.mapID = 1424 ns.Risk:LearnRuleset()
    assertTrue(ns.db.ruleset == "pvp", "flagged in two contested zones -> PvP")
    M.pvpFlag = false
    ns.Risk:LearnRuleset()
    assertTrue(ns.db.ruleset == "normal", "unflagged in contested -> Normal")
    M.zonePvp, M.pvpFlag = nil, nil
    ns.db.ruleset = "pvp"
    -- zones: friendly (Elwynn) vs contested (Stranglethorn, Horde camp nearby for an Alliance player)
    local function at(uiMap, rect) local r = { uiMap = uiMap, rect = rect } ns.Risk:Assess(r) return r.danger end
    local elwynn = at(1429, { 0.40, 0.60, 0.48, 0.70 })
    local stvCamp = at(1434, { 0.29, 0.25, 0.35, 0.32 }) -- around Grom'gol
    local stvFar = at(1434, { 0.60, 0.60, 0.66, 0.66 })
    assertTrue(elwynn.gank <= 5 and elwynn.label == "Low", string.format("own low-level zone: low risk (gank %s death %s hyper %s %s: %s)",
        tostring(elwynn.gank), tostring(elwynn.death), tostring(elwynn.hyper), tostring(elwynn.label), table.concat(elwynn.why.death or {}, "; ") .. " | " .. table.concat(elwynn.why.hyper or {}, "; ")))
    assertTrue(stvCamp.gank > stvFar.gank and stvCamp.gank >= 70, "enemy flight path nearby raises gank risk")
    assertTrue(#stvCamp.why.gank >= 2, "reasons given")
    ns.settings.ruleset = "normal"
    assertTrue(at(1434, { 0.29, 0.25, 0.35, 0.32 }).gank == 0, "Normal ruleset: no gank risk")
    ns.settings.ruleset = "auto"
    -- death: higher-level area for a level-12 character
    local best = ns.Finder:Run({ goal = "gold", zones = { 1434 }, perZone = 1, anyLevel = true })[1]
    assertTrue(best and best.danger.death >= 50, "mobs far above your level: " .. tostring(best and best.danger.death))
    -- your deaths raise the death risk there
    local before = at(1429, { 0.40, 0.60, 0.48, 0.70 }).death
    M.mapID, M.pos = 1429, { 0.44, 0.65 }
    M.Fire("PLAYER_DEAD")
    M.Fire("PLAYER_DEAD")
    local after = at(1429, { 0.40, 0.60, 0.48, 0.70 })
    assertTrue(after.death >= before + 25, "two deaths logged")
    -- every finder / combo result carries a risk; overall combines the parts
    local res = ns.Finder:Run({ goal = "gold", perZone = 1, anyLevel = true })
    for _, r in ipairs(res) do
        local d = r.danger
        assertTrue(d and d.score >= math.max(d.gank, d.death, d.hyper) - 1e-6 and d.score <= 100, "combined score")
        assertTrue(ns.Risk:Short(r):find("Risk:"), "short text")
    end
    for _, r in ipairs(ns.Combo:Run({ gather = "ore", perZone = 1 })) do assertTrue(r.danger, "combo risk") end
    -- filter
    ns.settings.maxRisk = "low"
    local low = ns.Finder:Run({ goal = "gold", perZone = 1, anyLevel = true })
    for _, r in ipairs(low) do assertTrue(r.danger.score < 20, "only low risk") end
    assertTrue(#low < #res, "filter removed riskier spots")
    ns.settings.maxRisk = "any"
    -- UI shows it without errors
    ns.Main:Toggle("farm")
    ns.Main:SelectTabByKey("combo")
    ns.Main.frame:Hide()
    for _, l in ipairs(M.printed) do assertTrue(not tostring(l):find("UI error") and not tostring(l):find(" error:"), tostring(l)) end
    print(string.format("       risk: Elwynn %s (%.0f) · STV by Grom'gol %s (%.0f: gank %.0f, death %.0f, hyper %.0f)", elwynn.label, elwynn.score,
        stvCamp.label, stvCamp.score, stvCamp.gank, stvCamp.death, stvCamp.hyper))
end)

test("settings migration to v6 (route only, measured times, TSM, seeded yields, spawn data)", function()
    local savedDB, savedBackup = ForagerDB, ForagerBackupDB
    ForagerBackupDB = nil
    ForagerDB = { version = 2, settings = { worldNodes = "goal", minimapNodes = "goal", areaAlpha = 0.25, routeAlpha = 0.9, pinScale = 1.3,
        showArea = true, gamePin = true, tomtom = true, hiddenTypes = { ["1"] = true }, gatherSeconds = 3,
        priceSources = { "Auctionator", "AuctionTrends", "Vendor" } },
        nodes = { [1429] = { a = { t = 1, x = 0.5, y = 0.5 }, b = { t = 34, c = 6, y = { [2770] = 9, [249391] = 1 } } } } }
    ns:InitDB()
    local st = ns.settings
    assertTrue(ns.db.version == 6 and not ns.safeMode, "migrated")
    assertTrue(st.spawnData == true and st.harvestRank == 0 and st.netGold and st.calibrate, "2.0 settings")
    assertTrue(st.gatherSeconds == 1, "flat gather seconds become extra seconds per node")
    assertTrue(table.concat(st.priceSources, ",") == "Auctionator,AuctionTrends,TSM,Vendor", "TSM before vendor")
    local seeded = ns.db.learn.nodes[34]
    assertTrue(seeded and seeded.n == 6 and seeded.v == 2 and seeded.y[249391] == 1, "old yields seed learning (6 loots / 3 taps)")
    assertTrue(st.worldNodes == nil and st.minimapNodes == nil and st.farmMinimap == nil and st.pinScale == nil and st.hiddenTypes == nil, "pin settings removed")
    assertTrue(st.showRoute and st.routeMinimap == "next" and not st.showArea and not st.gamePin and not st.tomtom, "route only")
    assertTrue(st.areaAlpha == 0.12 and st.routeAlpha == 0.8, "styles")
    ForagerDB, ForagerBackupDB = savedDB, savedBackup
    ns:InitDB()
    assertTrue(ns.db.version == 6, "restored")
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

test("spawn data: live share per zone/type, respawn per mob, flat share when off", function()
    local copper = ns.NodeTypes[34]
    local z = ns.Zones[1429]
    local want = (z.shares and z.shares[34]) or copper.share
    assertTrue(want and want > 0 and want < 1, "copper has spawn-pool share")
    assertTrue(math.abs(ns.DS:LiveShare(copper, 1429) - want) < 1e-9, "zone share used")
    assertTrue(ns.NodeTypes[1].respawn and ns.NodeTypes[1].respawn > 0, "node respawn")
    local m = ns.DS:GetMob(6) -- Kobold Vermin: 3 min respawn in CMaNGOS
    assertTrue(m.respawn == 180 and ns.DS:MobRespawn(m, 300) == 180, "mob respawn " .. tostring(m.respawn))
    ns.settings.spawnData = false
    assertTrue(ns.DS:LiveShare(copper, 1429) == ns.settings.activeFraction and ns.DS:MobRespawn(m, 300) == 300, "off: flat")
    ns.settings.spawnData = true
    local res = ns.Finder:Run({ goal = "ore", zones = { 1426 }, perZone = 1 })
    local r = res[1]
    assertTrue(r and r.why:find("live per loop"), "ore result")
end)

test("fights: seconds per kill and downtime measured, blended into kills per hour", function()
    local f = ns.Learn.Store().fight
    f.n, f.f, f.dn, f.d = 0, 0, 0, 0
    local function fightOnce(id, secs, gap)
        M.Fire("PLAYER_REGEN_DISABLED")
        M.now = M.now + secs
        M.loot = { { link = "|Hitem:2589::|h[Linen Cloth]|h", qty = 1, sources = { "Creature-0-1-0-1-3245-0F" .. id, 1 } } }
        M.Fire("LOOT_READY") M.Fire("LOOT_CLOSED")
        M.Fire("PLAYER_REGEN_ENABLED")
        M.RunTimers(31)
        M.now = M.now + gap
    end
    for i = 1, 40 do fightOnce(i, 20, 10) end
    assertTrue(math.abs(f.n - 40) < 0.01 and math.abs(f.f / f.n - 20) < 0.5, "fight seconds per kill " .. f.f / math.max(1, f.n))
    assertTrue(f.dn >= 38 and math.abs(f.d / f.dn - 41) < 2, "downtime between fights " .. (f.d / math.max(1, f.dn)))
    local kph, src = ns.Learn:KillsPerHour()
    local own = 3600 / (f.f / f.n + f.d / f.dn)
    local w = f.dn / (f.dn + 30)
    assertTrue(math.abs(kph - (w * own + (1 - w) * ns.settings.killsPerHour)) < 0.01, "blend " .. kph .. " " .. src)
    local ks = ns.Learn:KillSeconds()
    assertTrue(ks < ns.settings.comboKillSeconds, "seconds per kill moves toward yours " .. ks)
    f.n, f.f, f.dn, f.d = 0, 0, 0, 0
end)

test("travel speed measured on foot and mounted; idle/AFK pauses the session clock", function()
    local sp = ns.Learn.Store().speed
    sp.foot, sp.mount = nil, nil
    M.speed, M.mounted = 11.2, true
    for _ = 1, 35 do ns.Capture:Tick() end
    assertTrue(math.abs((ns.Learn:Speed(true)) - 11.2) < 0.01 and not ns.Learn:Speed(false), "mounted speed")
    local lvl = M.level
    M.level = 45
    assertTrue(math.abs(ns.Player:Speed() - 11.2) < 0.01, "route timing uses measured mount speed")
    M.level = lvl
    M.speed, M.mounted = 0, false
    -- session clock: active time only
    ns.Capture:ResetSession()
    local sess = ns.Capture.session
    ns.Capture:AddValue(1000, nil, 0)
    ns.Capture:Activity()
    M.now = M.now + 2 ns.Capture:Tick()
    M.now = M.now + 2 ns.Capture:Tick()
    local a1 = sess.active
    assertTrue(a1 >= 3.9, "active " .. a1)
    M.afk = true
    M.now = M.now + 2 ns.Capture:Tick()
    assertTrue(sess.active == a1 and sess.paused, "AFK pauses")
    M.afk = false
    M.now = M.now + 400 ns.Capture:Tick() -- long gap without activity: idle
    M.now = M.now + 2 ns.Capture:Tick()
    assertTrue(sess.active == a1, "idle pauses")
    ns.Capture:ResetSession()
    sp.foot, sp.mount = nil, nil
end)

test("net gold: AH cut on AH-priced items, repairs per kill, calibration from farm sessions", function()
    local rep = ns.Learn.Store().repair
    rep.c, rep.k = 0, 0
    -- a repair after 100 kills costing 50s
    ns.db.stats.repairMark = ns.db.stats.kills or 0
    ns.db.stats.kills = (ns.db.stats.kills or 0) + 100
    M.repairCost = 5000
    M.Fire("MERCHANT_SHOW")
    M.repairCost = 0
    M.Fire("UPDATE_INVENTORY_DURABILITY")
    M.Fire("MERCHANT_CLOSED")
    local rpk, k = ns.Learn:RepairPerKill()
    assertTrue(k == 100 and math.abs(rpk - 50) < 1e-9, "repair per kill " .. rpk)
    -- an AH-priced item (Auctionator) and a vendor-priced one
    _G.Auctionator = { API = { v1 = { GetAuctionPriceByItemID = function(_, id) if id == 2589 then return 100 end end } } }
    ns.Prices:Flush()
    local r = { uiMap = 1429, goal = "cloth", source = "mob", mode = "gold", rect = { 0.1, 0.1, 0.2, 0.2 }, unitsPerHour = 60,
        perHour = 6000 + 3000, items = { { id = 2589, perHour = 60, value = 6000 }, { coin = true, perHour = 60, value = 3000 } } }
    ns.Net:Apply(r)
    assertTrue(r.estGross == 9000 and math.abs(r.ahCut - 300) < 1e-9 and math.abs(r.repairs - 3000) < 1e-9, "cut and repairs")
    assertTrue(math.abs(r.perHour - (9000 - 300 - 3000)) < 1e-9 and r.items[1].value == 5700, "net " .. r.perHour)
    -- calibration: 2 h at a spot that made 80% of its estimate
    ns.Learn.Store().calib = {}
    ns.Learn:AddFarm(ns.Learn.FarmKey(r), ns.Learn.FarmGroup(r), 9000, 7200, 2)
    local f, h, src = ns.Learn:Calibration(ns.Learn.FarmKey(r), ns.Learn.FarmGroup(r))
    assertTrue(src == "spot" and math.abs(f - (0.8 * 2 + 1) / 3) < 1e-9 and h == 2, "calibration " .. f)
    local r2 = { uiMap = 1429, goal = "cloth", source = "mob", mode = "gold", rect = r.rect, unitsPerHour = 60, perHour = 9000,
        items = { { id = 2589, perHour = 60, value = 6000 }, { coin = true, perHour = 60, value = 3000 } } }
    ns.Net:Apply(r2)
    assertTrue(r2.calib and math.abs(r2.perHour - (9000 * f - 6000 * f * 0.05 - 3000)) < 1e-6, "calibrated net " .. r2.perHour)
    assertTrue(#ns.Net:Lines(r2) >= 4, "explained")
    -- another cloth spot uses the group factor once there is an hour
    local f2, _, src2 = ns.Learn:Calibration("other", ns.Learn.FarmGroup(r))
    assertTrue(src2 == "type" and math.abs(f2 - f) < 1e-9, "group calibration")
    -- farm session flow: 10+ active minutes books a calibration entry
    ns.Learn.Store().calib = {}
    local best = ns.Finder:Run({ goal = "herb", zones = { 1429 }, perZone = 1 })[1]
    ns.Route:Start(best)
    local sess = ns.Capture.session
    assertTrue(sess.farm == ns.Learn.FarmKey(best) and sess.est and sess.est > 0, "session tied to the farm")
    sess.active, sess.value = 700, 5000
    ns.Route:Stop()
    assertTrue(ns.Learn.Store().calib[ns.Learn.FarmKey(best)], "booked")
    ns.Learn.Store().calib = {}
    rep.c, rep.k = 0, 0
    _G.Auctionator = nil
    ns.Prices:Flush()
end)

test("tracking: ready check, one-click fix, herb/ore switcher, re-track after death, tools", function()
    M.skills = { { "Herbalism", 50, 75, 182 }, { "Mining", 60, 75, 186 }, { "Skinning", 40, 75, 393 } }
    _G.GetProfessions = function() return 1, 2, 3, nil, nil end
    ns.Player:RefreshSkills()
    for _, t in ipairs(M.tracking) do t.active = false end
    M.bags = {}
    local r = { source = "combo", gather = "both", killFor = "skin", uiMap = 1429, route = { points = {} }, rect = { 0.1, 0.1, 0.2, 0.2 }, goal = "combo:both" }
    local issues = ns.Tracking:Issues(r)
    local text = ""
    for _, i in ipairs(issues) do text = text .. i.text .. ";" end
    assertTrue(text:find("Find Herbs is off") and text:find("Mining Pick") and text:find("Skinning Knife"), text)
    issues[1].fix()
    assertTrue(ns.Tracking:Active() == "herb", "fix turned Find Herbs on")
    -- tools in bags (a Keen Skinning Knife counts by name)
    M.bags = { 2901, 999001 }
    M.Fire("BAG_UPDATE_DELAYED")
    assertTrue(#ns.Tracking:Issues(r) == 0, "ready")
    -- switcher flips only while moving, out of combat, on a herb + ore route
    ns.Route.active = { result = r, route = { points = {} }, uiMap = 1429, index = 1, loops = 0, visited = 0, cool = {} }
    ns.Tracking:SwitchTick()
    assertTrue(ns.Tracking:Active() == "herb", "standing still: no flip")
    M.speed = 7
    ns.Tracking:SwitchTick()
    assertTrue(ns.Tracking:Active() == "ore", "moving: flipped to minerals")
    M.inCombat = true
    ns.Tracking:SwitchTick()
    assertTrue(ns.Tracking:Active() == "ore", "combat: no flip")
    M.inCombat, M.speed = false, 0
    ns.Route.active = nil
    -- dying clears tracking; it comes back when alive
    M.Fire("MINIMAP_UPDATE_TRACKING")
    M.Fire("PLAYER_DEAD")
    for _, t in ipairs(M.tracking) do t.active = false end
    M.dead = true
    M.Fire("PLAYER_ALIVE")
    M.RunTimers(2)
    assertTrue(ns.Tracking:Active() == nil, "still a ghost: nothing yet")
    M.dead = false
    M.Fire("PLAYER_UNGHOST")
    M.RunTimers(2)
    assertTrue(ns.Tracking:Active() == "ore", "re-tracked after death")
    M.skills = { { "Herbalism", 50, 75, 182 }, { "Skinning", 40, 75, 393 } }
    _G.GetProfessions = function() return 1, 2, nil, nil, nil end
    ns.Player:RefreshSkills()
    M.bags = {}
end)

test("route: stops you gathered cool down for the node's respawn and are skipped", function()
    local r = ns.Finder:Run({ goal = "herb", zones = { 1429 }, perZone = 1 })[1]
    ns.Route:Start(r)
    local a = ns.Route.active
    local n = #a.route.points
    assertTrue(n >= 3, "route")
    local i = a.index
    local p = a.route.points[i]
    ns:Fire("FORAGER_NODE_GATHERED", 1429, p.x, p.y, p.t)
    assertTrue(ns.Route:Cooling(i) and ns.Route:CoolingCount() >= 1, "cooling")
    M.pos = { 0.99, 0.99 }
    ns.Route:Update()
    assertTrue(a.index ~= i, "cooling stop skipped")
    M.now = M.now + 4000
    assertTrue(not ns.Route:Cooling(i), "respawned")
    ns.Route:Stop()
    M.pos = { 0.40, 0.60 }
end)

test("hotfix notes, Hardcore profile, herb seeds, error log, pruning", function()
    local stv = ns.Finder:Run({ goal = "gold", zones = { 1434 }, perZone = 1, anyLevel = true })
    assertTrue(stv[1] and stv[1].note and stv[1].note:find("Hotfix"), "STV hotfix note")
    -- Hardcore: stricter Realistic
    ns.Risk.hc = nil
    M.hardcore = true
    assertTrue(ns.Risk:IsHardcore() and ns.Risk:Profile().above == 1, "hardcore profile")
    assertTrue(ns.Risk.TooHard({ rank = 0, maxLevel = M.level + 2 }, M.level), "level + 2 too hard in Hardcore")
    M.hardcore = false
    ns.Risk.hc = nil
    assertTrue(not ns.Risk.TooHard({ rank = 0, maxLevel = M.level + 2 }, M.level), "fine on normal realms")
    -- seeds: known items with vendor prices, tiers resolved to herb names
    assertTrue(ns.DS:ItemVendor(268418) == 115 and ns.DS:ItemName(268415):find("Herb Seeds"), "seed items")
    assertTrue(ns.HerbSeeds[1].from.Peacebloom and ns.HerbSeeds[1].from.Silverleaf and ns.HerbSeeds[2].from.Briarthorn, "seed tiers")
    local found = false
    for _, s2 in ipairs(ns.Finder:Suggest("herb seeds", 20)) do if s2.id == 268416 then found = true end end
    assertTrue(found, "seeds are searchable")
    -- error log: same message counted once
    ns.db.errors = {}
    ns:Error("x", "boom") ns:Error("x", "boom")
    assertTrue(#ns.db.errors == 1 and ns.db.errors[1].n == 2, "deduped")
    ns.Slash("errors")
    ns.Slash("errors clear")
    assertTrue(#ns.db.errors == 0, "cleared")
    -- pruning: empty mobs and stale shared nodes go
    ns.db.mobs[999999] = {}
    ns.db.shared[1429] = ns.db.shared[1429] or {}
    ns.db.shared[1429]["0a00a0"] = { t = 1, c = 1, l = time() - 100 * 86400 }
    local removed = ns:Prune()
    assertTrue(removed >= 2 and not ns.db.mobs[999999] and not (ns.db.shared[1429] and ns.db.shared[1429]["0a00a0"]), "pruned " .. removed)
end)

test("time-sliced jobs and the result cache", function()
    local got
    ns.RunJob("t", function() for _ = 1, 3 do ns.Yield() end return 42 end, function(v) got = v end)
    ns.DrainJobs()
    assertTrue(got == 42, "job result")
    local o1 = ns.Finder:Run({ goal = "herb", zones = { 1429 }, perZone = 1 })
    local o2 = ns.Finder:Run({ goal = "herb", zones = { 1429 }, perZone = 1 })
    assertTrue(o1 == o2, "cache hit")
    ns.Touch()
    local o3 = ns.Finder:Run({ goal = "herb", zones = { 1429 }, perZone = 1 })
    assertTrue(o3 ~= o1, "new data: searched again")
    ns.DS:Flush()
    local nz, mz, mc = ns.DS:CacheSizes()
    assertTrue(nz == 0 and mz == 0 and mc == 0, "flushed")
end)

test("item tooltips: best spot in the background, Alt+Shift+click opens the farm", function()
    local post = M.postCalls[0]
    assertTrue(post, "item post-call registered")
    local lines = {}
    local tt = GameTooltip
    local add = tt.AddLine
    tt.AddLine = function(self, l) lines[#lines + 1] = l end
    GameTooltip._shown = true
    post(tt, { id = 2447 }) -- Peacebloom
    assertTrue(#lines >= 1 and lines[#lines]:find("Alt%+Shift"), "hint line")
    M.RunTimers(1)
    ns.DrainJobs()
    lines = {}
    post(tt, { id = 2447 })
    local any = false
    for _, l in ipairs(lines) do if l:find("best spot") then any = true end end
    assertTrue(any, "best spot shown: " .. table.concat(lines, " | "))
    lines = {}
    post(tt, { id = 6948 }) -- Hearthstone: not farmable
    assertTrue(#lines == 0, "no lines on items Forager can't farm")
    tt.AddLine = add
    M.alt, M.shift = true, true
    HandleModifiedItemClick("|cffffffff|Hitem:2770::::::::|h[Copper Ore]|h|r")
    M.alt, M.shift = false, false
    assertTrue(ns.char.goal == "item:2770" and ns.Main.frame:IsShown(), "farm tab on the item")
    ns.Main.frame:Hide()
    ns.char.goal = nil
end)

test("self-test, settings pages and localisation tables", function()
    local fails, rows = ns.SelfTest()
    assertTrue(fails == 0, table.concat(rows, "\n"))
    ns.Main:Toggle("settings")
    ns.Main.frame:Hide()
    for _, l in ipairs(M.printed) do assertTrue(not tostring(l):find("UI error"), tostring(l)) end
    assertTrue(ns.L["Farm"] == "Farm", "English falls back to the key")
    for loc, t in pairs(ns.LocaleTables) do
        local n = 0
        for k, v in pairs(t) do
            assertTrue(type(k) == "string" and type(v) == "string" and v ~= "", loc .. " " .. tostring(k))
            -- format strings keep their placeholders
            local _, a = k:gsub("%%[ds%.%d]+", "")
            local _, b = v:gsub("%%[ds%.%d]+", "")
            assertTrue(a == b, loc .. " placeholders: " .. k)
            n = n + 1
        end
        assertTrue(n >= 60, loc .. " has " .. n .. " strings")
    end
end)

test("new zones: trace mobs, zone levels, no node data said plainly, your loot fills in values", function()
    -- zones: published ranges, or the traced mob levels where sources disagree; the battleground is out
    assertTrue(ns.Zones[2548] and ns.Zones[2548].min == 35 and ns.Zones[2652].min == 40 and ns.Zones[2482].min == 56, "levels")
    assertTrue(ns.Zones[2524] == nil, "Darkspear Islands (battleground) not a farming zone")
    assertTrue(ns.DS:HasZoneNodeData(1429) and not ns.DS:HasZoneNodeData(2548), "node data flag")
    -- Riverglades mobs from QuestieDB traces: levels, spawns, no loot table
    local spawns = ns.DS:GetZoneMobs(2548)
    local croc = ns.DS:GetMob(259046)
    assertTrue(spawns[259046] and #spawns[259046] >= 20, "crocolisk spawns")
    assertTrue(croc and croc.minLevel == 38 and croc.noLoot and not croc.lootSrc, "new NPC without loot data")
    local hostile = 0
    for npc in pairs(spawns) do local m = ns.DS:GetMob(npc) if m and not ns.DS:IsFriendly(m) then hostile = hostile + 1 end end
    assertTrue(hostile >= 50, "hostile mob types in Riverglades: " .. hostile)
    -- risk works there
    local lvl = M.level
    M.level = 40
    local r = { uiMap = 2548, rect = { 0.40, 0.40, 0.50, 0.50 } }
    ns.Risk:Assess(r)
    assertTrue(r.danger and r.danger.label, "risk in a new zone")
    M.level = lvl
    -- loot two crocolisk corpses: items with quantities and coin are learned, the mob gets a value
    ns.db.mobs[259046] = nil
    for i = 1, 2 do
        M.loot = { { link = "|Hitem:5471::|h[Stringy Wolf Meat]|h", qty = 2, sources = { "Creature-0-1-0-1-259046-0A" .. i, 1 } } }
        M.Fire("LOOT_READY")
        M.money = (M.money or 0) + 150
        M.Fire("PLAYER_MONEY")
        M.Fire("LOOT_CLOSED")
    end
    ns.DS:InvalidateMobs()
    croc = ns.DS:GetMob(259046)
    local own = ns.db.mobs[259046]
    assertTrue(own.n == 2 and own.iq[5471] == 4 and math.abs(own.c - 300) < 1e-9, "quantities and coin recorded")
    local meat
    for _, e in ipairs(croc.farm) do if e[1] == 5471 then meat = e[2] end end
    assertTrue(meat == 2 and croc.copper == 150 and croc.lootSrc, "your loot as it is (no table to blend with)")
    assertTrue(ns.Finder:MobValue(croc, "gold", {}, 40) > 0, "valued")
    local camp = ns.Finder:MobResult(259046, 2548)
    assertTrue(camp and camp.perHour > 0 and camp.route, "farm this mob in Riverglades")
    -- Classic mobs: your drops (quantities) are blended with the bundled table, gear items left to the grades
    local base = ns.DS:GetMob(426)
    local baseCloth
    for _, e in ipairs(base.farm) do if e[1] == 2589 then baseCloth = e[2] end end
    ns.db.mobs[426] = { k = 30, n = 30, i = { [2589] = 30 }, iq = { [2589] = 60 }, q = {}, c = 0, cn = 0 }
    ns.DS:InvalidateMobs()
    local cloth
    for _, e in ipairs(ns.DS:GetMob(426).farm) do if e[1] == 2589 then cloth = e[2] end end
    assertTrue(math.abs(cloth - (0.5 * 2 + 0.5 * baseCloth)) < 1e-9, "blended linen " .. cloth)
    ns.db.mobs[426], ns.db.mobs[259046] = nil, nil
    ns.DS:InvalidateMobs()
    -- the UI says why a new zone has no nodes
    local items = ns.Main.ZoneItems(false, false)
    local tagged = false
    for _, it in ipairs(items) do if it.value == 2548 and it.text:find("new") then tagged = true end end
    assertTrue(tagged, "zone list marks new zones")
    assertTrue(string.format(ns.DS.NO_NODE_DATA, "Riverglades"):find("fills in"), "explanation")
end)

test("free roam: arrow to the nearest likely node, checked/gathered spots skipped, minimap dots lock on and are saved", function()
    local HBD = LibStub("HereBeDragons-2.0")
    M.skills = { { "Herbalism", 50, 75, 182 }, { "Mining", 60, 75, 186 } }
    _G.GetProfessions = function() return 1, 2, nil, nil, nil end
    ns.Player:RefreshSkills()
    M.mapID, M.pos = 1429, { 0.40, 0.60 }
    ns.Route:Stop()
    assertTrue(ns.Roam:Start("ore"), "started")
    local a = ns.Roam:Active()
    assertTrue(a and a.kind == "ore" and ns.Route.active == a and a.result.source == "roam", "runs as a farm without route points")
    assertTrue(ns.Finder:GoalInfo(a.result.goal).label:find("Mining"), "goal label")
    -- target: the nearest copper/tin spawn point you can mine, not checked yet
    local tg, d = ns.Roam:Target()
    assertTrue(tg and d and d > 0, "a target")
    local t = ns.DS:GetType(tg.t)
    assertTrue(t.kind == "ore" and (t.skill or 0) <= 60, "ore you can mine: " .. t.name)
    -- the HUD points at it
    ns.settings.hud = true
    ns.Overlay.UpdateArrow()
    -- walking up to it: checked, the arrow moves on
    M.pos = { tg.x, tg.y }
    ns.Roam:Update(true)
    local tg2 = ns.Roam:Target()
    assertTrue(a.nChecked >= 1 and tg2 and tg2.key ~= tg.key, "reached spot is checked, next one picked")
    -- gathering a node: spots around it cool down
    ns:Fire("FORAGER_NODE_GATHERED", 1429, tg2.x, tg2.y, tg2.t)
    assertTrue(a.gathered == 1 and a.checked[tg2.key], "gathered spot cooling")
    -- hover a dot on the minimap: 35 px right of the centre on a 140 px minimap = 100 yd east
    Minimap:SetSize(140, 140)
    local cx, cy = Minimap:GetCenter()
    local getCursor = _G.GetCursorPosition
    _G.GetCursorPosition = function() return cx + 35, cy end
    _G.GameTooltipTextLeft1 = { GetText = function() return "|cffffffffCopper Vein|r\nMailbox" end }
    local nl = GameTooltip.NumLines
    GameTooltip.NumLines = function() return 1 end
    local before = 0
    for _ in pairs(ns.db.nodes[1429] or {}) do before = before + 1 end
    ns.Detect:OnMinimapTooltip()
    local lock = a.lock
    assertTrue(lock and lock.locked and ns.DS:GetType(lock.t).name == "Copper Vein", "locked on to the hovered dot")
    local px, py = M.pos[1], M.pos[2]
    local dist = ns.Player:Distance(1429, px, py, lock.x, lock.y)
    assertTrue(lock.x > px and math.abs(lock.y - py) < 0.002 and math.abs(dist - 100) < 2, string.format("100 yd east: %.1f yd", dist))
    local after = 0
    for _ in pairs(ns.db.nodes[1429]) do after = after + 1 end
    assertTrue(after == before + 1, "saved as a spawn point")
    local key = ns.EncodeXY(lock.x, lock.y)
    local rec = ns.db.nodes[1429][key]
    assertTrue(rec and rec.s == "seen" and rec.c == 0, "seen, no gathers or yields")
    assertTrue(ns.Roam:Target() == lock, "the arrow follows the dot")
    ns.Detect:OnMinimapTooltip()
    assertTrue(a.seen == 1, "the same dot counts once")
    _G.GetCursorPosition = getCursor
    GameTooltip.NumLines = nl
    _G.GameTooltipTextLeft1 = nil
    -- soft target: a Copper Vein in front of you is saved at your position, its name learned
    M.pos = { 0.30, 0.70 }
    local getName = _G.UnitName
    _G.UnitName = function(u) if u == "softinteract" then return "Kupferader" end return getName(u) end
    M.Fire("PLAYER_SOFT_INTERACT_CHANGED", nil, "GameObject-0-1-0-1-1731-000A")
    _G.UnitName = getName
    local seenRec
    for k, r in pairs(ns.db.nodes[1429]) do
        local x, y = ns.DecodeXY(k, 1)
        if r.t == 34 and r.s == "seen" and math.abs(x - 0.30) < 0.005 and math.abs(y - 0.70) < 0.005 then seenRec = r end
    end
    assertTrue(seenRec, "soft-targeted vein saved")
    assertTrue(ns.Detect.TypeForName("Kupferader") == 34, "localized name learned for minimap dots")
    -- the tracking switcher / ready check know what roam needs
    local need = ns.Tracking.Needs(a.result)
    assertTrue(need.ore and not need.herb, "needs Mining")
    -- the card and the Route tab show it; Stop ends it
    ns.Main:Toggle("route")
    ns.Main:UpdateStatus()
    assertTrue(ns.Main.card.goal:GetText():find("Mining"), "card")
    ns.Main.frame:Hide()
    ns.Route:Stop()
    assertTrue(not ns.Roam:Active(), "stopped")
    -- slash command and minimap ctrl-click
    ns.Slash("roam herb")
    assertTrue(ns.Roam:Active() and ns.Roam:Active().kind == "herb", "slash")
    ns.Slash("roam stop")
    assertTrue(not ns.Roam:Active(), "slash stop")
    for k, r in pairs(ns.db.nodes[1429]) do if r.s == "seen" then ns.db.nodes[1429][k] = nil end end
    ns.Learn.Store().names = {}
    ns.DS:Invalidate(1429)
    M.skills = { { "Herbalism", 50, 75, 182 }, { "Skinning", 40, 75, 393 } }
    _G.GetProfessions = function() return 1, 2, nil, nil, nil end
    ns.Player:RefreshSkills()
    M.pos = { 0.40, 0.60 }
end)

test("minimap detection: rotation, nodes you can't gather yet are still saved, setting off saves nothing", function()
    M.mapID, M.pos = 1429, { 0.50, 0.50 }
    Minimap:SetSize(140, 140)
    local cx, cy = Minimap:GetCenter()
    local getCursor, getCVar, facing = _G.GetCursorPosition, _G.GetCVar, _G.GetPlayerFacing
    _G.GetCursorPosition = function() return cx + 35, cy end
    -- rotating minimap, facing west: screen right is north
    _G.GetCVar = function(k) if k == "rotateMinimap" then return "1" end return getCVar(k) end
    _G.GetPlayerFacing = function() return math.pi / 2 end
    local x, y = ns.Detect.CursorMapPosition(1429)
    assertTrue(math.abs(x - 0.5) < 0.001 and y < 0.5 and math.abs(ns.Player:Distance(1429, 0.5, 0.5, x, y) - 100) < 2, "rotated: 100 yd north")
    _G.GetCVar, _G.GetPlayerFacing = getCVar, facing
    -- off the minimap: nothing
    _G.GetCursorPosition = function() return cx + 90, cy end
    assertTrue(ns.Detect.CursorMapPosition(1429) == nil, "outside the minimap")
    _G.GetCursorPosition = function() return cx, cy + 35 end
    local count = function()
        local n = 0
        for _, r in pairs(ns.db.nodes[1429] or {}) do if r.s == "seen" then n = n + 1 end end
        return n
    end
    local nl = GameTooltip.NumLines
    GameTooltip.NumLines = function() return 1 end
    -- a Mithril Deposit: too high to mine, still saved for the database
    _G.GameTooltipTextLeft1 = { GetText = function() return "Mithril Deposit" end }
    local n0 = count()
    ns.Detect:OnMinimapTooltip()
    assertTrue(count() == n0 + 1, "saved")
    -- setting off: not saved
    ns.settings.detectNodes = false
    _G.GetCursorPosition = function() return cx - 35, cy end
    ns.Detect:OnMinimapTooltip()
    assertTrue(count() == n0 + 1, "not saved with the setting off")
    ns.settings.detectNodes = true
    -- not a node: ignored
    _G.GameTooltipTextLeft1 = { GetText = function() return "Mailbox" end }
    _G.GetCursorPosition = function() return cx, cy - 35 end
    ns.Detect:OnMinimapTooltip()
    assertTrue(count() == n0 + 1, "other tooltips ignored")
    _G.GetCursorPosition, GameTooltip.NumLines, _G.GameTooltipTextLeft1 = getCursor, nl, nil
    for k, r in pairs(ns.db.nodes[1429]) do if r.s == "seen" then ns.db.nodes[1429][k] = nil end end
    ns.DS:Invalidate(1429)
    M.pos = { 0.40, 0.60 }
end)

test("memory: searches stay within budget, caches are capped", function()
    collectgarbage("collect")
    local base = collectgarbage("count")
    local t0 = os.clock()
    for _, g in ipairs({ "herb", "ore", "skin", "cloth", "leather" }) do ns.Finder:Run({ goal = g, perZone = 2 }) end
    ns.Combo:Run({ gather = "both" })
    local secs = os.clock() - t0
    collectgarbage("collect")
    local after = collectgarbage("count")
    local nz, mz, mc = ns.DS:CacheSizes()
    print(string.format("       5 searches + gather/kill: %.0f ms, retained %.0f KB (node zones %d, mob zones %d, mobs %d)",
        secs * 1000, after - base, nz, mz, mc))
    assertTrue(nz <= ns.DS.CAP_NODE_ZONES and mz <= ns.DS.CAP_MOB_ZONES and mc <= ns.DS.CAP_MOBS, "caps")
    assertTrue(after - base < 12000, "retained memory " .. (after - base) .. " KB")
end)

M.RunTimers(10)
print(string.format("\n%d passed, %d failed", passed, failed))
os.exit(failed == 0 and 0 or 1)
