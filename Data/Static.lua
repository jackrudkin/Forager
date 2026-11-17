-- Static reference tables (hand-written). Classic-era values unless noted.
local _, ns = ...

-- Gather/loot spells. Forever may use different IDs, so Capture also matches by the
-- localized spell name of these IDs (C_Spell.GetSpellName).
ns.GatherSpells = {
    herb = { 2366, 2368, 3570, 11993 },          -- Herb Gathering
    ore = { 2575, 2576, 3564, 10248 },           -- Mining
    skin = { 8613, 8617, 8618, 10768 },          -- Skinning
    fish = { 7620, 7731, 7732, 18248 },          -- Fishing
    pick = { 921 },                              -- Pick Pocket
    lock = { 1804 },                             -- Pick Lock
}

-- Profession skill lines (GetProfessionInfo 7th return).
ns.SkillLines = { herb = 182, ore = 186, skin = 393, fish = 356, cook = 185 }

-- Junkboxes from Pick Pocket and the Lockpicking skill they need (Forever guides: same as Classic).
ns.Junkboxes = { [16882] = 1, [16883] = 70, [16884] = 175, [16885] = 250 }

-- Skill colour offsets above the required (orange) skill: yellow, green, grey.
-- Mining and Skinning: same as Classic (warcraft.wiki.gg Forever mining/skinning techniques).
-- Herbalism: Forever moved the yellow -> green step 15 points later, so herbs stay yellow up to
-- required + 65 (warcraft.wiki.gg "Forever herbalism techniques" herb table, e.g. Peacebloom 1/25/65/100).
ns.SkillOffsets = { 25, 50, 100 }
ns.SkillOffsetsByKind = { herb = { 25, 65, 100 }, ore = { 25, 50, 100 }, skin = { 25, 50, 100 } }
-- Nodes whose wiki thresholds don't follow the offsets: { yellow, green, grey } as absolute skill.
ns.SkillThresholds = { ["Dreamfoil"] = { 290, 340, 370 } }
ns.SkillUpChance = { orange = 1.0, yellow = 0.75, green = 0.25, grey = 0 }

-- Gather cast times in seconds (Classic spell data, classicdb.ch: Herb Gathering 5 s, Mining 3.2 s).
-- Forager measures your own casts and uses those once it has 10 of a kind.
ns.CastSeconds = { herb = 5.0, ore = 3.2 }

--- Skinning skill needed for a mob of the given level (Forever wiki formula).
function ns.SkinSkillForLevel(level)
    level = level or 1
    if level <= 10 then return 1 end
    if level <= 20 then return (level - 10) * 10 end
    return level * 5
end

--- "orange"/"yellow"/"green"/"grey"/"red" for a skill requirement vs player skill.
--- kind (herb/ore/skin) picks the Forever offsets; abs = { yellow, green, grey } overrides them.
function ns.SkillColor(required, have, kind, abs)
    if not have then return "red" end
    if have < required then return "red" end
    local y, g, gr
    if abs then
        y, g, gr = abs[1], abs[2], abs[3]
    else
        local o = (kind and ns.SkillOffsetsByKind[kind]) or ns.SkillOffsets
        local base = required <= 1 and 0 or required -- skill-1 nodes: 1/25/50/100 on the wiki
        y, g, gr = base + o[1], base + o[2], base + o[3]
    end
    if have < y then return "orange" end
    if have < g then return "yellow" end
    if have < gr then return "green" end
    return "grey"
end

--- Skill colour of a node type for a skill value.
function ns.NodeSkillColor(t, have)
    return ns.SkillColor(t.skill or 0, have, t.kind, ns.SkillThresholds[t.name])
end

-- Scarce materials (new in Forever): bonus finds while gathering, three tiers per profession.
-- Item IDs and vendor prices: wowgoldfarms.com Forever scarce materials table (TheWoWDB links).
-- No source publishes drop rates for herbs or ore, so Forager learns them from your own gathers.
ns.Scarce = {
    [249399] = { name = "Frilled Lichen", kind = "herb", tier = 1, vendor = 30 },
    [249424] = { name = "Rosecap", kind = "herb", tier = 2, vendor = 95 },
    [249274] = { name = "Stranglevine", kind = "herb", tier = 3, vendor = 250 },
    [249391] = { name = "Pyrite", kind = "ore", tier = 1, vendor = 100 },
    [249425] = { name = "Bauxite", kind = "ore", tier = 2, vendor = 250 },
    [249426] = { name = "Pitchblende", kind = "ore", tier = 3, vendor = 375 },
    [249427] = { name = "Pristine Leather", kind = "skin", tier = 1, vendor = 125 },
    [249428] = { name = "Pristine Hide", kind = "skin", tier = 2, vendor = 250 },
    [249429] = { name = "Pristine Scale", kind = "skin", tier = 3, vendor = 375 },
}
-- Which node gives which Scarce item: herbs from the warcraft.wiki.gg herb table; ore from the
-- warcraft.wiki.gg ore table (Copper/Tin/Silver: Pyrite, Iron/Mithril: Bauxite) plus Thorium:
-- Pitchblende (wow-professions.com; the wiki lists Thorium as unknown).
ns.ScarceForNode = {}
do
    local byItem = {
        [249399] = { "Earthroot", "Mageroyal", "Briarthorn", "Stranglekelp", "Bruiseweed", "Wild Steelbloom", "Kingsblood" },
        [249424] = { "Liferoot", "Fadeleaf", "Goldthorn", "Khadgar's Whisker", "Wintersbite", "Firebloom", "Purple Lotus" },
        [249274] = { "Sungrass", "Blindweed", "Ghost Mushroom", "Gromsblood", "Golden Sansam", "Dreamfoil",
            "Mountain Silversage", "Plaguebloom", "Icecap" },
        [249391] = { "Copper Vein", "Tin Vein", "Silver Vein", "Ooze Covered Silver Vein" },
        [249425] = { "Iron Deposit", "Ooze Covered Iron Deposit", "Mithril Deposit", "Ooze Covered Mithril Deposit" },
        [249426] = { "Small Thorium Vein", "Ooze Covered Thorium Vein", "Rich Thorium Vein", "Ooze Covered Rich Thorium Vein" },
    }
    for id, names in pairs(byItem) do for _, n in ipairs(names) do ns.ScarceForNode[n] = id end end
end
-- Skinning Scarce with a published source: Pristine Leather from beasts level 10-26
-- (classicwowforever.com). Starting rate: one community log, 29 from 1,000 Barrens beasts at
-- level 22-26 (nerdflakes.com). Your own skins replace it from 100 skins in that band.
ns.ScarceSkin = {
    { id = 249427, ctype = 1, minLevel = 10, maxLevel = 26, rate = 0.029, n = 1000 },
}

-- Herb seeds (new in Forever): bonus finds from herb nodes, four tiers. Which herb nodes give which
-- tier: QuestieDB Forever item traces (objectDrops). Vendor prices: Forever item database pages
-- (Nov 2026); only a fallback, the game's own sell price is used once the item is cached.
-- No published rates: Forager learns them from your gathers (pooled over the herbs of a tier).
ns.HerbSeeds = {
    { id = 268415, name = "Commonplace Herb Seeds", vendor = 10, objects = { 1617, 1618, 1619, 657380, 657382, 657383 } },
    { id = 268416, name = "Uncommon Herb Seeds", vendor = 25,
        objects = { 1620, 1621, 1622, 1623, 1624, 1628, 2045, 657385, 657386, 657387, 657388, 657394 } },
    { id = 268417, name = "Unusual Herb Seeds", vendor = 90, objects = { 2041, 2042, 2043, 2044, 657390, 657391, 657392, 657393 } },
    { id = 268418, name = "Scarce Herb Seeds", vendor = 115, objects = { 2046, 2866, 142140, 142141, 142142, 142143, 142144,
        142145, 176583, 176584, 176586, 176587, 176588, 657395, 657397, 657398, 657399, 657401 } },
}
ns.KnownItems = {} -- small items Forager knows without the data addon: [id] = { name, vendor }
for id, e in pairs(ns.Scarce) do ns.KnownItems[id] = { e.name, e.vendor } end
for _, e in ipairs(ns.HerbSeeds) do ns.KnownItems[e.id] = { e.name, e.vendor } end

-- Spawn-rate hotfixes since launch (Blizzard hotfix notes; qualitative, the bundled Classic data
-- does not include them). Shown on spots in these zones.
ns.HotfixNotes = {
    [1434] = "Hotfix (Nov 13): tigers, panthers and raptors spawn more often",
    [1418] = "Hotfix (Nov 13): Lesser Rock Elementals spawn more often",
    [1412] = "Hotfix (Nov 13): fewer Quillboar and Venture Co. in the starting area",
    [1419] = "Hotfix (Nov 13): Nethergarde guards no longer drop loot",
    [1426] = "Hotfix: Grol'bolar troggs no longer respawn too quickly",
    [1445] = "Hotfix: murlocs no longer respawn too quickly",
}

-- Gathering tools that must be in your bags, and the resource tracking spells.
ns.Tools = { ore = 2901, skin = 7005 }            -- Mining Pick, Skinning Knife
ns.TrackSpells = { herb = 2383, ore = 2580 }      -- Find Herbs, Find Minerals

ns.ColorHex = {
    red = "ff2020", orange = "ff8040", yellow = "ffff00", green = "40c040", grey = "808080",
    [0] = "9d9d9d", [1] = "ffffff", [2] = "1eff00", [3] = "0070dd", [4] = "a335ee", [5] = "ff8000",
}
ns.ColorRGB = {
    red = { 1, 0.13, 0.13 }, orange = { 1, 0.5, 0.25 }, yellow = { 1, 1, 0 }, green = { 0.25, 0.75, 0.25 },
    grey = { 0.5, 0.5, 0.5 },
}

-- Disenchanting (Classic armour split; weapons are essence-heavy, so this is approximate).
-- { minIlvl, maxIlvl, {dustID, avg, chance}, {essenceID, avg, chance}, {shardID, avg, chance} }
ns.Disenchant = {
    { 5, 15, { 10940, 1.5, 0.80 }, { 10938, 1.5, 0.20 } },
    { 16, 20, { 10940, 2.5, 0.75 }, { 10939, 1.5, 0.20 }, { 10978, 1, 0.05 } },
    { 21, 25, { 10940, 5, 0.75 }, { 10998, 1.5, 0.15 }, { 10978, 1, 0.10 } },
    { 26, 30, { 11083, 1.5, 0.75 }, { 11082, 1.5, 0.20 }, { 11084, 1, 0.05 } },
    { 31, 35, { 11083, 3.5, 0.75 }, { 11134, 1.5, 0.20 }, { 11138, 1, 0.05 } },
    { 36, 40, { 11137, 1.5, 0.75 }, { 11135, 1.5, 0.20 }, { 11139, 1, 0.05 } },
    { 41, 45, { 11137, 3.5, 0.75 }, { 11174, 1.5, 0.20 }, { 11177, 1, 0.05 } },
    { 46, 50, { 11176, 1.5, 0.75 }, { 11175, 1.5, 0.20 }, { 11178, 1, 0.05 } },
    { 51, 55, { 11176, 3.5, 0.75 }, { 16202, 1.5, 0.20 }, { 14343, 1, 0.05 } },
    { 56, 60, { 16204, 1.5, 0.75 }, { 16203, 1.5, 0.20 }, { 14344, 1, 0.05 } },
    { 61, 99, { 16204, 3.5, 0.75 }, { 16203, 2.5, 0.20 }, { 14344, 1, 0.05 } },
}
-- Blue items disenchant to one shard of their tier (approximation).
ns.DisenchantBlue = {
    { 1, 25, 10978 }, { 26, 30, 11084 }, { 31, 35, 11138 }, { 36, 40, 11139 },
    { 41, 45, 11177 }, { 46, 50, 11178 }, { 51, 55, 14343 }, { 56, 99, 14344 },
}
ns.EnchantNames = {
    [10940] = "Strange Dust", [10938] = "Lesser Magic Essence", [10939] = "Greater Magic Essence",
    [10978] = "Small Glimmering Shard", [10998] = "Lesser Astral Essence", [11082] = "Greater Astral Essence",
    [11084] = "Large Glimmering Shard", [11083] = "Soul Dust", [11134] = "Lesser Mystic Essence",
    [11135] = "Greater Mystic Essence", [11138] = "Small Glowing Shard", [11139] = "Large Glowing Shard",
    [11137] = "Vision Dust", [11174] = "Lesser Nether Essence", [11175] = "Greater Nether Essence",
    [11177] = "Small Radiant Shard", [11178] = "Large Radiant Shard", [11176] = "Dream Dust",
    [16202] = "Lesser Eternal Essence", [16203] = "Greater Eternal Essence", [14343] = "Small Brilliant Shard",
    [14344] = "Large Brilliant Shard", [16204] = "Illusion Dust",
}

-- Creature types (cmangos numbering) -> label
ns.CreatureTypes = { "Beast", "Dragonkin", "Demon", "Elemental", "Giant", "Undead", "Humanoid", "Critter", "Mechanical", "Not specified" }

-- Goals offered by the finder. kind: node (herb/ore), mob (value function), fish.
ns.Goals = {
    { key = "herb", label = "Herbalism", kind = "node", prof = "herb", icon = "Interface\\Icons\\Trade_Herbalism" },
    { key = "ore", label = "Mining", kind = "node", prof = "ore", icon = "Interface\\Icons\\Trade_Mining" },
    { key = "skin", label = "Skinning", kind = "mob", prof = "skin", icon = "Interface\\Icons\\INV_Misc_Pelt_Wolf_01" },
    { key = "fish", label = "Fishing", kind = "fish", prof = "fish", icon = "Interface\\Icons\\Trade_Fishing" },
    { key = "cloth", label = "Cloth", kind = "mob", icon = "Interface\\Icons\\INV_Fabric_Linen_01" },
    { key = "greens", label = "Greens to disenchant", kind = "mob", icon = "Interface\\Icons\\INV_Enchant_DustStrange" },
    { key = "leather", label = "Leather / hides", kind = "mob", prof = "skin", icon = "Interface\\Icons\\INV_Misc_LeatherScrap_03" },
    { key = "meat", label = "Meat (Cooking)", kind = "mob", icon = "Interface\\Icons\\INV_Misc_Food_14" },
    { key = "elemental", label = "Elemental mats", kind = "mob", icon = "Interface\\Icons\\Spell_Fire_Volcano" },
    { key = "lockbox", label = "Lockboxes (Rogue)", kind = "mob", prof = "lock", icon = "Interface\\Icons\\INV_Box_02" },
    { key = "gold", label = "Raw gold (all loot)", kind = "mob", icon = "Interface\\Icons\\INV_Misc_Coin_01" },
}
ns.GoalByKey = {}
for _, g in ipairs(ns.Goals) do ns.GoalByKey[g.key] = g end

-- Travel speed presets in yards/second.
ns.Speeds = { run = 7, mount60 = 11.2, mount100 = 14 }

-- Short labels for the category chips.
do
    local short = { herb = "Herbs", ore = "Ore", skin = "Skinning", fish = "Fishing", cloth = "Cloth", greens = "Greens (DE)",
        leather = "Leather", meat = "Meat", elemental = "Elemental", lockbox = "Lockboxes", gold = "Raw gold" }
    for _, g in ipairs(ns.Goals) do g.short = short[g.key] or g.label end
end

-- Location filter for the finder and the Mobs tab.
ns.Locations = {
    { key = "any", label = "Anywhere" },
    { key = "cave", label = "Caves & mines" },
    { key = "outdoor", label = "Outdoors" },
}
-- Words that mark a subzone as a cave/mine (English client; zone cave lists come from the data).
ns.CaveKeywords = { "mine", "cave", "cavern", "grotto", "den", "barrow", "burrow", "hollow", "lair", "tunnel", "quarry", "dig site", "excavation" }

-- UI theme
ns.Theme = {
    bg = { 0.055, 0.055, 0.065, 0.97 },
    panel = { 0.09, 0.09, 0.105, 1 },
    panel2 = { 0.12, 0.12, 0.14, 1 },
    border = { 0.22, 0.22, 0.26, 1 },
    accent = { 0.50, 0.83, 0.42, 1 },
    accentDark = { 0.22, 0.42, 0.20, 1 },
    gold = { 1, 0.82, 0, 1 },
    text = { 0.92, 0.92, 0.92, 1 },
    muted = { 0.60, 0.60, 0.64, 1 },
    cave = { 0.62, 0.48, 0.95, 1 },
    route = { 0.20, 0.85, 1.00, 1 },
    area = { 1.00, 0.82, 0.00, 1 },
}
