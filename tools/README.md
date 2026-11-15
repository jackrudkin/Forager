# Rebuilding the bundled data

1. `git clone --depth 1 https://github.com/Questie/QuestieDB.git` and `https://github.com/cmangos/classic-db.git`
2. `lua5.1 dumpq.lua QuestieDB/data/Forever/foreverObjectDB.lua objectData obj.json`
3. `lua5.1 dumpq.lua QuestieDB/data/Forever/foreverNpcDB.lua npcData npc.json`
4. `cp QuestieDB/support/Forever/Zones/areaIdToUiMapId.lua areamap.lua`
5. `zcat classic-db/Full_DB/ClassicDB_*.sql.gz > classic.sql`
6. `python3 build_data.py` (writes ../build/Forager/Data/*.lua and ../build/Forager_Data/*.lua; adjust OUT_* paths)
