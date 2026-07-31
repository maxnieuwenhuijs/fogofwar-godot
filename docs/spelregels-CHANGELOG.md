# Spelregels — CHANGELOG

## C18 — 31 juli 2026 (Krokodil ingeperkt, Wolf krijgt tempo)

*Besluit Max: "zal ik eerst een harde verandering doen: krokodil 6 budget per
kaart, en geef de wolf dan die +1 cav speed van de krokodil?"*

De regelzoeker kan alleen aan de ECONOMIE draaien, en twee metingen wezen
allebei naar de facties zelf: Krokodil had exact het leger van Varken (13/6/3,
3 kaarten, budget 7) plus schutkleur plus +1 cavalerie-snelheid, en stond
25 tot 42 punten hoger. Wolf betaalde zijn tempo-pakket met niets en zakte naar
8,3%.

- **Krokodil**: kaartbudget **7 -> 6** en de +1 cavalerie-snelheid eraf. Hij
  houdt zijn schutkleur (dat is zijn identiteit); zijn nadeel is nu ook echt een
  nadeel: zwakkere kaarten dan de rest.
- **Wolf**: krijgt die **+1 cavalerie-snelheid**. Past bij zijn karakter (gratis
  stap na melee, cavalerie die over vijandelijke infanterie springt).

Gemeten op de campagne-regels, 324 partijen, L2 tegen L2, zelfde seeds als de
nulmeting van de regelzoeker:

| factie | voor | na |
|---|---|---|
| Krokodil | 83,3% | **41,7%** |
| Leeuw | 66,7% | 58,3% |
| Varken | 58,3% | 66,7% |
| Muis | 50,0% | 50,0% |
| Beer | 33,3% | 50,0% |
| Wolf | 8,3% | **33,3%** |

Gemiddelde afwijking van 50%: **19,4% -> 8,3%**. Ter vergelijking: de
regelzoeker kwam in 139 minuten en vijf generaties op 11,1%, en moest daarvoor
Wolf bijna 20 punten reserve geven -- een pleister op een factie die kapot was.
Partijen werden er ook gezonder van: 8% tiebreak, 52% haven tegen 38%
eliminatie, mediaan 10 cycli.

**Wat nog scheef staat**: Varken (66,7%) is de allrounder zonder perks en staat
nu bovenaan, wat betekent dat de perks van de anderen minder waard zijn dan hun
nadelen kosten. Wolf blijft met 33,3% de zwakste. Dat is werk voor een volgende
ronde, en nu wel binnen bereik van de regelzoeker.


## C17 — 31 juli 2026 (EEN regelset: de campagne is het spel)

*Besluit Max: "het moet allemaal 1 lijn zijn en zeker de trainer. De campagne-
regels zijn belangrijk, de 1v1 is gewoon een afgeleide van de campagne: in
plaats van meerdere duels speel je er een, en dus heb je iets gedowngrade CP en
reinforcements, meer niet."*

Er stonden twee economieen naast elkaar en dat is nu weg:

| | campagne (voor C17) | 1v1 / trainer (voor C17) |
|---|---|---|
| startreserve | 0,5 x comp + budget-bonus (15-18 pt) | vaste tabel C16 (7-12 pt) |
| spawn-cap | 15 | 10 |
| cycluslimiet | uit | 20 |

De trainer draaide op `rules_v42_campaign.json`, maar daar stond de 1v1-tabel
in: hij leerde dus over een economie die in de campagne niet bestaat.

**Nu geldt overal dezelfde formule.** `start_poolfactor` (0,5) x je
legersamenstelling, plus `budget_bonus` van je factie -- exact wat CRules in de
campagne doet. Het losse potje schaalt dat met **`potje_factor`**: 1,0 in de
campagne, 0,35 in een los duel. Dat is precies "een duel in plaats van een hele
campagne", en verder niets.

| | campagne | los potje (factor 0,35) |
|---|---|---|
| Varken / Krokodil | 15 pt, 10 CP | 5 pt, 4 CP |
| Muis | 17 pt, 10 CP | 6 pt, 4 CP |
| Leeuw | 16 pt, 10 CP | 6 pt, 4 CP |
| Beer | 16 pt, 10 CP | 6 pt, 4 CP |
| Wolf | 18 pt, 14 CP | 6 pt, 5 CP |

- `punten_start_factie` (C16) bestaat nog als expliciete afwijking voor
  experimenten, maar staat NIET meer in de trainer- of arena-configs.
- **Trainer, nacht-matrix, ijk-sims en de regelzoeker draaien nu alle vier op
  `rules_v42_campaign.json`.** `train_ai.bat` gaf dat regelbestand niet mee en
  trainde dus op 4.1: rechtgezet.
- De **regelzoeker** draait niet meer aan een 1v1-tabel maar aan de
  campagne-knoppen: `start_poolfactor`, `budget_bonus` per factie, `cp_start`,
  ruil, buit en de spawn-caps.
- **Meetgrens, geen spelregel**: in de echte campagne staat de cycluslimiet uit
  (C9). Bots rekken partijen dan tot ~1570 stappen (gemeten: 3x zo lang, 18%
  eindigt op de meet-afkap). De arena- en trainerconfig krijgt daarom een ruime
  limiet van 25 cycli; die bindt in botspel vrijwel nooit (mediaan 10) en houdt
  een trainingsnacht bruikbaar. Met die grens: 686 stappen, 11% tiebreak.


## Ijk-sims verhuisd naar 4.2 (30 juli)

De vijf vaste sims in `tests/golden_sims.json` draaiden nog op de KALE
4.1-defaults, terwijl 4.1 sinds vandaag geen speelbare optie meer is. Ze
bewaakten dus een regelset die niemand speelt. `simcheck` laadt nu
`arena/arena_configs/v42_default.json` (pad staat in golden_sims.json) en de
vijf uitkomsten zijn opnieuw vastgelegd onder die regels.

**Eerlijk erbij**: onder de oude 4.1-baseline weken alle vijf sims af na de
C15/C16-ronde, en ik heb die afwijking NIET kunnen herleiden tot een enkel
bestand (Pawn, Rules, GameState, rules_config en AIController elk los
teruggezet: de afwijking bleef; alle code samen terugzetten: weg). Het gaat om
kortere partijen en een omgeklapte winnaar, niet om een crash. Omdat 4.2 de
gespeelde regelset is, bewaakt de canary nu dat, en blijft dit als open vraag
staan in WIP.md.

## C16 — 30 juli 2026 (startreserve per factie in een los potje)

*Besluit Max: "de 1v1 moet dus wel die voordelen in economie vertaald hebben per
factie, dus de muis heeft dan bijv 12 tov de leeuw 7 -- dat moeten we nog goed
uittrainen en bedenken."*

- Nieuwe knop **`punten_start_factie`** (sleutel = doctrine-int als string). Leeg
  = uit, dan geldt `punten_start` voor iedereen. Dit is de 1v1-vertaling van de
  campagne-budgetbonus (`budget_bonus` in CRules), die alleen in de campagne gold.
- **Startpunt** in `v42_default.json` en `rules_v42_campaign.json` (dus ook voor
  de trainer): Muis 12, Beer 12, Wolf 11, Varken 9, Leeuw 7, Krokodil 7. De twee
  ankers komen van Max; de rest volgt de gemeten winrates van 29 juli
  (Krokodil 76%, Varken 58%, Leeuw 48%, Wolf 45%, Muis 40%, Beer 30%): zwak =
  meer reserve.
- **Dit is expliciet een startpunt, geen conclusie.** De volgende trainingsnacht
  is de eerste met werkende versterkingen (zie C14) EN met buit (C15), dus de
  winrates van 29 juli zijn nu verouderd. Meten voordat we hier weer aan draaien.


## C15 — 30 juli 2026 (buit op figuranten, rules_version 4.2.1)

*Besluit Max: "de vaandel 2 reinforcements en de tamboer 2 CP dus in. Alleen
moet je ook zelf dus kunnen bepalen waar deze komen te staan bij army neerzet
fase."*

Tot nu toe waren de vaandeldrager en de tamboer pure aankleding: een pion zonder
kaart kreeg een prop in de hand, en strategisch negeerde je hem. Nu hangt er
geld aan.

- **Rol staat op de PION, in de staat** (`Pawn.rol`: "" / "flag" / "drum"). Dat
  moest wel: er hangt buit aan, dus replays en goldens moeten hem kennen. De rol
  verhuist NOOIT (expliciete wens): koppel je een drager, dan bergt hij zijn
  vaandel op; ontkoppel je hem, dan pakt hij hetzelfde vaandel weer op.
- **Buit bij een kill**: een DRAGENDE vaandeldrager levert de aanvaller
  **2 versterkingspunten** op, een tamboer **2 CP**
  (`buit_vaandel_pt` / `buit_tamboer_cp`, 0 = uit). "Dragend" = zonder kaart:
  een gekoppelde pion is een gewone soldaat en heeft niets in de hand, dus er
  valt niets te veroveren. Dat is ook wat je op het bord ZIET.
- **Je zet ze zelf neer**: in de opstelfase zijn "vaandeldragers" en "tamboers"
  losse plaats-stappen, net als kanonnen en ruiters. Je kiest dus hun vak.
  `vaandels_max` en `tamboers_max` (default 2 en 2) begrenzen hoeveel je mag
  aanwijzen; de validator weigert meer, rollen op niet-infanterie en rollen
  zonder campagne-blok.
- **Bots doen mee**: twee leerbare gewichten, `buit_jacht` (een vijandelijke
  drager binnen bereik is winst) en `buit_hoede` (mijn drager binnen bereik van
  de vijand is verlies), gewaardeerd uit de regelknoppen zelf. De arena meet
  `buit_pt`, `buit_cp` en `dragers_verloren` per potje, dus de trainingsnacht
  kan laten zien of ze er echt op jagen.
- **Zonder campagne-blok (4.1) verandert er niets**: rollen zijn dan niet eens
  legaal in een opstelling. Binnen 4.2 is dit wel een echte regelwijziging, dus
  `rules_version` gaat naar **4.2.1** en de goldens zijn hergenereerd.


## C14 — 30 juli 2026 (een los potje krijgt een potje-budget)

**Eerst de bug, want die maakte de regel pas meetbaar.** Sinds C11 (27 juli,
commit 35704f0) is de reserve EEN puntenpot: `pools[speler] = {"pt": N}`. Twee
plekken bouwden de pool nog per type op (`inf`/`cav`/`art`) en lazen dus 0:

- `agents/agent.gd` (view-reconstructie): elke bot zag een LEGE reserve en
  diende zelf een lege spawn-inzet in. De nacht van 24 juli had nog 36,1
  aanvullingen per partij, de nachten van 28 juli 0,00 in 3240 partijen. Twee
  trainingsnachten hebben dus over een dode economie geleerd.
- `core/match/serializer.gd` (`state_from_dict`): elke replay, fold en
  campagne-hervatting verloor de puntenreserve. Onzichtbaar, want `zobrist`
  hasht de pools niet, dus geen golden kon het vangen.

Beide doen nu "neem de sleutels over die er staan"; twee regressietests in
`tests/SpawnTests.gd` zetten het vast (agent ziet zijn eigen puntenreserve,
en de reserve overleeft een serialisatie-roundtrip).

**En toen de regel.** Met werkende aanvullingen gemeten, L2 tegen L2, alle
matchups, v4.2-duel:

| reserve | potjes | cycli (mediaan) | aanvullingen | haven | eliminatie | tiebreak |
|---|---|---|---|---|---|---|
| oude 1v1-formule (1,5 x comp = 39-52 pt) | 288 | 14.5 | 24.5 | 72% | 17% | 11% |
| 4 punten | 288 | 10.0 | 4.2 | 64% | 33% | 3% |
| 6 punten | 288 | 9.0 | 5.1 | 58% | 39% | 3% |
| **10 punten (gekozen)** | 288 | 10.0 | 9.2 | 50% | 50% | 0% |
| 15 punten (hele campagnepot) | 288 | 11.0 | 12.7 | 53% | 39% | 8% |

- **`punten_start` = 10** en **`spawn_totaal_max` = 10** in `v42_default.json`
  (het losse duel, en de bron van de nacht-matrix) en in
  `rules_v42_campaign.json` (de trainer). Keuze van Max: een los potje mag wat
  langer doorlopen. De meting steunt dat: 10 punten geeft dezelfde speelduur als
  4 punten maar ruim dubbel zoveel aanvullingen, en geen enkele partij eindigde
  in de cycluslimiet.
- **Waarom niet de oude formule** (1,5 x comp = 39 tot 52 punten): dat is geen
  potje-budget maar een oorlogskas. 24,5 aanvullingen per partij, de langste
  partijen van allemaal en 11% die de cycluslimiet haalt.
- **Waarom niet de hele campagnepot** (15 punten): 0,5 x comp geeft in de
  campagne 15 tot 18 punten voor een campagne van MINSTENS vier duels. Dat in
  een enkel potje stoppen is vier potjes budget in een potje.
- **De campagne blijft de campagne**: die levert per duel een expliciete pool
  uit het grootboek, en een expliciete pool wint van `punten_start`. Een los
  1v1 speelt dus met campagne-REGELS (CP, versterkingen, spawn-fase) op het
  budget van een enkel duel.
- **Goldens**: hergenereerd. Geen enkele hash veranderde (de startpool zit niet
  in de zobrist-hash), alleen de opgeslagen startpool in de replay-data.

## C13 — 29 juli 2026 (balans na de trainingsplateau-meting)

De trainingsnacht liep vast op een plateau: 314 generaties, 1 adoptie, en de
convergentiecheck meldde 50% tegen de kampioen van 5 generaties terug. De bots
spelen hun factie dus zo goed als dit model toelaat -- wat overbleef was geen
leerprobleem maar een ONTWERPprobleem. Gemeten winrates: Krokodil 76%, Varken
58%, Leeuw 48%, Wolf 45%, Muis 40%, Beer 30% (Muis-vs-Krokodil zelfs 5%).

- **Krokodil, schutkleur afgezwakt** (`schutkleur_onthul_nabij`, default aan):
  de gedekte koppeling valt niet alleen weg bij schade, maar OOK zodra er een
  actieve vijandelijke pion naast de pion staat. Van een vak afstand kijk je
  iemand recht aan; schutkleur werkt op afstand, niet in een handgemeen. Puur
  een KIJK-regel: de staat verandert niet, dus replays/goldens blijven gelijk.
- **Beer, speedplafond 3 -> 4**: 81% van alle partijen wordt via de haven
  beslist en maar 14% via eliminatie. Beer betaalde zijn +1 HP dus met precies
  het middel waarmee je wint. Hij blijft de traagste factie (anderen kennen
  geen plafond), maar is niet langer structureel uitgeteld in de race.

## Campagne C9 — 26 juli 2026 (playtest Max: volle rondes, geen cycluslimiet)

- **Ronde 1 = loting:** alle 16 spelers worden random 1v1 gepaird (nieuwe
  campagne-actie `loting`, systeem-only, paren als data in het log). Geen
  raad en geen donatie-venster in ronde 1 (iedereen heeft zijn
  factie-start): na de loting direct de duels in.
- **Ronde 2+ = iedereen vecht:** `duels_per_ronde_max` 2 -> 8; aantal duels
  = kleinste teamgrootte; de raad stemt de matchups om-en-om; overtal rust.
- **Donaties:** aan elke levende teamgenoot (was: alleen genomineerden) —
  een superset, oude logs blijven geldig.
- **Cycluslimiet campagne-duels:** 6 -> 0 (uit). Duels eindigen op haven of
  eliminatie, zoals een los potje; de bot-simulatie houdt alleen een ruime
  noodstop (max_steps 3000). Reden: met limiet 6 eindigde vrijwel elk duel
  in het tiebreak-vangnet (echte winst kost 5-16 cycli) en stierf er
  niemand, waardoor campagnes 34-44 rondes duurden.
- **Compat:** oude campagne-saves folden onder hun eigen regels
  (`CRules.from_dict` valt terug op max 2 duels / geen loting); de hub
  start bij een pre-C9-save een verse campagne.

## 4.2.0 — juli 2026 (F2.2: pools + CYCLE_SPAWN, config-gated door het campaign-blok)

**Bijstelling 25 juli (besluit Max, na de eerste speeltest):** `cp_start`
6 → **10** (kort 5 geprobeerd: "je burnt er snel doorheen"); `poolfactor`
3.0 → **1.5** (reinforcements = startleger × 1.5) en NIEUW
`spawn_totaal_max` = **15** spawns per potje (de 1v1-setting, te testen).
Koppel-gedrag: onder campaign krijgen achterrij-pionnen koppel-voorrang
zodat de spawn-rij vrijloopt (standbeelden blokkeerden hem permanent). En overgebleven
duel-CP verdampt niet — in campagnemodus vloeit het restant terug naar de
campagnelaag en is daar overdraagbaar (F3-eis; de laag leest `final_state.cp`);
bij uitvallen geldt het F3-testament (max helft, max 2 ontvangers, timer).

**Eerste v4.2-stap in de engine** (spec: F2.1-ontwerpsessie met Max, 24 juli;
`docs/spelregels-v4.2.md` Deel B). Een match zonder `campaign`-blok speelt
byte-identiek 4.1.10-hr; activering van het blok zet `rules_version` op 4.2.0.

- **Pionnen-pool** per speler {inf, cav, art}: 3.0 × doctrine-comp per type
  (D5), of expliciet aangeleverd via `campaign.pools`.
- **Fase-flow bij cycluseinde** (vanaf `spawn_vanaf_cyclus`, D7): zichtbare
  `RESET`-fase (ledger-event `cycle_admin`, geen spelerinput) → blinde
  `CYCLE_SPAWN` met commit-gate zoals DEFINE. Nieuwe fase-waarden achteraan
  de enum: bestaande replays behouden hun ints.
- **SPAWN** (max `spawn_max`=3 totaal, alleen de eigen achterste rij, D6):
  blind en simultaan; een spawn op een bezet vak wordt pas bij de reveal
  geweigerd en de pion blijft in de pool. Pool-loze spelers auto-committen
  leeg (D11). Nieuwe pionnen komen als ongekoppelde standbeelden binnen.
- **Winconditie**: eliminatie kijkt naar bord + pool (met reserves ben je
  niet verslagen).
- **View** (D12): vijandelijke pool is het "?"-sentinel (tenzij
  `pool_zichtbaar`); de lopende spawn-inzet is geheim tot de reveal.
- **F2.3 — BET_CP** (zelfde 4.2.0-lijn): blinde CP-inzet als apart actietype
  vóór de eigen kaartdefinitie (D14), 0..min(saldo, kaarten die ronde);
  direct verbrand, ook ongebruikt (D2). Effect (D1): elke ingezette CP staat
  precies 1 kaart met budget+1 toe (define-validatie, max 1 per kaart, D4).
  Initiatief loopt vanzelf via de stats (D3, geen aparte bod-regel).
  Ledger-events: cp_bet (blind), cp_admin bij de reveal (server/log-only,
  D12) en cp_earned bij haven-/eliminatie-winst (tarief 8/4, D13 — saldo
  blijft onaangeraakt, de campagnepot boekt bij). View: eigen saldo/inzet
  zichtbaar, vijandelijk saldo "?" en inzet onzichtbaar tot de reveal.
- **F2.4 — CANNON_ACT** (zelfde 4.2.0-lijn): onder campaign is
  `CANNON_ACT{pawn_id, sub: roll|shoot}` de actietaal voor artillerie-bewegen
  en -schieten (union-actietype, D14; RETREAT bestaat niet, D9). ROLL = 1 vak,
  kosten uit `campaign.kanon_actie_kost` {roll 1, shoot 1}; dracht uit
  `campaign.kanon_dracht_max` (6, Leeuw +1, D8); dode zone en vuurlijn-
  blokkade ongewijzigd. MOVE/SHOOT voor een kanon worden onder campaign
  geweigerd en blijven het 4.1.x-pad; melee blijft voor elk type een gewone
  MELEE-actie (bewust: de kanon-taal dekt bewegen en schieten).
- Serialisatie-formaat uitgebreid (pools/spawn-commits): alle goldens
  geregenereerd (formaatwijziging, geen 4.1-regelwijziging — simcheck 5/5
  en de volledige suite bewijzen gedragsbehoud).

## 4.1.10-hr — juli 2026 (regelwijziging: kaartdefinitie begrensd door vrije pionnen)

**Regel (besluit Max):** je definieert per setup-ronde hoogstens zoveel kaarten
als je vrije (levende, ongekoppelde) pionnen hebt. Heb je er nul, dan sla je de
ronde over en gaat de tegenstander alleen door (define, reveal en koppelen
lopen gewoon; jouw kant is vrijgesteld). Voorheen definieerde een uitgedunde
speler elke ronde het volle doctrine-aantal en vervielen de overtollige
kaarten pas bij het koppelen — drie lege verplichte rondes voor de verliezende
kant.

- Engine: `Validator.expected_define_count` (min(doctrine.cards, vrije
  pionnen)); commit-gate telt vrijgestelde spelers als klaar; gate draait ook
  bij het betreden van elke define-fase (beide vrijgesteld → meteen door).
- AI/sim/UI volgen automatisch (generate_cards, kaartwaaier toont het juiste
  aantal sloten).
- Golden replays + sim-baselines geregenereerd onder de nieuwe regel
  (bewuste breuk conform werkafspraak §0).

> Regel uit het masterplan (§0): breekt een wijziging een golden replay, dan hoort
> daar een versie-bump in `rules_version` bij + een entry hier. Vanaf F0.7 zijn
> golden replays de handhaving; tot die tijd is dit document de waarheid.

## 4.1.9-hr — juli 2026 (F0.0: codificatie van de geïmplementeerde huisregels)

Eerste vastlegging: `docs/spelregels-v4.2.md` Deel A beschrijft de engine zoals
hij draait. Daarbij zijn alle stille afwijkingen t.o.v. `spelregels-v4.1.md`
gedocumenteerd, plus één bewuste regelwijziging en een code-opruiming.

### Bewuste regelwijziging in deze versie

- **Muis-samenstelling → [18 inf, 4 cav, 0 art]** (besluit Max, juli 2026 — het
  "BIG BRO"-besluit van 6 juli). Historie: doc zei 22/0/0; commit 05c8f65 maakte
  er 20/0/2 van; nu 18/4/0 — de Muis krijgt cavalerie (de dikke rat), de kanonnen
  gaan eruit. Arena-hermeting + eventuele bijstelling volgt in F1.6. Gevolg: de
  bestaande Muis-AI-gewichten zijn getraind op 20/0/2 en gelden als verouderd tot
  de F1.6-hertraining.

### Opruiming (geen gedragswijziging)

- **Dode RPS-code verwijderd**: `Phase.Type.SETUP_*_RPS`, `is_rps()`,
  `rps_for_round()`, de `needs_rps`-parameter van `cards_revealed_event` en het
  `needs_rps`-veld uit `compute_initiative` — allemaal sinds v4.1 onbereikbaar
  (initiatief is volledig deterministisch). Let op: de Phase-enum is hierdoor
  hernummerd; er bestond nog geen serialisatie die daarop leunde.
- Verouderde comments rechtgezet (Rules.gd-header "Attack−1" en "dracht 2..Speed";
  GameSession "dracht = Speed") en de Muis-UI-tekst ("geen cavalerie") aangepast.
- capture.gd `-- play`: headless zonder viewport-texture hangt niet meer op de
  screenshot maar slaat hem over en sluit netjes af (rooksignaal = de
  [PLAY]-regel).

### Gedocumenteerde stille afwijkingen t.o.v. spelregels-v4.1.md

Deze golden al in de engine; ze zijn nu spec (bronnen in spelregels-v4.2.md):

1. **Infanterieschot: volle Attack** i.p.v. Attack−1. Ook Aanval-1-pionnen kunnen
   schieten; elk schot doodt een standbeeld.
2. **Actie-economie: opmaakbare stamina** i.p.v. "1 actie per pion per cyclus".
   Stap 1 / melee 1 / schot 1 / charge stappen+1; meerdere beurten per pion;
   artillerie kan verspreid over beurten bewegen én schieten.
3. **Artilleriedracht vast 6** (+1 Leeuw) i.p.v. dracht = Speed. De hele
   dracht-Speed-ontwerpruimte uit de v4.1-doc (1/5/1 vs 1/2/4, Beer ≤ 3) bestaat
   niet in de engine.
4. **Terugslag type-afhankelijk** {inf 1, cav 2, art 0} i.p.v. alleen-infanterie
   altijd 1.
5. **Cavalerie springt over eigen pionnen bij élke doctrine** (doc: alleen Muis
   door eigen pionnen).
6. **Wolf: tweede perk** — cavalerie springt ook over vijandelijke infanterie
   (doc kende Wolf alleen de gratis stap toe).
7. **Muis: tweede perk** — +1 Speed op elke koppeling (commit 51e3112).
8. **Krokodil: tweede perk** — +1 Speed op cavalerie bij koppeling.
9. **Leeuw: perk** — artilleriedracht +1 (doc: "geen regelafwijking").
10. **Doctrine-namen**: display Varken/Krokodil voor enum MENS/VOS (facties zijn
    dierenfamilies; commits 646d5dd, d6f4064, f16078e).
11. **Vuurmodel hardcoded aan/aan**: vuur raakt inactieve pionnen en wordt door
    álles geblokkeerd; de §8-configuratievraag uit de v4.1-doc
    (vuurRaaktInactief/vuurGeblokkeerd) wordt pas in F0.2 een config-knop.
12. **20s-beslistimer met auto-acties** in de mens-vs-AI-client (geen
    engine-regel; migreert in F0.8 naar échte klokken in de staat).

### Bekende dode/inconsistente restpunten (bewust laten staan)

- `GameState.pending_forced_move_attacker` wordt nergens gezet (verplichte
  verplaatsing gebeurt altijd direct in `_resolve_melee`); `clear_placement()`
  wordt nergens aangeroepen. Opruimen kan in F0.4 (reducer-verhuizing) zonder
  risico.
