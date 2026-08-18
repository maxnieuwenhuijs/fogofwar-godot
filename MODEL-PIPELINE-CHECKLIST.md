# Model-pijplijn checklist

Afvinken per nieuw model. Uitleg: `MODEL-WISHLIST.md` sectie 4. Kanon: zie
`KANON-ANIMATIE-EN-GIBS.md`.

**Naam-conventie:** `assets/models/<factie>/<type>_<archetype>.glb`
factie: `mouse pig lion bear wolf crocodile` · type: `infantry cavalry artillery` ·
archetype: `base spd hp atk mix`

**Geen artillerie voor `mouse` en `bear`** (stand C19, 8 augustus 2026): hun
legersamenstelling is [16,4,0] en [19,3,0], en `GameState.kent_type()` verbiedt
ze dan ook een kanon te spawnen. Sla voor die twee dus zowel het model als de
gibs over. Controleren wat er nu geldt: `capture.tscn -- facties`.
Regimentsrollen (wishlist 3d): `infantry_flag drum horn sapper officer canteen scout medic` -- attribuut apart genereren en in Blender parenten
aan hand/heup als deel `prop`; deze modellen krijgen GEEN musket.

---

## A. Genereren & riggen (infanterie / cavalerie)
- [ ] Model genereren (Tripo/Meshy, **Laag Poly ~1000 tris**), losse lichaamsdelen
- [ ] Mixamo: upload **A-pose zonder botten** → auto-rig → **1× FBX "With Skin"**

## B. Blender — voorbereiden
- [ ] Lijf in **losse objecten** geknipt. Namen mogen zijn zoals Blender ze
      geeft: `Arm.L`, `ARm.R`, `Upleg.L`, `body`, `hat`, `Leg.R` ... Het spel
      maakt namen zelf kaal (punten, spaties en hoofdletters tellen niet mee),
      dus `Arm.L` telt gewoon als `armL`. Zorg alleen dat het WOORD klopt:
      arm, leg, body, hat, tail.
- [ ] **Clipnamen hoeven niet netjes.** Mixamo-namen als "Death 1",
      "Rifile Walking" of "Bayont Attack" worden bij het laden vertaald naar
      death1 / walk1 / bayonet1. Herkende woorden: idle, walk, death|die,
      hit|reaction, fire|shoot, bayon|butt|stab|melee|attack, aim|ready.

## C. Drie exports uit hetzelfde .blend (sinds 15 augustus gescript)

Levert de generator een .blend met losse delen, dan doet de pijplijn alles.
**Geldt ook voor de big bros (cavalerie)**: zelfde drie stappen, alleen heet
het wapen dan `cavalry_<arch>_melee.glb` in plaats van
`infantry_<arch>_musket.glb` (sabel/bijl/lans in plaats van musket).

```
blender --background model.blend --python tools/blender_export_musket.py -- --uit <map>/infantry_<arch>_musket.glb
blender --background model.blend --python tools/blender_export_blend.py  -- --uit <map>/infantry_<arch>.glb
blender --background --python tools/blender_merge_character.py -- --base <map>/infantry_<arch>.glb --gibs
```

LET OP: de `tripo_node_<uuid>`-mesh in zo'n blend is het INGEBAKKEN MUSKET
(niet een duplicaat -- die vergissing is op 15 augustus gemaakt en gefikst).
De generator hangt hem bot-geparent aan `mixamorig:RightHand`, dus hij
beweegt in ELKE animatie mee: richten, dragen, bajonetstoot.

Sinds 16 augustus (besluit Max) gebruikt het spel dat ingebakken musket ZELF:
- Stap 1 haalt een losse kopie eruit (nog steeds nodig: terugval-prop en
  referentie), stap 2 exporteert het karakter MET het musket erin (vlag
  `--zonder-wapen` voor het oude kale gedrag), stap 3 doet de kwartslag-fix
  en de gibs -- het wapen wordt daar automatisch uit de gibs geweerd.
- In het spel laat `pawn_view` het meebewegende musket gewoon staan (geen
  prop, musket-tuning niet meer nodig) en gooit het bij de dood los vanaf de
  hand. Modellen ZONDER meebewegend musket (muis, oude statische bakken)
  vallen automatisch terug op de prop-in-de-hand.
- Controle na import: `<godot> --headless --path . --script
  tools/_wapencheck.gd` (30 modellen: beweegt het wapen mee, heeft het z'n
  texture, zit er niets in de gibs).

Twijfel je wat een mesh is: RENDER hem even, een naam-scan is geen
inhouds-controle.

## C-oud. Twee exports uit hetzelfde .blend (handmatig)
- [ ] **Export 1** het model **+ Armature** · **Skinning AAN · Animation AAN**
- [ ] **Export 2** de gibs — dezelfde delen, **Animation UIT**
- [ ] Bestandsnamen mogen kort (`infantry_atk.glb` / `infantry_atk_gibs.glb`)
      of lang (`infantry_atk_mouse.glb` / `infantry_atk_mouse.gibs.glb`) zijn;
      het spel accepteert beide en zoekt in die volgorde.
- [ ] **Waar neerzetten:** `assets/models/<factie>/infantry/`. De map maakt
      niet uit (het spel zoekt op naam), maar teamkleur-png's moeten naast hun
      glb liggen. Losse texturen uit de generator gaan naar `source-textures/`:
      die zitten al ingebakken in de glb.

## D. Clips + rechtdraaien
- [ ] Zitten alle 15 clips in je .blend? → sleep `<model>.glb` op **`fix_model.bat`** (kwartslag-fix)
- [ ] Missen er clips? → donor-merge tegen de **huidige** base:
      `blender --background --python tools/blender_merge_character.py -- --base assets/models/<factie>/<model>.glb --donor assets/models/mouse/infantry_base.glb`

## E. Textures
- [ ] `<model>_red.png` + `<model>_blue.png` (team-uniformen, **zelfde UV-atlas**)
- [ ] *(optioneel)* `<model>_red_gore.png` + `<model>_blue_gore.png` (bloederige gibs)
- [ ] *(optioneel)* `<model>_musket.glb` (eigen musket; anders factie-musket)
- [ ] Import van **elke grote PNG**: `process/size_limit=1024` + `mipmaps/generate=true`
      (anders hapert de gib bij het eerste gebruik)

## F. In Godot
- [ ] Importeren (editor openen of `Godot --headless --path . --import`)
- [ ] **Model-tuner** (hoofdmenu): schaal / hoogte / X / Z · musket (schaal/pos/rot) · vuurmond → **OPSLAAN**
- [ ] `assets/models/model_tuning.json` mee-committen
- [ ] **Melee-timing NIET aanraken** — die is globaal (`effects_tuning.json`, gedeelde clips)

## G. Controleren in de tuner (preview-strip bovenin)
- [ ] `idle / walk / attack / melee / hit / die / ready` spelen goed af
- [ ] Melee-stoot gaat **recht naar voren** (niet gedraaid)
- [ ] `gibs (kanon/musket/melee)` — delen vliegen los + bloed, gore op de brokstukken
- [ ] Team **rood/blauw** kloppen

## H. Afronden
- [ ] `git add -A && git commit && git push`

---

### De drie valkuilen (altijd checken)
1. **Twee exports** — een skinned mesh kun je niet los slingeren; het aparte
   `_gibs.glb` (armature-loos) IS de gebakken versie.
2. **Kwartslag** — Mixamo levert bayonet/hit/ready ~90° gedraaid → `fix_model.bat`.
3. **1024-textures** — anders de gib-freeze.
