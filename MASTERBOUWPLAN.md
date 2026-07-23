# Fog of War — MASTERBOUWPLAN

> **Wat is dit:** het uitvoerbare bouwplan dat `fog-of-war-bouwplan-godot-v1.md` (campagne, AI & meta)
> verbindt met de bestaande codebase. Gebaseerd op een volledige code-nulmeting (juli 2026): alle
> subsystemen zijn doorgelicht en naast het bouwplan gelegd; het plan zelf is daarna adversarieel
> geverifieerd op feiten, dekking en uitvoerbaarheid.
> **Hoe te gebruiken:** elke fase bestaat uit genummerde stappen (F0.1, F0.2, …). Elke stap heeft een
> doel, concrete bestanden, implementatiedetail en een **CHECK**. Checks zijn door Claude Code headless
> uit te voeren; waar een menselijke speelsessie nodig is staat dat expliciet als **MAX:**-onderdeel.
> Een stap is pas af als de CHECK groen is én de bestaande testsuite groen blijft. Vink af in dit document.
>
> **Let op:** de fasenummers van dit masterplan wijken af van bouwplan §12 (er is een fase tussengevoegd).
> De mapping staat in de overzichtstabel (§3).

---

## 0. Werkafspraken (gelden voor élke stap)

- **Godot:** gebruik `$env:GODOT_PATH`; **is die leeg** (verse shell), val terug op
  `C:\Users\maxni\Downloads\Godot_v4.7-stable_win64.exe\Godot_v4.7-stable_win64.exe` (zelfde patroon als
  arena.bat r18-19). Eénmalig persistent zetten mag: `setx GODOT_PATH "<pad>"`.
- **Regressienet:** `& $godot --headless --path . res://tests/TestScene.tscn` — exit 0 = groen.
  Draait na elke stap; de suite groeit per stap mee. Huidige nulstand: **111 tests / ~310 asserts**
  (Rules 67, GameSession 24, Card 9, AI 11).
- **Rooksignaal UI:** `& $godot --headless --path . res://tools/capture.tscn -- play` (auto tot
  actiefase + screenshot) — bewijst dat de 3D-client nog speelt na een core-wijziging.
- **Sim-signaal:** `... res://tools/capture.tscn -- sim medium hard muis leeuw` — volledige partij, print winnaar.
- **Nooit de .bat's aanroepen in checks** (`arena.bat`/`train_ai.bat` eindigen met `pause` en hangen
  headless): draai altijd het onderliggende capture-commando direct (bv. `-- arena 20 medium`).
- Elke afgeronde stap: WIP.md bijwerken + commit met stapnummer in de message (`F0.3: validator.gd`).
- **Regelwijziging = bewuste beslissing:** breekt een wijziging een golden replay (vanaf F0.7), dan hoort
  daar een versie-bump in `rules_version` bij + een regel in `docs/spelregels-CHANGELOG.md`.
- Nieuwe core-bestanden: Engelse identifiers, Nederlands commentaar (bestaande stijl).

---

## 1. Nulmeting — bouwplan naast de code

Per bouwplan-onderdeel: wat er al staat, wat er mist. Status: ✅ = staat er, 🟡 = deels, ❌ = ontbreekt.

| Bouwplan-onderdeel | Status | Wat er al is | Wat er mist |
|---|---|---|---|
| **MatchCore puur (§2.1)** | 🟡 | `GameState`/`Pawn`/`Card`/`Phase`/`Rules` zijn al RefCounted en Node-vrij; `Rules.gd` is de facto validator+mutator (statisch, puur); alle mutaties lopen door de per-speler gevalideerde `submit_*`-API | `GameSession` (fasemachine) is een Node-autoload met signals; geen `apply(state, action) → events`; fase-overgangen/beurtwissel zitten in GameSession i.p.v. een reducer |
| **actions.gd (§2.1)** | ❌ | Actie/result-dicts in `action_performed` dragen ~90% van de benodigde event-velden al | Geen actietypes, geen JSON-schema, geen (de)serialisatie; string-dispatch op ±6 plekken in 4 bestanden (game.gd 3×, match_runner.gd, AIController.simulate, AIHard._quick) |
| **validator.gd** | 🟡 | `Rules.get_valid_*` is herbruikbare legaliteit | Fase/beurt/eigendom-checks zitten inline in `GameSession.submit_*`; geen één `is_legal(state, action, player)` |
| **view.gd / fog (§2.1)** | ❌ | Verborgen info zit wél in het model (`cards_defined` per speler, `Pawn.card_revealed` voor Vos) | Geen `get_view(player)`; UI toont alle stats (ook gedekte Vos), AI leest de volle staat (cheat), `state_updated` broadcast alles |
| **rules_config (§2.4)** | ❌ | Knoppen bestaan als `const` in Constants + `DOCTRINE_DATA` is al data-gedreven | Niets is per match instelbaar; §8-flags (`vuurRaaktInactief` etc.) bestaan niet; arena kan geen config-sweeps doen |
| **Event sourcing (§1)** | ❌ | Spellogica + AI zijn deterministisch op `AIEasy.gd:14` na (audio/VFX gebruiken bewust de globale RNG — presentatie; de trainingslaag loot ook nog globaal) | Geen append-only log, geen fold, geen replay; signals zijn vluchtig |
| **serializer/zobrist** | 🟡 | `Pawn`/`Card` hebben `to_dict`/`from_dict`; `GameState.clone()` bestaat | `GameState` heeft geen to/from_dict; `clone()` breekt kaart-identiteit (bekend risico 7 uit het online-plan); geen state-hash |
| **SeededRng (§2.3)** | ❌ | Zie event sourcing-rij: bijna alles is al deterministisch | Geen seedbare RNG; AIEasy, trainer en arena loten op de globale RNG |
| **Klokken in de staat** | ❌ | 20s-fasetimer client-side in game.gd, met timeout-fallbacks per fase | Niets in de staat, niet server-verifieerbaar; `acknowledge_reveal()` heeft geen player_id (single-ack-gat) |
| **CampaignCore (§2.2)** | ❌ | — | Volledig greenfield; ook de campagne-spec zelf ontbreekt als document in de repo |
| **AI L0–L4 (§7)** | 🟡 | Easy/Medium/Hard/Ultra op één gedeelde, leerbare eval (31 gewichten/doctrine, getraind); kaartgeneratie/opstelling/koppeling ook gewichten-gestuurd | Geen echte L0 (random); agents zien de volle staat i.p.v. views; geen campagne-agent (`decide_campaign`); search kent geen fasegrenzen/Wolf-stap |
| **Arena (§8)** | 🟡 | Arena-modus (36 richtingen, winrate-matrix), CMA-lite-training + dashboard-trainer, tiebreak, per-factie parallel | ~0,13 match/s/proces ≈ **factor 40 onder** het ≥5/s/core-doel; geen metrics-JSON per game (§8.2-mapping), geen seeds (metingen zijn schijn-precies: deterministische partijen 20× herhaald), geen dashboard, geen fuzz; alles zit in de 1300-regel `capture.gd` |
| **Backend/netwerk (§5)** | ❌ | `ONLINE-PLAYTEST-PLAN.md` (uitgewerkt maar 0 code); MatchRunner bewijst N sessies/proces (= rooms) | Geen server/-map, geen protocol, geen accounts, geen resign/remise/cycluslimiet in de engine |
| **Solo-campagne (§6)** | ❌ | Sterke bot-basis (zie AI) | Geen CampaignCore, geen SoloDriver, geen persoonlijkheden/barks, geen campagne-UI |
| **Meta (§9)** | ❌ | — | Glicko/seizoenen/leagues/leaderboards/matchmaking: alles nog papier |
| **Tests (§11)** | 🟡 | Eigen headless runner met exit-codes (CI-klaar); 111 tests / ~310 asserts (waarvan 67 Rules-tests); alle regels van v4.1-hr gedekt | Geen serialisatie-, replay-, determinisme-, view-lek- of campagne-tests; geen CI-pipeline; tests gebruiken privé-API's (`_spawn_pawn`) |
| **Client/UI (§4)** | 🟡 | Volledige 3D mens-vs-AI-loop met opstelling/kaarten/koppelen/combat-feel/SFX/muziek; mobile-portrait viewport | game.gd = 2381-regel monoliet die beide kanten speelt; hardcoded P1-perspectief; geen touch-knoppen voor rechtermuis-acties; geen render-vanaf-snapshot; campagneschermen bestaan niet |
| **Assets** | 🟡 | Model-pipeline bewezen end-to-end (Muis-infanterie 100% af incl. gibs/gore/team-textures); geluid vrijwel compleet | Overige facties/archetypes door de pipeline (loopt parallel, blokkeert dit plan niet) |

### 1b. Vijf bevindingen die het plan sturen

1. **De engine is al bijna multiplayer-klaar** — de audit-conclusie uit het online-plan klopt: per-speler
   gevalideerde `submit_*`-API, deterministische kern, MatchRunner draait N sessies in één proces. F0 is
   dus een *refactor met vangnet*, geen herbouw.
2. **"v4.2" bestaat nergens als document, maar half wél als code.** De huisregels in de engine zíjn
   grotendeels de v4.2-concepten uit het bouwplan: type-afhankelijke terugslag {inf 1, cav 2, art 0} =
   "universele terugslag {basis 1, ruiter 2}"; opmaakbare stamina + vaste kanondracht = de kern van het
   "stamina-kanon". Daarbovenop zitten drie **ongedocumenteerde** afwijkingen: infanterieschot doet volle
   Attack (doc zegt Attack−1), Muis heeft comp [20,0,2] (doc zegt 22/0/0), en Mens/Vos heten in-game
   Varken/Krokodil. → F0.0 legt de geïmplementeerde werkelijkheid vast als spec vóór de refactor.
3. **De grootste regel-delta voor de campagne is de economie:** CP (inzet, verdienen, verbranden),
   pionnen-pools in de match en de SPAWN-fase per cyclus bestaan in geen enkele vorm. Zonder die laag kan
   geen enkele campagneregel (donaties, testament, poolfactor) werken. → eigen fase F2.
4. **Twee plannen spreken elkaar tegen op de backend:** het online-plan koos "headless Godot-server met
   rooms + SQLite op de droplet"; het bouwplan kiest "Node+MySQL+Redis met Godot-workers" (n8n is
   geschrapt, zie B5). Het
   masterplan volgt **het bouwplan** (de campagne/meta-laag heeft de Node-stack echt nodig); alle
   engine-/clientwerk uit online-plan Fase 0 blijft geldig en is in F0/F4 opgenomen. De droplet blijft de
   deploy-machine.
5. **De arena is factor ~40 te traag** voor het meetprogramma (0,13 vs ≥5 matches/s/core) en de metingen
   zijn schijn-precies (deterministische partijen 20× herhaald ≈ n=1 per matchup). De F0-refactor
   (RefCounted core, geen signals in de hot loop, seeds voor variatie) is tegelijk het herstelplan van de
   arena.

---

## 2. Vastgelegde architectuurbeslissingen

| # | Beslissing | Rationale |
|---|---|---|
| B1 | **MatchCore in GDScript, RefCounted, geen Nodes.** C# alleen als de arena na F1-optimalisatie nog piept (dan alléén reducer/validator, achter dezelfde interface, golden replays bewijzen gelijkheid). | Bouwplan §0/§14.4; de kern is al bijna Node-vrij. |
| B2 | **`apply()` muteert in-place; de aanroeper kloont indien nodig.** Signatuur `Reducer.apply(state, action, player_id) -> {ok, events, error}`; "puur" betekent hier: geen Nodes, geen signals, geen globals, deterministisch. | Een copy-per-zet in GDScript maakt de ≥5/s/core-eis onhaalbaar; AI/arena clonen nu ook al zelf. |
| B3 | **GameSession blijft tijdens F0 bestaan als dunne compat-shim** (autoload, zelfde signals, zelfde `submit_*`-signaturen) bovenop MatchCore. game.gd en de bestaande tests blijven daardoor vrijwel ongewijzigd draaien; de shim krimpt per stap. | De 2381-regel driver en 3 testsuites zijn het vangnet — dat gooi je niet weg middenin de verbouwing. |
| B4 | **Regelversie-lijn:** `4.1.9-hr` = de huidige geïmplementeerde huisregels (vastgelegd in F0.0) → `4.2.0` = + CP/pools/spawn/kanon-act (F2). Elke match slaat `rules_version` + volledige `rules_config` op. | Bouwplan §0 "regelversies zijn heilig". |
| B5 | **Backend = Node (Fastify) + MySQL + Redis; Godot headless workers valideren matches** (bouwplan §1/§5). **GEEN n8n of andere workflow-automation-tooling (besluit Max, juli 2026):** alle geplande jobs (nachtruns, digests, seizoenswissel, e-mail-fallback) zijn gewone code — node-cron in de backend of systemd-timers/Taakplanner. Capaciteitsaanname uit §5.3 geldt: één 4-core VPS ≈ duizenden campagnes, bottleneck = push-notificaties — dus géén premature schaal-architectuur; schalen = workers bijstarten. Online-plan Fase 0-items verhuizen naar F0 (engine) en F4 (client); de "room = sessie-instantie"-vondst wordt het worker-model. | Campagne, ledgers, deadlines, notificaties en cron-jobs horen niet in een Godot-proces. |
| B6 | **Solo-campagne draait lokaal; de server her-valideert het event-log bij sync** (bouwplan §14.1, voorstel overgenomen). Implementatie: F4.5. | Goedkoopste milestone, geen netwerkvariabelen; vals spelen offline levert geen online punten op. |
| B7 | **Ranked 1v1 gaat open vanaf F4** als aparte snelle queue en regelversie-testbed, mét consent-vlag voor A/B op rules_config (§9.4/§14.2). **Bot-backfill zichtbaar 🤖** (§14.3). | Vertrouwen > vullingsgraad; 1v1 is ook het A/B-kanaal voor rules_config. |
| B8 | **Agents krijgen views, niet de staat.** De agent-interface (F1.1) is `decide(view, legal, rng)`; een expliciete `full_state`-vlag houdt de oude (valsspelende) eval beschikbaar zodat het Vos-effect meetbaar wordt (ablatie). | Bouwplan §7.1; lost meteen het "AI kijkt door de fog"-gat op. |
| B9 | **Naamgeving:** enum-namen (MENS/VOS) blijven; presentatienamen (Varken/Krokodil) blijven in `DOCTRINE_DATA.name`; nieuwe bestanden volgen bouwplan-namen (`state.gd`, `reducer.gd`, …) in `res://core/`. Dode RPS-code wordt in F0.0 verwijderd. | Twee vertaallagen bestaan al; saneren ≠ hernoemen wat werkt. |
| B10 | **Arena-data leeft in jsonl-bestanden** (`results/`), niet in de `arena_runs`/`arena_games`-MySQL-tabellen uit bouwplan §5.1 — die tabellen komen pas als F7-rapportage ze echt nodig heeft. | De arena draait (F1) vóór er een database bestaat (F4); bestanden zijn gratis reproduceerbaar en diff-baar. |
| B11 | **Imperfecte informatie in L2/L3:** F1 start met een puntschatting (verwachtingswaarde over de onthulde kaartenset) voor onbekende Vos-stats; het bouwplan-§7.2-model (determinized sampling N=16) is een expliciete upgrade-stap zodra de arena aantoont dat de puntschatting L3 merkbaar zwakker maakt (F8, eerder mag). | Sampling ×16 vermenigvuldigt de rekentijd; eerst meten of het nodig is. |
| B12 | **Client-telemetrie = het server-event-log** (acties, think_ms, uitkomsten); er komt géén apart `Telemetry.gd`-autoload in v1. De **web-replay-viewer** uit bouwplan §3 schuift naar F8 (client-replay + `-- replay` dekken de behoefte tot die tijd). | Event sourcing ís de telemetrie (bouwplan §1); geen dubbele meetlaag bouwen. |

**Doelstructuur in de repo** (groeit per fase; bestaande mappen blijven tot hun vervanger af is):

```
res://core/match/     state.gd  actions.gd  validator.gd  reducer.gd  view.gd
                      rules_config.gd  serializer.gd  match_log.gd  zobrist.gd
res://core/campaign/  cstate.gd  cactions.gd  creducer.gd  cview.gd  crules.gd
res://core/shared/    seeded_rng.gd
res://agents/         agent.gd  l0_random.gd  l1_greedy.gd  l2_weights.gd  l3_search.gd
                      campaign/  (campagne-agents + persoonlijkheden, F3)
res://arena/          arena.tscn  run.gd  metrics.gd  fuzz.gd  arena_configs/
res://net/            net_client.gd  event_stream.gd  offline_queue.gd  (F4)
res://ui/screens/     (campagne-schermen F3; lobby/online F4; leaderboard/profiel F6)
server/               Node-backend: api/ ws/ workers/ jobs/ db/  (F4; jobs = node-cron, geen n8n)
docs/                 spelregels-v4.2.md  campagne-spec.md  protocol.md  spelregels-CHANGELOG.md
tests/                unit-suites  golden_replays/  fuzz/
```

---

## 3. Faseplan — overzicht

| Masterplan-fase | = bouwplan | Inhoud | Acceptatie (hard criterium) |
|---|---|---|---|
| **F0 — Core-extractie** | F0 | MatchCore puur: rules_config, actions, validator, reducer, serializer, view, event-log, SeededRng, zobrist, klokken/resign/remise; GameSession → shim | 10 opgenomen partijen replayen byte-identiek; view-lektest groen; UI speelt ongewijzigd; alle tests groen |
| **F1 — Arena v1** | F1 | Agent-interface op views, L0–L3, standalone runner, metrics per §8.2, throughput ≥5/s/core, fuzz, dashboard, nachtjob, eerste balanspatch | Winrate-matrix 21 matchups mét metrics-JSON; ≥5 matches/s/core aangetoond; balanspatch (Muis) op data |
| **F2 — Regels v4.2** | *(nieuw)* | CP-economie in de match (BET_CP), pionnen-pool + CYCLE_SPAWN/RESET, SPAWN, kanon-actiepot (CANNON_ACT), agents leren de nieuwe acties, arena-hermeting; `spelregels-v4.2.md` definitief | v4.2-config speelt end-to-end in arena én UI; alle v4.1-hr golden replays blijven groen onder hun eigen config |
| **F3 — Solo-campagne** | F2 | campagne-spec definitief, CampaignCore (raad/stemmen/donaties/testament/burgeroorlog/CP-ledger), SoloDriver + 15 persoonlijkheden, campagne-UI, barks, offline | Volledige solo-campagne speelbaar begin→kampioen zonder netwerk; campagne-log replayt deterministisch |
| **F4 — Online duels** | F3 | Node-backend, accounts (gast + upgrade), REST+WS, Godot-workers, server-klokken/forfeit, reconnect, ranked 1v1, replays, solo-sync; client LocalSession/RemoteSession, camera-flip, render-from-snapshot, web-spike | 2 clients spelen een duel uit met vliegtuigstand-test halverwege; leak-canary in CI groen |
| **F5 — Online campagne** | F4 | Rounds/raad/deadlines server-side, donaties/testamenten, teamchat+quick-chat, spookmodus, push-notificaties, live-8 + async-16 | 8 testers spelen een live-event < 90 min; async-campagne overleeft 3 no-shows via defaults |
| **F6 — Meta** | F5 | Glicko-2, seizoenen/leagues, leaderboards + drama-borden, matchmaking + 🤖-backfill, commend/report, moderatie | Eerste publieke seizoen draait |
| **F7 — Campagne-arena** | F6 | 16-bot-campagnes headless, campagnegewichten-evolutie, formatmetrieken, config-sweeps | Poolfactor & CP-tabel vastgesteld op data |
| **F8 — Optioneel** | F7 | L4 neuraal, determinized sampling (B11), C#-acceleratie, web-replay-viewer, toeschouwersmodus, cosmetica | — |

**Volgorde-rationale** (bouwplan §12 blijft geldig): F1 vóór alles met mensen — bots vinden regelbugs
gratis. F2 vóór F3 — de campagne staat op de v4.2-economie. F3 vóór F4/F5 — de campagne-loop bewijzen
zonder netwerkvariabelen. F7 ná F5 — campagne-arena heeft de definitieve campagneregels nodig.
Het asset-spoor (modellen/geluid per MODEL-WISHLIST) loopt parallel en blokkeert niets.

---

## 4. FASE F0 — Core-extractie

Doel: het bestaande spel wordt een pure, serialiseerbare, replaybare MatchCore zonder gedragswijziging.
Elke stap laat de volledige bestaande testsuite + de UI groen.

### ☑ F0.0 — Specs vastleggen + dode code opruimen — AF (juli 2026)

**Doel:** de geïmplementeerde werkelijkheid wordt de spec; de refactor krijgt een vast referentiepunt.

**Werk:**
1. `docs/spelregels-v4.2.md` (concept) schrijven met twee delen:
   - **Deel A — "4.1.9-hr", de huidige engine-regels** (uit `Rules.gd`/`Constants.gd`, niet uit het oude
     doc): opmaakbare stamina (stap 1 / melee 1 / schot 1 / charge stappen+1; terugslag & Wolf-stap
     gratis), artillerie 1 actie/beurt met vaste dracht 6 (+1 Leeuw) en dode zone 1, infanterieschot
     afstand exact 2 met **volle** Attack, terugslag {inf 1, cav 2, art 0}, cav springt over eigen
     pionnen (Wolf-cav ook over vijandelijke inf), Muis +1 Speed doctrine-breed, Vos-cav +1 Speed,
     doctrine-comps zoals `DOCTRINE_DATA` (**besluit Max juli 2026: Muis wordt [18,4,0]** — het BIG
     BRO-besluit van 6 juli wordt in F0.0 doorgevoerd, arena-hermeting in F1.6; zie §15.1),
     presentatienamen Varken/Krokodil, beschieting raakt óók inactieve pionnen en elimineert
     standbeelden ongeacht HP (Rules.gd get_valid_shot_targets + apply_shot — de basis onder F0.2's
     `fire_hits_inactive`/`statue_threshold`-knoppen).
   - **Deel B — "4.2.0", de campagne-uitbreidingen** (concept, uit bouwplan §2.1/§2.4): CP-inzet
     (`BET_CP{0..3}`, cap +1 per kaart), pionnen-pool + spawnfase (`SPAWN` ≤3 per cyclus), kanon-actiepot
     (`CANNON_ACT{ROLL|SHOOT|RETREAT}`), klokken. Markeer elk punt "TE BEVESTIGEN".
2. `docs/spelregels-CHANGELOG.md` starten (eerste entry: 4.1.9-hr codificatie, incl. de drie stille
   afwijkingen t.o.v. spelregels-v4.1.md).
3. Dode code weg: `Phase.Type.SETUP_*_RPS` + `is_rps`/`rps_for_round`, de `needs_rps`-parameter van
   `cards_revealed_event`. Doc-opruiming: `choose_rps` schrappen uit de interfacebeschrijving in WIP.md
   §8 (staat alleen dáár, niet in code).

**CHECK:** tests groen; `grep -ri "rps" scripts/ tests/` levert 0 treffers; beide docs bestaan.

### ☑ F0.1 — SeededRng: het laatste beetje niet-determinisme eruit — AF (juli 2026)

**Bestanden:** `core/shared/seeded_rng.gd` (nieuw), `AIEasy.gd`, `match_runner.gd`, `capture.gd`, `trainer.gd`.
(`audio_manager.gd` en `pawn_view.gd` blijven bewust op de globale RNG — presentatie hoeft niet
reproduceerbaar te zijn.)

**Werk:** `SeededRng` (RefCounted, wrapper om `RandomNumberGenerator` met seed in `_init`; api:
`randi_range`, `randf`, `randf_range`, `pick(array)`, `shuffle(array)`, `fork(label)` voor sub-streams).
`AIController` krijgt een `rng: SeededRng`-veld (default vaste seed); `AIEasy` gebruikt die i.p.v.
`randi()`. MatchRunner krijgt `seed` in `_init` en seedt beide agents; trainer/arena leiden seeds af van
`(run_seed, game_index)` — daarmee vervalt ook de "randi mag alleen op de main thread"-beperking in
capture.gd. De sim-CLI krijgt een seed-argument: `-- sim <p1> <p2> <d1> <d2> [seed]`, doorgegeven aan
beide agents (nodig voor de F0.4-checks).

**CHECK:** nieuwe test: 2× dezelfde sim met zelfde seed → identieke winnaar/cycli/actie-telling; 2×
verschillende seed met AIEasy → verschillend verloop. Grep (breed patroon!):
`grep -rEn "\brandi\b|\brandf\b|randi_range|randf_range|randomize\(|pick_random|\.shuffle\(" scripts/core scripts/ai scripts/training`
→ 0 treffers buiten `seeded_rng.gd` en `audio_manager.gd`.

### ☑ F0.2 — rules_config.gd: alle knoppen worden data — AF (juli 2026)

**Bestanden:** `core/match/rules_config.gd` (nieuw), `arena/arena_configs/v41_default.json` (nieuw),
`GameState.gd`, `Rules.gd`, `Constants.gd`, `Card.gd`.

**Werk:** `RulesConfig` (RefCounted) met `to_dict`/`from_dict`/`defaults()` en velden:
`rules_version`, `rounds_per_cycle`, `pawns_in_haven_to_win`, vuurmodel (`fire_hits_inactive`,
`fire_blocked` — nu écht geïmplementeerd in `get_valid_shot_targets`, incl. het uit/uit-boogvuuralternatief,
plus `inf_shot_over_pawn` — de §2.4-knop "infanterieschot over één pion", default false),
`statue_threshold` (standbeeld-drempel, default 0), `haven_score_cumulative` (default false — telt
"touches" i.p.v. gelijktijdige aanwezigheid), `per_stat_cap` (0 = uit), schotparameters
(`inf_shot_range/cost`, `inf_shot_full_attack`, `art_min_range/range/move/shot_cost`),
`retaliation {inf, cav, art}`, `stamina_model` ("pool" | "one_action" — de v4.1-doc-variant als knop),
`cycle_limit` + `tiebreak` (materiaal→haven→nabijheid, uit MatchRunner overgenomen), `clock {bank_sec,
increment_sec, reconnect_grace_sec}`, `doctrines` (override op `DOCTRINE_DATA`), en een `campaign`-blok
(cp/pool/spawn/cannon, default null → v4.1-gedrag). `GameState` krijgt `rules: RulesConfig`; alle
`Constants.<knop>`-reads in `Rules.gd`/`Card.is_valid_stats` gaan via `state.rules`. Constants houdt
enums, havens/geometrie en presentatiehelpers. Deze stap schrijft zelf het eerste configbestand:
`arena/arena_configs/v41_default.json` = `RulesConfig.defaults().to_dict()` (F1.2 breidt die map uit).

**CHECK:** tests groen met `RulesConfig.defaults()` (= gedrag exact als nu). Nieuwe tests: (a)
`fire_hits_inactive=false` → standbeeld onraakbaar; (b) `statue_threshold=2` → schade 1 elimineert geen
standbeeld; (c) `stamina_model="one_action"` → pion kan één actie per cyclus; (d) `inf_shot_over_pawn=true`
→ schot over precies één tussenpion legaal; (e) config round-trip dict→JSON→dict identiek. Sim-modus
accepteert `-- sim ... --rules res://arena/arena_configs/v41_default.json`.

### ☑ F0.3 — actions.gd + validator.gd: één actietaal, één poort — AF (juli 2026)

**Bestanden:** `core/match/actions.gd`, `core/match/validator.gd` (nieuw), aanpassingen `GameSession.gd`.

**Werk:**
- `actions.gd`: één `Action`-vorm (Dictionary met `type` + payload; types als const strings):
  `PLACE{placements}`, `DEFINE_CARDS{cards:[{hp,stamina,attack}]}`, `ACK_REVEAL`, `LINK{card_id,pawn_id}`,
  `MOVE{pawn_id,target}`, `MELEE{attacker_id,defender_id}`, `SHOOT{shooter_id,target_id}`,
  `CHARGE{pawn_id,move_target,defender_id}`, `WOLF_STEP{target}`, `SKIP_WOLF_STEP`, `RESIGN`,
  `CLAIM_TIMEOUT`. Plus `make_*`-factories, `to_dict/from_dict` (Vector2i ↔ [x,y]), `is_wellformed(a)`.
  `CLAIM_TIMEOUT` wordt hier alleen **gedefinieerd** en is tot F0.8 altijd illegaal (klokken bestaan nog
  niet). (v4.2-acties `BET_CP`/`SPAWN`/`CANNON_ACT` komen in F2 in ditzelfde bestand.)
- `validator.gd`: `is_legal(state, action, player_id) -> {legal: bool, reason: String}` — verzamelt álle
  checks die nu in `GameSession.submit_*` zitten (fase, beurt, eigendom, dubbel indienen) plus
  `Rules.get_valid_*`. En `legal_actions(state, player_id) -> Array[Action]` voor agents/fuzz (voor
  DEFINE/PLACE een generator van geldige voorbeelden, niet exhaustief).
- GameSession's `submit_*` bouwen vanaf nu Actions en gaan door de validator (gedrag identiek;
  `error_occurred` krijgt de `reason`).

**CHECK:** tests groen. Nieuwe property-test: speel 50 partijen met een tijdelijke random-keuze uit
`legal_actions` (seed uit F0.1); élke gekozen actie passeert `is_legal` en élke toegepaste
`is_legal`-actie slaagt; actie → JSON → actie is identiek.

### ☑ F0.4a — Reducer, deel 1: de actiefase — AF (juli 2026)

**Bestanden:** `core/match/reducer.gd` (nieuw), `GameSession.gd` (actiefase-submits worden shim).

**Werk:** `Reducer.apply(state, action, player_id) -> {ok, events: Array, error}` — eerst alleen voor
`MOVE/MELEE/SHOOT/CHARGE/WOLF_STEP/SKIP_WOLF_STEP`, inclusief beurtwissel, win-checks en
cyclus-reset-trigger (die voorlopig nog `_start_new_cycle` in de shim aanroept). Events zijn typed dicts
(`{type, seq, payload}`); de bestaande result-dict-velden (damage/eliminated/forced_move/retaliation/
wolf_step_available/posities) worden event-payloads. GameSession's actiefase-submits delegeren aan
`Reducer.apply` en vertalen events 1-op-1 naar de bestaande signals — game.gd merkt er niets van.

**CHECK:** alle bestaande actiefase-tests groen via de shim; `-- sim <p1> <p2> <d1> <d2> <seed>` geeft
voor 6 vaste seeds exact dezelfde winnaar+cycli als vóór deze stap (uitkomsten vastgelegd in een test).

### ☑ F0.4b — Reducer, deel 2: setup-fasen + cyclus — AF (juli 2026)

**Bestanden:** `reducer.gd`, `GameSession.gd` (krimpt verder).

**Werk:** `PLACE`, `DEFINE_CARDS`, `ACK_REVEAL`, `LINK` en de volledige fasemachine (reveal-gate,
linking-beurtlogica met staartkoppelen, ronde/cyclus-overgangen) verhuizen naar de reducer.
**Gedragsverbetering die hier bewust in zit:** `ACK_REVEAL` is per speler (lost het single-ack-gat op).
De shim vertaalt één `acknowledge_reveal()`-aanroep van de huidige UI naar **twee** ACK_REVEAL-acties
(beide spelers), zodat offline gedrag identiek blijft; een aparte reducer-test dekt het echte
per-speler-pad (één ack → fase blijft; tweede ack → door).

**CHECK:** volledige bestaande suite groen; reducer-fold-test: een handgeschreven actielijst van
opstelling t/m actiefase geeft de verwachte eindstand; per-speler-ACK-test groen; sim-uitkomsten van de
6 seeds onveranderd.

### ☑ F0.4c — Reducer, deel 3: RESIGN + remise; MatchRunner zonder Node — AF (juli 2026)

**Bestanden:** `reducer.gd`, `match_runner.gd`, `trainer.gd`, `capture.gd`.

**Werk:** `RESIGN` (elke fase → GAME_OVER, winnaar = tegenstander) en de **cycluslimiet-remise**
(`rules.cycle_limit` + tiebreak materiaal→haven→nabijheid — de MatchRunner-heuristiek wordt hiermee een
échte spelregel in de reducer). MatchRunner stapt over van de GameSession-Node op directe
`Reducer.apply`-aanroepen (geen `GameSessionScript.new()`/`free()` meer); trainer en arena volgen.

**CHECK:** reducer-tests: RESIGN in elke fase → juiste winnaar; partij die `cycle_limit` raakt →
remise/tiebreak-uitkomst zoals geconfigureerd. `-- arena 4 medium` draait Node-vrij en produceert een
matrix; sim-seeds onveranderd.

### ☑ F0.5 — serializer.gd: snapshot zonder kaart-identiteitsbreuk — AF (juli 2026)

**Bestanden:** `core/match/serializer.gd` (nieuw), `GameState.gd`.

**Werk:** `Serializer.state_to_dict(state)` / `state_from_dict(d)`: kaarten worden **éénmaal per id**
geserialiseerd (`all_cards`); `cards_defined`/`cards_revealed` worden lijsten van card-**ids**;
reconstructie herstelt referenties naar dezelfde objecten (fixt de bekende clone-identiteitsbreuk).
`GameState.clone()` wordt herschreven als `state_from_dict(state_to_dict(state))` (of ref-correct
gemaakt) zodat er maar één kopieerpad bestaat. RulesConfig serialiseert mee.

**CHECK:** round-trip-test in élke fase (PLACEMENT, DEFINE, REVEAL, LINKING, ACTION, GAME_OVER): speel
tot fase X, serialiseer → deserialiseer → vergelijk veld-voor-veld + speel door tot einde met zelfde
seed → identieke uitkomst. Expliciete regressietest: linking-fase op een gedeserialiseerde staat
**eindigt** (risico 7 uit het online-plan).

### ☑ F0.6 — view.gd: verborgen informatie bestaat alleen nog in de view — AF (juli 2026)

**Bestanden:** `core/match/view.gd` (nieuw), `game.gd` + HP-blokjes (Vos-"?"), capture.gd, tests.

**Werk:** `View.for_player(state, player_id) -> Dictionary` — gefilterde, serialiseerbare weergave:
- vóór reveal: eigen `cards_defined` wel, die van de ander **niet** (ook geen aantallen-lek via ids);
- tijdens PLACEMENT: pionnen van de ander onzichtbaar (blind opstellen);
- Vos: van gedekte vijandelijke pionnen worden hp/stamina/attack/max_* vervangen door een `"?"`-sentinel
  (géén 0/-1 — lege blokjes lekken ook), kaart-koppeling weggelaten; wél zichtbaar: dat de pion actief is + type;
- doctrine van de ander verborgen tot beide gekozen (relevant zodra doctrine-keuze in de engine zit, F4).
UI-werk: de stat-blokjes en reveal-UI renderen een "?"-staat; eigen pionnen tonen altijd alles.

**CHECK:** **leak-canary offline**: property-test die 200 states fuzzt (random-agent-partijen, alle
fases), de tegenstander-view JSON-serialiseert en asserteert dat geen enkel verboden veld
(niet-onthulde defines, Vos-stats, blinde opstelling) in de payload voorkomt — letterlijk de CI-test die
in F4 de servergrens bewaakt. Plus een programmatische UI-assert: nieuwe capture-modus `-- vosview` zet
een gedekte Vos-pion op het bord, leest de HP-blokjes-nodes uit en asserteert dat het label het
"?"-sentinel toont (screenshot als bijvangst, exit-code op de assert).

### ☑ F0.7 — Event-log, zobrist en golden replays — AF (juli 2026)

**Bestanden:** `core/match/match_log.gd`, `core/match/zobrist.gd` (nieuw), `tests/golden_replays/`,
capture-modi `record`/`replay`.

**Werk:**
- `MatchLog`: append-only `{seq, player_id, action, events, ts}` per geaccepteerde actie; de shim (en
  straks de server/arena) schrijft elke apply erin; `MatchLog.fold(initial_state_dict, entries)` speelt
  af. Save/load als JSON (`user://replays/` + `res://tests/golden_replays/`).
- `zobrist.gd`: state-hash. Implementatie-keuze: start met `hash(Serializer.canonical_bytes(state))`
  (goedkoop, correct); een incrementele XOR-zobrist is een F1-optimalisatie als herhalingsdetectie in de
  hot loop nodig blijkt. Hash komt in elke log-entry → checksum bij replay.
- Golden replays, eerste set (~12): per doctrine 1 volledige sim-partij (vaste seeds) + handmatige
  randgevallen: terugslag-doodt-aanvaller, Wolf-stap-in-haven-wint, charge+kill+verplichte-verplaatsing,
  kanon-blokkade/dode zone, Vos-onthulling, staartkoppelen Muis-vs-Leeuw, kaart-vervalt-zonder-pion,
  cycluslimiet-remise. CI-regel: **een gebroken golden = bewuste beslissing + versie-bump** (§0).
- Capture-modi: `-- record <seed> <out.json>` en `-- replay <file>` (exit 0 bij hash-match).

**CHECK (= F0-acceptatie bouwplan):** neem 10 partijen op (mix doctrines/AI-niveaus, vaste seeds),
replay ze → eind-zobrist én volledige eindstate byte-identiek. Alle 12 goldens groen in de testsuite.

### ☑ F0.8 — Klokken, timeout en de complete CLAIM_TIMEOUT-afhandeling — AF (juli 2026)

**Bestanden:** `reducer.gd`, `rules_config.gd`, `game.gd` (timer wordt weergave), UI.

**Werk:** `state.clocks[player] = {bank_ms, increment_ms}` + `state.turn_deadline` (gezet door de
reducer bij elke beurt/fase-overgang volgens `rules.clock`). `CLAIM_TIMEOUT` wordt nu volledig
geïmplementeerd (was tot hier altijd-illegaal, F0.3): de reducer krijgt `now_ms` als parameter (puur =
zelf geen klok lezen) en valideert dat de deadline echt verstreken is; gevolg per fase: setup-fasen →
default-loadout/default-opstelling (het bouwplan-gedrag "deadline valt → default"), actiefase →
bank-verbruik en bij lege bank forfeit. Offline is game.gd de klok-autoriteit (en behoudt zijn
vriendelijke auto-fallbacks als *driver*-gedrag dat gewone acties indient); online wordt dat de server
(F4). De UI krijgt een opgeven-knop (RESIGN bestaat sinds F0.4c) in het pauze/hulpmenu.

**CHECK:** unit-tests: increment na actie; bank leeg + `CLAIM_TIMEOUT` → forfeit-winst tegenpartij;
`CLAIM_TIMEOUT` vóór de deadline → geweigerd; timeout in DEFINE-fase → default-loadout toegepast.
UI-rooktest: timer telt af op basis van `state.turn_deadline` (capture `-- play`).

### ☐ F0.9 — F0-acceptatie & opruiming

**CHECK (Claude, headless):**
1. `tests/TestScene.tscn` groen — baseline 111 tests/~310 asserts + de nieuwe suites (verwacht ≥170 tests).
2. 10-partijen-replay byte-identiek (F0.7).
3. Leak-canary groen (F0.6), `-- vosview`-assert groen.
4. `-- play`-capture ok; `-- sim`-seeds onveranderd; `-- arena 4 medium` produceert een matrix op de nieuwe core.
5. `GameSession.gd` ≤ ~150 regels shim; `grep -rn "Rules.apply_" scripts/ | grep -v reducer` → 0 treffers.

**MAX:** één volledige mens-vs-AI-partij spelen (win + verlies + een Vos-potje): voelt identiek, "?"-blokjes
kloppen, opgeven-knop werkt.

---

## 5. FASE F1 — Arena v1 (het meetprogramma)

Doel: van "trainings-bijproduct in capture.gd" naar een reproduceerbaar meetinstrument dat de
§8-playtest-agenda draait en de eerste balanspatch op data oplevert.

### ☐ F1.1 — Agent-interface op views

**Bestanden:** `agents/agent.gd`, `agents/l0_random.gd`, `agents/l1_greedy.gd`, `agents/l2_weights.gd`, `agents/l3_search.gd`.

**Werk:** hard contract (bouwplan §7.1): `decide(view: Dictionary, legal: Array, rng: SeededRng) ->
Action` (+ later `decide_campaign`). Mapping: **L0** = uniform random uit `legal` (nieuw — fuzz &
ondergrens); **L1** = greedy one-liners (pak kill > loop naar haven > dek kanon; de huidige
`_quick`-ordering is de kiem); **L2** = de bestaande gewichten-eval (AIController-eval geport naar
view-input; per-doctrine profielen blijven `data/ai_weights.json`); **L3** = Hard/Ultra-search bovenop
L2. Onbekende Vos-stats: puntschatting per B11 (determinized sampling = latere upgrade); een
`full_state: bool`-vlag (B8) houdt de oude alwetende eval beschikbaar voor ablatie-metingen. De oude
`AIEasy/Medium/Hard/Ultra`-bestanden blijven als dunne wrappers voor de game-UI tot die op de nieuwe
agents overstapt.

**CHECK:** AITests geport; nieuwe test: L0 speelt 20 volledige partijen zonder crash of illegale actie
(elke keuze door `is_legal`); L2-met-view vs L2-full-state winrate-delta wordt gelogd (Vos-ablatie werkt).

### ☐ F1.2 — Standalone runner + metrics

**Bestanden:** `arena/arena.tscn` (minimal scene, root-script run.gd), `arena/run.gd`, `arena/metrics.gd`,
`arena/arena_configs/*.json` (map bestaat sinds F0.2), `arena.ps1` (multi-proces launcher).

**Werk:** `godot --headless --path . res://arena/arena.tscn -- --config <json> --out results/<run>/`.
Config: matchups, aantal per richting, agents/niveaus, seeds (basis-seed + index), rules_config(s),
max-cycli. Per game één regel metrics-JSON (append, `results/<run>/games.jsonl`) met de **letterlijke
§8.2-mapping**: cycli, winnaar+methode (haven/eliminatie/remise+tiebreak), zobrist-herhalingen,
kills-op-standbeelden per kaartprofiel (1/5/1-oogst), schoten per kanon + actiepot-benutting + %
geblokkeerde intenties, koppelverdeling kaart→type per doctrine, winrate-matrix, verspilde Attack per
kill (Leeuw-spiraal), schade-per-actie (Muis), winmethode per havenvak (hoekfort), gedekt-vs-open-delta
(Vos-ablatie via F1.1-vlag), remise-triggers. `arena.ps1` start 1 proces per core met een seed-offset en
merget de jsonl's. Run-metadata (git-sha, config, seed) in een header-regel — jsonl is het formaat (B10).
`arena.bat` gaat naar de nieuwe runner wijzen (met `pause` achter een `FOW_NOPAUSE`-guard).

**CHECK:** run met 2 doctrines × 10 games produceert geldige jsonl (schema-check-script); zelfde
config+seed 2× → identieke jsonl (reproduceerbaarheid); het capture-arena-pad blijft werken of is
verwijderd met verwijzing.

### ☐ F1.3 — Doorvoer ≥5 matches/s/core

**Werk:** benchmark-modus (`--bench`): meet matches/s op 1 core met L1-vs-L1 (het arena-werkpaard).
Optimalisatievolgorde (meten na elke stap): (1) geen Node/signal-overhead meer (al gedaan in F0.4c);
(2) `legal_actions`/eval zonder volledige `state.clone()` per kandidaat — apply/undo per actie in de
actiefase óf een compacte sim-state (arrays i.p.v. Pawn-objecten) alléén in de agents; (3) geen
Dictionary-allocaties in de hot loop (hergebruik buffers); (4) beperk L2-eval tot incrementele features
waar het kan. Haalt GDScript het dan nog niet → B1-escalatie (C#-poort van reducer/validator, goldens
bewijzen gelijkheid) — pas beslissen mét meetdata.

**CHECK:** `--bench` rapporteert ≥5 matches/s/core met L1-vs-L1 (en documenteert L2/L3-doorvoer).
Nachtcapaciteit (8 cores × 8 uur ≥ 150k L1-matches) mag als **extrapolatie** uit `--bench` worden
afgevinkt; het echte run-log volgt vanzelf uit de eerste nachtjob (F1.5).

### ☐ F1.4 — Fuzz & invarianten als nachtvangnet

**Bestanden:** `arena/fuzz.gd`.

**Werk:** 10k L0-vs-L0 per nacht (of zoveel als past), per partij property-checks: pionnen ontstaan
nooit uit het niets, som HP-schade klopt met events, geen actie buiten `legal_actions`,
`fold(log) == eindstate`, view lekt niets (herbruik F0.6-canary). Elke schending → `results/fuzz/`
repro-bestand met seed+config+log.

**CHECK:** fuzz-run van 500 partijen schoon; een handmatig ingebouwde mutatie-bug (test de tester) wordt
gevangen.

### ☐ F1.5 — Dashboard + nachtjob

**Bestanden:** `tools/dashboard/build_dashboard.py` (of .gd), `arena_nacht.ps1`.

**Werk:** dashboard leest `results/**/games.jsonl` → statisch HTML (winrate-matrix-heatmap,
§8-metrieken, trend vs vorige run, regelversie erbij). Nachtjob eerst lokaal via Windows Taakplanner
(`arena_nacht.ps1`: git pull → arena → fuzz → dashboard → diff-samenvatting naar Telegram/mail);
verhuist in F4 naar een cron-job op de VPS (bouwplan §8.4; geen n8n — B5).

**CHECK:** dashboard opent lokaal met echte data; nachtjob draait één keer end-to-end aantoonbaar
(inclusief het echte 8-uurs-capaciteitslog voor F1.3).

### ☐ F1.6 — Eerste balanspatch op data

**Werk:** de openstaande balansvragen met het nieuwe instrument beantwoorden, minstens: **Muis (kapot:
4–12% tegen de topfacties, 16,7% totaal in de arena-matrix — zie data/matchup_muis.txt en
data/arena_results.txt)**, Leeuw-dominantie, en de §8-agenda punten 1/2/4 (standoff, 1/5/1-oogst,
infanterie-koppeling) via config-sweeps (`statue_threshold` 0/2, `haven_score_cumulative` aan/uit,
terugslag-varianten, Muis-comp 22/0/0 vs 20/0/2 vs 18/4/0). Resultaat: `rules_version` 4.1.10-hr met
CHANGELOG-onderbouwing per knop, plus hertraining van de gewichten. Trainingsnotitie: de bestaande
CMA-lite geldt als de "CEM-variant" van de bouwplan-§7.4-lus (bewuste keuze); neem wél de
convergentiecheck over (kampioen gen N vs gen N−5, vaste seeds) en draai voortaan met seeds. De gedrifte
`ai_weights_f*.json`-profielen (f3: cav_value ≈ 179k) eerst renormaliseren of opnieuw trainen vóór er
balansconclusies op steunen.

**CHECK:** arena-matrix ná patch: geen doctrine <25% of >75% totaal-winrate op L2 (werkdoel);
convergentiecheck gerapporteerd; alle goldens bewust ge-bumpt waar regels wijzigden.

---

## 6. FASE F2 — Regels v4.2 (de campagne-economie in de match)

Doel: MatchCore spreekt de volledige v4.2-actieset uit het bouwplan. Alles config-gated: een match
zonder `campaign`-blok speelt exact 4.1.x.

### ☐ F2.1 — spelregels-v4.2.md definitief

**Werk:** Deel B uit F0.0 samen met Max doornemen en vastklikken: CP-tabel (start 6, haven 8, eliminatie
4, raadstem 1 — bouwplan §2.4), inzet per ronde (0..3, cap +1 per kaart — wat doet een CP op een kaart
precies: +1 op een stat naar keuze bij koppeling? TE BEVESTIGEN), poolfactor (3.0 × wat — startpionnen?
TE BEVESTIGEN), spawnregels (≤3 per cyclus, welke vakken — thuisrijen? TE BEVESTIGEN), kanon-actiepot
(`CANNON_ACT`: stamina = pot; ROLL = 1 vak rollen, SHOOT, RETREAT = inrukken? dracht-model: vast max 5
per bouwplan-config vs huidige 6 — TE BEVESTIGEN), `SKIP`-actie (alleen als engine geen legale actie
vindt). Dit is een ontwerpsessie-stap, geen codestap.

**CHECK:** document bevat geen "TE BEVESTIGEN" meer; elke regel heeft een config-knop-naam.

### ☐ F2.2 — Pools, CYCLE_SPAWN en SPAWN in de reducer

**Werk:** fase-enum uitbreiden conform bouwplan §2.1: `CYCLE_SPAWN` vóór de define-rondes en `RESET` als
expliciete fase. `state.pools[player] = {inf, cav, art}` (init uit config/campagne); `SPAWN{[(type,
cel)≤3]}` als blinde gelijktijdige keuze (zelfde commit-gate als DEFINE: beide binnen → reveal-event);
pion-eliminaties muteren de pool niet (dood = weg), spawns halen uit de pool. Win/verlies-condities
herzien: eliminatie-winst kijkt naar bord+pool.

**CHECK:** reducer-tests: spawn boven poolsaldo geweigerd; spawn op bezet vak geweigerd; blinde
gelijktijdigheid (view van de ander toont niets tot beide binnen — leak-canary uitgebreid); golden
replay "spawn-geblokkeerd".

### ☐ F2.3 — CP in de match: BET_CP

**Werk:** `state.cp[player]`; `BET_CP{0..3}` als blinde keuze per setup-ronde naast DEFINE_CARDS
(zelfde commit-gate); effect volgens F2.1-besluit (bv. +1 stat op een kaart, cap 1/kaart); ingezette
CP verbranden of terugkeren volgens spec; CP-mutaties zijn events (de latere campagne-ledger leest ze).
Initiatief-bod: CP-inzet telt mee/niet mee volgens spec.

**CHECK:** reducer-tests: cap per kaart; CP-saldo kan nooit negatief; view verbergt vijandelijke inzet
tot reveal (leak-canary); golden replay met CP-inzet.

### ☐ F2.4 — CANNON_ACT (stamina-kanon)

**Werk:** artillerie krijgt de expliciete actie `CANNON_ACT{piece, ROLL dir | SHOOT target | RETREAT}`
met de stamina-pot als actiebron (formaliseert de huidige huisregel); dracht/kosten uit config
(`kanonDrachtMax`, `kanonActieKost`). UI: actiepot-badge op het kanon (bouwplan §4.1). Oude
MOVE/SHOOT-paden voor artillerie blijven werken onder 4.1.x-config.

**CHECK:** tests voor alle drie subacties + dode zone + blokkade onder v4.2-config; 4.1.x-goldens
ongewijzigd groen.

### ☐ F2.5 — Agents leren v4.2

**Werk:** zonder dit meet F2.6 ruis: L0 kiest de nieuwe acties al legaal-random (gratis via
`legal_actions`), maar L1 krijgt heuristieken (spawn richting front/haven; CP op de ronde-3-kaart;
kanon: SHOOT > ROLL naar schootsveld > RETREAT bij bedreiging) en L2 krijgt de bouwplan-§7.3-features:
spawn-drempel, kanon-actiepot-gebruik, CP-inzet-timing, kaartspreiding-onder-CP — als nieuwe leerbare
gewichten. Daarna hertraining per doctrine onder v4.2-config (met seeds + convergentiecheck).

**CHECK:** L1/L2 spelen 50 v4.2-partijen waarin aantoonbaar gespawnd/geboden wordt (metrics: >0 spawns
en >0 CP-inzet per partij gemiddeld); hertrainde gewichten verslaan de niet-v4.2-bewuste gewichten (>55%
op vaste seeds).

### ☐ F2.6 — Arena-hermeting + UI onder v4.2

**Werk:** `arena_configs/v42_default.json`; volledige matrix + §8.2-metrics onder v4.2; sweep over de
nieuwe knoppen (CP-tabel ±, poolfactor 2.5/3.0, kanonDrachtMax 5/6). UI: spawn-UI (hergebruik
placement-flow), CP-toggle in de kaartwaaier, actiepot-badge, en het **MatchSetup**-scherm uit bouwplan
§4.1: 3 kaarten met sliders + presets Aanvallend/Gebalanceerd/Verdedigend, waarbij **preset = ook de
timeout-default** (koppelt aan de F0.8 default-loadout).

**CHECK (Claude):** arena-rapport v4.2 bestaat; `-- sim ... --rules v42_default.json` speelt uit; alle
4.1.x-goldens én nieuwe 4.2-goldens groen; capture-shot van MatchSetup + spawn-UI.
**MAX:** één mens-vs-AI-duel onder v4.2 spelen: spawn, CP-inzet en kanon-act voelen kloppend.

---

## 7. FASE F3 — Solo-campagne (15 AI's)

Doel: de volledige campagne-loop lokaal, offline, tegen 15 bots — het goedkoopste bewijs van het hele
campagne-ontwerp (bouwplan §6).

### ☐ F3.0 — campagne-spec.md definitief

**Werk:** `docs/campagne-spec.md` schrijven (draft door Claude uit bouwplan §2.2/§9.2, daarna sessie met
Max): teams van 8 (live-8) / 16 (async), raadsronde-flow, nominatieregels (niemand 2× per raadsronde;
duels/ronde = min(2, kleinste teamgrootte); kleinste team — tiebreak minste punten — nomineert eerst; 1
overlevende nomineert zelf), stemregels (default teammeerderheid; staking → speler met kleinste pool),
donatiecaps (10 pionnen / 3 CP per ontvanger per ronde), testament (≤ helft, ≤2 ontvangers, timer,
forfeit = verbranden), teamwinst-punten ook voor doden, burgeroorlog (seeding punten→CP→pool, vrijloting
hoogste seed, geen raad/ruil), puntentabel (§9.2), CP↔match-koppeling (start-CP, haven/eliminatie-bonus
→ ledger), pool↔match-koppeling (poolfactor → startpionnen + spawnvoorraad per duel; verliezen gaan van
de pool af? TE BEVESTIGEN), timers/deadlines per fase (live-8 vs async-16 verschillen).

**CHECK:** spec compleet zonder "TE BEVESTIGEN"; elke regel heeft een testgeval-naam in een bijlage.

### ☐ F3.1 — CampaignCore

**Bestanden:** `core/campaign/cstate.gd`, `cactions.gd`, `creducer.gd`, `cview.gd`, `crules.gd`.

**Werk:** zelfde patroon als MatchCore: `cstate` (spelers, teams, pools, CP, punten, ronde, fase,
bracket, pending-duels), `cactions` (`NOMINATE`, `VOTE`, `DONATE{pions|cp}`, `TESTAMENT`,
`MATCH_RESULT`, `JOIN`, `LEAVE`, `TICK_DEADLINE` — deadline-verwerking als actie, zodat óók defaults in
het log staan), `creducer.apply` met alle §2.2-regels, `cview` (grootboek publiek; teamchat/stem-details
team-only; doden → publieke view), `crules` (puntentabel, caps, timers, poolgrootte als data).
CP/pion-mutaties lopen als **ledger-events** (reason: start/donate/testament/loss/spawn/win_haven/…);
saldo = som van het ledger, nooit een muteerbaar veld (bouwplan §5.1-principe, ook lokaal).
`MATCH_RESULT` consumeert het match-event-log (winnaar, methode, verliezen per type → pool-afboeking).

**CHECK:** elke regel uit de spec-bijlage is een reducer-test (verwacht ~40 tests): nominatie-limieten,
stem-defaults/staking, donatiecaps hard, testament-varianten incl. timeout-verbranding, forfeit-keten,
burgeroorlog-seeding + vrijloting, punten ook voor doden. Campagne-log fold-test: replay = identieke
eindstand. Ledger-invariant: som(pion-ledger) + bord = constant behalve expliciete verbranding.

### ☐ F3.2 — SoloDriver + 15 persoonlijkheden

**Bestanden:** `agents/campaign/campaign_agent.gd`, `personalities.gd`, `game/solo_driver.gd`.

**Werk:** `decide_campaign(cview, legal, rng)` per bot; persoonlijkheid = gewichtenvector + temperatuur
+ bark-profiel (bouwplan §6): nominatie-doelfunctie (zwakste vijand vs tank laten bloeden),
donatie-concentratie, CP-timing (sparen voor burgeroorlog), testament-loyaliteit, risico-afslag bij
kleine pool. Archetypes: Trouwe generaal, Rat, Gierigaard, Berserker + 4 variaties; spreiding per lobby.
**Moeilijkheid: L1/L2/L3-mix per lobby (L3 = zware solo-bot), géén rubber-banding in v1** (bouwplan §6 —
eerlijkheid > comfort). SoloDriver: draait CampaignCore lokaal; bots stemmen direct, de raad wacht
alleen op de mens (zachte timer 60s, skipbaar); **bot-vs-bot-duels simuleren via MatchCore op vol
tempo** en posten een MatchReport-kaartje — mét opgeslagen match-log zodat de speler ze als replay kán
bekijken. Mens-duels starten de normale Board-flow met campagne-rules_config (pool/CP uit cstate).
Barks: quick-chat-ids gepost als campagne-events op triggers (nominatie, donatie, testament, verraad).

**CHECK:** headless volledige solo-campagne (mens vervangen door een 16e bot) speelt uit tot kampioen
< 60 s wall-clock; geen deadlocks over 20 seeds. Barks-assert: bij vaste seed bevat het campagne-log
voor 5 benoemde triggers (o.a. nominatie-van-teamgenoot, testament-naar-vijand) elk ≥1 bark-event van de
betrokken persoonlijkheid — assert op log-inhoud, niet op UI.

### ☐ F3.3 — Campagne-UI (mobile-first)

**Bestanden:** `ui/screens/campaign_hub`, `ledger_screen`, `council_screen`, `donate_sheet`,
`testament_screen`, `match_report`, components (`FactionIcon`, `PoolBadge`, `CPBadge`, `TimerBar`,
`VoteCard`, `LedgerCard`, **`BracketView`** — de burgeroorlog moet zichtbaar zijn); capture.gd.

**Werk:** bouwplan §4.1-schermen, gereduceerd tot de solo-behoefte: CampagneHub = tijdlijn met kaartjes
(rapporten/donaties/stemmen — "Among Us-gevoel"), Grootboek (sorteerbare tabel 🪖/🎖️/⭐/❤️💀), Raad
(ballot + portret-tik = stem, sluit vervroegd bij unanimiteit), DonateSheet (steppers + caps hard in UI
én reducer), Testament (verdeel-slider, grote timer), MatchReport (auto-kaartje), BracketView
(burgeroorlog). Alles leest uitsluitend `cview`. Touch-equivalenten voor alle rechtermuis-acties
(placement-undo, Wolf-skip) — het openstaande online-plan-0.5-punt hoort bij dit UI-blok. **Nieuwe
capture-modus `-- shot <schermnaam>`**: instantieert het scherm met een fixture-cstate en schrijft een
PNG + exit-code op node-asserts (deze modus wordt hier gebouwd en is daarna het standaardgereedschap
voor alle UI-checks).

**CHECK (Claude):** `-- shot campaignhub|ledger|council|donate|testament|report|bracket` allemaal exit 0
met PNG; de headless F3.2-campagnerun gekoppeld aan de UI (driver-integratietest: elk kaartje-type
verschijnt minstens één keer).
**MAX:** volledige solo-campagne handmatig spelen begin→kampioen zonder netwerk (dé F3-acceptatie).

### ☐ F3.4 — Persistentie & hervatten

**Werk:** savegame = campagne-event-log + match-logs (`user://campaigns/<id>/`); hervatten = fold; "durf
te sluiten"-garantie (elke actie direct gepersisteerd). Voorbereid op F4-sync: het log is het
uploadformaat (B6; endpoint komt in F4.5).

**CHECK:** campagne halverwege afsluiten + herstarten → identieke staat (fold-hash); kill -9 tijdens een
duel verliest hooguit de laatste actie.

---

## 8. FASE F4 — Online duels

Doel: twee mensen spelen een gevalideerd duel via de backend; ranked 1v1 opent (B7). Volgt bouwplan §5;
client-voorwerk uit het online-plan (camera-flip, render-from-snapshot, web-spike) zit hier.

**Prereq:** Docker Desktop geïnstalleerd en gestart (voor testcontainers-MySQL/Redis in de
integratietests); anders fallback: lokale MySQL + `DB_URL`-env. Check dit als eerste substap.

### ☐ F4.1 — Backend-skelet + datamodel + accounts

**Bestanden:** `server/` (Node 22 + Fastify), `server/db/migrations/*` (MySQL), Redis, `docs/protocol.md`.

**Werk:** tabellen uit bouwplan §5.1 (users/sessions/matches/match_events/snapshots/ratings/…;
campagnetabellen mogen al mee, blijven leeg tot F5; arena-tabellen niet — B10). Accounts §9.1 volledig:
gast-eerst (device-token UUID → user), **upgrade naar e-mail/OAuth** voor cross-device en leaderboards,
**profaniteitsfilter op namen**, avatar = doctrine-embleem + kleur, **vriendcodes** (tabel + endpoint;
UI volgt in F4.4). REST: `POST /matches/:id/actions {seq_expected, action, idem_key}` → 200 events / 409
events-sinds-seq; WS: subscribe per match, events met seq, `GET /events?after=seq` voor gaten;
polling-fallback. Idempotency-keys + seq-verwachting (bouwplan §10). `rules_version` + `rules_config`
JSON op de match.

**CHECK:** integratietest (vitest + testcontainers): actie posten → event terug → dubbel posten met
zelfde idem_key → geen duplicaat; seq-conflict → 409 met inhaal-events; gast-upgrade-flow;
profaniteitsfilter weigert testwoorden.

### ☐ F4.2 — Godot headless worker

**Bestanden:** `server/workers/` (job-consumer), Godot export-preset "worker" (of `--headless --script`).

**Werk:** worker consumeert Redis-jobs `{job: "apply", match, action, player}`: laadt snapshot+staart
uit MySQL, `Validator.is_legal` + `Reducer.apply`, appendt events, schrijft snapshot elke 50 events,
ack't. Stateless → `fow-worker@N` schalen. Zelfde `core/`-bestanden als de client (kernprincipe één
waarheid); een `core-hash`-endpoint vergelijkt de hash van de `core/`-map tussen client-build en worker
(bouwplan §11.5).

**CHECK:** worker-integratietest: volledige partij via de queue naspelen = zelfde eind-zobrist als
lokaal; kill van een worker midden in een job → job wordt heropgepakt zonder dubbele events (idempotent).

### ☐ F4.3 — Client: LocalSession/RemoteSession + render-vanaf-snapshot

**Bestanden:** `net/net_client.gd`, `net/event_stream.gd`, `net/offline_queue.gd`, `game.gd`-splitsing,
`ui/screens/lobby`.

**Werk:** game.gd praat tegen een `SessionInterface` (submit_*-signaturen + signals): `LocalSession` =
huidige shim (vs-AI blijft exact zoals nu), `RemoteSession` = REST/WS met optimistic UI (lokale
validator, server wint bij conflict → rebase) en OfflineQueue met idem-keys (trein-tunnel-proof,
resume(seq) bij reconnect). **Render-vanaf-snapshot**: elke fase opbouwbaar uit view+events (de grootste
verborgen klantenpost — expliciet plannen: pawn-views, hp-blokjes, kaarthand, pending wolf-stap,
reveal-overlay, klokken). Camera-flip 180° voor P2 (geen coördinaat-spiegeling), `local_player_id`
overal doorheen, hardcoded "Jij (rood)"-teksten parametriseren. Doctrine-keuze verhuist naar de engine
(`CHOOSE_DOCTRINE`-actie met blinde gate, zoals DEFINE). Lobby-scherm (bouwplan §4.1): join-code /
publieke queue / "vs AI" — gastaccount = 0 frictie.

**CHECK:** twee clients lokaal tegen dev-server: volledige partij (M1 uit het online-plan); reconnect
midden in élke fase (M3): client koud herstarten → resume → identieke weergave (schermvergelijk-capture);
vs-AI-regressie: bestaande flow onveranderd.

### ☐ F4.4 — Server-klokken, forfeit, ranked, web

**Werk:** server = klok-autoriteit (F0.8-model met server-`now_ms`); reconnect-gratie 20s×3;
deadline-job scant elke 30s (`jobs/deadlines`); per fase het juiste deadline-gevolg: setup-fasen →
**default-loadout/preset-default** (F0.8/F2.6), actiefase → bank/forfeit; RESIGN/remise volledig
server-side. Ranked 1v1-queue (FIFO → rating-venster zodra Glicko in F6 landt), mét **consent-vlag voor
A/B op rules_config** (B7); rematch; privélobby's via vriendcode; replay-download (het event-log).
Web-export-spike vroeg in F4 (gl_compatibility, single-thread → AI-vlag uit op web, roomcode via
JavaScriptBridge) zodat "spelen via een link" kan voor playtests.

**CHECK (F4-acceptatie):** 2 apparaten spelen een duel uit met **vliegtuigstand-test halverwege**
(MAX + 1 tester); leak-canary draait in CI tegen een echte server (verbindt als P2, asserteert dat geen
serverbericht verboden velden bevat); klok-forfeit aantoonbaar in een integratietest.

### ☐ F4.5 — Solo-sync: her-validatie van offline campagnes

**Werk:** `POST /solo/sync` (B6): client uploadt het solo-campagne-log (+ match-logs); een worker
replayt alles (fold + zobrist-checksums), vergelijkt de uitkomst en schrijft pas dán solo-progressie/
punten bij het account. Afwijking → log afgekeurd, niets bijgeschreven (met reden terug).

**CHECK:** integratietest: geldig log → progressie bijgeschreven; gemanipuleerd log (1 actie vervalst) →
afgekeurd; dubbel uploaden → idempotent.

---

## 9. FASE F5 — Online campagne

### ☐ F5.1 — CampaignCore server-side
CampaignCore draait in de worker (zelfde één-waarheid-principe); `campaign_events` append-only;
rounds/nominations/votes-tabellen gevuld door de creducer; `TICK_DEADLINE` door de deadline-job
(defaults staan zo in het log). Live-8 en async-16 lobby's (async alleen privé, bouwplan §9.4).
**CHECK:** campagne-integratietest: 16 gescripte clients spelen een campagne door incl. 3 no-shows →
forfeits/defaults regelen het; fold(campaign_events) = eindstand.

### ☐ F5.2 — Teamchat, quick-chat, spookmodus
Quick-chat als id-lijst (JSON, vertaalbaar), vrije tekst als lobby-instelling; chat-scheiding hard
server-side: doden krijgen publieke view, geen teamgeheimen. CampagneHub-tijdlijn krijgt de
live-kaartjes (stemmen/donaties/rapporten).
**CHECK:** spook-test: dode speler ontvangt geen team-payloads (canary-variant).

### ☐ F5.3 — Push-notificaties (de bekende pijnplek — eerste week van F5)
FCM (Android) + APNs (iOS) via plugin; de 3 ping-types (jouw duel / raad open / rapport);
e-mail-fallback via een backend-job (node-cron/nodemailer). Vroeg prototypen op echte apparaten.
**CHECK:** push komt aan op een echt toestel bij elk van de 3 events (MAX bevestigt); fallback-mail bij
uitgezette push (integratietest).

### ☐ F5.4 — Acceptatie
**MAX:** 8 testers spelen een live-8-event < 90 min; async-16-campagne overleeft 3 no-shows via
defaults. **Claude:** alle timers/vangnetten (raad-deadline, testament-timer, klokken) aantoonbaar in de
server-logs van dat event.

---

## 10. FASE F6 — Meta

- ☐ **F6.1 Glicko-2** per queue (ranked 1v1 / campagneduels; solo telt niet — solo heeft een eigen bord,
  zie F6.3), placement via RD. **CHECK:** rating-unittests tegen referentie-implementatie; RD daalt met
  partijen.
- ☐ **F6.2 Seizoenen & leagues:** LP = campagnepunten × tier-multiplier, 6 weken, Hout→Fabel,
  promotie/degradatie 20%, soft reset + embleem-cosmetica. **CHECK:** seizoenswissel-job (node-cron) op een
  testseizoen; LP-berekening als unit-test.
- ☐ **F6.3 Leaderboards + schermen:** globaal, per doctrine (min. 20 partijen), seizoen-LP, vrienden
  (vereist vriendcodes uit F4.1), **solo-campagne-bord** (gevoed door F4.5-sync), drama-borden
  (testament-verraad, langste last-stand) — uurlijkse snapshots (materialized). Client: Leaderboard-,
  Profiel- en Instellingen-schermen (bouwplan §4.1). **CHECK:** boards vullen zich uit seed-data;
  query-tijd < 50 ms op 100k rijen; `-- shot leaderboard|profile` groen.
- ☐ **F6.4 Matchmaking + backfill + commend:** publieke queue mikt op live-8; lobby vult niet binnen 3
  min → bots, zichtbaar 🤖 (B7). **Commend/report stuurt matchmaking-pools** (bouwplan §10). **CHECK:**
  wachtrij-simulatie met 100 nep-clients vult lobbies correct; commend-signaal verschuift pool-toewijzing
  in een simulatie.
- ☐ **F6.5 Moderatie + collusie:** rapporteren → dagelijkse digest-job (node-cron); sancties mute → quick-chat-only →
  queue-ban; rate-limits per route; **device/IP-collusieheuristiek** (2 accounts zelfde speler in één
  campagne → flag, niet auto-ban). **CHECK:** sanctie-escalatie als integratietest; collusie-flag op
  gesimuleerd device-paar.

---

## 11. FASE F7 — Campagne-arena

- ☐ **F7.1** 16-bot-campagnes headless (CampaignCore + MatchCore), campagne-metrics: doctrine-winrate op
  campagneniveau, comeback-rate 3v1, duur in duels, CP-inflatie, testament-naar-vijand-frequentie
  (drama-metriek), burgeroorlog-frequentie + vrijloting-effect, poolfactor-validatie (kampioen houdt
  10–25% pool over). Data mag nu alsnog naar `arena_runs`/`arena_games`-tabellen als de rapportage-jobs dat
  vraagt (B10). **CHECK:** één nachtrun produceert het campagne-dashboard.
- ☐ **F7.2** Campagnegewichten-evolutie (bouwplan §7.4: populatie 24/doctrine, round-robin met
  kleurwissel + vaste seeds, top 25% op Elo, mutatie+crossover; reproduceerbaar via `(git_sha,
  rules_config, seed)`), apart van matchgewichten. **CHECK:** kampioen gen N verslaat gen N−5 (>55%) op
  vaste seeds.
- ☐ **F7.3** Config-sweeps op campagneknoppen → CP-tabel & poolfactor definitief op data;
  kampioensvectoren naar `ai_agents` (productie-bots §8.5, bot-Elo op het mensen-ratingsysteem).

---

## 12. FASE F8 — Optioneel

L4 neuraal (imitatie op event-logs → PPO-selfplay met action-masking; pas als F7-data er ligt),
**determinized sampling N=16 voor L3** (B11-upgrade, eerder mag als de arena de noodzaak aantoont),
C#-poort van reducer/validator (alleen als F1.3 het GDScript-plafond aantoont; goldens bewijzen
equivalentie), **web-replay-viewer** in tools/ (B12), toeschouwersmodus (gratis bij event sourcing: view
zonder speler-geheimen + delay), cosmetica.

---

## 13. Test- en kwaliteitsprogramma (loopt door alle fasen)

1. **Unit per regel** — bestaande suites (111 tests) + per nieuwe reducer-regel een test;
   resolutievolgordes uit spelregels §7 zijn letterlijke testgevallen.
2. **Golden replays** — groeit van 12 (F0) naar ~40 (elke doctrine, elk randgeval, v4.1-hr én v4.2,
   campagne-goldens vanaf F3). Breekt er één: bewuste beslissing + versie-bump.
3. **Invarianten/property-tests** — pionnen alleen via ledger/spawn, CP-som constant minus verbrand,
   geen actie buiten `legal_actions`, view lekt nooit (reflectie op payloads), fold(log)==snapshot.
4. **Fuzz** — nachtelijk L0-vs-L0; elke crash/illegale staat = repro-seed in `results/fuzz/`.
5. **Cross-laag** — client en worker draaien dezelfde `core/`-bestanden; core-hash in versie-endpoint;
   leak-canary in CI vanaf F4.
6. **CI** — GitHub Actions (of lokaal pre-commit): headless tests + goldens + leak-canary bij elke PR;
   arena-run verplicht vóór merge bij regelwijzigingen (bouwplan §8.4).

## 14. Risico's (aangevuld op bouwplan §13)

| Risico | Mitigatie |
|---|---|
| GDScript-arena haalt 5/s/core niet | F1.3-meetladder; pas dán C# (goldens bewijzen gelijkheid) |
| F0-refactor breekt de speelbare game | Shim-strategie (B3): UI + tests blijven elke stap groen; capture-rooktest per stap; F0.4 in drie delen |
| v4.2-economie blijkt onuitgebalanceerd ontwerp | F2 ligt vóór de campagne; agents leren de acties eerst (F2.5), dán pas meten (F2.6) |
| Campagne-spec-details ontbreken (staat niet in de repo) | F3.0-ontwerpsessie met Max is een expliciete stap; reducer-tests zijn de contractvorm |
| Push-notificaties (plugin-gedoe) | F5.3 in week 1 van F5; e-mail/Telegram-fallback via backend-job |
| Verborgen info lekt via client | Geheimen bestaan client-side niet (F0.6); canary offline (F0) → CI (F4) |
| Regel-iteratie breekt oude data | `rules_version`+config per match; replayer laadt config uit de match |
| Async-16 bloedt leeg met vreemden | Live-8 publiek default; forfeit-keten garandeert een winnaar |
| Getrainde gewichten zijn gedrift (f3-profiel: cav_value ≈ 179k) | F1.6: renormaliseren/hertrainen met seeds vóór balansconclusies |
| Balans-schijnzekerheid (bots ≠ mensen) | Bot-metrieken = hypothese-filter; ranked 1v1 (F4) is de mens-toets |

## 15. Openstaande beslissingen voor Max

Genummerd; het plan noemt ze op de plek waar ze vallen.

1. ~~**Muis-samenstelling**~~ **BESLOTEN (juli 2026): 18/4/0** — het BIG BRO-besluit wordt in F0.0
   doorgevoerd (comp-wijziging + spec + CHANGELOG); arena-hermeting en eventuele bijstelling in F1.6.
   De dikke rat (Muis-cavalerie) komt op de modellenlijst (MODEL-WISHLIST).
2. **v4.2-economie-details** (CP-effect op kaart, poolfactor-basis, spawnvakken, kanon-actiepot-details,
   dracht 5 vs 6): → F2.1-ontwerpsessie.
3. **Campagne-spec-details** die niet in het bouwplan staan (pool-afboeking na duel, exacte
   deadline-duren per fase, live-8 vs async-16 timerverschillen): → F3.0-ontwerpsessie.
4. ~~**Bevestiging architectuurkeuzes B5–B7 en B10–B12**~~ **BESLOTEN (juli 2026): akkoord, met één
   wijziging — GEEN n8n of andere workflow-automation-tooling.** Alle geplande jobs worden gewone
   code: node-cron in de backend, systemd-timers/Taakplanner voor host-level. B5 is aangepast; alle
   n8n-verwijzingen in dit plan zijn vervangen.

---

*Nulmeting uitgevoerd op commit 721ddb6, juli 2026. Bronnen: volledige code-doorlichting (core, game/UI,
AI, training/arena, tests, docs), spelregels-v4.1.md, game_description.md, WIP.md, ONLINE-PLAYTEST-PLAN.md,
AI_TRAINING_PLAN.md en fog-of-war-bouwplan-godot-v1.md. Daarna adversarieel geverifieerd (feiten-,
dekkings- en uitvoerbaarheidscheck); alle bevindingen zijn in deze versie verwerkt.*
