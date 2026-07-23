# Fog of War — Spelregels (spec)

> **Deel A** legt vast wat de engine vandaag écht doet: regelversie **4.1.10-hr**
> (de huisregels zoals geïmplementeerd, gecodificeerd juli 2026 via volledige
> code-extractie + kruischeck tegen `spelregels-v4.1.md`). Elke regel draagt zijn
> codebron. Wijkt dit document af van de code, dan is dat een bug in één van beide
> en hoort er een entry in `spelregels-CHANGELOG.md` bij.
> **Deel B** is het 4.2.0-concept (campagne-economie): alles daarin is **TE
> BEVESTIGEN** tot de F2.1-ontwerpsessie het vastklikt.

---

# DEEL A — Regelversie 4.1.10-hr

## 1. Bord & winnen

- Het bord is **11×11**; alleen posities met x en y van 0 t/m 10 bestaan. Alles
  (bewegen, melee, schieten) werkt uitsluitend **orthogonaal** via de 4 buurvakken;
  diagonalen bestaan niet. `constants.gd:3,197-203`
- Elke speler heeft **5 havenvakken** aan de overkant: Speler 1 (start rij 10/9)
  moet naar rij 0 op x ∈ {0,4,5,6,10}; Speler 2 (start rij 0/1) naar rij 10,
  zelfde kolommen. `constants.gd:104-118,183-187`
- **Winnen:** 2 eigen pionnen tegelijk op eigen havenvakken. Gekoppeld of
  ongekoppeld maakt niet uit — alleen eigenaar, levend en positie tellen.
  `Rules.gd:24-35, constants.gd:5`
- Je wint ook door **uitroeiing**: de tegenstander heeft 0 levende pionnen en jij
  minstens 1. `Rules.gd:36-41`
- De win-check draait na elke actie (ook na een Wolf-stap of het overslaan ervan)
  en direct na de cyclus-reset. `GameSession.gd:349-371,391-398`
- *Randgevallen:* voldoen beide spelers tegelijk aan de havenvoorwaarde, dan wint
  Speler 1 (checkvolgorde). Hebben beide spelers 0 pionnen, dan wijst de check
  geen winnaar aan (-1); een remise-uitkomst bestaat in 4.1.9-hr niet.
  `Rules.gd:33-42`

## 2. Partijverloop

- Fasen: PRE_GAME → PLACEMENT → per setup-ronde {DEFINE → REVEAL → LINKING} ×3 →
  ACTION → (bij winst) GAME_OVER. `Phase.gd:4-18`
- Een **cyclus** = 3 setup-rondes + 1 actiefase. Na de koppelfase van ronde 1/2
  volgt de define van de volgende ronde; na ronde 3 begint de actiefase.
  `GameSession.gd:207-215, constants.gd:4`
- Doctrine-keuze staat vast voor de hele partij. Het spel begint in cyclus 1,
  ronde 1. `GameSession.gd:23-30`
- **Cyclus-reset** (niemand kan meer handelen): alle overlevende pionnen verliezen
  hun kaart en worden inactief (HP/stamina/aanval → 0; Krokodil-verhulling weer
  openbaar), kaartlijsten geleegd, openstaande Wolf-stap vervalt, cyclus +1, ronde
  naar 1. Posities blijven staan; geëlimineerde pionnen komen nooit terug. Er komt
  géén nieuwe opstellingsfase. Vóór de nieuwe cyclus draait eerst de win-check.
  `GameState.gd:221-232, Pawn.gd:38-46, GameSession.gd:391-401`

## 3. Opstelling

- Elke speler plaatst zijn **volledige leger** vrij binnen zijn twee thuisrijen
  (P1: rij 10+9, P2: rij 0+1). Geldig = exact de doctrine-samenstelling, alles
  binnen eigen rijen, geen dubbele bezetting. `GameState.gd:150-170`
- Opstellen is simultaan en blind (éénmalig indienen; pas als beide binnen zijn
  start cyclus 1). Sinds F0.6 dwingt de view-laag de blindheid ook in de data
  af (vijandelijke pionnen bestaan niet in jouw view tijdens PLACEMENT).
- **Standaard-opstelling** (auto-plaatsing): artillerie voorste rij op kolommen
  0/10/5; infanterie voorste rij centrum-uit, dan achterste rij centrum-uit;
  cavalerie achterste rij flanken-eerst met overloop naar voor.
  `GameState.gd:88-147`

## 4. Kaarten definiëren

- Per setup-ronde dient elke speler kaarten in: **het doctrine-aantal
  (Varken/Beer/Wolf/Krokodil 3, Muis 4, Leeuw 2), maar nooit méér dan je
  vrije (levende, ongekoppelde) pionnen** (4.1.10-hr). Nul vrije pionnen =
  ronde overslaan; de tegenstander gaat alleen door. Eénmalig, simultaan en
  blind (commit-gate: pas door als iedereen die moet, binnen is).
  `Validator.expected_define_count, Reducer._check_define_gate`
- Een kaart heeft **HP / Speed / Aanval**: elke stat ≥ 1 en de som **exact** het
  doctrine-budget (5/7/9). Beer: Speed ≤ 3. Eén ongeldige kaart verwerpt de hele
  indiening. Hoogst mogelijke losse stat = budget − 2. `Card.gd:22-27`
- Kaarten zijn **typeloos**: elke kaart mag op elk eigen pion-type gekoppeld
  worden; de betekenis van de stats ontstaat pas bij de koppeling.
  `GameSession.gd:147-168`
- Een kaart hoort bij de ronde waarin hij gedefinieerd is en kan alleen in die
  ronde gekoppeld worden. `GameSession.gd:78-85,155`

## 5. Reveal & initiatief

- Bij de reveal worden beide kaartsets tegelijk onthuld; beide spelers zien de
  stat-totalen en het bod van beide kanten plus de initiatiefwinnaar. Daarna is
  een expliciete bevestiging (acknowledge) nodig; die is idempotent.
  `GameSession.gd:97-118`
- **Bod-formule:** bod = (Σ stat − n) / (n × (budget − 3)) over de onthulde
  kaarten (n = aantal). 0 kaarten of budget ≤ 3 → bod 0. Genormaliseerd over
  doctrines: alles-op-max geeft 1.0. `Rules.gd:442-449`
- **Initiatief:** hoogste Aanval-bod wint (ε = 0.000001). Gelijk → hoogste
  Speed-bod. Ook gelijk → in cyclus 1/ronde 1 Speler 1, anders de vorige
  initiatiefhouder. Volledig deterministisch; er is geen loting en geen
  steen-papier-schaar. `Rules.gd:453-485`
- Initiatief wordt elke ronde opnieuw berekend; de houder van ronde 3 begint de
  actiefase. De "vorige houder" blijft over cyclusgrenzen bewaard.
  `GameSession.gd:114-118,220, GameState.gd:9`

## 6. Koppelen

- Om de beurt 1 kaart aan 1 pion, initiatiefhouder eerst (tenzij die geen
  koppelwerk heeft en de ander wel). `GameSession.gd:120-130`
- Geldig koppelen: jouw beurt, kaart van jou + huidige ronde + ongekoppeld, pion
  van jou + levend + zonder kaart. Een pion draagt maximaal 1 kaart per cyclus.
  `GameSession.gd:147-161`
- **Effect:** pion wordt actief; HP = kaart-HP (+1 Beer), stamina-voorraad =
  kaart-Speed (+1 Muis; +1 Krokodil-cavalerie), Aanval = kaart-Aanval. Bonussen
  vallen buiten het budget. `Pawn.gd:28-36, GameSession.gd:162-168`
- **Staartkoppelen:** de beurt wisselt alleen naar een speler mét koppelwerk
  (ongekoppelde kaart uit deze ronde + vrije pion); anders koppel je door.
  Niemand koppelwerk → fase eindigt direct. `GameSession.gd:177-205`
- Kaarten die je niet kwijt kunt **vervallen** zonder compensatie.
  `GameSession.gd:132-139, GameState.gd:234-238`

## 7. Actiefase & stamina

- Per beurt precies **1 actie**: verplaatsen, melee, schot of charge.
  `GameSession.gd:232-320`
- **Stamina is een opmaakbare voorraad voor de hele cyclus** (niet per beurt):
  stap 1 · melee 1 · schot 1 · charge = stappen + 1. Nooit negatief; tussentijds
  nooit bijgevuld. Terugslag en Wolf-stap zijn gratis. `Rules.gd:109,145,170-186,373`
- **Beurtwissel:** na elke actie gaat de beurt naar de tegenstander zodra die kan
  handelen (strikte afwisseling waar mogelijk); kan alleen jij nog, dan blijf je
  aan zet. Kan niemand meer iets → cyclus-reset. `GameSession.gd:373-389`
- Handelen kan alleen met een actieve, levende pion met ≥ 1 stamina en minstens
  één geldige optie (doelwit of beweegruimte). Een volledig ingesloten pion zonder
  doelwitten kan niets. `Rules.gd:400-425`

## 8. Bewegen

- Stap-voor-stap over orthogonale buurvakken; elk gepasseerd vak kost 1 stamina.
  Loopbereik per beweegactie = resterende stamina; artillerie max **1 stap** per
  beweegactie. Eindigen op een bezet vak of buiten het bord kan nooit.
  `Rules.gd:50-53,76-110, constants.gd:23`
- **Springen:** Muis-pionnen bewegen door eigen pionnen heen (doctrine-breed);
  cavalerie springt altijd over eigen pionnen (elke doctrine); Wolf-cavalerie ook
  over vijandelijke infanterie (niet over vijandelijke cavalerie/artillerie).
  Gepasseerde bezette vakken tellen als stappen. `Rules.gd:66-96`

## 9. Melee

- Doelwit: elke vijandelijke pion op aangrenzend vak, óók inactieve
  (standbeelden). Kost 1 stamina. Artillerie kan nooit melee. `Rules.gd:118-145`
- **Schade = volle Aanval.** Actieve verdediger: HP eraf, dood bij ≤ 0. Inactieve
  verdediger: elke schade > 0 elimineert direct. `Rules.gd:201-212`
- **Verplichte verplaatsing:** een melee-kill verplaatst de aanvaller verplicht
  naar het vrijgekomen vak (alleen melee; een schot wint nooit terrein).
  `Rules.gd:213-216`
- **Terugslag:** overleeft een ACTIEVE verdediger, dan krijgt de aanvaller gratis
  schade naar verdediger-type: **infanterie 1, cavalerie 2, artillerie 0**. De
  aanvaller kan eraan sterven. Nooit tegen schoten; inactieve verdedigers slaan
  nooit terug. Wederzijdse eliminatie bestaat dus niet. `Rules.gd:217-229,
  constants.gd:27-31`
- **Wolf-stap:** na élke melee van een Wolf-pion (ook via charge, ook zonder kill)
  1 optionele gratis stap naar een aangrenzend leeg vak, mits de aanvaller leeft
  en er een vrij buurvak is. Zolang de stap openstaat is elke andere actie
  geblokkeerd (zetten of expliciet overslaan). Vervalt bij cyclus-reset. Nooit na
  schoten. `Rules.gd:230-245, GameSession.gd:322-360`
- **Charge (alleen cavalerie):** 0..Speed stappen + optionele melee; minimaal
  1 stap óf een aanval. Kosten = stappen (+1 bij aanval), vooraf volledig te
  betalen; de actie is atomair (ongeldig = er gebeurt niets). De melee-resolutie
  is identiek aan een gewone melee. `Rules.gd:150-190`

## 10. Schieten

- **Infanterie:** afstand **exact 2**, rechte orthogonale lijn, tussenvak leeg
  (elke pion op afstand 1 blokkeert). Schade = **volle Aanval** (ook Aanval 1
  schiet, voor 1). Kost 1 stamina. `Rules.gd:260-263,284-308, constants.gd:18-19`
- **Artillerie:** rechte lijn, afstand **2 t/m 6** (Leeuw: t/m 7). Dode zone:
  afstand 1 nooit beschietbaar én een pion op afstand 1 blokkeert de hele lijn.
  Schade = volle Aanval, kost 1 stamina. Speed telt níet mee voor de dracht.
  `Rules.gd:288-291, constants.gd:20-22,74`
- Cavalerie schiet nooit. `Rules.gd:260-266`
- **Vuurlijn:** alleen de eerste pion in de lijn is raakbaar; alles (ook eigen
  pionnen) blokkeert erachter. Eigen pionnen zijn nooit doelwit. `Rules.gd:296-308`
- **Vuur raakt óók inactieve pionnen**: een schot op een standbeeld elimineert
  het altijd direct, ongeacht de kaart eronder. `Rules.gd:301-307,365-372`
- Een schot geeft nooit terugslag en nooit verplaatsing. `Rules.gd:347-375`

## 11. Doctrines

| Doctrine (display) | Kaarten/ronde | Budget | Leger [inf,cav,art] | Perks |
|---|---|---|---|---|
| **Varken** (enum MENS) | 3 | 7 | [13,6,3] = 22 | geen — allrounder |
| **Muis** | 4 | 5 | **[18,4,0] = 22** | +1 Speed op elke koppeling; beweegt door eigen pionnen (zwerm) |
| **Leeuw** | 2 | 9 | [6,10,2] = 18 | artilleriedracht +1 (7) |
| **Beer** | 3 | 7 | [16,3,3] = 22 | +1 HP op elke koppeling; kaart-Speed max 3 |
| **Wolf** | 3 | 7 | [11,8,3] = 22 | gratis stap na elke melee; cav springt over vijandelijke infanterie |
| **Krokodil** (enum VOS) | 3 | 7 | [13,6,3] = 22 | verborgen koppeling; +1 Speed op cavalerie |

`constants.gd:54-101` — Muis [18,4,0] is het BIG BRO-besluit (juli 2026),
doorgevoerd in F0.0; arena-hermeting volgt in F1.6. Onbekende doctrine-id valt
terug op Varken. `constants.gd:120-121`

## 12. Krokodil: verborgen koppeling

- Alleen Krokodil-pionnen starten met verborgen kaart (de kaarten zelf zijn bij
  de reveal openbaar; wélke kaart op wélke pion zit niet). `GameSession.gd:169-171`
- Onthulling gebeurt **vóór de schade-afhandeling** zodra de pion bij schade
  betrokken raakt: melee onthult aanvaller + (mits actief) verdediger; een schot
  onthult schutter + (mits actief) doelwit. **Bewegen onthult niets.**
  `Rules.gd:196-200,358-361,101-110`

## 13. Client-gedrag (geen engine-regels)

De mens-vs-AI-laag (game.gd) voegt gedrag toe dat géén spelregel is en bij F0.8
naar de engine-klokken migreert:

- **20s-beslistimer** per fase met auto-fallbacks: standaard-opstelling, kaarten
  auto-bevestigd, auto-koppelen, greedy zet (AIMedium). Pauzeert bij het
  uitleg-scherm. `game.gd:76,115-162,181-194`
- De dominante kaart-stat bepaalt alleen het 3D-model-uiterlijk (hp/spd/atk/mix);
  nul gameplay-effect. `constants.gd:162-169`

---

# DEEL B — 4.2.0-concept (campagne-economie) — ALLES TE BEVESTIGEN

> Bron: bouwplan §2.1/§2.4 via MASTERBOUWPLAN F2. Elk punt krijgt in F2.1 een
> definitief besluit + config-knop-naam. Een match zonder `campaign`-config
> speelt exact 4.1.x.

## B1. Commandopunten (CP) — TE BEVESTIGEN
- `state.cp[player]`; start 6 per campagneduel (CP-tabel: haven 8, eliminatie 4,
  raadstem 1 — campagnelaag).
- **BET_CP{0..3}**: blinde inzet per setup-ronde naast DEFINE_CARDS (zelfde
  commit-gate), cap +1 per kaart. TE BEVESTIGEN: wat een CP op een kaart precies
  doet (+1 op een stat naar keuze bij koppeling?), en of ingezette CP verbranden
  of terugkeren. Telt CP-inzet mee in het initiatief-bod?

## B2. Pionnen-pool + SPAWN — TE BEVESTIGEN
- `state.pools[player] = {inf, cav, art}` (init uit config/campagne; poolfactor
  3.0 — TE BEVESTIGEN: 3.0 × wat precies).
- Nieuwe fasen `CYCLE_SPAWN` (vóór de define-rondes) en `RESET` (expliciet).
- **SPAWN{[(type, cel)] ≤3}** per cyclus, blind + simultaan (commit-gate).
  TE BEVESTIGEN: spawnvakken (thuisrijen?). Dood = weg (pool muteert niet);
  eliminatie-winst kijkt naar bord + pool.

## B3. Kanon-actiepot (CANNON_ACT) — TE BEVESTIGEN
- **CANNON_ACT{piece, ROLL dir | SHOOT target | RETREAT}** met de stamina-pot als
  actiebron (formaliseert de huidige huisregel). TE BEVESTIGEN: dracht-model
  (bouwplan zegt vast max 5; huidige engine 6), ROLL = 1 vak, RETREAT = inrukken?

## B4. Klokken — TE BEVESTIGEN
- `clock {bank_sec, increment_sec, reconnect_grace_sec}` in rules_config;
  deadline-gevolgen per fase (setup → default-loadout, actiefase → bank/forfeit).
  Implementatie F0.8; getallen TE BEVESTIGEN.

## B5. SKIP — TE BEVESTIGEN
- `SKIP`-actie alleen als de engine geen legale actie vindt (voorkomt deadlocks
  onder v4.2-fasen).
