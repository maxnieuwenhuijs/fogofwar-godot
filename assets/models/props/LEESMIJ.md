# Props (attributen in de hand, en het diorama om het bord)

Losse voorwerpen die een pion vasthoudt. Gedeeld door alle facties.

**Sinds 8 september ook de props van het diorama om het bord** (tent, fakkel,
wagen, hakblok, ...): zelfde map, zelfde naamregel `prop_<naam>.glb`, met een
team-variant `prop_<naam>_red.glb` (arm) en `prop_<naam>_blue.glb` (rijk). Het
spel (`scripts/game/omgeving.gd`) pakt voor elk kamp de eigen kleur en anders
de gedeelde, schaalt hem op zijn ware hoogte (een tegel is 1, een pion 0,62;
tabel `PROP_HOOGTE`, of `prop_<naam>.json` met `hoogte`, `draai`, `y`) en zet
hem klikbaar neer. De volledige lijst met scenes, prompts en wat er al ligt:
`PROP-WISHLIST.md` en `prop-tracker.html` (`python tools/bouw_prop_tracker.py`,
paneelknop "Welke props ontbreken?"). Een prop die maar voor een team bestaat
lever je MET het teamwoord, anders komt hij in beide kampen.

## Formaat

- **GLB** (aanrader): het spel probeert eerst `.glb`, dan `.fbx`. GLB is één
  bestand met de textures erin — geen losse plaatjes die kwijtraken.
- **Statische mesh**: geen skelet, geen animatie, geen team-textures, geen gibs.
  Het voorwerp erft de beweging van de hand waar het aan hangt.
- Poly-budget: laag houden (~500-1.000 tris is ruim zat voor een trommel);
  voor de diorama-props staat de tabel onder **Budget** onderaan.
- Textures: het spel zet ze bij import terug naar **512px met mipmaps** (zie de
  `.import`-bestanden). Een prop in een hand heeft op bord-afstand niet meer
  nodig, en het voorkomt hapering bij het eerste gebruik.

## Namen (exact zo, anders vindt het spel ze niet)

| Bestand | Wie draagt het |
|---|---|
| `prop_flag.glb` (of `prop_pole.glb`) | vaandeldrager — **alleen de kale stok**, het doek maakt het spel er zelf aan (teamkleur + wapper) |
| `prop_drum.glb` | tamboer |
| `prop_horn.glb` | hoornblazer (sinds 12 september NIET meer in de hand; wel klikbaar in het diorama en in de Model-tuner) |
| `prop_axe.glb` | sapeur (idem) |
| `prop_barrel.glb` | marketentster (idem) |
| `prop_mace.glb` | tamboer-majeur (idem, alleen nog in de Model-tuner) |

Wil je een factie-eigen variant (een muizentrommel is kleiner dan een
berentrommel), zet die dan in `assets/models/<factie>/` met dezelfde naam —
die wint automatisch van de gedeelde versie hier.

## Na het toevoegen

1. Project openen in Godot, of `Godot --headless --path . --import`.
2. Klaar: de vaandeldrager en de tamboer van elk leger pakken hun attribuut
   vanzelf op. **Alleen die twee** (Max, 12 september: "sommige hebben nu wel
   een prop vast anders dan de vlag of trom, dat niet doen graag"): de knop
   `ROL_DICHTHEID` in `scripts/game/pawn_view.gd` staat op 0; op 5 komen
   hoorn, bijl, vat en staf weer sporadisch terug bij ongekoppelde pionnen.
3. Het spel schaalt de prop automatisch naar ~0,55 wereld-unit op de langste
   as en hangt hem aan de rechterhand. Zit hij scheef of te groot? **Model-tuner**
   (hoofdmenu → Instellingen): zet type op *Infanterie*, kies bij **Hand** de
   prop (vaandel/trommel/hoorn/bijl/vat/staf) en stel hem bij met de
   musket-schuifjes; opslaan schrijft naar `assets/models/model_tuning.json`
   onder de sleutel `props/<naam>`.

Ontbreekt een prop, dan draagt die pion gewoon zijn musket — je kunt dus met
één trommel beginnen. Zie `MODEL-WISHLIST.md` §3d voor de prompts.

## Budget voor de diorama-props (12 september, Max: "hoeveel props, hoeveel vertices")

Op deze schaal maakt het weinig uit, zolang elke prop laag blijft. Ter
vergelijking (gemeten met `-- dioramashots`, dat nu per diorama meshes en
driehoeken meldt): een diorama heeft 14-18 props uit primitieven, samen
4.700-9.500 driehoeken in 70-106 meshes. Een infanterist is 2.231
driehoeken plus 736 voor zijn musket, dus twee legers van zestien man zijn
ruim 90.000 driehoeken; het bord is er 196. Het diorama mag dus rustig drie
keer zo zwaar worden als nu zonder dat iemand het merkt.

| Soort prop | Voorbeelden | Driehoeken | Textuur |
|---|---|---|---|
| klein | bijl, lantaarn, emmer, fles, kist, bel, kip, kogel | 300-800 | 512 |
| middel | tent, wagen, kraam, put, kanon, hakblok, toilethuisje | 800-1.500 | 512-1.024 |
| groot decor | molen, ruine, piramide, sfinx, steiger, hooiberg, boom | 1.500-3.000 | 1.024 |

Grenzen: geen enkele prop boven de 3.000, een heel diorama onder de 30.000
(een derde van wat de pionnen al kosten), 15-25 props per diorama (meer
wordt vol, en de reacties zitten elkaar in de weg). Wat op een telefoon
echt telt is niet het aantal vertices maar het aantal MESHES en materialen
(draw calls): lever elke prop als EEN mesh met EEN materiaal. Een Tripo-glb
van een mesh is daarmee al goedkoper dan de placeholder van vier tot acht
primitieven die hij vervangt. Tripo levert standaard 20.000-100.000+
driehoeken: kies daar de low-poly/quad-optie met een face-limiet van
1.000-2.000, of haal hem achteraf door
`blender --background --python tools/blender_decimate.py -- --in prop_x.glb --out prop_x.glb --doel 1200`.
Een prop staat op het scherm zo'n 40-110 px hoog (75 px per bord-eenheid),
dus detail onder een centimeter zie je toch niet; steek de moeite in het
silhouet en de textuur.
