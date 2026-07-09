# Model-pijplijn checklist

Afvinken per nieuw model. Uitleg: `MODEL-WISHLIST.md` sectie 4. Kanon: zie
`KANON-ANIMATIE-EN-GIBS.md`.

**Naam-conventie:** `assets/models/<factie>/<type>_<archetype>.glb`
factie: `mouse pig lion bear wolf crocodile` · type: `infantry cavalry artillery` ·
archetype: `base spd hp atk mix`

---

## A. Genereren & riggen (infanterie / cavalerie)
- [ ] Model genereren (Tripo/Meshy, **Laag Poly ~1000 tris**), losse lichaamsdelen
- [ ] Mixamo: upload **A-pose zonder botten** → auto-rig → **1× FBX "With Skin"**

## B. Blender — voorbereiden
- [ ] Lijf in **losse objecten** geknipt en exact benoemd: `armL armR body hat legL legR tail`
      (Edit Mode → selecteer per deel → `P` → Selection)

## C. Twee exports uit hetzelfde .blend
- [ ] **Export 1** `<model>.glb` — 7 delen **+ Armature** · **Skinning AAN · Animation AAN**
- [ ] **Export 2** `<model>_gibs.glb` — **alleen** de 7 delen · **Skinning UIT · Animation UIT**

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
