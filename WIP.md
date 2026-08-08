# Fog of War — Work In Progress & Context

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


## 8 augustus -- de facties staan (4,4 procentpunt spreiding)

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
