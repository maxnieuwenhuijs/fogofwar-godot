# Spelregels — CHANGELOG

## 4.2.0 — juli 2026 (F2.2: pools + CYCLE_SPAWN, config-gated door het campaign-blok)

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
