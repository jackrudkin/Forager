# Forager (WoW Forever)

Tells you where to farm any gathering profession, material or single item (including inside caves and mines), draws an optimised route on the world map and minimap, shows what every mob drops ranked by gold per kill, and adds loot, skinning and gear-grade chances to mob tooltips.

Built for **WoW Forever 1.60.1** (`## Interface: 16001`, Mainline 12.x API). Forever only.

## What's new in 2.2: free roam

Farm a profession without a route: the HUD arrow points you to nodes. Start it with the **Free roam** button on the window's card, `/forage roam [herb|ore|both]`, or Ctrl-right-click on the minimap button. Stop it with **Stop** or `/forage roam stop`.

| Feature | How it works |
|---|---|
| Arrow to the next node | Points to the nearest likely spawn point of a node you can gather (bundled data, your finds, shared and imported nodes). Closer spots and node types that are up more often come first. Spots you pass within 30 yd count as checked and are skipped until they could have respawned. Gathering a node cools the spots around it. |
| Locks on to minimap dots | Hover a herb or ore dot on your minimap: the arrow switches to that dot for 2 minutes or until you reach it. It's saved at that position, worked out from the dot's offset and the minimap's zoom, to within about 15 yd. Works with Rotate Minimap on. |
| Nodes in front of you | When the game's soft target picks a herb or vein, Forager saves it at your position and learns its name in your client's language. |
| Fills the database | Every node you gather, hover or face is saved as a spawn point, without yields until you gather it. These nodes are shared with your guild/party if sharing is on, and used by the Farm rankings and routes. This is how the new zones (no open node data) fill in. Turn it off in Settings → Maps & farming → **Save nodes I point at**. |
| Follows you | Carries on across zone changes. Herbs, ore or both follow your Farm goal, else your professions. The tracking switcher and ready check know which tracking you need. |

**Why a new dot doesn't trigger the arrow by itself:** no game API lists the minimap's tracking dots. NodeRadar's page says the November 2026 Forever update stopped addons reading the minimap in the background. NodeRadar 3.0 works around this by moving the minimap under your cursor for a split second, which makes it blink. Forager reads a dot only when you hover it, so nothing blinks and nothing is moved.

## What's new in 2.1: Forever's new zones

| Zone | Mobs now in Forager | Herb / ore nodes |
|---|---|---|
| Riverglades (35-45) | 151 hostile mob types, ~5,600 spawn points | None bundled: no open data source has them yet |
| Mount Hyjal (56-60) | 83 types, ~3,700 points | None bundled |
| Zephras Isle (1-12) | 66 types, ~2,700 points | None bundled |
| Shen'dralas (40-45) | 34 types, ~2,900 points | None bundled |

- **Where the mobs come from:** QuestieDB's Forever trace layer, which is aggregated from Questie users' own game clients. It gives names, levels, elite rank, faction and spawn points. Pets, summons, bots and camp tents are filtered out. In the Classic zones only Forever's new faction NPCs are added (towns and camps, for gank risk); Classic mobs are untouched.
- **What works in those zones:** Mobs & Drops, **Farm this mob**, risk levels and Realistic spots (levels, elites, density, towns), and the Gather + Kill fighting side.
- **Loot:** these are new NPCs, and no open database has their loot tables. They show **loot it** until you do: Forager now records loot quantities and coin per mob, and uses them in every estimate. For Classic mobs your loot is blended with the bundled tables; for new NPCs it's used as it is.
- **Herb and ore nodes:** no open data source has spawn points for the new zones: QuestieDB's traces don't record gathering nodes and CMaNGOS is Classic-only (Wowhead's maps can't be copied: its terms forbid scraping). Forager adds every node you gather, so these zones fill in as you, your guild (sharing) or a GatherMate2/GatherLite import find them. Zone lists mark them **new**, and the Nodes and Farm tabs say why they're empty.
- **Zone levels:** Mount Hyjal is 56-60 and Shen'dralas 40-45, from the levels of their mobs in the traces (published sources disagree on Shen'dralas). Darkspear Islands is a battleground, so it's no longer listed as a farming zone.
- Your mob drops are now also counted with quantities (e.g. 2 cloth from one corpse), and weapons/armour stay in the gear-grade chances so they aren't counted twice.

## What's new in 2.0: real spawn data, numbers that learn, farming helpers

**More accurate estimates**

| Change | Before | Now |
|---|---|---|
| Live nodes per spawn point | Flat 30% everywhere | From the CMaNGOS spawn pools, per node type and per zone for ore (e.g. Copper 20%, Tin 12%, Silver 8%; Black Lotus 100%). Ore estimates were too high before |
| Mob respawn | Flat 5:00 | Per mob from CMaNGOS (e.g. 3:00 for many low-level mobs; rares much longer, so they count for less) |
| Your data vs estimates | Hard switch at n = 30 | Blended: with n of your samples and estimate weight k (Settings, default 30), value = (n × yours + k × estimate) ÷ (n + k). Yields, skins, drops, gear grades and fishing |
| Kills per hour, seconds per kill | Sliders only | Measured from your fights (time in combat per kill, downtime between fights) and blended with the sliders |
| Travel speed | 60% mount from 40 assumed | Measured on foot and mounted; used when known (100% at 60 is only assumed once measured) |
| Gold per hour | Full item prices | After the 5% AH cut on AH-priced items and your measured repair cost per kill. Hover the rate for the breakdown |
| Calibration | — | After 10+ active minutes farming a spot, its estimate is scaled by what you actually made there; spots of the same kind use it too once you have an hour. Stats shows each session vs its estimate |
| Bountiful Harvest | Not counted | Settings → Estimates: your rank (Legacy perk, +20% Scarce from Mining, Herbalism and Skinning per rank). Scarce rates are stored per rank, so changing it rescales them |
| Herb seeds | Not known | All four tiers known (IDs, vendor prices, which herbs give which tier, from QuestieDB). Rates are learned from your gathers |
| Hotfix notes | — | Spots in zones with spawn-rate hotfixes since launch say so (e.g. STV tigers/panthers/raptors more frequent) |

**Farming helpers** (Settings → Maps & farming)

| Helper | What it does |
|---|---|
| Tracking switcher | On routes with both herbs and ore (and both professions), flips Find Herbs / Find Minerals every 4 s while you move, out of combat and not casting. Forever allows one resource tracker at a time |
| Re-track after death | Dying clears tracking in Forever; your herb or ore tracking comes back on once you're alive |
| Ready check | When a farm starts: tracking off, or Mining Pick / Skinning Knife not in your bags. Shown on the HUD with a one-click **Turn on** for tracking |
| Cooling stops | The arrow skips stops you just gathered until they can have respawned (spawn data, or sooner if you've seen that node type back sooner) |
| Session clock | Counts active time only: AFK, or 3 minutes without moving, looting or fighting, pauses it |
| Hardcore | Detected (`C_GameRules.IsHardcoreActive`). Realistic spots turns on and gets stricter: no mob above your level + 1, no elites, death risk Low |

**Item tooltips:** items you can farm show the best spot for your character (worked out in the background the first time you hover them). **Alt+Shift+click** an item link anywhere to open Farm on that item.

**Smooth and light:** searches run a few milliseconds per frame with a progress line, so the game never stutters; recent results are cached. Decoded data is capped and emptied after 2 idle minutes. `/forage selftest` checks the data, the game APIs Forager uses, search speed and memory; `/forage errors` lists any errors Forager caught (kept between sessions). Saved data is trimmed of empty records and old shared nodes.

**Also:** German and French for tabs, Settings, HUD and the gold breakdown, with zone names in your client's language. Settings is split into three pages. A weekly GitHub workflow rebuilds the data from the latest QuestieDB and opens a pull request when it changed.

## What's new in 1.9: item tooltips

Hover any item in the Forager window to see the game's own item tooltip. Below it, Forager adds the price it uses (and where that price comes from) and what the item is worth in that spot.

| Where | Extra lines |
|---|---|
| Farm: loot icons on result cards, **Per hour** rows in the detail panel | Per hour here, value per hour |
| Gather + Kill: **Loot per hour** icons | Per hour here, value per hour |
| Mobs & Drops: a mob's drops in the detail panel | Drop chance, value per kill |
| Stats: items gathered/looted | All-time count, this session, worth now |
| Search suggestions (Farm and Mobs & Drops) and the selected item chip | Forager price |

Coin and "Green/Blue gear (DE)" entries show a short explanation instead, because they aren't single items. Price addons that add lines to item tooltips (Auctionator, TSM) show their lines as usual.

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

**What's missing from the bundled data:** herb and ore nodes in Forever's new zones (Mount Hyjal, Riverglades, Shen'dralas, Zephras Isle), loot tables for Forever's new NPCs, and new node types (Marefoil, Demonsage, Death Lotus, Heavy Thorium, Poor Copper, Wilted Peacebloom, Stunted Silverleaf). No open source has them yet. They fill in as you gather and loot. A node type Forager doesn't know is learned from the item it gives and named after that item. Mobs in the new zones are included (from QuestieDB's player traces, see [What's new in 2.1](#whats-new-in-21-forevers-new-zones)).

**Why GatherLite's database isn't bundled:** its Forever coordinates were scraped from Wowhead, and Wowhead's terms forbid scraping. GatherMate2_Data has the same problem. Importing your own saved nodes from either addon is fine.

**How captures work:** a gather spell (Herb Gathering, Mining, Fishing, Skinning, Pick Pocket) followed by a loot window is recorded. Spells are matched by ID and, as a fallback, by localized name, so Forever's own spell IDs are learned automatically. The node type comes from the loot source's GameObject ID, or from the main item. Creature loot is grouped per corpse GUID and counted once per corpse. Any value the client returns as secret is skipped without an error.

## Nodes on the map

Forager draws no node pins. Live nodes show through the game's own tracking (Find Herbs / Find Minerals), as without the addon. Spawn points from the database, your gathers, guild sharing and imports are still used to rank spots and build routes, and you can browse them in the Nodes tab.

## Window (`/forage`)

The sidebar has seven tabs. Below them, the **Now farming** card shows the active farm with **Map** and **Stop** buttons; with nothing running it offers **Best spot** and **Free roam**. The status bar at the bottom shows your search scope, session gold/hour and price sources.

| Tab | What's there |
|---|---|
| **Farm** | **What do you want to farm?** search box (category, item or mob; suggestions as you type). Category chips: Herbs, Ore, Skinning, Fishing, Cloth, Greens (DE), Leather, Meat, Elemental, Lockboxes, Raw gold. **Rank by** Gold/hour or Skill-ups/hour. **Location**: Anywhere / Caves & mines / Outdoors. **Search in**: Everywhere (your level), Current zone (follows you), or a zone you're questing in. **Enemy zones** and **Realistic spots** toggles. Below that is a ranked list of cards (zone · subzone/cave, rate, mob levels or node skill, risk, loot icons). The detail panel has a zone map preview with the area, spawns, route and your position; what you get per hour (quantity and value per item); the mobs or nodes in the area; and buttons for **Start farming here**, **Show on world map** (preview only) and **Set waypoint**. |
| **Gather + Kill** | **Gather**: Mining / Herbs / Both; **Kill**: All mobs / Skinnable only; **Rank by**: Gold / hour or Skill-ups / hour; plus **Location**, **Search in** and **Realistic spots** (shared with Farm). Sliders: Seconds per kill, Seconds per skin, Reach from the route, Mob respawn. Cards show the total and the split (gathering + skins + loot, or gathering + skinning skill-ups), plus the gain over doing either alone. Detail panel: map preview; per-hour split with "only gathering here" and "only mobs here" for comparison; the loop's walk / gather / fight minutes; which mobs are **worth killing** (gold per kill, gold per fighting minute, kills/hour) and which to **skip**; top loot per hour; Start farming / Show on world map / Set waypoint. |
| **Mobs & Drops** | Pick a zone (current zone, all zones for your level, or any zone), a Location filter and a mob/item filter. Columns: Mob, Level (coloured by difficulty), Where (cave name / Outdoors / ?), Zone, **Gold/kill**, Best drop with chance, Green %, Blue %, Skin skill, Spawns. Sorted by gold per kill. Click a mob to see its top 8 drops with chance and value, then **Farm this mob** (area and route around its densest camp) or **Show on world map**. |
| **Route & Map** | The active farm: zone preview, stops with coords, target and leg length, loop length/time, loop number and progress. Buttons: Open world map at farm, Skip stop, Restart here, Waypoint, Stop. Map options: route on the world map, route on the minimap (Off / Next stops / Whole loop), farm area outline, route HUD, game map pin and TomTom arrow when starting. |
| **Nodes** | Per-zone node database (what the finder ranks). Columns: Node, Type, Skill, Database spawns, Learned, Shared, Gathered, Value/node; hover for yields. Also: Import GatherMate2/GatherLite, Forget learned nodes in zone. |
| **Stats** | This session (active time, value, gold/hour vs the farm's estimate, gathers, kills, coin) with **New session**. Every item you gathered or looted, last 30 sessions with each one's result vs its estimate, data health, **Save now** and **Backup now**. |
| **Settings** | Three pages. **Maps & farming**: route on world map / minimap, area outline, hide in combat/instances, opacity, HUD, map pin, TomTom, enemy zones, elites, ruleset, risk filter, farming helpers (tracking switcher, re-track after death, ready check, skip cooling stops, idle-paused clock, save nodes I point at). **Estimates**: spawn-pool data, fallback live share, estimate weight, extra seconds per node, fishing casts, Bountiful Harvest rank, kills per hour, travel speed, what's been measured from your play, net gold (AH cut + repairs), calibration. **Tooltips, prices & more**: tooltip parts (incl. best spot on item tooltips), price source order, TSM price, sharing, minimap button, save reminder, debug, **Self-test**, **Diagnostics**. |

There is also a minimap button (left-click: window; right-click: Start farming; Ctrl-right-click: free roam; shift-right-click: stop), an addon compartment entry and an LDB launcher.

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
| Gathering | live nodes within reach of the route × seconds per node (casts × gathers per node + loot + extra) | node value × live share (spawn pools per type and zone) |
| Fighting | mobs killed × (seconds per kill + seconds per skin if you skin it), faster for lower-level mobs, +½ reach walked per pull | loot (drops, coin, disenchant value of greens/blues) + skins if your Skinning ≥ the mob's requirement |

**Gold/hour** = (node income + mob income) × 3600 ÷ (walk + gather + fight). Shown as gathering + skins + other loot.

**Skinning:** a mob's required skill uses the Forever formula (level 1-10 → 1; 11-20 → (level − 10) × 10; 21+ → level × 5). Below that, the mob gives no skins and no extra skinning time. **Kill: Skinnable only** drops every mob you can't skin. If the character has no Skinning, that mode assumes it is maxed and says so.

**Skill-ups / hour** = gathering skill-ups (colour chance × taps per vein) + Skinning skill-ups (colour chance per skin), with the same time model and the same best-ratio choice of mobs.

**Which mobs to kill:** a mob type is only worth killing when its gold per second of fighting beats the loop's current gold per second. Forager takes mob types from best to worst gold per fighting second while that holds. This is the standard best-ratio rule and gives the highest total. The rest are listed under **Skip**: they'd pay less than the time spent gathering. So a combined spot is never rated below gathering alone on the same route.

**Respawns:** a mob you killed is back only after its respawn time (CMaNGOS, per mob; the slider is used for mobs without data). A loop shorter than that meets fewer of them (loop time ÷ respawn); this feedback is solved by iterating.

**Areas and routes:**
- For each zone the shortlist is the best 3 windows by node value and the best 3 by node + mob value (about 800 yd; 450 in Caves & mines). Each candidate is then evaluated exactly.
- Two routes are tried per area: through the nodes only, and through the nodes plus up to 3 camps of worthwhile mobs the node route misses. The faster one wins.
- Up to 2 areas per zone are kept.
- An area needs at least 3 nodes you can gather.

**Compared with:**
- *Only gathering here*: the same route without fighting.
- *Only mobs here*: the Farm tab's mob model on the same area.

The card shows the gain over the better of the two. If just killing pays more, the detail panel says so.

Defaults you can change in the tab: 30 s per kill (blended with your measured fights), 3 s per skin (your measured skins replace it from 10), 30 yd reach, 5 min respawn for mobs without spawn data. Extra seconds per node comes from Settings → Estimates.

**Limitations:** it uses Classic spawn points and loot tables, distances are straight lines, and mobs you skip can still aggro. **Both** routes through herbs and ore; the tracking switcher flips between the two trackers while you move.

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
Skinnable 70 (you 85)                           blend n=4
  Light Leather 74% · Medium Leather 19% · Light Hide 5.1% · Pristine Leather 2.9%
Drops                                           estimate
  Strider Meat 40% · Shadowgem 0.34%
Gear: 2% · 0% · 0%   (green · blue · purple)        estimate
  Green (ilvl ~18) DE: Strange Dust ≈ 4s 20c
Pick pocket: Battered Junkbox 15%               (Rogues)
```

- The required skinning skill uses the Forever formula: level 1-10 → 1; 11-20 → (level − 10) × 10; 21+ → level × 5. It's coloured against your skill.
- Skin lists include Forever's Pristine Leather for beasts level 10–26 (see [Data sources & accuracy](#data-sources--accuracy)).
- Your own observations are blended with the estimate: `blend n=…` until n reaches the estimate weight (default 30), then `my data n=…`. Mobs with no bundled data show only what you've seen; numbers are never invented.
- If a value comes back secret (in restricted content), the lines are simply skipped.

## Slash commands

| Command | Does |
|---|---|
| `/forage` (or `/forager`) | Open/close the window |
| `/forage start [goal or item]` | Best spot now. Goals: herb ore skin fish cloth greens leather meat elemental lockbox gold, or an item name (`/forage start copper ore`) |
| `/forage stop` | Stop the route |
| `/forage roam` [`herb` / `ore` / `both` / `stop`] | Free roam: arrow to the nearest likely node, no route |
| `/forage farm` / `combo` / `mobs` / `route` / `nodes` / `stats` / `settings` | Open that tab |
| `/forage map` | Open the world map at your farm |
| `/forage caves` | Caves in this zone, cells you've walked, whether you're in one |
| `/forage diag` | Diagnostics to paste into a bug report |
| `/forage selftest` | Check data, game APIs, search speed and memory |
| `/forage errors` [`clear`] | Errors Forager caught (kept between sessions) |
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
  - Count per node = (n × your items per visit + k × CMaNGOS loot table × gathers per node) ÷ (n + k), with n your visits to that node type and k the estimate weight (default 30). Gathers per node is blended the same way.
  - Scarce items and herb seeds: your pooled rate per gather (over every node type that gives them, from 100 gathers) × gathers per node. Scarce rates are normalised by your Bountiful Harvest rank (+20% per rank).
- **Prices:** AuctionTrends `GetMarketValue` → Auctionator `GetAuctionPriceByItemID` → TradeSkillMaster `TSM_API.GetCustomPriceValue` (DBMarket by default) → vendor price (order set in Settings). Forager only reads them and never touches Auctionator or TSM.
- **Area:** each zone is split into a 20 × 20 grid. Forager picks the window of cells, about 800 yards across (450 in Caves & mines), with the highest total value (or skill-up chance). Up to 2 areas per zone (4 in questing mode). In cave mode the area shrinks to the cave's spawn points.
- **Item goals:** node areas are weighted by expected count × price of that item, mob camps by drop chance × price (by chance if the item has no price), fishing zones by catch rate. If the item has no price, results are ranked by quantity per hour.
- **Route:** up to 40 of the best points in the area, at least 25 yd apart, in a closed loop (nearest neighbour + 2-opt). Mob routes go through up to 14 camp centres. Distances come from HereBeDragons zone sizes.
- **Gold/hour (nodes)** = live nodes per loop × value per node × loops per hour.
  - Live nodes = Σ over spawn points of the chance the point holds a live node. CMaNGOS spawn pools: limit ÷ members × the parent pool's active chance, averaged per node type, and per zone for ore (mineral pools are per zone). Points not in a pool count 100%. With spawn data off: the flat share (default 30%).
  - Loop time = route length ÷ speed + Σ live nodes × seconds per node.
  - Seconds per node = gathers per node × (cast + loot) + extra (default 1 s). Cast is your measured average from 10 casts, else Herb Gathering 5 s / Mining 3.2 s. Loot is your measured loot-window time, else 0.
  - Speed: Auto = your measured speed (on foot below level 40, mounted from 40), else running 7 yd/s below 40 and a 60% mount 11.2 yd/s from 40.
- **Gold/hour (mobs)** = kills/hour × value per kill.
  - Kills/hour = (n × your rate + k × setting) ÷ (n + k) × density. Your rate = 3600 ÷ (seconds in combat per kill + downtime between fights under 90 s, gathering excluded). Density = min(1, Σ spawns × min(1, 300 s ÷ respawn) ÷ 25) × level factor.
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
- **Net gold/hour** = gross × calibration − 5% of the AH-priced items' value − repair copper per kill × kills/hour.
  - Calibration = (h × actual ÷ estimate + 1) ÷ (h + 1) over h hours of your farm sessions at that spot (from 15 minutes; spots of the same kind from 1 hour), limited to 0.25–3.
  - Repairs = repair cost when you repair at a merchant ÷ kills since your last repair (from 50 kills).
- **Session gold/hour** = value of everything you looted at current prices, plus coin, ÷ active session time (AFK and idle time excluded).

## Data sources & accuracy

What each number comes from, and how sure it is.

| Data | Source | Forever-specific? |
|---|---|---|
| Node, mob and NPC spawn points, mob levels, NPC factions | QuestieDB Forever database (Classic spawns converted to Forever coordinates) | Partly. Forever's new zones have no node spawn points yet: your gathers, your guild (sharing) and imports fill the gaps |
| Mobs and NPCs new in Forever (incl. the new zones) | QuestieDB's Forever trace layer: names, levels, rank, faction and spawns aggregated from Questie users' clients | Yes. No loot tables: learned from your loot |
| Node yields, gathers per vein, mob loot and skins | CMaNGOS classic-db (Classic) | No, so your own data is blended in (half at n = 30 by default) |
| Live share per spawn point, node and mob respawn times | CMaNGOS classic-db spawn pools (`pool_template`, `pool_gameobject`, `pool_pool`) and `spawntimesecsmin/max` | Classic. Forever's spawn hotfixes are listed as notes; your calibration corrects the rest |
| Herb seeds (IDs, which herbs give which tier) | QuestieDB Forever item traces; vendor prices from Forever item database pages (fallback only: the game's sell price is used once the item is cached) | Yes. Rates are learned |
| Bountiful Harvest | Legacy perk: +20% Scarce from Mining, Herbalism and Skinning per rank, 5 ranks (Icy Veins, Warcraft Tavern, Mobalytics) | Yes |
| Spawn-rate hotfixes | Blizzard hotfix notes (Nov 13 and earlier) | Yes, shown as notes on spots |
| Scarce materials (IDs, vendor prices, which nodes give which) | warcraft.wiki.gg Forever herbalism/mining techniques, wowgoldfarms.com, wow-professions.com (Thorium → Pitchblende) | Yes. Drop rates for herbs and ore are unpublished, so they're learned |
| Pristine Leather start rate | 29 per 1,000 skins of level 22–26 Barrens beasts (nerdflakes.com); beasts level 10–26 (classicwowforever.com) | One community log; your skins replace it from 100 in that band |
| Herb skill colours | warcraft.wiki.gg Forever herb table (yellow → green moved 15 points later) | Yes |
| Ore and skinning skill colours, skinning skill formula | warcraft.wiki.gg Forever mining/skinning techniques | Yes (same as Classic, plus the Forever skinning formula) |
| Cast times | classicdb.ch: Herb Gathering 5 s, Mining 3.2 s | Classic. Your measured casts replace them from 10 |
| Prices | Your AuctionTrends / Auctionator scans, TSM, vendor | Live |
| Kills per hour, seconds per kill, travel speed, repairs | Measured from your play | Yes |
| AH cut and deposit | 5% cut; deposits have a 1c minimum since the Nov 17 maintenance and are returned on sale (left out) | Yes |

Not changed, because no better data was found: node spawn positions (Forever reduced Poor Copper Veins in starter areas, but the new positions aren't in any open database) and dynamic respawn. Mob kill times are now measured (Forever raised enemy health on 2 Nov).

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

- `tests/run_tests.lua`: a mock-API harness (Lua 5.1) with 56 tests. They cover:
  - TOC packaging metadata, login, decoding, finder (all goal types, item goals, both modes, questing, caves/outdoors), routes, farm-this-mob;
  - tooltips, capture (herb, unknown Forever node, creature loot, skinning, secret values), sharing, imports, backup/restore/safe mode;
  - UI tabs (fails on any UI build error), slash commands, maps (no pins created, route drawing in every minimap mode), settings migrations;
  - cave learning and explored-area lookups, preview / open map at farm / game map pin, world-map drawing on zone, continent and unrelated maps;
  - OpenMap (mocked API): positions, layer above its art, view glide, window hide/restore, preview cleared on close;
  - Gather + Kill: split and loop time add up, never below gathering alone, worthy/skipped mobs on the right side of the loop rate, slower kills never raise the rate, ore/herb/both, start as a farm;
  - Gather + Kill skinning: skins only within your skill, skin-only mode, no skins without Skinning, skin time never helps, skill-ups split and best-ratio property, both modes render;
  - risk: ruleset detection, gank by zone/settlement/ruleset, death from levels and logged deaths, combined score, filter, UI;
  - accuracy (1.7): Forever herb colours and Dreamfoil, time per node from cast times × gathers per vein, measured casts and loot windows (interrupts ignored), one visit per vein, learned yields and pooled Scarce rates, Pristine Leather band, own skins with quantities, TSM price source, v4 → v5 upgrade;
  - Realistic spots (1.8): orange/elite mobs excluded, every kept spot passes the rules (Farm ore/skinning/gold, Gather + Kill, PvP ruleset), spots still found at level 25, setting, slash command, UI;
  - item tooltips (1.9): game tooltip + Forager price, loot/coin/gear entries, every item hover area in Farm and Gather + Kill, search suggestions;
  - 2.0: spawn-pool shares and mob respawns, blending (yields, skins, Bountiful Harvest rescaling), fights → kills per hour, measured speed, AFK/idle clock, AH cut, repairs per kill, calibration and farm sessions, tracking ready check / fix / switcher / re-track after death / tools in bags, cooling stops, hotfix notes, Hardcore profile, herb seeds, error log, pruning, time-sliced jobs and the result cache, item tooltip best spot and Alt+Shift+click, self-test, settings pages, translation tables, memory budget and cache caps;
  - 2.1 / 2.2: new-zone trace NPCs and own loot for new NPCs; free roam (target, checked and cooling spots, minimap hover lock-on at the right position with and without Rotate Minimap, soft-target saving and name learning, setting off, slash commands, card and Route tab).

  Run with `lua5.1 tests/run_tests.lua . Forager_Data Forager_Backup`.
- `luacheck .` is clean (config in `.luacheckrc`).
- `tools/`: data build scripts (`build_data.py`) and instructions to regenerate `Forager_Data` from QuestieDB and CMaNGOS. The **Data update** workflow does this every Monday and opens a pull request when the data changed.
- **Publishing:** the Release workflow uploads to CurseForge and GitHub. Wago Addons and WoWInterface are ready too: add the `WAGO_API_TOKEN` / `WOWI_API_TOKEN` repository secrets and `## X-Wago-ID:` / `## X-WoWI-ID:` lines to `Forager.toc` (the project IDs from those sites).

## Known limitations

- Spawns and loot rates are Classic-era (see [Data sources & accuracy](#data-sources--accuracy)). Forever changed some itemization (world epics, rare spawns), so gear-grade rates for rares may be off. Your own data is blended in and counts most from n = 30.
- Herb/ore nodes in Forever's new zones, new node types and the loot of Forever's new NPCs are learned only as you, your guild or imports find them.
- Gold/hour is an estimate. It assumes you're the only farmer, Classic spawn-pool sizes, and straight-line travel without terrain. Calibration from your own sessions corrects it per spot.
- Translations cover the tabs, Settings, HUD and gold breakdown; the rest of the window is English. Non-English map previews and translations haven't been checked in a live client.
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
| `GameTooltip:SetItemByID`, `Frame:SetMouseClickEnabled` | Item tooltips on hover; clicks pass through icons to the card | Name-only tooltip with Forager's price; clicks are handed to the card |
| `UNIT_SPELLCAST_START` / `SUCCEEDED` / `INTERRUPTED` for gather spells | Measured cast times | Classic cast times stay in use |
| `TSM_API.GetCustomPriceValue` on Forever | TSM price source | Skipped; the next price source is used |
| `C_Minimap.GetTrackingInfo` / `SetTracking` out of combat | Tracking switcher, re-track, ready check fix | No switching; the ready check still warns |
| `GetUnitSpeed("player")` (may be secret in combat; sampled out of combat only) | Measured travel speed, switcher "moving" check | Level-based speed; no switching |
| `GetRepairAllCost` at a merchant | Repairs per kill | Repairs not counted |
| `C_GameRules.IsHardcoreActive` | Hardcore detection | Treated as not Hardcore |
| `HandleModifiedItemClick`, `TooltipDataProcessor` item post-call | Alt+Shift+click, best spot on item tooltips | No item tooltip lines; click does nothing |
| Minimap tooltip on hover (`GameTooltip` owned by `Minimap`, `GetCursorPosition`, `C_Minimap.GetViewRadius`) | Free roam lock-on, saving hovered dots | Hovering does nothing; the arrow still points to likely spots |
| `PLAYER_SOFT_INTERACT_CHANGED`, `UnitGUID("softinteract")` on gathering nodes | Saving nodes you face | Nodes are saved only when gathered or hovered |
| `UnitIsAFK`, `UnitOnTaxi`, `IsMounted`, `IsSwimming` | Idle clock, speed samples | Clock counts all time; speed samples less precise |

## Credits & licence

Forager is GPL-3.0-or-later. Bundled data comes from QuestieDB (Forever data) and CMaNGOS classic-db, both GPLv3. Libraries: HereBeDragons core (BSD), LibStub, CallbackHandler-1.0, LibDataBroker-1.1. See `THIRD_PARTY.md`.
