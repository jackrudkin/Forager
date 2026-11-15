# Forager (WoW Forever)

Tells you where to farm for any gathering profession or material, draws the area and an optimised route on the world map and minimap, shows your own icon for every known node, and adds loot, skinning and gear-grade chances to mob tooltips. Built to replace GatherLite, GatherMate2 and similar addons.

Built for **WoW Forever 1.60.1** (`## Interface: 16001`, Mainline 12.x API). Forever only.

## Install

1. Extract the zip into `World of Warcraft\_forever_\Interface\AddOns\`. You get three folders:
   - `Forager\Forager.toc`: the addon.
   - `Forager_Backup\Forager_Backup.toc`: storage-only addon that keeps a second copy of your data in its own file.
   - `Forager_Data\Forager_Data.toc`: the bundled node/mob/loot database, loaded on demand.

   Each `.toc` must sit directly inside its folder (not `Forager\Forager\`).
2. Restart the game or `/reload`, then tick **Forager**, **Forager Backup** and **Forager Data** in the AddOns list.
3. If Forever patches and the addon shows "Out of date", tick **Load out of date AddOns**, or edit the `## Interface:` line (`/dump (select(4, GetBuildInfo()))` gives the new number).
4. Switching from GatherMate2 or GatherLite: leave them enabled for one login. Forager imports their saved nodes automatically (or type `/forage import`). Then you can delete them.

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

## Minimap node identification

Since 7 Nov (build 70862) and 13 Nov 2026 (a server-side change), Forever no longer lets addons read what the yellow tracking dots are. The client has also never had a way to restyle them. So Forager draws its own pins:

- The icon is the item the node gives (Copper Ore, Peacebloom…).
- The border shows your skill: orange, yellow, green, grey, or red (too high).
- Pins fade with distance on the minimap.
- Hover a pin for: name, required skill vs yours, source, times gathered, last gathered, and what it yielded.

A pin marks a known spawn point, not a live node. The game's own yellow dots still show live nodes.

## Window tabs (`/forage`)

| Tab | What's there |
|---|---|
| **Header** | **Goal** dropdown; **Rank by** (Gold/hour or Skill-ups/hour); big **Start farming** button and **Stop**; **Questing zone** dropdown with **Use current zone** and **X** to clear; optional **Next hub** zone. The status line shows `Questing in: <zone>`, the active farm and session gold/hour. |
| **Find** | Ranked table of zones and sub-areas. Columns: Zone, Area (centre coords), Rate, w/ travel (questing mode), Detour, Levels, Skill (coloured vs yours), Density, Risk (Friendly / Contested / Enemy territory), Data confidence. Hover a row for why it ranks: node mix, mobs with value per kill, quest mobs in the area, quest objectives inside it, detour minutes. Click a row to draw it and start the arrow. In questing mode a line shows **best anywhere** for comparison. |
| **Map & Route** | Active route: waypoints with coords, target and distance from the previous one; loop length/time, loop number, progress. Buttons: Open world map, Skip waypoint, Restart from here, Stop. Layer toggles (area, route, arrow, mob camps, minimap pins, world map pins) and a legend. |
| **Nodes** | Per-zone node database. Columns: Show, Node, Type, Skill, Database spawns, Learned, Shared, Gathered, Value/node. Click a row to show or hide that node type on the maps. Also: Import GatherMate2/GatherLite, Forget learned nodes in zone, kind filters, "Only nodes I can gather". |
| **Mobs** | Look up a mob or a material (e.g. `Linen Cloth`, `Boar`, or an item link). Columns: Mob, Level, Type, Zone, Chance for the searched material, Skinning skill, Green/Blue/Epic %, Value/kill, your sample size. Hover a row for the full tooltip lines. |
| **Stats** | This session (time, value, gold/hour, gathers, kills, coin) with **New session**. Every item you gathered or looted (total, this session, value). Last 30 sessions. Data health (learned nodes, mobs observed, database, last write, backup). **Save now** and **Backup now**. |
| **Settings** | Map layers and opacity, pin size, distance fade, hide in combat/instances, finder assumptions (live share of spawn points, kills/hour, casts/hour, seconds per gather, sample size where your data takes over, travel speed, include elites), tooltip parts, price source order, sharing, minimap button, save reminder, debug. |

There is also a minimap button (left-click: window; right-click: Start farming; shift-right-click: stop), an addon compartment entry and an LDB launcher.

## Goals

Herbalism, Mining, Skinning, Fishing, Cloth (Linen to Runecloth/Felcloth), Greens to disenchant, Leather/hides, Meat (Cooking), Elemental mats, Lockboxes (Rogue pick pocket junkboxes), and Raw gold (all loot). Results are filtered by your skill, level and faction, all auto-detected from the game.

**Skill-ups / hour** is available for Herbalism, Mining, Skinning, Leather, Fishing and Lockboxes. It ranks orange and yellow targets for your current skill instead of profit.

## Questing-zone mode

Pick the zone you're questing in, or **Use current zone**, or **Auto** (follows you), plus an optional next-hub zone. The choice is remembered per character.

- Only those zones are ranked. Each area is scored by its rate including the detour: travel from the nearest active quest objective (`C_QuestLog.GetQuestsOnMap`) plus one loop. The **Detour** column shows the extra minutes.
- Mobs named in your active objectives (e.g. "Prowler slain: 2/8") are listed as quest mobs when they're in the farming area. Quest objectives inside the area are counted.
- **X** clears it and goes back to dedicated farming. The Find tab always shows the best spot anywhere for comparison.

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
| `/forage start [goal]` | Best spot now. Goals: herb ore skin fish cloth greens leather meat elemental lockbox gold |
| `/forage stop` | Stop the route |
| `/forage find` / `map` / `nodes` / `mobs` / `stats` / `settings` | Open that tab |
| `/forage quest <zone>` / `current` / `auto` / `off` | Set or clear the questing zone |
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
- **Area:** each zone is split into a 20 × 20 grid. Forager picks the window of cells, about 800 yards across, with the highest total value (or skill-up chance). Up to 2 areas per zone (4 in questing mode).
- **Route:** up to 40 of the best points in the area, at least 25 yd apart, in a closed loop (nearest neighbour + 2-opt). Mob routes go through up to 14 camp centres. Distances come from HereBeDragons zone sizes.
- **Gold/hour (nodes)** = live nodes per loop × value per node × loops per hour.
  - Live nodes = spawn points × live share (default 30%).
  - Loop time = route length ÷ speed + live nodes × seconds per gather (default 3 s).
  - Speed: Auto = running 7 yd/s below level 40, otherwise 60% mount 11.2 yd/s.
- **Gold/hour (mobs)** = kills/hour × value per kill.
  - Kills/hour = setting (default 45) × density, where density = min(1, spawns in area ÷ 25) × level factor.
  - Level factor: mobs more than 3 levels above you, and elites, are excluded unless allowed in Settings; mobs well below you count as faster kills.
  - Value per kill = Σ chance × price for the goal's items. Cloth, meat and elemental also get ×1.2 for stacks. Skinning counts only if your skill is high enough.
- **Greens:** P(green) × expected disenchant value + P(blue) × one shard. The disenchant table follows Classic armour splits by item level. If enchanting mats have no AH price, an estimated vendor value (0.7 × ilvl² copper) is used instead.
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

- `tests/run_tests.lua`: a mock-API harness (Lua 5.1) with 26 tests covering login, decoding, finder (all goal types, both modes, questing), routes, tooltips, capture (herb, unknown Forever node, creature loot, skinning, secret values), sharing, imports, backup/restore/safe mode, UI tabs, slash commands and pins. Run with `lua5.1 tests/run_tests.lua`.
- `luacheck .` is clean (config in `.luacheckrc`).
- `tools/`: data build scripts (`build_data.py`) and instructions to regenerate `Forager_Data` from QuestieDB and CMaNGOS.

## Known limitations

- Spawns and loot rates are Classic-era. Forever changed some itemization (world epics, rare spawns), so gear-grade rates for rares may be off. Your own data takes over at n ≥ 30.
- New Forever zones and node types are learned only as you, your guild or imports find them.
- Gold/hour is an estimate. It assumes you're the only farmer, that 30% of spawn points are live, and straight-line travel without terrain.
- Lockpicking skill can't be read from the API, so it's assumed to be at the level cap.
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
| `WorldMapFrame:GetCanvas()`, `ScrollContainer:GetCanvasScale()`, `OnMapChanged` | World map overlay | Area/route not drawn on world map |
| Templates `ButtonFrameTemplate`, `PanelTabButtonTemplate`, `UICheckButtonTemplate`, `InputBoxTemplate` | UI | Plain-frame fallbacks for the window and tabs |
| Textures `Interface\Minimap\MinimapArrow`, `Interface\Common\Indicator-*` | Arrow, camp markers | Blank texture (cosmetic) |
| `C_Item.GetItemIconByID` for Forever-only items | Pin icons | Herb/ore default icon |

## Credits & licence

Forager is GPL-3.0-or-later. Bundled data comes from QuestieDB (Forever data) and CMaNGOS classic-db, both GPLv3. Libraries: HereBeDragons (BSD), LibStub, CallbackHandler-1.0, LibDataBroker-1.1. See `THIRD_PARTY.md`.
