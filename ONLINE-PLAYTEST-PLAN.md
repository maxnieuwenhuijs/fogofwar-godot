# Plan — Fog of War online playtesten

> Doel: zo snel mogelijk met échte mensen online playtesten (capaciteit eerst),
> daarna de competitieve laag (lobby, punten, leaderboard, matchmaking), en pas
> daarna dichttimmeren. Dit plan is gebaseerd op een code-audit, netwerk-research
> en een adversariële review (juli 2026). Werkvolgorde: Fase 0 → 4.

**De vier harde eisen en waar ze landen:**

| Eis | Waar in dit plan |
|---|---|
| 1. Online tegen elkaar spelen (playtest-prio) | Fase 1 (MVP) |
| 2. Lobby / punten / leaderboard / matchmaking | Fase 2 (lite) + Fase 3 (volledig) |
| 3. Bord gedraaid voor speler 2 (eigen pionnen altijd onderaan) | Fase 0 (offline al te bouwen + testen) |
| 4. Kaarten van de tegenstander zichtbaar na onthulling | Fase 0 (offline al te bouwen + testen) |

**Kernbevinding van de audit:** de engine is al bijna multiplayer-klaar. Alle
mutaties lopen door de `submit_*`-API met per-speler-validatie, de core bevat
géén RNG (deterministisch → replay/reconnect via event-log), en MatchRunner
bewijst dat N losse `GameSession`-instanties in één proces draaien (= N rooms
in één headless server). De echte gaten: geen gefilterde snapshot (verborgen
info lekt als je `state` doorstuurt), doctrine-keuze/reveal-ack zitten niet in
de per-speler-API, de driver speelt nu beide kanten, en er bestaat geen
remise of opgeven.

---

## Architectuurkeuze (vastgesteld)

**Eigen JSON-eventprotocol over WebSocket, zonder Godots high-level
MultiplayerAPI.** Headless Godot-server (zelfde GDScript-engine!) op de
bestaande DigitalOcean-droplet, achter nginx als `wss://`-reverse-proxy
(Let's Encrypt staat er al). Client later ook als **web-export** → spelen via
een link = maximale playtest-capaciteit.

Waarom zo:
- Turn-based → latency irrelevant → WebSocket (firewall-vriendelijk, werkt in
  web-export; ENet/UDP werkt dáár niet).
- Verborgen informatie (blinde defines, Vos) verdraagt géén node-replicatie
  (MultiplayerSynchronizer is voor realtime). Event-gebaseerd + per-speler
  gefilterde snapshots is het juiste model.
- JSON is logbaar, versioneerbaar en met `websocat` testbaar; het event-log per
  match ís meteen de replay én de telemetrie.
- Server-authoritative vanaf dag 1: de client is een domme renderer; elke
  `submit_*` wordt op de server door de bestaande engine gevalideerd.

---

## Fase 0 — Offline voorwerk (alles nu al bouw- en testbaar vs AI)

Deze punten zijn nodig vóór netcode en direct te verifiëren zonder server.

**0.1 Reveal-UI: toon de échte kaarten van de tegenstander (eis 4).**
`_on_cards_revealed` toont nu alleen bod/totalen. Verrijk
`cards_revealed_event` met beide kaartensets (`Card.to_dict()`-arrays) en toon
in het onthul-scherm de kaarten van de tegenstander (mini-CardViews of
compacte statregels). Werkt meteen ook tegen de AI.

**0.2 Camera-flip voor speler 2 (eis 3).**
Besloten mechanisme (uit de audit, door de review bevestigd): **draai de
camera/het bord 180° om het bordcentrum** — engine-coördinaten blijven
canoniek, picking (unproject), hp-bars, damage-floats en de opstellings-ghost
volgen automatisch. GEEN coördinaat-spiegeling in de client (klassieke bron
van gespiegelde-zet-bugs). Werk: `local_player_id`-parameter in de driver,
flip toepassen als die PLAYER_2 is, en de hardcoded teksten/kleuren
("Jij (rood)", `_player_name`, `_player_color`, HUD-teksten) parametriseren.
Testbaar nu al met een debug-vlag ("speel als blauw" vs AI).

**0.3 Engine-werklijst (kleine, geïsoleerde uitbreidingen):**
- `submit_doctrine(player_id, doctrine)` + beide-klaar-gate in PRE_GAME
  (blinde keuze verhuist van driver naar engine).
- `acknowledge_reveal(player_id)` met both-acked-gate (nu: het éérste ack laat
  de partij doorlopen → het reveal-scherm van de langzame lezer klapt dicht,
  precies terwijl eis 4 leestijd vraagt). Server-timeout erbij.
- **`submit_resign(player_id)`** — bestaat niet; zonder dit kan de server een
  forfeit alleen "faken" met een desync tussen log en engine als gevolg.
- **Remise/cycluslimiet** — er bestaat geen remise; twee spelers in een
  standoff (verwacht! zie spelregels §8 punt 1) schuiven eeuwig door. Neem de
  MatchRunner-tiebreak (materiaal → haven → haven-nabijheid) over als
  server-instelbare limiet (bv. 30 cycli), verankerd in engine of room-laag.
- `link_performed`-event met kaart-info (de UI leunt nu op state-reads).
- **Snapshot-serializer met per-speler-filter** (`GameState.to_view(player_id)`):
  - strip `cards_defined`/`all_cards` van de tegenstander vóór de reveal;
  - strip tijdens PLACEMENT de pionnen van de ander (blind opstellen!);
  - strip doctrine van de ander vóór wederzijdse keuze;
  - Vos: gedekte koppeling → stats vervangen door een `?`-sentinel
    (niet `-1`/0 — "lege blokjes" lekken ook informatie);
  - LET OP (audit): serialiseer kaarten éénmaal per id en reconstrueer
    referenties — het bestaande `clone()`-patroon breekt kaart-identiteit
    (drie losse kopieën van dezelfde Card → linking-fase eindigt nooit op een
    gedeserialiseerde state).
- **Event-log per match** (elke geaccepteerde submit + seed-loze determinisme
  = gratis replay, reconnect-herstel én telemetrie).

**0.4 Vos-"?"-weergave in de UI.**
De hp/stamina/attack-blokjes tonen nu alles, ook van gedekte Vos-pionnen
(bekend gat, ook offline). Bouw een "?"-staat voor de blokjes. Hoort bij de
view-filter, niet erna — anders crasht of lekt de hp-bar-code zodra de
gefilterde snapshot die stats terecht niet meer meestuurt.

**0.5 Touch-equivalenten voor rechtermuis.**
Placement-undo en Wolf-stap-overslaan zijn rechtermuis-only; hover-hints
bestaan niet op touch. Voeg on-screen knoppen toe ("Ongedaan", "Overslaan").
Zonder dit zit een Wolf-speler op een telefoon vast tot de timeout → onterecht
forfeit + boze feedback.

**0.6 Web-export-spike (vóór de netcode!).**
- Renderer: Forward+/D3D12 werkt niet op web → exporteer met
  `gl_compatibility` en draai een smoke-test mét de echte export-preset.
- Single-threaded build (geen COOP/COEP-gedoe) → **de AI-Thread in game.gd
  werkt daar niet**: vs-AI op web óf synchroon maken (Hard = ~400ms hitch,
  Ultra uitschakelen) óf uit de webbuild laten.
- Jolt zit niet in webtemplates (stille fallback naar GodotPhysics) — picking
  is al physics-vrij, maar zet `use_collision` van de 121 tegels uit.
- `?room=`-parsing op web kan alléén via JavaScriptBridge (niet cmdline).
- iOS Safari is de zwakste web-target; test vroeg of communiceer
  Android/desktop-first.

**Fase 0-testroute:** alles hierboven is vs-AI of met een tweede lokale client
tegen een localhost-server te testen (zie 1.6) — camera-flip, reveal-UI en
alle "wachten op tegenstander"-states zonder droplet, TLS of web-export. Zo
debug je nooit twee foutbronnen (view + netwerk) tegelijk.

---

## Fase 1 — Online MVP (eis 1: playtesten tegen elkaar)

**1.1 Server** (`server/` in dit repo, zelfde codebase):
- Headless Godot-proces op de droplet (systemd of pm2), luistert op een lokale
  poort; nginx doet `wss://fogofwar.<domein>/ws` → localhost.
- **Room = één `GameSession`-instantie** (MatchRunner-patroon). Rooms in een
  dictionary; één proces host tientallen potjes moeiteloos (turn-based).
  Valkuil uit de audit: GameSession is nu een autoload — de server instanceert
  het script los per room (zoals MatchRunner al doet).
- Server-side **beurt-timers** (de bestaande 20s wordt server-autoritatief;
  client-timer wordt puur weergave op basis van server-deadline) + timeout-
  gedrag: zelfde als offline (auto-define/-link/-zet). De client-side
  `PHASE_TIME_LIMIT` moet in online-modus aantoonbaar uit staan (geen twee
  vechtende klokken).
- Disconnect: 60s reconnect-venster (casual), daarna forfeit.

**1.2 Protocol** (JSON over WebSocket):
- `hello {name, device_token, protocol_version, rules_hash}` — server weigert
  mismatches met een duidelijke melding. **Rules-hash naast protocolversie**:
  de client draait Rules.gd lokaal voor highlights; juist dit spel gaat
  regel-knoppen omzetten tijdens playtests → stille regel-drift ("bij mij doet
  de knop niks") is verraderlijker dan protocol-drift.
- `create_room` → `{room_code}` (5 tekens, 31-alfabet zonder O/0/I/1),
  `join_room {code}`, `resume {match_id}`.
- In-game: 1-op-1 mapping op de bestaande API: `{action:"submit_move", ...}` →
  server valideert via engine → broadcast events (`phase_changed`,
  `turn_changed`, `action_performed` incl. het volledige result-dict — daar
  zit alle animatie-info al in — `cards_revealed` MET beide kaartensets,
  `wolf_step_pending`, `game_over`) + per speler een gefilterde
  `state_view`. `error_occurred` wordt géén broadcast maar gaat alleen naar de
  betreffende client, met request-id.
- Identiteit playtest-fase: displaynaam + client-gegenereerd device-token
  (UUID in `user://identity.cfg`; op web = IndexedDB). Token = ook de
  reconnect-sleutel (één mechanisme, geen aparte rejoin-tokens).
- Dubbele-tab-beleid: nieuwste verbinding met hetzelfde token wint de seat;
  de oude krijgt een nette melding.

**1.3 Client-refactor:**
- game.gd praat tegen een dunne interface: `LocalSession` (huidige autoload,
  vs-AI blijft exact zoals nu) of `RemoteSession` (WebSocket). De driver
  gebruikt al overal `submit_*` + signalen, dus dit is inpasbaar zonder
  herontwerp; de ongefilterde `GameSession.state`-reads verhuizen naar de
  laatst ontvangen `state_view`.
- **Render-vanaf-snapshot is de grootste verborgen klientpost** (reconnect!):
  elke fase moet opgebouwd kunnen worden uit een view (pawn-views, hp-bars,
  kaarthand-status, pending wolf-stap, reveal-overlay, beurt + deadline).
  Plan dit expliciet; het is méér dan de happy path.
- AI-gerelateerde driver-code (AI-submits, auto-link namens AI) draait online
  simpelweg niet: de tegenstander is een echte client (of een server-AI, 2.4).

**1.4 Deploy & ops:**
- Droplet: systemd-unit `fogofwar-server`, nginx-locatie met
  `limit_conn`/`limit_req` (rate-limiting hoort in nginx — in GDScript zie je
  achter de proxy alleen 127.0.0.1).
- **Deploy-drain**: rooms zijn in-memory; een restart doodt alle potjes.
  Minimaal: drain-modus (geen nieuwe rooms, herstart zodra leeg). Beter (de
  engine is deterministisch en het event-log bestaat): room-herstel door
  submit-log-replay in een verse GameSession.
- Client-distributie: Windows-build via itch/Drive; web-build op de droplet
  zodra de spike (0.6) groen is.

**1.5 Werkschatting (gereconcilieerd door de review):** reken op **60–90 uur**
voor Fase 0+1 samen (niet de optimistische 20–35): engine-uitbreidingen +
view-filter + serializer ≈ 20u, server/rooms/protocol ≈ 20u, client-refactor +
render-from-snapshot ≈ 20u, camera-flip + reveal-UI + touch ≈ 10u, deploy +
web-spike ≈ 10u.

**1.6 Mijlpalen (in volgorde):**
1. Twee clients lokaal tegen localhost-server: volledige partij (M1).
2. Zelfde over internet via de droplet + wss (M2).
3. Reconnect midden in elke fase werkt (M3).
4. Web-build speelt tegen desktop-build (M4) → **playtest-avond #1**.

---

## Fase 2 — Playtest-ops: lobby-lite, telemetrie, capaciteit

**2.1 Lobby-lite:** één schermflow: naam invullen → "Speel met code" (maak/join
private room) of "Snel spelen" (FIFO-wachtrij: eerste twee wachtenden worden
gekoppeld; geen rating). Roomcode deelbaar als link (web: via JavaScriptBridge).

**2.2 Telemetrie = het eigenlijke doel van de playtest.** Server logt per
match één JSON (schema v1):
- `match_id, started_at, build {git, rules_hash}, mode, seats [{name_hash,
  device_hash, is_ai, doctrine}]`
- verloop: `cycles, actions_total, per_type {moves, melees, shots, charges,
  wolf_steps}`, koppelverdeling kaart→type, schoten per kanon, charges per
  paard, gemiddelde `think_ms` per beslissing
- uitkomst: `winner_seat, win_condition ∈ {haven, eliminatie, resign,
  forfeit_afk, forfeit_disconnect, draw_cycle_limit}` — en die
  `draw_cycle_limit` bestaat écht (0.3).
- Dit beantwoordt direct de playtest-agenda uit `spelregels-v4.1.md` §8:
  winrate per matchup (21), haven- vs eliminatie-winst, standoff-lengte,
  1/5/1-oogstmachine, infanterie-koppelverdeling, kanon-schootsveld.
- **Vos-kanttekening (review):** de AI kijkt door de Vos-dekking heen
  (evaluate leest gedekte stats). Flag `is_ai`-potjes in Vos-matchups als
  vervuild voor agendapunt 8, tot er een fog-respecting eval is.

**2.3 Feedback-knop in de client:** commentaar + match_id → server. Goud
tijdens playtests; kost een avond.

**2.4 Server-AI als capaciteits-opvang:** "Speel vs AI (online)" zodat niemand
op een tegenstander wacht — hergebruikt de bestaande AI op de server. Besluit
(review): host maximaal **Medium** server-side (Hard ~400ms en Ultra 2,2s CPU
per zet verdringen andere rooms op de droplet); Ultra blijft lokaal.

**2.5 Mini-dashboard:** nachtelijke job zet de match-JSONs om in een statische
HTML (winrates per matchup, wincondities, partijlengtes) — zelfde droplet.

---

## Fase 3 — Competitief (eis 2: punten, leaderboard, matchmaking)

- **Identiteit:** device-token blijft; optioneel later platform-koppeling.
- **Rating: Glicko-2** (niet kale Elo): RD-onzekerheid past bij lage volumes
  en ís het placement-mechanisme (eerste 5 potjes geen notering, intern telt
  alles). Opslag: SQLite op de server (`ratings`, `rating_history`,
  `seasons`, `penalties`).
- **Leaderboard:** JSON-dump → statische webpagina + in-game top-lijst.
- **Matchmaking:** ranked wachtrij, rating-venster ±100 dat per 15s wachten
  verbreedt; wintrade-rem (zelfde tegenstander: vol/50/25/0% ratingeffect
  per dag).
- **Seizoenen:** ~3 maanden, soft reset (`1500 + (r−1500)×0.5`), gekoppeld aan
  `rules_version` zodat balansdata per regelversie schoon blijft. Beloningen
  cosmetisch.
- **Rematch:** room blijft 60s; seats wisselen, doctrines opnieuw blind
  (counterpick-gedrag = extra balansdata).
- **AFK/verlaten:** resign is legitiem (gewoon ratingverlies); afk/disconnect
  geeft escalerende wachtrij-lockouts (2→10→60 min); ranked reconnect-venster
  30s met doorlopende klok.

---

## Fase 4 — Dichttimmeren (later, zoals afgesproken)

- **Leak-canary in CI:** geautomatiseerde test die als speler 2 verbindt en
  asserteert dat geen enkel serverbericht verborgen velden bevat (opponent-
  defines vóór reveal, Vos-kaartidentiteit, blinde opstelling, doctrine vóór
  wederzijdse keuze). Dit is 90% van de echte anti-cheat in dit spel: de
  waardevolste cheat is een maphack, en die is puur server-discipline.
- **Replay-verificatie:** batchjob her-simuleert elk matchlog door een verse
  GameSession en vergelijkt de uitkomst (vangt serverbugs/desyncs/logcorruptie
  — essentieel zodra ratings op die data leunen).
- Timing-analyse voor botdetectie (think_ms zit al in het log; alleen flaggen,
  nooit auto-bannen), echte accounts, payload-caps, TLS-hardening, moderatie.

---

## Belangrijkste risico's (uit de adversariële review)

1. **Eeuwige partijen** — remise bestaat niet; zonder cycluslimiet eindigt de
   eerste playtest-avond met een potje dat niet kán aflopen. → 0.3, verplicht.
2. **Verborgen-info-lek** — volle GameState syncen lekt defines/Vos/opstelling;
   let ook op het `state_updated`-moment nádat één speler definieerde. → filter
   in 0.3, canary in Fase 4.
3. **Spiegel-bugs** — alleen camera-flip, nooit coördinaten spiegelen. → 0.2.
4. **Web ≠ desktop** — renderer, threads (AI!), Jolt-fallback, roomcode-parsing:
   spike vóór de netcode. → 0.6.
5. **Scope-optimisme** — reken met 60–90u tot playtest-avond #1, niet 20–35u.
6. **Deploys doden rooms** — drain of log-replay-herstel vanaf dag één. → 1.4.
7. **Kaart-identiteit bij serialisatie** — naïef clonen laat de koppelfase
   online nooit eindigen. → 0.3.

## Definitieve keuzes (om discussies te sluiten)

- Transport: **WebSocket + eigen JSON-protocol**, server-authoritative.
- Hosting: **bestaande DO-droplet**, headless Godot + nginx wss.
- P2-perspectief: **camera-flip** om het bordcentrum.
- Reconnect/identiteit: **één device-token** (UUID in user://), nieuwste tab wint.
- Roomcodes: **5 tekens, 31-alfabet**; quick-match = simpele FIFO (Fase 2).
- Rating: **Glicko-2 + SQLite**, pas in Fase 3.
- Server-AI: **max Medium** online; Ultra alleen lokaal.
