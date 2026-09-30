# Fog of War — Work In Progress & Context

## 30 september -- F6.0 P4: bots op punten (knoppen, trainer, meetketen)

Max: "en?" (na P1-P3; de F7-datarun van 29 september lag er).

- **De nacht van 29 september (F7):** het orakel uit 1860 gemeten duels is
  bruikbaar (Brier 0,169). De campagnetrainer haalde in 17 generaties 3
  adopties; het verstand leerde vooral "kies goede matchups" (`w_matchup`
  0,63) en wint 52-54% van de handbots (doel >55%). Nog niet op echte duels
  nagemeten; staat lokaal aan (`data/campagne_verstand.json`, niet gecommit).
- **Twee knoppen van eigenbelang** (`w_sparen`, `w_rivaal`, maal de druk =
  1 - vijand/eigen). `CampaignAgent.zaai_plekken` rekent de zaaiplek zoals
  `CReducer.seed_volgorde` (roem, CP, pool, id), uit de teamsaldi van de view.
  Rivaal: bij w x druk >= 0,5 geen versterkingen voor wie boven je staat
  (eronder achteraan in de rij), en in de raad een bonus op hem plus een
  omgekeerde matchup-term (liefst tegen een vijand waar hij van verliest).
  Op 0 dezelfde keuzes en evenveel trekkingen (getest).
- **Fitness "punten"** in de campagnetrainer (`meet`, `speel_punten`):
  gemengde stoelen om en om, per seed ook omgedraaid; adoptie vraagt ook een
  positief gemiddeld verschil (de rooktest had een kandidaat die vaker won
  maar gemiddeld verloor). `sleutels`: de teamtrainer laat de nieuwe knoppen
  met rust, dus zijn loting blijft gelijk. `start`: de puntentrainers beginnen
  bij het teamverstand en schrijven dat meteen weg, anders meet een meting na
  een nacht zonder adoptie de handbots.
- **Arena:** `verstand_pad` per team, `per_stoel`, en per campagne `punten`
  per stoel (met `tabel`), `burgeroorlog_spelers`, `donatie_rondes`; met
  `meet_raad` speelt hij het log na en telt hij wie de raad stuurde
  (roemleider, winkans onder 40% volgens het orakel).
- **Meetketen voor Max:** `tools/punten_meting.ps1` en de paneelknop "Punten
  meten (3 tabellen)" (kader Campagnebots, derde rij; het paneel is 42 px
  hoger). Drie trainers tegelijk (een kern elk), dan vijf metingen van 1000
  campagnes, dan `tools/campagne/punten_rapport.py` -> `rapport.md`.
- **Proef zonder training:** eigenbelang loont niet (44-48% van de campagnes,
  0 tot -0,5 punt per stoel, bij elke kroonfactor) en kost het team niets
  (49-52% teamwinst).
- **Nulmeting** (`results/punten_20260930_0934`, 1000 campagnes elk):
  burgeroorlog 60% met de handbots (gem 3,2 spelers, 58% met 3+),
  43% met het teamverstand (gem 2,8, 42% met 3+). Het plan wil 70%
  en meestal 3+. In 57% van de campagnes houdt het winnende team met het
  teamverstand een speler over: die wordt kampioen zonder strijd. Dat is de
  eerste knoop, niet de kroonfactor.
- Checks: CampaignTests 403 (was 343; `test_p4_*`: zaaiplek = reducer, druk,
  knoppen op 0 veranderen niets, rivaal en sparen doen wat ze zeggen, de
  puntenfitness is symmetrisch en de arena telt, trainer-sleutels en start;
  met een nep-orakel in de test, een campagne van 16 in milliseconden), de
  volle batterij 2664 geslaagd, 0 mislukt (was 2604).

## 29 september -- F6.0 P1-P3: punten in de core en in solo

Max: "doe maar" (op P1-P3 uit het puntenplan).

- **P1, de core.** De reducer houdt bij wat de punten nodig hebben: `uitval`
  (ronde, burgeroorlog ja/nee, en in de burgeroorlog de grootte van de
  bracketronde: de duels daarin zijn gelijktijdig), `stunts` (p2 wint van p1:
  in de bracket is p1 altijd de hogere plek), `testament_naar`, en de dank.
  Nieuwe actie `DANK`, de enige na de kroning. `core/campaign/uitslag.gd` en
  `puntentabel.gd` rekenen puur op de eindstaat. "Laatste stand" is anders
  dan in het plan stond: iedereen van het verliezende team die pas in de
  laatste ronde viel (niet "de laatste 2"), om dezelfde reden. Plan
  bijgewerkt.
- **P2, solo.** Eindscherm: "JOUW PUNTEN 27 Bekijk hoe" (venster met elke
  regel, het totaal en je badges) en de top drie op punten. Spelregels: een
  kaart "Punten (online)" uit de puntentabel, plus de regel over de
  #-plaatjes. Schaduwbracket: vanaf ronde 3 "#1", "#2" bij de levende schilden
  van je team (de #1 in goud), bij de donaties en in het venster van een
  teamgenoot.
- **P3, pesterij.** Vijf zinnen in een groep RIVALITEIT (in de burgeroorlog
  vooraan in de balk), bots antwoorden naar karakter op de chat-rng. Een stunt
  staat in rood op het slagrapport. Ben jij kampioen, dan bedank je eerst een
  gevallen teamgenoot (of niemand); een bot-kampioen doet dat zelf. De dank
  komt als kaartje in de tijdlijn.
- **Bug erbij gevonden (al ouder):** besliste jouw eigen duel de campagne
  (en in de finale zit je altijd zelf), dan ging de hub na het bord naar de
  factiekeuze en zag je het eindscherm nooit. Nu zet `CampaignBridge.rond_af`
  de vlag `terug_van_bord` en pakt de hub dan ook een afgelopen campagne op.
  Fixture-modus `terug` controleert het.
- Checks: CampaignTests 343 (was 270; `test_f6_*`: het voorbeeld uit het plan
  79/55/44/16/0, een mini-campagne door de reducer met elke regel, de
  dank-regels, oude saves, giften, de bot-dank), SoloTests en de volle
  batterij: zie de commit. Fixture: modi `punten` en `dank`, en `_nl` achter
  elke modus voor Nederlands.

## 29 september -- masterplan: punten verdienen en krijgen (online)

Max: "Bouw nu aan een masterplan voor online punten verdienen, en krijgen,
sowieso de incentive als het team wint, maar ook als jij wint, zo dat je ook
die burgeroorlog-tactieken triggert en onderling pesterij."

- **Plan:** `docs/F6-punten-masterplan.md`, in het MASTERBOUWPLAN als F6.0.
  Twee potten per campagne: de **teampot** (+20 voor het hele winnende team,
  ook wie eruit ligt) en de **kroonpot** (kampioen +40, finale +20, dan
  aflopend), plus +1 per roem, stunt (+5, een hoger geplaatste teamgenoot
  verslaan), dank van de kampioen (+10), koningsmaker (+5) en laatste stand
  (+5). "Het team is je toegangskaartje, de kroon is de hoofdprijs."
- **Waarom het werkt:** bij de start is je team ongeveer twee keer zoveel waard
  als je kroonkans; hoe dichter de overwinning, hoe meer je plek in de
  burgeroorlog telt. De kroonfactor (kampioen ÷ teamwinst, v1: 2) stelt dat
  kantelpunt in; de bots meten 1, 2 en 3 met de campagnetrainer (fitness
  "eigen punten", na de F7-datarun).
- **Pesterij** zonder nieuwe regels: de raad als wapen, doneren of houden,
  testament; erbij: schaduwbracket met punten, vier rivaliteitszinnen in de
  (team-only) quick chat, badges voor één seizoen. Punten zijn nooit
  overdraagbaar; geen punten voor of tegen beloftes.
- **Techniek:** uitslag en puntentabel in de core (GDScript, één waarheid
  voor solo, trainer en worker), ladder en seizoen in Node, boekingen
  append-only met een uniek sleutelpaar per campagne en reden.
- Nog niets gebouwd. P1-P3 kunnen nu; negen besluiten met een default in §10.

## 29 september -- spelregelscherm voor de campagne (en: doneren als je dood bent)

Max: "hoe werkt het ook alweer met doneren als je dood bent in de campagne",
daarna "schrijf alles op ook in een UI conforme spelregel scherm", "simpele
taal en zo weinig mogelijk tekst" en "iconen wel gebruiken".

- **Het antwoord (uit `CReducer`):** doneren kan alleen een levende speler,
  aan een levende teamgenoot. Wie valt (duel verloren en geen versterkingen
  meer) krijgt een keer een testament: hooguit de helft van wat hij nog heeft
  (per soort en CP, naar beneden) aan hooguit 2 levende spelers, eigen team
  of vijand; de rest verbrandt, niets kiezen = alles verbrandt. Je valt pas
  als je versterkingen op zijn, dus in de praktijk is het de helft van je CP
  (en zonder CP is er geen testament). In de burgeroorlog geen testament: de
  verliezer verbrandt alles. Daarna geen stem en geen chat, wel alles zien;
  de teambonus (+2 roem) krijg je ook als dode.
- **Het scherm:** `scripts/ui/campaign/hub_regels.gd` bouwt acht kaarten
  (doel, bezit, een ronde, doneren, het duel, als je valt, burgeroorlog,
  quick chat), per regel een icoon en een korte zin of icoon-getal-paren. De
  getallen komen uit `CRules` en `RulesConfig.CAMPAIGN_DEFAULTS`, dus ze
  lopen niet uit de pas met het spel. `_toon_regels` (via `_keuze_scherm`,
  sluiten met de X) vervangt het uitleg-venster van 27 september; ook te
  openen met "Hoe werkt de campagne?" op de factiekeuze.
- Fixture: modus `regels` (plaatjes boven en onderaan), `factie` controleert
  de link. 41 teksten erbij, 7 weg (de oude uitleg).
- **Moderne taal** (Max: "gebruik beetje moderne taal dit is niet echt
  leesbaar"): elke regel herschreven zoals je het zou zeggen ("Blijf als
  laatste over en je bent kampioen", "Wat je inzet, ben je kwijt", "Van de
  vijand zie je alleen een ?"), geen woorden als levenden, nalaten of
  nagekomen; tekst een tik groter (`KOP`/`TEKST`/`GETAL` in hub_regels.gd),
  buit als twee eigen regels (vaandeldrager gepakt +2, tamboer gepakt +4).

## 29 september -- C27 terug naar C26, bots leren CP beter inzetten

- Max: "naar c26 en opnieuw trainen ook met campagne modus, want volgens
  mij snappen de bots nog niet goed hoe belangrijk de CP en reinforcements
  kunnen zijn". Leeuw weer budget 8, [12,4,2] (+6 pt / +5 CP blijft).
  Rules, goldens, golden_sims uit 331bac3^. simcheck 0, uispel 777 =
  `533fd17e` (zelfde partij, 171/4, alleen de staat-hash).
- **Vermoeden klopt, twee gaten in de bots:** (1) `cp_bet_r1`/`r2` stonden
  voor alle facties op 0,01 en de trainer muteerde multiplicatief
  (x e^N(0;0,25)), dus die konden nooit een hele CP worden: iedereen zette
  alleen in ronde 3 in, de Leeuw 1 CP per cyclus uit 15 start-CP. Nu
  optellend (`CP_BET_STAP` 4 x sigma = 1 CP bij sigma 0,25, geklemd 0-6).
  (2) Het CP-punt ging hard naar HP op vier plekken (l2_weights,
  match_runner, game.gd, capture.gd): nu `AIController.kaarten_met_cp`
  met leerbare `cp_naar_hp`/`_atk`/`_stam` (default HP; valt terug op HP
  bij een factiegrens). Byte-identiek bewezen (uispel met en zonder).
- `tools/nacht_met_campagne.ps1`: training_nacht (480 min) -> campagne-
  datarun (campagne_arena, orakel) -> campagnetrainer (60 min).

## 29 september -- trainingsnacht op C27 (10 uur): de Leeuw schiet door

- Training 28 september 19:10 (600 min): Varken 2, Beer 1, Leeuw 1, rest 0.
  Gewichten apart gecommit (74c7979). Fuzz 500/0, simcheck 0, uispel 777
  ongewijzigd 0561707 (Muis en Wolf adopteerden niet).
- Matrix 
esults/nacht_20260929_0624_v42_matrix_l2 (3240): Leeuw 55,7,
  Muis 53,4, Varken 51,0, Krokodil 48,4, Beer 47,3, Wolf 44,1. Band
  44,1-55,7 (11,6 pp). Tegen de C27-controle met oude bots: Leeuw +9,2,
  Muis +7,0, Beer -7,3, Wolf -6,9. Foutmarge ~+-3 pp per factie.

## 28 september -- C27 aangenomen: Leeuw budget 9, leger [11,5,1]

- Max: "adopteer dan zijn we er wel toch". Alleen het doctrines-blok in
  `rules_v42_campaign.json`; rules_version blijft 4.3.7. CHANGELOG C27,
  CLAUDE.md (tabel + stand).
- Trainingsnacht 27 september (op de regels van VOOR C27): Varken 2, Wolf
  1, rest 0; gewichten apart gecommit (2041929). Matrix
  `results/nacht_20260928_0431_v42_matrix_l2`.
- Goldens opnieuw, golden_sims geijkt (leeuw-beer 202: 2/4/88, wolf-leeuw
  404: 1/8/188), simcheck 0, uispel 777 = `a0561707…` (171, 4).
- Volgende: een trainingsnacht OP C27 (de Leeuw-bot kent budget 9 en
  [11,5,1] nog niet), dan de matrix als echte stand.

## 27 september (middag) -- factiezoeker voor de Leeuw + controlemeting

- Zoeker (08:29-12:55, 6 generaties, achtergrond nacht_20260927_0559):
  voorstel Leeuw budget 8 -> 9, comp [12,4,2] -> [11,5,1] (startcompensatie
  +6 pt / +5 CP blijft). `results/facties_20260927_082952/voorstel.json`.
- Controle op de volle matrix (4320 partijen per variant, tegen de
  nachtmatrix van 27 september):
  - `leeuw_zoeker` (budget 9 + [11,5,1]): Beer 54,7, Varken 53,1, Wolf
    51,0, Krokodil 48,3, **Leeuw 46,5**, Muis 46,5. **Band 46,5-54,7, 8,2
    pp**, de smalste tot nu toe. Muis zakt 6,4.
  - `leeuw_1151` (alleen de ruil, budget 8): **Leeuw 32,2** (-8,7). Het
    kanon eruit kost de Leeuw veel (zijn perk is artilleriedracht 7); de
    ruil werkt alleen samen met het extra budget.
- NIET aangenomen: wacht op Max. Aannemen = C27 in het doctrines-blok,
  CHANGELOG, goldens + golden_sims + uispel opnieuw.
- 19:56 een TRAINING-NACHT gestart (Max: "start nog een master run") via
  wacht_en_start + WMI, op de HUIDIGE regels (Leeuw budget 8, [12,4,2]).

## 27 september -- de campagne-UI kritisch nagelopen en strakker gemaakt

Max: "kijk nog eens kritisch naar de hele ui campagne kan je het nog beter
maken en strakker?" Eerst elke toestand gefotografeerd met een nieuwe
fixture (`-- shot campaign_hub [seed] [modus] [orakel=<pad>]`,
`tools/hub_shot.gd`, 18 modi; met een orakel spoelt hij in seconden door),
dan per plaatje nagelopen. Wat er mis was en wat het nu is:

- **Hoofdknoppen vielen onder de vouw** (fasepaneel scrolde, met de grijze
  standaardbalk). Nu een vaste voet `FaseVoet` onder het paneel: NAAR HET
  BORD, KLAAR, NALATEN AAN ..., NIEUWE CAMPAGNE staan altijd in beeld;
  bijzaken (blijven, niets nalaten, de andere paren) zijn tekstlinks.
  Overloop toont een dunne inktlijn in plaats van de grijze balk.
- **Tijdlijn stond seconden leeg** bij binnenkomst (de onderste kaartjes
  kwamen tot 4 s later): nu een golf van hooguit 0,8 s.
- **Duel**: was een lange zin met em-dash, "Blijf in de hub" groter dan de
  hoofdknop, geen aftelling, zeven keer "nu op het bord". Nu JOUW DUEL,
  jij tegen hem gespiegeld (schild, naam, factie, versterkingen/CP), een
  regel uitleg, de rode knop met een aftelbalk van 2,5 s; de paren in een
  eigen venster (`_toon_paren`).
- **Testament**: was een OptionButton "Piet (team 0)" zonder te zien wat je
  nalaat. Nu "de helft van je bezit" (exact de regel van de reducer,
  `testament_fractie`) met een pijl naar je erfgenaam, en NALATEN AAN
  <naam>. De erfgenaam kies je zoals in de raad: tik een schild in de
  kolommen (gouden ring) of het schild in het paneel (volgende); eigen team
  eerst, de vijand mag ook. Een raster met alle kandidaten liep bij 8+
  spelers over.
- **Burgeroorlog**: de BracketView van de veldtafel is weg (hij toonde elk
  paar twee keer: `c.bracket` en `duels_deze_ronde` zijn dezelfde paren). Nu
  BURGEROORLOG: JOUW DUEL met "Nog in de strijd: ...", of als jij niet aan
  zet bent de paren van de knock-outronde.
- **Donaties**: per teamgenoot zijn saldo en "kreeg x/10 · y/3 CP", de
  plusjes uit bij de cap of als je niets hebt; KLAAR is de rode hoofdknop.
- **Slagrapport-kaartje** telde gevallen pionnen ("-33"), vooral het
  startleger dat elk duel terugkomt. Nu het netto reserve-verlies (inzet
  min buit, punten) en drie figuurtjes voor het deel van de reserve; de
  driver en het orakel geven daarvoor `reserve` mee in de uitkomst. Het
  venster is nu twee kolommen (schild, WINNAAR, reserve ingezet, buit, CP,
  gesneuveld) met de winmethode in woorden.
- **Einde**: kampioen met de samenvatting ernaast en de top drie op een rij.
- **Lid-venster, doelkeuze, uitleg**: het lid toont factie, stand, tegen
  wie hij vecht en tent/medaille/ster ("?" voor de vijand, D12); "WIE
  STUREN WE?" in plaats van "STUUR ...!"; de uitleg is zes blokjes met een
  icoon in plaats van een lap tekst. Quick-chat-iconen staan niet meer
  onder de hoekbeslagen. JIJ staat bovenop je eigen schild; de zandloper
  draait zolang de bots werken.
- **Keuzeschermen** (factie, hervatten, laden) waren nog de veldtafel van
  juli: nu in de stijl van de hub (`_keuze_scherm`), gecentreerd.
- **Grootboek**: de tent telde stukken (9) waar de hub punten toont (13);
  nu overal versterkingspunten. Team als "jouw team"/"vijand" in blauw en
  rood met de schilden van de hub. Bruno stond er twee keer in: 15 namen
  voor 16 spelers (`Personalities.NAMEN` heeft er nu 20; de eerste 15 zijn
  gelijk, dus bestaande campagnes veranderen alleen de dubbele Bruno).
- Em-dashes uit de campagneteksten; 25 dode sleutels uit `strings.csv`, 31
  nieuwe voor de panelen, de uitleg en het grootboek.

Checks: `tests.ps1` 2531 geslaagd, 0 fout; alle 18 modi van
`-- shot campaign_hub 42 <modus> orakel=<14 duels>` 0 fouten, plaatjes
nagekeken. Voor/na-vel: `campagne_ui_voor_na.png` in de sessie-scratchpad
(niet in git).

Open voor Max (niet aangeraakt, is een regelvraag): `pool_totaal_van` telt
voor de C3-eliminatie nog stukken, niet punten.

## 27 september -- twee trainingsnachten op C24+C25+C26: de Leeuw zakt weer

- **25 september** (07:55-16:03, via WMI): Varken, Beer, Wolf elk 1
  adoptie, Muis/Leeuw/Krokodil 0, geen afgekapte partijen (noodstop 2500
  werkt). Matrix erna `results/nacht_20260925_1603_v42_matrix_l2`.
- **26 september** (Max, 22:06-05:59): Leeuw 1 (gen 21, verificatie 8,9
  tegen 7,8), Wolf 1, rest 0. Matrix `results/nacht_20260927_0559_v42_matrix_l2`.
- Gewichten apart gecommit (0163d09).
- **Band** (25 / 27 sept): Beer 52,8/54,4, Muis 53,8/52,9, Wolf 53,9/52,2,
  Krokodil 51,8/50,6, Varken 47,5/49,1, **Leeuw 40,3/40,9**. Samen
  40,6-53,6, 13 pp; op 24 september met de oude bots 44,8-54,1 (9,3 pp).
  De anderen leerden bij, de Leeuw nauwelijks: zijn trainer draait de
  meeste generaties (20+ per nacht, korte partijen) maar vindt niets. Alle
  facties zitten op een plateau (Muis en Krokodil twee nachten 0).
- `-- simcheck` 0 afwijkingen (easy/medium gebruiken de getrainde
  gewichten niet). `-- uispel 777` = `4df2aeed…` (62 acties, cyclus 2;
  was `9e0c375b…`): de Wolf heeft twee keer geadopteerd.
- Volgende knop voor de Leeuw: versterkingspunt ~0,6 pp, start-CP ~0,36
  pp; 4 pp dicht je daar niet mee. Een kaart erbij is ~23 pp (te grof).
  Kandidaten: een ruiter erbij (~18 pp per ruiter volgens de oude meting,
  dus eerder een halve stap via een ruil kanon -> ruiter) of een
  factiezoeker-run gericht op de Leeuw.

## 25 september -- varken-levering nagekeken: het ene probleem was een vals alarm

Max plakte de uitvoer van `verwerk_levering.py` op `assets/new upload
folder/pig` (tien modellen, veertig jassen, alles OK) met onderaan "1
probleem(en)": `zweef pig: wapen-hand 0.35 (prop tripo_node_6ef51aab...)
... rol=flag`.

**Vals alarm, van mij.** Dat is de vaandelstok (`prop_pole`, zelfde uuid als
de textuur `prop_pole_Color_6ef51aab`), die door zijn lengte op 0,35 van de
hand zit. Het script las de EERSTE `[ZWEEF]`-regel als uitslag; sinds 8
september print de zweefcheck eerst de wapen-tot-hand-lijst (verste
bovenaan), dus elke levering meldde dit. Nu leest hij de regel met
(PASS)/(FAIL).

**Tweede fout erbij: de verkeerde factie.** Het script geeft de mapnaam door
(`pig`, `mouse`); de zweefcheck kende alleen varken/muis/leeuw/beer/wolf/
krokodil en viel anders terug op de standaard, het varken. Voor het varken
klopte het toevallig, een muis-levering werd dus nooit echt gecontroleerd.
Nu kennen zweef-, wind-, richting-, wapenroute-, debris- en linkcheck ook
de mapnamen (`_met_mapnamen`), en de zweefcheck meldt welke factie hij meet.

**Richtingcheck in de controleronde, oordeel op de rusthouding.** Alle tien
de varkens staan in rust recht (-2 tot +3 graden, omhoog 0,99-1,00). Vier van
de vijf cavaleristen staan in de idle die het spel kiest (de stilste) 37-44
graden schuin: dat is de gevechtshouding van die Mixamo-clip (bij `hp` is het
`Idle 1`, bij de anderen `Idle 3`), geen bestandsfout, en op het bord zie je
het nauwelijks (`_shot_richting.png` bekeken). De check oordeelt daarom op de
rusthouding en toont de idle-hoek als info; de scheve varken-atk van 18
september (-110 graden in rust, omhoog -0,44) valt er nog steeds door. Het
leveringsscript draait hem nu per factie mee.

**Wat er verder in de levering zit.** `cavalry_hp` had een actie "Pommel
strick" (verschreven): het spel herkende hem niet en die ruiter miste dus
een melee-variant. Op verzoek van Max ("kan jij die niet hernoemen") in
`pig hp.blend` hernoemd naar "Pommel strike" (headless Blender, zonder
.blend1; het origineel als reservekopie in de werkmap van de sessie) en
`cavalry_hp` opnieuw gebouwd met `verwerk_levering.py` op die ene map: vier
jassen 99,7-100%, controleronde zonder problemen, `-- cliplengtes` geeft nu
`Pommel strike -> melee2`. Hij heeft ook twee
charge-clips ("Run jump attack" en "Standing Melee Run Jump Attack " met
een spatie, beide 3,71 s); het spel neemt de eerste. Infanterie spd en mix
delen hetzelfde musket (zelfde tripo-uuid), de .blends zelf verschillen.

**Checks.** Controleronde van het script op de tien varkens (zonder
`--import`, er liep een trainingsnacht): 0 problemen; `zweefcheck mouse` en
`pig` meten nu hun eigen factie, PASS; `richtingcheck pig` 10/10 PASS.
De varken-modellen zelf zijn nog niet gecommit (werk van Max' levering).

## 25 september -- F7: de campagnetrainer (hoe bots handelen in het menu) + hub-saldi

Max: "ook hier moeten we een campagne trainer strategie maken voor de bots, hoe
te handelen in de campaign menu". Plan: `docs/F7-campagnetrainer.md`.

- **Gemeten:** een `easy`-campagneduel duurt ~40 s (L2 ~48 s, dus geen winst),
  een headless campagne met 16 bots en echte duels ~10 minuten (584 s, 19
  duels). Trainen op echte duels is onhaalbaar.
- **F7.1a campagne-arena** (`arena/campagne_arena.gd` achter `--campagne` in
  `arena/run.gd`, launcher `campagne_arena.ps1 [-Duels N]`, rapport
  `tools/campagne/rapport.py`): volledige bot-campagnes met per team eigen
  gewichten of verstand (`campagne_hand.json`, `campagne_validatie.json`) en
  losse duels over de invoerruimte (`campagne_duels.json`: factiepaar,
  reserve per soort, CP). Beide schrijven `duels.jsonl`. De duel-uitkomst is
  uit `verwerk_duel_uitslag` getild: `SoloDriver.duel_uitkomst` (per kant),
  `duel_record`, `duel_regels`, `speel_duel_staat`, `_boek_uitkomst`.
- **F7.1b duel-orakel** (`scripts/training/duel_orakel.gd`,
  `tools/campagne/maak_orakel.py` -> `data/duel_orakel.json`): trekt een ECHT
  gespeeld duel uit hetzelfde factiepaar met ongeveer hetzelfde reserve- en
  CP-verschil (emmers van 3 punten en 6 CP, steeds wijder tot er 8 zijn). De
  inzet schaalt als AANDEEL van de reserve in punten (eerst schaalde hij per
  soort: dan raakte de verliezer nooit leeg en duurden campagnes 100+ rondes).
  `SoloDriver.duel_modus = "orakel"`: 10 campagnes met 16 bots in 0,7 s,
  3-6 rondes en 15-17 duels (echt: 7 rondes, 19 duels). Het script meet op
  een controle-set de Brier-score tegen een model dat alleen het factiepaar
  kent. Nog GEEN echte data: dat is de datarun hieronder.
- **F7.2a verstand** (`CampaignAgent.verstand`, `VERSTAND`): w_matchup (de
  raad kiest het paar met de winkans uit het orakel), w_don_nood (geef waar
  een gift de winkans het meest optilt), w_geef (vrijgevigheid x (1+w), de
  gierigaard blijft 0), w_houden (houd meer als je zelf vecht), w_ruil (ruil
  CP boven een reserve; bots ruilden tot nu toe nooit). Leeg verstand = alles
  als voorheen. Bots lezen voorraad en CP uit het publieke grootboek
  (`saldo_uit_ledger`); de cview draagt nu ook de factie (openbaar).
  `data/campagne_verstand.json` (ontbreekt nog) wordt bij elke campagne
  geladen.
- **F7.2b trainer** (`scripts/training/campagne_trainer.gd`, `--campagnetrain`,
  `campagne_arena.ps1`/`campagne_train.ps1`, paneelkader "Campagnebots"):
  gespiegelde ES over de vijf knoppen, kandidaat-team tegen kampioen-team op
  het orakel (teams gewisseld per seed), adoptie na een controle op verse
  seeds (>= 53%), elke 5 generaties de check tegen 5 generaties terug en
  tegen de handbots.
- **Hub (Max):** onder elk schild versterkingen (tent) en CP (medaille); van de
  vijand "?" (D12, doden zien alles). De tijdlijn en de chat lopen als een
  chat: oud boven, nieuw onder, het venster scrolt mee. De loting staat nu
  voor de fasewissel die ze veroorzaakt.
- **Gevonden, niet opgelost:** `CState.pool_totaal_van` telt STUKS, terwijl de
  reserve sinds C11 in PUNTEN rekent en per soort negatief kan staan (ruiters
  gespawnd uit soldatenpunten). De uitvalcheck (C3) gebruikt die stukstelling:
  wie op 0 punten staat kan "actief" blijven, of andersom. Rapport en hub
  tellen punten. Beslissing voor Max (regel C3/C11).
- **Voor Max, in deze volgorde, als de duel-training klaar is:** paneel
  "Campagne-duels meten" (120 minuten geeft ~5.500 duels met 31 processen),
  dan "Campagnebots trainen" (60 minuten of meer), dan de kampioen op echte
  duels: `.\campagne_arena.ps1 -Config arena/arena_configs/campagne_validatie.json`
  (getraind tegen hand, teams gewisseld; `rapport.py` geeft de winkans).

## 25 september -- Quick chat volgens het campagneontwerp

Max: "de quick chats slaan niet echt op wat we hebben bedacht voor de campagne
toch?" Klopt: de zinnen uit de pdf van de ontwerper (dek me, verdedig de flank,
terugtrekken) zijn slagveld-commando's, en in de campagne vecht niemand samen
op een bord. Wat wij bedachten: UI-spec 2b.2 (team-only, ~12 vaste zinnen zoals
"Send me", "Donate to X", "Trust me", "Traitor!", verzegeld voor de doden),
intrige-voorstel P1 (gesloten zinnenlijsten, het spel is notaris) en P4 (elke
regel heeft botgedrag: leesbaar, feilbaar), masterplan F3.2/F5.2.

- De lijst (14, NL en EN): raad (Stuur mij!, Stuur X!, Pak X!), donaties
  (Versterking nodig!, Doneer aan X!, Bedankt!, Ik kan niets missen), duels
  en testament (Succes!, Goed gevochten!, Laat het aan mij na), altijd
  (Vertrouw me, Verrader!, Akkoord!, Nee.). De balk toont per fase de drie
  die erbij horen (in de raad met je keuze uit de kolommen: "Pak Ludo!"),
  "..." opent de hele lijst in groepen; een zin over iemand vraagt eerst wie.
- Alleen je eigen team: het chat-tabblad en de chatkaartjes in de tijdlijn
  tonen alleen je team (ook de barks); stemdetails (nominatiekaartjes) van de
  vijand zijn weg, de uitslag blijft. Gevallen: de balk is VERZEGELD en het
  tabblad zegt dat je team zonder jou verder praat.
- Bots luisteren (SoloDriver.quick_chat). Een verzoek (stuur, pak, doneer,
  versterking, nalaten) krijgt AKKOORD! of NEE. van hooguit drie teamgenoten,
  naar karakter (kans uit loyaliteit, vrijgevigheid, w_zelf, risico_afslag).
  AKKOORD! is een toezegging voor de rest van de ronde, en de bot komt hem na
  met kans loyaliteit (`CampaignAgent._nagekomen`: de trouwe generaal altijd,
  de rat bijna nooit). Dat werkt omdat de bots van jouw team pas stemmen en
  doneren nadat jij gestemd of "klaar" gedrukt hebt. Vechtende teamgenoten
  vragen zelf soms om versterking, en wie jij iets geeft bedankt je.
- Nooit in het campagnelog, eigen rng-stroom (`_rng.fork("quick_chat")`),
  zonder toezeggingen geen extra trekkingen: headless en determinisme gelijk.
- Tests: CampaignTests `test_qc_*` (nakomen bij loyaliteit 1, breken bij 0 en
  dan precies de keuze zonder toezegging, ongeldig doel telt niet, doneren aan
  wie beloofd is, driver: antwoorden = toezeggingen, nooit in het log, de doden
  zwijgen). Testbatterij 2531 geslaagd, 0 gefaald. Plaatjes: `-- shot
  campaign_hub 42 popup|chat|raad`.

## 25 september -- De trainingsnacht stierf mee met een app-update; trainer-noodstop naar 2500

- **Wat er misging:** de TRAINING-NACHT op C26 (gestart 24 september 23:10)
  stopte om 23:34, 0 generaties af. Windows-systeemlog: op 23:34:47 werkte de
  Claude-app zichzelf bij (service uitgeschakeld, nieuwe versie). Omdat de
  run door Claude was gestart (`Start-Process`, eigen venster) hing hij in
  de procesboom van de app en ging mee onderuit. Sinds vandaag start Claude
  lange runs via WMI (`Invoke-CimMethod Win32_Process Create`): de ouder is
  dan `WmiPrvSE.exe`. Wat Max via het paneel start heeft hier geen last van.
- **Gevonden in de logs:** de trainer kapte partijen af op 1400 stappen
  (augustus gemeten: max 932). Met de reserves van C24-C26 duren partijen
  langer: 23 september 23 Varken- en 23 Leeuw-partijen afgekapt, en een
  afgekapte partij telde als gelijkspel (1 van de 3 punten). De arena
  (grens 2500) kapte in 16.000 partijen NIETS af, langste 34 cycli.
  `TRAIN_MAX_STEPS` = 2500 op alle drie de trainer-plekken (aced24e).
  Geen spelwijziging; simcheck 0 afwijkingen.
- **Opnieuw gestart** 25 september 07:55 via WMI: 7 uur trainen op
  C24+C25+C26, dan matrix + dashboard, klaar rond 16:15.

## 24 september -- C26: de Leeuw +6 versterkingen en 5 CP; nu trainen

Max: "maar de Leeuw minder CP en meer reinforcements? zeg 5 CP en 1 of 2
extra reinforcements" en na de meting "ja vast en nu trainen!".

- **Nacht 23 op 24 september:** training op C24 + C25 (12:23-20:45, Beer 3
  adopties, Leeuw 1), daarna matrix `nacht_20260923_2045` (3240 partijen):
  band 41,9-54,2, alleen de Leeuw (41,9) buiten. Daarna vanzelf (via
  `tools/wacht_en_start.ps1`) Leeuw +4 CP en +8 CP gemeten.
- **Ochtend:** Max' voorstel gemeten, pt5/cp5 en pt6/cp5. Vier varianten
  naast elkaar (tabel in de CHANGELOG, C26): +6 punten en +5 CP geeft de
  smalste band, **44,8-54,1 (9,3 pp)**. Knoppen: versterkingspunt ~0,6 pp,
  start-CP ~0,36 pp.
- **C26 vastgezet** met `zet_budget_bonus.py leeuw --pt 6 --cp 5`
  (startreserve 12 inf, 15 CP). Goldens opnieuw, wolf-leeuw 404 geijkt
  (9 -> 7 cycli), simcheck 0, testsuite 2589/0, uispel 777 `9e0c375b...`.
- `meet_variant.ps1` splitst "a,b" nu zelf: via `powershell -File` kwam het
  als een naam binnen (de vangrail stopte hem meteen).

**Volgende:** TRAINING-NACHT op C24+C25+C26 (gestart na deze commit), dan
de matrix erna als nieuw ijkpunt.

## 23 september -- De Campaign Hub in het nieuwe ontwerp

Max: "MAAK DIT IN HET SPEL NU" bij de pdf `Campaign_hub.pdf` (drie pagina's:
hoofdscherm, de soorten tijdlijnkaartjes, het chat-frame) en de map
`fogofwar-assets/Campaign_HUB_UI` met de elementen.

- Elementen staan in `assets/ui/campaign_hub/<map>/` met de namen van de
  ontwerper (56 png's, VRAM-compressie uit, mipmaps aan). `HubAssets`
  (`scripts/ui/campaign/hub_assets.gd`) is de enige plek die de paden kent:
  9-patches, het ronde portret (schijf teal/zalm, gravure, gouden ring,
  statusbadge), knopstijlen, een silhouet-shader voor de factievlag.
- De hub (`campaign_hub.gd`) rekent in ontwerp-eenheden van het frame
  (564 x 981, de maat van BG.png) maal S = schermbreedte / 564; een hoger
  scherm geeft de kolommen meer hoogte, een breder scherm zet het frame in
  het midden. Opbouw: titelbalk (vlag, ronde + fase, ? en tandwiel),
  statusbalk (versterkingspunten, ruiters, kanonnen, CP, roem; tik =
  grootboek), jouw team / tijdlijn / vijand, tabbladen FASE en CHAT, het
  fasepaneel en de quick-chat-balk. Alle driver-aanroepen zijn gebleven.
- De raad zoals op pagina 1: je vechter en het doelwit kies je door een
  portret in de kolommen aan te tikken (of het portret in het paneel:
  volgende kandidaat); teamstemmen als rondjes, de balk telt de stemmen
  (er is in solo geen klok, dus geen nep-aftelling), STEM.
- Tijdlijn (pagina 2): `HubFeedKaart` bouwt per feed-item een kaartje:
  slagrapport, nominatie, donatie/ruil, testament, fase, stemuitslag,
  quick chat, systeem. Nieuwste bovenaan; de bovenste 12 nieuwe faden in.
  Daarvoor zet de SoloDriver meer in de feed (alleen presentatie, geen
  staat): `nominatie`-items, `fase`-items bij elke fasewissel (met de
  paren uit de raad), en bij donatie/ruil/testament `soort` + bedragen.
  Nominatie-barks staan alleen in de chat (anders dubbel).
- Quick chat (pagina 3): drie vaste knoppen plus het pop-upvenster met
  zes; een bericht komt in de tijdlijn en het chat-tabblad en soms
  antwoordt een teamgenoot (eigen RNG). Chat staat alleen in de feed,
  nooit in het campagnelog.
- `SoloTests` zocht het rapport als laatste feed-item; nu het laatste
  rapport (er kan een fasekaartje achter komen).
- Check: `-- shot campaign_hub [seed] [chat|popup|raad|donatie]`
  (capture.tscn, met venster voor het plaatje). `raad` speelt door tot de
  eerste raad na ronde 1 en zet voor het plaatje de mens terug op actief.
  Testbatterij (`tests.ps1`): 2498 geslaagd, 0 gefaald.
- Open: portretten tonen de factiegravure (er zijn geen generaalsportretten
  geleverd); de groene quick-chat-lint is een effen vlak (geen asset).

## 23 september -- C24: de Leeuw krijgt 4 versterkingspunten; de knoppen zijn nu gemeten

Max: "doe maar even niks met de Leeuw, behalve dan die reinforcements
increasen en dan Varken testen en daarna een superrun in de nacht."

- **Wat er gemeten is** (elk de volle matrix, getrainde bots van 21
  september): 3 kaarten voor de Leeuw +23,3 pp (36,6 -> 59,8, doorgeschoten),
  +2 versterkingspunten +1,3 pp (te klein). Daarmee staat de schaal:
  kaart ~23, kaartbudget ~27 (C20), ruiter ~18, **versterkingspunt ~0,6**,
  soldaat en legergrootte ~0. Voor het gat van twaalf punten bestaat geen
  hele knop.
- **CP is voor de Leeuw structureel minder waard** (opgezocht, niet eerder
  opgeschreven): een ingezette CP staat precies EEN kaart met budget+1 toe
  (`cp_effect_mode: define_budget`, `cp_inzet_max: per_kaart`). Met 2
  kaarten per ronde kan de Leeuw dus hooguit 2 CP per ronde omzetten, de
  Muis 5. Zijn hoge budget (8) compenseert de sterkte van een kaart, niet
  het TEMPO: hij activeert 2 pionnen per cyclus waar de Muis er 5 doet.
  Dat is waarschijnlijk de kern van zijn 37%.
- **C24 aangenomen:** `budget_bonus` Leeuw 0 -> 4 punten (startreserve 6 ->
  10 inf), gelijk aan de Muis. Gezet met het nieuwe
  `tools/balans/zet_budget_bonus.py` (drie plekken tegelijk, commentaar per
  regel blijft staan). Kaarten, budget, leger en perk ongemoeid;
  `rules_version` blijft 4.3.7 (factie-instelling, geen mechaniek).
- **Checks:** `-- facties` toont Leeuw 10 inf startreserve; goldens opnieuw,
  twee sims geijkt (leeuw-beer 202 en wolf-leeuw 404, allebei langer);
  `-- simcheck` 0 afwijkingen; testsuite **2592/0**; `-- uispel 777` nu
  `b9c2ee75...` (213 acties, cyclus 5).

**C25, dezelfde dag:** Varken [11,5,3] -> [12,4,2] (voorstel van de
factiezoeker van 22 op 23 september) gemeten op de volle matrix, 4320
partijen, bovenop C24: Varken 59,2 -> 49,4, Leeuw 36,6 -> 41,2, band
36,6-59,2 -> **41,2-53,4 (12,2 pp)**, niemand buiten 40-60. Vastgezet in het
doctrines-blok. Een eerste meetpoging stopte om 09:17 op 1552 van 5040
partijen (hing aan de sessie, die bij een modelwissel onderbrak); niet
gebruikt, want een half gelopen run speelt alleen de eerste paren en de
korte partijen. Sindsdien starten metingen in een eigen venster.
Goldens opnieuw, sim mens-vos 101 geijkt (19 -> 17 cycli), `-- simcheck`
0, testsuite 2589/0 (drie beweringen minder: het Varken heeft een pion
minder in de start-opstelling), `-- uispel 777` nu `6b820e3f...` (213, 5).

**Daarna:** de TRAINING-NACHT-pijplijn opnieuw gestart op de C24+C25-regels
(de eerste start om 11:48 liep op het oude Varken en is na 2 minuten
gestopt): 7 uur trainen, dan 60 minuten matrix en het dashboard.
`tools/wacht_en_start.ps1` zet zo'n klus klaar achter een lopende meting.

## 22 september -- L4 neuraal: de keten staat, de eerste datarun draait

Max las het TypeSafe-stuk over "System One models" (Jev) en vroeg of zo'n
model de bots slimmer zou maken. Nee: Jev kent het spel niet en leert niet
van de arena; de winst zit in een netwerk op EIGEN data, lokaal en
deterministisch. Max: "BOUWEN". F8.1 is daarmee naar voren gehaald (voor
F4.3j).

**Ontwerp (TD-Gammon, geen PPO):** L4 is dezelfde 1-ply greedy als L2, maar
de waarde van elke na-staat komt uit een MLP op `Kenmerken.van_staat` (65
getallen: alle termen van `evaluate()` ongewogen per kant, plus cyclus,
honger, ronde, wanhoop en de twee facties als one-hot). Een lineair netwerk
kan L2 dus exact nadoen; alles erboven is winst die 42 gewichten niet
kunnen uitdrukken. De kenmerken worden in GDScript berekend en zo gelogd:
Python rekent nooit zelf kenmerken, dus wat je traint is wat je speelt.

**Gebouwd:** `scripts/ai/kenmerken.gd`, `scripts/ai/neuraal_net.gd`
(forward pass in pure GDScript, float32-gewichten, double-rekenen, `proef`
in het json bewijst pariteit met numpy), `agents/l4_net.gd` (AgentL4 erft
AgentL2: actiefase en Wolf-stap via het netwerk, de rest L2; geen netwerk of
verkeerde kenmerk-versie = waarschuwing en byte-identiek L2),
`arena/beslis_log.gd` + haakje in AgentL2/AgentL4 (`"beslis_log": true`,
`"beslis_elke": 4`; per beslissing ALLE kandidaat-rijen + gekozen index,
per partij de uitslag; binair, formaat in de kop van het bestand),
arena-label `l4` en `l4:<pad>`, `tools/l4/train_net.py` (numpy-MLP, Adam,
imitatie = softmax over de kandidaten, uitslag = sigmoid van de gekozen
na-staat; validatie gesplitst op PARTIJ), `-- netcheck [net=<pad>]
[seed]`, `tests/L4Tests.gd` (6 tests, 52 asserts).

**Gemeten (rooktest, 4 partijen L2 vs L2 met volledig log):** 400
beslissingen per partij, gemiddeld 62 kandidaten, 6,5 MB per partij bij
elke beslissing, 150 s per partij (het log simuleert alles nog een keer);
daarom `beslis_elke` 4 voor de echte run. Netwerk 65-48-48-1 op die 4
partijen: pariteit `-0.265173` in beide talen, L4 speelt 313 stappen
legaal (0 illegaal, 0 terugval), 634 ms per beslissing incl. de L2-
tegenstander. `-- uispel 777` blijft `90650e1e` (het haakje in L2 staat
achter `beslis_log != null`).

**Datarun:** `results/l4_log_20260922/` (12 procs, 36 paren x 2, L2 vs L2,
elke 4e beslissing): 864 partijen, 68.508 beslissingen, 3,58 miljoen
kandidaat-rijen, 892 MB. Trainen duurt 4 min (numpy).

**Metingen (winst van L4 tegen L2, 432 partijen per kleur, +-4,7):**

| netwerk | validatie | rood | blauw |
|---|---|---|---|
| imitatie + uitslag in een getal (48-48) | imit 55,6% | 43,5% | 46,3% |
| alleen imitatie | imit 64,5% | 49,5% | - |
| groot (96-96, imitatie + uitslag) | imit 56,3% | 44,4% | - |
| tweetraps, waardenetwerk BESLIST de topgroep | uitslag 84,2% | 53,9% | 47,0% |
| tweetraps, waardenetwerk WEEGT de loting (temp 0,5) | | 50,0% | 48,1% |

**De twee lessen van de dag.** (1) `-- tiecheck`: bij 48% van L2's
beslissingen delen meerdere zetten de hoogste score (topgroep gemiddeld
4,4, soms 10+) en loot L2. Perfecte kennis van de score haalt dus
maximaal 66% imitatie; het imitatienetwerk zit op 64,5% en speelt 49,5%:
een kopie van L2. De uitslag-term in hetzelfde getal maakt het netwerk
slechter, klein of groot. (2) De Leeuw: L4 als Leeuw zakte in ELKE
variant naar 24-27% waar L2 38% haalt, terwijl het netwerk juist de Leeuw
het best nadoet (71% imitatie, 93% top-3; `-- imitcheck leeuw`: 87-97%
van de zetten in L2's topgroep). Oorzaak: "altijd de eerste" bij bijna
gelijke scores is systematisch (zelfde pion, zelfde vak) waar L2 spreidt,
en de Leeuw loot het meest (zijn override-gewichten `ai_weights_f2.json`:
haven 0,05, material 3,97, dus bijna alles rondt naar dezelfde int).
Met loting binnen de topgroep (`tie_eps` 0,3) staat L4 als Leeuw weer op
38% (128 partijen, loopt door tot 432). Daarom weegt het waardenetwerk nu
de loting (`waarde_temp` 0,5) in plaats van hem te beslissen. **Let op
voor de balans:** de live gewichten per factie zijn extreem geschaald
(Beer cav_value 278.630, ranged 97.520; Leeuw haven 0,05). Dat is wat
L2 echt speelt; de tabel in `data/ai_weights.json` zegt daar niets over.

**Hardware-noot:** een andere sessie draait tegelijk 20 arena-procs
(`c23_leeuw3`), dus alles liep op halve snelheid; een partij L4 vs L2
kost 2-3 minuten.

**Slot van de dag (16:45): L4 = L2, geparkeerd.** De gewogen tweetraps
eindigt op 49,1% over 864 partijen (beide kleuren). De Leeuw-loting
bleek bij 428 partijen 25,5% (de 59% en 38% van onderweg waren de snelle
partijen die als eerste binnenkwamen: meet nooit op een lopende run).
Scheidingstest `l4:l2` (L2's eigen evaluate door de L4-route, met
loting): 31,9% als Leeuw over 432 partijen, tegen L2's eigen 38,3%
(360 partijen uit vier runs, +-5,0); zonder loting speelt die route
byte-identiek L2 (test). Verschil van 7 punten met marges van 5: ruis
of een klein effect, geen bug. De Leeuw is gewoon de factie waar een
paar procent imitatiefout het hardst aankomt (hp-gewicht 1130: elk
gemist HP-punt schade is een grote spijt).

Gecommit als de officiele L4: `data/ai_net.json` (score, de L2-kopie) +
`data/ai_net_waarde.json`; label `l4` in de arena werkt daarmee direct.
Meetgereedschap dat blijft: `-- tiecheck`, `-- imitcheck [factie]`,
`l4:l2`, `tools/l4/meet_l4.py`, `tools/l4/selfplay_ronde.ps1`.

**Wat het waard was:** een netwerk dat L2 exact nadoet, in 4 minuten
getraind, met een waardenetwerk dat de uitslag op 84% voorspelt. Wat het
NIET opleverde: winst tegen L2. De uitslag-term in een greedy-score
maakt het spel slechter, en het waardenetwerk als loting-wegger maakt het
niet beter: een 1-ply-bot verandert niet van sterkte door wie hij kiest
tussen zetten die L2 al gelijk vond.

**Als Max hier ooit op door wil:** de winst moet uit selfplay-data komen
(`selfplay_ronde.ps1`, Max start hem zelf, B13: elke ronde ~3 uur op 12
procs) of uit een tweede ply (het netwerk als evaluatie onder L3's
search). Niet uit meer varianten van de keuze. F4.3j is weer de
volgende stap.

## 21 september -- De poort werkt: vijf adopties

Trainingsrun van 20 september (10:00-22:00, zes trainers, 720 min, 4.3.7 met
de nieuwe poort 4a502b8):

| factie | generaties | adopties |
|---|---|---|
| Varken | 28 | 1 |
| Muis | 8 | 0 |
| Leeuw | 38 | 1 |
| Beer | 20 | 0 |
| Wolf | 27 | 3 |
| Krokodil | 19 | 0 |

Gewichten `ai_weights_f0/f2/f4.json` vernieuwd (77f5314). `-- simcheck` 0
afwijkingen (de easy-bots gebruiken de L2-gewichten niet, en de enige
medium in de sims is de Beer, ongewijzigd). `-- uispel 777` verschuift wel:
de bot speelt daar de Wolf met de nieuwe gewichten: nu `90650e1e…` (213
acties, cyclus 5; was 3d361f8b, 116, 3). `-- herstelcheck 777` 138 momenten,
0 verschillen.

**Volgende:** nachtmatrix als nulpunt van 4.3.7 met de getrainde bots
(`.rena_nacht.ps1`, Max start), dan de factiezoeker voor wat er scheef
staat. De Muis haalt maar 8 generaties in 12 uur (lange partijen): als de
Muis niets leert is dat eerder een tijdsprobleem dan een plateau.

## 19 september -- De adoptie-poort van de trainer stond dicht

Max, na de nachtrun op 4.3.7 (186 generaties, 0 adopties): "korte diagnose
run."

- **Diagnose** (Leeuw, 25 min in de voorgrond, log
  `results/diagnose_train_leeuw.log`): gen 1 verificatie 4,5/12 tegen
  referentie 4,1 (kampioen 1,4/1,5, baseline 3,1/2,5), gen 2 4,1 tegen 4,1.
  Een kandidaat die +0,4 beter was (tegen de baseline +0,6) werd
  verworpen, want de poort eiste **+2,0**. Die eis stamt uit de tijd dat een
  winst 1 punt was; sinds de campagne-fitness is een potje genormaliseerd
  naar 0-1, dus "+2" betekende: twee verliespartijen die op 12 vaste loten
  in havenwinsten omslaan, zonder er een terug te geven. Daarbovenop
  kromp sigma na acht afwijzingen naar 0,06: kopieen van de kampioen.
  Vier runs sinds 8 september, samen ~300 generaties, 1 adoptie.
- **Fix in `tools/capture.gd`** (constanten boven `_run_training`):
  verificatie per helft `VERIFY_FACTOR` (2) x games = 12 + 12 potjes; eis
  `VERIFY_MARGE` 1,0 op het totaal (een winst netto op 24); per helft
  hooguit `VERIFY_HELFT_MIN` 0,5 achteruit; `SIGMA_VLOER` 0,12 en na
  `SIGMA_RESET_NA` (5) afwijzingen op rij sigma terug naar 0,25.
  `_verify_round` speelt in rondes van `VERIFY_THREADS` (6): 12 threads
  tegelijk gaf allocator-contention (generatie 14,6 -> 28,8 min; met rondes
  20,5 min, waarvan ~6 min de verdubbelde verificatie).
- **Controle** (dezelfde seed, dus dezelfde kandidaat): verificatie 9,1/24
  tegen 8,2 (kampioen 2,9/3,1, baseline 6,2/5,1) -> +0,9, net onder de
  eis van 1,0. De poort staat nu op de juiste schaal; de marge blijft op
  1,0 (niet bijstellen op een meetpunt). Geen scriptfouten.
- Niet in de engine, niet in de regels: uispel, goldens en sims
  ongewijzigd. De diagnose-runs schreven `data/matchup_leeuw.txt` over;
  teruggezet op het nachtrapport.

**Training gestart** (20 september 10:00, Max: "go!!!!"): zes trainers
`train 720 6 6 <factie> 0 arena/arena_configs/rules_v42_campaign.json` op
4.3.7 met de nieuwe poort (4a502b8), geminimaliseerd, standby en hibernate
uit; klaar rond 22:00. Daarna: gewichten apart committen, `-- simcheck` (bij
adopties de sims herijken en de uispel-digest opnieuw meten), nachtmatrix
als nulpunt, dan de factiezoeker.

## 18 september -- 4.3.7: de ruiter krijgt alleen nog +2 attack

Max, na de nachtmatrix en de driedubbele meting: "voeg toe en dan kunnen we
trainen vanavond."

- **Nachtrun 18 september** (Max gestart, 04:42, 60 min, git 89ec74f, 3240
  partijen, fuzz 500 schoon): 4.3.6 voor het eerst als matrix gemeten:
  band 27,1-68,6% (41,5 pp; 4.3.5 op 10 september 39,3-55,6 / 16,3). Beer
  39 -> 69, Muis 51 -> 66, Leeuw 56 -> 27, Wolf 46 -> 34. Mechanisme: de
  +2 stamina maakte elke ruiter een havenrenner; Muis en Beer winnen in
  5,8-6,4 cycli op de haven (89-90%), de honger vanaf cyclus 10 doet niets
  meer (0,2-0,4 hongerdoden per partij, was 1,2-2,5), de slachters
  (Varken, Leeuw, Krokodil, 97-99% eliminatie) krijgen de tijd niet.
- **Drie kandidaten naast elkaar** (`tools/balans/meet_437_varianten.ps1`,
  configs in `arena/arena_configs/varianten/`, 5400 partijen elk, 30
  procs, 09:57-17:39; let op: de variant met alleen een ondergrens draagt
  expliciet `stat_bonus cav {attack 0}`, anders legt `arena/run.gd` de
  campagne-bonus eroverheen):

  | | 4.3.5 | 4.3.6 | +2 atk | +2 atk +1 sta | min 2 atk |
  |---|---|---|---|---|---|
  | Varken | 54,7 | 49,5 | 54,0 | 50,4 | 54,0 |
  | Muis | 51,3 | 65,6 | 49,9 | 62,9 | 52,7 |
  | Leeuw | 55,6 | 27,1 | 47,3 | 35,9 | 57,2 |
  | Beer | 39,3 | 68,6 | 49,1 | 58,6 | 43,1 |
  | Wolf | 46,1 | 34,4 | 45,3 | 40,4 | 44,6 |
  | Krokodil | 53,1 | 54,7 | 54,4 | 51,7 | 48,3 |
  | spreiding | 16,3 | 41,5 | **9,2** | 26,9 | 14,1 |
  | cycli / haven | 9,8 / 39% | 7,8 / 55% | 9,9 / 38% | 8,8 / 48% | 9,8 / 42% |

  Met alleen de attack-plus is de band 9,2 pp, de smalste ooit gemeten;
  al +1 stamina trekt hem open naar 27. De ondergrens-variant van Max
  (min 2 attack) komt uit waar hij verwacht werd: het 4.3.5-beeld met de
  Beer weer laag. **De stamina op de ruiter is de gevoelige knop: elk punt
  kost een factie 10-20 pp.** Gemeten met de bots van voor de regel (0
  adopties op 17 september).
- **4.3.7 vastgezet:** `stat_bonus` -> `{"cav": {"attack": 2}}` in
  `rules_v42_campaign.json`, `v42_default.json`, de zes `duur/rules_pt*.json`
  en `duel_rules_voor`; `rules_config.gd` bumpt naar 4.3.7; engine
  ongewijzigd (de knop bestond). SpawnTests: versie-asserts en een check
  dat geen config nog een stamina-bonus draagt. Goldens opnieuw
  (`-- makegoldens`), `golden_sims.json` geijkt (tabel in de CHANGELOG),
  spelregels-v4.2 C22 en CLAUDE.md bijgewerkt.

**Checks:** testsuite 2495/0; `-- simcheck` 0 afwijkingen; `-- uispel 777`
nu `3d361f8b…` (116 acties, cyclus 3; was a6677ac8, 220, 7); `-- herstelcheck
777` 138 momenten, 0 verschillen; `-- naadcheck` PASS. Core-hash veranderd:
server opnieuw uitrollen en een nieuwe client-build.

**Training gestart** (18 september 19:40, Max: "go! volle bak ultra je mag
er ook 12uur van maken"): zes trainers `train 720 6 6 <factie> 0
arena/arena_configs/rules_v42_campaign.json` op 4.3.7 (a1d5e15),
geminimaliseerd, standby en hibernate op netstroom uit; klaar rond 07:40 op
19 september. Gewichten bij elke adoptie in `data/ai_weights_f*.json`,
rapporten in `data/matchup_*.txt` aan het einde. Daarna: gewichten apart
committen, `-- simcheck` (bij adopties `golden_sims.json` opnieuw ijken en de
uispel-digest opnieuw meten), een nachtrun als nulpunt van 4.3.7 met
getrainde bots, en pas dan de factiezoeker voor wat er dan nog scheef staat.

## 18 september -- Een mengpaneel voor alles; studio overzichtelijker

Max: "alle geluiden qua niveau dezelfde dB als bij de muis-infanterie ooit
ingesteld, 1 mixboard voor alle sounds, tenzij je specifiek instelt per
factie per unit" en "maak het paneel voor de sounds nog beter en
overzichtelijker", plus "al die kreten: loud and very short bursts".

- `Audio.mix_keten`/`mix_bron`/`mix_eigen`/`mix_db`/`mix_niveau`/
  `wis_geluid_tuning`; `volume_correctie` en `extra_vertraging` erven via
  de bron. Gemeten: `inf_die_pig_hp` erft -2 dB van `inf_die_mouse`,
  `inf_kanon_die_pig` +12 dB en -0,04 s van `inf_kanon_die_mouse`,
  `step_pig` -7 van `step`. De muis-categorieen zelf ongewijzigd.
  De ongecommitte `mix_db`/`ERFT_MIX_DB` van de andere sessie is in de
  werkmap vervangen door de generieke versie (let op bij hun commit).
- Studio: derde kolom mengpaneel (niveau, bron, tuner-dB, vertraging,
  eigen instelling / erf weer via `/api/mix_zet` en `/api/mix_wis`, schrijft
  `sounds/sound_tuning.json` met tabs zoals Godot), filters "nog te doen"
  en "eigen mix-instelling", klare rijen ingeklapt tot een regel met
  "toon". Rondje zetten/wissen getest: bestand inhoudelijk gelijk.
- Prompts: alle kreten "one loud, very short burst ... cut off";
  `maak_geluid_prompts.py --kreten`.

## 18 september -- De big bro sterft als de infanterie (kreet per kanon/archetype)

Max: "gebruik ook bij cav de sounds voor de body en gibs, die doodemans-
geluiden, en maak in de studio de die-geluiden aan voor als ze worden
geraakt door een kanon of normaal sterven." Body/gibs/snede/val waren al
type-onafhankelijk; nieuw: `cav_kanon_die` (mix -2 dB) met archetype in
`_death_sound` en `_speel_doodskreet`, `cav_die` met archetype, 66 nieuwe
studio-rijen (6 x kanon + 6 x 5 x 2 archetypen) met prompts. geluidcheck
134 categorieen, niets stil. **uispel 777 geeft nu 3d361f8b (116, 3):
dat is de 4.3.7-regelwijziging (alleen +2 attack voor de ruiter) die de
andere sessie ongecommit in rules_config.gd en de configs heeft staan,
niet dit werk.**

## 18 september -- Dreunende aanloop onder de charge

Max: "voeg ook een stukje trembling footsteps in als iemand een charge
doet, die er apart onder komt." Nieuwe categorie `charge_rumble` (mix
-5 dB), gespeeld in de charge-tak van game.gd naast `charge_yell`, per
factie als `charge_rumble_<factie>` ligt (`play_factie`). Placeholder:
drie synthetische clips van 2,4 s in `sounds/melee/`
(`maak_wapen_geluiden.py`: versnellende stampen met een laag gerommel
dat aanzwelt), prompt in de studio (een clip, geen reeks), rij in
SOUND-WISHLIST 6. geluidcheck: 134 categorieen, niets stil; uispel 777
a6677ac8 gelijk.

## 18 september -- Geluid-studio: natuurlijke prompts en een betere pagina

Max: "improve the UI met loaders en alles" en "verbeter echt alle prompts
voor ElevenLabs, nu komt er alleen maar bagger uit, gebruik echt natuurlijke
termen".

- `tools/maak_geluid_prompts.py`: 227 prompts in gewone beschrijvende
  zinnen (kreten uit een sjabloon per factie x archetype, de rest met de
  hand) met duur en invloed per categorie in `sounds/geluid_studio.json`;
  standaard-invloed 0,6. Max' takes van vanochtend (charge_yell,
  impact_flesh, inf_die_mouse_base, ...) waren allemaal 2 s met het oude
  "6 in a row"-recept; dat recept is een eisenlijst, geen beschrijving.
- Daarna toch weer een reeks (Max: "doe weer multiple, geluid duur dan op
  7 of zo, en dan met die knip op stiltes"): de beschrijving blijft een
  geluid, met erachter "Play it five times in a row, each one slightly
  different, with a clear pause of silence between them", duur 7 s, en de
  studio knipt de clip op de stiltes (het vinkje staat aan zodra de prompt
  "in a row" zegt). Muziek, sfeer en de twee stings blijven een clip.
- Studio: lader per rij met de seconden, x3, toasts, per-rij verversen
  (`/api/rij`), sectie-chips met dekking, inklappen, vinkje op een gebruikte
  take (`gebruikt` in de take-json), "alle takes weg", sha1-cache voor de
  overzichtsbouw, junk-rijen uit de wishlist-tabellen (base/spd/hp/atk/mix
  en de oude horse_*-namen) overgeslagen. "Knip op stiltes" alleen aan als
  de prompt "in a row" zegt.

## 18 september -- Geluid-studio (ElevenLabs in een overzicht)

Max: "kunnen we alle prompts voor geluiden niet zo maken dat we met een
ElevenLabs-api-call die krijgen, en als ik op gebruiken druk dat we die
opslaan; prompts aanpassen, retry, de ElevenLabs-instelling aanpassen; een
groot makkelijk overzicht met .wav etc."

- `tools/geluid_studio.py`: lokale webpagina (stdlib http.server, numpy voor
  het knippen), leest dezelfde bronnen als de geluid-tracker (importeert
  `bouw_geluid_tracker`), 237 categorieen in vijf secties. Genereren via
  `POST /v1/sound-generation` met `output_format=pcm_44100` (mp3-terugval
  bij een 4xx op pcm), stilte-knipper (10 ms-rms, drempel 5% van de piek,
  gaten < 150 ms dicht, stukjes < 60 ms weg), takes als 16-bit wav in
  `results/geluid_studio/<cat>/<stempel>_<i>.wav` + json met prompt en
  instellingen. Gebruiken = kopie naar de doelmap als volgende vrije
  variant, of over de eerste synthetische heen. Sleutel buiten de repo.
  Paneel: vijfde knop in "Bekijken" (kader 40 px hoger, alles eronder
  geschoven).
- Getest zonder sleutel (nette melding), met een verkeerde sleutel
  (ElevenLabs 401 komt door), knippen op een synthetische 6-takes-clip
  (6 stukken), gebruiken/vervangen/audio-route (`..` geeft 404).
  Poort 8765 was op deze machine al bezet door drie andere python-
  processen op 0.0.0.0:8765 (Max: "ERR_EMPTY_RESPONSE"): Windows laat
  http.server met SO_REUSEADDR gewoon naast een ander programma binden, en
  dat andere programma krijgt dan de verbindingen. `vrije_poort` probeert
  eerst te verbinden en bindt exclusief, en schuift door naar de eerste
  vrije poort (8766); de browser opent de poort die hij echt kreeg.

## 18 september -- de varken-atk stond scheef: object-actie op het musket, exporter gefixt

Max: "kun je kijken of voor infantry attack pig er een model change iets is,
de orientatie klopt niet."

**Meting.** Nieuwe check `-- richtingcheck [factie]`: per archetype een
PawnView zoals de Model-tuner, in de pose die de speler ziet, voet -> teen
in wereldruimte tegen de voorkant (-Z). Varken: base/spd/hp/mix op -8 tot
-15 graden en heup -> nek recht omhoog; **atk op -114 graden en de romp-as
0,42 OMLAAG**, ook in de rustpose. In de glb droeg de Armature-node
T (-0,03, 0,36, 0,24), een draai van 114 graden en schaal 1, waar base en hp
de Blender-objecttransform dragen (90 graden om X, schaal 0,01). De .blend
(`Character 7.blend`) is goed: zelfde armature-transform als base, zelfde
rustpose.

**Oorzaak.** In de atk-blend staat op het musket-object (`tripo_node_ac43...`)
een eigen actie met location/rotation/scale-keys (Blender 5: een
"Legacy Slot" met 9 object-fcurves; in Godot de extra clip
`tripo_node...Action`, 0,08 s). `blender_export_blend.py` exporteert in
ACTIONS-modus, en daarin probeert de exporter elke object-actie op elk
object, dus ook op de Armature; die hield de wapen-transform als
node-transform over. Base en hp hebben zo'n actie niet.

**Fix.** `blender_export_blend.py` stap 2b: mesh-objecten verliezen hun
animation_data en elke actie zonder `pose.bones`-tracks gaat eruit (via de
gelaagde acties van Blender 5: layers > strips > channelbags; terugval op
`act.fcurves`). De varken-atk is opnieuw gebouwd met de drie stappen van
`bouw_modellen.stappen` (musket, karakter, gibs+fix): Armature-node weer
90 graden / 0,01, 17 acties, geen tripo-clip; richtingcheck varken 5/5
PASS (atk -10 graden, omhoog 1,00); zweefcheck varken PASS; met venster
`_shot_richting.png` bekeken: vijf varkens op een rij, allemaal dezelfde
kant op. Bijvangst: de 18 base-varkens dragen hun musket op 0,29 van de
hand (drempel 0,25 in de zweefcheck-lijst), consequent voor alle 18, dus
een eigenschap van het geleverde base-model, niet van deze fix. De
varken-levering zelf (assets/models/pig/) is nog ongecommit werk van de
andere sessie; de herbouwde atk-glb's staan ernaast in de werkmap.

## 17 september -- de capes zijn eruit

Max: "verwijder de capes, alles eromheen, alles." Weg: de cape-code in
pawn_view.gd (shader-lap, cloth op Jolt, lijf-meting, romp-segmenten,
rugplaat, kraagpunten, vlaag, cape_weg), de bewoner-cape, de knoppen in het
sfeer-paneel (alle `cape_*`), de windvlaag van een schot en de
physics-stop in de hitstop, de checks `-- capecheck`, `-- capeschot` en
`-- capebench`, de tab Cape in de Model-tuner met `-- capetuner` (was nog
niet gecommit), de cloth-tak in zweefcheck, `cape_blue.png` met zijn
import, PROP-WISHLIST sectie 14 (de textuur-prompts; de prop-tracker houdt
zijn png-rijen-logica, die is generiek) en de cape-sectie in
props/LEESMIJ.md. Gebleven: het `dim`-uniform en de doorzicht-variant van
de eigen shaders, want het vlaggendoek en de snede gebruiken die. De
secties hieronder over de cape zijn geschiedenis. Checks na het weghalen:
tunercheck, zweefcheck muis 2, omgevingcheck 1, bewonercheck, windcheck,
debrischeck, herstelcheck 777, uispel 777.

## 17 september -- Bloedwolk bij de melee kleiner dan bij het kanon

Max: "maak de bloedwolk bij de melee iets kleiner dan de kanon-bloedwolk."
De snede (`_spawn_blood_mist` in `_spawn_slice`) leende de kanon-mist op
volle sterkte. Nu `_spawn_blood_mist(..., schaal)`: minder flarden,
kleiner, minder ver, minder groei; de snede geeft `blood_mist_melee`
(0,55, Model-tuner tab Bloed) mee en schaalt de druppel-burst mee.
`-- snijcheck` PASS. Opgemerkt: `-- meleecheck` faalt sinds de
cape-mantel-commit (4c0b8b8) op "te vroeg overgestoken": headless duren de
frames 100-200 ms, de check telt zijn 0,05-timers als tijd en de echte
1,5 s-timer van de opruk valt dan op "0,7 s". Niet de geluiden (getest
met de zwaai uit); de frametijd hoort bij de cape-meting.

## 17 september -- de cape als mantel om de rug, het lijf gemeten

Max: "de cape van de blauwen werkt niet goed en is slecht zichtbaar,
kunnen we die beter om de rug heen doen, nu zit het echt in het model."
De lap was een baan achter de rug aan een rechte kraagrij, en vanaf de
speler (van voren-boven) zag je er weinig van. Nu een MANTEL: de kraag is
een boog van 140 graden rond het nekbot, van boven de ene schouder over de
rug naar boven de andere, en de 9 x 10 punten hangen daar als een halve
koker omheen (over de schouders, langs de flanken, 170 graden aan de zoom,
uitlopend). De straal van de boog komt uit het GEMETEN lijf
(`_cape_meet_lijf`): per band langs de as heup-nek hoe ver rug, flanken
en borst van de as liggen. Eerste versie las de vertices via de
node-transform van de mesh: dan staan alle lijfvertices op een punt (de
geskinde mesh hangt onder het skelet met schaal 0,01, maar zijn data
staat in meters; de bind-matrices slikken die factor 100), en de
musket, star aan de hand, vulde de flanken tot de afkapgrens. Nu gaat
elke vertex via de bind-pose van zijn zwaarste bot (skelet x botrust x
inverse-bind x v) en tellen alleen romp-botten (hips, spine, neck,
shoulder). Gemeten muis-infanterist op 0,9: schouders 0,12 halve
breedte, rug 0,03-0,05 diep, borst 0,10, heupband 0,17 (jaspanden). Het
lijf voor de botsing zijn nu drie convexe romp-segmenten en een
been-segment uit die doorsneden (`_cape_romp`, elliptische hull) plus de
bovenarmen; een ronde capsule zo breed als de schouders duwde de rug-stof
te ver naar achteren. Van achteren hangt de mantel om de rug, ook bij de
bewoner; van voren-boven zie je de flanken met goudrand naast het lijf.
Checks: capecheck (beide plaatjes), zweefcheck muis 2, omgevingcheck 1,
capeschot, herstelcheck 777. Let op: de mantel-code van vanochtend zat al
in HEAD via het emblemen-commit a627191 van de andere sessie (die nam
pawn_view.gd in zijn geheel mee); dit commit draagt de meting-fix.

## 17 september -- Zwaai en klap per wapen

Max: "update de sounds ook voor slashing sounds en zwaard-impactgeluiden per
factie of type wapen."

- `PawnView.melee_wapen(unit_type, arch, doctrine)`: infanterie bajonet;
  ruiter base/mix sabel, spd lans, hp bijl, atk per factie (MODEL-WISHLIST
  3c-2: briquet/pallasch = sabel, broadaxe/enterbijl = bijl, uhlanenlans =
  lans). `Audio.melee_keten` / `effectieve_melee_categorie` / `play_melee`:
  `<cat>_<wapen>_<factie>` → `<cat>_<wapen>` → `<cat>`. `game._melee_geluid`
  op de bajonet- en de charge-klap: `slash_<wapen>` `melee_slash_voor`
  (0,18 s, tuner-knop) voor de klap, dan `melee_kill_<wapen>` /
  `melee_survive_<wapen>`; de materiaal-laag blijft eronder.
- `tools/maak_wapen_geluiden.py`: 12 categorieen x 3 varianten synthetisch
  in `sounds/melee/` (whoosh met glijdende band per wapen, natte hak met
  botkraak, staalklank, schraap), manifest `synthetisch.json`. Mix-dB in
  `CATEGORY_DB`. Geluid-tracker: sectie "Wapens" met prompts, alle
  manifesten onder `sounds/` tellen als synthetisch. SOUND-WISHLIST 6b.
- Checks: `-- wapengeluidcheck` PASS (60 combinaties, vier wapens),
  `-- meleecheck` PASS, `-- geluidcheck` (130 categorieen, niets stil,
  niets ongebruikt), `-- uispel 777` a6677ac8 (220, 7) ongewijzigd.

## 17 september -- Bots trainen op 4.3.6 (ruiter +2/+2)

Max: "staan de nieuwe regels nu ook in de trainer? dat kaarten toevoegen" en
"de bots moeten hierop getraind worden."

- De regel zelf zat er al in: de trainer speelt op `rules_v42_campaign.json`
  (draagt `stat_bonus` sinds 3550b3e) en de reducer telt het bij elke
  koppeling op. Wat er niet in zat: de gewichten (`data/ai_weights_f*.json`,
  geleerd onder 4.3.5) en de schatting van een GEDEKTE pion in
  `Agent.reconstruct_state`: die middelde de zichtbare kaarten en telde er
  niets bij op, dus een verborgen Krokodil-ruiter stond 2 HP (C12
  `basis_hp`, al sinds juli) en nu ook 2 stamina en 2 attack te laag.
  Gerepareerd (`f3686cd`): de schatting leest `basis_hp` en `stat_bonus`
  per type uit de regels mee. Testsuite 2490/0, `-- simcheck` 0
  afwijkingen (ook mens-vos seed 101).
- Training gestart (17 september, door Claude op Max' verzoek, geen
  automatische job): zes trainers, `train 240 6 6 <factie> 0
  arena/arena_configs/rules_v42_campaign.json`, geminimaliseerde vensters
  zoals `train_ai.bat`, standby op netstroom uit. Gewichten verversen bij
  elke adoptie, rapporten in `data/matchup_*.txt` aan het einde van het
  budget. Daarna: gewichten apart committen ("Trainingsdata: ..."),
  `golden_sims.json` opnieuw ijken als de bots veranderd zijn, en de
  `-- uispel`-digest opnieuw meten.

## 17 september -- Vlees en bloedspatten op alle gibs

Max: "kun je dat rode bloederige bij alle gibs doen, ook bij melee of musket
(of kanon wel goed)" en "de kleur heb ik het over". De vlees-binnenkant van
de snede (16 september) zat alleen op de doorgesneden romp; de andere
brokstukken droegen de schone teamjas, want een `_gore.png` bestaat voor de
muis niet. Nu draagt ELK brokstuk het vlees-materiaal (`_zet_vlees`,
`_zet_vlees_alle`): de kanon-explosie, het afgerukte ledemaat van musket en
bajonet, de ongesneden delen van de snede, en wat er van het lijf overblijft
als er een ledemaat af is (`_shed_one`). De gibs zijn niet dichtgemaakt
(gemeten: romp 542 open randen, elke arm en elk been tientallen), dus door
elk open uiteinde en door het gat in de schouder kijk je op rood vlees met
korrel. Daarbovenop bloedspatten op de buitenkant: gladde ruis op twee maten
(blobs, geen blokjes), drempel via knop `gib_bloed` (0,45; tab Gore), het
bloed glimt (ruwheid 0,45). `kant` 0 in de shader = niet snijden.

Twee lessen. (1) `get_shader_parameter` geeft null voor een uniform die
nooit expliciet gezet is: de check zag "0 van 12 met vlees" en, erger,
`verduister_later` had de gibs nooit donker gemaakt omdat hij op `dim`
kijkt; `_zet_vlees` zet `vlees` en `dim` nu expliciet. (2) Ruis op de
VERTEX-positie werd op het geskinde lijf stof: een geskinde mesh rekent zijn
VERTEX in een andere ruimte dan zijn AABB (instantie en mesh meten allebei
0,66 hoog, de ruis liep toch honderd keer te fijn). De ruis loopt nu over de
UV, die is op elk deel 0..1, dus gib en lijf zijn even grof.

Checks: `-- stompcheck` (nieuw, ModelTuner.tscn: musketdood met gedwongen
ledemaat: 12 -> 9 zichtbare lijf-delen, alle 9 met vlees, 2 weggeslingerde
gib-delen met vlees, PASS; met venster `_shot_stomp.png`), `-- snijcheck`
PASS (elk van de 12 delen draagt vlees, 2 snijvlakken), `-- debrischeck`
PASS, `-- gibshot` (kanon, met venster: rode blobs op hoed en delen, rood
door de open uiteinden), `-- uispel 777` gelijk.

## 16 september -- Doormidden: de sabelhouw snijdt het poppetje in tweeën

Max: "en een gibs wolkje en doormidden gesliced het poppetje kan dat?
bloederig net als bij kanon inslag" (bij de charge). Kon. De charge-kill
kreeg tot nu toe de volledige gib-explosie van het kanon (0,85 + 0,4 = 1,25
zit boven de 1,2-drempel), dus alle delen vlogen los; nu snijdt de sabel.

**Hoe.** `PawnView._spawn_slice` (in `play_death`, vóór de kanon-route,
kind `"charge"` uit game.gd en met kleinere kans ook de bajonet). De
gibs-delen worden langs een vlak verdeeld dat door de romp gaat op
`slice_hoogte` (0,55 van de pionhoogte), gekanteld om de slagrichting
(`slice_hoek` 35 graden; van schouder naar de andere heup). Een echte snede
zonder mesh-werk: de romp wordt verdubbeld en elke kopie krijgt
`SNIJ_SHADER`, die met `discard` alleen haar eigen kant van het vlak tekent
(in mesh-ruimte: n' = Bᵀn, d' = n·o + d) en de achtervlakken als vlees
kleurt, zodat je in de snede de binnenkant ziet. Armen, benen, kop en hoed
worden niet gesneden: die gaan heel mee met de kant waar ze aanzitten (het
hoogste punt van het deel; een onderarm volgt zijn bovenarm, een onderbeen
zijn bovenbeen). De eerste versie sneed ook armen door en liet een halve arm
bij de benen liggen; de tweede stuurde een hangende onderarm op zijn midden
naar de benen. Vandaar de aanhecht-regel.

Twee groepen: `Body_boven` (romp-top, kop, armen) scharniert op de snede en
gaat als een stuk met de klap mee de lucht in, een salto om de dwars-as
(`slice_tuimel`), landt met het hoofd van de aanvaller af, grote poel.
`Benen_onder` (romp-onder, bekken, benen) scharniert op de voeten, staat
nog `slice_sta` (0,35 s), wankelt en kiept dan om met de klap mee (± 40
graden), met een stuiter; hangen de voeten in de lucht (de ruiter: de gibs
zijn alleen de ruiter) dan zakt hij mee naar het bord. Hoed en een onderarm
vliegen los (`slice_los` 2), plus de kanon-bloedmist, druppels en twee
spuiten op de snede: het gibs-wolkje. De shader draagt dezelfde haakjes als
de cape (`render_mode cull_disabled;`, `uniform float dim`, `ALBEDO = doek *
dim;`), dus `verduister_later` bouwt er zonder wijziging de doorzicht-
variant van: de helften worden donker, doorzichtig en zakken.

Knoppen in de Model-tuner (tab Gore): `slice_kans_sabel` 0,85,
`slice_kans_bajonet` 0,35, `slice_hoogte`, `slice_hoek`,
`slice_hoek_bajonet` 10, `slice_sta`, `slice_los`, `slice_kracht`,
`slice_tuimel`. Testknop "doormidden (sabel)" naast de gibs-knoppen; de
knop "charge (dood)" gebruikt nu ook kind `"charge"`. `-- gibshot sabel`.
Les uit het bouwen: een meerregelige lambda als eerste argument van
`tween_method` parst niet als er argumenten na de body komen; een gebonden
methode (`_draai_helft.bind(...)`) wel.

**Checks:** `-- snijcheck` (ModelTuner.tscn): 12 delen, boven 5, onder 5,
los 2, snijvlakken 2, bovenste helft 1,0 vak weg, onderste 88 graden
gekiept, 55 debris-nodes bij, PASS; met venster `_shot_snij.png` (halverwege
de vlucht: romp met kop tuimelt boven de nog staande benen, hoed en onderarm
los, bloedmist) en `_shot_snij_laat.png`. `-- uispel 777` zobrist
`a6677ac8…` (220 acties, cyclus 7, gelijk); `-- debrischeck` PASS;
`-- capecheck` PASS; `-- tunercheck` PASS. `-- meleecheck` faalt op de
charge-landing ("1,00 vak van het tussenvak"): dat is de root-motion-
compensatie van de charge waar de andere sessie op dit moment aan werkt
(ongecommit in game.gd, pawn_view.gd, capture.gd), niet de snede; het doel
sterft en verdwijnt wel. Alleen de eigen blokken zijn gecommit (eigen
index), de charge-wijzigingen van die sessie staan nog in de werkmap.

## 16 september -- de kaarten als een hand: waaier, klik-lift, slepen naar een pion

Max: "plaats de kaarten die je definieert meer in een waaier alsof je die in
je hand hebt"; "als je op een klikt dan schuift hij naar boven en kan je
makkelijker de knoppen indrukken"; "een drag-en-drop-link die highlight op
welk poppetje je hem dropt, zeker op mobiel met swipen moet het goed
zichtbaar zijn welke je koppelt, met een soort gebogen arc van een pijl";
"ook als ik de kaarten heb gedefinieerd moeten ze mooi als waaier staan".

**Waaier (`CardHand._layout_waaier`, beide fasen).** Draai 5,5 graden per
kaart vanaf het midden, een boog alsof de kaarten om een spil onder het
scherm draaien (straal uit tussenruimte en draaistap, dus een hand van vijf
buigt meer dan drie), overlap 0,72 van de breedte met rechts bovenop. De
maat volgt uit de schermbreedte met de draai erin (een gedraaide kaart
steekt verder uit dan zijn breedte; de eerste versie liet de linker
muizenkaart van het scherm vallen): drie kaarten op 1,0 (zoals voorheen),
vijf op 0,78 (was 0,63 plat naast elkaar). Definieren op 0,78 van de hoogte
met de bevestigknop eronder, uitdelen van onderaf op de klap van
`card_deal`; koppelen kleiner (0,84) en lager (0,86), geen knoppen nodig.
Twee kleine valkuilen: `get_meta(naam, null)` geeft in 4.7 alsnog de fout
"does not have any meta values" (eerst `has_meta`), en een kaart die
1,1 mocht worden bedekte de achterste rij van het bord.

**Naar voren en omhoog.** De kaart onder muis of vinger komt 34 px naar
voren (hover); een klik in de definieerfase schuift hem 0,22 van zijn hoogte
omhoog (109 px) en 8% groter en laat hem staan tot je een andere kiest, met
de plus-knoppen vrij; de gekozen kaart in de koppel-fase staat 0,14 omhoog.
De klik telt bij het LOSLATEN, zodat een plus-knop zijn klik nog krijgt
voordat de kaart onder de muis vandaan schuift. Volgorde via `move_child`
en niet z_index: de GUI kiest op boomvolgorde wie de klik krijgt, en een
kaartwortel vangt zijn hele vlak, dus wat je ziet is wat je raakt; een
halfbedekte plus-knop vuurt niet per ongeluk.

**Slepen (`KoppelPijl`, `scripts/ui/koppel_pijl.gd`).** In de koppel-fase
begint een druk op een vrije kaart een sleep zodra je 18 px beweegt; de
sleep kiest de kaart langs dezelfde weg als een tik (`card_picked`), tilt
hem op en meldt elke beweging (`drag_moved`). game.gd tekent een gebogen
pijl (kwadratische bezier met de buik omhoog) van de bovenkant van de kaart
naar de vinger, met streepjes die naar de punt lopen en een zachte gloed
eronder; boven een eigen vrije pion klikt de kop op de pion vast, wordt de
pijl goud met een pulserende ring en licht de pion op via dezelfde hover
als een muisbeweging. Loslaten boven de pion: een spookkaart vliegt langs
de boog naar de pion, krimpt en vervaagt, en de koppeling gaat langs
`_on_link_pawn_clicked` (dus dezelfde checks en meldingen als tik-tik,
ook in de beurt van de ander: dan blijft de kaart klaarstaan). Loslaten
naast een pion: de kaart blijft gekozen. Op Android komen vingers als
muis-events binnen (emulate_mouse_from_touch), dus swipen is hetzelfde
pad. De GUI houdt tijdens de sleep de muis-focus op de kaart, dus
`_unhandled_input` ziet die beweging niet; de hover komt uit
`_on_koppel_sleep`.

**Checks.** `-- define klik` (met venster): klik op kaart 0 bovenop, 109 px
omhoog, schaal 1,08, PASS; `-- define focus`: hover 34 px, PASS;
`-- define muis`: vijf kaarten binnen het scherm (-18 tot 703 px midden,
draai -11 tot 11). `-- sleepcheck` en `-- sleepcheck muis` (met venster;
headless bereiken muis-events de GUI niet): pijl raak boven pion 19,
gekoppeld na het loslaten, boven vak (5,5) geen raak en geen koppeling,
kaart blijft gekozen; PASS. Een eerste versie van de check rekende het lege
vak zonder `_board.to_global` en landde op een pion. `-- koppelcheck` PASS,
`-- uispel 777` a6677ac8 (220 acties, cyclus 7, ongewijzigd),
`-- herstelcheck 777` 142 momenten, 0 verschillen. Screenshots bekeken:
drie varkenskaarten, vijf muizenkaarten, de sleep met de gouden boog.

**Later die avond, Max: "laat de kaart verdwijnen na slepen, niet zo omhoog
animeren, of dus het pad van de arrow volgen."** De spookkaart vloog vanuit
zijn midden langs een eigen, hogere boog (andere begin- en eindpunten dan
de pijl). Nu hangt hij met zijn bovenkant, het beginpunt van de pijl,
precies op de boog van de pijl en volgt die naar de kop, met de neus langs
de raaklijn en snel krimpend (sqrt-verloop); de pijl wordt ingehaald (zijn
begin schuift met de kaart mee) en verdwijnt aan het eind; de echte kaart
is uit de hand zolang de vlucht duurt (0,34 s) en komt daarna gedimd
terug. Valkuil onderweg: `Control.global_position = ...` zet in 4.7 de
oorsprong van de transform, en die verschuift bij een draai om een spil;
het anker stond daardoor 230 px naast de boog. Via `position` (de UI-laag
verschuift niet) zit hij er op 0,4 px op. De sleepcheck meet het:
halverwege de vlucht anker op de boog, pijl begint bij het anker, kaart
uit de hand; erna spookkaart opgeruimd en kaart terug (`_shot_sleepvlucht.png`).

**En: "geef de icon een beetje meer ruimte van de stats, het cijfer-ding
mag wat langer en ietsje smaller, want nu vallen de hokjes er net
buiten."** De drie stat-kolommen (169 x 310 op 1,14 sinds vanmiddag) liepen
van 21 tot 623 op een kaart waarvan de lijst tot 47 en vanaf 599 loopt. De
kolom is nu een 9-patch-paneel van `Card_specs_holder.png` (randen 16 px,
`UiAssets.paneel_stijl("specs")`) op eigen maat `KOLOM_MAAT` 170 x 392,
dus smaller en langer zonder dat de getekende lijst vervormt: drie
kolommen van 56 tot 590, het icoon (74) op y 64 en het cijfer (104) vanaf
158, met de sierlijn ertussen; de plus op 284. `KAART_KOLOM_SCHAAL` is
weg. `-- define` meet de kolommen tegen het kader (PASS), klik-lift 109 px.

## 17 september -- het CP-zegel: duidelijk als het er is, bijna weg als het er niet is

Max: "maak de CP-stamp duidelijker, en als het er niet is nog lichter grijs,
bijna de kleur van de kaart, om verwarring te voorkomen."

Elke kaart droeg hetzelfde half doorzichtige grijze zegel onderaan, en een
kaart met inzet hetzelfde zegel in teamkleur met een kleine "CP": op
bord-afstand zag je twee grijze rondjes. Nu: leeg is de grijze plaat op
alpha 0,25 (van een plaat die zelf al op 0,53 staat), dus een vage afdruk
in het perkament; met inzet ligt het teamzegel twee keer over elkaar
(`CpZegel2`, dekkend), iets groter (0,47) en met "CP" op 44 met een
donkere rand. Het midden staat op 858 (was 871), anders raakte de grote
versie de onderlijst van het frame op 941. Geen nieuwe assets. Check:
`-- define cp` zet een CP-punt in; kaart 1 draagt het zegel (dubbel, 149
breed, alpha 1), kaart 2 en 3 de afdruk (137 breed, alpha 0,25), PASS;
screenshot bekeken. Koppelcheck en uicheck PASS.

## 17 september -- lichtstraal op de laatste pionnen die nog kunnen

Max: "voeg een highlight toe als het de laatste of bijna laatste pawns zijn,
dat je ziet welke je nog kan bewegen: een soort lichtstraal of een
highlight om het model heen."

Wie niet meer kan werd al gedimd, maar een donker poppetje op een donker
bord valt niet op. Nu andersom: in je eigen actiebeurt telt `_refresh_all`
je pionnen die nog kunnen (`Rules.can_pawn_act`, een keer per pion, ook
voor het dimmen); zijn dat er hooguit `beurt_licht_vanaf` (3), dan krijgen
die een lichtkegel van boven (CylinderMesh zonder kappen, eigen shader:
additief, onderaan fel en naar boven weg, de zijkanten zacht via de hoek
met de camera) en een lichtvlek op de vloer, warm goud en zacht pulserend
(tween, geen RNG). Knoppen `beurt_licht` en `beurt_licht_vanaf` in het
sfeer-paneel, live. `render_digest` telt het mee.

**Check `-- beurtlicht`.** Speelt tot de eigen actiebeurt (negen pionnen
kunnen, geen straal), zet door (de bot speelt zijn beurten zelf) tot er
drie over zijn: drie stralen, nul fout; drempel 1: nul stralen bij drie;
doorspelen tot de laatste: een straal; sterkte 0: geen. PASS, headless en
met venster (`_shot_beurtlicht.png` bekeken: drie warme kegels op de
pionnen met stamina over, de rest donker). uispel 777 a6677ac8
ongewijzigd, herstelcheck 777 en resumecheck 777 1 nul verschillen.

## 17 september -- de min-knop terug, en de stat heet stamina

Max: "voeg ook het minnetje weer terug, plaats die onder het plusje met wat
afstand en kleiner. En het is belangrijk: de term is stamina, niet speed.
Dat moet overal ook goed worden meegenomen."

**Min-knop.** `KnopMin` (56 px) onder de plus (88 px) met 8 px ertussen; de
kolom is 408 hoog (was 392) en alles erin schuift iets op (icoon 70 op 54,
lijn 130, cijfer 96 vanaf 142, plus 248, min 344); de CP-zegel past er nog
onder (778). De min-functies bestonden nog (het punt gaat naar de
kleinste andere stat); `_buttons` kent nu zes knoppen, dus ze verdwijnen
samen met de plus zodra de kaart niet meer bewerkbaar is. Het besluit van
3 september ("alleen plus") is hiermee teruggedraaid.

**Stamina.** Alle teksten die de speler ziet: `i18n/strings.csv` en de
fragmenten (STAMINA, CARD_STAT_SPEED = "STAMINA", DOCTRINE_1_PRO,
DOCTRINE_3_CON, HUD_DEFINE_LEGEND, PHASE_REVEAL_BODY/LINE, REVEAL_UI_BOD,
vier HELP-teksten), de pro/con-regels in `constants.gd`, en de docs die
het spel beschrijven (spelregels-v4.2.md, README, CLAUDE.md, UI-SPEC,
CARD-DESIGN-BRIEF, MASTERBOUWPLAN). De vertalingen opnieuw gebouwd
(`--import`, beide `.translation` mee). Code-sleutels blijven (`speed_max`,
`cav_speed_bonus`, `speed_bonus`, `stat-speed`, `speed.png`): die zitten in
regels-bestanden en saves. CHANGELOG en spelregels-v4.1.md zijn historie.

**Checks.** `-- define klik cp`: kolommen 56..590 binnen het kader, klik-lift
109 px, min-knop klik hp 3 -> 2 -> 3 (8 px onder de plus, 56 breed), CP-zegel
PASS; `-- carddist` ongewijzigd; `-- uicheck` PASS; UiAssetsTests groen.
Screenshot bekeken: STAMINA op de kaart, min klein onder de plus.

**Even later, Max: "doe het plusje weer boven het getal en het minnetje
eronder, zelfde grootte knoppen; font hp/stamina/attack mag kleiner."**
Kolom 170 x 420: naamplaat op 6 (font 30 -> 24), icoon 64 op 54, sierlijn
124, plus 72 op 144, cijfer 88 vanaf 218, min 72 op 340; onderkant 772, de
CP-zegel begint op 778. Les: een Label groeit tot zijn regelhoogte (~117 px
bij font 88), ook als je hem 92 hoog zet; de eerste versie zette de min
daardoor over het cijferblok heen (de check meet nu de volgorde
plus/cijfer/min). `-- define klik cp` PASS, uicheck PASS.

## 16 september -- Spits bloedstraaltje bij een overleefde klap, met het model mee

Max: "bij een hit ook een klein spits bloedstraaltje met de beweging mee van
het model."

- `PawnView._bloedstraaltje` (aangeroepen uit `_do_wound`, dus bij elke
  overleefde klap of schot op infanterie/cavalerie): een dunne kegel
  (CylinderMesh met top 0) aan een `BoneAttachment3D` op het rompbot, zodat
  hij de incasseer-clip (hit1/hit2) en de stagger volgt in plaats van in de
  lucht te blijven hangen waar de romp WAS.
- Rompbot via `_wond_op_romp`: `WOND_BOTTEN` Spine1 > Spine2 > Spine > Hips,
  gezocht op naamdeel (de muis-export heeft `mixamorig_Spine1` met een
  underscore, andere exports `mixamorig:Spine1`; `find_bone` op de volle
  naam vond niets, dat was de eerste FAIL van `-- wondshot`). Het wondpunt
  ligt 0,07 buiten het bot, met de klap mee; de druppels van
  `_spawn_blood_spurt` vertrekken nu uit datzelfde punt (was een vast punt
  0,55 boven de tegel).
- Ketting `Bloedstraal` > `Richting` > `Maat` > `Straal`: richting en maat op
  aparte nodes, want twee tweens op een basis (draai en schaal) overschrijven
  elkaar; de kegel staat een halve hoogte boven `Maat` zodat de schaal vanaf
  de voet werkt (`CylinderMesh` heeft geen `center_offset`, dat gaf de tweede
  FAIL). Verloop: uitschieten in `wound_straal_op` (0,07 s) tot
  `wound_straal` (0,22), dan in `wound_straal_duur` (0,3 s) doorzakken
  (richting van +0,35 omhoog naar 0,45 omlaag), dunner worden en vervagen
  (alpha vanaf de helft), daarna `queue_free` van de attachment. Dikte
  `wound_straal_dikte` (0,022; niet aan `drop_size` gehangen, die staat in
  `effects_tuning.json` op 0,4 en maakte hem onzichtbaar dun).
- Geen globale RNG, geen spelstaat.

**Checks:** `-- wondshot` (ModelTuner.tscn) PASS: "straaltje aan bot
mixamorig_Spine1: voet y=0,54, punt op 0,22 eenheden, schaal y=0,99", ruimt
zich op; met venster `_shot_wond.png` (klap van opzij, straaltje rechts uit
de romp, druppels erboven); `-- uispel 777` zobrist `a6677ac8…` (220 acties,
cyclus 7): dat is de referentie van 4.3.6 (andere sessie, dezelfde middag,
ruiter +2/+2), dus met het straaltje erin ongewijzigd.

Ongelukje bij het committen: de andere sessie had intussen haar hele
`pawn_view.gd` (cape-sim-hunks, werk in uitvoering) in de index gezet, en
die zijn met de bloedstraaltje-hunks meegegaan in de emblemen-commit
`a627191`. Niets kwijt, alleen een commit-bericht dat niet alles noemt.

## 16 september -- charge: het model bleef 1,3 vak over het doel heen vliegen; nu landt hij erop

Max: "de sprong van de cav attack moet echt eerder starten want het
poppetje vliegt gemiddeld 2 velden eroverheen, of doe geen walk en alleen
die aanloop met sprong op de target". Nieuwe meting `-- chargemeet`: de
sprong-clip van de muis-cavalerie draagt root motion in de heupen, 1,3 vak
vooruit (piek op 0,7 s bij tempo 2,3) en daarna glijdt hij terug naar 0;
dat kwam bovenop de rit-tween die al op het doelvak stond, dus het model
schoot door het slachtoffer heen en kwam terug. Fix in twee delen: (1)
`PawnView._charge_compensatie_start/_frame/_stop` schuift het stuk per
frame precies tegen de heup-verplaatsing in (op `mixer_applied`, alleen
x/z), gemeten: hooguit 0,06 vak van de node; (2) `charge_tijdlijn` laat
de rit-tween eindigen op de landing (`t_land` uit `charge_profiel`, per
model gecached uit de heup-track: hoogste punt, dan weer op de grond),
`game._animate_move` kreeg `dur_override`; sprong_start = rij_dur - t_land,
een korte rit wordt zo lang als de sprong (bij tempo 2,3: 0,72 s), en de
klap valt `charge_klap_na_landing` 0,12 s na de landing. `play_charge`
speelt altijd de eerste variant. Meleecheck-charge herschreven op de
nieuwe tijdlijn (en de check-ruiter heeft nu attack 3 en 4 HP: hij sloeg
met 0 en stierf, de check zag dat nooit). Checks: chargemeet PASS,
meleecheck PASS, tunercheck PASS, uispel 777 a6677ac8, herstelcheck 777 0
verschillen.

## 16 september -- charge: de sprong begint twee vakken voor de aankomst, de klap valt tegen het einde

Max: "start de jump attack animatie 2 blokjes eerder afstand, dan komt ie
mooi uit. en dan pas ook de bloed walk en alles afspelen op bijna het einde
van die jump attack". Tot nu toe begon de sprong-clip ("Standing Melee Run
Jump Attack", 3,71 s, op tempo 1,2 dus 3,09 s) pas na de rit en viel de klap
0,35 s later: 0,33 s in een clip van drie seconden, midden in de aanloop.

- `game.gd` "charge": `sprong_start = rij_dur - charge_aanloop_vakken *
  (rij_dur / rij_dist)`, geklemd op 0 (bij een rit van een of twee vakken
  begint de sprong dus meteen); de rit-tween zet daarna GEEN idle meer
  (`_animate_move(..., idle_na = false)`), anders kapte hij de sprong af.
  De klap: `klap_del = sprong_start + sprong_duur - charge_raak_voor_einde`
  (0,5 s, minimaal 0,1 s na de start). Geluid, impact-laag, bloed, ragdoll
  en terugslag hangen daar allemaal aan, net als eerst.
- `PawnView.charge_duur()`: de duur van de sprong-clip die play_charge()
  straks speelt (kortste variant, gedeeld door charge_speed); -1 zonder
  sprong-clip, en dan geldt de oude weg (melee-stoot bij aankomst,
  charge_hit_delay 0,35). Alleen de muis-cavalerie heeft een sprong-clip.
- "charge" staat nu in de oneshot-lijst van `_on_anim_finished`: daarvoor
  bleef de ruiter na de sprong op het laatste frame hangen zodra niemand
  play_idle riep.
- Model-tuner, Melee-tab: `charge_speed` (sprong-tempo), `charge_aanloop_vakken`
  (2, stap 0,5) en `charge_raak_voor_einde` (0,5 s). Per model ook als
  korte sleutel in `model_tuning.json` onder "melee".
- `-- meleecheck` charge-scenario rijdt nu drie vakken (5,8 -> 5,5; bij een
  vak zou de sprong meteen beginnen en de rush-clip nooit te zien zijn) en
  eist bij een echte sprong-clip dat hij na 1,2 s nog loopt en het doel nog
  staat (`_pawn_views` heeft hem nog: `_kill_view` haalt hem pas bij de
  klap weg). Uitslag: `rush1, charge1 (sprong-clip 3.09 s; na 1,2 s: sprong
  loopt nog=true, doel staat nog=true)`, PASS.
- `-- uispel 777`: d16a14f8, 246 acties, cyclus 6 (puur visueel).

**Vervolg dezelfde middag (Max: "laat dan wel in de tuner een enemy zien en
dan de aanval op gepaste afstand starten", "en een knop", "sowieso alle
knoppen beter in beeld", "voeg gewoon een bord toe met alle pionnen net als
in het spel zelf... ik moet in het spel op het bord zien en tunen net als
normaal in het spel"):**

- `PawnView.charge_tijdlijn(rij_dist)` geeft rit, sprong-start, sprong-duur
  en klap; game.gd en de tuner lezen dezelfde tijdlijn.
- Test-rij: `charge (dood)` / `charge (overleeft)`: vijand recht voor het
  model, rit van drie vakken (`CHARGE_RIT`) op de rush-clip met dezelfde
  sine-tween als `_animate_move`, sprong en klap op de tijdlijn. Het
  info-regeltje meldt: "rit 3 vakken in 0.39 s, sprong start op 0.13 s
  (3.09 s), klap op 2.72 s".
- `bord + legers` (bovenbalk): Board.tscn met beide legers in de
  standaard-opstelling van het spel: `v42_default.json` + het
  doctrines-blok, `GameState.default_placement` per speler, rood (Vergelijk
  links = speler 1) op de rijen 9-10 kijkend naar -z, blauw op 0-1; de
  eerste infanterist draagt het vaandel, de tweede de trom. Cam-keuze
  `bord` = de camera uit Board.tscn zelf (WYSIWYG), wordt automatisch
  gekozen. De sliders tunen het model uit de dropdowns (archetype base);
  `duel`/`charge` spelen op het bord op de pion van die factie
  (`_test_aanvaller`), met een verse vijand ervoor (`_test_verdediger`,
  altijd de andere teamkleur). Formatie / alle modellen / bord + legers
  sluiten elkaar uit; `_retune_target` herbouwt via `_herbouw_huidige`
  (daarvoor klapte "alle modellen" bij een slider-tik terug naar de
  formatie).
- De eigen 5x3 tegels en het hulpkruis staan onder `_tuner_vloer` en gaan
  uit zodra het bord aan is: ze lagen op dezelfde hoogte als het
  bordoppervlak en flikkerden erdoorheen (witte strepen midden op het
  bord in de eerste shot).
- Bovenbalk, clip-rij en test-rij zijn `HFlowContainer`s: op het staande
  venster (1080 breed) vielen `charge (...)` en `bord` rechts buiten beeld.
- `-- tunercheck` drukt nu ook `bord + legers` (39 pionnen, allemaal op het
  bord, 2 vaandels, bord-camera aan) en `charge (dood)` in (de rode ruiter
  rijdt weg, er staat een verdediger bij): 0 fouten. Shot met venster:
  `ModelTuner.tscn -- shot legers charge` (argumenten `legers` en `charge`
  zijn nieuw) -> `_shot_tuner.png`.

## 16 september -- Lijken en gibs worden doorzichtig en zakken in het bord

Max: "alle stukken lijk en gibs moeten echt ook lichtdoorzichtig worden na
korte tijd om het bord beter te kunnen zien en laat ze iets zakken op de z as
dat ze wel zichtbaar zijn maar wel verborgen in de grond deels ook."

- `PawnView.verduister_later` (de ene plek waar alles wat blijft liggen
  doorheen gaat: lijk, gibs, afgebroken ledematen, weggegooid musket of
  vaandel, cloth-cape) doet na `debris_donker_na` (4 s) in hetzelfde verloop
  (`debris_donker_duur`, 2,5 s) nu drie dingen: donker (was er al),
  doorzichtig (nieuwe knop `debris_doorzicht`, 0,55: alpha 0,45) en wegzakken
  (nieuwe knop `debris_zak`, 0,08 wereld-eenheden op een pion van ~0,9).
- Doorzicht op een BaseMaterial3D: de per-instantie kopie gaat op het moment
  van het verloop op `TRANSPARENCY_ALPHA_DEPTH_PRE_PASS` (eerst de diepte van
  het hele stuk, dan alleen het voorste vlak blenden; zonder die prepass
  schemeren de achterste ledematen door de romp en leest het lijk als een
  rontgenfoto) en `albedo_color.a` tweent mee. Al-transparante materialen
  (bloed, ringen) blijven wat ze zijn.
- Doorzicht op de eigen shaders (vlaggendoek `VLAG_SHADER`, cape
  `CAPE_SHADER`): een shader die `ALPHA` schrijft rendert ALTIJD in de
  transparante pass, dus de bron-shaders blijven onaangeroerd (de levende
  vlaggen en capes blijven dicht en schrijven diepte). `_shader_naar_doorzicht`
  bouwt per bron-shader een keer een alpha-variant uit de code (`uniform float
  doorzicht`, `ALPHA = 1.0 - doorzicht`, `render_mode ..., depth_prepass_alpha`)
  en zet die meteen op het materiaal van het lijk (tween_property wil de
  uniform al zien bestaan; met doorzicht 0 rendert de variant hetzelfde).
  De uniform-waarden blijven bij de wissel staan (ShaderMaterial bewaart ze
  op naam).
- Wegzakken: `position:y` van de wortel, relatief (`as_relative`), want het
  musket is op het moment van aanroepen nog onderweg in zijn worp-boog. Een
  SoftBody3D (cloth-cape) laat zich niet verschuiven: zijn kraag volgt de
  schouderbotten van het lijk, die zakken mee. `game._clear_debris` zakt
  daarna gewoon verder vanaf de nieuwe y.
- Geen globale RNG, geen spelstaat: puur visueel.

**Checks:** `-- debrischeck muis` PASS (albedo 1,00 -> 0,30; alpha 1,00 ->
0,45; transparency 4 = alpha met depth-prepass; y -0,006 -> -0,086; de levende
pion ongewijzigd in kleur, alpha, modus en y); `-- gibshot musket laat`
(ModelTuner.tscn, venster): `_shot_gibs.png` de val, `_shot_gibs_laat.png` het
donkere, doorzichtige, half weggezakte lijk met de bloedpoel erbovenop; `--
uispel 777` zobrist `d16a14f8…` (246 acties, cyclus 6, ongewijzigd).

Losse waarneming (niet aangeraakt): `card_hand.gd:192`
`card.get_meta("hand_tween", null)` gilt in de log "does not have any 'meta'
values with the key 'hand_tween'" (een null-default telt in 4.7 niet als
default); `has_meta` ervoor zou het stil maken.

## 16 september -- Versterkingen eerst zien landen, dan pas het CP-bod

Max: "het moet zijn: kiezen om te spawnen welke soldaten na een ronde. dan
zie je het bord de soldaten spawnen bij beide teams, dan daarna kies je CP
en definieer je de kaarten." De engine doet dat al precies zo (CYCLE_SPAWN,
beide inzetten blind, `spawns_revealed`, dan SETUP_1_DEFINE), maar het
scherm niet: `_on_phase_changed` opende het CP-bod in dezelfde tel als de
fase-wissel, dus het bod-scherm schoof over de poef-reveal van de
versterkingen heen; alleen de kaartwaaier (na het bod) wachtte op het bord
(`_open_define_hand`, sinds 7 september).

- `_open_define_fase`: wacht eerst op `_animaties_bezig` (poef-reveal,
  ontkoppel-golf, nalopende sterfte) en opent dan pas het CP-bod of de
  waaier; de fase-timer start daarna. Intussen zegt de balk
  `HUD_SPAWN_LANDING` ("De versterkingen komen aan..."); schuift de fase
  onder het wachten door (timeout, herstel), dan opent er niets.
- `_open_spawn_fase`: hetzelfde voor het spawn-keuzescherm (de laatste
  sterfte van de ronde eerst laten uitlopen; Max' regel van 7 september).
- `_poef_reveal`: na de laatste poef een kijkpauze (knop `spawn_kijk_pauze`
  in `effects_tuning.json`, 0,8 s) zodat je beide legers ziet staan.
- Beide wachten via `_define_open_bezig`, dus `is_rustig` (herstelcheck,
  resumecheck) wacht mee. Headless wacht niet: de acties en hun volgorde
  veranderen niet.

**Checks:** `-- uispel 777` zobrist `d16a14f8…` (246 acties, cyclus 6, ongewijzigd); `-- herstelcheck 777` 141 momenten, 0 verschillen; `-- herstelcheck 4242 wolf` 155 momenten, 0 verschillen; `-- resumecheck 777 1` 46 momenten, 0 verschillen over alle veertien fasen; `-- naadcheck` PASS; `-- koppelcheck` PASS; `--import` zonder scriptfouten (vertalingen opnieuw gecompileerd).

Tegelijk werkte de andere sessie in game.gd aan de HP-blokjes (6 en 7
kolommen); alleen de eigen hunks zijn gecommit (index-blob), de rest staat
in de werkmap van die sessie.

## 12 september -- een blauwe cape voor het blauwe team

Max: "kunnen we ook alle blauwe team karakters allemaal een blauw cape
geven vanuit godot?" Ja, zonder Blender: `PawnView.maak_cape` hangt een
lap aan het bovenste rugbot (mixamorig:Spine2) met een BoneAttachment3D.
De lap wordt in de RUST-houding van het bot recht naar beneden gezet
(wereld-omhoog en de rug van het model, omgerekend naar bot-ruimte) en
volgt daarna elke animatie; een vertex-shader laat de zoom wapperen
(bovenaan vast, onderaan los), flared hem uit en neemt de wind van het
potje mee (per frame de wereldrichting naar cape-ruimte, afgekapt zodat
hij nooit door de rug naar voren slaat). Blauw is koningsblauw met
goudgalon en een lichte voering (pompeus en rijk); rood kan via de knop
`cape_rood` en krijgt dan dof donkerrood zonder galon (arm). Hij hangt na
elke modelwissel opnieuw (`_apply_team_texture`), niet op artillerie, en
de bewoners van het blauwe kamp dragen dezelfde lap (`Bewoner.zet_cape`,
gezet door `Omgeving._bouw_bewoners` met de kampkleur). Knoppen in het
sfeer-paneel, live op pionnen en bewoners: `cape_blauw`, `cape_rood`,
`cape_lengte`, `cape_breedte`, `cape_wapper`, `cape_wind`. Bijvangst: de
eigen shaders (cape, vlaggendoek) hebben een `dim`-uniform dat
`verduister_later` tweent; tot nu toe bleef een gevallen vaandel fel naast
een donker lijk. Check `-- capecheck` (PASS; met venster
`_shot_capecheck.png` van schuin achter: rood zonder, blauw met, bewoner
met), zweefcheck muis 2 PASS, tunercheck 0 fouten, herstelcheck 777 0
verschillen, omgevingcheck 1 PASS. Puur visueel, geen RNG.

Max' bericht over het kegelspel ("bowlen zijn 10 stuks toch, kleiner, geen
onderveld") kwam in beide sessies binnen; de andere sessie (eigenaar van
`spelletjes.gd`) heeft hem opgepakt, hier niets aan gedaan.

**Drape (Max: "wat meer drape, nu is het erg strak; laat ze aan de
bovenkant richting de nek toelopen, de punten").** De shader vormt de lap
nu zelf: de breedte loopt van een smalle kraag (0,35 van de schouders) in
de eerste 22% van de lengte naar volle breedte en flared naar de zoom;
plooien vanuit de kraag (sinus over de breedte, dieper naar de zoom) en de
zijkanten bovenaan om de schouders gewikkeld; de normaal wordt uit die
verplaatsingen afgeleid, zodat het licht de plooien laat zien in plaats
van een vlak. Knop `cape_drape` schaalt plooi en wikkel. Fijnere mesh
(8 x 14).

**Hangen (13 september, Max: "de cape is wel erg sterk, kan ie niet meer
hangen echt").** De lap stond als een plank: hij kantelde stijf mee met
het rugbot (dat in de rifle-idle voorover leunt) en stak met een vaste
bolling naar achteren. Nu zit alleen de KRAAG aan het bot
(`cape_anker`, het kraagpunt in bot-ruimte) en hangt de lap per frame
aan de zwaartekracht (`PawnView.cape_process`): doelrichting = omlaag,
een beetje van de rug af, tegen de snelheid van de kraag in (sleept bij
lopen en uitvallen) en met de wind mee; een gedempte slinger (veer 60,
demping 7 per seconde) loopt daar achteraan, zodat hij nazwaait; nooit
door de rug naar voren; het doek krijgt zijn wereld-transform en Godot
rekent dat terug naar het bot. Bolling van 0,1 naar 0,04 pionhoogte.
Knop `cape_slinger`. Capecheck meet nu ook dat de lap recht hangt
(lap-omhoog . wereld-omhoog boven 0,85, gemeten 1,00 terwijl het bot op
0,98 leunt) en dat de kraag op het bot zit (0,000). Zweefcheck en
omgevingcheck 1 opnieuw groen.

**Cloth (13 september, Max: "nee gaat nog steeds niet goed, je hebt geen
cloth iets van simulatie?? lightweight iets").** De slinger op een vlak
vlak bleef een plank. Nu een echte cloth: `SoftBody3D` op Jolt (het
project staat al op "Jolt Physics"), 7 x 10 punten per cape, drie
solver-iteraties, massa 0,15, stijfheid 0,85, demping 0,06, drag 0,08.
Eerst headless geproefd met een los script: een lap van 70 punten met de
bovenste rij vastgepind hangt stabiel en zwaait na als het anker
springt. Drie valkuilen gevonden: (1) `set_point_pinned(i, true,
pad_naar_anker)` laat de punten gewoon vallen in 4.7, dus pinnen zonder
attachment en de kraagrij per frame via
`PhysicsServer3D.soft_body_move_point` op zijn plek zetten; (2) die
move_point VOOR de eerste physics-stap (direct bij het bouwen) verminkt
de vrije punten (zoom twee eenheden weg, gemeten met een debugprint),
dus de eerste `_process`-frame doet het; (3) de soft body levert de
shader geen bruikbare normalen (de lap was zwart) en de winding stond
andersom (je zag de voering): in cloth-stand haalt de shader de normaal
uit `dFdx`/`dFdy` naar de camera toe, en de driehoeken zijn omgedraaid.
Vierde les: de kraagrij mag niet met de DRAAI van het rugbot mee, alleen
met zijn positie; de rij staat dwars op de kijkrichting van het model
(`cape_kraag_punten`), anders zwaait de lap bij de gedraaide rifle-idle
om de pion heen. Het lijf zijn twee capsules (romp heup-nek, bekken en
bovenbenen) op physics-laag 20 die per frame de botten volgen. De lap
staat onder de PawnView/Bewoner (schaal 1), `cape_weg` ruimt lap,
bot-anker en capsules op, bij gibs gaat hij mee weg, bij een gewone dood
wordt hij donker met het lijk. Knoppen `cape_sim` (0 = de vlakke
shader-lap terug) en `cape_sim_precisie`. Checks: capecheck meet nu de
cloth via zijn physics-punten (70 punten, kraag 0,000 van het bot, zoom
0,45 onder de kraag, niets ontploft), zweefcheck idem (de node staat op
de oorsprong: eerst 16 valse "meer dan 2 van hun pion").

Max daarna: "het heeft geen texture meer en is iets te los en gaat door
de body heen af en toe." Drie oorzaken, drie fixes: (1) de textuur zat
alleen op de buitenkant en vanaf de speler zie je bij de vijand vooral
de binnenkant (voering): in cloth-stand nu het plaatje op beide kanten,
binnen iets donkerder; (2) stijfheid van 0,85 naar 1, demping 0,06 naar
0,15, drag 0,08 naar 0,2, vijf iteraties in plaats van drie (knop
`cape_sim_precisie`); (3) de kraag begon op 0,06 pionhoogte achter de
rug, binnen de romp-capsule van 0,1: stof die in een capsule start duwt
de solver naar de dichtstbijzijnde wand, soms de voorkant. Nu `CAPE_RUG`
0,09 en de romp-capsule 0,085, dus de kraag begint erbuiten; de capsules
zijn kinematisch (`AnimatableBody3D` met sync_to_physics, Jolt kent dan
de snelheid van het lijf en drukt de stof weg in plaats van erdoorheen
te springen) en de bovenarmen doen mee (die zwaaien bij het mikken en
de bajonetstoot door de lap). Les: `get_meta(sleutel, null)` print een
fout als de sleutel ontbreekt; eerst `has_meta`. Max: "ook aan de
binnenkant, of doen we daar vol goud?" Vol goud: de binnenkant van de
blauwe cape is een goudzijde (de galonkleur, glanzend, iets donkerder
naar de kraag), knop `cape_voering_goud` (0 = het plaatje aan beide
kanten); rood houdt zijn doffe voering.

Max: "de hele cape hangt nu in het niets en begint niet goed bij de
schouders." Klopt: de kraag was een smalle rij op nekhoogte, 0,09
pionhoogte achter het lijf, dus vanaf de speler (van voren-boven) hing
er een lap los in de lucht achter de nek. Nu loopt de kraagrij OVER de
schouders: u = -1 op het ene schouderbot, 0 op het nekbot, 1 op het
andere (welk armbot rechts zit wordt gemeten aan de kijkrichting, niet
aan de naam), recht gelerpt, 0,045 omhoog en 0,03 naar achteren; de lap
is bovenaan zo breed als de schouderspan uit de rusthouding en loopt naar
de zoom uit (1,5 x). Erbij een schouderbalk-capsule tussen de armbotten.
Eerste poging klapte bij de bewoner de bovenste rijen omhoog over de
schouders (goudzijde naar buiten): de romp-capsule reikte tot boven de
nek en duwde de stof omhoog in plaats van naar achteren. De romp stopt
nu 0,07 onder de schouderlijn (capsules hebben `rek_a`/`rek_b` per
kant), de schouderbalk is dunner (0,045) en de kraag hangt er net
buiten. De check maakt nu ook `_shot_capecheck_voor.png`, van
voren-boven zoals de speler kijkt: daar is niets zwevends meer te zien.
De 3:4-regel geldt alleen nog voor de vlakke lap; de cloth-lap volgt de
schouders en rekt het plaatje iets mee.

**Textuur (Max: "schrijf een texture prompt voor de blauwe cape met gouden
rand, mogen 3 verschillende zijn").** De shader neemt `cape_blue.png` /
`cape_red.png` (onder assets/models, aanrader props/) als buitenkant zodra
het er ligt (`PawnView.cape_textuur`, gecachet); zonder plaatje kleurt hij
zelf. De uv-hoek is gemeten in capecheck: linksboven van de lap = uv
(0, 0), dus boven = kraag, links = links van de drager gezien vanaf zijn
rug; een normaal getekend plaatje staat goed. Layout-regels en drie
prompts (velours met galon, damast met Napoleon-bijen en lauwerkrans,
officiersmantel met adelaar en hermelijnkraag) in
`assets/models/props/LEESMIJ.md`. Max' generator kent geen 4:5 (wel 1:1,
3:2, 2:3, 4:3, 3:4, 16:9, 9:16 en vaste maten): daarom neemt de lap nu de
verhouding van het plaatje over (breedte = lengte x b/h, lengte blijft de
knop), en zeggen de prompts 3:4 (1152 x 1536). Capecheck bewijst het met
een plaatje van 3 x 4. Max: "sla ook deze prompts op een file tracker":
PROP-WISHLIST sectie 14 (Texturen) draagt ze, en de prop-tracker kent nu
png-rijen (status = ligt het plaatje ergens onder assets/models), prompts
zonder prop-sjabloon eromheen, en variant-rijen (zelfde bestandsnaam als
de rij erboven, een pijltje, tellen niet dubbel). Max leverde meteen
variant 1 (velours met goudgalon en lelies, 1152 x 1536) als
`assets/models/props/cape_blue.png`: import op VRAM-compressie met
mipmaps (zoals de bord-textuur; een lap in 3D zonder mipmaps flikkert),
capecheck meldt "geleverd", de tracker staat op 7 klaar.

**Kegelen en keilen (Max: "de bowling werkt niet goed: je klikt, dan komt
de pijl, en dan inhouden en de pijl groeit; de pijl moet meteen komen; en
als die links is rolt de bal naar rechts").** Twee fouten in
`spelletjes.gd` (van de andere sessie, hier gefixt omdat het bericht hier
kwam): (1) de pijl kwam pas na `HOLD_DREMPEL` (0,22 s); nu start het
richten meteen bij het indrukken en telt loslaten binnen de drempel als
een gewone tik (de cadans wacht nog wel, die begint met tikken); (2) de
pijl draaide met `+hoek` om +Y, wat lokaal -Z naar -X zet, terwijl de worp
`(sin(hoek), 0, -cos(hoek))` naar +X gaat: gespiegeld. Nu `-hoek` op de
pijl, zodat kegelen en keilen allebei kloppen. `-- spelcheck` PASS
(kegelen 10, keilen 2, kanon 2, vissen 1, cadans 8 van 8), capecheck PASS,
omgevingcheck 1 PASS.

## 16 september -- 4.3.6: de ruiter krijgt +2 stamina en +2 attack (was: minstens 2)

Max: "en het is plus, dus als ik een cavalry een 1 atk kaart geef dan
heeft ie 3 atk, niet 2". C22 was in 4.3.5 als ondergrens gelezen
(`stat_minimum`); nu `stat_bonus` per type bovenop kaart en
factie-bonussen (`RulesConfig.stat_bonus`, to_dict/from_dict,
`Reducer._do_link` na de factie-bonussen en voor de lege ondergrens), in
alle configs op cav 2/2 (rules_v42_campaign, v42_default, de zes
duur/rules_pt*, duel_rules_voor); `arena/run.gd` legt hem over configs
zonder. rules_version 4.3.6. Nieuwe test
`test_ruiter_krijgt_2_stamina_en_2_attack_erbij` (1-kaart -> 3, 4-kaart ->
6, infanterie ongemoeid, de echte config draagt de bonus en geen
ondergrens meer); de 4.3.5-test blijft (de knop bestaat nog). Goldens
opnieuw gegenereerd (15 hash-mismatches op seq 0, want de regels zitten in
de hash), golden_sims.json opnieuw geijkt (tabel in de CHANGELOG),
testsuite 2490/0. Regressie: uispel 777 nu `a6677ac8…` (220 acties, cyclus
7; was d16a14f8, 246, 6), herstelcheck 777 0 verschillen, resumecheck 777 1
0 verschillen, naadcheck PASS. Core-hash veranderd: server opnieuw
uitrollen en een nieuwe client-build. Balans: de cavalerie wordt sterker
(Wolf met acht ruiters het meest); dat meet de nachtrun na het hertrainen,
die start Max zelf.

## 16 september -- blokjes tot 9, de factie-bonus op de kaart, kleiner embleem, de duo-emblemen

Max: "zorg dat de blokjes ook kloppen, je kan ook met CP en bonus 6 of 7
krijgen toch?" De stat-blokjes onder een pion waren een vast raster van 5;
alles daarboven viel weg. Nu bouwt `_build_health_bars` 9 kolommen per rij
(HP_COLS_MAX) en toont `_update_health_bars` per pion zoveel kolommen als hij
nodig heeft (minstens 5, tot 9: max_hp, stamina met trom, attack met
vaandel), gecentreerd onder de voeten; rol-icoon en vraagteken schuiven
mee; de render-digest telt alleen zichtbare blokjes. Max: "fix dat bij het
definieren per factie al duidelijk is op de kaart wat de +1 is, bijv muis
stamina heeft al +1": `CardView.set_bonus` zet een goudkleurig "+n" naast
het cijfer, `CardHand.configure` krijgt `factie_bonus` en game.gd geeft
`[hp_bonus, speed_bonus, 0]` uit de doctrine mee (`_factie_bonus_van`;
alleen wat voor elke pion geldt, de cavalerie-bonus van de Wolf en de
ondergrenzen per type niet). Max: "het embleem op de kaarten mag een stuk
kleiner en de stats wat groter": krans 0,94 -> 0,58, factienaam, sierlijn
en kolommen omhoog, de drie kolommen 1,14 x (`KAART_KOLOM_SCHAAL`, de
kolom-node schaalt met alles erin), cijfer 96 en boven de plus gezet
(KOLOM_CIJFER_Y 108, KNOP_Y 212). Max: "gebruik deze emblemen" (de zes
duo-gravures, big bro met zijn kleine broertje, uit
`fogofwar-assets/UI_assets_pack/Emblems/<dier>_nobg.png`):
`tools/verwerk_emblemen.py` knipt ze op de doorzichtige inhoud, maakt ze
vierkant en schrijft `assets/ui/emblems/<Naam>.png` op 500 x 500 (de oude
enkelvoudige koppen zijn vervangen). Checks: uispel 777 d16a14f8,
herstelcheck 777 0 verschillen, koppelcheck PASS, uicheck PASS, `-- define`
met venster: kaart met klein duo-embleem, grote stats, cijfer boven de plus.

## 16 september -- spelletjes nooit op het bord, hooguit twee per diorama, de kogel rolt door

Max: "de spelletjes mogen nooit op het bord komen en doe er nooit meer dan
2 per diorama", en "laat het kanon dat schiet de bal ook doorrollen op de
tonnen". Het kanon in Na de slag richt langs het bord; met de nieuwe zwaai
van 14 graden en dracht 7 landde de kogel op de verre rand van het bord.
Nu `_op_bord`/`_tot_buiten_bord` in Spelletjes (het bord is 0..10 in
Props-ruimte, marge 0,9): de kegelbal en de kanonskogel (dracht en rol)
stoppen ervoor; `_kanon_dracht` neemt de hoek mee en de doelring toont de
begrensde dracht. De kogel rolt na de inslag door (0,5 + 1,1 x kracht,
uitrollend, tollend om de dwars-as) en elk vat binnen 0,42 van dat pad
ontploft op het moment dat hij er langs komt (`_kanon_inslag` met rol_eind
en rol_duur); daarna blijft hij nog 2,4 s liggen. Per diorama telde alleen
Weidekamp drie spellen (cadans, kegelen, keilen): de cadans is daar weg
(spelcheck meet de cadans nu in Bosrand). Spelcheck en omgevingcheck PASS.

## 16 september -- idles: iedereen stil, af en toe een die rondkijkt

Max: "geef alle idles ook de standaard meest stilstaande idle en maximaal
af en toe doet 1 a 3 poppetjes een andere idle zoals dat rondkijken".
`_play_variant` gaf elke pion een willekeurige idle-variant (en de
vaandeldrager de stilste). Nu krijgt iedereen de stilste (dezelfde meting
op de kop/nek-tracks, per model gecached) en loot `_idle_process` per pion
elke 6-16 s met 30% kans een andere variant voor een clip lang, hooguit
`idle_afwijkers` (knop, 2) tegelijk; de vaandeldrager nooit. Eigen RNG per
pion (seed model + pion-id); de terugkeer naar stil gaat rechtstreeks via
`_anim.play`, want `_play_variant` trekt uit de globale RNG en dat moment
hangt van de framerate af. Nieuwe check `-- idlecheck`: twaalf muizen,
twintig seconden, piek tegelijk afwijkend 2 bij knop 2, PASS. uispel 777
d16a14f8, zweefcheck muis 2 PASS, meleecheck PASS.

## 16 september -- de flessen vliegen mee met de bal

Max: "alle objecten draaien om hun laagste as, bijvoorbeeld bij het
bowlen: laat ze echt met de bal mee vliegen". De flessen kantelden om hun
voet (rotation.x naar 1,45). Nu per fles een boog (`_boog`) in de richting
van de klap met wat zijwaartse spreiding, tuimelend om een schuine
dwars-as, dan plat neerkomen met een stuiter en even doorrollen;
`sterkte` 1 voor een directe treffer en steeds 0,65 x voor de ketting
(minstens 0,35) bepaalt afstand, hoogte en tuimel. Het terugzetten zet ook
de positie terug. Spelcheck PASS (strike).

## 16 september -- een geul voor het keilen

Max: "bij het ketsen van de steen ook een grotere plas maken of een soort
geul met water". `_bouw_plas_met_kikker` maakt de plas met `stenen` nu een
geul: ellips 1,45 bij 0,7 (was 0,6 bij 0,43), de wortel 0,6 rad gedraaid
zodat de lange as van het bord af wijst, een modderrand eronder, de stenen
aan de bordkant op (-1,62, 0,22) en de hengel op de rand; ijs en water
schalen mee; het glb-plasje wordt dan niet gebruikt. `water.groot` laat de
hupjes (0,25 + 0,9 x kracht, als op de rivier), het glijden op ijs en de
pijl langer zijn. Spelcheck en omgevingcheck PASS.

## 16 september -- werpen en schieten in drie tikken

Max: "maak alle bowl- en schietspelletjes zo: je klikt, je ziet de
richting-pijl die heen en weer gaat; dan klik je, dan staat de richting
vast, dan gaat een pijl of krachtmeter snel omhoog en naar beneden; dan
klik je weer, dan heb je je kracht." `Spelletjes` heeft nu een fase in
`_actief`: "richting" (pijl zwaait, vaste halve lengte) en "kracht" (de
pijl is de meter: driehoeksgolf, 0,45 s per kant, oranje geknipper op vol).
Tik 1 op de prop start, tik 2 zet de richting vast (`_volgende_tik`, met
een tikje), tik 3 werpt. Tik 2 en 3 mogen overal: `Omgeving.klik` geeft
een tik naast alle props door aan `tik_elders`; een tik op een andere prop
breekt af (`breek_af`) en geeft die prop zijn gewone tik. Kanon en vissen
heeft geen richting (zwaai 0) en begint met de meter; het kanon kreeg er
even later wel een (Max: "geef het kanon ook een richting, alleen dan
gaat hij sneller en het aantal graden minder"): zwaai 14 graden bij
snelheid 4,6, de loop draait mee (rotation.y) en de kogel landt op
`_kanon_richting(hoek)` maal de dracht. Loslaten en
wegschuiven doen niets meer voor het werpen (met een muis beweeg je tussen
de tikken), alleen nog voor de cadans; RICHT_TIMEOUT 12 s ruimt een
vergeten pijl op. `zet_richt` (check) zet beide vast en de volgende tik
werpt. Spelcheck controleert de fasen per spel (PASS: kegelen 8, keilen 4,
kanon 2, vissen 1, cadans 8/8); omgevingcheck telt bij een werp-prop de
neergezette pijl als reactie (PASS).

## 16 september -- capes reageren alleen op een schot in de buurt; de hitstop blies ze weg

Max: "alle capes reageren nu op een schot, dat moet niet, alleen binnen een
bepaalde straal rondom het schot, en bij kanon nog iets grotere straal", en
eerder: "de cape hangt over het hele poppetje". Nieuwe check `-- capeschot`
(drie blauwe muizen met cape op 1, 3 en 7 vakken van de vuurmond, grootste
verplaatsing van een lap-punt over 0,8 s tegen de rust) bewees het: op een
musketschot met vuur-shake en treffer-hitstop bewoog de cape op 7 vakken
0,92 (rust 0,03). Losse proeven: alleen de shake doet niets, alleen de
hitstop (Engine.time_scale 0,05 gedurende 0,12 s) gooit ALLE cloth-capes
(SoftBody3D op Jolt) van de rug, en zo'n weggeblazen lap hangt daarna over
het hele poppetje. Fix: `_hitstop` zet ook `PhysicsServer3D.set_active(false)`
zolang hij duurt. Daarnaast een echte vlaag: `game._cape_vlaag` bij het
afvuren duwt elke cape binnen cape_vlaag_straal (musket 2 vakken) of
cape_vlaag_straal_kanon (3,5) van de vuurmond af, sterkte lineair af naar de
rand, kanon harder (`PawnView.cape_vlaag`: `apply_central_impulse` op de
cloth, een stoot op de slinger van de vlakke lap; knop `cape_vlaag`). Na de
fix: musket dichtbij 0,54, op 3 en 7 vakken 0,02; kanon dichtbij 0,84, op 3
vakken 0,38, op 7 vakken 0,02. capeschot PASS, capecheck PASS, uispel 777
d16a14f8.

## 16 september -- geen cape op de cavalerie

Max: "verwijder de cape ook voor cav". `PawnView._hang_cape` hangt de lap
nu alleen op INFANTRY (was: alles behalve artillerie). Capecheck zet het
type van de blauwe muis op cavalerie en terug (rechtstreeks op `_unit_type`,
want `set_unit_type` wisselt een karaktermodel voor het geometrische stuk):
cavalerie geen cape, infanterie weer wel. PASS. Puur visueel.

## 16 september -- cavalerie-prompts zonder hoed

Max: "in de model tracker hebben alle cav prompts nog hoedjes op die ze
allemaal niet echt hebben, fix de prompts". Sinds 16 augustus droeg elke big
bro in de prompt de factie-hoed als `battered`; de cavalerie is blootshoofds.
Uit alle dertig cavalerie-prompts (zes facties x vijf archetypen) is de hoed
gehaald, in `model-tracker.html` en in `MODEL-WISHLIST.md`; de spd-pluim
staat op de schouder van het harnas. `heeftHoed` in de tracker geeft voor een
cavalerie-model dat er nog niet ligt nu `false`, zodat ook de team-prompts
(rood/blauw) er geen noemen; de infanterie houdt zijn hoed. De twee
uitlegzinnen in de wishlist (factie-herkenning cavalerie, hoofddeksel per
factie) zijn bijgewerkt. Gestaged als index-blob uit HEAD, want de werkboom
draagt ook de artillerie-prompts van de andere sessie.

## 14 september -- de hakbijl via de Blender-MCP-connector

Max: "gebruik de blender mcp connector", "maak de hakbijl voor me", bij de
platen van batch 2/3: "ik vind het tegenvallen, verwijder maar" (gedaan,
17ffdc0). De bijl is gebouwd in de draaiende Blender 5.1.2 via
`mcp__Blender__execute_blender_code` (script `tools/blender_props/
hakbijl_mcp.py`, uitgevoerd met exec, gerenderd met Eevee en naast Max'
plaatje gelegd). Eerste versie: kop uit een profiel met twee bmesh-insets en
een uitdrijving; Max: "is dit mooi glad ja?" bij zwarte driehoeken op de kop:
omgeklapte en overlappende vlakken. Tweede versie: "dit lijkt niet echt op
mijn plaatje", te dun en te veel een waaier met baard. Nu: de kop als loft van
zes dwarsdoorsneden (afgeschuind poll-vlak, dik blokkig lijf 0,11, wang,
slijpvouw 0,03, snede 0,004 met een bolle snede), kop 0,44 breed op een steel
van 1,07 (ruim de helft, zoals op het plaatje), steel 8 facetten met een bocht
naar de poll-kant en een zwelling naar de bladkant, de steeltop met wig boven
de kop uit. Manifold, 316 driehoeken. Zonder texturen (Max: "textures kan je
achterwege laten"): vier platte kleuren in een 64x64-palet, UV per vlak op
het blokmidden, een materiaal (eerst waren het er vier: vier draw calls).
Les: `image.pixels` van een 8-bits sRGB-plaatje zijn de sRGB-bytes, lineaire
waarden erin maakten het staal in Godot bijna zwart.

Pijplijn: `verwerk_prop.py ... axe` werkte eerst stilletjes niet: de
.blend-kopie in `results/props_blender/hakbijl/` liet Godot de hele
import-run afbreken ("Blender path is invalid", geen foutcode), zodat de
oude batch-1-textuur bleef staan. Nu `results/props_blender/.gdignore`, en
verwerk_prop meldt die regel als FOUT. En de bijl hing sinds batch 1 nergens
meer: `_bouw_bijl_stronk` stopte bij de hakblok-glb, zonder bijl en zonder de
bijl-reacties. Nu staat hij met de snede in het hakblok, steel schuin omhoog,
de klikdoos opnieuw gemeten, gemeld als `prop_hakblok (prop_hakblok.glb +
prop_axe.glb)`; de check matcht op de glb-naam. Nieuw: `-- propshot <naam>
[red|blue]` zet een prop-glb hoog boven het bord in het spel-licht en
schrijft `_shot_prop_<naam>.png` en `_achter.png` (met venster).
Checks: omgevingcheck PASS, propshot PASS, uispel 777 d16a14f8.

## 13 september -- batch 2 en 3 (28 props uit Blender): gebouwd en weer verwijderd

Batch 2 (kannen, ketels, kommen, manden, blauw en goud) en batch 3 (doek,
vaandels, het rijke kamp met het paviljoen als tent_blue en een
vlagstandaard op een driepoot) hebben een uur in het spel gestaan (commit
77cf5d0: 28 glb's, plaatsing per diorama met de team-regel, PROP_HOOGTE op
ware maat, `-- omgevingcheck [nr] blauw`). Max bij de twee platen: "ik vind
het tegenvallen, verwijder maar". Weer eruit: de 28 glb's met texturen en
.import, omgeving.gd terug naar de stand van batch 1 (specs, PROP_HOOGTE en
de EXTRA_PROPS-regels van musketrek, waslijn, kaarttafel en tapijt zoals ze
waren), tracker herbouwd. Gebleven: batch 1 (22, hout en ijzer) en de
appelkist, de recepten in `tools/blender_props/recepten.py` (`bouw_props.py
--batch 2` bouwt ze nog, maar niet opnieuw in het spel zetten in deze
stijl) en de check-optie `blauw` in capture.gd. Les: doek, email en
goudbeslag uit primitieven en een noise-atlas halen de voorbeelden niet;
hout en ijzer komen er dichterbij. Voor die 28 geldt weer de Tripo-route.
Checks na het verwijderen: omgevingcheck PASS, uispel 777 d16a14f8.

## 13 september -- 56 voorbeelden, batch 1: 22 props uit Blender

Max: "in assets/models/props/previews staan 56 voorbeelden, exact zo moeten
ze in Blender." De plaatjes heetten `tmp<hash>.jpg`; ze zijn hernoemd naar
de prop uit de wishlist (`_red`/`_blue`, `_alt` voor een tweede kandidaat;
tabel in `previews/LEESMIJ.md`, `.gdignore` zodat Godot ze niet importeert).
Omdat het er 56 zijn, is er nu een fabriek in plaats van een script per
prop: `tools/blender_props/bouwstenen.py` (box, lathe/draaivorm met
binnenwand voor open vormen, cil, bol, piramide voor spijkerkoppen, touw
langs een lijn, doek; per vlak een platte uv in een stofje, rondom een
draaivorm loopt u een keer rond zodat de naad op een facetrand valt) plus
EEN atlas van 1024 px met 8 x 8 tileerbare stofjes uit numpy (periodieke
value-noise; hout in vier smaken, duigen met een naad per duig, schors,
kopse kant met jaarringen, ijzer, roest, goud, koper, zilver, leer, touw,
jute, linnen, blauw fluweel, goudrand, steen, klei, lei, en decals:
fleur-de-lis, kroon, wapen, tapijt), `recepten.py` (per prop een functie,
maten in bord-eenheden, voorkant -y) en `bouw_props.py` (glb per prop +
een plaat van alles, van hoog naar laag zodat een ton het houtblok niet
verbergt). `tools/verwerk_props_bulk.py` zet een hele map in het spel met
een import en een omgevingcheck (22 props in vijf minuten).

Batch 1, hout en ijzer: kruitvat (met lont), kogels (14 in een piramide),
houtstapel (kruisstapel), houtblok, takkenbos, hakblok, zaag (leunt tegen
een blok), axe, touwrol, barrel (staat op 1,0 hoog: de "ton" schaalt met
0,56 zoals de Tripo-ton), barrel_red (roest, touw, gat), bierton_red (op
een bok met kraan), emmer en emmer_red (open, met binnenwand en touwgreep),
kist en kist_red (beslag, touw, lap), lantaarn aan een paal, fakkel
(vuurkorf op een driepoot), aambeeld op een blok met hamer, blaasbalg,
werkbank met gereedschap, put met leien dak en emmer. 40-1.120 driehoeken,
130-240 kB per glb. In omgeving.gd: PROP_HOOGTE op de ware maat van de
doos (schaal 1), de acht die in EXTRA_PROPS stonden daaruit gehaald (dat
zette ze in alle twaalf diorama's, met botsingen) en per diorama geplaatst
(smid in Dorpsrand en Waterloo, houthakkers in Bosrand en Boerenerf, kade
met touwrol en kist in de Rivierhaven, lantaarn in Weidekamp, Winterkamp en
Kapelruine, fakkels in Na de slag, Kapelruine en Egypte); `_plaats` valt
voor een naam zonder placeholder terug op zijn glb; de "ton" pakt per kamp
`prop_barrel_red`/`_blue`. De Tripo-bijl en -ton van juli zijn vervangen
(hun losse Color/NormalGL/ORM-jpg's weg). Checks: omgevingcheck PASS met
17 van de 22 als "geleverde glb-props" (axe en barrel gaan via de
placeholders, emmer en kist gedeeld staan nog nergens), uispel 777 en
herstelcheck 777 ongewijzigd.

## 13 september -- de appelkist: eerste eigen low-poly prop uit Blender

Max stuurde een plaatje van een houten krat met gefacetteerde appels: "kan
jij met blender dit maken, zo low poly mogelijk?" `tools/blender_appelkist.py`
bouwt hem procedureel: twaalf planken met kieren, vier hoekpalen erachter,
een bodem, de schuine lat op de voorkant (glTF +Z), spijkerkoppen als
vierzijdige piramides zonder bodem (4 driehoeken), en appels als icosferen
met twee subdivisies (80 driehoeken; met een is het een d20) met een scheef
steeltje, gefacetteerd (geen smooth shading). Een mesh, een materiaal, een
256-plaatje met vier vakken uit numpy (houtnerf met donkere lijnen, rode en
groene appel met een verticaal verloop, donker voor stelen en spijkers);
de appel-uv's projecteren x en hoogte in hun vak, zodat de facetten van
boven naar onder donkerder worden. 1.424 driehoeken, 874 vertices, 179 kB.
Daarna `verwerk_prop.py results/appelkist/appelkist.glb appelkist`: 150 kB
als `prop_appelkist.glb`, omgevingcheck PASS. In omgeving.gd: `appelkist`
als spec (Boerenerf, Dorpsrand, Rivierhaven, Marktplein), PROP_HOOGTE 0,3,
eigen reactie `_reageer_appelkist_appel` (een appel wipt eruit, rolt een
stukje en verdwijnt). Bpy-lessen: `read_factory_settings(use_empty=True)`
VOOR het bouwen (een reset erna gooit mesh en object weg:
"StructRNA ... has been removed"), en een verloop met numpy-broadcasting
eerst met `broadcast_to` op maat brengen voordat je een kanaal bijwerkt.

## 12 september -- vijf mini-games in het diorama

Max: "bedenk 5 spelletjes die je kunt doen, mini games in de dioramas, dus
kegels bowlen door een bepaalde bal in te drukken met hoek en snelheid ...
heel low key, simpel te bedienen met een tap of een klik inhouden", en
daarna "bouw het gelijk". `scripts/game/spelletjes.gd` (`Spelletjes`, een
RefCounted met een verwijzing naar de Omgeving; de helpers `_mesh`, `_boog`,
`_fx_*`, `_rimpel`, `_registreer`, `_rng` worden gewoon gebruikt) met twee
bedieningen:

- WERPEN: `Omgeving.klik` speelt de tik en geeft een spel-prop aan
  `Spelletjes.druk`; na `HOLD_DREMPEL` (0,22 s) begint het richten: een
  pijl op de grond zwaait heen en weer (richting, `zwaai` graden) en groeit
  (kracht, `laadtijd`), van grijs naar goud en rood-pulserend als hij vol
  is. `laat_los` werpt; een korte tik speelt bij het loslaten de gewone
  reactie van de prop; `beweeg` verder dan 90 px breekt af. game.gd geeft
  het loslaten en de beweging door (nieuw, het spel keek alleen naar drukken).
- OP DE MAAT: een prop met `spel_staat.wacht_op_tik` krijgt elke tik.

De vijf: kegelen (`kegelspel` in DIORAMAS 1, 2, 3, 9: tien lege flessen
uit de kantine in de driehoek van het bowlen, omgerold met een kanonskogel;
Max: "maak die kegels wel iets wat bij de setting hoort", "bowlen zijn 10
stuks toch ... wat kleiner en geen ondervlak"; de eerste versie had negen
bowlingkegels in een ruit op een donker vlak; de kogel rolt langs de pijl
0,9-2,6 eenheden, treffers langs de baan en
een ketting met kans 0,72 naar achteren; "Poedel!", "%d kegels!", "Alle
negen!" met de chime; na twee tellen staat alles weer), keilen (stenen aan
elke plas met `{"stenen": true}`, en op de kade van de Rivierhaven: eerste
worp 1,4x de hup, dan steeds 0,78x korter, elke kets een kring en een
plons met oplopende toon; buiten het water: "Op de kant!"; de kikker duikt
als de steen langs komt; op de bevroren plas glijdt en tolt de steen), het
kanon (`kruitvaten` in 4, 11, 12; `koppel_doelen` draait elk kanon naar de
dichtstbijzijnde vaten; vasthouden: loop van 10 naar 45 graden en een
doelring op de dracht 1,6 + 5,4 x kracht; de wind van het potje duwt de
kogel 0,35 x kracht opzij, dus "Windje!" als het zonder wind raak was;
vier vaten in een kettingreactie, "Alles de lucht in!"), vissen (`hengel`
op de kade in 6 en `{"hengel": true}` op de plas van 2: de dobber vliegt
de lengte van de pijl, blijft binnen het water; na 2-5 s duikt hij 0,5 s,
tik dan: snoek 55%, laars 25%, musket 15%, kist 5%; te vroeg is "Te
vroeg!", drie keer gemist is "Niets..."; vangsten blijven op de kant liggen,
vijf tegelijk) en de tamboer-cadans (`{"cadans": true}` op de trommels in
1, 4, 7, 10: vasthouden telt vier slagen af met de trom, dan acht gouden
pulsen op het tempo (0,6 s) waarop je tikt, venster 0,17 s voor en na;
drie soldaatjes in de teamkleur marcheren op de plaats, het vlaggetje
stijgt; "Uit de maat!" laat ze struikelen; 8 van 8 is "Perfect!", een
hoornstoot en 10% sneller de volgende keer).

Geluiden: `prop_kegel` (3), `prop_kegel_rol`, `prop_kruitvat`, `prop_hengel`,
`prop_vis` in `maak_prop_geluiden.py` (106 bestanden, 44 categorieen; de
oude blijven byte-gelijk), rijen in SOUND-WISHLIST sectie 11 en prompts in
de geluid-tracker; PROP-WISHLIST sectie 13 met de Tripo-props (kegel, bal,
stenen, kruitvat, hengel, vis, soldaatje). Check `-- spelcheck`: per spel
het diorama, vinger erop, na de drempel `zet_richt(0, kracht)` (kanon: de
kracht die precies op de vaten landt), loslaten, wachten tot de prop vrij
is, score minstens 3/1/1/1/8; met venster `_shot_spel_richt.png`. Eerste
run: kegelen 8, keilen 4, kanon 3, vissen 1, cadans 8 van 8. Lessen: `as`
is een sleutelwoord (tweede keer, zie 11 september); en `-- omgevingcheck`
moet sinds vandaag drukken EN loslaten, want een spel-prop reageert pas bij
het loslaten (kort) of na de drempel (lang). Windows-les: een python-patch
die een .gd-bestand schrijft terwijl een Godot-proces draait, krijgt
`OSError 22` (user-mapped file): eerst de checks laten uitlopen.

## 12 september -- kaartkeuze blijft staan in de koppel-fase; dode dragers komen niet terug

Max: "houd mijn kaart geselecteerd ook al is de AI eerst aan de beurt,
totdat ik gelinkt heb." Twee dingen zaten in de weg: `_on_link_card_picked`
weigerde een kaart zodra `current_player` niet de mens was, en
`_begin_human_linking` wiste de keuze bij elke beurtwissel en bouwde de
waaier kaal op. Nu mag kiezen de hele koppel-fase (ook in de beurt van de
bot of de online tegenstander), koppelt een pion-klik in zijn beurt niets
en laat hij de keuze staan (HUD `HUD_LINK_CARD_READY`, nl/en gecompileerd
met `--import`), en zet `_begin_human_linking` de keuze terug in de waaier
via het nieuwe `CardHand.selecteer(index)` (visueel, zonder signaal;
`_on_card_tapped` slaat gekoppelde kaarten over). `_on_phase_changed` wist
de keuze: die leeft alleen binnen een koppel-fase. Na een eigen koppeling
wordt de waaier meteen bijgewerkt, zodat de volgende keuze op de juiste
kaarten valt. Check `-- koppelcheck`: speelt tot de koppel-fase, kiest een
kaart terwijl de bot denkt, bewijst dat een pion-klik dan niets koppelt,
dat de keuze de beurtwissel overleeft (ook in de waaier: `_selected_index`
en de gloed) en pas na het koppelen weg is. Commit f83b130.

Max: "soms spawnen er weer soldaten met een trom of een vlag, dat kan niet,
als ze dood zijn zijn ze dood." De engine geeft een spawn geen rol; het
was de weergave. `game._werk_figurant_rollen_bij` (30 juli, cosmetische
verdeling van vaandel en trom van voor C15) keek per leger alleen of er nog
een LEVENDE pion met echte rol was; waren de vaandeldrager en de tamboer
allebei dood, dan verdeelde hij weer cosmetische rollen over ongekoppelde
infanterie, en een verse spawn op de achterste rij was de verste kandidaat.
Nu: draagt het potje echte rollen (`campaign_actief_rollen`, sinds C17 elk
potje), dan wordt er niets verdeeld en is `_figurant_rollen` leeg; alleen
kaal 4.1 houdt de oude verdeling. Check `-- dragercheck`: opstelling met
echte dragers, alle dragers van speler 1 sneuvelen in de staat, een verse
spawn erbij, `_refresh_all`: speler 1 toont geen vaandel of trom meer, de
spawn is een gewone soldaat, speler 2 houdt zijn dragers. Docs: CLAUDE.md
(zweefcheck-bullet en een koppel-bullet).

## 12 september -- de eerste Tripo-prop: de rode tent, en verwerk_prop.py

Max: "de tent van rood is dit" (een `tripo_node_<uuid>.glb` uit Downloads).
Geleverd: 174 driehoeken, een mesh, een materiaal, drie texturen van 2048
die samen 9,3 MB wegen, doos 1,00 x 0,64 x 0,65, de nok langs X (dus de
open voorkant naar -X). Dat is meteen het recept voor de ~100 die volgen,
vandaar gereedschap in plaats van handwerk:

- `tools/verwerk_prop.py <glb> <naam> [--team red|blue] [--draai graden]
  [--textuur 1024] [--doel 1500] [--hoogte] [--droogloop]`: meet de glb
  (pure python, struct + PIL, geen Blender nodig), decimeert boven `--doel`
  met blender_decimate.py, slankt de texturen af (kleur en ruwheid JPEG
  zonder chroma-subsampling, normaal PNG, hoogstens 1024, de ruwheid 512;
  alfa blijft alleen als het materiaal een alphaMode BLEND/MASK heeft, want
  Tripo zet in elke kleurtextuur wel ergens wat alfa die niemand rendert),
  hernoemt ze naar kleur/normaal/ruwheid zodat Godot ze leesbaar naast de
  glb uitpakt, bakt `--draai` in een wortelknoop `draai_<hoek>` (een tweede
  keer draaien vervangt de hoek), schrijft `prop_<naam>[_team].glb` (9,3 MB
  werd 1,11 MB), en controleert: `--import`, de `.import` van de uitgepakte
  texturen op VRAM-compressie + mipmaps (de normaal als normal map, dus
  RGTC), nog een `--import`, dan `-- omgevingcheck`, die PASS moet geven en
  de prop moet noemen in de nieuwe regel "geleverde glb-props" per diorama
  (capture.gd; `_glb_prop` zet daarvoor `glb` in het prop-dict).
- `tools/blender_prop_preview.py --in <glb> --uit <png>`: het model vier
  keer naast elkaar (0, 90, 180, 270 graden om de staande as, streepjes
  eronder), orthografisch van voren en iets van boven zoals het spel; de
  kolom waarin de voorkant naar je toe wijst is de `--draai`. Les: de
  wereldmatrices van de wortels bewaren VOOR het omhangen; na de eerste
  `primitive_cube_add` draagt `matrix_world` van het origineel al de
  verplaatsing van kolom 0, en kolom 3 en 4 stonden daardoor scheef.
- omgeving.gd: `_glb_prop` geeft de wortel terug (was bool) en neemt
  `reacties` en `extra` aan, zodat een geleverde prop zijn EIGEN reacties
  houdt; `_lees_prop_manifest` kijkt eerst naar `prop_<naam>_<team>.json`;
  de wortelnaam is uniek (`prop_tent7`), want twee `prop_tent` onder Props
  hernoemt Godot stil tot `@Node3D@123`. `_bouw_tent` geeft de Tripo-tent
  de lantaarn aan de voorkant van zijn omhullende doos (nieuw
  `_hang_lantaarn`, ook door de placeholder gebruikt), het model als doek
  voor de Zzz, en de laars; tik blijft `prop_doek`.

De tent had `--draai 90` nodig: de open voorkant naar +Z, naar de speler
(de placeholder stond ook zo). Stand: `prop_tent_red.glb` + `_kleur.jpg`,
`_normaal.png`, `_ruwheid.jpg` in `assets/models/props/`; in diorama 1
staan beide rode tenten uit de glb, de blauwe aan de overkant blijft de
placeholder tot `prop_tent_blue.glb` er ligt. Checks: omgevingcheck PASS
(alle twaalf, geleverde glb-props: prop_tent (prop_tent_red.glb) x2),
uispel 777 d16a14f8, dioramashots. Tracker: ½ voor de tent (rood ligt
er). Docs: props/LEESMIJ.md sectie "Een Tripo-glb erin zetten", CLAUDE.md,
PROP-WISHLIST rij. Het origineel blijft in Downloads staan.

## 12 september -- alleen vaandel en trom dragen een prop; budget voor de Tripo-props

Max: "sommige hebben nu wel een prop vast anders dan de vlag of trom, dat
niet doen graag." Dat waren de sporadische figuranten uit 28 juli: elke
vijfde ongekoppelde infanterist kreeg een hoorn, bijl, vat of staf in de
hand (`PawnView.ROLLEN_EXTRA`, `ROL_DICHTHEID` 5). `ROL_DICHTHEID` staat nu
op 0 (de ontworpen uit-stand), dus in het spel dragen alleen de
vaandeldrager en de tamboer een prop. De rollen zelf blijven bestaan: de
Model-tuner kan ze nog forceren (tab In de hand) en `prop_for`/`PROP_ALIAS`
zijn ongewijzigd, en het diorama gebruikt prop_drum/prop_barrel/prop_horn/
prop_axe als klik-props los van de pionnen. Puur visueel: `-- uispel 777`
blijft d16a14f8, `-- herstelcheck 777` 0 verschillen, `-- zweefcheck muis
2` toont per pion alleen nog musket, vaandel of trom, `-- tunercheck` PASS.
Docs: props/LEESMIJ.md (tabel + stap 2), CLAUDE.md. MODEL-WISHLIST §3d
punt 5 beschrijft de extra's nog als "ongeveer een op de vijf"; dat bestand
staat open in de andere sessie en is hier niet aangeraakt.

Max: "hoeveel props, hoeveel vertices is dan handig, of maakt dat niet heel
veel uit?" Gemeten (dioramashots print nu meshes en driehoeken per
diorama): 14-18 props, 70-106 meshes, 4.700-9.500 driehoeken per diorama
uit primitieven; een infanterist 2.231 + musket 736, twee legers ruim
90.000; het bord 196. Advies (tabel in props/LEESMIJ.md, samenvatting in
CLAUDE.md): klein 300-800, middel 800-1.500, groot decor 1.500-3.000, geen
prop boven de 3.000, diorama onder de 30.000, 15-25 props; EEN mesh en EEN
materiaal per prop, want draw calls wegen op een telefoon zwaarder dan
vertices; Tripo op de low-poly-optie (1.000-2.000 faces) of achteraf
`blender_decimate.py --doel 1200`; textuur 512, groot decor 1.024.

## 12 september -- de prop-geluiden in de geluid-tracker

Max: "voeg ook al deze prop geluiden toe aan de geluiden tracker."
`tools/bouw_geluid_tracker.py` heeft nu een sectie Diorama-props onder de
facties: de 40 `prop_*`/`bewoner_*`-categorieen uit SOUND-WISHLIST sectie 11,
per stuk de stand (echt opgenomen, nog synthetisch, leeg), het gewenste
aantal varianten, de Nederlandse omschrijving en een Engelse
ElevenLabs-prompt om te kopieren (`PROP_PROMPT_EN`). Synthetisch herkent
hij aan `sounds/props/synthetisch.json`: `maak_prop_geluiden.py` schrijft
daar de sha1 van elk bestand dat hij maakt (en zaait nu per bestand vast,
want python's `hash()` wisselt per proces); een echte opname op dezelfde
naam heeft een andere hash en telt als echt. Stand: 39 synthetisch, 1 leeg
(`prop_schot`, dat leent `musket`). Een les: een patch-script dat
`io.open(pad, "w", newline="\\n")` verkeerd citeert maakt het doelbestand
LEEG voordat de ValueError komt; twee keer teruggezet uit git, nu een
binaire schrijfactie.

Max ook: "en deze moeten allen ook een 3d model hebben niet? met tripo maak
ik alles." Ja: elke ⚙ in de prop-tracker is een placeholder uit primitieven
die wijkt voor `assets/models/props/prop_<naam>.glb` (of `_red`/`_blue`);
de prompt per prop staat in de tracker. Tripo levert glb met textuur, dus
geen Blender-stap: neerzetten, `--import`, en bij een zware mesh
`tools/blender_decimate.py`.

## 11 september -- drie trainingsruns, de Beer op 39%, en de factiezoeker gerepareerd

Max: "wat hebben ze geleerd, heb een run gedaan" en daarna "dan moet de
factietrainer maar even kijken wat de juiste samenstelling is".

**Wat de bots leerden: bijna niets.** Drie keer TRAINING-NACHT (8-9 sept
nacht, 9 sept avond na twee uur afgebroken, 10 sept overdag, elk 420 min
budget per factie). Alleen de Wolf nam een kandidaat aan (8 sept 23:03,
generatie 3, verificatie 8,9/12 tegen referentie 6,6): zijn nieuwe termen
kwamen op ~0,6-0,75 van de defaults uit (reserve_pt 14,5, reserve_cp 7,6,
aura_waarde 3,9, drager_front -0,7) en de rest schoof mee. De andere vijf
spelen de augustus-gewichten met de defaults erbij; ruim tweehonderd
kandidaten verworpen, convergentiecheck overal "plateau". De bots jagen
wel op dragers: 0,75-1,45 pt en 2,0-2,6 CP buit per potje, 0,5-1,0 eigen
dragers verloren. Trainingsdata (wolf-gewichten + matchup-logs) apart
gecommit.

**De nachtmeting is het nieuws** (10 sept, 3240 partijen, L2, 4.3.5; 9 sept
binnen 2,3 pp hetzelfde): Leeuw 55,6, Varken 54,7, Krokodil 53,1, Muis
51,3, Wolf 46,1, **Beer 39,3** (augustus: 56,7, de top). Band 16,3 pp (was
11,9). Beer verloor vooral van Muis (57 -> 31), Wolf (72 -> 34) en Krokodil
(84 -> 52): de ruiter-ondergrens 2/2 (C22) en de buit helpen iedereen
behalve de factie zonder ruiters van betekenis. De scharen Krokodil >
Varken (99%), Varken > Muis (91) en Varken > Beer (88) zijn NIET nieuw:
die stonden in augustus ook al zo.

**Factiezoeker, gerichte modus.** `--facties 3 --achtergrond
<games.jsonl>`: nulmeting en kandidaten spelen alleen de 11 paren met de
gezochte factie; de 25 andere paren komen uit het meegegeven bestand (de
nachtmatrix), teruggesnoeid tot evenveel partijen per paar als de zoeker
zelf speelt. Die paren spelen met vaste seeds toch byte-identiek, en onder
4.3.5 duurt een partij bijna een minuut (nachtrun: 0,51 partij/s met 30
processen), dus dit scheelt ruim drie keer. Seeds lopen in run.gd op met
de positie in de paarlijst, dus nulmeting en kandidaten spelen dezelfde
lijst en blijven gepaard.

**Twee fouten in de zoeker gevonden en gefixt.**
1. Run 1 (09:07): negen "ongewijzigde" kandidaten scoorden Beer 14,7%
   tegen 43,3% in de nulmeting, met dezelfde seeds. `muteer` haalde
   knoppen die gelijk zijn aan de basis uit het voorstel, maar sinds C19
   IS de basis het aangenomen blok (Beer: comp [19,3,0]); zonder dat blok
   valt de arena terug op de kale tabel uit constants.gd ([16,3,3], drie
   kanonnen). Vrijwel elke kandidaat sinds C19 is dus op de juli-factie
   gemeten. Nu blijft wat in het blok van de kampioen staat altijd staan.
   Bijvangst: de juli-Beer met drie kanonnen haalt onder 4.3.5 maar 14,7%.
2. Twaalf van de dertig kandidaten waren kopieen (integer-knoppen ronden
   een kleine stap weg), elk een half uur rekenen. Nu ontdubbeld, ook over
   generaties heen zolang de kampioen niet wisselt. En een ruilzet in de
   comp (een pion van type naar type, totaal gelijk): een factie op het
   bordmaximum (Beer 22) kon anders nooit een ruiter erbij krijgen.

**Run 2 (12:22, gerepareerd, 170 min, 30 kandidaten):** "niets veranderd
ten opzichte van nu", score 0,8848. Beste uitdager: ruiters +1 snelheid
(Beer 56,7, Wolf zakt naar 38,7; 0,8804). Kaartbudget 8: Beer 68,7;
budget 9: 81,3; kaarten 4: 44,0; snelheidslimiet 5: 40,0; 17 of 18
infanterie: 31-33; HP-bonus eraf: 10,7; 2 kaarten: 8,0. De knoppen zijn
grof (een budgetpunt is 25 pp) en de HP-bonus per koppeling is het hart
van de Beer.

**Batch met de hand (zes samenstellingen, 11 paren x 15 partijen, dezelfde
seeds als run 2):**

| Beer | score | afwijking | Beer wint | tegen Varken / Muis / Leeuw / Wolf / Krokodil |
|---|---|---|---|---|
| zoals nu, [19,3,0], 3 startpunten | 0,8848 | 4,2 | 43,3% | 20 / 27 / 70 / 33 / 67 |
| [18,4,0] | 0,8697 | 5,1 | 46,0% | 7 / 37 / 63 / 60 / 63 |
| **[17,5,0]** | **0,8958** | **2,9** | 46,7% | 10 / 50 / 70 / 23 / 80 |
| [18,3,1] (een kanon) | 0,7574 | 11,3 | 16,0% | 3 / 7 / 23 / 0 / 47 |
| [17,4,1] | 0,7525 | 11,8 | 14,7% | 0 / 0 / 27 / 3 / 43 |
| startpunten 6 | 0,8592 | 5,8 | 41,3% | 13 / 33 / 63 / 47 / 50 |
| startpunten 9 | 0,8760 | 5,1 | 54,7% | 17 / 37 / 80 / 70 / 70 |

Per tegenstander 30 partijen (ruis ~9 pp), totaal 150 (ruis ~4 pp). Een
kanon is voor de Beer gif (net als de juli-Beer met drie kanonnen). Twee
ruiters erbij ten koste van twee infanteristen geeft de beste balansscore
van alles wat vandaag gemeten is: de Beer zelf op 46,7 en de gemiddelde
afwijking van de zes facties van 4,2 naar 2,9. Startpunten werken niet
lineair (3 -> 6 doet niets, 6 -> 9 wel), dus die knop is verdacht ruisig.

**Nameting op verse seeds (777000, 11 paren x 30 partijen = 300 Beer-partijen
per kandidaat zonder spiegel, ruis ~3 pp), gepaard:**

| Beer | score | afwijking | Beer wint | alle zes (band) |
|---|---|---|---|---|
| zoals nu | 0,8486 | 6,7 | 35,7% | Leeuw 59,3 / Varken 57,0 / Krokodil 52,0 / Muis 51,7 / Wolf 44,3 / Beer 35,7 (23,6 pp) |
| **[17,5,0]** | **0,8933** | **3,3** | **49,7%** | Leeuw 53,7 / Krokodil 53,3 / Varken 53,0 / Beer 49,7 / Muis 48,0 / Wolf 42,3 (11,4 pp) |
| startpunten 9 | 0,8803 | 4,4 | 52,3% | Varken 56,7 / Leeuw 54,3 / Beer 52,3 / Krokodil 49,7 / Muis 45,7 / Wolf 41,3 (15,4 pp); vs Varken 5%, vs Muis 62% |

**Advies: Beer [19,3,0] -> [17,5,0]** (twee infanteristen worden ruiters; 22
pionnen blijft 22). Op verse seeds landt de Beer op 49,7 en krimpt de band
van 23,6 naar 11,4 procentpunt. Startpunten 9 zet de Beer ook rond de 50,
maar scheef (5% tegen Varken, 62% tegen Muis) en de knop is niet lineair.
Vastzetten is een regelwijziging: `comp` van factie 3 in het
`doctrines`-blok van `rules_v42_campaign.json` (de enige bron; los potje
en campagne lezen mee), dan `-- facties`, goldens (`-- makegoldens`),
`golden_sims.json` opnieuw ijken, `-- uispel 777` opnieuw meten, en de
bots hertrainen op de nieuwe Beer. Besluit ligt bij Max; niets is
gewijzigd. Uitslagen: `results/beer_batch_20260911_153518/uitslag.json`,
`results/beer_nameting_20260911_160530/uitslag.json`, zoeker-runs
`results/facties_20260911_090747` (fout, zie boven) en
`results/facties_20260911_122213`.

**Checks.** Geen spelcode geraakt (alleen `tools/balans/factiezoeker.py`
en scratch-scripts), dus geen goldens, geen uispel. `py_compile` plus
droge proeven van `muteer` (blok blijft staan in 60/60 kandidaten;
ruilzet levert [18,4,0]/[18,3,1]/...) en van `achtergrond_partijen`
(375 partijen, 25 paren, 15 per paar, geen Beer).

## 11 september -- twaalf diorama's, en elke prop reageert anders

Max: "Bedenk iets van 12 verschillende diorama's. Voeg sowieso ook een
hartvorm houten toilethuisje etc. En allemaal iconische dingen voor de
Napoleon-tijd. Ook moet er per diorama een beetje variatie komen: je klikt
op de vogel en dan vliegt ie weg, je klikt op de vogel en er komt een andere
vogel bij en een klein hartje, je klikt op de vogel dan wordt ie geschoten
en ploft hij in een verenbal om. Per klikbaar element verschillende dingen
die je random krijgt te zien."

**Reacties.** `Omgeving._registreer` neemt nu een lijst Callables; een klik
kiest er willekeurig een (`_speel_willekeurig`), nooit twee keer achter
elkaar dezelfde. Elke bestaande prop kreeg er twee bij (de kraai: weg en
terug / een tweede kraai met hartjes / geschoten, verenbal, valt van de
paal en later zit er een nieuwe; de kikker: springen / kwaken / duiken; het
vuur, de trommel, de ton, de hoorn, de bijl, de kogels, de tent, de
wegwijzer, de geleverde glb's en de bewoners net zo; tabel in
PROP-WISHLIST.md sectie 11). Gereedschap: tekstwolkjes (Label3D:
Bezet!, Zzz, Kwaak!, Plons!, Oehoe), hartjes (twee bollen en een
gekantelde kubus), veren, rook- en stofwolken, spetters, een knal met
lichtflits, een boogje voor tween_method (`_boog` via bind), vogels die
komen aanvliegen en weer weggaan (`_maak_vogel`, `_vlieg`, `_land_vogel`),
kippen die wegrennen (`_maak_kip`, `_ren_weg`). Alles hangt aan zijn
prop-node en ruimt zichzelf op.

**De twaalf diorama's** (`Omgeving.DIORAMAS`, data: grond, tint, extra's,
props als `[naam, x, z, draai, {opties}]`): Weidekamp, Boerenerf, Dorpsrand
met molen, Na de slag (modder, smeulend vuur, kanonnen, kruisen), Winterkamp
(sneeuw op de grond en uit de lucht, bevroren plas, sneeuwpop), Rivierhaven
(water met kade, steiger met sloep, een meeuw), Bosrand, Kapelruine (uil in
de boog), Marktplein (keien, kramen in teamkleur, fontein), Egypte 1798
(zand, piramiden, sfinx, palmen), Alpenpas (rots met sneeuw, kanon op de
pas), Hoeve van Waterloo. Per potje geloot in `game._loot_wind` (online uit
het match-id), knop `diorama` in het sfeer-paneel zet er een vast, en
`zet_diorama` herbouwt alles onder Props. Zestien nieuwe placeholder-props
uit primitieven, met het hartjes-toilethuisje voorop (deur aan een
scharnier: Bezet!, stinkwolk uit de pijp, een kip rent eruit), de molen
(wieken draaien met de wind, harder na een klik), het kanon (schiet met
flits, rook en terugslag), put, kruis met hoed, palm, piramide, sfinx,
steiger met sloep, ruine, fontein, marktkraam, sneeuwpop, hooiberg,
lantaarnpaal, boom (ook kaal), rots. Zes grondvarianten uit
`tools/maak_omgeving_texturen.py --varianten` (768, naadloos, VRAM +
mipmaps). Twee GDScript-lessen: `as` is een sleutelwoord (geen
variabelenaam voor een molenas), en een `:=` met een ternary van Color en
Array-element kan het type niet afleiden.

**Tik-dingen (later die ochtend).** Max: "ieder diorama moet minimaal 3
dingen hebben die lekker dingen of pingen of dongen die je zo vaak als je
klikt kunt klikken: glaswerk, drums, bijlen, poophuizen; alles wat geen
animatie heeft alleen een kleine schudding of stuiter." Nu roept `klik`
altijd eerst `_tik`: meteen een geluid (per prop een eigen categorie met
terugval, `TIK_GELUID`) met een toon die per snelle klik iets oploopt
(combo), en een stuiter van de hele prop, ook als de grote reactie nog
loopt; de grote reactie komt er alleen bij als de prop vrij is. Per prop een
tik-extra bovenop: bel zwaait, flessen wiebelen, de hamer slaat met vonken,
de deksel wipt, de deur rammelt, het vuur schrikt op. Vier nieuwe pure
dingers (bel, glaswerk met flessen en glazen, aambeeld met hamer, kookpot
aan een driepoot) en elk diorama heeft er nu minstens drie; de check telt
ze uit de data en klikt zes keer snel op een prop (alle zes raak, combo
loopt op). Tik-geluiden staan in SOUND-WISHLIST sectie 11 (`prop_tik`,
`prop_bel`, `prop_glas`, `prop_aambeeld`, `prop_kookpot`, `prop_klop`, ...);
tot die tijd klinken ui_click, haven_score, card_stat_up en impact_armor.

**Eigen geluid per prop, en de combo (nog later die dag).** Max: "iedere
prop moet ook z'n eigen geluidjes hebben met variatie per prop", "de
lijst", en "maak de afspeelgeluidjes leuker: de toon omhoog bij snelheid is
goed, maar bij stoppen van x milliseconden moet ik herstarten of een net
ander geluidje afspelen." Nieuw `tools/maak_prop_geluiden.py`: 39
categorieen, 95 wav's in `sounds/props/` (22 kHz, piek -6 dB), puur
gesynthetiseerd: een FM-bel, glasklink uit hoge partialen, een aambeeld met
onharmonische partialen, een trommelslag met toonval, een sawtooth-hoorn met
vibrato, een kraai uit een blokgolf met ruis en tremolo, een kikker uit een
gepulste toon, een klop-klop, een plons met belletjes, geritsel uit
gepoorte ruis, en zo verder, elk 2-3 varianten met een eigen toon en lengte.
Zelfde naamregel als de losse bestanden (`prop_bel.wav`, `prop_bel_2.wav`),
dus een echte opname op die naam wint. De lijst met wat elk moet klinken:
SOUND-WISHLIST sectie 11. Combo: binnen `tik_pauze` (0,6 s, knop) blijft de
variant gelijk en gaat de toon per klik omhoog; na een pauze herstart de
ladder met een andere variant; elke vijfde klik een chime met "x5!" (en
vanaf tien een hartje). Ook afgesteld: klikpunt en straal uit de omhullende
doos (een brede ruine of steiger is nu op zijn midden raak; de check klikt
in elk diorama op elke prop), en hek, plas en rotsen reageren ook (kraak,
spetters, stof). `-- geluidcheck` ziet alle 39 categorieen met hun varianten.

**De RNG-les (belangrijk).** uispel gaf ineens `d16a14f8` in plaats van
`d9985647`, ook met de herbouw bij de start uitgezet, en een schone
checkout van HEAD gaf wel `d9985647`. De oorzaak: de omgeving trok bij de
herbouw uit de GLOBALE RNG (`randf_range` voor een boomrotatie, stenen van
het vuur, de idle-keuze van een bewoner), en die herbouw zit tussen
`seed(777)` en de auto-opstelling van de mens, die de globale RNG wel
gebruikt. Elk ander aantal trekjes = een andere opstelling = een andere
partij. De referentie `d9985647` van 4.3.5 bevatte dus stiekem het aantal
trekjes van het diorama van 8 september. Nu hebben Omgeving en Bewoner een
eigen `RandomNumberGenerator` (96 + 2 aanroepen omgezet) en is `d16a14f8…`
(246 acties, cyclus 6) de referentie: twee keer gedraaid, gelijk. Regel in
CLAUDE.md: visuele code trekt nooit uit de globale RNG.

**Checks.** `-- omgevingcheck [nr]` bouwt alle twaalf (elk minstens 8
props), eindigt op nr, klikt elke prop en speelt daarna elke reactie van
elke prop een keer: PASS, 39 reacties op 13 props, geen scriptfouten;
`-- dioramashots` (nieuw: alle twaalf op de foto in het menu,
`_shot_diorama_<nr>.png`, contactvel in `results/schaakbord/dioramas.png`);
`-- uispel 777` = `d16a14f8…` (twee keer); `-- herstelcheck 777` PASS;
`-- play`; `-- vosview` PASS. Tracker: 129 regels, 31 placeholders.

## 8 september -- zwevende musket bij figuranten; aura in teamkleur

Max (screenshot): "er gaat toch iets mis met zwevende wapens, met name bij
het blauwe team, base model, na ontkoppeling" en "het zit hem echt bij muis
model_base blauw".

**Diagnose.** `-- zweefcheck` kreeg een `[cyclus]`-argument (speelt door tot
die cyclus, dus voorbij de reset waarin elke pion ontkoppelt en van vecht-
naar basismodel terugwisselt) en meet nu per pion de afstand tussen de
rechterhand-bot en het midden van het wapen (`PawnView.wapen_hand_afstand`,
prop of ingebakken), met team, koppeling, rol en het aantal modelwissels.
Uitkomst: rood en blauw identiek, dus geen teambug. Wat wel opviel: de
figuranten met rol sapper/canteen/drummajor droegen een losse musket op 0,44
van de hand. Oorzaak: de props zijn geleverd als `prop_axe`, `prop_barrel` en
`prop_mace` (props/LEESMIJ.md: sapeur, marketentster, tamboer-majeur), maar
`prop_for` zocht `prop_sapper`, `prop_canteen`, `prop_drummajor`. Geen van de
drie vond ooit zijn prop; de terugval verborg het ingebakken musket en hing
de statische musket-glb (zonder afstelling, dus op zijn bind-positie) in de
hand. Dat is de musket die rechtop naast de pion stond. Blauw viel op omdat
de blauwe figuranten in beeld stonden; rood had hem net zo goed.

**Fix.** `PawnView.PROP_ALIAS` (sapper -> prop_axe, canteen -> prop_barrel,
drummajor -> prop_mace) in `prop_for`, en een vangrail in `_attach_weapon`:
een rol telt alleen als er ook echt een prop ligt, anders houdt de pion zijn
ingebakken musket (de oude terugval naar een losse musket geldt nog alleen
voor modellen zonder ingebakken musket, die hebben er een afstelling voor).
Gemeten (`-- zweefcheck muis 2`, cyclus 2 na de ontkoppel-reset): bijl, vat
en staf op 0,00-0,01 van de hand, hoorn 0,07, musket 0,11, trom 0,12,
vaandelstok 0,35 (zijn lengte); "verder dan 0,25": alleen de twee vaandels.
Screenshot bekeken: elke blauwe basispion houdt zijn musket vast. Voor bijl,
vat en staf staat nog geen afstelling in `model_tuning.json`; ze hangen op
het handbot zelf (dat is de Model-tuner, tab Hand).

**Headless-hang.** De nieuwe screenshot in zweefcheck (en windcheck,
audiopaneel, trainer) deed `get_image().save_png()` op een texture die
headless soms wel bestaat maar geen image geeft; die scriptfout brak de
coroutine af VOOR `quit()` en liet het proces meer dan tien minuten hangen.
Nu overal `get_image() != null` als voorwaarde.

**Aura in teamkleur.** Max: "geef de teams ook hun eigen kleur invloed-area,
dus de drummer een kleur roodish en de vaandel ook maar net verschillend, en
hetzelfde geldt voor blauw." `ROL_KLEUR` is `AURA_KLEUR` per team geworden:
rood = oranjerood (vaandel) / karmijn (trom), blauw = hemelsblauw (vaandel) /
indigo (trom); vaandel is in beide teams de lichte tint, trom de diepe.
`_werk_aura_bij` onthoudt per tegel het team van de drager die de tegel wint
(eigen boven vijand, vijand gedimd zoals eerder), `_maak_aura_rand` kleurt
ermee, de randjes om de extra stat-blokjes en het rol-icoon volgen het team
van de pion (`rol_kleur(rol, owner_id)`), en `render_digest` telt het team
mee in de aura-sleutel.

**Checks.** `-- zweefcheck muis 2` (venster) PASS, screenshot bekeken;
`-- herstelcheck 777`: PASS, 141 momenten, 0 verschillen, canary 0; `-- uispel 777`: d9985647, 272 acties, cyclus 7 (ongewijzigd, de engine is niet geraakt);
testsuite: 2471 groen, 0 rood (761 s). Geen regelwijziging, dus geen goldens.

## 8 september -- de nieuwe regels overal: trainers, zoekers, arena, fuzz

Max: "werk overal de nieuwe spelregels door en in alle trainers en
factiezoekers, alles."

**Wie laadt wat.** Drie bronnen dragen het echte spel: `rules_v42_campaign.json`
(trainer via `-- train`/`train_ai.bat`/TRAINING-NACHT, de nachtrun-matrix
`v42_matrix_l2.json`, fuzz, ijk-sims, `quick_l1`, `v42_check_*`,
factiezoeker en regelzoeker als `BASIS` waar ze kandidaten van afleiden),
`v42_default.json` (los potje, oefenpotje op de loopback en online via
`OnlineBridge.nieuwe_match(_potje_regels())`) en `duel_rules_voor` in
`solo_driver.gd` (campagne-duels, bot en mens). Alle drie hebben `basis_hp`
en `stat_minimum`; de aura- en buitknoppen komen uit `CAMPAIGN_DEFAULTS`,
dus die zaten al overal waar een campagne-blok staat.

**Wat achterliep, nu bij.**
- De zes `duur/rules_pt*.json` (C14-proeven) droegen `basis_hp` maar niet
  `stat_minimum`: toegevoegd.
- `arena/run.gd` legt nu ook `basis_hp` en `stat_minimum` uit
  `rules_v42_campaign.json` over elk regels-bestand dat ze niet draagt
  (dezelfde schakelaar als de facties, `facties_uit_bestand`), en schrijft
  ze in de run-metadata. Bewezen met een proef-config op
  `rules_v42d15_pf15.json` (droeg geen van beide): drie overlay-regels in de
  log, run-metadata `4.3.5` met `basis_hp {cav: 2}` en `stat_minimum {cav:
  {stamina: 2, attack: 2}}`.
- De oude dashboard-trainer (`scripts/training/trainer.gd`, `Trainer.tscn`,
  `-- trainer`) speelde zijn potjes zonder regels (kaal 4.1); hij laadt nu
  `CRules.REGELS_BESTAND` en geeft dat aan beide MatchRunner-paden.
- CLAUDE.md zei nog "train_ai.bat (6 facties, 4.1)"; dat pad geeft sinds 8
  augustus `rules_v42_campaign.json` mee. Tekst rechtgezet.

**Checks.** `--fuzz 40 4242` onder 4.3.5: 0 schendingen (55,7 s). Overlay-proef
hierboven. Dashboard-trainer: een generatie gespeeld op de echte regels, gewichten onaangeraakt; de headless screenshot van `-- trainer` gaf een oude null-fout en is nu afgevangen zoals bij `-- play`. Geen regelwijziging, dus
geen goldens.

## 8 september -- 4.3.5: de trom-bonus is dynamisch, en de ruiter heeft minstens 2/2

Max: "zorg dat als de drummer of vlag verplaatst dat ze dan ook de buff
verliezen als ze erin staan, maar ook kunnen krijgen als ze die nog niet
verbruikt hebben door er in te gaan staan." En: "een bigbro / paard heeft
altijd 2 stamina en 2 attack."

**Trom.** Tot 4.3.4 kreeg een pion zijn +1 stamina bij het koppelen en bleef
dat punt van hem, ook als de trom wegliep. Nu is het een punt dat je een keer
per cyclus mag gebruiken, alleen op het moment dat je in de vorm staat:
- `Rules.trom_bonus` (0 als de pion niet actief is, het punt al gebruikte, of
  niet in de vorm staat), `Rules.stamina_beschikbaar` (eigen voorraad plus
  het punt) en `Rules.besteed_stamina` (eerst de trom, dan de eigen
  voorraad; `bonus_vooraf` omdat een verplaatsing gemeten wordt waar de pion
  VERTREKT). Alle stamina-checks lopen daarlangs: `move_range`, melee,
  charge, schot, kanon-rollen en -schieten, `can_pawn_act`, de validator
  (kanon-acties, actie-opsomming, charges), de bots (bereik, kill-check,
  charge-kosten) en de client (blokjes, HUD, charge-doelen).
- `Pawn.trom_gebruikt` (staat, view, replay, hash; terug naar false bij
  (ont)koppelen). Het link-moment deelt niets meer uit.
- Het vaandel (+1 attack op het moment van slaan) werkte al zo.
- Client: het blauw omrande stamina-blokje is nu het trompunt zolang je er
  recht op hebt; de HUD toont wat je nu kunt uitgeven. Hulptekst
  HELP_COMBAT_LOOT_3 herschreven, vertalingen opnieuw gecompileerd.

**Ruiter.** Nieuwe knop `stat_minimum` (naast `basis_hp` van C12), in
`rules_v42_campaign.json`, `v42_default.json` en `duel_rules_voor` op
`{"cav": {"stamina": 2, "attack": 2}}`; toegepast in `Reducer._do_link` na
kaart en factie-bonussen. Gelezen als ONDERGRENS (een 4-stamina-kaart blijft
4). Max zei "altijd 2", niet "+2" of "vast 2"; als hij een van die twee
bedoelt is het een knop plus een regel in `_do_link`. `RulesConfig.to_dict`
/`from_dict` dragen de knop (view, replay).

**Tests.** SpawnTests: `test_c21_trom_bonus_is_dynamisch` (bereik met bonus,
validator, eruit stappen betaalt eerst de trom, terug erin niets, trom loopt
naar een pion en weer weg, lege voorraad in de vorm handelt nog een keer,
(ont)koppelen reset, roundtrip en hash, knop uit),
`test_c21_trom_bonus_bij_charge_en_kanon` (charge van 3 met 2 stamina,
kanon rolt met 0 eigen stamina via de reducer) en
`test_ruiter_heeft_minstens_2_stamina_en_2_attack` (ondergrens, sterkere
kaart blijft, infanterie niet, zonder knop niet, knop overleeft to_dict).
De oude koppel-test van de trom is vervangen. Engine/bot-groep 1035 groen.

**Metingen.** Testsuite: 2471 groen, 0 rood (698 s parallel). Goldens opnieuw gegenereerd
(versiestring en het nieuwe pionveld zitten in de staat-hash),
`golden_sims.json` opnieuw geijkt (alle vijf schuiven, geen winnaar kantelt; tabel in de CHANGELOG), `-- uispel 777`:
`d9985647…`, 272 acties, cyclus 7 (was `718992dc…`, 238, 6).

## 8 september -- low-poly schaakbord uit Blender

Max, met een foto van een oud houten schaakbord: "kun je in blender een
schaakbord maken in deze stijl alleen dan met weinig faces etc goed voor
performance".

Nieuw `tools/blender_schaakbord.py` (Blender 5.1, headless). Bouwt de plank
als bmesh: een afgeronde rechthoek (4 hoeken x 4 segmenten) met een
kwartrond profiel op de bovenrand (3 segmenten) en een zijwand; bovenkant en
onderkant zijn elk EEN n-gon. Totaal 196 driehoeken, 100 vertices, een
materiaal, tegen 930 driehoeken voor het Tripo-bord dat nu in Board.tscn
staat. Al het hout zit in een textuur van 2048x2048 die het script zelf
rekent met numpy (waarde-ruis met een eigen celmaat per as, zaagtand-ringen
op twee schalen, porien, vuil, spikkels, krassen): elk vak is een eigen
ingelegd stukje met zijn eigen nerfrichting en -dichtheid, het frame is een
verstek-lijst van vier latten, dunne zwarte lijnen tussen de vakken en een
licht biesje om het speelveld. De zijwand en de afronding projecteren dezelfde
textuur van boven naar binnen gevouwen, dus ze bemonsteren het frame-hout
zonder naad; de onderkant is een piepklein stukje frame. Kleuren uit de foto
gepikt.

Uitvoer in `assets/models/board/schaakbord/`: `schaakbord.glb` (60 KB, de
textuur zit er niet in), `schaakbord.png` (de textuur, 2048x2048),
`bron/schaakbord.blend` (93 KB, wijst naar de png). Preview-render (Eevee,
camera als de foto) in `results/schaakbord/schaakbord_preview.png`; daar ook
een 11x11-proef (`--vakken 11`, de maat van het spelbord) als `bord11/`.
Niet in Board.tscn gezet: dat is een keuze voor Max.

Twee valkuilen onderweg, allebei in het script gedocumenteerd: (1) in bpy
wist een toekenning aan `img.colorspace_settings.name` de buffer van een
gegenereerd plaatje, dus na `pixels.foreach_set` nooit meer aanraken (eerste
run leverde een pikzwart bord; nu een canary die de png terugleest); (2) een
.blend in een map die Godot scant breekt de hele import-run zonder
Blender-pad (er kwam ook voor de glb geen .import), vandaar `bron/` met
`.gdignore`, net als "assets/new upload folder/".

**Checks.** `--import` in Godot zonder fouten; laadcheck via een
SceneTree-script: een MeshInstance3D, 196 driehoeken, albedo-textuur
2048x2048; `blender_tel_tris.py` telt ook 196.

**In het spel (zelfde dag).** Max: "Ja importeer maar dan retexture ik
later." Board.tscn instantieert nu `assets/models/board/spelbord/spelbord.glb`
(`--vakken 11 --seed 11 --oorsprong boven`) op (5, 0,05, 5) zonder schaal: de
bovenkant ligt op `PAWN_Y`, net als het oude Tripo-bord (dat stond op
-0,754 + 0,0535 x 15 = 0,049), en het speelveld van 11 vakken valt precies
op de tegelmiddens 0..10. Met het oog op de retexture zit de textuur NIET in
de glb (die is nu 10 KB) maar ernaast als `spelbord.png`, en Board.tscn legt
hem er via een material_override op (roughness 0,55, geen emissie meer; het
oude override had emissie x4,43 om het donkere Tripo-plaatje op te lichten).
Retexture = dat png vervangen, klaar. Godot trok een ingebakken plaatje er
anders als `<glb>_<naam>.png` naast (een tweede kopie van 3 MB in git),
vandaar `--textuur-ingebakken` als optie en los als standaard; de
8x8-schaakversie is ook zo herbouwd en zijn duplicaat is weg. De png-imports
staan op VRAM-compressie + mipmaps, zoals `board_Image_0.png` had. Het
Tripo-bord (`board.glb` in de root, `assets/models/board/board.glb`,
`board_Image_0.png`) wordt nergens meer gebruikt; laten staan tot Max het
weggooit.

**Checks.** Boardcheck (SceneTree-script): bovenkant 0,050, plank van -1,05
tot 11,05 in x en z, override met textuur 2048; `-- uispel 777` = zobrist
`718992dc…`, 238 acties, cyclus 6 (ongewijzigd, het bord is puur visueel);
`-- play` met venster: `_shot_play.png`, pionnen op de vakken, havens gloeien
op de hoeken, raster valt op de lijnen; `-- tunercheck`: 0 fouten, knop bord
laadt Board.tscn met de camera uit.

**Retexture naar een veld (zelfde middag).** Max vroeg een prompt ("het moet
wel lijken alsof men op een veld is"); de truc daarin is een geblokt
maaipatroon zoals op een voetbalveld, zodat de 11x11 leesbaar blijft op
gras. Hij kwam terug met een AI-plaatje (1024, jpeg): "KAN JE DIT GEBRUIKEN
DIRECT?" Bijna: de AI had het speelveld naar binnen en naar boven geschoven
(gemeten 11,5 px in x en 29 px in y, een derde vak onderaan). Nieuw
`tools/bord_raster_fix.py` meet waar het dambord werkelijk ligt (offset en
vakmaat per as, door het dambord-contrast te maximaliseren) en warpt het
plaatje affien op het raster dat de mesh verwacht; na de warp onder 1 px.
Origineel bewaard in `bron/spelbord_veld_origineel.jpeg`, resultaat is de
nieuwe `spelbord.png` (1024, dus lichter dan het houten 2048-plaatje).
Checks: `uv_check.py` 100% (past), `--import`, `-- play`: pionnen en
selectievakken precies op de grasplots.

**Het diorama om het bord (zelfde middag).** Max: "hoe kunnen we het zo
maken dat de rest van het scherm ook een grasachtig landschap is", en: "ik
wil net als bij Hearthstone kleine props om op te klikken als je moet
wachten, en het mag wel een beetje cinematografisch zijn." Nieuw
`scripts/game/omgeving.gd` (`Omgeving`), procedureel gebouwd in
`game._setup_omgeving` als kind van de kijk-pivot (draait met de camera mee,
dus speler 2 ziet hetzelfde kamp vooraan). Lagen: een grondvlak van 160
eenheden op de onderkant van het bord met een naadloze grastegel in het
palet van de bord-retexture plus een grove multiply-laag tegen het
herhaal-effect (`tools/maak_omgeving_texturen.py` schrijft gras.png,
gras_vlekken.png en wolken.png, periodieke ruis, dus zonder rand); een
doorzichtig wolkenschaduw-vlak net boven het gras dat met de wereldwind
meedrijft en onder het bord vanzelf onzichtbaar is; een vignet (ColorRect
met shader, achter de UI); en twaalf props: vooraan het kamp (kampvuur met
vlammen, rook, vonken en flakkerend licht; trommel, ton, hoorn en bijl uit
de gedeelde glb-props; stronk, kanonskogels, twee tenten waarvan een met
een lantaarn), aan de overkant een hek met een kraai, een plas met een
kikker, een wegwijzer en de tent van de tegenstander. Alles behalve de vier
glb's is primitieven in het bord-palet, per stuk te vervangen door een echt
model.

Klikken: `game._unhandled_input` vraagt `Omgeving.klik(schermpositie)` VOOR
de beurt-check, dus ook terwijl je op de tegenstander wacht; het kiest de
dichtstbijzijnde prop binnen 46 schermpixels via unproject (zelfde principe
als `_pick_coord`), en een prop die nog bezig is slikt de klik. Reacties:
vuur laait op met een vonkenregen, trommel stuitert, ton wiebelt, hoorn
wipt, bijl trilt, de bovenste kogel springt van de stapel en rolt terug, de
lantaarn zwaait, de kraai vliegt weg en komt na 16-28 s terug, de kikker
springt de plas over met een kring, de wegwijzer wiebelt. Elke prop zoekt
eerst een eigen geluidscategorie (`prop_vuur`, `prop_trom`, `prop_ton`,
`prop_hoorn`, `prop_bijl`, `prop_kogel`, `prop_lantaarn`, `prop_kraai`,
`prop_kikker`, `prop_wegwijzer`; zet een `prop_<naam>.wav` in sounds/ en hij
klinkt) en valt anders terug op wat er is (val_drum, impact_wood, val_horn,
impact_armor); zie SOUND-WISHLIST.md. Knoppen in het sfeer-paneel:
`omgeving`, `omgeving_licht`, `wolken`, `vignet`, `props`.

Twee dingen die onderweg bleken. De orthografische camera tekent niets
achter zijn eigen positie (het near-vlak), en die stond maar 5 hoog net
voor het bord, dus het kamp viel in een zwarte band weg: `_setup_omgeving`
schuift de camera 40 eenheden langs zijn kijkrichting naar achteren (een
orthografisch beeld verandert daar niet van, `_cam_base` gaat mee). En de
schaal uit een ParticleProcessMaterial kwam niet door (een quad van 1 bleef
1 en het vuur was een witte blok van een eenheid): de maat zit nu in de
quad zelf, scale_min/max zijn alleen nog de spreiding.

**Checks.** Nieuw `-- omgevingcheck` (capture.tscn): bouwt het spel, telt de
lagen en de props, klikt elke prop op zijn eigen schermpositie (moet raak
zijn en de prop bezig maken), klikt het bordmidden (mag niets raken) en
kijkt na 4,5 s of alles behalve de kraai weer vrij is; met venster ook
`_shot_omgeving.png`. PASS (12 props). Verder `-- play` (screenshot met
het kamp onder en de overkant boven het bord), `-- vosview` PASS,
`-- herstelcheck 777` PASS (141 momenten, 0 verschillen) en `-- uispel 777`
= `d9985647…`, 272 acties, cyclus 7: de nieuwe referentie sinds 4.3.5 van
de andere sessie, het diorama rekent niet mee.

**Bewoners: geanimeerde poppetjes (zelfde middag).** Max: "bedenk een manier
dat ik kleine 3d poppetjes kan animeren die dingen doen daaromheen, bijv als
ik een peasant_mouse aanlever die bij hout hakt als je op hem drukt." Nieuw
`scripts/game/bewoner.gd` (`Bewoner`): laadt `<naam>.glb` uit
`assets/models/bewoners/<naam>/`, schaalt op `hoogte` (0,62) met de voeten op
het gras, sorteert de clips met dezelfde woordenlijst als de pionnen (idle is
idle; walk, die, hit, rush, charge doen niet mee; al het onbekende zoals
Chopping is een ACTIE), laat de idles om en om lopen en speelt bij een klik
een actie, met geluid uit het manifest, daarna weer idle. Het factiewoord in
de naam bepaalt waar hij staat: vooraan bij wie die factie speelt, aan de
overkant bij de tegenstander, nergens als niemand haar speelt
(`Omgeving.zet_facties`, uit `game._omgeving_facties` bij `_start_match`, de
online reveal en de herstart vanaf de staat). Manifest `<naam>.json`, alles
optioneel: hoogte, schaal, draai, plek, kant, idle, acties, geluid,
geluid_moment, decor (stronk, houtstapel, kist, vuurtje), model (een glb
elders hergebruiken). `verwerk_levering.py` herkent het woord `bewoners` in
het pad: alleen de karakter-export met clips (geen musket, geen gibs, geen
jassen) naar `assets/models/bewoners/<naam>/`, dan `-- bewonercheck`.
Handleiding: `assets/models/bewoners/LEESMIJ.md`. Voorbeeld zonder eigen
model: `soldaat_mouse.json` zet de muis-infanterist bij een houtstapel
(acties melee en ready).

Een echte valkuil onderweg: uispel crashte 4 s na de start (segfault). Alle
instanties van een glb delen hun AnimationLibrary en Animation-objecten;
PawnView hernoemt daarin de vuile Mixamo-namen zodra de eerste pion van dat
model verschijnt, en de bewoner speelde net "Idle  2" die onder hem
verdween. De bewoner neemt nu een diepe kopie van zijn bibliotheken en
hernoemt zelf op dezelfde manier; `-- bewonercheck` bewaakt dat de kopie los
is (`deelt_clips_met`) en kan een bewoner eerst N seconden idle laten staan
(het wisselpad tussen idles, dat zat anders nergens in).

**Checks.** `-- bewonercheck soldaat_mouse 8` PASS (idle1..3, melee1..2,
ready1, eigen kopie, 8 s idle, actie in 4,0 s weer idle); `-- omgevingcheck`
PASS (bewoners: menu 0, Wolf tegen Muis 1 aan de overkant op z -3,4, als Muis
1 vooraan op z 14,6, klik raak); `-- uispel 777` = `d9985647…`;
`-- herstelcheck 777` PASS; `verwerk_levering.py --droogloop` op een
nep-inbox plaatst `bewoners/peasant_mouse` naast een gewone pion.

**Props per team en de prop-tracker (einde van de middag).** Max: "maak dan
een extra prop tracker, met die scenes, een tent een fakkel, een houtblok een
stuk hout, een bijl, een peasant variatie per team. rood armoede en blauw
pompeus en rijk. Wagon spullen uit die tijd allemaal props die evt relevant
zijn echt een stuk of 100 bedenken." Nieuw `PROP-WISHLIST.md`: tien scenes
(kampvuur en koken, tent en slapen, hout en ambacht, wagen en vervoer,
wapens en uitrusting, eten en drinken, rijk, arm, land en overkant,
bewoners), 110 regels, per prop het team (gedeeld / rood / blauw / beide),
wat een klik doet, de status en een korte text-to-3D-prompt met een vaste
teamstijl (rood: worn, patched, rope and rough wood, rust and mud; blauw:
ornate, gilded, blue cloth with gold trim). `tools/bouw_prop_tracker.py`
bouwt `prop-tracker.html` uit die lijst en de mappen (net als de
geluid-tracker: hij kan niet verouderen), paneelknop "Welke props
ontbreken?" naast de geluidknop. Stand nu: 6 ✓ (de handprops), 1 ½ (de ton,
alleen gedeeld), 12 ⚙ placeholders, 91 ➕.

In het spel hoort daar de teamkant bij: stoel 1 is rood, stoel 2 blauw, en
`Omgeving.zet_facties(eigen, ander, eigen_team)` herbouwt alles onder Props
(kamp, overkant, extra props, bewoners) als team of factie wisselt.
`_glb_prop` kijkt per prop eerst naar `prop_<naam>_<team>.glb`, dan
`prop_<naam>.glb`, en zet die geschaald op zijn ware hoogte (`PROP_HOOGTE`,
of `prop_<naam>.json`) in plaats van de primitieven (tent, hakblok, kogels,
wegwijzer, hek en plas; de kraai en de kikker blijven); `EXTRA_PROPS` geeft
dertig wishlist-props een vaste plek die pas gevuld wordt als hun glb er
ligt. Bewoners met een teamwoord in de naam staan alleen in dat kamp. Omdat
een herbouw de oude props vrijgeeft, hangen de tweens van alle reacties nu
aan hun eigen prop-node in plaats van aan de Omgeving.

**Checks.** `-- omgevingcheck` PASS (herbouw via zet_facties, alle klikken
raak), `-- play`, `-- uispel 777` = `d9985647…`, `-- herstelcheck 777` PASS,
`bouw_prop_tracker.py` bouwt 110 regels in 10 scenes.

## 8 september -- geluidsinstellingen in het menu

Max: "voeg ook audio controllers toe in settings belangrijk."

Er was alleen toets M (alles dempen) en de per-categorie dB in de Model-tuner;
een speler kon nergens het volume zetten. Nu: Instellingen > Geluid met vier
schuiven, alles (schaalt de rest), muziek, effecten en omgeving (de
ambience-laag). Elke verandering is meteen hoorbaar: de muziek- en
ambience-laag krijgen hun nieuwe `volume_db` direct (`Audio.pas_lagen_toe`),
losse effecten pakken het bij het volgende afspelen, en loslaten van een
schuif speelt een proefgeluid. Bewaard in `user://settings.cfg` onder
`[audio]`, naast de taal (`Constants.set_language` schrijft in hetzelfde
bestand; beide laden met "bestaande instellingen behouden").

**Code.** `scripts/core/audio_manager.gd`: `vol_alles`/`vol_muziek`/
`vol_effecten`/`vol_omgeving`, `volume_naar_db` (0 = -80 dB, geen -inf),
`zet_volume`, `volume`, `pas_lagen_toe`, `_laad_volumes` in `_ready`,
`_bewaar_volumes`; de volumes komen bovenop `master_db` en de per-categorie
dB, dus de tuner-afstelling blijft wat hij was. `scripts/game/game.gd`:
`_show_audio_panel` (perkament-paneel in de huisstijl, LabelInkt/KnopBreed,
elke keer opnieuw opgebouwd zodat een taalwissel doorwerkt), optie
MENU_AUDIO in het instellingenmenu. Zes nieuwe strings (MENU_AUDIO*),
vertalingen opnieuw gecompileerd.

**Checks.** Nieuw `tests/AudioTests.gd` (dB-omrekening; zet_volume landt
meteen op de muzieklaag en omgeving raakt de muziek niet; bewaren en
teruglezen, de taal overleeft een volume-opslag, klemmen op 1), geregistreerd
in TestRunner en tests.ps1; schrijft naar een eigen cfg en zet alles terug.
Nieuw `-- audiopaneel` (capture.tscn): bouwt het paneel, zet de vier schuiven
op 25/35/45/55, controleert `Audio.volume`, de muzieklaag (-41,16 dB verwacht
en gemeten) en het cfg-bestand (`settings_check.cfg`, daarna weg); PASS. Met
venster ook `_shot_audiopaneel.png`, bekeken: paneel in de huisstijl.
Testgroep Audio/GameSession/UiAssets: 402 groen.

## 8 september -- wind: alle vlaggen wapperen dezelfde kant op

Max: "voeg 1 windrichting toe, die is random per potje, dan wapperen alle
vlaggen dezelfde kant op ook van de vijand."

Het vaandeldoek hangt als kind onder de vlag-prop, en die hangt aan het
rechterhand-bot van het model. Tot nu stak het doek in de lokale +X van de
prop, dus in de kijkrichting van de pion: rood en blauw kijken tegengesteld
en hun vlaggen wapperden tegen elkaar in.

**Wat er staat.** `PawnView.wind_richting` (statisch, wereld-XZ, lengte 1).
`_hang_vlagdoek` onthoudt de top en de as van de stok in prop-ruimte;
`_richt_vlag` zet het doek per frame (`_process`, alleen bij een doek) zo dat
zijn vrije zijde in wereldruimte met de wind mee wijst: wereldwind naar de
ruimte van de ouder, projecteren op het vlak loodrecht op de stok, en het
doek een basis geven met X = die richting, Y = de stok. Staat de stok plat
(dood, gevallen), dan blijft de vorige stand staan. `game._loot_wind` loot bij
`_start_match` en `_start_vanaf_sessie`: los potje willekeurig, online uit
`hash(OnlineBridge.match_id)` zodat beide stoelen dezelfde wind zien zonder
dat de engine er iets van weet. Geen staat, geen digest.

**Controle.** Nieuw: `-- windcheck [factie]` (capture.tscn, default muis):
opstelling, wind op 0, 90 en 225 graden, per vlagdoek de vrije zijde in
wereldruimte gedeeld door de wind; rood en blauw moeten allebei boven 0,95
zitten, anders FAIL. Met venster ook `_shot_windcheck.png` (overlay en
kaarthand weg). Uitslag: PASS, 0 fouten, dot 1,000 voor beide teams bij alle
drie de hoeken. Screenshots bekeken: beide vlaggen naar linksboven. Testgroep
GameSession/UiAssets/ClientState/View/Agent: 643 groen, 0 rood.

## 8 september -- 4.3.4: een vaandeldrager en een tamboer per leger, tamboer 4 CP

Max: "we doen 1 drummer en 1 flag bearer want het staat te vol en dan 1
drummer is 4 ipv."

`vaandels_max` en `tamboers_max` van 2 naar 1, `buit_tamboer_cp` van 2 naar 4.
Het vaandel blijft 2 punten (aanname: Max noemde alleen de tamboer; met een
tamboer per leger telt hij nu dubbel, zodat de trom zijn gewicht houdt). Alles
leest de knoppen al (opstelling van mens en bot, validator, buit, fitness,
aura-laag), dus de wijziging zit in `CAMPAIGN_DEFAULTS` plus de
terugval-waarden in code die voor de lezer gelijk moeten lopen.
`rules_version` 4.3.3 -> 4.3.4.

**Wat mee moest.** Vier tests legden de oude aantallen vast (dragers-opstelling
van de bot: 2 en 2; tamboer 2 CP in het resultaat; de trainer-invariant
"verloren dragers = (pt + cp) / 2", nu pt / 2 + cp / 4; de fitness-normering,
nu 4 haalbare punten in plaats van 6) en twee de versiestring. De
hulpteksten in `i18n/strings.csv` (HELP_COMBAT_LOOT_1..3, HELP_GAME_SETUP_ROLES)
beschreven nog de 4.3.1-wereld: "een pion zonder kaart draagt", "2 CP",
"bergt zijn vaandel op, geen buit". Nu: een van elk, gekoppeld of niet, 4 CP,
en een regel over de aura. Vertalingen opnieuw gecompileerd (`--import`) en
meegecommit; anders verandert er niets aan wat de speler ziet.

**Metingen.** Testsuite: 2415 groen, 0 rood. Goldens opnieuw gegenereerd,
`golden_sims.json` opnieuw geijkt (alle vijf schuiven, geen winnaar kantelt;
tabel in de CHANGELOG), `-- uispel 777`: `718992dc…`, 238 acties, cyclus 6
(was `c5db0ff3…`, 243, 6 onder 4.3.3).

## 7 september -- C21 op het bord: gloeiende tegelrand en gekleurde blokjesrand

Max: "geef dan een lichte glow om die tegels", en op de eerste versie: "nee
vreselijk, laat alleen omliggende tegels een minimale gloed-rand hebben en dan
ook de extra hp blokjes of stamina ook die zelfde kleur rand."

**Wat er staat (`scripts/game/game.gd`).** Elke tegel in de vorm om een levende
tamboer of vaandeldrager krijgt een dunne gloeiende rand in de kleur van het
rol-icoon (`ROL_KLEUR`: goud = vaandel, blauw = trom). Per tegel een plat
vlakje net boven de tegel (0.056, onder de highlights) met een vierkant
verloop (`GradientTexture2D.FILL_SQUARE`, dezelfde Chebyshev-vorm als
`Rules.aura_bonus`) dat pas bij de buitenste tien procent oplicht; additief,
unshaded. Gelden beide auras op een tegel, dan staat de vaandelrand buiten
(0.98) en de tromrand er net binnen (0.88): naast elkaar in plaats van wit op
elkaar geteld. De vijand zijn vorm is ook zichtbaar (zijn rol staat sinds
4.3.2 in de view en het icoon toont hem al), gedimd (0.6). De laag wordt per
frame uit de staat afgeleid met een sleutel (alleen herbouwen als er iets
verandert), telt mee in `render_digest` ("aura": rol:x,y per tegel) en heeft
een sterkte-knop `aura_gloed` in het sfeer-paneel (toets L, effects_tuning).

De stat-blokjes: elk blokje heeft nu een verborgen `ReferenceRect` als rand.
Stamina-blokjes boven `max_stamina` (dat zijn de punten van de trom, bij het
koppelen geteld) krijgen de blauwe rand; de attack-rij toont
`Rules.effectieve_attack` en de blokjes boven `attack_value` (het vaandel,
zolang de pion in de vorm staat) krijgen de gouden rand. Gedekte vijanden
tonen zoals altijd alleen het vraagteken.

**Wat eraf ging.** De eerste versie was een zacht vlak over de hele vorm
(een groot verloop per drager). Op het bord werd dat een lichte waas, en met
twee dragers naast elkaar bijna wit. Max keurde het af; de rand-versie is
wat hij vroeg.

**Checks.** `-- play` met venster voor de screenshots (headless slaat het
schieten over), `-- herstelcheck 777` en `-- herstelcheck 4242 wolf`
allebei PASS (147 en 114 momenten, 0 verschillen, canary 0); testgroep GameSession/UiAssets/ClientState/
RemoteSession/View: 685 groen, 0 rood. Geen engine-wijziging, dus geen goldens.

## 7 september -- 4.3.3: C21, de tamboer en het vaandel geven een buff

Max: "Bouw ook in als spelregel dat een drummer en een vaandeldrager in een
vorm om zich heen een buff geven. Dus als een model daarin staat heeft ie +1
stamina bij de drum en bij de vaandel +1 atk. Zo dwingen we de spelers om ze
ook echt daadwerkelijk te gebruiken."

**De regel** (spec: `docs/spelregels-v4.2.md` C21, knoppen in het
campagne-blok): de vorm is het blok om de drager, `aura_bereik` vakken in elke
richting, ook diagonaal (default 1 = de acht buurvakken), de drager zelf niet.
Wie **bij het koppelen** in de vorm om een levende eigen tamboer staat krijgt
die cyclus +1 stamina (`aura_tamboer_stamina`; alleen `remaining_stamina`, de
dracht van een kanon groeit niet mee). Wie in de vorm om een levend eigen
vaandel staat slaat en schiet +1 (`aura_vaandel_attack`) zolang hij daar
staat. Niet stapelbaar, gekoppeld of niet, alleen eigen pionnen, 0 = uit.

**Twee keuzes die Max niet hardop maakte, dus hier vastgelegd.**
1. "Een vorm" is het blok van acht geworden: de kleinste vorm die je in een
   oogopslag afleest en waarin diagonaal meetelt. Het is een knop.
2. Stamina bij het koppelen, attack bij het slaan. Stamina is in dit spel een
   cyclusvoorraad die bij het koppelen wordt uitgedeeld (`reset_for_new_cycle`
   ontkoppelt alles, `_do_link` vult); "zolang je ernaast staat" zou per pion
   een extra stukje staat vergen (bonus al gebruikt of niet) dat je aan het
   bord niet kunt volgen. Een aanval is een moment, dus daar geldt wel "zolang
   je er staat". Gevolg voor het spel: waar je je troepen aan het EIND van een
   cyclus laat staan, bepaalt wie er bij het koppelen naast de trom staat.

**Engine.** `Rules.aura_bonus(state, pawn, rol)` en
`Rules.effectieve_attack(state, pawn)`; `_resolve_melee` en `shot_damage`
lezen daar hun schade (melee, charge, infanterie- en kanonschot);
`Reducer._do_link` telt de trom-bonus op de voorraad. `rules_version`
4.3.2 -> 4.3.3 met de overgang in `rules_config.gd`. Geen nieuw stukje staat:
de bonus landt in `remaining_stamina`, en de rol was al zichtbaar in de view
(4.3.2), dus ook de aura van de vijand is af te lezen.

**Bots.** `Rules.effectieve_attack` in `_is_killable` en in `AIHard._quick`
(een vijand met attack 1 naast zijn vaandel is een bedreiging voor 2 HP);
`aura_waarde` (leerbaar, 6) beloont eigen actieve pionnen in een eigen aura,
zero-sum. L1 blijft conservatief op de kaartwaarde.

**Tests.** SpawnTests: `test_c21_vaandel_aura_geeft_attack` (melee, schot,
diagonaal, afstand 2 niet, andermans vaandel niet, trom geeft geen attack,
niet stapelen, gekoppeld wel, dood niet, knop uit, 4.1 niets),
`test_c21_tamboer_aura_geeft_stamina_bij_koppelen` (via de reducer: +1 op de
voorraad, max_stamina niet, buiten de vorm niet, de tamboer zelf niet, de
vijand niet, knop uit) en `test_c21_aura_bereik_is_een_knop`. AITests:
`test_c21_eval_waardeert_pionnen_in_de_aura` en
`test_c21_kill_check_rekent_met_de_aura_attack`.

**Metingen.** Testsuite: 2421 groen, 0 rood. Goldens opnieuw gegenereerd
(`-- makegoldens`: de versiestring zit in de staat-hash). `-- simcheck`:
alle vijf ijk-sims schuiven (777: cyclus 7 -> 12; 101: 18 -> 11; 202: 16 -> 9; 303: 13 -> 14; 404 kantelt van winnaar 2 naar 1 en gaat van 20 naar 8 cycli), tabel in de CHANGELOG, baseline opnieuw geijkt en daarna 0 afwijkingen. `-- uispel 777`: `c5db0ff3…`, 243 acties, cyclus 6 (was `8d6aafaa…`, 231, cyclus 5 onder 4.3.2).

**Nog open (client, niet in deze stap):** de vorm op het bord tekenen bij het
selecteren van of hoveren over een drager, en de +1 in de stat-blokjes tonen.
De stamina-blokjes laten nu gewoon een vol rijtje zien als de voorraad boven
de kaart uitkomt (`HP_COLS` vaste kolommen, dus geen overflow). Dit hoort bij
de sessie die vandaag het rol-icoon bouwde (685d58f).

## 7 september -- de bots jagen op de buit, en de trainer telt het mee

Max: "het moet nu ook wel worden meegenomen in de training run dat de
resources toenemen bij het killen van een drummer of vlagdrager, de ai moet
daar ook op focussen."

**Wat er mis was.** De buit kwam wel in de staat (`Rules._boek_buit` boekt de
2 punten op de reserve en de 2 CP in de pot), maar `AIController.evaluate`
las reserve en pot nergens. Het enige wat de bot van een drager zag was de
jacht-term (`buit_jacht`: een pakbare drager binnen bereik is winst), en die
VIEL WEG zodra de drager dood was. Reken het na met de defaults: een gewone
soldaat naast een drager neerleggen gaf +32 materiaal en liet de jacht-term
(+24) staan; de drager zelf neerleggen gaf +32 materiaal en -24 jacht. De bot
koos dus liever de gewone soldaat. En sinds 4.3.2 betaalt elke drager, maar
de jacht-term telde alleen ongekoppelde standbeelden.

**Wat er nu staat (`scripts/ai/AIController.gd`).**
- `reserve_pt` (20) en `reserve_cp` (10), leerbaar: de waarde van een punt in
  de eigen reserve en een CP in de pot, zero-sum tegen de vijand. In de
  actiefase veranderen die alleen door buit, dus dit is de beloning voor de
  kill zelf. Op een fog-view is het vijandelijke saldo "?" en telt als 0:
  een vaste verschuiving binnen een beslissing, verandert de keuze niet.
- Jacht en hoede zien elke drager, gekoppeld of niet.
- `drager_front` (-1) en `drager_center` (0), leerbaar: waar de bot zijn
  EIGEN dragers zet. Tot nu kregen ze de beste infanterievakken, en met
  `inf_front` 0.6 was dat de voorste rij. Nu default de achterste rij; een
  zachte spreiding (0.25 per buurdrager, kleiner dan een rij verschil) houdt
  ze uit elkaar zonder ooit de rij-voorkeur te overstemmen. De eerste versie
  had een harde "niet naast een andere drager"-regel, en die duwde de vierde
  drager naar de voorste rij.
- `AIHard._quick` sorteert een drager-kill 250 hoger, zodat de beam hem niet
  wegsnoeit voordat de eval (diepte 3-5) hem kan waarderen.

**Trainer (`tools/capture.gd`, `scripts/training/`).**
- `MatchRunner.buit[kant]` telt pt, cp en verloren dragers uit het
  `result`-blok van elk action_applied-event (dezelfde bron als
  ArenaMetrics). Honger-doden tellen niet: geen buit, geen event.
- De campagne-fitness is verhuisd naar `scripts/training/campagne_fitness.gd`
  (`CampagneFitness.score`, testbaar) en krijgt een buit-term van 5%,
  genormeerd op de maximale buit uit de regels (vaandels_max x pt +
  tamboers_max x cp / 2 = 6 punten). De reserve zat al in de spaarbonus,
  maar 2 punten op ~70 startpunten is een derde procent: te weinig om iets
  van te leren. Noemer 1.2 -> 1.25; de relatieve adoptie-gate blijft gelden
  omdat kandidaat en referentie dezelfde schaal delen.
- Het log meldt per kandidaat `buit N pt + M CP, K dragers verloren` en per
  generatie het gemiddelde per potje; `data/matchup_<factie>.txt` krijgt een
  regel over de hele run. Proefrun van 1 minuut (Muis, pop 2, 1 potje):
  2,00 pt + 2,00 CP per potje veroverd, 0,50 eigen dragers verloren. De
  gewichten zijn NIET aangeraakt (geen adoptie in een minuut; het
  matchup-bestand van de proef is teruggedraaid).

Van 38 naar 42 leerbare gewichten; de f0-f5-profielen krijgen de nieuwe
sleutels op hun default bij het laden. Hertrainen doet Max zelf (B13).

**Tests.** 5 nieuwe in AITests (veroverde buit in de eval, gekoppelde drager
telt, greedy kiest de drager boven een gewone soldaat, dragers leerbaar
achteraan, Hard sorteert de drager-kill vooraan) en 3 in V42AgentTests
(MatchRunner telt, in een echte partij klopt verloren = (pt + cp) / 2 van de
ander, fitness beloont buit en is uit als de knoppen uit staan). De
greedy-test moest de wanhoop-modus buiten de deur houden (minder dan 7 eigen
pionnen rent liever naar de haven dan dat hij slaat) en de zetten tot de twee
kills beperken.

**Wat de jagende bots blootlegden: de campagne boekte de buit nooit.** De
eerste volle testrun gaf twee rode in SoloTests
(`test_mens_duel_pauzeert_en_bord_uitslag_boekt`: fase 3 in plaats van KLAAR).
Op een schone HEAD-worktree is die test groen, dus het kwam door de nieuwe
bots. Een sonde met een ruimer vangnet (6000 stappen) liet zien dat de
campagne niet traag was maar MUURVAST stond: fase TESTAMENT, alle duels van
ronde 1 klaar, en ALLE zes spelers met een negatieve pool (-6, -1, -6, -1,
-1, -3). De keten: in een duel groeit de reserve door buit en krimpt hij door
spawns, maar `verwerk_duel_uitslag` gaf de campagne alleen `inzet` (de
gespawnde versterkingen) mee en de reducer boekte die af. Wie zijn buit in
het duel uitgaf, kreeg dus meer afgeboekt dan hij had. Met pool -6 en 1 CP
viel de mens uit met een open testament, en een LEEG testament strandde op
"boven de helft van het bezit" (max_inf = floor(-6 x 0,5) = -3, en 0 > -3).
De test spinde daar 6000 keer op `submit_mens_testament([])` zonder het
resultaat te controleren. Oude bots namen zelden een drager, dus dit lag
sinds C15 stil te wachten.

Gerepareerd op drie plekken: `verwerk_duel_uitslag` berekent de buit
(eindreserve - startreserve + inzetkosten; spawnen is de enige uitgave en
buit de enige inkomst) en zet hem als `buit` op MATCH_RESULT en in het
battlereport; `CReducer._do_match_result` boekt hem als soldaten terug
(ledger-reden `buit`, alleen naast een `inzet`-veld zodat oude logs
byte-identiek folden); `_do_testament` klemt zijn maxima op nul, zodat een
negatieve pool nooit meer een leeg testament blokkeert. Tests: CampaignTests
(buit geboekt, buitenstaander geweigerd, oud pad ongewijzigd, leeg testament
op een negatieve pool gaat door) en SoloTests (van duel-staat naar ledger:
inzet -1, buit +2, battlereport meldt het). Let op: `core/campaign` zit in de
core-hash, dus zodra er een droplet is hoort hier een server-uitrol en een
nieuwe client-build bij.

**Metingen.** Testsuite: 2386 groen, 0 rood (335 s parallel). `-- simcheck`: alle vijf ijk-sims
schuiven (bot-partijen; twee kantelen van winnaar), baseline opnieuw geijkt,
tabel in de CHANGELOG. `-- uispel 777` blijft `8d6aafaa…` (231 acties, cyclus
5, het getal dat 4.3.2 vanmiddag vastlegde): in dat potje komt geen drager
binnen bereik, dus de nieuwe termen kiezen daar niets anders.

## 7 september -- rol-icoon, en twee valkuilen in het testen zelf

Max: "ik koppel, maar dan zie ik wel nog het icoon dat het een drummer is, en de
tegenstander ook toch." Ja. Drie stukken:

- **Het prop verdwijnt bij koppelen** (zoals het was), want een gekoppelde pion
  vecht en hoort zijn musket vast te hebben, geen trom. Mijn eerste poging liet
  het vaandel juist staan; Max corrigeerde dat meteen.
- **`rol_echt` los van `rol_vast`.** Die liepen door hetzelfde veld: `rol_vast`
  pakte eerst `Pawn.rol` en viel anders terug op de cosmetische toewijzing.
  Daardoor was niet te zien welk systeem wat deed. Nu is `rol_echt` de echte rol
  (opstelfase, verhuist nooit, betaalt buit) en `rol_vast` de aankleding (hoorn,
  bijl, vat -- alleen op ongekoppelde pionnen, mag verhuizen).
- **Het icoon** onder de HP-blokjes: vaandel-teken in goud, noot in lichtblauw.
  Tekens en geen texture, want het UI-pack heeft er nog geen; zodra die er zijn
  is het een TextureRect.

**De vijand zien kostte niets.** `rol` zit al in `Pawn.to_dict()` en
`View._pawn_view` redigeert hem niet: alleen hp/stamina/attack worden `"?"` en
de koppeling verdwijnt. Wel fragiel, want niemand had opgeschreven dat dat expres
was -- daar staat nu een test op.

**Twee dingen die ik over het testen zelf leerde, allebei duur betaald:**

1. **`-- suites=ViewTests` bestaat al sinds 30 juli** (Max vroeg er destijds
   zelf om). Ik heb vandaag zes keer de volle batterij van tien minuten gedraaid
   waar zes seconden genoeg was. Gebruik de filter.
2. **Een kapotte test ziet er groen uit.** `assert_eq(2, "?")` vergelijkt int met
   String; GDScript geeft daar geen `false` op maar een RUNTIME-FOUT die de
   testmethode afbreekt, en de runner telt dan niets -- niet geslaagd, niet
   gefaald. Mijn view-test stond zo een tijdje "groen" terwijl hij niets deed.
   Vandaar `str()` om beide kanten. Idee voor later: de runner laten klagen als
   een testmethode nul asserts deed.

De test faalde overigens terecht op een derde punt, maar niet om de reden die ik
dacht: `card_revealed` staat standaard op TRUE (alleen de Krokodil begint
gedekt), dus mijn pion was helemaal niet gedekt en kreeg gewoon de volle
dictionary. Geen fog-lek dus -- een testfout.

**Uispel-contract verschoven.** Seed 777 gaf `890b6cb4...` (270 acties, cyclus 6)
onder 4.3.1 en geeft nu `8d6aafaa...` (231 acties, cyclus 5). Twee keer
gereproduceerd. Onderweg zag ik ook `7f54db25...`: dat was de tussenversie waarin
een gekoppelde drager zijn vaandel HIELD -- een vaandeldrager heeft een andere
idle-clip, en `-- uispel` stuurt de mens via het timeout-pad, dus andere
cliplengtes geven andere beslismomenten. Presentatie kan hier dus wel degelijk
de uitkomst sturen; goed om te weten.

Controles: ViewTests + GameSessionTests + ClientStateTests 252 groen,
`-- naadcheck` PASS, `-- herstelcheck 777` 132 momenten 0 verschillen,
`4242 wolf` 139 momenten 0 verschillen.

## 7 september -- 4.3.2: C15-buit ook op een GEKOPPELDE drager

Max: "als ie gekoppeld is wel of niet maakt niet uit, als je die slaat krijg je
die resources." `Rules._boek_buit` liet de buit vervallen bij
`linked_card_id != -1`; die voorwaarde is eruit.

De redenering achter de oude regel ("gekoppeld = vaandel opgeborgen") hield geen
stand: de rol staat vast vanaf de opstelling en verhuist nooit, maar de KOPPELING
is geheim tot de onthulling. Je wist dus wel wie de drager was en niet of hij
deze ronde iets waard was -- een regel die je aan het bord niet kunt aflezen
stuurt geen enkele beslissing.

`rules_version` 4.3.1 -> **4.3.2**, met de overgang in `rules_config.gd` zodat
oudere configs meeschuiven. CHANGELOG-entry geschreven.

**Wat er omviel, en wat dat betekent.** Eerst 6 fouten: alle vijftien golden
replays op `seq 0` met een hash-mismatch -- dat is de VERSIESTRING in de
staat-hash, niet de buitregel. Opnieuw gegenereerd met `-- makegoldens`.

De baseline in `golden_sims.json` liet de regel wel echt rekenen; vier van de
vijf ijk-sims schuiven en bij een kantelt de winnaar:

| sim | was | wordt |
|---|---|---|
| mens-vos 101 | winner 1, cyclus 19, 475 acties | **winner 2**, cyclus 21, 539 |
| leeuw-beer 202 | cyclus 19, 481 | cyclus 20, 510 |
| beer-muis 303 | cyclus 14, 515 | cyclus 13, 485 |
| wolf-leeuw 404 | cyclus 19, 455 | cyclus 16, 372 |

Dat een enkele seed kantelt zegt niets over balans -- vijf sims zijn daar veel te
weinig voor (vuistregel: onder ~2000 partijen geen uitspraken over een paar
procentpunt). Wie het wil weten draait de nachtrun.

Daarna bleven drie fouten over, en dat waren precies de tests die de OUDE regel
vastlegden. Omgedraaid, met een assertie erbij die eerst impliciet gedekt werd
door de koppel-voorwaarde en anders stilzwijgend was weggevallen: een pion ZONDER
rol levert nooit buit op, gekoppeld of niet. Twee `4.3.1`-asserties in
SpawnTests moesten mee (de tweede zat op een andere plek en zag ik pas na een
tweede ronde).

Eindstand: testsuite 2287 groen, `-- simcheck` 0 afwijkingen.

**Open gevolg, nog niet gefikst:** het BEELD klopt nu niet meer met de regel. Bij
het koppelen wordt `_rol` leeggemaakt (`card == null`-voorwaarde in
`set_character`), dus het vaandel verdwijnt uit de hand terwijl de pion wel 2
punten waard is. Die voorwaarde kwam recht uit de oude regel. Volgende stap:
`rol_echt` (uit `Pawn.rol`, houdt zijn vaandel ook gekoppeld) scheiden van
`rol_vast` (cosmetische aankleding, blijft alleen op ongekoppelde pionnen).

## 7 september -- lijken en gibs worden na een tijdje donker

Max: "kan je ook een soort donkere shader gooien over alle stukjes lijk en gibs,
na x seconden."

Het probleem erachter: alles wat blijft liggen heeft dezelfde felheid als een
LEVENDE pion, en debris verdwijnt pas bij de volgende definieerfase. Na een paar
rondes is het bord een bonte bende waarin je de stukken die er nog toe doen niet
meer terugvindt.

Geen aparte shader nodig: `BaseMaterial3D.albedo_color` VERMENIGVULDIGT met de
texture, dus die van wit naar donkergrijs tweenen dimt het hele stuk -- ook
bovenop de gore-textures die er dan al op liggen. `PawnView.verduister_later()`
doet dat voor het lijk, allebei de gib-wortels en het weggeslingerde wapen (de
bloedvlekken blijven; die zijn al donker en horen bij de grond).

Drie knoppen in `effects_tuning.json`, af te stellen in de Model-tuner tab Gore:
`debris_donker_na` (4 s), `debris_donker_duur` (2,5 s), `debris_donker` (0,7).

**De valkuil zat in het materiaal.** Een glb-materiaal is GEDEELD tussen alle
pionnen met datzelfde model; kleur je dat, dan wordt elke levende muis ook
donker. `verduister_later` dupliceert daarom eerst naar een `material_override`
per instantie. De nieuwe modus `-- debrischeck [factie]` meet precies dat:

    [DEBRIS] instelling: na 4.0 s, verloop 2.5 s, kracht 0.70
    [DEBRIS] lijk : albedo 1.00 -> 0.30 (verwacht ~0.30)
    [DEBRIS] levend: albedo 1.00 -> 1.00 (moet gelijk blijven)
    [DEBRIS] PASS: 0 fout(en)

## 7 september -- kaarten en schermen wachten op de animaties

Max: "speel altijd eerst alle animaties af voordat de nieuwe kaarten of schermen
in beeld komen, altijd", en daarna preciezer: "bij een nieuwe ronde zie je de
versterkingen een voor een op het bord ploppen en pas daarna definieer je de
nieuwe kaarten."

Er stond al EEN zo'n wachtmoment (27 juli): `_open_define_hand` wachtte op de
poef-reveal van verse spawns. Maar alleen daarop -- een sterfte, een naijlende
beweging, een opruk-hold of hitstop liep gewoon door terwijl de kaarten of het
onthul-scherm er al overheen kwamen.

`is_rustig()` (F4.3e, voor de herstelcheck) wist al precies wat "het scherm staat
stil" betekent. Die is gesplitst: `_animaties_bezig()` is het deel dat over
BEWEGING gaat, en daar wachten de kaartwaaier en `_toon_reveal` nu op via
`_wacht_op_animaties()` (vangrail 6 s, want liever een kaart te vroeg dan een
spel dat vastloopt). `is_rustig()` geeft hetzelfde antwoord als eerst, dus de
herstelcheck merkt er niets van.

Bewust NIET meegenomen in `_animaties_bezig()`: `_fase_overgang_bezig` en
`_define_open_bezig`. Dat zijn juist de vlaggen die gezet worden TERWIJL we
wachten; daarop wachten zou zichzelf blokkeren.

**Headless slaat het wachten over.** `-- uispel` liep er minuten langer door en
er kijkt niemand mee. Het wachten is puur presentatie en verandert niets aan de
acties die de engine binnenkrijgt; dat is ook precies wat de uitslag bewijst.
Keerzijde, eerlijk gezegd: de checks toetsen het wachten dus niet -- dat moet in
het echte spel gezien worden.

Regressieset: `-- uispel 777` geeft `890b6cb4...` met 270 acties en cyclus 6
(ongewijzigd), `-- naadcheck` PASS, `-- herstelcheck 777` en `4242 wolf` allebei
0 verschillen en 0 canary.

## 7 september -- tuner: team-keuze, alle modellen naast elkaar, bord-view

Drie wensen van Max in een keer: "alle modellen checken in rood of blauw", "alle
modellen op een rij naast elkaar op het bord om zo de schaal te bepalen", en
"een originele bord view zoals in het spel zelf met alle kleuren en textures".

- **Team-keuze** (`rood vs blauw` / `alles rood` / `alles blauw`). Tot nu toe
  kon je alleen rood TEGENOVER blauw zien, en dan staat de ene jas altijd van je
  af. De keuze werkt door op het losse model, de formatie en de nieuwe
  alle-modellen-opstelling.
- **`alle modellen`**: zes facties in rijen, en per rij VIJFTIEN kolommen --
  infanterie base/spd/hp/atk/mix, dan cavalerie, dan artillerie. Negentig
  pionnen, met een gaatje tussen de type-groepen. Bij `rood vs blauw` krijgt
  elke tweede factie-rij de andere jas.
  **Eerste versie was fout** en Max zag het meteen: die nam het type uit de
  dropdown, dus je kreeg zes facties van EEN type -- en omdat er pas twee
  modellen geleverd zijn viel de rest terug op hetzelfde placeholder-blokje.
  "Zie dan alleen maar dezelfde modellen", en dat klopte. De info-regel zegt nu
  ook expliciet dat een blokje betekent dat dat model nog niet geleverd is.
- **`bord`**: `Board.tscn` eronder, met zijn textures en zijn eigen licht. Twee
  dingen moesten daarbij: de camera van het bord UIT (anders neemt die het beeld
  over van de tuner-camera) en het tuner-licht omlaag naar 0,55 (niet uit, want
  dan valt de voorkant van de modellen weg).
- De camera zoomt in alle-modellen-modus verder uit (17 in plaats van 12,5 op de
  bordhoek), anders vallen de buitenste rijen buiten beeld.

Meevaller bij het bord: het is 11x11 tegels van 1x0,1x1 met de Board-node op
(-5, 0, -5), dus de oorsprong IS de middelste tegel en het tegeloppervlak ligt op
y = 0,05 -- precies de hoogte waarop de tuner zijn pionnen al zet. Geen enkele
verschuiving nodig.

`-- tunercheck` drukt de knoppen nu ook echt in, want alleen "bouwt de scene op"
zegt niets over wat er PAS bij het indrukken gebeurt:

    [TUNER] alle modellen: 30 pionnen op het veld
    [TUNER] alles rood: 30 van de 30 pionnen rood
    [TUNER] bord-view: 1 bord(en), 0 actieve bord-camera(s)

## 7 september -- teamprompts per MODEL in de tracker, ook voor het wapen

Max: "nee het moet juist in de model tracker komen, nee zie ik maar 1 musket
prompt per model bijv." Klopte: de tracker bouwt zijn prompts PER MODEL met
functies, en daar zaten twee gaten.

1. **`const TEAM` droeg nog het schema van 30 juli** (rood = brikrood + goud,
   blauw = navy + zilver, allebei afgesloten met "muted, nothing bright or
   saturated"). Nu draagt elk team ook een `staat`-zin: rood is een veldleger na
   maanden campagne, blauw komt uit het depot. Het goud is naar blauw verhuisd
   (zilver EN goud); rood houdt dof aangeslagen messing.
2. **Per model stond er maar EEN wapen-prompt.** Nu staan er drie: de neutrale
   voor de glb, plus een rood- en blauw-retexture. Zelfde voor de melee-wapens
   van de cavalerie. Nieuwe functie `wapenTeamPrompt()`; die zet er expliciet
   "Ignore its original materials" in, want de wapen-prompt noemt de
   factie-materialen (bij de muis dof donker ijzer en bleek hout) en zonder die
   zin vraag je bij blauw tegelijk om dof ijzer en gepolijst zilver.

Ook opgelost: de model-prompt zegt "Wearing a weathered ... uniform" en bij de
cavalerie "a battered shako". Voor rood versterkt dat de veldstaat, voor blauw
stond er "wearing a weathered, immaculate uniform" -- onzin. Voor blauw worden
die twee woorden er nu uitgehaald.

**Twee keer dezelfde escape-val in een uur.** Een `` in een Python-heredoc
werd een echt BACKSPACE-teken (0x08) in het JavaScript, dus de regex
`/<BS>weathered,\s*/` matchte nooit -- en dat zie je niet aan de uitvoer van
grep. Gevonden door de regel als `repr()` te printen. Eerder vandaag ging het
net zo mis met `
` in `assets
ew 3d models` in paneel.ps1. Regel voor
mezelf: bewerk je een bestand met backslashes via een heredoc, print de regel
daarna als repr en controleer wat er echt staat.

Gecontroleerd door de tracker-functies in node te draaien: JS geldig
(`node --check`), en de zes prompts voor mouse/infantry_mix uitgeprint.

## 7 september -- teamstijl doorgevoerd in ALLE teamjas-prompts

Max: "dit moet dan voor alle prompts team jas textures, de modellen blijven
hetzelfde maar de stijlen zijn duidelijk anders."

Dat viel mee qua werk, want de prompts staan niet per model: `model-tracker.html`
draagt EEN paar teamkleur-prompts (`const TEXTURES`) dat voor elk model geldt.
Daar omgezet, dus alle facties en archetypen tegelijk.

- **Blauw** -- immaculate parade condition, freshly issued from the depot:
  strakke marineblauwe stof met scherpe vouwen, smetteloos wit bandelier,
  spiegelend zilveren knopen MET vergulde gouden epauletten en tressen, nette
  rechte pluim, glanzend geolied leer. "Not a scuff or a stain anywhere."
- **Rood** -- heavily weathered and field-worn after months on campaign:
  verbleekte brikrode jas met stof- en modderplekken, gerafelde manchetten,
  bandelier grijs geworden van het dragen, dof aangeslagen donker messing, een
  slappe gerafelde pluim, gekrast en verkleurd leer. "Nothing polished."
- Twee regels erbij voor de **wapenjas** (`<wapen>_red.png` / `_blue.png`), die
  de engine sinds vandaag ondersteunt.
- In alle vier staat nu expliciet "keep the existing UV layout and geometry
  unchanged", want dat is de enige manier waarop het misgaat.

Wat er veranderde ten opzichte van 30 juli: toen zat het verschil ALLEEN in de
kleur (brikrood met goud tegen marineblauw met zilver) en stond bij allebei
"muted, nothing bright or saturated". Twee gedempte donkere jassen op een klein
bordstuk houd je niet uit elkaar. Nu draagt ook de STAAT van het uniform het
verschil, en verhuist het goud naar blauw: die krijgt zilver en goud, rood
houdt dof messing.

`MODEL-WISHLIST` par. 3-team beschrijft de regel en verwijst voor de tekst naar
de tracker, zodat er niet twee versies gaan rondzwerven. JavaScript van de
tracker gecontroleerd met `node --check`: geldig. `tools/bouw_hoedenlijst.py`
opnieuw gedraaid (2 modellen, beide met hoed).

Terzijde: Max bouwde tijdens dit werk `mouse/infantry_base`, en die is in commit
`f07ed4b` meegegaan zonder dat de commit-tekst hem noemt.

## 7 september -- teamstijl vastgelegd: rood verweerd, blauw gepoetst

Max: "wat ik sowieso wil is dat team rood meer verweerd is in hun uniformen en
stijl, en team blauw is echt ultiem shiny en gold en silver en netjes gepoetst."

Vastgelegd als `MODEL-WISHLIST.md` par. **3-team**, want het geldt voor het lijf
EN het wapen, niet alleen voor de musketten waar het gesprek begon. Rood is een
veldleger dat maanden onderweg is (verbleekte stof, stofvlekken, gerafelde
randen, dof aangeslagen donker ijzer, geschuurd leer, bleek versleten hout);
blauw komt net uit het depot (strakke diepe kleuren, spiegelend zilver en goud,
vergulde knopen en epauletten, smetteloos wit leer, donker gelakt hout).

Waarom dit beter werkt dan rood-tegen-blauw verf: de modellen dragen al
donkergrijze uniformen, en twee tinten grijs uit elkaar houden op een klein
bordstuk lukt niet. Versleten tegen glimmend leest wel, ook in een oogopslag.

Met retexture-toevoegingen per team voor het lijf en voor het wapen, plus de
waarschuwing die me eerder opviel: laat de materiaal-zin uit de oorspronkelijke
model-prompt WEG in een retexture-prompt, anders vraag je dof donker ijzer en
gepolijst zilver tegelijk en kiest de dienst er zelf een.

## 7 september -- teamjas voor het WAPEN (weapon/red en weapon/blue)

Max: "ik heb nu ook de folder weapon met daarin ook weer red en blue, dus iedere
factie heeft een iets ander stijl wapen texture. kan je die bij de model upload
ook meenemen met het paneel."

Dat kon de engine nog niet. Het lijf kreeg de team-png als albedo-override en
bij het wapen werd die override er JUIST afgehaald -- de team-png van het lijf
over een musket-atlas is een bonte vlek. Nu:

- `PawnView.weapon_team_texture(<wapen-glb>, team)` zoekt
  `<wapen>_red.png` / `_blue.png` naast de wapen-glb.
- `_zet_wapenjas()` legt hem op elk ingebakken wapen; is er geen, dan gaat de
  override eraf en houdt het wapen zijn glb-atlas (oud gedrag, niets breekt).
- `apply_albedo_to_mesh()` erbij, want `find_children()` slaat de root zelf over
  en je kunt dus geen texture op een losse mesh zetten met `apply_albedo_to`.
- Het weggeslingerde wapen bij de dood hoeft niets: `_los_wapen_voor_worp`
  koppelt de ECHTE wapen-node los, met de override die er dan al op zit.

**Valkuil die me een ronde kostte:** `_apply_team_texture()` draait aan het eind
van `_swap_piece()`, en `_attach_weapon()` komt pas DAARNA -- daar wordt
`_baked_prop_pad` gezet. Bij het opbouwen was het wapenpad dus nog leeg, vond hij
geen jas, en haalde hij de override eraf. `-- wapenroute` liet dat zien
("staat op 0/1 wapen-mesh(es) !! NIET TOEGEPAST"); `_attach_weapon` roept
`_zet_wapenjas()` nu nog een keer aan zodra het pad bekend is. Daarna 1/1.

De leveringsknop pakt de map op: `weapon`/`wapen` in het pad betekent wapenjas.
Die wordt tegen de WAPEN-glb gemeten en niet tegen het model, want de wapen-glb
draagt maar een atlas -- meten tegen het model zou de wapen-atlas als "beste
materiaal" opleveren en dus alsnog slagen. Uitslag op de muis:

    OK   mouse/infantry_mix: jas blue erin (98.8% dekking)
    OK   mouse/infantry_mix: jas red erin (98.7% dekking)
    OK   mouse/infantry_mix: wapenjas blue erin (100.0% dekking)
    OK   mouse/infantry_mix: wapenjas red erin (100.0% dekking)

Nog niet gedaan: de PROP-route (modellen zonder meebewegend wapen) krijgt geen
wapenjas. Dat is de terugval en raakt nu geen enkel model.

## 7 september -- tunerpaneel sleepbaar; een vast schermaandeel was ook fout

Max stuurde een schermafdruk van zijn venster: **1080x1920, staand.** Mijn
"gebruik meer van het scherm"-oplossing (paneel op 56% van de schermhoogte)
werd daar ruim 1000 px en er bleef van het model een streepje over. Een vast
AANDEEL is dus net zo fout als de 430 vaste pixels die het verving, alleen de
andere kant op. Les: schermverhoudingen zijn geen constante, en een tuner wordt
op een staand venster gebruikt.

Zijn vraag: "maak dit interactief dat ik het naar boven of beneden kan sliden."

- Het paneel hangt nu aan de ONDERKANT met een hoogte in pixels
  (`offset_top = -hoogte`), standaard 300.
- Bovenop zit een sleepgreep van 12 px met een verticale-sleep-cursor. Omhoog
  slepen maakt het paneel groter, omlaag kleiner. Begrensd op 130 px en 85% van
  het scherm, zodat er altijd model zichtbaar blijft.
- Dubbelklik op de greep wisselt tussen compact (150) en ruim (300).
- De gekozen hoogte wordt onthouden in `user://tuner_ui.cfg`. Bewust NIET in
  `model_tuning.json`: dat is speldata die de engine leest, daar hoort geen
  vensterstand in.

`-- tunercheck` meet nu de hoogte in pixels in plaats van het aandeel, en
controleert dat de sleepgreep bestaat:

    [TUNER] paneel 300 px hoog van 1920 (16%), sleepbaar
    [TUNER] tabs: 7, waarvan scrollbaar 7

## 7 september -- Model-tuner: kleiner, breder, en niets valt meer weg

Max: "fix de tuner ui zorg dat alles past gewoon simpele stijl ui buttons en
gebruik meer van het scherm. kleinere fonts etc."

Vier dingen zaten fout, en ze versterkten elkaar:

- **Het paneel was 430 vaste pixels hoog.** Op een groot scherm bleef de rest
  ongebruikt, terwijl de rijen er tegelijk uitliepen. Nu op ANKERS
  (`anchor_top = 0.44`), dus het pakt 56% van de schermhoogte en schaalt mee
  zonder resize-afhandeling.
- **De tabs konden niet scrollen.** Wat niet paste was gewoon weg: geen balk,
  geen melding. Alle zeven tabs zitten nu in een ScrollContainer.
- **Sliders hadden een vaste breedte** (280 en 200 px) en duwden bij een smal
  venster de spinboxes buiten beeld. Nu `SIZE_EXPAND_FILL` met een klein
  minimum, dus ze krimpen mee.
- **Alles op de standaardlettergrootte.** Nieuw `_tuner_thema()`: 12 punt over
  de hele linie, vlakke knoppen met een dunne rand en 3 px hoeken, op het paneel
  gezet zodat alles eronder het erft in plaats van een override per widget.

`-- tunercheck` bewaakt het nu ook: het meldt hoeveel schermhoogte het paneel
pakt (FOUT onder de 40%) en of elke tab kan scrollen (FOUT zodra er een niet
kan). Zo hoeft de tuner niet met de hand geopend te worden om te zien dat er
iets afgekapt raakt:

    [TUNER] paneel pakt 56% van de schermhoogte
    [TUNER] tabs: 7, waarvan scrollbaar 7 (Model, In de hand, Geluid, Melee, Gore, Bloed, Rook)

## 7 september -- het scheve musket: de bot-kind-fix deéd het

Max, met een schermafdruk: "het wapen blijft gedraaid en niet goed hoe kan dat
nou." De plaats klopte, de bajonet wees omlaag.

`-- wapenroute` had al bewezen dat het spel de INGEBAKKEN route neemt en geen
afstelling toepast, dus de scheefstand moest uit de export komen. Gemeten door
dezelfde blend te exporteren en de wapen-node te lezen VOOR en NA
`blender_botkind_fix.fix_glb`:

| | translation | rotatie (euler) |
|---|---|---|
| exporter | [3.4617, 17.7872, 0.6005] | [-38.6, 80.5, -39.5] |
| na fix_glb | [3.4617, 17.7872, 0.6005] | **[-128.6, 80.5, -39.5]** |

Zelfde beeld op `mouse_cavalry_atk` (144,4 -> 54,4). De translatie is in beide
bestanden AL identiek -- de fix corrigeerde daar dus niets -- en de rotatie
wordt precies 90 graden om X gekanteld.

Oorzaak: `_bot_relatief` rekent in Blender's BOT-ruimte (+Y langs het bot) en
schreef die matrix ongecorrigeerd als glTF-node-rotatie weg. De joint-ruimte van
glTF staat daar 90 graden om X naast. De bevinding van 3 september ging over de
TRANSLATIE (Y kreeg de botlengte gedeeld door de armature-schaal erbij); het
meeschrijven van rotatie en schaal was meegenomen zonder dat iemand het mat.

`fix_glb` schrijft nu alleen nog de translatie, en alleen als die echt afwijkt
(anders logt hij "staat goed"). Rotatie en schaal blijven van de exporter. Na
een herbouw draagt de node weer euler [-38.6, 80.5, -39.5]. wapencheck
beweegt-mee=true, zweefcheck PASS, tunercheck 0 fouten.

Les: schrijf nooit een Blender-bot-matrix rechtstreeks in een glTF-node zonder
de bot-as-conversie. En: een "fix" die meer overschrijft dan het gemeten
probleem is zelf een bug in de wacht.

## 7 september -- model_tuning.json leeggemaakt, met een vangrail erbij

Max: "doe dan ook alle opties voor model tuning opnieuw, want dat zit nu in de
weg." Klopte. `model_tuning.json` droeg nog twaalf sleutels van de oude
lichting, en die werken WEL door: `_auto_fit_model` doet `root.scale *= extra`,
dus de verse mix-muis liep op schaal 1,11 (later 1,2) met een `muzzle` van een
mesh die niet meer bestaat.

- **Verwijderd (12):** alle `lion/*` en `mouse/*`, inclusief de
  `_musket`-sleutels en `mouse/musket`.
- **Gehouden (3):** `props/prop_drum`, `props/prop_horn`, `props/prop_pole` --
  die modellen zijn niet vervangen en hun afstelling klopt nog.
- Max' niet-gecommitte afstelwerk (lion 1,29 en 1,28, mouse/infantry_mix naar
  1,2 met y 0,01) is EERST apart vastgelegd in `5ef1432`, zodat de reset niets
  weggooit dat niet terug te halen is.

Na de reset meldt `-- wapenroute` netjes "geen afstelling" en `-- tunercheck`
doet 3 sleutels byte-identiek heen en terug.

**Vangrail tegen herhaling.** `verwerk_levering.py` waarschuwt nu bij een
HERBOUW als er al afstelling onder die naam ligt:

    LET OP mouse/infantry_mix: er ligt nog afstelling onder
    'mouse/infantry_mix' van het VORIGE model. Zet hem opnieuw in de Model-tuner.

Alleen melden, niet weggooien -- het is Max' werk, en soms is de mesh wel
degelijk dezelfde. `oude_afstelling()` kijkt naar de modelsleutel en de
wapensleutel (`_musket` voor infanterie, `_melee` voor cavalerie); los getest op
een schone en een vervuilde tuning.

## 7 september -- retexture-exports naast de .blend in plaats van in results/

Max: "doe dan niet de map results als folder maar upload de glbs gewoon in de
folder". Terecht: `results/` is gitignored werkmateriaal, en zo staat alles van
een model uit elkaar. `maak_retexture.py` schrijft nu standaard naast de .blend
zelf; `--uit <map>` overschrijft dat nog steeds. De paneelknop opent daarna de
map die Max zelf koos, niet meer `results/retexture`.

Zo houdt een modelmap alles bij elkaar:

    mouse/infantry_mix/       infantry_mix_mouse.blend
                              mouse_infantry_mix.glb        (upload: het lijf)
                              mouse_infantry_mix_wapen.glb  (upload: het wapen)
    mouse/infantry_mix/red/   de png die terugkomt
    mouse/infantry_mix/blue/  idem

`verwerk_levering.py` kijkt alleen naar `.blend` en `.png`, dus die twee exports
liggen hem niet in de weg.

Bij het bewerken van de meldtekst overschreef ik de afsluitregel van de
MessageBox (`"Fog of War") | Out-Null`) -- regels invoegen EN vervangen in een
lijst tegelijk verschuift de indexen onder je handen. Hersteld en opnieuw
geparseerd.

## 7 september -- wapen-route bewezen, wapen apart exporteren, hele ledemaat af

Max zag het musket scheef hangen: "nu is het wapen toch nog vreemd en niet
gealigend. het wapen is geanimeerd ook in de hoofdblend file, dus dat moet
eigenlijk de main zijn, behalve als het poppetje sterft dan spawn je een los
wapen net als de gibs."

**Dat gebeurt al, en dat is nu meetbaar.** Nieuwe modus `-- wapenroute [factie]`
in capture.gd bouwt PawnViews zoals de Model-tuner (NIET via een partij: daar
verschijnen alleen archetypen waarvoor een model bestaat, en op een halflege
assets-map zie je dan niets -- eerste poging gaf 40 pionnen zonder model).
Uitslag voor de muis:

    [WAPEN] infantry mix INGEBAKKEN sleutel=mouse/infantry_mix_musket
            pos=[0.05, 0.19, 0.05] rot=[75.0, -105.0, -160.0] scale=1.55
            (NIET gebruikt op deze route)

Dus: het spel gebruikt het geskinde wapen uit de .blend, bot-geparent aan de
rechterhand, en past GEEN afstelling toe. De verdenking dat de verweesde
`mouse/infantry_mix_musket`-tuning het wapen scheeftrok is daarmee weerlegd. Wat
Max ziet is de plaatsing uit zijn eigen blend, of een restje van de Blender
5.1-bot-kind-bug die de export corrigeert. Volgende meting als hij dat wil: het
wapen t.o.v. de handbot in de .blend naast dezelfde meting in de glb.

**Wapen apart voor een retexture** (Max: "dan kan ik ook het wapen een retexture
geven"). `maak_retexture.py` levert nu per model twee bestanden: `<naam>.glb`
(lijf) en `<naam>_wapen.glb` (alleen het wapen, via `blender_export_musket.py`,
het script dat de pijplijn er toch al voor gebruikt). Op infantry_mix: 1235 en
891 driehoeken. `--geen-wapen` slaat het over. Lijf en wapen hebben elk hun
eigen UV-atlas, dus ze kunnen los.

**Een ledemaat vliegt er nu als GEHEEL af** (Max: "een been of arm bestaan uit 2
delen soms, dan moeten die beide eraf vliegen"). De oorzaak was erger dan half
werk: de zoeksleutel `arml` zit ook in `forarml` en `legl` ook in `uplegl`, en
zowel `_shed_one` als `_fling_single_gib` pakte de EERSTE match en stopte.
Gevolg: er vloog een van de twee segmenten weg, welk hing af van de
scene-volgorde, en de levende kant kon `Arm.L` verbergen terwijl de gib-kant
`Forarm.L` wegslingerde -- gat op de ene plek, brokstuk van de andere.

Nu verzamelt `_shed_one` alle zichtbare delen van het ledemaat en
`_fling_limb_gibs` (hernoemd) slingert ze allemaal weg. De wond-plek voor de
bloedspuit is het segment dat het DICHTST bij de romp zat, geometrisch bepaald:
uit de naam raden kan niet, want bij deze modellen is `Leg` het onderbeen en
`Upleg` het bovenbeen.

Controles: testsuite 2282 groen / 0 rood, `_gibcheck` PASS (11 delen in de
mix-gibs), `-- simcheck` 0 afwijkingen.

## 7 september -- leveringsindeling factie/model/kleur, inbox-knoppen eruit

Max: "factie -> model -> en dan twee mapjes met kleur zodat je in 1x beide teams
kan uploaden is dat goed?" Ja, en het is beter dan wat hij eerst deed
(`mouse/red/infantry_mix`): de .blend staat er nu een keer in plaats van per
team, dus een ronde bouwt het model en zet er twee jassen op.

    mouse/infantry_mix/            infantry_mix_mouse.blend
    mouse/infantry_mix/blue/       ...-color.png
    mouse/infantry_mix/red/        ...-color.png

`verwerk_levering.py` liep hier meteen op, zonder aanpassing: `os.walk` levert de
ouder voor de kinderen, dus de blend-post bouwt het model en de twee kleurposten
leggen daarna hun jas erop. Uitslag: model gebouwd, blauw 98,8%, rood 98,7%,
wapencheck beweegt-mee=true, zweefcheck PASS, tunercheck 0 fouten.

De map met alleen een .blend en geen png geeft geen "team onbekend"-waarschuwing
meer -- die staat alleen bij een map die wel jassen draagt.

**Paneelknoppen "Inbox: eerst kijken" en "Inbox: alles bouwen" verwijderd**
(Max: "die gebruik ik toch niet"). Het kader "Modellen bouwen" houdt twee
knoppen over en krimpt van 162 naar 122; de noodrem van y=864 naar 824 en het
venster van 1008 naar 968. Kaders eindigen op 910 in een clienthoogte van 929,
dezelfde onderrand als altijd, geen overlap.

`tools/bouw_modellen.py` blijft WEL bestaan: `verwerk_levering.py` leent er
`plaats_uit_woorden()`, `stappen()` en `woorden()` uit, en voor de bulk-inbox
van dertig blends is het nog steeds het juiste gereedschap. Alleen niet meer
vanaf een knop.

## 7 september -- de knop doet nu ook de controles, en onthoudt je map

Max' test slaagde ("OK model gebouwd / OK jas red erin (98.7% dekking)") en
daarna twee terechte opmerkingen: "moet ik dit nu doen?" over de vier
Godot-commando's die eronder stonden, en "het paneel moet dat dan ook doen he".

**Controles zitten nu in `verwerk_levering.py`.** Na het bouwen draait hij zelf
`--import`, `_wapencheck.gd`, `zweefcheck` per geraakte factie en `tunercheck`,
en vat de uitslag samen. `--geen-controles` slaat het over, `--godot <pad>` of
`GODOT_PATH` wijst de binary aan; ontbreekt Godot, dan slaat hij de ronde over
met een nette melding in plaats van te struikelen.

Alleen de regels die over DIT werk gaan komen in beeld. Op een halflege
assets-map meldt wapencheck anders tientallen "GEEN MODEL" voor alles wat nog
niet geleverd is, en dat zegt niets over wat je net bouwde. Uitvoer nu:

```
Controleren:
  importeren...
  wapen  mouse/infantry_mix: tripo_node_356d7a7b... beweegt-mee=true texture=true
  zweef  mouse: meshes zichtbaar=65, meer dan 2 van hun pion: 0 (PASS)
  tuner  1 modellen gevonden, 29 nog niet geleverd -- 0 fout(en)

Alles klopt. Open de Model-tuner in het hoofdmenu voor schaal en hoogte;
dat is het enige wat nog met de hand moet.
```

**Mapkiezer onthoudt waar je was.** Max: "kan je dan in het paneel de new upload
folder als standaard pad openen dat ik niet zoveel hoef te klikken." Beide
kiezers (levering en retexture) beginnen nu bij de map die je het laatst koos
(`results/laatste_map.txt`), anders bij `assets/new upload folder`, anders bij
`assets`. Verdwijnt de onthouden map, dan valt hij netjes terug. Alle drie de
takken getest.

## 7 september -- team-herkenning stuk als je de modelmap zelf aanwijst

Max: "hij zegt team onbekend terwijl hij zit in folder red." Klopte. `team_uit`
las het pad RELATIEF aan de map die je in de kiezer aanwijst, en Max wijst de
modelmap zelf aan. Dan is het relatieve pad "." en staat `red` een niveau
HOGER dan wat hij koos: nul woorden om in te zoeken.

Opgelost met `padwoorden()`: lees de laatste zes mapniveaus van het VOLLEDIGE
pad, niet het stukje onder de gekozen map. Zes is genoeg voor
`... / mouse / red / infantry_mix` en te weinig om de projectmap zelf te laten
meepraten. Zowel het team als de plaatsing (factie/type/archetype) gaan nu door
dezelfde woordenlijst; `bouw_modellen.plaats()` is opgesplitst in
`plaats_uit_woorden()` zodat beide scripts er dezelfde regels op nahouden.

Meteen de type-aliassen uitgebreid voor Max' aangekondigde mapstructuur
(`mouse/blue/cav`, `mouse/red/cannon`): `cav` -> cavalry, `cannon` en `kanon`
-> artillery, `inf` -> infantry, `art` -> artillery.

Gemeten op zijn structuur:

| map die je aanwijst | team | plaatsing |
|---|---|---|
| mouse/red/infantry_mix | red | mouse/infantry/infantry_mix.glb |
| mouse/blue/cav/cavalry_atk | blue | mouse/cavalry/cavalry_atk.glb |
| mouse/red/cannon/artillery_base | red | mouse/artillery/artillery_base.glb |
| wolf/blue/inf/infantry_spd | blue | wolf/infantry/infantry_spd.glb |
| mouse/blue/cav (zonder archetype) | blue | geweigerd, archetype ontbreekt |

Echte run vanaf de diepe map: model gebouwd, jas erin op 98,7%, wapencheck
"beweegt-mee=true texture=true", zweefcheck PASS, tunercheck 0 fouten.

**Wat NIET kan: de team-mapstructuur doortrekken naar assets/models.** Max
vroeg of het daar ook `mouse/red/...` mag worden. Dat breekt de teamjassen:
`PawnView.team_texture()` zoekt `<model>_red.png` NAAST de glb (op pad, niet via
`Bestandsindex`), dus de glb en BEIDE jassen moeten in dezelfde map liggen. Een
glb kan niet tegelijk in `mouse/red/` en `mouse/blue/` staan, en hij is ook
team-neutraal: alleen de jas verschilt. Daarom blijft de doelkant
`assets/models/<factie>/<type>/` met `<model>_red.png` en `<model>_blue.png`
ernaast. De LEVERING mag wel de teamstructuur hebben -- daar wordt hij juist
uit gelezen.

## 7 september -- een hele levering met een knop het spel in

Max: "maak dus een knop in paneel ook dat als in de folder dus de blend met
animaties heb en de glb eruit gedestilleerd en de nieuwe textures dat alles dan
geupload kan worden in de assets map." Dus niet bouwen en jassen apart, maar een
map ineens.

**`tools/verwerk_levering.py <map>`.** Per submap met een .blend en/of een
kleur-png: factie/type/archetype uit de mapnamen (`plaats()` uit
`bouw_modellen.py`), het TEAM uit red/rood of blue/blauw in het pad. Dan de drie
Blender-stappen, en daarna de jas met `uv_check` tegen de NET GEBOUWDE glb
gemeten. Onder de 90% dekking gaat hij er niet in en staat er waarom. Een map
met alleen texturen mag ook: dan wordt alleen de jas gewisseld op een model dat
er al staat. Normal-maps nooit -- de engine zet alleen een albedo-override.

Beide takken bewezen:
- `assets/new upload folder` -> model gebouwd, jas erin op 98,7% dekking.
- Kladlevering met de kapotte cavalry_mix-jas -> `GEWEIGERD ... dekt maar 75,2%
  van de UV's (op 'Material')`, exitcode 1, terwijl de goede base-jas in
  dezelfde run gewoon op 99,8% naar binnen ging.

**Paneel: kader "Modellen bouwen" is nu een 2x2.** Boven de losse levering:
"Map in het spel zetten" en "Model klaarmaken voor retexture". Onder de bulk:
"Inbox: eerst kijken" en "Inbox: alles bouwen". Hoogte ongewijzigd (162), geen
overlap, clienthoogte 969. De hoofdknop draait eerst de droogloop (geen Blender,
dus meteen klaar), toont die in een venster met Ja/Nee, en pas daarna het echte
werk in een venster met `-NoExit`.

Twee PowerShell-valkuilen, allebei kostbaar:
- **Bouw de opdrachtregel EERST in een variabele.** Inline samenplakken binnen
  de `@()`-lijst van `-ArgumentList` gaat mis bij een pad met spaties: het pad
  komt er met een spatie ervoor uit ("Dat is geen map:  C:\..."). De
  retexture-knop deed het al via een variabele en werkte daarom wel.
- **Een `@`-teken als plaatsvervanger voor een backslash gebruiken en dan
  globaal vervangen sloopt `@(`.** Vier PowerShell-array-literals werden
  `@(` -> `<bs>(`. Regelgebaseerd bewerken is hier veiliger dan zoek-en-vervang
  met escapes, want de tool-laag eet ook nog een backslash-niveau op.

## 7 september -- gemeten: de teamjassen overleven de nieuwe lichting (op een na)

Max: "moet ik nu opnieuw retextureren of gaat het goed?" Op 6 en 7 september
stond hier de verwachting dat nieuwe blends nieuwe UV's zouden geven en dat
alle twintig jassen opnieuw door Tripo moesten. **Dat klopt niet.** Nu gemeten
met `uv_check.py`, en de uitkomst is bijna overal goed.

De vijf muis-cavalerie-modellen opnieuw gebouwd uit `assets/new 3d models/Mouse`
(naar een kladmap, niet in assets/models) en de tien jassen uit `d5c87d7`
ertegenaan gehouden:

| jas | dekking | oordeel |
|---|---|---|
| cavalry_base rood+blauw | 99,8% | past |
| cavalry_spd rood+blauw | 99,8% | past |
| cavalry_hp rood+blauw | 99,8% | past |
| cavalry_atk rood+blauw | 99,9% | past |
| **cavalry_mix rood+blauw** | **75,2%** | **past nergens op** |
| infantry_mix rood+blauw | 98,8% | past |

**cavalry_mix is de enige echte fout, en hij is gratis te repareren.** Die twee
jassen (bake `5d8cfcce`) passen op GEEN van de vijf cavalerie-modellen: hun beste
score is 75,2% en dan nog op het vlakke `Material`, niet op een lijf. Ze horen
bij een mesh die niet in het spel zit. Op 6 september viel al op dat die uuid
bij geen enkel model hoorde; de conclusie daar ("een uuid die bij geen bestaand
model hoort is gewoon een nieuwe bake en gaat er wel in") was FOUT.

Nieuwe retexture is er niet voor nodig: **cavalry_mix draagt hetzelfde lijf als
cavalry_base** (beide `tripo_material_ed40c828`), en `cavalry_base_red.png` /
`_blue.png` scoren 99,8% op cavalry_mix. Als de cavalerie terugkomt, krijgt
cavalry_mix dus gewoon de base-jas -- precies zoals het vóór 6 september al was.

Reden dat de jassen het overleven: de nieuwe blends dragen **dezelfde meshes**
(zelfde `tripo_material_<uuid>`), alleen beter gerigd en met wapen. Een jas
sneuvelt pas als het lijf zelf opnieuw uitgevouwen wordt.

Nog niet te meten: mouse infantry base/spd/hp/atk. Die .blends zijn nog niet
geleverd; zodra ze er zijn is het een enkele `uv_check.py` per stuk.

## 7 september -- eerste model van de nieuwe lichting + twee nieuwe controles

Max zette een complete levering neer in `assets/new upload folder/mouse/red/
infantry_mix/`: een .blend plus de rode mix-jas. Vraag: hoe testen we of het
werkt, en hoe vis ik zo'n model uit Blender om er een retexture op te laten
maken?

**De keten draait, van .blend tot in het spel.**
`python tools/bouw_modellen.py --inbox "assets/new upload folder"` bouwde
mouse/infantry_mix in 18 s (glb + gibs + musket). Daarna: `_wapencheck.gd`
"beweegt-mee=true texture=true", `-- zweefcheck mouse` PASS (65 meshes, 0 los),
`-- tunercheck` vindt hem, gibs compleet, 0 fouten. Rode jas erop als
`infantry_mix_red.png` met size_limit 1024. Nieuwe inbox heeft `.gdignore` en
staat in `.gitignore`, net als de andere twee.

**Nieuw: `tools/uv_check.py` -- past deze teamjas op dit model?** Dit ontbrak
en het is de enige harde meting. Hij pakt de glb zelf uit (alleen numpy en
Pillow), leest TEXCOORD_0 en de indices, tekent elke UV-driehoek barycentrisch
in een 512-masker, en meet hoeveel van dat gebied in de png beschilderd is.
Gemeten op infantry_mix: de juiste jassen 98,8%, jassen van een ander model
70-75%. Een gat waar je niet naast kunt kijken.

Twee dingen die eerst FOUT gingen en waarom het nu klopt:
- **Per materiaal meten, niet in totaal.** Een spel-glb draagt twee atlassen:
  het lijf (`tripo_material_<uuid>`) en het ingebakken wapen. Die UV-vlakken
  liggen over elkaar, samen 84,6% van de atlas -- dan meet je niets meer en
  scoorde alles 63-73%. Apart: lijf 62,4%, wapen 59,4%.
- **"Beschilderd" is alfa, geen kleur.** De eerste versie noemde bijna-zwarte
  texels onbeschilderd, en juist de nieuwe blauwe jassen zijn bijna zwart:
  `infantry_mix_blue` zakte daardoor naar 86,8% terwijl hij perfect past. Nu
  telt alfa, met kleur als terugval voor oude platte PNG's zonder alfakanaal
  (die hebben overal alfa 255).

Er zit ook een `Material.001` in deze modellen: 228 driehoeken, GEEN texture,
alleen een vlakke donkerrode kleur -- de opengesneden binnenkanten van de losse
lichaamsdelen. Het spel legt de teamjas daar wel overheen (`apply_albedo_to`
pakt elke MeshInstance3D behalve de ingebakken wapens). Zichtbaar alleen als er
een ledemaat af vliegt. Bestaand gedrag, niets aan gedaan.

**Nieuw: `tools/blender_export_retexture.py`** -- het kale lijf uit een .blend
vissen om te uploaden voor een retexture. Rusthouding (armature op REST vóór
de modifiers eraf, anders exporteer je frame 1 van een dood-animatie), geen
skelet, geen animaties, geen ingebakken wapen (dat heeft een eigen atlas en
het spel laat die met rust), lichaamsdelen aaneengeplakt tot een object
(`--los` / `--met-wapen` als vlaggen). Op infantry_mix: 1 object, 1235
driehoeken, 237 KB.

Bewezen dat de export de UV's ONAANGETAST laat: `uv_check.py` op het
exportbestand geeft exact dezelfde cijfers als op het spel-model (98,8% voor de
juiste jassen, 70-75% voor de verkeerde). Wat er terugkomt past dus, mits de
dienst niet opnieuw uitvouwt -- daar moet Max expliciet om vragen, en
`uv_check.py` controleert het antwoord.

## 7 september -- retexture-knop in het paneel

Max: "kan een retexture paneel aanmaken waarbij ik de folder selecteer en dan
checkt ie voor blender file". Gebouwd als derde knop in het kader "Modellen
bouwen": een mapkiezer, en daarna `tools/maak_retexture.py` in een zichtbaar
venster met `-NoExit`, gevolgd door Verkenner op `results/retexture/`. Vindt hij
geen .blend in de gekozen map (submappen meegeteld), dan zegt hij dat en start
er niets.

`tools/maak_retexture.py <map>` haalt elke .blend door
`blender_export_retexture.py` en geeft ze een nette naam via `plaats()` uit
`bouw_modellen.py` -- met de OUDER van de gekozen map als startpunt, want de
gekozen map draagt vaak zelf de factienaam. Getest op twee naamstijlen:
`assets/new upload folder/mouse/red/infantry_mix` wordt `mouse_infantry_mix.glb`,
en `assets/new 3d models/Mouse` levert alle vijf als `mouse_cavalry_<arch>.glb`
(950-1448 driehoeken, ~220 KB per stuk).

Twee valkuilen in dit paneelwerk:
- **`$?` in een dubbel aangehaalde PowerShell-string wordt HIER al ingevuld.**
  De opdrachtregel `"...; if ($?) { explorer ... }"` werd letterlijk
  `if (True) {` in het venster dat hem moest draaien. Backtick ervoor.
- Layout is handwerk: het kader groeide van 122 naar 162, de noodrem van y=824
  naar 864, het venster van 968 naar 1008 hoog. Gecontroleerd door het script
  tot `Add_Shown` te draaien en de kaders uit te lezen (laatste kader eindigt op
  950 in een clienthoogte van 969, dezelfde onderrand als altijd), en de
  opdrachtregel die de knop bouwt is los uitgevoerd met een pad met spaties.

## 7 september -- schone lei voor de modellen + een runner voor de blend-inbox

Max: "kunnen we alle models allemaal verwijderen echt alles wat we hebben, want
ik krijg blender files volledig geanimeerd die met wapen mooi zijn." Gekozen:
nu alles weg, en een batch-runner bouwen voor de nieuwe lichting.

**Weg** (commit `72023bd`): `assets/models/{mouse,pig,lion,bear,wolf,crocodile}/`,
1252 bestanden, 642 MB terug naar 39 MB, 134 glb terug naar 7. Het spel blijft
speelbaar: `pawn_view` valt terug op het placeholder-blokje met
archetype-silhouet. `-- tunercheck` na de opruiming: 0 modellen gevonden, 30 nog
niet geleverd, tuner-scene bouwt op, 0 fouten.

**Blijft staan omdat het NIET uit een .blend komt:** `board/`, `props/`
(prop_drum, prop_pole, prop_horn, prop_axe, prop_mace, prop_barrel voor de
regimentsrollen), `model_tuning.json`, `effects_tuning.json`.

**Weg maar terug te halen uit `d5c87d7`:** de teamjassen `<model>_red.png` /
`_blue.png` (incl. de twintig verse muis-jassen van 6 september), de
gore-varianten en de per-factie `musket.glb`. Passen ze nog op de nieuwe
meshes, dan is `git checkout d5c87d7 -- <pad>` genoeg; is de UV-atlas anders
(nieuwe mesh = nieuwe UV's), dan moeten ze opnieuw door Tripo. Reken op het
laatste. De 15 sleutels in `model_tuning.json` zijn nu grotendeels verweesd
(`mouse/*`, `lion/*`): die tuning hoort bij de oude meshes.

**Nieuw: `tools/bouw_modellen.py`.** De gescripte checklist-C voor een hele
inbox: per .blend de drie Blender-stappen (wapen-prop, karakter mét ingebakken
wapen, gibs + kwartslag + bot-kind-fix). De namen in de inbox zijn rommelig,
dus pad + bestandsnaam worden in woorden geknipt en daaruit komen factie, type
en archetype; wat niet zeker te plaatsen is wordt NIET gebouwd maar benoemd.
`--droogloop` toont eerst alleen de indeling, `--factie` / `--model` beperken,
`--parallel` (standaard 4). De Blender-stapscripts gebruiken geen tijdelijke
bestanden en schrijven alleen naar hun eigen `--uit`, dus parallel draaien is
veilig. Elke aanroep krijgt een log in `results/modelbouw_<tijd>/`.

Droogloop op de dertig .blends die er nu liggen: alle dertig goed geplaatst,
inclusief `lion Base.blend`, `pig atk.blend`, `mouse_cavalry_atk.blend` en
`bear_infantry_atk/bear_infantry_atk.blend`.

**Runner bewezen op een echt model** (wolf/infantry_base, 27 s): drie glb's
geschreven, 12 mesh-delen en 17 acties. Daarna `--import` en de vaste checks:
`_wapencheck.gd` meldt `beweegt-mee=true texture=true`, `-- zweefcheck wolf`
PASS (333 meshes zichtbaar, 0 los van hun pion), `-- cliplengtes` vertaalt alle
17 Mixamo-namen goed (Bayonet Attack -> melee1, Death 1-6 -> die1-6, Rifle idle
1-3 -> idle1-3, ...), `-- tunercheck` 0 fouten. Dat testmodel is daarna weer
verwijderd: het kwam uit de OUDE lichting en de lei moet schoon blijven.

**Paneelknop erbij** (Max: "ja doe maar"). Nieuw kader "Modellen bouwen" met
twee knoppen: "Eerst kijken (verandert niets)" draait de droogloop naar
`results/modelbouw_indeling.txt` en opent dat, "Modellen bouwen" vraagt eerst
om bevestiging (het OVERSCHRIJFT modellen) en start de bouw in een zichtbaar
venster met `-NoExit`, zodat het rapport blijft staan. De noodrem schoof van
y=694 naar 824, het venster van 838 naar 968 hoog; de kaders eindigen op 910 in
een clienthoogte van 929, dezelfde onderrand als eerst. Getest zonder het
paneel te tonen: het formulier bouwt op (script tot `Add_Shown` gedraaid en de
kaders uitgelezen), en de droogloop-aanroep is exact zoals de knop hem doet
uitgevoerd -- 32 regels, alle dertig blends geplaatst.

Valkuil onderweg: `assets
ew 3d models` in een niet-rauwe Python-string maakte
van `
` een echt regeleinde en brak de PowerShell-regel doormidden.
PowerShell-tekst met Windows-paden patchen: rauwe string, en daarna
`[Parser]::ParseFile` erop.

**Volgorde voor de nieuwe lichting:** blends in `assets/new 3d models/`,
`python tools/bouw_modellen.py --droogloop`, dan zonder vlag, dan `--import`,
`_wapencheck.gd`, `-- zweefcheck <factie>`, `-- cliplengtes`, `-- tunercheck`.
Daarna pas de teamjassen en de Model-tuner: die twee zijn handwerk.

## 6 september -- nieuwe teamtexturen voor de muis

Max leverde `assets/new textures/mouse/{red,blue}/<archetype>/` aan: 20 verse
Tripo-bakes (2048x2048 PNG, color + normal). Geïnstalleerd als teamjas naast de
glb: `<archetype>_<team>.png` in `assets/models/mouse/{infantry,cavalry}/`.

- **Alle 20 erin.** 12 bestaande jassen vervangen, 8 nieuwe erbij: de cavalerie
  had alleen `cavalry_base`, nu hebben alle vijf archetypen rood én blauw.
- Eerste ronde ging `red/infantry_base` niet mee: dat bestand was toen bake
  `68fa9394…` (de mix-node) en byte-identiek aan `red/infantry_mix`, een dubbele
  download. Max leverde de juiste na; die draagt `d8188b58…`, de eigen bake van
  het base-model, en is alsnog geïnstalleerd.
- **Twee controles op de jas-bij-de-juiste-mesh-vraag.** (1) De uuid in de
  bestandsnaam is de Tripo-node waarop gebakken is: die moet horen bij de
  `<model>_Color_<uuid>.jpg` die al naast dat model ligt. (2) De UV-BEZETTING
  (welke texels beschilderd zijn, uit de alfa) hoort bij de mesh, dus rood en
  blauw van hetzelfde archetype moeten elkaars beste match zijn: 89-99% voor de
  juiste paren tegen ~52% voor de eerstvolgende. Alle tien groen. LET OP: die
  meting werkt alleen tussen de PNG's; de gebakken `_Color_*.jpg` naast het
  model heeft geen alfa en een gevulde achtergrond, en levert voor elk paar
  ~62% op — waardeloos als referentie.
- **Normal-maps niet geïnstalleerd.** Rood en blauw zijn per archetype
  byte-identiek (ze dragen geen teaminformatie) en de engine zet alleen een
  albedo-override (`PawnView.apply_albedo_to`); de normal zit al als
  `<model>_NormalGL_<uuid>.jpg` in de glb. Ze staan nog in de inbox.
- **Gore-varianten zijn niet meegegaan.** `infantry_{atk,base,mix,spd}_*_gore.png`
  zijn de óúde jas met bloed erop (ze verschillen op 30-70% van de atlas: geen
  losse splatter maar een hele hertekening, dus niet automatisch over te zetten).
  Gibs pakken die gore-variant met voorrang, dus brokstukken dragen daar nog het
  oude uniform. `infantry_mix_gibs_red.png` is dood gewicht: gibs kijken naar het
  MODEL-pad, niet naar het gibs-pad.
- **De nieuwe blauwe jas is veel donkerder** dan de oude (bijna zwart in plaats
  van marineblauw); rood is gedempter baksteenrood. Leesbaarheid rood/blauw op
  het bord leunt daardoor zwaarder op het voetringetje. Contactvel oud/nieuw:
  `results/muis_texturen_oud_nieuw.png` (regenereert niet vanzelf, results/ is
  gitignored).
- Import volgens MODEL-PIPELINE-CHECKLIST E: `process/size_limit=1024` +
  `mipmaps/generate=true` in elke `.import`. `-- tunercheck`: 30 modellen, gibs
  compleet, 0 fouten.
- Inbox `assets/new textures/` krijgt dezelfde behandeling als
  `assets/new 3d models/`: `.gdignore` erin (anders importeert Godot 39 PNG's
  van 4 MB mee) en een regel in `.gitignore`.

## 4 september -- F4.4a: online hosten op een droplet (deploy-pakket)

Max: "hoe kan ik dit online gaan hosten op digital ocean" en "bouw maar".
Eerst gemeten wat er echt op een droplet moet: de Node-backend (72 MB), de
scheidsrechter (headless Godot, 136 MB) en MySQL (~400 MB). Het volle project
(4,7 GB) hoort er NIET bij: de import ervan piekt op 7,5 GB werkgeheugen en de
worker gebruikt er niets van. Proef in de scratchpad: een kopie met alleen
`core/`, `scripts/`, `agents/`, `net/`, `arena/`, `i18n/`, `data/` en de worker
importeert in 7 s (56 KB cache) en geeft dezelfde core-hash `db5029…`.
Advies aan Max: eigen droplet van 2 GB (~12 dollar), niet de
ReisLastMinute-machine (elf PM2-apps + productie-MySQL op 8 GB).

Gebouwd, in `tools/deploy/` (README voor Max met de stappen die hij zelf
doet: droplet + SSH-sleutel, A-record, e-mail voor Let's Encrypt):

- `bouw_serverpakket.ps1 [-Proef]`: het server-pakket naar
  `results/serverpakket(.tgz)` (0,3 MB, 233 bestanden; zonder
  `scripts/game/game.gd` (preloadt Board.tscn) en zonder `scenes/`). `-Proef`
  importeert het pakket, start er een worker uit en vergelijkt core-hash én
  init-hash met een worker uit het volle project (`worker_proef.mjs`:
  NDJSON over TCP; les: de worker neemt precies één verbinding aan en stopt
  als die dichtgaat, dus nooit "peilen" met een losse verbinding).
- `deploy-server.ps1 -Droplet <domein> [-Nettest]`: pakket + proef, server-bron
  (src, db, package*.json, tsconfig*) inpakken, scp, ssh
  `op-droplet-uitrollen.sh` (import als service-gebruiker, `npm ci`,
  `npm run build`, engine wisselen, herstart, wachten op `/gezond`), dan
  `GET /versie` via https en desgewenst `-- nettest` tegen de droplet.
- `droplet-setup.sh` (eenmalig, Ubuntu 24.04): nginx + certbot, MySQL 8 met
  database en gebruiker (gegenereerd wachtwoord in `.env`, 600), Node 22
  (NodeSource), Godot 4.7 Linux-binary (download gecontroleerd), gebruiker
  `fogofwar`, `fogofwar.service` (Restart=always, ProtectSystem=full,
  EnvironmentFile), nginx-site (poort 80, certbot voegt 443 toe) plus
  http-context (`limit_req` 10 r/s burst 30, `limit_conn`, WebSocket-map),
  ufw 22/80/443. Idempotent.
- Server: `npm run build` (`tsconfig.build.json` → `dist/`), `npm start` =
  `node dist/index.js`, `FOW_PROJECT_PAD` (engine los van de code),
  `.env.voorbeeld`, `server/.env` in `.gitignore`; de worker krijgt
  `FOW_WORKER=1` mee.
- Engine: `Audio._ready` slaat onder `FOW_WORKER` het laden van de banken
  over (`_laad_banken()`), `UiThema._ready` keert dan meteen terug. Op het
  pakket scheelde dat 1180 regels ontbrekend-bestand-fouten per start; de
  core-hash raakt het niet (beide scripts zitten niet in `core/` of de zes
  kernscripts).
- Client: `Identiteit.server_url` leest de projectinstelling
  `fogofwar/server_url` (voor een uitgeleverde build; `identity.cfg` en
  `-- server=` gaan erbovenop). `project.godot` kreeg de sectie `[fogofwar]`.

**Nazorg onderweg.** (1) De lobbycheck faalde op stap 6: niet door dit werk
maar door de UI-assetpack-merge (5d4a18e) waarin het factie-menu een eigen
scherm werd (`game._factie_keuze`); de check keek nog naar het overlay-menu.
Aangepast in `capture.gd`. (2) De lokale MySQL op 3316 was twee keer gestopt
(db-lokaal.ps1). (3) Eigen review van de Linux-scripts (de review-agents
liepen op de maandlimiet): een apostrof in `${EMAIL:?...}` was voor bash een
open quote, `ufw status | head` kon met `pipefail` een SIGPIPE-exit geven, een
`[ ] && mv` onder `set -e` is een expliciete `if` geworden, en de
nettest-argumenten in PowerShell gaan als array zodat het losse `--` letterlijk
aankomt. `bash -n` op beide scripts en de PowerShell-parser op beide ps1's zijn
schoon; de Linux-kant zelf draait pas op Max' droplet (geen WSL-Ubuntu hier).

**Checks:** pakket-proef PASS (core-hash en init-hash gelijk, import schoon);
`npm run typecheck` + `build` ok; `npm test` 20/20; de GEBOUWDE server
(`node dist/index.js`, `FOW_PROJECT_PAD` = pakket): `-- nettest` 13/13 en
`-- lobbycheck` 10/10; testsuite 2282 asserts, 0 fouten; `-- uispel 777`
zobrist `890b6cb4…`, 270 acties, cyclus 6 (ongewijzigd). Docs: CLAUDE.md,
MASTERBOUWPLAN (F4.4a onder F4.4), server/README.md, tools/deploy/README.md.

**Volgende:** Max maakt de droplet en het A-record; dan `droplet-setup.sh`,
`deploy-server.ps1 -Nettest`, en de projectinstelling `fogofwar/server_url`
op de https-url zetten vóór de eerste client-export. Daarna F4.3j.

## 4 september (ochtend) -- zwevende wapens: de bot-kind-bug van Blender 5.1

Max: "alle wapens zweven overal en zwaarden etc., terwijl de blends geanimeerd
en wel zijn." Klopte: in alle cavalerie-glb's en de beer/krokodil/wolf-
infanterie stond het ingebakken wapen (de `tripo_node` aan
`mixamorig:RightHand`) 4 tot 9 wereld-eenheden van de hand, en omdat de
handrotatie per animatieframe verschilt, lagen sabels en musketten overal
naast en onder het bord. `tools/_wapencheck.gd` zag niets: die kijkt alleen
naar de hierarchie (bot-geparent = goed), niet naar de afstand.

**Oorzaak.** In de blends zit het wapen wél netjes op de hand (8-20 cm van het
bot, gemeten in Blender). De glTF-exporter van Blender 5.1 schrijft voor een
bot-geparent object onder een armature met schaal 0,009 de X en Z goed, maar
telt bij Y de botlengte GEDEELD DOOR de armature-schaal op (4,4 / 0,009 = 490
in plaats van 4,4) en negeert een niet-identieke `matrix_parent_inverse`. De
importer doet hetzelfde de andere kant op, dus de merge-stap (glb importeren,
kwartslag-fix, gibs, opnieuw exporteren) maakte het opnieuw stuk. De oude
pig/muis/leeuw-infanterie (exports van voor 15 augustus) had het niet.

**Fix in de pijplijn** (`tools/blender_botkind_fix.py`): stap 2
(`blender_export_blend.py`) bakt de parent-inverse in en overschrijft na de
export de wapen-node in de glb met de bot-relatieve matrix die Blender zelf
ziet; stap 3 (`blender_merge_character.py`) bewaart de bot-kind-transforms
uit de basis-glb voor de import en zet ze na de export terug. Alle 30
getroffen modellen zijn opnieuw door stap 2 en 3 gehaald vanuit de blends in
`assets/new 3d models/` (de Pig/Lion-blends zijn de cavalerie; per model op
tripo-id geverifieerd). Nieuwe controle: `-- zweefcheck [factie]` (elke
zichtbare mesh die meer dan 2 eenheden van zijn pion staat; de vaandels op
1,3 vallen erbinnen).

**Checks na de her-export en import:** `-- zweefcheck` PASS voor alle zes
facties (0 meshes verder dan 2 van hun pion), `_wapencheck.gd` PASS (42
ingebakken, 3 prop-route, 0 fouten), `-- tunercheck` 0 fouten,
`-- meleecheck` PASS, suites groen, `-- uispel 777` zelfde zobrist (modellen
raken de logica niet). Schermafbeeldingen per factie (`-- play <factie>`)
bekeken: musketten en sabels in de hand, niets meer naast het bord.

## 5 september -- F4.3i: de lobby, twee mensen tegen de dev-server

Max: "dus morgen kunnen we gaan testen, is het heus?" Ja, op het eigen
netwerk. Dit is masterplan-M1: twee clients tegen de dev-server.

- Autoload `OnlineBridge` (`scripts/game/online_bridge.gd`, patroon van
  CampaignBridge): identiteit, `HttpTransport` (HTTPRequest-kinderen aan de
  bridge, overleven een scene-wissel), `verbind` (gast-login + core-hash),
  `nieuwe_match`, `meedoen`, `hervatten`, `sessie()`, `klaar_met_match`.
  De laatste match-id staat in `identity.cfg` (hervatten).
- Lobby in game.gd: MULTIPLAYER → "Online (via de server)" → verbinden →
  "Nieuwe match" (wachtscherm met de match-id groot in beeld, kopieerknop,
  elke 2 s `GET /matches/:id` tot `bezig`, dan `_start_online`),
  "Meedoen met een match-id" (invoerpaneel; het klembord vult een uuid
  alvast in), "Laatste match hervatten" (status: bezig → starten, klaar →
  melding, lobby → wachten). Fouten in één overlay met "Terug".
  `_verlaat_online` maakt de match-id schoon.
- `Identiteit`: ook `-- naam=<naam>`. Server: `HOST` env (0.0.0.0 voor het
  LAN). README: het stappenplan "Twee mensen tegen elkaar".
- `-- lobbycheck [url]` (capture): A via de echte lobby-code (keuzes,
  nieuwe match, wachtscherm), B als tweede client, A's wachtscherm ziet de
  join en opent het factie-menu, beide keuzes, opstel-overlay, B ziet de
  opstelling, hervat-id in identity.cfg. **10 van 10 PASS.**

**Vondst, en precies waar de loopback blind voor was:** bij een 409 diende
`RemoteSession` meteen opnieuw in, terwijl de inhaal-rijen en de view per
HTTP nog onderweg waren: de herindiening ging met de oude seq de deur uit
en eindigde in "De situatie is veranderd". In de lobbycheck viel dat op
zodra beide spelers tegelijk hun factie kozen. Nu wacht de herindiening
(`_rebase_wacht`) tot `seq` de inhaal heeft ingehaald; `VertraagdTransport`
in de tests levert nu antwoord voor antwoord (`lever()` snapshot), en een
elfde test stapt precies door die keten. RemoteSessionTests 148 asserts.

Checks: lobbycheck 10/10, RemoteSessionTests 148, play online seat 2,
uispel 777 zobrist gelijk, play/vosview/meleecheck/naadcheck PASS,
volledige suite 1997 asserts groen (0 fouten).


## 4 september (nacht, later) -- nazorg g: het licht draait mee voor blauw

Max speelde de oefenmodus als blauw: "lijkt te werken, alleen het licht is
nu te eenzijdig, dus alleen goed voor rood." Klopt: de camera draaide, de
zon, spot en rim niet (bouwplan: "lichten draaien niet mee, aanvaard";
niet aanvaard dus). Oplossing: in `_ready` komen camera, zon, spot en rim
onder één kijk-pivot (`Kijkrichting`, kind van het bord, op identiteit,
dus alle kinderen houden hun bord-coördinaten en het sfeer-paneel werkt
gewoon door). `_orient_camera_for` draait nu het PIVOT 180 graden om het
bordcentrum; de camera zelf houdt zijn lokale stand (`_cam_base` en de
screen shake ongemoeid). Gemeten wereldpositie van de camera: (-1,8, 5,
4,8) voor rood, (1,8, 5, -4,8) voor blauw. play online 1 en 2, offline
play/vosview/meleecheck en resumecheck 4242 seat 2 allemaal PASS.


## 4 september (nacht) -- F4.3h: HttpTransport, identiteit, core-hash, nettest

De echte server erachter. Polling is de eerste (en blijvende) terugval
voor de push: `npm run dev` herstart bij elke bronwijziging en gooit alle
WebSockets dicht, dus tijdens het bouwen is dit het normale pad.

- `scripts/core/core_hash.gd` (`CoreHash.bereken()`): de hash-berekening
  uit de worker, nu ook aan de clientkant; de worker roept dezelfde functie
  aan. Het bestand zit niet in de gehashte lijst, dus de hash is
  onveranderd (`db502910…`, zelfde aan beide kanten in de nettest).
- `net/identiteit.gd` (`Identiteit`): `user://identity.cfg` met
  device-token (UUID), naam, server-url (default `http://127.0.0.1:8787`),
  laatste match; `-- identiteit=<naam>` kiest `identity_<naam>.cfg` (twee
  clients op één machine delen user://), `-- server=<url>` overschrijft.
- `net/http_transport.gd` (`HttpTransport`): per verzoek een verse
  HTTPRequest als kind van een host-node (view-ophaal, actie-POST en poll
  lopen door elkaar), Bearer-token, antwoorden in dezelfde vorm als de
  loopback. Extra: `login` (POST /auth/gast), `versiecheck` (GET /versie
  tegen `CoreHash.bereken()`), `maak_match`, `join`. `pollen()` = true.
- `RemoteSession._process`: polling elke 0,5 s (`events?after=seq`) zolang
  het transport erom vraagt; dedupe zit al in `_ontvang`.
- Server, twee regels (matches.ts): `GET /view` leest de hoogste seq VÓÓR
  de fold. Zo is de gemelde seq hoogstens te laag (de client haalt de rij
  gewoon in), nooit te hoog (rij afspelen op een verouderde staat).
- `-- nettest [url]` (capture): twee gast-accounts, versiecheck, match
  maken en joinen, twee RemoteSessions op HttpTransport, beide blinde
  keuzes, reveal via de server, opstelling van A die B ziet maar niet
  inhoudelijk (fog), `GET /matches/:id`. Uitslag: **13 van 13 PASS**, B
  ziet de keuze van A na 606 ms polling.

Twee valkuilen voor wie dit herhaalt: de dev-database `fogofwar` bestaat
niet vanzelf (alleen `fogofwar_test`, door de tests): README heeft nu het
`CREATE DATABASE`-regeltje; en de lokale MySQL bleek na de pauze van het
abonnement weer gestopt (`server/db-lokaal.ps1` start hem, idempotent).

Checks: servertests 20/20, tsc schoon, RemoteSessionTests +
GameSessionTests 235, play online PASS, resumecheck 777 seat 1 PASS,
simcheck 0 afwijkingen, volledige suite 1983 asserts groen (0 fouten).


## 4 september (avond) -- F4.3g: game.gd speelt via de online-weg, ook als seat 2

De speelbare tussenstand zonder server, en het eerste dat Max zelf kan zien.
Onder MULTIPLAYER staat nu een menu: "Oefenen via de online-weg (als rood)",
"(als blauw)", "Online (binnenkort)". Oefenen = een `LoopbackTransport` op
de potje-regels met een L1-bot op de andere stoel, en game.gd op een
`RemoteSession` erop: exact het pad dat straks tegen de server loopt (alleen
de eigen view, wachtteksten in elke commit-fase, de blinde factiekeuze als
actie, de CP-inzet in de define).

- `_potje_regels()` uit `_start_match` getrokken; `_start_online(sessie)`
  verbindt (status + eerste view) en gaat dan door `_start_vanaf_sessie`
  (stap e). `_start_oefenpotje(seat)` bouwt de loopback (`_loopback` houdt
  hem in leven; het transport houdt alleen een weakref).
- **Camera:** `_orient_camera_for(pid)` draait voor speler 2 de camera 180
  graden om het bordcentrum (board-lokaal), `_cam_base` mee. Geen
  coördinaat-spiegeling; picking, blokjes en highlights volgen vanzelf.
  Gemeten: (3.185, 5, 9.84) wordt (6.815, 5, 0.16).
- Fase-flow zonder bot: `_on_doctrine_choice` online → `submit_choose_doctrine`
  + wachten; `_on_doctrines_revealed` zet de facties uit de staat;
  `_on_phase_changed` opent online de opstel-overlay bij PLACEMENT;
  `_on_cp_choice` online onthoudt de inzet (`_cp_bet_keuze`) en
  `_on_define_confirmed` geeft hem mee aan `submit_define_cards(..., cp_bet)`
  (F4.2b: één rij). Offline blijft de losse `submit_bet_cp`: byte-identiek.
- Namen: `_player_name` volgt de seat (rood = 1, blauw = 2) plus wie erop
  zit (jij / AI / de naam uit de sessie, terugval kleur). Strings
  `HUD_PLAYER_YOU`/`_AI` zijn nu "%s (jij)"/"%s (AI)" met `HUD_COLOR_RED`/
  `_BLUE`; offline leest dat als vanouds. Het onthul-scherm is per seat een
  `PHASE_REVEAL_LINE` met die naam (offline: "Rood (jij)" waar het "Jij
  (rood)" was), `HELP_GAME_WHAT_BODY` is neutraal.
- Einde online: winnaar + `eind_reden`, "Terug naar het menu"
  (`_verlaat_online`: sessie weg, camera terug, hoofdmenu). Nooit
  `CampaignBridge.rond_af` (assert in `_start_vanaf_sessie`).
- capture: `-- play online [2]`, `-- vosview online [2]` (bot = Krokodil,
  '?'-check via `session.pion_gedekt`) en `-- resumecheck [seed] [seat]`:
  de koude herstart op de online-weg, elk moment een verse scene met een
  verse RemoteSession op dezelfde loopback.

Uitslag: play online seat 1 en 2 PASS (11 stappen tot de actiefase),
resumecheck 777 seat 1 en 4242 seat 2 PASS: 46 momenten, 0 verschillen,
0 canary, ALLE veertien fasen van PRE_GAME tot GAME_OVER (de bot won
binnen 160 acties). Dat is masterplan-M3 zonder netwerk, voor beide stoelen.

Checks: uispel 777 zobrist gelijk, opname gelijk, play/vosview/meleecheck/
naadcheck PASS, herstelcheck 777 PASS, simcheck 0, RemoteSessionTests +
GameSessionTests 235, volledige suite 1983 asserts groen (0 fouten).


## 4 september (later) -- F4.3f: RemoteSession, Transport, LoopbackTransport

De online sessie, headless bewezen tegen een server-in-het-klein die alleen
JSON-tekst en geredigeerde rijen levert. game.gd is niet aangeraakt.

- `net/transport.gd` (`Transport`): het contract, callback-stijl (geen
  coroutines: de loopback antwoordt in dezelfde aanroep, de HttpTransport
  van stap h later, de sessie merkt het verschil niet): `status`, `view`,
  `acties(seq_expected, action, idem_key)`, `events(after)` en de push
  `rijen_binnen`. Eén instantie = één identiteit op één match.
- `net/loopback_transport.gd` (`LoopbackTransport`): één volle GameState
  in PRE_GAME, het actieprotocol van protocol.md (idem-tabel, seq-check met
  409 en inhaal, `Validator.is_legal` als 422, `Reducer.apply`), een
  server-only log in MatchLog-formaat en client-rijen door
  `View.client_events` én door `JSON.stringify/parse_string` (floats,
  gesorteerde sleutels: precies wat de echte server geeft). Per stoel een
  `Eindpunt` (Transport) met een `stil`-vlag om een verbindingsverlies te
  spelen. Optioneel een bot op de andere stoel (`zet_bot`), die na elke rij
  zijn legale zetten doet zoals een tegenstander achter de server.
  `snapshot()/herstel()` voor de resumecheck van stap g.
- `net/remote_session.gd` (`RemoteSession extends SessionInterface`): één
  poort `_ontvang` voor alle rijen (push, 200, 409-inhaal, `events`), dedupe
  op seq, strikt op volgorde; vóór elke rij de view verversen (staat
  vervangen via `ClientState.uit_view`, `state_updated`), dan de events door
  `EventCodec` naar de signals. Submits: lokale `Validator`-voorcheck,
  `Actions.to_dict`, `acties` met een verse idem-key; 409 → inhalen en één
  herindiening als de actie nog kan; 409 "afgelopen" → status → `game_over`;
  422 → `error_occurred`. `submit_bet_cp` weigert bewust (F4.2b: online
  reist de inzet in de define mee, `submit_define_cards(..., cp_bet)`, dat
  veld zit nu ook in SessionInterface en GameSession met default 0). Hier
  draait NOOIT `Reducer.apply`.
- `tests/RemoteSessionTests.gd` (8 tests, in TestRunner en tests.ps1): het
  contract (dezelfde gescripte partij via GameSession en via twee
  RemoteSessions op de loopback geeft dezelfde signal-reeks mét argumenten
  en dezelfde staat op de gesloten fog-lijst; de loopback-server heeft
  exact de offline staat), de lek-canary op de client-staat (geen
  vijandelijke pionnen in PLACEMENT, geen vijandelijke kaarten vóór de
  reveal, nooit vijandelijke saldi), 409-rebase van een verouderde client
  (één rij, geen fout), idem-herhaling (één rij, `herhaald`), 422 plus de
  lokale voorcheck en de stoel-check, typed signals na JSON (nergens een
  float), de einde-route via de status, en de bot op de andere stoel.
  Alle acht slaagden bij de eerste run.

**Zelf nagelopen, omdat de review-agents uitvielen (maandlimiet van het
abonnement, drie van drie lezers):** de pomp was met een SYNCHROON transport
goed, maar met een echt asynchroon transport (stap h: het view-antwoord
komt later dan de push) speelde `_pomp` een rij af vóórdat de bijbehorende
view er was, dus op een oude staat. Nu wacht een rij op zijn view
(`_view_onderweg`) en een gat op zijn inhaal-rijen (`_inhaal_onderweg`); de
callbacks zetten de pomp weer aan, en met de loopback (antwoord in dezelfde
aanroep) loopt de lus gewoon door. `_neem_view` schuift `seq` alleen bij de
koude start vooruit; daarna blijft `seq` de laatst afgespeelde rij, zodat
elke rij zijn signals krijgt. Twee tests erbij met een `VertraagdTransport`
(houdt antwoorden vast tot `lever()`): rij wacht op view en het 200-antwoord
na de push wordt niet dubbel afgespeeld; en een gemiste rij wordt via
`events(after)` ingehaald en op volgorde afgespeeld. 10 tests, 134 asserts.

Checks: RemoteSessionTests 134 asserts groen, uispel 777 zobrist gelijk,
opname gelijk, simcheck 0, naadcheck/vosview PASS, herstelcheck 777 PASS,
volledige suite 1983 asserts groen (0 fouten, 334 s).


## 4 september -- F4.3e: render-vanaf-snapshot, offline bewezen

De grootste post van F4.3: elke fase van game.gd opbouwbaar uit de staat
ALLEEN, zonder events, als het normale startpad van een online partij. En
bewezen zonder een byte netwerk.

**game.gd.** Drie refactors zonder gedragswijziging (`_open_define_fase`,
`_toon_reveal`, `_open_spawn_fase`: de fase-UI die aan de signals hing is nu
aanroepbaar vanuit de staat). Nieuw `_start_vanaf_sessie(sessie)`: geen bot,
sessie erin, signals overkoppelen, `_toon_fase_vanaf_staat()`. Die laatste
bouwt per fase het scherm: doctrine-menu of wachten, opstel-overlay of
wachten, CP-bod/waaier of wachten, onthul-scherm (uit
`Rules.compute_initiative`, dezelfde getallen als het event) of wachten,
koppel-waaier + ringen + beurt, actiefase + open wolf-stap, spawn-overlay,
einde. Plus `render_digest()` (deterministische samenvatting van het scherm)
en `is_rustig()`.

**`-- herstelcheck [seed] [factie]`** (capture): de live scene speelt zonder
bot, de mens via het timeout-pad, de tegenstander (L1) buiten game.gd om via
GameSession, zoals een server. Op elk nieuw moment (fasewissel, beurtwissel,
eigen commit, open wolf-stap) start een VERSE game.tscn op alleen de
fog-view van speler 1, door JSON-tekst, en wordt de digest vergeleken.
Canary: geen hp-blokje met een getal voor een pion die in de view '?' droeg.

**Wat de check aan het licht bracht (en gefixt is):** de koppel-waaier
kwam uit de define-configuratie (na een koude start toonde hij de standaard
drie kaarten): nu `_toon_linking_hand()` uit `cards_revealed`, en de waaier
staat de hele koppel-fase in beeld. De koppel-ringen stonden ook op
VIJANDELIJKE ongekoppelde pionnen (`_refresh_all` en
`_highlight_own_unlinked_pawns`): dat verried offline de koppelstaat van
gedekte Krokodil-pionnen, iets wat de view niet geeft. Nu alleen eigen
pionnen. De hp-blokjes volgden een andere dekkingsregel dan de view (C13
"van dichtbij zie je hem" ontbrak offline): `View.pion_gedekt_voor` is nu
dé regel, voor view én renderer (vosview aangepast). De topbalk kende de
spawn-fase niet en werd bij het CP-bod niet ververst. Na een eigen commit
zegt de prompt online nu "Wachten op de tegenstander". Verder twee
harnas-vlaggen (`_fase_overgang_bezig`, `_define_open_bezig`) zodat
"rustig" ook de 0,9 s ronde-pauze en de poef-reveal dekt, en posities op
halve tegels (een stagger mag uitlopen, een verkeerde tegel valt er nog uit).

Uitslag: seed 777 (Krokodil-tegenstander) 131 momenten, seed 4242 (Wolf)
139 momenten, 0 verschillen, 0 canary, alle fasen van SETUP_1_DEFINE tot
CYCLE_SPAWN. Niet gedekt door de check: PRE_GAME (offline begint game.gd na
de keuze; stap g) en het GAME_OVER-scherm (naadcheck dekt het pad, de
digest niet).

**Uit de review erachteraan (46 agents):** twee bewuste gedragswijzigingen
in het vs-AI-pad die de uispel/record-meting niet ziet, hier vastgelegd:
(1) laat de mens in ronde 2/3 het CP-bod verlopen, dan dient de timeout nu
altijd de standaardverdeling in; voorheen stond de koppel-waaier van de
vorige ronde nog onder het CP-bod en diende de timeout stilletjes de
kaarten van de VORIGE ronde opnieuw in (of liep vast als daar een CP-kaart
tussen zat). (2) heeft de mens deze ronde geen vrije pionnen
(`expected_define_count` 0, laat in de partij), dan opent er geen lege
waaier meer met een bevestigknop die een ongeldige define stuurt; de bot
komt meteen aan de beurt (`_ai_define_beurt`), online wacht je. Verder:
`_animate_link` zette bij een koppeling van de tegenstander het
karaktermodel uit de ECHTE kaart, ook voor een gedekte Krokodil-pion (het
archetype verried de kaart, een offline fog-lek van voor F4): nu door
dezelfde gate. Na een eigen opstelling online: "wachten". De
eindvergelijking van de herstelcheck wacht nu ook op een stil scherm.

Checks: herstelcheck 777 en 4242 wolf 0 verschillen, uispel 777 zobrist
gelijk, opname gelijk, naadcheck/vosview/play/meleecheck PASS, simcheck 0
afwijkingen, fuzz 30/0, volledige suite 1849 asserts groen (0 fouten).

## 3 september (middag) -- UI-assetpack ingebouwd (branch ui-assets-pack)

De ontwerper leverde `fogofwar-assets/UI_assets_pack` (91 png's: 7 knoppen
met pressed/blocked, kaartkit, 6 emblemen, 30 iconen, 3 panelen, perkament)
plus de pdf "Fog of war UI direction" (kaartstaten, palet, fonts Roboto Slab
SemiBold + Rye). Alles zit nu in het spel. Gebouwd in een eigen worktree op
de branch **`ui-assets-pack`** (basis 8d84e7a = F4.3d), omdat er tegelijk een
andere sessie aan F4.3e in de hoofdmap werkte; game.gd is daarom bewust
klein en additief geraakt (preload-constanten, knop-eigenschappen, de body
van twee menu-functies, extra argumenten aan show_choice, een regel in
_open_define_hand en _on_cards_revealed). Mergen zodra F4.3e gecommit is.

**Fundament.** `assets/ui/` met de ORIGINELE bestandsnamen (typo's
`button_2_bloccked`/`Croccodile` worden in code herkend, zodat een nieuwe
drop gewoon werkt; zie `assets/ui/LEESMIJ.md`). `scripts/ui/ui_assets.gd`
(`UiAssets`) is de enige plek die bestandsnamen kent: iconen op hun spec-id
(`icoon("stat-hp")`), emblemen, kaartdelen, 9-patch-knop- en paneelstijlen,
palet, fonts, en het thema. Autoload `UiThema` legt dat thema over het hele
spel; schermen kiezen vormen met `theme_type_variation` (KnopGroot/Breed/
Rood/Rond/Vierkant/Plus/Min, PaneelBalk/Veldtafel/Papier/..., LabelInkt/
Kop/Cijfer, RichInkt). Widgets: `UiPortret` (embleem in krans in teamkleur),
`UiIcoonTekst`, `UiFactieKaart` (regimentskaart als knop). Statusbord:
`-- uicheck`. Suite `UiAssetsTests` (16 tests).

**Bevinding thema-overerving.** Een Godot-thema erft alleen door een keten
van Control/Window-ouders: het venster-thema kwam NIET aan onder de
CanvasLayer `$UI` van game.tscn en niet onder de kale Node van capture.tscn
(alle drie de bouwers liepen er tegenaan). `UiThema` hangt het thema nu ook
aan elke Control/Window die onder een niet-Control de boom in komt
(`node_added`); test `test_thema_bereikt_controls_onder_canvaslayer_en_node`.

**Schermen.** Kaarten (`card_view` herbouwd op het 645x989-frame met
naamplaat, krans+embleem, drie stat-kolommen, +/- knopjes, CP-zegel, en de
staten EDITABLE/SELECTABLE/SELECTED/LINKED/REVEALED/rug; `_adjust_stat`
letterlijk behouden, `-- carddist` exact gelijk); bord-HUD (`HudBalk` op
Frame_1 met fase-icoon en unit/pool/CP-iconen, ronde ?-knop, rode
opgeef-knop, contextknop); `Overlay` op Frame_2 met brede perkamentknoppen en
optionele iconen per optie; `FactieKeuzeScherm` (zes regimentskaarten, ook
voor de tegenstanderkeuze); `EindeScherm`; campagne-hub (veldtafel,
kopbalk, portretten met teamkrans, feed-kaartjes met teamrand en icoon,
fasepaneel op Frame_3), grootboek (blad met icoon-kolomkoppen en portretjes),
bracket, en het helpscherm (Frame_3, tabbladknoppen, inkt-tekst met iconen
en emblemen via `[img color]`). Onthulscherm: beide handen als echte kaarten
met REVEALED-stempel (zie hieronder).

**Niet in het pack.** Acht spec-iconen (vote, nomination, donation,
testament, report, chat, clock, pin): schermen vallen terug op tekst. De
fonts: Rye en Roboto Slab SemiBold ontbreken; `assets/ui/fonts/` draagt
Roboto Slab Regular/Bold van deze machine als terugval, het thema pakt de
bedoelde bestanden vanzelf op zodra ze er staan.

**Besluit Max (3 september, middag):** kaart definiëren met ALLEEN een grote
plus-knop per stat, geen min: plussen haalt het punt weg bij de grootste
andere stat (de bestaande `_adjust_stat`). De min-functies blijven voor de
tools (`-- carddist`), alleen de knop verdwijnt. De pdf toont nog "+ -".

**Controle-ronde (3 september, 14:40).** Een review-workflow (11 visuele
reviewers per scherm + 4 code-lenzen, daarna tegensprekers en herstellers)
leverde 66 ruwe bevindingen op, maar liep op de uitgavenlimiet van de
subagents vast (147 van 158 agents); de triage en het herstel doet de
hoofdsessie zelf. Aangenomen: kaart plus-only en groter, kaarttekst groter
(statnaam 22->30, titel 40->48, naamplaat 34->40, cijfer 70->84), ondertitel
(9 px op het scherm) weg en de sierlijn onder de titel; HUD-balk hoger
(170->190) zodat een prompt van twee regels niet over de telregel valt, de
define-legenda uit de prompt (de kaart draagt nu zelf de stat-iconen),
zijknoppen sfeer/opgeven 88x88 (de 88x60-compactie gaf een 9-patch-naad en
onleesbare tekst), het legertotaal in de telregel uit
`state.doctrine_data_of().comp` (toonde 19/22 bij de start: kale tabel),
dialoogtekst leesbaar (AcceptDialog op een donker vlak), hub `_wis_paneel`
met remove_child (naamconflict), dode tooltip weg, grootboek-uitleg in inkt,
bracket-tekst 22 px, em-dashes uit de HUD/bracket-sleutels. Afgewezen of
buiten scope (3D-bord, later): zwevende musket-props na het plaatsen,
haven/ring-kleuren en cyaan vakken buiten het palet, camera-framing,
hp-chips van 5,5 px, koppelring onzichtbaar, `?`-knop boven het dim-vlak
(bewust: uitleg altijd bereikbaar).

**Merge met F4.3h + nazorg (e7b6525) en F4.3i (c8eb306), 3 september avond:**
alleen project.godot (beide autoloads: OnlineBridge en UiThema) en de
gecompileerde vertalingen botsten. Daarna is main gefast-forward naar de
branch (besluit Max: "gooi de UI er maar in") en in de hoofdmap een
`--import` gedraaid voor de nieuwe textures en fonts.

**Merge met F4.3g (983fffc, 3 september 19:20):** conflicten in de csv
(beide blokken nieuwe sleutels) en opnieuw `_toon_reveal` (F4.3g's
tekstregels per seat vervallen: het OnthulScherm toont de namen per seat
al). Op het online-pad (`-- play online 2`) bleef het factie-keuzescherm
open staan, omdat de keuze daar niet via een tik binnenkomt: het scherm
sluit nu in `_on_doctrine_choice`/`_on_opponent_choice` en bij elke
`_start_match`/`_start_vanaf_sessie`. Na de merge: suites 970 groen,
carddist exact, uicheck PASS, uispel 777 zelfde zobrist, naadcheck PASS,
`-- resumecheck 777 1` en `4242 2` PASS (0 verschillen, 0 canary). Main
staat inmiddels vuil met F4.3h-werk van de andere sessie; fast-forwarden
kan pas als die map schoon is (`git merge --ff-only ui-assets-pack`).

**Merge met main (F4.3f, 3 september 18:55):** vier conflicten (WIP.md,
game.gd `_toon_reveal`, tests.ps1, TestRunner.gd) opgelost; F4.3e's
`_toon_linking_hand` geeft de kaartwaaier nu factie, kleur en CP-zegel mee.
Na de merge: suites 908 groen, carddist exact, uicheck PASS, uispel 777
zelfde zobrist en 270 acties, naadcheck PASS, `-- herstelcheck 777` en
`4242 wolf` allebei PASS met 0 verschillen en 0 canary.

**Merge-recept (proefmerge, achterhaald door de echte merge hierboven):** twee conflictblokken: WIP.md (beide
koppen houden) en game.gd (`_toon_reveal` van F4.3e houden en daarin de
OnthulScherm-aanroep zetten); daarna in F4.3e's `_toon_linking_hand` de
`configure(...)` van de hand `_human_id, _human_doctrine` meegeven en per
kaart `set_cp_inzet(hp+stamina+attack > budget)`. Pas fast-forwarden naar
main als de hoofdmap schoon is.

**Checks (in de worktree, na de centrale `--import`):** suites
UiAssets/Card/GameSession/Campaign/View 733 asserts groen, SoloTests groen
(bouwer), `-- uicheck` PASS, `-- carddist` exact, `-- uispel 777` zobrist
`890b6cb4...b97d` met 270 acties (gelijk aan F4.3a), `-- naadcheck` PASS,
`-- simcheck` 0 afwijkingen, `-- vosview` PASS, `-- shot campaign_hub/ledger/
bracket` 0 fouten. Schermafbeeldingen van define (3 en 5 kaarten), link,
reveal, play, tegenstander, placetest, uitleg, hub, grootboek en bracket
zijn bekeken tegen de pdf. `-- define` klikt nu zelf het CP-bod weg zodat
de waaier in beeld komt.

## 3 september (nacht) -- F4.3d: view compleet, ClientState, EventCodec

De engine-kant van de client, zonder een byte netwerk: alles wat nodig is om
uit JSON-tekst een speelbare, renderbare staat te bouwen, bewezen op
engine-niveau.

- `View.for_player` draagt vier publieke sleutels extra:
  `last_initiative_winner` (Rules.compute_initiative valt er bij een gelijk
  bod op terug), `eind_reden`, `turn_deadline` en `clocks` (beide banken;
  een klokstand is geen geheim). De core-hash verandert mee, protocol.md in
  dezelfde commit.
- `net/client_state.gd` (`ClientState.uit_view`): wrapper om
  `Agent.reconstruct_state` (onaangeraakt, dus het 4672/4672-bewijs en de
  trainingspaden staan), vult aan wat een CLIENT nog mist: de eigen blinde
  commits (doctrine, spawn; anders biedt de validator ze opnieuw aan en
  antwoordt de server 422), de vier sleutels, en herstelt de id-volgorde
  van pionnen en kaarten. Dat laatste was de vondst van deze stap: JSON
  sorteert object-sleutels ("10" vóór "2" in Godot, numeriek in Node) en
  daarmee week `legal_actions` op de herbouwde staat in volgorde af van de
  volle staat. Semantisch onschuldig, maar de client hoort niet in iets te
  verschillen dat op de server niet verschilt.
- `net/event_codec.gd` (`EventCodec.van_json`): int-coercie (een signal met
  een int-parameter weigert een float, `_pawn_views.get(3.0)` is een miss),
  gesloten lijst Vector2i-sleutels, `bid` blijft float.
- `tests/ClientStateTests.gd` (in TestRunner en tests.ps1): twee echte
  L1-partijen op de campagne-regels (een met Krokodil), elke rustfase, beide
  kijkers, DOOR JSON-tekst: dezelfde legale acties, hetzelfde initiatief bij
  elke reveal, een gesloten lijst van toegestane afwijkingen in
  `state_to_dict` (pawns, all_cards, cards_defined, pools/cp/cp_bets/
  cp_bet_done/spawn_totaal, spawn_commits, doctrine_commits, rules,
  next_*_id; al het andere moet gelijk zijn), pionposities/eigenaar/type/
  actief gelijk, regels overleven de '?'-redactie. Plus PRE_GAME (eigen
  keuze niet opnieuw aangeboden, die van de ander blind), de vier sleutels
  heen en terug, en de codec-canary over alle client-events van een partij
  (inhoud én typen gelijk; faalt zodra de reducer een Vector2i-sleutel
  krijgt die de codec niet kent).
- Besluit (default, omkeerbaar): alleen `core_hash` als versiecheck; de
  server dicteert de regels per match. protocol.md herschreven.

Checks: ClientStateTests + ViewTests + AgentTests 253 asserts groen,
servertests 20/20 (worker-handshake met de nieuwe core-hash), tsc schoon,
uispel 777 zobrist gelijk, opname gelijk, play/vosview/meleecheck/naadcheck
PASS, simcheck 0 afwijkingen, fuzz 60 partijen 0 schendingen, volledige
suite 1848 asserts groen (0 fouten, 330 s).


## 3 september (avond, later) -- F4.3c: de bot-naad dicht

Alles wat game.gd namens speler 2 of "namens de klok" deed is nu dood pad
zodra `_ai == null`, en dat is precies de online-situatie: de tegenstander
is een andere client. Elke gewijzigde regel zit achter `_ai != null`, raakt
alleen de `_ai == null`-tak, of is de aanroep van een sessie-haak; vs-AI is
byte-identiek gebleven (zie checks).

- `_human_id`/`_ai_id` komen in `_start_match` uit `session.local_player_id()`
  en `Constants.opponent()`; voor vs-AI 1/2 zoals altijd.
- Guards om de AI-opstelling (`_finish_manual_placement`,
  `_confirm_placement`), de AI-bet en -define (`_on_define_confirmed`), de
  AI-spawn (CYCLE_SPAWN-tak; dit ruimde meteen de simcheck-scriptfout van
  juli op, `_ai` was Nil op die regel), de AI-koppeling (LINKING-tak van
  `_on_turn_changed`: zonder bot alleen de prompt), de AI-zet (ACTION-tak)
  en de AI-wolfstap (`HUD_WAIT_WOLF`).
- `_continue_after_reveal`: met bot de dubbel-ack-shim, zonder bot alleen
  `submit_ack_reveal(_human_id)`. De shim is online structureel onbereikbaar.
- `_start_phase_timer` leest `session.klok()`; zonder klok en zonder bot
  start er geen lokale timer, dus online kiest game.gd nooit zelf zetten,
  spawns of koppelingen namens de mens.
- Eén gate voor gedekte pionnen: de hp-blokjes en het karaktermodel vragen
  `session.pion_gedekt(id)`; offline exact de oude expressie, online straks
  het '?'-sentinel uit de view.
- `_player_color` hangt aan de seat (rood = 1, blauw = 2), net als de ringen.
- `_on_state_updated`: zonder bot `_sync_new_pawn_views` +
  `_update_piece_counts` (online komt het vijandelijke leger zo op het bord).
- i18n: `HUD_WAIT_OPPONENT`, `HUD_WAIT_WOLF` (beide `.translation` mee).

**Nieuwe check `-- naadcheck`** (capture): na de opstelling gaat `_ai` op
null; de mens speelt via het timeout-pad, de tegenstander dient buiten
game.gd om in (zoals een server). Eisen: niets crasht, game.gd dient nooit
iets namens speler 2 in, elke commit-fase wacht op de ander, zonder klok
geen lokale timer, de drie setup-rondes lopen uit tot de actiefase, in de
beurt van de ander gebeurt niets, en de resign van de ander eindigt netjes
in game_over. Uitslag: PASS, 0 fouten, 0 acties door game.gd, 20 rondjes.
(Eerste versie van het harnas ging ervan uit dat na één koppelronde de
actiefase komt; het zijn er drie.)

Checks: uispel 777 zobrist gelijk, opname gelijk, play/vosview/meleecheck
PASS, simcheck 0 afwijkingen ZONDER de oude game.gd-scriptfout, naadcheck
PASS, volledige suite 1808 asserts groen (0 fouten, 364 s).


## 3 september (avond) -- F4.3b: SessionInterface, game.gd praat via `session`

Eén naad tussen game.gd en "wie het spel bijhoudt". Nieuw
`scripts/core/session_interface.gd` (`class_name SessionInterface extends
Node`): de 11 signals, `state`, de volledige submit-set als stubs die luid
weigeren, `_relay_events` LETTERLIJK uit GameSession verhuisd, en zes haken
met offline-identieke defaults: `local_player_id()` (speler 1), `klok()`
(paar deadline/servertijd), `naam_van()`, `pion_gedekt()` (exact de oude
blokjes-expressie), `tegenstander_status()`, `is_online()`. GameSession
`extends SessionInterface` en IS daarmee de LocalSession; autoload-naam
blijft, tests, capture en de worker merken niets.

game.gd: `var session: SessionInterface`, `session = GameSession` als
eerste regel van `_ready`, en alle 136 `GameSession.`-voorkomens mechanisch
naar `session.` (hulpscript `tools/f43_vervang_session.py`, bewaard als
bewijs van wat er gebeurd is). `_connect_session_signals` is idempotent per
sessie-object (koppelt los van de vorige sessie, verbindt in de oude
volgorde) en verbindt twee nieuwe lege handlers `_on_doctrines_revealed` en
`_on_state_updated` (lichaam in c/g).

Twee lessen: (1) een nieuwe `class_name` staat pas na `godot --headless
--path . --import` in de class-cache; tot die tijd compileert alles wat hem
gebruikt niet en blijven headless runs hangen. Dus na elk nieuw script met
class_name eerst importeren. (2) De "record-diff leeg" uit het bouwplan kan
nooit: `meta.created` en `ts` per entry zijn wandkloktijd. Nieuw
`tools/vergelijk_opname.py` vergelijkt eind-zobrist, eindstaat en elke
entry zonder `ts`; dat is voortaan regressiestap 4.

Checks: `grep -c "GameSession\." game.gd` = 0 (alleen de toewijzing zonder
punt), uispel 777 zobrist `890b6cb4…` gelijk, opname gelijk (365 entries,
eind-zobrist 3bff2f11…), play/vosview/meleecheck PASS, GameSessionTests
100 asserts groen incl. de nieuwe interface-test, volledige suite 1808
asserts groen (0 fouten, 358 s), simcheck 0 afwijkingen.


## 3 september (later) -- F4.3a: nulmeting op game.gd-niveau

Eerste stap van het F4.3-bouwplan (`docs/F4.3-bouwplan.md`): een hard getal
voor "vs-AI blijft byte-identiek" dat de submit-VOLGORDE van game.gd dekt.
Simcheck, goldens en `-- record` lopen via GameSession en `_run_sim`, dus die
zien niet of game.gd de AI-opstelling vóór de mens indient, de AI-bet en
-define ná de mens, en de AI-spawn vóór de overlay. Nieuwe capture-modus
`-- uispel [seed]`: een volledige partij (Muis vs Wolf, AI easy) waarin de
mens uitsluitend via het bestaande timeout-pad speelt (`_timer_left = 0`,
dus `_process` vuurt `_on_phase_timeout`: auto-define, aanvul-spawn,
auto-link, greedy zet; opstelling en reveal-ack zoals `-- play`). Print
winner, acties, cyclus, duur en de eind-zobrist; exit 1 als de partij na 20
minuten niet uit is.

**Contract (seed 777, drie runs, alle drie gelijk):** winner=2, acties=270,
cyclus=6, zobrist `890b6cb46241617aa7de3189e622913fbe3089d72eb7e78ea6e75c1bc345b97d`,
duur 106-107 s (de AI-thread en de animaties lopen in echte tijd). Dat de
zobrist over drie runs gelijk is betekent dat de AI-thread-timing de
actievolgorde niet beïnvloedt; het sterke contract geldt dus, niet het
zwakkere "winner + cyclus + acties".

Referentie-opname vóór enige clientwijziging: `-- record user://ref_voor.json
easy easy muis wolf 777` (275 KB, buiten de repo in `user://`). Elke
F4.3-stap eindigt met een nieuwe opname naar `user://ref_na.json` en een
lege `fc`.

Audit-greps (uitgangspunt voor stap b): `GameSession\.` in game.gd = 128;
membervariabelen van het type Pawn of Card in game.gd = 0 (goed: online wordt
de staat per batch vervangen, niets mag een oude Pawn vasthouden); private
leden van game.gd die capture.gd aanstuurt en dus in F4.3 hun naam houden:
`_start_match` (18x), `_confirm_placement` (17), `_on_link_pawn_clicked` (13),
`_on_link_card_picked` (13), `_pawn_views` (12), `_continue_after_reveal`
(12), `_pawn_has_room` (11), `_select_pawn` (7), `_human_doctrine`,
`_camera`, `_ai_doctrine` (6), `_board`, `_ai` (4), en verder `_valid_moves`,
`_refresh_all`, `_raycast_pawn`, `_on_placement_tile_clicked`, `_valid_shots`,
`_tiles`, `_spawn_footprints`, `_on_tile_clicked`, `_on_pawn_clicked`,
`_update_placement_ghost`, `_update_health_bars`, `_undo_placement`,
`_uncouple_cascade`, `_toggle_ambiance_panel`, `_spawn_wheel_tracks`,
`_show_rules_overlay`, `_show_opponent_menu`, `_show_doctrine_menu`,
`_selected_pawn_id`, `_pick_move_tile`, `_hp_bars`, `_build_pawn_views`,
`_begin_manual_placement`.

Checks: uispel 3x gelijk, simcheck 0 afwijkingen (suite en fuzz ongewijzigd
sinds F4.2b: alleen capture.gd kreeg een modus).


## 3 september -- F4.2b: het stream-lek gedicht voordat de client bestaat

Max: "waar staan we met de multiplayer mode" en daarna "laten we gewoon
beginnen". Eerst een volledige herlezing van F4 (zeven lezers, een
kritiekronde, zes toetsen met echte metingen). Stand: F4.0-F4.2 staan en zijn
vandaag opnieuw groen gemeten (tsc schoon, 12/12, worker 5-16 ms per actie),
F4.3 is nul (geen regel netwerkcode in de client, ook niet in zijtakken), en
sinds 9 augustus raakte geen enkele commit server, engine of worker. De
meevaller: `Agent.reconstruct_state` bouwt uit de fog-view al een speelbare
staat (4672/4672 identieke legale acties in een proef over alle fasen), dus
render-vanaf-snapshot heeft een fundament.

**De tegenvaller, en die is vandaag gedicht:** de client-stream van F4.2 was
niet fog-veilig. `payload.hash` was de zobrist over de VOLLEDIGE staat, dus
inclusief blinde factiekeuze, ongeonthulde kaartdefinities, spawn-commits en
CP-inzet, en met dezelfde engine te brute-forcen. Met de echte worker
aangetoond: factiekeuze uit 6 kandidaten, kaartdefinitie (Muis, 1296
combinaties) in 11,5 s gevonden. Daarnaast passeerde `cp_bet {player_id}`
beide filters terwijl de view de vijandelijke inzet bewust verbergt
(CpTests). En de WebSocket had geen auth, `/events` geen seat-check. De
nulmeting van 9 augustus boekte "admin-events gefilterd" als dicht; dat klopte
voor die twee events, maar de Node-redactie werd door geen test bewaakt en de
canary testte vijf synthetische types van de achttien.

Gebouwd (F4.2b):

- **Engine:** `View.SERVER_ONLY_EVENTS` (cycle_admin, cp_admin, cp_bet) naast
  `View.CLIENT_EVENTS`; `client_events()` volgt de lijst. Nieuwe canary in
  ViewTests laadt `reducer.gd`, loopt alle `EV_`-constanten af en faalt op een
  event dat in geen van beide lijsten staat (of in beide).
- **Worker:** meldt `server_only_events` in de handshake.
- **Node:** `naarClientRij` levert alleen nog `{events}` (geen hash), de lijst
  bevat `cp_bet`, en `GodotWorker.start()` vergelijkt de gemelde lijst met de
  eigen en weigert te starten bij verschil. Ontbrekende Godot-binary: nette
  fout met het pad (er was geen `error`-luisteraar op het kindproces, dus het
  hele Node-proces viel om). `/events` eist een seat; de WS eist identiteit
  (Bearer of `?token=`) en een seat, sluitcodes 4401/4403/4404. Nieuw
  `GET /matches/:id` (status, seats met namen, winnaar, eindreden, hoogste
  seq). Na `klaar` zegt `/acties` "De match is afgelopen".
- **Tests:** 18/18 (6 nieuw), waaronder de eerste echte WebSocket-test (Node
  22 heeft een ingebouwde client; `app.listen` op poort 0). De pariteitstest
  leest de eind-hash nu uit het server-only log en klopt nog.
- **Docs:** protocol.md, server/README.md (incl. de verplichte `--import` op
  een verse checkout: zonder `.godot/` compileert de engine niet; gemeten 110 s
  en ~7,5 GB piek), masterplan nulmeting + F4.2b.

**De review erachteraan (32 agents, elke bevinding door twee sceptici) vond
nog een laag dieper:** een event-filter dicht niet dat een actie een RIJ is.
Een losse `bet_cp` is een eigen `seq` met `player_seat`, en wie in het
define-venster een vijandelijke rij ziet zonder dat `enemy_has_defined`
omslaat, weet dat er ingezet is. Elke afzender in de repo stuurt bovendien
alleen een `bet_cp` bij een inzet > 0. Oplossing in de engine, zonder
regelwijziging: `define_cards` kent het optionele veld `cp_bet` (zelfde
checks als de losse inzet, zelfde boeking, byte-identieke eindstaat, veld
alleen aanwezig als > 0 dus alle logs en goldens blijven gelijk). Online is
dat de enige vorm; de losse `bet_cp` blijft legaal voor offline en arena.
Verder uit de review: de WS-handler kon een abonnement eeuwig laten hangen
als de client sloot tijdens de auth-awaits (vlag vóór de awaits); `?token=`
stond in het access-log (request-serializer redigeert hem); de idem-lookup
stond ná de statuscheck, dus de blinde herhaling van een partij-beëindigende
actie kreeg 409 in plaats van het oorspronkelijke antwoord (volgorde
omgedraaid, test erbij); "Node weigert te starten" was lui en per verzoek
met twee Godot-starts (worker start nu eager in `bouwApp`, blijvende fouten
worden onthouden); en worker-fouten gingen met serverpad als 500-body naar
de client (`setErrorHandler`: neutraal, details in het log). Geaccepteerd en
gedocumenteerd: een lege vijandelijke pool is afleidbaar uit het meteen
sluiten van de spawn-gate, en 404/403 verraadt dat een match-id bestaat.

Niet gedaan, bewust: sessies verlopen nog niet, geen rate limiting, geen
protocol_version/rules_hash-handshake (klein, hoort bij de eerste client),
geen klokprofiel (besluit van Max). De volgende stap is F4.3: SessionInterface
+ LocalSession eerst (vs-AI byte-identiek), dan RemoteSession + lobby, dan
render-vanaf-snapshot op `reconstruct_state`.

Checks: volledige Godot-suite 1795 asserts groen (0 fouten, 364 s parallel;
vóór de review-fixes 1775), simcheck 0 afwijkingen, fuzz 30 partijen 0
schendingen, servertests 20/20, tsc schoon.

Meteen erachteraan het **F4.3-bouwplan** laten ontwerpen (drie architecten,
drie juryleden, synthese): `docs/F4.3-bouwplan.md`, elf substappen a t/m k
met een vaste regressieset en de open besluiten voor Max onderaan. Terzijde: simcheck laat sinds juli een
script-fout uit game.gd:1550 zien (`_ai` is Nil in de sim-context bij
CYCLE_SPAWN); staat los van deze stap, wel opruimen.


## 26 augustus -- de eerste ECHTE big bros: cavalerie voor muis, leeuw en varken

Max leverde 15 cavalerie-blends (Mouse/Lion/Pig x base/spd/hp/atk/mix) in de
inbox, plus (via zijn texture-workflow, aangewezen in Downloads) de eerste
team-atlassen: rood en blauw voor de muis-base. Precies wat het systeem van
de 16e verwachtte: losse lijfdelen, een melee-clipset (Idle 1-3, Walking 1-2,
zes Death-varianten, Attack/Thrust/Pommel strike, Ready, Hit) en het wapen
bot-geparent aan mixamorig:RightHand. Renders bevestigden identiteit en
wapens VOOR de pijplijn draaide: de rat stoot met een beugelgevest-sabel, de
leeuw met een korte kling, het varken hakt met een bijl.

Drie dingen aangepast tijdens het verwerken:

- **Tripo-gruis**: de leeuw- en varken-blends dragen naast het echte wapen
  geskinde tripo-fragmentjes van 1 driehoek. Beide exportscripts filteren nu
  alles onder de 20 tris (anders: zwevende splinters in wapen-glb en model).
- **"Pommel strike"** herkend als melee-variant (woord "strike" in
  CLIP_WOORDEN); de "Run"-clips blijven bewust ongebruikt (niet gedetrende
  root-motion zou laten wegglijden als walk-variant).
- **_wapencheck.gd** bestrijkt nu infanterie EN cavalerie (ontbrekende
  cavalerie is daar geen fout: beer/wolf/krokodil komen nog).

Verwerking: drie-export-pijplijn x 15 (melee-glb, karakter-glb met wapen,
kwartslag-fix + gibs), 0 fouten. Godot-import liep dit keer via Max' OPEN
editor (live mee-importerend); de team-png's kregen hun .import
voorgeschreven (md5-pad-formule geverifieerd, mipmaps + 1024-limiet) zodat
de eerste import meteen goed staat. De rood/blauw-atlassen dekken alleen
muis-base; de andere 14 modellen houden hun neutrale glb-texture tot Max
meer atlassen genereert.

Voor Max: tuner-pass (schaal/positie -- de big bro hoort boven zijn
infanterie uit te torenen, auto-fit maakt ze gelijk), en de resterende
team-atlassen + de drie ontbrekende facties wanneer hij wil.

NAKOMER 2 (zelfde dag, Max: "je hebt ook een jump en dan een melee, dat is
voor rush en attack cav -- check ook alle gibs"): de charge gebruikt nu de
clips waarvoor ze bedoeld zijn. "Run"/"Run and jump" heten na het laden
rush1/rush2 (loopend, in-place), "Standing Melee Run Jump Attack" heet
"charge". De sprong-aanval droeg ~174 eenheden z-drift (hij rende zelf naar
voren en zou voorbij het doelwit schieten); de fix-pass detrend nu ook
run/jump-clips (case-insensitive, meteen de oude kleine-letter-blindheid
van walk/idle gefikst) en alle 15 cavalerie-glbs zijn opnieuw door de pass.
De charge-flow in game.gd is in fasen: aanrijden op de rush-clip, bij
aankomst de sprong-stoot (play_charge, terugval play_melee), en de klap op
rij-tijd + charge_hit_delay (0,35 default, tunebaar) in plaats van de vaste
0,4s dwars door het rijden. Meleecheck heeft er een DERDE scenario bij dat
het hele verloop bemonstert: rush1 -> charge1 -> (die2: de ruiter sneuvelde
aan de terugslag, ook dat klopt) -- PASS. En de gibcheck is verbreed naar
ALLE 45 gibs-bestanden: 11 delen infanterie / 10 cavalerie (geen hoedje in
die blends), ledemaat-namen overal vindbaar, geen stapels -- PASS.

NAKOMER (zelfde dag, Max: "alle cav maken ook gebruik van hun wapen"): de
aanval-flow bleek al goed (aangrenzende cavalerie-aanval en de charge gaan
allebei door play_melee, nooit door het musket-pad), maar het bewijs
ontbrak. `-- meleecheck` meet nu TWEE scenario's: de infanterie-bajonet en
de cavalerie-stoot, zelfde choreografie-eisen (stoot-clip speelt, aanvaller
blijft op zijn vak tot stoot-frame + opruk-vertraging). Uitslag: infanterie
melee2 en cavalerie melee3 (een van de nieuwe wapen-clips), allebei
vertrek 1,40s bij 1,50 verwacht -- PASS. De cavalerie zwaait dus echt met
zijn ingebakken sabel/bijl in het echte spel.

Drie verzoeken van Max in een middag, allemaal rond "de archetypes moeten
visueel uit elkaar":

1. **Cavalerie-prompts** (MODEL-WISHLIST): elk archetype een eigen
   uitrustingsstuk op een eigen plek op het lijf (base X-bandeliers op de
   borst, spd verenpluim op de kop, hp kuras om de romp, atk spikes op de
   schouder, mix dekenrol dwars over de borst), elke factie zijn gehavende
   factie-hoed (zelfde hoeden-taal als de infanterie), en de bouw-woorden
   extremer zodat de generator ze niet afvlakt. Zelfde slag voor de
   **artillerie**: houding van het bemanningsdier (staat op / duwt / zit op
   de loop / hangt over de loop / zit op een kruitvat) plus opgesjorde
   stukken -- alles vast aan het kanon, want dat rolt over het bord.
2. **Melee-wapens** (3c-2): type-variatie ook BINNEN de factie (was: muis en
   leeuw vijf klingen, varken vijf bijlen, beer vijf lansen). Nu volgt het
   TYPE het archetype (base sabel, spd lans/piek, hp korte bijl, atk het
   overmaatse familie-stuk, mix kort en kaal) en zit de factie in materiaal
   en afwerking.
3. **Ingebouwd in het spel**: de big bro draagt zijn melee-wapen zoals de
   infanterie het musket. Zelfde systeem, twee routes: komt het wapen
   INGEBAKKEN in het geanimeerde model mee (bot-geparent, tripo_node of een
   naam als sabre/axe/lance -- woordenlijst WAPEN_WOORDEN, gedeeld met de
   gibs-uitsluiting in de pijplijn), dan blijft het staan en zwaait het mee;
   anders hangt het spel `cavalry_<arch>_melee.glb` (terugval
   `<factie>/melee.glb`) aan de rechterhand. Doodsworp identiek aan het
   musket, kletter-categorie `val_melee`. Artillerie doet expliciet NIET mee
   in de wapendetectie ("gunner"/"gun_carriage" zou vals matchen en de
   team-kleuring van kanon-modellen slopen).

Een review-workflow (2 lenzen, geverifieerd) ving voor de commit drie echte
gaten in de geluidskant: val_melee had geen tuning-entry (zou 9 dB te hard
spelen), de BANK-placeholder zou een echte opname voorgoed verdringen (nu:
geen placeholder, nette terugval op val_prop, en val_melee.wav doet vanzelf
mee zodra hij er ligt + rij in SOUND-WISHLIST 7bis), en de tuner-Geluid-tab
kende de categorie niet. Dat laatste was een kopie van de categorie-regel
in de tuner -- precies de divergentie die de audit van 30 juli al eens
wegwerkte -- dus de regel is nu een gedeelde static
(`PawnView.val_categorie_voor`) die tuner en spel allebei gebruiken.

Er bestaan nog geen cavalerie-karaktermodellen of melee-glbs: tot Max ze
genereert vecht de big bro met blote handen (lege wapen-file = nette
no-op) en verandert er niets aan het zichtbare spel.

Max zag wat ik over het hoofd bleef zien: "de animator neemt altijd de musket
al mee in de animaties" -- waarom zouden we een stijve prop in de hand hangen
als de generator het wapen al meebakt? Onderzoek bevestigde het mechanisme:
de `tripo_node` is BOT-GEPARENT aan `mixamorig:RightHand` (geen skinning
nodig), dus hij richt, draagt en steekt in elke Mixamo-clip exact mee. Godot
maakt daar bij import vanzelf een BoneAttachment3D van.

Omgebouwd ("ja dus voor alle facties he doe maar"):

- `pawn_view.gd`: draagt het model een MEEBEWEGEND ingebakken wapen (geskind
  of bot-geparent) en ligt er een musket-glb naast, dan blijft het ingebakken
  musket gewoon zichtbaar -- geen prop, geen musket-tuning meer nodig. Bij de
  dood wordt het bot-geparente mesh ZELF losgekoppeld en weggeslingerd:
  exact vanaf de plek, stand en maat waarmee de pion hem vasthield (idee van
  Max: "als iemand sterft net als een gibs spawnen vanaf die plek dat hij
  het vast houdt"). Geskinde exemplaren: verbergen + statische glb op de
  handpositie. Team-texture blijft van het wapen af (eigen atlas). Vangrails:
  figuranten (trommel/vaandel), statische bakken en modellen zonder
  musket-glb vallen automatisch terug op de oude prop-route.
- `blender_export_blend.py` houdt het musket voortaan IN de karakter-export
  (`--zonder-wapen` voor het oude kale gedrag); `blender_merge_character.py`
  weert wapen-meshes uit de gibs (anders vliegt het musket dubbel -- het
  spook-gib-probleem van gisteren).
- Alle 15 beer/krokodil/wolf-modellen her-geexporteerd uit de inbox-blends
  (15 exports, 15 gibs a 11 delen, 0 fouten).
- Nieuw controlegereedschap `tools/_wapencheck.gd` (na `--import` draaien):
  **27 van de 30 modellen dragen een meebewegend, getextureerd musket** --
  ook muis-spd/hp/atk/mix en alle leeuwen, die bleken het al die tijd al bij
  zich te hebben. Alleen muis-base, varken-spd en varken-mix blijven op de
  prop-route (geen ingebakken wapen in die bestanden). Geen wapen meer in
  welke gibs dan ook.

Checks: testsuite 1716/1716, simcheck 0 afwijkingen, meleecheck PASS,
tunercheck 30/30 + gibs compleet + roundtrip byte-identiek, play OK. De
`choose_spawn`-errors die in de simcheck-log ratelen zijn PRE-EXISTING
(empirisch bewezen: HEAD-pawn_view geeft dezelfde 70) -- los klusje
aangemeld: null-guard in game.gd:1550.

Een adversariele review (3 lenzen, elk geverifieerd) ving nog een echte bug
voor de commit: de baked-route liet `_weapon_tune_key` op de default
"mouse/musket" staan, waardoor de hand-schuifjes in de Model-tuner voor 27
modellen stilletjes de MUIS-afstelling zouden overschrijven. Gefikst (sleutel
wordt nu ook op de baked-route gezet); tunercheck + meleecheck opnieuw groen.

LET OP: de losse achtergrondtaak "Strip tripo-duplicaat uit lion/pig-modellen"
(worktree objective-curie-296992, commit c65d154) doet precies het OMGEKEERDE
van dit besluit -- die strippt de ingebakken muskets die het spel nu
gebruikt. NIET mergen; gewoon weggooien.

Wat Max nog zelf beoordeelt: hoe het er in het echt uitziet (tuner +
potje) -- de musket-schuifjes in de tuner doen voor ingebakken-musket-
modellen niets meer, dat is verwacht.

NAKOMER (zelfde dag): Max ving in het spel laadfouten -- "Resource file not
found: infantry_base_Color_....jpg". Mijn fout: de losse jpg's naast de
nieuwe glb's waren GEEN Blender-bijproduct maar door GODOT bij de import
UITGEPAKTE textures (embedded_image_handling=extract; de geimporteerde scene
verwijst ernaar). Ik controleerde alleen de glb (textures embedded: klopt)
en niet de geimporteerde scene, en gooide ze weg. Herstel: import-cache voor
de infanterie-glbs gewist, her-import pakt ze opnieuw uit, en nu gewoon
GECOMMIT -- net als de musket-jpg's van de 15e, die om precies dezelfde
reden bestaan. Wapencheck PASS, tunercheck 0 fouten, play schoon. Les: "dit
bestand gebruikt niemand" bewijs je op de GEIMPORTEERDE resource, niet op de
bron; en verwijderen hoort VOOR de laatste check-ronde, niet erna.


## 15 augustus (avond) -- CORRECTIE: de tripo_node WAS het musket

Max bleef aandringen ("de musketten zitten in die files") en had voor de
derde keer vandaag gelijk. De `tripo_node_<uuid>`-mesh die ik overal als
"karakter-duplicaat" heb weggeknipt is het INGEBAKKEN MUSKET dat de
generator meelevert -- het staat nota bene in de docstring van
`blender_strip_baked_weapon.py`, die op 4 augustus voor precies dit doel is
gebouwd. Mijn driehoeken-telling zette me op het verkeerde been (een musket
is ~900 tris, een laagpoly-karakter ook); een headless RENDER (musket met
bajonet, onmiskenbaar) besliste het.

Wat er klopte en wat niet: de tripo_node uit de karakter-glbs knippen was
toevallig JUIST (het spel verbergt hem toch en hangt zijn eigen prop op;
scheelt dode geometrie), en hem uit de twaalf oude gibs-bestanden strippen
ook (een musket hoort geen lichaams-brokstuk te zijn; het echte
musket-prop vliegt apart weg). Maar het wapen WEGGOOIEN in plaats van
exporteren was fout, en de verhalen in twee commits en dit logboek noemden
hem ten onrechte een duplicaat.

Rechtgezet: `tools/blender_export_musket.py` (de blend-variant van
--wapen-uit) haalt het wapen los -- armature eraf, stand behouden, texture
naar 1024 -- en alle VIJFTIEN musketten van beer, krokodil en wolf staan nu
als `infantry_<arch>_musket.glb` naast hun model, waar `weapon_for()` ze
vanzelf vindt. Elke factie draagt nu zijn eigen wapen; de "ongewapend tot
Max genereert"-melding van vanmiddag vervalt.

Les, hard geleerd: een naam-scan is geen inhouds-controle. RENDER het
gewoon even -- kijken kost een minuut, en drie keer "Max had gelijk" op een
dag is het bewijs dat de bestanden beter wisten dan mijn aannames.


## 15 augustus (vervolg) -- vos-infanterie + muis-musket: het modelbord is VOL

Max wees op twee dingen die ik had gemist, allebei terecht. (1) De
wolf-mappen STONDEN al in de inbox -- mijn eerste inventaris was afgekapt op
40 regels en de wolf sorteerde achteraan. Alle vijf de vos-archetypes zijn
alsnog door dezelfde pijplijn: tunercheck zegt nu 30/30 modellen, gibs
compleet, 0 fouten -- ALLE ZES de infanterie-facties zijn binnen. (2) "De
musketten zitten er ook in": in de vijftien blends bleek GEEN enkel
musket-object te zitten (per blend gecontroleerd op mesh-namen), maar in de
inbox-root lag wel de nooit verwerkte muis-base-musket van 5 augustus. Die
staat nu als `infantry_base_musket.fbx` (+ twee png's met size_limit 1024 en
mipmaps, conform checklist E) naast de andere vier muis-musketten.

Wapenstand per factie: muis/varken/leeuw volledig bewapend; beer, krokodil
en wolf spelen ONGEWAPEND tot hun musketten gegenereerd zijn (de zoeker
`weapon_for` vindt per-model eerst, dan <factie>/musket.glb|fbx, en die
bestaan voor deze drie niet -- prompts staan in MODEL-WISHLIST par. 7b).

Les voor de inventaris: nooit een `find | head` als volledigheids-check.

**Max' vervolgtest ving de echte bug: er vloog NOOIT een ledemaat af, bij
geen enkele factie.** De bestanden waren goed; de runtime-koppeling niet.
`_fling_single_gib` vergeleek gib-namen met `to_lower()`, maar Godot hernoemt
`Arm.L.001` bij het importeren naar `Arm_L_001`, en "arm_l_001" bevat "arml"
niet. Alleen het hoedje matchte (geen scheidingsteken in de naam), dus doden
oogden levendig genoeg om dit maandenlang te verbergen. De levende kant
gebruikte al de kale-naam-functie (strip alles behalve letters); nu de
gib-kant ook -- een regel. Bewijs vooraf met een naam-dump over de echte
scenes (oud=false, kaal=true voor arml/armr/legl/legr bij muis, beer en
wolf), bewijs achteraf met `-- meleecheck` (PASS) en `-- play`. Het VOLLE
uiteenklappen (kanon) werkte altijd al: dat pad pakt alle delen naamloos.

**En de gib-vraag van Max ("komen de armen en benen wel los?") ving een oude
bug.** Een meetscript (`tools/_gibcheck.gd`: delen tellen, hoogte-spreiding
van de zwaartepunten, stapel-detectie) bewees dat de NIEUWE facties perfect
uiteenklappen (11 delen, spreiding ~0,8 zoals de muis-referentie) -- maar
ving bij die referentie zelf een uitschieter: muis-atk had 12 delen waarvan
een op 18 eenheden afstand. Bleek in TWAALF oude gibs-bestanden te zitten
(heel leeuw, vier muis, drie varken): het tripo-duplicaat als spook-brokstuk
dat bij een volle gib uit het niets komt aanvliegen.
`tools/_strip_gib_verstekeling.py` heeft alle twaalf geschoond; de scan
staat nu op nul verstekelingen over alle 30 gibs-bestanden. De GEANIMEERDE
leeuw/varken-glbs dragen het duplicaat nog wel (alleen bloat, geen
zichtbare fout) -- daarvoor staat een bijgewerkte opruim-chip klaar.


## 15 augustus -- wasbeer- en hagedis-infanterie erin (Beer + Krokodil compleet)

Max leverde tien .blend-bestanden in de inbox (`assets/new 3d models/`): de
volledige infanterie-archetypes voor Beer (wasbeer) en Krokodil (hagedis),
base/spd/hp/atk/mix. Alle tien verwerkt; het statusbord (`-- tunercheck`)
staat nu op VIER complete infanterie-facties (muis, varken, leeuw, beer,
krokodil = vijf zelfs) met gibs compleet en 0 fouten. Alleen de
Wolf-infanterie (de vos) ontbreekt nog.

**De route is nu een pijplijn** in plaats van handwerk:

1. `tools/blender_export_blend.py` (nieuw): .blend -> geanimeerde .glb.
   Verwijdert de `tripo_node*`-mesh (het onopgeknipte generator-origineel dat
   naast de losse delen blijft hangen -- dubbele geometrie plus een tweede
   4K-textureset), ruimt wees-afbeeldingen op, verkleint textures naar 1024
   en exporteert met ACTIONS-modus (Mixamo-namen blijven; het spel vertaalt
   ze bij het laden).
2. `blender_merge_character.py --base <glb> --gibs` (bestond al): de
   kwartslag-fix plus de statische gibs-glb uit de losse delen.

Resultaat per model: ~1,3 MB geanimeerd (11 delen, 17 clips) + ~250 KB gibs.
Ter vergelijking: de leeuw-modellen dragen het tripo-duplicaat WEL mee
(inclusief een compleet lijf als gib-brok) -- daar staat een opruim-chip voor
klaar (taak "Ontdubbel lion/pig-modellen").

**Twee near-misses die de moeite van het onthouden waard zijn:** de inbox-map
was NIET gitignored -- 984 MB aan blends was bij de volgende `git add -A`
het repo ingegaan (nu in .gitignore, plus een .gdignore zodat de editor er
niet in gaat scannen). En de teamkleur-textures (`_red`/`_blue` png's) zaten
niet in de upload: beer en krokodil spelen net als de leeuw op hun ingebakken
textuur tot Max die genereert (prompts in MODEL-WISHLIST par. 7).

Checks: import schoon, tunercheck 0 fouten (25 van 30 infanterie-modellen
geleverd, gibs compleet, tuner-opslag byte-identiek), cliplengtes vertaalt
alle 17 clips correct per model, play draait.


## 9 augustus (avond, later) -- F4.2 af: de server is nu een scheidsrechter

**De server echoot niet meer, hij oordeelt.** Elke actie die via
`POST /matches/:id/acties` binnenkomt gaat nu door de Godot-worker: een
headless engine-proces (`tools/server_worker.tscn`) dat door de Node-backend
wordt gespawnd en beheerd, en dat exact dezelfde `core/`-bestanden draait als
het spel zelf. De worker is stateloos: per verzoek krijgt hij het jongste
snapshot plus de staart van acties (het MatchLog-fold-formaat), herbouwt de
staat, en haalt de actie door Validator en Reducer. Illegaal = 422 met de
validator-tekst. Node bewaart een rij per actie (action/events/hash -- het
MatchLog-formaat, dus replay en battlereport zijn gratis), een snapshot elke
50 acties, en de servertijd per rij (F4.0b). `GET /matches/:id/view` geeft je
gefilterde fog-view (het F4.3-render- en reconnect-startpunt), `GET /versie`
de core-hash zodat een client weigert met een andere engine te praten.

**De pariteitstest is de kroon op vier dagen werk**: een volledige partij,
offline opgenomen met `capture -- record` (muis-wolf, seed 777), actie voor
actie door de server nagespeeld -- inclusief de blinde factie-keuzes vooraf,
want online begint in PRE_GAME (F4.0) -- eindigt op EXACT dezelfde
zobrist-hash als de offline opname. De server en het offline spel zijn
bewezen hetzelfde spel. En de kill-test: worker hard doodgemaakt midden in de
partij, volgende actie herstart hem vanzelf, en de idem-herhaling van voor de
kill blijft een herhaling -- geen dubbele events (de database schrijft pas na
een worker-antwoord, dus een gestorven verzoek heeft niets veranderd).

**Drie afwijkingen/vondsten, alle drie gedocumenteerd:**

1. **Geen Redis maar een synchrone zijspan** (masterplan noemde Redis-jobs).
   Zelfde stateloosheid, zelfde schaalbaarheid (N workers), een bewegend deel
   minder. Redis komt terug bij de matchmaking-wachtrij (F4.4+).
2. **TCP in plaats van stdio**: `OS.read_string_from_stdin` blokkeert op een
   open pijp tot 64K of EOF -- een gesprek over stdin/stdout loopt dus vast.
   En stdout door een pijp buffert tot exit zonder
   `application/run/flush_stdout_on_print=true` (staat nu aan in
   project.godot). En een worker als `--script` faalt omdat autoloads dan
   niet laden (Constants) -- vandaar een scene, net als capture.tscn.
3. **readline is gevaarlijk op sockets** (Node/Windows): sterft de peer
   terwijl er net geschreven is, dan komt er een TWEEDE ECONNRESET die langs
   elke error-luisteraar gaat (geisoleerd bewezen in een 40-regelig
   experiment). De brug knipt regels daarom zelf op 'data'-events.

Checks: 12/12 server-integratietests groen zonder onafgevangen fouten
(pariteit, kill, 422, idem, seq-conflict, view-lek, accounts), tsc schoon,
Godot-suite + simcheck groen (engine ongewijzigd; alleen de flush-vlag en
twee nieuwe tool-bestanden erbij).


## 9 augustus (avond) -- F4.1 af: de backend staat, ondanks Docker

**Het skelet van de online-server bestaat en zijn tests zijn groen.** `server/`
is een Node 22 + Fastify-backend met het schema uit bouwplan §5.1 (users,
sessies, vrienden, matches, seats, event-log, snapshots; ratings en
campagnetabellen alvast leeg erbij, arena-tabellen bewust niet -- B10),
accounts §9.1 (gast-eerst op device-token, e-mail-upgrade voor cross-device,
profaniteitsfilter met leet-normalisatie, avatar, vriendcodes in het
31-alfabet) en het actieprotocol uit §10: `POST /matches/:id/acties` met
`seq_expected` + `idem_key`, idempotentie via een unieke database-index,
seq-conflict = 409 mét inhaal-events, WebSocket per match plus een
inhaal-endpoint. Contract in `docs/protocol.md`. In F4.1 echoot de server
acties (`action_accepted`); F4.2 hangt de Godot-worker ertussen die er echte
reducer-events van maakt, zonder de 200/409/idem-semantiek te raken.

**De Docker-saga, voor wie hier later iets mee moet.** Docker Desktop start op
deze machine niet. Elke start maakt AF_UNIX-socketbestanden aan
(`run/dockerInference`, `docker-secrets-engine/engine.sock`) en crasht bij een
VOLGENDE start op het verwijderen ervan: fout 1920, "het systeem kan geen
toegang verkrijgen tot het bestand". Die bestanden zijn ook handmatig
onverwijderbaar -- del, fsutil reparsepoint delete: alles 1920 -- en dat
overleeft een herstart van Windows, dus het zijn geen vastgehouden handles
maar kapotte/geblokkeerde reparse-points (Windows 11 26200, alleen Defender).
Mappen HERNOEMEN werkt wel, maar elke nieuwe crash laat nieuwe restanten
achter: klop-de-mol. Vier startpogingen, toen gestopt met vechten.

**De uitweg stond al in het masterplan: lokale MySQL.** MySQL 8.0.44 als
zip-zonder-installatie in `~/fogofwar-mysql/` (geen adminrechten, alleen
127.0.0.1:3316), starten met `server/db-lokaal.ps1`. De integratietests
kregen een schakelaar: `FOW_TEST_DB_URL` gezet = die server (de database uit
de URL wordt per run GEWIST), niet gezet = testcontainers zoals gepland (CI).
Zelfde tests, zelfde dekking. Redis is pas in F4.2 nodig (de worker is de
enige consument); tegen die tijd Memurai lokaal of Docker op de droplet.

Onderweg nog twee lessen: vitest/vite zoekt omhoog naar een postcss-config en
vond er een uit een ANDER project in de thuismap (opgelost met een eigen
`vitest.config.ts`: css.postcss leeg), en de migratie-splitser gooide een heel
SQL-blok weg omdat het met commentaarregels begon (commentaar wordt nu per
regel gestript -- de FK-fout "Failed to open the referenced table" was het
symptoom).

Checks: `npx tsc --noEmit` schoon, 8/8 integratietests groen tegen een echte
MySQL 8.0.44. De Godot-kant is deze commit niet aangeraakt.


## 9 augustus (later) -- F4.0b+c: kloktijd in het log, event-stream gefilterd

De twee bovenste restgaten uit de F4-nulmeting, allebei klein maar dragend:

**F4.0b — het log draagt nu de kloktijd.** De reducer zet `turn_deadline` en
eet de bank op basis van `now_ms`, en die velden zitten in de zobrist-hash.
Maar `MatchLog.record` sloeg de tijd niet op en `fold` speelde zonder tijd af:
elke partij MET klokken was dus niet hash-getrouw na te spelen -- precies het
mechanisme waar reconnect, replay-verificatie en de F4.5-solo-sync op leunen.
Nu: `record(..., now_ms)` schrijft het veld alleen als er echt een tijd was
(oude logs blijven byte-identiek), `fold` geeft het door aan `Reducer.apply`.
GameSession's `submit_claim_timeout` loopt nu ook gewoon door `_apply_action`
(scheelt een gedupliceerd pad) en de tijd reist mee het log in.

**F4.0c — `View.client_events()` is de poort voor de event-stream.** De
reducer-events zijn bijna allemaal blind-veilig, maar EV_CYCLE_ADMIN en
EV_CP_ADMIN dragen de saldi van BEIDE kanten en stonden al sinds F2.2 in de
code gemarkeerd als "server/log-only, de F4-event-stream MOET dit redigeren".
Die verplichting is nu een functie in plaats van een comment: de filter houdt
die twee tegen, al het andere gaat 1-op-1 door. Eigen saldi bereiken de client
toch al via zijn view; de battlereport leest ze post-match uit het log.
Canary-test op zowel synthetische als echte reducer-events (een campagne-
define met CP-inzet produceert het admin-event; na de filter is hij weg en de
reveal niet).

Daarmee is de F4-nulmetinglijst: twee van de zeven dicht op de eerste avond.
De volgende drie zijn clientwerk (render-vanaf-snapshot, camera-flip,
ack-shim) en twee zijn serverwerk zodra Docker er staat.


## 9 augustus (middag) -- F4 gestart: verkenning + de factie-keuze zit in de engine

Max: "lets go online." F4 is open. Eerst vijf verkenners de code in gestuurd om
het online-plan van 3 juli tegen de werkelijkheid te houden, en dat scheelde
een hoop dubbel werk: **vrijwel elk engine-gat uit dat plan is sindsdien al
gedicht** door F0.4-F0.8 (RESIGN, per-speler reveal-ack, klokken met
CLAIM_TIMEOUT en per-fase defaults, View.for_player als kant-en-klare
client-payload, kaart-identiteit, en V0 heeft de remise-kwestie opgeheven).
De volledige nulmeting met de zeven ECHTE restgaten staat in het masterplan
onder F4; de twee belangrijkste: MatchLog slaat `now_ms` niet op (partijen met
klokken zijn niet hash-getrouw te folden) en game.gd rendert van de volle
staat in plaats van uit views (render-vanaf-snapshot is de grote clientklus).

**F4.0 gebouwd: de blinde factie-keuze als engine-actie.** Het laatste gat uit
de verkenning. CHOOSE_DOCTRINE is alleen legaal in PRE_GAME, een keer per
speler, en volgt exact het DEFINE/SPAWN/BET_CP-patroon: blinde commit in
`doctrine_commits`, gate-check na elke commit, simultane onthulling. Beide
binnen -> doctrines toegepast, `init_pools()` (de startreserve hangt aan de
comp!), EV_DOCTRINES_REVEALED, opstelfase open. Vanaf dat punt is de partij
byte-identiek aan een die via `start_new_game` over PRE_GAME heen sprong.
Timeout in PRE_GAME = standaard-factie voor de slaper. De view toont je eigen
commit en van de ander alleen DAT hij koos; de serializer schrijft de sleutel
alleen bij een lopende keuze, dus alle bestaande snapshots en goldens blijven
hash-identiek (dat is getest).

Waarom dit eerst moest: online kiezen twee mensen hun factie blind en
gelijktijdig (v4.1 §4.1), dus de keuze moet in het log en door de reducer, niet
in een menu op een van de twee schermen. Nu kan een server een kale GameState
opzetten en beide clients laten kiezen zonder eigen lobby-logica.

**Koers (voor wie dit later leest):** het masterplan-F4 is de route
(Node/Fastify-backend + Godot headless workers); het ONLINE-PLAYTEST-PLAN van
3 juli is deels verouderd maar zijn client-voorwerk zit in F4.3. F4.1 (backend)
wacht op Docker Desktop of MySQL op deze machine -- geen van beide staat er.
Het voorwerk (F4.0, straks F4.3-clientwerk) heeft daar niets van nodig.

Checks: 1695 asserts groen (was 1638; +57 over de gate, de pools-boeking,
legal_actions, timeout-default, serializer-rondreis en de lek-test), simcheck
0 afwijkingen, fuzz 60/0.


## 9 augustus -- C20: Krokodil krijgt startpunten (+2,3 procentpunt)

Drie dingen op een dag: de trainer en de factiezoeker zijn allebei uitgeconvergeerd,
mijn balanscijfer van gisteren bleek te mooi, en Krokodil is gerepareerd.

**Beide zoekers zijn klaar.** De trainingsnacht liep helemaal af (trainers 13:39
tot 20:52, arena tot 22:20, dashboard 22:21, fuzz schoon) maar leverde in **418
generaties precies één adoptie** op: Varken, een kwartier na de start. Alle zes
de facties loggen herhaald "plateau". De factiezoeker draaide daarna 8,4 uur en
kwam met een voorstel dat identiek is aan wat er al stond: geen van de 17
generaties kwam boven de huidige facties uit (0,72 tegen 0,82). Met deze
gereedschappen valt er niets meer te halen.

**Correctie: de spreiding was geen 4,4 maar 12,6 procentpunt.** De meting van
6480 partijen gaf Beer 55,0 · Varken 54,7 · Leeuw 52,1 · Wolf 48,9 · Muis 46,9 ·
Krokodil 42,4. Mijn "4,4" van gisteren kwam uit 1152 partijen, waar de foutmarge
per factie ±3,6 is: dat antwoord paste niet in die meting. De twee runs spreken
elkaar niet tegen en de rangorde is op één plek na gelijk, maar ik heb een
gelukkige greep als conclusie opgeschreven. Vuistregel eruit: **onder ~2000
partijen geen uitspraken over een paar procentpunt.**

**Krokodil, drie kandidaten:**

| kandidaat | Krokodil | spreiding | n | |
|---|---|---|---|---|
| ervoor | 42,4% | 12,6 pp | 6480 | |
| budget 6 → 7 | 69,3% (+26,9) | 27,1 pp | 2160 | afgewezen |
| schutkleur-perk terug | 44,4% (+2,0) | 10,8 pp | 1080 | te weinig |
| +3 startpunten (afstelrun) | 45,8% (+3,4) | 7,8 pp | 1080 | |
| **+3 startpunten, verse seeds** | **44,7% (+2,3)** | **11,9 pp** | **2160** | **aangenomen** |

**En daar ging ik voor de derde keer op dezelfde manier de mist in.** Ik nam het
besluit op de afstelrun van 1080 partijen (marge ±2,6) en schreef "band naar 7,8"
op — in dezelfde entry waarin ik de vuistregel "onder ~2000 partijen geen
uitspraken" formuleerde. De bevestiging op verse seeds zegt 11,9. Het echte
effect van C20 is Krokodil +2,3 procentpunt (marge ±2,2, dus net-aan
significant); de band wordt er niet merkbaar smaller van en Beer is met 56,7% de
nieuwe bovenkant. C20 blijft staan, want het is de goede richting voor de
zwakste factie, maar het is een duwtje en geen doorbraak.

**Werkafspraak, nu echt:** stel af op minstens 2160 partijen, en bevestig op
VERSE seeds voordat er een getal in een document komt.

Wat we daarvan leren is meer waard dan het resultaat:

- **Een kaartbudgetpunt is geen afstelknop.** +26,9 procentpunt over 2160
  partijen, terwijl de hele band 12,6 breed was. In C19 gebruikte ik hem twee
  keer (Leeuw 9→8, Varken 6→7) en dat kwam toevallig goed uit.
- **Krokodils schutkleur is bijna niets waard.** De C13-verzwakking van 29 juli
  terugdraaien geeft hem +2,0, binnen de foutmarge van niets. En hij betaalt er
  wel voor: 3 × 6 = 18 statpunten per ronde tegen 21 voor Varken, Beer en Wolf.
  Dat gat is precies zijn achterstand.
- **`budget_bonus` is de fijne knop** en die bestond al (C11, 27 juli). Voorraad
  in plaats van kaartkracht, dus fijn genoeg gedoseerd.

**Valkuil onderweg:** `budget_bonus` wordt, anders dan het doctrines-blok, NIET
uit het regels-bestand gelezen door de campagnelaag. De tabel staat op drie
plekken (`CRules`, `rules_v42_campaign.json`, `v42_default.json`). Zonder alle
drie had Krokodil zijn punten wel in een duel gekregen en niet in de campagne:
precies de splitsing die C17 verbiedt. Alle drie bijgewerkt, en
`CampaignTests.test_c19_budget_bonus_overal_gelijk` bewaakt het voortaan.

**En een les over interim-cijfers.** Ik heb tijdens deze meting twee keer een
tussenstand gerapporteerd en beide keren zat ik ernaast (eerst "+10,6 hoopvol",
toen "+0,2, doet niets", uiteindelijk +3,4). Oorzaak: de arena speelt de
matchups op volgorde, dus bij een halve run is de dekking scheef en zeggen de
percentages niets. **Niet meer naar een lopende arena-run kijken voordat alle 36
matchups rond zijn.**

Geen versie-bump (blijft 4.3.1), zelfde behandeling als het doctrines-blok:
`rules_version` volgt wat de engine doet, niet welke waarde er op een knop staat.
Eén ijk-sim opnieuw geijkt (seed 101, de enige met een Krokodil: 16 → 19 cycli),
de andere vier byte-identiek.


## 8 augustus (avond) -- alles op het echte spel, en de fuzz vond meteen een bug

Max: "alles moet op echte facties en de 4.2 campagne." Dat bleek geen
opruimklusje maar een steen die je omdraait.

**Wat er stond.** De nachtrun verdeelde zijn meettijd om-en-om over de
4.1-matrix en de campagne-matrix, dus de helft ging over een economie en dieren
die niemand speelt. `arena.ps1` startte standaard de 4.1-matrix, `arena.bat` en
de runner de 4.1-quickrun. En de fuzz, het vangnet dat elke nacht 10.000
partijen nakijkt, draaide op een kale `RulesConfig`: geen campagne-blok, geen
factie-blok. Hij heeft dus nooit een Muis met 5 kaarten gezien, nooit een Beer
zonder artillerie, en nooit een spawn of een CP-inzet.

**Wat er nu staat.** Nachtrun, arena-defaults en de drie live configs draaien op
`rules_v42_campaign.json`. `arena/run.gd` legt bovendien het aangenomen
factie-blok over elk regels-bestand dat er zelf geen draagt (net als `game.gd`
voor een los potje), en schrijft in de run-metadata welke facties er gespeeld
zijn. Zo kan geen enkele config nog stilletjes de kale tabel meten.

**En toen was de fuzz meteen rood: 60 van de 60 partijen.** Twee oorzaken, en de
tweede is de vervelende:

1. **De fuzz kende de versterkingen niet.** Zijn regel "pion-ids liggen vast na
   de opstelling" komt uit 4.1. Sinds F2.2 zet je in CYCLE_SPAWN nieuwe pionnen
   op het bord en horen er nieuwe ids bij te komen. Dat mag nu, maar alleen in
   de actie die `spawns_revealed` meldt.
2. **De C15-rol viel uit elk opgenomen potje weg.** `Actions.to_dict` schreef
   van een opstelling alleen type en positie, niet `rol`. De opstelling gaat als
   `place`-actie het log in, dus elke opgenomen campagne-partij verloor zijn
   vaandeldragers en tamboers. Naspelen leverde dan nooit de C15-buit op
   (2 punten / 2 CP per drager) en de nagespeelde partij liep vanaf actie 0 uit
   de pas. **Replays van campagne-duels waren sinds 30 juli dus niet
   betrouwbaar.** Niemand zag het: de fuzz draaide op 4.1, waar rollen niet
   bestaan, en de goldens vergelijken eindstanden, geen tussenstappen.

Hoe het gevonden is, voor de volgende keer: de fold meldde "Onvoldoende CP" op
actie 681, wat naar CP wijst maar niet naar de oorzaak. Door het log tijdelijk
MET per-actie-hash op te nemen (een regel in `fuzz.gd`) schoof de melding naar
actie 0, en dat is de opstelling. Die aanwijzing staat nu in de code.

`rol` reist nu mee, en alleen als hij gevuld is, dus oude logs blijven
byte-identiek. Geen versie-bump: de gespeelde regels zijn niet veranderd.

Checks: fuzz 60/0 op campagneregels, zelftest PASS (het vangnet vangt sabotage
nog steeds), simcheck 0 afwijkingen, arena-proefrun laat zien dat het
factie-blok wordt overgelegd en in de metadata landt.


## 8 augustus (later) -- de rest van het spel kende de nieuwe facties nog niet

Opdracht Max: "update alle context en bestanden en uitleg met de nieuwe facties
en werk alle progress etc bij." Dat werd meer dan een tekstrondje, want op drie
plekken liep de code langs het aangenomen blok heen.

**De speler kreeg verkeerde informatie voorgeschoteld.** De factiekiezer in het
hoofdmenu, de tegenstanderkiezer en het help-scherm lazen `Constants.DOCTRINE_DATA`
rechtstreeks. Ze beloofden dus de kale tabel: "4 kaarten" bij een Muis die er
vijf uitdeelt, "budget 9" bij een Leeuw die er 8 heeft. Precies wat CLAUDE.md
verbiedt ("lees factie-data NOOIT rechtstreeks uit `Constants.doctrine_data()`"),
maar die regel was geschreven voor speel-code en de schermen waren nooit
nagelopen. Nieuwe ingang: `CRules.actieve_tabel()`.

**De pro/con-teksten noemden getallen die kunnen schuiven.** Die staan in
`i18n/strings.csv`, niet in de code, dus het bijwerken van `constants.gd` alleen
had niets opgelost. Ze zeggen nu alleen nog wat kwalitatief vastligt ("de meeste
kaarten van het spel", "het hoogste kaartbudget"); de schermen printen de exacte
getallen er toch al live naast. Bijvangst: Krokodil's PRO beloofde nog steeds
"+1 Speed op cavalerie", een perk die in C18 (31 juli) naar de Wolf is verhuisd.

En een valkuil die er bijna doorheen glipte: het spel leest de GECOMPILEERDE
`i18n/*.translation`, niet de csv, en een headless run bouwt die niet opnieuw.
De csv aanpassen en committen had dus niets aan het scherm veranderd. Herbouwen
gaat met `<godot> --headless --path . --import`; nagelopen door beide talen uit
de gecompileerde tabel terug te lezen.

**Twee regressietests erbij** (`CampaignTests.test_c19_actieve_tabel_*`): één die
eist dat elk veld uit het regels-blok ook echt in de schermtabel landt, en één
die eist dat een ontbrekend regels-bestand netjes terugvalt op de kale tabel in
plaats van om te vallen. Dit soort fout (scherm en engine lezen verschillende
bronnen) is nu twee keer voorgekomen, dus hij hoort in de suite.

**Muis en Beer hebben geen artillerie meer, en dat scheelt werk.**
`GameState.kent_type()` leidt uit de comp af welke types je mag spawnen, dus met
`[16,4,0]` en `[19,3,0]` kunnen die twee nooit een kanon op het bord krijgen. Een
berenkanon, zijn gibs en `cannon_die_bear` zijn dus verloren moeite. De
geluidtracker vraagt er niet meer om (22 geluiden in plaats van 24) en leest die
comps rechtstreeks uit de regels, dus dat corrigeert zichzelf als de facties ooit
weer schuiven. Zelfde noot in MODEL-WISHLIST, SOUND-WISHLIST en model-tracker.

**Beer's speedplafond stond in drie documenten als 3.** Het is 4 sinds C13 (29
juli); die wijziging stond wél in de changelog maar was nooit in de spec
doorgevoerd. Gevolg voor het asset-spoor: de Beer heeft drie `spd`-kaarten, niet
één. Alleen de uiterste 1/5/1 valt voor hem af.

**`toon_economie.py` rekende met legers die niemand meer opstelt** (kale comps
hardgecodeerd) en toonde `cycle_limit`, dat V0 op 3 augustus heeft afgeschaft.
Legt nu hetzelfde blok eroverheen als het spel, met dezelfde terugval als
`game.gd` gebruikt voor een los potje.

Verder bijgewerkt: `docs/spelregels-v4.2.md` §11 (nieuwe tabel + een §11b dat
uitlegt waarom de getallen niet in `constants.gd` staan), `CLAUDE.md`
(factie-tabel + "waar we zijn" stond nog op 26 juli), `README.md` (beschreef nog
een 2-spelerspel zonder campagne, met twee .bat-bestanden die niet bestaan),
`MASTERBOUWPLAN.md` (F1.6 gehaald: 44,7-56,2%, ruimer dan het werkdoel 25-75%),
`CARD-DESIGN-BRIEF.md` en `MODEL-WISHLIST.md` (kaartcombinaties per budget 5/6/7/8
opnieuw uitgerekend; het waren er 5/7/9).

**Nog een observatie, geen wijziging:** `arena_nacht.ps1` verdeelt de meettijd
om-en-om over de 4.1-matrix en de v4.2-matrix, en de 4.1-kant draait op
`v41_default.json` dat GEEN doctrines-blok heeft. De helft van de meting gaat dus
over facties die niemand meer speelt. Voor vanavond niets aan gedaan (dat is een
keuze over wat je wilt meten, niet een fout), maar het is zonde van de uren.


## 8 augustus -- de facties staan (spreiding: zie de correctie van 9 augustus)

> De 4,4 procentpunt in dit stuk klopt niet. Een run van 6480 partijen zet hem
> op 12,6; zie de entry van 9 augustus. De factie-tabel zelf is niet gewijzigd.

Twee correctierondes op C19, elk gestuurd door een meting, en bevestigd op 1152
partijen met ANDERE seeds dan waarop is afgesteld.

**De geldende facties** (het `doctrines`-blok in
`arena/arena_configs/rules_v42_campaign.json`; met `-- facties` zie je ze naast
de kale tabel uit `constants.gd`):

| factie | kaarten | budget | leger [inf,cav,art] | perk |
|---|---|---|---|---|
| Varken | 3 | 7 | [11,5,3] = 19 | - (allrounder) |
| Muis | 5 | 5 | [16,4,0] = 20 | +1 Speed op elke pion, loopt door eigen pionnen |
| Leeuw | 2 | 8 | [12,4,2] = 18 | artilleriedracht 7 |
| Beer | 3 | 7 | [19,3,0] = 22 | +1 HP per koppeling, kaart-Speed max 4 |
| Wolf | 3 | 7 | [11,8,3] = 22 | gratis stap na melee, cavalerie +2 Speed en springt over vijanden |
| Krokodil | 3 | 6 | [13,5,3] = 21 | koppeling blijft geheim tot de eerste schade |

| factie | winst | haven-aandeel |
|---|---|---|
| Varken | 56,2% | 1% |
| Beer | 54,4% | 93% |
| Leeuw | 52,5% | 1% |
| Wolf | 46,9% | 79% |
| Krokodil | 45,3% | 51% |
| Muis | 44,7% | 97% |

Band 45-56%, niemand verder dan 6,2 van de 50. Beginstand vanochtend: 28-76%.

Beer wint met 93% rennen, Leeuw met 99% slachten, allebei rond 53%. Twee
speelstijlen, even sterk: de zorg van 7 augustus dat eliminatie het structureel
wint van rennen is weerlegd.

**Welke knop doet wat** (het bruikbaarste dat we hebben opgehaald):
kaartbudget ~30 punten per punt (te grof om mee af te stellen), cavalerie ~18
per ruiter, infanterie vrijwel niets, legergrootte op zichzelf niets, artillerie
-21 voor een renner en neutraal voor een slachter. En: het leger van een factie
bepaalt zijn spelstijl NIET (Leeuw ging van 10 naar 4 cavaleristen en bleef 0%
haven).

**Factiezoeker gerepareerd**: die mat afdrijving vanaf `constants.gd` en gaf het
aangenomen blok dus identiteit 0,49 in plaats van 1,00. Hij zou vannacht
kandidaten hebben beloond die Max' werk terugdraaien. Leest nu het actieve blok
uit het regels-bestand.

**Trainer hoefde niets**: die leest hetzelfde bestand. Stap-budget 1400 is ruim
(gemeten maximum 957 over 864 partijen, nul afkappingen).

**Nu aan de beurt: hertrainen.** De gewichten komen van de nacht van 7 augustus,
dus van voor deze twee correctierondes.


## 7 augustus (avond) -- C19: het eerste factie-blok is aangenomen

Besluit Max: "ja pas aan en dan doen we het doortesten met de fogofwarpanel."
Voor het eerst staat er een `doctrines`-blok in `rules_v42_campaign.json`, en
daarmee spelen campagne, los potje, trainer en arena allemaal deze facties.

| factie | was | wordt |
|---|---|---|
| Varken | 3k b7 [13,6,3] | budget 6, [12,6,3] |
| Muis | 4k b5 [18,4,0] | 5 kaarten, [16,4,0] |
| Leeuw | 2k b9 [6,10,2] | [12,4,2] |
| Beer | 3k b7 [16,3,3] | [19,3,0] |
| Wolf | 3k b7 [11,8,3] | cavalerie-snelheid 2 |
| Krokodil | 3k b6 [13,6,3] | [13,5,3] |

Drie ervan gaan tegen de zoeker in. Bij Leeuw en Varken had Max gelijk (de
zoeker gaf Leeuw MEER budget terwijl hij de sterkste was), bij Beer niet: zijn
kanon behouden kostte 21 procentpunt.

**Ijk-sims opnieuw geijkt.** Alle vijf werden LANGER (seed 404: 6 -> 16 cycli),
winnaar in alle vijf hetzelfde. De nieuwe legers vechten trager, niet anders.
Gevolg: de honger vanaf cyclus 10 gaat nu veel vaker bijten dan op 3 augustus.
Dat is iets om in de gaten te houden bij de eerste meting.

**Test die brak en waarom dat goed nieuws was:**
`SoloTests.test_mens_factie_keuze_vast_voor_campagne` had "Leeuw heeft 10
cavalerie" hardgecodeerd. Hij toetst de koppeling tussen factiekeuze en
startvoorraad, niet een specifiek leger, dus hij leest de comp nu uit de actieve
regels. De rest van de suite is nagelopen: dit was de laatste met zo'n vast
getal erin.

**Wat er NIET is gebeurd, en wat de volgorde nu is:**
De bots zijn niet hertraind. Ze hebben leren spelen tegen een Leeuw met tien
cavaleristen en een Beer met kanonnen. Elke meting nu meet dus botonkunde, geen
factiebalans. Daarom eerst TRAINING-NACHT (traint 7 uur, meet 1 uur), en pas
daarna de factiezoeker. Ook niet los doorgemeten: Leeuw [12,4,2]; die drie
metingen zijn afgebroken toen Max de machine nodig had.


## 7 augustus -- de facties spelen twee verschillende spellen

Gevonden tijdens het nameten van het factie-voorstel, en dit is belangrijker dan
het voorstel zelf. Hoe wint elke factie eigenlijk? (432 partijen, huidige
regels, L2 tegen L2.)

| factie | comp | winst | via haven |
|---|---|---|---|
| Muis | [18,4,0] | 44 | 37 (84%) |
| Krokodil | [13,6,3] | 76 | 44 (58%) |
| Beer | [16,3,3] | 33 | 19 (58%) |
| Wolf | [11,8,3] | 40 | 22 (55%) |
| Varken | [13,6,3] | 76 | 1 (1%) |
| Leeuw | [6,10,2] | 91 | **0 (0%)** |

Leeuw wint 91 keer en NUL keer via de haven. Varken 76 keer en een keer. Die
twee rennen niet, die vegen het bord leeg. Muis doet het omgekeerde: 84% van
zijn winsten komt uit de haven-race.

**Gevolg 1: artillerie is niet slecht, artillerie is slecht voor een RENNER.**
Beer met 20 pionnen en 0 kanonnen haalt 49,2%; met 20 pionnen en 2 kanonnen
33,3%. Zelfde legergrootte, twee infanteristen ingeruild voor twee kanonnen,
16 procentpunt eraf. En legergrootte zelf doet niets: [15,3,0] en [17,3,0]
scoren allebei exact 49,2%.

De oorzaak staat in de regels: `art_move 1` (Rules.gd:75) laat een kanon een
vak per ACTIE verzetten waar infanterie zijn hele Speed in een keer loopt, en
een kanon kan geen melee en heeft terugslag 0. Onder het vol-team-model staat je
comp elk duel op het bord, dus twee kanonnen zijn permanent twee lopers minder.
Beer haalt 58% van zijn winst uit de haven; voor hem is dat dodelijk. Bij Leeuw
maakt het niets uit, want die gaat toch nergens heen.

**Gevolg 2: de zoeker kreeg Leeuw niet omlaag met economie-knoppen, en dat is
logisch.** Leeuw is niet sterk doordat zijn kaarten goed zijn maar doordat
ELIMINATIE het wint van RENNEN, en hij met tien cavaleristen de meest complete
slachter is. Een kaart of een budgetpunt verandert dat niet.

**De echte ontwerpvraag** is dus niet welke knop je verzet, maar of de
haven-race een gelijkwaardige manier van winnen mag zijn. Zo ja, dan is er iets
structureels nodig (de haven belonen of eliminatie duurder maken). Zo nee, dan
zijn Muis en Beer verkeerd ontworpen.

*Voorbehoud:* deze bots hebben op de OUDE facties leren spelen. Het patroon is
te sterk om toeval te zijn (0 van de 91), maar hertrainen hoort erbij voordat er
een besluit op valt.


## Werkafspraak 5 augustus -- nog geen factie-voorstel aannemen

Besluit Max: "laten we het nog even zo laten, want tot nu toe was er altijd wel
iets mis met de training."

De factiezoeker START elke run vanaf `rules_v42_campaign.json`
(factiezoeker.py:413), en daar staat GEEN doctrines-blok in. Alle runs tot nu toe
zijn dus vanaf dezelfde blanco stand vertrokken en hebben hun eerste generaties
besteed aan het opnieuw vinden van dezelfde zetten. Binnen een run bouwt hij wel
voort op zijn eigen kampioen; tussen runs niet.

Doorbouwen kan pas als een voorstel wordt aangenomen, en dat is een echte
regelwijziging: hetzelfde bestand stuurt spel, trainer, arena en ijk-sims
tegelijk. Aannemen betekent goldens en `golden_sims.json` regenereren, een
CHANGELOG-entry, en de bots hertrainen.

Dat gebeurt bewust nog NIET. In twee dagen kwamen er vijf gebreken uit de
meetketen, waarvan vier pas nadat een run geslaagd leek:
  1. doctrines-blok legde de bots lam (elke kandidaat speelde niet)
  2. geen loting: 36 partijen gemeten terwijl de zoeker 216 dacht te hebben
  3. scorefunctie te bespelen: korte partijen +0,20 zonder beter spel
  4. dode knoppen (artilleriedracht voor een factie zonder artillerie)
  5. legers boven 22 liepen vast in de opstelfase (een derde van een run)

Een voorstel vastzetten terwijl dat gebeurt, bakt een meetfout in de spelregels
en is daarna niet meer terug te draaien: goldens geregenereerd, bots hertraind,
oude stand weg. Voorwaarde om dit te heroverwegen: een run die doorkomt zonder
dat er achteraf iets aan blijkt te mankeren.


## 3 augustus 2026 (avond) -- V0: een duel kent geen gelijkspel meer

Besluit Max uit `docs/campagne-intrige-voorstel.md`: een duel eindigt op de
haven of op totale eliminatie, meer smaken zijn er niet. Geen remise, geen
tiebreak, geen cycluslimiet. In plaats daarvan de **honger**: vanaf cyclus 10
verliest elke speler bij het begin van een cyclus de pion die het verst van zijn
doelhaven staat. De achterhoede verhongert het eerst, dus je wordt vooruit
geduwd in plaats van achteruit.

**Waarom dit meer is dan een regeltje**: als elk duel beslissend is, is elke
nominatie in de raad een doodvonnis. De hele politieke laag van de campagne
wordt er zwaarder van. En het is de afmaking van C9, waar de cycluslimiet er al
uit ging omdat bots vrijwel alleen via de tiebreak wonnen.

**Het getal komt uit meting, niet uit smaak.** 216 partijen, L2 tegen L2:

| klok | cycli mediaan | cycli max | stappen max | beslissend |
|---|---|---|---|---|
| cycluslimiet 25 (oud) | 10 | 26 | 1.165 | 95% |
| helemaal geen klok | 10 | **330** | **6.001** | 97% |
| honger vanaf 10 | 10 | **16** | **932** | **100%** |

De mediaan verandert niet: de klok doet niets voor een gewone partij en bestaat
puur voor de staart. Die staart was erger dan gedacht (330 cycli, tegen de
noodstop aan). Max koos 10 als middenweg tussen "zeldzame noodrem" en "voelbare
klok".

**Drie dingen aan de honger zijn correctheid, geen smaak**, en alle drie zijn ze
door de verkenning boven water gekomen voordat ik ze fout kon bouwen:

1. Om de beurt eten met een win-check ertussen, en wisselend wie begint. Anders
   wist een dubbele wipe beide legers en leest de winstcheck dat als "nog geen
   winnaar": het duel loopt dan eeuwig door.
2. "De vijandelijke haven" is in code de haven van je EIGEN speler-id (die ligt
   aan de vijandkant). Wie daar `opponent` schrijft laat zijn voorhoede
   verhongeren, precies omgekeerd, en dat valt niet op in een symmetrische test.
3. Honger boekt geen C15-buit. De cyclusreset ontkoppelt net alle pionnen, dus
   elke vaandeldrager zou anders 2 punten opleveren voor iemand die niets deed.

**De noodstop verzint geen uitslag meer.** Beide runners kapten bij `max_steps`
stilletjes af met een tiebreak-winnaar. Nu blijft de winnaar leeg, gaat er een
`afgekapt`-vlag aan en gilt er een fout. De arena boekt dat als eigen categorie,
zodat een kapotte klok niet in een onschuldig ogende remise-kolom verdwijnt.

**Opgeven telt voor de winnaar als eliminatie**, roem en CP. De staat draagt
daarvoor een nieuw veld `eind_reden`, want de campagnelaag leidde de methode af
uit de eindstaat en een opgave was daaraan niet te zien: die boekte als tiebreak
en kostte de winnaar dus een punt roem.

**Gevolgen die je moet weten**: de honger verschuift uitslagen van haven naar
eliminatie (88/118 wordt 73/139), want hij dunt legers uit. De bots moeten
hertraind: hun waardefunctie kende "overleven tot de limiet" als geldige
uitkomst en die bestaat niet meer. Alle 15 goldens en drie ijk-sims zijn
opnieuw opgenomen; de winnaar bleef in alle drie de sims dezelfde, dus de honger
kort partijen in zonder uitslagen om te draaien. Versie 4.3.0 (met
campagne-blok 4.3.1).

**Nog te doen na deze stap**: de zoekers (kolom `remise` wordt `afkap`, en de
term "beslissend" in de regelzoeker wordt structureel 1.0 en moet vervangen),
hertrainen, en dan pas de factie-hermeting zonder `budget_bonus`.

## 3 augustus 2026 (later) -- C17 was een afspraak, geen mechanisme

Keuze van Max: de campagne gelijktrekken met de duels, voordat er een
factie-voorstel wordt aangenomen. Bij het uitzoeken bleek het gat groter dan de
startvoorraad alleen: **de campagne las geen enkele regels-json**. Ze rekende
haar startvoorraad uit de kale factietabel, stelde haar duels met dezelfde tabel
op, en bouwde de duelregels ter plekke op zonder doctrines-sleutel. Een voorstel
van de factiezoeker kwam dus in de arena, in de trainer en in de ijk-sims, en
nooit in een gespeelde campagne.

Alle drie moesten samen mee. Alleen het blok doorgeven aan de duelregels was
niet genoeg: `comp_override` uit de campagne wint van de merge, dus je zou
nieuwe kaarten en perks krijgen op een leger van de oude grootte. Half repareren
was hier erger dan niet repareren.

Nu: `CRules` draagt de facties, leest ze bij de start uit
`rules_v42_campaign.json` (hetzelfde bestand waar de trainer en de arena op
draaien) en **bevriest ze in de save**. Hervat je een campagne, dan houdt die
haar eigen dieren, ook als je later een ander voorstel aanneemt. Het losse potje
haalt ze uit dezelfde bron. Zolang dat bestand geen blok heeft verandert er
niets, en dat is precies wat de poort moest bewijzen.

**Nieuw kijkgereedschap**: `-- facties` laat zien welke factie-instellingen er
NU gelden, met een sterretje bij alles wat afwijkt van `constants.gd`, en start
een proefcampagne die bewijst dat het grootboek en de duelregels hetzelfde leger
gebruiken. Getest met een tijdelijk blok (Beer comp [22,6,3], Leeuw budget 6):
Beer startte met 14 inf in plaats van 11 en de duelopstelling werd [22, 6, 3].
Bestand daarna teruggezet, poort opnieuw groen.

**Nog niet gelijk**: de factiekeuze in de hub en het Facties-tabblad tonen nog
de kale tabel, dus met een blok actief kies je op verouderde cijfers. En
`budget_bonus` (Muis +4, Beer +3, Wolf +2/+4 CP) staat er als aparte
startboeking bovenop: arena en campagne passen die allebei toe, dus de meting
klopt, maar het blijven twee knoppen voor hetzelfde probleem.

## 3 augustus 2026 -- de factiezoeker speelde helemaal niet

De run van 90 minuten leverde niets op: 72 van de 73 kandidaten kregen een VETO,
de kampioen bewoog geen millimeter. Eerst leek dat mijn drempel (speler 1 mocht
niet boven 65%, maar de nulmeting van de zoeker staat al op 61%). Dat klopte
ook, maar het was niet de echte oorzaak.

**De echte oorzaak: met een `doctrines`-blok in de regels speelden de bots
niet meer.** De agent bouwt elke beurt zijn staat uit de view, en daar zit de
regels-config als dict in. Die rondreis ging stuk op een sleutel-conversie
(`String(int)` bestaat niet meer in Godot 4.7), `from_dict` gaf `null`, en de
runner koos dan maar de eerste legale zet. Elke beurt. 236.928 noodkeuzes per
216 partijen, tegen 0 bij de nulmeting.

Zichtbaar in de cijfers zodra je ernaar kijkt: eliminaties verdwenen (78 -> 0),
alles liep naar de cycluslimiet, en speler 1 sprong naar 85-90% *ongeacht wat er
in het blok stond* (samenhang met "meer macht": r = -0,14, oftewel geen). Alleen
een LEEG blok bleef heel, en juist de nulmeting had er een -- daarom zag de run
er van buiten normaal uit.

**Gerepareerd**: sleutels blijven string, waarden door `_diep_int` (JSON maakt
van 6 een 6.0 en `comp` moet ints houden), en `l1_greedy` las de factietabel
rechtstreeks uit `Constants` in plaats van de override -- die plande zijn
aanvul-spawns dus met een leger dat hij niet had. Na de fix op dezelfde 36
partijen: fallback 0, eliminaties terug, speler 1 van 89% naar 50%.

**Canary**: `AgentTests.test_bots_blijven_spelen_met_doctrines_blok` eist
`fallback_count = 0`. Dat is de enige controle die dit vangt -- er kwam immers
gewoon een keurige uitslag uit.

Twee dingen in de zoekers zelf gingen mee: het kant-veto ijkt nu op de
nulmeting van dezelfde run (bodem 62%, harde bovengrens 85%), en alle
generaties spelen dezelfde seeds, zodat een kandidaat niet meer wordt afgezet
tegen een kampioen die op andere partijen is gemeten.

**Tweede vondst, en die is net zo vervelend: de zoeker mat 36 partijen, geen
216.** Drie totaal verschillende base_seeds gaven byte-identieke uitslagen. L2
is namelijk volledig deterministisch zolang `tie_break_loting` uit staat, en die
knop zat alleen in de nachtmatrix. Bij gelijke stand koos de bot dan altijd
dezelfde zet, dus waren `2 potjes x 3 processen` gewoon 36 unieke partijen die
zes keer werden overgetikt -- 216 regels zonder een greintje variatie.

Daarmee is de oude vraag beantwoord: de 61% eerste-speler-voorsprong van de
zoeker tegen 51% in de nacht was geen ruis en geen ander spel, maar het verschil
tussen 36 partijen zonder spreiding en 3240 mét. Beide zoekers zetten nu
`tie_break_loting: true` en `max_steps: 2500`, gelijk aan `v42_matrix_l2.json`.

**Wat dit betekent voor de eerdere runs**: de regelzoeker-run van 31 juli en de
factiezoeker-runs van 1 en 3 augustus zijn allemaal ongeldig. De eerste twee
door te weinig spreiding, de derde ook nog door de lamgelegde bots.

**De nieuwe nulmeting** (648 partijen, drie seed-sets, mét loting) laat zien dat
de opstelling nu wél iets meet: de drie sets geven 47%, 54% en 46% eerste-speler-
voorsprong in plaats van drie keer exact hetzelfde getal, samen 49%. Dat sluit
aan bij de 51% van de nachtrun.

| factie | wint (540 partijen, zonder spiegels) |
|---|---|
| Leeuw | 72,8% |
| Krokodil | 63,9% |
| Varken | 60,6% |
| Muis | 38,9% |
| Wolf | 36,1% |
| Beer | 27,2% |

Gemiddelde afwijking van 50%: **15,8 procentpunt**. Twee dingen springen eruit:
C18 heeft Krokodil niet echt afgeremd (nog steeds tweede, 63,9%), en **Beer is
nu de zwakste** met 27,2%. Dat is het echte werk voor de factiezoeker.

**Nagekeken, en dit is GEEN fout**: de trainer speelt ook zonder loting en met
seed 0 (`capture.gd:1787`), maar daar is dat opzet. Zijn kandidaten verschillen
in gewichten, en juist die gewichten bepalen dan het verschil in plaats van de
dobbelsteen: gepaarde vergelijking. De variatie komt bij hem uit tegenstander,
factie en kant, die wél rouleren. Bij de zoeker was er helemaal geen variatie,
want daar spelen beide kanten hetzelfde profiel.

Dat geldt ook voor de **voor/na-tabel bij C18**: die is gemeten met "zelfde
seeds als de nulmeting van de regelzoeker", dus zonder loting. 324 partijen was
in werkelijkheid 36. Vandaar ook die verdachte ronde getallen (83,3% / 8,3% /
33,3% -- allemaal twaalfden). Het BESLUIT C18 zelf staat overeind: Krokodil had
letterlijk het leger van Varken plus twee voordelen, en de nachtmatrix van
1 augustus (3240 partijen, mét loting) laat los daarvan zien dat Leeuw op 74%
staat en Beer en Wolf te zwak zijn. Maar hoeveel C18 precies heeft geholpen weet
ik niet: dat moet een nachtrun opnieuw meten.

## 1 augustus 2026 -- de factiezoeker vond een gat in mijn eigen scorefunctie

Eerste echte run: 86 generaties, 6 uur, eindscore 0,9117 met alle zes facties op
precies 50,0%. Te mooi, en dat klopte ook niet.

**Wat er gebeurde**: in de winnende kandidaat won **speler 1 alle 216 partijen**.
Elke factie speelt de helft van zijn potjes als speler 1, dus stond iedereen op
exact 50% en scoorde dat als perfecte balans. 124 van de 517 kandidaten hadden
datzelfde patroon. De zoeker had niet de balans opgelost maar het spel
kapotgemaakt: partijen van 15 cycli die door de beurtvolgorde werden beslist.

**Twee fouten in mijn score, allebei gerepareerd:**
1. Spiegelpartijen (factie tegen zichzelf, 36 van de 216) telden mee. Die geven
   dezelfde factie een winst en een verlies en trekken alles naar 50%. Nu eruit.
2. Geen enkele meting op de KANT. Nu meten beide zoekers hoe vaak speler 1 wint;
   wijkt dat meer dan 15 procentpunt van 50/50 af, dan volgt een VETO (score x
   0,25). Een aftrek van 0,20 was niet genoeg: de kapotte kandidaat won daarmee
   nog steeds. Na het veto: 0,9117 -> 0,1804, en de huidige facties (0,6844)
   winnen ruim.

**Wat de meting wel opleverde, en dat is nuttig**: de eerste-speler-voorsprong
in het echte spel. Nacht van 1 augustus (3240 partijen): speler 1 wint 51% --
gezond. De kleinere runs van 216-324 partijen gaven 61%, dus dat was ruis.

**Les voor de volgende zoeker**: een zoekfunctie optimaliseert precies wat je
meet. Meet je "iedereen 50%", dan krijg je ook een spel waarin de beurtvolgorde
beslist. Elke nieuwe doelstelling heeft een veto nodig op de manier waarop hij
te makkelijk gehaald kan worden.

## 31 juli 2026 (avond) -- C18: Krokodil ingeperkt, Wolf krijgt tempo

Max koos een harde ingreep boven acht uur economie-zoeken, en dat was de betere
volgorde. De regelzoeker kan alleen aan de pot draaien; twee metingen wezen naar
de FACTIES zelf.

- Krokodil: kaartbudget 7 -> 6, +1 cavalerie-snelheid eraf (houdt schutkleur).
- Wolf: krijgt die +1 cavalerie-snelheid.

Gemeten op de campagne-regels, 324 partijen, zelfde seeds als de nulmeting van
de zoeker: gemiddelde afwijking van 50% **19,4% -> 8,3%**. Krokodil 83,3 ->
41,7; Wolf 8,3 -> 33,3; Beer 33,3 -> 50,0. De zoeker kwam in 139 minuten niet
verder dan 11,1% en moest daarvoor Wolf bijna 20 punten reserve geven.

Nog scheef: Varken 66,7 (allrounder zonder perks staat bovenaan, dus de perks
van de anderen wegen niet op tegen hun nadelen) en Wolf 33,3.

Test `test_vos_cavalry_gets_speed_bonus_via_session` is meeverhuisd naar Wolf en
bewaakt nu beide kanten: Krokodil zonder bonus en budget 6, Wolf met bonus.
Goldens hergenereerd, 3 ijk-sims opnieuw vastgelegd.

Checks: 1532/0, simcheck 0 afwijkingen, fuzz 25 schoon, play 0 fouten.

## 31 juli 2026 (later) -- C17: EEN regelset, de campagne is het spel

Max: "het moet allemaal 1 lijn zijn en zeker de trainer. De campagne-regels zijn
belangrijk, de 1v1 is gewoon een afgeleide: in plaats van meerdere duels speel
je er een, en dus heb je iets gedowngrade CP en reinforcements, meer niet."

**Wat er mis was**: er stonden twee economieen naast elkaar. De campagne rekende
0,5 x comp + budget-bonus (15-18 pt), het 1v1 gebruikte de vaste C16-tabel
(7-12 pt), en de TRAINER draaide op `rules_v42_campaign.json` waar ik die
1v1-tabel in had gezet. Hij leerde dus over een economie die in de campagne niet
bestaat. Bovendien gaf `train_ai.bat` het regelbestand helemaal niet mee: die
trainde op 4.1.

**Nu**: `start_poolfactor` x comp + `budget_bonus` is de enige formule, overal.
Het losse potje schaalt met `potje_factor` (0,35). Campagne 15-18 pt en 10-14
CP; los potje 5-6 pt en 4-5 CP. Trainer, nacht-matrix, ijk-sims en regelzoeker
draaien alle vier op de campagne-config. De regelzoeker draait niet meer aan een
1v1-tabel maar aan `start_poolfactor`, `budget_bonus` per factie, `cp_start`,
ruil, buit en de spawn-caps.

**Meetgrens, geen spelregel**: in de campagne staat de cycluslimiet uit (C9).
Gemeten wat dat met bots doet: 1569 stappen per partij (3x zo lang) en 18%
eindigt op de meet-afkap; er kwamen 11 partijen door waar er anders 36 door
komen. De arena/trainer-config heeft daarom een limiet van 25 cycli als
MEETGRENS -- bindt vrijwel nooit (mediaan 10), en met die grens: 686 stappen,
11% tiebreak, 36 partijen.

**Nieuw hulpje**: `python tools/balans/toon_economie.py` rekent voor wat elke
factie krijgt onder een regels-json, campagne en potje naast elkaar.

Checks: 1536/0, simcheck 0 (baseline nu op de campagne-regels, 5 sims herijkt),
fuzz 25 schoon, play 0 fouten, meleecheck PASS.

## 31 juli 2026 -- regelzoeker, nachtmeting en de dode buit

**De nacht van 31 juli gelezen** (3240 partijen, v4.2-matrix): de C14-fix werkt,
7,01 aanvullingen per partij in 99% van de partijen (was 0,00). Maar de winrates
zijn omgegooid: Krokodil 80,8, Leeuw 68,4 (+20!), Varken 60,8, Beer 34,4, Muis
33,3, Wolf 21,9 (-23!). De aanvul-economie bevoordeelt dure comps enorm. De
C16-tabel is dus achterhaald: die gaf Wolf 11 op basis van de oude 45%.

**De trainer zit op een plateau**: 6 facties, 40-142 generaties, 7 uur, in totaal
**1 adoptie**. Wat er nog te winnen valt zit in het ONTWERP, niet in de bots.

**Buit deed in botspel niets** (0 in 34 arena-partijen, ook met de nieuwste
code): bots bouwen hun opstelling met `AIController.choose_placement` en die
wees geen dragers aan -- `default_placement` deed dat wel, maar die gebruiken ze
niet. Nu delen ze dezelfde verdeling. Meteen gemeten: buit 0,00 -> 1,53 per
partij, 58% van de partijen. Zonder deze fix had de trainingsnacht geleerd over
een regel die in botwereld niet bestond.

**Nieuw gereedschap: de regelzoeker** (`tools/balans/regelzoeker.py`, paneelknop
"Regels uitproberen (balans)"). Zoekt betere REGELS met vaste bots, precies
andersom dan de trainer. Score: factie-evenwicht 45%, beslissende partijen 25%,
speelduur 15%, levende economie 15%. Verandert het spel NIET: schrijft
`voorstel.json` + log per kandidaat. Eerste run: 0,636 -> 0,743 in twee
generaties, scheefheid 19,4% -> 13,9%.

*Valkuil die zich meteen liet zien*: knoppen die niet in de basis-json staan
(buit_vaandel_pt, buit_tamboer_cp) begonnen op hun ondergrens, dus de zoeker
zette de buit op 0 en noemde dat balans. Startwaarden komen nu uit een tabel met
de echte code-defaults. Les: een zoeker vindt altijd iets, en zonder oplettende
startwaarden vindt hij dat je regel beter niet kan bestaan.

**Testbatterij sneller**: `tests.ps1` verdeelt hem over negen processen
(SoloTests in drieen via de nieuwe `deel=i/n`-filter). Van ~13 minuten naar 5
tot 7, zelfde 1529 tests.

**Sim-baseline nogmaals herijkt**: bots zetten nu dragers neer, dus hun
opstelling verandert -- 3 van de 5 sims wijken bewust af en zijn opnieuw
vastgelegd.

## 30 juli 2026 (avond 2) -- C15-buit, C16-economie en een reeks bugs

**C15 buit op figuranten** (spec + CHANGELOG). Rol staat op de PION in de staat,
verhuist nooit, en levert bij een kill 2 versterkingspunten (vaandel) of 2 CP
(tamboer) op -- alleen als het slachtoffer ongekoppeld is, want alleen dan
draagt hij ook echt. Je wijst de dragers zelf aan in de opstelfase (losse
plaats-stappen). Bots kregen `buit_jacht` en `buit_hoede` als leerbare
gewichten; de arena meet `buit_pt`, `buit_cp` en `dragers_verloren`.

**C16 reserve per factie**: Muis 12, Beer 12, Wolf 11, Varken 9, Leeuw 7,
Krokodil 7 (ankers van Max, rest op de winrates van 29 juli). Staat ook in de
trainer-config. Uitdrukkelijk een startpunt: die winrates komen uit nachten
zonder werkende versterkingen en zonder buit.

**Bugs deze ronde**, allemaal eerst gemeten:
- Fog-lek: hub en grootboek toonden reserve en CP van de tegenstander. Nu "?",
  alleen roem is publiek (spec 6). Test erbij.
- Muis stierf met het ALGEMENE doodsgeluid: game.gd speelde `inf_die` hard,
  terwijl de factie-kreet aan een tweede pad met 15% kans hing. Nu loopt het
  door de factie-keten.
- Reuzengeweer, twee oorzaken: (1) de gib-maat werd vergeleken met de
  bind-pose van een geskinde mesh (base leest 0,006 terwijl hij 0,88 hoog
  staat) -- nu vergeleken met wat de auto-fit aan het skelet mat; (2) bij een
  VERS gespawnde pion waren de bot-transforms nog niet doorgerekend, dus las de
  prop-normalisatie ouderschaal 1.0 in plaats van ~0,008 en werd het voorwerp
  honderden malen te groot. Skelet wordt nu geforceerd bijgewerkt. Plus een
  vangrail op 3x de normale voorwerplengte.
- Opstelbug: de dragers werden dubbel geteld (ze zijn ook infanterie), de
  opstelling kwam 4 pionnen te hoog uit, de engine keurde hem af en de partij
  bleef in de opstelfase hangen -- dat was Max' verdwenen hover-ring.
- Freeze bij koppelen: de AI koppelde in dezelfde tel. Nu 0,55s denktijd
  (`ai_link_denktijd`).
- Spawn-geluid ingebouwd bij het koppelen (-9 dB), witte pof bij koppelen en
  ontkoppelen.

**Open vraag**: onder de OUDE 4.1-sim-baseline weken na deze ronde alle vijf
sims af, en dat is niet te herleiden tot een enkel bestand (Pawn, Rules,
GameState, rules_config, AIController elk los teruggezet: afwijking bleef; alles
samen terug: weg). Omdat 4.1 geen speelbare optie meer is, draait de baseline nu
op v42_default.json en is hij opnieuw vastgelegd. Wie ooit weer 4.1 wil spelen,
moet dit eerst uitzoeken.

**Werkafspraak-les**: nooit bisecten terwijl er een achtergrondpoort door
dezelfde werkmap draait -- twee metingen waren daardoor onbruikbaar (script-
fouten uit mijn eigen stash lazen als spelbugs).

## 30 juli 2026 (avond) -- bajonet-choreografie, tuner-opslag, vlaggen

**Bajonet-melee (Max: "dit werkt nog niet goed in het spel zelf")**. Twee
oorzaken, beide gemeten met de nieuwe check `-- meleecheck`:

1. `Rules.apply_melee` zet de winnaar METEEN op het vrijgekomen vak, en
   `_refresh_all()` zet elke pion op zijn staat-positie. De eerste refresh na de
   stoot teleporteerde hem er dus al naartoe, terwijl de nette opruk-timer nog
   liep. Stervende pionnen hadden die bescherming wel (`_dying_views`), de
   oprukker niet. Nieuw: `_advance_holds` houdt hem visueel op zijn eigen vak
   tot `_begin_advance` hem laat oversteken.
2. `_play_variant` sloeg een clip over als die al speelde. Twee stoten achter
   elkaar die dezelfde variant trokken lieten dus NIETS zien. Eenmalige clips
   (stoot, schot, dood, hit, ready) herstarten nu; idle/walk blijven doorlopen.

**Opruk-wachttijd is VAST** (Max, later dezelfde dag: "maak dat wachten op melee
altijd zelfde, dan gaat die dood-animatie maar langer door, moet snel naar die
plek"). Eerst stond `melee_move_wait` op 1,0 en wachtte hij de hele dood-clip
af: die varieert per variant van 1,8 tot 3,8 seconden, dus elke kill duurde
anders lang (tot 5,3s). Nu is het stoot-frame + opruk-vertraging, klaar. Drie
metingen met `-- meleecheck`: 1,45 / 1,45 / 1,40 seconden. De dood-animatie
loopt door terwijl hij oversteekt; het slachtoffer ligt dan al of is ragdoll.
`melee_move_wait` is uit de tuner EN uit effects_tuning.json gehaald, want die
knop zou nu niets meer doen: de vaste tijd stel je bij met "opruk-vertraging".

**Muis-sterfgeluiden**: Max zette `inf_die_mouse[_2,_3].wav` neer maar Godot gaf
`No loader found` -- nieuwe wav's moeten eerst geïmporteerd worden. Na
`--import` staat de categorie op 6 varianten. Terugvalketen ongewijzigd:
`inf_die_mouse_<archetype>` -> `inf_die_mouse` -> `inf_die`.

**Tuner sloeg de musket-stand niet op**. Tijdens het slepen zetten we de
spinboxen stil bij (anders herbouwt hij het model per muisbeweging); bij
loslaten zetten we dezelfde waarde nog eens "met signaal", maar Godot stuurt
`value_changed` niet als het getal al klopt. De schrijfactie bleef dus uit en
OPSLAAN bewaarde de oude stand. `_sleep_afronden` schrijft nu expliciet weg.
Gemeten met een tijdelijke probe: sleutel `mouse/infantry_hp_musket` komt nu
echt op schijf.

**Vlag-idle op meetwaarde, niet op index** (Max: "je hebt nu de verkeerde idle
vlag gekozen"). De exports zetten de rustanimaties per model in een ANDERE
volgorde. Gemeten kop/nek-uitslag per idle: atk 70/34/14 graden, spd 1/70/14,
hp 42/14/1, base en mix 42/70/14. Index 0 pakken is dus per definitie soms de
wildste. PawnView meet nu de uitslag van de kop-tracks en kiest de stilste
variant, per model gecached. Handmatig overrulen kan met `vlag_idle` in
effects_tuning.json (-1 = automatisch). Uitkomst: spd en hp krijgen hun
1-graad-variant, de rest 14 graden.

**Vlaggen** (Max): doek kleiner (0,42 x 0,26 van de poollengte, afstelbaar via
`vlag_breedte`/`vlag_hoogte` in effects_tuning.json), vaandeldrager speelt
altijd dezelfde rust-clip zodat hij rechtop staat en niet rondkijkt, en de
vaste rollen staan verder uit elkaar: vlag op 0 en 4, trommel op 2 en 6 -- dus
minimaal 4 pionnen tussen twee gelijke rollen.

## 30 juli 2026 (later) -- de versterkingen deden al drie dagen niks

**Aanleiding**: Max wilde de campagne-regels houden maar het BUDGET van een
enkel potje ("niet dat een 1v1 zo lang duurt als reinforcements voor een
campagne van minstens 4 potjes"). Bij het meten van de speelduur bleek er
iets veel ergers: **0 spawns in 33 partijen**. Historisch nagerekend over alle
runs: nacht 24 juli 36,1 spawns per partij, nachten 28 juli 0,00 in 3240
partijen.

**Oorzaak** (fan-out van vier diagnose-lenzen, alle vier op dezelfde regel
uitgekomen; de geschiedenis-lens noemde de commit): sinds C11 heet de reserve
`{"pt": N}`, maar `agents/agent.gd` bouwde de pool van een bot terug als
`{inf, cav, art}`. De bot zag dus 0 en bood zelf een lege spawn-inzet aan --
de legaliteitspoort was onschuldig (SPAWN was gewoon legaal). Commit 35704f0,
27 juli.

**Tweede vondst, stiller**: `Serializer.state_from_dict` deed hetzelfde, dus
elke replay/fold/campagne-hervatting verloor de puntenreserve. Geen golden ving
dat, want `zobrist` hasht de pools niet. Beide gefixt met "neem de sleutels
over die er staan"; twee regressietests in SpawnTests zetten het vast.

**Toen pas de regel** (C14): startreserve gemeten tegen speelduur, L2-L2, alle
matchups, 288 potjes per variant. Oude 1v1-formule (1,5 x comp = 39-52 pt) =
14,5 cycli mediaan, 24,5 aanvullingen, 11% in de cycluslimiet. 4 pt = 10,0 /
4,2 / 3%. 6 pt = 9,0 / 5,1 / 3%. 15 pt (hele campagnepot) = 11,0 / 12,7 / 8%.
**10 pt = 10,0 / 9,2 / 0%** en dat is Max' keuze ("gewoon om een 1v1 wat te
prolongeren"): dezelfde speelduur als 4 punten, ruim dubbel zoveel aanvullen,
en geen enkele partij die de cycluslimiet haalt. Gezet in `v42_default.json`
(los duel + bron van de nacht-matrix) en `rules_v42_campaign.json` (trainer):
`punten_start` 10, `spawn_totaal_max` 10. De campagne zelf levert per duel een
expliciete pool uit het grootboek en is dus onaangeroerd.

**Let op bij parallel werken**: halverwege raakte `agents/agent.gd` zijn fix
kwijt, waardoor een deel van de eerste meetdata besmet raakte (aanvullingen
zakten van 4,2 naar 1,1). Er liep tegelijk een TWEEDE sessie in deze repo (de
commits van 12:08: `sounds/` in submappen per soort, 639 bestanden, plus de
bestandsindex), dus een git-actie daarvan is de waarschijnlijke oorzaak. Data
weggegooid en schoon opnieuw gemeten; fix opnieuw aangebracht en met een
debug-run bevestigd (`her.pools = {"pt": 7}`). Les: bij twee sessies in een
repo eerst `git status` lezen voor je meet, en na een lange meting checken of
je fix er nog in staat.

**Na de geluidsverhuizing gecontroleerd**: `-- geluidcheck` meldt 73
categorieen, geen enkele zonder geluid en geen enkele die niemand afspeelt. De
submappen breken de audio dus niet.

**Voor de eerstvolgende trainingsnacht**: de weights van 28 juli hebben over een
dode economie geleerd -- de spawn-gewichten (incl. `spawn_duur`) zijn nooit
getest. Een nieuwe nacht is dus geen herhaling maar de eerste echte meting van
het aanvullen.

**Opgeruimd**: de diagnose-agents lieten probe_*.gd/tscn, mn_ab.json,
zz_check_*.json en scripts/core/bestandsindex.gd achter; verwijderd.

## 30 juli 2026 (later) -- de veertien nieuwe geluiden doen mee

- **Ingelezen**: de veertien wav's stonden op de schijf maar Godot had ze nog
  niet geimporteerd (geen .import), dus het spel kon ze niet eens laden.
- **Materiaal-laag onder elke treffer**: je hoort nu WAT er geraakt wordt.
  Artillerie -> `impact_wood`, hp-archetype (kuras) -> `impact_armor`, de rest
  `impact_flesh`; dodelijke melee legt er 50% van de tijd `impact_bone` op.
  De keuze-regel staat op EEN plek (`PawnView.impact_categorie`), zodat de
  tuner exact laat horen wat het spel kiest. Vijf speelplekken: melee,
  melee-terugslag, schot, charge, charge-terugslag.
- **Afketser hangt aan een overleefd schot** (40% kans), niet aan een mis: een
  mis bestaat niet in de regels (schade is altijd minstens 1 en de validator
  weigert een schot zonder schade). `impact_dirt` blijft dus voorlopig zonder
  plek. Dit kwam uit een audit: de eerste versie hing hem aan `damage <= 0`,
  wat dus dode code was.
- **Val-geluiden van de figuranten** deden meteen mee: `_val_categorie()` koos
  al op rol, dus val_flag/val_drum/val_horn/val_sapper vielen op hun plek en
  wat ontbreekt valt terug op `val_prop`.
- **Nieuw kijkgereedschap `-- geluidcheck`**: elke categorie met aantal
  varianten, mix-dB, tuner-dB en vertraging, plus een melding van categorieen
  zonder geluid of die niemand afspeelt. Dat laatste bracht 73 spookcategorieen
  aan het licht (elk bank-bestand kreeg ook zijn eigen categorie); die zijn bij
  de bron weggesneden. Van 145 naar 72 echte categorieen, alles gedekt.
- Ook eerlijk gemaakt: de tuner toonde voor val-geluiden een basisvertraging
  van 0.44s die de code nooit gebruikte (het geluid hangt aan het landings-
  moment van de tween).

## 30 juli 2026 -- vuur-clip, 1v1-reserve, prompts op ElevenLabs-recept

- **Vuur-animatie deed niets** (Max, HP-muis): de clip heet "Firing Rifile
  ankle shot" en mijn vertaaltabel zocht op het hele woord "fire" -- dat zit
  niet in "Firing". Nu `fir`/`shoot`/`shot`. Droogtest over alle vier de muizen:
  idle, walk, attack, melee, die, hit en ready worden nu alle vier gevonden,
  ook met "Rfile", "Bayont" en dubbele spaties. De animator hoeft niets te
  hernoemen; alleen het kernwoord moet in de clipnaam staan.
- **Ingebakken musket verborgen**: de nieuwe muizen dragen zelf een musket
  (los meshje aan RightHand). Het spel zet dat op invisible zodra hij onze
  eigen afstelbare prop in de hand hangt -- geen Blender-werk nodig. Filter is
  smal (wapenwoorden + naamloze generator-meshjes).
- **C14, vaste 1v1-reserve**: nieuwe knop `punten_start`; het losse duel start
  op 15 punten en 10 CP voor beide spelers. Drie goldens hergenereerd
  (cp_inzet, kanon_act, spawn_geblokkeerd), twaalf cosmetische diffs
  teruggedraaid.
- **Geluidsprompts herschreven** (SOUND-WISHLIST §0): een laag per prompt, zes
  korte takes in een clip, duur per take in de prompt. De oude filmscene-stijl
  ("war-beast death cry ... harness creaking") gaf sfeerclipjes in plaats van
  spelgeluid. 24 prompts om, plus het recept en de "zo niet / zo wel" uitleg.
- Checks: 1466/0, simcheck 0 afwijkingen, fuzz 25 schoon, play/shot 0 fouten.

> Levend document. Bijgewerkt terwijl we bouwen. Laatste grote update: mens-vs-AI
> volledig speelbaar, met slimme kaarten, health/stamina/attack-blokjes, animaties
> en projectie-picking.

---

## ⏵ MASTERBOUWPLAN — voortgang (bijgewerkt juli 2026)

Uitvoering volgt `MASTERBOUWPLAN.md`. Afgerond:

- **F0.0 — Specs vastgelegd + dode code opgeruimd.** `docs/spelregels-v4.2.md`
  (Deel A = 4.1.9-hr zoals geïmplementeerd, Deel B = 4.2-concept) +
  `docs/spelregels-CHANGELOG.md` (12 stille afwijkingen gedocumenteerd). Alle
  RPS-code verwijderd (Phase-enum hernummerd — er bestond nog geen serialisatie).
  **Muis-comp → [18,4,0]** (besluit Max; hertraining volgt in F1.6, de oude
  Muis-gewichten gelden als verouderd). Besluit: **geen n8n** — jobs worden
  node-cron/systemd-timers (masterplan B5 aangepast). capture.gd `-- play` hangt
  headless niet meer op de screenshot (null-texture → overslaan + nette exit).
  Checks: 422 asserts groen · rps-grep 0 (incl. tools/) · `-- play` exit 0.

- **F0.1 — SeededRng.** `core/shared/seeded_rng.gd` (class_name SeededRng:
  randi_range/randf/randf_range/randfn/pick/shuffle/fork). AIController heeft
  `rng` (default seed 1337); AIEasy, trainer (run_seed-veld) en de headless
  CMA-trainer loten er nu doorheen — de "randi alleen op de main thread"-
  beperking in capture.gd is daarmee vervallen. MatchRunner: 5e param
  `seed_val` → forkt per agent ("p1"/"p2"). Sim-CLI: `-- sim <p1> <p2> [d1]
  [d2] [seed]`; train-CLI: 5e arg = run-seed. Doctrine-loting (game.gd) blijft
  bewust globaal (pre-match invoer, gedocumenteerde uitzondering, net als
  audio/VFX). Nieuwe suite DeterminismTests (6 tests). Check-grep verfijnd naar
  kale globale calls (de SeededRng-API hergebruikt de randi_range-namen).
  Checks: 456 asserts groen · sim seed 777 2× identiek, 778 wijkt af ·
  `-- play` exit 0.

- **F0.2 — rules_config.** `core/match/rules_config.gd` (class_name RulesConfig):
  ~20 knoppen als data — vuurmodel (fire_hits_inactive/fire_blocked/
  inf_shot_over_pawn), statue_threshold (melee én schot), haven_score_cumulative
  (touch-hook in GameState.set_pawn_position), per_stat_cap, schotparameters,
  retaliation-dict, stamina_model pool|one_action, cycle_limit+tiebreak (velden;
  handhaving F0.4c), clock (velden; F0.8), doctrine-overrides, campaign-blok
  (F2). GameState.rules (clone deelt referentie — config is match-onveranderlijk);
  Rules.gd leest alles via state.rules; vuurlijn-scan gedeeld (_scan_fire_lines).
  shot_damage/shot_cost/move_range kregen state als eerste param. Sim-CLI:
  `--rules <pad.json>`; `-- genrules` schrijft defaults →
  arena/arena_configs/v41_default.json. Suite: +17 tests (RulesConfigTests).
  Checks: 503 asserts groen · sim seed 777 met/zonder default-config identiek
  (winner=2 cyclus=12 acties=339 = F0.1-baseline) · `-- play` exit 0.

- **F0.3 — actions + validator.** `core/match/actions.gd` (12 actietypes als
  const strings, make_*-factories, to_dict/from_dict met Vector2i↔[x,y],
  is_wellformed; CLAIM_TIMEOUT gedefinieerd maar illegaal tot F0.8, RESIGN
  krijgt effect in F0.4c). `core/match/validator.gd`: is_legal(state, action,
  player) met exact de bestaande foutmeldingen (charge via droge run op een
  kloon) + legal_actions (PLACE/DEFINE als voorbeeld-generator, rest volledig,
  incl. charge-enumeratie). Alle GameSession.submit_* + skip_wolf_step gaan
  door de poort; _validate_action_turn verwijderd. tests/ValidatorTests.gd:
  property-test 50 random partijen uit legal_actions (elke actie is_legal,
  elke dispatch geaccepteerd, JSON-roundtrip) + roundtrip/wellformed/samples.
  Checks: 613 asserts groen (24s) · sim seed 777 onveranderd · `-- play` exit 0.

- **F0.4a — Reducer, deel 1 (actiefase).** `core/match/reducer.gd`:
  apply(state, action, player_id) -> {ok, events, error} voor MOVE/MELEE/
  SHOOT/CHARGE/WOLF_STEP/SKIP_WOLF_STEP incl. beurtwissel (_advance_turn),
  win-check (_check_game_over) en CYCLE_RESET-event (shim draait
  _start_new_cycle tot F0.4b). Events = typed dicts {type, seq, payload};
  GameSession vertaalt ze 1-op-1 naar de bestaande signals (_relay_events) —
  game.gd merkt niets. _post_action/_after_combat/_check_action_phase_status
  uit GameSession verwijderd. Sim-CLI geherstructureerd: _run_sim-helper +
  nieuwe modus `-- simcheck` (draait tests/golden_sims.json, exit 1 bij
  afwijking; 5 vaste seeds vastgelegd op pre-reducer-commit d320647;
  medium-medium ontbreekt bewust — kan zonder cycle_limit oneindig patstellen,
  F0.4c). Checks: 613 asserts groen · simcheck 5/5 OK · `-- play` exit 0.

- **F0.4b — Reducer, deel 2 (setup-fasen + cyclus).** De volledige fasemachine
  zit in de reducer: PLACE (beide binnen -> define + CYCLE_STARTED),
  DEFINE_CARDS (commit-gate -> reveal + CARDS_REVEALED-event), **ACK_REVEAL
  per speler** (state.reveal_acks; single-ack-gat dicht — validator weigert
  dubbele ack met "Al bevestigd"), LINK met staartkoppel-logica,
  ronde/cyclus-overgangen en _start_new_cycle. GameSession = 132-regel shim
  (19 functies; F0.9-doel <=150 nu al gehaald): submits zijn 1-regel-
  delegaties, acknowledge_reveal() = compat-shim die beide spelers ackt,
  nieuw: submit_ack_reveal(player). Nieuwe events: EV_PLACEMENT,
  EV_CARDS_REVEALED, EV_CYCLE_STARTED (EV_CYCLE_RESET vervallen).
  tests/ReducerTests.gd: per-speler-ACK, fold-test opstelling->actiefase
  ZONDER Node (18 koppelingen, 2x9 actieve pionnen), initiatief-tiebreak.
  Checks: 705 asserts groen · simcheck 5/5 OK · `-- play` exit 0.

- **F0.4c — Reducer, deel 3 (RESIGN + remise; MatchRunner Node-vrij).**
  RESIGN werkt in elke speelbare fase (tegenstander wint; na GAME_OVER
  illegaal). Cycluslimiet is een echte spelregel: rules.cycle_limit > 0 en
  cyclus voorbij de limiet -> Reducer.tiebreak_winner (materiaal -> haven ->
  nabijheid; alles gelijk = -1 remise) — einde oneindige patstellingen
  (default 0 = uit, offline ongewijzigd). MatchRunner draait rechtstreeks op
  Reducer.apply met een kale GameState: geen GameSessionScript.new()/free()
  meer; dispose() is een no-op (compat). Trainer en arena volgen automatisch.
  Reducer-tests: resign per fase, tiebreak-materiaal, echte-remise-spiegel.
  Checks: 768 asserts groen · simcheck 5/5 · `-- play` exit 0 · `-- arena 4
  medium` Node-vrij (matrix, zie hieronder).

- **F0.5 — serializer.** `core/match/serializer.gd`: state_to_dict/
  state_from_dict — kaarten EENMAAL per id (all_cards), cards_defined/
  cards_revealed als id-lijsten, reconstructie herstelt referenties naar
  dezelfde objecten; bord wordt herbouwd uit pion-posities; RulesConfig
  serialiseert mee; JSON-veilig (string-keys, Vector2i als [x,y]).
  GameState.clone() ref-correct gemaakt (defined/revealed wijzen naar de
  all_cards-klonen) en blijft handgeschreven voor de AI-hot-path; de
  lockstep-test (clone == serializer-roundtrip, veld-voor-veld) bewaakt dat
  beide kopieerpaden identiek materialiseren. Dood veld
  pending_forced_move_attacker/target verwijderd (CHANGELOG-restpunt).
  tests/SerializerTests.gd (7): round-trip in ELKE fase (incl. GAME_OVER via
  resign), doorspelen-na-deserialisatie identiek (40 zetten lockstep),
  risico-7-regressie (linking EINDIGT op gedeserialiseerde staat),
  kaart-identiteit, clone-ref-correctheid, bord-herbouw met eliminaties.
  Checks: 828 asserts groen · simcheck 5/5 · `-- play` exit 0.

- **F0.6 — view.gd (fog of war).** `core/match/view.gd`: View.for_player(state,
  player) -> gefilterde JSON-veilige weergave. Blind opstellen (PLACEMENT:
  vijandelijke pionnen bestaan niet in de view), defines onzichtbaar tot de
  reveal (geen aantallen-lek; enemy_has_defined-bool is wel openbaar),
  Krokodil-dekking: stats -> "?"-sentinel (geen 0/-1), koppeling weggelaten,
  vijandelijke kaart openbaar maar linked_pawn_id geredacteerd zolang gedekt.
  UI: HP-blokjes tonen "?"-label voor gedekte vijandelijke pionnen (game.gd
  _build/_update_health_bars). tests/ViewTests.gd: leak-canary property-test
  (200+ staten over 12 partijen met Krokodil, structurele checks — letterlijk
  de test die in F4 de servergrens bewaakt) + blind-placement/define-hidden/
  sentinel-unit-tests. Nieuwe capture-modus `-- vosview`: speelt tot de
  actiefase vs Krokodil-AI en assert het "?"-label op alle 9 gedekte pionnen
  (exit-code op de assert). NB: de AI leest nog steeds de volle staat — dat
  is B8-werk (agents op views, F1.1, met full_state-ablatievlag).
  Checks: 846 asserts groen · vosview PASS (9/9) · simcheck 5/5 · play exit 0.

- **F0.7 — event-log, zobrist en golden replays.** `core/match/match_log.gd`:
  append-only {seq, player_id, action, events, hash, ts} per geaccepteerde
  actie; fold() = de replay-machine (per-actie hash-checksum);
  verify_file() = fold + eind-hash + byte-identieke eindstaat (genormaliseerd
  — JSON leest ints als floats terug). `core/match/zobrist.gd`: state-hash =
  sha256 over de canonieke serialisatie (incrementele XOR is F1-optimalisatie).
  GameSession.match_log = opt-in recording op alle drie accept-paden.
  Capture-modi: `-- record <uit.json> <p1> <p2> [d1] [d2] [seed]`,
  `-- replay <bestand>` (exit 0 bij byte-match), `-- makegoldens`.
  tests/golden_replays/: 12 goldens — 6 volledige sim-partijen (1 per
  doctrine, vaste seeds) + 6 randgevallen (terugslag-doodt-aanvaller,
  wolf-stap-in-haven-wint, charge-kill-verplichte-verplaatsing,
  vos-onthulling-bij-schade, kaart-vervalt-zonder-pion, cycluslimiet-remise).
  GoldenReplayTests: elke golden byte-identiek bij elke suite-run — breekt er
  een: bewuste beslissing + versie-bump + CHANGELOG (werkafspraak §0).
  Checks: 860 asserts groen · 12/12 goldens · 10 partijen record+replay
  byte-identiek · simcheck 5/5 · play exit 0.

- **F0.8 — klokken + CLAIM_TIMEOUT.** state.clocks[speler]={bank_ms} +
  state.turn_deadline (absoluut, in het now_ms-domein van de aanroeper);
  Reducer.apply(+now_ms-param — puur, leest zelf geen klok). Model:
  setup-fasen = increment_sec per beslissing (deadline verlopen -> defaults:
  default-opstelling / default-loadout via de validator-samples / auto-ack /
  auto-link); actiefase = increment + bank (overschot eet de bank; deadline
  verlopen = forfeit). CLAIM_TIMEOUT volledig: validator checkt structureel
  (klokken aan + deadline gezet), de reducer valideert het verstrijken met
  now_ms. bank_sec 0 (default) = klokken uit -> offline ongewijzigd; game.gd
  blijft offline de klok-autoriteit (20s-driver) maar de fasetimer leest
  state.turn_deadline zodra die gezet is. UI: opgeven-knop (met bevestiging)
  onder de sfeer-knop -> GameSession.submit_resign. Ook: submit_claim_timeout.
  Serializer + clone dragen clocks/turn_deadline mee -> goldens geregenereerd
  (formaat-wijziging, geen regelwijziging; simcheck 5/5 bewijst dat).
  tests/ClockTests.gd (7): increment spaart bank, trage actie eet bank, claim
  voor deadline geweigerd, lege bank = forfeit, timeout in define =
  default-loadout, klokken-uit = claim illegaal, klok-round-trip.
  Checks: 885 asserts groen · simcheck 5/5 · play exit 0 · vosview PASS.

- **F0.9 — acceptatie (headless-deel AF).** Alle Claude-checks groen:
  (1) suite 170 tests / 900 asserts (was 111/310 bij de nulmeting) incl. 5
  extra dekkingstests (timeout-in-reveal ackt achterblijver, timeout-in-
  linking koppelt automatisch, dekking-vervalt-bij-cyclus-reset,
  haven_touches-round-trip, vervalst-log-wordt-afgekeurd — het F4.5-anti-
  manipulatiepad); (2) 10-partijen-replay 10/10 byte-identiek (F0.7);
  (3) leak-canary + vosview PASS; (4) play/simcheck/arena-matrix groen;
  (5) GameSession 162 regels (~150-doel; incl. commentaar), Rules.apply_
  buiten de reducer alleen nog in AIController-SIMULATIE op klonen
  (gedocumenteerde uitzondering; live-staat muteert uitsluitend via de
  reducer; F1.1 agents-op-views ruimt dit op).
  **MAX-acceptatie gespeeld: alles klopt** — F0 IS FORMEEL AF (juli 2026).

- **Regelwijziging 4.1.10-hr (besluit Max, na F0):** kaartdefinitie is
  begrensd door je vrije pionnen; 0 vrije pionnen = ronde overslaan, de
  tegenstander gaat alleen door. Doorgevoerd in validator (expected_define_
  count), reducer (define-gate + fase-entry-gates), AI, sim/MatchRunner en de
  kaartwaaier-UI. Versie-bump 4.1.9-hr -> 4.1.10-hr; CHANGELOG-entry; goldens
  + golden_sims-baselines geregenereerd (bewuste breuk conform werkafspraak).
  3 legacy-tests bijgewerkt; 3 nieuwe regeltests. Checks: 915 asserts groen ·
  simcheck 5/5 (nieuwe baselines) · play exit 0.

## F1 — Arena v1 (bezig)

- **F1.1 — Agent-interface op views.** Hard contract (bouwplan par. 7.1):
  `decide(view, legal, rng) -> Action`. `agents/agent.gd` (basisklasse +
  reconstruct_state: view -> speelbare staat met PUNTSCHATTING voor gedekte
  stats = gemiddelde over onthulde vijandelijke kaarten, B11; gedekte pion
  heeft per definitie nog geen schade dus current=max klopt per constructie),
  `l0_random.gd` (uniform random — fuzz-motor), `l1_greedy.gd` (kill > haven >
  schade > random; arena-werkpaard), `l2_weights.gd` (AIMedium-eval op de
  reconstructie; per-doctrine-profielen uit ai_weights.json),
  `l3_search.gd` (Hard/Ultra-search, zelfde reconstructie),
  `agent_runner.gd` (EEN uniforme lus voor alle fasen: view + legal_actions +
  Reducer.apply; geen fase-dispatch, geen Node — de kiem van arena/run.gd en
  het worker-model). full_state-vlag (B8) -> View.for_player(redacted=false):
  fog-loze view voor ablatie. View uitgebreid met haven_touches (publiek).
  Vangnetten gemeten: illegal_count/fallback_count op de runner.
  Oude AIEasy..Ultra blijven als UI-wrappers (plan-conform) tot de game-UI
  overstapt. tests/AgentTests.gd: L0 20 volledige partijen 0 illegaal/0
  fallback (cycle_limit begrenst), puntschatting-test, L1-kill-test,
  B8-ablatie gelogd (view 2 - full 2 - remise 0 over 4 Krokodil-spiegels;
  echte meting volgt in F1.6). Checks: 1013 asserts groen (1m32s) · simcheck
  5/5 · play exit 0 · vosview PASS.

- **F1.2 — standalone runner + metrics.** `arena/arena.tscn` + `arena/run.gd`:
  `godot --headless --path . res://arena/arena.tscn -- --config <json> --out
  <map> [--seed-offset N]`. Configs in arena/arena_configs/: quick_l1 (2
  doctrines x 10), matrix_l1 (alle 36 richtingen), vos_ablatie_l2 (B8:
  full_state p2). `arena/metrics.gd`: per game EEN jsonl-regel met de
  letterlijke par. 8.2-mapping — cycli, winnaar+methode (haven/eliminatie/
  tiebreak/remise + trigger), zobrist-herhalingen, standbeeld-kills per
  kaartprofiel (1/5/1-oogst), schoten per kanon + kanonnen-zonder-schot-%
  (benadering geblokkeerde intenties), koppelverdeling kaartprofiel->type
  PER SPELER, overkill-per-kill (Leeuw-spiraal), schade-per-actie (Muis),
  winmethode per havenvak (hoekfort), full_state-vlaggen (ablatie).
  Header-regel: git-sha + config + ts; game-regels ZONDER wallclock ->
  zelfde config+seed = byte-identieke jsonl (bewezen: run A == run B).
  arena.ps1 (multi-proces: 1 per core, seed-offset, merge), arena.bat ->
  nieuwe runner (FOW_NOPAUSE-guard; oude capture-pad blijft, zie
  arena.bat.oud). results/ in .gitignore (B10: reproduceerbaar uit
  config+seed). EERSTE DOORVOERMETING: 3.0 match/s/core met L1 (was 0.13
  met de oude Node-runner — 23x sneller; F1.3-doel >=5/s is dichtbij).
  Checks: schema 0 fouten · reproduceerbaarheid bewezen · 1013 asserts
  groen · simcheck 5/5 · play exit 0.

- **F1.3 — doorvoer: DOEL GEHAALD (7.9 match/s/core met L1; eis >=5).**
  Meetladder (bench: `arena.tscn -- --bench [l0|l1|l2|l3] [games]`, 60 games,
  ruis +-10%): baseline 2.4 -> L1 leest de view direct i.p.v. staat-
  reconstructie per beslissing (3.9) -> reducer-fast-gate: goedkope poort
  (fase/beurt/eigendom) + atomaire Rules.apply_*-validatie, geen dubbele
  pathfinding en geen charge-kloon meer (4.2; simcheck bewijst identiek
  gedrag) -> kosten-BFS zonder pad-array-kopieën in legal_actions (4.3) ->
  view-dieet: geen geelimineerde pionnen/dode kaarten in de view (L1 neutraal,
  L0/fuzz +35%, payload begrensd voor F4) -> DE KLAPPERS: check_win en
  can_player_act zonder array-allocaties (draaiden na elke actie) +
  wants_view-zelfverklaring (L0 nooit een view, L1 alleen in de actiefase;
  minder info aanvragen is nooit valsspelen) -> 7.86 match/s (3346 besl./s).
  L0 (fuzz-motor): 0.62 -> 3.19/s (5x). Gedocumenteerde doorvoer: L2 0.16/s
  (96 besl./s), L3 0.02/s — eval/search-optimalisatie is F8-werk (B1-
  escalatie naar C# is NIET nodig: GDScript haalt het doel ruim).
  Nachtcapaciteit (extrapolatie conform plan): 8 cores x 8 uur x 7.86/s
  ~ 1,8 MILJOEN L1-partijen (eis >=150k: 12x overhead). Gedrag bewezen
  identiek na elke trede: 1013 asserts groen · simcheck 5/5 · play · vosview.

- **F1.4 — fuzz & invarianten als nachtvangnet.** `arena/fuzz.gd`: ArenaFuzz
  draait L0-vs-L0 (seeded, doctrine-rotatie, cycle_limit 12) met een
  FuzzChecker op de metrics-haak. Invarianten per actie: (1) pion-ids bevroren
  na de opstelling + geen opstanding uit de dood, (2) HP-delta == damage +
  terugslag uit de events (reset-bewust: verlaat de actie de actiefase, dan
  unlinkt _start_new_cycle iedereen VOOR de winnaarbepaling — correct gedrag,
  geen schending), (3) 0 illegale/fallback-keuzes, (4) fold(log) == eindstaat
  (byte-vergelijking; MatchLog.record kreeg with_hash=false zodat per-actie-
  sha256 niet nodig is), (5) view-lek-canary gesampled per 25 acties. Elke
  schending -> repro-json in results/fuzz/ met seed+schendingen+volledig log.
  CLI: `arena.tscn -- --fuzz [games] [seed]` en `-- --fuzz-selftest` (sabotage:
  spook-pion + HP-mutatie op een gevechtsactie — een kale +1 HP was NIET
  genoeg, de cyclus-reset wist hem uit; les: de tester testen loont). De fuzz
  vond meteen 11 valse alarmen in de eigen checker (cyclus-reset-semantiek) —
  vangnet werkt. CHECK: 500 partijen schoon (3.75/s incl. checks) · selftest
  3/3 gevangen · 1016 asserts groen (FuzzTests nieuw) · simcheck 5/5 · play ·
  vosview.

- **BACKLOG C12 basis-HP cavalerie (besluit Max, 27 juli).** Ruiter/bigbro
  krijgt ALTIJD basis-2 HP plus de kaart-HP erbovenop (kaart 1 -> ruiter 3).
  Bouwen als RulesConfig-knop `basis_hp` per type (default {} = 4.1
  byte-identiek; v4.2-configs zetten {"cav": 2}). Toepassen waar de pion
  z'n HP uit de gekoppelde kaart krijgt (link/reveal-pad), UI-blokjes
  rekenen mee. Logica: in het punten-model kost een ruiter 2 punten en
  hoort hij taaier te zijn dan een 1-punt-soldaat. Daarna trainen + arena.

- **GEFIXT kanon-visuals (28 juli): `cannon_act` ontbrak in de effecten-match van `_on_action_performed` — regels verwerkten de kill, maar geluid/kogel/ragdoll vielen door de match heen. Nu vertaald naar het 4.1-equivalent (shoot->shot, roll->move; result-velden identiek). Nog open uit dit onderzoek: de 'Lambda capture freed'-regen in shoottest (kaartfases, verdacht: i18n-refactor) + headless-guard voor de shoottest-screenshot.**
  *(oorspronkelijk spoor hieronder)*
- **OPEN BUG kanon-visuals (28 juli, playtest Max) — ONDERZOEK LOOPT.**
  Symptoom: kanon "schiet niet meer" en geen dood-animatie; andere
  animaties wel; combat-feel staat AAN. Engine bewezen groen (12
  CannonTests + kanon_act-golden). Sporen: (1) REPRODUCEERBAAR:
  `-- shoottest` toont een regen "Lambda capture at index 0 was freed"
  (gdscript_lambda_callable.cpp:110) al tijdens de define/link-fasen —
  verdacht: de i18n-refactor van card_hand/card_view (pull 5adf140) of
  een tween-lambda die een gefreede node vasthoudt. (2) `_fire_projectile`
  gebruikt exact dat patroon: tween_method-lambda + tween_callback op
  `proj` — als proj vroeg gefreed wordt (scene-wissel/debris-ruiming)
  vuurt de inslag nooit → schot zonder visuals, kill zonder ragdoll,
  precies Max' symptoom. (3) shoottest hangt headless sowieso op een
  screenshot zonder null-guard (los euvel, fixen). VOLGENDE STAPPEN:
  lambda-bron pinnen (run shoottest met --verbose backtrace), proj-tween
  robuust maken (is_instance_valid-guard of proj in battlefield_debris
  met eigen opruiming), null-guard screenshot in shoottest, daarna
  in-game verifiëren met een campagne-duel. Vraag aan Max uitgezet:
  sterft de pion wél regel-technisch (HP-blokjes weg) zonder animatie?
  Dat bevestigt de visuele-keten-hypothese.

- **C11 AF + spawn-inkoop + menu (28 juli).** Het hele economie-pakket
  speelbaar: (1) spawn-fase = inkooplijst voor de mens (+soldaat 1 pt /
  +ruiter 2 / +kanon 3, max 3 per cyclus, haven-prio-vakken automatisch);
  bots kregen een duur-eerst spawn-variant + leerbaar gewicht `spawn_duur`
  (trainer leert kwaliteit vs lijven per factie). (2) CP-ruil 2:1 (actie
  `exchange`, alleen donatie-venster, hub-knop, feed-event). (3) Factie-
  budgetten: CRules.budget_bonus (Muis +4 pt, Beer +3, Wolf +2 pt/+4 CP)
  als eigen ledger-boeking bij setup; compat: pre-C11 leeg. (4) Hub toont
  overal EEN versterkingsgetal (1/2/3-waarde), saldi-regel "Veldleger:
  altijd vol", donaties via [+1]/[+CP]-plusjes per teamgenoot. (5) C12
  basis-2-HP bigbro nu ook in campagne-duels. (6) Hoofdmenu herbouwd:
  SOLO/MULTIPLAYER/Speluitleg/Instellingen, campagne-moeilijkheid
  (easy/medium/hard schaalt de bord-AI via CampaignBridge), trainer uit
  het menu. Vangst onderweg: budget_bonus-serialisatie niet byte-stabiel
  (cp:0 expliciet gemaakt). CHECKS: 1456 asserts, simcheck 0, solocheck
  3/3, shot/play schoon. Werkafspraak nieuw: snelle poort (~3 min) bij
  itereren, volle batterij alleen als commit-poort (Max wachtte te veel).

- **BACKLOG hoofdmenu-herstructurering (besluit Max, 27 juli — VOLGENDE
  BOUWKLUS).** Hoofdmenu wordt: SOLO / MULTIPLAYER (disabled tot F4) /
  Settings / How to play. SOLO -> "1v1" of "Campagne"; daarna pas de
  moeilijkheidsvraag — OOK voor de campagne (easy/medium/hard bepaalt
  duel_ai + bot-niveau in SoloDriver/hub). AI Trainer verdwijnt uit het
  menu; Model-tuner komt onder Settings. Minder knoppen, logischer flow.
  Design-docs/wireframes (docs/design/ + UI-DESIGN-BRIEF) moeten mee.
  Paneel al gedaan: "Training 1v1 (4.1-regels)" vs "Training campagne
  (v4.2)" (die laatste = campagne-fitness: neemt 1v1-learnings als
  startpunt en traint lange-termijn/economie incl. factie-tweaks), en
  VOLLE TRAINING-NACHT draait nu de hele pijplijn automatisch:
  trainen -> wachten -> arena-meting (4.1+v4.2) -> dashboard
  (training_nacht.ps1; een knop, alles vanzelf — Max wil minder knoppen).

- **UX-iteratie 2 + wanhoop-modus (27 juli, playtest Max).** Drie
  pakketten. (1) F3.4c: de mens heeft VOORRANG op de bot-simulaties —
  campagne starten = loting-overzicht, aftel, laadscherm, direct je duel;
  CampaignBridge simuleert de overige duels op een thread terwijl je op
  het bord staat; terug in de hub druppelen gemiste battlereports als
  afspeel-animatie binnen (fade-in, feed_gezien overleeft de wissel);
  bark-%s-bug gefixt (replace i.p.v. format). (2) Spawn-gevoel:
  poef-reveal (spawns landen een voor een op het bord, define-hand wacht)
  + haven-prioriteit bij plaatsing (midden-havens, hoek-havens, dan de
  rest — zelfde sampler voor bots en mens-suggestie). (3) WANHOOP-MODUS
  in AIController.evaluate (easy/medium/L2/trainer): onder de 7 eigen
  pionnen overstemmen havenopmars (6x) en kills (300/vijand) elke
  voorzichtigheid en vervalt de eigen risico-straf — tiebreaks horen
  niet te bestaan (Max). Sim-goldens bewust geregenereerd: zelfde
  winnaars, kortere potjes (bv. muis-wolf 14→11 cycli);
  golden_sims.json bijgewerkt, simcheck 0 afwijkingen. NOG OPEN (C11,
  besluit Max 27 juli, volgende klus): reinforcements als één
  puntenpot (soldaat 1 / ruiter 2 / kanon 3), doneren via plus-knopjes
  achter namen, CP-ruil 2:1 naar versterkingen, per-factie
  budget-knoppen (Muis/Beer meer punten, Wolf meer CP), en de
  saldi-regel moet "veldleger altijd vol" expliciet maken.

- **Campagne-fitness in de trainer (26 juli) — "lange termijn denken".**
  Onder v4.2-regels traint `_train_match` niet meer op kale winst maar op
  het campagne-puntensysteem: haven 3 > eliminatie 2 > tiebreak 1 >
  verlies 0, genormaliseerd + spaarbonus (0.15 × restleger-fractie + 0.05
  × CP-fractie, óók voor de verliezer — in de campagne houd je wat
  overleeft, dus sparen loont altijd). 4.1-training ongewijzigd
  (win-based). De relatieve gate blijft geldig: kandidaat en referentie
  scoren op dezelfde schaal. Trainingsconfig rules_v42_campaign.json:
  cycle_limit 12→20 (echte winst kost 5-16 cycli; met 12 trainde je deels
  op het tiebreak-vangnet). Rooktest: fitness fractioneel (2.4/6 etc.),
  gate werkt, één generatie ±10-15 min per factie → nachtrun ≈ 30-45
  generaties per factie. Max start training zelf via het paneel (B13).

- **C9 GEBOUWD (26 juli) — playtest-iteratie 1: volle rondes + nieuwe hub.**
  Max' eerste playtest-feedback, direct verwerkt. Regels: ronde 1 = LOTING
  (nieuwe systeem-actie, alle 16 random 1v1-paren als data in het log,
  geen raad), ronde 2+ = iedereen vecht (duels_per_ronde_max 2→8, aantal
  = kleinste team, raad stemt de paren om-en-om), doneren aan élke levende
  teamgenoot (superset, oude logs geldig), cycluslimiet op campagne-duels
  6→0 (uit — vrijwel alles eindigde in het tiebreak-vangnet omdat echte
  winst 5-16 cycli kost; noodstop max_steps 3000 blijft). Compat:
  CRules.from_dict valt voor ontbrekende sleutels terug op de oude
  waarden, dus pre-C9-saves folden ongewijzigd; de hub start dan een
  verse campagne. UI: hub herbouwd naar Max' schets — links 8 bolletjes
  eigen team, rechts de vijand (initiaal in teamkleur, geel randje =
  vecht nu, grijs = gevallen, saldo-regel per lid), chatlog eronder,
  fase-paneel onderaan. Meetmodus `-- duelstats` toegevoegd (methode-
  verdeling per cycluslimiet). CHECKS: 1473 asserts groen (nieuwe
  loting/volle-ronde/donatie-tests), hub-shot 0 fouten.

- **F3.3 AFGEROND (26 juli) — touch-equivalent voor rechtermuis-acties.**
  Eén contextuele knop linksonder op het bord ("ContextKnop", 64px hoog)
  die meebeweegt met de modus: "Ongedaan" tijdens zelf opstellen,
  "Overslaan" bij de gratis Wolf-stap, "Deselecteer" bij een selectie in
  de actiefase. Rechtermuis blijft werken; dit is dezelfde actie voor
  vingers (mobile-first, online-plan-voorwerk). Daarmee is het hele
  F3-UI-blok af. CHECKS: play, vosview PASS, 1459 asserts groen.

- **F3.3-rest GEBOUWD (26 juli) — Grootboek, BracketView, MatchReport-detail.**
  `LedgerScreen` (scripts/ui/campaign/): het volledige, openbare
  campagne-ledger als sorteerbare tabel (naam/team/status/soldaten/
  cavalerie/kanonnen/totaal/CP/punten; mens geel, gevallenen gedimd;
  statische `rijen()`-helper is puur en getest). Hub kreeg een
  "Grootboek"-knop. `BracketView`: bij de burgeroorlog toont het
  fase-paneel wie NU op het bord staat, wie in de wachtrij wacht en wie
  nog leeft. Battlereport-kaartjes in de tijdlijn zijn nu klikbaar →
  dialoog met verliezen per type én CP-delta per speler (cp_delta zit
  nu ook in de feed). Shot-modes uitgebreid: `-- shot ledger` (16 rijen)
  en `-- shot bracket` (synthetische burgeroorlog-fixture). REST F3.3:
  touch-equivalenten voor rechtermuis-acties (hoort bij het
  online-plan-voorwerk). CHECKS: suite groen, shots 3× 0 fouten.

- **F3.4b GEBOUWD (26 juli) — het mens-duel op het echte bord.** Het
  sluitstuk van F3: als de mens genomineerd is, pauzeert de SoloDriver
  (wacht_op_mens dekt nu ook DUELS/BURGEROORLOG via `mens_duel()` — alleen
  als het mens-duel het eerstvolgende open duel is), de hub toont "Speel
  het duel op het bord" en de nieuwe autoload **CampaignBridge** draagt de
  driver over de scene-wissel heen: duel-config uit `duel_rules_voor()`
  (mens = bord-P1, comp gecapt op voorraad, rest reserve, CP per speler),
  game.gd start zonder menu's direct het v4.2-duel tegen medium-AI met de
  échte vijandsnaam, en na game-over boekt `verwerk_duel_uitslag()` (nu
  gedeeld tussen bot-pad en bord-pad) verliezen/CP-delta/methode als
  MATCH_RESULT terug en keert de scene terug naar de hub — autosave loopt
  gewoon door. Hoofdmenu kreeg "Solo-campagne (v4.2)". Opgeven op het bord
  = tiebreak-winst voor de vijand (v1). CHECKS: 1429 asserts groen (nieuwe
  SoloTest speelt een hele campagne waarin élk mens-duel via het
  bord-pad loopt en het log daarna replayt), play + shot 0 fouten.
  **Hiermee is de F3-MAX-check speelbaar: solo-campagne begin→kampioen.**

- **F3.4 AFGEROND (26 juli) — persistentie & hervatten ("durf te sluiten").**
  CLog kreeg `autosave_pad`: setup schrijft de meta-regel (incl. seed +
  beginstand), elke record appendt één jsonl-regel en sluit het bestand —
  een kill verliest dus hooguit de actie die nog onderweg was. Terugweg:
  `CLog.laad_jsonl` + `SoloDriver.hervat(pad)` (fold op de beginstand;
  `_duel_teller`/`duels_gespeeld` uit de MATCH_RESULT-entries; feed start
  met een hervat-kaartje — barks van vóór de herstart zijn presentatie, de
  agents her-seeden van de campagne-seed). De CampagneHub hervat bij het
  openen automatisch `user://campaigns/solo/campagne.jsonl` (uitgespeeld =
  vers beginnen). Vangst van de CHECK-test: Godot's `JSON.stringify`
  sorteert keys, waardoor MATCH_RESULT-dicts (`verliezen`/`cp_delta`) na
  een disk-roundtrip in andere volgorde foldden dan live → CReducer boekt
  nu op oplopende speler-id (`_gesorteerde_ids`), zodat key-volgorde het
  ledger nooit kan veranderen — precies wat de F4-upload (JSON-transport,
  B6) straks nodig heeft. Match-logs per duel volgen bij de echte
  game-scene-koppeling (F3.3-rest). CHECKS: halverwege sluiten + hervatten
  → byte-identieke staat; bestand na élke actie leesbaar én foldbaar;
  hervatte campagne speelt uit tot kampioen; volle suite groen.

- **F3.3 kern GEBOUWD (25 juli) — de CampagneHub.** Een mobile-first
  scherm dat de hele solo-campagne draagt: tijdlijn met barks en
  battlereports (nieuwste onderaan, autoscroll), eigen pool/CP/punten in
  de kop, en het fase-paneel: raad-ballot (eigen + vijand-dropdown),
  doneer-paneel (4 steppers, caps zichtbaar, "klaar met doneren") en het
  testament ("helft naar 1 speler" of "alles verbrandt"). Bots (incl.
  duels) draaien op een thread; de UI pauzeert alleen als JIJ aan zet
  bent (SoloDriver.wacht_op_mens + submit_mens_*). Nieuw gereedschap:
  capture `-- shot campaign_hub [seed]` (fixture + node-asserts + PNG
  buiten headless) — 0 fouten. Kanttekening: het mens-DUEL wordt nog
  gesimuleerd; de koppeling naar de echte game-scene is F3.4, en losse
  schermen (grootboek-tabel, BracketView) volgen. CHECKS: 1328 asserts
  groen - simcheck 5/5 - shot 0 fouten.

- **F3.2 AFGEROND (25 juli) — SoloDriver + persoonlijkheden.** De campagne
  LEEFT: 16 bots spelen van raadsronde tot kampioen. agents/campaign/:
  Personalities (8 archetypes met gewichten + temperatuur + barks: trouwe
  generaal, rat, gierigaard, berserker, strateeg, opportunist, twijfelaar,
  kamikaze) en CampaignAgent (beslist op de CVIEW; leest andermans voorraad
  door het publieke grootboek op te tellen - de Among Us-skill).
  scripts/game/solo_driver.gd: fase-orkestratie, bot-duels via MatchRunner
  met het echte campagne-bezit (comp_override + pools + cp per speler -
  nieuwe campaign-keys; C7 arm-start werkt), MATCH_RESULT met battlereport
  (methode/verliezen/cp_delta incl. winst-tarief), barks + rapporten in de
  feed, alles door CReducer + CLog (replay byte-identiek). CLI: capture
  `-- solocheck [seeds]`. Bugfix onderweg: de duel-lus overleefde de
  lijst-vervanging bij rondewissel niet. CHECK: suite 1328 groen (SoloTests:
  5, kleine 6-speler-campagnes op easy); 20-seeds-run: 17/20 kampioen +
  determinisme OK; de 3 uitschieters zijn CONVERGENTIE-caps, geen deadlocks
  (ronde 120 nog actief): kunstmatig korte check-duels geven tiebreak-rijke
  uitkomsten -> weinig doden -> trage uitputting. Met normale duel-limieten
  convergeert alles (34-44 rondes, ~2.5 min/campagne op easy). SIGNAAL voor
  Max: campagneduur hangt aan duel-dodelijkheid (tuning na de eerste
  speelervaring; 60s-wall-clock-doel uit het masterplan is met de rijke
  v4.2-duels niet realistisch en losgelaten). Volgende: F3.3 (campagne-UI).

- **F3.1 AFGEROND (25 juli) — CampaignCore.** core/campaign/: crules
  (alle spec-knoppen als data), cstate (LEDGER als bron van waarheid:
  saldi = som van events, nooit muteerbare velden; serialisatie roundtrip
  byte-identiek), cactions (NOMINATE=stem v1, DONATE, KLAAR_MET_DONEREN,
  MATCH_RESULT, TESTAMENT, TICK_DEADLINE — deadlines als actie zodat
  defaults in het log staan), creducer (nominatie-telling met staking ->
  kleinste pool; donatiecaps hard; C3-uitvallen; testament helft/2/timeout-
  verbranding; punten 3/2/1/0 + remise = beide tiebreak; teambonus ook
  doden; burgeroorlog-seeding punten->CP->pool met vrijloting en knock-out
  zonder ruil; kampioen-kroning), cview (grootboek publiek, stemmen
  team-only, doden zien alles, eigen saldi kant-en-klaar) en clog
  (campagne-log met fold-replay). v1-keuzes gedocumenteerd in creducer:
  nomineren = stemmen; remise-bracket: hoogste seed door; burgeroorlog-
  verliezer verbrandt restant. CHECKS: 1273 asserts groen (CampaignTests:
  15 tests over het spec-contract, incl. log-fold byte-identiek) -
  simcheck 5/5. Volgende: F3.2 (SoloDriver + 15 persoonlijkheden).

- **F3.0 AFGEROND (25 juli) — campagne-spec definitief.** Ontwerpsessie met
  Max (besluiten C1-C8): twee teams van 8; je neemt je VOLLEDIGE bezit mee
  het duel in (comp opstellen gecapt op voorraad, rest = spawn-reserve;
  armoede = kleiner starten); uitvallen = duel verloren en voorraad te klein
  voor een nieuwe startopstelling (dan testament); burgeroorlog zodra een
  team is uitgeschakeld (seeding punten->CP->pool, geen raad/ruil); punten
  haven 3 / eliminatie 2 / tiebreak 1 / verlies 0 + teambonus +2 ook voor
  doden; ronde-flow raad -> doneren -> duels; de 15-spawn-cap geldt ook in
  campagne-duels. docs/campagne-spec.md is DEFINITIEF (0x TE BEVESTIGEN,
  28 testgevallen als F3.1-contract). Volgende: F3.1 CampaignCore
  (cstate/cactions/creducer/cview/crules + ledger).

- **Leerbaar spawn/CP-beleid GEBOUWD (25 juli, opdracht Max).** Vier nieuwe
  trainbare gewichten in AIController: spawn_drempel (1.0 = aanvullen tot
  vol; lager = reserve sparen) en cp_bet_r1/r2/r3 (inzet-wens per ronde,
  default alles op r3). choose_spawn/choose_cp_bet vervangen de vaste
  heuristieken in MatchRunner (trainer!), de sim-runner, AgentL2 en de
  spel-AI in game.gd — defaults zijn bewezen gedragsneutraal (v4.2-sim
  byte-identiek). De trainer muteert ze vanaf nu gewoon mee; bestaande
  profielen krijgen de defaults bij het laden (merge). Paneel-knop
  "Training v4.2 (6 facties)" erbij (traint onder rules_v42_campaign =
  de 1v1-setting). Volgende leerslag: campagne-scope (sparen over
  wedstrijden, doneren/testament) bij F3's decide_campaign.
  CHECKS: 1177 asserts groen (leerbaarheids-test: extreme gewichten geven
  ander gedrag) - simcheck 5/5.

- **F2.6 deel B GEBOUWD (25 juli) — het v4.2-duel is speelbaar.** Na Max'
  sturing ("bouw gewoon het spel"; D15 geparkeerd als B16, sweeps gestopt):
  de mens-vs-AI-flow spreekt nu volledig v4.2. Nieuw in game.gd (12 edits):
  regelset-keuze bij de matchstart (Klassiek 4.1 / Campagne-duel v4.2 via
  v42_default.json), CP-bod-overlay voor de kaartwaaier (blind, opties 0..max,
  timeout = zonder inzet door), kaartwaaier met per-kaart CP-budget
  (card_hand.configure kreeg bonus_kaarten: eerste N kaarten budget+1),
  versterkingen-overlay in CYCLE_SPAWN (aanvullen/niets; AI dient blind
  aanvul-inzet in; timeout vult automatisch aan), kanon-vertaling op alle
  4 submit-plekken (klik/timer/AI: artillerie -> submit_cannon_roll/shoot
  onder campaign), AI-bet-heuristiek ronde 3, en Reserve+CP in de HUD-teller
  (alleen eigen kant, D12). CHECKS: play-mode draait, 1162 asserts groen,
  simcheck 5/5. OPEN: de MAX-check — een echt potje spelen (spawn, CP-inzet
  en kanon-act moeten kloppend voelen); daarna F2.6 afvinken. MatchSetup-
  presets (Aanvallend/Gebalanceerd/Verdedigend) doorgeschoven: de bestaande
  moeilijkheids+doctrine+regelset-flow dekt de matchstart.

- **F2.5 AFGEROND (24 juli) — agents leren v4.2.** L1: spawn maximaal
  (volste sample-optie), CP alleen op de ronde-3-kaarten (masterplan-
  heuristiek; wants_view nu ook in define-fases voor round_number),
  kanonschot telt mee in kill/schade-takken en cannon_roll in de haven-tak.
  L2: zelfde spawn/bet-heuristiek + verdikt zijn generate_cards-kaarten met
  het CP-punt (validatie op de reconstructie) + vertaalt legacy move/shot
  van de eval naar cannon_roll/shoot onder campaign. Agent.reconstruct_state
  kent nu pools/cp/bets/spawn_done (dekt de laatste review-melding van
  F2.2). Validator._sample_card_sets maakt bet-kaarten budget+1 (anders
  verbrandde de sample-flow de inzet onbenut). MatchRunner (trainer-pad):
  rules-param, CYCLE_SPAWN/BET_CP-afhandeling, kanon-vertaling; AgentRunner
  init_pools. Trainer-CLI: 6e arg = rules-json (v4.2-trainen), live bewezen
  met een minigeneratie onder 4.2.0. ArenaMetrics telt spawns/cp_bet (+
  cannon_act in schoten/statue-kills). CHECK deel 1: L1 22 spawns + 12 CP
  per partij, L2 40 + 12 (elk 72 partijen, 0 illegaal). Deel 2 (hertraining
  >55%) = lange run voor Max: paneel/CLI met rules_v42_campaign.json.
  CHECKS: 1162 asserts groen (V42AgentTests: 4) - simcheck 5/5 - fuzz 100
  schoon - bench 5.3/s (iets lager door define-views, boven het 5-doel).
  Volgende: F2.6 (arena-hermeting + UI onder v4.2).

- **F2.4 AFGEROND (24 juli) — CANNON_ACT (stamina-kanon).** Union-actietype
  (D14) met sub roll|shoot; is_wellformed valideert per sub (RETREAT is
  per constructie misvormd, D9). ROLL hergebruikt apply_move (afwijkende
  kost boekt bij), SHOOT hergebruikt apply_shot; Rules._shot_ranges en
  shot_cost zijn campaign-bewust (kanon_dracht_max/kanon_actie_kost —
  dode zone en blokkade ongewijzigd). Onder campaign weigeren MOVE/SHOOT
  artillerie (volle poort EN fast-gate) en genereert legal_actions
  cannon_act-varianten; melee blijft MELEE (bewuste keuze, genoteerd in
  CHANGELOG). 4.1-compat expliciet getest. Golden #15 "kanon_act" (roll +
  standbeeld-schot; P2 overleeft via bord+pool). CHECKS: 1151 asserts
  groen (CannonTests: 12 tests) - simcheck 5/5 - vosview - fuzz 100
  schoon - bench 7.8/s. Volgende: F2.5 (agents leren v4.2).

- **F2.3 AFGEROND (24 juli) — BET_CP in de match.** Blinde CP-inzet als
  apart actietype (D14) voor de eigen define: state.cp (init cp_start=6,
  D13), cp_bets/cp_bet_done per ronde, saldo direct verbrand (D2, ook
  ongebruikt), validator eist bet-voor-define en 0..min(saldo, kaarten);
  define-check staat per ingezette CP precies 1 kaart met budget+1 toe
  (D1/D4, budget+2 kan nooit). Initiatief werkt vanzelf via de stats (D3,
  expliciet getest). Events: cp_bet (blind, geen hoogte), cp_admin bij de
  reveal en cp_earned bij haven/eliminatie-winst (8/4, saldo onaangeraakt
  — campagnepot). View: eigen saldo/inzet zichtbaar, vijand-saldo "?"
  (zelfde D12-knop als de pool). Golden #14 "cp_inzet" (bet -> dikke kaart
  -> reveal met initiatiefwinst). CHECKS: 1124 asserts groen (CpTests: 13
  tests) - simcheck 5/5 - play - vosview - fuzz 100 schoon. Volgende:
  F2.4 (CANNON_ACT, zonder RETREAT).

- **F2.2 review-naspel (24 juli):** adversariele 4-dimensies-review op de
  diff vond 1 bevestigde lek + 2 door mij nabeoordeelde punten. GEFIXT:
  (a) expliciete startpool lekte integraal via view.rules.campaign.pools
  (omzeilde het ?-sentinel; nu geredigeerd op een kopie, canary-test erbij);
  (b) auto-commit bij lege pool gebeurde instant bij fase-start -> de
  tegenstander las "pool leeg" af aan enemy_has_spawned (timing-lek); de
  lege inzet wordt nu pas geregistreerd zodra de gate rond is. GENOTEERD:
  cycle_admin-event bevat beide pools en is server/log-only -> de F4-event-
  stream MOET per speler redigeren (comment bij het event); en
  Agent.reconstruct_state neemt pools/spawn-velden nog niet mee -> F2.5-taak
  (v4.2-agents). Review-run zelf strandde deels op de maand-limiet van het
  Claude-abonnement (6/8 subagents); de 3 onbeoordeelde meldingen zijn
  handmatig nagelopen. CHECKS na fixes: 1076 asserts groen - simcheck 5/5.

- **F2.2 AFGEROND (24 juli) — pools, CYCLE_SPAWN en SPAWN in de reducer.**
  Config-gated: zonder campaign-blok byte-identiek 4.1.10-hr (suite bewijst
  het); met blok rules_version 4.2.0. Nieuw: Phase.RESET + Phase.CYCLE_SPAWN
  (achteraan de enum, replays heel), state.pools {inf,cav,art} (3x comp per
  type of expliciet), blinde SPAWN met commit-gate (cap 3, eigen achterste
  rij, bezet vak geweigerd BIJ REVEAL met pool-behoud, auto-commit bij lege
  pool), win op bord+pool, view-redactie D12 (vijand-pool = "?", inzet geheim
  tot reveal, enemy_has_spawned-boolean), cycle_admin-ledger-event in RESET.
  Vangst onderweg: campaign-subdicts verloren int-typen na JSON-roundtrip
  (Zobrist-hash divergeerde) -> _diep_int-normalisatie in RulesConfig.
  Golden #13 "spawn_geblokkeerd" (move -> cycluseinde -> RESET -> blinde
  commits -> reveal met weigering); alle goldens geregenereerd (formaat).
  CHECKS: 1067 asserts groen (SpawnTests nieuw, 14 tests) - simcheck 5/5 -
  play - vosview - fuzz 150 schoon - bench 6.8/s. Volgende: F2.3 (BET_CP).

- **F2.1 AFGEROND (24 juli) — v4.2-economie definitief.** Ontwerpsessie met
  Max via de beslisagenda (docs/F2.1-beslisagenda.md, gebouwd door een
  multi-agent-werkgroep: 3 bron-lezers + synthese + adversariele toets die
  D13/D14 nog aan het net trok). Alle 14 punten besloten; docs/spelregels-
  v4.2.md Deel B is nu de definitieve spec (0x "TE BEVESTIGEN", elke regel
  een campaign.*-knop). Kern: CP = +1 kaartbudget bij definieren (1 per
  kaart, geen plafond, verbrand, initiatief loopt vanzelf via de stats);
  pool = 3x comp per type met campagne-afboeking; spawn max 3 vanaf cyclus 2
  ALLEEN op de achterste rij (Max' hoekfort-rem); CANNON_ACT = ROLL+SHOOT
  (RETREAT geschrapt: "geen spelelement"); vijandelijke pool/CP VERBORGEN
  (fog voorop; battlereports/teamgenoten = F3-eis); klok-campagnestandaard
  180/5/60. Nachtrun-data (61.560 partijen, fuzz 10k schoon): Muis 41.7
  (+16.7 door de gen-2-adoptie!), maar Wolf zakte naar 16.7 — volgende
  trainingsronde is aan Max (paneel-knop). Meetkwaliteit: seeded tie-break-
  loting in L2 (vlag, default uit; matrix_l2.json aan) — zelfde seeds
  identiek, andere seeds echte spreiding. Volgende: F2.2 (pools/CYCLE_SPAWN/
  SPAWN in de reducer).

- **F1.6 AFGEROND (23 juli) — vervolg + slot:** trainer-gate was het echte
  blok: de absolute adoptie-eis (>=8/12 = 67% winrate) is voor een zwakke
  factie onhaalbaar — 2x een run met 0 adopties, ook met betere kandidaten.
  Nu RELATIEF: de huidige kampioen speelt dezelfde deterministische
  verificatiereeks als referentie (gecacht per factie, vervalt bij adoptie);
  adoptie = totaal >= referentie+2 en per helft geen achteruitgang >1.
  BEWIJS: proefrun gen 2 -> GEADOPTEERD (8/12 vs referentie 5/12). L2-matrix
  na de gewichten-wissel (3348 partijen, Max' run): Muis 16.7 -> 25.0,
  Leeuw 58.3 -> 50.0 (verliest nu van Muis), rest exact gelijk — CHECK
  gehaald: alle doctrines binnen 25-75 (Muis/Wolf op de vloer, Krokodil op
  het plafond: verdere training gewenst, geen blocker). Convergentiecheck
  live gerapporteerd; geen regels gewijzigd dus geen golden-bumps.
  MEETLES: L2 is deterministisch per matchup (elke cel 93/0/0) — winrates
  verspringen per 8.3%; herhalingen voegen niets toe. TODO later: vleugje
  loting in L2-gelijkwaardige zetten. Dashboard-trend vergelijkt nu alleen
  runs met dezelfde agents+matchups. Paneel (paneel.ps1 + "FogOfWar
  Paneel.bat"): alle runs met een knop, VOLLE NACHTRUN-knop (8u),
  fuzz schaalt mee met de duur; machine blijkt 32 threads (31 procs).

  Oorspronkelijke F1.6-notities: Meetfase klaar: L2-baseline
  864 partijen (Krokodil 75% / Varken 66.7 / Leeuw 58.3 / Beer 58.3 / Wolf 25
  / Muis 16.7 — drie buiten het 25-75-werkdoel). L1-sweeps (identieke seeds):
  statue_threshold=2 VERWORPEN (standbeeld-kills 18k->0 maar 69% van de
  partijen strandt in tiebreak, cycli x2.9 — de knop doodt de dynamiek);
  havencum en retal-zwaar op L1 onmeetbaar (L1 raakt die mechanieken amper)
  -> L2-nachtdata. REGELBESLUIT: geen knop gedraaid, 4.1.10-hr blijft — de
  onbalans is een gewichten-probleem (L1 bewijst: 18/4/0-comp wint 91.7% met
  simpel haven-gedrag). Hertraining: doortrainen vanaf het oude Muis-profiel
  is een doodlopend dal (11 gen, 0 adopties, kandidaten 0/6 vanaf gen 1;
  convergentiecheck live bewezen: "50% — plateau" op identieke kampioenen).
  Profiel-A/B op de gerichte Muis-L2-matrix (160 partijen/variant, vaste
  seeds): oud getraind 10.0% == haven-rusher x10 10.0% (byte-identiek spel:
  L2-Muis komt nooit toe aan de haven-term) < KROKODIL-VERHOUDINGEN 20.0%
  (wint ineens 50% van Leeuw; er is weer een gradient). Besluit: f1 =
  krokodil-verhoudingen als startpunt; avondtraining 420 min (seed 20260724)
  eindigt ~01:30, nachtrun (02:00, nu op matrix_l2) meet het resultaat.
  Nachtjob-default naar L2 gezet. Nog open voor F1.6-CHECK: L2-matrix na
  training binnen 25-75 voor alle doctrines; havencum/retal-besluit op
  L2-data; Krokodil-dominantie beoordelen.

- **F1.5 — dashboard + nachtjob.** `tools/dashboard/build_dashboard.py`
  (stdlib-only) leest results/**/games.jsonl, groepeert per run-map en bouwt
  results/dashboard.html: winrate-matrix-heatmap (gerichte paren), totaal-
  winrate per doctrine met geel-markering buiten 25-75% en trend-pp t.o.v. de
  vorige run, plus de par.8.2-metrieken (winmethode/remise-triggers, cycli/
  acties/zobrist-herhalingen, illegale keuzes, kanonnen-zonder-schot-%,
  standbeeld-kills per kaartprofiel, schade-per-actie en overkill-per-kill per
  doctrine, winnende havenvakken, koppel-matrix) en een runs-historie.
  `arena_nacht.ps1`: git pull --ff-only -> fuzz (10k) -> tijdgebonden arena-
  batches (procs = cores-2, verse seeds per nacht via epoch-offset, alles in
  run_meta = reproduceerbaar) -> merge naar 1 games.jsonl -> dashboard ->
  summary.txt + nacht.log. BESLUIT MAX (23 juli): NIET automatisch plannen op
  de lokale machine — de nachtjob wordt altijd handmatig gestart
  (`.\arena_nacht.ps1`, evt. met -DuurMinuten). De Taakplanner-taak is weer
  verwijderd; tools/register_nachtjob.ps1 blijft beschikbaar voor wie ooit
  wél wil plannen (en voor de VPS-cron in F4; geen n8n, werkafspraak B5). Valkuilen gefixt:
  $procs botste case-insensitief met param [int]$Procs; PS 5.1 Set-Content
  schrijft utf-8-BOM (dashboard leest utf-8-sig); dubbele glob telde elke
  jsonl 2x. CHECK: smoke-run -Kort end-to-end groen (720 partijen, 6.6
  match/s over 4 procs, fuzz 100 schoon, dashboard met echte data in de
  browser bekeken). EERSTE DATA (L1, 4.1.10-hr): Muis-comp 18/4/0 wint 91.7%
  totaal en verliest GEEN enkele gerichte matchup; P1-kant wint bijna alles
  behalve tegen Muis; 720/720 partijen eindigen via haven. F1.6-vragen dus:
  Muis-dominantie (ipv het oude 8.3%-kapot), starter-voordeel, haven-race.

Volgende stap: **F1.4 — fuzz & invarianten als nachtvangnet**. (agent-interface op views, L0-L3, doorvoer
>=5 matches/s/core, metrics per bouwplan-par. 8.2, fuzz, dashboard, en de
eerste balanspatch op data — Muis-hertraining met de nieuwe cavalerie).

---

## ⏵ STAND VAN ZAKEN MODELLEN + GORE-SYSTEEM (bijgewerkt 6 juli 2026, avond)

**De Muis-infanterie is 100% af en het complete gore/effect-systeem staat.**
Pipeline bewezen end-to-end: Meshy/Tripo (Laag Poly ~1k) → Mixamo auto-rig →
Blender (delen LOS houden!) → glb → auto-fit → Model-tuner. Alles hieronder werkt
automatisch voor elk volgend model dat de conventies volgt.

**Model-conventies (BELANGRIJK voor factie 2+):**
- Levend model: `assets/models/<factie>/<type>_<archetype>.glb` met losse
  geskinnede meshes `hat`/`armL`/`armR`/`legL`/`legR`/`tail`/`body` aan één
  skelet (in Blender NIET joinen; P → Selection om te splitsen).
- Gibs: `<model>_gibs.glb` met delen `Torso/ArmL/ArmR/LegL/LegR/Hat` (bebloede
  stompjes door Max geschilderd).
- Clips mogen `fire`/`death1`/`death2` heten (ANIM_ALIASES vertaalt naar
  attack/die); varianten idle1-3/walk1-3 worden random gekozen met desync.
- Verse Blender-export? Walk-clips hebben vaak weer root-motion → één keer
  `tools/blender_merge_character.py --base <glb>` draaien (detrend), of In
  Place-varianten in het blend-bestand zetten. `fix_mouse_clips.bat` is er
  als vangnet maar meestal niet meer nodig (clips zitten in Max' blend).

**Auto-fit (definitief opgelost 6 juli):** meet het skelet in het EERSTE
IDLE-FRAME (niet de A-rustpose — dat was de oorzaak van zwevende/verschoven
modellen), centreert horizontaal op het ZWAARTEPUNT van de lijf-botten
(staart telt nergens mee), zolen op de grond via voet-botten. Handmatige
x/z-tuning is model-ruimte (draait mee met facing). Tuner heeft debug-
tegelrand + middenkruis + meetcijfers in de infobalk; capture-modus
`-- align` print per pion de delta t.o.v. zijn tegel + top-down screenshot.
Tuner-camera = bordcamera (orthograaf, zelfde hoek): WYSIWYG.

**Dood-systeem (allemaal tunebaar via de Model-tuner, opslag in
`assets/models/effects_tuning.json`):**
- **Kanon (strength ≥1.2)**: lijf klapt uiteen in gibs, alles blast WEG van
  het schot (dir dominant), per-deel ruis op kracht/hangtijd, delen landen
  plat (dunste as omhoog), bloedmist-billboards (Max' `blood_mist*.png`) +
  druppel-fontein met blast-bias; druppels laten splat-vlekken achter; elk
  brokstuk krijgt EEN pool-plas exact onder zijn landingsplek (romp groot,
  hoedje klein).
- **Musket-schot**: death-animatie (random death1/death2) + borst-fontein
  die 1-3x pompt (stoten volgen de zakkende torso, elk een eigen splat) +
  OF hoedje eraf OF één ledemaat (echte mesh verdwijnt, gib vliegt, straal
  uit het stomp-gat) + lijkpoel onder de TORSO (per death-clip instelbaar:
  wacht/groei/maat/torso-afstand via de "Dood-poel"-rij + test-knop).
- **Melee**: zelfde maar alleen ledemaat (nooit het hoedje) — kind-parameter
  loopt van game.gd ("shot"/"melee") door play_death.
- **Bloedtextures**: `assets/textures/blood/` — `blood_pool*` (plassen),
  `splat*` (inslagen), `blood_mist*` (mist-billboards); automatisch opgepikt,
  prefix bepaalt gebruik, map leeg = procedurele fallback.
- Alles blijft liggen (groep `battlefield_debris`) tot de nieuwe cyclus;
  tuner laat het ook liggen tot de volgende test.
- Tuner-knoppen (stap 0.01, max 10): hoed-kracht/-hangtijd/-kans,
  ledemaat-kans/-kracht/-hangtijd, gib-worpkracht, gib-tolling,
  wond-druppels, spuit-straal, kanon-mist, druppel-duur/-maat/-vlekkans,
  vlek-wacht/-groei, gib-poel-wacht/-groei, plas-wacht/-groei/-maat,
  lijkpoel-fallback. Drie gib-testknoppen: kanon/musket/melee.

**VOLGENDE STAPPEN:**
1. **Team-textures**: per model `<basis>_team1.png`/`_team2.png` (rood/blauw
   leger) — Max levert recolors, Claude bouwt loader + tuner-preview.
   Urgent-ish: sokkel is weg, dus mirror-matches missen team-onderscheid.
2. **Muis-archetypes** (spd/hp/atk) en dan de overige facties door de
   pipeline (prompts klaar in MODEL-WISHLIST §3).
3. **Cavalerie = BIG BRO** (besluiten 6 juli, zie MODEL-WISHLIST):
   varken/everzwijn (MENS-slot), muis/dikke rat (comp 22/0/0 → moet cav
   krijgen, bv. 18/4/0 + arena-hermeting), cheetah/leeuw, wasbeer/grizzly,
   vos/dire wolf (WOLF-slot), hagedis/krokodil (VOS-slot). Big bros
   tweebenig, Mixamo melee-clipset (Idle/Walking/Melee Attack/Death).
4. **Aim/anticipation**: "Rifle Down To Aim" als `aim`-clip + projectiel/knal
   ~0.2s vertragen tot het vuur-frame.
5. Open: arena-run Muis-balans, trainer-nachtrun v2, online-playtest Fase 0,
   resterende sounds (place_undo, timer_timeout, wolf_step, muziek-menu),
   cavalerie-audio per familie (horse_* vervangen).

---

## 1. Wat is dit

2-speler tactisch **3D**-bordspel, **Godot 4.7** (Forward+, Jolt Physics, D3D12),
portrait 1080×1920. Je speelt (rood = speler 1) tegen een AI (blauw = speler 2).

- **Spelregels: `spelregels-v4.1.md` is de geldende regelset** (eenheidstypes Infanterie/
  Cavalerie/Artillerie, vuurlijnen, terugslag, 6 doctrines, vrije opstelling, initiatief-bod).
  `game_description.md` (v1) is het basisdocument waarop v4.1 voortbouwt.
  **De engine implementeert v4.1 volledig** (zie §2b); resterende UI-gaten in §9.
- Opgeruimd (juli 2026): `GAME_LOGIC_OVERVIEW.md` (oude 2D/server-implementatie) is
  verwijderd; de `README.md` is herschreven naar de huidige 3D-realiteit.
- De volledige, geteste engine + AI is geport uit het oude project
  `C:\Users\maxni\FOGOFWAR GODOT` (dat was 2D). Hier bouwen we de 3D-presentatie erop.

## 2. Huidige status — SPEELBAAR

Volledige mens-vs-AI loop werkt end-to-end:

1. **Difficulty-menu** bij start: Easy / Medium / Hard → **doctrine-keuze** (6 doctrines;
   de AI kiest blind willekeurig) → **opstelling** (standaard-opstelling bevestigen).
2. **Definieer** je kaarten via de waaier (aantal × budget volgt je doctrine, zie §5).
3. **Onthulling**: scherm toont bod-percentages + aanval/speed en wie begint
   (deterministisch — geen RPS meer).
4. **Koppelen** (interactief): tik een kaart onderaan → je pionnen lichten op → tik een pion.
   AI koppelt automatisch op zijn beurt (staartkoppelen bij ongelijke aantallen).
5. Herhaalt 3 rondes.
6. **Actiefase**: pion selecteren → groen = bewegen, rood = melee/charge, oranje = schot.
   Wolf-doctrine: na melee cyaan vakken = gratis stap (rechtermuis = overslaan). AI reageert.
7. **Win** → eindscherm met "Nieuw spel".

Engine bewaakt alle regels. **364 test-asserts groen** (`res://tests/TestScene.tscn`).

## 2b. Regels v4.1 — GEÏMPLEMENTEERD (engine + AI + UI)

De volledige v4.1-regelset zit in de engine (`scripts/core/`):

- **Eenheidstypes** op Pawn (`unit_type`): Infanterie / Cavalerie / Artillerie; letter op de
  pion (`PawnView.set_unit_type`) + andere blokvorm (cavalerie hoog, artillerie plat/breed).
- **Opmaakbare stamina (HUISREGEL, wijkt af van v4.1 §3.3/§4.4)**: stamina is de
  actievoorraad van de cyclus — stap = 1, melee/schot = 1, charge = stappen + 1
  (`Pawn.spend_stamina`). Een pion mag meerdere beurten handelen tot de voorraad op is.
  Terugslag en de Wolf-stap zijn gratis.
- **Acties per type** (`Rules`): infanterie beweeg/melee/schot (afstand exact 2, tussenvak
  leeg, schade Attack−1, `get_valid_shot_targets`); cavalerie charge (`apply_charge`,
  bewegen + optionele melee, minstens 1 stap óf aanval, kosten stappen+1) en **springt
  ALTIJD over eigen pionnen heen** (HUISREGEL; gepasseerde vakken tellen als stappen);
  artillerie **1 ding per beurt** (1 stap óf 1 schot) met **vaste dracht 6** (HUISREGEL,
  `Constants.ARTILLERY_RANGE`; v4.1 zei dracht = Speed), volle Attack, dode zone op 1.
  Artillerie-Speed is dus puur het aantal acties per cyclus.
- **Factie-perks (HUISREGELS, juli 2026)**: Leeuw-kanonnen dracht 7 (`art_range_bonus`);
  Vos-cavalerie +1 Speed bij koppeling (`cav_speed_bonus`); Wolf-cavalerie springt óók
  over VIJANDELIJKE infanterie (`cav_jump_infantry`; niet over vijandelijke cav/art);
  Muis +1 Speed op ELKE pion bij koppeling (`speed_bonus`, doctrine-breed buiten het
  budget) — anders kruipt de budget-5-zwerm te traag over het bord (min stamina 2, typisch 3).
  Teksten (pro/con per doctrine) staan in `Constants.DOCTRINE_DATA`.
- **Terugslag** (`_resolve_melee`, HUISREGEL type-afhankelijk): een ACTIEVE verdediger die
  een melee overleeft slaat terug op de aanvaller — infanterie −1, cavalerie −2,
  artillerie −0 (`Constants.RETALIATION_DAMAGE`). Geen terugslag bij dood, tegen
  beschietingen, of van inactieve pionnen.
- **Vuurregels**: vuur raakt óók inactieve pionnen; elke tussenliggende pion blokkeert;
  vuur wint geen terrein (geen forced move); melee-eliminatie → verplichte verplaatsing.
- **Vrije opstelling**: `Phase.Type.PLACEMENT` + `submit_placement`; `default_placement()`
  per doctrine (artillerie vóór op flank/centrum, cavalerie achter). RPS is weg —
  initiatief is deterministisch: **bod-percentage** (`Rules.compute_bid`, §4.3-B) →
  Speed-bod → C1/R1: P1, anders vorige initiatiefhouder.
- **Doctrines** (`Constants.DOCTRINE_DATA`, per speler in `state.doctrines`): Mens 3×7,
  Muis 4×5 (22 inf, doorbewegen door eigen pionnen), Leeuw 2×9 (18 pionnen 6/10/2),
  Beer (+1 HP bij koppeling buiten budget, Speed max 3 bij definitie), Wolf (gratis stap
  na elke melee; `pending_wolf_step_pawn` + `submit_wolf_step`/`skip_wolf_step`),
  Vos (gedekt koppelen: `pawn.card_revealed=false` tot schade geven/krijgen).
- **Koppelen**: staartkoppelen bij ongelijke kaartaantallen; kaarten zonder geldige pion
  vervallen; initiatiefhouder zonder koppelwerk → beurt direct naar de ander (bugfix).
- **AI**: `enumerate_actions` met schoten + charges, `choose_placement`, `choose_wolf_step`,
  budget-bewuste `generate_cards` (respecteert doctrine-budget + Beer-speedcap).
- **UI/driver**: doctrine-keuzemenu (AI kiest blind willekeurig), opstelling-overlay,
  kaart-UI met dynamisch budget/aantal (`CardHand.configure`), targeting: rood = melee/
  charge, oranje = schot, groen = bewegen; wolf-stap = cyaan vakken klikken (rechts =
  overslaan); bod als percentage in het onthul-scherm.
- **Sims per doctrine**: `capture.tscn -- sim <ai1> <ai2> [doctrine1] [doctrine2]`
  (bv. `sim medium hard muis leeuw`). Alle 6 doctrines spelen uit met winnaars via
  beide wincondities.

## 3. Architectuur (3 lagen)

```
Laag 3  Driver          scripts/game/game.gd  — koppelt GameSession aan het 3D-bord,
                        input, AI-beurten, overlays, animaties, indicatoren.
Laag 2  Presentatie     Board.tscn (bord+camera), pawn_view, card_hand/card_view, overlay.
Laag 1  Core (headless) scripts/core/  — Phase, Card, Pawn, GameState, Rules, GameSession.
        AI              scripts/ai/    — AIController + AIEasy/AIMedium/AIHard.
```

- **Autoloads** (project.godot): `Constants` (`scripts/core/constants.gd`) en `GameSession`.
- `Constants` is gemerged: engine-constanten + compat-enums (`Team`, `UiPhase`) +
  `STAT_TOTAL`/`MIN_STAT` voor de kaart-UI.
- Engine-`Card` (id/owner) ≠ UI-`CardData` (edit-model in de waaier). Ze bestaan naast elkaar;
  bij `submit_define_cards` geeft de UI dicts `{hp,stamina,attack}` door.

## 4. Belangrijke bestanden

| Bestand | Rol |
|---|---|
| `scripts/game/game.gd` | **Driver** — alle glue: flow, input, AI, overlays, animatie, blokjes |
| `Board.tscn` | Volledig 11×11 bord (node "Board", incl. Camera3D + light + havens) |
| `scenes/game/pawn_view.tscn/.gd` | Pion: speelstuk/model + ring + facing. `@export model_scene` = karaktermodel (.glb met AnimationPlayer); anders het type-speelstuk. `play_walk/attack/idle/die`, `face_dir` |
| `scenes/game/pieces/*.tscn` | **Speelstukken per type** (CSG): infanterist (romp+geweer), cavalerie (paardenkop), artillerie (kanon+wielen). Delen in groep `team_tint` krijgen de teamkleur + status (select/hover/dim) via `PawnView._update_material`; letter I/C/A op het Label3D erboven |
| `scenes/ui/card_hand.tscn/.gd` | Waaier: definieer + interactief koppelen |
| `scenes/ui/card_view.tscn/.gd` | Losse kaart: slimme +/− stat-herverdeling, tap-select |
| `scenes/ui/overlay.tscn/.gd` | Herbruikbaar modaal keuzescherm (difficulty/doctrine/reveal/eind) |
| `scripts/ui/instructions.gd` | **Speluitleg-tabscherm** (simpele taal): Het spel / Beurten / Eenheden / Vechten / Facties (facties-tab uit `DOCTRINE_DATA` gegenereerd). Altijd bereikbaar via de "?"-knop rechtsboven (`game._build_help_button`; pauzeert de fase-timer) en via de Speluitleg-knoppen in de menu's |
| `scripts/core/*` | Headless engine (geport, getest) |
| `scripts/ai/*` | AIController + Easy/Medium/Hard |
| `tests/*` | Testrunner + Rules/GameSession/AI/Card tests (156) |
| `tools/capture.*` | Screenshot/test-harness via CLI (zie §7) |

## 5. Gameplay-details & beslissingen

- **Slimme kaarten**: starten op 3/2/2 (7 al verdeeld). `+stat` haalt 1 weg bij de grootste
  andere stat (>1); `−stat` geeft 1 aan de kleinste andere. Totaal blijft altijd 7, elke
  stat 1..5. ("Punten over"-label verborgen; Bevestigen altijd geldig.)
- **Melee met terugslag (v4.1)**: de verdediger krijgt de volle Attack; overleeft een
  ACTIEVE INFANTERIST de melee, dan krijgt de aanvaller exact 1 schade terug
  (`Rules._resolve_melee`, test `test_retaliation_when_active_infantry_survives`).
  Bij eliminatie moet de aanvaller direct naar het vrijgekomen vak (alleen melee).
- **Stamina is opmaakbaar** (huisregel): een pion kan in meerdere beurten handelen —
  bv. 2 stappen lopen, later nog eens slaan — tot de stamina op is. Een aanval kost 1.
  De cyclus eindigt zodra niemand nog stamina + een geldige actie heeft.
- **Opstelling**: rood (P1) op rijen z=9,10; blauw (P2) op z=0,1. Havens: P1-doel z=0, P2-doel z=10.
- **Koppelen v-model**: één kaart per beurt, initiatief-winnaar begint, beurten wisselen.
  Auto-koppelaar (AI + fallback) kiest pion met "ademruimte" (niet ingeklemd).
- **Indicatoren boven pion** (3×5 blokjes, projectie via `camera.unproject_position`):
  rij 0 = HP groen, rij 1 = stamina lichtblauw, rij 2 = attack oranje, leeg = zwart.
  Blokjes staan áchter de kaarten (z-index) en dicht bij de pion (y+1.55).
- **Gedimde pionnen**: eigen pionnen die tijdens jouw actiebeurt niet kunnen (0 stamina/ingeklemd).
- **Hover-highlight**: pion licht geel op onder de muis (bij koppelen: alleen eigen ongekoppelde).
- **Beweeg-animatie**: pion glijdt (`_animate_move`, tween); `_tweening_pawns` voorkomt dat
  `_refresh_all` de positie overschrijft tijdens de animatie.
- **Pauze** (0.9s) na de laatste koppeling vóór de nieuwe definieer-ronde.
- **Stamina-kosten op tiles**: geselecteerde pion toont op elke groene zet-tile klein de
  stap-/stamina-kosten (`_highlight_move_tiles` met een Label3D per tile = pad-lengte).
- **Koppel-animatie**: pion springt kort omhoog + ring glim-flits (`_animate_link` +
  `PawnView.flash_ring`), voor beide spelers.
- **Treffer-feedback**: minivertraging → witte flits op de geraakte pion
  (`PawnView.flash_hit`) + opstijgend rood schade-label ("-2") dat vervaagt
  (`game._hit_feedback`/`_spawn_damage_float`); bij terugslag krijgt de aanvaller
  even later zijn eigen "-1". Charge-feedback wacht op de aanrij-animatie.
- **Combat feel ("Hit"-fase, Valheim-stijl)** — op het inslagmoment via `_hit_feedback`:
  witte flits (`PawnView.flash_hit`), **stagger/knockback** (`PawnView.stagger`),
  **vonken-/stofexplosie** (`_spawn_sparks`), **screen shake** (`_shake`/`_update_screen_shake`,
  dempt in ~0.2s, schaalt met impact) en **hitstop** (`_hitstop`: `Engine.time_scale`-dip
  met ignore_time_scale-timer). Impact schaalt per type (kanon > infanterieschot > melee;
  kills sterker). **Lichte ragdoll** bij dood (`PawnView.play_death`): omvallen in de
  knockback-richting + wegzinken + self-free; `_dying_views` + `_kill_view` zorgen dat
  `_refresh_all` de stervende pion niet meteen verbergt. Toetsen: **K** = screen shake aan/uit
  (motion sickness), **J** = alle combat-feel aan/uit, **M** = geluid dempen.
  Nog te doen (anticipation-fase): aim→shoot/charge-opbouw-animaties op de modellen
  (`play_attack`-hooks staan klaar).
- **Karaktermodellen per factie + kaart-archetype (juli 2026)**: elke pion toont
  na koppeling een karakter op basis van de dominante kaart-stat
  (`Constants.card_archetype`: spd/hp/atk/mix; 1/5/1 = "dunne schichtige muis").
  `PawnView.set_character(doctrine, type, card)` zoekt
  `assets/models/<factie>/<type>_<archetype>.glb` met fallback-keten archetype →
  `_base` → geometrisch stuk met archetype-silhouet (ARCHETYPE_SCALE: dun/hoog,
  breed, groot). Kale .glb's krijgen automatisch een team-gekleurd sokkeltje
  (groepen zitten niet in glTF); tint-verzameling verbreed naar GeometryInstance3D
  (CSG + MeshInstance3D). Verborgen Vos-koppelingen blijven neutraal voor de
  tegenstander tot onthulling (archetype zou de kaart verraden); eigen pionnen
  tonen hun karakter altijd. Opstellings-preview toont het factie-basismodel.
  Modellen droppen = klaar (geen code): zie **MODEL-WISHLIST.md** (16 basis-modellen
  = prio 1, 64-80 voor de volledige set; eisen: .glb, MAX 1.000 tris (low-poly
  stijl, besluit juli 2026), voeten y=0,
  neus -Z, ~0.9 hoog, optioneel AnimationPlayer idle/walk/attack/die).
- **Model-tuner (juli 2026)**: hoofdmenu → "Model-tuner"
  (`scenes/tools/ModelTuner.tscn`) — per factie/type/archetype schaal- en
  hoogte-sliders naast een referentiestuk, clip-preview-knoppen, OPSLAAN →
  `assets/models/model_tuning.json`. PawnView past die correcties toe bovenop
  de auto-fit (`model_tuning()`/`_tune_key`, sleutel volgt het geladen bestand
  incl. basis-fallback). Screenshot-hook: scene draaien met `-- shot`.
- **Animatie-varianten (juli 2026)**: `_play_variant`/`_variants_of` — clips met
  volgnummer (`idle2`, `walk3`, `die2`) worden willekeurig gekozen per
  afspeelmoment, idle/walk starten op een random punt in de clip (desync: de
  zwerm beweegt nooit synchroon). Muis-basis-glb heeft 9 clips (3 idle, 3 walk,
  attack, 2 death), samengesteld via het headless Blender-merge-script
  (scratchpad `merge_mouse*.py`; herbruikbaar per karakter).
- **Schiet-VFX (prototype)**: `_fire_projectile` — kanonskogel (groot, donker, met
  boogje) vs infanterie-tracer (klein, fel, strak), muzzle flash met OmniLight-puls
  (`_muzzle_flash`) en low-poly rookwolkjes bij loop én inslag (`_spawn_smoke`).
  De treffer-feedback wacht op de projectiel-reistijd. Bekende quirk: een dodelijk
  geraakt doelwit verdwijnt al bij vertrek van het projectiel (refresh), niet bij
  de inslag — acceptabel voor het prototype.
- **Charge-kosten in de UI**: alleen betaalbare charges (stappen + 1 ≤ stamina) worden
  rood gemarkeerd (`_compute_charge_targets`) — anders "blijft het paard staan" (bugfix).
- **Beurt-timer (20s) in ALLE fases** (`PHASE_TIME_LIMIT`, countdown in de HUD-topbalk).
  Bij 0: opstellen → standaard-opstelling (`_cancel_manual_placement`); definiëren →
  auto-bevestigd; koppelen → auto-afgemaakt (`_auto_link_human`); actiefase (mensbeurt) →
  het spel kiest greedy een zet (`_auto_action_human`, AIMedium-motor; pending Wolf-stap
  wordt overgeslagen). Timer stopt tijdens AI-beurten en pauzeert bij de "?"-uitleg.
- **Geen type-letters meer** boven de pionnen — de speelstuk-modellen tonen het type
  (`PawnView.set_unit_type` zet het Label3D leeg).
- **Geluid (SFX)**: autoload `Audio` (`scripts/core/audio_manager.gd`) met een pool van
  AudioStreamPlayers; `Audio.play(categorie, delay)` kiest een willekeurige variant uit
  `sounds/` (categorieën: cannon_fire/air/hit, musket_fire/echo/hit/cock, melee_kill/survive)
  met subtiele pitch-variatie + per-categorie volume. Alle bronbestanden zijn **WAV**
  (mp3's verwijderd — WAV = nul decode-latency + geen encoder-padding, past bij de op
  reistijd getimede inslaggeluiden). Gehaakt in `game._on_action_performed`: schot →
  musket/cannon bij afvuren, echo/whoosh kort erna, inslag-geluid getimed op de
  projectiel-reistijd; melee/charge → kill- vs. overleeft-klap. Haan-spannen
  (`musket_cock`) bij selectie van een infanterist die kan schieten.
  **Beweeggeluid per type** (in `_animate_move`): infanterie = `step` en artillerie =
  `cannon_move` via `play_footsteps` (één klap per gelopen vakje, sample cyclt vanaf
  random start, pitch per volle ronde omhoog); cavalerie = **één** `horse_move`-galopclip
  per beweging (bevat zelf al meerdere hoefslagen). NB: loop-duur schaalt met afstand
  (0.13s/vak, max 0.45s). **Selectie**: `musket_cock` (infanterie die kan schieten) /
  `horse_select` (cavalerie), `inf_select` (infanterie zonder schot), `cannon_select`
  (artillerie); `deselect` bij loslaten. Kanonschot krijgt ook `cannon_fuse` (lont-sis)
  bovenop `cannon_fire`. **Sterven** (`_death_sound`): `inf_die` (infanterie) /
  `horse_die` (cavalerie) / `cannon_die` (artillerie), ook bij dood door terugslag.
  **Overleven**: `blood_splash` bij een niet-dodelijke treffer op een levend stuk
  (inf/cav, niet artillerie). **Terugslag door een paard** (`_retaliation_sound`):
  `retaliation_horse` als de terugslaande verdediger cavalerie is (hoeven bovenop de klap).
  **UI**: `ui_click` (3 var) op knoppen/koppel-tap, `ui_hover` op overlay-knoppen,
  `ui_open` bij openen van overlay/uitleg, `ui_back` bij sluiten uitleg, `ui_toggle`
  bij tab-wissel, `ui_error` bij een pion die niet kan handelen. **Kaart-UI**:
  `card_confirm` bij bevestigen, `card_stat_up`/`card_stat_down` op de +/− stat-knoppen
  (`card_view._adjust_stat`). **Flow**: `reveal` (trommelroffel) + `initiative` (bugel, 0.6s
  later) bij de onthulling (`_on_cards_revealed`), `phase_change` bij elke nieuwe
  definitie-ronde (`_on_phase_changed`), `cycle_start` bij een nieuwe cyclus (vanaf 2,
  `_on_cycle_started`). **Opstellen**: `place_pawn`. **Beurt**: `your_turn` (uit).
  **Koppelen**: `card_deal` (uitdelen), `card_select` (tik), `link_snap` (vastklikken).
  **Charge**: `charge_yell`. **Timer**: `timer_tick` per seconde in de laatste 5 sec;
  de laatste 3 sec dezelfde tik op dubbel tempo + pitch 1.12 (`_tick_accum`) —
  `timer_warning` vervallen (bestand blijft). **Uitkomst**: `haven_score` (pion in
  haven, nog niet gewonnen), `win_fanfare`/`lose_sting` bij `_on_game_over`.
  `pawn_block` staat klaar in de bank maar heeft nog geen event.
  **Muziek & ambience** (`music/`, QOA-import 34→6,7 MB per track): aparte loop-lagen
  in de Audio-autoload (`play_music`/`play_ambient`/`stop_music`, `MUSIC_BANK`, lazy
  load; track klaar → willekeurige volgende variant). `ambient_field` (3 var, incl.
  regen, -20 dB) start bij `_ready` en loopt onder menu én spel; `music_battle`
  (2 var, -16 dB) start bij `_start_match` en stopt bij game-over zodat de sting
  ruimte krijgt. Mute (M) pauzeert ook de muzieklagen (`set_enabled` → `stream_paused`).
  De verlanglijst met ElevenLabs-prompts staat in `SOUND-WISHLIST.md`.
  Draai `--import` na een verse checkout.
- **Kijkrichting (facing)**: elke pion heeft een facing (Y-rotatie) + zichtbaar wit "neusje"
  vooraan (`PawnView._build_front_marker` + `face_dir(dir)`, front = -Z). Start: rood kijkt naar
  z=0, blauw naar z=10 (naar de vijand). Draait naar de looprichting bij bewegen en naar het doel
  bij aanvallen. Bedoeld als basis voor het latere karaktermodel (blik-/loop-animatie).

## 6. Opgeloste bugs / valkuilen (niet opnieuw intrappen)

- **Picking-bug (Jolt)**: pion-collider was `StaticBody3D`; Jolt updatet static collision NIET
  bij verplaatsen → raycast vond verplaatste pion niet → "kan niet opnieuw selecteren".
  **Definitieve fix**: geen physics meer voor picking. `_raycast_pawn` en `_pick_move_tile`
  projecteren wereldposities naar het scherm en pakken de dichtstbijzijnde (pion 44px, tegel 52px).
- **Overlappende waaier-kaarten** maakten +/− onklikbaar (buurkaart ving de klik) → genoeg
  spreiding + kaart springt naar voren op hover.
- **`_pawns_root.reparent(_board)`** met keep_global_transform gaf 5-vakjes offset → gebruik
  `reparent(_board, false)`.
- **Pion-positie** = tile-midden op hele coördinaten (`tile_position`), niet `gx+0.5`.
- **Autoload-enum als type**: `var x: Constants.Team` faalt (autoload is instance) → gebruik `int`.
- **`class_name` niet in CLI-cache** bij verse run → `var _overlay` untyped houden.

## 7. Runnen, testen, screenshots

- **Godot exe**: `C:\Users\maxni\Downloads\Godot_v4.7-stable_win64.exe\Godot_v4.7-stable_win64.exe`
  (de .exe zit ín een gelijknamige map). GODOT_PATH user-env staat hierop.
- **Spelen**: open project in Godot, F5 (main scene = `scenes/game/game.tscn`).
- **Tests**: `res://tests/TestScene.tscn` (F6 in editor, of headless CLI). Nu 156 groen.
- **CLI-workflow** (geen live editor nodig): `tools/capture.tscn` instancet game.tscn en
  saved een viewport-PNG. Run: `& $godot --path <proj> res://tools/capture.tscn -- <modus>`.
  Modi: (geen)=menu, `define`, `reveal`, `rps`, `link`, `play` (auto tot actiefase),
  `carddist` (test stat-herverdeling), `reselect`/`picktest` (picking na zet),
  `benchhard` (AI-timing), `click`. Output: `_shot*.png` in de projectroot.

## 8. AI

- Interface: `generate_cards`, `choose_placement`, `choose_link`, `choose_action`.
- **Gedeelde zero-sum evaluatie** (`AIController.evaluate(state, me)`): pionnen-in-haven ×6000,
  niet-lineaire nabijheid van de 2 dichtstbijzijnde pionnen naar BEIDE havens (= aanval +
  verdediging), bewaking van winvakjes ±320, materiaal ±32, HP ±3. `AIController` biedt ook
  `enumerate_actions` / `simulate` / `best_greedy_action`.
- **Easy**: greedy op eval, maar kiest willekeurig uit de top-3 (maakt fouten).
- **Medium**: 1-ply greedy op de eval.
- **Hard**: negamax diepte 3 + beam (14/8) op de zero-sum eval. ~400ms/zet.
- **Ultra (god mode)**: `AIUltra.gd` — iterative-deepening negamax tot diepte 5,
  beam 20/10, denktijd-budget `time_budget_ms` (2200ms) per zet; move-ordering
  hergebruikt de beste zet van de vorige diepte. Bench: `capture.tscn -- benchultra`.
  Alle niveaus delen dezelfde (geleerde) gewichten — het verschil is de zoekdiepte.
- Slimme kaarten + koppeling gedeeld: renner/slager/anker, koppel hoogste stamina op de pion
  het dichtst bij de eigen doelhaven.
- **Meten**: `capture.tscn -- sim <p1> <p2>` (AI vs AI, puur engine). `-- benchhard` voor timing.
- Historie: was "dom in alle standen" (mens won ~3 zetten). Bugs: AI verdedigde de verkeerde
  haven; Hard's negamax evalueerde vanuit vaste i.p.v. side-to-move perspectief. Nu: Hard>Medium>Easy,
  geen triviale haven-rush meer.
- **Instelbare gewichten**: `AIController.weights` (Dictionary, `default_weights()`), gebruikt in
  `evaluate`. Kunnen opgeslagen/geladen (`save_weights`/`load_weights` → `user://ai_weights.json`).
  Het spel laadt geleerde gewichten in `_setup_ai`.

## 8b. AI Trainer (self-play dashboard)

`scenes/training/Trainer.tscn` (via het difficulty-menu "AI Trainer bekijken", of F6). Draait
hill-climbing self-play en toont het live:
- **4 potjes tegelijk** (`MatchRunner` = losse GameSession-engine per potje, stap voor stap;
  `MiniBoard` tekent elke GameState top-down).
- **Spreektaal-narratie** (RichTextLabel): welke gewicht-aanpassing geprobeerd wordt en of de
  uitdager wint → nieuwe kampioen.
- **Stats** (generatie, verbeteringen, kampioen-gewichten) + snelheidsregelaar (stappen/frame) +
  pauze + "Bewaar kampioen".
- **Auto-opslaan**: bij elke kampioen-verbetering schrijft 'ie naar **`res://data/ai_weights.json`**
  (in het project → commit-baar + met de hand aan te passen). Het spel laadt dit in `_setup_ai`
  (gemerged over `default_weights()`, dus robuust). Verwijder het bestand = terug naar de defaults.
- Patstellingen eindigen na 2500 stappen met een materiaal/haven-tiebreak (`MatchRunner._tiebreak`)
  zodat de trainer signaal krijgt en sneller verbetert.
- Training gebruikt Medium (snel); geleerde gewichten helpen ook Hard (gedeelde eval).
- **Pool van oude kampioenen** (`_pool`, incl. baseline): de uitdager speelt tegen een mix →
  geen overfit op één stijl. `GAMES_PER_GEN=8` (balans snelheid/betrouwbaarheid; 4 borden = steekproef).
  Adoptie alleen bij **marge** `ADOPT_MARGIN=2` (uitdager ≥2 potjes verschil → geen geluk).
- **Tiebreak** (`MatchRunner._tiebreak`): materiaal → haven → haven-nabijheid, zodat patstellingen
  bijna nooit gelijk eindigen (anders geen leersignaal).
- **Kracht-grafiek** (`TrainGraph`): kampioen vs baseline-gewichten (gestapelde eval-batch,
  `_start_eval`/`_finish_eval`) → stijgende lijn boven 50% = echt sterker geworden.
- **Balansmeting opgeslagen (juli 2026)**: `arena.bat` (`capture.tscn -- arena [potjes]
  [level]`) speelt alle 36 doctrine-richtingen parallel en schrijft een winrate-matrix
  "wie wint tegen wie" + ranglijst naar `data/arena_results.txt` (MatchRunner.max_steps=600
  voor snelle metingen). De headless trainer schrijft per factie de winrate tegen elke
  tegenstander naar `data/matchup_<factie>.txt`. Zo kun je na een run meten en bijstellen.
- **Nachtrun 8u × 6 processen (juli 2026) — balansbeeld uit `data/matchup_*.txt`**:
  Leeuw dominant (90-99% tegen alles, 61% vs Beer), Vos sterk all-round (127 adopties
  in 151 gens), Beer sterk, Wolf middenmoot (~25% tegen de top-3), Mens zwak,
  **Muis kapot: 3-14% tegen alles, 1 adoptie in 80 gens** — ondanks de +1 Speed-perk.
  Kanttekening bij de getrainde gewichten: Leeuw/Beer/Vos hebben na 90+ adopties
  gedegenereerde grootte-ordes (bv. Leeuw `hp`=112k vs `haven`=63; Beer `haven`=1.2M,
  `cav_value`=846k) — multiplicatieve mutatie + hoge adoptiegraad laat de schaal
  exploderen. De eval is relatief dus het "werkt", maar de onderlinge ratio's zijn
  extreem gedrift. **→ Opgelost in trainer v2** (zelfde dag): (1) schaal-anker
  `AIController.renormalize_weights()` na elke recombinatie én bij het laden
  (gedrag-neutraal, eval is lineair); (2) dubbele verify-gate — 2×games, helft vs
  kampioen, helft vs vaste baseline, marge op totaal én geen verlies per helft
  (oude gate liet ~34% ruis door); (3) gepaarde vergelijking — alle kandidaten spelen
  hetzelfde tegenstander-schema met gebalanceerde facties; (4) sigma-cap 0.35 +
  stap-limiet 900 per trainingspotje. Zie AI_TRAINING_PLAN.md "Robuustheid v2".
- **Facties-curriculum + per-factie-profielen (juli 2026)**: de kampioen is een PROFIEL —
  per doctrine een eigen set van 31 gewichten: evaluatie (15) + opstelling (6:
  `art/cav/inf_front/center`, via `choose_placement`) + type-bewust koppelen (10:
  `aff_<type>_<stat>` + `link_advance`). Elke generatie muteert één factie; de uitdager
  speelt die factie (signaal!), de tegenstander krijgt een willekeurige factie. De
  kracht-grafiek meet op een vaste rotatie van 4 matchups. Opslag:
  `AIController.save_profile`/`load_profile` → `data/ai_weights.json` (per-doctrine;
  oud plat formaat wordt herkend). Het spel laadt de set van de AI-doctrine (`_setup_ai`).
  Mini-borden tonen types: ● soldaat, ▲ paard (punt naar de vijand), ▮ kanon + legenda.
- **"Train de AI"-knop = `train_ai.bat`** (projectroot): dubbelklik = 60 min headless
  CMA-lite-training zonder dashboard (`train_ai_nacht.bat` = 8 uur). Ctrl+C mag altijd —
  elke adoptie is al opgeslagen. CLI: `capture.tscn -- train [minuten] [pop] [games] [factie]`.
  Kandidaten spelen parallel (1 thread per kandidaat; MEER threads bleek averechts —
  allocator-contentie). Tegenstander-pool tegen rondjes draaien (potje 0 = baseline,
  1 = kampioen, rest = oude kampioenen). Mutatie/recombinatie zijn TEKEN-behoudend
  (bugfix: negatieve flankvoorkeuren werden naar +0.01 geklemd).
- **64-cores-route: `train_ai_parallel.bat`** — start 6 processen, één per factie; elk
  schrijft een eigen override (`data/ai_weights_f<d>.json`), `AIController.load_profile`
  merget die automatisch over het hoofdbestand (geen schrijfconflicten). Inspectie van
  het actieve profiel: `capture.tscn -- showweights`. Het dashboard (`Trainer.tscn`)
  blijft voor live meekijken (hill-climbing).
- Zie `AI_TRAINING_PLAN.md` voor de bredere roadmap (dit is Fase A+B).

## 9. TODO / volgende stappen

- [x] **i18n / slug-vertalingen (27 juli, opdracht Max)**: alle speler-zichtbare
      UI-strings lopen nu via `tr("SLUG")` + `res://i18n/strings.csv` (kolommen
      `keys,en,nl` — 320 sleutels; later talen = extra kolommen). Default-taal
      **Engels**; wissel via hoofdmenu-knop of `Constants.set_language("nl")`
      (bewaard in user://settings.cfg). Doctrine-namen/pro/con voor weergave via
      `Constants.doctrine_display_name()/doctrine_pro()/doctrine_con()` — de
      DOCTRINE_DATA zelf blijft NL (bestandsnamen/logica). Scene-teksten
      (card_hand/card_view) vertalen via Godot auto-translate (letterlijke tekst
      als key in de CSV). Dev-tools (sfeer-paneel, tuner, trainer) bewust NIET
      vertaald. Bekende restpunten: "1 cannons" (geen meervouds-logica),
      BARK_DOUBTER_NOM_TEAM_1 heeft 2×%s (pre-existente format-bug), feed-teksten
      worden gerenderd in de taal van dát moment (taalwissel hernoemt oude
      kaartjes niet).

- [x] **Solo-hang gefixt (27 juli, laptop)**: de hub bleef "Wachten op de volgende
      fase." tonen terwijl bot-duels minutenlang maalden (medium-AI, cycluslimiet 0,
      3000 stappen — en de tussenstand van een lopend duel wordt niet bewaard, dus
      afsluiten = duel opnieuw). Fix: (1) bot-duels in de hub op **easy** met
      cycluslimiet-vangnet 24 (`BOT_DUEL_AI`/`BOT_DUEL_CYCLE_LIMIT`,
      `SoloDriver.bot_duel_cycle_limit` — het MENS-duel houdt cycluslimiet 0 op het
      echte bord); de hang zat specifiek in medium (verdedigt naar de noodstop);
      (2) eerlijk busy-label + live voortgang ("De bots spelen duel X van Y:
      A vs B...") via `SoloDriver.bezig_met`; (3) testament-deadlock:
      `wacht_op_mens()` checkt pending testamenten nu vóór de actief-guard — een
      gevallen mens mét bezit kreeg anders nooit het testament-paneel; (4) nieuw:
      **factiekeuze bij de campagnestart** (vast voor de hele campagne, besluit
      Max) — keuzescherm in de hub, `SoloDriver.new(..., p_mens_doctrine)`.
      Regressietests in SoloTests.
      **DESIGN-BEVINDING (27 juli):** bot-duels via de snelle L1-agent
      (AgentRunner-route, blijft beschikbaar via `duel_ai="l1"`) lieten de
      campagne nooit convergeren: haven-rushers winnen zonder slachtoffers,
      niemand zakte door zijn pool. → **Beantwoord door C10 (besluit Max,
      zelfde dag): het vol-team-model.** Elk duel start hoe dan ook met de
      volle samenstelling; de pool is puur reinforcements (comp × 0.5) en
      slinkt alleen door INZET (spawns), donaties en testamenten — niet door
      bord-verliezen. Uitvallen = duel verloren + reinforcements op. Zie
      docs/campagne-spec.md §3 (C10); `CRules.vol_team_start` gate't oude
      logs; `inzet`-veld op MATCH_RESULT boekt (`reason: "inzet"`); de hub
      start oude saves opnieuw. Let op: een zuinige speler die nooit spawnt
      teert niet uit — de campagne-arena (F7) moet meten of dat een
      turtle-probleem wordt.

- [x] ~~REGELS v4.1 IN DE ENGINE~~ — **gedaan**, zie §2b. Resterende v4.1-gaten:
  - [x] **Vrije opstelling UI**: gedaan — "Zelf opstellen" in het opstellingsmenu:
        plaats het schaarste type eerst (kanonnen → paarden, klik op cyaan gemarkeerde
        thuisvakken, rechtermuis = ongedaan); infanterie vult automatisch aan (voorste
        rij, centrum eerst). Previews via losse PawnViews; engine-validatie bij submit.
        **Ghost-voorvertoning**: een semi-doorzichtig stuk van het huidige type volgt
        de muis over de vrije vakken (`_update_placement_ghost(_type)`; transparant
        teammateriaal op alle CSG-delen, schaduw uit).
        AI's plaatsen zichzelf via `choose_placement` (ook in sims/Trainer).
        Test: `capture.tscn -- placetest`. Doctrines met lege vakken (Leeuw) laten de
        rest van de thuisrijen automatisch leeg.
  - [ ] **Vos-informatie echt verbergen**: `pawn.card_revealed` wordt bijgehouden, maar
        de UI toont de stat-blokjes van ALLE actieve pionnen en de AI leest de volledige
        state (vals spelen). Voor mens-vs-AI met een Vos-AI zou de UI vijandelijke
        gedekte stats moeten maskeren; de AI-kant vergt een info-set-model.
  - [ ] **Engine-flags `vuurRaaktInactief`/`vuurGeblokkeerd`** (balansknop §8 v4.1):
        nu hard aan/aan volgens spec; als flags inbouwen zodra het selfplay-harnas
        het boogvuur-alternatief (uit/uit) moet kunnen meten.
  - [ ] **AI-eval verfijnen voor v4.1**: `_is_killable` kent alleen melee-dreiging
        (geen schoten/charges); artillerie-posities (schootsveld) worden niet gewogen;
        koppel-strategie is nog type-blind (kaart × type is juist de v4.1-kern).
  - [ ] **Playtest-agenda §8 van de regels** draaien via sims/Trainer per matchup
        (21 matchups); meet vooral standoff/verlamming en de 1/5/1-oogstmachine.
- [ ] **AI verder tunen / trainen** — nog te makkelijk te verslaan (§8). Zie **`AI_TRAINING_PLAN.md`**
      voor het gefaseerde bouwplan: self-play infrastructuur → eval-gewichten tunen via self-play
      (aanbevolen start) → MCTS → deep-RL (godot_rl_agents). Snelle korte-termijn-ideeën: diepere
      search voor Hard, mens-rush zwaarder straffen, betere koppel-strategie.
- [ ] **Karaktermodel** — de blokjes zijn vervangen door gestileerde CSG-speelstukken per
      type (`scenes/game/pieces/`); echte geanimeerde modellen (.glb via `model_scene`,
      kijk-/loop-/aanval-animaties op `face_dir`) blijven een latere upgrade.
- [ ] **Aanval-animatie** (hit-flash / bounce / screen shake bij een treffer).
- [ ] "AI denkt…"-feedback duidelijker maken (nu vrijwel instant).
- [ ] Geluid + eventueel echte sprites (i.p.v. gekleurde blokken).
- [ ] Camera-/board-thema polijsten (tile-kleuren, WorldEnvironment/ambient).
- [x] ~~`main.tscn` opschonen en README updaten naar 3D-realiteit~~ — gedaan: main.tscn
      bestond al niet meer, README herschreven, GAME_LOGIC_OVERVIEW.md verwijderd,
      `_shot*.png` opgeruimd + in .gitignore.
- [ ] **ONLINE PLAYTESTEN — volledig plan in `ONLINE-PLAYTEST-PLAN.md`** (juli 2026):
      Fase 0 (offline voorwerk: reveal-UI met tegenstander-kaarten, camera-flip voor P2,
      submit_doctrine/submit_resign/cycluslimiet in de engine, per-speler view-filter +
      snapshot-serializer, Vos-"?"-UI, touch-knoppen, web-export-spike) → Fase 1
      (WebSocket + JSON, headless server op de DO-droplet, rooms = GameSession-instanties,
      device-token reconnect) → Fase 2 (lobby-lite, quick-match, playtest-telemetrie
      gekoppeld aan spelregels §8, feedback-knop, server-AI max Medium) → Fase 3
      (Glicko-2 + SQLite, leaderboard, matchmaking, seizoenen, rematch) → Fase 4
      (dichttimmeren: leak-canary, replay-verificatie). Schatting Fase 0+1: 60-90 uur.
- [ ] Export-presets (Android AAB, Web, iOS) — later.
- [ ] **Diorama: mini-animaties van je eigen factie** (Max, 8 september: "wat
      dan leuk is dat je kleine mini animaties ziet van de factie die je hebt
      gekozen"). Idee: in het kamp vooraan (scripts/game/omgeving.gd) een of
      twee pionnen van de gekozen factie neerzetten die niet meespelen, met
      korte idle-clips uit de bestaande animaties (zitten bij het vuur, musket
      poetsen, trommelen, om zich heen kijken), per factie een eigen setje en
      een klikreactie zoals de andere props. De tegenstander krijgt hetzelfde
      aan de overkant zodra zijn factie bekend is (na de blinde keuze). Bouwt
      voort op PawnView (modellen, teamkleur, clips) en de prop-registratie in
      Omgeving; de speler-factie is bekend vanaf CHOOSE_DOCTRINE.

## 10. Open ontwerpvragen (wachten op keuze)

Beantwoord door `spelregels-v4.1.md` en de implementatie:

- **Tiebreak-methode**: opgelost — RPS is verwijderd; deterministisch bod → Speed-bod →
  C1/R1: P1, anders vorige initiatiefhouder (`Rules.compute_initiative`). De RPS-fases
  staan nog ongebruikt in `Phase.Type` (opruimen mag).
- **Wederzijdse aanvalsschade**: opgelost — terugslag (§3.1 v4.1), geïmplementeerd.
- **Start-verdeling kaarten**: opgelost — `CardData.reset_stats()` verdeelt het
  doctrinebudget (7→3/2/2, 5→2/2/1, 9→3/3/3; Beer-speedcap → overschot naar HP).
- **Balansknoppen v4.1 §8**: bewust nog níét in de regels (standbeeld-drempel, cumulatieve
  havenscore, per-stat cap, …) — beslissen via selfplay/playtests, agenda staat in de regels.
