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
  spelen (meting), Bekijk het rapport, STOP alles. Meet-gereedschap voor
  Claude (fuzz, L1-test, losse L2-matrix, 4.1-training via train_ai.bat)
  draait alleen nog via de CLI.
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

`assets/models/<factie>/{infantry,weapons,source-textures}/` en
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
via `GODOT_PAD`). Volgende stap: F4.3 (client: render-vanaf-snapshot,
camera-flip, RemoteSession). De bots zijn na C19/C20 getraind tot een
plateau; het asset-spoor loopt los van alles en blokkeert niets.
