# Mappen onder sounds

Ingedeeld op wat je zoekt (Max, 30 juli). **Het spel zoekt op BESTANDSNAAM,
niet op pad**, dus verplaatsen mag; een nieuwe submap ook.

```
sounds/
  vuren/          musket, kanon, lont, strijdkreet, terugslag
  impact/         wat er geraakt wordt: vlees, kuras, hout, bot, afketser, bloed
  dood/           inf_die, horse_die, kanon vernietigd, wiel schiet los
  val/            wat er op de grond valt: lijf, hoed, musket, vlag, trommel...
  beweging/       stappen, paard, kanon rollen, pion plaatsen, blokkade
  selectie/       pion/kanon/paard aanklikken en deselecteren
  kaarten/        kaarten pakken, kiezen, stats schuiven, koppelen, onthullen
  spel/           fase, klok, initiatief, haven, winst, verlies
  ui/             knoppen, hover, menu's
  facties/<factie>/  factie-eigen kreten (nu alleen mouse)
  sound_tuning.json  jouw dB- en vertraging-afstelling per categorie
```

## Hoe een bestand een categorie wordt

De naam is de categorie. `impact_flesh.wav` en `impact_flesh_2.wav` vormen samen
de categorie `impact_flesh` met twee varianten (`_2`, `_3` ... = variant). Staat
een bestand al in de BANK van `scripts/core/audio_manager.gd`, dan hoort het
daar en krijgt het geen eigen categorie.

Controleren of alles meedoet:

```
<godot> --headless --path . res://tools/capture.tscn -- geluidcheck
```

Dat toont per categorie het aantal varianten, de mix-dB, jouw tuner-dB en de
vertraging, en meldt categorieen zonder geluid of die niemand afspeelt.
