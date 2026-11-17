-- Tracking: resource tracking and ready checks for gathering routes.
--   * In Forever only one resource tracker can be on at a time. On routes with both herbs and ore
--     (and both professions), Find Herbs and Find Minerals are flipped every 4 s while you move,
--     out of combat and not casting, the way Forever's tracking switchers do it.
--   * Dying clears tracking in Forever: the tracker you had on is turned back on when you are alive.
--   * Ready check when a farm starts: tracking off, Mining Pick / Skinning Knife not in your bags
--     (Forever needs the tool in your bags), with a one-click fix for tracking.
local _, ns = ...
local Tracking = {}
ns.Tracking = Tracking
local Safe, P = ns.Safe, ns.Player

Tracking.SWITCH_SECONDS = 4
Tracking.issues = {}

local spellNames = {}
local function nameOf(kind)
    local id = ns.TrackSpells[kind]
    if not id then return nil end
    if spellNames[kind] == nil then
        local n = C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(id)
        if not n and GetSpellInfo then n = GetSpellInfo(id) end
        spellNames[kind] = Safe(n) or false
    end
    return spellNames[kind] or nil
end
Tracking.SpellName = nameOf

local function entry(i)
    local ok, a, _, c, _, _, f = pcall(C_Minimap.GetTrackingInfo, i)
    if not ok or a == nil then return nil end
    if type(a) == "table" then return Safe(a.name), Safe(a.active), Safe(a.spellID) end
    return Safe(a), Safe(c), Safe(f)
end

--- Index of the tracking entry for "herb" or "ore", whether it is on, and its name. nil when not known.
function Tracking:Find(kind)
    if not (C_Minimap and C_Minimap.GetNumTrackingTypes and C_Minimap.GetTrackingInfo) then return nil end
    local ok, n = pcall(C_Minimap.GetNumTrackingTypes)
    n = ok and Safe(n)
    if type(n) ~= "number" then return nil end
    local want, wantName = ns.TrackSpells[kind], nameOf(kind)
    for i = 1, n do
        local name, active, spellID = entry(i)
        if (spellID and spellID == want) or (wantName and name == wantName) then
            if name and not spellNames[kind] then spellNames[kind] = name end
            return i, active and true or false, name
        end
    end
end

--- "herb", "ore" or nil: the resource tracker that is on.
function Tracking:Active()
    for _, k in ipairs({ "herb", "ore" }) do
        local i, on = Tracking:Find(k)
        if i and on then return k end
    end
end

--- Turn a resource tracker on (out of combat only). Returns true when it is on.
function Tracking:Set(kind)
    if InCombatLockdown() then return false end
    local i, on = Tracking:Find(kind)
    if not i then return false end
    if on then return true end
    local ok = pcall(C_Minimap.SetTracking, i, true)
    return ok
end

--- Professions a result needs: { herb = true, ore = true, skin = true }.
function Tracking.Needs(r)
    local need = {}
    if not r then return need end
    if r.source == "combo" then
        for k in pairs((ns.Combo.KINDS or {})[r.gather] or {}) do need[k] = true end
        if r.killFor == "skin" or (r.skinsPerHour or 0) > 0 then need.skin = true end
    elseif r.source == "node" then
        for _, m in ipairs(r.mix or {}) do
            local t = ns.DS:GetType(m.t)
            if t and (t.kind == "herb" or t.kind == "ore") then need[t.kind] = true end
        end
    elseif r.source == "mob" then
        if r.goal == "skin" or r.goal == "leather" then need.skin = true end
    end
    return need
end

local toolCache = {}
--- Is the gathering tool for a kind in your bags? (Mining Pick for ore, Skinning Knife for skin;
--- items whose name contains the tool's name count too, e.g. the new Keen Skinning Knife.)
function Tracking:HasTool(kind)
    local id = ns.Tools[kind]
    if not id then return true end
    if toolCache[kind] ~= nil then return toolCache[kind] end
    local has = false
    if C_Item and C_Item.GetItemCount then
        local ok, c = pcall(C_Item.GetItemCount, id)
        has = ok and (Safe(c) or 0) > 0
    end
    if not has and C_Container and C_Container.GetContainerNumSlots then
        local base = ns.DS:ItemName(id)
        base = base and base:lower()
        if base and not base:find("^item:") then
            for bag = 0, 5 do
                local ok, slots = pcall(C_Container.GetContainerNumSlots, bag)
                for slot = 1, (ok and Safe(slots) or 0) do
                    local item = Safe(C_Container.GetContainerItemID(bag, slot))
                    local name = item and ns.DS:ItemName(item)
                    if name and name:lower():find(base, 1, true) then has = true break end
                end
                if has then break end
            end
        else
            has = true -- name not cached yet: don't warn on a guess
        end
    end
    toolCache[kind] = has
    return has
end

--- Problems that would cost you loot on a result: { { text, fix = function, fixText }, ... }
function Tracking:Issues(r)
    local out = {}
    if not r or ns.settings.readyCheck == false then return out end
    local need = Tracking.Needs(r)
    local canHerb, canOre = need.herb and P.skills.herb, need.ore and P.skills.ore
    if canHerb or canOre then
        local active = Tracking:Active()
        local want = canHerb and "herb" or "ore"
        if canHerb and canOre then want = nil end -- either is fine, the switcher flips them
        if not active or (want and active ~= want) then
            local kind = want or "herb"
            if Tracking:Find(kind) then
                out[#out + 1] = { text = (nameOf(kind) or kind) .. (active and " is not on" or " is off"), fixText = "Turn on",
                    fix = function() Tracking:Set(kind) end }
            end
        end
    end
    if need.ore and P.skills.ore and not Tracking:HasTool("ore") then
        out[#out + 1] = { text = "No " .. ns.DS:ItemName(ns.Tools.ore) .. " in your bags" }
    end
    if need.skin and P.skills.skin and not Tracking:HasTool("skin") then
        out[#out + 1] = { text = "No " .. ns.DS:ItemName(ns.Tools.skin) .. " in your bags" }
    end
    return out
end

--- Recompute the issues of the active farm (events call this).
function Tracking:Refresh()
    local a = ns.Route.active
    Tracking.issues = a and Tracking:Issues(a.result) or {}
    ns:Fire("FORAGER_READY_CHANGED")
end

--- When a farm starts: print what is not ready.
function Tracking:AnnounceIssues(r)
    Tracking:Refresh()
    if #Tracking.issues == 0 then return end
    local parts = {}
    for _, i in ipairs(Tracking.issues) do parts[#parts + 1] = i.text end
    ns:Print("|cffffd100Ready check:|r " .. table.concat(parts, "; ") .. ".")
end

-------------------------------------------------------------------------------
-- switcher and re-track after death
-------------------------------------------------------------------------------
local function moving()
    if not GetUnitSpeed then return false end
    local ok, v = pcall(GetUnitSpeed, "player")
    v = ok and Safe(v)
    return type(v) == "number" and v > 0
end

local function busy()
    if InCombatLockdown() or (UnitIsDeadOrGhost and UnitIsDeadOrGhost("player")) then return true end
    if UnitCastingInfo and Safe(UnitCastingInfo("player")) then return true end
    if UnitChannelInfo and Safe(UnitChannelInfo("player")) then return true end
    return false
end

--- Should the switcher run for the active farm?
function Tracking:SwitchWanted()
    if ns.settings.trackSwitch == false then return false end
    local a = ns.Route.active
    if not a then return false end
    local need = Tracking.Needs(a.result)
    return need.herb and need.ore and P.skills.herb and P.skills.ore and true or false
end

function Tracking:SwitchTick()
    if not Tracking:SwitchWanted() or busy() or not moving() then return end
    local active = Tracking:Active()
    Tracking:Set(active == "herb" and "ore" or "herb")
end

local function retrack()
    local want = Tracking.beforeDeath
    if not want or ns.settings.retrack == false then return end
    if UnitIsDeadOrGhost and UnitIsDeadOrGhost("player") then return end
    if InCombatLockdown() then Tracking.retrackAfterCombat = true return end
    if not Tracking:Active() then Tracking:Set(want) end
    Tracking.beforeDeath = nil
end

function Tracking:Init()
    ns:On("MINIMAP_UPDATE_TRACKING", function()
        if not (UnitIsDeadOrGhost and UnitIsDeadOrGhost("player")) then
            Tracking.lastActive = Tracking:Active() or Tracking.lastActive
        end
        if ns.Route.active then Tracking:Refresh() end
    end)
    ns:On("PLAYER_DEAD", function() Tracking.beforeDeath = Tracking:Active() or Tracking.lastActive end)
    local function alive() ns.After(1.5, retrack) end
    ns:On("PLAYER_ALIVE", alive)
    ns:On("PLAYER_UNGHOST", alive)
    ns:On("PLAYER_REGEN_ENABLED", function()
        if Tracking.retrackAfterCombat then Tracking.retrackAfterCombat = nil ns.After(0.5, retrack) end
    end)
    ns:On("BAG_UPDATE_DELAYED", function() wipe(toolCache) if ns.Route.active then Tracking:Refresh() end end)
    ns:On("SKILL_LINES_CHANGED", function() if ns.Route.active then Tracking:Refresh() end end)
    ns:On("FORAGER_ROUTE_CHANGED", function() Tracking:Refresh() end)
    ns.Ticker(Tracking.SWITCH_SECONDS, function()
        local ok, err = pcall(Tracking.SwitchTick, Tracking)
        if not ok then ns:Error("tracking", err) end
    end)
    Tracking.lastActive = Tracking:Active()
end
