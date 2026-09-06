# Online hosten op DigitalOcean: stappenplan voor Max

Doel: twee mensen spelen over internet tegen de server op jouw eigen droplet.
Actieve tijd: ongeveer een half uur, plus wachten op DNS. Alle scripts staan in
`tools/deploy/` (achtergrond en beheer: `tools/deploy/README.md`). Vink af wat
klaar is; bij een fout: de laatste 30 regels uitvoer naar mij, dan kijk ik mee.

Vul in zodra bekend:

```
IP van de droplet : ............
Subdomein         : fog.............
E-mail (certbot)  : ............
```

## Vooraf (eenmalig)

- [ ] Je hebt een domein waar je een subdomein op kunt zetten (bijvoorbeeld
      `fog.jouwdomein.nl`).
- [ ] Er staat een SSH-sleutel op deze pc. Controle in PowerShell:
      `Get-Content ~\.ssh\id_ed25519.pub`. Bestaat hij niet:
      `ssh-keygen -t ed25519` (Enter op alle vragen) en daarna de inhoud van
      dat `.pub`-bestand bij DigitalOcean onder Settings, Security, SSH keys
      plakken.

## Stap 1: de droplet aanmaken (5 minuten)

In DigitalOcean: Create, Droplets.

- [ ] Regio: Amsterdam (AMS3).
- [ ] Image: Ubuntu 24.04 LTS.
- [ ] Plan: Basic, Regular, **2 GB / 1 vCPU** (ongeveer 12 dollar per maand).
      1 GB is te krap door MySQL. Niet de ReisLastMinute-droplet gebruiken.
- [ ] Authentication: SSH key, jouw sleutel aanvinken.
- [ ] Hostname: `fog-of-war`. Create Droplet.
- [ ] Noteer het IPv4-adres bovenaan.
- [ ] Test vanuit PowerShell: `ssh root@<ip>`. Bij de vraag over de
      fingerprint: `yes`. Je ziet een Ubuntu-prompt. `exit`.

## Stap 2: DNS (5 minuten, dan wachten)

Bij het beheer van je domein:

- [ ] Nieuw A-record: naam `fog`, waarde het IP van stap 1, TTL zo laag als
      mag (300 seconden).
- [ ] Controle in PowerShell: `nslookup fog.jouwdomein.nl`. Pas verder als
      dit het IP van de droplet geeft; dat kan tot een uur duren. Let's
      Encrypt (stap 3) controleert precies dit.

## Stap 3: de droplet inrichten (10 minuten, eenmalig)

In PowerShell, in de projectmap (`C:\Users\maxni\Documents\fog-of-war-0.1`):

```powershell
scp -r tools/deploy root@<ip>:/tmp/deploy
```

```powershell
ssh root@<ip> "DOMEIN=fog.jouwdomein.nl EMAIL=jouw@mail.nl bash /tmp/deploy/droplet-setup.sh"
```

Het script zet nginx met Let's Encrypt, MySQL, Node 22, de Godot-binary, de
service en de firewall neer en genereert zelf een database-wachtwoord (je
hoeft niets in te typen). Het is veilig om het nog een keer te draaien.

- [ ] Aan het eind staat er `https staat` en `Klaar. Nu vanaf Windows ...`.
- [ ] Staat er in plaats daarvan `LET OP: certbot mislukte`: de DNS is nog
      niet doorgekomen. Wacht, controleer stap 2, en draai dan alleen dit:
      `ssh root@<ip> "certbot --nginx -d fog.jouwdomein.nl -m jouw@mail.nl --agree-tos --redirect"`.
- [ ] Iets anders mislukt: uitvoer naar mij.

## Stap 4: de eerste uitrol (5 minuten; dit is ook de stap voor elke update)

```powershell
.\tools\deploy\deploy-server.ps1 -Droplet fog.jouwdomein.nl -Nettest
```

Wat er gebeurt: het server-pakket wordt gebouwd en bewezen (`PROEF OK`), de
server-code en het pakket gaan per scp naar de droplet, daar wordt
geïmporteerd, gebouwd en herstart, en daarna test dit script vanaf jouw pc de
echte server via https.

- [ ] `PROEF OK: pakket en volle project geven dezelfde core-hash en init-hash.`
- [ ] `== klaar` (van de droplet) en daaronder `publiek: https://fog.../versie -> core_hash=...`
- [ ] `[NETTEST] PASS: 13 stappen, 0 fouten`.
- [ ] Mislukt de proef: mij melden (dan klopt er iets in de repo, niet op de
      droplet). Mislukt het op de droplet: de uitvoer naar mij. Alleen de
      publieke check mislukt: DNS of certificaat, terug naar stap 2 en 3.

## Stap 5: zelf proberen (5 minuten)

- [ ] Start het spel één keer met de server-url erbij, in PowerShell in de
      projectmap:
      `& $env:GODOT_PATH --path . -- server=https://fog.jouwdomein.nl`
      (of het volledige pad naar `Godot_v4.7-stable_win64.exe`). Daarna
      onthoudt `identity.cfg` de url; de vlag is dan niet meer nodig.
- [ ] MULTIPLAYER, "Online (via de server)", "Nieuwe match". Je ziet de
      match-id groot in beeld.
- [ ] Tweede venster op dezelfde pc met een tweede account:
      `& $env:GODOT_PATH --path . -- identiteit=B server=https://fog.jouwdomein.nl`,
      MULTIPLAYER, Online, "Meedoen met een match-id", de id plakken.
- [ ] Beide kiezen een factie, opstellen, een paar zetten doen. Werkt dit, dan
      werkt het voor iedereen op internet.

## Stap 6: een build voor je testers (15 minuten, eenmalig per engine-versie)

- [ ] Godot-editor: Project, Project Settings, zoek `server_url` (sectie
      Fogofwar). Zet hem op `https://fog.jouwdomein.nl`. Dat is de standaard
      voor een verse installatie; jouw eigen `identity.cfg` houdt de
      dev-server, dus dit mag gewoon gecommit worden.
- [ ] Project, Export, Add..., Windows Desktop. De eerste keer vraagt de
      editor om export-templates: Manage Export Templates, Download and
      Install (versie 4.7.stable, eenmalig, ongeveer 1 GB).
- [ ] Export Project naar een lege map, bijvoorbeeld `build\FogOfWar\`, met
      bestandsnaam `FogOfWar.exe`. De map zippen en delen via Drive of itch.
- [ ] Een tester pakt uit, start `FogOfWar.exe`, MULTIPLAYER, Online, Meedoen
      met jouw match-id. Geen commandoregel nodig.

## Daarna, elke keer

- Server of engine gewijzigd: **stap 4 opnieuw**. Engine gewijzigd (iets
  onder `core/` of in de zes kernscripts): **ook stap 6 opnieuw**, anders
  weigert de client met een versiefout (core-hash).
- Uitrollen kost enkele seconden zonder server: niet midden in een partij.
  Lopende partijen zijn daarna te hervatten met "Laatste match hervatten".
- Meekijken wat de server doet: `ssh root@<ip> "journalctl -u fogofwar -f"`
  (stoppen met Ctrl+C).
- Back-up van de database: `ssh root@<ip> "mysqldump fogofwar" > fogofwar-backup.sql`.

## Als het misgaat

| wat je ziet | waarschijnlijk | wat te doen |
|---|---|---|
| "Geen verbinding" in het spel | verkeerde url, of de server staat stil | `ssh root@<ip> "systemctl status fogofwar"`; herstart met `systemctl restart fogofwar` |
| versiefout bij verbinden | client-build en server hebben een andere engine | stap 4 en stap 6 opnieuw, in die volgorde |
| de server stopt steeds | crash bij het opstarten (database, Godot-pad) | `ssh root@<ip> "journalctl -u fogofwar -n 50"`, uitvoer naar mij |
| certbot faalt | DNS wijst nog niet naar de droplet | stap 2 afwachten, dan het certbot-commando uit stap 3 |
| `PROEF MISLUKT` lokaal | het pakket wijkt af van het volle project | mij melden, niet uitrollen |

## Wat nog niet werkt (bewust, staat in het plan)

- Verbindingsverlies midden in een zet netjes opvangen en de WebSocket-push:
  F4.3j (de volgende bouwstap).
- Server-klokken, forfeit bij wegblijven, korte roomcodes: F4.4.
- Nu pollt de client elke halve seconde; een zet van de ander komt dus tot
  een halve seconde later in beeld.
