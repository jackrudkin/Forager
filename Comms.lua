-- Optional guild/party sharing of node finds (off by default). Never sends in instances.
local _, ns = ...
local Comms = {}
ns.Comms = Comms
local PREFIX = "Forager"
local queue, sending = {}, false

local function channels()
    local out = {}
    if ns.settings.shareGuild and IsInGuild() then out[#out + 1] = "GUILD" end
    if ns.settings.shareParty and IsInGroup() and not IsInRaid() then out[#out + 1] = "PARTY" end
    return out
end

local function pump()
    if #queue == 0 then sending = false return end
    sending = true
    local item = table.remove(queue, 1)
    pcall(C_ChatInfo.SendAddonMessage, PREFIX, item[1], item[2])
    ns.After(2, pump)
end

--- Share a node. Message: "N1|typeKey|uiMap|xxxyyy".
function Comms:Share(typeKey, uiMap, key)
    if ns.Player:InRestrictedContent() then return end
    local chans = channels()
    if #chans == 0 or not C_ChatInfo or not C_ChatInfo.SendAddonMessage then return end
    local msg = table.concat({ "N1", tostring(typeKey), tostring(uiMap), key }, "|")
    for _, ch in ipairs(chans) do
        if #queue < 50 then queue[#queue + 1] = { msg, ch } end
    end
    if not sending then pump() end
end

function Comms:Init()
    if not C_ChatInfo or not C_ChatInfo.RegisterAddonMessagePrefix then return end
    C_ChatInfo.RegisterAddonMessagePrefix(PREFIX)
    ns:On("CHAT_MSG_ADDON", function(_, prefix, msg, _, sender)
        prefix, msg = ns.Safe(prefix), ns.Safe(msg)
        if prefix ~= PREFIX or type(msg) ~= "string" then return end
        if not (ns.settings.shareGuild or ns.settings.shareParty) then return end
        local me = UnitName("player")
        sender = ns.Safe(sender)
        if sender and me and sender:match("^[^-]+") == me then return end
        local v, t, map, key = strsplit("|", msg)
        if v ~= "N1" or not key or #key ~= 6 or not key:match("^[0-9a-z]+$") then return end
        map = tonumber(map)
        t = tonumber(t) or t
        if not map or not ns.Zones[map] then return end
        if type(t) == "number" and not ns.NodeTypes[t] then return end
        if type(t) == "string" and not t:match("^i%d+$") then return end
        local zone = ns.db.shared[map] or {}
        ns.db.shared[map] = zone
        local rec = zone[key] or { t = t, c = 0, s = "shared" }
        rec.c = rec.c + 1
        rec.l = time()
        rec.from = sender
        zone[key] = rec
        ns.DS:Invalidate(map)
        ns:Fire("FORAGER_NODES_CHANGED", map)
    end)
end
