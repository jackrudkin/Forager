-- Locales: ns.L["English text"] returns the client's language where a translation exists, else the
-- English text. deDE and frFR cover the tab names, Settings, the HUD, searching and the gold
-- breakdown; everything else is English. Zone names always come from the client (DataStore:ZoneName).
local _, ns = ...
local L = setmetatable({}, { __index = function(_, k) return k end })
ns.L = L
local locale = GetLocale and GetLocale() or "enUS"

local T = {}

T.deDE = {
    -- tabs
    ["Farm"] = "Farmen", ["Gather + Kill"] = "Sammeln + Töten", ["Mobs & Drops"] = "Mobs & Beute", ["Route & Map"] = "Route & Karte",
    ["Nodes"] = "Vorkommen", ["Stats"] = "Statistik", ["Settings"] = "Einstellungen",
    -- settings pages
    ["Maps & farming"] = "Karten & Farmen", ["Estimates"] = "Schätzungen", ["Tooltips, prices & more"] = "Tooltips, Preise & mehr",
    ["Map & minimap"] = "Karte & Minikarte", ["Route on the world map"] = "Route auf der Weltkarte",
    ["Route on the minimap"] = "Route auf der Minikarte", ["Off"] = "Aus", ["Next stops"] = "Nächste Stopps", ["Whole loop"] = "Ganze Runde",
    ["Farm area outline"] = "Umriss des Farmgebiets", ["Hide overlays in combat"] = "Im Kampf ausblenden",
    ["Hide overlays in instances"] = "In Instanzen ausblenden", ["Route opacity"] = "Deckkraft der Route", ["Area opacity"] = "Deckkraft des Gebiets",
    ["Nodes: Forager draws no node pins; use the game's own tracking (Find Herbs / Find Minerals)."] =
        "Vorkommen: Forager zeichnet keine Pins; nutze die Suche des Spiels (Kräutersuche / Mineraliensuche).",
    ["Farming"] = "Farmen", ["Route HUD with arrow"] = "Routen-HUD mit Pfeil", ["Game map pin when starting"] = "Kartenmarkierung beim Start",
    ["TomTom arrow when starting"] = "TomTom-Pfeil beim Start", ["Rank enemy-faction zones"] = "Gebiete der Gegenfraktion einbeziehen",
    ["Include elites / high-level mobs"] = "Elite- und hochstufige Mobs einbeziehen", ["Your ruleset (for gank risk)"] = "Dein Regelwerk (für Gank-Risiko)",
    ["Auto"] = "Automatisch", ["detected"] = "erkannt", ["not detected yet: PvP assumed"] = "noch nicht erkannt: PvP angenommen",
    ["Normal (PvE)"] = "Normal (PvE)", ["Hide spots with risk"] = "Orte mit Risiko ausblenden", ["Show all"] = "Alle zeigen",
    ["Very high"] = "Sehr hoch", ["High or worse"] = "Hoch oder höher", ["Medium or worse (Low only)"] = "Mittel oder höher (nur Niedrig)",
    ["Farming helpers"] = "Farmhilfen", ["Flip Find Herbs / Find Minerals"] = "Kräuter-/Mineraliensuche wechseln",
    ["On routes with both herbs and ore (and both professions): switches tracking every 4 s while you move, out of combat and not casting. Forever allows only one resource tracker at a time."] =
        "Auf Routen mit Kräutern und Erz (und beiden Berufen): wechselt die Suche alle 4 s, während du dich bewegst, außerhalb des Kampfes und ohne Zauber. In Forever ist nur eine Rohstoffsuche gleichzeitig aktiv.",
    ["Turn tracking back on after dying"] = "Suche nach dem Tod wieder einschalten",
    ["Dying clears tracking in Forever; this turns your herb or ore tracking back on once you are alive."] =
        "In Forever endet die Suche beim Tod; dies schaltet deine Kräuter- oder Erzsuche wieder ein, sobald du lebst.",
    ["Ready check when starting a farm"] = "Bereitschaftscheck beim Farmstart",
    ["Warns when tracking is off or your Mining Pick / Skinning Knife is not in your bags, with a one-click fix for tracking."] =
        "Warnt, wenn die Suche aus ist oder Spitzhacke / Kürschnermesser nicht in deinen Taschen sind; die Suche lässt sich mit einem Klick einschalten.",
    ["Skip stops you just gathered"] = "Gerade gesammelte Stopps überspringen",
    ["The route arrow skips stops whose node you gathered until it can have respawned (spawn data, or faster if you have seen it back sooner)."] =
        "Der Routenpfeil überspringt Stopps, die du gesammelt hast, bis sie wieder da sein können (Spawndaten, oder früher, wenn du sie früher gesehen hast).",
    ["Pause the session clock when idle"] = "Sitzungsuhr bei Inaktivität anhalten",
    ["Session gold/hour counts active time only: AFK or 3 minutes without moving, looting or fighting pauses the clock."] =
        "Gold/Stunde der Sitzung zählt nur aktive Zeit: AFK oder 3 Minuten ohne Bewegung, Plündern oder Kampf hält die Uhr an.",
    ["Spawns and yields"] = "Spawns und Erträge", ["Use spawn-pool data"] = "Spawn-Pool-Daten verwenden",
    ["Live nodes per spawn point by node type and zone, and respawn time per mob, from the CMaNGOS spawn pools. Off: the flat share below and 5 min respawns."] =
        "Aktive Vorkommen pro Spawnpunkt nach Typ und Gebiet sowie Respawnzeit pro Mob aus den CMaNGOS-Spawn-Pools. Aus: der feste Anteil unten und 5 Min. Respawn.",
    ["Live share when spawn data is off"] = "Aktiver Anteil ohne Spawndaten", ["Estimate weight (samples)"] = "Gewicht der Schätzung (Proben)",
    ["Your data is blended with the estimates: after n of your samples it counts n / (n + this). At 30, your data counts half after 30 samples."] =
        "Deine Daten werden mit den Schätzungen gemischt: nach n eigenen Proben zählen sie n / (n + diesen Wert). Bei 30 zählen deine Daten nach 30 Proben zur Hälfte.",
    ["Extra seconds per node"] = "Extra-Sekunden pro Vorkommen", ["Dismount, walk in. Cast and loot times are measured."] =
        "Absitzen, hinlaufen. Zauber- und Plünderzeiten werden gemessen.",
    ["Fishing casts per hour"] = "Angelwürfe pro Stunde", ["Bountiful Harvest (Legacy perk)"] = "Bountiful Harvest (Legacy)",
    ["Not learned"] = "Nicht gelernt", ["Rank %d: +%d%% Scarce"] = "Rang %d: +%d%% Scarce",
    ["Kills and travel"] = "Kills und Reisen", ["Kills per hour until measured"] = "Kills pro Stunde (bis gemessen)",
    ["Equal-level mobs. Forager measures your fights and the time between them and blends that in."] =
        "Mobs deiner Stufe. Forager misst deine Kämpfe und die Zeit dazwischen und mischt das ein.",
    ["Travel speed"] = "Reisetempo", ["Auto (measured, else by level)"] = "Automatisch (gemessen, sonst nach Stufe)",
    ["Running (7 yd/s)"] = "Laufen (7 m/s)", ["60% mount"] = "60%-Reittier", ["100% mount"] = "100%-Reittier",
    ["Measured from your play"] = "Aus deinem Spiel gemessen", ["Gold per hour"] = "Gold pro Stunde",
    ["After AH cut and repairs"] = "Nach AH-Gebühr und Reparaturen",
    ["Takes the 5% auction house cut off items priced from the AH, and your measured repair cost per kill. Deposits are left out (1c minimum, returned on sale)."] =
        "Zieht die 5% Auktionshausgebühr bei AH-bepreisten Gegenständen und deine gemessenen Reparaturkosten pro Kill ab. Anzahlungen bleiben außen vor (mind. 1 Kupfer, beim Verkauf erstattet).",
    ["Calibrate with my farm sessions"] = "Mit meinen Farmsitzungen kalibrieren",
    ["After 10+ minutes farming a spot, its estimate is scaled by what you actually made there (and spots of the same kind, once you have an hour)."] =
        "Nach 10+ Minuten an einem Ort wird seine Schätzung mit deinem tatsächlichen Ertrag skaliert (und ähnliche Orte, sobald du eine Stunde hast).",
    ["Tooltips"] = "Tooltips", ["Forager lines on mob tooltips"] = "Forager-Zeilen in Mob-Tooltips", ["Skinning chances"] = "Kürschnerchancen",
    ["Cloth / meat / elemental drops"] = "Stoff / Fleisch / Elementarbeute", ["Gear grade chances (green/blue/purple)"] = "Chancen auf Ausrüstung (grün/blau/lila)",
    ["Pick pocket boxes (Rogue)"] = "Taschendiebstahl-Kassetten (Schurke)", ["Best spot on item tooltips"] = "Bester Ort in Gegenstand-Tooltips",
    ["Items you can farm show the best spot for your character. Alt+Shift+click an item link to farm it."] =
        "Farmbare Gegenstände zeigen den besten Ort für deinen Charakter. Alt+Umschalt+Klick auf einen Gegenstandslink, um ihn zu farmen.",
    ["Prices"] = "Preise", ["Vendor only"] = "Nur Händlerpreis", ["TSM price"] = "TSM-Preis", ["Available"] = "Verfügbar",
    ["Prices come from your price addon, which keeps them per realm and faction."] =
        "Preise kommen von deinem Preis-Addon, das sie pro Realm und Fraktion führt.",
    ["Sharing (off by default)"] = "Teilen (standardmäßig aus)", ["Share my node finds with guild"] = "Funde mit der Gilde teilen",
    ["Sends node type, zone and position only. Never in instances."] = "Sendet nur Typ, Gebiet und Position. Nie in Instanzen.",
    ["Share with party"] = "Mit der Gruppe teilen", ["Other"] = "Sonstiges", ["Hide minimap button"] = "Minikarten-Knopf verbergen",
    ["Save reminder every N gathers (0 = off)"] = "Speicher-Erinnerung alle N Funde (0 = aus)", ["Debug messages"] = "Debug-Meldungen",
    ["Self-test"] = "Selbsttest", ["Diagnostics"] = "Diagnose",
    ["Hardcore character: Realistic spots are stricter."] = "Hardcore-Charakter: Realistische Orte sind strenger.",
    ["Cast times"] = "Zauberzeiten", ["none yet"] = "noch keine", ["Yields: %d node types, %d mostly yours"] = "Erträge: %d Typen, %d überwiegend deine",
    ["Calibrated from %d spots, %.1f h farmed."] = "Kalibriert aus %d Orten, %.1f h gefarmt.",
    ["No farm sessions yet: start a farm and play 10+ minutes."] = "Noch keine Farmsitzungen: starte eine Farm und spiele 10+ Minuten.",
    ["%d errors caught"] = "%d Fehler abgefangen",
    -- searching, HUD, tooltips
    ["Searching..."] = "Suche...", ["Searching... %d%%"] = "Suche... %d%%",
    ["No results - see the panel on the right."] = "Keine Ergebnisse - siehe rechts.",
    ["Stop"] = "Stopp", ["Skip"] = "Weiter", ["Map"] = "Karte", ["Turn on"] = "Einschalten", ["%d cooling"] = "%d abkühlend",
    ["Stop %d/%d  ·  loop %d (%d%%)  ·  %s"] = "Stopp %d/%d  ·  Runde %d (%d%%)  ·  %s",
    ["best spot"] = "bester Ort", ["Alt+Shift+click: farm this with Forager"] = "Alt+Umschalt+Klick: mit Forager farmen",
    ["Looking for the best place to farm %s."] = "Suche den besten Ort zum Farmen von %s.",
    ["Seconds per kill"] = "Sekunden pro Kill", ["Mob respawn"] = "Mob-Respawn",
    ["Fight + loot for a mob of your level, until Forager has measured your fights (then blended in). Lower-level mobs count as faster."] =
        "Kampf + Plündern für einen Mob deiner Stufe, bis Forager deine Kämpfe gemessen hat (dann eingemischt). Niedrigere Mobs zählen als schneller.",
    ["Time before a mob you killed is back, for mobs without spawn data (or with spawn data off). A loop shorter than this meets fewer mobs."] =
        "Zeit, bis ein getöteter Mob wieder da ist, für Mobs ohne Spawndaten (oder mit Spawndaten aus). Eine kürzere Runde trifft weniger Mobs.",
    -- gold breakdown
    ["Estimate (full prices)"] = "Schätzung (volle Preise)", ["AH cut 5%"] = "AH-Gebühr 5%", ["Repairs (measured)"] = "Reparaturen (gemessen)",
    ["You keep"] = "Dir bleibt",
}

T.frFR = {
    -- tabs
    ["Farm"] = "Farmer", ["Gather + Kill"] = "Récolter + tuer", ["Mobs & Drops"] = "Monstres & butin", ["Route & Map"] = "Itinéraire & carte",
    ["Nodes"] = "Gisements", ["Stats"] = "Statistiques", ["Settings"] = "Paramètres",
    -- settings pages
    ["Maps & farming"] = "Cartes & farm", ["Estimates"] = "Estimations", ["Tooltips, prices & more"] = "Infobulles, prix & plus",
    ["Map & minimap"] = "Carte & minicarte", ["Route on the world map"] = "Itinéraire sur la carte du monde",
    ["Route on the minimap"] = "Itinéraire sur la minicarte", ["Off"] = "Non", ["Next stops"] = "Prochains arrêts", ["Whole loop"] = "Boucle entière",
    ["Farm area outline"] = "Contour de la zone", ["Hide overlays in combat"] = "Masquer en combat",
    ["Hide overlays in instances"] = "Masquer en instance", ["Route opacity"] = "Opacité de l'itinéraire", ["Area opacity"] = "Opacité de la zone",
    ["Nodes: Forager draws no node pins; use the game's own tracking (Find Herbs / Find Minerals)."] =
        "Gisements : Forager n'affiche pas de marqueurs ; utilisez le pistage du jeu (Découverte d'herbes / de gisements).",
    ["Farming"] = "Farm", ["Route HUD with arrow"] = "Fenêtre d'itinéraire avec flèche", ["Game map pin when starting"] = "Repère sur la carte au départ",
    ["TomTom arrow when starting"] = "Flèche TomTom au départ", ["Rank enemy-faction zones"] = "Inclure les zones de la faction adverse",
    ["Include elites / high-level mobs"] = "Inclure élites / monstres de haut niveau", ["Your ruleset (for gank risk)"] = "Vos règles (pour le risque de gank)",
    ["Auto"] = "Auto", ["detected"] = "détecté", ["not detected yet: PvP assumed"] = "pas encore détecté : JcJ supposé",
    ["Normal (PvE)"] = "Normal (JcE)", ["Hide spots with risk"] = "Masquer les lieux à risque", ["Show all"] = "Tout afficher",
    ["Very high"] = "Très élevé", ["High or worse"] = "Élevé ou plus", ["Medium or worse (Low only)"] = "Moyen ou plus (faible seulement)",
    ["Farming helpers"] = "Aides au farm", ["Flip Find Herbs / Find Minerals"] = "Alterner herbes / gisements",
    ["On routes with both herbs and ore (and both professions): switches tracking every 4 s while you move, out of combat and not casting. Forever allows only one resource tracker at a time."] =
        "Sur les itinéraires avec herbes et minerai (et les deux métiers) : change de pistage toutes les 4 s en mouvement, hors combat et sans incantation. Forever n'autorise qu'un seul pistage de ressources à la fois.",
    ["Turn tracking back on after dying"] = "Réactiver le pistage après la mort",
    ["Dying clears tracking in Forever; this turns your herb or ore tracking back on once you are alive."] =
        "Dans Forever, mourir coupe le pistage ; ceci réactive votre pistage d'herbes ou de minerai une fois en vie.",
    ["Ready check when starting a farm"] = "Vérification au départ d'un farm",
    ["Warns when tracking is off or your Mining Pick / Skinning Knife is not in your bags, with a one-click fix for tracking."] =
        "Avertit si le pistage est coupé ou si votre pioche / couteau à dépecer n'est pas dans vos sacs ; le pistage se réactive en un clic.",
    ["Skip stops you just gathered"] = "Passer les arrêts déjà récoltés",
    ["The route arrow skips stops whose node you gathered until it can have respawned (spawn data, or faster if you have seen it back sooner)."] =
        "La flèche passe les arrêts récoltés jusqu'à leur réapparition possible (données d'apparition, ou plus tôt si vous l'avez déjà vu revenir).",
    ["Pause the session clock when idle"] = "Mettre la session en pause si inactif",
    ["Session gold/hour counts active time only: AFK or 3 minutes without moving, looting or fighting pauses the clock."] =
        "L'or/heure de la session ne compte que le temps actif : ABS ou 3 minutes sans bouger, ramasser ni combattre met l'horloge en pause.",
    ["Spawns and yields"] = "Apparitions et rendements", ["Use spawn-pool data"] = "Utiliser les données d'apparition",
    ["Live nodes per spawn point by node type and zone, and respawn time per mob, from the CMaNGOS spawn pools. Off: the flat share below and 5 min respawns."] =
        "Gisements actifs par point d'apparition selon le type et la zone, et réapparition par monstre, d'après les pools CMaNGOS. Désactivé : la part fixe ci-dessous et 5 min de réapparition.",
    ["Live share when spawn data is off"] = "Part active sans données d'apparition", ["Estimate weight (samples)"] = "Poids de l'estimation (échantillons)",
    ["Your data is blended with the estimates: after n of your samples it counts n / (n + this). At 30, your data counts half after 30 samples."] =
        "Vos données sont mêlées aux estimations : après n échantillons, elles comptent n / (n + cette valeur). À 30, vos données comptent pour moitié après 30 échantillons.",
    ["Extra seconds per node"] = "Secondes en plus par gisement", ["Dismount, walk in. Cast and loot times are measured."] =
        "Descendre de monture, s'approcher. Les temps d'incantation et de ramassage sont mesurés.",
    ["Fishing casts per hour"] = "Lancers de pêche par heure", ["Bountiful Harvest (Legacy perk)"] = "Bountiful Harvest (Legacy)",
    ["Not learned"] = "Non appris", ["Rank %d: +%d%% Scarce"] = "Rang %d : +%d%% Scarce",
    ["Kills and travel"] = "Victimes et déplacements", ["Kills per hour until measured"] = "Victimes par heure (avant mesure)",
    ["Equal-level mobs. Forager measures your fights and the time between them and blends that in."] =
        "Monstres de votre niveau. Forager mesure vos combats et le temps entre eux et en tient compte.",
    ["Travel speed"] = "Vitesse de déplacement", ["Auto (measured, else by level)"] = "Auto (mesurée, sinon selon le niveau)",
    ["Running (7 yd/s)"] = "Course (7 m/s)", ["60% mount"] = "Monture 60%", ["100% mount"] = "Monture 100%",
    ["Measured from your play"] = "Mesuré pendant votre jeu", ["Gold per hour"] = "Or par heure",
    ["After AH cut and repairs"] = "Après taxe HV et réparations",
    ["Takes the 5% auction house cut off items priced from the AH, and your measured repair cost per kill. Deposits are left out (1c minimum, returned on sale)."] =
        "Retire la taxe de 5% de l'hôtel des ventes sur les objets estimés à l'HV, et votre coût de réparation mesuré par victime. Les dépôts sont ignorés (1c minimum, rendus à la vente).",
    ["Calibrate with my farm sessions"] = "Calibrer avec mes sessions de farm",
    ["After 10+ minutes farming a spot, its estimate is scaled by what you actually made there (and spots of the same kind, once you have an hour)."] =
        "Après 10+ minutes sur un lieu, son estimation est ajustée selon ce que vous y avez réellement gagné (et les lieux similaires, dès une heure).",
    ["Tooltips"] = "Infobulles", ["Forager lines on mob tooltips"] = "Lignes Forager sur les monstres", ["Skinning chances"] = "Chances de dépeçage",
    ["Cloth / meat / elemental drops"] = "Tissu / viande / butin élémentaire", ["Gear grade chances (green/blue/purple)"] = "Chances d'équipement (vert/bleu/violet)",
    ["Pick pocket boxes (Rogue)"] = "Coffrets de vol à la tire (voleur)", ["Best spot on item tooltips"] = "Meilleur lieu sur les objets",
    ["Items you can farm show the best spot for your character. Alt+Shift+click an item link to farm it."] =
        "Les objets farmables affichent le meilleur lieu pour votre personnage. Alt+Maj+clic sur un lien d'objet pour le farmer.",
    ["Prices"] = "Prix", ["Vendor only"] = "Marchand seulement", ["TSM price"] = "Prix TSM", ["Available"] = "Disponibles",
    ["Prices come from your price addon, which keeps them per realm and faction."] =
        "Les prix viennent de votre addon de prix, qui les garde par royaume et faction.",
    ["Sharing (off by default)"] = "Partage (désactivé par défaut)", ["Share my node finds with guild"] = "Partager mes trouvailles avec la guilde",
    ["Sends node type, zone and position only. Never in instances."] = "Envoie seulement le type, la zone et la position. Jamais en instance.",
    ["Share with party"] = "Partager avec le groupe", ["Other"] = "Divers", ["Hide minimap button"] = "Masquer le bouton de la minicarte",
    ["Save reminder every N gathers (0 = off)"] = "Rappel de sauvegarde toutes les N récoltes (0 = non)", ["Debug messages"] = "Messages de débogage",
    ["Self-test"] = "Autotest", ["Diagnostics"] = "Diagnostic",
    ["Hardcore character: Realistic spots are stricter."] = "Personnage hardcore : les lieux réalistes sont plus stricts.",
    ["Cast times"] = "Temps d'incantation", ["none yet"] = "aucun pour l'instant", ["Yields: %d node types, %d mostly yours"] = "Rendements : %d types, %d surtout les vôtres",
    ["Calibrated from %d spots, %.1f h farmed."] = "Calibré sur %d lieux, %.1f h de farm.",
    ["No farm sessions yet: start a farm and play 10+ minutes."] = "Pas encore de session : lancez un farm et jouez 10+ minutes.",
    ["%d errors caught"] = "%d erreurs interceptées",
    -- searching, HUD, tooltips
    ["Searching..."] = "Recherche...", ["Searching... %d%%"] = "Recherche... %d%%",
    ["No results - see the panel on the right."] = "Aucun résultat - voir à droite.",
    ["Stop"] = "Arrêt", ["Skip"] = "Passer", ["Map"] = "Carte", ["Turn on"] = "Activer", ["%d cooling"] = "%d en attente",
    ["Stop %d/%d  ·  loop %d (%d%%)  ·  %s"] = "Arrêt %d/%d  ·  boucle %d (%d%%)  ·  %s",
    ["best spot"] = "meilleur lieu", ["Alt+Shift+click: farm this with Forager"] = "Alt+Maj+clic : farmer avec Forager",
    ["Looking for the best place to farm %s."] = "Recherche du meilleur lieu pour farmer %s.",
    ["Seconds per kill"] = "Secondes par victime", ["Mob respawn"] = "Réapparition des monstres",
    ["Fight + loot for a mob of your level, until Forager has measured your fights (then blended in). Lower-level mobs count as faster."] =
        "Combat + ramassage pour un monstre de votre niveau, jusqu'à ce que Forager mesure vos combats (puis mélangé). Les monstres plus faibles comptent comme plus rapides.",
    ["Time before a mob you killed is back, for mobs without spawn data (or with spawn data off). A loop shorter than this meets fewer mobs."] =
        "Délai avant le retour d'un monstre tué, pour les monstres sans données d'apparition (ou données désactivées). Une boucle plus courte croise moins de monstres.",
    -- gold breakdown
    ["Estimate (full prices)"] = "Estimation (prix pleins)", ["AH cut 5%"] = "Taxe HV 5%", ["Repairs (measured)"] = "Réparations (mesurées)",
    ["You keep"] = "Il vous reste",
}

local t = T[locale]
if t then for k, v in pairs(t) do rawset(L, k, v) end end
ns.LocaleTables = T -- tests check every translation: real strings, same placeholders
