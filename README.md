# Forager (WoW Forever)

Tells you where to farm any gathering profession, material or single item (including inside caves and mines), draws an optimised route on the world map and minimap, shows what every mob drops ranked by gold per kill, and adds loot, skinning and gear-grade chances to mob tooltips.

Built for **WoW Forever 1.60.1** (`## Interface: 16001`, Mainline 12.x API). Forever only.

## What's new in 1.8: Realistic spots

Tick **Realistic spots** in the Farm or Gather + Kill tab (or type `/forage realistic`) to see only spots you can farm solo at your level. The two tabs share the setting, and it's remembered.

| Rule | Why |
|---|---|
| No mob more than 2 levels above you in or near the area | Yellow mobs are within 2 levels of you; orange is 3–4 above, red 5–9, skull 10+ (wowpedia difficulty colours) |
| No elites in or near the area | Elites aren't soloable at their level |
| Death and hyperspawn risk each below High, and Low/Medium together | No tight packs of higher mobs or very dense spawns |
| Gank risk below Very high (PvP ruleset) | No enemy territory and no enemy camp within 300 yd. Contested zones stay |

- The search steers around dangerous ground. Zone grid cells near too-hard mobs (and near enemy camps on PvP) are skipped when picking areas and routes.
- It also checks spare areas, so a zone's best realistic spot replaces one that fails.
- Mobs that are too hard are never picked as farm targets or as mobs worth killing.
- If nothing is left, the panel says how many spots were hidden and why.

Example in testing: level 25 with Mining 150. Without it, the top ore spots were Arathi Highlands and Alterac Mountains, with mobs 14–25 levels above you. With it, they're Wetlands, Westfall and Duskwood, all Low or Medium risk.

Tip: if you play on a Normal (PvE) ruleset, set **Settings → Your ruleset → Normal**. Until Forager has seen you unflagged in a contested zone, it assumes PvP and adds gank risk.

## What's new in 1.7: more accurate numbers

The data was researched against Forever sources. Wherever Forever data exists it now replaces the Classic values, and from now on Forager learns from your own play. See [Data sources & accuracy](#data-sources--accuracy).

| Change | Before | Now |
|---|---|---|
| Time at each node | Flat 3 s per node, even for mining veins that take several gathers | Cast time × gathers per node. Herb Gathering is 5 s and Mining 3.2 s per gather (Classic spell data). Forager measures your own casts and loot time, and uses them from 10 casts |
| Herbalism skill colours | Classic: green from required +50 | Forever: herbs stay yellow until required +65 (warcraft.wiki.gg herb table). Dreamfoil uses its own 270/290/340/370 |
| Yields per node | CMaNGOS Classic loot tables only | Your own yields per node type take over at n ≥ 30 visits (setting). This includes Scarce finds and Forever's real number of gathers per vein. Gathers you logged before 1.7 seed this |
| Scarce materials | Not counted | All nine are known (IDs, vendor prices): Frilled Lichen, Rosecap, Stranglevine, Pyrite, Bauxite, Pitchblende, Pristine Leather/Hide/Scale. Herb and ore rates aren't published anywhere, so Forager learns them (pooled per material, from 100 gathers). Pristine Leather starts at 2.9% for beasts level 10–26 |
| Skins | Classic table | Your own skins of a mob, quantities included, take over at n ≥ 30. Skinning time uses your measured skins from 10 |
| Prices | AuctionTrends → Auctionator → vendor | **TradeSkillMaster** added: AuctionTrends → Auctionator → TSM → vendor. TSM price is DBMarket by default, or DBMinBuyout / DBRecent / DBRegionMarketAvg (Settings) |
| Source label | "Classic spawns" | Results say whether yields are your own data: "Classic spawns · your yields" |

The **Seconds per gather** setting is now **Extra seconds per node** (dismount, walk in), default 1 s, because casts and loot are timed separately. Settings and node data upgrade automatically.

## What's new in 1.6: risk level

Every spot in Farm, Gather + Kill and Mobs & Drops ("Farm this mob") now shows a **risk level**: Low / Medium / High / Very high. Hover it to see why. See [Risk level](#risk-level).

Also fixed: creatures friendly to your faction (guards, villagers, vendors) are no longer counted as farm targets or as danger. The database now records which faction each NPC belongs to.

## What's new in 1.5: skinning in Gather + Kill

| Change | Details |
|---|---|
| Skins counted separately | Gold is split three ways: gathering, **skins** and other mob loot. Skins only count for mobs your Skinning is high enough for (Forever formula); "too high" mobs show in red. |
| Skinning costs time | New **Seconds per skin** slider (default 3 s), added only for mobs you skin. |
| Kill: All mobs / Skinnable only | **Skinnable only** = Mining + skinning: only mobs you can skin are considered. |
| Rank by Skill-ups / hour | Gathering skill-ups plus Skinning skill-ups per hour (orange 100%, yellow 75%, green 25%), same best-ratio choice of mobs; gold earned on the side is still shown. |
| More detail | Skins per hour, the skinning skill for each worthwhile mob, and skill-ups gained on the way (gold mode) or gold on the side (skill mode). |

## What's new in 1.4: Gather + Kill

A new **Gather + Kill** tab finds areas where mining and/or herbalism plus killing the mobs on the way pays more than either alone. See [Gather + Kill](#gather--kill).

## What's new in 1.3

| Change | Details |
|---|---|
| No node pins | Forager no longer draws anything on nodes: no icons or dots on the minimap or world map, farming or not. Nodes are the game's own tracking (Find Herbs / Find Minerals). |
| Just the route | World map: a thin route line through the farm, nothing else. Minimap: a line from you to the next stop and the next few legs, fading out (or Off / Whole loop). |
| Fewer extras by default | Farm area outline, game map pin and TomTom arrow are off by default (toggles in Route & Map or Settings). **Set waypoint** still places the game pin on demand. |

Settings from earlier versions are upgraded automatically, and the old pin settings are removed.

**1.3.1:** **Show on world map** now shows the route with OpenMap. Forager uses OpenMap's API to position the line and draws it above OpenMap's map art, which had been covering it. With OpenMap's map showing, the view glides to the farm area. The Forager window hides while the map is open and comes back when you close the map. A preview clears when the map closes.

## What's new in 1.1

| Change | Details |
|---|---|
| World map is no longer covered in nodes | Default shows only the nodes of the spot you're farming or previewing. **Off / Farm only / All** for the world map and the minimap, in Route & Map or Settings. |
| Route now shows reliably | Numbered stops are HereBeDragons pins, and area/route lines are translated to whatever map is open: zone, continent or OpenMap. Draw errors are caught and shown in `/forage diag`. |
| "Open world map" opens at your farm | It opens straight to the farm zone with the area, route and stops drawn. Starting a farm also places the game's own map pin there, plus a TomTom arrow if TomTom is installed. |
| New look | Dark flat window with a sidebar, a **Now farming** card, result cards with a zone map preview, and a movable route HUD (arrow, distance, Skip/Map/Stop). |
| Farm anything | Type any item in **What do you want to farm?** (e.g. *Copper Ore*, *Linen Cloth*). Forager ranks node areas, mob camps and fishing zones for that item. |
| Caves & mines | A **Location** filter (Anywhere / Caves & mines / Outdoors) in Farm and in Mobs & Drops. See [Caves & mines](#caves--mines). |
| Mobs & Drops | Every mob in your zone (or all zones for your level) ranked by **gold per kill**, with cave name, best drop, green/blue %, skin skill and **Farm this mob**. |
| `/forage diag` | Prints what Forager sees (map IDs, translation, APIs, OpenMap/TomTom, last draw error) to paste into a bug report. |

## Install

1. Extract the zip into `World of Warcraft\_forever_\Interface\AddOns\`. You get three folders:
   - `Forager\Forager.toc`: the addon.
   - `Forager_Backup\Forager_Backup.toc`: storage-only addon that keeps a second copy of your data in its own file.
   - `Forager_Data\Forager_Data.toc`: the bundled node/mob/loot database, loaded on demand.

   Each `.toc` must sit directly inside its folder (not `Forager\Forager\`).
2. Restart the game or `/reload`, then tick **Forager**, **Forager Backup** and **Forager Data** in the AddOns list.
3. If Forever patches and the addon shows "Out of date", tick **Load out of date AddOns**, or edit the `## Interface:` line (`/dump (select(4, GetBuildInfo()))` gives the new number).
4. If you use GatherMate2 or GatherLite, Forager imports their saved nodes automatically to improve its rankings (or type `/forage import`).

## How data is collected

| Source | What it gives | Confidence label |
|---|---|---|
| **QuestieDB Forever data** (GPLv3) | ~24,600 herb, ore and fishing-pool spawn points and ~4,200 mob spawn sets. These are Classic spawns converted to Forever map coordinates. | "Classic spawns" |
| **CMaNGOS classic-db** (GPLv3) | Loot, skinning, pick pocket, node yield and fishing tables. Item quality and vendor prices. | "Classic estimate" |
| **Your play** | Every gather, skin, pick pocket and creature loot, with zone and coordinates | "my data n=…" |
| **Guild/party sharing** (off by default) | Node finds from other Forager users | "Shared" |
| **GatherMate2 / GatherLite import** | Their saved nodes (while those addons are enabled) | "Imported" |

**What's missing from the bundled data:** nodes in Forever's new zones (Mount Hyjal, Riverglades, Shen'dralas, Zephras Isle, Darkspear Islands) and new node types (Marefoil, Demonsage, Death Lotus, Heavy Thorium, Poor Copper, Wilted Peacebloom, Stunted Silverleaf). These fill in as you gather. A node type Forager doesn't know is learned from the item it gives and named after that item.

**Why GatherLite's database isn't bundled:** its Forever coordinates were scraped from Wowhead, and Wowhead's terms forbid scraping. GatherMate2_Data has the same problem. Importing your own saved nodes from either addon is fine.

**How captures work:** a gather spell (Herb Gathering, Mining, Fishing, Skinning, Pick Pocket) followed by a loot window is recorded. Spells are matched by ID and, as a fallback, by localized name, so Forever's own spell IDs are learned automatically. The node type comes from the loot source's GameObject ID, or from the main item. Creature loot is grouped per corpse GUID and counted once per corpse. Any value the client returns as secret is skipped without an error.

## Nodes on the map

Forager draws no node pins. Live nodes show through the game's own tracking (Find Herbs / Find Minerals), as without the addon. Spawn points from the database, your gathers, guild sharing and imports are still used to rank spots and build routes, and you can browse them in the Nodes tab.

## Window (`/forage`)

The sidebar has seven tabs. Below them, the **Now farming** card shows the active farm with **Map** and **Stop** buttons. The status bar at the bottom shows your search scope, session gold/hour and price sources.

| Tab | What's there |
|---|---|
| **Farm** | **What do you want to farm?** search box (category, item or mob; suggestions as you type). Category chips: Herbs, Ore, Skinning, Fishing, Cloth, Greens (DE), Leather, Meat, Elemental, Lockboxes, Raw gold. **Rank by** Gold/hour or Skill-ups/hour. **Location**: Anywhere / Caves & mines / Outdoors. **Search in**: Everywhere (your level), Current zone (follows you), or a zone you're questing in. **Enemy zones** and **Realistic spots** toggles. Below that is a ranked list of cards (zone · subzone/cave, rate, mob levels or node skill, risk, loot icons). The detail panel has a zone map preview with the area, spawns, route and your position; what you get per hour (quantity and value per item); the mobs or nodes in the area; and buttons for **Start farming here**, **Show on world map** (preview only) and **Set waypoint**. |
| **Gather + Kill** | **Gather**: Mining / Herbs / Both; **Kill**: All mobs / Skinnable only; **Rank by**: Gold / hour or Skill-ups / hour; plus **Location**, **Search in** and **Realistic spots** (shared with Farm). Sliders: Seconds per kill, Seconds per skin, Reach from the route, Mob respawn. Cards show the total and the split (gathering + skins + loot, or gathering + skinning skill-ups), plus the gain over doing either alone. Detail panel: map preview; per-hour split with "only gathering here" and "only mobs here" for comparison; the loop's walk / gather / fight minutes; which mobs are **worth killing** (gold per kill, gold per fighting minute, kills/hour) and which to **skip**; top loot per hour; Start farming / Show on world map / Set waypoint. |
| **Mobs & Drops** | Pick a zone (current zone, all zones for your level, or any zone), a Location filter and a mob/item filter. Columns: Mob, Level (coloured by difficulty), Where (cave name / Outdoors / ?), Zone, **Gold/kill**, Best drop with chance, Green %, Blue %, Skin skill, Spawns. Sorted by gold per kill. Click a mob to see its top 8 drops with chance and value, then **Farm this mob** (area and route around its densest camp) or **Show on world map**. |
| **Route & Map** | The active farm: zone preview, stops with coords, target and leg length, loop length/time, loop number and progress. Buttons: Open world map at farm, Skip stop, Restart here, Waypoint, Stop. Map options: route on the world map, route on the minimap (Off / Next stops / Whole loop), farm area outline, route HUD, game map pin and TomTom arrow when starting. |
| **Nodes** | Per-zone node database (what the finder ranks). Columns: Node, Type, Skill, Database spawns, Learned, Shared, Gathered, Value/node; hover for yields. Also: Import GatherMate2/GatherLite, Forget learned nodes in zone. |
| **Stats** | This session (time, value, gold/hour, gathers, kills, coin) with **New session**. Every item you gathered or looted, last 30 sessions, data health, **Save now** and **Backup now**. |
| **Settings** | Your ruleset (Auto / PvP / Normal), Hide spots with risk, route on world map / minimap, farm area outline, hide in combat/instances, route/area opacity, route HUD, game map pin, TomTom, enemy zones, elites, finder assumptions, travel speed, tooltip parts, price source order, sharing, minimap button, save reminder, debug, **Print diagnostics**. |

There is also a minimap button (left-click: window; right-click: Start farming; shift-right-click: stop), an addon compartment entry and an LDB launcher.

## Caves & mines

No public data source has positions for cave interiors (Questie and CMaNGOS spawns only record the zone), so Forager combines three things:

| Source | What it gives | Works |
|---|---|---|
| Cave names per zone (QuestieDB area table) | 35 zones list their caves and mines, e.g. Elwynn Forest: Echo Ridge Mine, Fargodeep Mine, Jasperlode Mine | Always |
| The game's explored-map areas (`C_MapExplorationInfo.GetExploredAreaIDsAtPosition`) | Which subzone a spawn point lies in; a cave or mine name counts as a cave | For map areas you have explored |
| Learning as you play | Every 2 s while you're indoors in a cave subzone, Forager records your 1 % map cell. Mobs you target, mouse over or see nameplates for there are marked as cave mobs | Fills in as you visit caves |

- **Caves & mines** keeps only spawn points known to be in a cave. It uses a tighter area (about 450 yd) and skips zones without caves. Results are marked **CAVE** (purple outline on the maps if the area outline is on), and the cave's name replaces the subzone.
- **Outdoors** drops known cave points. Points with unknown status are kept.
- If nothing is known yet, the Farm tab lists the caves in zones for your level, so you know where to go.
- `/forage caves` lists the zone's caves, the cells you've walked and whether you're in one now.

## World map, minimap and OpenMap

- **Start farming** draws a thin route line on the world map. On the minimap you get a line from you to the next stop plus the next few legs. The HUD arrow points to the next stop. **Stop** removes it all.
- Optional (off by default): farm area outline (yellow, purple for caves), the game's map pin and a TomTom arrow when you start. **Set waypoint** places the game pin on demand.
- **Show on world map** previews a result without starting it. The preview disappears when you close the map.
- **Open world map** (HUD, Now farming card, Route & Map, `/forage map`) opens the map at the farm zone.
- **No node pins** anywhere; nodes are the game's own tracking.
- **OpenMap** (`OpenMapAPI`, [docs](https://github.com/openmap-world/openmap/blob/main/docs/api.md)): while OpenMap's stitched map is showing, route points are placed with `WorldFromMap` / `MapFromWorld`, and the route layer sits above `ArtTopLevel()` so OpenMap's art doesn't cover it. Opening the map glides the view to the farm with `ShowWorld`, and Forager redraws on `OpenMap_ViewChanged` / `OpenMap_StitchedChanged`. Without OpenMap, the route is translated to the displayed map with HereBeDragons. `/forage diag` shows the OpenMap state and the route layer's frame level.

## Gather + Kill

Each area is scored on one loop of its route, with **time as the shared budget**. That way mining and mob income aren't simply added together.

| Part of the loop | Time | Income |
|---|---|---|
| Walking | route length ÷ speed | — |
| Gathering | live nodes within reach of the route × seconds per node (casts × gathers per node + loot + extra) | node value × live share (30%) |
| Fighting | mobs killed × (seconds per kill + seconds per skin if you skin it), faster for lower-level mobs, +½ reach walked per pull | loot (drops, coin, disenchant value of greens/blues) + skins if your Skinning ≥ the mob's requirement |

**Gold/hour** = (node income + mob income) × 3600 ÷ (walk + gather + fight). Shown as gathering + skins + other loot.

**Skinning:** a mob's required skill uses the Forever formula (level 1-10 → 1; 11-20 → (level − 10) × 10; 21+ → level × 5). Below that, the mob gives no skins and no extra skinning time. **Kill: Skinnable only** drops every mob you can't skin. If the character has no Skinning, that mode assumes it is maxed and says so.

**Skill-ups / hour** = gathering skill-ups (colour chance × taps per vein) + Skinning skill-ups (colour chance per skin), with the same time model and the same best-ratio choice of mobs.

**Which mobs to kill:** a mob type is only worth killing when its gold per second of fighting beats the loop's current gold per second. Forager takes mob types from best to worst gold per fighting second while that holds. This is the standard best-ratio rule and gives the highest total. The rest are listed under **Skip**: they'd pay less than the time spent gathering. So a combined spot is never rated below gathering alone on the same route.

**Respawns:** a mob you killed is back only after the respawn time (default 5 min). A loop shorter than that meets fewer mobs (loop time ÷ respawn); this feedback is solved by iterating.

**Areas and routes:**
- For each zone the shortlist is the best 3 windows by node value and the best 3 by node + mob value (about 800 yd; 450 in Caves & mines). Each candidate is then evaluated exactly.
- Two routes are tried per area: through the nodes only, and through the nodes plus up to 3 camps of worthwhile mobs the node route misses. The faster one wins.
- Up to 2 areas per zone are kept.
- An area needs at least 3 nodes you can gather.

**Compared with:**
- *Only gathering here*: the same route without fighting.
- *Only mobs here*: the Farm tab's mob model on the same area.

The card shows the gain over the better of the two. If just killing pays more, the detail panel says so.

Defaults you can change in the tab: 30 s per kill, 3 s per skin (your measured skins replace it from 10), 30 yd reach, 5 min respawn. Live share and extra seconds per node come from Settings → Finder assumptions.

**Limitations:** it uses Classic spawn points and loot tables, distances are straight lines, and mobs you skip can still aggro. **Both** routes through herbs and ore, but you can only track one of them at a time.

## Risk level

Each spot gets a score from 0 to 100, made of three parts:

| Part | What raises it |
|---|---|
| **Gank** (PvP ruleset only) | Zone: your faction's 5, contested 45, enemy territory 70; sanctuary 0. An enemy settlement within 300 yd adds 25 (35 if it has a flight path); within 700 yd adds 12. Your own guards within 250 yd take off 10. |
| **Death** | Mobs above your level (12 per level, up to 50). Elite spawns in or near the area (20; 35 for 6 or more). Tight packs (20 if each mob has 2+ others within 12 yd; 10 for pairs). Caves (10). **Your own deaths there** (15 each, up to 45). |
| **Hyperspawn** | Non-grey mob spawns per 100 × 100 yd: 0.5 → 10, 1 → 25, 2 → 45, 3+ → 60. Caves add 20, because players report fast respawns are worst there. |

- **Overall** = 1 − (1 − gank)(1 − death)(1 − hyperspawn), treating the three as independent chances.
- **Labels:** under 20 Low, under 40 Medium, under 65 High, otherwise Very high.
- **Settlements** come from QuestieDB: clusters of NPCs friendly to only one faction (towns, camps, flight masters), 46 zones.
- **Ruleset** (Settings → Your ruleset): on Forever's PvP ruleset you're flagged in contested and enemy zones, so being unflagged there once proves you're on Normal. **Auto** learns this, and assumes PvP until it knows.
- **Deaths:** Forager logs where you die (2% map cells) and raises the death risk there.
- **Filter:** Settings → **Hide spots with risk**: Show all / Very high / High or worse / Medium or worse.
- **Realistic spots** (Farm and Gather + Kill): a stricter filter for solo farming at your level. It allows no orange/red/skull mobs or elites near the area, death and hyperspawn risk Low or Medium, and gank risk below Very high. It also steers the area search away from dangerous ground. See [What's new in 1.8](#whats-new-in-18-realistic-spots).
- **Where it shows:**
  - on result cards;
  - in the detail panels (hover for the reasons);
  - on the Now farming card.

**Limitations:**
- It can't see live players, how many people are in a zone, or the game's dynamic respawn rate. Hyperspawn is estimated from spawn density.
- Neutral (yellow) mobs count the same as aggressive ones.

## Goals

Herbalism, Mining, Skinning, Fishing, Cloth (Linen to Runecloth/Felcloth), Greens to disenchant, Leather/hides, Meat (Cooking), Elemental mats, Lockboxes (Rogue pick pocket junkboxes), and Raw gold (all loot). Results are filtered by your skill, level and faction, all auto-detected from the game.

**Skill-ups / hour** is available for Herbalism, Mining, Skinning, Leather, Fishing and Lockboxes. It ranks orange and yellow targets for your current skill instead of profit.

## Questing-zone mode

In the Farm tab, **Search in** picks the scope: **Everywhere** (zones for your level), **Current zone** (follows you) or a specific zone you're questing in. `/forage quest2 <zone>` adds an optional next-hub zone. The choice is remembered per character.

- Only those zones are ranked. Each area is scored by its rate including the detour: travel from the nearest active quest objective (`C_QuestLog.GetQuestsOnMap`) plus one loop. Cards show the detour in minutes.
- Mobs named in your active objectives (e.g. "Prowler slain: 2/8") are marked **QUEST** when they're in the farming area. Quest objectives inside the area are counted.
- **Everywhere** goes back to dedicated farming.

## Mob tooltip

(Ornery Plainstrider, level 17)

```
Skinnable 70 (you 85)                           estimate | me n=4
  Light Leather 74% · Medium Leather 19% · Light Hide 5.1% · Pristine Leather 2.9%
Drops                                           estimate
  Strider Meat 40% · Shadowgem 0.34%
Gear: 2% · 0% · 0%   (green · blue · purple)        Classic est.
  Green (ilvl ~18) DE: Strange Dust ≈ 4s 20c
Pick pocket: Battered Junkbox 15%               (Rogues)
```

- The required skinning skill uses the Forever formula: level 1-10 → 1; 11-20 → (level − 10) × 10; 21+ → level × 5. It's coloured against your skill.
- Skin lists include Forever's Pristine Leather for beasts level 10–26 (see [Data sources & accuracy](#data-sources--accuracy)).
- Your own observations replace the estimate once the sample reaches the threshold (default n = 30). Until then both are shown. Mobs with no data show `learning (n=…)`; numbers are never invented.
- If a value comes back secret (in restricted content), the lines are simply skipped.

## Slash commands

| Command | Does |
|---|---|
| `/forage` (or `/forager`) | Open/close the window |
| `/forage start [goal or item]` | Best spot now. Goals: herb ore skin fish cloth greens leather meat elemental lockbox gold, or an item name (`/forage start copper ore`) |
| `/forage stop` | Stop the route |
| `/forage farm` / `combo` / `mobs` / `route` / `nodes` / `stats` / `settings` | Open that tab |
| `/forage map` | Open the world map at your farm |
| `/forage caves` | Caves in this zone, cells you've walked, whether you're in one |
| `/forage diag` | Diagnostics to paste into a bug report |
| `/forage quest <zone>` / `current` / `auto` / `off` | Set or clear the questing zone |
| `/forage quest2 <zone>` / `off` | Optional next quest hub (ranked too) |
| `/forage mode gold` / `skill` | Rank by gold/hour or skill-ups/hour |
| `/forage realistic` [`on` / `off`] | Only spots you can farm solo at your level |
| `/forage mob` | Print Forager's lines for your target |
| `/forage import` | Import GatherMate2 / GatherLite nodes |
| `/forage save` | Write data to disk now (reloads UI) |
| `/forage backup` / `restore` | Backup status / restore from the backup file (asks first) |
| `/forage reset nodes` / `mobs` / `stats` / `all` | Clear data (asks first) |
| `/forage status` | Version, data and backup status |
| `/forage debug` | Toggle debug messages |

## How the numbers are calculated

- **Value per node** = Σ (expected count per node × price).
  - With 30+ of your own visits to that node type (setting): your own items per visit, all items including Scarce finds.
  - Otherwise: the node's CMaNGOS loot table × gathers per node (multi-tap ore veins), plus a Scarce item at your pooled rate once you've logged 100 gathers of the nodes that give it.
- **Prices:** AuctionTrends `GetMarketValue` → Auctionator `GetAuctionPriceByItemID` → TradeSkillMaster `TSM_API.GetCustomPriceValue` (DBMarket by default) → vendor price (order set in Settings). Forager only reads them and never touches Auctionator or TSM.
- **Area:** each zone is split into a 20 × 20 grid. Forager picks the window of cells, about 800 yards across (450 in Caves & mines), with the highest total value (or skill-up chance). Up to 2 areas per zone (4 in questing mode). In cave mode the area shrinks to the cave's spawn points.
- **Item goals:** node areas are weighted by expected count × price of that item, mob camps by drop chance × price (by chance if the item has no price), fishing zones by catch rate. If the item has no price, results are ranked by quantity per hour.
- **Route:** up to 40 of the best points in the area, at least 25 yd apart, in a closed loop (nearest neighbour + 2-opt). Mob routes go through up to 14 camp centres. Distances come from HereBeDragons zone sizes.
- **Gold/hour (nodes)** = live nodes per loop × value per node × loops per hour.
  - Live nodes = spawn points × live share (default 30%).
  - Loop time = route length ÷ speed + Σ live nodes × seconds per node.
  - Seconds per node = gathers per node × (cast + loot) + extra (default 1 s). Cast is your measured average from 10 casts, else Herb Gathering 5 s / Mining 3.2 s. Loot is your measured loot-window time, else 0.
  - Speed: Auto = running 7 yd/s below level 40, otherwise 60% mount 11.2 yd/s.
- **Gold/hour (mobs)** = kills/hour × value per kill.
  - Kills/hour = setting (default 45) × density, where density = min(1, spawns in area ÷ 25) × level factor.
  - Level factor: mobs more than 3 levels above you, and elites, are excluded unless allowed in Settings; mobs well below you count as faster kills.
  - Value per kill = Σ chance × price for the goal's items. Skinning counts only if your skill is high enough.
  - **Gold/kill** in Mobs & Drops = every drop × price + average coin + disenchant value of greens/blues + skins if you have Skinning.
- **Greens:** P(green) × expected green disenchant value + P(blue) × expected blue disenchant value. The disenchant table follows Classic armour splits by item level. If enchanting mats have no AH price, an estimated vendor value (0.7 × ilvl² copper) is used instead.
- **Gear grade %:** P(at least one green, blue or epic weapon/armour) per kill. This combines independent loot rows as 1 − Π(1 − p) and adds up the chances inside each loot group, including shared world-drop reference tables.
- **Skill-ups/hour:** chance per gather by colour — orange 100%, yellow 75%, green 25%, grey 0.
  - Ore and skinning colour thresholds: required +25/+50/+100 (same as Classic).
  - Herbs (Forever): required +25/+65/+100; Dreamfoil 290/340/370. Skill-1 nodes use 25/50/100 (ore) and 25/65/100 (herbs).
  - Fishing is rough: min(1, (300 − skill)/300 + 0.05) × 0.6 per catch.
  - Lockpicking: junkbox chance × colour chance. Rogue skill is assumed to be level × 5, which is the cap.
- **Questing score** = rate × loop time ÷ (loop time + 2 × distance to nearest quest objective ÷ speed).
- **Session gold/hour** = value of everything you looted at current prices, plus coin, ÷ session time.

## Data sources & accuracy

What each number comes from, and how sure it is.

| Data | Source | Forever-specific? |
|---|---|---|
| Node, mob and NPC spawn points, mob levels, NPC factions | QuestieDB Forever database. Its node and NPC tables were last updated on 11 Oct 2026; Questie's Forever coordinates are converted from Classic Era sources | Partly: Forever's new zones and nodes have few or no spawn points yet. Your gathers, your guild (sharing) and imports fill the gaps |
| Node yields, gathers per vein, mob loot and skins | CMaNGOS classic-db (Classic) | No, so your own data replaces them at n ≥ 30 |
| Scarce materials (IDs, vendor prices, which nodes give which) | warcraft.wiki.gg Forever herbalism/mining techniques, wowgoldfarms.com, wow-professions.com (Thorium → Pitchblende) | Yes. Drop rates for herbs and ore are unpublished, so they're learned |
| Pristine Leather start rate | 29 per 1,000 skins of level 22–26 Barrens beasts (nerdflakes.com); beasts level 10–26 (classicwowforever.com) | One community log; your skins replace it from 100 in that band |
| Herb skill colours | warcraft.wiki.gg Forever herb table (yellow → green moved 15 points later) | Yes |
| Ore and skinning skill colours, skinning skill formula | warcraft.wiki.gg Forever mining/skinning techniques | Yes (same as Classic, plus the Forever skinning formula) |
| Cast times | classicdb.ch: Herb Gathering 5 s, Mining 3.2 s | Classic. Your measured casts replace them from 10 |
| Prices | Your AuctionTrends / Auctionator scans, TSM, vendor | Live |
| Mob respawn | Slider (default 5:00) | Forever adjusted respawn rates for launch, especially in starting zones, and no numbers are published |

Not changed, because no better data was found: node spawn positions (Forever reduced Poor Copper Veins in starter areas, but the new positions aren't in any open database), mob kill times (Forever raised enemy health on 2 Nov; set **Seconds per kill** to match your character), and dynamic respawn.

## Your data survives updates

| File | Contents |
|---|---|
| `WTF\Account\<ACCOUNT>\SavedVariables\ForagerDB.lua` | Learned/shared/imported nodes, mob observations, stats, sessions, settings, per-character questing zone and goal |
| `WTF\Account\<ACCOUNT>\SavedVariables\ForagerBackupDB.lua` | Full backup copy |

- **Backup:** refreshed at every logout and `/reload`, but only while the data looks healthy. It's skipped if the data shrank below half of the previous backup; `/forage reset` counts as intentional.
- **Auto-restore:** if the main file loads empty, the backup is restored at login and you're told.
- **Safe mode:** data is versioned and upgrade steps run protected. If an upgrade fails, or the data comes from a newer version, your data is left as-is and the backup is never overwritten.
- **Save now:** WoW only writes on `/reload` or logout. `/forage save` writes immediately. A reminder appears every 30 gathers (configurable).
- **Manual recovery:** exit WoW, then rename `ForagerDB.lua.bak`, or use `/forage restore` in game.

## Development

- `tests/run_tests.lua`: a mock-API harness (Lua 5.1) with 41 tests. They cover:
  - TOC packaging metadata, login, decoding, finder (all goal types, item goals, both modes, questing, caves/outdoors), routes, farm-this-mob;
  - tooltips, capture (herb, unknown Forever node, creature loot, skinning, secret values), sharing, imports, backup/restore/safe mode;
  - UI tabs (fails on any UI build error), slash commands, maps (no pins created, route drawing in every minimap mode), settings migrations;
  - cave learning and explored-area lookups, preview / open map at farm / game map pin, world-map drawing on zone, continent and unrelated maps;
  - OpenMap (mocked API): positions, layer above its art, view glide, window hide/restore, preview cleared on close;
  - Gather + Kill: split and loop time add up, never below gathering alone, worthy/skipped mobs on the right side of the loop rate, slower kills never raise the rate, ore/herb/both, start as a farm;
  - Gather + Kill skinning: skins only within your skill, skin-only mode, no skins without Skinning, skin time never helps, skill-ups split and best-ratio property, both modes render;
  - risk: ruleset detection, gank by zone/settlement/ruleset, death from levels and logged deaths, combined score, filter, UI;
  - accuracy (1.7): Forever herb colours and Dreamfoil, time per node from cast times × gathers per vein, measured casts and loot windows (interrupts ignored), one visit per vein, learned yields and pooled Scarce rates, Pristine Leather band, own skins with quantities, TSM price source, v4 → v5 upgrade;
  - Realistic spots (1.8): orange/elite mobs excluded, every kept spot passes the rules (Farm ore/skinning/gold, Gather + Kill, PvP ruleset), spots still found at level 25, setting, slash command, UI.

  Run with `lua5.1 tests/run_tests.lua . Forager_Data Forager_Backup`.
- `luacheck .` is clean (config in `.luacheckrc`).
- `tools/`: data build scripts (`build_data.py`) and instructions to regenerate `Forager_Data` from QuestieDB and CMaNGOS.

## Known limitations

- Spawns and loot rates are Classic-era (see [Data sources & accuracy](#data-sources--accuracy)). Forever changed some itemization (world epics, rare spawns), so gear-grade rates for rares may be off. Your own data takes over at n ≥ 30.
- New Forever zones and node types are learned only as you, your guild or imports find them.
- Gold/hour is an estimate. It assumes you're the only farmer, that 30% of spawn points are live, and straight-line travel without terrain.
- Lockpicking skill can't be read from the API, so it's assumed to be at the level cap.
- Cave detection needs explored map areas or a visit. A cave's explored-map area also covers the ground around its entrance, so a few "cave" spawns may sit just outside.
- OpenMap support follows OpenMap's published API (major 1, version 4). It's tested against a mock of that API, not the live addon.
- Sharing sends only node type, zone and position, never in instances. Trial accounts can't send addon messages on Forever.
- Written against the documented Mainline/Forever API and tested in a simulated client. **It has not been run in the live Forever client yet.** If anything errors, `/forage debug` plus the error text will pinpoint it.

### API calls not verified on the live Forever client

| API / behaviour | Used for | If it fails |
|---|---|---|
| NPC ID field in obfuscated creature GUIDs (build 70425+) | Tooltip, capture | No tooltip lines; capture can't attribute mobs |
| `GetZonePVPInfo`, `UnitIsPVP("player")` | Ruleset detection | Stays on "PvP assumed"; set it in Settings |
| `GetLootSourceInfo` returning non-secret GUIDs out of combat | Node type by object ID, per-corpse counting | Falls back to the main item; one corpse per loot |
| Gather spell IDs 2366/2575/8613/7620/921 (name fallback built in) | Detect gathers | Learned automatically by name |
| `C_QuestLog.GetQuestsOnMap`, `GetQuestObjectives` | Questing mode | Ranked without detour ("No quest objectives found") |
| `TooltipDataProcessor.AddTooltipPostCall` with `data.guid` | Mob tooltip | Fallback via `tooltip:GetUnit()` |
| `C_Minimap.GetViewRadius`, `GetPlayerFacing` outside encounters | Minimap lines, arrow | Arrow shows "travel to zone"; lines hidden |
| `WorldMapFrame:GetCanvas()`, `ScrollContainer:GetCanvasScale()`, `OnMapChanged` | World map route line | Route not drawn on the world map; the HUD arrow and minimap route still work |
| `HereBeDragons:TranslateZoneCoordinates` for Forever map IDs | Lines on continent/OpenMap views | Lines only on the zone map |
| `OpenWorldMap(uiMapID)`, `WorldMapFrame:SetMapID` | Open map at farm | Map opens at your current zone |
| `C_Map.SetUserWaypoint`, `UiMapPoint.CreateFromCoordinates`, `C_SuperTrack` | Optional game map pin / Set waypoint | No pin (TomTom still works) |
| `C_MapExplorationInfo.GetExploredAreaIDsAtPosition`, `C_Map.GetAreaInfo` | Cave/subzone names at spawn points | Caves only from your visits |
| `IsIndoors`, `GetSubZoneText` | Cave learning | No learning; explored areas still used |
| `C_Map.GetMapArtLayers`, `GetMapArtLayerTextures` | Zone map previews | "Map preview unavailable" (lines still drawn) |
| `OpenMapAPI` (major 1): `IsStitched`, `WorldFromMap`, `MapFromWorld`, `ArtTopLevel`, `ShowWorld`, callbacks | Route on OpenMap's map | Falls back to HereBeDragons translation; the line may be hidden under OpenMap's art |
| Template `UICheckButtonTemplate`, `BackdropTemplate` | UI | Checkboxes / panel backgrounds missing (cosmetic) |
| Textures `Interface\Minimap\MinimapArrow`, `Interface\Common\Indicator-Gray`, `Interface\Common\UI-Searchbox-Icon`, `Interface\FriendsFrame\ClearBroadcastIcon` | HUD arrow, preview dots, search, close | Blank texture (cosmetic) |
| `C_Item.GetItemIconByID` for Forever-only items | Item icons in the window | Question-mark icon |
| `UNIT_SPELLCAST_START` / `SUCCEEDED` / `INTERRUPTED` for gather spells | Measured cast times | Classic cast times stay in use |
| `TSM_API.GetCustomPriceValue` on Forever | TSM price source | Skipped; the next price source is used |

## Credits & licence

Forager is GPL-3.0-or-later. Bundled data comes from QuestieDB (Forever data) and CMaNGOS classic-db, both GPLv3. Libraries: HereBeDragons core (BSD), LibStub, CallbackHandler-1.0, LibDataBroker-1.1. See `THIRD_PARTY.md`.
