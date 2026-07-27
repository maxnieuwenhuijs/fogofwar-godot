# Card Design Brief — Fog of War (spelerskaarten)

Design-opdracht voor de kaarten die spelers per setup-ronde definiëren en aan pionnen koppelen. Te gebruiken als prompt voor Claude of als brief voor een designer. Regels: `spelregels-v4.1.md`; huidige implementatie: `scripts/ui/card_view.gd` + `card_hand.gd`.

---

## 1. Context & toon

- **Spel:** 2-speler tactisch bordspel in Godot; 11×11 bord met 3D-dierensoldaten in napoleontische stijl (muis-infanterist met sjako en musket, kanonnen, cavalerie).
- **Sfeer:** vroeg-19e-eeuws militair — veldorders, regimentsinsignes, verweerd papier, koper en lakzegels. Denk aan een handgeschreven bevelbriefje van een veldmaarschalk, niet aan een glossy TCG-kaart.
- **Geen fantasy-look:** geen gloed, geen foil, geen edelstenen. Wel: inkt, stempels, canvas, vergeeld papier.

## 2. Wat een kaart IS (belangrijk voor het ontwerp)

Kaarten zijn **geen vaste collectie** — de speler stelt ze elke setup-ronde zelf samen:

- 3 stats: **HP** (levenspunten), **Speed** (stappen/dracht), **Attack** (schade).
- Elke stat minimaal 1; de som is exact het **kaartbudget** van de doctrine.
- Kaarten zijn **typeloos**: dezelfde kaart kan op infanterie, cavalerie of artillerie gelegd worden. Het ontwerp mag dus géén unit-type suggereren.
- De kaart is dus vooral een **stat-drager met identiteit van de doctrine/speler**, geen illustratiekaart per eenheid.

### Per doctrine

| Doctrine | Kaarten/ronde | Budget | Ontwerp-accent |
|---|---|---|---|
| Mens | 3 | 7 | neutraal referentie-ontwerp |
| Muis | 4 | 5 | zwerm: klein, veel, snel leesbaar naast elkaar |
| Leeuw | 2 | 9 | elite: groter/zwaarder aanvoelend, hogere statwaarden mogelijk (tot 7) |
| Beer | 3 | 7 | toont "+1 HP" bonus buiten budget; Speed max 3 |
| Wolf | 3 | 7 | standaard frame, roedel-insigne |
| Vos | 3 | 7 | moet ook een **verborgen/anonieme** variant hebben (gedekt koppelen) |

## 3. Kaartstates (allemaal visueel te onderscheiden)

1. **Definitie (bewerkbaar):** speler verdeelt punten met +/− per stat; toon resterend budget. Blind voor de tegenstander.
2. **Onthuld:** stats zichtbaar voor beide spelers; Attack-totaal telt mee voor het initiatief-bod — Attack mag visueel iets zwaarder wegen.
3. **Selecteerbaar/geselecteerd:** aan te tikken in de koppel-fase (nu: gele tint).
4. **Gekoppeld/gebruikt:** gedempt/vergrijsd, met verwijzing naar de gekoppelde pion (nu: modulate 0.5).
5. **Kaartrug:** nodig voor de blinde definitie-fase en voor Vos-koppelingen. Ontwerp per speler kleurgecodeerd.

## 4. Layout-eisen

- **Formaat:** staand, ~2:3. Moet leesbaar blijven op klein formaat: de Muis toont 4 kaarten naast elkaar in de hand-balk, en gekoppelde kaarten kunnen als mini-badge bij een pion verschijnen.
- **Stats:** 3 grote cijfers met icoon, verticaal of in een rij:
  - HP → hart of schild
  - Speed → laars of hoefijzer
  - Attack → gekruiste sabels of musketten
- **Cijfers zijn het hoofdelement** — groter dan al het andere. Bereik 1–7 (Leeuw), plus "6*" weergave voor Beer-HP met bonus.
- **Spelerskleur:** rood (speler 1) / blauw (speler 2) als duidelijke rand- of zegelkleur.
- **Doctrine-insigne:** klein wapenschild/embleem per dier (muis, leeuw, beer, wolf, vos, mens) op een vaste plek, bv. bovenaan als regimentszegel.
- **Editable-modus:** ruimte voor +/− knoppen per stat en een budget-teller ("nog 2 punten"), zonder de layout te breken wanneer die knoppen verdwijnen.

## 5. Deliverables

1. Kaart-frame (voor- en achterkant) in rood- en blauwvariant.
2. 3 stat-iconen (HP/Speed/Attack), monochroom, leesbaar op 24×24 px.
3. 6 doctrine-emblemen (Mens, Muis, Leeuw, Beer, Wolf, Vos).
4. State-varianten: bewerkbaar, onthuld, geselecteerd, gekoppeld/gebruikt, verborgen (Vos).
5. Mini-variant (badge) van de kaart voor weergave bij een gekoppelde pion op het bord.
6. Assets als losse PNG's met alpha (of SVG), geschikt voor Godot `PanelContainer`/`TextureRect`; 9-patch-vriendelijke frames hebben de voorkeur.

## 6. Niet doen

- Geen unit-type-illustraties op de kaart (kaarten zijn typeloos).
- Geen tekstzware kaarten — alle regels zitten in het spel, niet op de kaart.
- Geen effecten die states onleesbaar maken bij kleine weergave (subtiele tint-verschillen zijn nu al krap; gebruik ook vorm/icoon, niet alleen kleur).
