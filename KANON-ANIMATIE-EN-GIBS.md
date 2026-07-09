# Kanon: draaiende wielen + gibs

Het kanon is een **prop**, maar loopt door dezelfde PawnView-pijplijn als de
poppetjes. Het spel roept bij elke beweging `play_walk()` aan, óók voor
artillerie. Dus: geef je kanon-glb een **`walk`-clip waarin de wielen draaien**,
en het spel speelt die automatisch af zodra het kanon over het bord rolt. Een
`idle` (stilstaand) is de rustpose.

**Belangrijk verschil met de poppetjes:** het kanon heeft **geen skelet/heupen**,
dus:
- **Geen** `fix_model.bat` en **geen** donor-merge (die zijn voor de
  Mixamo-infanterie met heup-clips).
- Je maakt de wiel-animatie **zelf** in Blender (object-rotatie), en exporteert
  direct.

---

## Deel 1 — Wielen laten draaien (walk-animatie)

### 1a. Wielen los + juiste draaipunt
1. Zorg dat **elk wiel een eigen object** is (niet samengevoegd met de affuit).
   Zo niet: Edit Mode → selecteer het wiel → `P` → Selection om af te splitsen.
2. **Zet het draaipunt (origin) in het midden van de as** van elk wiel, anders
   "wentelt" het wiel in een baan i.p.v. rond zijn as:
   - Selecteer het wiel → in de viewport de 3D-cursor op het ashart plaatsen
     (selecteer een rand/vertex op het ashart → `Shift+S` → Cursor to Selected).
   - `Object → Set Origin → Origin to 3D Cursor`.
3. Kijk welke **lokale as** door de wielen loopt (meestal X). Die as gaat draaien.

### 1b. De walk-clip maken (wielen spinnen)
1. Ga naar het **Animation**-tabblad. Zet een nieuwe Action aan en noem hem
   **`walk1`** (de naam telt: het spel zoekt `walk`/`walk1`/`walk2`).
2. Frame 1: selecteer beide wielen → `I` → **Rotation** (keyframe op 0°).
3. Ga naar bv. frame 24. Draai beide wielen **360°** om hun as
   (`R X 360 Enter`, of via het N-paneel Rotation). Keyframe opnieuw (`I` →
   Rotation).
4. Zet de interpolatie op **Lineair** (Graph Editor → alles selecteren → `T` →
   Linear), anders versnelt/vertraagt het wiel. 0° → 360° loopt naadloos rond,
   dus de clip herhaalt vloeiend (het spel loopt `walk` automatisch).
5. Maak ook een **`idle1`**: een tweede Action met de wielen stil (1 keyframe op
   0° is genoeg). Dit is de rustpose.

> Tip: de muis-artillerist en de affuit hoeven niet mee te bewegen — alleen de
> wielen draaien. Laat die dus buiten de rotatie-keyframes.

### 1c. Exporteren
- **File → Export → glTF 2.0 (.glb)**, met **Animation AAN**.
- Selecteer het hele kanon (affuit + wielen + muis-artillerist).
- Opslaan als `assets/models/<factie>/artillery_<archetype>.glb`
  (bv. `assets/models/mouse/artillery_base.glb`).
- In Godot importeren. Klaar — het kanon rolt nu met draaiende wielen.

*(Object-animatie exporteert glTF als node-animatie; Godot maakt er een
AnimationPlayer van die het spel automatisch oppikt. Een armature is niet nodig.)*

---

## Deel 2 — Kanon-gibs (uit elkaar spatten)

Zelfde principe als de poppetjes: een **apart statisch `_gibs.glb`** met de losse
delen die het spel wegslingert bij vernietiging.

### 2a. Delen splitsen
Knip het kanon in losse objecten, bv.:
- `wielL`, `wielR` (de twee wielen)
- `loop` (de kanonsloop)
- `affuit` (het onderstel)
- `muis` (de artillerist — vliegt er los af)

### 2b. Exporteren (statisch)
- **File → Export → glTF 2.0 (.glb)**, selecteer **alleen die losse delen**.
- **Skinning UIT · Animation UIT** (net als bij de poppetjes-gibs).
- Opslaan als `assets/models/<factie>/artillery_<archetype>_gibs.glb`.

Bij vernietiging vliegen de delen los (wielen weg, loop los, artillerist eraf).

> **Let op — bloed:** het gib-systeem spuit standaard bloed bij elk deel. Voor
> hout/metaal (wielen, loop, affuit) is dat vreemd. Als je de gibs erin hebt,
> kan ik de code zo aanpassen dat alleen het **muis**-deel bloedt en het
> hout/metaal splinters/rook geeft i.p.v. bloed. Zeg het als je zover bent.

---

## Naamgeving samengevat

| Bestand | Wat |
|---|---|
| `artillery_<archetype>.glb` | kanon + `idle1`/`walk1` (wielen draaien) |
| `artillery_<archetype>_gibs.glb` | losse delen, statisch (wielen/loop/affuit/muis) |
| `artillery_<archetype>_red.png` / `_blue.png` | team-kleuring (optioneel; kanon is vaak neutraal) |

Import van grote textures op **1024 + mipmaps** (net als bij de poppetjes).
