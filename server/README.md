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

## Wat er staat (F4.1) en wat nog niet

Accounts (gast-eerst op device-token, e-mail-upgrade, profaniteitsfilter,
avatar, vriendcodes), matches met het idempotente actieprotocol
(seq_expected + idem_key, 409-met-inhaal), WebSocket + inhaal-endpoint.

Nog niet: de Godot-worker (F4.2) die acties door de echte engine haalt — tot
die er is echoot de server acties als `action_accepted`. OAuth-login komt
later als extra loginmethode (e-mail dekt cross-device al); de Redis-jobqueue
komt samen met zijn consument in F4.2.
