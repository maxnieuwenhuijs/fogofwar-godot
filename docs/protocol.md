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

### Wat F4.2 hieraan toevoegt (nog niet gebouwd)

In F4.1 accepteert de server acties als transport: het event is een
`action_accepted`-echo. De Godot-worker (F4.2) gaat elke actie door
`Validator.is_legal` + `Reducer.apply` halen; het event wordt dan de ECHTE
reducer-uitvoer (per speler geredigeerd via `View.client_events`), plus een
snapshot elke 50 events. De 200/409/idem-semantiek verandert daarbij niet —
alleen de inhoud van `events`, en een illegale actie wordt een `4xx` in
plaats van een echo. Kloktijden: de worker stempelt `now_ms` (servertijd) en
het log draagt hem mee (F4.0b), zodat elke partij hash-getrouw naspeelbaar is.

## Versies

De client meldt bij het verbinden `protocol_version` én `rules_hash` (hash
van de actieve regels-json). De server weigert een mismatch met een duidelijke
melding: juist dit spel verzet regel-knoppen tijdens playtests, en stille
regel-drift ("bij mij doet die knop niks") is verraderlijker dan
protocol-drift.

## Nog open (F4.4+)

Roomcodes/publieke queue, rematch, server-klokprofiel (beslisagenda: bank 180 /
increment 5 / grace 60), deadline-jobs, replay-download, web-export.
