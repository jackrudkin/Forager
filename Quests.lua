-- Quests: active quest POIs and objective mob names for questing-zone mode.
-- Uses C_QuestLog (Mainline API; Forever shares it). Everything is optional: if an API is
-- missing or returns nothing, questing mode falls back to the zone's centre/mob areas.
local _, ns = ...
local Q = {}
ns.Quests = Q

--- { {x, y, questID, title}, ... } quest POIs on uiMap.
function Q:POIs(uiMap)
    local out = {}
    if not (C_QuestLog and C_QuestLog.GetQuestsOnMap) then return out end
    local ok, list = pcall(C_QuestLog.GetQuestsOnMap, uiMap)
    if not ok or type(list) ~= "table" then return out end
    for _, q in ipairs(list) do
        local x, y = ns.Safe(q.x), ns.Safe(q.y)
        if x and y then
            local title = C_QuestLog.GetTitleForQuestID and C_QuestLog.GetTitleForQuestID(q.questID)
            out[#out + 1] = { x = x, y = y, questID = q.questID, title = title }
        end
    end
    return out
end

--- Lower-cased mob names that appear in active objectives ("Kobold Vermin slain: 3/10").
function Q:ObjectiveNames()
    local names, list = {}, {}
    if not (C_QuestLog and C_QuestLog.GetNumQuestLogEntries) then return names, list end
    local n = C_QuestLog.GetNumQuestLogEntries() or 0
    for i = 1, n do
        local info = C_QuestLog.GetInfo(i)
        if info and not info.isHeader and info.questID then
            local objs = C_QuestLog.GetQuestObjectives(info.questID) or {}
            for _, o in ipairs(objs) do
                local text = ns.Safe(o.text)
                if text and not o.finished then
                    local name = text:match("^(.-)%s+slain") or text:match("^%d+/%d+%s+(.+)$") or text:match("^(.-):%s*%d+/%d+")
                    if name then
                        names[name:lower()] = info.title or true
                        list[#list + 1] = { name = name, quest = info.title, questID = info.questID }
                    end
                end
            end
        end
    end
    return names, list
end

--- Questing zone(s) for this character: primary (or current zone if "auto") and optional second.
function Q:Zones()
    local z1 = ns.char.questZone
    if z1 == "auto" then z1 = ns.Player:MapID() end
    return z1, ns.char.questZone2
end

function Q:IsActive() return ns.char.questZone ~= nil end

function Q:Set(z1, z2)
    ns.char.questZone, ns.char.questZone2 = z1, z2
    ns:Fire("FORAGER_QUESTZONE_CHANGED")
end
