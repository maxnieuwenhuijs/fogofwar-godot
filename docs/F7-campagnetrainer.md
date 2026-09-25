# F7.2 — De campagnetrainer: hoe bots handelen in het campagnemenu

> **Status (25 september 2026): stap 1 t/m 4 gebouwd, wacht op de datarun.**
> Stap 1 (arena), 2 (orakel), 3 (verstand) en 4 (trainer, paneelkader
> "Campagnebots") staan; zonder `data/duel_orakel.json` en
> `data/campagne_verstand.json` spelen de bots zoals in juli. Volgorde voor
> Max: duels meten, trainen, nameten op echte duels (§5). Aanleiding, Max:
> "ook hier moeten we een campagne trainer strategie maken voor de bots, hoe te
> handelen in de campaign menu". Dit is F7.2 uit het masterplan
> (campagnegewichten-evolutie, apart van de duelgewichten). De open keuzes
> onderaan hebben een default; die gelden tot Max iets anders zegt.

## 1. Wat een bot in het menu beslist

De duel-trainer leert hoe een bot op het BORD speelt. Deze trainer leert wat een
bot in de HUB doet, tussen de duels door. Dat zijn vijf keuzemomenten:

| Keuzemoment | Nu (met de hand, `CampaignAgent`) | Wat de trainer leert |
|---|---|---|
| **Raad**: wie van ons vecht, tegen wie | pool-heuristiek per archetype (zwakste vijand of de tank laten bloeden, sterkste eigen, zelf gaan) | de kans dat ONZE vechter DIE vijand verslaat: factie tegen factie, reserve, CP (uit het duel-orakel, §3); zelf gaan of sparen; wie er nog moet vechten |
| **Donaties**: aan wie, hoeveel, pionnen of CP | vaste fractie `vrijgevigheid` naar de eerste vechter | wat een extra punt aan de winkans van elke vechter toevoegt (het orakel), hoeveel je zelf nodig hebt voor je eigen duels, en wie je straks in de finale treft (P3) |
| **Ruil**: CP naar versterkingen | doen bots nooit | wanneer CP meer waard is als versterking dan als inzet |
| **Testament**: team of vijand, aan wie | `loyaliteit` en de grootste pool | aan wie het de meeste winkans oplevert |
| **Quick chat**: toezeggen en nakomen | karakter (`loyaliteit`, `vrijgevigheid`, `w_zelf`) | **niet getraind**: dit is karakter (P4: leesbaar en feilbaar), en er is in de training geen mens die iets vraagt |

## 2. Verstand plus karakter

Getraind wordt een **verstand**: een gewichtenvector die voor alle bots gelijk
is. Het **karakter** blijft een vaste afwijking per archetype uit
`personalities.gd`. Een bot rekent met `verstand + karakter`. Zo blijft de rat
een rat en de gierigaard gierig (identiteitsrem, net als in de factiezoeker),
maar spelen ze allemaal beter dan de handgewichten van juli.

Zonder getraind bestand (`data/campagne_verstand.json`) is het verstand nul en
speelt alles zoals nu: byte-identiek, dus de goldens, SoloTests en de
determinisme-tests blijven staan.

## 3. Het duel-orakel (de snelheid)

**Gemeten 25 september:** een volledige campagne met 16 bots en echte duels
(`-- solocheck`) duurt minuten. Een trainer heeft er tienduizenden nodig
(elke kandidaat tegen de kampioen, honderden seeds, want een teamzege is een
muntworp met veel ruis). Met echte duels is dat maanden rekenen.

Maar een campagne-duel hangt van weinig af: **de twee facties, de reserve die
meegaat (per type, samen hooguit `duel_spawn_totaal_max`) en de CP van beide
kanten**. Het veldleger is altijd vol (C10). Die ruimte is klein genoeg om met
echte duels in kaart te brengen:

1. **Datarun** (Max start hem, B13): `campagne_arena.ps1` met een
   `"soort": "duels"`-config speelt duels met de bots van de campagne over die
   hele ruimte en schrijft per duel de invoer en de uitkomst (winnaar,
   methode, ingezette reserve per type, CP-verschil, buit, cycli) naar
   `duels.jsonl`. Echte campagnes (`"soort": "campagnes"`) schrijven hetzelfde
   formaat, dus ook die tellen mee.
2. **Orakel** (`tools/campagne/maak_orakel.py` → `data/duel_orakel.json`): per
   factiepaar de gemeten duels, gegroepeerd op reserve- en CP-verschil. Het
   orakel trekt voor een nieuw duel een ECHT gespeeld duel uit de dichtstbijzijnde
   groep. Geen modelaannames: wat het teruggeeft is ooit zo gebeurd.
3. **Validatie**: per factiepaar en per groep moet de winkans van het orakel
   binnen 3 procentpunt van de echte liggen; anders meer data.
4. `SoloDriver.duel_modus = "orakel"` speelt de campagne met het orakel: een
   campagne kost dan milliseconden in plaats van minuten.

**Het orakel is een meetlat, geen spel.** De mens speelt altijd echt, en de
kampioen van de trainer wordt altijd nagemeten op echte duels (§5, stap 5),
anders leert hij de gaten in het orakel in plaats van de campagne.

## 4. Fitness en toernooi

- **Teamfitness (eerst):** de kandidaat speelt alle acht stoelen van team A,
  de kampioen team B; dezelfde seeds nog eens met de teams gewisseld. Score =
  hoe vaak het team van de kandidaat de oorlog wint (de kampioen komt uit dat
  team). Dit leert hoe een TEAM moet handelen.
- **Eigen belang (daarna, P3):** gemengde teams (vier stoelen kandidaat, vier
  kampioen) en dan de kans dat de kampioen van de campagne uit de
  kandidaatgroep komt. Dit leert wanneer geven je eigen finalist bewapent.
- **Zoeker:** CMA-lite zoals de duel-trainer (populatie 16-24, relatieve
  adoptiepoort, convergentiecheck), reproduceerbaar via (git-sha, regels, seed).
- **CHECK (masterplan F7.2):** de kampioen van generatie N verslaat die van
  N-5 met meer dan 55% op vaste seeds; en op echte duels verslaat de kampioen
  de handgewichten met meer dan 55% over minstens 200 campagnes.

## 5. Bouwstappen

1. **F7.1a Campagne-arena** (25 september): `arena/campagne_arena.gd` achter
   `--campagne` in `arena/run.gd`, launcher `campagne_arena.ps1`. Twee
   soorten runs: `campagnes` (volledige campagnes, per team een eigen set
   gewichten, samenvatting per campagne in `campagnes.jsonl`) en `duels`
   (losse duels over de invoerruimte). Beide schrijven `duels.jsonl`. De
   duel-uitkomst is uit `verwerk_duel_uitslag` getild naar
   `SoloDriver.duel_uitkomst`, zodat de campagne en de datarun hetzelfde
   tellen.
2. **F7.1b Orakel**: `maak_orakel.py`, `DuelOrakel` in GDScript,
   `duel_modus = "orakel"`, validatie tegen de echte duels.
3. **F7.2a Verstand**: `CampaignAgent` rekent met kenmerken (matchupkans uit
   het orakel, reserve, CP, wie nog moet vechten, afstand tot de finale) en
   leert ruilen; verstand nul = het huidige gedrag.
4. **F7.2b Trainer**: `-- campagnetrain` + paneelknop "Campagnebots trainen";
   schrijft `data/campagne_verstand.json` (apart committen, zoals de
   duelgewichten).
5. **F7.2c Validatie op echte duels**: kampioen tegen de handgewichten,
   minstens 200 echte campagnes (nachtrun, Max start).

## 5b. Wat de rooktests lieten zien (25 september)

- Een `easy`-duel ~40 s, L2 ~48 s; een echte campagne ~10 minuten.
- Het orakel (op 14 rookduels, alleen om de keten te testen): 70 ms per
  campagne, 3-6 rondes, 15-17 duels. De eerste versie schaalde de inzet per
  soort; dan raakte een verliezer nooit leeg en duurden campagnes 100+
  rondes. Nu: hetzelfde AANDEEL van de reserve in punten.
- Validatie van een echt orakel moet dus ook de campagneduur vergelijken
  (rondes en duels per campagne, orakel tegen echt), niet alleen de
  winkans per duel.
- Gevonden: `pool_totaal_van` telt stuks, de reserve rekent in punten (C11);
  de uitvalcheck C3 gebruikt de stukstelling. Beslissing voor Max.

## 6. Open keuzes (met de default die nu geldt)

- **Welke duel-AI voor bots in de campagne?** Default: `easy`, zoals de hub nu
  speelt (bloedig genoeg voor de attritie, snel genoeg). Het orakel meet wat
  de campagne speelt; wisselt dat, dan een nieuwe datarun.
- **Een verstand voor alle facties, of een per factie?** Default: een, want
  de matchupkans uit het orakel draagt het factieverschil al.
- **Leren de bots van de quick chat?** Default: nee (karakter, §1).
- **Mag de trainer het karakter aanraken?** Default: nee. Wie een ander
  karakter wil, past `personalities.gd` aan; dat is ontwerp, geen training.
