-- Detect: learns herb and ore nodes you see but don't gather, so free roam can point at them and the
-- finders know the spot exists (Forever's new zones have no spawn data at all).
--   * Minimap: hover a herb/ore dot and the game's tooltip names it. Forager reads the name, works out
--     where the dot is from the cursor's offset to the minimap centre (zoom and rotation included) and
--     saves the node at that position. In free roam the arrow locks on to it.
--   * World: the node the game soft-targets (the closest interactable object in front of you, within a
--     few yards) is saved at your position, and its name in your client's language is learned.
-- There is no API that lists minimap dots. Addons that find them without a hover move the minimap under
-- the cursor every few seconds (it blinks, and Forever restricted that in November); Forager doesn't.
local _, ns = ...
local Detect = {}
ns.Detect = Detect
local DS, P, Safe = ns.DS, ns.Player, ns.Safe

Detect.POLL = 0.2          -- seconds between reads of the minimap tooltip while it is shown
Detect.DEDUPE_YARDS = 12   -- the same dot hovered again within this is the same node

local names -- [lowercase node name] = node type key (bundled English names + names learned in your language)
local function nameMap()
    if names then return names end
    names = {}
    for key, t in pairs(ns.NodeTypes) do
        if (t.kind == "herb" or t.kind == "ore") and t.name then names[t.name:lower()] = key end
    end
    for n, key in pairs(ns.Learn.Store().names) do names[n] = key end
    return names
end

local function clean(text)
    text = text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|T.-|t", ""):gsub("|A.-|a", "")
    return (text:gsub("^%s+", ""):gsub("%s+$", ""))
end

--- Node type for a node name (any case, colour codes allowed), or nil.
function Detect.TypeForName(name)
    if type(name) ~= "string" then return nil end
    return nameMap()[clean(name):lower()]
end

--- Node types named in a tooltip, in order (several dots under the cursor give several lines).
function Detect.TooltipTypes(tt)
    local out = {}
    local n = tt.NumLines and tt:NumLines() or 0
    for i = 1, n do
        local fs = _G["GameTooltipTextLeft" .. i]
        local text = fs and Safe(fs:GetText())
        if type(text) == "string" then
            for line in (text:gsub("|n", "\n") .. "\n"):gmatch("(.-)\n") do
                local tk = Detect.TypeForName(line)
                if tk then out[#out + 1] = tk end
            end
        end
    end
    return out
end

local function radius()
    if C_Minimap and C_Minimap.GetViewRadius then
        local r = Safe(C_Minimap.GetViewRadius())
        if r and r > 0 then return r end
    end
    return 200
end

--- Map position (on uiMap) of the point under the cursor on the minimap, or nil when not over it.
--- Screen offset from the minimap centre -> yards east/north of the player (undoing rotation when
--- "Rotate Minimap" is on: screen up = facing) -> zone coordinates via the zone's size in yards.
function Detect.CursorMapPosition(uiMap)
    local mm = Minimap
    if not (mm and GetCursorPosition and uiMap) then return nil end
    local scale = mm:GetEffectiveScale()
    local cx, cy = GetCursorPosition()
    local mx, my = mm:GetCenter()
    if not (cx and cy and mx and my and scale and scale > 0) then return nil end
    local sx, sy = cx / scale - mx, cy / scale - my -- right / up, in minimap pixels
    local half = mm:GetWidth() / 2
    if half <= 0 or math.abs(sx) > half or math.abs(sy) > half then return nil end
    local R = radius()
    local e, n = sx / half * R, sy / half * R
    if GetCVar("rotateMinimap") == "1" then
        local f = Safe(GetPlayerFacing()) or 0 -- 0 = north, counter-clockwise
        local s, c = math.sin(f), math.cos(f)
        e, n = e * c - n * s, e * s + n * c
    end
    local px, py = P:Position(uiMap)
    local w, h = P:ZoneSize(uiMap)
    if not (px and w and h and w > 0 and h > 0) then return nil end
    local x, y = px + e / w, py - n / h
    if x < 0 or x > 1 or y < 0 or y > 1 then return nil end
    return x, y
end

local recent = {} -- last few detections, to save each node once
local function duplicate(uiMap, x, y, tk)
    local now = GetTime()
    for i = #recent, 1, -1 do
        local e = recent[i]
        if now - e.at > 30 then table.remove(recent, i)
        elseif e.uiMap == uiMap and e.t == tk and P:Distance(uiMap, x, y, e.x, e.y) < Detect.DEDUPE_YARDS then return true end
    end
    recent[#recent + 1] = { uiMap = uiMap, x = x, y = y, t = tk, at = now }
    if #recent > 20 then table.remove(recent, 1) end
    return false
end

--- A node was seen at (x, y): save it (setting) and tell free roam. how = "minimap" | "world".
function Detect:Seen(uiMap, x, y, tk, how)
    if duplicate(uiMap, x, y, tk) then
        ns:Fire("FORAGER_NODE_SEEN", uiMap, x, y, tk, how, true)
        return
    end
    if ns.settings.detectNodes ~= false then ns.Capture:RecordSeen(uiMap, x, y, tk) end
    ns:Fire("FORAGER_NODE_SEEN", uiMap, x, y, tk, how, false)
end

--- The minimap tooltip is showing: read it.
function Detect:OnMinimapTooltip()
    if P:InRestrictedContent() then return end
    local uiMap = P:MapID()
    if not uiMap then return end
    local types = Detect.TooltipTypes(GameTooltip)
    if #types == 0 then return end
    local x, y = Detect.CursorMapPosition(uiMap)
    if not x then return end
    for _, tk in ipairs(types) do Detect:Seen(uiMap, x, y, tk, "minimap") end
end

--- The soft interact target changed (GUID of the new target, or nil).
function Detect:OnSoftTarget(guid)
    guid = Safe(guid) or (UnitGUID and Safe(UnitGUID("softinteract")))
    local id, kind = ns.IDFromGUID(guid)
    if kind ~= "GameObject" then return end
    local tk = DS:TypeForObject(id)
    local t = tk and ns.NodeTypes[tk]
    if not t or (t.kind ~= "herb" and t.kind ~= "ore") then return end
    local name = UnitName and Safe(UnitName("softinteract"))
    if type(name) == "string" and name ~= "" then
        local n = clean(name):lower()
        if not nameMap()[n] then
            ns.Learn.Store().names[n] = tk
            names[n] = tk
        end
    end
    if P:InRestrictedContent() then return end
    local uiMap = P:MapID()
    local x, y = P:Position(uiMap)
    if x then Detect:Seen(uiMap, x, y, tk, "world") end
end

local function minimapOwned()
    local o = GameTooltip.GetOwner and GameTooltip:GetOwner()
    if o and o == Minimap then return true end
    return Minimap and Minimap.IsMouseOver and Minimap:IsMouseOver() or false
end

function Detect:Init()
    local poll = CreateFrame("Frame")
    poll:Hide()
    local acc = 0
    poll:SetScript("OnUpdate", function(self, elapsed)
        acc = acc + elapsed
        if acc < Detect.POLL then return end
        acc = 0
        if not GameTooltip:IsShown() or not minimapOwned() then self:Hide() return end
        local ok, err = pcall(Detect.OnMinimapTooltip, Detect)
        if not ok then ns:Error("minimap tooltip", err) end
    end)
    Detect.poll = poll
    GameTooltip:HookScript("OnShow", function()
        if minimapOwned() then acc = Detect.POLL poll:Show() end
    end)
    ns:On("PLAYER_SOFT_INTERACT_CHANGED", function(_, _, newTarget) Detect:OnSoftTarget(newTarget) end)
end
