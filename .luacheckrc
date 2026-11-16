std = "lua51"
max_line_length = false
exclude_files = { "Libs/**", "Forager_Data/**", "Data/NodeTypes.lua", "Data/Zones.lua", "tests/**", "tools/**" }
ignore = { "212", "213", "432", "542" } -- unused args/loop vars, shadowed self, empty if branch
globals = {
  "Forager", "ForagerDB", "ForagerBackupDB", "ForagerData",
  "SLASH_FORAGER1", "SLASH_FORAGER2", "SlashCmdList", "StaticPopupDialogs",
  "Forager_OnAddonCompartmentClick", "Forager_OnAddonCompartmentEnter", "Forager_OnAddonCompartmentLeave",
}
read_globals = {
  "LibStub", "CreateFrame", "UIParent", "Minimap", "WorldMapFrame", "GameTooltip", "DEFAULT_CHAT_FRAME",
  "UISpecialFrames", "C_Timer", "C_Map", "C_AddOns", "C_Item", "C_Spell", "C_ChatInfo", "C_QuestLog", "C_Minimap",
  "GetTime", "time", "date", "strsplit", "strtrim", "wipe", "tinsert", "hooksecurefunc", "issecretvalue",
  "SecondsToTime", "InCombatLockdown", "IsInInstance", "GetCVar", "GetPlayerFacing", "IsInGuild", "IsInGroup",
  "IsInRaid", "IsShiftKeyDown", "IsMouseButtonDown", "GetCursorPosition", "ReloadUI", "ToggleWorldMap", "GetMoney",
  "GetRealmName", "UnitName", "UnitLevel", "UnitClass", "UnitFactionGroup", "UnitGUID", "GetProfessions",
  "GetProfessionInfo", "GetNumLootItems", "GetLootSlotLink", "GetLootSlotInfo", "GetLootSourceInfo", "Enum",
  "TooltipDataProcessor", "PanelTemplates_SetNumTabs", "PanelTemplates_SetTab", "PanelTemplates_TabResize",
  "ButtonFrameTemplate_HidePortrait", "ButtonFrameTemplate_HideButtonBar", "StaticPopup_Show", "YES", "NO",
  "GetSpellInfo", "GetMinimapShape", "Auctionator", "AuctionTrends", "GatherMate2HerbDB", "GatherMate2MineDB",
  "GatherMate2FishDB", "GatherLiteSettings",
  "C_MapExplorationInfo", "CreateVector2D", "IsIndoors", "GetSubZoneText", "UnitCanAttack", "GetBuildInfo",
  "OpenWorldMap", "UiMapPoint", "C_SuperTrack", "TomTom", "HBD_PINS_WORLDMAP_SHOW_CONTINENT", "Mixin",
  "BackdropTemplateMixin", "OpenMapAPI",
}
