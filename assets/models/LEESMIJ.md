# Mappen onder assets/models

Ingedeeld op vindbaarheid (Max, 30 juli). **Het spel zoekt op BESTANDSNAAM,
niet op pad** (`Bestandsindex` in `scripts/core/bestandsindex.gd`), dus je mag
hier submappen bijmaken of dingen verplaatsen zonder dat er iets stukgaat.
Twee bestanden met dezelfde naam: die het minst diep zit wint.

```
assets/models/
  board/                  het bord
    spelbord/             HET bord in Board.tscn: 11x11, 196 driehoeken, uit
                          tools/blender_schaakbord.py. spelbord.png is de
                          textuur (material_override in Board.tscn): die
                          vervang je bij een retexture. bron/ = het .blend
                          (met .gdignore, Godot mag dat niet importeren)
    schaakbord/           dezelfde bouw als 8x8-schaakbord (referentie)
    omgeving/             het landschap om het bord: gras.png (naadloze tegel),
                          gras_vlekken.png (grove multiply-laag), wolken.png
                          (wolkenschaduw, alfa); uit tools/maak_omgeving_texturen.py,
                          gebruikt door scripts/game/omgeving.gd
    board.glb, board_Image_0.png   het oude Tripo-bord (930 driehoeken),
                          sinds 8 september niet meer in gebruik
  props/                  gedeelde voorwerpen (prop_drum, prop_pole, ...)
  <factie>/               per factie, bv mouse/
    infantry/           de modellen zelf + gibs + musket-variant + teamkleuren
    weapons/               musket.glb en zijn texturen
    source-textures/        losse Tripo-jpg's; het spel gebruikt ze NIET
  model_tuning.json       jouw afstelwerk (tuner)
  effects_tuning.json     effect-knoppen
```

## Wat hoort bij elkaar te blijven

- **Teamkleuren** (`<model>_red.png`, `_blue.png`, `_red_gore.png`,
  `_blue_gore.png`) horen NAAST hun glb: die worden op naam-van-het-model
  gezocht, niet via de index.
- **Gibs** (`<model>_gibs.glb` of `<model>.gibs.glb`) mogen overal staan, maar
  naast het model is het overzichtelijkst.
- **source-textures/** kun je leeg gooien zonder gevolgen; de texturen zitten
  ingebakken in de glb. Ze staan er alleen voor als je later opnieuw wil bakken.

## Afstel-sleutels veranderen NIET door verhuizen

`model_tuning.json` gebruikt `<factie>/<bestandsnaam>` (bv `mouse/infantry_atk`,
`props/prop_drum`). Die sleutel komt niet uit de mapnaam, dus jouw afstelwerk
blijft aan het juiste model hangen als je dingen opschuift.
