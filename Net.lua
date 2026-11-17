-- Net: what a gold estimate is worth to you. The finders value every item at its full price (gross);
-- this applies, per result:
--   1. calibration: how your actual farm sessions compared with the estimate (this spot, else spots
--      of the same kind), see Learn:Calibration
--   2. the 5% auction house cut on items priced from the auction house (vendor-priced items: none)
--   3. your measured repair cost per kill x kills per hour
-- AH deposits are left out: the minimum deposit is 1c since the Nov 17 maintenance and deposits are
-- returned when an item sells.
local _, ns = ...
local Net = {}
ns.Net = Net
Net.AH_CUT = 0.05

local function ahPriced(it)
    if it.coin then return false end
    if it.greens then return true end -- disenchanting mats or the items themselves go to the AH
    if not it.id then return false end
    local _, src = ns.Prices:Get(it.id)
    return src ~= "Vendor" and src ~= "none"
end

local function itemGoal(r) return type(r.goal) == "string" and r.goal:find("^item:") ~= nil end

--- Adjust one result in place (once). Sets estGross (gross copper/h, for calibration), calib,
--- calibHours, calibSrc, ahCut, repairs, and scales perHour and item values in gold mode.
function Net:Apply(r)
    if not r or r.netDone then return r end
    r.netDone = true
    local s = ns.settings
    local gross, ahGross = 0, 0
    for _, it in ipairs(r.items or {}) do
        local v = it.value or 0
        gross = gross + v
        if v > 0 and ahPriced(it) then ahGross = ahGross + v it.ah = true end
    end
    r.estGross = (not itemGoal(r)) and gross or nil -- item searches leave out the rest of the loot
    if r.mode ~= "gold" or (r.perHour or 0) <= 0 then return r end
    local f, h, src = 1, 0, nil
    if s.calibrate ~= false and r.estGross then f, h, src = ns.Learn:Calibration(ns.Learn.FarmKey(r), ns.Learn.FarmGroup(r)) end
    local cut, repairs = 0, 0
    if s.netGold ~= false then
        cut = ahGross * f * Net.AH_CUT
        local kills = r.killsPerHour or (r.source == "mob" and r.unitsPerHour) or 0
        repairs = (ns.Learn:RepairPerKill()) * kills
    end
    if src then r.calib, r.calibHours, r.calibSrc = f, h, src end
    r.ahCut, r.repairs = cut, repairs
    local before = r.perHour
    r.grossPerHour = before
    r.perHour = math.max(0, before * f - cut - repairs)
    for _, it in ipairs(r.items or {}) do
        it.value = (it.value or 0) * f * (it.ah and s.netGold ~= false and (1 - Net.AH_CUT) or 1)
        it.perHour = (it.perHour or 0) * f
    end
    if r.itemUnits then r.itemUnits = r.itemUnits * f end
    -- Gather + Kill breakdown: same proportion as the total
    local k = before > 0 and r.perHour / before or 1
    for _, key in ipairs({ "nodeRate", "mobRate", "nodeGold", "skinGold", "lootGold", "gold", "nodesOnlyRate", "mobsOnlyRate" }) do
        if r[key] then r[key] = r[key] * k end
    end
    if r.score then r.score = r.score * k end
    return r
end

function Net:ApplyAll(list)
    for _, r in ipairs(list or {}) do Net:Apply(r) end
    return list
end

--- Tooltip lines explaining a result's gold estimate.
function Net:Lines(r)
    local out = {}
    if not r or r.mode ~= "gold" then return out end
    if r.grossPerHour then out[#out + 1] = { "Estimate (full prices)", ns.Money(r.grossPerHour, true) .. "/h" } end
    if r.calib then
        out[#out + 1] = { string.format("Calibrated x%.2f", r.calib),
            string.format("%.1f h farmed %s", r.calibHours or 0, r.calibSrc == "spot" and "here" or "on similar spots") }
    end
    if (r.ahCut or 0) > 0 then out[#out + 1] = { "AH cut 5%", "-" .. ns.Money(r.ahCut, true) .. "/h" } end
    if (r.repairs or 0) > 0 then out[#out + 1] = { "Repairs (measured)", "-" .. ns.Money(r.repairs, true) .. "/h" } end
    out[#out + 1] = { "You keep", ns.Money(r.perHour, true) .. "/h" }
    return out
end
