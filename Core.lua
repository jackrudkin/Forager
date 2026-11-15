-- Forager core: namespace, events, timers and small helpers.
local ADDON, ns = ...
Forager = ns -- global for /dump and other addons (read-only use)

ns.name = ADDON
ns.version = (C_AddOns and C_AddOns.GetAddOnMetadata and C_AddOns.GetAddOnMetadata(ADDON, "Version")) or "dev"
if ns.version:find("@") then ns.version = "dev" end
ns.modules = {}

-------------------------------------------------------------------------------
-- secret-value safety (Midnight/Forever). Never compare or index with a secret.
-------------------------------------------------------------------------------
local issecret = issecretvalue or function() return false end
ns.IsSecret = issecret

--- Returns v if it is a readable (non-secret) value, else nil.
function ns.Safe(v)
    if v == nil or issecret(v) then return nil end
    return v
end

--- Calls fn with pcall and returns its results, or nil on error/secret.
function ns.Try(fn, ...)
    local ok, a, b, c, d, e = pcall(fn, ...)
    if not ok then return nil end
    if issecret(a) then return nil end
    return a, b, c, d, e
end

-------------------------------------------------------------------------------
-- events
-------------------------------------------------------------------------------
local frame = CreateFrame("Frame")
local handlers = {}
ns.eventFrame = frame

function ns:On(event, fn)
    local list = handlers[event]
    if not list then
        list = {}
        handlers[event] = list
        if not event:find("^FORAGER_") then
            local ok = pcall(frame.RegisterEvent, frame, event)
            if not ok then ns:Debug("event not available on this client:", event) end
        end
    end
    list[#list + 1] = fn
end

function ns:Fire(event, ...)
    local list = handlers[event]
    if not list then return end
    for i = 1, #list do
        local ok, err = pcall(list[i], event, ...)
        if not ok then ns:Debug("error in", event, err) end
    end
end

frame:SetScript("OnEvent", function(_, event, ...) ns:Fire(event, ...) end)

-------------------------------------------------------------------------------
-- timers
-------------------------------------------------------------------------------
function ns.After(sec, fn)
    if C_Timer and C_Timer.After then C_Timer.After(sec, fn) end
end

function ns.Ticker(sec, fn)
    if C_Timer and C_Timer.NewTicker then return C_Timer.NewTicker(sec, fn) end
end

-------------------------------------------------------------------------------
-- output
-------------------------------------------------------------------------------
ns.COLOR = "|cff7fd36b"
function ns:Print(...)
    local msg = ns.COLOR .. "Forager|r:"
    for i = 1, select("#", ...) do msg = msg .. " " .. tostring(select(i, ...)) end
    DEFAULT_CHAT_FRAME:AddMessage(msg)
end

ns.debugLog = {}
function ns:Debug(...)
    local parts = {}
    for i = 1, select("#", ...) do parts[#parts + 1] = tostring(select(i, ...)) end
    local line = date("%H:%M:%S") .. " " .. table.concat(parts, " ")
    local log = ns.debugLog
    log[#log + 1] = line
    if #log > 200 then table.remove(log, 1) end
    if ns.db and ns.db.settings and ns.db.settings.debug then
        DEFAULT_CHAT_FRAME:AddMessage("|cff888888Forager debug:|r " .. line)
    end
end

-------------------------------------------------------------------------------
-- helpers
-------------------------------------------------------------------------------
function ns.Round(v, d)
    local m = 10 ^ (d or 0)
    return math.floor(v * m + 0.5) / m
end

function ns.Clamp(v, lo, hi)
    if v < lo then return lo elseif v > hi then return hi end
    return v
end

--- Copper -> "12g 34s" (compact, coloured).
function ns.Money(copper, short)
    copper = math.floor((copper or 0) + 0.5)
    local g = math.floor(copper / 10000)
    local s = math.floor((copper % 10000) / 100)
    local c = copper % 100
    if short or g >= 100 then
        if g > 0 then return string.format("%d|cffffd700g|r", g) end
        if s > 0 then return string.format("%d|cffc7c7cfs|r", s) end
        return string.format("%d|cffeda55fc|r", c)
    end
    if g > 0 then return string.format("%d|cffffd700g|r %d|cffc7c7cfs|r", g, s) end
    if s > 0 then return string.format("%d|cffc7c7cfs|r %d|cffeda55fc|r", s, c) end
    return string.format("%d|cffeda55fc|r", c)
end

function ns.Pct(p, digits)
    if not p then return "-" end
    local v = p * 100
    if v >= 10 then return string.format("%.0f%%", v) end
    if v >= 1 then return string.format("%.1f%%", v) end
    if v >= 0.1 then return string.format("%.2f%%", v) end
    if v > 0 then return string.format("%.3f%%", v) end
    return "0%"
end

function ns.CopyTable(t, seen)
    if type(t) ~= "table" then return t end
    seen = seen or {}
    if seen[t] then return seen[t] end
    local out = {}
    seen[t] = out
    for k, v in pairs(t) do out[ns.CopyTable(k, seen)] = ns.CopyTable(v, seen) end
    return out
end

function ns.Count(t)
    local n = 0
    if t then for _ in pairs(t) do n = n + 1 end end
    return n
end

function ns.Now() return time() end

--- Base-36 coordinate codec used by the data files: 3 chars per axis, value = percent*100.
local B36 = "0123456789abcdefghijklmnopqrstuvwxyz"
local DEC = {}
for i = 1, 36 do DEC[B36:byte(i)] = i - 1 end
function ns.DecodeXY(s, i)
    local b = s.byte
    local x = (DEC[b(s, i)] * 1296 + DEC[b(s, i + 1)] * 36 + DEC[b(s, i + 2)]) / 10000
    local y = (DEC[b(s, i + 3)] * 1296 + DEC[b(s, i + 4)] * 36 + DEC[b(s, i + 5)]) / 10000
    return x, y
end
function ns.EncodeXY(x, y)
    local function e(v)
        v = ns.Clamp(math.floor(v * 10000 + 0.5), 0, 46655)
        local c3 = v % 36; v = (v - c3) / 36
        local c2 = v % 36; v = (v - c2) / 36
        return B36:sub(v + 1, v + 1) .. B36:sub(c2 + 1, c2 + 1) .. B36:sub(c3 + 1, c3 + 1)
    end
    return e(x) .. e(y)
end

--- NPC ID / object ID from a GUID ("Creature-0-S-I-Z-NPCID-SPAWN"). Server/spawn parts are
--- obfuscated on Forever since build 70425 but the format (and the ID field) is unchanged.
function ns.IDFromGUID(guid)
    guid = ns.Safe(guid)
    if type(guid) ~= "string" then return nil end
    local kind, _, _, _, _, id = strsplit("-", guid)
    id = tonumber(id)
    return id, kind
end

ns.CharKey = function()
    local name = ns.Safe(UnitName("player")) or "?"
    local realm = ns.Safe(GetRealmName()) or "?"
    return name .. "-" .. realm
end
