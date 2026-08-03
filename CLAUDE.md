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
- **C15-buit (4.2.1)**: vaandeldrager neerleggen = 2 versterkingspunten,
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
- Nachtrun: `.\arena_nacht.ps1 [-DuurMinuten] [-Kort]` — draait 4.1- én
  v4.2-matrix om-en-om naar aparte run-mappen (B17).
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
- Kijken zonder te spelen: `-- cliplengtes` (elke animatie met lengte EN de
  naam die het spel ervan maakt) en `-- geluidcheck` (elke geluidscategorie met
  aantal varianten, mix-dB, tuner-dB en vertraging; meldt categorieen zonder
  geluid of die niemand afspeelt). Beide via `res://tools/capture.tscn`.
- Fuzz: `<godot> --headless --path . res://arena/arena.tscn -- --fuzz [games] [seed]`
  (`--fuzz-selftest` = test-de-tester).

## Mappen (30 juli)

`assets/models/<factie>/{infanterie,wapens,bron-texturen}/` en
`sounds/{vuren,impact,dood,val,beweging,selectie,kaarten,spel,ui,facties/<factie>}/`.
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

## Waar we zijn (26 juli 2026)

F0 + F1 + F2 af (v4.2-duel speelbaar; D15 geparkeerd, B16). F3 grotendeels af:
C1-C8-spec, CampaignCore (ledger, CReducer, CView, CLog), SoloDriver + 8
persoonlijkheden, CampagneHub-UI, persistentie (append-only jsonl-autosave in
`user://campaigns/solo/`, hervatten = fold, "durf te sluiten") én het
mens-duel op het echte bord (autoload `CampaignBridge`, hoofdmenu-optie
"Solo-campagne (v4.2)"). **De F3-MAX-check is nu speelbaar: solo-campagne
begin→kampioen.** Grootboek-scherm, BracketView, MatchReport-detail en de
touch-contextknop op het bord zijn er ook (26 juli): het F3-UI-blok is af.
Playtest-iteratie C9 (26 juli, Max): ronde 1 = loting (16 random 1v1-paren
als log-data), ronde 2+ = iedereen vecht (raad stemt paren), doneren aan elke
teamgenoot, cycluslimiet op campagne-duels UIT (was 6 → alles tiebreak);
hub-UI = teamkolommen met bolletjes + chatlog. Pre-C9-saves folden onder hun
oude regels (from_dict-fallback), de hub start dan vers. Daarna F4 (online).
1v1-setting (25 juli): cp_start 10, poolfactor 1.5, spawn_totaal_max 15 per
potje; achterrij-pionnen krijgen koppel-voorrang onder campaign.
