-- Pins: Forager's own node icons on the minimap and world map (native yellow dots can't be read
-- or restyled on Forever). Pins are pooled and only created for the current/displayed zone.
local _, ns = ...
local Pins = {}
ns.Pins = Pins
local HBD = LibStub("HereBeDragons-2.0")
local HBDPins = LibStub("HereBeDragons-Pins-2.0")
local DS, P = ns.DS, ns.Player

local REF_MM, REF_WM = "ForagerMinimap", "ForagerWorldmap"
local pool, active = {}, { mm = {}, wm = {} }
local mmZone, wmZone

local SOURCE_LABEL = { bundled = "Database (Classic spawn)", learned = "Learned (you gathered it)", shared = "Shared by guild/party", import = "Imported" }

local function colorFor(t)
    local key = t.kind == "fish" and "fish" or t.kind
    local have = P:Skill(key)
    if t.kind == "fish" then return ns.ColorRGB.green end
    return ns.ColorRGB[ns.SkillColor(t.skill or 0, have)] or ns.ColorRGB.grey
end

local function onEnter(self)
    local d = self.data
    if not d then return end
    local t = DS:GetType(d.t)
    if not t then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:AddLine(t.name, 1, 1, 1)
    local have = P:Skill(t.kind)
    if t.kind ~= "fish" then
        local col = ns.SkillColor(t.skill or 0, have)
        GameTooltip:AddDoubleLine("Required skill", string.format("|cff%s%d|r (you: %s)", ns.ColorHex[col], t.skill or 0, have or "none"))
    end
    GameTooltip:AddDoubleLine("Source", SOURCE_LABEL[d.src] or d.src, 0.7, 0.7, 0.7, 0.9, 0.9, 0.9)
    local rec = d.rec
    if rec then
        GameTooltip:AddDoubleLine("Times gathered", rec.c or 0, 0.7, 0.7, 0.7, 1, 1, 1)
        if rec.l then GameTooltip:AddDoubleLine("Last gathered", date("%d %b %H:%M", rec.l), 0.7, 0.7, 0.7, 1, 1, 1) end
        if rec.y and next(rec.y) then
            GameTooltip:AddLine("Yielded:", 0.7, 0.7, 0.7)
            for id, q in pairs(rec.y) do GameTooltip:AddDoubleLine("  " .. DS:ColoredItem(id), "x" .. q) end
        end
        if rec.from then GameTooltip:AddDoubleLine("From", rec.from, 0.7, 0.7, 0.7, 1, 1, 1) end
    end
    if t.yields and #t.yields > 0 and (not rec or not rec.y) then
        GameTooltip:AddLine("Typical yield (Classic):", 0.7, 0.7, 0.7)
        for i = 1, math.min(3, #t.yields) do
            GameTooltip:AddDoubleLine("  " .. DS:ColoredItem(t.yields[i][1]), string.format("%.2f", t.yields[i][2]))
        end
    end
    GameTooltip:AddLine("A pin shows a known spawn point, not a live node.", 0.5, 0.5, 0.5, true)
    GameTooltip:Show()
end

local function acquire()
    local f = table.remove(pool)
    if not f then
        f = CreateFrame("Button", nil, UIParent)
        f:SetSize(14, 14)
        f.border = f:CreateTexture(nil, "BACKGROUND")
        f.border:SetPoint("TOPLEFT", -1, 1)
        f.border:SetPoint("BOTTOMRIGHT", 1, -1)
        f.border:SetColorTexture(1, 1, 1, 1)
        f.icon = f:CreateTexture(nil, "ARTWORK")
        f.icon:SetAllPoints()
        f.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        f:SetScript("OnEnter", onEnter)
        f:SetScript("OnLeave", function() GameTooltip:Hide() end)
    end
    f:EnableMouse(true)
    return f
end

local function release(f)
    f:Hide()
    f:ClearAllPoints()
    f.data = nil
    pool[#pool + 1] = f
end

local function visible(pt, t)
    local s = ns.settings
    if not t then return false end
    if not s.kinds[t.kind] then return false end
    if s.hiddenTypes[tostring(pt.t)] then return false end
    if pt.src == "bundled" and not s.showBundled then return false end
    if pt.src == "learned" and not s.showLearned then return false end
    if pt.src == "shared" and not s.showShared then return false end
    if s.onlyEligibleNodes and pt.src == "bundled" and t.kind ~= "fish" then
        local have = P:Skill(t.kind)
        if not have or have < (t.skill or 0) then return false end
    end
    return true
end

local function style(f, t, scale)
    f.icon:SetTexture(DS:TypeIcon(t))
    local c = colorFor(t)
    f.border:SetVertexColor(c[1], c[2], c[3], 1)
    local size = 14 * (scale or 1) * ns.settings.pinScale
    f:SetSize(size, size)
    f:SetAlpha(ns.settings.pinAlpha)
end

local function clear(which)
    local ref = which == "mm" and REF_MM or REF_WM
    if which == "mm" then HBDPins:RemoveAllMinimapIcons(ref) else HBDPins:RemoveAllWorldMapIcons(ref) end
    for _, f in ipairs(active[which]) do release(f) end
    wipe(active[which])
end

local function hiddenNow()
    local s = ns.settings
    if s.hideInInstances and P:InRestrictedContent() then return true end
    if s.hideInCombat and InCombatLockdown() then return true end
    return false
end

function Pins:RefreshMinimap()
    clear("mm")
    mmZone = P:MapID()
    if not ns.settings.showNodesMinimap or not mmZone or hiddenNow() then return end
    for _, pt in ipairs(DS:GetZoneNodes(mmZone)) do
        local t = DS:GetType(pt.t)
        if visible(pt, t) then
            local f = acquire()
            f.data = pt
            style(f, t, 1)
            f.wx, f.wy = HBD:GetWorldCoordinatesFromZone(pt.x, pt.y, mmZone)
            HBDPins:AddMinimapIconMap(REF_MM, f, mmZone, pt.x, pt.y, false, false)
            active.mm[#active.mm + 1] = f
        end
    end
end

function Pins:RefreshWorldMap()
    clear("wm")
    if not WorldMapFrame or not WorldMapFrame:IsShown() then return end
    if not ns.settings.showNodesWorld or hiddenNow() then return end
    wmZone = WorldMapFrame:GetMapID()
    if not wmZone or not ns.Zones[wmZone] then return end
    local n = 0
    for _, pt in ipairs(DS:GetZoneNodes(wmZone)) do
        local t = DS:GetType(pt.t)
        if visible(pt, t) then
            local f = acquire()
            f.data = pt
            style(f, t, 1.1)
            HBDPins:AddWorldMapIconMap(REF_WM, f, wmZone, pt.x, pt.y, 0)
            active.wm[#active.wm + 1] = f
            n = n + 1
            if n >= 1500 then break end
        end
    end
end

--- Distance fade for minimap pins.
local function fade()
    if not ns.settings.distanceFade or #active.mm == 0 then return end
    local px, py = HBD:GetPlayerWorldPosition()
    if not px then return end
    local far = ns.settings.fadeYards
    local base = ns.settings.pinAlpha
    for _, f in ipairs(active.mm) do
        if f.wx then
            local dx, dy = f.wx - px, f.wy - py
            local d = math.sqrt(dx * dx + dy * dy)
            f:SetAlpha(base * ns.Clamp(1.15 - d / far, 0.35, 1))
        end
    end
end

function Pins:RefreshAll()
    Pins:RefreshMinimap()
    Pins:RefreshWorldMap()
end

function Pins:Init()
    ns:On("ZONE_CHANGED_NEW_AREA", function() ns.After(0.5, function() Pins:RefreshMinimap() end) end)
    ns:On("PLAYER_ENTERING_WORLD", function() ns.After(1, function() Pins:RefreshMinimap() end) end)
    ns:On("FORAGER_NODES_CHANGED", function(_, map)
        if not map or map == mmZone then Pins:RefreshMinimap() end
        if not map or map == wmZone then Pins:RefreshWorldMap() end
    end)
    ns:On("FORAGER_SETTINGS_CHANGED", function() Pins:RefreshAll() end)
    ns:On("PLAYER_REGEN_DISABLED", function() if ns.settings.hideInCombat then clear("mm") clear("wm") end end)
    ns:On("PLAYER_REGEN_ENABLED", function() if ns.settings.hideInCombat then Pins:RefreshAll() end end)
    ns:On("SKILL_LINES_CHANGED", function() ns.After(0.2, function() Pins:RefreshAll() end) end)
    if WorldMapFrame then
        hooksecurefunc(WorldMapFrame, "OnMapChanged", function() Pins:RefreshWorldMap() end)
        WorldMapFrame:HookScript("OnShow", function() Pins:RefreshWorldMap() end)
        WorldMapFrame:HookScript("OnHide", function() clear("wm") end)
    end
    ns.Ticker(0.5, fade)
end
