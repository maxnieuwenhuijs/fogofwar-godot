# Props (attributen in de hand)

Losse voorwerpen die een pion vasthoudt. Gedeeld door alle facties.

## Formaat

- **GLB** (aanrader): het spel probeert eerst `.glb`, dan `.fbx`. GLB is één
  bestand met de textures erin — geen losse plaatjes die kwijtraken.
- **Statische mesh**: geen skelet, geen animatie, geen team-textures, geen gibs.
  Het voorwerp erft de beweging van de hand waar het aan hangt.
- Poly-budget: laag houden (~500-1.000 tris is ruim zat voor een trommel).
- Textures: het spel zet ze bij import terug naar **512px met mipmaps** (zie de
  `.import`-bestanden). Een prop in een hand heeft op bord-afstand niet meer
  nodig, en het voorkomt hapering bij het eerste gebruik.

## Namen (exact zo, anders vindt het spel ze niet)

| Bestand | Wie draagt het |
|---|---|
| `prop_flag.glb` (of `prop_pole.glb`) | vaandeldrager — **alleen de kale stok**, het doek maakt het spel er zelf aan (teamkleur + wapper) |
| `prop_drum.glb` | tamboer |
| `prop_horn.glb` | hoornblazer |
| `prop_axe.glb` | sapeur |
| `prop_barrel.glb` | marketentster |
| `prop_mace.glb` | tamboer-majeur |

Wil je een factie-eigen variant (een muizentrommel is kleiner dan een
berentrommel), zet die dan in `assets/models/<factie>/` met dezelfde naam —
die wint automatisch van de gedeelde versie hier.

## Na het toevoegen

1. Project openen in Godot, of `Godot --headless --path . --import`.
2. Klaar: ongekoppelde infanteristen pakken het attribuut vanzelf op
   (ongeveer 1 op de 3 — knop `ROL_DICHTHEID` in `scripts/game/pawn_view.gd`).
3. Het spel schaalt de prop automatisch naar ~0,55 wereld-unit op de langste
   as en hangt hem aan de rechterhand. Zit hij scheef of te groot? **Model-tuner**
   (hoofdmenu → Instellingen): zet type op *Infanterie*, kies bij **Hand** de
   prop (vaandel/trommel/hoorn/bijl/vat/staf) en stel hem bij met de
   musket-schuifjes; opslaan schrijft naar `assets/models/model_tuning.json`
   onder de sleutel `props/<naam>`.

Ontbreekt een prop, dan draagt die pion gewoon zijn musket — je kunt dus met
één trommel beginnen. Zie `MODEL-WISHLIST.md` §3d voor de prompts.
