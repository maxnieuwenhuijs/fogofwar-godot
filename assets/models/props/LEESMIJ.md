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

## Een Tripo-glb erin zetten (12 september, de eerste: de rode tent)

Tripo levert een `tripo_node_<uuid>.glb`: een mesh, een materiaal, drie
texturen van 2048 die samen 9 MB wegen. Dat gaat er in EEN commando in:

    python tools/verwerk_prop.py <tripo.glb> tent --team red --draai 90

- `tent` is de naam uit PROP-WISHLIST.md zonder `prop_` en zonder team;
  `--team red|blue` maakt er de arme of de rijke versie van (zonder team:
  gedeeld, in beide kampen).
- `--draai` draait het model om zijn staande as tot de VOORKANT (opening,
  deur, gezicht) naar +Z wijst, naar de speler toe; de placeholders staan zo.
  Niet gokken: `blender --background --python tools/blender_prop_preview.py
  -- --in <glb> --uit results/props/x.png` zet het model vier keer naast
  elkaar (0, 90, 180, 270 graden, streepjes eronder); de kolom waarin de
  voorkant naar je toe wijst is de hoek. De rode tent had 90 nodig (Tripo
  legt de nok langs X).
- Het script slankt de texturen af (kleur en ruwheid als JPEG, normaal als
  PNG, hoogstens 1024 px, `--textuur`), decimeert boven `--doel` (1500)
  driehoeken met Blender, bakt de draai in een wortelknoop, schrijft
  `prop_<naam>[_team].glb` hierheen (9 MB wordt ruim 1 MB) en draait dan
  `--import`, zet de `.import` van de uitgepakte texturen op VRAM-compressie
  met mipmaps (`prop_tent_red_kleur.jpg`, `_normaal.png`, `_ruwheid.jpg`
  komen naast de glb te liggen: committen), importeert nog een keer en
  eindigt met `-- omgevingcheck`, die de prop als "geleverde glb-props" moet
  noemen. Een plaat van het resultaat staat in `results/props/`.
- `--hoogte 1.2` schrijft een manifest `prop_<naam>[_team].json` als de ware
  hoogte niet in `PROP_HOOGTE` staat; `--droogloop` vertelt alleen wat er zou
  gebeuren.
- Het spel houdt bij een geleverde tent zijn eigen reacties (lantaarn aan de
  voorkant van de doos, Zzz, de laars); andere geleverde props krijgen de
  generieke wiebel, hop en stofwolk, tenzij `_bouw_<prop>` in omgeving.gd
  eigen reacties meegeeft aan `_glb_prop`.

## Eigen low-poly props uit Blender (13 september, Max: "56 voorbeelden, exact zo moeten ze in Blender")

De voorbeelden staan in `previews/` (hernoemd naar de prop, `.gdignore`
erbij). De props worden procedureel gebouwd door `tools/blender_props/`:

- `bouwstenen.py`: de stenen (`box`, `lathe` = draaivorm voor tonnen, emmers,
  kannen; `cil`, `bol`, `piramide` = spijkerkop, `touw` = een zeshoek langs
  een lijn, `doek` = een lap) en de atlas: EEN plaatje van 1024 px met een
  raster van 8 x 8 stofjes van 128 px uit numpy (hout licht/donker/verweerd/
  blauw, duigen, schors, kopse kant, ijzer, roest, goud, koper, leer, touw,
  jute, linnen, blauw fluweel met goudrand, steen, klei, lei, fleur-de-lis,
  kroon, wapen, tapijt, ...). Per vlak past de uv in een stofje; rondom een
  draaivorm loopt u een keer rond. Platte facetten, `glad=True` voor kannen.
- `recepten.py`: per prop een functie op een `Bouwer` (maten in
  bord-eenheden, voeten op z = 0, voorkant naar -y = naar de speler), met
  een batchnummer in `RECEPTEN`.
- `bouw_props.py`: `blender --background --python tools/blender_props/bouw_props.py
  -- --batch 1` (of `--alleen kruitvat,kist_red`) schrijft
  `results/props_blender/prop_<naam>.glb` per prop (atlas ingebakken) en een
  plaat `plaat_batch1.png` met alles naast elkaar (van hoog naar laag).
- `python tools/verwerk_props_bulk.py results/props_blender` zet ze allemaal
  in een keer in het spel (per stuk verwerk_prop.py zonder controles, dan
  een keer importeren, de texturen op VRAM-compressie, nog een keer
  importeren, omgevingcheck).

Batch 1 (hout en ijzer, 22 stuks): kruitvat, kogels, houtstapel, houtblok,
takkenbos, hakblok, zaag, axe, touwrol, barrel, barrel_red, bierton_red,
emmer, emmer_red, kist, kist_red, lantaarn, fakkel, aambeeld, blaasbalg,
werkbank, put. Tussen 40 (houtblok) en 1.120 (kogels) driehoeken, 130-240 kB
per glb. Ze staan per diorama in `Omgeving.DIORAMAS` (niet meer in
EXTRA_PROPS: dat zette alles overal neer); een naam zonder placeholder
valt in `_plaats` terug op zijn glb. `prop_barrel` en `prop_axe` (Tripo,
juli) zijn vervangen; de "ton" pakt per kamp `prop_barrel_red` /
`_blue` als die er ligt.

Batch 2 en 3 (28: kannen, ketels, kommen, manden, doek, vaandels, het
rijke kamp) zijn op 13 september gebouwd en dezelfde dag weer verwijderd
(Max: "ik vind het tegenvallen, verwijder maar"); de recepten staan nog
in `recepten.py`, maar voor die props geldt weer de Tripo-route hierboven.
`-- omgevingcheck 1 blauw` speelt het kamp vooraan als blauw, voor props
die alleen als `_blue` bestaan.

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

## Cape-textuur (12 september, Max: "schrijf een texture prompt voor de blauwe cape met gouden rand")

De cape van het blauwe team komt uit code (`PawnView.maak_cape`): een lap
aan het rugbot die de shader vormt (smalle kraag bij de nek, over de
schouders breed, plooien, wind) en zelf kleurt: koningsblauw met goudgalon.
Wil je een echt plaatje, zet dan **`cape_blue.png`** (en eventueel
`cape_red.png`) in deze map en draai `--import`; de shader gebruikt het dan
als buitenkant en laat zijn eigen galon weg. Geen model nodig.

Zo moet het plaatje in elkaar zitten (de uv-hoek staat in `-- capecheck`):

- **Staand; kies 3:4** (bv 1152 x 1536), dat ligt het dichtst bij de lap.
  De cloth-cape is bovenaan zo breed als de schouders van het model en
  loopt naar de zoom uit; het plaatje rekt daar iets mee, wat je bij een
  rand en een embleem niet ziet. (De vlakke shader-lap, knop `cape_sim`
  0, neemt wel precies de verhouding van het plaatje over.) Geen alpha.
- **Boven = kraag** (wordt in het spel smal naar de nek toe getrokken),
  **onder = zoom**, links en rechts de zijranden. Links in het plaatje is
  links van de drager, gezien vanaf zijn rug.
- **Vlak en egaal belicht**: geen plooien, geen slagschaduw, geen
  perspectief, geen achtergrond. De plooien, de wind en het licht komen
  uit de shader; een ingebakken plooi vecht daarmee.
- **Rand rondom** (alle vier de zijden), want de lap wordt bovenaan smal en
  onderaan breed: de rand blijft dan overal een rand.
- **Embleem symmetrisch en in de onderste helft** (het bovenste vijfde
  verdwijnt in de kraag over de schouders).

Drie prompts (Engels, voor een plaatjesgenerator; kies er een of laat ze
alle drie maken en kies op het oog):

1. Velours met galon:
   `Royal blue velvet cape cloth, flat orthographic texture seen straight on, rectangular, portrait 3:4. A wide gold braid border with fine embroidered scroll-work runs along all four edges, a small gold fleur-de-lis in each lower corner. The center is plain deep royal blue velvet with a soft fabric sheen and subtle nap. Evenly lit, no folds, no creases, no shadows, no perspective, no background, fills the frame edge to edge, game texture, 1152x1536.`
2. Damast met bijen (Napoleon):
   `Napoleonic ceremonial cape cloth texture, flat and orthographic, rectangular, portrait 3:4. Deep royal blue silk damask with a fine tone-on-tone floral pattern, scattered small golden embroidered bees, a gold laurel wreath emblem centered in the lower half, and a gold embroidered border with a Greek-key motif along all four edges. Evenly lit, no folds, no shadows, no perspective, no background, fills the frame edge to edge, game texture, 1152x1536.`
3. Officiersmantel met adelaar en hermelijn:
   `Rich cobalt blue wool officer's cape cloth texture, flat orthographic view, rectangular, portrait 3:4. Slightly brushed wool surface, a broad gold-thread border with metallic braid along all four edges, a white ermine band with black spots along the top edge (the collar), and a golden eagle with spread wings embroidered centered in the lower half. Flat and even, no folds, no shadows, no perspective, no background, fills the frame edge to edge, game texture, 1152x1536.`

Voor het rode team (arm) zou het een verschoten, gestopte wollen lap
zonder galon zijn; die staat standaard uit (knop `cape_rood`).
