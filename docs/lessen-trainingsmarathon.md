# Lessen uit de trainingsmarathon (2-4 oktober 2026)

Voorlopig vastgelegd op 5 oktober. De marathon: 48 uur, vijf cycli
duel-training met na elke cyclus een nachtmatrix van 3240 partijen,
campagne- en puntenbots, een L4-proef, de regelwijzigingen C28, C29 en C30,
en twee reparaties aan de duel-trainer (be95d06 verse seeds, 0dc3f59
loting). Wat er gebeurde staat in WIP.md (2-4 oktober). Hier staat wat we
ervan leren: wat je de volgende keer anders of hetzelfde doet.

Hoe dit tot stand kwam: acht lezers haalden lessen uit WIP, CHANGELOG, de
matrices zelf, de trainerlogs, de looptijden, het sessietranscript, de
campagnekant en het geheugen (157 lessen). Elke les ging daarna langs een
aparte controle die hem tegen de bron probeerde te weerleggen (nagerekend
met python op de games.jsonl, logs en commits), in twee rondes; een les die
in een van beide sneuvelde is eruit of bijgesteld. Een criticus zocht wat
ontbrak; die negen lessen gingen elk langs twee controleurs. Wat niet
overeind bleef, of niet nieuw was, staat hier niet in. Percentages zijn
zonder spiegelpartijen, tenzij er iets anders staat.

**Status: voorlopig.** Besluit B18 in MASTERBOUWPLAN.md vat de werkregel
samen. De open punten onderaan zijn nog niet opgepakt.

---

## 1. Balans: de balans draait mee met de bots

**Drie nachten op C30** (elk 3240 partijen, 900 per factie, foutmarge
+-3,3; tussen de nachten veranderden alleen de botgewichten):

| factie | na cyclus 3 | na cyclus 4 | na cyclus 5 | gemiddeld | SD |
|---|---|---|---|---|---|
| Varken | 47,3 | 52,2 | 47,9 | 49,1 | 2,7 |
| Muis | 51,4 | 51,6 | 48,1 | 50,4 | 2,0 |
| Leeuw | 60,9 | 55,7 | 55,3 | 57,3 | 3,1 |
| Beer | 43,8 | 59,3 | 56,7 | 53,3 | 8,3 |
| Wolf | 50,3 | 40,6 | 47,3 | 46,1 | 5,0 |
| Krokodil | 46,2 | 40,7 | 44,7 | 43,9 | 2,9 |

- **De schommeling komt van de bots, niet van de steekproef.** De ruis van
  een nacht is 1,0-1,7 pp per factie; de sprongen tussen nachten met
  dezelfde regels hebben een mediaan van 3,7 pp en een maximum van 15,6
  (Beer 43,8 naar 59,3). Per paar: dezelfde bots met andere seeds komen
  binnen de ruis terug (rms z 1,13), tussen C30-nachten niet (rms z 2,58
  en 1,78). **Had je de Beer na nacht 3 opgekrikt, dan had hij een nacht
  later zonder ingreep op 59,3 gestaan.**
- **Structureel op C30:** de Leeuw zit alle drie de nachten boven de 55, de
  Krokodil alle drie onder de 47. De Wolf zat in vier van de vijf
  marathonnachten onder de 50. De Beer is de echte wisselaar, de Muis staat
  het stilst. Het criterium is de RICHTING (steeds aan dezelfde kant van
  50), niet de band: met een band van 45-55 valt de Beer alle drie de
  nachten erbuiten.
- **Het aantal adopties voorspelt de matrix niet** (r = 0,08 over de 12
  factie-cycli van cyclus 4 en 5; van de 9 factie-cycli met een adoptie
  stegen er 4). De Beer ging met EEN adoptie +15,5, de Leeuw met drie
  adopties -5,2. Beoordeel een nacht op **welke paren omdraaiden en wie
  daarin veranderde**.
- **Ook een bevroren bot verschuift.** De Muis adopteerde in vijf cycli
  niets en zakte van 54,7 naar 48,1, puur doordat de anderen tegen haar
  veranderden (Muis-Beer 44 naar 24 na de Beer-adopties).
- **De driehoek ligt vast:** Varken wint 94-98% van de Beer, Varken 80-83%
  van de Muis, Krokodil 89-98% van het Varken, in elke meting van C28 tot
  nu, over vijf botgeneraties en een regelwijziging heen. Het derde been,
  Beer tegen Krokodil, beweegt wel mee (76-79, na de Beer-adoptie 93-95).
  Training duwt extreme paren hooguit verder van 50, niet terug.
- **De Krokodil is een factie van een kunstje:** op C30 wint hij 94-98%
  van het Varken en maar 27-33% van de andere vier (op C29 nog 44-45). De
  daling kwam vooral uit Krokodil-Leeuw en, na de Beer-adopties, uit
  Krokodil-Beer.
- **Een paar kan een factie zeven punten geven.** De factiewinst is het
  gemiddelde over vijf tegenstanders, dus een paar dat 35 pp schuift
  beweegt de factie 7. Bij C29 kwam de hele +7 van het Varken uit Varken
  tegen Leeuw (4 naar 39 van de 100): de vier andere paren waren in de
  gepaarde meting partij voor partij gelijk. De CHANGELOG-zin "een enkele
  matchup kan geen 7 punten geven" klopte dus niet. **Kijk per paar
  voordat je een uitschieter toeval noemt.**
- **C29 en C30 verschoven vooral hetzelfde paar, Leeuw tegen Varken, elk
  een andere kant op.** C30 repareerde voor een deel een bijwerking van
  C29. Het doel van C30 hield wel stand: het Varken stond drie nachten op
  47,3-52,2 (op C29 57,6 en 57,9).

### Wat een knop kost (gemeten in de marathon, per factie anders)

| ingreep | effect | hoe gemeten |
|---|---|---|
| Varken een ruiter minder ([12,4,2] naar [12,3,2]) | -7,5 | gepaard, 1440 partijen, z 2,8 |
| Varken een kanon minder ([12,4,1]) | -13,8 | gepaard, 1440 partijen |
| Leeuw een ruiter minder ([12,3,2], c31_a) | -4,2 | ongepaard, 1,4 SE: niet bewezen |
| Leeuw een kanon geruild voor infanterie | -1,4 | binnen de ruis |
| Leeuw zonder dracht 7 (C29) | -8,0 | 1800 partijen |
| Leeuw kaartbudget 8 naar 7 | -17,6 | 1800 partijen, schiet door |
| Leeuw zijn 5 start-CP eraf (C28) | ~-3 | 1800 partijen |
| Leeuw zijn versterkingspunten eraf | 0 | 1800 partijen |
| Wolf extra punten of CP | 0 | drie varianten, 40,4-42,4 |
| Varken een kaart per ronde minder | -35,0 | factiezoeker-log, gepaard, 120 partijen, ruis ~5 |
| Varken een kaart per ronde erbij | ~+11 | idem |
| Varken +1 HP per koppeling | +10,0 | idem |
| Varken kaartbudget 7 naar 8 | +11,7 | idem |
| Varken dracht +1 | +17,5 | idem |
| Varken twee kanonnen minder | -20,8 | idem |

- De oude "~18 per ruiter" (CLAUDE.md) komt van 8 augustus, van voor de +2
  attack op de ruiter en voor de trainer-reparaties. Gebruik de tabel
  hierboven.
- **Lees het log van de factiezoeker uit.** Alle kandidaten spelen dezelfde
  seeds, dus `results/facties_<stempel>/log.jsonl` is een gepaarde
  knoppentabel (de Varken-regels hierboven). In de marathon is alleen het
  voorstel gelezen. Kaarten per ronde is de grofste en meest scheve knop:
  een kaart minder kost drie keer zoveel als een kaart erbij oplevert.
- **Afpakken werkt alleen bij iets wat de factie echt inzet.** De Leeuw op
  C28 schoot 24 keer per partij (het Varken met hetzelfde leger 11), won
  284 van 284 door uitschakeling, deed 0 charges en spawnde 3,4 keer per
  partij. Daarom deed dracht en kaartbudget veel, en versterkingspunten
  niets. **Lees voor elke factie-ingreep eerst het profiel uit de laatste
  matrix** (shots, spawns, charges, methode haven of eliminatie, cp_bet)
  en meet alleen knoppen die op die kolommen werken. Of hij iets inzet zie
  je aan of de kolom meebeweegt met de knop (zonder dracht schoot de
  Leeuw 24 naar 21 keer; met een kanon minder bleef hij op 22 en spawnde
  hij vaker).

## 2. Meten

- **De spreiding heeft een ruisvloer.** Als elke factie precies 50% was,
  gaf ruis alleen al een gemiddelde spreiding van 6,9 bij 1440 partijen en
  4,6 bij 3240. De "smalste band ooit" van C30 (5,5 bij 1440 partijen)
  was dus niet van perfecte balans te onderscheiden, en het "vorige
  record" van 8,2 ook niet. Geen enkele nachtmatrix sinds 23 september kwam
  onder 12,0. **Noem een spreiding altijd met het aantal partijen en "met
  deze bots" erbij, zonder superlatieven.**
- **Een smalle band uit een variantmeting tegen vaste bots houdt na
  training geen stand** (C30: 5,5 in de variant, daarna 17,1 / 18,8 /
  12,0; C27 net zo). Een regelwijziging is pas geslaagd na minstens een
  trainingsnacht op de nieuwe regels, en dan beoordeeld op de doelfactie.
- **De C30-controle is per ongeluk herhaald, en het doel hield stand.** De
  datarun van de L4-proef (`results/l2_log_20261003_1613`, 480 partijen
  zonder spiegel) speelde dezelfde regels en bots als c30_a met andere
  seeds: Varken 50,6 tegen 50,5, de paren binnen de ruis, maar spreiding
  18,1 tegen 5,5. Beide spreidingen zijn deels seed-geluk (bij 480 partijen
  geeft perfecte balans al gemiddeld 11,0). Samen, 560 per factie: 44,6-52,9.
  Een datarun voor iets anders is ook een balansmeting: lees hem.
- **De factiezoeker is per proces deterministisch.** De herstart met
  `--procs 4` speelde zijn nulmeting partij voor partij opnieuw. De eerste
  run had al vijf blokken van vier processen klaarliggen: het Varken kwam
  daarin op 56,7 / 57,5 / 55,0 / 51,7 / 55,8 (5,8 pp uiteen, zelfde regels,
  bots en code). Een zoeker met 12 partijen per paar meet dus grof.
- **Foutmarges, nagerekend:** het binomiale model klopt (geen extra ruis
  per proces of seed). Omdat de paren extreem zijn is de effectieve
  variantie per partij ~0,18 in plaats van 0,25: een factie in een nacht
  van 3240 partijen heeft gemiddeld +-2,8 pp (het Varken, met alleen
  extreme paren, +-2,0).
- **Meet een variant altijd gepaard, met een eigen _ref.** Varianten met
  dezelfde seeds en dezelfde bots zijn echt gepaard: elke partij zonder de
  veranderde factie is byte-identiek. c31_a is tegen de nachtmatrix
  afgezet (andere seeds, geen enkele gedeelde partij), dus daar zit de
  volle ruis van twee losse steekproeven in. Leg na elke nacht de
  paarmatrix naast die van de vorige nacht en reken z per paar (rms z rond
  1 is ruis).
- **Een tussenstand van een lopende matrix is systematisch scheef** (al
  bekend sinds 9 augustus, nu gemeten): elk proces speelt de 36 paren in
  vaste volgorde; op 25% van de kloktijd wijkt de Krokodil 33-55 pp af van
  de eindstand, op 75% nog ~5 pp, pas op 90% hooguit 2.
- **Een trainer naast een meting vervuilt die meting.** Elke arena-partij
  maakt verse agents en AgentL2 leest het profiel bij zijn eerste
  beslissing van schijf; de trainer schrijft bij elke adoptie meteen
  `data/ai_weights_f<n>.json` weg. De L4-meting van 3 oktober liep over een
  Varken- en een Leeuw-adoptie heen. **Meet nooit tijdens een trainersessie**
  (of laat de arena een bevroren kopie van de gewichten lezen).
- **De run-metadata zegt niet met welke bots er gespeeld is:** wel
  git_sha, geen hash van de gewichten, en geen melding van ongecommitte
  gewichten. Dezelfde cyclus-4-bots dragen daardoor twee labels (43be5a5 en
  951045c).
- **Het effect van een regel meet je gepaard, niet van nacht tot nacht.**
  Elke cyclus traint nieuwe bots, dus een vergelijking van nachtmatrices
  over een regelwijziging heen mengt altijd regels en bots. C30 gaf gepaard
  Varken -7,5 en Leeuw +4,0; van de laatste C29-nacht naar de eerste
  C30-nacht was dat -10,6 en +16,3. Een gepaarde variant voorspelt het
  niveau van de factie die je verandert redelijk goed (C30: 50,5
  voorspeld, 47,3-52,2 in de nachten erna), maar niet de spreiding en niet
  de buren. Let op: een matrix leest zijn regels pas bij zijn eigen start
  (na de fuzz); markeer in WIP welke regels hij mat.
- **Kleur:** buiten de spiegelpartijen is er geen voordeel voor stoel 1
  (49,8% over 13.500 partijen). In de spiegelpartijen wel: stoel 1 wint
  56,8% (2700 partijen, z ~7), oorzaak onbekend (open punt).

## 3. De duel-trainer

- **Verse seeds alleen deden niets.** De MatchRunner-seed voedt alleen de
  rng waarmee bots loten tussen gelijke topzetten, en `tie_break_loting`
  stond in de trainer uit (de arena aan). Trainer en meting speelden tot
  0dc3f59 (4 oktober 02:28) dus een ander spel, en cyclus 2 en 3 trainden
  nog op vaste partijen. **Herkennen:** de referentie van een ongewijzigde
  kampioen, elke generatie op een verse reeks gemeten, blijft tot op de
  decimaal gelijk (Beer tien keer 15,3, Muis vier keer 12,7). Met loting
  zwaait hij 5-6 punten op 24.
- **Een rooktest die alleen "geen fouten" toont bewijst een randomness-fix
  niet.** De rooktest van be95d06 draaide een generatie; draai er minstens
  twee en controleer dat wat moet variëren ook varieert. Het symptoom
  stond al in de logs van cyclus 2 en viel pas ruim 20 uur later op: lees
  tussen twee cycli de referentiekolom per kampioen.
- **Met loting adopteert de trainer 6,4 keer zo vaak:** zonder loting 5
  adopties in 191 generaties (2,6%), met loting 17 in 102 (16,7%).
  Adopties over de hele marathon: Varken 7, Leeuw 6 (waarvan 1 vals en
  teruggezet), Wolf 4, Beer 3, Krokodil 2, Muis 0.
- **De poort laat nu ruis door.** Dezelfde kampioen haalt op verse reeksen
  een referentie met een SD van 0,5 (Leeuw) tot 2,1 (Wolf), terwijl de eis
  +1,0 is. Alle 12 adopties in cyclus 4-5 waarvan de kampioen minstens
  twee referenties had, vielen op een referentie onder zijn gemiddelde; 7
  op zijn laagste (bij toeval 3 verwacht). Een betere poort vergelijkt
  kandidaat en kampioen op dezelfde seeds (open punt).
- **De convergentiecheck meet niets.** `_conv_game` zet geen
  `tie_break_loting`, dus de 12 partijen zijn er 2; er kan alleen 0, 6 of
  12 uitkomen. In de marathon 21 van de 22 keer precies 6,0/12.
- **Of een bot CP inzet hangt aan een drempel, en de trainer beloont
  sparen.** `choose_cp_bet` rondt `cp_bet_rN` af, dus een gewicht onder 0,5
  biedt nooit, en CampagneFitness telt gespaarde CP mee (W_CP 0,05) terwijl
  CP in een duel alleen via inzet iets doet. In de laatste matrix bieden
  Varken, Leeuw en Beer niets meer (de Leeuw in alle vijf nachten 0,0 per
  partij, op C28 nog 9,0; de Beer na cyclus 5, r3 van 1,65 naar 0,26).
- **De zes trainers laden het profiel van de anderen een keer, bij de
  start.** Een factie die laat in de cyclus adopteert verrast de rest pas
  in de matrix.
- **De valse Leeuw-adoptie van cyclus 1** (verificatie 9,9 tegen een
  toevallig lage referentie van 7,7) won in de matrix 36,3% tegen 48,8% met
  de oude bot, en tegen elke tegenstander minder. Gewichten terugzetten
  alleen na zo'n directe vergelijking van oud en nieuw.
- **De Muis leert niet omdat hij te weinig generaties krijgt.** Een
  Muis-generatie duurt 3,3-4,4 keer zo lang als een Leeuw-generatie (90-130
  min tegen 20-35): 20 generaties in vijf cycli tegen 72 voor de Leeuw. Niet
  door langere partijen (een Muis-partij heeft minder stappen dan een
  Leeuw-partij), maar door de tijd per stap. Zijn gewichten zijn van 7
  augustus. Lees zijn matrixcijfer niet als dat van een getrainde Muis.
- **Tel adopties uit de logs** (`grep -c GEADOPTEERD` of de kopregel van
  `data/matchup_<factie>.txt`), nooit uit het hoofd: het Varken adopteerde
  in cyclus 5 twee keer, niet een keer zoals commit cedb219 zegt.
- **Een trainingsnacht kan een test breken.** V42AgentTests speelde met het
  getrainde profiel en faalde toen de Beer leerde minder CP te bieden.
  Tests die een mechanisme bewaken spelen op `AIController.default_weights()`
  (AgentTests en L4Tests doen dat nog niet). Draai na elke datacommit de
  suite, en lees een falende agent-test eerst als "speelt hij getrainde
  gewichten?".

## 4. Planning op deze machine (32 threads)

- **Het trainingsbudget loopt fors uit.** Een trainer start een nieuwe
  generatie zolang hij onder het budget zit, en maakt die af. Budget 420
  werd 455-523 min, budget 200 werd 297. Meestal bepaalde de Muis het eind.
  Het commentaar "~15 min uitloop" in training_nacht.ps1 klopte niet. **Plan
  een cyclus als budget + een Muis-generatie (~2 uur) + de nachtrun (~2
  uur).** In 48 uur passen vier cycli van 420 en een van 200.
- **De nachtrun** (fuzz 500 + matrix 3240 + dashboard) duurt alleen 1u46-1u50,
  met 8-16 andere Godots ernaast 22-30% langer. Stapelen levert geen
  capaciteit op: alles samen haalt dan ~0,6 partij/s. De fuzz draait als een
  enkel proces (10-13 min) voor de matrix start, en `-ArenaMinuten 60` doet
  niets: de matrix is altijd precies een batch. **Een hele cyclus** met 420
  min training duurde van start tot dashboard 9u36-10u29.
- **-Procs bepaalt hoeveel partijen je krijgt, niet hoe snel het klaar is.**
  Elk arena-proces speelt de hele matrix: partijen = procs x 36 x
  games_per_matchup. Een richting binnen het uur: 2 potjes per paar op 24
  processen (1728 partijen) in plaats van 5 op 8.
- **De factiezoeker vermenigvuldigt:** processen = kandidaten x --procs.
  `--procs 20` gaf 120 Godots op 32 threads. Naast iets anders hooguit
  `--procs 4`.
- **Tel voor elke start de processen op** en blijf onder ~32: een
  duel-trainer is een proces met 6 threads, zes trainers vragen dus al 36
  threads. De matrix 30, een variant 8, de datarun 20. Een Godot via de
  console-wrapper telt dubbel in de proceslijst.
- **Testsuite:** `.\tests.ps1` (9 processen) doet het in 552 s op een vrije
  machine, 757 s direct na een matrix, 1181 s naast een matrix. De seriële
  suite naast een matrix haalt het in 40 minuten niet. Draai tests nooit
  serieel naast een matrix of training. ("Passed: 2747" telt asserts; de
  suite heeft ~398 testfuncties.)

## 5. Gereedschap en valkuilen

- **Een Monitor loopt hooguit 30 minuten**, wat je ook opgeeft (83 keer
  gevraagd om 60, 83 keer 30 gekregen). Voor een bekende eindmijlpaal: een
  achtergrond-until-lus (onder de 2 uur).
- **Nooit `tail -F` op een log dat een PowerShell-script nog beschrijft.**
  Het hield het marathonlog vast (cyclus 1 kreeg na de startregel niets
  meer) en de tail-processen overleefden de Monitor: ze draaiden op 5
  oktober nog. Pollen met `wc -l` + `sed -n`, en in eigen scripts loggen via
  `[IO.File]::AppendAllText` met een paar pogingen.
- **Godot buffert bestanden per 4 KB en de arena flusht niet.** Bij een
  lopende of gestopte run zie je de voortgang niet en is de laatste regel
  half. De campagne-nameting op echte duels is afgeschreven als "te traag
  (15 van 96 campagnes in twee uur)", maar dat was een telfout: het waren er
  12 in de afgesloten bestanden (de 15 telde de kopregels mee), en uit de
  geflushte duels blijkt dat er minstens 75 klaar waren (een duel komt pas
  in het bestand als zijn campagne af is; nageteld per proces). Daarbij
  liep de factiezoeker met 120 Godots ernaast. Die nameting is dus nooit
  eerlijk gemeten.
- **Een leger van meer dan 22 pionnen** wordt alleen in de factiezoeker
  tegengehouden. Variant c31_b gaf de Beer 23 pionnen; alle Varken-Beer
  partijen liepen vast in de opstelling (afgekapt op 2501 stappen) en de
  run kroop. De push_error van RulesConfig komt niet in het variant-log.
- **Schrijven kan tijdelijk mislukken met Errno 22.** Maak patchscripts per
  bestand idempotent (eerst kijken of de nieuwe tekst er al staat) en
  probeer na een paar seconden opnieuw.
- Start python-runs die naar een bestand schrijven met `-u`.

## 6. Campagne en punten

- **De bot-duels in de campagne spelen op AIEasy met de standaardgewichten,
  niet met de getrainde L2-bots.** Daarin wint de Wolf 92% van zijn duels
  (zonder spiegelduels), de Leeuw 31% en de Krokodil 27%; het orakel erft
  dat. Vijf cycli duel-training hebben de campagne dus nooit bereikt, en
  "de campagnebalans" is een andere balans dan de nachtmatrix. De keuze
  easy of L2 (docs/F7-campagnetrainer.md paragraaf 6) ligt weer open.
- **Een campagne-datarun loot geen verse seeds** (vaste base_seed 7000,
  proces i krijgt offset i x 100000). Omdat de duels AIEasy op
  standaardgewichten spelen, is elk duel zonder de gewijzigde factie
  byte-identiek aan de vorige run: over de marathon 1696 van 2400 duels en
  ~32 van 43 Godot-uur herhaling. Ondertussen had het orakel juist te
  weinig data. Beter: verse seeds per datarun, en de duels van ongewijzigde
  factieparen hergebruiken (het C30-orakel had dan 2054 in plaats van 1200
  duels gehad).
- **Het orakel voorspelt niet beter dan het factiepaar alleen** (Brier
  0,1733 tegen 0,1755 op C29, 0,1719 tegen 0,1659 op C30; binnen de ruis).
  De reserve- en CP-emmers zijn te fijn voor 1200 duels (1,6 rij per
  emmer). Grover maken, of minstens 3000 duels.
- **De poort van de campagnetrainer laat ruis door.** Over 186 controles
  gemiddeld 49,9% met spreiding 1,7; precies de 7 die op 53% of hoger
  uitkwamen werden adopties, en op toeval verwacht je er 6,5. Geen enkele
  run haalde de F7-check (>55%); tegen de handbots 48,3-52,5%. Het
  verstand dat het spel laadt heeft dus geen aantoonbaar voordeel, en
  "leren gericht doneren" is niet gemeten.
- **Team links wint met gelijke bots 42-45%**, omdat de factieverdeling
  vastligt (stoel i krijgt factie i%6). Meet team tegen team altijd met
  wissel.
- **De puntenbots pesten niet**, bij kroonfactor 1, 2 en 3 (w_rivaal
  0,00-0,04, burgeroorlog 44-46%). Ze leerden ook vrijwel niets (0, 2 en 1
  adopties, de 2 waren ruis). Bots kunnen Max' ontwerpvraag over pesterij
  niet beantwoorden: P5 (tabel v1 vastzetten) aan Max voorleggen en de echte
  toets laten bij de speeltest met mensen.
- **Het teamverstand verandert het gedrag sterk, maar de uitslag niet:**
  slechte matchups in de raad 10% van de nominaties tegen 30% bij de
  handbots, burgeroorlog 46% tegen 63%. Beoordeel een verstand op
  teamwinst met wissel, niet op gedragsmaten.

## 7. Het neurale net

- L4 won 40,3% +-4,0 van L2 (576 partijen), elke factie onder de 50, en
  rekende ~1,1 s per beslissing op een volle machine.
- **Lees dat niet als "het netwerk kan L2 niet eens nadoen":** de proef
  trainde het scorenetwerk met de uitslag-term aan (`train_net.py`-default,
  0,5), en die variant speelde op 22 september al slechter dan de kopie met
  alleen imitatie; er was ook minder data, en L2 trainde tijdens datarun en
  meting door. Het oordeel van 22 september blijft: imitatie maakt L4
  hooguit gelijk aan L2. Alleen nog selfplay of een tweede ply, en pas als
  de duel-trainer stabiel is. Zet bij een herhaling `--uitslag 0` voor het
  scorenetwerk.

## 8. Werkwijze

- **Een doel op een uitkomst die uit het spelverloop volgt is geen eis.**
  "Burgeroorlog in 70% van de campagnes" stond als eis in het plan en zou
  een volgende stap blokkeren (Max: "waarom wil een plan 70%, hangt toch
  gewoon af van het verloop"). Zulke frequenties meet je ter info; een getal
  dat je zelf bedenkt noem je een gok.
- **Wat de eigenheid van een factie raakt (een perk) gaat langs Max**, via
  AskUserQuestion met de aanbeveling bovenaan en het percentage voor en na.
  Kaartbudget, leger en compensatie binnen een balansmandaat beslis je zelf.
- **"Start zelf de training" gold voor die ene opdracht** (uitzondering op
  B13). Na de marathon start je niets meer zonder nieuwe opdracht.
- **Gebruik vrije kernen in een marathon:** na elke matrix de factiezoeker
  op de factie die het langst buiten de band zit (`--facties N
  --achtergrond <laatste matrix> --procs 4`). Op de laatste dag lag er ruim
  vier uur aan vrije kernen ongebruikt, en daardoor eindigde het rapport met
  een opdracht in plaats van een gemeten voorstel.
- **Laat een beloofd acceptatiecriterium niet stil los.** Het nieuwe
  campagneverstand zou alleen in het spel gaan als het op echte duels iets
  toevoegde; die nameting lukte niet en het ging er toch in, zonder dat het
  rapport dat zei. Beloof alleen wat binnen de tijd meetbaar is, en zeg
  anders wat er wel gebeurde.
- **Een bewering wordt niet sterker tussen tussenrapport en eindrapport.**
  "Waarschijnlijk de reden voor het plateau" werd "dat is de reden", en "de
  bots vinden weer echte verbeteringen, dat zie je in de metingen" stond
  erin zonder dat nieuwe tegen oude gewichten was gemeten. "Beter" alleen na
  een meting van nieuw tegen oud; het chatrapport is nooit sterker dan
  WIP.md.

---

## Open punten

Niet opgepakt, op volgorde van wat het meest oplevert:

1. **Balans (C31):** de Leeuw (een ruiter minder, c31_a, nu gepaard meten
   met een _ref tegen de huidige bots) en de Krokodil (factiezoeker
   gericht, `--facties 5`). Pas vastzetten met een trainingsnacht erachter.
2. **Campagne-duels:** easy of L2 (de Wolf wint 92% van de easy-duels).
   Daarna een verse datarun (met verse seeds, oude duels van ongewijzigde
   paren erbij) en een nieuw orakel.
3. **Trainer:** een gepaarde adoptiepoort (kandidaat en kampioen op dezelfde
   seeds), loting in de convergentiecheck, de Muis een eigen instelling
   (minder potjes of een eigen nacht), het profiel van de anderen
   herladen, en de CP-inzet zonder harde drempel (of de spaarbonus W_CP
   eruit).
4. **Meetgereedschap:** een hash van de gewichten in de run-metadata, flush
   na elke partij in de arena, de 22-pionnen-grens ook in meet_variant en
   de arena, en een bevroren kopie van de gewichten voor metingen naast een
   trainer.
5. **Kleur in spiegelpartijen:** waarom wint stoel 1 daar 56,8%?
6. **Tests op standaardgewichten:** AgentTests en L4Tests.
