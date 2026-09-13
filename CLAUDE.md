# Fog of War — projectcontext

Godot 4.7-strategiespel (fog-of-war-bordspel, dierenfacties) met een pure
GDScript-engine (reducer-patroon), AI-agents, een meet-arena en een campagne
in aanbouw. **Lees `MASTERBOUWPLAN.md` (fasering + werkafspraken + besluiten
B1-B17) en `WIP.md` (per-stap-logboek) voor de actuele stand.**

## Kernregels (samenvatting; bron: MASTERBOUWPLAN §0 + besluiten)

- **EEN REGELSET (C17)**: de **campagne** is het spel. Een los 1v1 is dezelfde
  economie maal `potje_factor` (0,35): dezelfde formule, kleinere pot. De
  startreserve is overal `start_poolfactor` x comp + `budget_bonus` per factie,
  net als CRules in de campagne. Trainer, nacht-matrix, ijk-sims en de
  regelzoeker draaien allemaal op `arena/arena_configs/rules_v42_campaign.json`.
  Bouw NOOIT een tweede economie voor het 1v1. **Facties (3 augustus):** het
  `doctrines`-blok in dat bestand is de enige plek waar factie-eigenschappen
  worden bijgesteld zonder `constants.gd` aan te raken. De campagne leest het
  bij de start (`CRules.facties_uit_bestand()`) en **bevriest** het in de save;
  het losse potje leest het uit dezelfde bron. Wie hier iets wijzigt, verandert
  meting én spel tegelijk: dat is een bewuste regelwijziging (goldens +
  `golden_sims.json` regenereren). Lees factie-data NOOIT rechtstreeks uit
  `Constants.doctrine_data()` in speel-code; ga via `rules.doctrine_data()`,
  `c.rules.doctrine_data()` of `Agent.doctrine_data_uit_view()`.
- **De facties zelf (C19, 8 augustus 2026)** — dit is wat er NU gespeeld wordt.
  `constants.gd` draagt nog de kale tabel van juli; die is alleen de terugval:

  | factie | kaarten | budget | leger [inf,cav,art] | perk |
  |---|---|---|---|---|
  | Varken (enum MENS) | 3 | 7 | [11,5,3] | - allrounder |
  | Muis | 5 | 5 | [16,4,0] | +1 Speed op elke pion, loopt door eigen pionnen |
  | Leeuw | 2 | 8 | [12,4,2] | artilleriedracht 7 |
  | Beer | 3 | 7 | [19,3,0] | +1 HP per koppeling, kaart-Speed max 4 |
  | Wolf | 3 | 7 | [11,8,3] | gratis stap na melee, cavalerie +2 Speed en springt over vijanden |
  | Krokodil (enum VOS) | 3 | 6 | [13,5,3] | koppeling geheim tot de eerste schade |

  **Startcompensatie (C11-`budget_bonus`, geen kaartbudget):** Muis +4 punten,
  Beer +3, Wolf +2 punten en 4 CP, **Krokodil +3** (C20, 9 augustus). Die tabel
  staat op DRIE plekken die gelijk moeten blijven — `CRules.budget_bonus`,
  `campaign.budget_bonus` in `rules_v42_campaign.json` en in `v42_default.json`
  — want anders dan het doctrines-blok wordt hij níét uit het regels-bestand
  gelezen. `CampaignTests.test_c19_budget_bonus_overal_gelijk` bewaakt dat.

  Gemeten na C20 op verse seeds (2160 partijen): band **44,7-56,7%, spreiding
  11,9 procentpunt**. Daarvoor 42,4-55,0 / 12,6 over 6480 partijen; in juli 48.
  C20 gaf Krokodil +2,3 en liet de band verder zoals hij was. Beer is nu met
  56,7% de bovenkant.
  (Een eerder gemeld "4,4" kwam uit 1152 partijen met een foutmarge van ±3,6 per
  factie: te klein voor die uitspraak. Vuistregel: onder ~2000 partijen geen
  conclusies over een paar procentpunt.) **Muis en Beer hebben nul artillerie**, en `kent_type()`
  verbiedt ze er dus ook een te spawnen: geen kanon-model, geen gibs, geen
  `cannon_die_<factie>` voor die twee. Controleer de actuele stand altijd met
  `-- facties`, nooit door `constants.gd` te lezen. Welke knop hoeveel doet:
  kaartbudget ~27 procentpunt per punt (gemeten op 2160 partijen: Krokodil
  6 → 7 gaf +26,9), cavalerie ~18 per ruiter, infanterie en
  legergrootte vrijwel niets, artillerie -21 voor een renner en neutraal voor
  een slachter.
- **V0 — GEEN GELIJKSPEL (4.3.0)**: een duel eindigt op de **haven** of op
  **totale eliminatie**. Geen remise, geen tiebreak, geen cycluslimiet. In
  plaats daarvan de **honger**: vanaf `honger_vanaf_cyclus` (10, gelijk in
  campagne en los potje) verliest elke speler bij het begin van een cyclus de
  pion die het verst van zijn doelhaven staat. Om de beurt, met een win-check
  ertussen, wisselend wie begint; gelijke afstand = laagste pion-id; **geen
  C15-buit** (honger is geen kill). Eliminatie kijkt naar INZETBARE reserve
  (spawn-cap op = punten zijn dood kapitaal). Opgeven telt voor de winnaar als
  eliminatie. **De noodstop `max_steps` is een FOUT, geen uitslag**: de runners
  zetten `afgekapt` en gillen, en de arena boekt dat als eigen categorie.
  Bron: `docs/campagne-intrige-voorstel.md` §1b (V0-V19 = voorstellen; alleen V0
  is aangenomen).
- **C15-buit (4.3.4)**: vaandeldrager neerleggen = 2 versterkingspunten,
  tamboer = 4 CP (4.3.4, 8 september; was 2), gekoppeld of niet (sinds
  4.3.2). Sinds 4.3.4 heeft elk leger EEN vaandeldrager en EEN tamboer
  (`vaandels_max`/`tamboers_max` 1; was 2 en 2, Max: "het staat te vol").
  De rol staat op de pion (`Pawn.rol`) en verhuist nooit; je wijst de
  dragers zelf aan in de opstelfase. Knoppen: `buit_vaandel_pt`,
  `buit_tamboer_cp`, `vaandels_max`, `tamboers_max`. **Bots (7 september):** `buit_jacht`/
  `buit_hoede` (drager binnen bereik), `reserve_pt`/`reserve_cp` (wat de
  VEROVERDE buit waard is; zonder die twee was een gewone soldaat naast een
  drager de betere kill, want de jacht-term viel weg met de drager) en
  `drager_front`/`drager_center` (waar de bot zijn eigen dragers zet,
  default achteraan). De trainer telt buit per kant (`MatchRunner.buit`),
  beloont het in de campagne-fitness (`CampagneFitness`, 5% genormeerd op
  de maximale buit) en meldt per generatie pt/CP per potje in het log en in
  `data/matchup_<factie>.txt`. De arena meet `buit_pt`/`buit_cp`/
  `dragers_verloren`. Bot-wijziging = `golden_sims.json` opnieuw ijken en
  de `-- uispel`-digest opnieuw meten; de golden replays blijven staan.
- **C21-aura (4.3.3, dynamisch sinds 4.3.5)**: de tamboer en het vaandel doen
  ook iets voor het EIGEN leger. Wie op het moment van handelen in het blok
  van acht vakken om een levende eigen tamboer staat heeft één extra
  stamina-punt, één keer per cyclus (eerst van de trom betalen, dan eigen
  voorraad; `Pawn.trom_gebruikt` onthoudt het; weg als de trom wegloopt of
  jij eruit stapt vóór je het gebruikte, terug als je erin stapt en het nog
  niet gebruikte); wie in het blok om een eigen vaandel staat slaat en
  schiet +1 zolang hij daar staat. Niet stapelbaar, gekoppeld of niet,
  alleen eigen pionnen. Knoppen `aura_bereik`, `aura_tamboer_stamina`,
  `aura_vaandel_attack` (0 = uit). ELKE stamina-check leest
  `Rules.stamina_beschikbaar` en betaalt via `Rules.besteed_stamina`; lees
  nooit rechtstreeks `remaining_stamina` voor een beslissing. Engine:
  `Rules.aura_bonus`/`Rules.effectieve_attack`/`Rules.trom_bonus`; bots:
  `aura_waarde` (leerbaar). **Op het bord:** elke tegel in de vorm krijgt een
  minimale gloeiende rand in de kleur van het TEAM van de drager
  (`AURA_KLEUR` in game.gd, 8 september: rood = oranjerood voor het vaandel
  en karmijn voor de trom, blauw = hemelsblauw en indigo; vaandel is
  altijd de lichte tint, trom de diepe; vaandel buiten, trom net
  daarbinnen; vijand gedimd), en de stat-blokjes die uit de aura komen
  (stamina boven de kaart, attack boven de kaart) en het rol-icoon onder
  de blokjes krijgen dezelfde teamkleur.
  Expres GEEN vlak (Max: "vreselijk"). Sterkte: knop `aura_gloed` in het
  sfeer-paneel (toets L). Code: `_werk_aura_bij` in game.gd, per frame uit
  de staat, telt mee in `render_digest` (herstelcheck). **Wind (8
  september):** een windrichting per potje, alle vlaggen wapperen die kant
  op, ook die van de vijand (`PawnView.wind_richting`, geloot in
  `game._loot_wind`; online uit het match-id zodat beide stoelen dezelfde
  wind zien; puur visueel, geen staat). Controle: `-- windcheck [factie]`.
- **Regelversies zijn heilig.** 4.1.10-hr = het huidige spel; 4.2.0 = de
  campagne-economie, config-gated door het `campaign`-blok (zonder blok speelt
  álles byte-identiek 4.1.x). Spec: `docs/spelregels-v4.2.md` (Deel A = 4.1,
  Deel B = 4.2 definitief); besluiten D1-D15: `docs/F2.1-beslisagenda.md`;
  wijzigingen: `docs/spelregels-CHANGELOG.md`.
- **Golden replays + golden_sims.json zijn het regressiecontract.** Breekt een
  golden: bewuste regelwijziging (versie-bump + CHANGELOG + regenereren via
  `-- makegoldens`) of formaatwijziging (alleen regenereren, gedocumenteerd).
- **Elke stap eindigt met checks**: testsuite (`res://tests/TestScene.tscn`),
  `-- simcheck`, `-- play`, `-- vosview` (capture.tscn), zonodig `--fuzz` en
  `--bench` (arena.tscn). Dan WIP.md + masterplan-checkbox + commit "Fx.y: ...".
- **GEEN automatische jobs op deze machine** (B13): Max start nachtrun/training
  zelf (paneel of CLI). Geen Taakplanner, geen n8n (B5).
- **Trainingsdata (`data/ai_weights*.json`) apart committen** van code.
- **Bots spelen winst-gericht** (B15): aanvul-spawnen, nooit max; de
  cycluslimiet is vangnet/meetgereedschap, geen doel.
- **Fog voorop** (D12): vijandelijke pool/CP zijn "?" in views; leak-canary's
  bewaken dit (ViewTests/SpawnTests/CpTests + fuzz). Events `cycle_admin`/
  `cp_admin` zijn server/log-only → F4-event-stream moet per speler redigeren.
- **GDScript-edits met `\`-regelvoortzettingen NOOIT via bash-heredocs** —
  python-script via de Write-tool, dan `python script.py` (bekende bug).

## Commando's

- Godot: `$env:GODOT_PATH`, anders
  `C:\Users\maxni\Downloads\Godot_v4.7-stable_win64.exe\Godot_v4.7-stable_win64.exe`
  (console-variant `..._console.exe` voor terminal-output).
- **Paneel** (Max' knoppen, herbouw 28-07 in gewone taal): `"FogOfWar
  Paneel.bat"` → TRAINING-NACHT (pijplijn), Bots laten leren, Bots laten
  spelen (meting), Bekijk het rapport, Map in het spel zetten, Model
  klaarmaken voor retexture, STOP alles. Meet-gereedschap voor
  Claude (fuzz, L1-test, losse L2-matrix, 4.1-training via train_ai.bat)
  draait alleen nog via de CLI.
- **Een levering in het spel zetten** (7 september): `python
  tools/verwerk_levering.py <map> [--droogloop]`, of de paneelknop "Map in het
  spel zetten" (vraagt om een map, toont eerst de droogloop). Voor een map met
  per model een submap die de .blend EN de nieuwe texturen draagt; factie/type/
  archetype komen uit de mapnamen, het TEAM uit het woord red/rood of
  blue/blauw in het pad. Een map met `weapon`/`wapen` in het pad levert de jas
  voor het WAPEN: die gaat als `<wapen-glb>_<team>.png` naast de wapen-glb en
  wordt tegen DIE glb gemeten (die draagt maar een atlas, dus een verkeerde jas
  valt meteen door de mand). Bouwt het model en meet de jas met `uv_check` tegen de
  GEBOUWDE glb: onder de 90% dekking gaat hij er NIET in en zegt het script
  waarom. Een map met alleen texturen mag ook (dan alleen de jas wisselen).
  Normal-maps gaan er nooit in: de engine zet alleen een albedo-override.
  Draait daarna zelf de vaste ronde (`--import`, `_wapencheck.gd`, `zweefcheck`
  per geraakte factie, `tunercheck`) en vat de uitslag samen; `--geen-controles`
  slaat dat over, `--godot <pad>` of `GODOT_PATH` wijst de binary aan. Alleen de
  Model-tuner blijft handwerk.
- **Een hele blend-inbox bouwen** (7 september, alleen CLI -- de paneelknoppen
  zijn er op 7 september weer uit gehaald omdat Max met losse leveringen werkt):
  `python tools/bouw_modellen.py [--droogloop] [--factie <naam>]
  [--model <naam>] [--parallel N]`. Draait
  per .blend in `assets/new 3d models/` de drie Blender-stappen uit
  MODEL-PIPELINE-CHECKLIST sectie C en herkent factie/type/archetype uit de
  (rommelige) bestandsnamen. Draai altijd eerst de droogloop. Wat hij niet
  zeker kan plaatsen bouwt hij NIET. Logs per aanroep in
  `results/modelbouw_<tijd>/`.
- **Welke wapen-route neemt het spel? `-- wapenroute [factie]`** (capture.tscn,
  bouwt PawnViews zoals de Model-tuner). INGEBAKKEN = het geskinde wapen uit de
  .blend blijft staan en beweegt met elke animatie mee, zonder afstelling. PROP
  = het ingebakken wapen wordt verborgen en er hangt een statische glb in de
  hand MET `model_tuning.json` erop; een afstelling van een ouder model zet het
  wapen dan zichtbaar scheef. Draai dit als een wapen er raar bij hangt: het
  zegt of de plaatsing uit de .blend komt of uit de afstelling.
- **Het bord (8 september): low-poly, uit `tools/blender_schaakbord.py`.**
  Board.tscn instantieert `assets/models/board/spelbord/spelbord.glb` (11x11,
  vakken van 1 eenheid, plank 12,1 breed, 196 driehoeken, 100 vertices) op
  (5, 0,05, 5) zonder schaal: bovenkant op `PAWN_Y`, speelveld precies op de
  tegels -0,5..10,5. De textuur zit NIET in de glb maar ernaast als
  `spelbord.png`, via een material_override in Board.tscn: **retexture = dat
  png vervangen** (zelfde UV: platte projectie van boven; zijwand en afronding
  vouwen dezelfde textuur naar binnen, dus geen naad en geen tweede
  materiaal). Het Tripo-bord (`board.glb`, `assets/models/board/board.glb`,
  `board_Image_0.png`) wordt niet meer gebruikt. Opnieuw bouwen: `blender
  --background --python tools/blender_schaakbord.py -- --uit
  assets/models/board/spelbord/spelbord.glb --vakken 11 --seed 11 --oorsprong
  boven` (de 8x8-schaakversie: `--uit
  assets/models/board/schaakbord/schaakbord.glb`, standaardknoppen), daarna
  `--import`. Het script rekent de houttextuur zelf met numpy (geen
  Cycles-bake): donker verstek-frame, ronde hoeken, afgeronde bovenrand, losse
  ingelegde licht/donker-vakken met dunne zwarte lijnen, slijtage. Levert glb
  + png + `bron/<naam>.blend` (bron/ krijgt een `.gdignore`: Godot wil elke
  .blend zelf importeren en breekt zonder Blender-pad de hele import-run) +
  een Eevee-preview in `results/schaakbord/`. Knoppen: `--vakken`, `--vak`,
  `--rand`, `--dikte`, `--hoek`/`--hoeksegmenten`,
  `--afronding`/`--afrondsegmenten`, `--textuur`, `--seed`,
  `--zonder-onderkant`, `--oorsprong boven`, `--textuur-ingebakken` (plaatje
  wel in de glb, bv voor een upload; Godot trekt het er dan als
  `<glb>_<naam>.png` naast, een tweede kopie van 3 MB), `--geen-preview`,
  `--geen-blend`. De png-imports staan op VRAM-compressie + mipmaps
  (`compress/mode=2`), hou dat zo. Bpy-valkuil: na `pixels.foreach_set` NOOIT
  `colorspace_settings` van een gegenereerd plaatje aanraken, dat wist de
  buffer en je bewaart zwart (Blender 5.1.2); het script heeft er een canary
  op. Checks na een bordwijziging: `-- uispel 777` (zobrist ongewijzigd, het
  bord is puur visueel), `-- play` (met venster: `_shot_play.png`),
  `-- tunercheck` (knop bord). **De huidige `spelbord.png` is de
  veld-retexture van 8 september** (AI-plaatje uit Max' prompt, 1024, jpeg
  in `bron/spelbord_veld_origineel.jpeg`): een AI schuift het raster
  makkelijk een paar procent op (toen 11,5 px in x, 29 px in y), dus elke
  nieuwe retexture gaat door `python tools/bord_raster_fix.py <plaatje>
  --uit assets/models/board/spelbord/spelbord.png [--raster <overlay.png>]`:
  meet offset en vakmaat per as via het dambord-contrast, warpt affien op
  het verwachte raster (frame 4,55%, 11 vakken) en weigert boven 2,5 px
  restafwijking; de overlay tekent rood = verwacht, groen = gemeten. Daarna
  `uv_check.py`, `--import`, `-- play`. Het houten bord terug: het
  Blender-script opnieuw draaien.
- **Het diorama om het bord (8 september): `scripts/game/omgeving.gd`.**
  `game._setup_omgeving` bouwt het procedureel onder de kijk-pivot (draait
  met de camera mee, speler 2 ziet hetzelfde kamp vooraan): grondvlak van
  160 eenheden met de naadloze grastegel uit `assets/models/board/omgeving/`
  (`tools/maak_omgeving_texturen.py`, palet uit de bord-retexture) plus een
  grove multiply-laag, een wolkenschaduw-vlak dat met de wind meedrijft, een
  vignet achter de UI, en twaalf klik-props (Hearthstone-idee van Max):
  kampvuur, trommel, ton, hoorn, bijl in een stronk, kogelstapel, tenten met
  lantaarn vooraan; hek met kraai, plas met kikker, wegwijzer en de tent van
  de ander aan de overkant. `game._unhandled_input` vraagt `Omgeving.klik`
  VOOR de beurt-check (klikken mag altijd, ook tijdens het wachten); picking
  via unproject binnen 46 px, geen physics. Geluid per prop: eerst
  `prop_<naam>` (zet `prop_vuur.wav` enz. in sounds/, zie
  SOUND-WISHLIST.md), anders een terugval uit het arsenaal. Knoppen in het
  sfeer-paneel: `omgeving`, `omgeving_licht`, `wolken`, `vignet`, `props`.
  **Let op:** de orthografische camera staat sinds die dag 40 eenheden
  langs zijn kijkrichting naar achteren (near-vlak, anders viel het kamp in
  een zwarte band weg); een orthografisch beeld verandert daar niet van.
  Deeltjes: de maat hoort in de quad, niet in scale_min/max van het
  ParticleProcessMaterial (die kwam niet door). Check: `-- omgevingcheck`
  (lagen, props, klik per prop raak, bordmidden niet raak, bewoners volgen
  de facties, alles behalve de kraai na 5,5 s weer vrij; met venster
  `_shot_omgeving.png`), plus `-- play` voor het beeld.
- **Bewoners: geanimeerde poppetjes in het diorama (8 september, Max: "een
  peasant_mouse die bij hout hakt als je op hem drukt").**
  `scripts/game/bewoner.gd` (`Bewoner`) laadt een glb met clips uit
  `assets/models/bewoners/<naam>/`, schaalt hem op `hoogte` (0,62), zet zijn
  voeten op het gras, laat de idle-clips lopen en speelt bij een klik een
  ACTIE-clip een keer (met geluid uit het manifest). Clipnamen gaan door
  dezelfde vertaling als de pionnen (`PawnView.CLIP_WOORDEN`): idle is idle,
  walk/die/hit/rush/charge doen niet mee, **alles wat het spel niet kent
  (Chopping, Cheer) is een actie**. Het factiewoord in de naam
  (`peasant_mouse`) bepaalt waar hij staat: vooraan bij wie die factie
  speelt, aan de overkant bij de tegenstander, nergens als niemand haar
  speelt; zonder factiewoord altijd. `Omgeving.zet_facties` (uit
  `game._omgeving_facties`, bij `_start_match`, de online reveal en de
  herstart vanaf de staat) bouwt ze opnieuw. Manifest `<naam>.json` (alles
  optioneel: hoogte, draai, plek, kant, idle, acties, geluid, geluid_moment,
  decor zoals stronk/houtstapel/kist/vuurtje, model = een glb elders
  hergebruiken): `assets/models/bewoners/LEESMIJ.md`. Levering:
  `verwerk_levering.py` herkent het woord `bewoners` in het pad en doet dan
  alleen de karakter-export (clips mee, geen musket, geen gibs, geen jassen)
  naar `assets/models/bewoners/<naam>/<naam>.glb`, gevolgd door
  `-- bewonercheck <naam>` (laadt, sorteert clips, speelt een actie, moet
  weer in idle komen). Voorbeeld zonder eigen model:
  `bewoners/soldaat_mouse/soldaat_mouse.json` hergebruikt de
  muis-infanterist (acties melee en ready) bij een houtstapel.
- **Props per team en de prop-tracker (8 september, Max: "rood armoede en
  blauw pompeus en rijk, een stuk of 100").** `PROP-WISHLIST.md` is de lijst
  (tien scenes, ruim honderd props en poppetjes, met per prop team, klik,
  status en een text-to-3D-prompt); `python tools/bouw_prop_tracker.py`
  bouwt `prop-tracker.html` uit die lijst plus de mappen `props/` en
  `bewoners/` (paneelknop "Welke props ontbreken?"): ✓ ligt er, ½ een deel,
  ⚙ placeholder uit primitieven, ➕ nog maken. Bestanden:
  `assets/models/props/prop_<naam>.glb` (gedeeld) en `prop_<naam>_red.glb` /
  `_blue.glb` (arm / rijk); een prop die maar voor een team bestaat lever je
  MET het teamwoord. In het spel: stoel 1 is rood, stoel 2 blauw
  (`game._omgeving_facties` geeft het team mee aan `Omgeving.zet_facties`,
  die dan alles onder Props herbouwt); `Omgeving._glb_prop` vervangt de
  primitieven van tent, hakblok, kogels, wegwijzer, hek en plas door een
  geleverde glb (op ware hoogte via `PROP_HOOGTE` of `prop_<naam>.json`) en
  `EXTRA_PROPS` zet dertig wishlist-props op een vaste plek zodra hun glb er
  ligt (fakkel, wagen, kookpot, musketrek, kanon, boom, troon, ...). Een
  bewoner met teamwoord (`peasant_mouse_red`) staat alleen in het kamp van
  die kleur. De tweens van alle reacties hangen aan hun prop-node, zodat een
  herbouw ze netjes meeneemt. **Budget (12 september):** klein 300-800
  driehoeken, middel 800-1.500, groot decor tot 3.000, een diorama onder de
  30.000 en 15-25 props; een mesh en een materiaal per prop (draw calls
  tellen op een telefoon zwaarder dan vertices); Tripo-uitvoer door
  `tools/blender_decimate.py --doel 1200`. `-- dioramashots` meldt per
  diorama meshes en driehoeken (nu 70-106 meshes, 4.700-9.500 driehoeken
  uit primitieven; een infanterist is er 2.231). Tabel:
  `assets/models/props/LEESMIJ.md`. **Een Tripo-glb erin zetten (12
  september, de eerste: de rode tent):** `python tools/verwerk_prop.py
  <tripo.glb> tent --team red --draai 90`. Meet de glb, decimeert boven
  `--doel` (1500), slankt de texturen af naar 1024 (kleur en ruwheid
  JPEG, normaal PNG; 9 MB wordt ruim 1 MB), bakt `--draai` in (voorkant
  naar +Z = naar de speler; aflezen van de plaat van
  `tools/blender_prop_preview.py`, vier hoeken naast elkaar), schrijft
  `prop_<naam>[_team].glb`, importeert, zet de `.import` van de
  uitgepakte texturen (`_kleur.jpg`, `_normaal.png`, `_ruwheid.jpg`, mee
  committen) op VRAM-compressie + mipmaps en eindigt met
  `-- omgevingcheck`, die de prop onder "geleverde glb-props" moet
  noemen. `_glb_prop` geeft sinds die dag de wortel terug en neemt eigen
  reacties aan: de geleverde tent houdt lantaarn, Zzz en laars.
- **Twaalf diorama's en willekeurige reacties (11 september, Max: "bedenk
  iets van 12 diorama's... per klikbaar element verschillende dingen die je
  random krijgt te zien").** `Omgeving.DIORAMAS` is de bron: per diorama
  grond (`gras`, of `grond_<variant>.png` uit `assets/models/board/omgeving/`
  voor sneeuw, zand, modder, kei, bos, rots; `tools/maak_omgeving_texturen.py
  --varianten`), een tint, extra's (`sneeuw` = vallende sneeuw, `water` =
  een rivier met kade aan de overkant) en de props als `[naam, x, z, draai,
  {opties}]` voor het kamp en de overkant (`_plaats` kent ze). Geloot per
  potje in `game._loot_wind` (online uit het match-id), knop `diorama` in
  het sfeer-paneel (1-12) zet er een vast; `zet_diorama(i)` herbouwt alles
  onder Props. De twaalf: Weidekamp, Boerenerf, Dorpsrand met molen, Na de
  slag, Winterkamp, Rivierhaven, Bosrand, Kapelruine, Marktplein, Egypte
  1798, Alpenpas, Hoeve van Waterloo (tabel in PROP-WISHLIST.md sectie 11).
  Nieuwe placeholder-props: toilethuisje met hartje in de deur, molen
  (wieken draaien in `_process`), kanon, put, kruis met hoed, palm,
  piramide, sfinx, steiger met sloep, ruine, fontein, marktkraam (zeil in
  teamkleur), sneeuwpop, hooiberg, lantaarnpaal, boom (ook kaal), rots
  (decor). **Reacties:** `_registreer` neemt een Array van Callables, een
  klik kiest er willekeurig een (`_speel_willekeurig`, nooit twee keer
  achter elkaar dezelfde); elke prop heeft er drie (tabel in PROP-WISHLIST
  sectie 11). Gereedschap: `_fx_tekst` (Label3D-wolkje), `_fx_hart`,
  `_fx_veren`, `_fx_wolk`, `_fx_spetters`, `_fx_knal`, `_boog` (boogje voor
  tween_method via bind), `_maak_vogel`/`_vlieg`/`_land_vogel`,
  `_maak_kip`/`_ren_weg`. **Tik (11 september, Max: "minimaal 3 dingen die
  lekker dingen of pingen, zo vaak je klikt"):** `klik` roept ALTIJD eerst
  `_tik` (geluid uit `TIK_GELUID` op de naam van de prop-node, oplopende
  toon bij snel doorklikken via `combo`, stuiter op de root-scale, plus een
  `tik_extra` per prop: bel zwaait, flessen wiebelen, hamer slaat, deksel
  wipt, deur rammelt, vuur schrikt), ook als de grote reactie nog loopt.
  `TIK_NAMEN` zijn de dingers; `Omgeving.dinger_aantal(i)` telt ze per
  diorama en elk heeft er minstens drie. Nieuwe pure dingers: bel, glaswerk,
  aambeeld, kookpot. **Eigen geluid per prop (Max: "iedere prop z'n eigen
  geluidjes met variatie"):** 39 categorieen in `sounds/props/`, 95
  bestanden, gesynthetiseerd door `tools/maak_prop_geluiden.py` (FM-bel,
  glasklink, aambeeld-partialen, trommel, kraai, kikker, klop, plons,
  geritsel, ...; 2-3 varianten per categorie); een echte opname op dezelfde
  naam (`prop_bel.wav`, `prop_bel_2.wav`) wint. Combo: binnen `tik_pauze`
  (knop, 0,6 s) dezelfde variant met oplopende toon (`tik_toon`, 0,07 per
  klik, max 10); na een pauze herstart de ladder met een ANDERE variant
  (`_tik_geluid_prop`); elke vijfde klik een chime (`prop_combo`) met
  "x5!". Klikpunt en straal komen uit de omhullende doos van de prop
  (`midden`/`omvang` in `_registreer`), dus ook een brede ruine of steiger
  is op zijn midden raak; hek, plas en rotsen zijn ook klikbaar. Alles zit
  in `sounds/props/`, dus `sounds/LEESMIJ.md` en de geluid-tracker kennen ze. Check: `-- omgevingcheck [nr]` bouwt alle twaalf (elk
  minstens 8 props en 3 dingers), eindigt op nr, klikt elke prop, speelt
  daarna elke reactie van elke prop een keer, en klikt zes keer snel op de
  eerste prop (alle zes raak, combo minstens 4); script-fouten vangt de grep
  op `SCRIPT ERROR`.
- **Vijf mini-games in het diorama (12 september, Max: "bedenk 5
  spelletjes... heel low key, een tap of een klik inhouden"):**
  `scripts/game/spelletjes.gd` (`Spelletjes`, aangemaakt in
  `Omgeving._init`). Twee bedieningen op een vinger: WERPEN (vinger op de
  spel-prop, METEEN zwaait een pijl op de grond heen en weer = richting en
  groeit hij = kracht (sinds 12 september, Max: "de pijl moet meteen
  komen"; de pijl wijst sindsdien ook de kant op die de bal gaat, de draai
  om +Y stond andersom), loslaten werpt, binnen `HOLD_DREMPEL` 0,22 s is
  het een gewone tik (alleen de cadans wacht op de drempel); wegschuiven
  breekt af) en OP DE MAAT (tikken op het moment). Kegelen (`kegelspel` in
  de DIORAMAS: tien lege flessen uit de kantine in de bowling-driehoek,
  klein en zonder vlak eronder, omgerold met een kanonskogel, Max: "iets
  wat bij de setting hoort", "10 stuks"; ketting van omvallers, "Strike!"), keilen (`{"stenen": true}` op een `plas_kikker`, of `stenen` op
  de kade van de Rivierhaven: steeds kortere hupjes met een oplopende
  plons, buiten het water is het klaar, de kikker duikt; op ijs glijdt de
  steen), kanon (`kruitvaten` in het diorama: het kanon draait er bij de
  bouw naartoe, vasthouden brengt de loop omhoog en zet een doelring op de
  dracht 1,6-7,0, de wind van het potje duwt de kogel opzij: "Windje!";
  vier vaten in een kettingreactie), vissen (`hengel` op de kade of
  `{"hengel": true}` op een plas: vasthouden werpt de dobber uit, tik als
  hij duikt: snoek, laars, musket of kist blijven op de kant liggen) en de
  tamboer-cadans (`{"cadans": true}` op een `trommel`: vasthouden telt vier
  slagen af, dan acht keer op de maat tikken, drie soldaatjes marcheren op
  de plaats, "Perfect!" versnelt het tempo). Een korte tik op een spel-prop
  blijft een gewone tik (ding + reactie bij het loslaten); game.gd geeft
  daarvoor het loslaten (`Omgeving.laat_los`) en de beweging
  (`Omgeving.beweeg`) door. Puur visueel: eigen RNG, tweens aan de
  prop-node, geen spelstaat. Geluiden `prop_kegel`, `prop_kegel_rol`,
  `prop_kruitvat`, `prop_hengel`, `prop_vis` (synthetisch, in de
  geluid-tracker). Check: `-- spelcheck` (elk spel: vasthouden, richten
  vastzetten via `Spelletjes.zet_richt`, loslaten, score; met venster
  `_shot_spel_richt.png`); `omgevingcheck` klikt sinds die dag met drukken
  EN loslaten. Tripo-props ervoor: PROP-WISHLIST sectie 13.
- **Koppel-fase: je kaartkeuze blijft staan** (12 september, Max: "houd
  mijn kaart geselecteerd ook al is de AI eerst aan de beurt, totdat ik
  gelinkt heb"). Een kaart kiezen mag de hele koppel-fase, ook in de
  beurt van de bot of de online tegenstander; een pion-klik in zijn beurt
  doet niets en laat de keuze staan; `_begin_human_linking` zet de keuze
  bij de beurtwissel terug in de waaier (`CardHand.selecteer`). Weg gaat
  hij pas als de kaart aan een pion hangt of de fase voorbij is. Check:
  `-- koppelcheck`.
- **Cape voor het blauwe team (12 september, Max: "alle blauwe team
  karakters een blauwe cape, vanuit Godot").** Geen Blender:
  `PawnView.maak_cape(root, hoogte, blauw, fase)` hangt een lap (PlaneMesh)
  aan `mixamorig:Spine2` (terugval Spine1/Neck/Spine) via een
  BoneAttachment3D. De KRAAG zit aan het bot; de LAP hangt sinds 13
  september per frame aan de zwaartekracht (`cape_process`: omlaag vanaf
  de kraag, een gedempte slinger die tegen de beweging in sleept en met de
  wind meegaat, nooit door de rug; Max: "kan ie niet meer hangen echt"),
  dus hij kantelt niet stijf mee met een leunend rugbot. Een
  vertex-shader (`CAPE_SHADER`) vormt de
  lap (smalle kraag bij de nek die over de schouders naar volle breedte
  loopt, plooien vanuit de kraag die naar de zoom dieper worden, zijkanten
  om de schouders gewikkeld, echte normalen op de plooien; Max: "meer
  drape, de punten naar de nek toe"), laat de zoom wapperen, flared hem
  uit en neemt de wind mee (`cape_wind` per frame uit `wind_richting`,
  nooit door de rug naar voren). Een geleverd plaatje `cape_blue.png` /
  `cape_red.png` onder assets/models (aanrader props/) wordt de buitenkant
  (boven = kraag, rand rondom, de lap neemt de verhouding van het plaatje
  over, 3:4 ligt het dichtst bij; layout en drie prompts in
  `assets/models/props/LEESMIJ.md` en in de prop-tracker, PROP-WISHLIST
  sectie 14: png-rijen, prompts zonder sjabloon, variant-rijen). Blauw: koningsblauw
  met goudgalon en lichte voering; rood (knop `cape_rood`, standaard uit)
  dof donkerrood zonder galon. `_hang_cape` loopt na elke modelwissel
  (`_apply_team_texture`), niet op artillerie; `zet_team()` wisselt jas en
  cape samen; de bewoners van het blauwe kamp krijgen dezelfde lap
  (`Bewoner.zet_cape`, gezet door `Omgeving._bouw_bewoners`). Knoppen in
  het sfeer-paneel (live, ook op de bewoners): `cape_blauw`, `cape_rood`,
  `cape_lengte`/`cape_breedte` (x pionhoogte), `cape_wapper`, `cape_wind`,
  `cape_drape` (plooien en wikkel), `cape_slinger` (hoe ver hij sleept).
  Eigen shaders (cape en vlaggendoek) dragen een `dim`-uniform dat
  `verduister_later` tweent, zodat een lijk met cape ook donker wordt.
  Check: `-- capecheck` (rood geen cape, blauw een, achter de rug aan een
  rugbot; teamwissel, modelwissel, knop cape_rood, bewoner; met venster
  `_shot_capecheck.png` van schuin achter). Puur visueel: uispel en
  herstelcheck ongewijzigd.
- **Past deze teamjas op dit model?** `python tools/uv_check.py <model>.glb
  <png's...>` -- leest de UV's uit de glb, tekent ze als driehoeken en meet
  hoeveel van dat gebied in de png beschilderd is. Passend = boven de 95%, een
  jas van een ander model rond de 70%. Per materiaal, want lijf en ingebakken
  wapen hebben elk hun eigen atlas -- en sinds 7 september draagt het wapen ook
  een eigen teamjas (`<wapen>_red.png` / `_blue.png` naast de wapen-glb), zodat
  elke factie zijn eigen musket-stijl heeft; ontbreekt die, dan houdt het wapen
  de atlas uit zijn glb. Een nieuwe jas laten maken:
  `python tools/maak_retexture.py <map>`, of de paneelknop "Model klaarmaken
  voor retexture" (die vraagt om een map). Levert per .blend TWEE bestanden
  NAAST die .blend: `<naam>.glb` (het kale lijf in rusthouding, geen skelet,
  animaties of wapen) en `<naam>_wapen.glb` (alleen het wapen, statisch). Zo
  staat alles van een model bij elkaar: blend, uploads en de png's die
  terugkomen. Met `--uit <map>` schrijf je ze ergens anders heen.
  Lijf en wapen dragen elk hun eigen UV-atlas, dus je kunt ze los laten
  hertexturen; `--geen-wapen` slaat het tweede bestand over. Dat upload je, en je vraagt de dienst UITDRUKKELIJK de
  UV's te laten staan. Per stuk:
  `blender --background <model>.blend --python tools/blender_export_retexture.py
  -- --uit <naam>.glb` (vlaggen `--los`, `--met-wapen`).
- **Factiezoeker** (1 augustus): `python tools/balans/factiezoeker.py --minuten
  120 --potjes 2 [--facties 2,3]`, of de paneelknop "Facties uitproberen
  (balans)". Zoekt aan kaartbudget, kaarten per ronde, legersamenstelling en de
  perks, met een **identiteits-rem**: elke afwijking van het huidige ontwerp
  kost punten, anders eindig je met zes klonen. Zijn voorstel is een regels-json
  met een `doctrines`-blok: dat kun je direct aan de trainer of de arena
  meegeven zonder `constants.gd` aan te raken. **Gericht op een factie (11
  september):** `--facties 3 --achtergrond results/nacht_<stempel>_v42_matrix_l2/games.jsonl`
  speelt alleen de 11 paren met die factie en haalt de rest uit de
  nachtmatrix (ruim drie keer sneller; een 4.3.5-partij duurt bijna een
  minuut, dus reken op een half uur per generatie met `--potjes 3 --procs
  5`). Sinds die dag blijft het aangenomen blok van de kampioen in elke
  kandidaat staan (daarvoor viel een "ongewijzigde" factie stilletjes
  terug op de kale tabel uit constants.gd), worden kandidaten ontdubbeld
  en kent de comp een ruilzet (pion van type naar type, totaal gelijk).
  Zijn knoppen zijn grof (kaartbudget ~25 pp per punt); de fijne knop
  `budget_bonus` (startpunten, C11) zit NIET in zijn zoekruimte.
- **Regelzoeker** (31 juli): `python tools/balans/regelzoeker.py --minuten 60
  --potjes 2 --kandidaten 6`, of de paneelknop "Regels uitproberen (balans)".
  Zoekt betere REGELS met vaste bots (de trainer zoekt betere bots met vaste
  regels). Scoort op factie-evenwicht 45%, beslissende partijen 25%, speelduur
  15%, levende economie 15%. Raakt het spel niet aan: schrijft `voorstel.json`
  + een log per kandidaat in `results/balans_<tijd>/`.
- Nachtrun: `.\arena_nacht.ps1 [-DuurMinuten] [-Kort]` — draait de
  **campagne-matrix** (`v42_matrix_l2.json`). De 4.1-helft is er op 8 augustus
  uit gegaan: die mat een economie en facties die niemand speelt. B17's
  om-en-om-lus staat er nog voor als je meerdere programma's wilt.
- **Alles meet het echte spel (8 augustus).** `arena/run.gd` legt het aangenomen
  `doctrines`-blok over elk regels-bestand dat er zelf geen draagt, net als
  `game.gd` voor een los potje; de run-metadata schrijft `facties_bron` + het
  blok op. Sinds 8 september geldt dat ook voor de fysieke pionregels
  `basis_hp` (C12) en `stat_minimum` (C22): draagt een regels-bestand ze
  niet, dan komen ze uit `rules_v42_campaign.json` en staan ze in de
  run-metadata. Ook de **fuzz** draait op `rules_v42_campaign.json`, dus mét
  campagne-economie en de echte facties. Wil je expres de kale tabel meten:
  `"facties_uit_bestand": false` in de config (zet ook de overlay van
  `basis_hp`/`stat_minimum` uit). De factiezoeker en de regelzoeker
  starten van `rules_v42_campaign.json` en erven dus alles; de oude
  dashboard-trainer (`Trainer.tscn`, `-- trainer`) speelt sinds 8 september
  ook die regels in plaats van kaal 4.1.
- Arena: `.\arena.ps1 -Config arena/arena_configs/<x>.json -Procs N -Naam run`
  (machine heeft 32 threads). Dashboard: `python tools/dashboard/build_dashboard.py`
  → `results/dashboard.html`; vergelijken: `python tools/dashboard/compare_runs.py A B`.
- Training: `train_ai.bat [min]` (6 facties, sinds 8 augustus op
  `rules_v42_campaign.json`, dus de echte regels) of per factie:
  `<godot> --headless --path . res://tools/capture.tscn -- train <min> 6 6 <factie> <seed> arena/arena_configs/rules_v42_campaign.json`
  (trainer heeft een relatieve adoptie-gate + convergentiecheck; onder
  v4.2-regels traint hij op campagne-fitness: haven 3 > eliminatie 2 >
  tiebreak 1 > verlies 0 + spaarbonus restleger/CP — één generatie duurt
  met cycle_limit 20 zo'n 10-15 min per factie).
- **Client-regressie (F4.3):** `-- uispel [seed]` speelt een volledige partij
  vs-AI waarin de mens via het timeout-pad van game.gd speelt en print de
  eind-zobrist; seed 777 moet `d16a14f8…` geven (246 acties, cyclus 6, sinds
  11 september: de omgeving en de bewoners hebben een EIGEN
  RandomNumberGenerator; de oude referentie `d9985647…` (272, 7, onder
  4.3.5) bevatte stiekem het aantal trekjes dat het diorama bij de herbouw
  uit de globale RNG deed, tussen `seed(777)` en de auto-opstelling van de
  mens, die wel de globale RNG gebruikt: elke visuele verandering verschoof
  daardoor de hele partij. **Visuele code trekt NOOIT uit de globale RNG**
  (`randf`, `randi`, `randf_range` zonder eigen RNG-instantie), anders is
  uispel weer een lot). Was `718992dc…` (238, 6) onder 4.3.4, `c5db0ff3…` (243, 6) onder
  4.3.3, `8d6aafaa…` (231, 5) onder 4.3.2 en `890b6cb4…` (270, 6) tot 4.3.1:
  elke regelwijziging rekent anders, en dat werkt door in het hele potje. Elke F4.3-stap: uispel gelijk, én `-- record
  user://ref_na.json easy easy muis wolf 777` gevolgd door `python
  tools/vergelijk_opname.py` (vergelijkt eind-zobrist, eindstaat en elke
  entry; een byte-`fc` is nooit leeg door `meta.created` en `ts`). Sinds
  F4.3c ook `-- naadcheck` (game.gd zonder bot: dient nooit iets namens
  speler 2 in, wacht in elke commit-fase, geen lokale timer zonder klok) en
  sinds F4.3e `-- herstelcheck [seed] [factie]` (elk moment van een partij
  een verse scene op alleen de fog-view starten en het scherm vergelijken;
  777 en `4242 wolf` moeten 0 verschillen geven), en sinds F4.3g
  `-- play online [2]`, `-- vosview online [2]` en `-- resumecheck [seed]
  [seat]` (dezelfde koude herstart, maar op de online-weg: RemoteSession op
  een loopback met bot; `777 1` en `4242 2` moeten 0 verschillen geven over
  alle veertien fasen), sinds F4.3h `-- nettest [url]` (tegen een draaiende
  dev-server: 13 stappen PASS) en sinds F4.3i `-- lobbycheck [url]` (de
  echte lobby-code van game.gd tegen de dev-server: 10 stappen PASS). Het
  bouwplan met de vaste regressieset staat in `docs/F4.3-bouwplan.md`.
- **Online hosten (F4.4a):** `tools/deploy/README.md`. Pakket + bewijs:
  `.\tools\deploy\bouw_serverpakket.ps1 -Proef` (0,3 MB engine-subset,
  zelfde core-hash als het volle project); uitrol:
  `.\tools\deploy\deploy-server.ps1 -Droplet <domein> -Nettest`. De
  server bouwt met `npm run build` naar `dist/`; env in `server/.env.voorbeeld`.
  Engine gewijzigd = server uitrollen én een nieuwe client-build.
- Choreografie meten: `-- meleecheck` (bajonetstoot in het echte spel: speelt
  er een melee-clip, blijft de aanvaller op zijn eigen vak staan, en steekt hij
  pas over als de dood-animatie klaar is? PASS/FAIL + de gemeten seconden).
- Facties bekijken: `-- facties` (welke factie-instellingen gelden er NU: de
  kale tabel uit `constants.gd` naast de actieve waarden met het
  `doctrines`-blok eroverheen, plus de startvoorraad die een campagne daarmee
  boekt, en een proefcampagne die bewijst dat grootboek en duelregels hetzelfde
  leger gebruiken). Draai dit vóór en ná het aannemen van een voorstel.
- Geluid per factie: `python tools/bouw_geluid_tracker.py` bouwt
  `sound-tracker.html` (paneelknop "Welke geluiden ontbreken?"). Leest de
  `sounds/`-mappen en SOUND-WISHLIST.md, dus hij kan niet verouderen: per factie
  zie je wat er ligt, wat mist, en de ElevenLabs-prompt om te kopieren. Een
  factie telt als gedekt zodra alle vijf de archetype-varianten er zijn (dan
  wordt de factie-categorie nooit bereikt). **Sinds 12 september ook de
  diorama-props**: een sectie met de 40 `prop_*`/`bewoner_*`-categorieen uit
  SOUND-WISHLIST sectie 11, per stuk echt opgenomen / nog synthetisch / leeg
  (synthetisch herkent hij aan `sounds/props/synthetisch.json`, het manifest
  met sha1's dat `tools/maak_prop_geluiden.py` schrijft; een echte opname op
  dezelfde naam heeft een andere hash) en een Engelse ElevenLabs-prompt
  (`PROP_PROMPT_EN` in het script).
- **UI-assetpack nakijken: `-- uicheck`** (statusbord van de UI-assets onder
  `assets/ui/`: elk icoon-id uit `docs/design/UI-SPEC-EN.md` met zijn bestand,
  de zes emblemen, de kaartdelen, elke knop- en paneelstijl met 9-patch-marge,
  de fonts per rol (bedoeld of terugval), en of het thema en de widgets
  bouwen; exit 1 als er iets ontbreekt). Alles wat een scherm nodig heeft komt
  uit `scripts/ui/ui_assets.gd` (`UiAssets`); de autoload `UiThema` legt het
  thema over het hele spel en schermen kiezen vormen met
  `theme_type_variation` (lijst bij THEMA-VARIANTEN in dat bestand). Nieuwe
  png's onder `assets/ui/` eerst `--import`-en. Zie `assets/ui/LEESMIJ.md`.
- **Zwevende wapens/props: `-- zweefcheck [factie] [cyclus]`** (capture.tscn, na de
  opstelling: elke zichtbare mesh die meer dan 2 eenheden van zijn eigen pion
  staat, met naam en ouderketen; PASS/FAIL). Met een cyclus-getal (bv `muis
  2`, 8 september) speelt hij door tot die cyclus, dus voorbij de reset
  waarin iedereen ontkoppelt en van vecht- naar basismodel terugwisselt, en
  print per pion de afstand hand-tot-wapen (`PawnView.wapen_hand_afstand`:
  prop of ingebakken, met team, rol en modelwissels; boven 0,25 = verdacht,
  de vaandelstok zit door zijn lengte op 0,35), met venster ook
  `_shot_zweefcheck.png`. Gibs tellen niet mee. Zo kwam de "zwevende musket
  bij blauw" boven water: de figuranten sapper/canteen/drummajor heten
  anders dan hun props (prop_axe/prop_barrel/prop_mace) en kregen daardoor
  een onafgestelde losse musket; nu `PawnView.PROP_ALIAS` plus de vangrail
  dat een rol zonder prop zijn ingebakken musket houdt. **Sinds 12
  september dragen ALLEEN de vaandeldrager en de tamboer een prop**
  (`PawnView.ROL_DICHTHEID` 0; Max: "sommige hebben nu wel een prop vast
  anders dan de vlag of trom, dat niet doen graag"); hoorn, bijl, vat en
  staf bestaan alleen nog in de Model-tuner (rol_override) en als
  diorama-prop. **En een dode drager komt niet terug** (12 september,
  Max: "als ze dood zijn zijn ze dood"): de oude cosmetische verdeling
  van vaandel en trom (`game._werk_figurant_rollen_bij`, 30 juli) is
  uit zodra het potje echte rollen draagt (campagne-blok, dus altijd);
  daarvoor sprong hij pas bij als er geen LEVENDE drager meer was, en
  dan kreeg een verse spawn een trom of vlag. Check: `-- dragercheck`. Bot-geparente wapens uit Blender
  5.1 zweefden meters naast de hand door een export- en importbug; de
  pijplijn corrigeert dat (`tools/blender_botkind_fix.py`, zie
  MODEL-PIPELINE-CHECKLIST sectie C). Draai dit na elke her-export.
- **Wapperen de vlaggen met de wind mee? `-- windcheck [factie]`** (capture.tscn:
  opstelling met beide kanten dezelfde factie, default muis; zet de wind op
  drie richtingen en meet per vlagdoek of zijn vrije zijde in wereldruimte met
  de wind mee wijst, voor rood en blauw; PASS/FAIL, met venster ook
  `_shot_windcheck.png`). Een factie zonder model met vlag-prop geeft FAIL
  "geen vlag gevonden".
- **Geluidsinstellingen nakijken: `-- audiopaneel`** (capture.tscn: bouwt het
  paneel Instellingen > Geluid, zet elke schuif, bewijst dat `Audio.zet_volume`
  meteen op de muzieklaag landt en dat het in een cfg wordt bewaard; schrijft
  naar `settings_check.cfg`, niet naar die van de speler; met venster ook
  `_shot_audiopaneel.png`). De vier volumes (alles, muziek, effecten,
  omgeving) wonen in de autoload `Audio` (`vol_*`, `zet_volume`, `volume`)
  en in `user://settings.cfg` onder `[audio]`, naast de taal. Toets M dempt
  daarnaast alles tijdelijk.
- Model-tuner nakijken: `-- tunercheck` (welk model het spel per factie en
  archetype vindt, welke modellen nog GEEN gibs hebben, of de tuner-scene
  opbouwt, en of de afstelling een rondje opslaan-en-teruglezen byte-identiek
  overleeft). Draai dit na elke map- of modelwijziging; het is meteen het
  statusbord van "wat is er al geleverd". Sinds 7 september controleert hij ook
  de UI: paneelhoogte en sleepgreep, of elke tab kan scrollen, en hij DRUKT de
  knoppen in -- "alle modellen" moet 90 pionnen zetten (6 facties x 3 types x
  5 archetypen), "alles rood" moet ze alle 90 rood maken, en "bord" moet
  Board.tscn laden met zijn eigen camera UIT.
- **Model-tuner, wat je ermee kunt** (hoofdmenu): losse model + referentiestuk,
  `formatie` (twee facties tegenover elkaar), `alle modellen` (negentig pionnen:
  rijen zijn de zes facties, kolommen zijn infanterie, cavalerie en artillerie
  met elk base/spd/hp/atk/mix, met een gaatje tussen de type-groepen; hiermee
  beoordeel je de SCHAAL tussen facties en tussen types), `Team` (rood vs blauw, alles rood, alles blauw)
  en `bord` (het echte Board.tscn eronder met zijn textures en licht, zodat je
  ziet wat de speler ziet). Het onderste paneel is sleepbaar aan de greep
  bovenin; de hoogte wordt onthouden in `user://tuner_ui.cfg`.
- Worden lijken en gibs donker? `-- debrischeck [factie]` (bouwt een pion, maakt
  hem debris, wacht de ingestelde tijd uit en vergelijkt de albedo voor en na;
  controleert ook dat een LEVENDE pion met hetzelfde model NIET meeverkleurt --
  de klassieke fout is het gedeelde glb-materiaal aanraken in plaats van een
  per-instantie kopie). Knoppen in `effects_tuning.json` / Model-tuner tab Gore:
  `debris_donker_na`, `debris_donker_duur`, `debris_donker`.
- Kijken zonder te spelen: `-- cliplengtes` (elke animatie met lengte EN de
  naam die het spel ervan maakt) en `-- geluidcheck` (elke geluidscategorie met
  aantal varianten, mix-dB, tuner-dB en vertraging; meldt categorieen zonder
  geluid of die niemand afspeelt). Beide via `res://tools/capture.tscn`.
- Fuzz: `<godot> --headless --path . res://arena/arena.tscn -- --fuzz [games] [seed]`
  (`--fuzz-selftest` = test-de-tester).
- **UI-teksten wijzigen**: de strings staan in `i18n/strings.csv` (+ de
  losse fragmenten), maar het spel leest de GECOMPILEERDE
  `i18n/strings.{nl,en}.translation`, en een gewone headless run bouwt die
  **niet** opnieuw. Na elke csv-wijziging dus `<godot> --headless --path .
  --import` draaien en de twee `.translation`-bestanden meecommitten, anders
  verandert er niets aan wat de speler ziet.

## Mappen (30 juli)

`assets/ui/{buttons,cards,emblems,icons,fonts,texture}/` (de UI-assetpack, zie
`assets/ui/LEESMIJ.md`), `assets/models/<factie>/{infantry,weapons,source-textures}/` en
`sounds/{firing,impact,death,falling,movement,selection,cards,game,ui,factions/<factie>}/`.
Het spel zoekt assets op **bestandsnaam** via `scripts/core/bestandsindex.gd`,
niet op pad: submappen bijmaken of dingen verschuiven mag. Teamkleur-png's
moeten wel naast hun glb blijven (die gaan op modelnaam). Afstel-sleutels in
`model_tuning.json` zijn map-onafhankelijk (`<factie>/<bestandsnaam>`). Zie
`assets/models/LEESMIJ.md` en `sounds/LEESMIJ.md`.

## Architectuur in één alinea

`core/match/` = de pure engine: `reducer.gd` (apply → {ok, events, error}),
`validator.gd` (is_legal/gate_check/legal_actions), `actions.gd` (actietaal
incl. SPAWN/BET_CP/CANNON_ACT), `view.gd` (per-speler fog-views),
`serializer.gd`/`zobrist.gd`/`match_log.gd` (replays), `rules_config.gd`
(alle knoppen incl. campaign-blok). `scripts/core/GameState.gd` draagt de
staat (incl. pools/cp), `GameSession.gd` is de signal-shim voor de UI
(game.gd, 2441-regel monoliet). `agents/` = L0-L3 op views;
`arena/` = runner/metrics/fuzz; `tools/capture.gd` = CLI-modes + trainer.

## Waar we zijn (8 augustus 2026)

**F0 + F1 + F2 + F3 af.** Het spel is speelbaar van begin tot kampioen:
CampaignCore (ledger, CReducer, CView, CLog), SoloDriver + 8 persoonlijkheden,
CampagneHub-UI, append-only jsonl-autosave in `user://campaigns/solo/`
(hervatten = fold), het mens-duel op het echte bord via autoload
`CampaignBridge`, plus grootboek-scherm, BracketView en MatchReport-detail.
Daarna komt F4 (online).

Sinds eind juli is de aandacht verschoven van bouwen naar **kloppend krijgen**,
en dat is nu op vier punten gebeurd:

- **C17 — EEN REGELSET (31 juli).** De campagne is het spel; een los 1v1 is
  dezelfde formule maal `potje_factor` (0,35). Er staat nergens nog een tweede
  economie. 1v1-instelling: cp_start 10, poolfactor 1,5, spawn_totaal_max 15.
- **V0 — geen gelijkspel meer (3 augustus, 4.3.0).** Een duel eindigt op de
  haven of op eliminatie. Vanaf cyclus 10 knaagt de honger: elke speler verliest
  bij het begin van een cyclus zijn achterste pion. Geen remise, geen
  cycluslimiet, geen tiebreak.
- **C22 (4.3.5, 8 september)**: de ruiter heeft na kaart en bonussen minstens
  2 stamina en 2 attack (`stat_minimum`, naast `basis_hp` uit C12; staat in
  `rules_v42_campaign.json`, `v42_default.json` en `duel_rules_voor`).
  Gelezen als ondergrens, niet als +2; één knop als Max iets anders bedoelt.
- **C15-buit (4.3.4).** Vaandeldrager neerleggen levert 2 versterkingspunten op,
  tamboer 4 CP, gekoppeld of niet; een van elk per leger. Sinds 7 september
  jagen de bots er ook op en telt de trainer het mee.
- **C21-aura (4.3.3, 7 september).** Tamboer = +1 stamina bij het koppelen voor
  wie in de acht vakken om hem heen staat; vaandel = +1 attack zolang je erin
  staat. Op het bord: gloeiende tegelrand en gekleurde randjes om de extra
  stat-blokjes.
- **C19 — de facties staan (8 augustus).** Zie de tabel bij de kernregels
  hierboven, plus C20 (9 augustus: Krokodil +3 startpunten). Band 44,7-56,7%;
  was 28-76% in juli.

**F4 (online): F4.0 + F4.1 + F4.2 zijn af (9 augustus).** De nulmeting staat
in het masterplan onder F4. F4.0: blinde factie-keuze als CHOOSE_DOCTRINE,
kloktijd in het log, `View.client_events()`. F4.1: de Node+Fastify-backend in
`server/` (accounts, matches, idempotent actieprotocol; contract in
`docs/protocol.md`). F4.2: de Godot-worker (`tools/server_worker.tscn`,
NDJSON over lokale TCP, gespawnd door `server/src/worker.ts`) — elke actie
gaat door de echte Validator/Reducer en de pariteit is bewezen (opgenomen
partij door de server = zelfde eind-zobrist). **Docker Desktop start op deze
machine NIET** (Windows-AF_UNIX-bug, zie WIP 9 augustus): de database is een
lokale MySQL 8.0.44 zonder Docker, starten met `server/db-lokaal.ps1`, tests
met `FOW_TEST_DB_URL=mysql://root@127.0.0.1:3316/fogofwar_test` (Godot-pad
via `GODOT_PAD`). **F4.2b (3 september):** de client-stream is sluitend
geredigeerd (geen `hash`, geen `cp_bet`; lijst in `View.SERVER_ONLY_EVENTS`,
Node weigert te starten bij verschil), WS en `/events` alleen met een seat,
`GET /matches/:id` voor de lobby; de CP-inzet reist online als veld `cp_bet`
op `define_cards` mee (een losse `bet_cp` is een verklappende rij).

**F4.3 (client) is halverwege, 3-4 september; bouwplan in
`docs/F4.3-bouwplan.md`, stappen a t/m f af, elk een eigen commit:**
(a) nulmeting `-- uispel`; (b) `SessionInterface` (scripts/core/
session_interface.gd), GameSession IS de LocalSession, game.gd praat via
`session`; (c) de bot-naad: alles wat game.gd namens speler 2 deed zit
achter `_ai != null`, `-- naadcheck`; (d) view +4 publieke sleutels,
`net/client_state.gd` (`ClientState.uit_view` op `Agent.reconstruct_state`,
herstelt de id-volgorde want JSON sorteert sleutels), `net/event_codec.gd`,
`ClientStateTests`; (e) render-vanaf-snapshot: `_toon_fase_vanaf_staat`,
`_start_vanaf_sessie`, `render_digest`, `-- herstelcheck` (elk moment een
verse scene op alleen de fog-view, 0 verschillen op 777 en 4242 wolf); (f)
`net/transport.gd` (callback-contract), `net/loopback_transport.gd` (het
protocol in-proces, alles door JSON, bot op de andere stoel),
`net/remote_session.gd` (`RemoteSession`), `RemoteSessionTests` (10 tests,
incl. asynchroon transport en gat-inhaal); (g) game.gd speelt via de
online-weg: MULTIPLAYER → "Oefenen via de online-weg (als rood / als
blauw)" op een loopback met L1-bot, `_start_online`, camera-flip voor
seat 2, namen per seat, CP-inzet in de define, `-- resumecheck` groen op
beide stoelen over alle fasen; (h) `net/http_transport.gd`,
`net/identiteit.gd` (`user://identity.cfg`, `-- identiteit=<naam>`,
`-- server=<url>`), `scripts/core/core_hash.gd` (client en worker dezelfde
functie), polling in `RemoteSession._process`, `GET /view` meldt de seq
van vóór de fold, `-- nettest [url]` 13/13 tegen de dev-server; (i) de
lobby: autoload `OnlineBridge` (`scripts/game/online_bridge.gd`),
MULTIPLAYER → "Online (via de server)" → nieuwe match met match-id,
meedoen, hervatten; `HOST` env op de server voor het LAN;
`-- lobbycheck [url]` 10/10; de 409-herindiening wacht op de inhaal
(asynchroon bewezen met `VertraagdTransport`). Handleiding voor een
playtest met twee mensen: `server/README.md` "Twee mensen tegen elkaar".
**Volgende stap: j** (WS-push, reconnect met backoff, OfflineQueue op
schijf, stiltetest), dan k (botclient, M3). Dev-server:
`server/db-lokaal.ps1`, database `fogofwar` aanmaken (README), dan
`npm run dev` in `server/`.
**F4.4a (4 september): de deploy staat klaar** in `tools/deploy/` (README
voor Max: droplet aanmaken, DNS, `droplet-setup.sh`, dan
`deploy-server.ps1`). Bewezen zonder droplet: pakket-proef, `npm test`
20/20, gebouwde server met het pakket als engine: nettest 13/13,
lobbycheck 10/10. Wacht op Max' droplet; daarna j.
Open besluiten voor Max staan onderaan het bouwplan; tot nu toe zijn de
defaults genomen (alleen `core_hash` als versiecheck, match-id als
roomcode, automatische gastnaam). Elke stap eindigt met de vaste
regressieset uit het bouwplan. De bots zijn na C19/C20 getraind tot een
plateau; het asset-spoor loopt los van alles en blokkeert niets.
