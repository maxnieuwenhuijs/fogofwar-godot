# Fog of War — Spelregels v4.1: Vuurlijnen & Melee

Deze versie **vervangt v4**. Enige wijziging: het infanterieschot gaat niet langer over een tussenliggende pion heen — **vuur wordt nu zonder uitzondering geblokkeerd**. Verder bouwt alles voort op `game_description.md` (v1); wat hier niet expliciet wordt gewijzigd, blijft gelden zoals in v1 beschreven.

**Kern.** Elke pion heeft een vast **eenheidstype** (Infanterie, Cavalerie, Artillerie) dat bepaalt wat de kaart-stats betekenen. Infanterie kan schieten op afstand 2 over open grond. Artillerie schiet in vrije rechte lijnen zover als zijn Speed draagt. Vuur raakt **alles**, ook niet-geactiveerde pionnen — maar dekking is fysiek en absoluut: elke tussenliggende pion blokkeert elke vuurlijn. Alleen wat vrij zicht heeft, kan geraakt worden. Kaarten blijven typeloos; daarbovenop kiest elke speler vóór de partij een vaste **doctrine** (asymmetrisch, niet wisselbaar).

---

## 1. Speltype en Doel

- **Type:** 2-speler, asymmetrisch tactisch bordspel met kaart-gedreven pion-activatie.
- **Doel (primair):** wees de eerste die 2 eigen pionnen in de doelhavens aan de overkant heeft staan.
- **Doel (secundair):** elimineer alle pionnen van de tegenstander. Let op: het totale aantal pionnen verschilt per doctrine.

## 2. Componenten

### 2.1 Spelbord

Ongewijzigd t.o.v. v1: een 11×11 speelveld; per speler 5 doelhavens aan de overzijde (de 3 centrale randvakjes plus de 2 bijbehorende hoekvakjes).

### 2.2 Pionnen

- Aantal en samenstelling per doctrine (§6). Referentie (Mens): 22 pionnen — 13 Infanterie, 6 Cavalerie, 3 Artillerie.
- Elke pion heeft een **vast type**, voor beide spelers zichtbaar gedurende de hele partij.
- **Opstelling is vrij** binnen de twee thuisrijen. Beide spelers stellen blind en gelijktijdig op; de opstellingen worden samen onthuld vóór Cyclus 1. Doctrines met minder dan 22 pionnen kiezen zelf welke thuisvakken leeg blijven.
- De vaste v1-startopstelling vervalt.

### 2.3 Kaarten

- Structuur ongewijzigd: 3 stats (HP, Speed, Attack), elke stat **minimaal 1**, som **exact het kaartbudget** van je doctrine. Mens: 7 (1/1/5 geldig; Muis-extreem 1/1/3, Leeuw-extreem 1/1/7).
- **Geen aparte maximum-cap per stat** buiten "min 1, som = budget". (Uitzondering: Beer, §6.4.)
- Elk doctrinebudget is **minimaal 4** (vereiste van de initiatief-formule, §4.3-B).
- Kaarten zijn **typeloos**: elke kaart kan aan elk eigen pion-type gekoppeld worden. De betekenis van de stats volgt uit het type (§3).
- Het aantal te definiëren kaarten per setup-ronde verschilt per doctrine (Mens: 3).

## 3. Eenheidstypes

### 3.0 Algemene principes

1. Het type is een eigenschap van de **pion**; de kaart is typeloos.
2. Typeregels gelden **alleen voor actieve pionnen**. Inactieve pionnen hebben geen stats en geen typevoordelen.
3. **Vuur raakt alles wat het kan zien** — ook inactieve pionnen. Een inactieve pion wordt geëlimineerd door elke treffer met schade > 0 (de v1-regel, veralgemeend naar afstand).
4. **Vuur wordt geblokkeerd — zonder uitzondering:** elke tussenliggende pion (eigen of vijandelijk) blokkeert elke vuurlijn volledig. Dekking is fysiek: wat achter een andere pion staat, is voor elk schot onraakbaar. Alleen de voorste laag staat bloot.
5. **Vuur wint geen terrein:** afstandseliminaties verplaatsen niemand; het vrijgekomen vak blijft leeg. Alleen beweging en melee (met zijn verplichte verplaatsing) veroveren vakken.
6. Alle aanvallen (melee en vuur) werken orthogonaal: zelfde rij of zelfde kolom.
7. De schaar: **Artillerie > Infanterie** (dracht 3–5 tegen 2), **Infanterie > Cavalerie** (terugslag op contact), **Cavalerie > Artillerie** (dode zone induiken, buiten de vuurlijnen aansluipen, bewegen + doden in één actie — en elke pion die je passeert blokkeerde toch al het schot).

### 3.1 Infanterie

Eén actie = bewegen, melee-aanval **óf** schot.

- **Bewegen:** maximaal `Speed` stappen, orthogonaal, volgens de v1-bewegingsregels.
- **Melee (afstand 1):** aanval op een direct aangrenzende vijandelijke pion, volle `Attack`, volgens de v1-regels inclusief de verplichte verplaatsing na een eliminatie. Inactieve verdedigers worden geëlimineerd bij Attack > 0.
- **Schot (afstand exact 2):** beschiet een vijandelijke pion (actief óf inactief) op precies 2 vakjes in een rechte orthogonale lijn; **het tussenliggende vak moet leeg zijn** (§3.0-4).
  - Schade: `Attack − 1`. Een pion met Attack 1 kan dus niet schieten (0 schade is geen geldige actie); een inactief doelwit vereist om dezelfde reden Attack ≥ 2.
  - Geen verplaatsing bij eliminatie; het vak blijft leeg. Lokt nooit terugslag uit.
  - Dit is de **standoff-prikker**: het gat van één vak tussen twee linies is de klassieke wie-stapt-eerst-positie, en het schot is daar het antwoord op — chippen op afstand 2 zonder de melee-klap en terugslag van het contact te riskeren.
- **Terugslag:** wordt een **actieve** infanteriepion in **melee** aangevallen en **overleeft** hij (HP > 0), dan krijgt de aanvaller onmiddellijk **1 schade**.
  - Alleen tegen melee (Infanterie of Cavalerie), nooit tegen beschietingen.
  - Altijd exact 1 schade, ongeacht de eigen Attack-stat.
  - Kost geen actie; `hasActedThisCycle` blijft onaangeraakt.
  - Sterft de verdediger, dan is er géén terugslag — wederzijdse eliminatie via terugslag bestaat niet.
  - Zakt de aanvaller door terugslag naar HP ≤ 0, dan wordt hij verwijderd; direct daarna volgt de win-check.

### 3.2 Cavalerie

- **Charge (één actie):** beweeg 0 t/m `Speed` stappen (v1-bewegingsregels) en voer daarna optioneel één melee-aanval uit op een aangrenzende vijand.
  - **Charge-minimum:** de actie is alleen geldig als er minstens 1 stap wordt gezet **óf** een aanval wordt uitgevoerd. "0 stappen en geen aanval" bestaat niet — passen bestaat in dit spel nergens.
  - Volgorde ligt vast: eerst bewegen, dan aanvallen — nooit andersom.
  - Elimineert de charge de verdediger, dan geldt de verplichte verplaatsing naar het vrijgekomen vak; daarna eindigt de actie. Totale verplaatsing kan dus `Speed + 1` zijn — de dreigingszone van een verse cavalerist is één vak groter dan zijn Speed.
  - Terugslag van infanterie werkt gewoon tegen een charge.
- Cavalerie kan **niet schieten**. Melee is zijn hele bestaan: de jager die vuurlijnen oversteekt, dode zones induikt en samen met infanterie als enige terrein wint.

### 3.3 Artillerie

Eén actie = 1 stap bewegen **óf** schieten, nooit beide.

- **Bewegen:** maximaal **1 stap**, ongeacht de Speed-stat.
- **Schieten:** beschiet een vijandelijke pion (actief óf inactief) in een rechte orthogonale lijn op afstand **2 t/m `Speed`** (dracht = Speed).
  - **Vrije vuurlijn vereist:** álle tussenliggende vakken moeten leeg zijn (§3.0-4).
  - Schade: volle `Attack`. Actieve verdediger: HP −= Attack, eliminatie bij ≤ 0. Inactieve verdediger: eliminatie (Attack is altijd ≥ 1).
  - Geen verplaatsing bij eliminatie; het vak blijft leeg. Lokt nooit terugslag uit.
  - **Dode zone:** afstand 1 is nooit beschietbaar. Een vijand pal naast het kanon is onaantastbaar voor dit kanon; wegstappen (1) of een ander doelwit binnen dracht beschieten kan wel.
- Dracht en schade concurreren binnen hetzelfde kaartbudget: een 1/5/1 is een verre prikker (dracht 5, schade 1), een 1/2/4 een kort zwaar kaliber, een 1/3/3 de allrounder. De kaartdefinitie is daarmee óók een artilleriekeuze.
- Kanonnen hebben **schootsveld** nodig: zet ze op flanken, vooraan, of laat bewust vuurlanen open in je opstelling — de vrije opstelling (§2.2) is hiervoor je gereedschap.
- Een kaart met Speed 1 op artillerie kan niet schieten (dracht 1 < minimum 2) en alleen 1 stap bewegen — geldige maar zwakke koppeling; zie de knop in §8.

## 4. Spelverloop

### 4.1 Pre-game

1. Beide spelers kiezen **blind en gelijktijdig** een doctrine (§6). De keuze staat vast voor de hele partij.
2. Doctrines worden onthuld.
3. Beide spelers stellen **blind** hun pionnen op binnen hun twee thuisrijen (§2.2).
4. Opstellingen worden onthuld; Cyclus 1 begint.

*Variant:* draft-keuze (speler 2 kiest ná speler 1); zie §8.

### 4.2 Start van een Cyclus

Ongewijzigd t.o.v. v1: ontkoppelen, statusreset, start Setup Ronde 1.

### 4.3 Setup Ronde (3× per cyclus)

**A. Kaartdefinitie** — als v1, met twee aanvullingen:

- Aantal kaarten en budget per kaart volgen uit je doctrine (§6).
- Beer: Speed mag bij definitie maximaal 3 zijn; de +1 HP wordt pas bij koppeling toegepast (§6.4).

**B. Onthul & Initiatief** — de v1-vergelijking op totale Attack is vervangen door een **bod-percentage**, zodat doctrines met verschillende budgetten en kaartaantallen tegen elkaar kunnen bieden:

```
vrije punten per kaart = budget − 3          (elke kaart draagt verplicht 1/1/1)

AttackBod = (Σ Attack − aantal kaarten) / (aantal kaarten × (budget − 3))
```

- Hoogste AttackBod krijgt het initiatief.
- **Tiebreak 1:** dezelfde formule op Speed. **Tiebreak 2:** de v1-regels (Ronde 1 van Cyclus 1: Speler 1; anders de vorige initiatiefhouder).
- Bij gelijke budgetten wiskundig identiek aan totale Attack vergelijken — spiegel-matchups gedragen zich exact als v1.
- IJkpunten (alles-op-attack = 100% bij elke doctrine): Muis 4×(1/1/3): (12−4)/(4×2) = 100%; Mens 3×(1/1/5): (15−3)/(3×4) = 100%; Leeuw 2×(1/1/7): (14−2)/(2×6) = 100%.
- UI-suggestie: toon het bod als percentage ("bod: 67%").

**C. Koppelen** — als v1, met vier aanvullingen:

1. Kaarten zijn typeloos: elke kaart mag op elke eigen pion die deze cyclus nog geen kaart heeft. Pas bij de koppeling ontstaat de betekenis — dezelfde 1/5/1 is een sprinter op cavalerie en een verre prikker op artillerie.
2. **Ongelijke kaartaantallen** (bv. Muis 4 vs Leeuw 2): om de beurt koppelen vanaf de initiatiefhouder; is één speler klaar, dan koppelt de ander zijn resterende kaarten achter elkaar. De staartkoppelaar ziet daarbij alle vijandelijke koppelingen — bewust informatievoordeel.
3. Kan een kaart aan geen enkele geldige pion meer gekoppeld worden, dan vervalt hij voor deze ronde. Het aantal te definiëren kaarten blijft ook in het late spel gelijk; overtollige kaarten vervallen gewoon.
4. Doctrine-hooks: de Vos koppelt gedekt (§6.6); Beer-pionnen krijgen bij koppeling `currentHP = HP-stat + 1` (§6.4).

### 4.4 Actiefase

- De initiatiefhouder van Ronde 3 begint (v1).
- Per beurt: kies één actieve pion die deze cyclus nog niet gehandeld heeft en voer **één actie** uit volgens zijn type:
  - **Infanterie:** bewegen, melee **óf** schot (afstand 2, vrije lijn).
  - **Cavalerie:** charge (bewegen + optionele melee; minstens één van beide).
  - **Artillerie:** 1 stap bewegen **óf** schieten (dracht = Speed, vrije lijn).
- Schade en eliminatie volgens v1, aangevuld met terugslag (§3.1) en de vuurregels (§3.0-3/4).
- De **verplichte verplaatsing** naar een vrijgekomen vak geldt uitsluitend bij **melee**-eliminaties.
- Win-check na elke actie, inclusief eliminaties door terugslag.
- **Geen geldige actie (skip):** heeft de speler aan de beurt met geen enkele nog niet gehandelde actieve pion een geldige actie (bv. volledig ingesloten pionnen), dan gaat de beurt over naar de tegenstander zonder dat er iets gebeurt. Pionnen worden daarbij níét als gehandeld gemarkeerd: ontstaat er later in de cyclus ruimte, dan mogen ze alsnog handelen.
- Beurtwissel verder als v1: de beurt gaat pas terug zodra de ander geen geldige actie heeft — dit dekt automatisch de ongelijke activatie-aantallen tussen doctrines.

### 4.5 Resetfase

- **Trigger (aangescherpt t.o.v. v1):** de Resetfase begint zodra **geen van beide spelers** nog een geldige actie kan uitvoeren met een actieve, nog niet gehandelde pion — door handelen, eliminatie óf het ontbreken van legale zetten. Dit omvat de v1-trigger en voorkomt dat ingesloten pionnen de cyclus eeuwig openhouden.
- Acties bij reset: ongewijzigd t.o.v. v1 (ontkoppelen, statusreset overlevenden, geëlimineerde pionnen blijven weg, nieuwe cyclus).

## 5. Winnen en Verliezen

De v1-regels blijven gelden, met deze verduidelijkingen:

- Havenwinst vereist **fysieke aanwezigheid**: beschietingen (infanterieschot én artillerie) veranderen geen posities en kunnen nooit een havenvak "veroveren".
- Een melee-eliminatie op een havenvak kan via de verplichte verplaatsing wél direct winst opleveren; ook de gratis Wolf-stap (§6.5) kan een pion een havenvak in zetten.
- Bij de eliminatie-winconditie telt het **doctrine-afhankelijke** totaal (tegen de Leeuw: 18).
- Elimineert een terugslag de laatste pion van de aanvallende speler, dan wint de verdedigende speler onmiddellijk.

## 6. Doctrines

| Doctrine | Kaarten × budget | Pionnen | Samenstelling (I/C/A) | Regelafwijking |
|---|---|---|---|---|
| **Mens** | 3 × 7 | 22 | 13 / 6 / 3 | geen — referentiedoctrine |
| **Muis** | 4 × 5 | 22 | 22 / 0 / 0 | mag door eigen pionnen heen bewegen |
| **Leeuw** | 2 × 9 | 18 | 6 / 10 / 2 | geen — economie en samenstelling zíjn de identiteit |
| **Beer** | 3 × 7 | 22 | 16 / 3 / 3 | +1 HP op elke kaart (buiten budget); Speed max 3 bij definitie |
| **Wolf** | 3 × 7 | 22 | 11 / 8 / 3 | na een melee-aanval 1 gratis stap naar een vrij vak |
| **Vos** | 3 × 7 | 22 | 13 / 6 / 3 | gedekt koppelen |

Samenstellingen zijn startwaarden voor playtests, geen eindwaarheden.

### 6.1 Mens

Geen bijzonderheden. IJkpunt: balanceer elke doctrine eerst tegen de Mens, daarna onderling.

### 6.2 Muis — de zwerm

- 4 kaarten × budget 5: 12 activaties per cyclus (tegen 9 bij de Mens), maar geen muis komt boven stat 3 uit.
- **Doorbewegen:** muizen mogen door **eigen** pionnen heen bewegen; elk gepasseerd vak telt gewoon als stap; eindigen op een bezet vak mag nooit; vijandelijke pionnen blokkeren normaal.
- Volledig infanterie: geen charge, geen kanonnen — wél 22 potentiële terugslagprikkers en het chip-schot (Attack 3 − 1 = 2 schade) over het ene lege vak. Over de eigen voorste rij heen schieten kan sinds v4.1 niet meer; het doorbewegen is het zwermgereedschap — van formatie wisselen zonder jezelf klem te zetten.
- Aandachtspunt: de staart van de cyclus (na de 6e Leeuw-actie nog 6 ongestoorde muisacties op rij). Noodrem in §8.

### 6.3 Leeuw — elite

- 2 kaarten × budget 9: brute kaarten (1/1/7 one-shot alles, ook de Beer-muur van 6 HP), maar slechts 6 activaties per cyclus.
- 18 pionnen: 4 thuisvakken naar keuze leeg. Let op de hoekhavens — een lege flankkolom is een open voordeur.
- Minder pionnen = minder inactieve doelen voor de vijand én een kortere eliminatie-route voor de tegenstander; beide zijn bewuste compensatie.
- **Meetpunt overkill:** schade draagt niet over, dus Attack 7 en Attack 4 doen tegen een 3-HP-doelwit hetzelfde. Tegen de Muis koopt budget 9 weinig extra's terwijl het actietekort blijft — de riskantste matchup van het roster.

### 6.4 Beer — bolwerk

- De **+1 HP** valt buiten het budget en telt **niet mee** in het initiatief-bod.
- Toepassing bij koppeling: `currentHP = HP-stat + 1`. Maximale muur: 5 + 1 = 6 HP.
- **Speed max 3** bij definitie. Beer-artillerie heeft dus dracht ≤ 3 **én** heeft vrije vuurlijnen nodig — achter de eigen muur staat een Beer-kanon blind. Vuurlanen openlaten of flankeren is verplichte kost.
- **Meetpunt:** presteren Beer-kanonnen structureel ondermaats, dan is 19/3/0 (alles op muur en melee) de terugvaloptie.
- Voor de race: een Beer-loper doet ± 3 cycli over de oversteek waar een speed-5-sprinter er 2 doet.

### 6.5 Wolf — roedel

- De gratis stap geldt na **elke melee-aanval**, ongeacht de uitkomst — juíst ook als het doelwit overleeft: prikken en buiten bereik stappen.
- Volgorde: aanval → (bij eliminatie) verplichte verplaatsing → optionele gratis stap naar een aangrenzend vrij vak.
- Geldt ook voor Wolf-cavalerie: bewegen + aanval + verplichte verplaatsing + stap kan `Speed + 2` opleveren. Zeer mobiel — playtesten.
- Geldt **níét** na schoten of beschietingen; Wolf-infanterie die schiet en Wolf-artillerie zijn standaard.
- Sneuvelt de wolf door terugslag, dan is er uiteraard geen stap.

### 6.6 Vos — informatieoorlog

- De 3 gedefinieerde kaarten worden in de onthulfase gewoon **openbaar** onthuld — het initiatief-bod werkt volledig normaal. Alleen de **toewijzing** (welke kaart op welke pion) is verborgen.
- Zichtbaar: wélke pion geactiveerd wordt, en zijn type. Onzichtbaar: welke van de 3 kaarten hij draagt. Je ziet dát het een kanon is, niet hoe ver het schiet.
- **Onthulling:** de gekoppelde kaart wordt openbaar zodra de pion voor het eerst schade **toebrengt of ontvangt** — altijd vóór de schaderesolutie. Ook bij eliminatie wordt de kaart onthuld.
- Bewegen onthult níét, maar lekt deductie: 4 vakjes lopen bewijst Speed ≥ 4; een kanonschot op afstand 4 bewijst (en onthult, want schade) de kaart. Dat deductiespel is de bedoeling.

## 7. Resolutievolgorde (implementatie)

### Melee-aanval (Infanterie-melee of Cavalerie-charge)

1. (Cavalerie) verplaats 0 t/m Speed stappen volgens de bewegingsregels; onthoud het charge-minimum (§3.2).
2. Kies een aangrenzend vijandelijk doelwit (optioneel bij charge mits er bewogen is; een infanterie-melee-actie bestaat alleen uit deze aanval).
3. (Vos) onthul de gedekte kaart(en) van aanvaller en/of verdediger.
4. Schade: verdediger `HP −= Attack`; inactieve verdediger: eliminatie bij Attack > 0.
5. Verdediger geëlimineerd → verwijder van bord; aanvaller **verplicht** naar het vrijgekomen vak; win-check (haven én eliminatie).
6. Verdediger overleeft én is actieve Infanterie → 1 terugslagschade op de aanvaller; aanvaller op ≤ 0 → verwijderen; win-check.
7. (Wolf, alleen als de aanvaller nog leeft) optionele gratis stap naar een aangrenzend vrij vak; win-check (havenvak!).
8. `hasActedThisCycle = true`; beurtwissel volgens §4.4.

### Beschieting (Infanterieschot of Artillerie)

1. Valideer:
   - doelwit is een vijandelijke pion (actief óf inactief) in een rechte orthogonale lijn waarvan **álle tussenvakken leeg** zijn;
   - afstand **exact 2** (infanterie) of **2 t/m Speed** (artillerie);
   - de schade zou > 0 zijn (infanterie: Attack ≥ 2).
2. (Vos) onthul de gedekte kaart(en) van de schutter en — indien actief — het doelwit.
3. Schade: `Attack − 1` (infanterie) of `Attack` (artillerie). Actief doelwit: `HP −= schade`, eliminatie bij ≤ 0. Inactief doelwit: eliminatie (schade > 0 is al gevalideerd). Het vrijgekomen vak blijft leeg; geen terugslag, geen verplaatsing.
4. Win-check (alleen eliminatie — posities veranderen niet).
5. `hasActedThisCycle = true`; beurtwissel.

### Beweging

1. Valideer het pad volgens type en doctrine: Artillerie max 1 stap, anders max Speed; Muis mag door eigen pionnen (gepasseerde vakken tellen als stappen); altijd orthogonaal; nooit eindigen op een bezet vak; vijandelijke pionnen blokkeren altijd.
2. Verplaats; win-check (havenvak).
3. `hasActedThisCycle = true`; beurtwissel.

### Skip

1. Heeft de speler aan de beurt geen enkele geldige actie met een nog niet gehandelde actieve pion → beurt naar de tegenstander, zonder markeringen.
2. Hebben beide spelers geen geldige actie → Resetfase (§4.5).

## 8. Balansknoppen & playtestnotities

Bewust nog níét in de regels, wel klaarliggend:

- **Vuurmodel-flags (engine):** `vuurRaaktInactief` en `vuurGeblokkeerd`. Deze spec: **aan/aan**, en `vuurGeblokkeerd` geldt nu uniform voor infanterieschot én artillerie. Het v3-alternatief (boogvuur): **uit/uit** — vuur raakt alleen actieven en negeert tussenliggende pionnen. **Verboden: aan/uit** — beschietbare standbeelden zonder blokkade is risicoloos oogsten en levert gegarandeerde verlamming op. Bouw beide configuraties in en laat het selfplay-harnas beslissen.
- **Infanterieschot over één pion** (de v4-regel): herinvoeren als infanterie structureel geen kaarten meer krijgt. Maakt dubbelrij-formaties mogelijk (muur vóór, vuur erachter), maar doorbreekt de absolute dekkingsregel.
- **Standbeeld-drempel:** vuur elimineert een inactieve pion alleen bij schade ≥ 2. Doodt de 1/5/1-oogstmachine (verre prikker die standbeelden plinkt) als die de meta gaat domineren.
- **Cumulatieve havenscore:** 2 haven-"touches" scoren in plaats van 2 pionnen tegelijk aanwezig. De grootste hefboom tegen standoffs en tegen het probleem dat een indringer bij de cyclusreset inactief wordt en aan één treffer sterft.
- **Per-stat cap** (bv. max 5) als de 1/1/7-Leeuw te lomp blijkt.
- **Artilleriedracht = Speed + 1** als de niet-kunnende-schieten Speed-1-koppeling te frustrerend blijkt.
- **Staart-cap:** maximum op opeenvolgende ongestoorde acties als de Muis-staart matches breekt.
- **Terugslag opschalen** (bv. ⌈Attack/2⌉ i.p.v. vast 1) als melee-agressie te goedkoop blijft.
- **Wolf-stap ook na schoten** (shoot-and-scoot) — grote power-spike, alleen bij structurele achterstand.
- **Vos-swap:** na de reveal 1 kaart herdefiniëren tegen budget 6, initiatief herberekenen — als gedekt koppelen te zwak meet.
- **Initiatiefhouder kiest koppelvolgorde** (eerst of laatst koppelen): maakt initiatief in Ronde 1/2 waardevoller, want als eerste koppelen is informatietechnisch eerder een straf dan een prijs.
- **Draft-doctrinekeuze** als variant op blind kiezen.

**Playtest-agenda** (hypotheses geordend op risico):

1. **Standoff/verlamming:** oprukkende pionnen worden bij de cyclusreset beschietbare standbeelden — hoe zwaar drukt dat op de haven-race? Meet partijlengte in cycli en het aandeel partijen zonder winnaar binnen N cycli. Te zwaar → cumulatieve havenscore inschakelen.
2. **1/5/1-oogstmachine:** duikt de goedkope verre prikker op als dominante artilleriekaart tegen standbeelden? → standbeeld-drempel.
3. **Vuurlijnen & kanon-nut:** krijgen kanonnen genoeg schootsveld, of verstoppen eigen linies ze permanent? Meet schoten per kanon per partij. Raakt vooral de Beer (dracht ≤ 3): terugvaloptie 19/3/0.
4. **Infanterie-koppelverdeling** *(omhoog geschoven: het schot is in v4.1 verzwakt)*: krijgt infanterie daadwerkelijk kaarten, of blijven cavalerie + artillerie (samen 9 = exact het kaartaantal van de Mens) de standaardkeuze? Meet koppelverdeling per type. Zakt infanterie weg → knop "infanterieschot over één pion" of terugslag opschalen.
5. **Leeuw-spiraal:** overkill-verspilling + actietekort, vooral tegen de Muis. Meet winrates en gemiddelde "verspilde Attack" per kill.
6. **Muis-chipzwerm:** 12 acties met chip-2-schoten over open gaten plus doorbewegen. Te sterk of precies goed?
7. **Hoekfort:** vrije opstelling maakt hoekhaven + beide toegangsvakken bezetbaar, waardoor winst naar de 3 middenvakken trechtert. Observeren; eventueel havenvakken niet-bezetbaar maken voor de verdediger.
8. **Vos vs Muis:** verborgen toewijzing is weinig waard als alle vijandelijke kaarten toch bijna identiek zijn. Accepteren of Vos-swap inzetten.
9. **Gelijkspel-claim v1:** met de skip/reset-semantiek kan een cyclus niet meer blijven hangen, maar eeuwig herhalende cycli blijven theoretisch mogelijk. Eerst meten (zie 1); zo nodig cyclus-limiet met tiebreak op resterende pionnen.

Meetadvies ongewijzigd: log winrates per matchup (6 doctrines = 21 matchups inclusief spiegels) en per winconditie; een simpel selfplay-harnas verdient zich hier direct terug. Vaste toetsvraag per doctrine: *"hoe zet dit leger 2 pionnen in de vijandelijke haven tegen een verdedigende tegenstander?"*
