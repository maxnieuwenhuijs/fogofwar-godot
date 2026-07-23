# Fog of War — Work In Progress & Context

> Levend document. Bijgewerkt terwijl we bouwen. Laatste grote update: mens-vs-AI
> volledig speelbaar, met slimme kaarten, health/stamina/attack-blokjes, animaties
> en projectie-picking.

---

## ⏵ MASTERBOUWPLAN — voortgang (bijgewerkt juli 2026)

Uitvoering volgt `MASTERBOUWPLAN.md`. Afgerond:

- **F0.0 — Specs vastgelegd + dode code opgeruimd.** `docs/spelregels-v4.2.md`
  (Deel A = 4.1.9-hr zoals geïmplementeerd, Deel B = 4.2-concept) +
  `docs/spelregels-CHANGELOG.md` (12 stille afwijkingen gedocumenteerd). Alle
  RPS-code verwijderd (Phase-enum hernummerd — er bestond nog geen serialisatie).
  **Muis-comp → [18,4,0]** (besluit Max; hertraining volgt in F1.6, de oude
  Muis-gewichten gelden als verouderd). Besluit: **geen n8n** — jobs worden
  node-cron/systemd-timers (masterplan B5 aangepast). capture.gd `-- play` hangt
  headless niet meer op de screenshot (null-texture → overslaan + nette exit).
  Checks: 422 asserts groen · rps-grep 0 (incl. tools/) · `-- play` exit 0.

- **F0.1 — SeededRng.** `core/shared/seeded_rng.gd` (class_name SeededRng:
  randi_range/randf/randf_range/randfn/pick/shuffle/fork). AIController heeft
  `rng` (default seed 1337); AIEasy, trainer (run_seed-veld) en de headless
  CMA-trainer loten er nu doorheen — de "randi alleen op de main thread"-
  beperking in capture.gd is daarmee vervallen. MatchRunner: 5e param
  `seed_val` → forkt per agent ("p1"/"p2"). Sim-CLI: `-- sim <p1> <p2> [d1]
  [d2] [seed]`; train-CLI: 5e arg = run-seed. Doctrine-loting (game.gd) blijft
  bewust globaal (pre-match invoer, gedocumenteerde uitzondering, net als
  audio/VFX). Nieuwe suite DeterminismTests (6 tests). Check-grep verfijnd naar
  kale globale calls (de SeededRng-API hergebruikt de randi_range-namen).
  Checks: 456 asserts groen · sim seed 777 2× identiek, 778 wijkt af ·
  `-- play` exit 0.

- **F0.2 — rules_config.** `core/match/rules_config.gd` (class_name RulesConfig):
  ~20 knoppen als data — vuurmodel (fire_hits_inactive/fire_blocked/
  inf_shot_over_pawn), statue_threshold (melee én schot), haven_score_cumulative
  (touch-hook in GameState.set_pawn_position), per_stat_cap, schotparameters,
  retaliation-dict, stamina_model pool|one_action, cycle_limit+tiebreak (velden;
  handhaving F0.4c), clock (velden; F0.8), doctrine-overrides, campaign-blok
  (F2). GameState.rules (clone deelt referentie — config is match-onveranderlijk);
  Rules.gd leest alles via state.rules; vuurlijn-scan gedeeld (_scan_fire_lines).
  shot_damage/shot_cost/move_range kregen state als eerste param. Sim-CLI:
  `--rules <pad.json>`; `-- genrules` schrijft defaults →
  arena/arena_configs/v41_default.json. Suite: +17 tests (RulesConfigTests).
  Checks: 503 asserts groen · sim seed 777 met/zonder default-config identiek
  (winner=2 cyclus=12 acties=339 = F0.1-baseline) · `-- play` exit 0.

- **F0.3 — actions + validator.** `core/match/actions.gd` (12 actietypes als
  const strings, make_*-factories, to_dict/from_dict met Vector2i↔[x,y],
  is_wellformed; CLAIM_TIMEOUT gedefinieerd maar illegaal tot F0.8, RESIGN
  krijgt effect in F0.4c). `core/match/validator.gd`: is_legal(state, action,
  player) met exact de bestaande foutmeldingen (charge via droge run op een
  kloon) + legal_actions (PLACE/DEFINE als voorbeeld-generator, rest volledig,
  incl. charge-enumeratie). Alle GameSession.submit_* + skip_wolf_step gaan
  door de poort; _validate_action_turn verwijderd. tests/ValidatorTests.gd:
  property-test 50 random partijen uit legal_actions (elke actie is_legal,
  elke dispatch geaccepteerd, JSON-roundtrip) + roundtrip/wellformed/samples.
  Checks: 613 asserts groen (24s) · sim seed 777 onveranderd · `-- play` exit 0.

- **F0.4a — Reducer, deel 1 (actiefase).** `core/match/reducer.gd`:
  apply(state, action, player_id) -> {ok, events, error} voor MOVE/MELEE/
  SHOOT/CHARGE/WOLF_STEP/SKIP_WOLF_STEP incl. beurtwissel (_advance_turn),
  win-check (_check_game_over) en CYCLE_RESET-event (shim draait
  _start_new_cycle tot F0.4b). Events = typed dicts {type, seq, payload};
  GameSession vertaalt ze 1-op-1 naar de bestaande signals (_relay_events) —
  game.gd merkt niets. _post_action/_after_combat/_check_action_phase_status
  uit GameSession verwijderd. Sim-CLI geherstructureerd: _run_sim-helper +
  nieuwe modus `-- simcheck` (draait tests/golden_sims.json, exit 1 bij
  afwijking; 5 vaste seeds vastgelegd op pre-reducer-commit d320647;
  medium-medium ontbreekt bewust — kan zonder cycle_limit oneindig patstellen,
  F0.4c). Checks: 613 asserts groen · simcheck 5/5 OK · `-- play` exit 0.

- **F0.4b — Reducer, deel 2 (setup-fasen + cyclus).** De volledige fasemachine
  zit in de reducer: PLACE (beide binnen -> define + CYCLE_STARTED),
  DEFINE_CARDS (commit-gate -> reveal + CARDS_REVEALED-event), **ACK_REVEAL
  per speler** (state.reveal_acks; single-ack-gat dicht — validator weigert
  dubbele ack met "Al bevestigd"), LINK met staartkoppel-logica,
  ronde/cyclus-overgangen en _start_new_cycle. GameSession = 132-regel shim
  (19 functies; F0.9-doel <=150 nu al gehaald): submits zijn 1-regel-
  delegaties, acknowledge_reveal() = compat-shim die beide spelers ackt,
  nieuw: submit_ack_reveal(player). Nieuwe events: EV_PLACEMENT,
  EV_CARDS_REVEALED, EV_CYCLE_STARTED (EV_CYCLE_RESET vervallen).
  tests/ReducerTests.gd: per-speler-ACK, fold-test opstelling->actiefase
  ZONDER Node (18 koppelingen, 2x9 actieve pionnen), initiatief-tiebreak.
  Checks: 705 asserts groen · simcheck 5/5 OK · `-- play` exit 0.

- **F0.4c — Reducer, deel 3 (RESIGN + remise; MatchRunner Node-vrij).**
  RESIGN werkt in elke speelbare fase (tegenstander wint; na GAME_OVER
  illegaal). Cycluslimiet is een echte spelregel: rules.cycle_limit > 0 en
  cyclus voorbij de limiet -> Reducer.tiebreak_winner (materiaal -> haven ->
  nabijheid; alles gelijk = -1 remise) — einde oneindige patstellingen
  (default 0 = uit, offline ongewijzigd). MatchRunner draait rechtstreeks op
  Reducer.apply met een kale GameState: geen GameSessionScript.new()/free()
  meer; dispose() is een no-op (compat). Trainer en arena volgen automatisch.
  Reducer-tests: resign per fase, tiebreak-materiaal, echte-remise-spiegel.
  Checks: 768 asserts groen · simcheck 5/5 · `-- play` exit 0 · `-- arena 4
  medium` Node-vrij (matrix, zie hieronder).

- **F0.5 — serializer.** `core/match/serializer.gd`: state_to_dict/
  state_from_dict — kaarten EENMAAL per id (all_cards), cards_defined/
  cards_revealed als id-lijsten, reconstructie herstelt referenties naar
  dezelfde objecten; bord wordt herbouwd uit pion-posities; RulesConfig
  serialiseert mee; JSON-veilig (string-keys, Vector2i als [x,y]).
  GameState.clone() ref-correct gemaakt (defined/revealed wijzen naar de
  all_cards-klonen) en blijft handgeschreven voor de AI-hot-path; de
  lockstep-test (clone == serializer-roundtrip, veld-voor-veld) bewaakt dat
  beide kopieerpaden identiek materialiseren. Dood veld
  pending_forced_move_attacker/target verwijderd (CHANGELOG-restpunt).
  tests/SerializerTests.gd (7): round-trip in ELKE fase (incl. GAME_OVER via
  resign), doorspelen-na-deserialisatie identiek (40 zetten lockstep),
  risico-7-regressie (linking EINDIGT op gedeserialiseerde staat),
  kaart-identiteit, clone-ref-correctheid, bord-herbouw met eliminaties.
  Checks: 828 asserts groen · simcheck 5/5 · `-- play` exit 0.

- **F0.6 — view.gd (fog of war).** `core/match/view.gd`: View.for_player(state,
  player) -> gefilterde JSON-veilige weergave. Blind opstellen (PLACEMENT:
  vijandelijke pionnen bestaan niet in de view), defines onzichtbaar tot de
  reveal (geen aantallen-lek; enemy_has_defined-bool is wel openbaar),
  Krokodil-dekking: stats -> "?"-sentinel (geen 0/-1), koppeling weggelaten,
  vijandelijke kaart openbaar maar linked_pawn_id geredacteerd zolang gedekt.
  UI: HP-blokjes tonen "?"-label voor gedekte vijandelijke pionnen (game.gd
  _build/_update_health_bars). tests/ViewTests.gd: leak-canary property-test
  (200+ staten over 12 partijen met Krokodil, structurele checks — letterlijk
  de test die in F4 de servergrens bewaakt) + blind-placement/define-hidden/
  sentinel-unit-tests. Nieuwe capture-modus `-- vosview`: speelt tot de
  actiefase vs Krokodil-AI en assert het "?"-label op alle 9 gedekte pionnen
  (exit-code op de assert). NB: de AI leest nog steeds de volle staat — dat
  is B8-werk (agents op views, F1.1, met full_state-ablatievlag).
  Checks: 846 asserts groen · vosview PASS (9/9) · simcheck 5/5 · play exit 0.

- **F0.7 — event-log, zobrist en golden replays.** `core/match/match_log.gd`:
  append-only {seq, player_id, action, events, hash, ts} per geaccepteerde
  actie; fold() = de replay-machine (per-actie hash-checksum);
  verify_file() = fold + eind-hash + byte-identieke eindstaat (genormaliseerd
  — JSON leest ints als floats terug). `core/match/zobrist.gd`: state-hash =
  sha256 over de canonieke serialisatie (incrementele XOR is F1-optimalisatie).
  GameSession.match_log = opt-in recording op alle drie accept-paden.
  Capture-modi: `-- record <uit.json> <p1> <p2> [d1] [d2] [seed]`,
  `-- replay <bestand>` (exit 0 bij byte-match), `-- makegoldens`.
  tests/golden_replays/: 12 goldens — 6 volledige sim-partijen (1 per
  doctrine, vaste seeds) + 6 randgevallen (terugslag-doodt-aanvaller,
  wolf-stap-in-haven-wint, charge-kill-verplichte-verplaatsing,
  vos-onthulling-bij-schade, kaart-vervalt-zonder-pion, cycluslimiet-remise).
  GoldenReplayTests: elke golden byte-identiek bij elke suite-run — breekt er
  een: bewuste beslissing + versie-bump + CHANGELOG (werkafspraak §0).
  Checks: 860 asserts groen · 12/12 goldens · 10 partijen record+replay
  byte-identiek · simcheck 5/5 · play exit 0.

- **F0.8 — klokken + CLAIM_TIMEOUT.** state.clocks[speler]={bank_ms} +
  state.turn_deadline (absoluut, in het now_ms-domein van de aanroeper);
  Reducer.apply(+now_ms-param — puur, leest zelf geen klok). Model:
  setup-fasen = increment_sec per beslissing (deadline verlopen -> defaults:
  default-opstelling / default-loadout via de validator-samples / auto-ack /
  auto-link); actiefase = increment + bank (overschot eet de bank; deadline
  verlopen = forfeit). CLAIM_TIMEOUT volledig: validator checkt structureel
  (klokken aan + deadline gezet), de reducer valideert het verstrijken met
  now_ms. bank_sec 0 (default) = klokken uit -> offline ongewijzigd; game.gd
  blijft offline de klok-autoriteit (20s-driver) maar de fasetimer leest
  state.turn_deadline zodra die gezet is. UI: opgeven-knop (met bevestiging)
  onder de sfeer-knop -> GameSession.submit_resign. Ook: submit_claim_timeout.
  Serializer + clone dragen clocks/turn_deadline mee -> goldens geregenereerd
  (formaat-wijziging, geen regelwijziging; simcheck 5/5 bewijst dat).
  tests/ClockTests.gd (7): increment spaart bank, trage actie eet bank, claim
  voor deadline geweigerd, lege bank = forfeit, timeout in define =
  default-loadout, klokken-uit = claim illegaal, klok-round-trip.
  Checks: 885 asserts groen · simcheck 5/5 · play exit 0 · vosview PASS.

- **F0.9 — acceptatie (headless-deel AF).** Alle Claude-checks groen:
  (1) suite 170 tests / 900 asserts (was 111/310 bij de nulmeting) incl. 5
  extra dekkingstests (timeout-in-reveal ackt achterblijver, timeout-in-
  linking koppelt automatisch, dekking-vervalt-bij-cyclus-reset,
  haven_touches-round-trip, vervalst-log-wordt-afgekeurd — het F4.5-anti-
  manipulatiepad); (2) 10-partijen-replay 10/10 byte-identiek (F0.7);
  (3) leak-canary + vosview PASS; (4) play/simcheck/arena-matrix groen;
  (5) GameSession 162 regels (~150-doel; incl. commentaar), Rules.apply_
  buiten de reducer alleen nog in AIController-SIMULATIE op klonen
  (gedocumenteerde uitzondering; live-staat muteert uitsluitend via de
  reducer; F1.1 agents-op-views ruimt dit op).
  **MAX-acceptatie gespeeld: alles klopt** — F0 IS FORMEEL AF (juli 2026).

- **Regelwijziging 4.1.10-hr (besluit Max, na F0):** kaartdefinitie is
  begrensd door je vrije pionnen; 0 vrije pionnen = ronde overslaan, de
  tegenstander gaat alleen door. Doorgevoerd in validator (expected_define_
  count), reducer (define-gate + fase-entry-gates), AI, sim/MatchRunner en de
  kaartwaaier-UI. Versie-bump 4.1.9-hr -> 4.1.10-hr; CHANGELOG-entry; goldens
  + golden_sims-baselines geregenereerd (bewuste breuk conform werkafspraak).
  3 legacy-tests bijgewerkt; 3 nieuwe regeltests. Checks: 915 asserts groen ·
  simcheck 5/5 (nieuwe baselines) · play exit 0.

## F1 — Arena v1 (bezig)

- **F1.1 — Agent-interface op views.** Hard contract (bouwplan par. 7.1):
  `decide(view, legal, rng) -> Action`. `agents/agent.gd` (basisklasse +
  reconstruct_state: view -> speelbare staat met PUNTSCHATTING voor gedekte
  stats = gemiddelde over onthulde vijandelijke kaarten, B11; gedekte pion
  heeft per definitie nog geen schade dus current=max klopt per constructie),
  `l0_random.gd` (uniform random — fuzz-motor), `l1_greedy.gd` (kill > haven >
  schade > random; arena-werkpaard), `l2_weights.gd` (AIMedium-eval op de
  reconstructie; per-doctrine-profielen uit ai_weights.json),
  `l3_search.gd` (Hard/Ultra-search, zelfde reconstructie),
  `agent_runner.gd` (EEN uniforme lus voor alle fasen: view + legal_actions +
  Reducer.apply; geen fase-dispatch, geen Node — de kiem van arena/run.gd en
  het worker-model). full_state-vlag (B8) -> View.for_player(redacted=false):
  fog-loze view voor ablatie. View uitgebreid met haven_touches (publiek).
  Vangnetten gemeten: illegal_count/fallback_count op de runner.
  Oude AIEasy..Ultra blijven als UI-wrappers (plan-conform) tot de game-UI
  overstapt. tests/AgentTests.gd: L0 20 volledige partijen 0 illegaal/0
  fallback (cycle_limit begrenst), puntschatting-test, L1-kill-test,
  B8-ablatie gelogd (view 2 - full 2 - remise 0 over 4 Krokodil-spiegels;
  echte meting volgt in F1.6). Checks: 1013 asserts groen (1m32s) · simcheck
  5/5 · play exit 0 · vosview PASS.

- **F1.2 — standalone runner + metrics.** `arena/arena.tscn` + `arena/run.gd`:
  `godot --headless --path . res://arena/arena.tscn -- --config <json> --out
  <map> [--seed-offset N]`. Configs in arena/arena_configs/: quick_l1 (2
  doctrines x 10), matrix_l1 (alle 36 richtingen), vos_ablatie_l2 (B8:
  full_state p2). `arena/metrics.gd`: per game EEN jsonl-regel met de
  letterlijke par. 8.2-mapping — cycli, winnaar+methode (haven/eliminatie/
  tiebreak/remise + trigger), zobrist-herhalingen, standbeeld-kills per
  kaartprofiel (1/5/1-oogst), schoten per kanon + kanonnen-zonder-schot-%
  (benadering geblokkeerde intenties), koppelverdeling kaartprofiel->type
  PER SPELER, overkill-per-kill (Leeuw-spiraal), schade-per-actie (Muis),
  winmethode per havenvak (hoekfort), full_state-vlaggen (ablatie).
  Header-regel: git-sha + config + ts; game-regels ZONDER wallclock ->
  zelfde config+seed = byte-identieke jsonl (bewezen: run A == run B).
  arena.ps1 (multi-proces: 1 per core, seed-offset, merge), arena.bat ->
  nieuwe runner (FOW_NOPAUSE-guard; oude capture-pad blijft, zie
  arena.bat.oud). results/ in .gitignore (B10: reproduceerbaar uit
  config+seed). EERSTE DOORVOERMETING: 3.0 match/s/core met L1 (was 0.13
  met de oude Node-runner — 23x sneller; F1.3-doel >=5/s is dichtbij).
  Checks: schema 0 fouten · reproduceerbaarheid bewezen · 1013 asserts
  groen · simcheck 5/5 · play exit 0.

Volgende stap: **F1.3 — doorvoer >=5 matches/s/core** (meetladder + optimalisaties). (agent-interface op views, L0-L3, doorvoer
>=5 matches/s/core, metrics per bouwplan-par. 8.2, fuzz, dashboard, en de
eerste balanspatch op data — Muis-hertraining met de nieuwe cavalerie).

---

## ⏵ STAND VAN ZAKEN MODELLEN + GORE-SYSTEEM (bijgewerkt 6 juli 2026, avond)

**De Muis-infanterie is 100% af en het complete gore/effect-systeem staat.**
Pipeline bewezen end-to-end: Meshy/Tripo (Laag Poly ~1k) → Mixamo auto-rig →
Blender (delen LOS houden!) → glb → auto-fit → Model-tuner. Alles hieronder werkt
automatisch voor elk volgend model dat de conventies volgt.

**Model-conventies (BELANGRIJK voor factie 2+):**
- Levend model: `assets/models/<factie>/<type>_<archetype>.glb` met losse
  geskinnede meshes `hat`/`armL`/`armR`/`legL`/`legR`/`tail`/`body` aan één
  skelet (in Blender NIET joinen; P → Selection om te splitsen).
- Gibs: `<model>_gibs.glb` met delen `Torso/ArmL/ArmR/LegL/LegR/Hat` (bebloede
  stompjes door Max geschilderd).
- Clips mogen `fire`/`death1`/`death2` heten (ANIM_ALIASES vertaalt naar
  attack/die); varianten idle1-3/walk1-3 worden random gekozen met desync.
- Verse Blender-export? Walk-clips hebben vaak weer root-motion → één keer
  `tools/blender_merge_character.py --base <glb>` draaien (detrend), of In
  Place-varianten in het blend-bestand zetten. `fix_mouse_clips.bat` is er
  als vangnet maar meestal niet meer nodig (clips zitten in Max' blend).

**Auto-fit (definitief opgelost 6 juli):** meet het skelet in het EERSTE
IDLE-FRAME (niet de A-rustpose — dat was de oorzaak van zwevende/verschoven
modellen), centreert horizontaal op het ZWAARTEPUNT van de lijf-botten
(staart telt nergens mee), zolen op de grond via voet-botten. Handmatige
x/z-tuning is model-ruimte (draait mee met facing). Tuner heeft debug-
tegelrand + middenkruis + meetcijfers in de infobalk; capture-modus
`-- align` print per pion de delta t.o.v. zijn tegel + top-down screenshot.
Tuner-camera = bordcamera (orthograaf, zelfde hoek): WYSIWYG.

**Dood-systeem (allemaal tunebaar via de Model-tuner, opslag in
`assets/models/effects_tuning.json`):**
- **Kanon (strength ≥1.2)**: lijf klapt uiteen in gibs, alles blast WEG van
  het schot (dir dominant), per-deel ruis op kracht/hangtijd, delen landen
  plat (dunste as omhoog), bloedmist-billboards (Max' `blood_mist*.png`) +
  druppel-fontein met blast-bias; druppels laten splat-vlekken achter; elk
  brokstuk krijgt EEN pool-plas exact onder zijn landingsplek (romp groot,
  hoedje klein).
- **Musket-schot**: death-animatie (random death1/death2) + borst-fontein
  die 1-3x pompt (stoten volgen de zakkende torso, elk een eigen splat) +
  OF hoedje eraf OF één ledemaat (echte mesh verdwijnt, gib vliegt, straal
  uit het stomp-gat) + lijkpoel onder de TORSO (per death-clip instelbaar:
  wacht/groei/maat/torso-afstand via de "Dood-poel"-rij + test-knop).
- **Melee**: zelfde maar alleen ledemaat (nooit het hoedje) — kind-parameter
  loopt van game.gd ("shot"/"melee") door play_death.
- **Bloedtextures**: `assets/textures/blood/` — `blood_pool*` (plassen),
  `splat*` (inslagen), `blood_mist*` (mist-billboards); automatisch opgepikt,
  prefix bepaalt gebruik, map leeg = procedurele fallback.
- Alles blijft liggen (groep `battlefield_debris`) tot de nieuwe cyclus;
  tuner laat het ook liggen tot de volgende test.
- Tuner-knoppen (stap 0.01, max 10): hoed-kracht/-hangtijd/-kans,
  ledemaat-kans/-kracht/-hangtijd, gib-worpkracht, gib-tolling,
  wond-druppels, spuit-straal, kanon-mist, druppel-duur/-maat/-vlekkans,
  vlek-wacht/-groei, gib-poel-wacht/-groei, plas-wacht/-groei/-maat,
  lijkpoel-fallback. Drie gib-testknoppen: kanon/musket/melee.

**VOLGENDE STAPPEN:**
1. **Team-textures**: per model `<basis>_team1.png`/`_team2.png` (rood/blauw
   leger) — Max levert recolors, Claude bouwt loader + tuner-preview.
   Urgent-ish: sokkel is weg, dus mirror-matches missen team-onderscheid.
2. **Muis-archetypes** (spd/hp/atk) en dan de overige facties door de
   pipeline (prompts klaar in MODEL-WISHLIST §3).
3. **Cavalerie = BIG BRO** (besluiten 6 juli, zie MODEL-WISHLIST):
   varken/everzwijn (MENS-slot), muis/dikke rat (comp 22/0/0 → moet cav
   krijgen, bv. 18/4/0 + arena-hermeting), cheetah/leeuw, wasbeer/grizzly,
   vos/dire wolf (WOLF-slot), hagedis/krokodil (VOS-slot). Big bros
   tweebenig, Mixamo melee-clipset (Idle/Walking/Melee Attack/Death).
4. **Aim/anticipation**: "Rifle Down To Aim" als `aim`-clip + projectiel/knal
   ~0.2s vertragen tot het vuur-frame.
5. Open: arena-run Muis-balans, trainer-nachtrun v2, online-playtest Fase 0,
   resterende sounds (place_undo, timer_timeout, wolf_step, muziek-menu),
   cavalerie-audio per familie (horse_* vervangen).

---

## 1. Wat is dit

2-speler tactisch **3D**-bordspel, **Godot 4.7** (Forward+, Jolt Physics, D3D12),
portrait 1080×1920. Je speelt (rood = speler 1) tegen een AI (blauw = speler 2).

- **Spelregels: `spelregels-v4.1.md` is de geldende regelset** (eenheidstypes Infanterie/
  Cavalerie/Artillerie, vuurlijnen, terugslag, 6 doctrines, vrije opstelling, initiatief-bod).
  `game_description.md` (v1) is het basisdocument waarop v4.1 voortbouwt.
  **De engine implementeert v4.1 volledig** (zie §2b); resterende UI-gaten in §9.
- Opgeruimd (juli 2026): `GAME_LOGIC_OVERVIEW.md` (oude 2D/server-implementatie) is
  verwijderd; de `README.md` is herschreven naar de huidige 3D-realiteit.
- De volledige, geteste engine + AI is geport uit het oude project
  `C:\Users\maxni\FOGOFWAR GODOT` (dat was 2D). Hier bouwen we de 3D-presentatie erop.

## 2. Huidige status — SPEELBAAR

Volledige mens-vs-AI loop werkt end-to-end:

1. **Difficulty-menu** bij start: Easy / Medium / Hard → **doctrine-keuze** (6 doctrines;
   de AI kiest blind willekeurig) → **opstelling** (standaard-opstelling bevestigen).
2. **Definieer** je kaarten via de waaier (aantal × budget volgt je doctrine, zie §5).
3. **Onthulling**: scherm toont bod-percentages + aanval/speed en wie begint
   (deterministisch — geen RPS meer).
4. **Koppelen** (interactief): tik een kaart onderaan → je pionnen lichten op → tik een pion.
   AI koppelt automatisch op zijn beurt (staartkoppelen bij ongelijke aantallen).
5. Herhaalt 3 rondes.
6. **Actiefase**: pion selecteren → groen = bewegen, rood = melee/charge, oranje = schot.
   Wolf-doctrine: na melee cyaan vakken = gratis stap (rechtermuis = overslaan). AI reageert.
7. **Win** → eindscherm met "Nieuw spel".

Engine bewaakt alle regels. **364 test-asserts groen** (`res://tests/TestScene.tscn`).

## 2b. Regels v4.1 — GEÏMPLEMENTEERD (engine + AI + UI)

De volledige v4.1-regelset zit in de engine (`scripts/core/`):

- **Eenheidstypes** op Pawn (`unit_type`): Infanterie / Cavalerie / Artillerie; letter op de
  pion (`PawnView.set_unit_type`) + andere blokvorm (cavalerie hoog, artillerie plat/breed).
- **Opmaakbare stamina (HUISREGEL, wijkt af van v4.1 §3.3/§4.4)**: stamina is de
  actievoorraad van de cyclus — stap = 1, melee/schot = 1, charge = stappen + 1
  (`Pawn.spend_stamina`). Een pion mag meerdere beurten handelen tot de voorraad op is.
  Terugslag en de Wolf-stap zijn gratis.
- **Acties per type** (`Rules`): infanterie beweeg/melee/schot (afstand exact 2, tussenvak
  leeg, schade Attack−1, `get_valid_shot_targets`); cavalerie charge (`apply_charge`,
  bewegen + optionele melee, minstens 1 stap óf aanval, kosten stappen+1) en **springt
  ALTIJD over eigen pionnen heen** (HUISREGEL; gepasseerde vakken tellen als stappen);
  artillerie **1 ding per beurt** (1 stap óf 1 schot) met **vaste dracht 6** (HUISREGEL,
  `Constants.ARTILLERY_RANGE`; v4.1 zei dracht = Speed), volle Attack, dode zone op 1.
  Artillerie-Speed is dus puur het aantal acties per cyclus.
- **Factie-perks (HUISREGELS, juli 2026)**: Leeuw-kanonnen dracht 7 (`art_range_bonus`);
  Vos-cavalerie +1 Speed bij koppeling (`cav_speed_bonus`); Wolf-cavalerie springt óók
  over VIJANDELIJKE infanterie (`cav_jump_infantry`; niet over vijandelijke cav/art);
  Muis +1 Speed op ELKE pion bij koppeling (`speed_bonus`, doctrine-breed buiten het
  budget) — anders kruipt de budget-5-zwerm te traag over het bord (min stamina 2, typisch 3).
  Teksten (pro/con per doctrine) staan in `Constants.DOCTRINE_DATA`.
- **Terugslag** (`_resolve_melee`, HUISREGEL type-afhankelijk): een ACTIEVE verdediger die
  een melee overleeft slaat terug op de aanvaller — infanterie −1, cavalerie −2,
  artillerie −0 (`Constants.RETALIATION_DAMAGE`). Geen terugslag bij dood, tegen
  beschietingen, of van inactieve pionnen.
- **Vuurregels**: vuur raakt óók inactieve pionnen; elke tussenliggende pion blokkeert;
  vuur wint geen terrein (geen forced move); melee-eliminatie → verplichte verplaatsing.
- **Vrije opstelling**: `Phase.Type.PLACEMENT` + `submit_placement`; `default_placement()`
  per doctrine (artillerie vóór op flank/centrum, cavalerie achter). RPS is weg —
  initiatief is deterministisch: **bod-percentage** (`Rules.compute_bid`, §4.3-B) →
  Speed-bod → C1/R1: P1, anders vorige initiatiefhouder.
- **Doctrines** (`Constants.DOCTRINE_DATA`, per speler in `state.doctrines`): Mens 3×7,
  Muis 4×5 (22 inf, doorbewegen door eigen pionnen), Leeuw 2×9 (18 pionnen 6/10/2),
  Beer (+1 HP bij koppeling buiten budget, Speed max 3 bij definitie), Wolf (gratis stap
  na elke melee; `pending_wolf_step_pawn` + `submit_wolf_step`/`skip_wolf_step`),
  Vos (gedekt koppelen: `pawn.card_revealed=false` tot schade geven/krijgen).
- **Koppelen**: staartkoppelen bij ongelijke kaartaantallen; kaarten zonder geldige pion
  vervallen; initiatiefhouder zonder koppelwerk → beurt direct naar de ander (bugfix).
- **AI**: `enumerate_actions` met schoten + charges, `choose_placement`, `choose_wolf_step`,
  budget-bewuste `generate_cards` (respecteert doctrine-budget + Beer-speedcap).
- **UI/driver**: doctrine-keuzemenu (AI kiest blind willekeurig), opstelling-overlay,
  kaart-UI met dynamisch budget/aantal (`CardHand.configure`), targeting: rood = melee/
  charge, oranje = schot, groen = bewegen; wolf-stap = cyaan vakken klikken (rechts =
  overslaan); bod als percentage in het onthul-scherm.
- **Sims per doctrine**: `capture.tscn -- sim <ai1> <ai2> [doctrine1] [doctrine2]`
  (bv. `sim medium hard muis leeuw`). Alle 6 doctrines spelen uit met winnaars via
  beide wincondities.

## 3. Architectuur (3 lagen)

```
Laag 3  Driver          scripts/game/game.gd  — koppelt GameSession aan het 3D-bord,
                        input, AI-beurten, overlays, animaties, indicatoren.
Laag 2  Presentatie     Board.tscn (bord+camera), pawn_view, card_hand/card_view, overlay.
Laag 1  Core (headless) scripts/core/  — Phase, Card, Pawn, GameState, Rules, GameSession.
        AI              scripts/ai/    — AIController + AIEasy/AIMedium/AIHard.
```

- **Autoloads** (project.godot): `Constants` (`scripts/core/constants.gd`) en `GameSession`.
- `Constants` is gemerged: engine-constanten + compat-enums (`Team`, `UiPhase`) +
  `STAT_TOTAL`/`MIN_STAT` voor de kaart-UI.
- Engine-`Card` (id/owner) ≠ UI-`CardData` (edit-model in de waaier). Ze bestaan naast elkaar;
  bij `submit_define_cards` geeft de UI dicts `{hp,stamina,attack}` door.

## 4. Belangrijke bestanden

| Bestand | Rol |
|---|---|
| `scripts/game/game.gd` | **Driver** — alle glue: flow, input, AI, overlays, animatie, blokjes |
| `Board.tscn` | Volledig 11×11 bord (node "Board", incl. Camera3D + light + havens) |
| `scenes/game/pawn_view.tscn/.gd` | Pion: speelstuk/model + ring + facing. `@export model_scene` = karaktermodel (.glb met AnimationPlayer); anders het type-speelstuk. `play_walk/attack/idle/die`, `face_dir` |
| `scenes/game/pieces/*.tscn` | **Speelstukken per type** (CSG): infanterist (romp+geweer), cavalerie (paardenkop), artillerie (kanon+wielen). Delen in groep `team_tint` krijgen de teamkleur + status (select/hover/dim) via `PawnView._update_material`; letter I/C/A op het Label3D erboven |
| `scenes/ui/card_hand.tscn/.gd` | Waaier: definieer + interactief koppelen |
| `scenes/ui/card_view.tscn/.gd` | Losse kaart: slimme +/− stat-herverdeling, tap-select |
| `scenes/ui/overlay.tscn/.gd` | Herbruikbaar modaal keuzescherm (difficulty/doctrine/reveal/eind) |
| `scripts/ui/instructions.gd` | **Speluitleg-tabscherm** (simpele taal): Het spel / Beurten / Eenheden / Vechten / Facties (facties-tab uit `DOCTRINE_DATA` gegenereerd). Altijd bereikbaar via de "?"-knop rechtsboven (`game._build_help_button`; pauzeert de fase-timer) en via de Speluitleg-knoppen in de menu's |
| `scripts/core/*` | Headless engine (geport, getest) |
| `scripts/ai/*` | AIController + Easy/Medium/Hard |
| `tests/*` | Testrunner + Rules/GameSession/AI/Card tests (156) |
| `tools/capture.*` | Screenshot/test-harness via CLI (zie §7) |

## 5. Gameplay-details & beslissingen

- **Slimme kaarten**: starten op 3/2/2 (7 al verdeeld). `+stat` haalt 1 weg bij de grootste
  andere stat (>1); `−stat` geeft 1 aan de kleinste andere. Totaal blijft altijd 7, elke
  stat 1..5. ("Punten over"-label verborgen; Bevestigen altijd geldig.)
- **Melee met terugslag (v4.1)**: de verdediger krijgt de volle Attack; overleeft een
  ACTIEVE INFANTERIST de melee, dan krijgt de aanvaller exact 1 schade terug
  (`Rules._resolve_melee`, test `test_retaliation_when_active_infantry_survives`).
  Bij eliminatie moet de aanvaller direct naar het vrijgekomen vak (alleen melee).
- **Stamina is opmaakbaar** (huisregel): een pion kan in meerdere beurten handelen —
  bv. 2 stappen lopen, later nog eens slaan — tot de stamina op is. Een aanval kost 1.
  De cyclus eindigt zodra niemand nog stamina + een geldige actie heeft.
- **Opstelling**: rood (P1) op rijen z=9,10; blauw (P2) op z=0,1. Havens: P1-doel z=0, P2-doel z=10.
- **Koppelen v-model**: één kaart per beurt, initiatief-winnaar begint, beurten wisselen.
  Auto-koppelaar (AI + fallback) kiest pion met "ademruimte" (niet ingeklemd).
- **Indicatoren boven pion** (3×5 blokjes, projectie via `camera.unproject_position`):
  rij 0 = HP groen, rij 1 = stamina lichtblauw, rij 2 = attack oranje, leeg = zwart.
  Blokjes staan áchter de kaarten (z-index) en dicht bij de pion (y+1.55).
- **Gedimde pionnen**: eigen pionnen die tijdens jouw actiebeurt niet kunnen (0 stamina/ingeklemd).
- **Hover-highlight**: pion licht geel op onder de muis (bij koppelen: alleen eigen ongekoppelde).
- **Beweeg-animatie**: pion glijdt (`_animate_move`, tween); `_tweening_pawns` voorkomt dat
  `_refresh_all` de positie overschrijft tijdens de animatie.
- **Pauze** (0.9s) na de laatste koppeling vóór de nieuwe definieer-ronde.
- **Stamina-kosten op tiles**: geselecteerde pion toont op elke groene zet-tile klein de
  stap-/stamina-kosten (`_highlight_move_tiles` met een Label3D per tile = pad-lengte).
- **Koppel-animatie**: pion springt kort omhoog + ring glim-flits (`_animate_link` +
  `PawnView.flash_ring`), voor beide spelers.
- **Treffer-feedback**: minivertraging → witte flits op de geraakte pion
  (`PawnView.flash_hit`) + opstijgend rood schade-label ("-2") dat vervaagt
  (`game._hit_feedback`/`_spawn_damage_float`); bij terugslag krijgt de aanvaller
  even later zijn eigen "-1". Charge-feedback wacht op de aanrij-animatie.
- **Combat feel ("Hit"-fase, Valheim-stijl)** — op het inslagmoment via `_hit_feedback`:
  witte flits (`PawnView.flash_hit`), **stagger/knockback** (`PawnView.stagger`),
  **vonken-/stofexplosie** (`_spawn_sparks`), **screen shake** (`_shake`/`_update_screen_shake`,
  dempt in ~0.2s, schaalt met impact) en **hitstop** (`_hitstop`: `Engine.time_scale`-dip
  met ignore_time_scale-timer). Impact schaalt per type (kanon > infanterieschot > melee;
  kills sterker). **Lichte ragdoll** bij dood (`PawnView.play_death`): omvallen in de
  knockback-richting + wegzinken + self-free; `_dying_views` + `_kill_view` zorgen dat
  `_refresh_all` de stervende pion niet meteen verbergt. Toetsen: **K** = screen shake aan/uit
  (motion sickness), **J** = alle combat-feel aan/uit, **M** = geluid dempen.
  Nog te doen (anticipation-fase): aim→shoot/charge-opbouw-animaties op de modellen
  (`play_attack`-hooks staan klaar).
- **Karaktermodellen per factie + kaart-archetype (juli 2026)**: elke pion toont
  na koppeling een karakter op basis van de dominante kaart-stat
  (`Constants.card_archetype`: spd/hp/atk/mix; 1/5/1 = "dunne schichtige muis").
  `PawnView.set_character(doctrine, type, card)` zoekt
  `assets/models/<factie>/<type>_<archetype>.glb` met fallback-keten archetype →
  `_base` → geometrisch stuk met archetype-silhouet (ARCHETYPE_SCALE: dun/hoog,
  breed, groot). Kale .glb's krijgen automatisch een team-gekleurd sokkeltje
  (groepen zitten niet in glTF); tint-verzameling verbreed naar GeometryInstance3D
  (CSG + MeshInstance3D). Verborgen Vos-koppelingen blijven neutraal voor de
  tegenstander tot onthulling (archetype zou de kaart verraden); eigen pionnen
  tonen hun karakter altijd. Opstellings-preview toont het factie-basismodel.
  Modellen droppen = klaar (geen code): zie **MODEL-WISHLIST.md** (16 basis-modellen
  = prio 1, 64-80 voor de volledige set; eisen: .glb, MAX 1.000 tris (low-poly
  stijl, besluit juli 2026), voeten y=0,
  neus -Z, ~0.9 hoog, optioneel AnimationPlayer idle/walk/attack/die).
- **Model-tuner (juli 2026)**: hoofdmenu → "Model-tuner"
  (`scenes/tools/ModelTuner.tscn`) — per factie/type/archetype schaal- en
  hoogte-sliders naast een referentiestuk, clip-preview-knoppen, OPSLAAN →
  `assets/models/model_tuning.json`. PawnView past die correcties toe bovenop
  de auto-fit (`model_tuning()`/`_tune_key`, sleutel volgt het geladen bestand
  incl. basis-fallback). Screenshot-hook: scene draaien met `-- shot`.
- **Animatie-varianten (juli 2026)**: `_play_variant`/`_variants_of` — clips met
  volgnummer (`idle2`, `walk3`, `die2`) worden willekeurig gekozen per
  afspeelmoment, idle/walk starten op een random punt in de clip (desync: de
  zwerm beweegt nooit synchroon). Muis-basis-glb heeft 9 clips (3 idle, 3 walk,
  attack, 2 death), samengesteld via het headless Blender-merge-script
  (scratchpad `merge_mouse*.py`; herbruikbaar per karakter).
- **Schiet-VFX (prototype)**: `_fire_projectile` — kanonskogel (groot, donker, met
  boogje) vs infanterie-tracer (klein, fel, strak), muzzle flash met OmniLight-puls
  (`_muzzle_flash`) en low-poly rookwolkjes bij loop én inslag (`_spawn_smoke`).
  De treffer-feedback wacht op de projectiel-reistijd. Bekende quirk: een dodelijk
  geraakt doelwit verdwijnt al bij vertrek van het projectiel (refresh), niet bij
  de inslag — acceptabel voor het prototype.
- **Charge-kosten in de UI**: alleen betaalbare charges (stappen + 1 ≤ stamina) worden
  rood gemarkeerd (`_compute_charge_targets`) — anders "blijft het paard staan" (bugfix).
- **Beurt-timer (20s) in ALLE fases** (`PHASE_TIME_LIMIT`, countdown in de HUD-topbalk).
  Bij 0: opstellen → standaard-opstelling (`_cancel_manual_placement`); definiëren →
  auto-bevestigd; koppelen → auto-afgemaakt (`_auto_link_human`); actiefase (mensbeurt) →
  het spel kiest greedy een zet (`_auto_action_human`, AIMedium-motor; pending Wolf-stap
  wordt overgeslagen). Timer stopt tijdens AI-beurten en pauzeert bij de "?"-uitleg.
- **Geen type-letters meer** boven de pionnen — de speelstuk-modellen tonen het type
  (`PawnView.set_unit_type` zet het Label3D leeg).
- **Geluid (SFX)**: autoload `Audio` (`scripts/core/audio_manager.gd`) met een pool van
  AudioStreamPlayers; `Audio.play(categorie, delay)` kiest een willekeurige variant uit
  `sounds/` (categorieën: cannon_fire/air/hit, musket_fire/echo/hit/cock, melee_kill/survive)
  met subtiele pitch-variatie + per-categorie volume. Alle bronbestanden zijn **WAV**
  (mp3's verwijderd — WAV = nul decode-latency + geen encoder-padding, past bij de op
  reistijd getimede inslaggeluiden). Gehaakt in `game._on_action_performed`: schot →
  musket/cannon bij afvuren, echo/whoosh kort erna, inslag-geluid getimed op de
  projectiel-reistijd; melee/charge → kill- vs. overleeft-klap. Haan-spannen
  (`musket_cock`) bij selectie van een infanterist die kan schieten.
  **Beweeggeluid per type** (in `_animate_move`): infanterie = `step` en artillerie =
  `cannon_move` via `play_footsteps` (één klap per gelopen vakje, sample cyclt vanaf
  random start, pitch per volle ronde omhoog); cavalerie = **één** `horse_move`-galopclip
  per beweging (bevat zelf al meerdere hoefslagen). NB: loop-duur schaalt met afstand
  (0.13s/vak, max 0.45s). **Selectie**: `musket_cock` (infanterie die kan schieten) /
  `horse_select` (cavalerie), `inf_select` (infanterie zonder schot), `cannon_select`
  (artillerie); `deselect` bij loslaten. Kanonschot krijgt ook `cannon_fuse` (lont-sis)
  bovenop `cannon_fire`. **Sterven** (`_death_sound`): `inf_die` (infanterie) /
  `horse_die` (cavalerie) / `cannon_die` (artillerie), ook bij dood door terugslag.
  **Overleven**: `blood_splash` bij een niet-dodelijke treffer op een levend stuk
  (inf/cav, niet artillerie). **Terugslag door een paard** (`_retaliation_sound`):
  `retaliation_horse` als de terugslaande verdediger cavalerie is (hoeven bovenop de klap).
  **UI**: `ui_click` (3 var) op knoppen/koppel-tap, `ui_hover` op overlay-knoppen,
  `ui_open` bij openen van overlay/uitleg, `ui_back` bij sluiten uitleg, `ui_toggle`
  bij tab-wissel, `ui_error` bij een pion die niet kan handelen. **Kaart-UI**:
  `card_confirm` bij bevestigen, `card_stat_up`/`card_stat_down` op de +/− stat-knoppen
  (`card_view._adjust_stat`). **Flow**: `reveal` (trommelroffel) + `initiative` (bugel, 0.6s
  later) bij de onthulling (`_on_cards_revealed`), `phase_change` bij elke nieuwe
  definitie-ronde (`_on_phase_changed`), `cycle_start` bij een nieuwe cyclus (vanaf 2,
  `_on_cycle_started`). **Opstellen**: `place_pawn`. **Beurt**: `your_turn` (uit).
  **Koppelen**: `card_deal` (uitdelen), `card_select` (tik), `link_snap` (vastklikken).
  **Charge**: `charge_yell`. **Timer**: `timer_tick` per seconde in de laatste 5 sec;
  de laatste 3 sec dezelfde tik op dubbel tempo + pitch 1.12 (`_tick_accum`) —
  `timer_warning` vervallen (bestand blijft). **Uitkomst**: `haven_score` (pion in
  haven, nog niet gewonnen), `win_fanfare`/`lose_sting` bij `_on_game_over`.
  `pawn_block` staat klaar in de bank maar heeft nog geen event.
  **Muziek & ambience** (`music/`, QOA-import 34→6,7 MB per track): aparte loop-lagen
  in de Audio-autoload (`play_music`/`play_ambient`/`stop_music`, `MUSIC_BANK`, lazy
  load; track klaar → willekeurige volgende variant). `ambient_field` (3 var, incl.
  regen, -20 dB) start bij `_ready` en loopt onder menu én spel; `music_battle`
  (2 var, -16 dB) start bij `_start_match` en stopt bij game-over zodat de sting
  ruimte krijgt. Mute (M) pauzeert ook de muzieklagen (`set_enabled` → `stream_paused`).
  De verlanglijst met ElevenLabs-prompts staat in `SOUND-WISHLIST.md`.
  Draai `--import` na een verse checkout.
- **Kijkrichting (facing)**: elke pion heeft een facing (Y-rotatie) + zichtbaar wit "neusje"
  vooraan (`PawnView._build_front_marker` + `face_dir(dir)`, front = -Z). Start: rood kijkt naar
  z=0, blauw naar z=10 (naar de vijand). Draait naar de looprichting bij bewegen en naar het doel
  bij aanvallen. Bedoeld als basis voor het latere karaktermodel (blik-/loop-animatie).

## 6. Opgeloste bugs / valkuilen (niet opnieuw intrappen)

- **Picking-bug (Jolt)**: pion-collider was `StaticBody3D`; Jolt updatet static collision NIET
  bij verplaatsen → raycast vond verplaatste pion niet → "kan niet opnieuw selecteren".
  **Definitieve fix**: geen physics meer voor picking. `_raycast_pawn` en `_pick_move_tile`
  projecteren wereldposities naar het scherm en pakken de dichtstbijzijnde (pion 44px, tegel 52px).
- **Overlappende waaier-kaarten** maakten +/− onklikbaar (buurkaart ving de klik) → genoeg
  spreiding + kaart springt naar voren op hover.
- **`_pawns_root.reparent(_board)`** met keep_global_transform gaf 5-vakjes offset → gebruik
  `reparent(_board, false)`.
- **Pion-positie** = tile-midden op hele coördinaten (`tile_position`), niet `gx+0.5`.
- **Autoload-enum als type**: `var x: Constants.Team` faalt (autoload is instance) → gebruik `int`.
- **`class_name` niet in CLI-cache** bij verse run → `var _overlay` untyped houden.

## 7. Runnen, testen, screenshots

- **Godot exe**: `C:\Users\maxni\Downloads\Godot_v4.7-stable_win64.exe\Godot_v4.7-stable_win64.exe`
  (de .exe zit ín een gelijknamige map). GODOT_PATH user-env staat hierop.
- **Spelen**: open project in Godot, F5 (main scene = `scenes/game/game.tscn`).
- **Tests**: `res://tests/TestScene.tscn` (F6 in editor, of headless CLI). Nu 156 groen.
- **CLI-workflow** (geen live editor nodig): `tools/capture.tscn` instancet game.tscn en
  saved een viewport-PNG. Run: `& $godot --path <proj> res://tools/capture.tscn -- <modus>`.
  Modi: (geen)=menu, `define`, `reveal`, `rps`, `link`, `play` (auto tot actiefase),
  `carddist` (test stat-herverdeling), `reselect`/`picktest` (picking na zet),
  `benchhard` (AI-timing), `click`. Output: `_shot*.png` in de projectroot.

## 8. AI

- Interface: `generate_cards`, `choose_placement`, `choose_link`, `choose_action`.
- **Gedeelde zero-sum evaluatie** (`AIController.evaluate(state, me)`): pionnen-in-haven ×6000,
  niet-lineaire nabijheid van de 2 dichtstbijzijnde pionnen naar BEIDE havens (= aanval +
  verdediging), bewaking van winvakjes ±320, materiaal ±32, HP ±3. `AIController` biedt ook
  `enumerate_actions` / `simulate` / `best_greedy_action`.
- **Easy**: greedy op eval, maar kiest willekeurig uit de top-3 (maakt fouten).
- **Medium**: 1-ply greedy op de eval.
- **Hard**: negamax diepte 3 + beam (14/8) op de zero-sum eval. ~400ms/zet.
- **Ultra (god mode)**: `AIUltra.gd` — iterative-deepening negamax tot diepte 5,
  beam 20/10, denktijd-budget `time_budget_ms` (2200ms) per zet; move-ordering
  hergebruikt de beste zet van de vorige diepte. Bench: `capture.tscn -- benchultra`.
  Alle niveaus delen dezelfde (geleerde) gewichten — het verschil is de zoekdiepte.
- Slimme kaarten + koppeling gedeeld: renner/slager/anker, koppel hoogste stamina op de pion
  het dichtst bij de eigen doelhaven.
- **Meten**: `capture.tscn -- sim <p1> <p2>` (AI vs AI, puur engine). `-- benchhard` voor timing.
- Historie: was "dom in alle standen" (mens won ~3 zetten). Bugs: AI verdedigde de verkeerde
  haven; Hard's negamax evalueerde vanuit vaste i.p.v. side-to-move perspectief. Nu: Hard>Medium>Easy,
  geen triviale haven-rush meer.
- **Instelbare gewichten**: `AIController.weights` (Dictionary, `default_weights()`), gebruikt in
  `evaluate`. Kunnen opgeslagen/geladen (`save_weights`/`load_weights` → `user://ai_weights.json`).
  Het spel laadt geleerde gewichten in `_setup_ai`.

## 8b. AI Trainer (self-play dashboard)

`scenes/training/Trainer.tscn` (via het difficulty-menu "AI Trainer bekijken", of F6). Draait
hill-climbing self-play en toont het live:
- **4 potjes tegelijk** (`MatchRunner` = losse GameSession-engine per potje, stap voor stap;
  `MiniBoard` tekent elke GameState top-down).
- **Spreektaal-narratie** (RichTextLabel): welke gewicht-aanpassing geprobeerd wordt en of de
  uitdager wint → nieuwe kampioen.
- **Stats** (generatie, verbeteringen, kampioen-gewichten) + snelheidsregelaar (stappen/frame) +
  pauze + "Bewaar kampioen".
- **Auto-opslaan**: bij elke kampioen-verbetering schrijft 'ie naar **`res://data/ai_weights.json`**
  (in het project → commit-baar + met de hand aan te passen). Het spel laadt dit in `_setup_ai`
  (gemerged over `default_weights()`, dus robuust). Verwijder het bestand = terug naar de defaults.
- Patstellingen eindigen na 2500 stappen met een materiaal/haven-tiebreak (`MatchRunner._tiebreak`)
  zodat de trainer signaal krijgt en sneller verbetert.
- Training gebruikt Medium (snel); geleerde gewichten helpen ook Hard (gedeelde eval).
- **Pool van oude kampioenen** (`_pool`, incl. baseline): de uitdager speelt tegen een mix →
  geen overfit op één stijl. `GAMES_PER_GEN=8` (balans snelheid/betrouwbaarheid; 4 borden = steekproef).
  Adoptie alleen bij **marge** `ADOPT_MARGIN=2` (uitdager ≥2 potjes verschil → geen geluk).
- **Tiebreak** (`MatchRunner._tiebreak`): materiaal → haven → haven-nabijheid, zodat patstellingen
  bijna nooit gelijk eindigen (anders geen leersignaal).
- **Kracht-grafiek** (`TrainGraph`): kampioen vs baseline-gewichten (gestapelde eval-batch,
  `_start_eval`/`_finish_eval`) → stijgende lijn boven 50% = echt sterker geworden.
- **Balansmeting opgeslagen (juli 2026)**: `arena.bat` (`capture.tscn -- arena [potjes]
  [level]`) speelt alle 36 doctrine-richtingen parallel en schrijft een winrate-matrix
  "wie wint tegen wie" + ranglijst naar `data/arena_results.txt` (MatchRunner.max_steps=600
  voor snelle metingen). De headless trainer schrijft per factie de winrate tegen elke
  tegenstander naar `data/matchup_<factie>.txt`. Zo kun je na een run meten en bijstellen.
- **Nachtrun 8u × 6 processen (juli 2026) — balansbeeld uit `data/matchup_*.txt`**:
  Leeuw dominant (90-99% tegen alles, 61% vs Beer), Vos sterk all-round (127 adopties
  in 151 gens), Beer sterk, Wolf middenmoot (~25% tegen de top-3), Mens zwak,
  **Muis kapot: 3-14% tegen alles, 1 adoptie in 80 gens** — ondanks de +1 Speed-perk.
  Kanttekening bij de getrainde gewichten: Leeuw/Beer/Vos hebben na 90+ adopties
  gedegenereerde grootte-ordes (bv. Leeuw `hp`=112k vs `haven`=63; Beer `haven`=1.2M,
  `cav_value`=846k) — multiplicatieve mutatie + hoge adoptiegraad laat de schaal
  exploderen. De eval is relatief dus het "werkt", maar de onderlinge ratio's zijn
  extreem gedrift. **→ Opgelost in trainer v2** (zelfde dag): (1) schaal-anker
  `AIController.renormalize_weights()` na elke recombinatie én bij het laden
  (gedrag-neutraal, eval is lineair); (2) dubbele verify-gate — 2×games, helft vs
  kampioen, helft vs vaste baseline, marge op totaal én geen verlies per helft
  (oude gate liet ~34% ruis door); (3) gepaarde vergelijking — alle kandidaten spelen
  hetzelfde tegenstander-schema met gebalanceerde facties; (4) sigma-cap 0.35 +
  stap-limiet 900 per trainingspotje. Zie AI_TRAINING_PLAN.md "Robuustheid v2".
- **Facties-curriculum + per-factie-profielen (juli 2026)**: de kampioen is een PROFIEL —
  per doctrine een eigen set van 31 gewichten: evaluatie (15) + opstelling (6:
  `art/cav/inf_front/center`, via `choose_placement`) + type-bewust koppelen (10:
  `aff_<type>_<stat>` + `link_advance`). Elke generatie muteert één factie; de uitdager
  speelt die factie (signaal!), de tegenstander krijgt een willekeurige factie. De
  kracht-grafiek meet op een vaste rotatie van 4 matchups. Opslag:
  `AIController.save_profile`/`load_profile` → `data/ai_weights.json` (per-doctrine;
  oud plat formaat wordt herkend). Het spel laadt de set van de AI-doctrine (`_setup_ai`).
  Mini-borden tonen types: ● soldaat, ▲ paard (punt naar de vijand), ▮ kanon + legenda.
- **"Train de AI"-knop = `train_ai.bat`** (projectroot): dubbelklik = 60 min headless
  CMA-lite-training zonder dashboard (`train_ai_nacht.bat` = 8 uur). Ctrl+C mag altijd —
  elke adoptie is al opgeslagen. CLI: `capture.tscn -- train [minuten] [pop] [games] [factie]`.
  Kandidaten spelen parallel (1 thread per kandidaat; MEER threads bleek averechts —
  allocator-contentie). Tegenstander-pool tegen rondjes draaien (potje 0 = baseline,
  1 = kampioen, rest = oude kampioenen). Mutatie/recombinatie zijn TEKEN-behoudend
  (bugfix: negatieve flankvoorkeuren werden naar +0.01 geklemd).
- **64-cores-route: `train_ai_parallel.bat`** — start 6 processen, één per factie; elk
  schrijft een eigen override (`data/ai_weights_f<d>.json`), `AIController.load_profile`
  merget die automatisch over het hoofdbestand (geen schrijfconflicten). Inspectie van
  het actieve profiel: `capture.tscn -- showweights`. Het dashboard (`Trainer.tscn`)
  blijft voor live meekijken (hill-climbing).
- Zie `AI_TRAINING_PLAN.md` voor de bredere roadmap (dit is Fase A+B).

## 9. TODO / volgende stappen

- [x] ~~REGELS v4.1 IN DE ENGINE~~ — **gedaan**, zie §2b. Resterende v4.1-gaten:
  - [x] **Vrije opstelling UI**: gedaan — "Zelf opstellen" in het opstellingsmenu:
        plaats het schaarste type eerst (kanonnen → paarden, klik op cyaan gemarkeerde
        thuisvakken, rechtermuis = ongedaan); infanterie vult automatisch aan (voorste
        rij, centrum eerst). Previews via losse PawnViews; engine-validatie bij submit.
        **Ghost-voorvertoning**: een semi-doorzichtig stuk van het huidige type volgt
        de muis over de vrije vakken (`_update_placement_ghost(_type)`; transparant
        teammateriaal op alle CSG-delen, schaduw uit).
        AI's plaatsen zichzelf via `choose_placement` (ook in sims/Trainer).
        Test: `capture.tscn -- placetest`. Doctrines met lege vakken (Leeuw) laten de
        rest van de thuisrijen automatisch leeg.
  - [ ] **Vos-informatie echt verbergen**: `pawn.card_revealed` wordt bijgehouden, maar
        de UI toont de stat-blokjes van ALLE actieve pionnen en de AI leest de volledige
        state (vals spelen). Voor mens-vs-AI met een Vos-AI zou de UI vijandelijke
        gedekte stats moeten maskeren; de AI-kant vergt een info-set-model.
  - [ ] **Engine-flags `vuurRaaktInactief`/`vuurGeblokkeerd`** (balansknop §8 v4.1):
        nu hard aan/aan volgens spec; als flags inbouwen zodra het selfplay-harnas
        het boogvuur-alternatief (uit/uit) moet kunnen meten.
  - [ ] **AI-eval verfijnen voor v4.1**: `_is_killable` kent alleen melee-dreiging
        (geen schoten/charges); artillerie-posities (schootsveld) worden niet gewogen;
        koppel-strategie is nog type-blind (kaart × type is juist de v4.1-kern).
  - [ ] **Playtest-agenda §8 van de regels** draaien via sims/Trainer per matchup
        (21 matchups); meet vooral standoff/verlamming en de 1/5/1-oogstmachine.
- [ ] **AI verder tunen / trainen** — nog te makkelijk te verslaan (§8). Zie **`AI_TRAINING_PLAN.md`**
      voor het gefaseerde bouwplan: self-play infrastructuur → eval-gewichten tunen via self-play
      (aanbevolen start) → MCTS → deep-RL (godot_rl_agents). Snelle korte-termijn-ideeën: diepere
      search voor Hard, mens-rush zwaarder straffen, betere koppel-strategie.
- [ ] **Karaktermodel** — de blokjes zijn vervangen door gestileerde CSG-speelstukken per
      type (`scenes/game/pieces/`); echte geanimeerde modellen (.glb via `model_scene`,
      kijk-/loop-/aanval-animaties op `face_dir`) blijven een latere upgrade.
- [ ] **Aanval-animatie** (hit-flash / bounce / screen shake bij een treffer).
- [ ] "AI denkt…"-feedback duidelijker maken (nu vrijwel instant).
- [ ] Geluid + eventueel echte sprites (i.p.v. gekleurde blokken).
- [ ] Camera-/board-thema polijsten (tile-kleuren, WorldEnvironment/ambient).
- [x] ~~`main.tscn` opschonen en README updaten naar 3D-realiteit~~ — gedaan: main.tscn
      bestond al niet meer, README herschreven, GAME_LOGIC_OVERVIEW.md verwijderd,
      `_shot*.png` opgeruimd + in .gitignore.
- [ ] **ONLINE PLAYTESTEN — volledig plan in `ONLINE-PLAYTEST-PLAN.md`** (juli 2026):
      Fase 0 (offline voorwerk: reveal-UI met tegenstander-kaarten, camera-flip voor P2,
      submit_doctrine/submit_resign/cycluslimiet in de engine, per-speler view-filter +
      snapshot-serializer, Vos-"?"-UI, touch-knoppen, web-export-spike) → Fase 1
      (WebSocket + JSON, headless server op de DO-droplet, rooms = GameSession-instanties,
      device-token reconnect) → Fase 2 (lobby-lite, quick-match, playtest-telemetrie
      gekoppeld aan spelregels §8, feedback-knop, server-AI max Medium) → Fase 3
      (Glicko-2 + SQLite, leaderboard, matchmaking, seizoenen, rematch) → Fase 4
      (dichttimmeren: leak-canary, replay-verificatie). Schatting Fase 0+1: 60-90 uur.
- [ ] Export-presets (Android AAB, Web, iOS) — later.

## 10. Open ontwerpvragen (wachten op keuze)

Beantwoord door `spelregels-v4.1.md` en de implementatie:

- **Tiebreak-methode**: opgelost — RPS is verwijderd; deterministisch bod → Speed-bod →
  C1/R1: P1, anders vorige initiatiefhouder (`Rules.compute_initiative`). De RPS-fases
  staan nog ongebruikt in `Phase.Type` (opruimen mag).
- **Wederzijdse aanvalsschade**: opgelost — terugslag (§3.1 v4.1), geïmplementeerd.
- **Start-verdeling kaarten**: opgelost — `CardData.reset_stats()` verdeelt het
  doctrinebudget (7→3/2/2, 5→2/2/1, 9→3/3/3; Beer-speedcap → overschot naar HP).
- **Balansknoppen v4.1 §8**: bewust nog níét in de regels (standbeeld-drempel, cumulatieve
  havenscore, per-stat cap, …) — beslissen via selfplay/playtests, agenda staat in de regels.
