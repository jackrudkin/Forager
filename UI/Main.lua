-- Main window: header (goal, mode, Start farming, questing zone) + tabs.
local _, ns = ...
local UI = ns.UI
local Main = {}
ns.Main = Main
Main.tabs = {}

local W, H = 900, 610

local function zoneItems(includeOff, includeAuto)
    local items = {}
    if includeOff then items[#items + 1] = { text = "|cff9d9d9dOff (dedicated farming)|r", value = false } end
    if includeAuto then items[#items + 1] = { text = "Auto: current zone", value = "auto" } end
    local list = {}
    for id, z in pairs(ns.Zones) do list[#list + 1] = { id = id, z = z } end
    table.sort(list, function(a, b) if a.z.min ~= b.z.min then return a.z.min < b.z.min end return a.z.name < b.z.name end)
    for _, e in ipairs(list) do
        items[#items + 1] = { text = string.format("%s |cff9d9d9d(%d-%d)|r", e.z.name, e.z.min, e.z.max), value = e.id }
    end
    return items
end
Main.ZoneItems = zoneItems

function Main:RegisterTab(key, label, build)
    self.tabs[#self.tabs + 1] = { key = key, label = label, build = build }
end

function Main:Create()
    if self.frame then return self.frame end
    local ok, f = pcall(CreateFrame, "Frame", "ForagerMainFrame", UIParent, "ButtonFrameTemplate")
    if not ok or not f then
        f = CreateFrame("Frame", "ForagerMainFrame", UIParent, "BackdropTemplate")
        f:SetBackdrop({ bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background", edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
            tile = true, tileSize = 32, edgeSize = 32, insets = { left = 11, right = 12, top = 12, bottom = 11 } })
        local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
        close:SetPoint("TOPRIGHT", -4, -4)
    end
    self.frame = f
    f:SetSize(W, H)
    f:SetPoint("CENTER")
    f:SetFrameStrata("HIGH")
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    f:SetClampedToScreen(true)
    if ButtonFrameTemplate_HidePortrait then pcall(ButtonFrameTemplate_HidePortrait, f) end
    if ButtonFrameTemplate_HideButtonBar then pcall(ButtonFrameTemplate_HideButtonBar, f) end
    if f.SetTitle then f:SetTitle("Forager") elseif f.TitleText then f.TitleText:SetText("Forager") end
    if f.Inset then f.Inset:Hide() end
    tinsert(UISpecialFrames, "ForagerMainFrame")
    f:Hide()

    -- header -------------------------------------------------------------
    local hdr = CreateFrame("Frame", nil, f)
    hdr:SetPoint("TOPLEFT", 14, -28)
    hdr:SetPoint("TOPRIGHT", -14, -28)
    hdr:SetHeight(80)
    self.header = hdr

    local goalLbl = UI.Label(hdr, "Goal", "GameFontNormalSmall")
    goalLbl:SetPoint("TOPLEFT", 2, -2)
    local goalItems = function()
        local out = {}
        for _, g in ipairs(ns.Goals) do out[#out + 1] = { text = "|T" .. g.icon .. ":14|t " .. g.label, value = g.key } end
        return out
    end
    self.goalDD = UI.Dropdown(hdr, 190, goalItems, function() return Main:Goal() end, function(v)
        ns.char.goal = v
        ns:Fire("FORAGER_GOAL_CHANGED")
    end)
    self.goalDD:SetPoint("TOPLEFT", goalLbl, "BOTTOMLEFT", 0, -2)

    local modeLbl = UI.Label(hdr, "Rank by", "GameFontNormalSmall")
    modeLbl:SetPoint("LEFT", goalLbl, "LEFT", 200, 0)
    self.modeDD = UI.Dropdown(hdr, 130, function()
        return { { text = "Gold / hour", value = "gold" }, { text = "Skill-ups / hour", value = "skill" } }
    end, function() return ns.settings.mode end, function(v)
        ns.settings.mode = v
        ns:Fire("FORAGER_GOAL_CHANGED")
    end)
    self.modeDD:SetPoint("TOPLEFT", modeLbl, "BOTTOMLEFT", 0, -2)

    local start = CreateFrame("Button", nil, hdr, "UIPanelButtonTemplate")
    start:SetSize(150, 36)
    start:SetPoint("LEFT", self.modeDD, "RIGHT", 14, 6)
    start:SetText("Start farming")
    start:SetNormalFontObject("GameFontNormalLarge")
    start:SetHighlightFontObject("GameFontHighlightLarge")
    start:SetScript("OnClick", function() Main:StartFarming() end)
    start:SetScript("OnEnter", function(self)
        UI.Tip(self, "Start farming", { "Picks the best spot for your goal, skill, level and faction (inside your questing zone if one is set), draws the area and route on both maps and shows the next-waypoint arrow." })
    end)
    start:SetScript("OnLeave", function() GameTooltip:Hide() end)
    self.startBtn = start
    local stop = UI.Button(hdr, "Stop", 60, function() ns.Route:Stop() Main:UpdateStatus() end)
    stop:SetPoint("LEFT", start, "RIGHT", 6, 0)

    local qLbl = UI.Label(hdr, "Questing zone:", "GameFontNormal")
    qLbl:SetPoint("TOPLEFT", 2, -60)
    self.questDD = UI.Dropdown(hdr, 190, function() return zoneItems(true, true) end,
        function() return ns.char.questZone or false end,
        function(v) ns.Quests:Set(v or nil, ns.char.questZone2) end)
    self.questDD:SetPoint("LEFT", qLbl, "RIGHT", 6, 0)
    local cur = UI.Button(hdr, "Use current zone", 120, function()
        local m = ns.Player:MapID()
        if m and ns.Zones[m] then ns.Quests:Set(m, ns.char.questZone2) else ns:Print("Current zone is not a farming zone.") end
    end)
    cur:SetPoint("LEFT", self.questDD, "RIGHT", 4, 0)
    local clear = UI.Button(hdr, "X", 24, function() ns.Quests:Set(nil, nil) end)
    clear:SetPoint("LEFT", cur, "RIGHT", 2, 0)
    clear:SetScript("OnEnter", function(self) UI.Tip(self, "Clear questing zone", { "Back to dedicated farming (best anywhere)." }) end)
    clear:SetScript("OnLeave", function() GameTooltip:Hide() end)
    local q2Lbl = UI.Label(hdr, "Next hub (optional):", "GameFontNormalSmall")
    q2Lbl:SetPoint("LEFT", clear, "RIGHT", 14, 0)
    self.quest2DD = UI.Dropdown(hdr, 180, function() return zoneItems(true, false) end,
        function() return ns.char.questZone2 or false end,
        function(v) ns.Quests:Set(ns.char.questZone, v or nil) end)
    self.quest2DD:SetPoint("LEFT", q2Lbl, "RIGHT", 6, 0)
    self.quest2DD:SetScript("OnEnter", function(self) UI.Tip(self, "Second questing zone", { "Optional: the zone of your next quest hub. Spots there are ranked too." }) end)
    self.quest2DD:SetScript("OnLeave", function() GameTooltip:Hide() end)

    -- status line
    local status = UI.Label(f, "", "GameFontHighlightSmall")
    status:SetPoint("TOPLEFT", hdr, "BOTTOMLEFT", 2, -2)
    status:SetPoint("RIGHT", hdr, "RIGHT", 0, 0)
    status:SetHeight(16)
    self.status = status

    -- content + tabs -------------------------------------------------------
    local content = CreateFrame("Frame", nil, f)
    content:SetPoint("TOPLEFT", 14, -132)
    content:SetPoint("BOTTOMRIGHT", -14, 14)
    self.content = content

    self.tabButtons = {}
    for i, tab in ipairs(self.tabs) do
        local okT, b = pcall(CreateFrame, "Button", "ForagerMainFrameTab" .. i, f, "PanelTabButtonTemplate")
        if not okT or not b then b = CreateFrame("Button", "ForagerMainFrameTab" .. i, f, "UIPanelButtonTemplate") b:SetSize(100, 24) end
        b:SetText(tab.label)
        b:SetID(i)
        if PanelTemplates_TabResize then pcall(PanelTemplates_TabResize, b, 0) end
        if i == 1 then b:SetPoint("TOPLEFT", f, "BOTTOMLEFT", 12, 2) else b:SetPoint("LEFT", self.tabButtons[i - 1], "RIGHT", -14, 0) end
        b:SetScript("OnClick", function() Main:SelectTab(i) end)
        self.tabButtons[i] = b
        local panel = CreateFrame("Frame", nil, content)
        panel:SetAllPoints()
        panel:Hide()
        tab.panel = panel
    end
    f.numTabs = #self.tabs
    f.Tabs = self.tabButtons
    if PanelTemplates_SetNumTabs then pcall(PanelTemplates_SetNumTabs, f, #self.tabs) end

    ns:On("FORAGER_QUESTZONE_CHANGED", function() Main:RefreshHeader() end)
    ns:On("FORAGER_ROUTE_CHANGED", function() Main:UpdateStatus() end)
    ns:On("FORAGER_ROUTE_PROGRESS", function() Main:UpdateStatus() end)
    ns:On("FORAGER_SESSION_UPDATE", function() if f:IsShown() then Main:UpdateStatus() end end)
    f:SetScript("OnShow", function() Main:RefreshHeader() Main:UpdateStatus() end)
    self:SelectTab(1)
    return f
end

function Main:SelectTab(i)
    for j, tab in ipairs(self.tabs) do
        if j == i then
            if not tab.built then tab.build(tab.panel) tab.built = true end
            tab.panel:Show()
            if tab.panel.OnActivate then tab.panel:OnActivate() end
        else
            tab.panel:Hide()
        end
    end
    self.selected = i
    if PanelTemplates_SetTab then pcall(PanelTemplates_SetTab, self.frame, i) end
end

function Main:SelectTabByKey(key)
    for i, t in ipairs(self.tabs) do if t.key == key then self:SelectTab(i) return end end
end

function Main:Goal() return ns.char.goal or ns.Finder:DefaultGoal() end

function Main:RefreshHeader()
    if not self.frame then return end
    self.goalDD:Refresh()
    self.modeDD:Refresh()
    self.questDD:Refresh()
    self.quest2DD:Refresh()
    self:UpdateStatus()
end

function Main:UpdateStatus()
    if not self.status then return end
    local parts = {}
    if ns.Quests:IsActive() then
        local z1, z2 = ns.Quests:Zones()
        local txt = "|cffffd100Questing in:|r " .. (z1 and ns.Player:ZoneName(z1) or "?")
        if ns.char.questZone == "auto" then txt = txt .. " |cff9d9d9d(auto)|r" end
        if z2 then txt = txt .. " → " .. ns.Player:ZoneName(z2) end
        parts[#parts + 1] = txt
    else
        parts[#parts + 1] = "|cff9d9d9dDedicated farming (best anywhere)|r"
    end
    local a = ns.Route.active
    if a then
        local r = a.result
        local rate = r.mode == "skill" and string.format("%.0f skill-ups/h", r.perHour) or (ns.Money(r.perHour, true) .. "/h")
        parts[#parts + 1] = string.format("|cff7fd36bFarming:|r %s · %s · %s", ns.GoalByKey[r.goal].label, r.zoneName or "?", rate)
    end
    local perHour = ns.Capture:SessionPerHour()
    if ns.Capture.session.start then
        parts[#parts + 1] = string.format("Session: %s (%s/h)", ns.Money(ns.Capture.session.value), ns.Money(perHour, true))
    end
    if ns.safeMode then parts[#parts + 1] = "|cffff4040SAFE MODE|r" end
    self.status:SetText(table.concat(parts, "   |cff555555|||r   "))
end

function Main:StartFarming()
    local goal = self:Goal()
    local best, all = ns.Finder:Best(goal, ns.settings.mode)
    if not best then
        ns:Print("No spot found for " .. ns.GoalByKey[goal].label .. " with your current skill/level" ..
            (ns.Quests:IsActive() and " in your questing zone. Clear it (X) to search everywhere." or "."))
        return
    end
    ns.Route:Start(best)
    local rate = best.mode == "skill" and string.format("%.0f skill-ups/h", best.perHour) or (ns.Money(best.perHour, true) .. "/h")
    ns:Print(string.format("Farming %s in |cffffffff%s|r: ~%s. Follow the arrow; route drawn on map and minimap.", ns.GoalByKey[goal].label, best.zoneName, rate))
    if self.frame and self.frame:IsShown() then
        self:SelectTabByKey("find")
        ns:Fire("FORAGER_SHOW_RESULTS", all, best)
    end
end

function Main:Toggle(tabKey)
    local f = self:Create()
    if f:IsShown() and not tabKey then f:Hide() return end
    f:Show()
    if tabKey then self:SelectTabByKey(tabKey) end
end
