# Spelregels — CHANGELOG

## Alles meet nu het echte spel — 8 augustus 2026 (en dat legde een bug bloot)

*Besluit Max: "alles moet op echte facties en de 4.2 campagne."* Geen
regelwijziging, wel een meetwijziging, en die vond meteen iets dat al ruim een
week stuk was.

**Wat er is omgezet.** De nachtrun verdeelde zijn tijd om-en-om over de
4.1-matrix en de campagne-matrix (F2.6/B17); de 4.1-helft mat een economie die
niemand meer speelt, met de kale factietabel erbij. Die helft is eruit. Verder
wijzen `quick_l1`, `matrix_l1` en `matrix_l2` nu naar
`rules_v42_campaign.json` (met `max_steps` 1500 → 2500, want onder V0 duren
partijen langer en is een afkapping een fout), en de defaults van `arena.ps1`,
`arena.bat` en de runner zelf staan op de campagne-matrix.

**Een vangnet eronder.** `arena/run.gd` legt voortaan het aangenomen
`doctrines`-blok over elk regels-bestand dat er zelf geen draagt, precies zoals
`game.gd` dat voor een los potje doet. Elke config meet dus de dieren die het
spel ook opstelt, ook de oude sweep-configs. De run-metadata schrijft op welke
facties zijn gespeeld (`facties_bron` + het blok), zodat je dat achteraf niet
hoeft te raden; `"facties_uit_bestand": false` in een config zet het uit.

**En de fuzz draait nu zelf ook op de echte regels.** Dat was de belangrijkste
wijziging, want daar zaten twee dingen onder:

- **De fuzz kende de VERSTERKINGEN niet.** Zijn invariant "pion-ids liggen vast
  na de opstelling" komt uit 4.1. Sinds F2.2 zetten spelers in CYCLE_SPAWN
  nieuwe pionnen op het bord, en dat is legitiem. Nieuwe ids mogen nu ontstaan
  in de actie die `spawns_revealed` meldt, en daarbuiten nog steeds niet.
- **De C15-rol viel uit elk opgenomen potje weg.** `Actions.to_dict` schreef
  van een opstelling alleen type en positie, niet `rol`. De opstelling gaat als
  `place`-actie het log in, dus elke opgenomen campagne-partij verloor zijn
  vaandeldragers en tamboers. Bij het naspelen kwam de C15-buit (2 punten /
  2 CP per drager) dan nooit binnen, en liep de nagespeelde partij vanaf actie 0
  uit de pas. Dat betekent: **replays van campagne-duels waren sinds C15 (30
  juli) niet betrouwbaar**, en de campagne-logs die daarop leunen evenmin. De
  fuzz zag het niet omdat hij zelf op 4.1-regels draaide, waar figurant-rollen
  niet bestaan; de goldens zagen het niet omdat die eindstanden vergelijken.
  `rol` reist nu mee, en alleen als hij gevuld is: logs van vóór vandaag blijven
  byte-identiek en spelen zich af zoals ze zijn opgenomen. Geen versie-bump,
  want de gespeelde regels zijn niet veranderd; dit is een formaat-uitbreiding.

Twee regressietests erbij (`SerializerTests`): de rol moet de actie-rondreis
overleven zonder dat een lege rol een sleutel toevoegt, en een campagne-staat
moet byte-identiek door de serializer komen, inclusief campagne- en factie-blok.

## C19 definitief — 8 augustus 2026 (facties afgesteld op 4,4 procentpunt)

Twee correctierondes na de eerste aanname, elk gestuurd door een meting.

| factie | kaarten | budget | comp | perk |
|---|---|---|---|---|
| Varken | 3 | 7 | [11, 5, 3] | - |
| Muis | 5 | 5 | [16, 4, 0] | - |
| Leeuw | 2 | 8 | [12, 4, 2] | artilleriedracht +1 |
| Beer | 3 | 7 | [19, 3, 0] | HP +1 |
| Wolf | 3 | 7 | [11, 8, 3] | cavalerie-snelheid +2 |
| Krokodil | 3 | 6 | [13, 5, 3] | - |

**Bevestigd op 1152 partijen en ANDERE seeds** (515000) dan waarop is afgesteld
(91000), dus dit is geen overfitting:

| factie | winst | haven-aandeel |
|---|---|---|
| Varken | 56,2% | 1% |
| Beer | 54,4% | 93% |
| Leeuw | 52,5% | 1% |
| Wolf | 46,9% | 79% |
| Krokodil | 45,3% | 51% |
| Muis | 44,7% | 97% |

Spreiding **4,4 procentpunt**, band 45-56%, niemand verder dan 6,2 van de 50.
Beginstand was 28-76%.

En let op die havenkolom: Beer wint met 93% rennen, Leeuw met 99% slachten, en
ze staan allebei rond de 53%. Twee compleet verschillende manieren om te winnen,
even sterk. De zorg van 7 augustus dat eliminatie het structureel wint van
rennen is daarmee weerlegd.

### Wat we onderweg over de knoppen hebben geleerd

Dit is bruikbaarder dan de tabel zelf, want het zegt welke knop je moet pakken:

- **Kaartbudget is veruit de zwaarste.** Een punt is ongeveer 30 procentpunt.
  Leeuw ging van 63,7 naar 46,7 op budget 9 -> 8; Varken van 33,2 naar 64,2 op
  6 -> 7. Te grof om mee af te stellen, alleen voor grote correcties.
- **Cavalerie is de tweede**: een ruiter meer of minder is ongeveer 18 punten.
- **Infanterie doet vrijwel niets** en **legergrootte op zichzelf helemaal
  niets**: Beer scoorde met [15,3,0] en [17,3,0] exact hetzelfde (49,2%).
- **Artillerie is een last voor een RENNER en neutraal voor een slachter.**
  Beer verloor er 21 procentpunt aan, Leeuw houdt de zijne zonder bezwaar.
- **Het leger van een factie bepaalt zijn spelstijl NIET.** Leeuw ging van tien
  cavaleristen naar vier en bleef 0% haven: een pure slachter.

### Ceremonie

Ijk-sims drie keer opnieuw geijkt (per correctieronde). De winnaar bleef in alle
vijf de sims steeds dezelfde; alleen de partijduur schoof. Partijen zijn per
saldo NIET langer geworden: mediaan 9 cycli, hongerdoden 8,0% van alle doden,
nul afkappingen over 1152 partijen. Stap-budget van de trainer (1400) is ruim:
gemeten maximum 957.

**De factiezoeker meet nu vanaf de ACTIEVE facties** in plaats van de kale tabel
uit `constants.gd`. Dat was stuk geworden door de aanname: hij gaf het
aangenomen blok identiteit 0,49 in plaats van 1,00 en zou dus kandidaten hebben
beloond die deze wijzigingen terugdraaien.

**De bots moeten hertraind**: hun gewichten komen van de nacht van 7 augustus,
dus van vóór deze twee correctierondes.

### Nasleep: de rest van het spel kende de nieuwe facties nog niet

Bij het doorlopen van alle documentatie en schermen bleek het blok op een aantal
plekken langs de tekst heen te gaan. Geen regelwijzigingen, wel dingen die de
speler en de assetlijst verkeerd voorlichtten:

- **Drie schermen lazen `Constants.DOCTRINE_DATA` rechtstreeks** (factiekiezer
  in het hoofdmenu, tegenstanderkiezer, help-scherm). Die beloofden dus de kale
  tabel: "4 kaarten" bij een Muis die er vijf uitdeelt, budget 9 bij een Leeuw
  met 8. Ze gaan nu via `CRules.actieve_tabel()`. De campagne-lobby toonde
  alleen pro/con-tekst en had hetzelfde probleem via de i18n-regels.
- **De pro/con-teksten noemen geen verschuifbare getallen meer.** Kaartaantal,
  budget en legergrootte staan er in de schermen toch al live naast; de tekst
  zegt nu alleen wat kwalitatief vastligt. Krokodil's PRO beloofde bovendien nog
  "+1 Speed op cavalerie", een perk die in C18 naar de Wolf is verhuisd.
- **Muis en Beer hebben geen artillerie meer.** `GameState.kent_type()` verbiedt
  ze een kanon te spawnen, dus `artillery_base` en `cannon_die_<factie>` zijn
  voor die twee verloren werk. MODEL-WISHLIST, SOUND-WISHLIST, model-tracker en
  de geluidtracker weten dat nu; de geluidtracker leest de comps rechtstreeks
  uit de regels, dus die corrigeert zichzelf als de facties weer schuiven.
- **`toon_economie.py` rekende met legers die niemand meer opstelt.** Legt nu
  hetzelfde blok eroverheen als het spel, en toont `honger_vanaf_cyclus` in
  plaats van de allang afgeschafte `cycle_limit`.
- **Beer's speedplafond stond in drie documenten als 3.** Het is 4 sinds C13
  (29 juli); die wijziging stond wel in deze changelog maar was nooit in de spec
  doorgevoerd. Gevolg voor het asset-spoor: de Beer heeft drie `spd`-kaarten in
  plaats van één, alleen de uiterste 1/5/1 valt voor hem af.

Let op bij een volgende tekstwijziging: het spel leest de gecompileerde
`i18n/*.translation`, en een headless run bouwt die NIET opnieuw. Alleen de csv
aanpassen verandert dus niets aan wat de speler ziet. Herbouwen met
`<godot> --headless --path . --import`, en de twee `.translation`-bestanden
meecommitten. Twee regressietests (`CampaignTests.test_c19_actieve_tabel_*`)
bewaken voortaan dat de schermtabel het regels-blok volgt en dat een ontbrekend
regels-bestand netjes terugvalt op `constants.gd`.

## C19 — 7 augustus 2026 (facties aangenomen: het eerste doctrines-blok)

*Besluit Max, na de zoekrun van 6 augustus, het nameten daarvan en drie eigen
correcties.* Dit is het EERSTE blok dat echt wordt aangenomen; alle eerdere
voorstellen zijn bekeken en weer weggelegd.

> **Historie, niet de geldende stand.** Twee correctierondes later ziet de
> tabel er anders uit; zie "C19 definitief" bovenaan. Varken schoof hier het
> verst door: budget 6 bleek 30 procentpunt te duur en ging weer naar 7.

| factie | was | wordt (op 7 augustus) |
|---|---|---|
| Varken | 3k b7 [13,6,3] | budget **6**, comp **[12,6,3]** |
| Muis | 4k b5 [18,4,0] | **5 kaarten**, comp **[16,4,0]** |
| Leeuw | 2k b9 [6,10,2] | comp **[12,4,2]** |
| Beer | 3k b7 [16,3,3] | comp **[19,3,0]** |
| Wolf | 3k b7 [11,8,3] | cavalerie-snelheid **2** |
| Krokodil | 3k b6 [13,6,3] | comp **[13,5,3]** |

Drie van deze zes gaan bewust IN TEGEN wat de zoeker voorstelde, en in twee
gevallen had Max gelijk:

- **Leeuw** kreeg van de zoeker meer budget (9 → 10) terwijl hij met 84% de
  sterkste was. Dat de meting toch een daling liet zien, kwam doordat de rest
  harder steeg: wegpoetsen, geen indammen. Nu blijft het budget 9 en gaat het
  mes in zijn leger: tien cavaleristen worden er vier. Zie de vondst hieronder.
- **Varken** houdt zijn drie kaarten (de zoeker wilde er twee) en levert in
  plaats daarvan de cavalerie-snelheid in plus een budgetpunt. Een kaart bleek
  daar 33 procentpunt waard, dus dat is de zwaarste knop van het spel.
- **Beer** houdt een vol leger van 22 pionnen, maar zonder artillerie. Hier had
  Max ONgelijk: zijn wens om het kanon te behouden kostte 21 procentpunt.

### De vondst die dit stuurde: artillerie is slecht voor een RENNER

Gemeten over 432 partijen per variant, alleen Beer's comp verschilt:

| Beer | winst |
|---|---|
| [15,3,0] 18 pionnen, geen kanon | 49,2% |
| [17,3,0] 20 pionnen, geen kanon | **49,2%** |
| [15,3,2] 20 pionnen, 2 kanonnen | 33,3% |
| [17,3,2] 22 pionnen, 2 kanonnen | 23,3% |

Legergrootte doet NIETS (49,2 tegen 49,2). Artillerie kost 21 procentpunt.

De oorzaak staat in de regels: `art_move 1` (`Rules.gd:75`) laat een kanon een
vak per ACTIE verzetten waar infanterie zijn hele Speed in een keer loopt, een
kanon kan geen melee en heeft terugslag 0. Onder het vol-team-model staat je
comp elk duel op het bord, dus twee kanonnen zijn permanent twee lopers minder.

En Beer is een renner: 58% van zijn winsten komt uit de haven. Leeuw daarentegen
won 91 partijen en NUL keer via de haven, Varken 76 en een keer. Die twee vegen
het bord leeg. Daarom hielpen budget-knoppen niet bij Leeuw: hij is sterk omdat
ELIMINATIE het wint van RENNEN, niet omdat zijn kaarten goed zijn. Vandaar het
mes in zijn cavalerie.

### Gevolgen

**De ijk-sims zijn opnieuw geijkt.** Alle vijf werden LANGER (seed 404: 6 → 16
cycli, seed 777: 4 → 7), maar de WINNAAR bleef in alle vijf dezelfde. De nieuwe
legers vechten trager, niet anders. Let op: langere partijen betekent dat de
honger (vanaf cyclus 10) vaker gaat bijten dan bij de meting van 3 augustus.

**De bots zijn NIET hertraind.** Ze hebben op de oude facties leren spelen, dus
elke meting hierna is een meting met verouderde bots tot dat gebeurd is.

**Leeuw [12,4,2] is als enige NIET los doorgemeten.** De drie metingen die
daarvoor liepen zijn afgebroken toen Max de machine nodig had. Dat is bewust:
het doortesten gebeurt nu via het paneel, vanaf deze nieuwe nulmeting.

## V0 — 3 augustus 2026 (geen gelijkspel, de uitputtingsklok, rules_version 4.3.0)

*Besluit Max: "een duel eindigt op de haven of op totale eliminatie. Meer
smaken zijn er niet." Bron: `docs/campagne-intrige-voorstel.md` §1b.*

Dit is geen sfeerregel maar een fundament. Als elk duel beslissend is, is elke
nominatie in de raad een doodvonnis, en dat maakt de hele politieke laag van de
campagne zwaarder. Het is ook de afmaking van de C9-waarneming: bots wonnen
vrijwel alleen via de tiebreak, dus ging de cycluslimiet er toen al uit.

**Wat verdwijnt:**

- `cycle_limit` en `tiebreak` als knoppen. De tiebreak-knop was al dood (de
  string werd nergens gelezen, de reducer riep de functie onvoorwaardelijk aan).
- `Reducer.tiebreak_winner` en `_haven_closeness`.
- De trede `punten_tiebreak` in de campagne (roem kent nog haven, eliminatie en
  verlies).
- De campagne-tak waarin bij winnaar -1 **beide** vechters een punt kregen en
  niemand iets verloor. Dat was precies de uitkomst die dit besluit verbiedt.
- De bracket-regel "bij remise valt de laagste seed uit".

**Wat ervoor terugkomt: de honger.** Vanaf `honger_vanaf_cyclus` verliest elke
speler bij het begin van een cyclus een pion: de pion die het **verst van zijn
doelhaven** staat. De achterhoede verhongert dus het eerst, en dat duwt je
vooruit in plaats van achteruit. Thematisch de Russische veldtocht: niet de
vijand maakt je leger op, de winter doet dat.

Drie dingen daaraan zijn correctheid, geen smaak:

1. De spelers eten **om de beurt, met een win-check ertussen**, en wie het eerst
   eet wisselt per cyclus. Verhongeren beiden tegelijk hun laatste pion, dan
   staat de winstcheck op nul tegen nul en leest die dat als "nog geen
   winnaar": het duel zou eeuwig doorlopen. Een vaste volgorde zou de tweede
   speler in precies die stand een gratis winst geven.
2. Bij gelijke afstand valt de **laagste pion-id**, zodat de keuze niet aan de
   invoegvolgorde van een dictionary hangt.
3. Honger boekt **geen C15-buit**. De cyclusreset heeft net alle pionnen
   ontkoppeld, dus elke vaandeldrager zou anders 2 punten opleveren voor iemand
   die niets deed.

**De winstvoorwaarde is bijgesteld**: eliminatie kijkt naar **inzetbare**
reserve. Spawnen is gecapt op `spawn_totaal_max`, en is die cap op, dan zijn je
punten dood kapitaal. Zonder die correctie kon je met een leeg bord en een volle
pot "in leven" blijven, en dan houdt de honger nooit op.

**De noodstop verzint geen uitslag meer.** Beide runners kapten bij `max_steps`
stilletjes af met een tiebreak-winnaar; nu blijft `winner` op -1, gaat er een
`afgekapt`-vlag aan en gilt een `push_error`. De arena boekt dat als eigen
categorie in plaats van als remise, zodat een kapotte klok niet in een
onschuldig ogende kolom verdwijnt. De stap-budgetten van trainer en solocheck
zijn daarop verruimd (600/900 → 1400, gemeten max 932).

**Opgeven telt voor de winnaar als een eliminatie**, roem én CP. Anders is
opgeven een goedkope manier om de winst van je tegenstander te drukken. De staat
draagt daarvoor een nieuw veld `eind_reden` ("haven" / "eliminatie" / "resign" /
"timeout"), want de campagnelaag leidde de methode tot nu toe af uit de
eindstaat en een opgave was daaraan niet te zien: die boekte als tiebreak.

### Het getal, en waarom

C17 (een regel, twee getallen) is hier één regel en één getal: **honger vanaf
cyclus 10**, in campagne en los potje gelijk. Gemeten over 216 partijen, L2
tegen L2 op de campagne-regels:

| klok | cycli mediaan | cycli max | stappen max | beslissend |
|---|---|---|---|---|
| cycluslimiet 25 (oud) | 10 | 26 | 1.165 | 95% |
| helemaal geen klok | 10 | **330** | **6.001** | 97% |
| honger vanaf 10 | 10 | **16** | **932** | **100%** |

De mediaan is in alle drie de gevallen 10 cycli: de klok doet niets voor een
gewone partij en bestaat puur voor de staart. Die staart was erger dan gedacht,
want zonder klok liep één partij door tot 330 cycli en knalde tegen de noodstop
van 6.000 stappen.

De honger verschuift de uitslagen wel: van 118 eliminatie / 88 haven naar 139 /
73. Dat is logisch, want hij dunt legers uit. Bots moeten hier dus op hertraind
worden; hun oude waardefunctie kende "overleven tot de limiet" als geldige
uitkomst en die bestaat niet meer.

**Ijk-sims:** drie van de vijf werden korter (seed 101: 23 → 17 cycli, seed 202:
26 → 11, seed 303: 366 → 361 acties). De **winnaar bleef in alle drie dezelfde**:
de honger kort partijen in zonder uitslagen om te draaien. Alle 15 golden
replays zijn opnieuw opgenomen, want de hash dekt de volledige regels-config;
`cycluslimiet_remise.json` is vervangen door `honger.json`.

## C17 afgemaakt — 3 augustus 2026 (de campagne volgt nu ook de facties)

**Geen gedragswijziging zolang er geen `doctrines`-blok is.** Wel: tot vandaag
kon een aangenomen factie-voorstel het echte spel helemaal niet bereiken.

C17 zei "EEN regelset", maar dat was een afspraak, geen mechanisme. De campagne
rekende haar startvoorraad uit met `Constants.doctrine_data()` (`cstate.gd:55`),
stelde haar duels op met dezelfde kale tabel (`solo_driver.gd:378`) en bouwde de
duelregels ter plekke op zónder `doctrines`-sleutel (`solo_driver.gd:399`). Een
voorstel van de factiezoeker landde dus wel in de arena, de trainer en de
ijk-sims, en nooit in een gespeelde campagne.

Alle drie moesten samen mee. Alleen het blok doorgeven aan de duelregels was
niet genoeg: `comp_override` uit de campagne wint in
`GameState.doctrine_data_of()` van de merge, dus je zou nieuwe kaarten, budget
en perks krijgen op een leger van de oude grootte.

- **`CRules` krijgt een `doctrines`-veld** met dezelfde vorm als het blok in de
  match-regels, plus `doctrine_data()` die naar `RulesConfig` delegeert (zo
  erven we de sleutel-behandeling en `_diep_int` uit de fix van vanochtend).
- **Bij campagnestart** wordt het blok uit `rules_v42_campaign.json` gelezen:
  hetzelfde bestand waar de trainer, de arena en de ijk-sims op draaien. Alleen
  de `doctrines`-sleutel; de rest van dat bestand bevat meet-instellingen zoals
  de cycluslimiet, en die horen niet in een echte campagne (C9).
- **Daarna bevroren in de save.** Hervatten gebruikt de opgeslagen kopie, nooit
  het bestand. Neem je later een ander voorstel aan, dan houdt een lopende
  campagne haar eigen dieren en pakken alleen nieuwe campagnes het nieuwe blok.
- **Het losse potje** (`game.gd:547`, `v42_default.json`) haalt zijn facties uit
  dezelfde bron, anders speelt een los duel andere dieren dan de campagne.
- Saves van voor vandaag missen de sleutel en krijgen een leeg blok: dat is
  precies hun oude gedrag.

Let op bij het aannemen van een voorstel: `budget_bonus` (Muis +4 pt, Beer +3,
Wolf +2 pt/+4 CP) blijft er als aparte startboeking bovenop staan. Arena en
campagne passen die allebei toe, dus de meting klopt, maar het zijn wel twee
knoppen die hetzelfde probleem oplossen.

Nog niet gelijkgetrokken: de factiekeuze in de hub en het Facties-tabblad in het
uitlegscherm drukken nog de kale tabel af. Met een blok actief kiest de speler
dus op verouderde cijfers. Ook draagt `CView` geen doctrine mee, dus
campagne-bots kunnen niet op gewijzigde factie-eigenschappen redeneren.

## Meetfout hersteld — 3 augustus 2026 (doctrines-blok legde de bots lam)

**Geen regelwijziging. Wel: alle metingen mét een `doctrines`-blok waren tot
vandaag waardeloos.** Dat raakt de hele eerste factiezoeker-run (1 en
3 augustus). De nulmeting klopte, alle kandidaten niet.

Wat er gebeurde: de agent bouwt elke beurt zijn eigen staat uit de view, en
daar zit de regels-config als dict in. `RulesConfig.from_dict` normaliseerde de
doctrine-sleutels naar **int**; bij de tweede rondreis (`to_dict` → `from_dict`,
precies wat de agent doet) stond er dus een int in de sleutel en riep de code
`String(int)` aan — een constructor die in Godot 4.7 niet meer bestaat.
`from_dict` gaf `null` terug, `reconstruct_state` viel om, en de runner koos
voor élke beurt maar `legal[0]`. De bots speelden dus niet meer, maar er kwam
wel netjes een uitslag uit.

Meetbaar aan de fallback-teller: **236.928 noodkeuzes** per 216 partijen (elke
beurt) tegen **0** bij de nulmeting. Zichtbaar in de uitslagen: eliminaties
verdwenen volledig (78 → 0), partijen liepen naar de cycluslimiet, en speler 1
sprong van 61% naar 85-90% — ongeacht wát er in het blok stond. De
identiteits-rem en het kant-veto rekenden vrolijk door op die onzin, dus 72 van
de 73 kandidaten werden afgeschoten en de kampioen bewoog nooit.

Alleen een **leeg** blok bleef heel (de lus draait dan niet), en juist de
nulmeting had er een. Daarom zag de run er van buiten normaal uit.

- `core/match/rules_config.gd`: doctrine-sleutels blijven **string**, zodat de
  rondreis stabiel is; waarden gaan door `_diep_int` (JSON leest `6` terug als
  `6.0` en `comp` moet ints houden).
- `agents/agent.gd`: nieuwe helper `doctrine_data_uit_view()` — factie-data
  zoals ze in dít potje gelden, tabel plus override.
- `agents/l1_greedy.gd` las `Constants.doctrine_data()` rechtstreeks en plande
  zijn aanvul-spawns dus met een leger dat hij niet had. Gebruikt nu de helper.
- Canary's: `AgentTests.test_bots_blijven_spelen_met_doctrines_blok`
  (fallback_count = 0) en twee rondreis-tests in `RulesConfigTests`.

### En de zoeker mat 36 partijen, geen 216

Tweede vondst, uit dezelfde controle. Drie totaal verschillende `base_seed`-
waarden (515000, 91000, 300000) gaven **byte-identieke uitslagen**: 61% speler 1,
114 haven, 78 eliminatie, 24 tiebreak. Oorzaak: L2 is volledig deterministisch
tenzij `tie_break_loting` aanstaat, en die knop stond alleen in de nachtmatrix.
Zonder loting kiest de bot bij gelijke stand altijd dezelfde zet, dus zijn
`games_per_matchup: 2` maal drie processen niet 216 partijen maar **36 unieke
potjes, zes keer overgetikt**.

Dat verklaart meteen de 61% tegen 51% die eerder op ruis werd afgeboekt: dat is
geen ander spel en geen andere seed-set, dat is het verschil tussen 36 partijen
zonder spreiding en 3240 mét. Beide zoekers zetten `tie_break_loting: true` en
`max_steps: 2500`, gelijk aan `v42_matrix_l2.json`.

Verder in de zoekers:

- **Kant-veto is nu relatief**: ijken op de nulmeting van dezelfde run, met 62%
  als bodem en 85% als harde bovengrens, in plaats van vast 50 ± 15.
- **Vaste seeds.** Kandidaten speelden `515000 + generatie * 1000` en werden
  afgezet tegen een kampioen die op ándere partijen was gemeten. Nu speelt
  iedereen dezelfde seeds: gepaarde vergelijking. Prijs: het voorstel kan zich
  vastbijten in juist die partijen, dus altijd nameten met de nachtmatrix.

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

> **Nagekomen 3 augustus:** deze tabel is gemeten zonder `tie_break_loting`, en
> L2 is zonder die knop volledig deterministisch. De "324 partijen" waren dus
> 36 unieke potjes, negen keer overgetikt -- vandaar de twaalfden (83,3% / 8,3%
> / 33,3%). Het besluit staat overeind (Krokodil had het leger van Varken plus
> twee voordelen, en de nachtmatrix wees dezelfde kant op), maar deze getallen
> zijn te dun om iets aan af te lezen. Nameten met een nachtrun.

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
