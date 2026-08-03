# UI Design Brief — Fog of War (alle schermen & componenten)

Design-opdracht voor de volledige spel-UI. Te gebruiken als prompt voor Claude of als brief voor een
designer, per sectie los uit te delen. Zusterdocument van `CARD-DESIGN-BRIEF.md` (de spelerskaarten —
daar verwijst §3 hieronder naar). Regels: `docs/spelregels-v4.2.md` en `docs/campagne-spec.md`; huidige
implementatie: `scripts/ui/`, `scripts/ui/campaign/`, `scripts/game/game.gd`.

---

## 1. Context & toon

- **Spel:** 2-speler tactisch bordspel + team-campagne, Godot 4.7, **mobiel-first portrait 1080×1920**.
  3D-bord met dierensoldaten in napoleontische stijl; alle UI ligt als 2D-laag over het bord of als
  los scherm.
- **Sfeer:** vroeg-19e-eeuws militair veldkwartier — veldorders, regimentsboeken, lakzegels, koper,
  verweerd papier en canvas. De campagne voelt als een **grootboek + berichtenstroom van het regiment**,
  niet als een moderne app.
- **Geen fantasy-look:** geen gloed, geen foil, geen neon. Wel: inkt, stempels, waszegels, linnen.
- **Iconen boven tekst** (hard uitgangspunt uit het bouwplan): elk concept heeft een pictogram; tekst is
  ondersteuning. Quick-chat en rapporten moeten zonder lezen te begrijpen zijn.
- **Speeldoelgroep:** ook vreemden op een telefoon; alles moet met duim-tikken werken (geen hover,
  geen rechtermuisknop — de touch-contextknop bestaat al in `game.gd`).

## 2. Design-systeem (fundament — eerst dit, alles hergebruikt het)

### 2.1 Iconenset (monochroom leesbaar op 24×24, kleurvariant toegestaan)

> **Definitieve lijst (30 juli): 37 unieke iconen, genummerd vastgelegd in
> `docs/design/UI-SPEC-EN.md` § "Icon list (definitive)".** Die lijst is het
> contract met de designer; de tabel hieronder is de duiding per concept.
> Bovenop de eerdere tabel telt hij ook mee: de 3 stat-iconen (gedeeld met de
> kaart-brief), 4 fase-iconen, initiatief, het "?"-zegel, de pin voor
> vastgepinde orders, rapport- en chat-iconen.

| Concept | Suggestie | Gebruikt in |
|---|---|---|
| Pool (pionnenvoorraad) | 🪖 soldatenrij / tentenkamp | Grootboek, DonateSheet, spawn-UI, HUD |
| CP (commandopunten) | 🎖️ medaille / epaulet | Grootboek, bied-UI, DonateSheet |
| Punten (klassement) | ⭐ ster / laurier | Grootboek, MatchReport, leaderboard |
| Levend / dood | ❤️ / 💀 (of vlag / gebroken vlag) | Grootboek, portretten, spookmodus |
| Winst haven / eliminatie / remise / forfeit | 🏰 / 💀 / 🤝 / 🏳️ | MatchReport, historie |
| Acties: melee / schot / bewegen / charge / wolf-stap | ⚔️ / 🏹(musket) / 👣 / 🐎 / 🐾 | bordknoppen, rapporten, uitleg |
| Kanon-acties: rollen / vuren / inrukken | wiel / vlam / omgekeerde pijl | kanon-actiepot-UI |
| Spawn | tent + pijl het veld op | spawn-UI, rapporten |
| Unit-types I/C/A | silhouet infanterist / ruiter / kanon | overal waar types staan |
| Klok/deadline | zakhorloge | TimerBar, raad, testament |
| Stem / nominatie / donatie / testament | stembus / wijzende vinger / gift / verzegelde brief | campagne-kaartjes |

Plus de **6 doctrine-emblemen** (regimentszegels: Varken/Mens, Muis, Leeuw, Beer, Wolf, Krokodil/Vos) —
gedeeld deliverable met CARD-DESIGN-BRIEF §5.3.

### 2.2 Thema-tokens

- Kleurpalet: papier (licht), inkt (donker), koper/goud (accenten), **rood = speler/team 1, blauw =
  speler/team 2** — consistent in 3D (team-textures bestaan al) én UI.
- Typografie: één display-font met veldorder-karakter voor titels, één zeer leesbare UI-font voor
  cijfers/lopende tekst. Cijfers zijn overal het hoofdelement (stats, klokken, saldi).
- Panel-stijlen als 9-patch: papier-kaartje (licht), grootboek-regel, donker "veldtafel"-paneel voor
  over het 3D-bord.
- **Universele states** (vorm + kleur, nooit alleen kleur): normaal / selecteerbaar / geselecteerd /
  gedimd (kan niet handelen) / verborgen ("?"-staat, zie 4.4).

### 2.3 Portretten

Avatar = doctrine-embleem + spelerskleur + naam (geen uploads). Nodig in: Grootboek, Raad,
chat-kaartjes, leaderboard, testament. Dood = zelfde portret gedesatureerd + 💀-overlay.

## 3. De kaarten

Volledig gespecificeerd in `CARD-DESIGN-BRIEF.md`. **Aanvulling sinds v4.2 (F2):** de kaart heeft een
extra state en element:

- **CP-geboden-staat:** een kaart waarop de speler 1 CP heeft ingezet toont een koperen
  medaille-stempel + de verhoogde stat gemarkeerd ("+1"). Blind voor de tegenstander tot de reveal.
- De bied-stepper (0..3 CP per ronde) hoort bij de kaartwaaier-balk, niet op de kaart zelf.

## 4. Match-UI (het bord-duel)

### 4.1 HUD & fasen

- **Topbalk:** fase-icoon + naam (opstellen / definiëren / onthullen / koppelen / actie / spawn),
  cyclus- en rondeteller, beurt-indicator (wiens kleur), **TimerBar/klok** (bank + increment; nu een
  kale countdown-tekst). Deadline-stress: laatste 5 s visueel (roder/pulserend zegel), sluit aan op de
  bestaande tik-geluiden.
- **Fase-overgangsmoment:** kort, duidelijk banner-moment ("Ronde 2 — definieer je kaarten") dat ook
  als anker dient voor de audio-cues (`phase_change`, `cycle_start`).

### 4.2 Targeting-taal op het bord

Bestaande kleurcodes behouden maar vormgeven als echte markers (nu platte CSG-vlakken):
groen = bewegen (met stamina-kostenlabel per tile), rood = melee/charge, oranje = schot/vuurlijn,
cyaan = wolf-stap. Elke marker krijgt ook een vorm-verschil (pijl / sabels / vizier / pootafdruk) voor
kleurenblindheid.

### 4.3 Pion-informatie

- **Stat-blokjes** boven actieve pionnen (rij HP groen / stamina blauw / attack oranje) — kandidaat
  voor redesign: kleiner, rustiger, papier/koper-stijl, en schaalbaar (22 pionnen in beeld).
- **Kanon-actiepot-badge:** resterende acties op het kanon (v4.2), leesbaar op afstand.
- Selectie-/koppelringen aan de voet (bestaan) — stijlen mee in het thema.

### 4.4 De "?"-staat (verborgen informatie)

Gedekte Vos-pionnen en niet-onthulde informatie tonen een **"?"-zegel** — nooit lege of nul-waarden
(lekt informatie). Zelfde "?"-taal overal: stat-blokjes, kaartrug, reveal-scherm, grootboek.

### 4.5 v4.2-schermen (functioneel gebouwd in F2.6, design ontbreekt)

- **Spawn-UI:** poolvoorraad per type (🪖 × I/C/A), plaatsing op de thuisrij (hergebruikt de
  opstellings-ghost), "klaar"-bevestiging, blind-indicator ("tegenstander kiest ook…").
- **CP-bied-UI:** stepper in de kaartwaaier-balk + saldo-badge.
- **MatchSetup-presets:** drie knoppen Aanvallend / Gebalanceerd / Verdedigend (tevens de
  timeout-default) boven de kaartwaaier.

### 4.6 Onthul-scherm (reveal)

Beide kaartensets naast elkaar (mini-kaarten), bod-percentage groot, "X begint"-moment met
initiatief-icoon. Moet leestijd bieden (per-speler doorgaan-knop, online).

### 4.7 Opstelling

Ghost-preview (bestaat), undo-knop (touch), "standaard"-knop, resterende-stukken-telling per type.

### 4.8 Einde-states

Aparte momenten voor: winst 🏰 / winst 💀 / verlies / **remise (cycluslimiet + tiebreak-uitleg)** /
opgeven / forfeit-door-tijd. Elk met één kernstat-regel en doorknop (rematch / terug naar campagne —
de campagne-variant voedt het MatchReport-kaartje).

## 5. Campagne-schermen (functioneel gebouwd in F3 — `scripts/ui/campaign/`)

### 5.1 CampagneHub (het hoofdscherm van de campagne)

Tijdlijn/berichtenstroom van **kaartjes** — het "Among Us-gevoel": alles wat gebeurt is een kaartje in
de stream. Elk kaartje-type is een eigen mini-ontwerp (vast icoon + kleuraccent + 1 regel + detail-tik):

1. **Duel-rapport** (uitslag, methode-icoon, verliezen) — tik = MatchReport.
2. **Nominatie** ("X wijst Y aan") — wijzende vinger.
3. **Stemuitslag** (ballot-icoon + uitslag per portret).
4. **Donatie** (gift-icoon, 🪖/🎖️ + aantal, van → naar).
5. **Testament** (verzegelde brief; geopend = verdeling zichtbaar).
6. **Bark/quick-chat** (spraakballon + portret + frase-icoon).
7. **Fase-kaartje** ("Raad geopend", "Burgeroorlog begint") — als scheidingsbanner.

Vaste onderbalk: naar Grootboek / Raad / (eigen) pool & CP-saldo / menu.

### 5.2 Grootboek

Regimentsboek-look: sorteerbare tabel — portret, doctrine-zegel, 🪖 pool, 🎖️ CP, ⭐ punten, ❤️/💀.
Tik op rij = spelersdetail (historie van duels/donaties). Eigen rij gemarkeerd.

### 5.3 Raad

Vastgepinde **ballot** bovenaan (wie tegen wie wordt voorgesteld), TimerBar, portretten tikken =
stemmen; live stem-status binnen het team (portret krijgt stembus-stempel); sluit vervroegd bij
unanimiteit. Duidelijk verschil "jij mag stemmen" vs "wachten op teamgenoten".

### 5.4 DonateSheet

Rij teamgenoten (portretten), stepper +1/+5 🪖 en +1 🎖️, caps zichtbaar als stempel ("max 10/ronde"),
swipe of dubbele tik = bevestigen. Caps zitten hard in de reducer — de UI moet het *waarom* tonen.

### 5.5 Testament

Het dramascherm: verdeel-slider over max 2 ontvangers, **grote dwingende timer**, verbrand-waarschuwing
("niets gekozen = alles verbrandt"). Moet ook koud vanaf een pushmelding kunnen openen.

### 5.6 MatchReport

Winnaar + methode-icoon, cycli, verliezen per type (unit-silhouetten), CP-mutaties, "bekijk replay"-knop.
Verschijnt als kaartje én als los scherm.

### 5.7 BracketView (burgeroorlog)

Toernooiboom met portretten, seeds, vrijloting gemarkeerd; gespeelde duels tonen uitslag-icoon.
Banner-moment "geen raad, geen ruil — ieder voor zich".

### 5.8 Spookmodus

Dode spelers zien alles in een gedempte variant (sepia/gedesatureerd + 💀-badge op eigen portret);
teamgeheimen (stemmen, teamchat) verdwijnen zichtbaar ("verzegeld voor de doden").

## 6. Menu's & flow

- **Hoofdmenu/startflow:** nu generieke overlay-knoppen; wordt: veldtafel-menu (solo-campagne /
  los duel / vs AI / uitleg / instellingen).
- **Doctrine-keuze:** 6 regiment-kaarten met embleem, comp (I/C/A), kaarten×budget en pro/con —
  bestaat functioneel (`Constants.DOCTRINE_DATA`), verdient het belangrijkste redesign van de menu-flow.
- **Speluitleg:** 5 tabs (bestaat, volledig in code) — restyle in het thema; regels als geïllustreerde
  voorbeeldjes i.p.v. lopende tekst.

## 7. Online (F4/F5 — nog niet gebouwd; nu mee-ontwerpen zodat het systeem past)

- **Lobby:** join-code (5 tekens, groot invoerveld), publieke queue, "vs AI"; bots altijd zichtbaar
  gelabeld 🤖.
- **Wachtstates:** per blinde fase een "wachten op tegenstander"-variant (verzegelde envelop-motief);
  reconnect ("verbinding herstellen… gratie-klok"); "tegenstander weggevallen".
- **Quick-chat-bar:** frase-id's als icoon+korte tekst; moet in de teamchat én als bark boven het bord
  werken.
- **Pushmeldingen** (3 types): jouw duel ⚔️ / raad open 🗳️ / rapport 📜 — icoon + één regel, met
  duidelijke landing (duel → MatchSetup; raad → Raad; rapport → kaartje).

## 8. Meta (F6 — later, wel in het systeem meenemen)

Leaderboard-scherm (tabs: globaal / doctrine / seizoen-LP / vrienden / drama-borden), Profiel
(portret, rating, historie), Instellingen (geluid, shake, taal), league-tiers Hout→Brons→Zilver→Goud→
Fabel als emblemen-ladder, seizoensbeloning = embleem-cosmetica, rapporteer/commend-flow (twee knoppen
op het einde-scherm).

## 9. Deliverables (gefaseerd)

**Fase 1 — systeem (blokkeert de rest):**
1. Thema-tokens: palet, 2 fonts, 3 panel-9-patches, knop-set met states.
2. Iconenset §2.1 (±28 iconen, monochroom 24×24 + kleurvariant).
3. 6 doctrine-emblemen + portret-frame (gedeeld met CARD-DESIGN-BRIEF).

**Fase 2 — match:** HUD-topbalk + TimerBar, targeting-markers (4 vormen), stat-blokjes-redesign,
"?"-zegel, spawn/CP/kanon-elementen, reveal- en einde-schermen, MatchSetup-presets.

**Fase 3 — campagne:** de 7 kaartje-types, CampagneHub-layout + onderbalk, Grootboek, Raad-ballot,
DonateSheet, Testament, MatchReport, BracketView, spook-variant.

**Fase 4 — flow & online:** hoofdmenu, doctrine-keuze, uitleg-restyle, lobby + wachtstates,
quick-chat-iconenset, push-iconen. (Meta §8 pas richting F6.)

Assetvorm: PNG met alpha of SVG; frames 9-patch-vriendelijk; alles op portrait 1080×1920 met
leesbaarheid op 6"-schermen als toets.

## 10. Niet doen

- Geen tekstmuren — als een scherm uitleg nodig heeft, faalt het ontwerp (uitleg leeft in het
  "?"-scherm).
- Geen informatie-lek via het ontwerp: verborgen = "?"-zegel, nooit lege/nul-weergave of een
  wél/niet-aanwezig verschil dat iets verraadt (zelfde regel als de view-filter in de engine).
- Geen states die alleen op kleur leunen (kleurenblindheid; vorm/icoon altijd mee).
- Geen hover-afhankelijke interactie en niets essentieels in schermhoeken die een duim niet haalt.
- Geen aparte desktop-layout in v1 — portrait schaalt mee, klaar.


---

## Playtest-wensen 27 juli (Max) — verwerkt + open voor design

**Al gebouwd (functioneel, wacht op designer-polish):**
- **Campagne-eindscherm** (hub, fase KLAAR): kampioen groot, samenvatting
  (rondes/duels/eigen roem + plek), top-3 roem, knoppen "Bekijk het
  volledige grootboek" en "Start een nieuwe campagne". Design mag hier een
  echt podium/celebratie-moment van maken.
- **Alle acties zichtbaar in de chatlog**: donaties en testamenten (ook die
  van de speler zelf) verschijnen als groene event-regels ("X geeft 3
  soldaten, 1 CP aan Y"). Battlereport-kaartjes zijn klikbaar -> dialoog
  met verliezen per type + CP-delta per speler.
- **Duel-flow**: loting-overzicht (wie-tegen-wie), auto-start met aftel +
  laadscherm; bots simuleren op de achtergrond; gemiste events druppelen
  bij terugkomst gefaseerd binnen (fade-in) als afspeel-animatie.
- **Spawn-moment op het bord**: verse reinforcements "poeffen" een voor een
  het bord op voordat de kaarten-fase opent (place-tik per pion).

**Nog te bouwen (C11, besluit Max) — design mag voorsorteren:**
- **Reinforcements = een puntenpot** (soldaat 1 / ruiter 2 / kanon 3):
  overal een getal i.p.v. drie voorraadjes. Saldi-regel moet expliciet
  maken: "Veldleger: altijd vol - Versterkingen: N - CP: N - Roem: N"
  (verwarring "ben ik alles kwijt?" wegnemen).
- **Doneren via plus-knopjes** achter elke teamgenoot-naam in de
  teamkolommen ([+1] versterking, [+CP]), caps zichtbaar; geen
  spinbox-formulier meer.
- **CP-ruil 2:1** naar versterkingen (knop bij je eigen saldi).
- **Per-factie budgetten** (tweakbaar): zwakke facties compenseren met
  meer versterkingen (Muis/Beer) of meer CP (Wolf).
