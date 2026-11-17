-- Launcher: initialisation, minimap button, LDB launcher, addon compartment, slash commands.
local _, ns = ...

-------------------------------------------------------------------------------
-- minimap button (own, draggable around the minimap edge)
-------------------------------------------------------------------------------
local button
local function tooltip(owner)
    GameTooltip:SetOwner(owner, "ANCHOR_LEFT")
    GameTooltip:AddLine("Forager")
    local a = ns.Route.active
    if a then
        local r = a.result
        GameTooltip:AddLine(string.format("%s in %s%s  ·  %s", ns.Finder:GoalInfo(r.goal).label, r.areaName and (r.areaName .. ", ") or "",
            r.zoneName or "?", ns.Main:RateText(r)), 1, 1, 1)
    end
    if ns.Quests:IsActive() then
        local z1 = ns.Quests:Zones()
        GameTooltip:AddLine("Questing in: " .. (z1 and ns.Player:ZoneName(z1) or "?"), 1, 0.82, 0)
    end
    local perHour = ns.Capture:SessionPerHour()
    if ns.Capture.session.start then GameTooltip:AddLine("Session: " .. ns.Money(ns.Capture.session.value) .. "  (" .. ns.Money(perHour, true) .. "/h)", 1, 1, 1) end
    GameTooltip:AddLine("Left-click: open  ·  Right-click: Start farming", 0.7, 0.7, 0.7)
    GameTooltip:AddLine("Shift-right-click: stop route  ·  Drag: move", 0.7, 0.7, 0.7)
    GameTooltip:Show()
end

local function onClick(_, btn)
    if btn == "RightButton" then
        if IsShiftKeyDown() then ns.Route:Stop() else ns.Main:StartFarming() end
    else
        ns.Main:Toggle()
    end
end

local function placeButton()
    local angle = math.rad(ns.settings.minimap.angle or 200)
    local r = (Minimap:GetWidth() / 2) + 5
    button:ClearAllPoints()
    button:SetPoint("CENTER", Minimap, "CENTER", math.cos(angle) * r, math.sin(angle) * r)
end

local function createButton()
    button = CreateFrame("Button", "ForagerMinimapButton", Minimap)
    button:SetSize(31, 31)
    button:SetFrameStrata("MEDIUM")
    button:SetFrameLevel(8)
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    button:RegisterForDrag("LeftButton")
    button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
    local overlay = button:CreateTexture(nil, "OVERLAY")
    overlay:SetSize(53, 53)
    overlay:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    overlay:SetPoint("TOPLEFT")
    local bg = button:CreateTexture(nil, "BACKGROUND")
    bg:SetSize(20, 20)
    bg:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
    bg:SetPoint("TOPLEFT", 7, -5)
    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetSize(17, 17)
    icon:SetTexture("Interface\\Icons\\INV_Misc_Herb_07")
    icon:SetPoint("TOPLEFT", 7, -6)
    button:SetScript("OnClick", onClick)
    button:SetScript("OnEnter", tooltip)
    button:SetScript("OnLeave", function() GameTooltip:Hide() end)
    button:SetScript("OnDragStart", function(self)
        self:SetScript("OnUpdate", function()
            local mx, my = Minimap:GetCenter()
            local cx, cy = GetCursorPosition()
            local scale = Minimap:GetEffectiveScale()
            cx, cy = cx / scale, cy / scale
            ns.settings.minimap.angle = math.deg(math.atan2(cy - my, cx - mx)) % 360
            placeButton()
        end)
    end)
    button:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)
    placeButton()
    button:SetShown(not ns.settings.minimapHide)
end

-- addon compartment (TOC: AddonCompartmentFunc)
function Forager_OnAddonCompartmentClick(_, btn)
    onClick(nil, btn == "RightButton" and "RightButton" or "LeftButton")
end
function Forager_OnAddonCompartmentEnter(_, frame) tooltip(frame) end
function Forager_OnAddonCompartmentLeave() GameTooltip:Hide() end

-------------------------------------------------------------------------------
-- slash commands
-------------------------------------------------------------------------------
local HELP = {
    "/forage - open/close the window",
    "/forage start [goal|item name] - best spot now (goals: herb ore skin fish cloth greens leather meat elemental lockbox gold)",
    "/forage stop - stop the route",
    "/forage farm | combo | mobs | route | nodes | stats | settings - open a tab",
    "/forage map - open the world map at your farm spot",
    "/forage caves - caves known in this zone",
    "/forage diag - diagnostics (paste this when reporting a problem)",
    "/forage quest <zone name> | current | auto | off - set questing zone",
    "/forage quest2 <zone name> | off - optional next quest hub (ranked too)",
    "/forage mode gold | skill - rank by gold/hour or skill-ups/hour",
    "/forage mob - print Forager lines for your target",
    "/forage import - import GatherMate2/GatherLite nodes",
    "/forage save - write data to disk now (reloads UI)",
    "/forage backup | restore - backup status / restore from backup",
    "/forage reset nodes|mobs|stats|all - clear data (asks first)",
    "/forage status - data and backup status",
}

local function findZone(text)
    text = text:lower()
    for id, z in pairs(ns.Zones) do if z.name:lower() == text then return id end end
    for id, z in pairs(ns.Zones) do if z.name:lower():find(text, 1, true) then return id end end
end

StaticPopupDialogs["FORAGER_CONFIRM_RESET"] = {
    text = "Forager: clear %s? This can't be undone (the backup file is refreshed too).",
    button1 = YES, button2 = NO, timeout = 0, whileDead = true, hideOnEscape = true,
    OnAccept = function(_, data) ns:ResetData(data) ns:Print("Cleared: " .. data) end,
}
StaticPopupDialogs["FORAGER_CONFIRM_RESTORE"] = {
    text = "Forager: replace your current data with the backup copy? The UI will reload.",
    button1 = YES, button2 = NO, timeout = 0, whileDead = true, hideOnEscape = true,
    OnAccept = function() ns:RestoreBackup() end,
}

local function slash(msg)
    msg = strtrim(msg or "")
    local cmd, rest = msg:match("^(%S*)%s*(.-)$")
    cmd = (cmd or ""):lower()
    if cmd == "" then ns.Main:Toggle()
    elseif cmd == "start" then
        if rest ~= "" then
            if ns.GoalByKey[rest:lower()] then ns.char.goal = rest:lower()
            else
                local s = ns.Finder:Suggest(rest, 3)[1]
                if s and s.kind ~= "mob" then ns.char.goal = s.key else ns:Print("Unknown goal or item: " .. rest) return end
            end
        end
        ns.Main:StartFarming()
    elseif cmd == "stop" then ns.Route:Stop()
    elseif cmd == "map" then ns.Overlay:OpenMapTo()
    elseif cmd == "find" or cmd == "farm" or cmd == "combo" or cmd == "route" or cmd == "nodes" or cmd == "mobs" or cmd == "stats" or cmd == "settings" then ns.Main:Toggle(cmd)
    elseif cmd == "caves" then
        local m = ns.Player:MapID()
        local z = m and ns.Zones[m]
        ns:Print(string.format("Caves in %s: %s", ns.Player:ZoneName(m), (z and z.caves and #z.caves > 0) and table.concat(z.caves, ", ") or "none listed"))
        for _, c in ipairs(m and ns.Caves:List(m) or {}) do
            DEFAULT_CHAT_FRAME:AddMessage(string.format("  %s: %d cells walked, centre %.1f, %.1f", c.name, c.cells, c.x * 100, c.y * 100))
        end
        local cur = ns.Caves:PlayerCave()
        if cur then DEFAULT_CHAT_FRAME:AddMessage("  You are in: " .. cur) end
    elseif cmd == "diag" then ns.Diag()
    elseif cmd == "quest" then
        local r = rest:lower()
        if r == "off" or r == "" then ns.Quests:Set(nil, nil) ns:Print("Questing zone cleared - dedicated farming.")
        elseif r == "current" or r == "auto" then ns.Quests:Set(r == "auto" and "auto" or ns.Player:MapID(), ns.char.questZone2) ns:Print("Questing in: " .. ns.Player:ZoneName(ns.Player:MapID()))
        else
            local z = findZone(rest)
            if z then ns.Quests:Set(z, ns.char.questZone2) ns:Print("Questing in: " .. ns.Zones[z].name) else ns:Print("Unknown zone: " .. rest) end
        end
    elseif cmd == "quest2" then
        local r = rest:lower()
        if r == "off" or r == "" then ns.Quests:Set(ns.char.questZone, nil) ns:Print("Next hub cleared.")
        elseif not ns.char.questZone then ns:Print("Set a questing zone first (/forage quest <zone>).")
        else
            local z = findZone(rest)
            if z then ns.Quests:Set(ns.char.questZone, z) ns:Print("Next hub: " .. ns.Zones[z].name) else ns:Print("Unknown zone: " .. rest) end
        end
    elseif cmd == "mode" then
        if rest == "gold" or rest == "skill" then ns.settings.mode = rest ns:Print("Ranking by " .. (rest == "gold" and "gold/hour" or "skill-ups/hour")) end
    elseif cmd == "mob" then
        local guid = ns.Safe(UnitGUID("target"))
        local id, kind = ns.IDFromGUID(guid)
        if kind ~= "Creature" then ns:Print("Target a creature first.") return end
        ns.DS:Load()
        ns:Print((ns.Safe(UnitName("target")) or "?") .. " (npc " .. id .. ")")
        for _, l in ipairs(ns.Tooltip:Lines(id, ns.Safe(UnitLevel("target")))) do DEFAULT_CHAT_FRAME:AddMessage("  " .. l[1] .. (l[2] and ("  " .. l[2]) or "")) end
    elseif cmd == "import" then ns.Import:Run()
    elseif cmd == "save" then ns:SaveNow()
    elseif cmd == "backup" then ns:Print("Backup: " .. ns:BackupStatus())
    elseif cmd == "restore" then StaticPopup_Show("FORAGER_CONFIRM_RESTORE")
    elseif cmd == "reset" then
        local what = (rest ~= "" and rest:lower()) or "all"
        if what ~= "nodes" and what ~= "mobs" and what ~= "stats" then what = "all" end
        local dlg = StaticPopup_Show("FORAGER_CONFIRM_RESET", what)
        if dlg then dlg.data = what end
    elseif cmd == "status" then
        local learned = 0
        for _, z in pairs(ns.db.nodes) do learned = learned + ns.Count(z) end
        ns:Print(string.format("v%s · learned nodes %d · mobs observed %d · database %s · backup %s%s", ns.version, learned, ns.Count(ns.db.mobs),
            ns.DS:HasBundled() and "loaded" or "not loaded", ns:BackupStatus(), ns.safeMode and (" · SAFE MODE: " .. ns.safeMode) or ""))
    elseif cmd == "debug" then
        ns.settings.debug = not ns.settings.debug
        ns:Print("debug " .. (ns.settings.debug and "on" or "off") .. " (" .. #ns.debugLog .. " log lines)")
    else
        for _, l in ipairs(HELP) do DEFAULT_CHAT_FRAME:AddMessage(ns.COLOR .. l .. "|r") end
    end
end

-------------------------------------------------------------------------------
-- diagnostics
-------------------------------------------------------------------------------
local function addonLoaded(pattern)
    if not (C_AddOns and C_AddOns.GetNumAddOns) then return nil end
    for i = 1, C_AddOns.GetNumAddOns() do
        local name = C_AddOns.GetAddOnInfo(i)
        if name and name:lower():find(pattern) and C_AddOns.IsAddOnLoaded(i) then return name end
    end
end

function ns.Diag()
    local HBD = LibStub("HereBeDragons-2.0")
    local out = {}
    local function add(k, v) out[#out + 1] = "  " .. k .. ": " .. tostring(v) end
    local _, build, _, toc = GetBuildInfo()
    add("Forager", ns.version .. " · client " .. tostring(build) .. " · toc " .. tostring(toc))
    local m = ns.Player:MapID()
    local x, y = ns.Player:Position(m)
    add("Player map", tostring(m) .. " " .. ns.Player:ZoneName(m) .. (x and string.format(" (%.1f, %.1f)", x * 100, y * 100) or " (no position)"))
    add("World map shown", WorldMapFrame and WorldMapFrame:IsShown() and ("yes, map " .. tostring(WorldMapFrame:GetMapID())) or "no")
    local a = ns.Route.active
    if a then
        add("Active farm", string.format("%s · map %d · %d stops · %d yd · rect %s", a.result.goal, a.uiMap, #a.route.points, a.route.length or 0,
            a.result.rect and "yes" or "no"))
        local p = a.route.points[1]
        if p and WorldMapFrame then
            local tx, ty = HBD:TranslateZoneCoordinates(p.x, p.y, a.uiMap, WorldMapFrame:GetMapID() or a.uiMap, true)
            add("Stop 1 on displayed map", tx and string.format("%.3f, %.3f", tx, ty) or "cannot translate (map not in HereBeDragons data)")
        end
        local wx = HBD:GetWorldCoordinatesFromZone(0.5, 0.5, a.uiMap)
        add("Zone in HereBeDragons", wx and "yes" or "NO (route can't be drawn)")
    else
        add("Active farm", "none")
    end
    add("Preview", ns.Route.preview and "yes" or "no")
    add("Route on maps (world / minimap)", (ns.settings.showRoute and "on" or "off") .. " / " .. ns.settings.routeMinimap
        .. " · area outline " .. (ns.settings.showArea and "on" or "off"))
    add("Explored-area API", (C_MapExplorationInfo and C_MapExplorationInfo.GetExploredAreaIDsAtPosition) and "yes" or "no")
    if m then
        local cave, name = ns.Caves:At(m, x or 0.5, y or 0.5)
        add("Cave here", tostring(cave) .. (name and (" (" .. name .. ")") or "") .. " · area " .. tostring(x and ns.Caves:AreaName(m, x, y)))
        add("Caves learned in zone", #ns.Caves:List(m))
    end
    add("Map art API", (C_Map.GetMapArtLayers and C_Map.GetMapArtLayerTextures) and "yes" or "no")
    local OM = ns.Overlay.OpenMapAPI()
    local layer = ns.Overlay:WorldMapLayer()
    add("OpenMap", (addonLoaded("openmap") or "not loaded") .. (OpenMapAPI and (" · API v" .. tostring(OpenMapAPI.version)) or "")
        .. (OM and (" · stitched, art top " .. tostring(OM.ArtTopLevel and OM.ArtTopLevel())) or ""))
    add("Route layer", layer and string.format("level %d, %dx%d, %s", layer:GetFrameLevel(), layer:GetWidth(), layer:GetHeight(),
        layer:IsVisible() and "visible" or "hidden") or "not created (world map canvas missing at login)")
    add("TomTom", TomTom and "loaded" or "not loaded")
    add("Prices", table.concat(ns.Prices:Available(), ", "))
    add("Database", ns.DS:HasBundled() and (ns.DS:CountBundledNodes() .. " spawn points") or "NOT LOADED")
    add("Last draw error", ns.Overlay.lastError or "none")
    add("Backup", ns:BackupStatus())
    ns:Print("diagnostics:")
    for _, l in ipairs(out) do DEFAULT_CHAT_FRAME:AddMessage(l) end
end

SLASH_FORAGER1, SLASH_FORAGER2 = "/forage", "/forager"
SlashCmdList.FORAGER = slash
ns.Slash = slash

-------------------------------------------------------------------------------
-- initialisation
-------------------------------------------------------------------------------
ns:On("PLAYER_LOGIN", function()
    ns:InitDB()
    ns.Player:RefreshSkills()
    ns.DS:Load()
    ns.Capture:Init()
    ns.Comms:Init()
    ns.Caves:Init()
    ns.Risk:Init()
    ns.Overlay:Init()
    ns.Tooltip:Init()
    createButton()
    local ldb = LibStub("LibDataBroker-1.1", true)
    if ldb then
        ldb:NewDataObject("Forager", { type = "launcher", icon = "Interface\\Icons\\INV_Misc_Herb_07", label = "Forager",
            OnClick = onClick, OnTooltipShow = function(tt) tt:AddLine("Forager") tt:AddLine("Left: open · Right: Start farming", 0.7, 0.7, 0.7) end })
    end
    ns:On("FORAGER_SETTINGS_CHANGED", function() if button then button:SetShown(not ns.settings.minimapHide) end end)
    ns.After(5, function() ns.Import:FirstRun() end)
    local learned = 0
    for _, z in pairs(ns.db.nodes) do learned = learned + ns.Count(z) end
    ns:Print(string.format("v%s loaded · %d learned nodes · %d mobs observed · backup %s · /forage",
        ns.version, learned, ns.Count(ns.db.mobs), ns:BackupStatus()))
end)
