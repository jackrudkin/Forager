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
-- Herbalism/Mining node thresholds follow Classic (Forever wiki lists the same numbers for ore).
ns.SkillOffsets = { 25, 50, 100 }
ns.SkillUpChance = { orange = 1.0, yellow = 0.75, green = 0.25, grey = 0 }

--- Skinning skill needed for a mob of the given level (Forever wiki formula).
function ns.SkinSkillForLevel(level)
    level = level or 1
    if level <= 10 then return 1 end
    if level <= 20 then return (level - 10) * 10 end
    return level * 5
end

--- "orange"/"yellow"/"green"/"grey"/"red" for a skill requirement vs player skill.
function ns.SkillColor(required, have)
    if not have then return "red" end
    if have < required then return "red" end
    local o = ns.SkillOffsets
    if have < required + o[1] then return "orange" end
    if have < required + o[2] then return "yellow" end
    if have < required + o[3] then return "green" end
    return "grey"
end

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
