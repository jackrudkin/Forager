-- Main window: title bar, sidebar navigation, "now farming" card, content area and status bar.
local _, ns = ...
local UI = ns.UI
local T = ns.Theme
local Main = {}
ns.Main = Main
Main.tabs = {}

local W, H, SIDE = 1000, 640, 164

local function zoneItems(includeOff, includeAuto)
    local items = {}
    if includeOff then items[#items + 1] = { text = "|cff9d9d9dEverywhere (my level)|r", value = false } end
    if includeAuto then items[#items + 1] = { text = "Current zone (follows me)", value = "auto" } end
    local list = {}
    for id, z in pairs(ns.Zones) do if z.faction ~= "S" then list[#list + 1] = { id = id, z = z } end end
    table.sort(list, function(a, b) if a.z.min ~= b.z.min then return a.z.min < b.z.min end return a.z.name < b.z.name end)
    for _, e in ipairs(list) do
        items[#items + 1] = { text = string.format("%s |cff9d9d9d(%d-%d)|r", ns.DS:ZoneName(e.id), e.z.min, e.z.max), value = e.id }
    end
    return items
end
Main.ZoneItems = zoneItems

function Main:RegisterTab(key, label, icon, build)
    self.tabs[#self.tabs + 1] = { key = key, label = ns.L[label], icon = icon, build = build }
end

function Main:RateText(r)
    if not r then return "" end
    if r.mode == "skill" then return string.format("%.0f skill-ups/h", r.perHour) end
    if ns.Finder.last and ns.Finder.last.byUnits and r.itemUnits then return string.format("%.0f /h", r.itemUnits) end
    return ns.Money(r.perHour, true) .. "/h"
end

local function charLine()
    local P = ns.Player
    local parts = { "Level " .. P:Level() }
    local names = { herb = "Herbalism", ore = "Mining", skin = "Skinning", fish = "Fishing", lock = "Lockpicking" }
    for _, k in ipairs({ "herb", "ore", "skin", "fish", "lock" }) do
        local s = P.skills[k]
        if s then parts[#parts + 1] = names[k] .. " " .. s.rank end
    end
    return table.concat(parts, "  ·  ")
end

function Main:Create()
    if self.frame then return self.frame end
    local f = CreateFrame("Frame", "ForagerMainFrame", UIParent, "BackdropTemplate")
    self.frame = f
    UI.Skin(f, T.bg, T.border)
    f:SetSize(W, H)
    f:SetPoint("CENTER")
    f:SetFrameStrata("HIGH")
    f:SetToplevel(true)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    f:SetClampedToScreen(true)
    tinsert(UISpecialFrames, "ForagerMainFrame")
    f:Hide()

    -- title bar ------------------------------------------------------------
    local title = CreateFrame("Frame", nil, f)
    title:SetPoint("TOPLEFT", 1, -1)
    title:SetPoint("TOPRIGHT", -1, -1)
    title:SetHeight(40)
    local tbg = title:CreateTexture(nil, "BACKGROUND")
    tbg:SetAllPoints()
    tbg:SetColorTexture(T.panel[1], T.panel[2], T.panel[3], 1)
    local line = title:CreateTexture(nil, "BORDER")
    line:SetPoint("BOTTOMLEFT")
    line:SetPoint("BOTTOMRIGHT")
    line:SetHeight(1)
    line:SetColorTexture(T.border[1], T.border[2], T.border[3], 1)
    local icon = title:CreateTexture(nil, "ARTWORK")
    icon:SetSize(26, 26)
    icon:SetPoint("LEFT", 10, 0)
    icon:SetTexture("Interface\\Icons\\INV_Misc_Herb_07")
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    local name = title:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    name:SetPoint("LEFT", icon, "RIGHT", 8, 0)
    name:SetText("Forager")
    name:SetTextColor(T.accent[1], T.accent[2], T.accent[3])
    local ver = UI.Muted(title, "v" .. (ns.version or "?"))
    ver:SetPoint("BOTTOMLEFT", name, "BOTTOMRIGHT", 6, 1)
    self.charLine = UI.Muted(title, "")
    self.charLine:SetPoint("LEFT", ver, "RIGHT", 16, 0)
    local close = UI.IconButton(title, "Interface\\FriendsFrame\\ClearBroadcastIcon", 16, function() f:Hide() end, "Close")
    close:SetPoint("RIGHT", -12, 0)

    -- sidebar ----------------------------------------------------------------
    local side = CreateFrame("Frame", nil, f)
    side:SetPoint("TOPLEFT", 1, -41)
    side:SetPoint("BOTTOMLEFT", 1, 25)
    side:SetWidth(SIDE)
    local sbg = side:CreateTexture(nil, "BACKGROUND")
    sbg:SetAllPoints()
    sbg:SetColorTexture(T.panel[1], T.panel[2], T.panel[3], 0.6)
    local sline = side:CreateTexture(nil, "BORDER")
    sline:SetPoint("TOPRIGHT")
    sline:SetPoint("BOTTOMRIGHT")
    sline:SetWidth(1)
    sline:SetColorTexture(T.border[1], T.border[2], T.border[3], 1)
    self.side = side

    self.navButtons = {}
    for i, tab in ipairs(self.tabs) do
        local b = CreateFrame("Button", nil, side)
        b:SetSize(SIDE - 1, 34)
        b:SetPoint("TOPLEFT", 0, -8 - (i - 1) * 36)
        b.bg = b:CreateTexture(nil, "BACKGROUND")
        b.bg:SetAllPoints()
        b.bar = b:CreateTexture(nil, "BORDER")
        b.bar:SetPoint("TOPLEFT")
        b.bar:SetPoint("BOTTOMLEFT")
        b.bar:SetWidth(3)
        b.bar:SetColorTexture(T.accent[1], T.accent[2], T.accent[3], 1)
        b.icon = b:CreateTexture(nil, "ARTWORK")
        b.icon:SetSize(20, 20)
        b.icon:SetPoint("LEFT", 14, 0)
        b.icon:SetTexture(tab.icon)
        b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        b.text = b:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        b.text:SetPoint("LEFT", b.icon, "RIGHT", 10, 0)
        b.text:SetText(tab.label)
        b:SetScript("OnEnter", function(self) if Main.selected ~= i then self.bg:SetColorTexture(1, 1, 1, 0.04) end end)
        b:SetScript("OnLeave", function(self) if Main.selected ~= i then self.bg:SetColorTexture(0, 0, 0, 0) end end)
        b:SetScript("OnClick", function() Main:SelectTab(i) end)
        self.navButtons[i] = b
    end

    -- now farming card (bottom of sidebar)
    local card = UI.Panel(side, T.panel2, T.border)
    card:SetPoint("BOTTOMLEFT", 8, 8)
    card:SetPoint("BOTTOMRIGHT", -9, 8)
    card:SetHeight(120)
    local ch = UI.Muted(card, "NOW FARMING", "GameFontNormalSmall")
    ch:SetPoint("TOPLEFT", 8, -7)
    card.icon = card:CreateTexture(nil, "ARTWORK")
    card.icon:SetSize(22, 22)
    card.icon:SetPoint("TOPLEFT", 8, -24)
    card.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    card.goal = UI.Label(card, "", "GameFontNormalSmall")
    card.goal:SetPoint("TOPLEFT", card.icon, "TOPRIGHT", 6, 0)
    card.goal:SetPoint("RIGHT", -6, 0)
    card.goal:SetWordWrap(false)
    card.zone = UI.Label(card, "", "GameFontHighlightSmall")
    card.zone:SetPoint("TOPLEFT", card.goal, "BOTTOMLEFT", 0, -2)
    card.zone:SetPoint("RIGHT", -6, 0)
    card.zone:SetWordWrap(false)
    card.rate = UI.Label(card, "", "GameFontHighlightSmall")
    card.rate:SetPoint("TOPLEFT", 8, -52)
    card.rate:SetPoint("RIGHT", -6, 0)
    card.map = UI.Button(card, "Map", 66, function() ns.Overlay:OpenMapTo() end)
    card.map:SetPoint("BOTTOMLEFT", 6, 6)
    card.stop = UI.Button(card, "Stop", 66, function() ns.Route:Stop() end)
    card.stop:SetPoint("BOTTOMRIGHT", -6, 6)
    card.idle = UI.Muted(card, "Pick something in Farm and press Start farming, or right-click the minimap button.")
    card.idle:SetPoint("TOPLEFT", 8, -24)
    card.idle:SetPoint("RIGHT", -8, 0)
    card.idle:SetJustifyV("TOP")
    self.card = card

    -- content + status ---------------------------------------------------------
    local content = CreateFrame("Frame", nil, f)
    content:SetPoint("TOPLEFT", SIDE + 14, -52)
    content:SetPoint("BOTTOMRIGHT", -14, 34)
    self.content = content

    local status = CreateFrame("Frame", nil, f)
    status:SetPoint("BOTTOMLEFT", 1, 1)
    status:SetPoint("BOTTOMRIGHT", -1, 1)
    status:SetHeight(24)
    local stbg = status:CreateTexture(nil, "BACKGROUND")
    stbg:SetAllPoints()
    stbg:SetColorTexture(T.panel[1], T.panel[2], T.panel[3], 1)
    local stl = status:CreateTexture(nil, "BORDER")
    stl:SetPoint("TOPLEFT")
    stl:SetPoint("TOPRIGHT")
    stl:SetHeight(1)
    stl:SetColorTexture(T.border[1], T.border[2], T.border[3], 1)
    self.status = UI.Muted(status, "")
    self.status:SetPoint("LEFT", 10, 0)
    self.status:SetPoint("RIGHT", -10, 0)
    self.status:SetWordWrap(false)

    for _, tab in ipairs(self.tabs) do
        local panel = CreateFrame("Frame", nil, content)
        panel:SetAllPoints()
        panel:Hide()
        tab.panel = panel
    end

    ns:On("FORAGER_QUESTZONE_CHANGED", function() Main:UpdateStatus() end)
    ns:On("FORAGER_ROUTE_CHANGED", function() Main:UpdateStatus() end)
    ns:On("FORAGER_ROUTE_PROGRESS", function() Main:UpdateStatus() end)
    ns:On("FORAGER_SESSION_UPDATE", function() if f:IsShown() then Main:UpdateStatus() end end)
    ns:On("SKILL_LINES_CHANGED", function() if f:IsShown() then self.charLine:SetText(charLine()) end end)
    f:SetScript("OnShow", function() self.charLine:SetText(charLine()) Main:UpdateStatus() end)
    self:SelectTab(1)
    return f
end

function Main:SelectTab(i)
    for j, tab in ipairs(self.tabs) do
        local b = self.navButtons[j]
        if j == i then
            if not tab.built then
                local ok, err = pcall(tab.build, tab.panel)
                if not ok then ns:Print("UI error in " .. tab.label .. ": " .. tostring(err)) end
                tab.built = true
            end
            tab.panel:Show()
            if tab.panel.OnActivate then tab.panel:OnActivate() end
            b.bg:SetColorTexture(1, 1, 1, 0.06)
            b.bar:Show()
            b.text:SetTextColor(1, 1, 1)
        else
            tab.panel:Hide()
            b.bg:SetColorTexture(0, 0, 0, 0)
            b.bar:Hide()
            b.text:SetTextColor(T.muted[1], T.muted[2], T.muted[3])
        end
    end
    self.selected = i
end

function Main:SelectTabByKey(key)
    if key == "find" then key = "farm" elseif key == "map" then key = "route" end
    for i, t in ipairs(self.tabs) do if t.key == key then self:SelectTab(i) return end end
end

function Main:Goal() return ns.char.goal or ns.Finder:DefaultGoal() end

function Main:UpdateStatus()
    if not self.frame then return end
    -- now farming card
    local card, a = self.card, ns.Route.active
    if a then
        local r = a.result
        local g = ns.Finder:GoalInfo(r.goal)
        card.icon:SetTexture(g.icon)
        card.goal:SetText(g.short or g.label)
        card.zone:SetText((r.areaName and (r.areaName .. ", ") or "") .. (r.zoneName or ""))
        local _, _, _, loops = ns.Route:Next()
        card.rate:SetText(string.format("|cffffd100%s|r  ·  loop %d\n%s", Main:RateText(r), (loops or 0) + 1, ns.Risk:Short(r)))
        for _, w in ipairs({ card.icon, card.goal, card.zone, card.rate, card.map, card.stop }) do w:Show() end
        card.idle:Hide()
    else
        for _, w in ipairs({ card.icon, card.goal, card.zone, card.rate, card.map, card.stop }) do w:Hide() end
        card.idle:Show()
    end
    -- status bar
    local parts = {}
    if ns.Quests:IsActive() then
        local z1, z2 = ns.Quests:Zones()
        local txt = "Questing in |cffffffff" .. (z1 and ns.Player:ZoneName(z1) or "?") .. "|r"
        if ns.char.questZone == "auto" then txt = txt .. " (follows you)" end
        if z2 then txt = txt .. " → |cffffffff" .. ns.Player:ZoneName(z2) .. "|r" end
        parts[#parts + 1] = txt
    else
        parts[#parts + 1] = "Searching everywhere for your level"
    end
    if ns.Capture.session.start then
        parts[#parts + 1] = string.format("Session |cffffffff%s|r (%s/h)", ns.Money(ns.Capture.session.value, true), ns.Money(ns.Capture:SessionPerHour(), true))
    end
    parts[#parts + 1] = "Prices: " .. table.concat(ns.Prices:Available(), " > ")
    if ns.safeMode then parts[#parts + 1] = "|cffff4040SAFE MODE: " .. ns.safeMode .. "|r" end
    self.status:SetText(table.concat(parts, "    ·    "))
end

function Main:StartFarming(goal)
    goal = goal or self:Goal()
    local best, all = ns.Finder:Best(goal, ns.settings.mode)
    local label = ns.Finder:GoalInfo(goal).label
    if not best then
        local why = ""
        if ns.settings.location == "cave" then why = " in caves (caves fill in as you explore; set Location to Anywhere)"
        elseif ns.Quests:IsActive() then why = " in your questing zone (set Search in: Everywhere)" end
        ns:Print("No spot found for " .. label .. " with your current skill/level" .. why .. ".")
        return
    end
    ns.Route:Start(best)
    ns:Print(string.format("Farming %s in |cffffffff%s%s|r: ~%s. Follow the arrow; area and route are on the map and minimap.",
        label, best.areaName and (best.areaName .. ", ") or "", best.zoneName, Main:RateText(best)))
    if self.frame and self.frame:IsShown() then
        self:SelectTabByKey("farm")
        ns:Fire("FORAGER_SHOW_RESULTS", all, best)
    end
end

function Main:Toggle(tabKey)
    local f = self:Create()
    if f:IsShown() and not tabKey then f:Hide() return end
    f:Show()
    if tabKey then self:SelectTabByKey(tabKey) end
end
