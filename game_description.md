# Fog of War - Spelbeschrijving (v1 — basisdocument)

> **LET OP: de actuele spelregels zijn `spelregels-v4.1.md`** (eenheidstypes, vuurlijnen,
> melee/terugslag, doctrines, vrije opstelling, initiatief-bod). Dat document bouwt voort
> op dit v1-document: wat daar niet expliciet gewijzigd wordt, blijft gelden zoals hier
> beschreven. Lees dit document dus als de basis, v4.1 als de geldende overlay.

## 1. Speltype en Doel

- **Type:** 2-speler, tactisch bordspel met kaart-gedreven pion-activatie.
- **Thema:** Abstract tactisch gevecht.
- **Doel (Primair):** Wees de eerste speler die 2 van je eigen pionnen in de "Haven" (startgebied) van de tegenstander krijgt.
- **Doel (Secundair):** Elimineer alle 22 pionnen van de tegenstander.

## 2. Componenten

- **Spelbord:**
  - Een centraal speelveld van 11x11 vierkante vakjes.
  - Twee "Havens": elk bestaande uit 3 specifieke vakjes direct grenzend aan het midden van de tegenoverliggende zijdes plus het vakje in de twee bijbehorende hoeken.
    - Speler 1's doelhavens zijn de 3 centrale vakjes bovenaan en de 2 bovenste hoekvakjes (0,0 en 10,0).
    - Speler 2's doelhavens zijn de 3 centrale vakjes onderaan en de 2 onderste hoekvakjes (0,10 en 10,10).
- **Pionnen:**
  - 22 pionnen per speler (bv. Rood voor Speler 1, Blauw voor Speler 2).
  - **Startopstelling:** De 22 pionnen van elke speler beginnen op de twee dichtstbijzijnde rijen van het 11x11 speelveld (11 pionnen per rij).
- **Kaarten:**
  - Spelers hebben **geen** vast deck aan het begin.
  - Per setup-ronde (3 rondes per cyclus) **definiëren** beide spelers de stats voor 3 nieuwe kaarten.
  - **Stats per Kaart:** Elke kaart heeft 3 waarden:
    - Levenspunten (HP)
    - Loopsnelheid (stamina)
    - Aanvalspunten (Attack)
  - **Puntenverdeling:** Bij het definiëren van een kaart moeten de 3 stats optellen tot **exact 7**. Elke stat moet **minimaal 1** zijn (bv. 5/1/1, 3/2/2, 1/1/5).
  - **Gebruik:** Kaarten worden gekoppeld aan pionnen om deze te activeren en hun stats (HP, stamina, Attack) te bepalen voor de huidige cyclus.

## 3. Spelverloop: Cycli en Ronden

Het spel verloopt in grote **Cycli**. Binnen elke cyclus zijn er 3 **Setup Ronden** gevolgd door een **Actie Fase**.

### 3.1. Pre-Game Setup

1.  Plaats het bord.
2.  Elke speler plaatst zijn 22 pionnen op de startposities (de twee dichtstbijzijnde rijen).

### 3.2. Start van een Cyclus

1.  Alle pionnen worden (indien nodig) ontkoppeld van kaarten uit de vorige cyclus.
2.  De status van alle pionnen wordt gereset (HP wordt irrelevant tot nieuwe koppeling, `hasActedThisCycle` wordt `false`).
3.  Start Setup Ronde 1.

### 3.3. Setup Ronde (Wordt 3x per Cyclus Herhaald: Ronde 1, 2, 3)

Elke Setup Ronde bestaat uit de volgende fasen:

- **A. Kaart Definitie Fase (`SETUP_X_DEFINE`)**

  1.  Beide spelers definiëren _onafhankelijk_ (en idealiter tegelijkertijd/blind) de stats (HP, stamina, Attack - elk min. 1, totaal 7) voor 3 **nieuwe** kaarten specifiek voor deze ronde.
  2.  De stats worden per speler opgeslagen (logisch, nog niet zichtbaar voor tegenstander).

- **B. Onthul & Initiatief Fase (`SETUP_X_REVEAL`)**

  1.  Beide spelers onthullen (logisch) de 3 zojuist gedefinieerde kaarten.
  2.  Bereken de totale Attack-waarde van de 3 onthulde kaarten per speler. De speler met de hoogste totale Attack krijgt het **Initiatief** voor de komende Koppel Fase en (indien Ronde 3) de Actie Fase.
  3.  **Tiebreaker:** Bij een gelijke totale Attack wordt gekeken naar de totale stamina. Bij een gelijke totale stamina:
      - In Ronde 1 van Cyclus 1 wint **Speler 1** de tiebreaker.
      - In latere Ronden/Cycli wint de speler die het Initiatief had in de _vorige_ onthulfase de tiebreaker.
  4.  De 3 onthulde kaarten per speler worden beschikbaar gemaakt voor koppeling.

- **C. Koppel Fase (`SETUP_X_LINKING`)**
  1.  De speler die het Initiatief heeft begint.
  2.  Spelers kiezen **om de beurt**:
      - Eén van hun 3 kaarten die _in deze ronde_ zijn onthuld en nog niet gekoppeld zijn.
      - Eén van hun eigen pionnen op het bord die _in deze cyclus_ nog **geen** kaart gekoppeld heeft gekregen.
  3.  De gekozen kaart wordt aan de gekozen pion gekoppeld. De pion wordt `isActive`, krijgt de `currentHP` van de kaart, en de kaart wordt 'gebruikt' voor deze ronde.
  4.  Dit gaat door totdat alle 6 kaarten (3 per speler) van deze ronde gekoppeld zijn, **of** totdat een speler geen geldige pion meer kan kiezen om aan een resterende kaart te koppelen.
  5.  **Volgende Stap:**
      - Na Ronde 1 of 2: Ga naar de Kaart Definitie Fase van de volgende Setup Ronde.
      - Na Ronde 3: Ga naar de Actie Fase.

### 3.4. Actie Fase (`ACTION`)

1.  De speler met het **Laatst Bepaalde Initiatief** (uit de onthulfase van Ronde 3) begint.
2.  Spelers nemen **om de beurt** een actie.
3.  **Tijdens een beurt:**
    - De speler kiest één van zijn **actieve** pionnen (die een kaart gekoppeld heeft deze cyclus) die **deze cyclus nog geen actie heeft uitgevoerd**.
    - De speler voert **één** van de volgende acties uit met de gekozen pion:
      - **Bewegen:**
        - Verplaats de pion horizontaal of verticaal.
        - Maximaal aantal stappen gelijk aan de `stamina` van de gekoppelde kaart.
        - Mag niet door andere pionnen (vriend of vijand) heen bewegen.
        - Mag niet op een bezet vakje eindigen.
      - **Aanvallen:**
        - Kies een vijandelijke pion (actief of inactief) op een **direct aangrenzend** vakje (horizontaal of verticaal).
        - De `Attack`-waarde van de aanvaller wordt afgetrokken van de `currentHP` van de verdediger (indien de verdediger actief is).
        - **Schade & Eliminatie:**
          - Als de verdediger actief is en zijn HP <= 0 wordt, wordt hij geëlimineerd.
          - Als de verdediger _niet_ actief is (geen kaart), wordt hij geëlimineerd als de Attack van de aanvaller > 0 is.
          - Geëlimineerde pionnen worden van het bord verwijderd (worden inactief, verliezen eventuele kaart).
        - **Verplichte Verplaatsing na Eliminatie:** Als de aanvallende pion de aanval overleeft **en** de verdedigende pion werd geëlimineerd, **moet** de aanvallende pion **direct** naar het zojuist vrijgekomen vakje verplaatsen.
4.  **Na elke Actie:** Controleer direct de win condities.
5.  **Beurt Einde:** Markeer de pion die gehandeld heeft (`hasActedThisCycle = true`). De beurt gaat naar de andere speler, tenzij deze geen geldige acties meer heeft deze cyclus (dan gaat de beurt terug).
6.  De Actie Fase gaat door totdat de Reset Fase wordt getriggerd.

### 3.5. Reset Fase

- **Trigger:** De Reset Fase begint zodra _alle_ actieve pionnen van _beide_ spelers die deze cyclus konden starten, hun actie hebben uitgevoerd of geëlimineerd zijn.
- **Acties:**
  1.  Alle kaarten worden logisch ontkoppeld van alle pionnen.
  2.  De status van alle _overlevende_ pionnen wordt gereset (niet meer `isActive`, HP irrelevant, `hasActedThisCycle` = false).
  3.  Geëlimineerde pionnen blijven van het bord.
  4.  Start een nieuwe Cyclus (ga terug naar 3.2).

## 4. Winnen en Verliezen

Een speler wint onmiddellijk als:

- Hij 2 of meer van zijn pionnen in de 5 voor hem bestemde doelhavens (middenrand óf hoeken aan de overkant) heeft staan aan het einde van zijn eigen actie (na bewegen of na aanvallen+verplaatsen).
- De tegenstander aan het begin van zijn beurt (of direct na een aanval resulteert in) geen pionnen meer op het bord heeft.
- Een gelijkspel (Draw) is niet mogelijk onder de huidige regels. Het spel eindigt altijd met een winnaar.
