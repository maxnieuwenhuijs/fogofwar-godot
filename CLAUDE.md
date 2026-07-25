# Fog of War — projectcontext

Godot 4.7-strategiespel (fog-of-war-bordspel, dierenfacties) met een pure
GDScript-engine (reducer-patroon), AI-agents, een meet-arena en een campagne
in aanbouw. **Lees `MASTERBOUWPLAN.md` (fasering + werkafspraken + besluiten
B1-B17) en `WIP.md` (per-stap-logboek) voor de actuele stand.**

## Kernregels (samenvatting; bron: MASTERBOUWPLAN §0 + besluiten)

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
- **Paneel** (Max' knoppen): `"FogOfWar Paneel.bat"` → nachtrun (vol/kort),
  training, L2-matrix, fuzz, dashboard, STOP.
- Nachtrun: `.\arena_nacht.ps1 [-DuurMinuten] [-Kort]` — draait 4.1- én
  v4.2-matrix om-en-om naar aparte run-mappen (B17).
- Arena: `.\arena.ps1 -Config arena/arena_configs/<x>.json -Procs N -Naam run`
  (machine heeft 32 threads). Dashboard: `python tools/dashboard/build_dashboard.py`
  → `results/dashboard.html`; vergelijken: `python tools/dashboard/compare_runs.py A B`.
- Training: `train_ai.bat [min]` (6 facties, 4.1) of per factie met v4.2-regels:
  `<godot> --headless --path . res://tools/capture.tscn -- train <min> 6 6 <factie> <seed> arena/arena_configs/rules_v42_campaign.json`
  (trainer heeft een relatieve adoptie-gate + convergentiecheck).
- Fuzz: `<godot> --headless --path . res://arena/arena.tscn -- --fuzz [games] [seed]`
  (`--fuzz-selftest` = test-de-tester).

## Architectuur in één alinea

`core/match/` = de pure engine: `reducer.gd` (apply → {ok, events, error}),
`validator.gd` (is_legal/gate_check/legal_actions), `actions.gd` (actietaal
incl. SPAWN/BET_CP/CANNON_ACT), `view.gd` (per-speler fog-views),
`serializer.gd`/`zobrist.gd`/`match_log.gd` (replays), `rules_config.gd`
(alle knoppen incl. campaign-blok). `scripts/core/GameState.gd` draagt de
staat (incl. pools/cp), `GameSession.gd` is de signal-shim voor de UI
(game.gd, 2441-regel monoliet). `agents/` = L0-L3 op views;
`arena/` = runner/metrics/fuzz; `tools/capture.gd` = CLI-modes + trainer.

## Waar we zijn (25 juli 2026)

F0 + F1 volledig af. F2 (v4.2-economie): F2.1-F2.5 af, F2.6 deel A (metingen)
af op het D15-besluit na, **deel B (spawn-UI, CP-toggle, actiepot-badge,
MatchSetup) is de eerstvolgende bouwklus** — daarna speelt Max zijn eerste
v4.2-duel (de F2.6-MAX-check). Daarna F3: de teamcampagne (donaties per lid
bepalen de duel-pool en CP; duel-restant CP vloeit terug en is overdraagbaar;
uitvallers laten na via het testament (max helft, max 2 ontvangers, timer);
eliminatie telt door over wedstrijden; battlereports zijn de info-bron over
vijandelijke voorraad — zie B16/D15-context). 1v1-setting (25 juli): cp_start 10,
poolfactor 1.5, spawn_totaal_max 15 per potje; achterrij-pionnen krijgen
koppel-voorrang onder campaign (spawn-rij vrijspelen).
