# Bewoners: kleine poppetjes in het diorama om het bord

Een bewoner is een geanimeerd 3D-poppetje dat naast het bord staat, iets
doet als je erop klikt (of tikt) en verder gewoon zijn idle staat te wezen.
Het idee (Max, 8 september): een `peasant_mouse` die hout hakt als je op hem
drukt, en zo per factie een paar mini-animaties.

## Wat je aanlevert

Een map `<naam>/` met daarin `<naam>.glb` (rigged, met de clips erin), en
eventueel `<naam>.json`. Het spel zoekt op bestandsnaam (net als bij de
pionnen), dus de map mag hier ook dieper staan.

- **Naam** = `<rol>_<factie>`: `peasant_mouse`, `cook_pig`, `bard_wolf`.
  Het factiewoord bepaalt waar hij staat: bij wie die factie speelt (jij
  vooraan in het kamp, de tegenstander aan de overkant). Woorden die het spel
  kent: mouse/muis, pig/varken/mens, lion/leeuw, bear/beer, wolf,
  croc/crocodile/krokodil/vos. Geen factiewoord = hij staat er altijd.
- **Clips**: dezelfde regel als bij de pionnen (`PawnView.CLIP_WOORDEN`):
  `Idle`, `Idle 2` zijn idle; `Death`, `Walk`, `Hit` doen niet mee. Alles wat
  het spel niet kent is een ACTIE: `Chopping`, `Axe swing`, `Drinking`,
  `Cheer`. Meer acties = bij elke klik een willekeurige. Geen actie-clip =
  een huppeltje bij een klik. Geen idle-clip = hij staat stil.
- **Maat**: maakt niet uit, het spel schaalt hem op `hoogte` (standaard 0,62
  op het bord, een pion is ongeveer zo hoog) en zet zijn voeten op het gras.
- **Textuur**: die in de glb. Geen teamkleuren, geen gibs, geen los wapen:
  een bijl mag gewoon ingebakken in het model zitten.

## Uit een .blend

Zet de map in de inbox met het woord `bewoners` in het pad, bijvoorbeeld
`assets/new upload folder/bewoners/peasant_mouse/peasant_mouse.blend`, en
draai:

    python tools/verwerk_levering.py "assets/new upload folder"

Dat exporteert alleen het karakter met zijn clips (geen musket-stap, geen
gibs) naar `assets/models/bewoners/<naam>/<naam>.glb`, importeert in Godot
en draait `-- bewonercheck <naam>`. Een kant-en-klare glb mag ook: zet hem
in `assets/models/bewoners/<naam>/`, draai `--import` en de check.

## Het manifest (`<naam>.json`, alles optioneel)

```json
{
  "hoogte": 0.62,
  "schaal": 1.0,
  "draai": 0,
  "draai_model": 0,
  "plek": [0.7, 14.6],
  "plek_ander": [9.5, -3.4],
  "kant": "eigen",
  "factie": "mouse",
  "idle": "Idle 2",
  "acties": ["Chopping"],
  "geluid": ["bewoner_hakken", "prop_bijl", "impact_wood"],
  "geluid_moment": 0.6,
  "decor": ["stronk"],
  "decor_offset": [0.0, 0.5],
  "model": "infantry_base"
}
```

- `hoogte`: hoe hoog hij op het bord wordt; `schaal` gaat daar nog overheen.
- `draai`: graden om zijn as (standaard 0 vooraan, 180 aan de overkant);
  `draai_model` draait alleen het model in zijn eigen frame, voor een export
  die scheef staat.
- `plek` / `plek_ander`: bordcoordinaten [x, z] voor het kamp vooraan en de
  overkant. Zonder plek krijgt hij een vrij vast plekje (vier vooraan, drie
  aan de overkant). Het kamp vooraan ligt bij z 12 tot 16, de overkant bij
  z -2 tot -4; x loopt van -1 tot 11, en door de camera-yaw schuift wat
  vooraan staat op het scherm naar rechts.
- `kant`: `eigen`, `ander` of `beide`; alleen voor bewoners zonder factie.
- `factie`: overrulet het woord in de naam.
- `idle`: een clipnaam die als enige idle geldt; `acties`: alleen deze
  clips (doelnamen als `melee` of ruwe clipnamen) zijn acties.
- `geluid`: categorieen in volgorde, de eerste die bestaat klinkt (een
  `bewoner_hakken.wav` ergens in sounds/ doet automatisch mee);
  `geluid_moment`: seconden na het begin van de actie.
- `decor`: spulletjes uit het diorama naast hem (`stronk`, `houtstapel`,
  `kist`, `vuurtje`), `decor_offset` [x, z] in zijn eigen frame (standaard
  een halve meter voor hem).
- `model`: gebruik een glb elders onder assets/models/ in plaats van
  `<naam>.glb`, zoals `soldaat_mouse.json` doet met de muis-infanterist.

## Controleren

    <godot> --headless --path . res://tools/capture.tscn -- bewonercheck [naam]

Laadt elke bewoner, print factie, hoogte, idle- en actie-clips, speelt een
actie en kijkt of hij weer in idle komt. `-- omgevingcheck` klikt daarna ook
op de bewoners in het echte spel (ze zijn gewone props).
