# Spelregels — CHANGELOG

## C14 — 30 juli 2026 (vaste 1v1-startreserve)

- **`punten_start`** (nieuwe knop in het campaign-blok, default 0 = uit): een
  vaste puntenreserve voor beide spelers. Staat hij op 0, dan rekent
  `poolfactor x doctrine-comp` het bedrag uit zoals voorheen -- dat blijft het
  gedrag in de campagne, waar de laag zelf de pool aanlevert.
- **Het losse 1v1-potje** (`v42_default.json`) start nu op **15 punten reserve
  en 10 CP**, ongeacht de factie. Daarvoor hing de reserve aan de doctrine-comp
  en verschilde hij per factie (21 punten voor de een, 17 voor de ander) zonder
  dat iemand dat kon zien: onuitlegbaar in een duel dat verder symmetrisch is.
  De campagne is de plek waar ongelijke budgetten thuishoren (budget_bonus).
- **Goldens hergenereerd**: `cp_inzet`, `kanon_act` en `spawn_geblokkeerd`
  draaien op de 1v1-config en kennen dus een andere startpool.


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
