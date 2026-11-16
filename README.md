# Forager (WoW Forever)

Tells you where to farm any gathering profession, material or single item (including inside caves and mines), draws an optimised route on the world map and minimap, shows what every mob drops ranked by gold per kill, and adds loot, skinning and gear-grade chances to mob tooltips.

Built for **WoW Forever 1.60.1** (`## Interface: 16001`, Mainline 12.x API). Forever only.

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
| **Farm** | **What do you want to farm?** search box (category, item or mob; suggestions as you type). Category chips: Herbs, Ore, Skinning, Fishing, Cloth, Greens (DE), Leather, Meat, Elemental, Lockboxes, Raw gold. **Rank by** Gold/hour or Skill-ups/hour. **Location**: Anywhere / Caves & mines / Outdoors. **Search in**: Everywhere (your level), Current zone (follows you), or a zone you're questing in. **Enemy zones** toggle. Below that is a ranked list of cards (zone · subzone/cave, rate, mob levels or node skill, risk, loot icons). The detail panel has a zone map preview with the area, spawns, route and your position; what you get per hour (quantity and value per item); the mobs or nodes in the area; and buttons for **Start farming here**, **Show on world map** (preview only) and **Set waypoint**. |
| **Gather + Kill** | **Gather**: Mining / Herbs / Both, plus **Location** and **Search in** (shared with Farm). Sliders: Seconds per kill, Reach from the route, Mob respawn. Cards show total gold/hour and the split (e.g. ore 1g 20s + mobs 80s), plus the gain over doing either alone. Detail panel: map preview; per-hour split with "only gathering here" and "only mobs here" for comparison; the loop's walk / gather / fight minutes; which mobs are **worth killing** (gold per kill, gold per fighting minute, kills/hour) and which to **skip**; top loot per hour; Start farming / Show on world map / Set waypoint. |
| **Mobs & Drops** | Pick a zone (current zone, all zones for your level, or any zone), a Location filter and a mob/item filter. Columns: Mob, Level (coloured by difficulty), Where (cave name / Outdoors / ?), Zone, **Gold/kill**, Best drop with chance, Green %, Blue %, Skin skill, Spawns. Sorted by gold per kill. Click a mob to see its top 8 drops with chance and value, then **Farm this mob** (area and route around its densest camp) or **Show on world map**. |
| **Route & Map** | The active farm: zone preview, stops with coords, target and leg length, loop length/time, loop number and progress. Buttons: Open world map at farm, Skip stop, Restart here, Waypoint, Stop. Map options: route on the world map, route on the minimap (Off / Next stops / Whole loop), farm area outline, route HUD, game map pin and TomTom arrow when starting. |
| **Nodes** | Per-zone node database (what the finder ranks). Columns: Node, Type, Skill, Database spawns, Learned, Shared, Gathered, Value/node; hover for yields. Also: Import GatherMate2/GatherLite, Forget learned nodes in zone. |
| **Stats** | This session (time, value, gold/hour, gathers, kills, coin) with **New session**. Every item you gathered or looted, last 30 sessions, data health, **Save now** and **Backup now**. |
| **Settings** | Route on world map / minimap, farm area outline, hide in combat/instances, route/area opacity, route HUD, game map pin, TomTom, enemy zones, elites, finder assumptions, travel speed, tooltip parts, price source order, sharing, minimap button, save reminder, debug, **Print diagnostics**. |

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
| Gathering | live nodes within reach of the route × seconds per gather | node value × live share (30%) |
| Fighting | mobs killed × seconds per kill (faster for lower-level mobs, +½ reach walked per pull) | each mob's full loot value (drops, coin, disenchant value of greens/blues, skins if you have Skinning) |

**Gold/hour** = (node income + mob income) × 3600 ÷ (walk + gather + fight).

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

Defaults you can change in the tab: 30 s per kill, 30 yd reach, 5 min respawn. Live share and seconds per gather come from Settings → Finder assumptions.

**Limitations:** it uses Classic spawn points and loot tables, distances are straight lines, and mobs you skip can still aggro. **Both** routes through herbs and ore, but you can only track one of them at a time.

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
Skinnable 70 (you 85)                           Classic est. | me n=4
  Light Leather 74% · Medium Leather 19% · Light Hide 5.1% · Medium Hide 1.7%
Drops                                           Classic est.
  Strider Meat 40% · Shadowgem 0.34%
Gear: 2% · 0% · 0%   (green · blue · purple)        Classic est.
  Green (ilvl ~18) DE: Strange Dust ≈ 4s 20c
Pick pocket: Battered Junkbox 15%               (Rogues)
```

- The required skinning skill uses the Forever formula: level 1-10 → 1; 11-20 → (level − 10) × 10; 21+ → level × 5. It's coloured against your skill.
- Your own observations replace the Classic estimate once the sample reaches the threshold (default n = 30). Until then both are shown. Mobs with no data show `learning (n=…)`; numbers are never invented.
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
| `/forage mob` | Print Forager's lines for your target |
| `/forage import` | Import GatherMate2 / GatherLite nodes |
| `/forage save` | Write data to disk now (reloads UI) |
| `/forage backup` / `restore` | Backup status / restore from the backup file (asks first) |
| `/forage reset nodes` / `mobs` / `stats` / `all` | Clear data (asks first) |
| `/forage status` | Version, data and backup status |
| `/forage debug` | Toggle debug messages |

## How the numbers are calculated

- **Value per gather** = Σ (expected count per open × price) × gathers per node (multi-tap ore veins), from the node's CMaNGOS loot table.
- **Prices:** AuctionTrends `GetMarketValue` → Auctionator `GetAuctionPriceByItemID` → vendor price (order set in Settings). Forager only reads them and never touches Auctionator.
- **Area:** each zone is split into a 20 × 20 grid. Forager picks the window of cells, about 800 yards across (450 in Caves & mines), with the highest total value (or skill-up chance). Up to 2 areas per zone (4 in questing mode). In cave mode the area shrinks to the cave's spawn points.
- **Item goals:** node areas are weighted by expected count × price of that item, mob camps by drop chance × price (by chance if the item has no price), fishing zones by catch rate. If the item has no price, results are ranked by quantity per hour.
- **Route:** up to 40 of the best points in the area, at least 25 yd apart, in a closed loop (nearest neighbour + 2-opt). Mob routes go through up to 14 camp centres. Distances come from HereBeDragons zone sizes.
- **Gold/hour (nodes)** = live nodes per loop × value per node × loops per hour.
  - Live nodes = spawn points × live share (default 30%).
  - Loop time = route length ÷ speed + live nodes × seconds per gather (default 3 s).
  - Speed: Auto = running 7 yd/s below level 40, otherwise 60% mount 11.2 yd/s.
- **Gold/hour (mobs)** = kills/hour × value per kill.
  - Kills/hour = setting (default 45) × density, where density = min(1, spawns in area ÷ 25) × level factor.
  - Level factor: mobs more than 3 levels above you, and elites, are excluded unless allowed in Settings; mobs well below you count as faster kills.
  - Value per kill = Σ chance × price for the goal's items. Skinning counts only if your skill is high enough.
  - **Gold/kill** in Mobs & Drops = every drop × price + average coin + disenchant value of greens/blues + skins if you have Skinning.
- **Greens:** P(green) × expected green disenchant value + P(blue) × expected blue disenchant value. The disenchant table follows Classic armour splits by item level. If enchanting mats have no AH price, an estimated vendor value (0.7 × ilvl² copper) is used instead.
- **Gear grade %:** P(at least one green, blue or epic weapon/armour) per kill. This combines independent loot rows as 1 − Π(1 − p) and adds up the chances inside each loot group, including shared world-drop reference tables.
- **Skill-ups/hour:** chance per gather by colour — orange 100%, yellow 75%, green 25%, grey 0. Herb/ore colour thresholds are required skill +25/+50/+100.
  - Fishing is rough: min(1, (300 − skill)/300 + 0.05) × 0.6 per catch.
  - Lockpicking: junkbox chance × colour chance. Rogue skill is assumed to be level × 5, which is the cap.
- **Questing score** = rate × loop time ÷ (loop time + 2 × distance to nearest quest objective ÷ speed).
- **Session gold/hour** = value of everything you looted at current prices, plus coin, ÷ session time.

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

- `tests/run_tests.lua`: a mock-API harness (Lua 5.1) with 33 tests. They cover:
  - TOC packaging metadata, login, decoding, finder (all goal types, item goals, both modes, questing, caves/outdoors), routes, farm-this-mob;
  - tooltips, capture (herb, unknown Forever node, creature loot, skinning, secret values), sharing, imports, backup/restore/safe mode;
  - UI tabs (fails on any UI build error), slash commands, maps (no pins created, route drawing in every minimap mode), settings migrations;
  - cave learning and explored-area lookups, preview / open map at farm / game map pin, world-map drawing on zone, continent and unrelated maps;
  - OpenMap (mocked API): positions, layer above its art, view glide, window hide/restore, preview cleared on close;
  - Gather + Kill: split and loop time add up, never below gathering alone, worthy/skipped mobs on the right side of the loop rate, slower kills never raise the rate, ore/herb/both, start as a farm.

  Run with `lua5.1 tests/run_tests.lua . Forager_Data Forager_Backup`.
- `luacheck .` is clean (config in `.luacheckrc`).
- `tools/`: data build scripts (`build_data.py`) and instructions to regenerate `Forager_Data` from QuestieDB and CMaNGOS.

## Known limitations

- Spawns and loot rates are Classic-era. Forever changed some itemization (world epics, rare spawns), so gear-grade rates for rares may be off. Your own data takes over at n ≥ 30.
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

## Credits & licence

Forager is GPL-3.0-or-later. Bundled data comes from QuestieDB (Forever data) and CMaNGOS classic-db, both GPLv3. Libraries: HereBeDragons core (BSD), LibStub, CallbackHandler-1.0, LibDataBroker-1.1. See `THIRD_PARTY.md`.
