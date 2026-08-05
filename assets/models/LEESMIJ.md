# Mappen onder assets/models

Ingedeeld op vindbaarheid (Max, 30 juli). **Het spel zoekt op BESTANDSNAAM,
niet op pad** (`Bestandsindex` in `scripts/core/bestandsindex.gd`), dus je mag
hier submappen bijmaken of dingen verplaatsen zonder dat er iets stukgaat.
Twee bestanden met dezelfde naam: die het minst diep zit wint.

```
assets/models/
  board/                  het bord
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
