-- Player state: professions, level, faction, zone, position, travel speed.
local _, ns = ...
local P = {}
ns.Player = P
local HBD = LibStub("HereBeDragons-2.0")

P.skills = {}

function P:RefreshSkills()
    wipe(P.skills)
    if not GetProfessions then return end
    local profs = { GetProfessions() }
    for i = 1, 6 do
        local idx = profs[i]
        if idx then
            local name, _, rank, maxRank, _, _, skillLine = GetProfessionInfo(idx)
            for key, line in pairs(ns.SkillLines) do
                if skillLine == line then P.skills[key] = { rank = rank or 0, max = maxRank or 0, name = name } end
            end
        end
    end
    -- Rogue Lockpicking: not a profession in the Mainline API; Forever cap = level x 5.
    local _, class = UnitClass("player")
    if class == "ROGUE" then
        local lvl = UnitLevel("player") or 1
        P.skills.lock = { rank = (ns.char.lockSkill or lvl * 5), max = lvl * 5, name = "Lockpicking", estimated = not ns.char.lockSkill }
    end
end

function P:Skill(key)
    local s = P.skills[key]
    return s and s.rank or nil
end

function P:Level() return ns.Safe(UnitLevel("player")) or 1 end

function P:Faction()
    local f = ns.Safe(UnitFactionGroup("player"))
    return (f == "Horde" and "H") or (f == "Alliance" and "A") or "?"
end

function P:MapID()
    return C_Map and C_Map.GetBestMapForUnit and ns.Safe(C_Map.GetBestMapForUnit("player"))
end

--- x, y (0-1) on the given or current map, or nil (instances, secret).
function P:Position(uiMap)
    uiMap = uiMap or P:MapID()
    if not uiMap then return nil end
    local pos = C_Map.GetPlayerMapPosition(uiMap, "player")
    if not pos then return nil end
    local x, y = pos:GetXY()
    x, y = ns.Safe(x), ns.Safe(y)
    if not x or not y or (x == 0 and y == 0) then return nil end
    return x, y, uiMap
end

--- Yards/second used for route timing.
function P:Speed()
    local s = ns.settings.speed
    if s and ns.Speeds[s] then return ns.Speeds[s] end
    local lvl = P:Level()
    if lvl >= 60 then return ns.Speeds.mount60 end
    if lvl >= 40 then return ns.Speeds.mount60 end
    return ns.Speeds.run
end

--- Zone width/height in yards via HereBeDragons, with a fallback.
function P:ZoneSize(uiMap)
    local w, h = HBD:GetZoneSize(uiMap)
    if not w or w == 0 then return 3000, 2000 end
    return w, h
end

--- Distance in yards between two points on the same map.
function P:Distance(uiMap, x1, y1, x2, y2)
    local w, h = P:ZoneSize(uiMap)
    local dx, dy = (x2 - x1) * w, (y2 - y1) * h
    return math.sqrt(dx * dx + dy * dy)
end

function P:ZoneName(uiMap)
    local z = ns.Zones[uiMap]
    if z then return z.name end
    local info = C_Map and C_Map.GetMapInfo and C_Map.GetMapInfo(uiMap)
    return info and info.name or ("Map " .. tostring(uiMap))
end

function P:InRestrictedContent()
    local inInstance, itype = IsInInstance()
    return inInstance and itype ~= "none"
end

ns:On("SKILL_LINES_CHANGED", function() if ns.db then P:RefreshSkills() end end)
ns:On("PLAYER_LEVEL_UP", function() if ns.db then ns.After(1, function() P:RefreshSkills() end) end end)
