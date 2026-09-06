# Fog of War online hosten op een DigitalOcean-droplet (F4.4a)

Dit is de handleiding voor Max. Alles wat hier staat is op 4 september 2026
gebouwd en lokaal bewezen (pakket-proef, `npm run build`, nettest en
lobbycheck tegen de gebouwde server met het pakket als engine); de
Linux-kant draait pas op de droplet zelf.

## Wat er op de droplet komt te draaien

| onderdeel | wat | geheugen |
|---|---|---|
| nginx | https (Let's Encrypt), rate-limiting, doorgeven naar Node | klein |
| Node 22 | `server/` (Fastify), als systemd-service `fogofwar` | ~70 MB |
| Godot 4.7 headless | de scheidsrechter (`tools/server_worker.tscn`), kindproces van Node | ~140 MB |
| MySQL 8 | accounts, matches, het event-log | ~400 MB |

De scheidsrechter draait NIET het volle project (4,7 GB, import piekt op
7,5 GB werkgeheugen) maar het **server-pakket**: alleen `core/`,
`scripts/`, `agents/`, `net/`, `arena/`, `i18n/`, `data/` en de worker
zelf. Dat is 0,3 MB als tgz, importeert in seconden, en geeft dezelfde
core-hash als het volle project. `bouw_serverpakket.ps1 -Proef` bewijst
dat elke keer opnieuw.

## Eenmalig: de droplet (dit doe jij)

1. **Droplet aanmaken** in je DigitalOcean-account: Ubuntu 24.04, Basic,
   2 GB / 1 vCPU (ongeveer 12 dollar per maand), Amsterdam, met je
   SSH-sleutel. 1 GB is te krap door MySQL. Niet op de
   ReisLastMinute-droplet zetten: die deelt zijn geheugen al met elf
   PM2-apps en een productie-database.
2. **DNS**: een A-record voor een subdomein (bijvoorbeeld
   `fog.<jouw domein>`) naar het IP van de droplet. Wacht tot
   `nslookup fog.<domein>` het IP geeft; Let's Encrypt controleert dat.
3. **Inrichten**, vanuit de projectmap op Windows:
   ```powershell
   scp -r tools/deploy root@<ip>:/tmp/deploy
   ssh root@<ip> "DOMEIN=fog.<domein> EMAIL=<jouw e-mail> bash /tmp/deploy/droplet-setup.sh"
   ```
   Het script zet nginx, certbot, MySQL, Node 22, de Godot-binary, de
   service-gebruiker `fogofwar`, de systemd-unit en de firewall neer, en
   schrijft `/opt/fogofwar/server/.env` met een gegenereerd
   database-wachtwoord (alleen leesbaar voor de service). Het is
   idempotent: nog een keer draaien roteert het wachtwoord niet. Mislukt
   Let's Encrypt (DNS nog niet doorgekomen), dan zegt het script hoe je
   dat later los doet.

## Uitrollen (elke keer dat de server of de engine verandert)

```powershell
.\tools\deploy\deploy-server.ps1 -Droplet fog.<domein> -Nettest
```

Dat doet: pakket bouwen en bewijzen, server-bron inpakken, beide per scp
naar de droplet, daar importeren, `npm ci`, `npm run build`, engine
wisselen, service herstarten, wachten op `/gezond`, en dan vanaf Windows
`GET /versie` via https plus het 13-stappen contract (`-- nettest`)
tegen de droplet. Uitrollen kost enkele seconden zonder server: niet
midden in een playtest. Lopende partijen staan in de database en zijn
daarna te hervatten.

**Engine gewijzigd = twee dingen uitrollen.** De client weigert een
server met een andere core-hash (`GET /versie`). Elke wijziging onder
`core/` of in de zes kernscripts betekent dus: server uitrollen én een
nieuwe client-build aan de spelers geven.

## De client naar de spelers

- Zet in de editor de projectinstelling **`fogofwar/server_url`** op
  `https://fog.<domein>` (Project, Projectinstellingen, sectie
  "Fogofwar"). Dat is de standaard voor een verse installatie;
  `identity.cfg` en `-- server=<url>` gaan daar bovenop. Op jouw eigen
  machine blijft de dev-server staan zolang je `identity.cfg` niet
  weggooit; eenmaal starten met `-- server=https://fog.<domein>` schakelt
  om en onthoudt het.
- Exporteer een Windows-build (Project, Exporteren, Windows Desktop; de
  export-templates van 4.7 eenmalig downloaden via de editor). Deel de
  map via Drive of itch. Een speler start het spel, MULTIPLAYER, "Online
  (via de server)", en heeft geen commandoregel nodig.
- Voor jezelf: `-- identiteit=B` blijft de manier om twee vensters op één
  machine als twee accounts te draaien.

## Beheer op de droplet

```bash
journalctl -u fogofwar -f          # logboek van de server (live)
systemctl restart fogofwar         # herstarten
curl -s http://127.0.0.1:8787/versie
mysqldump fogofwar > ~/fogofwar-$(date +%F).sql   # back-up (als root)
```

- `.env` staat in `/opt/fogofwar/server/.env`; de engine in
  `/opt/fogofwar/engine` (de vorige in `engine.oud`); de Godot-binary in
  `/opt/fogofwar/godot/`.
- Rate-limiting zit in nginx (`/etc/nginx/conf.d/fogofwar-http.conf`):
  10 verzoeken per seconde per IP, burst 30. Een client pollt 2 per
  seconde; twee spelers achter één NAT zitten daar ruim onder.
- Node luistert alleen op 127.0.0.1; de firewall laat 22, 80 en 443
  door.

## Wat er nog niet is (en waar het in het plan zit)

- Verbindingsverlies midden in een zet en de WebSocket-push: F4.3j
  (de nginx-config laat de upgrade al door).
- Server-klokken, forfeit bij wegblijven, roomcodes: F4.4.
- Een Docker-variant: bewust niet. Docker Desktop start op Max' machine
  niet (WIP 9 augustus), en een droplet met systemd is één bewegend deel
  minder.

## Bestanden in deze map

| bestand | rol |
|---|---|
| `bouw_serverpakket.ps1` | bouwt `results/serverpakket(.tgz)`; `-Proef` bewijst dezelfde core-hash |
| `worker_proef.mjs` | praat NDJSON met een worker: handshake, ping, core_hash, init |
| `deploy-server.ps1` | de uitrol vanaf Windows (pakket, scp, ssh, versiecheck, `-Nettest`) |
| `droplet-setup.sh` | eenmalige inrichting van een verse Ubuntu 24.04-droplet |
| `op-droplet-uitrollen.sh` | draait op de droplet per uitrol (import, npm ci, build, wissel, herstart) |
| `fogofwar.service` | systemd-unit |
| `nginx-fogofwar.conf` | site-sjabloon (poort 80; certbot voegt 443 toe) |
| `nginx-fogofwar-http.conf` | http-context: rate-limit-zones en de WebSocket-map |
