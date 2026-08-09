# Fog of War — backend (F4)

Node 22 + Fastify + MySQL. Contract: `docs/protocol.md`. Schema:
`db/migrations/` (draait vanzelf bij het opstarten).

## Ontwikkelen op deze machine

Docker Desktop start hier niet (Windows-bug: AF_UNIX-socketbestanden krijgen
onverwijderbare reparse-points, fout 1920, overleeft een herstart — zie
WIP.md 9 augustus). Daarom draait er een LOKALE MySQL zonder Docker, als
gewoon programma zonder adminrechten in `~/fogofwar-mysql/`:

```powershell
# starten (idempotent):
./db-lokaal.ps1
```

Daarna:

```powershell
cd server
npm install
$env:FOW_TEST_DB_URL = "mysql://root@127.0.0.1:3316/fogofwar_test"; npm test
$env:DB_URL = "mysql://root@127.0.0.1:3316/fogofwar"; npm run dev
```

- **`FOW_TEST_DB_URL` gezet** → de tests gebruiken die server en WISSEN de
  database uit de URL per run (dus nooit een database met echte data invullen).
- **Niet gezet** → de tests trekken zelf een MySQL op via testcontainers
  (CI, machines met werkende Docker). Zelfde tests, zelfde dekking.

De databaseserver luistert alleen op 127.0.0.1:3316, root zonder wachtwoord:
prima voor lokaal ontwikkelen, uiteraard nooit voor de droplet.

## Wat er staat (F4.1 + F4.2)

Accounts (gast-eerst op device-token, e-mail-upgrade, profaniteitsfilter,
avatar, vriendcodes), matches met het idempotente actieprotocol
(seq_expected + idem_key, 409-met-inhaal), WebSocket + inhaal-endpoint, en
sinds F4.2 de **Godot-worker**: elke actie gaat door de echte engine
(`tools/server_worker.tscn`, gespawnd door `src/worker.ts`, NDJSON over een
lokale TCP-poort). Illegaal = 422. `GET /matches/:id/view` = jouw gefilterde
fog-view, `GET /versie` = de core-hash van de engine. De pariteit is bewezen:
een volledige offline opgenomen partij door de server naspelen eindigt op
dezelfde zobrist-hash.

De worker heeft de Godot-binary nodig: env `GODOT_PAD` (valt terug op het
bekende pad van deze machine). Nog niet: OAuth-login (e-mail dekt
cross-device al) en Redis (komt met de matchmaking-wachtrij, F4.4+).
