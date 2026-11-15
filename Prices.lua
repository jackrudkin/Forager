-- Prices: AuctionTrends (optional) -> Auctionator (optional) -> vendor. Read-only; never touches
-- Auctionator's data or frames.
local _, ns = ...
local Prices = {}
ns.Prices = Prices

local cache, cacheTime = {}, 0

local function fromAuctionTrends(itemID)
    local api = AuctionTrends and AuctionTrends.API
    if not api or not api.GetMarketValue then return nil end
    local ok, v = pcall(api.GetMarketValue, itemID)
    if ok and type(v) == "number" and v > 0 then return v end
end

local function fromAuctionator(itemID)
    local api = Auctionator and Auctionator.API and Auctionator.API.v1
    if not api or not api.GetAuctionPriceByItemID then return nil end
    local ok, v = pcall(api.GetAuctionPriceByItemID, "Forager", itemID)
    if ok and type(v) == "number" and v > 0 then return v end
end

local sources = {
    AuctionTrends = fromAuctionTrends,
    Auctionator = fromAuctionator,
    Vendor = function(itemID) local v = ns.DS:ItemVendor(itemID) return v > 0 and v or nil end,
}

--- Price in copper and the source name. Cached for 60 s.
function Prices:Get(itemID)
    if not itemID or itemID == 0 then return 0, "none" end
    local now = GetTime()
    if now - cacheTime > 60 then wipe(cache) cacheTime = now end
    local c = cache[itemID]
    if c then return c[1], c[2] end
    for _, name in ipairs(ns.settings.priceSources or { "AuctionTrends", "Auctionator", "Vendor" }) do
        local fn = sources[name]
        local v = fn and fn(itemID)
        if v then
            cache[itemID] = { v, name }
            return v, name
        end
    end
    cache[itemID] = { 0, "none" }
    return 0, "none"
end

--- Sales rate from AuctionTrends if available: soldPerDay, goldPerDay (copper), daysSupply.
function Prices:SalesRate(itemID)
    local api = AuctionTrends and AuctionTrends.API
    if not api or not api.GetSalesRate then return nil end
    local ok, a, b, c = pcall(api.GetSalesRate, itemID)
    if ok then return a, b, c end
end

function Prices:Available()
    local out = {}
    if AuctionTrends and AuctionTrends.API then out[#out + 1] = "AuctionTrends" end
    if Auctionator and Auctionator.API and Auctionator.API.v1 then out[#out + 1] = "Auctionator" end
    out[#out + 1] = "Vendor"
    return out
end

--- Expected value (copper) of disenchanting one green / blue of the given item level.
function Prices:DisenchantValue(ilvl, quality)
    ilvl = ilvl or 1
    local v, best = Prices:RawDisenchantValue(ilvl, quality)
    if v > 0 then return v, best end
    -- no AH prices for enchanting mats: fall back to an estimate of the item's vendor price
    return 0.7 * ilvl * ilvl * (quality == 3 and 1.5 or 1), best
end

function Prices:RawDisenchantValue(ilvl, quality)
    if quality == 3 then
        for _, row in ipairs(ns.DisenchantBlue) do
            if ilvl >= row[1] and ilvl <= row[2] then return (Prices:Get(row[3])), row[3] end
        end
        return 0
    end
    for _, row in ipairs(ns.Disenchant) do
        if ilvl >= row[1] and ilvl <= row[2] then
            local v, best, bestP = 0, nil, 0
            for i = 3, #row do
                local id, avg, p = row[i][1], row[i][2], row[i][3]
                v = v + Prices:Get(id) * avg * p
                if p > bestP then best, bestP = id, p end
            end
            return v, best
        end
    end
    return 0
end

--- Expected disenchant result text for an item level, e.g. "75% Soul Dust x1.5, 20% ...".
function Prices:DisenchantText(ilvl)
    for _, row in ipairs(ns.Disenchant) do
        if ilvl >= row[1] and ilvl <= row[2] then
            local parts = {}
            for i = 3, #row do
                parts[#parts + 1] = string.format("%d%% %s x%g", row[i][3] * 100, ns.DS:ItemName(row[i][1]), row[i][2])
            end
            return table.concat(parts, ", ")
        end
    end
    return "-"
end
