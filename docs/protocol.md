# Fog of War — online protocol (F4.1 t/m F4.2b)

> Status: eerste versie bij het backend-skelet van 9 augustus 2026, aangevuld
> op 3 september (F4.2b: redactie en toegang). Dit document is het contract
> tussen client, server en Godot-worker. Wijzigt er iets, dan wijzigt dit
> bestand mee in dezelfde commit.

## Uitgangspunten

- **Server-authoritative.** De client is een renderer met een lokale validator
  voor snelle highlights; de server (via de Godot-worker, F4.2) is de enige
  waarheid. Zelfde `core/`-bestanden aan beide kanten — een
  `core-hash`-vergelijking bewaakt dat client en worker dezelfde engine draaien.
- **Het event-log ís het spel.** Elke geaccepteerde actie wordt een rij in
  `match_events` met een dicht oplopend `seq`. Replay, reconnect, telemetrie
  en de battlereport zijn allemaal hetzelfde log.
- **Acties zijn `Actions.to_dict`-dicts** (JSON-veilig, `Vector2i` als
  `[x, y]`) — exact het formaat dat de engine sinds F0.3 spreekt, inclusief
  `choose_doctrine` (F4.0).
- **Views zijn `View.for_player`-dicts**; events naar clients gaan door
  `View.client_events()` (F4.0c). Het rauwe log blijft server-only: de acties
  daarin dragen blinde keuzes.

## Identiteit (accounts §9.1 — geïmplementeerd in F4.1)

Gast-eerst: het **device-token** (client-UUID, `user://identity.cfg`; web:
IndexedDB) is het account én de reconnect-sleutel.

| Route | Doet |
|---|---|
| `POST /auth/gast {device_token, naam?}` | maakt of herkent de speler; → `{sessie_token, user}` |
| `POST /auth/upgrade {email, wachtwoord}` | koppelt e-mail (cross-device); 409 als het adres al gekoppeld is |
| `POST /auth/login {email, wachtwoord, device_token?}` | zelfde account op een ander apparaat; neemt het nieuwe device-token over |
| `PATCH /profiel {naam?, avatar_doctrine?, avatar_kleur?}` | naam door het profaniteitsfilter; avatar = doctrine-embleem (0..5) + kleur |
| `POST /vrienden {code}` / `GET /vrienden` | vriendcodes: 8 tekens, 31-alfabet (geen O/0/I/1) |

Alle beveiligde routes: `Authorization: Bearer <sessie_token>`. De
WebSocket-route accepteert daarnaast `?token=<sessie_token>` (een browser kan
geen header op een WS-upgrade zetten); het serverlog redigeert dat token uit
de URL. Sessies zijn losse handles; het wachtwoord is scrypt-gehasht.
(Intrekken/verlopen van sessies: nog open.)

## Matches en het actieprotocol (bouwplan §10 — geïmplementeerd in F4.1)

| Route | Doet |
|---|---|
| `POST /matches {rules_version, rules_config}` | maakt de match; de maker is seat 1. `rules_config` is de VOLLEDIGE regels-dict (doctrines-blok en al): elke deelnemer speelt exact hetzelfde spel |
| `POST /matches/:id/join` | seat 2; match → `bezig`. Idempotent voor wie er al in zit |
| `GET /matches/:id` | status (`lobby`/`bezig`/`klaar`), jouw seat, beide namen, `winnaar_seat`, `eind_reden`, hoogste `seq`. Alleen voor wie een seat heeft (403) |
| `POST /matches/:id/acties {seq_expected, action, idem_key}` | zie hieronder. Na afloop: `409 {fout: "De match is afgelopen"}` |
| `GET /matches/:id/events?after=seq` | inhaal (reconnect, WS-gaten, polling-fallback). Alleen met een seat (403) |
| `GET /matches/:id/ws[?token=…]` | WebSocket: elke nieuwe event-batch gepusht, met seq. Zonder identiteit dicht met **4401**, zonder seat **4403**, onbekende match **4404** |

### De actie-indiening

```
POST /matches/:id/acties
{ "seq_expected": 12, "idem_key": "<client-uuid>", "action": {"type": "move", ...} }
```

- **200 `{events}`** — geaccepteerd; de events dragen `seq` 13, 14, …
- **200 `{events, herhaald: true}`** — deze `idem_key` was al verwerkt; je
  krijgt het oorspronkelijke antwoord terug (trein-tunnel-proof: de client
  mag blind opnieuw posten). Dit gaat vóór elke andere check, dus ook de
  herhaling van de actie die de match beëindigde blijft een 200.
- **409 `{events}`** — `seq_expected` loopt achter; de payload bevat de
  events SINDS jouw seq. Bijlopen, opnieuw indienen. Een 409 met `fout` en
  lege `events` betekent dat de match niet (meer) `bezig` is.
- **500 `{fout}`** — scheidsrechter of database niet beschikbaar; de melding
  is neutraal (details staan alleen in het serverlog).

De idempotentie leunt op de unieke index `(match_id, idem_key)`, het
seq-nummer op een `FOR UPDATE`-lock op de match-rij — beide zijn
database-garanties, geen applicatielogica.

### De scheidsrechter (F4.2 — gebouwd)

Elke actie gaat door de **Godot-worker**: een headless engine-proces met
exact dezelfde `core/`-bestanden als de client, gespawnd en beheerd door de
Node-backend, sprekend over NDJSON op een lokale TCP-poort. De worker is
**stateloos**: per verzoek krijgt hij het jongste snapshot plus de staart van
acties sindsdien (het MatchLog-fold-formaat), herbouwt de staat, haalt de
actie door `Validator`/`Reducer`, en geeft de reducer-events, de nieuwe staat
en de zobrist-hash terug. Node bewaart één rij per actie
(`action_applied`, payload `{action, events, hash}` — hetzelfde formaat als
een MatchLog-entry) en elke 50 acties een snapshot.

- Een **illegale actie** is een `422 {fout}` met de validator-tekst.
- **now_ms**: de server stempelt zijn eigen tijd; zonder klokken in de regels
  wordt bewust `-1` doorgegeven zodat een online partij byte-identiek blijft
  aan een offline replay (F4.0b).
- **Redactie (F4.2b, aangescherpt op 3 september)**: een client-rij is
  uitsluitend `{seq, player_seat, type, payload: {events}}`. Wat er NOOIT in
  zit: `payload.action` (draagt blinde keuzes), **`payload.hash`** (de zobrist
  over de volledige staat; met dezelfde engine is die te brute-forcen, en dat
  is aangetoond: factiekeuze uit 6 kandidaten, kaartdefinitie uit 1296 in
  11,5 s), en de server-only events `cycle_admin`, `cp_admin` (saldi van beide
  kanten) en **`cp_bet`** (de view verbergt bewust of de vijand in het
  define-venster inzet; de eigen inzet staat in de eigen view). De lijst
  staat op één plek in de engine (`View.SERVER_ONLY_EVENTS`, met een
  sluitende tweedeling tegen `View.CLIENT_EVENTS` die de ViewTests-canary
  over alle reducer-events afloopt) en op één plek in Node
  (`SERVER_ONLY_EVENTS` in `matches.ts`); de worker meldt zijn lijst bij de
  handshake en **Node weigert te starten** als ze verschillen (de worker
  start eager in `bouwApp`, dus dat is een opstartfout, geen 500 per verzoek).
  De hash blijft in de database voor replay-verificatie en de battlereport.
- **De CP-inzet reist in de define mee (F4.2b).** Een event-filter dicht niet
  dat een actie een RIJ is: een losse `bet_cp` levert een eigen `seq` met
  `player_seat`, en wie in het define-venster een vijandelijke rij ziet zonder
  dat `enemy_has_defined` omslaat, weet dat er ingezet is. Daarom kent
  `define_cards` het optionele veld **`cp_bet`** (`{type: "define_cards",
  cards: [...], cp_bet: 1}`): zelfde regels als een losse inzet, één actie, één
  rij, byte-identieke eindstaat. Een online client stuurt NOOIT een losse
  `bet_cp`; de engine laat hem toe (offline, arena, goldens) en de stream
  redigeert hem, maar de rij-telling verraadt dan de inzet.
- **Wat een client wél mag afleiden (bekend, geaccepteerd):** dat de vijand
  in CYCLE_SPAWN een lege pool had (de spawn-gate sluit dan meteen op jouw
  eigen inzet, dus de fasewissel zit in je eigen rij), en dat een match-id
  bestaat (404 voor onbekend, 403 zonder seat; ids zijn 122-bits UUID's).
- **Crash-veiligheid**: de database schrijft pas ná een worker-antwoord, dus
  een worker die midden in een verzoek sterft heeft niets veranderd; de pool
  herstart hem en de client-retry (zelfde `idem_key`) is per definitie
  veilig. Een Godot-binary die niet start (fout pad, geen rechten) is een
  nette 500 met het pad in de melding, geen crash van het Node-proces.
- **Verse checkout**: de worker heeft de import-cache van Godot nodig
  (`.godot/`, gitignored). Op een nieuwe machine of droplet eerst éénmalig
  `godot --headless --path . --import` draaien (minuten, en de import piekt op
  ~7,5 GB werkgeheugen); daarna meldt de worker zich in ~1,3 s gereed.
- `GET /matches/:id/view` levert jouw gefilterde `View.for_player`-dict (het
  render- en reconnect-startpunt voor de F4.3-client); `GET /versie` geeft de
  `core_hash` van de worker zodat een client kan weigeren met een andere
  engine te praten (bouwplan §11.5).

*Afwijking van het oorspronkelijke plan:* de masterplan-tekst noemde een
Redis-jobqueue tussen backend en worker. Dit is een synchrone zijspan
geworden — zelfde stateloosheid en schaalbaarheid (N workers), één bewegend
deel minder. Redis komt terug zodra er echt een wachtrij nodig is
(matchmaking-queues, F4.4+).

## De view (F4.3d)

`GET /matches/:id/view` levert `View.for_player` van jouw kant; de client
bouwt daar met `ClientState.uit_view` (net/client_state.gd, een wrapper om
`Agent.reconstruct_state`) een speelbare staat uit, alleen voor de renderer
en de lokale `Validator` (highlights). De client past NOOIT zelf
`Reducer.apply` toe: kaart-ids zijn server-toegewezen. Vier publieke sleutels
zijn er sinds F4.3d bijgekomen omdat een client ze nodig heeft en ze geen
geheim dragen: `last_initiative_winner` (tiebreak bij een gelijk bod),
`eind_reden`, `turn_deadline` en `clocks` (beide banken). Views komen als
JSON-tekst binnen: elk getal kan een float zijn en object-sleutels zijn
gesorteerd (Godot alfabetisch, Node numeriek), dus `uit_view` cast alles en
zet pionnen en kaarten weer op id-volgorde. Events gaan door
`EventCodec.van_json` (net/event_codec.gd): ints terug naar int, de
gesloten lijst Vector2i-sleutels (`from`, `target`, `move_target`,
`position`, `defender_pos`, `attacker_from_pos`, `charge_from`) terug naar
Vector2i, het bod (`bid`) blijft een float. `ClientStateTests` bewijst dit
door JSON-tekst heen: dezelfde legale acties als de volle staat in elke
rustfase van echte partijen, een gesloten lijst van toegestane afwijkingen,
en een codec-canary over alle client-events van een partij.

## De client (F4.3f)

`net/remote_session.gd` is de online sessie achter `SessionInterface`; zij
praat via een `Transport` (`net/transport.gd`, callback-stijl: `status`,
`view`, `acties`, `events`, push `rijen_binnen`). Boekhouding: `seq` is de
laatst verwerkte client-rij; elke rij (push, 200-antwoord, 409-inhaal,
`events`) gaat door één poort met dedupe op seq en strikte volgorde; vóór
het afspelen van een rij wordt de view ververst (staat vervangen), daarna
gaan de events door `EventCodec` naar de signals. Submits: lokale
`Validator`-voorcheck, verse `idem_key` per actie, 409 → inhalen en één
herindiening als de actie nog kan, 409 "De match is afgelopen" → status →
`game_over`, 422 → `error_occurred`. De client stuurt nooit een losse
`bet_cp`. `net/loopback_transport.gd` is dezelfde server in-proces (het
protocol op één GameState, alles door JSON-tekst) voor tests en de
oefenmodus; `RemoteSessionTests` bewijst dat een partij via de loopback
signal-voor-signal gelijk is aan een offline partij.

## Versies

Besluit F4.3d (default, 3 september; omkeerbaar): de client vergelijkt bij
het verbinden alleen de **`core_hash`** (`GET /versie`) met de zijne en
weigert bij verschil. Een aparte `rules_hash` is overbodig: de server
dicteert `rules_config` per match en de view brengt de regels mee, dus
regel-drift tussen client en server kan alleen ontstaan als de engine
verschilt, en dat vangt de core-hash. Een `protocol_version` komt erbij
zodra het protocol een tweede versie krijgt.

## Nog open (F4.4+)

Roomcodes/publieke queue, rematch, server-klokprofiel (beslisagenda: bank 180 /
increment 5 / grace 60), deadline-jobs, replay-download, web-export.
