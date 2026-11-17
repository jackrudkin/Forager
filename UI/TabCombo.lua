-- Gather + Kill tab: areas where mining / herbalism and killing (and skinning) the mobs on the way pay
-- best together, by gold per hour or by gathering + skinning skill-ups per hour.
local _, ns = ...
local UI, Main = ns.UI, ns.Main
local T = ns.Theme

local RISK_COLOR = { [0] = "|cff7fd36b", [1] = "|cffffd100", [2] = "|cffff5050" }
local GATHER_LABEL = { ore = "Mining", herb = "Herbalism", both = "Herbs + ore" }
local GATHER_ICON = { ore = "Interface\\Icons\\Trade_Mining", herb = "Interface\\Icons\\Trade_Herbalism", both = "Interface\\Icons\\INV_Pick_02" }
local SKIN_ICON = "Interface\\Icons\\INV_Misc_Pelt_Wolf_01"
local MOB_ICON = "Interface\\Icons\\Ability_Warrior_Revenge"
local SKILL_HEX = { orange = "ff8040", yellow = "ffff00", green = "40c040", grey = "808080", red = "ff4040" }

local function itemIcon(id)
    return (C_Item and C_Item.GetItemIconByID and C_Item.GetItemIconByID(id)) or "Interface\\Icons\\INV_Misc_QuestionMark"
end
local function lootIcon(it)
    if it.coin then return "Interface\\Icons\\INV_Misc_Coin_01" end
    if it.greens == 2 then return "Interface\\Icons\\INV_Enchant_DustStrange" end
    if it.greens == 3 then return "Interface\\Icons\\INV_Enchant_ShardGlimmeringSmall" end
    return itemIcon(it.id)
end
local function money(c) return ns.Money(c or 0, true) end
local function minutes(sec) return string.format("%.1f", (sec or 0) / 60) end
local function su(v) return string.format("%.0f", v or 0) end

--- "skin 170" coloured by your Skinning (red = too high), or "" if not skinnable.
local function skinTag(row)
    if not row.req then return "" end
    local col = row.col or (row.skinOK and "yellow" or "red")
    local txt = "skin " .. row.req
    if col == "red" then txt = txt .. " (too high)" end
    return "|cff" .. (SKILL_HEX[col] or "ffffff") .. txt .. "|r"
end

local function gain(r)
    local single = math.max(r.nodesOnlyRate or 0, r.mobsOnlyRate or 0)
    if single <= 0 then return nil end
    return (r.perHour / single - 1) * 100
end

local function rateText(r)
    if r.mode == "skill" then return su(r.perHour) .. " skill-ups/h" end
    return money(r.perHour) .. "/h"
end

Main:RegisterTab("combo", "Gather + Kill", "Interface\\Icons\\INV_Pick_02", function(panel)
    local state = { results = {}, selected = nil }

    ---------------------------------------------------------------------------
    -- controls
    ---------------------------------------------------------------------------
    local gLbl = UI.Muted(panel, "Gather")
    gLbl:SetPoint("TOPLEFT", 0, -6)
    local gather = UI.Segmented(panel, {
        { key = "ore", label = "Mining" },
        { key = "herb", label = "Herbs" },
        { key = "both", label = "Both", tip = "Routes through herbs and ore. You can only track one of them on the minimap at a time." },
    }, function() return ns.Combo:DefaultGather() end, function(v) ns.settings.comboGather = v panel:Rerun() end)
    gather:SetPoint("LEFT", gLbl, "RIGHT", 8, 0)
    local kLbl = UI.Muted(panel, "Kill")
    kLbl:SetPoint("LEFT", gather, "RIGHT", 16, 0)
    local kill = UI.Segmented(panel, {
        { key = "all", label = "All mobs", tip = "Any mob worth your time. Skins count when your Skinning is high enough for the mob." },
        { key = "skin", label = "Skinnable only", tip = "Only mobs you can skin (beasts within your Skinning). Mining + skinning." },
    }, function() return ns.Combo:KillFor() end, function(v) ns.settings.comboKill = v panel:Rerun() end)
    kill:SetPoint("LEFT", kLbl, "RIGHT", 8, 0)
    local rLbl = UI.Muted(panel, "Rank by")
    rLbl:SetPoint("LEFT", kill, "RIGHT", 16, 0)
    local rank = UI.Segmented(panel, {
        { key = "gold", label = "Gold / hour" },
        { key = "skill", label = "Skill-ups / hour", tip = "Gathering skill-ups plus Skinning skill-ups per hour (orange 100%, yellow 75%, green 25%)." },
    }, function() return ns.Combo:Mode() end, function(v) ns.settings.comboMode = v panel:Rerun() end)
    rank:SetPoint("LEFT", rLbl, "RIGHT", 8, 0)

    local lLbl = UI.Muted(panel, "Location")
    lLbl:SetPoint("TOPLEFT", 0, -36)
    local loc = UI.Segmented(panel, {
        { key = "any", label = "Anywhere" },
        { key = "cave", label = "Caves & mines" },
        { key = "outdoor", label = "Outdoors" },
    }, function() return ns.settings.location end, function(v) ns.settings.location = v panel:Rerun() ns:Fire("FORAGER_GOAL_CHANGED") end)
    loc:SetPoint("LEFT", lLbl, "RIGHT", 8, 0)
    local sLbl = UI.Muted(panel, "Search in")
    sLbl:SetPoint("LEFT", loc, "RIGHT", 16, 0)
    local scope = UI.Dropdown(panel, 190, function() return Main.ZoneItems(true, true) end,
        function() return ns.char.questZone or false end,
        function(v) ns.Quests:Set(v or nil, v and ns.char.questZone2 or nil) end)
    scope:SetPoint("LEFT", sLbl, "RIGHT", 8, 0)
    local skills = UI.Muted(panel, "")
    skills:SetPoint("LEFT", scope, "RIGHT", 14, 0)

    local function slider(x, label, key, lo, hi, step, fmt, tip)
        local s = UI.Slider(panel, label, lo, hi, step, function() return ns.settings[key] end,
            function(v) ns.settings[key] = v panel:Rerun(0.5) end, fmt, 140)
        s:SetPoint("TOPLEFT", x, -64)
        UI.AttachTip(s.slider, label, tip)
        return s
    end
    slider(0, "Seconds per kill", "comboKillSeconds", 10, 90, 5, function(v) return v .. " s" end,
        "Fight + loot for a mob of your level. Lower-level mobs count as faster.")
    slider(202, "Seconds per skin", "comboSkinSeconds", 0, 10, 0.5, function(v) return v .. " s" end,
        "Extra time to skin a mob (cast + loot). Only for mobs you can skin.")
    slider(404, "Reach from the route", "comboPullYards", 15, 60, 5, function(v) return v .. " yd" end,
        "Mobs and nodes this close to the route count as on the way.")
    slider(606, "Mob respawn", "comboRespawn", 60, 900, 30, function(v) return math.floor(v / 60) .. ":" .. string.format("%02d", v % 60) end,
        "Time before a mob you killed is back. A loop shorter than this meets fewer mobs.")

    ---------------------------------------------------------------------------
    -- result cards
    ---------------------------------------------------------------------------
    local TOP = -112
    local list = UI.CardList(panel, 70, 6, function(c)
        c.num = c:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        c.num:SetPoint("TOPLEFT", 8, -8)
        c.num:SetTextColor(T.muted[1], T.muted[2], T.muted[3])
        c.title = UI.Label(c, "", "GameFontNormal")
        c.title:SetPoint("TOPLEFT", 32, -7)
        c.title:SetPoint("RIGHT", -96, 0)
        c.title:SetWordWrap(false)
        c.split = UI.Label(c, "", "GameFontHighlightSmall")
        c.split:SetPoint("TOPLEFT", c.title, "BOTTOMLEFT", 0, -3)
        c.split:SetPoint("RIGHT", -8, 0)
        c.split:SetWordWrap(false)
        c.rate = UI.Label(c, "", "GameFontNormal")
        c.rate:SetPoint("TOPRIGHT", -8, -7)
        c.rate:SetJustifyH("RIGHT")
        c.sub = UI.Muted(c, "")
        c.sub:SetPoint("BOTTOMLEFT", 32, 8)
        c.sub:SetPoint("RIGHT", -8, 0)
        c.sub:SetWordWrap(false)
    end, function(c, r, _, idx)
        c.num:SetText(idx)
        c.title:SetText((r.zoneName or "?") .. (r.areaName and ("  ·  " .. r.areaName) or ""))
        c.rate:SetText("|cffffd100" .. rateText(r) .. "|r")
        local gi = GATHER_ICON[r.gather] or GATHER_ICON.ore
        if r.mode == "skill" then
            c.split:SetText(string.format("|T%s:12|t %s  +  |T%s:12|t %s skill-ups", gi, su(r.nodeSU), SKIN_ICON, su(r.skinSU)))
        else
            c.split:SetText(string.format("|T%s:12|t %s  +  |T%s:12|t %s  +  |T%s:12|t %s", gi, money(r.nodeGold), SKIN_ICON,
                money(r.skinGold), MOB_ICON, money(r.lootGold)))
        end
        local bits = {}
        local g = gain(r)
        if g then bits[#bits + 1] = g >= 0 and string.format("|cff7fd36b+%d%%|r vs one alone", g) or "|cffff8040one alone is better|r" end
        if r.cave then bits[#bits + 1] = "|cff9e7af2CAVE|r" end
        if ns.Route.active and ns.Route.active.result == r then bits[#bits + 1] = "|cff7fd36bFARMING|r" end
        bits[#bits + 1] = (RISK_COLOR[r.riskLevel or 0] or "") .. (r.risk or "") .. "|r"
        c.sub:SetText(table.concat(bits, "  ·  "))
    end, function(r) panel:Select(r) end)
    list:SetPoint("TOPLEFT", 0, TOP)
    list:SetWidth(318)

    ---------------------------------------------------------------------------
    -- detail
    ---------------------------------------------------------------------------
    local d = UI.Panel(panel, T.panel, T.border)
    d:SetPoint("TOPLEFT", list, "TOPRIGHT", 10, 0)
    d:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", 0, 0)
    d.title = UI.Label(d, "", "GameFontNormalLarge")
    d.title:SetPoint("TOPLEFT", 12, -10)
    d.title:SetPoint("RIGHT", -150, 0)
    d.title:SetWordWrap(false)
    d.sub = UI.Muted(d, "")
    d.sub:SetPoint("TOPLEFT", d.title, "BOTTOMLEFT", 0, -4)
    d.sub:SetPoint("RIGHT", -12, 0)
    d.sub:SetWordWrap(false)
    d.rate = d:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    d.rate:SetPoint("TOPRIGHT", -12, -10)
    d.rate:SetTextColor(T.gold[1], T.gold[2], T.gold[3])

    local preview = UI.MapPreview(d, 210, 140)
    preview:SetPoint("TOPLEFT", 12, -50)
    preview:SetScript("OnClick", function()
        if state.selected then ns.Route:Preview(state.selected) ns.Overlay:OpenMapTo(state.selected.uiMap) end
    end)
    UI.AttachTip(preview, "Click to open the world map", nil)

    local splitHdr = UI.Header(d, "Per hour")
    splitHdr:SetPoint("TOPLEFT", preview, "TOPRIGHT", 14, 0)
    local function row(y, iconPath)
        local f = CreateFrame("Frame", nil, d)
        f:SetHeight(17)
        f:SetPoint("TOPLEFT", splitHdr, "BOTTOMLEFT", 0, y)
        f:SetPoint("RIGHT", d, "RIGHT", -12, 0)
        f.icon = f:CreateTexture(nil, "ARTWORK")
        f.icon:SetSize(15, 15)
        f.icon:SetPoint("LEFT")
        f.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        if iconPath then f.icon:SetTexture(iconPath) else f.icon:Hide() end
        f.name = UI.Label(f, "", "GameFontHighlightSmall")
        f.name:SetPoint("LEFT", iconPath and 21 or 0, 0)
        f.val = UI.Label(f, "", "GameFontHighlightSmall")
        f.val:SetPoint("RIGHT", -40, 0)
        f.val:SetJustifyH("RIGHT")
        f.pct = UI.Muted(f, "")
        f.pct:SetPoint("RIGHT")
        f.pct:SetJustifyH("RIGHT")
        return f
    end
    local rNodes = row(-5, GATHER_ICON.ore)
    local rSkins = row(-23, SKIN_ICON)
    local rLoot = row(-41, MOB_ICON)
    local rTotal = row(-62)
    local sep = d:CreateTexture(nil, "ARTWORK")
    sep:SetHeight(1)
    sep:SetPoint("TOPLEFT", rTotal, "TOPLEFT", 0, 2)
    sep:SetPoint("TOPRIGHT", rTotal, "TOPRIGHT", 0, 2)
    sep:SetColorTexture(T.border[1], T.border[2], T.border[3], 1)
    local rOnlyN = row(-84)
    local rOnlyM = row(-101)

    local loop = UI.Muted(d, "")
    loop:SetPoint("TOPLEFT", preview, "BOTTOMLEFT", 0, -6)
    loop:SetPoint("RIGHT", -12, 0)
    loop:SetWordWrap(false)
    local side = UI.Muted(d, "")
    side:SetPoint("TOPLEFT", loop, "BOTTOMLEFT", 0, -3)
    side:SetPoint("RIGHT", -12, 0)
    side:SetWordWrap(false)

    local verdict = UI.Label(d, "", "GameFontHighlightSmall")
    verdict:SetPoint("TOPLEFT", side, "BOTTOMLEFT", 0, -4)
    verdict:SetPoint("RIGHT", d, "RIGHT", -12, 0)
    verdict:SetJustifyV("TOP")

    local worthHdr = UI.Header(d, "Worth killing")
    worthHdr:SetPoint("TOPLEFT", verdict, "BOTTOMLEFT", 0, -8)
    local worth = UI.Label(d, "", "GameFontHighlightSmall")
    worth:SetPoint("TOPLEFT", worthHdr, "BOTTOMLEFT", 0, -4)
    worth:SetPoint("RIGHT", -12, 0)
    worth:SetJustifyV("TOP")
    worth:SetSpacing(2)
    local skip = UI.Muted(d, "")
    skip:SetPoint("TOPLEFT", worth, "BOTTOMLEFT", 0, -5)
    skip:SetPoint("RIGHT", -12, 0)
    skip:SetJustifyV("TOP")
    local lootLine = UI.Label(d, "", "GameFontHighlightSmall")
    lootLine:SetPoint("TOPLEFT", skip, "BOTTOMLEFT", 0, -6)
    lootLine:SetPoint("RIGHT", -12, 0)
    lootLine:SetJustifyV("TOP")
    lootLine:SetSpacing(3)

    d.start = UI.Button(d, "Start farming here", 170, function()
        local r = state.selected
        if not r then return end
        if ns.Route.active and ns.Route.active.result == r then ns.Route:Stop() else ns.Route:Start(r) end
        panel:Select(r)
    end, "primary", 30)
    d.start:SetPoint("BOTTOMLEFT", 12, 10)
    d.showMap = UI.Button(d, "Show on world map", 140, function()
        local r = state.selected
        if r then
            if not (ns.Route.active and ns.Route.active.result == r) then ns.Route:Preview(r) end
            ns.Overlay:OpenMapTo(r.uiMap)
        end
    end, nil, 30)
    d.showMap:SetPoint("LEFT", d.start, "RIGHT", 8, 0)
    d.pin = UI.Button(d, "Set waypoint", 110, function()
        if state.selected then ns.Overlay:SetFarmPin(state.selected, true) end
    end, nil, 30)
    d.pin:SetPoint("LEFT", d.showMap, "RIGHT", 8, 0)

    d.empty = UI.Muted(d, "")
    d.empty:SetPoint("TOPLEFT", 16, -16)
    d.empty:SetPoint("RIGHT", -16, 0)
    d.empty:SetJustifyV("TOP")
    d.empty:SetSpacing(3)

    local widgets = { d.title, d.sub, d.rate, preview, splitHdr, rNodes, rSkins, rLoot, rTotal, sep, rOnlyN, rOnlyM, verdict,
        loop, side, worthHdr, worth, skip, lootLine, d.start, d.showMap, d.pin }

    local function setRow(f, name, val, pct, show)
        f:SetShown(show ~= false)
        f.name:SetText(name)
        f.val:SetText(val)
        f.pct:SetText(pct or "")
    end

    function panel:Select(r)
        state.selected = r
        list.selected = r
        list:Refresh()
        for _, w in ipairs(widgets) do w:SetShown(r ~= nil) end
        d.empty:SetShown(r == nil)
        if not r then return end
        local gname = GATHER_LABEL[r.gather] or "Gathering"
        d.title:SetText((r.zoneName or "?") .. (r.areaName and ("  ·  " .. r.areaName) or "") .. (r.cave and "  |cff9e7af2(cave)|r" or ""))
        local sub = {}
        if r.minLevel then sub[#sub + 1] = string.format("Mobs %d-%d", r.minLevel, r.maxLevel) end
        if r.minSkill then sub[#sub + 1] = "nodes from skill " .. r.minSkill end
        if r.minSkin then sub[#sub + 1] = "skins from " .. r.minSkin end
        sub[#sub + 1] = (RISK_COLOR[r.riskLevel or 0] or "") .. (r.risk or "") .. "|r"
        sub[#sub + 1] = r.confidence
        d.sub:SetText(table.concat(sub, "  ·  "))
        d.rate:SetText(rateText(r))
        preview:SetResult(r)
        rNodes.icon:SetTexture(GATHER_ICON[r.gather] or GATHER_ICON.ore)
        local function pct(v, total) return total > 0 and string.format("%d%%", v / total * 100 + 0.5) or "" end
        if r.mode == "skill" then
            local total = math.max(0.0001, r.skillups)
            setRow(rNodes, gname .. " skill-ups", su(r.nodeSU), pct(r.nodeSU, total))
            setRow(rSkins, "Skinning skill-ups", su(r.skinSU), pct(r.skinSU, total))
            setRow(rLoot, "|cff9d9d9dGold on the side|r", "|cff9d9d9d" .. money(r.gold) .. "|r", "")
            setRow(rTotal, "|cffffffffTogether|r", "|cffffd100" .. su(r.skillups) .. "|r", "")
            setRow(rOnlyN, "|cff9d9d9d" .. gname .. " only here|r", "|cff9d9d9d" .. su(r.nodesOnlyRate) .. "|r")
            setRow(rOnlyM, "|cff9d9d9dSkinning only here|r", "|cff9d9d9d" .. su(r.mobsOnlyRate) .. "|r")
        else
            local total = math.max(1, r.gold)
            setRow(rNodes, gname, money(r.nodeGold), pct(r.nodeGold, total))
            setRow(rSkins, "Skins", money(r.skinGold), pct(r.skinGold, total), r.killFor == "skin" or (r.skinGold or 0) > 0 or ns.Player:Skill("skin") ~= nil)
            setRow(rLoot, r.killFor == "skin" and "Other loot" or "Mob loot", money(r.lootGold), pct(r.lootGold, total))
            setRow(rTotal, "|cffffffffTogether|r", "|cffffd100" .. money(r.gold) .. "|r", "")
            setRow(rOnlyN, "|cff9d9d9d" .. gname .. " only here|r", "|cff9d9d9d" .. money(r.nodesOnlyRate) .. "|r")
            setRow(rOnlyM, "|cff9d9d9d" .. (r.killFor == "skin" and "Skinning only here" or "Mobs only here") .. "|r",
                "|cff9d9d9d" .. money(r.mobsOnlyRate) .. "|r")
        end
        local g = gain(r)
        if g and g >= 1 then
            verdict:SetText(string.format("|cff7fd36b+%d%%|r over doing either alone here.", g))
        elseif g then
            verdict:SetText((r.mobsOnlyRate or 0) > (r.nodesOnlyRate or 0) and "|cffff8040Just killing mobs pays more here.|r" or
                "|cffff8040Mobs here add little; gathering alone is about the same.|r")
        else
            verdict:SetText("")
        end
        if r.assumedSkin then verdict:SetText((verdict:GetText() or "") .. "  |cffff8040(No Skinning on this character: assumed maxed.)|r") end
        loop:SetText(string.format("Loop %s min: walk %s · gather %s · fight %s   ·   ~%.0f nodes, ~%.0f kills, ~%.0f skins /h",
            minutes(r.loopSec), minutes(r.walkSec), minutes(r.gatherSec), minutes(r.fightSec), r.nodesPerHour or 0, r.killsPerHour or 0,
            r.skinsPerHour or 0))
        if r.mode == "skill" then
            side:SetText(string.format("Gold on the side: %s/h  (%s %s · skins %s · loot %s)", money(r.gold), gname:lower(),
                money(r.nodeGold), money(r.skinGold), money(r.lootGold)))
        else
            side:SetText(string.format("Skill-ups on the way: %s ~%s/h · skinning ~%s/h", gname:lower(), su(r.nodeSU), su(r.skinSU)))
        end
        local lines = {}
        for i, m in ipairs(r.worthy or {}) do
            if i > 3 then lines[#lines + 1] = string.format("|cff9d9d9d+%d more|r", #r.worthy - 3) break end
            local tag = skinTag(m)
            if r.mode == "skill" then
                lines[#lines + 1] = string.format("%s |cff9d9d9d(%d-%d)|r  %s  ·  %.1f skill-ups per fighting minute  ·  ~%.0f/h",
                    m.m.name, m.m.minLevel, m.m.maxLevel, tag, m.perMin, m.kills)
            else
                local skinBit = m.skinG > 0 and (" |cff9d9d9d(skins " .. money(m.skinG) .. ")|r") or ""
                lines[#lines + 1] = string.format("%s |cff9d9d9d(%d-%d)|r  %s/kill%s  %s  ·  %s/fight-min  ·  ~%.0f/h",
                    m.m.name, m.m.minLevel, m.m.maxLevel, money(m.perKill), skinBit, tag, money(m.perMin), m.kills)
            end
        end
        worth:SetText(#lines > 0 and table.concat(lines, "\n") or "|cff9d9d9dNone: nothing near the route pays more than gathering.|r")
        local sk = {}
        for i, m in ipairs(r.skipped or {}) do
            if i > 5 then sk[#sk + 1] = "..." break end
            sk[#sk + 1] = m.m.name
        end
        skip:SetText(#sk > 0 and ("Skip (less than gathering time is worth): " .. table.concat(sk, ", ")) or "")
        local lt = {}
        for i, it in ipairs(r.items or {}) do
            if i > 8 then break end
            lt[#lt + 1] = string.format("|T%s:16|t %s", lootIcon(it), it.coin and money(it.value) or string.format("%.0f", it.perHour))
        end
        lootLine:SetText(#lt > 0 and ("|cff7fd36bLoot per hour|r   " .. table.concat(lt, "   ")) or "")
        local farming = ns.Route.active and ns.Route.active.result == r
        d.start:SetText(farming and "Stop farming" or "Start farming here")
    end

    ---------------------------------------------------------------------------
    -- run
    ---------------------------------------------------------------------------
    local function emptyText()
        local g = ns.Combo:DefaultGather()
        local lines = { "|cffffffffNo spots found|r for " .. (GATHER_LABEL[g] or g) .. (ns.Combo:KillFor() == "skin" and " + skinning" or " + mobs") .. "." }
        if ns.settings.location == "cave" then lines[#lines + 1] = "Caves fill in as you explore them; try Location: Anywhere."
        elseif ns.Quests:IsActive() then lines[#lines + 1] = "Set Search in to Everywhere to look beyond your questing zone." end
        lines[#lines + 1] = ""
        lines[#lines + 1] = "An area needs at least 3 nodes you can gather. Mobs are only counted when they pay more per second than gathering."
        return table.concat(lines, "\n")
    end

    local function skillLine()
        local P = ns.Player
        local bits = {}
        for _, k in ipairs({ { "ore", "Mining" }, { "herb", "Herbalism" }, { "skin", "Skinning" } }) do
            local v = P:Skill(k[1])
            if v then bits[#bits + 1] = k[2] .. " " .. v end
        end
        if not P:Skill("skin") then bits[#bits + 1] = "|cffff8040no Skinning|r" end
        return table.concat(bits, " · ")
    end

    function panel:Run()
        gather:Refresh()
        kill:Refresh()
        rank:Refresh()
        loc:Refresh()
        scope:Refresh()
        skills:SetText(skillLine())
        local ok, res = pcall(ns.Combo.Run, ns.Combo, { perZone = 2 })
        if not ok then ns:Print("Gather + Kill error: " .. tostring(res)) res = {} end
        state.results = res
        local et = #res == 0 and emptyText() or nil
        list:SetItems(res, et and "No results - see the panel on the right." or nil)
        d.empty:SetText(et or "")
        local pick
        if ns.Route.active then
            for _, r in ipairs(res) do
                if r.uiMap == ns.Route.active.uiMap and r.goal == ns.Route.active.result.goal and r.rank == ns.Route.active.result.rank then pick = r end
            end
        end
        panel:Select(pick or res[1])
    end

    local pending
    function panel:Rerun(delay)
        if pending then return end
        pending = true
        ns.After(delay or 0.05, function()
            pending = false
            if panel:IsVisible() then panel:Run() else panel.stale = true end
        end)
    end
    ns:On("FORAGER_QUESTZONE_CHANGED", function() panel:Rerun() end)
    ns:On("FORAGER_GOAL_CHANGED", function() panel.stale = true end)
    ns:On("FORAGER_SETTINGS_CHANGED", function() panel.stale = true end)
    ns:On("SKILL_LINES_CHANGED", function() panel.stale = true end)
    ns:On("FORAGER_ROUTE_CHANGED", function() if panel:IsVisible() and state.selected then panel:Select(state.selected) end end)
    panel.OnActivate = function()
        if panel.stale or #state.results == 0 then panel.stale = false panel:Run() else list:Refresh() end
    end
end)
