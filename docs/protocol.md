# Fog of War — online protocol (F4.1, concept)

> Status: eerste versie bij het backend-skelet van 9 augustus 2026. Dit
> document is het contract tussen client, server en Godot-worker. Wijzigt er
> iets, dan wijzigt dit bestand mee in dezelfde commit.

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

Alle beveiligde routes: `Authorization: Bearer <sessie_token>`. Sessies zijn
losse, intrekbare handles; het wachtwoord is scrypt-gehasht.

## Matches en het actieprotocol (bouwplan §10 — geïmplementeerd in F4.1)

| Route | Doet |
|---|---|
| `POST /matches {rules_version, rules_config}` | maakt de match; de maker is seat 1. `rules_config` is de VOLLEDIGE regels-dict (doctrines-blok en al): elke deelnemer speelt exact hetzelfde spel |
| `POST /matches/:id/join` | seat 2; match → `bezig`. Idempotent voor wie er al in zit |
| `POST /matches/:id/acties {seq_expected, action, idem_key}` | zie hieronder |
| `GET /matches/:id/events?after=seq` | inhaal (reconnect, WS-gaten, polling-fallback) |
| `GET /matches/:id/ws` | WebSocket: elke nieuwe event-batch gepusht, met seq |

### De actie-indiening

```
POST /matches/:id/acties
{ "seq_expected": 12, "idem_key": "<client-uuid>", "action": {"type": "move", ...} }
```

- **200 `{events}`** — geaccepteerd; de events dragen `seq` 13, 14, …
- **200 `{events, herhaald: true}`** — deze `idem_key` was al verwerkt; je
  krijgt het oorspronkelijke antwoord terug (trein-tunnel-proof: de client
  mag blind opnieuw posten).
- **409 `{events}`** — `seq_expected` loopt achter; de payload bevat de
  events SINDS jouw seq. Bijlopen, opnieuw indienen.

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
- **Redactie**: clients krijgen nooit `payload.action` (draagt blinde
  keuzes) en nooit de twee server-only admin-events — de Node-kant spiegelt
  `View.client_events`, met tests op beide oevers.
- **Crash-veiligheid**: de database schrijft pas ná een worker-antwoord, dus
  een worker die midden in een verzoek sterft heeft niets veranderd; de pool
  herstart hem en de client-retry (zelfde `idem_key`) is per definitie
  veilig.
- `GET /matches/:id/view` levert jouw gefilterde `View.for_player`-dict (het
  render- en reconnect-startpunt voor de F4.3-client); `GET /versie` geeft de
  `core_hash` van de worker zodat een client kan weigeren met een andere
  engine te praten (bouwplan §11.5).

*Afwijking van het oorspronkelijke plan:* de masterplan-tekst noemde een
Redis-jobqueue tussen backend en worker. Dit is een synchrone zijspan
geworden — zelfde stateloosheid en schaalbaarheid (N workers), één bewegend
deel minder. Redis komt terug zodra er echt een wachtrij nodig is
(matchmaking-queues, F4.4+).

## Versies

De client meldt bij het verbinden `protocol_version` én `rules_hash` (hash
van de actieve regels-json). De server weigert een mismatch met een duidelijke
melding: juist dit spel verzet regel-knoppen tijdens playtests, en stille
regel-drift ("bij mij doet die knop niks") is verraderlijker dan
protocol-drift.

## Nog open (F4.4+)

Roomcodes/publieke queue, rematch, server-klokprofiel (beslisagenda: bank 180 /
increment 5 / grace 60), deadline-jobs, replay-download, web-export.
