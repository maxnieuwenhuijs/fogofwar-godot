# Mappen onder assets/ui

De UI-assetpack van de ontwerper (`fogofwar-assets/UI_assets_pack`, 3
september 2026) plus zijn "Fog of war UI direction"-pdf. **Het spel zoekt op
BESTANDSNAAM, niet op pad** (`Bestandsindex`), dus je mag hier submappen
bijmaken of dingen verplaatsen. De bestandsnamen zijn precies die van de
ontwerper, typo's incluis (`button_2_bloccked.png`, `Croccodile.png`): de
code herkent beide spellingen, zodat een nieuwe drop van het pack gewoon
werkt. Nieuwe bestanden erin? Een keer `<godot> --headless --path . --import`
draaien (net als bij de i18n-csv), anders kent het spel ze niet.

```
assets/ui/
  buttons/    button_1..7 (+ _pressed, _blocked) en de lakzegel-vinkjes
  cards/      kaartframe, ruggen, linten, zegels, stempels, kransen, panelen (Frame_1..3), Texture_1
  emblems/    de zes gravures (Pig, Mouse, Lion, Bear, Wolf, Croccodile)
  icons/      30 witte iconen (kleur je in met modulate)
  fonts/      Roboto Slab Regular + Bold (van deze machine); zie hieronder
  texture/    Texture_1.png (perkament)
```

## Wie wat gebruikt

Alles loopt via `scripts/ui/ui_assets.gd` (`UiAssets`): iconen op hun id uit
`docs/design/UI-SPEC-EN.md` (`UiAssets.icoon("stat-hp")`), emblemen per factie
(`UiAssets.embleem(doctrine)`), kaartonderdelen (`UiAssets.kaart("lint_rood")`),
knop- en paneelstijlen als 9-patch (`knop_stijl`, `paneel_stijl`) en het
thema dat de autoload `UiThema` over het hele spel legt. In een scherm zet je
alleen `theme_type_variation` (de lijst staat in ui_assets.gd bij
THEMA-VARIANTEN); je hoeft nergens een pad te kennen.

Controleren wat er ligt en wat mist: `<godot> --headless --path .
res://tools/capture.tscn -- uicheck` (statusbord: elk icoon-id, embleem,
kaartdeel, knop en font, plus of het thema bouwt).

## Wat er (nog) niet in zit

- **Acht iconen uit de spec** zijn niet geleverd: vote, nomination, donation,
  testament, report, chat, clock, pin (campagne/sociaal en tijd). Schermen
  vallen daar terug op tekst; zodra de png's er zijn, zet je de bestandsnaam
  in `UiAssets.ICONEN` en haalt hem uit `NOG_NIET_GELEVERD`.
- **Fonts.** De pdf schrijft Roboto Slab SemiBold (tekst) en Rye Regular
  (cijfers) voor. Die twee zitten niet in het pack. In `fonts/` staan nu
  Roboto Slab Regular en Bold van deze machine; het thema gebruikt Regular
  voor tekst en Bold voor koppen en cijfers. Drop `RobotoSlab-SemiBold.ttf`
  en `Rye-Regular.ttf` (Google Fonts, OFL) in `fonts/`, importeer, en het
  thema pakt ze vanzelf op (volgorde in `UiAssets.FONTS`).
- **Gouden selectiehoeken** van de "SELECTED"-kaart (pdf pagina 3) zijn geen
  los bestand; het spel tekent een gouden rand + gloed in Selection Gold.

## Mipmaps

De iconen en kaartdelen worden vaak op 30-60% getekend; de `.import`-
bestanden hier staan daarom op `mipmaps/generate=true` en het project op
`default_texture_filter` = linear-with-mipmaps. Nieuwe png's krijgen de
Godot-standaard (geen mipmaps): zet het even aan in het importpaneel of kopieer
een bestaand `.import`-blok.
