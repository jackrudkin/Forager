-- Minimal mock of the WoW Mainline/Forever API surface Forager uses. Lua 5.1.
-- Not a full emulator: enough to load every file, fire events and exercise logic.
local M = {}
M.registered = {}       -- event -> {frames}
M.timers = {}
M.now = 1000
M.printed = {}
M.secret = setmetatable({}, { __tostring = function() return "<secret>" end })

-------------------------------------------------------------------------------
-- frames
-------------------------------------------------------------------------------
local FrameMT = {}
local frameMethods = {}
local function newObj(kind, parent)
    local o = { _kind = kind, _scripts = {}, _shown = kind ~= "Frame" or true, _children = {}, _parent = parent, _text = "", _w = 200, _h = 200 }
    return setmetatable(o, FrameMT)
end
FrameMT.__index = function(t, k)
    local m = frameMethods[k]
    if m then return m end
    if type(k) == "string" and (k:match("^Set") or k:match("^Enable") or k:match("^Register") or k:match("^Clear") or k:match("^Unregister")) then
        return function() end
    end
    return nil
end
function frameMethods:Show() self._shown = true if self._scripts.OnShow then self._scripts.OnShow(self) end end
function frameMethods:Hide() self._shown = false if self._scripts.OnHide then self._scripts.OnHide(self) end end
function frameMethods:SetShown(v) if v then self:Show() else self:Hide() end end
function frameMethods:IsShown() return self._shown end
function frameMethods:IsVisible() return self._shown end
function frameMethods:SetScript(k, fn) self._scripts[k] = fn end
function frameMethods:GetScript(k) return self._scripts[k] end
function frameMethods:HookScript(k, fn)
    local old = self._scripts[k]
    self._scripts[k] = function(...) if old then old(...) end fn(...) end
end
function frameMethods:RegisterEvent(e)
    M.registered[e] = M.registered[e] or {}
    table.insert(M.registered[e], self)
end
function frameMethods:UnregisterEvent() end
function frameMethods:CreateTexture() return newObj("Texture", self) end
function frameMethods:CreateMaskTexture() return newObj("Texture", self) end
function frameMethods:CreateFontString() return newObj("FontString", self) end
function frameMethods:CreateLine() return newObj("Line", self) end
function frameMethods:GetWidth() return self._w end
function frameMethods:GetHeight() return self._h end
function frameMethods:SetSize(w, h) self._w, self._h = w, h end
function frameMethods:SetWidth(w) self._w = w end
function frameMethods:SetHeight(h) self._h = h end
function frameMethods:GetSize() return self._w, self._h end
function frameMethods:GetScale() return 1 end
function frameMethods:GetEffectiveScale() return 1 end
function frameMethods:GetFrameLevel() return 1 end
function frameMethods:GetCenter() return 100, 100 end
function frameMethods:GetPoint() return "CENTER", nil, "CENTER", 0, 0 end
function frameMethods:SetText(t) self._text = t end
function frameMethods:GetText() return self._text end
function frameMethods:SetChecked(v) self._checked = v end
function frameMethods:GetChecked() return self._checked end
function frameMethods:IsMouseOver() return false end
function frameMethods:SetValue(v)
    self._value = v
    if self._scripts.OnValueChanged then self._scripts.OnValueChanged(self, v) end
end
function frameMethods:GetValue() return self._value or 0 end
function frameMethods:GetID() return self._id or 0 end
function frameMethods:SetID(i) self._id = i end
function frameMethods:GetName() return self._name end
function frameMethods:GetZoom() return 2 end
function frameMethods:GetMapID() return M.worldMapID end
function frameMethods:GetCanvas() self._canvas = self._canvas or newObj("Frame", self) return self._canvas end
function frameMethods:GetCanvasScale() return 1 end
function frameMethods:GetUnit() return "Ornery Plainstrider", "mouseover" end
function frameMethods:AddLine(t) table.insert(M.tooltipLines, tostring(t)) end
function frameMethods:AddDoubleLine(a, b) table.insert(M.tooltipLines, tostring(a) .. " || " .. tostring(b)) end
function frameMethods:AddMessage(msg) table.insert(M.printed, msg) if M.verbose then print("[chat] " .. msg) end end
function frameMethods:StartMoving() end
function frameMethods:StopMovingOrSizing() end
function frameMethods:GetNormalFontObject() return nil end

function M.CreateFrame(kind, name, parent, template)
    if template and M.failTemplates and M.failTemplates[template] then error("template " .. template) end
    local f = newObj(kind or "Frame", parent)
    f._name = name
    if name then _G[name] = f end
    if kind == "Slider" then f._value = 0 end
    if template == "ButtonFrameTemplate" then f.TitleText = newObj("FontString", f) end
    if template == "UICheckButtonTemplate" then f.Text = newObj("FontString", f) end
    return f
end

function M.Fire(event, ...)
    for _, f in ipairs(M.registered[event] or {}) do
        local s = f._scripts.OnEvent
        if s then s(f, event, ...) end
    end
end

function M.RunTimers(advance)
    M.now = M.now + (advance or 0)
    local due = M.timers
    M.timers = {}
    for _, t in ipairs(due) do
        if t.at <= M.now then t.fn() else table.insert(M.timers, t) end
    end
end

-------------------------------------------------------------------------------
-- globals
-------------------------------------------------------------------------------
function M.Install(env)
    M.tooltipLines = {}
    M.worldMapID = 1429
    M.mapID = 1429
    M.pos = { 0.40, 0.60 }
    M.loot = {}
    M.money = 1000
    M.skills = { { "Herbalism", 50, 75, 182 }, { "Skinning", 40, 75, 393 } }
    M.level = 12
    M.addonsLoaded = { Forager = true, Forager_Backup = true }
    local G = _G
    G.CreateFrame = M.CreateFrame
    G.UIParent = M.CreateFrame("Frame", "UIParent")
    G.Minimap = M.CreateFrame("Frame", "Minimap")
    G.WorldMapFrame = M.CreateFrame("Frame", "WorldMapFrame")
    G.WorldMapFrame.ScrollContainer = M.CreateFrame("Frame")
    G.WorldMapFrame.OnMapChanged = function() end
    G.WorldMapFrame._shown = false
    G.GameTooltip = M.CreateFrame("Frame", "GameTooltip")
    G.DEFAULT_CHAT_FRAME = M.CreateFrame("Frame")
    G.UISpecialFrames = {}
    G.StaticPopupDialogs = {}
    G.SlashCmdList = {}
    G.YES, G.NO = "Yes", "No"
    G.StaticPopup_Show = function(name, a) local d = G.StaticPopupDialogs[name] return { data = nil, dialog = d } end
    G.C_Timer = {
        After = function(sec, fn) table.insert(M.timers, { at = M.now + sec, fn = fn }) end,
        NewTicker = function(sec, fn) return { Cancel = function() end } end,
    }
    G.GetTime = function() return M.now end
    G.time = function() return math.floor(M.now) + 1700000000 end
    G.date = os.date
    G.strsplit = function(sep, s, limit)
        local out, pattern, last = {}, "([^" .. sep .. "]*)" .. sep .. "?", 1
        if s == nil then return nil end
        local i = 1
        while true do
            local a, b = s:find(sep, i, true)
            if not a then table.insert(out, s:sub(i)) break end
            table.insert(out, s:sub(i, a - 1))
            i = b + 1
        end
        return unpack(out)
    end
    G.strtrim = function(s) return (s:gsub("^%s+", ""):gsub("%s+$", "")) end
    G.wipe = function(t) for k in pairs(t) do t[k] = nil end return t end
    G.tinsert = table.insert
    G.hooksecurefunc = function(t, name, fn)
        if type(t) == "string" then t, name, fn = G, t, name end
        local old = t[name]
        t[name] = function(...) local r = { old(...) } fn(...) return unpack(r) end
    end
    G.issecretvalue = function(v) return v == M.secret end
    G.SecondsToTime = function(s) return math.floor(s) .. " sec" end
    G.InCombatLockdown = function() return M.inCombat or false end
    G.IsInInstance = function() return false, "none" end
    G.GetCVar = function(k) if k == "rotateMinimap" then return "0" end return "0" end
    G.GetPlayerFacing = function() return 0.5 end
    G.IsInGuild = function() return true end
    G.IsInGroup = function() return false end
    G.IsInRaid = function() return false end
    G.IsShiftKeyDown = function() return false end
    G.IsMouseButtonDown = function() return false end
    G.GetCursorPosition = function() return 0, 0 end
    G.ReloadUI = function() M.reloaded = true end
    G.ToggleWorldMap = function() end
    G.GetMoney = function() return M.money end
    G.GetRealmName = function() return "TestRealm" end
    G.UnitName = function(u) if u == "player" then return "Tester" end return "Ornery Plainstrider" end
    G.UnitLevel = function(u) if u == "player" then return M.level end return 17 end
    G.UnitClass = function() return "Warrior", "WARRIOR" end
    G.UnitFactionGroup = function() return "Alliance" end
    G.UnitGUID = function(u) return M.unitGUID end
    G.GetProfessions = function() return 1, 2, nil, nil, nil end
    G.GetProfessionInfo = function(i)
        local s = M.skills[i]
        if not s then return nil end
        return s[1], 0, s[2], s[3], 0, 0, s[4]
    end
    G.C_Map = {
        GetBestMapForUnit = function() return M.mapID end,
        GetPlayerMapPosition = function(map) return { GetXY = function() return M.pos[1], M.pos[2] end } end,
        GetMapInfo = function(id) return { name = "Map" .. id } end,
    }
    G.C_Minimap = { GetViewRadius = function() return 200 end }
    G.C_AddOns = {
        GetAddOnMetadata = function() return "1.0.0-test" end,
        IsAddOnLoaded = function(n) return M.addonsLoaded[n] or false end,
        LoadAddOn = function(n)
            if n == "Forager_Data" then
                if M.noData then return false, "MISSING" end
                M.LoadDataAddon()
                M.addonsLoaded[n] = true
                return true
            end
            return false, "MISSING"
        end,
    }
    G.C_Item = {
        GetItemNameByID = function() return nil end,
        GetItemQualityByID = function(id) if id == 9999 then return 2 end return nil end,
        GetItemInfoInstant = function(id) if id == 9999 then return id, "Armor", "Leather", "INVTYPE_CHEST", 0, 4, 2 end return id, "Trade", "", "", 0, 7, 0 end,
        GetItemIconByID = function() return 134400 end,
        GetItemInfo = function() return nil end,
        RequestLoadItemDataByID = function() end,
    }
    G.C_Spell = { GetSpellName = function(id)
        local names = { [2366] = "Herb Gathering", [2575] = "Mining", [8613] = "Skinning", [7620] = "Fishing", [921] = "Pick Pocket", [1804] = "Pick Lock" }
        return names[id]
    end }
    G.GetNumLootItems = function() return #M.loot end
    G.GetLootSlotLink = function(i) local l = M.loot[i] return l and l.link end
    G.GetLootSlotInfo = function(i) local l = M.loot[i] return 0, "x", l and l.qty or 1 end
    G.GetLootSourceInfo = function(i) local l = M.loot[i] if not l then return end return unpack(l.sources) end
    G.C_ChatInfo = { RegisterAddonMessagePrefix = function() end, SendAddonMessage = function(p, m, c) M.sent = M.sent or {} table.insert(M.sent, { p, m, c }) end }
    G.C_QuestLog = {
        GetQuestsOnMap = function(map) if map == 1429 then return { { questID = 1, x = 0.45, y = 0.62 } } end return {} end,
        GetTitleForQuestID = function() return "Test quest" end,
        GetNumQuestLogEntries = function() return 1 end,
        GetInfo = function() return { title = "Wolves Across the Border", questID = 33, isHeader = false } end,
        GetQuestObjectives = function() return { { text = "Prowler slain: 2/8", finished = false } } end,
    }
    G.Enum = { TooltipDataType = { Unit = 2 } }
    G.TooltipDataProcessor = { AddTooltipPostCall = function(kind, fn) M.tooltipPostCall = fn end }
    G.PanelTemplates_SetNumTabs = function() end
    G.PanelTemplates_SetTab = function() end
    G.PanelTemplates_TabResize = function() end
    G.ButtonFrameTemplate_HidePortrait = function() end
    G.ButtonFrameTemplate_HideButtonBar = function() end
end

return M
