# Fog of War — Campagne-uitbreiding: verraad, bluf en samenwerking (VOORSTEL)

> **Status: VOORSTEL, nog niets besloten.** Dit document stelt regels voor die
> bovenop `docs/campagne-spec.md` (C1-C17) komen. Niets hierin is geïmplementeerd.
> Zodra Max een voorstel goedkeurt, verhuist het als C-besluit naar de spec en
> krijgt het een entry in `docs/spelregels-CHANGELOG.md`.
>
> **Doelmodus: F5, de online campagne met 16 mensen.** De solo-campagne
> (1 mens + 15 bots) moet elke regel kunnen spelen: per voorstel staat in §7
> wat de bot doet. Een regel die alleen online werkt, hoort hier niet in.
>
> **Voorstelcodes zijn V0..V19.** Ze worden pas een C-nummer als ze zijn
> aangenomen. Zo blijft zichtbaar wat besluit is en wat idee.

---

## 0. Waarom dit document bestaat

De campagne heeft de economie van intrige al: je bepaalt wie tegen wie vecht,
je verdeelt schaarse middelen, je bezit is verborgen en je erfenis mag naar de
vijand. Wat ontbreekt, is dat er iets **gezegd** kan worden en dat iemand het
**onthoudt**.

Een schemer heeft vier dingen nodig. Je hebt er anderhalf:

| Nodig | Nu |
|---|---|
| Een hefboom over andermans lot | **Aanwezig.** De raad bepaalt wie vecht. Dit is de sterkste regel in het spel. |
| Informatie die anderen niet hebben | **Kapot.** Zie V1: de mist is vandaag cosmetisch. |
| Beloftes die je kunt breken | **Afwezig.** |
| Een publiek dat het onthoudt | **Afwezig.** |

Bij zestien mensen hoef je liegen niet te bouwen. Liegen is gratis en oneindig
en beter dan wat een ontwerper kan bedenken. Wat je bouwt is het **moment
waarop een leugen controleerbaar wordt**.

---

## 1. Vijf uitgangspunten

Alles hieronder volgt uit deze vijf. Wie een nieuw voorstel bedenkt, toetst het
eerst hieraan.

### P0 — Een duel kent geen gelijkspel

**Besluit Max, 3 augustus 2026.** Een duel eindigt op de **haven** of op
**totale eliminatie**. Meer smaken zijn er niet. Geen remise, geen tiebreak,
geen winst op punten.

Dit is geen sfeerregel maar een fundament, en het maakt de hele politieke laag
zwaarder: als elk duel beslissend is, is elke nominatie in de raad een
doodvonnis. Uitwerking in §1b.

### P1 — Nooit afdwingen, altijd vastleggen

Het spel is **notaris**, geen chatprogramma. Een belofte die de regels afdwingen
is een contract, en contracten zijn saai. Een belofte die het spel woordelijk
bewaart en op het juiste moment naast je werkelijke daad legt, is een strop.

Er komt dus **nooit** een regel die zegt "je moet je belofte nakomen" of "je
verliest roem als je liegt". Het spel registreert, publiceert op het afgesproken
moment, en zwijgt verder.

**Gevolg dat je nu al moet accepteren: geen vrije tekst.** Alles wat het spel
vastlegt, moet het spel ook automatisch kunnen toetsen. Vrije tekst tussen
zestien vreemden vraagt vanaf dag één om melden, blokkeren en moderatie, en die
infrastructuur hoort niet in een Godot-reducer. Dus: **gesloten zinnenlijsten,
altijd.** Praten doen ze op Discord, en dat is prima. Het spel levert alleen de
akte.

### P2 — Blind vastleggen, gelijktijdig onthullen

Het duel doet dit al overal: kaarten definiëren, CP inzetten en versterkingen
plaatsen gebeuren blind en tegelijk, achter een commit-gate. De campagne doet
het nergens. Elke sociale actie in dit voorstel volgt hetzelfde ritme: **eerst
iedereen vastleggen, dan alles tegelijk open**.

Zonder dat ritme valt er niets te bluffen: wie als laatste indient, hoeft niet
te gokken.

### P3 — Je bondgenoten zijn je finalisten

Het team wint samen, en daarna vechten de overlevenden onderling om de kroon.
Elke gift bewapent iemand die je in de finale treft. Elke nominatie waarmee je
een teamgenoot spaart, laat een rivaal groeien.

Dat is de Napoleontische spagaat: je hebt ze nodig om de oorlog te winnen en je
hebt ze zwak nodig om de vrede te winnen. Die spanning verschijnt nu pas
helemaal aan het eind, als zaaiing. Ze hoort vanaf ronde 3 in beeld te staan.

### P4 — Elke regel heeft een botgedrag

De solo-campagne is de **leerschool**, de menscampagne is het echte spel.

Geen voorstel wordt aangenomen zonder dat in §7 staat wat de bot doet, en dat
gedrag moet **deterministisch** zijn (uit de agent-rng-fork, nooit `randi()`),
**leesbaar** (de speler moet de zet als karakterkeuze herkennen) en **feilbaar**
(bots moeten zich vergissen en hun woord breken, anders bestaat bluf in solo
niet).

---

## 1b. Geen gelijkspel: de uitputtingsklok (V0)

### Wat er weg moet

P0 is niet gratis. Op vijf plekken staat op dit moment letterlijk het
tegendeel, en op één daarvan bestaat een **echt** gelijkspel:

| Waar | Wat er nu staat | Wat het wordt |
|---|---|---|
| `crules.gd:48` | `punten_tiebreak: int = 1` | de trede verdwijnt uit de tabel en uit `punten_voor_methode`. |
| `reducer.gd:407` `tiebreak_winner` | materiaal, dan haven, dan nabijheid, en **alles gelijk geeft -1**: een echte remise | de hele functie vervalt. |
| `reducer.gd:317` | voorbij `cycle_limit` wordt de tiebreak de uitslag | vervalt; de honger hieronder neemt het over. |
| `creducer.gd:305` | bij winnaar -1 krijgen **beide** vechters het tiebreak-punt | vervalt; winnaar -1 kan niet meer voorkomen. |
| `rules_config.gd:55` | `cycle_limit` en `tiebreak` als knoppen | beide knoppen verdwijnen, er komt er één voor terug. |

Dat vierde punt is het scherpste: op dit moment kan een campagne-duel eindigen
waarin **beide** spelers een punt krijgen en niemand iets verliest. Dat is
precies de uitkomst die P0 verbiedt.

**RESIGN blijft bestaan.** Opgeven is geen gelijkspel maar een verlies. Twee
dingen horen daarbij besloten te worden:

- Telt opgeven voor de **winnaar** als eliminatie (2 roem)? Voorstel: ja,
  anders is opgeven een goedkope manier om de winst van je tegenstander te
  drukken.
- Op dit moment kennen resign, tiebreak en timeout bewust **geen CP-tarief**
  (`reducer.gd:595`). Als opgeven als eliminatie telt voor de roem, ligt het
  voor de hand dat ook voor de CP door te trekken.

**En de noodstop.** De campagne-spec noemt een ruime technische noodstop
(`max_steps`) voor bot-simulaties. Onder P0 mag die noodstop **geen uitslag
meer opleveren**: hij wordt een harde fout. Een duel dat de noodstop haalt, is
vanaf nu een bug in de uitputtingsklok en moet als zodanig gillen, niet stil
een remise boeken.

### Het probleem dat dan overblijft

Zonder tiebreak en zonder cycluslimiet moet iemand het einde afdwingen. En dat
gebeurt niet vanzelf: onder C10 is je veldleger gratis en gegarandeerd, en
bordverliezen kosten je geen reserves. Passief blijven staan is dus goedkoop.
Twee spelers die zich ingraven, kunnen in theorie eeuwig blijven zitten.

De cycluslimiet was tot nu toe het vangnet. Als dat vangnet weg is, moet de
**druk uit de regels zelf komen**.

### De uitputtingsklok

Vanaf cyclus X begint het leger te lijden. Drie varianten, één kiezen:

**A. Honger (aanbevolen).** Vanaf cyclus X verliest elke speler aan het begin
van elke cyclus één pion, gekozen met een vaste deterministische regel: de pion
die het **verst van de vijandelijke haven** staat. De achterhoede verhongert
het eerst. Dat garandeert wiskundig dat het duel eindigt, en het duwt je bovendien
vooruit in plaats van achteruit. Thematisch is het de Russische veldtocht: niet
de vijand maakt je leger op, de winter doet dat.

**B. De haven wijkt.** Vanaf cyclus X daalt de haveneis van twee pionnen naar
één. Zachter, maar het kan de winst ineens te goedkoop maken, en het garandeert
niets: twee spelers die alle vijf de havenvakken bezet houden, blijven zitten.

**C. De winter.** Vanaf cyclus X krimpt het kaartbudget elke cyclus met 1 tot
een bodem van 3. Verdediging degradeert sneller dan aanval, dus de linies
breken. Elegant, maar traag en het garandeert het einde niet.

**Advies: A, eventueel met B als tweede trap** als de arena laat zien dat honger
alleen te lang duurt. A is de enige variant die het einde wiskundig afdwingt.

### C17: één regel, twee getallen

De uitputtingsklok vervangt de cycluslimiet in **beide** modi, precies zoals
`poolfactor` en de spawn-cap dat al doen:

| | campagne-duel | los potje |
|---|---|---|
| honger begint | late cyclus (voorstel: 15) | vroege cyclus (voorstel: 8) |
| tiebreak | bestaat niet | bestaat niet |
| cycluslimiet | bestaat niet | bestaat niet |

Er komt dus geen tweede economie bij: er verdwijnt er zelfs een knop.

*Praktische waarschuwing:* de cycluslimiet begrensde tot nu toe ook de looptijd
van arena- en fuzzruns. De doorvoereis van 5 partijen per seconde per core hangt
eraan. De hongercyclus voor het losse potje is dus niet alleen een balansgetal
maar ook je meetbudget: zet hem laag genoeg dat een nachtrun even veel partijen
haalt als nu, en meet dat expliciet voordat de knop vastligt.

### Waarom dit de campagne beter maakt

Dit is de afmaking van de C9-waarneming (bots wonnen vrijwel alleen via
tiebreak, dus ging de cycluslimiet eruit). Met P0 erbij geldt:

- **Elk duel is beslissend.** Er komt niemand halfdood terug. Wie de ring in
  gaat, komt eruit als winnaar of ligt eruit.
- **De raad wordt zwaarder.** Iemand nomineren is niet meer "hem laten bloeden"
  maar "hem laten sneuvelen".
- **Er komt een nieuw gespreksonderwerp.** Het aantal cycli staat in de depeche.
  "Bruno had negentien cycli nodig" betekent: hij heeft honger geleden, hij is
  op. Publieke informatie over verborgen kracht, gratis, zonder de mist op te
  heffen.

---

## 2. De vier kernmechanieken (V1-V4)

Zonder deze vier is de rest toneel. Ze delen een eigenschap: **ze voegen geen
sociale regel toe, ze maken bestaande regels zichtbaar of controleerbaar.**

### V1 — De zwarte stift (KERN)

**Het probleem: de mist is vandaag cosmetisch.** `cview.gd` toont pool en CP van
de vijand als `"?"` en geeft in dezelfde dictionary `"ledger":
c.ledger.duplicate(true)` mee, met het commentaar "publiek grootboek".
Startbezit, budgetbonus, donaties, inzet, verliezen, ruil en CP-winst zijn
allemaal ledger-regels. Wie kan optellen, reconstrueert **elk** verborgen saldo
exact. De bots doen dat vandaag al.

Er valt op dit moment dus letterlijk niets te bluffen over je bezit, en elke
leugen erover is met een optelsom te weerleggen.

**De redactie.** Van een niet-teamgenoot zie je **welke** gebeurtenis
plaatsvond, nooit het bedrag. Van je eigen team zie je alles (voorlopig, zie de
open vragen). Wat in de depeche staat, blijft voor iedereen volledig zichtbaar.

Voorbeeldregels uit het register van daden:

> Ronde 3: Ida heeft aan Bram geschonken.
> Ronde 3: Vera heeft CP geruild.
> Ronde 5: het spoor tussen Bruno en Vera loopt nu vier rondes.
> Ronde 6: het spoor tussen Bruno en Vera is verbroken.

**De boedelbeschrijving.** Wie valt, valt met open boeken. Op het moment van
uitvallen worden je bedragen met terugwerkende kracht volledig openbaar. Dat is
het spiegelbeeld van de bestaande regel dat wie dood is alles ziet, en het komt
precies op tijd voor de volgende nominatie.

> Otto is gevallen. Zijn boeken gaan open: 14 infanterie, 2 cavalerie,
> 0 artillerie, 9 CP. Nagelaten aan Vera (team Zuid): 7 infanterie, 4 CP.
> De rest verbrandt.
> Otto gaf in ronde 4 als parool: mijn reserve is ten hoogste 4. Gebroken.

**Twee waarschuwingen.** Te veel redigeren maakt het grootboek onleesbaar, en
dan opent niemand het meer, en dan is de enige harde informatiebron dood. En zet
een **drempel op vermelding**: "A heeft aan B geschonken" voor één soldaat wekt
argwaan uit ruis. Een verstopplek onder de drempel is geen bug maar een feature.

*Randvoorwaarde:* leak-canary in de testsuite die per ronde controleert dat een
vijandelijke view niet optelbaar is, in de lijn van de bestaande view-lektests.

*Let op:* de campagne-spec zegt nu nog dat het grootboek publiek is. Dit is dus
een expliciete herroeping, geen implementatiedetail.

### V2 — De klok en de grendel (KERN)

`crules.gd` heeft **geen enkele deadline-knop**. Voor bots is dat prima, want
die beslissen direct. Voor zestien mensen is het fataal: de ronde loopt op de
traagste speler, en er is geen sluitmoment.

Twee dingen tegelijk:

**De klok.** Deadlines als knoppen in `CRules`, zodat een groep uit dezelfde
regels een campagne van drie dagen of van drie weken kan draaien. Duren zijn
knoppen, geen constanten.

**De grendel.** Alles wat je indient blijft dicht tot de klok valt of iedereen
op klaar heeft gedrukt. Dat is precies de commit-gate die het duel al gebruikt.
De **blinde raadstemming** is dus geen apart idee, hij is de eerste toepassing
ervan: op dit moment zet `_do_nominate` je stem direct in de staat en geeft
`cview` de teamstemmen live door, dus de eerste stemmer maakt de kudde en de
laatste hoeft niet te gokken. Ook het donatievenster gaat blind en simultaan.

**Het zwijgregister.** `_do_tick` past de defaults al toe (niet gestemd wordt de
standaardkeuze, testament-timeout verbrandt alles) maar legt nergens vast **wie**
er zweeg. Dat is gratis informatie die nu weggegooid wordt. Stilte wordt een
zichtbare zet met een naam eronder.

> De raad sluit over 14 uur. Nog niet binnen: Ida, Otto, Vera.
> De stembriefjes zijn open. Bram stemde Otto tegen Vera. Ida stemde Otto tegen
> Karel. Vier stemmen voor Otto tegen Vera: dat duel gaat door.
> Ronde 5: de klok besliste voor Otto. Zijn stem ging naar de standaardkeuze.

**Eén harde ontwerpkeuze meteen vastleggen: verzuim krijgt nooit een economische
straf.** Een afwezige die ook nog verarmt, komt niet terug, en zijn team is de
rest van de campagne kreupel.

### V3 — De volle depeche (KERN)

`solo_driver.gd` rekent per duellist het veld `inzet` uit (de werkelijk ingezette
versterkingen per type) en `campaign_hub.gd` drukt alleen verliezen en cp_delta
af. **Het meest belastende getal van de hele campagne wordt berekend en
weggegooid.**

De depeche wordt een eigen gelogd stuk, voor iedereen identiek, met alleen
**stromen** en nooit **voorraden**: ingezette versterkingen per type, ingezette
CP en het hoogste enkele bod, verliezen, buit, cycli, winmethode.

> Depeche, ronde 4. Bram (Krokodil) tegen Otto (Beer). Winnaar Bram via de
> haven, 11 cycli.
> Bram zette in: 6 infanterie, 1 cavalerie, 0 artillerie. CP ingezet 7, hoogste
> enkele bod 4. Verloren: 4 infanterie. Buit: 1 vaandel (2 punten).
> Otto zette in: 12 infanterie, 2 cavalerie, 1 artillerie. CP ingezet 12,
> hoogste enkele bod 6. Verloren: 9 infanterie, 2 cavalerie. Buit: geen.

Dit is de leugendetector. "Ik ben blut, ik kan echt niets missen" naast een
depeche waarin twaalf versterkingen het veld op kwamen, is een publieke
ontmaskering die het spel gratis produceert.

*Harde grens:* stromen wel, saldi nooit. Anders heft de depeche de mist op.

### V4 — Het schaduwbracket (KERN)

`_seed_bracketronde` rekent de burgeroorlog-zaaiing nu al uit op roem, dan CP,
dan pool. Splits die functie in een pure `seed_volgorde(deelnemers)` en **teken
de burgeroorlog die vandaag zou ontstaan**, vanaf ronde 3, naast het
schenkpaneel.

Nul nieuwe regels, nul determinisme-risico, en waarschijnlijk het sterkste
voorstel in dit hele document. Zonder dit paneel moet een speler weken onthouden
dat zijn teamgenoten zijn finalisten zijn, en dan bestaat P3 voor hem niet.

Het schuift live mee terwijl je een donatie invult:

> Als jouw team vandaag zou winnen: eerste ronde Bram tegen Ida, Vera tegen
> Karel, Otto heeft de vrijloting. Jij staat vierde. Vorige ronde stond je
> derde: Vera schoof over je heen.

---

## 3. Het woord (bluf)

### V5 — Het parool

Vlak voor je duel dien je **blind en gelijktijdig** één zin in uit een **gesloten
lijst**. De depeche zet er achteraf zelf het oordeel bij. Geen scheidsrechter,
geen interpretatie, geen vrije tekst.

Zinnen uit de lijst:

- Ik zet dit duel hoogstens 3 versterkingen in.
- Ik zet dit duel geen enkele CP in.
- Ik win via de haven of ik win niet.
- Mijn reserve is minstens 8.
- Ik schenk deze ronde niets aan Vera.
- Ik stem Otto deze ronde niet het duel in.

> Parool Bram: ik zet hoogstens 8 versterkingen in. Nagekomen (7).
> Parool Otto: ik zet geen enkele CP in. Gebroken (12).

Dit is P1 in één knop, en het is scherper dan een losse belofte omdat het
**automatisch toetsbaar** is tegen een depeche die toch al gelogd wordt.

**Het merkteken moet vervagen.** Naast je naam komt één neutrale teller, "3
nagekomen, 1 gebroken", die na drie rondes uitdooft en **nooit over campagnes
heen reist**. Geen boete, geen roem, alleen het stempel. Een permanente
schandpaal is de snelste manier om iemand te laten afhaken.

### V6 — Het stemregister

Stemmen worden bewaard in plaats van weggegooid (`creducer.gd` doet nu
`c.nominatie_stemmen = {}`). Je eigen team ziet ze direct na de onthulling, de
rest van de wereld zodra het duel dat eruit voortkwam is gespeeld.

Zonder archief bestaat er geen bewijs, en zonder bewijs bestaat er geen verraad,
alleen gemopper.

**Open punt:** briefjes met naam volledig publiek onthullen lekt teamintentie
naar de vijand (die ziet wie jullie wilden sparen, en dus wie zwak staat), en
het levert permanente wrok op. Alternatief: **briefjes met naam alleen voor het
eigen team, de uitslag voor iedereen.** Ik neig naar het alternatief.

### V7 — De opengeslagen boeken

Eén ontsnappingsroute voor de eerlijke speler, anders wordt dit een spel van
louter wantrouwen. **Eén keer per campagne** mag je je exacte voorraad en CP
publiek laten afdrukken. Het kost je die ronde je recht om te geven én te
ontvangen.

Duur, en daarom geloofwaardig. Dit is de enige manier om jezelf te bewijzen, en
je kunt hem maar één keer gebruiken.

### V8 — De wilsbeschikking

Je testament ligt **altijd klaar**, is geheim, en je mag hem elke ronde
wijzigen. Iedereen ziet **dat** je hem wijzigde, niemand ziet **voor wie**. Hij
gaat pas open op de dag dat je valt.

Dit lost een echt async-probleem op dat vandaag in `_do_tick` zit: een gevallene
moet binnen een timer kiezen, en een gevallen mens komt vaak niet meer terug,
dus de hele ronde staat stil op een dode.

En het levert meteen het scherpste bluf-object van de campagne, want de reducer
staat een **vijand** als ontvanger nu al toe (`_do_testament` toetst alleen op
`status == "actief"`, niet op team). De publieke wijzigingsmelding zonder inhoud
is gratis dreiging: je verandert er niets aan en laat iedereen denken van wel.

> Otto heeft een wilsbeschikking klaarliggen. Laatst gewijzigd in ronde 5.
> Otto is gevallen. Zijn wilsbeschikking gaat open: 7 infanterie en 4 CP naar
> Vera, van team Zuid. De rest verbrandt.

---

## 4. Het kruit (samenwerken)

Schenken is nu een eenzijdig cadeau zonder tegenprestatie. Dat is geen
samenwerking maar liefdadigheid.

### V9 — Huurtroepen

**De motor zit al in de code:** `duel_spawn_totaal_max = 15` maakt alles wat je
daarboven hebt deze ronde **dood kapitaal**. En dood kapitaal dat bij iemand
anders wél kan werken, is de zuiverste reden om afhankelijk te worden.

Je leent maximaal 4 punten uit aan een vechtende teamgenoot. Ze verlaten jouw
grootboek niet: ze gaan als extra spawnruimte mee. Wat hij spawnt, boekt af bij
**jou** met reden `inzet_geleend`. Wat hij niet spawnt, keert automatisch terug.

**Er is geen automatische prijs.** Hij betaalt terug of niet, en de depeche laat
zien hoe hij jouw kruit heeft verbrand.

> Ida leent Bram 4 versterkingspunten voor zijn duel tegen Otto. Ze blijven van
> Ida.
> Depeche, ronde 6: Bram zette 3 geleende punten in, geleend van Ida. Eén punt
> keerde terug.

Dit vervangt zowel de gezamenlijke inzet als de voorwaardelijke schenking uit
een eerdere versie van dit document: het is concreter, het hangt aan een cap die
al bestaat, en het verraadmoment zit er gratis in.

### V10 — De schatplicht

Een staande afdracht die elke ronde vanzelf loopt zonder dat iemand hoeft te
klikken, met één ronde publieke opzegtermijn.

**Het enige samenwerkingsmechaniek dat werkt terwijl je offline bent**, en
daarmee het enige dat een async campagne echt draagt. Harde koppeling: staat de
betaler in het zwijgregister, dan stopt de afdracht vanzelf.

> Vera zegt haar schatplicht aan Karel op. De afdracht van deze ronde loopt nog,
> daarna stopt hij.

### V11 — Bewaargeving

Punten stallen bij een teamgenoot om ze boven de duelcap te parkeren, met
automatische teruggave bij stilte en een **publieke weigering** als enige manier
om ze te houden.

*Verplichte fix bij invoering:* bewaring telt gewoon mee voor de uitvalsconditie
C3. Anders kegelt deze knop spelers zonder waarschuwing uit de campagne.

### V12 — De monstering

Eén verplichte gift van precies één punt aan precies één teamgenoot in ronde 1,
blind ingediend en gelijktijdig onthuld.

Er ligt dan een **sociogram** op tafel voordat de eerste pion valt. Wie koos
wie, en wie koos niemand die hem terugkoos. Dat is een gespreksonderwerp voor de
hele campagne, voor de prijs van één punt.

### V13 — Eén ontvanger per ronde

Met zeven teamgenoten is doneren nu een invuloefening: je verdeelt wat en
iedereen krijgt iets. Met **precies één ontvanger per ronde** is elke schenking
een publieke voorkeursverklaring, en zijn er zes mensen genegeerd.

*Dit draait C9 gedeeltelijk terug (doneren aan elke levende teamgenoot), dus dit
is een besluit voor Max en niet voor mij.* Het is wel het enige voorstel in dit
document dat spanning toevoegt door iets **weg** te halen.

---

## 5. De afrekening

### V14 — De rekening van de burgeroorlog

Op de dag dat de burgeroorlog begint, rekent het spel hardop voor wie wie heeft
volgeladen. Pure presentatie van gegevens die de reducer al tweezijdig boekt,
met precies het juiste onthullingsmoment: geen ronde eerder, zodat je tijdens de
teamfase kunt blijven doen alsof je gulheid vanzelfsprekend is.

> De burgeroorlog begint. Wat jullie elkaar gaven: Ida naar Bram 22 punten en
> 6 CP. Bram naar Ida 4 punten. Netto ontvangen: Bram 18, Karel 9, Vera 0.
> Eerste duel: Ida tegen Bram. Jij bewapende hem met 22 versterkingen en 6 CP.

### V15 — De bruidsschat

Nu verbrandt de bracketverliezer volledig (`_verbrand_alles`) en is de finale
bewust kaal. Laat hem in plaats daarvan een vast, gecapt deel nalaten aan een
nog levende pretendent naar keuze, en **nooit aan degene die hem zojuist
versloeg**.

Dan krijgt elke bracketronde een onderhandeling ervoor.

### V16 — Het slotscherm en de kroniek

Een spel over verraad dat eindigt met "je hebt gewonnen" heeft zijn eigen
onderwerp weggegooid. Bij het kronen opent een scherm dat de kampioen **niet kan
overslaan**: op volgorde van overlijden elke gevallen speler, met precies één
boeking die hem met de kampioen verbindt. Alleen feiten, geen bijvoeglijke
naamwoorden.

> Otto, gevallen in ronde 4. Jij stemde hem twee keer het duel in. Hij gaf jou
> nooit iets.
> Ida, gevallen in ronde 7. Zij gaf jou 22 versterkingen en 6 CP. Jij gaf haar
> 4 punten terug.
> Karel, gevallen in ronde 9. Tussen jullie is nooit iets geboekt.
>
> Wijs één gevallen speler aan zonder wie je het niet had gehaald.
> "Niemand" is een geldig antwoord.

Daaronder **de kroniek**: één bestand in gewone taal, opgebouwd uit vaste zinnen
en dus reproduceerbaar uit hetzelfde log, dat je in de groepsapp plakt. Regel die
het leesbaar houdt: een ronde komt er alleen in als er iets **onherroepelijks**
gebeurde. Rondes waarin niets brak krijgen één regel of niets, en die stilte is
zelf informatie.

---

## 6. Zestien mensen, weken lang

### V17 — Terugtrekking met eer

Eerlijk afwezig zijn moet altijd goedkoper zijn dan verdwijnen. Je mag je
terugtrekken uit een ronde: het kost je het duel, maar **niet je voorraad**. De
tegenstander krijgt de volle winst, zodat het ontwijken van een slechte matchup
duur blijft. Beperkt aantal per campagne.

> Otto trekt zich terug uit ronde 5. Vera krijgt de volle winst, Otto houdt zijn
> voorraad. Otto heeft nog één terugtrekking over.

### V18 — De stadhouder

Je wijst vooraf zelf een teamgenoot aan die namens jou stemt als je er niet
bent. Publiek, en te wijzigen.

Dat is meteen een vertrouwenskeuze met tanden: je geeft iemand je stem in de
raad die straks je finalist is.

> Otto is een week weg. Zijn stadhouder Bram stemde namens hem: Otto tegen
> Karel.

### V19 — De gunst van de doden

Van alle mogelijke dodenrollen precies één, en de kleinste. Alle uitgevallen
spelers samen stemmen per ronde over **één vast, klein cadeau** (bijvoorbeeld
twee CP) aan één levende speler van welk team dan ook. Publiek. Bij staking
verbrandt het.

Zo wordt uitvallen een rolwissel in plaats van een exit, zonder dat mensen die
niets meer te verliezen hebben de campagne kunnen beslissen.

*Voorwaarde vooraf:* hak de knoop door over wat doden mogen **zien**.
`mag_saldo_zien` geeft ze nu alles, terwijl het masterplan (F5.2) zegt dat ze de
publieke view krijgen. Een alwetende dode met stemrecht is de sterkste
informatiehandelaar in het spel.

---

## 7. Hoe dit met bots werkt

De sleutel: de bot-persoonlijkheden hebben de knoppen al.

**`loyaliteit` wordt de kans dat een bot zijn woord houdt.** Die waarde staat al
in alle acht archetypes: de trouwe generaal op 1,0 breekt nooit een parool, de
rat op 0,1 breekt er bijna elk. Eén regel betekenis erbij en de hele
beloftelaag speelt in solo, zonder nieuwe data.

En er is een dode knop: `concentratie` staat in alle acht profielen en wordt
nergens gelezen. Die is vrij voor wrok en dankbaarheid.

| Voorstel | Wat de bot doet in solo |
|---|---|
| V0 geen gelijkspel | Raakt de bots het hardst van alles. Hun huidige waardefunctie kent "overleven tot de limiet" als geldige uitkomst; die verdwijnt. Bots moeten hertraind op een fitness met alleen haven, eliminatie en verlies, en ze moeten de honger meewegen. **Dit is de enige regel in dit document die een trainingsronde vraagt.** |
| V1 zwarte stift | **Verplicht tegelijk te bouwen met een schatter** (laatst geziene waarde, verstreken rondes, wat er in depeches stond). Bots die exacte saldi kennen maken de mist zinloos, en dan is de mist een straf voor de mens. |
| V2 klok en grendel | Bots dienen direct in; de grendel wacht alleen op mensen. Het zwijgregister blijft in solo leeg, en dat is eerlijk: het gaat daar alleen over jou. |
| V3 depeche | Geen botgedrag, wel botgebruik: de bot voedt zijn schatter met de inzet uit depeches. |
| V4 schaduwbracket | Weergave. Bots wegen hun eigen bracketpositie mee bij schenken (nieuw gewicht, default 0, aan te zetten na meting). |
| V5 parool | Bot kiest een parool uit zijn archetype en houdt het met kans `loyaliteit`. **Hier woont de bluf in solo.** |
| V6 stemregister | Bot weegt "wie stemde mij het duel in" mee via `concentratie`. |
| V7 opengeslagen boeken | De strateeg doet het als hij sterk staat en vertrouwen wil kopen. De rat nooit. |
| V8 wilsbeschikking | Bot houdt er een klaarliggen en wijzigt hem naar archetype. Die van de rat wijst naar de vijand. |
| V9 huurtroepen | Bot leent uit zodra hij dood kapitaal boven de cap heeft (zuivere rekensom, dus een goede leermeester) en betaalt terug met kans `loyaliteit`. Precies hier besteelt de rat je. |
| V10 schatplicht | Bot accepteert naar `vrijgevigheid` en zegt op zodra hij arm wordt. |
| V11 bewaargeving | Bot geeft in bewaring bij wie hij zelf betrouwbaar acht, en geeft terug met kans `loyaliteit`. |
| V12 monstering | Bot kiest naar archetype, en dat maakt het sociogram in solo net zo leesbaar als online. |
| V13 één ontvanger | Dwingt de bot te kiezen, waardoor zijn persoonlijkheid zichtbaar wordt. Winst voor solo. |
| V14, V15, V16 | Presentatie; geen botgedrag nodig. |
| V17 terugtrekking | Bot trekt zich nooit terug. Dit is een mens-affordance, en dat is prima. |
| V18 stadhouder | Bots hebben er geen nodig, maar een bot **kan** jouw stadhouder zijn en stemt dan naar zijn eigen gewichten. Je keuze van stadhouder wordt zo een weddenschap op een karakter. |
| V19 gunst van de doden | Dode bots stemmen naar archetype. |

### Het punt dat je moet onthouden over bots

**Tegen bots ben jij de enige die kan liegen.** In solo is de vraag dus niet
"wie liegt hier", maar "hoever kan ik gaan en wat kost het me". Dat is een
legitiem en leerzaam spel, maar het is een ander spel.

Er is één plek waar bots overtuigend "liegen" zonder dat je liegen hoeft te
programmeren: zodra ze onder V1 alleen nog een **schatting** van andermans
kracht hebben, zeggen ze dingen die simpelweg niet kloppen. Een bot die oprecht
ongelijk heeft, is aan tafel niet te onderscheiden van een bot die bedriegt.

---

## 8. Wat er uitdrukkelijk NIET in moet

Overwogen en afgevallen. Ze staan hier zodat ze niet opnieuw worden voorgesteld.

**Geschrapt zonder discussie.** De mol, de plaatsvervanging, het brandmerk op de
erfgenaam, de rouwveiling, de jury van de gevallenen, de dodenkamer, de
onthulling door de doden, de erfopvolging, de erelijst van het gebroken woord,
het gokboek, de schaduwmarkt, vazalschap bij stilte, de gedwongen kas, overlopen
naar het andere team, asiel, en de vete-rol.

De rode draad in die stapel: ze geven macht aan mensen die niets meer te
verliezen hebben, of ze maken van één speler wekenlang een paria, of ze bouwen
een kanaal waarmee je je eigen duel kunt weggeven.

**Verder afgevallen, met de reden erbij:**

- **Roemstraf op een gebroken parool.** Botst frontaal met P1, en het raakt de
  burgeroorlog-zaaiing en dus de goldens. Het merkteken doet het werk al.
- **Vrije tekst in welke vorm dan ook** (spreekbeurt, brieven, citaatknop,
  doorgestuurde berichten). Vraagt vanaf dag één om melden, blokkeren en
  moderatie. Het spel is notaris, geen chatprogramma. Gesloten zinnenlijsten
  doen wat nodig is.
- **Geheime opdrachten en verzegelde bevelen.** Technisch klopt commit-reveal
  met zout prima, maar in een campagne van wéken is een fout vermoeden geen
  twintig minuten ongemak maar vier dagen, en wie eenmaal als verrader is
  weggezet, haakt af. Dit was in een eerdere versie van dit document nog een
  hoofdvoorstel; de tegenspraak heeft me overtuigd.
- **Borgtocht, onderpand, compagnie en weddenschappen.** Het meest waarschijnlijke
  recept voor analyseverlamming per ronde, en weddenschappen openen een kanaal om
  je eigen duel weg te geven dat met Discord ernaast niet dicht te timmeren is.
- **De gekochte stem** en **het recht van de armste.** Allebei een extra
  stemronde in de fase die in async al het duurst is, en de eerste levert
  precies de sneeuwbal op die het masterplan als risico noemt.
- **Cross-team doneren.** Blijft verboden. Maar schrijf het onderliggende
  probleem wel op: twee vrienden in verschillende teams spreken tóch af, en
  vandaag is die afspraak gratis, onzichtbaar en beslissend. We kiezen bewust om
  dat niet te legaliseren, niet omdat het niet gebeurt.
- **De tribune** (live meekijken bij andermans duel) en **de secondant**. Het
  enige idee dat aanpakt dat zestien mensen om beurten solitaire spelen, maar
  coaching is niet te verhinderen met Discord ernaast en tijdzones maken een
  aangekondigd venster oneerlijk. Experiment, geen fundament. Bewaren tot de
  rest staat.

---

## 9. Volgorde van bouwen

**Blok 0, de regel.** Als eerste en helemaal apart, want alles erna wordt eraan
gemeten.

0. **V0 geen gelijkspel plus de uitputtingsklok.** De enige echte regelwijziging
   in dit document: versiebump, CHANGELOG, goldens opnieuw, arena-meting op
   partijduur, bots hertrainen. Doe hem helemaal af voordat er een sociale regel
   bij komt, anders weet je bij de eerste balansverrassing niet waar hij vandaan
   komt.

**Blok 1, de vier kernmechanieken.** Zonder deze vier is de rest decor.

1. **V1 de zwarte stift** plus het register van daden plus de leak-canary.
2. **V2 de klok en de grendel**, met blinde nominatie en het zwijgregister als
   bijvangst. De goedkoopste echte winst in het hele document.
3. **V3 de volle depeche.** Het `inzet`-veld ophalen dat al berekend wordt.
4. **V4 het schaduwbracket vanaf ronde 3.** Nul regels, nul risico,
   waarschijnlijk het sterkste voorstel dat er ligt.

**Blok 2, het woord.** Nu valt er iets te zeggen en te breken.

5. **V5 het parool** (het eerste dat de depeche tot spel maakt), **V6 het
   stemregister**, **V8 de wilsbeschikking**.

**Blok 3, het kruit.**

6. **V9 huurtroepen**, **V10 de schatplicht**, **V12 de monstering**.

**Blok 4, de afrekening.**

7. **V14 de rekening van de burgeroorlog**, **V16 het slotscherm en de kroniek**,
   **V15 de bruidsschat**.

**Blok 5, het onderhoud.** V17, V18, V19, V7, V11, V13.

---

## 10. Testgevallen (contractvorm, zelfde stijl als campagne-spec §7)

| Regel | Testgeval |
|---|---|
| Een duel eindigt nooit anders dan op haven of eliminatie | `test_geen_gelijkspel` |
| `winner == -1` is onbereikbaar (gefuzzd over N staten) | `test_geen_remise_canary` |
| Puntentabel kent geen tiebreak-trede meer | `test_punten_zonder_tiebreak` |
| Opgeven telt voor de winnaar als eliminatie | `test_resign_tarief` |
| Noodstop bereikt = harde fout, geen uitslag | `test_noodstop_is_fout` |
| Honger begint pas op de ingestelde cyclus | `test_honger_startcyclus` |
| Honger kiest de pion het verst van de vijandelijke haven | `test_honger_keuze` |
| Honger is deterministisch bij gelijke afstand | `test_honger_deterministisch` |
| Twee passieve spelers eindigen altijd binnen N cycli | `test_turtle_termineert` |
| Los potje en campagne-duel: zelfde regel, ander getal | `test_honger_c17_schaal` |
| Grootboek redigeert bedragen van niet-teamgenoten | `test_ledger_redactie` |
| Roem blijft publiek na redactie | `test_roem_publiek` |
| Geen vijandelijke view is optelbaar tot een saldo (gefuzzd) | `test_campagne_leak_canary` |
| Boeken gaan open bij uitvallen, met terugwerkende kracht | `test_boedelbeschrijving` |
| Gift onder de vermeldingsdrempel verschijnt niet in het register | `test_register_drempel` |
| Alles blijft dicht tot de grendel valt | `test_grendel_blind` |
| Nominatie is blind tot alle stemmen binnen zijn | `test_nominatie_blind` |
| Zwijgen wordt geregistreerd met naam | `test_zwijgregister` |
| Verzuim kost nooit bezit | `test_verzuim_geen_straf` |
| Depeche toont stromen, nooit saldi | `test_depeche_geen_saldo` |
| Depeche is identiek voor elke kijker | `test_depeche_uniform` |
| Parool wordt automatisch getoetst tegen de depeche | `test_parool_oordeel` |
| Parool verandert nooit een saldo of roem | `test_parool_geen_effect` |
| Merkteken dooft uit na 3 rondes | `test_merkteken_vervaagt` |
| Stemregister blijft bewaard | `test_stemregister_bewaard` |
| Vreemd team ziet stemverslag pas na het duel | `test_stemregister_vrijgave` |
| Opengeslagen boeken: 1 per campagne, kost geef- en ontvangrecht | `test_open_boeken` |
| Wilsbeschikking blijft geheim tot de val | `test_wilsbeschikking_geheim` |
| Wijziging is publiek zichtbaar, inhoud niet | `test_wilsbeschikking_melding` |
| Huurtroepen: ongebruikte punten keren automatisch terug | `test_huurtroepen_retour` |
| Huurtroepen: gespawnd boekt af bij de uitlener | `test_huurtroepen_afboeking` |
| Niet terugbetalen is legaal | `test_huurtroepen_geen_afdwinging` |
| Schatplicht stopt bij zwijgen van de betaler | `test_schatplicht_stopt` |
| Bewaring telt mee voor de uitvalsconditie C3 | `test_bewaring_c3` |
| Bruidsschat kan nooit naar de winnaar van dat duel | `test_bruidsschat_uitsluiting` |
| Bot houdt parool met kans loyaliteit, deterministisch per seed | `test_bot_parool_seed` |
| Bot met geredigeerd grootboek gebruikt de schatter | `test_bot_schatter` |
| Oude campagne-logs folden ongewijzigd (alle nieuwe velden default) | `test_compat_pre_v` |

---

## 11. Open vragen voor Max

0. **Welke uitputtingsklok, en vanaf welke cyclus?** Honger, wijkende haven of
   winter (§1b). Advies: honger. En telt opgeven voor de winnaar als eliminatie?
   Dit blokkeert blok 0 en dus alles erna.

1. **Zien teamgenoten elkaars saldo?** `mag_saldo_zien` zegt vandaag ja. Je
   vijand kom je één keer op een bord tegen; je teamgenoot is je finalist. Dat is
   de enige persoon tegen wie liegen érgens over gaat. Maar volledige
   ondoorzichtigheid maakt coördineren onmogelijk, en de bestaande stakingsregel
   (kleinste pool beslist) draait dan op informatie die niemand meer heeft. **Dit
   is de vraag waar de hele bluf-laag op staat of valt.** Advies: één campagne
   lang naast de huidige regel meten voordat je hem beantwoordt.

2. **Hoe smal mag de mist?** Zodra het grootboek geredigeerd is, leiden de
   rekenaars alsnog een marge af en de rest niet, en dan is hoofdrekenen een
   vaardigheid geworden. De bandbreedte wel of niet expliciet tonen is een echte
   keuze, en de gemiddelde marge per ronde hoort een arena-metriek te worden.

3. **Wat mogen de doden zien?** `CView` geeft ze alles, het masterplan (F5.2)
   zegt de publieke view. Deze knoop moet los vóórdat V19 gebouwd wordt.

4. **Hoeveel beslissingen per ronde kan een mens dragen?** Mijn schatting is
   drie: met wie vecht ik, aan wie geef ik, en één sociale zet. Alles daarboven
   wordt overgeslagen, en dan draagt het spel wel de complexiteit maar krijgt het
   niet de spanning. Meetbaar: alarm zodra meer dan een kwart van de zetten per
   ronde uit `TICK_DEADLINE`-defaults bestaat.

5. **Is roem de juiste munt voor sociale mechanieken?** Roem raakt de economie
   niet, maar stuurt wel de burgeroorlog-zaaiing. Als beloftes en voorspellingen
   allemaal in roem betalen, verschuift het optimale spel van goed duelleren naar
   netjes boekhouden, en devalueert het bord.

6. **Halveren de donaties door het schaduwbracket (V4)?** Als niemand nog aan de
   sterkste teamgenoot geeft, verliest dat team van het andere en komt er nooit
   een burgeroorlog. Meet donaties per ronde tegen het aantal overlevende
   teamleden, voor en na invoering.

7. **Gaat V13 (één ontvanger per ronde) door?** Dat draait C9 gedeeltelijk terug.

---

## 12. Eén werkafspraak die ik erbij zou vastleggen

Elk aangenomen mechaniek landt als knop in `CRules` die **default UIT** staat,
precies zoals het `campaign`-blok dat nu doet, plus een teller in het grootboek:
hoeveel verschillende levende spelers raakten deze actie deze ronde aan.

Na twee volle campagnes komt die lijst op tafel en gaat eruit wat niemand
gebruikt, code en al. Uitzetten wordt daarmee net zo goedkoop als aanzetten, en
de golden replays blijven werken omdat oude logs hun eigen knoppen in de
begin-snapshot meedragen.

**Uitzondering die je vooraf moet maken:** alles wat maar één keer per campagne
kan (een testament, een terugtrekking, opengeslagen boeken) haalt zo'n
gebruiksdrempel nooit, terwijl juist de zeldzaamheid het waardevol maakt. Meet
dus per **keuzemoment**, niet per actie.

---

*Voorstel opgesteld 3 augustus 2026, herzien na een tweede ontwerpronde met
tegenspraak. Bronnen: `docs/campagne-spec.md` (C1-C17), `docs/spelregels-v4.2.md`
(Deel B), `MASTERBOUWPLAN.md` F3 t/m F7, `core/campaign/`,
`agents/campaign/personalities.gd`, `scripts/game/solo_driver.gd`,
`scripts/ui/campaign/campaign_hub.gd`. Nog niets besloten en nog niets gebouwd.*
