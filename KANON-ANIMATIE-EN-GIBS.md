# Kanon: draaiende wielen + gibs

## Sinds 9 oktober 2026: gescript (de Leeuw-kanonnen)

De eerste echte kanonnen kwamen als vijf blends (`assets/new upload folder/
lion/canon_{atk,base,hp,mix,spd}/lion *.blend`). Zo zit zo'n blend in elkaar,
en zo gaat hij het spel in.

**De blend:** twee rigs. `Armature` is het kanon (9 botten, het hp-kanon 11
met vier wielen: `Bone` = wortel, wielen aan `Bone.001`/`.002`, de loop is de
ketting `Bone.003`..`.007`, de affuit aan `Bone.008`). `Armature.001` is de
bediener, een Mixamo-karakter met een IK-besturingsrig (126 botten, waarvan 41
`mixamorig`-deform; de acties keyen alleen `Ctrl_`-botten). Zeven acties,
in alle vijf dezelfde namen: `Character fire` + `cannon Fire` (vuren, de
terugslag op frame 29-31), `push` / `pushing 2` + `Cannon moving` (duwen, de
wielen een hele slag), `Idle 1` / `idle 2`. De bediener is in alle vijf
dezelfde mesh (zelfde UV's): een rode en een blauwe jas voor hem passen op alle
vijf. Alles heet `tripo_node`, ook de leeuw; de pijplijn deelt dus in op RIG.

**Erin zetten:** `python tools/verwerk_levering.py "assets/new upload folder/
lion/canon_atk"` (of de paneelknop "Map in het spel zetten"). Een mapnaam met
`canon`, `cannon`, `kanon` of `artillery` is artillerie; dan draait er een stap,
`tools/blender_export_kanon.py`, die schrijft:

| Bestand | Wat |
|---|---|
| `artillery_<arch>.glb` | kanon + bediener; clips `attack` (de bediener ontsteekt, het kanon slaat terug), `walk1`/`walk2` (duwen, wielen een slag per duwcyclus), `idle1`/`idle2` (kanon stil). Elke clip beweegt BEIDE skeletten (NLA-sporen met dezelfde naam, samengevoegd door de exporter); alleen deform-botten, de besturingsrig ingebakken; 30 fps |
| `artillery_<arch>_cannon.glb` | alleen het kanon, statisch: de kanonjas hoort hierbij en `uv_check` meet ertegen |
| `artillery_<arch>_gibs.glb` | de brokstukken: `Kanon_Loop`, `Kanon_Affuit`, `Kanon_Wiel.L`/`.R` (geskinde delen op de botten geknipt) en de bediener in de delen van de infanterie (`Hat`, `Head`, `Body`, `Arm.L`, `Forarm.L`, `Upleg.L`, `Leg.L` ...; de berenmuts los op kleur en hoogte), in de idle-houding naast het kanon |

**Jassen:** in de leveringsmap `red/` + `blue/` = de jas van de bediener
(`artillery_<arch>_red.png`), `weapon/red` + `weapon/blue` = de kanonjas
(`artillery_<arch>_cannon_red.png`, Max: "kanon ook blauw of rood jas hoor,
minimaal verschil maar toch"). De uploads voor de retexture-dienst maakt
`python tools/maak_retexture.py "assets/new upload folder/lion"` (paneelknop
"Model klaarmaken voor retexture"): `lion_artillery_<arch>.glb` = de bediener,
`lion_artillery_<arch>_wapen.glb` = het kanon. Wat terugkomt zet de
Texture-koppelaar (paneel, of `python tools/texture_koppelaar.py <map>`) op
zijn plek: een bediener-jas gaat naar alle vijf de kanonnen, een kanonjas naar
zijn eigen kanon, rood of blauw; met "Ja" meteen het spel in.

**In het spel** (`PawnView`, blok "Artillerie: kanon + bediener"): de vuur-clip
speelt, de kogel, de vlam, de knal en de treffer wachten op het schot-moment
(gemeten uit de clip: het laatste frame dat het kanon stilstaat, ~0,9 s), de
lont-sis begint even eerder, en op het schot-moment slaat het hele stuk terug
(een duw naar achteren en de neus omhoog). De vuurmond is zonder afstelling
het punt van de loop zelf. De bediener staat bij elk kanon even hoog
(`kanon_bediener_hoogte`, 0,6 vak); het kanon houdt zijn eigen maat tot
`kanon_max_lengte`. Bij de dood spat het ALTIJD uit elkaar, ook van een
musketkogel of een sabel (Max: "net als de man zelf"): kanondelen met de
kanonjas en zonder bloed, de bediener met vlees, bloed en een kreet, plus de
ontploffing van `VFX.kanon_kapot`.

**Tunen:** Model-tuner, tab **Kanon**. Bovenin voor alle kanonnen
(`effects_tuning.json`, `kanon_*`): schot-moment (-1 = uit de clip),
vuur-tempo, terugslag, kanteling, terugslag heen/terug, lont-sis, bediener-
hoogte, max lengte, uit-elkaar-kracht, bloedwolk. Daaronder dezelfde knoppen
voor alleen dit kanon (`model_tuning.json` -> `"kanon"`), de vuurmond (gelijk
aan de rij op In de hand; "vuurmond = punt van de loop" haalt de afstelling
weer weg), en "test schot" / "uit elkaar". Schaal en plek: tab Model, zoals bij
elk model.

**Controle:** `<godot> --headless --path . res://tools/capture.tscn --
kanoncheck [factie]` (per archetype de clips op beide skeletten, het
schot-moment, kanon en bediener gescheiden, gibs met kanon- en lijfdelen, de
vuurmond voor het stuk, dan een musketdood die echt uit elkaar moet spatten;
met venster `_shot_kanon.png`, `_shot_kanon_vuur.png` (een kanon op het
schot-moment) en `_shot_kanon_gibs.png`). `verwerk_levering.py` draait hem na
elke kanon-levering.

---

## Handmatig (juli 2026, het oorspronkelijke voorstel)

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
