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
- **C15-buit (4.3.1)**: vaandeldrager neerleggen = 2 versterkingspunten,
  tamboer = 2 CP, alleen als het slachtoffer ONgekoppeld is. De rol staat op de
  pion (`Pawn.rol`) en verhuist nooit; je wijst de dragers zelf aan in de
  opstelfase. Knoppen: `buit_vaandel_pt`, `buit_tamboer_cp`, `vaandels_max`,
  `tamboers_max`. Bots hebben `buit_jacht`/`buit_hoede`; de arena meet
  `buit_pt`/`buit_cp`/`dragers_verloren`.
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
  meegeven zonder `constants.gd` aan te raken.
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
  blok op. Ook de **fuzz** draait op `rules_v42_campaign.json`, dus mét
  campagne-economie en de echte facties. Wil je expres de kale tabel meten:
  `"facties_uit_bestand": false` in de config.
- Arena: `.\arena.ps1 -Config arena/arena_configs/<x>.json -Procs N -Naam run`
  (machine heeft 32 threads). Dashboard: `python tools/dashboard/build_dashboard.py`
  → `results/dashboard.html`; vergelijken: `python tools/dashboard/compare_runs.py A B`.
- Training: `train_ai.bat [min]` (6 facties, 4.1) of per factie met v4.2-regels:
  `<godot> --headless --path . res://tools/capture.tscn -- train <min> 6 6 <factie> <seed> arena/arena_configs/rules_v42_campaign.json`
  (trainer heeft een relatieve adoptie-gate + convergentiecheck; onder
  v4.2-regels traint hij op campagne-fitness: haven 3 > eliminatie 2 >
  tiebreak 1 > verlies 0 + spaarbonus restleger/CP — één generatie duurt
  met cycle_limit 20 zo'n 10-15 min per factie).
- **Client-regressie (F4.3):** `-- uispel [seed]` speelt een volledige partij
  vs-AI waarin de mens via het timeout-pad van game.gd speelt en print de
  eind-zobrist; seed 777 moet `890b6cb4…` geven (270 acties, cyclus 6, zie
  WIP 3 september). Elke F4.3-stap: uispel gelijk, én `-- record
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
  wordt de factie-categorie nooit bereikt).
- **UI-assetpack nakijken: `-- uicheck`** (statusbord van de UI-assets onder
  `assets/ui/`: elk icoon-id uit `docs/design/UI-SPEC-EN.md` met zijn bestand,
  de zes emblemen, de kaartdelen, elke knop- en paneelstijl met 9-patch-marge,
  de fonts per rol (bedoeld of terugval), en of het thema en de widgets
  bouwen; exit 1 als er iets ontbreekt). Alles wat een scherm nodig heeft komt
  uit `scripts/ui/ui_assets.gd` (`UiAssets`); de autoload `UiThema` legt het
  thema over het hele spel en schermen kiezen vormen met
  `theme_type_variation` (lijst bij THEMA-VARIANTEN in dat bestand). Nieuwe
  png's onder `assets/ui/` eerst `--import`-en. Zie `assets/ui/LEESMIJ.md`.
- **Zwevende wapens/props: `-- zweefcheck [factie]`** (capture.tscn, na de
  opstelling: elke zichtbare mesh die meer dan 2 eenheden van zijn eigen pion
  staat, met naam en ouderketen; PASS/FAIL). Bot-geparente wapens uit Blender
  5.1 zweefden meters naast de hand door een export- en importbug; de
  pijplijn corrigeert dat (`tools/blender_botkind_fix.py`, zie
  MODEL-PIPELINE-CHECKLIST sectie C). Draai dit na elke her-export.
- Model-tuner nakijken: `-- tunercheck` (welk model het spel per factie en
  archetype vindt, welke modellen nog GEEN gibs hebben, of de tuner-scene
  opbouwt, en of de afstelling een rondje opslaan-en-teruglezen byte-identiek
  overleeft). Draai dit na elke map- of modelwijziging; het is meteen het
  statusbord van "wat is er al geleverd".
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
- **C15-buit (4.3.1).** Vaandeldrager neerleggen levert 2 versterkingspunten op,
  tamboer 2 CP, alleen bij een ongekoppeld slachtoffer.
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
